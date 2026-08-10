extends RefCounted
## Material table. **One material = one row in `DEFS`.** Behavior, color, name and fuel all derive from there.
##
## The runtime form is a **flat array**, baked once at boot — a `Dictionary` lookup in an inner loop
## is thousands of VM calls per tick on its own.
## **The palette also comes from this table.** Color literals in the shader split sim from render.

# --- material ids -------------------------------------------------
# ids are int and **iteration goes only through the explicit `ALL` list**.
#  Assuming the values are contiguous breaks silently the day a slot is retired.
const EMPTY := 0
const STONE := 1
const WOOD := 2
const BEDROCK := 3  ## Unbreakable wall. Behaves like STONE (solid); only destruction is refused — see `indestructible`.
## **Water is one material. It does not split into "water" and "shallow water"** — the door that writes
##  materials (`_write_cell`) zeroes `_flag` and `_aux` together, so **the amount vanishes on the spot**
##  every time it crosses the threshold.
##  => Depth rides on a `_flag` bit (`docs/design/water.md`, "Screen").
const WATER := 4

const ALL: Array[int] = [EMPTY, STONE, WOOD, BEDROCK, WATER]

## Palette slot count. Must **equal the shader's `palette[16]`.**
##  Past 16, a material id leaves the L8 precision safe range (0..15).
const SLOT_COUNT := 16

# --- behavior ------------------------------------------------------
const BEHAVIOR_NONE := 0    # does nothing (EMPTY)
const BEHAVIOR_STATIC := 1  # does not move. **Solid** — bolts land on it and the character stands on it

# --- state bits (`_flag`) ------------------------------------------
# **Only the low 4 bits are used.** The L8 texture is recovered in the shader as `int(v*255+0.5)`,
#  and 0..15 is safe even on machines that drop to mediump.
# These values are **injected into the shader as uniforms** (`cell_renderer.gd`) — do not re-hardcode them there.
const FLAG_BURNING := 2
## **Water amount at or below the threshold = shallow.** Not a separate state but **a mirror derived
##  from the amount**, updated by `cell_grid._write_water` **at the same place** it writes the amount.
## Do not touch it separately. If amount and bit move in two places they diverge, and
##  **the diverged side shows only on screen** — the sim reads only the amount and the shader only the bit,
##  so neither corrects the other.
## It **cannot stand on the same cell as `FLAG_BURNING`** — water has 0 fuel, so ignition can't reach it in principle.
const FLAG_SHALLOW := 1
# Bits 4 and 8 are free. **Do not name them in advance** — a name with no consumer and no plan is a false handle.
#  v1 had exactly that, `FLAG_FROZEN := 8`.

# --- what `_aux` means ---------------------------------------------
# An idle field with no consumer gets read with a different meaning later. **Pin the meaning here.**
#
#   BURNING set -> remaining fuel
#   WATER       -> **water amount (1..255).** 0 means that cell is not water — the material becomes EMPTY.
#                  => "material is WATER with amount 0" cannot exist (`cell_grid._write_water`).
#   otherwise   -> unused. Must be 0
#
# **BURNING and WATER cannot meet on one cell** — water has 0 fuel so ignition can't reach it, and
#  water's door (`_write_water`) writes only over EMPTY or WATER. => The two meanings never overlap.

## Material definitions. Behavior, color, name and fuel all derive from this one place.
##
##   fuel  **This is fire's budget.** 0 means it doesn't burn. It goes into `_aux` (PackedByteArray), so **255 or less.**
##         "burning consumes fuel and it goes out at 0" => where you put wood is fire's lifespan (GDD).
##   rgb   **Color is a 24-bit integer `0xRRGGBB`, not a `Color`.**
##         This folder's contract is "integers only" and `net_determinism` **catches float literals.**
##         A color written as `Color(0.36, ...)` splits the folder contract from what the net measures,
##          and patching that gap with an exception list means **the list goes stale next.** => The exception was removed.
##         The single source still holds — only `src/view/cell_renderer.gd` bakes it into `Color`.
const DEFS: Dictionary = {
	EMPTY: {"name": &"빈칸", "behavior": BEHAVIOR_NONE, "fuel": 0, "rgb": 0x0E0E13},
	STONE: {"name": &"돌", "behavior": BEHAVIOR_STATIC, "fuel": 0, "rgb": 0x5C574F},
	# **`indestructible` yet it burns. Not a contradiction — it is this game's rule** (decided by the user).
	#  · **Blasts cannot dig it** — `cell_grid._disc(…, destroy)` filters on `_indestructible`
	#  · **Fire consumes it** — `_burn()` calls `_write_cell(idx, EMPTY)` **on a separate path** (skipping the filter)
	#  => **Fire is the only way to remove wood.**
	#
	# **Why it changed — the GDD's progression key did not hold in code.** Measured (verify-read):
	#  stage 1's wood wall (3 tiles) **was passed with three blasts and no fire.** Worse, the blast
	#  did not carry `element`, so **one runeless blast ignited 159 cells** => "get the fire rune from the
	#  midboss to burn wood and open the path" **was never a lock at all.**
	#  Thickness can't fix it — it only adds shots. `blast_rd(0)` is 8 cells, so a 3-tile wall was 3 shots.
	#
	# **The price**: no wood anywhere on the map is dug by blasts. "Clear wood with a blast" play disappears.
	#  That is the point — **only fire removes wood** must stand as a rule for the progression key to survive.
	# **`rune_only` — only the fire rune's own ignition may light this material** (`burn-out-of-the-bull-room.md`
	#  §0, the door-protection question). A wood-wide law, not a door-only one: the bull's own fire and a
	#  runeless blast both pass **through the same command** the fire rune's trace does
	#  (`CellGrid.cmd_ignite`), and nothing about the command tells them apart except the `src` argument
	#  `_ignite_cell` now takes. **`docs/decisions/the-door-burns-only-from-the-fire-rune.md`** is the decision;
	#  this row is where it is enforced.
	# **Every material with `fuel > 0` must carry this column** — `net_tables` measures that pairing directly.
	#  Without it, ordinary fire's ability to spread (`_burn`'s own unconditional `IGNITE_RUNE_FIRE` argument,
	#  below) stops being provably safe the moment a second fuel-bearing material is added.
	WOOD: {"name": &"나무", "behavior": BEHAVIOR_STATIC, "fuel": 200, "rgb": 0x6B4524,
		"indestructible": true, "rune_only": true},
	BEDROCK: {"name": &"기반암", "behavior": BEHAVIOR_STATIC, "fuel": 0, "rgb": 0x232228,
		"indestructible": true},
	# **Two values derive the rules. Do not write separate blocking code.**
	#  · `BEHAVIOR_NONE` => `is_solid()` is false => **both character and bolts pass through water**
	#  · `fuel: 0`       => "water doesn't catch fire". `_ignite_cell` already stops at 0 fuel
	# **0x2C5F8A -> 0x1B3E5E (decided by the user). Darkened.**
	#  **Not taste — making the rule readable.** `sim_tuning.WATER_WET` **sets both color and fire-proofing**,
	#   so shallow water can't put out fire. With the two colors close,
	#   **"why can't this water put out fire" doesn't read on screen.**
	#  That symptom actually occurred: verify-look saw that "the deep side is **fairly bright and saturated**,
	#   so at 4px thickness it reads as a shade of the same blue", and fire running below the blue line
	#   looked like **"fire burning underwater"** (`water-and-chunk-sleep`, "Result (6)").
	#  => **The shallow side (`fx_tuning.WATER_SHALLOW`) brighter, this one darker** — pushed apart from both ends.
	# **The hue is unchanged** (still blue). Splitting the hue too makes the two depths read as two different materials.
	# **Not yet seen on screen.** Whether this value is enough is what gets looked at next.
	WATER: {"name": &"물", "behavior": BEHAVIOR_NONE, "fuel": 0, "rgb": 0x1B3E5E},
}

## Color for a slot with no definition. **Deliberately magenta** — add a material without the palette
##  following and the screen screams. A quiet black lets "what you fire ≠ what you see" happen silently.
const MISSING_RGB := 0xFF00FF


## Once at boot. Inner loops only index this array — zero dictionary lookups.
static func bake_behavior() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(SLOT_COUNT)
	for id: int in ALL:
		out[id] = int(DEFS[id]["behavior"])
	return out


## Fuel is a flat array too. Fire touches tens to hundreds of cells' fuel every tick.
static func bake_fuel() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(SLOT_COUNT)
	for id: int in ALL:
		var f := int(DEFS[id]["fuel"])
		if f < 0 or f > 255:
			# `_aux` is a PackedByteArray, so out-of-range fuel is **truncated to the low 8 bits, with no error.**
			push_error("Mat: fuel %d of %s is out of byte range" % [f, DEFS[id]["name"]])
			f = clampi(f, 0, 255)
		out[id] = f
	return out


## The value the destruction path (`cell_grid._disc`) sweeps. Missing materials are destructible
##  (default false) — omitting `"indestructible"` from `DEFS` for a new material means **breakable is the default.**
static func bake_indestructible() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(SLOT_COUNT)
	for id: int in ALL:
		out[id] = 1 if bool(DEFS[id].get("indestructible", false)) else 0
	return out


## **Mirrors `bake_indestructible()` exactly.** Missing materials are lightable by anything (default false) —
##  omitting `"rune_only"` from `DEFS` for a new fuel-bearing material means **it is open to ordinary fire**,
##  the same "breakable is the default" idiom that constant already holds for destruction.
static func bake_rune_only() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(SLOT_COUNT)
	for id: int in ALL:
		out[id] = 1 if bool(DEFS[id].get("rune_only", false)) else 0
	return out


## A slot's color (0xRRGGBB). Magenta sentinel if undefined.
## **Baking into `Color` happens in `src/view/cell_renderer.gd`, not here** — see the `rgb` comment above.
static func rgb_of(id: int) -> int:
	if not DEFS.has(id):
		return MISSING_RGB
	return int(DEFS[id]["rgb"])


static func material_name(id: int) -> StringName:
	if not DEFS.has(id):
		return &"?"
	return DEFS[id]["name"]
