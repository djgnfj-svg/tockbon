extends Area2D
## 상호작용 지점 — 플레이어가 가까이 오면 안내를 띄우고, E에 `interacted`를 쏜다.
##
## 🔴 **책상 · 출입구 · 탈출구 · 각 스테이션은 같은 물건이다** (세션 26). 세션 25까지 이건
## `desk.gd`라는 이름으로 베이스에만 있었는데, 무대가 늘자 출구·귀환 지점이 같은 코드를 또 필요로
## 했다 — 문구만 다르고 하는 일은 하나다. 문구는 씬의 `Prompt.text`가 정한다.
##
## 🪦 **세112 R1: `hold_sec`(꾹 눌러 버티기, D7)이 통째로 죽었다.** 세99에 늘었던 축이고 켜는 곳이
## `boss_room`의 탈출 지점 하나뿐이었는데, 장르 전환이 「3초 꾹 탈출」을 **「걷는다」로** 바꿨다
## (`room_loop_design.md` R1). ⇒ **지금 모든 지점은 [E] 한 번에 즉시**이고, 그게 세98까지의 동작이다.
## 🔴 **되살리지 마라 — 되살릴 거면 D7부터 돌아와야 한다.** 같이 사라진 것: 진행 막대 · 취소 4트리거
## (피격·범위 이탈·모달·씬 전환) · `balance.extract_hold_sec` 소비. 경위 = `git show`(세99~112).
##
## 🔴 **레이어 계약: layer 64(interaction) / mask 2(player)** — 씬에서 설정한다.
## 기본 레이어 1(world)에 두면 **캐리어(마스크 5 = world+enemy)가 여기 부딪혀 마법이 죽는다**.
## 그리고 mask에서 2(player)를 빼면 감지가 죽어 **안내가 안 뜨고 E가 안 먹는다** —
## 베이스에선 그게 곧 "게임이 통째로 막힘"이다 (tests/test_base_auto가 그 짝을 묶는다).

signal interacted  ## 플레이어가 이 지점에서 E를 눌렀다

## 어느 지점인가 — 씬이 잇는 대상을 헷갈리지 않게, 테스트가 노드 이름 대신 이걸로 찾게.
## (실측 — `src/props/*.tscn`가 쥔 값 8개: &"desk" 책상 · &"forest_gate" **문**(정산 대사 + **출발**) ·
##  &"npc" 길잡이 · &"refine" 정제대 · &"craft" 공방 · &"shop" 상점 · &"exit" **나가는 길** ·
##  &"landmark" **상자 열기**(`chest.tscn`의 `OpenZone` — 세101 N26 · 세112 1c에 `nest`→`chest` 개명).
##  새 프롭 = 여기 한 줄이 아니라 씬의 zone_id다)
## 🔴 **&"landmark"가 &"exit"이 아닌 것이 계약이다** — `test_chapter_auto`가 `&"exit"`을 세어 배선 수와
##  대조하므로, 지점에 그 값을 주면 **출구가 하나 더 있는 것으로 집계돼** 그물이 빨개진다(설계 §10-1.5).
## ⚠ **`&"npc"`는 씬 파일에만 남아 있다 — `base.tscn`이 세95에 길잡이를 뺐다**(문이 화자·정산을 겸한다).
##  `npc_guide.tscn`은 「주민 복귀」용으로 일부러 안 지웠다 — 그러니 여기 한 줄도 남긴다(값 목록은 실측이다).
## 🔴 **한 zone_id에 두 일을 태울 땐 `base.gd _on_gate_talk`의 머리말 ⓐ~ⓓ를 먼저 읽어라** —
##  `ui_modal_open` 게이트(아래) 때문에 대사 뒤 챕터 선택이 **E 두 번**이 되는 자리가 거기 있다.
## 🔴 **&"exit"은 보스방의 「나가는 길」 전량이다** — 세112 R1 뒤 **씬 인라인 `$Exit` 하나**다
##  (`exit_zone.tscn`은 탈출구 여럿과 함께 삭제됐다 · `&"portal"`은 세99에 은퇴했다).
##  나가는 길에 조건이 붙은 종류는 없으니 **새 zone_id를 만들지 마라**(갈라 두던 계약 자체가 없다).
@export var zone_id: StringName = &""

@onready var _prompt: Label = $Prompt

var _player_in_range: bool = false

func _ready() -> void:
	add_to_group("interact_zones")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _prompt != null:
		_prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	# 🔴 모달(창고·책·정제대)이 열려 있으면 E를 먹지 않는다 (player·caster와 같은 게이트).
	# 안 그러면 창고를 연 채 숲길에서 E → 모달이 켜진 채 씬이 바뀌어 되돌릴 길이 없는 소프트락.
	if GameState.ui_modal_open:
		return
	if not (_player_in_range and event.is_action_pressed("interact")):
		return
	interacted.emit()

## 플레이어가 범위 안인가 — 씬·테스트가 읽는 공개 상태 (내부 필드를 더듬지 않게).
## 🔴 **읽는 데가 여럿이다**(`base.gd`·`chest.gd`·그물 셋) — 아래 홀드 묘비를 세울 때 이 함수까지
##  같이 잘라 먹어 **`test_base_auto`·`test_chest_open_auto`가 `SCRIPT ERROR`로 침묵 통과**했다(세112 실측).
func player_in_range() -> bool:
	return _player_in_range

## 🪦 **세112 R1에 홀드 기계를 통째로 걷었다** — `_process` 폴링 · `is_holding()` · `hold_progress()` ·
## `_hold_duration()` · `_begin_hold`/`_finish_hold`/`_cancel_hold`/`_end_hold` · `_on_player_hurt` ·
## `_refresh_prompt` + 진행 막대 상수 셋.
##
## 🔴🔴 **그 코드가 닫고 있던 함정 셋을 남긴다 — 다시 「꾹 누르기」를 만들 사람이 밟는다**
##  (`player_caster._tick_cast` 머리말에 같은 셋이 살아 있다 · 전부 **에러가 0**이다):
##   ① 화면 덮는 Control이 `mouse_filter=STOP`이면 **뗀 이벤트를 먹는다**(누른 건 이미 닿았어도)
##   ② 창 포커스가 빠지면 엔진이 `Input.release_pressed_events()`로 **액션만 풀고 이벤트는 안 쏜다**(alt-tab)
##   ③ `_unhandled_input`은 모달 중 이 노드에 **아예 안 온다**(위 게이트)
##  셋 다 「영원히 차오르는 막대」로 끝나는데 **화면은 멀쩡하다.** ⇒ 🔴 **이벤트로 「뗐나」를 받지 말고
##  `_process` 폴링으로 재라** — 그게 셋을 한 자리에서 닫는다(덤: `_process`는 노드와 함께 죽어 씬 전환에
##  구조적으로 안전하다. `SceneTreeTimer`엔 그 보장이 없다).
## ⚠ 되살릴 땐 **그물도 같이** — 실눌림을 재던 `test_extract_hold_auto`도 R1에 지워졌다(`git show` 세112).


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		_player_in_range = true
		if _prompt != null:
			_prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body is CharacterBody2D:
		_player_in_range = false
		if _prompt != null:
			_prompt.visible = false
