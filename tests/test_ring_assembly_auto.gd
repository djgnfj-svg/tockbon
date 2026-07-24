extends SceneTree
## 🔴 고리 **조립 상태기계** 계약 검증 (세션 22) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_assembly_auto.gd
## 전 항목 통과 시 "TEST_RING_ASSEMBLY_OK" 출력 후 종료 코드 0.
##
## 🔴 **왜 따로 있나** (docs/REFACTOR_PLAN.md C4): test_ring_trace_auto는 **추적·점수 중심**이고
## 조립 상태기계(단계 전이·진이 칸을 여는 규칙·assembly 계약)를 검증하지 않는다.
## 세션60: 문양본(템플릿) 축이 진에 흡수됐다 — 열린 칸 = `JinDef.glyph_slots` →
## `choose_jin(jd)` → `set_open_slots`. 스텐실·걷어내기·필터 계약(④⑤⑥)은 그대로다.
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
	_test_open_slots_stencil()
	_test_open_slots_shrink_clears()
	_test_open_slots_filters_garbage()
	_test_assembly_shape()
	_test_assembly_records_glyphs()
	_test_clear_all_resets()
	_test_signals()
	_test_finish_without_glyphs()
	_test_jin_opens_slots()
	_test_jin_swap_before_lock()
	_test_jin_db_loaded()
	_test_jin_default_slots()
	_test_jin_slot_dots()

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
	_check((b.call(&"get_open") as Array) == [0, 2], "진 미선택 폴백 = [0,2]")
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


# ── ④ 🔴 열린 칸 = 스텐실 — 열린 칸만 채울 수 있다 (세션60: 여는 주체가 문양본→진으로 바뀜) ──
func _test_open_slots_stencil() -> void:
	var b = _make_board()
	b.call(&"set_open_slots", [1, 2, 3])
	_check((b.call(&"get_open") as Array) == [1, 2, 3], "열린 칸 = [1,2,3]")
	_reach_glyph(b)
	# 🔴 세션 25: 열린 칸 목록이 정하는 건 **어느 칸을 여는가**뿐이다. 채우는 **순서는 사용자가**
	# 칸을 클릭해 정한다 — 예전엔 열린 목록 순으로 자동 진행했고, 그래서 도착하자마자
	# 첫 칸이 잡혀 있었다. 스텐실 계약(닫힌 칸은 못 건드린다)은 그대로다.
	b.call(&"select_slot", 3)
	_check(int(b.call(&"trace_slot")) == 3, "열린 칸은 순서와 무관하게 고른다")
	b.call(&"select_slot", 0)
	_check(int(b.call(&"trace_slot")) == 3, "닫힌 칸(0)은 못 고른다 — 열린 칸이 스텐실이다")
	_rub(b)
	b.call(&"advance")
	_check(int(b.call(&"filled_count")) == 1, "고른 칸이 채워진다")
	b.queue_free()


# ── ⑤ 🔴 열린 칸을 좁히면 닫힌 칸의 문양은 걷힌다 (걷어내기 계약 — 방어선·미래 경로) ──
func _test_open_slots_shrink_clears() -> void:
	var b = _make_board()
	b.call(&"set_open_slots", [0, 2, 4, 6])
	b.call(&"set_active_glyph", G_RADIATE)
	_reach_glyph(b)
	b.call(&"select_slot", 0)
	_rub(b)
	b.call(&"advance")          # 칸 0 채움
	_check(int(b.call(&"filled_count")) == 1, "칸 하나 채움")
	# 칸 0을 닫는 목록으로 교체 → 그 문양은 사라져야 한다
	b.call(&"set_open_slots", [2, 6])
	_check((b.call(&"get_open") as Array) == [2, 6], "새로 연 칸 목록")
	_check(int(b.call(&"filled_count")) == 0, "닫힌 칸(0)의 문양은 걷힌다")
	var rings: Array = (b.call(&"get_assembly") as Dictionary).rings[0]
	_check(int(rings[0]) == GLYPH_NONE, "assembly에도 닫힌 칸은 빈칸")
	b.queue_free()


# ── ⑥ set_open_slots는 범위 밖·중복을 걸러낸다 (.tres 오염값도 이 필터가 마지막 방어선) ──
func _test_open_slots_filters_garbage() -> void:
	var b = _make_board()
	b.call(&"set_open_slots", [2, 2, -1, 99, 5])
	_check((b.call(&"get_open") as Array) == [2, 5], "중복·범위 밖(-1·99)은 걸러진다")
	b.call(&"set_open_slots", [])
	_check((b.call(&"get_open") as Array).is_empty(), "빈 목록 = 빈 진(열린 칸 없음)")
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
	b.call(&"set_open_slots", [0, 4])
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
	b.call(&"set_open_slots", [0, 2, 4, 6])
	_check(changed[0] > before, "열린 칸 교체 → assembly_changed (칸이 바뀌었다)")
	b.queue_free()


# ── ⑪ 빈 진: 문양 하나 없이 맺어도 유효한 assembly가 나온다 ──
func _test_finish_without_glyphs() -> void:
	var b = _make_board()
	b.call(&"set_open_slots", [])
	_rub(b)
	b.call(&"advance")
	_rub(b)
	_check(String(b.call(&"advance")) == "finished", "빈 진은 룬 다음 바로 완성")
	_check(bool(b.call(&"can_commit")), "빈 진도 맺을 수 있다")
	var a: Dictionary = b.call(&"get_assembly")
	_check((a.rings[0] as Array).size() == SLOTS, "빈 진도 8칸 계약을 지킨다")
	_check(int(b.call(&"filled_count")) == 0, "빈 진 = 채운 칸 0")
	b.queue_free()


## JinDef 인스턴스를 런타임 load로 만든다 — -s 컴파일 시점의 전역 클래스 캐시에 기대지 않는다
## (glyph_slots는 typed Array[int]라 대입도 typed 지역변수로 — 형 불일치가 조용히 새지 않게).
func _make_jin(slots: Array) -> Resource:
	var jd: Resource = (load("res://src/core/schemas/jin_def.gd") as GDScript).new()
	var typed: Array[int] = []
	for s in slots:
		typed.append(int(s))
	jd.set(&"glyph_slots", typed)
	return jd


# ── ⑫ 🔴 진이 칸을 연다 (세션60 — 문양본 축 흡수의 심장) ──
# choose_jin(jd)가 jd.glyph_slots를 set_open_slots로 흘려야 한다. 이 배선 한 줄이 빠지면
# 모든 진이 폴백 [0,2]로 조용히 굳는다 — 에러 없이 게임 전체의 칸 배치가 죽는 자리다.
func _test_jin_opens_slots() -> void:
	var b = _make_board()
	b.call(&"choose_jin", _make_jin([1, 5]))
	_check((b.call(&"get_open") as Array) == [1, 5], "🔴 choose_jin(jd) → jd.glyph_slots가 칸을 연다")
	# jd=null(테스트·폴백 경로) = 현 _open 유지 — 덮어쓰지 않는다
	b.call(&"choose_jin")
	_check((b.call(&"get_open") as Array) == [1, 5], "choose_jin(null)은 현 열린 칸을 유지")
	b.queue_free()
	# 새 판: 진을 한 번도 안 고르면 폴백 그대로 (①의 폴백 계약과 한 쌍)
	var b2 = _make_board()
	b2.call(&"choose_jin")
	_check((b2.call(&"get_open") as Array) == [0, 2], "진 미선택 + choose_jin(null) = 폴백 [0,2] 유지")
	b2.queue_free()


# ── ⑬ 진 교체(잠금 전) → 칸이 두 번째 진을 따라간다 ──
# choose_jin은 has_jin()이면 거부하므로(잠근 진은 [다시 그리기]로만) 이 경로는 진 잠금 전
# 셀 재클릭에서만 돈다 — 그래도 "마지막으로 고른 진이 이긴다"는 계약이다.
func _test_jin_swap_before_lock() -> void:
	var b = _make_board()
	b.call(&"choose_jin", _make_jin([1, 5]))
	b.call(&"choose_jin", _make_jin([0, 4, 6]))
	_check((b.call(&"get_open") as Array) == [0, 4, 6], "진 재선택 → 열린 칸 = 두 번째 진의 것")
	b.queue_free()


# ── ⑭ 🔴 Db 로드 그물 — .tres 파싱 침묵사 방지 (세50 함정: 한 글자 오타 = 리소스 전체 증발) ──
# test_decode_auto의 「룬 6종 로드」와 같은 역할. Db는 못 읽은 리소스를 조용히 건너뛰므로
# 개수를 세지 않으면 진 하나가 게임에서 통째로 사라져도 전 스위트가 그린이다.
func _test_jin_db_loaded() -> void:
	var db: Node = root.get_node("/root/Db")
	var jins: Array = db.call(&"all_jins")
	# 세61 콘텐츠 리셋: 진 8종 → 1종(jin_single). 사용자가 진을 하나 되살릴 때마다 이 기대치를 +1.
	# 🔴 세79 M1: 1종(jin_single) → **2종**. 새 진 = `jin_plain_g2`(band_count=2 = 「2등급」) —
	# 1등급은 층이 1겹이라 **문양을 감쌀 순서 자체가 안 생겨서** 순서=연산 실증에 2겹 진이 필요했다.
	_check(jins.size() == 2, "🔴 진 2종(jin_single·jin_plain_g2)이 Db에 로드된다 (지금 %d종 — 줄었으면 .tres 침묵사 의심, 새 진을 추가했으면 기대치를 갱신)" % jins.size())
	for jd in jins:
		var jid := String(jd.get(&"id"))
		var slots: Array = jd.get(&"glyph_slots")
		_check(not slots.is_empty(), "%s: glyph_slots가 비어 있지 않다" % jid)
		var seen: Dictionary = {}
		var valid := true
		for s in slots:
			var k := int(s)
			if k < 0 or k >= SLOTS or seen.has(k):
				valid = false
			seen[k] = true
		_check(valid, "%s: glyph_slots 전 원소 0..7 · 중복 없음 (지금 %s)" % [jid, str(slots)])


# ── ⑮ JinDef 기본값 계약 — 필드 누락 .tres도 8칸 전부로 산다 ──
# .tres에 glyph_slots가 없으면 @export 기본값이 적용된다 — "깜빡한 새 진"이 조용히 약해지지 않는다.
func _test_jin_default_slots() -> void:
	var jd: Resource = (load("res://src/core/schemas/jin_def.gd") as GDScript).new()
	_check((jd.get(&"glyph_slots") as Array) == [0, 1, 2, 3, 4, 5, 6, 7],
		"JinDef.new().glyph_slots 기본값 = 8칸 전부 [0..7]")


# ── ⑯ 진 셀 다이어그램 관측점 — 「칸 0=위, 시계방향」 기하 규약 (세션60 리뷰 지적) ──
# jin_slot_dots는 순수 static 관측점인데 소비자가 렌더뿐이면 각도(-PI/2 탈락)·open 반전
# 회귀를 아무도 못 잡는다 — MCP 스샷은 커밋 시점 1회 스냅샷이다. 여기가 상시 그물.
func _test_jin_slot_dots() -> void:
	var b = _make_board()
	var dots: Array = b.call(&"jin_slot_dots", [1, 5], Vector2.ZERO, 10.0)
	_check(dots.size() == SLOTS, "다이어그램 점 = 8개 (칸 전수)")
	var p0: Vector2 = dots[0]["pos"]
	var p2: Vector2 = dots[2]["pos"]
	_check(p0.distance_to(Vector2(0, -10)) < 0.01, "칸 0 = 위 (지금 %s — -PI/2 규약)" % str(p0))
	_check(p2.distance_to(Vector2(10, 0)) < 0.01, "칸 2 = 오른쪽 (시계방향 규약)")
	var opens: Array = []
	for k in SLOTS:
		if bool(dots[k]["open"]):
			opens.append(k)
	_check(opens == [1, 5], "열린 표시 = 정확히 [1,5] (지금 %s)" % str(opens))
	b.queue_free()
