extends Node2D
## 고리 조립 제작대 **통합 시험대** (tests/test_ring_forge_panel.tscn, F6) — 리드 소유.
##
## 옛 test_forge와 같은 결: 세계(아레나)가 늘 살아 있고, E로 책을 펼쳐 **조립**하고, ESC로
## 덮으면 그 자리에서 **쏜다**.
##
## 🔴 발사 = **실제 시스템**이다 (세션 12, #16). 자체 시뮬이 아니라 `EventBus.ring_cast_requested`
## → `ring_spell_system` → **진(캐리어)이 날아가 실제 허수아비(take_hit)에 닿으면 전개**:
##   • 발산→ 칸: 그 방향으로 불 탄환 (projectile.tscn)
##   • 응집← 칸: 착탄점에 불기둥 하나 (pillar.tscn, 많을수록 굵다)
##   • 빈 진도 몸으로 때린다 · 안 맞으면 전개 없음
##
## 조작: (책 펼침) 왼쪽 판에 유령을 손으로 따라 그으기(진→룬→문양) · Q·W=문양 고르기 · ✓맺기/ESC=덮기
##       (책 덮음) WASD=이동 · 마우스=조준 · 좌클릭/Space=발사 · R=과녁 리셋 · E=책 펴기 · C=보드 비우기

const RingForgePanelScript := preload("res://src/drawing/ring_forge_panel.gd")
const ForgeScene := preload("res://src/drawing/ring_forge_panel.tscn")
const RingBoard := preload("res://src/drawing/ring_board.gd")
const RingSpellScene := preload("res://src/spell/ring_spell_system.tscn")
const DummyScene := preload("res://src/spell/dummy_target.tscn")

const BG_COLOR := Color(0.10, 0.14, 0.11)
const TEXT_COLOR := Color(0.90, 0.86, 0.78)
const OK_COLOR := Color(0.60, 0.85, 0.55)
const WARN_COLOR := Color(0.92, 0.45, 0.35)
const HINT_COLOR := Color(0.70, 0.66, 0.58)

# ── 세계 ──
const PLAYER_SPEED := 90.0
const PLAYER_START := Vector2(150, 250)
const BOUNDS := Rect2(14, 40, 612, 306)
const TARGET_POS: Array[Vector2] = [
	Vector2(360, 90), Vector2(470, 70), Vector2(560, 110),
	Vector2(410, 190), Vector2(540, 210),
]

var _forge: RingForgePanelScript
var _world: Node2D
var _system: Node2D            # 실제 ring_spell_system (발사·전개를 담당)
var _enemies: Array = []       # 실제 dummy_target 노드
var _player_pos: Vector2 = PLAYER_START
var _aim: Vector2 = Vector2.UP
var _committed: Dictionary = {}

var _title_label: Label
var _result_label: Label
var _hint_label: Label


func _ready() -> void:
	# 실제 발사 시스템 — 진·탄·기둥이 이 노드의 자식으로 스폰된다 (월드 좌표)
	# 🔴 z_index를 올려 아레나 배경(World, z=0) **위에** 그린다 — 안 그러면 발사체가 배경 뒤에
	# 가려 안 보인다 (세션 13에 발견: _system이 _world보다 먼저 add_child돼 덮였다).
	_system = RingSpellScene.instantiate()
	_system.z_index = 10
	add_child(_system)

	_world = Node2D.new()
	_world.name = "World"
	_world.draw.connect(_draw_world)
	add_child(_world)

	_spawn_enemies()

	var ui := CanvasLayer.new()
	add_child(ui)
	_title_label = _label(ui, Vector2(8, 6), 11)
	_title_label.text = "고리 조립 제작대 — 통합 시험대 (F6) · 실제 시스템 발사 · 진이 날아가 히트하면 전개"
	_result_label = _label(ui, Vector2(8, 22), 10)
	_hint_label = _label(ui, Vector2(8, 344), 8)
	_hint_label.text = "책 펼침: 왼쪽 판에 손으로 따라 그으기(진→룬→문양) · Q·W=문양 고르기 · ✓맺기/ESC=덮기   |   덮음: WASD·마우스=조준 · 좌클릭/Space=발사 · R=리셋 · E=책 · C=비움"
	_hint_label.add_theme_color_override(&"font_color", HINT_COLOR)

	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_forge = ForgeScene.instantiate() as RingForgePanelScript
	layer.add_child(_forge)
	_forge.design_committed.connect(_on_committed)
	_forge.closed.connect(_on_closed)
	_forge.open()
	_refresh_result()


func _process(_delta: float) -> void:
	if not _forge.is_open():
		var dir := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
		if dir != Vector2.ZERO:
			_player_pos = (_player_pos + dir.normalized() * PLAYER_SPEED * _delta) \
				.clamp(BOUNDS.position, BOUNDS.end)
		var to_mouse := get_global_mouse_position() - _player_pos
		if to_mouse.length_squared() > 1.0:
			_aim = to_mouse.normalized()
	_world.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _forge.is_open():
		return
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		match k.keycode:
			KEY_E:
				_forge.open()
			KEY_SPACE:
				_fire()
			KEY_R:
				_reset_targets()
			KEY_C:
				_forge.clear_board()
				_committed = {}
				_refresh_result()
		get_viewport().set_input_as_handled()
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_fire()
		get_viewport().set_input_as_handled()


# ─────────────────────────── 발사 = 실제 시스템에 요청한다 ───────────────────────────

func _fire() -> void:
	var a: Dictionary = _forge.get_assembly()
	if a.is_empty():
		if _forge.can_commit():
			_set_warn("조립은 됐다 — E로 책을 펴서 ✓맺기(또는 ESC로 덮으면 자동 맺힘)")
		else:
			_set_warn("진과 룬을 손으로 그려 맺어야 쏜다 (E)")
		return
	# 🔴 실제 발사 — ring_spell_system이 받아 진(캐리어)을 조준 방향으로 쏜다.
	EventBus.ring_cast_requested.emit(a, _player_pos, _aim)
	_forge.play_cast()
	_set_ok("발사 — 마법진이 날아간다 (%s) · 맞으면 전개" % _describe(a))


func _spawn_enemies() -> void:
	for p: Vector2 in TARGET_POS:
		var e := DummyScene.instantiate()
		_world.add_child(e)
		e.global_position = p
		_enemies.append(e)


func _reset_targets() -> void:
	for e in _enemies:
		if is_instance_valid(e):
			e.queue_free()
	_enemies.clear()
	# 날아다니던 진·탄·기둥도 치운다
	for c in _system.get_children():
		c.queue_free()
	for n in get_tree().get_nodes_in_group("pillars"):
		n.queue_free()
	_spawn_enemies()
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
	# 🔴 세82: 이름의 정본은 GlyphDef.display_name (옛 RingBoard.GLYPH_NAMES 배열 은퇴).
	# 놓인 코드만 세므로 어휘 길이에 의존하지 않는다 — 문양이 늘어도 여길 안 고쳐도 된다.
	var counts := {}
	for g in ring:
		if int(g) != RingBoard.GLYPH_NONE:
			counts[int(g)] = int(counts.get(int(g), 0)) + 1
	var codes: Array = counts.keys()
	codes.sort()
	var parts: Array[String] = []
	for gi in codes:
		var gd = Db.glyph_by_code(int(gi))
		parts.append("%s×%d" % [gd.display_name if gd != null else "문양%d" % gi, counts[gi]])
	var rune_name := "불" if rune == RingBoard.RUNE_FIRE else "?"
	return "%s · [%s]" % [rune_name, "빈 칸" if parts.is_empty() else " ".join(parts)]


# ─────────────────────────── 세계 렌더 (배경·플레이어·조준만 — 적·탄·기둥은 각자 그린다) ───────────────────────────

func _draw_world() -> void:
	_world.draw_rect(get_viewport_rect(), BG_COLOR, true)
	_world.draw_rect(BOUNDS, Color(0.16, 0.20, 0.16), false, 2.0)

	# 플레이어 + 조준
	_world.draw_circle(_player_pos, 6.0, Color(0.85, 0.80, 0.70, 0.95))
	var col: Color = Color(0.95, 0.65, 0.25, 0.85) if not _committed.is_empty() \
		else Color(0.6, 0.6, 0.6, 0.35)
	_world.draw_line(_player_pos + _aim * 10.0, _player_pos + _aim * 28.0, col, 2.0)


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
