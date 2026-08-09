# Monster animation — the art that was already on disk finally plays

**Status**: done — **implementation finished.** Every trash-mob and boss sheet in `assets/monster/` now has a
state that draws it, driven from one table. **"Done" means implementation, not acceptance** (CLAUDE.md).

**Accepted**: **not by the user.** Seen on screen through the editor bridge in this session and confirmed
working (pig walk → shove on contact, hen walk → idle at range, bull roar → charge, all reading their own
sheets). **Whether the animations look good is untouched** — nobody has judged the motion itself.

**Where the design lives**: [../../design/monsters.md](../../design/monsters.md), whose own header named this
exactly: *"animation is entirely a code gap now. There is no art left to generate for the trash mobs."*

---

## What was wrong

`fx_tuning.MONSTER_SHEETS` held **one image per kind** and `monster_view` fitted that whole texture to the
box. **26 animation sheets sat in `assets/monster/` that nothing could draw** — hand one to that code and the
beast comes out squashed, because a 9-frame strip is 9× the box's width.

The bosses had nine sheets each and drew one of them. The trash mobs had five each and drew one.

## What was built

**One table, `fx_tuning.MONSTER_ANIM`: kind → state → sheet.** The character's own idiom (`CHAR_SHEET` plus
`CHAR_FRAMES`) brought over, with three differences the monsters forced:

| | Character | Monsters |
|---|---|---|
| Sheets | one, all states in it | **one per state** — the frame counts differ per pattern (gore 17, hurt 4) |
| Frame count | implicit (the table lists frame *numbers*) | **written down**, so a truncated png goes red instead of silently looping short |
| Missing state | barks | **falls back to idle** — the bosses have no hurt sheet, on purpose |

**Ten states** (`MON_IDLE`/`WALK`/`ATTACK`/`HURT`/`DEATH`/`WINDUP`/`CHARGE`/`FIRE`/`LEAP`/`STUN`), resolved
by `MonsterView.resolve_state()` in a fixed priority: **a boss's pattern outranks everything**, then hurt,
then attacking, then walking.

- **`Pattern` and the state set are deliberately not the same enum.** `Pattern.WINDUP` draws a roar,
  `Pattern.GORE` and a pig's body shove are both `MON_ATTACK`, and `MON_HURT` has no pattern behind it at all
- **`Pattern.IDLE` is not `MON_IDLE`** — a boss walks at you during `IDLE`
- **A boss never plays hurt.** A bull flinching out of its own charge would be the screen contradicting the sim

### The two mobs with no signal to hang an animation on

**The hen fires on one tick and leaves no notification.** The only trace is `reload_left` jumping back up, so
the view diffs that field — the same idiom it already used to find a hit by diffing hp — and latches the
8-frame spit.

**The pig has nothing at all.** It damages by body contact (`world_step._boxes_overlap` every tick), so there
is no event, only a condition. The view asks the same question `MONSTER_SHOVE_REACH_PX` (8px) early, so the
shove is a tell and not a report.

### Clocks

**Walking's clock is the monster's own `x`** (`MONSTER_WALK_PX_PER_FRAME`, **16px** per frame — it shipped at
12 and was slowed by eye; the constant's own comment carries the cadences either side), exactly as the
character's is. Everything else counts view frames from the moment the state changed. Two clocks for one gait
is the bug this splits to avoid — `character_view` records having been burned by it ("it stopped but the legs
keep moving"). One px value for every kind, on purpose: the kinds already move at different speeds, so the
same tick gives each a different cadence for free.

**`loop: false` clamps on the last cell.** That is what makes a death stay dead.

### The corpse is the death animation

Driven by the `age` the corpse already carried, so there is no second timer to drift.
**`MONSTER_CORPSE_LIFE_FRAMES` went 30 → 60** — the longest death sheet runs 32 view frames, so at 30 the
beast was still mid-fall when the whole afterimage had faded. `net_monster_sprite` measures that the corpse
outlives its own animation for every kind.

### The bull's sheets were the wrong size, and were padded, never scaled

The generator returned 86×54 frames against an 88×56 box. **`tools/pixel/pad_sheet.py`** rounds each frame up
by adding transparency — symmetric left/right, everything else on top, **bottom pad 0** — the rule
`monsters.md` already set when the bull's body sprite was padded. Nothing is resampled, so the pixel grid is
exactly what the generator produced. `bull_roar.png` was already 88×56 and was left untouched.

---

## What the nets measure, and what they cannot

`net_monster_sprite` grew 41 → 512 checks; `net_monster` gained three wiring checks.

**Measured**: every path loads · **the frame count in the table equals the png's width** (the check this
section exists for — one too high draws a transparent cell and the beast blinks out with nothing barking) ·
no frame is blank · frame 0 stands on the ground · the imported texture matches the png on disk · the state
priority table · loop-wraps vs. one-shot-clamps · the walk clock is `x` and nothing else · a missing state
falls back to idle · the corpse outlives its death animation · **and, driven through a real world**: a
walking pig reaches `MON_WALK`, a hit puts the hurt pose up and holds it past the flash, a corpse plays its
sheet through and stops.

**Not measured, in principle**: **whether the sheet in a slot is really that animation.** Point every row at
one png and all 512 checks stay green. Also dropped after measuring: "the feet touch the bottom row" and
`minx + maxx == w - 1` **per frame** — a charging bull is airborne on 4 of its 9 frames and a goring bull
leans 8px off-centre, and those are the animation working. Only frame 0 is held to the rest pose.

## Inversion

Eleven mutations, all red, one no-op control green:
frame count 9→8 · a death row set to `loop: true` · a walk row set to `loop: false` · corpse life back to 30 ·
hurt/attack priority swapped · the walk clock reading frames instead of `x` · boss patterns ignored ·
`_scan_anim` never called · the hurt latch never set · the hurt latch never decayed · `_corpse_art` frozen on
cell 0.

**Two holes were found by inverting and then closed** — both are the same shape, and it is the shape
CLAUDE.md warns about:

1. **The `loop` flags in the real table were unmeasured.** The clock checks used synthetic rows, so flipping
   `pig_death` to `loop: true` left all 498 checks green
2. **The corpse check drove `frame_index()` instead of the drawing.** Freezing `_corpse_art` on cell 0 — the
   exact bug — passed. It reads `view.corpse_frame()` now, which goes through the same function that
   produces the drawn rect

## The enlarged hen and the wolf, added after

The animation table made two more sets of art reachable — `hen_*` (48x64) and `wolf_*` (48x28) had been sitting
in `assets/monster/` with **no row in `monster_defs`**, which `monsters.md` had already named as the only
thing missing ("art on disk and nothing more").

- **The hen's box followed its art**, 24x28 → 48x64. `net_monster_sprite` asserts sheet == box, so this was
  not a tuning choice
- **The wolf is a fifth kind** (`KIND_WOLF`), spawnable with `V`, with **no placement anywhere** — that is
  the map's share, not the table's
- **`wolf_lunge.png` plays on contact**, the same door the pig's shove uses. The wolf has no lunge in the
  sim, and the picture does not claim one that never fires — but the *dash* the art implies is not a mechanic

**One behaviour was lost and it is worth naming**: at 24px the hen fit through a 32px gap and the pig did
not. **Nothing in the table is narrower than the pig any more**, so `net_monster`'s chimney check moved up a
size (pig fits, bull does not) rather than being weakened. Wanting the narrow-mob-drops-through-a-hole
behaviour back needs a *narrow kind*, not a smaller hen.

### The cost was measured, and the projection it replaces was wrong in a useful direction

`tools/stage/profile_monsters.gd` re-takes the whole table on demand — **that tool is the point**, because
`monster_defs.gd` has carried a standing "leave the measurement here" instruction since the bosses landed and
a box then moved with no way to re-take it.

| | cells | 1 alive | **20 alive (measured)** |
|---|---|---|---|
| pig | 88 | +192µs | **3,416µs — 20.5% of the 60Hz frame** |
| hen (enlarged) | 192 | +306µs | **5,318µs — 31.9%** |
| wolf | 84 | +197µs | 4,004µs — 24.0% |

**Cost is sublinear in box cells.** The hen has 2.2x the pig's cells and costs 1.6x.
`monsters-bigger-boxes.md` §4 built its entire estimate on cells-being-proportional and **flagged it as an
assumption**; the assumption was pessimistic, and the same result dissolves that doc's other open puzzle
("the rooster costs 1.6x the bull on 17% more cells" — per-cell work is simply not what dominates).

## What is still open

- **Nobody has judged the motion.** Every `hold` value in the table is a first guess
- **A corpse always faces right.** The death notification carries no `facing` (`monster_view`'s own note,
  unchanged by this work)
- **The wolf and the enlarged hen** (`hen_body.png`, `wolf_body.png`) are still art on disk with no row in
  `monster_defs` — [../1.ready/monsters-bigger-boxes.md](../1.ready/monsters-bigger-boxes.md)'s share
