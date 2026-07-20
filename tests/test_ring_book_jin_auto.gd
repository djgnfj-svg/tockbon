extends SceneTree
## 책 진 탭이 **8종을 갈라 보여 주는가** 자동 검증 (세션48) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_book_jin_auto.gd
## 전 항목 통과 시 "TEST_RING_BOOK_JIN_OK" 출력 후 종료 코드 0.
##
## 🔴 왜 이 테스트가 있나: 세션47에 문양이 3→6으로 늘 때 **한 줄 격자**가 셀을 쪼그라뜨리고
##   `GLYPH_DESC` 인덱스 초과가 잠복 크래시를 냈다. 세션48에 진이 3→8로 늘어 **같은 자리**를
##   밟을 참이었다. 여기서 지키는 계약:
##     ① 셀이 8칸 다 생기고 · 책 밖으로 안 나가고 · 서로 안 겹친다 (격자)
##     ② 8종의 아이콘 획이 **서로 다르다** (색만 다른 8지선다가 아니다)
##     ③ 진이 늘어도 설명·아이콘이 인덱스 초과로 죽지 않는다 (모르는 진 = 폴백)
##
## ⚠ 헤드리스가 **못** 잡는 것: 셀이 실제로 보이는지·클릭이 닿는지. 리드가 실게임 push_input과
##   MCP 스샷으로 따로 확인해야 한다.
##
## 주의: -s 모드는 오토로드보다 먼저 컴파일 — 오토로드 식별자·모듈 preload 금지. 첫 프레임 후 load().

## 책 Control 크기 = ring_forge_panel.tscn의 RingBook (332,24)~(612,286)
const BOOK_SIZE := Vector2(280.0, 262.0)

var failures: int = 0
var _BookScript = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(15.0).timeout.connect(func() -> void:
		print("TEST_RING_BOOK_JIN_TIMEOUT — 15초 초과")
		quit(1))
	await process_frame

	_BookScript = load("res://src/drawing/ring_book.gd")

	var jins := _load_jins()
	_test_all_jins_present(jins)
	_test_cells_fit_and_dont_overlap(jins)
	_test_icons_differ(jins)
	_test_unknown_jin_survives()

	if failures == 0:
		print("TEST_RING_BOOK_JIN_OK")
	else:
		print("TEST_RING_BOOK_JIN_FAIL — 실패 %d건" % failures)
	quit(1 if failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("  FAIL: ", msg)


## data/jin/*.tres 를 sort 순으로 (Db 오토로드는 -s에서 못 본다 — 디렉터리를 직접 읽는다)
func _load_jins() -> Array:
	var out: Array = []
	var dir := DirAccess.open("res://data/jin")
	if dir == null:
		return out
	for f in dir.get_files():
		var p: String = f.get_basename() + ".tres" if f.ends_with(".remap") else f
		if not p.ends_with(".tres"):
			continue
		var res = load("res://data/jin/" + p)
		if res != null:
			out.append(res)
	out.sort_custom(func(a, b) -> bool: return int(a.sort) < int(b.sort))
	return out


func _test_all_jins_present(jins: Array) -> void:
	_check(jins.size() >= 8, "진이 8종 이상이어야 한다 (실제 %d)" % jins.size())


## 🔴 격자 계약 — 8칸이 다 생기고, 책 안에 들어가고, 서로 안 겹친다.
## 뮤테이션: `_draw_jin_cells`를 세션44의 한 줄 배치(`cw = 전체폭/n`)로 되돌리면
## 셀 폭이 30px로 쪼그라들어 이름이 넘치고 — 여기선 **높이가 안 늘어** 아래 desc 줄과
## 겹치지 않으므로, 폭 하한(48px)으로 잡는다.
func _test_cells_fit_and_dont_overlap(jins: Array) -> void:
	var top: float = _BookScript.body_top()
	var rects: Array = _BookScript.jin_cell_rects(jins.size(), BOOK_SIZE, top)
	_check(rects.size() == jins.size(),
		"진 셀이 %d칸이어야 한다 (실제 %d)" % [jins.size(), rects.size()])

	# 격자 아래엔 고른 진의 설명 한 줄이 들어간다 — 그 자리(12px)까지 남겨야 한다
	var bounds := Rect2(Vector2.ZERO, BOOK_SIZE - Vector2(0.0, 12.0))
	for r: Rect2 in rects:
		_check(bounds.encloses(r), "셀이 책(설명 줄 제외) 밖으로 나갔다: %s" % r)
		_check(r.size.x >= 48.0, "셀 폭이 너무 좁다 (%.1f) — 한 줄로 몰아넣었나?" % r.size.x)
		_check(r.size.y >= 40.0, "셀 높이가 너무 낮다 (%.1f)" % r.size.y)
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			var a: Rect2 = rects[i]
			var b: Rect2 = rects[j]
			_check(not a.intersects(b), "셀 %d·%d가 겹친다 (%s / %s)" % [i, j, a, b])

	# 진이 더 늘어도(12종) 격자가 버티는가 — 폭은 그대로, 줄만 늘어난다
	var many: Array = _BookScript.jin_cell_rects(12, BOOK_SIZE, top)
	_check(many.size() == 12, "12종에서도 셀이 12칸")
	_check(is_equal_approx(float(many[0].size.x), float(rects[0].size.x)),
		"진이 늘 때 셀 폭이 줄면 안 된다 (한 줄 배치 회귀)")


## 🔴 아이콘이 진마다 갈리는가 — **색만 다르면 8지선다**(세션47 문양이 밟은 그것).
## 패턴(몇 발)과 경로(어떻게 나는가) 둘 중 하나라도 다르면 획 배열이 달라야 한다.
## 뮤테이션: `jin_icon_marks`의 match를 지우고 항상 단발 획만 돌려주면 여기가 대량 실패한다.
func _test_icons_differ(jins: Array) -> void:
	var seen: Dictionary = {}
	for jd in jins:
		var marks: Array = _BookScript.jin_icon_marks(
			int(jd.pattern), int(jd.motion), Vector2(50.0, 50.0), 17.0)
		_check(not marks.is_empty(), "%s: 아이콘 획이 비었다" % jd.id)
		var total := 0
		for m in marks:
			total += (m as PackedVector2Array).size()
		_check(total >= 2, "%s: 아이콘 점이 너무 적다 (%d)" % [jd.id, total])
		var key := _fingerprint(marks)
		if seen.has(key):
			failures += 1
			print("  FAIL: %s 아이콘이 %s와 똑같다 — 색만 다른 셈" % [jd.id, seen[key]])
		seen[key] = String(jd.id)


func _fingerprint(marks: Array) -> String:
	var s := ""
	for m in marks:
		for p in (m as PackedVector2Array):
			s += "%.1f,%.1f;" % [p.x, p.y]
		s += "|"
	return s


## 🔴 진이 더 늘어도 죽지 않는다 — 모르는 패턴·경로·id는 폴백이지 크래시가 아니다.
## (`GLYPH_DESC`가 세션44~47에 인덱스 초과로 잠복 크래시를 냈던 자리와 같은 종류의 계약.)
func _test_unknown_jin_survives() -> void:
	var marks: Array = _BookScript.jin_icon_marks(99, 99, Vector2.ZERO, 17.0)
	_check(not marks.is_empty(), "모르는 패턴·경로도 아이콘 획이 나와야 한다 (폴백=단발)")
