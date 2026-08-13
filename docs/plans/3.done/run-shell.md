# Plan 1 — the run shell

**Status**: `3.done` — built in three stages on 2026-08-14. **14 nets · 293 checks · 1.2s · `[래퍼] 통과`.**
⚠ **`3.done` means the implementation finished. It does not mean anyone has played it** — see *What the build
actually is* below, which is the record of what three verifiers measured and what is still open.
**The implementation plan is the last section of this file** — three stages, three new nets, a named mutation
per check.
✅ **Corrected for [the 2026-08-14 adversarial review](../../adversarial-review-2026-08-14-ko.md) and for
[Hunting and the boss](../../design/hunting-and-the-boss-ko.md).** What changed, so the diff is not re-argued:
the eaten total gets **one write site and one function** (`Swarm.eat`) instead of "wherever `banked` or
`carried` is" · net 7 is **inverted** — it asserted a thing the same page forbade · the shell **rebinds the
view after `restart()`** · `_camera_rect()` **divides by zoom** · `cargo_lost` is in the struct and in the
ending table · the fallout is **five files, eight sites** · the unit is **경험치**, never 세포 · the two
folder-contract violations are placed properly · every net bound that came out of the thing it measured is
now a literal.

**What it closes**: **a run starts and it ends.** Today the game opens straight into the field and stops on a
300-second timer with no screen of any kind. After this plan there is a title page, a run, and an ending page
that leads back to the title.

**Nothing about the body, the parts, the species or the boss is in this plan.** The end condition here is a
placeholder that plan 4 replaces.

---

## What exists today, precisely

- `main.gd::_ready()` builds `FieldView`, a `Camera2D`, a `CanvasLayer`, `Hud`, `CardPanel` and calls
  `world.setup()`. **There is no phase** — the field is the whole game
- `World.over` flips true at `Rules.RUN_LENGTH` (300s) or `host_hp <= 0`, and then `step()` returns early.
  The screen freezes with the HUD still up
- `main.gd::_unhandled_key_input` reloads the scene on `R` when `world.over`
- **`Hud` is already half of the ending screen, and this is the piece the first draft of this plan missed.**
  `Hud::_paint` draws a **countdown** from `Rules.RUN_LENGTH - world.elapsed`, and calls `_paint_result(c)`
  when `world.over` — the run's four numbers already have a panel. The same method also draws the key legend
  `"WASD 이동 · Space 대시 · 1 모이기(커서) · 2 흩어지기"`
- ⚠ **The legend is true today and plan 2 makes every clause of it false. It is NOT this plan's to fix** —
  plan 1 does not change a single key. It is named here only so the next plan cannot claim it was unknown;
  `hands-and-commands` owns the rewrite

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
var paused := false              ## the ONE pause flag. See "Who owns the pause" below

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

### Who owns the pause — one flag, on `Run`

`World::step` already returns early on `pending_levels > 0`. Plan 2 adds `Tab` as a second reason and plan 3
adds banked levels as a third. ⚠ **The flag lands here, in plan 1, before there are two of them** — two
independent early returns in two files is how one of them gets missed, and the review found this plan's own
first draft naming the shell in one paragraph and `Run` in the next.

**`Run.paused` is the only pause in the game.** `Run.step()` checks it and skips `world.step()`; the shell
**sets** it and never keeps its own copy. `World::step`'s `pending_levels` guard stays where it is — it is
the sim refusing to advance past an unspent level, which is a different sentence from "a panel is open".

**`World.over` and `Rules.RUN_LENGTH` are deleted.** A run no longer ends on a clock.

⚠ **The fallout is five files and eight sites.** Counted across the whole repo — the first draft said four
files and the review found the fifth, which is `main.gd`, the file that drives everything:

| File | Site | What breaks | What to do |
|---|---|---|---|
| `src/sim/world.gd` | `step()`'s tail | the end condition itself | replaced by `Run` |
| `src/sim/rules.gd` | `RUN_LENGTH` | the constant | deleted |
| `src/view/hud.gd` | the countdown in `_paint` | reads a constant that no longer exists — **parse error** | **delete the countdown.** A run with no clock must not show one |
| `src/view/hud.gd` | `if world.over: _paint_result(c)` | the result panel | **move `_paint_result` out of the HUD** into `ending_screen.gd`. It is the ending screen, in the wrong file |
| `src/shell/main.gd` | `_process`'s `not world.over` gate | the step gate | becomes `run.step(delta)`, gated on `run.phase` |
| `src/shell/main.gd` | `_unhandled_key_input`'s `KEY_R and world.over` | the restart key | becomes `run.phase == Run.Phase.ENDING` |
| `tests/nets/net_hunt.gd` | sets the deleted fields | net | updated in this commit |
| `tests/nets/net_hud.gd` | reads them | net | its checks move — see below |

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
var experience: int = 0             ## everything eaten this run. See the unit note below
var cargo_lost: int = 0             ## what died out in the field with the clones carrying it
var species: PackedStringArray = [] ## names of species eaten at least once, in first-eaten order
var peak_swarm: int = 0
var clones_lost: int = 0
var body_slots: PackedStringArray = []  ## ELEVEN entries, "" for empty. The count is body-and-parts.md's slot table and nowhere else. Plan 3 fills it; ship it empty here
```

**The unit is 경험치** ([Hunting and the boss](../../design/hunting-and-the-boss-ko.md), which is newer than
the word 세포 and deletes it). Everything eaten is experience, and the ending says *"경험치 312"*.
⚠ **`세포` does not appear in this build's code, comments or strings.** The old word is in the prototype's
docs and it stays there.

### The eaten total has ONE write site, and it is a function

⚠ **`Swarm.banked` is not that number and saying it was is how this field would have shipped wrong.**
`banked` is what reached the host — after plan 2 deletes contact-absorb, a run that ends in death loses
everything every clone ever ate. **The ending must report what the run ATE, not what it banked**, or dying
with a fat swarm reads as having eaten nothing.

But the first draft's fix — *"`cells_eaten`, incremented wherever `banked` or `carried` is"* — **double-counts
every mouthful**, and three of the five reviewers found it independently. `Swarm::_absorb` does
`banked += carried[i]`: that is cargo **moving**, not food being eaten, and the sentence as written counts it
again. The ending's number then inflates with how fat the swarm was.

⇒ **`Swarm` gains one function and the arithmetic lives only inside it:**

```gdscript
var eaten := 0.0   ## monotonic. Every mouthful this run, host and clones together. Never decremented

## THE ONLY PLACE `banked` OR `carried[i]` GROWS BY NEW MATERIAL. Moving cargo between two bodies is not
## eating and must not call this — `_absorb()` assigns directly, and that asymmetry is the whole point.
func eat(i: int, amount: float) -> void:
    eaten += amount
    if i == 0: banked += amount
    else: carried[i] += amount
```

- `Swarm::_try_eat` calls it for both the host and the clone arm
- `World::_contact` calls it where it does `swarm.banked += threat * CRITTER_MEAT` today
- `Swarm::_absorb` **does not call it** and keeps assigning `banked`/`carried` directly
- **Plan 4 moves the call to the corpse-completion site** and this function does not change

**`RunResult.experience` rounds `swarm.eaten` once, here, and nowhere else.**

**Who fills the rest**: `Run` copies it out of `World` at the moment the end is detected. `peak_swarm`,
`clones_lost` and `cargo_lost` exist today. **`species` does not exist anywhere** — `World` gains
`species_eaten: PackedInt32Array` (ids, first-eaten order) and **plan 4 is what puts anything in it**; until
then it is empty and the ending prints `없음`.

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

⚠ **Banking it does not raise `eaten`.** It was eaten when it was eaten; this is the same cargo arriving.
The net for it asserts `eaten` is **unchanged** across the beat — see net 6, which the review had to invert.

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

**Signals**: `start_pressed` and `quit_pressed`. **Both.** ⚠ The first draft had this file call
`get_tree().quit()` itself and justified it as "it touches the tree, so it cannot live in `sim/`" — **a false
dichotomy the review named**: the third place is the shell, and this file had already defined the signal
pattern one line above. **`src/view/` draws and reports; it does not decide the process ends.** The shell
connects both signals. The title screen knows nothing about `Run`.

### `src/view/ending_screen.gd` — new

**One screen, two outcomes** (user, 2026-08-14). Same layout, different headline and different colour.

| Line | Source | Shown when |
|---|---|---|
| headline | `보스를 삼켰다` / `먹혔다` | always |
| 걸린 시간 | `result.elapsed`, as `m:ss` | always |
| **먹은 경험치** | `result.experience` | always |
| 먹은 종 | `result.species` joined | always — `없음` when empty |
| 최대 무리 | `result.peak_swarm` | always |
| 잃은 클론 | `result.clones_lost` | always |
| **같이 날아간 것** | `result.cargo_lost` | always |
| the body | `result.body_slots`, eleven squares | **drawn empty in this plan.** Plan 3 fills it |

⚠ **같이 날아간 것 is one of the prototype's four numbers and the first draft promised it in prose while
leaving it out of both the struct and this table** — which is why plan 3's net 13 asked for a check with
nowhere to point. It is here now, in both places.

**Two keys and two buttons**: `R` and a `다시 하기` button restart; `Esc` and a `타이틀로` button go to the
title. The user asked for both routes (2026-08-14).

⚠ **The two keys are read in the shell, not here.** `src/shell/` is the only place that reads `Input`, and
the first draft put an `_unhandled_key_input` in a `src/view/` file — a folder-contract violation with a
precedent (`card_panel.gd`) that is **itself the violation**, not a licence. The ending screen emits
`restart_pressed` and `title_pressed` for its buttons; `main.gd::_unhandled_key_input` maps `R` and `Esc`
onto the same two calls.

- **`restart()` takes a NEW seed.** 다시 하기 is another run, not a retry of the same ground. A seeded retry
  is a different game and nobody asked for it
- **The seed comes from the shell**, not from `sim/` — `Time` is a tree-adjacent global and `sim/` may not
  read it. `main.gd::_ready` already does this; keep it there
- **`Esc` during PLAY does nothing in this plan.** Not a pause, not a quit. A player will press it, and
  doing nothing is a choice made here rather than a menu invented by the builder

**Every string above is Korean.** `CLAUDE.md`: in-game text is what the user reads.

### `src/shell/main.gd` — rewired

`main.gd` owns a `Run`, not a `World`. Its `_process` switches on `run.phase`:

- **TITLE** — title screen visible, field/HUD/cards hidden, camera parked
- **PLAY** — exactly today's behaviour, reading `run.world`
- **ENDING** — ending screen visible, field still drawn behind it (frozen), HUD hidden

#### ⚠ The view has to be rebound, and nothing in the first draft did it

`main.gd::_ready` sets `view.world` and `hud.world` **once**. `Run.start()` and `Run.restart()` each build a
**new** `World`. So after 다시 하기 the sim runs a fresh world and **the screen keeps drawing the previous
one** — the exact mirror of the signature fake, and two reviewers found it independently.

```gdscript
func _bind_world() -> void:      ## called immediately after run.start() and run.restart(), nowhere else
    view.world = run.world
    hud.world = run.world
```

**The net pins instance identity, not state**: after `restart()`, `view.world` **is** `run.world`. Comparing
fields would pass on two different worlds that happen to start alike — which is every world.

### The camera opens tight and pulls back as the swarm grows

**The user's read of the prototype, 2026-08-14: the map felt small.** The field is not changing — it stays
3840×2160 — **the camera is.**

`zoom = lerp(Look.ZOOM_NEAR, Look.ZOOM_FAR, clampf(count / Look.ZOOM_FULL_AT, 0, 1))`, smoothed over
`Look.ZOOM_LERP` so it never snaps.

⇒ **It fixes the complaint from the other end.** Alone, you are close, and one 14px body fills enough of the
screen to read as a creature rather than a dot. At forty, you are far enough back to see the swarm you are
steering — which is the picture this game is selling.

⇒ **It is also why the minimap can wait until plan 4.** Early on there is nothing off-screen worth marking.

#### ⚠ Culling breaks at the exact moment zoom starts working

`main.gd::_camera_rect` returns `Rect2(cam.position - vp * 0.5 - vp * 0.1, vp * 1.2)` and **does not divide
by zoom.** `FieldView::_paint` uses that rect for all three culling loops. At `ZOOM_FAR` (0.8) the visible
width is `vp / 0.8 = 1.25 × vp` while the rect covers `1.2 × vp` — **so things inside the screen stop being
drawn, and they stop the moment the swarm gets big enough for the zoom to do its job.** No error, no log.

```gdscript
func _camera_rect() -> Rect2:
    var vp := get_viewport_rect().size / cam.zoom.x      ## the divide is the fix
    return Rect2(cam.position - vp * 0.5 - vp * 0.1, vp * 1.2)
```

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

New file `tests/nets/net_run.gd`. **Every check below must be inverted before it counts** (`CLAUDE.md`), and
the mutation to use is named where the check is one of the shapes the review flagged.

1. `Run.new()` starts in `TITLE` with `world == null`
2. `start()` → `PLAY`, `world != null`, `swarm.count == 7`. ⚠ **The literal 7, not `1 + Rules.START_CLONES`** —
   a bound read out of the thing it measures passes at any value, and **"the swarm started at zero" is the bug
   that walked through 102 green checks.** Plan 2 takes `START_CLONES` to 0 and this check is *supposed* to go
   red that day
3. `start()` twice yields **two different `World` instances** — pin identity, not just state
4. Driving `step()` with `host_hp = 0` flips to `ENDING` with `outcome == DIED` **in one step**
5. Setting `stage_cleared` flips to `ENDING` with `outcome == CLEARED` **only after** `CLEAR_ABSORB_TIME`
   elapses — assert it is still `PLAY` at half the beat. *A check that reads only final state cannot measure
   an ordering contract*
6. **The beat banks without eating.** Give a clone a known `carried`, clear, and assert: `banked` rose by
   exactly that amount **and `swarm.eaten` did not move.** ⚠ **This is the inverted form of the first draft's
   net 6**, which asserted the absorbed cargo was *added* to the run's eaten total — double-counting it,
   because it was counted when the clone ate it
7. **A clone that dies out in the field still counted what it ate.** Feed a clone a known amount, kill it,
   and assert `result.experience` **still includes it** while `banked` never saw it. ⚠ **Inverted from the
   first draft**, which asserted the opposite and could not pass: the same page defines the total as never
   decremented, and *"what the run ATE, not what it banked"* is the reason the field exists
8. **`_absorb()` never raises `eaten`.** Park a loaded clone on the host, step once, assert `banked` rose and
   `eaten` did not. *This is the specific write site that was double-counted; it needs its own bite*
9. `to_title()` → `TITLE`, `world == null`, and `result` still readable
10. `restart()` from `ENDING` → `PLAY` without passing through `TITLE`
11. **The view is rebound.** Drive `main.gd` treed: start, force the ending, restart, then assert
    `view.world` **is the same instance as** `run.world` — and `hud.world` too. *Comparing fields passes on
    two different worlds; use identity*
12. **Driven, not grepped**: add `main.gd` to `t.root`, `pump_frames`, then assert `visible` on the title
    screen, the field, the HUD and the ending screen **in each of the three phases**. ⚠ **Treed, not
    untreed** — `main.gd::_process` reaches `get_viewport_rect()` through `_camera_rect()`, so the untreed
    form the first draft called for cannot run a single phase. Null the fields back out before `_ready()`
    so the net is exercising the real wiring, which is the part that matters
13. `_paint_title(...)` and `_paint_ending(...)` hooks cut out of `_draw()` capture their arguments; assert
    the four button rectangles land **inside the viewport** and that the ending's headline string differs
    between `CLEARED` and `DIED`. *`visible` is not "on screen"* — assert `size != Vector2.ZERO` too
14. **A run does not end on a clock, driven.** Step a `Run` for **900 simulated seconds** with the host alive
    and assert `phase == PLAY`. ⚠ **Not "`Rules` has no `RUN_LENGTH`"** — that measures a name's absence and
    passes against a hardcoded `300.0`. Drive it synchronously with `step(1.0/60.0)` in a loop, **not**
    `pump_frames`, or this one check costs half the round
15. **The seven ending lines, by value** — the four inherited from `net_hud` plus 걸린 시간, 먹은 경험치 and
    먹은 종. Feed a known result and assert each **label with its number** appears. `net_hud`'s own comment
    records why: a bare number match was measured worthless — swapping two rows stayed green, and deleting a
    row outright stayed green
16. **The beat pulls**: with 20 clones scattered, assert the mean distance to the host **falls every frame**
    of the beat. *Asserting only `count == 1` at the end passes with no pull at all*
17. **`_separate` is off during the beat** — place two clones 2px apart and assert they are not pushed
18. **The outcome latches**: set `stage_cleared`, then zero `host_hp` mid-beat, and assert `CLEARED`
19. **A level earned during the beat opens no cards** — `pending_levels` is 0 at the flip
20. `restart()` twice produces two different worlds **and two different seeds**
21. **The camera rect survives the zoom.** Set `cam.zoom` to `ZOOM_FAR`, place a clone at a **literal world
    coordinate** just inside the viewport's real corner, pump a frame, and assert `_paint_cell` was called
    for it. Then set `ZOOM_NEAR` and assert a clone outside is still culled — *one bite does not prove the
    range, and the whole point of the zoom is that it changes what is on screen*
22. **The pause is one flag.** Set `run.paused`, step, and assert `world.elapsed` did not move — then clear
    it and assert it does. *A pause that only ever locks is a panel that never closes*

**Net hygiene, corrected**: the wrapper reds below **five nets in the round**, and the round has ten. Adding
`net_run.gd` cannot trip it, and the first draft's reading — that new nets must land in groups — was the right
conclusion from the wrong rule. **The real reason `net_run.gd` and the `net_hunt`/`net_hud` updates land in one
commit is that they break together**: `hud.gd` losing `RUN_LENGTH` makes two nets vanish, not go red.

## Acceptance

**The user opens the game, presses 시작하기, plays, dies or clears, and lands on the ending screen, then goes
back to the title from both routes.** Nothing is accepted until they say the shape reads right.

**Not accepted by**: the net going green, a screenshot existing, or an agent walking through it.

---

# Implementation plan

**Written 2026-08-14 against the tree at `967e81c` plus the working-tree corrections already in `net_eat_carry`
and this file.** Everything above is the design; everything below is the order to build it in.

**Baseline measured, not assumed**: `powershell -ExecutionPolicy Bypass -File tests/run_nets.ps1` →
**10 nets · 113 checks · 0.9s · `[래퍼] 통과`.** The design text above says 111; `net_eat_carry` gained two
constant-against-constant checks in the working tree, which is the whole difference.

## Three things measured today that change how this gets built

### 1. A new `class_name` file is invisible until the project is re-imported — and `--script` does NOT re-import

Two throwaway classes referencing each other were dropped into `tests/` and driven headless.
**Three separate `--headless --script` runs all failed with `Parse Error: Identifier "ProbeAlpha" not
declared in the current scope`.** One `--headless --import` run fixed it and the next `--script` printed
the expected values.

⇒ **This plan creates four new `class_name` files** (`Run`, `RunResult`, `TitleScreen`, `EndingScreen`).
**The first net round after each of them is written will be red for a reason that is not the code.** Run

```
./Godot_v4.7.1-stable_win64.exe --headless --path . --import
```

once after adding a `class_name`, before believing any red. ⚠ **`CLAUDE.md` currently says the opposite** —
*"any `--headless --script` invocation re-imports"* — and that sentence is wrong as measured. Flagged to
`main`; **this plan does not edit `CLAUDE.md`.**

### 2. `Run` holding a `RunResult` that defaults a field from `Run.Outcome` is NOT a cyclic reference

The same probe pair mirrored the exact shape this plan asks for: class A owns `enum Outcome` and holds
`B.new()`, class B declares `var outcome: int = A.Outcome.NONE`. **Godot 4.7.1 parses it and runs it**
(`outcome=0`, `cleared=1`). ⇒ **Write `run_result.gd` exactly as the design section above shows it.** No
enum needs relocating and no forward declaration is needed.

### 3. What "the net VANISHES" actually looks like on the wrapper — measured

A net file with a parse error in its base class (the exact shape `net_hud.gd` takes when `hud.gd` breaks)
was added and the round was run:

| What the round printed | Reading |
|---|---|
| `zzprobe  통과 0  [실패]` | the per-net line **does** flag it |
| `[net] 통과 113개 · 실패 0개` | ⚠ **the totals are identical to a clean round.** The failure counter never moves |
| runner exit code `0` | ⚠ the runner itself thinks it succeeded — `_note_fail` is never reached, because `script.new()` errors before it |
| `[침묵사] stderr에 선언되지 않은 출력이 15줄` | **this is the only thing that turns the round red** |

⇒ Two operational consequences, and both bind every stage below:

- **`[래퍼] 통과` is the verdict and the pass count is not.** `CLAUDE.md` already says this; here is the
  measurement behind it. A stage that ends with "113 passed" and a red wrapper line has **lost checks**
- **The runner's own zero-check detector does not fire for this failure mode.** It catches a net that ran
  and asserted nothing; it does not catch a net that never loaded

## The dependency that fixes the stage order

`hud.gd` is the joint. It reads `Rules.RUN_LENGTH` (the countdown) and `world.over` (the result panel), and
**`net_hud.gd` declares `class Spy extends Hud`** — so the moment `hud.gd` stops parsing, `net_hud`'s seven
checks stop being run, four of which are the only place the ending's four numbers are measured by value.
`net_cards.gd` breaks by a second route: it `load()`s `main.gd`, which constructs a `Hud`.

⇒ **The clock cannot be deleted in a stage that does not also finish `hud.gd`, `main.gd`, `net_hud`,
`net_hunt` and `net_cards`.** That is stage 3, and it is the reason stage 3 is the big one.
⇒ And the four ending numbers **arrive in their new home one stage before they leave their old one**
(stage 2 adds them to `net_screens`; stage 3 removes them from `net_hud`). For one stage they are asserted
twice. That is deliberate: *a check that disappears is not a check that passed.*

---

## Stage 1 — the sim spine. Nothing is deleted and the game does not change

**Boundary**: 11 nets green, `[래퍼] 통과`. **Launching the game plays exactly as it does today** — `Run`
exists and nothing calls it yet.

### Files

| File | Change | Why here |
|---|---|---|
| `src/sim/run.gd` | **new** — `Run`, the phase machine | nothing else can be driven without it |
| `src/sim/run_result.gd` | **new** — `RunResult`, the snapshot | `Run` holds one |
| `src/sim/rules.gd` | **add** `CLEAR_ABSORB_TIME` `CLEAR_ABSORB_PULL`. `RUN_LENGTH` untouched | additive, so nothing downstream breaks |
| `src/sim/swarm.gd` | **add** `eaten` · `eat()` · `clear_pull`, route `_try_eat` through `eat()`, third clone mode, `_separate` skip | the eaten total and the beat both live here |
| `src/sim/world.gd` | **add** `stage_cleared` · `species_eaten` · `levels_frozen`, route `_contact` through `swarm.eat()`, gate `_grow()` | the end condition and the level freeze |
| `tests/nets/net_run.gd` | **new** — the sim half, 16 checks | — |

### `src/sim/swarm.gd`

`eat()` verbatim from the design section above. Three call-site rules, and the third is the one a builder
would get wrong:

- `_try_eat`'s two arms become `eat(i, 1.0)` — the `if i == 0` split moves inside `eat()`
- `_absorb()` **keeps assigning `banked` directly.** It must not call `eat()`
- **`World::_contact` calls `eat(0, …)`, not `eat(i, …)`.** ⚠ The loop that finds the eater walks the whole
  swarm, but the line it replaces is `swarm.banked += …` — it credits the host **whichever body touched the
  critter**. Passing `i` would silently move critter meat onto the clone's `carried`, which is a rule change
  nobody asked for in plan 1. **Preserve today's behaviour; plan 4 moves this call to the corpse site anyway**

`clear_pull` changes two things in `step()` and both are required:

```gdscript
func step(dt: float, food: Food = null) -> void:
    _rebuild_grids(food)
    _move_host(dt)
    for i in range(1, count):
        _move_clone(i, dt, food)
    if not clear_pull:                     ## the beat's separation skip. See _move_clone
        for i in range(1, count):
            _separate(i)
    for i in count:
        _try_eat(i, dt, food)
    _absorb()
```

and in `_move_clone`, **the pull is a third branch that also replaces `speed`**:

```gdscript
var speed := Rules.CLONE_SPEED_FOLLOW if state[i] == FOLLOW else Rules.CLONE_SPEED_SCATTER
if clear_pull:
    speed = Rules.CLEAR_ABSORB_PULL
```

⚠ **Setting only `desired` and leaving `speed` alone clamps the 900px/s pull back down to 215** through
`vel[i] = desired.limit_length(speed)` at the tail of the function, and net 16's *"falls every frame"* would
still pass while the beat crawls. The pull branch takes the `if clear_pull` position **before** the
`FOLLOW`/`SCATTER` test and steers at `pos[0]`.

### `src/sim/world.gd`

- `stage_cleared := false` — set in `_contact()` on the line that already does `critters_eaten += 1`, guarded
  by `critter_threat[k] == Rules.CRITTER_THREAT_MAX`. Comment it as **plan 4's placeholder**
- `species_eaten := PackedInt32Array()` — declared, appended to by nothing in this plan. It is the shape
  plan 4 fills; net 15 measures the empty case (`없음`)
- `levels_frozen := false` — **`_grow()` returns immediately when it is true.** This is what "a level earned
  during the beat is swallowed" actually needs: during the beat `_absorb()` banks every returning clone's
  cargo, `swarm.banked` jumps, and `_grow()` would hand out levels the ending then sits underneath
- ⚠ **`Run` must ALSO zero `pending_levels` and `offer` when the beat starts.** `levels_frozen` stops new
  levels; a level already pending makes `World::step()` early-return and **the beat never advances at all**

### `src/sim/run.gd`

```gdscript
func step(dt: float) -> void:
    if phase != Phase.PLAY or paused:
        return
    if absorb_beat > 0.0:
        absorb_beat -= dt
        world.step(dt)
        if absorb_beat <= 0.0:
            _finish_clear()
        return
    world.step(dt)
    if world.host_hp <= 0:
        _end(Outcome.DIED)
    elif world.stage_cleared:
        _begin_clear()
```

**The latch is the shape, not a flag**: once `absorb_beat > 0.0` the `host_hp` test is unreachable, so dying
mid-beat cannot rewrite a clear into a death (net 18). `_begin_clear()` sets `absorb_beat`,
`swarm.clear_pull = true`, `world.levels_frozen = true`, zeroes `pending_levels`/`offer`, **and takes the
snapshot** — `result.elapsed` is stamped at detection, not at the flip.

`_finish_clear()` walks the swarm **backwards** and banks at the call site:

```gdscript
for i in range(world.swarm.count - 1, 0, -1):
    world.swarm.banked += world.swarm.carried[i]   ## NOT eat() — this cargo was counted when it was eaten
    world.swarm.carried[i] = 0.0
    world.swarm.remove_at(i)
```

Backwards because `remove_at` swaps the last row down. `clones_lost` is untouched — these were absorbed,
not lost. Then `clear_pull = false`, `outcome = CLEARED`, `phase = ENDING`.

`Run` also carries **`var seed_used := 0`**, written by `start()` and `restart()`. Net 20b reads it.

### The 16 checks of stage 1, and the mutation that must redden each

`tests/nets/net_run.gd`. **`sim/` only — it must not `load()` a view or shell file**, so that a broken
`hud.gd` in stage 3 cannot take these with it.

| # | Check (label in Korean) | Mutation that must go red |
|---|---|---|
| 1 | `Run.new()` is TITLE, `world == null` | initialise `phase = Phase.PLAY` |
| 2 | `start()` → PLAY, `world != null`, **`swarm.count == 7` as a literal** | `Rules.START_CLONES` 6 → 5. ⚠ Writing `1 + Rules.START_CLONES` survives that mutation and is the exact shape the review flagged |
| 3 | `start()` twice yields two **different instances** (`w1 != w2` by identity) | make `start()` reuse: `if world == null: world = World.new()` |
| 4 | `host_hp = 0`, one `step()` → ENDING · DIED | compare `host_hp < 0` |
| 5 | `stage_cleared` → **still PLAY at half the beat**, ENDING after the full beat | flip to ENDING on detection with no beat |
| 6 | the beat **banks without eating**: a known `carried`, cleared → `banked` rose by exactly it **and `eaten` did not move** | `_finish_clear()` calls `swarm.eat(0, carried[i])`. ⚠ The net must silence food **and** critters first, or it is measuring spawn luck |
| 7 | a clone killed in the field: `result.experience` **still contains** what it ate, `banked` never saw it | `eat()` increments `eaten` only for `i == 0` |
| 8 | `_absorb()` never raises `eaten`: loaded clone parked on the host, one step → `banked` rose, `eaten` flat | `_absorb()` calls `eat(0, carried[i])` — the double-count three reviewers found |
| 9 | `to_title()` → TITLE, `world == null`, `result` still readable | leave `world` assigned |
| 10 | `restart()` from ENDING → PLAY, `world != null`, and a **different instance** from the previous run's | `restart()` sets `world = null`. ⚠ *"without passing through TITLE"* is **not measurable from final state** — the shell half of it is net 12's "the title screen is never visible across 다시 하기" |
| 16 | the beat **pulls**: 20 scattered clones, mean distance to `pos[0]` **falls on every frame** of the beat | `Rules.CLEAR_ABSORB_PULL` → `0.0`. Second bite: keep the `limit_length(speed)` clamp — a per-frame assertion catches a crawl that a final-count assertion does not |
| 17 | `_separate` is **off** during the beat: two clones 2px apart are not pushed | delete the `if not clear_pull` guard in `step()` |
| 18 | the outcome **latches**: `stage_cleared`, then `host_hp = 0` mid-beat → CLEARED | test `host_hp <= 0` before the `absorb_beat` guard |
| 19 | a level earned during the beat opens no cards: `pending_levels == 0` at the flip **and the beat actually completed** | never set `levels_frozen`. Second bite: skip the `pending_levels = 0` zeroing — the beat then stalls forever and the "actually completed" half bites |
| 20a | `restart()` twice → two different `World` instances | share the world across restarts |
| 22 | `paused` is one flag: set it, step, `world.elapsed` did not move — **then clear it and assert it does** | `Run.step()` ignores `paused`. Second bite: a pause that can never be cleared — *"a pause that only ever locks is a panel that never closes"* |

⚠ **`paused` is wired to nothing in plan 1.** Nothing in the shell sets it; `Tab` in plan 2 is its first
setter. It lands now because the design section above argues it, and net 22 is what keeps it from being a
comment. **Say so in the field's own comment** so it does not read as dead code to the next reader.

⚠ **Net 14 is NOT in this stage.** With `RUN_LENGTH` still alive, `World::over` flips at 300s and
`World::step()` early-returns — `Run.phase` would stay PLAY **because the world froze**, which is a green
that measures the opposite of its label. It lands in stage 3, where the clock is actually gone.

---

## Stage 2 — the two screens exist and are proven to draw. Still not wired

**Boundary**: 12 nets green, `[래퍼] 통과`. The game still plays as today; two new files draw correctly when
driven, and **nothing shows them yet.** That is the one stage boundary where `CLAUDE.md`'s "a feature nobody
has looked at" warning applies on purpose — it is closed one stage later, and the nets drive both files
**treed, with real frames pumped**, so "it was built" is not the claim being made.

**Depends on stage 1** — `ending_screen.gd` reads a `RunResult`.

### Files

| File | Change |
|---|---|
| `src/look.gd` | **add** the title/ending palette and metrics, and the four zoom constants |
| `src/view/title_screen.gd` | **new** — `TitleScreen`, four buttons, two signals |
| `src/view/ending_screen.gd` | **new** — `EndingScreen`, one layout two outcomes, two signals |
| `tests/nets/net_screens.gd` | **new** — 2 groups of checks, treed |

### `src/look.gd` — the new constants

The zoom four are named in the design's Numbers table. The screens need the rest, and they go **here** rather
than as file-local `const`s: `CLAUDE.md` and `look.gd`'s own header make this file the one place a
presentation constant lives.

⚠ **`hud.gd`, `card_panel.gd` and `field_view.gd` already violate that** — they hold 17 colours between them.
**Do not retrofit them in this plan.** New code obeys the contract; the retrofit is its own change with its
own risk, and it is listed under *Out of scope* below.

| Constant | Value | Note |
|---|---|---|
| `ZOOM_NEAR` / `ZOOM_FAR` | `1.6` / `0.8` | Godot's `Camera2D.zoom`: **larger is closer in** |
| `ZOOM_FULL_AT` | `30.0` | measured against **`swarm.count`** (bodies, host included), not clones |
| `ZOOM_LERP` | `2.0` | per second, as `1.0 - exp(-ZOOM_LERP * delta)` — see stage 3 |
| `TITLE_BG` | `Color(0.07, 0.05, 0.05)` | **placeholder.** Art is generated and pointed at, never discussed |
| `SCREEN_TEXT` / `SCREEN_DIM_TEXT` | `Color(0.95, 0.92, 0.86)` / `Color(0.66, 0.62, 0.58)` | matches the HUD's existing pair |
| `BUTTON_SIZE` / `BUTTON_GAP` | `Vector2(280.0, 62.0)` / `18.0` | |
| `BUTTON_BG` / `BUTTON_BG_OFF` | `Color(0.16, 0.14, 0.13)` / `Color(0.11, 0.10, 0.10)` | |
| `BUTTON_EDGE` / `BUTTON_TEXT_OFF` | `Color(0.95, 0.85, 0.45)` / `Color(0.42, 0.40, 0.38)` | the greyed pair is what makes 도감/설정 read as *coming*, not broken |
| `ENDING_DIM` | `Color(0.04, 0.03, 0.03, 0.86)` | inherited from `hud.gd`'s `OVER_DIM`, which is deleted in stage 3 |
| `ENDING_CLEARED` / `ENDING_DIED` | `Color(0.95, 0.85, 0.45)` / `Color(0.85, 0.35, 0.32)` | *"same layout, different headline and different colour"* |
| `SLOT_SIZE` / `SLOT_GAP` / `SLOT_EMPTY` | `Vector2(38.0, 38.0)` / `8.0` / `Color(0.2, 0.18, 0.17)` | the eleven squares, drawn empty here |

### Both screens have the same skeleton

`extends Control`, and in `_ready()`:

```gdscript
set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   ## _and_offsets_ — see below
mouse_filter = Control.MOUSE_FILTER_STOP
```

⚠ **`set_anchors_preset` sets anchors and leaves the offsets alone**, so a Control on a bare `CanvasLayer`
keeps `size == (0, 0)` and every rectangle computed from `size` piles into the top-left corner. `card_panel.gd`
carries the same note and it was **reported by the user on the first play.**

`_draw()` calls `_paint(self)` and `_paint` calls a hook per element, because Godot refuses to override
`draw_string`/`draw_rect` — a parse error. The hooks:

| Hook | On | Captured by |
|---|---|---|
| `_paint_text(c, p, text, font_size, col)` | both | net 15 |
| `_paint_button(c, r: Rect2, label: String, enabled: bool)` | both | net 13 |
| `_paint_slot(c, r: Rect2, filled: String)` | ending | the eleven squares |

and each screen exposes the **pure** `_rect_of(k) -> Rect2` that produced the rect it passed.

⚠ **Assert the captured argument equals what the pure function returns.** `CLAUDE.md` records a rect
function asserted correct while `_draw()` passed a bare `Rect2()` — 320 checks green, the panel painting at
zero size. Measuring `_rect_of()` alone measures nothing about what was drawn.

### `src/view/title_screen.gd`

Four buttons in the order and with the labels of the design table (시작하기 · 도감 · 설정 · 종료); indices 1
and 2 are drawn with `BUTTON_BG_OFF`/`BUTTON_TEXT_OFF` and **occupy their real place**. Signals
`start_pressed` and `quit_pressed`, emitted from `_gui_input` on a left click inside `_rect_of(0)` /
`_rect_of(3)`. Clicks on 1 and 2 do nothing.

⚠ **This file never calls `get_tree().quit()`** — the review named that a false dichotomy. It reports; the
shell decides. And **`_gui_input` is not the folder-contract violation** `card_panel.gd`'s
`_unhandled_key_input` is: `_gui_input` is the engine handing an event to a Control it hit-tested, not this
file reading `Input`. Keys stay in the shell.

### `src/view/ending_screen.gd`

`var result: RunResult = null`, and `_paint` returns immediately when it is null. Rows exactly as the design
table, all seven always drawn:

| Row | String |
|---|---|
| headline | `보스를 삼켰다` in `ENDING_CLEARED` / `먹혔다` in `ENDING_DIED` |
| 걸린 시간 | `"걸린 시간 %d:%02d"` from `result.elapsed` |
| 먹은 경험치 | `"먹은 경험치 %d"` |
| 먹은 종 | `"먹은 종 %s"`, `", ".join(result.species)` or **`없음`** when empty |
| 최대 무리 | `"최대 무리 %d"` |
| 잃은 클론 | `"잃은 클론 %d"` |
| 같이 날아간 것 | `"같이 날아간 것 %d"` |

then eleven `_paint_slot` squares from `result.body_slots` (all empty this plan), then two buttons —
`다시 하기` and `타이틀로` — emitting `restart_pressed` / `title_pressed`.

⚠ **The word 세포 appears nowhere.** ⚠ **`R` and `Esc` are read in the shell, not here.**

### The checks of stage 2

`tests/nets/net_screens.gd`. Treed (`t.root.add_child` + `pump_frames`), spies subclassing each screen and
capturing the hook arguments — the `net_hud.gd` / `net_paint.gd` pattern.

| # | Check | Mutation that must go red |
|---|---|---|
| 13a | after two pumped frames the title's `size == the viewport's size` and **is not `Vector2.ZERO`** | `set_anchors_preset` instead of `set_anchors_and_offsets_preset` |
| 13b | `_paint_button` was called **four** times, and each captured `Rect2` **equals `_rect_of(k)`** and lands inside `Rect2(Vector2.ZERO, viewport_size)` | `_paint` passes `Rect2()`; and separately, `_rect_of` offset by +2000px |
| 13c | buttons 1 and 2 arrive with `enabled == false`, 0 and 3 with `true` | fold `enabled` out of the call — ⚠ **assert the flags per index, never as a count**: two `false`s summed survives deleting one, which is the dim-check failure `CLAUDE.md` records |
| 13d | a left click inside `_rect_of(0)` emits `start_pressed`; inside `_rect_of(1)` emits **nothing** | make every rect emit `start_pressed` |
| 13e | the ending's headline string **differs** between `CLEARED` and `DIED`, **and so does its colour** | one headline for both outcomes; and separately, one colour for both |
| 15 | **the seven rows by value.** Feed a `RunResult` with values that are not substrings of one another and assert each **label together with its number** | swap the 잃은 클론 and 최대 무리 numbers; and delete the 먹은 경험치 row outright. ⚠ `net_hud.gd`'s own comment records that a bare number match survived **both** of those |
| 15b | `result.species` empty → the row reads **`없음`** | print an empty string instead |

**The four rows inherited from `net_hud`** — 잃은 클론 · 같이 날아간 것 · 최대 무리, plus the total that was
모은 것 and is now 먹은 경험치 — **are in check 15 from this stage on.** They stay in `net_hud` until stage 3.

---

## Stage 3 — the clock dies, the shell takes the phases, the loop closes

**Boundary**: 13 nets green, `[래퍼] 통과`, and **the game opens on a title, plays, ends, and comes back.**
This is the stage the user's acceptance is asked about.

**Everything in this stage lands in one commit** — that is the vanish constraint, not a preference.

### Files

| File | Change | What breaks without it |
|---|---|---|
| `src/sim/rules.gd` | **delete `RUN_LENGTH`** | — |
| `src/sim/world.gd` | **delete `over`** and `step()`'s tail; `step()` guards on `pending_levels` only | — |
| `src/view/hud.gd` | **delete** the countdown line, `_paint_result()`, `OVER_DIM`, and the `if world.over` branch | parse error — takes `net_hud` and `net_cards` with it |
| `src/shell/main.gd` | the phase rewrite (below) | — |
| `tests/nets/net_hunt.gd` | **delete** the `w5` "the run ends by itself" block (2 checks) | reads both deleted names |
| `tests/nets/net_hud.gd` | **delete** the result half (4 checks) and `w.over = true` | reads `world.over` |
| `tests/nets/net_cards.gd` | **open the run** before its shell section | ⚠ **the sixth fallout file, and no plan named it** |
| `tests/nets/net_run.gd` | **add** net 14 | — |
| `tests/nets/net_shell.gd` | **new** — nets 11 · 12 · 20b · 21 | — |

⚠ **`net_cards.gd` is the file the fallout table above misses.** It is named there only as *"it vanishes when
`hud.gd` stops parsing"*. The larger problem is that **13 of its checks reach `main.world`**, which stops
existing: `main.world.swarm.pos[0]` · `main.world.swarm.banked` · `main.world.offer` · `main.world.count` ·
`main.world.pending_levels`. Every one becomes `main.run.world`, **and the run has to be in PLAY first or
`run.world` is null.**

⇒ **Open it through the real path**: `main.title.start_pressed.emit()` then `await t.pump_frames(1)`, and add
one check that `main.run.phase == Run.Phase.PLAY` right there. Calling a private starter instead would hide
the shell's `connect()` line, which is the same failure `net_cards`'s own header was written about.

### `src/shell/main.gd`

`var run := Run.new()` replaces `var world := World.new()`. `_ready()` builds **every** child once —
`FieldView`, `Camera2D`, `CanvasLayer`, `Hud`, `CardPanel`, `TitleScreen`, `EndingScreen` in that order — and
connects four signals. **No node is added or removed per phase; only `visible` moves.**

```gdscript
func _process(delta: float) -> void:
    _apply_phase()
    if run.phase != Run.Phase.PLAY:
        return
    _sync_cards()
    if run.world.pending_levels == 0:
        _read_input()          ## Input is read in PLAY and nowhere else
    run.step(delta)            ## Run owns the pause; the shell keeps no copy
    _follow_camera(delta)
    _apply_zoom(delta)
    view.view_rect = _camera_rect()
```

⚠ **`_follow_camera`, `_apply_zoom` and `_camera_rect` all dereference `run.world` or the viewport** — every
one of them is inside the PLAY gate. In TITLE `run.world` is null and touching it is a crash, not a bug that
degrades.

```gdscript
func _bind_world() -> void:
    view.world = run.world
    hud.world = run.world
    if run.world != null:
        cam.position = run.world.swarm.pos[0]
        _zoom = Look.ZOOM_NEAR      ## snap, never lerp: a restart opens alone and must open tight
        cam.zoom = Vector2(_zoom, _zoom)
```

⚠ **The design section says `_bind_world()` is called after `start()` and `restart()` "and nowhere else".
That is one call site short.** `to_title()` drops the world too, and leaving `view.world`/`hud.world` pointed
at a dropped `World` is exactly the stale-reference shape the rebinding exists to prevent. **Call it after
all three**, and let the `null` guard above do the rest. `_apply_phase()` additionally sets `view.visible`
false in TITLE.

`_apply_zoom`, frame-rate independent and with the target read from the swarm:

```gdscript
var target: float = lerpf(Look.ZOOM_NEAR, Look.ZOOM_FAR,
        clampf(float(run.world.swarm.count) / Look.ZOOM_FULL_AT, 0.0, 1.0))
_zoom = lerpf(_zoom, target, 1.0 - exp(-Look.ZOOM_LERP * delta))
cam.zoom = Vector2(_zoom, _zoom)
```

`_camera_rect()` **divides by zoom**, exactly as the design section shows. Without it, at `ZOOM_FAR` the real
visible width is `vp / 0.8 = 1.25 × vp` while the rect covers `1.2 × vp`, and things inside the screen stop
being drawn **at the moment the zoom starts doing its job.**

`_apply_phase()` — the visibility table, asserted by net 12:

| | `title` | `view` | `hud` | `cards` | `ending` |
|---|---|---|---|---|---|
| TITLE | ✅ | ✖ | ✖ | ✖ | ✖ |
| PLAY | ✖ | ✅ | ✅ | by `_sync_cards` | ✖ |
| ENDING | ✖ | ✅ frozen behind | ✖ | ✖ | ✅ |

Keys, in `_unhandled_key_input`, **the only place either is read**:

- ENDING · `KEY_R` → `_restart()` · `KEY_ESCAPE` → `run.to_title()` then `_bind_world()`
- PLAY · **`Esc` does nothing.** Not a pause, not a quit — a decision made here rather than a menu invented
- the four button signals map onto the same two calls, so there is one implementation per route

```gdscript
## Monotonic microseconds, NOT int(Time.get_unix_time_from_system()) — that truncates to WHOLE SECONDS, so
## two restarts inside the same second hand out the same seed and 다시 하기 replays the identical field.
func _new_seed() -> int:
    return int(Time.get_ticks_usec())
```

⚠ **`main.gd::_ready` uses the seconds form today and the design section says to keep it.** Kept as-is it
makes net 20b fail and, worse, makes a fast retry silently deterministic. This is the one place this
implementation plan overrides the design text above.

### The checks of stage 3

| # | Where | Check | Mutation that must go red |
|---|---|---|---|
| 14 | `net_run` | **no clock, driven synchronously**: `step(1.0/60.0)` in a loop for 900 simulated seconds with the host alive → `phase == PLAY` **and `world.elapsed > 890.0`** | hardcode `if elapsed >= 300.0` back into `World::step`. ⚠ The `elapsed` half is not optional — without it a world that froze at 300s passes the label. ⚠ **Loop `step()`; `pump_frames` here costs half the round** |
| 11 | `net_shell` | **the view is rebound**: start, force the ending (`run.world.host_hp = 0`), restart, then `view.world` **is the same instance as** `run.world`, and `hud.world` too | delete `_bind_world()`'s call after `restart()`. ⚠ Compare identity — comparing fields passes on two different worlds, which is every world |
| 12 | `net_shell` | **`visible` per phase, treed**: fifteen assertions, the table above, walked TITLE → PLAY → ENDING → TITLE. ⚠ **Null `main.view`/`main.hud`/`main.title`/`main.ending` back out before calling `_ready()`** so the real wiring is what runs | never set `title.visible = false` on start; and separately, never set `ending.visible = true` |
| 12b | `net_shell` | across 다시 하기 the title screen is **never** visible and `view.world` changed instance | `_restart()` implemented as `to_title()` + `start()` |
| 20b | `net_shell` | two `_new_seed()` calls in a row differ, **and two restarts in a row produce two different `run.seed_used`** | `int(Time.get_unix_time_from_system())` — the real bug this bites |
| 21a | `net_shell` | **the zoom moves**: from `ZOOM_NEAR` with 30 clones added, `cam.zoom.x` falls over 30 pumped frames and moves toward `ZOOM_FAR` | `Look.ZOOM_LERP` → `0.0`; and separately, drop the `_apply_zoom` call from `_process` |
| 21b | `net_shell` | **the rect survives the zoom.** Host pinned at the literal `(1920, 1080)`, camera set there, 30 clones so the target **is** `ZOOM_FAR`, `main._zoom` seeded to `ZOOM_FAR`, one frame pumped → a clone at the literal `(2705, 1080)` reached `_paint_cell` | remove `/ cam.zoom.x` from `_camera_rect()` |
| 21c | `net_shell` | at `ZOOM_NEAR` with one body, a clone at the literal `(2520, 1080)` is **still culled** | make `_camera_rect()` return `Rect2(Vector2.ZERO, Rules.FIELD)` — *one bite does not prove the range* |

**Where 2705 and 2520 come from, so nobody re-derives them wrong.** The viewport is `1280×720`
(`project.godot`). At `ZOOM_FAR` 0.8 the real half-width on screen is `640 / 0.8 = 800`; the **fixed** rect
reaches `0.6 × 1280 / 0.8 = 960`; the **broken** rect reaches only `0.6 × 1280 = 768`. **785 sits in the gap**
— on screen, inside the fixed rect, outside the broken one — so `1920 + 785 = 2705`. At `ZOOM_NEAR` 1.6 the
rect reaches `0.6 × 1280 / 1.6 = 480` and the screen `400`, so **600 is off screen by either reading** and
`1920 + 600 = 2520`. **Silence the food** before capturing, or `_paint_cell` arrives 500 times.

⚠ **Seeding `main._zoom` rather than pumping to convergence is deliberate.** With `ZOOM_LERP` 2.0 the lerp
needs ~200 frames to settle within 0.001, and net 21 would become the slowest thing in the round. Setting
`_zoom` while the **target already equals it** is not faking the value — 21a is what proves the lerp runs.

---

## Order, in one line each

1. **Stage 1** — `run.gd`, `run_result.gd`, the three `sim/` edits, `net_run.gd`. Nothing deleted, game unchanged
2. **Stage 2** — `look.gd` constants, both screens, `net_screens.gd`. Needs `RunResult` from stage 1
3. **Stage 3** — the clock deleted, `main.gd` rewritten, four nets edited, `net_shell.gd`. **One commit**

**Run `--headless --import` after stage 1 and after stage 2** before believing any red.

## Risk — what this could break silently

- **`World::_contact` passing `i` instead of `0` to `eat()`** moves critter meat onto a clone's `carried`.
  No error, no failing net today, and it quietly makes hunting stop paying the host
- **The pull branch not replacing `speed`** leaves `limit_length(215)` on a 900px/s pull. The beat still
  finishes and net 16 still passes; it just crawls. Net 16 measuring *every frame* is what narrows it
- **`levels_frozen` without zeroing `pending_levels`** stalls the beat forever. Loud in play, and silent in a
  net that only reads the final phase — net 19 asserts the beat completed
- **`_bind_world()` missed on the `to_title()` path** leaves the view holding a dropped `World`
- **New `class_name` files read as parse errors until `--import`.** Measured today; will look like broken code
- **`net_cards`'s 13 shell checks** die on `main.world`. They do not vanish — they go red — but they will read
  as "the phase machine broke the cards", which is the wrong diagnosis to chase
- **`snap_2d_transforms_to_pixel = true` with a fractional camera zoom** (0.8 … 1.6) can shimmer on moving
  bodies. Not a net's job — **`verify-look`'s**, and the first thing to look at if the field reads jittery
- **`paused` is set by nobody in this plan.** It is not fake code only because net 22 drives it and plan 2
  binds it; if plan 2 slips, this is the field to re-read
- **The placeholder clear needs 25 clones** (`is_hunter_of` against `CRITTER_THREAT_MAX` 5 at
  `SWARM_PER_THREAT` 5). Reachable in plan 1 because the prototype's own growth still runs; **unreachable
  through plans 2 and 3, and that is accepted** above

## Acceptance

**Per stage** — the wrapper line, not the pass count:

| Stage | Green means | Looks like |
|---|---|---|
| 1 | 11 nets, `[래퍼] 통과` | nothing on screen changed. Launch it and confirm that |
| 2 | 12 nets, `[래퍼] 통과` | still nothing on screen changed |
| 3 | 13 nets, `[래퍼] 통과` | **title → 시작하기 → play → die → ending → 타이틀로 → title**, and 다시 하기 |

**The plan's own acceptance is the section above this one, and it belongs to the user.** Not to a net, not to
a screenshot, not to an agent walking through it.

⚠ **Call `harness-manager` after stage 3.** Three nets and ~40 checks land on a 0.9s round, and net 12 and
net 21 both pump frames. The old game lost a net to 24.3s unnoticed for weeks.
⇒ **It was not called, and it did not need to be.** The round did blow out — **18.2s**, of which `net_run`'s
900-second check was 17.4s measured in isolation — and builder fixed it inside the same edit that closed the
check's real hole, by raising `dt` to 1.0 for that check alone. 900 iterations prove what 54,000 proved,
because the check measures phase and elapsed rather than physics. **Round is back to 1.2s.**

---

## What the build actually is — three verifiers, 2026-08-14

**Written down because the next session sees only the repo.** None of this is acceptance.

**Measured and holding**, by driving rather than reading: the loop closes in both directions and by both
routes (buttons and `R`/`Esc`) · `_bind_world()` holds **by identity** on all three paths and `to_title`
leaves both fields `null` rather than dangling · `ending.result` is a different object per run — run 1 read
111, run 2 read 222 · `_read_input()` was called 8 times across a whole loop and the phase was **PLAY on
every one** · the camera rect reaches 960 against a real 800 at `ZOOM_FAR`, with a clone at the literal
(2705, 1080) drawn and one at (2520, 1080) culled at `ZOOM_NEAR` · 900 simulated seconds leave `phase == PLAY`
· the `eaten` ledger closes to **0.000000** over 18,000 frames against an independently counted source · an
A/B trace against `HEAD` is **byte-identical** through 270s, so nothing in ordinary play changed beyond the
clock's removal.

**Seen on screen, once, by `verify-look`** — the floor is `Look.BG` sampled at two points, the window is full
1920×1080 with no letterbox and no blur, 도감/설정 read as *coming* rather than broken, the ending's seven rows
read as a result and the frozen swarm shows behind the dim without competing with it, and the absorption reads
as swallowing from start to finish: **37 frames, a 1-frame tail, `무리 N` falling 39 → 30 → 6 → 0** with the
HUD gauge surging as bodies land.

### What 279 green checks could not see, and one look did

**Three defects, none visible to any net**, and all three are now fixed:
1. **The field had no floor colour.** `Look.BG` was read in zero places repo-wide, and `project.godot`'s
   `default_clear_color` was written as `rendering/environment/...` **inside** `[rendering]`, so its real key
   was `rendering/rendering/environment/...` — a setting nobody reads. The play background was engine grey,
   and the ending only looked right because `ENDING_DIM`'s 0.86 alpha over grey happens to read as black
2. **The absorption was a still frame for 62% of its length** — the pull crossed maximum spread in 0.5s
   against a 1.2s timer, so 45 frames were one motionless square while the HUD still read `무리 39`
3. **The game filled 44% of the window.** `scale_mode="integer"` floored 1.5× to 1×

⇒ **This is the fourth time this repo has measured it and it is worth the fourth line**: a screen defect is
invisible to a number. Five of stage 2's seven survivors were the same shape — a headline in the wrong band,
labels 10,000px away, six rows off the left edge — all green.

### Open, and each belongs to someone

**The user's call** (`verify-look` raised all three and refused to decide them):
- **The eleven empty slots** are an unlabelled row of uniform boxes with 184px of empty space above them.
  Do they read as *slots waiting*, or as noise? Plan 3 fills them, which may answer it by itself
- **시작하기 and 종료 are styled identically**, and all four buttons share the same yellow edge — the greyed
  signal is carried only by fill and text colour. Should 시작하기 stand out?
- **The title has no game name on it.** Within spec ("four buttons, a background, and nothing else") but it
  reads more like a pause menu than a title

**Plan 2's, and named here so it is not rediscovered**: `Run.paused` is set by nobody until `Tab` binds it ·
the HUD's key legend is wrong-in-advance and stays that way on purpose.

**Plan 4's**: `beat_frozen` freezes the ecosystem during the absorption, and it was added because the swarm
shrinking flipped `is_hunter_of()` mid-victory — critters turned from blue prey back to red hunters and could
still take hearts off the host at the moment the run was won. **The guard is written to survive plan 4's
deletion of `is_hunter_of` and `critter_threat`** — it gates *when the ecosystem steps*, not who hunts whom.

**Harness, still open**: `net_draw_leaf` covers `title_screen.gd` and `ending_screen.gd` only. `hud.gd`,
`card_panel.gd` and `field_view.gd` each call `draw_*` in 5–9 places and are **not** protected —
`CLAUDE.md`'s folder-contract section now says so by name.

## Out of scope — not this round, and builder does not expand into it

- **Every key.** `F` `V` `1` `2` `3`, `Tab`, the three active slots — plan 2. **The HUD's key legend stays
  exactly as it is**, wrong-in-advance and not this plan's to fix
- **The eleven body slots' contents.** Drawn empty; plan 3 fills `RunResult.body_slots`
- **`species_eaten` ever getting an entry**, and the species-id → name table — plan 4
- **The real clear condition.** `stage_cleared` is a placeholder with plan 4's name in its comment
- **The title background art.** Flat `TITLE_BG` ships; candidates get generated with `tools/pixel/` and the
  user points at one. **Do not block on it**
- **`도감` and `설정`.** Drawn, greyed, occupying their place, wired to nothing
- **Retrofitting `hud.gd` / `card_panel.gd` / `field_view.gd`'s 17 file-local colours into `look.gd`**
- **A minimap.** Plan 4, and the camera pull-back is why it can wait
- **`Esc` during PLAY**, a pause menu, and a seeded retry — all three named and refused above
