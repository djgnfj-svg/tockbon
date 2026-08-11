# Gate — the last square of the milestone chain

**One line**: a stone arch standing east of boss room ③. The rooster's death **brings the room's east wall
down and puts the arch beyond it**, and **standing at it ends the run** — the settlement screen opens, and the
button on that screen enters the town.

**Implemented**: **all of it, screen unverified** — `src/actor/stage_gate.gd` · `src/view/gate_view.gd` ·
the wall drop and the `at_gate` term in `stage.gd`. A clear and a death now differ by the panel's title line
(that one **overrules this doc's "deferrable"** — grounds in the plan). Detail:
[../plans/3.done/gate-ending-to-game.md](../plans/3.done/gate-ending-to-game.md)
**Accepted**: **unseen**

**A concept stays alive and never changes folders.** The two header lines are only "how much runs now" —
format per [README.md](README.md).

---

## Why — the chain has no last square

`docs/GDD.md` "First milestone" is one chain, and its own gap table calls this row **"An ending — still none
in the map"**. [../plans/3.done/planning-review-order.md](../plans/3.done/planning-review-order.md) makes it
step 4 of four. This doc owns it.

**Everything before it landed and the run still cannot end.** The bull, the rooster, the fire rune and the
wood wall are all in the tree; walk the map to its right edge today and **nothing happens.** A roguelike whose
run cannot close on a win has only one ending, and it is death.

### It is the ending **and** the stage transition — one object, not two

`docs/design/README.md` carried "Stage transition — none" with "method settled: beat the stage-1 boss, a gate
appears behind it, you go through". [../plans/3.done/stage1-map-layout.md](../plans/3.done/stage1-map-layout.md)
calls the same thing **「스테이지2 문」** and seats it behind room ③.

**Stage 2 does not exist**, so what is on the far side today is **the end of the run**.
⇒ **Build one object.** The day stage 2 exists, what changes is where it leads, not what it is.

---

## What it is — an arch, a seat, and one flag

**Not a `cell_materials` entry** (the grid is destructible and material-typed; an ending is not a material) and
**not a collision volume** (nothing in this repo has one). It is **a drawn sprite plus a standing test.**

**What it looks like**: `assets/town/departure_gate.png` — 36x44, a stone arch with glowing runes, drawn at
`TOWN_FIXTURE_ZOOM` 2.0 = **72x88 px on screen**, taller than the 32px player ([town.md](town.md), "Art").
**Reuse the picture.** A gate is a gate, and one image doing both ends of the loop makes "you go through
arches" a grammar the player already knows by the time they get here. A picture of its own is a TBD.

### It appears when the rooster dies — one flag, drawn and acted on from the same read

`Progress` already holds this fact, keyed by kind and generic: `boss_died(MonsterDefs.KIND_ROOSTER)`. Room ①'s
water is gated on exactly this shape for the bull (`stage.gd:587`), and
[../plans/3.done/stage1-bosses.md](../plans/3.done/stage1-bosses.md) records that **the rooster's own gate
exists in `Progress` and nothing is wired to it.** This is its first consumer.

**Before that flag, the arch is not drawn and standing there does nothing — both from that one read.**
Draw it from a second flag and the repo's signature fake is one edit away: an arch that does nothing, or an
invisible tile that ends the run.

**Why a flag and not a wall**: the wall between room ③ and the gate is **stone, not bedrock** (x367–368,
measured in the baked map), and stone is what blasts carve. A player who tunnels east before the fight would
otherwise walk into the ending with the boss alive. **The lock is the flag.**

### What is **not** reused: `Fixtures.at()`

The town's position-checking door looks like the obvious fit and is not, for two reasons that are both written
in the files themselves:

- **`fixtures.gd:15-18` says it: "x only. There is no y."** The town is one flat room. **The stage is not** —
  the gate's column is open from row 0 to row 24, so an x-only test reads "standing at the gate" while the
  player is falling past it, jumping over it, or standing on rubble above it. **A y band is needed in the
  first line of this code, not later.**
- **A fourth `Fixtures` kind turns `net_town` red immediately.** `net_town.gd:151-157` asserts, for **every**
  kind in `Fixtures.NAMES`, a seat inside the *town* room, and `:264` counts sprites against the same table.
  **Reusing `KIND_GATE` is worse**: `fixtures.gd:31` fixes its name as **출발문** and `town_view.gd:96-99`
  draws that name plus `[E] 출발문` over every fixture unconditionally — **the key prompt this doc rules out
  below arrives attached to the reuse.**

⇒ **What is reused is the idea, not the file: one seat constant, an x band and a y band.** It is smaller than
the town's table (one seat, not three), so nothing is lost by not sharing.

---

## Where it is — immediately east of room ③, and the camera pins it

Measured in `src/stage/terrain_map_generated.gd`:

| | Tiles | |
|---|---|---|
| Room ③ interior | x347–366, rows 13–24 | 20x12, the size `stage1-bosses.md` pinned |
| Its east wall | x367–368, rows 13–24 | **stone**, 2 tiles thick, all twelve rows |
| The ground beyond | x369–397, floor top **row 25** | 29 tiles, open sky above (rows 0–24 are empty in that column) |
| Map edge | row 25 is stone to x398, bedrock at x399 · rows 13–24 are bedrock at x398–399 | |

**Seat: tile x370, standing on floor row 25.** Centre `(370 + 0.5) * 32 = 11856px`, so the arch occupies
**11820–11892px**. The `+ 0.5` is `town_map.fixture_seats()`'s own idiom — off by half a tile and the arch
looks reached a step before it is.

### The camera is what fixes this, not level-design taste

Viewport **960x540** (`project.godot:23-24`), play zoom **1.0** (`stage.gd` `ZOOM_STEPS[0]`) ⇒ half-width
**480px**. The camera centres on the player plus a lead of up to **±72px** (`fx_tuning.CAM_LEAD_PX`, folded
into the focus at `stage.gd:741`), and the world clamp is far away (grid 4096 cells = 16384px), so it never
bites here.

| Player stands | Screen's right edge (lead 0 / +72) | **Arch at x370** (11820–11892) | ~~x384~~ (12268–12340) |
|---|---|---|---|
| Room ③ mid-point (11408) | 11888 / 11960 | 68 of 72px / **fully** | **380px / 308px off screen** |
| Room ③ east end (11728) | 12208 / 12280 | **fully**, 316px margin | **60px off screen** |

⇒ **x384 — this doc's own first proposal — is off screen from inside the room, and off screen even standing
against the east wall.** The map doc's approximate 「x380~400」 cannot be taken literally; **x370 is the
measured version of that row, not a second one.**

**And the room is wider than half a screen** (20 tiles = 640px vs 480). From its west end nothing east of the
wall is ever visible, whatever the seat. ⇒ **"you can see it from the room" means from the room's east half**,
and running *away* from it (lead −72) hides it. Both are correct behaviour, not a defect — but neither is
what the first draft claimed.

---

## What happens when you stand at it

```
rooster dies ─▶ east wall down, arch appears ─▶ stand at it ─▶ settlement screen ─▶ [ 마을로 ] ─▶ town
```

### The fork: reuse the settlement screen, or a second screen for clearing

| | **A — reuse** (recommended) | **B — a clear screen of its own** |
|---|---|---|
| What opens | The same panel death opens | A second full-screen panel |
| Cost | The gate is one more term in one condition | A second window, its own layout, its own count-up |
| Risk | A clear and a death read identically until someone gives them a difference | Two screens drift; the 원석 count-up is written twice |

**Recommendation: A, and it is already decided elsewhere** —
[../plans/3.done/run-end-settlement.md](../plans/3.done/run-end-settlement.md) states it in its own words
("Clearing uses the same screen… **not making a second screen for it is** [this doc's job]") and notes that
**only the death path can reach it today.** This gate is what makes the other path exist.

⇒ **Do not restate what that screen shows.** Play time, 준 피해, the 원석 count-up, the button and every bound
on them are counted there, once.

### **The gate joins that screen's derivation. It does not open it**

~~"The screen needs two doors, not a widened condition."~~ **Void — that was written against a screen that
does not work the way this doc assumed**, and it would have introduced the exact bug that plan names as its
own worst one.

That plan's Stage D wiring is **derived, not pushed**: `want := _char.downed and not _in_town`, opened on the
rising edge and **closed whenever `want` is false**. Its Risk 3 says why in one line: the panel takes
`mouse_filter = STOP` over the whole viewport, so **a panel stranded open leaves the entire game unclickable
with no error raised** — and it forbids replacing the derivation with a latch by name. **A second door the
gate pushes *is* a latch.**

⇒ **The gate adds a term to `want`:**

```
want := (_char.downed or (boss_died(KIND_ROOSTER) and standing_at_gate)) and not _in_town
```

**The new term collapses by itself, which is the whole reason this is safe.** The button runs
`enter_town()` → `reset_stage()` → `_world.reset()` → `Progress.reset()`, whose `_reward_pending.clear()`
(`progress.gd:285`) makes `boss_died()` false again — the same self-collapse `_char.place()` restoring hp
already gives `downed`. **Neither term can strand the panel open.**

**And it hands back the "exactly once" property for free.** Standing on the seat for two hundred frames is one
rising edge. A pushed door would have had to defend against that by hand.

### Standing, not a keypress

**No `E`.** The moment this happens is the water escape, with the player climbing. **A prompt that must be
pressed while swimming is a way to fail a run you have already won.** The town spends a keypress because
*leaving* town is a decision; ending a run you won is not.

⇒ **The town gate is pressed; the stage gate is walked into.** If that reads as inconsistent on screen the
fallback is a prompt — **and it is not the one line the first draft claimed**, since the town's prompt comes
welded to `Fixtures.NAMES` and `town_view` (above).

### Sound — there is none, anywhere

`docs/design/game-feel.md` records **no sound in the repo at all**. The gate does not get the first one. The
settlement's count-up tick (**「띠리리링」**) is that doc's.

### Returning to town

`stage.enter_town()` already exists and is already the whole return path. **The settlement's button calls it;
the gate does not.** Two callers of `enter_town()` is fine; two ways to *skip* the settlement is not.

---

## The east wall comes down on the rooster's death — **decided here**

**It could not be deferred**: the wall is stone across all twelve rows, and with it standing the only route
east is out of the room's west gap, over the roof, and off a **13-tile (416px) one-way drop** at x369 that
nobody would find and nobody could climb back from. ⇒ **A cleared run would have no path to its own ending.**

**What made it decidable is that the conflict this doc first reported does not exist.**
~~"The wall that pours the water cannot be the wall that opens."~~ **Void**:
[../plans/3.done/water-jump-and-escape.md](../plans/3.done/water-jump-and-escape.md) shipped pour
**approach A — rain across the full width from above** — and states in its own Out-of-scope table that
**"wall collapse is a picture, not a water path."** Room ③'s water does not come from a wall.
(That doc's TBD line still saying "water also comes from the side wall" is a stale leftover of the old
approach, and it is what the first draft of this doc was reading.)

⇒ **One event, two consequences, one flag**: the rooster dies → the east wall (x367–368, rows 13–24) is
removed and the arch appears. Whether the removal is one rectangle or a run of the destruction command the
bull's charge already uses is **the plan's call**, not this doc's.

---

## Screen

- **The arch is visible from the room's east half the moment the rooster dies** — with the wall gone it is the
  answer to "where now", and the player is about to be rained on. The numbers that make this true are the
  camera table above; **move the seat east and this bullet is false**
- **It stands on the floor, taller than the player**, the same relation the town's gate already holds
- **Nothing is drawn before the rooster dies.** The arch appearing *is* "the fight is over"
- **Water reaches it.** Floor row 25 runs continuous from the room to the map edge, so the pour pools around
  it. **Standing is position-only, so water does not lock the gate** — recommended, and it answers half of
  `water-jump-and-escape.md`'s open "how do the gate and water meet" from this side. The other half (is it
  high enough to need a jump) stays open there
- **No 「스테이지 2」 label.** There is no stage 2; naming one on screen is the lie the doc headers exist to stop

---

## Acceptance

**The settlement screen does not exist yet** (see Boundary). Checks 1·2·5·6 are written against it and cannot
be run before it lands.

### Headless — these are values

1. **Before the rooster dies, standing there does nothing.** Place the character exactly on the seat, step the
   world, and no run-end state exists
2. **After the rooster dies, standing there ends the run once.** Two hundred frames on the seat is one
   opening — and the derivation above is what gives that, so a build that needs a guard for it took a pushed
   door somewhere
3. **The seat is standing ground** — the gate's tile has solid floor beneath it and a clear character box
   above. **A new check, not a copy**: `net_town` measures fixture seats for x range and overlap only
   (`:151-167`); the floor-and-box shape is its *spawn* check (`:126-148`), and it reads `SPAWN_TILE`
4. **A player above or below the seat is not "at the gate"** — drop through the column, jump over it: nothing
   fires. **This is the check the x-only reuse would fail**
5. **Tunnelling east before the fight does not end the run** — carve x367–368 with blasts, walk to the seat,
   nothing happens
6. **A death still opens the settlement by its own term** — adding the clear term did not disturb `downed`
7. **The town has no stage gate**, and going down in the town still opens nothing
8. **The east wall is gone after the rooster dies**, and the ground from the room to the seat is walkable end
   to end with no drop — the check that would have caught the 416px one-way fall

### Screen — only eyes can close these

9. **The arch is on screen when the rooster dies**, standing in the room's east half
10. **It reads as walk-through**, not as scenery — the town's gate had to be drawn at 2x for this reason
11. **Standing on it is unambiguous** — nobody waits there wondering what to press
12. **The water and the gate do not fight** — the escape ends at the gate rather than the gate being a second
    thing to survive

---

## Boundary — what this doc is not

| | |
|---|---|
| **The settlement screen** | [../plans/3.done/run-end-settlement.md](../plans/3.done/run-end-settlement.md) — **built since** (`3.done`, screen unverified). ⇒ **The precondition this doc was waiting on is met**: the panel it would open into exists, and only the death path reaches it. `planning-review-order`'s "small" is the size of *this* piece, not of the pair |
| **Room ③'s water** | [../plans/3.done/water-jump-and-escape.md](../plans/3.done/water-jump-and-escape.md). No pour is wired to the rooster today |
| **Redrawing the map** | `stage1-map-layout.md`. The band and the wall are read from the bake, not asked for |
| **Stage 2, and the shop between stages** | Zero code. **The gate is where the shop will sit** — a pointer, not a plan |
| **Saving** | 원석 outliving the process has no doc and no owner ([town.md](town.md) TBD). A cleared run makes the loss louder; it does not cause it |

---

## Interaction with what exists

| What | How |
|---|---|
| `Progress.boss_died(KIND_ROOSTER)` | **Already there, already generic, wired to nothing.** Drives the wall, the drawing and the standing test — one read |
| `Progress.reset()` | `_reward_pending.clear()` (`progress.gd:285`) is what makes the settlement's new term collapse on the way back to town |
| The settlement's derived `want` | The gate is a term in it, **never a second door** — that plan's Risk 3 forbids the latch |
| `Fixtures` / `TownView` | **Not extended.** Both are welded to the town's own table and to `net_town` (above) |
| `stage.enter_town()` | Unchanged |
| The stone east wall | **Destructible**, which is why acceptance 5 exists at all |

---

## TBD

- **Does the gate get its own picture**, or keep wearing the town's arch. **Deferrable**: the reused sprite is
  legible at 2x and nothing downstream depends on which image it is
- **Do death and clearing look different on the settlement screen** — that doc's own TBD. **Deferrable**: the
  gate is what makes the question answerable at all, and answering it changes only that panel's text
- **Does the gate lock behind you** — a run's last screen is a button, so "can you walk back into ③" has no
  consequence today. **Deferrable until stage 2 exists**, which is when it gets one
- **Where the shop sits relative to the gate** — before it, on it, or beyond. **Deferrable**: no shop exists
- **Whether a clear pays anything a death does not** (a bonus, a line, a first-clear pool widening — GDD "what
  is permanent is a pool"). **Untouched on purpose** — it is a reward decision, and the reward doors are
  counted elsewhere
- **What the 29 tiles east of the seat are for** — with the arch at x370 the rest of that field is runoff the
  pour will pool in. **Deferrable**: it is empty ground either way, and it is the map doc's to fill
