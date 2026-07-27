extends CharacterBody2D
## 플레이어 — WASD 이동. 조준·발사·슬롯은 자식 `Caster`(player_caster.gd)가 쥔다.
##
## 🔴 **마을(base)과 보스방이 같은 몸을 쓴다** (세션 26에 공용화 — `player.tscn`을 무는 씬은
## `base.tscn`·`boss_room.tscn` 둘뿐이다. 옛 숲 씬은 세58-B 은퇴). 세션 25까지 플레이어는
## `base.tscn`에 **인라인**이라 다른 무대가 쓰려면 base를 preload해야 했고, 그건 모듈 간 직접
## 참조 금지 위반이었다. 그래서 `src/actors`(공용 배우 모듈)로 뺐다 — base도 field도 여기서 조립한다.
##
## 🔴 **레이어 계약을 지켜라: layer 2(player) / mask 1(world)** (player.tscn).
## 기본 레이어 1(world)로 되돌리면 **쏘는 순간 진이 내 몸에 부딪혀 총구에서 죽는다** —
## 캐리어 마스크가 5(world+enemy)이기 때문이다. **에러도 경고도 없다** (세션 24에 실제로 겪었다).
## mask에 3(enemy)을 더하지도 마라: 적이 나를 밀어내는 게임이 아니다.
##
## 🔴 그룹 `"player"` = **적이 나를 찾는 유일한 경로**다 (forest_enemy가 이 그룹으로 조준한다).
## 지우면 적이 제자리에 굳는데 에러는 안 난다.

const PlayerCaster := preload("res://src/actors/player_caster.gd")

@onready var caster: PlayerCaster = $Caster
@onready var sprite: AnimatedSprite2D = $Sprite

## 🔴 구르기(**스페이스** = `dash` 액션) — 짧은 대시 + 그동안 무적 (세션41 온보딩).
## `forest_enemy`가 접촉 피해 전에 `is_rolling()`을 보고 피해를 흘린다(무적 프레임). 수치는 balance(dash_*).
##
## 🔴🔴 **세97: 다시 켰다**(사용자 요청 — *"스페이스바 구르기 + 꾹 누르면 런"*).
##   ⚠ 세71f에 **사용자 확정으로 껐던** 것이다(*"구르기 처음엔 없다 — 나중에 장비 착용이 이동수단을
##   정하게"*). 그 계획을 되살릴 거면 이 상수를 **장비 조회로 바꾸면** 된다 — 게이팅 지점은 여기 하나다.
## ⚠ 주석이 오래 *"Shift"*라고 말했는데 실제 액션은 **Ctrl**에 잡혀 있었다(세97에 스페이스로 옮겼다).
##   키 이름을 여기 베끼지 말고 `project.godot`의 `dash` 액션을 봐라 — 이 줄이 또 늙는다.
const ROLL_ENABLED := true
var _face := Vector2.DOWN      ## 마지막으로 향한 방향 — 제자리에서 굴러도 이쪽으로 대시
var _roll_time := 0.0          ## 남은 구르기 시간(>0이면 구르는 중 = 무적)
var _roll_cd := 0.0            ## 다음 구르기까지 쿨다운
var _roll_dir := Vector2.DOWN  ## 이번 구르기의 대시 방향

## 🔴 외부 밀림 채널 (세56 — gale 돌풍이 첫 호출자). 적 `_knockback`과 같은 감쇠 additive 모델이라
## **밀리는 중에도 조작이 살아 있다**(경직 아님). 호출자가 없으면 no-op — 공용 배우 최소 침습.
## PUSH_DECAY는 연출값(손맛) const다 (forest_enemy KNOCKBACK_DECAY 선례 — 밸런스 아님).
const PUSH_DECAY := 900.0      ## 밀림 감쇠(속도/s)
var _push := Vector2.ZERO      ## 남은 밀림 속도 — 걷기 velocity 위에 얹힌다

## 🔴 이동 속도 램프 (세74 이동 필) — 즉시 대입 대신 목표 속도로 move_toward해 스냅·무게감을 준다.
## 입력 있음 → balance.player_accel로 가속 · 입력 없음 → player_friction으로 감속. 최종 velocity =
## _move_vel + _push(밀림 additive 계약 보존). 구르기 중엔 물리 process가 early-return이라 무관(걷기 전용).
var _move_vel := Vector2.ZERO  ## 입력 구동 속도(밀림 제외) — 램프의 대상

## 🔴 피격 애니 (세63) — `EventBus.player_hurt`(발신 = `GameState.damage_player` 한 곳)를 받아
## HURT_ANIM_SEC 동안 hurt 프레임을 유지한다. 이동은 안 막는다(경직 아님 — apply_push additive 철학).
## 복구 코드는 없다: `_apply_anim`이 매 프레임 우선순위를 다시 계산하므로 타이머가 소진되면 자연 복귀한다
## (⚠ 세90까지 이 주석은 *"`_face_mouse`가 덮는 성질을 역이용"*이라고 적혀 있었다 — 그 함수는 이제 없다.
##  복구가 **우선순위 한 곳**에서 나온다는 게 지금의 계약이다).
## HURT_ANIM_SEC는 연출값(손맛) const다 (PUSH_DECAY 선례 — 밸런스 아님).
const HURT_ANIM_SEC := 0.25    ## 피격 프레임 유지 시간(s)
var _hurt_time := 0.0          ## 남은 피격 표시 시간(>0이면 hurt 애니 유지)

## 🔴 달리기 표시 (세97) — 전용 시트가 없어 `run` 애니의 **박자만** 올린다(`_apply_anim` 머리말).
## 연출값(손맛) const다 — 속도 자체는 balance가 쥔다(`player_run_mult`).
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

## 🔴 구르는 중 = 무적. forest_enemy가 접촉 피해 전에 이것만 본다. 튜토 "균열 넘기"도 이걸 읽는다.
func is_rolling() -> bool:
	return _roll_time > 0.0

## 🔴🔴 **세90: 애니 = `idle` · `run` · `hurt` 셋이고 방향 분기가 없다.**
##
## 옛 `left`/`right`는 **완전히 같은 그림이었다** — 세90 실측으로 두 셀의 픽셀 차이가 **0**이었다.
## penzilla 원본 시트(`assets/_source/penzilla_hooded/`)가 **정면뿐**이라 세76의 「런타임 2방향」이
## 그림에는 처음부터 없었다(코드만 방향을 갈랐다 = 감사 T8의 거울: 표시부가 아니라 **데이터가** 뒤처졌다).
## 좌우 방향감은 떠있는 지팡이(`floating_wand`)의 조준 회전이 준다.
## ⚠ 측면 스프라이트를 그리게 되면 여기서 방향을 되살린다(옛 `_face_mouse` = git 이력 세89 이전).
##
## 🔴 **애니를 정하는 자리를 한 곳으로 모았다.** 그전엔 `_face_mouse`(방향) · `_set_walking`(play/pause) ·
## `_hold_hurt_anim`(피격) **셋이 매 프레임 같은 속성을 덮어썼고**, hurt 복구를 *"`_face_mouse`가 매
## 프레임 animation을 덮는 성질을 역이용"*한다고 주석에 적어 뒀다 — 셋 중 하나의 호출 순서만 바뀌어도
## 조용히 어긋나는 구조였다. 우선순위(hurt > run > idle)는 이제 이 함수 안에만 있다.
## 🔴 세97: `running`이 붙었다 — **애니는 여전히 `run` 하나**고 `speed_scale`로만 갈린다.
##   측면·달리기 전용 시트가 없어서인데, 발 박자가 빨라지는 것만으로 「지금 달리는 중」이 읽힌다
##   (ART_SPEC §8-2 *"박자는 크기가 아니라 어떻게 움직이는가에서 나온다"*의 같은 원리).
##   ⚠ 달리기 시트를 그리게 되면 여기서 `&"run_fast"` 같은 이름으로 갈라라 — `speed_scale`은 되돌린다.
func _apply_anim(moving: bool, running: bool = false) -> void:
	var want: StringName = &"hurt" if _hurt_time > 0.0 else (&"run" if moving else &"idle")
	if sprite.animation != want:
		sprite.animation = want
		sprite.frame = 0
	sprite.speed_scale = RUN_ANIM_SCALE if (running and want == &"run") else 1.0
	# 🔴 좌우 반전 = **커서 쪽을 본다** (세97). 방향의 단일 소스는 `caster.aim()`이다 —
	#   `get_global_mouse_position()`을 여기서 또 읽으면 지팡이(`floating_wand._aim`)와 **두 곳이
	#   같은 것을 각자 계산**하게 된다(감사 T5). caster가 없으면(테스트 등) 반전을 건드리지 않는다.
	# ⚠ 지금 시트는 **정면 한 종류**라 효과가 약하다 — 측면 스프라이트가 생기면 여기서 방향 애니로 올린다
	#   (세90이 방향 분기를 걷은 이유가 「두 셀의 픽셀 차이가 0」이었다).
	if caster != null:
		var ax: float = caster.aim().x
		if absf(ax) > AIM_FLIP_DEADZONE:
			sprite.flip_h = ax < 0.0
	# 🔴 **늘 재생 상태로 둔다 — `idle`도 숨쉬는 애니다.** 옛 코드는 멈춰 서면 `pause()` + `frame = 0`으로
	#   굳혀서 「정지 = 완전 정지」였고, 그게 뻣뻣함의 절반이었다. 나머지 절반은 **걷기 칸에 원본 idle
	#   두 장이 들어 있던 것**이다(세90 실측) — 즉 걸을 때도 서 있을 때도 같은 그림이 나왔다.
	if not sprite.is_playing():
		sprite.play()

## 🔴 속도는 balance가 쥔다 (수치를 코드에 박지 않는다 — data/balance.tres가 정본).
## 🔴 UI 모달(창고 등)이 열리면 멎는다 — 안 그러면 창고를 보는 동안 뒤에서 계속 걸어간다.
func _physics_process(delta: float) -> void:
	# 🔴 피격 타이머 감쇠는 최상단 — 모달 early-return 안쪽에 두면 창고를 연 채로 hurt가 영구히 굳는다.
	if _hurt_time > 0.0:
		_hurt_time -= delta

	if GameState.ui_modal_open:
		velocity = Vector2.ZERO
		_move_vel = Vector2.ZERO   # 램프도 리셋 — 모달 닫을 때 잔여 속도로 미끄러지지 않게
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

	# 구르기 시작(Shift) — 방향은 지금 누른 쪽, 없으면 마지막으로 향한 쪽.
	# 🔴 세71f: ROLL_ENABLED=false면 Shift 무시(구르기 제거) — 나중에 장비 게이트로 켠다.
	if ROLL_ENABLED and Input.is_action_just_pressed("dash") and _roll_cd <= 0.0:
		# 🔴🔴 **구르기가 시전을 끊는다** (세98 확정 ⑥ — 마나는 태운다). 안 막으면 *"무적으로
		#   굴러다니며 퍼펙트 시전"*이 최적해가 돼 확정 ⑤(시전 중 감속 = 위험)가 통째로 무효가 된다.
		# 🔴 **폴링이 아니라 여기서 알린다**: 캐스터가 매 프레임 `is_rolling()`을 보면 한 프레임 늦고
		#   짧은 구르기를 통째로 놓친다. 판정 시점은 `_roll_time`이 0에서 올라가는 **이 순간**이다
		#   (구르기 뒤 손을 안 떼면 달리기로 이어지지만 그건 이미 끊긴 뒤라 무관하다).
		# ⚠ 둘 다 `player.tscn` 안이라 형제 참조로 닫힌다 — EventBus 신설 불필요.
		if caster != null:
			caster.cancel_cast()
		_roll_dir = (dir if dir != Vector2.ZERO else _face).normalized()
		_roll_time = GameState.balance.dash_duration_sec
		_roll_cd = GameState.roll_cooldown()   # 🔴 부적(CHARM) 배수 반영 (세션42)
		_push = Vector2.ZERO   # 구르기로 밀림을 **흘린다** — 안 지우면 잔량이 구르기 끝에 도로 온다(세56 리뷰)
		_hurt_time = 0.0       # 구르기가 피격 표시를 이긴다 — 구르기 조작감 우선(세63 설계 §B)
		return

	# 🔴🔴 **달리기 = 스페이스를 「계속」 누르고 있는 동안** (세97 · 사용자 확정 = 즉발 구르기 후 홀드).
	#   위 구르기 분기가 `just_pressed`라 **누른 첫 프레임엔 구르기가 나가고 여기 도달하지 않는다** —
	#   구르기가 끝나면(무적 종료) 손을 안 뗐을 때 그대로 달리기로 이어진다.
	#   🔴 **홀드 판정 타이머를 넣지 않은 이유**: 그러면 구르기가 그만큼 늦게 나가 피하려는 순간에
	#   몸이 안 움직인다(사용자가 「즉발」을 골랐다). 대신 **달리려면 늘 구르기가 한 번 선행**한다.
	# ⚠ 제자리에선 달려도 의미가 없다 — 목표 속도가 `dir`(0)에 곱해지므로 자동으로 무해하다.
	var running := ROLL_ENABLED and Input.is_action_pressed("dash")
	# 🔴 이동 램프 — 목표 속도(입력 방향 × move_speed)로 move_toward. 즉시 대입이 아니라 가속/감속이라
	# 스냅·무게감이 생긴다 (세74). 🔴 속도 = GameState.move_speed()/run_speed()(balance × 모자 배수)
	# — balance를 직접 참조하지 마라(세42: 그러면 장비 배수가 조용히 빠진다).
	# 🔴 시전 중 감속 (세98 확정 ⑤) — **등급이 무게를 판다**: 공들인 마법진일수록 오래·무겁게 서 있다
	#   = 그게 위험이고, 강한 마법진이 「난사용」이 아니라 「한 방」인 이유다.
	# 🔴 곱하는 자리는 `move_speed()`/`run_speed()`의 **결과**다 — 모자(HAT)·달리기 배수가 이미 실린
	#   값 위에 얹어야 장비 효과가 **시전 중에만 조용히 사라지지** 않는다(세42 선례). 배수의 단일
	#   소스는 `RingPower.cast_move_mult_of`이고 캐스터가 시전 시작에 한 번 정해 들고 있다.
	var speed := GameState.run_speed() if running else GameState.move_speed()
	if caster != null:
		speed *= caster.cast_move_mult()
	var target := dir * speed
	var rate := GameState.balance.player_accel if dir != Vector2.ZERO else GameState.balance.player_friction
	_move_vel = _move_vel.move_toward(target, rate * delta)
	# 밀림(_push)은 이동 위에 얹는다(additive) — 구르기 중엔 위 early-return이라 밀림 무시(흘린 게 맞다).
	velocity = _move_vel + _push
	_push = _push.move_toward(Vector2.ZERO, PUSH_DECAY * delta)
	# 애니는 실제 이동(_move_vel)에 맞춘다 — 입력을 떼도 감속하며 미끄러지는 동안 발이 움직인다.
	# 🔴 `_hurt_time` 가드를 **여기 두지 않는다** — 우선순위는 `_apply_anim` 안 한 곳으로 모았다.
	#   옛 코드는 가드가 이 자리에 있고 hurt 전환은 위쪽에 따로 있어서 **두 자리가 같은 규칙을 나눠 갖고** 있었다.
	_apply_anim(_move_vel.length() > 8.0, running)
	move_and_slide()
