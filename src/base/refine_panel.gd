extends Control
## 정제대 — 재료를 **특별잉크·종이**로 바꾼다 (세션29 경제 E3). 베이스 [E]로 연다.
##
## 🔴 왜 필요했나: 세션27~28에 드롭이 쌓이고 창고에서 보이는데 **쓸 데가 없었다**(가공이 빈 칸).
## 여기가 재료의 소비처다 — 잉크재료→특별잉크·종이재료→종이. 그린 마법이 세지는 첫 고리.
##
## 🔴 **레시피는 데이터**(Db.all_recipes / RecipeDef) · **소비·지급은 GameState**(spend·add_item).
## 이 패널은 나열·버튼만 — 새 레시피 = data/recipes/*.tres 한 장이면 여기에 저절로 뜬다.
##
## 🔴 **모달** — 열리면 GameState.ui_modal_open을 켠다(창고 I·발사와 겹침 방지, inventory_panel과 같은
## 패턴). ESC로 닫는다. CanvasLayer 위에 산다(카메라 추적 무관 — HUD·창고와 같은 이유).
##
## 계약: open() / closed 시그널. base.gd가 InteractZone(zone_id=refine)에서 연다.

signal closed

const PANEL_SIZE := Vector2(520.0, 440.0)

const BACKDROP := Color(0.03, 0.025, 0.02, 0.82)
const PANEL_BG := Color(0.12, 0.10, 0.08, 0.98)
const PANEL_EDGE := Color(0.48, 0.43, 0.34, 0.9)
const TITLE_COLOR := Color(0.96, 0.90, 0.78)
const HINT_COLOR := Color(0.66, 0.62, 0.54)
const NAME_COLOR := Color(0.94, 0.90, 0.80)
const HAVE_COLOR := Color(0.62, 0.80, 0.52)
const SHORT_COLOR := Color(0.86, 0.46, 0.40)
const ROW_BG := Color(0.17, 0.15, 0.12, 0.95)

@onready var _list: VBoxContainer = $Center/Panel/Margin/VBox/List

var _open := false


func _ready() -> void:
	# 화면을 덮는 모달 — STOP이라 열린 동안 좌클릭을 통째로 먹는다(뒤에서 실수로 안 쏜다).
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	EventBus.resources_changed.connect(_on_resources_changed)
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


func _on_resources_changed() -> void:
	if visible:
		_refresh()


## 배경(어둠 + 카드 판) — 카드 자체는 씬 노드(Center/Panel)가 그리므로 여기선 뒷막만.
func _on_draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP, true)


## 레시피 행을 다시 짓는다 — 보유량이 바뀌면(정제·소모) 만들 수 있는지·수량이 달라진다.
func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	# 🔴 정제대 레시피(잉크)만 — 공방(장비) 레시피는 station=&"craft"라 여기 안 뜬다 (세션32).
	# 🔴 세71d 종이 축 은퇴: 종이(kind==PAPER) 결과 레시피(craft_paper_mid/high)는 목록에서 숨긴다 —
	# size가 1.0 고정이라 효과 없는 종이를 mat_vine 써서 만드는 dead affordance다. 레시피 .tres·
	# 아이템은 삭제하지 않고 **필터로만 숨긴다**(휴면 — 종이 축을 되살리면 이 필터만 빼면 된다).
	var recipes: Array = []
	for r: RecipeDef in Db.recipes_for_station(&"refine"):
		var out := Db.get_item(r.output_id)
		if out != null and out.kind == Enums.ItemKind.PAPER:
			continue
		recipes.append(r)
	if recipes.is_empty():
		var none := Label.new()
		none.text = "만들 수 있는 게 없다 (data/recipes 비어 있음)"
		none.add_theme_color_override(&"font_color", HINT_COLOR)
		_list.add_child(none)
		return
	for r: RecipeDef in recipes:
		_list.add_child(_make_row(r))


## 한 레시피 행 = [결과 이름 + 재료(보유/필요)] ……… [제작]. 재료가 모자라면 버튼 비활성.
func _make_row(r: RecipeDef) -> Control:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = ROW_BG
	sb.set_content_margin_all(9.0)
	sb.set_corner_radius_all(3)
	row.add_theme_stylebox_override(&"panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override(&"separation", 10)
	row.add_child(hb)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = "%s ×%d" % [_item_name(r.output_id), r.output_count]
	name_lbl.add_theme_color_override(&"font_color", NAME_COLOR)
	info.add_child(name_lbl)

	var need_lbl := Label.new()
	var afford := GameState.can_afford(r.inputs)
	need_lbl.text = "재료: " + _inputs_text(r)
	need_lbl.add_theme_font_size_override(&"font_size", 11)
	need_lbl.add_theme_color_override(&"font_color", HAVE_COLOR if afford else SHORT_COLOR)
	info.add_child(need_lbl)

	var btn := Button.new()
	btn.text = "제작"
	btn.custom_minimum_size = Vector2(88.0, 44.0)
	btn.disabled = not afford
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_craft.bind(r.id))
	hb.add_child(btn)
	return row


## 🔴 제작 — 재료를 창고에서 빼고 결과를 넣는다. spend가 can_afford를 확인하므로 이중 클릭도 안전.
## resources_changed가 팔레트·창고·이 패널을 전부 다시 그리게 한다 (add/remove가 이미 emit한다).
func _craft(recipe_id: StringName) -> void:
	var r := Db.get_recipe(recipe_id)
	if r == null:
		return
	if GameState.spend(r.inputs):
		GameState.add_item(r.output_id, r.output_count)
		Audio.play(&"craft")


## "재생 덩굴 줄기 2/5, …" — 재료마다 필요/보유. 소비자(GameState.spend)가 먹는 형식과 같은 dict.
func _inputs_text(r: RecipeDef) -> String:
	var parts: Array[String] = []
	for id: StringName in r.inputs:
		var need := int(r.inputs[id])
		parts.append("%s %d/%d" % [_item_name(id), need, GameState.get_count(id)])
	return ", ".join(parts)


func _item_name(id: StringName) -> String:
	var it := Db.get_item(id)
	return it.display_name if it != null and it.display_name != "" else String(id)
