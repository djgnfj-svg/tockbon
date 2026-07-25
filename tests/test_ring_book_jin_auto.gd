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
var _BoardScript = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(15.0).timeout.connect(func() -> void:
		print("TEST_RING_BOOK_JIN_TIMEOUT — 15초 초과")
		quit(1))
	await process_frame

	_BookScript = load("res://src/drawing/ring_book.gd")
	_BoardScript = load("res://src/drawing/ring_board.gd")

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
	# 세61 콘텐츠 리셋: 카탈로그를 jin_single 1종으로 비웠다 — 사용자가 되살릴 때마다 늘어난다.
	_check(jins.size() >= 1, "진이 1종 이상이어야 한다 (실제 %d)" % jins.size())


## 🔴 격자 계약 — 8칸이 다 생기고, 책 안에 들어가고, 서로 안 겹친다.
## 뮤테이션: `_draw_jin_cells`를 세션44의 한 줄 배치(`cw = 전체폭/n`)로 되돌리면
## 셀 폭이 30px로 쪼그라들어 이름이 넘치고 — 여기선 **높이가 안 늘어** 아래 desc 줄과
## 겹치지 않으므로, 폭 하한(48px)으로 잡는다.
func _test_cells_fit_and_dont_overlap(jins: Array) -> void:
	var top: float = _BookScript.body_top()
	# 세61 콘텐츠 리셋로 Db엔 1종뿐 — 격자 계약(8칸 배치·겹침 없음)은 합성 개수 8로 계속 잰다.
	# jin_cell_rects는 순수 함수라 Db와 무관하다. 진이 되살아나도 이 검사는 그대로 유효하다.
	var grid_n := maxi(jins.size(), 8)
	var rects: Array = _BookScript.jin_cell_rects(grid_n, BOOK_SIZE, top)
	_check(rects.size() == grid_n,
		"진 셀이 %d칸이어야 한다 (실제 %d)" % [grid_n, rects.size()])

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
## 🔴 **세83에 갈리는 축이 바뀌었다**: 옛 축 = 패턴(몇 발)×경로(어떻게 나는가) 힌트 획.
## 새 축 = **진 모양(guide_shape) × 룬 자리 수(rune_slots)** — 사용자 확정으로 셀이
## "진 모양 + 룬 위치"만 답하게 좁혔기 때문이다(`jin_icon_paths` 머리 주석).
## ⚠ 그래서 이 그물은 이제 `pattern`·`motion`을 **안 잰다**. 그 둘은 죽은 축이 아니라
##   (`ring_spell_system`이 여전히 읽는다) **셀이 답하는 질문이 아니게** 된 것이다.
## 뮤테이션: `jin_icon_paths`가 shape를 무시하고 늘 원을 내면 도형 조합이 대량 실패하고,
##   rune_slots를 무시하고 늘 1자리면 아래 [자리 수] 검사와 지문이 같이 실패한다(실측 확인).
func _test_icons_differ(jins: Array) -> void:
	# 세61 콘텐츠 리셋 이후 Db 진이 적어 실데이터만으론 "서로 다르다"를 못 잰다 —
	# 합성 조합으로 기계(축 직교 아이콘)의 검출력을 유지한다(옛 관행 계승).
	var combos: Array = []
	for shape in [Enums.JinShape.CIRCLE, Enums.JinShape.TRIANGLE, Enums.JinShape.OCTAGON,
			Enums.JinShape.ELLIPSE, Enums.JinShape.PENTAGON, Enums.JinShape.DIAMOND,
			Enums.JinShape.FLOWER, Enums.JinShape.LENS]:
		for slots in [1, 2, 3]:
			combos.append([int(shape), int(slots)])
	for jd in jins:
		combos.append([int(jd.guide_shape), maxi(int(jd.rune_slots), 1)])
	var seen: Dictionary = {}
	for c in combos:
		var label := "shape%d·rune%d" % [int(c[0]), int(c[1])]
		var paths: Array = _BookScript.jin_icon_paths(
			int(c[0]), int(c[1]), Vector2(50.0, 50.0), 17.0)
		_check(not paths.is_empty(), "%s: 아이콘 획이 비었다" % label)
		# 🔴 자리 수 = 윤곽 1 + 룬 자리 n. 여기가 "룬 위치만 표시"의 직접 그물이다 —
		#   rune_slots를 무시하면(늘 1자리) 융합진 셀이 단발진과 똑같아진다.
		_check(paths.size() == 1 + int(c[1]),
			"%s: 획 수가 윤곽1+룬%d이 아니다 (%d)" % [label, int(c[1]), paths.size()])
		_check(not bool(paths[0]["faint"]), "%s: 진 윤곽은 흐린 획이 아니다" % label)
		for i in range(1, paths.size()):
			_check(bool(paths[i]["faint"]), "%s: 빈 룬 자리는 흐려야 한다" % label)
		# 🔴🔴 **세83 뮤테이션이 잡은 그물 구멍**: 자리 좌표를 전부 중심으로 고정해도 위의
		#   [자리 수]·지문이 **전부 그린이었다**(원이 한 점에 포개질 뿐 개수는 그대로니까) —
		#   융합진 셀에서 두 자리가 겹쳐 "룬 위치를 보여준다"는 기능 자체가 죽는데 아무도 안
		#   빨개진다. 그래서 **판의 단일 소스와 같은 좌표인가**를 직접 잰다(식을 베끼면 빨감).
		var want_pos: Array = _BoardScript.rune_slot_positions(int(c[1]), Vector2(50.0, 50.0), 17.0)
		_check(want_pos.size() == paths.size() - 1,
			"%s: 판의 자리 수와 셀의 자리 수가 다르다" % label)
		for i in range(1, paths.size()):
			if i - 1 >= want_pos.size():
				break
			var got: Vector2 = _path_center(paths[i]["pts"])
			var want: Vector2 = want_pos[i - 1]
			_check(got.distance_to(want) < 0.5,
				"🔴 %s: 룬 자리 %d가 판(rune_slot_positions)과 갈라졌다 — %s vs %s"
					% [label, i - 1, got, want])
		var total := 0
		for p in paths:
			total += (p["pts"] as PackedVector2Array).size()
		_check(total >= 2, "%s: 아이콘 점이 너무 적다 (%d)" % [label, total])
		var key := _fingerprint(paths)
		if seen.has(key) and String(seen[key]) != label:
			failures += 1
			print("  FAIL: %s 아이콘이 %s와 똑같다 — 색만 다른 셈" % [label, seen[key]])
		seen[key] = label


## 닫힌 점열의 중심 — 룬 자리 표식은 원이라 점 평균이 곧 자리 좌표다.
func _path_center(pts: PackedVector2Array) -> Vector2:
	if pts.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for p in pts:
		sum += p
	return sum / float(pts.size())


func _fingerprint(paths: Array) -> String:
	var s := ""
	for path in paths:
		s += "f" if bool(path["faint"]) else "s"
		for p in (path["pts"] as PackedVector2Array):
			s += "%.1f,%.1f;" % [p.x, p.y]
		s += "|"
	return s


## 🔴 진이 더 늘어도 죽지 않는다 — 모르는 도형·자리 수·id는 폴백이지 크래시가 아니다.
## (`GLYPH_DESC`가 세션44~47에 인덱스 초과로 잠복 크래시를 냈던 자리와 같은 종류의 계약.)
func _test_unknown_jin_survives() -> void:
	var paths: Array = _BookScript.jin_icon_paths(99, 0, Vector2.ZERO, 17.0)
	_check(not paths.is_empty(), "모르는 도형도 아이콘 획이 나와야 한다 (폴백=원)")
	# rune_slots 0·음수도 자리 하나로 산다 — .tres에 안 적힌 옛 진이 셀에서 사라지면 안 된다.
	_check(paths.size() == 2, "rune_slots=0이면 자리 1개로 폴백 (윤곽1+룬1=2, 실제 %d)" % paths.size())
