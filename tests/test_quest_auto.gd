extends SceneTree
## 모듈 Q 자동 검증 — 퀘스트 온보딩 선형 목표 스택 (NEXT_CYCLE §3 DoD).
## 실행: Godot --headless --path . -s res://tests/test_quest_auto.gd
## 주의: -s 스크립트는 오토로드 전역 등록 전에 컴파일되므로,
## 오토로드는 root.get_node()로, quest 씬은 첫 프레임에 load()로 얻는다.

const GOAL_1 := "숲에서 수액 슬라임 우두머리를 찾아 물의 글자를 탁본하라"
const GOAL_2 := "연구소에서 물의 글자를 해독하라"
const GOAL_3 := "물의 도안을 그려 갑주 갑충을 무찔러라"
const GOAL_4 := "숲 북쪽의 바람을 품은 존재에 도전하라"
const CLEAR_TEXT := "데모 클리어 — 바람의 글자가 숲에 되돌아왔다"

var _fails: int = 0

# 오토로드 (첫 프레임에 바인딩)
var gs: Node      # GameState
var eb: Node      # EventBus

# 지연 로드 리소스
var quest_packed: PackedScene
var beetle: EnemyDef
var gale: EnemyDef

func _init() -> void:
	# 오토로드 _ready 이후에 실행되도록 첫 프레임까지 대기
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		_fails += 1
		print("FAIL: ", label)

func _run() -> void:
	gs = root.get_node(^"GameState")
	eb = root.get_node(^"EventBus")
	quest_packed = load("res://src/quest/quest.tscn") as PackedScene
	beetle = load("res://data/enemies/beetle.tres") as EnemyDef
	gale = load("res://data/enemies/gale.tres") as EnemyDef
	_check(quest_packed != null, "quest.tscn 로드")
	_check(beetle != null and beetle.id == &"beetle", "beetle.tres 로드")
	_check(gale != null and gale.id == &"gale", "gale.tres 로드")
	Engine.time_scale = 4.0  # 연출 트윈·타이머 가속 (양쪽 다 스케일되므로 판정 안전)
	await _test_full_chain()
	await _test_restore_mid()
	await _test_restore_done()
	Engine.time_scale = 1.0
	if _fails == 0:
		print("TEST_QUEST_OK")
	else:
		print("TEST_QUEST_FAILED: ", _fails)
	quit(mini(_fails, 125))

func _spawn() -> Control:
	var quest := quest_packed.instantiate() as Control
	root.add_child(quest)
	return quest

func _goal_text(quest: Control) -> String:
	return (quest.get_node(^"GoalPanel/GoalLabel") as Label).text

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

# ── 전체 체인: 비활성 → 튜토 해금 → 1~4단계 → 데모 클리어 문구 소멸

func _test_full_chain() -> void:
	var quest := _spawn()
	await process_frame
	_check(not quest.visible, "tutorial_done 해금 전 비활성(숨김)")

	# 해금 전 시그널은 진행시키지 않는다
	eb.rubbing_completed.emit(&"fragment_water")
	_check(not gs.is_unlocked(&"quest_1"), "해금 전 rubbing_completed 무시")

	# 실행 중 해금 → 1단계 표시
	eb.codex_unlocked.emit(&"tutorial_done")
	_check(quest.visible, "tutorial_done 해금 시 표시")
	_check(_goal_text(quest) == GOAL_1, "1단계 목표 문구")

	# 오답·순서 밖 시그널 무시
	eb.rubbing_completed.emit(&"fragment_wind")
	_check(not gs.is_unlocked(&"quest_1"), "다른 조각(fragment_wind) 무시")
	eb.research_completed.emit(&"rune_wind")
	eb.enemy_died.emit(beetle, Vector2.ZERO)
	_check(not gs.is_unlocked(&"quest_2") and not gs.is_unlocked(&"quest_3"),
			"순서 밖 research/enemy_died 무시")

	# 1단계: 물 조각 탁본
	eb.rubbing_completed.emit(&"fragment_water")
	_check(gs.is_unlocked(&"quest_1"), "quest_1 codex 등록")
	_check(_goal_text(quest).begins_with("✓"), "완료 체크(✓) 연출 표시")
	await _wait(2.4)  # 팝 0.2 + 유지 1.4 + 페이드 0.35 + 여유
	_check(_goal_text(quest) == GOAL_2, "2단계 목표 전환")

	# 2단계: 물 룬 해독
	eb.research_completed.emit(&"rune_water")
	_check(gs.is_unlocked(&"quest_2"), "quest_2 codex 등록")

	# 3단계: 갑주 갑충 처치 (체크 연출 중에도 판정은 즉시)
	eb.enemy_died.emit(beetle, Vector2.ZERO)
	_check(gs.is_unlocked(&"quest_3"), "quest_3 codex 등록")

	# 4단계: 보스 처치 → 데모 클리어
	eb.enemy_died.emit(gale, Vector2.ZERO)
	_check(gs.is_unlocked(&"quest_4"), "quest_4 codex 등록")
	await _wait(2.0)  # 팝 0.2 + 유지 1.4 + 여유
	_check(_goal_text(quest) == CLEAR_TEXT, "데모 클리어 문구 표시")
	await _wait(6.5)  # 클리어 유지 6.0 + 페이드 0.35 + 여유
	_check(not quest.visible, "클리어 문구 몇 초 뒤 자동 소멸")

	quest.free()
	await process_frame

# ── 중간 저장 복원: quest_2까지 해금 상태로 부팅 → 3단계부터 표시

func _test_restore_mid() -> void:
	gs.codex.erase(&"quest_3")
	gs.codex.erase(&"quest_4")
	var quest := _spawn()
	await process_frame
	_check(quest.visible, "복원 부팅: 표시")
	_check(_goal_text(quest) == GOAL_3, "복원 부팅: quest_2까지 해금 → 3단계 목표")

	# 복원 후 이어서 진행 가능
	eb.enemy_died.emit(beetle, Vector2.ZERO)
	_check(gs.is_unlocked(&"quest_3"), "복원 후 3단계 완료")
	eb.enemy_died.emit(gale, Vector2.ZERO)
	_check(gs.is_unlocked(&"quest_4"), "복원 후 4단계 완료")

	quest.free()
	await process_frame

# ── 데모 클리어 상태 복원: 전부 해금 → 표시할 목표 없음

func _test_restore_done() -> void:
	var quest := _spawn()
	await process_frame
	_check(not quest.visible, "전부 완료 상태 복원: 숨김 유지")
	quest.free()
	await process_frame
