extends Node2D
## 피격 손맛 통제소 — 화면 흔들림 · 히트스톱 · 떠오르는 피해 숫자. Player 아래 공용 노드라
## 마을·보스방 양쪽에서 자동으로 산다. 넉백·팝은 적 자신이 하고, 여긴 "월드 전체 반응"만 든다.
##
## 🔴 EventBus만 본다(타 모듈 직접 참조 금지).
## 카메라 offset = 지터(트라우마) + 킥(방향 벡터). 지터 진폭이 trauma²이라 잔진동은 미미하고
## 큰 사건만 크게 흔든다.
## 🔴 **offset 대입은 `_process` 한 곳뿐이다** — 두 곳이 쓰면 서로 덮는 3파전이 된다.
## 🔴 수치는 밸런스가 아니라 연출값(손맛)이라 const다.

const DamageNumber := preload("res://src/hud/damage_number.tscn")

const TRAUMA_HIT := 0.18         ## 타격 1회 트라우마 가산
const TRAUMA_KILL := 0.35        ## 처치
const TRAUMA_HURT := 0.5         ## 내가 맞았을 때 (제일 크게)
const TRAUMA_DECAY := 1.4        ## 트라우마 선형 감쇠(/s)
const SHAKE_MAX_PX := 7.0        ## trauma=1일 때 지터 진폭(px) — 실진폭 = 이 값 × trauma²
const HURT_KICK_PX := 5.0        ## 피격 방향성 킥(px) — 맞은 방향 **반대**(밀려나는 쪽)
const RECOIL_PX := 2.0           ## 발사 반동 킥(px) — 조준 반대
const KICK_RETURN := 40.0        ## 킥 복귀 속도(px/s, move_toward)
const HITSTOP_HIT := 0.035       ## 타격 정지(s)
const HITSTOP_KILL := 0.07       ## 처치 정지(s)
const HITSTOP_SCALE := 0.05      ## 정지 중 Engine.time_scale
const HITSTOP_COOLDOWN := 0.08   ## 정지 재발동 최소 간격 — 연타로 얼어붙지 않게
const BIG_HIT := 60.0            ## 이 이상이면 큰 숫자(금색)

var _camera: Camera2D = null
var _trauma: float = 0.0
var _kick: Vector2 = Vector2.ZERO
var _hitstop_cool: float = 0.0
## 히트스톱 토큰 — 겹칠 때 **마지막 발동만** time_scale을 되돌린다 (짧은 게 긴 걸 먼저 풀어 버리지 않게).
var _hitstop_token: int = 0


func _ready() -> void:
	_camera = get_parent().get_node_or_null(^"Camera2D") as Camera2D
	EventBus.enemy_hit.connect(_on_enemy_hit)
	EventBus.enemy_died.connect(_on_enemy_died)
	# 🔴 HP 감소 추측이 아니라 `player_hurt`를 구독한다 — 회복·출격 만HP에 오발하지 않는다.
	EventBus.player_hurt.connect(_on_player_hurt)
	EventBus.ring_cast_requested.connect(_on_cast)


func _process(delta: float) -> void:
	_hitstop_cool = maxf(0.0, _hitstop_cool - delta)
	if _camera == null:
		return
	_trauma = maxf(0.0, _trauma - TRAUMA_DECAY * delta)
	_kick = _kick.move_toward(Vector2.ZERO, KICK_RETURN * delta)
	if _trauma > 0.0 or _kick != Vector2.ZERO:
		var amp := SHAKE_MAX_PX * _trauma * _trauma
		var jitter := Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
		_camera.offset = jitter + _kick
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO


func _add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _on_enemy_hit(enemy: Node2D, damage: float, _rune: int) -> void:
	if is_instance_valid(enemy):
		_spawn_number(enemy.global_position, damage, damage >= BIG_HIT)
	_add_trauma(TRAUMA_HIT)
	_hitstop(HITSTOP_HIT)


func _on_enemy_died(_id: StringName) -> void:
	_add_trauma(TRAUMA_KILL)
	# 처치는 같은 프레임의 타격 히트스톱(쿨다운 걸림)을 넘어 더 길게 — force=true.
	_hitstop(HITSTOP_KILL, true)


## 킥 = (나 − 가해자) 방향 = 밀려나는 쪽. ⚠ source_pos INF는 「방향 모름」 센티널이라 킥 없이 넘긴다.
func _on_player_hurt(_amount: float, source_pos: Vector2) -> void:
	_add_trauma(TRAUMA_HURT)
	if not source_pos.is_finite():
		return
	var me := get_parent() as Node2D
	if me == null:
		return
	var away := me.global_position - source_pos
	if away.length() > 0.1:
		_kick = away.normalized() * HURT_KICK_PX


## 발사 반동 — 조준 반대로 소폭 킥. 마나 부족이면 caster가 emit 전에 걸러 헛반동이 없다.
func _on_cast(_assembly: Dictionary, _origin: Vector2, aim_dir: Vector2) -> void:
	if aim_dir.length() > 0.01:
		_kick = -aim_dir.normalized() * RECOIL_PX


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
