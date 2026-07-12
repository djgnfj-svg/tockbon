extends Control
## 퀘스트 온보딩 — 선형 목표 스택 (GDD 4개월차 / NEXT_CYCLE §3 / TECH_SPEC §5.1·§7).
## Main의 UILayer에 인스턴스 1개 추가하면 자립 동작한다:
## 기존 EventBus 시그널(rubbing_completed·research_completed·enemy_died)만으로
## 단계 완료를 판정하고, 진행은 codex_unlocked(quest_<n>) 발신으로 저장한다
## (GameState가 codex에 등록 → SaveManager 자동 커버). 타 모듈 노드 접근 없음.

const InkStyle := preload("res://src/ui/ink_style.gd")

const TUTORIAL_UNLOCK := &"tutorial_done"
const CLEAR_TEXT := "데모 클리어 — 바람의 글자가 숲에 되돌아왔다"

## 선형 목표 스택. 완료 판정은 아래 시그널 핸들러가 단계 인덱스로 게이트한다.
## 활성 단계가 아니면 어떤 시그널도 진행시키지 않는다 (선행 단계 강제).
const STEPS := [
	{"unlock": &"quest_1", "goal": "숲에서 수액 슬라임 우두머리를 찾아 물의 글자를 탁본하라"},
	{"unlock": &"quest_2", "goal": "연구소에서 물의 글자를 해독하라"},
	{"unlock": &"quest_3", "goal": "물의 도안을 그려 갑주 갑충을 무찔러라"},
	{"unlock": &"quest_4", "goal": "숲 북쪽의 바람을 품은 존재에 도전하라"},
]

# 연출 타이밍 (초)
const CHECK_HOLD_SEC := 1.4   # ✓ 유지
const CLEAR_HOLD_SEC := 6.0   # 데모 클리어 문구 유지
const FADE_SEC := 0.35

# 뷰포트 640×360 — HUD TopBar(중앙 상단, y≤38)를 피한 우상단 자리
const TOP_OFFSET := 40.0
const RIGHT_MARGIN := 6.0

var _started := false
var _step := 0   # 현재 활성 단계 인덱스. STEPS.size() 도달 = 전부 완료
var _panel: PanelContainer
var _goal_label: Label
var _tween: Tween


func _ready() -> void:
	_build_ui()
	visible = false
	EventBus.rubbing_completed.connect(_on_rubbing_completed)
	EventBus.research_completed.connect(_on_research_completed)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.codex_unlocked.connect(_on_codex_unlocked)
	# 세이브 로드 등으로 이미 튜토가 끝난 상태 — 즉시 시작 (진행 복원 포함)
	if GameState.is_unlocked(TUTORIAL_UNLOCK):
		_start()


# ─────────────────────────── 진행 판정 (시그널 전용) ───────────────────────────

func _on_codex_unlocked(unlock_id: StringName) -> void:
	if not _started and unlock_id == TUTORIAL_UNLOCK:
		_start()


func _on_rubbing_completed(fragment_id: StringName) -> void:
	if _active(0) and fragment_id == &"fragment_water":
		_complete_step()


func _on_research_completed(unlock_id: StringName) -> void:
	if _active(1) and unlock_id == &"rune_water":
		_complete_step()


func _on_enemy_died(enemy_def: EnemyDef, _position: Vector2) -> void:
	if enemy_def == null:
		return
	if _active(2) and enemy_def.id == &"beetle":
		_complete_step()
	elif _active(3) and enemy_def.id == &"gale":
		_complete_step()


func _active(step: int) -> bool:
	return _started and _step == step


func _start() -> void:
	_started = true
	# codex(quest_<n>)에서 진행 복원 — 완료된 단계를 건너뛴다
	_step = 0
	while _step < STEPS.size() and GameState.is_unlocked(STEPS[_step].unlock):
		_step += 1
	if _step >= STEPS.size():
		return  # 데모 클리어 상태로 복원 — 표시할 목표 없음
	_show_goal()
	visible = true


func _complete_step() -> void:
	var done: Dictionary = STEPS[_step]
	EventBus.codex_unlocked.emit(done.unlock)
	_step += 1
	_play_check(String(done.goal))


# ─────────────────────────── 표시·연출 ───────────────────────────

## 완료 체크 연출: ✓ 팝 → 잠시 유지 → 다음 목표 페이드 인 (마지막이면 클리어 문구)
func _play_check(done_goal: String) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = true
	_panel.modulate.a = 1.0
	_set_text("✓ " + done_goal, InkStyle.SEAL)
	_panel.pivot_offset = Vector2(_panel.size.x, 0.0)  # 우상단 모서리 고정 팝
	_panel.scale = Vector2.ONE
	_tween = create_tween()
	_tween.tween_property(_panel, "scale", Vector2(1.08, 1.08), 0.08)
	_tween.tween_property(_panel, "scale", Vector2.ONE, 0.12)
	_tween.tween_interval(CHECK_HOLD_SEC)
	if _step >= STEPS.size():
		_tween.tween_callback(_show_clear)
		_tween.tween_interval(CLEAR_HOLD_SEC)
		_tween.tween_property(_panel, "modulate:a", 0.0, FADE_SEC)
		_tween.tween_callback(_hide_done)
	else:
		_tween.tween_callback(_show_goal)
		_tween.tween_callback(func() -> void: _panel.modulate.a = 0.0)
		_tween.tween_property(_panel, "modulate:a", 1.0, FADE_SEC)


func _show_goal() -> void:
	_set_text(String(STEPS[_step].goal), InkStyle.INK)


func _show_clear() -> void:
	_set_text(CLEAR_TEXT, InkStyle.SEAL)


func _hide_done() -> void:
	visible = false
	_panel.modulate.a = 1.0


func _set_text(text: String, color: Color) -> void:
	_goal_label.text = text
	_goal_label.add_theme_color_override(&"font_color", color)
	_panel.reset_size()  # 문구 길이에 맞게 축소 (앵커 우측 고정 → 왼쪽으로 늘어남)


# ─────────────────────────── UI 빌드 (전부 코드 생성) ───────────────────────────

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "GoalPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.offset_top = TOP_OFFSET
	_panel.offset_right = -RIGHT_MARGIN
	_panel.add_theme_stylebox_override(&"panel", InkStyle.make_panel(
			Color(InkStyle.PAPER.r, InkStyle.PAPER.g, InkStyle.PAPER.b, 0.92),
			InkStyle.INK, 1, 3, 8, 4))
	add_child(_panel)

	_goal_label = InkStyle.make_label("", 9)
	_goal_label.name = "GoalLabel"
	_goal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_goal_label)
