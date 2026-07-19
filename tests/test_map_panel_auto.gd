extends SceneTree
## 원정 지도 패널 자동 검증 — 세션 후속(원정 지도).
## 실행: Godot --headless --path . -s res://tests/test_map_panel_auto.gd
## 오토로드는 런타임 get_node로만 접근 (-s 컴파일 시점 미등록 함정). 씬/스크립트는 load()로 지연 로드.
##
## 🔴 헤드리스가 못 잡는 것(리드가 실게임으로): 지도가 화면에 보이나(MCP 스샷) · 실제 좌클릭이 지도에
##  닿아 마커가 찍히나(push_input — _gui_input을 직접 부르는 이 테스트는 Control 히트테스트를 우회한다) ·
##  닫힌 뒤 mouse_filter가 발사/이동을 다시 통과시키나. 아래는 좌표 왕복·모달 배선·빈/마커 data만 잡는다.
## 🔴 뮤테이션 검출력: world_to_map/map_to_world의 공식(오프셋·나눗셈)을 되돌리면 ②③의 코너·왕복이
##  빨개진다 — 초록불이 실제로 변환을 지키는지 확인했다.

var _pass := 0
var _fail := 0

func _init() -> void:
	_run.call_deferred()

func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("PASS: ", label)
	else:
		_fail += 1
		print("FAIL: ", label)

func _approx(a: Vector2, b: Vector2, eps: float = 0.01) -> bool:
	return absf(a.x - b.x) <= eps and absf(a.y - b.y) <= eps

func _run() -> void:
	await process_frame
	var gs: Node = root.get_node("GameState")

	var scene: PackedScene = load("res://src/hud/map_panel.tscn")
	var layer: Node = scene.instantiate()
	root.add_child(layer)
	var panel: Control = layer.get_node("Panel")
	# 헤드리스에서 레이아웃이 흔들리지 않게 크기를 못박는다(map_rect는 size를 본다).
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size = Vector2(960.0, 540.0)
	await process_frame

	var bounds := Rect2(-1200.0, -1000.0, 2400.0, 1900.0)
	var data := {
		"bounds": bounds,
		"player": Vector2(0.0, 0.0),
		"enemies": [Vector2(300.0, -400.0), Vector2(-800.0, 600.0)],
		"extract": Vector2(0.0, 800.0),
		"marker": null,
	}

	# ── ① 열기 = 모달 배선 (visible·ui_modal_open) ──
	gs.ui_modal_open = false
	panel.open(data)
	_check("open 후 visible=true", panel.visible)
	_check("open 후 GameState.ui_modal_open=true", gs.ui_modal_open == true)
	_check("is_open()=true", panel.is_open())

	# ── ② 좌표 왕복 (world→map→world ≈ 원본) — 뮤테이션 검출력의 핵심 ──
	var samples := [
		bounds.position,                          # 좌상단 코너
		bounds.end,                               # 우하단 코너
		bounds.get_center(),                      # 중앙
		Vector2(300.0, -400.0),                   # 임의 내부점
		Vector2(-800.0, 600.0),
	]
	var round_ok := true
	for w: Vector2 in samples:
		var back: Vector2 = panel.map_to_world(panel.world_to_map(w))
		if not _approx(back, w):
			round_ok = false
			print("  왕복 어긋남: ", w, " → ", back)
	_check("🔴 좌표 왕복 정확 (world→map→world ≈ 원본, 5점)", round_ok)

	# 코너·중앙이 지도 rect의 코너·중앙에 정확히 매핑 (공식이 오프셋/스케일을 지키는지)
	var mr: Rect2 = panel.map_rect()
	_check("🔴 bounds 좌상단 → 지도 rect 좌상단", _approx(panel.world_to_map(bounds.position), mr.position, 0.5))
	_check("🔴 bounds 우하단 → 지도 rect 우하단", _approx(panel.world_to_map(bounds.end), mr.end, 0.5))
	_check("🔴 bounds 중앙 → 지도 rect 중앙", _approx(panel.world_to_map(bounds.get_center()), mr.get_center(), 0.5))

	# ── ③ 클릭 → 마커 (역변환 emit + place-and-stay) ──
	var got: Array = []
	panel.marker_placed.connect(func(wp: Vector2) -> void: got.append(wp))

	# 지도 중앙 클릭 → 월드 bounds 중앙이 나와야 한다.
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = mr.get_center()
	panel._gui_input(ev)
	_check("🔴 지도 중앙 좌클릭 → marker_placed 1회", got.size() == 1)
	if got.size() == 1:
		_check("🔴 찍힌 마커 = 월드 bounds 중앙 (역변환 정확)", _approx(got[0], bounds.get_center(), 0.5))

	# 지도 밖 클릭 → 무시 (도식 rect 바깥)
	var ev_out := InputEventMouseButton.new()
	ev_out.button_index = MOUSE_BUTTON_LEFT
	ev_out.pressed = true
	ev_out.position = Vector2(4.0, 4.0)   # 중앙 480×360 지도 바깥(좌상단 여백)
	panel._gui_input(ev_out)
	_check("🔴 지도 밖 좌클릭 = 무시 (emit 없음)", got.size() == 1)

	# ── ④ 닫기 (ui_cancel) = 모달 해제 + closed ──
	var closed_count := [0]
	panel.closed.connect(func() -> void: closed_count[0] += 1)
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	panel._unhandled_input(cancel)
	_check("🔴 ESC(ui_cancel) → closed 1회", closed_count[0] == 1)
	_check("🔴 닫으면 visible=false", not panel.visible)
	_check("🔴 닫으면 GameState.ui_modal_open=false", gs.ui_modal_open == false)
	# 닫힌 뒤 입력 가드 — 다시 눌러도 아무 일 없다(닫힌 지도가 ESC를 훔치지 않는다)
	panel._unhandled_input(cancel)
	_check("🔴 닫힌 상태에서 다시 ESC → closed 재발신 안 함", closed_count[0] == 1)

	# ── ⑤ 빈 data / 마커 있는 data 둘 다 에러 없이 뜬다 ──
	panel.open({})   # 모든 키 누락
	_check("빈 data로 open — 에러 없이 visible=true", panel.visible)
	panel._unhandled_input(cancel)

	var data_marked := {
		"bounds": bounds,
		"player": Vector2(100.0, 100.0),
		"enemies": [],
		"extract": Vector2(0.0, 800.0),
		"marker": Vector2(500.0, 500.0),   # 이미 찍힌 마커
	}
	panel.open(data_marked)
	_check("마커 포함 data로 open — 에러 없이 visible=true", panel.visible)
	# 이미 찍힌 마커도 지도 안에 매핑되는지(왕복)
	_check("기존 마커 왕복 정확", _approx(panel.map_to_world(panel.world_to_map(Vector2(500.0, 500.0))), Vector2(500.0, 500.0)))
	panel._unhandled_input(cancel)

	gs.ui_modal_open = false
	print("RESULT pass=%d fail=%d" % [_pass, _fail])
	if _fail == 0:
		print("TEST_MAP_PANEL_OK — 전 항목 통과")
	quit()
