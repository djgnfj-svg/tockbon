extends CharacterBody2D
## 플레이어 — WASD 이동. 조준·발사·슬롯은 자식 `Caster`(player_caster.gd)가 쥔다.
##
## 🔴 **베이스캠프와 숲이 같은 몸을 쓴다** (세션 26). 세션 25까지 플레이어는 `base.tscn`에
## **인라인**이라 숲이 쓰려면 base를 preload해야 했고, 그건 모듈 간 직접 참조 금지 위반이었다.
## 그래서 `src/actors`(공용 배우 모듈)로 뺐다 — base도 field도 여기서 조립한다.
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
## `forest_enemy`가 접촉 피해 전에 `is_rolling()`을 보고 피해를 흘린다(무적 프레임). 튜토 방의
## "균열 넘기"도 같은 술어를 읽는다 (docs/ONBOARDING_FLOW.md 구간 A). 수치는 balance(dash_*).
var _face := Vector2.DOWN      ## 마지막으로 향한 방향 — 제자리에서 굴러도 이쪽으로 대시
var _roll_time := 0.0          ## 남은 구르기 시간(>0이면 구르는 중 = 무적)
var _roll_cd := 0.0            ## 다음 구르기까지 쿨다운
var _roll_dir := Vector2.DOWN  ## 이번 구르기의 대시 방향

func _ready() -> void:
	add_to_group("player")

## 🔴 구르는 중 = 무적. forest_enemy가 접촉 피해 전에 이것만 본다. 튜토 "균열 넘기"도 이걸 읽는다.
func is_rolling() -> bool:
	return _roll_time > 0.0

## 🔴 좌우 향함은 **마우스가 정한다** (세션43 — 조준하는 게임이라 몸이 커서를 본다).
## 이동·구르기와 무관하게 매 프레임: 커서가 오른쪽이면 right·왼쪽이면 left. 가만히 서서
## 커서만 옮겨도 홱 돈다. up/down 로우는 이제 안 쓴다(시트에 남아도 무해 — 뒷태 안 그리기).
func _face_mouse() -> void:
	var a: StringName = &"right" if get_global_mouse_position().x >= global_position.x else &"left"
	if sprite.animation != a:
		sprite.animation = a

## 걷기 재생/정지 — 걸을 때만 2프레임 까딱, 멈추면 첫 프레임(정지 포즈)으로.
func _set_walking(moving: bool) -> void:
	if moving:
		sprite.play()
	else:
		sprite.pause()
		sprite.frame = 0

## 🔴 속도는 balance가 쥔다 (수치를 코드에 박지 않는다 — TECH_SPEC §10).
## 🔴 UI 모달(창고 등)이 열리면 멎는다 — 안 그러면 창고를 보는 동안 뒤에서 계속 걸어간다.
func _physics_process(delta: float) -> void:
	if GameState.ui_modal_open:
		velocity = Vector2.ZERO
		_set_walking(false)
		return

	_face_mouse()   # 🔴 마우스 쪽 좌우 향함 — 이동·구르기와 무관하게 매 프레임

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
	if Input.is_action_just_pressed("dash") and _roll_cd <= 0.0:
		_roll_dir = (dir if dir != Vector2.ZERO else _face).normalized()
		_roll_time = GameState.balance.dash_duration_sec
		_roll_cd = GameState.roll_cooldown()   # 🔴 부적(CHARM) 배수 반영 (세션42)
		return

	# 🔴 속도 = GameState.move_speed()(balance × 모자 배수) — balance 직접 참조 금지 (세션42).
	velocity = dir * GameState.move_speed()
	_set_walking(dir != Vector2.ZERO)
	move_and_slide()
