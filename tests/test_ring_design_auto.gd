extends SceneTree
## 고리 도안(RingDesign) + 장착 배선 자동 검증 (#17 1단계, 세션 16) — 헤드리스:
##   ./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_ring_design_auto.gd
## 전 항목 통과 시 "TEST_RING_DESIGN_OK".
##
## 검증: (1) RingDesign.from_assembly↔to_assembly 라운드트립·filled_count,
##   (2) EventBus.ring_design_committed → GameState.ring_equipped 자동 장착(첫 진=슬롯 1),
##   (3) 빈 슬롯 소진(4장까지 장착, 5장째는 보관만).
##
## 주의: -s 스크립트는 오토로드 전역 등록 전에 컴파일 — 오토로드는 root.get_node(), RingDesign은 load().

var _fails: int = 0
var gs: Node      # GameState
var eb: Node      # EventBus
var RD: GDScript  # ring_design.gd


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		_fails += 1
		print("FAIL: ", label)


func _run() -> void:
	gs = root.get_node(^"GameState")
	eb = root.get_node(^"EventBus")
	RD = load("res://src/core/schemas/ring_design.gd")

	_test_roundtrip()
	_test_auto_equip()
	_test_slot_fill()

	if _fails == 0:
		print("TEST_RING_DESIGN_OK")
	else:
		print("TEST_RING_DESIGN_FAILED: ", _fails)
	quit(mini(_fails, 125))


## 타입 배열(Array[RingDesign])은 무형 리터럴로 재대입할 수 없다 — clear()·원소 대입으로 비운다.
func _reset_ring_state() -> void:
	gs.ring_designs.clear()
	for i in gs.ring_equipped.size():
		gs.ring_equipped[i] = null


## 기본 2방 문양본에 발산 하나 채운 assembly (rune=불).
func _sample_assembly() -> Dictionary:
	# 8칸: 칸0=발산(1), 칸2=응집(0), 나머지 빈칸(-1). 열린 칸 = [0, 2]
	var ring := [1, -1, 0, -1, -1, -1, -1, -1]
	return {"ring_count": 1, "rune": 0, "rings": [ring], "open": [0, 2]}


func _test_roundtrip() -> void:
	var a := _sample_assembly()
	var d = RD.from_assembly(a, "시험진", 0.82)
	_check(d != null, "from_assembly가 RingDesign을 만든다")
	_check(String(d.display_name) == "시험진", "이름 전달")
	_check(is_equal_approx(float(d.total_score), 0.82), "종합 점수 저장")
	_check(int(d.filled_count()) == 2, "채운 칸 수 = 2 (발산·응집)")
	var back: Dictionary = d.to_assembly()
	_check(int(back.get("ring_count", 0)) == 1, "to_assembly ring_count=1")
	_check(int(back.get("rune", -1)) == 0, "룬 보존(불)")
	_check((back.get("rings", []) as Array)[0] == a.rings[0], "rings 라운드트립 일치")
	_check((back.get("open", []) as Array) == [0, 2], "open 라운드트립 일치")
	# 깊은 복사 확인 — 원본을 바꿔도 도안이 안 흔들린다
	a.rings[0][0] = -1
	_check(int(d.to_assembly().rings[0][0]) == 1, "from_assembly는 깊은 복사(원본 변경 무관)")


func _test_auto_equip() -> void:
	_reset_ring_state()
	var d = RD.from_assembly(_sample_assembly(), "첫 진")
	eb.ring_design_committed.emit(d)
	_check(gs.ring_designs.size() == 1, "보관고에 들어간다")
	_check(gs.ring_equipped[0] == d, "빈 슬롯 없으면 슬롯 1(index 0)에 자동 장착")
	_check(gs.ring_equipped[1] == null, "나머지 슬롯은 빈 채")


func _test_slot_fill() -> void:
	_reset_ring_state()
	var made: Array = []
	for i in 5:
		var d = RD.from_assembly(_sample_assembly(), "진%d" % i)
		made.append(d)
		eb.ring_design_committed.emit(d)
	_check(gs.ring_designs.size() == 5, "5장 모두 보관")
	for slot in 4:
		_check(gs.ring_equipped[slot] == made[slot], "슬롯 %d에 순서대로 장착" % slot)
	_check(not (made[4] in gs.ring_equipped), "5장째는 슬롯이 꽉 차 장착 안 됨(보관만)")
