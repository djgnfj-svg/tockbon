extends Node2D
## 베이스(허브) — 익스트랙션 루프의 귀환 지점.
## 책상에서 E를 누르면 **고리 조립 책**(진·룬·문양)이 베이스 위에 뜬다.
## 씬 전환 없음 — ESC로 닫으면 베이스가 그대로 뒤에 남는다.
## 원정(필드)은 아직 없음 — 지금은 베이스 + 탁본 책상까지만.
##
## 🔴 2026-07-17 세션 21 (사용자 확정): 여기가 **게임의 진입점**이다 (project.godot run/main_scene).
## 책상 UI = 고리 조립 책. 그 전에는 옛 자유 드로잉(drawing_panel: DrawingCanvas+ForgeBook =
## SpellDesign 모델)을 열어서, 확정된 고리 조립 모델이 **여기엔 없었다** — 띄우면 「문양을 칸에 삽입·
## 룬은 중심 원」이 사라진 것처럼 보였다.
## 같은 세션의 대청소로 옛 자유 드로잉 경로(drawing_panel·DrawingCanvas·ForgeBook·인식기)와
## 옛 본 게임(src/base 거점·field·ui·tutorial·quest)은 **삭제됐다** — 되돌리려면 git 이력을 본다.

const RingForgePanel := preload("res://src/drawing/ring_forge_panel.gd")
const Desk := preload("res://src/playground/desk.gd")

@onready var _desk: Desk = $Desk
@onready var _player: CharacterBody2D = $Player

var _overlay: CanvasLayer = null
var _forge: RingForgePanel = null

func _ready() -> void:
	_desk.interacted.connect(_open_drawing)

## 책상에서 E — 고리 조립 책을 편다. 이미 열려 있으면 무시.
func _open_drawing() -> void:
	if _overlay != null:
		return
	_player.set_physics_process(false)  # 조립하는 동안 이동 정지
	_overlay = CanvasLayer.new()
	_overlay.layer = 10
	add_child(_overlay)
	_forge = RingForgePanel.new()            # 기지 이젤과 같은 책 (진→룬→문양본→문양, 손으로 따라 그어 확정)
	_overlay.add_child(_forge)
	_forge.design_committed.connect(_on_ring_committed)
	_forge.closed.connect(_close_drawing)   # ESC(ui_cancel) → 패널이 closed 발신
	_forge.open()

## 고리 마법진이 맺혔다 — RingDesign으로 감싸 GameState에 넘긴다(빈 슬롯에 자동 장착).
func _on_ring_committed(assembly: Dictionary) -> void:
	var design := RingDesign.from_assembly(assembly, "고리 마법진")
	EventBus.ring_design_committed.emit(design)

func _close_drawing() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
		_forge = null
	_player.set_physics_process(true)
