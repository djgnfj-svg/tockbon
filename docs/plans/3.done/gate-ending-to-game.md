# Gate (ending) — into the game

**Status**: implemented (A~D) · **screen unverified**. Design: [`../../design/gate-ending.md`](../../design/gate-ending.md).
**The milestone chain's last square is filled** — stage 1 now has an ending. See "What landed" below: sim
held under mutation, and **all five holes were on the path to the screen.** Acceptance's Screen half is untouched.
**One line**: the rooster's death drops room ③'s east wall and stands an arch at tile x370; walking into the
arch opens **the settlement screen that already exists**, with a different title line.

---

## The one thing the user has to decide (does not block the build)

**What the clear title says.** Today the panel's title is one constant, `Fx.SETTLEMENT_TITLE = "런 종료"`
(`fx_tuning.gd:1577`), drawn unconditionally (`settlement_window.gd:137-139`).

This plan **does** distinguish a clear from a death, against the design doc's own "deferrable" — see
"Where this plan overrules the design doc" below. It changes **one string and nothing else**: no extra row,
no bonus, no second panel.

- **Provisional value**: `SETTLEMENT_TITLE_CLEAR := "런 클리어"`. Build with it; the user swaps the string.
- Changing it later is one constant. Nothing downstream reads it.

Everything else in this plan is decided.

---

## What was measured, and where the design doc is wrong

The design doc was written before the settlement screen landed and before some line numbers moved. All of
the following were re-read in code, not taken from the doc.

### Confirmed (do not re-litigate)

| Claim | Measured |
|---|---|
| Room ③ interior x347–366, rows 13–24 | ✅ `terrain_map_generated.gd` MAP rows 13–20 are `##` at x345–346 and x367–368; **rows 21–24 have the west wall missing** (the "west gap") |
| East wall x367–368, rows 13–24, **stone** | ✅ all 24 tiles are `#`, never `B` |
| Ground beyond: x369–397, floor top **row 25**, rows 0–24 empty in that column | ✅ row 25 is `#` continuous from x0 to x398 (`B` at x399); rows 13–24 are `BB` at x398–399 |
| The room's floor is **the same row 25** | ✅ ⇒ once the wall is gone the walk east is **flat, no drop** |
| Seat x370, centre `(370+0.5)*32 = 11856` | ✅ tile = `TILE_CELLS(8) * CELL_PX(4)` = 32px |
| Camera: viewport 960x540 (`project.godot:23-24`), zoom `ZOOM_STEPS[0] = 1.0`, `CAM_LEAD_PX = 72.0` (`fx_tuning.gd:1191`) | ✅ the doc's visibility table stands |
| `Progress.boss_died(KIND_ROOSTER)` exists, is generic, and **nothing consumes it** | ✅ `progress.gd:223-224`; set on any boss death at `world_step.gd:224-225` |
| A fourth `Fixtures` kind turns `net_town` red | ✅ **`net_town.gd:153-160`** (every kind in `Fixtures.NAMES` needs a seat *inside the town room*) and **`net_town.gd:259-271`** (every kind needs an art row in `Fx.TOWN_FIXTURES`). The doc said `:151-157`/`:264` — the checks are real, the line numbers were 2–5 off |
| Reusing `KIND_GATE` drags the prompt in | ✅ `fixtures.gd:31` names it 출발문; `town_view.gd:96-100` draws the name **and** `[E] 출발문` over every fixture unconditionally |
| `Fixtures` is x-only | ✅ `fixtures.gd:15-18` says so in its own header |

### Wrong or stale in the design doc

1. **`progress.gd:285` for `_reward_pending.clear()`** — it is **`progress.gd:327`**, inside `reset()`.
   The *argument* holds: `reset()` clears the dict, so the new settlement term collapses on the way to town.
2. **`stage.gd:587` for room ①'s water** — that is now the middle of a comment. The code is
   **`stage.gd:611-617`** (`_take_boss_reward`), and it is behind **debug key L**, not on the bull's death.
   ⇒ **The rooster's wall is not the same shape as the bull's water.** The bull's water waits for a keypress;
   the design (correctly) wants the wall to fall on the death itself. The *idiom* to copy from that function
   is only the guard shape: `<already-done latch> and progress.boss_died(kind)`.
3. **`stage.gd:741` for the camera lead** — it is `stage.gd:813-814`. The value is unchanged.
4. **Links to `../plans/1.ready/run-end-settlement.md`** — that doc is in `3.done/` now, and every link in the
   repo has already been repointed. No action.
5. **`net_town.gd:151-167`/`:126-148`** cited for the seat and spawn checks — the seat check is
   **`:153-172`**, the floor-and-box spawn check is **`:129-150`**. Stage A copies the second one's shape.

### What the design doc could not know

**`fixtures.gd:37-47` already settled the question this plan would otherwise re-open.** `REACH_PX` is
deliberately **not** derived from the drawn sprite size ("that follows the art and changes whenever a sprite
is swapped; this is a feel value"), and `net_town` measures the *relation* — the reach must cover the widest
fixture and then some. **This plan copies that exact arrangement rather than welding the band to the art.**

**The runner turns real frames now.** `run_nets.gd:116` `pump_frames(n)` + `t.root.add_child(node)` makes
`_draw()` measurable headless (`net_frame_runner.gd` is the reference). And `run_nets.gd:98-103` fails a net
that runs **zero** checks. Both matter to Stage C.

---

## Structure — one new kind, or a variant?

**Neither.** There is no existing table this is a row in:

- **`Fixtures` cannot hold it** — a fourth kind is two nets red on the spot (measured above), and `KIND_GATE`
  reuse drags 출발문 and `[E]` onto the stage.
- **`cell_materials` cannot hold it** — the grid is destructible and material-typed; an ending is not a material.
- **There is no stage-side view that draws world-space props.** `TownView` is the town's and is hidden
  outside it (`stage.gd:881`).

⇒ **One new pure file (`src/actor/stage_gate.gd`) and one new view node.** Everything else is a line or two
added to files that already exist. **Adding a *second* stage gate later touches exactly those two files**
(a seat constant and a draw), which is the file-count contract this repo holds.

### The one read, three consumers

```
Progress.boss_died(KIND_ROOSTER)
  ├─ stage._on_ticked()      → the east wall comes down (once)
  ├─ gate_view._process()    → the arch is visible
  └─ stage._sync_settlement()→ standing at the seat ends the run
```

**Three reads of one accessor, not three flags.** The design doc's ban is on a *second flag*, not on a second
`boss_died()` call — a view reading the sim is what `src/view/` is for.

---

## Files to touch, and why — one line each

| File | Why |
|---|---|
| **`src/actor/stage_gate.gd`** *(new)* | The seat, the standing band, and the east wall's rect — plus `at(center) -> bool`. Pure, no scene, no `Fx` (see below) |
| **`src/view/gate_view.gd`** *(new)* | Draws the arch at the seat and derives its own `visible` from `boss_died` |
| **`src/stage/stage.tscn`** | One `GateView` node, so the arch has a path to the screen |
| **`src/stage/stage.gd`** | `@onready _gate_view` + `setup` in `_ready()`; the wall latch in `_on_ticked()`; the latch cleared in `reset_stage()`; the new term in `_sync_settlement()` |
| **`src/view/settlement_window.gd`** | `open()` takes a fourth argument; `_draw()` picks the title |
| **`src/view/fx_tuning.gd`** | One constant: `SETTLEMENT_TITLE_CLEAR` |
| **`tests/nets/net_gate.gd`** *(new)* | Everything below |
| **`tests/nets/net_settlement.gd`** | Two `open()` call sites (`:134`, `:157`) gain the new argument, and `_wired_root` (`:424-471`) wires `_gate_view` |

**Not touched**: `fixtures.gd`, `town_view.gd`, `town_map.gd`, `terrain_map_generated.gd`, `world_step.gd`,
`progress.gd`, `net_town.gd`, `net_render.gd`.

### Why `stage_gate.gd` lives in `src/actor/` and holds level content

`net_layers.RULES` (`net_layers.gd:26-31`) forbids `src/actor/` from referencing `src/view/` **or
`src/stage/`**. And a file in `src/stage/` that the view preloads would have to be a new `RefCounted`
alongside `town_map.gd` — a third file for two constants.

⇒ **The seat lives with the machine, not with the map**, breaking the precedent `fixtures.gd:11-13` sets for
the town. **The price is named**: a map repaint moves a constant that does not sit next to the map.
**Stage A's first check is what pays it** — it drives the real baked terrain and fails the moment the seat
stops being standing ground, exactly the accident `stage.gd:44-53` records for `SPAWN_TILE`.

---

## Stage A — `src/actor/stage_gate.gd`, pure

**No screen, no scene, no `Progress`.** Geometry and one predicate.

```
SEAT_TILE_X   = 370          # the arch's column
FLOOR_TILE_Y  = 25           # the row it stands ON (its top edge is the ground line)
REACH_PX      = 48           # x half-band, ± from the seat centre
BAND_UP_PX    = 96           # y band, upward from the ground line (3 tiles)
WALL_TILE_X0/X1 = 367 / 368  # room ③'s east wall
WALL_TILE_Y0/Y1 =  13 /  24
```

- `seat_px() -> float` → `(SEAT_TILE_X + 0.5) * 32 = 11856.0`. **The `+ 0.5` is `town_map.fixture_seats()`'s
  own idiom** (`town_map.gd:86-94`) — off by half a tile and the arch reads as reached a step early.
- `floor_y_px() -> float` → `FLOOR_TILE_Y * 32 = 800.0`.
- `at(center: Vector2) -> bool` → `absf(center.x - seat_px()) <= REACH_PX` **and**
  `center.y >= floor_y_px() - BAND_UP_PX` **and** `center.y <= floor_y_px()`.
- `wall_cells() -> Rect2i` → cells `x 2936..2951`, `y 104..199` (tile × `TILE_CELLS` 8).

**Why a y band at all, in one sentence in the file**: the x370 column is open from row 0 to row 24, so an
x-only test says "at the gate" while the player is sailing over the roof.

**Why not `on_ground` instead of a y band**: room ③'s escape is a water escape. A player floating at the gate
is not standing, and requiring `on_ground` would fail a run already won — the same reason the design refuses
a keypress. **The limit that buys**: water deeper than ~3 tiles at the seat lifts the player out of the band.
Named in Risk 6; it is `water-jump-and-escape.md`'s to answer, not this plan's.

**Why 96 and not the arch's 88px**: the same reason `fixtures.gd:37-47` gives for `REACH_PX` — the band is a
feel value, the art is not. **Stage A's net measures the relation instead** (the band must cover the drawn
arch and then some), which is `net_town`'s own proven shape.

### What the net measures here (`net_gate.gd`, Stage A)

1. **The seat is standing ground, on the real baked map.** `Stage.build_terrain_into(g)`, then: every cell of
   a `W_PX`x`H_PX` box (20x32, `character.gd:57-58`) placed at the seat is non-solid, **and** the cell
   directly under its feet is solid. Copy the *shape* of `net_town.gd:129-150`, not its values.
2. **The east wall is stone, not bedrock** — twelve rows, both columns. This is what makes "the lock is the
   flag, not the wall" a fact rather than a sentence.
3. **The ground either side of the (still-standing) wall has no drop** — row 25 solid and rows 24 clear for
   tiles **366, 369, 370** (not 367/368 — those are the wall's own columns, solid through row 24 right now
   by check 2, so asserting "clear" there would contradict check 2, not extend it; that fact is check 8's,
   *after* a real death opens the wall). **Correction (builder, measured against real check 2): this plan
   originally wrote x367..x370 here — running it against the real baked terrain turns up exactly 2 mismatched
   tiles, both wall columns. Approved by team-lead; not re-litigated.**
4. **`at()` fires at the seat and only there**: true standing on the seat; false at `seat ± (REACH_PX + 1)`;
   false at the same x with `center.y` in row 5 (over the roof); false at the town's own gate seat x.
5. **The band covers the drawn arch**: `REACH_PX >= (36 * TOWN_FIXTURE_ZOOM) / 2` and
   `BAND_UP_PX >= 44 * TOWN_FIXTURE_ZOOM`, read from `Fx.TOWN_FIXTURES[KIND_GATE]` (the net may read `Fx`;
   `stage_gate.gd` may not).

**Inversions to run**: drop the y term from `at()` → check 4's roof case goes red. Change `SEAT_TILE_X` to
384 → check 1 stays **green** (x384 is still open ground — **check 1 alone is not enough**, and check 3 does
not catch it either, its tile numbers being hardcoded rather than read from `SEAT_TILE_X`). **Correction
(team-lead, Stage C): this was not left to verify-look.** Standing at room ③'s own centre with a full
rightward camera lead is a real, computable value — `Stage.camera_center`/`Fx.CAM_LEAD_PX`, read rather than
reproduced — and the arch at 384 sits 308px outside that window while 370 sits inside it. Stage C's own
`_the_arch_is_inside_the_camera_window_only_from_the_rooms_east_half` measures exactly that, and the 384
mutation was run against it and turns it red.

---

## Stage B — the east wall comes down on the rooster's death

**In `stage.gd`, nowhere else.** Terrain is the shell's (`_room1_reward_water` is held there for exactly this
reason, `stage.gd:858-860`).

- New field beside `_room1_reward_water`: `var _room3_gate_open := false`.
- In **`_on_ticked()`**, immediately after the two `WaterSource.tick()` calls (`stage.gd:763-766`) and
  **before `_grid.consume_changed()`** (`stage.gd:787`) — otherwise the renderer sees the hole one tick late:

  ```
  if not _room3_gate_open and _world.progress().boss_died(MonsterDefs.KIND_ROOSTER):
      _room3_gate_open = true
      var r := StageGate.wall_cells()
      _grid.apply(CellGrid.cmd_fill(r.position.x, r.position.y, r.end.x, r.end.y, Mat.EMPTY))
  ```

- In **`reset_stage()`**, on the line under `_room1_reward_water = null` (`stage.gd:860`):
  `_room3_gate_open = false`.

**One rectangle, not a run of carve commands.** `cmd_fill` (`cell_grid.gd:757`, `_fill_rect` at `:866`) goes
through `_write_cell`, which is what counts `_changed` and wakes the neighbouring chunks — the same door the
map builder uses. A loop of `cmd_carve` would be 24 discs to erase a rectangle and would leave rounded
corners in stone.

**Why a latch is safe here and forbidden on the panel.** The panel's latch ban (`run-end-settlement.md`
Risk 3) is about `mouse_filter = STOP` stranding the whole game unclickable. A terrain latch strands nothing:
its only writer is `reset_stage()`, which **always** rebuilds the terrain in the same call (`_build_room()`
at `stage.gd:861`), so the flag and the wall cannot disagree. Stage B's net measures that R restores both.

### What the net measures (`net_gate.gd`, Stage B) — through a **real** rooster death

`_wired_root()` (copy `net_settlement.gd:424-471`), then `root.call("_leave_town")`:

6. **The wall is solid before anything dies** (premise, driven — not assumed).
7. **Spawn a real rooster and kill it through the death loop**: `_world.spawn_monster(KIND_ROOSTER, …)`
   (`world_step.gd:450`), `_world.monster_at(0).hp = 0` (`:477`), then pump `_physics_process` until a tick
   runs (`TICK_DIVIDER` 3 ⇒ ~6 frames). Assert `boss_died(KIND_ROOSTER)` **and** every cell of
   `wall_cells()` is non-solid. **This is the check that proves the real path, not a hand-set flag.**
8. **The walk out is flat** — after the drop, for every tile x366..x370: row 24 clear, row 25 solid.
9. **R puts the wall back and the latch with it**: `root.call("reset_stage")` → wall solid again and
   `_room3_gate_open` false.
10. **It fires once, not every tick.** After the drop, put one wall cell back by hand
    (`_grid.apply(CellGrid.cmd_fill(<one cell>, Mat.STONE))`) and pump 60 more frames: **that cell is still
    stone.** A block without the latch would erase it again on the next tick. *(Final state alone cannot see
    a per-tick refill — the hand-placed cell is what turns it into a process measurement.)*

**Inversion**: delete the `not _room3_gate_open` guard → check 10 goes red. Delete the whole block → 7 red.
Move the block after `consume_changed()` → nothing goes red (it is a one-frame render delay); **say so in the
comment rather than claiming the net pins the ordering.**

---

## Stage C — the arch on screen

**`src/view/gate_view.gd`**, a `Node2D` under the stage root, seated in `stage.tscn`.

- `setup(progress)` — called once from `stage._ready()`, next to `_town_view.setup(_char)` (`stage.gd:380`).
- `_process()` — `visible = _progress != null and _progress.boss_died(MonsterDefs.KIND_ROOSTER)`;
  `if visible: queue_redraw()` (the discipline `three_pick_window`/`settlement_window.gd:23-29` record).
- `_draw()` — one `draw_texture_rect(tex, rect(), false)`, where
  `rect() = Rect2(seat_px() - w/2, floor_y_px() - h, w, h)` with `w/h` from
  `Fx.TOWN_FIXTURES[Fixtures.KIND_GATE]` × `TOWN_FIXTURE_ZOOM` ⇒ **72x88 at (11820, 712)**.
  `false` for `tile`, as `town_view.gd:93` already does — an integer upscale, not a stretch.

**The picture is the town's arch, read from the town's own table.** One png, one size, one place. `net_town`
already measures that the file loads and that the table matches the png (`:259-271`), so this reuse costs
**zero new constants** and cannot drift. The day it gets its own picture (design TBD), one row is added.

**Why in town it is not drawn, and why that is not an argument left hanging.** `enter_town()` →
`reset_stage()` → `_world.reset()` → `Progress.reset()` → `_reward_pending.clear()` (`progress.gd:327`), so
`boss_died` is false in the town by construction. **The plan does not rest on that sentence** — check 13
drives it.

### What the net measures (`net_gate.gd`, Stage C)

11. **Invisible before the kill, visible after** — same wired root as Stage B, calling
    `gate_view.call("_process", 0.0)` by hand (untreed roots do not tick). **`visible`, not a helper**
    — the settlement screen sat behind 5,576 green checks with `visible` never set.
12. **The drawn rect is where the arch belongs**: `rect() == Rect2(11820, 712, 72, 88)`, and its bottom edge
    equals `floor_y_px()` exactly (no floating, no sinking).
13. **In the town it is invisible** — `root.call("enter_town")`, `_process`, `visible == false`.
14. **`_draw()` actually runs** — `t.root.add_child(view)`, `await t.pump_frames(2)`, and a draw counter
    moves (`net_frame_runner.gd`'s technique). `remove_child` + `queue_free` afterwards.

**Inversion**: never assign `visible` → 11 and 13 red. Drop the `- h` from the rect → 12 red. Leave
`queue_redraw()` out → 14 red.

---

## Stage D — the ending

**One term in `_sync_settlement()` (`stage.gd:744-755`), never a second door.**

```
var at_gate := _world.progress().boss_died(MonsterDefs.KIND_ROOSTER) and StageGate.at(_char.center())
var want    := (_char.downed or at_gate) and not _in_town
if want and not _settlement.is_showing():
    _settlement.open(pr.run_seconds(), pr.damage_dealt, pr.gems_this_run(), at_gate and not _char.downed)
    …
elif not want and _settlement.is_showing():
    _settlement.close()
```

**This works on today's code — checked, not assumed.** Both new terms collapse on their own:

- The button runs `enter_town()` (`stage.gd:386` connects it, `:975-978`) → `reset_stage()` → `_world.reset()`
  → `Progress.reset()` → `_reward_pending.clear()` (`progress.gd:327`) ⇒ `boss_died` false.
- The same call reaches `_build_room()` → `_char.place(SPAWN_TILE)` (`stage.gd:896-899`) ⇒ the character is
  at tile (3,19), 11,760px from the seat ⇒ `at()` false.

**Two independent collapses, either one sufficient.** Nothing can strand the panel open.

**The tie rule, decided: a death wins.** If the player is downed *and* on the seat, the fourth argument is
`false` and the death title shows. A downed body did not walk through the arch.

**"Exactly once" is free.** Two hundred frames on the seat is one rising edge, because `is_showing()` is the
edge detector. A build that needed a guard for this took a pushed door somewhere.

### The panel gains one string

- `fx_tuning.gd`: `SETTLEMENT_TITLE_CLEAR := "런 클리어"` beside `SETTLEMENT_TITLE` (`:1577`).
- `settlement_window.gd:65` `open(seconds, damage, gems, cleared: bool)` — **no default value.** The repo's
  own rule (`cell_grid.gd:771`, `character.gd:331-334`): a call site that forgets a load-bearing argument
  must not silently pick a behaviour. Missing → a clear that reads as a death, which is the exact fake.
- `settlement_window.gd:137-139` picks the title from the stored bool. Nothing else in `_draw()` changes.
- `net_settlement.gd:134` and `:157` gain the argument.

### What the net measures (`net_gate.gd`, Stage D)

15. **Before the rooster dies, standing on the seat does nothing.** Place the character exactly on the seat
    (`_char.place(11846, 768)` — `seat_px() - W_PX/2`, `floor_y_px() - H_PX`), pump 10 frames, panel closed.
    **This is also acceptance 5** (tunnelling east early): no flag, no ending, wall or no wall.
16. **After the rooster dies, standing on the seat ends the run** — kill it as in check 7, place on the seat,
    pump: `is_showing()` **and** `visible` true, and `_cleared` is true.
17. **Exactly one opening over 200 frames** — measured as a *process*: `_frames` (the window's own count-up
    clock, reset by `open()`) equals the number of frames pumped since it opened. A re-open resets it to 0,
    so this catches the thing final state cannot.
18. **A player above the seat does not end the run** — same flag, character placed at row 5 in the x370
    column, pump: closed. **This is the check the x-only reuse would fail.**
19. **A death still opens it, and reads as a death** — take `MAX_HP` in the stage, panel open, `_cleared`
    false. The existing `net_settlement` checks stay green untouched.
20. **The town opens nothing** — flag impossible in town; go down there and nothing opens (already covered by
    `net_settlement:249-262`; **do not duplicate it here**, point at it).
21. **The button closes it and returns to town** — `root.call("enter_town")` while the gate panel is open:
    panel closed, `_in_town` true, `boss_died` false. **This is the anti-strand check.**

**Inversions**: delete the `boss_died` term → 15 red. Delete `StageGate.at(...)` → 15 red (the player spawns
nowhere near the seat but the flag alone would fire). Latch `want` instead of deriving it → 21 red. Pass
`true` unconditionally as the fourth argument → 19 red.

---

## Order, and what each stage can be seen by

| Stage | Depends on | Headless can see | Only the screen can see |
|---|---|---|---|
| **A** `stage_gate.gd` | nothing | the seat is standing ground; `at()`'s bands; the wall is stone | — |
| **B** the wall drops | A (`wall_cells()`) | a real rooster death empties the wall; R restores it; the walk is flat | the hole reading as a doorway |
| **C** the arch | A (`seat_px`) | `visible` flips with the flag and not in town; the rect; `_draw()` runs | **is it on screen from the room's east half**; does it read as walk-through |
| **D** the ending | A, and C only for the eye | opens once, on the seat, after the flag, not before, not in town; the title flag | the panel arriving without the player wondering what to press |

**B before D** is not strictly required (a player can reach the seat over the roof and off a 13-tile drop),
but a cleared run with no walkable path to its own ending is the failure the design named. Build in order.

### Verify-look's problem, named up front

~~**No rooster is placed on the map.**~~ **Void — `3.done/monster-placement-stage1.md` landed** and the
rooster is a row in its table (room ③). ⇒ **On screen: leave town and walk east.** No debug key. It has
**250 hp** (`monster_defs.gd:83-88`), so bring something. Debug key **C** (`stage_input.gd:91`) still stands
one up if you want it sooner.
**No new debug key is added for this.** A "force clear" key would make the ending observable only through a
door the player never touches, and this repo's own `_take_boss_reward` (L) is already one such door too many.

---

## Risk

1. **The panel stranded open** — the worst failure in this feature (`mouse_filter = STOP` over the whole
   viewport, no error raised, the whole game unclickable). Closed by construction: `want` stays derived, and
   both new terms self-collapse. Check 21 drives it.
2. **`_gate_view` null inside `stage._ready()`** — `net_settlement.gd:332-348` is the one net that calls
   `_ready()` on an untreed root. It must set `_gate_view` and add `"GateView"` to the path list at `:443-446`.
   Forgotten, the failure is a runtime error mid-`run()` and **checks disappear rather than fail**
   (`run_nets.gd:90-103` is the only thing that catches that shape).
3. **Screen moves, sim does not (or the reverse)** — the repo's signature fake, and here it would be an arch
   drawn where the standing test is not. Both read `StageGate`; check 5 pins the relation and check 12 pins
   the rect.
4. **A fourth `Fixtures` kind** — two `net_town` checks red immediately. Do not touch `fixtures.gd`.
5. **The wall latch diverging from the flag** — only `reset_stage()` writes it, and it always rebuilds the
   terrain in the same call. Check 9.
6. **Water deeper than ~3 tiles at the seat lifts the player out of the y band** — the run then cannot end.
   Not solved here; room ③'s pour is `2.active/water-jump-and-escape.md`'s. **Recorded there when this lands.**
7. **`open()`'s signature change** — deliberate and unforgiving (no default). Two call sites in
   `net_settlement.gd`; nothing else calls it.
8. **`t.ok(true, …)` and file-grepping checks are banned here.** Every check above drives a value. In
   particular, do **not** measure "the arch is drawn" by grepping `gate_view.gd` for `draw_texture_rect` —
   five such scans were evaded in one feature.

---

## What landed — and **every hole was on the way to the screen**

A~D are all in. `src/actor/stage_gate.gd` (seat tile **x370**, x band 48, y band 96 — three tiles above the
floor line, `at(center) -> bool`); the east wall (x367–368, rows 13–24) comes down on the rooster's death via
`stage.gd`'s `_room3_gate_open` latch and **one** `cmd_fill(EMPTY)` rectangle, released by `reset_stage()`;
`src/view/gate_view.gd` + its `stage.tscn` node, `visible` derived, drawing the town door sprite (**zero new
constants**); and `_sync_settlement()`'s `at_gate` term, which **reuses the settlement panel** and swaps only
the title. **A tie goes to death** — downed while standing on the seat is a death, not a clear.

**30 nets, 6191 checks, 0 failures.** The new one is `net_gate.gd` (328 checks).

### What verification found

**The sim side held.** All 12 mutations bit, including the two process measurements — the wall not re-running
every tick, and the panel opening exactly once across 200 frames.

**All five holes were between the code and the screen:**

1. **Delete `stage.gd`'s `_gate_view.setup()` line and everything stayed green** — the arch would never
   appear and nothing errors. The net's `_wired_root` **wired it directly and so masked the real line**
2. **Turn `draw_texture_rect` into `pass` and everything stayed green** — the counter climbs even when
   `super()` draws nothing. **"`_draw()` ran" is not "something was drawn"**
3. **Delete the title ternary and everything stayed green** — a clear printed 런 종료. This is Stage D's
   **only user-visible output**, and the checks followed `_cleared` as far as the bool and stopped
4. The wall check was **self-referential through `wall_cells()`** — shrink the rectangle and the check's own
   range shrank with it
5. The derived-close branch sits outside the nets — **but it is unreachable in today's build**: once the panel
   is up `_world.frame()` stops, so the condition is frozen. The real guarantee against being stranded is
   `reset_stage()`'s explicit `close()`

**1–4 are fixed.** Godot **rejects an override of a native draw call as a parse error**, so 2 and 3 were
closed by carving out `_paint(...)` and `_draw_title(...)` hooks and overriding those to capture the
arguments. **5 was fixed as a comment correction, not a deletion** — the branch comes back to life the day
that condition can change while frozen.

**One thing worth remembering.** With the `cleared` argument removed, the nets reported **passed 267 ·
failed 0** — **38 checks vanished rather than failed.** `_wired_root`'s `if root == null: return` shape is
structurally a disappearing check (`run_nets.gd:90-103` is the only thing that catches that shape at all).

## Acceptance

**Headless** — checks 1–21 above, run through `tests/run_nets.ps1`, with the inversions named per stage
actually run and shown to bite. **Done: 6191 passed, 0 failed.**

**Screen** (verify-look, the design doc's own 9–12) — **none of this has been looked at:**

- The arch is on screen the moment the rooster dies, standing in the room's **east half**
- It reads as walk-through, not as scenery
- Standing on it is unambiguous — nobody waits there wondering what to press
- The settlement panel says **클리어**, not the death line, and the button returns to town

**What to carry in when the screen finally opens** — three known facts, none of them judged:

- **The arch is only on screen from room ③'s east half.** The room is 640px and half the screen is 480px, and
  the camera lead (−72) points away from it when you run west. **Both are correct behaviour and the nets
  assert the negative case** — whether it still reads as *the ending is over there* is the open question
- **런 클리어 is the provisional string** ("The one thing the user has to decide", above). The user changes
  one constant; nothing downstream reads it
- **Does the wall coming down read as an event.** Today one rectangle is emptied, silently

---

## Out of scope

| | |
|---|---|
| **Room ③'s water** | `2.active/water-jump-and-escape.md`. Nothing here starts a pour |
| **Placing the rooster on the map** | `3.done/monster-placement-stage1.md` — **built since; it is a row in that table now** |
| **A gate sprite of its own** | Design TBD. The town's arch is reused, from the town's own table |
| **A clear paying more than a death** | A reward decision, counted elsewhere. **The title changes; nothing else does** |
| **Does the gate lock behind you** | No consequence until stage 2 exists |
| **The shop, stage 2, saving** | Zero code, no owner |
| **A second settlement screen** | Refused by `decisions/run-end-is-settlement-only.md` |

---

## Where this plan overrules the design doc

**The design doc calls "do death and clearing look different" deferrable. This plan does the title now.**

Grounds: the design's own fork table names the risk of option A as *"a clear and a death read identically
until someone gives them a difference"* — and the gate is the change that first makes both paths reachable.
Shipping the ending with the death panel unchanged means the one screen the whole feature exists to produce
says **런 종료** after a win. The cost of not deferring is **one constant, one argument, one branch**; the
cost of deferring is that verify-look has nothing to tell a clear from a death by, on the very build where
the difference first exists.

**Bounded on purpose**: the title, and nothing else. No extra row, no bonus, no second layout.

---

## Correction log — what this plan claimed and got wrong

**Two claims were written into this plan and caught during the build. Both are corrected in place above; both
are recorded here because a plan that quietly fixes itself teaches nothing.**

| Claimed | Actually |
|---|---|
| Stage A check 3 tests row 24 clear for tiles x367..x370 | **False** — x367/368 are the wall's own columns (check 2's own claim: stone through row 24). Run as written, exactly 2 tiles (367, 368) turn up mismatched. The check now runs 366/369/370 instead — the ground either side of the wall, not the wall's own footprint |
| Moving `SEAT_TILE_X` to 384 is caught by check 1 (standing-ground) | **False** — x384 is standing ground too; check 1 stayed green when this was actually run. Left as "verify-look's job" until Stage C's own camera-window check (`_the_arch_is_inside_the_camera_window_only_from_the_rooms_east_half`) made it a measured value instead — 384 sits 308px outside the window a 370 seat sits inside |
