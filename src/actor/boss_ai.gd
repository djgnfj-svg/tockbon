extends RefCounted
## The boss pattern table and the tick machine that walks it — `stage1-bosses.md` Stages B-F.
## `Monster._next_axis` delegates to `Monster._boss_axis` for any kind this table covers (`has_pattern`);
## `Monster.on_tick` calls `advance` once per 20Hz tick.
##
## **Two clocks, on purpose** (the plan's "two questions answered before any code"): the state transitions
##  here (idle -> windup -> charge/fire/gore/leap -> stun -> idle) are 20Hz, ticked from `Monster.on_tick` —
##  the same idiom as `invuln_left`/`reload_left` (an integer, decremented once per tick). **Movement stays
##  60Hz** — `Monster.step` reads only `pattern`/`pattern_dir` to pick a direction; it never itself decides
##  when a state ends. Tie the state machine to frames instead and it would flip mid-frame at whatever rate
##  the engine happens to render, and a charge could carve or stun at a moment no tick exists to apply it.
##
## **One new kind needs a row in `MOVES` — and, today, a matching `kind ==` branch in `advance`'s `WINDUP`
## transition too** (verify-read's finding: a row alone is not enough — `advance` falls through to the
## bull's `MOVE_CHARGE` for any kind it does not explicitly recognize there, and did so **silently** for a
## test kind that only had its own `MOVES` row, no error, a slow carve-less charge running forever on the
## safety cap). **The fall-through now barks** (`push_error`, below) if it is ever reached for a kind that
## is not the bull — this is the whole of what stops it being silent again.
## **Not net-driven, and said so rather than faked**: with only two real kinds today, this branch is
## structurally unreachable — the rooster's own `kind == KIND_ROOSTER` check always intercepts it first, and
## the bull reaching it is the correct, legitimate path (no bark). Reaching the buggy case needs a *third*
## kind with its own `MOVES` row and no branch of its own, which does not exist yet; a net cannot drive a
## `MOVES` entry that would first have to be added to production code just to prove the guard catches it —
## that is a fake net (CLAUDE.md), not a check. This bark is future-proofing, proven by reading, not by a run.
## The bull has two round-robin moves (charge, fire) plus gore (not round-robin — see its own box below); the
## rooster (Stage F) has one, leap. The design doc's triple and sweeping charges are still described as more
## rows in the same shape as `MOVE_CHARGE` (a repeat count, a direction flip), not built here: nobody has
## asked for them yet and adding rows nobody asked for is exactly the "while I'm here" CLAUDE.md rules out.
## **Do not add per-kind branching here for "what does this kind do next"** — that turns this file into a
## second `monster.gd` and re-opens the AI slot the design doc deliberately left as one line
## (`monsters.md`, `_next_axis()`). The `kind ==` checks below are the minimum this file's own header already
## sanctions ("the boss is the first real code to enter that slot... build only these two bosses' patterns") —
## each guards one kind's own move table, not a general "what should this kind be doing" dispatcher.
## **Move dicts are not a shared shape across kinds** — `MOVE_CHARGE`'s `charge_max_ticks` and `MOVE_LEAP`'s
## `leap_max_ticks` are different keys on purpose, matching the header's own promise that a per-kind
## accessor (`carve_r`, `leap_jump_vy_px`, ...) is scoped to exactly the one kind/move it is about.

const Defs := preload("res://src/actor/monster_defs.gd")

## `pattern` values — also the exact sequence `net_monster`'s pattern-sequence checks record
## (`stage1-bosses.md` Risk 5: "idle -> wind-up -> charge -> stun -> idle", extended by Stage D's fire cycle,
## Stage E's gore substitution and Stage F's leap). **`IDLE` also means "walk toward the player"** —
## `Monster._boss_axis` falls through to the same brainless-forward rule every other kind uses while idle,
## so a boss reads as a trash mob until its own clock runs out and it commits to a move. `WINDUP`/`STUN` are
## shared by every move (the telegraph and the recovery window read the same either way — **`STUN` doubles
## as the rooster's landing window**, the plan's own words: "one field is the window to hit for both
## bosses"); `CHARGE`/`FIRE`/`GORE`/`LEAP` are each one move's own active state.
enum Pattern { IDLE, WINDUP, CHARGE, STUN, FIRE, GORE, LEAP }

## Which move is running — an index into a kind's `MOVES` row, chosen at the `IDLE -> WINDUP` transition and
## carried through `Monster.move_choice` until the next choice. **The enum's ordinal is the array index** —
## `MOVES[kind][MoveChoice.FIRE]` must be the fire move, not a name lookup, so a kind's row order is
## load-bearing. **`GORE` is deliberately not a member of this enum** — it is never round-robin-chosen, only
## substituted for `CHARGE` at that move's own activation (see `GORE_MOVES` below), so it never needs to be
## an index into `MOVES`. **Only `CHARGE`/`FIRE`/`SLAM` name bull moves** — the rooster's one move
## (`MOVE_LEAP`) sits at index 0 of its own `MOVES` row without needing its own enum member (round-robin over
## a one-element array always resolves to index 0; see `advance`'s own comment on the arithmetic).
## **`SLAM`** (`stage1-bosses.md` Stage G) is the third bull move — round-robin now cycles CHARGE -> FIRE ->
## SLAM -> CHARGE -> ... (`MOVES[Defs.KIND_BULL].size()` grew from 2 to 3, and the round-robin arithmetic
## needs no other change for it, per this file's own header on why one row is enough).
enum MoveChoice { CHARGE, FIRE, SLAM }

## The charge. `windup_ticks` is the telegraph (the boss must not move a pixel — read by `Monster._boss_axis`,
## which returns 0 for `WINDUP`), `charge_max_ticks` is a safety cap for the case a charge never finds a wall
## (an open test floor; a real room always has one — Cost/Risk in the plan doc), `stun_ticks` is the window
## to hit back, `charge_speed_mult` multiplies `Defs.speed_px` only while charging. `carve_r` (cells) is
## Stage C's radius — read only by `WorldStep._carve_charge_impact`, on the exact tick a real collision (not
## the safety-cap timeout) ends a charge.
##
## **Every tick count and the speed multiplier are provisional** — `stage1-bosses.md`'s own TBD: "how many
## seconds the stun lasts — the fight's rhythm comes from here", "skeleton first, set on screen". Nothing
## here has had the user's acceptance yet.
##
## **The seconds noted below are the real elapsed time, not `ticks * 0.05s`** — the tick that *sets* one of
## these counters is itself already the first tick spent in that state (`net_monster`'s run-length checks
## pin this as `+1`; verify-run measured it directly), so e.g. `windup_ticks`=16 actually holds `WINDUP` for
## 17 ticks.
##
## **`carve_r`=3 is deliberately small, not just unmeasured** — `stage1-bosses.md` Risk 3-addendum measured
## the `h_px`/`carve_r` relation directly: a disc of radius `r` is `2r+1` cells tall at its widest row, and
## the bull's own box (`h_px`=56 = 14 cells) needs all 14 rows of a column clear to advance into it. `r`=3
## gives a 7-cell hole (7 < 14, no accumulation, measured across 196 real charges on room ①'s actual
## boundary — 29 cells removed total, all in the first two hits). `r`=7 crosses the cliff (15 >= 14, the
## bull can enter what it just dug). Raising `carve_r` past that line is a real design choice with a named
## cost, not a free tuning knob — see that Risk for the full table.
const MOVE_CHARGE: Dictionary = {
	"windup_ticks": 16,      # 17 ticks = 0.850s telegraph
	"charge_max_ticks": 60,  # 61 ticks = 3.050s safety cap if nothing stops it
	"stun_ticks": 24,        # 25 ticks = 1.250s window to hit back
	"charge_speed_mult": 2.0,
	"carve_r": 3,
}

## The fire breath (`stage1-bosses.md` Stage D). `windup_ticks` is its own telegraph — shorter than the
## charge's, because "the wind-up before a fire breath has nothing to say; fire appearing is the tell" (the
## design doc's own words) means the tell has less to communicate than a charge's runway does.
## `breathe_ticks` is how long `Pattern.FIRE` holds (frozen, like `WINDUP`/`STUN` — `Monster._boss_axis`
## returns 0 for it too); `reload_ticks` gates how often a bolt fires while breathing (`Monster.ready_to_fire`/
## `consume_fire`, the same clock idiom the hen already uses, `reload_left`). `stun_ticks` is the recovery
## window afterward — **its own value, not shared with the charge's**, since nothing says the two moves
## should recover at the same rate.
##
## **Bolt-level properties (damage, ignite radius, speed, range) are not here** — they belong to the bolt
## itself (`monster_bolts.gd`'s `FIRE_DAMAGE`/`FIRE_IGNITE_R`), the same split `BOLT_DAMAGE` already draws
## for the hen. This dict only holds "when does the mouth open and close".
const MOVE_FIRE: Dictionary = {
	"windup_ticks": 12,   # 13 ticks = 0.650s telegraph
	"breathe_ticks": 20,  # 21 ticks = 1.050s breathing
	"reload_ticks": 6,    # a bolt roughly every 0.3s while breathing
	"stun_ticks": 20,     # 21 ticks = 1.050s recovery
}

## The jump slam (`stage1-bosses.md` Stage G — "reuses D (fire) and F (leap)"). **The physics is the
## rooster's own `Pattern.LEAP`, not a new state** — `windup_ticks`/`leap_max_ticks`/`stun_ticks`/
## `leap_speed_mult`/`jump_vy_px` are the exact same field names as `MOVE_LEAP` for the exact same reason
## (`Monster.on_tick`'s jump-launch line and `Monster.step`'s gravity/arc code read them through `kind`, not
## through a second physics path). What's new is what happens the instant it lands: **`ignite_r`/
## `ignite_spread_cells`/`ignite_points` describe the fire thrown outward across the ground** — the design
## doc's own words — read only by `WorldStep._ignite_slam_impact`, on the exact tick a real landing (not the
## safety-cap timeout) ends the leap. **The same idiom as `MOVE_CHARGE.carve_r`**: a grid-touching radius that
## lives here rather than `sim_tuning.gd`, per that file's own named exception (`stage1-bosses.md`, "one rule
## collision, named rather than broken").
##
## **Ignites through the ordinary door, `CellGrid.cmd_ignite`** — no special-casing for the wood wall or for
## room ①. "Every constraint on the bull's fire applies unchanged" (the design doc's own words) falls out for
## free from reusing the same command Stage D's fire breath already uses; it does not need to be re-proven.
##
## **Every number is a guess, not a measurement** — same status as every other move in this file when it
## first ships. **`ignite_spread_cells` was `3` and verify-look saw it on screen**: the outermost pair sat at
## offset `(i - half) * spread_cells` = ±2*3 = ±6 cells, +`ignite_r`=2 = **±8 cells = ±32px** from the impact
## centre — inside the bull's own **44px** half-width (`w_px`=88), so the ring read as "the bull is standing
## on a small fire" (mostly hidden behind the sprite), not "the impact threw fire outward". **Corrected to
## `ignite_spread_cells`=6**: outermost offset is now ±2*6 = ±12 cells, +`ignite_r`=2 = **±14 cells = ±56px**,
## clearing the 44px half-width with margin instead of sitting 12px short of it. The three inner points
## (centre, ±6 cells/±24px) still land under the body — only the outer pair needed to clear it, and a
## centre-to-edge gradient reads as "radiating outward from the impact" rather than "a solid band under the
## body" or "a ring floating past it with a gap in the middle". **Picked, then measured, not derived and
## trusted** — the ±8px-short first version was itself the product of trusting the formula once already
## (this same comment's own prior correction, catching a doubled half-count); `stage1-bosses.md` Risk 11
## records both the original miss and this fix.
##
## **`jump_vy_px` was `-600.0` ("a bigger hop than the rooster's") and it broke acceptance 8** — verify-run
## reproduced the bull leaving room ① on the real map (89 slams, out at frame 660, 236px past the left
## boundary), because a slam's apex clears room ①'s left step (64px) the way `carve_r`=3 was sized never to.
## **Corrected to `-450.0`, measured 38px real apex** (not derived — the continuous formula overshoots by
## roughly 30% every time it's been checked against this game's discrete integration; see `MOVE_LEAP`'s own
## correction above for the first instance). 38px leaves **26px of margin under the 64px step**, not the 3-6px
## a value closer to the ceiling would give, and it sits clearly below the rooster's own 48px so the two
## moves' apex checks can still tell a swapped constant apart. **The slam is now shorter than the rooster's
## leap, the opposite of the flavor text that shipped with `-600`** — a real, visible change from what the
## design doc first pictured ("both front hooves down" reading as a big stomp), traded for keeping the bull in
## its own room. `stage1-bosses.md` Risk 11 records the acceptance-8 failure and this fix.
const MOVE_SLAM: Dictionary = {
	"windup_ticks": 18,       # 19 ticks = 0.950s telegraph — a two-footed jump reads slower than a charge
	"leap_max_ticks": 40,     # 41 ticks = 2.050s safety cap if it somehow never lands
	"stun_ticks": 24,         # 25 ticks = 1.250s recovery, same magnitude as the charge's own stun
	"leap_speed_mult": 1.5,   # travels toward the player, less far than a full charge
	"jump_vy_px": -450.0,     # measured 38px real apex - 26px of margin under room ①'s 64px step
	"ignite_r": 2,            # cells, each impact point's own radius (same idiom as MOVE_CHARGE.carve_r)
	"ignite_spread_cells": 6, # cells between each ignite point - outer pair now clears the bull's 44px half-width
	"ignite_points": 5,       # total points, symmetric outward from the impact centre (odd, so one sits centre)
}

## Kind -> its moves, indexed by `MoveChoice` for the bull (`CHARGE`/`FIRE`/`SLAM`), or just index 0 for any
## kind with only one move (the rooster). **Growing a kind's own AI = adding a row here** — the file header's
## promise.
const MOVES: Dictionary = {
	Defs.KIND_BULL: [MOVE_CHARGE, MOVE_FIRE, MOVE_SLAM],
	Defs.KIND_ROOSTER: [MOVE_LEAP],
}

## Gore — the close-range answer to the charge's dead zone (`stage1-bosses.md` Stage E; design doc: "standing
## under the bull's nose beats a move that needs runway, and without an answer the fight's lesson becomes
## 'hug it'"). **Not round-robin-selected.** It substitutes for `CHARGE` at the exact tick `WINDUP` would
## otherwise launch one, if the player is within `range_px` at that instant **and the boxes can actually
## touch vertically** — the same telegraph plays either way (`WINDUP` itself never changes), only the reveal
## differs. This is also the whole of "charge does not fire inside gore range" (acceptance): the substitution
## happens *before* `CHARGE` is ever entered.
## `active_ticks` is a fixed swing duration, not blocked-driven like the charge — a horn swing does not need
## a wall to end. `stun_ticks` is its own recovery window (reuses the fire breath's number, not the charge's
## — nothing says a gore and a charge should recover at the same rate either).
##
## **The contact damage itself is not here** — `world_step.BULL_GORE_DAMAGE` lives beside
## `PIG_CONTACT_DAMAGE`/`BULL_CHARGE_CONTACT_DAMAGE`, the same split every other damage value in this file
## already draws (bolt damage in `monster_bolts.gd`, contact damage in `world_step.gd` where the one
## contact-damage lump already lives).
##
## **`range_px`=120 is a guess, not a measurement, and it is now a *documented* guess** —
## `stage1-bosses.md` Risk 8-addendum (verify-run-b): the box-overlap reach is only 54px
## ((88+20)/2), so there is a ~66px band where gore commits but cannot land a hit. Left as a named open
## choice for a tuning pass (shrink the gate, or give the swing a lunge), not patched blind.
const MOVE_GORE: Dictionary = {
	"range_px": 120.0,
	"active_ticks": 12,  # 13 ticks = 0.650s swing
	"stun_ticks": 20,    # 21 ticks = 1.050s recovery
}

## Kind -> its gore move, if it has one. **Separate from `MOVES`** — gore is not one of the choices the
## round-robin picks between (`MOVE_GORE`'s own header), so it does not belong in that array.
const GORE_MOVES: Dictionary = {
	Defs.KIND_BULL: MOVE_GORE,
}

## The rooster's leap (`stage1-bosses.md` Stage F). Unlike every move above, `LEAP` is not a fixed-tick
## "stand still and do a thing" state — it is a real jump: `Monster.on_tick` gives the body an upward
## velocity (`jump_vy_px`) the instant `WINDUP` ends, gravity (`Character.GRAVITY_PX`, shared — no second
## physics axis is made for one kind) does the rest, and `Monster._boss_axis` returns the locked horizontal
## direction (the same idiom the charge already uses) so it arcs forward, not just up. **It ends when it
## actually lands** (`Body.grounded`, read by `Monster.step` into a latch — the same "60Hz collision reaches
## the 20Hz clock" channel `_charge_blocked` already opened for the charge), not a fixed duration —
## `leap_max_ticks` exists only as a safety net for the case gravity somehow never brings it down.
## `leap_speed_mult` multiplies `Defs.speed_px` for the horizontal lunge, the same idiom as the charge's own
## multiplier. **`windup_ticks`/`stun_ticks` reuse the same shared fields every other move already has** — the
## landing window *is* `Pattern.STUN`, per this file's own header ("one field is the window to hit for both
## bosses").
##
## **Does the rooster break terrain on landing** — `stage1-bosses.md`'s own TBD, explicitly undecided. **Not
## built here.** `LEAP` carries no `carve_r`.
##
## **Every number is a guess, not a measurement** — the same status as `MOVE_CHARGE`'s own values when they
## first shipped. `jump_vy_px`=-500 reaches **52px by the continuous formula** (`vy²/(2·GRAVITY_PX)`, the same
## one `body.gd`'s header cites for the player's own jump) — **but measured in-game it is 40px, 0.400s
## airtime, 153px across** (verify-run-b, `stage1-bosses.md` Stage F fix list). The gap is 60Hz Euler
## integration plus `move_y`'s integer-pixel rounding, not a bug — the continuous formula is an upper bound,
## not the real number. **The rooster's own box is 80px tall, so it leaps roughly half its own height** — the
## number to judge on screen, not 52px.
const MOVE_LEAP: Dictionary = {
	"windup_ticks": 14,      # 15 ticks = 0.750s telegraph
	"leap_max_ticks": 40,    # 41 ticks = 2.050s safety cap if it somehow never lands
	"stun_ticks": 20,        # 21 ticks = 1.050s landing window
	"leap_speed_mult": 2.0,
	"jump_vy_px": -500.0,
}

## `IDLE`'s duration (ticks) between moves — a boss-level value, not a per-move one (nothing about "how long
## to approach before committing" belongs to any one move). One shared constant, not a per-kind dict, because
## every kind with moves today shares it; split it out the day a kind needs its own.
const IDLE_TICKS := 20  # 21 ticks = 1.050s

## **`boss-entrance-and-hp-bar.md` Stage A/D — the entrance idle window.** Applied to the fresh monster's
## `pattern_left` only when `WorldStep.spawn_monster` is called with `entrance := true` **and** the kind has a
## pattern (`world_step.gd`'s own comment on why that gate, not `Monster._init`, is where this belongs) — so
## the boss walks a beat before its first `WINDUP`/roar instead of committing on the exact frame it appears.
## **Not `IDLE_TICKS`** — that value already has a job (the ordinary round-robin's own idle beat between
## moves) and is read every time `advance()` returns to `Pattern.STUN -> IDLE`; a shared constant would mean
## retuning the ordinary idle beat silently retunes the entrance too, and the reverse.
## **The cross-clock constraint** (`fx_tuning.gd`'s own comment on `BOSS_ENTRANCE_ZOOM_IN_FRAMES`/
## `BOSS_ENTRANCE_HOLD_FRAMES`): `ENTRANCE_IDLE_TICKS * Tuning.TICK_DIVIDER` must land strictly inside the
## camera's hold window, or the roar fires while the camera has already left the boss.
const ENTRANCE_IDLE_TICKS := 14  # 14 * TICK_DIVIDER(3) = 42 - inside the entrance camera's hold window

## **Stage H — "pattern durations... scale by integer ratios" at half health** (`stage1-bosses.md`'s own
## words, Order table row H). Applied at the single point every duration flows through on its way into
## `pattern_left` (`_phase_ticks`, below) — not baked into a second phase-2 row on each `MOVE_*` dict. A boss
## has one set of numbers; phase 2 is a multiplier read at the moment a duration is chosen, not a parallel
## table that could silently drift from the phase-1 one.
const PHASE2_DURATION_DIVISOR := 2
## **Only "charge speed" is named in the plan's own words** ("pattern durations and *charge speed*" — not a
## general pattern-speed multiplier). The rooster's own phase 2 reads through shorter windows between leaps
## (the duration divisor above), not a faster leap itself — `speed_mult` below only doubles the bull's own
## `CHARGE`. Provisional, same status as every number in this file; a later pass may decide the leap should
## speed up too, but that is not what the doc's own words commit to today.
const PHASE2_SPEED_MULT := 2.0


## Does this kind run the pattern machine at all. Trash mobs (`Defs.KIND_PIG`/`KIND_HEN`) do not — their
## `pattern` field stays at its default `Pattern.IDLE` forever, unread by anything (`Monster._next_axis`
## never reaches `_boss_axis` for them).
static func has_pattern(kind: int) -> bool:
	return MOVES.has(kind)


## **Stage H.** Scales one duration by `PHASE2_DURATION_DIVISOR` when `phase2` is true, otherwise returns it
## unchanged. `maxi(1, ...)` guards the smallest duration in the table today (`MOVE_GORE.active_ticks`=12 ->
## 6 at phase 2, nowhere near 0) — a future move with a 1-tick duration must not divide to 0 and freeze the
## tick machine returning to the same state forever (`pattern_left`=0 means "advance next tick", not "never").
static func _phase_ticks(v: int, phase2: bool) -> int:
	if not phase2:
		return v
	return maxi(1, v / PHASE2_DURATION_DIVISOR)


## The speed multiplier `Monster.step` applies to `Defs.speed_px` — 1.0 outside `CHARGE`/`LEAP`, or for any
## kind with no matching move. **`Pattern.LEAP` is shared by two different kinds' own moves** (the rooster's
## leap, the bull's slam — both stage1-bosses.md Stage G's own words, "reuses F"), so the pattern alone is not
## enough to pick a multiplier; `kind` still decides which move's own number applies.
## **`phase2` only touches the `CHARGE` branch** — see `PHASE2_SPEED_MULT`'s own comment on why the leap
## branches are untouched.
static func speed_mult(kind: int, pattern: int, phase2: bool = false) -> float:
	if pattern == Pattern.CHARGE and kind == Defs.KIND_BULL:
		var base := float(MOVE_CHARGE["charge_speed_mult"])
		return base * PHASE2_SPEED_MULT if phase2 else base
	if pattern == Pattern.LEAP and kind == Defs.KIND_ROOSTER:
		return float(MOVE_LEAP["leap_speed_mult"])
	if pattern == Pattern.LEAP and kind == Defs.KIND_BULL:
		return float(MOVE_SLAM["leap_speed_mult"])
	return 1.0


## The charge impact's carve radius (cells) — Stage C. 0 for any kind with no charge move, so a caller does
## not need its own kind guard on top of this one.
static func carve_r(kind: int) -> int:
	if kind != Defs.KIND_BULL:
		return 0
	return int(MOVE_CHARGE["carve_r"])


## The fire breath's reload (ticks) between bolts while `Pattern.FIRE` holds — Stage D. 0 for any kind with
## no fire move (a `0` reload would fire every tick, so callers must still gate on `pattern == Pattern.FIRE`
## themselves, the same discipline `ready_to_fire` already holds for the hen's own gate).
static func fire_reload_ticks(kind: int) -> int:
	if kind != Defs.KIND_BULL:
		return 0
	return int(MOVE_FIRE["reload_ticks"])


## The distance (px, center to center) inside which gore substitutes for a charge — Stage E. 0 for any kind
## with no gore move, so "closer than 0px" is never true and the substitution never fires by accident.
static func gore_range_px(kind: int) -> float:
	if not GORE_MOVES.has(kind):
		return 0.0
	return float(GORE_MOVES[kind]["range_px"])


## The upward velocity (px/s, negative = up) `Monster.on_tick` applies the instant `WINDUP` hands off to
## `Pattern.LEAP`. **Keyed on `kind` alone, not `kind` + `move_choice`** — safe because each kind that has a
## leap-shaped move has exactly one (the rooster's leap, the bull's slam), so there is no case where the same
## kind could be entering `LEAP` for two different reasons. 0 for any kind with no leap-shaped move, so a
## stray call cannot launch a kind that has no business leaving the ground.
static func leap_jump_vy_px(kind: int) -> float:
	if kind == Defs.KIND_ROOSTER:
		return float(MOVE_LEAP["jump_vy_px"])
	if kind == Defs.KIND_BULL:
		return float(MOVE_SLAM["jump_vy_px"])
	return 0.0


## The slam impact's ignite radius (cells) for one point of the outward ring — Stage G. 0 for any kind with
## no slam move, so a caller does not need its own kind guard on top of this one (the same contract `carve_r`
## already holds).
static func slam_ignite_r(kind: int) -> int:
	if kind != Defs.KIND_BULL:
		return 0
	return int(MOVE_SLAM["ignite_r"])


## How many cells apart each ignite point sits along the ground, outward from the impact centre — Stage G.
static func slam_ignite_spread_cells(kind: int) -> int:
	if kind != Defs.KIND_BULL:
		return 0
	return int(MOVE_SLAM["ignite_spread_cells"])


## How many points get ignited in total (symmetric outward from the impact centre) — Stage G.
static func slam_ignite_points(kind: int) -> int:
	if kind != Defs.KIND_BULL:
		return 0
	return int(MOVE_SLAM["ignite_points"])


## **Advances the tick machine by exactly one 20Hz tick.** A pure function over plain values, not over
## `Monster` — `Monster` already preloads this file, and the reverse edge would cycle. Returns
## `[next_pattern, next_pattern_left, next_pattern_dir, next_move_choice]`.
##
## `blocked` is whether this tick's preceding `Monster.step()` calls found `move_x` returning true while
## charging — **the only channel a 60Hz collision reaches this 20Hz clock through** (`Monster._charge_blocked`,
## set in `step`, read and cleared here). `landed` is the same idiom for the rooster's leap — did `step()`
## find the body back on the ground. `axis_toward_target` is the sign of "player minus me" at this exact
## tick — read only at the instant a move's active state **begins** (the `WINDUP -> CHARGE`/`FIRE`/`GORE`/
## `LEAP` transition below) and then discarded; `pattern_dir` carries it forward from there. Reading it every
## tick during `CHARGE` itself would let the bull steer mid-run, and "runs straight at the player" (the
## design doc's own words) is the point — the fire breath, the gore swing and the leap's arc all lock the
## same way, for the same reason. `in_gore_range` is read at that same instant, for the same reason — a
## charge already launched does not abort into a gore just because the player closed the distance mid-run.
## `phase2` (Stage H) scales every duration chosen below through `_phase_ticks` — the single point every
## `pattern_left` assignment in this function flows through, so no transition can forget to scale.
static func advance(kind: int, pattern: int, pattern_left: int, pattern_dir: int, move_choice: int,
		blocked: bool, axis_toward_target: float, in_gore_range: bool, landed: bool, phase2: bool = false) -> Array:
	if not MOVES.has(kind):
		return [pattern, pattern_left, pattern_dir, move_choice]
	var moves: Array = MOVES[kind]

	# **Checked before the countdown, every tick.** A charge that hits a wall, or a leap that touches down,
	#  ends the moment that is *noticed* — the next tick after it happens — not whenever its own safety-cap
	#  timer happens to run out. This is why `blocked`/`landed` bypass `pattern_left` entirely instead of
	#  being folded into it. The fire breath and the gore swing have no equivalent early-out — they always
	#  run their full duration.
	if pattern == Pattern.CHARGE and blocked:
		return [Pattern.STUN, _phase_ticks(int(MOVE_CHARGE["stun_ticks"]), phase2), pattern_dir, move_choice]
	if pattern == Pattern.LEAP and landed:
		return [Pattern.STUN, _phase_ticks(_leap_stun_ticks(kind, move_choice), phase2), pattern_dir, move_choice]

	if pattern_left > 0:
		return [pattern, pattern_left - 1, pattern_dir, move_choice]

	if pattern == Pattern.IDLE:
		# **Selection — round-robin, not random.** This file sits one door from `src/sim/`, which forbids
		#  `randi` for determinism; alternating is also "brainless" per the design doc, and it is testable
		#  without seeding anything. `monsters.md` flagged "which move runs next" as undecided the day a
		#  second move arrived — this is that decision, made here rather than deferred again. Gore is not
		#  one of the choices here — it can only ever replace a `CHARGE` pick, below. **A one-element `moves`
		#  array (the rooster) always resolves to index 0** — `(x + 1) % 1 == 0` for every `x` — so this same
		#  line covers "there is only one move" without a special case.
		var next_move: int = (move_choice + 1) % moves.size()
		var next_windup: int = _phase_ticks(int(moves[next_move]["windup_ticks"]), phase2)
		return [Pattern.WINDUP, next_windup, pattern_dir, next_move]
	if pattern == Pattern.WINDUP:
		var dir := pattern_dir
		if axis_toward_target != 0.0:
			dir = signi(int(axis_toward_target))
		if kind == Defs.KIND_ROOSTER:
			return [Pattern.LEAP, _phase_ticks(int(MOVE_LEAP["leap_max_ticks"]), phase2), dir, move_choice]
		# **Stage G — the slam reuses `Pattern.LEAP`, the rooster's own physics, for a bull move.** Checked
		#  before `FIRE`/`CHARGE` below only because it must be checked somewhere before the bull's fall-through
		#  guard; the three `move_choice` branches are mutually exclusive by construction (round-robin only ever
		#  picks one value), so the order among them carries no meaning.
		if move_choice == MoveChoice.SLAM:
			return [Pattern.LEAP, _phase_ticks(int(MOVE_SLAM["leap_max_ticks"]), phase2), dir, move_choice]
		if move_choice == MoveChoice.FIRE:
			return [Pattern.FIRE, _phase_ticks(int(MOVE_FIRE["breathe_ticks"]), phase2), dir, move_choice]
		# CHARGE was chosen, but gore substitutes for it in its own dead zone (Stage E). `move_choice` stays
		#  CHARGE either way — gore is "what a charge became this time," not a separate turn in the rotation.
		if move_choice == MoveChoice.CHARGE and in_gore_range and GORE_MOVES.has(kind):
			return [Pattern.GORE, _phase_ticks(int(MOVE_GORE["active_ticks"]), phase2), dir, move_choice]
		# **The fall-through this file's header warns about.** Only the bull is meant to land here — its own
		#  charge. Any other kind reaching this line has a `MOVES` row (it passed the guard at the top of this
		#  function) but no `kind ==` branch of its own above, so it would silently run the bull's charge
		#  instead — no error, just the wrong boss doing the wrong thing forever. Barking here is what makes
		#  "one new kind = one row in `MOVES`" true again instead of "...and hope nobody forgets the branch".
		if kind != Defs.KIND_BULL:
			push_error("BossAi.advance: kind %d has a MOVES row but no WINDUP branch of its own - it fell through to the bull's charge" % kind)
		return [Pattern.CHARGE, _phase_ticks(int(MOVE_CHARGE["charge_max_ticks"]), phase2), dir, move_choice]
	if pattern == Pattern.CHARGE:
		# The safety cap ran out with no wall found.
		return [Pattern.STUN, _phase_ticks(int(MOVE_CHARGE["stun_ticks"]), phase2), pattern_dir, move_choice]
	if pattern == Pattern.FIRE:
		return [Pattern.STUN, _phase_ticks(int(MOVE_FIRE["stun_ticks"]), phase2), pattern_dir, move_choice]
	if pattern == Pattern.GORE:
		return [Pattern.STUN, _phase_ticks(int(MOVE_GORE["stun_ticks"]), phase2), pattern_dir, move_choice]
	if pattern == Pattern.LEAP:
		# The safety cap ran out without a landing ever being noticed (should not happen — gravity always
		#  wins eventually — kept as a defensive net, the same idiom as the charge's own safety cap).
		return [Pattern.STUN, _phase_ticks(_leap_stun_ticks(kind, move_choice), phase2), pattern_dir, move_choice]
	# Pattern.STUN
	return [Pattern.IDLE, _phase_ticks(IDLE_TICKS, phase2), pattern_dir, move_choice]


## Which move's recovery window applies once a `Pattern.LEAP` ends, however it ends (landed or safety-cap
## timeout) — shared physics, not a shared stun length. **Two call sites, one function** — inlining this
## branch at both would let one of them drift and only the other get fixed the day these numbers diverge.
static func _leap_stun_ticks(kind: int, move_choice: int) -> int:
	if kind == Defs.KIND_BULL and move_choice == MoveChoice.SLAM:
		return int(MOVE_SLAM["stun_ticks"])
	return int(MOVE_LEAP["stun_ticks"])
