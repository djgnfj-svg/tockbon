extends Control
## The magic circle assembly window — **this stage is the backing board and the title, nothing more.**
##  Concentric circles, layer rings, rune seats and the palette are **the work of stages 3 to 5. Do not build
##  them in advance.**
##
## **`mouse_filter` is this window's contract, and it is everything this stage measures.**
##
## ```
##  inside this node's rect  ->  STOP    the click does not leak into firing
##  outside it               ->  the same as this node not existing  ->  **you can shoot with the window open**
## ```
##
##  Being able to shoot from outside is the evidence for "the world does not stop" (design acceptance 4).
##   That is why **no full-screen `Control` is laid down** — the moment the screen is covered, `IGNORE` or `STOP`
##   alike, that evidence disappears or firing dies.
##  The value is written in `stage.tscn` and **is not overwritten at runtime here.** Overwrite it and the value
##   in the scene becomes a meaningless false knob, which quietly overturns it later when a modal does have to
##   block what is behind (the same comment in `stage.gd` — a v1 measurement).
##
## The window is under `HUD` (a `CanvasLayer`). As a `Node2D` **the window would shake along with the screen shake.**
##  That is why `stage_input._to_world` must not be used for click coordinates — a `CanvasLayer` does not take
##   the camera transform, so there is no transform to undo. Undo it and clicks go to the wrong place while shaking.
##
## **`focus_mode` must be NONE** (it is written in the scene). If a `Control` inside the window takes focus,
##  Tab is consumed by the GUI as `ui_focus_next` and **never reaches** `_unhandled_input` => "Tab does not work".
##  The symptom is identical to "the input map was not fixed", so diagnosis takes a long time — suspect focus first.

const Fx := preload("res://src/view/fx_tuning.gd")
const Layout := preload("res://src/view/circle_layout.gd")
## The window axis is **separate.** The window assembles the two, and `circle_layout` does not know `book_layout`.
const Book := preload("res://src/view/book_layout.gd")
## The palette is **"slot kind x item"** — write it for glyphs only and stage 5 rewrites it wholesale.
const Palette := preload("res://src/view/palette_layout.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const SpellCircle := preload("res://src/actor/spell_circle.gd")
## The value that **removes** a circle comes from here — pin `0` in the window and the reserved value lives
## in two places.
const CircleDefs := preload("res://src/sim/circle_defs.gd")

## **A reference, not a copy** — it reads **the same thing** as the muzzle (the plan's section 1 single source).
##  Pressing debug keys 4 and 5 flipping the drawing is the evidence for that, and a copy would destroy it.
## **It only reads.** At this stage **nothing can be placed by clicking** (stage 4).
var _circle: SpellCircle = null

## The palette item currently picked. `_picked_kind < 0` means nothing is picked.
## **It holds the kind too** — circles, runes and glyphs are all pickable, so an item id alone does not say which.
##  Why two integers rather than a dictionary: key typos are impossible in principle and there is no allocation.
var _picked_kind := -1
var _picked_item := -1


func setup(circle: SpellCircle) -> void:
	_circle = circle
	queue_redraw()


## There is no separate **moment** when the assembly state changes (debug keys and the assembly window both
##  touch the model directly).
##  => Redraw every frame while it is open. The same way `character_view` does it for the muzzle.
##  It does nothing while closed — the window is closed most of the time.
func _process(_dt: float) -> void:
	if visible:
		queue_redraw()


func _ready() -> void:
	# **This rectangle is the interaction area** — `mouse_filter` only bites here.
	#  `fx_tuning` is the single source for the dimensions (write offsets in the scene and there are two places).
	position = Fx.WINDOW_RECT.position
	size = Fx.WINDOW_RECT.size


## Tab. Only one door is kept so the shell does not touch `visible` directly — later, when opening and closing
##  grow more to do (focus, animation), that attaches here in one place.
func toggle() -> void:
	visible = not visible
	# Drop the pick when closing — without it, reopening looks like **nobody has picked anything** while
	#  the next slot click places the old item.
	_clear_pick()


# ══════════════════════════════════════════════════════════════════
#  Clicking — **pick then place. Press what is placed and it is removed**
#
#  **The nets cannot call the functions below.** It is a `Control` outside the tree, so neither `_gui_input`
#   nor `_draw` runs, and a net cannot stand one up either. The line is this:
#     · **static coordinate functions** (`circle_layout` · `palette_layout` · `book_layout`) -> nets measure them
#     · **`Control` methods** (`_gui_input` · `_click_*` · `_place_or_clear` · `_can_pick`) -> **not measured**
#   => **verify-run and verify-look are the only detectors.** Edit here knowing that a green net guarantees
#    nothing.
#  That is why **judgment was pushed as far as possible into the coordinate functions and the model** —
#   what is left here should be wiring only.
# ══════════════════════════════════════════════════════════════════

## **Being `_gui_input`, the coordinates are already relative to the window's inside.** Take it through
##  `_unhandled_input` and they are screen coordinates, so the window position has to be subtracted again,
##  and the moment that subtracted value lives in two places they drift.
##  And the window is `STOP`, so not taking it here means **the click goes nowhere** — it does not leak into firing.
##
## **Risk 22 — draw inside the transform and take clicks outside it and they diverge silently.**
##  Below is the answer: the `page.position` the drawing added is **subtracted here.** The value to subtract
##  comes from the same function in `book_layout`, so the two cannot diverge.
##  The repo has the same measurement — when `stage_input._to_world` fails to undo the canvas transform,
##   "aim goes to the wrong cell while shaking" (no error).
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	# A click inside the window is **not firing.** Not accepting it means magic goes off while assembling.
	accept_event()
	if _circle == null:
		return

	var pal := Book.palette_page(size)
	if pal.has_point(mb.position):
		_click_palette(pal, mb.position - pal.position)
		return
	var page := Book.circle_page(size)
	if page.has_point(mb.position):
		_click_circle(page, mb.position - page.position)


## Pick from the palette. Pressing the same one again drops the pick.
func _click_palette(pal: Rect2, local: Vector2) -> void:
	var hit := Palette.item_at(pal.size, local)
	if hit.is_empty():
		return
	var kind := int(hit["kind"])
	var item := int(hit["item"])
	# **What cannot be placed cannot be picked in the first place.** Get it picked and then have the slot
	#  refuse it and it becomes "I pressed it and nothing happened", which reads as a malfunction (design).
	if not _can_pick(kind, item):
		return
	if _picked_kind == kind and _picked_item == item:
		_clear_pick()
		return
	_picked_kind = kind
	_picked_item = item


## Press a slot. With something picked it **places**, with nothing picked it **removes** (plan section 9-1).
##
## **The three kinds follow the same rule.** Differ per kind and there are three things to learn.
## **Look from the inside out** — the circle slot is the whole inside of the frame, so without checking the
##  layer and rune seats first it eats all of them.
func _click_circle(page: Rect2, local: Vector2) -> void:
	var area := Layout.circle_area(page.size)
	var id := _circle.circle_id()

	var layer := Layout.layer_at(id, area, local)
	if layer >= 0:
		_place_or_clear(Palette.KIND_GLYPH, func(v: int) -> void:
			_circle.place_glyph(layer, v), Glyph.GLYPH_NONE)
		return

	var slot := Layout.rune_slot_at(id, area, local)
	if slot >= 0:
		_place_or_clear(Palette.KIND_RUNE, func(v: int) -> void:
			_circle.set_rune(slot, v), SpellCircle.RUNE_EMPTY)
		return

	if Layout.frame_has_point(area, local):
		_place_or_clear(Palette.KIND_CIRCLE, func(v: int) -> void:
			_circle.set_circle(v), CircleDefs.CIRCLE_NONE)


## **The rule for placing and removing lives here in one place.** Write it per kind and there are three copies,
##  and the day only one is fixed you get "glyphs come out but runes do not".
##  If what is picked is a **different kind**, nothing happens — picking a rune and placing it on a layer
##  has no meaning.
func _place_or_clear(kind: int, put: Callable, empty: int) -> void:
	if _picked_kind < 0:
		put.call(empty)
		return
	if _picked_kind != kind:
		return
	put.call(_picked_item)
	# Pick then place is one action. Once placed, the hand is emptied.
	_clear_pick()


func _clear_pick() -> void:
	_picked_kind = -1
	_picked_item = -1


## **All three pass through the same question: "is there even one slot that would take this item".**
##
## **A real defect happened here** (verify-look). This function was asking **only about glyphs**
##  and always giving `true` for circles and runes => remove the circle and there are 0 rune seats while
##  **the rune stays bright and pickable, and after picking it, pressing anywhere did nothing.**
##  That is the "it is pressable and nothing happens" the design warned about.
##
## **The cause was the rule being split per kind** — the same reason `_place_or_clear` was gathered into
##  one place. "Glyphs are blocked but runes are not" is the same disease as "glyphs come out but runes do not".
##  => What differs per kind is only **how slots are counted** and **the accepting condition**; the question is one.
func _can_pick(kind: int, item_id: int) -> bool:
	for i in _slot_count(kind):
		if _slot_accepts(kind, i, item_id):
			return true
	return false


## How many slots that kind has. **All of it comes from the model** — remove the circle and both layers and
## rune seats become 0, and then the question above falls to "there is nowhere to place it" on its own.
func _slot_count(kind: int) -> int:
	if kind == Palette.KIND_CIRCLE:
		# The circle slot is the **single** frame seat and **it exists even with no circle**
		#  (`circle_layout.frame_has_point`). That is what lets a user who removed the circle put one back —
		#  leave it at 0 and they are **trapped.**
		return 1
	if kind == Palette.KIND_RUNE:
		return _circle.rune_count()
	if kind == Palette.KIND_GLYPH:
		return _circle.layer_count()
	push_error("CircleWindow: unknown slot kind %d - treating the slot count as 0" % kind)
	return 0


## Does that slot take this item. **Only glyphs have a constraint** and that constraint comes from
## `glyph_defs.DEFS`.
##  It is **not written again here** (`can_place_glyph` is called) — write it and the rule has two copies
##   and what `net_circle`'s bidirectional agreement was measuring becomes meaningless.
## **Only empty layers count.** Overwriting layer 1 while spread is on layer 1 is allowed by the rules, but
##  allowing it looks like "spread is there and spread gets blocked". => Moving means removing first, as one rule.
func _slot_accepts(kind: int, index: int, item_id: int) -> bool:
	if kind != Palette.KIND_GLYPH:
		return true
	return _circle.glyph_at(index) == Glyph.GLYPH_NONE \
		and _circle.can_place_glyph(index, item_id)


func _draw() -> void:
	# The coordinates are **relative to the window's inside** (a `Control`'s `_draw` uses its own rect origin).
	#  Use screen coordinates and only the drawing fails to follow when the window moves.
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Fx.WINDOW_BG, true)
	draw_rect(r, Fx.WINDOW_EDGE, false, Fx.WINDOW_EDGE_PX)

	# If there is no font it **does not draw.** Passing `null` makes the engine bark every frame, and since
	#  the wrapper counts stderr as failure, the nets go red wholesale at that moment.
	var font := get_theme_default_font()
	if font == null:
		return
	draw_string(font,
		Vector2(Fx.WINDOW_PAD_PX, Fx.WINDOW_PAD_PX + float(Fx.WINDOW_TITLE_SIZE)),
		Fx.WINDOW_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1,
		Fx.WINDOW_TITLE_SIZE, Fx.WINDOW_TITLE_COLOR)

	# -- the opened book --
	# The page rectangles come from `book_layout` alone — the drawing and (stage 4b's) clicking read them together.
	#  Draw the fold separately here and **the visible boundary and the click boundary diverge** (risk 23).
	var pages := Book.pages(size)
	draw_rect(pages["left"], Fx.BOOK_PAGE, true)
	draw_rect(pages["right"], Fx.BOOK_PAGE, true)
	draw_rect(pages["fold"], Fx.BOOK_FOLD, true)
	# The left page is **deliberately empty** — the palette is stages 4b and 5.

	if _circle == null:
		return

	# **Moving the magic circle onto the right page is a coordinate-system transform.** The page position is not
	#  added to the magic circle's coordinates — add it and `circle_layout` learns where it sits, and the day
	#  the window shape changes the magic circle's code opens with it (section 3.7).
	#  **The price is that stage 4b must undo this transform to take clicks** (risk 22).
	#   The value to subtract is `pages()["right"].position` — **the same value used here.**
	# **Which page is the magic circle is decided by `book_layout`.** Pin the key here and the day left and right
	#  flip, the window and the nets flip separately and it stays **green with only one side moved**
	#  (section 3.7 — it has already flipped once).
	var page := Book.circle_page(size)
	draw_set_transform(page.position)

	# **Every coordinate comes from `circle_layout`.** Compute even one here and stage 4b's hit test uses
	#  different coordinates, and that goes to the wrong layer with no error.
	var area := Layout.circle_area(page.size)
	var id := _circle.circle_id()
	_draw_frame(area)
	_draw_rune_slot(area, id)
	# **The layer count here comes from the model (`layer_count()`) while the ring radii inside `_draw_ring`
	#  come from the table (`layer_rings()`) — there are two sources.** Today both derive from `circle_defs`
	#  and give the same number, but the day they drift, `_draw_ring`'s `layer >= rings.size()` guard
	#  **draws less without barking** (if the model has more) or **loops less** (if the table has more).
	#  On screen it only reads as "one layer is missing". If they are to be merged, merge toward **the table** —
	#   the drawing must get its seats from the table, and the model only knows what is placed on those seats.
	for i in _circle.layer_count():
		_draw_ring(area, id, i, font)

	# **It must be restored.** Without restoring, everything drawn afterwards is shifted by the page —
	#  and the palette below is exactly that "everything drawn afterwards".
	draw_set_transform(Vector2.ZERO)

	# The palette also draws **inside its own page**, relative to its origin. The same discipline as the magic circle.
	var pal := Book.palette_page(size)
	draw_set_transform(pal.position)
	_draw_palette(pal, font)
	draw_set_transform(Vector2.ZERO)


# ══════════════════════════════════════════════════════════════════
#  **The three axes — they do not call each other**
#   The day runes become two, the only thing that opens is `_draw_rune_slot`.
# ══════════════════════════════════════════════════════════════════

## Circle axis — the vessel's rim. Even with no circle **the seat is drawn.** That is what "an empty slot" is,
##  and it is why the magic circle visibly shrinking to a single slot is seen when the circle is removed (stage 5).
func _draw_frame(area: Rect2) -> void:
	var f := Layout.frame(area)
	# **It uses the same function as the palette's circle.** Draw it separately here and the day the circle's
	#  frame changes, **only the palette's circle fails to follow** — runes and glyphs already shared functions
	#  and only the circle did not.
	_draw_circle_symbol(f["center"], f["radius"])


## Rune axis — the rune seats. Both the **number** of seats and their **positions** come from the circle table.
## An empty rune is **the same grey** as a dead staff tip — same meaning, so the same color is what connects
##  the two screens at a glance.
##  Writing out "why can it not fire" in text is stage 5. This stage goes as far as **drawing the state honestly.**
##
## **The bark raised here is "every frame", not "once per event".**
##  `Layout.rune_slots()` barks on `rune_slots != 1` and this function is called **60 times a second** while
##  the window is open => the day a 2-rune-seat circle arrives, the log is buried at 60 lines a second and the
##  wrapper's stderr check gets just as noisy.
##  **It does not bite today** (there is 1 rune seat). Whoever grows the runes must move the bark out of the
##   frame **then** — `spell_sim._run_glyph`'s bark is once per impact, an entirely different cost.
##   The same goes for `_draw_glyph` below.
func _draw_rune_slot(area: Rect2, circle_id: int) -> void:
	var r := Layout.rune_radius(area)
	var slots := Layout.rune_slots(circle_id, area)
	for i in slots.size():
		var rune_id := _circle.rune_at(i)
		if rune_id == SpellCircle.RUNE_EMPTY:
			# **This is the third device saying "it cannot fire"** (section 3.5 — the staff tip and the HUD
			#  already stood up in stage 1).
			#  An empty rune seat is a **warning**, not an invitation saying "you may place here" —
			#   it **means something different from a layer's empty seat (`+`), so it is drawn differently.**
			#   It is **the same grey** as a dead staff tip so the two screens say the same thing.
			#   The constant names were `MUZZLE_DEAD` and `MUZZLE_DEAD_WIDTH_PX` — they became
			#    `DEAD_TINT` and `DEAD_RING_PX` when the muzzle bead disappeared. **Value and meaning are unchanged.**
			draw_circle(slots[i], r, Fx.DEAD_TINT, false, Fx.DEAD_RING_PX)
			continue
		_draw_rune_symbol(slots[i], r, rune_id)


## Layer axis — one ring, the layer number, and the glyph placed on it.
##
## **Two devices hang on "inner comes first"** (design acceptance 3):
##   (1) **The layer number** 1 and 2 written beside the ring
##   (2) **A brightness difference** — bright inside, darker outward. It divides by the layer count, so a
##     3-layer circle is automatic
##  A concentric circle alone says only that an order **exists**, never **which side comes first.**
func _draw_ring(area: Rect2, circle_id: int, layer: int, font: Font) -> void:
	var rings := Layout.layer_rings(circle_id, area)
	if layer < 0 or layer >= rings.size():
		return
	var n := rings.size()
	# With only 1 layer there is nothing to divide — dividing by 0 makes the drawing disappear wholesale.
	var t := 0.0 if n <= 1 else float(layer) / float(n - 1)
	# **`frame()` is not called.** The center is a shared value belonging to no axis, and calling the circle
	#  axis here hangs the layer axis off it (the `circle_layout.center` comment).
	var c := Layout.center(area)
	draw_circle(c, rings[layer], Fx.CIRCLE_RING_INNER.lerp(Fx.CIRCLE_RING_OUTER, t),
		false, Fx.CIRCLE_RING_PX)

	if font != null:
		# The 9 o'clock direction. The glyph symbol sits at 12 o'clock, so writing it there overlaps.
		# Both the text size and the offset distance **derive from the radius** — grow only the size and keep
		# the offset in px and the text sinks into the ring as it grows.
		var num := Layout.layer_num_size(area)
		draw_string(font, c + Vector2(
				-rings[layer] + float(num) * Fx.CIRCLE_LAYER_NUM_INSET_FRAC,
				-float(num) * Fx.CIRCLE_LAYER_NUM_LIFT_FRAC),
			str(layer + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, num, Fx.CIRCLE_LAYER_NUM)

	var slots := Layout.layer_slots(circle_id, area)
	if layer >= slots.size():
		return
	var glyph_id := _circle.glyph_at(layer)
	# **Empty seats are drawn too — "you can place here" has to be in the picture.**
	#  Without drawing it, "a blocked seat" and "an empty seat" look the same, and in stage 4b-2b where to press
	#   is not on the screen (the first of the three slot states — the `fx_tuning.SLOT_EMPTY` comment).
	if glyph_id == Glyph.GLYPH_NONE:
		_draw_empty_slot(slots[layer], Layout.glyph_radius(area))
		return
	_draw_glyph(slots[layer], Layout.glyph_radius(area), glyph_id)


## **Shape from `kind`, color from the glyph id.** Give each glyph its own drawing and that becomes
##  **a fourth place to fix**, and `glyph_defs.gd` itself wrote "if a fourth place appears the structure is
##  wrong, so stop".
##  => A new glyph gets its shape **for free.** The day "swap" arrives, kinds become three and shapes become three.
## And that axis is **the whole of the pipeline** (design doc), so **the drawing teaches the rule.**
func _draw_glyph(at: Vector2, r: float, glyph_id: int) -> void:
	if not Glyph.DEFS.has(glyph_id):
		push_error("CircleWindow: glyph %d is not in the table - cannot draw it" % glyph_id)
		return
	var tint: Color = Fx.GLYPH_TINT.get(glyph_id, Fx.GLYPH_TINT_MISSING)
	var kind := int(Glyph.DEFS[glyph_id]["kind"])
	if kind == Glyph.KIND_SPAWN:
		# Branches reaching outward — "it makes new bolts" is in the shape.
		for k in Fx.GLYPH_SPAWN_RAYS:
			# Rotated by half a step — without rotating, the horizontal rays lie on top of the ring line and
			#  **disappear** (the `fx_tuning.GLYPH_SPAWN_ANGLE_STEP_FRAC` comment holds the measurement).
			var a := TAU * (float(k) + Fx.GLYPH_SPAWN_ANGLE_STEP_FRAC) / float(Fx.GLYPH_SPAWN_RAYS)
			var d := Vector2(cos(a), sin(a))
			draw_line(at + d * (r * Fx.GLYPH_SPAWN_INNER_RATIO), at + d * r,
				tint, Fx.GLYPH_SYMBOL_PX)
		return
	if kind == Glyph.KIND_TERMINAL:
		# A filled disc — "it ends right there" is in the shape.
		draw_circle(at, r * Fx.GLYPH_TERMINAL_RATIO, tint, true)
		return
	# It barks on an unknown kind — grow the table's kinds without growing the drawing and it gets caught here.
	push_error("CircleWindow: glyph kind %d has no drawing" % kind)


## Rune symbol — a glowing bead. **The palette and the slot use this same function.**
##  Draw them separately and it becomes "the palette's fire looks different from the fire placed in the circle",
##  and that is quiet.
func _draw_rune_symbol(at: Vector2, r: float, rune_id: int) -> void:
	var fx := Fx.elem_fx(rune_id)
	draw_circle(at, r, fx["glow"], true)
	draw_circle(at, r * Fx.CIRCLE_RUNE_CORE_RATIO, fx["core"], true)


## Circle symbol — the vessel's rim. A circle is a **frame**, so being hollow inside is its meaning.
func _draw_circle_symbol(at: Vector2, r: float) -> void:
	draw_circle(at, r, Fx.CIRCLE_FRAME, false, Fx.CIRCLE_FRAME_PX)


## **An empty seat — "you can place here".**
##  A faint ring plus a **plus sign.** Draw only the ring and it reads as "a seat" and "you can place here"
##  does not read.
##  Fill it and it is confused with the TERMINAL disc — being empty is part of the meaning.
func _draw_empty_slot(at: Vector2, r: float) -> void:
	draw_circle(at, r, Fx.SLOT_EMPTY, false, Fx.SLOT_EMPTY_PX)
	var a := r * Fx.SLOT_PLUS_RATIO
	draw_line(at - Vector2(a, 0.0), at + Vector2(a, 0.0), Fx.SLOT_EMPTY, Fx.SLOT_PLUS_PX)
	draw_line(at - Vector2(0.0, a), at + Vector2(0.0, a), Fx.SLOT_EMPTY, Fx.SLOT_PLUS_PX)


# ══════════════════════════════════════════════════════════════════
#  Palette — **"slot kind x item".** Not glyph-only
# ══════════════════════════════════════════════════════════════════

## **This stage goes as far as drawing.** Picking and placing by click is 4b-2b.
## Every coordinate comes from `palette_layout` — the hit test must be able to call **the same functions.**
func _draw_palette(page: Rect2, font: Font) -> void:
	for ki in Palette.KINDS.size():
		var kind: int = Palette.KINDS[ki]
		var sec := Palette.section(page.size, ki)
		_draw_palette_section(sec, kind, font)
		# Items come from **iterating the table** — write them by hand and the table grows while the palette does not.
		var items := Palette.items_of(kind)
		for ii in items.size():
			var slot := Palette.item_slot(sec, ii, items.size())
			_draw_palette_item(slot, kind, items[ii])


## A section — **it makes the empty space read as "a seat for what is coming".** With only four items the page
##  is largely empty, and without a frame and a title the same screen simply reads as **unfinished.**
func _draw_palette_section(sec: Rect2, kind: int, font: Font) -> void:
	draw_rect(sec, Fx.PALETTE_SECTION_BG, true)
	draw_rect(sec, Fx.PALETTE_SECTION_EDGE, false, Fx.PALETTE_SECTION_EDGE_PX)
	if font == null:
		return
	if not Palette.KIND_DEFS.has(kind):
		push_error("CircleWindow: unknown slot kind %d - it has no title" % kind)
		return
	var nm: StringName = Palette.KIND_DEFS[kind]["name"]
	draw_string(font, sec.position + Vector2(
			Fx.PALETTE_PAD_PX, Fx.PALETTE_HEAD_PX * Fx.PALETTE_HEAD_BASELINE_FRAC),
		String(nm), HORIZONTAL_ALIGNMENT_LEFT, -1,
		Fx.PALETTE_HEAD_SIZE, Fx.PALETTE_HEAD_COLOR)


## One item. **It uses the same symbol functions as drawing into a slot** — draw them separately and it becomes
##  "the palette's blast looks different from the blast placed in the circle", and that is quiet.
func _draw_palette_item(slot: Rect2, kind: int, item_id: int) -> void:
	var at := slot.get_center()
	var r := Palette.item_symbol_radius(slot)

	if kind == Palette.KIND_CIRCLE:
		_draw_circle_symbol(at, r)
	elif kind == Palette.KIND_RUNE:
		_draw_rune_symbol(at, r, item_id)
	elif kind == Palette.KIND_GLYPH:
		_draw_glyph(at, r, item_id)
	else:
		push_error("CircleWindow: slot kind %d has no item drawing" % kind)
		return

	# **What cannot be placed is dimmed** — with spread already in place, a second spread **cannot be pressed
	#  in the first place** (design).
	#  If it is pressable and nothing happens, that reads as a malfunction. Blocking it one step earlier is the point.
	#  **`modulate` must not be used** — it applies to the whole node and lingers into the next frame.
	#   => A **veil** is laid over that cell alone.
	# All three kinds go the same way — that the constraint exists only for glyphs is what `_can_pick` knows.
	if not _can_pick(kind, item_id):
		draw_rect(slot, Color(Fx.PALETTE_SECTION_BG, Fx.PALETTE_BLOCKED_VEIL_A), true)
		return
	# An outline on what is picked. **Not presentation but half of the action** —
	#  without seeing what was picked, the first half of "pick then place" is not on screen.
	if _picked_kind == kind and _picked_item == item_id:
		draw_rect(slot, Fx.PALETTE_PICK, false, Fx.PALETTE_PICK_PX)
