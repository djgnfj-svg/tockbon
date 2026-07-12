extends RefCounted
## 연구소 서비스 — 창고의 조각·재료 소모 → 게임 시간 경과 후 research_completed 발신 (모듈 D).
## 진행 중 연구는 1개 (GDD §6). 소요 시간 = balance.research_time_sec (플레이 시간 기준).
## 상태는 static — 씬 전환·서비스 재생성에도 유지된다.

const Recipes := preload("res://src/base/recipes.gd")

static var current_id: StringName = &""
static var started_at_sec: float = -1.0

## 절대 게임 시간 = (day-1)×하루 길이 + 오늘 경과.
## 취침(sleep_until_morning)으로 스킵된 밤 시간도 연구에 반영된다.
func abs_game_time() -> float:
	return float(Clock.day - 1) * GameState.balance.day_length_sec + Clock.time_sec

func is_researching() -> bool:
	return current_id != &""

func can_start(project_id: StringName) -> bool:
	if is_researching():
		return false
	var p: Dictionary = Recipes.RESEARCH.get(project_id, {})
	if p.is_empty():
		return false
	if GameState.is_unlocked(project_id):
		return false
	var prereq: StringName = p["prereq"]
	if prereq != &"" and not GameState.is_unlocked(prereq):
		return false
	return GameState.can_afford(p["cost"])

func start(project_id: StringName) -> bool:
	if not can_start(project_id):
		return false
	var p: Dictionary = Recipes.RESEARCH[project_id]
	if not GameState.spend(p["cost"]):
		return false
	current_id = project_id
	started_at_sec = abs_game_time()
	return true

func progress() -> float:
	if not is_researching():
		return 0.0
	var t: float = GameState.balance.research_time_sec
	if t <= 0.0:
		return 1.0
	return clampf((abs_game_time() - started_at_sec) / t, 0.0, 1.0)

func remaining_sec() -> float:
	if not is_researching():
		return 0.0
	return maxf(GameState.balance.research_time_sec - (abs_game_time() - started_at_sec), 0.0)

## 완료 검사 — 시간이 찼으면 research_completed 발신 후 true.
## 거점 씬이 매 프레임 호출한다 (타이머 노드 대신 Clock 기준 폴링).
func poll() -> bool:
	if not is_researching() or progress() < 1.0:
		return false
	_complete()
	return true

## 디버그·테스트용 — 남은 시간 무시하고 즉시 완료
func force_complete() -> bool:
	if not is_researching():
		return false
	_complete()
	return true

func _complete() -> void:
	var finished := current_id
	current_id = &""
	started_at_sec = -1.0
	EventBus.research_completed.emit(finished)
