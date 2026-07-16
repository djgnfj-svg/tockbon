extends Node2D
## 베이스(허브) — 익스트랙션 루프의 귀환 지점.
## 책상에서 E를 누르면 **고리 조립 책**(진·룬·문양)이 베이스 위에 뜬다.
## 씬 전환 없음 — ESC로 닫으면 베이스가 그대로 뒤에 남는다.
## 원정(필드)은 아직 없음 — 지금은 베이스 + 탁본 책상까지만.
##
## 🔴 여기가 **게임의 진입점**이다 (project.godot run/main_scene, 사용자 확정 세션 21).
## 세션 22에 폴더가 `src/playground` → `src/base`로 바뀌었다 — "버려도 되는 실험"이라는
## 거짓 신호 때문에 리드가 세션 21에 엉뚱한 씬을 띄워 "다 사라졌다"고 헤맸다.
##
## 🔴 이 파일이 preload로 `ring_forge_panel`을 무는 건 **규칙 위반이 아니다** — 진입 씬 =
## 조합 루트이고 누군가는 모듈을 조립해야 한다. 결합도 얕다(open/design_committed/closed 3계약뿐,
## 보드 내부를 모른다).

const RingForgePanel := preload("res://src/drawing/ring_forge_panel.gd")
const Desk := preload("res://src/base/desk.gd")

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
