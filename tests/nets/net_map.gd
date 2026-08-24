extends RefCounted
## The node map: the graph `rules.gd` authors, the walk `map.gd` takes over it, and the picture
## `map_view.gd` draws of both.
##
## **Every route is walked exhaustively.** The map is authored and not generated — no RNG, no seed —
## which is exactly what makes that possible, and it is the reason the design chose an authored map
## over a generated one. So the rows below are not samples: `_routes()` enumerates every path from a
## floor-0 node to a terminal one, and the claims about the fork are minima and maxima over all of
## them rather than over the two somebody happened to try.
##
## ⚠⚠ **One row the plan asked for is NOT here, and its absence is a finding rather than an
## omission.** `title-and-map` section 8.1 asks for 「어느 경로도 부리 칸을 하나 이상 지난다」 with a
## floor of 1, **and it contradicts the row directly above it** (「한 경로가 지나는 짐승 칸은 최대
## 셋이다」, floor 3). The proof is one line: every route steps on exactly three FIGHT nodes, so a
## route with three `COUNT` nodes is a route with zero `BEAK` nodes, and the two rows cannot both
## hold on any table with this shape. **The three rows that replace it are below** — the fight count
## is pinned at 3 both ways, and the beak minimum and maximum are pinned at what they are, which is
## the fork actually being a fork. See the report handed back with this net.
##
## ⚠ **`net_islands`'s 「두 칸이 같은 격자를 안 쓴다」 is not here either**, and that is the plan's own
## instruction: the island column is still the stage-1 `[0, 1, 2, 1, 2, -1, 2]` and the check that
## forbids two nodes sharing a grid lands WITH the three new grids. What IS here is the row that
## survives the gap — every island a node names is a real island.
##
## The view half is driven treed with real frames and a spy over all seven leaves, the same shape
## `net_shell` uses. Its clock is stopped and `_fx_step(dt)` is called by hand, because a headless
## frame is 6.56 ms and a 0.45 s ring walk is sixty-eight frames of guessing.


## All seven leaves of `map_view.gd`. A hook left out binds to nothing at all: the REAL `draw_*` runs,
## the capture array stays empty, and every check about it reads as "nothing was drawn".
class MapSpy extends MapView:
	var draws := 0
	var seq := 0
	var edges := []
	var nodes := []
	var borders := []
	var glyphs := []
	var here_rings := []
	var armies := []
	var fades := []

	func _draw() -> void:
		edges.clear()
		nodes.clear()
		borders.clear()
		glyphs.clear()
		here_rings.clear()
		armies.clear()
		fades.clear()
		seq = 0
		super()
		draws += 1

	func _bump() -> int:
		seq += 1
		return seq - 1

	func _paint_edge(from_px: Vector2, to_px: Vector2, col: Color, line_width: float) -> void:
		edges.append({"seq": _bump(), "from": from_px, "to": to_px, "col": col, "width": line_width})

	func _paint_node(sides: int, centre: Vector2, radius: float, col: Color,
			points: PackedVector2Array) -> void:
		nodes.append({"seq": _bump(), "sides": sides, "centre": centre, "radius": radius, "col": col,
			"points": points})

	func _paint_node_border(points: PackedVector2Array, col: Color, line_width: float) -> void:
		borders.append({"seq": _bump(), "points": points, "col": col, "width": line_width})

	func _paint_glyph(points: PackedVector2Array, col: Color, line_width: float) -> void:
		glyphs.append({"seq": _bump(), "points": points, "col": col, "width": line_width})

	func _paint_here_ring(centre: Vector2, radius: float, col: Color, line_width: float) -> void:
		here_rings.append({"seq": _bump(), "centre": centre, "radius": radius, "col": col,
			"width": line_width})

	func _paint_army(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		armies.append({"seq": _bump(), "face": face, "at": at, "text": text, "fsize": fsize,
			"col": col})

	func _paint_fade(rect: Rect2, col: Color) -> void:
		fades.append({"seq": _bump(), "rect": rect, "col": col})


## The viewport as LITERALS, not as `Look.VIEWPORT_*`. A check whose bounds come from the thing it
## checks proves nothing — reading the constant on both sides would let the screen shrink and every
## hit circle shrink with it.
const SCREEN := Rect2(0.0, 0.0, 1280.0, 720.0)

## The closest two node centres are allowed to be. **`2 x (MAP_NODE_R_PX + PRESS_HIT_PAD_PX)` is 96**,
## so 120 leaves 24 px of daylight between the two hit circles — written out because that is the whole
## claim, and reading the radii back would make the bound move with them.
const MIN_CENTRE_GAP_PX := 120.0


func run(t) -> void:
	_the_graph_is_legal(t)
	_every_route_walked(t)
	_the_walk_over_it(t)
	_the_fourth_floor_opens_an_island_too(t)
	await _the_picture(t)


# -- the graph rules.gd authors --------------------------------------------------------------------

func _the_graph_is_legal(t) -> void:
	# 「지도는 일곱 칸이고 변은 아홉이다」 — both ends of the same row, because a table that grew and a
	# table that shrank are two different failures and one bound catches only one of them.
	t.eq(Rules.map_node_count(), 7, "지도는 일곱 칸이다")
	t.eq(Rules.map_edge_count(), 9, "변은 아홉이다")
	t.eq(Rules.MAP_NODES.size(), Rules.map_node_count(), "칸 수 접근자가 표 크기 그 자체다 (자가 점검)")
	t.eq(Rules.MAP_EDGES.size(), Rules.map_edge_count(), "변 수 접근자도 표 크기 그 자체다 (자가 점검)")

	# 「층은 다섯이고, 층마다 칸 수가 1·2·2·1·1이다」 — floor: every floor holds at least one node, or
	# the map is disconnected; ceiling: the top floor holds exactly one, or a run can end two ways.
	t.eq(Rules.map_floor_count(), 5, "층은 다섯이다")
	var per_floor := [0, 0, 0, 0, 0]
	for n in Rules.map_node_count():
		var f := Rules.map_floor_of(n)
		t.ok(f >= 0 and f < 5, "%d번 칸의 층 %d 가 0~4 안이다" % [n, f])
		per_floor[f] += 1
	t.eq(per_floor, [1, 2, 2, 1, 1], "층마다 칸이 1·2·2·1·1개다")
	var empty_floors := 0
	for f in 5:
		if int(per_floor[f]) < 1:
			empty_floors += 1
	t.eq(empty_floors, 0, "빈 층이 없다 — 하나라도 비면 지도가 끊긴다")
	t.eq(int(per_floor[4]), 1, "꼭대기 층은 정확히 한 칸이다 — 런이 끝나는 자리는 하나다")

	# 「모든 변은 한 층만 올라간다」 — this is what makes a route's length the floor count and what
	# makes the recursive walker below terminate. Mutation: add [0, 3].
	var skipping := 0
	var descending := 0
	for e in Rules.map_edge_count():
		var a := Rules.map_edge_from(e)
		var b := Rules.map_edge_to(e)
		var climb := Rules.map_floor_of(b) - Rules.map_floor_of(a)
		if climb != 1:
			skipping += 1
		if climb <= 0:
			descending += 1
	t.eq(skipping, 0, "변 아홉이 전부 정확히 한 층만 올라간다")
	t.eq(descending, 0, "그래서 내려가는 변도, 같은 층을 잇는 변도 없다")

	# No duplicate edge, and no node with no way out except the boss. Both are silent failures: a
	# doubled edge makes one branch look twice as thick to a walker, and a dead end locks the run.
	var seen := {}
	var duplicates := 0
	for e in Rules.map_edge_count():
		var key := "%d>%d" % [Rules.map_edge_from(e), Rules.map_edge_to(e)]
		if seen.has(key):
			duplicates += 1
		seen[key] = true
	t.eq(duplicates, 0, "같은 변이 두 번 적혀 있지 않다")
	var dead_ends := 0
	for n in Rules.map_node_count():
		if Rules.map_kind_of(n) == Rules.NodeKind.BOSS:
			continue
		var out := 0
		for e in Rules.map_edge_count():
			if Rules.map_edge_from(e) == n:
				out += 1
		if out < 1:
			dead_ends += 1
	t.eq(dead_ends, 0, "보스가 아닌 칸은 전부 나가는 변이 있다 — 막다른 칸은 런을 잠근다")

	# ⚠⚠ 「칸 종류는 전투와 보스뿐이다」 — the chest is gone, every node opens a fight, and no node's
	# island is -1 any more. Mutation: give node 5 back a third kind.
	t.eq(Rules.map_kind_of(6), Rules.NodeKind.BOSS, "꼭대기 칸은 보스다")
	var bosses := 0
	var other_kind := 0
	var bad_island := 0
	for n in Rules.map_node_count():
		var kind := Rules.map_kind_of(n)
		var island := Rules.map_island_of(n)
		if kind == Rules.NodeKind.BOSS:
			bosses += 1
		elif kind != Rules.NodeKind.FIGHT:
			other_kind += 1
		if island < 0 or island >= Islands.count():
			bad_island += 1
	t.eq(bosses, 1, "보스 칸은 하나다")
	t.eq(other_kind, 0, "칸 종류는 전투와 보스뿐이다")
	t.eq(bad_island, 0, "칸 일곱 전부가 가리키는 섬 번호가 실제 섬이다 (섬 %d개)" % Islands.count())
	# 「4층 칸도 섬을 연다」 — node 5 WAS the chest, floor 4, no fight. Mutation: give it back island -1.
	t.eq(Rules.map_kind_of(5), Rules.NodeKind.FIGHT, "5번(4층, 옛 상자 자리)도 전투 칸이다")
	t.ok(Rules.map_island_of(5) >= 0, "그리고 섬을 연다")
	t.eq(Rules.map_reward_of(6), Rules.Reward.NONE, "보스는 보상을 안 낸다 — 런이 거기서 끝난다")


# -- every route, walked ---------------------------------------------------------------------------

## Every path from a floor-0 node to a node with no way out, as node ids. Recursive, and it terminates
## because every edge climbs exactly one floor — which is asserted above rather than assumed here.
func _routes() -> Array:
	var out := []
	for n in Rules.map_node_count():
		if Rules.map_floor_of(n) == 0:
			_walk(n, PackedInt32Array(), out)
	return out


func _walk(n: int, so_far: PackedInt32Array, out: Array) -> void:
	var here := so_far.duplicate()
	here.append(n)
	var went := false
	for e in Rules.map_edge_count():
		if Rules.map_edge_from(e) == n:
			went = true
			_walk(Rules.map_edge_to(e), here, out)
	if not went:
		out.append(here)


func _count_reward(route: PackedInt32Array, reward: int) -> int:
	var n := 0
	for id in route:
		if Rules.map_reward_of(id) == reward:
			n += 1
	return n


func _every_route_walked(t) -> void:
	var routes := _routes()

	# 「경로가 넷이다」 — both ends. Mutation: delete edge [1, 4] and it is 3.
	t.ok(routes.size() >= 4, "경로가 넷 이상이다 (%d개) — 하나라도 줄면 갈림길이 좁아진 것이다" % routes.size())
	t.ok(routes.size() <= 4, "그리고 넷을 넘지도 않는다 (%d개)" % routes.size())

	# Every route ends on the boss. A route that ends anywhere else is a run that can never be won, and
	# nothing else in the tree would notice.
	var not_boss := 0
	var wrong_length := 0
	for route: PackedInt32Array in routes:
		if Rules.map_kind_of(route[route.size() - 1]) != Rules.NodeKind.BOSS:
			not_boss += 1
		if route.size() != Rules.map_floor_count():
			wrong_length += 1
	t.eq(not_boss, 0, "경로 넷이 전부 보스 칸에서 끝난다")
	t.eq(wrong_length, 0, "경로마다 칸이 층 수(%d)만큼이다 — 변이 한 층씩만 오르니 길이가 곧 층 수다"
		% Rules.map_floor_count())

	# ⚠⚠ **The row that replaces the plan's self-contradicting pair.** Every route steps on exactly
	# three FIGHT nodes, and that is what makes 「짐승 칸 최대 셋」 and 「부리 칸 최소 하나」 mutually
	# exclusive: four fights all paying cells is a route with no beak on it at all. ⚠⚠ **The chest is
	# gone and node 5 (floor 4) is a fight now, so every route steps on FOUR fight nodes, not three.**
	var fights_min := 99
	var fights_max := 0
	for route: PackedInt32Array in routes:
		var n := 0
		for id in route:
			if Rules.map_kind_of(id) == Rules.NodeKind.FIGHT:
				n += 1
		fights_min = mini(fights_min, n)
		fights_max = maxi(fights_max, n)
	t.eq(fights_min, 4, "어느 경로든 싸우는 칸이 넷 이상이다")
	t.eq(fights_max, 4, "그리고 넷을 넘지도 않는다 — 어느 길로 가도 싸우는 횟수는 같다")

	# 「한 경로가 카드를 내는 칸을 넷 지난다」 — a node pays cards iff it is not the boss, so this is the
	# same count as the fights above, asked through the accessor `refit_held_capacity()` will ride on.
	var cards_min := 99
	var cards_max := 0
	for route: PackedInt32Array in routes:
		var n := 0
		for id in route:
			if Rules.map_kind_of(id) != Rules.NodeKind.BOSS:
				n += 1
		cards_min = mini(cards_min, n)
		cards_max = maxi(cards_max, n)
	t.eq(cards_min, 4, "카드를 내는 칸이 넷 밑으로 안 내려간다")
	t.eq(cards_max, 4, "그리고 넷을 넘지도 않는다")
	t.eq(Rules.map_max_card_nodes_on_a_route(), cards_max,
		"map_max_card_nodes_on_a_route() 가 걸어서 나온 최대(%d)와 같다" % cards_max)

	var beaks_min := 99
	var beaks_max := 0
	var counts_min := 99
	var counts_max := 0
	for route: PackedInt32Array in routes:
		var b := _count_reward(route, Rules.Reward.BEAK)
		var c := _count_reward(route, Rules.Reward.COUNT)
		beaks_min = mini(beaks_min, b)
		beaks_max = maxi(beaks_max, b)
		counts_min = mini(counts_min, c)
		counts_max = maxi(counts_max, c)
		# The two are complementary on every single route, which is the arithmetic above stated per
		# row rather than as an aggregate.
		t.eq(b + c, 4, "경로 %s 는 부리 %d + 짐승 %d = 싸우는 칸 넷이다" % [str(route), b, c])

	# ⚠⚠ 「한 경로가 지나는 짐승 칸은 최대 넷이다」 — node 5 (floor 4, the ex-chest) pays COUNT now, so
	# the ceiling this repo watched rot once already moved from 3 to 4 with it. ⚠ **the FLOOR is the
	# half that proves the fork exists**: a table where nobody can reach four count nodes has no
	# cells-heavy branch at all.
	t.ok(counts_max >= 4, "짐승 칸만 넷 지나는 경로가 실제로 있다 (최대 %d) — 갈림길의 짐승 쪽 답이다"
		% counts_max)
	t.ok(counts_max <= 4, "그리고 넷을 넘는 경로는 없다 (최대 %d) — 명부 상한이 이 수에 걸려 있다"
		% counts_max)
	# 「부리 칸을 지나는 경로가 있다」 — the other end of the same fork.
	t.ok(beaks_max >= 2, "부리를 둘까지 모으는 경로가 있다 (최대 %d) — 갈림길의 부리 쪽 답이다" % beaks_max)
	t.ok(beaks_max <= 2, "그리고 둘을 넘지 않는다 (최대 %d)" % beaks_max)
	# ⚠ **And the two answers really are different answers.** If min and max agreed on either axis the
	# fork would be a decoration: every route would pay the same thing and the map would be a corridor
	# with pictures on it — this repo's second game died of exactly that shape.
	t.ok(counts_max - counts_min >= 2,
		"경로에 따라 짐승 칸 수가 %d~%d 로 갈린다 — 두 칸 이상 차이가 나야 고를 이유가 있다"
			% [counts_min, counts_max])
	t.ok(beaks_max - beaks_min >= 2, "부리 칸 수도 %d~%d 로 갈린다" % [beaks_min, beaks_max])
	t.eq(beaks_min, 0, "부리를 하나도 안 지나는 경로가 있다 — 짐승을 넷 다 먹는 길이 바로 그 길이다")

	# 「`map_max_count_nodes_on_a_route()` 가 그 최대와 같다」 — the accessor is walked over the table
	# and never written as a literal 4, because `net_islands`'s region floor and the roster capacity
	# both ride on it. Mutation: hardcode it to 1.
	t.eq(Rules.map_max_count_nodes_on_a_route(), counts_max,
		"map_max_count_nodes_on_a_route() 가 걸어서 나온 최대(%d)와 같다" % counts_max)
	t.ok(Rules.map_max_count_nodes_on_a_route() >= 1,
		"그리고 1 이상이다 — 0이면 보상이 붙는 칸이 하나도 없다는 뜻이다")


# -- the walk map.gd takes -------------------------------------------------------------------------

func _the_walk_over_it(t) -> void:
	var m := RunMap.new()
	t.eq(m.path.size(), 0, "새 지도는 밟은 칸이 없다")
	t.eq(m.at(), -1, "그래서 서 있는 칸이 -1 이다 — 아직 아무 데도 안 내렸다는 뜻이고 오류가 아니다")
	t.ok(not m.is_finished(), "아무 데도 안 내린 지도는 끝난 지도가 아니다")

	# 「런을 시작하면 1층 칸 하나만 갈 수 있다」 — floor: exactly one; ceiling: not two. Mutation: make
	# `is_reachable` true for every floor-0 node (there is only one, so the real bite is the
	# floor test vanishing and every node opening).
	var first := m.reachable_nodes()
	t.eq(first.size(), 1, "처음에 갈 수 있는 칸은 정확히 하나다")
	t.eq(first[0], 0, "그 하나가 0번 칸이다")
	t.ok(not m.is_reachable(3), "3층 칸에는 바로 못 간다")
	t.ok(not m.is_reachable(6), "보스에게도 바로 못 간다")
	t.ok(not m.is_reachable(-1), "-1 은 갈 수 있는 칸이 아니다")
	t.ok(not m.is_reachable(Rules.map_node_count()), "표 밖 번호도 갈 수 있는 칸이 아니다")

	# 「닿을 수 없는 칸은 `enter` 가 거절하고 아무것도 안 바꾼다」 — floor: `path` is untouched;
	# ceiling: it returns false. Mutation: let `enter` append unconditionally.
	t.ok(not m.enter(3), "닿을 수 없는 칸은 enter 가 false 를 낸다")
	t.eq(m.path.size(), 0, "그리고 밟은 자취가 그대로 비어 있다")
	t.ok(not m.enter(-1), "음수도 거절한다")
	t.ok(not m.enter(9_999), "표 밖 번호도 거절한다")
	t.eq(m.path.size(), 0, "잘못된 번호 셋을 넣고도 자취가 비어 있다")

	t.ok(m.enter(0), "0번 칸은 밟힌다")
	t.eq(m.at(), 0, "그래서 서 있는 칸이 0번이다")
	# 「서 있는 칸은 아직 깬 칸이 아니다」 — the one place "visited" and "cleared" differ, and folding
	# them lights the node the player is currently losing on. Mutation: plain membership.
	t.ok(not m.is_cleared(0), "서 있는 칸은 아직 깬 칸이 아니다 — 그 섬은 아직 안 이겼다")
	t.ok(not m.is_cleared(1), "안 밟은 칸도 깬 칸이 아니다")

	# 「1층을 밟으면 2층 두 칸이 다 열린다」
	var second := m.reachable_nodes()
	t.eq(second.size(), 2, "0번을 밟으면 2층 두 칸이 다 열린다")
	t.eq(second[0], 1, "왼쪽이 1번")
	t.eq(second[1], 2, "오른쪽이 2번")
	t.ok(not m.is_reachable(0), "이미 밟은 칸으로는 다시 못 간다")

	t.ok(m.enter(2), "오른쪽 2번을 밟는다")
	t.ok(m.is_cleared(0), "그러자 0번이 깬 칸이 된다 — 발을 뗀 뒤에야 깬 것이다")
	t.ok(not m.is_cleared(2), "그리고 지금 서 있는 2번은 아직 아니다")

	# 「2층 어느 칸에서도 3층 두 칸에 다 닿는다」 — ⚠ the rejoin is what stops one bad turn locking the
	# map. Mutation: delete [2, 4], and the map still walks, still draws, and quietly becomes two
	# corridors.
	var third := m.reachable_nodes()
	t.eq(third.size(), 2, "2번에서도 3층 두 칸에 다 닿는다")
	t.eq(third, PackedInt32Array([3, 4]), "그 둘이 3번과 4번이다 — 갈래가 갈렸다 다시 합류한다")
	var left := RunMap.new()
	left.enter(0)
	left.enter(1)
	t.eq(left.reachable_nodes(), PackedInt32Array([3, 4]),
		"왼쪽 1번에서도 똑같이 3번과 4번 둘 다다 — 한 번 잘못 꺾어도 지도가 안 잠긴다")

	t.ok(m.enter(4), "4번을 밟는다")
	t.eq(m.reachable_nodes(), PackedInt32Array([5]), "3층 다음은 상자 하나뿐이다")
	t.ok(m.enter(5), "상자를 밟는다")
	t.eq(m.reachable_nodes(), PackedInt32Array([6]), "상자 다음은 보스 하나뿐이다")
	t.ok(not m.is_finished(), "상자 위에 서 있는 것은 끝난 것이 아니다")
	t.ok(m.enter(6), "보스를 밟는다")
	t.ok(m.is_finished(), "보스 칸에 서면 지도가 끝난다")
	t.eq(m.reachable_nodes().size(), 0, "그리고 더 갈 데가 없다")
	t.eq(m.path, PackedInt32Array([0, 2, 4, 5, 6]), "걸어온 자취가 밟은 순서 그대로다")

	# 「edge_is_travelled」 — derived, never stored: the picture the view draws and the sim's progress
	# are read off the same array, so a line cannot reach a node the run never stood on.
	var walked := 0
	var wrong := 0
	for e in Rules.map_edge_count():
		var a := Rules.map_edge_from(e)
		var b := Rules.map_edge_to(e)
		var want := false
		for i in range(m.path.size() - 1):
			if m.path[i] == a and m.path[i + 1] == b:
				want = true
		if m.edge_is_travelled(e) != want:
			wrong += 1
		if m.edge_is_travelled(e):
			walked += 1
	t.eq(wrong, 0, "지나온 변만 지나온 것으로 나온다")
	t.eq(walked, 4, "지나온 변이 넷이다 — 칸 다섯을 걸었으니 변은 넷이다")
	t.ok(not m.edge_is_travelled(-1), "없는 변 번호는 false 다")
	t.ok(not m.edge_is_travelled(Rules.map_edge_count()), "표 밖 변 번호도 false 다")
	# The direction matters: [0,1] and [1,0] are not the same permission, and a walker that ignored
	# the order would light the line for a route the run never took.
	var back := RunMap.new()
	back.enter(0)
	back.enter(1)
	var lit := 0
	for e in Rules.map_edge_count():
		if back.edge_is_travelled(e):
			lit += 1
	t.eq(lit, 1, "두 칸만 걸었으면 켜지는 변도 하나뿐이다")

	m.reset()
	t.eq(m.path.size(), 0, "reset 하면 자취가 비고")
	t.eq(m.at(), -1, "서 있는 칸도 -1 로 돌아간다")
	t.ok(not m.is_finished(), "그리고 끝난 지도가 아니게 된다")


# -- the ex-chest floor --------------------------------------------------------------------------------

## ⚠⚠ 「4층 칸도 섬을 연다」 — node 5, floor 4, WAS the chest and had no island. Walked the way a run
## does: node 0, win, node 1, win, node 3, win (a beak node, so a pick is taken), then node 5.
## Mutation: give node 5 back `island < 0`.
## Every win now stops for the card pick before the map (「6개중 2택」). ⚠ **`enter_node` refuses
## unless `_state == MAP`**, so a route walk that skips the pick between two nodes never reaches the
## second one at all — `enter_node` would just return false and the whole rest of this function would
## read a run parked one node behind where it looks like it should be. Mutation: skip the take/close
## pair on any leg below and every `enter_node` after it silently starts returning false.
func _take_two_and_close_refit(r: Run) -> void:
	if r.state() != Run.State.PICK:
		return
	r.take_card(0)
	r.take_card(1)
	r.close_refit()


func _the_fourth_floor_opens_an_island_too(t) -> void:
	var r := Run.new()
	t.ok(r.enter_node(0), "0번 칸을 밟는다")
	r.finish_island(true)
	t.eq(r.state(), Run.State.PICK, "0번은 짐승 칸이라 지도 전에 카드 고르기부터 연다 (자가 점검)")
	_take_two_and_close_refit(r)
	t.eq(r.state(), Run.State.MAP, "카드를 고르고 정비를 닫아야 지도다 (자가 점검)")

	t.ok(r.enter_node(1), "1번 칸을 밟는다")
	r.finish_island(true)
	_take_two_and_close_refit(r)

	t.ok(r.enter_node(3), "3번 칸을 밟는다")
	r.finish_island(true)
	t.eq(r.state(), Run.State.REWARD, "3번은 부리 칸이라 고르기가 열렸다 (자가 점검)")
	r.apply_beak(0)
	# ⚠⚠ 「부리를 달고 나면 지도가 아니라 카드 화면이다」 — 3번의 승리도 여섯 장을 냈고 `apply_beak`
	# 는 그 카드를 건드리지 않으므로, `_advance` 는 `MAP` 이 아니라 `PICK` 에 내려앉는다.
	t.eq(r.state(), Run.State.PICK, "부리를 달고 나면 지도가 아니라 카드 고르기다")
	_take_two_and_close_refit(r)
	t.eq(r.state(), Run.State.MAP, "카드를 고르고 정비를 닫아야 비로소 지도다")
	t.eq(r.map.at(), 3, "서 있는 칸은 3번 그대로다")

	var before := r.army.living_count()
	t.ok(r.enter_node(5), "4층 칸(옛 상자 자리)을 밟는다")
	t.eq(r.state(), Run.State.BATTLE, "섬이 열린다 — 상자처럼 그 자리에서 끝나지 않는다")
	t.ok(r.begin_island() != null, "그리고 실제로 전투가 만들어진다")
	r.finish_island(true)
	t.eq(r.state(), Run.State.PICK, "이겼으니 카드 고르기부터 연다 — COUNT는 고를 게 없어도 카드는 있다")

	# ⚠ 「이기면 카드가 여섯 장 나온다」 — the win drew the six cards even though the COUNT reward itself
	# had nothing to choose. Mutation: skip `_draw_cards()` inside `finish_island`.
	t.eq(r.cards.size(), Rules.CARDS_PER_WIN, "이긴 뒤 카드 배열이 세 장이다 — 카드 하나가 정수 하나다")

	_take_two_and_close_refit(r)
	t.eq(r.state(), Run.State.MAP, "카드를 고르고 정비를 닫으면 지도로 돌아온다")
	t.ok(r.army.living_count() > before, "그리고 COUNT 보상으로 병력이 늘었다 (%d -> %d)"
		% [before, r.army.living_count()])

	t.eq(r.map.reachable_nodes(), PackedInt32Array([6]), "4층 다음은 보스뿐이다")
	t.ok(r.enter_node(6), "보스를 밟는다")
	t.eq(r.state(), Run.State.BATTLE, "보스는 섬을 연다")
	r.finish_island(true)
	t.eq(r.state(), Run.State.WON, "보스를 이기면 런이 끝난다 — 지도로도 카드 고르기로도 안 돌아간다")


# -- the picture -----------------------------------------------------------------------------------

func _the_picture(t) -> void:
	# 「칸 일곱의 판정 원이 전부 Rect2(0,0,1280,720) 안이다」 — against the LITERALS. Mutation: move
	# node 6 to y 40.
	var off_screen := 0
	for n in Rules.map_node_count():
		var c := Look.map_node_pos_px(n)
		var reach := Look.map_node_hit_radius_px(Rules.map_kind_of(n))
		if not SCREEN.encloses(Rect2(c - Vector2(reach, reach), Vector2(reach, reach) * 2.0)):
			off_screen += 1
		# The you-are-here ring is bigger than the node it marks and can sit on any of them.
		var ring := Look.MAP_HERE_RING_R_PX + Look.MAP_HERE_RING_WIDTH_PX
		if not SCREEN.encloses(Rect2(c - Vector2(ring, ring), Vector2(ring, ring) * 2.0)):
			off_screen += 1
	t.eq(off_screen, 0, "칸 일곱의 판정 원도, 그 위에 앉을 수 있는 고리도 전부 1280x720 안이다")

	# 「어느 두 칸의 판정도 안 겹친다」 — floor: centres at least 120 px apart; ceiling: and the hit
	# circles themselves never touch, which is the stronger claim the 120 exists to buy. Mutation:
	# move node 3 to (470, 460).
	var closest := 99_999.0
	var touching := 0
	for a in Rules.map_node_count():
		for b in range(a + 1, Rules.map_node_count()):
			var gap := Look.map_node_pos_px(a).distance_to(Look.map_node_pos_px(b))
			closest = minf(closest, gap)
			var sum_reach := Look.map_node_hit_radius_px(Rules.map_kind_of(a)) \
				+ Look.map_node_hit_radius_px(Rules.map_kind_of(b))
			if gap <= sum_reach:
				touching += 1
	t.ok(closest >= MIN_CENTRE_GAP_PX, "가장 가까운 두 칸의 중심이 %.0fpx 떨어져 있다 (>= 120)" % closest)
	t.eq(touching, 0, "그래서 어느 두 칸의 판정 원도 안 닿는다 — 한 번 누르면 한 칸만 잡힌다")
	t.ok(Look.MAP_BOSS_R_PX > Look.MAP_NODE_R_PX,
		"보스가 다른 칸보다 크다 (%.0f > %.0f) — 크기가 종류를 말하는 세 축 중 하나다"
			% [Look.MAP_BOSS_R_PX, Look.MAP_NODE_R_PX])
	# ⚠ **The ceiling that `>` relation never had.** `MAP_BOSS_R_PX` gets MORE true against the row
	# above as it grows, and the two rows that would eventually catch it — the screen enclosure and
	# the hit-circle gap — only bite at 83. Its own comment says 70, from 56 + 48 = 104 < 140.
	t.ok(Look.MAP_BOSS_R_PX <= 70.0,
		"그래도 보스가 70px 을 안 넘는다 (%.0f) — 위면 보스와 상자 칸의 판정 원이 닿는다"
			% Look.MAP_BOSS_R_PX)
	t.ok(Look.MAP_HERE_RING_R_PX > Look.MAP_NODE_R_PX,
		"고리는 칸보다 바깥에 있다 — 안쪽이면 칸 밑에 숨는다")
	# Same shape one knob over: the row above gets more true as the ring grows, and a ring wide enough
	# to reach the next floor points at two nodes at once.
	t.ok(Look.MAP_HERE_RING_R_PX <= 68.0,
		"그래도 여기 고리가 68px 을 안 넘는다 (%.0f) — 68 + 48 = 116 이 칸 간격 120px 안이다"
			% Look.MAP_HERE_RING_R_PX)
	# ⚠ **`MAP_RING_SEGMENTS` was referenced by NO row at all.** Every closed shape on this screen —
	# node outlines, the boss's nested rings, the you-are-here arc — is built at this count, so 3 turns
	# the whole map into triangles and 200 costs more than it shows.
	t.ok(Look.MAP_RING_SEGMENTS >= 16 and Look.MAP_RING_SEGMENTS <= 64,
		"동그라미 한 개를 잇는 선분이 16~64개다 (%d) — 밑이면 56px 원에 각이 보이고 위면 값만 비싸진다"
			% Look.MAP_RING_SEGMENTS)
	t.eq(Look.MAP_RING_SEGMENTS % 4, 0,
		"그리고 4의 배수다 — 네 축마다 꼭짓점이 하나씩 떨어져야 아래의 반지름 되읽기가 정확해진다")
	# ⚠⚠ **`MAP_NODE_R_PX` had a ceiling and no floor**, and both rows above it are `>` relations that
	# get MORE true as it shrinks — so `40 -> 4` was green: seven 4px dots with 12px hit circles and the
	# 13px glyph drawn outside the node it belongs to. The floor is the constant's own comment, and the
	# stronger half is the press rule the title screen is held to: **the hit circle is at least 64px
	# across**, against the same literal 64 `net_title` pins as its smallest pressable box.
	t.ok(Look.MAP_NODE_R_PX >= 28.0,
		"칸 반지름이 28px 이상이다 (%.0f) — 밑이면 안에 그린 무늬가 뭉개진다" % Look.MAP_NODE_R_PX)
	t.ok(Look.MAP_NODE_R_PX <= 52.0,
		"그리고 52px 을 안 넘는다 (%.0f) — 2 x 52 = 104 는 120px 세로 간격에 16px 밖에 안 남긴다"
			% Look.MAP_NODE_R_PX)
	var too_small_press := 0
	for kind in [Rules.NodeKind.FIGHT, Rules.NodeKind.BOSS]:
		if Look.map_node_hit_radius_px(int(kind)) * 2.0 < 64.0:
			too_small_press += 1
	t.eq(too_small_press, 0,
		"칸 두 종류의 판정 원이 전부 지름 64px 이상이다 — 타이틀 칸에 건 것과 같은 리터럴이다")

	# ⚠ **The glyph radius was referenced by NO net at all**: every point is built as `c +- r * k`, so
	# `MAP_GLYPH_R_PX = 0` collapses all six glyphs onto their node centres and the point-count rows
	# below still hold. Both ends, and the ceiling is the constant's own comment.
	# ⚠⚠ **The floor was 8 and that is what let the defect ship**: 13 px cleared it comfortably and the
	# glyph was still 「a few pixels of line art inside a 40 px circle」 — the user could not tell what
	# a node paid. A floor that the broken value passes is not a floor. It is 12 now, from the COUNT
	# glyph's own arithmetic: its squares are `2 x 0.28 x r` on a side, so at r = 12 they are 6.7 px
	# against a 3 px stroke and fill solid.
	t.ok(Look.MAP_GLYPH_R_PX >= 12.0,
		"무늬 반지름이 12px 이상이다 (%.0f) — 밑이면 짐승 칸 네모 세 개가 획으로 꽉 찬다"
			% Look.MAP_GLYPH_R_PX)
	# The ceiling is the widest glyph fitting inside the SMALLEST drawn node. The COUNT glyph reaches
	# `0.80 + 0.28 = 1.08` radii out, half the stroke goes outside that, and the smallest node on the
	# screen is a locked one at `MAP_NODE_R_PX * MAP_NODE_LOCKED_SCALE`.
	var widest_glyph := Look.MAP_GLYPH_R_PX * 1.08 + Look.MAP_GLYPH_WIDTH_PX * 0.5
	var smallest_node := Look.MAP_NODE_R_PX * Look.MAP_NODE_LOCKED_SCALE
	t.ok(widest_glyph <= smallest_node,
		"가장 넓은 무늬(%.1fpx)가 가장 작게 그려지는 칸(%.1fpx) 안에 들어간다 — 무늬는 칸 따라 안 줄어든다"
			% [widest_glyph, smallest_node])
	t.ok(Look.MAP_GLYPH_WIDTH_PX >= 2.0 and Look.MAP_GLYPH_WIDTH_PX <= 5.0,
		"무늬 획이 2~5px 다 (%.1f) — 밑은 스냅 바닥이고 위면 네모 세 개가 덩어리 셋으로 읽힌다"
			% Look.MAP_GLYPH_WIDTH_PX)

	# -- the four states a node can be drawn in ----------------------------------------------------
	# ⚠⚠ **This block is the round's whole reason.** The first build put the difference between "where
	# I may go" and "where I cannot" into a hover and a pulse — one channel each, both of which need
	# either a cursor or a moving frame — and at rest every node but one was the same grey. What is
	# pinned here is that the four states differ in SIZE and in BRIGHTNESS, both of which survive a
	# still screenshot, and that neither channel is allowed to collapse on its own.
	t.ok(Look.MAP_NODE_LOCKED_SCALE < Look.MAP_NODE_PAST_SCALE
			and Look.MAP_NODE_PAST_SCALE < 1.0,
		"크기가 못 감 < 지나옴 < 지금 갈 수 있음 순으로 커진다 (%.2f < %.2f < 1.0)"
			% [Look.MAP_NODE_LOCKED_SCALE, Look.MAP_NODE_PAST_SCALE])
	# Both ends, and the floors are the halves that prove the channel EXISTS: a scale of 0.99 is
	# arithmetically a ladder and visually nothing. 40 px x 0.06 = 2.4 px, just over the snap floor.
	t.ok(1.0 - Look.MAP_NODE_PAST_SCALE >= 0.06,
		"지나온 칸이 갈 수 있는 칸보다 %.1fpx 작다 — 2px 아래면 화면에서 같은 크기다"
			% (Look.MAP_NODE_R_PX * (1.0 - Look.MAP_NODE_PAST_SCALE)))
	t.ok(Look.MAP_NODE_PAST_SCALE - Look.MAP_NODE_LOCKED_SCALE >= 0.06,
		"못 가는 칸도 지나온 칸보다 %.1fpx 더 작다"
			% (Look.MAP_NODE_R_PX * (Look.MAP_NODE_PAST_SCALE - Look.MAP_NODE_LOCKED_SCALE)))
	t.ok(Look.MAP_NODE_LOCKED_SCALE >= 0.62,
		"그래도 못 가는 칸이 0.62 밑으로는 안 줄어든다 (%.2f) — 밑이면 무늬가 칸 밖으로 삐져나온다"
			% Look.MAP_NODE_LOCKED_SCALE)
	# ⚠ The size channel must never push a node's rim outside the circle you can press. The pulse
	# rides on the FULL radius, so this is the one sum that matters.
	var open_rim := Look.MAP_NODE_R_PX + Look.MAP_PULSE_R_PX
	t.ok(open_rim <= Look.map_node_hit_radius_px(Rules.NodeKind.FIGHT),
		"가장 크게 그려지는 순간의 테두리(%.0fpx)도 판정 원(%.0fpx) 안이다 — 보이는 가장자리가 눌린다"
			% [open_rim, Look.map_node_hit_radius_px(Rules.NodeKind.FIGHT)])
	t.ok(Look.MAP_NODE_PAST_ALPHA > Look.PRESS_ALPHA_OFF + 0.1
			and Look.MAP_NODE_PAST_ALPHA < Look.PRESS_ALPHA_ON - 0.1,
		"지나온 칸의 진하기 %.2f 가 못 감(%.2f)과 갈 수 있음(%.2f) 사이에서 양쪽 다 0.1 넘게 떨어져 있다"
			% [Look.MAP_NODE_PAST_ALPHA, Look.PRESS_ALPHA_OFF, Look.PRESS_ALPHA_ON])
	# ⚠ The you-are-here ring is the mark that answers 「지금 내가 어디 있나」, and it had a ceiling and
	# no floor: at 2px it is a hairline and the whole answer is gone with the round green.
	t.ok(Look.MAP_HERE_RING_WIDTH_PX >= 4.0,
		"여기 고리가 4px 이상 굵다 (%.0f) — 밑이면 지금 어디 있는지가 실선 한 줄로 사라진다"
			% Look.MAP_HERE_RING_WIDTH_PX)
	t.ok(Look.MAP_HERE_RING_WIDTH_PX <= 8.0, "그래도 8px 을 안 넘는다 — 위면 가리키는 칸을 삼킨다")
	# ⚠ **It used to double as the boss's inner-ring width.** Two concepts on one knob is what stops a
	# person tuning either, so the boss got its own — and this row is what keeps them apart.
	t.ok(Look.MAP_BOSS_RING_WIDTH_PX >= 2.0
			and Look.MAP_BOSS_RING_WIDTH_PX <= Look.MAP_BOSS_RING_STEP_PX - 4.0,
		"보스 겹고리 굵기 %.0fpx 가 2px~(간격 %.0f - 4)px 다 — 위면 세 고리가 한 띠로 붙는다"
			% [Look.MAP_BOSS_RING_WIDTH_PX, Look.MAP_BOSS_RING_STEP_PX])
	# ⚠⚠ **The row above was `MAP_BOSS_RING_STEP_PX`'s ONLY coverage and it gets MORE true as the step
	# grows** — exactly the shape flagged for `MAP_NODE_R_PX` twenty lines up, applied to that sibling
	# and not to this one. At 60 the two inner rings land at radius -4 and -64 against a 56px boss:
	# a 64px ring painted in the BACKDROP tone outside the disc it is meant to be cut out of, with the
	# round green. Its own comment says 6..18, from 56 - 2 * 18 = 20 > 0.
	t.ok(Look.MAP_BOSS_RING_STEP_PX >= 6.0 and Look.MAP_BOSS_RING_STEP_PX <= 18.0,
		"보스 겹고리 간격이 6~18px 다 (%.0f) — 밑이면 세 고리가 한 고리이고 위면 안쪽 고리가 보스 밖으로 나간다"
			% Look.MAP_BOSS_RING_STEP_PX)
	# The strong form of the same claim, in arithmetic rather than by literal: the INNERMOST ring still
	# has a positive radius. Driven off the capture further down as well.
	t.ok(Look.MAP_BOSS_R_PX - float(Look.MAP_BOSS_RINGS - 1) * Look.MAP_BOSS_RING_STEP_PX
			- Look.MAP_BOSS_RING_WIDTH_PX * 0.5 > 0.0,
		"가장 안쪽 겹고리(반지름 %.0fpx)가 획 두께까지 보스 안에 남는다"
			% (Look.MAP_BOSS_R_PX - float(Look.MAP_BOSS_RINGS - 1) * Look.MAP_BOSS_RING_STEP_PX))

	# ⚠ The two colours, and they have to be DIFFERENT: the chest's diamond is gone with it, so a fight
	# and the boss are told apart by size and by the boss's nested rings, and by hue as well.
	var fight := Look.map_node_colour_of(Rules.NodeKind.FIGHT)
	var boss := Look.map_node_colour_of(Rules.NodeKind.BOSS)
	var hue_gap: float = minf(absf(fight.h - boss.h), 1.0 - absf(fight.h - boss.h))
	t.ok(hue_gap >= 0.08, "칸 두 종류의 색상이 서로 최소 29도 떨어져 있다")
	t.eq(Look.map_node_sides_of(Rules.NodeKind.FIGHT), 0, "싸우는 칸은 원이다")
	t.eq(Look.map_node_sides_of(Rules.NodeKind.BOSS), 0, "보스도 원이고, 대신 크기와 겹고리로 갈린다")
	t.ok(Look.MAP_BOSS_RINGS == 3, "보스 겹고리는 셋이다")

	# The three line weights, each above the next by more than the 2 px snap floor, or two of the
	# three are the same picture.
	t.ok(Look.MAP_LINE_PAST_WIDTH_PX > Look.MAP_LINE_OPEN_WIDTH_PX
			and Look.MAP_LINE_OPEN_WIDTH_PX > Look.MAP_LINE_DIM_WIDTH_PX,
		"선 굵기 셋이 지나온 > 갈 수 있는 > 아무것도 아닌 순서다 (%.0f > %.0f > %.0f)"
			% [Look.MAP_LINE_PAST_WIDTH_PX, Look.MAP_LINE_OPEN_WIDTH_PX, Look.MAP_LINE_DIM_WIDTH_PX])
	# ⚠⚠ **This row used to NAME one pair, and it named the wrong one.** It read
	# `OPEN - DIM >= 2.0` under the label 「가장 붙어 있는 두 굵기」, but that pair is 3.0 apart and the
	# actually-tightest pair was PAST-OPEN at exactly 2.0 — which had only a bare `>` of its own, so
	# `8.0 -> 6.1` against a 6.0 sibling was green with two of the three lines the same picture.
	# Naming a pair fixes the day it is written and nothing after it, the same way naming a function in
	# `net_draw_leaf`'s table does. **The minimum is taken over the whole ladder now**, and the floor is
	# above 2.0 rather than at it, because `look.gd`'s own header sentence says *more than* the snap
	# floor and the shipped 8.0 did not satisfy the sentence written directly above it.
	var widths := [Look.MAP_LINE_PAST_WIDTH_PX, Look.MAP_LINE_OPEN_WIDTH_PX,
		Look.MAP_LINE_DIM_WIDTH_PX]
	var tightest_width := 99.0
	for i in range(widths.size() - 1):
		tightest_width = minf(tightest_width, float(widths[i]) - float(widths[i + 1]))
	t.ok(tightest_width >= 2.5,
		"세 굵기 중 가장 붙어 있는 두 개가 %.1fpx 벌어져 있다 (>= 2.5) — 2.0 은 스냅 바닥 그 자체라 「넘는다」가 아니다"
			% tightest_width)
	t.ok(Look.MAP_LINE_PAST_WIDTH_PX <= 12.0, "그래도 가장 굵은 선이 12px 을 안 넘는다")
	t.ok(Look.MAP_LINE_DIM_ALPHA >= 0.15,
		"안 걸은 선도 알파 %.2f 로 보이긴 한다 — 지도 전체가 첫 프레임부터 보여야 경로가 결정이 된다"
			% Look.MAP_LINE_DIM_ALPHA)
	t.ok(Look.MAP_LINE_DIM_ALPHA <= 0.45, "그래도 0.45 를 안 넘는다 — 그 위면 세 굵기가 한 뭉치로 읽힌다")
	# ⚠⚠ **The alpha row was written for the DIM sibling and for neither of the other two**, and both
	# went to 0.0 with 1816 checks green: `PAST` at 0 erases the travelled route — the map's whole
	# progress readout — and `OPEN` at 0 erases every line the run may still take. This repo's named
	# "the plan's own fix gets applied to one value and not to its siblings", one line over in
	# `look.gd`.
	t.ok(Look.MAP_LINE_PAST_ALPHA >= 0.8,
		"지나온 선이 알파 %.2f 로 진하다 (>= 0.8) — 0이면 걸어온 길이 통째로 사라진다"
			% Look.MAP_LINE_PAST_ALPHA)
	t.ok(Look.MAP_LINE_PAST_ALPHA <= 1.0, "그리고 1.0 을 안 넘는다")
	t.ok(Look.MAP_LINE_OPEN_ALPHA >= 0.6,
		"갈 수 있는 선도 알파 %.2f 다 (>= 0.6) — 0이면 고를 길이 안 보인다" % Look.MAP_LINE_OPEN_ALPHA)
	t.ok(Look.MAP_LINE_OPEN_ALPHA <= 1.0, "그리고 1.0 을 안 넘는다")
	t.ok(Look.MAP_LINE_PAST_ALPHA - Look.MAP_LINE_DIM_ALPHA >= 0.3,
		"지나온 선과 안 걸은 선의 알파가 0.3 이상 벌어져 있다 (%.2f) — 굵기 말고 진하기로도 갈린다"
			% (Look.MAP_LINE_PAST_ALPHA - Look.MAP_LINE_DIM_ALPHA))
	# ⚠ **PAST and OPEN were never related to EACH OTHER on either channel.** The widths carry that
	# pair now; what this pins is that the alpha ladder cannot INVERT it — a choosable line brighter
	# than the road already taken says the map's progress backwards. It is an ordering row and not a
	# gap row on purpose: the separation is the 3px of width, and demanding a gap here too would forbid
	# the two lines being equally solid, which is a legitimate thing to tune toward.
	t.ok(Look.MAP_LINE_PAST_ALPHA >= Look.MAP_LINE_OPEN_ALPHA,
		"지나온 선이 갈 수 있는 선보다 흐리지 않다 (%.2f >= %.2f)"
			% [Look.MAP_LINE_PAST_ALPHA, Look.MAP_LINE_OPEN_ALPHA])
	t.ok(Look.MAP_LINE_OPEN_ALPHA - Look.MAP_LINE_DIM_ALPHA >= 0.3,
		"갈 수 있는 선과 안 걸은 선의 알파도 0.3 이상 벌어져 있다 (%.2f) — 고를 길과 배경이 갈린다"
			% (Look.MAP_LINE_OPEN_ALPHA - Look.MAP_LINE_DIM_ALPHA))

	# -- treed, with a real run behind it ----------------------------------------------------------
	var run := Run.new()
	var spy := MapSpy.new()
	t.root.add_child(spy)
	# ⚠⚠ **`set_process(false)` DOES NOT HOLD, and this was measured on 4.7.1 rather than assumed.**
	# A `Node2D` whose script defines `_process` has processing switched back ON by the engine on the
	# first frame after it enters the tree — `set_process(false)` right after `add_child` reads back
	# false immediately and TRUE two frames later, and setting it before `add_child` loses the same
	# way. A view frozen that way is aged by a real 6.9 ms delta on every pumped frame, which is
	# exactly the tolerance a timing row cannot absorb. `PROCESS_MODE_DISABLED` holds, and `_draw`
	# still runs under it (both halves measured).
	spy.process_mode = Node.PROCESS_MODE_DISABLED
	spy.bind(run)
	# The reveal is a beat: at age 0 nothing is drawn at all, which is the fade arriving out of the
	# background. Push past the whole of it for the geometry checks below.
	spy._fx_step(Look.SCENE_FADE_SEC + Look.MAP_NODE_FADE_SEC * 4.0)
	spy.queue_redraw()
	await t.pump_frames(2)
	t.ok(spy.draws >= 1, "지도의 _draw 가 트리 위에서 진짜 돌았다 (%d프레임)" % spy.draws)

	t.eq(spy.edges.size(), Rules.map_edge_count(), "변 아홉을 다 그렸다")
	t.eq(spy.nodes.size(), Rules.map_node_count(), "칸 일곱을 다 그렸다")
	var node_bad := 0
	for n in Rules.map_node_count():
		var raw: Dictionary = spy.nodes[n]
		if (raw["centre"] as Vector2) != Look.map_node_pos_px(n):
			node_bad += 1
		if int(raw["sides"]) != Look.map_node_sides_of(Rules.map_kind_of(n)):
			node_bad += 1
		# ⚠⚠ **This row read `>= 기본 반지름` and so could not see the size channel at all** — every
		# node drawn at the same size passed it, which is the defect the round exists to fix. With an
		# empty `path`, node 0 is the ONLY node on offer and the other six are locked; the expectation
		# is written out by hand rather than asked of `_look_of`, because a check whose bounds come
		# from the thing it checks proves nothing.
		var full := Look.map_node_radius_px(Rules.map_kind_of(n))
		if n == 0:
			if float(raw["radius"]) < full or float(raw["radius"]) > full + Look.MAP_PULSE_R_PX:
				node_bad += 1
		elif not is_equal_approx(float(raw["radius"]), full * Look.MAP_NODE_LOCKED_SCALE):
			node_bad += 1
		# The polygon branch has to be handed real geometry, or `draw_colored_polygon` gets an empty
		# array and draws nothing at all with the round green.
		# ⚠⚠ **A point COUNT cannot see a ring collapse.** `_ring_points(centre, radius * 0.0, ...)`
		# hands back the right NUMBER of points, all of them at the centre — the chest's diamond
		# becomes a dot and every border becomes a dot, and the count row plus `_ring_centre` (a
		# bounding box of zero extent still has the right middle) stayed green at 1911. This repo's own
		# `draw_circle(p, 0.0, col)` case, reaching the GEOMETRY argument instead of the radius one.
		# The extent is read back off the argument the leaf was handed and compared to the radius the
		# SAME capture carries, which is the row that closes it.
		var pts: PackedVector2Array = raw["points"]
		var want_pts: int = int(raw["sides"]) if int(raw["sides"]) > 0 else Look.MAP_RING_SEGMENTS
		if pts.size() != want_pts:
			node_bad += 1
		elif absf(_ring_extent(pts) - float(raw["radius"])) > 0.01:
			node_bad += 1
	t.eq(node_bad, 0,
		"칸 일곱이 각자 자리·모양으로 그려졌고, 갈 수 있는 칸만 제 크기이고 못 가는 여섯은 %.0f%% 로 줄어 있다 — 넘어간 점들도 그 반지름만큼 실제로 벌어져 있다"
			% (Look.MAP_NODE_LOCKED_SCALE * 100.0))

	# 「`_paint_glyph` 가 받은 점이 비어 있지 않다」 — ⚠ the scanner skips the unused-argument check on
	# any function whose draw count is 0, so a leaf holding `draw_multiline(PackedVector2Array(), ...)`
	# reads as one draw call with every argument used and draws nothing. Mutation: return an empty
	# array from `_glyph_points`.
	t.eq(spy.glyphs.size(), 6, "보상이 있는 칸 여섯에 무늬를 그렸다 — 보스는 크기와 겹고리로 말한다")
	var glyph_bad := 0
	var glyph_points := 0
	var glyph_alpha_min := 9.0
	var glyph_alpha_max := -9.0
	for g: Dictionary in spy.glyphs:
		var pts: PackedVector2Array = g["points"]
		glyph_points += pts.size()
		if pts.size() < 3:
			glyph_bad += 1
		if pts.size() > 24:
			glyph_bad += 1
		if pts.size() % 2 != 0:
			glyph_bad += 1
		if float(g["width"]) != Look.MAP_GLYPH_WIDTH_PX:
			glyph_bad += 1
		var ink_a := (g["col"] as Color).a
		glyph_alpha_min = minf(glyph_alpha_min, ink_a)
		glyph_alpha_max = maxf(glyph_alpha_max, ink_a)
	t.eq(glyph_bad, 0, "무늬 여섯이 전부 점 3~24개를 짝수로 받았다 (draw_multiline 은 점 쌍이다)")
	t.ok(glyph_points >= 18, "무늬 점이 다 합쳐 %d개다 — 빈 배열을 넘기면 여기가 문다" % glyph_points)
	# ⚠⚠ **`_paint_glyph` 's COLOUR was captured and read by nothing.** `ink.a * 0.0` erased all six
	# rewards with 1911 checks green. Both ends against LITERALS: the floor says the ink exists, the
	# ceiling says it is still ink rather than a second fill.
	t.ok(glyph_alpha_min >= 0.20,
		"화면까지 간 무늬 여섯의 알파가 전부 0.20 이상이다 (가장 옅은 것이 %.2f)" % glyph_alpha_min)
	t.ok(glyph_alpha_max <= 1.0, "그리고 1.0 을 안 넘는다 (%.2f)" % glyph_alpha_max)
	# ⚠⚠ **And an alpha floor alone is not the claim — CONTRAST is.** At the shipped values the LOCKED
	# glyph cleared any alpha floor and was still unreadable: the ink reused `PRESS_ALPHA_OFF` 0.30 and
	# the fill under it is also at 0.30, which verify-look measured at **1.3 : 1** on the real pixels —
	# with six of the seven nodes LOCKED on the opening frame, that is the user's 「어떤 칸이 뭘 주는지
	# 알 수가 없다」 written as a number. Both colours are the CAPTURED ones, composited over the
	# project's own clear colour through `Look.scene_fade_colour(1.0)` — the same source `_paint_fade`
	# draws — so this measures the picture and not a constant, and an ink in the node's own tone fails
	# it exactly as alpha 0 does.
	# ⚠ **A plain Rec.709 ratio and NOT WCAG's `(L + 0.05)` form.** See `MAP_GLYPH_LOCKED_ALPHA`: on
	# this ink and this fill the offset form tops out at 2.7 : 1 with the glyph fully opaque, so 3 : 1
	# is a floor nothing can pass, and a floor nothing can pass is not a floor.
	var glyph_gap := _tightest_glyph_contrast(spy)
	t.ok(glyph_gap >= 1.8,
		"무늬 여섯이 전부 제 칸 바탕과 밝기가 %.2f배 이상 갈린다 (>= 1.8) — 1.0 이면 무늬가 바탕에 녹아 있다"
			% glyph_gap)
	# ⚠⚠ **This row used to compare ABSOLUTE point arrays and could never fail.** `_glyph_points` builds
	# every point off `node_centre_of(n)`, so node 1's array and node 2's differ by a constant 340 px
	# translation NO MATTER WHAT SHAPE IS DRAWN — the check was measuring the coordinate table. Proved:
	# the BEAK branch was replaced with a byte-for-byte copy of the COUNT branch, every fight node drew
	# three squares, and the round stayed green at 1816. **Recentred on its own node** is what turns it
	# back into a claim about the vocabulary.
	#
	# The FLOOR first: a glyph has to reach away from the centre at all. At `MAP_GLYPH_R_PX = 0` every
	# point collapses onto the node centre, the point COUNT rows above still hold, and six glyphs
	# vanish.
	# ⚠⚠ **The floor used to be a flat 6 px and that is why the glyph shipped unreadable.** 6 px is
	# "not collapsed to a point"; it is not "big enough to tell a triangle from three squares", and the
	# user's report was exactly the gap between the two. Both ends are measured against the radius the
	# node was ACTUALLY DRAWN at — read back off the capture, not off a constant — so the pair moves
	# with `MAP_NODE_LOCKED_SCALE` and cannot be satisfied by shrinking the nodes instead.
	var flat_glyphs := 0
	var spilled_glyphs := 0
	var tightest := 9.0
	for n in Rules.map_node_count():
		if Rules.map_reward_of(n) == Rules.Reward.NONE:
			continue
		var shape := _glyph_shape(spy, n)
		if shape.size() == 0:
			flat_glyphs += 1
			continue
		var reach := 0.0
		for p in shape:
			reach = maxf(reach, (p as Vector2).length())
		var drawn: float = float((spy.nodes[n] as Dictionary)["radius"])
		# ⚠⚠ **The two ends are measured against DIFFERENT radii, and that is not sloppiness.** The
		# glyph deliberately does NOT shrink with a locked node — reading what a node pays is how the
		# route gets chosen before you can walk it — so putting the FLOOR against the shrunken radius
		# flatters it. Measured: with `MAP_GLYPH_R_PX` put back to 13, the value the user could not
		# read, six of the seven nodes are locked at 30 px and 13 / 30 clears a 40% floor outright; the
		# floor bit on ONE node, at 35 against 40. The floor belongs against the size a node is drawn at
		# when it is NOT shrunken. The ceiling stays against the size it was ACTUALLY drawn at, because
		# that is the rim a stroke would spill over.
		var full_r := Look.map_node_radius_px(Rules.map_kind_of(n))
		tightest = minf(tightest, reach / full_r)
		if reach < full_r * 0.40:
			flat_glyphs += 1
		if reach + Look.MAP_GLYPH_WIDTH_PX * 0.5 > drawn:
			spilled_glyphs += 1
	t.eq(flat_glyphs, 0,
		"무늬 여섯이 전부 안 줄어든 칸 반지름의 40%% 이상 뻗어 있다 (가장 좁은 것이 %.0f%%) — 알아볼 수 있는 크기다"
			% (tightest * 100.0))
	t.eq(spilled_glyphs, 0, "그리고 획 바깥쪽까지 전부 칸 안에 들어간다 — 키운 무늬가 테두리를 안 넘는다")

	# The two nodes on floor 2, and the two on floor 3, which nothing compared at all.
	#
	# ⚠⚠ **`==` on two `PackedVector2Array`s is EXACT, and that made these five rows a trap for
	# whoever next retunes `MAP_GLYPH_R_PX`.** Every point is `centre + r * k` at two centres 340 px
	# apart, so the same shape comes back differing in the last float bit — measured: at r = 13 nodes
	# 1 and 4 gave 14.04001 against 14.04004 and the identity row below went red with nothing wrong.
	# The user has to be able to change that number without the round lying about it, so the
	# comparison is `_shapes_match`, tolerant to a hundredth of a pixel — far under this file's own
	# 2.0 px snap floor, so it cannot forgive a real difference.
	t.ok(not _shapes_match(_glyph_shape(spy, 1), _glyph_shape(spy, 2)),
		"2층 두 칸의 무늬가 서로 다르다 — 같으면 갈림길에 고를 것이 없다")
	t.ok(not _shapes_match(_glyph_shape(spy, 3), _glyph_shape(spy, 4)),
		"3층 두 칸의 무늬도 서로 다르다")
	# ⚠ Two reward kinds now, not three: the chest (and its cross glyph) is gone, and node 5 (floor 4,
	# the ex-chest) pays COUNT exactly like node 0 — so their glyphs MATCH now, which is the inverse of
	# what this row used to assert.
	t.ok(_shapes_match(_glyph_shape(spy, 0), _glyph_shape(spy, 5)),
		"짐승을 내는 두 칸(0번과 5번)의 무늬가 같다 — 같은 보상은 같은 무늬다")
	t.ok(not _shapes_match(_glyph_shape(spy, 2), _glyph_shape(spy, 5)),
		"부리 칸과 짐승 칸의 무늬는 다르다")
	# ⚠⚠ **The case that fails the CHECK rather than the tree.** Nodes 1 and 4 both pay cells and sit at
	# different centres. If the four rows above were comparing POSITIONS again, this one would go red —
	# it is the inversion of the instrument, not of the subject.
	t.ok(_shapes_match(_glyph_shape(spy, 1), _glyph_shape(spy, 4)),
		"같은 보상을 내는 두 칸은 자기 중심에 맞춰 놓으면 무늬가 완전히 같다 — 이 줄이 red 면 위 네 줄이 모양이 아니라 자리를 재고 있는 것이다")

	t.eq(spy.armies.size(), 1, "병사·힘 숫자를 한 번 그렸다")
	# ⚠⚠ **The expectation used to be read out of the very constant it was checking**, so
	# `MAP_ARMY_POS_PX = (-900, -900)` — the map screen's only text drawn entirely off screen, and
	# `hud_view._draw` returns on `battle == null` so the screen carries no numbers at all — stayed
	# green. The literal `SCREEN` is what pins it; the comparison below is what pins that the value
	# actually reaches the leaf. `net_title` already does it this way one file over.
	t.ok(SCREEN.has_point(Look.MAP_ARMY_POS_PX),
		"힘 숫자 자리 (%.0f, %.0f) 가 1280x720 안이다" % [Look.MAP_ARMY_POS_PX.x, Look.MAP_ARMY_POS_PX.y])
	t.ok(Look.MAP_ARMY_POS_PX.y >= float(Look.MAP_ARMY_FONT_SIZE_PX),
		"그리고 y 가 글자 크기 이상이다 — 기준선이 0이면 글자가 화면 위로 잘려 나간다")
	t.ok(Look.MAP_ARMY_POS_PX.x >= 0.0 and Look.MAP_ARMY_POS_PX.x <= 422.0,
		"x 도 0~422 다 — 422 는 가장 왼쪽 칸 기둥이 시작하는 자리다")
	t.eq(spy.armies[0]["at"], Look.MAP_ARMY_POS_PX, "그리고 그 자리가 실제로 화면까지 갔다")
	t.eq(int(spy.armies[0]["fsize"]), Look.MAP_ARMY_FONT_SIZE_PX, "글자 크기도 look.gd 값이다")
	t.ok(Look.MAP_ARMY_FONT_SIZE_PX > Look.HUD_FONT_SIZE_PX and Look.MAP_ARMY_FONT_SIZE_PX <= 30,
		"그 크기가 전투 HUD 글자(%d)보다 크고 30 이하다 (%d) — 이 화면의 유일한 수치라 가장 커야 한다"
			% [Look.HUD_FONT_SIZE_PX, Look.MAP_ARMY_FONT_SIZE_PX])
	# ⚠ **The army readout's COLOUR was captured and read by nothing either** — the map screen's only
	# two numbers could be drawn fully transparent with the round green, and `hud_view._draw` returns on
	# `battle == null`, so the screen would carry no data at all.
	t.ok((spy.armies[0]["col"] as Color).a >= 0.8,
		"그리고 그 글자가 알파 %.2f 로 화면까지 갔다 (>= 0.8) — 이 화면에서 숫자가 사라지면 아무 정보도 없다"
			% (spy.armies[0]["col"] as Color).a)
	t.ok(str(spy.armies[0]["text"]).contains("병사"), "「병사」가 쓰여 있다")
	t.ok(str(spy.armies[0]["text"]).contains("힘"), "「힘」도 쓰여 있다")
	# ⚠ The glyph budget, as a COUNT and not a taste: this screen is allowed two numbers and no
	# sentences. 「병사 16 · 힘 188」 is five space-separated tokens and a sixth would be a word nobody
	# agreed to add. The design's acceptance row asks for exactly this number to be written down.
	var tokens := str(spy.armies[0]["text"]).split(" ")
	t.eq(tokens.size(), 5, "그 문구가 「병사 N · 힘 X」 다섯 토막뿐이다 — 문장이 없다 (%s)"
		% str(spy.armies[0]["text"]))
	t.ok(not str(spy.armies[0]["text"]).contains("층"), "층 번호는 화면에 없다")

	# The layer contract: lines under nodes, nodes under the ring, the wash last of all.
	var last_edge := 0
	for e: Dictionary in spy.edges:
		last_edge = maxi(last_edge, int(e["seq"]))
	t.ok(last_edge < int(spy.nodes[0]["seq"]),
		"변을 전부 먼저 그린다 — 선이 뒤에 오면 자기가 끝나는 칸을 가로지른다")
	t.ok(spy.here_rings.size() == 0, "아직 아무 칸도 안 밟았으니 여기 고리는 없다 — 구석에 유령 고리가 안 생긴다")

	# 「갈 수 있는 칸과 못 가는 칸의 알파가 3배 넘게 다르다」 — mutation: PRESS_ALPHA_OFF -> 0.9.
	var open_fill := spy._node_fill(0)
	var shut_fill := spy._node_fill(6)
	t.ok(spy.is_node_pressable(0), "0번 칸은 지금 누를 수 있다 (자가 점검)")
	t.ok(not spy.is_node_pressable(6), "보스는 아직 못 누른다 (자가 점검)")
	t.ok(open_fill.a / shut_fill.a >= 3.0,
		"갈 수 있는 칸이 못 가는 칸보다 알파가 %.1f배 밝다" % (open_fill.a / shut_fill.a))
	t.eq(shut_fill.s, 0.0, "그리고 못 가는 칸은 채도가 0이다 — 색이 남으면 눈이 계속 종류로 분류한다")
	t.ok(open_fill.s > 0.0, "갈 수 있는 칸은 자기 색을 그대로 쓴다 (자가 점검)")
	# The border is the "this presses" mark and it is drawn for nothing else.
	t.eq(spy.borders.size(), 1 + (Look.MAP_BOSS_RINGS - 1),
		"테두리는 누를 수 있는 한 칸에만 붙는다 (보스 안쪽 겹고리 %d개는 별개다) — 화면에서 테두리가 있는 것이 곧 고를 것이다"
			% (Look.MAP_BOSS_RINGS - 1))

	# ⚠⚠ 「커서가 얹힌 칸이 켜진다」 — **`set_hover` was called by NO net at all**, so `_hover_node` was
	# never anything but -1 and the whole hover half of `_node_fill` and of the border lerp was
	# unreached: a bare `return` at the top of `set_hover` was green at 1816. This is the row the round
	# exists for — 「뭐 어떻게 동작시키는지 전혀 모르겠는데?」 is answered by "what is pressable looks
	# pressable", and on the map that is only the hover. `net_title` already closes exactly this hole
	# for the title screen, which is what makes the asymmetry a miss rather than a decision.
	var rest_border := float(spy.borders[0]["width"])
	var rest_lum := spy._node_fill(0).get_luminance()
	t.eq(rest_border, Look.PRESS_BORDER_WIDTH_PX, "커서를 얹기 전 테두리는 기본 굵기다 (자가 점검)")
	spy.set_hover(Look.map_node_pos_px(0))
	t.eq(spy._hover_node, 0, "커서가 0번 칸 위에 있으면 그 칸이 호버 칸이 된다")
	spy._fx_step(Look.PRESS_HOVER_SEC)
	spy.queue_redraw()
	await t.pump_frames(1)
	t.eq(float(spy.borders[0]["width"]), Look.PRESS_HOVER_BORDER_WIDTH_PX,
		"얹은 칸의 테두리가 %.0fpx 로 굵어져서 화면까지 갔다" % Look.PRESS_HOVER_BORDER_WIDTH_PX)
	t.ok(spy._node_fill(0).get_luminance() > rest_lum,
		"그리고 그 칸 색이 실제로 밝아졌다 (%.3f -> %.3f)"
			% [rest_lum, spy._node_fill(0).get_luminance()])
	# 「못 가는 칸 위에서는 안 켜진다」 — the picture asks the SIM, so an offer on screen is always an
	# offer the sim will take. Mutation: drop the `is_node_pressable` test out of `set_hover`.
	spy.set_hover(Look.map_node_pos_px(6))
	t.eq(spy._hover_node, -1, "보스 칸 위에서는 호버가 -1 이다 — 못 가는 칸은 커서에 반응하지 않는다")
	spy.set_hover(Vector2(40.0, 40.0))
	t.eq(spy._hover_node, -1, "빈 데 위에서도 -1 이다")
	spy._fx_step(Look.PRESS_HOVER_SEC)
	spy.queue_redraw()
	await t.pump_frames(1)
	t.eq(float(spy.borders[0]["width"]), Look.PRESS_BORDER_WIDTH_PX,
		"커서가 벗어나자 테두리가 기본 굵기로 돌아왔다 — 켜지기만 하면 두 칸이 같이 켜진 채로 남는다")
	t.ok(Look.PRESS_HOVER_BORDER_WIDTH_PX - Look.PRESS_BORDER_WIDTH_PX > 2.0,
		"두 굵기가 2px 넘게 벌어져 있다 (%.0f -> %.0f) — 밑이면 켜졌는지 알 수가 없다"
			% [Look.PRESS_BORDER_WIDTH_PX, Look.PRESS_HOVER_BORDER_WIDTH_PX])

	# 「맥동이 0이 아니고 4px을 안 넘는다」 — ⚠ **the floor is the half that proves the beat exists.**
	# Mutation: multiply the pulse by 0.0.
	var swing_max := -1.0
	var swing_min := 99.0
	for k in 40:
		spy._fx_step(Look.MAP_PULSE_SEC / 40.0)
		var s := spy._pulse_scale_of(0)
		swing_max = maxf(swing_max, s)
		swing_min = minf(swing_min, s)
	t.ok(swing_max > 0.0, "맥동이 한 주기 안에서 실제로 0을 벗어난다 (최대 %.2fpx)" % swing_max)
	t.ok(swing_max >= Look.MAP_PULSE_R_PX * 0.9,
		"그리고 MAP_PULSE_R_PX 의 90%%까지 실제로 간다 (%.2f / %.2f)" % [swing_max, Look.MAP_PULSE_R_PX])
	t.ok(swing_max <= Look.MAP_PULSE_R_PX, "그래도 %.0fpx 을 안 넘는다" % Look.MAP_PULSE_R_PX)
	t.ok(swing_min <= Look.MAP_PULSE_R_PX * 0.1, "그리고 바닥까지 내려온다 — 한쪽으로 부풀기만 하지 않는다")
	t.eq(spy._pulse_scale_of(6), 0.0, "못 가는 칸은 맥동이 정확히 0이다 — 뛰는 것은 갈 수 있는 칸뿐이다")
	t.ok(Look.MAP_PULSE_SEC >= 0.5 and Look.MAP_PULSE_SEC <= 1.4,
		"맥동 주기가 0.5~1.4초다 (%.1f) — 밑은 깜빡임이고 위는 움직임으로 안 읽힌다" % Look.MAP_PULSE_SEC)
	t.ok(Look.MAP_PULSE_R_PX >= 2.0 and Look.MAP_PULSE_R_PX <= 8.0,
		"맥동 폭이 2~8px 다 (%.0f)" % Look.MAP_PULSE_R_PX)

	# The reveal teaches the direction: floor by floor from the bottom. A check that reads only final
	# state cannot measure that, so this one reads it MID-RAMP.
	var fresh := MapSpy.new()
	t.root.add_child(fresh)
	fresh.process_mode = Node.PROCESS_MODE_DISABLED
	fresh.bind(run)
	var at_zero := 0
	for n in Rules.map_node_count():
		if fresh._reveal_alpha_of(n) != 0.0:
			at_zero += 1
	t.eq(at_zero, 0, "지도가 뜬 그 순간에는 어느 칸도 아직 안 보인다 — 등장이 박자다")
	fresh._fx_step(Look.MAP_REVEAL_STEP_SEC + Look.MAP_NODE_FADE_SEC * 0.5)
	var inverted := 0
	for f in range(Rules.map_floor_count() - 1):
		var lower := -1.0
		var upper := -1.0
		for n in Rules.map_node_count():
			if Rules.map_floor_of(n) == f:
				lower = maxf(lower, fresh._reveal_alpha_of(n))
			if Rules.map_floor_of(n) == f + 1:
				upper = maxf(upper, fresh._reveal_alpha_of(n))
		if lower < upper:
			inverted += 1
	t.eq(inverted, 0, "등장 중간에 아래 층이 언제나 위 층보다 진하다 — 이게 문장 대신 방향을 가르친다")
	t.ok(fresh._reveal_alpha_of(0) > fresh._reveal_alpha_of(6),
		"1층이 꼭대기보다 실제로 먼저 나온다 (%.2f > %.2f)"
			% [fresh._reveal_alpha_of(0), fresh._reveal_alpha_of(6)])
	fresh._fx_step(Look.MAP_REVEAL_STEP_SEC * 4.0 + Look.MAP_NODE_FADE_SEC)
	var unfinished := 0
	for n in Rules.map_node_count():
		if fresh._reveal_alpha_of(n) < 1.0:
			unfinished += 1
	t.eq(unfinished, 0, "%.2f초가 지나면 일곱 칸이 전부 다 나와 있다 — 영영 반투명으로 남지 않는다"
		% (Look.MAP_REVEAL_STEP_SEC * 4.0 + Look.MAP_NODE_FADE_SEC))
	t.ok(Look.MAP_NODE_FADE_SEC >= 0.084 and Look.MAP_NODE_FADE_SEC <= 0.40,
		"칸 하나가 나오는 시간이 다섯 프레임~0.40초다 (%.2f)" % Look.MAP_NODE_FADE_SEC)
	t.ok(Look.MAP_REVEAL_STEP_SEC >= 0.03 and Look.MAP_REVEAL_STEP_SEC <= 0.12,
		"층 사이 간격이 0.03~0.12초다 (%.2f) — 이건 박자가 아니라 박자 사이 간격이라 다섯 프레임 밑이어도 된다"
			% Look.MAP_REVEAL_STEP_SEC)
	t.root.remove_child(fresh)
	fresh.queue_free()

	# The scene wash: the map arrives OUT of the background rather than cutting to it.
	var washer := MapSpy.new()
	t.root.add_child(washer)
	washer.process_mode = Node.PROCESS_MODE_DISABLED
	washer.bind(run)
	washer.queue_redraw()
	await t.pump_frames(1)
	t.eq(washer.fades.size(), 1, "뜨는 순간 화면 전체에 배경색 막이 한 장 덮인다")
	t.eq(washer.fades[0]["rect"], Rect2(Vector2.ZERO, Look.viewport_size_px()),
		"그 막이 화면 전체다")
	t.ok((washer.fades[0]["col"] as Color).a > 0.5, "그리고 뜨는 순간에는 거의 불투명하다")
	washer._fx_step(Look.SCENE_FADE_SEC * 0.5)
	washer.queue_redraw()
	await t.pump_frames(1)
	t.ok(washer.fades.size() == 1 and (washer.fades[0]["col"] as Color).a < 0.6,
		"절반쯤 지나면 막이 옅어진다 — 계단이 아니라 걷힘이다")
	washer._fx_step(Look.SCENE_FADE_SEC)
	washer.queue_redraw()
	await t.pump_frames(1)
	t.eq(washer.fades.size(), 0, "%.2f초가 지나면 막이 완전히 사라진다 — 영영 회색 창이 남지 않는다"
		% Look.SCENE_FADE_SEC)
	t.ok(Look.SCENE_FADE_SEC >= 0.20 and Look.SCENE_FADE_SEC <= 0.60,
		"장면 전환이 0.20~0.60초다 (%.2f) — 밑은 그냥 컷이고 위는 기다림이다" % Look.SCENE_FADE_SEC)
	t.root.remove_child(washer)
	washer.queue_free()

	# 「고리가 0.45초 동안 선을 따라 실제로 이동한다」 — ⚠ cut straight to the island and the map's work
	# is invisible: the walk IS the progress readout. Mutation: freeze `_here_centre` at the source.
	t.ok(run.enter_node(0), "0번 칸을 밟는다 (자가 점검)")
	run.finish_island(true)
	# ⚠ `map_view._draw` gates on `run.state() == MAP`, so the whole picture below reads a blank
	# `spy` unless the win is walked all the way through the pick and the refit board first.
	t.eq(run.state(), Run.State.PICK, "이겼으니 카드 고르기부터 연다 (자가 점검)")
	_take_two_and_close_refit(run)
	t.eq(run.state(), Run.State.MAP, "카드를 고르고 정비를 닫아야 지도다 (자가 점검)")
	spy.bind(run)
	spy._fx_step(Look.SCENE_FADE_SEC + Look.MAP_NODE_FADE_SEC * 4.0)
	t.eq(spy._here_centre(), Look.map_node_pos_px(0), "누르기 전 고리는 서 있는 칸 위에 있다")
	spy.note_press(1)
	t.eq(spy._here_centre(), Look.map_node_pos_px(0), "누른 그 순간에도 아직 출발점이다")
	var walked_ring := [spy._here_centre()]
	for k in 6:
		spy._fx_step(Look.MAP_TRAVEL_SEC / 6.0)
		walked_ring.append(spy._here_centre())
	var distinct := {}
	for p in walked_ring:
		distinct[(p as Vector2).snapped(Vector2(1.0, 1.0))] = true
	t.ok(distinct.size() >= 3, "고리가 걷는 동안 서로 다른 자리 %d군데를 지난다 (>= 3)" % distinct.size())
	t.eq(walked_ring[0], Look.map_node_pos_px(0), "출발점이 0번 칸 중심이다")
	t.eq((walked_ring[walked_ring.size() - 1] as Vector2), Look.map_node_pos_px(1),
		"도착점이 1번 칸 중심이다")
	var mid_point: Vector2 = walked_ring[3]
	t.ok(mid_point != Look.map_node_pos_px(0) and mid_point != Look.map_node_pos_px(1),
		"중간 자리는 두 칸 중심 어느 쪽도 아니다 — 순간이동이 아니라 이동이다")
	t.ok(absf(Look.map_node_pos_px(0).distance_to(mid_point)
			+ mid_point.distance_to(Look.map_node_pos_px(1))
			- Look.map_node_pos_px(0).distance_to(Look.map_node_pos_px(1))) < 0.5,
		"그리고 그 중간 자리가 두 칸을 잇는 선 위다 — 고리가 선을 따라 간다")
	t.ok(Look.MAP_TRAVEL_SEC >= 0.25 and Look.MAP_TRAVEL_SEC <= 0.70,
		"이동이 0.25~0.70초다 (%.2f) — 밑은 순간이동이고 위는 기다림이다" % Look.MAP_TRAVEL_SEC)

	# The travelled line thickens, and the cleared node fills. Both are read off `map.path`, so the
	# picture cannot claim progress the sim did not make.
	t.ok(run.enter_node(1), "1번 칸을 밟는다 (자가 점검)")
	run.finish_island(true)
	_take_two_and_close_refit(run)
	spy.bind(run)
	# The reveal is run out FIRST and the clear is armed after it, because both ride the same
	# `_fx_step` and folding them would leave `_cleared_age` past the whole fill before the first read.
	spy._fx_step(Look.SCENE_FADE_SEC + Look.MAP_NODE_FADE_SEC * 4.0)
	spy.note_cleared(run.map.at())
	t.eq(spy._cleared_node, run.map.at(), "방금 이긴 칸이 채워지기 시작했다 (자가 점검)")
	# ⚠⚠ 「이긴 칸이 채워진다」 — **`MAP_CLEAR_FILL_SEC` was only ever a duration to step
	# PAST**, and nothing anywhere read `_cleared_node`, `_cleared_age` or the lerp branch of
	# `_node_fill`. After the fill lands the colour is identical whether the beat played or not, so a
	# check reading only the final state cannot see `note_cleared` being made a no-op — measured green
	# at 1816 with `_cleared_node = -1` written into it. This one reads the PROCESS: three points, and
	# the first is the floor that proves the beat starts dim rather than snapping.
	var fill_start := spy._node_fill(1)
	spy._fx_step(Look.MAP_CLEAR_FILL_SEC * 0.5)
	var fill_half := spy._node_fill(1)
	spy._fx_step(Look.MAP_CLEAR_FILL_SEC)
	var fill_done := spy._node_fill(1)
	t.ok(is_equal_approx(fill_start.a, Look.PRESS_ALPHA_OFF),
		"채우기가 시작될 때 그 칸은 아직 흐린 알파 %.2f 다 — 여기서 이미 진하면 채워진 적이 없는 것이다"
			% fill_start.a)
	t.eq(fill_start.s, 0.0, "그리고 채도도 아직 0이다")
	t.ok(fill_half.a > fill_start.a and fill_half.a < fill_done.a,
		"절반 시간에는 절반쯤 차 있다 (%.2f < %.2f < %.2f) — 지켜보는 동안 채워진다"
			% [fill_start.a, fill_half.a, fill_done.a])
	t.ok(fill_half.s > 0.0 and fill_half.s < fill_done.s, "색도 중간에 절반쯤 돌아와 있다")
	t.ok(is_equal_approx(fill_done.a, Look.PRESS_ALPHA_ON),
		"다 차면 알파가 %.2f 로 도착한다 — 영영 반투명으로 남지 않는다" % Look.PRESS_ALPHA_ON)
	t.ok(Look.MAP_CLEAR_FILL_SEC >= 0.084 and Look.MAP_CLEAR_FILL_SEC <= 0.50,
		"채우기가 다섯 프레임~0.50초다 (%.2f) — 밑은 그냥 펑이고 위는 기다림이다" % Look.MAP_CLEAR_FILL_SEC)
	spy.queue_redraw()
	await t.pump_frames(1)

	# ⚠⚠ **ALL FOUR STATES ON SCREEN AT ONCE, READ OFF ONE STILL FRAME.** `path` is [0, 1]: the army
	# stands on node 1, the fork is 3 and 4, node 0 is walked, and 2 / 5 / 6 are out of reach. This is
	# the block the round exists for. 「현재 위치 제대로 표현해야 되고」 and 「갈 수 있는 칸이 안 보인다」
	# are both claims about a STILL frame, so nothing below touches the hover or waits for the pulse —
	# the previous build's whole answer was a hover and a pulse, and it was green.
	# ⚠⚠ **The cursor is nowhere, and this is the row that says so.** The previous build's ENTIRE answer
	# to 「어디로 갈 수 있나」 was a hover plus a pulse, and it was green — so a block claiming the four
	# states read off a STILL frame has to prove first that nothing is being touched. Without these two
	# rows, moving every claim below back into the hover would pass again, because the block sits after
	# a hover test and inherits whatever that test left behind.
	t.eq(spy._hover_node, -1, "이 블록 내내 커서가 어느 칸에도 안 얹혀 있다 (자가 점검)")
	t.eq(spy._press_node, -1, "눌린 칸도 없다 (자가 점검) — 아래는 전부 가만히 있는 한 장에 대한 주장이다")
	t.eq(spy._look_of(1), MapView.NodeLook.HERE, "서 있는 칸이 HERE 다 (자가 점검)")
	t.eq(spy._look_of(3), MapView.NodeLook.OPEN, "갈림길 한쪽이 OPEN 이다 (자가 점검)")
	t.eq(spy._look_of(0), MapView.NodeLook.PAST, "지나온 칸이 PAST 다 (자가 점검)")
	t.eq(spy._look_of(2), MapView.NodeLook.LOCKED, "못 가는 전투 칸이 LOCKED 다 (자가 점검)")
	# Four FIGHT nodes, so the four radii are comparable without the boss's own size getting in.
	var r_here := float((spy.nodes[1] as Dictionary)["radius"])
	var r_open := float((spy.nodes[3] as Dictionary)["radius"])
	var r_past := float((spy.nodes[0] as Dictionary)["radius"])
	var r_shut := float((spy.nodes[2] as Dictionary)["radius"])
	t.ok(r_open >= r_here, "갈 수 있는 칸이 서 있는 칸만큼 크다 (%.1f >= %.1f) — 맥동만 더 붙는다"
		% [r_open, r_here])
	# ⚠ **The ceiling that row never had.** `>=` gets MORE true the bigger the open node grows, so the
	# only thing it forbids is shrinking — and a node on offer swollen past the ring that marks where
	# the run is standing swallows the answer to 「지금 내가 어디 있나」. The pulse is the whole of the
	# extra it is allowed.
	t.ok(r_open <= r_here + Look.MAP_PULSE_R_PX,
		"그리고 맥동 폭(%.0fpx) 넘게 커지지는 않는다 (%.1f <= %.1f) — 위면 갈 수 있는 칸이 서 있는 칸을 삼킨다"
			% [Look.MAP_PULSE_R_PX, r_open, r_here + Look.MAP_PULSE_R_PX])
	# ⚠⚠ **OPEN against LOCKED, read off the CAPTURED arguments.** This is the exact pair the user could
	# not tell apart — at rest 「갈 수 있는 칸」 and 「못 가는 칸」 were the same grey — and it was the
	# only pair with no direct row of its own: the size ladder above reaches it by two hops through
	# HERE and PAST, and the alpha ladder never compares the two at all. `_node_fill(0)` / `_node_fill(6)`
	# further up ARE compared, and that is a pure function: it proves two colours differ, never that
	# either one was handed to a leaf.
	# ⚠ **The pulse is subtracted first, and leaving it in made this row a coin flip.** Measured: with
	# the locked scale mutated up to the walked one the gap is 5.6 px at the bottom of the pulse and
	# 9.6 px at the top, so a floor of 8 passed or failed on which phase `_age` happened to be at. A
	# check whose value swings by `MAP_PULSE_R_PX` between frames is not measuring the size channel.
	# `_pulse_scale_of` is read at the same `_age` the capture was taken at — the spy is
	# `PROCESS_MODE_DISABLED` and nothing has stepped its clock since — so this is the RESTING radius
	# exactly, and a pulse mutated to zero takes the correction to zero with it.
	var r_open_rest := r_open - spy._pulse_scale_of(3)
	t.ok(r_open_rest - r_shut >= 8.0,
		"맥동을 뺀 갈 수 있는 칸이 못 가는 칸보다 %.1fpx 크게 그려져서 화면까지 갔다 (>= 8px)"
			% (r_open_rest - r_shut))
	t.ok(r_shut >= r_open_rest * 0.55,
		"그래도 못 가는 칸이 갈 수 있는 칸의 55%% 밑으로는 안 줄어든다 (%.0f%%) — 밑이면 무늬가 칸 밖으로 나간다"
			% (r_shut / r_open_rest * 100.0))
	t.ok(r_here - r_past >= 2.0,
		"서 있는 칸이 지나온 칸보다 %.1fpx 크다 (>= 2px, 스냅 바닥)" % (r_here - r_past))
	t.ok(r_past - r_shut >= 2.0,
		"지나온 칸이 못 가는 칸보다 %.1fpx 크다 (>= 2px) — 크기 하나만으로도 셋이 갈린다"
			% (r_past - r_shut))
	# The brightness channel, off the SAME frame. Neither channel may carry the read alone: delete the
	# size ladder and these three rows still hold, delete these and the three above still hold.
	var c_here := (spy.nodes[1] as Dictionary)["col"] as Color
	var c_open := (spy.nodes[3] as Dictionary)["col"] as Color
	var c_past := (spy.nodes[0] as Dictionary)["col"] as Color
	var c_shut := (spy.nodes[2] as Dictionary)["col"] as Color
	t.ok(c_here.a - c_past.a >= 0.1 and c_past.a - c_shut.a >= 0.1,
		"진하기도 서 있는 칸 %.2f > 지나온 칸 %.2f > 못 가는 칸 %.2f 로 셋이 갈린다"
			% [c_here.a, c_past.a, c_shut.a])
	t.ok(c_past.s > 0.0, "지나온 칸은 색이 남아 있다 — 어떤 칸을 지나왔는지 읽을 수 있어야 한다")
	t.eq(c_shut.s, 0.0, "못 가는 칸만 색이 없다")
	# The same pair again on the brightness channel, and BOTH ends. The floor says the two are told
	# apart; the ceiling says the unreachable one is still THERE — a locked node faded to nothing is a
	# map whose shape cannot be read ahead, and the route stops being a decision. Same claim
	# `MAP_LINE_DIM_ALPHA` carries for the lines, which had it and the nodes did not.
	t.ok(c_open.a - c_shut.a >= 0.5,
		"갈 수 있는 칸과 못 가는 칸의 진하기가 %.2f 벌어진 채로 화면까지 갔다 (>= 0.5)"
			% (c_open.a - c_shut.a))
	t.ok(c_shut.a >= 0.15,
		"그래도 못 가는 칸이 알파 %.2f 로 보이긴 한다 — 지도 전체가 첫 프레임부터 보여야 경로가 결정이 된다"
			% c_shut.a)
	t.ok(c_open.s > 0.0 and is_equal_approx(c_shut.s, 0.0),
		"그리고 갈 수 있는 칸만 색이 있다 (채도 %.2f / %.2f)" % [c_open.s, c_shut.s])
	# The third channel: what is drawn ON the node. The border marks exactly the two nodes on offer,
	# and the you-are-here ring marks exactly one. Mutation: draw the border for every node.
	t.eq(spy.borders.size(), 2 + (Look.MAP_BOSS_RINGS - 1),
		"테두리가 갈림길 두 칸에만 붙었다 (보스 안쪽 겹고리 %d개는 별개다)" % (Look.MAP_BOSS_RINGS - 1))
	# ⚠⚠ **A COUNT cannot say WHERE.** Border the node the run is standing on and drop one of the two on
	# offer and the row above is still 2 — HERE and OPEN are the same size and the same alpha, so the
	# border is the ONLY thing separating them and a count cannot see it move. These read each border's
	# centre back out of the points the leaf was handed.
	var bordered := {}
	var border_of := {}
	for b: Dictionary in spy.borders:
		var mark_at := _ring_centre(b["points"])
		for n in Rules.map_node_count():
			if mark_at.distance_to(Look.map_node_pos_px(n)) < 1.0:
				bordered[n] = int(bordered.get(n, 0)) + 1
				if not border_of.has(n):
					border_of[n] = []
				(border_of[n] as Array).append(b)
	t.eq(int(bordered.get(3, 0)), 1, "테두리 하나가 갈림길 3번 칸 위다")
	t.eq(int(bordered.get(4, 0)), 1, "나머지 하나가 4번 칸 위다 — 고를 수 있는 두 칸이 정확히 그 둘이다")
	t.eq(int(bordered.get(1, 0)), 0, "서 있는 1번 칸에는 테두리가 없다 — 그 칸은 고리가 말한다")
	t.eq(int(bordered.get(0, 0)), 0, "지나온 0번 칸에도 없다")
	t.eq(int(bordered.get(2, 0)), 0, "못 가는 2번 칸에도 없다")
	t.eq(int(bordered.get(6, 0)), Look.MAP_BOSS_RINGS - 1,
		"보스 칸에 있는 고리 %d개는 안쪽 겹고리이고 테두리가 아니다" % (Look.MAP_BOSS_RINGS - 1))
	t.eq(bordered.size(), 3, "테두리가 얹힌 칸은 그 셋뿐이다 — 어느 것도 칸 밖에 떠 있지 않다")
	# ⚠ **The instrument, inverted.** `_ring_centre` reads a bounding box, and a bounding box is the
	# node's centre only because every ring on this screen is symmetric about it. Two rings that really
	# are at different places must come back at different places, or every row above is comparing one
	# number with itself. The two boss rings share a centre and node 3's border does not.
	t.ok(_ring_centre(spy.borders[0]["points"]).distance_to(
			_ring_centre(spy.borders[spy.borders.size() - 1]["points"])) > 1.0,
		"서로 다른 칸에 얹힌 두 고리는 되읽은 중심도 다르다 — 이 줄이 red 면 위 여섯 줄이 한 수를 자기와 비교하고 있는 것이다")
	# ⚠⚠ **The border's COLOUR was captured and read by NO row**, so `edge.a = reveal * 0.0` drew both
	# fork borders fully transparent with 1911 checks green — and that border is this round's headline
	# answer to 「쉬는 화면에서 갈 수 있는 칸이 구분이 안 된다」. The hover rows above closed the WIDTH
	# channel and left the visibility channel wide open, which is the same half-closed shape this file
	# already records for the edge alphas.
	# ⚠ **The SIZE is read back in the same loop**, because `_ring_centre` structurally cannot see a
	# ring collapse: a bounding box of zero extent still returns the right middle. `_ring_points` with
	# its radius zeroed left every border a single point and all six `bordered` rows above stayed green.
	var back := Look.scene_fade_colour(1.0)
	var border_bad := 0
	var border_gap := 99.0
	var border_alpha := 9.0
	for n in [3, 4]:
		var caps: Array = border_of.get(n, [])
		if caps.size() != 1:
			border_bad += 1
			continue
		var cap: Dictionary = caps[0]
		var col := cap["col"] as Color
		border_alpha = minf(border_alpha, col.a)
		if absf(_ring_extent(cap["points"]) - float((spy.nodes[n] as Dictionary)["radius"])) > 0.01:
			border_bad += 1
		var under := _over((spy.nodes[n] as Dictionary)["col"] as Color, back)
		border_gap = minf(border_gap, _contrast(_over(col, under), under))
	t.eq(border_bad, 0,
		"갈림길 두 칸의 테두리가 각각 하나씩이고, 넘어간 점들이 그 칸 반지름만큼 실제로 벌어져 있다")
	t.ok(border_alpha >= 0.8,
		"그 테두리가 알파 %.2f 로 화면까지 갔다 (>= 0.8) — 0이면 이번 라운드의 대표 수정이 통째로 사라진다"
			% border_alpha)
	t.ok(border_gap >= 1.25,
		"그리고 자기가 얹힌 칸 색과 밝기가 %.2f배 갈린다 (>= 1.25) — 칸과 같은 색 테두리는 알파 0 과 같다"
			% border_gap)
	# ⚠ **`MAP_BOSS_RING_STEP_PX` driven, not merely bounded.** The literal pair far above is one half;
	# this reads the radii the LEAF was actually handed — each nested ring strictly inside the one
	# outside it, and the innermost still positive. At a step of 60 the two land at -4 and -64 against a
	# 42px drawn boss, and `_ring_points` turns a negative radius into a 64px ring painted in the
	# BACKDROP tone outside the disc it is meant to be cut out of.
	var boss_caps: Array = border_of.get(6, [])
	t.eq(boss_caps.size(), Look.MAP_BOSS_RINGS - 1,
		"보스 안쪽 겹고리 %d개가 잡혔다 (자가 점검)" % (Look.MAP_BOSS_RINGS - 1))
	var boss_r := float((spy.nodes[6] as Dictionary)["radius"])
	var boss_bad := 0
	var outer := boss_r
	for cap: Dictionary in boss_caps:
		var ext := _ring_extent(cap["points"])
		if ext <= 0.0 or ext >= outer:
			boss_bad += 1
		outer = ext
	t.eq(boss_bad, 0,
		"겹고리 반지름이 보스(%.0fpx)에서 안쪽으로 계속 줄고 0 밑으로 안 내려간다 — 음수면 보스 밖에 고리가 생긴다"
			% boss_r)
	# The same contrast claim as the glyphs, on the frame that actually holds a PAST node: the reward on
	# a walked square is the only one of the four states the earlier frame could not show.
	var glyph_gap_four := _tightest_glyph_contrast(spy)
	t.ok(glyph_gap_four >= 1.8,
		"네 상태가 다 있는 이 한 장에서도 무늬 여섯이 제 칸 바탕과 %.2f배 이상 갈린다 (>= 1.8) — 지나온 칸의 무늬는 여기서만 나온다"
			% glyph_gap_four)
	# And the you-are-here mark answers 「지금 내가 어디 있나」 by sitting on ONE node — the one the run
	# is standing on, which is the only one of the four states with no border.
	var ring_at := spy.here_rings[0]["centre"] as Vector2
	t.ok(ring_at.distance_to(Look.map_node_pos_px(1)) < 1.0, "여기 고리가 서 있는 1번 칸 위다")
	t.ok(ring_at.distance_to(Look.map_node_pos_px(3)) > Look.MAP_HERE_RING_R_PX
			and ring_at.distance_to(Look.map_node_pos_px(4)) > Look.MAP_HERE_RING_R_PX,
		"그리고 갈림길 두 칸 어느 쪽에서도 고리 반지름보다 멀다 — 가리키는 칸은 하나뿐이다")
	t.ok(float(spy.here_rings[0]["radius"]) > r_here,
		"고리가 그 칸(%.1fpx)보다 바깥(%.1fpx)이다 — 안쪽이면 칸 밑에 숨는다"
			% [r_here, float(spy.here_rings[0]["radius"])])
	# ⚠⚠ **THE RING'S COLOUR AND WIDTH WERE CAPTURED AND READ BY NOTHING**, and this ring is the whole
	# of the user's 「현재 위치 제대로 표현해야 되고」 in one object. `mark.a * 0.0` drew it fully
	# invisible with 1911 checks green — the centre and the radius still arrived, only the tone was
	# dead. HERE and OPEN share a hue AND a radius, so this ring is the only channel separating them:
	# lose it and 「지금 내가 어디 있나」 has no answer on the screen at all.
	# ⚠ `MAP_HERE_RING_WIDTH_PX >= 4.0` far above is asserted of the CONSTANT and never of the value
	# that reached the leaf, which is the distance a hook spy exists to close.
	var ring_col := spy.here_rings[0]["col"] as Color
	t.ok(ring_col.a >= 0.8,
		"여기 고리가 알파 %.2f 로 화면까지 갔다 (>= 0.8) — 0이면 서 있는 칸과 갈 수 있는 칸이 같은 그림이 된다"
			% ring_col.a)
	t.eq(float(spy.here_rings[0]["width"]), Look.MAP_HERE_RING_WIDTH_PX,
		"굵기 %.0fpx 도 상수 그대로 화면까지 갔다" % Look.MAP_HERE_RING_WIDTH_PX)
	var here_under := _over(c_here, back)
	t.ok(_contrast(_over(ring_col, here_under), here_under) >= 1.25,
		"그리고 고리가 감싼 칸 색과 밝기가 %.2f배 갈린다 (>= 1.25) — 칸과 같은 색 고리는 안 보이는 것과 같다"
			% _contrast(_over(ring_col, here_under), here_under))

	var past := 0
	var dim := 0
	for e in Rules.map_edge_count():
		var style := spy._edge_style(e)
		if is_equal_approx(style.x, Look.MAP_LINE_PAST_WIDTH_PX):
			past += 1
		if is_equal_approx(style.x, Look.MAP_LINE_DIM_WIDTH_PX):
			dim += 1
	t.eq(past, 1, "걸어온 변 하나만 굵어졌다")
	t.ok(dim >= 4, "그리고 안 걸은 변은 여전히 얇다 (%d개)" % dim)
	# ⚠⚠ **Only the WIDTH half of `_edge_style` was ever read back.** The alpha half reaches the leaf as
	# `col.a` and nothing inspected the captured colour at all, so `MAP_LINE_PAST_ALPHA = 0` — the
	# travelled route invisible — was green. The reveal is fully run out above, so the drawn alpha is
	# `_edge_style(e).y` exactly and this measures the tone that arrives, not the constant.
	var past_seen := -1.0
	var open_seen := -1.0
	var dim_seen := -1.0
	for cap: Dictionary in spy.edges:
		var e := -1
		for k in Rules.map_edge_count():
			if (cap["from"] as Vector2) == Look.map_node_pos_px(Rules.map_edge_from(k)) \
					and (cap["to"] as Vector2) == Look.map_node_pos_px(Rules.map_edge_to(k)):
				e = k
		if e < 0:
			continue
		var alpha := (cap["col"] as Color).a
		if is_equal_approx(float(cap["width"]), Look.MAP_LINE_PAST_WIDTH_PX):
			past_seen = alpha
		elif is_equal_approx(float(cap["width"]), Look.MAP_LINE_OPEN_WIDTH_PX):
			open_seen = alpha
		else:
			dim_seen = alpha
	t.ok(past_seen >= 0.8, "화면에 간 지나온 선의 알파가 %.2f 다 (>= 0.8)" % past_seen)
	t.ok(open_seen >= 0.6, "갈 수 있는 선의 알파도 %.2f 다 (>= 0.6)" % open_seen)
	t.ok(dim_seen >= 0.05 and dim_seen <= 0.45,
		"안 걸은 선은 %.2f 로 보이긴 하되 흐리다 (0.05~0.45)" % dim_seen)
	t.ok(past_seen - dim_seen > 0.3,
		"그리고 두 알파가 0.3 넘게 벌어진 채로 화면까지 갔다 (%.2f) — 굵기만이 아니라 진하기도 다르다"
			% (past_seen - dim_seen))
	t.eq(spy.here_rings.size(), 1, "이제 여기 고리가 화면에 하나 있다")
	t.eq(spy.here_rings[0]["centre"], Look.map_node_pos_px(1), "그 고리가 서 있는 칸 위다")
	t.eq(float(spy.here_rings[0]["radius"]), Look.MAP_HERE_RING_R_PX, "고리 반지름이 look.gd 값이다")

	# ⚠ 「COUNT 보상을 타면 힘 숫자가 0.60초에 걸쳐 올라간다」 — winning a `Reward.COUNT` node is the
	# node in this round that raises the pool without the player choosing anything, so without the climb
	# a win that grew the roster and one that did not look identical. Mutation: make `bind` reset
	# `_force_to` unconditionally, and the rise snaps.
	t.ok(run.enter_node(3), "3번 부리 칸을 밟는다 (자가 점검)")
	run.finish_island(true)
	run.apply_beak(0)
	_take_two_and_close_refit(run)
	spy.bind(run)
	# Two steps: the first notices the pool moved, the second runs the chase all the way out, so the
	# number is SETTLED before node 5 is won. Without that the row below would be measuring a climb
	# that was already in flight.
	spy._fx_step(0.016)
	spy._fx_step(Look.MAP_HEAL_SEC * 2.0)
	var low := await _force_shown(t, spy)
	t.ok(is_equal_approx(low, _pool(run.army)),
		"4층 칸을 밟기 전 힘 숫자가 실제 총합 %.0f 에 도착해 있다 (자가 점검)" % _pool(run.army))
	t.ok(run.enter_node(5), "4층 칸을 밟는다 (자가 점검)")
	run.finish_island(true)
	_take_two_and_close_refit(run)
	# ⚠ The SAME run object, re-bound exactly as the shell does one line after `finish_island` — which is
	# what must NOT reset the chase. Reset it and the rise snaps, and a win that grew the roster looks
	# exactly like one that did not.
	spy.bind(run)
	spy._fx_step(0.016)
	# ⚠ `is_processing()` still reads TRUE under `PROCESS_MODE_DISABLED` — the flag is set and the mode
	# is what gates it — so the self-check has to measure the EFFECT. Ask the clock, not the flag.
	var frozen_at := spy._age
	await t.pump_frames(2)
	t.eq(spy._age, frozen_at,
		"지도 뷰의 자체 시계가 프레임을 돌려도 안 흐른다 (자가 점검) — 흐르면 아래 시간 검사가 전부 헐거워진다")
	var climbing := await _force_shown(t, spy)
	spy._fx_step(Look.MAP_HEAL_SEC * 0.5)
	var half := await _force_shown(t, spy)
	spy._fx_step(Look.MAP_HEAL_SEC)
	var landed := await _force_shown(t, spy)
	t.ok(landed > low, "회복 뒤 힘 숫자가 %.0f 에서 %.0f 로 올랐다" % [low, landed])
	t.ok(is_equal_approx(climbing, low),
		"밟은 그 프레임에는 아직 %.0f 그대로다 — 다시 물렸다고 숫자가 튀지 않는다" % climbing)
	t.ok(climbing < landed, "그리고 도착값보다 낮다 (%.0f < %.0f) — 순간이동이 아니다"
		% [climbing, landed])
	t.ok(half > climbing and half < landed,
		"절반 시간에는 절반쯤 와 있다 (%.0f < %.0f < %.0f) — 지켜보는 동안 오른다" % [climbing, half, landed])
	t.ok(is_equal_approx(landed, _pool(run.army)),
		"다 오른 값이 실제 HP 총합(%.1f)과 같다 — 화면과 sim 이 같은 수를 말한다" % _pool(run.army))
	t.ok(Look.MAP_HEAL_SEC >= 0.30 and Look.MAP_HEAL_SEC <= 1.00,
		"힘 숫자 오르는 시간이 0.30~1.00초다 (%.2f) — 밑은 지켜볼 수가 없다" % Look.MAP_HEAL_SEC)

	# `node_at`, the hit test the shell actually asks. Every centre finds its own node; the daylight
	# between two hit circles finds nothing.
	var hit_bad := 0
	for n in Rules.map_node_count():
		if spy.node_at(Look.map_node_pos_px(n)) != n:
			hit_bad += 1
		var edge_of := Look.map_node_pos_px(n) \
			+ Vector2(Look.map_node_hit_radius_px(Rules.map_kind_of(n)) - 1.0, 0.0)
		if spy.node_at(edge_of) != n:
			hit_bad += 1
	t.eq(hit_bad, 0, "칸 일곱이 각자 중심에서도 판정 가장자리에서도 자기 번호를 낸다")
	t.eq(spy.node_at(Vector2(40.0, 40.0)), -1, "빈 데를 찍으면 -1 이다")
	t.eq(spy.node_at((Look.map_node_pos_px(1) + Look.map_node_pos_px(3)) * 0.5), -1,
		"가장 가까운 두 칸 사이 한가운데도 -1 이다 — 판정이 안 붙어 있다")

	t.root.remove_child(spy)
	spy.queue_free()


## The glyph the LEAF was handed for node `n`, moved so the node's own centre is the origin.
##
## ⚠⚠ **Recentring is the whole point.** Two glyphs at two different centres can never have equal
## absolute point arrays whatever shape either one is, so a comparison of the raw captures measures the
## coordinate table and nothing else. Subtracting each node's own centre is what leaves only the shape.
##
## The glyph is found by proximity rather than by index: `spy.glyphs` is in draw order, which happens
## to match node order today and would stop doing so the moment a node stops paying a reward. Reading
## it by distance also asserts, quietly, that the glyph was drawn AT its node.
## Two recentred glyphs, same shape to within a hundredth of a pixel.
##
## ⚠ **The tolerance is a hundredth and not a tenth on purpose.** It has to be far below the 2.0 px
## snap floor this repo works to, or the check starts forgiving differences that would reach the
## screen — and the four rows above it, which claim two glyphs are DIFFERENT, are exactly the ones a
## loose tolerance would silently pass.
##
## An empty array never matches a non-empty one, so a glyph that vanished cannot read as "the same".
func _shapes_match(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() != b.size() or a.size() == 0:
		return false
	for i in a.size():
		if a[i].distance_to(b[i]) > 0.01:
			return false
	return true


## The centre of a captured ring, read back out of the points the LEAF was handed.
##
## Every closed shape on this screen comes out of `map_view._ring_points`, which is symmetric about
## its centre at every segment count it is called with — 32 for a circle, 4 for the chest's diamond —
## so the middle of the bounding box IS the centre. Reading it back off the argument is what turns
## 「테두리가 두 개 있다」 into 「테두리가 이 두 칸 위에 있다」: a count cannot see a border move from
## one node to another, and HERE and OPEN are separated by nothing else.
func _ring_centre(points: PackedVector2Array) -> Vector2:
	var lo := points[0]
	var hi := points[0]
	for p in points:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	return (lo + hi) * 0.5


## The half-extent of a captured ring's bounding box — the radius the LEAF was actually handed
## geometry for, as opposed to the radius it was handed as a number.
##
## ⚠⚠ **`_ring_centre` beside it structurally cannot see a ring collapse.** A bounding box of zero
## extent still returns the correct middle, so `_ring_points(centre, radius * 0.0, ...)` turned the
## chest's diamond and every node border into a single point with 1911 checks green. `draw_circle`
## survived that mutation because its radius argument is asserted directly; the polygon and polyline
## branches take GEOMETRY, and nothing was reading it back.
##
## Every closed shape on this screen comes out of `map_view._ring_points` and is symmetric about its
## centre, and every segment count it is called with is a multiple of 4 — pinned by the
## `MAP_RING_SEGMENTS % 4` row — so a vertex lands on each axis and the half-extent IS the radius,
## exactly rather than approximately.
func _ring_extent(points: PackedVector2Array) -> float:
	var lo := points[0]
	var hi := points[0]
	for p in points:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	return maxf(hi.x - lo.x, hi.y - lo.y) * 0.5


## `col` composited over `under`, opaque. Alpha is what a leaf is handed and alpha is what a mutation
## zeroes, so every contrast row in this file reads the CAPTURED colour through this rather than
## asserting a constant — a tone that never reached the screen cannot be flattered by one.
func _over(col: Color, under: Color) -> Color:
	var out := under.lerp(col, clampf(col.a, 0.0, 1.0))
	out.a = 1.0
	return out


## The plain Rec.709 luminance ratio between two OPAQUE colours, brighter over darker so the caller
## does not have to know which way round the pair is.
##
## ⚠ **Deliberately not WCAG's `(L + 0.05)` form**, and that is arithmetic rather than a lowered bar:
## the glyph ink is `COL_PANEL_BG` (luminance 0.088) and a LOCKED node fill over the clear colour is
## 0.328, so the offset form tops out at 2.7 : 1 with the glyph fully opaque and WCAG's 3 : 1 non-text
## floor is unreachable on this pair without changing the ink or the fill. A floor nothing can pass is
## not a floor. See `MAP_GLYPH_LOCKED_ALPHA` in `look.gd` for the full working.
func _contrast(a: Color, b: Color) -> float:
	var x := a.get_luminance()
	var y := b.get_luminance()
	return maxf(x, y) / maxf(minf(x, y), 0.0001)


## The tightest glyph-against-its-own-node contrast in the frame the spy is holding, or -1 if a glyph
## was captured that sits on no node at all.
##
## Both colours are the CAPTURED ones, composited down onto the project's own clear colour through
## `Look.scene_fade_colour(1.0)` — the same source `_paint_fade` draws, so the backdrop is never
## written down twice. That is what makes this a claim about the picture: an ink drawn in the node's
## own tone fails it exactly as an ink at alpha 0 does, and neither is reachable by reading constants.
func _tightest_glyph_contrast(spy: MapSpy) -> float:
	var worst := 99.0
	var back := Look.scene_fade_colour(1.0)
	for g: Dictionary in spy.glyphs:
		var pts: PackedVector2Array = g["points"]
		if pts.size() == 0:
			return -1.0
		var owner := -1
		for n in Rules.map_node_count():
			if pts[0].distance_to(spy.node_centre_of(n)) <= Look.MAP_NODE_R_PX:
				owner = n
		if owner < 0:
			return -1.0
		var fill := _over((spy.nodes[owner] as Dictionary)["col"] as Color, back)
		worst = minf(worst, _contrast(_over(g["col"] as Color, fill), fill))
	return worst


func _glyph_shape(spy: MapSpy, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var centre := spy.node_centre_of(n)
	for g: Dictionary in spy.glyphs:
		var pts: PackedVector2Array = g["points"]
		if pts.size() == 0 or pts[0].distance_to(centre) > Look.MAP_NODE_R_PX:
			continue
		for p in pts:
			out.append(p - centre)
		return out
	return out


## The 힘 number as the picture actually carries it, parsed back out of `_paint_army`'s text. Reading
## `_force_from`/`_force_to` instead would measure the fields and not the string that reaches the
## screen — the same distance a hook spy exists to close.
## ⚠ `await`, and the frame is a REAL one: calling `_draw()` by hand barks *"drawing outside
## NOTIFICATION_DRAW"*. The spy is `PROCESS_MODE_DISABLED`, so pumping the frame does not age the
## chase and the value read back is the one the age set by hand produced.
func _force_shown(t, spy: MapSpy) -> float:
	spy.queue_redraw()
	await t.pump_frames(1)
	if spy.armies.is_empty():
		return -1.0
	var text := str(spy.armies[0]["text"])
	var parts := text.split("힘 ")
	if parts.size() < 2:
		return -1.0
	return str(parts[1]).to_float()


func _pool(army: Army) -> float:
	var sum := 0.0
	for i in army.hp.size():
		if army.alive[i] != 0:
			sum += army.hp[i]
	return sum
