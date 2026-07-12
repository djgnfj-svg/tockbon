extends Node
## 게임 내 시간 — 상시 진행, 낮밤 페이즈 (GDD §7, TECH_SPEC §3).
## 페이즈 전환·하루 시작은 EventBus로 방송된다.

var balance: BalanceData = preload("res://data/balance.tres")

var day: int = 1
## 하루 내 경과 (초)
var time_sec: float = 0.0
var phase: Enums.Phase = Enums.Phase.MORNING
var paused: bool = false

func _ready() -> void:
	# 씬 노드들의 _ready 이후에 첫 방송이 닿도록 지연
	_broadcast_day_start.call_deferred()

func _process(delta: float) -> void:
	if paused:
		return
	time_sec += delta
	if time_sec >= balance.day_length_sec:
		_next_day()
		return
	var new_phase := _phase_for(time_sec / balance.day_length_sec)
	if new_phase != phase:
		phase = new_phase
		EventBus.phase_changed.emit(phase)

## 취침 — 아침 스킵 + 마나 완전 회복 (GDD §7)
func sleep_until_morning() -> void:
	GameState.restore_mana_full()
	_next_day()

func is_night() -> bool:
	return phase == Enums.Phase.NIGHT

## 하루 진행률 0..1 (HUD 시계용)
func day_progress() -> float:
	return clampf(time_sec / balance.day_length_sec, 0.0, 1.0)

func _phase_for(frac: float) -> Enums.Phase:
	var acc := 0.0
	for i in range(balance.phase_fracs.size()):
		acc += balance.phase_fracs[i]
		if frac < acc:
			return i as Enums.Phase
	return Enums.Phase.NIGHT

func _next_day() -> void:
	day += 1
	time_sec = 0.0
	phase = Enums.Phase.MORNING
	_broadcast_day_start()

func _broadcast_day_start() -> void:
	EventBus.day_started.emit(day)
	EventBus.phase_changed.emit(phase)
