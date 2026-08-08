extends RefCounted
## Magic projectile sim + **the glyph pipeline** — a pure object. It knows nothing of the scene tree.
##
## **A projectile is not a node.** They are fixed-size parallel arrays, and one single node draws them all.
##  Four values this decision buys: (1) the server runs with no scene and the nets run with no scene
##  (2) pooling is unnecessary (3) the `add_child`-inside-a-physics-callback trap **vanishes**
##  (4) the `queue_free`+group trap **vanishes.**
##  Switch to "projectile = node" and (3) and (4) both come back.
##
## == **This file's contract — integers only** ======================
##  Position and velocity are **fixed point, 1/256 of a cell**. There is **not one** `Vector2` (32-bit float),
##  `sqrt`, trig function, `randi()`, `Time` or `delta`. Moving to screen coordinates is the renderer's job.
##
##  Why go this far — **because in lockstep the only thing that crosses the wire is the fire command.**
##  Flight, blast and grid change must **each be reproduced by every client**, so if flight is not deterministic
##  one blast cell drifts, that cell changes terrain, and **the two clients' worlds become different worlds forever.**
##  => "Same float operations, same answer, surely?" is dangerous: `+ - *` are bit-identical under IEEE-754,
##   but **`sqrt`, `sin` and `atan2` are libm and differ per platform**, and aim normalization sits exactly there.
##
##  **No `sin`/`cos` table either.** Baking one with floats at boot makes the baked values platform-dependent
##   all over again. => Normalization is done by **one integer Newton `_isqrt`**, run **once** at launch.
##
##  **A net that runs it twice and compares cannot hold this contract in principle** — two instances in the same
##   process give identical float answers too. `net_determinism`'s **folder text scan** is the only detector.
## =================================================================

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")

## Fixed point: the low 8 bits are the fraction. Cell coordinate = pos >> FP_SHIFT.
## Precision 4px / 256 = 0.0156px — far more than enough.
## `>>` is an arithmetic shift, so it **floors on negatives too** (cell coordinates don't jump outside the grid).
const FP_SHIFT := 8
const FP_ONE := 1 << FP_SHIFT
const FP_HALF := FP_ONE >> 1

## Intermediate precision for aim normalization. Without it, `_isqrt`'s truncation inflates speed by up to 40%
##  on short aim vectors (e.g. at aim (1,1), isqrt(2)=1 makes speed larger by a factor of the square root of 2).
##  **A net that measures only axis directions can't see this value killed to 0** — that is why the net measures diagonals.
const AIM_SHIFT := 8

## Absolute ceiling on an aim component. The fire command's aim is **two i16s** by contract.
##  Exceed it and `len2 << 16` overflows and goes silently wrong.
const AIM_MAX := 32767

## Uses **a different key name** (`spell_kind`) from the grid commands — share the same `kind` key and
##  the two enums' numbers collide, `CellGrid.apply` runs the wrong thing, and if the value happens to land in
##  a valid range, **with not one error** a fire becomes a fill.
const CMD_FIRE := 0

## Spread's 8 directions. **The order walks around the circle** — the order is part of the determinism contract
##  (launch order sets slot order, and slot order sets the order things hit the blast budget).
const SPREAD_DX: Array[int] = [1, 1, 0, -1, -1, -1, 0, 1]
const SPREAD_DY: Array[int] = [0, 1, 1, 1, 0, -1, -1, -1]

# --- state -------------------------------------------------------
## **They are parallel arrays.** Held as `Array[Dictionary]` this would touch 32 dictionaries every tick.
## **Do not pass a `PackedInt32Array` as an argument** — it becomes a CoW copy and writes silently evaporate.
##  Keep them all as members and touch them directly here.
var _px := PackedInt32Array()
var _py := PackedInt32Array()
var _vx := PackedInt32Array()
var _vy := PackedInt32Array()
## Previous position, for render interpolation. The sim **does not read this** — purely the screen's share.
var _prev_px := PackedInt32Array()
var _prev_py := PackedInt32Array()
## **The remaining glyph list** (`glyph_defs.gd`). A single integer.
var _glyphs := PackedInt32Array()
var _element := PackedByteArray()
var _age := PackedInt32Array()
## **The spread generation.** 0 = original. **Size, range, blast radius, ignition radius and presentation all
##  derive from here** (`sim_tuning.SIM_SIZES` · `fx_tuning.FX_SIZES`).
##  The two tables must grow **together** — the sim axis growing while the screen doesn't follow is how v1 died,
##   and `net_tables` measures length and monotonicity together.
var _gen := PackedByteArray()

## Slot indices **shuffle every tick** (removal is swap-remove). If the renderer holds a trail by index,
##  the moment a projectile dies someone else's trail teleports — no error, only a wrong screen.
##  => The renderer must pair by `get_id()`.
var _id := PackedInt32Array()
## **Not rewound on reset — it increases monotonically across resets.** Rewind it and the first projectile after
##  a reset reuses id 0, and since the renderer pairs trails by id, **an old trail sticks to a new projectile.**
var _next_id := 0

var _count := 0
var _behavior := PackedByteArray()

# --- per-tick budget ----------------------------------------------
## Per-glyph "how many times per tick". `_cap` is the baked table (immutable), `_left` is what remains this tick.
##  **The point is that the pipeline knows no specific glyph id** — the budget is one field of `glyph_defs.DEFS`
##   and this only indexes it. A new glyph gaining a budget does not change this file.
var _budget_cap := PackedInt32Array()
var _budget_left := PackedInt32Array()

## **A pipeline pushed to the next tick because the budget ran out.**
##  What gets pushed is not one blast but **the whole remaining list.** Defer only the blast and run the rest now
##   and "blast -> spread" becomes "spread -> blast", which the GDD pinned as **different magic** —
##   the kind of magic changes with not one error.
## The length ceiling is projectile cap (32) x layer cap (7), so it is finite by itself.
var _pend_x := PackedInt32Array()
var _pend_y := PackedInt32Array()
var _pend_g := PackedInt32Array()
var _pend_e := PackedByteArray()
## The generation is pushed along too — without it a deferred blast detonates **at generation 0 size**, so small
##  blasts grow only when you spam. To the eye it reads only as "sometimes it detonates unusually large".
var _pend_gen := PackedByteArray()

## Blasts that went off this tick — **the only notice presentation gets.** The sim **does not read this.**
##  Cleared at the start of `step()`. Leave it to the shell and the moment someone forgets once, the same flash
##   **replays forever**, and no error is raised.
var _fx_x := PackedInt32Array()
var _fx_y := PackedInt32Array()
var _fx_e := PackedByteArray()
var _fx_g := PackedByteArray()

## **The spans a bolt crossed this tick** (fixed point). **The same idiom as the blast notice** —
##  cleared at the start of `step()`, and the sim **does not read it.** It only goes out.
##  Only the consumer differs: the blast notice is read by the screen and **this one is read by the actor**
##  (the "was I hit" test in `src/actor/character.gd`).
##
## **Why a span and not "the current position".** A generation 0 bolt covers 20 cells (80px) per tick while the
##  character box is **20px** (monsters are 20-44px depending on kind) => matching only the points at tick
##  boundaries lets **the leap skip the whole box.** It is one frame, so **the eye can never see it** and it reads
##  only as "sometimes it doesn't hit" — `_walk` already wrote the same trap once for walls
##  ("do not write it as a check on the destination cell only").
##  **These were stale values across the 32px switch** (the old 40px/16px are from the 16px world) —
##  `monsters-minimum` fixed them passing through stage 3.
##
## **It carries neither generation nor rune.** Every bolt does the same damage today, so **there is no consumer.**
##  Sending a value nobody uses makes it a false knob (the same discipline as the `_notify_blast` comment).
var _seg_x0 := PackedInt32Array()
var _seg_y0 := PackedInt32Array()
var _seg_x1 := PackedInt32Array()
var _seg_y1 := PackedInt32Array()

## The cell `_walk` stopped at. **Why a member and not a local**: the impact point is both an argument to
##  `_impact` and the end point of the span notice, so keeping two copies gives "the blast happened here but the
##  span went to there", and that mismatch shows up only as **hitting a character beyond a wall.**
var _hit_cx := 0
var _hit_cy := 0


func _init() -> void:
	var n := Tuning.MAX_PROJECTILES
	_px.resize(n)
	_py.resize(n)
	_vx.resize(n)
	_vy.resize(n)
	_prev_px.resize(n)
	_prev_py.resize(n)
	_glyphs.resize(n)
	_element.resize(n)
	_age.resize(n)
	_gen.resize(n)
	_id.resize(n)
	# Material behavior and glyph budgets are **received baked** — redefine them here and the rules become two copies.
	_behavior = Mat.bake_behavior()
	_budget_cap = Glyph.bake_tick_budget()
	_budget_left.resize(_budget_cap.size())


# =================================================================
#  Commands
# =================================================================

## **This is the one thing that crosses the wire.** Flight, blast and grid change are each client's deterministic
##  consequence, so **however big the blast, bandwidth is 0.**
## `adx`/`ady` are **integer differences in cells** — the mouse float is quantized exactly once in `src/actor/aim.gd`.
static func cmd_fire(ox: int, oy: int, adx: int, ady: int, element: int, glyphs: int) -> Dictionary:
	return {
		"spell_kind": CMD_FIRE, "ox": ox, "oy": oy,
		"adx": adx, "ady": ady, "element": element, "glyphs": glyphs,
	}


## Fire. True if accepted.
## **False is not itself an error** — hitting the cap or a zero aim should be dropped quietly
##  (clicking exactly on the origin is normal input). Only unknown values bark.
func fire(cmd: Dictionary) -> bool:
	# **Fire is by design the only command that crosses the wire — validate it here or there is nowhere to.**
	#  `_px` being a `PackedInt32Array`, an out-of-range origin is **truncated to 32 bits with no error** (v1 measured:
	#  ox = 10,000,000 -> stored value -1,734,967,168 => the projectile starts on the far side of the grid).
	#  And that truncation is **deterministic**, so it doesn't even desync and **nobody barks.**
	#   Unreachable with a local mouse, but the network opens that door.
	if int(cmd.get("spell_kind", -1)) != CMD_FIRE:
		push_error("SpellSim: unknown spell command %s - discarding the shot" % cmd)
		return false
	var element := int(cmd.get("element", -1))
	if not Tuning.ELEM_ALL.has(element):
		push_error("SpellSim: unknown rune %d - discarding the shot" % element)
		return false
	var ox := int(cmd.get("ox", 0))
	var oy := int(cmd.get("oy", 0))
	if ox < 0 or ox >= CellGrid.W or oy < 0 or oy >= CellGrid.H:
		push_error("SpellSim: origin (%d,%d) is outside the grid - discarding the shot" % [ox, oy])
		return false
	var adx := int(cmd.get("adx", 0))
	var ady := int(cmd.get("ady", 0))
	if absi(adx) > AIM_MAX or absi(ady) > AIM_MAX:
		push_error("SpellSim: aim (%d,%d) is outside i16 range - discarding the shot" % [adx, ady])
		return false
	var glyphs := int(cmd.get("glyphs", Glyph.GLYPH_NONE))
	if not _valid_glyphs(glyphs):
		return false

	return _launch((ox << FP_SHIFT) + FP_HALF, (oy << FP_SHIFT) + FP_HALF,
		adx, ady, glyphs, element, 0)


## **The glyph constraint bites here too, not only at assembly time.** The GDD chose to stop the explosion with a
##  constraint rather than a cap ("spread, only one per magic circle"), and the consumer of that table is this function.
##  => The assembly window (B) **reads the same table** and blocks placement before it happens — the rule does not
##   become two copies.
func _valid_glyphs(glyphs: int) -> bool:
	var cur := glyphs
	var layers := 0
	while cur != Glyph.GLYPH_NONE:
		var id := Glyph.first(cur)
		if not Glyph.DEFS.has(id):
			push_error("SpellSim: unknown glyph id %d - discarding the shot" % id)
			return false
		var cap := int(Glyph.DEFS[id]["max_per_circle"])
		if cap > 0 and Glyph.count_of(glyphs, id) > cap:
			push_error("SpellSim: glyph %s is limited to %d per magic circle - discarding the shot" % [
				Glyph.DEFS[id]["name"], cap])
			return false
		layers += 1
		cur = Glyph.rest(cur)
	if layers > Tuning.GLYPH_MAX_LAYERS:
		push_error("SpellSim: %d layers - the ceiling is %d" % [layers, Tuning.GLYPH_MAX_LAYERS])
		return false
	return true


## **Fire and spread go through the same door.** Normalize separately in each and you get "only the 8 spread bolts
##  have a different speed", which to the eye reads only as "the spreading shape is off".
## The arguments are **fixed-point positions** (not cells) — spread must leave from the middle of the impact point.
func _launch(pfx: int, pfy: int, adx: int, ady: int,
		glyphs: int, element: int, gen: int) -> bool:
	if _count >= Tuning.MAX_PROJECTILES:
		# **Bark and drop.** In single player spread is one per magic circle, so 1 -> 8 bolts is the ceiling and
		#  32 is unreachable in principle. Reaching it is a bug, so it must bark
		#  (the wrapper counts stderr as failure, so nobody can miss it).
		push_error("SpellSim: exceeded the simultaneous projectile cap %d" % Tuning.MAX_PROJECTILES)
		return false
	var len2 := adx * adx + ady * ady
	if len2 <= 0:
		return false
	# The only quantization point and the only square root. It does not run again in flight.
	var norm := _isqrt(len2 << (AIM_SHIFT + AIM_SHIFT))
	if norm <= 0:
		return false

	# Speed comes from the generation table too — "smaller and weaker" includes **going less far**.
	#  Drag range ceiling = speed / (1 - DRAG), so this one line sets range entirely.
	var speed_fp := Tuning.speed_cells(gen) << FP_SHIFT
	var i := _count
	_px[i] = pfx
	_py[i] = pfy
	_prev_px[i] = pfx
	_prev_py[i] = pfy
	_vx[i] = (adx << AIM_SHIFT) * speed_fp / norm
	_vy[i] = (ady << AIM_SHIFT) * speed_fp / norm
	_glyphs[i] = glyphs
	_element[i] = element
	_age[i] = 0
	_gen[i] = gen
	_id[i] = _next_id
	_next_id += 1
	_count = i + 1
	return true


## **The deferred pipelines are cleared too.** Without it, the tick after rebuilding the stage with R, the previous
##  experiment's blast punches holes in the new terrain — acceptance 1 and 2, which compare two combinations, die there.
## `_next_id` is **not rewound** (comment above).
func reset() -> void:
	_count = 0
	_pend_x.clear()
	_pend_y.clear()
	_pend_g.clear()
	_pend_e.clear()
	_pend_gen.clear()
	_clear_notices()


# =================================================================
#  Tick
# =================================================================

## **The call order is a contract**: 1. drain external commands 2. `grid.step()` 3. `spell.step(grid)`.
##  Projectiles fly against **the grid after the cells have moved**.
##
## The order inside here is a contract too: **pay the deferred ones first, then look at new impacts.** Reverse it
##  and this tick's impacts eat the whole budget so the deferred ones never detonate — the other face of
##  "spam shots and a few don't detonate".
func step(grid: CellGrid) -> void:
	_clear_notices()
	for id: int in Glyph.ALL:
		_budget_left[id] = _budget_cap[id]
	_drain_pending(grid)

	var i := 0
	while i < _count:
		if _advance(grid, i):
			i += 1
		else:
			_remove(i)


## One projectile. True if it survives.
func _advance(grid: CellGrid, i: int) -> bool:
	_age[i] += 1
	if _age[i] > Tuning.LIFETIME_TICKS:
		return false

	# **These two lines are the whole trajectory rule** (design, "trajectory").
	#  At high speed inertia beats gravity so it looks almost straight, and as it slows gravity wins and it droops.
	#  One rule makes "flies straight for N ticks and falls after" by itself — **there is no moment where it bends.**
	#  The order is a contract: multiply drag **first**, add gravity **after**. Reverse it and the gravity added
	#   this tick is damped too, so terminal speed drops by a factor of DRAG (to the eye, only "it feels less heavy").
	_vx[i] = _vx[i] * Tuning.DRAG_NUM / Tuning.DRAG_DEN
	_vy[i] = _vy[i] * Tuning.DRAG_NUM / Tuning.DRAG_DEN + Tuning.GRAVITY_FP

	var x0 := _px[i]
	var y0 := _py[i]
	var x1 := x0 + _vx[i]
	var y1 := y0 + _vy[i]
	_prev_px[i] = x0
	_prev_py[i] = y0
	_px[i] = x1
	_py[i] = y1
	var alive := _walk(grid, i, x0 >> FP_SHIFT, y0 >> FP_SHIFT, x1 >> FP_SHIFT, y1 >> FP_SHIFT)

	# **Leave the end point as `x1` and it hits a character *beyond* the wall.** A bolt that impacted did not reach
	#  x1 — it reached the impact cell where `_walk` stopped. x1 is the true arrival point only when it survived.
	# **There is exactly one notice site, here.** Notify from `_impact` too and you get "some bolts are notified and
	#  some are not", which reads only as "sometimes it doesn't hit".
	# The die-of-age branch already returned above — **it did not move, so there is no span.**
	if alive:
		_notify_seg(x0, y0, x1, y1)
	else:
		_notify_seg(x0, y0, _cell_center_fp(_hit_cx), _cell_center_fp(_hit_cy))
	return alive


## **Integer Bresenham steps every cell crossed — do not write this as "check the destination cell only".**
##  The first tick covers 10 cells, so checking only the destination **passes straight through a 1-2 tile wall.**
##  It is one frame, so **the eye can never see it** — to the user it reads only as "sometimes it doesn't detonate".
##
## **The starting cell is not checked.** It was already seen last tick (it passed, which is why the bolt is alive),
##  and on the first tick the starting cell is the staff tip — if the character is against a wall, detonating right
##  there is correct.
## Bresenham **grazes past diagonal corners.** "Terrain's minimum thickness is 4 cells so it can't happen" is true
##  only on the initial map, and **the blast itself breaks that premise** — an integer disc carving terrain leaves
##  1-cell diagonal fragments. => In the real game, **if "sometimes it doesn't detonate" is reported, this is the
##  first suspect.** The answer is a supercover DDA, but it costs more and is unrelated to what this stage measures,
##  so it was **deliberately left alone.**
func _walk(grid: CellGrid, i: int, x0: int, y0: int, x1: int, y1: int) -> bool:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var cx := x0
	var cy := y0
	# The impact point is **not the solid cell but the empty cell just before it.** If spread threw 8 bolts from a
	#  solid cell, all 8 would be born inside the wall and **all detonate on the spot** — 8 blasts would look like
	#  1 and acceptance 2 would die entirely. The blast uses the same point (1 cell is invisible in a radius-24 circle).
	_hit_cx = x0
	_hit_cy = y0

	# A `for` with a step ceiling, not a `while` — one sign error and a `while` eats the whole frame and stops
	#  (the game freezes with no error).
	var steps := dx - dy
	for _k in steps:
		if cx == x1 and cy == y1:
			return true
		var e2 := err + err
		if e2 >= dy:
			err += dy
			cx += sx
		if e2 <= dx:
			err += dx
			cy += sy

		if cx < 0 or cx >= CellGrid.W or cy < 0 or cy >= CellGrid.H:
			return false  # outside the grid = gone with no impact
		if _behavior[grid.mat_at(cx, cy)] != Mat.BEHAVIOR_STATIC:
			_hit_cx = cx
			_hit_cy = cy
			continue
		_impact(grid, _hit_cx, _hit_cy, i)
		return false
	return true


## **Everything** an impact does to the world. **The order is a contract: carve -> rune trace -> glyph.**
func _impact(grid: CellGrid, x: int, y: int, i: int) -> void:
	# (1) **There is no conditional branch.** It looks at neither rune nor glyph — see the `_carve` comment below.
	_carve(grid, x, y, _gen[i])
	# (2) **The rune trace comes before the glyph.** The trace is the floor value and the glyph stacks on top of it.
	_rune_trace(grid, x, y, _element[i], _gen[i])
	# (3) The glyph pipeline. A blast digs far larger here than (1) does.
	_resume(grid, x, y, _glyphs[i], _element[i], _gen[i])


## **Every impact carves — even with no glyph, even with a none rune** (the GDD's first natural law,
##  "terrain is destroyed. Magic digs walls").
##
## **The point is that this is not inside `_rune_trace`.** Put it there and the none branch `return`s, so
##  **only none does not carve**, and that is "some bolts carve and some don't" —
##  the exact trap `_rune_trace` below already avoided with "every impact leaves a trace", the same idiom.
##
## **(1) is placed before (2)** — the same idiom as `cell_grid._blast`'s "destruction comes first".
##  **But the nets cannot measure this order. Two people measured it separately** (builder · verify-run):
##   swapping (1) and (2) and running everything left **1,371 checks all green and stderr clean.**
##  Why doesn't it bite — reversed, `_write_cell`'s `_unburn` does erase the fire just set. But **in the correct
##   order those cells never catch in the first place** (a carved cell is EMPTY = fuel 0, and `_ignite_cell` stops
##   at fuel 0) => **the grid state is the same in both orders.**
##  **That equivalence hangs on "as long as `_write_cell` calls `_unburn`".**
##   Remove that call and 15 nets go red (verify-read measured) — that is, the day `_unburn` is moved or removed,
##   this order **silently becomes a contract again.** Leave this paragraph unfixed that day and nobody will know.
##  And **only the grid state is the same** — `consume_changed()` **differs by 13**
##   (carve first 113 · ignite first 126). Nobody measures that value today and the screen behaves the same.
##   **So do not read this line as "the nets protect it". The order is for the person reading.**
##
## **The only contract actually observed is `carve_r < rune_r`.** Break it and the carve erases the fuel the fire
##  would burn wholesale, so **only the fire quietly disappears** — the same thing as the `cell_grid.blast_ignite_r`
##  trap, and it was measured inverted: setting `carve_r(0)` equal to `rune_r(0)` turned **16 checks red.**
##  => The real picture of "carved while burning" is **a ring**: the inner `carve_r` is carved and
##   the band `carve_r < r <= rune_r` burns. `net_tables` measures the inequality per generation.
##
## **It issues no notice.** A carve is not a blast — no flash, no shake.
##  A hole appearing while the screen does not flash is what says "this is not a blast".
func _carve(grid: CellGrid, x: int, y: int, gen: int) -> void:
	grid.apply(CellGrid.cmd_carve(x, y, Tuning.carve_r(gen)))


## **Even with no glyph at all, an impact does at least the rune's part** (design, "a bolt leaves the rune's trace
##  even with no glyph").
##
## **The point is that there is no conditional branch.** Written as "only when the list is empty", the rule becomes
##  two, and the day those two diverge you get "some bolts leave a trace and some don't".
##  => **Every impact leaves a trace.** `net_spell._glyph_bolt_also_traces` holds that decision.
##
## **The price is written down exactly — it is not "overwriting".**
##  When a blast follows, `rune_r < rd` is the contract and both use **the same point**, so the trace's disc fits
##  entirely inside the blast's disc => **the observable effect is 0.**
##  **"But ghost indices are still left in the burn slots (measured 41%)" was written here, and it is false.**
##   verify-read matched three instruments (burn-slot length · membership claim · flag) and re-measured across four
##   combinations, and **"EMPTY yet flagged" was 0 everywhere**
##   (no glyph 46/46/46 · blast 118 · spread 62 · spread+blast 254).
##   => **As long as `_write_cell` calls `_unburn`, ghosts are 0 in principle.** The 41% appears to be a value from
##   **before** `_unburn` was added. Even with carving added, **there is no risk of growing them to begin with.**
##
## **The trace itself does not break terrain. It only ignites.** Digging is `_carve`'s ((1) above) job.
##  **This line used to read "an impact does not break terrain", and it was overturned.**
##   The old grounds were "break it and spread doubles as blast, so 'spread->blast' and 'blast->spread' mush
##   together on screen".
##   **The grounds for overturning it: what prevents the mush is not "carve or not" but "size".** With a blast `rd`
##   of 8 cells against a carve of 2, **the area differs 16x** — the pair actually cutting it close is `rune_r` (6)
##   and `rd` (8), and `sim_tuning.SIM_SIZES` wrote for itself that "the margin shrank from 0.25 to 0.75".
##   => **If it looks mushy, the first suspect is `rune_r`, not `carve_r`.**
##  The trigger was a user report — "ordinary magic and fire magic don't shrink a wall by one cell ·
##   **you can't even tell whether you attacked**". Under the old rule the only thing that dug walls was the blast
##   glyph, so a magic circle with no glyph was **completely harmless to a stone wall**
##   (the fire rune only ignites, and stone doesn't burn).
## **Barks on an unknown trace.** When the nets impact each of `ELEM_ALL` once, a rune that exists in the table but
##  not in code is caught **for free** by the wrapper's stderr check (the same device as `_run_glyph`).
func _rune_trace(grid: CellGrid, x: int, y: int, element: int, gen: int) -> void:
	var trace := int(Tuning.ELEM_DEFS[element]["trace"])
	if trace == Tuning.TRACE_IGNITE:
		grid.apply(CellGrid.cmd_ignite(x, y, Tuning.rune_r(gen)))
		return
	# **The water rune's trace — the exact mirror of fire.** Same place, same shape; only what it leaves differs.
	#  **The amount is fixed at `WATER_MAX` and strength comes only from the radius.** "A different amount per
	#   magic strength" is **derived** from `water_r` shrinking per generation — half the radius is a quarter the water.
	#  Put the amount in a table separately and **one more column has to decrease**, and if that column doesn't
	#   decrease, nobody measures it unless its name is written into `net_tables` (that file's `damage` case).
	#   => **Keep it to one axis.** Open it the day grounds appear for a separate amount.
	if trace == Tuning.TRACE_WET:
		grid.apply(CellGrid.cmd_water(x, y, Tuning.water_r(gen), Tuning.WATER_MAX))
		return
	# **This one `return` is the whole definition of none** — **it leaves no trace.**
	#  **It is not "does nothing to the world". That sentence narrowed** — carving moved up to (1) of `_impact`,
	#   so **a none bolt does make a hole.** The user pointed at both, saying "**ordinary magic and** fire magic",
	#   so that is the intent. (The same sentence is in `sim_tuning.ELEM_NONE` — **two places.**)
	#  **Do not replace this with the bark below.** "In the table but not in code" and "deliberately does nothing"
	#   are different things, and folding them into one branch buries a real missing implementation under everyday firing.
	if trace == Tuning.TRACE_NONE:
		return
	push_error("SpellSim: rune trace %d has no implementation" % trace)


## **The glyph pipeline.** Runs from the **first glyph** of the list at the impact point.
##
##  · **A glyph that makes bolts** (SPAWN) -> hands the remaining list to the new bolts and **ends here**
##  · **A glyph that ends where it is** (TERMINAL) -> no bolt is made, so **it continues at the same place**
##
## An empty list ends it — **that is the same code path as "take all the glyphs out and it must still fire".**
## It cannot be infinite: `rest` shrinks by 4 bits each time, so 7 rounds at most reach 0.
##
## Why it takes **only position, list and rune** and not the impacting projectile: when a deferred pipeline resumes
##  next tick, that projectile is already gone. Hang it on the slot index and there is no way to resume then.
func _resume(grid: CellGrid, x: int, y: int, glyphs: int, element: int, gen: int) -> void:
	var g := glyphs
	while g != Glyph.GLYPH_NONE:
		var id := Glyph.first(g)
		# When the budget runs out, push **the whole remaining list** (`_pend_*` comment above). Pull out only this
		#  glyph here and keep running the rest and the order reverses, and it becomes different magic.
		# 0 = unlimited, so **it isn't even counted.** Count it and the counter drifts negative and loses meaning.
		if _budget_cap[id] > 0:
			if _budget_left[id] <= 0:
				_defer(x, y, g, element, gen)
				return
			_budget_left[id] -= 1
		g = _run_glyph(grid, x, y, id, Glyph.rest(g), element, gen)


## Runs one glyph and returns **the remaining list to run next.**
## Returns `GLYPH_NONE` (= ends here) if the list was handed to new bolts or the glyph is unknown.
##
## **Barks on an unknown id.** When the nets run each of `Glyph.ALL` once, a glyph that exists in the table but not
##  in code is caught **for free** by the wrapper's stderr check.
## Why `if` and not `match`: in a `match`, an attribute access like `Glyph.GLYPH_BLAST` **risks being read as a
##  binding pattern**, and then every id hits the first branch with no error raised.
func _run_glyph(grid: CellGrid, x: int, y: int, id: int, rest: int,
		element: int, gen: int) -> int:
	if id == Glyph.GLYPH_BLAST:
		# The one door that changes the grid is `apply(cmd)` — touch `_mat` directly here and the side effects
		#  added later (waking, ignition) are skipped wholesale and **nothing happens, with no error.**
		var rd := Tuning.blast_rd(gen)
		grid.apply(CellGrid.cmd_blast(x, y, rd, Tuning.blast_ignite_r(gen)))
		_notify_blast(x, y, element, gen)
	elif id == Glyph.GLYPH_SPREAD:
		# **"Blocked by the floor" and "no slot" must be told apart.** Both are "no bolt was made", but the former
		#  is **a designed normal path** and must be quiet, and the latter is **a bug** and must bark.
		#  Fold them into one branch and the bug hides behind the normal path's silence.
		if gen >= Tuning.SPLIT_MAX:
			# **The size floor** (GDD). No bolt was made, so there is nowhere to hand the list => continue in place.
			#  **It is unreachable today** — spread is one per magic circle (`max_per_circle: 1`), so a generation 1
			#   bolt cannot carry spread. It is a structural floor for the day that constraint loosens, and
			#   **the nets cannot reach this branch either** (it cannot be produced through the public API).
			return rest
		if _spread(x, y, rest, element, gen) == 0:
			# **Not one slot = a bug.** `return rest` here would run the remaining list **at the impact point at
			#  generation 0** — "spread -> blast" would become **one big hole** instead of eight small ones, and
			#  that is exactly the difference the GDD pinned as **different magic.**
			#  => Rather than quietly become different magic, **bark and drop** (plan 9: spread is not deferred).
			push_error("SpellSim: spread got not one slot - discarding the remaining list %d" % rest)
			return Glyph.GLYPH_NONE
	else:
		push_error("SpellSim: glyph %d has no implementation" % id)
		return Glyph.GLYPH_NONE

	# **Whether it continues or ends is chosen by the table's `kind`, not by the id** — the GDD wrote that this
	#  distinction is the whole pipeline, and here is that axis's **only consumer.**
	#   · SPAWN    the new bolts took the remaining list => end here
	#   · TERMINAL no bolt was made => continue at the same place
	#  Without this branch, changing `kind` does nothing, and then table and code diverge while
	#   "the glyph's execution rule" survives only in a comment.
	if int(Glyph.DEFS[id]["kind"]) == Glyph.KIND_SPAWN:
		return Glyph.GLYPH_NONE
	return rest


## **Spread — scatters small bolts in 8 directions from the impact point and hands them the remaining list.**
##  Returns **how many were actually born.** The size-floor test is the caller's (comment above).
##
## `(±1,0) (0,±1) (±1,±1)` — **the eight come out as integers with no `sin` or `cos`** —
##  the glyph's integer constraint costs nothing here (GDD).
## Normalization is `_launch`'s job — correct the diagonals separately here and you get "only the four diagonals
##  are faster", which on screen reads only as **a squashed radial burst.**
## **Only some of them flying is a bug too** — the burst goes lopsided. `_launch` already barks on the slot cap, so
##  it does not bark again here (bark the same fact twice and the amnesty declaration widens).
func _spread(x: int, y: int, rest: int, element: int, gen: int) -> int:
	# It leaves from **the middle** of the impact point. Emitting from a cell corner makes the eight directions asymmetric.
	var pfx := (x << FP_SHIFT) + FP_HALF
	var pfy := (y << FP_SHIFT) + FP_HALF
	var born := 0
	for k in Tuning.SPREAD_COUNT:
		# **Hands the remaining list through as-is** (`rest`) — this one integer assignment is the whole of the
		#  GDD's "a glyph that makes bolts hands the remaining list to the new bolts".
		if _launch(pfx, pfy, SPREAD_DX[k], SPREAD_DY[k], rest, element, gen + 1):
			born += 1
	return born


func _defer(x: int, y: int, glyphs: int, element: int, gen: int) -> void:
	_pend_x.append(x)
	_pend_y.append(y)
	_pend_g.append(glyphs)
	_pend_e.append(element)
	_pend_gen.append(gen)


## **Only the count at the start is iterated.** Look at ones deferred again this tick within the same tick and
##  `_resume` immediately defers them again with a budget of 0, so **the frame stops entirely** (it freezes with no error).
func _drain_pending(grid: CellGrid) -> void:
	var n := _pend_x.size()
	if n == 0:
		return
	for k in n:
		_resume(grid, _pend_x[k], _pend_y[k], _pend_g[k], _pend_e[k], _pend_gen[k])
	# Drop the first n. What is appended after them is what was just deferred again.
	# `slice` makes a new array and **reassigns it to the member** — the opposite direction from the trap of
	#  passing it as an argument and writing to a CoW copy (`_px` comment above), so it is safe.
	_pend_x = _pend_x.slice(n)
	_pend_y = _pend_y.slice(n)
	_pend_g = _pend_g.slice(n)
	_pend_e = _pend_e.slice(n)
	_pend_gen = _pend_gen.slice(n)


## **It carries the generation and not the radius.** The radius is a sim-table value (`SIM_SIZES.rd`) and
##  presentation has no use for it — flash size comes from the screen table (`FX_SIZES.flash_px`). Sending a value
##  nobody uses makes it a false knob.
## What keeps the two tables from diverging is **not stuffing the radius into the notice** but `net_tables`
##  measuring both tables' length and monotonicity **together**.
func _notify_blast(x: int, y: int, element: int, gen: int) -> void:
	_fx_x.append(x)
	_fx_y.append(y)
	_fx_e.append(element)
	_fx_g.append(gen)


## Cell number -> the fixed point at **the middle** of that cell. Put the impact point at a cell corner and the
##  span comes up half a cell short.
func _cell_center_fp(c: int) -> int:
	return (c << FP_SHIFT) + FP_HALF


func _notify_seg(x0: int, y0: int, x1: int, y1: int) -> void:
	_seg_x0.append(x0)
	_seg_y0.append(y0)
	_seg_x1.append(x1)
	_seg_y1.append(y1)


## **Both notices are cleared in one place.** Clear them separately and the day comes when only one is cleared, and
##  then that notice **lives forever** — the same flash keeps replaying, or a bolt long gone keeps hitting.
func _clear_notices() -> void:
	_fx_x.clear()
	_fx_y.clear()
	_fx_e.clear()
	_fx_g.clear()
	_seg_x0.clear()
	_seg_y0.clear()
	_seg_x1.clear()
	_seg_y1.clear()


## Pulls the last slot over to overwrite. **Indices shuffle** — see the `_id` comment above.
func _remove(i: int) -> void:
	var last := _count - 1
	if i != last:
		_px[i] = _px[last]
		_py[i] = _py[last]
		_vx[i] = _vx[last]
		_vy[i] = _vy[last]
		_prev_px[i] = _prev_px[last]
		_prev_py[i] = _prev_py[last]
		_glyphs[i] = _glyphs[last]
		_element[i] = _element[last]
		_age[i] = _age[last]
		_gen[i] = _gen[last]
		_id[i] = _id[last]
	_count = last


## Integer square root (Newton). **These few lines replace trig functions, `sqrt` and angle tables entirely.**
##  It runs once at launch and never in flight.
## Overflow headroom: the maximum input comes from the aim cap — `2 x AIM_MAX^2 << 16` ~= 1.4e14, overwhelmingly
##  inside int64 (9.2e18). **Raise `AIM_MAX` and redo this calculation.**
func _isqrt(n: int) -> int:
	if n <= 0:
		return 0
	var x := n
	var y := (x + 1) >> 1
	while y < x:
		x = y
		y = (x + n / x) >> 1
	return x


# =================================================================
#  Queries — all read-only (render · nets)
# =================================================================
# The arrays below are **not copies but live views.** Write to a returned array and the sim actually changes.
#  **Do not write to them** — the language does not stop you.
# The array length is always `MAX_PROJECTILES`. **Only the first `active_count()` are alive**, and past that are
#  last tick's corpses. Iterate by length and you draw ghosts.

func active_count() -> int:
	return _count


func get_px() -> PackedInt32Array:
	return _px


func get_py() -> PackedInt32Array:
	return _py


func get_prev_px() -> PackedInt32Array:
	return _prev_px


func get_prev_py() -> PackedInt32Array:
	return _prev_py


func get_vx() -> PackedInt32Array:
	return _vx


func get_vy() -> PackedInt32Array:
	return _vy


func get_element() -> PackedByteArray:
	return _element


func get_glyphs() -> PackedInt32Array:
	return _glyphs


## The spread generation. The renderer derives head size and trail length from it — the sim axis growing while
##  the screen doesn't follow is how v1 died.
func get_gen() -> PackedByteArray:
	return _gen


## The only safe key the renderer can pair trails by. Slot indices shuffle every tick.
func get_id() -> PackedInt32Array:
	return _id


# --- blasts that went off this tick ------------------------------
# **The only notice presentation gets.** The shell reads it **immediately after** `step()` and hands it to `blast_fx`.
#  The next `step()` clears it — read it two ticks later and it is an empty array.
# There is no path for this value back into the sim. It is screen-side, so differing per client doesn't split the world.

func blast_count() -> int:
	return _fx_x.size()


func get_blast_x() -> PackedInt32Array:
	return _fx_x


func get_blast_y() -> PackedInt32Array:
	return _fx_y


func get_blast_element() -> PackedByteArray:
	return _fx_e


func get_blast_gen() -> PackedByteArray:
	return _fx_g


# --- spans a bolt crossed this tick ------------------------------
# **The only notice the actor's "was I hit" test reads.** Same lifetime as the blast notice above —
#  the next `step()` clears it. The coordinates are **cell fixed point**; converting to px is the actor's job.

func seg_count() -> int:
	return _seg_x0.size()


func get_seg_x0() -> PackedInt32Array:
	return _seg_x0


func get_seg_y0() -> PackedInt32Array:
	return _seg_y0


func get_seg_x1() -> PackedInt32Array:
	return _seg_x1


func get_seg_y1() -> PackedInt32Array:
	return _seg_y1


## The number of pipelines pushed to the next tick because the budget ran out. Where the nets and the HUD measure
##  **that nothing was discarded.**
func pending_count() -> int:
	return _pend_x.size()
