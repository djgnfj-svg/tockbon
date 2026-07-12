extends "res://src/base/panel_base.gd"
## 연구소 패널 — 탁본 조각 해독·제법 연구 (모듈 D 임시 UI).
## 진행 중 연구는 1개, 소요 시간은 게임 시간 기준 (balance.research_time_sec).

const Recipes := preload("res://src/base/recipes.gd")
const ResearchService := preload("res://src/base/research_service.gd")

var _svc: ResearchService
var _current_label: Label
var _bar: ProgressBar
var _list_box: VBoxContainer

func _init(svc: ResearchService) -> void:
	super()
	_svc = svc
	set_title("연구소")
	_current_label = Label.new()
	content.add_child(_current_label)
	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.custom_minimum_size = Vector2(0, 12)
	content.add_child(_bar)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_box)
	EventBus.resources_changed.connect(_on_changed, CONNECT_DEFERRED)
	EventBus.research_completed.connect(_on_research_completed, CONNECT_DEFERRED)

func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	if _svc.is_researching():
		var p: Dictionary = Recipes.RESEARCH[_svc.current_id]
		_current_label.text = "진행 중: %s — %d%% (남은 %d초)" % [
			p["name"], int(_svc.progress() * 100.0), int(_svc.remaining_sec())]
		_bar.value = _svc.progress()
	else:
		_current_label.text = "진행 중인 연구 없음"
		_bar.value = 0.0

func _on_changed() -> void:
	if is_visible_in_tree():
		refresh()

func _on_research_completed(_unlock_id: StringName) -> void:
	if is_visible_in_tree():
		refresh()

func refresh() -> void:
	clear_box(_list_box)
	for project_id: StringName in Recipes.RESEARCH:
		var p: Dictionary = Recipes.RESEARCH[project_id]
		var state := _state_text(project_id, p)
		var row := add_row(_list_box, "%s — 비용: %s%s" % [p["name"], fmt_items(p["cost"]), state])
		if _svc.current_id == project_id:
			add_button(row, "즉시 완료(디버그)", true, _do_force_complete)
		else:
			add_button(row, "시작", _svc.can_start(project_id), _do_start.bind(project_id))

func _state_text(project_id: StringName, p: Dictionary) -> String:
	if GameState.is_unlocked(project_id):
		return "  [완료]"
	if _svc.current_id == project_id:
		return "  [진행 중]"
	if _svc.is_researching():
		return "  [대기 — 진행 중 연구 있음]"
	var prereq: StringName = p["prereq"]
	if prereq != &"" and not GameState.is_unlocked(prereq):
		return "  [선행 필요: %s]" % prereq
	if not GameState.can_afford(p["cost"]):
		return "  [재료 부족]"
	return ""

func _do_start(project_id: StringName) -> void:
	_svc.start(project_id)
	refresh.call_deferred()

func _do_force_complete() -> void:
	_svc.force_complete()
	refresh.call_deferred()
