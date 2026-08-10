extends RefCounted
## The character — movement, gravity, jumping, landing, **step offset**. It only **reads** the grid.
##
## **The point is that it is a `RefCounted`, not a `Node`.** If the character were a `Node`, the step offset
##  could not be measured headless — whether acceptance 4 ("does it walk over terrain it broke itself") goes
##  to the nets or stays eye-only is decided right here.
##
## **Godot physics (`CharacterBody2D` + collision) is not used.** The terrain is not a TileMap but a 4px cell
##  array, so putting it on the physics engine would mean **rebaking collision shapes on every blast.**
##  One blast changes hundreds of cells, and that is the real cost. => Movement and landing are written by
##  hand and the cells are read directly.
##
## **Floats are allowed here.** The GDD's multiplayer table pinned it — the grid and projectiles are
##  deterministic, and **the player, monsters and items are host-authoritative.** Integer hell applies only to
##  code touching the grid.
##  That is why this file is not a target of `net_determinism`. Instead `net_layers` measures that
##   **no `src/view/` or `src/stage/` path string appears.**
##   That only reaches "it does not reference the screen", and **"it does not know the scene tree" is measured
##    by nobody** — globals like `Input` and `Engine` are reachable without a preload, so the path scan misses them.
##    Discipline is the only thing holding it. Write one `Input.` line here and the nets are green and only the
##    server dies.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
## Reading the notification's coordinate system (fixed point) needs that constant. **Referencing `src/sim/` is
##  inside the contract** — what is blocked is only `src/view/` and `src/stage/` (`net_layers`).
const SpellSim := preload("res://src/sim/spell_sim.gd")
## **Movement, gravity and terrain collision are no longer here — they were extracted into `Body`**
##  (`monsters-minimum` stage 0). Making the monsters use the same five lines is the reason.
##  `_move_x`, `_move_y`, `_try_step_up`, `_box_free` and `_grounded` moved into `Body` — leave a copy here
##  and it will diverge.
const Body := preload("res://src/actor/body.gd")

## **This is the "collision box". Not the "sprite size". The day the two split apart is recorded here.**
##  The sprite cell is still 32px and that constant is `fx_tuning.CHAR_CELL_PX` — **that is the single source
##  on the sprite side.**
##
## **`W_PX` was narrowed 32 -> 20** (decided by the user): "**the character registers as touching the wall
##  before it touches it**". The body sprite's content width is **18-22px** (it differs per cell — idle 18,
##  walk 20, jump 22) while the box was 32, so **it hit walls with 7px of empty space on each side.**
##  20 is the value that fits the walk cell exactly.
##  The jump cell (22) now overflows the box by 1px on each side — **overlapping is better than floating**
##  was the judgment behind the choice.
##
## **The GDD's "keep the character and the tile the same thickness" is not broken — that is a contract about
##  the *visible* size.** It is the device for counting "break that wall and I can get through" on screen, and
##  what does the counting is the **sprite**. The sprite is still drawn on a 32px cell. Lose this distinction
##  and put `W_PX` back to 32 and the floating-off-the-wall symptom comes right back.
##
## **The vertical (`H_PX`) was not touched.** The feet touch the bottom row (`net_sprite` measures it), so
##  vertically the sprite and the box already match, and what the user spoke about was the sides.
## **A bigger box makes this file expensive.** `Body.box_free` and `Body.grounded` (`body.gd`) and this file's
##  `_standing_in_fire` sweep the cells the box covers **in GDScript**, and that went **25 cells -> 81 cells**,
##  and this runs at **60Hz**, not per tick.
##  Measured (stage 0): `step()` while walking went **77 -> 249us** (1.5% of budget).
##   => Since the width was reduced to 20, it comes down to **6x9 = 54 cells**. Not re-measured.
const W_PX := 20
const H_PX := 32

## **A 2-cell (8px) step offset.** Without it the character **stops on the 4px ledge it broke itself.**
##  Cells are 4px, so the place a blast passed through is not a smooth floor but a surface littered with
##  1-2 cell ledges, and in this game that is not the exception but **the default state** — firing magic is
##  the same thing as breaking terrain.
##
## **It was not raised in the 32px switch. This is the spot where you want to read it as "half a tile" and
##  raise it to 4, but the two grounds point in different directions, and the surviving one is cell-based:**
##  · "Walking up a whole tile mushes the sense of power" <- **tile-based.** It **loosened** as a tile became
##    8 cells — 7 cells is now the safe line
##  · "At 1 cell you get stuck on **the slightest gouge**" <- **cell-based, and the cell did not change.**
##    The ledges a blast leaves are still 1-2 cells
##  => **What makes the ledges is the cell, and the cell did not change, so 2 is right.**
## The alternatives that could have been used (slope handling, capsule collision, doing nothing) are in the
##  design doc's "to reopen later".
const STEP_CELLS := 2
const STEP_PX := STEP_CELLS * Tuning.CELL_PX

## Feel values — decided while looking at the screen. The grounds must be written alongside or the next person
##  will undo them.
##  **All four were doubled in the 32px switch, and the ground is one: "the value read in tiles must stay the same".**
##  · Movement 260px/s = 8 tiles/s. It crosses the 1,920px screen in 7.4s (the viewport doubled too).
##    That is about the lower bound of "walking"
##  · Gravity 2400px/s^2 + jump -720px/s => reachable height v^2/2g = 108px = **3.4 tiles**, 0.6s of airtime.
##    3 tiles = three characters stacked, so "I can jump up there" is gaugeable by eye
##  · The 1800px/s fall cap is 30px per frame, **smaller than the box height (32px)** — it does not pass through walls
##
## **`GRAVITY_PX` no longer drives the player's own fall — `PLAYER_GRAVITY_PX` below does.** It stays here,
##  unchanged at 2400, only because **`monster.gd` and `boss_ai.gd`'s jump/leap/slam arcs read this exact
##  constant** (`monster.gd:240`, cross-class, deliberately — one shared "world gravity" for everything that
##  hasn't opted out). The split happened, not a rename, because lowering it for player feel silently moved
##  every boss's leap apex, leap distance and landing-marker prediction too — 4 nets went red
##  (`net_monster`, `net_monster_slam`, `net_monster_breath`, `net_attack_predict`) measuring **bosses**, not
##  the player, the moment this one number changed. **Read `boss_ai.gd`'s own note on why it needed a second
##  constant after all** — this file is not where that reasoning is kept, so it does not get repeated here.
##
## **Double just one of `PLAYER_GRAVITY_PX` and `JUMP_VY_PX` and it silently goes wrong.**
##  Reachable height is `v^2/2g`, so doubling only `v` gives **4x** and doubling only `g` gives **half**.
##  **No error is raised.** The stage's pillar and wall heights are all designed around these values, so
##  getting it wrong only looks like "I cannot clear the pillar".
## **240, and the last digit is the whole reason: it is exactly 4px per 60Hz frame.**
##
## `body.x` is an integer (the fraction lives in `_rem_*`), so a speed that does not divide 60 makes the
##  character advance unevenly — at 260 it was **5, 4, 4, 5, 4, 4** (measured, driven at 60Hz). The camera
##  follows, so on screen the character is nearly still and **the world scrolls in that rhythm**. That is
##  the 부르르 떨림 the user reported, and it survived `stage.snap_camera_px` because that fix is about the
##  camera and this is the gait.
##
## **This value could not be changed until the bolt hit test was fixed, and that is why it moved today.**
##  `monster_bolts.consume_hits` tested the bolt's **point**, so at 240 (and at 300) the player and the bolt
##  closed fast enough to straddle the box between samples and **never collide** — a slower player dodged
##  better than a faster one. That function now tests the bolt's **swept segment**, which is what made this
##  line editable.
##
## **The price: this is exactly the wolf's `speed_px`, so a wolf can no longer be outrun on foot.** Kept
##  knowingly — the wolf backs off after each swing (`monster_defs.MELEE`), so the gap opens anyway, and
##  being tailed by the fast mob reads as pressure rather than as a dead end.
const MOVE_SPEED_PX := 240.0
## **The world's shared gravity — every monster and boss (`monster.gd:240`, cross-class), not the player.**
##  See the box above for why the player does **not** read this anymore.
const GRAVITY_PX := 2400.0
## **The player's own fall, split out from `GRAVITY_PX` above** ("game feels sped up", the user, looking at the
##  screen; `docs/design/game-feel.md` "11b"). Paired with `JUMP_VY_PX` below from the `v0=36k, g=6k^2` family
##  (`k=16`) so reachable height stays **exactly** 108px (3.4 tiles, unchanged) while airtime goes 0.6s -> 0.75s.
##  `k=15` is the old pair (540/1350 — not used); `k=17` (612/1734) was the hand-computed value that first
##  prompted this and was rejected only for giving an uglier airtime fraction (12/17s vs 12/16=0.75s exactly).
const PLAYER_GRAVITY_PX := 1536.0
## **The player's own launch speed.** Paired 1:1 with `PLAYER_GRAVITY_PX` above — see that constant's box.
##  Never shared with monsters (`monster_defs.gd` gives every jumping/leaping kind its own `jump_vy_px`), so
##  this one needed no split.
const JUMP_VY_PX := -576.0
const MAX_FALL_PX := 1800.0

## **Variable jump — "how long you held it" sets the height** (user request).
##  After the key is released, the rising speed is **clipped** down to this ratio. Keep holding and it is not clipped.
##
## **It went in at 0.55 and was lowered to 0.2. The reason is this constant's whole story —
##  the height did not vary across "the press durations a human can produce"** (user: "seems like it does not work").
##  The shortest tap a hand can produce is **0.05-0.1s**, and at 0.55 that stretch was already **67-92%**.
##  **The nets did not see this** — they were measuring a 1-frame (0.017s) press, and there it was 46%, which
##   separated well.
##   **Measure with input a human cannot produce and you get "it works" while the game does not.**
##
## **Height is the square of speed (`v^2/2g`) — do not read the ratio directly as height.**
## **Recomputed for the `PLAYER_GRAVITY_PX`/`JUMP_VY_PX` pair above (2400/-720 -> 1536/-576, "game feels sped
##  up", `docs/design/game-feel.md` "11b") — the old table's px values were for the old pair and went stale the
##  moment the constants above moved. Analytic, from the same `height(t) = v0*t - g*t^2/2 + cut_vy^2/(2g)`
##  formula the old table's own numbers came from, not re-simulated frame-by-frame this time:
## ```
##   hold time    at 0.2 (now, v0=576 g=1536)
##   0.05s (3F)   31px  29%   <- the shortest a hand can produce
##   0.10s (6F)   54px  50%
##   0.17s (10F)  79px  73%
##   0.25s (15F) 100px  93%   <- was already 100% at the old pair (14.4-frame stretch); now still inside it
## ```
##  => Every row dropped in both px *and* percent — the same hold now buys a smaller share of a *taller*
##   time-budget, because the stretch where the cut bites also widened (below). **Not yet felt against the
##   stage's tree/pillar landmarks** — the old table's "2.0 tiles (tree)" / "3.2 tiles (pillar)" readings were
##   tied to the old numbers and are not re-asserted here; that is a screen judgment, not this edit's to make.
##
## **The stretch where the control bites = `(v0 / (g * DT)) * (1 - ratio)` frames** — `18` was that formula's
##  value for the *old* pair only (`720 / (2400/60) = 18`), not a constant of its own; the new pair gives
##  `576 / (1536/60) = 22.5`. At ratio 0.2 that stretch is now **18 frames (0.3s)**, up from 14 (0.24s).
##  If you want to raise the ratio, first compute whether that stretch **covers a human's tap time (0.05-0.2s).**
##
## **The point is that the clipping is a "clamp", not a "multiply".**
##  Multiply every frame and it keeps shrinking after release, so **the result wobbles with when you let go**,
##  and missing the release event by one frame leaves that difference in place. A clamp **gives the same result
##  no matter how many times it fires.**
##  That is also why the input is **polling** (`is_action_pressed`) rather than `is_action_just_released` —
##   the same reason as `stage_input`'s "movement and jumping are polled", and it does not get tangled when
##   the window loses focus.
const JUMP_CUT_RATIO := 0.2
const JUMP_CUT_VY_PX := JUMP_VY_PX * JUMP_CUT_RATIO

## **Coyote time and the jump buffer — the two forgiveness windows** (`docs/design/game-feel.md`).
##  The user's report was "moving, the camera and jumping feel slightly unpleasant", and **neither of these
##  existed**: step off a ledge and the jump was simply eaten, press just before landing and it was eaten again.
##
## **They forgive opposite mistakes and are not one feature:**
##  · **Coyote** — pressed **after** leaving the ground. Keeps a jump alive for a moment past the ledge
##  · **Buffer** — pressed **before** touching the ground. Keeps the press alive until the landing frame
##
## **0.1s = 6 frames, and it comes from the same measurement `JUMP_CUT_RATIO` above stands on** — a hand
##  produces a 0.05-0.1s press, so a window shorter than a tap forgives nothing a hand can actually do.
## **Do not raise it much past this.** Coyote is airtime in which you may still jump, so a large value reads
##  as a double jump — and the double jump is a **town research unlock** (GDD), an axis this must not blur.
const COYOTE_SEC := 0.1
const JUMP_BUFFER_SEC := 0.1

## **How long the air-jump ring stays on screen, in ticks** (`research-bench-unlocks.md`). 4 ticks = 0.2s,
##  the same length as `INVULN_TICKS`, and **that is a starting value, not a tuned one** — whether a ring is
##  even the right mark (versus a puff, a stretch of the sprite, or a sound) is unseen. That doc's TBD.
## **Ticks, not seconds, because the screen reads the counter directly** — the same shape `invuln_left` holds,
##  and for the reason its own box gives: make a separate clock for the drawing and there are two clocks, and
##  you get a ring still showing after the jump it marked is long over.
const AIR_JUMP_FLASH_TICKS := 4

# --- HP ------------------------------------------------------------
## **A number** (design: "HP and damage"). Base damage is 10, so it takes **ten hits** to go down —
##  the whole of this value is that a one-shot death is not fun but rage.
const MAX_HP := 100

## **A direct hit and a blast are the same value.** What the design settled is one baseline only, and not
##  adding axes is skeleton first — **the blast side is an assumption and a place the user may overturn** (plan section 4).
const DAMAGE_HIT := 10

## **Invulnerability that applies only to hits. 0.2s = 4 ticks** (design: "invulnerability").
##  **Standing in fire (continuous damage) is not covered by it** — make invulnerability a single thing and
##   fire becomes harmless, and then "where you put fuel is level design" becomes meaningless to the player.
##   => The continuous damage path **neither reads nor writes** this value (stage 3).
const INVULN_TICKS := 4

## Standing in fire shaves this much **per second.**
## **An assumption** (plan section 4) — it reads as "1 second in fire = one bolt". A place the user may overturn.
## **It is per second, so it runs on frames (60Hz).** Being a rate, frames are natural, and on ticks the
##  "one hit becomes three" problem does not exist at all.
const BURN_DPS := 10.0

# --- recoil --------------------------------------------------------
## **Fire and you get pushed** (GDD natural law). It stays because it is part of the magic circle's fun.
##
## **Hit knockback was deleted** (decided by the user). Getting hit does not move the body.
##  **Do not confuse the two** — what disappeared is "pushed **when hit**", and what remains is "pushed **when firing**".
##  Deleted: `KB_SPEED_PX`, `_push_dir`, the pushing branch of `on_tick`, and the six nets that measured it.
##
## **The recoil became 1D — the vertical component (rocket jumping) was deleted** (decided by the user).
##  Firing downward does not lift you. **This is not a knob turned to 0 but an axis erased** —
##  `recoil()` has **no** line pushing `vy`. Raise the strength as high as you like and it does not move vertically.
##  **Only the horizontal share of the GDD natural law "magic recoil can push the character" remains.**
##   To revive it, read the deletion note on `recoil()` below — it records what has to come along with it.
##  One more thing was deleted: "danger and mobility come out of the same action" (plan: "magic recoil").
##   Shooting at your own feet is now **only danger and not mobility.**
##
## **An assumption** (plan section 4) — the design left "strength undecided" and **it is a place the user may overturn.**
##  · Recoil 40px/s — total horizontal displacement about 10px. **It was lowered three times, 400 -> 200 -> 100 -> 40**
##    (all decided by the user while looking at the screen. The last was "there should really only be a little").
##
## **Total displacement is `v0 * tau`. Read only the speed without looking at the decay and you cannot gauge the size.**
##  tau = 1 / ln(1/0.02) = **0.256s** => at 40px/s that is 10.2px. In cells, 2.5; in tiles, 1/3.
##  **It is 15% of the movement speed (260px/s)** — put in an input and it wins immediately. "You feel the push
##   but it does not take the controls away" is the spot this value picked.
##
## **This is the threshold of "might as well not exist". To go lower, do not shave the value, erase the axis** —
##  the vertical (rocket jump) disappeared in exactly that way. Keep shaving the value and what remains is a
##  **false knob whose feature exists but nobody can feel**, and that becomes the spot where the next person
##  reads "there is recoil" and builds a design on top of it.
##  · Decay x0.02 per second (tau ~= 0.26s) — "a sharp push that dies down"
## **The decay is a time constant, so it is independent of scale and tiles.**
##  **Erase the decay and the character slides forever after firing.** It is a spot you want to delete along
##   with the knockback, but `recoil_vx` below exists as an axis precisely **because the horizontal has no
##   decay mechanism**, and this is that mechanism.
##  **With the vertical gone, this mechanism became the only one** — before, gravity handled the vertical side.
const RECOIL_SPEED_PX := 40.0
const RECOIL_DECAY_PER_SEC := 0.02

# --- current -------------------------------------------------------
## **Current — recoil's sibling, but it does not decay** (`water-jump-and-escape.md` stage 4,
##  `docs/design/water.md`, "water pushes the character"). **It is a "field" re-read every frame, so attaching
##  decay makes it shrink twice** — recoil is an impulse dying down, the current is that frame's state.
##
## **Definition: "the speed when the neighbor cells' amount difference is at maximum (255)", and it is linear
##  in the difference.** `_body.water_flow()` already returns the average difference divided by the row count
##  (range -255 to 255), so here it is only divided by `WATER_MAX` to turn it into a ratio (see `step()`).
##
## **130 — half of walking (260). The two existing values give the ruler:**
##
##      RECOIL_SPEED_PX   40    recoil when firing
##      MOVE_SPEED_PX    260    walking
##      WATER_PUSH_PX    130    <- this value
##
##  · **Stronger than the recoil (40)** — otherwise "I am being pushed" is not graspable in the hand
##  · **Weaker than walking (260)** — **you must be able to walk against the current.** If you cannot, the user
##    gets trapped and this feature's purpose ("water affects me") turns into "water imprisons me".
##    To avoid the risk of being trapped at the skeleton stage, it is set so that **even against the current
##    you still advance at at least 130px/s.**
##
## **One thing remains to be re-measured on screen** — nobody has yet measured what the neighbor-cell difference
##  of actually flowing water is (at equilibrium it is at or below `WATER_MIN_DIFF` (4), but the value **while
##  flowing** is different). If the difference is always around 10, `130 * (10/255) ~= 5px/s` and nobody feels
##  it — **the scale is a place to reopen after measurement.** Do not tune it here to "make it felt"
##  (the nets measure that value).
const WATER_PUSH_PX := 130.0

## **Position, velocity, grounding and terrain collision are held by `_body`.** The declaration order is a
##  contract — declare it **before** the properties below. Put it after and the getters bite `null`
##  (`world_step._init` already recorded the same trap in the declaration order of its three fields).
var _body := Body.new(W_PX, H_PX, STEP_CELLS)

## Top-left px. **Delegated to `_body` — do not turn these into getter functions (`x()`).**
##  The repo reads `ch.x`, `_char.y`, `_ch.vy` and `ch.on_ground` **as fields**
##  (`character_view.gd`, `stage.gd`, `net_character`, `net_damage`). Turn them into functions and every one of
##  those call sites has to be fixed, and at that moment the implementer starts touching the assertions
##  acceptance 1 was guarding.
##  The reason for not keeping a fractional position (the landing height differs by up to 1px every time) is
##  `Body.x`'s contract.
var x: int:
	get: return _body.x
	set(v): _body.x = v
var y: int:
	get: return _body.y
	set(v): _body.y = v
var vy: float:
	get: return _body.vy
	set(v): _body.vy = v
var on_ground: bool:
	get: return _body.on_ground
	set(v): _body.on_ground = v
## The last direction faced (+1 right, -1 left). It is the default direction when the mouse is exactly on top
##  of the character.
var facing := 1

## **An integer** (plan section 6, risk 12). A float HP blurs both the HUD and the acceptance — the day
##  continuous damage is attached, hold a separate accumulator rather than making this value fractional.
var hp := MAX_HP
## Remaining invulnerability **ticks**. **The screen reads this value too** (`character_view`'s blinking) —
##  make a separate clock for the blinking and there are two clocks, and you get blinking after the
##  invulnerability has ended.
var invuln_left := 0

## Am I downed (HP 0). **It is not instant death** — you become incapacitated and **still take gravity**
##  (design: "death"). "For team-killing to be fun there has to be a way back" is the reason for this state.
## **When alone, the only revival is R (stage reset)** (plan section 4 assumption) — being picked up by an ally
##  is for the day multiplayer arrives.
## **It is a derived value, not separately held state** — diverge from `hp == 0` and "HP is 0 but it walks
##  around" happens with no error (that is why plan section 1 kept the character as one lump).
## **When does it become real state**: there is one condition — **"you can be downed while HP is not 0"**.
##  Two undecided items in the design make that day: **how long you hold out while downed** (during which HP
##  may recover) and **how much HP you have when picked up** (partial-HP revival). Once either is settled,
##  drop the getter and turn it into state.
var downed: bool:
	get:
		return hp <= 0

## Am I standing in fire right now. **The screen reads it** (a burning character). It is re-decided every
##  frame, so "I left the fire but keep looking like I am burning" is impossible in principle.
var burning := false

## **The recoil's horizontal speed.** Unlike `vy`, **the horizontal has no decay mechanism**, so a new axis was
##  needed — the vertical already has gravity doing that job (which is why the recoil's vertical component was
##  simply added to `vy`).
## **It is added to the input and decays over time.** It is neither "blocked" nor "gradually restored" —
##  put in the opposite input and while the recoil is running **the input does not win immediately.**
## **Its name was `kb_vx` (knockback).** It was renamed once the knockback disappeared and **`recoil()` was the
##  only remaining user** — an axis named after a feature that does not exist gets misread by the next person
##  as "so you get pushed when hit".
var recoil_vx := 0.0

## Fire damage that has not reached 1 yet. **The device that keeps `hp` an integer** (plan section 6, risk 12) —
##  a float HP blurs both the HUD and the acceptance.
## **It is not cleared when you leave the fire.** Clear it and tapping across fire becomes **free**, and that
##  eats away at "where you put fuel is level design".
var _burn_acc := 0.0

## **The two forgiveness windows' remaining time** (`COYOTE_SEC` · `JUMP_BUFFER_SEC` above), in seconds.
## **Seconds, not frames** — everything else in this file that ages is `dt`-driven, and a frame counter
##  would be the one thing in here that changes meaning if the physics rate ever moves.
var _coyote_left := 0.0
var _jump_buffer_left := 0.0

## **How many air jumps this character is allowed — pushed in from outside, every frame.**
##  `stage._physics_process` re-derives it from `Progress.air_jump_budget()` immediately before the world
##  steps, so buying the double jump is felt without any reset, purchase hook or application moment. **Do not
##  latch it here** and do not give `Character` a `Progress` reference to read it from — `src/actor/` holds no
##  reference to the run's progress today and adding one to answer "may I jump twice" would be a second
##  ownership path for a value the shell already derives.
## **0 by default, which is what keeps every existing jump check untouched** — with 0 the `or` term in
##  `step()` is never true and the spend branch below it is unreachable, so the condition reduces to exactly
##  today's. `net_character`'s A-1~A-4 water checks need no edit, and `net_research` asserts that identity by
##  driving the same frame sequences rather than assuming it.
var air_jump_budget := 0

## **How many are left in this airtime.** Counted down by the spend below, and **refilled on the ground and
##  nowhere else** — the same single-site discipline `_coyote_left`'s own box argues for ("a counter that only
##  counts down has to be reset somewhere else too, and the day a second grounding path appears that reset is
##  the line that gets forgotten").
## **Water deliberately does not refill it.** Air-jump over land, fall into water, jump freely, leave the
##  surface — you leave with 0. Refilling in water would mean the water path *writes* this counter, and the
##  whole point is that water short-circuits it without touching it.
var _air_jumps_left := 0

## **Ticks left on the air-jump ring. `invuln_left`'s exact shape, and read by the screen the same way**
##  (`character_view`) — one field, one clock. A second jump with no mark reads as a bug the first time it
##  fires, which is the whole reason this exists.
## **It is decremented at the very top of `on_tick()`, above the invulnerability branch** — that branch
##  `return`s, so a decrement below it stops counting for the entire invulnerability window and an air jump
##  taken just after being hit leaves the ring **frozen on screen**. Nothing barks.
var air_jump_flash_left := 0

## **HP and invulnerability are reverted too.** Without that, R (stage reset) cannot bring you back —
##  when alone there is nobody to pick you up, so **R is the only revival** (plan section 4).
## Position, velocity, grounding and `_rem_*` are reverted by `_body.place()` — touch them again here and
##  there are two places doing the reverting.
func place(px: int, py: int) -> void:
	_body.place(px, py)
	hp = MAX_HP
	invuln_left = 0
	burning = false
	_burn_acc = 0.0
	recoil_vx = 0.0
	# **Reverted with everything else.** Leave them and R (stage reset) can drop you into the new position
	#  already holding a buffered press from before the reset — one free jump on the first frame.
	_coyote_left = 0.0
	_jump_buffer_left = 0.0
	# **Reverted with the two windows above, for the same reason.** Left standing, R (stage reset) could drop
	#  you into the new position already holding an unspent air jump from before the reset. `air_jump_budget`
	#  itself is **not** touched — it is the shell's value, re-derived every frame, and clearing it here would
	#  be this object writing over something it does not own.
	_air_jumps_left = 0
	air_jump_flash_left = 0


func center() -> Vector2:
	return _body.center()


## **Runs at 60Hz (every `_physics_process`) — do not tie it to the 20Hz sim.**
##  Tie it to 20Hz and the controls stutter, breaking measurement 3 ("does it stick to the hand") entirely.
##  It is host-authoritative, so there is no reason to tie it to ticks (GDD multiplayer table).
## **`jump` and `jump_held` are different things.** `jump` is "was it pressed this frame" (start jumping),
##  `jump_held` is "is it held now" (keep allowing the rise). **No default is given** — a call site that does
##  not pass it silently becomes an "instantly released jump" and the reachable height drops to a third
##  (the same discipline as `cmd_blast`).
func step(grid: CellGrid, dt: float, axis: float, jump: bool, jump_held: bool) -> void:
	on_ground = _body.grounded(grid)
	# **Am I in water — re-read every frame.** Put it in `on_tick()` (where `burning` is set) and
	#  `TICK_DIVIDER` (3) makes the jump decision use an answer up to 2 frames stale, so you can still jump
	#  for two more frames after leaving the water — **the eye cannot see it**
	#  (`water-jump-and-escape.md` stage 1; net A-3 catches it by value).
	var in_water := _body.standing_in_water(grid)
	# **It is an assignment. This is exactly where "jump + recoil" becomes a technique.**
	#  Fire on the same frame and this line **erases the recoil**; fire after lifting off and the recoil
	#  survives, taking the reachable height to **51 -> 109px (2.1x)** (measured — **that is the 16px world's
	#  value.** At 32px both numbers double, but **whether the 2.1x ratio holds was not re-measured**).
	#  **This is intended** (decided by the user) — "**when** you fire" setting the height is the feel.
	#  **Do not change it to an addition.** It is an easy spot to read as a bug, so it is written down here.
	# **The two windows age before the jump is judged, not after.** Age them afterwards and a press on the
	#  landing frame itself is judged against last frame's answer — the exact staleness `in_water` above
	#  refuses to accept.
	# **Coyote is refilled, not decremented, while grounded.** A counter that only counts down has to be reset
	#  somewhere else too, and the day a second grounding path appears (a platform, a revive) that reset is the
	#  line that gets forgotten.
	_coyote_left = COYOTE_SEC if on_ground else maxf(0.0, _coyote_left - dt)
	# **The air-jump budget is refilled the same way and in the same place, and the ground is the only site.**
	#  Written as a refill rather than "reset it when you land" for the reason the line above it gives — a
	#  landing *event* has to be detected somewhere, and the day a second grounding path appears that detection
	#  is what gets forgotten. `air_jump_budget` is 0 unless the town unlock is bought, so with no unlock this
	#  line writes 0 over 0 every frame and changes nothing.
	_air_jumps_left = air_jump_budget if on_ground else _air_jumps_left
	# **`jump` is a press edge** (`stage_input.jump_pressed` is `is_action_just_pressed`), so the buffer is armed
	#  once per press. **If it ever becomes a polled `is_action_pressed`, holding the key would re-arm it every
	#  frame and the character would bounce on every landing** — that is the one change that breaks this line.
	_jump_buffer_left = JUMP_BUFFER_SEC if jump else maxf(0.0, _jump_buffer_left - dt)
	# **`or in_water` — underwater you jump any number of times regardless of grounding**
	#  (`water-jump-and-escape.md`, "it is not buoyancy or swimming — it is lifting the jump limit").
	#  The jump's own value (`JUMP_VY_PX`) is the same in and out of water — no new physics axis of buoyancy is made.
	#  **Water grants no coyote** — `on_ground` is false throughout a water column, so `_coyote_left` never fills
	#  there, and A-3 ("leaving water is blocked that very frame") survives this change untouched.
	# **`ground_jump` is named because it is asked twice** — once to allow the jump, once to decide who paid
	#  for it. Inline it and the two can drift, and the drift is a free air jump off every ledge.
	var ground_jump := on_ground or _coyote_left > 0.0
	# **`_air_jumps_left` is the town research unlock** (`research-bench-unlocks.md`). The unlock is a
	#  structural no-op underwater rather than a special case — but **read the next box for where that
	#  property actually lives, because it is not here.**
	#
	# **The term order in this `or` chain is cosmetic. Measured, and the design doc was wrong about it.**
	#  `research-bench-unlocks.md` says `in_water` sitting before the budget is what makes the unlock a
	#  no-op in water, and its acceptance 13 asks for an inversion that moves the budget ahead of `in_water`.
	#  **That mutation was run and every net stayed green — and it must, because it is a semantic no-op**: a
	#  disjunction's truth value does not depend on term order, both operands here are pure reads (`in_water`
	#  is a local computed above, `_air_jumps_left` a field), so short-circuiting skips no side effect. No
	#  check can catch it, and no check should be written claiming to.
	#  ⇒ **The whole no-op property is the `not in_water` guard on the spend below.** Drop *that* and water
	#  eats the budget immediately (that mutation turns 9 checks red). Reorder these terms freely; delete
	#  that guard and the feature breaks silently.
	if _jump_buffer_left > 0.0 and (ground_jump or in_water or _air_jumps_left > 0) and not downed:
		vy = JUMP_VY_PX
		# **Both are spent, and the coyote one is what stops a *free* double jump.** Leave `_coyote_left`
		#  standing and the window is still open next frame while airborne ⇒ a second press jumps again, for
		#  nothing. **The bought double jump does not come from here** — it is `_air_jumps_left`, a separate
		#  counter, and `COYOTE_SEC`'s own box forbids widening the forgiveness window into it.
		_jump_buffer_left = 0.0
		_coyote_left = 0.0
		# **Spent only when neither the ground nor the water paid for it.** This guard is the other half of
		#  the term ordering above: without it a jump in deep water would still charge the budget, and the
		#  no-op property is gone. **The jump's own value is `JUMP_VY_PX` unchanged** — whether an air jump
		#  should be weaker than the first is that doc's TBD, to be decided by eye and retuned as *height*
		#  (`v²/2g`, the box on `JUMP_CUT_RATIO`), never as a velocity ratio.
		if not ground_jump and not in_water:
			_air_jumps_left -= 1
			air_jump_flash_left = AIR_JUMP_FLASH_TICKS
	_body.apply_gravity(dt, PLAYER_GRAVITY_PX, MAX_FALL_PX)

	# **Variable jump — if the key was released and it is still rising, clip the rise** (`JUMP_CUT_*` above).
	#  **It checks `vy < JUMP_CUT_VY_PX`, not `vy < 0`.** Measure it as "is it rising" and you end up touching
	#   even rises already slower than the cut, and while the clamp leaves the value unchanged, **the intent
	#   gets blurred** — what is measured here is "is it rising faster than the cut".
	#  **Put it after gravity.** Put it before and this frame's gravity lands on top of the cut one more time,
	#   so the same input gives a height that wobbles with the phase of the release frame.
	#  It runs while downed too — the only path upward is the jump (rocket jumping was deleted) so it cannot
	#   trigger, and adding a branch means two places to fix the day a "floating while downed" path appears.
	if not jump_held and vy < JUMP_CUT_VY_PX:
		vy = JUMP_CUT_VY_PX

	# **Go down and the input dies. Gravity and the leftover recoil stay.**
	#  Erase `vy` or `recoil_vx` here too and it becomes indistinguishable from "instant death" on screen —
	#   **falling** while downed is the only mark separating "incapacitated" from "dead".
	var move := 0.0 if downed else axis
	if move != 0.0:
		facing = 1 if move > 0.0 else -1
	# The axes are solved separately — push diagonally in one go and you cannot tell which side was blocked at
	#  a corner, and you get "jumping while pressed against a wall sometimes passes through".
	# **Current — added into the same sum as the recoil.** **No decay is attached** — slip the current in
	#  right below the recoil line (the line after the decay) and the current eats the decay too, so it
	#  **shrinks twice**, and the push lingers a while after the water is gone. `water_flow()` is re-read every
	#  frame, so that in itself is already "decay".
	var water_push := float(_body.water_flow(grid)) / float(Tuning.WATER_MAX) * WATER_PUSH_PX
	# **Input, recoil and current are added. They do not overwrite** — overwrite and the controls die while the
	#  recoil is running, and that becomes "blocked", which is the side the user did not choose.
	_body.move_x(grid, (move * MOVE_SPEED_PX + recoil_vx + water_push) * dt)
	# **Decay after pushing.** Decay before and the recoil of the very frame you fired gets one frame shaved off.
	#  The current is not a decay target — only `recoil_vx` is reduced.
	recoil_vx *= pow(RECOIL_DECAY_PER_SEC, dt)
	if _body.move_y(grid, vy * dt):
		vy = 0.0
	on_ground = _body.grounded(grid)
	# **Look after all the moving is done.** Look before and you get shaved by "the fire at the spot you just left".
	_burn(grid, dt)


## **Standing in fire shaves you — it neither refreshes invulnerability nor is stopped by it.**
##  That branch is the whole of this feature (design: "what hits me"). Make invulnerability a single thing and
##  **standing in fire stops hurting**, and then "where you put fuel is level design" becomes meaningless to
##  the player. => This function **neither reads nor writes** `invuln_left`.
func _burn(grid: CellGrid, dt: float) -> void:
	burning = _body.standing_in_fire(grid)
	if not burning:
		return
	_burn_acc += BURN_DPS * dt
	var whole := floori(_burn_acc)
	if whole <= 0:
		return
	_burn_acc -= float(whole)
	take_hit(whole, false)


## **There is one door that shaves HP** (`monsters-minimum` stage 5). There are already four places shaving
##  HP — `on_tick`'s direct hit and blast, `_burn`'s continuous damage, **pig contact** and **the hen's bolt**
##  (the latter two are called by `world_step`) — and if all four wrote their own `hp = maxi(0, hp - dmg)`,
##  **then when one of them forgets the floor, HP leaks negative while `downed` is `hp <= 0` so the behavior
##  looks fine and only the HUD reads `-3/100`.** => The invulnerability check, the floor clamp and the
##  invulnerability set are gathered here in one place.
##
## `tanks_invuln`: whether this damage rides the invulnerability — **direct hits, blasts, pig contact and hen
##  bolts are true**, **fire's continuous damage is false** (make invulnerability a single thing and fire
##  becomes harmless — the same reason as the `_burn` header above).
## Return value: true if HP was actually shaved, false if the invulnerability blocked it (the caller judges
##  "one hit and that is the end of it" from this return value — `world_step`'s (6) uses it that way).
func take_hit(dmg: int, tanks_invuln: bool) -> bool:
	if tanks_invuln and invuln_left > 0:
		return false
	hp = maxi(0, hp - dmg)
	if tanks_invuln:
		invuln_left = INVULN_TICKS
	return true


# ══════════════════════════════════════════════════════════════════
#  Was I hit — **this is where two worlds meet**
# ══════════════════════════════════════════════════════════════════
# The sim (`src/sim/`) does **not know** the character. Here is where the sim's notifications are **only read**
# and judged.
# Do it the other way around (the sim knowing the character) and determinism gets tied to a host-authoritative
#  position, so **the grid diverges per client** — no error is raised and it only shows up as "the terrain looks
#  different to each player in multiplayer" (GDD).

## **It runs only on ticks.** Call it at 60Hz and **one hit becomes three** — the notification arrays are
##  cleared only at the start of `spell.step()`, so the same values stay there for the three frames between ticks.
##  The invulnerability eats two of them, so **on screen it looks normal**, and the 3x only shows up in
##   continuous damage, which is unrelated to invulnerability. => The only entrance is inside `world_step.frame()`'s
##   **tick branch**.
##
## **It does not take the grid.** This judgment does not need the grid right now (continuous damage is `step()`'s
##  job), and an unused argument becomes a false knob saying "the terrain is looked at here".
func on_tick(spell: SpellSim) -> void:
	# (0) **The air-jump ring's clock, and it has to be above (1).** That branch `return`s, so a decrement
	#  written below it stops counting for the whole invulnerability window — take an air jump just after
	#  being hit and the ring **freezes on screen for four ticks** with nothing barking. This is the same
	#  passage CLAUDE.md names three times over (`_charge_blocked`/`_leaped_landed`/`_grounded_recently`): a
	#  fact latched at 60Hz that the tick has to read regardless of what else the tick decides to skip.
	air_jump_flash_left = maxi(0, air_jump_flash_left - 1)
	# (1) If invulnerable, do nothing. This branch is the whole of acceptance 3-(2) —
	#  the tick you get hit fills it with 4 and this line eats the next 4 ticks
	#  (3-tick spacing = one hit, 5-tick spacing = two hits).
	if invuln_left > 0:
		invuln_left -= 1
		return
	# (2)(3)(4) Segment (direct hit), blast and pillar. **One hit and that is the end of it** —
	#  that is acceptance 3-(1) (taking two blasts on the same tick is still one hit).
	# **`hit_by_segment`/`hit_by_blast`/`hit_by_pillar` return a power percent, 0 = not hit — `max`, not `or`.**
	#  `if a() or b()` short-circuits, so whichever the array order finds first would silently decide the
	#  damage the moment the two ever disagree (`body.gd`'s "why max" comment). Base 100 keeps this identical
	#  to the pre-Stage-A flat `DAMAGE_HIT` for every combination that existed before.
	# **`hit_by_pillar` must land here too, or the pillar hits monsters and not the player with no error raised**
	#  (`glyph-condense.md` §11.8's own risk list — "only one of `character.gd`/`monster.gd` updated").
	var pw := maxi(maxi(_body.hit_by_segment(spell), _body.hit_by_blast(spell)), _body.hit_by_pillar(spell))
	if pw <= 0:
		return
	# (4) HP does not go below 0 (plan section 4) — `take_hit` does the floor and the invulnerability set together.
	take_hit(DAMAGE_HIT * pw / 100, true)
	# **Getting hit does not push you** (decided by the user). There used to be a "push toward the hit direction"
	#  here and `_push_dir` carried it — both were deleted. **To revive it you must revive both the place that
	#  finds the direction (`_hit_by_*`) and the place that pushes (here).** Leave only one and you find the
	#  direction and use it nowhere.


## **Fire and you get pushed** (GDD natural law). `world_step` calls it **after `fire()` returned true** —
##  hook it at the moment of queueing and **even rejected shots push you**, giving "it did not fire but I got pushed".
##
## **It is 1D. There used to be a `vy -= d.y * RECOIL_SPEED_PX` here and it was deleted** (decided by the user).
##  That one line was the GDD's **rocket jump** — firing downward lifted you, and since getting caught in your
##  own blast was guaranteed, **you rose and hurt at the same time**. Now only the hurting is left.
##  **Reviving it takes more than that line** — the net's `_firing_down_does_not_lift_me` currently
##   **asserts "it does not lift"**, so it goes red the moment you revive it. That is the correct behavior.
##
## **`ady` is still used. Do not delete the argument.** It just does not push vertically; **it is needed for the
##  normalization** — remove it and `d.x` is always plus or minus 1, so **firing downward pushes you hard sideways.**
##  Right now firing downward gives `d.x ~= 0`, so the horizontal recoil is nearly nothing too. No error is
##  raised and it only looks like "firing downward makes me slide sideways".
func recoil(adx: int, ady: int) -> void:
	var d := _unit(float(adx), float(ady))
	recoil_vx -= d.x * RECOIL_SPEED_PX


## Unit vector. **The zero vector returns zero** — normalizing it divides by zero.
##  (A zero aim vector is normal input that `spell_sim.fire()` also silently discards.)
static func _unit(dx: float, dy: float) -> Vector2:
	var d := Vector2(dx, dy)
	if d.length_squared() <= 0.0:
		return Vector2.ZERO
	return d.normalized()


## **`_move_x`, `_try_step_up`, `_move_y`, `_grounded` and `_box_free` moved into `Body`**
##  (`monsters-minimum` stage 0). **`_hit_by_segment`, `_hit_by_blast`, `_seg_hits_box`, `_circle_hits_box`,
##  `_slab`, `_fp_px`, `_cell_px` and `_standing_in_fire` moved too**
##  (`monsters-minimum` stage 3, the second extraction) — monsters use the same box shape, so leaving a copy
##  here guarantees divergence exactly as CLAUDE.md says. Whoever fixes them, look at `body.gd`.
