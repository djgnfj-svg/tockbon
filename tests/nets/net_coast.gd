extends RefCounted
## Landability, the WATER ROUTE a boat sails, and which harbour a boat returns to — the whole of
## `grid.gd`'s coastline machinery from `boat-and-landing` section 3/4.3 as rewritten by
## `speed-off-open-landing`. Hand-built fixtures only; nothing here reads a real island
## (`net_islands` owns the real grids and pins the plan's own measured counts against them, which is
## the strongest cross-check this file has).
##
## ⚠⚠ **The straight-line half of this file is DELETED, not rewritten to pass.**
## `_sampler_catches_a_one_tile_wall` and `_adjacent_tile_exemption` drove `grid.water_line_clear`
## directly, and that function and its two `Rules` constants are gone: landing is a denylist now and a
## boat sails a BFS route over water. Rewriting checks whose subject no longer exists is how a suite
## comes to measure a rule nobody implements. What replaced them is `_deleted_names_are_really_gone`
## at the bottom — every deletion needs a check that the thing is GONE.
##
## ⚠ **Every fixture below was verified OUTSIDE Godot** with an independent re-implementation of the
## same BFS, before being written in here — hand-picked coordinates for a flood fill are exactly the
## kind of thing that "looks right" and isn't, and a lagoon whose water turns out to be 8-connected
## through one diagonal gap passes every assertion for the wrong reason. Each fixture's comment names
## the mutation that must redden its check, and the measured numbers are in the comments.


func run(t) -> void:
	_diagonal_contact_is_sendable_now(t)
	_a_diagonal_squeeze_is_not_a_sail(t)
	_the_descent_home_never_squeezes(t)
	_cliff_and_ramp(t)
	_a_lagoon_harbour_cannot_see_the_open_shore(t)
	_every_waypoint_of_a_route_is_water(t)
	_a_route_goes_around_the_headland(t)
	_a_route_walks_the_field_down_one_step_at_a_time(t)
	_home_harbour_is_the_shortest_WATER_route(t)
	_start_harbour_is_neither_first_nor_last(t)
	_no_harbour_island_is_a_defined_noop(t)
	_water_fields_are_built_once(t)
	_deleted_names_are_really_gone(t)


## ⚠⚠ **A boat must not slip between two land corners that touch.** `_water_field` and `water_route`
## walked `NEIGHBOURS` on the water byte alone, so a DIAGONAL step from water to water was accepted
## with land on BOTH shoulders — the hull crosses a seam that has no water in it.
##
## The fixture is built so the squeeze is the ONLY thing joining two water bodies: pool A is the
## harbour side `(4,1)H (5,1) (4,2) (5,2)`, pool B is `(3,3) (2,3) (2,4)`, and they touch nowhere
## except the diagonal `(4,2) <-> (3,3)`, whose two shoulders `(3,2)` and `(4,3)` are both land.
##
## ⚠ **The shipped maps cannot fail this** — measured 0 squeezes on all three — so the old rule is
## re-implemented HERE as an unguarded 8-way flood fill and the two answers are made to disagree.
## Without that half, "the landing is refused" would also be what a fixture with no squeeze in it
## says, and the check would be measuring nothing.
##
## ⚠ **`net_boat`'s water check cannot see this defect and never could**: it rounds the hull to a tile
## every sub-step, and along a squeeze that rounded tile is always one of the two water endpoints.
func _a_diagonal_squeeze_is_not_a_sail(t) -> void:
	var rows := [
		"########",
		"####H~##",
		"###.~~##",
		"##~~.###",
		"##~.####",
		"########",
	]
	var g := Grid.new()
	g.load_rows(rows)
	t.eq(g.w, 8, "칸 너비가 8이다 (자가 점검)")
	t.eq(g.harbour_tiles.size(), 1, "항구가 하나다 (자가 점검)")

	# The squeeze itself, asserted rather than assumed: two water tiles a diagonal apart with land on
	# both shoulders. If a later edit to these rows loses that shape, this check stops measuring a
	# squeeze and would go on printing green about one.
	var a := g.tile_index(4, 2)
	var bpool := g.tile_index(3, 3)
	t.eq(int(g.water[a]), 1, "(4,2)는 물이다 (자가 점검)")
	t.eq(int(g.water[bpool]), 1, "(3,3)도 물이다 (자가 점검)")
	t.eq(int(g.water[g.tile_index(3, 2)]), 0, "그 대각선의 어깨 (3,2)는 물이 아니다 (자가 점검)")
	t.eq(int(g.water[g.tile_index(4, 3)]), 0, "다른 어깨 (4,3)도 물이 아니다 (자가 점검)")

	# The old rule, re-implemented here. It reaches pool B; the shipped rule must not.
	var loose := _unguarded_water_reach(g, int(g.harbour_tiles[0]))
	t.ok(loose.has(bpool), "옛 규칙(어깨를 안 보는 8방향)이라면 (3,3)까지 갔다 — 이 검사가 잴 게 있다는 뜻이다")

	var behind := g.tile_index(3, 4)
	t.eq(int(g.passable[behind]), 1, "(3,4)는 땅이고 물에 닿아 있다 (자가 점검)")
	t.ok(loose.has(g.tile_index(2, 4)),
		"옛 규칙이라면 (3,4) 옆의 물 (2,4)까지 닿았다 — 곧 옛 규칙에서는 상륙 가능한 칸이었다 (자가 점검)")
	t.ok(not g.can_land_at(0, behind),
		"틈 너머 (3,4)로는 못 보낸다 — 배는 땅 모서리 둘 사이를 못 빠져나간다")
	t.eq(g.water_route(0, behind).size(), 0, "그리로 가는 항로도 없다")

	# The ceiling under it: the harbour side is still fully reachable, so the guard refuses the seam
	# and not the sea. A guard that refused every diagonal would pass the two rows above.
	var near := g.tile_index(4, 3)
	t.ok(g.can_land_at(0, near), "같은 항구에서 (4,3)에는 그대로 보낼 수 있다 — 대각선 전체를 막은 게 아니다")
	t.ok(g.can_land_at(0, g.tile_index(3, 2)), "(3,2)에도 보낼 수 있다")
	var route := g.water_route(0, near)
	t.ok(route.size() >= 2, "(4,3)로 가는 항로가 있다 (%d점)" % route.size())
	t.eq(_squeeze_steps(g, route).size(), 0,
		"그 항로의 어떤 걸음도 땅 모서리 사이를 지나지 않는다 %s" % str(_squeeze_steps(g, route)))


## ⚠⚠ **The guard has to be in TWO places and the field alone is not enough.** `water_route` descends
## the field by taking the cheapest strictly-lower water neighbour, so a squeezed neighbour that some
## OTHER path reached cheaply is exactly what it prefers — the field can be perfectly clean and the
## drawn, sailed route still cuts through the seam.
##
## The fixture, verified outside Godot before it was written here: the harbour arm runs east to
## `(2,1)` at hop **1**, and the landing `(4,1)`'s only water neighbour is `(3,2)`, which the guarded
## field reaches at hop **5** the long way round the west arm. `(2,1)` and `(3,2)` are a diagonal
## apart with land on both shoulders `(3,1)` and `(2,2)`.
##
## ⇒ **An unguarded descent from `(3,2)` jumps straight to `(2,1)`** — cost 1 against cost 4 for the
## honest step — and produces the 4-point route `(1,1) (2,1) (3,2) (4,1)`. The guarded one is 7 points
## and goes the whole way round. Both numbers are literals below.
func _the_descent_home_never_squeezes(t) -> void:
	var rows := [
		"########",
		"#H~#.###",
		"#~#~####",
		"#~#~####",
		"#~~~####",
		"########",
	]
	var g := Grid.new()
	g.load_rows(rows)
	var landing := g.tile_index(4, 1)
	t.eq(g.harbour_tiles.size(), 1, "항구가 하나다 (자가 점검)")
	t.ok(g.can_land_at(0, landing), "(4,1)에는 보낼 수 있다 — 물이 빙 둘러 닿아 있다 (자가 점검)")

	# The temptation, measured off the field itself: the honest approach tile sits at hop 5 while a
	# squeezed neighbour of it sits at hop 1. Without this pair the check below could pass on a grid
	# where the descent never had a shortcut to take.
	var f: PackedInt32Array = g.water_fields[0]
	t.eq(int(f[g.tile_index(3, 2)]), 5, "상륙 앞 물 (3,2)까지는 5홉이다 (서쪽 팔을 빙 돌아서)")
	t.eq(int(f[g.tile_index(2, 1)]), 1, "그런데 그 대각선 옆 (2,1)은 1홉이다 — 내려오는 길이 탐낼 지름길이다")
	t.eq(int(g.water[g.tile_index(3, 1)]), 0, "그 대각선의 어깨 (3,1)은 물이 아니다 (자가 점검)")
	t.eq(int(g.water[g.tile_index(2, 2)]), 0, "다른 어깨 (2,2)도 물이 아니다 (자가 점검)")

	var route := g.water_route(0, landing)
	t.eq(route.size(), 7, "항로가 7점이다 — 지름길을 안 타고 서쪽 팔을 그대로 되짚는다 %s" % str(route))
	t.eq(_squeeze_steps(g, route).size(), 0,
		"그리고 그 7점 중 땅 모서리 사이를 지나는 걸음이 없다 %s" % str(_squeeze_steps(g, route)))
	t.eq(route[0], Vector2(1.0, 1.0), "0번은 항구다")
	t.eq(route[route.size() - 1], Vector2(4.0, 1.0), "마지막은 상륙 칸이다")


## 8-way flood fill over water from `seed`, with NO shoulder rule — **the rule as it was before the
## guard landed.** It exists so the check above can show the two answers differ; the shipped grids
## cannot, because none of them holds a squeeze.
func _unguarded_water_reach(g: Grid, seed: int) -> Dictionary:
	var seen := {seed: true}
	var queue := [seed]
	var head := 0
	while head < queue.size():
		var tile := int(queue[head])
		head += 1
		var tx := tile % g.w
		var ty := tile / g.w
		for k in Grid.NEIGHBOURS.size():
			var nx := tx + int(Grid.NEIGHBOURS[k][0])
			var ny := ty + int(Grid.NEIGHBOURS[k][1])
			if nx < 0 or ny < 0 or nx >= g.w or ny >= g.h:
				continue
			var nt := ny * g.w + nx
			if g.water[nt] == 0 or seen.has(nt):
				continue
			seen[nt] = true
			queue.append(nt)
	return seen


## Every step of `route` that is a DIAGONAL between two water tiles with land on both shoulders.
## The last waypoint is the LANDING and is land by construction, so the pair that ends on it is a
## beaching rather than a sail and is skipped — the same exemption `grid.gd` states in the guard's
## own comment.
func _squeeze_steps(g: Grid, route: PackedVector2Array) -> Array:
	var out := []
	for k in range(1, route.size()):
		var from_p := route[k - 1]
		var to_p := route[k]
		var fx := int(from_p.x)
		var fy := int(from_p.y)
		var tx := int(to_p.x)
		var ty := int(to_p.y)
		if fx == tx or fy == ty:
			continue
		if g.water[ty * g.w + tx] == 0 or g.water[fy * g.w + fx] == 0:
			continue
		if g.water[fy * g.w + tx] != 0 or g.water[ty * g.w + fx] != 0:
			continue
		out.append("(%d,%d)->(%d,%d)" % [fx, fy, tx, ty])
	return out


## ⚠ **This check is INVERTED from the one it replaces, and that is the whole of item 2.** The old
## rule said a tile touching water only at a CORNER is not landable ("coming ashore there reads as
## landing on the rock beside it"); the user said *"내가 어디든지 상륙할 수 있게 해달라고 했는데"*, so
## the coast is 8-way now. On the three real islands this exact difference is 82 -> 84 and 80 -> 82
## tiles (`net_islands` pins both numbers).
##
## Harbour at (1,1). (1,2) touches it orthogonally; (2,2) touches it ONLY diagonally — all four of
## (2,2)'s orthogonal neighbours are land. Both must be sendable.
func _diagonal_contact_is_sendable_now(t) -> void:
	var rows := [
		"~~~~~",
		"~H..~",
		"~...~",
		"~...~",
		"~~~~~",
	]
	var g := Grid.new()
	g.load_rows(rows)
	t.eq(g.harbour_tiles.size(), 1, "항구가 하나다 (자가 점검)")
	t.eq(int(g.passable[2 * 5 + 2]), 1, "(2,2)는 땅이다 (자가 점검)")
	# The self-check that makes the diagonal claim mean something: (2,2) really has no ORTHOGONAL
	# water neighbour, so a 4-way rule would refuse it.
	var ortho_water := false
	for d in [[0, -1], [0, 1], [-1, 0], [1, 0]]:
		var nx := 2 + int(d[0])
		var ny := 2 + int(d[1])
		if g.water[ny * 5 + nx] != 0:
			ortho_water = true
	t.ok(not ortho_water, "(2,2)는 직교로는 물에 안 닿는다 — 대각선 주장이 성립하는 픽스처다 (자가 점검)")
	t.ok(g.can_land_at(0, 2 * 5 + 1), "물에 직교로 닿은 칸은 보낼 수 있다")
	t.ok(g.can_land_at(0, 2 * 5 + 2),
		"대각선으로만 물에 닿은 칸도 보낼 수 있다 — grid.gd 의 _entry_water_tile 을 4방향으로 바꾸면 문다")


## A cliff row (`^`) between open water and the land behind it. The cliff tile is impassable, so
## `sendable`'s FIRST test refuses it; the land behind has no water neighbour at all, so the SECOND
## test refuses that. **Two different reasons, and the fixture separates them.** A ramp (`/`) in the
## same wall is passable AND touches water, so it comes back sendable — while the land behind the
## ramp still does not, because a doorway is not a shore.
func _cliff_and_ramp(t) -> void:
	var cliff_rows := [
		"~~~H~~~~",
		"^^^^^^^^",
		"........",
	]
	var cg := Grid.new()
	cg.load_rows(cliff_rows)
	t.eq(cg.harbour_tiles.size(), 1, "절벽 픽스처에 항구가 있다 (자가 점검 — 없으면 전부 거절이라 아무것도 증명 못 한다)")
	t.eq(int(cg.passable[1 * 8 + 3]), 0, "절벽 칸은 지나갈 수 없다")
	t.ok(not cg.can_land_at(0, 1 * 8 + 3),
		"절벽 칸에는 배를 못 댄다 — grid.gd 의 LAND_CHARS 에 '^' 를 넣으면 문다")
	t.ok(not cg.can_land_at(0, 2 * 8 + 3),
		"절벽 뒤 땅에도 못 댄다 — 물에 닿은 이웃이 하나도 없다 (구조로 막힌다, 별도 규칙이 없다)")

	var ramp_rows := [
		"~~~H~~~~",
		"^^^/^^^^",
		"........",
	]
	var rg := Grid.new()
	rg.load_rows(ramp_rows)
	t.eq(int(rg.passable[1 * 8 + 3]), 1, "램프는 걸을 수 있다")
	t.ok(rg.can_land_at(0, 1 * 8 + 3),
		"물에 닿은 램프에는 배를 댈 수 있다 — grid.gd 의 LAND_CHARS 에서 '/' 를 빼면 문다")
	t.ok(not rg.can_land_at(0, 2 * 8 + 3),
		"램프 뒤 땅에는 여전히 못 댄다 — 문은 해안이 아니다 (천장)")


## ⚠⚠ **The ONLY shape left in which two harbours disagree about one tile.** The old headland fixture
## worked because a STRAIGHT line was blocked by a `#` peninsula; an 8-connected water route sails
## around any peninsula, so on that fixture both harbours now reach both shores and the check would
## have gone green while measuring nothing. What still separates two harbours is genuinely
## DISCONNECTED water — an inner lake.
##
## Verified outside Godot: 93 water tiles total, the lake harbour's field reaches **12** and the sea
## harbour's reaches **81**, and 12 + 81 = 93 — so the two bodies share not one tile and the lake is
## not leaking through a diagonal gap. Harbours row-major: 0 is the lake (6,5), 1 is the sea (5,10).
## (4,5) touches lake water only; (2,3) touches sea water only.
func _a_lagoon_harbour_cannot_see_the_open_shore(t) -> void:
	var g := Grid.new()
	g.load_rows(_lagoon_rows())
	t.eq(g.harbour_tiles.size(), 2, "항구가 둘이다 (자가 점검)")
	t.eq(int(g.harbour_tiles[0]), 5 * 14 + 6, "0번 항구는 석호 안(6,5)이다 (자가 점검 — 행 우선)")
	t.eq(int(g.harbour_tiles[1]), 10 * 14 + 5, "1번 항구는 바깥 바다(5,10)다 (자가 점검)")

	# The fixture's own load-bearing property, asserted rather than assumed: the two water bodies
	# really are disjoint. If a future edit widens the lake by one tile this line fails FIRST and
	# names the cause, instead of the four reach checks below quietly all going true.
	var total := 0
	var lake_reach := 0
	var sea_reach := 0
	var f_lake: PackedInt32Array = g.water_fields[0]
	var f_sea: PackedInt32Array = g.water_fields[1]
	for tile in g.water.size():
		if g.water[tile] == 0:
			continue
		total += 1
		if int(f_lake[tile]) != Grid.UNREACHABLE:
			lake_reach += 1
		if int(f_sea[tile]) != Grid.UNREACHABLE:
			sea_reach += 1
	t.eq(total, 93, "물이 93칸이다 (바깥에서 검증됨)")
	t.eq(lake_reach, 12, "석호 항구가 닿는 물은 12칸뿐이다 (바깥에서 검증됨)")
	t.eq(sea_reach, 81, "바다 항구가 닿는 물은 81칸이다 (바깥에서 검증됨)")
	t.eq(lake_reach + sea_reach, total, "12 + 81 = 93 — 두 물이 한 칸도 안 겹친다, 대각선으로도 안 샌다")

	var lake_shore := 5 * 14 + 4   # (4,5)
	var sea_shore := 3 * 14 + 2    # (2,3)
	t.eq(int(g.passable[lake_shore]), 1, "석호 해안(4,5)은 땅이다 (자가 점검)")
	t.eq(int(g.passable[sea_shore]), 1, "바깥 해안(2,3)도 땅이다 (자가 점검)")

	# The floor. A BFS that reached nothing at all passes every `not can_land_at` line below it.
	t.ok(g.can_land_at(0, lake_shore), "석호 항구는 석호 해안에 배를 댈 수 있다")
	t.ok(g.can_land_at(1, sea_shore), "바다 항구는 바깥 해안에 배를 댈 수 있다")
	t.ok(not g.can_land_at(0, sea_shore),
		"석호 항구는 바깥 해안에 못 댄다 — 물이 끊겨 있으면 배가 못 간다")
	t.ok(not g.can_land_at(1, lake_shore),
		"바다 항구는 석호 해안에 못 댄다")
	t.ok(g.can_land_at(0, lake_shore) != g.can_land_at(1, lake_shore),
		"같은 칸을 두 항구가 다르게 판정한다 — sendable 을 항구 하나로 합치면 이 줄이 죽는다")
	t.ok(g.can_land_at(0, sea_shore) != g.can_land_at(1, sea_shore),
		"반대쪽 칸도 마찬가지다 — 항구마다 물 필드가 따로 있다는 뜻이다")


## ⚠⚠ **「배가 도착했다」는 「배가 물 위로 갔다」가 아니다.** The endpoint alone cannot tell a polyline
## from the straight line it replaced, so this walks every point.
##
## Verified outside Godot on the peninsula fixture: `water_route(0, (9,2))` is
## `[(2,4),(3,3),(4,3),(5,4),(6,3),(7,3),(8,3),(9,2)]` — **8 points**, and the dip to (5,4) is the
## boat going AROUND the `#` at (5,3) that the old straight line was refused by.
func _every_waypoint_of_a_route_is_water(t) -> void:
	var g := Grid.new()
	g.load_rows(_peninsula_rows())
	var beach := 2 * 12 + 9   # (9,2)
	t.eq(int(g.passable[beach]), 1, "목표 해안(9,2)은 땅이다 (자가 점검)")
	t.ok(g.can_land_at(0, beach), "0번 항구는 그 해안에 배를 보낼 수 있다 (자가 점검)")

	var route := g.water_route(0, beach)
	# The floor: a two-point path IS the straight line this whole change exists to replace.
	t.ok(route.size() >= 3, "항로가 3점 이상이다 (실제 %d점) — 2점이면 예전 직선 그대로다" % route.size())
	t.eq(route[0], g.tile_point(int(g.harbour_tiles[0])), "0번은 항구다")
	t.eq(route[route.size() - 1], g.tile_point(beach), "마지막은 상륙 칸이다")

	var dry: Array = []
	for k in route.size() - 1:
		var p: Vector2 = route[k]
		var tile := g.tile_index(int(round(p.x)), int(round(p.y)))
		if g.water[tile] == 0:
			dry.append(str(p))
	t.eq(dry.size(), 0,
		"마지막을 뺀 모든 중간 지점이 물 위다 — 물 밖 지점: %s" % str(dry))


## The same fixture, measured against the straight line it replaced. Verified outside Godot: route
## length **8.6569** against a harbour-to-beach straight line of **7.2801**.
func _a_route_goes_around_the_headland(t) -> void:
	var g := Grid.new()
	g.load_rows(_peninsula_rows())
	var beach := 2 * 12 + 9
	var route := g.water_route(0, beach)
	var length := 0.0
	for k in range(1, route.size()):
		length += route[k - 1].distance_to(route[k])
	var straight: float = route[0].distance_to(route[route.size() - 1])
	t.ok(length > straight + 0.5,
		"항로가 곶을 돌아가느라 직선보다 길다 — 항로 %.4f칸 vs 직선 %.4f칸" % [length, straight])


## The walk's own shape, which is what makes it terminate without the `w * h` guard ever firing: from
## the harbour outward every point's field value is EXACTLY its index, and every step is a
## Chebyshev-1 hop. Verified outside Godot: field values `[0,1,2,3,4,5,6]` then the land tile, and
## every one of the seven steps is Chebyshev 1.
##
## ⚠ This is the ceiling on a route that teleports or loops. A descent that took two steps at once,
## or revisited a tile, breaks one of the two halves.
func _a_route_walks_the_field_down_one_step_at_a_time(t) -> void:
	var g := Grid.new()
	g.load_rows(_peninsula_rows())
	var beach := 2 * 12 + 9
	var route := g.water_route(0, beach)
	var field: PackedInt32Array = g.water_fields[0]
	var bad_cost: Array = []
	for k in route.size() - 1:
		var p: Vector2 = route[k]
		var tile := g.tile_index(int(round(p.x)), int(round(p.y)))
		if int(field[tile]) != k:
			bad_cost.append("%d번 지점 비용 %d" % [k, int(field[tile])])
	t.eq(bad_cost.size(), 0,
		"항구에서부터 물 필드 값이 정확히 0,1,2,... 로 한 칸씩 내려간다 — 어긋난 지점: %s" % str(bad_cost))

	var bad_hop: Array = []
	for k in range(1, route.size()):
		var d: Vector2 = route[k] - route[k - 1]
		if maxi(absi(int(round(d.x))), absi(int(round(d.y)))) != 1:
			bad_hop.append("%d->%d" % [k - 1, k])
	t.eq(bad_hop.size(), 0,
		"모든 걸음이 8방향 한 칸이다 — 순간이동한 구간: %s" % str(bad_hop))


## ⚠⚠ **돌아갈 항구는 물길이 가장 짧은 항구다, 직선으로 제일 가까운 쪽이 아니다.** The straight-line
## rule this replaced picks a harbour on the far side of a land bar — near as the crow flies, a long
## sail — and a beachhead there strands itself.
##
## A land bar (rows 3-4) separates an enclosed bay (rows 5-6) from the open sea (rows 0-2); they join
## only around the bar's right end. Verified outside Godot, for the beach at (2,3):
##   harbour 0 (10,0), sea — straight **8.544**, **7 hops**, route 9.243   <- the answer
##   harbour 1 (2,6),  bay — straight **3.000**, **24 hops**, route 28.314 <- nearest, and wrong
func _home_harbour_is_the_shortest_WATER_route(t) -> void:
	var rows := [
		"~~~~~~~~~~H~~~~~",
		"~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~",
		"..............~~",
		"..............~~",
		"~~~~~~~~~~~~~~~~",
		"~~H~~~~~~~~~~~~~",
	]
	var g := Grid.new()
	g.load_rows(rows)
	t.eq(g.harbour_tiles.size(), 2, "항구가 둘이다 (자가 점검)")
	var b := 3 * 16 + 2   # (2,3)
	t.eq(int(g.passable[b]), 1, "해안(2,3)은 땅이다 (자가 점검)")
	t.ok(g.can_land_at(0, b), "바다 항구는 그 해안에 댈 수 있다 (자가 점검)")
	t.ok(g.can_land_at(1, b), "만 안쪽 항구도 (멀리 돌아서) 댈 수 있다 — 둘 다 후보다 (자가 점검)")

	# The self-check that makes the claim discriminating: the straight-line rule really WOULD pick
	# the other one. Without this the fixture could be green because both answers agree.
	var straight_best := -1
	var straight_d := 0.0
	for hb in g.harbour_tiles.size():
		var d: float = g.tile_point(int(g.harbour_tiles[hb])).distance_to(g.tile_point(b))
		if straight_best == -1 or d < straight_d - Rules.EPS:
			straight_best = hb
			straight_d = d
	t.eq(straight_best, 1, "직선으로 가장 가까운 항구는 1번(만 안쪽)이다 — 픽스처가 실제로 갈린다 (자가 점검)")

	t.eq(g.home_harbour_for(b), 0,
		"돌아갈 항구는 물길이 짧은 0번이다 — home_harbour_for 를 직선 거리로 되돌리면 " +
		"만 안쪽 1번을 골라 24홉짜리 항해를 시킨다")

	var short_len := 0.0
	var route0 := g.water_route(0, b)
	for k in range(1, route0.size()):
		short_len += route0[k - 1].distance_to(route0[k])
	var long_len := 0.0
	var route1 := g.water_route(1, b)
	for k in range(1, route1.size()):
		long_len += route1[k - 1].distance_to(route1[k])
	t.ok(long_len > short_len * 2.0,
		"고른 쪽 항로 %.3f칸, 안 고른 쪽 %.3f칸 — 두 배 넘게 차이 난다" % [short_len, long_len])


## Three harbours where the answer is neither index 0 nor the last index — `net_islands` alone could
## never catch "start_harbour = 0" or "start_harbour = harbour_tiles.size() - 1" as a stand-in for the
## real rule, because the start harbour happens to be the LAST one on all three real islands.
## Re-verified outside Godot against the WIDER sendable set: still the middle harbour.
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
		"인덱스 0이나 size()-1 로 대신하면 이 픽스처에서만 문다 (넓어진 해안으로 재측정됨)")


## An island authored with no `H` at all must be a defined no-op, not a bark: `harbour_tiles` empty,
## `start_harbour == -1`, `sendable` and `water_fields` empty, `can_land_at` false everywhere and
## `water_route` empty.
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
	t.eq(g.sendable.size(), 0, "sendable 배열이 비어 있다")
	t.eq(g.water_fields.size(), 0, "물 필드 배열도 비어 있다")
	t.eq(g.water_field_builds, 0, "물 BFS 를 한 번도 안 돌렸다")
	var any_true := false
	for tile in g.passable.size():
		if g.can_land_at(0, tile):
			any_true = true
	t.ok(not any_true, "항구가 없으면 can_land_at 은 어디서도 참이 아니다 — 짖지도 않는다")
	t.eq(g.home_harbour_for(2 * 5 + 2), -1, "돌아갈 항구도 -1 이다")
	t.eq(g.water_route(0, 2 * 5 + 2).size(), 0, "항로는 빈 배열이다 — 없는 항구를 색인하며 터지지 않는다")


## The water field is built ONCE per harbour inside `load_rows`; `can_land_at`, `home_harbour_for`
## and `water_route` only ever read it back. Driving all three sixty times (one per pumped frame, the
## way the drag route does) must not move `water_field_builds`.
##
## ⚠ **A BFS is more expensive than the line test it replaced, not less** — 1536 tiles x 3 harbours a
## frame — so this row got MORE load-bearing, not less, when the rule changed.
func _water_fields_are_built_once(t) -> void:
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
	# The floor. A build count of 0 would pass the equality below trivially, and every read after it
	# would be reading an empty table.
	t.ok(g.water_field_builds > 0, "섬을 불러오는 동안 물 BFS 가 실제로 돌았다 (%d번)" % g.water_field_builds)
	t.eq(g.water_field_builds, g.harbour_tiles.size(), "항구 하나에 물 필드 하나, 그 이상도 이하도 아니다")
	var after_load := g.water_field_builds
	var w := g.w
	var b := 2 * w + 7
	t.ok(g.home_harbour_for(b) >= 0, "그 칸에 배를 보낼 수 있다 (자가 점검 — 아래 60번이 헛돌지 않는다)")
	for _f in 60:
		g.can_land_at(0, b)
		g.can_land_at(1, b)
		g.can_land_at(2, b)
		g.home_harbour_for(b)
		g.water_route(g.home_harbour_for(b), b)
	t.eq(g.water_field_builds, after_load,
		"60번 더 물어도 물 BFS 횟수가 안 늘었다 — can_land_at 이나 water_route 가 _water_field 를 " +
		"직접 부르게 바꾸면 이 줄이 매 프레임 다시 돈다")


## ⚠⚠ **Every deletion needs a check that the thing is GONE.** A green round after deleting a rule
## proves nothing about the deletion — the checks that drove it were deleted in the same edit, so
## "nothing red" is exactly what a deletion that never happened would also look like.
func _deleted_names_are_really_gone(t) -> void:
	var g := Grid.new()
	g.load_rows(["~~~", "~H~", "~.~"])
	t.ok(not g.has_method("water_line_clear"),
		"grid 에 water_line_clear 가 없다 — 직선 항로 검사는 물 BFS 로 대체됐다")

	var props: Array = []
	for raw in g.get_property_list():
		props.append(str((raw as Dictionary)["name"]))
	t.ok(not props.has("landable"), "grid 에 landable 필드가 없다 — 8방향 해안이 그 자리를 대신한다")
	t.ok(not props.has("line_tests"), "grid 에 line_tests 가 없다 — water_field_builds 가 그 자리를 대신한다")
	t.ok(props.has("water_fields"), "대신 water_fields 가 있다 (자가 점검 — 속성 목록을 실제로 읽고 있다)")
	t.ok(props.has("water_field_builds"), "water_field_builds 도 있다 (자가 점검)")

	# ⚠ `get_script_constant_map()` is NOT static — `Grid.get_script_constant_map()` is a PARSE error,
	# not a runtime one, so it takes the whole net out with "Nonexistent function new". Asked of the
	# instance's own script instead, which is also the script the game actually loaded.
	var gconst: Dictionary = g.get_script().get_script_constant_map()
	t.ok(not gconst.has("ORTHO"),
		"Grid 에 ORTHO 상수가 없다 — 절벽 면을 그리던 네 방향은 field_view 로 옮겨갔다")
	t.ok(gconst.has("NEIGHBOURS"), "8방향 NEIGHBOURS 는 그대로 있다 (자가 점검 — 상수 표를 실제로 읽고 있다)")

	var rconst: Dictionary = Rules.new().get_script().get_script_constant_map()
	t.ok(not rconst.has("LINE_SAMPLE_STEP"),
		"Rules 에 LINE_SAMPLE_STEP 이 없다 — 읽는 사람이 사라진 규칙 상수는 조용히 썩는다")
	t.ok(not rconst.has("LINE_SAMPLE_EXEMPT_CHEBYSHEV"),
		"Rules 에 LINE_SAMPLE_EXEMPT_CHEBYSHEV 도 없다 — 한 칸 내륙 상륙을 허용하던 그 예외다")
	t.ok(rconst.has("BOAT_SPEED"), "BOAT_SPEED 는 그대로 있다 (자가 점검)")


# --- fixtures, shared by more than one check -----------------------------------------------------

## An island with an inner LAKE holding one harbour and the open sea holding another. Written once
## and read by one check today; it is a function rather than a `const` because a `const` Array of
## Strings buys nothing here and this repo has been bitten twice by const-expression rules.
##
## ⚠ The land ring around the lake is two tiles thick on every side INCLUDING the diagonals — that is
## what makes the two water bodies genuinely disconnected under an 8-way flood fill, and it is
## asserted (12 + 81 = 93) rather than trusted.
func _lagoon_rows() -> Array:
	return [
		"~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~",
		"~~..........~~",
		"~~..........~~",
		"~~...~~~~....~",
		"~~...~H~~....~",
		"~~...~~~~....~",
		"~~..........~~",
		"~~..........~~",
		"~~~~~~~~~~~~~~",
		"~~~~~H~~~~~~~~",
	]


## A one-tile `#` peninsula at (5,2)-(5,3) that the OLD straight-line rule was blocked by: the line
## from harbour 0 at (2,4) to the beach at (9,2) samples onto (5,3). An 8-way water route sails
## around it instead, dipping to (5,4) — which is the whole difference this round bought.
func _peninsula_rows() -> Array:
	return [
		"~~~~~~~~~~~~",
		"~..........~",
		"~....#.....~",
		"~~~~~#~~~~~~",
		"~~H~~~~~~H~~",
	]
