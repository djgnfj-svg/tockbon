extends Node2D
## 그리기→발사 시험대 (tests/test_forge.tscn 루트, F6 실행) — 리드 소유.
##
## **실제 게임과 같은 구조로 돌린다** (사용자 결정, 세션 8): 세계(아레나)가 항상 살아 있고,
## 작업대에 다가가 E로 **책을 펼쳐** 그린다. ESC로 책을 덮으면 그 자리에 세계가 그대로 있다 —
## 그린 도안을 곧바로 허수아비에 쏴 본다. 그리기와 쏘기 사이에 씬 전환이 없다는 게 핵심이다
## (GDD §10.5 · TECH_SPEC §4.4). 제작 UI 자체는 src/drawing/forge_panel.gd — 본편에 그대로 들어간다.
##
## 조작: WASD 이동 / 작업대 앞에서 E = 책 펼침 / ESC = 덮기
##       (책 펼친 중) 좌클릭 드래그 = 획 · 우클릭·Ctrl+Z = 취소 · 오른쪽 탭 = 책자 열람
##       (책 덮은 중) 마우스 = 조준 · 좌클릭/Space = 발사 · R = 허수아비 리셋 · C = 종이 비우기
##       **Tab = 지팡이 바꾸기** (단발 → 세 갈래 → 둘레) — v2.0 지팡이 축을 눈으로 보는 자리
##
## **v2.0에서 여기서 확인할 것**: (1) **보는 방향으로 나가는가** (2) **그린 진이 그대로 탄이 되는가**
## (3) **문양이 효과로 얹히는가** — 팅김+관통을 함께 그리면 **튕기면서 뚫는 탄 하나**
## (4) **도안을 안 고치고 지팡이만 바꿔도 나가는 그림이 달라지는가** (Tab)
##
## 개발용 시험대다 — 기본 무한 자원(마나·내구). 경제 검증은 본편·test_base_auto에서 한다.

const ForgePanel := preload("res://src/drawing/forge_panel.gd")
const DesignBuilder := preload("res://src/drawing/design_builder.gd")
const ExampleDesigns := preload("res://src/core/example_designs.gd")
const Copy := preload("res://src/drawing/drawing_copy.gd")
const SpellSystemScene := preload("res://src/spell/spell_system.tscn")
const DummyScene := preload("res://src/spell/dummy_target.tscn")

const BG_COLOR := Color(0.10, 0.14, 0.11)      # 어두운 숲 바닥 — 발광 먹선이 읽히는지 보려고
const TEXT_COLOR := Color(0.90, 0.86, 0.78)
const HINT_COLOR := Color(0.70, 0.66, 0.58)
const WARN_COLOR := Color(0.92, 0.45, 0.35)
const OK_COLOR := Color(0.60, 0.85, 0.55)
const PROMPT_COLOR := Color(0.98, 0.88, 0.55)
const WALL_COLOR := Color(0.22, 0.20, 0.19)    # 벽·기둥 — 팅김이 튕기는 면
const WALL_EDGE := Color(0.38, 0.35, 0.32)

# ── 세계 ──
const PLAYER_SPEED := 90.0
const PLAYER_START := Vector2(150, 290)
const BOUNDS := Rect2(14, 14, 612, 332)
const DESK_POS := Vector2(56, 300)             # 작업대(이젤) — 거점의 그 자리
const DESK_SIZE := Vector2(34, 40)
const INTERACT_RANGE := 46.0
const DUMMY_POS: Array[Vector2] = [
	Vector2(360, 70), Vector2(470, 44), Vector2(575, 80), Vector2(400, 160),
	Vector2(570, 175),
]

## 벽 (레이어 1 = world) — **팅김⚡을 눈으로 보려면 튕길 것이 있어야 한다** (v1.9).
## 아레나 테두리 + 가운데 기둥 둘. 기둥은 **엄폐물**이기도 하다: 뒤에 선 허수아비는
## 곧은 탄으로는 못 맞히고 **팅김으로 돌아가 맞힌다** — 그게 이 글자의 존재 이유다 (GDD §4.3).
const WALL_THICK := 10.0
const PILLAR_RECTS: Array[Rect2] = [
	Rect2(250, 110, 18, 90),    # 왼쪽 기둥 — 허수아비(400,160) 앞을 가린다
	Rect2(490, 105, 90, 16),    # 오른쪽 가로 기둥 — (570,175)를 위에서 덮는다
]

var _world: Node2D
var _forge: Control
var _player_pos: Vector2 = PLAYER_START
var _aim: Vector2 = Vector2.UP
var _dummies: Array[Node2D] = []
var _infinite := true

var _cast_label: Label
var _design_label: Label
var _hint_label: Label

# ── 예시 카탈로그 (숫자키로 불러와 바로 쏜다 — 복합·중첩을 그리기 없이 확인) ──
var _catalog: Array = []
var _loaded: SpellDesign = null     # 불러온 예시 (있으면 이걸 쏜다), null이면 그린 도안


func _ready() -> void:
	_catalog = ExampleDesigns.catalog()
	_build_world()
	_build_forge()
	_build_hud()
	# 시험대는 자원이 말라 검증이 끊기면 안 된다 — 종이를 넉넉히 시드
	if GameState.get_count(&"paper_1") < 20:
		GameState.add_item(&"paper_1", 99)
	EventBus.cast_executed.connect(_on_cast_executed)
	EventBus.cast_failed.connect(_on_cast_failed)
	EventBus.enemy_hit.connect(_on_enemy_hit)
	_refresh_design_label()
	# 카탈로그 목록을 상단에 한 줄로 — 무엇을 불러올 수 있는지 보인다
	var names: Array[String] = []
	for i in _catalog.size():
		names.append("%d.%s" % [i + 1, _catalog[i].name])
	_cast_label.text = "예시: " + "  ".join(names)
	_cast_label.add_theme_color_override(&"font_color", PROMPT_COLOR)


func _process(delta: float) -> void:
	if _infinite:
		GameState.mana = GameState.mana_max()
	# 책을 펼친 동안 세계는 멈춘다 — 붓을 든 손으로 걷거나 쏘지 않는다
	if not _forge.call(&"is_open"):
		var dir := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
		if dir != Vector2.ZERO:
			_player_pos = (_player_pos + dir.normalized() * PLAYER_SPEED * delta) \
				.clamp(BOUNDS.position, BOUNDS.end)
		var to_mouse := get_global_mouse_position() - _player_pos
		if to_mouse.length_squared() > 1.0:
			_aim = to_mouse.normalized()
	_world.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _forge.call(&"is_open"):
		return                                  # 책이 펼쳐져 있으면 세계는 입력을 받지 않는다
	if event.is_action_pressed(&"interact") and _near_desk():
		_forge.call(&"open")
		get_viewport().set_input_as_handled()
		return
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		match k.keycode:
			KEY_SPACE:
				_try_cast()
			KEY_R:
				_reset_dummies()
			KEY_C:
				_forge.call(&"clear_canvas")
				_loaded = null
				_refresh_design_label()
			KEY_TAB:
				_cycle_wand()
			KEY_0:
				_loaded = null
				_set_hint("예시 해제 — 그린 도안을 쏜다")
				_refresh_design_label()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				_load_example(k.keycode - KEY_1)
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_try_cast()


## **같은 도안을 지팡이만 바꿔 쏴 본다** (Tab) — v2.0 지팡이 축을 눈으로 보는 자리다.
## 도안은 "무엇이 나가는가"만 정하고 **"어디로 몇 발"은 지팡이가 정한다**:
## 단발 → 세 갈래(산탄) → 둘레(전방위). 도안을 한 줄도 안 고쳤는데 나가는 그림이 달라진다.
const WANDS: Array[StringName] = [&"wand_basic", &"wand_fork", &"wand_ring"]

func _cycle_wand() -> void:
	var cur: StringName = GameState.equipment.get(Enums.ItemKind.WAND, &"")
	var idx := WANDS.find(cur)
	var next: StringName = WANDS[(idx + 1) % WANDS.size()]
	# 시험대는 창고 재고를 거치지 않는다 (equip_gear는 창고에서 1개 차감한다) — 직접 꽂는다
	GameState.equipment[Enums.ItemKind.WAND] = next
	var def: ItemDef = Db.get_item(next)
	_set_hint("지팡이: %s — 도안은 그대로다. 나가는 건 지팡이가 정한다 (Tab)"
		% (def.display_name if def != null else String(next)))


func _near_desk() -> bool:
	return _player_pos.distance_to(DESK_POS) <= INTERACT_RANGE


## 장착 슬롯을 거치지 않고 **지금 종이 위에 맺힌 도안**을 그대로 쏜다 — 그리자마자 검증하려고.
## 계약은 게임과 동일하다: cast_requested(도안, 원점, 에임) → spell_system이 전부 처리.
func _try_cast() -> void:
	# 예시를 불러왔으면 그걸, 아니면 종이에 그린 도안을 쏜다
	var design: SpellDesign = _loaded if _loaded != null else _forge.call(&"get_design")
	if design == null:
		_set_warn(Copy.INCOMPLETE)
		return
	if _infinite:
		design.durability = design.durability_max
	EventBus.cast_requested.emit(design, _player_pos, _aim)
	_report_aim(design)


## 숫자키로 예시 마법진을 불러온다 — 그리기 없이 복합·중첩을 바로 쏴 본다.
func _load_example(idx: int) -> void:
	if idx < 0 or idx >= _catalog.size():
		return
	var entry: Dictionary = _catalog[idx]
	_loaded = entry.design as SpellDesign
	_set_hint("예시 %d: %s — 좌클릭/Space로 발사 · 0=예시 해제" % [idx + 1, entry.name])
	_design_label.text = "★ 예시 %d: %s · %s" % [idx + 1, entry.name, _composition(_loaded)]
	_design_label.add_theme_color_override(&"font_color", PROMPT_COLOR)


## 책 펼친 중 숫자키 → 그 예시를 **탁본**으로 캔버스에 깐다. 그 위에 필사(따라 그리기)한다.
func _on_example_requested(idx: int) -> void:
	if idx < 0 or idx >= _catalog.size():
		return
	var entry: Dictionary = _catalog[idx]
	_forge.call(&"show_rubbing", entry.design as SpellDesign)
	_set_hint("필사 %d: %s — 탁본을 따라 진·룬·문양을 그리세요 (0=탁본 걷기)"
		% [idx + 1, entry.name])


## 예시 구성 한 줄 — 룬(복합)·안쪽 진(중첩)을 보여 준다
func _composition(d: SpellDesign) -> String:
	var runes: Array[String] = []
	for r: RuneInstance in d.rune_list():
		runes.append(DesignBuilder.rune_name(r.type))
	var s := "룬 " + "+".join(runes)
	if not d.children.is_empty():
		s += " · 안쪽 %d진" % d.children.size()
	return s


## **이 도안이 실제로 무엇을 쏘는가** — 한 줄로 보인다.
##
## 🔴 **v2.0에서 볼 것이 바뀌었다.** 발사각은 이제 **언제나 에임**이라(지팡이가 정한다)
## "그린 방향 vs 날아간 방향"을 견줄 것이 없다 — 어긋날 수가 없는 구조가 됐다.
## 대신 봐야 할 것은 **"내가 그린 문양들이 한 탄에 어떤 효과로 얹혔는가"**다:
## 문양 3개를 그렸는데 효과가 2종이면 하나가 BASIC(글자 인식 실패)으로 샌 것이고,
## 팅김을 둘 그었는데 세기가 안 늘면 합산이 깨진 것이다.
##
## (세션 7의 "모든 문양이 90도 틀어져 나갔다" · 세션 11의 "관통이 14도 빗나갔다"는
##  둘 다 **테스트가 전부 초록인 채로** 숨어 있었다 — 눈으로 볼 수 있어야 잡힌다.
##  방향이 지팡이로 가면서 그 버그 계열은 **구조적으로 사라졌다.**)
const GLYPH_MARK := {
	Enums.GlyphType.BOUNCE: "팅김⚡",
	Enums.GlyphType.HOMING: "유도∿",
	Enums.GlyphType.PIERCE: "관통‖",
}

func _report_aim(design: SpellDesign) -> void:
	if design.arrows.is_empty():
		return
	var system := _world.get_node_or_null("SpellSystem")
	if system == null:
		return
	var effects: Dictionary = system.call(&"compile_effects", design)
	var parts: Array[String] = []
	for glyph: int in effects:
		parts.append("%s×%.1f" % [GLYPH_MARK.get(glyph, "?"), float(effects[glyph])])
	# v2.1: 곧은 화살표는 **착탄 충격파**를 뿜는다 — 몇 개를 뿜는지 눈에 보여야
	# "모아 그리면 기둥이 선다"를 확인할 수 있다
	var waves := 0
	for a: ArrowData in design.arrows:
		if a.glyph == Enums.GlyphType.BASIC:
			waves += 1
	if waves > 0:
		parts.append("충격파×%d" % waves)
	if parts.is_empty():
		parts.append("효과 없음")
	# 사거리는 문양 reach의 **최댓값**이 정한다 — 합이 아니다 (합이면 효과를 얹을수록 공짜로 는다).
	# 발수는 **지팡이**가 정한다 — 도안은 발수에 아무 말도 하지 않는다 (v2.0)
	var shots: Array = system.call(&"wand_shots", _aim.angle())
	var wand: ItemDef = Db.get_item(GameState.equipment.get(Enums.ItemKind.WAND, &""))
	_hint_label.text = "조준 %+.0f° · %s %d발 · 효과 %s · 사거리 %.1f×" % [
		rad_to_deg(_aim.angle()),
		wand.display_name if wand != null else "맨손",
		shots.size(),
		" ".join(parts),
		float(system.call(&"design_reach", design)),
	]
	_hint_label.add_theme_color_override(&"font_color", OK_COLOR)


# ─────────────────────────── 세계 ───────────────────────────

func _build_world() -> void:
	_world = Node2D.new()
	_world.name = "World"
	_world.draw.connect(_draw_world)
	add_child(_world)

	# spell_system은 게임 씬과 동일한 인스턴스 — 마법진·투사체가 여기서 나온다
	_world.add_child(SpellSystemScene.instantiate())

	_build_walls()

	for p: Vector2 in DUMMY_POS:
		var d := DummyScene.instantiate() as Node2D
		d.global_position = p
		_world.add_child(d)
		_dummies.append(d)


## 벽 = 레이어 1(world). 투사체 마스크가 1|3이라 **곧은 탄은 여기서 죽고 팅김은 튕긴다**.
## 테두리는 BOUNDS 바깥에 둘러 세워 플레이어 이동 범위(BOUNDS clamp)와 어긋나지 않게 한다.
func _build_walls() -> void:
	var b := BOUNDS
	var rects: Array[Rect2] = [
		Rect2(b.position.x, b.position.y - WALL_THICK, b.size.x, WALL_THICK),              # 위
		Rect2(b.position.x, b.end.y, b.size.x, WALL_THICK),                                # 아래
		Rect2(b.position.x - WALL_THICK, b.position.y - WALL_THICK,
			WALL_THICK, b.size.y + WALL_THICK * 2.0),                                      # 왼
		Rect2(b.end.x, b.position.y - WALL_THICK,
			WALL_THICK, b.size.y + WALL_THICK * 2.0),                                      # 오른
	]
	rects.append_array(PILLAR_RECTS)
	for r: Rect2 in rects:
		var body := StaticBody2D.new()
		body.collision_layer = 1      # world
		body.collision_mask = 0       # 벽은 아무것도 안 쫓는다 — 맞기만 한다
		body.global_position = r.get_center()
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		body.add_child(cs)
		_world.add_child(body)


func _build_forge() -> void:
	var layer := CanvasLayer.new()               # 세계 위에 얹힌다 — 씬 전환이 아니라 오버레이
	layer.name = "ForgeLayer"
	add_child(layer)
	_forge = ForgePanel.new()
	layer.add_child(_forge)
	_forge.connect(&"design_completed", _on_design_completed)
	_forge.connect(&"closed", _on_forge_closed)
	_forge.connect(&"example_requested", _on_example_requested)


func _reset_dummies() -> void:
	for d in _dummies:
		if is_instance_valid(d) and d.has_method("reset_hits"):
			d.call("reset_hits")
	_cast_label.text = "허수아비 리셋"
	_cast_label.add_theme_color_override(&"font_color", HINT_COLOR)


func _draw_world() -> void:
	_world.draw_rect(get_viewport_rect(), BG_COLOR, true)

	# 벽·기둥 — 팅김⚡이 튕기는 면. **보이지 않으면 왜 튕겼는지 알 수 없다.**
	# 기둥 뒤 허수아비는 곧은 탄으로 못 맞힌다 — 팅김으로 돌아가 맞히라는 문제 제기다
	var b := BOUNDS
	_world.draw_rect(b.grow(WALL_THICK * 0.5), WALL_COLOR, false, WALL_THICK)
	for r: Rect2 in PILLAR_RECTS:
		_world.draw_rect(r, WALL_COLOR, true)
		_world.draw_rect(r, WALL_EDGE, false, 1.0)

	# 작업대 — 거점의 이젤 자리. 다가가면 프롬프트가 뜬다
	var desk := Rect2(DESK_POS - DESK_SIZE * 0.5, DESK_SIZE)
	var near := _near_desk()
	_world.draw_rect(desk, Color(0.30, 0.24, 0.17), true)
	_world.draw_rect(desk, PROMPT_COLOR if near else Color(0.48, 0.40, 0.30),
		false, 1.0)
	# 이젤 위의 종이
	_world.draw_rect(Rect2(desk.position + Vector2(5, 5), Vector2(24, 22)),
		Color(0.88, 0.84, 0.75), true)
	if near and not _forge.call(&"is_open"):
		var font := ThemeDB.fallback_font
		var text := Copy.FORGE_OPEN
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		_world.draw_string(font, DESK_POS + Vector2(-w * 0.5, -DESK_SIZE.y * 0.5 - 6.0),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, PROMPT_COLOR)

	# 플레이어 — 캐스팅 원점
	_world.draw_circle(_player_pos, 5.0, Color(0.85, 0.80, 0.70, 0.95))
	_world.draw_arc(_player_pos, 9.0, 0.0, TAU, 24, Color(0.85, 0.80, 0.70, 0.35), 1.0)
	# 에임 — 진은 한 종류다. 도안은 **항상** 이 방향으로 통째로 회전한다 (캔버스 위쪽 = 앞)
	var has_design: bool = _forge.call(&"get_design") != null
	var col: Color = Color(0.95, 0.65, 0.25, 0.8) if has_design \
		else Color(0.6, 0.6, 0.6, 0.35)
	_world.draw_line(_player_pos + _aim * 11.0, _player_pos + _aim * 26.0, col, 1.5)


# ─────────────────────────── 이벤트 ───────────────────────────

func _on_design_completed(_design: SpellDesign) -> void:
	_refresh_design_label()


## 책을 덮었다 — 이제 쏴 볼 차례다. 그 말을 그 자리에서 해 준다
func _on_forge_closed() -> void:
	_refresh_design_label()
	var design: SpellDesign = _forge.call(&"get_design")
	if design != null:
		_set_hint("좌클릭/Space = 발사 · 마우스 = 조준 · R = 리셋")
	else:
		_set_hint("작업대(E)로 돌아가 도안을 맺어라 · WASD 이동")


func _on_cast_executed(_design_c: SpellDesign, mana: float) -> void:
	_cast_label.text = "발사 — 마나 %.0f 소모" % mana
	_cast_label.add_theme_color_override(&"font_color", OK_COLOR)


func _on_cast_failed(_design_c: SpellDesign, reason: int) -> void:
	var why: String = {
		Enums.CastFailReason.NO_MANA: "마나 부족",
		Enums.CastFailReason.BROKEN: "도안 손상 (내구 0)",
		Enums.CastFailReason.INVALID: "도안 무효 (문양 없음)",
	}.get(reason, "?")
	_cast_label.text = "발사 실패 — %s" % why
	_cast_label.add_theme_color_override(&"font_color", WARN_COLOR)


func _on_enemy_hit(_enemy: Node2D, damage: float, rune_type: int) -> void:
	_cast_label.text = "명중! %s · 피해 %.1f" % [DesignBuilder.rune_name(rune_type), damage]
	_cast_label.add_theme_color_override(&"font_color", OK_COLOR)


## 도안 상태 — **v1.9의 검증 표면이다.** "내가 그린 지그재그가 팅김으로 읽혔는가,
## 그리고 얼마나 세게(멀리) 나가는가"를 발사 전에 눈으로 확인할 수 있어야 한다.
##
## ~~곡률(휨)~~ 표시는 **뺐다** — v1.9가 궤적을 폐기했으므로(GDD §4.3) 그 숫자는 이제
## 전투에서 아무것도 정하지 않는다. **아무 일도 안 하는 값을 계속 보여 주면 거짓말이 된다.**
## 그 자리에 **문양별 글자·세기(reach)**를 보여 준다.
func _refresh_design_label() -> void:
	var design: SpellDesign = _forge.call(&"get_design")
	if design == null:
		_design_label.text = "도안 없음 — 작업대(E)에서 진·룬·문양을 그린다"
		_design_label.add_theme_color_override(&"font_color", HINT_COLOR)
		return
	# 문양 하나하나를 낱개로 — "1개는 팅김으로 읽혔는데 2개째는 기본으로 떨어졌다"가 보여야 한다
	var parts: Array[String] = []
	for a: ArrowData in design.arrows:
		parts.append("%s %.1f" % [Copy.glyph_label(a.glyph), a.reach])
	_design_label.text = "%s · 정확도 %d%% · 마나 %.0f · [%s]" % [
		design.display_name,
		roundi(design.rune_accuracy * 100.0),
		design.mana_cost,
		" / ".join(parts),
	]
	_design_label.add_theme_color_override(&"font_color", OK_COLOR)


# ─────────────────────────── HUD ───────────────────────────

func _build_hud() -> void:
	# 세계(Node2D) 위, 제작대(CanvasLayer) 아래 — 책을 펼치면 HUD도 함께 덮인다
	var ui := Control.new()
	ui.name = "HUD"
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)

	_cast_label = _label(ui, Vector2(8, 6), Vector2(400, 14), 10)
	_design_label = _label(ui, Vector2(8, 22), Vector2(500, 14), 9)
	_hint_label = _label(ui, Vector2(8, 342), Vector2(620, 14), 9)
	_set_hint("이동 WASD · E=책 · 좌클릭/Space=발사 · Tab=지팡이 · 숫자=예시(책 닫힘:발사 / 펼침:탁본 필사) · 0=해제")


func _label(parent: Control, pos: Vector2, sz: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", TEXT_COLOR)
	parent.add_child(l)
	return l


func _set_hint(text: String) -> void:
	_hint_label.text = text
	_hint_label.add_theme_color_override(&"font_color", HINT_COLOR)


func _set_warn(text: String) -> void:
	if text == "":
		return
	_hint_label.text = text
	_hint_label.add_theme_color_override(&"font_color", WARN_COLOR)
