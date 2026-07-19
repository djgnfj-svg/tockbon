extends Node2D
## 이동 튜토리얼 방 (세션41 온보딩 구간 A) — 게임의 첫 씬(새 게임 → 여기 → 베이스).
## 침대에서 깨어나 WASD로 걷고, 길을 막는 잔해를 Shift로 굴러 넘어 문으로 나간다.
## 🔴 설명 팝업이 아니라 **"길이 막혀서" 배우게** 한다 — 문에 닿으려면 걸어야 하고, 잔해는 굴러야 넘는다.
##
## 🔴 잔해 통과 = 구르기 무적과 **같은 술어**(player.is_rolling())를 읽는다:
##   잔해 = layer 8(BARRIER_LAYER)의 StaticBody2D. 플레이어 마스크에 8을 얹어 평소엔 막히고,
##   구르는 동안만 마스크에서 8을 빼 통과시킨다. 튜토에서만 8을 쓰므로 베이스·숲엔 영향이 없다
##   (player.tscn은 8을 안 켠다 — 공용 배우 무변경).
## 🔴 Ground.mouse_filter=2 규약은 여기선 무의미(발사 계층 없음)하지만 관례상 유지.

const BASE_SCENE := "res://src/base/base.tscn"
const BARRIER_LAYER := 8   ## 잔해 전용 물리 레이어 (world=1과 분리 — 구르는 동안만 플레이어가 통과)
const NEAR := 130.0        ## 안내문이 뜨고 사라지는 거리 기준(px)

@onready var _player: CharacterBody2D = $Player
@onready var _barrier: StaticBody2D = $Barrier
@onready var _door: Area2D = $Door
@onready var _prompt_wasd: Label = $Ui/PromptWasd
@onready var _prompt_roll: Label = $Ui/PromptRoll

var _exited := false

func _ready() -> void:
	GameState.ui_modal_open = false
	GameState.in_expedition = false   # 튜토엔 허기 없음
	_player.caster.enabled = false    # 이동만 익힌다 — 조준·발사 끔
	# 잔해(layer 8)와 부딪히도록 플레이어 마스크에 8을 얹는다 (런타임 = 튜토 한정).
	_player.set_collision_mask_value(BARRIER_LAYER, true)
	_door.body_entered.connect(_on_door)
	_prompt_roll.visible = false

func _physics_process(_delta: float) -> void:
	var px := _player.global_position.x
	var bx := _barrier.global_position.x
	# WASD 안내: 침대에서 걸어 나오면 사라진다.
	_prompt_wasd.visible = px < bx - NEAR
	# 구르기 안내: 잔해 앞에 다가오면 뜨고, 넘으면 사라진다.
	_prompt_roll.visible = px < bx and absf(px - bx) < NEAR
	# 🔴 구르는 동안만 잔해를 통과(평소엔 막힘). 부모가 자식(Player)보다 먼저 도니 이번 프레임 이동에 반영된다.
	_player.set_collision_mask_value(BARRIER_LAYER, not _player.is_rolling())

## 문에 닿으면 베이스로. body_entered는 플레이어(layer 2)만 온다(Door.mask=2).
func _on_door(body: Node2D) -> void:
	if _exited or body != _player:
		return
	_exited = true
	get_tree().change_scene_to_file(BASE_SCENE)
