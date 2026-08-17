extends RefCounted
## Landability, the straight line a boat may sail, and which harbour a boat returns to — the whole of
## `grid.gd`'s new coastline machinery from `boat-and-landing`, section 3 and 4.3. Hand-built fixtures
## only; nothing here reads a real island (`net_islands` owns the real grids and pins the plan's own
## measured counts against them, which is the strongest cross-check this file has).
##
## Every fixture below was verified by hand — computed outside Godot with the same arithmetic
## `grid.gd` runs (round-half-away-from-zero, `ceil(dist / Rules.LINE_SAMPLE_STEP)` samples, the
## Chebyshev-1 exemption) — before being written in here, precisely because hand-picked coordinates
## for a sub-tile sampler are exactly the kind of thing that "looks right" and isn't. Each fixture's
## comment names the mutation that must redden its check.


func run(t) -> void:
	_landable_orthogonal_vs_diagonal(t)
	_cliff_and_ramp(t)
	_headland_and_per_harbour_reach(t)
	_sampler_catches_a_one_tile_wall(t)
	_adjacent_tile_exemption(t)
	_home_harbour_never_strands(t)
	_start_harbour_is_neither_first_nor_last(t)
	_no_harbour_island_is_a_defined_noop(t)
	_sendable_computed_once(t)


## A harbour at (1,1). (1,2) touches it ORTHOGONALLY and is landable; (2,2) touches it only
## DIAGONALLY (its four orthogonal neighbours are all land) and must not be.
func _landable_orthogonal_vs_diagonal(t) -> void:
	var rows := [
		"~~~~~",
		"~H..~",
		"~...~",
		"~...~",
		"~~~~~",
	]
	var g := Grid.new()
	g.load_rows(rows)
	t.eq(int(g.landable[2 * 5 + 1]), 1,
		"물에 직교로 닿은 칸은 상륙지다 — grid.gd 에서 passable[t]==1 조건을 빼면 문다")
	t.eq(int(g.landable[2 * 5 + 2]), 0,
		"대각선으로만 물에 닿은 칸은 상륙지가 아니다 — Grid.NEIGHBOURS(8방향)로 바꾸면 문다")


## A cliff row (`^`) sitting between open water and the land behind it. The cliff tile itself is
## impassable, and — with no rule written for it — the land behind it is not landable either, because
## it has no orthogonal water neighbour any more. A ramp (`/`) in the same wall stays passable and
## landable.
func _cliff_and_ramp(t) -> void:
	var cliff_rows := [
		"~~~~~~~~",
		"^^^^^^^^",
		"........",
	]
	var cg := Grid.new()
	cg.load_rows(cliff_rows)
	t.eq(int(cg.passable[1 * 8 + 3]), 0, "절벽 칸은 지나갈 수 없다")
	t.eq(int(cg.landable[2 * 8 + 3]), 0,
		"절벽 뒤 땅은 상륙지가 아니다 — grid.gd 의 LAND_CHARS 에 '^' 를 넣으면 문다 (구조로 막힌다, 별도 규칙이 없다)")

	var ramp_rows := [
		"~~~~~~~~",
		"^^^/^^^^",
		"........",
	]
	var rg := Grid.new()
	rg.load_rows(ramp_rows)
	t.eq(int(rg.passable[1 * 8 + 3]), 1, "램프는 걸을 수 있다")
	t.eq(int(rg.landable[1 * 8 + 3]), 1,
		"램프가 물에 닿으면 상륙지다 — grid.gd 의 LAND_CHARS 에서 '/' 를 빼면 문다")


## A single-tile peninsula splits an otherwise open bay into a west shore and an east shore, with
## harbours on each side. Verified: the west harbour sees its own shore (A) and NOT the far one (B);
## the east harbour sees B and not A — the straight line from either harbour to the far shore is
## sampled onto the peninsula tile at (5,3), well outside the landing tile's own Chebyshev-1 exemption
## zone, so the exemption cannot rescue it.
func _headland_and_per_harbour_reach(t) -> void:
	var rows := [
		"~~~~~~~~~~~~",
		"~..........~",
		"~....#.....~",
		"~~~~~#~~~~~~",
		"~~H~~~~~~H~~",
	]
	var g := Grid.new()
	g.load_rows(rows)
	t.eq(g.harbour_tiles.size(), 2, "항구가 둘이다")
	var w := g.w
	var a := 2 * w + 2   # west shore, landable
	var b := 2 * w + 9   # east shore, landable, behind the peninsula from the west harbour
	t.eq(int(g.landable[a]), 1, "서쪽 해안은 상륙지다 (자가 점검)")
	t.eq(int(g.landable[b]), 1, "동쪽 해안도 상륙지다 (자가 점검)")

	t.ok(g.can_land_at(0, a), "서쪽 항구는 자기 쪽 해안을 볼 수 있다")
	t.ok(not g.can_land_at(0, b),
		"서쪽 항구는 곶 뒤의 동쪽 해안을 못 본다 — can_land_at 에서 water_line_clear 호출을 지우면 문다")
	t.ok(g.can_land_at(1, b), "동쪽 항구는 자기 쪽 해안을 볼 수 있다")
	t.ok(not g.can_land_at(1, a),
		"동쪽 항구는 곶 뒤의 서쪽 해안을 못 본다 — 항로 검사는 항구마다 따로 돈다는 뜻이다")
	# The two harbours disagree about the SAME two tiles, which is only possible if `sendable` is
	# indexed per harbour and not shared across them.
	t.ok(g.can_land_at(0, a) != g.can_land_at(1, a),
		"같은 칸을 두 항구가 다르게 판정한다 — sendable 을 항구 하나로 합치면 이 줄이 죽는다")


## `water_line_clear` sampled every 0.05 tiles must catch a wall exactly 1 tile wide that a coarse
## 1.0-tile sampler provably steps over. Verified outside Godot: with `Rules.LINE_SAMPLE_STEP` at 0.05
## a sample lands on the wall tile (3,1); with it widened to 1.0 (`ceil(dist/1.0)` = 8 samples) none of
## the eight integer-spaced samples ever lands there — the wall is a real gap the coarse sampler jumps.
func _sampler_catches_a_one_tile_wall(t) -> void:
	t.eq(Rules.LINE_SAMPLE_STEP, 0.05, "표본 간격은 0.05칸이다 (자가 점검 — 아래 수치는 이 값을 전제한다)")
	var rows := [
		"~~~~~~~~",
		"~~~#~~~~",
		"~~~~~~~~",
		"~~~~~~~~",
		"~~~~~~~~",
	]
	var g := Grid.new()
	g.load_rows(rows)
	t.ok(not g.water_line_clear(Vector2(0.0, 0.0), Vector2(7.0, 4.0)),
		"한 칸짜리 벽을 0.05칸 간격 표본이 잡아낸다 — Rules.LINE_SAMPLE_STEP 을 1.0 으로 바꾸면 이 벽을 건너뛰어 문다 (바깥에서 검증됨)")
	t.ok(g.water_line_clear(Vector2(0.0, 0.0), Vector2(0.0, 4.0)),
		"벽을 안 지나는 직선은 그대로 열려 있다 (자가 점검 — 전부 막는 검사기가 아니다)")


## A landing tile (10,5) with a land tile right next to it at (11,5) — a real coastal shape, two
## beaches side by side. A harbour at (13,5) sails a straight line THROUGH (11,5) on the way in;
## verified outside Godot: the sample at that tile is within Chebyshev-1 of the target and only the
## exemption saves it. Without the exemption this exact shore is refused for grazing its own
## neighbour, which is the failure `Rules.LINE_SAMPLE_EXEMPT_CHEBYSHEV` exists to prevent.
func _adjacent_tile_exemption(t) -> void:
	var rows := []
	for y in 10:
		if y == 5:
			rows.append("~~~~~~~~~~..~H~~")
		else:
			rows.append("~".repeat(16))
	var g := Grid.new()
	g.load_rows(rows)
	var b := 5 * 16 + 10   # (10,5), landable via its west neighbour (9,5)
	t.eq(int(g.landable[b]), 1, "상륙지 자체는 유효하다 (자가 점검)")
	t.eq(int(g.passable[5 * 16 + 11]), 1, "바로 옆(11,5)도 땅이다 (자가 점검 — 스칠 대상이 있다)")
	t.ok(g.can_land_at(0, b),
		"살짝 스치는 접근은 거절하지 않는다 — Rules.LINE_SAMPLE_EXEMPT_CHEBYSHEV 를 0으로 바꾸면 " +
		"바로 옆(11,5) 땅을 스쳤다는 이유로 이 항로가 막힌다")


## Three harbours: one sits closest to a landing tile in raw distance but is walled off from it; a
## second, farther harbour has a clear line and is the correct answer; a third, farther still, ALSO
## has a clear line and must lose to the second. Verified outside Godot:
##   harbour 0 (3,4)  — visible,  dist 4.47   <- the answer
##   harbour 1 (10,4) — BLOCKED,  dist 3.61   <- nearest by raw distance, and wrong
##   harbour 2 (0,5)  — visible,  dist 7.62   <- also visible, but farther than 0
func _home_harbour_never_strands(t) -> void:
	var rows := [
		"~~~~~~~~~~~~~~~~",
		"~..............~",
		"~..............~",
		"~~~~~~~~~#~~~~~~",
		"~~~H~~~~~~H~~~~~",
		"H~~~~~~~~~~~~~~~",
	]
	var g := Grid.new()
	g.load_rows(rows)
	t.eq(g.harbour_tiles.size(), 3, "항구가 셋이다")
	var w := g.w
	var b := 2 * w + 7
	t.eq(int(g.landable[b]), 1, "상륙지 자체는 유효하다 (자가 점검)")
	t.ok(g.can_land_at(0, b), "항구 0(멀지만 보임)은 그 상륙지를 볼 수 있다")
	t.ok(not g.can_land_at(1, b),
		"항구 1(제일 가깝지만 벽 뒤)은 그 상륙지를 못 본다 — 이게 갇히는 함정이다")
	t.ok(g.can_land_at(2, b), "항구 2(더 멀지만 보임)도 그 상륙지를 볼 수 있다")

	t.eq(g.home_harbour_for(b), 0,
		"돌아갈 항구는 '보이는 것 중 가장 가까운' 항구 0이다 — can_land_at 필터를 빼면 " +
		"제일 가깝지만 못 보는 항구 1을 골라 상륙 거점을 고립시킨다")
	# And among the two that DO qualify, the nearer of the two — not merely the first one found.
	t.ok(g.home_harbour_for(b) != 2,
		"보이는 항구가 둘일 때는 그중 더 가까운 쪽을 고른다 — 첫 번째로 찾은 항구를 그냥 쓰면 문다")


## Three harbours where the answer is neither index 0 nor the last index — `net_islands` alone could
## never catch "start_harbour = 0" or "start_harbour = harbour_tiles.size() - 1" as a stand-in for the
## real rule, because the start harbour happens to be the LAST one on all three real islands. Verified
## outside Godot: harbours (7,0) · (3,4) · (10,4) row-major-index to 0, 1, 2, and harbour 1's own
## nearest reachable coast (4.47 tiles) is farther than either neighbour's (harbour 0: 2.24, harbour 2:
## 3.16) — so the answer is the MIDDLE one.
func _start_harbour_is_neither_first_nor_last(t) -> void:
	var rows := [
		"~~~~~~~H~~~~~~~~",
		"~..............~",
		"~..............~",
		"~~~~~~~~~#~~~~~~",
		"~~~H~~~~~~H~~~~~",
		"~~~~~~~~~~~~~~~~",
	]
	var g := Grid.new()
	g.load_rows(rows)
	t.eq(g.harbour_tiles.size(), 3, "항구가 셋이다 (자가 점검)")
	var got: Array = []
	for hb in g.harbour_tiles:
		got.append(int(hb))
	t.eq(got, [7, 67, 74], "항구 타일이 행 우선 순서로 (7,0)·(3,4)·(10,4) 다 (자가 점검)")
	t.eq(g.start_harbour, 1,
		"함대는 첫 번째도 마지막도 아닌, 자기 해안에서 가장 먼 가운데 항구에서 시작한다 — " +
		"인덱스 0이나 size()-1 로 대신하면 이 픽스처에서만 문다")


## An island authored with no `H` at all must be a defined no-op, not a bark: `harbour_tiles` empty,
## `start_harbour == -1`, `sendable` empty, `can_land_at` false everywhere. At the stage-1 halt every
## existing fixture and every real island (pre-`boat-and-landing`) has zero harbours, so this is the
## NORMAL case this round, not an edge case.
func _no_harbour_island_is_a_defined_noop(t) -> void:
	var rows := [
		"~~~~~",
		"~...~",
		"~...~",
		"~...~",
		"~~~~~",
	]
	var g := Grid.new()
	g.load_rows(rows)
	t.eq(g.harbour_tiles.size(), 0, "항구가 없는 섬이다 (자가 점검)")
	t.eq(g.start_harbour, -1,
		"항구가 없으면 시작 항구는 -1이다 — _derive_start_harbour 의 best 초기값을 0으로 바꾸면 " +
		"없는 0번 항구를 가리키게 되어 문다")
	t.eq(g.sendable.size(), 0, "sendable 배열도 비어 있다")
	var any_true := false
	for tile in g.landable.size():
		if g.can_land_at(0, tile):
			any_true = true
	t.ok(not any_true, "항구가 없으면 can_land_at 은 어디서도 참이 아니다 — 짖지도 않는다")


## `sendable` is filled once inside `load_rows`; `can_land_at` only ever reads it back. Driving
## `can_land_at` sixty times (one per pumped frame, the way the drag overlay will) must not move
## `line_tests` — if it moved, the straight-line sampler would be re-running at drag-overlay
## frequency, which the plan measures at ~750k operations a frame against a real island.
func _sendable_computed_once(t) -> void:
	var rows := [
		"~~~~~~~~~~~~~~~~",
		"~..............~",
		"~..............~",
		"~~~~~~~~~#~~~~~~",
		"~~~H~~~~~~H~~~~~",
		"H~~~~~~~~~~~~~~~",
	]
	var g := Grid.new()
	g.load_rows(rows)
	var after_load := g.line_tests
	t.ok(after_load > 0, "섬을 불러오는 동안 항로 검사가 실제로 돌았다 (%d번)" % after_load)
	var w := g.w
	var b := 2 * w + 7
	for _f in 60:
		g.can_land_at(0, b)
		g.can_land_at(1, b)
		g.can_land_at(2, b)
	t.eq(g.line_tests, after_load,
		"60번 다시 물어도 항로 검사 횟수가 안 늘었다 — can_land_at 이 water_line_clear 를 직접 부르게 " +
		"바꾸면 이 줄이 매 프레임 다시 돈다")
