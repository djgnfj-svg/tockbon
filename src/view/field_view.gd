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
## lives inside one of those eleven hooks, in the exact per-function counts `combat-juice` pins under
## "Every hook table". A net overrides a hook and reads its arguments back; the per-function count is
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

## What lives in the transient drawer. Anything bolted to a BODY lives in `_body` instead, keyed by
## body, which is why "drop the oldest" and "one flash per body, age reset rather than stacked" never
## eat each other — they are rules of two different drawers.
enum FxKind { SHOT, SPARK, BURST, AREA, LAND }


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
	position = Vector2.ZERO
	queue_redraw()


## The sim moves every frame and a `Node2D` only repaints when it is asked to. Without this line the
## picture freezes on the first frame while `battle.step` keeps running — the signature fake, with
## the sim and the screen the wrong way round.
##
## **The order of these three is load-bearing.** Ageing first and draining second means an effect
## born this frame is drawn at full amplitude on the frame it was born, so the flinch really does
## reach `HIT_KNOCK_PX` and the shake really does reach `dmg * SHAKE_PER_DAMAGE_PX` once. Draining
## first would shave one frame's delta off every effect before anyone saw it.
func _process(delta: float) -> void:
	_fx_step(delta)
	_drain_events()
	position = _shake_offset()
	queue_redraw()


func _draw() -> void:
	if battle == null or army == null or battle.grid == null:
		return
	if battle.grid.w <= 0:
		return

	# --- 1. terrain, one margin ring wider than the grid ----------------------------------------
	# The grid fills the viewport exactly (32 x 40 = 1280, 18 x 40 = 720), so any shake would expose
	# bare ground at the edges. The margin tiles are painted COL_WATER DIRECTLY rather than through
	# `terrain_colour_of_char`: that lookup takes a legend character and there is no legend outside
	# the grid, so inventing one would put the island legend in two places.
	var margin := Look.WATER_MARGIN_TILES
	for ty in range(-margin, Look.GRID_H + margin):
		for tx in range(-margin, Look.GRID_W + margin):
			var fill := Look.COL_WATER
			if ty >= 0 and ty < rows.size() and tx >= 0:
				var row: String = rows[ty]
				if tx < row.length():
					fill = Look.terrain_colour_of_char(row[tx])
			_paint_tile(
				Look.tile_rect_px(tx, ty),
				fill,
				Look.COL_GRID_LINE,
				Look.GRID_LINE_WIDTH_PX)

	# --- 2. docks ------------------------------------------------------------------------------
	# The tile under a dock is already dock-coloured by the terrain pass, so the marker is an
	# outline rather than a fill: it has to still say "a boat may be sent here" with a soldier
	# standing on it. It is drawn in the boat's colour on purpose — look.gd keeps the berth icon and
	# the boat the same tone so the thing missing from the harbour is recognisable at sea.
	for d in battle.dock_count():
		var dock := battle.dock_tile(d)
		if dock < 0:
			continue
		var at := _tile_xy(dock)
		_paint_dock(Look.tile_rect_px(at.x, at.y), Look.COL_BOAT, Look.BODY_OUTLINE_WIDTH_PX)

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
		if ground_kind != FxKind.AREA and ground_kind != FxKind.LAND:
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
		else:
			var land_col := Look.COL_LAND_RING
			land_col.a = land_col.a * (1.0 - ground_at)
			_paint_ring(
				ground["at"],
				Look.LAND_RING_R_PX * ground_at,
				land_col,
				Look.LAND_RING_WIDTH_PX)

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

	# --- 6. boats ---------------------------------------------------------------------------------
	# A soldier in TRANSIT sits at its boat's position, so drawing both would stack a body on the
	# hull. The boat IS the cargo on screen; the roster count is the HUD's job.
	for raw_boat in battle.boats:
		var boat: Dictionary = raw_boat
		_paint_boat(_boat_rect(boat["pos"]), Look.COL_BOAT)

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


## 1 call. An outline, not a fill — see the dock comment in `_draw`.
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


## 1 call.
func _paint_boat(rect: Rect2, colour: Color) -> void:
	draw_rect(rect, colour)


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

func _tile_xy(tile: int) -> Vector2i:
	var w := battle.grid.w
	return Vector2i(tile % w, tile / w)


func _boat_rect(pos: Vector2) -> Rect2:
	var span := Vector2(Look.BOAT_W_PX, Look.BOAT_H_PX)
	return Rect2(Look.tile_point_px(pos) - span * 0.5, span)


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
