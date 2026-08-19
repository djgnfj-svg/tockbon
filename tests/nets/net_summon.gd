extends RefCounted
## The sea summon, in the sim alone: the band `grid.can_summon_at` opens, the landing it derives, the
## route a boat born out there actually sails, and `Battle.summon`'s seven refusals. **No tree, no
## view, no shell** — every object here is built with `.new()`.
##
## ⚠⚠ **THE ROW THIS FILE EXISTS FOR IS THE ZERO-HARBOUR ONE.** `sea-summon`'s structural sentence is
## that a summon has NO harbour: `send` names the destination and derives the origin from a harbour,
## and this names the origin and derives the destination from the coast. The way that claim dies
## quietly is somebody satisfying an existing net by calling `home_harbour_for` inside `summon`, or
## seeding the band off `sendable`. On the three shipped islands both would still pass everything else
## in this file, because every one of them has harbours and all their water is connected. So there is
## a fixture with **no `H` at all**: the band still fills, `summon` still works, and `send` refuses
## every tile on the same grid.
##
## ⚠ **Every bound below is a LITERAL**, re-measured off `islands.gd` rather than read back off the
## grid under test. A check that asks the subject for its own expectation is this repo's named false
## green.
##
## The mutation paired with each row is written beside it. `sea-summon` section 6.1 is the table.


## ⚠⚠ **THE BAND INVERTED — it is a MINIMUM distance from land now, not a maximum**, on the user's own
## sentence after playing (*"해안선에 배를 배치하는게 아니라 좀 거리를 둬야함 … 배가 가는게 중요하니까"*).
## Every literal in this block moved with it, and all of them were re-derived outside Godot from a
## from-scratch reimplementation of `_summon_field` before being typed in here.
##
## The three shipped islands' band sizes at `Rules.SUMMON_BAND_MIN_TILES = 6`. Measured off the rows,
## not counted back off a `Grid`. ⚠ At `>= 4` they are 470 / 460 / 478 and at `>= 8` they are
## 256 / 256 / 256 — which is what a `>=` moved by two reads as.
## ⚠⚠ **THE CEILING IS 10 AND IT IS A CLIFF, not taste**: at `>= 12` the band is 48 tiles and resolves
## to **2 distinct landings on every island**. `rules.gd` carries the sweep.
const BAND_AT_MIN_6 := [360, 360, 366]

## How many LANDINGS the band can reach, against how many coast tiles the drag can reach.
##
## ⚠⚠ **THE OLD NOTE HERE IS NOW FALSE AND IS KEPT AS THE CORRECTION.** It read *"`SUMMON_BAND_TILES`
## 2 -> 1 does NOT bite this row and that is measured"* — true of a band hugging the coast, where the
## count was 82 / 75 / 80 at d = 1, 2 AND 3. **Under a minimum distance the constant bites this row
## hard**: 45 / 40 / 43 at `>= 3`, 42 / 38 / 40 at `>= 4`, **34 / 35 / 34 at `>= 6`**, 30 / 31 / 25 at
## `>= 10`, and **2 / 2 / 2 at `>= 12`**. Moving the band out
## really does cost the player addressable coastline, which is the trade `sea-summon` §3.3 predicted
## and the user's decision overrode.
const LANDINGS_FROM_BAND := [34, 35, 34]
const SENDABLE_COAST := [84, 76, 82]

## Water on island 0 that is CLOSER to the coast than the band allows — the tiles a press must be
## refused on. ⚠ **The refusal arm flipped with the band**: it used to be the open ocean and it is the
## shoreline now. A self-check for that arm: at 0 it would be vacuous.
const NEAR_WATER_ISLAND_0 := 364


func run(t) -> void:
	_the_band(t)
	_the_long_map_band(t)
	_a_lake_no_boat_can_leave(t)
	_no_land_is_summonable(t)
	_the_landing_of_every_band_tile(t)
	_what_the_derivation_costs(t)
	_every_route_is_water_then_one_beach(t)
	_a_grid_with_no_harbours(t)
	_the_field_is_built_once(t)
	_the_tie_break(t)
	_the_boat_has_no_harbour(t)
	_highest_hp_first(t)
	_a_pinned_hold_does_not_grow_the_army(t)
	_seven_refusals(t)
	_a_summoned_boat_goes_home_to_the_sea(t)
	_a_mixed_plan_unloads_on_two_tiles(t)
	_the_slot_table(t)


# -- G1 --------------------------------------------------------------------------------------------
## ⚠ Mutation: `can_summon_at`'s `<=` -> `<` (⇒ 90 / 82 / 88).
func _the_band(t) -> void:
	for i in 3:
		var g := _island(i)
		var band := _band_tiles(g)
		t.eq(band.size(), int(BAND_AT_MIN_6[i]),
			"섬 %d 의 소환 가능한 바다 칸이 %d 개다" % [i, int(BAND_AT_MIN_6[i])])
	t.eq(Rules.SUMMON_BAND_MIN_TILES, 6,
		"띠는 해안에서 여섯 홉 이상 떨어진 물이다 (이 파일의 리터럴이 재는 값 — 자가 점검)")
	# ⚠ The DIRECTION, asserted separately from the number: a tile one hop out is refused and a tile far
	# out is allowed. Under the old rule both answers were the other way round, so a check that only
	# read the count would have passed a band that inverted back.
	var g0 := _island(0)
	var hugging := -1
	var out_at_sea := -1
	for tile in g0.w * g0.h:
		if g0.water[tile] == 0:
			continue
		if g0.summon_landing_of(tile) < 0:
			continue
		if hugging < 0 and not g0.can_summon_at(tile):
			hugging = tile
		if out_at_sea < 0 and g0.can_summon_at(tile):
			out_at_sea = tile
	t.ok(hugging >= 0 and out_at_sea >= 0, "가까운 물과 먼 물을 하나씩 찾았다 (자가 점검)")
	t.ok(not g0.can_summon_at(hugging), "해안에 붙은 물은 거절한다 — 예전 규칙은 여기만 받아들였다")
	t.ok(g0.can_summon_at(out_at_sea), "떨어진 물은 받아들인다 — 예전 규칙은 여기를 거절했다")


## ⚠⚠ **THE LINE THE INVERSION MADE LOAD-BEARING, AND IT WAS GREEN WHEN DELETED.** `can_summon_at`
## now tests `summon_hops[t] == UNREACHABLE` explicitly. Under the OLD `<= SUMMON_BAND_TILES` that test
## was free: `UNREACHABLE` is `1 << 30` and failed the ceiling on its own. Under `>=` it **passes** —
## so without the guard every unreachable water tile in the game joins the band.
##
## ⚠ **Measured: dropping the guard reddens NOTHING on the three shipped islands or the long map**,
## because all their water is one connected body and no water tile is ever unreachable. That is the
## same shape this feature was bounced for one round ago — a line whose comment claims it matters while
## nothing measures it — so it gets a fixture that makes it matter.
##
## The fixture is a lake ringed by `#`. A hole is impassable, so the lake touches no PASSABLE tile
## anywhere in its component and `_summon_field` never seeds it: hops stay `UNREACHABLE` and its
## landing stays -1. **A boat born there would have nowhere to sail**, and the band would be painted
## green over water no hull can leave.
func _a_lake_no_boat_can_leave(t) -> void:
	var g := Grid.new()
	# ⚠ **Grown 12x12 -> 24x24 when the band went from `>= 4` to `>= 6`, and sized for the CEILING this
	# time.** It has 351 band tiles at 6 and still 47 at 10, so the next distance bump does not empty it
	# again — a fixture that has to be regrown every time a constant moves is one nobody trusts.
	g.load_rows([
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~.....~~~~~~~~~",
		"~~~~~~~~~~.###.~~~~~~~~~",
		"~~~~~~~~~~.#~#.~~~~~~~~~",
		"~~~~~~~~~~.###.~~~~~~~~~",
		"~~~~~~~~~~.....~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
	])
	var lake := g.tile_index(12, 12)
	t.eq(int(g.water[lake]), 1, "가운데 (12,12)는 물이다 (자가 점검)")
	t.eq(g.summon_hops[lake], Grid.UNREACHABLE,
		"그런데 구멍에만 둘러싸여 있어 씨앗이 안 뿌려진다 — hops 가 UNREACHABLE 이다 (자가 점검)")
	t.eq(g.summon_landing_of(lake), -1, "그래서 갈 상륙지도 없다 (자가 점검)")
	# ⚠ **The self-check that makes the row bite**: `UNREACHABLE` really is greater than the minimum, so
	# a `>=` without the guard really does accept this tile. Without this line the row below would be
	# green for a grid where the comparison never came up.
	t.ok(Grid.UNREACHABLE >= Rules.SUMMON_BAND_MIN_TILES,
		"UNREACHABLE 는 최소 거리보다 크다 — 가드를 빼면 `>=` 가 이 칸을 받아들인다는 뜻이다 (자가 점검)")
	t.ok(not g.can_summon_at(lake), "그래도 그 칸은 소환 지점이 아니다 — 배가 못 나가는 물이다")

	# The floor: the OUTER sea on the same grid is summonable, so the refusal above is not "this grid
	# has no band at all".
	var band := _band_tiles(g)
	t.eq(band.size(), 351, "같은 격자의 바깥 바다는 351칸이 소환 지점이다")
	var no_landing := 0
	for raw in band:
		if g.summon_landing_of(int(raw)) < 0:
			no_landing += 1
	t.eq(no_landing, 0, "그리고 그 351칸은 전부 갈 상륙지가 있다 — 띠는 언제나 상륙지의 부분집합이다")


## ⚠⚠ **THE 144 x 32 MAP, because the band that changed is the one thing a long map is FOR.** The user's
## reason for moving it out was *"배가 가는게 중요하니까"* — the crossing is the thing worth watching —
## and a map three times as wide is where a crossing has room to be long.
##
## Derived outside Godot from the same from-scratch reimplementation as the three islands above:
## **1128 band tiles · 138 distinct landings · crossing 1.60 / 3.18 / 17.96 s** at `BOAT_SPEED` 4.0.
## ⚠ **The catchment barely collapses here** — 140 of 174 coast tiles stay individually addressable
## against 34 of 84 on island 1 — because the coast is one long straight line rather than a ring, so
## far-out sea drains to many different nearest landings instead of to four corners.
##
## ⚠ This map is **not wired into `Rules.MAP_NODES`** and no node opens it; what is measured here is
## that the rule does not fall over at three times the width.
func _the_long_map_band(t) -> void:
	var g := Grid.new()
	g.load_rows(Islands.rows_of(Islands.LONG_ISLAND_INDEX))
	t.eq(g.w, 144, "긴 지도가 144칸 폭으로 실렸다 (자가 점검)")
	var band := _band_tiles(g)
	t.eq(band.size(), 1128, "긴 지도의 띠가 1128칸이다")
	var reached := {}
	var no_route := 0
	var longest := 0.0
	for raw in band:
		var tile := int(raw)
		reached[g.summon_landing_of(tile)] = true
		var route := g.summon_route(tile)
		if route.size() < 2:
			no_route += 1
			continue
		var d := 0.0
		for k in range(1, route.size()):
			d += route[k - 1].distance_to(route[k])
		longest = maxf(longest, d)
	t.eq(no_route, 0, "그 1128칸 전부에서 항로가 나온다 — 띠 안에 못 가는 칸이 없다")
	t.eq(reached.size(), 138, "그리고 그 띠가 닿는 상륙지가 138곳이다")
	# ⚠ **The whole point of a long map, as a number**: the longest crossing here is three times the
	# longest on a 48-column island (5.96 tiles-per-second-worth), which is what the user asked the band
	# to buy. The bound is a literal derived outside Godot, not read back off the route.
	t.ok(absf(longest / Rules.BOAT_SPEED - 17.96) < 0.05,
		"가장 긴 항해가 17.96초다 (실제 %.2f) — 48칸짜리 섬의 5.96초보다 세 배 길다" % (longest / Rules.BOAT_SPEED))


# -- G2 --------------------------------------------------------------------------------------------
## ⚠⚠ **MEASURED: DROPPING THE `water[t] != 0` CLAUSE IN `can_summon_at` DOES NOT REDDEN THIS ROW**,
## and the reason is structural — `_summon_field` writes `summon_hops` on water tiles only, so a land
## tile already carries `UNREACHABLE` and fails the range test on its own. **This row measures the
## INVARIANT rather than that one line**, and it is written down here so nobody reads its green as a
## guarantee about the clause. What DOES bite it is a seed loop that walks something other than water,
## and that shows up in the band-size row above (measured: `can_summon_at` returning `true` outright
## takes island 0 from 190 to 724). ⚠ Do not "fix" this by deleting the clause — see its own comment
## in `grid.gd`.
func _no_land_is_summonable(t) -> void:
	var land_hits := 0
	var dry_hits := 0
	var checked := 0
	for i in 3:
		var g := _island(i)
		for tile in g.w * g.h:
			checked += 1
			if g.passable[tile] != 0 and g.can_summon_at(tile):
				land_hits += 1
			if g.can_summon_at(tile) and g.water[tile] == 0:
				dry_hits += 1
	t.eq(checked, 3 * 48 * 32, "세 섬의 칸을 전부 봤다 (자가 점검 — 0개면 깨끗한 게 아니라 안 돈 것이다)")
	t.eq(land_hits, 0, "육지 칸은 어떤 섬에서도 소환 지점이 아니다")
	t.eq(dry_hits, 0, "그리고 소환 가능한 칸은 전부 물이다")


# -- G3 --------------------------------------------------------------------------------------------
## ⚠ Mutation: drop the `passable[nt] == 0: continue` in `_summon_field`'s seed loop — every landing
## becomes another water tile and a boat aims at the sea.
func _the_landing_of_every_band_tile(t) -> void:
	var bad := 0
	var inland := 0
	var seen := 0
	for i in 3:
		var g := _island(i)
		for tile in _band_tiles(g):
			seen += 1
			var landing := g.summon_landing_of(int(tile))
			if landing < 0 or g.passable[landing] == 0:
				bad += 1
				continue
			if not _touches_water(g, landing):
				inland += 1
	t.eq(seen, 360 + 360 + 366, "세 섬의 띠 칸 1086개를 전부 봤다 (자가 점검)")
	t.eq(bad, 0, "띠의 모든 칸이 상륙할 수 있는 육지 칸을 가리킨다")
	t.eq(inland, 0, "그리고 그 육지 칸은 전부 물에 닿아 있다 — 내륙을 가리키는 칸이 없다")


# -- G4 --------------------------------------------------------------------------------------------
## ⚠ Mutation: seed only from ORTHOGONALLY adjacent water (4-way) — the corner landings drop out.
## ⚠⚠ **`SUMMON_BAND_MIN_TILES` DOES bite this row now**, which is the opposite of what its old comment
## said: under a maximum the landing count was flat at 82 / 75 / 80 for every value, and under a
## minimum it falls with distance (45 / 40 / 43 at 3, **42 / 38 / 40 at 4**, 34 / 35 / 34 at 6). The
## band size row above is no longer the only thing that number moves.
func _what_the_derivation_costs(t) -> void:
	for i in 3:
		var g := _island(i)
		var reached := {}
		for tile in _band_tiles(g):
			reached[g.summon_landing_of(int(tile))] = true
		t.eq(reached.size(), int(LANDINGS_FROM_BAND[i]),
			"섬 %d 에서 띠가 닿는 상륙지가 %d 곳이다" % [i, int(LANDINGS_FROM_BAND[i])])
		t.eq(_sendable_union(g).size(), int(SENDABLE_COAST[i]),
			"섬 %d 에서 드래그가 닿는 해안이 %d 칸이다 (오늘의 제스처 — 자가 점검)"
				% [i, int(SENDABLE_COAST[i])])
	# ⚠⚠ **THE COST OF THE DERIVATION WENT FROM TWO TILES TO HALF THE COASTLINE, and it is stated as a
	# number rather than softened.** Under the old hugging band the derivation lost 2 / 1 / 2 coast
	# tiles. Moving the band out to four hops means many sea tiles share one nearest landing, so the
	# player can still address **exactly half** of what a drag could: 42 of 84, 38 of 76, 40 of 82.
	# `sea-summon` §3.3 predicted this and measured the shape of it (the four biggest catchments are
	# corner landings, 40 / 40 / 72 / 84 tiles at this distance against a MEDIAN catchment of 8); the
	# user's decision overrides its verdict, and the price is written here where it can be re-measured.
	t.eq(SENDABLE_COAST[0] - LANDINGS_FROM_BAND[0], 50, "섬 0 에서 도출이 잃는 것은 50칸이다 — 해안의 60%")
	t.eq(SENDABLE_COAST[1] - LANDINGS_FROM_BAND[1], 41, "섬 1 에서는 41칸")
	t.eq(SENDABLE_COAST[2] - LANDINGS_FROM_BAND[2], 48, "섬 2 에서는 48칸")


# -- G5 --------------------------------------------------------------------------------------------
## ⚠ Mutation: make `_straight_is_all_water` return `true` unconditionally ⇒ the smoother cuts routes
## over land. Also bitten by reversing the descent, which would put the landing at index 0.
func _every_route_is_water_then_one_beach(t) -> void:
	var short_routes := 0
	var wrong_start := 0
	var wrong_end := 0
	var dry_waypoints := 0
	var not_adjacent := 0
	var bent := 0
	var seen := 0
	for i in 3:
		var g := _island(i)
		for raw in _band_tiles(g):
			var tile := int(raw)
			seen += 1
			var path := g.summon_route(tile)
			if path.size() < 2:
				short_routes += 1
				continue
			if path[0] != g.tile_point(tile):
				wrong_start += 1
			if path[path.size() - 1] != g.tile_point(g.summon_landing_of(tile)):
				wrong_end += 1
			if path.size() > 2:
				bent += 1
			# ⚠⚠ **The last WATER waypoint must touch the landing**, and this is the row that measures
			# the descent's same-landing restriction. The landing is APPENDED after the walk, so a
			# descent that drifted onto another beach's field still ends on the right tile in the array
			# — the line simply teleports across the sea to get there. Measured: without this line,
			# deleting `if int(summon_landing[nt]) != want: continue` from `summon_route` was green.
			var beach: Vector2 = path[path.size() - 2]
			var shore := g.tile_point(g.summon_landing_of(tile))
			if maxf(absf(beach.x - shore.x), absf(beach.y - shore.y)) > 1.0:
				not_adjacent += 1
			for k in path.size() - 1:
				var wp: Vector2 = path[k]
				var wt := int(wp.y) * g.w + int(wp.x)
				if wt < 0 or wt >= g.water.size() or g.water[wt] == 0:
					dry_waypoints += 1
	t.eq(seen, 360 + 360 + 366, "세 섬의 띠 칸 1086개의 항로를 전부 걸었다 (자가 점검)")
	t.eq(short_routes, 0, "띠의 모든 칸에서 항로가 최소 두 점이다")
	t.eq(wrong_start, 0, "항로의 첫 점이 누른 그 칸이다 — 배는 거기서 태어난다")
	t.eq(wrong_end, 0, "항로의 끝 점이 도출된 상륙지다")
	t.eq(dry_waypoints, 0, "마지막을 뺀 모든 지점이 물이다 — 해변을 가로지르는 직선이 없다")
	t.eq(not_adjacent, 0,
		"그리고 마지막 물 지점이 상륙지에 붙어 있다 — 항로가 바다를 건너뛰어 해변에 닿지 않는다")
	t.ok(bent > 0, "그리고 두 점보다 긴 항로가 실제로 있다 (%d개 — 자가 점검)" % bent)


# -- G6 --------------------------------------------------------------------------------------------
## ⚠⚠ **THE ROW THIS FILE EXISTS FOR.** Mutation: make `_summon_field` seed from `sendable[0]`, or make
## `summon` derive its landing from `home_harbour_for` — either one turns this grid's every press into
## a refusal while every other row in this file stays green.
func _a_grid_with_no_harbours(t) -> void:
	var g := Grid.new()
	# ⚠⚠ **GROWN TWICE NOW — 6x6 -> 10x10 -> 24x24 — and this time it is sized for the CEILING.** A
	# minimum distance empties any fixture whose sea is shallower than the constant, and regrowing a
	# fixture every time a number moves is how a check quietly stops measuring anything. 24x24 holds
	# 432 band tiles at `>= 6` and still 176 at `>= 10`, which is the highest value `rules.gd` allows.
	# The island — a 2x2 patch of land with no `H` anywhere — is unchanged; only the sea is deeper.
	g.load_rows([
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~..~~~~~~~~~~~",
		"~~~~~~~~~~~..~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
	])
	t.eq(g.harbour_tiles.size(), 0, "이 격자에는 항구가 하나도 없다 (자가 점검)")
	t.eq(g.water_fields.size(), 0, "그래서 물 필드도 하나도 없다 (자가 점검)")

	var band := _band_tiles(g)
	t.ok(band.size() > 0, "그래도 띠는 채워진다 — %d 칸 (항구가 아니라 해안에서 자란다)" % band.size())

	# Every tile refused by `send`, on the same grid, in the same breath. A one-sided row would be
	# satisfied by a grid where nothing works at all.
	var refused := 0
	for tile in g.w * g.h:
		if g.home_harbour_for(tile) < 0:
			refused += 1
	t.eq(refused, g.w * g.h, "그리고 같은 격자에서 드래그는 모든 칸을 거절한다 — 갈 항구가 없다")

	var army := Army.new()
	army.add_starting_force()
	var b := Battle.new()
	b.setup(g, army, [], 60.0)
	var pressed := int(band[0])
	var uid := b.summon(0, pressed)
	t.ok(uid >= 0, "항구가 없는 격자에서도 소환이 된다 (uid %d)" % uid)
	t.eq(b.boats.size(), 1, "배가 한 척 생겼다")
	var boat: Dictionary = b.boats[0]
	t.eq(int(boat["target"]), g.summon_landing_of(pressed), "그 배의 목적지가 도출된 상륙지다")
	t.eq(b.send(0, int(boat["target"])), -1,
		"같은 상륙지로 send 는 여전히 -1 이다 — 소환에는 항구가 필요 없다는 것이 바로 이 줄이다")


# -- G7 --------------------------------------------------------------------------------------------
## ⚠ Mutation: build the summon field inside `can_summon_at` — the per-press BFS `sea-summon` refuses,
## because `field_view` asks that question once per visible tile per frame while aiming.
func _the_field_is_built_once(t) -> void:
	var g := _island(0)
	t.eq(g.summon_field_builds, 1, "소환 필드는 섬을 불러올 때 딱 한 번 지어진다")
	var harbours := g.harbour_tiles.size()
	t.eq(g.water_field_builds, harbours,
		"물 필드는 항구 수 그대로다 (%d) — 소환 BFS 가 그 안에 접혀 들어가지 않았다" % harbours)

	for k in 20:
		g.can_summon_at(k * 7)
		g.summon_landing_of(k * 7)
		g.summon_route(k * 7)
	t.eq(g.summon_field_builds, 1, "예순 번 읽어도 소환 필드는 그대로 한 번이다")
	t.eq(g.water_field_builds, harbours, "그리고 물 필드도 안 움직였다")


# -- G8 --------------------------------------------------------------------------------------------
## ⚠ Mutation, fixture 1: `nt < best` -> `nt > best` in the seed loop.
## ⚠ Mutation, fixture 2: delete the per-level frontier sort in `_summon_field`.
##
## ⚠⚠ **Both fixtures carry a SELF-CHECK that the thing they discriminate actually occurs**, because a
## tie-break fixture where the two orders happen to agree is a row that passes whatever the code does.
func _the_tie_break(t) -> void:
	# Fixture 1 — one water tile between two beaches. The lower TILE INDEX wins.
	var g := Grid.new()
	g.load_rows([
		".~.",
		"~~~",
		"~~~",
	])
	t.ok(g.passable[0] != 0 and g.passable[2] != 0, "두 상륙지가 둘 다 육지다 (자가 점검)")
	t.ok(g.water[1] != 0, "그 사이 칸이 물이다 (자가 점검)")
	t.eq(g.summon_landing_of(1), 0, "두 상륙지에 닿는 물칸은 낮은 칸 번호를 고른다")

	# Fixture 2 — a hop-2 tile whose two hop-1 neighbours order the OTHER way round. Tile 6 carries
	# landing 10 and tile 8 carries landing 4: ascending tile order says 6 first, ascending landing
	# order says 8 first, and only the second gives the minimum over all shortest paths.
	var g2 := Grid.new()
	# ⚠ **Four water rows added when the band inverted, and EVERY hand-derived literal below survived
	# it** — tiles 6 and 8 are still hop 1, tile 12 is still hop 2, and their landings are still 10, 4
	# and 4. What the rows buy is a tile far enough out to press at all: the route half of this check
	# needs `can_summon_at`, and nothing in a three-row grid is four hops from the shore.
	# ⚠ **Grown 5x7 -> 24x20 and WIDENED, not just deepened.** Growing downward never produces a
	# pressable tile carrying landing 4: everything deep below drains to the land at (0,2). The sea has
	# to reach out past (4,0) instead. Sized for the ceiling — 408 band tiles at `>= 6` and 320 at 10.
	# ⚠ **The tile INDICES moved with the width and the claim did not**: (1,1) is 25, (3,1) is 27 and
	# (2,2) is 50 now, and the shape this row is about survives exactly — 25 < 27 while landing 48 > 4,
	# and the level-2 tile still takes the lower landing.
	g2.load_rows([
		"~~~~.~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		".~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~",
	])
	t.eq(g2.summon_hops[25], 1, "(1,1)=25번 칸이 띠의 첫 층이다 (자가 점검)")
	t.eq(g2.summon_hops[27], 1, "(3,1)=27번 칸도 첫 층이다 (자가 점검)")
	t.eq(g2.summon_hops[50], 2, "(2,2)=50번 칸은 두 번째 층이다 (자가 점검)")
	t.ok(25 < 27 and g2.summon_landing_of(25) > g2.summon_landing_of(27),
		"칸 번호 순서와 상륙지 번호 순서가 실제로 어긋난다 (25->%d, 27->%d) — 안 어긋나면 이 줄은 공허하다"
			% [g2.summon_landing_of(25), g2.summon_landing_of(27)])
	t.eq(g2.summon_landing_of(50), g2.summon_landing_of(27),
		"두 번째 층도 낮은 상륙지를 고른다 — 층마다 (상륙지, 칸) 순으로 걷기 때문이다")
	t.eq(g2.summon_landing_of(50), 4, "그 값이 4번 칸이다 (리터럴)")
	# And the route honours it: a descent that drifted onto the other beach's field would draw a line
	# ending where the appended landing is not.
	# ⚠ **Pressed at tile 24 = (4,4) and not at 12.** Tile 12 carries the landing this row is about but
	# is only two hops out, so the band refuses it now; 24 is four hops out and carries the SAME
	# landing, which is what makes it the right substitute rather than a different question.
	t.eq(g2.summon_landing_of(10), 4, "(10,0)=10번 칸도 4번 상륙지를 가리킨다 (자가 점검 — 50번과 같은 답이다)")
	t.ok(g2.can_summon_at(10), "그리고 10번은 띠 안이다 (자가 점검)")
	t.ok(not g2.can_summon_at(50), "50번은 해안에 너무 가까워 거절된다 (자가 점검 — 띠가 뒤집힌 그 지점)")
	var path := g2.summon_route(10)
	t.eq(path[path.size() - 1], g2.tile_point(4), "10번에서 뜬 배의 항로도 4번 칸에서 끝난다")
	# ⚠⚠ **AND THE LAST WATER POINT TOUCHES IT.** This is the row that measures the descent's
	# same-landing restriction, and **it needs this fixture rather than a shipped island**: measured on
	# all three, dropping the restriction changes nothing at all, because their coasts are long enough
	# that neighbouring hop-1 tiles share a landing. Here they do not — without the restriction the walk
	# steps onto tile 6, whose beach is three tiles from the landing that gets appended, and the drawn
	# line teleports across the water to reach it.
	var beach: Vector2 = path[path.size() - 2]
	var shore := g2.tile_point(4)
	t.ok(maxf(absf(beach.x - shore.x), absf(beach.y - shore.y)) <= 1.0,
		"그 항로의 마지막 물 지점이 상륙지에 붙어 있다 — 다른 해변의 필드로 새지 않는다 (%s vs %s)"
			% [str(beach), str(shore)])


# -- B1 / B6 ---------------------------------------------------------------------------------------
## ⚠ Mutation: make `summon` call `home_harbour_for` and sail from the harbour it picks.
## ⚠⚠ **THIS ROW USED TO READ `boat["home"]` AND THAT KEY IS DELETED** with the drag it belonged to.
## The claim it carried — *a summoned boat has no harbour* — is stronger read off the PATH: a boat
## `send` builds starts AT a harbour tile and a summoned one starts at the pressed sea tile, which is
## a fact about where it actually is rather than about a field somebody remembered to write.
## **Both boats are built side by side in ONE function** so the contrast is the check rather than two
## rows that could each be satisfied alone.
func _the_boat_has_no_harbour(t) -> void:
	var g := _island(0)
	var army := Army.new()
	army.add_starting_force()
	var b := Battle.new()
	b.setup(g, army, Islands.spawns_of(0), Islands.time_limit_of(0))

	var beach := int(_sendable_union(g)[0])
	var sent := b.send(0, beach)
	t.ok(sent >= 0, "드래그로 한 척 띄웠다 (자가 점검)")
	var sent_boat: Dictionary = b.boats[0]
	var sent_from := Vector2(sent_boat["path"][0])
	var is_harbour := false
	for raw_h in g.harbour_tiles:
		if g.tile_point(int(raw_h)) == sent_from:
			is_harbour = true
	t.ok(is_harbour, "send 로 띄운 배는 항구 칸에서 출발한다 (%s)" % str(sent_from))

	var pressed := int(_band_tiles(g)[0])
	var summoned := b.summon(0, pressed)
	t.ok(summoned >= 0, "바다를 눌러 한 척 더 띄웠다")
	t.eq(b.boats.size(), 2, "배가 두 척이다")
	var sum_boat: Dictionary = b.boats[1]
	var sum_from := Vector2(sum_boat["path"][0])
	var summoned_at_harbour := false
	for raw_h2 in g.harbour_tiles:
		if g.tile_point(int(raw_h2)) == sum_from:
			summoned_at_harbour = true
	t.ok(not summoned_at_harbour,
		"소환한 배는 항구에서 안 뜬다 — 누른 바다 칸에서 뜬다 (%s)" % str(sum_from))
	t.eq(int(sum_boat["target"]), g.summon_landing_of(pressed),
		"그 배의 목적지는 grid.summon_landing_of 가 내놓은 그 칸이다")
	t.eq(Vector2(sum_boat["pos"]), g.tile_point(pressed), "그리고 배는 누른 바다 칸에 서 있다")
	var sid := int((sum_boat["soldiers"] as Array)[0])
	t.eq(b.soldier_state[sid], Battle.SoldierState.TRANSIT, "탄 병사는 TRANSIT 이다")
	t.eq(b.soldier_pos[sid], g.tile_point(pressed), "그 병사도 누른 바다 칸에 있다")


# -- B3 --------------------------------------------------------------------------------------------
## ⚠ Mutation: `slot_reserve_ids` returns them in id order instead of `living_ids_of_type`'s order.
func _highest_hp_first(t) -> void:
	var g := _island(0)
	var army := Army.new()
	army.add_starting_force()
	# HP order and id order now disagree: 2..5 are full, 0 is hurt and 1 is nearly gone.
	army.hp[0] = 5.0
	army.hp[1] = 3.0
	var b := Battle.new()
	b.setup(g, army, Islands.spawns_of(0), Islands.time_limit_of(0))
	t.ok(army.hp[2] > army.hp[0] and army.hp[0] > army.hp[1],
		"HP 순서와 아이디 순서가 실제로 어긋난다 (자가 점검)")

	var band := _band_tiles(g)
	var order: Array = []
	for k in 6:
		var uid := b.summon(0, int(band[k]))
		t.ok(uid >= 0, "%d번째 소환이 됐다" % k)
		var boat: Dictionary = b.boats[b.boats.size() - 1]
		order.append(int((boat["soldiers"] as Array)[0]))
	t.eq(order, [2, 3, 4, 5, 0, 1],
		"멀쩡한 몸부터 나간다 — 같은 HP 는 낮은 아이디부터다 %s" % str(order))


# -- B4 --------------------------------------------------------------------------------------------
## ⚠ Mutation: drop the `RESERVE` filter in `slot_reserve_ids` — the same six bodies board twenty
## boats. **The hold changes the SPEED of placing, never the AMOUNT: the roster is the cap.**
func _a_pinned_hold_does_not_grow_the_army(t) -> void:
	var g := _island(0)
	var army := Army.new()
	army.add_starting_force()
	var b := Battle.new()
	b.setup(g, army, Islands.spawns_of(0), Islands.time_limit_of(0))

	var band := _band_tiles(g)
	var placed := 0
	var refused := 0
	for k in 20:
		if b.summon(0, int(band[k % band.size()])) >= 0:
			placed += 1
		else:
			refused += 1
	t.eq(placed, 6, "슬롯 1 을 스무 번 눌러도 여섯 척뿐이다 (START_MELEE)")
	t.eq(refused, 14, "나머지 열넷은 거절이다 — 꾹 눌러도 군대가 늘지 않는다")
	t.eq(b.boats.size(), 6, "배도 여섯 척이다")
	t.eq(Rules.START_MELEE, 6, "시작 근접 병력이 여섯이다 (이 줄의 리터럴이 재는 값 — 자가 점검)")


# -- B2 --------------------------------------------------------------------------------------------
## ⚠ Mutation: drop any one guard. ⚠ For the unbound arm specifically: `summon_type_of(slot) < 0` ->
## `<= 0`, which refuses slot 0 forever because `Rules.CELL_MELEE` is 0 — and every count row above
## still passes, because a slot that refuses looks exactly like an empty roster.
## ⚠⚠ **MEASURED: the land arm and the far-water arm are NOT carried by `summon`'s own
## `can_summon_at` line** — deleting it reddens nothing, because `grid.summon_route` refuses on the
## same predicate and `summon` then refuses on the short path. What bites those two arms is
## `can_summon_at` itself (measured: made to return `true`, four rows in this file go red). Both lines
## are kept for the reason `send` keeps its own pair; the record is here so the green is not read as
## covering a line it does not.
func _seven_refusals(t) -> void:
	var g := _island(0)
	var band := _band_tiles(g)
	var good := int(band[0])

	# 1 — committed.
	var a := _fresh(0)
	t.ok(a.send(0, int(_sendable_union(g)[0])) >= 0, "확정하려면 배가 한 척은 있어야 한다 (자가 점검)")
	t.ok(a.commit(), "확정했다 (자가 점검)")
	_refuses(t, a, 0, good, "확정한 뒤에는 거절한다")

	# 2 — slot below range.
	_refuses(t, _fresh(0), -1, good, "슬롯 -1 은 거절한다")
	# 3 — slot above range.
	_refuses(t, _fresh(0), 5, good, "슬롯 5 는 거절한다 (칸이 다섯이므로 마지막 색인은 4다)")
	# 4 — the slot is unbound. ⚠ The `< 0` / `<= 0` arm.
	_refuses(t, _fresh(0), 2, good, "비어 있는 슬롯 3 은 거절한다")
	t.eq(Rules.summon_type_of(2), Rules.SUMMON_UNBOUND, "그 슬롯이 실제로 비어 있다 (자가 점검)")
	t.eq(Rules.CELL_MELEE, 0,
		"그리고 근접 세포의 번호는 0 이다 — 이 줄이 `<= 0` 이 왜 슬롯 1을 죽이는지의 전부다 (자가 점검)")

	# 5 — a land tile.
	var land := -1
	for tile in g.w * g.h:
		if g.passable[tile] != 0:
			land = tile
			break
	t.ok(land >= 0, "육지 칸을 하나 찾았다 (자가 점검)")
	_refuses(t, _fresh(0), 0, land, "육지를 누르면 거절한다")

	# 6 — water too CLOSE to the coast. ⚠ **This arm flipped with the band**: it used to be the open
	# ocean. The self-check is what stops it being vacuous.
	var near := -1
	var near_count := 0
	for tile in g.w * g.h:
		if g.water[tile] != 0 and g.summon_landing_of(tile) >= 0 and not g.can_summon_at(tile):
			near_count += 1
			if near < 0:
				near = tile
	t.eq(near_count, NEAR_WATER_ISLAND_0,
		"섬 0 에서 해안에 너무 가까운 물이 %d 칸이다 (자가 점검 — 0개면 이 팔은 공허하다)"
			% NEAR_WATER_ISLAND_0)
	_refuses(t, _fresh(0), 0, near, "해안에 붙은 물을 누르면 거절한다")

	# 7 — the slot is dry.
	var dry := _fresh(0)
	for k in 6:
		t.ok(dry.summon(0, int(band[k])) >= 0, "마르기 전에는 %d번째도 나간다 (자가 점검)" % k)
	t.eq(dry.slot_reserve_ids(0).size(), 0, "슬롯 1 이 실제로 말랐다 (자가 점검)")
	var before := dry.boats.size()
	t.eq(dry.summon(0, good), -1, "마른 슬롯은 거절한다")
	t.eq(dry.boats.size(), before, "그리고 배도 안 늘었다")


## One refusal arm: `-1` comes back, `boats` does not move, and **the body it would have taken is
## still RESERVE**. The second half is the one that catches a `summon` that returns -1 after already
## boarding somebody.
func _refuses(t, b: Battle, slot: int, tile: int, label: String) -> void:
	var before := b.boats.size()
	var states := b.soldier_state.duplicate()
	t.eq(b.summon(slot, tile), -1, label)
	t.eq(b.boats.size(), before, "%s — 배가 안 늘었다" % label)
	t.eq(b.soldier_state, states, "%s — 아무도 배에 안 탔다" % label)


# -- B5 --------------------------------------------------------------------------------------------
## ⚠ Mutation: delete `back.reverse()` in `_phase_landings`, or add a return-to-harbour
## branch to it — a summoned boat has `home == -1` and would sail to harbour -1.
func _a_summoned_boat_goes_home_to_the_sea(t) -> void:
	var g := _island(0)
	var army := Army.new()
	army.add_starting_force()
	var b := Battle.new()
	b.setup(g, army, Islands.spawns_of(0), Islands.time_limit_of(0))

	var pressed := int(_band_tiles(g)[0])
	t.ok(b.summon(0, pressed) >= 0, "바다에서 한 척 띄웠다 (자가 점검)")
	t.ok(b.commit(), "확정했다 (자가 점검)")

	var turned := false
	var back_end := Vector2.ZERO
	var gone := false
	for _k in 400:
		b.begin_frame()
		b.step(0.05)
		if not turned and not b.boats.is_empty():
			var boat: Dictionary = b.boats[0]
			if int(boat["phase"]) == Battle.Phase.RETURNING:
				turned = true
				var path: PackedVector2Array = boat["path"]
				back_end = path[path.size() - 1]
		if turned and b.boats.is_empty():
			gone = true
			break
	t.ok(turned, "배가 상륙하고 돌아서기까지 갔다")
	t.eq(back_end, g.tile_point(pressed), "돌아가는 항로의 끝은 소환한 바로 그 바다 칸이다")
	t.ok(gone, "그리고 도착해서 사라졌다 — 항구를 찾아 헤매지 않는다")


# -- B7 --------------------------------------------------------------------------------------------
## ⚠ Mutation: make `_free_tiles_from` refuse to walk over reserved tiles — the second boat waits out
## the island at a coast with an empty beach two tiles away.
func _a_mixed_plan_unloads_on_two_tiles(t) -> void:
	var g := _island(0)
	var army := Army.new()
	army.add_starting_force()
	var b := Battle.new()
	b.setup(g, army, Islands.spawns_of(0), Islands.time_limit_of(0))

	# Both aimed at ONE landing, which is the only arrangement that tests the spreading at all.
	var pressed := int(_band_tiles(g)[0])
	var landing := g.summon_landing_of(pressed)
	t.ok(b.send(0, landing) >= 0, "드래그로 한 척 (자가 점검)")
	t.ok(b.summon(0, pressed) >= 0, "소환으로 한 척 (자가 점검)")
	t.eq(b.boats.size(), 2, "둘이 같은 상륙지를 노린다")
	t.ok(b.commit(), "확정했다 (자가 점검)")

	var ashore: Array = []
	for _k in 400:
		b.begin_frame()
		b.step(0.05)
		ashore = b.ashore_ids()
		if ashore.size() >= 2:
			break
	t.eq(ashore.size(), 2, "섞인 계획의 두 척이 둘 다 병력을 내렸다")
	t.ok(b.soldier_pos[int(ashore[0])] != b.soldier_pos[int(ashore[1])],
		"그리고 서로 다른 칸에 섰다 — 한 해변에 겹쳐 쌓이지 않는다")


# -- R1 --------------------------------------------------------------------------------------------
## ⚠ Mutation: put `BISON` in slot 2. `session-loop`'s buildability review measured a previous attempt
## shipping *"bison, crow and lion with correct names and correct bodies"* as the player's army.
func _the_slot_table(t) -> void:
	t.eq(Rules.summon_slot_count(), 5, "슬롯이 다섯이다")
	t.eq(Rules.SUMMON_SLOTS.size(), 5, "표에도 다섯 줄이다")
	var bound := 0
	var enemy_typed := 0
	for i in Rules.summon_slot_count():
		var want := Rules.summon_type_of(i)
		if want >= 0:
			bound += 1
		if want >= 2:
			enemy_typed += 1
	t.eq(bound, 2, "그중 둘만 채워져 있다")
	t.eq(enemy_typed, 0, "들소·까마귀·사자가 들어간 슬롯은 하나도 없다 — 세포 경제는 아직 안 열렸다")
	t.eq(Rules.summon_type_of(0), Rules.CELL_MELEE, "1번은 근접 세포다")
	t.eq(Rules.summon_type_of(1), Rules.CELL_RANGED, "2번은 원거리 세포다")
	t.eq(Rules.summon_type_of(-1), Rules.SUMMON_UNBOUND, "범위 밖은 비어 있다고 답한다")
	t.eq(Rules.summon_type_of(9), Rules.SUMMON_UNBOUND, "위쪽 범위 밖도 마찬가지다")


# -- helpers ---------------------------------------------------------------------------------------

func _island(i: int) -> Grid:
	var g := Grid.new()
	g.load_rows(Islands.rows_of(i))
	return g


## A fresh `Battle` on island `i` with the starting force. **A new `Army` every time** — the refusal
## rows board and un-board bodies, and a shared roster would let one arm's state leak into the next.
##
## ⚠⚠ **THIS TOOK A `Grid` AND IGNORED IT.** It was `_fresh(g: Grid)` and built island 0 internally
## whatever it was handed, which was green only because every caller happens to pass island 0's grid:
## a row written tomorrow with `_fresh(_island(1))` would have measured island 0 and passed for the
## wrong reason, silently. The argument is the island INDEX now, so the rows, the spawns and the limit
## all come out of ONE number and cannot name different islands.
func _fresh(i: int) -> Battle:
	var grid := Grid.new()
	grid.load_rows(Islands.rows_of(i))
	var army := Army.new()
	army.add_starting_force()
	var b := Battle.new()
	b.setup(grid, army, Islands.spawns_of(i), Islands.time_limit_of(i))
	return b


func _band_tiles(g: Grid) -> PackedInt32Array:
	var out := PackedInt32Array()
	for tile in g.w * g.h:
		if g.can_summon_at(tile):
			out.append(tile)
	return out


## Every tile SOME harbour can land on. On all three shipped islands the water is one connected body,
## so each harbour's own set is the same one — the union is written out anyway rather than reading
## `sendable[0]`, because a fixture with two pools would make those different numbers.
func _sendable_union(g: Grid) -> PackedInt32Array:
	var out := PackedInt32Array()
	for tile in g.w * g.h:
		for hb in g.harbour_tiles.size():
			if g.can_land_at(hb, tile):
				out.append(tile)
				break
	return out


func _touches_water(g: Grid, tile: int) -> bool:
	var tx := tile % g.w
	var ty := tile / g.w
	for k in Grid.NEIGHBOURS.size():
		var nx := tx + int(Grid.NEIGHBOURS[k][0])
		var ny := ty + int(Grid.NEIGHBOURS[k][1])
		if nx < 0 or ny < 0 or nx >= g.w or ny >= g.h:
			continue
		if g.water[ny * g.w + nx] != 0:
			return true
	return false
