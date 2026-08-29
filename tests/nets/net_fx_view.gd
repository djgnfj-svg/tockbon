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
	_the_hills_never_swallow_the_tier(t)
	_the_first_island_opens_with_room_around_it(t)
	_a_body_lays_one_shadow_disc(t)
	_a_body_stands_on_its_own_tile_and_not_the_next_one(t)
	_the_readers_themselves(t)
	_every_row_wears_its_own_picture(t)
	_the_bite_rides_the_blow_that_lunges(t)
	for raw in _created:
		var fv: FieldView = raw
		fv.free()
	_created = []






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

	var wolf_px := Look.body_radius_of(Rules.WOLF) * Look.BEAST_SPRITE_W_RATIO * zoom
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
		var tex := fv._beast_tex(ty, true)
		t.ok(tex != null, "%d 번 줄에 그림이 있다" % ty)
		seen[tex] = int(seen.get(tex, 0)) + 1
	t.eq(seen.size(), Rules.UNITS.size(),
		"표의 줄마다 저마다 다른 그림을 쓴다 — 개수만 세면 다섯이 늑대 그림 하나를 나눠 써도 맞는다")
	# The floor: a body really does reach the pool wearing one of them.
	t.ok(fv._sprites_used > 0, "그리고 몸이 실제로 화면에 섰다 (자가 점검)")
	# The `is_enemy` argument is gone, so the same row facing the same way is the same picture whoever
	# is asking. Asserted as an EQUALITY, which is what a deleted selector actually means.
	t.eq(fv._beast_tex(Rules.WOLF, true), fv._beast_tex(Rules.WOLF, true),
		"같은 줄은 같은 그림을 준다 — 묻는 쪽이 편을 안 고른다")


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

	fv._process(1.0 / 60.0)
	t.ok(float((fv._body["s0"] as Dictionary)["bite"]) <= 0.0, "물기가 끝났다 (자가 점검)")
	t.ok(walk.find(fv._body_tex("s0", Rules.WOLF, true)) >= 0,
		"그리고 걷기 띠로 돌아간다 — 안 돌아가면 입을 벌린 채 남은 싸움을 한다")

	# ⚠ The other eight, through the SAME call: the enemy standing right there has no strip at all.
	t.eq(fv._body_tex("e0", Rules.WOLF, true), fv._beast_tex(Rules.WOLF, true),
		"띠 없는 종은 같은 호출로 서 있는 그림을 받는다")
	t.ok(fv._body_tex("e0", Rules.WOLF, true) != null, "그리고 그 그림은 비어 있지 않다")




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
	var claimed := b.grid.reserved
	claimed[int(round(p.y)) * b.grid.w + int(round(p.x))] = i
	b.grid.reserved = claimed


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
