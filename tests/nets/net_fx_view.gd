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
	# ⚠⚠ **THE BOAT FAMILY RUNS FIRST, AND THAT IS A MEASUREMENT AND NOT A PREFERENCE** (2026-08-30).
	# `_the_bite_rides_the_blow_that_lunges` currently dies on `_body["s0"]` — the fixture's ashore
	# soldier has no body entry — and **a row that dies abandons everything under it**, so on the round this
	# was written the five boat rows below it were not being measured at all and the file still read
	# 59 green. **The order of independent rows carries no meaning; the bite row still reddens where it
	# is**, and nothing here is hidden by moving the boats above it.
	_every_hull_stands_on_its_own_boat(t)
	_the_hull_is_a_committed_mesh_pointing_where_it_sails(t)
	_the_sea_moves_the_hull_and_the_sim_does_not(t)
	_the_deck_carries_eight_riders(t)
	_the_rider_faces_the_screen_and_not_the_compass(t)
	_the_rider_stands_on_the_plank_and_not_on_its_frame(t)
	_the_footing_survives_the_picture_changing(t)
	_every_taken_seat_carries_a_disc_that_rides_the_hull(t)
	_the_disc_is_wider_than_the_wolf_standing_on_it(t)
	_the_hills_never_swallow_the_tier(t)
	_the_first_island_opens_with_room_around_it(t)
	_a_body_lays_one_shadow_disc(t)
	_bodies_sharing_a_piece_are_drawn_apart(t)
	_a_body_stands_on_its_own_tile_and_not_the_next_one(t)
	_the_readers_themselves(t)
	_every_row_wears_its_own_picture(t)
	_the_wolf_ashore_wears_the_picture_that_was_chosen(t)
	for raw in _created:
		var fv: FieldView = raw
		fv.free()
	_created = []
	# **The sentinel.** See `run_nets.done` — without it a `run()` that dies
	# half way still reports every check it managed first, in a shape a healthy net cannot be told from.
	t.done()







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
	# ⚠ **14 since 2026-08-29 and it was 15**: the stair moved out of the plateau's corner onto the
	# middle of its west wall, so the plateau is a clean rectangle and has one boundary corner fewer.
	t.eq(walls, 14, "첫 섬의 층 경계 모서리는 14개다 (자가 점검, 이 수가 0이면 아래가 전부 공허하다)")

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

	# ⚠⚠ **BOTH SCALE FACTORS, BECAUSE BOTH REACH THE SCREEN** (2026-08-30). This read the bare ratio
	# and so measured a width nothing has ever drawn — `BODY_SPRITE_SCALE` has multiplied it since
	# 2026-08-28 and the wolf's own draw column since today. ⚠ **And it is the FRAME**: H's ink fills
	# 72% of it side-on and 24% head-on, so the animal is smaller than whatever this says.
	var wolf_px := Look.body_radius_of(Rules.WOLF) * Look.BEAST_SPRITE_W_RATIO 		* Look.BODY_SPRITE_SCALE * Look.beast_draw_scale(Rules.WOLF) * zoom
	t.ok(wolf_px >= Look.TILE_PX,
		"그 줌에서 늑대가 화면에 %.1fpx 로 선다 — 한 칸(%.0fpx)보다 작아지면 뒤로 그만 빼는 것이다"
			% [wolf_px, Look.TILE_PX])







# == the ground transients ============================================================================





## ⚠⚠ **`_the_refusal_mark` STOOD HERE AND IS DELETED** (2026-08-28). It measured the 26 px
## `COL_LOSE` ring the shell stamped when `Battle.summon` answered -1 — and the summon gesture,
## `note_refusal` and `FxKind.REFUSE` were all deleted with the start button. See `game.gd`.




## ⚠⚠ **A BODY'S WHOLE SHADOW, AND IT IS THE ONLY ONE IT HAS** (2026-08-28, the user: 「그림자도
## 단순하게 아래 동그라미정도해줘」). `field_view._sprite` stops casting a real one — a billboard's cast
## shadow is the shadow of a card that turns to face the camera, and it swings when the board turns.
##
## **One disc per body, in the GROUND buffer, at the body's own centre.** The vertex count is
## `maxi(8, ceil(TAU·r / FX_GROUND_STEP_PX)) · 3`, and it is read back rather than typed: the radius
## comes from the species table through two ratios, and a literal here would be a third copy of them.
##
## ⚠ **The floor is that the count RISES with a second body.** One body's disc is equally consistent
## with a drawer that ignores its argument and lays exactly one disc for the whole frame.
##
## ⚠ Mutation: drop `_put_ground_shadow`'s call out of `_put_body` and both counts go to zero.
func _a_body_lays_one_shadow_disc(t) -> void:
	var rows := _open(ARENA_W, ARENA_H)
	# ⚠ **IT STOOD ENEMIES HERE UNTIL 2026-08-29** and stands the company instead — the enemies are
	# deleted, and a shadow belongs to a body whichever side it is on.
	var b := _battle_of(rows, _army_of([Rules.SWORDSMAN, Rules.SWORDSMAN]), [])
	_ashore(b, 0, Vector2(14.0, 6.0))
	var fv := _view_of(b, rows)
	fv._process(0.0)
	var one := _verts_of(fv._g_v, fv._g_c, Look.COL_BODY_SHADOW)
	t.ok(one.size() > 0, "몸 하나가 바닥에 그림자를 놓는다 (%d 정점)" % one.size())
	t.eq(one.size() % 3, 0, "그리고 삼각형으로 떨어진다 — 원판은 부채꼴이다")
	# The disc sits under the body it belongs to, not at the origin and not at the camera.
	var centre := Vector2.ZERO
	for pt: Vector2 in one:
		centre += pt
	centre /= float(one.size())
	# ⚠ **Tile CENTRES.** `Look.tile_point_px` puts 조각 (14,6) at (14.5, 6.5) in tile units, and a
	# bare (14, 6) here would be its corner — the half-조각 error this repo has paid for once.
	t.ok(centre.distance_to(Vector2(14.5, 6.5)) < 0.2,
		"그 원판의 한가운데가 그 몸 발밑이다 (%.2f, %.2f)" % [centre.x, centre.y])

	# ⚠ **The floor: a SECOND body lays a SECOND disc.** Without this the row above is equally true of
	# a drawer that lays one disc per frame regardless of how many bodies there are.
	var b2 := _battle_of(rows, _army_of([Rules.SWORDSMAN, Rules.SWORDSMAN]), [])
	_ashore(b2, 0, Vector2(14.0, 6.0))
	_ashore(b2, 1, Vector2(11.0, 6.0))
	var fv2 := _view_of(b2, rows)
	fv2._process(0.0)
	var two := _verts_of(fv2._g_v, fv2._g_c, Look.COL_BODY_SHADOW)
	t.ok(two.size() > one.size(),
		"몸이 둘이면 그림자도 둘이다 (%d -> %d 정점) — 프레임당 하나가 아니다" % [one.size(), two.size()])


## **Two bodies on ONE 조각 are drawn in two places, and a body standing alone is not moved at all.**
##
## ⚠⚠ **A 조각 ADMITS `Rules.TILE_CAPACITY` BODIES SINCE 2026-08-30** (the user at the screen: about
## nine to a 칸). The sim walks every one of them to the same 조각 centre, so **without a spread the
## count changes and the screen does not** — the second body is hidden exactly behind the first, which
## is this repo's own named 「screen changes but the sim doesn't」 wearing its other face.
##
## ⚠ **The alone row is the floor.** A drawer that scattered every body unconditionally would pass the
## apart row on its own, and it would have moved the single-body picture nobody asked to move.
## ⚠ **Inside its own 조각 is the ceiling.** A spread past half a 조각 draws a body standing on its
## neighbour, and the reservation it holds would then disagree with the ground it appears to be on.
##
## ⚠ Mutation: make `Look.crowd_offset_px` answer `Vector2.ZERO` and the apart row reddens; make it
## answer for slot 0 too and the alone row does.
func _bodies_sharing_a_piece_are_drawn_apart(t) -> void:
	var rows := _open(ARENA_W, ARENA_H)
	var b := _battle_of(rows, _army_of([Rules.SWORDSMAN, Rules.SWORDSMAN]), [])
	_ashore(b, 0, Vector2(14.0, 6.0))
	_ashore(b, 1, Vector2(14.0, 6.0))
	var tile := b.grid.tile_index(14, 6)
	t.eq(b.grid.hold_count(tile), 2, "몸 둘이 한 조각에 서 있다 (자가 점검)")
	t.eq(b.grid.slot_of(tile, 0), 0, "첫 몸이 0번 자리다 (자가 점검)")
	t.eq(b.grid.slot_of(tile, 1), 1, "둘째 몸이 1번 자리다 (자가 점검)")
	t.ok((b.soldier_pos[0] as Vector2).is_equal_approx(b.soldier_pos[1] as Vector2),
		"그리고 sim 의 자리는 완전히 같다 — 갈라놓는 것은 그림뿐이다 (자가 점검)")

	var fv := _view_of(b, rows)
	fv._process(0.0)
	var at := _body_spots(fv)
	t.eq(at.size(), 2, "화면에 몸이 둘 그려졌다 (자가 점검)")
	if at.size() < 2:
		return
	var apart: float = (at[0] as Vector2).distance_to(at[1] as Vector2)
	var want := Look.crowd_offset_px(1, Rules.TILE_CAPACITY).length() / Look.TILE_PX
	t.ok(want > 0.01, "자리마다 밀어내는 거리가 실제로 있다 (%.3f 조각 — 자가 점검)" % want)
	t.ok(absf(apart - want) < 0.01,
		"한 조각에 선 둘이 %.3f 조각 떨어져 그려진다 (기대 %.3f)" % [apart, want])

	# **Inside its own 조각**, both of them — a spread past half a 조각 stands a body on its neighbour.
	for raw_pt in at:
		var pt: Vector2 = raw_pt
		t.ok(pt.distance_to(Vector2(14.5, 6.5)) < 0.5,
			"그러고도 제 조각 안이다 (%.2f, %.2f)" % [pt.x, pt.y])

	# ⚠ **The floor: a body ALONE is not moved.** Slot 0 is the 조각 centre, so the single-body picture
	# is exactly what it was before crowds existed.
	var solo := _battle_of(rows, _army_of([Rules.SWORDSMAN, Rules.SWORDSMAN]), [])
	_ashore(solo, 0, Vector2(14.0, 6.0))
	var fv2 := _view_of(solo, rows)
	fv2._process(0.0)
	var one := _body_spots(fv2)
	t.eq(one.size(), 1, "혼자 선 몸 하나만 그려졌다 (자가 점검)")
	if one.is_empty():
		return
	t.ok((one[0] as Vector2).distance_to(Vector2(14.5, 6.5)) < 0.01,
		"혼자면 조각 한가운데 그대로다 — 무조건 흩뿌리는 게 아니다 (%.3f, %.3f)"
			% [(one[0] as Vector2).x, (one[0] as Vector2).y])



## ⚠⚠ **A BODY ON THE LIP OF THE PLATEAU SANK INTO THE GROUND** (2026-08-28, the user: 「지금보면
## 땅속으로 들어감 2층 에서 보셈」). The foot height was asked as `centre_px / Look.TILE_PX` — and
## `Look.tile_point_px` puts a tile centre **half a tile along both axes**, so the sample landed at
## `pos + 0.5` and `Grid.surface_h` rounded it onto the NEXT tile. On the edge of the plateau the next
## tile is the floor a storey down, so the body was drawn standing at the low tile's height while
## actually being on the high one.
##
## ⚠ **The y axis was off by a different amount than the x**, because `TILE_H_PX` need not equal
## `TILE_PX` — which is why this is measured on BOTH axes and on a boundary, not on open ground where
## a half-tile error reads as nothing.
##
## ⚠ Mutation: pass `centre_px / Look.TILE_PX` back into `_stand_h` and the body on the high tile drops
## to the low tile's height.
func _a_body_stands_on_its_own_tile_and_not_the_next_one(t) -> void:
	# ⚠⚠ **THE PLATEAU IS ON THE WEST AND THE BODY STANDS ON ITS EAST LIP**, and that orientation is
	# the whole of the row. The bad sample was `pos + 0.5`, which rounds to the tile **east** of the
	# body — so a plateau whose edge faced the other way would put both samples on the SAME tile and
	# the check would pass against the very defect it is written for. **Measured: it did, first try.**
	var rows := _open(ARENA_W, ARENA_H)
	var tiers := []
	for y in ARENA_H:
		var row := ""
		for x in ARENA_W:
			row += "2" if x <= 8 else "."
		tiers.append(row)
	var b := _battle_of(rows, _army_of([Rules.WOLF]), [_spawn(ARENA_W, Rules.WOLF, 8, 6)], tiers)
	var fv := _view_of(b, rows, tiers)
	fv._process(0.0)
	var g := b.grid
	t.eq(g.level_of(g.tile_index(8, 6)), 2, "몸이 선 조각이 2층이다 (자가 점검)")
	t.eq(g.level_of(g.tile_index(9, 6)), 0, "그 동쪽 조각은 1층이다 (자가 점검 — 반 조각 밀리면 여기로 간다)")

	var s := _body_sprite(fv)
	t.ok(s != null, "몸이 그려졌다 (자가 점검)")
	# The body's own tile height, and the tile next to it. They must differ, or this row proves nothing.
	var high := g.surface_h(Vector2(8.0, 6.0)) + Islands.base_h()
	var low := g.surface_h(Vector2(9.0, 6.0)) + Islands.base_h()
	t.ok(high > low + 0.5, "두 조각의 높이가 한 층 벌어져 있다 (%.3f vs %.3f — 자가 점검)" % [high, low])

	# `_put_body` returns the TOP; the foot is the sprite's centre minus half its drawn height.
	var foot: float = s.position.y - s.scale.y * float(s.texture.get_height()) * 0.5 / Look.TILE_PX
	t.ok(absf(foot - (high + Look.BODY_LIFT_PX / Look.TILE_PX)) < 0.02,
		"발이 자기 조각(2층)의 높이에 있다 (%.3f, 기대 %.3f)"
			% [foot, high + Look.BODY_LIFT_PX / Look.TILE_PX])
	t.ok(foot > low + 0.5,
		"그리고 동쪽 조각(1층) 높이가 아니다 — 반 조각 밀려 읽으면 여기가 문다 (%.3f vs %.3f)" % [foot, low])


# == the air transients ===============================================================================













# == the dry slot draws no plan — ⚠⚠ DELETED 2026-08-28 =============================================
## It measured `_paint_plan`'s reserve gate: an armed slot with nothing left drew neither ring nor
## route, so the screen could not promise a drop `Battle.summon` would refuse. **`_paint_plan` is
## deleted** with the whole summon gesture — there is no plan layer left to gate. See `game.gd`.




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
	# ⚠⚠ **IT STOOD ONE BODY PER TABLE ROW AND READ THE POOL BACK** until 2026-08-29. Only the player's
	# rows can stand on the island now, so the census is asked of the PICTURE TABLE directly — which is
	# what the row was ever about: **counting bodies alone stays green while five of them share one
	# drawing.**
	var b := _battle_of(rows, _army_of([Rules.SWORDSMAN]), [])
	_ashore(b, 0, Vector2(6.0, 6.0))
	var fv := _view_of(b, rows)
	fv._process(0.0)
	var seen := {}
	for ty in Rules.UNITS.size():
		var tex := fv._beast_tex(ty, Vector2.RIGHT)
		t.ok(tex != null, "%d 번 줄에 그림이 있다" % ty)
		seen[tex] = int(seen.get(tex, 0)) + 1
	t.eq(seen.size(), Rules.UNITS.size(),
		"표의 줄마다 저마다 다른 그림을 쓴다 — 개수만 세면 다섯이 늑대 그림 하나를 나눠 써도 맞는다")
	# The floor: a body really does reach the pool wearing one of them.
	t.ok(fv._sprites_used > 0, "그리고 몸이 실제로 화면에 섰다 (자가 점검)")
	# The `is_enemy` argument is gone, so the same row facing the same way is the same picture whoever
	# is asking. Asserted as an EQUALITY, which is what a deleted selector actually means.
	t.eq(fv._beast_tex(Rules.WOLF, Vector2.RIGHT), fv._beast_tex(Rules.WOLF, Vector2.RIGHT),
		"같은 줄은 같은 그림을 준다 — 묻는 쪽이 편을 안 고른다")


## **The wolf on the island is the picture the user chose, and it faces four ways.**
##
## ⚠⚠ **IT REPLACES `_the_bite_rides_the_blow_that_lunges`, WHOSE SUBJECT NO LONGER EXISTS**
## (2026-08-30). That row watched the 46 side-view walk and bite frames; **H is 92 x 92 with no frames
## at all**, so the wolf's row declares none and there is no strip left to watch. ⚠ **That row had also
## been dead since 2026-08-29** — it read `push` and `lunge` off a body entry the fight's deletion took
## away — so what it measured had already stopped being measured.
##
## ⚠⚠ **티켓 48 WAS MARKED RESOLVED WHILE THIS WAS FALSE.** H reached the boat deck and the island kept
## walking `wolf_r.png`, because the deck named its four pictures in a list of its own and the wolf's
## row named the old animal. **This is the row that would have caught it**: it reads the wolf's own row,
## which is now the only place either surface looks.
##
## ⚠ Mutation: point the wolf's row back at `wolf_r.png` / `wolf_l.png`; drop its two head-on pictures;
## give the bear four; foot the body on its frame instead of its ink.
func _the_wolf_ashore_wears_the_picture_that_was_chosen(t) -> void:
	# **The row itself, before anything is drawn.** ⚠ The paths are read off `Look`, not off the pool:
	# a pool that loaded nothing is `null` four times and「four pictures」 would still be green.
	t.eq(Look.beast_facings(Rules.WOLF), 4, "늑대 줄이 그림 넉 장을 든다 — 좌·우·앞·뒤")
	var paths := []
	for f in Look.beast_facings(Rules.WOLF):
		paths.append(Look.beast_tex_path(Rules.WOLF, f))
	var h_count := 0
	for raw in paths:
		if str(raw).contains("wolf_h/"):
			h_count += 1
	t.eq(h_count, 4, "넉 장이 전부 사용자가 고른 H 다 %s" % str(paths))
	t.eq(_distinct(paths), 4, "그리고 서로 다른 파일 넷이다 %s" % str(paths))
	for raw in paths:
		t.ok(not str(raw).ends_with("wolf_r.png") and not str(raw).ends_with("wolf_l.png"),
			"옛 옆모습 늑대가 한 장도 안 남았다 (%s)" % str(raw))
	# ⚠ **The other rows keep the two they had.** Fixing one row by breaking three is the failure this
	# guards, and it is the shape 「a list per species」 was chosen to make impossible.
	# ⚠⚠ **THE SWORDSMAN LEFT THIS LIST 2026-08-31.** He was a 33 x 40 side-on chibi with two pictures;
	# the user chose a new body and asked for the turned views, so his row now names four files of its
	# own. **He is checked on the four-picture side below**, which is the same guard pointed the other
	# way — the row that must NOT break is now bear and crow.
	for ty in [Rules.BEAR, Rules.CROW]:
		t.eq(Look.beast_facings(ty), 2, "%d 번 줄은 좌우 두 장 그대로다" % ty)
	t.eq(Look.beast_facings(Rules.SWORDSMAN), 4, "검사 줄도 그림 넉 장을 든다 — 좌·우·앞·뒤")
	var man_paths := []
	for f in Look.beast_facings(Rules.SWORDSMAN):
		man_paths.append(Look.beast_tex_path(Rules.SWORDSMAN, f))
	t.eq(_distinct(man_paths), 4, "그리고 서로 다른 파일 넷이다 %s" % str(man_paths))
	for raw in man_paths:
		t.ok(not str(raw).contains("sword_"), "옛 칼든 검사가 한 장도 안 남았다 (%s)" % str(raw))

	# **A two-picture row can never answer with a head-on picture, whatever way it walks.** Asked at the
	# heading that would pick one if the row had it — straight down the screen.
	#
	# ⚠⚠ **THE FIXTURE IS THE BOAT'S, DRIVEN UNTIL THE FIRST HULL HAS UNLOADED**, because a spawn alone
	# no longer stands a beast on the island — they come by boat since 티켓 41, and three functions in
	# this file are red on exactly that. **These wolves walked off a deck**, which is also the only way
	# to have one ashore and one aboard in one frame.
	var pack := _boat_view(Rules.BOAT_FIRST_SEC + Rules.BOAT_INTERVAL_SEC)
	var fv: FieldView = pack["fv"]
	var b: Battle = pack["b"]
	fv.cam_yaw_deg = 0.0
	for ty in [Rules.BEAR, Rules.CROW]:
		t.ok(fv._facing_index(ty, Vector2(0.0, 1.0)) <= Look.FACE_LEFT,
			"%d 번 줄은 화면 아래로 걸어도 옆모습 둘 중 하나다" % ty)
	# ⚠ **And the swordsman now goes the wolf's way**, because the row's own length is what decides it.
	t.eq(fv._facing_index(Rules.SWORDSMAN, Vector2(0.0, 1.0)), Look.FACE_DOWN,
		"검사도 화면 아래로 걸으면 앞모습이다")
	# And the wolf, which does have them, does not.
	t.eq(fv._facing_index(Rules.WOLF, Vector2(0.0, 1.0)), Look.FACE_DOWN,
		"늑대는 화면 아래로 걸으면 앞모습이다 — 넉 장을 든 줄만 여기로 온다")
	t.eq(fv._facing_index(Rules.WOLF, Vector2(0.0, -1.0)), Look.FACE_UP, "위로 걸으면 뒷모습이다")

	# **And a body really did reach the pool wearing one of the four**, read off the sprite the engine
	# consumes rather than off the lookup that chose it.
	# ⚠ **Sprite 0 is the first living beast**: `_paint_bodies` walks the beasts, then the company, then
	# the decks, and this fixture has no company. The count beside it is the self-check.
	var ashore := b.living_enemy_ids().size()
	t.ok(ashore > 0, "늑대가 배에서 내려 판 위에 %d 마리 서 있다 (자가 점검)" % ashore)
	t.ok(fv._sprites_used > ashore, "그리고 갑판에도 아직 남아 있다 (자가 점검) — 한 프레임에 둘 다 있다")
	if ashore <= 0 or fv._sprites_used <= 0:
		return
	var sp: Sprite3D = fv._sprites[0]
	t.ok(paths.has(str(sp.texture.resource_path)),
		"판 위의 몸이 입은 것이 늑대 줄의 그림이다 (%s)" % str(sp.texture.resource_path))
	t.eq(Vector2i(sp.texture.get_width(), sp.texture.get_height()), Vector2i(92, 92),
		"92 x 92 다 — 74 x 40 이 남아 있으면 여기서 문다")

	# **It stands on the animal and not on the frame around it.** ⚠ The padding is scanned off the PNG's
	# own alpha, never asked of `_foot_body` — reading the view's answer back at it is the shape that put
	# five green checks over five real defects in one day.
	# ⚠⚠ **THE GROUND IS ASKED OF `Grid` AND `Islands`, WHICH ARE SIM**, never of the view's own
	# `_stand_h`. ⚠ **And it is NOT zero on a flat arena**: the Blender island's level-0 top stands
	# `Islands.base_h()` above zero, which cost a round in 2026-08-27 when a plate was drawn at zero and
	# spent the whole session underground.
	var who := int(b.living_enemy_ids()[0])
	var stands: Vector2 = b.enemy_pos[who]
	var tall := float(sp.texture.get_height()) * sp.scale.y / Look.TILE_PX
	var pad := _ink_pad_below(sp.texture)
	var ground := b.grid.surface_h(stands) + Islands.base_h() + Look.BODY_LIFT_PX / Look.TILE_PX
	var frame_bottom := sp.position.y - tall * 0.5
	t.ok(absf(frame_bottom + pad * tall - ground) < 0.0005,
		"늑대의 발이 땅에 정확히 닿는다 (어긋난 높이 %.6f 조각)" % absf(frame_bottom + pad * tall - ground))
	# The second half: the FRAME hangs below the ground by exactly the empty rows. Without it a view
	# that never changed would have to be caught by arithmetic alone.
	t.ok(ground - frame_bottom > 0.05,
		"그림틀의 아래끝은 땅보다 %.4f 조각 아래다 — 땅에 세운 것은 틀이 아니라 짐승이다"
			% (ground - frame_bottom))

	# **How big it is drawn, which is the other half of what the user said.** The frame is what the
	# ratio sizes; the animal inside it is what he was looking for.
	var frame_px := float(sp.texture.get_width()) * sp.scale.x
	var ink_px := _ink_width_frac(sp.texture) * frame_px
	t.ok(ink_px > 20.3,
		"늑대가 옛 늑대(20.3px)보다 넓게 그려진다 (틀 %.1fpx 안에 짐승 %.1fpx)" % [frame_px, ink_px])


## How many distinct entries an array holds.
func _distinct(items: Array) -> int:
	var seen := {}
	for raw in items:
		seen[raw] = true
	return seen.size()



## The pooled BODY sprite standing nearest tile point `at`. Matched by position rather than by index
## in the pool, so the row still names the right body if the draw order is ever changed.
# == the beasts' boat, on screen ======================================================================
## **티켓 41's view half.** The sim's boat is a `Vector2` and a beach 조각; everything below is what the
## eye is given on top of that, and none of it is measurable at the `sim` seam — `net_boats` drives that
## half and is deliberately tree-free.
##
## ⚠ **Measured on the two surfaces `CONTEXT.md` names for this seam**: the pooled `Sprite3D` fields the
## engine consumes, and **the committed surface count** — a hull whose mesh has zero surfaces is a node
## in the right place drawing nothing, and every transform check about it stays green.


## **Every hull is drawn where its OWN boat is, and every rider on the hull it belongs to.**
##
## ⚠⚠ **NOTHING IN THIS FILE READ A HULL'S x OR z UNTIL THIS ROW, AND THREE MUTATIONS PROVED IT.** Run
## against the suite before it existed, all three came back fully green: **every hull parked at the
## world origin**, **riders placed from their bare deck offsets with the hull ignored**, and **only the
## first boat ever drawn**. A picture can be entirely detached from the sim and still satisfy a surface
## count, a bow angle and a bob.
##
## ⚠⚠ **TWO BOATS, BECAUSE ONE CANNOT SEE ANY OF IT.** With a single hull 「drawn at the boat」 and
## 「drawn at the only place there is」 are the same sentence, and 「only the first is drawn」 is
## unfalsifiable. The acceptance line 티켓 41 carries — 「the next boat comes to a different side」 — is
## a claim about the SCREEN and this is the only row that measures it there.
##
## ⚠ **The expected point goes through `Look.tile_point_px`**, the same conversion every body uses, so
## a 조각 centre is half a 조각 along both axes and this row cannot silently accept a corner.
func _every_hull_stands_on_its_own_boat(t) -> void:
	var pack := _boat_view(Rules.BOAT_FIRST_SEC + Rules.BOAT_INTERVAL_SEC)
	var fv: FieldView = pack["fv"]
	var b: Battle = pack["b"]
	t.eq(b.boat_pos.size(), 2, "sim 에 배가 둘 떠 있다 (자가 점검 — 하나면 아래가 전부 공허하다)")
	t.eq(fv._boats_used, 2, "선체도 둘 쓰였다 — 첫 배만 그리는 게 아니다")

	var worst := 0.0
	var seen: Array = []
	for i in b.boat_pos.size():
		var want := Look.tile_point_px(b.boat_pos[i] as Vector2) / Look.TILE_PX
		var hull: Node3D = fv._boats[i]
		var got := Vector2(hull.position.x, hull.position.z)
		worst = maxf(worst, got.distance_to(want))
		seen.append(got)
	t.ok(worst < 0.001,
		"선체 둘 다 제 배가 선 자리에 그려져 있다 (제일 어긋난 거리 %.6f 조각)" % worst)

	# The self-check that makes the row above a claim: the two boats are NOT in the same place, so a
	# drawer that parked every hull on one point — the origin included — has to fail it.
	var apart := (seen[0] as Vector2).distance_to(seen[1] as Vector2)
	t.ok(apart > 1.0, "그리고 둘이 %.1f 조각 떨어져 그려진다 — 한 점에 겹쳐 있지 않다" % apart)
	t.ok((seen[0] as Vector2).length() > 1.0 and (seen[1] as Vector2).length() > 1.0,
		"자가 점검 — 둘 다 원점이 아니다: 전부 (0,0) 에 그려도 위가 문다")

	# **Every rider belongs to a hull.** ⚠ Assigned by nearest hull rather than by index, because the
	# sprite pool hands them out in one flat run — a rider placed from its bare deck offset with the
	# hull ignored lands near the origin and is counted against neither.
	var count := [0, 0]
	var stray := 0
	var reach := Rules.BOAT_HULL_HALF_TILES + 1.0
	for raw_sp in _rider_sprites(fv, b):
		var sp: Sprite3D = raw_sp
		var at := Vector2(sp.position.x, sp.position.z)
		var best := -1
		var best_d := reach
		for i in seen.size():
			var d: float = at.distance_to(seen[i] as Vector2)
			if d < best_d:
				best_d = d
				best = i
		if best < 0:
			stray += 1
		else:
			count[best] += 1
	t.eq(stray, 0, "갑판 늑대가 전부 어느 한 선체 옆에 서 있다 — 배와 상관없는 자리에 선 것이 없다")
	# ⚠⚠ **READ OFF `boat_riders` AND NOT PINNED AT EIGHT** (2026-08-30, 티켓 41's 목~일 slice). By 35
	# seconds the first boat has already unloaded, so 「첫 배에 여덟」 became a claim about an EMPTY deck
	# — and pinning it there would be asserting the landing away. **What a deck draws is what is still
	# aboard**, which is the claim that survives riders becoming bodies. The two floors under it are the
	# next two rows: one deck full, one deck empty, so this pair can never be 「0 == 0」 twice.
	t.eq(count[0], int(b.boat_riders[0]),
		"첫 배의 갑판에 아직 탄 수만큼 서 있다 (%d)" % int(b.boat_riders[0]))
	t.eq(count[1], int(b.boat_riders[1]),
		"둘째 배의 갑판도 그렇다 — 둘째 배도 실제로 그려진다 (%d)" % int(b.boat_riders[1]))
	t.eq(int(b.boat_riders[0]), 0, "먼저 온 배는 다 내려놨다 — 갑판이 비면 그림도 빈다")
	t.eq(int(b.boat_riders[1]), Rules.BOAT_CAPACITY, "아직 건너는 배에는 여덟이 그대로 타 있다")


## **The hull is a real committed mesh, and its bow points where it is sailing.**
##
## ⚠⚠ **THE SURFACE COUNT IS HALF THE ROW AND NOT A SELF-CHECK.** `boat.glb` had never been imported by
## Godot before this ticket — no `.import` sat beside it — so `load(...) as PackedScene` coming back
## null is a live failure mode, and it produces a frame with no hull, no error, and a pool that is
## simply empty. **Position and rotation cannot see it; a surface count can.**
##
## ⚠⚠ **THE YAW IS READ OFF THE BASIS AND NOT OFF `rotation.y`, DELIBERATELY.** The roll is applied with
## `rotate_object_local` AFTER the yaw, so the composed Euler's y is no longer the heading. **The model's
## bow is its local +X** (measured off the file: `boat_stem` at x = +2.30, `boat_tail` at −2.26), and a
## roll about that same axis cannot move it — so `basis.x` IS the heading, exactly, and comparing it
## needs no second copy of the `atan2` the view runs.
func _the_hull_is_a_committed_mesh_pointing_where_it_sails(t) -> void:
	var pack := _boat_view()
	var fv: FieldView = pack["fv"]
	var b: Battle = pack["b"]
	t.eq(b.boat_pos.size(), 1, "판에 배가 한 척 떴다 (자가 점검 — 없으면 아래가 전부 공허하다)")
	t.eq(fv._boats_used, 1, "그 배마다 선체 노드가 하나씩 쓰였다")
	t.eq(fv._boats.size(), 1, "그리고 풀에도 하나뿐이다 — 프레임마다 새로 만들지 않는다")

	var hull: Node3D = fv._boats[0]
	t.ok(hull.visible, "선체가 보이는 상태다")
	t.ok(_surfaces_of(hull) > 0,
		"선체 메시가 면을 %d 개 올렸다 — 노드만 있고 그릴 것이 없는 게 아니다" % _surfaces_of(hull))

	var beach := int(b.boat_beach[0])
	var target := Vector2(beach % b.grid.w, beach / b.grid.w)
	var head := (target - (b.boat_pos[0] as Vector2)).normalized()
	var bow := hull.transform.basis.x
	t.ok(absf(bow.x - head.x) < 0.01 and absf(bow.z - head.y) < 0.01,
		"뱃머리(%.3f, %.3f)가 가는 쪽(%.3f, %.3f)을 본다" % [bow.x, bow.z, head.x, head.y])

	# ⚠⚠ **THE SAME HULL AIMED A SECOND WAY, AND WITHOUT IT THE ROW ABOVE CAN BE VACUOUS.** A fixture
	# whose first beach happens to lie due east has a heading of exactly the model's own +X, and a hull
	# that was never rotated at all passes — measured, on this arena. **Re-aiming is a view-side read**
	# (nothing in `sim` decides a bow), so moving the boat and painting again asks the question the
	# fixture could not.
	b.boat_pos[0] = target + Vector2(-3.0, -4.0)
	fv._process(0.0)
	var again := hull.transform.basis.x
	t.ok(absf(again.x - 0.6) < 0.01 and absf(again.z - 0.8) < 0.01,
		"다른 쪽에서 겨누면 뱃머리도 그쪽(0.600, 0.800)을 따라 돈다 (%.3f, %.3f)" % [again.x, again.z])
	t.ok(absf(again.x - bow.x) > 0.01 or absf(again.z - bow.z) > 0.01,
		"자가 점검 — 두 각도가 실제로 다르다: 안 돌리는 선체는 둘 중 하나에 걸린다")

	# Before the first boat's clock there is nothing to draw, and the pool says so.
	var quiet := _boat_view(0.0)
	t.eq((quiet["fv"] as FieldView)._boats_used, 0, "첫 시각 전에는 선체를 하나도 안 쓴다")


## **The bob and the roll are the SCREEN's, and they move while the sim stands still.**
##
## ⚠⚠ **THE SIM IS NOT STEPPED IN THIS ROW AND THAT IS THE WHOLE MEASUREMENT.** Only `_process` is
## called, so `boat_pos` cannot change — anything that moves is the view's own clock. A bob written into
## `Battle` would pass a 「the boat goes up and down」 check just as well and would put a second clock
## under the game, which is the seam every defect worth the name has come out of here.
##
## ⚠ **Bounded at BOTH ends.** Amplitude alone is 「it moved」, which a hull sliding away forever also
## satisfies; the band is what says it is a bob.
func _the_sea_moves_the_hull_and_the_sim_does_not(t) -> void:
	var pack := _boat_view()
	var fv: FieldView = pack["fv"]
	var b: Battle = pack["b"]
	var hull: Node3D = fv._boats[0]
	var froze: Vector2 = b.boat_pos[0]

	var rest := Look.SEA_Y_TILES + Look.BOAT_DRAFT_TILES
	var lo := 9999.0
	var hi := -9999.0
	var roll_lo := 9999.0
	var roll_hi := -9999.0
	var out_of_band := 0
	var over_roll := 0
	# Seven samples over 3.0 s: `BOAT_BOB_SEC` is 2.2 and `BOAT_ROLL_SEC` 3.1, so this covers more than
	# one whole bob and very nearly one whole roll — a window shorter than the slower period could
	# catch a monotone slide and read it as motion.
	for _k in 7:
		fv._process(0.5)
		var y := hull.position.y
		lo = minf(lo, y)
		hi = maxf(hi, y)
		if absf(y - rest) > Look.BOAT_BOB_TILES + 0.0001:
			out_of_band += 1
		var lean := rad_to_deg(hull.transform.basis.y.angle_to(Vector3.UP))
		roll_lo = minf(roll_lo, lean)
		roll_hi = maxf(roll_hi, lean)
		if lean > Look.BOAT_ROLL_DEG + 0.01:
			over_roll += 1

	t.ok(hi - lo > Look.BOAT_BOB_TILES,
		"선체가 %.4f조각 오르내렸다 — 흔들림이 실제로 움직인다" % (hi - lo))
	t.eq(out_of_band, 0, "그리고 %.3f조각 띠를 한 번도 안 벗어났다 — 떠내려가는 게 아니라 흔들리는 것이다"
		% Look.BOAT_BOB_TILES)
	t.ok(roll_hi - roll_lo > Look.BOAT_ROLL_DEG * 0.5,
		"옆으로도 %.2f도 기울었다 폈다 한다" % (roll_hi - roll_lo))
	t.eq(over_roll, 0, "그 기울기가 %.1f도를 안 넘는다" % Look.BOAT_ROLL_DEG)

	t.ok((b.boat_pos[0] as Vector2).distance_to(froze) <= 0.0,
		"자가 점검 — 그동안 sim 의 배는 한 조각도 안 움직였다: 위가 재는 것은 화면의 시계뿐이다")


## **Eight riders stand on the deck, and they stand ON it.**
##
## ⚠ **Counted off the pooled `Sprite3D` textures**, which is the seam's own surface — a rider drawn by
## some other path would not be one of these, and a rider counted from `boat_riders` would be counting
## the sim twice.
func _the_deck_carries_eight_riders(t) -> void:
	var pack := _boat_view()
	var fv: FieldView = pack["fv"]
	var hull: Node3D = fv._boats[0]

	var riders := 0
	var below_deck := 0
	for raw_sp in _rider_sprites(fv, pack["b"] as Battle):
		var sp: Sprite3D = raw_sp
		riders += 1
		if sp.position.y <= hull.position.y:
			below_deck += 1
	t.eq(riders, Rules.BOAT_CAPACITY, "갑판에 여덟이 서 있다")
	t.eq(below_deck, 0, "여덟 다 선체보다 위다 — 갑판을 뚫고 있지 않다")
	t.eq(Look.BOAT_DECK_SLOTS.size(), Rules.BOAT_CAPACITY, "자리 표가 여덟 줄이다 (자가 점검)")


## **Which of the four `wolf_h` pictures a rider wears is a SCREEN direction, not a compass one.**
##
## ⚠⚠ **THE BOARD TURNS, AND THAT IS THE WHOLE ROW.** A picker written against world north puts a wolf
## facing the wrong way the moment the player presses the turn key — and nothing else on screen moves,
## so it reads as the wolves spinning for no reason. **The same heading is asked twice, at two camera
## yaws, and it must answer two different pictures.**
func _the_rider_faces_the_screen_and_not_the_compass(t) -> void:
	var pack := _boat_view()
	var fv: FieldView = pack["fv"]
	fv.cam_yaw_deg = 0.0
	# ⚠ **The wolf's own row in `Look.BEAST_TEX`, in `Look.FACE_*` order** — screen-right, screen-left,
	# screen-down, screen-up. **The deck has no picture list of its own since 2026-08-30**, which is what
	# makes this row measure the island's wolf and the deck's wolf at once.
	var pics: Array = fv._tex_facing[Rules.WOLF]
	var east: Texture2D = pics[Look.FACE_RIGHT]
	var west: Texture2D = pics[Look.FACE_LEFT]
	var south: Texture2D = pics[Look.FACE_DOWN]
	var north: Texture2D = pics[Look.FACE_UP]
	t.ok(south != north and east != west and south != east,
		"네 그림이 서로 다른 파일이다 (자가 점검)")

	t.ok(fv._beast_tex(Rules.WOLF, Vector2(0.0, 1.0)) == south, "화면 아래로 가면 이쪽을 본 그림이다")
	t.ok(fv._beast_tex(Rules.WOLF, Vector2(0.0, -1.0)) == north, "화면 위로 가면 등을 보인다")
	t.ok(fv._beast_tex(Rules.WOLF, Vector2(1.0, 0.0)) == east, "화면 오른쪽으로 가면 오른쪽 그림이다")
	t.ok(fv._beast_tex(Rules.WOLF, Vector2(-1.0, 0.0)) == west, "왼쪽도 마찬가지다")

	fv.cam_yaw_deg = 90.0
	t.ok(fv._beast_tex(Rules.WOLF, Vector2(0.0, 1.0)) == east,
		"판을 90도 돌리면 같은 방향이 오른쪽 그림이 된다 — 나침반이 아니라 화면 기준이다")


## **The wolf stands on the plank. Its 92 x 92 FRAME does not.**
##
## ⚠⚠ **THE PADDING IS RE-MEASURED HERE, OFF THE PNG'S OWN ALPHA, AND NOT ASKED OF `_foot_body`.**
## Reading the view's own answer back at it is the shape where a check and the code it checks share one
## blind spot — five of those went green in one day. **The net scans the image itself**, so a footing
## computed from the wrong rows fails here even though the view is perfectly self-consistent.
##
## ⚠ **Both halves are asserted.** That the ink sits on the seat is the claim; that the FRAME sits
## BELOW the seat, by exactly the padding, is what makes it a different sentence from the old code —
## without the second half, a view that never changed at all would have to be caught by arithmetic
## alone, and 0.16 조각 is small enough to be lost in a loose tolerance.
func _the_rider_stands_on_the_plank_and_not_on_its_frame(t) -> void:
	var pack := _boat_view()
	var fv: FieldView = pack["fv"]
	var hull: Node3D = fv._boats[0]

	var worst_ink := 0.0
	var least_frame_drop := 1e9
	var seen := 0
	for raw_sp in _rider_sprites(fv, pack["b"] as Battle):
		var sp: Sprite3D = raw_sp
		var slot := hull.transform * (Look.BOAT_DECK_SLOTS[seen] as Vector3)
		var tall := float(sp.texture.get_height()) * sp.scale.y / Look.TILE_PX
		var pad := _ink_pad_below(sp.texture)
		var frame_bottom := sp.position.y - tall * 0.5
		var ink_bottom := frame_bottom + pad * tall
		worst_ink = maxf(worst_ink, absf(ink_bottom - slot.y))
		least_frame_drop = minf(least_frame_drop, slot.y - frame_bottom)
		seen += 1
	t.eq(seen, Rules.BOAT_CAPACITY, "여덟이 다 그려져 있다 (자가 점검 — 0이면 아래가 전부 공허하다)")
	t.ok(worst_ink < 0.0005,
		"늑대의 발이 제 판자 위에 정확히 서 있다 (제일 어긋난 높이 %.6f 조각)" % worst_ink)
	# The padding under the widest picture is 25 rows of 92; at the drawn size that is 0.16 조각. This
	# floor is deliberately well under it and well over zero — what it forbids is「the frame is the
	# feet」, which puts this at exactly 0.
	t.ok(least_frame_drop > 0.05,
		"그리고 그림틀의 아래끝은 판자보다 %.4f 조각 아래다 — 판자에 세운 것은 틀이 아니라 짐승이다"
			% least_frame_drop)


## **The picture changes when the board turns, and the wolf does not rise or sink.**
##
## ⚠⚠ **THIS IS THE ROW A SINGLE PADDING CONSTANT DIES ON.** The four files carry 11, 23, 25 and 25
## empty rows under the animal — one number cannot foot all four, and with one number the deck's whole
## crew steps up and down as the player turns the camera, which is the sort of thing that gets blamed
## on the bob.
## ⚠ **The camera's yaw is what is turned, not the boat's heading** — the seat positions come out of
## the hull's transform and do not move, so anything that shifts is the picture's doing and nothing
## else's.
func _the_footing_survives_the_picture_changing(t) -> void:
	var pack := _boat_view()
	var fv: FieldView = pack["fv"]
	var hull: Node3D = fv._boats[0]

	fv.cam_yaw_deg = 0.0
	fv._process(0.0)
	var first := _rider_feet(fv, pack["b"] as Battle, hull)
	fv.cam_yaw_deg = 90.0
	fv._process(0.0)
	var turned := _rider_feet(fv, pack["b"] as Battle, hull)

	t.ok(first["tex"] != turned["tex"],
		"판을 돌리자 다른 그림을 입었다 (자가 점검 — 같은 그림이면 아래가 공허하다)")
	t.ok(absf(float(first["pad"]) - float(turned["pad"])) > 0.05,
		"그 두 그림의 아래 여백이 서로 %.3f 만큼 다르다 (자가 점검 — 같으면 한 상수로도 통과한다)"
			% absf(float(first["pad"]) - float(turned["pad"])))
	t.ok(float(first["worst"]) < 0.0005 and float(turned["worst"]) < 0.0005,
		"그런데 발 높이는 두 그림 다 판자 위 그대로다 (%.6f · %.6f 조각)"
			% [float(first["worst"]), float(turned["worst"])])


## **Every seat that is taken carries a disc, it is committed geometry, and it goes where the hull
## goes.**
##
## ⚠⚠ **THE SURFACE COUNT IS HALF THE ROW.** A disc whose vertices were built and never committed
## leaves a `MeshInstance3D` that draws nothing, with no error and nothing else to see — the same hole
## `_the_hull_is_a_committed_mesh_pointing_where_it_sails` was written for.
## ⚠⚠ **AND THE WORLD POINT IS WALKED UP THE PARENTS, NOT ASKED OF `hull.transform` BY THE NET.** The
## claim is「the shadow is under the wolf while the boat bobs and rolls」, and a disc hung off `_world`
## with the hull's transform applied by hand would satisfy any check that applied the same transform
## by hand. Walking the actual parent chain is the only version that can tell the two apart.
## ⚠ **An empty seat is measured too**, by cutting the boat's crew to three: a drawer that lights all
## eight discs whatever the count leaves a shadow lying on a bare plank.
func _every_taken_seat_carries_a_disc_that_rides_the_hull(t) -> void:
	var pack := _boat_view()
	var fv: FieldView = pack["fv"]
	var b: Battle = pack["b"]
	var hull: Node3D = fv._boats[0]

	var holder := hull.get_node_or_null(NodePath(FieldView.DECK_SHADOWS))
	t.ok(holder != null, "선체가 제 갑판 그림자를 들고 있다")
	if holder == null:
		return
	t.eq(holder.get_child_count(), Look.BOAT_DECK_SLOTS.size(), "자리마다 원판이 하나씩이다")

	var surfaces := 0
	var verts := 0
	var lit := 0
	var worst_slot := 0.0
	for k in holder.get_child_count():
		var disc := holder.get_child(k) as MeshInstance3D
		var mesh := disc.mesh
		if mesh != null:
			surfaces += mesh.get_surface_count()
			if mesh.get_surface_count() > 0:
				verts += (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		if disc.visible:
			lit += 1
		var want := (Look.BOAT_DECK_SLOTS[k] as Vector3) + Vector3(0.0, Look.BOAT_RIDER_SHADOW_LIFT_TILES, 0.0)
		worst_slot = maxf(worst_slot, disc.position.distance_to(want))
	t.eq(surfaces, Look.BOAT_DECK_SLOTS.size(), "여덟 다 실제로 커밋된 면을 하나씩 들고 있다")
	t.eq(verts, Look.BOAT_DECK_SLOTS.size() * Look.BOAT_RIDER_SHADOW_SEGS * 3,
		"그 면들이 부채꼴 %d 조각짜리 원판이다" % Look.BOAT_RIDER_SHADOW_SEGS)
	t.eq(lit, Rules.BOAT_CAPACITY, "여덟이 다 타 있으니 원판도 여덟 다 켜져 있다")
	t.ok(worst_slot < 0.0005, "원판이 제 자리 바로 위에 놓여 있다 (제일 어긋난 거리 %.6f 조각)" % worst_slot)

	# **The disc rides the hull.** Two view clocks apart, the world point under a rider and the rider
	# itself must have moved by the SAME amount — the bob and the roll live in the hull's transform and
	# nothing else re-applies them.
	var rider0 := _first_rider(fv, pack["b"] as Battle)
	var disc0 := _world_point(holder.get_child(0) as Node3D, fv._world)
	var was_rider := rider0.position
	fv._process(0.7)
	var moved_rider := _first_rider(fv, pack["b"] as Battle).position - was_rider
	var moved_disc := _world_point(holder.get_child(0) as Node3D, fv._world) - disc0
	t.ok(moved_disc.length() > 0.0005,
		"한 프레임 뒤 원판이 %.5f 조각 움직였다 — 배와 같이 흔들린다 (자가 점검)" % moved_disc.length())
	t.ok((moved_rider - moved_disc).length() < 0.0005,
		"그리고 그 움직임이 위에 선 늑대의 것과 같다 — 그림자가 몸 밑에 붙어 있다 (차이 %.6f 조각)"
			% (moved_rider - moved_disc).length())

	# **An empty seat has no shadow.** ⚠ Written into the sim's own count, so the drawer has to read it.
	var crew := b.boat_riders
	crew[0] = 3
	b.boat_riders = crew
	fv._process(0.0)
	var lit_now := 0
	for k in holder.get_child_count():
		if (holder.get_child(k) as Node3D).visible:
			lit_now += 1
	t.eq(lit_now, 3, "셋만 남기자 원판도 셋만 켜져 있다 — 빈 판자에 그림자가 안 남는다")


## **The disc is wider than the animal standing on it, and it is not black.**
##
## ⚠⚠ **`how-nets-lie`'s 「a shadow the size of its caster is not a shadow」, as a check.** Measured
## twice on two subjects an hour apart: a disc sized from its caster's own footprint puts nearly all of
## itself underneath the caster and shows nothing. **The width the animal actually covers is measured
## here off the PNG's alpha and the drawn scale**, not taken from a constant, so a ratio that quietly
## fell under it reddens.
## ⚠ **Size and strength are one decision**, which is the second half of that entry: this disc covers
## about thirteen times the ground disc's area, so its alpha is held at or above the ground's and under
## the 0.45 `COL_BODY_SHADOW` names as the point a disc reads as a hole.
func _the_disc_is_wider_than_the_wolf_standing_on_it(t) -> void:
	var pack := _boat_view()
	var fv: FieldView = pack["fv"]
	var rider := _first_rider(fv, pack["b"] as Battle)
	var ink_w := _ink_width_frac(rider.texture) * float(rider.texture.get_width()) * rider.scale.x / Look.TILE_PX
	var across := Look.boat_rider_shadow_r_tiles() * 2.0
	t.ok(ink_w > 0.1, "갑판 늑대가 %.3f 조각 폭으로 그려져 있다 (자가 점검)" % ink_w)
	t.ok(across >= ink_w,
		"원판이 %.3f 조각 폭이다 — 그 위에 선 짐승(%.3f)보다 좁지 않다" % [across, ink_w])
	t.ok(Look.COL_BOAT_RIDER_SHADOW.a >= Look.COL_BODY_SHADOW.a,
		"땅바닥 원판보다 옅지 않다 (%.2f >= %.2f)" % [Look.COL_BOAT_RIDER_SHADOW.a, Look.COL_BODY_SHADOW.a])
	t.ok(Look.COL_BOAT_RIDER_SHADOW.a <= 0.45,
		"그러고도 0.45 아래다 — 구멍으로 읽히지 않는다 (%.2f)" % Look.COL_BOAT_RIDER_SHADOW.a)


# == the boat's fixture ================================================================================

## An arena with one boat on it, painted once. `secs` is how long the sim is driven before the frame —
## the default is `Rules.BOAT_FIRST_SEC`, which is the sub-step the first hull is born on.
##
## ⚠ **`_process` is called ONCE here and the rows that want motion call it again themselves.** A
## fixture that pumped its own frames would hand every row a different view clock.
func _boat_view(secs: float = -1.0) -> Dictionary:
	var rows := _open(ARENA_W, ARENA_H)
	var b := _battle_of(rows, _army_of([]), [])
	b.step(Rules.BOAT_FIRST_SEC if secs < 0.0 else secs)
	var fv := _view_of(b, rows)
	fv._process(0.0)
	return {"fv": fv, "b": b}


## **How much of a rider picture's own height is empty BELOW the animal, as a fraction.**
##
## ⚠⚠ **THE NET SCANS THE PNG ITSELF AND DOES NOT ASK THE VIEW.** `field_view._foot_body` holds the
## same quantity; reading it back would make every footing row a tautology, which is exactly the shape
## that put five green checks over five real defects in one day.
func _ink_pad_below(pic: Texture2D) -> float:
	var img := pic.get_image()
	var h := img.get_height()
	var last := -1
	for y in h:
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				last = y
				break
	return 0.0 if last < 0 else float(h - 1 - last) / float(h)


## **How much of a rider picture's own width the animal covers, as a fraction.**
func _ink_width_frac(pic: Texture2D) -> float:
	var img := pic.get_image()
	var w := img.get_width()
	var lo := w
	var hi := -1
	for x in w:
		for y in img.get_height():
			if img.get_pixel(x, y).a > 0.0:
				lo = mini(lo, x)
				hi = maxi(hi, x)
				break
	return 0.0 if hi < 0 else float(hi - lo + 1) / float(w)


## **The pooled sprites that are RIDERS — and it is NOT asked of the picture they wear.**
##
## ⚠⚠ **A RIDER AND A WOLF ASHORE WEAR THE SAME FOUR PICTURES SINCE 2026-08-30**, which is the whole
## point of the wolf having one list of pictures instead of two. 「its texture is a `wolf_h` one」 stopped
## naming a rider that day and started naming every wolf on the island as well — measured: three wolves
## that had already landed were counted as riders standing nowhere near a hull.
## ⚠⚠ **THE BOUNDARY COMES FROM THE SIM**, never from the pool: the field paints every body the sim says
## is standing, and only then a single deck. ⇒ **The draw order is load-bearing here**, so it is
## asserted rather than assumed — the two rows that call this both check where every sprite it hands
## back actually is, and a rider that leaked into the body run would land nowhere near a bench.
func _rider_sprites(fv: FieldView, b: Battle) -> Array:
	var bodies := b.living_enemy_ids().size() + b.ashore_ids().size()
	var out := []
	for k in range(bodies, fv._sprites_used):
		out.append(fv._sprites[k])
	return out


## The worst gap between a rider's drawn feet and its own seat, plus which picture the deck is wearing.
func _rider_feet(fv: FieldView, b: Battle, hull: Node3D) -> Dictionary:
	var worst := 0.0
	var seat := 0
	var pic: Texture2D = null
	for raw_sp in _rider_sprites(fv, b):
		var sp: Sprite3D = raw_sp
		pic = sp.texture
		var slot := hull.transform * (Look.BOAT_DECK_SLOTS[seat] as Vector3)
		var tall := float(sp.texture.get_height()) * sp.scale.y / Look.TILE_PX
		worst = maxf(worst, absf(sp.position.y - tall * 0.5 + _ink_pad_below(sp.texture) * tall - slot.y))
		seat += 1
	return {"worst": worst, "tex": pic, "pad": 0.0 if pic == null else _ink_pad_below(pic)}


func _first_rider(fv: FieldView, b: Battle) -> Sprite3D:
	var riders := _rider_sprites(fv, b)
	return null if riders.is_empty() else riders[0] as Sprite3D


## **A node's point in `stop`'s space, walked up the real parent chain.**
##
## ⚠ **`global_transform` is not used on purpose** — a `FieldView` built by a net is not in the tree,
## and asking for one there errors and hands back identity, which is the trap `_paint_riders` already
## carries a note about. Walking the chain answers the same in both worlds.
func _world_point(n: Node3D, stop: Node3D) -> Vector3:
	var at := n.position
	var up := n.get_parent()
	while up != null and up != stop and up is Node3D:
		at = (up as Node3D).transform * at
		up = up.get_parent()
	return at


## Every surface committed by every mesh under `n`. **Zero is the failure this exists to catch**: a
## scene that failed to load leaves no node at all, and a node whose mesh has no surface draws nothing.
func _surfaces_of(n: Node) -> int:
	var total := 0
	if n is MeshInstance3D:
		var m := (n as MeshInstance3D).mesh
		if m != null:
			total += m.get_surface_count()
	for c in n.get_children():
		total += _surfaces_of(c)
	return total


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


## The reef bay's four numbers, named rather than buried in the row builder below.
const REEF_X := 9
const REEF_Y0 := 2
const REEF_Y1 := 9
const ISLE_X := 14


## ⚠⚠ **`_port` STOOD HERE AND THE HARBOUR IT WAS NAMED AFTER IS DELETED.** It drew `net_fx`'s port —
## rows 3-7 water for the first six columns, land from column 6 on, one `H` at (2,5) — and the one row
## that used it sent a boat from that harbour to the beach farthest from it. **A boat is SUMMONED now**,
## from a water tile inside the band, and that bay cannot carry the row: measured on it, the band holds
## exactly **2** tiles and the longer of their two routes is **3 points over 4.24 tiles**, of which
## **1.41** remain after the first waypoint. A crossing that short beaches before the drawn line can
## let go of anything, so the row's whole subject would go unmeasured on a green.
##
## **The replacement is a reef bay.** The island is one block on the EAST (x 14..22, y 1..10), the west
## is open sea, and a `#` reef wall stands at x 9, y 2..9. ⚠ **The reef is the trick and it is a `#`
## for a reason**: a hole is neither `water` nor `passable`, so `_summon_field` neither seeds a shore
## on it nor walks through it — it shortens no `summon_hops` and only blocks. A boat from the western
## sea therefore has to sail AROUND one of its ends, which is what puts interior waypoints in a route
## that open water would smooth into a single chord.
##
## Measured on this board: **110 band tiles**, the longest route **5 points over 15.44 tiles**
## `[(2,8) (8,2) (9,1) (13,0) (14,1)]`, and the boat is still OUTBOUND on leg 2 after 150 sub-steps.
func _reef_bay() -> Array:
	var rows := []
	for y in ARENA_H:
		var row := ""
		for x in ARENA_W:
			var c := "~"
			if y >= 1 and y <= ARENA_H - 2 and x >= ISLE_X and x <= ARENA_W - 2:
				c = "."
			if x == REEF_X and y >= REEF_Y0 and y <= REEF_Y1:
				c = "#"
			row += c
		rows.append(row)
	return rows




## How much water a route still holds AFTER its first waypoint, in tiles. **The floor the crossing row
## needs**: everything before `path[1]` is sailed on leg 0, so this is all the sea there is left for
## `leg` to advance through while the boat is still OUTBOUND.
func _sail_after_first_waypoint(route: PackedVector2Array) -> float:
	var span := 0.0
	for k in range(2, route.size()):
		span += route[k - 1].distance_to(route[k])
	return span


## ⚠ **`ITEM_BLEED` and `_worn` stood here and both are deleted** (2026-08-29) with the statuses.
## The fixture discipline outlives them: the item was fitted onto a board the fight does not use, so
## its own stat columns could not move the arithmetic every other row here is built from.






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
## ⚠ **`tiers` is optional and empty means FLAT**, which is what every row in this file wanted until a
## height boundary had to be measured (2026-08-28). `Grid.load_rows` already takes it that way.
func _battle_of(rows: Array, army: Army, spawns: Array, tiers: Array = []) -> Battle:
	var b := _planning_battle_of(rows, army, spawns, tiers)
	return b


func _planning_battle_of(rows: Array, army: Army, spawns: Array, tiers: Array = []) -> Battle:
	var g := Grid.new()
	g.load_rows(rows, tiers)
	var b := Battle.new()
	b.setup(g, army, spawns)
	return b


## Ashore the way a landing leaves a soldier — state, position, goal AND the tile reservation
## (`net_fx`'s helper: state alone teleports the unit back to its stale goal on the first move).
func _ashore(b: Battle, i: int, p: Vector2) -> void:
	b.soldier_state[i] = Battle.SoldierState.ASHORE
	b.soldier_pos[i] = p
	b._soldier_goal[i] = p
	# ⚠⚠ **`Grid.hold` AND NOT A WRITE INTO `reserved`.** That array holds `Rules.TILE_CAPACITY` slots
	# per 조각 since 2026-08-30, so `reserved[tile] = i` now writes slot 0 of a 조각 three rows away —
	# **silently**, with every row here still green and the body holding nothing.
	b.grid.hold(i, int(round(p.y)) * b.grid.w + int(round(p.x)))


func _view_of(b: Battle, rows: Array, _tiers: Array = []) -> FieldView:
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
		"lunge": 0.0, "lunge_dir": Vector2.RIGHT, "push": 0.0, "gait": 0.0,
		"walk": 0.0, "head": Vector2.RIGHT, "last": at, "half": 0.0, "still": 0.0,
		# ⚠⚠ **`bite` STOOD HERE AND IT IS THREE KEYS NOW** (2026-08-31): the swing, the
		# flinch and the fall each own a countdown, and `_body_tex` reads all three. **A fixture short
		# one of them faults inside the picker rather than failing this net's own assertion.**
		"attack": 0.0, "hurt": 0.0, "dying": 0.0, "hp": 0.0, "cool": 0.0, "alive": true,
		"type": 0}


## The first pooled body sprite — anything not wearing the one-texel bar texture.
## **Where every body in the pool is drawn, in tile units on the ground plane.** ⚠ **`z` and not `y`**:
## `_put_body` writes the world x/z out of the canvas px and puts the sprite's own height in y.
func _body_spots(fv: FieldView) -> Array:
	var out := []
	for k in fv._sprites_used:
		var s: Sprite3D = fv._sprites[k]
		if s.texture != fv._tex_flat:
			out.append(Vector2(s.position.x, s.position.z))
	return out



func _body_sprite(fv: FieldView) -> Sprite3D:
	for k in fv._sprites_used:
		var s: Sprite3D = fv._sprites[k]
		if s.texture != fv._tex_flat:
			return s
	return null


# == readers ==========================================================================================

## **Ground vertices that are NOT a body's shadow.**
##
## ⚠⚠ **EVERY BODY LAYS A DISC ON THE GROUND SINCE 2026-08-28** (the user: 「그림자도 단순하게 아래
## 동그라미정도해줘」), so a fixture with a body in it no longer has an empty ground buffer. **Every row
## below that used to read `_g_v.size() == 0` now reads this instead** — the claim was never 「the
## buffer is empty」, it was 「this effect drew nothing on the ground」, and the shadow is not the effect.
## ⚠ **The shadow itself is measured on its own** in `_a_body_lays_one_shadow_disc`, so filtering it
## out here does not hide it.
func _ground_minus_shadow(fv: FieldView) -> int:
	var n := 0
	for k in fv._g_c.size():
		if not _col_close(fv._g_c[k], Look.COL_BODY_SHADOW):
			n += 1
	return n


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
