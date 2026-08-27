extends RefCounted
## The sea summon, in the sim alone: the band `grid.can_summon_at` opens, the landing it derives, the
## route a boat born out there actually sails, and `Battle.summon`'s seven refusals. **No tree, no
## view, no shell** — every object here is built with `.new()`.
##
## ⚠⚠ **THE ROW THIS FILE EXISTS FOR IS THE ZERO-HARBOUR ONE.** `sea-summon`'s structural sentence is
## that a summon has NO harbour: the deleted `send` named the destination and derived the origin from a
## harbour, and this names the origin and derives the destination from the coast. The way that claim
## died quietly was somebody satisfying an existing net by seeding the band off the harbour tables. On
## the shipped island that would still pass everything else in this file, because it has harbour
## characters all the way round its border and all its water is connected. So there is a fixture with
## **no `H` at all**: the band still fills and `summon` still works on it.
##
## ⚠ **Every bound below is a LITERAL**, derived outside Godot from a from-scratch reimplementation of
## `_summon_field` rather than read back off the grid under test. A check that asks the subject for its
## own expectation is this repo's named false green.
##
## The mutation paired with each row is written beside it. `sea-summon` section 6.1 is the table.
##
## ⚠⚠ **EVERY ISLAND LITERAL IN THIS FILE WAS RE-MEASURED 2026-08-27 AGAINST THE ONE 26 x 20 BOARD.**
## The three 48 x 32 islands and the 144 x 32 long map are deleted, and the numbers that stood here
## were theirs. **What the old numbers knew, kept because it is the price of a decision and not a bug
## to be found again later**:
##
##  · **`BAND_AT_MIN_6 = [282, 282, 288]`** — band sizes at `>= 6` hops from land. At `>= 4` they were
##    470 / 460 / 478 and at `>= 8` 256 / 256 / 256, which is what a `>=` moved by two reads as; before
##    the ring was added (`SUMMON_RADIUS_RATIO`, on the user's 「섬 기준으로 동그랗게」) they were
##    360 / 360 / 366. ⚠⚠ **THE CEILING WAS 10 AND IT WAS A CLIFF, not taste**: at `>= 12` the band fell
##    to 48 tiles and resolved to **2 distinct landings on every island**.
##  · **`LANDINGS_FROM_BAND = [30, 31, 30]` against `SENDABLE_COAST = [84, 76, 82]`** — the derivation
##    cost the player **half the coastline**: many sea tiles share one nearest landing, and the four
##    biggest catchments were corner landings of 40 / 40 / 72 / 84 tiles against a MEDIAN catchment of
##    8. `sea-summon` §3.3 predicted that trade and the user's decision overrode its verdict.
##  · **The long map's own row** — 1128 band tiles, 138 landings, a longest crossing of 17.96 s against
##    5.96 s on a 48-column island. ⚠ Its finding was that **a straight coast keeps its catchments**:
##    140 of 174 coast tiles stayed individually addressable there against 34 of 84 on a ring-shaped
##    island, because far-out sea drains to many different nearest landings instead of to four corners.
##    **That is the argument for a long island, and it is the one thing worth re-measuring if one is
##    ever drawn again.**


## ⚠⚠ **THE BAND IS A MINIMUM distance from land, not a maximum**, on the user's own sentence after
## playing (*"해안선에 배를 배치하는게 아니라 좀 거리를 둬야함 … 배가 가는게 중요하니까"*).
##
## The island's band at `Rules.SUMMON_BAND_MIN_TILES = 3`. ⚠⚠ **Twenty-two tiles, and the number is
## small because BOTH ends of the band bite on a 26 x 20 board**: the moat is only about six hops wide,
## so `>= 4` leaves 6 tiles and `>= 5` leaves **none at all**. The ring (`SUMMON_RADIUS_RATIO` 0.46
## about the middle of the grid) takes the rest. **This is a real thing to watch when the island is
## next re-shaped** — one more hop of minimum distance empties the band and every press becomes a
## refusal, with `can_summon_at` still perfectly correct.
const BAND_TILES := 22

## How many LANDINGS the band can reach, against how many coast tiles there are to reach. ⚠ The
## second is the coastal set `_summon_field` seeds from — *passable AND touching water on any of eight
## sides* — which is what the deleted per-harbour `sendable` table used to answer, tile for tile.
const LANDINGS_FROM_BAND := 16
const COASTAL_TILES := 72

## Water a press must be REFUSED on: it has a landing, so it is not open ocean the field never reached,
## but it is inside `SUMMON_BAND_MIN_TILES` of the shore or outside the ring. **A self-check for that
## arm: at 0 it would be vacuous.**
const NEAR_WATER := 242


func run(t) -> void:
	_the_band(t)
	_a_lake_no_boat_can_leave(t)
	_no_land_is_summonable(t)
	_the_landing_of_every_band_tile(t)
	_what_the_derivation_costs(t)
	_every_route_is_water_then_one_beach(t)
	_a_grid_with_no_harbours(t)
	_the_field_is_built_once(t)
	_the_tie_break(t)
	_the_boat_has_no_harbour(t)
	_most_hurt_first(t)
	_a_pinned_hold_does_not_grow_the_army(t)
	_seven_refusals(t)
	_a_summoned_boat_goes_home_to_the_sea(t)
	_a_mixed_plan_unloads_on_two_tiles(t)
	_the_run_slots(t)
	_an_unregistered_slot_sends_nobody(t)
	_the_unit_table(t)


# -- G1 --------------------------------------------------------------------------------------------
## ⚠ Mutation: move `can_summon_at`'s comparison by one hop — at `>= 4` the band is 6 tiles and at
## `>= 5` it is **empty**, which is how narrow the moat on a 26 x 20 board is.
func _the_band(t) -> void:
	var g := _island()
	var band := _band_tiles(g)
	t.eq(band.size(), BAND_TILES, "섬의 소환 가능한 바다 칸이 %d 개다" % BAND_TILES)
	t.eq(Rules.SUMMON_BAND_MIN_TILES, 3,
		"띠는 해안에서 세 홉 이상 떨어진 물이다 (이 파일의 리터럴이 재는 값 — 자가 점검)")
	# ⚠ The DIRECTION, asserted separately from the number: a tile one hop out is refused and a tile far
	# out is allowed. Under the old rule both answers were the other way round, so a check that only
	# read the count would have passed a band that inverted back.
	var hugging := -1
	var out_at_sea := -1
	for tile in g.w * g.h:
		if g.water[tile] == 0:
			continue
		if g.summon_landing_of(tile) < 0:
			continue
		if hugging < 0 and not g.can_summon_at(tile):
			hugging = tile
		if out_at_sea < 0 and g.can_summon_at(tile):
			out_at_sea = tile
	t.ok(hugging >= 0 and out_at_sea >= 0, "가까운 물과 먼 물을 하나씩 찾았다 (자가 점검)")
	t.ok(not g.can_summon_at(hugging), "해안에 붙은 물은 거절한다 — 예전 규칙은 여기만 받아들였다")
	t.ok(g.can_summon_at(out_at_sea), "떨어진 물은 받아들인다 — 예전 규칙은 여기를 거절했다")


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
	# ⚠ **RE-PRICED 2026-08-27 when `SUMMON_BAND_MIN_TILES` read 3 rather than 6**: 152 -> 296 on the
	# same rows. **The fixture is not a claim about 296** — it is a claim that the OUTER sea of this
	# grid is summonable while the walled lake in the middle is not, and the count is here only so
	# 「바깥 바다도 비어 있다」 cannot pass as agreement.
	t.eq(band.size(), 296, "같은 격자의 바깥 바다는 296칸이 소환 지점이다 (고리 밖은 띠가 아니다 — 옛 값 152 at >= 6)")
	var no_landing := 0
	for raw in band:
		if g.summon_landing_of(int(raw)) < 0:
			no_landing += 1
	t.eq(no_landing, 0, "그리고 그 296칸은 전부 갈 상륙지가 있다 — 띠는 언제나 상륙지의 부분집합이다")


## ⚠⚠ **`_the_long_map_band` STOOD HERE AND ITS MAP IS DELETED** (2026-08-27). It loaded the 144 x 32
## board and measured 1038 band tiles, 132 landings and a longest crossing of **17.96 s** at
## `BOAT_SPEED` 4.0 — three times the 5.96 s a 48-column island could offer. **The user's reason for
## moving the band out to sea was *"배가 가는게 중요하니까"*, and a map three times as wide is where a
## crossing has room to be long**, so that row was the one number saying whether the rule bought
## anything. ⚠ Its second finding is the one to re-read before a long island is drawn again: **a
## STRAIGHT coast keeps its catchments** (140 of 174 coast tiles individually addressable, against 34
## of 84 on a ring-shaped island), because far-out sea drains to many different nearest landings
## instead of collapsing onto four corners.
##
## ⚠ **It is not replaced by a row on the 26 x 20 island.** Every crossing there is a couple of hops,
## and 「the crossing is long enough to be worth watching」 is exactly the claim that board cannot make
## — asserting it against a two-second sail would be a green measuring the opposite of what it says.


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
	var g := _island()
	for tile in g.w * g.h:
		checked += 1
		if g.passable[tile] != 0 and g.can_summon_at(tile):
			land_hits += 1
		if g.can_summon_at(tile) and g.water[tile] == 0:
			dry_hits += 1
	t.eq(checked, 26 * 20, "섬의 칸을 전부 봤다 (자가 점검 — 0개면 깨끗한 게 아니라 안 돈 것이다)")
	t.eq(land_hits, 0, "육지 칸은 소환 지점이 아니다")
	t.eq(dry_hits, 0, "그리고 소환 가능한 칸은 전부 물이다")


# -- G3 --------------------------------------------------------------------------------------------
## ⚠ Mutation: drop the `passable[nt] == 0: continue` in `_summon_field`'s seed loop — every landing
## becomes another water tile and a boat aims at the sea.
func _the_landing_of_every_band_tile(t) -> void:
	var bad := 0
	var inland := 0
	var seen := 0
	var g := _island()
	for tile in _band_tiles(g):
		seen += 1
		var landing := g.summon_landing_of(int(tile))
		if landing < 0 or g.passable[landing] == 0:
			bad += 1
			continue
		if not _touches_water(g, landing):
			inland += 1
	t.eq(seen, BAND_TILES, "섬의 띠 칸 %d개를 전부 봤다 (자가 점검)" % BAND_TILES)
	t.eq(bad, 0, "띠의 모든 칸이 상륙할 수 있는 육지 칸을 가리킨다")
	t.eq(inland, 0, "그리고 그 육지 칸은 전부 물에 닿아 있다 — 내륙을 가리키는 칸이 없다")


# -- G4 --------------------------------------------------------------------------------------------
## ⚠ Mutation: seed only from ORTHOGONALLY adjacent water (4-way) — the corner landings drop out.
## ⚠⚠ **`SUMMON_BAND_MIN_TILES` DOES bite this row**, which is the opposite of what its first comment
## said. On the deleted 48 x 32 boards: under a MAXIMUM the landing count was flat at 82 / 75 / 80 for
## every value, and under a MINIMUM it fell with distance (45 / 40 / 43 at 3, 42 / 38 / 40 at 4,
## 34 / 35 / 34 at 6). **The band size row above is not the only thing that number moves**, and on a
## 26 x 20 board it bites harder still — the band itself empties at 5.
func _what_the_derivation_costs(t) -> void:
	var g := _island()
	var reached := {}
	for tile in _band_tiles(g):
		reached[g.summon_landing_of(int(tile))] = true
	t.eq(reached.size(), LANDINGS_FROM_BAND,
		"띠가 닿는 상륙지가 %d 곳이다" % LANDINGS_FROM_BAND)
	t.eq(_coastal_tiles(g).size(), COASTAL_TILES,
		"그런데 배가 닿을 수 있는 해안은 %d 칸이다 (자가 점검)" % COASTAL_TILES)
	# ⚠⚠ **THE COST OF THE DERIVATION IS MOST OF THE COASTLINE, and it is stated as a number rather
	# than softened.** Under the old band hugging the coast the derivation lost 2 tiles; a band held
	# out at sea means many sea tiles share one nearest landing, so the player can address 16 of 72.
	# `sea-summon` §3.3 predicted this and measured the shape of it on the deleted islands (the four
	# biggest catchments were corner landings, 40 / 40 / 72 / 84 tiles against a MEDIAN catchment of
	# 8); **the user's decision overrides its verdict, and the price is written here where it can be
	# re-measured** rather than argued down.
	t.eq(COASTAL_TILES - LANDINGS_FROM_BAND, 56,
		"도출이 잃는 것은 56칸이다 — 해안의 78%")


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
	var g := _island()
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
	t.eq(seen, BAND_TILES, "섬의 띠 칸 %d개의 항로를 전부 걸었다 (자가 점검)" % BAND_TILES)
	t.eq(short_routes, 0, "띠의 모든 칸에서 항로가 최소 두 점이다")
	t.eq(wrong_start, 0, "항로의 첫 점이 누른 그 칸이다 — 배는 거기서 태어난다")
	t.eq(wrong_end, 0, "항로의 끝 점이 도출된 상륙지다")
	t.eq(dry_waypoints, 0, "마지막을 뺀 모든 지점이 물이다 — 해변을 가로지르는 직선이 없다")
	t.eq(not_adjacent, 0,
		"그리고 마지막 물 지점이 상륙지에 붙어 있다 — 항로가 바다를 건너뛰어 해변에 닿지 않는다")
	t.ok(bent > 0, "그리고 두 점보다 긴 항로가 실제로 있다 (%d개 — 자가 점검)" % bent)


# -- G6 --------------------------------------------------------------------------------------------
## ⚠⚠ **THE ROW THIS FILE EXISTS FOR.** Mutation: seed `_summon_field` from anything that starts at a
## harbour tile, or make `summon` derive its landing from one — either turns this grid's every press
## into a refusal while every other row in this file stays green.
## ⚠ **The two mutations used to be named as `sendable[0]` and `home_harbour_for`, and both symbols are
## deleted** (2026-08-27). **The mutation is not gone with them**: the seed loop is one line away from
## being written 「from the water a harbour can reach」 the next time somebody adds a harbour table, and
## this fixture — no `H` anywhere — is the only thing in the repo that would notice.
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
	# ⚠⚠ **TWO ROWS STOOD HERE AND BOTH NAMED DELETED SYMBOLS** (2026-08-27). `t.eq(g.water_fields.size(),
	# 0)` said the per-harbour water BFS table was empty on a harbourless grid, and a loop over
	# `home_harbour_for` said **the drag refused every tile of this grid in the same breath** — the
	# contrast was the check, because a one-sided row is satisfied by a grid where nothing works at all.
	# **`water_fields`, `home_harbour_for` and the drag itself are gone**, so the contrast has only one
	# side left and it is the side that still exists: a summon works here.
	# ⚠ **The claim is not weaker for it and the fixture is why**: this grid has no `H` anywhere, so a
	# `summon` that had quietly grown a harbour dependency would refuse every press on it while every
	# other row in this file stayed green.
	var band := _band_tiles(g)
	t.ok(band.size() > 0, "그래도 띠는 채워진다 — %d 칸 (항구가 아니라 해안에서 자란다)" % band.size())

	var army := Army.new()
	army.add_starting_force()
	var b := Battle.new()
	b.setup(g, army, [])
	var pressed := int(band[0])
	var uid := b.summon(0, pressed)
	t.ok(uid >= 0, "항구가 없는 격자에서도 소환이 된다 (uid %d)" % uid)
	t.eq(b.boats.size(), 1, "배가 한 척 생겼다")
	var boat: Dictionary = b.boats[0]
	t.eq(int(boat["target"]), g.summon_landing_of(pressed), "그 배의 목적지가 도출된 상륙지다")
	t.eq(Vector2(boat["pos"]), g.tile_point(pressed),
		"그리고 그 배는 누른 바다 칸에 서 있다 — 항구 하나 없는 격자에서 출발점을 스스로 만들었다")


# -- G7 --------------------------------------------------------------------------------------------
## ⚠ Mutation: build the summon field inside `can_summon_at` — the per-press BFS `sea-summon` refuses,
## because `field_view` asks that question once per visible tile per frame while aiming.
func _the_field_is_built_once(t) -> void:
	# ⚠⚠ **`water_field_builds` WAS THE SIBLING OF THIS COUNTER AND IT IS DELETED** (2026-08-27, with the
	# harbour system). Two rows here read it — 「물 필드는 항구 수 그대로다」 before and after sixty
	# reads — and their job was to prove the summon BFS had NOT been folded into the harbour one.
	# ⚠ **The trap they named is still live and it is why the surviving counter is asserted twice**:
	# *do not fold a second BFS into a counter to make a red go away, and do not raise a counter's
	# expected value either.* Two facts, two counters — and there is one fact left.
	var g := _island()
	t.eq(g.summon_field_builds, 1, "소환 필드는 섬을 불러올 때 딱 한 번 지어진다")

	for k in 20:
		g.can_summon_at(k * 7)
		g.summon_landing_of(k * 7)
		g.summon_route(k * 7)
	t.eq(g.summon_field_builds, 1, "예순 번 읽어도 소환 필드는 그대로 한 번이다")


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
## ⚠⚠ **THIS ROW USED TO READ `boat["home"]` AND THAT KEY IS DELETED** with the drag it belonged to.
## The claim it carries — *a summoned boat has no harbour* — is stronger read off the PATH, which is a
## fact about where the hull actually is rather than about a field somebody remembered to write.
##
## ⚠⚠ **AND THE CONTRAST IT WAS WRITTEN AS IS DELETED TOO** (2026-08-27). Both boats used to be built
## side by side in ONE function — `send` from a harbour, `summon` from the pressed sea tile — so the
## comparison was the check rather than two rows that could each be satisfied alone. **`Battle.send`
## has no callers left in `src/` and is gone**, so there is no second boat to hold this one against.
## ⚠ **What replaces the contrast is the board itself**: this island's `H` characters are its whole
## border ring, 88 of them, and the row below walks every one to say the boat did not start on any —
## a summon that had grown a harbour dependency would start on one of them and nothing else here
## would notice.
func _the_boat_has_no_harbour(t) -> void:
	var g := _island()
	var army := Army.new()
	army.add_starting_force()
	var b := Battle.new()
	b.setup(g, army, Islands.spawns())

	# ⚠⚠ **The pressed tile is chosen to NOT be a harbour character, and that is not fussiness.** This
	# board's `H` ring is the whole border, and part of the band sits on it — press one of those and
	# 「소환한 배는 항구에서 안 뜬다」 is violated by the fixture rather than by the code. **Pressing a
	# harbour tile is perfectly legal**; it is simply not the press this row is about.
	var pressed := -1
	for raw_p in _band_tiles(g):
		if not _is_harbour(g, int(raw_p)):
			pressed = int(raw_p)
			break
	t.ok(pressed >= 0, "항구 글자가 아닌 띠 칸을 하나 찾았다 (자가 점검)")
	var summoned := b.summon(0, pressed)
	t.ok(summoned >= 0, "바다를 눌러 한 척 띄웠다")
	t.eq(b.boats.size(), 1, "배가 한 척이다")
	t.ok(g.harbour_tiles.size() > 0, "그런데 이 판에는 항구 글자가 실제로 있다 (%d칸 — 자가 점검, 0이면 아래 줄이 공허하다)"
		% g.harbour_tiles.size())
	var sum_boat: Dictionary = b.boats[0]
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
## ⚠⚠ **MOST HURT FIRST, and it used to be HEALTHIEST first.** The user, asked which body a slot
## spends: ***"다친놈부터"***. **The fixture is what makes this row bite**: 2..5 are full, 0 is hurt and
## 1 is nearly gone, so the two orders pick DIFFERENT ids — the old rule gives `[2,3,4,5,0,1]` and the
## new one `[1,0,2,3,4,5]`. A fixture where the two agree would measure nothing at all.
## ⚠ Mutation: `slot_reserve_ids` returns them in id order, or in `living_ids_of_type`'s own
## healthiest-first order — the second is the OLD behaviour and this row is written to fail it.
func _most_hurt_first(t) -> void:
	var g := _island()
	var army := Army.new()
	army.add_starting_force()
	# HP order and id order now disagree: 2..5 are full, 0 is hurt and 1 is nearly gone.
	army.hp[0] = 5.0
	army.hp[1] = 3.0
	var b := Battle.new()
	b.setup(g, army, Islands.spawns())
	t.ok(army.hp[2] > army.hp[0] and army.hp[0] > army.hp[1],
		"HP 순서와 아이디 순서가 실제로 어긋난다 (자가 점검)")

	var band := _band_tiles(g)
	var order: Array = []
	for k in 6:
		var uid := b.summon(0, int(band[k]))
		t.ok(uid >= 0, "%d번째 소환이 됐다" % k)
		var boat: Dictionary = b.boats[b.boats.size() - 1]
		order.append(int((boat["soldiers"] as Array)[0]))
	t.eq(order, [1, 0, 2, 3, 4, 5],
		"다친 몸부터 나간다 — 같은 HP 는 낮은 아이디부터다 %s" % str(order))
	# ⚠ **The OLD answer written out, so this row cannot be read as agreeing with it.** Healthiest-first
	# on this fixture is `[2,3,4,5,0,1]`; the two share no first element, which is what makes the
	# assertion above a measurement rather than a restatement.
	t.ok(order[0] != 2, "그리고 옛 규칙(멀쩡한 몸부터)의 첫 답 2번이 아니다 (자가 점검)")
	# `army.living_ids_of_type` keeps its documented healthiest-first order. ⚠ Its one caller used to
	# be the probe putting the beak on the healthiest body; **the beak reward is deleted** (2026-08-25)
	# and the ORDER is still the documented contract, so the split stays asserted here.
	# ⚠ **`Rules.WOLF` stood here and the opening roster is `Rules.SWORDSMAN` now** — the wolf crossed
	# to the enemy's side, `Rules.START_SLOTS` is one row of ten swordsmen, and this call would have
	# indexed an EMPTY array and taken the whole net down with it rather than reddening one row.
	t.eq(int(army.living_ids_of_type(Rules.SWORDSMAN)[0]), 2,
		"army.living_ids_of_type 는 여전히 멀쩡한 몸부터다 — 문서가 그렇게 적어 뒀다")


# -- B4 --------------------------------------------------------------------------------------------
## ⚠ Mutation: drop the `RESERVE` filter in `slot_reserve_ids` — the same six bodies board twenty
## boats. **The hold changes the SPEED of placing, never the AMOUNT: the roster is the cap.**
func _a_pinned_hold_does_not_grow_the_army(t) -> void:
	var g := _island()
	var army := Army.new()
	army.add_starting_force()
	var b := Battle.new()
	b.setup(g, army, Islands.spawns())

	var band := _band_tiles(g)
	var placed := 0
	var refused := 0
	for k in 20:
		if b.summon(0, int(band[k % band.size()])) >= 0:
			placed += 1
		else:
			refused += 1
	# ⚠ **The counts are DERIVED from the opening table and only its own value is a literal.** Slot 0
	# opened with six while the run started on two species; it opens with ten since the second one
	# moved to a card (티켓 15).
	# ⚠⚠ **AND THE CARD THAT SECOND SPECIES MOVED TO IS DELETED** (2026-08-27, with the whole BEAST
	# CARD: `SPECIES_CARDS`, `SPECIES_CARD_BODIES`, `CardKind.SPECIES` and `Run._take_species_card`).
	# **Nothing changes on this row and that is the point** — the derivation reads `start_bodies_of(0)`
	# and the opening table did not move, so the ten is still the ten. What died is the sentence's
	# second half: a run can no longer take that second species back on a card, so the ten is now the
	# roster for the WHOLE run and not just for its opening. The old wording is kept rather than
	# rewritten because it says where the ten came from, and that history is still what set it.
	t.eq(Rules.start_bodies_of(0), 10, "개막 첫 칸의 병력이 열이다 (이 줄의 리터럴이 재는 값 — 자가 점검)")
	t.eq(placed, Rules.start_bodies_of(0), "슬롯 1 을 스무 번 눌러도 그 칸이 가진 만큼만 나간다")
	t.eq(refused, 20 - Rules.start_bodies_of(0), "나머지는 거절이다 — 꾹 눌러도 군대가 늘지 않는다")
	t.eq(b.boats.size(), Rules.start_bodies_of(0), "배도 그만큼이다")


# -- B2 --------------------------------------------------------------------------------------------
## ⚠ Mutation: drop any one guard. ⚠ For the unbound arm specifically: `army.slot_type_of(slot) < 0`
## -> `<= 0`, which refuses slot 0 forever because there IS a unit row 0 — and every count row above
## still passes, because a slot that refuses looks exactly like an empty roster.
## ⚠⚠ **MEASURED: the land arm and the far-water arm are NOT carried by `summon`'s own
## `can_summon_at` line** — deleting it reddens nothing, because `grid.summon_route` refuses on the
## same predicate and `summon` then refuses on the short path. What bites those two arms is
## `can_summon_at` itself (measured: made to return `true`, four rows in this file go red). Both lines
## are kept for the reason `send` keeps its own pair; the record is here so the green is not read as
## covering a line it does not.
func _seven_refusals(t) -> void:
	var g := _island()
	var band := _band_tiles(g)
	var good := int(band[0])

	# 1 — committed. ⚠ **The boat that makes the commit legal used to be a DRAG** (`send` onto the first
	# tile the harbour tables allowed); `send` is deleted, so the plan is authored the one way left —
	# a summon on a different band tile than the one pressed afterwards, so the refusal below is the
	# commit talking and not 「that tile is already taken」.
	var a := _fresh()
	t.ok(a.summon(0, int(band[1])) >= 0, "확정하려면 배가 한 척은 있어야 한다 (자가 점검)")
	t.ok(a.commit(), "확정했다 (자가 점검)")
	_refuses(t, a, 0, good, "확정한 뒤에는 거절한다")

	# 2 — slot below range.
	_refuses(t, _fresh(), -1, good, "슬롯 -1 은 거절한다")
	# 3 — slot above range.
	# ⚠ Off the END of the RUN's own slots, whatever the run has registered — derived so a fourth
	# registration does not turn this row into a rewrite.
	var fresh := _fresh()
	_refuses(t, fresh, fresh.army.slot_count(), good, "회차의 칸 수를 넘는 슬롯은 거절한다")
	# 4 — ⚠⚠ **THE UNBOUND ARM.** Every slot the run HAS registered is bound, so the `< 0` vs `<= 0`
	# rule is driven through the out-of-range door: `army.slot_type_of` answers `SUMMON_UNBOUND` there.
	t.eq(fresh.army.slot_type_of(fresh.army.slot_count()), Rules.SUMMON_UNBOUND,
		"칸 끝 너머는 비어 있다고 답한다 (자가 점검 — 위 줄이 거절하는 이유가 이것이다)")
	# ⚠ **어떤 종이 0번인지는 표 순서에 달렸고, 함정은 「0번 종이 존재한다」는 것 하나다.** 늑대가 0번이던
	# 시절 이 줄은 `Rules.CELL_MELEE == 0` 이었는데, 그것은 함정이 아니라 그날의 표 순서였다.
	t.ok(Rules.player_type_count() > 0 and Rules.side_of(0) == Rules.Side.PLAYER,
		"0번 줄이 아군 종으로 실재한다 (자가 점검 — 없으면 아래 줄이 공허하다)")
	t.ok(Rules.SUMMON_UNBOUND < 0,
		"그리고 빈 칸의 답은 음수다 — 이 둘이 `<= 0` 이 왜 0번 종을 영원히 거절하는지의 전부다")

	# 5 — a land tile.
	var land := -1
	for tile in g.w * g.h:
		if g.passable[tile] != 0:
			land = tile
			break
	t.ok(land >= 0, "육지 칸을 하나 찾았다 (자가 점검)")
	_refuses(t, _fresh(), 0, land, "육지를 누르면 거절한다")

	# 6 — water too CLOSE to the coast. ⚠ **This arm flipped with the band**: it used to be the open
	# ocean. The self-check is what stops it being vacuous.
	var near := -1
	var near_count := 0
	for tile in g.w * g.h:
		if g.water[tile] != 0 and g.summon_landing_of(tile) >= 0 and not g.can_summon_at(tile):
			near_count += 1
			if near < 0:
				near = tile
	t.eq(near_count, NEAR_WATER,
		"해안에 너무 가깝거나 고리 밖이라 거절되는 물이 %d 칸이다 (자가 점검 — 0개면 이 팔은 공허하다)"
			% NEAR_WATER)
	_refuses(t, _fresh(), 0, near, "해안에 붙은 물을 누르면 거절한다")

	# 7 — the slot is dry.
	var dry := _fresh()
	# ⚠ Derived from the opening table, not a literal 6 — slot 0's body count moved to ten (티켓 15).
	for k in Rules.start_bodies_of(0):
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
	var b := _fresh_with_a_beast()
	var g := b.grid

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
##
## ⚠⚠ **IT WAS A DRAG AND A SUMMON AND IT IS TWO SUMMONS NOW** (2026-08-27). `Battle.send` is deleted,
## so 「섞인 계획」 has nothing to mix; **what the row actually measures is unchanged** — two boats aimed
## at ONE landing, which is the only arrangement that tests the spreading at all — and two band tiles
## that share a landing are what produce it. ⚠ **They must be found rather than typed**: 22 band tiles
## resolve to 16 landings here, so a pair exists, but which pair is a fact about the board.
func _a_mixed_plan_unloads_on_two_tiles(t) -> void:
	var b := _fresh_with_a_beast()
	var g := b.grid

	var band := _band_tiles(g)
	var first := {}
	var pressed := -1
	var pressed2 := -1
	for raw in band:
		var tile := int(raw)
		var lz := g.summon_landing_of(tile)
		if first.has(lz):
			pressed = int(first[lz])
			pressed2 = tile
			break
		first[lz] = tile
	t.ok(pressed >= 0 and pressed2 >= 0,
		"같은 상륙지를 가리키는 띠 칸 두 개를 찾았다 (자가 점검 — 못 찾으면 아래가 겹침을 못 잰다)")
	var landing := g.summon_landing_of(pressed)
	t.eq(g.summon_landing_of(pressed2), landing, "그 둘의 상륙지가 실제로 같다 (자가 점검)")
	t.ok(b.summon(0, pressed) >= 0, "한 척 (자가 점검)")
	t.ok(b.summon(0, pressed2) >= 0, "또 한 척 (자가 점검)")
	t.eq(b.boats.size(), 2, "둘이 같은 상륙지를 노린다")
	t.ok(b.commit(), "확정했다 (자가 점검)")

	var ashore: Array = []
	for _k in 400:
		b.begin_frame()
		b.step(0.05)
		ashore = b.ashore_ids()
		if ashore.size() >= 2:
			break
	t.eq(ashore.size(), 2, "한 상륙지를 노린 두 척이 둘 다 병력을 내렸다")
	t.ok(b.soldier_pos[int(ashore[0])] != b.soldier_pos[int(ashore[1])],
		"그리고 서로 다른 칸에 섰다 — 한 해변에 겹쳐 쌓이지 않는다")


# -- R1 --------------------------------------------------------------------------------------------
## ⚠⚠ **THE SLOTS ARE RUN STATE NOW AND THIS ROW MOVED WITH THEM.** `Rules.SUMMON_SLOTS` was a
## CONSTANT table saying 「칸 s 는 영원히 종 t 에 묶여 있다」, and that sentence stopped being true the
## day a card could fill a slot — a constant holding a per-run fact is a shape this repo has paid for.
## What survives is the three lessons its header carried, and they are all below.
##
## ⚠⚠ **THE CARD THAT ORIGINALLY JUSTIFIED THIS MOVE IS DELETED** (2026-08-27 — the BEAST CARD, table
## and mechanism together; `CardKind` is one member wide now and every card is an item). **The move
## itself is NOT reverted and this row is not weakened**, because the reason it was made is not the
## only reason it holds: `Army.register_species` is still a live door that changes the slot count
## while a run is being played — 티켓 15's 「슬롯 자체를 강화한다」 economy and the raid path both open
## it — and a `const` table cannot answer a question whose answer moves. ⚠ **What IS now false is the
## historical clause above**: as of today nothing in `src/` fills a slot mid-run, so the four
## registration rows below are the only thing measuring that door. **They are written down here
## rather than argued away**: if that door is ever closed too, this whole row is what should be
## re-read before `Army.slots` is folded back into a constant.
##
## ⚠ Mutation: put an enemy row in a slot; count slots with a literal; answer `0` for an empty slot.
func _the_run_slots(t) -> void:
	# ⚠⚠ **THE COUNT IS PINNED AGAINST THE ARMY AND THE OPENING TABLE'S SIZE IS THE LITERAL**, never
	# the other way round — pinning both to one number moves them together and passes at any value.
	var a := Army.new()
	a.add_starting_force()
	t.eq(Rules.START_SLOTS.size(), 1, "회차는 표의 한 줄로 연다 (리터럴)")
	t.eq(a.slot_count(), Rules.START_SLOTS.size(), "그리고 새 군대의 칸 수는 그 표가 정한다")
	t.eq(Rules.roster_start_count(), 10,
		"시작 병력은 열이다 (리터럴) — 작은 섬 넷의 밀도가 전부 이 열에 맞춰져 있다")
	t.eq(a.slot_type_of(0), Rules.WOLF, "1번 칸은 늑대다")

	# Lesson 1: **the answer for an empty slot is `SUMMON_UNBOUND` and never 0.** There IS a row 0,
	# so a `0` here summons the squirrel with every bounds check downstream still passing.
	t.eq(a.slot_type_of(a.slot_count()), Rules.SUMMON_UNBOUND, "칸 끝 너머는 비어 있다고 답한다")
	t.eq(a.slot_type_of(-1), Rules.SUMMON_UNBOUND, "아래쪽 범위 밖도 마찬가지다")
	t.ok(a.slot_type_of(a.slot_count()) < 0, "그 답은 음수다 — `< 0` 로 검사해야 하는 이유가 이것이다")

	# Lesson 2: **an enemy row cannot be registered.** The old header said binding one 「reads as done
	# and ships enemy bodies as the player's army」; there is a door to try it through now.
	var enemy := Rules.player_type_count()
	t.eq(Rules.side_of(enemy), Rules.Side.ENEMY, "%d 번이 적 줄이다 (자가 점검)" % enemy)
	var before := a.slot_count()
	t.eq(a.register_species(enemy), -1, "적 편 종은 칸에 못 들어간다")
	t.eq(a.slot_count(), before, "그리고 거절이라 칸 수도 그대로다 — 아무것도 안 변했다")

	# Lesson 3: **one species, at most one slot.**
	t.eq(a.register_species(Rules.WOLF), -1, "이미 등록된 종은 두 번째 칸에 못 들어간다")
	t.eq(a.slot_count(), before, "그것도 아무것도 안 바꿨다")

	# The floor under those three ceilings: a legal registration DOES land.
	var got := a.register_species(Rules.BEAR)
	t.eq(got, before, "안 등록된 아군 종은 다음 빈 칸으로 들어간다 (자가 점검)")
	t.eq(a.slot_count(), before + 1, "그리고 칸이 하나 늘었다")
	t.eq(a.slot_type_of(got), Rules.BEAR, "그 칸이 그 종이다")

	# The ceiling on the ceiling: `SUMMON_SLOT_MAX` refuses, and nothing changes when it does.
	var full := Army.new()
	full.add_starting_force()
	for ty in Rules.player_type_count():
		full.register_species(ty)
	t.eq(full.slot_count(), Rules.SUMMON_SLOT_MAX, "다섯 종을 다 넣으면 칸이 상한만큼 찬다 (자가 점검)")
	t.eq(Rules.SUMMON_SLOT_MAX, 5, "그 상한은 다섯이다 (리터럴)")


## The summon and its reserve list both refuse a slot the run never registered — and they refuse it
## **without putting a body anywhere**, which a count-only check cannot see.
##
## ⚠ Mutation: `slot >= army.slot_count()` -> `slot >= Rules.SUMMON_SLOT_MAX`.
func _an_unregistered_slot_sends_nobody(t) -> void:
	var b := _fresh()
	var unbound := b.army.slot_count()
	t.ok(unbound < Rules.SUMMON_SLOT_MAX, "등록 안 된 칸이 상한 안쪽에 있다 (자가 점검)")
	t.eq(b.slot_reserve_ids(unbound).size(), 0, "등록 안 된 칸의 예비 병력은 비어 있다")
	var tile := int(_band_tiles(b.grid)[0])
	t.ok(tile >= 0, "띠 안의 칸을 하나 찾았다 (자가 점검)")
	t.eq(b.summon(unbound, tile), -1, "그 칸으로는 소환이 거절된다")
	t.eq(b.boats.size(), 0, "그리고 배가 한 척도 안 생겼다 — 거절은 아무것도 안 만든다")
	var transit := 0
	for i in b.soldier_state.size():
		if b.soldier_state[i] != Battle.SoldierState.RESERVE:
			transit += 1
	t.eq(transit, 0, "몸도 하나도 안 나갔다")
	# The floor: a REGISTERED slot on the same grid does send one.
	t.ok(b.summon(0, tile) >= 0, "등록된 칸으로는 나간다 (자가 점검)")


# -- U1 --------------------------------------------------------------------------------------------
## **The barking device the unit table has never had.** `rules.gd`'s own header says renumbering
## `UNITS` renumbers every spawn character and every hotkey binding at once **with nothing to bark
## about it** — these rows are that bark.
##
## ⚠ Mutation: swap two rows of `UNITS`; move an enemy row above a player row.
func _the_unit_table(t) -> void:
	# Every id constant, paired with the identifier its own row carries. The pair list is a second
	# copy of nothing — the NAMES are what the table stores — but its LENGTH is, so the length is
	# pinned against the table: a row added without a pair here reddens this line before anything else.
	var named := [
		[Rules.SWORDSMAN, "SQUIRREL"],
		[Rules.WOLF, "WOLF"],
		[Rules.SWORDSMAN, "COW"],
		[Rules.BEAR, "BEAR"],
		[Rules.CROW, "CROW"],
		[Rules.WOLF, "SPEARMAN"],
		[Rules.CROW, "ARCHER"],
		[Rules.WOLF, "SHIELDBEARER"],
		[Rules.LION, "LION"],
	]
	t.eq(named.size(), Rules.UNITS.size(),
		"이 검사가 표의 모든 줄을 든다 — 줄이 늘면 여기가 먼저 문다 (자가 점검)")
	for raw in named:
		var pair: Array = raw
		t.eq(Rules.name_of(int(pair[0])), str(pair[1]),
			"%s 상수가 제 줄을 가리킨다" % str(pair[1]))

	# The side column, and the ordering contract that `Loadout`'s board index stands on.
	var players := 0
	var first_enemy := -1
	for i in Rules.UNITS.size():
		if Rules.side_of(i) == Rules.Side.PLAYER:
			players += 1
			t.ok(first_enemy < 0, "%d 번 아군 줄이 어떤 적 줄보다도 앞에 있다" % i)
		elif first_enemy < 0:
			first_enemy = i
	t.ok(players > 0 and players < Rules.UNITS.size(),
		"표에 아군 줄도 적 줄도 있다 — 한쪽만이면 아래 줄들이 공허하다 (자가 점검)")
	# ⚠ **어디에도 숫자로 안 박는다.** 아군 수는 표를 걸어서 나오고, 이 검사도 표를 걸어서 센다.
	t.eq(Rules.player_type_count(), players, "아군 종 수는 표를 세어서 나온다")
	for i in Rules.player_type_count():
		t.eq(Rules.side_of(i), Rules.Side.PLAYER,
			"아군 줄 번호가 0 부터 연속이다 — %d 번" % i)
	t.eq(Rules.side_of(Rules.player_type_count()), Rules.Side.ENEMY,
		"그리고 바로 다음 줄이 적이다 — 연속의 끝을 못 박는다")

	# ⚠⚠ **THE FOUR TRANSPLANTED ROWS, PINNED AS LITERALS.** `rules.gd` claims 늑대 · 까마귀 · 궁수 ·
	# 방패병 carry the numbers their pre-rename rows carried, and **nothing measured that claim** —
	# 까마귀's damage in particular was pinned in no file at all, so changing it 1.5 -> 2.5 reddened
	# one HP-total line in `net_run` and nothing else. The literals below are the OLD table's own
	# values, typed in rather than read back: a check that asks the subject for its expectation is
	# this repo's named false green.
	#
	# ⚠ **The two that are NOT transplants are deliberately absent** — 다람쥐 · 소 · 곰 · 창병 are first
	# drafts the user is expected to move, and pinning them would turn a tuning pass into a rewrite.
	var moved := [
		# row                   hp    dmg  period range  area  speed  detect
		[Rules.WOLF,           14.0,  2.0,  1.0,   0.0,  0.0,  4.0,  Rules.NO_DETECT],
		[Rules.CROW,            8.0,  1.5,  1.0,   4.0,  1.0,  4.0,  Rules.NO_DETECT],
		[Rules.CROW,          6.0,  1.5,  1.0,   3.0,  0.0,  6.0,  12.0],
		[Rules.WOLF,   20.0,  3.0,  2.0,   0.0,  0.0,  2.5,  6.0],
	]
	for raw2 in moved:
		var row: Array = raw2
		var ty := int(row[0])
		var who := Rules.label_of(ty)
		t.eq(Rules.hp_of(ty), float(row[1]), "%s 의 체력이 옮겨온 값 그대로다" % who)
		t.eq(Rules.damage_of(ty), float(row[2]), "%s 의 공격력이 옮겨온 값 그대로다" % who)
		t.eq(Rules.period_of(ty), float(row[3]), "%s 의 공격주기가 옮겨온 값 그대로다" % who)
		t.eq(Rules.range_of(ty), float(row[4]), "%s 의 사거리가 옮겨온 값 그대로다" % who)
		t.eq(Rules.area_of(ty), float(row[5]), "%s 의 범위가 옮겨온 값 그대로다" % who)
		t.eq(Rules.speed_of(ty), float(row[6]), "%s 의 이동속도가 옮겨온 값 그대로다" % who)
		t.eq(Rules.detect_of(ty), float(row[7]), "%s 의 시야가 옮겨온 값 그대로다" % who)


# -- helpers ---------------------------------------------------------------------------------------

## The island, loaded the way the game loads it — terrain AND tier board together.
##
## ⚠⚠ **IT TOOK AN ISLAND INDEX AND IGNORED IT** (dropped 2026-08-27). `_island(i)` built the same grid
## whatever `i` was, which was harmless only while every caller happened to pass 0 — a row written
## tomorrow with `_island(1)` would have measured island 0 and passed for the wrong reason, silently.
## **There is one island, so there is no index.** ⚠ **The same defect ate `_fresh(g: Grid)` before it**:
## that one took a grid and built island 0 internally regardless. **A parameter nothing reads is a lie
## about what a fixture is measuring**, and this file has now been bitten by it twice.
## ⚠ It reads `load_into` rather than `load_rows`: a grid loaded without its tier board comes up flat,
## draws, plays, and says nothing.
func _island() -> Grid:
	var g := Grid.new()
	Islands.load_into(g)
	return g


## A fresh `Battle` on the island with the starting force. **A new `Army` every time** — the refusal
## rows board and un-board bodies, and a shared roster would let one arm's state leak into the next.
func _fresh() -> Battle:
	var b := Battle.new()
	var army := Army.new()
	army.add_starting_force()
	b.setup(_island(), army, Islands.spawns())
	return b


## The same fixture with **one wolf standing on the island**, for the two rows that actually run the
## sim.
##
## ⚠⚠ **AN EMPTY ISLAND IS ALREADY WON, AND THAT FREEZES `step`.** `_phase_clock` asks 「are the enemies
## gone?」 before anything else, and **the board the user drew carries no spawn character at all** — so
## the first sub-step after a commit latches `Outcome.WON` and `step` breaks out of its sub-step loop
## for good. A boat would never sail, never land and never turn round, and every row driving frames
## would be reading a fight that stopped before it started.
## ⚠ **Only the rows that call `step` use this.** The refusal and band rows never turn a frame, so
## giving them an enemy would be a fixture detail nothing measures.
func _fresh_with_a_beast() -> Battle:
	var b := Battle.new()
	var army := Army.new()
	army.add_starting_force()
	var g := _island()
	b.setup(g, army, [{"type_id": Rules.WOLF, "tile": g.tile_index(5, 10)}])
	return b


func _band_tiles(g: Grid) -> PackedInt32Array:
	var out := PackedInt32Array()
	for tile in g.w * g.h:
		if g.can_summon_at(tile):
			out.append(tile)
	return out


## Every tile a boat can beach on: **passable, and touching water on any of eight sides.**
##
## ⚠⚠ **IT WAS `_sendable_union` AND IT ASKED THE HARBOURS** — every tile SOME harbour could land on,
## looped over `can_land_at`. **That whole table is deleted**, and this is the same set written the way
## `_summon_field`'s own seed loop writes it. ⚠ On every island this repo has shipped the two answered
## tile for tile (84 / 76 / 82 there, 72 here), which is why the swap costs nothing — **but it is the
## definition that survived, not the numbers**: 8-way and not 4-way, which is the user's 「어디든지」.
func _coastal_tiles(g: Grid) -> PackedInt32Array:
	var out := PackedInt32Array()
	for tile in g.w * g.h:
		if g.passable[tile] != 0 and _touches_water(g, tile):
			out.append(tile)
	return out


## Is `tile` one of the board's `H` characters? Used by `_the_boat_has_no_harbour`, whose fixture must
## press a sea tile that is NOT one — this island's harbour ring is its whole border and part of the
## band sits on it.
func _is_harbour(g: Grid, tile: int) -> bool:
	for raw in g.harbour_tiles:
		if int(raw) == tile:
			return true
	return false


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
