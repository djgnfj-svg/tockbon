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

## 🔴 구르기(Shift = `dash` 액션) — 짧은 대시 + 그동안 무적 (세션41 온보딩).
## `forest_enemy`가 접촉 피해 전에 `is_rolling()`을 보고 피해를 흘린다(무적 프레임). 수치는 balance(dash_*).
## 🔴 세71f: **구르기 처음엔 없다**(사용자 확정) — 나중에 **장비 착용이 이동수단을 정하게** 할 예정이라
## 지금은 입력만 막는다. 기계(대시·무적·먼지 버스트·is_rolling)는 **전부 남겨** 그때 게이트만 켜면 된다.
## 게이팅 지점은 여기 하나(`_roll_enabled()`) — 나중에 이 함수를 장비 조회로 바꾼다.
const ROLL_ENABLED := false
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
func _apply_anim(moving: bool) -> void:
	var want: StringName = &"hurt" if _hurt_time > 0.0 else (&"run" if moving else &"idle")
	if sprite.animation != want:
		sprite.animation = want
		sprite.frame = 0
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
		_roll_dir = (dir if dir != Vector2.ZERO else _face).normalized()
		_roll_time = GameState.balance.dash_duration_sec
		_roll_cd = GameState.roll_cooldown()   # 🔴 부적(CHARM) 배수 반영 (세션42)
		_push = Vector2.ZERO   # 구르기로 밀림을 **흘린다** — 안 지우면 잔량이 구르기 끝에 도로 온다(세56 리뷰)
		_hurt_time = 0.0       # 구르기가 피격 표시를 이긴다 — 구르기 조작감 우선(세63 설계 §B)
		return

	# 🔴 이동 램프 — 목표 속도(입력 방향 × move_speed)로 move_toward. 즉시 대입이 아니라 가속/감속이라
	# 스냅·무게감이 생긴다 (세74). 🔴 속도 = GameState.move_speed()(balance × 모자 배수) — 직접 참조 금지(세42).
	var target := dir * GameState.move_speed()
	var rate := GameState.balance.player_accel if dir != Vector2.ZERO else GameState.balance.player_friction
	_move_vel = _move_vel.move_toward(target, rate * delta)
	# 밀림(_push)은 이동 위에 얹는다(additive) — 구르기 중엔 위 early-return이라 밀림 무시(흘린 게 맞다).
	velocity = _move_vel + _push
	_push = _push.move_toward(Vector2.ZERO, PUSH_DECAY * delta)
	# 애니는 실제 이동(_move_vel)에 맞춘다 — 입력을 떼도 감속하며 미끄러지는 동안 발이 움직인다.
	# 🔴 `_hurt_time` 가드를 **여기 두지 않는다** — 우선순위는 `_apply_anim` 안 한 곳으로 모았다.
	#   옛 코드는 가드가 이 자리에 있고 hurt 전환은 위쪽에 따로 있어서 **두 자리가 같은 규칙을 나눠 갖고** 있었다.
	_apply_anim(_move_vel.length() > 8.0)
	move_and_slide()
