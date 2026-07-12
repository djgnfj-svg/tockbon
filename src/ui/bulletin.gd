extends Control
## 아침 게시판 — 오늘의 적 목록. 도감 해금된 적은 약점 룬 표기, 미해금은 ??? (모듈 E).
## day_started 수신·표시 흐름은 ui_root가 관리한다.

signal closed

const InkStyle := preload("res://src/ui/ink_style.gd")

@onready var _sub_title: Label = %SubTitle
@onready var _enemy_list: VBoxContainer = %EnemyList
@onready var _close_button: Button = %CloseButton

func _ready() -> void:
	_close_button.pressed.connect(func() -> void: closed.emit())
	# 게시판이 열린 채 도감 해금 시 약점 ??? → 룬 표기 실시간 전환 (TECH_SPEC §5.1)
	EventBus.codex_unlocked.connect(_on_unlock)
	EventBus.research_completed.connect(_on_unlock)

func _on_unlock(_unlock_id: StringName) -> void:
	if visible:
		refresh()

func open() -> void:
	visible = true
	refresh()
	_close_button.grab_focus()

func refresh() -> void:
	_sub_title.text = "%d일차 — 오늘 숲에서 목격된 무늬들" % Clock.day
	InkStyle.clear_children(_enemy_list)
	if Db.enemies.is_empty():
		var empty := InkStyle.make_label("게시된 정보가 없다.", 9, InkStyle.INK_FAINT)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_enemy_list.add_child(empty)
		return
	for id: StringName in Db.enemies:
		var def: EnemyDef = Db.enemies[id]
		_enemy_list.add_child(_make_enemy_row(def))

func _make_enemy_row(def: EnemyDef) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		InkStyle.make_panel(InkStyle.PAPER_DARK, InkStyle.INK_FAINT, 1, 2, 8, 3))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var display := def.display_name if not def.display_name.is_empty() else String(def.id)
	if def.is_elite:
		display = "◆ " + display
	var name_l := InkStyle.make_label(display, 10)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_l)

	var weak_l: Label
	if not GameState.is_unlocked(InkStyle.enemy_unlock_id(def.id)):
		weak_l = InkStyle.make_label("약점 ???", 9, InkStyle.INK_FAINT)
	elif not def.has_counter:
		weak_l = InkStyle.make_label("약점 없음", 9, InkStyle.INK_SOFT)
	else:
		weak_l = InkStyle.make_label(
			"약점 %s %s" % [InkStyle.rune_glyph(def.counter_rune), InkStyle.rune_name(def.counter_rune)],
			9, InkStyle.rune_color(def.counter_rune))
	row.add_child(weak_l)

	panel.add_child(row)
	return panel
