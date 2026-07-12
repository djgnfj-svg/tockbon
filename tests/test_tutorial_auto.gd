extends Node
## 튜토리얼(필사 수업) 자가 검증 — 드로잉 모듈 없이 EventBus 시그널 시뮬레이션만으로
## 발동 조건·단계 진행·완료 해금·스킵을 확인한다. 시그널 연결이 전부 동기이므로
## 프레임 대기 없이 _ready에서 순차 실행한다.
## 실행: Godot --headless --path . res://tests/test_tutorial.tscn --quit-after 120

const TutorialScene := preload("res://src/tutorial/tutorial.tscn")

var _passed := 0
var _failed := 0


func _ready() -> void:
	_scenario_a_already_done()
	_scenario_b_activation()
	_scenario_c_full_lesson()
	_scenario_c2_design_before_arrow()
	_scenario_d_skip()
	_finish()


func _spawn() -> CanvasLayer:
	var t := TutorialScene.instantiate() as CanvasLayer
	add_child(t)
	return t


func _reset_unlock() -> void:
	GameState.codex.erase(&"tutorial_done")


func _body(t: CanvasLayer) -> Label:
	return t.find_child("NoteBody", true, false) as Label


# ── (a) 이미 해금 → 완전 비활성

func _scenario_a_already_done() -> void:
	GameState.codex[&"tutorial_done"] = true
	var t := _spawn()
	_check(not t.visible, "(a) 해금 상태 → 시작부터 숨김")
	_check(t.get_node_or_null("Root") == null, "(a) 해금 상태 → UI 미생성")
	EventBus.scene_change_requested.emit(&"drawing")
	_check(not t.visible, "(a) 해금 상태 → 드로잉 진입에도 무반응")
	t.free()


# ── (b) 미해금 + 드로잉 진입 → 1단계 패널

func _scenario_b_activation() -> void:
	_reset_unlock()
	var t := _spawn()
	_check(not t.visible, "(b) 미해금 초기 상태 — 수업 전 숨김")
	EventBus.scene_change_requested.emit(&"base")
	_check(not t.visible, "(b) 드로잉 외 씬 진입 → 무반응")
	EventBus.scene_change_requested.emit(&"drawing")
	_check(t.visible, "(b) 드로잉 진입 → 수업 시작(패널 표시)")
	_check(_body(t).text.contains("원을 그려"), "(b) 1단계 안내 = 원(경계)")
	var skip := t.find_child("SkipButton", true, false) as Button
	_check(skip != null and skip.visible, "(b) 수업 중 스킵 버튼 표시")
	# 드로잉룸 이탈 → 패널 숨김, 재진입 → 같은 단계로 복귀
	EventBus.scene_change_requested.emit(&"base")
	_check(not t.visible, "(b) 드로잉 이탈 → 패널 숨김")
	EventBus.scene_change_requested.emit(&"drawing")
	_check(t.visible and _body(t).text.contains("원을 그려"), "(b) 재진입 → 1단계 유지")
	t.free()


# ── (c) 지시 순서: CIRCLE → RUNE → ARROW → design_created

func _scenario_c_full_lesson() -> void:
	_reset_unlock()
	var t := _spawn()
	EventBus.scene_change_requested.emit(&"drawing")
	EventBus.recognition_result.emit(Enums.StrokeRole.RUNE, false, 0.2)
	_check(_body(t).text.contains("원을 그려"), "(c) 미인식(matched=false) 획 → 단계 유지")
	EventBus.recognition_result.emit(Enums.StrokeRole.CIRCLE, true, 0.9)
	_check(_body(t).text.contains("불의 글자"), "(c) 원 인식 → 2단계(불 룬)")
	EventBus.recognition_result.emit(Enums.StrokeRole.RUNE, true, 0.85)
	_check(_body(t).text.contains("화살표"), "(c) 룬 인식 → 3단계(화살표)")
	EventBus.recognition_result.emit(Enums.StrokeRole.ARROW, true, 1.0)
	_check(not GameState.is_unlocked(&"tutorial_done"), "(c) design_created 전에는 미완료")
	_check(_body(t).text.contains("마무리"), "(c) 화살표 인식 → 4단계(도안 대기)")
	EventBus.design_created.emit(SpellDesign.new())
	_check(GameState.is_unlocked(&"tutorial_done"), "(c) design_created → codex에 tutorial_done 등록")
	_check(_body(t).text.contains("첫 도안"), "(c) 마무리 안내(출격 권유) 표시")
	var skip := t.find_child("SkipButton", true, false) as Button
	_check(not skip.visible, "(c) 완료 → 스킵 버튼 숨김")
	var close := t.find_child("CloseButton", true, false) as Button
	_check(close.visible, "(c) 완료 → 닫기 버튼 표시")
	close.pressed.emit()
	_check(not t.visible, "(c) 닫기 → 패널 숨김")
	EventBus.scene_change_requested.emit(&"drawing")
	_check(not t.visible, "(c) 완료 후 드로잉 재진입 → 재발동 없음")
	t.free()


# ── (c-2) 실제 drawing_canvas 순서: 마지막 획이 화살표면
#     design_created가 recognition_result(ARROW)보다 먼저 온다

func _scenario_c2_design_before_arrow() -> void:
	_reset_unlock()
	var t := _spawn()
	EventBus.scene_change_requested.emit(&"drawing")
	EventBus.recognition_result.emit(Enums.StrokeRole.CIRCLE, true, 0.9)
	EventBus.recognition_result.emit(Enums.StrokeRole.RUNE, true, 0.85)
	EventBus.design_created.emit(SpellDesign.new())
	_check(not GameState.is_unlocked(&"tutorial_done"),
		"(c-2) design 선착 — 화살표 인식 전에는 미완료")
	_check(_body(t).text.contains("화살표"), "(c-2) design 선착 — 3단계 유지")
	EventBus.recognition_result.emit(Enums.StrokeRole.ARROW, true, 1.0)
	_check(GameState.is_unlocked(&"tutorial_done"), "(c-2) 화살표 인식 → 곧바로 완료")
	_check(_body(t).text.contains("첫 도안"), "(c-2) 마무리 안내 표시")
	t.free()


# ── (d) 스킵 버튼 → 즉시 tutorial_done

func _scenario_d_skip() -> void:
	_reset_unlock()
	var t := _spawn()
	EventBus.scene_change_requested.emit(&"drawing")
	var skip := t.find_child("SkipButton", true, false) as Button
	skip.pressed.emit()
	_check(GameState.is_unlocked(&"tutorial_done"), "(d) 스킵 → 즉시 tutorial_done 해금")
	_check(not t.visible, "(d) 스킵 → 패널 숨김")
	EventBus.recognition_result.emit(Enums.StrokeRole.CIRCLE, true, 0.9)
	EventBus.design_created.emit(SpellDesign.new())
	_check(not t.visible, "(d) 스킵 후 시그널 → 무반응")
	t.free()


func _finish() -> void:
	print("TEST_TUTORIAL_DONE: pass=%d fail=%d" % [_passed, _failed])
	if _failed == 0:
		print("TEST_TUTORIAL_OK")
	else:
		print("TEST_TUTORIAL_FAILED")
	get_tree().quit.call_deferred()


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS: ", label)
	else:
		_failed += 1
		print("FAIL: ", label)
