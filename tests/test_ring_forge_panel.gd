extends Node2D
## 고리 조립 제작대 **통합 시험대** (tests/test_ring_forge_panel.tscn, F6) — 리드 소유.
##
## 옛 test_forge와 같은 결: 세계(아레나)가 늘 살아 있고, E로 책을 펼쳐 **조립**하고, ESC로
## 덮으면 그 자리에서 **쏜다**.
##
## 🔴 발사 모델 (사용자 확정) — **진이 곧 투사체다.**
##   1) 발사 = 조립한 **마법진(진)이 통째로 조준 방향으로 날아간다** (진 = 탄의 몸).
##   2) 히트 = 적에 맞으면 그 자리에서 **안의 마법진이 전개**된다 (껍질이 내용물을 착탄점에 배달):
##        • 발산→ 칸: 그 화살표 방향으로 **불 탄환**이 퍼져 나간다 (사방/오른쪽 등 = 칸 패턴대로)
##        • 응집← 칸: **하나로 모여 불기둥 하나**가 착탄점에 선다 (많을수록 굵다)
##   보드 위(칸 0)는 **탄이 가던 방향**에 맞춰 회전한다 (전개는 진행 방향 기준).
##
## 발사는 아직 **자체 데모**다 (spell_system·중첩 진 통합은 TODO #16).
##
## 조작: (책 펼침) 탭=진/룬/문양 · 문양 클릭/Q·W=고리에 얹기 · 칸 클릭=방향 조절 · Enter=맺기 · ESC=덮기
##       (책 덮음) WASD=이동 · 마우스=조준 · 좌클릭/Space=발사 · R=과녁 리셋 · E=책 펴기 · C=보드 비우기

const RingForgePanel := preload("res://src/drawing/ring_forge_panel.gd")
const RingBoard := preload("res://src/drawing/ring_board.gd")

const SLOTS := 8
const UP_AXIS := -PI / 2.0

const BG_COLOR := Color(0.10, 0.14, 0.11)
const TEXT_COLOR := Color(0.90, 0.86, 0.78)
const OK_COLOR := Color(0.60, 0.85, 0.55)
const WARN_COLOR := Color(0.92, 0.45, 0.35)
const HINT_COLOR := Color(0.70, 0.66, 0.58)
const TARGET_COLOR := Color(0.72, 0.42, 0.38)
const TARGET_HIT := Color(0.95, 0.80, 0.45)
const CARRIER_COLOR := Color(0.85, 0.72, 0.40)   # 날아가는 마법진(진)
const BOLT_COLOR := Color(0.98, 0.58, 0.22)      # 전개된 불 탄환
const PILLAR_COLOR := Color(0.98, 0.62, 0.22)    # 전개된 불기둥

# ── 세계 ──
const PLAYER_SPEED := 90.0
const PLAYER_START := Vector2(150, 250)
const BOUNDS := Rect2(14, 40, 612, 306)
const TARGET_R := 12.0
const TARGET_POS: Array[Vector2] = [
	Vector2(360, 90), Vector2(470, 70), Vector2(560, 110),
	Vector2(410, 190), Vector2(540, 210),
]

# ── 진 = 날아가는 투사체 (조준 방향) ──
const CARRIER_SPEED := 240.0
const CARRIER_LIFE := 2.6
const CARRIER_R := 9.0

# ── 전개: 발산 = 불 탄환 (착탄점에서 화살표 방향으로) ──
const BOLT_SPEED := 200.0
const BOLT_LIFE := 1.1
const BOLT_RADIUS := 4.0

# ── 전개: 응집 = 불기둥 (착탄점에 하나) ──
const PILLAR_LIFE := 1.4
const PILLAR_TICK := 0.20
const PILLAR_BASE_R := 15.0
const PILLAR_R_PER := 3.5

var _forge: Control
var _world: Node2D
var _player_pos: Vector2 = PLAYER_START
var _aim: Vector2 = Vector2.UP
var _committed: Dictionary = {}
var _targets: Array[Dictionary] = []
var _carriers: Array[Dictionary] = []   # 날아가는 마법진(진)
var _bolts: Array[Dictionary] = []      # 전개된 불 탄환
var _pillars: Array[Dictionary] = []    # 전개된 불기둥

var _title_label: Label
var _result_label: Label
var _hint_label: Label


func _ready() -> void:
	for p: Vector2 in TARGET_POS:
		_targets.append({"pos": p, "hits": 0, "flash": 0.0})

	_world = Node2D.new()
	_world.name = "World"
	_world.draw.connect(_draw_world)
	add_child(_world)

	var ui := CanvasLayer.new()
	add_child(ui)
	_title_label = _label(ui, Vector2(8, 6), 11)
	_title_label.text = "고리 조립 제작대 — 통합 시험대 (F6) · 진이 날아가 히트하면 전개"
	_result_label = _label(ui, Vector2(8, 22), 10)
	_hint_label = _label(ui, Vector2(8, 344), 8)
	_hint_label.text = "책 펼침: 탭=진/룬/문양 · Q·W=문양 · 칸 클릭=방향 · Enter=맺기 · ESC=덮기   |   덮음: WASD·마우스=조준 · 좌클릭/Space=발사 · R=리셋 · E=책 · C=비움"
	_hint_label.add_theme_color_override(&"font_color", HINT_COLOR)

	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_forge = RingForgePanel.new()
	layer.add_child(_forge)
	_forge.connect(&"design_committed", _on_committed)
	_forge.connect(&"closed", _on_closed)
	_forge.call(&"open")
	_refresh_result()


func _process(delta: float) -> void:
	if not _forge.call(&"is_open"):
		var dir := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
		if dir != Vector2.ZERO:
			_player_pos = (_player_pos + dir.normalized() * PLAYER_SPEED * delta) \
				.clamp(BOUNDS.position, BOUNDS.end)
		var to_mouse := get_global_mouse_position() - _player_pos
		if to_mouse.length_squared() > 1.0:
			_aim = to_mouse.normalized()
		_update_combat(delta)
	_world.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _forge.call(&"is_open"):
		return
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		match k.keycode:
			KEY_E:
				_forge.call(&"open")
			KEY_SPACE:
				_fire()
			KEY_R:
				_reset_targets()
			KEY_C:
				_forge.call(&"clear_board")
				_committed = {}
				_refresh_result()
		get_viewport().set_input_as_handled()
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_fire()
		get_viewport().set_input_as_handled()


# ─────────────────────────── 발사 = 진(마법진)을 통째로 쏜다 ───────────────────────────

func _slot_angle(k: int) -> float:
	return TAU * float(k) / float(SLOTS) + UP_AXIS


func _fire() -> void:
	var a: Dictionary = _forge.call(&"get_assembly")
	if a.is_empty():
		if bool(_forge.call(&"can_commit")):
			_set_warn("조립은 됐다 — E로 책을 펴서 Enter로 맺어야 쏜다")
		else:
			_set_warn("문양을 고리에 얹어 맺어야 쏜다 (E)")
		return
	var rings: Array = a.get("rings", [])
	if rings.is_empty():
		return
	# 🔴 진이 곧 탄이다 — 마법진을 통째로 조준 방향으로 쏜다. 링 패턴은 히트할 때 전개된다.
	_carriers.append({
		"pos": _player_pos, "vel": _aim * CARRIER_SPEED, "life": CARRIER_LIFE,
		"ring": (rings[0] as Array).duplicate(),
	})
	_forge.call(&"play_cast")
	_set_ok("발사 — 마법진이 날아간다 (%s) · 맞으면 전개" % _describe(a))


## 히트 = 착탄점에서 안의 마법진을 편다. travel = 탄이 가던 방향(회전 기준).
func _deploy(hit: Vector2, travel: Vector2, ring: Array) -> void:
	var rotate_by := travel.angle() - UP_AXIS
	var gather := 0
	for k in SLOTS:
		var g := int(ring[k])
		if g == RingBoard.G_RADIATE:
			# 발산 → 화살표 방향으로 불 탄환이 퍼진다
			var dir := Vector2.from_angle(_slot_angle(k) + rotate_by)
			_bolts.append({"pos": hit, "vel": dir * BOLT_SPEED, "life": BOLT_LIFE})
		elif g == RingBoard.G_GATHER:
			gather += 1
	# 응집 → 하나로 모여 불기둥 하나 (착탄점에)
	if gather > 0:
		_pillars.append({"pos": hit, "life": PILLAR_LIFE, "tick": 0.0,
			"r": PILLAR_BASE_R + PILLAR_R_PER * float(gather)})


func _hit_target(t: Dictionary) -> void:
	t.hits += 1
	t.flash = 0.22


func _update_combat(delta: float) -> void:
	for t in _targets:
		if t.flash > 0.0:
			t.flash = maxf(0.0, t.flash - delta)

	# ── 진(투사체): 조준 방향으로 날다가 적에 맞으면 전개하고 사라진다 ──
	var carriers_kept: Array[Dictionary] = []
	for c in _carriers:
		c.pos += c.vel * delta
		c.life -= delta
		var hit := false
		for t in _targets:
			if c.pos.distance_to(t.pos) <= TARGET_R + CARRIER_R:
				_hit_target(t)
				_deploy(c.pos, c.vel, c.ring)
				hit = true
				break
		if hit:
			continue
		if c.life > 0.0 and BOUNDS.grow(20.0).has_point(c.pos):
			carriers_kept.append(c)   # 아직 안 맞음 — 계속 난다 (안 맞으면 전개 없음)
	_carriers = carriers_kept

	# ── 전개된 불 탄환: 화살표 방향으로 퍼지며 적을 맞힌다 ──
	var bolts_kept: Array[Dictionary] = []
	for s in _bolts:
		s.pos += s.vel * delta
		s.life -= delta
		var dead: bool = s.life <= 0.0 or not BOUNDS.grow(20.0).has_point(s.pos)
		for t in _targets:
			if s.pos.distance_to(t.pos) <= TARGET_R + BOLT_RADIUS:
				_hit_target(t)
				dead = true
				break
		if not dead:
			bolts_kept.append(s)
	_bolts = bolts_kept

	# ── 전개된 불기둥: 사는 동안 안의 과녁을 주기로 태운다 ──
	var pillars_kept: Array[Dictionary] = []
	for p in _pillars:
		p.life -= delta
		p.tick -= delta
		if p.tick <= 0.0:
			p.tick = PILLAR_TICK
			for t in _targets:
				if p.pos.distance_to(t.pos) <= p.r + TARGET_R:
					_hit_target(t)
		if p.life > 0.0:
			pillars_kept.append(p)
	_pillars = pillars_kept


func _reset_targets() -> void:
	for t in _targets:
		t.hits = 0
		t.flash = 0.0
	_carriers.clear()
	_bolts.clear()
	_pillars.clear()
	_set_ok("과녁 리셋")


# ─────────────────────────── 이벤트 ───────────────────────────

func _on_committed(assembly: Dictionary) -> void:
	_committed = assembly
	_refresh_result()


func _on_closed() -> void:
	_refresh_result()
	if _committed.is_empty():
		_set_hint("책을 덮었다 — E로 다시 펴서 맺어라")
	else:
		_set_hint("좌클릭/Space=발사 · 마우스=조준 · R=리셋")


func _refresh_result() -> void:
	if _committed.is_empty():
		_result_label.text = "맺힌 조립 없음 — E로 책을 펴세요"
		_result_label.add_theme_color_override(&"font_color", HINT_COLOR)
		return
	_result_label.text = "맺힘 → " + _describe(_committed)
	_result_label.add_theme_color_override(&"font_color", OK_COLOR)


func _describe(a: Dictionary) -> String:
	var rune := int(a.get("rune", 0))
	var rings: Array = a.get("rings", [])
	var ring: Array = rings[0] if not rings.is_empty() else []
	var counts := {RingBoard.G_GATHER: 0, RingBoard.G_RADIATE: 0}
	for g in ring:
		if int(g) != RingBoard.GLYPH_NONE:
			counts[int(g)] += 1
	var parts: Array[String] = []
	for gi in RingBoard.GLYPH_NAMES.size():
		if counts[gi] > 0:
			parts.append("%s×%d" % [RingBoard.GLYPH_NAMES[gi], counts[gi]])
	var rune_name := "불" if rune == RingBoard.RUNE_FIRE else "?"
	return "%s · [%s]" % [rune_name, "빈 칸" if parts.is_empty() else " ".join(parts)]


# ─────────────────────────── 세계 렌더 ───────────────────────────

func _draw_world() -> void:
	_world.draw_rect(get_viewport_rect(), BG_COLOR, true)
	_world.draw_rect(BOUNDS, Color(0.16, 0.20, 0.16), false, 2.0)

	var font := ThemeDB.fallback_font
	for t in _targets:
		var col: Color = TARGET_HIT if t.flash > 0.0 else TARGET_COLOR
		_world.draw_circle(t.pos, TARGET_R, col)
		_world.draw_arc(t.pos, TARGET_R, 0.0, TAU, 24, Color(0.9, 0.85, 0.8, 0.5), 1.0)
		if t.hits > 0:
			_world.draw_string(font, t.pos + Vector2(-4, -TARGET_R - 3),
				str(t.hits), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TEXT_COLOR)

	# 불기둥 (전개 결과)
	for p in _pillars:
		var t2: float = clampf(p.life / PILLAR_LIFE, 0.0, 1.0)
		_world.draw_circle(p.pos, p.r, Color(PILLAR_COLOR, 0.28 * t2))
		_world.draw_circle(p.pos, p.r * 0.6, Color(PILLAR_COLOR, 0.5 * t2))
		_world.draw_arc(p.pos, p.r, 0.0, TAU, 30, Color(PILLAR_COLOR, 0.9 * t2), 2.0)

	# 불 탄환 (전개 결과)
	for s in _bolts:
		_world.draw_circle(s.pos, BOLT_RADIUS, BOLT_COLOR)
		_world.draw_circle(s.pos, BOLT_RADIUS * 1.8, Color(BOLT_COLOR, 0.25))

	# 진(날아가는 마법진) — 작은 이중 고리로
	for c in _carriers:
		_world.draw_arc(c.pos, CARRIER_R, 0.0, TAU, 24, CARRIER_COLOR, 2.0)
		_world.draw_arc(c.pos, CARRIER_R * 0.5, 0.0, TAU, 16, Color(CARRIER_COLOR, 0.7), 1.5)

	# 플레이어 + 조준
	_world.draw_circle(_player_pos, 6.0, Color(0.85, 0.80, 0.70, 0.95))
	var col3: Color = Color(0.95, 0.65, 0.25, 0.85) if not _committed.is_empty() \
		else Color(0.6, 0.6, 0.6, 0.35)
	_world.draw_line(_player_pos + _aim * 10.0, _player_pos + _aim * 28.0, col3, 2.0)


# ─────────────────────────── HUD ───────────────────────────

func _label(parent: CanvasLayer, pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", TEXT_COLOR)
	parent.add_child(l)
	return l


func _set_ok(text: String) -> void:
	_result_label.text = text
	_result_label.add_theme_color_override(&"font_color", OK_COLOR)


func _set_warn(text: String) -> void:
	_result_label.text = text
	_result_label.add_theme_color_override(&"font_color", WARN_COLOR)


func _set_hint(text: String) -> void:
	_result_label.text = text
	_result_label.add_theme_color_override(&"font_color", HINT_COLOR)
