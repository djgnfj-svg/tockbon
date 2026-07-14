extends Control
## HUD — 좌상 HP·마나 바, 상단 하루 시계, 하단 장착 4슬롯, 우하 가방 수 (모듈 E).
## GameState/Clock 폴링 + EventBus 구독만 — 게임 로직 없음 (TECH_SPEC §10).

const InkStyle := preload("res://src/ui/ink_style.gd")
const DesignThumb := preload("res://src/core/design_thumb.gd")

const FLASH_OK := Color(1.0, 0.9, 0.55)
const FLASH_FAIL := Color(0.9, 0.35, 0.25)
const FLASH_RESTORE_SEC := 0.45

## 슬롯 칸 — 먹선 썸네일(왼쪽) + 이름·내구·마나(오른쪽). 4칸이 SlotBar 폭(402)에 들어간다
const SLOT_MIN := Vector2(96, 44)
const SLOT_THUMB := Vector2(32, 32)
## 32px 칸에서 기본 굵기는 뭉갠다 — 절반으로
const SLOT_THUMB_WIDTH := 0.5

@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_text: Label = %HpText
@onready var _mana_bar: ProgressBar = %ManaBar
@onready var _mana_text: Label = %ManaText
@onready var _day_label: Label = %DayLabel
@onready var _day_bar: ProgressBar = %DayProgress
@onready var _slot_bar: HBoxContainer = %SlotBar
@onready var _bag_label: Label = %BagLabel

## 마지막으로 방송된 페이즈 — Clock 재조회 대신 시그널 인자를 신뢰한다
var _phase: int = Enums.Phase.MORNING
var _slot_panels: Array[PanelContainer] = []
var _slot_thumbs: Array[Control] = []
var _slot_name_labels: Array[Label] = []
var _slot_dura_labels: Array[Label] = []
var _slot_mana_labels: Array[Label] = []
var _slot_cache_design: Array[SpellDesign] = [null, null, null, null]
var _slot_cache_dura := PackedInt32Array([-2, -2, -2, -2])
var _slot_tweens: Array[Tween] = [null, null, null, null]
var _mana_shown := -1
var _bag_shown := -1

func _ready() -> void:
	_phase = Clock.phase
	_refresh_bar_maxes()
	_style_bars()
	_build_slots()
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.day_started.connect(_on_day_started)
	EventBus.player_hp_changed.connect(_on_player_hp_changed)
	EventBus.equipment_changed.connect(_on_equipment_changed)
	EventBus.cast_executed.connect(_on_cast_executed)
	EventBus.cast_failed.connect(_on_cast_failed)
	_refresh_hp()
	_refresh_clock_label()

## 상한은 장비(로브)에 따라 변한다 — balance 직접 참조 금지 (TECH_SPEC §4.2)
func _refresh_bar_maxes() -> void:
	_hp_bar.max_value = GameState.hp_max()
	_mana_bar.max_value = GameState.mana_max()
	_mana_shown = -1  # 마나 텍스트 분모 갱신 강제

func _process(_delta: float) -> void:
	# 마나 — 자연 회복으로 매 프레임 변하므로 폴링 (텍스트는 정수 변화 시만)
	_mana_bar.value = GameState.mana
	var mana_now := int(ceilf(GameState.mana))
	if mana_now != _mana_shown:
		_mana_shown = mana_now
		_mana_text.text = "%d/%d" % [mana_now, int(GameState.mana_max())]
	_day_bar.value = Clock.day_progress() * 100.0
	var bag_now := _bag_total()
	if bag_now != _bag_shown:
		_bag_shown = bag_now
		_bag_label.text = "가방 %d" % bag_now
	_refresh_slots()

# ── 구성

func _style_bars() -> void:
	_hp_bar.add_theme_stylebox_override("fill", InkStyle.make_bar_fill(InkStyle.SEAL))
	_mana_bar.add_theme_stylebox_override("fill", InkStyle.make_bar_fill(InkStyle.RUNE_COLORS[Enums.RuneType.WATER]))
	_day_bar.add_theme_stylebox_override("fill", InkStyle.make_bar_fill(InkStyle.phase_color(Clock.phase)))

func _build_slots() -> void:
	for i in GameState.EQUIP_SLOTS:
		var panel := PanelContainer.new()
		panel.name = "Slot%d" % (i + 1)
		panel.custom_minimum_size = SLOT_MIN
		panel.add_theme_stylebox_override("panel", InkStyle.make_panel(
			Color(InkStyle.PAPER.r, InkStyle.PAPER.g, InkStyle.PAPER.b, 0.88),
			InkStyle.INK, 1, 3, 5, 3))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var thumb := DesignThumb.new()
		thumb.name = "Thumb"
		thumb.custom_minimum_size = SLOT_THUMB
		thumb.width_mult = SLOT_THUMB_WIDTH
		# strokes 없는 도안(샘플·구세이브)은 룬 표기로 — core는 폴백 모양을 모른다
		thumb.fallback_builder = InkStyle.make_design_fallback
		thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(thumb)

		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vb.add_theme_constant_override("separation", 0)
		var name_l := InkStyle.make_label("", 9)
		name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var dura_l := InkStyle.make_label("", 8, InkStyle.INK_SOFT)
		dura_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var mana_l := InkStyle.make_label("", 8, InkStyle.INK_SOFT)
		mana_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		vb.add_child(name_l)
		vb.add_child(dura_l)
		vb.add_child(mana_l)
		row.add_child(vb)

		panel.add_child(row)
		_slot_bar.add_child(panel)
		_slot_panels.append(panel)
		_slot_thumbs.append(thumb)
		_slot_name_labels.append(name_l)
		_slot_dura_labels.append(dura_l)
		_slot_mana_labels.append(mana_l)

# ── 갱신

func _refresh_slots() -> void:
	for i in GameState.EQUIP_SLOTS:
		var d: SpellDesign = GameState.equipped[i]
		var dura := d.durability if d != null else -1
		if d == _slot_cache_design[i] and dura == _slot_cache_dura[i]:
			continue
		_slot_cache_design[i] = d
		_slot_cache_dura[i] = dura
		_slot_thumbs[i].call("set_design", d)
		if d == null:
			_slot_name_labels[i].text = "%d · 비어 있음" % (i + 1)
			_slot_name_labels[i].add_theme_color_override("font_color", InkStyle.INK_FAINT)
			_slot_dura_labels[i].text = "—"
			_slot_dura_labels[i].add_theme_color_override("font_color", InkStyle.INK_FAINT)
			_slot_mana_labels[i].text = ""
		else:
			_slot_name_labels[i].text = "%d · %s" % [i + 1, d.display_name]
			_slot_name_labels[i].add_theme_color_override("font_color", InkStyle.INK)
			if d.is_broken():
				_slot_dura_labels[i].text = "손상 — 수리 필요"
				_slot_dura_labels[i].add_theme_color_override("font_color", InkStyle.SEAL)
			else:
				_slot_dura_labels[i].text = "내구 %d/%d" % [d.durability, d.durability_max]
				_slot_dura_labels[i].add_theme_color_override("font_color", InkStyle.INK_SOFT)
			# 농도(v1.7)는 상태이상 세기다 — 같은 룬이라도 짙은 도안과 옅은 도안은 다른 무기다 (GDD §4.2)
			_slot_mana_labels[i].text = "%s%s %s · 마나 %d" % [
				InkStyle.rune_glyph(d.rune_type), InkStyle.rune_name(d.rune_type),
				InkStyle.density_name(d.rune_fill), int(d.mana_cost)]

func _refresh_hp() -> void:
	# HP 원장은 GameState (v1.1 이관) — player_hp_changed로 갱신
	_hp_bar.value = GameState.hp
	_hp_text.text = "%d/%d" % [int(ceilf(GameState.hp)), int(GameState.hp_max())]

func _refresh_clock_label() -> void:
	_day_label.text = "%d일차 · %s %s" % [
		Clock.day, InkStyle.phase_glyph(_phase), InkStyle.phase_name(_phase)]

# ── 시그널

func _on_day_started(_day: int) -> void:
	_phase = Clock.phase
	_refresh_clock_label()

func _on_phase_changed(phase: int) -> void:
	_phase = phase
	_refresh_clock_label()
	_day_bar.add_theme_stylebox_override("fill", InkStyle.make_bar_fill(InkStyle.phase_color(phase)))

func _on_player_hp_changed(_hp: float, _hp_max: float) -> void:
	_refresh_hp()

func _on_equipment_changed() -> void:
	_refresh_bar_maxes()
	_refresh_hp()

func _on_cast_executed(design: SpellDesign, _mana_spent: float) -> void:
	_flash(GameState.equipped.find(design), FLASH_OK)

func _on_cast_failed(design: SpellDesign, _reason: int) -> void:
	_flash(GameState.equipped.find(design), FLASH_FAIL)

func _flash(slot: int, color: Color) -> void:
	if slot < 0 or slot >= _slot_panels.size():
		return
	if _slot_tweens[slot] != null and _slot_tweens[slot].is_valid():
		_slot_tweens[slot].kill()
	_slot_panels[slot].modulate = color
	var tw := create_tween()
	tw.tween_property(_slot_panels[slot], "modulate", Color.WHITE, FLASH_RESTORE_SEC)
	_slot_tweens[slot] = tw

func _bag_total() -> int:
	var total := 0
	for entry: Dictionary in GameState.bag:
		total += int(entry.get("count", 0))
	return total
