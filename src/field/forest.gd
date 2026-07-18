extends Node2D
## 숲 원정 — 나갔다 돌아오기 (세션 26, F1·F2).
##
## 🔴 **왜 만들었나**: 세션 25까지 그린 마법은 **허수아비만 때렸다**. 잘 그려 위력 160을 내도
## 나무 인형이라 "그래서 뭐?"였다 — 점수→위력 축(세션 23~24)을 다 만들어 놓고 그 위력이
## **의미를 갖는 자리**가 없었다. 사용자: *"마법을 사용할 사용처가 필요할꺼같은데?"*
##
## 루프: 베이스에서 [E] → 숲 → 적이 쫓아온다 → **들어온 자리로 돌아가 [E]** → 베이스.
##
## 사용자 확정 (2026-07-17):
##  • **죽어도 벌 없음** — 그냥 베이스로 돌아온다. 🔴 얻는 것(탁본)이 없으니 잃을 것도 없다:
##    익스트랙션의 긴장은 **탁본이 생겨야** 성립한다. 그래도 `bag_lost`는 쏜다 — 가방이 빈
##    지금은 no-op이지만, 그게 계약이고(event_bus.gd 주석) 탁본이 붙는 날 저절로 돈다.
##  • **귀환 = 들어온 자리로 가서 E** (익스트랙션 문법 — 돌아오는 길이 곧 긴장).
##  • **얻는 건 이번엔 없다** — 싸움 + 귀환만. 드롭 자리는 forest_enemy._die() 주석 참조.
##
## 🔴 **HP는 GameState가 쥔다** — 오토로드라 씬을 갈아타도 남는다. 그래서 여기서 로컬 HP를
## 만들지 마라: 숲에서 맞은 피해가 베이스로 이어지는 게 원장이 하나인 이유다.
##
## 씬(forest.tscn) 쪽 결정 — .tscn엔 주석을 못 달아서 여기 적는다:
##  • 🔴 **`Ground.mouse_filter = 2`(IGNORE) — 지우면 발사가 통째로 죽는다.** Ground는 화면을
##    다 덮는 ColorRect인데 **Control의 기본 mouse_filter는 STOP**이라 바닥이 좌클릭을 전부
##    먹는다 → `_unhandled_input`에 안 와서 발사가 아예 안 불린다. **에러도 경고도 없고,
##    헤드리스로는 절대 못 잡는다** (세션 25에 베이스가 정확히 이걸로 두 세션을 잃었다).
##  • `RingSpellSystem.z_index = 10` — 안 올리면 날아가는 진·탄·기둥이 Ground(z=0) 뒤에 가려
##    **안 보인다**. base.tscn과 같은 이유다.
##  • 나무는 **Polygon2D 장식이고 물리가 없다** — StaticBody2D로 만들면 world 레이어라
##    캐리어(마스크 5)가 나무마다 터진다. 숲에서 마법이 안 나가는 것처럼 보일 것이다.

const InteractZone := preload("res://src/actors/interact_zone.gd")
const Player := preload("res://src/actors/player.gd")
const Hud := preload("res://src/hud/hud.gd")

## 돌아갈 곳 — 🔴 **PackedScene이 아니라 경로다. 바꾸지 마라.**
##
## 처음엔 `@export var base_scene: PackedScene = preload(...)`로 썼다 (base.gd의 `forge_scene`
## 선례를 따라서). **그게 순환 preload를 만들었다**: base.gd가 forest.tscn을 preload하고 forest.gd가
## 다시 base.tscn을 preload한다 → 베이스로 부팅하면 base.tscn이 **아직 로드 중**일 때 forest.gd가
## 그걸 preload해서, `base_scene`이 **노드 0개짜리 껍데기**로 굳는다.
## 결과: 숲에서 귀환·사망해도 **베이스로 못 돌아간다** (`Parameter "new_scene" is null`).
##
## 🔴 **경로 문자열엔 로드 시점이 없다** — 전환할 때 처음 읽으므로 순환이 성립하지 않는다.
## `forge_scene`이 PackedScene이어도 되는 이유는 **책이 base를 안 물기 때문**이다(순환이 아니다).
## ⚠ 헤드리스는 이걸 못 잡는다: 테스트가 forest.tscn을 **먼저** 로드하므로 base preload가
## 멀쩡히 끝난다. **베이스로 부팅한 실제 게임에서만** 껍데기가 된다 (세션 26에 실측).
@export_file("*.tscn") var base_scene_path: String = "res://src/base/base.tscn"

## 쓰러진 뒤 베이스로 돌아가기까지 (초) — 연출값. 0이면 뭘 맞고 죽었는지 못 보고 화면이 바뀐다.
const DEATH_BEAT_SEC := 0.9

@onready var _player: Player = $Player
@onready var _extract_zone: InteractZone = $ExtractZone
@onready var _hud: Hud = $Hud/Hud

## 씬 전환은 한 번뿐 — 귀환 도중 죽거나, 죽는 중에 E를 누르면 두 번 갈아탄다.
var _leaving: bool = false


func _ready() -> void:
	# 🔴 출격 = 만HP. `GameState.hp` 주석의 "출격 시 reset"이 여기서 지켜진다.
	# 이게 없으면 **죽는 게 이득**이 된다: 죽으면 어차피 베이스로 돌아가는데 HP는 안 깎인 채라,
	# 다친 몸으로 걸어 돌아오는 것보다 그 자리에서 죽는 편이 싸진다 (벌이 없는 지금은 특히).
	GameState.reset_player_hp()
	# 출격 = 만마나 (세션 35). HP와 같은 이유 — 연습장에서 쏘고 저마나로 원정을 시작하면 안 된다.
	GameState.restore_mana_full()
	# 🔴 여기서부터 허기가 준다 (세션 35). 만복으로 시작 — 이 플래그가 GameState._process의 유일한 스위치다.
	GameState.in_expedition = true
	GameState.restore_hunger_full()
	# 🔴 모달 플래그를 내린다 — 오토로드라 씬 전환에도 남는다(base.gd _ready와 같은 안전망).
	GameState.ui_modal_open = false
	_extract_zone.interacted.connect(_extract)
	_player.caster.notice.connect(_hud.say)
	_player.caster.slot_changed.connect(_hud.select)
	_hud.select(_player.caster.slot())
	EventBus.player_hp_changed.connect(_on_hp_changed)
	# 🔴 목표 달성 넛지 (세션40 턴인) — 숲에서 5마리째를 잡는 순간이 여기다. **완료가 아니라 정산 대기**라
	# quest_completed가 아니라 quest_ready를 듣는다(완료는 베이스 길잡이 정산에서만 → 숲에선 절대 안 뜬다).
	# 넛지가 사라진 그 순간이 "왜 돌아가야 하나"를 알려줄 유일한 타이밍이라 숲에서도 꼭 띄운다.
	EventBus.quest_ready.connect(_on_quest_ready)
	_hud.say("숲이다 — 들어온 자리(남쪽)로 돌아가 E를 누르면 귀환한다")


## 목표 하나를 달성했다 — 아직 완료 아님. 길잡이에게 돌아가 정산하라고 HUD로 민다.
func _on_quest_ready(quest_id: StringName) -> void:
	var q := Db.get_quest(quest_id)
	if q != null:
		_hud.say("목표 달성: %s — 길잡이에게 돌아가 정산하라 [?]" % q.title)


## 🔴 귀환 성공 — `extraction_success`가 **가방을 창고로 옮기고 자동 저장**한다 (GameState·SaveManager가
## 이미 이 시그널에 연결돼 있다). 세션 25까지 이 시그널은 **발신자가 없었다** — 필드가 그 자리였다.
func _extract() -> void:
	if _leaving:
		return
	_leaving = true
	EventBus.extraction_success.emit()
	_to_base()


func _on_hp_changed(hp: float, _hp_max: float) -> void:
	if hp <= 0.0:
		_die()


## 쓰러졌다 — 벌은 없다(사용자 확정). `bag_lost`는 그래도 쏜다: 가방이 빈 지금은 no-op이지만
## 수신자(GameState 가방 비우기 · SaveManager 자동 저장 = 세이브스컴 방지)는 이미 연결돼 있다.
func _die() -> void:
	if _leaving:
		return
	_leaving = true
	_player.caster.enabled = false
	_player.set_physics_process(false)
	_hud.say("쓰러졌다 — 베이스로 돌아온다", true)
	EventBus.bag_lost.emit()
	await get_tree().create_timer(DEATH_BEAT_SEC).timeout
	_to_base()


func _to_base() -> void:
	get_tree().change_scene_to_file(base_scene_path)
