# Monster AI — it jumps when blocked, and mobs stop standing inside each other

**Status**: implemented (A~E) · **verified** · **screen unverified**.
verify-read reported: **four false greens, two checks that measured nothing, one real bug — all fixed.**
**7171 checks, 0 failures, 31 nets.** What is left is the screen, and **the 3px margin the whole feature
turns on has never been seen move.** See "What landed" below.
**One line**: trash mobs gain **exactly two** behaviours — **jump when `move_x` says blocked**, and **push apart
when boxes overlap** — so that walling them off becomes a skill instead of a formality, and a pack reads as a
pack instead of one flickering blob.

**Design doc**: [../../design/monsters.md](../../design/monsters.md) — "How they find you — brainlessly. And
that is temporary" / "AI is deferred; the slot is left open". This is the first thing to enter that slot for a
**trash mob** (the bosses entered it first, `../3.done/stage1-bosses.md`).
**Sibling**: [monster-placement-stage1.md](monster-placement-stage1.md) — where the mobs stand. Written the
same session, deliberately separate (user's instruction).

---

## Why

**The user's words**: "가두는 것도 조금 어렵게, 성공이 가능해야지. 너무 쉽게 성공하면 재미없어."

Today a pit is not a skill. **Any** hole traps **any** trash mob, because a trash mob cannot leave the ground
under its own power. The terrain is this game's thesis and its most-used verb, and right now the terrain
answer to every mob is the same one hole.

Give them a jump and a number appears that did not exist: **how deep a pit has to be.** That number is the
whole point. Below it the terrain does nothing; above it the terrain wins. **That is what makes digging a
skill rather than a formality.**

The second half is smaller and the user named it directly — "겹쳐서 부르르 떠는 것도 좀 이상하더라고". Twenty
mobs that all walk toward one point end up **occupying the same pixels**, and the screen shows one flickering
silhouette with twenty health bars stacked on it.

---

## Behavior

### 1. Jump when blocked

`body.move_x()` **already returns `true` when it could not move**, and today **only a charging bull reads it**
(`monster.gd:157`). Every trash mob throws that signal away and keeps pressing into the wall forever.

```
if move_x(...) returned blocked  and  on_ground  and  the axis was not 0
    vy = MonsterDefs.jump_vy_px(kind)
```

- **`allow_step` still runs first.** `body._try_step_up` handles anything within `step_cells`
  (pig 4px, everyone else 12px) by walking up it. The jump only fires for what a step cannot clear —
  so an ordinary slope never makes a mob hop, and **a wall does**.
- **It fires on the frame it is blocked, not on a timer.** A mob pressed into a wall it cannot clear will
  jump repeatedly. **That is correct and it is the picture we want**: "it is trying to get out and cannot"
  reads as trapped. A mob that stands still at the bottom of a pit reads as broken.
- **Only when `on_ground`.** Without this it becomes a flying mob, which `monsters.md` explicitly does not
  have a way to hit yet ("There is currently no way to hit a flyer").
- **It lives inside the movement half of `step()`, not inside `_next_axis()`.** `_next_axis` answers "which
  horizontal direction", and its header pins that meaning ("where does the next step go"). A jump is a
  vertical impulse and a *reaction to the result of moving* — it cannot be computed before `move_x` runs.
  **Do not widen `_next_axis`'s contract to carry it.**

### 2. The number this creates — pit depth

`vy²/(2·GRAVITY_PX)` with `GRAVITY_PX` = 2400 (shared with the player, `character.gd:91` — **no second gravity
axis**, the same discipline `monster.gd` already records for falling).

| | `jump_vy_px` | apex | in cells | in tiles |
|---|---|---|---|---|
| Player | −720 | **108px** | 27 | 3.4 |
| Rooster leap | −500 | 52px | 13 | 1.6 |
| Bull slam | −450 | 42px (**38px measured**) | 10 | 1.2 |
| **Trash mob (proposed)** | **−520** | **56px** | **14** | **1.75** |

⇒ **A 1-tile pit (32px) is hopped out of. A 2-tile pit (64px) holds.**

That is the contract this whole plan exists to create, and −520 was picked to land it cleanly with margin on
both sides (56 is comfortably over 32 and comfortably under 64). **It is one number in
`monster_defs`, per kind**, so a heavier pig can be given a worse jump later without touching this logic.

**The measured apex will be lower than the formula** — the bull's −450 computes to 42px and measured 38px
(`boss_ai.gd:158`), because the apex is sampled at frame boundaries and a body stops at the last free pixel.
Expect ~10% under. **56px computed is ~50px real**, still clear of 32 and clear of 64. **verify-run measures
the real apex; do not ship the formula's number as the contract.**

### 3. Separation — mobs push each other apart

**The failure to avoid is the one the user already saw: the shudder.** It has a specific cause. Naive
separation moves A away from B and B away from A every frame; when **one of them is against a wall or in a
corner**, its half of the correction is refused by `box_free`, so the pair never resolves and both vibrate at
frame rate forever.

The rules that prevent it:

- **A push is a position correction, not a velocity.** It resolves this frame or it does not happen.
- **Ask `box_free` before moving.** If the corrected position is inside terrain, **do not move at all** —
  do not "move as far as possible". Partial moves are what re-trigger next frame.
- **Below a threshold overlap, do nothing.** Perfectly resolving to zero overlap is what makes a pack
  oscillate around the boundary. A small permitted overlap (a few px) is invisible and stable.
- **Horizontal only.** Vertical separation fights gravity and grounding every frame; a mob standing on
  another mob's head is not a thing this game has (mobs are not solid to each other, only *separated*).
- **Order-independent, or the nets cannot measure it.** Iterating the monster array in a different order must
  not produce a different result — CLAUDE.md's own recorded failure ("iteration order was reversed, final
  state was identical, three checks stayed green"). Compute all corrections from the pre-move snapshot, then
  apply. **A check that reads only final state cannot measure this**; the net must measure the process.

**Mobs do not block each other.** They separate. A wall of pigs that physically stops the player was
considered and is not this — see TBD.

### 4. What is deliberately NOT added

- **No pathfinding, no wall-following, no digging.** `monsters.md` rejected pathfinding for a reason that is
  not performance: "**dig and they walk around, and trapping stops being a tactic**". Wall-following is the
  same rejection wearing a cheaper hat.
- **A mob that breaks through walls is a later kind, not a later behaviour** (user: "나중에는 벽을 뚫는
  애도 있는데 일단은 뛰는 애들로만 채우자"). It belongs in `monster_defs` as a kind with its own move, the
  way the bull's carve does — **not as a branch inside this jump.**
- **`_next_axis` is not touched.** It stays the one line of "toward the player". Everything here is in the
  movement half of `step()`.

---

## Screen

### The gap — **there is no airborne sprite for any kind**

Checked against `fx_tuning.MONSTER_ANIM` and `assets/monster/` (57 pngs). Every kind has
`idle · walk · attack · hurt · death`; **not one has a jump or fall frame.**

| Kind | idle | walk | attack | hurt | death | **airborne** |
|---|---|---|---|---|---|---|
| 돼지 pig | 4f | 9f | `pig_shove` 8f | 4f | 8f | **none** |
| 닭 hen | 4f | 8f | `hen_throw` 8f | 4f | 8f | **none** |
| 늑대 wolf | 4f | 8f | `wolf_lunge` 8f | 4f | 8f | **none** |
| 황소 bull | 5f | 9f | `bull_gore` 17f | — | 7f | `bull_slam` (its own move) |
| 거대 수탉 rooster | 5f | 9f | — | — | 7f | `rooster_leap` (its own move) |

**The attack side is already wired and needs nothing** — `monster_view._is_attacking` drives the pig's and
wolf's by box contact (8px early, so the picture is a tell and not a report) and the hen's by a fire latch.
**The user asked whether attack animations exist: they do, for all three trash mobs, and they already play.**

**The jump does not have that luxury.** Make them jump today and a pig sails through the air playing its walk
cycle, legs churning.

⇒ **Decided by the user: the art gets made.** `MON_AIRBORNE` becomes a real state with a real sheet per trash
mob, matching the player (which has both `CHAR_JUMP` and `CHAR_FALL`).

The route is the same one every other monster sheet took (`tools/pixel/README.md`: pixellab `animate_image`
from the standing frame, "this is the one thing local cannot do" — the local walk LoRA is human-only).
**The inputs must be quantized to ~12 colors first** — past ~3,000 base64 characters the MCP client silently
truncates and the call returns "could not decode image".

#### The trap this hit, measured — **`animate_image` will not lift the feet off the bottom row**

First attempt, three kinds, seeds 7301–7303, action phrased as "leaping upward … all four legs tucked under
the belly". **All three came back with every foot still on the bottom row on all four frames.** Measured, not
eyeballed: `maxy == h-1` on every frame of every sheet. The pig reads as a head-butt, the wolf is
indistinguishable from its walk.

**The cause is composition, not wording** — the standing frame fills its box down to the last row, and the
model preserves that. "Tucked under the belly" was already in the prompt and changed nothing.

⇒ **Give it ground clearance in the input.** The sprite goes on a canvas taller than the box with the empty
space **underneath** it (pig 44×32 → 44×48), so "airborne" becomes something the picture can express, and the
result is cropped back to the box afterwards.

⇒ **And frame 0 of the sheet is the standing body, not a generated frame.** `net_monster_sprite` holds frame 0
to "the feet touch the bottom row" (and exempts every later frame — a charging bull is airborne on 4 of its 9).
A jump that starts on the ground and leaves it satisfies that contract **by being what a jump actually is.**

**Ground clearance alone fixed the pig and did not fix the wolf or the hen** (seeds 7311–7313) — both came
back with legs still extended. What fixed those two was **pinning the last frame**: `animate_image` takes a
`last_frame`, which turns the call from open-ended animation into interpolation toward a pose. The target
pose was made mechanically — **the sprite's own content with its bottom N px cut off**, which is the nearest
thing to "legs tucked under the belly" that can be produced without drawing a pixel by hand
(`monsters.md`: hand-pixeling is blocked by the user). **Only the frames near the end of an interpolation are
usable**; the early ones are still standing.

#### The sheets, as shipped

| Kind | Sheet | Box | Frames | Seed | Route |
|---|---|---|---|---|---|
| 돼지 pig | `pig_jump.png` | 44×32 | **3** | 7311 | clearance only |
| 늑대 wolf | `wolf_jump.png` | 48×28 | **3** | 7322 | clearance + pinned last frame |
| 닭 hen | `hen_jump.png` | 48×64 | **3** | 7323 | clearance + pinned last frame |

**Frame 0 = the standing body verbatim** (feet on the bottom row), frames 1–2 = airborne, seated **2px above
the bottom row**. Not flush and not floating: the box itself is what rises, so the sprite only has to say
"the feet just left the ground". Measured on all three: frame 0 passes both `maxy == h-1` and
`minx + maxx == w-1`.

**Nobody has seen them move in the game.** They are on disk and wired to nothing — `MONSTER_ANIM` is code and
another session is editing `src/`.

**Wire it as `loop: false`, `frames: 3`.** A jump is a one-shot that holds its last cell — the same call
`MON_DEATH` and `MON_ATTACK` already make, and it is what makes the pose read as "in the air" rather than as
a stutter. **The `frames` count is written down and not derived from the png width** — `net_monster_sprite`
compares the two, so a truncated import goes red instead of silently playing a shorter loop.

⇒ **Three edits, no structure change**: one state constant (`MON_AIRBORNE`), one resolve branch
(`not _body.on_ground`), three rows in `MONSTER_ANIM`.

**`MON_AIRBORNE` must be resolved before `MON_WALK` and after `MON_HURT`/`MON_DEATH`** — a mob in the air is
moving horizontally too, so a walk-first order would never show the jump at all. **The bosses have no row
here and must fall through to their own patterns**; `monster_view.resolve_state` already resolves patterns
first, so this falls out of the existing order rather than needing a kind check.

### Separation has no screen of its own

Nothing is drawn for it. **What changes is that twenty health bars stop stacking into one column.**
It is judged by verify-look on a pack of 20, and there is no headless substitute.

---

## Bounds

| Situation | What must happen |
|---|---|
| **A mob in a 1-tile pit** | Hops out. This is the shallow case that must NOT trap |
| **A mob in a 2-tile pit** | Jumps, hits the wall, falls back. Repeatedly. **Trapped, and visibly trying** |
| **A mob under a ceiling** | `move_y` blocks and `vy` is zeroed (`step()` already does this). It must not stick in the terrain |
| **A mob against a wall taller than 56px** | Jumps forever. **Intended.** It is the "walled off" picture |
| **20 mobs in a corner** | Separation must settle, not oscillate. The single most likely failure |
| **A mob jumping while burning** | `_burn` runs after all movement (`step()`'s own contract). Unchanged |
| **A mob jumping into the player** | Contact damage is a box overlap on every tick; being airborne changes nothing |
| **A hen stopped at range** | `axis == 0` ⇒ `move_x` returns `false` with nothing attempted (`body.gd:104`) ⇒ **never jumps while standing and throwing.** This falls out of the existing contract, but a net must pin it |
| **A boss** | `BossAi.has_pattern(kind)` ⇒ patterns own the body. **The blocked-jump must not fire during `CHARGE`** — a charge that hops the wall it was supposed to ram destroys the "ramming stuns it" contract (`body.gd:90`'s whole reason for `allow_step=false`) |

**That last row is the sharpest edge in this plan.** A charging bull passes `allow_step=false` *specifically*
so it rams flat into anything solid, and `move_x` returning `true` is how the charge knows it hit. Hang a
jump on the same return value with no kind/pattern gate and **the bull jumps out of pit ① and the midboss
fight stops existing.**

---

## Interaction with what exists

- **`body.move_x`'s return value** — currently read by exactly one caller. This adds a second. **No change to
  `body.gd`.**
- **`boss_ai`** — untouched. Bosses are gated out.
- **`world_step`** — the monster loop is where separation has to live (it is the only place that sees all
  monsters at once). **`spawn_monster` stays the only door that makes one.**
- **`monster_view`** — one new state id + one resolve branch.
- **Water** — `monsters.md`: "eventually everything takes everything", and monsters do not take water yet.
  A jump in water is not a question until then. **Stage 1 is a dry farm** (`stage1-map-layout.md`), so this
  does not gate anything.
- **`net_monster._pig_and_hen_cross_the_ledge_differently`** — measures a `step_cells` contract ("pig is
  blocked at a 3-cell ledge, every other kind clears it"). **A jump makes the pig clear that ledge anyway**,
  and the check would go red — correctly, because the behaviour genuinely changed. **The net must be rewritten
  to measure the step-up path specifically, not "can it get past"**, or the distinction it protects is lost.

---

## Cost

- **The jump is free.** One comparison on a value already computed and returned.
- **Separation is O(n²) — 190 pairs at `MAX_MONSTERS`=20.** A pair test is a box overlap; the existing
  `world_step._boxes_overlap` already does this shape once per monster against the player. 190 of them is
  small against the measured **20 pigs = 3,416µs (20.5% of the 60Hz frame)** already being spent
  (`monster_defs.gd`'s cost table). **Measure it anyway** — `tools/stage/profile_monsters.gd` exists and the
  table's own standing instruction is to re-take it, not edit it by hand.
- **No new chunk wakeups.** Monsters only **read** the grid (`monster.gd:2`). Neither behaviour writes a cell.
- **`box_free` calls go up** — separation asks it per corrected mob. It sweeps the covered cells in GDScript
  and it is the expensive primitive in this file (`character.gd`'s own burn record, 25 → 81 cells).
  **This is where the cost will actually show, not in the pair loop.**

---

## Acceptance

1. **A 1-tile pit does not hold a pig. A 2-tile pit does.** The contract this plan exists for — measured, not
   eyeballed
2. **The real apex, per kind, measured** — and written into `monster_defs.gd` beside the box, the way the
   cost table already is
3. **A mob walled off jumps repeatedly and never clears it.** No accidental wall-climbing via `_try_step_up`
   stacking with a jump
4. **A charging bull still rams and stuns.** Pit ① confinement holds — re-run `net_monster_slam`'s real-map
   600-tick check
5. **A hen stopped at throwing range never jumps**
6. **20 mobs converging on the player settle into a spread, with no shudder** — verify-look, on screen, at 20
7. **Separation is order-independent** — reverse the monster array and the resulting positions are identical
8. **Airborne mobs are not playing the walk cycle** — whatever the pose ends up being, it is not that
9. **Frame cost re-measured with 20 mobs**, separation included

---

## TBD

- **`jump_vy_px` per kind, or one value for all.** −520 is a proposal, not a decision. A pig that jumps worse
  than a wolf is a real design axis and this is where it would live. **The user has not seen any of it move**
- **Does a mob keep jumping forever, or give up?** Forever is proposed (it reads as "trapped"). A cooldown
  would look calmer and read as "resigned". **Judged on screen**
- **Do mobs block the player?** Right now they separate from each other and pass through the player freely
  (contact is damage, not collision). A wall of pigs the player cannot walk through is a different game feel
  and a different implementation
- **The permitted overlap threshold, and the correction rate.** Both are screen values
- **Do the three jump sheets read as jumps?** They are generated and on disk; **nobody has looked at them
  moving.** The `hold` value is a first guess, exactly as `monsters.md` says every other sheet's is
- **The bosses have no jump sheet and are not getting one** — they are gated out of this behaviour, and
  `bull_slam` / `rooster_leap` already cover the only airborne thing they do
- **The pig's `step_cells`=1 vs everyone else's 3 was the only mobility difference between kinds.**
  A jump flattens most of it. **Whether the kinds should differ in jump instead** is the question that
  replaces it, and nobody has answered it

---

# Implementation plan

**The doc stays in `1.ready/` and `Status` is untouched** — team-lead's explicit instruction for this round.

## What the user has to decide (nothing below is blocked on it — build under the stated assumption)

1. **`jump_vy_px`, and therefore pit depth.** The plan builds the *contract* (1 tile out, 2 tiles holds) and
   starts at −520, but **does not write a final apex into the table** — see "the number" below for why the
   doc's own −520/56px/~10%-under arithmetic cannot be carried over from the bosses. **The eye decides.**
2. **Is the 1-tile/2-tile pair the right pair at all** — the cost of *digging* it moved this session. gen 0
   `carve_r` is **2 cells** (a 5-cell-tall disc, `sim_tuning.SIM_SIZES`), so a 2-tile (16-cell) pit wide
   enough to hold a 48px mob (12 cells) is **roughly 12-15 blast impacts**, and gen 0's measured **horizontal
   range is 32-34 cells = 4.0-4.3 tiles** (that table, re-driven after 20→12). "Hard but possible" is
   the sum of *jump height* and *dig cost*, and only one of the two is in this doc.
3. **Per kind or one value** · **jump forever or a cooldown** · **the separation threshold and rate** — the
   doc's own TBDs, all screen values. Skeleton first; the columns exist either way.
4. **`MON_AIRBORNE` vs `MON_ATTACK` priority** (new, not in the doc — see Stage B). Recommendation: airborne
   wins.

## Where the design doc and the code disagree

| Doc says | Code says |
|---|---|
| "only a charging bull reads it (`monster.gd:157`)" | the claim is right, the line is **`monster.gd:163`**; 157 is `apply_gravity` |
| "expect ~10% under" the formula | **two records, not one**: bull −450 → 42 computed / 38 measured (**9.5%**), rooster −500 → 52 / **40** (**23%**, `boss_ai.gd:222-226`). And both were launched from `on_tick`, **before** `step()`'s own `apply_gravity` runs — this jump launches **inside `step()`, after** it, so it does not lose that frame of gravity at all. **The recorded shortfall is from a different launch door and does not transfer.** Drive it |
| "the net must be rewritten" (one net) | **two**. `net_monster._walking_monster_blocked_by_wall` (`net_monster.gd:888-908`) stands a pig against an **8-cell = 32px** wall and asserts `m.y == y` ("only horizontal is blocked — vertical is the control"). That is *exactly* the 1-tile case this plan requires to be hopped: **both** of its assertions break |
| "three edits, no structure change" for the screen | `MonsterView.resolve_state` is a **static function with a fixed signature and no `on_ground` argument** (`monster_view.gd:1136`). It has to widen, and `_scan_anim` (`:324`) and `net_monster_sprite`'s direct calls follow. Four edits, and one of them is a signature |
| — | **`net_determinism` will not bark at separation.** It scans `res://src/sim` only and its own header says "src/actor/ is not a target" (`net_determinism.gd:17,20`). Order-independence has **no existing net at all**; it is built here or it is not measured |
| — | **`tools/stage/profile_monsters.gd:73` spawns at `200 + i * (w_px + 8)`, deliberately spread** ("so they are not all resolving collisions against each other in one column"). As written it measures **zero** of separation's cost |
| "acceptance 3 — no wall-climbing via `_try_step_up` stacking" | **already structural**: `_try_step_up` returns false when `not on_ground` (`body.gd:129-130`), and `on_ground` is false for every frame of the arc after the launch frame. On the launch frame itself a step is still allowed, but a step reaches at most 12px (`step_cells`≤3) and a pit wall is ≥32px. Still worth a net — but it is a confirmation, not a discovery |

## The answers

**Where does the jump live** — `src/actor/`, nowhere else. `vy` is a float on `Body`, gravity is a float, and
`src/sim/` forbids both; the bosses' own launch already sits at `monster.gd:325` (`_body.vy =
BossAi.leap_jump_vy_px(kind)`). Same file, same door, one function earlier.

**What decides "blocked"** — `Body.move_x`'s existing return value. **No new axis.** Its own contract
(`body.gd:96-102`) already says "returns true if blocked" and already says `dx == 0.0` returns **false with
nothing attempted** — which *is* the hen's "never jumps while standing at range", for free.
⇒ **Do not add `axis != 0.0` to the jump condition.** It is a second copy of a rule that lives in `body.gd`,
and the acceptance-5 net pins the behaviour either way.
The one real edit to that line is capturing the return into a local so it is not called twice:

```gdscript
var blocked := _body.move_x(grid, dx, not charging)
if blocked and charging:
    _charge_blocked = true
```

**Does the jump break determinism** — no. Nothing in `src/sim/` is touched.

**Does separation break determinism** — not automatically, and no existing net would notice. It is made
order-independent by construction (below) and **two** new checks measure it, because either one alone lies:
invariance-under-reversal passes trivially when separation is **deleted** (CLAUDE.md: "A/B comparison catches
'diverged', never 'vanished'"), and a process check alone does not measure order.

**Does the jump apply to bosses** — no. One gate, `BossAi.has_pattern(kind)`, in `step()`. **Not
`pattern == CHARGE`**: `WINDUP`/`STUN`/`FIRE`/`GORE` already freeze the axis so they are unreachable, but
`Pattern.IDLE` walks brainlessly forward (`monster.gd:223`) and an idle bull pressed into room ①'s left
boundary would hop out of it. The gate is at the kind, the same door `_next_axis` (`:198`) and `is_phase2()`
(`:141`) already use — and that function's own comment is the reason: *one* place holds "does this apply to
this monster at all".

## Stage A — the jump

| File | Why |
|---|---|
| `src/actor/monster_defs.gd` | one `jump_vy_px` column on all five rows + one static accessor. Bosses get **0.0**, with a comment that the live gate is `has_pattern`, not this value |
| `src/actor/monster.gd` | `step()` — capture `move_x`'s return, then the jump |
| `tests/nets/net_tables.gd:785` | the hand-maintained column list goes nine → ten, plus "up is negative" (`<= 0.0`) |
| `tests/nets/net_monster.gd` | the pit-depth pair, the boss gate, the hen gate; **and the two broken checks, rewritten** |

`monster_defs.gd`'s header lists what is deliberately *not* a column ("how it attacks", damage taken, fire
DPS — false knobs). **`jump_vy_px` is not one of those**: it is mobility, read every frame, the same shape as
`speed_px` and `step_cells`. Say so in the header or the next reader deletes it.

**Exact seat inside `step()`** — between `move_x` and `move_y`:

```gdscript
if blocked and _body.on_ground and not BossAi.has_pattern(kind):
    _body.vy = Defs.jump_vy_px(kind)
```

**Why not after `move_y`.** `on_ground` is written twice per `step()` — line 151 (top of frame) and line 167
(after the vertical move). Reading the later one means a mob pressed against a wall jumps on the frame it
*lands*, off a different definition of "on the ground" than `_try_step_up` used four lines earlier. One
definition per frame.

**Why the apex cannot be written down in advance.** The order is `apply_gravity` (157) → `move_x` (163) →
**jump** → `move_y` (165). Gravity has already been spent this frame when the launch happens, so this door
does **not** lose the first frame the bosses' `on_tick` launch loses. The recorded 9.5%/23% shortfalls are
from that other door. **verify-run drives the real apex per kind and it gets written into `monster_defs.gd`
beside the box, the way the cost table already is** (acceptance 2).

**What Stage A's nets measure**
- **1-tile pit (8 cells) does not hold a pig · 2-tile (16 cells) does.** Grid shape already exists —
  `net_monster._chimney_grid()` is a `cmd_fill(..., Mat.EMPTY)` hole in the stone floor; make it 16+ cells
  wide so a 48px hen fits too. **Assert the premise**: `step_cells * CELL_PX < 32`, so the escape cannot be
  a step-up in disguise
- **A jump actually fired** — record `m` going airborne / `vy < 0` at least once, and assert the sample
  count. "It got out" is not "it jumped", and a settle loop that ran zero iterations has passed here before
- **A bull walled off never leaves the ground.** Drive `Pattern.IDLE` into a wall on the real path
  (`world.frame`), record `on_ground` every frame, assert it never goes false
- **A hen at `BOLT_STOP_PX` never jumps** — `axis == 0` ⇒ `move_x` false. Same record-the-process shape
- **Re-run** `net_monster_slam`'s room-① 600-tick confinement and
  `net_monster_charge._charging_bull_does_not_step_a_3cell_ledge`. Expected unchanged; they are the witness

**The two broken checks**
- `_walking_monster_blocked_by_wall` — raise the wall past the measured apex so "blocked" still means
  blocked, and **keep the y assertion inverted into a witness**: at 32px the pig now clears it, at the taller
  wall it never does. The check gets stronger, not weaker
- `_pig_and_hen_cross_the_ledge_differently` — the doc is right that it dies. **Rewrite it to measure the
  process, not "can it get past"**: at a 3-cell (12px) ledge the hen (`step_cells`=3 = 12px) crosses with
  `vy` **never negative and `on_ground` never false**, and the pig (`step_cells`=1 = 4px) crosses **only by
  going airborne**. That measures `step_cells` more sharply than the old binary did.
  Note the `Body`-level half is **already safe**: `_body_step_is_a_ctor_arg` (`net_monster.gd:608-628`)
  drives bare `Body` objects, which have no jump

## Stage B — the screen

| File | Why |
|---|---|
| `src/view/fx_tuning.gd` | `MON_AIRBORNE` (next free id — 0-9 are taken) + three rows: pig/hen/wolf |
| `src/view/monster_view.gd` | `resolve_state` gains `on_ground: bool`; `_scan_anim` (`:324`) passes `m.on_ground` (already a public property, `monster.gd:102`) |
| `tests/nets/net_monster_sprite.gd` | the `resolve_state` call sites follow; two new checks (below) |

**The three pngs are on disk and they fit** — measured, not assumed: `pig_jump.png` 132×32 (= 3 × 44),
`wolf_jump.png` 144×28 (= 3 × 48), `hen_jump.png` 144×64 (= 3 × 48). All three satisfy
`net_monster_sprite`'s `width == frames * w_px` and `height == h_px` at `frames: 3`, and that check is
table-driven, so it picks them up with no edit.

**`hold` has a computable ceiling, and the doc's "first guess" does not name it.** At −520 the airtime is
roughly 25-30 frames, so `frames * hold` must fit inside it or the pose **never reaches its last cell** —
the same failure `_hurt_left` was split from `_flash_left` to avoid (`monster_view.gd:109-112`).
⇒ `hold` in **[3, 8]**, start at **4** (12 frames), then the eye.

**The priority slot — an open question the doc leaves half-pinned.** It says "before `MON_WALK`, after
`MON_HURT`/`MON_DEATH`" and never says where **`MON_ATTACK`** sits.
⇒ **Recommendation: airborne outranks attacking.** `_is_attacking` is a *proximity condition* for the pig and
wolf, not an event (`monster_view.gd:356-363`) — so a pig jumping anywhere near the player would otherwise
never show a jump frame at all, which is precisely the "it is trying to get out and cannot" picture this plan
exists for. The hen's is a latch on a real event, and the hen never jumps at range anyway.

**Two checks, because "the bosses fall through" is a claim, not a fact yet**
- **No boss has a `MON_AIRBORNE` row, and an airborne boss does not resolve to one.** `resolve_state` returns
  early for `has_pattern(kind) and pattern != IDLE` (`:1137`) — but **during `Pattern.IDLE` a boss falls
  straight through to this chain**, and `anim_row` then substitutes `MON_IDLE` for the missing row (`:1160`).
  ⇒ **An idle bull walking off a ledge stops playing its walk and plays its idle.** Small, real, and the doc's
  "falls out of the existing order" does not cover it. Measure the resolved state for a boss at
  `Pattern.IDLE` with `on_ground == false` and write down which of the two it is
- **A jumping mob is not on `MON_WALK`.** Driven, not grepped — `resolve_state` is pure static and the nets
  already call it directly

## Stage C — separation

| File | Why |
|---|---|
| `src/actor/monster_separation.gd` (**new**) | **phase 1, pure over plain values** — positions and widths in, an integer dx per index out. The `BossAi.advance` precedent verbatim ("a pure function over plain values, not over `Monster`"), so a net drives it with no world and the inversion is trivial |
| `src/actor/monster.gd` | **one new method**, `try_shift_x(grid, dx: int) -> bool` — asks `box_free` and moves, or refuses whole. `_body` stays private, the same read-only-window idiom as `charge_blocked_now()` |
| `src/actor/world_step.gd` | phase 2 — call it after the 60Hz `m.step()` loop; two constants beside `PIG_CONTACT_DAMAGE` (threshold px, max correction px) |
| `tests/nets/net_monster.gd` | three checks (below) |

**Why the split is exactly here.** Phase 1 is the only part where order could matter, and it is pure —
it reads a snapshot that nothing mutates during the phase, plus nothing else. Phase 2's `box_free` refusal is
**per-mob independent** (the grid is read-only for monsters, `monster.gd:2`), so applying corrections in any
order gives the same result. That is the whole order-independence argument and it is checkable by reading.

~~**The mechanism by which acceptance 7 would actually fail, and the doc does not name it: float summation.**
A correction summed over up to 19 partners as a `float` is **not associative** — reverse the array and the
last bit moves, and at a rounding tie the integer px differs.~~
**This reasoning did not survive being tried** — see "What landed". ⇒ **accumulate corrections as integers**
anyway: `Body.x` is an integer, nothing is lost, and it is **prevention, not a fix for an observed failure.**

**60Hz, after the `m.step()` loop** (not the 20Hz tick branch): an overlap created by *this frame's* walking
is resolved in the same frame, and deferring it to the tick leaves up to 2 frames of visible stacking — the
symptom the user named. **If Stage D's measurement says it does not fit the budget, moving it into the tick
branch is the fallback** — that is a decision with a measurement behind it, not a guess.

**Two named consequences, neither worth code**
- `_rem_x` is **not** touched by a shift. It carries the walk's sub-pixel remainder; clearing it silently
  slows the walk (`body.gd:79-88` records that exact family of bug)
- `on_ground` goes stale for one frame after a shift that pushes a mob off a ledge. Refreshing it means a
  second `grounded()` — i.e. a second `box_free`, the expensive primitive — per mob per frame, to fix one
  frame of cosmetics. Named, not fixed

**Three checks**
1. **The process.** Two mobs placed overlapping, record the overlap **every frame**; assert it strictly
   decreases on a named frame and that a correction was applied on that frame. "They end up apart" is what
   walking does anyway — it proves nothing
2. **Order-invariance.** Same start state, monster array reversed, N frames, positions identical. **Only
   meaningful next to (1)** — alone it passes with separation deleted
3. **Terrain refuses whole.** A mob cornered against stone: assert it does **not** move at all, not that it
   "moved as far as it could". Partial moves are what re-trigger next frame and become the shudder

## Stage D — cost

| File | Why |
|---|---|
| `tools/stage/profile_monsters.gd` | a **clumped** spawn row. Line 73's `w_px + 8` spacing was chosen so mobs never resolve against each other — as written it measures none of this |
| `src/actor/monster_defs.gd` | re-take the cost table. **Do not hand-edit it** — that file's own standing instruction |

**The cost model, from reading `body.gd`, not from assuming.** The pair loop is 190 `_boxes_overlap` calls
(four integer comparisons each) — noise. The real cost is `box_free`, one extra call per *corrected* mob per
frame. Each `box_free` sweeps `(w/4)·(h/4)` cells — pig 88, hen 192.
**But `step()` already spends 10-15 `box_free` calls per mob per frame** (`move_x`'s per-pixel loop, `move_y`'s,
two `grounded()`, plus `standing_in_fire`'s equivalent sweep). ⇒ **+1 is +7-10%, not a new order of magnitude.**
**And it must still be measured**: this repo already recorded that per-cell projection is wrong in the other
direction (hen: 2.2× the cells, 1.6× the cost). Do not project from cell counts.

## Stage E — order

A → B can be parallel with C. Everything else is sequential:

1. **A** (the jump) — nothing else can be judged until a mob leaves the ground
2. **the two broken nets** — inside A, not after. Leaving a knowingly-red net for a later stage is how a
   round ends with "it was already red"
3. **B** (the screen) — depends on A only for "was there an airborne frame to draw"
4. **C** (separation) — independent of A and B
5. **D** (cost) — last, because it must measure A + C together
6. **verify-look** — after B and C. It is the only judge of items 6 and 8 of Acceptance, and of every TBD

## Can this be verified without the sibling placement doc — yes

- **Headless**: `world.spawn_monster(kind, px, py)` is the only door and it is public and drivable with no
  scene (`net_monster` does it throughout). A pit is a `cmd_fill(..., Mat.EMPTY)` — `_chimney_grid()` is
  already that shape
- **On screen**: `stage_input.MONSTER_KEYS` binds **M**=pig, **N**=hen, **V**=wolf, spawning at the mouse
  (`stage.gd:693`), and `MAX_MONSTERS` is 20 — so the 20-mob pack is twenty presses of M. A pit is dug with
  the magic circle or the terrain paint keys
⇒ **Nothing here waits on `monster-placement-stage1.md`.**

## Risk

| Risk | Shape |
|---|---|
| **The bull hops out of room ①** | the sharpest edge, and the gate is one term. `net_monster_slam`'s real-map 600-tick check is the witness — **re-run it, do not reason about it** |
| **`move_x` called twice** | the naive edit writes `if _body.move_x(...) and charging` *and* `if _body.move_x(...) and on_ground`. That moves the body twice per frame and nothing barks. Capture the local |
| **The jump reads the wrong `on_ground`** | two writes per `step()` (151, 167). The later one makes a mob jump on its landing frame |
| **A false green from a check that never ran** | every pit/wall check asserts its own sample count. A settle loop with zero iterations has passed in this repo already |
| **Order-independence measured by final state only** | CLAUDE.md's own recorded failure. Checks (1) and (2) of Stage C exist as a pair for this reason |
| **A screen/sim split** | the signature fake. `MON_AIRBORNE` with no `on_ground` reaching `resolve_state` is exactly it — the state constant would exist, the sheet would load, every table net would be green, and **nothing would ever play it** |
| **The cost number means nothing** | `profile_monsters.gd` as written spreads mobs apart on purpose |
| **`net_tables`' column list** | hand-maintained by design. Add the column and forget the list, and a kind missing `jump_vy_px` throws at runtime, not in the nets |

## What landed

**The grounds are the user's own words: 「가두는 것도 조금 어렵게, 성공이 가능해야지. 너무 쉽게 성공하면
재미없어.」** Before this, **any hole held any trash mob.**

**The contract is 1 tile (32px) out, 2 tiles (64px) held.** `jump_vy_px` **−520**, measured apex **61px**
⇒ **3px of margin**, pinned by `t.eq(margin_px, 3)`.

**That check really computes the margin** — `jump_vy_px` −520→−515 makes it bark, and so does `GRAVITY_PX`
2400→2440. **`hold` does not, and must not**: it is a `src/view/` constant and has nothing to do with the
arithmetic. (An earlier draft of this line named `hold` as one of the inputs. It was wrong.)

**But the same measurement says the contract is very thin.** −520 → −515 is a **1% change and the margin goes
3 → 4.** ⇒ **when the value is finally chosen on a screen, choose it knowing that.** Nobody has seen it move.

**Boss exclusion has exactly one axis: `BossAi.has_pattern(kind)`.** It started as two — the gate *and*
`jump_vy_px = 0.0` — so deleting the gate did not bite. Setting the boss rows to −520 as well made the gate
the only barrier, and doing that turned **`net_monster_slam`'s room ① confinement and `net_monster_charge`'s
collision timing red together** ⇒ **the plan's own "sharpest risk" (the bull jumping out of room ①) is proven
to be held by that one gate.** Verification re-ran it: deleting the gate turns **7 checks across 3 nets** red
(an idling bull's `on_ground` false on 31 frames · the charge landing 0 of 3 cells · room ①'s left bound
crossed). **The pit-depth checks are not self-referential** either — the depth appears only on the
construction side.

**Screen**: `MON_AIRBORNE`, and **airborne outranks attacking** — the pigs' and wolves' `_is_attacking` is a
**proximity condition, not an event**, so ranking it above airborne would mean a pig jumping near the player
never shows a single frame of the jump. Hang time measured **26 frames** against `frames*hold = 12`.
**Confirmed on a real situation, not on the table**: across 200 frames, all **22** frames where
`on_ground == false and _is_attacking()` were both true resolved to `MON_AIRBORNE`.

**The bosses' `IDLE` animation was left alone** — a bull idling off a ledge stops walking and plays
**standing** (no `MON_AIRBORNE` row for bosses, so it falls back to `MON_IDLE`). Boss jump art is out of scope.

**Separation** is a pure function feeding `try_shift_x`, which asks `box_free` for the whole box and, on
refusal, **does not move at all**.

**The accumulation is `int` — and the reason written here first was not true.** The claim was that summing 19
neighbours in float is non-associative, so reversing the array shifts whole pixels. **It was tried: 19 mobs
packed together, fractional divisors, array reversed — green.** At this game's magnitudes (single- and
double-digit px, tens of terms) IEEE-754 double does not actually break associativity.
⇒ **`int` stays, as prevention against the day the values grow — but no observed failure backs it today.**
The file header says the same; **do not let the two drift.**

**`net_determinism` scans `res://src/sim` only** (its own header says `src/actor/` is not a target)
⇒ **a new net measures order independence.** And **"invariants alone stay green when separation is deleted"
was reproduced by measurement** — an invariant check is worth something only paired with a process check.

### What verification found — four false greens, two checks that measured nothing

1. **The whole of Stage B was outside the nets.** Pin `m.on_ground` to `true` at `monster_view.gd:324` — **the
   one wire by which the jump art reaches the screen** — and **all 31 nets stayed green.**
   `net_monster_sprite` drove `resolve_state` **as a pure function only**, and **zero checks drove an airborne
   monster through `advance()` and read `anim_state == MON_AIRBORNE`.** A wiring check was added.
   **This was the sixth "the shell is outside the nets" of that one day**
2. **`OVERLAP_THRESHOLD_PX` 4→43 was green, and `MAX_CORRECTION_PX` 8→1 was green.** At 43 a pig (44 wide)
   only separates when **almost perfectly stacked** ⇒ **the 40px overlap that is the only kind real play
   produces would never be pushed apart at all.** The cause: the process check had exactly one scenario, the
   degenerate **two mobs on the same x**. Partial-overlap scenarios pinned to **exact final coordinates** now
3. **No net called `corrections()` directly** — a pure function whose own header advertises that nets can
   drive it without a world
4. **Order independence bit only halfway.** Index-dependent mutations were caught, but **swapping in
   successive relaxation — genuine order dependence — stayed green**, because the net's **four evenly spaced**
   monsters are insensitive to it. Uneven spacing and a 19-mob cluster were added
5. **One label claimed more than its check measured** — it stayed green with separation deleted, because both
   monsters walk and their x changes either way

### The real bug — **falling asleep in mid-air, and the 20Hz phase trap under it**

**A monster that fell asleep while airborne kept `on_ground == false` forever and froze in the jump pose,
in the air.**

The obvious fix — read `on_ground` fresh each tick — **made it never sleep again**, and the reason is worth
more than the bug: **a pig jumping against a wall has a 27-frame cycle, and 27 is a multiple of
`TICK_DIVIDER` (3).** The single frame on which it lands therefore falls on **exactly the same tick phase
every cycle**, and the 20Hz check never once observes it. (Confirmed by printing 120 frames.)

⇒ Fixed with the **channel that already exists for carrying a 60Hz event to the 20Hz clock**, the one
`_charge_blocked` / `_leaped_landed` use: `Monster._grounded_recently`, a read-and-clear accessor. No new cost.

**This is the third place in this repo that needed that same channel.** **A 60Hz event sampled by a 20Hz
clock can be invisible with no error at all** when the event's period shares a factor with `TICK_DIVIDER` —
and the symptom is not a wrong value, it is a thing that never happens.

**One check in `net_monster_placement.gd` moved with it.** Finding 5's fix broke that net's assumption of
"asleep exactly one tick later" — a wall sits at its spawn point, so its test monster jumps too. It now waits
up to 15 ticks. **The two features meet there**; the sibling doc records it as well.

## Acceptance — who measures what. **6 · 8's second half are the screen's, and unseen**

| # (doc) | Owner |
|---|---|
| 1 · 1-tile out, 2-tile holds | verify-run + net (Stage A) |
| 2 · real apex per kind, written into `monster_defs` | verify-run — **the plan does not supply this number** |
| 3 · walled off, jumps forever, never clears | net (and `body.gd:129`'s airborne guard is the structural half) |
| 4 · the charging bull still rams and stuns | re-run `net_monster_slam` |
| 5 · a hen at range never jumps | net |
| 6 · 20 mobs settle, no shudder | **verify-look only.** No headless substitute |
| 7 · separation is order-independent | net — **two checks, not one** |
| 8 · airborne mobs are not on the walk cycle | net drives `resolve_state`; whether the pose *reads* as a jump is verify-look |
| 9 · frame cost re-measured with 20 | `profile_monsters.gd`, **clumped** — and that tool was itself found to be spreading the monsters apart, hiding separation's cost as zero. Fixed in the sibling doc's build (`3.done/monster-placement-stage1.md`), where the numbers are |

**What the screen still has to answer** — none of it has been looked at:

- **Does the jump read as a jump.** Three sheets exist on disk and nobody has seen them move
- **Do 20 mobs jitter** — the separation pass runs every frame over every awake pair
- **Does 3px of margin actually feel like "조금 어렵게".** It is the whole point of the feature and it is the
  one number with no screen behind it — **and a 1% change to `jump_vy_px` moves it**
- **Does the airborne-sleep fix look natural** — a monster that dozes off mid-air now lands first. Measured
  correct; never watched

## Out of scope

Placement (the sibling doc) · mobs blocking the player · a wall-breaking kind · pathfinding, wall-following,
digging · vertical separation · boss jump sheets · a second gravity axis · touching `body.gd` · touching
`boss_ai.gd` · differentiating `jump_vy_px` per kind beyond the column existing.
