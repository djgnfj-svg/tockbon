class_name FieldView
extends Node2D
## The island itself: terrain, docks, boats at sea, bodies, beaks, HP bars — and nine of the twelve
## combat effects.
##
## **Reads `Battle` and never writes it.** There is no assignment into any sim object anywhere in
## this file — that is the `src/view/` half of the folder contract, and it is what keeps "the screen
## changed but the sim did not" from being expressible here at all. The lunge and the flinch are
## DRAWING offsets and never `soldier_pos`: reach tests read positions directly and the grid reserves
## one body per tile, so writing either into the sim would change who is inside whose reach and the
## decoration would rewrite the rules it exists to decorate.
##
## **`_draw()` calls the `_paint_*` hooks and nothing else**, and every `draw_*` call in the file
## lives inside one of those thirteen hooks, in the exact per-function counts `net_draw_leaf._table()`
## pins (`combat-juice`'s original eleven, plus `_paint_route` for stage 4's drag and `_paint_hull` /
## `_paint_cliff_face` for stage 5's fleet — `_paint_boat` is gone, replaced by `_paint_hull`, and
## `_paint_overlay` is gone with the green coast wash it drew). A net overrides a hook and reads its
## arguments back; the per-function count is
## what stops a hook from quietly throwing its drawing away, because **argument capture proves a
## value was computed and handed on, never that it was used** — a `draw_circle(p, 0.0, col)` inside
## a leaf once turned forty rocks invisible with the whole round green. See
## lessons-from-two-dead-games.
##
## Every helper below returns a value and calls no `draw_*`: a drawing call outside the eleven hooks
## is exactly what `net_draw_leaf` reddens on, and a function written tomorrow is red until it is in
## the table.
##
## No colour literal and no named colour constant appears here — every colour and every pixel value
## is read from `look.gd`, because a presentation number kept in two files diverges and the
## divergence is invisible on screen. The scan that enforces it greps this file's raw text, so even
## the sentence you are reading avoids writing the forbidden shape out.
##
## **The effects keep their own clock and their own drawers, and that is a requirement rather than a
## convenience**: the shell skips `battle.step` entirely while a panel is up, so an effect hung off
## the sim's clock freezes mid-play behind the win screen — which is the exact moment the death burst
## and the transition are supposed to be running. See `combat-juice`, "what the view owns".


## How finely one rounded corner of a body outline is sampled. **Not a design value** — the shape
## the player reads comes from `Look.BODY_CORNER_RATIO`, and this only decides whether the arc
## between two of its points is visibly faceted. It is not in `look.gd` because nothing outside this
## file's polygon builder can see it.
const CORNER_SEGMENTS := 6

## How finely a ring is sampled. Same reason as `CORNER_SEGMENTS`, and deliberately NOT an argument
## to `_paint_ring`: made an argument it would add one more entry to `net_draw_leaf`'s "unused
## parameter" check and buy nothing, because "does the arc look faceted" is not a design value.
const RING_SEGMENTS := 24

## The four ORTHOGONAL offsets, used ONLY by the cliff-face pass below — which walks a cliff tile's
## seaward EDGES, and a tile has four edges however many neighbours it has.
##
## ⚠ **These four moved here out of `Grid.ORTHO`, which is deleted.** `Grid`'s copy existed for the
## `landable` predicate ("a tile touching water only at a corner is not landable"), and
## `speed-off-open-landing` deleted that whole rule — the coast is 8-way now. This is a DRAWING
## question, not a rule one: an edge is an edge. It is not in `look.gd` because it is not a number
## anyone would tune; it is the geometry of a square.
const CLIFF_SIDES := [[0, -1], [0, 1], [-1, 0], [1, 0]]

## What lives in the transient drawer. Anything bolted to a BODY lives in `_body` instead, keyed by
## body, which is why "drop the oldest" and "one flash per body, age reset rather than stacked" never
## eat each other — they are rules of two different drawers.
## ⚠ `REFUSE` is the one entry here that is NOT born in `_drain_events`. Every other kind is drained
## out of `battle.events`; a refusal produces no event because `Battle.send` refuses with **nothing at
## all changed** — that is the whole of its contract — so the shell pushes this one in through
## `note_refusal` off `send`'s own -1. See that function.
enum FxKind { SHOT, SPARK, BURST, AREA, LAND, REFUSE }


## The fight being drawn. Null until `setup`, and `_draw` paints nothing while it is.
var battle: Battle = null

## The roster. **It must be the same object `battle` was set up with** — the shell hands both from
## one place for that reason. A fresh `Grid` and a fresh `Battle` are built per island and the army
## is not, which is how HP and the beak carry, so the view reads *who a soldier is* from here and
## *where it is standing* from `battle`.
var army: Army = null

## The island's 18 legend rows, straight from `Islands.rows_of`. **The rows are the only place water
## and a hole can be told apart**: `grid.passable` stores one byte and both are 0 in it, so a view
## coloured from passability alone paints the sea and the pits the same tone and the map reads as one
## shape. `look.gd`'s terrain lookup takes the legend character for exactly this reason.
var rows: Array = []


## The transient drawer: shots, sparks, bursts, area rings, landing rings. Each entry carries
## `age`, `delay`, `life` and whatever geometry was FROZEN when it was born — a tracer that re-read
## `soldier_target` every frame would bend onto the next enemy the instant its target died, and a
## spark whose root followed its striker would walk backwards as the lunge returned.
var _fx: Array = []

## The per-body drawer, keyed `"e3"` / `"s7"`. Flash, flinch, lunge, gait phase and last position.
## **A Dictionary and not a list on purpose**: the key is the body, so a body hit twice in one frame
## has its age reset instead of stacking a second entry, and stacked halos would multiply their alpha
## until the body was simply white.
var _body: Dictionary = {}

## Screen shake. `_shake_amp` is the peak in px and `_shake_left` counts down; the offset is ASSIGNED
## to `position` and never added, because in the last game a `+=` became the basis of the next
## frame's lerp and compounded roughly 9x, so a 28 px cap stopped nothing at all.
var _shake_amp := 0.0
var _shake_left := 0.0

## The camera. `cam_px` is the world-space (canvas px) top-left corner of what is visible; `zoom` is
## the runtime float `Look.ZOOM_MIN`..`Look.ZOOM_MAX` the wheel changes. **There is still no
## `Camera2D`** — this node composes the whole transform itself in one expression
## (`position = -cam_px * zoom + shake_offset()`, `scale = Vector2(zoom, zoom)`), which is what keeps
## every screen->world conversion going through the one function beside it
## (`screen_to_world_px`) instead of a second copy drifting somewhere else on screen at once.
var cam_px := Vector2.ZERO
var zoom := 1.0

## The drag (`plan-then-watch`, section 7). `_drag_soldier` is -1 while nothing is being dragged;
## `_drag_tile` is the tile under the cursor while one is. Both are set by `game.gd` through
## `set_drag`, the one call site "a drag started", "a drag moved" and "a drag ended" all go through —
## the two states can never disagree about whether the overlay should be showing.
##
## ⚠ **It is a SOLDIER now, not a boat.** The reversal made the boat plumbing: you drag a body off the
## harbour onto a beach and a boat is created by the drop. There is no fleet slot to name.
var _drag_soldier := -1
var _drag_tile := -1

## The summon aim (`sea-summon`). `_summon_slot` is the slot a number key has armed, or -1;
## `_summon_aim` is the tile under the cursor, or -1. **Both are set by `game.gd` through one call**,
## `set_summon_aim`, exactly as the drag's two fields are — "armed", "moved" and "cleared" all go
## through it, so the two can never disagree about whether the aim marks should be showing.
##
## ⚠ **Neither of them gates the BAND.** The green ribbon is drawn from the moment the island opens
## with nothing armed at all: the region on screen at frame one is what says a press belongs there,
## and that is the answer to 「뭐 어떻게 동작시키는지 전혀모르겠는데?」.
var _summon_slot := -1
var _summon_aim := -1

## P7's stalled-boat blink clock (`boat-and-landing` stage 5). A boat's OWN age is not the right
## clock for this — a boat that just arrived and a boat that has been stuck for ten seconds must
## blink in the same phase, or the mark would read as counting something instead of as a warning.
## One shared clock, like `_shake_offset`'s own, deterministic so a net can drive it by hand.
var _wait_clock := 0.0

@warning_ignore("shadowed_variable")
func setup(battle: Battle, army: Army, rows: Array) -> void:
	self.battle = battle
	self.army = army
	self.rows = rows
	# **Both drawers are emptied here.** Without it island 2 opens with island 1's explosions still
	# in flight over bodies that no longer exist, and every id in them means a different unit now.
	_fx = []
	_body = {}
	_shake_amp = 0.0
	_shake_left = 0.0
	# A drag in flight on the island that just ended must not survive onto the one that just opened —
	# its soldier id would now name a stranger standing at a different harbour.
	_drag_soldier = -1
	_drag_tile = -1
	# Same argument as the drag one line up: a slot armed on island 1 must not survive onto island 2,
	# and the tile index it was aiming at would name a different piece of water there.
	_summon_slot = -1
	_summon_aim = -1
	_wait_clock = 0.0
	# The survey: an island opens zoomed all the way out, so the WHOLE island is on screen before
	# anything is planned — `plan-then-watch` 6.3, on the user's 「조금 더 카메라를 뒤로 빼야 될」.
	# `_clamp_cam` centres any axis whose map is narrower than the visible world, and at `ZOOM_MIN`
	# 0.45 that is now BOTH axes, which is the whole of the framing change.
	zoom = Look.ZOOM_MIN
	cam_px = Vector2.ZERO
	_clamp_cam()
	position = _compose_position()
	scale = Vector2(zoom, zoom)
	queue_redraw()


## The sim moves every frame and a `Node2D` only repaints when it is asked to. Without this line the
## picture freezes on the first frame while `battle.step` keeps running — the signature fake, with
## the sim and the screen the wrong way round.
##
## **The order of these three is load-bearing.** Ageing first and draining second means an effect
## born this frame is drawn at full amplitude on the frame it was born, so the flinch really does
## reach `HIT_KNOCK_PX` and the shake really does reach `dmg * SHAKE_PER_DAMAGE_PX` once. Draining
## first would shave one frame's delta off every effect before anyone saw it.
##
## ⚠ **Every clock in this file is aged by the BARE frame delta**, `_wait_clock` included.
## `set_time_scale` and `_time_scale` are deleted with the speed ladder
## (`speed-off-open-landing`, item 1): with no multiplier the only honest value the field could hand
## its own drawers is a constant 1.0, and a leaf handed a constant is the shape 「No fake code」 names.
## Every duration in `look.gd` is budgeted against real seconds, which is where they were written.
func _process(delta: float) -> void:
	_fx_step(delta)
	_drain_events()
	_wait_clock += delta
	position = _compose_position()
	scale = Vector2(zoom, zoom)
	queue_redraw()


# --- the camera: one transform, in one place ------------------------------------------------------

## `position = -cam_px * zoom + shake_offset()` — the pan, the zoom and the shake compose in exactly
## this one expression, and nothing else in the tree may write `position` for this node.
func _compose_position() -> Vector2:
	return -cam_px * zoom + _shake_offset()


## The inverse of the node's own transform: a screen (viewport) px back to world (canvas) px. Every
## click, and every future drag, goes through this rather than a second hand-rolled conversion.
func screen_to_world_px(at: Vector2) -> Vector2:
	return (at - position) / zoom


func world_to_tile(world: Vector2) -> Vector2i:
	return Vector2i(int(floor(world.x / Look.TILE_PX)), int(floor(world.y / Look.TILE_PX)))


## Moves the camera by a SCREEN-space delta (e.g. mouse motion) and re-clamps.
func pan_by(delta_screen: Vector2) -> void:
	cam_px -= delta_screen / zoom
	_clamp_cam()


## Multiplies `zoom` by `factor` (clamped to `Look.ZOOM_MIN`..`Look.ZOOM_MAX`) while keeping the WORLD
## point under `at` fixed on screen — `boat-and-landing`, 7.1: `position' = at - (at - position) *
## zoom' / zoom`. Computed against the UNSHAKEN position deliberately: locking the zoom centre to a
## jittering shake offset would make the zoom itself judder while nothing is being zoomed.
func zoom_at(at: Vector2, factor: float) -> void:
	var new_zoom := clampf(zoom * factor, Look.ZOOM_MIN, Look.ZOOM_MAX)
	if new_zoom == zoom:
		return
	var unshaken := -cam_px * zoom
	var world_at := (at - unshaken) / zoom
	zoom = new_zoom
	cam_px = world_at - at / new_zoom
	_clamp_cam()


## `cam_px` clamped per axis to `[0, map_px - viewport_px / zoom]`; an axis where the map is narrower
## than the visible world (every zoom below 0.667 horizontally, and always vertically at these
## dimensions) is CENTRED on that axis instead of clamped to an empty range.
func _clamp_cam() -> void:
	var map_px := Vector2(_map_tiles()) * Look.TILE_PX
	var visible := Look.viewport_size_px() / zoom
	var out := cam_px
	for axis in 2:
		if map_px[axis] < visible[axis]:
			out[axis] = (map_px[axis] - visible[axis]) * 0.5
		else:
			out[axis] = clampf(out[axis], 0.0, map_px[axis] - visible[axis])
	cam_px = out


func _visible_world_rect() -> Rect2:
	return Rect2(cam_px, Look.viewport_size_px() / zoom)


## **The grid's own size in tiles, and the one place anything here asks for it.**
##
## ⚠⚠ **Nothing that draws or clamps may read `Look.GRID_W` / `GRID_H` directly any more.** They were
## `const 48` / `32` and `_draw` and `_clamp_cam` read them instead of the grid, so **two maps of
## different sizes were unrepresentable** — a long map and a small one could not both exist. The
## constants survive only as the answer for a view that has no grid yet (`setup(Battle.new(), …)`, and
## the frames between the shell building the node and opening an island), and that fallback is what
## keeps every camera literal measured against 48 x 32 still true.
func _map_tiles() -> Vector2i:
	if battle != null and battle.grid != null and battle.grid.w > 0 and battle.grid.h > 0:
		return Vector2i(battle.grid.w, battle.grid.h)
	return Vector2i(Look.GRID_W, Look.GRID_H)


## The half-open tile span the terrain pass walks: what is on screen, padded, and clamped to the grid
## plus its water margin. **`end` is exclusive**, so `range(position.x, end.x)` is the loop.
##
## ⚠⚠ **Without this the terrain loop paints the whole map every frame whatever is visible.** Measured
## at 48 x 32 with a 12-tile margin: 72 x 56 = **4,032 tiles = 8,064 immediate-mode calls a frame**,
## of which the zoomed-out camera can see about three quarters. At 144 columns the same loop is
## 168 x 56 = 9,408, and the long map is unplayable before anything about it can be judged.
##
## The pad is `Look.CULL_PAD_TILES`, and it is arithmetic rather than slack — see its own comment: the
## shake is added to `position` AFTER this is computed, so the world can slide under the camera by
## `SHAKE_MAX_PX / ZOOM_MIN` px without `cam_px` moving at all.
##
## ⚠ **The clamp to the margin is the reason this can never cut anything.** `WATER_MARGIN_TILES` is
## already sized so the margin rect contains the whole zoomed-out visible world (`net_camera` pins
## that), so intersecting the two can only ever drop tiles that were off screen.
func _visible_tile_rect(margin: int) -> Rect2i:
	var tiles := _map_tiles()
	var world := _visible_world_rect().grow(Look.CULL_PAD_TILES * Look.TILE_PX)
	var x0 := maxi(-margin, int(floor(world.position.x / Look.TILE_PX)))
	var y0 := maxi(-margin, int(floor(world.position.y / Look.TILE_PX)))
	var x1 := mini(tiles.x + margin, int(ceil(world.end.x / Look.TILE_PX)))
	var y1 := mini(tiles.y + margin, int(ceil(world.end.y / Look.TILE_PX)))
	return Rect2i(Vector2i(x0, y0), Vector2i(maxi(0, x1 - x0), maxi(0, y1 - y0)))


## Called by `game.gd` on every press, motion and release of a drag. `soldier == -1` clears the
## candidate outright — the SAME call a press starts a drag with is the one a release ends it with,
## so "a drag is showing" and "`_drag_soldier >= 0`" can never read two different answers.
func set_drag(soldier: int, tile: int) -> void:
	_drag_soldier = soldier
	_drag_tile = tile


## Called by `game.gd` whenever a slot is armed or disarmed, whenever the cursor moves with one armed,
## and on the release. `slot == -1` clears the whole aim. **0 draw calls** — the same shape `set_drag`
## above is, and for the same reason: one call site for three events means the two fields cannot
## disagree.
func set_summon_aim(slot: int, tile: int) -> void:
	_summon_slot = slot
	_summon_aim = tile


## One mark at `at_px` (world px) saying the sim REFUSED this drop. **0 draw calls** — it pushes one
## entry into the transient drawer and the ground-ring block paints it on the next frame, the same
## path every other transient takes.
##
## ⚠⚠ **The shell calls this off `Battle.send`'s own -1 and off nothing else.** A view that decided
## for itself whether a tile was refusable would be a second copy of `grid.home_harbour_for`, and two
## copies of one predicate is exactly what the deleted green wash was trusted NOT to be. Driving it
## from the sim's answer is how the honesty guarantee survives the wash it used to belong to
## (`speed-off-open-landing`, 2.5).
##
## `delay` is 0.0: the mark has to land on the frame of the press, not one beat after it — Swink's
## bound on input-to-response is under 100 ms and `REFUSE_MARK_SEC` is the whole of the effect.
func note_refusal(at_px: Vector2) -> void:
	_fx.append({
		"kind": FxKind.REFUSE,
		"age": 0.0,
		"delay": 0.0,
		"life": Look.REFUSE_MARK_SEC,
		"at": at_px,
	})


func _draw() -> void:
	if battle == null or army == null or battle.grid == null:
		return
	if battle.grid.w <= 0:
		return

	# --- 1. terrain, one margin ring wider than the grid ----------------------------------------
	# The grid is deliberately SMALLER than the zoomed-out visible world (48 x 32 tiles = 1920 px wide
	# against 2844.4 px of view at the new ZOOM_MIN 0.45), so the margin has to cover the whole
	# zoomed-out edge, not just a shake — `Look.WATER_MARGIN_TILES` is 12 for exactly that reason, and
	# it was re-measured in the same edit that lowered the zoom. The margin tiles are
	# painted COL_WATER DIRECTLY rather than through `terrain_colour_of_char`: that lookup takes a
	# legend character and there is no legend outside the grid, so inventing one would put the island
	# legend in two places.
	# ⚠ **The bounds come from `battle.grid` through `_map_tiles()`, never from `Look.GRID_W`/`GRID_H`,
	# and the span is CULLED to what is on screen.** Read off the constants this loop could only ever
	# paint one map size; painted whole it was 4,032 tiles a frame at 48 x 32 and would be 9,408 at 144.
	var margin := Look.WATER_MARGIN_TILES
	var tile_span := _visible_tile_rect(margin)
	# Answered ONCE for the whole pass rather than per tile: it is a fact about the fight, not about
	# a tile, and asking it 3168 times would invite the next reader to fold it into the tile predicate
	# where it would read as part of `can_summon_at`. See the band block inside the loop.
	var band_on := not battle.committed()
	for ty in range(tile_span.position.y, tile_span.end.y):
		for tx in range(tile_span.position.x, tile_span.end.x):
			var fill := Look.COL_WATER
			if ty >= 0 and ty < rows.size() and tx >= 0:
				var row: String = rows[ty]
				if tx < row.length():
					fill = Look.terrain_colour_of_char(row[tx])
			# --- the summonable band (sea-summon) ---------------------------------------------
			# ⚠⚠ **A BLEND INTO THE EXISTING FILL, not a second pass, and that is what makes it
			# checkable.** A `_paint_band` leaf would add a leaf, a draw call per band tile and a new
			# width row; as a blend it costs zero extra draw calls, and a spy on `_paint_tile` sees the
			# `fill` argument — so "the band was drawn" is measured by two fills being DIFFERENT, and
			# dropping the blend makes the behaviour VANISH rather than diverge.
			# ⚠ **The predicate is `grid.can_summon_at` and nothing else** — the same call
			# `Battle.summon` refuses on — so the green cannot promise a tile the sim then denies. That
			# is the guarantee the deleted coast wash carried and the reason it was trusted at all.
			# The bounds test is here because this loop runs `WATER_MARGIN_TILES` wider than the grid
			# and `tile_index` off the map would compute an in-range index for a tile that is not there.
			# ⚠⚠ **AND IT GOES WITH THE BOXES AT THE COMMIT.** The paragraph above says the green
			# cannot promise a tile the sim then denies, and without `band_on` it did exactly that for
			# the whole fight: after the commit `Battle.summon` refuses everything, `hud_view` stops
			# drawing the five slot boxes, and the sea went on wearing **the only mark on the field
			# that says 「your hand goes here」**. That is the deleted coast wash's failure with the
			# tint on the other side of the commit. ⚠ Measured before it was fixed: adding this test
			# ran the whole round GREEN — no check could tell the two behaviours apart, which is why
			# `net_slots` now reads the band's tile count on both sides of `commit()`.
			if band_on and tx >= 0 and ty >= 0 and tx < battle.grid.w and ty < battle.grid.h:
				if battle.grid.can_summon_at(battle.grid.tile_index(tx, ty)):
					fill = fill.blend(Look.COL_SUMMON_BAND)
			_paint_tile(
				Look.tile_rect_px(tx, ty),
				fill,
				Look.COL_GRID_LINE,
				Look.GRID_LINE_WIDTH_PX)

	# --- 1b. cliff faces (boat-and-landing stage 5, P10) --------------------------------------------
	# A line along a cliff tile's SEAWARD edge — whichever ortho side touches water — the only thing
	# that turns "coloured like a hole" into "reads as height" with no elevation axis at all (3.2: a
	# cliff is exactly as impassable as a hole and differs only in how it is drawn).
	#
	# The geometry is built HERE and handed to the leaf as ONE FLAT ARRAY, consecutive pairs being one
	# segment's two endpoints — the same shape `_paint_spark` already uses for its six shards, drawn
	# with a SINGLE `draw_multiline` call rather than a loop of `draw_line`. That shape is not a style
	# choice: a loop indexing `seg[0]` / `seg[1]` inside the leaf can drop the second endpoint
	# (`draw_line(seg[0], seg[0], …)`, every face collapsed to a point) and no scanner catches it —
	# `segments` reads as "used" the moment `seg[0]` appears once, and a spy overriding the whole leaf
	# never runs its body at all. A flat array hands `draw_multiline` everything in one native call;
	# there is no per-segment indexing left inside the leaf for that mutation to hide in.
	# Same two rules as the terrain pass above: the size comes from the grid, and the walk is culled to
	# what is on screen. The span is clamped to the grid itself here (margin 0) — a cliff is a legend
	# character and there is no legend outside the rows.
	var cliff_points := PackedVector2Array()
	var cliff_span := _visible_tile_rect(0)
	for ty2 in range(cliff_span.position.y, cliff_span.end.y):
		var row2: String = rows[ty2] if ty2 < rows.size() else ""
		for tx2 in range(cliff_span.position.x, cliff_span.end.x):
			if tx2 >= row2.length() or row2[tx2] != "^":
				continue
			var crect := Look.tile_rect_px(tx2, ty2)
			for k in CLIFF_SIDES.size():
				var dx := int(CLIFF_SIDES[k][0])
				var dy := int(CLIFF_SIDES[k][1])
				var nx := tx2 + dx
				var ny := ty2 + dy
				if nx < 0 or ny < 0 or nx >= battle.grid.w or ny >= battle.grid.h:
					continue
				if battle.grid.water[ny * battle.grid.w + nx] == 0:
					continue
				if dy == -1:
					cliff_points.append(crect.position)
					cliff_points.append(crect.position + Vector2(crect.size.x, 0.0))
				elif dy == 1:
					cliff_points.append(crect.position + Vector2(0.0, crect.size.y))
					cliff_points.append(crect.end)
				elif dx == -1:
					cliff_points.append(crect.position)
					cliff_points.append(crect.position + Vector2(0.0, crect.size.y))
				else:
					cliff_points.append(crect.position + Vector2(crect.size.x, 0.0))
					cliff_points.append(crect.end)
	# ⚠⚠ **AN EMPTY ARRAY IS A BARK, NOT A NO-OP.** `canvas_item_add_multiline` fails on
	# `p_points.is_empty() || p_points.size() % 2 != 0`, and it fails on stderr while the frame carries
	# on looking fine. Culling made this reachable: zoom in anywhere with no water-touching cliff edge
	# in view and the loop above produces nothing. Verify-look caught eight of them in one capture run
	# **while this round's own report said stderr was clean** — the nets had never driven the camera
	# into a cliff-free view, so a green round said nothing about it.
	# ⚠ The guard is at the CALL SITE and not inside the leaf: a leaf that sometimes draws nothing is a
	# leaf `net_draw_leaf` can no longer pin at one call, and "it drew" would stop meaning anything.
	if not cliff_points.is_empty():
		_paint_cliff_face(cliff_points, Look.COL_CLIFF_FACE, Look.CLIFF_FACE_WIDTH_PX)

	# --- 2. harbours -----------------------------------------------------------------------------
	# The tile under a harbour is already water-coloured by the terrain pass, so the marker is an
	# outline rather than a fill: it has to still say "a boat may be sent from here" against open
	# water, whether or not a hull happens to be sitting there right now (both boats can be at sea
	# at once, leaving every harbour on the island empty). It is drawn in the boat's colour on
	# purpose, exactly as the old dock outline was.
	for h in battle.harbour_count():
		var harbour := battle.harbour_tile(h)
		if harbour < 0:
			continue
		var at := _tile_xy(harbour)
		_paint_dock(Look.tile_rect_px(at.x, at.y), Look.COL_BOAT, Look.BODY_OUTLINE_WIDTH_PX)

	# --- 2b. the drag candidate (P3, plan-then-watch) --------------------------------------------
	# ⚠⚠ **THE GREEN COAST IS DELETED.** It washed every sendable tile at alpha 0.18 from the moment
	# the island opened; `speed-off-open-landing`'s question C replaced it on the user's own sentence
	# 「못내림만 표시하면 됨 ㅇㅇ」 — the screen marks what is BLOCKED and nothing else. What carries
	# 「여긴 못 내린다」 now is the cliff-face pass above (a standing mark on the terrain itself) plus
	# the refusal mark below, which fires on the frame the sim actually refuses a drop.
	#
	# ⚠ **The wash was also what made the promise honest** — its predicate was
	# `grid.home_harbour_for(t) >= 0`, the exact call `Battle.send` refuses on, so the green could never
	# promise a tile the sim then denied. The refusal mark inherits that guarantee from the OTHER end:
	# it is pushed by the shell off `send`'s own -1, so it cannot deny anything the sim allows.
	if not battle.committed():
		if _drag_soldier >= 0 and _drag_tile >= 0:
			# The ring under the cursor answers the SAME predicate the release will, so the refusal is
			# readable before the release rather than after it.
			var drag_hb := battle.grid.home_harbour_for(_drag_tile)
			var ring_col := Look.COL_WIN if drag_hb >= 0 else Look.COL_LOSE
			var candidate_px := Look.tile_point_px(battle.grid.tile_point(_drag_tile))
			_paint_ring(candidate_px, Look.TARGET_RING_R_PX, ring_col, Look.AREA_RING_WIDTH_PX)
			if drag_hb >= 0:
				# ⚠ **Built from `grid.water_route` and not from two endpoints.** Which harbour it
				# would sail from is decided by the LANDING, and since
				# `speed-off-open-landing` the crossing bends around headlands — so a straight line
				# drawn here would promise a sail the boat does not make, and it would promise it
				# over LAND. `send` builds its boat off this same call, so the line the player sees
				# while dragging is point for point the line the boat will really take.
				var plan_px := PackedVector2Array()
				for wp in battle.grid.water_route(drag_hb, _drag_tile):
					plan_px.append(Look.tile_point_px(wp))
				_paint_route(plan_px, Look.COL_ROUTE, Look.ROUTE_WIDTH_PX)

		# --- 2c. the summon aim (sea-summon) -------------------------------------------------------
		# The same two leaves the drag uses, and nothing new. **A dry slot draws NEITHER** — the absence
		# is the answer, and it arrives before the press instead of after it.
		if _summon_slot >= 0 and _summon_aim >= 0 \
				and not battle.slot_reserve_ids(_summon_slot).is_empty():
			# ⚠ **The predicate is `can_summon_at`, the call `Battle.summon` itself refuses on** — not
			# 「does this water tile have a landing at all」, which answers yes 534 tiles out to sea on
			# island 0 and would promise a crossing the sim will not make.
			var aim_ok := battle.grid.can_summon_at(_summon_aim)
			var aim_landing := battle.grid.summon_landing_of(_summon_aim)
			# ⚠⚠ **The ring sits on the DERIVED LANDING and not on the pressed tile.** The landing is
			# the thing the player is choosing; the pressed tile is only how they said it. Off the band
			# there is no landing to point at, so the refusal ring goes where the hand is.
			var aim_at := _summon_aim if not aim_ok or aim_landing < 0 else aim_landing
			_paint_ring(
				Look.tile_point_px(battle.grid.tile_point(aim_at)),
				Look.TARGET_RING_R_PX,
				Look.COL_WIN if aim_ok else Look.COL_LOSE,
				Look.AREA_RING_WIDTH_PX)
			if aim_ok:
				# ⚠ **Built from `grid.summon_route` — the same call `Battle.summon` builds its boat
				# from** — so the screen cannot promise a crossing the sim does not make. Inherited from
				# the drag's own route above rather than re-derived.
				var summon_px := PackedVector2Array()
				for wp in battle.grid.summon_route(_summon_aim):
					summon_px.append(Look.tile_point_px(wp))
				_paint_route(summon_px, Look.COL_ROUTE, Look.ROUTE_WIDTH_PX)

	# --- 3. target lines -----------------------------------------------------------------------
	# ENEMY side only, and none at all above the count: this is the one effect of the twelve that
	# can be a net loss in readability. It sits under the boats and the bodies because a line
	# crossing a body is the "cloud of visual effects and particles" Riot explicitly deleted.
	if Look.fx_gain_of(6) > 0.0 and battle.enemies_left() <= Look.TARGET_LINE_MAX_COUNT:
		for e in battle.enemy_alive.size():
			if battle.enemy_alive[e] == 0:
				continue
			var aim := int(battle.enemy_target[e])
			if aim < 0 or not battle.is_hittable(aim):
				continue
			_paint_target_line(
				Look.tile_point_px(battle.enemy_pos[e]),
				Look.tile_point_px(battle.soldier_pos[aim]),
				Look.COL_TARGET_LINE,
				Look.TARGET_LINE_WIDTH_PX)

	# --- 4. ground rings: the lion's telegraph, area rings, landing rings ------------------------
	# All three are marks on the FLOOR rather than events on a body, so they go under everything
	# that stands on it.
	#
	# The telegraph is drawn from sim STATE and not from an event: `enemy_windup` counts down inside
	# the sim, and a view-side clock started by an event would be a second copy of that countdown —
	# two clocks drift and the ring would stop naming the frame the blow lands.
	if Look.fx_gain_of(5) > 0.0:
		for e in battle.enemy_windup.size():
			if battle.enemy_alive[e] == 0 or battle.enemy_windup[e] <= 0.0:
				continue
			var aimed := int(battle.enemy_windup_at[e])
			if aimed < 0:
				continue
			var span := Rules.area_of(int(battle.enemy_type[e])) * Look.TILE_PX
			if span <= 0.0:
				continue
			# It grows to the REAL area radius and arrives there exactly as the blow lands, so the
			# ring the player read and the tiles that take damage are the same circle.
			var wound := clampf(
				1.0 - float(battle.enemy_windup[e]) / Rules.LION_WINDUP_SEC, 0.0, 1.0)
			_paint_ring(
				Look.tile_point_px(battle.soldier_pos[aimed]),
				span * lerpf(Look.AREA_RING_START_RATIO, 1.0, wound),
				Look.COL_AREA_RING,
				Look.AREA_RING_WIDTH_PX)

	for raw_ground in _fx:
		var ground: Dictionary = raw_ground
		var ground_kind := int(ground["kind"])
		# ⚠ An ALLOWLIST and never a denylist. Written as "skip the three that are not ground marks",
		# a sixth kind added tomorrow would fall through into the `else` below and be drawn as a
		# refusal ring, silently, with every check green.
		var is_ground := ground_kind == FxKind.AREA or ground_kind == FxKind.LAND
		is_ground = is_ground or ground_kind == FxKind.REFUSE
		if not is_ground:
			continue
		var ground_at := clampf(
			(float(ground["age"]) - float(ground["delay"])) / float(ground["life"]), 0.0, 1.0)
		if ground_kind == FxKind.AREA:
			var area_col := Look.COL_AREA_RING
			area_col.a = area_col.a * (1.0 - ground_at)
			_paint_ring(
				ground["at"],
				float(ground["radius"]) * lerpf(Look.AREA_RING_START_RATIO, 1.0, ground_at),
				area_col,
				Look.AREA_RING_WIDTH_PX)
		elif ground_kind == FxKind.LAND:
			var land_col := Look.COL_LAND_RING
			land_col.a = land_col.a * (1.0 - ground_at)
			_paint_ring(
				ground["at"],
				Look.LAND_RING_R_PX * ground_at,
				land_col,
				Look.LAND_RING_WIDTH_PX)
		else:
			# The refusal mark (2.5). It fades out at a FIXED radius rather than growing like the
			# landing ring: growth reads as "something is happening here", and a refusal is the
			# statement that nothing happened. Drawn through the same `_paint_ring` leaf as the other
			# three so no new leaf enters `net_draw_leaf`'s table for one more circle.
			var refuse_col := Look.COL_LOSE
			refuse_col.a = refuse_col.a * (1.0 - ground_at)
			_paint_ring(
				ground["at"],
				Look.REFUSE_MARK_R_PX,
				refuse_col,
				Look.REFUSE_MARK_WIDTH_PX)

	# ⚠ **`_deck_slots` is gone and there is no `transit_pos` table any more.** A boat carries exactly
	# one soldier (결정 14R), the hull is centred on `boat["pos"]`, and a TRANSIT soldier's
	# `soldier_pos` IS `boat["pos"]` — so the deck slot and `Look.tile_point_px(soldier_pos[i])` were
	# always the same point, computed twice. One fact, one expression, and the halo can no longer walk
	# away from the body it belongs to.

	# --- 5. hit halos, ALL of them, before any body -----------------------------------------------
	# A body here is a 2 px outline plus a 3 px dot, so a white tint has no AREA to paint and reads
	# as no flash at all — the halo is what makes item 3 exist. It has to be under EVERY body and not
	# just its own: drawn per body it would cover the neighbour's outline, and a filled 1.35x circle
	# over a 2 px outline erases that body with the whole round green.
	for e in battle.enemy_alive.size():
		if battle.enemy_alive[e] == 0:
			continue
		var ehalo_key := "e%d" % e
		if _flash_of(ehalo_key) <= 0.0:
			continue
		_paint_halo(
			Look.tile_point_px(battle.enemy_pos[e]) + _body_offset_of(ehalo_key),
			Look.body_radius_of(int(battle.enemy_type[e])) * Look.HIT_HALO_MUL,
			Look.COL_HIT_HALO)
	for raw_halo_id in battle.ashore_ids():
		var hi := int(raw_halo_id)
		var shalo_key := "s%d" % hi
		if _flash_of(shalo_key) <= 0.0:
			continue
		_paint_halo(
			Look.tile_point_px(battle.soldier_pos[hi]) + _body_offset_of(shalo_key),
			Look.body_radius_of(int(army.type_id[hi])) * Look.HIT_HALO_MUL,
			Look.COL_HIT_HALO)
	# A soldier still aboard a boat is `is_hittable` (a coastal crow already reaches it) and the
	# tracer already flies to it — P4's whole fix is that the body finally has somewhere to catch
	# the flash it was always tracking. Same halo, same trigger, only the position is a deck slot.
	for raw_tid in battle.transit_ids():
		var ti := int(raw_tid)
		var thalo_key := "s%d" % ti
		if _flash_of(thalo_key) <= 0.0:
			continue
		_paint_halo(
			Look.tile_point_px(battle.soldier_pos[ti]) + _body_offset_of(thalo_key),
			Look.body_radius_of(int(army.type_id[ti])) * Look.HIT_HALO_MUL,
			Look.COL_HIT_HALO)

	# --- 6. the plan, and then the plan running (P5/P6/P7, plan-then-watch) -----------------------
	# **This one loop draws both screens**, and that is the point: 「a different picture means the plan
	# lied」. Before the commit each entry is a route from a harbour to a landing, a ring on the
	# landing, and a ghost standing on it; after the commit the same entry is a hull moving along the
	# same line with the same ring still on it. Nothing is added at the start button and nothing is
	# taken away — which is also why 「the unspent plan stays visible」 needs no code of its own: a
	# route is drawn while its boat is in `boats` and vanishes with the boat.
	#
	# ⚠ **The fan counter is per LANDING TILE, not per boat.** `boats` index is the drop order across
	# the whole plan, and fanning by it walks a ghost off the ring it belongs to the moment two boats
	# aim at two different beaches: with `GHOST_FAN_PX` 9 px and `TARGET_RING_R_PX` 18 px the fourth
	# boat's ghost is already 38 px from its own ring, and the thirteenth is 3.8 tiles away — over
	# other terrain, possibly on top of another boat's landing. The order the fan has to show is
	# 「who stands in front at THIS beach」 (`plan-then-watch`, 4.4), which is the order among the
	# boats sharing one target and nothing wider.
	var fan_rank := {}
	for bk in battle.boats.size():
		var boat: Dictionary = battle.boats[bk]
		var anchor := Look.tile_point_px(Vector2(boat["pos"]))
		var phase := int(boat["phase"])
		# "Waiting" is read from state that already exists — arrived, but still OUTBOUND means
		# `_try_unload` refused this frame and will try again next frame (4.5) — no new sim field.
		var arrived := float(boat["t"]) * float(boat["speed"]) + Rules.EPS >= float(boat["dist"])
		var waiting := phase == Battle.Phase.OUTBOUND and arrived
		# ⚠ **No hull before the commit.** A boat that has not left is drawn as its PLAN — the route,
		# the ring and the ghost at the far end — and thirteen hulls stacked on one harbour point
		# would be one blob saying nothing at all. OPEN question B in `plan-then-watch` picks the
		# ghost over the hull for exactly this reason: the ghost is at the LANDING, which is the fact
		# the player is authoring.
		if battle.committed():
			var hull_col := Look.COL_BOAT
			if waiting:
				hull_col = hull_col.lerp(Look.COL_HULL_WAIT, _wait_blend())
			_paint_hull(_hull_rect(anchor), hull_col, Look.BODY_OUTLINE_WIDTH_PX)

		# P5 / P6: the whole crossing is on screen, both legs, not only the outbound one — without
		# this a boat TELEPORTS home and the player never learns 4.3's relocation rule exists.
		if phase == Battle.Phase.OUTBOUND:
			var target_px := Look.tile_point_px(battle.grid.tile_point(int(boat["target"])))
			_paint_ring(target_px, Look.TARGET_RING_R_PX, Look.COL_ROUTE, Look.AREA_RING_WIDTH_PX)
			_paint_route(_route_ahead(boat), Look.COL_ROUTE, Look.ROUTE_WIDTH_PX)
			# P7 — the ghost fan. The rank is how many EARLIER boats aim at this same tile, so the
			# fan spreads in the order the player dropped and the FRONT of it is the front of the
			# landing. That is exactly and only what the order decides: every boat departs on the
			# commit frame, so 「어느 순서로」 carries no timing at all, and the fan is the one picture
			# allowed to claim anything about it. Ranking by the boat's index in `boats` instead
			# would spread one beach's fan across the whole plan — see the note above the loop.
			# The offsets are built HERE and handed to the leaf as a finished centre — a constant fan
			# (`rank * 0`) is the fake this shape exists to make impossible to write invisibly.
			if not battle.committed():
				var tgt := int(boat["target"])
				var rank := int(fan_rank.get(tgt, 0))
				fan_rank[tgt] = rank + 1
				var ghosts: Array = boat["soldiers"]
				for gk in ghosts.size():
					var gid := int(ghosts[gk])
					var gtype := int(army.type_id[gid])
					var gcentre := target_px + Look.GHOST_FAN_PX * float(rank)
					_paint_body(
						gcentre,
						Look.body_radius_of(gtype),
						Look.body_corner_radius_of(gtype),
						Look.ghost_tint(),
						Look.BODY_OUTLINE_WIDTH_PX,
						Look.BODY_DOT_RADIUS_PX,
						Vector2.ONE)
		else:
			# The return leg is the outbound path reversed by the sim, so its last waypoint IS the
			# home harbour — asking `battle.harbour_tile(boat["home"])` for it again would be the
			# same fact read from two places, and the whole reason the sim reverses rather than
			# recomputes is to keep it one.
			_paint_route(_route_ahead(boat), Look.COL_ROUTE, Look.ROUTE_WIDTH_PX)

		# P3: the passenger, on deck, with its own HP bar — RETURNING boats carry nobody, so this loop
		# is a no-op for them, which is itself half of what draws the return leg as empty.
		#
		# ⚠ **Gated on the commit, and it is the same `if` the ghost is gated on, inverted.** Before
		# the start button this soldier is drawn ONCE, as a ghost at its landing; after it, ONCE, as a
		# body on its hull. Drop the gate and every planned soldier appears twice — at the harbour it
		# has not left and at the beach it has not reached.
		var soldiers: Array = boat["soldiers"] if battle.committed() else []
		for k in soldiers.size():
			var i := int(soldiers[k])
			var st := int(army.type_id[i])
			var skey := "s%d" % i
			var sradius := Look.body_radius_of(st)
			# `Look.tile_point_px(battle.soldier_pos[i])` and not `anchor`, even though a TRANSIT
			# soldier's `soldier_pos` IS its boat's `pos` and the two are numerically equal: the halo
			# pass above reads it that way, and one fact written two different ways is the shape this
			# file's own `_body_offset_of` comment warns about.
			var scentre := Look.tile_point_px(battle.soldier_pos[i]) + _body_offset_of(skey)
			_paint_body(
				scentre,
				sradius,
				Look.body_corner_radius_of(st),
				Look.body_colour_of(false).lerp(Look.COL_FLASH, _flash_of(skey)),
				Look.BODY_OUTLINE_WIDTH_PX,
				Look.BODY_DOT_RADIUS_PX,
				_gait_squash(skey))
			if army.has_beak[i] != 0:
				var ttri := _beak_points(scentre, sradius, _facing_of(i, false))
				_paint_beak(ttri[0], ttri[1], ttri[2], Look.COL_BEAK)
			var tbars := _hp_rects(scentre, st, army.hp[i] / Rules.hp_of(st))
			_paint_hp(tbars[0], Look.hp_bar_colour(false), tbars[1], Look.hp_bar_colour(true))

	# --- 6b. the army still standing at the harbour (P4, plan-then-watch) --------------------------
	# **This is the thing the player drags**, and it is on the map rather than in a HUD strip because
	# the user's own sentence is 「내가 내릴 수 있는 곳 위치에 딱 나서 … 끌어서 탁 놓으면」. Drawing it in a
	# strip as well would be one fact under two names, which `look.gd`'s header forbids.
	#
	# ⚠ **It is drawn during the fight too, and that is deliberate.** A soldier you never sent stays
	# RESERVE for the whole island, alive, and carries to the next one — so 「I lost with eight still
	# at home」 has to be readable, and a stack that vanished at the start button would hide it.
	#
	# The rect comes from `idle_soldier_rect`, never from re-deriving the anchor here: `game.gd`'s hit
	# test needs the EXACT rect that reaches the screen. A hand-rolled hit test that tested a tile
	# index instead of the drawn rect once left ~70% of a hull dead to a press.
	for ii in battle.soldier_state.size():
		var irect := idle_soldier_rect(ii)
		if irect.size == Vector2.ZERO:
			continue
		var itype := int(army.type_id[ii])
		var icentre := irect.position + irect.size * 0.5
		_paint_body(
			icentre,
			Look.body_radius_of(itype),
			Look.body_corner_radius_of(itype),
			Look.body_colour_of(false),
			Look.BODY_OUTLINE_WIDTH_PX,
			Look.BODY_DOT_RADIUS_PX,
			Vector2.ONE)
		if army.has_beak[ii] != 0:
			# Facing RIGHT and not `_facing_of`: a soldier in reserve has no target, and `_facing_of`
			# would answer RIGHT anyway — asking it here would only invite someone to "fix" it into
			# aiming at an enemy the soldier cannot reach and has not been sent at.
			var itri := _beak_points(icentre, Look.body_radius_of(itype), Vector2.RIGHT)
			_paint_beak(itri[0], itri[1], itri[2], Look.COL_BEAK)
		# The HP bar is not decoration on this pass. Soldiers carry their damage between islands and a
		# dead one is dead for good, so 「which of these thirteen is nearly gone」 is a planning fact,
		# and it is only readable before anything is dropped.
		var ibars := _hp_rects(icentre, itype, army.hp[ii] / Rules.hp_of(itype))
		_paint_hp(ibars[0], Look.hp_bar_colour(false), ibars[1], Look.hp_bar_colour(true))

	# --- 7. enemies ------------------------------------------------------------------------------
	# Drawn before the soldiers so an ally on the same tile reads on top of what it is fighting.
	for e in battle.enemy_alive.size():
		if battle.enemy_alive[e] == 0:
			continue
		var et := int(battle.enemy_type[e])
		var ekey := "e%d" % e
		# ONE offset, computed once and handed to the body, the halo and the bar alike. Riding it on
		# the body alone leaves the HP bar standing where the body used to be, and `net_draw_leaf`
		# can never see that — every per-function count and every argument is unchanged.
		var ecentre := Look.tile_point_px(battle.enemy_pos[e]) + _body_offset_of(ekey)
		_paint_body(
			ecentre,
			Look.body_radius_of(et),
			Look.body_corner_radius_of(et),
			Look.body_colour_of(true).lerp(Look.COL_FLASH, _flash_of(ekey)),
			Look.BODY_OUTLINE_WIDTH_PX,
			Look.BODY_DOT_RADIUS_PX,
			_gait_squash(ekey))
		var ebars := _hp_rects(ecentre, et, battle.enemy_hp[e] / Rules.hp_of(et))
		var eback: Rect2 = ebars[0]
		var efill: Rect2 = ebars[1]
		_paint_hp(eback, Look.hp_bar_colour(false), efill, Look.hp_bar_colour(true))

	# --- 8. soldiers ashore -----------------------------------------------------------------------
	for raw_id in battle.ashore_ids():
		var i := int(raw_id)
		var st := int(army.type_id[i])
		var skey := "s%d" % i
		var sradius := Look.body_radius_of(st)
		var scentre := Look.tile_point_px(battle.soldier_pos[i]) + _body_offset_of(skey)
		_paint_body(
			scentre,
			sradius,
			Look.body_corner_radius_of(st),
			Look.body_colour_of(false).lerp(Look.COL_FLASH, _flash_of(skey)),
			Look.BODY_OUTLINE_WIDTH_PX,
			Look.BODY_DOT_RADIUS_PX,
			_gait_squash(skey))
		if army.has_beak[i] != 0:
			var tri := _beak_points(scentre, sradius, _facing_of(i, false))
			var tip: Vector2 = tri[0]
			var left: Vector2 = tri[1]
			var right: Vector2 = tri[2]
			_paint_beak(tip, left, right, Look.COL_BEAK)
		var sbars := _hp_rects(scentre, st, army.hp[i] / Rules.hp_of(st))
		var sback: Rect2 = sbars[0]
		var sfill: Rect2 = sbars[1]
		_paint_hp(sback, Look.hp_bar_colour(false), sfill, Look.hp_bar_colour(true))

	# --- 9. tracers, then hit sparks. Both above every body ---------------------------------------
	# A bullet passes over what it is crossing, and the spark has to clear BOTH outlines: the contact
	# point is by definition between them, and the halo it is meant to read against is at layer 5.
	# Under the bodies the shard would slide back under the very outlines it exists to escape.
	for raw_shot in _fx:
		var shot: Dictionary = raw_shot
		if int(shot["kind"]) != FxKind.SHOT:
			continue
		var muzzle: Vector2 = shot["from"]
		var landing: Vector2 = shot["to"]
		var flight := muzzle.distance_to(landing)
		if flight <= Rules.EPS:
			continue
		var travelled := flight * clampf(float(shot["age"]) / float(shot["life"]), 0.0, 1.0)
		var heading := (landing - muzzle) / flight
		# A stub, not the whole line — the whole line IS item 6. Its tail is clamped to the muzzle so
		# the first frames grow out of the shooter instead of starting inside it.
		_paint_shot(
			muzzle + heading * maxf(0.0, travelled - Look.SHOT_LEN_PX),
			muzzle + heading * travelled,
			Look.COL_SHOT,
			Look.SHOT_WIDTH_PX)

	for raw_spark in _fx:
		var spark: Dictionary = raw_spark
		if int(spark["kind"]) != FxKind.SPARK:
			continue
		if float(spark["age"]) < float(spark["delay"]):
			continue
		# **The points are built HERE and handed to the leaf.** Built inside the leaf they never leave
		# it, and `net_draw_leaf`'s unused-argument check skips any function whose draw count is 0 —
		# so a leaf holding `draw_multiline(PackedVector2Array(), ...)` would be green with nothing on
		# screen. `_beak_points` -> `_paint_beak` is the same shape for the same reason.
		_paint_spark(
			_spark_points(
				spark["at"],
				spark["facing"],
				clampf((float(spark["age"]) - float(spark["delay"])) / float(spark["life"]),
					0.0, 1.0)),
			Look.COL_SPARK,
			Look.SPARK_WIDTH_PX)

	# --- 10. death bursts, above everything -------------------------------------------------------
	# On the floor a 10 px crow burst is buried under a 22 px lion.
	for raw_burst in _fx:
		var burst: Dictionary = raw_burst
		if int(burst["kind"]) != FxKind.BURST:
			continue
		var grown := clampf(float(burst["age"]) / float(burst["life"]), 0.0, 1.0)
		var burst_col: Color = burst["colour"]
		burst_col.a = burst_col.a * (1.0 - grown)
		_paint_ring(
			burst["at"],
			float(burst["radius"]) * lerpf(1.0, Look.BURST_GROWTH, grown),
			burst_col,
			Look.BURST_WIDTH_PX)


# --- the eleven hooks. Every draw_* call in this file is inside one of them ----------------------

## 2 calls. **One is not enough and that is why the table says two**: the terrain tone and the faint
## grid are separate layers, and a game where position is the decision needs the grid visible or the
## player cannot pick a position.
func _paint_tile(rect: Rect2, fill: Color, line_colour: Color, line_width: float) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, line_colour, false, line_width)


## 1 call. An outline, not a fill — see the harbour comment in `_draw`. The name is unchanged from
## the old dock hook even though the concept moved to a harbour in `boat-and-landing`; stage 5 draws
## a hull with `_paint_hull` on top of this marker when a boat is actually sitting there.
func _paint_dock(rect: Rect2, colour: Color, outline_width: float) -> void:
	draw_rect(rect, colour, false, outline_width)


## 2 calls: the rounded-square outline, then the centre dot.
##
## **Friend and foe are told apart by `colour`; the unit type by `radius` and `corner`.** Encoding
## the type in colour too would mean five ally tones and five enemy tones that have to stay legible
## against each other, and nothing on screen would say which side a new body is on.
##
## `squash` is the gait, and it is a `Vector2` rather than a scalar because a single radius can only
## PULSE — "pressed along the direction of travel and spread across it" cannot be said with one
## number at all. Only the outline is squashed; the centre dot keeps its radius, so the body reads as
## deforming rather than shrinking.
func _paint_body(centre: Vector2, radius: float, corner: float, colour: Color,
		outline_width: float, dot_radius: float, squash: Vector2) -> void:
	draw_polyline(_rounded_square(centre, radius, corner, squash), colour, outline_width)
	draw_circle(centre, dot_radius, colour)


## 1 call. A triangle poking out past the outline, so which soldier carries the beak is readable
## without clicking anything.
func _paint_beak(tip: Vector2, left: Vector2, right: Vector2, colour: Color) -> void:
	draw_colored_polygon(PackedVector2Array([tip, left, right]), colour)


## 2 calls: the empty bar, then the filled part on top of it.
##
## **The empty half is drawn on purpose.** A bar that is only ever as long as the HP left has no
## length to lose, so nothing on screen goes down — and "no moment was fun" in the last game came
## partly from exactly that.
func _paint_hp(back: Rect2, back_colour: Color, fill: Rect2, fill_colour: Color) -> void:
	draw_rect(back, back_colour)
	draw_rect(fill, fill_colour)


## 2 calls: the filled hull, then a darker outline so its edge reads even sitting on same-toned
## water. `colour.darkened(...)` is a METHOD CALL on the argument, not a new stored literal — it
## matches neither half of the "no `Color(` / no `Color.`" rule the rest of this file lives under.
## Replaces `_paint_boat` (`boat-and-landing` stage 5, 7.3): a flat rect said nothing about which
## boat this was or whether it was carrying anyone.
func _paint_hull(rect: Rect2, colour: Color, outline_width: float) -> void:
	draw_rect(rect, colour, true)
	draw_rect(rect, colour.darkened(0.35), false, outline_width)


## 1 call — `draw_polyline`, over however many waypoints the caller built. The water route from a
## harbour to the candidate tile while a drag is in flight (P8), the REMAINING route under a crossing
## hull, and the remaining route home on the return leg (P5 / P6) — one hook, three call sites in
## `_draw()`, same shape.
##
## ⚠⚠ **This was `draw_line(from, to, ...)` and the change is invisible to every scanner.**
## `net_draw_leaf` counts call SITES, so a polyline and a straight line between the same endpoints are
## both "1 call, every argument used" — and a `draw_line(points[0], points[points.size() - 1], ...)`
## written in here would put the route back over the island with the whole round green. What catches
## it is a RUNTIME check in `net_shell` reading the captured `points` back and asserting the drag over
## a bent route hands this more than two of them. `speed-off-open-landing`'s S4 is that row.
func _paint_route(points: PackedVector2Array, colour: Color, width: float) -> void:
	draw_polyline(points, colour, width)


## 1 call. `draw_multiline` — the same shape `_paint_spark` uses, and for the same reason: a loop
## indexing pairs INSIDE the leaf can drop the second endpoint of one pair with no scanner catching
## it, and a flat array handed straight to one native call leaves no index inside the leaf to drop.
## P10: a line along each SEAWARD edge of a cliff tile (whichever ortho side touches water), the only
## thing that reads as height with no elevation axis at all (3.2).
func _paint_cliff_face(points: PackedVector2Array, colour: Color, width: float) -> void:
	draw_multiline(points, colour, width)


## 1 call. The tracer stub for item 1.
func _paint_shot(from: Vector2, to: Vector2, colour: Color, width: float) -> void:
	draw_line(from, to, colour, width)


## 1 call, FILLED — the whole point of item 3's halo is that it has area where the body has none.
func _paint_halo(centre: Vector2, radius: float, colour: Color) -> void:
	draw_circle(centre, radius, colour)


## 1 call, shared by the death burst (4), the area ring and the lion's telegraph (5) and the landing
## ring (7). They differ in colour, radius, width and layer, and nothing else — three leaves would be
## three copies of one `draw_arc`.
func _paint_ring(centre: Vector2, radius: float, colour: Color, width: float) -> void:
	draw_arc(centre, radius, 0.0, TAU, RING_SEGMENTS, colour, width)


## 1 call.
func _paint_target_line(from: Vector2, to: Vector2, colour: Color, width: float) -> void:
	draw_line(from, to, colour, width)


## 1 call. `draw_multiline` paints all six shards at once, so raising `SPARK_COUNT` never moves this
## file's per-function count — which is why the count is safe to pin.
func _paint_spark(points: PackedVector2Array, colour: Color, width: float) -> void:
	draw_multiline(points, colour, width)


# --- pure helpers. None of these calls draw_* ---------------------------------------------------

## The part of a boat's route it has NOT sailed yet, in canvas px: where the hull is standing now,
## then every waypoint strictly past the segment it is on. **Draw 0** — it builds geometry and hands
## it to `_paint_route`.
##
## ⚠⚠ **`leg` is read off the SIM and the walk is never re-derived here.** `_phase_boats` advances it
## as the boat moves; a view that found its own segment by re-walking `cum` would be the same fact
## computed in two places, and the two would drift the first time one of them changed — which is the
## failure this file's own deleted `_deck_slots` comment records. The drawn line therefore cannot show
## a boat sailing water it has already crossed, because the sim is what decides what is behind it.
func _route_ahead(boat: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append(Look.tile_point_px(Vector2(boat["pos"])))
	var path: PackedVector2Array = boat["path"]
	for k in range(int(boat["leg"]) + 1, path.size()):
		out.append(Look.tile_point_px(path[k]))
	return out


func _tile_xy(tile: int) -> Vector2i:
	var w := battle.grid.w
	return Vector2i(tile % w, tile / w)


## The hull rectangle, centred on world point `at` (`boat["pos"]`). **One size for every boat**: the
## capacity column died with `Rules.BOATS` (`plan-then-watch`, 결정 14R), a boat carries the one
## soldier that was dragged onto it, and nothing distinguishes two boats. `BOAT_SLOT_PX + 2 *
## BOAT_HULL_PAD_PX` = 46 px wide.
##
## ⚠ **It lost its `boat` and `slot` arguments, and both are gone rather than defaulted.** There is no
## fleet slot to index, and there is no second hull at one anchor to shift sideways — a boat is drawn
## only after the commit, by which point it is moving.
func _hull_rect(at: Vector2) -> Rect2:
	var w := Look.BOAT_SLOT_PX + 2.0 * Look.BOAT_HULL_PAD_PX
	var h := Look.BOAT_HULL_H_PX
	return Rect2(at - Vector2(w, h) * 0.5, Vector2(w, h))


## Where soldier `i` is drawn while it is still in reserve, standing at the START HARBOUR — the body
## the player presses to begin a drag (P4). `Rect2()` (zero size) for anything that is not RESERVE:
## dead, already sent, or already ashore. **That zero is what makes the stack visibly empty as the
## plan fills**, and it is also what stops a corpse being draggable, which `Battle.send` would refuse
## anyway.
##
## ⚠ **The slot is the SOLDIER ID and not a position in a list.** Re-flowing the stack every time one
## is dragged away would move every body under the cursor mid-plan; a hole stays where the soldier
## was, and the hole is the feedback.
##
## ⚠ **`_draw()`'s idle pass and `game.gd::_soldier_hit_at` BOTH call this**, rather than either one
## re-deriving the anchor: the hit test has to answer to the EXACT rect that reaches the screen. A
## hand-rolled hit test that tested a tile index instead of the drawn rect once left ~70% of a hull
## dead to a press, with a camera pan starting silently in its place.
func idle_soldier_rect(i: int) -> Rect2:
	if battle == null or battle.grid == null or army == null:
		return Rect2()
	if i < 0 or i >= battle.soldier_state.size():
		return Rect2()
	if battle.soldier_state[i] != Battle.SoldierState.RESERVE:
		return Rect2()
	var harbour_tile := battle.harbour_tile(battle.grid.start_harbour)
	if harbour_tile < 0:
		return Rect2()
	var centre := Look.tile_point_px(battle.grid.tile_point(harbour_tile)) \
		+ Look.idle_soldier_offset_px(i)
	var r := Look.body_radius_of(int(army.type_id[i]))
	return Rect2(centre - Vector2(r, r), Vector2(r, r) * 2.0)


## Back rectangle first, filled rectangle second. The fill shrinks from the right, so the bar's left
## edge stays put and a body's HP can be compared to its neighbour's at a glance.
func _hp_rects(centre: Vector2, type_id: int, frac: float) -> Array:
	var origin := Look.hp_bar_origin_px(centre, type_id)
	var span := Look.hp_bar_size_px()
	var f := clampf(frac, 0.0, 1.0)
	return [Rect2(origin, span), Rect2(origin, Vector2(span.x * f, span.y))]


## Tip, then the two base corners. The base sits on the body's EDGE and the length is measured
## outward from there — `Look.BEAK_LENGTH_PX` is how far it sticks out, not how far it is from the
## centre, so the same constant reads the same on a 10 px crow and a 22 px lion.
func _beak_points(centre: Vector2, radius: float, facing: Vector2) -> Array:
	var edge := centre + facing * radius
	var side := Vector2(-facing.y, facing.x) * (Look.BEAK_WIDTH_PX * 0.5)
	return [edge + facing * Look.BEAK_LENGTH_PX, edge + side, edge - side]


## Which way a body is pointing: toward its current target, and to the right when it has none — a
## zero vector normalised is zero, which would collapse the beak triangle to a point and aim a lunge
## nowhere while every check about them still passed.
##
## **`is_enemy` is not decoration.** Two of the three types whose range is 0 — the bison and the lion
## — are enemies, and they are exactly the ones that lunge, so a soldier-only version of this
## function would aim every enemy lunge to the right.
func _facing_of(i: int, is_enemy: bool) -> Vector2:
	var here := Vector2.ZERO
	var there := Vector2.ZERO
	if is_enemy:
		var aim := int(battle.enemy_target[i])
		if aim < 0 or not battle.is_hittable(aim):
			return Vector2.RIGHT
		here = battle.enemy_pos[i]
		there = battle.soldier_pos[aim]
	else:
		var tgt := int(battle.soldier_target[i])
		if tgt < 0 or tgt >= battle.enemy_alive.size() or battle.enemy_alive[tgt] == 0:
			return Vector2.RIGHT
		here = battle.soldier_pos[i]
		there = battle.enemy_pos[tgt]
	var away := there - here
	if away.length() <= Rules.EPS:
		return Vector2.RIGHT
	return away.normalized()


## A closed rounded-square outline, four corner arcs joined. `corner` is clamped to `radius`, so a
## corner ratio of 1.0 degenerates to a circle rather than folding the polygon inside out.
## `squash` scales every vertex about the centre, component-wise: `Vector2.ONE` is the rest shape.
func _rounded_square(centre: Vector2, radius: float, corner: float, squash: Vector2) -> PackedVector2Array:
	var r := clampf(corner, 0.0, radius)
	var inner := radius - r
	var pivots := [
		Vector2(inner, -inner),
		Vector2(inner, inner),
		Vector2(-inner, inner),
		Vector2(-inner, -inner),
	]
	var out := PackedVector2Array()
	for k in pivots.size():
		var pivot: Vector2 = pivots[k]
		var start := -PI * 0.5 + k * PI * 0.5
		for s in CORNER_SEGMENTS + 1:
			var a := start + PI * 0.5 * (float(s) / float(CORNER_SEGMENTS))
			out.append(centre + (pivot + Vector2(cos(a), sin(a)) * r) * squash)
	# Closes the loop. draw_polyline does not close for you, and an open outline leaves a notch in
	# the top-right corner of every body in the game.
	out.append(out[0])
	return out


## Ages both drawers by one frame and drops what has finished, then walks every body that can be on
## screen so the gait phase advances by DISTANCE rather than by time.
##
## Creating the per-body entries is done HERE and nowhere else. `_drain_events` deliberately refuses
## to create one: a body with no entry this frame is a body that is not on screen this frame, and
## flashing a corpse is the one thing item 3 must not do.
func _fx_step(delta: float) -> void:
	var live := []
	for raw_fx in _fx:
		var fx: Dictionary = raw_fx
		fx["age"] = float(fx["age"]) + delta
		if float(fx["age"]) < float(fx["delay"]) + float(fx["life"]):
			live.append(fx)
	_fx = live

	_shake_left = maxf(0.0, _shake_left - delta)
	if _shake_left <= 0.0:
		_shake_amp = 0.0

	for key: String in _body:
		var b: Dictionary = _body[key]
		b["flash"] = maxf(0.0, float(b["flash"]) - delta)
		b["knock"] = maxf(0.0, float(b["knock"]) - delta)
		b["lunge"] = maxf(0.0, float(b["lunge"]) - delta)

	if battle == null or army == null:
		return

	# Every alive enemy and every HITTABLE soldier — a soldier still aboard a boat can be shot by a
	# coastal crow, and without an entry that hit would have nothing to flash.
	var walkers := []
	for e in battle.enemy_alive.size():
		if battle.enemy_alive[e] != 0:
			walkers.append(["e%d" % e, battle.enemy_pos[e]])
	for i in battle.soldier_state.size():
		if battle.is_hittable(i):
			walkers.append(["s%d" % i, battle.soldier_pos[i]])

	for raw_walker in walkers:
		var walker: Array = raw_walker
		var key: String = walker[0]
		var here: Vector2 = walker[1]
		if not _body.has(key):
			_body[key] = {
				"flash": 0.0,
				"knock": 0.0,
				"knock_dir": Vector2.RIGHT,
				"lunge": 0.0,
				"lunge_dir": Vector2.RIGHT,
				"push": 0.0,
				"gait": 0.0,
				"head": Vector2.RIGHT,
				"last": here,
			}
		var b: Dictionary = _body[key]
		var last: Vector2 = b["last"]
		var moved := here.distance_to(last)
		if moved > Rules.EPS:
			# Positions are in TILES and so is the period, so the two divide directly. Phase on
			# distance is the whole of "it must not slide": a body that does not move does not
			# animate, and no amount of time passing changes that.
			b["gait"] = fposmod(
				float(b["gait"]) + TAU * moved / Look.GAIT_PERIOD_TILES, TAU)
			b["head"] = (here - last).normalized()
		b["last"] = here


## Turns one frame of sim FACTS into effects. Everything geometric is frozen here, on the frame the
## fact happened, because every one of these outlives the frame that produced it.
func _drain_events() -> void:
	if battle == null or army == null:
		return
	var born := []
	for raw_ev in battle.events:
		var ev: Dictionary = raw_ev
		var kind := int(ev["kind"])

		if kind == Battle.Event.LAND:
			if Look.fx_gain_of(7) > 0.0:
				born.append({
					"kind": FxKind.LAND,
					"age": 0.0,
					"delay": 0.0,
					"life": Look.LAND_RING_SEC,
					"at": Look.tile_point_px(battle.soldier_pos[int(ev["id"])]),
				})
			continue

		if kind == Battle.Event.DEATH:
			if Look.fx_gain_of(4) <= 0.0:
				continue
			var did := int(ev["id"])
			var dead_enemy: bool = ev["is_enemy"]
			var dtype := int(battle.enemy_type[did]) if dead_enemy else int(army.type_id[did])
			var dpos: Vector2 = battle.enemy_pos[did] if dead_enemy else battle.soldier_pos[did]
			born.append({
				"kind": FxKind.BURST,
				"age": 0.0,
				"delay": 0.0,
				"life": Look.BURST_SEC,
				"at": Look.tile_point_px(dpos),
				"radius": Look.body_radius_of(dtype),
				"colour": Look.body_colour_of(dead_enemy),
			})
			continue

		if kind != Battle.Event.ATTACK:
			continue

		var from_id := int(ev["from"])
		var from_enemy: bool = ev["from_enemy"]
		var to_id := int(ev["to"])
		var atk_type := int(battle.enemy_type[from_id]) if from_enemy else int(army.type_id[from_id])
		var tgt_type := int(army.type_id[to_id]) if from_enemy else int(battle.enemy_type[to_id])
		var atk_tile: Vector2 = battle.enemy_pos[from_id] if from_enemy \
			else battle.soldier_pos[from_id]
		var tgt_tile: Vector2 = battle.soldier_pos[to_id] if from_enemy \
			else battle.enemy_pos[to_id]
		var atk_px := Look.tile_point_px(atk_tile)
		var tgt_px := Look.tile_point_px(tgt_tile)
		var atk_key := ("e%d" if from_enemy else "s%d") % from_id

		# **The reaction is delayed by exactly the tracer's flight time.** The sim landed the damage
		# on the firing frame, so without this the target flashes and flinches before the bullet has
		# left the muzzle — the one thing item 1's own spec calls a lie about time.
		var reaction := 0.0
		if Rules.range_of(atk_type) > 0.0:
			reaction = Look.SHOT_SEC
			if Look.fx_gain_of(1) > 0.0:
				born.append({
					"kind": FxKind.SHOT,
					"age": 0.0,
					"delay": 0.0,
					"life": Look.SHOT_SEC,
					"from": atk_px,
					"to": tgt_px,
				})
		else:
			var facing := _facing_of(from_id, from_enemy)
			var r_self := Look.body_radius_of(atk_type)
			# The push is capped at `gap + LUNGE_BITE_PX` rather than being a flat distance: the grid
			# guarantees one body per tile, so the gap is 40 px or 56.6 px and a flat push drove the
			# lion 33.6 px into a body 40 px away and swallowed it whole. With the cap the worst
			# overlap in any pairing is exactly LUNGE_BITE_PX, by construction.
			var gap := maxf(0.0,
				atk_px.distance_to(tgt_px) - r_self - Look.body_radius_of(tgt_type))
			var push := minf(Look.LUNGE_PUSH_RATIO * r_self, gap + Look.LUNGE_BITE_PX) \
				* Look.fx_gain_of(2)
			if _body.has(atk_key):
				var ab: Dictionary = _body[atk_key]
				ab["lunge"] = Look.LUNGE_SEC
				ab["lunge_dir"] = facing
				ab["push"] = push
			if Look.fx_gain_of(2) > 0.0:
				# The contact point is frozen at the body edge AS IT WILL BE at the peak of the
				# lunge, `r_self + push` out — not at `r_self`. The shards are seen half a lunge
				# later, when the body really is that far forward, so freezing the un-pushed edge
				# would root them inside the striker.
				born.append({
					"kind": FxKind.SPARK,
					"age": 0.0,
					"delay": Look.LUNGE_SEC * 0.5,
					"life": Look.SPARK_SEC,
					"at": atk_px + facing * (r_self + push),
					"facing": facing,
				})

		var area := float(ev["area"])
		if area > 0.0 and Look.fx_gain_of(5) > 0.0:
			born.append({
				"kind": FxKind.AREA,
				"age": 0.0,
				"delay": 0.0,
				"life": Look.AREA_RING_SEC,
				"at": tgt_px,
				"radius": area * Look.TILE_PX,
			})

		var victims := [to_id]
		for raw_splash in ev["splash"]:
			victims.append(int(raw_splash))
		for raw_victim in victims:
			var v := int(raw_victim)
			var vkey := ("s%d" if from_enemy else "e%d") % v
			if not _body.has(vkey):
				continue
			var vb: Dictionary = _body[vkey]
			# Age is RESET, never stacked. A second entry would multiply the halo's alpha until the
			# body was simply white, and the Dictionary key makes stacking structurally impossible.
			vb["flash"] = Look.HIT_FLASH_SEC + reaction
			vb["knock"] = Look.HIT_KNOCK_SEC + reaction
			var vtile: Vector2 = battle.soldier_pos[v] if from_enemy else battle.enemy_pos[v]
			var away := Look.tile_point_px(vtile) - atk_px
			vb["knock_dir"] = Vector2.RIGHT if away.length() <= Rules.EPS else away.normalized()

		# Amplitude tracks damage, or half of this effect is dead: a 2-damage cell and the lion's 4
		# have to feel different. A hit landing during an older shake only restarts it when it is at
		# least as strong as what is left, so a crow cannot cut a lion's blow short.
		var amp := minf(Look.SHAKE_MAX_PX, float(ev["dmg"]) * Look.SHAKE_PER_DAMAGE_PX)
		if amp >= _shake_amp * (_shake_left / Look.SHAKE_SEC):
			_shake_amp = amp
			_shake_left = Look.SHAKE_SEC

	for raw_new in born:
		_fx.append(raw_new)
	# The transient drawer is capped and the OLDEST goes: the per-body drawer is bounded by the
	# number of bodies instead, which is why this rule cannot reach a flash or a lunge.
	while _fx.size() > Look.FX_MAX_COUNT:
		_fx.remove_at(0)


## The shake, as an ABSOLUTE offset to assign to `position`.
##
## The phase runs off the shake's OWN age rather than a wall clock, which makes it deterministic —
## a random shake cannot be measured by any net — and starts it from rest so there is no pop. The
## magnitude is limited rather than left as two independent sines, because two sines at ±1 would put
## the corner at 1.41 x the cap and the cap would stop being a cap.
func _shake_offset() -> Vector2:
	if _shake_left <= 0.0:
		return Vector2.ZERO
	var decay := _shake_left / Look.SHAKE_SEC
	var age := Look.SHAKE_SEC - _shake_left
	var mag := _shake_amp * decay * Look.fx_gain_of(11)
	if mag <= 0.0:
		return Vector2.ZERO
	var raw := Vector2(sin(age * Look.SHAKE_A_FREQ), sin(age * Look.SHAKE_B_FREQ))
	return (raw * mag).limit_length(mag)


## P7. 0..1, one full on/off cycle every `HULL_WAIT_BLINK_SEC` — a raised cosine rather than a raw
## sine, so it sits at exactly 0 and 1 at the ends of each half-cycle instead of sweeping through
## every value with no rest, which reads as a pulse rather than a smear.
func _wait_blend() -> float:
	return 0.5 - 0.5 * cos(TAU * _wait_clock / Look.HULL_WAIT_BLINK_SEC)


## The one place a body's drawing offset is computed, so the body, the halo, the beak and the HP bar
## are all handed the same number. Split across call sites, one of them is eventually forgotten and
## the body walks out from under its own health bar with the whole round green.
func _body_offset_of(key: String) -> Vector2:
	return _lunge_offset(key) + _knock_offset(key)


## Item 2①. A triangle: exactly 0 at both ends and full push at the halfway point, so no body is ever
## left sitting displaced when it finishes.
func _lunge_offset(key: String) -> Vector2:
	if not _body.has(key):
		return Vector2.ZERO
	var b: Dictionary = _body[key]
	var left := float(b["lunge"])
	if left <= 0.0:
		return Vector2.ZERO
	var dir: Vector2 = b["lunge_dir"]
	var at := 1.0 - left / Look.LUNGE_SEC
	return dir * (float(b["push"]) * (1.0 - absf(2.0 * at - 1.0)))


## Item 3③. Full `HIT_KNOCK_PX` on the frame the blow is felt, decaying to 0.
##
## The countdown carries the tracer's delay on top of `HIT_KNOCK_SEC` and this only reads while it is
## back inside that window — the same trick the flash uses, and for the same reason: a body must not
## flinch away from a bullet that has not arrived.
func _knock_offset(key: String) -> Vector2:
	if not _body.has(key):
		return Vector2.ZERO
	var b: Dictionary = _body[key]
	var left := float(b["knock"])
	if left <= 0.0 or left > Look.HIT_KNOCK_SEC:
		return Vector2.ZERO
	var dir: Vector2 = b["knock_dir"]
	return dir * (Look.HIT_KNOCK_PX * Look.fx_gain_of(3) * (left / Look.HIT_KNOCK_SEC))


## Item 3①. How much white is mixed into this body's colour, 0.0 when it is not being hit.
##
## It does NOT ramp: `HIT_FLASH_STRENGTH` is held for the whole window and then drops out. Fading it
## would spend the back half of a 9-frame beat on a tint too weak to see, and the halo underneath is
## what carries the effect anyway.
func _flash_of(key: String) -> float:
	if not _body.has(key):
		return 0.0
	var b: Dictionary = _body[key]
	var left := float(b["flash"])
	if left <= 0.0 or left > Look.HIT_FLASH_SEC:
		return 0.0
	return Look.HIT_FLASH_STRENGTH * Look.fx_gain_of(3)


## Item 12. `1 - s*sin(phase)` along the heading and `1 + s*sin(phase)` across it, delivered in
## SCREEN axes because that is all `_rounded_square` can apply.
##
## The heading is resolved to whichever screen axis it leans on rather than blended between them:
## blending cancels the two factors exactly on a 45-degree heading, and units on this grid walk
## diagonals constantly — the effect would simply vanish for half of all movement. The cost is a
## swap when a body crosses 45 degrees, on an amplitude of 2 to 4 px.
##
## `sin` and not `cos` is load-bearing: a standing body sits at phase 0 and must be UNDEFORMED, and
## a cosine would leave every idle body permanently squashed.
func _gait_squash(key: String) -> Vector2:
	if not _body.has(key):
		return Vector2.ONE
	var b: Dictionary = _body[key]
	var s := Look.GAIT_SQUASH * Look.fx_gain_of(12) * sin(float(b["gait"]))
	if absf(s) <= 0.0:
		return Vector2.ONE
	var head: Vector2 = b["head"]
	if absf(head.x) >= absf(head.y):
		return Vector2(1.0 - s, 1.0 + s)
	return Vector2(1.0 + s, 1.0 - s)


## Item 2②. The six shards as twelve points, inner end then outer end, ready for `draw_multiline`.
##
## **The fan opens along the TANGENT of the two touching faces**, three shards to each side. That is
## the only axis on which every point moves away from BOTH centres: opened along ±facing, every one
## of the ten points lands back inside the striker's own outline, because the contact point is always
## `(HIT_HALO_MUL - 1) * own radius` deep inside the striker's own halo. The shards are NOT claimed
## to escape the target's halo — what carries this effect is that they move while everything under
## them stands still.
func _spark_points(centre: Vector2, facing: Vector2, progress: float) -> PackedVector2Array:
	var tangent := Vector2(-facing.y, facing.x)
	var outer := Look.SPARK_REACH_PX * progress
	# The shard has LENGTH, so its inner end trails the tip by SPARK_LEN_PX. Every margin in the
	# spec is computed from this end and never from the tip — built from the tip, half the points
	# would pass a check they were never inside.
	var inner := maxf(0.0, outer - Look.SPARK_LEN_PX)
	var per_side := Look.SPARK_COUNT / 2
	var spread := deg_to_rad(Look.SPARK_SPREAD_DEG)
	var out := PackedVector2Array()
	for k in Look.SPARK_COUNT:
		var side := 1.0 if k < per_side else -1.0
		var slot := k % per_side
		var lean := 0.0
		if per_side > 1:
			lean = float(slot) / float(per_side - 1) * 2.0 - 1.0
		var dir := (tangent * side).rotated(spread * lean)
		out.append(centre + dir * inner)
		out.append(centre + dir * outer)
	return out
