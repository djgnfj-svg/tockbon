extends Control
## 탁본 해독대 — 보스에게서 얻은 **룬 조각(fragment_*)을 해독해 새 룬을 배운다** (세션34 E4).
## 베이스 [E]로 연다. 게임 이름이 '탁본'인 만큼, 룬은 드롭이 아니라 **여기서 손수 해독**해 얻는다.
##
## 🔴 왜 필요했나: 세션34에 룬 사슬을 뚫어(물·바람을 그려 쏠 수 있게) 놨지만, 새 룬을 **해금할
## 길이 없었다**. 조각의 unlock_id(rune_water 등)는 codex_unlocked로 등록되면 조립 책이 그 룬 셀을
## 띄운다 — 이 패널이 그 codex_unlocked를 쏘는 유일한 곳이다.
##
## 🔴 **소비·해금은 GameState/EventBus**(remove_item·codex_unlocked). 이 패널은 나열·버튼만 —
## 새 조각 = data/items/fragment_*.tres 한 장(kind=FRAGMENT, params.unlock_id)이면 여기에 저절로 뜬다.
##
## 🔴 **모달** — 열리면 GameState.ui_modal_open을 켠다(정제대·창고·발사와 같은 패턴). ESC로 닫는다.
##
## 계약: open() / closed 시그널. base.gd가 InteractZone(zone_id=decode)에서 연다.

signal closed

const BACKDROP := Color(0.03, 0.025, 0.02, 0.82)
const HINT_COLOR := Color(0.66, 0.62, 0.54)
const NAME_COLOR := Color(0.94, 0.90, 0.80)
const DONE_COLOR := Color(0.62, 0.80, 0.52)
const NEW_COLOR := Color(0.90, 0.78, 0.42)
const ROW_BG := Color(0.17, 0.15, 0.12, 0.95)

@onready var _list: VBoxContainer = $Center/Panel/Margin/VBox/List

func _ready() -> void:
	# 화면을 덮는 모달 — STOP이라 열린 동안 좌클릭을 통째로 먹는다(뒤에서 실수로 안 쏜다).
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	EventBus.resources_changed.connect(_on_changed)
	EventBus.codex_unlocked.connect(_on_codex_changed)
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


## 해금이 바뀌면(방금 해독) 행의 상태 표시를 갱신한다 — remove_item의 resources_changed와 별개로
## codex_unlocked도 듣는다(조각을 다 써서 목록에서 사라져도 다른 행의 상태가 바뀔 수 있다).
func _on_codex_changed(_id: StringName) -> void:
	if visible:
		_refresh()


func _on_draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP, true)


## 창고의 룬 조각(kind=FRAGMENT)만 나열한다. 없으면 "보스를 잡아라" 안내.
func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var frags := _fragments()
	if frags.is_empty():
		var none := Label.new()
		none.text = "해독할 조각이 없다 — 숲 깊은 곳의 우두머리를 잡아라"
		none.add_theme_color_override(&"font_color", HINT_COLOR)
		_list.add_child(none)
		return
	for id: StringName in frags:
		_list.add_child(_make_row(id))


## 창고에서 보유 중인 조각 id들 (kind=FRAGMENT, 수량>0) — id 오름차순.
func _fragments() -> Array:
	var out: Array = []
	for id: StringName in GameState.get_inventory_snapshot():
		if GameState.get_count(id) <= 0:
			continue
		var it := Db.get_item(id)
		if it != null and it.kind == Enums.ItemKind.FRAGMENT:
			out.append(id)
	out.sort()
	return out


## 한 행 = [조각 이름 ×수량 + 배울 룬(또는 이미 배움)] ……… [해독] / [이미 배움(비활성)].
func _make_row(frag_id: StringName) -> Control:
	var it := Db.get_item(frag_id)
	var unlock := StringName(it.params.get("unlock_id", &"")) if it != null else &""
	var learned := unlock != &"" and GameState.is_unlocked(unlock)

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
	name_lbl.text = "%s ×%d" % [_item_name(frag_id), GameState.get_count(frag_id)]
	name_lbl.add_theme_color_override(&"font_color", NAME_COLOR)
	info.add_child(name_lbl)

	var sub := Label.new()
	sub.add_theme_font_size_override(&"font_size", 11)
	if learned:
		sub.text = "%s 룬 — 이미 해독함" % _rune_name(unlock)
		sub.add_theme_color_override(&"font_color", DONE_COLOR)
	else:
		sub.text = "해독하면 %s 룬을 배운다" % _rune_name(unlock)
		sub.add_theme_color_override(&"font_color", NEW_COLOR)
	info.add_child(sub)

	var btn := Button.new()
	btn.text = "이미 배움" if learned else "해독"
	btn.custom_minimum_size = Vector2(96.0, 44.0)
	btn.disabled = learned or unlock == &""
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_decode.bind(frag_id))
	hb.add_child(btn)
	return row


## 🔴 해독 — 조각 하나를 소비하고 그 룬을 해금한다 (codex_unlocked → GameState가 codex에 심는다).
## 이미 배운 룬이면 아무 일도 안 한다(버튼이 비활성이지만 이중 안전) — 조각을 헛되이 소비하지 않게.
func _decode(frag_id: StringName) -> void:
	var it := Db.get_item(frag_id)
	if it == null:
		return
	var unlock := StringName(it.params.get("unlock_id", &""))
	if unlock == &"" or GameState.is_unlocked(unlock):
		return
	if GameState.remove_item(frag_id, 1):
		EventBus.codex_unlocked.emit(unlock)
		Audio.play(&"unlock")


## unlock_id(rune_water 등)를 가진 룬의 이름 — Db.runes를 뒤져 매칭. 없으면 unlock_id 문자열.
func _rune_name(unlock_id: StringName) -> String:
	for t: int in Enums.RUNE_TYPES:
		var rd := Db.get_rune(t)
		if rd != null and rd.unlock_id == unlock_id:
			return rd.display_name
	return String(unlock_id)


func _item_name(id: StringName) -> String:
	var it := Db.get_item(id)
	return it.display_name if it != null and it.display_name != "" else String(id)
