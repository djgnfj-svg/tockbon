extends Control
## 공방 — 재료를 **장비**로 만들고(제작), 만든 장비를 **착용/해제**한다 (세션32, 백로그 장비 제작).
## 베이스 공방 지점 [E]로 연다. 정제대(잉크·종이)와 형제지만 다루는 물건이 달라 별도 벤치다.
##
## 🔴 왜 별도인가: 사용자 확정("별도 공방 스테이션"). 정제대는 소모품(잉크·종이), 공방은 장비.
## 레시피는 `station`으로 갈린다 — 공방은 &"craft"만, 정제대는 &"refine"만 (Db.recipes_for_station).
##
## 🔴 왜 장착을 여기 두나: 창고(I) 패널은 `_draw` 전용이라 버튼을 못 단다. 장비를 손에 넣는 곳과
## 몸에 맞추는 곳을 한 벤치로 묶는다(몬헌식). `equip_gear`/`unequip_gear`가 이미 창고 차감·반환·
## 상한 클램프까지 쥐고 있어(GameState) — 이 패널은 나열·버튼뿐이다.
##
## 🔴 **모달** — refine_panel과 같은 규약: 열리면 GameState.ui_modal_open을 켜 발사·이동·창고와
## 겹치지 않게 하고, mouse_filter=STOP으로 좌클릭을 통째로 먹는다. ESC로 닫고 closed를 쏜다.
## CanvasLayer(base.gd가 씌운다) 위에 산다 — 카메라 추적 무관.
##
## 계약: open() / closed 시그널. base.gd가 InteractZone(zone_id=craft)에서 연다.

signal closed

const BACKDROP := Color(0.03, 0.025, 0.02, 0.82)
const NAME_COLOR := Color(0.94, 0.90, 0.80)
const HINT_COLOR := Color(0.66, 0.62, 0.54)
const HAVE_COLOR := Color(0.62, 0.80, 0.52)
const SHORT_COLOR := Color(0.86, 0.46, 0.40)
const SECTION_COLOR := Color(0.86, 0.80, 0.66)
const EQUIPPED_COLOR := Color(0.98, 0.86, 0.52)
const ROW_BG := Color(0.17, 0.15, 0.12, 0.95)
const EQUIPPED_ROW_BG := Color(0.20, 0.18, 0.11, 0.98)

## 착용 부위 — 표시 순서·라벨. PEN을 앞에 둔다(공방을 여는 주된 이유가 펜이라).
const EQUIP_KINDS: Array = [
	[Enums.ItemKind.PEN, "펜"],
	[Enums.ItemKind.WAND, "지팡이"],
	[Enums.ItemKind.ROBE, "로브"],
	[Enums.ItemKind.CHARM, "부적"],
]

@onready var _list: VBoxContainer = $Center/Panel/Margin/VBox/Scroll/List


func _ready() -> void:
	# 화면을 덮는 모달 — STOP이라 열린 동안 좌클릭을 통째로 먹는다(뒤에서 실수로 안 쏜다).
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	EventBus.resources_changed.connect(_on_changed)
	EventBus.equipment_changed.connect(_on_changed)
	draw.connect(_on_draw)


func open() -> void:
	if visible:
		return
	visible = true
	GameState.ui_modal_open = true
	_refresh()
	queue_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	GameState.ui_modal_open = false
	closed.emit()


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_changed() -> void:
	if visible:
		_refresh()


## 배경(어둠) — 카드 판은 씬 노드(Center/Panel)가 그린다.
func _on_draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP, true)


## 두 구역을 다시 짓는다 — ① 제작(공방 레시피) ② 장착(착용 중 + 보유 장비).
## 보유·착용이 바뀌면(제작·장착·해제) resources_changed/equipment_changed가 여길 다시 부른다.
func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()

	_list.add_child(_section_label("제작"))
	var recipes: Array = Db.recipes_for_station(&"craft")
	if recipes.is_empty():
		_list.add_child(_hint_label("만들 수 있는 장비가 없다 (data/recipes 비어 있음)"))
	else:
		for r: RecipeDef in recipes:
			_list.add_child(_make_recipe_row(r))

	_list.add_child(_section_label("장착"))
	_add_equip_rows()


# ─────────────────────────── 제작 ───────────────────────────

## 한 레시피 행 = [결과 이름 + 재료(보유/필요)] ……… [제작]. 재료 부족이면 버튼 비활성.
## refine_panel과 같은 규약 — 소비·지급은 GameState.spend/add_item이 쥔다.
func _make_recipe_row(r: RecipeDef) -> Control:
	var afford := GameState.can_afford(r.inputs)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := Label.new()
	name_lbl.text = "%s ×%d" % [_item_name(r.output_id), r.output_count]
	name_lbl.add_theme_color_override(&"font_color", NAME_COLOR)
	info.add_child(name_lbl)

	var need_lbl := Label.new()
	need_lbl.text = "재료: " + _inputs_text(r)
	need_lbl.add_theme_font_size_override(&"font_size", 11)
	need_lbl.add_theme_color_override(&"font_color", HAVE_COLOR if afford else SHORT_COLOR)
	info.add_child(need_lbl)

	var btn := Button.new()
	btn.text = "제작"
	btn.disabled = not afford
	btn.pressed.connect(_craft.bind(r.id))
	return _row(info, btn, ROW_BG)


## 🔴 제작 — 재료를 창고에서 빼고 결과를 넣는다. spend가 can_afford를 확인하므로 이중 클릭도 안전.
func _craft(recipe_id: StringName) -> void:
	var r := Db.get_recipe(recipe_id)
	if r == null:
		return
	if GameState.spend(r.inputs):
		GameState.add_item(r.output_id, r.output_count)
		Audio.play(&"craft")


# ─────────────────────────── 장착 ───────────────────────────

## 착용 중(부위별 [해제]) → 보유 장비([장착]). 착용품은 창고에서 빠져 있으니 두 목록이 겹치지 않는다.
func _add_equip_rows() -> void:
	var any_equipped := false
	for pair: Array in EQUIP_KINDS:
		var kind: int = pair[0]
		if GameState.equipment.has(kind):
			any_equipped = true
			_list.add_child(_make_equipped_row(kind, pair[1]))
	if not any_equipped:
		_list.add_child(_hint_label("착용 중인 장비가 없다"))

	var owned := _owned_equippable()
	if owned.is_empty():
		_list.add_child(_hint_label("보유한 장비가 없다 — 공방에서 만들거나 숲에서 얻는다"))
		return
	for entry: Dictionary in owned:
		_list.add_child(_make_owned_row(entry["id"], int(entry["count"])))


## 착용 중인 한 부위 — "펜 · 길든 펜 (보정 …)" [해제].
func _make_equipped_row(kind: int, kind_label: String) -> Control:
	var item_id: StringName = GameState.equipment[kind]
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := Label.new()
	name_lbl.text = "%s · %s" % [kind_label, _item_name(item_id)]
	name_lbl.add_theme_color_override(&"font_color", EQUIPPED_COLOR)
	info.add_child(name_lbl)

	var hint := _effect_text(item_id)
	if hint != "":
		var eff := Label.new()
		eff.text = hint
		eff.add_theme_font_size_override(&"font_size", 11)
		eff.add_theme_color_override(&"font_color", HINT_COLOR)
		info.add_child(eff)

	var btn := Button.new()
	btn.text = "해제"
	btn.pressed.connect(GameState.unequip_gear.bind(kind))
	return _row(info, btn, EQUIPPED_ROW_BG)


## 창고에 있는 장착 가능한 한 아이템 — 이름 + 효과 [장착].
func _make_owned_row(item_id: StringName, count: int) -> Control:
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := Label.new()
	name_lbl.text = "%s ×%d" % [_item_name(item_id), count]
	name_lbl.add_theme_color_override(&"font_color", NAME_COLOR)
	info.add_child(name_lbl)

	var hint := _effect_text(item_id)
	if hint != "":
		var eff := Label.new()
		eff.text = hint
		eff.add_theme_font_size_override(&"font_size", 11)
		eff.add_theme_color_override(&"font_color", HINT_COLOR)
		info.add_child(eff)

	var btn := Button.new()
	btn.text = "장착"
	btn.pressed.connect(GameState.equip_gear.bind(item_id))
	return _row(info, btn, ROW_BG)


## 창고에서 착용 가능한(장비 종류) 아이템만 — 종류→등급→id 순으로. 착용품은 창고에 없어 안 뜬다.
func _owned_equippable() -> Array:
	var equip_kinds: Array = []
	for pair: Array in EQUIP_KINDS:
		equip_kinds.append(pair[0])
	var out: Array = []
	var snap := GameState.get_inventory_snapshot()
	for id: StringName in snap:
		var count := int(snap[id])
		if count <= 0:
			continue
		var it := Db.get_item(id)
		if it != null and it.kind in equip_kinds:
			out.append({"id": id, "count": count})
	out.sort_custom(_owned_less)
	return out


func _owned_less(a: Dictionary, b: Dictionary) -> bool:
	var ia := Db.get_item(a["id"])
	var ib := Db.get_item(b["id"])
	var ka := int(ia.kind) if ia != null else 99
	var kb := int(ib.kind) if ib != null else 99
	if ka != kb:
		return ka < kb
	var ga := ia.grade if ia != null else 0
	var gb := ib.grade if ib != null else 0
	if ga != gb:
		return ga > gb
	return String(a["id"]) < String(b["id"])


# ─────────────────────────── 조각 ───────────────────────────

## 왼쪽 정보(VBox) + 오른쪽 버튼을 한 카드에 담는다 — 제작·장착·해제가 같은 모양.
func _row(info: Control, btn: Button, bg: Color) -> Control:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_content_margin_all(9.0)
	sb.set_corner_radius_all(3)
	row.add_theme_stylebox_override(&"panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override(&"separation", 10)
	row.add_child(hb)
	hb.add_child(info)

	btn.custom_minimum_size = Vector2(88.0, 44.0)
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(btn)
	return row


func _section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override(&"font_size", 15)
	lbl.add_theme_color_override(&"font_color", SECTION_COLOR)
	return lbl


func _hint_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override(&"font_size", 12)
	lbl.add_theme_color_override(&"font_color", HINT_COLOR)
	return lbl


## 장비 효과 한 줄 — 펜=보정, 로브=HP/마나, 지팡이=발사 패턴. 없으면 빈 문자열.
func _effect_text(item_id: StringName) -> String:
	var it := Db.get_item(item_id)
	if it == null:
		return ""
	match int(it.kind):
		Enums.ItemKind.PEN:
			return "손그림 보정 +%.2f" % float(it.params.get("correction", 0.0))
		Enums.ItemKind.ROBE:
			var parts: Array[String] = []
			if it.params.has("hp_max_add"):
				parts.append("HP +%d" % int(it.params["hp_max_add"]))
			if it.params.has("mana_max_add"):
				parts.append("마나 +%d" % int(it.params["mana_max_add"]))
			return " · ".join(parts)
		Enums.ItemKind.WAND:
			return "발사 패턴"
		_:
			return ""


func _inputs_text(r: RecipeDef) -> String:
	var parts: Array[String] = []
	for id: StringName in r.inputs:
		var need := int(r.inputs[id])
		parts.append("%s %d/%d" % [_item_name(id), need, GameState.get_count(id)])
	return ", ".join(parts)


func _item_name(id: StringName) -> String:
	var it := Db.get_item(id)
	return it.display_name if it != null and it.display_name != "" else String(id)
