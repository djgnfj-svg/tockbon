# Plan 1 — the run shell

**Status**: `1.ready`. Part of [the grassland index](grassland-whole-loop.md). Build this first.

**What it closes**: **a run starts and it ends.** Today the game opens straight into the field and stops on a
300-second timer with no screen of any kind. After this plan there is a title page, a run, and an ending page
that leads back to the title.

**Nothing about the body, the parts, the species or the boss is in this plan.** The end condition here is a
placeholder that plan 4 replaces.

---

## What exists today, precisely

- `src/shell/main.gd::_ready()` builds `FieldView`, a `Camera2D`, a `CanvasLayer`, `Hud`, `CardPanel` and
  calls `world.setup()`. **There is no phase** — the field is the whole game
- `World.over` flips true at `Rules.RUN_LENGTH` (300s) or `host_hp <= 0`, and then `step()` returns early.
  The screen freezes with the HUD still up
- `main.gd::_unhandled_key_input` reloads the scene on `R` when `world.over`
- **`Hud` is already half of the ending screen, and this is the piece the first draft of this plan missed.**
  `hud.gd:58` draws a **countdown** from `Rules.RUN_LENGTH - world.elapsed`, and `hud.gd:69` calls
  `_paint_result(c)` when `world.over` — the run's four numbers already have a panel. `hud.gd:70-72` also
  draws the key legend `"WASD 이동 · Space 대시 · 1 모이기(커서) · 2 흩어지기"`, **every clause of which
  plan 2 makes false**

## What this plan builds

### `src/sim/run.gd` — new, the phase machine

`sim/` never touches the tree, so this is a `RefCounted` a net drives with `.new()`.

```gdscript
class_name Run
extends RefCounted

enum Phase { TITLE, PLAY, ENDING }
enum Outcome { NONE, CLEARED, DIED }

var phase: int = Phase.TITLE
var outcome: int = Outcome.NONE
var world: World = null          ## null while TITLE. Built fresh by start()
var result := RunResult.new()    ## only meaningful in ENDING

func start(run_seed: int) -> void          ## TITLE -> PLAY. Builds a new World
func step(dt: float) -> void               ## PLAY only. Drives world, watches for the end
func to_title() -> void                    ## ENDING -> TITLE. Drops the world
func restart(run_seed: int) -> void        ## ENDING -> PLAY, without passing through TITLE
```

**`start()` builds a brand-new `World` every time.** Reusing one and calling `setup()` again is how state
leaks between runs; `World` has **twenty** mutable fields and a missed one is a silent bug that only shows
on the second run — which is the run nobody tests.

**`step()` is the only place the end is detected**, and it checks in this order:

1. `world.host_hp <= 0` → `outcome = DIED`, `phase = ENDING`
2. `world.stage_cleared` → the great absorption beat (below), then `outcome = CLEARED`, `phase = ENDING`

**`World.over` and `Rules.RUN_LENGTH` are deleted.** A run no longer ends on a clock.

⚠ **The fallout is four files, not one.** Counted across the whole repo before being written down here:

| File | What breaks | What to do |
|---|---|---|
| `src/sim/world.gd:72` | the end condition itself | replaced by `Run` |
| `src/view/hud.gd:58` | the countdown reads a constant that no longer exists — **parse error** | **delete the countdown.** A run with no clock must not show one |
| `src/view/hud.gd:69` | `if world.over: _paint_result(c)` | **move `_paint_result` out of the HUD** into `ending_screen.gd`. It is the ending screen, in the wrong file |
| `tests/nets/net_hunt.gd:139` · `net_hud.gd:51` | both set or read the deleted fields | updated in this commit |

⚠ **`net_hud` does not go red here — it VANISHES**, which is worse. `hud.gd` failing to parse takes the
whole net with it, and `net_cards` too (it loads `main.gd`, which builds a `Hud`). **The four checks that
die are the ones whose own comment records that a bare number match was measured worthless** — swapping two
rows stayed green, deleting a row stayed green. **Those four checks move into `net_run` against the ending
screen, by value, in this commit.** A check that disappears is not a check that passed.

### `src/sim/run_result.gd` — new, what the ending screen reads

The ending screen must not reach into `World`. It reads a snapshot taken at the moment the run ended,
because `Run.to_title()` drops the world and the screen would then be reading a dead object.

```gdscript
class_name RunResult
extends RefCounted

var outcome: int = Run.Outcome.NONE
var elapsed: float = 0.0
var cells: int = 0                  ## everything eaten, counted in CELLS. See the unit note below
var species: PackedStringArray = [] ## names of species eaten at least once, in first-eaten order
var peak_swarm: int = 0
var clones_lost: int = 0
var body_slots: PackedStringArray = []  ## ELEVEN entries, "" for empty. The count is body-and-parts.md's slot table and nowhere else. Plan 3 fills it; ship it empty here
```

**The unit is the cell** (user, 2026-08-14). Everything the run counts as consumed is counted in cells, and
the ending says so: *"312 cells"*.

⚠ **`Swarm.banked` is not that number and saying it was is how this field would have shipped wrong.**
`banked` is what reached the host — after plan 2 deletes contact-absorb, a run that ends in death loses
everything every clone ever ate. **The ending must report what the run ATE, not what it banked**, or dying
with a fat swarm reads as having eaten nothing.
⇒ **`World` gains `cells_eaten: float`, incremented wherever `banked` or `carried` is**, and never
decremented. `banked` keeps its own job as the level-up currency. `RunResult.cells` rounds `cells_eaten`
**once, here, and nowhere else.**

**Who fills the rest of `RunResult`**: `Run` copies it out of `World` at the moment the end is detected.
`peak_swarm` and `clones_lost` exist today. **`species` does not exist anywhere** — `World` gains
`species_eaten: PackedInt32Array` (ids, first-eaten order) and **plan 4 is what puts anything in it**; until
then it is empty and the ending prints `없음`. `cargo_lost` is one of the prototype's four numbers and it
**stays**, as `RunResult.cargo_lost` — it is the number that says what the swarm lost out there.

### The end condition, temporarily

Plan 4 brings the boss. Until then, `World` gains:

```gdscript
var stage_cleared := false   ## set true the frame a critter with the maximum threat is eaten
```

Set it in `World::_contact()` at the point that already increments `critters_eaten`, when
`critter_threat[k] == Rules.CRITTER_THREAT_MAX`. **One line, and plan 4 rewrites the condition, not the
plumbing.** Write it with a comment naming plan 4 so it is not mistaken for the real rule.

⚠ **This condition dies in plan 2 and the build is left with no way to win.** Eating a max-threat critter
needs `is_hunter_of()` to be true, which needs 25 clones; plan 2 takes the swarm off the level-up and puts
it on `F`, and plan 3 deletes `add_clone()` from `take_card` — so reaching the clear needs level 25.
**Through plans 2 and 3 the only reachable ending is death.** That is stated here rather than discovered:
- **Plan 1 alone: reachable.** The prototype's own growth still runs, so the placeholder clear happens
- **Plans 2–3: unreachable, and accepted as such.** Do not invent an interim boss to paper over it —
  the ending screen is exercised by dying, and by `net_run` driving `stage_cleared` directly
- **Plan 4: the real condition** replaces it and this paragraph goes away

### The great absorption

**On clearing, the whole swarm is absorbed — bodies included, the one time that happens** (design doc,
*Stages*). Here it is a beat, not a mechanic: `Run` holds `absorb_beat: float`, set to
`Rules.CLEAR_ABSORB_TIME` when the clear is detected. While it is positive the field keeps moving, and when
it reaches zero the clones are removed, their `carried` is banked, and the phase flips.

**Clones removed here bank their cargo. Clones removed by dying do not.** That asymmetry is the whole point
of `carried` living in a packed array — do not add a "drop cargo" flag to `remove_at()` to serve this case;
bank it at the call site before calling.

**Four things about the beat that the first draft left to the builder, and each has one answer:**

1. **Who pulls, and what stops fighting it.** `Swarm` gains `clear_pull: bool`. While it is set, `step()`
   runs a **third clone mode** that steers every clone at `pos[0]` at `Rules.CLEAR_ABSORB_PULL` **and skips
   `_separate()` entirely.** Separation pushes bodies 16px apart every frame; run both and 40 clones sit in
   a ring not moving while the sim says they are being pulled — **screen and sim disagreeing, which
   `CLAUDE.md` names as the signature fake.** The net must measure the mean distance to the host falling,
   not just the final count
2. **Dying during the beat does not turn a clear into a death.** The outcome is **latched** when it is
   first detected. Checking `host_hp <= 0` first, every frame, means being hit while swallowing the boss
   prints 먹혔다 over the run you just won
3. **A level-up during the beat is swallowed.** `world.step()` freezes on `pending_levels > 0`, so a level
   earned by eating the boss would open three cards on top of the ending. **Levels stop being granted once
   the beat starts**; whatever is pending is dropped
4. **`result.elapsed` is stamped when the end is DETECTED**, not when the phase flips — the beat is not
   part of the player's time

### `src/view/title_screen.gd` — new

A `Control`. **Four buttons, a background, and nothing else.**

| Button | Label (Korean, in-game text is Korean) | State |
|---|---|---|
| start | 시작하기 | enabled |
| codex | 도감 | **disabled** |
| options | 설정 | **disabled** |
| quit | 종료 | enabled |

- **The two disabled buttons are drawn, greyed, and occupy their real place.** The user asked for the slots
  to be filled now (2026-08-14). Do not hide them and do not wire them
- **The background is art and art is not decided by discussion.** Ship a flat `look.gd` colour behind the
  buttons, expose it as `Look.TITLE_BG`, and generate real candidates with `tools/pixel/` for the user to
  point at. **Do not block the build on the picture**
- `quit` calls `get_tree().quit()` — and that is the one line in this file that touches the tree beyond
  drawing, so it lives here and not in `sim/`

**Signal**: `start_pressed`. The shell connects it. The title screen knows nothing about `Run`.

### `src/view/ending_screen.gd` — new

**One screen, two outcomes** (user, 2026-08-14). Same layout, different headline and different colour.

| Line | Source | Shown when |
|---|---|---|
| headline | `보스를 삼켰다` / `먹혔다` | always |
| 걸린 시간 | `result.elapsed`, as `m:ss` | always |
| 먹은 세포 | `result.cells` | always |
| 먹은 종 | `result.species` joined | always — `없음` when empty |
| 최대 무리 | `result.peak_swarm` | always |
| 잃은 클론 | `result.clones_lost` | always |
| the body | `result.body_slots`, eleven squares | **drawn empty in this plan.** Plan 3 fills it |

**Two keys and two buttons**: `R` and a `다시 하기` button restart; `Esc` and a `타이틀로` button go to the
title. The user asked for both routes (2026-08-14).

- **`restart()` takes a NEW seed.** 다시 하기 is another run, not a retry of the same ground. A seeded retry
  is a different game and nobody asked for it
- **The seed comes from the shell**, not from `sim/` — `Time` is a tree-adjacent global and `sim/` may not
  read it. `main.gd` already does this at `:19`; keep it there
- **`Esc` during PLAY does nothing in this plan.** Not a pause, not a quit. A player will press it, and
  doing nothing is a choice made here rather than a menu invented by the builder

**Every string above is Korean.** `CLAUDE.md`: in-game text is what the user reads.

### `src/shell/main.gd` — rewired

`main.gd` owns a `Run`, not a `World`. Its `_process` switches on `run.phase`:

- **TITLE** — title screen visible, field/HUD/cards hidden, camera parked
- **PLAY** — exactly today's behaviour, reading `run.world`
- **ENDING** — ending screen visible, field still drawn behind it (frozen), HUD hidden

### The camera opens tight and pulls back as the swarm grows

**The user's read of the prototype, 2026-08-14: the map felt small.** The field is not changing — it stays
3840×2160 — **the camera is.**

`zoom = lerp(Look.ZOOM_NEAR, Look.ZOOM_FAR, clampf(count / Look.ZOOM_FULL_AT, 0, 1))`, smoothed over
`Look.ZOOM_LERP` so it never snaps.

⇒ **It fixes the complaint from the other end.** Alone, you are close, and one 14px body fills enough of the
screen to read as a creature rather than a dot. At forty, you are far enough back to see the swarm you are
steering — which is the picture this game is selling.

⇒ **It is also why the minimap can wait until plan 4.** Early on there is nothing off-screen worth marking.

**Build the children once in `_ready()` and toggle `visible`.** Adding and removing nodes per phase means a
`_ready()` that runs more than once and `@onready` fields that go stale — and `CLAUDE.md` records a panel
that shipped without ever setting `visible` under 5,576 green checks. **Assert `visible` per phase in the
net.**

The input read moves behind the phase check: **`Input` is only read in PLAY.** Today `_read_input()` runs
whenever the cards are closed, which would let the player walk the host around behind the title screen.

## Numbers

| Constant | Value | Where | Why this one |
|---|---|---|---|
| `CLEAR_ABSORB_TIME` | `1.2` | `rules.gd` | long enough to read as a beat, short enough that nobody waits |
| `CLEAR_ABSORB_PULL` | `900.0` px/s | `rules.gd` | crosses a rallied swarm's radius in well under the beat |
| `TITLE_BG` | flat colour | `look.gd` | placeholder until a board is generated |
| `ZOOM_NEAR` / `ZOOM_FAR` | `1.6` / `0.8` | `look.gd` | close enough that one body reads; far enough that forty do |
| `ZOOM_FULL_AT` | `30` bodies | `look.gd` | fully pulled back before the cap, so the last ten still change the picture |
| `ZOOM_LERP` | `2.0` /s | `look.gd` | slow enough to be felt rather than seen |
| `RUN_LENGTH` | **deleted** | `rules.gd` | a run ends on the boss or on death, never on a clock |

## Nets

New file `tests/nets/net_run.gd`. **Every check below must be inverted before it counts** (`CLAUDE.md`).

1. `Run.new()` starts in `TITLE` with `world == null`
2. `start()` → `PLAY`, `world != null`, `swarm.count == 1 + Rules.START_CLONES`
3. `start()` twice yields **two different `World` instances** — pin identity, not just state
4. Driving `step()` with `host_hp = 0` flips to `ENDING` with `outcome == DIED` **in one step**
5. Setting `stage_cleared` flips to `ENDING` with `outcome == CLEARED` **only after** `CLEAR_ABSORB_TIME`
   elapses — assert it is still `PLAY` at half the beat. *A check that reads only final state cannot measure
   an ordering contract*
6. After a clear, `swarm.count == 1` and `result.cells` **includes** what the absorbed clones carried —
   give a clone a known `carried` first and assert the exact sum
7. After a death, a clone's `carried` is **not** in `result.cells`
8. `to_title()` → `TITLE`, `world == null`, and `result` still readable
9. `restart()` from `ENDING` → `PLAY` without passing through `TITLE`
10. **Driven, not grepped**: add `main.gd` to `t.root`, `pump_frames`, then assert `visible` on the title
    screen, the field, the HUD and the ending screen **in each of the three phases**. ⚠ **Treed, not
    untreed** — `main.gd::_process` reaches `get_viewport_rect()` through `_camera_rect()`, so the untreed
    form the first draft called for cannot run a single phase. Null the fields back out before `_ready()`
    so the net is exercising the real wiring, which is the part that matters
11. `_paint_title(...)` and `_paint_ending(...)` hooks cut out of `_draw()` capture their arguments; assert
    the four button rectangles land **inside the viewport** and that the ending's headline string differs
    between `CLEARED` and `DIED`. *`visible` is not "on screen"* — assert `size != Vector2.ZERO` too
12. `Rules` has no `RUN_LENGTH` — a run that ends on a clock is the thing this plan removes
13. **The six ending lines, by value** — the four checks inherited from `net_hud` plus 걸린 시간 and 먹은 종.
    Feed a known result and assert each **label with its number** appears. `net_hud`'s own comment records
    why: a bare number match was measured worthless — swapping two rows stayed green, and deleting a row
    outright stayed green
14. **The beat pulls**: with 20 clones scattered, assert the mean distance to the host **falls every frame**
    of the beat. *Asserting only `count == 1` at the end passes with no pull at all*
15. **`_separate` is off during the beat** — place two clones 2px apart and assert they are not pushed
16. **The outcome latches**: set `stage_cleared`, then zero `host_hp` mid-beat, and assert `CLEARED`
17. **A level earned during the beat opens no cards** — `pending_levels` is 0 at the flip
18. `restart()` twice produces two different worlds **and two different seeds**

**The wrapper reds below five nets**, so `net_run.gd` lands together with the `net_hunt` update in one
commit.

## Acceptance

**The user opens the game, presses 시작하기, plays, dies or clears, and lands on the ending screen, then goes
back to the title from both routes.** Nothing is accepted until they say the shape reads right.

**Not accepted by**: the net going green, a screenshot existing, or an agent walking through it.
