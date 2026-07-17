extends Node2D
## 베이스(허브) — 익스트랙션 루프의 귀환 지점.
## 책상에서 E를 누르면 **고리 조립 책**(진·룬·문양)이 베이스 위에 뜬다.
## 씬 전환 없음 — ESC로 닫으면 베이스가 그대로 뒤에 남는다.
## 원정(필드)은 아직 없음 — 지금은 베이스 + 탁본 책상 + **연습장(허수아비)**까지.
##
## 🔴 여기가 **게임의 진입점**이다 (project.godot run/main_scene, 사용자 확정 세션 21).
## 세션 22에 폴더가 `src/playground` → `src/base`로 바뀌었다 — "버려도 되는 실험"이라는
## 거짓 신호 때문에 리드가 세션 21에 엉뚱한 씬을 띄워 "다 사라졌다"고 헤맸다.
##
## 🔴 M1 (세션 22): 책을 preload가 아니라 **@export로 받는다** — 진입 씬은 조합 루트라 모듈을
## 조립하는 게 정당했지만(그래서 preload도 위반은 아니었다), 씬을 인스펙터에서 갈아 끼울 수 있으면
## 규칙 논쟁 자체가 사라진다. 계약은 여전히 셋뿐: open() / design_committed / closed.
##
## 🔴 세션 24: **그린 마법진을 여기서 쏜다.** 그전엔 잘 그려 위력을 올려도 확인할 데가 시험대뿐이라,
## 본 게임에서는 손그림 점수가 **보이지 않는 숫자**였다. 이제 책상 옆이 연습장(허수아비)이다.
##
## 씬(base.tscn) 쪽 결정 — .tscn엔 주석을 못 달아서 여기 적는다:
##  • `RingSpellSystem`은 **@export가 아니라 씬에 직접 인스턴스**로 놨다. 책(forge_scene)과 달리
##    이 스크립트는 발사 시스템을 **한 번도 참조하지 않는다** — EventBus.ring_cast_requested로만
##    말한다. 참조가 없으니 갈아 끼울 @export 구멍도 필요 없다(있으면 안 쓰는 필드만 는다).
##  • `RingSpellSystem.z_index = 10` — 안 올리면 날아가는 진·탄·기둥이 Ground(ColorRect, z=0) **뒤에
##    가려 안 보인다**. 시험대가 같은 함정을 세션 13에 밟았다.
##  • 허수아비 5개는 전부 플레이어 시작점에서 **사거리 안**(≈390px = 260px/s × 1.5s, balance)에 있다.
##    더 멀리 두면 걸어가서 쏘기 전엔 안 닿아 연습장이 장식이 된다 (tests/test_base_auto가 못 박는다).
##  • Player = 레이어 2(player) / Desk = 레이어 64(interaction). 🔴 둘 다 기본 레이어 1(**world**)에
##    있었는데, 캐리어 마스크가 5(world+enemy)라 **쏘는 순간 내 몸에 부딪혀 총구에서 죽었다**
##    (책상 쪽으로 쏘면 책상에서). 레이어 이름표(project.godot)대로 옮겨서 푼 것이다.
##    Desk의 마스크는 2 — 플레이어를 감지해야 "[E] 탁본"이 뜬다.

const RingForgePanelScript := preload("res://src/drawing/ring_forge_panel.gd")
const Desk := preload("res://src/base/desk.gd")
const BaseHud := preload("res://src/base/base_hud.gd")
## 🔴 위력 표시는 여기서 계산하지 않는다 — 리포트·발사·HUD가 **같은 함수**를 본다 (core에 있는 이유).
const RingPower := preload("res://src/core/ring_power.gd")

## 책상에서 펴는 책 (base.tscn이 ring_forge_panel.tscn을 물려 준다).
@export var forge_scene: PackedScene = preload("res://src/drawing/ring_forge_panel.tscn")

## 조준선 길이 (연출값 — 밸런스 아님).
const AIM_FROM := 14.0
const AIM_TO := 34.0
const AIM_ARMED := Color(0.95, 0.65, 0.25, 0.85)
const AIM_EMPTY := Color(0.6, 0.6, 0.6, 0.35)

@onready var _desk: Desk = $Desk
@onready var _player: CharacterBody2D = $Player
@onready var _aim_node: Node2D = $Player/Aim   # 조준선만 그리는 빈 노드 (플레이어 로컬 좌표)
@onready var _hud: BaseHud = $Hud/BaseHud

var _overlay: CanvasLayer = null
var _forge: RingForgePanelScript = null

var _aim := Vector2.RIGHT
var _slot: int = 0        # 지금 고른 장착 슬롯 (1~4 키)

func _ready() -> void:
	_desk.interacted.connect(_open_drawing)
	_aim_node.draw.connect(_draw_aim)
	_hud.select(_slot)

# ─────────────────────────── 조준 · 발사 ───────────────────────────

## 책이 펼쳐져 있는 동안은 베이스가 조작을 받지 않는다 (조준·발사·슬롯 전부).
## `_forge`로 본다 — `is_open()`은 덮는 애니가 끝날 때까지 참이라, 그동안 클릭이 새어 나가면
## 책을 덮는 클릭이 그대로 발사가 된다.
func _is_book_open() -> bool:
	return _forge != null

func _process(_delta: float) -> void:
	if _is_book_open():
		return
	var to_mouse := get_global_mouse_position() - _player.global_position
	if to_mouse.length_squared() > 1.0:
		_aim = to_mouse.normalized()
	_aim_node.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if _is_book_open():
		return
	for i in GameState.EQUIP_SLOTS:
		if event.is_action_pressed(StringName("cast_slot_%d" % (i + 1))):
			_select_slot(i)
			get_viewport().set_input_as_handled()
			return
	# 🔴 발사는 **좌클릭만**이다 (사용자 확정). Space는 발사가 아니다 —
	# 시험대(test_ring_forge_panel)가 Space도 받는 건 시험대 사정이고 본 게임은 아니다.
	# Space를 다른 용도로 임의 배정하지도 마라: 그건 사용자가 정할 몫이다.
	if event.is_action_pressed(&"attack_basic"):
		_fire()
		get_viewport().set_input_as_handled()

func _select_slot(slot: int) -> void:
	_slot = slot
	_hud.select(slot)
	var design: RingDesign = GameState.ring_equipped[slot]
	if design == null:
		_hud.say("슬롯 %d — 비어 있다. 책상에서 E로 마법진을 그려 채워라" % (slot + 1))
	else:
		_hud.say("슬롯 %d — %s (위력 %d)" % [slot + 1, design.display_name,
			RingPower.power_display(design.total_score)])
	_aim_node.queue_redraw()

## 🔴 `to_assembly()`로 쏜다 — 그래야 `assembly.score`(손그림 점수)가 실려 **그때 그린 위력이 그대로
## 난다**. 직접 Dictionary를 만들면 score가 빠져 조용히 기준 위력으로 발사된다 (ring_design.gd 주석).
func _fire() -> void:
	var design: RingDesign = GameState.ring_equipped[_slot]
	if design == null:
		_hud.say("슬롯 %d이 비어 있다 — 1~4로 다른 슬롯을 고르거나 책상에서 E" % (_slot + 1), true)
		return
	EventBus.ring_cast_requested.emit(design.to_assembly(), _player.global_position, _aim)

## 조준선 — 장착됐으면 불빛, 빈 슬롯이면 흐리게. 쏘기 전에 슬롯 상태가 손끝에서 보인다.
func _draw_aim() -> void:
	var armed := GameState.ring_equipped[_slot] != null
	_aim_node.draw_line(_aim * AIM_FROM, _aim * AIM_TO,
		AIM_ARMED if armed else AIM_EMPTY, 2.0)

# ─────────────────────────── 고리 조립 책 ───────────────────────────

## 책상에서 E — 고리 조립 책을 편다. 이미 열려 있으면 무시.
func _open_drawing() -> void:
	if _overlay != null:
		return
	_player.set_physics_process(false)  # 조립하는 동안 이동 정지
	_overlay = CanvasLayer.new()
	_overlay.layer = 10
	add_child(_overlay)
	_forge = forge_scene.instantiate() as RingForgePanelScript   # 진→룬→문양본→문양, 손으로 따라 그어 확정
	if _forge == null:
		push_error("forge_scene이 RingForgePanel이 아니다")
		return
	_overlay.add_child(_forge)
	_forge.design_committed.connect(_on_ring_committed)
	_forge.commit_rejected.connect(_on_ring_rejected)
	_forge.closed.connect(_close_drawing)   # ESC(ui_cancel) → 패널이 closed 발신
	_forge.open()

## 고리 마법진이 맺혔다 — RingDesign으로 감싸 GameState에 넘긴다(빈 슬롯에 자동 장착).
## 🔴 손그림 점수는 `assembly.score`를 타고 들어와 `total_score`가 된다 (세션 23).
## 세션 22까지 여기가 점수를 안 넘겨서 **저장된 도안의 total_score가 전부 0**이었다.
func _on_ring_committed(assembly: Dictionary) -> void:
	var design := RingDesign.from_assembly(assembly, "고리 마법진")
	EventBus.ring_design_committed.emit(design)

## 🔴 책을 덮었는데 **점수 미달로 안 맺혔다** (세션 25). 슬롯이 조용히 빈 채로 남으면
## "맺었는데 안 나간다"가 된다 — 사용자가 실제로 겪었고, 화면 어디에도 이유가 없었다.
func _on_ring_rejected(score: float) -> void:
	_hud.say("마법진이 안 맺혔다 — 종합 %d점 (%d점을 넘겨야 견딘다). 책상에서 E로 다시 그려라"
		% [RingPower.score_display(score), RingPower.score_display(RingPower.threshold())], true)

func _close_drawing() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
		_forge = null
	_player.set_physics_process(true)
