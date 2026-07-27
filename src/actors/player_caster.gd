extends Node2D
## 조준선 · **시전** · 슬롯 선택 — **마을(base)과 보스방이 공유한다** (백로그 R4. 옛 숲 씬은 세58-B 은퇴).
##
## 🔴 **세98: 좌클릭이 곧 발사가 아니다.** 마나를 물고 `ring_cast_started`를 쏜 뒤 등급이 정한
## `duration`초 동안 발밑에 마법진이 열린다(그건 vfx 몫). 🔴🔴 **다 차도 자동으로 안 나간다 —
## 좌클릭을 「떼면」 나간다**(확정 ⑦, F5가 만든 자리: *"타이머가 쥔 게 아니라 내가 쥔다"*).
## 구간이 둘이다: **채우기**(`_cast_left > 0`) → **홀드**(다 찼는데 아직 쥐고 있다) → 발사.
## 🔴🔴 **홀드 시간은 위력에 1도 안 실린다** — 오래 들면 세지는 순간 *"대충 조립하고 오래 누르기"*가
##   최적해가 돼 이 설계 전체(**조립이 화면과 위력을 판다**)가 무너진다. 각하된 대안이 정확히 그것이다.
## ⚠ 일찍 떼면 **다 차는 즉시** 나간다(최소 시전 시간은 보장 — 확정 ④가 사는 자리).
## 상태기계는 아래 `_cast_*` 필드 + `fire`/`_tick_cast`/`_release_cast`/`cancel_cast`가 전부다.
##
## 🔴 왜 뽑았나: 세션 25까지 이 로직은 `base.gd` 안에 있었다. 다른 무대가 생기면 그대로 복사됐을 텐데,
## 복사본에는 **`to_assembly()`를 빼먹는 함정이 같이 복사된다** — 직접 Dictionary를 만들면
## `assembly.score`가 빠져 **손그림 점수가 조용히 사라지고 기준 위력으로 나간다**
## (ring_design.gd 주석). 한 곳에 두면 함정도 한 곳뿐이다.
##
## 플레이어의 **자식으로 원점에 붙는다** — 그래서 `global_position`이 곧 총구다.
## 씬은 이 노드를 두 갈래로만 쓴다: `notice`/`slot_changed`를 HUD에 잇고, 책이 펼쳐지면 `enabled = false`.

## 한 줄 안내문을 HUD로 — **HUD를 직접 참조하지 않는다**(씬이 이 시그널을 `hud.say`에 잇는다).
## ⚠ 옛 이유("베이스와 숲의 HUD가 다르다")는 낡았다: 세64부터 씬별 HUD 차이가 0이다(`hud.gd` 머리말).
## 그래도 시그널을 유지하는 진짜 이유는 **모듈 경계**다 — actors가 hud를 직접 물면 안 된다.
signal notice(text: String, warn: bool)
## 고른 슬롯이 바뀌었다 — HUD가 강조 칸을 옮긴다.
signal slot_changed(slot: int)

## 🔴 위력·마나 비용은 여기서 계산하지 않는다 — 리포트·발사·HUD가 **같은 함수**를 본다.
## 마나는 `GameState.cast_mana_cost()`(= `RingPower` 기본값 × 장비 보정)를 부른다 — 세85에
## `RingPower`를 직접 preload하던 줄을 걷었다(중간 참조가 남으면 장비 보정을 빼먹기 쉽다).
##
## 🔴 **시전 시간·감속은 그 은퇴의 예외다**(세98). 마나와 달리 **장비 보정 축이 없어서** GameState를
## 거칠 이유가 없다 — 세85가 걷은 건 「장비 배수를 빼먹는 중간 참조」이지 core 참조 자체가 아니다.
## 🔴🔴 **`balance`를 직접 lerp하지 마라** — 점수의 실사용 범위가 0.70~1.0(맨 진이 이미 0.70)이라
## 정규화(`quality_t`)가 이 함수들 **안에** 들어 있다. 그냥 보간하면 하위 70%가 통째로 죽는다.
const RingPower := preload("res://src/core/ring_power.gd")

## 조준선 길이·색 (연출값 — 밸런스 아님). 빈 슬롯은 흐리게 — "못 쏨"이 손끝에서 보인다 (세션59
## 매직볼 은퇴 후 이 흐림이 다시 **참 신호**다).
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
## 🔴 떠있는 지팡이(형제 노드) — 발사 총구가 지팡이 끝이 된다(세피리아식). 지연 조회(노드 준비
## 순서 무관). 장착한 지팡이가 없어 지팡이가 숨으면 총구는 몸 중심으로 폴백한다(맨손 캐스팅).
var _wand: Node2D = null

# ── 시전 (세98 · 정본 = docs/takbon-design/spell_cast_visual_design.md) ────────────────
## 🔴 **좌클릭 = 발사가 아니다.** 가드 → 마나 차감 → `ring_cast_started`(발밑이 열린다) →
## **duration초 대기** → `ring_cast_requested`(탄이 나간다). 등급이 그 길이를 판다(확정 ④).
##
## 🔴🔴 **`SceneTreeTimer`가 아니라 `_process` 카운트다운인 게 계약이다** — 시전 상태가 이 노드에
## 살아 있으므로 씬이 바뀌면(귀환·사망) 노드와 함께 사라져 **없는 씬에 쏘는 일이 구조적으로
## 불가능**하다(설계 ⓐ). 타이머는 노드보다 오래 살아 그 보장이 없다.
## ⚠ 그래서 `_exit_tree`에서 취소를 쏘지 않는다 — 씬이 바뀌면 발밑 마법진도 그 씬과 함께 죽고,
##   리페어런팅에도 도는 훅을 다는 건 세50이 실제로 밟은 함정이다(있지도 않은 문제를 막다 침묵을 심었다).
## ⚠ 히트스톱(`Engine.time_scale`)을 **탄다**(delta가 같이 줄어든다) — 설계 ⓗ의 기본값 유지.
##
## 🔴🔴 **세98(홀드): 「시전 중」의 단일 소스는 `_cast_left`가 아니라 이 플래그다.**
## 다 차고 손을 안 뗀 홀드 구간도 **시전 중**이라, `_cast_left > 0.0`으로 재면 연사 차단·슬롯
## 전환 차단·이동 감속이 **다 차는 순간 통째로 풀린다**(에러 0 — 원은 열려 있는데 그 위로 두 번째
## 시전이 들어가 마법진이 겹친다). 그래서 남은 시간과 시전 여부를 갈랐다.
var _casting: bool = false
## 남은 **채우는** 시간(0 = 다 찼다). 홀드 구간에도 0으로 앉아 있다 — 계속 흐르지 않는다.
var _cast_left: float = 0.0
## 🔴 좌클릭을 뗐나 (latch). 시작할 땐 false고, 한 번 참이 되면 다시 눌러도 **안 돌아온다** —
## 떼는 순간 발사가 확정된다. 아직 채우는 중에 떼면 여기만 서고 발사는 **다 차는 순간**이다.
## ⚠ 프로그램에서 `fire()`를 직접 부르면(테스트) 버튼이 안 눌려 있으므로 첫 프레임에 참이 된다
##   = 옛 「duration 뒤 자동 발사」와 같은 타이밍이라 기존 그물이 그대로 산다.
var _cast_released: bool = false
## 🔴 시작 시점 **스냅샷** — `to_assembly()`는 시전 한 번에 **한 번만** 부른다(설계 ⓖ).
## emit 시점에 `GameState.ring_equipped[_slot]`을 다시 읽으면 시전 중 슬롯을 바꿨을 때
## **그린 것 ≠ 나가는 것**이 된다(에러 0). 그래서 슬롯 전환도 시전 중엔 막는다.
var _cast_assembly: Dictionary = {}
## 🔴 origin·aim도 스냅샷이다 — `ring_cast_started`와 `ring_cast_requested`가 **같은 `_muzzle()`
## 값**을 실어야 총구 단일 소스(세65)가 시전 시작에서만 갈라지지 않는다(설계 ⓛ).
## ⚠ 대가: **시전 중 움직여도 탄은 클릭한 자리·방향에서 나간다.** 확정 ④⑤(강한 진 = 오래 무방비,
##   되돌릴 수 없다)와 결이 같아 그렇게 골랐다. F5에서 "뒤에서 날아온다"로 읽히면 여기만
##   `_muzzle()`·`_aim` 재조회로 바꾸고 ⓛ 그물은 started 쪽에 남겨라.
var _cast_origin := Vector2.ZERO
## 🔴 이 시전이 실제 버튼 눌림으로 시작됐나 (false = 프로그램 호출 → 홀드 없음. `_tick_cast` 참조).
var _cast_by_input := false
## 시전 중 이동 배수 — 시작할 때 점수로 한 번 정한다(점수는 시전 중 안 변한다). `player`가 읽는다.
var _cast_move_mult: float = 1.0


## 지금 고른 슬롯 · 조준 방향 — 씬이 읽는다 (테스트도 이 API로만 본다).
func slot() -> int:
	return _slot


func aim() -> Vector2:
	return _aim


## 시전 중인가 — 발사·슬롯 전환 차단과 이동 감속이 이 술어 하나를 본다.
## 🔴 **채우는 중 + 홀드 중을 둘 다 포함한다**(위 `_casting` 주석) — 홀드에서 풀리면 원이 겹친다.
func is_casting() -> bool:
	return _casting


## 다 차 놓고 손을 안 뗀 「홀드」 구간인가 — 🔴 **헤드리스 관측점이다**(`floor_circle.bounds_radius`
## 선례). "다 찬 뒤에도 안 뗐으면 안 나간다"를 재는 그물이 이걸로 **홀드에 들어간 것 자체**를
## 확인한다 — 안 그러면 「발사 0회」가 *"시전이 애초에 안 걸렸다"*와 구분이 안 된다(자명 통과).
func is_holding() -> bool:
	return _casting and _cast_left <= 0.0


## 🔴 시전 중 이동 배수(1.0 = 평소). `player._physics_process`가 `GameState.move_speed()`/
## `run_speed()`의 **결과에** 곱한다 — 모자(HAT)·달리기 배수가 이미 실린 값 위에 얹혀야
## 장비 효과가 시전 중에만 조용히 사라지지 않는다(세42 선례).
func cast_move_mult() -> float:
	return _cast_move_mult if is_casting() else 1.0


## 🔴 시전을 끊는다 — **마나는 안 돌려준다**(설계 ⓓ: 돌려주면 "모달 열었다 닫아 마나 아끼기"가
## 생기고 자연 회복과 싸운다). 부르는 곳 = 구르기 시작(`player`) · 모달/책 열림(아래 `_process`).
## 🔴 `ring_cast_canceled`를 반드시 쏜다 — 안 쏘면 시전은 끊겼는데 **발밑 원만 남아** "쐈는데
## 안 나갔다"로 읽힌다. 반환 = 실제로 끊었나(시전 중이 아니었으면 false).
func cancel_cast() -> bool:
	if not is_casting():
		return false
	_clear_cast()
	EventBus.ring_cast_canceled.emit()
	return true


func _process(delta: float) -> void:
	# 🔴 시전 진행은 **아래 early-return보다 먼저** 본다 — 모달·책이 열리면 「멎는」 게 아니라
	# **취소**다(설계 ⓕ). `enabled=false`·`ui_modal_open`은 조준·입력만 막지 지연 emit은 안 막아서,
	# 마을에서 시전하고 책상 [E]를 누르면 펼쳐진 책 위로 마법이 날아간다.
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


## 🔴 시전 진행 — **채우기 → 홀드 → 발사** (확정 ⑦). 여기가 「떼면 나간다」의 전부다.
##
## 🔴🔴 **뗐는지는 폴링으로 본다 — `_unhandled_input`의 released 이벤트가 아니다.**
## 이벤트로만 받으면 **영원히 홀드에 갇히는 길이 셋**이고 전부 에러가 0이다(= 마법이 영영 안 나가고
## 이동만 무거워진다. 홀드는 원래 「기다리는」 상태라 화면으로도 구분이 안 된다):
##   ① 화면을 덮는 Control이 `mouse_filter=STOP`이면 뗀 이벤트를 **먹는다**(누른 건 이미 닿았어도).
##   ② 창 포커스가 빠지면 엔진이 `Input.release_pressed_events()`로 **액션만 풀고 이벤트는 안 쏜다**
##      — alt-tab 한 번에 갇힌다.
##   ③ `_unhandled_input`은 UI가 먼저 먹은 뒤에만 오고, 이 노드는 모달 중엔 그 함수를 아예 건너뛴다.
## 폴링은 셋을 **한 자리에서** 닫는다(늦어야 한 프레임 = 체감 불가). 선례 = `player.gd`의 달리기
## 판정(`Input.is_action_pressed("dash")`) — 같은 이유로 같은 수법이다.
## ⚠ 그래서 여기 말고 다른 곳에 「뗌」 판정을 또 만들지 마라(두 소스가 갈리면 T5다).
func _tick_cast(delta: float) -> void:
	if not _cast_released and not Input.is_action_pressed(&"attack_basic"):
		_cast_released = true
	if _cast_left > 0.0:
		_cast_left = maxf(_cast_left - delta, 0.0)
	# 🔴 다 찼는데 아직 쥐고 있으면 **열린 채 머문다** — 자동 발사가 없다.
	#   여기에 "오래 들면 세진다"를 얹지 마라(확정 ⑦ 표에서 각하된 안이다 — 홀드가 위력 축이 되면
	#   조립과 경쟁하는 **새 스칼라 축**이 생겨 GDD §7을 어긴다). 홀드는 **타이밍만** 판다.
	# 🔴🔴 **뗄 손이 없는 시전은 홀드 규칙에서 뺀다** — `fire()`를 프로그램에서 부른 경우
	#   (헤드리스 그물·스크립트)는 버튼이 애초에 안 눌려 있어 **첫 프레임에 「뗐다」로 잡힌다.**
	#   그대로 두면 아래 불발 규칙에 걸려 **모든 프로그램 호출이 불발**이 되고, 발사를 재는 그물이
	#   통째로 죽는다(실측: 이 분기가 없으면 3건이 즉시 빨개진다).
	# ⚠ **라이브는 이 분기를 절대 안 탄다** — `fire()`는 `_unhandled_input`의
	#   `is_action_pressed(&"attack_basic")` 안에서만 불리므로 그 순간 반드시 눌려 있다.
	#   즉 「테스트만 다른 길」이 아니라 **「손가락이 없으면 뗄 수도 없다」**는 같은 규칙의 귀결이다.
	# 🔴 그물 = `Input.action_press`로 **진짜 눌림**을 만들어 홀드가 걸리는지 재는 항목(§10).
	#   그게 없으면 이 분기가 라이브 경로까지 조용히 삼켜도 아무도 모른다(= T1).
	if not _cast_by_input:
		if _cast_left <= 0.0:
			_release_cast()
		return
	if not _cast_released:
		return
	# 🔴🔴 **덜 찼는데 뗐으면 불발이다 — 마나는 태운다** (확정 ⑦-b · F5가 뒤집었다).
	#   초판은 *"일찍 떼도 다 차는 순간 자동 발사"*(최소 시간 보장)였는데, 실제로 켜 보니
	#   **한 번 톡 누르기만 해도 차징이 알아서 굴러가** *"꾹 누르고 있다"*는 감각이 통째로 죽었다.
	#   → 이제 **누르고 있는 동안만 시전이 산다.** 손을 떼는 순간 승부가 난다:
	#      다 찼으면 나가고, 덜 찼으면 흩어진다.
	# ⚠ 취소와 **같은 문**으로 보낸다(`cancel_cast`) — 연출·마나 규칙이 구르기 취소와 같아야
	#   "끊겼다"가 한 가지 그림으로 읽힌다(설계 ⓓ: 돌려주면 마나 아끼기 수법이 생긴다).
	if _cast_left > 0.0:
		cancel_cast()
		return
	_release_cast()


## 🔴 발사는 **좌클릭만**이다 (사용자 확정). Space는 발사가 아니다 — 시험대가 Space도 받는 건
## 시험대 사정이다. Space를 다른 용도로 임의 배정하지도 마라: 그건 사용자가 정할 몫이다.
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
	# 🔴 시전 중 슬롯 전환 차단 (설계 ⓖ). 나가는 건 시작할 때의 **스냅샷**이므로, 강조 칸만 옮기면
	# HUD가 가리키는 진과 실제로 나가는 마법이 **에러 없이 갈라진다**. 확정 ⑤와 결이 같다 —
	# 시전은 되돌릴 수 없고, 무르려면 구르기(스페이스)로 끊는다.
	if is_casting():
		return
	_slot = slot
	# 🔴 슬롯 선택 안내(notice→HUD.say)를 더 안 쏜다 (세64). HUD가 선택 슬롯 상세를 **상시 한 줄**로
	# 그려서, 여기서 또 say를 띄우면 같은 "슬롯 N … 그려 장착"이 두 줄로 겹친다(사용자 지적). 강조 칸
	# 이동만 알린다. 발사 거부 안내(fire의 notice)는 그대로 — 그건 상시 줄이 못 보여 주는 순간 피드백이다.
	slot_changed.emit(slot)
	queue_redraw()


## 🔴 `to_assembly()`로 쏜다 — 그래야 `assembly.score`(손그림 점수)가 실려 **그때 그린 위력이
## 그대로 난다**. 직접 Dictionary를 만들면 score가 빠져 조용히 기준 위력이 된다.
##
## 🔴 세98: 여기서 **탄이 나가지 않는다** — 시전이 걸린다. 순서가 곧 계약이다(설계 ⓚ):
##   ① 빈 슬롯 거부 → ② 마나 차감 → ③ 스냅샷 + `ring_cast_started` → duration 채우기 →
##   **좌클릭을 뗄 때까지 홀드**(`_tick_cast`) → ④ `ring_cast_requested`
## 가드가 ③보다 **먼저**여야 빈 슬롯·마나 부족에 발밑이 열리고 차징음이 나는 일이 없다.
func fire() -> void:
	# 🔴 연사 차단 (설계 ⓒ) — 없으면 바닥 마법진이 겹겹이 쌓이고 마나가 연타로 녹는다.
	# 🔴 세98(홀드): **차단이 홀드 구간까지 이어진다** — `is_casting()`이 `_cast_left`가 아니라
	#   `_casting`을 보기 때문이다. 다 찬 원을 들고 있는 동안 또 누르면 원이 겹친다.
	# ⚠ **조용히 거부해도 되는 유일한 자리다**: 이미 열린 발밑 마법진이 "지금 시전 중"을 말한다
	#   (빈 슬롯·마나 부족과 달리 화면에 이유가 이미 나와 있다). 안내를 띄우면 연타마다 도배된다.
	if is_casting():
		return
	# 🔴 빈 슬롯은 발사 거부 (세션59, 사용자 확정 — 세션44 「매직볼 바닥」 은퇴). 새 연출(글로우
	# 볼·트레일·플래시)이 매직볼에도 실리자 "아무것도 안 그렸는데 마법이 나간다"로 읽혔다.
	# 이제 발사 = 그린 진뿐이다. ⚠ 거부는 조용히 하지 마라(commit_rejected 규칙과 같은 병) —
	# 안내가 없으면 "장착했는데 안 나간다"가 된다. 마나 판정보다 먼저 — 거부에 마나를 태우지 않는다.
	var design: RingDesign = GameState.ring_equipped[_slot]
	if design == null:
		notice.emit("장착된 진이 없다 — 책상(E)에서 맺어 장착해라", true)
		return
	# 🔴 마나 소모 — 이게 없으면 좌클릭 연사다 (세션 35). 수치를 여기 박지 마라.
	# 🔴 세85: **`GameState.cast_mana_cost()`를 부른다** — 장착 지팡이의 `wand_mana_mult`가 얹힌 값이다
	# (은퇴한 `wand_pattern`을 대신하는 실효 축). HUD 마나 막대도 같은 함수를 봐야 「부족」 경계와
	# 실제 소모가 안 갈라진다.
	# ⚠ debug_free_cast(에디터 실행 전용) = 테스트 편의 무소모 — 익스포트에선 항상 false.
	# 🔴 세98: 마나는 **시전 시작**에 나간다 — 취소돼도 안 돌아온다(설계 ⓓ).
	if not GameState.debug_free_cast and not GameState.spend_mana(GameState.cast_mana_cost()):
		notice.emit("마나가 부족하다 — 잠시 기다려라", true)
		return
	# ③ 여기서부터가 시전이다. `to_assembly()`는 이 줄에서 **한 번만** 불린다(ⓖ).
	_cast_assembly = design.to_assembly()
	# 🔴 `origin`은 **발밑 원을 여는 자리**라 시작 시점을 얼린다. 반면 **탄이 나가는 자리·방향은
	#   `_release_cast`가 「지금」을 다시 본다** — 얼리면 걸어간 만큼 탄이 몸 뒤에서 나온다(F5 각하).
	_cast_origin = _muzzle()
	var score := float(_cast_assembly.get("score", 0.0))
	_cast_move_mult = RingPower.cast_move_mult_of(score)
	var duration := maxf(RingPower.cast_time_of(score), 0.0)
	_cast_left = duration
	# 🔴 세98(홀드): 「뗐나」는 여기서 **읽지 않는다** — 첫 `_tick_cast`가 폴링으로 정한다.
	#   여기서 `Input.is_action_pressed`를 봐 두면 상태가 두 곳에서 정해져 갈라진다.
	_cast_released = false
	# 🔴 이 시전이 **실제 버튼 눌림**으로 시작됐나 — 여기서만 정한다(`_tick_cast` 머리말 참조).
	#   프로그램 호출(그물·스크립트)이면 false라 홀드 없이 다 차면 나간다.
	_cast_by_input = Input.is_action_pressed(&"attack_basic")
	_casting = true
	EventBus.ring_cast_started.emit(_cast_assembly, _cast_origin, duration)
	# 시전 시간을 0으로 조이면(balance) 예전처럼 **즉발**로 돈다 — 그 되돌림이 살아 있게 분기를 남긴다.
	# ⚠ **즉발엔 홀드가 없다**(뗄 때까지 기다리지 않는다) — 「채우는 시간이 0」이면 그 되돌림이
	#   되살리려는 건 세97까지의 *누르면 나간다*이기 때문이다. duration > 0일 때만 확정 ⑦이 돈다.
	if duration <= 0.0:
		_release_cast()


## ④ 손을 뗐고 다 찼다 — 쏜다.
##
## 🔴🔴 **무엇을 얼리고 무엇을 다시 보는지가 갈린다** (F5가 정한 자리다):
##   • **`assembly`는 스냅샷이다**(설계 ⓖ) — 시작할 때 `to_assembly()`를 한 번만 부른다.
##     안 그러면 홀드 중 슬롯을 바꿨을 때 **그린 것 ≠ 나가는 것**이 된다(에러 0).
##   • 🔴 **`origin`·`aim`은 반대로 「지금」을 다시 본다.** 초판은 셋을 다 얼렸는데,
##     사용자가 F5에서 *"처음에 기를 모은 데에서 발사됨, 캐릭터가 아니라"*로 즉시 잡아냈다 —
##     시전이 길수록(퍼펙트 0.75초) 그동안 걸어간 거리만큼 **탄이 몸 뒤에서 날아왔다.**
##     ⚠ 되돌리지 마라: 「조준을 클릭 순간에 건다」는 긴장은 **실물로 확인해 각하됐다.**
## ⚠ 발신 전에 상태를 먼저 지운다 — 수신자가 그 안에서 다시 `fire()`를 불러도 얽히지 않게.
## ⚠ `ring_cast_started`의 origin은 여전히 **시작 시점**이다(그건 발밑 원을 여는 자리라 맞다) —
##   그래서 「started.origin == requested.origin」은 **이제 계약이 아니다.** 총구 단일 소스
##   (세65 `muzzle_position()`)는 양쪽 다 `_muzzle()`을 거치는 것으로 지켜진다.
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


## 🔴 발사 원점 = 떠있는 지팡이 끝(총구 단일 소스는 floating_wand). 지팡이가 없거나 숨었으면
## 몸 중심(global_position)으로 폴백 — 맨손도 쏠 수 있다.
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
