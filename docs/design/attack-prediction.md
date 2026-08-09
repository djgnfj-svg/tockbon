# Attack prediction — the telegraph becomes a red mark on the ground

**One line**: the wind-up tell stops being a symbol above the head that says "something is coming" and becomes
a red, pulsing mark on the ground, shaped to the actual move, that says **where it lands.**

**Implemented**: full — all five moves (charge · fire · gore · slam · leap) draw a shape during `WINDUP`,
tracking the player live until the direction locks. Provisional numbers throughout (see "Not decided yet").
**Accepted**: unseen — written from the user's own words in conversation, not yet judged on screen.

---

## Why

The user looked at screenshots of the bull and rooster fighting and asked for five changes. This is the
first: **make the attack telegraph a red prediction of where the attack will land.**

The old tell was a blinking orange "!" above the hp bar (`stage1-bosses.md` Stage B, acceptance 3).
verify-look measured it at roughly **one eighth of the bull's height** at 1.0 zoom, next to the stun ring — a
bright cyan circle wrapping the whole body — and the gap was not subtle. The ring reads; the "!" doesn't.

⇒ **Two problems, one fix.** The symbol was too small to read fast, and it said only *that* something was
coming, not *where*. A ground mark sized like the stun ring answers both: it is big enough to read in 0.4s
(phase 2's shortest wind-up), and its shape and position are the answer to "where do I need to not be."

---

## The five shapes

Each move already knows where it goes — the sim computes it, this only draws what the sim already knows,
through the doors that already exist (`BossAi`'s public accessors, `Monster.center()`, `CellGrid.is_solid`).

| Move | Shape | Comes from |
|---|---|---|
| **CHARGE** | A red band, the monster's own height, from its leading edge to the wall it will actually hit (or the safety-cap distance, whichever is shorter) | `BossAi.MOVE_CHARGE`'s own duration/speed, `CellGrid.is_solid` for the wall |
| **FIRE** | A horizontal line, `MonsterBolts.BOLT_RANGE_PX` (480) long, from the exact point a real bolt spawns from | `WorldStep.frame()`'s own `_bolts.spawn(m.center().x, m.center().y, Vector2(pattern_dir, 0.0), ...)` |
| **GORE** | A band **54px** wide, centered on the monster, symmetric (not directional) | `(w_px + Character.W_PX) / 2` — the real box-overlap reach, not `BossAi.gore_range_px`'s 120px gate |
| **SLAM** (bull) | A landing ring, plus a second ring at **±56px** for the ignite spread | `BossAi.MOVE_SLAM`'s jump velocity and speed (the continuous-flight estimate) · `slam_ignite_r`/`_spread_cells`/`_points` |
| **LEAP** (rooster) | A landing ring only, no ignite | Same continuous-flight estimate, `MOVE_LEAP`'s own numbers |

### Why gore shows 54px, not the 120px gate

`BossAi.gore_range_px` (120px) only decides **whether** gore is chosen over a charge, at the instant `WINDUP`
ends. The actual hit is a plain box overlap (`WorldStep._boxes_overlap`), which lands at
`(the monster's own w_px + the player's W_PX) / 2` — 54px for the bull. Drawing the 120px gate would show a
reach the attack does not have; drawing 54px shows what it can actually touch.

### Why the charge lane can undersell but never oversell

The lane is found by stepping forward in `Tuning.CELL_PX` increments, checking the same box-vs-cell rule
`Body.box_free` uses for the real collision (that function is private to `Body`; `CellGrid.is_solid`, the door
it is built on, is public — the view reads through that door rather than duplicating a second collision
system). A charge passes `allow_step=false`, so it rams flat into anything solid, no matter how short — the
same discipline `body.gd`'s own header names for why a charging boss cannot climb a step. This raycast does
not model stepping at all, so it can call a charge blocked by a bump the real charge would ram straight
through — the lane can read *shorter* than the real run, never *longer*.

### Why slam/leap's landing point is an estimate, not the real number

The real landing depends on 60Hz discrete integration against whatever terrain sits underneath — unmeasurable
from the view without actually running the frame (verify-run's seat, not this one). What is drawn instead is
the same **continuous** analytic formula `boss_ai.gd`'s own comments already compute and already name as an
overshoot: `2 * |jump_vy_px| / Character.GRAVITY_PX` for time aloft, times the horizontal speed the move
actually uses. The one number on record for how far off this runs *horizontally* (not the apex, a different
error shape) is the rooster's own leap — 153px measured vs. this formula's 167px, an 8% gap, tighter than the
~30% the same file's comments record for apex height. Still an estimate, not the real number, and said so in
the code rather than presented as exact.

---

## The honesty constraint — tracks the player live, does not lie from the stale direction

`boss_ai.gd`'s own header: direction (and, for the bull's charge, whether gore substitutes for it) is only
decided at the `WINDUP -> active` transition and held from there. During `WINDUP` itself, `Monster.pattern_dir`
and `Monster.move_choice`'s gore-or-charge question both still carry the **previous** move's answer.

**Decision: the mark tracks the live player position every frame during `WINDUP`, converging on the real
answer at the exact tick it locks — it does not read the stale field and hold it for the whole wind-up.**

A prediction drawn from the stale value would be *lying* for however long `WINDUP` has left. At phase 2 that
is up to 0.4 seconds of a mark pointing the wrong way, or showing a charge lane where a gore band is about to
appear — worse than showing nothing, since a wrong mark actively misleads instead of merely failing to help.
Tracking live means the guess and the eventual lock **agree by construction** on the tick they meet (the same
two formulas `boss_ai.advance()` itself applies — `signi()` on the horizontal difference, and
`gore_range_px` plus a vertical-overlap check — are re-read on the view side, not re-derived differently), not
by coincidence.

**Cost of this choice**: for however long `WINDUP` has left, the mark can visibly change side or shape if the
player crosses the boss or steps in/out of gore range. This is a deliberate trade — a mark that moves is more
honest than one that commits early and might be wrong, and it still becomes exactly correct by the time it
matters (the lock instant, which is also the instant the attack actually starts).

---

## Color

**Red** — the user's own word. `fx_tuning.ATTACK_PREDICT_COLOR`, near-pure red
(`Color(0.95, 0.12, 0.12)`), replacing the retired orange "!" (`MONSTER_TELEGRAPH_*`, deleted with this
change, not kept switched off).

Checked against everything else already meaning something on this screen (the same hue-degree method
`MONSTER_PHASE2_COLOR`'s own comment already used): damage-number red sits at ~8°, terrain/monster fire at
~15-40°, the stun ring's cyan at ~185°, phase-2's indigo at ~230°, the reserved scream-magenta at 300°. True
red (~0-3°) is the one hue the request pins down, so it cannot be rotated away from the damage number's own 8°
the way phase-2 was free to pick 230° — the two are kept apart by **saturation and value** instead: the
damage number is a light, desaturated coral; this is a near-pure, fully saturated red, and the two never share
a vocabulary anyway (floating text vs. a ground mark).

Pulses the same `sin()` shape the stun ring already uses, copied rather than reinvented (`ATTACK_PREDICT_
PULSE_FRAMES` = 12, faster than the stun ring's 30 — the shortest phase-2 wind-up is 8 ticks/0.4s, and a full
pulse cycle has to complete inside that).

---

## What this does not do

- **Does not touch the stun ring.** Explicitly the model for how strong this should read — its own code and
  constants are unchanged
- **Does not show during the active move itself** (`CHARGE`/`FIRE`/`GORE`/`LEAP`), only during `WINDUP` — once
  the move is running, the real effect (the charge's own motion, real fire bolts, the real gore contact box)
  is the show
- **Does not model stepping** in the charge-lane raycast (see above) — a real, named simplification, not an
  oversight
- **Does not compute an exact slam/leap landing** — the continuous estimate, named as one

---

## Screen

Not yet seen. What to look for once it is:

1. **Reads inside 0.4 seconds** — phase 2's shortest wind-up (the user's other named complaint about the old "!")
2. **Red does not collide** with body fire, ground fire, or the stun ring at a glance
3. **The mark visibly follows the player** during a long wind-up if they move to the other side, and does not
   look "stuck" pointing the wrong way
4. **The charge lane visibly stops at a wall**, not running past it into open air beyond
5. **The slam's two rings read as one event** (landing + the fire it throws), not as two unrelated marks

---

## Not decided yet

**Do not force these full.**

- **Every number is provisional** — same status every value in `boss_ai.gd` already carries. The user judges
  shape and readability on screen first; exact px values follow from that, not the reverse
- **Whether the charge lane should show the safety-cap distance at all when no wall is in range** (854/868px
  is most of the room) — may read as "the whole room is dangerous" rather than "here specifically." Untested
  on screen
- **Whether gore's symmetric band is the right read** — a horn swing has a facing, even if the hit box does
  not care; whether that reads as confusing ("why is there danger behind it too") is a screen question
- **The pulse speed and both alpha fractions** (`ATTACK_PREDICT_PULSE_FRAMES`/`_MIN_ALPHA_FRAC`/`_MAX_ALPHA_
  FRAC`) — picked to be faster than the stun ring, not measured against anything on screen yet

---

## Files touched

| File | What |
|---|---|
| `src/view/monster_view.gd` | `_draw_attack_prediction` and its five shape functions, replacing `_draw_telegraph` |
| `src/view/fx_tuning.gd` | `ATTACK_PREDICT_*` constants, replacing `MONSTER_TELEGRAPH_*` |
| `src/stage/stage.gd` | `_monster_view.setup()` gains `_char`/`_grid` (optional — every other call site is unaffected) |
| `tests/nets/net_attack_predict.gd` | New — geometry for all five shapes, the live-tracking honesty contract, a branch-swap mutation |
| `tests/nets/net_monster.gd` · `net_monster_breath.gd` · `net_monster_charge.gd` · `net_monster_slam.gd` | `_RecordingMonsterView`'s `_draw_telegraph` override renamed to `_draw_attack_prediction`, recording `"predict"` instead of the retired `"telegraph"` |
