extends RefCounted
## Circle table -> coordinates. **The single source that drawing and clicking share.**
##  Compute the coordinates in two places and it becomes "the click goes to the wrong layer",
##  and **no error is raised.**
##
## == **There are three axes, and the axes do not call each other** ==============
## ```
##         circle axis            rune axis           layer axis
## coords  frame()                rune_slots()        layer_rings() · layer_slots()
## draw    _draw_frame()          _draw_rune_slot()   _draw_ring()      <- circle_window
## ```
## **The day runes become two, what opens is the two rune columns only, and the layer and circle code stays shut.**
##  Written as one lump, the assembly window gets rebuilt wholesale — that one thing is what the design's
##  "Boundary" asked of this stage.
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
## **It barks on `rune_slots != 1`.** Grow the circle without deciding how the runes lay out and it gets caught
##  **for free** by the wrapper's stderr check (the same device as `spell_sim._run_glyph`).
##  Fusion means the two seats interlock and parallel means they sit apart — **the arrangement is the circle's
##  picture**, so it cannot be decided automatically.
## Having 0 seats (no circle) is **normal**, so it does not bark.
static func rune_slots(circle_id: int, area: Rect2) -> PackedVector2Array:
	var n := CircleDefs.rune_slots(circle_id)
	var out := PackedVector2Array()
	if n <= 0:
		return out
	if n != 1:
		push_error("CircleLayout: no layout yet for a circle with %d rune slots" % n)
		return out
	# The rune is dead center. **That is why the layer rings grow outward wrapping around the rune**, and
	#  "inner comes first" goes into the picture itself.
	out.append(_center(area))
	return out


## Radius of the rune seat's drawing.
static func rune_radius(area: Rect2) -> float:
	return _radius(area) * Fx.CIRCLE_RUNE_RATIO


# --- layer axis ---------------------------------------------------

## Radii of the layer rings. Length = `circle_defs.layers`. The inner one (layer 1) comes first.
##
## **Derived by dividing by the layer count.** Pin two constants and the day a 3-layer circle arrives the rings
##  overlap, and an overlapping picture makes "is it two layers or three" uncountable on screen.
static func layer_rings(circle_id: int, area: Rect2) -> PackedFloat32Array:
	var n := CircleDefs.layers(circle_id)
	var out := PackedFloat32Array()
	if n <= 0:
		return out
	var zone := _radius(area) * Fx.CIRCLE_RING_ZONE
	for i in n:
		out.append(zone * float(i + 1) / float(n))
	return out


## The points the glyphs sit on. **Drawing and clicking both use this one function** (stage 4's hit test).
## It calls `layer_rings` because it is the same axis — find the radius again here and that is a second copy.
static func layer_slots(circle_id: int, area: Rect2) -> PackedVector2Array:
	var c := _center(area)
	var out := PackedVector2Array()
	# The 12 o'clock direction. Scatter the angle per layer and "which ring's glyph is this" stops reading.
	for r: float in layer_rings(circle_id, area):
		out.append(c + Vector2(0.0, -r))
	return out


## Radius of the glyph symbol.
static func glyph_radius(area: Rect2) -> float:
	return _radius(area) * Fx.CIRCLE_GLYPH_RATIO


## **Which layer was clicked.** -1 if none.
##  **It uses the same `layer_slots()` and `glyph_radius()` as the drawing.** Find the coordinates again here
##   and it becomes "the click goes to the wrong layer", and **no error is raised** (risk 6).
## The argument `p` is **relative to the box origin** — the caller must **subtract** however much the window
##  moved with `draw_set_transform` (risk 22). Not subtracting drifts silently.
## The clickable circle is larger than the symbol — make it symbol-sized and an empty layer has to be aimed at
##  exactly, so it cannot be clicked.
static func layer_at(circle_id: int, area: Rect2, p: Vector2) -> int:
	var slots := layer_slots(circle_id, area)
	var r := glyph_radius(area) * Fx.SLOT_HIT_RATIO
	for i in slots.size():
		if p.distance_to(slots[i]) <= r:
			return i
	return -1


## Which rune seat was clicked. -1 if none. The same discipline as above.
static func rune_slot_at(circle_id: int, area: Rect2, p: Vector2) -> int:
	var slots := rune_slots(circle_id, area)
	var r := rune_radius(area) * Fx.SLOT_HIT_RATIO
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
