extends RefCounted
## The monster kind table. The precedent is `src/sim/glyph_defs.gd` — id constants + a `DEFS` dictionary +
##  an explicit `ALL` list + static accessors. **One new kind = one line here.**
##
## What is deliberately not in the table right now — put it in and it reads as "this value is live", and that
##  is a false knob: "how it attacks", "damage taken", "fire DPS" (stages 5 and 6).
##  "Damage taken 10" and "fire DPS 10/s" get no columns in the table —
##  `monsters-minimum`, "behavior (7)" pinned "use the player's constants verbatim. No axes are added".
##
## **`jump_vy_px` is not one of those false knobs** (`monster-ai-jump-and-separation.md`,
##  Stage A) — it is mobility, read every frame `move_x` reports blocked, the same shape `speed_px` and
##  `step_cells` already are. **The bosses carry the same real value the trash mobs do, not an inert `0.0`**
##  (team-lead's own correction: a placeholder made the kind gate untestable — removing
##  `not BossAi.has_pattern(kind)` from `monster.gd:step()` alone launched nothing when the value was 0,
##  so no mutation could prove the gate was what stood between a bull and room ①'s wall). The actual gate is
##  `BossAi.has_pattern(kind)`, checked before this column is ever indexed — this column is the number a
##  boss *would* launch at if that gate ever failed, not a value anything reads while it holds.
##
## The stage each column is first read in: `w_px`, `h_px`, `step_cells` and `max_hp` = stage 1 · `speed_px` =
##  stage 2 · `invuln_ticks` = stage 3. `speed_px` went in from the start in order to establish that the box
##  and the gait come from **the same table** — `invuln_ticks` lives here for the same reason (the player has
##  a single constant, monsters can differ per kind so it is a table cell. Both values are 2 ticks right now).

## A reserved value. The death notification arrays (`_died_kind`) and the view carry the kind as an integer,
##  and **if 0 were a valid kind, a cleared slot would silently be drawn as a pig.**
##  Two precedents: `glyph_defs.GLYPH_NONE = 0` ("the end of the list is 0 itself") ·
##  why `spell_view._elem_id` gives -1 for a dead slot ("falling to 0 nearly drew a nonexistent projectile as fire").
const KIND_NONE := 0
const KIND_PIG := 1
const KIND_HEN := 2
const KIND_BULL := 3
const KIND_ROOSTER := 4
## **The wolf** — `docs/design/monsters.md`'s own "the wolf is tawny/chestnut, brighter than the pig and
##  warmer than the dirt" (the user's rule: species are told apart by brightness first). Its art landed with a
##  full animation set and **the row it needed to exist at all is this one** — until now it was "art on disk
##  and nothing more", that doc's own words.
## **It is assigned to stage 1 now** (`monster-placement-stage1.md`, the user's call —
##  stage 1's trash roster is pig + hen + wolf, not the pair this comment used to name) —
##  **placement is still the map's share, not this table's**; `src/stage/stage1_monsters.gd` is that share.
const KIND_WOLF := 5

## Iteration goes **only through this explicit list**. It does not assume the values are contiguous.
const ALL: Array[int] = [KIND_PIG, KIND_HEN, KIND_BULL, KIND_ROOSTER, KIND_WOLF]

## 20 is a value decided by the user — not a value to measure and adjust.
const MAX_MONSTERS := 20

## `xp`/`money` are **per-kind by nature, not "how it attacks"** — the header above excludes damage-taken and
##  fire-DPS columns because those read as "this value is live" (a false knob), but a pig being worth more
##  than a hen is a plain fact about the kind (`levelup-and-three-picks.md`, Stage B).
##  Provisional values from that plan's own table — knobs to turn once XP is on screen, not by the user yet.
const DEFS: Dictionary = {
	KIND_PIG: {
		"name": &"돼지", "w_px": 44, "h_px": 32, "step_cells": 1,
		"max_hp": 30, "speed_px": 160.0, "invuln_ticks": 2,
		"xp": 12, "money": 5,
		# **−520, a proposal, not a decision** (the plan's own TBD — "the user has not seen any of it move").
		#  `vy²/(2·GRAVITY_PX)` = 56.3px computed; **measured (`net_monster._real_jump_apex_is_measured`,
		#  driven — a pig against a 60-cell wall, one clean rise): 61px, *above* the formula, not under it.**
		#  The bull/rooster's own recorded shortfalls (9.5%/23% under) do not transfer — this launch sits
		#  after `step()`'s own `apply_gravity`, theirs before it.
		#
		#  ⚠ **THIS VALUE IS NOT DECIDED ON SCREEN YET, and the 2-tile pit's containment holds by exactly
		#  3px (64px pit − 61px apex) — not the ~14px the doc's own "56 computed, ~50 real" estimate implied.**
		#  `net_monster._real_jump_apex_is_measured` asserts this margin as a value (`== 3`), not just
		#  "still under 64" — so the day gravity, this number, or the jump sheet's `hold` moves the real apex,
		#  that check names the new margin instead of quietly staying green until the 2-tile pit also escapes.
		"jump_vy_px": -520.0,
	},
	# **24x28 -> 48x64 when the enlarged art landed** (`monsters.md`: "the trash mobs are too small", the
	#  user's decision, and `hen_body.png` is 48x64). **The picture is what moved this, not a tuning pass** —
	#  the box follows the art because `net_monster_sprite` asserts the two are equal.
	#
	# **A gameplay property was lost with it, and it is not a bug**: at 24px the hen fit through a 32px gap
	#  and the pig did not, which was the narrow-mob-drops-through-a-hole behaviour `net_monster._monster_
	#  collision_width_gates_the_chimney` measured. **At 48px nothing in the table is narrower than the pig**,
	#  so that check now measures the pig against the bull instead. If "one mob slips through gaps" is wanted
	#  back, it needs a *narrow* kind, not a smaller hen.
	#
	# **The cost is 4.6x, and it is measured, not assumed** — see the profile table below.
	KIND_HEN: {
		"name": &"닭", "w_px": 48, "h_px": 64, "step_cells": 3,
		"max_hp": 10, "speed_px": 220.0, "invuln_ticks": 2,
		"xp": 6, "money": 3,
		"jump_vy_px": -520.0,
	},
	# **`w_px`/`h_px` are not free here** — `stage1-bosses.md` Risk 1: `net_monster_sprite` asserts the sheet
	#  equals the box, and `net_monster._defs_preconditions` asserts the box is a `Tuning.CELL_PX`(4) multiple
	#  (every other kind already satisfies both). `bull_body.png`'s art came out at 86x54 (4x → downscale,
	#  the trash-mob pipeline), which fails the second contract — so the png was padded to 88x56, the original
	#  86x54 pixels placed unmoved at (1, 2): 1px transparent margin left/right, 2px on top, **0px on the
	#  bottom** (so the feet-on-the-last-row contract carries over, and 1px symmetric each side keeps
	#  `minx+maxx == w-1`). No pixel resampled — this is not the "regenerate, don't scale" case.
	#  `rooster_body.png` (72x80) already satisfied both contracts untouched.
	# `max_hp`/`speed_px`/`xp`/`money` are provisional — `stage1-bosses.md`'s own TBD ("skeleton first, set on
	#  screen"). `invuln_ticks` is carried over unexamined from the trash-mob table.
	# `step_cells` = 3 for both — `net_monster._pig_and_hen_cross_the_ledge_differently` hardcodes a binary
	#  contract ("pig is blocked at a 3-cell ledge, every other kind clears it"), so any kind added to `ALL`
	#  inherits "clears a 3-cell ledge". A big body stepping a 3-cell ledge is fine fiction for the bull too.
	KIND_BULL: {
		"name": &"황소", "w_px": 88, "h_px": 56, "step_cells": 3,
		"max_hp": 300, "speed_px": 140.0, "invuln_ticks": 2,
		"xp": 200, "money": 100,
		# **Correction (team-lead, measured): a `0.0` placeholder was a false handle here** — it made the kind
		#  gate (`not BossAi.has_pattern(kind)` in `monster.gd:step()`) untestable, since removing the gate
		#  alone launched nothing regardless (measured directly: every check stayed green). A real value —
		#  the same one the trash mobs carry — means **the gate is the only thing standing between this row
		#  and a bull hopping out of room ①'s left boundary**, which is the actual reason `has_pattern` was
		#  chosen over a pattern check (`Pattern.IDLE` walks brainlessly forward, `monster.gd:_boss_axis`'s
		#  own fallback, with nothing else stopping it). The bull's own airborne move is still `bull_slam`, a
		#  different door (`BossAi.leap_jump_vy_px`) — this column is never reached while a real pattern runs.
		"jump_vy_px": -520.0,
	},
	KIND_ROOSTER: {
		"name": &"거대 수탉", "w_px": 72, "h_px": 80, "step_cells": 3,
		"max_hp": 250, "speed_px": 200.0, "invuln_ticks": 2,
		"xp": 250, "money": 120,
		"jump_vy_px": -520.0,  # Same correction, same reason as the bull's row above.
	},
	# **48x28 is the art's own size** (`wolf_body.png`), already a multiple of 4 on both sides — no padding,
	#  unlike the bull. Long and low: wider than the pig and barely half its height.
	# **Every number except the box is provisional and nobody has set them** — "skeleton first" (`monsters.md`
	#  leaves health, damage and movement speed TBD for exactly this reason). The shape chosen: **faster than
	#  the pig and thinner** (240 vs 160 px/s, 24 vs 30 hp), because the art is a lunging predator and the
	#  pig's identity is already "a big body that falls into a pit".
	# **It has no lunge in the sim.** `wolf_lunge.png` plays when it is in contact range, the same door the
	#  pig's shove uses — the picture shows an attack when an attack happens, but the *dash* the art implies is
	#  not a mechanic. `boss_ai` is where a real lunge would go, and it is not built.
	KIND_WOLF: {
		"name": &"늑대", "w_px": 48, "h_px": 28, "step_cells": 3,
		"max_hp": 24, "speed_px": 240.0, "invuln_ticks": 2,
		"xp": 15, "money": 6,
		"jump_vy_px": -520.0,
	},
}

## **A trash mob's melee — how close it must get, how hard it hits, and how long it waits after.**
##
## **Why it is a separate table and not three columns in `DEFS`**: only two kinds have one. The hen and the
##  rooster throw, the bull owns `boss_ai`'s patterns, and a `melee_range_px: 0` row on those would be a
##  false knob — a value that reads live and does nothing. **A kind missing here has no melee**, which is
##  what `has_melee` asks and what every caller branches on.
##
## **What it replaced was contact damage, and that is the whole point.** A pig used to damage the player on
##  **every tick their boxes overlapped**, gated by nothing but invulnerability — so the fight was walking
##  into the player and staying there. The user's word for it was 비비비 비비니까 재미가 없고.
##  ⇒ **`cd_ticks` is the beat**: hit, wait, hit. At 20Hz a pig's 20 is one second between swings and a
##  wolf's 14 is 0.7 — the wolf is the faster, lighter threat, exactly as its speed already says.
##
## **`range_px` is a horizontal widening of the mob's own box, not a radius** — measured centre to centre it
##  would let a mob standing on the player's head swing at them. `world_step` widens the box and asks the same
##  overlap question it already asks, so "can it reach me" keeps one definition.
##
## **The damage is the old contact value for the pig (8), unchanged deliberately** — it now lands once a
##  second instead of continuously, which is the nerf; changing the number in the same edit would make the two
##  effects impossible to tell apart on screen. **The wolf had no damage at all** (no branch existed in
##  `world_step._char_hit_by_monsters`, so it was a harmless decoration) — 10 is a first value, unseen.
##
## **`net_monster` names these two kinds literally rather than iterating this table** — deleting a row here
##  left a table-driven check green, measured. Growing this table means growing that list on purpose.
const MELEE: Dictionary = {
	KIND_PIG: {"range_px": 12.0, "damage": 8, "cd_ticks": 20},
	KIND_WOLF: {"range_px": 16.0, "damage": 10, "cd_ticks": 14},
}


static func has_melee(kind: int) -> bool:
	return MELEE.has(kind)


## **0.0 when the kind has no melee**, which reads at the call site as "never in range" — the same
## substitute-do-not-bark discipline `monster_view._load_sheets` holds for a missing sheet.
static func melee_range_px(kind: int) -> float:
	return float(MELEE.get(kind, {}).get("range_px", 0.0))


static func melee_damage(kind: int) -> int:
	return int(MELEE.get(kind, {}).get("damage", 0))


static func melee_cd_ticks(kind: int) -> int:
	return int(MELEE.get(kind, {}).get("cd_ticks", 0))


## **The cost table. Re-take it with `tools/stage/profile_monsters.gd`, do not edit it by hand.**
##  `stage1-bosses.md`'s Cost section asked whoever builds Stage A to leave the numbers here; the hen's box
##  then grew 4.6x and there was **no way to re-take them**, which is how a measured number becomes a stale
##  one. There is a tool now. Same method as verify-run's original: 600 frames warmed, 3 runs (median), one
##  `world.frame()` per frame, an empty world subtracted. 60Hz budget = 16,667µs.
##
##  | | box cells | 1 alive | % of 60Hz | **20 alive (measured)** | % of 60Hz | 자는 20마리 | % of 60Hz |
##  |---|---|---|---|---|---|---|---|
##  | 돼지 pig | 88 (44x32) | +219µs | 1.3% | **+4,648µs** | 27.9% | +705µs | 4.2% |
##  | 닭 hen | 192 (48x64) | +235µs | 1.4% | **+6,828µs** | 41.0% | +1,399µs | 8.4% |
##  | 황소 bull | 308 (88x56) | +433µs | 2.6% | +3,889µs | 23.3% | +2,152µs | 12.9% |
##  | 거대 수탉 rooster | 360 (72x80) | +696µs | 4.2% | +12,297µs | 73.8% | +2,536µs | 15.2% |
##  | 늑대 wolf | 84 (48x28) | +211µs | 1.3% | +4,984µs | 29.9% | +605µs | 3.6% |
##
##  **Re-taken whole** (`monster-placement-stage1.md` Stage D), not appended to — the old numbers directly
##  above this line stopped meaning what their own column headers said, for two separate reasons layered
##  on top of each other, both found by running the tool again rather than assumed:
##
##  1. **Separation (`monster_separation.gd`) landed after the old table and the old placement measured
##     zero of its cost.** The old spread (`200 + i*(w_px+8)`) kept every pair permanently non-overlapping,
##     so `Monster.try_shift_x`'s own `box_free` call — the only place separation actually costs anything —
##     never fired once. `_one_run` now clusters (`4px` apart, well inside every kind's own width) so a
##     real crowd's settling cost is in the number, the same shape converging on the player actually
##     produces. **This alone raised the 20-pig figure** (3,416 -> 4,648) — a real cost that was not being
##     measured, not a regression.
##  2. **Sleep (this same plan's Stage D) made the *old* placement measure the wrong thing entirely.**
##     `Monster.step()` now skips its own movement block while `asleep`, and the old placement stood the
##     character 3,200px away from every monster — past `MonsterPlacement.STIR_EXIT_PX`(560) from the very
##     first tick. Being asleep, those monsters never walked a single pixel closer, so they stayed asleep
##     the entire run. **Measured, not assumed**: with the old, unfixed placement the pig's own numbers had
##     silently dropped to +39µs/+679µs — an "awake" cost that was actually a sleeping one. `_one_run`'s
##     `sleeping` flag now makes this a deliberate, labelled scenario (the rightmost two columns) instead
##     of an accident the "awake" columns were quietly falling into.
##
##  **The asleep column is the sleep skip's own payoff, and it is not free** (`Monster.step()`'s own
##  header) — `_burn` still runs, and `Body.standing_in_fire` sweeps the box **plus one row under the
##  feet**: for the hen that is 12x17 = **204 cells**, the single largest sweep any monster does, which is
##  why the hen's asleep figure (+1,399µs) is not proportionally as cheap as the pig's or wolf's (+705µs /
##  +605µs) despite all three being trash mobs on the same flat, fireless floor this tool uses.
##
##  **Bull/rooster no longer scale the naive way, and that is boss-pattern behavior, not a measurement
##  bug.** Clustering 20 bulls near one character puts many of them inside gore range at once — `GORE`
##  freezes the axis the same way `WINDUP`/`STUN`/`FIRE` already do, so a clustered bull pays the same
##  `grounded()` sweeps but skips `move_x`'s own work more often than a single, always-charging bull does.
##  20 real bulls landing *under* the 1-bull-x-20 projection (3,889 vs 8,665) is that effect, not a
##  suspiciously-cheap number — 20 bulls is still not a real scene either way (Cost section, above).
##
##  **Empty world: 74µs.**
##
##  **What this still does not measure**: monsters *plus* fire plus water on one screen. `monsters.md`'s "the
##  problem is not monsters alone but the overlap" is untouched, and water's acceptance 7 is still open.

## **Index `DEFS[kind][...]` directly.** Do not use `.get(..., default)` —
##  a kind missing from the table silently becomes a pig. `character_view._cell_rect` recorded the same discipline.
static func name_of(kind: int) -> StringName:
	return DEFS[kind]["name"]


static func w_px(kind: int) -> int:
	return DEFS[kind]["w_px"]


static func h_px(kind: int) -> int:
	return DEFS[kind]["h_px"]


static func step_cells(kind: int) -> int:
	return DEFS[kind]["step_cells"]


static func max_hp(kind: int) -> int:
	return DEFS[kind]["max_hp"]


static func speed_px(kind: int) -> float:
	return DEFS[kind]["speed_px"]


static func invuln_ticks(kind: int) -> int:
	return DEFS[kind]["invuln_ticks"]


static func xp_of(kind: int) -> int:
	return DEFS[kind]["xp"]


static func money_of(kind: int) -> int:
	return DEFS[kind]["money"]


## **The launch velocity `monster.gd:step()` gives a blocked, grounded trash mob.** Bosses hold `0.0` here
##  but never reach it — `BossAi.has_pattern(kind)` is the actual gate (this file's own header).
static func jump_vy_px(kind: int) -> float:
	return DEFS[kind]["jump_vy_px"]
