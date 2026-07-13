extends Node2D
## 거점 오두막 (모듈 D) — 작업대·창고·연구소·침대 상호작용, 패널 관리, 연구 폴링 (TECH_SPEC §7).
## 플레이어는 임시 WASD 노드 — 통합 시 모듈 C 플레이어로 교체.

const WorkbenchService := preload("res://src/base/workbench_service.gd")
const ResearchService := preload("res://src/base/research_service.gd")
const WorkbenchPanel := preload("res://src/base/workbench_panel.gd")
const StoragePanel := preload("res://src/base/storage_panel.gd")
const LabPanel := preload("res://src/base/lab_panel.gd")
const Recipes := preload("res://src/base/recipes.gd")
const BasePlayer := preload("res://src/base/base_player.gd")

## 인테리어 소품 시트 (ART_SPEC P3) — 32×48 가로 스트립, 없으면 ColorRect 플레이스홀더 유지
const PROPS_SHEET_PATH := "res://assets/sprites/base/props.png"
const PROP_INDEX := {&"workbench": 0, &"storage": 1, &"lab": 2, &"bed": 3, &"door": 4, &"easel": 5}
## 거점 임시 플레이어의 겉모습 — 필드 주인공 시트의 정면 idle 1프레임 재사용
const PLAYER_SHEET_PATH := "res://assets/sprites/player/player.png"

var _workbench_service: WorkbenchService
var _research_service: ResearchService
## {facility_id: CenterContainer(래퍼)} / {facility_id: 패널}
var _wraps: Dictionary = {}
var _panels: Dictionary = {}
var _status: Label
var _toast: Label
var _toast_seq: int = 0
var _theme: Theme
## 튜토리얼 유도 마커 (EventBus.tutorial_focus) — 대상 시설 위에서 까딱이는 ▼
var _focus_marker: Label

@onready var _player: BasePlayer = $Player
@onready var _ui: CanvasLayer = $UI

func _ready() -> void:
	_workbench_service = WorkbenchService.new()
	_research_service = ResearchService.new()
	_theme = Theme.new()
	_theme.default_font_size = 11
	_build_hud()
	_add_panel(&"workbench", WorkbenchPanel.new(_workbench_service))
	_add_panel(&"storage", StoragePanel.new())
	_add_panel(&"lab", LabPanel.new(_research_service))
	for node in $Interactables.get_children():
		node.activated.connect(_on_facility)
	_apply_sprites()
	EventBus.research_completed.connect(func(unlock_id: StringName) -> void:
		var p: Dictionary = Recipes.RESEARCH.get(unlock_id, {})
		_show_toast("연구 완료: %s" % p.get("name", unlock_id)))
	EventBus.tutorial_focus.connect(_on_tutorial_focus)
	EventBus.cast_failed.connect(_on_cast_failed)

## 플레이스홀더 ColorRect → 스프라이트 교체 (시트 없으면 그대로)
func _apply_sprites() -> void:
	if ResourceLoader.exists(PROPS_SHEET_PATH):
		var tex: Texture2D = load(PROPS_SHEET_PATH)
		for node in $Interactables.get_children():
			var idx: int = PROP_INDEX.get(node.get("facility_id"), -1)
			if idx < 0:
				continue
			var visual := node.get_node_or_null("Visual") as CanvasItem
			if visual != null:
				visual.visible = false
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(idx * 32, 0, 32, 48)
			var spr := Sprite2D.new()
			spr.texture = at
			spr.position = Vector2(0, -8)   # 하단을 기존 32×32 비주얼 바닥에 맞춤
			node.add_child(spr)
	if ResourceLoader.exists(PLAYER_SHEET_PATH):
		var p_visual := _player.get_node_or_null("Visual") as CanvasItem
		if p_visual != null:
			p_visual.visible = false
		var p_at := AtlasTexture.new()
		p_at.atlas = load(PLAYER_SHEET_PATH)
		p_at.region = Rect2(0, 0, 32, 32)
		var p_spr := Sprite2D.new()
		p_spr.texture = p_at
		p_spr.position = Vector2(0, -6)
		_player.add_child(p_spr)

func _process(_delta: float) -> void:
	# 연구는 패널이 닫혀 있어도 진행·완료돼야 한다
	_research_service.poll()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and _any_panel_open():
		_close_all()
		get_viewport().set_input_as_handled()

# ── 시설

func _on_facility(facility_id: StringName) -> void:
	if facility_id == &"bed":
		Clock.sleep_until_morning()
		_show_toast("푹 잤다 — Day %d 아침, 마나 회복" % Clock.day)
		return
	if facility_id == &"door":
		EventBus.scene_change_requested.emit(&"field")
		return
	if facility_id == &"easel":
		EventBus.scene_change_requested.emit(&"drawing")
		return
	_open(facility_id)

func _open(facility_id: StringName) -> void:
	if not _wraps.has(facility_id):
		return
	_close_all()
	_wraps[facility_id].visible = true
	_panels[facility_id].open()
	_player.locked = true

func _close_all() -> void:
	for facility_id: StringName in _wraps:
		_wraps[facility_id].visible = false
	_player.locked = false

func _any_panel_open() -> bool:
	for facility_id: StringName in _wraps:
		if _wraps[facility_id].visible:
			return true
	return false

# ── 온보딩 지원 (TECH_SPEC §5 — 튜토리얼이 시그널로만 거점을 유도한다)

## 튜토리얼이 지목한 시설 위에 마커를 옮겨 단다. target_id = &"" 면 해제.
## 유효 대상: Interactables의 facility_id(easel·door·workbench…) + &"dummy"(허수아비).
func _on_tutorial_focus(target_id: StringName) -> void:
	if _focus_marker != null:
		_focus_marker.queue_free()
		_focus_marker = null
	if target_id == StringName():
		return
	var target := _find_focus_target(target_id)
	if target == null:
		return
	_focus_marker = Label.new()
	_focus_marker.text = "▼"
	_focus_marker.add_theme_font_size_override(&"font_size", 14)
	_focus_marker.add_theme_color_override(&"font_color", Color(0.710, 0.278, 0.180))
	_focus_marker.position = Vector2(-6, -46)
	target.add_child(_focus_marker)
	var bob := _focus_marker.create_tween().set_loops()
	bob.tween_property(_focus_marker, "position:y", -40.0, 0.5).set_trans(Tween.TRANS_SINE)
	bob.tween_property(_focus_marker, "position:y", -46.0, 0.5).set_trans(Tween.TRANS_SINE)

func _find_focus_target(target_id: StringName) -> Node2D:
	if target_id == &"dummy":
		return get_node_or_null("TrainingDummy") as Node2D
	for node in $Interactables.get_children():
		if node.get("facility_id") == target_id:
			return node as Node2D
	return null

## 시험 발사 실패 안내 — 거점에는 작업대(수리)와 침대(마나 회복)가 있다.
## 여기서 막다른 길에 빠지지 않게 무엇을 하면 되는지 알려준다.
func _on_cast_failed(_design: SpellDesign, reason: int) -> void:
	match reason:
		Enums.CastFailReason.NO_MANA:
			_show_toast("마나가 모자란다 — 잠시 기다리거나 침대에서 자고 나면 회복된다")
		Enums.CastFailReason.BROKEN:
			_show_toast("도안이 손상됐다 — 작업대에서 수리하라")
		_:
			_show_toast("아직 그릴 도안이 없다 — 이젤 앞에 앉아라")

# ── UI 조립

func _add_panel(facility_id: StringName, panel: PanelContainer) -> void:
	var wrap := CenterContainer.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.theme = _theme
	wrap.visible = false
	wrap.add_child(panel)
	_ui.add_child(wrap)
	panel.close_requested.connect(_close_all)
	_wraps[facility_id] = wrap
	_panels[facility_id] = panel

func _build_hud() -> void:
	# Day·마나 표시는 전역 HUD(모듈 E) 소관 — 여기는 조작 힌트만 (중복 제거, v1.1)
	_status = Label.new()
	_status.text = "이동 WASD · 상호작용 E · 캐스트 1~4 (마우스로 조준) · 닫기 ESC"
	_status.position = Vector2(8, 344)
	_status.theme = _theme
	_ui.add_child(_status)
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 26.0
	_toast.offset_bottom = 46.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.theme = _theme
	_toast.visible = false
	_ui.add_child(_toast)

func _show_toast(message: String) -> void:
	_toast_seq += 1
	var seq := _toast_seq
	_toast.text = message
	_toast.visible = true
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if _toast_seq == seq:
			_toast.visible = false)
