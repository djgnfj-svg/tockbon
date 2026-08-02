extends Node2D
## 조준선 · **발사** · 슬롯 선택 — 마을과 보스방이 공유하는 **유일한 발사 경로**다.
## 🔴 발사는 반드시 `design.to_assembly()`로 — 직접 Dictionary를 만들면 `assembly.score`가 빠져
##   **손그림 점수가 조용히 사라지고 기준 위력으로 나간다.** 한 곳에 두면 그 함정도 한 곳뿐이다.
##
## ⏸ **지금 좌클릭 = 즉시 발사다.** 스위치는 코드가 아니라 `balance.cast_time_plain_sec`·
## `cast_time_perfect_sec` 둘이고, 0이라 시전 구간의 길이가 0이다 — 아래 ⏸ 표시가 붙은 기계
## (`_tick_cast`·홀드·불발·시전 중 차단·이동 감속·발밑 마법진)는 **죽은 게 아니라 안 불릴 뿐**이다.
## 🔴 **⏸ 주석을 지우지 마라 — 실측으로 산 규칙이라 값을 되돌리는 날 그대로 필요하다.**
##
## 플레이어의 자식으로 원점에 붙는다. 씬은 `notice`/`slot_changed`를 HUD에 잇고, 책이 펼쳐지면
## `enabled = false`로 멎힌다.

## 한 줄 안내문을 HUD로 — 🔴 **HUD를 직접 참조하지 않는다**(모듈 경계. 씬이 `hud.say`에 잇는다).
signal notice(text: String, warn: bool)
## 고른 슬롯이 바뀌었다 — HUD가 강조 칸을 옮긴다.
signal slot_changed(slot: int)

## 🔴 위력은 여기서 계산하지 않는다 — 리포트·발사·HUD가 **같은 함수**를 본다.
## ⚠ 마나만은 `GameState.cast_mana_cost()`를 거친다(장비 보정이 얹힌 값이라 직접 부르면 빼먹는다).
## 🔴🔴 **`balance`를 직접 lerp하지 마라** — 점수의 실사용 범위가 0.70~1.0(맨 진이 이미 0.70)이라
## 정규화가 이 함수들 **안에** 들어 있다. 그냥 보간하면 하위 70%가 통째로 죽는다.
const RingPower := preload("res://src/core/ring_power.gd")

## 조준선 길이·색 (연출값 — 밸런스 아님). 빈 슬롯은 흐리게 — "못 쏨"이 손끝에서 보인다.
const AIM_FROM := 14.0
const AIM_TO := 34.0
const AIM_ARMED := Color(0.95, 0.65, 0.25, 0.85)
const AIM_EMPTY := Color(0.75, 0.72, 0.65, 0.30)

## false면 조준·발사·슬롯이 전부 멎는다 (책이 펼쳐진 동안).
var enabled: bool = true:
	set(value):
		enabled = value
		queue_redraw()

var _aim := Vector2.RIGHT
var _slot: int = 0
## 떠있는 지팡이(형제) — 지연 조회라 노드 준비 순서를 안 탄다. 없거나 숨었으면 몸 중심으로 폴백.
var _wand: Node2D = null

# ── 시전 ───────────────────────────────────────────────────────────────────────
## 가드 → 마나 차감 → `ring_cast_started`(발밑이 열린다) → ⏸duration → `ring_cast_requested`(탄).
##
## 🔴🔴 **`SceneTreeTimer`가 아니라 `_process` 카운트다운인 게 계약이다** — 시전 상태가 이 노드에
## 살아 있어 씬이 바뀌면(귀환·사망) 노드와 함께 죽는다 = **없는 씬에 쏘는 일이 구조적으로 불가능**.
## ⚠ 그래서 `_exit_tree` 취소 훅도 달지 않는다 — 리페어런팅에도 도는 훅은 없던 문제를 만든다.
##
## 🔴🔴 **「시전 중」의 단일 소스는 `_cast_left`가 아니라 이 플래그다.** 다 차고 안 뗀 홀드 구간도
## 시전 중이라, `_cast_left > 0.0`으로 재면 연사·슬롯 전환 차단과 이동 감속이 **다 차는 순간
## 통째로 풀려** 열린 원 위로 두 번째 시전이 겹친다(에러 0).
var _casting: bool = false
## 남은 **채우는** 시간(0 = 다 찼다). 홀드 구간에도 0으로 앉아 있다.
var _cast_left: float = 0.0
## 🔴 좌클릭을 뗐나 (latch — 한 번 참이 되면 다시 눌러도 안 돌아온다).
## ⚠ 프로그램에서 `fire()`를 부르면 버튼이 안 눌려 있어 첫 프레임에 참이 된다.
var _cast_released: bool = false
## 🔴 시작 시점 **스냅샷** — `to_assembly()`는 시전 한 번에 한 번만 부른다. emit 시점에 다시 읽으면
## 시전 중 슬롯을 바꿨을 때 **그린 것 ≠ 나가는 것**이 된다(에러 0). 그래서 슬롯 전환도 막는다.
var _cast_assembly: Dictionary = {}
## 발밑 원을 여는 자리(시작 시점 고정). 🔴 탄이 나가는 자리는 `_release_cast`가 다시 본다.
var _cast_origin := Vector2.ZERO
## 🔴 실제 버튼 눌림으로 시작됐나 (false = 프로그램 호출 → 홀드 없음. `_tick_cast` 참조).
var _cast_by_input := false
## 시전 중 이동 배수 — 시작할 때 점수로 한 번 정한다. `player`가 읽는다.
var _cast_move_mult: float = 1.0


## 씬·테스트가 읽는 공개 API.
func slot() -> int:
	return _slot


func aim() -> Vector2:
	return _aim


## 발사·슬롯 전환 차단과 이동 감속이 이 술어 하나를 본다.
## 🔴 **채우는 중 + 홀드 중을 둘 다 포함한다** — 홀드에서 풀리면 원이 겹친다.
func is_casting() -> bool:
	return _casting


## 다 차 놓고 손을 안 뗀 홀드 구간인가 — 그물이 「홀드에 들어간 것 자체」를 이걸로 확인한다
## (없으면 「발사 0회」가 *"시전이 애초에 안 걸렸다"*와 구분이 안 돼 자명 통과한다).
## ⏸ 🔴 **지금은 항상 false다** — 「뭔가 도는 중」의 신호로 쓰면 조용히 죽는다.
func is_holding() -> bool:
	return _casting and _cast_left <= 0.0


## 🔴 시전 중 이동 배수(1.0 = 평소). `player`가 `GameState.move_speed()`/`run_speed()`의 **결과에**
## 곱한다 — 장비·달리기 배수가 실린 값 위에 얹혀야 장비 효과가 시전 중에만 조용히 사라지지 않는다.
## ⏸ 지금은 항상 1.0이다(`balance.cast_move_mult_*`은 일부러 남겨 뒀다).
func cast_move_mult() -> float:
	return _cast_move_mult if is_casting() else 1.0


## 🔴 시전을 끊는다 — **마나는 안 돌려준다**(돌려주면 "모달 열었다 닫아 마나 아끼기"가 생긴다).
## 🔴 `ring_cast_canceled`를 반드시 쏜다 — 안 쏘면 **발밑 원만 남아** "쐈는데 안 나갔다"가 된다.
## 반환 = 실제로 끊었나. ⏸ 지금은 늘 false다(끊을 시전이 없다).
func cancel_cast() -> bool:
	if not is_casting():
		return false
	_clear_cast()
	EventBus.ring_cast_canceled.emit()
	return true


func _process(delta: float) -> void:
	# 🔴 시전 진행은 **아래 early-return보다 먼저** 본다 — 모달이 열리면 「멎는」 게 아니라 **취소**다.
	# `enabled=false`·`ui_modal_open`은 입력만 막지 지연 emit은 안 막아서, 시전 뒤 책상 [E]를 누르면
	# 펼쳐진 책 위로 마법이 날아간다.
	if is_casting():
		if not enabled or GameState.ui_modal_open:
			cancel_cast()
		else:
			_tick_cast(delta)
	if not enabled or GameState.ui_modal_open:
		return
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length_squared() > 1.0:
		_aim = to_mouse.normalized()
	queue_redraw()


## 시전 진행 — 채우기 → 홀드 → 발사. ⏸ 지금은 한 번도 안 불린다.
##
## 🔴🔴 **뗐는지는 폴링으로 본다 — released 이벤트가 아니다.** 이벤트로 받으면 **영원히 홀드에
## 갇히는 길이 셋**이고 전부 에러가 0이다(마법이 영영 안 나가고 이동만 무거워진다):
##   ① 화면을 덮는 Control이 `mouse_filter=STOP`이면 뗀 이벤트를 먹는다(누른 건 이미 닿았어도)
##   ② 창 포커스가 빠지면 엔진이 **액션만 풀고 이벤트는 안 쏜다** — alt-tab 한 번에 갇힌다
##   ③ `_unhandled_input`은 UI가 먼저 먹은 뒤에만 오고, 모달 중엔 아예 안 온다
## 폴링은 셋을 한 자리에서 닫는다(늦어야 한 프레임). ⚠ 다른 곳에 「뗌」 판정을 또 만들지 마라.
func _tick_cast(delta: float) -> void:
	if not _cast_released and not Input.is_action_pressed(&"attack_basic"):
		_cast_released = true
	if _cast_left > 0.0:
		_cast_left = maxf(_cast_left - delta, 0.0)
	# 🔴 다 찼는데 쥐고 있으면 **열린 채 머문다** — 자동 발사가 없다. 여기에 "오래 들면 세진다"를
	#   얹지 마라(조립과 경쟁하는 새 위력 축이 생긴다). 홀드는 **타이밍만** 판다.
	# 🔴🔴 **뗄 손이 없는 시전은 홀드 규칙에서 뺀다** — 프로그램 호출(그물)은 버튼이 안 눌려 있어
	#   첫 프레임에 「뗐다」로 잡히고, 그대로 두면 아래 불발 규칙에 걸려 **모든 프로그램 호출이
	#   불발**이 된다(이 분기가 없으면 그물 3건이 즉시 빨개진다).
	# ⚠ 라이브는 이 분기를 절대 안 탄다 — `fire()`는 눌림 안에서만 불린다.
	if not _cast_by_input:
		if _cast_left <= 0.0:
			_release_cast()
		return
	if not _cast_released:
		return
	# 🔴 덜 찼는데 뗐으면 불발이다 — 마나는 태운다. 「일찍 떼도 다 차면 자동 발사」는 톡 눌러도
	#   차징이 알아서 굴러가 *"꾹 누르고 있다"*는 감각을 죽여서 각하됐다.
	# ⚠ 취소와 **같은 문**으로 보낸다 — 연출·마나 규칙이 구르기 취소와 같아야 한 그림으로 읽힌다.
	if _cast_left > 0.0:
		cancel_cast()
		return
	_release_cast()


## 🔴 발사는 **좌클릭만**이다. Space는 발사가 아니고, 다른 용도로 임의 배정하지도 마라.
##
## 🔴🔴 **즉발인 지금 아래 early-return이 모달·책 가드의 「유일한」 자리다.**
## ⚠ **그래서 `fire()`를 직접 부르는 그물은 이 가드를 통째로 우회한다** — 실제로 그 형태로
##   *"모달인데 탄이 나갔다"* 빨강이 났는데 게임은 멀쩡했다(그물이 거짓말했다).
## 🔴 모달·`enabled` 계약을 재려면 `root.push_input(InputEventMouseButton)`으로 진짜 좌클릭을 밀어라.
func _unhandled_input(event: InputEvent) -> void:
	if not enabled or GameState.ui_modal_open:
		return
	for i in GameState.EQUIP_SLOTS:
		if event.is_action_pressed(StringName("cast_slot_%d" % (i + 1))):
			select_slot(i)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"attack_basic"):
		fire()
		get_viewport().set_input_as_handled()


func select_slot(slot: int) -> void:
	# 🔴 시전 중 슬롯 전환 차단 — 나가는 건 시작 시점 스냅샷이라, 강조 칸만 옮기면 HUD가 가리키는
	# 진과 실제로 나가는 마법이 **에러 없이 갈라진다**. ⏸ 지금은 늘 통과한다.
	if is_casting():
		return
	_slot = slot
	# 🔴 여기서 notice를 쏘지 마라 — HUD가 선택 슬롯을 상시 한 줄로 그려서 같은 문구가 두 줄로 겹친다.
	slot_changed.emit(slot)
	queue_redraw()


## 🔴 순서가 곧 계약이다 — **가드가 ③보다 먼저**여야 빈 슬롯·마나 부족에 발밑이 열리지 않는다:
##   ① 빈 슬롯 거부 → ② 마나 차감 → ③ 스냅샷 + `ring_cast_started`
##   → ⏸ 채우기 → ⏸ 홀드(`_tick_cast`) → ④ `ring_cast_requested`
## 🔴 ⏸ 두 단계가 길이 0이라 ③과 ④가 이 함수 안에서 연달아 난다(맨 아래 분기).
##   ⇒ **`fire()`가 돌아왔을 때 탄은 이미 나가 있다.** 「나중에 나간다」를 전제로 짜지 마라.
func fire() -> void:
	# 🔴 연사 차단 — 없으면 바닥 마법진이 겹겹이 쌓이고 마나가 연타로 녹는다.
	# ⚠ **조용히 거부해도 되는 유일한 자리다**: 이미 열린 발밑 마법진이 이유를 화면에 말하고 있다
	#   (안내를 띄우면 연타마다 도배된다).
	if is_casting():
		return
	# 🔴 빈 슬롯 거부는 마나 판정보다 먼저 — 거부에 마나를 태우지 않는다.
	# ⚠ 조용히 거부하지 마라 — 안내가 없으면 "장착했는데 안 나간다"가 된다.
	var design: RingDesign = GameState.ring_equipped[_slot]
	if design == null:
		notice.emit("장착된 진이 없다 — 책상(E)에서 맺어 장착해라", true)
		return
	# 🔴 수치를 여기 박지 말고 `GameState.cast_mana_cost()`를 불러라 — 지팡이 배수가 얹힌 값이라
	#   HUD 마나 막대와 같은 함수를 봐야 「부족」 경계와 실제 소모가 안 갈라진다.
	# ⚠ debug_free_cast는 에디터 실행 전용 — 익스포트에선 항상 false.
	# 🔴 마나는 **시전 시작**에 나간다 — 취소돼도 안 돌아온다.
	if not GameState.debug_free_cast and not GameState.spend_mana(GameState.cast_mana_cost()):
		notice.emit("마나가 부족하다 — 잠시 기다려라", true)
		return
	# ③ 여기서부터가 시전이다. `to_assembly()`는 이 줄에서 **한 번만** 불린다.
	_cast_assembly = design.to_assembly()
	# 🔴 발밑 원을 여는 자리라 시작 시점을 얼린다 — 탄이 나가는 자리는 `_release_cast`가 다시 본다.
	_cast_origin = _muzzle()
	var score := float(_cast_assembly.get("score", 0.0))
	_cast_move_mult = RingPower.cast_move_mult_of(score)
	var duration := maxf(RingPower.cast_time_of(score), 0.0)
	_cast_left = duration
	# 🔴 「뗐나」는 여기서 읽지 않는다 — 첫 `_tick_cast`가 폴링으로 정한다(두 곳이 정하면 갈라진다).
	_cast_released = false
	# 🔴 실제 버튼 눌림으로 시작됐나 — 여기서만 정한다. 프로그램 호출이면 false라 홀드가 없다.
	_cast_by_input = Input.is_action_pressed(&"attack_basic")
	_casting = true
	EventBus.ring_cast_started.emit(_cast_assembly, _cast_origin, duration)
	# 🔴 duration 0(= 지금)이면 그 자리에서 발사한다 — 즉발엔 홀드가 없다.
	# ⚠ `vfx._on_ring_cast_started`도 같은 값을 본다 — duration 0이면 발밑 원을 안 연다.
	if duration <= 0.0:
		_release_cast()


## ④ 쏜다. 🔴 **무엇을 얼리고 무엇을 다시 보는지가 갈린다**:
##   • `assembly`는 시작 시점 스냅샷이다 — 아니면 홀드 중 슬롯을 바꿨을 때 그린 것 ≠ 나가는 것.
##   • 🔴 **`origin`·`aim`은 반대로 「지금」을 다시 본다.** 셋을 다 얼렸더니 시전 동안 걸어간 만큼
##     **탄이 몸 뒤에서 날아왔다** — F5로 각하된 자리라 되돌리지 마라.
## ⚠ 발신 전에 상태를 먼저 지운다 — 수신자가 그 안에서 다시 `fire()`를 불러도 얽히지 않게.
## ⚠ 그래서 「started.origin == requested.origin」은 차징이 살아 있는 동안은 계약이 아니다
##   (총구 단일 소스는 양쪽 다 `_muzzle()`을 거치는 것으로 지켜진다).
func _release_cast() -> void:
	var assembly := _cast_assembly
	var origin := _muzzle()
	var aim := _aim
	_clear_cast()
	EventBus.ring_cast_requested.emit(assembly, origin, aim)


## 시전 상태 초기화 — **시그널을 쏘지 않는다**(취소는 `cancel_cast`, 완료는 `_release_cast`가 쏜다).
func _clear_cast() -> void:
	_casting = false
	_cast_left = 0.0
	_cast_released = false
	_cast_assembly = {}
	_cast_move_mult = 1.0


## 🔴 발사 원점 = 지팡이 끝. **총구 단일 소스는 `floating_wand.muzzle_position()`이니 기하를 여기
## 복제하지 마라.** 지팡이가 없거나 숨었으면 몸 중심으로 폴백한다(맨손 캐스팅).
func _muzzle() -> Vector2:
	if _wand == null:
		_wand = get_parent().get_node_or_null("FloatingWand")
	if _wand and _wand.visible:
		return _wand.muzzle_position()
	return global_position


## 조준선 — 장착됐으면 불빛, 빈 슬롯이면 흐리게. 쏘기 전에 슬롯 상태가 손끝에서 보인다.
func _draw() -> void:
	if not enabled:
		return
	var armed := GameState.ring_equipped[_slot] != null
	draw_line(_aim * AIM_FROM, _aim * AIM_TO, AIM_ARMED if armed else AIM_EMPTY, 2.0)
