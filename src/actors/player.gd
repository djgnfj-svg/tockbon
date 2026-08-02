extends CharacterBody2D
## 플레이어 — WASD 이동. 조준·발사·슬롯은 자식 `Caster`(player_caster.gd)가 쥔다.
## 마을과 보스방이 같은 몸을 쓴다 — 그래서 씬이 아니라 공용 배우 모듈에 산다.
##
## 🔴 **레이어 계약: layer 2(player) / mask 1(world)**(player.tscn). 기본 레이어 1(world)로 되돌리면
## **쏘는 순간 진이 내 몸에 부딪혀 총구에서 죽는다**(캐리어 마스크가 5 = world+enemy). 에러도 경고도 없다.
## mask에 3(enemy)을 더하지도 마라 — 적이 나를 밀어내는 게임이 아니다.
##
## 🔴 그룹 `"player"` = **적이 나를 찾는 유일한 경로**다. 지우면 적이 제자리에 굳는데 에러는 안 난다.

const PlayerCaster := preload("res://src/actors/player_caster.gd")

@onready var caster: PlayerCaster = $Caster
@onready var sprite: AnimatedSprite2D = $Sprite

## 구르기 = 짧은 대시 + 그동안 무적. 적이 접촉 피해 전에 `is_rolling()`을 본다. 수치는 balance(dash_*).
## 🔴 **게이팅 지점은 이 상수 하나다** — 장비로 열 거면 여기를 장비 조회로 바꾼다.
## ⚠ 키 이름을 여기 베끼지 마라 — 정본은 `project.godot`의 `dash` 액션이다(주석이 두 번 늙었다).
const ROLL_ENABLED := true
var _face := Vector2.DOWN      ## 마지막으로 향한 방향 — 제자리에서 굴러도 이쪽으로 대시
var _roll_time := 0.0          ## 남은 구르기 시간(>0이면 구르는 중 = 무적)
var _roll_cd := 0.0            ## 다음 구르기까지 쿨다운
var _roll_dir := Vector2.DOWN  ## 이번 구르기의 대시 방향

## 외부 밀림 채널 — 감쇠 additive 모델이라 **밀리는 중에도 조작이 살아 있다**(경직이 아니다).
## PUSH_DECAY는 연출값(손맛) const다.
const PUSH_DECAY := 900.0      ## 밀림 감쇠(속도/s)
var _push := Vector2.ZERO      ## 남은 밀림 속도 — 걷기 velocity 위에 얹힌다

## 즉시 대입 대신 목표 속도로 move_toward해 스냅·무게감을 준다. 최종 velocity = _move_vel + _push.
var _move_vel := Vector2.ZERO

## 피격 표시 — 이동은 안 막는다(경직이 아니다). 🔴 복구 코드가 따로 없다: `_apply_anim`이 매 프레임
## 우선순위를 다시 계산하므로 타이머가 소진되면 자연 복귀한다. HURT_ANIM_SEC는 연출값 const.
const HURT_ANIM_SEC := 0.25    ## 피격 프레임 유지 시간(s)
var _hurt_time := 0.0

## 달리기 표시 — 전용 시트가 없어 `run` 애니의 **박자만** 올린다. 속도 자체는 balance가 쥔다.
const RUN_ANIM_SCALE := 1.5
## 좌우 반전 데드존 — 커서가 몸의 **바로 위/아래**에 있을 때 x가 0 근처에서 떨려
## 스프라이트가 파르르 뒤집히는 것을 막는다. (실측값이 아니라 떨림 방지용 여유)
const AIM_FLIP_DEADZONE := 0.15

## 밀쳐낸다 — 초기 속도 = sqrt(2·감쇠·거리)라 감쇠 적분 이동거리 ≈ dist(밀 거리는 호출자 .tres가 쥔다).
func apply_push(dir: Vector2, dist: float) -> void:
	_push = dir.normalized() * sqrt(2.0 * PUSH_DECAY * maxf(dist, 0.0))

func _ready() -> void:
	add_to_group("player")
	EventBus.player_hurt.connect(_on_hurt)


func _on_hurt(_amount: float, _source_pos: Vector2) -> void:
	_hurt_time = HURT_ANIM_SEC

## 🔴 구르는 중 = 무적. 적이 접촉 피해 전에 이것만 본다.
func is_rolling() -> bool:
	return _roll_time > 0.0


## 🔴🔴 **애니는 `idle`·`run`·`hurt` 셋뿐이고 방향 분기가 없다** — 그림 자체가 정면 한 종류라
## up/down 태그를 배선해도 같은 셀이 나온다. 좌우 방향감은 떠있는 지팡이의 조준 회전이 준다.
## 🔴 **애니를 정하는 자리는 이 함수 하나다**(우선순위 hurt > run > idle). 그전엔 방향·재생·피격을
##   셋이 매 프레임 같은 속성에 덮어써서 호출 순서만 바뀌어도 조용히 어긋났다.
## ⚠ 달리기는 `run` 애니의 `speed_scale`로만 갈린다 — 전용 시트를 그리면 애니 이름으로 갈라라.
func _apply_anim(moving: bool, running: bool = false) -> void:
	var want: StringName = &"hurt" if _hurt_time > 0.0 else (&"run" if moving else &"idle")
	if sprite.animation != want:
		sprite.animation = want
		sprite.frame = 0
	sprite.speed_scale = RUN_ANIM_SCALE if (running and want == &"run") else 1.0
	# 🔴 방향의 단일 소스는 `caster.aim()`이다 — 여기서 `get_global_mouse_position()`을 또 읽으면
	#   지팡이와 두 곳이 같은 것을 각자 계산한다. caster가 없으면 반전을 건드리지 않는다.
	if caster != null:
		var ax: float = caster.aim().x
		if absf(ax) > AIM_FLIP_DEADZONE:
			sprite.flip_h = ax < 0.0
	# 🔴 **늘 재생 상태로 둔다 — `idle`도 숨쉬는 애니다.** 멈춰 설 때 pause하면 「정지 = 완전 정지」가 돼
	#   몸이 뻣뻣해진다.
	if not sprite.is_playing():
		sprite.play()

## 🔴 속도 수치를 코드에 박지 마라 — balance가 쥔다.
## 🔴 UI 모달이 열리면 멎는다 — 안 그러면 창고를 보는 동안 뒤에서 계속 걸어간다.
func _physics_process(delta: float) -> void:
	# 🔴 피격 타이머 감쇠는 최상단 — 모달 early-return 안쪽에 두면 모달을 연 채 hurt가 영구히 굳는다.
	if _hurt_time > 0.0:
		_hurt_time -= delta

	if GameState.ui_modal_open:
		velocity = Vector2.ZERO
		_move_vel = Vector2.ZERO   # 모달을 닫을 때 잔여 속도로 미끄러지지 않게
		_apply_anim(false)
		return

	if _roll_cd > 0.0:
		_roll_cd -= delta

	# 구르는 중 — 입력 무시, 대시 방향으로 밀고 무적 유지(is_rolling()==true).
	if _roll_time > 0.0:
		_roll_time -= delta
		velocity = _roll_dir * GameState.balance.dash_speed
		move_and_slide()
		return

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		_face = dir

	# 구르기 시작 — 방향은 지금 누른 쪽, 없으면 마지막으로 향한 쪽.
	if ROLL_ENABLED and Input.is_action_just_pressed("dash") and _roll_cd <= 0.0:
		# 🔴 **구르기가 시전을 끊는다** — 안 막으면 "무적으로 굴러다니며 시전"이 최적해가 된다.
		# 🔴 **폴링이 아니라 여기서 알린다**: 캐스터가 `is_rolling()`을 폴링하면 한 프레임 늦어
		#   짧은 구르기를 통째로 놓친다. 판정 시점은 `_roll_time`이 0에서 올라가는 이 순간이다.
		if caster != null:
			caster.cancel_cast()
		_roll_dir = (dir if dir != Vector2.ZERO else _face).normalized()
		_roll_time = GameState.balance.dash_duration_sec
		_roll_cd = GameState.roll_cooldown()   # 🔴 부적(CHARM) 배수 반영
		_push = Vector2.ZERO   # 밀림을 흘린다 — 안 지우면 잔량이 구르기 끝에 도로 온다
		_hurt_time = 0.0       # 구르기가 피격 표시를 이긴다(조작감 우선)
		return

	# 🔴 달리기 = `dash`를 「계속」 누르고 있는 동안. 위 분기가 `just_pressed`라 첫 프레임엔 구르기가
	#   나가고 여기 도달하지 않는다 — 즉 **달리려면 늘 구르기가 한 번 선행**한다.
	#   ⚠ 홀드 판정 타이머를 넣지 마라 — 그만큼 구르기가 늦게 나가 피하려는 순간 몸이 안 움직인다.
	var running := ROLL_ENABLED and Input.is_action_pressed("dash")
	# 🔴 `GameState.move_speed()`/`run_speed()`를 거쳐라 — balance를 직접 참조하면 장비 배수가 조용히 빠진다.
	# 🔴 시전 감속을 곱하는 자리는 그 **결과**다 — 장비·달리기 배수가 실린 값 위에 얹어야
	#   장비 효과가 시전 중에만 조용히 사라지지 않는다.
	var speed := GameState.run_speed() if running else GameState.move_speed()
	if caster != null:
		speed *= caster.cast_move_mult()
	var target := dir * speed
	var rate := GameState.balance.player_accel if dir != Vector2.ZERO else GameState.balance.player_friction
	_move_vel = _move_vel.move_toward(target, rate * delta)
	# 밀림은 이동 위에 얹는다(additive) — 구르기 중엔 위 early-return이라 무시된다.
	velocity = _move_vel + _push
	_push = _push.move_toward(Vector2.ZERO, PUSH_DECAY * delta)
	# 애니는 실제 이동(_move_vel)에 맞춘다 — 입력을 떼도 미끄러지는 동안 발이 움직인다.
	# 🔴 `_hurt_time` 가드를 여기 두지 마라 — 우선순위는 `_apply_anim` 한 곳에 모여 있다.
	_apply_anim(_move_vel.length() > 8.0, running)
	move_and_slide()
