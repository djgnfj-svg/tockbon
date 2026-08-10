extends RefCounted
## Circle table -> coordinates. **The single source that drawing and clicking share.**
##  Compute the coordinates in two places and it becomes "the click goes to the wrong layer",
##  and **no error is raised.**
##
## == **There are three axes, and the axes do not call each other** ==============
## ```
##         circle axis            rune axis           layer axis
## coords  frame()                rune_slots()        layer_bands() · layer_slots()
## draw    _draw_frame()          _draw_rune_slot()   _draw_ring()      <- circle_window
## ```
## **The day runes become two, what opens is the two rune columns only, and the layer and circle code stays shut.**
##  Written as one lump, the assembly window gets rebuilt wholesale — that one thing is what the design's
##  "Boundary" asked of this stage.
##
## **One exception, taken deliberately** (`onboarding-and-palette-tabs.md`, "한 칸씩 바깥으로"):
##  `layer_bands()`'s `PIC_ROUND` branch reads `rune_radius()` to find where the ring zone starts, because
##  growing the rune with no offset on the layer side leaves the rings sitting on top of it. **Read-only and
##  one-directional** — the rune axis still never reads the layer axis back, so a layer's own size cannot
##  move the rune. The table above still holds for `PIC_TRIANGLE`, which never takes this branch.
##
## **The three sharing one `_center` and `_radius` is not mixing the axes.** It is the opposite —
##  have each find its own center and **the center lives in three places**, and the day the window size changes
##  the three drift apart.
##  Axis separation is separating "who decides what", not "do not share the same disc".
## ==================================================================
##
## **Layer count and rune slot count all come from the `circle_defs` table.** Pin 2 and 1 here and you get
##  "the model has 3 layers but the third ring is not drawn", and that is **worse** than the layer count not
##  following (the sim growing while the screen does not = the way v1 died). `net_circle` measures it as text.
##
## Every dimension ratio is in `fx_tuning` — no numbers are written here.

const CircleDefs := preload("res://src/sim/circle_defs.gd")
const Fx := preload("res://src/view/fx_tuning.gd")


## Where the magic circle sits inside a given box. **Relative to the box origin.**
##
## **The magic circle does not know where it sits.** The window moves the coordinate system
##  (`circle_window`'s `draw_set_transform`) and this side takes **size only** —
##  pass the page rectangle and **the circle axis hangs off the window axis.**
## That is why the argument is a `Vector2` and not a `Rect2`. The moment it knows its seat, this file opens
##  every time the window shape changes (the same spirit as section 2's "the axes do not call each other").
## **Both drawing and clicking pass through this function** (stage 4b).
static func circle_area(box: Vector2) -> Rect2:
	var pad := Fx.CIRCLE_AREA_PAD_PX
	return Rect2(pad, pad, maxf(box.x - pad * 2.0, 0.0), maxf(box.y - pad * 2.0, 0.0))


# --- circle axis --------------------------------------------------

## The circle's frame. Even with no circle **the seat exists** — that is what "an empty slot" is.
static func frame(area: Rect2) -> Dictionary:
	return {"center": _center(area), "radius": _radius(area)}


## Was the circle slot clicked. **The whole inside of the frame is the circle's seat** — it is what is left
## after the layer and rune seats, and the caller decides that priority (it looks at the inner ones first).
## **It is true even with no circle — but only inside this function.**
##  That is what lets a user who removed the circle put one back, but **if the caller blocks in front of it
##  they stay trapped and nobody barks.** This is not a "structural guarantee" — this being true and
##  **actually being able to click and place** are different things.
##  => Whether it actually gets placed is known only when **verify-run clicks it** (a net cannot call
##  `Control` methods).
static func frame_has_point(area: Rect2, p: Vector2) -> bool:
	return p.distance_to(_center(area)) <= _radius(area)


# --- rune axis ----------------------------------------------------

## Centers of the rune seats. Length = `circle_defs.rune_slots`.
##
## **Branches on `circle_defs.picture`, not on the slot count** — the count alone cannot tell fusion's two
##  interlocked seats from a parallel circle's two seats sitting apart (`circle_defs.picture`'s own comment).
##
## **The bark moved here, not disappeared** (`triangle-circle-to-game.md` step 4). Before the triangle
##  existed, this barked on `rune_slots != 1` — the free stderr catch for "a circle grew past one rune seat
##  without anyone deciding how it lays out". Now that layout is decided by `picture`, the thing that
##  genuinely cannot be derived is a **picture id neither branch recognizes** — an arrangement nobody wrote
##  down — so that is where the same catch lives now. `PIC_TRIANGLE`'s three seats are decided
##  (`_socket_centers`) and `PIC_ROUND`'s one seat is decided (dead center); only an unrecognized picture
##  is undecided.
## Having 0 seats (no circle) is **normal**, so it does not bark.
static func rune_slots(circle_id: int, area: Rect2) -> PackedVector2Array:
	var n := CircleDefs.rune_slots(circle_id)
	var out := PackedVector2Array()
	if n <= 0:
		return out
	var pic := CircleDefs.picture(circle_id)
	if pic == CircleDefs.PIC_TRIANGLE:
		# Three seats scattered around the frame, not one shared center — clockwise order (seat 0 at
		#  12 o'clock) is what carries "which one goes first" now that there is no ring to nest inside.
		return _socket_centers(area, n)
	if pic == CircleDefs.PIC_ROUND:
		# The rune is dead center. **That is why the layer rings grow outward wrapping around the rune**, and
		#  "inner comes first" goes into the picture itself.
		out.append(_center(area))
		return out
	push_error("CircleLayout: unknown picture %d - no rune layout" % pic)
	return out


## Radius of the rune seat's drawing. **`PIC_TRIANGLE`'s rune seat is `socket_r - band`, not
##  `CIRCLE_RUNE_RATIO`** — the rune sits inside the socket, under the band the layer occupies
##  (`layer_bands`' hit-shape comment has the full picture). Argument order matches every other
##  picture-aware function in this file (`circle_id` first) — `area` first here alone would be the one
##  function called backward from its neighbors, and that goes wrong silently at the call site.
##
## **Falls to the `PIC_ROUND` formula for any picture that is not `PIC_TRIANGLE`, silently.** Unlike
## `rune_slots()` above, this does not bark on an unrecognized picture — only `rune_slots()` carries that
## catch. A third picture that is neither would draw with the round circle's ratio and nobody would know
## from this function alone (`layer_bands()` and `rune_slot_at()` below share the same silent fallback).
static func rune_radius(circle_id: int, area: Rect2) -> float:
	if CircleDefs.picture(circle_id) == CircleDefs.PIC_TRIANGLE:
		return _radius(area) * float(Fx.TRI_SOCKET_R - Fx.TRI_BAND) / float(Fx.TRI_CANVAS_R)
	return _radius(area) * Fx.CIRCLE_RUNE_RATIO


# --- layer axis ---------------------------------------------------

## One band per layer. Length = `circle_defs.layers`. The inner one (layer 1) comes first.
##
## ```
##  center  the point `edges` are stroked around (frame center for PIC_ROUND, the socket center for
##          PIC_TRIANGLE — concentric rings share one center, socket bands do not)
##  edges   radii to stroke, **outer edge first**. concentric: [outer]   socket: [outer, inner]
##          (concentric layers tile the radius — layer k's inner edge *is* layer k-1's outer edge,
##          so stroking outer edges only still draws the whole picture. A socket band is a standalone
##          annulus and owns both of its edges.)
##  seat    where the glyph symbol/texture anchors. For PIC_ROUND this is **not** `center` — the glyph
##          sits at 12 o'clock on the ring, not at the ring's own center. For PIC_TRIANGLE it **is**
##          the socket center, because the socket glyph texture is the band itself
##  hit     (inner, outer) radii of the clickable region, **measured from `seat`** — for PIC_ROUND
##          `seat` and the hit anchor are the same point (one seat per ring), so this reduces to the
##          disc `layer_at` has always used. For PIC_TRIANGLE `seat` is the socket center, which is
##          also where the rune's own hit disc sits (`rune_radius`) — `hit`'s nonzero inner edge is
##          what keeps the layer's outer band from swallowing the rune sitting inside it
## ```
##
## **Written from `seat`, where `triangle-circle-to-game.md`'s step 2 plan says "measured from `center`"
##  — a deliberate deviation, not an oversight, agreed on with spec.** The plan's own wording did not account
##  for `PIC_ROUND`'s `center` and `seat` being *different points* (the disc `layer_at` draws its hit test
##  around has always been the ring's 12-o'clock seat, never the frame's shared center) — reading literally
##  from `center` there would turn the round circle's layer hit test from a small disc into a full-circumference
##  annulus at the ring's own radius, a real behavior change `net_circle:709-720`'s pinned geometry (left
##  untouched on purpose, see that check's own header) would have caught as a regression. `PIC_TRIANGLE`
##  has `seat == center` for every band, so nothing about its behavior differs either way. **If you are
##  tempted to "fix" this back to `center` to match the plan literally, run that net's inversion first.**
##
## **Derived by dividing by the layer count** (PIC_ROUND). Pin two constants and the day a 3-layer circle
##  arrives the rings overlap, and an overlapping picture makes "is it two layers or three" uncountable on screen.
##
## **Falls to the concentric formula for any picture that is not `PIC_TRIANGLE`, silently** — the same
## unguarded fallback `rune_radius()` and `rune_slot_at()` carry, and for the same reason: only `rune_slots()`
## owns the "unrecognized picture" bark.
##
## **Invariant, not checked here**: for `PIC_TRIANGLE`, `n` here comes from `CircleDefs.layers(id)`, while
## `rune_slots()` above passes `_socket_centers` the count from `CircleDefs.rune_slots(id)` — a different
## column. The two only agree today because the triangle row's `layers` and `rune_slots` columns are both 3
## (`circle_defs.gd`'s own comment on that row). If a future triangle-picture row ever gave those two columns
## different values, this function would build a different number of bands than `rune_slots()` builds seats,
## and `_socket_centers`'s own `TRI_SOCKET_DEG[i]` index would run past its 3-entry array for whichever side
## asked for more — an index error, not a silent drift, but only once someone actually mismatches the columns.
static func layer_bands(circle_id: int, area: Rect2) -> Array[Dictionary]:
	var n := CircleDefs.layers(circle_id)
	var out: Array[Dictionary] = []
	if n <= 0:
		return out
	if CircleDefs.picture(circle_id) == CircleDefs.PIC_TRIANGLE:
		var centers := _socket_centers(area, n)
		var outer := _radius(area) * float(Fx.TRI_SOCKET_R) / float(Fx.TRI_CANVAS_R)
		var inner := _radius(area) * float(Fx.TRI_SOCKET_R - Fx.TRI_BAND) / float(Fx.TRI_CANVAS_R)
		for i in n:
			out.append({
				"center": centers[i],
				"edges": PackedFloat32Array([outer, inner]),
				"seat": centers[i],
				"hit": Vector2(inner, outer),
			})
		return out
	# **"한 칸씩 바깥으로" is one derived rule, not two tuned numbers** (`onboarding-and-palette-tabs.md`
	#  Stage 5). The round rune sits dead center, so "move the rune outward" has no direction — what actually
	#  needs to move is where the ring zone *starts*. `hole` pushes that start to just outside the rune's own
	#  drawn edge (`CIRCLE_RING_GAP_FRAC` is the "one칸" gap), and both layers scale into the remaining band
	#  out to `zone`. Grow the rune (`CIRCLE_RUNE_RATIO`) and every layer seat follows on its own — there is
	#  no second offset to keep in step, which is the whole point of writing it this way.
	var zone := _radius(area) * Fx.CIRCLE_RING_ZONE
	var hole := rune_radius(circle_id, area) + _radius(area) * Fx.CIRCLE_RING_GAP_FRAC
	var c := _center(area)
	for i in n:
		var outer := hole + (zone - hole) * float(i + 1) / float(n)
		out.append({
			"center": c,
			"edges": PackedFloat32Array([outer]),
			# The 12 o'clock direction. Scatter the angle per layer and "which ring's glyph is this" stops reading.
			"seat": c + Vector2(0.0, -outer),
			"hit": Vector2(0.0, glyph_radius(area) * Fx.SLOT_HIT_RATIO),
		})
	return out


## The points the glyphs sit on. **Drawing and clicking both use this one function** (stage 4's hit test).
## It calls `layer_bands` because it is the same axis — find the seat again here and that is a second copy.
static func layer_slots(circle_id: int, area: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for b: Dictionary in layer_bands(circle_id, area):
		out.append(b["seat"])
	return out


## Radius of the glyph symbol.
static func glyph_radius(area: Rect2) -> float:
	return _radius(area) * Fx.CIRCLE_GLYPH_RATIO


## **Which layer was clicked.** -1 if none.
##  **It reads `seat`/`hit` from `layer_bands()` — the same function the drawing reads.** Find the
##   coordinates again here and it becomes "the click goes to the wrong layer", and **no error is raised** (risk 6).
## The argument `p` is **relative to the box origin** — the caller must **subtract** however much the window
##  moved with `draw_set_transform` (risk 22). Not subtracting drifts silently.
## **No picture branch** — `hit.x` (the inner radius) is 0 for every `PIC_ROUND` band, which turns the annulus
##  test into exactly the disc test this function has always run. `PIC_TRIANGLE`'s nonzero inner radius is what
##  keeps the band from also claiming the rune's own disc sitting inside it (`rune_slot_at` below).
static func layer_at(circle_id: int, area: Rect2, p: Vector2) -> int:
	var bands := layer_bands(circle_id, area)
	for i in bands.size():
		var seat: Vector2 = bands[i]["seat"]
		var hit: Vector2 = bands[i]["hit"]
		var d := p.distance_to(seat)
		if d >= hit.x and d <= hit.y:
			return i
	return -1


## Which rune seat was clicked. -1 if none. The same discipline as above — a disc, not an annulus, since
##  a rune has no inner hole to protect the way a socket's layer band does.
##
## **Also falls to the `PIC_ROUND` formula for any picture that is not `PIC_TRIANGLE`, silently** — the
## `!=` above means "not triangle", not "is round". `circle_window._draw_rune_slot` calls `rune_radius()`
## before `rune_slots()`, so on a genuinely unrecognized picture the wrong (round) radius is used for one
## frame before `rune_slots()`'s own bark ever fires — not a logical guarantee, just why nothing has caught
## this in practice with only two pictures to choose from.
##
## **`SLOT_HIT_RATIO` applies to `PIC_ROUND` only — it must not touch `PIC_TRIANGLE`.**
##  `1.8 * (96/512) = 0.3375 > 288/512/2 = 0.28125` (`fx_tuning.TRI_*`'s own comment): inflating the triangle's
##  rune disc by the same ratio the round circle uses swallows its socket's layer band whole and spills the
##  rune's own hit region past the socket rim. The round circle's lonely dead-center dot needed the inflation
##  so an empty layer could still be aimed at; a socket's rune sits **exactly** where `rune_radius` already
##  measures the drawn disc, so there is nothing to inflate.
static func rune_slot_at(circle_id: int, area: Rect2, p: Vector2) -> int:
	var slots := rune_slots(circle_id, area)
	var r := rune_radius(circle_id, area)
	if CircleDefs.picture(circle_id) != CircleDefs.PIC_TRIANGLE:
		r *= Fx.SLOT_HIT_RATIO
	for i in slots.size():
		if p.distance_to(slots[i]) <= r:
			return i
	return -1


## Text size of the layer number. **Derived from the radius** — pin it and the numbers freeze while the circle
## grows, and that weakens one of the two devices saying "inner comes first" (design acceptance 3).
static func layer_num_size(area: Rect2) -> int:
	return maxi(int(_radius(area) * Fx.CIRCLE_LAYER_NUM_RATIO), Fx.CIRCLE_LAYER_NUM_MIN)


# --- the disc the three share -------------------------------------
# See the comment above — sharing this is not mixing the axes, it **prevents the center living in three places.**

## The middle of the magic circle. **It belongs to none of the axes** — which is why it is public.
##  Call `frame()` to draw a layer and **the layer axis hangs off the circle axis.** The day a circle with
##   several circles (glyphs per rune) arrives, `frame()` starts returning several, and the layer code breaks with it.
static func center(area: Rect2) -> Vector2:
	return _center(area)


static func _center(area: Rect2) -> Vector2:
	return area.get_center()


static func _radius(area: Rect2) -> float:
	return minf(area.size.x, area.size.y) * 0.5 * Fx.CIRCLE_DISC_RATIO


## **The triangle picture's socket centers — read by both the rune axis (`rune_slots`) and the layer axis
##  (`layer_bands`), so neither one calls the other.** The same argument this file already makes for sharing
##  `_center`/`_radius`: separating axes means separating **who decides what**, not "do not share a value".
##
## `Fx.TRI_SOCKET_DEG` is written as degrees measured against `Fx.TRI_CANVAS_R` (512) — scale the distance by
##  the real frame radius and it lands at the same angles the asset was drawn at (`draw_circle.py:128`).
## `n` is a parameter rather than reading `Fx.TRI_SOCKET_DEG.size()` directly so a future picture with a
##  different socket count is not silently handed extra or missing seats.
static func _socket_centers(area: Rect2, n: int) -> PackedVector2Array:
	var c := _center(area)
	var dist := _radius(area) * float(Fx.TRI_SOCKET_DIST) / float(Fx.TRI_CANVAS_R)
	var out := PackedVector2Array()
	for i in n:
		var a := deg_to_rad(Fx.TRI_SOCKET_DEG[i])
		out.append(c + Vector2(cos(a), sin(a)) * dist)
	return out
