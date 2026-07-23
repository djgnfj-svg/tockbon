extends Node2D
## 🔴 세68 조립→탁본 슬라이스 **F6 시험대** — 손에 쥐고 실측한다(정본 목표).
##   조립(오른쪽 소켓에 문양-고리 끼움) → 왼쪽 판 손 트레이스 → [분석 ▶] → [마력 주입] →
##   맺으면 패널이 덮이고, 마우스=조준·좌클릭=발사(기존 ring_cast_requested 경로 재사용).
##   [E] = 패널 열고/덮기.
## base.tscn은 안 건드린다 — 라이브 = 옛 포지 유지.
##
## 실행(F6): tests/test_assembly_slice.tscn.

const PanelScene := preload("res://src/drawing/assembly_slice_panel.tscn")
const DummyScene := preload("res://src/spell/dummy_target.tscn")
const SpellScene := preload("res://src/spell/ring_spell_system.tscn")

## 발사 원점(왼쪽 발사대). 조준 = 마우스 − 원점.
const ORIGIN := Vector2(220, 360)

var _panel: Control = null
var _system: Node = null
var _assembly: Dictionary = {}


func _ready() -> void:
	_system = SpellScene.instantiate()
	add_child(_system)
	for pos: Vector2 in [Vector2(640, 200), Vector2(780, 360), Vector2(660, 490)]:
		var d := DummyScene.instantiate() as Node2D
		add_child(d)
		d.global_position = pos
	var layer := CanvasLayer.new()
	add_child(layer)
	_panel = PanelScene.instantiate()
	layer.add_child(_panel)
	_panel.committed.connect(_on_committed)
	_panel.open_panel()


func _on_committed(assembly: Dictionary) -> void:
	_assembly = assembly
	_panel.close_panel()


func _unhandled_input(event: InputEvent) -> void:
	if _panel.visible:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if _assembly.is_empty():
			return
		var aim := get_global_mouse_position() - ORIGIN
		if aim.length() < 1.0:
			aim = Vector2(1, 0)
		EventBus.ring_cast_requested.emit(_assembly, ORIGIN, aim.normalized())


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_E:
		if _panel.visible:
			_panel.close_panel()
		else:
			_panel.open_panel()
		queue_redraw()


func _draw() -> void:
	# 발사 원점 표시 (조준 가이드 — 절차 마커, 프롭 아님)
	draw_circle(ORIGIN, 8.0, Color(0.92, 0.86, 0.5, 0.85))
	draw_arc(ORIGIN, 13.0, 0.0, TAU, 20, Color(0.92, 0.86, 0.5, 0.4), 2.0, true)
