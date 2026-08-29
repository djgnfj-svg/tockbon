extends RefCounted
## **The line a body actually walks.** 티켓 37.
##
## The claim under test is one sentence: **a body told to walk across open ground walks a straight line,
## and the walk bends only where the ground makes it bend.**
##
## ⚠⚠ **WHY 「DID IT ARRIVE」 CANNOT MEASURE THIS.** The defect the user saw — a straight walk arcing to
## the top of the board — arrives perfectly. Every reachability check in this repo stayed green through
## it. `how-nets-lie`: *a check that reads only final state cannot measure an ordering contract.* ⇒ **the
## field's VALUES are asserted against a formula, and the walk's SHAPE against its own straight segment.**
##
## ⚠ **Every literal below is derived from the octile identity and not read off a run**: the cheapest an
## 8-connected walk between two 조각 can cost is `ORTHO * max(|dx|,|dy|) + (DIAG - ORTHO) * min(|dx|,|dy|)`,
## because such a walk takes exactly `min` diagonal steps and `max - min` orthogonal ones.


## The two costs, read from `Rules` and never typed. A check that hardcodes 10 and 14 stops measuring the
## constants the day one of them moves.
const ORTHO := Rules.STEP_COST_ORTHO
const DIAG := Rules.STEP_COST_DIAG

const WALK_ID := 830_001
const OTHER_ID := 830_002


func run(t) -> void:
	_the_heap_orders(t)
	_the_empty_board_field_is_octile(t)
	_a_diagonal_costs_more_than_an_orthogonal(t)
	_the_straight_walk_has_no_turn(t)
	_the_knights_angle_stays_near_the_line(t)
	_the_queue_at_a_neck_survives(t)
	_the_hold_is_never_wider_than_two(t)
	_keep_level_still_refuses(t)
	_a_line_between_two_tiles_is_octile_exact(t)
	_path_from_touches_nothing(t)
	_path_from_hands_back_a_walkable_list(t)
	_string_pull_takes_a_corner_out(t)
	_string_pull_never_lengthens(t)
	_string_pull_will_not_cross_a_stair_flank(t)
	_step_along_refuses_a_tile_that_is_not_adjacent(t)
	_step_along_refuses_what_somebody_else_holds(t)
	_the_body_actually_walks_the_stored_route(t)
	_a_blocked_next_tile_falls_back_to_the_field(t)
	_a_re_order_replaces_the_route(t)
	_the_pulled_route_of_all_four_probe_walks_hugs_its_line(t)


# == the heap =========================================================================================

## **Ordering is the one thing a 「did the body arrive」 check can never see**, so it is measured directly:
## push out of order, pop everything, and read what comes back.
## ⚠ **The COUNT is asserted beside the order.** An empty heap pops nothing, and「every popped cost was
## ascending」is vacuously true of nothing at all.
func _the_heap_orders(t) -> void:
	var heap := IntHeap.new()
	var costs := [50, 14, 90, 10, 24, 10, 1, 38, 24, 7, 100, 3]
	for k in costs.size():
		heap.push(int(costs[k]), 700 + k)
	t.eq(heap.size(), costs.size(), "밀어 넣은 만큼 들어 있다 (자가 점검)")
	var popped := []
	var out_of_order := 0
	var last := -1
	while not heap.is_empty():
		var value := heap.pop_value()
		if heap.last_cost < last:
			out_of_order += 1
		last = heap.last_cost
		popped.append(value)
	t.eq(popped.size(), costs.size(), "꺼낸 개수가 넣은 개수와 같다 — 빈 힙으로 얻은 초록이 아니다")
	t.eq(out_of_order, 0, "그리고 꺼낸 값이 값싼 것부터 나온다 — 순서가 뒤집힌 자리가 없다")
	# Every pushed value came back, so ordering was not bought by dropping pairs.
	var seen := {}
	for v in popped:
		seen[v] = true
	t.eq(seen.size(), costs.size(), "넣은 값이 하나도 안 없어졌다 (자가 점검)")
	t.eq(heap.pop_value(), -1, "빈 힙에서 꺼내면 조각일 수 없는 -1 이 나온다")


# == the field ========================================================================================

## **The whole field against its closed form, on 288 조각 rather than one.** On an empty board the exact
## answer is known, so nothing here is a spot check.
##
## ⚠⚠ **IT MEASURES THE RELAXATION, NOT THE POP ORDER, AND THIS FILE SAID OTHERWISE FOR A DRAFT.**
## Measured 2026-08-29, twice: scramble the heap — or swap it for a plain first-in-first-out queue — and
## **all 288 조각 stay exact**, because the flood re-pushes a 조각 every time its value improves and
## therefore converges whatever order it pops in. **Take the re-push away as well and 223 of the 288 go
## wrong.** ⇒ **The heap buys speed, not correctness**, and the one thing that measures ordering is
## `_the_heap_orders`. A row that claimed to catch a FIFO here would be a label promising more than it
## can see.
func _the_empty_board_field_is_octile(t) -> void:
	var g := _empty(24, 12)
	var tx := 20
	var ty := 6
	var field := g.flow_field(g.tile_index(tx, ty))
	t.eq(field.size(), 24 * 12, "24 x 12 판의 흐름장이 288 조각이다 (자가 점검)")
	var wrong := 0
	var first := ""
	for tile in field.size():
		var x := tile % g.w
		var y := tile / g.w
		var want := _octile(x, y, tx, ty)
		if int(field[tile]) != want:
			wrong += 1
			if first == "":
				first = "(%d,%d) %d 대신 %d" % [x, y, want, int(field[tile])]
	t.eq(wrong, 0, "빈 판 288 조각의 값이 전부 옥타일 정확값이다 — 어긋난 첫 조각: %s" % first)


## The two constants named apart. Setting them equal — which is what an unweighted flood is — reddens this
## and nothing about arrival.
##
## ⚠⚠ **THE TWO EQUALITIES CANNOT SEE THE CONSTANTS MOVE AND THAT WAS MEASURED.** They take their
## expectation from `Rules` too, so setting `STEP_COST_DIAG` to 10 leaves both green — the row would be a
## label claiming three measurements and making one. ⇒ **The claim is also stated with no constant on the
## expectation side at all**, as two field values read off the same board and bounded at BOTH ends: a
## diagonal 조각 four away costs more than an orthogonal one four away, and less than two of them.
## `how-nets-lie` — *a ceiling with no floor passes an effect that never happens*, and here a floor with
## no ceiling would pass a diagonal that costs a hundred.
func _a_diagonal_costs_more_than_an_orthogonal(t) -> void:
	var g := _empty(24, 12)
	var field := g.flow_field(g.tile_index(10, 6))
	var straight := int(field[g.tile_index(14, 6)])
	var slanted := int(field[g.tile_index(14, 10)])
	t.eq(straight, 4 * ORTHO, "곧게 넉 조각은 직교 걸음 넷 값이다")
	t.eq(slanted, 4 * DIAG, "대각으로 넉 조각은 대각 걸음 넷 값이다")
	# Constant-free, both ends. The upper bound is the same measured number doubled — walking four east
	# and then four south is what a diagonal must beat, and it is read off this board, not typed.
	t.ok(slanted > straight,
		"그래서 대각선 지름길이 공짜가 아니다 (%d > %d)" % [slanted, straight])
	t.ok(slanted < 2 * straight,
		"그러면서도 직교 두 번 도는 것보다는 싸다 (%d < %d) — 대각이 걸을 이유가 있다" % [slanted, 2 * straight])


# == the shape of the walk ============================================================================

## **The defect the user saw, stated as a number.** A(2,6) -> B(20,6) on an empty board is eighteen
## orthogonal steps and not one turn. What was measured 2026-08-29 was an arc to the top of the board.
func _the_straight_walk_has_no_turn(t) -> void:
	var g := _empty(24, 12)
	var walk := _walk_tiles(g, Vector2i(2, 6), Vector2i(20, 6))
	t.eq(walk.size(), 19, "곧게 동쪽으로 가는 걸음이 19 조각이다 — 곁길이 없다")
	t.eq(_turns(g.w, walk), 0, "그리고 한 번도 안 꺾인다")


## **The tie-break that drifts even when the cost is right.** A(2,10) -> B(20,2) is eight diagonals and ten
## orthogonals, interleaved any way at all — every ordering of them costs the same, so cost alone says
## nothing about the line. ⚠⚠ **This is the row that catches key 1 being the neighbour's own field value
## instead of the total cost of the route through it**: ranked that way the diagonal always wins outright,
## the walk runs all its diagonals first, and every check about arrival, cost and reachability is green.
func _the_knights_angle_stays_near_the_line(t) -> void:
	var g := _empty(24, 12)
	var a := Vector2i(2, 10)
	var b := Vector2i(20, 2)
	var walk := _walk_tiles(g, a, b)
	t.eq(int(walk[walk.size() - 1]), g.tile_index(b.x, b.y), "비스듬한 걸음이 실제로 B 에 닿는다 (자가 점검)")
	t.eq(walk.size(), 19, "그리고 18 걸음이다 — 옥타일 최단과 같은 길이다")
	var worst := _worst_offset(g, walk, a, b)
	t.ok(worst <= 1.0, "직선에서 가장 멀리 벗어난 조각이 1.0 조각 이내다 (%.2f)" % worst)


# == what must not break ==============================================================================

## **Measured behaviour the brief says must not break.** Two bodies and a one-조각 doorway: the one that
## does not hold the door stands still.
##
## ⚠ **The control is the whole row.** 「the second body did not move」 is equally true of a walker that is
## simply broken, so the same body is asked again with the door free and must move.
func _the_queue_at_a_neck_survives(t) -> void:
	var g := Grid.new()
	g.load_rows(_DOOR_ROWS)
	var goal := g.tile_index(5, 2)
	var field := g.flow_field(goal)
	var door := g.tile_index(3, 2)
	t.eq(g.level_of(door), 0, "문 조각을 잡았다 (자가 점검)")
	t.ok(g.passable[door] != 0 and g.passable[g.tile_index(3, 1)] == 0
			and g.passable[g.tile_index(3, 3)] == 0,
		"그리고 그 줄에서 지나갈 수 있는 조각은 그 하나뿐이다 (자가 점검)")

	# The other body takes the door first.
	g.step_toward(OTHER_ID, Vector2(2.0, 2.0), field)
	t.eq(int(g.reserved[door]), OTHER_ID, "다른 몸이 문을 잡았다 (자가 점검)")

	var from := Vector2(2.0, 2.0)
	var stood := g.step_toward(WALK_ID, from, field)
	t.ok(stood.is_equal_approx(from), "문이 잡혀 있으면 뒤에 선 몸은 제자리에 선다 — 목이 좁은 줄")

	# The control: free the door and the very same body walks through it.
	g.release_all(OTHER_ID)
	var moved := g.step_toward(WALK_ID, from, field)
	t.ok(not moved.is_equal_approx(from), "문이 비면 그 몸이 실제로 지나간다 (대조군 — 보행자가 고장난 게 아니다)")


## **Never wider than two, after any number of steps.** A body that claims a third 조각 halves every
## doorway with nothing on screen to explain it.
func _the_hold_is_never_wider_than_two(t) -> void:
	var g := _empty(24, 12)
	var field := g.flow_field(g.tile_index(20, 6))
	var at := Vector2(2.0, 6.0)
	var worst := 0
	var steps := 0
	for _i in 40:
		var next := g.step_toward(WALK_ID, at, field)
		if next.is_equal_approx(at):
			break
		at = next
		steps += 1
		worst = maxi(worst, _held_count(g, WALK_ID))
	t.ok(steps >= 10, "걸음을 %d 번 실제로 뗐다 (자가 점검 — 0 걸음짜리 초록이 아니다)" % steps)
	t.eq(worst, 2, "그 걸음 내내 한 몸이 잡은 조각이 최대 둘이다")


## **A body that may not leave its own level does not step down its own stair.**
func _keep_level_still_refuses(t) -> void:
	var g := Grid.new()
	g.load_rows(_STAIR_ROWS, _STAIR_TIERS)
	var stair := g.tile_index(2, 3)
	var on_high := Vector2(3.0, 3.0)
	t.eq(g.level_of(stair), 1, "계단 조각을 잡았다 (자가 점검)")
	t.eq(g.level_at(3, 3), 2, "그리고 몸이 선 자리가 2층이다 (자가 점검)")
	var field := g.flow_field(g.tile_index(1, 3))
	t.ok(int(field[g.tile_index(3, 3)]) != Grid.UNREACHABLE, "계단을 통해 내려가는 길이 있다 (자가 점검)")

	var held := g.step_toward(WALK_ID, on_high, field, 2)
	t.ok(held.is_equal_approx(on_high), "keep_level 이 2 면 몸이 제 계단으로 안 내려간다")
	g.release_all(WALK_ID)
	var free := g.step_toward(WALK_ID, on_high, field)
	t.ok(free.is_equal_approx(Vector2(2.0, 3.0)),
		"keep_level 이 없으면 같은 몸이 그 계단으로 내려간다 (대조군, %s)" % str(free))


# == the route ========================================================================================

## ⚠⚠ **THE ROW THAT WOULD HAVE CAUGHT THE RASTERISER, AND IT IS EVERY PAIR ON A BOARD RATHER THAN ONE
## FIXTURE.** 티켓 37's first draft sampled the segment every quarter 조각 and rounded each axis on its
## own, which emits a separate orthogonal step per axis crossing — **the straightener made the walk
## longer.** A single fixture can pass that by luck; 144 x 144 pairs cannot.
func _a_line_between_two_tiles_is_octile_exact(t) -> void:
	var g := _empty(12, 12)
	var pairs := 0
	var wrong_len := 0
	var wrong_cost := 0
	var not_adjacent := 0
	for a in g.w * g.h:
		for b in g.w * g.h:
			if a == b:
				continue
			pairs += 1
			var line := g.line_tiles(a, b)
			var ax := a % g.w
			var ay := a / g.w
			var dx := absi(b % g.w - ax)
			var dy := absi(b / g.w - ay)
			if line.size() != maxi(dx, dy):
				wrong_len += 1
			if _line_cost(g, a, line) != _octile(ax, ay, b % g.w, b / g.w):
				wrong_cost += 1
			var prev := a
			for raw in line:
				var nt := int(raw)
				if absi(nt % g.w - prev % g.w) > 1 or absi(nt / g.w - prev / g.w) > 1:
					not_adjacent += 1
				prev = nt
	t.eq(pairs, 144 * 143, "12 x 12 판의 모든 조각 짝을 다 걸었다 (자가 점검)")
	t.eq(wrong_len, 0, "모든 짝에서 직선의 걸음 수가 max(|dx|,|dy|) 다")
	t.eq(wrong_cost, 0, "그리고 그 값이 옥타일 최소값과 정확히 같다 — 곧게 그은 선이 최단이다")
	t.eq(not_adjacent, 0, "그 선의 이웃한 조각끼리는 전부 여덟 방향 이웃이다")


## ⚠⚠ **A QUERY THAT RESERVED WOULD PUT A BODY'S OWN HOLD IN THE WAY OF ITS OWN ROUTE.** The whole
## reservation table is compared 조각 by 조각, and the grid's own hold table has to stay empty.
## ⚠ **The control is what makes the emptiness mean something**: the very same grid, asked for one step
## instead, DOES claim a 조각 — so 「nothing was reserved」 is not just a table nobody could write to.
func _path_from_touches_nothing(t) -> void:
	var g := _empty(24, 12)
	var target := g.tile_index(20, 6)
	var field := g.flow_field(target)
	var before := g.reserved.duplicate()
	var path := g.path_from(field, g.tile_index(2, 6), target)
	t.ok(path.size() > 1, "길을 실제로 하나 받았다 (자가 점검, %d 조각)" % path.size())
	var moved := 0
	for tile in g.reserved.size():
		if int(g.reserved[tile]) != int(before[tile]):
			moved += 1
	t.eq(moved, 0, "길을 물어봐도 예약표가 한 조각도 안 바뀐다")
	t.eq(g._held.size(), 0, "그리고 아무도 조각을 쥐지 않았다")

	g.step_toward(WALK_ID, Vector2(2.0, 6.0), field, -1, target)
	t.ok(g._held.size() > 0, "같은 격자에 한 걸음을 시키면 실제로 쥔다 (대조군 — 쥐는 표가 죽어 있는 게 아니다)")


## **A list that reads plausible and cannot be walked is the failure this rules out.**
func _path_from_hands_back_a_walkable_list(t) -> void:
	var g := Grid.new()
	g.load_rows(_WALL_ROWS)
	var target := g.tile_index(1, 6)
	var path := g.path_from(g.flow_field(target), g.tile_index(1, 1), target)
	t.ok(path.size() > 8, "벽을 돌아가는 길이 %d 조각이다 (자가 점검 — 한 조각짜리가 아니다)" % path.size())
	t.eq(int(path[0]), g.tile_index(1, 1), "그 길이 몸이 선 조각에서 시작한다")
	t.eq(int(path[path.size() - 1]), target, "그리고 목적 조각에서 끝난다")
	var broken := 0
	for i in range(1, path.size()):
		if not g.can_step(int(path[i - 1]), int(path[i])):
			broken += 1
	t.eq(broken, 0, "그 길의 이웃한 조각끼리 전부 can_step 을 통과한다 — 실제로 걸을 수 있는 목록이다")


## ⚠⚠ **A PULL THAT SILENTLY RETURNS ITS INPUT IS THE INVISIBLE FAILURE HERE**, and an A/B comparison
## against the raw route catches 「diverged」 and never 「vanished」 (`how-nets-lie`). ⇒ **The turn count and
## the cost both have to DROP, on a route where a corner is provably removable.**
##
## ⚠ **The input is a hand-written dog-leg rather than the field's own descent, and that is deliberate.**
## The descent is already cost-optimal, so a pull can never make it cheaper and 「fewer turns」 would be a
## number nobody could derive without running it. **A right angle on open ground is provable by hand**:
## eight 조각 east and eight south is sixteen orthogonal steps with one turn, and the straight line
## between its ends is eight diagonal steps with none.
func _string_pull_takes_a_corner_out(t) -> void:
	var g := _empty(24, 12)
	var raw := PackedInt32Array()
	raw.append(g.tile_index(2, 2))
	for x in range(3, 11):
		raw.append(g.tile_index(x, 2))
	for y in range(3, 11):
		raw.append(g.tile_index(10, y))
	t.eq(raw.size(), 17, "직각으로 꺾인 길 17 조각을 손으로 지었다 (자가 점검)")
	t.eq(_turns(g.w, raw), 1, "그 길은 한 번 꺾인다 (자가 점검)")
	t.eq(_line_cost(g, int(raw[0]), _tail(raw)), 16 * ORTHO, "그리고 직교 열여섯 걸음 값이다 (자가 점검)")

	var pulled := g.string_pull(raw)
	t.eq(_turns(g.w, pulled), 0, "당긴 길은 한 번도 안 꺾인다 — 모서리가 실제로 빠졌다")
	t.eq(pulled.size(), 9, "그리고 대각 여덟 걸음으로 줄었다")
	t.eq(_line_cost(g, int(pulled[0]), _tail(pulled)), 8 * DIAG, "값도 대각 여덟 걸음 값이다")
	t.ok(_line_cost(g, int(pulled[0]), _tail(pulled)) < _line_cost(g, int(raw[0]), _tail(raw)),
		"곧 당긴 길이 원래 길보다 싸다 — 입력을 그대로 돌려준 게 아니다")
	t.eq(int(pulled[0]), int(raw[0]), "출발 조각은 그대로다")
	t.eq(int(pulled[pulled.size() - 1]), int(raw[raw.size() - 1]), "도착 조각도 그대로다")


## **「the smoothing made it longer」 is the one way this fails invisibly**, so it is asked on every board
## in this file rather than on one.
func _string_pull_never_lengthens(t) -> void:
	var boards := [
		[_empty(24, 12), Vector2i(2, 6), Vector2i(20, 6)],
		[_empty(24, 12), Vector2i(2, 10), Vector2i(20, 2)],
		[_loaded(_WALL_ROWS, []), Vector2i(1, 1), Vector2i(1, 6)],
		[_loaded(_DOOR_ROWS, []), Vector2i(1, 2), Vector2i(5, 2)],
		[_loaded(_STAIR_ROWS, _STAIR_TIERS), Vector2i(1, 1), Vector2i(4, 3)],
	]
	var longer := 0
	var dearer := 0
	var unwalkable := 0
	var measured := 0
	for raw_board in boards:
		var board: Array = raw_board
		var g: Grid = board[0]
		var a: Vector2i = board[1]
		var b: Vector2i = board[2]
		var target := g.tile_index(b.x, b.y)
		var path := g.path_from(g.flow_field(target), g.tile_index(a.x, a.y), target)
		if path.size() < 2:
			continue
		measured += 1
		var pulled := g.string_pull(path)
		if pulled.size() > path.size():
			longer += 1
		if _line_cost(g, int(pulled[0]), _tail(pulled)) > _line_cost(g, int(path[0]), _tail(path)):
			dearer += 1
		for i in range(1, pulled.size()):
			if not g.can_step(int(pulled[i - 1]), int(pulled[i])):
				unwalkable += 1
	t.eq(measured, boards.size(), "다섯 판 전부에서 실제로 길이 나왔다 (자가 점검 — 빈 반복이 아니다)")
	t.eq(longer, 0, "당긴 길이 원래보다 조각이 많아진 판이 하나도 없다")
	t.eq(dearer, 0, "그리고 값이 비싸진 판도 하나도 없다")
	t.eq(unwalkable, 0, "당긴 길은 전부 실제로 걸을 수 있다")


## ⚠⚠ **THE INSTRUMENT'S OWN INVERSION.** A stair is entered at its ends only, so a straightener that
## tested plain passability would send a body up the staircase's flank — 티켓 22's subject, which this
## ticket must not feed. **Swap `line_tiles`'s `can_step` for a `passable` test and this row goes red**,
## while every check about cost and arrival stays green.
##
## The board is the corner stair. The body starts on the floor NORTH-WEST of the stair and the goal is on
## the plateau east of it, so the straight line between the route's ends runs across the staircase's north
## flank and across the plateau wall. ⚠ **The 조각 the line would cross are both checked**: entering the
## stair sideways, and stepping onto the plateau over its own wall.
func _string_pull_will_not_cross_a_stair_flank(t) -> void:
	var g := _loaded(_STAIR_ROWS, _STAIR_TIERS)
	var stair := g.tile_index(2, 3)
	var from := g.tile_index(1, 1)
	var target := g.tile_index(4, 3)
	t.eq(g.level_of(stair), 1, "계단 조각을 잡았다 (자가 점검)")
	t.eq(g.level_of(from), 0, "몸은 계단 북서쪽 바닥에 선다 (자가 점검)")
	t.eq(g.level_of(target), 2, "그리고 목적지는 계단 머리 너머 고원이다 (자가 점검)")
	t.ok(not g.can_step(g.tile_index(2, 2), stair), "계단 북쪽 옆면으로는 못 올라간다 (자가 점검)")
	t.ok(not g.can_step(g.tile_index(2, 2), g.tile_index(3, 2)), "고원 벽도 옆에서는 못 넘는다 (자가 점검)")

	var path := g.path_from(g.flow_field(target), from, target)
	t.ok(path.size() > 2, "계단을 돌아 오르는 길이 %d 조각이다 (자가 점검)" % path.size())
	var pulled := g.string_pull(path)
	var broken := 0
	var sideways := 0
	for i in range(1, pulled.size()):
		var a := int(pulled[i - 1])
		var b := int(pulled[i])
		if not g.can_step(a, b):
			broken += 1
		if _is_sideways_onto_a_stair(g, a, b):
			sideways += 1
	t.eq(broken, 0, "당긴 길의 이웃한 조각끼리 전부 can_step 을 통과한다 — 계단 벽을 안 넘는다")
	t.eq(sideways, 0, "그리고 계단에 옆면으로 들어서는 걸음이 하나도 없다")
	t.eq(int(pulled[pulled.size() - 1]), target, "그러면서도 목적지에는 닿는다 (대조군 — 길을 지운 게 아니다)")


## ⚠⚠ **`can_step` SAYS `true` TO BOTH OF THESE.** Measured 2026-08-29: it asks about bounds,
## passability, the level gap, the stair face and a diagonal's shoulders, **and never whether the two
## 조각 touch**. Delete the adjacency test in `step_along` and this is the only row that goes red.
func _step_along_refuses_a_tile_that_is_not_adjacent(t) -> void:
	var g := _empty(24, 12)
	var from := Vector2(6.0, 5.0)
	var two_away := g.tile_index(8, 5)
	var far := g.tile_index(20, 5)
	t.ok(g.can_step(g.tile_index(6, 5), two_away), "can_step 은 두 조각 건너에도 참이라고 답한다 (자가 점검)")
	t.ok(g.can_step(g.tile_index(6, 5), far), "열네 조각 건너에도 참이라고 답한다 (자가 점검)")

	t.ok(g.step_along(WALK_ID, from, two_away).is_equal_approx(from), "두 조각 건너로는 안 미끄러진다")
	t.eq(int(g.reserved[two_away]), -1, "그리고 그 조각을 예약하지도 않는다")
	t.ok(g.step_along(WALK_ID, from, far).is_equal_approx(from), "열네 조각 건너로도 안 미끄러진다")
	t.eq(int(g.reserved[far]), -1, "그 조각도 예약 안 된다")

	# The control: the very same call with a real neighbour moves, so the refusals above are not a
	# function that refuses everything.
	var next := g.tile_index(7, 5)
	t.ok(g.step_along(WALK_ID, from, next).is_equal_approx(Vector2(7.0, 5.0)),
		"이웃한 조각으로는 그대로 간다 (대조군)")
	t.eq(int(g.reserved[next]), WALK_ID, "그리고 그 조각을 쥔다")


## The route is a second way to step, and a second way to step that did not honour reservation is two
## bodies walking through each other with every reservation check green.
func _step_along_refuses_what_somebody_else_holds(t) -> void:
	var g := _empty(24, 12)
	var from := Vector2(6.0, 5.0)
	var next := g.tile_index(7, 5)
	var claimed := g.reserved
	claimed[next] = OTHER_ID
	g.reserved = claimed
	t.ok(g.step_along(WALK_ID, from, next).is_equal_approx(from), "남이 쥔 조각으로는 안 간다")
	t.eq(int(g.reserved[next]), OTHER_ID, "그리고 그 조각의 임자가 안 바뀐다")
	t.ok(_held_count(g, WALK_ID) <= 1, "거절당한 몸은 제가 선 조각 하나만 쥐고 있다")

	# keep_level refuses on the route too, not only on the field.
	var s := _loaded(_STAIR_ROWS, _STAIR_TIERS)
	var head := Vector2(3.0, 3.0)
	var stair := s.tile_index(2, 3)
	t.eq(s.level_of(stair), 1, "계단 조각을 잡았다 (자가 점검)")
	t.ok(s.step_along(WALK_ID, head, stair, 2).is_equal_approx(head),
		"keep_level 이 2 면 길 위의 걸음도 계단으로 안 내려간다")
	s.release_all(WALK_ID)
	t.ok(s.step_along(WALK_ID, head, stair).is_equal_approx(Vector2(2.0, 3.0)),
		"keep_level 이 없으면 같은 걸음이 실제로 내려간다 (대조군)")


# == the body on the route ============================================================================

## ⚠⚠ **THE ROW THAT PROVES THE STORED ROUTE IS ACTUALLY CONSUMED, AND WITHOUT IT EVERY OTHER ROW HERE
## IS GREEN WITH THE WHOLE `battle` HALF DEAD.** On an empty board the field's own descent already walks
## a straight line, so 「the body walked straight」 says nothing about whether it read its route.
## ⇒ **The stored route is replaced with one that leads somewhere else**, and the body has to follow it.
## Delete `_next_goal`'s route branch and the body walks the field's straight line instead: `min y` stays
## at 6 and this reddens.
func _the_body_actually_walks_the_stored_route(t) -> void:
	var b := _battle(24, 12)
	var g := b.grid
	var dest := g.tile_index(20, 6)
	t.eq(b.place_ashore(0, g.tile_index(2, 6)), g.tile_index(2, 6), "몸이 (2,6) 에 섰다 (자가 점검)")
	t.ok(b.order_walk(0, dest), "그리고 (20,6) 으로 가라는 명령을 받았다 (자가 점검)")

	var stored: PackedInt32Array = b._soldier_path[0]
	t.ok(stored.size() > 1, "명령을 받는 순간 길이 실제로 만들어졌다 (%d 조각)" % stored.size())
	t.eq(int(stored[0]), g.tile_index(2, 6), "그 길은 몸이 선 조각에서 시작한다")
	t.eq(int(b._soldier_path_i[0]), 1, "그리고 다음 조각을 가리키는 자리가 1 이다")

	# The control arm: left alone, the field and the route agree and the body never leaves row 6.
	t.eq(_lowest_row(b, 4.0), 6, "손대지 않으면 몸이 6 행을 한 번도 안 벗어난다 (대조군)")

	# The poisoned arm: the same order, a route that veers north, and the body has to take it.
	var b2 := _battle(24, 12)
	var g2 := b2.grid
	b2.place_ashore(0, g2.tile_index(2, 6))
	b2.order_walk(0, dest)
	var veer := PackedInt32Array()
	veer.append(g2.tile_index(2, 6))
	veer.append(g2.tile_index(3, 5))
	veer.append(g2.tile_index(4, 4))
	veer.append(g2.tile_index(5, 3))
	b2._soldier_path[0] = veer
	b2._soldier_path_i[0] = 1
	t.ok(_lowest_row(b2, 4.0) <= 4, "길을 북쪽으로 바꿔 놓으면 몸이 그 길을 따라간다 — 흐름장이 아니라")


## **The fallback is the whole safety of this design.** The route's next 조각 is taken by somebody else,
## and the body still has to move — down the field, around the block.
func _a_blocked_next_tile_falls_back_to_the_field(t) -> void:
	var b := _battle(24, 12)
	var g := b.grid
	var dest := g.tile_index(20, 6)
	b.place_ashore(0, g.tile_index(2, 6))
	b.order_walk(0, dest)
	var stored: PackedInt32Array = b._soldier_path[0]
	t.ok(stored.size() > 1, "길이 있다 (자가 점검)")
	var blocked := int(stored[1])
	t.eq(blocked, g.tile_index(3, 6), "길의 다음 조각은 (3,6) 이다 (자가 점검)")

	var claimed := g.reserved
	claimed[blocked] = OTHER_ID
	g.reserved = claimed

	var was: Vector2 = b.soldier_pos[0]
	_step_for(b, 1.0)
	var now: Vector2 = b.soldier_pos[0]
	t.ok(now.distance_to(was) > 1.0, "길이 막혀도 몸은 선 채로 안 멈춘다 (%s -> %s)" % [str(was), str(now)])
	t.eq(int(g.reserved[blocked]), OTHER_ID, "그리고 남이 쥔 조각을 뺏지도 않는다")
	t.ok(now.x > was.x, "게다가 목적지 쪽으로 간다 — 흐름장이 받아준 것이다")


## ⚠⚠ **NOTHING MEASURED `_clear_path` AND GUTTING IT TO A BARE `return` LEFT ALL 608 CHECKS GREEN**
## (measured 2026-08-29 by an independent pass). The ticket's Risk section named 「the path outliving its
## order」 and there was no row under it.
##
## **The scenario is a re-order to somewhere nothing can reach.** The second `order_walk` builds no route
## of its own — `path_from` answers empty on an `UNREACHABLE` 조각 — so **the only thing that can throw the
## first route away is `_clear_path`.** Whole: the body finishes the 조각 it already reserved and stands.
## Gutted: it keeps walking to the FIRST destination, which is a body going somewhere nobody asked.
##
## ⚠ **The tolerance is one 조각 and that is a rule, not slack.** A body part-way across a 조각 it has
## already reserved must finish it — stopping mid-조각 leaves it holding both for the rest of the island.
func _a_re_order_replaces_the_route(t) -> void:
	var g := _loaded(_POCKET_ROWS, [])
	var start := g.tile_index(2, 6)
	var far := g.tile_index(18, 6)
	var pocket := g.tile_index(20, 6)
	t.ok(g.passable[pocket] != 0, "주머니 조각은 걸을 수 있는 땅이다 (자가 점검 — order_walk 이 거절하지 않는다)")
	t.eq(int(g.flow_field(pocket)[start]), Grid.UNREACHABLE,
		"그런데 몸이 선 자리에서는 아무 길도 없다 (자가 점검)")

	var b := _battle_on(_POCKET_ROWS)
	t.eq(b.place_ashore(0, start), start, "몸이 (2,6) 에 섰다 (자가 점검)")
	t.ok(b.order_walk(0, far), "먼저 (18,6) 으로 보냈다 (자가 점검)")
	_step_for(b, 1.0)
	var mid: Vector2 = b.soldier_pos[0]
	t.ok(mid.distance_to(g.tile_point(start)) > 2.0,
		"1 초 동안 실제로 걸었다 (%.2f 조각) (자가 점검)" % mid.distance_to(g.tile_point(start)))

	t.ok(b.order_walk(0, pocket), "그리고 닿을 수 없는 주머니로 다시 명령했다 (자가 점검)")
	t.ok((b._soldier_path[0] as PackedInt32Array).is_empty(),
		"그 순간 옛 길이 비워진다 — 명령보다 오래 사는 길이 없다")
	_step_for(b, 3.0)
	var stopped := (b.soldier_pos[0] as Vector2).distance_to(mid)
	t.ok(stopped <= 1.5,
		"몸은 예약한 조각만 마저 밟고 선다 (%.2f 조각) — 첫 목적지로 계속 걸어가지 않는다" % stopped)
	t.eq(int(b.soldier_order[0]), -1, "그리고 갈 수 없는 명령은 스스로 지워진다")

	# ⚠ **The control.** 「it stopped」 is equally true of a walker that simply broke, so the same board,
	# the same order and the same three seconds are run WITHOUT the re-order.
	var c := _battle_on(_POCKET_ROWS)
	c.place_ashore(0, start)
	c.order_walk(0, far)
	_step_for(c, 1.0)
	var c_mid: Vector2 = c.soldier_pos[0]
	_step_for(c, 3.0)
	var kept := (c.soldier_pos[0] as Vector2).distance_to(c_mid)
	t.ok(kept > 5.0,
		"다시 명령하지 않으면 같은 몸이 같은 3 초에 멀리 간다 (%.2f 조각) (대조군)" % kept)


# == the line the body actually walks =================================================================

## ⚠⚠ **THE BAR IS THE PULLED ROUTE AND ALL FOUR WALKS ARE ASKED**, because a row carrying only the easy
## one is a label claiming four measurements and making one. **The body walks the pulled route; the field
## is the fallback**, so the pulled route is what 「the line a body walks」 means — the ticket settles this
## outright after two independent passes measured both.
##
## ⚠⚠ **THE RAW DESCENT'S OWN NUMBER IS KEPT AND IT DOES NOT MEET 1.0.** Measured 2026-08-29:
## 0.00 · 0.81 · 1.97 · 1.39 raw against 0.00 · 0.41 · 0.49 · 0.28 pulled. **That is the key the plan
## chose, not a defect** — key 2 is the deviation from the DIRECTION to the goal, so with the goal 18
## east and 3 north, walking straight east is the best angle for twelve steps running. ⇒ **The raw number
## is asserted as a RELATION and never as a literal**: the pull may never leave a walk further off its
## line than the field left it. A literal here would freeze today's behaviour into a guarantee, which is
## the shape `how-nets-lie` records as 「the user's complaint written down as a green check」.
func _the_pulled_route_of_all_four_probe_walks_hugs_its_line(t) -> void:
	var worst_pulled := 0.0
	var worse_than_raw := 0
	var raw_line := ""
	for raw_walk in _PROBE_WALKS:
		var walk: Array = raw_walk
		var a: Vector2i = walk[0]
		var b: Vector2i = walk[1]
		var g := _empty(24, 12)
		var target := g.tile_index(b.x, b.y)
		var field := g.flow_field(target)
		var descent := g.path_from(field, g.tile_index(a.x, a.y), target)
		var pulled := g.string_pull(descent)
		t.eq(int(pulled[pulled.size() - 1]), target, "%s 의 당긴 길이 B 에 닿는다 (자가 점검)" % str(a))
		var raw_off := _worst_offset(g, descent, a, b)
		var pulled_off := _worst_offset(g, pulled, a, b)
		raw_line += "%.2f " % raw_off
		worst_pulled = maxf(worst_pulled, pulled_off)
		if pulled_off > raw_off + 0.0001:
			worse_than_raw += 1
		t.ok(pulled_off <= 1.0,
			"%s -> %s 의 당긴 길이 제 직선에서 1.0 조각 이내다 (당김 %.2f · 하강 %.2f)"
				% [str(a), str(b), pulled_off, raw_off])
	t.ok(worst_pulled <= 1.0, "네 걸음 중 가장 벗어난 당긴 길도 %.2f 조각이다" % worst_pulled)
	t.eq(worse_than_raw, 0,
		"그리고 당긴 길이 흐름장 하강보다 더 벗어난 걸음이 하나도 없다 — 하강은 %s(실측 기록)" % raw_line)


# == fixtures =========================================================================================

## The four walks the throwaway probe prints, so the net and the probe cannot drift apart about which
## lines were measured.
const _PROBE_WALKS := [
	[Vector2i(2, 6), Vector2i(20, 6)],
	[Vector2i(2, 10), Vector2i(20, 2)],
	[Vector2i(2, 9), Vector2i(20, 6)],
	[Vector2i(2, 2), Vector2i(14, 10)],
]

## A main island with a one-조각 strip cut off from it by a full column of water — **passable, and no walk
## can reach it**, which is the one shape `order_walk` accepts and `flow_field` refuses.
const _POCKET_ROWS := [
	"~~~~~~~~~~~~~~~~~~~~~~~~",
	"~..................~.~~~",
	"~..................~.~~~",
	"~..................~.~~~",
	"~..................~.~~~",
	"~..................~.~~~",
	"~..................~.~~~",
	"~..................~.~~~",
	"~..................~.~~~",
	"~..................~.~~~",
	"~..................~.~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~",
]

## A wall reaching in from the west with a gap at its east end, so a walk from north to south has to
## round it. Land is everything not `~`.
const _WALL_ROWS := [
	"~~~~~~~~~~~~",
	"~..........~",
	"~..........~",
	"~..........~",
	"~~~~~~~~...~",
	"~..........~",
	"~..........~",
	"~..........~",
	"~~~~~~~~~~~~",
]

## A wall with exactly one gap in it: (3,2). Everything about the queue at a neck is measured here.
const _DOOR_ROWS := [
	"~~~~~~~",
	"~..~..~",
	"~.....~",
	"~..~..~",
	"~~~~~~~",
]

## The corner stair, the same shape `net_tiers` measures the flank rule on: floor to the west and south,
## plateau to the east and north, so the stair climbs west to east.
const _STAIR_ROWS := [
	"~~~~~~~",
	"~.....~",
	"~.....~",
	"~.....~",
	"~.....~",
	"~~~~~~~",
]
const _STAIR_TIERS := [
	".......",
	"...222.",
	"...222.",
	"../222.",
	".......",
	".......",
]


# == helpers ==========================================================================================

func _rows_of(w: int, h: int) -> Array:
	var rows: Array = []
	for _y in h:
		rows.append(".".repeat(w))
	return rows


func _empty(w: int, h: int) -> Grid:
	return _loaded(_rows_of(w, h), [])


func _loaded(rows: Array, tiers: Array) -> Grid:
	var g := Grid.new()
	g.load_rows(rows, tiers)
	return g


## One swordsman on an empty board, ashore-able and orderable. **Built through `Army.register_species`
## and `recruit`** rather than by writing the columns, so the roster this drives is the one the game has.
func _battle(w: int, h: int) -> Battle:
	return _battle_on(_rows_of(w, h))


func _battle_on(rows: Array) -> Battle:
	var army := Army.new()
	army.recruit(army.register_species(Rules.SWORDSMAN))
	var b := Battle.new()
	b.setup(_loaded(rows, []), army, [])
	return b


## Real seconds through the real `step`, a frame at a time — **not one big `step`**, because the sim runs
## whole sub-steps and a single huge delta is a different discretisation from the one the game runs on.
func _step_for(b: Battle, seconds: float) -> void:
	var left := seconds
	while left > Rules.EPS:
		var dt: float = minf(left, 1.0 / 60.0)
		b.step(dt)
		left -= dt


## The lowest board row soldier 0 stands on at any point over `seconds`, sampled every frame.
func _lowest_row(b: Battle, seconds: float) -> int:
	var lowest := 1 << 20
	var left := seconds
	while left > Rules.EPS:
		var dt: float = minf(left, 1.0 / 60.0)
		b.step(dt)
		left -= dt
		lowest = mini(lowest, int(round((b.soldier_pos[0] as Vector2).y)))
	return lowest


## What a list of 조각 costs to walk, starting from `first_tile` — which is NOT in the list, the way
## `line_tiles` hands its answer back.
func _line_cost(g: Grid, first_tile: int, tiles: PackedInt32Array) -> int:
	var cost := 0
	var prev := first_tile
	for raw in tiles:
		cost += g.step_cost(prev, int(raw))
		prev = int(raw)
	return cost


## Everything after the first entry, so a `[from, ...]` route can be costed with `_line_cost`.
func _tail(path: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in range(1, path.size()):
		out.append(int(path[i]))
	return out


## **Whether this step enters a stair 조각 across its side rather than along its climb.** Reads
## `stair_run_of` — the same run the drawn staircase is cut from — so it cannot agree with a broken rule
## by sharing it.
func _is_sideways_onto_a_stair(g: Grid, from_tile: int, to_tile: int) -> bool:
	var run: Array = g.stair_run_of(to_tile)
	if run.is_empty() or not g.stair_run_of(from_tile).is_empty():
		return false
	var ax: Vector2i = run[0]
	var dx := to_tile % g.w - from_tile % g.w
	var dy := to_tile / g.w - from_tile / g.w
	return dx * ax.x + dy * ax.y == 0


## The cheapest an 8-connected walk between two 조각 can cost. Derived, never typed: such a walk takes
## exactly `min(|dx|,|dy|)` diagonal steps and `max - min` orthogonal ones.
static func _octile(ax: int, ay: int, bx: int, by: int) -> int:
	var dx := absi(bx - ax)
	var dy := absi(by - ay)
	return ORTHO * maxi(dx, dy) + (DIAG - ORTHO) * mini(dx, dy)


## The 조각 a body actually steps through, walking the game's own descent from `a` to `b`. Starts with `a`
## itself, so a straight 18-step walk is 19 entries.
func _walk_tiles(g: Grid, a: Vector2i, b: Vector2i) -> PackedInt32Array:
	var target := g.tile_index(b.x, b.y)
	var field := g.flow_field(target)
	g.release_all(WALK_ID)
	var out := PackedInt32Array()
	out.append(g.tile_index(a.x, a.y))
	var at := Vector2(a)
	for _i in 400:
		var next := g.step_toward(WALK_ID, at, field, -1, target)
		if next.is_equal_approx(at):
			break
		at = next
		out.append(g.tile_index(int(round(at.x)), int(round(at.y))))
		if int(out[out.size() - 1]) == target:
			break
	g.release_all(WALK_ID)
	return out


## How many times the walk changes direction. A straight line has none.
func _turns(board_w: int, walk: PackedInt32Array) -> int:
	if walk.size() < 3:
		return 0
	var turns := 0
	for i in range(2, walk.size()):
		if _delta(board_w, walk, i) != _delta(board_w, walk, i - 1):
			turns += 1
	return turns


func _delta(board_w: int, walk: PackedInt32Array, i: int) -> Vector2i:
	var a := int(walk[i - 1])
	var b := int(walk[i])
	return Vector2i(b % board_w - a % board_w, b / board_w - a / board_w)


## The furthest any 조각 of the walk stands from the straight segment `a` -> `b`, measured perpendicular.
func _worst_offset(g: Grid, walk: PackedInt32Array, a: Vector2i, b: Vector2i) -> float:
	var d := Vector2(b - a)
	var seg := d.length()
	var worst := 0.0
	for raw in walk:
		var tile := int(raw)
		var p := Vector2(tile % g.w, tile / g.w) - Vector2(a)
		worst = maxf(worst, absf(p.x * d.y - p.y * d.x) / seg)
	return worst


## How many 조각 the reservation table says this body holds. **`reserved` and not the grid's own fast
## path**: the table is the authority, and a hold that never entered the fast path is the one that leaks.
func _held_count(g: Grid, unit_id: int) -> int:
	var n := 0
	for tile in g.reserved.size():
		if int(g.reserved[tile]) == unit_id:
			n += 1
	return n
