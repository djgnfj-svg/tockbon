extends Control
## 상점 — 돈(닢)으로 기본 잉크(등급/색)를 산다 (세66 도파민 재편 §3).
## 베이스 [E]로 연다. 정제대(refine_panel)와 **동일 구조**의 소비처 — 다른 점은 잔액 줄뿐이다.
##
## 🔴 왜 상점인가: 잡몹 킬 → coin → 귀환 창고(지갑)로 흘러온 돈의 **소비처(3층 sink)**다.
## 여기서 돈을 잉크로 바꿔 「그리는 재미」(색·데미지 선택지)를 넓힌다. 특별잉크(효과)는 정제대 소관 —
## 상점은 등급 잉크만(소비처가 안 겹친다).
##
## 🔴 **재고는 데이터**(station=&"shop" RecipeDef) · **소비·지급은 GameState**(spend·add_item).
## 새 상품 = data/recipes/shop_*.tres 한 장이면 여기에 저절로 뜬다. ShopDef 같은 새 스키마 없음.
##
## 🔴 **모달** — 열리면 GameState.ui_modal_open을 켠다(창고 I·발사와 겹침 방지, refine_panel과 같은
## 패턴). ESC로 닫는다.
##
## 계약: open() / closed 시그널. base.gd가 InteractZone(zone_id=shop)에서 연다.

signal closed

const BACKDROP := Color(0.03, 0.025, 0.02, 0.82)
const NAME_COLOR := Color(0.94, 0.90, 0.80)
const HINT_COLOR := Color(0.66, 0.62, 0.54)
const AFFORD_COLOR := Color(0.92, 0.82, 0.42)   # 살 수 있는 가격(금빛)
const SHORT_COLOR := Color(0.86, 0.46, 0.40)    # 돈 모자람(붉은빛)
const ROW_BG := Color(0.17, 0.15, 0.12, 0.95)

@onready var _coin_lbl: Label = $Center/Panel/Margin/VBox/Coin
@onready var _list: VBoxContainer = $Center/Panel/Margin/VBox/List


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


## 배경(어둠) — 카드 판은 씬 노드(Center/Panel)가 그린다.
func _on_draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP, true)


## 재고 행을 다시 짓는다 — 잔액이 바뀌면(구매) 살 수 있는지·잔액 줄이 달라진다.
func _refresh() -> void:
	_coin_lbl.text = "보유: %d닢" % GameState.get_count(&"coin")
	for c in _list.get_children():
		c.queue_free()
	# 🔴 상점 레시피(station=&"shop")만 — 정제대·공방 레시피는 여기 안 뜬다.
	var recipes: Array = Db.recipes_for_station(&"shop")
	if recipes.is_empty():
		var none := Label.new()
		none.text = "파는 게 없다 (data/recipes에 station=shop 없음)"
		none.add_theme_color_override(&"font_color", HINT_COLOR)
		_list.add_child(none)
		return
	for r: RecipeDef in recipes:
		_list.add_child(_make_row(r))


## 한 상품 행 = [잉크 이름 + 가격(N닢)] ……… [구매]. 돈이 모자라면 버튼 비활성.
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

	var afford := GameState.can_afford(r.inputs)
	var price_lbl := Label.new()
	price_lbl.text = "가격: " + _price_text(r)
	price_lbl.add_theme_font_size_override(&"font_size", 11)
	price_lbl.add_theme_color_override(&"font_color", AFFORD_COLOR if afford else SHORT_COLOR)
	info.add_child(price_lbl)

	var btn := Button.new()
	btn.text = "구매"
	btn.custom_minimum_size = Vector2(88.0, 44.0)
	btn.disabled = not afford
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_buy.bind(r.id))
	hb.add_child(btn)
	return row


## 🔴 구매 — 공개 훅(헤드리스 검증용, loot_panel.advance 선례). 돈을 지갑에서 빼고 잉크를 넣는다.
## spend가 can_afford를 확인하므로 이중 클릭도 안전. resources_changed가 이 패널·창고를 다시 그린다.
func _buy(recipe_id: StringName) -> void:
	var r := Db.get_recipe(recipe_id)
	if r == null:
		return
	if GameState.spend(r.inputs):
		GameState.add_item(r.output_id, r.output_count)
		Audio.play(&"craft")


## "20닢" — 상점은 coin만 받으므로 재료 dict를 닢 단위로 읽는다. 소비자(GameState.spend)가 먹는 형식과 같다.
func _price_text(r: RecipeDef) -> String:
	var parts: Array[String] = []
	for id: StringName in r.inputs:
		parts.append("%d닢" % int(r.inputs[id]))
	return ", ".join(parts)


func _item_name(id: StringName) -> String:
	var it := Db.get_item(id)
	return it.display_name if it != null and it.display_name != "" else String(id)
