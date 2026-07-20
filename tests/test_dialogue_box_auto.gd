extends SceneTree
## 대사 상자(dialogue_box) 자동 검증 — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_dialogue_box_auto.gd
## 전 항목 통과 시 "TEST_DIALOGUE_OK" 출력 후 종료 코드 0.
##
## 🔴 헤드리스가 **잡을 수 있는** 것만 여기서 검증한다:
##   • 씬이 SCRIPT ERROR 없이 인스턴스된다
##   • open([]) → 즉시 finished, 안 보임 (빈 배열 계약)
##   • open([...]) → 보임·ui_modal_open=true·첫 줄 표시
##   • interact 액션으로 한 줄씩 넘어가고, 마지막에서 한 번 더 → finished 한 번·모달 해제·숨김
##   • ui_cancel(ESC) → 즉시 건너뛰기 finished·모달 해제
##   • speaker 인자 반영
## ⚠ **못 잡는 것**(리드가 실게임 push_input·MCP 스샷으로): 좌클릭이 밴드/화면에 닿아 진행되는가,
## 밴드가 실제로 하단에 렌더되는가, 열린 동안 mouse_filter STOP이 발사를 안 먹는가. 여기선
## 진행을 **액션 주입**으로만 몰아 로직만 본다(액션 주입은 mouse_filter 함정을 못 잡는다 — 세션 25).
##
## 주의: -s 모드는 오토로드 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지. load()·/root 지연.

var failures: int = 0
var _gs = null
var _fin_count: int = 0


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(20.0).timeout.connect(func() -> void:
		print("TEST_DIALOGUE_TIMEOUT — 20초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_gs = root.get_node("/root/GameState")
	var scene = load("res://src/hud/dialogue_box.tscn") as PackedScene
	_check(scene != null, "씬이 로드된다")

	var layer = scene.instantiate()
	root.add_child(layer)
	await process_frame

	var box = layer.get_node("Box")
	_check(box != null, "Box 노드가 있다")
	box.finished.connect(func() -> void: _fin_count += 1)

	var text_lbl = box.get_node("Band/Margin/VBox/Text")
	var speaker_lbl = box.get_node("Nameplate/Speaker")

	# ── 빈 배열: 즉시 finished, 안 보임, 모달 안 켜짐 ──
	_gs.ui_modal_open = false
	box.open([])
	await process_frame
	_check(_fin_count == 1, "빈 배열 → 즉시 finished 한 번")
	_check(box.visible == false, "빈 배열 → 안 보임")
	_check(_gs.ui_modal_open == false, "빈 배열 → 모달 안 켜짐")

	# ── 정상: 열림·모달·첫 줄 ──
	box.open(["첫 줄", "둘째 줄"])
	await process_frame
	_check(box.visible == true, "open → 보임")
	_check(_gs.ui_modal_open == true, "open → ui_modal_open=true")
	_check(text_lbl.text == "첫 줄", "open → 첫 줄 표시")
	_check(speaker_lbl.text == "길잡이", "기본 화자 = 길잡이")

	# ── interact 로 다음 줄 ──
	_push_action("interact")
	await process_frame
	_check(text_lbl.text == "둘째 줄", "interact → 둘째 줄")
	_check(box.visible == true, "마지막 전엔 안 닫힌다")
	_check(_fin_count == 1, "진행 중엔 finished 안 늘어난다")

	# ── 마지막에서 한 번 더 → 종료 ──
	_push_action("interact")
	await process_frame
	_check(_fin_count == 2, "마지막 줄 후 interact → finished")
	_check(box.visible == false, "종료 → 숨김")
	_check(_gs.ui_modal_open == false, "종료 → 모달 해제")

	# ── ESC 건너뛰기 ──
	box.open(["가", "나", "다"])
	await process_frame
	_check(box.visible == true and _gs.ui_modal_open == true, "다시 열림")
	_push_action("ui_cancel")
	await process_frame
	_check(_fin_count == 3, "ESC → 즉시 finished")
	_check(box.visible == false, "ESC → 숨김")
	_check(_gs.ui_modal_open == false, "ESC → 모달 해제")

	# ── speaker 인자 ──
	box.open(["안녕"], "노인")
	await process_frame
	_check(speaker_lbl.text == "노인", "speaker 인자 반영")
	box.open([])  # 정리(모달 해제 보장)
	await process_frame

	if failures == 0:
		print("TEST_DIALOGUE_OK")
		quit(0)
	else:
		print("TEST_DIALOGUE_FAIL — %d건" % failures)
		quit(1)


## 액션 이벤트를 뷰포트에 주입 → _unhandled_input의 is_action_pressed가 받는다.
## (키/액션은 렌더 없이도 도달한다 — 못 잡는 건 마우스 히트 테스트뿐이다.)
func _push_action(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	root.push_input(ev)


func _check(cond: bool, label: String) -> void:
	if not cond:
		failures += 1
		print("  FAIL: ", label)
