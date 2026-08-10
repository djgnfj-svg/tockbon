extends Node2D
## Character and staff. **It touches the screen only — it does not change character state.**
##
## **The single source for the staff tip is no longer here but `src/actor/staff.gd`.**
##  Let the drawing and the firing origin diverge and it looks like "it doesn't come out of where I aimed",
##  and that only shows up in a screenshot —
##  => **do not recompute the tip here.** `tip_px()` below only **calls** that function.
## Having no interpolation is correct — the character runs at 60Hz (the same clock as rendering), so there is
##  nothing between ticks. The only thing needing interpolation is `spell_view.gd`, which draws the 20Hz sim.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Character := preload("res://src/actor/character.gd")
const Staff := preload("res://src/actor/staff.gd")
const Fx := preload("res://src/view/fx_tuning.gd")
const SpellCircle := preload("res://src/actor/spell_circle.gd")
## **Same folder, so `net_layers` does not gate it** — `src/view/` files may reference one another. Used only
##  to call `kick()`, the same door `stage.gd` already uses for every other shake (gate wall, blasts).
const BlastFx := preload("res://src/view/blast_fx.gd")

var _ch: Character = null

## **The shake caller.** Optional and defaulting to null (the same idiom `monster_view.setup()`'s `char`/`grid`
##  parameters already use) — a net standing this node up with no stage has no shake to kick and must not bark.
var _blast_fx: BlastFx = null

## **The staff is shortened when blocked by terrain, so the screen holds the grid. It only reads.**
##  **Without taking this, the screen draws at the old seat while only firing goes to the new one** — the contract
##   that the three are one breaks right there and **not one error is raised.** That is why it is an argument of `setup()`.
var _grid: CellGrid = null

## **A reference, not a copy.** It is read on every `_draw()`, so when the shell changes the assembly the staff
##  tip color follows **on its own.** Keep a copy and the moment one push is forgotten it becomes "I changed the
##  combination and the screen stayed the same", and **no error is raised** — that is the way v1 died.
## **It only reads.** The moment the screen changes assembly state, it stops being the single source.
var _circle: SpellCircle = null

## Body sheet. **The path is held by `fx_tuning`** (presentation constants live in one file) — write the string
## again here and the day `assets/` moves only one side follows, and there is **no** net catching that drift
## (`assets/` is outside the folder scan).
## **No null check is attached.** If it cannot be read, `load()` and `draw_texture_rect_region` both bark —
##  a quiet `return` would make it **the character being invisible with nobody barking**, this repo's
##  representative silent death.
var _body_tex: Texture2D = load(Fx.CHAR_SHEET)

## Staff sheet. **The same idiom as `_body_tex` — no null check is attached** (same grounds as above).
var _staff_tex: Texture2D = load(Fx.STAFF_SHEET)

## **"Is it walking" is not asked of the character.** `character.gd` has no such state, and adding it would mean
##  editing that file, while **touching the screen only** is this file's contract.
##  => **Compare against the previous frame's x.** This is the only state the view holds.
## Being pushed also counts as "walking" — chosen knowingly, as written in the
##  `fx_tuning.CHAR_WALK_PX_PER_FRAME` comment.
var _prev_x := 0
var _moving := false

## **Hit-flash state — a child layer, not a material on `self`** (the box on `_flash_layer` below explains why).
var _flash_layer: Node2D = null
## View frames left of the hit flash. **Its clock is itself, the same one-field-one-clock rule `invuln_left`'s
##  own comment already holds** — a `delta` accumulator here would be a second clock, and the flash would
##  outlive or underlive the hit it reports on.
var _hit_flash_left := 0
## **`invuln_left`'s previous tick, so a rising edge can be read** — see `on_tick()` below for why the rising
##  edge, not an hp diff, is the signal.
var _prev_invuln_left := 0

## A child layer purely so the flash shader's material does not paint the staff and its ring too.
## **The same reason `monster_view._Layer` exists** (that file's own header: a `material` set on `self` applies
##  to every draw call this node makes during its own `_draw()`, so drawing the flashed body and the plain
##  staff in one `_draw()` call would mean either both are shaded or neither is).
class _FlashLayer extends Node2D:
	var fn: Callable
	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)


func setup(ch: Character, circle: SpellCircle, grid: CellGrid, blast_fx: BlastFx = null) -> void:
	_ch = ch
	_circle = circle
	_grid = grid
	_blast_fx = blast_fx
	# **`_prev_x`/`_prev_invuln_left` are aligned here.** Without aligning `_prev_x`, the first frame reads
	#  "0 -> spawn x" as movement and a standing-still character walks for one frame — `_prev_invuln_left`'s
	#  own risk is the same shape: unaligned, a fresh spawn with `invuln_left` already above 0 would read as
	#  "just hit" on the very first tick it is observed.
	if _ch != null:
		_prev_x = _ch.x
		_prev_invuln_left = _ch.invuln_left
	queue_redraw()


func _ready() -> void:
	# **With no shader it goes without a material** — the same "substitute, do not bark" idiom
	#  `monster_view._paint`'s own comment records; the flash then simply never becomes visible.
	var sh := load(Fx.CHAR_HIT_FLASH_SHADER) as Shader
	_flash_layer = _make_layer(_draw_flash)
	if sh != null:
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter(Fx.CHAR_HIT_FLASH_SHADER_PARAM, Fx.CHAR_HIT_FLASH_COLOR)
		_flash_layer.material = mat


func _make_layer(fn: Callable) -> Node2D:
	var n := _FlashLayer.new()
	n.fn = fn
	n.name = "HitFlash"
	add_child(n)
	return n


## **Clears the hit-flash state on a stage reset** — the same door `blast_fx.clear()`/`monster_view.clear()`
##  already open (`stage.gd`'s `_rebuild()`, "without clearing, the dead session's ... briefly ride into the
##  new session"). Without this, a hit taken the instant before pressing R paints a flash over the freshly
##  spawned character for a few frames.
func clear() -> void:
	_hit_flash_left = 0
	_prev_invuln_left = 0
	if _flash_layer != null:
		_flash_layer.queue_redraw()


## **Hit detection lives here, on the tick, not in `_process` on the frame.** `character.take_hit()` runs only
## inside `world_step`'s tick branch (`character.gd`'s own header: "call it at 60Hz and one hit becomes
## three") — watching `invuln_left` at 60Hz risks reading the same tick's write zero, one, two or three times
## depending on phase, the exact 60Hz/20Hz seam `CLAUDE.md` already names three times over. `stage.gd`'s
## `_on_ticked()` calls this once per tick, the same door `monster_view.on_tick()` and `blast_fx.on_blasts()`
## already use.
##
## **The rising edge of `invuln_left`, not an hp diff.** `take_hit` sets this field to `INVULN_TICKS` only on
## the tick a hit that respects invulnerability actually lands (`tanks_invuln=true` — direct hits, blasts, pig
## contact, hen bolts); fire's continuous damage passes `tanks_invuln=false` and never touches this field, so
## standing in fire correctly does not trigger this flash (it already has its own tell, `CHAR_BURN`'s border).
## Every other tick this field can only count down, so "it just went up" already means "I was just hit" with
## no second array to diff.
func on_tick() -> void:
	if _ch == null:
		return
	if _ch.invuln_left > _prev_invuln_left:
		_hit_flash_left = Fx.CHAR_HIT_FLASH_FRAMES
		if _blast_fx != null:
			_blast_fx.kick(Fx.CHAR_HIT_SHAKE_PX, Fx.CHAR_HIT_SHAKE_SECS)
	_prev_invuln_left = _ch.invuln_left


func _process(_dt: float) -> void:
	# **Do not build a separate walk clock.** Both "did it move" and "which frame of the cycle" come out of
	#  `_ch.x` — accumulate `delta` and there are two clocks from that moment, giving **"it stopped but the legs
	#  keep moving"**.
	#  `_process` runs once per frame and `_draw` comes after it => this is the seat for the update.
	if _ch != null:
		_moving = _ch.x != _prev_x
		_prev_x = _ch.x
	_hit_flash_left = maxi(0, _hit_flash_left - 1)
	# The character moves every frame and the staff follows the mouse every frame => always redraw.
	queue_redraw()
	# **The child does not receive the parent's `queue_redraw()`** — `monster_view._process`'s own comment
	#  names the identical trap ("the flash and the numbers freeze on the first frame").
	if _flash_layer != null:
		_flash_layer.queue_redraw()


## Unit vector toward the mouse. If the mouse is exactly at the character's center it falls back to
## **the facing direction** (normalizing a zero vector gives zero, and then the staff disappears).
##
## **The reference is the box center, not the staff pivot.** The pivot is `PIVOT_DY_PX` below the center,
##  so the two are off by that much, and **this change did not touch it** — the design left hand height "undecided",
##  and moving the reference before that value is settled makes it impossible to tell what changed the aim.
##  **Look at this together the day hand height is decided by eye.** It shows up largest when the mouse is
##  right up against the character.
func aim_dir() -> Vector2:
	if _ch == null:
		return Vector2.RIGHT
	var d := get_global_mouse_position() - _ch.center()
	if d.length_squared() < 1.0:
		return Vector2(_ch.facing, 0)
	return d.normalized()


## Where the bolt comes out. `stage.gd` passes this straight into `aim.fire_cmd`.
##
## **The computation is in `Staff.tip_px()` — do not redo it here.** The drawing side (`_draw`) calls the same
##  function, so "sprite tip" and "firing origin" are **structurally** the same value.
##  Recompute even one line here and the two can diverge from that moment, and **no error is raised.**
## **No null check is attached to `_grid`.** If the shell does not pass the grid, this must **bark** —
##  quietly returning the old seat leaves "screen at the old seat, firing at the new one" **with no error at all**,
##  and that is risk 2 of this document (the same discipline as attaching no null check to `_body_tex`).
func tip_px() -> Vector2:
	if _ch == null:
		return Vector2.ZERO
	return Staff.tip_px(_grid, _ch.x, _ch.y, aim_dir())


## **Picks which sheet cell to draw. Pure static, so a net can call it directly.**
##  This is **the seat that moves acceptance 3 (telling walk, jump and fall apart) and 4 (downed) from the eye
##   into the net** — a combination can be fed in and a cell number read back with no scene and no character.
##
## **Even so, what the net measures stops at "the code picks a different cell".**
##  **Draw all six cells identically and the net is still green** — "the art in that cell is actually different"
##  is measured by the eye only, in principle (plan section 7.2). Do not widen the label past that.
##
## The priority is a contract:
##  (1) **Downed comes before everything** — even while falling in a downed state, "it is downed" must show
##    so that nobody misses "I have to revive it"
##  (2) Airborne — rising and falling must split or the jump does not read on screen
##  (3) Walking, and everything else
## Airborne with `vy == 0` falls to **fall** (it is a single instant at the apex so either would do, but the
##  branch is kept to one).
static func pick_state(downed: bool, on_ground: bool, vy: float, moving: bool) -> int:
	if downed:
		return Fx.CHAR_DOWNED
	if not on_ground:
		return Fx.CHAR_JUMP if vy < 0.0 else Fx.CHAR_FALL
	return Fx.CHAR_WALK if moving else Fx.CHAR_STAND


## State -> the cell to cut from the sheet. **The table (`Fx.CHAR_FRAMES`) is the single source** — compute
## the cell number here and you get "I fixed the table and the screen stayed the same".
## **The clock for multi-cell states (walking) is `_ch.x`.** One cell advances per `CHAR_WALK_PX_PER_FRAME` —
##  why `absi`: walking left decreases x, and negative division truncating toward zero makes **left and right
##  asymmetric**.
## Asking for a state that does not exist **barks here.** Cover it with `get` and a state missing from the table
## quietly uses cell 0.
func _cell_rect(state: int) -> Rect2:
	var cells: Array = Fx.CHAR_FRAMES[state]
	var idx := 0
	if cells.size() > 1:
		idx = (absi(_ch.x) / Fx.CHAR_WALK_PX_PER_FRAME) % cells.size()
	# **These are in-sheet coordinates — use `Fx.CHAR_CELL_PX`, not `Character.W_PX`.**
	#  Since the box narrowed to 20px the two are different values, and using `W_PX` here cuts the sheet in
	#  20px units and draws **a fragment of the wrong cell**. Not one error is raised.
	return Rect2(int(cells[idx]) * Fx.CHAR_CELL_PX, 0, Fx.CHAR_CELL_PX, Fx.CHAR_CELL_PX)


## **The one place the body sprite's transform and cell are computed — `_draw()` and `_draw_flash()` both
## call this, on `self` and on `_flash_layer` respectively** (the same "single source" reason `tip_px()`'s own
## comment gives for not recomputing the staff tip). `canvas` is an argument, not implicit `self`, for the
## exact reason `monster_view._draw_flashes`'s own comment records: called from inside a child layer's
## `_draw()`, drawing onto implicit `self` would silently discard the command — damage numbers vanished
## wholesale that way once, with every net green.
##
## **`modulate` is the only difference between the two callers** — the body's own dim/full color for `_draw()`,
## white at the flash's current strength for `_draw_flash()`. Everything about *where* the sprite sits is
## identical, which is the whole point of pulling this out.
func _draw_body(canvas: CanvasItem, state: int, modulate: Color) -> void:
	# **The sprite cell (32px) is wider than the collision box (20px) — draw it centered on the box.**
	#  Draw it aligned to the top left and the character skews 6px left inside the box, and that only shows up
	#  as "the body looks off to one side when walking". Both are even, so this division lands on an integer.
	#  So **the sprite center and the box center are the same** — `Staff.pivot_px()` comes out of the box,
	#   and even after narrowing the box that seat is the middle of the body sprite.
	var pad := (Fx.CHAR_CELL_PX - Character.W_PX) / 2
	var sprite_x := _ch.x - pad
	# Why the origin goes at the right edge of the **sprite** when facing left: scale -1 sends local x leftward,
	#  so starting there is what makes the sprite land exactly in the same seat. **It is the sprite edge, not
	#  the box edge** — use the box and the character jumps by twice `pad` (12px) on every direction change.
	#  And the condition on the art side is **`minx + maxx == CHAR_CELL_PX - 1`** — `net_sprite` measures it.
	var flip := _ch.facing < 0
	canvas.draw_set_transform(
		Vector2(sprite_x + (Fx.CHAR_CELL_PX if flip else 0), _ch.y),
		0.0, Vector2(-1.0 if flip else 1.0, 1.0))
	canvas.draw_texture_rect_region(_body_tex,
		Rect2(0.0, 0.0, Fx.CHAR_CELL_PX, Fx.CHAR_CELL_PX),
		_cell_rect(state), modulate)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## `_flash_layer` calls this. **The same coordinate system as this node** — a child inherits the parent's
## transform, the same fact `monster_view._draw_flashes`'s own comment relies on.
##
## **State is recomputed here rather than cached from `_draw()`.** `pick_state()` is pure and cheap, and a
## cached field would be a second place holding "what `_draw()` decided this frame" that could go stale the
## moment the two calls stop happening in the same frame — recomputing keeps this function correct on its own.
func _draw_flash(canvas: CanvasItem) -> void:
	if _ch == null or _hit_flash_left <= 0:
		return
	var state := pick_state(_ch.downed, _ch.on_ground, _ch.vy, _moving)
	var frac := float(_hit_flash_left) / float(Fx.CHAR_HIT_FLASH_FRAMES)
	_draw_body(canvas, state, Color(1.0, 1.0, 1.0, Fx.CHAR_HIT_FLASH_COLOR.a * frac))


func _draw() -> void:
	if _ch == null:
		return
	# **The blink's clock is `invuln_left` itself.** It drops by one per tick, so watching only odd/even
	#  blinks twice over 0.2 seconds — accumulate `delta` here and there are two clocks from that moment,
	#  and it blinks after invulnerability has ended. **It only reads** (the first line of this file).
	var dim := 1.0 if (_ch.invuln_left & 1) == 0 else Fx.INVULN_DIM_A

	# **Which cell to draw — the only branch is `pick_state()`.** Write the conditions again here and
	#  the screen and the net see different rules (the net calls that function directly).
	var state := pick_state(_ch.downed, _ch.on_ground, _ch.vy, _moving)

	# **Left and right are one set plus a code flip.** Draw two sets by hand and the day comes when only one
	#  is fixed, and that drift shows up **only when looking left**, which the eye almost never catches.
	#  A flip has no such divergence in principle.
	#  The art is at a three-quarter angle, so flipping makes it **a mirror image** — chosen knowingly
	#  (the design's "the body is two sets, left and right").
	# **`draw_set_transform` applies to everything drawn afterwards — it must be restored.**
	#  Without restoring, the burn outline, the staff and **the ring at the tip** are drawn in a flipped
	#  coordinate system. The staff tip is the only place always visible without opening the assembly window,
	#  so that means the combination readout dies, and **not one error is raised.**
	#  **The nets cannot catch this** — at 16px, verify-read confirmed that deleting the restore line left
	#   **everything green**. All that guards it is this comment and the eye.
	# **Drawing the body is pulled out to `_draw_body()`** so `_draw_flash` (the hit flash, below) can draw the
	#  identical sprite at the identical seat through a shader instead — a second, hand-copied transform would
	#  drift from this one silently, and the drift would only show up as "the flash sits slightly off the body".
	_draw_body(self, state, Color(1.0, 1.0, 1.0, dim))

	# **If `_flash_layer` never got built (a net stood this node up with `new()`, no scene, `_ready()` never
	#  ran), the flash is drawn here directly instead** — the identical fallback `monster_view._process`'s own
	#  comment already uses ("otherwise two worlds appear, visible in the scene but absent in the net").
	if _flash_layer == null:
		_draw_flash(self)

	# **The air-jump mark, and it is drawn before the downed branch below on purpose.** The ring says "that
	#  second jump was real", and a jump that ended in going down is exactly the moment a player is most
	#  likely to think the input was eaten. **Its clock is `air_jump_flash_left` itself** — the same one field
	#  / one clock rule `invuln_left` above already holds; a `delta` accumulator here would be a second clock
	#  and the ring would outlive the jump.
	if _ch.air_jump_flash_left > 0:
		_paint_air_jump_ring(
			Vector2(float(_ch.x) + Character.W_PX * 0.5, float(_ch.y + Character.H_PX)),
			Fx.AIR_JUMP_RING_R_PX, Fx.AIR_JUMP_RING_COLOR)

	# **If downed, it ends here — neither the staff nor the ring at its tip is drawn.**
	#  It is a **state that cannot fire**, so drawing them would read as "it looks like I can shoot".
	#  The burn outline drops out with it — it has been that way since the rectangle days and was not changed.
	if _ch.downed:
		_draw_downed_tag()
		return

	# **It is an outline, so it stays visible together with the invulnerability dim.** Fire is not subject to
	# invulnerability, so that overlap is correct.
	if _ch.burning:
		draw_rect(Rect2(_ch.x, _ch.y, Character.W_PX, Character.H_PX),
			Fx.CHAR_BURN, false, Fx.CHAR_BURN_PX)
	# **Both the pivot and the tip come from `Staff`.** Draw from `_ch.center()` here and the drawn seat and
	#  the firing seat diverge, and that only shows up in a screenshot.
	# `aim_dir()` is called twice (here and inside `tip_px()`). **It is safe because the value is the same
	#  within one frame** — the mouse position does not change during a frame. Do not put state into `aim_dir()`.
	#  The moment you do, the drawn direction and the tip diverge, and that only shows up as
	#  "the staff looks slightly bent".
	var pivot := Staff.pivot_px(_ch.x, _ch.y)
	var tip := tip_px()
	var dir := aim_dir()
	_draw_staff(pivot, dir, (tip - pivot).length())

	if _circle == null:
		return

	# **The ring at the tip carries what is equipped — with one color.** The muzzle bead (size = layer count)
	# was erased by the user's acceptance, and what was lost is written in the `fx_tuning.STAFF_RING_*` section.
	#
	# **This is world coordinates — it must come after `_draw_staff` above restored the transform.**
	#  `tip` is already world px so that is natural, and **it makes where the restore line has to be visible
	#  in the shape of the code.** Without restoring, the ring sits in the wrong place and
	#  **no error is raised and the nets cannot catch it either.**
	#
	# **The ring overlaps the drawn ring exactly.** The seat `INSET` back from the tip is the ring's center
	#  (measured: tip 36.0, ring center x 32.0). **Alignment is something the eye has to look at.**
	# It is **re-read every frame** — the point is that there is no separate moment when the assembly changes.
	# **The "cannot fire" branch is inside `staff_tint`.** Split it here and that branch drops to a seat
	#  the nets cannot call, and then acceptance 5 is left to the eye only.
	# **The colour decision is not made here.** It used to be, and it asked `element()` unconditionally —
	#  remove the circle in the assembly window and that **barks on every redraw** (539 in one session), with
	#  every net green, because **nothing can call `_draw`.** `Fx.staff_ring_tint`'s header has the story.
	#  ⇒ **Do not unfold it back into this line.** What comes back with it is the blind spot, not the bug.
	draw_circle(tip - dir * Fx.STAFF_RING_INSET_PX, Fx.STAFF_RING_R_PX,
		Fx.staff_ring_tint(_circle), false, Fx.STAFF_RING_PX)


## **The rod and the ring are drawn separately. Do not x-scale the whole thing.**
##  When the staff is pressed its length drops below `LEN_PX`, and stretching the whole sprite
##  **squashes the ring into an ellipse** so the color ring (a true circle) laid over it does not fit.
##  => **Shrink only the rod and attach the ring 1:1 at the end.**
##  The rod shortening while the ring stays is the honest picture of "it gets pressed short near a wall"
##  (acceptance 2).
##
## **`draw_set_transform` applies to everything drawn afterwards — it must be restored.**
##  Without restoring, what follows (the ring's color ring, the next frame) is drawn in a rotated
##  coordinate system. **Not one error is raised.** **The nets cannot catch this** — the measurement is
##  written on the body-sprite side above. All that guards it is this comment and the eye.
##
## **The vertical is read from the sheet** (`get_height()`). Pin it as a constant and "png height" and
##  "constant" become two places, and when they diverge the staff stretches vertically with no error.
## **The single horizontal reference is `Staff.LEN_PX`** — that is why no width constant is kept in `fx_tuning`.
## **Being downed is put up directly above the character** (decided by the user).
##
## **Why the HUD is not enough**: even though the HUD already has "downed — R to restart",
##  **verifying agents got stuck on it three times.** Two reasons:
##  **The HUD debug text covers the monsters, so seeing the presentation means turning the HUD off** => and
##   then this text is gone too
##  **The eyes are on the character.** One line in a screen corner does not reach someone suspecting
##   "my click got eaten"
##
## **The staff disappearing is a signal too** (the box above) — but **"something gone" is not noticed.**
##  When firing is discarded wholesale (`_drain_queue`) with no change on screen, **it reads as an input problem.**
##
## **Centering is the same idiom as `monster_view._draw_dmg_number`** — measure the width and shift by half.
##  If there is no font it does not draw (passing `null` barks every frame and turns the nets red).
## **The air-jump ring, cut out of `_draw()` as its own method so a net can override it and read what it was
##  handed** — CLAUDE.md: "`_draw()` ran" is not "anything was drawn", and counting `_draw()` calls measures
##  the engine. Godot refuses to let a script override a native `draw_circle` (a hard parse error, measured
##  in `net_gate.gd`), so an ordinary method like this one is the only seam available.
##
## **Not named `_paint`** — that name is already taken twice with different signatures, by `gate_view.gd` and
##  `monster_view.gd`. A third overload would compile and then dispatch to whichever the reader did not mean.
##
## **World coordinates, so it must come after the body sprite restored its transform** (`draw_set_transform`
##  above). Drawn inside the flipped coordinate system it lands on the wrong side of the character while
##  facing left, and **no error is raised** — the same trap the staff ring's own comment records.
func _paint_air_jump_ring(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center, radius, color, false, Fx.AIR_JUMP_RING_PX)


func _draw_downed_tag() -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text := Fx.CHAR_DOWNED_TEXT
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.CHAR_DOWNED_SIZE).x
	draw_string(font,
		Vector2(_ch.x + Character.W_PX * 0.5 - w * 0.5, float(_ch.y) - Fx.CHAR_DOWNED_LIFT_PX),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.CHAR_DOWNED_SIZE, Fx.CHAR_DOWNED_COLOR)


func _draw_staff(pivot: Vector2, dir: Vector2, len_px: float) -> void:
	var sheet_h := float(_staff_tex.get_height())
	var ring := Fx.STAFF_RING_W_PX
	var rod := Staff.LEN_PX - ring
	# This is a rotated coordinate system — the origin is the pivot and +x is the aim direction. That is why
	#  the two rectangles below are written purely as "how far out from the pivot".
	draw_set_transform(pivot, dir.angle(), Vector2.ONE)
	# (1) The rod — shrunk **horizontally only** to the remaining length. `maxf` prevents a negative width
	#  in the extreme where the staff gets shorter than the ring (a box whose floor is below `ring`).
	draw_texture_rect_region(_staff_tex,
		Rect2(0.0, -Fx.STAFF_ANCHOR_Y_PX, maxf(0.0, len_px - ring), sheet_h),
		Rect2(0.0, 0.0, rod, sheet_h))
	# (2) The ring — **1:1.** It attaches at the end.
	draw_texture_rect_region(_staff_tex,
		Rect2(len_px - ring, -Fx.STAFF_ANCHOR_Y_PX, ring, sheet_h),
		Rect2(rod, 0.0, ring, sheet_h))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
