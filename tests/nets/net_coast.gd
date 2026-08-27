extends RefCounted
## The COASTLINE rules of `grid.gd` that are still alive: the 8-way shore, the cliff/ramp wall, and
## the diagonal-squeeze guard a hull may not cross. Hand-built fixtures only; nothing here reads a
## real island (`net_islands` owns the real grids).
##
## ⚠⚠ **THIS FILE WAS THE HARBOUR SYSTEM'S NET AND MOST OF IT IS DELETED, NOT REWRITTEN TO PASS.**
## It used to drive `can_land_at`, `water_route`, `home_harbour_for`, `start_harbour`, `sendable` and
## `water_fields` — every one of which died with the drag that fed `Battle.send`. **Rewriting checks
## whose subject no longer exists is how a suite comes to measure a rule nobody implements**, so what
## is gone is recorded in the block above `_deleted_names_are_really_gone` and nowhere else, and that
## check is what proves the deletion actually happened.
##
## ⚠⚠ **WHAT SURVIVED, AND WHY IT WAS WORTH THE REWRITE:** `_water_step_open` and `_smooth_water_path`
## are called by the SUMMON path (`_summon_field`, `summon_route`), so the squeeze guard and the shore
## rules are still live code. The checks below were re-aimed at the summon field — the only water field
## the grid builds now — rather than deleted with the harbour that used to ask them.
##
## ⚠ **Every fixture below is small enough to verify BY HAND**, and that is deliberate: the deleted
## half of this file used hand-picked coordinates for a flood fill on 12x5 and 14x11 boards, each one
## "verified outside Godot with an independent re-implementation" because that is exactly the kind of
## thing that looks right and isn't. Each fixture's comment still names the mutation that must redden
## its check.


func run(t) -> void:
	_a_corner_is_a_shore(t)
	_a_diagonal_squeeze_is_not_a_sail(t)
	_cliff_and_ramp(t)
	_no_harbour_island_still_builds_its_water(t)
	_deleted_names_are_really_gone(t)


## ⚠⚠ **A tile touching water only at a CORNER is a shore, and this is the user's own line.** The rule
## before it said a corner did not count ("coming ashore there reads as landing on the rock beside
## it"); the user threw that out — *"내가 어디든지 상륙할 수 있게 해달라고 했는데"* — and on the three
## real islands the exact difference is **82 -> 84 and 80 -> 82 tiles** (`net_islands` pins both).
##
## ⚠ **The rule now lives in `_summon_field`'s seed loop**, written the other way round from the coast
## table it replaced: for each WATER tile, its passable 8-neighbours. It used to live in the deleted
## `_entry_water_tile`, which walked the same eight offsets from the LAND side. Same set, one owner.
##
## The fixture is one land tile in an open sea, so every water tile that touches it has it as its ONLY
## passable neighbour and the tie-break cannot hide the answer. `(1,1)` touches `(2,2)` at a corner and
## nowhere else — both tiles between them are water, which is asserted rather than assumed.
func _a_corner_is_a_shore(t) -> void:
	var rows := [
		"~~~~~",
		"~~~~~",
		"~~.~~",
		"~~~~~",
		"~~~~~",
	]
	var g := Grid.new()
	g.load_rows(rows)
	var land := g.tile_index(2, 2)
	t.eq(int(g.passable[land]), 1, "(2,2)만 땅이다 (자가 점검)")

	# The self-check that makes the corner claim mean something: (1,1) really has no ORTHOGONAL land
	# neighbour, so a 4-way seed loop would give it no landing at all.
	var corner := g.tile_index(1, 1)
	t.eq(int(g.water[corner]), 1, "(1,1)은 물이다 (자가 점검)")
	t.eq(int(g.water[g.tile_index(1, 2)]), 1, "(1,1)과 (2,2) 사이의 (1,2)는 물이다 (자가 점검)")
	t.eq(int(g.water[g.tile_index(2, 1)]), 1, "다른 쪽 (2,1)도 물이다 — (1,1)은 대각선으로만 땅에 닿는다 (자가 점검)")

	# The floor: the ORTHOGONAL neighbour finds the same shore. Without it, "the corner found it" could
	# be true on a grid where the seed loop found nothing at all and both answers were -1.
	var ortho := g.tile_index(2, 1)
	t.eq(g.summon_landing_of(ortho), land,
		"직교로 닿은 (2,1)에서 온 배는 (2,2)에 내린다 (자가 점검 — 씨앗 루프가 실제로 돌았다)")
	t.eq(g.summon_landing_of(corner), land,
		"대각선으로만 닿은 (1,1)에서 온 배도 (2,2)에 내린다 — " +
		"grid.gd 의 _summon_field 씨앗 루프를 4방향으로 바꾸면 -1 이 되어 문다")
	t.eq(int(g.summon_hops[corner]), 1,
		"그 칸은 해안에서 1홉이다 — 씨앗 층은 0이 아니라 1이다")


## ⚠⚠ **A boat must not slip between two land corners that touch.** A water traversal that walks
## `NEIGHBOURS` on the water byte alone accepts a DIAGONAL step from water to water with land on BOTH
## shoulders — the hull crosses a seam that has no water in it. `_water_step_open` is the guard, and
## `_summon_field` and `summon_route` are the two traversals that ask it today.
##
## The fixture is built so the squeeze is the ONLY thing joining two water bodies: pool A is
## `(4,1)H (5,1) (4,2) (5,2)`, pool B is `(3,3) (2,3) (2,4)`, and they touch nowhere except the
## diagonal `(4,2) <-> (3,3)`, whose two shoulders `(3,2)` and `(4,3)` are both land.
##
## ⚠ **The shipped maps cannot fail this** — measured 0 squeezes on all three — so the old rule is
## re-implemented HERE as an unguarded 8-way flood fill and the two answers are made to disagree.
## Without that half, "the step is refused" would also be what a fixture with no squeeze in it says,
## and the check would be measuring nothing.
##
## ⚠⚠ **THIS CHECK DROPPED ONE LAYER WHEN THE HARBOUR DIED, AND THAT IS WRITTEN DOWN RATHER THAN
## HIDDEN.** It used to drive `can_land_at` and `water_route` on this fixture — a ROUTE-level claim,
## "no step of the sailed polyline squeezes" — and both are deleted. It now asks the predicate itself.
## **The guard has to be in TWO places and only one of them is measured here**: `_summon_field` and
## `summon_route` must each call it, and a `summon_route` fixture that reproduces this squeeze inside
## the summon band (`Rules.SUMMON_BAND_MIN_TILES` from any shore, inside `summon_radius()`) is what
## would raise it back. That fixture does not exist yet, and no green in this file claims it does.
##
## ⚠ `net_boat`'s water check cannot see this defect and never could: it rounds the hull to a tile
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

	# The squeeze itself, asserted rather than assumed: two water tiles a diagonal apart with land on
	# both shoulders. If a later edit to these rows loses that shape, this check stops measuring a
	# squeeze and would go on printing green about one.
	var a := g.tile_index(4, 2)
	var bpool := g.tile_index(3, 3)
	t.eq(int(g.water[a]), 1, "(4,2)는 물이다 (자가 점검)")
	t.eq(int(g.water[bpool]), 1, "(3,3)도 물이다 (자가 점검)")
	t.eq(int(g.water[g.tile_index(3, 2)]), 0, "그 대각선의 어깨 (3,2)는 물이 아니다 (자가 점검)")
	t.eq(int(g.water[g.tile_index(4, 3)]), 0, "다른 어깨 (4,3)도 물이 아니다 (자가 점검)")

	# The old rule, re-implemented here. It joins the two pools; the shipped rule must not.
	var loose := _unguarded_water_reach(g, g.tile_index(4, 1))
	t.ok(loose.has(bpool),
		"옛 규칙(어깨를 안 보는 8방향)이라면 (4,1)에서 (3,3)까지 갔다 — 이 검사가 잴 게 있다는 뜻이다")
	t.ok(loose.has(g.tile_index(2, 4)),
		"옛 규칙이라면 건너편 웅덩이 끝 (2,4)까지 닿았다 (자가 점검)")

	t.ok(not g._water_step_open(4, 2, 3, 3),
		"배는 (4,2)에서 (3,3)으로 못 건넌다 — 땅 모서리 둘 사이에는 물이 없다")
	t.ok(not g._water_step_open(3, 3, 4, 2),
		"반대 방향도 똑같이 막힌다 — 어깨 규칙은 방향을 안 탄다")

	# The ceiling under it: the guard refuses the seam and not the sea. A guard that refused every
	# diagonal would pass the two rows above.
	t.ok(g._water_step_open(4, 1, 5, 2),
		"어깨 한쪽((5,1))이 물인 대각선은 그대로 건넌다 — 대각선 전체를 막은 게 아니다")
	t.ok(g._water_step_open(4, 1, 4, 2),
		"직교 걸음은 언제나 건넌다")


## A cliff row (`^`) between open water and the land behind it. **Two different refusals, and the
## fixture separates them**: the cliff tile is impassable, so it can never be anybody's landing; the
## land behind it has no water neighbour at all, so nothing reaches that either. A ramp (`/`) cut into
## the same wall is passable AND touches water, so a boat lands on it — while the land behind the ramp
## still does not, because **a doorway is not a shore**.
##
## ⚠ The cliff half alone would be a floorless green: when nothing lands anywhere, "nothing lands on
## the cliff" is free. **The ramp fixture IS the floor** — the same wall with one character changed,
## and now there is a landing. Read the two together or neither means anything.
func _cliff_and_ramp(t) -> void:
	var cliff_rows := [
		"~~~H~~~~",
		"^^^^^^^^",
		"........",
	]
	var cg := Grid.new()
	cg.load_rows(cliff_rows)
	var cliff := cg.tile_index(3, 1)
	var behind := cg.tile_index(3, 2)
	t.eq(int(cg.passable[cliff]), 0, "절벽 칸은 지나갈 수 없다")
	t.eq(int(cg.passable[behind]), 1, "절벽 뒤는 땅이다 (자가 점검)")
	t.eq(_landings_of(cg).size(), 0,
		"절벽만 있는 해안에는 배가 내릴 곳이 하나도 없다 — grid.gd 의 land_chars() 에 '^' 를 넣으면 문다")

	var ramp_rows := [
		"~~~H~~~~",
		"^^^/^^^^",
		"........",
	]
	var rg := Grid.new()
	rg.load_rows(ramp_rows)
	var ramp := rg.tile_index(3, 1)
	var behind_ramp := rg.tile_index(3, 2)
	t.eq(int(rg.passable[ramp]), 1, "램프는 걸을 수 있다")
	var spots := _landings_of(rg)
	t.eq(spots, [ramp],
		"같은 벽에 '/' 하나를 뚫으면 배가 내릴 곳이 딱 그 램프 하나 생긴다 — " +
		"grid.gd 의 BARE_LAND_CHARS 에서 '/' 를 빼면 다시 0개가 되어 문다")
	t.ok(not spots.has(behind_ramp),
		"램프 뒤 땅에는 여전히 못 내린다 — 문은 해안이 아니다 (천장)")
	t.eq(rg.summon_landing_of(rg.tile_index(3, 0)), ramp,
		"램프 바로 앞 물에서 온 배는 그 램프로 간다")


## An island authored with no `H` at all must be a defined no-op, not a bark.
##
## ⚠⚠ **THIS IS THE SWAP ITSELF, MEASURED: A BOARD NEEDS NO HARBOUR TO HAVE BOATS.** The check it
## replaces asserted `start_harbour == -1`, `sendable` empty and `water_fields` empty — the whole
## harbour system's graceful-nothing — and every one of those is deleted. What is left is the one claim
## that still matters: **`harbour_tiles` is empty and the summon field is built anyway**, exactly once.
##
## ⚠ `summon_field_builds` is asserted as **1** and not `> 0`. A count that only has to be positive is
## a row that survives its own subject being called per frame, which is the cost this whole field
## exists to avoid — its sibling counter `water_field_builds` carried the same rule and the deletion
## block in `grid.gd` records why. `net_summon` owns the per-frame half of it.
func _no_harbour_island_still_builds_its_water(t) -> void:
	var rows := [
		"~~~~~",
		"~...~",
		"~...~",
		"~...~",
		"~~~~~",
	]
	var g := Grid.new()
	g.load_rows(rows)
	t.eq(g.harbour_tiles.size(), 0, "항구가 하나도 없는 섬이다 (자가 점검)")
	t.eq(g.summon_field_builds, 1, "그래도 물 BFS 는 정확히 한 번 돌았다 — 배에는 항구가 필요 없다")
	t.eq(g.summon_hops.size(), g.w * g.h, "물 필드가 판 전체 크기로 깔렸다")
	var spots := _landings_of(g)
	t.ok(spots.size() > 0,
		"항구가 없어도 배가 내릴 해안은 있다 (%d칸) — 항구 없는 섬이 조용히 빈 섬이 되지 않는다"
			% spots.size())


## ⚠⚠ **Every deletion needs a check that the thing is GONE.** A green round after deleting a rule
## proves nothing about the deletion — the checks that drove it were deleted in the same edit, so
## "nothing red" is exactly what a deletion that never happened would also look like.
##
## ⚠⚠ **WHAT THE HARBOUR SYSTEM WAS, AND WHAT IT MEASURED — THE RECORD OF THIS FILE'S OWN DELETION.**
## The player used to DRAG a body onto a boat that departed from a harbour; that drag went, `Battle.send`
## lost its last caller in `src/`, and everything behind it became unreachable. These checks went with
## it, and these are the findings they paid for:
##
##  · `_the_descent_home_never_squeezes` — ⚠⚠ **THE GUARD HAS TO BE IN TWO PLACES AND THE FIELD ALONE
##    IS NOT ENOUGH**, and this is the finding worth more than the check. A route descends its field by
##    taking the cheapest strictly-lower water neighbour, so **a squeezed neighbour that some OTHER
##    path reached cheaply is exactly what the descent prefers** — the field can be perfectly clean and
##    the drawn, sailed route still cuts the seam. Fixture: harbour arm east to `(2,1)` at hop **1**,
##    landing `(4,1)` whose only water neighbour `(3,2)` sits at hop **5** the long way round; the two
##    are a diagonal apart with land on both shoulders. Unguarded descent: **4 points**, cutting the
##    seam. Guarded: **6 points** (7 before the smoother) the whole way round. ⇒ **`summon_route` is
##    the surviving descent and this property of it is UNMEASURED today.**
##
##  · `_every_waypoint_of_a_route_is_water` — 「배가 도착했다」는 「배가 물 위로 갔다」가 아니다. The
##    endpoint alone cannot tell a polyline from the straight line it replaced, so it walked every
##    point. On the peninsula fixture the raw descent was 8 points,
##    `[(2,4),(3,3),(4,3),(5,4),(6,3),(7,3),(8,3),(9,2)]`, the dip to `(5,4)` being the boat going
##    AROUND the `#` at `(5,3)`. Its floor was `route.size() >= 3`: **a two-point path IS the straight
##    line the whole change existed to replace.**
##
##  · `_a_route_goes_around_the_headland` — ⚠⚠ **A FAKE GREEN THIS REPO ACTUALLY SHIPPED.** The check
##    was `length > straight + 0.5`, and when the route smoother landed that slack became a liability:
##    route **8.6569** over 8 points became **7.576491** over 4, against an unchanged straight line of
##    **7.280110** — a margin of **0.296**, so the fuzzy `+ 0.5` reads as "the detour is gone" when the
##    detour is exactly what is still there. **Replacing the slack with literals was the fix**, and it
##    is a stronger claim: a smoother that pulled the route through the `#` lands on 7.280110 and one
##    that did nothing lands on 8.6569.
##
##  · `_a_route_walks_the_field_down_one_step_at_a_time` — it demanded "the field value at point k is
##    exactly k" and "Chebyshev 1 between neighbours", **both of which the smoother makes false on
##    purpose** because string-pulling deletes waypoints. ⚠ **Rewriting it to pass would have been the
##    wrong move and so would deleting it**: what it really guarded is that the walk terminates, never
##    loops and never leaves the water, which survived as (1) starts at field value 0, (2) field values
##    are STRICTLY INCREASING along the kept points — a subsequence of a strict descent, so a loop still
##    breaks it — and (3) **every segment sampled by an INDEPENDENT walker** rather than by calling back
##    into `grid`: the smoother's own predicate deciding whether the smoother was right is not a check.
##
##  · `_home_harbour_is_the_shortest_WATER_route` — 돌아갈 항구는 물길이 가장 짧은 항구다, 직선으로 제일
##    가까운 쪽이 아니다. Fixture: a land bar between an enclosed bay and the open sea, joining only at
##    the bar's end. For the beach at `(2,3)` — sea harbour: straight **8.544**, **7 hops**; bay
##    harbour: straight **3.000**, **24 hops**. ⚠ **The self-check that made it discriminating was a
##    straight-line ranking computed in the net itself**, proving the two rules really disagree on this
##    fixture; without it the row could be green because both answers happened to agree.
##
##  · `_start_harbour_is_neither_first_nor_last` — ⚠⚠ **`net_islands` alone could NEVER have caught
##    `start_harbour = 0` or `= size() - 1` as a stand-in for the rule, because the start harbour
##    happens to be the LAST harbour on all three shipped islands.** That is the shape of the finding
##    and it outlives the rule: **a check against real data cannot tell a rule from a coincidence of
##    that data, and only a fixture built to break the tie can.**
##
##  · `_a_lagoon_harbour_cannot_see_the_open_shore` — ⚠⚠ **the fixture BEFORE it went green while
##    measuring nothing.** It used a `#` peninsula blocking a STRAIGHT line; once routes became
##    8-connected a boat sails around any peninsula, so both harbours reached both shores and the check
##    passed for the wrong reason. **What still separates two water origins is genuinely DISCONNECTED
##    water** — an inner lake, land two tiles thick on every side INCLUDING the diagonals. Its floor was
##    the water census: 93 water tiles total, lake reach **12**, sea reach **81**, and 12 + 81 = 93 is
##    what proved the two bodies shared not one tile and the lake was not leaking through a diagonal gap.
##
##  · `_water_fields_are_built_once` — the load-time-not-frame-time guarantee, now carried whole by
##    `summon_field_builds`. Its floor was `builds > 0`, because **`t.eq(builds, harbour_tiles.size())`
##    is trivially true as `0 == 0` on a board with no harbour** — the exact shape that turns an emptied
##    table into a green.
func _deleted_names_are_really_gone(t) -> void:
	var g := Grid.new()
	g.load_rows(["~~~", "~H~", "~.~"])

	t.ok(not g.has_method("can_land_at"),
		"grid 에 can_land_at 이 없다 — 항구별 상륙 허용표가 통째로 사라졌다")
	t.ok(not g.has_method("water_route"),
		"grid 에 water_route 도 없다 — 항구에서 해안까지의 항로는 아무도 안 묻는다")
	t.ok(not g.has_method("home_harbour_for"),
		"grid 에 home_harbour_for 도 없다 — 돌아갈 항구를 고르던 규칙이다")
	t.ok(not g.has_method("water_line_clear"),
		"grid 에 water_line_clear 도 없다 — 그 전 세대의 직선 항로 검사다")

	# The two that must NOT have died with it: the summon path calls both.
	t.ok(g.has_method("_water_step_open"),
		"대각선 끼임 규칙은 그대로 있다 — 소환 물 필드와 소환 항로가 둘 다 부른다")
	t.ok(g.has_method("_smooth_water_path"),
		"항로 다듬기도 그대로 있다 — 소환 항로가 부른다")
	t.ok(g.has_method("summon_route"), "그리고 소환 항로 자체가 있다 (자가 점검)")

	var props: Array = []
	for raw in g.get_property_list():
		props.append(str((raw as Dictionary)["name"]))
	t.ok(not props.has("landable"), "grid 에 landable 필드가 없다 — 8방향 해안이 그 자리를 대신한다")
	t.ok(not props.has("line_tests"), "grid 에 line_tests 도 없다 — 직선 표본 횟수를 세던 계기다")
	t.ok(not props.has("sendable"),
		"grid 에 sendable 도 없다 — 항구마다 깔던 상륙 허용표가 사라졌다")
	t.ok(not props.has("water_fields"),
		"grid 에 water_fields 도 없다 — 항구 하나에 물 필드 하나씩 깔던 배열이다")
	t.ok(not props.has("water_field_builds"),
		"grid 에 water_field_builds 도 없다 — summon_field_builds 가 그 보증을 통째로 물려받았다")
	t.ok(not props.has("start_harbour"),
		"grid 에 start_harbour 도 없다 — 함대가 어느 항구에서 시작할지 고르는 사람이 없다")

	# The survivor, and it is deliberate: nothing in `src/` reads it, but it is the only record of
	# where an `H` sits on the board and three other nets walk it.
	t.ok(props.has("harbour_tiles"),
		"harbour_tiles 는 남아 있다 — 판 위의 H 가 어디 있는지 아는 유일한 자리다")
	t.eq(g.harbour_tiles.size(), 1, "그리고 실제로 채워진다 (자가 점검 — 빈 배열이라 통과한 게 아니다)")
	t.ok(props.has("summon_hops"), "summon_hops 도 있다 (자가 점검 — 속성 목록을 실제로 읽고 있다)")
	t.ok(props.has("summon_field_builds"), "summon_field_builds 도 있다 (자가 점검)")

	var b := Battle.new()
	t.ok(not b.has_method("send"),
		"battle 에 send 가 없다 — 몸을 배에 끌어다 놓던 그 호출이다")
	t.ok(not b.has_method("harbour_count"),
		"battle 에 harbour_count 도 없다 — grid 로 넘기기만 하던 껍데기였다")
	t.ok(not b.has_method("harbour_tile"), "battle 에 harbour_tile 도 없다")
	t.ok(b.has_method("summon"), "대신 summon 이 있다 (자가 점검 — 배는 여전히 존재한다)")
	t.ok(b.has_method("commit"), "commit 도 그대로다 (자가 점검)")

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


# --- helpers -------------------------------------------------------------------------------------

## 8-way flood fill over water from `seed`, with NO shoulder rule — **the rule as it was before the
## guard landed.** It exists so the squeeze check can show the two answers differ; the shipped grids
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


## Every LAND tile some water tile would beach on, ascending, without duplicates. **The shore of this
## board as the sim actually sees it** — read off `summon_landing` rather than recomputed from the
## rows, because a helper that re-derived the coast here would be a second copy of the rule under test.
##
## ⚠ **`_squeeze_steps` used to live beside this and is deleted.** It walked a route and named every
## step that was a diagonal between two water tiles with land on both shoulders, skipping the final
## beaching pair (the landing is land by construction — the same exemption `_water_step_open` states in
## its own comment). It died because both routes it was ever handed came out of `water_route`.
## ⚠⚠ **It also carried a trap worth keeping: `_squeeze_steps(route).size() == 0` is TRIVIALLY TRUE on
## an EMPTY route**, so every caller had to floor it with a `route.size()` assertion first. Any
## "count the bad ones and expect zero" helper has that shape.
func _landings_of(g: Grid) -> Array:
	var seen := {}
	for tile in g.summon_landing.size():
		var land := int(g.summon_landing[tile])
		if land >= 0:
			seen[land] = true
	var out: Array = seen.keys()
	out.sort()
	return out
