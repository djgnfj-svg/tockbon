extends Area2D
## 상호작용 지점 — 플레이어가 가까이 오면 안내를 띄우고, E에 `interacted`를 쏜다.
##
## 🔴 **책상 · 출입구 · 탈출구 · 각 스테이션은 같은 물건이다** (세션 26). 세션 25까지 이건
## `desk.gd`라는 이름으로 베이스에만 있었는데, 무대가 늘자 출구·귀환 지점이 같은 코드를 또 필요로
## 했다 — 문구만 다르고 하는 일은 하나다. 문구는 씬의 `Prompt.text`가 정한다.
##
## 🔴 **세99: 축이 하나 늘었다 — `hold_sec`(꾹 눌러 버티기, D7).** 기본 0이라 **여기 있는 모든
## 기존 지점은 한 톨도 안 바뀐다**(마을 전부 = 즉시). 켜는 곳은 지금 `boss_room`의 탈출 지점들뿐이다.
##
## 🔴 **레이어 계약: layer 64(interaction) / mask 2(player)** — 씬에서 설정한다.
## 기본 레이어 1(world)에 두면 **캐리어(마스크 5 = world+enemy)가 여기 부딪혀 마법이 죽는다**.
## 그리고 mask에서 2(player)를 빼면 감지가 죽어 **안내가 안 뜨고 E가 안 먹는다** —
## 베이스에선 그게 곧 "게임이 통째로 막힘"이다 (tests/test_base_auto가 그 짝을 묶는다).

signal interacted  ## 플레이어가 이 지점에서 E를 눌렀다

## 어느 지점인가 — 씬이 잇는 대상을 헷갈리지 않게, 테스트가 노드 이름 대신 이걸로 찾게.
## (실측 — `src/props/*.tscn`가 쥔 값 7개: &"desk" 책상 · &"forest_gate" **문**(정산 대사 + 챕터 선택) ·
##  &"npc" 길잡이 · &"refine" 정제대 · &"craft" 공방 · &"shop" 상점 · &"exit" **탈출구**(`exit_zone.tscn`).
##  새 프롭 = 여기 한 줄이 아니라 씬의 zone_id다)
## ⚠ **`&"npc"`는 씬 파일에만 남아 있다 — `base.tscn`이 세95에 길잡이를 뺐다**(문이 화자·정산을 겸한다).
##  `npc_guide.tscn`은 「주민 복귀」용으로 일부러 안 지웠다 — 그러니 여기 한 줄도 남긴다(값 목록은 실측이다).
## 🔴 **한 zone_id에 두 일을 태울 땐 `base.gd _on_gate_talk`의 머리말 ⓐ~ⓓ를 먼저 읽어라** —
##  `ui_modal_open` 게이트(아래) 때문에 대사 뒤 챕터 선택이 **E 두 번**이 되는 자리가 거기 있다.
## 🔴 **&"exit"은 보스방의 「나가는 길」 전량이다** — 씬 인라인(`boss_room.tscn`의 남쪽 `$Exit`)과
##  프롭(`exit_zone.tscn`)이 **같은 값**을 쥔다. ⚠ **세99에 `&"portal"`(보스 처치 후에만 뜨던 귀환
##  포탈)이 은퇴했다** — 사용자 확정 *"보스죽으면 포탈 x"*. 나가는 길에 조건이 붙은 종류는 이제 없으니
##  **탈출구를 새로 세울 때 새 zone_id를 만들지 마라**(갈라 두던 계약 자체가 사라졌다).
@export var zone_id: StringName = &""

## 🔴 D7(세99 던전 구조) — 이 지점이 **[E]를 꾹 눌러 버텨야** 발동하나.
## 🔴🔴 **기본 0 = 지금 그대로 「누르면 즉시」다.** 이 스크립트는 마을·보스방이 같이 쓰는 **공용
##  배우**라 이 기본값 하나가 회귀 방어선 전부다(설계 §6 S8) — 마을의 책상·문·스테이션은 씬에서
##  이 값을 안 건드리므로 한 톨도 안 바뀐다.
## 🔴🔴 **여기 적힌 숫자는 「몇 초」가 아니다 — 「0이냐 아니냐」 스위치다.** 실제 길이는
##  `balance.extract_hold_sec`가 쥔다(`_hold_duration`). 탈출구가 여럿이라 씬마다 초를 적어 두면
##  F5로 조일 값이 **출구 수만큼 흩어진다**(설계 §2-4가 그래서 소유자를 balance로 못 박았다).
##  켜는 쪽은 이름 붙은 상수를 쓴다 — `boss_room.HOLD_ON`.
@export var hold_sec: float = 0.0

## 홀드 진행 막대 — **연출값(손맛)이라 balance가 아니라 여기 const다.**
## ⚠ 겉모습은 임시다: 지금은 `Prompt` 문구 뒤에 글자로 그린다. 제대로 채워지는 그림은 vfx 몫이고,
##  이 자리가 지는 건 **「얼마나 남았는지가 화면에 있다」** 하나뿐이다(설계 §2-4의 dev 몫).
const HOLD_BAR_CELLS := 5
const HOLD_BAR_FILLED := "█"
const HOLD_BAR_EMPTY := "░"

@onready var _prompt: Label = $Prompt

var _player_in_range: bool = false

# ── 홀드 상태 ──────────────────────────────────────────────────────────────────
## 🔴 `_hold_left > 0.0`이 아니라 이 플래그가 「홀드 중」의 단일 소스다 — 다 찬 프레임에도
##  참이어야 `hold_progress() == 1.0`과 「애초에 안 눌렀다(0.0)」가 구분된다.
var _holding: bool = false
var _hold_left: float = 0.0
var _hold_total: float = 0.0
## 홀드 전 `Prompt` 문구 — 막대를 붙이기 전 원문. 🔴 **`_ready`에서 캐시하지 마라**: **부모가
## `add_child` 뒤에 문구를 덮는** 것이 프롭 계약이라(세44) 그 시점 값은 이미 낡았을 수 있다.
## 홀드를 **시작할 때** 집어야 늘 그때 화면에 있던 줄이 돌아온다.
## ⚠ 세99까지 이 자리의 예시는 「포탈」이었다 — 그 프롭은 은퇴했지만 **계약은 그대로 살아 있다.**
var _prompt_base: String = ""

func _ready() -> void:
	add_to_group("interact_zones")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _prompt != null:
		_prompt.visible = false
	# 홀드 중에만 돈다 — 홀드가 없는 지점(마을 전부)은 `_process`를 아예 안 탄다.
	set_process(false)

func _unhandled_input(event: InputEvent) -> void:
	# 🔴 모달(창고·책·정제대)이 열려 있으면 E를 먹지 않는다 (player·caster와 같은 게이트).
	# 안 그러면 창고를 연 채 숲길에서 E → 모달이 켜진 채 씬이 바뀌어 되돌릴 길이 없는 소프트락.
	if GameState.ui_modal_open:
		return
	if not (_player_in_range and event.is_action_pressed("interact")):
		return
	# 🔴 홀드가 꺼진 지점(hold_sec == 0)은 **여기서 끝난다** — 세98까지와 한 글자도 안 다르다.
	if _hold_duration() <= 0.0:
		interacted.emit()
		return
	_begin_hold()

## 🔴🔴 홀드 진행은 **폴링**이다 — 「뗐나」를 이벤트로 받지 않는다.
## `player_caster._tick_cast` 머리말의 실측 세 가지가 [E] 홀드에 그대로 재현되고 **전부 에러가 0**이다:
##  ① 화면 덮는 Control이 `mouse_filter=STOP`이면 뗀 이벤트를 **먹는다**(누른 건 이미 닿았어도)
##  ② 창 포커스가 빠지면 엔진이 `Input.release_pressed_events()`로 **액션만 풀고 이벤트는 안 쏜다**(alt-tab)
##  ③ `_unhandled_input`은 모달 중 이 노드에 **아예 안 온다**(위 게이트).
## 셋 다 「영원히 차오르는 막대」로 끝나는데 화면은 멀쩡하다. 폴링은 셋을 한 자리에서 닫는다.
## ✅ 덤: `_process` 카운트다운은 **씬 전환에 구조적으로 안전**하다 — 노드와 함께 죽는다
##   (`SceneTreeTimer`엔 그 보장이 없다). 그래서 취소 트리거 ④(씬 전환)는 코드가 0줄이다.
func _process(delta: float) -> void:
	if not _holding:
		return
	# 취소 ③ — 모달이 열렸다. `_unhandled_input`이 안 오므로 여기서만 잡힌다.
	if GameState.ui_modal_open:
		_cancel_hold()
		return
	# 손을 뗐다 = 취소. 🔴 액션 이름을 다른 데 또 적지 마라 — 정본은 `project.godot`이고
	# 위 `_unhandled_input`의 `is_action_pressed("interact")`와 **같은 이름**이어야 한다.
	if not Input.is_action_pressed(&"interact"):
		_cancel_hold()
		return
	_hold_left = maxf(_hold_left - delta, 0.0)
	_refresh_prompt()
	if _hold_left <= 0.0:
		_finish_hold()

## 플레이어가 범위 안인가 — 씬·테스트가 읽는 공개 상태 (내부 필드를 더듬지 않게).
func player_in_range() -> bool:
	return _player_in_range

## 🔴 지금 [E]를 꾹 누르고 있나 — **헤드리스 관측점이다**(`player_caster.is_holding()` 선례).
## `hold_progress() == 0.0`만 보면 *"막 시작했다"*와 *"애초에 안 눌렸다"*가 구분이 안 돼서
## 취소 그물이 전부 **자명 통과**가 된다(취소가 죽어도 0.0은 0.0이다).
func is_holding() -> bool:
	return _holding

## 🔴 홀드 진행률 0.0~1.0 — 화면 막대와 그물이 **같은 값**을 본다(표시 전용 사본을 만들면 T5).
func hold_progress() -> float:
	if not _holding or _hold_total <= 0.0:
		return 0.0
	return clampf(1.0 - _hold_left / _hold_total, 0.0, 1.0)

## 🔴 실제 홀드 길이 — **값의 소유자는 `balance`다**(`hold_sec`은 스위치일 뿐이다, 위 @export 참조).
## ⚠ `GameState.balance`를 **런타임에** 읽는다 — static 함수에서 `const RES.프로퍼티`를 읽으면
##  컴파일타임에 굳어 값을 흔드는 그물이 조용히 거짓 통과한다(세이브·밸런스 실측).
func _hold_duration() -> float:
	if hold_sec <= 0.0:
		return 0.0
	return maxf(GameState.balance.extract_hold_sec, 0.0)

func _begin_hold() -> void:
	if _holding:
		return
	_hold_total = _hold_duration()
	if _hold_total <= 0.0:
		interacted.emit()
		return
	_hold_left = _hold_total
	_holding = true
	if _prompt != null:
		_prompt_base = _prompt.text
	# 취소 ① 피격 — 🔴 **홀드 중에만** 잇고 끝나면 푼다(상시 구독 금지, 설계 §2-4).
	if not EventBus.player_hurt.is_connected(_on_player_hurt):
		EventBus.player_hurt.connect(_on_player_hurt)
	set_process(true)
	_refresh_prompt()

## 다 버텼다 — 여기서야 `interacted`가 나간다(즉시 지점과 **같은 시그널**이라 수신자는 안 바뀐다).
func _finish_hold() -> void:
	_end_hold()
	interacted.emit()

func _cancel_hold() -> void:
	if not _holding:
		return
	_end_hold()

## 상태를 접는다 — **시그널을 쏘지 않는다**(완료는 `_finish_hold`가 쏜다).
func _end_hold() -> void:
	_holding = false
	_hold_left = 0.0
	_hold_total = 0.0
	set_process(false)
	if EventBus.player_hurt.is_connected(_on_player_hurt):
		EventBus.player_hurt.disconnect(_on_player_hurt)
	if _prompt != null and _prompt_base != "":
		_prompt.text = _prompt_base

## 취소 ① — 맞으면 끊긴다. 🔴 이게 D7의 긴장 전부다: 안 걸려도 **화면은 정상**이라(설계 §6 S4)
## 그물이 이 경로를 따로 재야 한다.
func _on_player_hurt(_amount: float, _source_pos: Vector2) -> void:
	_cancel_hold()

## 진행을 문구에 얹는다 — 원문 뒤에 막대 한 칸씩.
func _refresh_prompt() -> void:
	if _prompt == null:
		return
	var filled: int = clampi(roundi(hold_progress() * HOLD_BAR_CELLS), 0, HOLD_BAR_CELLS)
	_prompt.text = "%s  %s%s" % [
		_prompt_base,
		HOLD_BAR_FILLED.repeat(filled),
		HOLD_BAR_EMPTY.repeat(HOLD_BAR_CELLS - filled),
	]

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		_player_in_range = true
		if _prompt != null:
			_prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body is CharacterBody2D:
		_player_in_range = false
		# 취소 ② — 범위를 벗어났다. 🔴 문구 복구가 여기 걸려 있으므로 `_prompt.visible = false`
		# **앞**에서 끊어라(순서가 바뀌면 다음에 들어왔을 때 막대가 붙은 채로 뜬다).
		_cancel_hold()
		if _prompt != null:
			_prompt.visible = false
