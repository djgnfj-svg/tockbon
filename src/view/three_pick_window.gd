extends Control
## The three-pick window — **step 1 (choose · decline) and step 2 (the layer).**
##
## **`mouse_filter` is this window's contract, the exact copy of `circle_window.gd`'s own header:**
## ```
##  inside this node's rect  ->  STOP    the click does not leak into firing
##  outside it                ->  the same as this node not existing  ->  you can shoot with the window open
## ```
## Being able to shoot from outside is the evidence for "the world does not stop" (design acceptance 4).
## The value is written in `stage.tscn` and **is not overwritten at runtime here** — same reason, same trap:
## overwrite it and the scene's value becomes a meaningless false knob.
##
## **`Progress` is the single source of "is it open"** — this window holds no visibility latch of its own.
## `_process()` reads `_progress.is_pick_open()` every frame, the same discipline `stage._toggle_assembly()`
## already holds against `_circle_window.visible`. `stage.gd`'s `_toggle_pick()` only ever calls
## `Progress.open_pick()`/`decline()` — never this node's `visible` directly. **Step 2 adds no second window
## state** — it is still the same one `visible`/`is_pick_open()` pair; `_picked_index >= 0` alone tells step 1
## from step 2, and that only ever moves inside `_gui_input`/`_process` below, never at a toggle site.
##
## **Placement from this window goes through `spell_circle.place_glyph()` and nothing else** — stated
## precisely: `spell_circle.gd`'s `_layers` has exactly **two** write sites, `place_glyph()` and
## `set_from_packed()` (the debug-preset door behind keys 1-6), and both are gated by the **same**
## `_list_ok()`. Nothing in the three-pick path reaches `set_from_packed()`, so "one door" is true for this
## feature — it is not true of `spell_circle.gd` as a whole, and this window does not claim that it is. This
## window calls `place_glyph()` directly on a layer click; `Progress.take()` is bookkeeping only, called
## *after* placement already succeeded — see its own comment for why it never touches a circle.
##
## The window is under `HUD` (a `CanvasLayer`), the same reason `circle_window.gd` gives for its own placement
## — as a `Node2D` it would shake along with the screen shake.

const Fx := preload("res://src/view/fx_tuning.gd")
const Layout := preload("res://src/view/pick_layout.gd")
const CircleLayout := preload("res://src/view/circle_layout.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const Progress := preload("res://src/actor/progress.gd")
const SpellCircle := preload("res://src/actor/spell_circle.gd")

var _progress: Progress = null
## **A reference, not a copy** — the same reason `circle_window._circle` is a reference (the plan's single
## source). Placement must land on the one circle the rest of the game reads, not a copy nothing else sees.
var _circle: SpellCircle = null

## Which of the currently-drawn cards is tentatively picked. `-1` = step 1 (no card picked yet); `>= 0` = step
## 2, showing that card's glyph against the circle's layers.
var _picked_index := -1

## **Set the moment a layer click is rejected, cleared the moment anything else happens.** A rejected
## placement must be visible, not silent (Stage D's own screen lesson, one level up — see `Fx.PICK_REJECT_
## TEXT`'s own comment). Not persisted anywhere `Progress` can see — it is this window's own transient "the
## last thing I tried didn't work", the same kind of state `_picked_index` already is.
var _reject := false
## Which layer the rejected click landed on — `-1` = none. Read by `_draw_step2` to put the reject message
## **by the slot that was actually pressed** instead of a fixed panel corner (verify-look's own finding: the
## message read correctly but sat ~200px from the click).
var _reject_layer := -1

## **Confirmation — a short, screen-only afterglow after a successful placement, not new sim state.**
## `take()` runs immediately the moment a placement succeeds (`_gui_input_step2`'s own comment) — deferring
## it to wait for a dismiss would open a window where the glyph is already on the circle but the pick is not
## yet spent, and an interruption there (`Tab`, a stage reset) would grant a free placement. So the pick
## genuinely closes at once; only this window's own `visible` lingers a few frames past that, purely so the
## placement reads as a placement instead of the window vanishing on the very click that caused it
## (verify-look's own finding: the only confirmation today is the shell's debug HUD line, which "will not
## survive into the real game").
## **Ticked once per `tick_confirm()` call** (`stage._physics_process`, Godot's default 60Hz — unset in
## `project.godot`) — ~0.7s. A screen-only clock, not the sim's; `tick_confirm()`'s own header says why it
## no longer lives in this window's `_process()`.
const CONFIRM_FRAMES := 40
var _confirm_glyph := Glyph.GLYPH_NONE  # GLYPH_NONE = no confirmation to show
var _confirm_layer := -1
var _confirm_ticks := 0


func setup(progress: Progress, circle: SpellCircle) -> void:
	_progress = progress
	_circle = circle


func _ready() -> void:
	position = Fx.PICK_RECT.position
	size = Fx.PICK_RECT.size


## **Redraw every frame while open** — the same idiom `circle_window._process` already holds (there is no
## single "the state changed" moment; `Progress` can change under this window at any time, e.g. `decline()`
## called from `stage._toggle_assembly()` when the player presses Tab instead of this window's own button).
func _process(_dt: float) -> void:
	var pick_open := _progress != null and _progress.is_pick_open()
	# **Reset the moment it is not open** — not only on the transition. A stale `_picked_index` surviving a
	# `decline()` would show the wrong card highlighted the next time a pick opens.
	if not pick_open:
		_picked_index = -1
		_reject = false
		_reject_layer = -1
	# **A fresh pick pre-empts a lingering confirmation** — whichever thing is about to claim the screen
	#  wins; the same reason `cancel_confirm()` exists for the Tab/assembly-window path, one level up.
	#  **The countdown itself is not ticked here** — see `tick_confirm()`'s own header for why.
	if pick_open and _confirm_ticks > 0:
		_confirm_ticks = 0
		_confirm_glyph = Glyph.GLYPH_NONE
		_confirm_layer = -1
	visible = pick_open or _confirm_ticks > 0
	if visible:
		queue_redraw()


## **Ticks the confirmation countdown down by one — called from `stage._physics_process()`, immediately
## before `_update_hud()`, not from this window's own `_process()`.** The countdown used to live inside
## `_process()`, which runs on the idle clock; `stage._update_hud()` (the only reader of `is_showing()`) runs
## on the physics clock. Those are different clocks in Godot, so there was exactly one **render** frame at
## expiry where the countdown had already reached zero (this window already invisible) but `_update_hud()`
## had not yet run again to notice — `Stats` stayed hidden over nothing for that one frame. Both operations
## now happen in the same synchronous call chain (`stage.gd`'s own `_physics_process`), so there is no gap
## between "the countdown reached zero" and "the HUD found out" for either clock to open.
func tick_confirm() -> void:
	if _confirm_ticks <= 0:
		return
	_confirm_ticks -= 1
	if _confirm_ticks <= 0:
		_confirm_glyph = Glyph.GLYPH_NONE
		_confirm_layer = -1


## **The single source `stage._update_hud()` reads for `HUD/Stats`'s own visibility.** `Progress.is_pick_
## open()` alone stopped being enough the moment the confirmation afterglow could keep this window on screen
## a few frames after the pick itself already closed — the same "one expression, not a toggle site"
## discipline `stage.gd`'s own comment above `_toggle_assembly` already holds, widened here rather than
## duplicated at a second call site.
##
## **Computed fresh, not read off the cached `visible` property.** `visible` is only ever written inside
## `_process()` (idle-rate, a different clock from `stage._physics_process` -> `_update_hud()`), so reading
## it here would make `_hud.visible` **one frame late** relative to a click that just happened in the same
## frame — exactly the ordering trap `_wired_stage_root`'s own tests already guard against for `_process()`
## itself (`_sync_pick_window`'s existence is the proof this codebase already knows better). Re-deriving the
## same two terms `_process()` uses keeps this real-time, the same reliability class `Progress.is_pick_open()`
## always had on its own.
func is_showing() -> bool:
	return (_progress != null and _progress.is_pick_open()) or _confirm_ticks > 0


## **Called by `stage._toggle_assembly()` before it opens the assembly window.** Without this, pressing Tab
## during the confirmation afterglow would show both windows at once — the exact class of bug
## `net_render._opening_one_window_closes_the_other` exists to prevent — because the afterglow does not
## derive from `Progress` at all, and nothing else would ever clear it once the pick itself has closed.
func cancel_confirm() -> void:
	_confirm_ticks = 0
	_confirm_glyph = Glyph.GLYPH_NONE
	_confirm_layer = -1


## **Being `_gui_input`, coordinates are already window-local** — the same reason `circle_window._gui_input`
## takes clicks this way rather than through `_unhandled_input` (risk 22's answer, one level up: draw and
## click must read the *same* rects, and `Layout.cards()`/`card_at()` already share that by construction).
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	# A click inside the window is **not firing** — not accepting it lets magic go off while picking.
	accept_event()
	if _progress == null:
		return
	# **A click during the confirmation afterglow dismisses it early** — the timer (`CONFIRM_FRAMES`) is the
	#  floor, not a wait the player is forced to sit through.
	if _confirm_ticks > 0:
		cancel_confirm()
		return
	# **A fresh click clears any stale rejection message first** — every branch below either produces a new
	#  `_reject` state or leaves this cleared; there is no path that leaves an old message on screen describing
	#  a click that already happened. Measured: a click that does nothing (the dice button, inert by design)
	#  used to leave a stale reject message on screen — this line is what a net now drives directly.
	_reject = false
	_reject_layer = -1

	if Layout.decline_rect(size).has_point(mb.position):
		_progress.decline()
		return
	# **The dice button is inert on purpose** — `Progress.dice_left` is 0 and nothing raises it (that field's
	#  own comment). A click here does exactly what a click outside any card does: nothing.
	if Layout.dice_rect(size).has_point(mb.position):
		return

	if _picked_index >= 0:
		_gui_input_step2(mb.position)
		return

	var count := _progress.drawn().size()
	var idx := Layout.card_at(size, count, mb.position)
	if idx < 0:
		return
	_picked_index = idx


## **Step 2 — the layer choice.** Reached only while `_picked_index >= 0` (a card is picked); `_gui_input`
## above already handled decline/dice before routing here.
func _gui_input_step2(p: Vector2) -> void:
	# **The picked card, shrunk into the corner, is still clickable — press it again to go back to step 1.**
	#  The same "press what is placed and it comes back out" idiom `circle_window._click_palette` already
	#  holds for the assembly window's palette, one level up: here it is the *pick* that comes back out, not
	#  a placement.
	if Layout.picked_card_rect(size).has_point(p):
		_picked_index = -1
		return

	var rect := Layout.circle_rect(size)
	if not rect.has_point(p):
		return
	if _circle == null:
		return
	# **`circle_layout` is page-agnostic** (that file's own header) — it takes a box and a local point, and
	#  neither knows or cares that this box is the pick window's step 2 rather than the assembly window's
	#  right-hand page. The transform-and-subtract discipline is the same one `circle_window._gui_input`
	#  already holds for `risk 22` (draw inside a transform, take clicks outside it, and they diverge silently
	#  if the same subtraction is not made on both sides — here it is `rect.position`, on both).
	var area := CircleLayout.circle_area(rect.size)
	var layer := CircleLayout.layer_at(_circle.circle_id(), area, p - rect.position)
	if layer < 0:
		return

	var drawn := _progress.drawn()
	if _picked_index >= drawn.size():
		return
	var glyph_id: int = drawn[_picked_index]

	# **The one door.** `spell_circle.place_glyph()` — nothing here re-derives `max_per_circle` or any other
	#  placement rule; a `false` here is `SpellCircle`'s own decision, not this window's.
	if not _circle.place_glyph(layer, glyph_id):
		# **Visible, not silent** — `Fx.PICK_REJECT_TEXT`'s own comment names why this is the one message
		#  this window needs today (the family cap is the only reachable rejection through a real layer hit).
		#  `_reject_layer` is what lets `_draw_step2` put it by the slot that was actually pressed.
		_reject = true
		_reject_layer = layer
		return

	# **Bookkeeping only, after placement already succeeded** — `Progress.take()`'s own header.
	_progress.take(glyph_id)
	_confirm_glyph = glyph_id
	_confirm_layer = layer
	_confirm_ticks = CONFIRM_FRAMES
	_picked_index = -1
	_reject = false
	_reject_layer = -1


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Fx.PICK_BG, true)
	draw_rect(r, Fx.PICK_EDGE, false, Fx.PICK_EDGE_PX)

	# If there is no font it **does not draw** — passing `null` barks every frame, and the wrapper counts
	#  stderr as failure, so the nets would go red wholesale (the same reason `circle_window._draw` checks this).
	var font := get_theme_default_font()
	if font == null:
		return

	# **Confirmation takes priority over everything else** — it is the only state that can still be `visible`
	#  after `_progress.is_pick_open()` has already gone false (`is_showing()`'s own comment).
	#  **The title is drawn inside each branch, not once here** — verify-look's own finding: the shared title
	#  ("세 장 중 하나" — "one of three") kept reading during confirmation, when choosing was already over and
	#  nothing was left to pick from. Every branch below states its own truth instead.
	if _confirm_ticks > 0:
		_draw_confirm(font)
		return

	draw_string(font,
		Vector2(Fx.PICK_PAD_PX, Fx.PICK_PAD_PX + float(Fx.PICK_TITLE_SIZE)),
		Fx.PICK_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.PICK_TITLE_SIZE, Fx.PICK_TITLE_COLOR)

	if _progress == null:
		_draw_buttons(font)
		return

	if _picked_index >= 0:
		_draw_step2(font)
		_draw_buttons(font)
		return

	var drawn := _progress.drawn()
	var rects := _card_rects()
	for i in drawn.size():
		_draw_card(rects[i], drawn[i], font)

	_draw_buttons(font)


## **The confirmation screen — real, in-window feedback that a placement happened**, replacing "the window
## just vanishes" (verify-look's own finding: the only prior confirmation was the shell debug HUD, which
## "will not survive into the real game"). No buttons — there is nothing left to decline or place; a click
## anywhere dismisses it early (`_gui_input`'s own top branch), and it also clears itself after
## `CONFIRM_FRAMES`.
func _draw_confirm(font: Font) -> void:
	draw_string(font,
		Vector2(Fx.PICK_PAD_PX, Fx.PICK_PAD_PX + float(Fx.PICK_TITLE_SIZE)),
		Fx.PICK_CONFIRM_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.PICK_TITLE_SIZE, Fx.PICK_TITLE_COLOR)

	# **The circle itself, now showing the actual result — not an empty panel.** verify-look's own finding:
	#  the prior version emptied the window down to one sentence, and asked directly whether that read as
	#  confirmation or as the window failing to close, the answer was "failing to close." Reusing `_draw_pick_
	#  circle`/`_draw_pick_glyph_shape` (already built for step 2) means the player sees the placement land —
	#  the layer's own ring, its number, and the glyph now actually sitting there, at full brightness, no
	#  incoming/outgoing pair to draw since there is nothing pending anymore.
	var rect := Layout.circle_rect(size)
	draw_rect(rect, Fx.PICK_CARD_BG, true)
	draw_rect(rect, Fx.PICK_EDGE, false, Fx.PICK_CARD_EDGE_PX)
	if _circle != null:
		var area := CircleLayout.circle_area(rect.size)
		var circle_id := _circle.circle_id()
		_draw_pick_circle(rect, area, circle_id, font)
		var slots := CircleLayout.layer_slots(circle_id, area)
		var r := CircleLayout.glyph_radius(area)
		for layer in slots.size():
			var g := _circle.glyph_at(layer)
			if g != Glyph.GLYPH_NONE:
				_draw_pick_glyph_shape(rect.position + slots[layer], r, g, 1.0)

	# **Under the circle** (verify-look's own suggested placement, one level up) — naming what just happened
	#  in the same terms the reject message and every card already use: name and layer, not a symbol alone.
	if Glyph.DEFS.has(_confirm_glyph):
		var glyph_name: StringName = Glyph.DEFS[_confirm_glyph]["name"]
		var text := "%s을(를) %d층에 장착했다" % [String(glyph_name), _confirm_layer + 1]
		draw_string(font, Vector2(Fx.PICK_PAD_PX, size.y - Fx.PICK_PAD_PX * 0.5),
			text, HORIZONTAL_ALIGNMENT_LEFT, size.x - Fx.PICK_PAD_PX * 2.0, Fx.PICK_NAME_SIZE, Fx.PICK_TITLE_COLOR)


## **Step 2 — the picked card shrinks into the corner, the circle takes the rest.** `_picked_index`'s own
## comment: this only runs while a card is picked, and it is the *only* place the picked card still draws
## (step 1's loop above draws every card `_picked_index` did not hide, but once one is picked, step 1's own
## loop is not reached at all — replaced wholesale by this function, not merely filtered down to one card).
func _draw_step2(font: Font) -> void:
	var drawn := _progress.drawn()
	if _picked_index >= drawn.size():
		return
	var glyph_id: int = drawn[_picked_index]
	_draw_card(Layout.picked_card_rect(size), glyph_id, font)

	var rect := Layout.circle_rect(size)
	draw_rect(rect, Fx.PICK_CARD_BG, true)
	draw_rect(rect, Fx.PICK_EDGE, false, Fx.PICK_CARD_EDGE_PX)
	if _circle == null:
		return

	var area := CircleLayout.circle_area(rect.size)
	var circle_id := _circle.circle_id()
	# **The circle itself — item 1's own fix.** Step 2 used to draw only the glyph shapes sitting on the
	#  circle and never the circle (verify-look measured it: two 14px dots in an otherwise empty 608x286
	#  box, nothing saying "this is your magic circle" or which dot is layer 1 vs layer 2 — and layer *order*
	#  is this game's whole point). Redrawn from the same geometry `circle_window._draw_ring` reads
	#  (`CircleLayout`), not shared — the per-node `CanvasItem.draw_*` reason every redrawn shape in this
	#  file already gives.
	_draw_pick_circle(rect, area, circle_id, font)

	var slots := CircleLayout.layer_slots(circle_id, area)
	var r := CircleLayout.glyph_radius(area)
	for layer in slots.size():
		var at := rect.position + slots[layer]
		var existing := _circle.glyph_at(layer)
		# **Ask the rule before promising the picture** (item 3's own fix). A layer the family cap will
		#  refuse must not show a bright "it's going here" preview — the window would be promising a
		#  placement the very next click denies. `can_place_glyph` is read-only; asking it costs nothing.
		var can_place := _circle.can_place_glyph(layer, glyph_id)
		if existing != Glyph.GLYPH_NONE:
			if can_place:
				# **Beside the incoming glyph, smaller, dimmed — not underneath it** (item 2's own fix).
				#  Every layer sits on the same vertical ray at 12 o'clock, at increasing radius per layer
				#  (`circle_layout.layer_slots`'s own comment) — a *radial* offset could walk one layer's
				#  pushed-out glyph into the next layer's slot, so the offset is horizontal instead, where
				#  nothing else sits. Drawn dimmed *and* offset *and* smaller was tried as alpha alone first
				#  and failed for one shape pair: a dimmed `MODIFY` diamond sits entirely inside an incoming
				#  `TERMINAL` disc at the same point and radius — invisible regardless of alpha.
				_draw_pick_glyph_shape(at + Vector2(-r * Fx.PICK_PUSHOUT_OFFSET_RATIO, 0.0),
					r * Fx.PICK_PUSHOUT_SCALE, existing, Fx.PICK_PUSHOUT_DIM_ALPHA)
			else:
				# **This layer will not change** — its occupant draws plainly, not dimmed. Dimming it would
				#  falsely promise a replacement `can_place_glyph` has already refused.
				_draw_pick_glyph_shape(at, r, existing, 1.0)
		if can_place:
			_draw_pick_glyph_shape(at, r, glyph_id, 1.0)
		elif existing == Glyph.GLYPH_NONE:
			# **Blocked and empty — no `+` invite.** `circle_window._draw_empty_slot`'s plus sign means "you
			#  can place here"; this slot cannot take this glyph today, so it gets a plain dim ring instead,
			#  the same `DEAD_TINT` "cannot fire" reads elsewhere in this game.
			draw_circle(at, r, Fx.DEAD_TINT, false, Fx.RARITY_RING_PX)

	# **Near the slot that was actually pressed, not a fixed panel corner** (item 4's own fix — measured
	#  ~200px from the click). Falls back to the panel corner only if `_reject_layer` is somehow out of range
	#  (should not happen — `_gui_input_step2` sets it from the same `layer_at()` call this loop's `slots`
	#  come from).
	if _reject and font != null:
		var reject_at := rect.position
		if _reject_layer >= 0 and _reject_layer < slots.size():
			reject_at = rect.position + slots[_reject_layer] + Vector2(-r, r * 1.4)
		draw_string(font, reject_at, Fx.PICK_REJECT_TEXT, HORIZONTAL_ALIGNMENT_LEFT,
			rect.end.x - reject_at.x, Fx.PICK_EFFECT_SIZE, Fx.PICK_REJECT_COLOR)


## **The circle — rings, layer numbers, the outer frame.** See `_draw_step2`'s own comment for why this
## exists at all. `font == null` skips only the numbers, the same partial-degrade `_draw()`'s own top-level
## `font == null` guard does not need to duplicate here (rings and the frame need no font).
func _draw_pick_circle(rect: Rect2, area: Rect2, circle_id: int, font: Font) -> void:
	var frame := CircleLayout.frame(area)
	var center: Vector2 = rect.position + (frame["center"] as Vector2)
	draw_circle(center, frame["radius"], Fx.CIRCLE_FRAME, false, Fx.CIRCLE_FRAME_PX)

	var rings := CircleLayout.layer_rings(circle_id, area)
	var n := rings.size()
	for layer in n:
		var t := 0.0 if n <= 1 else float(layer) / float(n - 1)
		draw_circle(center, rings[layer], Fx.CIRCLE_RING_INNER.lerp(Fx.CIRCLE_RING_OUTER, t),
			false, Fx.CIRCLE_RING_PX)
		if font == null:
			continue
		var num := CircleLayout.layer_num_size(area)
		draw_string(font, center + Vector2(
				-rings[layer] + float(num) * Fx.CIRCLE_LAYER_NUM_INSET_FRAC,
				-float(num) * Fx.CIRCLE_LAYER_NUM_LIFT_FRAC),
			str(layer + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, num, Fx.CIRCLE_LAYER_NUM)


## **The same three shapes `circle_window._draw_glyph` draws — not called, redrawn.** `CanvasItem.draw_*`
## only runs inside the calling node's own `_draw()` (that file's own header, and `three_pick_window`'s own
## dummy-diamond precedent in `_draw_card` above), so a second node showing the same glyph shapes redraws
## them rather than sharing a function; what is shared is `Fx.GLYPH_TINT` and the shape constants, not code.
## **`alpha` scales the tint's own alpha** — the dim/full split `_draw_step2` needs, one column
## (`Fx.PICK_PUSHOUT_DIM_ALPHA`), not a second color table (the same "one column, every kind reads it in its
## own place" idiom `power_pct` already holds, one level up).
func _draw_pick_glyph_shape(at: Vector2, r: float, glyph_id: int, alpha: float) -> void:
	if not Glyph.DEFS.has(glyph_id):
		push_error("ThreePickWindow: glyph %d is not in the table - cannot draw it" % glyph_id)
		return
	var tint: Color = Fx.GLYPH_TINT.get(glyph_id, Fx.GLYPH_TINT_MISSING)
	tint.a *= alpha
	var kind := int(Glyph.DEFS[glyph_id]["kind"])
	if kind == Glyph.KIND_SPAWN:
		for k in Fx.GLYPH_SPAWN_RAYS:
			var a := TAU * (float(k) + Fx.GLYPH_SPAWN_ANGLE_STEP_FRAC) / float(Fx.GLYPH_SPAWN_RAYS)
			var d := Vector2(cos(a), sin(a))
			draw_line(at + d * (r * Fx.GLYPH_SPAWN_INNER_RATIO), at + d * r, tint, Fx.GLYPH_SYMBOL_PX)
		return
	if kind == Glyph.KIND_TERMINAL:
		draw_circle(at, r * Fx.GLYPH_TERMINAL_RATIO, tint, true)
		return
	if kind == Glyph.KIND_MODIFY:
		var d := r * Fx.GLYPH_MODIFY_RATIO
		var pts: Array[Vector2] = [
			at + Vector2(0.0, -d), at + Vector2(d, 0.0), at + Vector2(0.0, d), at + Vector2(-d, 0.0),
		]
		for k in pts.size():
			draw_line(pts[k], pts[(k + 1) % pts.size()], tint, Fx.GLYPH_MODIFY_PX)
		return
	push_error("ThreePickWindow: glyph kind %d has no drawing" % kind)


## **The rects `_draw()` paints — pulled out on purpose, because `_draw()` itself can't be driven headless**
## (`get_theme_default_font()` returns null untreed, so calling `_draw()` directly from a net does nothing and
## proves nothing). This function touches no font at all — it is pure `Layout` math over `_progress`'s live
## state, the same as `_gui_input`'s own hit-testing — so a net *can* call it directly and read back the real
## count `_draw()` will use, closing the gap a text-scan for `drawn.size()` cannot: a scan is satisfied by an
## unused decoy call sitting next to a hardcoded one; calling this function and reading its actual return
## value is not.
func _card_rects() -> Array[Rect2]:
	if _progress == null:
		return []
	return Layout.cards(size, _progress.drawn().size())


func _draw_buttons(font: Font) -> void:
	_draw_button(Layout.decline_rect(size), Fx.PICK_DECLINE_TEXT, Fx.PICK_DECLINE_COLOR, font)
	_draw_button(Layout.dice_rect(size), Fx.PICK_DICE_TEXT, Fx.PICK_DICE_COLOR, font)


## **Shape from `kind`, color from `rarity` — the card's whole "name · rarity · what it does · dummy
## marking".** Rarity separates by the border color (`RARITY_TINT`, Stage A's own proof this reads on this
## palette); the dummy diamond is the assembly window's `KIND_MODIFY` silhouette redrawn here — not a shared
## function (`CanvasItem.draw_*` only runs inside the calling node's own `_draw()`), a shared shape and color.
func _draw_card(rect: Rect2, glyph_id: int, font: Font) -> void:
	if not Glyph.DEFS.has(glyph_id):
		push_error("ThreePickWindow: glyph %d is not in the table - cannot draw its card" % glyph_id)
		return
	var rarity := Glyph.rarity_of(glyph_id)
	var edge: Color = Fx.RARITY_TINT.get(rarity, Fx.GLYPH_TINT_MISSING)
	draw_rect(rect, Fx.PICK_CARD_BG, true)
	draw_rect(rect, edge, false, Fx.PICK_CARD_EDGE_PX)

	var pad := Fx.PICK_PAD_PX * 0.5
	var x := rect.position.x + pad
	var text_w := maxf(rect.size.x - pad * 2.0, 0.0)

	var glyph_name: StringName = Glyph.DEFS[glyph_id]["name"]
	draw_string(font, Vector2(x, rect.position.y + pad + float(Fx.PICK_NAME_SIZE)), String(glyph_name),
		HORIZONTAL_ALIGNMENT_LEFT, text_w, Fx.PICK_NAME_SIZE, Fx.PICK_NAME_COLOR)

	var rarity_name: String = Fx.RARITY_NAME.get(rarity, "?")
	draw_string(font,
		Vector2(x, rect.position.y + pad + float(Fx.PICK_NAME_SIZE) + float(Fx.PICK_RARITY_SIZE) + 4.0),
		rarity_name, HORIZONTAL_ALIGNMENT_LEFT, text_w, Fx.PICK_RARITY_SIZE, edge)

	var kind := int(Glyph.DEFS[glyph_id]["kind"])
	draw_string(font, Vector2(x, rect.end.y - pad), _effect_text(glyph_id, kind),
		HORIZONTAL_ALIGNMENT_LEFT, text_w, Fx.PICK_EFFECT_SIZE, Fx.PICK_EFFECT_COLOR)

	# **The dummy marking's screen half** — Stage A closed the name half ("더미" is already the id's own
	#  `DEFS` name); this is the part that plan explicitly left for Stage D.
	if kind == Glyph.KIND_MODIFY:
		var c := rect.get_center()
		var d := minf(rect.size.x, rect.size.y) * Fx.PICK_DUMMY_MARK_RATIO
		var tint: Color = Fx.GLYPH_TINT.get(glyph_id, Fx.GLYPH_TINT_MISSING)
		var pts: Array[Vector2] = [
			c + Vector2(0.0, -d), c + Vector2(d, 0.0), c + Vector2(0.0, d), c + Vector2(-d, 0.0),
		]
		for k in pts.size():
			draw_line(pts[k], pts[(k + 1) % pts.size()], tint, Fx.PICK_DUMMY_MARK_PX)


## **"What it does" is a mechanical fact, not an invented name.** `docs/design/circle-rune-glyph.md`'s
## warning stands — 16 of the GDD's 17 glyphs are names only, and describing a rarity variant as if its
## behavior were decided would make the undecided read as decided. `power_pct` is not that: it is Stage A's
## own settled mechanic, so stating its value plainly is honest, not a naming decision.
func _effect_text(glyph_id: int, kind: int) -> String:
	var pct := Glyph.power_pct_of(glyph_id)
	if kind == Glyph.KIND_SPAWN:
		return "여덟 갈래로 흩어진다 (위력 %d%%)" % pct
	if kind == Glyph.KIND_TERMINAL:
		return "그 자리에서 터진다 (위력 %d%%)" % pct
	if kind == Glyph.KIND_MODIFY:
		return "이 탄의 위력을 %d%%로 올린다" % pct
	push_error("ThreePickWindow: glyph kind %d has no effect text" % kind)
	return "?"


func _draw_button(rect: Rect2, text: String, color: Color, font: Font) -> void:
	draw_rect(rect, Fx.PICK_CARD_BG, true)
	draw_rect(rect, color, false, Fx.PICK_CARD_EDGE_PX)
	draw_string(font, rect.position + Vector2(8.0, rect.size.y * 0.5 + float(Fx.PICK_EFFECT_SIZE) * 0.35),
		text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 16.0, Fx.PICK_EFFECT_SIZE, color)
