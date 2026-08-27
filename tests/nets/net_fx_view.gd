extends RefCounted
## The VIEW half of the twelve combat effects, rewritten for the 3D field (ticket 09, step 4). The
## sim half — what `Battle` puts in `events` — is `net_fx`'s; this file injects those facts into a
## real `FieldView`, calls `_process` by hand, and reads the surfaces the seam now names:
##
##   surface 2 — the pooled `Sprite3D` fields the engine consumes (position · modulate · scale),
##               where the body-bound effects live: flash, lunge, knockback, gait squash
##   surface 3 — the fx buffers `_g_v`/`_g_c` (ground) and `_a_v`/`_a_c` (air) after `_process`,
##               plus each layer's `mesh.get_surface_count()` — buffers prove geometry was BUILT,
##               the surface count proves `_fx_flush` COMMITTED it, and only the pair closes the
##               hole where deleting the flush stays green
##
## **Every transient is measured on the five axes the plan names**: which layer it lands in (and
## that the OTHER buffer stayed empty) · its vertex count as a hand literal · its position and
## EXTENT (a ring collapsed to radius 0 keeps the right centre and dies on the extent) · its colour
## with the fade's floor and ceiling in one equality · and ground marks follow the ground while air
## marks stand in the camera's plane, turns included.
##
## ⚠ **The exact vertex counts ARE the duty rows**: one event's floor (the mark exists, 「연출은
## 과할 정도로」's own number) and its ceiling (it does not cover the screen) in a single equality.
##
## ⚠ **Ages are injected as `<SEC constant> * 0.5`** so the fade is exactly 0.5 whatever the
## constant holds — `x * 0.5 / x` is exact in floats — and the expected colour can be compared
## outright instead of through a tolerance wide enough to hide a wrong fade.
##
## Fixtures are ARENA-small (24 x 12, and a 7 x 5 palm for the terrain rows): `setup()` rebuilds the
## whole terrain mesh, and a real island per row is what made an old net spin for 24 s unnoticed.


const ARENA_W := 24
const ARENA_H := 12

## Every `FieldView` built here, freed at the end — a `Node2D` left unfreed is a leaked RID on
## stderr, which the wrapper reads as failure.
var _created: Array = []


func run(t) -> void:
	_the_terrain_speaks_the_legend(t)
	_a_tier_boundary_is_a_wall(t)
	_the_hills_never_swallow_the_tier(t)
	_no_body_is_taller_than_the_wall_behind_it(t)
	_the_first_island_opens_with_room_around_it(t)
	_every_body_effect_is_sized_off_the_picture(t)
	_a_body_that_cannot_move_still_does_something(t)
	_the_landing_ring(t)
	_the_area_ring_follows_the_ground(t)
	_the_refusal_mark(t)
	_the_intent_line(t)
	_the_tracer(t)
	_the_spark(t)
	_the_death_burst_stands_in_the_camera_plane(t)
	_the_hit_halo(t)
	_body_effects_ride_the_pooled_fields(t)
	_the_boat_route_shrinks_with_the_sim(t)
	_a_dry_slot_draws_no_plan(t)
	_the_transient_drawer_is_capped(t)
	_the_readers_themselves(t)
	_every_row_wears_its_own_picture(t)
	_only_the_wolf_has_frames_and_they_share_one_canvas(t)
	_the_legs_run_on_time_not_on_distance(t)
	_the_bite_rides_the_blow_that_lunges(t)
	_a_bleeding_body_is_a_different_colour(t)
	for raw in _created:
		var fv: FieldView = raw
		fv.free()
	_created = []


# == the terrain, on a palm-sized island (verify-read A) ==============================================
## Steps 1-3 left the terrain with existence checks only — faces exist, the sea is visible — so the
## LEGEND -> COLOUR mapping could collapse to one tone and the cliff could lose its seaward wall with
## the round green. Both get hand-counted rows on a fixture small enough to count by hand:
##
##   "~~~~~~~"      cliff (1,1) stands against water on its west and north — the sea-wall subject
##   "~^.#..~"      hole (3,1) — the lowest thing on the island, nothing skirts DOWN from it
##   "~..^/.~"      inland cliff (3,2) with its ramp (4,2) — the ramp JOINS both sides, so it
##   "~.....~"      contributes exactly its own top face and no skirt
##   "~~~~~~~"
##
## A top face is 2 triangles = **6 vertices wearing the tile's own colour**; a skirt wears that
## colour `darkened(0.15)`. HOLE / CLIFF / RAMP are the three kinds whose colour is EXACTLY
## `terrain_colour_of_char` (only LAND is height-tinted and shore-blended), so their counts are
## closed hand literals: 6 · 12 (two cliffs) · 6.
func _the_terrain_speaks_the_legend(t) -> void:
	var rows := [
		"~~~~~~~",
		"~^.#..~",
		"~..^/.~",
		"~.....~",
		"~~~~~~~",
	]
	var b := _battle_of(rows, _army_of([]), [])
	var fv := _view_of(b, rows)
	var arrays: Array = (fv._terrain.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	t.ok(verts.size() > 0 and cols.size() == verts.size(), "지형 메시에 정점과 색이 같이 들어 있다 (자가 점검)")

	# The legend -> colour mapping, one closed count per untinted kind. A mapping collapsed to one
	# tone moves every one of these counts at once.
	var hole := _mesh_verts_of(verts, cols, Look.COL_HOLE)
	t.eq(hole.size(), 6, "구덩이 색 정점이 정확히 6개다 — # 한 칸의 윗면 두 삼각형")
	t.ok(_all_inside_tile(hole, 3, 1), "그리고 전부 (3,1) 칸 안이다 — 색이 자리까지 맞다")
	var cliff := _mesh_verts_of(verts, cols, Look.COL_CLIFF)
	t.eq(cliff.size(), 12, "절벽 색 정점이 정확히 12개다 — ^ 두 칸의 윗면")
	var cliff_stray := 0
	for v: Vector3 in cliff:
		if not (_inside_tile(v, 1, 1) or _inside_tile(v, 3, 2)):
			cliff_stray += 1
	t.eq(cliff_stray, 0, "절벽 정점이 두 절벽 칸 밖으로 안 샌다")
	var ramp := _mesh_verts_of(verts, cols, Look.COL_RAMP)
	t.eq(ramp.size(), 6, "경사로 제 색 정점이 정확히 6개다 — 윗면 두 삼각형 (스커트는 어두워져 딴 색이다)")
	t.ok(_all_inside_tile(ramp, 4, 2), "그리고 전부 (4,2) 칸 안이다")
	t.eq(_mesh_verts_of(verts, cols, Look.COL_WATER).size(), 0,
		"물색 정점은 0개다 — 바다는 지형 메시가 아니라 자기 판이 그린다")

	# The cliff's SEA-SIDE wall (the skirt): cliff (1,1) faces open water west and north, so its
	# darkened wall must reach DOWN to the sea (~0.10, water height minus the pad) — flip `_skirt`'s
	# lower-neighbour test on the water side and the wall stops under the land line (~0.95+) instead.
	var wall := _mesh_verts_of(verts, cols, Look.COL_CLIFF.darkened(0.15))
	t.ok(wall.size() >= 12, "절벽의 스커트 벽 정점이 있다 (%d개)" % wall.size())
	var wall_min := 1e9
	var wall_max := -1e9
	for v: Vector3 in wall:
		wall_min = minf(wall_min, v.y)
		wall_max = maxf(wall_max, v.y)
	t.ok(wall_min < 0.4, "그 벽이 바다까지 내려간다 (min y %.2f) — 물 쪽 벽을 빼면 1.0 근처에서 멈춘다" % wall_min)
	t.ok(wall_max > 2.0, "그리고 절벽 꼭대기에서 시작한다 (max y %.2f)" % wall_max)


## 티켓 19 — **the tier boundary, on a board small enough to count by hand.** Land is x 1..7, y 1..5;
## a 3 x 3 plateau sits at x 4..6, y 2..4, strictly inland, with one stair at (3,3).
##
## ⚠⚠ **THE MEASUREMENT IS A CLOSED VERTEX COUNT AND IT NEEDED A CONTROL TO BE ONE.** On this fixture
## the FLAT board emits **no skirt at all**: land joins land and land joins water, so every shared
## corner is one averaged height and `_skirt` returns before emitting. 35 land tiles x 6 = **210**, and
## that is the whole flat mesh. Give it a tier board and **14 walls** appear — 84 vertices, so **294**.
##
## ⚠⚠ **THE FIRST DERIVATION OF THAT 14 SAID 11, AND THE THREE IT MISSED ARE THE INTERESTING ONES.**
## A skirt is not emitted where two tiles fail to JOIN; it is emitted wherever the neighbour's two
## shared-edge corners sit LOWER. Those are different questions, because a corner is the average of
## the tiles around it that join THIS tile — so two tiles can join each other and still disagree about
## a corner they share, when one of them has a high neighbour the other is walled off from:
##
##   · **11** — plateau meeting low ground across a boundary it does not join (2 west, 3 north,
##     3 south, 3 east). These are the cube's own faces
##   · **1** — plateau (4,3) stepping down onto the stair. They JOIN — the stair is a real diagonal —
##     but the plateau's corner there averages plateau tiles the stair's corner also averages low ones
##     with, so the tread has a riser above it. That is what a step is
##   · **2** — the stair's own north and south sides. Same cause one level down: the stair's corners
##     reach up into the plateau and its low neighbours' corners do not
##
## ⇒ **A stair comes out as a tread with three risers around it**, and that is the picture wanted.
## Both numbers are floors AND ceilings: lose the tier test in `_tiles_join` and the count falls to
## 210; wall an edge that should be a slope and it rises past 294.
##
## ⚠⚠ **AND THE PLATEAU'S TOP STILL ROLLS.** 2026-08-24's tile-per-box terrain died on 「너무 딱딱해서
## 재미가 없을까?」, and a plateau whose top is one flat slab is that verdict coming back. The spread of
## the plateau's own top vertices is bounded AWAY FROM ZERO for that reason — a ceiling with no floor
## would pass a plateau with the hills switched off.
func _a_tier_boundary_is_a_wall(t) -> void:
	var rows := [
		"~~~~~~~~~",
		"~.......~",
		"~.......~",
		"~.......~",
		"~.......~",
		"~.......~",
		"~~~~~~~~~",
	]
	var tiers := [
		".........",
		".........",
		"....111..",
		".../111..",
		"....111..",
		".........",
		".........",
	]
	var flat := _view_of(_battle_of(rows, _army_of([]), []), rows)
	var g := Grid.new()
	g.load_rows(rows, tiers)
	var b := Battle.new()
	b.setup(g, _army_of([]), [])
	b._committed = true
	var fv := _view_of(b, rows)

	var flat_verts: PackedVector3Array = (flat._terrain.mesh as ArrayMesh) \
		.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var arrays: Array = (fv._terrain.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	t.eq(flat_verts.size(), 210,
		"평지 대조군의 지형 메시는 정점 210개다 — 땅 35칸 x 6, 스커트 0개")
	t.eq(verts.size(), 294,
		"단 판을 얹으면 294개다 — 벽 열넷 x 6. 고원 면 열하나에 계단의 디딤 하나와 옆면 둘이다")

	# The plateau really stands one tier up, measured on its own centre tile — every corner of (5,3)
	# averages plateau tiles only, so the lift is exact rather than blurred by the join.
	t.ok(absf((fv._ground_h(5, 3) - flat._ground_h(5, 3)) - Rules.TIER_RISE_TILES) < 1e-4,
		"고원 한가운데가 평지판보다 정확히 한 층(%.2f 타일) 높다" % Rules.TIER_RISE_TILES)

	# ⚠⚠ **THE FLOOR UNDER 「윗면이 계속 언덕이다」.** 2026-08-24's tile-per-box terrain died on
	# 「너무 딱딱해서 재미가 없을까?」, and a plateau whose top is one flat slab is that verdict coming
	# back one tier up. Bounded at BOTH ends: the spread must not be zero (the hills are switched off)
	# and must not exceed the hill amplitude (the tier has leaked into the top surface).
	#
	# ⚠ **Read off three plateau tiles' own ground heights, NOT off a window of mesh vertices.** A
	# window was tried and it leaked: `HILL_AMP_TILES` is 2.60 and a tier is 2.00, so **low ground next
	# to the plateau reaches higher than the plateau's own foot** and no height band separates the two.
	# That is worth keeping written down — it is also why the picture needs a wall and a colour rather
	# than height alone to say which surface a tile is on.
	var tops := [fv._ground_h(4, 2), fv._ground_h(5, 3), fv._ground_h(6, 4)]
	var top_min := 1e9
	var top_max := -1e9
	for raw in tops:
		top_min = minf(top_min, float(raw))
		top_max = maxf(top_max, float(raw))
	t.ok(top_max - top_min > 0.05,
		"고원 윗면의 높이가 하나가 아니다 (%.3f 타일 차) — 평평하면 8월 24일의 「너무 딱딱하다」로 돌아간 것이다"
			% (top_max - top_min))
	t.ok(top_max - top_min < Look.HILL_AMP_TILES + 0.001,
		"그리고 언덕 진폭을 안 넘는다 — 층 높이가 윗면 안으로 새어 들어오지 않는다")

	# The stair wears its own colour, exactly one tile of it. Sharing `COL_RAMP` would make this row
	# unwritable: the picker is the colour.
	var stair := _mesh_verts_of(verts, cols, Look.COL_STAIR)
	t.eq(stair.size(), 6, "계단 색 정점이 정확히 6개다 — 한 칸의 윗면 두 삼각형")
	t.ok(_all_inside_tile(stair, 3, 3), "그리고 전부 (3,3) 칸 안이다 — 색이 계단 밖으로 안 샌다")
	t.eq(_mesh_verts_of(flat_verts, (flat._terrain.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR],
		Look.COL_STAIR).size(), 0,
		"평지 대조군에는 계단 색이 0개다 — 색이 단에서 나오지 글자에서 나오는 게 아니다")


## ⚠⚠ **`HILL_AMP_TILES` IS 2.60 AND A TIER IS 2.00, AND THAT SOUNDS FATAL. IT IS NOT, AND THE
## DIFFERENCE BETWEEN THE TWO READINGS IS WHAT THIS ROW EXISTS TO HOLD DOWN.**
##
## The amplitude is the swell's range over an INFINITE sample. What a board actually samples is less,
## because one swell is `HILL_CELL_TILES` = 11 tiles wide and no island is many periods across;
## and what an EYE reads is neither of those, it is the LOCAL step. Derived outside Godot from a
## from-scratch re-implementation of `_noise_at` / `_swell_at` at the shipped seed:
##
## | footprint | ground's own span at amp 2.60 | against a 2.00 tier |
## |---|---|---|
## | island 4, 26 x 20 | 1.83 tiles | **+0.17 — the two surfaces do not overlap** |
## | the hand-written islands, 48 x 32 | 1.87 | +0.13 |
## | the long map, 144 x 32 | 2.18 | **−0.18 — there they WOULD overlap** |
##
## And locally the ground moves **0.10 tiles per tile on average, 0.49 at its worst**, against a tier
## step of 2.00. A tier boundary is never anything but a clean step on any board that has one today.
##
## ⚠ **The DRAWN wall is wider than those raw tile heights say, and the row below measures the drawn
## one.** The hand derivation above compares `_tile_h`; what a player sees is `_ground_h`, the average
## of four corners, and at a seam each side averages only its own tier — so the two surfaces are
## pulled APART at the boundary. Island 4's raw tile heights differ by 1.83–2.15 across the edges and
## the ground the eye stands on differs by up to **2.73**. The corner rule makes the boundary crisper
## than the naive arithmetic, not softer; the first version of this row carried the naive ceiling and
## went red on the real island, which is how the difference was found.
##
## ⇒ **Nothing was retuned, and this row is what makes that a decision instead of luck.** The margin
## is real but thin (7% of a tier), it is already negative on the 144-wide map, and both ends are
## bounded here so that raising the amplitude, lengthening a map, or shortening a tier reddens rather
## than quietly turning the plateau into another hill.
func _the_hills_never_swallow_the_tier(t) -> void:
	var rows := Islands.rows()
	var tiers := Islands.tiers()
	var g := Grid.new()
	g.load_rows(rows, tiers)
	var b := Battle.new()
	b.setup(g, _army_of([]), [])
	b._committed = true
	var fv := _view_of(b, rows)

	var wall_min := 1e9
	var wall_max := -1e9
	var walls := 0
	# The ground's OWN largest step, between two neighbours on the same tier. This is the yardstick the
	# wall is held against, and it is a different population measured on the same board — not the
	# wall's own extent read back at itself, which would shrink with whatever it was checking.
	var roll_max := 0.0
	var low_top := -1e9
	var high_bottom := 1e9
	for ty in g.h:
		for tx in g.w:
			if g.passable[ty * g.w + tx] == 0:
				continue
			var here := fv._ground_h(tx, ty)
			if g.level_at(tx, ty) == 2:
				high_bottom = minf(high_bottom, here)
			elif g.level_at(tx, ty) == 0:
				low_top = maxf(low_top, here)
			for d in [[0, -1], [0, 1], [-1, 0], [1, 0]]:
				var nx := tx + int(d[0])
				var ny := ty + int(d[1])
				if g.passable[ny * g.w + nx] == 0:
					continue
				var gap := g.level_at(tx, ty) - g.level_at(nx, ny)
				if gap == 0:
					roll_max = maxf(roll_max, absf(here - fv._ground_h(nx, ny)))
					continue
				if gap != 2:
					continue
				walls += 1
				var drop := here - fv._ground_h(nx, ny)
				wall_min = minf(wall_min, drop)
				wall_max = maxf(wall_max, drop)
	# ⚠ **15 and not 31 since the island was drawn by hand** (2026-08-25): the plateau is 4 x 4 with one
	# corner spent on the stair, so its 4-way boundary is 15 edges — counted off the letters, and it is
	# the perimeter shrinking with the slab, not the wall getting shallower. The claim below is what
	# carries the meaning; this row only refuses to let that claim be vacuous.
	t.eq(walls, 15, "첫 섬의 층 경계 모서리는 15개다 (자가 점검, 이 수가 0이면 아래가 전부 공허하다)")

	# ⚠⚠ **THE ONE THAT CARRIES THE CLAIM, AND IT HAS NO MAGIC NUMBER IN IT.** A tier boundary reads as
	# a boundary only if it is unmistakably steeper than the ground's own roll — so the two populations
	# are measured on the same board and compared. Raise the hills far enough and this reddens before
	# anything else does.
	t.ok(wall_min > roll_max,
		"제일 낮은 벽(%.2f)이 그 섬에서 언덕이 만드는 제일 큰 단차(%.2f)보다 가파르다 — 층 경계는 비탈이 아니다"
			% [wall_min, roll_max])
	t.ok(wall_min > Rules.TIER_RISE_TILES * 0.75,
		"그리고 한 층의 3/4 보다 높다 (%.2f 타일) — 언덕이 벽을 못 삼킨다" % wall_min)
	# ⚠ **An ABSOLUTE ceiling and not one scaled off the hills.** A bound that grew with the amplitude
	# could never say "the hills did not inflate this". Two tiers is where a wall starts lying about
	# how many levels the island has.
	t.ok(wall_max < Rules.TIER_RISE_TILES * 2.0,
		"제일 높은 벽도 두 층보다는 낮다 (%.2f 타일) — 벽 하나가 층 둘로 안 읽힌다" % wall_max)
	t.ok(low_top < high_bottom,
		"낮은 땅의 제일 높은 곳(%.2f)이 고원의 제일 낮은 곳(%.2f)보다 낮다 — 여유 %.2f 타일"
			% [low_top, high_bottom, high_bottom - low_top])


## ⚠⚠ **THE BODY SIZE NOW HAS A CEILING IT DID NOT HAVE, AND THE CEILING IS A TIER.**
## 2026-08-25, the user: 「캐릭터 크기 좀 줄이고」 · 「지금 캐릭터가 너무 커. 계속 플래시게임 같은
## 문제가 있거든」. Bodies are camera-facing panels, and a panel is hidden by being small — but there is
## now a second reason, which is 티켓 19's: **a body taller than the wall behind it covers the wall**,
## and the wall is the only thing on screen that says a body is standing a tier up.
##
## At the old 6.0 the tallest drawn body was the shieldbearer at 110 px = **1.37 tiers**. At 3.5 he is
## 64 px = **0.80**. Both ends are bounded here:
##
##   · **ceiling** — no drawn body reaches one tier, so nothing hides a boundary it stands at
##   · **floor** — the wolf is at least one TILE wide. 34 px was measured and rejected by the user
##     twice (「너무 작긴 하거든」, 「멀리서 봤을때 너무작네」), and a bare ceiling would pass bodies
##     shrunk back to it — or to nothing at all
func _no_body_is_taller_than_the_wall_behind_it(t) -> void:
	var fv := _quiet_view()["fv"] as FieldView
	var tier_px := Rules.TIER_RISE_TILES * Look.TILE_PX
	var tallest := 0.0
	var tallest_row := -1
	var drawn := 0
	for ty in Rules.UNITS.size():
		var tex := fv._beast_tex(ty, true)
		if tex == null:
			continue
		drawn += 1
		var rect := fv._beast_rect(Vector2.ZERO, Look.body_radius_of(ty), Vector2.ONE, tex)
		if rect.size.y > tallest:
			tallest = rect.size.y
			tallest_row = ty
	t.eq(drawn, 8, "그림을 가진 종 여덟 줄을 전부 쟀다 (자가 점검 — 0이면 아래가 공허하다)")
	t.ok(tallest < tier_px,
		"제일 큰 몸(%s, %.1fpx)이 한 층(%.0fpx)보다 낮다 — 몸이 제 뒤의 벽을 안 가린다"
			% [Rules.name_of(tallest_row), tallest, tier_px])
	var wolf := fv._beast_rect(Vector2.ZERO, Look.body_radius_of(Rules.WOLF), Vector2.ONE,
		fv._beast_tex(Rules.WOLF, true))
	t.ok(wolf.size.x >= Look.TILE_PX,
		"그래도 늑대는 한 칸(%.0fpx)보다 넓다 (%.1fpx) — 사용자가 두 번 거절한 34px 로 안 돌아간다"
			% [Look.TILE_PX, wolf.size.x])

	# ⚠ **The one constant that did NOT follow the bodies down.** `BURST_WIDTH_PX` is a raw px stroke
	# and its own note sets the rule: past half the crow's start radius the ring closes into a disc.
	# The radius halved with the sprites and the stroke did not, so what was 27% is now 46%. **Legal,
	# with 0.8 px of room** — and held here, so the next cut reddens instead of drawing a disc.
	var crow_start := Look.body_radius_of(Rules.CROW) * Look.BURST_START_MUL
	t.ok(Look.BURST_WIDTH_PX <= crow_start * 0.5,
		"파열 획(%.1fpx)이 까마귀 시작 반지름(%.1fpx)의 절반 안이다 — 넘으면 링이 원반이 된다"
			% [Look.BURST_WIDTH_PX, crow_start])


## 2026-08-25, the user: 「처음 시작할떄 가메라 좀더 뒤에서 시작할 수 있게해줘」. **The opening view is
## derived per island, and the first node's island is the one the request was made about.**
##
## ⚠⚠ **THE OLD OPENING VIEW WAS NOT THE SURVEY'S ANSWER — IT WAS `ZOOM_MAX`.** At the old margin the
## formula wanted 1.07 on a 26 x 20 island and the ceiling took it, so the survey had no say at all.
## That is the first thing bounded here: **the opening zoom must sit strictly inside both bounds**, or
## the island is being framed by a clamp again and no margin will move it.
##
## Then the framing itself, bounded at BOTH ends, because 「뒤로 빼줘」 has an obvious failure on each
## side: too tight and the request was not honoured; too far and the island is a stamp in an ocean,
## which is the exact thing shrinking the compact islands was for.
##
## ⚠ **And the body size is in this row on purpose.** Bodies were cut 84 -> 49 px the same day; pulling
## the camera back shrinks what reaches the screen a second time, and the two are only ever seen
## together. The wolf's floor here is **one tile at `TILE_PX`** — the same anchor its own size row uses,
## and the size the user rejected twice as too small.
func _the_first_island_opens_with_room_around_it(t) -> void:
	var g := Grid.new()
	Islands.load_into(g)
	var zoom := Look.survey_zoom_of(g.w, g.h)
	t.eq(Vector2i(g.w, g.h), Vector2i(26, 20), "첫 노드가 여는 섬은 26 x 20 이다 (자가 점검)")
	t.ok(zoom > Look.ZOOM_MIN + 0.01 and zoom < Look.ZOOM_MAX - 0.01,
		"여는 줌 %.4f 가 양쪽 한계 안에 있다 — 한계에 걸리면 여백 상수가 아무 일도 못 한다" % zoom)

	var across := float(g.w) * Look.TILE_PX * zoom / Look.VIEWPORT_W_PX
	var down := float(g.h) * Look.TILE_PX * zoom \
		* sin(deg_to_rad(Look.CAM_PITCH_DEG)) / Look.VIEWPORT_H_PX
	t.ok(across < 0.80,
		"섬이 화면 너비의 %.0f%% 만 차지한다 — 여백이 생겼다" % (across * 100.0))
	t.ok(across > 0.55,
		"그래도 절반은 넘게 채운다 (%.0f%%) — 바다 한가운데 우표가 되면 여기가 문다" % (across * 100.0))
	t.ok(down < 0.75 and down > 0.45,
		"세로도 마찬가지다 (%.0f%%)" % (down * 100.0))

	var wolf_px := Look.body_radius_of(Rules.WOLF) * Look.BEAST_SPRITE_W_RATIO * zoom
	t.ok(wolf_px >= Look.TILE_PX,
		"그 줌에서 늑대가 화면에 %.1fpx 로 선다 — 한 칸(%.0fpx)보다 작아지면 뒤로 그만 빼는 것이다"
			% [wolf_px, Look.TILE_PX])



## ⚠⚠ **EVERY EFFECT HUNG ON A BODY IS SIZED OFF THE PICTURE, NOT OFF THE SIM RADIUS — the rule this
## repo learned from the death burst and then did not apply to the three effects beside it.**
## 2026-08-25, the user: 「지금 너무 재미없어 그냥 붙어서 그냥 벌렁벌렁하는 거밖에 없어가지고」.
##
## A wolf's sim radius is 14 px and its picture is 49 px wide. Anchored to the radius, the lunge was
## **7.7 px (16% of the picture)**, the flinch **3.0 px (6%)** and the hit halo **18.9 px of radius —
## 37.8 across, INSIDE the 49 px body it was supposed to ring.** On the flat board, where a body WAS
## its radius, those same constants were 27%, 11% and a halo that cleared the body. **Nothing was
## turned off; the picture grew and the effects did not.**
##
## Bounded at BOTH ends per species, and the ceiling is not padding: a lunge longer than the body
## reads as a teleport, and a halo twice the body reads as a splash rather than as *this one*.
func _every_body_effect_is_sized_off_the_picture(t) -> void:
	# ⚠⚠ **DRIVEN, NOT RECOMPUTED — and the first draft of this row recomputed.** It multiplied the
	# constants together itself and asserted the product, so reverting `field_view` to the sim radius
	# changed the code and **not one row reddened.** 「Measuring a pure function is not measuring that
	# anything calls it」 is this repo's own sentence and it arrived inside the check written to stop
	# it. ⇒ A real blow lands, and the LUNGE is read back off the body the code wrote it on; the HALO
	# is measured as geometry in the air buffer.
	var rows := _open(ARENA_W, ARENA_H)
	var army := _army_of([Rules.WOLF])
	var b := _battle_of(rows, army, [_spawn(ARENA_W, Rules.WOLF, 12, 6)])
	_ashore(b, 0, Vector2(11.0, 6.0))
	var fv := _view_of(b, rows)
	var swung := false
	for k in 240:
		b.begin_frame()
		b.step(1.0 / 60.0)
		fv._process(1.0 / 60.0)
		if float((fv._body["s0"] as Dictionary)["push"]) > 0.0:
			swung = true
			break
	t.ok(swung, "늑대가 실제로 한 대 쳤고 런지가 몸에 적혔다 (자가 점검)")
	var push := float((fv._body["s0"] as Dictionary)["push"])
	var wolf_wide := Look.sprite_half_px(Rules.WOLF) * 2.0
	t.ok(push >= wolf_wide * 0.20,
		"런지가 제 그림 폭(%.1fpx)의 20%% 이상이다 (%.2fpx) — 심 반지름에 매달면 16%% 로 떨어진다"
			% [wolf_wide, push])
	t.ok(push <= wolf_wide * 0.40,
		"그리고 40%% 를 안 넘는다 (%.2fpx) — 몸을 통째로 건너뛰면 순간이동으로 읽힌다" % push)

	# The halo, as GEOMETRY, on a board with NOBODY FIGHTING.
	# ⚠⚠ **The first draft measured it on the board above and the mutation did not bite**: the air
	# buffer is shared, a live fight keeps sparks and tracers in it, and 「the widest thing in the
	# air buffer」 is not 「the halo」. An enemy alone on an empty arena puts exactly one disc there.
	var quiet := _battle_of(rows, _army_of([]),
		[_spawn(ARENA_W, Rules.WOLF, 12, 6)])
	var qv := _view_of(quiet, rows)
	qv._process(1.0 / 60.0)
	t.ok(qv._a_v.size() == 0, "싸움이 없으면 공중 버퍼가 비어 있다 (자가 점검)")
	(qv._body["e0"] as Dictionary)["flash"] = Look.HIT_FLASH_SEC
	qv._process(0.0)
	t.ok(qv._a_v.size() > 0, "맞은 표시 고리가 공중 버퍼에 실렸다 (자가 점검)")
	var centre := _xz_centre_v3(qv._a_v)
	var halo_px := _max_dist_v3(qv._a_v, centre) * Look.TILE_PX
	var foe_half := Look.sprite_half_px(Rules.WOLF)
	t.ok(halo_px > foe_half,
		"고리 반지름 %.1fpx 가 제 그림 반폭 %.1fpx 보다 크다 — 안 그러면 몸 밑에 깔려 안 보인다"
			% [halo_px, foe_half])
	t.ok(halo_px < foe_half * 2.5,
		"그리고 반폭의 2.5배 안이다 (%.1fpx) — 더 커지면 「이 놈이 맞았다」가 아니라 범위기로 읽힌다"
			% halo_px)

	# The flinch keeps a closed table row: it is a stored number, so every species is checkable.
	var checked := 0
	var thin_knock := []
	for ty in Rules.UNITS.size():
		if fv._beast_tex(ty, true) == null:
			continue
		checked += 1
		if Look.HIT_KNOCK_RATIO * Look.sprite_half_px(ty) < Look.sprite_half_px(ty) * 2.0 * 0.08:
			thin_knock.append(Rules.name_of(ty))
	t.eq(checked, 8, "그림을 가진 종 여덟을 전부 쟀다 (자가 점검 — 0이면 아래가 공허하다)")
	t.eq(thin_knock, [], "움찔이 제 그림 폭의 8%% 밑으로 안 내려간다 %s" % str(thin_knock))

	# ⚠ **And on the glass, at the zoom the first island actually opens at** — a ratio of the picture
	# is worth nothing if the picture itself is 43 px. The 2.0 px snap floor is this repo's own.
	var g := Grid.new()
	Islands.load_into(g)
	var zoom := Look.survey_zoom_of(g.w, g.h)
	var wolf_knock := Look.HIT_KNOCK_RATIO * Look.sprite_half_px(Rules.WOLF) * zoom
	var wolf_lunge := Look.LUNGE_PUSH_RATIO * Look.sprite_half_px(Rules.WOLF) * zoom
	t.ok(wolf_knock > 2.0,
		"첫 섬 여는 줌에서 늑대의 움찔이 %.1f 화면px 다 — 스냅 바닥 2.0 위다" % wolf_knock)
	t.ok(wolf_lunge > 8.0,
		"그리고 런지가 %.1f 화면px 다 — 옛 값은 6.8 이었다" % wolf_lunge)


## ⚠⚠ **THE STANDING RULE: 「붙어서 가만히 있으면 재미가 죽는다」** (the user, *"존나 중요해"*). The
## gait phases on DISTANCE, which is right for a walk cycle and leaves a body in contact — the two
## bodies the player is watching hardest — perfectly still. Measured in the sweep: a body stands over
## 5 seconds on 31 of 54 landing tiles, worst **22.4 s**, every better tile reserved.
##
## ⚠ **This does not shorten that queue and the row does not claim it does.** It claims a body that
## cannot move is not a frozen picture. Both ends: silent before the threshold, moving after it.
func _a_body_that_cannot_move_still_does_something(t) -> void:
	var rows := _open(ARENA_W, ARENA_H)
	var b := _battle_of(rows, _army_of([]), [_spawn(ARENA_W, Rules.WOLF, 12, 6)])
	var fv := _view_of(b, rows)
	fv._process(1.0 / 60.0)
	t.ok(fv._body.has("e0"), "몸 항목이 생겼다 (자가 점검)")
	t.ok(fv._idle_offset("e0").length() <= 0.001,
		"막 선 몸은 안 흔들린다 — 칸 사이에서 잠깐 멈춘 몸이 떠는 것을 막는 문턱이다")
	var half := Look.IDLE_AFTER_SEC * 0.5
	fv._process(half)
	t.ok(fv._idle_offset("e0").length() <= 0.001,
		"문턱 절반에서도 조용하다 (%.2fs)" % half)
	# Past the threshold, and far enough past it that the sine is nowhere near its own zero.
	fv._process(Look.IDLE_AFTER_SEC + Look.IDLE_PERIOD_SEC * 0.25)
	var sway := fv._idle_offset("e0").length()
	var cap := Look.IDLE_SWAY_RATIO * Look.sprite_half_px(Rules.WOLF)
	t.ok(sway > 0.0, "문턱을 넘으면 흔들린다 (%.2f px)" % sway)
	t.ok(sway <= cap + 0.001,
		"그리고 제 그림 반폭의 %.0f%% 를 안 넘는다 (상한 %.2f px) — 한 대 맞은 것처럼 보이면 안 된다"
			% [Look.IDLE_SWAY_RATIO * 100.0, cap])
	# ⚠ The other end: a body that IS moving must stay silent, or the sway would ride on top of the
	# gait and every walking animal would wobble.
	var moving := 0.0
	for k in 60:
		# ⚠ `k + 1`, and the +1 is not cosmetic: at k = 0 this wrote the position the body was ALREADY
		# at, so the first frame of the loop was a STILL frame and the max below captured the sway it
		# was already carrying. The row reddened on its own fixture rather than on the subject.
		b.enemy_pos[0] = Vector2(12.0 + 0.05 * float(k + 1), 6.0)
		fv._process(1.0 / 60.0)
		moving = maxf(moving, fv._idle_offset("e0").length())
	t.ok(moving <= 0.001, "움직이는 몸은 안 흔들린다 (%.3f px) — 걷는 짐승이 떨면 안 된다" % moving)


# == the ground transients ============================================================================

## Item 7 — the landing ring. Fixed radius 20 px, so the piece count is closed:
## ceil(TAU·20 / 20) = 7, floored to the minimum 8 segments ⇒ 8 quads = **48 vertices**, ground only.
func _the_landing_ring(t) -> void:
	var fx := _quiet_view()
	var fv: FieldView = fx["fv"]
	var at := Look.tile_point_px(Vector2(12.0, 6.0))
	fv._fx.append({"kind": FieldView.FxKind.LAND, "age": Look.LAND_RING_SEC * 0.5, "delay": 0.0,
		"life": Look.LAND_RING_SEC, "at": at})
	fv._process(0.0)
	t.eq(fv._g_v.size(), 48, "상륙 링은 바닥 정점 정확히 48개다 (8조각 x 6)")
	t.eq(fv._a_v.size(), 0, "공중 버퍼는 조용하다 — 상륙 링은 바닥의 것이다")
	t.eq(fv._decal.mesh.get_surface_count(), 1, "그리고 커밋됐다 — _fx_flush 를 지우면 버퍼만 남고 여기가 문다")
	var want := Look.COL_LAND_RING
	want.a *= 0.5
	t.ok(_cols_all_close(fv._g_c, want),
		"48개 전부 COL_LAND_RING 에 fade 0.5 를 실었다 — 바닥과 천장이 한 등식이다")
	var centre := _xz_centre_v3(fv._g_v)
	t.ok(centre.distance_to(at / Look.TILE_PX) < 0.02, "링의 중심이 상륙점이다")
	var outer := _max_dist_v3(fv._g_v, centre)
	t.ok(absf(outer - (20.0 + 2.5) / 40.0) < 0.03,
		"extent 가 반지름 20 + 굵기 절반이다 (%.3f 타일) — 반지름 0 으로 접힌 링은 여기서 문다" % outer)


## Item 5 — the area ring, AND the ground-following axis. The ring is the widest ground mark
## (r 42 px at half-life), so it is the one that crosses real slope: every vertex must sit at
## `_ground_y_px` of its own ground point.
## ⚠ The pairing closes both flattening mutations: flatten `_g_tri` and the per-vertex match bites;
## flatten `_ground_y_px` itself and the FIXTURE self-check (a real slope under the ring) bites,
## because the slope is measured through the same function.
func _the_area_ring_follows_the_ground(t) -> void:
	var fx := _quiet_view()
	var fv: FieldView = fx["fv"]
	# The land tile whose surrounding ground slopes the most, found on the fixed-seed terrain — a
	# deterministic search, not a random one.
	var best := Vector2.ZERO
	var best_spread := 0.0
	for ty in range(3, ARENA_H - 3):
		for tx in range(3, ARENA_W - 3):
			var c := Look.tile_point_px(Vector2(tx, ty))
			var hs := [fv._ground_y_px(c + Vector2(42.0, 0.0)), fv._ground_y_px(c - Vector2(42.0, 0.0)),
				fv._ground_y_px(c + Vector2(0.0, 42.0)), fv._ground_y_px(c - Vector2(0.0, 42.0))]
			var spread := float(hs.max()) - float(hs.min())
			if spread > best_spread:
				best_spread = spread
				best = c
	t.ok(best_spread > 0.05, "링이 걸칠 진짜 비탈을 찾았다 (자가 점검, 높이차 %.3f 타일)" % best_spread)

	fv._fx.append({"kind": FieldView.FxKind.AREA, "age": Look.AREA_RING_SEC * 0.5, "delay": 0.0,
		"life": Look.AREA_RING_SEC, "at": best, "radius": 60.0})
	fv._process(0.0)
	# r = 60 · lerp(0.4, 1.0, 0.5) = 42 px ⇒ ceil(TAU·42 / 20) = 14 pieces = 84 vertices.
	t.eq(fv._g_v.size(), 84, "광역 링은 바닥 정점 정확히 84개다 (14조각 x 6, 반지름 42px)")
	t.eq(fv._a_v.size(), 0, "공중 버퍼는 조용하다")
	var want := Look.COL_AREA_RING
	want.a *= 0.5
	t.ok(_cols_all_close(fv._g_c, want), "84개 전부 COL_AREA_RING 에 fade 0.5 다")
	var flat := 0
	var y_min := 1e9
	var y_max := -1e9
	for v: Vector3 in fv._g_v:
		if absf(v.y - fv._ground_y_px(Vector2(v.x, v.z) * Look.TILE_PX)) > 0.001:
			flat += 1
		y_min = minf(y_min, v.y)
		y_max = maxf(y_max, v.y)
	t.eq(flat, 0, "모든 정점이 제 발밑 땅 높이에 있다 — 링이 비탈을 따라 올라간다")
	t.ok(y_max - y_min > 0.04, "그리고 링의 높이가 실제로 벌어져 있다 (%.3f 타일) — 평평하게 뭉개면 여기가 문다"
		% (y_max - y_min))


## The refusal mark — `speed-off-open-landing` 2.5's one-shot, at its fixed 26 px:
## ceil(TAU·26 / 20) = 9 pieces = **54 vertices**, `COL_LOSE` with the fade SET (not multiplied).
func _the_refusal_mark(t) -> void:
	var fx := _quiet_view()
	var fv: FieldView = fx["fv"]
	var at := Look.tile_point_px(Vector2(10.0, 5.0))
	fv.note_refusal(at)
	var entry: Dictionary = fv._fx[fv._fx.size() - 1]
	entry["age"] = Look.REFUSE_MARK_SEC * 0.5
	fv._process(0.0)
	t.eq(fv._g_v.size(), 54, "거절 표시는 바닥 정점 정확히 54개다 (9조각 x 6)")
	t.eq(fv._a_v.size(), 0, "공중 버퍼는 조용하다")
	var want := Look.COL_LOSE
	want.a = 0.5
	t.ok(_cols_all_close(fv._g_c, want), "COL_LOSE 에 fade 0.5 — 알파가 곱해지는 게 아니라 fade 그 자체다")
	var centre := _xz_centre_v3(fv._g_v)
	t.ok(centre.distance_to(at / Look.TILE_PX) < 0.02, "표시의 중심이 거절당한 그 자리다")
	t.ok(absf(_max_dist_v3(fv._g_v, centre) - (26.0 + 2.5) / 40.0) < 0.03,
		"extent 가 후보 링(18px)과 갈리는 26px 다 — 거절이 후보로 안 읽힌다")


## Item 6 — one intent line, enemy to soldier, two tiles apart: 80 px at the intent's own coarse
## 120 px cut is ONE piece = **6 vertices**, wearing `COL_TARGET_LINE`'s deliberate 0.12 alpha.
func _the_intent_line(t) -> void:
	var rows := _open(ARENA_W, ARENA_H)
	var b := _battle_of(rows, _army_of([Rules.WOLF]), [_spawn(ARENA_W, Rules.WOLF, 14, 6)])
	_ashore(b, 0, Vector2(12.0, 6.0))
	b.enemy_target[0] = 0
	var fv := _view_of(b, rows)
	fv._process(0.0)
	t.eq(fv._g_v.size(), 6, "의도선 하나는 바닥 정점 정확히 6개다 — 성긴 120px 절단의 한 조각")
	t.eq(fv._a_v.size(), 0, "공중 버퍼는 조용하다")
	t.ok(_cols_all_close(fv._g_c, Look.COL_TARGET_LINE),
		"선이 COL_TARGET_LINE 그대로다 — 알파 0.12 는 일부러 희미한 면허다")
	var centre := _xz_centre_v3(fv._g_v)
	t.ok(centre.distance_to(Vector2(13.5, 6.5)) < 0.1, "선의 한가운데가 두 몸 사이다")


# == the air transients ===============================================================================

## Item 1 — the tracer: one camera-plane stub of **6 vertices**, `COL_SHOT` with NO fade, and a STUB
## — its whole extent stays far under the muzzle-to-target distance it sweeps.
func _the_tracer(t) -> void:
	var fx := _quiet_view()
	var fv: FieldView = fx["fv"]
	var from := Look.tile_point_px(Vector2(10.0, 6.0))
	var to := Look.tile_point_px(Vector2(14.0, 6.0))
	fv._fx.append({"kind": FieldView.FxKind.SHOT, "age": Look.SHOT_SEC * 0.5, "delay": 0.0,
		"life": Look.SHOT_SEC, "from": from, "to": to})
	fv._process(0.0)
	t.eq(fv._a_v.size(), 6, "예광선은 공중 정점 정확히 6개다 — 토막 하나")
	t.eq(fv._g_v.size(), 0, "바닥 버퍼는 조용하다 — 예광선은 공중의 것이다")
	t.eq(fv._air.mesh.get_surface_count(), 1, "그리고 커밋됐다")
	t.ok(_cols_all_close(fv._a_c, Look.COL_SHOT), "COL_SHOT 그대로다 — 예광선은 fade 가 없다")
	var longest := 0.0
	for i in fv._a_v.size():
		for j in range(i + 1, fv._a_v.size()):
			longest = maxf(longest, fv._a_v[i].distance_to(fv._a_v[j]))
	t.ok(longest > 0.28 and longest < 0.45,
		"토막의 최장 대각이 12px 길이 근처다 (%.3f 타일) — 전체 4타일 선을 그으면 레이저고, 0이면 접힌 것이다"
			% longest)


## Item 2② — the spark fan: six shards at half-life = 6 camera-plane segments = **36 vertices**,
## `COL_SPARK` with the fade as its alpha.
func _the_spark(t) -> void:
	var fx := _quiet_view()
	var fv: FieldView = fx["fv"]
	var at := Look.tile_point_px(Vector2(12.0, 6.0))
	fv._fx.append({"kind": FieldView.FxKind.SPARK, "age": Look.SPARK_SEC * 0.5, "delay": 0.0,
		"life": Look.SPARK_SEC, "at": at, "facing": Vector2.RIGHT})
	fv._process(0.0)
	t.eq(fv._a_v.size(), 36, "파편은 공중 정점 정확히 36개다 (조각 여섯 x 6)")
	t.eq(fv._g_v.size(), 0, "바닥 버퍼는 조용하다")
	var want := Look.COL_SPARK
	want.a = 0.5
	t.ok(_cols_all_close(fv._a_c, want), "COL_SPARK 에 fade 0.5 다")


## Item 4 — the death burst, AND the camera-plane axis with a turn under it. The lion-sized ring at
## half-life is `FX_RING_SEGMENTS` 24 quads = **144 vertices**; every one lies in the camera's own
## plane, before AND after the board turns 45° — the number behind 「판을 돌려도 안 찌그러진다」.
func _the_death_burst_stands_in_the_camera_plane(t) -> void:
	var fx := _quiet_view()
	var fv: FieldView = fx["fv"]
	var at := Look.tile_point_px(Vector2(12.0, 6.0))
	fv._fx.append({"kind": FieldView.FxKind.BURST, "age": Look.BURST_SEC * 0.5, "delay": 0.0,
		"life": Look.BURST_SEC, "at": at, "radius": 22.0, "colour": Look.COL_ENEMY})
	fv._process(0.0)
	t.eq(fv._a_v.size(), 144, "죽음 파열은 공중 정점 정확히 144개다 (24조각 x 6)")
	t.eq(fv._g_v.size(), 0, "바닥 버퍼는 조용하다")
	var want := Look.COL_ENEMY
	want.a = 0.5
	t.ok(_cols_all_close(fv._a_c, want), "죽은 쪽의 제 색에 fade 0.5 다")
	var centre := _centre_v3(fv._a_v)
	var r_out := 0.0
	var r_in := 1e9
	for v: Vector3 in fv._a_v:
		r_out = maxf(r_out, v.distance_to(centre))
		r_in = minf(r_in, v.distance_to(centre))
	# ⚠ The picture is SPRITE-scaled (verify-look: the sim-radius ring never read under the body piles):
	# the lion's 22 px radius starts its ring at 22 x `BURST_START_MUL`, so at half-life it stands at
	# that x 1.6, plus half the 9 px stroke.
	# ⚠⚠ **RE-DERIVED, NOT NUDGED (2026-08-25)**: the bodies were cut 6.0 -> 3.5, so `BURST_START_MUL`
	# went 3.00 -> 1.75 and every number on this line moved with it. 22 x 1.75 = **38.5**; at half-life
	# 38.5 x 1.6 = **61.6**; outer (61.6 + 4.5) / 40 = **1.6525 tiles**, inner (61.6 - 4.5) / 40 =
	# **1.4275**. The old 2.7525 was the same arithmetic at the old body size and it is what proves this
	# ring is tied to the art rather than to a constant somebody has to remember.
	t.ok(absf(r_out - 1.6525) < 0.03,
		"바깥 반지름이 스프라이트 반폭 38.5px 의 1.6 성장 + 굵기 절반이다 (%.3f 타일) — 더미 위로 읽힌다" % r_out)
	t.ok(absf(r_in - 1.4275) < 0.03,
		"안쪽 반지름도 0 이 아니다 — 접힌 링은 여기서 문다 (%.3f 타일)" % r_in)
	t.ok(is_equal_approx(Look.BURST_START_MUL, Look.BEAST_SPRITE_W_RATIO * 0.5),
		"시작 배수가 스프라이트 반폭 비율 그대로다 — 그림이 다시 커지는 날 파열이 같이 커진다")
	var plane_bad := _off_plane_count(fv._a_v, centre, fv._cam.transform.basis.z)
	t.eq(plane_bad, 0, "144개 전부 카메라 평면 위다")

	# The turn. The buffers rebuild on the next _process, the camera basis moves — and the ring must
	# have actually re-oriented (a stale buffer would pass the old basis and fail this pair).
	var before: Vector3 = fv._a_v[0]
	fv.turn_by(45.0)
	fv._process(0.0)
	t.eq(fv._a_v.size(), 144, "돌린 뒤에도 링은 그대로 144개다 (자가 점검)")
	t.ok(fv._a_v[0].distance_to(before) > 0.01, "그리고 정점이 실제로 움직였다 — 판을 따라 돈 것이다 (자가 점검)")
	var centre2 := _centre_v3(fv._a_v)
	t.eq(_off_plane_count(fv._a_v, centre2, fv._cam.transform.basis.z), 0,
		"45° 돌린 카메라의 평면 위에도 전부 서 있다 — 돌려도 안 찌그러진다")


## Item 3② — the hit halo, the area a hit is actually seen on: a camera-plane disc of 24 segments =
## **144 vertices**, `COL_HIT_HALO` with the flash's remaining fraction on its alpha.
func _the_hit_halo(t) -> void:
	var rows := _open(ARENA_W, ARENA_H)
	var b := _battle_of(rows, _army_of([]), [_spawn(ARENA_W, Rules.WOLF, 12, 6)])
	var fv := _view_of(b, rows)
	fv._process(0.0)
	t.eq(fv._a_v.size(), 0, "맞은 적 없는 프레임에는 헤일로가 없다 (바닥 — 무조건 그리는 잎은 여기서 갈린다)")
	fv._body["e0"] = _body_entry(b.enemy_pos[0])
	(fv._body["e0"] as Dictionary)["flash"] = Look.HIT_FLASH_SEC * 0.5
	fv._process(0.0)
	t.eq(fv._a_v.size(), 144, "타격 헤일로는 공중 정점 정확히 144개다 (원판 24조각 x 6)")
	t.eq(fv._g_v.size(), 0, "바닥 버퍼는 조용하다")
	var want := Look.COL_HIT_HALO
	want.a *= 0.5
	t.ok(_cols_all_close(fv._a_c, want), "COL_HIT_HALO 에 남은 플래시 0.5 를 실었다")


# == the body-bound effects, on SURFACE 2 =============================================================
## Flash · lunge · knockback · gait squash never touch a buffer: they are written into the pooled
## sprite's own modulate / position / scale — the fields the engine consumes. Each is toggled on the
## SAME body against its own resting frame, so the row is the difference the effect makes.
func _body_effects_ride_the_pooled_fields(t) -> void:
	var rows := _open(ARENA_W, ARENA_H)
	var b := _battle_of(rows, _army_of([]), [_spawn(ARENA_W, Rules.WOLF, 12, 6)])
	var fv := _view_of(b, rows)
	fv._body["e0"] = _body_entry(b.enemy_pos[0])
	fv._process(0.0)
	var body := _body_sprite(fv)
	t.ok(body != null, "적의 몸 스프라이트가 있다 (자가 점검)")
	var rest_mod: Color = body.modulate
	var rest_pos: Vector3 = body.position
	var rest_scale: Vector3 = body.scale
	t.eq(rest_mod, Look.beast_tint(Look.body_colour_of(true)), "쉬는 몸은 제 편 색이다 (자가 점검)")

	# Item 3① — the flash mixes COL_FLASH into the side colour before the team tint.
	(fv._body["e0"] as Dictionary)["flash"] = Look.HIT_FLASH_SEC * 0.5
	fv._process(0.0)
	var want_mod := Look.beast_tint(Look.body_colour_of(true).lerp(Look.COL_FLASH, Look.HIT_FLASH_STRENGTH))
	t.eq(_body_sprite(fv).modulate, want_mod, "플래시가 modulate 를 COL_FLASH 쪽으로 0.7 만큼 민다")
	t.ok(want_mod != rest_mod, "그리고 그 값은 쉬는 색과 실제로 다르다 (자가 점검)")
	(fv._body["e0"] as Dictionary)["flash"] = 0.0

	# Item 2① — the lunge at its peak pushes the whole body `push` px along its facing.
	var e0: Dictionary = fv._body["e0"]
	e0["lunge"] = Look.LUNGE_SEC * 0.5
	e0["lunge_dir"] = Vector2.RIGHT
	e0["push"] = 10.0
	fv._process(0.0)
	t.ok(absf(_body_sprite(fv).position.x - (rest_pos.x + 0.25)) < 0.001,
		"런지 꼭대기에서 몸이 정확히 10px(0.25타일) 앞으로 밀린다")
	e0["lunge"] = 0.0

	# Item 3③ — the knockback at half its window is half of the stored magnitude, away from the
	# striker. ⚠⚠ **RE-DERIVED: the magnitude is a ratio of the DRAWN half-width now and it was a
	# raw 3.0 px.** A shieldbearer's radius is 16.0, so its picture is 16.0 x 3.5 = 56 wide, half
	# 28.0; `HIT_KNOCK_RATIO` 0.22 x 28.0 = **6.16 px**, and half the window is **3.08**. The old
	# 1.5 was 3.0 halved, and 3.0 px of flinch on a 56 px animal is what the user was looking at.
	# ⚠ The magnitude is SET here rather than defaulted, so this row measures the stored value
	# reaching the sprite and not a constant this file could read for itself.
	e0["knock"] = Look.HIT_KNOCK_SEC * 0.5
	e0["knock_dir"] = Vector2(0.0, 1.0)
	e0["knock_px"] = Look.HIT_KNOCK_RATIO * Look.sprite_half_px(Rules.WOLF)
	fv._process(0.0)
	t.ok(absf(_body_sprite(fv).position.z - (rest_pos.z + 3.08 / 40.0)) < 0.001,
		"넉백 반창에서 몸이 정확히 3.08px 뒤로 밀려 있다 — 옛 1.5px 는 그림의 3%%였다")
	e0["knock"] = 0.0

	# Item 12 — the gait squash: 0.8 along the heading, 1.2 across it, carried on scale.
	e0["gait"] = TAU * 0.25
	e0["head"] = Vector2.RIGHT
	fv._process(0.0)
	var squashed := _body_sprite(fv)
	t.ok(absf(squashed.scale.x - rest_scale.x * 0.8) < 0.0001
			and absf(squashed.scale.y - rest_scale.y * 1.2) < 0.0001,
		"걸음 스쿼시가 scale 에 (0.8, 1.2) 로 실린다 — 서 있으면 sin(0)=0 이라 안 찌그러진다")


# == the sailing boat's remaining route (the caller `_route_ahead` lost) ==============================
## Ticket 09's own founding shape, closed: the line was computed every frame and drawn by nobody.
## `_paint_boat_routes` now feeds it to the floor layer — the SIM's own `leg` decides what is behind
## the boat, and the drawn water shrinks as the crossing advances.
func _the_boat_route_shrinks_with_the_sim(t) -> void:
	var rows := _port()
	# ⚠ One idle enemy far inland, or there is nothing to win against: a battle with zero enemies
	# latches WON on its first step and the boat freezes mid-bay — measured, 4000 sub-steps of leg 0.
	var b := _planning_battle_of(rows, _army_of([Rules.WOLF]),
		[_spawn(ARENA_W, Rules.WOLF, 20, 9)])
	var fv := _view_of(b, rows)
	# The sendable tile FARTHEST from the harbour, so the route holds interior waypoints and the
	# crossing lasts long enough for `leg` to advance while the boat is still at sea.
	var target := -1
	var far := 0.0
	for tile in b.grid.passable.size():
		if b.grid.home_harbour_for(tile) < 0:
			continue
		var d := absf(float(tile % ARENA_W) - 2.0) + absf(float(tile / ARENA_W) - 5.0)
		if d > far:
			far = d
			target = tile
	t.ok(target >= 0 and far >= 4.0 and b.send(0, target) >= 0,
		"항구에서 먼 곳으로 한 척을 보냈다 (자가 점검, 맨해튼 %.0f)" % far)

	# Before the commit the boat is its plan: no aim is armed, so the water carries NO route at all.
	fv._process(0.0)
	t.eq(_verts_of(fv._g_v, fv._g_c, Look.COL_ROUTE).size(), 0,
		"확정 전에는 항로선이 없다 — 배는 아직 계획이고 물은 계획의 것이다")

	t.ok(b.commit(), "확정했다 (자가 점검)")
	fv._process(0.0)
	var boat: Dictionary = b.boats[0]
	var path: PackedVector2Array = boat["path"]
	t.ok(path.size() >= 3, "항로에 경유점이 있다 (자가 점검, %d점)" % path.size())
	var route0 := _verts_of(fv._g_v, fv._g_c, Look.COL_ROUTE)
	t.ok(route0.size() >= 12, "확정하자 남은 항로선이 바닥에 깔렸다 (%d 정점)" % route0.size())
	var missing := 0
	for k in range(1, path.size()):
		if _min_dist(route0, Look.tile_point_px(path[k]) / Look.TILE_PX) > 0.3:
			missing += 1
	t.eq(missing, 0, "모든 남은 경유점 곁에 정점이 있다 — 선이 sim 의 path 그대로다")
	t.ok(_min_dist(route0, Look.tile_point_px(Vector2(boat["pos"])) / Look.TILE_PX) < 0.2,
		"선의 머리가 선체 제 자리다")

	# Sail. The sim's `leg` advances; the drawn line must let go of the water already crossed.
	var guard := 0
	while guard < 4000:
		b.begin_frame()
		b.step(Rules.SIM_SUBSTEP_SEC)
		guard += 1
		if int(boat["phase"]) != Battle.Phase.OUTBOUND:
			break
		if int(boat["leg"]) >= 1 \
				and Vector2(boat["pos"]).distance_to(path[1]) > 1.5:
			break
	t.ok(int(boat["phase"]) == Battle.Phase.OUTBOUND and int(boat["leg"]) >= 1,
		"아직 항해 중인 채로 첫 경유점을 지났다 (자가 점검, leg %d)" % int(boat["leg"]))
	b.begin_frame()
	fv._process(0.0)
	var route1 := _verts_of(fv._g_v, fv._g_c, Look.COL_ROUTE)
	t.ok(route1.size() < route0.size(),
		"가면서 선이 줄었다 (%d -> %d 정점) — 이미 지나온 물을 다시 안 그린다" % [route0.size(), route1.size()])
	t.ok(_min_dist(route1, Look.tile_point_px(path[1]) / Look.TILE_PX) > 0.8,
		"지나온 경유점 곁에는 더 이상 정점이 없다")
	t.ok(_min_dist(route1, Look.tile_point_px(Vector2(boat["pos"])) / Look.TILE_PX) < 0.2,
		"머리는 여전히 선체 자리를 따라간다")


# == the dry slot draws no plan (the fork the user closed: 「추천대로」) ================================
## ⚠ Mutation: delete `_paint_plan`'s reserve gate — the control half (a WET slot draws the refuse
## ring) proves the zero below is the gate and not a dead plan layer.
func _a_dry_slot_draws_no_plan(t) -> void:
	var rows := _open(ARENA_W, ARENA_H)
	var b := _planning_battle_of(rows, _army_of([Rules.WOLF]), [])
	var fv := _view_of(b, rows)
	# Aim at open water (the border ring). This arena has no summon band, so the aim is REFUSED
	# water — which draws the COL_LOSE ring: ceil(TAU·18 / 20) = 6, floored to 8 segments = 48 verts.
	var aim := 0 * ARENA_W + 5
	t.ok(b.grid.water[aim] != 0 and not b.grid.can_summon_at(aim), "띠 밖 물칸이다 (자가 점검)")
	fv.set_summon_aim(0, aim)
	fv._process(0.0)
	var wet_ring := _verts_of(fv._g_v, fv._g_c, Look.COL_LOSE)
	t.eq(wet_ring.size(), 48, "예비가 남은 슬롯의 조준은 거절 색 링 48 정점을 그린다 (대조군)")

	# Drain the slot — the only body goes TRANSIT — and the same aim must draw NOTHING.
	b.soldier_state[0] = Battle.SoldierState.TRANSIT
	t.eq(b.slot_reserve_ids(0).size(), 0, "슬롯이 말랐다 (자가 점검)")
	fv._process(0.0)
	t.eq(_verts_of(fv._g_v, fv._g_c, Look.COL_LOSE).size()
			+ _verts_of(fv._g_v, fv._g_c, Look.COL_WIN).size()
			+ _verts_of(fv._g_v, fv._g_c, Look.COL_ROUTE).size(), 0,
		"마른 슬롯은 링도 항로도 안 그린다 — sim 이 거절할 약속을 화면이 하지 않는다 (복원된 옛 규칙)")


## The ceiling on the transient drawer: `_drain_events` drops the oldest past `FX_MAX_COUNT`, so a
## refusal storm cannot pile geometry without bound.
func _the_transient_drawer_is_capped(t) -> void:
	var fx := _quiet_view()
	var fv: FieldView = fx["fv"]
	for _k in Look.FX_MAX_COUNT + 44:
		fv.note_refusal(Look.tile_point_px(Vector2(10.0, 5.0)))
	fv._process(0.0)
	t.eq(fv._fx.size(), Look.FX_MAX_COUNT,
		"일시 연출 서랍은 FX_MAX_COUNT 에서 잘린다 — 가장 오래된 것이 나간다")


# == the readers themselves ===========================================================================
## Cases that fail the INSTRUMENT rather than the tree — a colour filter that never matches reads
## exactly like a quiet frame, and a bounding box of zero extent still returns the right centre.
func _the_readers_themselves(t) -> void:
	var v := PackedVector3Array([Vector3(1, 0, 1), Vector3(3, 0, 3), Vector3(5, 0, 5)])
	var c := PackedColorArray([Color.RED, Color.BLUE, Color.RED])
	t.eq(_verts_of(v, c, Color.RED).size(), 2, "색 필터가 그 색만 고른다 (계기 자가 점검)")
	t.eq(_verts_of(v, c, Color.GREEN).size(), 0, "없는 색이면 0이다 — 조용한 프레임과 똑같이 읽힌다는 뜻이다")
	t.eq(_verts_of(PackedVector3Array(), PackedColorArray(), Color.RED).size(), 0,
		"빈 버퍼면 0이다 (계기 자가 점검)")
	var folded := PackedVector3Array([Vector3(2, 0, 2), Vector3(2, 0, 2), Vector3(2, 0, 2)])
	t.ok(_xz_centre_v3(folded).distance_to(Vector2(2, 2)) < 0.001
			and _max_dist_v3(folded, Vector2(2, 2)) == 0.0,
		"접힌 기하는 중심이 맞고 extent 가 0이다 — extent 를 같이 재는 이유다 (계기 자가 점검)")


# == 티켓 15: one row, one picture ====================================================================
## **The move's own picture check, read off the POOLED SPRITES and not off `_beast_tex`.** Measuring
## the lookup would prove the table exists; this proves the field actually put nine different pictures
## on nine bodies.
##
## ⚠⚠ **COUNTING IS NOT ENOUGH and that is the whole design of this row.** Five species sharing the
## wolf's texture draws exactly nine bodies, so the count is green while the field says one animal.
## The DISTINCT texture count is what bites, and the body count beside it is the self-check that keeps
## the distinct count from being green on an empty field.
##
## ⚠ **They are spawned as enemies because a spawn takes any row id**, which also drives the point:
## with `is_enemy` gone, what a body wears comes from its ROW and from nothing about which side it is.
##
## ⚠ Mutation: point two `Look.BEAST_TEX` rows at one path; give the lion a picture (that one reddens
## the distinct count from the other end, since it removes the only fallback body).
func _every_row_wears_its_own_picture(t) -> void:
	var rows := _open(ARENA_W, ARENA_H)
	var spawns := []
	for ty in Rules.UNITS.size():
		spawns.append(_spawn(ARENA_W, ty, 2 + ty, 3))
	var b := _battle_of(rows, _army_of([]), spawns)
	var fv := _view_of(b, rows)
	fv._process(0.0)
	var seen := {}
	var bodies := 0
	for k in fv._sprites_used:
		var s: Sprite3D = fv._sprites[k]
		# The one-texel bar texture is the HP rails, two per body — not a picture.
		if s.texture == fv._tex_flat:
			continue
		bodies += 1
		seen[s.texture] = int(seen.get(s.texture, 0)) + 1
	t.eq(bodies, Rules.UNITS.size(), "표의 아홉 줄이 전부 몸으로 섰다 (자가 점검)")
	t.eq(seen.size(), Rules.UNITS.size(),
		"그리고 저마다 다른 그림을 쓴다 — 개수만 세면 다섯이 늑대 그림 하나를 나눠 써도 맞는다")
	# The `is_enemy` argument is gone, so the same row facing the same way is the same picture whoever
	# is asking. Asserted as an EQUALITY, which is what a deleted selector actually means.
	t.eq(fv._beast_tex(Rules.WOLF, true), fv._beast_tex(Rules.WOLF, true),
		"같은 줄은 같은 그림을 준다 — 묻는 쪽이 편을 안 고른다")
	t.ok(fv._beast_tex(Rules.WOLF, true) != fv._beast_tex(Rules.WOLF, false),
		"그러나 좌우는 다른 그림이다 (자가 점검)")
	t.eq(fv._beast_tex(Rules.LION, true), null, "사자만 그림이 없다 — 둥근 사각형으로 선다")


# == 티켓 26: the wolf's frames =======================================================================

## The table, the files behind it, and **the canvas — which is the half no count can see.**
##
## ⚠⚠ **`_beast_rect` takes a body's WIDTH from its radius and its HEIGHT from the texture's own
## aspect.** A frame drawn on a wider canvas therefore draws the animal SHRUNK inside the same box,
## and a taller one LIFTS it off the ground — and both of those are a correct texture in a correct
## strip at a correct index. Nothing else in this file would say a word.
##
## ⚠ The fallback is the other half: eight of nine rows have no strip and must still get a body.
## Asserted at the PATH level here (a row with no strip answers with its standing picture) and at the
## picture level in the driven row below.
##
## ⚠ Mutation: `WOLF_ANIM_FRAMES` -> `[0, 0]`; `[4, 4]` onto a second row (whose files do not exist);
## a wolf frame re-exported on a different canvas; `beast_frame_path` returning the idle path always.
func _only_the_wolf_has_frames_and_they_share_one_canvas(t) -> void:
	# -- the table: exactly one animated row, and it is the wolf ------------------------------------
	var animated: Array[String] = []
	for ty in Rules.UNITS.size():
		if Look.beast_anim_frames(ty, Look.Anim.WALK) > 0 \
				or Look.beast_anim_frames(ty, Look.Anim.BITE) > 0:
			animated.append(Rules.name_of(ty))
	t.eq(animated, [Rules.name_of(Rules.WOLF)],
		"프레임을 가진 줄은 늑대 하나다 %s — 하나도 없으면 아래가 전부 공허하다" % str(animated))
	t.eq(Look.beast_anim_frames(Rules.WOLF, Look.Anim.WALK), 4, "걷기는 넉 장이다")
	t.eq(Look.beast_anim_frames(Rules.WOLF, Look.Anim.BITE), 4, "물기도 넉 장이다")
	# ⚠ The standing picture is NOT a strip, and a caller that asked for it must get 0 rather than 1 —
	# a one-frame idle strip would hand eight species an animation made of the picture they already
	# wear, and the fallback would stop being visible in the code at all.
	t.eq(Look.beast_anim_frames(Rules.WOLF, Look.Anim.IDLE), 0, "서 있는 그림은 띠가 아니다 (0장)")

	# -- the files the table promises ---------------------------------------------------------------
	var missing: Array[String] = []
	var paths := {}
	for anim in [Look.Anim.WALK, Look.Anim.BITE]:
		for f in Look.beast_anim_frames(Rules.WOLF, anim):
			for facing in [true, false]:
				var p := Look.beast_frame_path(Rules.WOLF, anim, f, facing)
				paths[p] = true
				if not ResourceLoader.exists(p):
					missing.append(p)
	t.eq(paths.size(), 16, "늑대 프레임 경로 열여섯 개를 만들었다 — 좌우가 겹치면 여덟이 된다")
	t.eq(missing, [], "그 열여섯 장이 전부 리포에 있다 %s" % str(missing))

	# -- the fallback, at the path level ------------------------------------------------------------
	var fell_back := 0
	for ty in Rules.UNITS.size():
		if Look.beast_anim_frames(ty, Look.Anim.WALK) > 0:
			continue
		fell_back += 1
		t.eq(Look.beast_frame_path(ty, Look.Anim.WALK, 0, true), Look.beast_tex_path(ty, true),
			"%s 는 띠가 없어서 서 있는 그림으로 답한다" % Rules.name_of(ty))
	t.eq(fell_back, 8, "띠 없는 여덟 줄을 전부 물어봤다 (자가 점검)")
	t.eq(Look.beast_frame_path(Rules.WOLF, Look.Anim.IDLE, 0, true),
		Look.beast_tex_path(Rules.WOLF, true), "늑대도 IDLE 을 물으면 서 있는 그림이다")
	t.eq(Look.beast_frame_path(Rules.WOLF, Look.Anim.WALK, 4, true),
		Look.beast_tex_path(Rules.WOLF, true), "띠 밖의 번호도 서 있는 그림으로 떨어진다")

	# -- ⚠⚠ the shared canvas ----------------------------------------------------------------------
	var stand: Texture2D = load(Look.beast_tex_path(Rules.WOLF, true))
	var want := stand.get_size()
	t.ok(want.x > 0.0 and want.y > 0.0, "서 있는 늑대의 캔버스가 %s 다 (자가 점검)" % str(want))
	# ⚠ **The instrument first.** A size comparison that cannot tell two sizes apart would pass the
	# whole table below while every frame sat on its own canvas. This is the case that fails the
	# CHECK, not the subject.
	var off := ImageTexture.create_from_image(
		Image.create(int(want.x) + 8, int(want.y), false, Image.FORMAT_RGBA8))
	t.ok(off.get_size() != want, "재는 자가 다른 캔버스를 실제로 구분한다 (계측기 뒤집기)")
	var odd: Array[String] = []
	var sized := 0
	for p: String in paths:
		var tex: Texture2D = load(p)
		sized += 1
		if tex == null or tex.get_size() != want:
			odd.append(p)
	t.eq(sized, 16, "열여섯 장을 전부 열어 봤다 (자가 점검)")
	t.eq(odd, [],
		"그리고 전부 서 있는 그림과 같은 %s 캔버스다 %s — 캔버스가 다르면 같은 폭 안에서 짐승만 줄어든다"
			% [str(want), str(odd)])


## **The legs run on TIME.** Driven on a body that never moves one pixel, because that is the body the
## rule is about: 「움직이지 않는 몸은 애니메이션하지 않는다」 is what left a wolf in contact — the one
## the player is watching hardest — completely still, and the user named it.
##
## ⚠ Both ends and the ORDER: it visits all four frames (a frozen strip fails the floor), never leaves
## them (a fifth picture fails the ceiling), advances by at most one at a time, and **wraps 3 -> 0 at
## least twice** — final state alone cannot tell a loop from a strip that clamped on its last frame.
##
## ⚠ Mutation: put `b["walk"] += delta` back under the `moved` test; freeze the index at 0; reverse
## the strip; drop the `% strip.size()` so it clamps.
func _the_legs_run_on_time_not_on_distance(t) -> void:
	var rows := _open(ARENA_W, ARENA_H)
	var b := _battle_of(rows, _army_of([]), [_spawn(ARENA_W, Rules.WOLF, 12, 6)])
	var fv := _view_of(b, rows)
	var stood: Vector2 = b.enemy_pos[0]
	fv._process(0.0)
	t.ok(fv._body.has("e0"), "몸 항목이 생겼다 (자가 점검)")
	var strip := fv._anim_strip(Rules.WOLF, Look.Anim.WALK, true)
	t.eq(strip.size(), 4, "걷기 띠가 넉 장으로 올라왔다 (자가 점검)")

	# Half a frame per sample, over three cycles — fine enough that no index can be stepped over, and
	# long enough that the wrap has to happen more than once.
	var seq: Array[int] = []
	var samples := int(round(Look.BEAST_FRAME_SEC * 4.0 * 3.0 / (Look.BEAST_FRAME_SEC * 0.5)))
	for k in samples:
		fv._process(Look.BEAST_FRAME_SEC * 0.5)
		seq.append(strip.find(fv._body_tex("e0", Rules.WOLF, true)))
	t.eq(samples, 24, "세 바퀴를 반 프레임 간격으로 24번 봤다 (자가 점검)")
	t.eq(b.enemy_pos[0], stood, "그동안 몸은 한 칸도 안 움직였다 — 이 줄이 재는 것이 그것이다")

	var outside := 0
	var jumped := 0
	var wraps := 0
	var seen := {}
	for k in seq.size():
		var at := seq[k]
		if at < 0:
			outside += 1
			continue
		seen[at] = true
		if k == 0:
			continue
		var prev := seq[k - 1]
		if prev < 0:
			continue
		var step := (at - prev + strip.size()) % strip.size()
		if step > 1:
			jumped += 1
		if prev == strip.size() - 1 and at == 0:
			wraps += 1
	t.eq(outside, 0, "선 채로도 늘 걷기 띠 안의 그림을 입는다 %s" % str(seq))
	t.eq(seen.size(), 4, "넉 장을 전부 지나갔다 — 한 장에 얼어 있으면 1이다 %s" % str(seq))
	t.eq(jumped, 0, "한 번에 한 장씩만 넘어간다 — 건너뛰거나 뒤집히면 여기서 걸린다 %s" % str(seq))
	t.ok(wraps >= 2, "3 다음에 0 으로 두 번 넘게 돌아왔다 (%d번) — 마지막 장에 눌러앉으면 0번이다" % wraps)


## **The bite and the lunge start on one event**, and the strip plays once. The lunge already existed;
## the mouth is hung on the same line of the same event so the two cannot drift into a wolf snapping
## at nothing.
##
## ⚠ Both ends: nothing is biting before the blow, the strip is entered at frame 0 (the only closed
## mouth), it reaches frame 3, it never goes backwards, and it hands the body back to the walk strip.
## And the row beside it: a species with NO strip wears its standing picture through the same call.
##
## ⚠ Mutation: drop the `ab["bite"]` line; start the bite from a clock of its own; loop the strip;
## make `_body_tex` ignore the bite clock.
func _the_bite_rides_the_blow_that_lunges(t) -> void:
	var rows := _open(ARENA_W, ARENA_H)
	var b := _battle_of(rows, _army_of([Rules.WOLF]),
		[_spawn(ARENA_W, Rules.WOLF, 12, 6)])
	_ashore(b, 0, Vector2(11.0, 6.0))
	var fv := _view_of(b, rows)
	var walk := fv._anim_strip(Rules.WOLF, Look.Anim.WALK, true)
	var bite := fv._anim_strip(Rules.WOLF, Look.Anim.BITE, true)
	t.eq(bite.size(), 4, "물기 띠가 넉 장으로 올라왔다 (자가 점검)")
	t.ok(walk.find(bite[0]) < 0, "걷기와 물기는 다른 그림이다 (자가 점검)")

	# ⚠ **A view frame with the sim not yet stepped**, so the body entry exists and no event has been
	# drained. `_ashore` puts the wolf in contact, so the blow lands on the FIRST stepped frame —
	# stepping here first would have read the clock one frame after it started and called that "before
	# the blow". It did, on the first run of this row.
	fv._process(0.0)
	t.ok(float((fv._body["s0"] as Dictionary)["bite"]) <= 0.0,
		"때리기 전에는 아무것도 안 물고 있다")
	t.ok(walk.find(fv._body_tex("s0", Rules.WOLF, true)) >= 0,
		"그래서 걷기 띠를 입고 있다")

	var swung := false
	for k in 240:
		b.begin_frame()
		b.step(1.0 / 60.0)
		fv._process(1.0 / 60.0)
		if float((fv._body["s0"] as Dictionary)["push"]) > 0.0:
			swung = true
			break
	t.ok(swung, "늑대가 실제로 한 대 쳤다 (자가 점검)")
	var s0: Dictionary = fv._body["s0"]
	# ⚠ **Read on the SAME frame, off the body the code wrote both onto.** Two separate reads a frame
	# apart would pass for two clocks started a frame apart, which is the thing this row exists for.
	t.ok(float(s0["lunge"]) > 0.0, "그 프레임에 런지가 켜졌다 (%.3f초 남음)" % float(s0["lunge"]))
	t.ok(float(s0["bite"]) > 0.0, "그리고 같은 프레임에 물기도 켜졌다 (%.3f초 남음)" % float(s0["bite"]))
	t.ok(is_equal_approx(float(s0["bite"]), fv._anim_sec(Rules.WOLF, Look.Anim.BITE)),
		"물기 시계는 띠 길이 그대로 시작한다 (%.2f초)" % fv._anim_sec(Rules.WOLF, Look.Anim.BITE))
	t.eq(fv._body_tex("s0", Rules.WOLF, true), bite[0],
		"입은 다문 첫 장부터 열린다 — 여기서 어긋나면 무는 순간이 이미 벌어진 입이다")

	# The sim is FROZEN from here — `begin_frame` still clears the event list, so nothing re-fires and
	# the strip is watched alone. A second blow mid-strip would make the sequence below meaningless.
	var seq: Array[int] = []
	for k in 40:
		b.begin_frame()
		fv._process(1.0 / 60.0)
		if float((fv._body["s0"] as Dictionary)["bite"]) <= 0.0:
			break
		seq.append(bite.find(fv._body_tex("s0", Rules.WOLF, true)))
	t.ok(seq.size() >= 20, "무는 동안 %d 프레임을 봤다 — 0.48초면 28 남짓이다" % seq.size())
	var back := 0
	var out := 0
	for k in seq.size():
		if seq[k] < 0:
			out += 1
		elif k > 0 and seq[k - 1] >= 0 and seq[k] < seq[k - 1]:
			back += 1
	t.eq(out, 0, "무는 내내 물기 띠 안의 그림을 입는다 %s" % str(seq))
	t.eq(back, 0, "그리고 한 번도 앞 장으로 안 돌아간다 — 한 번만 재생한다 %s" % str(seq))
	t.eq(seq[seq.size() - 1], bite.size() - 1,
		"마지막에 넷째 장까지 간다 — 못 닿으면 제일 크게 벌린 입이 화면에 안 나온다 %s" % str(seq))

	b.begin_frame()
	fv._process(1.0 / 60.0)
	t.ok(float((fv._body["s0"] as Dictionary)["bite"]) <= 0.0, "물기가 끝났다 (자가 점검)")
	t.ok(walk.find(fv._body_tex("s0", Rules.WOLF, true)) >= 0,
		"그리고 걷기 띠로 돌아간다 — 안 돌아가면 입을 벌린 채 남은 싸움을 한다")

	# ⚠ The other eight, through the SAME call: the enemy standing right there has no strip at all.
	t.eq(fv._body_tex("e0", Rules.WOLF, true), fv._beast_tex(Rules.WOLF, true),
		"띠 없는 종은 같은 호출로 서 있는 그림을 받는다")
	t.ok(fv._body_tex("e0", Rules.WOLF, true) != null, "그리고 그 그림은 비어 있지 않다")


# == 티켓 15: the bleed reaches the screen ============================================================
## ⚠⚠ **`field_view` had ZERO lines reading `status_time` before this**, so 출혈 was the one beast
## passive that happened entirely inside the sim. Four of the five come out as a body's POSITION or
## its target and the field already draws those; without this row 「어느 짐승을 데려갈까」 would be a
## four-way decision on screen and a five-way one in the rules.
##
## ⚠⚠ **BOTH ENDS, and the bleeding body is compared against a SIBLING OF THE SAME SPECIES** — not
## against its own earlier colour, which a hit flash also moves. Floor: the two differ while the
## clock runs. Ceiling: they are byte-identical once it expires, so a tint that never turned off
## would redden too.
##
## ⚠ **The bleed is driven through a real crow blow**, never by writing `status_time` — a fixture that
## sets the value it then reads back measures the view and not the seam between them.
##
## ⚠ Mutation: drop the `Look.bleeding` call in `_paint_bodies`; clamp `bleeding` to return `col`.
func _a_bleeding_body_is_a_different_colour(t) -> void:
	var rows := _open(ARENA_W, ARENA_H)
	var b := _battle_of(rows, _army_of([Rules.CROW]), [
		_spawn(ARENA_W, Rules.WOLF, 6, 5),    # 0 — bitten
		_spawn(ARENA_W, Rules.WOLF, 18, 9),   # 1 — the control sibling, far away
	])
	_ashore(b, 0, Vector2(3, 5))
	b.begin_frame()
	b.step(Rules.SIM_SUBSTEP_SEC)
	t.ok(b.status_left(Rules.Status.BLEED, 0) > 0.0, "0번 적이 출혈 중이다 (자가 점검)")
	t.eq(b.status_left(Rules.Status.BLEED, 1), 0.0, "1번 적은 아니다 (자가 점검)")

	var fv := _view_of(b, rows)
	fv._process(0.0)
	# ⚠ **Aged past the hit flash before the colours are read.** The flash pulls the bitten body toward
	# white on its own, so reading on the blow's own frame would be green with the tint deleted.
	fv._process(Look.HIT_FLASH_SEC * 2.0)
	var bleeding := _sprite_nearest(fv, b.enemy_pos[0])
	var clean := _sprite_nearest(fv, b.enemy_pos[1])
	t.ok(bleeding != null and clean != null, "두 몸을 화면에서 찾았다 (자가 점검)")
	t.ok(bleeding.modulate != clean.modulate,
		"출혈 중인 몸의 색이 같은 종의 안 출혈인 몸과 다르다 — 바닥 (%s vs %s)"
			% [str(bleeding.modulate), str(clean.modulate)])
	# ⚠ **Compared against the SIBLING and never against `body_colour_of` itself**: `_put_body` mixes
	# the body colour into the sprite (`BEAST_TEAM_TINT`), so the raw team colour is not what reaches
	# `modulate` — an equality against it would be measuring the mix, not the tint.
	var clean_rest := clean.modulate

	# ⚠⚠ **THE HUE, AND NOT ONLY THAT THE TWO DIFFER.** Mixed the other way round — bleed first, then
	# the faction tint 45% back toward white — the pull was mostly thrown away: measured on cloth the
	# body's hue did not move at all and only its brightness fell 27%, which reads as SHADE rather
	# than as blood. A `modulate != modulate` row is green for that too.
	var bled_share := bleeding.modulate.r \
		/ maxf(bleeding.modulate.r + bleeding.modulate.g + bleeding.modulate.b, 0.001)
	var clean_share := clean_rest.r \
		/ maxf(clean_rest.r + clean_rest.g + clean_rest.b, 0.001)
	t.ok(bled_share > clean_share + 0.03,
		"출혈한 몸에서 붉은 채널이 차지하는 몫이 확실히 더 크다 (%.3f > %.3f) — 색조가 움직인다"
			% [bled_share, clean_share])
	t.ok(Look.bleeding(Color(0.5, 0.5, 0.5), 0.0) == Color(0.5, 0.5, 0.5),
		"안 출혈이면 색을 하나도 안 건드린다 (계기 자가 점검)")

	# The CEILING: park the bitten one out of reach, let the clock run out, and the two agree again.
	var parked := Vector2(ARENA_W - 2, 2)
	b.enemy_pos[0] = parked
	b._enemy_goal[0] = parked
	b._settle(Battle.ENEMY_UID_BASE + 0, parked)
	var secs: float = float(Rules.species_status_of(Rules.CROW).get("sec", 0.0))
	for _k in int(ceil(secs / Rules.SIM_SUBSTEP_SEC)) + 4:
		b.begin_frame()
		b.step(Rules.SIM_SUBSTEP_SEC)
	t.eq(b.status_left(Rules.Status.BLEED, 0), 0.0, "출혈이 끝났다 (자가 점검)")
	fv._process(Look.HIT_FLASH_SEC * 2.0)
	var healed := _sprite_nearest(fv, b.enemy_pos[0])
	t.ok(healed != null, "옮긴 몸도 화면에서 찾았다 (자가 점검)")
	t.eq(healed.modulate, clean_rest,
		"지속 시간이 끝나면 안 출혈인 형제와 정확히 같은 색으로 돌아온다 — 천장")


## The pooled BODY sprite standing nearest tile point `at`. Matched by position rather than by index
## in the pool, so the row still names the right body if the draw order is ever changed.
func _sprite_nearest(fv: FieldView, at: Vector2) -> Sprite3D:
	var want := Vector2(at.x, at.y)
	var best: Sprite3D = null
	var best_d := 1e9
	for k in fv._sprites_used:
		var s: Sprite3D = fv._sprites[k]
		if s.texture == fv._tex_flat:
			continue
		var d := Vector2(s.position.x, s.position.z).distance_to(want)
		if d < best_d:
			best_d = d
			best = s
	return best if best_d < 1.5 else null


# == fixtures =========================================================================================

## Water border, land inside — `net_fx`'s own arena shape.
func _open(w: int, h: int) -> Array:
	var rows := []
	for y in h:
		if y == 0 or y == h - 1:
			rows.append("~".repeat(w))
		else:
			rows.append("~" + ".".repeat(w - 2) + "~")
	return rows


## A bay: rows 3-7 water for the first six columns, land from column 6 on, one harbour at (2,5) —
## `net_fx`'s port, for the rows that need a real boat.
func _port() -> Array:
	var rows := _open(ARENA_W, ARENA_H)
	for y in range(3, 8):
		rows[y] = "~~~~~~" + ".".repeat(ARENA_W - 7) + "~"
	rows[5] = "~~H~~~" + ".".repeat(ARENA_W - 7) + "~"
	return rows


## ⚠ The slots are the ARMY's since 티켓 15, so each species is REGISTERED first and the slot it lands
## in is what recruits.
func _army_of(types: Array) -> Army:
	var a := Army.new()
	for raw in types:
		var ty := int(raw)
		var slot := a.slot_of_type(ty)
		if slot < 0:
			slot = a.register_species(ty)
		a.recruit(slot)
	return a


func _spawn(w: int, type_id: int, x: int, y: int) -> Dictionary:
	return {"type_id": type_id, "tile": y * w + x}


## Committed directly, `net_fx`'s own idiom: an uncommitted battle is inert to every driver and the
## commit gate itself is `net_plan`'s to measure.
func _battle_of(rows: Array, army: Army, spawns: Array) -> Battle:
	var b := _planning_battle_of(rows, army, spawns)
	b._committed = true
	return b


func _planning_battle_of(rows: Array, army: Army, spawns: Array) -> Battle:
	var g := Grid.new()
	g.load_rows(rows)
	var b := Battle.new()
	b.setup(g, army, spawns)
	return b


## Ashore the way a landing leaves a soldier — state, position, goal AND the tile reservation
## (`net_fx`'s helper: state alone teleports the unit back to its stale goal on the first move).
func _ashore(b: Battle, i: int, p: Vector2) -> void:
	b.soldier_state[i] = Battle.SoldierState.ASHORE
	b.soldier_pos[i] = p
	b._soldier_goal[i] = p
	var claimed := b.grid.reserved
	claimed[int(round(p.y)) * b.grid.w + int(round(p.x))] = i
	b.grid.reserved = claimed


func _view_of(b: Battle, rows: Array) -> FieldView:
	var fv := FieldView.new()
	_created.append(fv)
	fv.setup(b, b.army, rows)
	return fv


## An empty committed arena and its view — the fixture every pure-transient row starts from. A quiet
## control frame runs here, and the rows' EXACT counts are what make it bite: geometry left over
## from a leaf firing unconditionally breaks every equality at once.
func _quiet_view() -> Dictionary:
	var rows := _open(ARENA_W, ARENA_H)
	var b := _battle_of(rows, _army_of([]), [])
	var fv := _view_of(b, rows)
	fv._process(0.0)
	return {"fv": fv, "b": b}


## A complete per-body drawer entry, every key `_paint_bodies` reads — injected whole so a fixture
## can light one clock without `_fx_step` refusing to create the rest. ⚠ `last` must be the body's
## OWN position: gait phase turns on distance travelled, and a stale `last` hands the first frame a
## twelve-tile step and a squash nobody asked for.
func _body_entry(at: Vector2) -> Dictionary:
	return {"flash": 0.0, "knock": 0.0, "knock_dir": Vector2.RIGHT, "knock_px": 0.0,
		"lunge": 0.0, "lunge_dir": Vector2.RIGHT, "push": 0.0, "gait": 0.0, "bite": 0.0,
		"walk": 0.0, "head": Vector2.RIGHT, "last": at, "half": 0.0, "still": 0.0}


## The first pooled body sprite — anything not wearing the one-texel bar texture.
func _body_sprite(fv: FieldView) -> Sprite3D:
	for k in fv._sprites_used:
		var s: Sprite3D = fv._sprites[k]
		if s.texture != fv._tex_flat:
			return s
	return null


# == readers ==========================================================================================

## The vertices wearing exactly `col`, on the ground plane (x, z) in tile units.
func _verts_of(v: PackedVector3Array, c: PackedColorArray, col: Color) -> Array:
	var out := []
	for k in v.size():
		if _col_close(c[k], col):
			out.append(Vector2(v[k].x, v[k].z))
	return out


## ⚠ 0.0045 and not tighter, MEASURED: a committed `ArrayMesh` stores vertex colour in 8 bits and
## TRUNCATES (0.235 comes back 0.2314 — a full 1/255 off, not half). The fx buffers hold full floats
## and every pair of look.gd tones this file separates sits far outside 0.0045.
func _col_close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.0045 and absf(a.g - b.g) < 0.0045 \
		and absf(a.b - b.b) < 0.0045 and absf(a.a - b.a) < 0.0045


func _cols_all_close(cols: PackedColorArray, want: Color) -> bool:
	if cols.is_empty():
		return false
	for c in cols:
		if not _col_close(c, want):
			return false
	return true


func _xz_centre_v3(v: PackedVector3Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in v:
		sum += Vector2(p.x, p.z)
	return sum / float(maxi(1, v.size()))


func _max_dist_v3(v: PackedVector3Array, from: Vector2) -> float:
	var out := 0.0
	for p in v:
		out = maxf(out, Vector2(p.x, p.z).distance_to(from))
	return out


func _centre_v3(v: PackedVector3Array) -> Vector3:
	var sum := Vector3.ZERO
	for p in v:
		sum += p
	return sum / float(maxi(1, v.size()))


func _min_dist(pts: Array, from: Vector2) -> float:
	var out := 1e9
	for p: Vector2 in pts:
		out = minf(out, p.distance_to(from))
	return out


## How many vertices sit measurably OFF the plane through `centre` perpendicular to `normal`.
func _off_plane_count(v: PackedVector3Array, centre: Vector3, normal: Vector3) -> int:
	var out := 0
	for p in v:
		if absf((p - centre).dot(normal)) > 0.001:
			out += 1
	return out


## The mesh vertices whose colour is exactly `col` — the terrain rows' reader.
func _mesh_verts_of(verts: PackedVector3Array, cols: PackedColorArray, col: Color) -> Array:
	var out := []
	for k in verts.size():
		if _col_close(cols[k], col):
			out.append(verts[k])
	return out


func _inside_tile(v: Vector3, tx: int, ty: int) -> bool:
	return v.x >= float(tx) - 0.001 and v.x <= float(tx) + 1.001 \
		and v.z >= float(ty) - 0.001 and v.z <= float(ty) + 1.001


func _all_inside_tile(verts: Array, tx: int, ty: int) -> bool:
	if verts.is_empty():
		return false
	for v: Vector3 in verts:
		if not _inside_tile(v, tx, ty):
			return false
	return true
