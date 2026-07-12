extends Control
## 장착 선택 — 보유 도안을 4슬롯에 배치하고 확정 시 GameState.equip 반영 (모듈 E).
## 손상(is_broken) 도안은 경고 표기. 필드 교체 불가 규칙(GDD §4.4)의 아침 확정 화면.

signal confirmed

const InkStyle := preload("res://src/ui/ink_style.gd")

const HINT_DEFAULT := "도안을 고른 뒤 슬롯을 누르면 배치된다. 같은 슬롯을 다시 누르면 해제."
const HINT_BROKEN := "손상된 도안이다 — 장착해도 수리 전에는 발동할 수 없다."

@onready var _design_list: VBoxContainer = %DesignList
@onready var _slot_list: VBoxContainer = %SlotList
@onready var _hint: Label = %Hint
@onready var _confirm: Button = %Confirm

var _selected: SpellDesign = null
var _pending: Array[SpellDesign] = [null, null, null, null]
var _slot_buttons: Array[Button] = []
var _design_buttons: Dictionary = {}

func _ready() -> void:
	for i in GameState.EQUIP_SLOTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 32)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.pressed.connect(assign_slot.bind(i))
		_slot_list.add_child(b)
		_slot_buttons.append(b)
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
	_set_hint(HINT_DEFAULT, InkStyle.INK_SOFT)

# ── 조작 (테스트에서 직접 호출 가능한 공개 API)

func select_design(d: SpellDesign) -> void:
	_selected = d
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

func _make_design_button(d: SpellDesign) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 34)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var head := d.display_name
	if d.is_broken():
		head = "[손상] " + head
		b.add_theme_color_override("font_color", InkStyle.SEAL)
		b.add_theme_color_override("font_hover_color", InkStyle.SEAL)
	b.text = "%s\n%s%s · 내구 %d/%d · 마나 %d" % [
		head,
		InkStyle.rune_glyph(d.rune_type), InkStyle.rune_name(d.rune_type),
		d.durability, d.durability_max, int(d.mana_cost)]
	b.pressed.connect(select_design.bind(d))
	return b

func _refresh_slot_buttons() -> void:
	for i in GameState.EQUIP_SLOTS:
		var d := _pending[i]
		if d == null:
			_slot_buttons[i].text = "슬롯 %d — 비어 있음" % (i + 1)
			_slot_buttons[i].remove_theme_color_override("font_color")
		else:
			var mark := " [손상]" if d.is_broken() else ""
			_slot_buttons[i].text = "슬롯 %d — %s%s" % [i + 1, d.display_name, mark]
			if d.is_broken():
				_slot_buttons[i].add_theme_color_override("font_color", InkStyle.SEAL)
			else:
				_slot_buttons[i].remove_theme_color_override("font_color")

func _set_hint(text: String, color: Color) -> void:
	_hint.text = text
	_hint.add_theme_color_override("font_color", color)

## 테스트·외부 확인용 — 현재 배치안
func pending() -> Array[SpellDesign]:
	return _pending
