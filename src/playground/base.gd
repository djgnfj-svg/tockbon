extends Node2D
## 베이스(허브) — 익스트랙션 루프의 귀환 지점.
## 책상에서 E를 누르면 그리기 오버레이(왼쪽 종이 / 오른쪽 진·룬·문양)가 베이스 위에 뜬다.
## 씬 전환 없음 — ESC로 닫으면 베이스가 그대로 뒤에 남는다.
## 원정(필드)은 아직 없음 — 지금은 베이스 + 탁본 책상까지만.

const DrawingPanel := preload("res://src/playground/drawing_panel.tscn")

@onready var _desk = $Desk
@onready var _player: CharacterBody2D = $Player

var _overlay: CanvasLayer = null

func _ready() -> void:
	_desk.interacted.connect(_open_drawing)

## 책상에서 E — 그리기 오버레이를 연다. 이미 열려 있으면 무시.
func _open_drawing() -> void:
	if _overlay != null:
		return
	_player.set_physics_process(false)  # 그리는 동안 이동 정지
	_overlay = CanvasLayer.new()
	_overlay.layer = 10
	add_child(_overlay)
	var panel := DrawingPanel.instantiate()  # 씬으로 재구성한 그리기 UI (960×540, 에디터 편집 가능)
	_overlay.add_child(panel)                # _ready에서 슬롯에 엔진 위젯이 얹힌다
	panel.set_ink_unlimited(true)            # 샌드박스 — 잉크 경제 없이 '그리는 손맛'만 먼저 본다
	panel.closed.connect(_close_drawing)     # ESC(ui_cancel) → 패널이 closed 발신
	panel.open()

func _close_drawing() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	_player.set_physics_process(true)
