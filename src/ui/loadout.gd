extends Control
## 장착 선택 — 보유 도안을 4슬롯에 배치하고 확정 시 GameState.equip 반영 (모듈 E).
## 손상(is_broken) 도안은 경고 표기. 필드 교체 불가 규칙(GDD §4.4)의 아침 확정 화면.

signal confirmed

const InkStyle := preload("res://src/ui/ink_style.gd")
const DesignThumb := preload("res://src/core/design_thumb.gd")

const HINT_DEFAULT := "도안을 고른 뒤 슬롯을 누르면 배치된다. 같은 슬롯을 다시 누르면 해제."
const HINT_BROKEN := "손상된 도안이다 — 장착해도 수리 전에는 발동할 수 없다."

## 여기가 "어제 그린 그 도안"을 알아보고 고르는 화면이다 — 썸네일을 크게 잡는다
const DESIGN_ROW_H := 56.0
const DESIGN_THUMB := Vector2(46, 46)
const SLOT_ROW_H := 42.0
const SLOT_THUMB := Vector2(32, 32)
const SLOT_THUMB_WIDTH := 0.6
const ROW_MARGIN := 4

@onready var _design_list: VBoxContainer = %DesignList
@onready var _slot_list: VBoxContainer = %SlotList
@onready var _hint: Label = %Hint
@onready var _confirm: Button = %Confirm

var _selected: SpellDesign = null
var _pending: Array[SpellDesign] = [null, null, null, null]
var _slot_buttons: Array[Button] = []
var _slot_thumbs: Array[Control] = []
var _slot_labels: Array[Label] = []
var _design_buttons: Dictionary = {}

func _ready() -> void:
	for i in GameState.EQUIP_SLOTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, SLOT_ROW_H)
		b.clip_contents = true
		b.pressed.connect(assign_slot.bind(i))
		var row := _make_row(b)
		var thumb := _make_thumb(SLOT_THUMB, SLOT_THUMB_WIDTH)
		row.add_child(thumb)
		var label := InkStyle.make_label("", 10)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(label)
		_slot_list.add_child(b)
		_slot_buttons.append(b)
		_slot_thumbs.append(thumb)
		_slot_labels.append(label)
	_confirm.pressed.connect(confirm)

func open() -> void:
	visible = true
	for i in GameState.EQUIP_SLOTS:
		_pending[i] = GameState.equipped[i]
	_selected = null
	refresh()

func refresh() -> void:
	InkStyle.clear_children(_design_list)
	_design_buttons.clear()
	if GameState.designs.is_empty():
		var empty := InkStyle.make_label("보유한 도안이 없다 — 밤에 작업대에서 그리자.", 9, InkStyle.INK_FAINT)
		_design_list.add_child(empty)
	for d: SpellDesign in GameState.designs:
		var b := _make_design_button(d)
		_design_list.add_child(b)
		_design_buttons[d] = b
	_refresh_slot_buttons()
	_refresh_selection()
	_set_hint(HINT_DEFAULT, InkStyle.INK_SOFT)

# ── 조작 (테스트에서 직접 호출 가능한 공개 API)

func select_design(d: SpellDesign) -> void:
	_selected = d
	_refresh_selection()
	if d.is_broken():
		_set_hint("선택: %s — %s" % [d.display_name, HINT_BROKEN], InkStyle.SEAL)
	else:
		_set_hint("선택: %s — 배치할 슬롯을 누르자." % d.display_name, InkStyle.INK)

func assign_slot(slot: int) -> void:
	if _selected == null:
		if _pending[slot] != null:
			_pending[slot] = null
			_set_hint("슬롯 %d을(를) 비웠다." % (slot + 1), InkStyle.INK_SOFT)
		else:
			_set_hint("먼저 왼쪽에서 도안을 고르자.", InkStyle.INK_SOFT)
		_refresh_slot_buttons()
		return
	# 같은 도안은 한 슬롯에만 — 기존 자리에서 옮긴다
	var prev := _pending.find(_selected)
	if prev >= 0 and prev != slot:
		_pending[prev] = null
	if _pending[slot] == _selected:
		_pending[slot] = null
		_set_hint("슬롯 %d에서 해제했다." % (slot + 1), InkStyle.INK_SOFT)
	else:
		_pending[slot] = _selected
		if _selected.is_broken():
			_set_hint("슬롯 %d에 배치 — %s" % [slot + 1, HINT_BROKEN], InkStyle.SEAL)
		else:
			_set_hint("슬롯 %d에 배치했다." % (slot + 1), InkStyle.INK)
	_refresh_slot_buttons()

func confirm() -> void:
	for i in GameState.EQUIP_SLOTS:
		GameState.equip(i, _pending[i])
	confirmed.emit()

# ── 표시

## 버튼 위에 얹는 내용 행 — 버튼 자신이 클릭을 받아야 하므로 내용은 마우스를 통과시킨다
func _make_row(button: Button) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, ROW_MARGIN)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	button.add_child(row)
	return row

func _make_thumb(box: Vector2, width: float) -> Control:
	var thumb := DesignThumb.new()
	thumb.name = "Thumb"
	thumb.custom_minimum_size = box
	thumb.width_mult = width
	# strokes 없는 도안(샘플·구세이브)은 룬 표기로 — core는 폴백 모양을 모른다
	thumb.fallback_builder = InkStyle.make_design_fallback
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return thumb

func _make_design_button(d: SpellDesign) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, DESIGN_ROW_H)
	b.clip_contents = true
	b.pressed.connect(select_design.bind(d))

	var row := _make_row(b)
	var thumb := _make_thumb(DESIGN_THUMB, 1.0)
	thumb.call("set_design", d)
	row.add_child(thumb)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 1)
	var head := d.display_name
	var head_color := InkStyle.INK
	if d.is_broken():
		head = "[손상] " + head
		head_color = InkStyle.SEAL
	var name_l := InkStyle.make_label(head, 10, head_color)
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var info_l := InkStyle.make_label("%s%s · 내구 %d/%d · 마나 %d" % [
		InkStyle.rune_glyph(d.rune_type), InkStyle.rune_name(d.rune_type),
		d.durability, d.durability_max, int(d.mana_cost)], 8, InkStyle.INK_SOFT)
	info_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name_l)
	col.add_child(info_l)
	row.add_child(col)
	return b

## 고른 도안에 인주 테두리 — 썸네일이 여럿이면 이름표보다 테두리가 먼저 읽힌다
func _refresh_selection() -> void:
	for d: SpellDesign in _design_buttons:
		var b: Button = _design_buttons[d]
		if d == _selected:
			b.add_theme_stylebox_override("normal",
				InkStyle.make_panel(InkStyle.PAPER, InkStyle.SEAL, 2, 2, 6, 3))
		else:
			b.remove_theme_stylebox_override("normal")

func _refresh_slot_buttons() -> void:
	for i in GameState.EQUIP_SLOTS:
		var d := _pending[i]
		_slot_thumbs[i].call("set_design", d)
		if d == null:
			_slot_labels[i].text = "슬롯 %d — 비어 있음" % (i + 1)
			_slot_labels[i].add_theme_color_override("font_color", InkStyle.INK_FAINT)
		else:
			var mark := " [손상]" if d.is_broken() else ""
			_slot_labels[i].text = "슬롯 %d — %s%s" % [i + 1, d.display_name, mark]
			_slot_labels[i].add_theme_color_override(
				"font_color", InkStyle.SEAL if d.is_broken() else InkStyle.INK)

func _set_hint(text: String, color: Color) -> void:
	_hint.text = text
	_hint.add_theme_color_override("font_color", color)

## 테스트·외부 확인용 — 현재 배치안
func pending() -> Array[SpellDesign]:
	return _pending
