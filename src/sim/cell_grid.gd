extends RefCounted
## The cell grid sim core. **A pure object — it knows nothing of the scene tree.**
##
## Being `RefCounted` rather than `Node` is this file's most important property.
##  It **never** touches `Input`, `Time`, `randi()`, `get_viewport()` or the scene tree.
##  => The server can run N of them headless, and nets run with no scene.
##
## **There are three doors that change the grid** — `apply(cmd)`, plus the direct doors `ignite` and
##  `set_water` for nets and the stage.
##  **This used to say "there is one door, `apply`", and that became false.** The stage's F key
##   actually calls `set_water` directly. **A false justification is worse than none** — the next person
##   reads "just look at the commands" and never looks at the other two.
##  => **Only `apply` goes to multiplayer; the other two are shell and net doors that won't survive into the real game.**
##   That distinction is what "one door" was protecting, and **direct writes still live only inside this file.**
##
## **Chunk sleep exists** (see the "chunk sleep" section). **Fire is still independent of chunks** —
##  it is a burn-slot list, so it burns even with the grid fully asleep (GDD, "state runs on burn-slot lists"). Leave it alone.
##
## == The traversal-order contract needed for water ==================
##  v1 bought it expensively and **the v1 file was deleted in stage 7.** So it is inlined here —
##  "fetch it from the deleted file" is a reference with nowhere to go.
##  The full text is in `git show e19e2a0:src/world/cells/cell_grid.gd` (the `_sweep` comment).
##
##  **It is the premise of a single-buffer water sim.** Double buffering means copying the whole grid
##  every tick, which collides head-on with "only the active region runs". => Instead, **traversal order**
##  eliminates double movement.
##
##  One invariant: **every destination a cell can move to must be a place already passed this tick, or one not visited at all.**
##    · Bands (chunk rows) **bottom -> top**    => y+1 was always passed first
##    · Rows within a band **bottom -> top**    => y+1 comes first within a band too
##    · Columns within a row **opposite the preferred direction `dir`** => the destination column for a `dir` slide comes first
##
##  **Within a band it goes "row -> chunk", not "chunk -> row".** With chunks on the outside,
##   **diagonal downward movement breaks at chunk column boundaries** — the neighboring chunk in the same
##   band hasn't run yet, so water falling there moves again in the same tick.
##  **The line that used to be here, "the cost is only 16 -> 256 flag checks per band", was for the v1 grid
##   and is false now.** v1 had 16 chunks per band and **there are now 256**, giving `256 x 16 = 4,096` per band —
##   fully asleep that is **6,016us/tick = 12% of budget** (measured).
##   => That is why `_band_awake` exists. **It is not an optimization but the value that makes this contract affordable.**
##  `dir` flips every tick, so **there is no left-right bias.** v1 had a net measuring that —
##   whoever brings water here must bring that net too (there is nothing to measure yet, so there is none).
## ===================================================================

const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")

# --- grid numbers ---------------------------------------------------
## The viewport is 1920x1080px with 4px cells, so **480x270 cells are visible.**
##  Making the grid larger is margin, and **the stage must sit within the visible edge** (`stage.gd` MAP comment).
## Doubled in the 32px switch (was 256x144). **Cells are still 4px** — what changed is the viewport.
## **Enlarged again to hold the user's drawn "stage 1" (312x126 tiles)**
##  (was 512x288 cells = 64x36 tiles). W must be a power of two, so 312 tiles (2496 cells) doesn't fit as-is
##  and was **rounded up to 4096 cells (512 tiles)** — about 200 tiles of margin remain on the right.
##  If `terrain_baker.gd`'s painted region exceeds this capacity it doesn't clip silently, it barks here
##  (bake failure) — and it will come again if the map grows.
const W := 4096
const H := 1008

## `idx = (y << X_SHIFT) | x`. W being a power of two **removes the multiply** —
##  it is computed constantly in inner loops, so this is performance directly.
##  Change W and this must change too. `_init()` barks on a mismatch.
const X_SHIFT := 12
const X_MASK := W - 1
## **4,128,768 cells.** It became 28x larger when the map grew (was 147,456), and
##  four measurement comments depending on that value didn't follow, so they were **quietly false for a day**
##  (re-measured afterwards).
##  => **Whoever changes W or H must hunt for comments with numbers like "147,456" baked in,
##   not for places reading this constant.** Code derives; comments don't follow.
##
## **The first value whoever builds water must know** — one GDScript sweep of this grid is
##  **62,676us** (measured, headless). The 20Hz tick budget is 50,000us, so **one sweep is 125% of budget.**
##  => **Water is impossible in principle without chunk sleep.** "Build it and optimize later" doesn't work here.
const CELL_COUNT := W * H  # 4,128,768

# --- chunk sleep ----------------------------------------------------
## **Split the grid into pieces and run only the pieces where something moved this tick.**
##  The 62,676us just above is the entire reason for this axis — **not an optimization but a premise.**
##
## **The knob (`CHUNK_CELLS`) lives in `sim_tuning`; all three here are derived.**
##  Not dividing evenly by 16 makes edge cells index out-of-range chunks — `_init()` barks.
const CHUNK_W := W / Tuning.CHUNK_CELLS      # 256
const CHUNK_H := H / Tuning.CHUNK_CELLS      # 63  <- band count
const CHUNK_COUNT := CHUNK_W * CHUNK_H       # 16,128

# --- commands — the only door that changes the grid -----------------
enum { CMD_FILL = 0, CMD_RESET = 1, CMD_BLAST = 2, CMD_IGNITE = 3, CMD_CARVE = 4, CMD_WATER = 5 }

# --- state ----------------------------------------------------------
var _mat := PackedByteArray()   # material id
var _flag := PackedByteArray()  # state bits (low 4 only)
var _aux := PackedByteArray()   # meaning is in `cell_materials.gd`'s `_aux` section

## Flat tables baked at boot — inner loops only index these.
var _behavior := PackedByteArray()
var _indestructible := PackedByteArray()
var _fuel := PackedByteArray()

## **Fire's burn-slot list — the indices of currently burning cells.** It does not sweep the grid.
##  This is the GDD's "state runs on burn-slot lists", and being **independent of chunk sleep**,
##  fire burns even with the grid asleep. v1's charge front had the same structure and was proven.
##
## **Kept as a member and pushed to here directly.** Passing a `PackedInt32Array` as an argument makes a
##  CoW copy and `append` **evaporates with no error** (where v1's `_charge_next` got burned).
## In v1, lightning not going out was caused not by TTL but by **water's ping-pong bug** (moving water
##  re-registered into the front every tick). **Fire doesn't move, so it can't have that problem.**
var _burning := PackedInt32Array()

## Cell -> its position within `_burning`. -1 means not burning. **The single source for front membership**
##  (`_flag`'s BURNING bit is a **mirror** the shader reads, and the two always move together).
## Without it, removing an erased cell from the front needs a **linear search**, and one blast erases
##  hundreds of cells, making it O(cells x front length). 590KB turns that into O(1).
var _burn_slot := PackedInt32Array()

## **`_awake` = chunks running this tick. `_dirty` = chunks running next tick.**
##
## **They cannot be one array.** A mark made mid-traversal entering this tick's sweep moves the same water
##  twice in one tick — the traversal-order contract at the head of this file exists to prevent exactly that.
## Swapping the two is `_chunk_flip()`, and **that is the start of a tick** (see that function's comment).
var _awake := PackedByteArray()
var _dirty := PackedByteArray()

## **Awake chunk count per band (chunk row). Not an optimization but a premise.**
##  The traversal contract is "row -> chunk within a band", so one band checks flags `256 x 16 = 4,096` times.
##
## **Measured — with the real `_water_step`** (headless, 2000 `step()` calls x 2 on a sleeping grid):
##
##      with band summary (now)  **5.25us/tick**  = 0.01% of budget (50,000us)
##      without band summary     **8,114us/tick** = **16%** of budget       <- 1,546x
##
##  The plan's "6,016us / 12%" was from **spec's proxy implementation**; the real code is **worse.**
##  The 5.25us includes `_chunk_flip` (3.7us alone, verify-run measured) — the band sweep itself is ~1.5us.
##
## **Without it the grid still runs correctly — it just gets slower, so nobody barks.** That is why this
##  value can vanish quietly, and why the net counts `_awake` directly and compares against it.
## **And that comparison catches only "diverged", never "vanished entirely"** — delete both and it's green.
##  => **A timing-based check goes into stage 3** (design, "nets").
var _band_awake := PackedInt32Array()
var _band_dirty := PackedInt32Array()

var _tick := 0

## Cells actually written since the last read. **The single source for "must the screen be re-uploaded".**
##  With `_write_cell` as the one door changing the grid, counting here is exact.
## A separate latch in the shell makes two copies of the rule, and **changes not going through the command
##  queue** (blasts are called directly by the projectile sim) silently miss that latch — then holes don't appear on screen.
var _changed := 0


func _init() -> void:
	_mat.resize(CELL_COUNT)
	_flag.resize(CELL_COUNT)
	_aux.resize(CELL_COUNT)
	_burn_slot.resize(CELL_COUNT)
	_burn_slot.fill(-1)
	_awake.resize(CHUNK_COUNT)
	_dirty.resize(CHUNK_COUNT)
	_band_awake.resize(CHUNK_H)
	_band_dirty.resize(CHUNK_H)
	_behavior = Mat.bake_behavior()
	_fuel = Mat.bake_fuel()
	_indestructible = Mat.bake_indestructible()
	# A place that goes wrong silently, so it barks at boot — with indexing wholly wrong,
	# the symptom is only "the grid looks strange".
	if (1 << X_SHIFT) != W:
		push_error("CellGrid: X_SHIFT(%d) does not match W(%d)" % [X_SHIFT, W])
	# Same place, same reason. Not dividing evenly truncates `CHUNK_W`/`CHUNK_H` and edge cells
	#  **index out-of-range chunks** — the symptom is an engine "Index out of bounds" every tick, a silent death.
	if W % Tuning.CHUNK_CELLS != 0 or H % Tuning.CHUNK_CELLS != 0:
		push_error("CellGrid: grid %dx%d does not divide evenly by chunk %d" % [W, H, Tuning.CHUNK_CELLS])


# ====================================================================
#  tick
# ====================================================================

## Advance one tick.
## **It does not return a worked-cell count.** "How many cells are burning" is answered by `burning_count()`,
##  and that value **stays correct after this tick ends.** Returned instead, the shell would hold it, and
##  since tick order is `grid.step()` -> `spell.step()`, **fire lit by a blast wouldn't be in that value** —
##  measured: the HUD printed 0 on the blast tick and 104 on the next (one tick late).
func step() -> void:
	_tick += 1
	# **This is the start of the tick, not the end** — the reason is in `_chunk_flip`'s comment below.
	_chunk_flip()
	# **Water before fire.** A cell burned to EMPTY receives water **the next tick.**
	#  Receiving it the same tick would mean reversing the order, and then "does fire catch on water created
	#  this tick" depends on ordering. **One tick late reads more easily, and at 20Hz it's 50ms — invisible on screen.**
	_water_tick()
	_burn()


# ====================================================================
#  chunk sleep
# ====================================================================

## Swap in next tick's chunks as this tick's.
##
## **It must be the start of the tick.** At the end, changes arriving from **outside** `step()`
##  **wait one more tick** — tick N's sweep uses the awake buffer swapped in at the end of tick N-1, but
##  a blast calls the grid inside `spell.step()`, which comes **after** `grid.step()` in `world_step` order,
##  and has therefore already passed that flip.
##  => "I breached the bowl and it doesn't leak next tick", **with no error at all.**
##
## **The design doc wrote this as "dirty is cleared on the spot", which this implementation doesn't do** —
##  handing the buffer over only delays, never loses. **The conclusion is the same, and "delayed" is scarier**:
##  losing it eventually shows, being one tick late never does.
## **A net measures this placement — with fire, not water.** `net_water`'s `_flip_is_at_tick_start`.
##  **"Only water moves mid-tick, so stage 1 can't measure it" was wrong** (the implementation wrote that
##   and verification overturned it): `_burn()` calls `_write_cell` **inside** `step()` on a burned-out cell
##   and that goes through `_touch`. => **Not awake on the tick it burned out and awake one tick later**
##   is the evidence the flip is at the front; moving it to the back splits it on the spot (confirmed by measurement).
##
## **Hand over the buffer and take a new one.** `_awake = _dirty` followed by `_dirty.fill(0)` produces a
##  CoW copy anyway, while the code reads as "two names see one array" and invites misreading.
##  => Allocate fresh and fill with 0 explicitly (a 16,128-byte memset).
##
## **Measured: a sleeping grid's `step()` is 3.7us/tick = 0.0074% of budget (50,000us)**
##  (verify-run measured with the real code — the grounds for "native, so negligible" that used to be here).
## **This is the flip's cost, not the sweep's.** Don't put it beside the plan's "with band summary -> 1us" —
##  that is `_water_step`'s band sweep, and **in stage 2 the two add up.**
func _chunk_flip() -> void:
	_awake = _dirty
	_band_awake = _band_dirty
	_dirty = PackedByteArray()
	_dirty.resize(CHUNK_COUNT)
	_dirty.fill(0)
	_band_dirty = PackedInt32Array()
	_band_dirty.resize(CHUNK_H)
	_band_dirty.fill(0)


## Mark the chunk holding one cell as **running next tick**.
##
## **Every door that changes the grid must pass through here.** Skip it and water there doesn't move,
##  which shows up only as **an "invisible wall"** on screen — with no error at all.
## **There are two call sites** — `_write_cell` and `_write_water`.
##  `_fill_rect`, `_disc(destroy)` and burned-out clearing all go through the former; every water movement through the latter.
##  **This used to say "there is only one"** — water arriving made it false, and that sentence was itself
##   the grounds for "there is nowhere to miss". **False grounds make the conclusion untrustworthy too.**
## **`_ignite_cell` does not call it.** It touches only `_flag` and `_aux` without changing the material, and
##  its ignition condition of fuel > 0 means it **cannot reach a water cell (fuel 0) in principle.**
##  Fire is a burn-slot list, independent of chunks.
##
## **Marking only its own chunk raises an "invisible wall" at chunk boundaries.** verify-read2
##  **reproduced it in the original code** (no mutation):
##
##      water at y=335 (band 20) · below at y=336 (band 21) is stone => asleep in 3 ticks
##      carve only directly below => **10 ticks later the water still floats at y=335**
##
##  Only the carved cell's chunk wakes and **the band holding the water stays asleep**, so the sweep skips it entirely.
##   0 errors, and on screen only "water floating in mid-air". **Blasts, carving and burned-out wood all take this path**
##   (when the water column's bottom y is a multiple of 16 minus 1 — roughly 1 in 16).
##
## => **Also mark the chunks in "directions water could flow into this cell from".**
## **It does not mark all 8 neighbors.** One awake band costs 128us and that is **independent of how many
##  chunks that band holds** (verify-run measured) — waking widely grows the band count and that term with it.
##  => Below and diagonals are not marked. Water comes from neither.
## **Left and right are woken too — because stage 3's `_water_step` began moving to `(x±1, y)`.**
##  verify-run confirmed "there is no diagonal path" over 900 ticks in stage 2, but **that conclusion belongs
##   to the down-only era and is void the moment left/right is added.** And **column boundaries are hit far
##   more often than row boundaries.**
## **Still not 8 neighbors.** Below and diagonals are not marked — water comes from **neither below nor diagonally.**
##  Measured (verify-run, stage 2): the price of choosing narrowly is **+1.7%** on the band term for falling water,
##  and **delta 0** for contiguous terrain fills (the band above is already awake).
func _touch(i: int) -> void:
	_touch_chunk_of(i)
	var cc := Tuning.CHUNK_CELLS
	var x := i & X_MASK
	# **Only cells on a boundary mark neighbors.** Interior cells share a chunk with their neighbors and
	#  are already marked — without this filter, one `_fill_rect` calls `_touch_chunk_of` four times as often.
	if (i >> X_SHIFT) % cc == 0 and i >= W:
		_touch_chunk_of(i - W)
	if x % cc == 0 and x > 0:
		_touch_chunk_of(i - 1)
	elif x % cc == cc - 1 and x < W - 1:
		_touch_chunk_of(i + 1)


## Mark the one chunk holding a cell index as dirty.
func _touch_chunk_of(i: int) -> void:
	var band := (i >> X_SHIFT) / Tuning.CHUNK_CELLS
	_touch_chunk(band * CHUNK_W + ((i & X_MASK) / Tuning.CHUNK_CELLS), band)


## Mark by chunk index directly. `band` is an argument because **the caller already knows it** —
##  dividing again here adds a division to an inner loop.
func _touch_chunk(c: int, band: int) -> void:
	# The band summary is maintained **incrementally only** — without deduplicating here, marking the same
	#  chunk repeatedly inflates the summary, and then the sweep reads a sleeping band as awake
	#  (it only gets slower; it doesn't bark).
	if _dirty[c] != 0:
		return
	_dirty[c] = 1
	_band_dirty[band] += 1


# ====================================================================
#  water
# ====================================================================

## **The only door water uses to touch the grid. Using `_write_cell` evaporates the amount on the spot** —
##  that function zeroes `_flag` and `_aux` together and **the amount lives in `_aux`.** Errors: zero.
##
## **The reverse direction is still `_write_cell`.** A blast erasing water is not setting the amount to 0
##  but **emptying the cell wholesale** — that is the boundary between the two doors.
##
## **The caller guarantees "write only over EMPTY or WATER" — in four places.**
##  `set_water` (explicit guard) · `_water_disc` (explicit guard) · `_water_fall` (checks the destination material) ·
##  `_water_share` (checks the neighbor material). **Only two used to be listed here.**
##  **A short list is itself the danger** — this function doesn't touch the front (`_burning`), so writing
##   over a burning cell leaves **a ghost claiming membership**, and then `_burn` **eats the water amount as fuel**
##   (measured 255 -> 250).
##  => **Missing any one of the four breaches it.** `unburnable_in_front_count()` is the instrument measuring all four at once.
## **The amount's range is also the caller's** — this is an inner loop, and checking once at the command
##  boundary is this file's idiom (see the `_valid_mat` comment). Overflow gets silently truncated by `PackedByteArray`.
## **The shallow bit is updated here — at the very place the amount is written.**
##  Touch the two separately and they diverge, and **the diverged side shows only on screen**
##  (the sim sees only the amount, the shader only the bit).
func _write_water(i: int, amount: int) -> void:
	if amount <= 0:
		_mat[i] = Mat.EMPTY
		_aux[i] = 0
		# **Clearing must lower the bit too.** Otherwise an empty cell keeps the shallow bit, and
		#  the next time that cell becomes water it **starts with amount and bit already mismatched.**
		_flag[i] &= ~Mat.FLAG_SHALLOW
	else:
		_mat[i] = Mat.WATER
		_aux[i] = amount
		if amount <= Tuning.WATER_WET:
			_flag[i] |= Mat.FLAG_SHALLOW
		else:
			_flag[i] &= ~Mat.FLAG_SHALLOW
	# Not counting means water moves and **the screen isn't re-uploaded** (`_changed` is the single source for "redraw?").
	_changed += 1
	_touch(i)


## Wet an integer disc. **The water-side sibling of `_disc`, and the disc rule must match it** —
##  written separately, the day comes when one is a circle and the other a square (same reason as that function's comment).
##
## **It calls `_write_water`, not `_write_cell`** — the latter sets the amount to 0.
## **It fills rather than overwrites** (`maxi`). Overwriting a deeper cell with a shallow value makes
##  **the water rune reduce water**, which is not what "wet" means.
## Solids are skipped — turning stone into water is destruction's job, and the water rune doesn't touch terrain.
## Outside the grid is **clamped** (same as `_disc`).
func _water_disc(cx: int, cy: int, r: int, amount: int) -> void:
	var r2 := r * r
	var ax := maxi(0, cx - r)
	var bx := mini(W - 1, cx + r)
	var ay := maxi(0, cy - r)
	var by := mini(H - 1, cy + r)
	for y in range(ay, by + 1):
		var dy := y - cy
		var dy2 := dy * dy
		var row := y << X_SHIFT
		for x in range(ax, bx + 1):
			var dx := x - cx
			if dx * dx + dy2 > r2:
				continue
			var i := row | x
			# `_write_water`'s contract (only over EMPTY or WATER) is upheld here —
			#  writing over a burning cell leaves **a ghost claiming membership** in the front (same place as `set_water`).
			if _mat[i] != Mat.EMPTY and _mat[i] != Mat.WATER:
				continue
			_write_water(i, maxi(_aux[i], amount))


## **One tick of water — runs `_water_step` `WATER_SUBSTEPS` times.**
##  The knob for "water spreads slowly" (the user judged it on screen) is here.
##  **Using `TICK_DIVIDER` speeds up bolts and fire too** — why that isn't the axis is in that constant's comment.
##
## **There is no `_chunk_flip` between substeps. That is this arrangement's contract, and it has a price.**
##  `_awake` is set once at tick start and `_touch` mid-substep marks only `_dirty` =>
##
##   · **Chunks awake at tick start run all N times** — which is why pooled water lies flat N times faster
##     (the surface band's chunks stay awake every tick while moving)
##   · ~~The leading edge spreading into new chunks doesn't speed up~~ -> **Wrong. A thinly spreading edge is 3x too**
##     (verify-run measured: reaching +8/+16/+32/+64/+95 cells was 3.0x in every case).
##     **The reason is speed** — the edge moves at **0.21 cells/tick**, **76x slower** than a chunk side (16 cells),
##     so it **can never reach** the "one chunk per tick" limit in principle. The diffusion rule can't produce that speed.
##     **A dam break sending water across open air was not measured** — it could still bite there.
##   · **A fall crossing a band boundary skips that tick's remaining substeps** (if the band below isn't awake yet).
##     **Measured: only when `y % 16 == 15`, once every 16 cells = once every 6 ticks.**
##     => The fall is **2.67 cells/tick**, not 3x (losing 11% of the theoretical 3x).
##     On screen that is **"the fall stutters one frame every 0.3 seconds"** — not a malfunction.
##
##  **Flipping per substep would remove all three at the cost of breaking "the flip is at tick start"**
##   (`_chunk_flip`'s comment · `net_water._flip_is_at_tick_start` measures that placement).
##   => **That price was not paid.** What is wanted here is one thing: how fast pooled water lies flat.
##
## **The cap is cut once per tick, not per substep.**
##  => A tick's real work is **`MAX_CHUNKS_PER_TICK` x `WATER_SUBSTEPS` chunk-passes.**
##  **So the cap's effective value becomes one Nth.** The grounds table is in that constant's comment.
##   **The value was not lowered** (that is a screen judgment).
##  **Cutting per substep would instead make the effective cap N times larger** — the first cut already
##   shrinks `_awake`, so from the second on `count()` is under the cap and passes through. That is the opposite of a safety net.
func _water_tick() -> void:
	# **The dir used for cutting is the first substep's.** dir flips per substep so "traversal order" isn't
	#  a single thing, but cutting happens once per tick so its reference must be single.
	#  Derived only from `_tick`, so **determinism holds** — two clients cut the same chunks.
	_cap_awake_chunks(_water_dir(0))
	var sub := 0
	while sub < Tuning.WATER_SUBSTEPS:
		_water_step(_water_dir(sub))
		sub += 1


## **One water sweep.** Traversal order is **exactly the contract at the head of this file** — nothing was redefined.
##  Bands bottom->top · rows within a band bottom->top · **row -> chunk** · columns opposite dir.
##
## **The head's "destinations are already passed or not visited" holds only vertically.**
##  It does not hold horizontally, and **cannot be made to** — the reason is in `_water_spread`'s comment.
##  The head comment came from v1's **grain** model (sliding one direction per tick), while amount-based
##   left-right averaging is **diffusion**, a different property. **Reading only the head comment without
##   knowing that difference makes you believe "horizontal is one cell per tick too" — it is not.**
##
## **Why the `_band_awake` check is this loop's first line**: remove it and a sleeping grid goes
##  **5.25us -> 8,114us/tick = 16% of budget** (measured; table in `_band_awake`'s comment).
##
## **Measured — 78.0us per chunk of flowing water** (implementation · headless · 300 ticks ·
##  5,586 chunk-ticks awake · peak 114 chunks · water actually falling). **1.9x the plan's 41us (spec's proxy).**
##  **That was a down-only figure and therefore a lower bound.** After left/right was added, verify-run
##   measured a dam break at **273-290% of budget for the worst tick and 101.5% mean over 400 ticks** —
##   the grounds table is in `sim_tuning.MAX_CHUNKS_PER_TICK`.
##  **The value is not changed here.** What decides it is acceptance 7 (FPS).
func _water_step(dir: int) -> void:
	var cc := Tuning.CHUNK_CELLS
	var band := CHUNK_H - 1
	while band >= 0:
		if _band_awake[band] == 0:
			band -= 1
			continue
		var chunk_base := band * CHUNK_W
		var y := band * cc + cc - 1
		var y_top := band * cc
		while y >= y_top:
			var row := y << X_SHIFT
			# The grid's bottom row has nowhere to receive. Without this filter `_water_fall` reads past
			#  the grid, giving an engine "Index out of bounds" every tick — **not caught by assertions,
			#  only by the wrapper** (measured).
			var can_fall := y < H - 1
			# **Chunks also go opposite dir.** Reversing only the column order and not the chunk order
			#  leaves the destination cell unvisited at chunk boundaries, and that water moves again the same tick.
			var cx := (CHUNK_W - 1) if dir > 0 else 0
			while cx >= 0 and cx < CHUNK_W:
				if _awake[chunk_base + cx] != 0:
					var x := (cx * cc + cc - 1) if dir > 0 else (cx * cc)
					var n := cc
					while n > 0:
						var i := row | x
						# **The material check is the fast path** — a chunk with no water at all
						#  bounces entirely here (measured 12.5us/chunk, spec's proxy measurement).
						if _mat[i] == Mat.WATER:
							_water_cell(i, x, row, y, can_fall, dir)
						x -= dir
						n -= 1
				cx -= dir
			y -= 1
		band -= 1


## **The single source for dir.** `_water_step` and `_cap_awake_chunks` **must see the same value** —
##  if cutting order and traversal order diverge, "the cut chunk" and "the unvisited chunk" differ, which
##  shows up not as a determinism break but as **a chunk running twice in one tick.**
##  Writing the expression in two places means one day only one gets fixed.
## Derived from `_tick` — **no new state is held.** It flips to remove left-right bias.
##
## **It flips per substep, not per tick** — that is why `sub` is an argument.
##  Flipping per tick pushes **N times in the same direction** within a tick => the per-tick bias amplitude
##  is N times larger (it still cancels across two ticks, but **what appears on screen is each tick's state**).
##  Flipping per substep leaves the amplitude at **one substep's worth**, the same as N=1.
##  With odd N one side gets pushed once more per tick (`+,-,+` at 3), but **the next tick receives it as
##   `-,+,-` and cancels** — because `_tick` is part of the expression.
##
## **`sub` must be added in exactly this one place.** At `WATER_SUBSTEPS = 1`, `sub` is only 0 and
##  **the value is identical to the pre-constant expression (`_tick & 1`)** — the way back is one value.
func _water_dir(sub: int) -> int:
	return 1 if ((_tick + sub) & 1) == 0 else -1


## One cell: (1) hand down, (2) share what remains left and right.
func _water_cell(i: int, x: int, row: int, y: int, can_fall: bool, dir: int) -> void:
	var amount := _aux[i]
	if can_fall:
		amount = _water_fall(i, x, y, amount)
		if amount <= 0:
			return
	_water_spread(i, x, row, amount, dir)


## (1) Downward. Scans up to `Tuning.WATER_FALL_CELLS` (K) **consecutive empty cells** and moves the whole
## amount into the lowest empty one (`sim_tuning.WATER_FALL_CELLS` header — no per-cell velocity state).
## On hitting water or solid it stops there and handles it **by the current rules**, so stacking and blocking
## keep their meaning. It moves only **as much as the cell below can take.** Returns the remaining amount.
## `can_fall` (the caller's `y < H - 1`) already guarantees the condition, so it isn't rechecked here.
func _water_fall(i: int, x: int, y: int, amount: int) -> int:
	var last_empty_y := -1
	var k := 0
	while k < Tuning.WATER_FALL_CELLS:
		var ny := y + k + 1
		if ny >= H or _mat[(ny << X_SHIFT) | x] != Mat.EMPTY:
			break
		last_empty_y = ny
		k += 1
	if last_empty_y >= 0:
		# Found empty cells — move the whole amount to **the lowest of them.**
		# **Both calls are `_write_water`** — going through this door on only one side evaporates the amount
		#  on the other and the total quietly leaks.
		_write_water((last_empty_y << X_SHIFT) | x, amount)
		_write_water(i, 0)
		return 0

	# No consecutive empties (directly below is already water or solid) — the current 1-cell rule as-is.
	var below := ((y + 1) << X_SHIFT) | x
	var bm := _mat[below]
	# Hitting a solid does nothing — that is "stone holds water", and the remaining amount goes to (2).
	if bm != Mat.WATER:
		return amount
	var space := Tuning.WATER_MAX - _aux[below]
	if space <= 0:
		return amount
	# `mini`, not `min` — `src/sim/` forbids float global functions (`net_determinism`).
	var move := mini(amount, space)
	_write_water(below, _aux[below] + move)
	_write_water(i, amount - move)
	return amount - move


## (2) Share left and right. **The dir-side neighbor is checked first.**
##
## **The head's traversal contract does not hold here, and cannot be made to.**
##  The head says "destinations are already passed or not visited", but with columns going opposite dir,
##  `x + dir` was already passed while **`x - dir` was not.** => Water moving to `x - dir` can move again
##  this tick, so **horizontally it spreads several cells per tick** (255 -> 127 -> 63 … tapering off).
##
## **This is not a bug but a property of diffusion.** Amount-based averaging is a Gauss-Seidel sweep, and
##  in a single buffer a chain occurs in one direction **whatever order you use.** Restricting sharing to one
##  direction removes the chain but **halves the speed to equilibrium and invalidates the design's measured tick counts.**
## => **That is why dir flips every tick.** Removing bias is this axis's only device.
## **The head comment applies vertically only** — vertical goes bottom->top, so chaining is impossible in
##  principle (a net measures it).
##
## **Measured: horizontal reach is at most 5 cells in one tick** (the first tick, verify-run).
##  **So diagonal paths really do occur** — knowing only "one cell down per tick", water leaking diagonally
##   looks like a malfunction. It isn't. 1 cell vertical + 5 horizontal is this rule's shape.
##
## **If the difference is at or below `WATER_MIN_DIFF`, nothing moves — this is the heart of stopping.**
##  Without it an odd number never divides and ping-pongs by 1, so **the chunk never sleeps and chunk sleep
##  is void entirely.** That is where v1 died.
func _water_spread(i: int, x: int, row: int, amount: int, dir: int) -> void:
	amount = _water_share(i, x + dir, row, amount)
	if amount <= 0:
		return
	_water_share(i, x - dir, row, amount)


## Share with one neighbor toward the average. Returns the remaining amount.
func _water_share(i: int, nx: int, row: int, amount: int) -> int:
	if nx < 0 or nx >= W:
		return amount
	var j := row | nx
	var nm := _mat[j]
	# Solids don't receive. Only empty and water do — the same contract as `_write_water` writing only over those two.
	if nm != Mat.EMPTY and nm != Mat.WATER:
		return amount
	# An empty cell's `_aux` is 0. "Material is EMPTY with an amount left" is impossible in principle
	#  (both `_write_cell` and `_write_water` zero the amount when clearing).
	var other := _aux[j]
	var diff := amount - other
	if diff <= Tuning.WATER_MIN_DIFF:
		return amount
	# **The integer shift is safe here**: `diff` is always positive at this point, so the `DRAG_NUM` comment's
	#  "`>>` is asymmetric on negatives" trap doesn't apply.
	# It cannot overflow: `other + move = (amount + other) / 2 <= max(amount, other) <= WATER_MAX`.
	var move := diff >> 1
	_write_water(j, other + move)
	_write_water(i, amount - move)
	return amount - move


## **The per-tick cap — awake chunks over the cap are pushed to the next tick.**
##
## **The call site is `_water_tick`, and it is *outside* the substep loop** — the cap is chunks per tick,
##  not per substep. Placed inside, the first cut already shrinks `_awake` so the remaining substeps pass
##  `count()` freely, and **the effective cap becomes N times larger** (`_water_tick`'s comment).
##
## **The cut must happen *before* the band sweep.** Within a band it goes "row -> chunk", so
##  **one chunk's 16 rows are not a contiguous stretch of the traversal** — stopping "at the Nth" inside
##  the loop produces **a chunk with only half its rows visited.**
##  **What breaks is "physics", not "determinism".** This used to say "determinism breaks" and that was wrong —
##   the same code is wrong in the same order **identically**, so both clients are wrong **the same way.**
##   => Not desync but **water flowing only halfway inside a chunk**, and that shows only on screen.
##   **So a determinism net cannot catch it in principle** (see that function's comment in `net_water`).
##    Confirmed by actually implementing the forbidden approach (verify-run). **There is nowhere to catch it — this comment is all there is.**
## => Before the sweep, count in traversal order (bands descending -> columns opposite dir) and put the
##  excess back to sleep **for this tick only**. **The cutting order is itself state** — which is why `dir`
##  is read through the same door as `_water_step` (`_water_dir`). With substeps standing up it is no longer
##  "the same value" — it is the first substep's.
##
## **Cut chunks run next tick** — they are re-marked via `_touch_chunk`. **Nothing is discarded.**
##  Without re-marking, "water at the cap never moves again", which is a malfunction, not a safety net.
##
## **Under the cap it ends in one native `count()` (~2us).** The sweep is only paid when it is exceeded.
func _cap_awake_chunks(dir: int) -> void:
	if _awake.count(1) <= Tuning.MAX_CHUNKS_PER_TICK:
		return
	var kept := 0
	var band := CHUNK_H - 1
	while band >= 0:
		if _band_awake[band] > 0:
			var base := band * CHUNK_W
			var cx := (CHUNK_W - 1) if dir > 0 else 0
			while cx >= 0 and cx < CHUNK_W:
				var c := base + cx
				if _awake[c] != 0:
					if kept < Tuning.MAX_CHUNKS_PER_TICK:
						kept += 1
					else:
						_awake[c] = 0
						_band_awake[band] -= 1
						_touch_chunk(c, band)
				cx -= dir
		band -= 1


## **One tick of fire.** It doesn't sweep the grid; it walks the burn-slot list.
##
## **It iterates back to front.** Iterating forward with swap-remove skips the cell just pulled in.
##  And since spreading grows the list **at the back**, seeing only up to the starting length (`n`) is the
##  contract — fire lit this tick spreading again this tick would cross the grid in one tick.
## Termination: fuel always decreases every tick, at 0 the cell becomes EMPTY, and EMPTY has 0 fuel so
##  **it cannot catch again.** => Fire always goes out (acceptance 5).
func _burn() -> void:
	var n := _burning.size()
	if n == 0:
		return
	var spread := (_tick % Tuning.FIRE_SPREAD_TICKS) == 0
	var i := n - 1
	while i >= 0:
		var idx := _burning[i]
		var x := idx & X_MASK
		var y := idx >> X_SHIFT
		# **Water puts out fire — asked from the front's side.**
		#  Asking from the water side ("is there fire beside me") makes **every water cell read four neighbors
		#   every tick**, which wakes the entire still lake and voids "only the surface band is awake".
		#   The front is chunk-independent, so this direction is free.
		# **The material is rewritten** (`_mat[idx]` unchanged) — `_write_cell` handles `_unburn`, `_flag`,
		#  `_aux`, `_changed` and `_touch` **in one place.** Touching those by hand makes them diverge.
		#  Same idiom and same loop position as `_write_cell(idx, EMPTY)` for a burned-out cell, so the
		#   swap-remove trap is already covered by that comment.
		if _water_adjacent(x, y):
			_write_cell(idx, _mat[idx])
			i -= 1
			continue
		var fuel := _aux[idx] - Tuning.FIRE_BURN_PER_TICK
		if fuel <= 0:
			# A burned-out cell **becomes empty.** Leaving the material would leave no trace of fire on
			#  screen at all, erasing the ember-side evidence of "1 blast + 8 ember branches".
			# Removal from the front is done by `_write_cell` too (swap-remove changes slot `i` to a cell
			#  pulled from the back) — removing again here would skip that cell.
			_write_cell(idx, Mat.EMPTY)
			i -= 1
			continue
		_aux[idx] = fuel
		if spread:
			# **Four directions.** Opening diagonals leaks through 1-cell gaps and blurs "it stops at stone".
			_ignite_cell(x - 1, y)
			_ignite_cell(x + 1, y)
			_ignite_cell(x, y - 1)
			_ignite_cell(x, y + 1)
		i -= 1


## Is there water among the four neighbors. **Diagonals are not checked** — fire spreads in four directions,
##  so this must be the same axis.
##
## **It is "there is water beside it", not "this wood is wet".** The wood cell itself changes nothing.
##  `docs/design/water.md`'s **"does wet wood not burn" is still TBD** (the user deferred it as "a later problem") —
##   that question is **does wood the water passed through stay unburnable after drying**, i.e. does wood **remember** wetness.
##  **This function does not answer that question.** Drain the water here and the cell burns again immediately.
##   => Do not read this as "the TBD is resolved".
##
## **Shallow water cannot extinguish — it must exceed `WATER_WET`** (decided by the user).
##  **This function used to have no threshold.** That comment recorded the condition for its revival in advance
##   — **"when a thin drop putting out a large fire looks excessive on screen"** — and exactly that happened:
##   **one F press (797 cells) spread sideways and permanently fireproofed ~860 cells of forest.** Still growing at 200 seconds.
##   => It was **the product of three** — water isn't consumed, touched cells don't burn, and it keeps spreading —
##   and this is the middle term.
##
## **No new constant was created. It reuses `WATER_WET`** — to avoid inventing "a third knob that isn't there".
##  **That value is `FLAG_SHALLOW`'s boundary, so rule and screen share one line:**
##  **wet stains that read bright sky-blue can't extinguish; only dark navy real water can.**
##  => "Why can't this water put out fire" is **already drawn on screen.** Change the value and both move together.
## **It reads `_aux`, not the bit** — `_flag` is the mirror and the amount is the original (the same trap as in `_ignite_cell`).
##
## **The cost was not measured.** Both call sites already make 4 function calls (`_ignite_cell`) at the same
##  point, so the order of magnitude shouldn't change — but **that is a judgment from reading, not a measurement.**
func _water_adjacent(x: int, y: int) -> bool:
	var row := y << X_SHIFT
	if x > 0 and _deep_water(row | (x - 1)):
		return true
	if x < W - 1 and _deep_water(row | (x + 1)):
		return true
	if y > 0 and _deep_water((row - W) | x):
		return true
	if y < H - 1 and _deep_water((row + W) | x):
		return true
	return false


## Is this cell water **enough to extinguish.** Edge guards were already checked by the caller —
##  checking again here doubles `_water_adjacent`'s four lines, and that function is inside the front loop.
func _deep_water(i: int) -> bool:
	return _mat[i] == Mat.WATER and _aux[i] > Tuning.WATER_WET


## Ignite one cell. Returns true if it caught.
## **"Only where there is fuel" is these three lines** (GDD). Stone has 0 fuel and stops here, and
##  empty has 0 fuel too, so **fire cannot cross open air.**
func _ignite_cell(x: int, y: int) -> bool:
	if x < 0 or x >= W or y < 0 or y >= H:
		return false
	var i := (y << X_SHIFT) | x
	# Membership is read from the slot table — `_flag` is a mirror, and judging by only one of them
	#  puts the same cell into the front **twice** the day they diverge.
	if _burn_slot[i] >= 0:
		return false
	var fuel := _fuel[_mat[i]]
	if fuel <= 0:
		return false
	# A safety net. If this starts biting, look not at the value but at **how much wood was placed.**
	if _burning.size() >= Tuning.MAX_BURNING:
		return false
	# **It never catches beside wet ground in the first place. Extinguishing in `_burn` alone is not enough.**
	#  With only extinguishing: a neighbor's fire spreads and catches -> it goes out next tick -> the neighbor
	#   is still burning so it catches again. **Measured at 37 consecutive ticks** (measured with a net before this line went in).
	#   On screen that is **fire flickering at the waterside**, which reads as a malfunction, not a rule.
	#  **It is not "it never sleeps"** — it ends when the neighboring wood's fuel runs out, so it is **finite.**
	#   So "does it end and sleep" can't catch it; **you must watch that cell per tick** (that check in `net_water`).
	# **Why this check is last**: the three above are all O(1) comparisons and this reads four arrays —
	#  there is no reason to read neighbors for a cell that won't catch anyway.
	if _water_adjacent(x, y):
		return false
	_flag[i] |= Mat.FLAG_BURNING
	_aux[i] = fuel
	_burn_slot[i] = _burning.size()
	_burning.append(i)
	# The material is unchanged but **the screen changes** (the shader reads `_flag`). Without counting, fire doesn't appear.
	_changed += 1
	return true


# ====================================================================
#  commands
# ====================================================================

static func cmd_fill(x0: int, y0: int, x1: int, y1: int, mat: int) -> Dictionary:
	return {"kind": CMD_FILL, "x0": x0, "y0": y0, "x1": x1, "y1": y1, "mat": mat}


## The tick number returns to 0 too — it means "open a new world", so that is right.
static func cmd_reset() -> Dictionary:
	return {"kind": CMD_RESET}


## **Destroy + ignite.** v1's fill and residue don't exist here since there is no water.
##
## **`ignite_r` must exceed `rd`.** Destruction comes first, so inside `rd` becomes EMPTY = 0 fuel, and
##  with equal radii **it erases its own fuel first.** Fire cannot catch in principle while
##  no error is raised — `net_fire` measures that inequality as a contract.
## Why the arguments have no defaults: a call site that omits them silently becomes "a blast with no fire".
##
## **Being a command makes bandwidth free** — send four integers and every client erases the same circle and
##  burns the same ring. However large the blast, network cost doesn't grow (GDD, multiplayer).
static func cmd_blast(x: int, y: int, rd: int, ignite_r: int) -> Dictionary:
	return {"kind": CMD_BLAST, "x": x, "y": y, "rd": rd, "ignite_r": ignite_r}


## **Ignite only.** It breaks not one cell of terrain — the door the rune trace passes through.
##  `cmd_blast(x, y, 0, r)` would do the same thing but **it gets its own name.**
##   "A blast with radius 0" lies to the reader, and command names persist in logs and on the network.
static func cmd_ignite(x: int, y: int, r: int) -> Dictionary:
	return {"kind": CMD_IGNITE, "x": x, "y": y, "r": r}


## **Carve only.** It lights not one cell — the door every impact passes through (step (1) of `spell_sim._impact`).
##  **The exact mirror of `cmd_ignite` above, named separately for the same reason.**
##   `cmd_blast(x, y, r, 0)` would do the same thing, but "a blast with ignition radius 0" lies to the reader.
##   And there are three more prices — (a) it breaks head-on the `ignite_r > rd` contract `cmd_blast` pins,
##   with **nobody barking at runtime** (the net measures the **table**, not **calls**),
##   (b) the `cmd_blast` <-> `spell_sim._notify_blast` pairing breaks, (c) every impact leaves a `CMD_BLAST`
##   in logs and on the network.
## **Side effects don't come in two copies** — `_disc(…, true)` -> `_write_cell` is shared.
static func cmd_carve(x: int, y: int, r: int) -> Dictionary:
	return {"kind": CMD_CARVE, "x": x, "y": y, "r": r}


## **Wet only.** It breaks no terrain and lights no fire — the door the water rune's trace passes through.
##
## **The water-side mirror of `cmd_ignite`, and the third trace alongside `cmd_carve`.**
##  **It cannot be made with `_disc`** — that function calls `_write_cell`, which zeroes `_aux`.
##   Water going through that door **evaporates the amount on the spot** (material WATER, amount 0). Errors: zero.
##   => `_water_disc()` exists separately and calls `_write_water`.
##
## **The command carries the amount.** Sending only a radius and letting the grid decide the amount would
##  split that rule between `sim_tuning` and `cell_grid` the day different power tiers make different water.
## **Being a command makes bandwidth free** — four integers and every client wets the same disc (same as `cmd_blast`).
static func cmd_water(x: int, y: int, r: int, amount: int) -> Dictionary:
	return {"kind": CMD_WATER, "x": x, "y": y, "r": r, "amount": amount}


func apply(cmd: Dictionary) -> void:
	match int(cmd.get("kind", -1)):
		CMD_FILL:
			_fill_rect(int(cmd["x0"]), int(cmd["y0"]), int(cmd["x1"]), int(cmd["y1"]),
				int(cmd["mat"]))
		CMD_RESET:
			_reset()
		CMD_BLAST:
			_blast(int(cmd["x"]), int(cmd["y"]), int(cmd["rd"]), int(cmd["ignite_r"]))
		CMD_IGNITE:
			var r := int(cmd["r"])
			if r > 0:
				_disc(int(cmd["x"]), int(cmd["y"]), r, false)
		CMD_CARVE:
			var cr := int(cmd["r"])
			if cr > 0:
				_disc(int(cmd["x"]), int(cmd["y"]), cr, true)
		CMD_WATER:
			var wr := int(cmd["r"])
			var amount := int(cmd["amount"])
			# The range check happens **once at the command boundary** (same idiom as `_valid_mat`) —
			#  checking per cell inside the disc loop is itself the cost, and once here is enough.
			if amount < 0 or amount > Tuning.WATER_MAX:
				push_error("CellGrid.cmd_water: amount %d is outside 0..%d" % [amount, Tuning.WATER_MAX])
			elif wr > 0 and amount > 0:
				_water_disc(int(cmd["x"]), int(cmd["y"]), wr, amount)
		_:
			push_error("CellGrid.apply: unknown command %s" % cmd)


## `apply()` is **the door a client sends to the server** in multiplayer. Left unvalidated, one out-of-range
##  id makes `_behavior[mat]` throw an engine **"Index out of bounds" every tick** — a silent death that
##  doesn't turn up in a `SCRIPT ERROR` grep. Past 255, `PackedByteArray` silently truncates to the low 8 bits
##  while the shader clamps and shows magenta => **sim and render break in different ways.**
## Checked once at the **command boundary**, not in inner loops — one fill runs `_write_cell` thousands of times.
func _valid_mat(mat: int) -> bool:
	# **Water cannot come through here.** `cmd_fill` goes through `_write_cell`, which zeroes `_aux` =>
	#  it would create **a cell whose material is WATER with amount 0**, a state `cell_materials.gd`'s
	#  `_aux` section pins as "impossible in principle".
	#  Measured (verify-read2): 55 cells placed with `cmd_fill(…, WATER)` were **0 after 20 ticks.**
	#   On the first sweep `_water_fall` hands amount 0 downward and makes the cell EMPTY — **it evaporates silently.**
	# **The amount is not invented here.** `cmd_fill` has no amount field, and putting 255 in would be
	#  **inventing a rule that doesn't exist** ("a fill is full water"). Water's doors carry the amount
	#  (`set_water` · stage 5's `CMD_WATER`) => here it **barks and discards.**
	# The day water goes on the map, terrain baking hits this line. **That is the right signal** — the water command stands up then.
	if mat == Mat.WATER:
		push_error("CellGrid: water cannot be placed with cmd_fill - with no amount it evaporates on the spot")
		return false
	if mat >= 0 and mat < Mat.SLOT_COUNT and Mat.DEFS.has(mat):
		return true
	push_error("CellGrid: unknown material id %d - discarding the command" % mat)
	return false


func _fill_rect(x0: int, y0: int, x1: int, y1: int, mat: int) -> void:
	if not _valid_mat(mat):
		return
	var ax := maxi(0, mini(x0, x1))
	var bx := mini(W - 1, maxi(x0, x1))
	var ay := maxi(0, mini(y0, y1))
	var by := mini(H - 1, maxi(y0, y1))
	for y in range(ay, by + 1):
		var row := y << X_SHIFT
		for x in range(ax, bx + 1):
			_write_cell(row | x, mat)


## **An integer disc.** `dx*dx + dy*dy <= rd*rd` — `sqrt` never appears.
##  That is how every client erases **the same cell set.** One cell off changes the terrain, and
##  from then on the two clients live in permanently different worlds.
##
## Outside the grid is **clamped** (not cut, not discarded) — a blast at a wall's corner
##  "carving only half" is the right picture, and without the range check `_mat[i]` throws an engine error per cell.
## rd <= 0 quietly does nothing — "a blast with radius 0" isn't valid input but isn't worth barking about
##  (with a spread floor added, 0 can actually occur).
func _blast(cx: int, cy: int, rd: int, ignite_r: int) -> void:
	# **Destruction first.** Reversed, it erases the fire it just lit.
	if rd > 0:
		_disc(cx, cy, rd, true)
	if ignite_r > 0:
		_disc(cx, cy, ignite_r, false)


## Sweep an integer disc. `destroy` erases; otherwise it ignites.
## The point is that both passes share one sweep — written separately, the day comes when one is a circle and the other a square.
func _disc(cx: int, cy: int, rd: int, destroy: bool) -> void:
	var r2 := rd * rd
	var ax := maxi(0, cx - rd)
	var bx := mini(W - 1, cx + rd)
	var ay := maxi(0, cy - rd)
	var by := mini(H - 1, cy + rd)
	for y in range(ay, by + 1):
		var dy := y - cy
		var dy2 := dy * dy
		var row := y << X_SHIFT
		for x in range(ax, bx + 1):
			var dx := x - cx
			if dx * dx + dy2 > r2:
				continue
			if destroy:
				# Indestructible materials (`Mat.BEDROCK` etc.) are filtered here — `_write_cell` is never called.
				if _indestructible[_mat[row | x]] == 1:
					continue
				_write_cell(row | x, Mat.EMPTY)
			else:
				_ignite_cell(x, y)


## Writing a material clears `_flag` and `_aux` too — otherwise filling burned ground with new wood makes it
##  "already burned-out wood" and fire won't catch. No error; only the rule goes wrong.
func _write_cell(i: int, mat: int) -> void:
	# **It removes from the front too.** Otherwise an erased cell's index stays in `_burning` as a ghost.
	#  It currently removes itself next tick (fuel is 0), but that self-healing **depends on "the erased place
	#  stays empty".** If water or terrain regeneration refills it with wood,
	#  (a) `_aux` being 0 makes **the new wood empty next tick** and (b) the duplicate guard passes so
	#  **the same cell enters the front twice.** => It's cheap (O(1) via the slot table), so block it now.
	# And `burning_count()` is the instrument — a value inflated 41% for even one tick is no floor to measure from (measured).
	_unburn(i)
	_mat[i] = mat
	_flag[i] = 0
	_aux[i] = 0
	_changed += 1
	# **The only place that wakes a chunk** (`_touch`'s comment). Water leaking from a bowl breached by a
	#  blast, and water flowing into burned-out ground, both hang entirely on this one line.
	_touch(i)


## Remove from the front. O(1) thanks to the slot table.
## The last cell is pulled in to overwrite, so **the order changes** — determinism holds (index arithmetic only).
func _unburn(i: int) -> void:
	var at := _burn_slot[i]
	if at < 0:
		return
	var last := _burning.size() - 1
	var moved := _burning[last]
	_burning[at] = moved
	_burn_slot[moved] = at
	_burning.resize(last)
	# **Sometimes the cell pulled in is itself** (`at == last`). That is why this line must be last —
	#  the line above revives `i` through `_burn_slot[moved]`.
	#  Measured: moving it earlier leaves 9 orphan cells right after a blast and 100 after a forest burns out,
	#   and those cells are blocked by the duplicate guard and **can never burn again.** `net_fire` measures it.
	_burn_slot[i] = -1


func _reset() -> void:
	_mat.fill(0)
	_flag.fill(0)
	_aux.fill(0)
	# The front is emptied too. Otherwise old fire sits on the new terrain's cell indices where there is
	#  no fuel, so **those cells become empty one tick later** — holes punched into the new stage.
	_burning.clear()
	_burn_slot.fill(-1)
	# Chunks are cleared directly too. `fill` doesn't go through `_write_cell`, so `_touch` never runs —
	#  **exactly the same trap as `_burning`**: the new stage is born holding the old dirty set.
	# Right after a reset everything is EMPTY so nothing can move in principle => **no reason to keep anything awake.**
	#  Terrain is laid by `cmd_fill` after the reset, and that fill wakes chunks itself via `_write_cell`.
	_awake.fill(0)
	_dirty.fill(0)
	_band_awake.fill(0)
	_band_dirty.fill(0)
	_tick = 0
	# `fill` doesn't go through `_write_cell`, so count directly here. Without it, the first frame after a
	# reset stays showing the old terrain (until the next blast).
	_changed += CELL_COUNT


# ====================================================================
#  queries — all read-only
# ====================================================================
# **`get_mat()` and `get_flag()` are live views, not copies.**
#  Trusting `PackedByteArray`'s CoW and writing "it's safe to modify outside" **is wrong with no error** —
#  in GDScript, `arr[0] = 9` on a returned array really does change the grid (measured in v1).
#  => **Do not write to arrays returned here.** The language doesn't stop you; only discipline does.

func get_mat() -> PackedByteArray:
	return _mat


func get_flag() -> PackedByteArray:
	return _flag


func get_tick() -> int:
	return _tick


## Cells changed since the last read. **Reading resets it to 0** — read twice and the second is 0.
##  The shell judges "re-upload the screen?" from this alone.
func consume_changed() -> int:
	var n := _changed
	_changed = 0
	return n


func mat_at(x: int, y: int) -> int:
	if x < 0 or x >= W or y < 0 or y >= H:
		return Mat.STONE  # outside the grid = solid
	return _mat[(y << X_SHIFT) | x]


func flag_at(x: int, y: int) -> int:
	if x < 0 or x >= W or y < 0 or y >= H:
		return 0
	return _flag[(y << X_SHIFT) | x]


func aux_at(x: int, y: int) -> int:
	if x < 0 or x >= W or y < 0 or y >= H:
		return 0
	return _aux[(y << X_SHIFT) | x]


## **The single source for "is it solid".** Both the character and projectiles call it —
##  each judging `mat_at(x,y) != EMPTY` themselves means one side doesn't follow when a material is added,
##  which shows only as "bolts pass through but the character is blocked".
## Outside the grid is solid (`mat_at`) — which is how neither the character nor bolts leave the grid.
func is_solid(x: int, y: int) -> bool:
	return _behavior[mat_at(x, y)] == Mat.BEHAVIOR_STATIC


## A native `count()`, but **588us per call** (measured, 4,128,768 cells).
## **This line used to say "~20us · 0.24% of budget", from when the grid was 28x smaller.**
##  The **HUD calls it twice per frame, so at 60Hz that is 70,600us/s = 7% of CPU.**
##  **This is where the intuition "native, therefore cheap" broke against grid size** — it scales directly with cells swept.
## **The place to fix is the caller, not here** (`stage.gd`'s HUD). If a count is needed, hold it
##  incrementally in `_write_cell`, or call it every N ticks instead of every frame. This function stays as the net and stage door.
func count_material(mat: int) -> int:
	return _mat.count(mat)


## Currently burning cells. Where the net measures **does it go out**, and where front leaks surface.
func burning_count() -> int:
	return _burning.size()


## **Cells claiming front membership. Must equal `burning_count()`.**
##
## **The reverse direction of the slot table, and the side that breaks is always this one.** The forward
##  direction (`_burn_slot[_burning[k]] == k`) falls out of sweeping `_burning` and rarely breaks. But
##  **a cell claiming membership while absent from the front** (an orphan) appears nowhere — it is blocked
##  by `_ignite_cell`'s duplicate guard and **can never burn again.** No error, nothing on screen. Measured:
##  moving `_unburn`'s last line earlier left 168 orphans after a forest burned out.
## **A net-only query** (same place as `ignite`). It sweeps the grid every call — do not call it in the game loop.
func claimed_slot_count() -> int:
	var n := 0
	for i in CELL_COUNT:
		if _burn_slot[i] >= 0:
			n += 1
	return n


## **Are unburnable materials sitting in the front. Must be 0.**
##
## **`claimed_slot_count()` and `burning_count()` cannot catch it in principle** — those two compare
##  **only against each other**, so a water cell claiming front membership leaves **both numbers identical.**
## What happens then (verify-read2 reproduced it by removing `set_water`'s guard):
##  a water cell sits with `FLAG_BURNING` and `_burn()` **eats the water amount as fuel** (255 -> 250 -> 245 …).
##  The water quietly dries up, and once dry the cell becomes EMPTY.
## => **The premise of stage 6 (water puts out fire).** That is where the two axes first meet on one cell.
##
## **No material name is hardcoded; it derives from the fuel table** — "0 fuel yet burning" is the invariant,
##  and that applies to stone and empty as much as to water. **A net-only query** (it sweeps the front).
func unburnable_in_front_count() -> int:
	var n := 0
	for k in _burning.size():
		if _fuel[_mat[_burning[k]]] <= 0:
			n += 1
	return n


## **The single source for "is it burning"** — same reason as `is_solid`.
##  The character (damage over time) and fuel queries both pass through it. Each using
##  `flag_at() & FLAG_BURNING` means one side doesn't follow the day the flag's meaning changes,
##  which shows only as "I'm standing in fire and it doesn't hurt".
## Outside the grid doesn't burn (`flag_at` returns 0).
func is_burning(x: int, y: int) -> bool:
	return (flag_at(x, y) & Mat.FLAG_BURNING) != 0


## Remaining fuel. Meaningless for a non-burning cell (`cell_materials.gd`'s `_aux` section).
func fuel_at(x: int, y: int) -> int:
	if not is_burning(x, y):
		return 0
	return aux_at(x, y)


## Ignite directly. **A net and stage door** — in-game ignition is done by `cmd_blast`'s `ignite_r`.
func ignite(x: int, y: int) -> bool:
	return _ignite_cell(x, y)


## Place water directly. **A net and stage door** — exactly the same place as `ignite`.
##  In-game water is made by the water rune (stage 5's `CMD_WATER`). **The command stands up then and this door remains.**
##
## **It writes only over EMPTY or WATER.** Writing over a burning cell changes only the material while
##  `_burn_slot` still claims that cell, **leaving a ghost in the front** — that is why `_write_cell` calls
##  `_unburn`, and since water's door doesn't touch the front, blocking here is the only way.
## Not turning stone into water is the same line's job — erasing terrain is **destruction's job.**
##
## **The amount's range is checked here** (same idiom as `_valid_mat` — once at the command boundary).
##  `_aux` is a `PackedByteArray`, so past 255 it is **truncated to the low 8 bits with no error.**
func set_water(x: int, y: int, amount: int) -> bool:
	if x < 0 or x >= W or y < 0 or y >= H:
		return false
	if amount < 0 or amount > Tuning.WATER_MAX:
		push_error("CellGrid.set_water: amount %d is outside 0..%d" % [amount, Tuning.WATER_MAX])
		return false
	var i := (y << X_SHIFT) | x
	if _mat[i] != Mat.EMPTY and _mat[i] != Mat.WATER:
		return false
	_write_water(i, amount)
	return true


## Chunks running this tick.
##
## **The only place "did the water stop" can be read as a value.** "It looks like it isn't moving" can't
##  measure it — v1's water looked stopped while it wasn't, and that killed lightning (`docs/design/water.md`).
## **Measured at 2.25us** (verify-run · 2000 calls x 2 sets). A native `count()` over 16,128 entries,
##  consistent with `count_material`'s 588us over 4,128,768. Negligible even called every frame by the HUD.
func active_chunk_count() -> int:
	return _awake.count(1)


## Does the chunk holding that cell run this tick.
## **Outside the grid is false** — a different axis from `mat_at` returning solid outside the grid.
##  Making "outside is always awake" here would make boundary-movement checks **measure nothing.**
##
## **True from the next `step()`, not immediately after a change.** Doors that change the grid mark `_dirty`,
##  and `_chunk_flip()` is what turns that into awake — that is what "runs this tick" means.
func chunk_awake_at(x: int, y: int) -> bool:
	if x < 0 or x >= W or y < 0 or y >= H:
		return false
	return _awake[(y / Tuning.CHUNK_CELLS) * CHUNK_W + (x / Tuning.CHUNK_CELLS)] != 0


## A band's awake chunk count — **the value to read when the sweep skips a whole band** (`_band_awake`'s comment).
func band_awake_count(band: int) -> int:
	if band < 0 or band >= CHUNK_H:
		return 0
	return _band_awake[band]


## **An independent measurement of the band summary.** `band_awake_count` above is the value `_touch`
##  maintains **incrementally**; this one is built by **counting `_awake` directly.**
##
## **The side that diverges is always the summary** (exactly the same place as `claimed_slot_count`).
##  A summary low at 0 makes the sweep **skip a whole awake band**, and that water freezes in place —
##  no error, and on screen only "an invisible wall".
## **Net-only.** It sweeps a chunk row — do not call it in the game loop.
func scan_awake_in_band(band: int) -> int:
	if band < 0 or band >= CHUNK_H:
		return 0
	var n := 0
	var base := band * CHUNK_W
	for k in CHUNK_W:
		if _awake[base + k] != 0:
			n += 1
	return n
