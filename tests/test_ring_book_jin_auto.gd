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
	_test_ring_icon_from_board()
	_test_ring_list_layout()

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


## motif·count만 있는 in-memory 문양-고리 (아이콘 기하 검증용 — .tres 카탈로그와 무관하게 잰다).
func _mk_ring(motif: int, count: int) -> GlyphRingDef:
	var gr := GlyphRingDef.new()
	gr.motif = motif
	gr.count = count
	return gr


## 🔴🔴 **층 탭 미리보기 아이콘이 판 정본에서 나오는가** (세86 — 사용자 F5 지적:
## *"아이콘이 조잡하다 · 판과 모양이 다르다 · 미리보기에선 선 위에 문양이 있다"*).
##
## 🔴 옛 `_ring_icon`은 판을 **베끼고 있었다**: 각도 루프를 다시 쓰고, 모티프 크기를 `radius*0.42`로
## 직접 잡고(판은 띠 반지름의 `MOTIF_SIZE_FRAC`=14%), 고리 선을 **모티프 중심 반경에 그대로** 그었다.
## 세86에 판이 층 선을 문양 바깥으로 밀자 미리보기만 옛 그림에 남아 「본 것 ≠ 끼운 것」이 됐다(감사 T5).
## 그물이 지키는 계약 셋 — 전부 **관계식**이라 판이 여백·모티프 크기를 조여도 거짓 빨강이 안 난다:
##   ① 🔴 모티프 점열이 `RingBoard.glyph_ring_subpaths` **정본과 점 단위로 같다**(로컬 계산 = 빨감)
##   ② 🔴🔴 **선이 모티프를 침범하지 않는다** — 모든 모티프 점이 띠 두 선 **사이**(옛 그림 = 빨감)
##   ③ 바깥 띠선이 아이콘 반지름에 앉는다(= 카드 밖으로 안 샌다) · 빈 소켓은 띠만
## ⚠ 겉보기(톤·굵기·"읽히나")는 여전히 헤드리스가 못 본다 — 리드의 MCP 스샷이 최종 판정.
## 모티프를 **자기 중심·크기로 정규화**한다 — 어디에 얼마나 크게 놓였는지를 지우고 「모양」만 남긴다.
## 아이콘은 판을 확대·맞춤 배율로 옮겨 그리므로 좌표는 다르지만 **모양은 같아야 한다**(사본 금지 계약).
func _normalized_shape(sub: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	if sub.size() == 0:
		return out
	var mid := Vector2.ZERO
	for p in sub:
		mid += p
	mid /= float(sub.size())
	var scale := 0.0
	for p in sub:
		scale = maxf(scale, p.distance_to(mid))
	if scale <= 0.0001:
		scale = 1.0
	for p in sub:
		out.append((p - mid) / scale)
	return out


## 모티프가 **어느 각도에 놓였나** — 중심에서 본 방향. 배치 규약(각도 루프)이 갈라지면 값이 달라진다.
func _dir_angle(sub: PackedVector2Array, c: Vector2) -> float:
	if sub.size() == 0:
		return 0.0
	var mid := Vector2.ZERO
	for p in sub:
		mid += p
	mid /= float(sub.size())
	return (mid - c).angle()


func _test_ring_icon_from_board() -> void:
	var c := Vector2(60.0, 40.0)
	var s := 20.0
	for bi in [0, 1]:
		for combo in [[1, 5], [6, 3], [7, 1], [0, 8]]:
			var label := "band%d·motif%d×%d" % [bi, combo[0], combo[1]]
			var gr := _mk_ring(int(combo[0]), int(combo[1]))
			var geom: Dictionary = _BookScript.ring_icon_geom(gr, c, s, bi)
			var lane: Vector2 = geom["lane"]
			var motifs: Array = geom["motifs"]

			# ③ 바깥 띠선 = 아이콘 반지름. 넘치면 카드 이웃을 침범하고, 모자라면 아이콘이 쪼그라든다.
			_check(absf(lane.y - s) < 0.01,
				"%s: 바깥 띠선이 아이콘 반지름과 다르다 (%.2f vs %.2f)" % [label, lane.y, s])
			_check(lane.x > 0.0 and lane.x < lane.y,
				"%s: 띠가 뒤집혔다/무너졌다 (%s)" % [label, lane])
			_check(motifs.size() == maxi(int(combo[1]), 1),
				"%s: 모티프 수가 count와 다르다 (%d)" % [label, motifs.size()])

			# ① 🔴 판 정본과 **모양이 같다** — band_r·모티프 점열을 BAND_RADII에서 독립적으로 되민다.
			# ⚠ 세86 F5: 아이콘은 판의 **픽셀 축소판이 아니다.** 판 비율 그대로면 모티프 지름이
			#   아이콘 반지름의 24%(≈4px)라 「폭발 ×1」이 점 하나로 사라진다 — 리드가 실게임에서
			#   보고 `ICON_MOTIF_ZOOM`을 넣었다(모티프와 띠를 **같은 배로** 벌려 「선 사이」는 유지).
			# 🔴 그래서 계약은 「점 좌표 동일」이 아니라 **「모양과 배치 각도가 판과 동일」**이다.
			#   ⓐ 각 모티프를 자기 중심·크기로 **정규화**해 비교한다 → 확대·맞춤 배율에 무관하게
			#      「그 문양이 맞나」만 남는다. 사본을 만들면(모양을 다시 그리면) 여기서 갈라진다.
			#   ⚠ **배치 각도는 여기서 안 잰다** — 리드가 넣었다가 걷었다: 판을 임의 반경(100)으로
			#     만들어 아이콘의 작은 반경과 비교하면 **모티프 평균 방향에 반경 의존 편차**가 생겨
			#     응집처럼 축 비대칭인 문양이 거짓 빨강이 났다(검사 자체가 틀렸다). 모티프가 중심을
			#     침범하는 진짜 사고는 아래 ②(선 사이)가 잡는다.
			var want: Array = _BoardScript.glyph_ring_subpaths(gr, c, 100.0)
			_check(want.size() == motifs.size(),
				"%s: 서브패스 수가 판과 다르다 (%d vs %d)" % [label, motifs.size(), want.size()])
			var same := true
			for mi in mini(want.size(), motifs.size()):
				var a: PackedVector2Array = motifs[mi]
				var b: PackedVector2Array = want[mi]
				if a.size() != b.size():
					same = false
					break
				var na := _normalized_shape(a)
				var nb := _normalized_shape(b)
				for pi in na.size():
					if na[pi].distance_to(nb[pi]) > 0.02:
						same = false
						break
			_check(same, "🔴 %s: 아이콘 모티프 **모양**이 판(glyph_ring_subpaths)과 갈라졌다 — 사본을 만들었나?"
				% label)

			# ② 🔴🔴 심장 — 선이 모티프를 관통하지 않는다(사용자가 눈으로 지적한 바로 그것).
			var worst_in := INF
			var worst_out := 0.0
			for sub_v in motifs:
				var sub: PackedVector2Array = sub_v
				for p in sub:
					var d := p.distance_to(c)
					worst_in = minf(worst_in, d)
					worst_out = maxf(worst_out, d)
			_check(worst_in > lane.x and worst_out < lane.y,
				"🔴 %s: 문양이 띠 선을 넘었다 — 모티프 %.2f~%.2f vs 선 %.2f~%.2f"
					% [label, worst_in, worst_out, lane.x, lane.y])

	# 빈 소켓 = 띠만 (끼우기 전에도 "여기가 한 층"이 읽혀야 한다)
	var empty: Dictionary = _BookScript.ring_icon_geom(null, c, s, 0)
	_check((empty["motifs"] as Array).is_empty(), "빈 소켓 아이콘에 모티프가 있다")
	_check(Vector2(empty["lane"]).y > 0.0, "빈 소켓 아이콘에 띠가 없다")


## 🔴 층 탭 소켓·목록 레이아웃 — 카드를 키운 대가로 **목록이 사라지지 않는가**(세86).
## 아이콘을 판 비율로 바로잡으면 모티프가 띠 반지름의 14%라 작다 → 카드를 30→44로 키워
## 겉보기를 되찾았고(아이콘 반지름 10.2→18.5px), 그 대가로 스크롤 없이 보이는 고리가 4→3장이 됐다.
## **그 거래의 하한**을 여기서 못 박는다 — 더 키우면 목록이 1~2장으로 무너진다.
## ⚠ 「세로로 쌓인다」는 `test_ring_trace_auto`가 이미 재는 계약이라 여기선 안 겹친다는 것만 잰다.
## 뮤테이션: `RING_ROW_H`를 60으로 올리면 [보이는 개수]가, 30으로 되돌리면 [카드 높이]가 빨개진다.
func _test_ring_list_layout() -> void:
	var top: float = _BookScript.body_top()
	var list_top: float = _BookScript.band_list_top(1, top)   # 층 1겹 진(지금 살아있는 전부)
	var n := 6
	var rects: Array = _BookScript.ring_list_rects(n, BOOK_SIZE, list_top)
	_check(rects.size() == n, "목록 카드가 %d칸이어야 한다 (실제 %d)" % [n, rects.size()])
	for r: Rect2 in rects:
		_check(r.position.x >= 0.0 and r.end.x <= BOOK_SIZE.x,
			"목록 카드가 책 좌우를 넘었다: %s" % r)
		# 아이콘 반지름 = 카드 높이 × ICON_R_FRAC(0.42) → 지름이 높이의 84%. 카드가 낮으면
		# 아이콘이 같이 쪼그라들어 세86 수정이 무의미해진다.
		_check(r.size.y >= 40.0, "목록 카드가 너무 낮다 (%.1f) — 아이콘이 도로 작아진다" % r.size.y)
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			var a: Rect2 = rects[i]
			var b: Rect2 = rects[j]
			_check(not a.intersects(b), "목록 카드 %d·%d가 겹친다 (%s / %s)" % [i, j, a, b])
	# 스크롤 콘텐츠 높이 = **마지막 카드 끝**과 맞물린다 — 어긋나면 스크롤이 빈 곳까지 굴러가거나
	# 마지막 카드가 영영 안 보인다(`_draw`가 항목 수로 직접 세던 자리를 static으로 뽑은 이유).
	var last: Rect2 = rects[n - 1]
	_check(list_top + float(_BookScript.ring_list_height(n)) >= last.end.y - 0.01,
		"콘텐츠 높이가 마지막 카드보다 짧다 — 끝까지 못 굴러간다")
	# 🔴 층 1겹 진에서 스크롤 없이 **3장**은 보여야 한다 (카드를 키운 대가의 하한선)
	var visible := 0
	for r2: Rect2 in rects:
		if r2.position.y >= list_top and r2.end.y <= BOOK_SIZE.y:
			visible += 1
	_check(visible >= 3, "스크롤 없이 보이는 고리가 %d장뿐이다 (카드를 너무 키웠나)" % visible)
	# 🔴 아이콘이 **카드 안에** 든다. `ring_icon_geom`은 "바깥 띠선 = 넘긴 반지름"만 보장하고
	# 그 반지름을 정하는 건 `_draw_*`의 `카드높이 × ICON_R_FRAC`이다 — 그래서 그 식을 여기서
	# 한 번 잰다(헤드리스는 `_draw`를 못 보므로 이게 유일한 관측점이다).
	# ⚠ 리드 뮤테이션이 잡은 구멍: ICON_R_FRAC을 0.60으로 올려도 전 항목이 그린이었다(아이콘이
	#   카드 밖으로 넘쳐 이웃 카드·이름을 덮는데 아무도 안 빨개졌다).
	var card: Rect2 = rects[0]
	var icon_r: float = card.size.y * float(_BookScript.ICON_R_FRAC)
	var icon_c: Vector2 = card.position + Vector2(card.size.y * 0.5, card.size.y * 0.5)
	_check(card.encloses(Rect2(icon_c - Vector2(icon_r, icon_r), Vector2(icon_r, icon_r) * 2.0)),
		"아이콘이 카드 밖으로 넘친다 (반지름 %.1f, 카드 높이 %.1f)" % [icon_r, card.size.y])
	_check(icon_r >= card.size.y * 0.3,
		"아이콘이 카드에 비해 너무 작다 (반지름 %.1f / 카드 %.1f)" % [icon_r, card.size.y])
	# 소켓도 같이 커졌다 — 소켓 아이콘 반지름 = 소켓 높이 × ICON_R_FRAC라 낮아지면 같이 작아진다.
	var socks: Array = _BookScript.band_socket_rects(2, BOOK_SIZE, top)
	for sr: Rect2 in socks:
		_check(sr.size.y >= 40.0, "층 소켓이 너무 낮다 (%.1f) — 아이콘이 도로 작아진다" % sr.size.y)
	_check((socks[1] as Rect2).end.y <= BOOK_SIZE.y, "층 2겹 진의 소켓이 책 밖으로 나갔다")


## 🔴 진이 더 늘어도 죽지 않는다 — 모르는 도형·자리 수·id는 폴백이지 크래시가 아니다.
## (`GLYPH_DESC`가 세션44~47에 인덱스 초과로 잠복 크래시를 냈던 자리와 같은 종류의 계약.)
func _test_unknown_jin_survives() -> void:
	var paths: Array = _BookScript.jin_icon_paths(99, 0, Vector2.ZERO, 17.0)
	_check(not paths.is_empty(), "모르는 도형도 아이콘 획이 나와야 한다 (폴백=원)")
	# rune_slots 0·음수도 자리 하나로 산다 — .tres에 안 적힌 옛 진이 셀에서 사라지면 안 된다.
	_check(paths.size() == 2, "rune_slots=0이면 자리 1개로 폴백 (윤곽1+룬1=2, 실제 %d)" % paths.size())
