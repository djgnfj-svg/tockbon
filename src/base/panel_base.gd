extends PanelContainer
## 거점 패널 공통 골격 — 제목 + 닫기 버튼 + 내용 VBox (모듈 D 임시 UI).
## 본격 UI는 모듈 E 소관 — 여기는 기능 확인용 플레이스홀더.

signal close_requested

var content: VBoxContainer
var _title_label: Label

func _init() -> void:
	custom_minimum_size = Vector2(500, 310)
	var root := VBoxContainer.new()
	add_child(root)
	var head := HBoxContainer.new()
	root.add_child(head)
	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title_label)
	var close_btn := Button.new()
	close_btn.text = "닫기(ESC)"
	close_btn.pressed.connect(func() -> void: close_requested.emit())
	head.add_child(close_btn)
	content = VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)

func set_title(text: String) -> void:
	_title_label.text = text

func open() -> void:
	refresh()

## 하위 패널이 목록 재구성으로 구현
func refresh() -> void:
	pass

# ── 공용 헬퍼

## 시그널 발신 중인 버튼도 안전하게 치울 수 있도록 remove 후 queue_free
func clear_box(box: Container) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()

func item_name(item_id: StringName) -> String:
	var def: ItemDef = Db.get_item(item_id)
	return def.display_name if def != null else String(item_id)

## {item_id: n} → "이름×n, 이름×n"
func fmt_items(items: Dictionary) -> String:
	var parts := PackedStringArray()
	for item_id: StringName in items:
		parts.append("%s×%d" % [item_name(item_id), int(items[item_id])])
	return ", ".join(parts)

func add_row(box: Container, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	box.add_child(row)
	return row

func add_button(row: HBoxContainer, text: String, enabled: bool, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.pressed.connect(on_pressed)
	row.add_child(button)
	return button
