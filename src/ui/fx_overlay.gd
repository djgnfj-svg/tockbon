extends Control
## 연출 스텁 — 자원 획득 토스트(resources_changed) + 탁본 진행 바(rubbing_*) (모듈 E).
## 획득량은 GameState.inventory 스냅샷 diff로 계산 — 표시 전용, 게임 로직 없음.

const InkStyle := preload("res://src/ui/ink_style.gd")

const TOAST_HOLD_SEC := 2.0
const TOAST_FADE_SEC := 0.4
const TOAST_MAX := 4

@onready var _toast_box: VBoxContainer = %ToastBox
@onready var _rubbing_box: VBoxContainer = %RubbingBox
@onready var _rubbing_label: Label = %RubbingLabel
@onready var _rubbing_bar: ProgressBar = %RubbingBar

var _inv_snapshot: Dictionary = {}
var _rubbing_tween: Tween = null

func _ready() -> void:
	_rubbing_bar.add_theme_stylebox_override("fill", InkStyle.make_bar_fill(InkStyle.SEAL))
	_inv_snapshot = GameState.inventory.duplicate()
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.rubbing_started.connect(_on_rubbing_started)
	EventBus.rubbing_completed.connect(_on_rubbing_completed)
	EventBus.cast_failed.connect(_on_cast_failed)

# ── 획득 토스트

func _on_resources_changed() -> void:
	var seen: Dictionary = {}
	for id: Variant in GameState.inventory:
		seen[id] = true
		var now := int(GameState.inventory[id])
		var before := int(_inv_snapshot.get(id, 0))
		if now != before:
			_toast_delta(id, now - before)
	for id: Variant in _inv_snapshot:
		if not seen.has(id) and int(_inv_snapshot[id]) != 0:
			_toast_delta(id, -int(_inv_snapshot[id]))
	_inv_snapshot = GameState.inventory.duplicate()

func _toast_delta(item_id: Variant, delta: int) -> void:
	var display := String(item_id)
	var def := Db.get_item(StringName(String(item_id)))
	if def != null and not def.display_name.is_empty():
		display = def.display_name
	var sign_text := "+%d" % delta if delta > 0 else str(delta)
	show_toast("%s %s" % [display, sign_text], InkStyle.INK if delta > 0 else InkStyle.SEAL)

func show_toast(text: String, color: Color = InkStyle.INK) -> void:
	if _toast_box.get_child_count() >= TOAST_MAX:
		var oldest := _toast_box.get_child(0)
		_toast_box.remove_child(oldest)
		oldest.queue_free()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", InkStyle.make_panel(
		Color(InkStyle.PAPER.r, InkStyle.PAPER.g, InkStyle.PAPER.b, 0.92),
		InkStyle.INK, 1, 3, 8, 3))
	var label := InkStyle.make_label(text, 9, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(label)
	_toast_box.add_child(panel)
	var tw := panel.create_tween()
	tw.tween_interval(TOAST_HOLD_SEC)
	tw.tween_property(panel, "modulate:a", 0.0, TOAST_FADE_SEC)
	tw.tween_callback(panel.queue_free)

# ── 탁본 진행 바

func _on_rubbing_started(_fragment_id: StringName) -> void:
	_rubbing_box.visible = true
	_rubbing_label.text = "탁본을 뜨는 중… 무방비!"
	_rubbing_bar.value = 0.0
	if _rubbing_tween != null and _rubbing_tween.is_valid():
		_rubbing_tween.kill()
	_rubbing_tween = create_tween()
	_rubbing_tween.tween_property(
		_rubbing_bar, "value", _rubbing_bar.max_value, GameState.balance.rubbing_duration_sec)

func _on_rubbing_completed(_fragment_id: StringName) -> void:
	if _rubbing_tween != null and _rubbing_tween.is_valid():
		_rubbing_tween.kill()
	_rubbing_box.visible = false
	show_toast("탁본 완료 — 조각을 가방에 넣었다.", InkStyle.INK)

# ── 캐스팅 실패 사유 토스트

func _on_cast_failed(_design: SpellDesign, reason: int) -> void:
	match reason:
		Enums.CastFailReason.NO_MANA:
			show_toast("마나가 부족하다!", InkStyle.SEAL)
		Enums.CastFailReason.BROKEN:
			show_toast("도안이 손상됐다 — 수리가 필요하다.", InkStyle.SEAL)
		_:
			show_toast("발동에 실패했다.", InkStyle.SEAL)
