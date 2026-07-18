extends Node2D
## 피격 손맛 통제소 (세션 38) — 화면 흔들림 · 히트스톱 · 떠오르는 피해 숫자를 한 곳에 모은다.
## Player 아래 공용 노드라 **베이스·숲 양쪽에서 자동으로 산다** (player가 공용 배우이므로 —
## 씬마다 배선하지 않는다). 넉백·팝은 적 자신이 한다(forest_enemy._pop) — 여긴 "월드 전체 반응"만.
##
## 🔴 EventBus만 본다 (타 모듈 직접 참조 금지). 신호 셋:
##   enemy_hit → 피해 숫자 + 작은 흔들림 + 짧은 히트스톱
##   enemy_died → 처치 흔들림 + 조금 긴 히트스톱
##   player_hp_changed(감소) → 큰 흔들림 (내가 맞았다는 위험 신호)
##
## 🔴 여기 수치는 밸런스가 아니라 **연출값(손맛)이다** (projectile 물리 여유 const 선례) —
## balance.tres가 아니라 여기 const로 둔다. 사용자가 직접 그어/맞아 보며 조일 값이다.
##
## class_name 없음 — 모듈 규칙(preload로만 참조).

const DamageNumber := preload("res://src/hud/damage_number.tscn")

const SHAKE_HIT := 2.5           ## 타격 1회 흔들림 세기(px)
const SHAKE_KILL := 5.0          ## 처치 흔들림
const SHAKE_HURT := 6.0          ## 내가 맞았을 때 (더 크게)
const SHAKE_DECAY := 22.0        ## 흔들림 감쇠(px/s)
const HITSTOP_HIT := 0.035       ## 타격 정지(s)
const HITSTOP_KILL := 0.07       ## 처치 정지(s)
const HITSTOP_SCALE := 0.05      ## 정지 중 Engine.time_scale
const HITSTOP_COOLDOWN := 0.08   ## 정지 재발동 최소 간격 — 연타로 얼어붙지 않게
const BIG_HIT := 60.0            ## 이 이상이면 큰 숫자(금색)

var _camera: Camera2D = null
var _shake: float = 0.0
var _hitstop_cool: float = 0.0
## 히트스톱 토큰 — 겹칠 때 **마지막 발동만** time_scale을 되돌린다 (짧은 게 긴 걸 먼저 풀어 버리지 않게).
var _hitstop_token: int = 0
## 플레이어 HP 감소를 잡으려는 직전값 (player_hp_changed는 증감을 구분 안 해 준다).
var _last_player_hp: float = -1.0


func _ready() -> void:
	_camera = get_parent().get_node_or_null(^"Camera2D") as Camera2D
	EventBus.enemy_hit.connect(_on_enemy_hit)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_hp_changed.connect(_on_player_hp_changed)


func _process(delta: float) -> void:
	_hitstop_cool = maxf(0.0, _hitstop_cool - delta)
	if _camera == null:
		return
	if _shake > 0.05:
		_camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		_shake = maxf(0.0, _shake - SHAKE_DECAY * delta)
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO


func _on_enemy_hit(enemy: Node2D, damage: float, _rune: int) -> void:
	if is_instance_valid(enemy):
		_spawn_number(enemy.global_position, damage, damage >= BIG_HIT)
	_shake = maxf(_shake, SHAKE_HIT)
	_hitstop(HITSTOP_HIT)


func _on_enemy_died(_id: StringName) -> void:
	_shake = maxf(_shake, SHAKE_KILL)
	# 처치는 같은 프레임의 타격 히트스톱(쿨다운 걸림)을 넘어 더 길게 — force=true.
	_hitstop(HITSTOP_KILL, true)


func _on_player_hp_changed(hp: float, _hp_max: float) -> void:
	if _last_player_hp >= 0.0 and hp < _last_player_hp:
		_shake = maxf(_shake, SHAKE_HURT)
	_last_player_hp = hp


func _spawn_number(pos: Vector2, amount: float, big: bool) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var dn: Label = DamageNumber.instantiate()
	dn.amount = amount
	dn.big = big
	dn.world_pos = pos
	scene.add_child(dn)


## 🔴 ignore_time_scale=true인 타이머로 복구한다 — 안 그러면 복구 타이머 자신이 느려진 시간을 타
## 영영 안 풀린다(게임이 슬로모에 갇힌다). 토큰으로 마지막 발동만 되돌린다.
func _hitstop(dur: float, force: bool = false) -> void:
	if _hitstop_cool > 0.0 and not force:
		return
	_hitstop_cool = HITSTOP_COOLDOWN
	_hitstop_token += 1
	var my := _hitstop_token
	Engine.time_scale = HITSTOP_SCALE
	var t := get_tree().create_timer(dur, true, false, true)
	t.timeout.connect(func() -> void:
		if my == _hitstop_token:
			Engine.time_scale = 1.0)
