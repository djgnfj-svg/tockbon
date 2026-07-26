extends Area2D
## 상호작용 지점 — 플레이어가 가까이 오면 안내를 띄우고, E에 `interacted`를 쏜다.
##
## 🔴 **책상 · 출입구 · 귀환 포탈 · 각 스테이션은 같은 물건이다** (세션 26). 세션 25까지 이건
## `desk.gd`라는 이름으로 베이스에만 있었는데, 무대가 늘자 출구·귀환 지점이 같은 코드를 또 필요로
## 했다 — 문구만 다르고 하는 일은 하나다. 문구는 씬의 `Prompt.text`가 정한다.
##
## 🔴 **레이어 계약: layer 64(interaction) / mask 2(player)** — 씬에서 설정한다.
## 기본 레이어 1(world)에 두면 **캐리어(마스크 5 = world+enemy)가 여기 부딪혀 마법이 죽는다**.
## 그리고 mask에서 2(player)를 빼면 감지가 죽어 **안내가 안 뜨고 E가 안 먹는다** —
## 베이스에선 그게 곧 "게임이 통째로 막힘"이다 (tests/test_base_auto가 그 짝을 묶는다).

signal interacted  ## 플레이어가 이 지점에서 E를 눌렀다

## 어느 지점인가 — 씬이 잇는 대상을 헷갈리지 않게, 테스트가 노드 이름 대신 이걸로 찾게.
## (실측 — `src/props/*.tscn`가 쥔 값 7개: &"desk" 책상 · &"forest_gate" **문**(정산 대사 + 챕터 선택) ·
##  &"npc" 길잡이 · &"refine" 정제대 · &"craft" 공방 · &"shop" 상점 · &"portal" 귀환 포탈.
##  새 프롭 = 여기 한 줄이 아니라 씬의 zone_id다)
## ⚠ **`&"npc"`는 씬 파일에만 남아 있다 — `base.tscn`이 세95에 길잡이를 뺐다**(문이 화자·정산을 겸한다).
##  `npc_guide.tscn`은 「주민 복귀」용으로 일부러 안 지웠다 — 그러니 여기 한 줄도 남긴다(값 목록은 실측이다).
## 🔴 **한 zone_id에 두 일을 태울 땐 `base.gd _on_gate_talk`의 머리말 ⓐ~ⓓ를 먼저 읽어라** —
##  `ui_modal_open` 게이트(아래) 때문에 대사 뒤 챕터 선택이 **E 두 번**이 되는 자리가 거기 있다.
## ⚠ 하나 더 있고 **그것만 프롭 씬이 아니다**: &"exit" = 보스방 남쪽 상시 귀환 출구(세88) — `boss_room.tscn`의
##  인라인 Area2D가 쥔다. 🔴 &"portal"과 갈라 둔 게 계약이다 — 포탈은 보스 처치 후에만 뜨고(그 그물이
##  `test_chapter_auto`에 산다) 출구는 처음부터 있다. 출구에 &"portal"을 주면 그 그물이 빨개진다.
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
	if _player_in_range and event.is_action_pressed("interact"):
		interacted.emit()

## 플레이어가 범위 안인가 — 씬·테스트가 읽는 공개 상태 (내부 필드를 더듬지 않게).
func player_in_range() -> bool:
	return _player_in_range

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
