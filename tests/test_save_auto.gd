extends SceneTree
## 저장/로드 자동 검증 — 시드→저장→오염→로드→복원 확인.
## 실행: Godot --headless --path . -s res://tests/test_save_auto.gd
## 오토로드는 런타임 get_node로만 접근 (-s 컴파일 시점 미등록 함정).

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

func _run() -> void:
	await process_frame
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("Clock")
	var sm: Node = root.get_node("SaveManager")
	var rs := load("res://src/base/research_service.gd")

	# 클린 시작
	sm.wipe_save()
	_check("초기: 세이브 없음", not sm.has_save())
	_check("초기: 로드 false (새 게임)", not sm.load_game())

	# 시드
	gs.add_item(&"ink_basic", 5)
	gs.add_item(&"fragment_water", 1)
	gs.codex[&"rune_water"] = true
	gs.designs = SampleDesigns.all()
	gs.designs[0].durability = 7
	# v1.7 룬 농도 축 (TECH_SPEC §4.0) — 기본값(0.5)과 다른 값을 심어야 라운드트립이 실제로 검증된다
	gs.designs[0].rune_fill = 0.82
	gs.equip(0, gs.designs[0])
	gs.equip(2, gs.designs[2])
	gs.mana = 42.0
	clock.day = 3
	clock.time_sec = 123.0
	rs.current_id = &"rune_wind"
	rs.started_at_sec = 999.0

	sm.save_game()
	_check("저장: 파일 생성", sm.has_save())

	# 오염 (로드가 복원해야 함)
	gs.inventory.clear()
	gs.codex.erase(&"rune_water")
	gs.designs = [] as Array[SpellDesign]
	gs.equipped = [null, null, null, null] as Array[SpellDesign]
	gs.mana = 1.0
	clock.day = 1
	clock.time_sec = 0.0
	rs.current_id = &""
	rs.started_at_sec = -1.0

	_check("로드: true", sm.load_game())
	_check("복원: 잉크 5", gs.get_count(&"ink_basic") == 5)
	_check("복원: 조각 1", gs.get_count(&"fragment_water") == 1)
	_check("복원: 도감 rune_water", gs.is_unlocked(&"rune_water"))
	_check("복원: 도안 3종", gs.designs.size() == 3)
	_check("복원: 도안 내구 7 (라운드트립)", gs.designs.size() == 3 and gs.designs[0].durability == 7)
	_check("복원: 도안 화살표 보존", gs.designs.size() == 3 and gs.designs[0].arrows.size() == 8)
	_check("복원: 룬 농도 0.82 (v1.7 라운드트립)",
		gs.designs.size() == 3 and is_equal_approx(gs.designs[0].rune_fill, 0.82))
	_check("복원: 장착 0·2 매핑", gs.equipped[0] == gs.designs[0] and gs.equipped[2] == gs.designs[2] and gs.equipped[1] == null)
	_check("복원: 마나 42", is_equal_approx(gs.mana, 42.0))
	_check("복원: Day 3 · 123초", clock.day == 3 and is_equal_approx(clock.time_sec, 123.0))
	_check("복원: 연구 진행", rs.current_id == &"rune_wind" and is_equal_approx(rs.started_at_sec, 999.0))

	# 뒷정리 — 실제 플레이 세이브 오염 방지
	sm.wipe_save()
	_check("뒷정리: 세이브 삭제", not sm.has_save())

	print("RESULT pass=%d fail=%d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
