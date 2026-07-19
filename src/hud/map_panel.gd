extends Control
## 재사용 원정 지도 패널 — 숲을 위에서 내려다본 도식을 그리고, 지도를 클릭해 목표 마커를 찍는다.
## **지도 내용을 모른다**(data Dictionary를 받는 범용). 실제 숲 배선(M키·월드 핀·화살표)은 리드가 한다.
## 이 컴포넌트는 데이터를 받아 그리고, 클릭을 월드 좌표로 역변환해 시그널로 넘긴다.
##
## 🔴 **모달 규약은 dialogue_box / tab_panel과 같다**(그 둘이 참고 원본):
##  · 열리면 mouse_filter=STOP → 좌클릭을 통째로 먹어 지도를 보며 실수로 안 쏜다(그 클릭이 마커가 된다).
##  · 닫히면 visible=false → GUI 히트테스트에서 빠져 클릭이 다시 바닥(발사·이동)으로 샌다.
##  · 열림/닫힘에 GameState.ui_modal_open을 토글 → player(이동)·caster(조준·발사)가 폴링해 멎는다.
##  · 닫힌 Control도 _unhandled_input은 받는다(mouse_filter는 마우스만 가른다) → 모든 핸들러를
##    `if not _open: return`으로 가둔다(닫힌 지도가 M/ESC를 훔치면 안 된다).
##
## 🔴 **mouse_filter 함정**(세션25): 화면을 덮는 이 루트가 열린 동안 STOP이라 좌클릭을 먹는다 —
## 지도 클릭이 곧 마커다. 닫히면 visible=false라 히트테스트에서 빠져 발사·이동이 되살아난다.
## ⚠ 헤드리스는 클릭·렌더를 못 잡는다 — 리드가 실게임 push_input(클릭 도달)·MCP 스샷(렌더)으로 확인.
##
## 🔴 **CanvasLayer(layer 8) 위에 산다**(map_panel.tscn) — 카메라가 플레이어를 따라다녀 월드에
## 그리면 지도가 흘러간다(HUD·dialogue_box와 같은 이유). 책(forge, layer 10)보다 아래.
##
## 🔴 **좌표 변환이 핵심** — 마커가 엉뚱한 데 찍히면 무용지물. world_to_map / map_to_world 왕복이
## 정확해야 한다(test_map_panel_auto가 뮤테이션까지 넣어 검증). 두 함수는 map_rect()·_bounds를 공유
## 단일 소스로 봐서 어긋나지 않는다.

## 지도 위 좌클릭 → 그 지점을 **월드 좌표로 역변환**해 emit. 🔴 place-and-stay: 찍어도 안 닫고
## 마커를 즉시 그려 보여 준다. 지도 밖(도식 rect 바깥) 클릭은 무시(emit 안 함).
signal marker_placed(world_pos: Vector2)
## M(map 액션) 또는 ESC(ui_cancel)로 닫힐 때 정확히 한 번 emit.
signal closed

# ── 레이아웃 (연출값 — 밸런스 아님. 선례: tab_panel의 PANEL_SIZE 등) ──
const MAP_SIZE := Vector2(480.0, 360.0)   # 화면 중앙 지도 도식 크기
const TITLE_H := 34.0                       # 지도 위 제목 줄 높이
const FOOTER_H := 22.0                      # 지도 아래 안내 줄 높이

# ── 색 (한지·먹 톤 — tab_panel 팔레트 계열) ──
const BACKDROP := Color(0.03, 0.025, 0.02, 0.82)   # 화면 전체 어둡게
const MAP_BG := Color(0.10, 0.09, 0.07, 0.96)       # 지도 바탕(반투명 먹)
const MAP_EDGE := Color(0.48, 0.43, 0.34, 0.95)     # 지도 테두리
const BOUND_EDGE := Color(0.40, 0.37, 0.30, 0.85)   # 숲 경계 사각
const TITLE_COLOR := Color(0.96, 0.90, 0.78)
const HINT_COLOR := Color(0.66, 0.62, 0.54)
const LEGEND_COLOR := Color(0.70, 0.66, 0.58)

const PLAYER_COLOR := Color(0.62, 0.86, 0.99)   # 내 위치 — 밝은 청
const ENEMY_COLOR := Color(0.90, 0.36, 0.32)    # 적 — 붉은
const EXTRACT_COLOR := Color(0.55, 0.82, 0.50)  # 귀환점 — 녹
const MARKER_COLOR := Color(0.98, 0.82, 0.34)   # 마커 핀 — 금/노랑
const DOT_OUTLINE := Color(0.05, 0.04, 0.03, 0.9)

const PLAYER_R := 6.0
const ENEMY_R := 4.0
const EXTRACT_R := 5.0
const MARKER_R := 5.0

var _open: bool = false
var _bounds: Rect2 = Rect2()
var _player: Vector2 = Vector2.ZERO
var _enemies: Array = []
var _extract: Vector2 = Vector2.ZERO
var _has_extract: bool = false
var _marker: Vector2 = Vector2.ZERO
var _has_marker: bool = false


func _ready() -> void:
	# 닫힌 동안엔 클릭을 먹지 않는다(visible=false면 GUI 히트테스트에서 빠진다).
	# 열리면 STOP이라 좌클릭을 통째로 먹어 지도 클릭이 곧 마커가 된다.
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


# ─────────────────────────── 공개 API (리드가 배선) ───────────────────────────

## 지도를 띄운다(모달). data 키:
##  "bounds"(Rect2, 숲 월드 범위) · "player"(Vector2) · "enemies"(Array of Vector2 스냅샷) ·
##  "extract"(Vector2, 귀환점) · "marker"(Vector2 또는 null, 이미 찍힌 마커).
## 누락 키는 안전한 기본값으로 처리한다(호출부가 특수 처리 안 해도 된다).
func open(data: Dictionary) -> void:
	_bounds = data.get("bounds", Rect2()) as Rect2
	_player = data.get("player", Vector2.ZERO) as Vector2
	_enemies = data.get("enemies", []) as Array
	if data.has("extract") and data["extract"] != null:
		_extract = data["extract"] as Vector2
		_has_extract = true
	else:
		_has_extract = false
	if data.has("marker") and data["marker"] != null:
		_marker = data["marker"] as Vector2
		_has_marker = true
	else:
		_has_marker = false
	_open = true
	visible = true
	GameState.ui_modal_open = true
	queue_redraw()


## 지도가 열려 있나 (리드가 M 토글을 배선할 때 참고).
func is_open() -> bool:
	return _open


# ─────────────────────────── 좌표 변환 (단일 소스) ───────────────────────────

## 화면 중앙에 놓인 지도 도식 rect(Control 로컬 좌표). _draw·world_to_map·map_to_world·클릭
## 히트테스트가 모두 이 하나를 봐서 그린 것과 누른 곳이 어긋나지 않는다.
func map_rect() -> Rect2:
	var pos := ((size - MAP_SIZE) * 0.5).round()
	return Rect2(pos, MAP_SIZE)


## 월드 좌표 → 지도 rect 안의 화면 좌표. bounds가 0폭이면 그 축은 0으로 접는다(0나눗셈 방지).
func world_to_map(world: Vector2) -> Vector2:
	var mr := map_rect()
	var bs := _bounds.size
	var nx := 0.0 if bs.x == 0.0 else (world.x - _bounds.position.x) / bs.x
	var ny := 0.0 if bs.y == 0.0 else (world.y - _bounds.position.y) / bs.y
	return mr.position + Vector2(nx, ny) * mr.size


## 지도 rect 안의 화면 좌표(로컬) → 월드 좌표. world_to_map의 역변환(왕복이 정확해야 한다).
func map_to_world(local: Vector2) -> Vector2:
	var mr := map_rect()
	var nx := 0.0 if mr.size.x == 0.0 else (local.x - mr.position.x) / mr.size.x
	var ny := 0.0 if mr.size.y == 0.0 else (local.y - mr.position.y) / mr.size.y
	return _bounds.position + Vector2(nx, ny) * _bounds.size


# ─────────────────────────── 입력 ───────────────────────────

## 지도 rect 안 좌클릭 = 마커 찍기(역변환해 월드 좌표로 emit). root가 STOP이라 마우스가 여기로 온다.
## 🔴 지도 밖 클릭은 무시(도식 rect 바깥 = 지도가 아니다). place-and-stay: 마커를 즉시 그린다.
func _gui_input(event: InputEvent) -> void:
	if not _open:
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if not map_rect().has_point(mb.position):
		return   # 지도 밖 클릭 — 무시
	var world := map_to_world(mb.position)
	_marker = world
	_has_marker = true
	queue_redraw()
	marker_placed.emit(world)
	accept_event()


## M(map 액션) / ESC(ui_cancel)로 닫는다. 닫힌 Control도 _unhandled_input을 받으므로 _open 가드.
## ⚠ map 액션은 리드가 project.godot에 추가한다 — 없으면 InputMap.has_action 가드로 조용히 건너뛴다.
func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	var want_close := event.is_action_pressed("ui_cancel")
	if not want_close and InputMap.has_action("map") and event.is_action_pressed("map"):
		want_close = true
	if want_close:
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	GameState.ui_modal_open = false
	closed.emit()


# ─────────────────────────── 그리기 ───────────────────────────

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP, true)

	var mr := map_rect()
	# 지도 바탕 + 테두리
	draw_rect(mr, MAP_BG, true)
	draw_rect(mr, MAP_EDGE, false, 2.0)

	# 제목 (지도 위)
	draw_string(font, Vector2(mr.position.x, mr.position.y - TITLE_H + 22.0), "숲 지도",
		HORIZONTAL_ALIGNMENT_LEFT, MAP_SIZE.x, 18, TITLE_COLOR)

	# 숲 경계 사각 — bounds 전체를 지도 rect 안쪽 테두리로(살짝 안으로 여백).
	var inset := 4.0
	draw_rect(Rect2(mr.position + Vector2(inset, inset),
		mr.size - Vector2(inset * 2.0, inset * 2.0)), BOUND_EDGE, false, 1.0)

	# 귀환점 (녹)
	if _has_extract:
		_draw_dot(_clamped(world_to_map(_extract), mr), EXTRACT_R, EXTRACT_COLOR)

	# 적들 (붉은)
	for e: Variant in _enemies:
		if e is Vector2:
			_draw_dot(_clamped(world_to_map(e as Vector2), mr), ENEMY_R, ENEMY_COLOR)

	# 내 위치 (밝은 청, 조금 크게)
	_draw_dot(_clamped(world_to_map(_player), mr), PLAYER_R, PLAYER_COLOR)

	# 마커 핀 (금/노랑) — 있을 때만
	if _has_marker:
		_draw_marker(_clamped(world_to_map(_marker), mr))

	# 안내 (지도 아래)
	draw_string(font, Vector2(mr.position.x, mr.end.y + FOOTER_H - 6.0),
		"지도를 클릭해 목표 지점 표시    [M] / [ESC]  닫기",
		HORIZONTAL_ALIGNMENT_LEFT, MAP_SIZE.x, 12, HINT_COLOR)

	# 범례 (지도 아래 오른쪽)
	draw_string(font, Vector2(mr.position.x, mr.end.y + FOOTER_H + 12.0),
		"● 나   ● 적   ● 귀환   ● 목표",
		HORIZONTAL_ALIGNMENT_LEFT, MAP_SIZE.x, 11, LEGEND_COLOR)


## 점 하나 — 어두운 외곽선 위에 색 채움(작은 도식이라 외곽선으로 배경과 분리).
func _draw_dot(at: Vector2, radius: float, color: Color) -> void:
	draw_circle(at, radius + 1.5, DOT_OUTLINE)
	draw_circle(at, radius, color)


## 마커 핀 — 채운 원 + 아래로 뾰족한 삼각(핀 모양)으로 "찍은 곳"을 강조.
func _draw_marker(at: Vector2) -> void:
	var tip := at + Vector2(0.0, MARKER_R + 7.0)
	var pts := PackedVector2Array([
		at + Vector2(-MARKER_R, 0.0),
		at + Vector2(MARKER_R, 0.0),
		tip,
	])
	draw_colored_polygon(pts, MARKER_COLOR)
	draw_circle(at, MARKER_R + 1.5, DOT_OUTLINE)
	draw_circle(at, MARKER_R, MARKER_COLOR)


## 스냅샷 좌표가 bounds 밖일 수 있어(추격 중 적이 경계 밖으로) 지도 rect 안으로 clamp해 밖으로 안 그린다.
func _clamped(pt: Vector2, mr: Rect2) -> Vector2:
	return Vector2(
		clampf(pt.x, mr.position.x, mr.end.x),
		clampf(pt.y, mr.position.y, mr.end.y))
