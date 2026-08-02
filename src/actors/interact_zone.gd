extends Area2D
## 상호작용 지점 — 플레이어가 가까이 오면 안내를 띄우고, E에 `interacted`를 쏜다.
## 책상·출입구·스테이션이 전부 같은 물건이라 한 스크립트다. 문구는 씬의 `Prompt.text`가 정한다.
##
## 🔴 **레이어 계약: layer 64(interaction) / mask 2(player)** — 씬에서 설정한다.
## 기본 레이어 1(world)에 두면 **캐리어(마스크 5 = world+enemy)가 여기 부딪혀 마법이 죽고**,
## mask에서 2(player)를 빼면 감지가 죽어 **안내가 안 뜨고 E가 안 먹는다**(= 마을이 통째로 막힌다).

signal interacted  ## 플레이어가 이 지점에서 E를 눌렀다

## 어느 지점인가 — 테스트가 노드 이름 대신 이걸로 찾는다. 새 프롭은 여기가 아니라 씬의 zone_id로 정한다.
## 🔴 **지점에 &"exit"을 함부로 주지 마라** — `test_chapter_auto`가 `&"exit"` 개수를 배선 수와 대조해
##  출구가 하나 더 있는 것으로 집계되면 그물이 빨개진다.
## 🔴 **한 zone_id에 두 일을 태울 땐 `base.gd _on_gate_talk` 머리말을 먼저 읽어라** —
##  아래 `ui_modal_open` 게이트 때문에 대사 뒤 다음 패널이 **E 두 번**이 되는 자리가 거기 있다.
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
	# 🔴 모달이 열려 있으면 E를 먹지 않는다 — 안 그러면 모달이 켜진 채 씬이 바뀌어 소프트락이 된다.
	if GameState.ui_modal_open:
		return
	if not (_player_in_range and event.is_action_pressed("interact")):
		return
	interacted.emit()

## 씬·테스트가 읽는 공개 상태 — 🔴 `base.gd`·`chest.gd`·그물 셋이 부른다. 지우면 그물이 침묵 통과한다.
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
