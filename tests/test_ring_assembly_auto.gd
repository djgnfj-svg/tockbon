extends SceneTree
## 🔴 고리 **조립 상태기계** 계약 검증 (세션 22) — 헤드리스 실행:
##   ./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_ring_assembly_auto.gd
## 전 항목 통과 시 "TEST_RING_ASSEMBLY_OK" 출력 후 종료 코드 0.
##
## 🔴 **왜 따로 있나** (docs/REFACTOR_PLAN.md C4): test_ring_trace_auto는 **추적·점수 중심**이고
## 조립 상태기계(단계 전이·문양본이 칸을 여는 규칙·assembly 계약)를 검증하지 않는다.
## ring_board(757줄)를 ring_assembly/trace_scorer/ring_board로 쪼개기 **전에** 이 계약을 못 박아,
## 쪼개다 조용히 깨지는 걸 잡는다.
##
## 여기 있는 건 전부 **public API 계약**이다 — 분할 전후 **양쪽 모두** 통과해야 한다.
## 내부 필드(_slots 등)를 더듬지 않는다: 그건 쪼개면 옮겨 다니는 물건이라 계약이 아니다.
##
## 주의: -s 모드는 오토로드보다 먼저 컴파일 — 오토로드 식별자·모듈 preload 금지. 첫 프레임 후 load().

const G_GATHER := 0
const G_RADIATE := 1
const GLYPH_NONE := -1
const SLOTS := 8

var failures: int = 0
var _BoardScript = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(15.0).timeout.connect(func() -> void:
		print("TEST_RING_ASSEMBLY_TIMEOUT — 15초 초과")
		quit(1))
	await process_frame

	_BoardScript = load("res://src/drawing/ring_board.gd")

	_test_initial_state()
	_test_stage_transitions()
	_test_can_commit_gate()
	_test_template_opens_slots()
	_test_template_closes_and_clears()
	_test_template_filters_garbage()
	_test_assembly_shape()
	_test_assembly_records_glyphs()
	_test_clear_all_resets()
	_test_signals()
	_test_finish_without_glyphs()

	if failures == 0:
		print("TEST_RING_ASSEMBLY_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_RING_ASSEMBLY_FAIL — %d개 실패" % failures)
		quit(1)


func _make_board():
	var b = _BoardScript.new()
	b.size = Vector2(268, 268)
	root.add_child(b)
	b.call(&"clear_all")
	return b


## 지금 가이드 위를 정확히 문지른다 — 조각을 잠글 수 있는 상태로 만든다.
## 🔴 세션 25: 진·룬은 **골라야** 밑그림이 뜬다 (사용자: "이게 눌러야 뜨게 해줘").
## 아직 안 골랐으면 골라 준다 — 이 파일의 관심은 조립 상태기계지 고르기가 아니다
## (고르기 계약은 test_ring_trace_auto ⑯이 본다).
func _rub(b) -> void:
	match int(b.call(&"stage")):
		b.STAGE_JIN:
			if int(b.call(&"jin_idx")) < 0:
				b.call(&"choose_jin")
		b.STAGE_RUNE:
			if int(b.call(&"rune_idx")) < 0:
				b.call(&"choose_rune")
	b.call(&"begin_stroke")
	for p in b.call(&"guide_points"):
		b.call(&"trace_stroke", p)


## 진→룬을 그려 문양 단계까지 간다. 🔴 세션 25: 칸은 자동으로 안 잡힌다 —
## 그릴 칸은 부르는 쪽이 `select_slot`으로 고른다 (미선택 계약은 ②가 못 박는다).
func _reach_glyph(b) -> void:
	_rub(b)
	b.call(&"advance")
	_rub(b)
	b.call(&"advance")


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("  ✗ ", msg)


# ── ① 빈 판의 초기 계약 ──
func _test_initial_state() -> void:
	var b = _make_board()
	_check(int(b.call(&"stage")) == b.STAGE_JIN, "빈 판은 진 단계에서 시작")
	_check(not bool(b.call(&"has_jin")), "초기: 진 없음")
	_check(not bool(b.call(&"has_rune")), "초기: 룬 없음")
	_check(not bool(b.call(&"can_commit")), "초기: 맺기 불가")
	_check(bool(b.call(&"is_tracing")), "초기: 진 가이드가 서 있다")
	_check(int(b.call(&"filled_count")) == 0, "초기: 채운 칸 0")
	_check((b.call(&"get_open") as Array) == [0, 2], "초기 문양본 = 2방 [0,2]")
	b.queue_free()


# ── ② 단계 전이는 진→룬→문양 순서다 ──
func _test_stage_transitions() -> void:
	var b = _make_board()
	_rub(b)
	_check(String(b.call(&"advance")) == "advanced", "진 [다음] = advanced")
	_check(int(b.call(&"stage")) == b.STAGE_RUNE, "진 다음은 룬 단계")
	_check(bool(b.call(&"has_jin")), "진이 잠겼다")
	_check(not bool(b.call(&"has_rune")), "아직 룬은 안 잠김")
	_rub(b)
	_check(String(b.call(&"advance")) == "advanced", "룬 [다음] = advanced")
	_check(int(b.call(&"stage")) == b.STAGE_GLYPH, "룬 다음은 문양 단계")
	_check(bool(b.call(&"has_rune")), "룬이 잠겼다")
	# 🔴 세션 25: 칸을 **멋대로 안 잡는다** (사용자: "8방 했을때 이미 주황색으로 선택되어있어").
	_check(int(b.call(&"trace_slot")) == -1, "문양 단계 도착 = 칸 미선택")
	b.queue_free()


# ── ③ can_commit = 진·룬이 있어야 참 (문양은 없어도 된다 = 빈 진) ──
func _test_can_commit_gate() -> void:
	var b = _make_board()
	_check(not bool(b.call(&"can_commit")), "아무것도 안 그림 → 맺기 불가")
	_rub(b)
	b.call(&"advance")
	_check(not bool(b.call(&"can_commit")), "진만 그림 → 여전히 맺기 불가")
	_rub(b)
	b.call(&"advance")
	_check(bool(b.call(&"can_commit")), "진+룬 → 문양 없어도 맺기 가능(빈 진)")
	b.queue_free()


# ── ④ 🔴 문양본이 칸을 연다 (스텐실) — 열린 칸만 채울 수 있고 순서도 그 목록 순 ──
func _test_template_opens_slots() -> void:
	var b = _make_board()
	b.call(&"set_template", [1, 2, 3])
	_check((b.call(&"get_open") as Array) == [1, 2, 3], "문양본이 연 칸 = [1,2,3]")
	_reach_glyph(b)
	# 🔴 세션 25: 문양본이 정하는 건 **어느 칸을 여는가**뿐이다. 채우는 **순서는 사용자가**
	# 칸을 클릭해 정한다 — 예전엔 열린 목록 순으로 자동 진행했고, 그래서 도착하자마자
	# 첫 칸이 잡혀 있었다. 스텐실 계약(닫힌 칸은 못 건드린다)은 그대로다.
	b.call(&"select_slot", 3)
	_check(int(b.call(&"trace_slot")) == 3, "열린 칸은 순서와 무관하게 고른다")
	b.call(&"select_slot", 0)
	_check(int(b.call(&"trace_slot")) == 3, "닫힌 칸(0)은 못 고른다 — 문양본이 스텐실이다")
	_rub(b)
	b.call(&"advance")
	_check(int(b.call(&"filled_count")) == 1, "고른 칸이 채워진다")
	b.queue_free()


# ── ⑤ 🔴 문양본을 바꾸면 닫힌 칸의 문양은 걷힌다 ──
func _test_template_closes_and_clears() -> void:
	var b = _make_board()
	b.call(&"set_template", [0, 2, 4, 6])
	b.call(&"set_active_glyph", G_RADIATE)
	_reach_glyph(b)
	b.call(&"select_slot", 0)
	_rub(b)
	b.call(&"advance")          # 칸 0 채움
	_check(int(b.call(&"filled_count")) == 1, "칸 하나 채움")
	# 칸 0을 닫는 문양본으로 교체 → 그 문양은 사라져야 한다
	b.call(&"set_template", [2, 6])
	_check((b.call(&"get_open") as Array) == [2, 6], "새 문양본이 연 칸")
	_check(int(b.call(&"filled_count")) == 0, "닫힌 칸(0)의 문양은 걷힌다")
	var rings: Array = (b.call(&"get_assembly") as Dictionary).rings[0]
	_check(int(rings[0]) == GLYPH_NONE, "assembly에도 닫힌 칸은 빈칸")
	b.queue_free()


# ── ⑥ set_template은 범위 밖·중복을 걸러낸다 ──
func _test_template_filters_garbage() -> void:
	var b = _make_board()
	b.call(&"set_template", [2, 2, -1, 99, 5])
	_check((b.call(&"get_open") as Array) == [2, 5], "중복·범위 밖(-1·99)은 걸러진다")
	b.call(&"set_template", [])
	_check((b.call(&"get_open") as Array).is_empty(), "빈 문양본 = 빈 진(열린 칸 없음)")
	b.queue_free()


# ── ⑦ 🔴 assembly = 발사 계약. 모양이 바뀌면 발사·저장이 조용히 깨진다 ──
func _test_assembly_shape() -> void:
	var b = _make_board()
	var a: Dictionary = b.call(&"get_assembly")
	_check(int(a.get("ring_count", -1)) == 1, "assembly.ring_count = 1 (진 하나)")
	_check(a.has("rune"), "assembly에 rune")
	_check(a.has("rings") and (a.rings as Array).size() == 1, "assembly.rings = 1줄")
	_check((a.rings[0] as Array).size() == SLOTS, "고리 한 줄 = 8칸 고정")
	_check(a.has("open"), "assembly에 open(열린 칸)")
	for k in SLOTS:
		_check(int(a.rings[0][k]) == GLYPH_NONE, "빈 판의 모든 칸 = 빈칸(-1)")
	b.queue_free()


# ── ⑧ 채운 문양이 assembly의 **그 칸에** 그 코드로 들어간다 ──
func _test_assembly_records_glyphs() -> void:
	var b = _make_board()
	b.call(&"set_template", [0, 4])
	_reach_glyph(b)
	b.call(&"select_slot", 0)
	b.call(&"set_active_glyph", G_RADIATE)
	_rub(b)
	b.call(&"advance")          # 칸 0 = 발산
	b.call(&"select_slot", 4)
	b.call(&"set_active_glyph", G_GATHER)
	_rub(b)
	b.call(&"advance")          # 칸 4 = 응집
	var a: Dictionary = b.call(&"get_assembly")
	_check(int(a.rings[0][0]) == G_RADIATE, "칸 0 = 발산(1)")
	_check(int(a.rings[0][4]) == G_GATHER, "칸 4 = 응집(0)")
	_check(int(a.rings[0][2]) == GLYPH_NONE, "안 연 칸(2)은 빈칸")
	_check((a.open as Array) == [0, 4], "assembly.open = 열린 칸")
	_check(int(b.call(&"filled_count")) == 2, "채운 칸 2")
	b.queue_free()


# ── ⑨ clear_all은 상태기계를 처음으로 되돌린다 ──
func _test_clear_all_resets() -> void:
	var b = _make_board()
	_reach_glyph(b)
	_rub(b)
	b.call(&"advance")
	b.call(&"clear_all")
	_check(int(b.call(&"stage")) == b.STAGE_JIN, "clear_all → 진 단계로")
	_check(not bool(b.call(&"has_jin")) and not bool(b.call(&"has_rune")), "clear_all → 진·룬 없음")
	_check(not bool(b.call(&"can_commit")), "clear_all → 맺기 불가")
	_check(int(b.call(&"filled_count")) == 0, "clear_all → 채운 칸 0")
	var a: Dictionary = b.call(&"get_assembly")
	for k in SLOTS:
		_check(int(a.rings[0][k]) == GLYPH_NONE, "clear_all → assembly 전 칸 비움")
	b.queue_free()


# ── ⑩ 상태가 바뀌면 바깥(패널)에 알린다 — 시그널이 계약이다 ──
func _test_signals() -> void:
	var b = _make_board()
	var stages: Array = []
	var changed := [0]
	b.stage_advanced.connect(func(s: int) -> void: stages.append(s))
	b.assembly_changed.connect(func() -> void: changed[0] += 1)

	_rub(b)
	b.call(&"advance")
	_check(stages.size() == 1 and int(stages[0]) == b.STAGE_RUNE, "진 잠금 → stage_advanced(룬)")
	_check(changed[0] >= 1, "진 잠금 → assembly_changed")

	var before: int = changed[0]
	b.call(&"set_template", [0, 2, 4, 6])
	_check(changed[0] > before, "문양본 교체 → assembly_changed (칸이 바뀌었다)")
	b.queue_free()


# ── ⑪ 빈 진: 문양 하나 없이 맺어도 유효한 assembly가 나온다 ──
func _test_finish_without_glyphs() -> void:
	var b = _make_board()
	b.call(&"set_template", [])
	_rub(b)
	b.call(&"advance")
	_rub(b)
	_check(String(b.call(&"advance")) == "finished", "빈 진은 룬 다음 바로 완성")
	_check(bool(b.call(&"can_commit")), "빈 진도 맺을 수 있다")
	var a: Dictionary = b.call(&"get_assembly")
	_check((a.rings[0] as Array).size() == SLOTS, "빈 진도 8칸 계약을 지킨다")
	_check(int(b.call(&"filled_count")) == 0, "빈 진 = 채운 칸 0")
	b.queue_free()
