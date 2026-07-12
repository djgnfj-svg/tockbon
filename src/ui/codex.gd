extends Control
## 도감 — 룬(4종 해금/실루엣)·적(약점)·제법 3탭 (모듈 E).
## 해금 판정은 GameState.is_unlocked만 사용. ui_codex(Tab) 토글은 ui_root가 담당.

signal closed

const InkStyle := preload("res://src/ui/ink_style.gd")

const RUNE_ORDER: Array[int] = [
	Enums.RuneType.FIRE, Enums.RuneType.IMPACT, Enums.RuneType.WATER, Enums.RuneType.WIND,
]
const RUNE_DESCS := {
	Enums.RuneType.FIRE: "화상 — 닿은 자리에 오래 타는 먹불을 남긴다.",
	Enums.RuneType.IMPACT: "넉백 — 한 점을 세게 두드려 밀쳐낸다.",
	Enums.RuneType.WATER: "젖음 — 둔화시키고 갑주를 무르게 한다.",
	Enums.RuneType.WIND: "흐름 — 넓게 번져 자리를 다스린다.",
}
## MVP 제법 목록 — 인스턴스 데이터(모듈 D)가 갖춰지면 Db 조회로 대체
const KNOWN_RECIPES: Array[Dictionary] = [
	{"id": &"recipe_paper_2", "name": "중급 종이 제법", "desc": "밤 재료로 뜬 종이 — 잉크 상한이 늘어난다."},
	{"id": &"recipe_paper_3", "name": "상급 종이 제법", "desc": "가장 질긴 종이 — 내구와 마나 감면이 붙는다."},
]

@onready var _rune_list: VBoxContainer = %RuneList
@onready var _enemy_list: VBoxContainer = %EnemyList
@onready var _recipe_list: VBoxContainer = %RecipeList
@onready var _close_button: Button = %CloseButton

func _ready() -> void:
	_close_button.pressed.connect(func() -> void: closed.emit())

func open() -> void:
	visible = true
	refresh()

func refresh() -> void:
	_refresh_runes()
	_refresh_enemies()
	_refresh_recipes()

# ── 룬 탭

func _refresh_runes() -> void:
	InkStyle.clear_children(_rune_list)
	for t: int in RUNE_ORDER:
		_rune_list.add_child(_make_rune_row(t))

func _make_rune_row(t: int) -> Control:
	var unlocked := GameState.is_unlocked(InkStyle.rune_unlock_id(t))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _row_style(unlocked))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var glyph := InkStyle.make_label(
		InkStyle.rune_glyph(t) if unlocked else "?",
		16,
		InkStyle.rune_color(t) if unlocked else InkStyle.INK_FAINT)
	glyph.custom_minimum_size = Vector2(26, 0)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(glyph)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	if unlocked:
		col.add_child(InkStyle.make_label("%s의 룬" % InkStyle.rune_name(t), 10))
		col.add_child(InkStyle.make_label(RUNE_DESCS[t], 8, InkStyle.INK_SOFT))
	else:
		col.add_child(InkStyle.make_label("???", 10, InkStyle.INK_FAINT))
		col.add_child(InkStyle.make_label("아직 해독하지 못한 글자다.", 8, InkStyle.INK_FAINT))
	row.add_child(col)

	panel.add_child(row)
	return panel

# ── 적 탭

func _refresh_enemies() -> void:
	InkStyle.clear_children(_enemy_list)
	if Db.enemies.is_empty():
		_enemy_list.add_child(InkStyle.make_label("기록된 적이 없다.", 9, InkStyle.INK_FAINT))
		return
	for id: StringName in Db.enemies:
		var def: EnemyDef = Db.enemies[id]
		_enemy_list.add_child(_make_enemy_row(def))

func _make_enemy_row(def: EnemyDef) -> Control:
	var unlocked := GameState.is_unlocked(InkStyle.enemy_unlock_id(def.id))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _row_style(unlocked))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	if unlocked:
		var display := def.display_name if not def.display_name.is_empty() else String(def.id)
		if def.is_elite:
			display = "◆ " + display
		var name_l := InkStyle.make_label(display, 10)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		row.add_child(InkStyle.make_label(
			"약점 %s %s" % [InkStyle.rune_glyph(def.counter_rune), InkStyle.rune_name(def.counter_rune)],
			9, InkStyle.rune_color(def.counter_rune)))
	else:
		var name_l := InkStyle.make_label("???", 10, InkStyle.INK_FAINT)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		row.add_child(InkStyle.make_label("숲에서 아직 만나지 못했다", 8, InkStyle.INK_FAINT))

	panel.add_child(row)
	return panel

# ── 제법 탭

func _refresh_recipes() -> void:
	InkStyle.clear_children(_recipe_list)
	var listed: Array[StringName] = []
	for recipe: Dictionary in KNOWN_RECIPES:
		var id: StringName = recipe["id"]
		listed.append(id)
		_recipe_list.add_child(_make_recipe_row(
			String(recipe["name"]), String(recipe["desc"]), GameState.is_unlocked(id)))
	# 목록 밖의 해금 제법 (모듈 D가 추가한 것) — id 그대로 노출
	for key: Variant in GameState.codex:
		var s := String(key)
		if s.begins_with("recipe_") and StringName(s) not in listed:
			_recipe_list.add_child(_make_recipe_row(s, "연구소에서 해독한 제법.", true))

func _make_recipe_row(name_text: String, desc: String, unlocked: bool) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _row_style(unlocked))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	if unlocked:
		col.add_child(InkStyle.make_label(name_text, 10))
		col.add_child(InkStyle.make_label(desc, 8, InkStyle.INK_SOFT))
	else:
		col.add_child(InkStyle.make_label("??? (미해독)", 10, InkStyle.INK_FAINT))
		col.add_child(InkStyle.make_label("탁본 조각을 연구소에서 해독하면 드러난다.", 8, InkStyle.INK_FAINT))
	panel.add_child(col)
	return panel

## 해금 행 = 한지, 미해금 행 = 바랜 그늘 (실루엣)
func _row_style(unlocked: bool) -> StyleBoxFlat:
	if unlocked:
		return InkStyle.make_panel(InkStyle.PAPER_DARK, InkStyle.INK_FAINT, 1, 2, 8, 4)
	return InkStyle.make_panel(InkStyle.PAPER_SHADOW, InkStyle.INK_FAINT, 1, 2, 8, 4)
