# The town — one bedrock room, three fixtures, and a door that checks where you are standing

**Status**: done — **the skeleton is finished and the run loop closes.** You start in the town, walk to the
departure gate, press E, and stage 1 builds around you; die there, press E, and you are back in the town.
**"Done" means implementation, not acceptance** (CLAUDE.md).

**Accepted**: **not by the user.** Walked end to end on screen through the editor bridge — the prompt
appears at each bench, the research window opens with its panel and icons, the gate builds stage 1 and puts
the character on its spawn tile.

**Where the design lives**: [../../design/town.md](../../design/town.md).

---

## Why now

`town.md` opened with the hole: the GDD's session loop is **town → stage 1 → die or clear → town**, and
**there was no town** — so a run had nowhere to end, and R (rebuild the same stage) was the only exit.

## What was built — four pieces, and only one of them is new machinery

| Piece | What it is |
|---|---|
| `src/actor/fixtures.gd` | **The one new machine.** Three kinds, a reach, and `at(seats, center_x) -> kind`. |
| `src/stage/town_map.gd` | The room. Four numbers (`ROOM_X0/X1/Y0/Y1`) generate the map rows; three tiles hold the fixture seats |
| `src/view/town_view.gd` | The three sprites, a name over each, a prompt on the one being stood at |
| `src/view/research_window.gd` · `research_layout.gd` | The bench's window — panel, slot frames, icons, the 원석 count |
| `stage.gd` | `_in_town`, `_build_room()`, `_interact()`, and the two doors |

### Nothing in this repo had ever asked "where is the player standing"

Every window opens from anywhere (Tab, P). That is the whole of `fixtures.gd`, and it is deliberately small.

**It lives in `src/actor/`, not the shell**, so the question is a pure function over a table — a net feeds in
seats and an x and reads back an index, with no scene. **The seat table stays in the shell** (`town_map`),
because it is level content and moves whenever the room is redrawn.

**x only, no y.** One flat room, so a vertical test would always be true. The day the town gets a second
storey, that is the line that changes — and it will show up as "the upstairs bench opens from downstairs",
not as a crash.

### The room reuses the stage, it is not a second scene

`build_terrain_into` was split into `build_map_into(g, map, chars)`; the town passes its own rows. The stage's
own door is kept under its old name because `net_tables` and `net_water_rain` call it to stand up *the real
stage 1*, and a net that had to pass a map in is a net that could be handed the wrong one.

**Same tile dimensions as the stage map, on purpose.** The camera clamps to the grid, not the map
(`stage.world_size`), so a smaller town would leave the player able to walk off the drawn area. Filling the
rest with bedrock costs 48 commands — a solid row bundles into one `cmd_fill`.

**Every cell is bedrock, and the character table has exactly one entry.** That is `town.md`'s "the town does
not get dug up" made *unwritable* rather than merely undone — there is no `=` to paint, so nothing burnable
can be added by accident. Casting in town is not blocked; nothing changes shape.

### What each fixture actually does

| Fixture | Today |
|---|---|
| **Departure gate** | **Real.** Builds stage 1 and puts you on its spawn tile |
| **Assembly bench** | **The same window Tab opens** — which is what `town.md` says it is. What the town *adds* (choosing what to equip within a point budget) needs a point table that does not exist |
| **Research bench** | **A window**: the 원석 count, the four unlock axes with their icons, and the rune pool as the item row — read live from `Progress`. **It spends nothing and says so** |

**The research bench is not a placeholder.** That list is the design's own core requirement — "unlocked and
locked sitting in one list is the best possible demonstration that the pool widened". What it does *not* have
is a buy button, because **there is no price table** (`town.md`'s own TBD, and the old "three per unlock"
arithmetic was voided by the 원석 yield landing 5x higher than it was written against).
**A button that took a 원석 and gave nothing back would be the fake**; an honest empty shelf is not.

### Death closes the run

The health readout used to say `쓰러짐 — R로 다시`. It says `쓰러짐 — E로 마을에 돌아간다` now. R still
rebuilds the room and is still the debug instrument it always was; what changed is which one the *player* is
told about. **E does nothing in the stage while you are standing** — otherwise it is a free escape from a fight.

---

## One thing was found by looking, not by measuring

**`Fixtures.REACH_PX` went 40 → 48.** Walking to the gate on screen, the prompt failed to appear while the
character was **visibly standing on the block** — measured at 41px from the seat, against a 48px-wide block
whose own edge is 24px out. A player reads that as the key being broken.

`net_town` measures the relation directly — the reach must clear every fixture's own drawn half-width — so
the band cannot come back. **The two constants are not derived from each other**: the drawn size follows the
art and the standing spot is a feel value, and tying one to the other would silently resize the standing spot
every time a sprite is swapped.

## The art, applied second — and one of the two was invisible

**The first pass drew coloured blocks in a black room, and every asset it needed was already in the repo.**
Three fixture sprites in `assets/town/`, two backdrops in `assets/stage/`, a panel and five icons in
`assets/ui/` — none of them referenced by any code.

| Asset | What it took |
|---|---|
| `assets/town/*` (3) | A size table in `fx_tuning`, drawn at **2x** (at 1:1 a 36px bench barely clears the 32px player) |
| `assets/stage/bg_town.png` · `bg_near_town.png` | **One call.** `sky_background.set_backdrop()` was written for this and had never been called by anything |
| `assets/ui/*` (7) | The research window — a 9-slice panel, slot frames cut from one row image, five tinted icons |

### The backdrop was swapped in and the town was still black

`sky_background` clamps the far picture at `BG_UNDER_TOP_Y` and fills everything below with the underground
bands. **The town room was cut twelve tiles lower than that line**, so both town pictures were drawn and then
covered by rock-coloured bands. The art loaded, the constants were right, `set_backdrop` ran, and the screen
was black with **nothing barking anywhere.** ⇒ The room moved up so its floor *is* the ground line, and
`net_town` now measures that relation rather than the coordinate.

**This is CLAUDE.md's "is there a path for the thing you want to see to reach the screen" in its purest form,
and it is the third time this repo has hit it** (water's cells, the monster sheets, this).

### The panel wore a white box

`research_panel.png` shipped on an opaque white background and had never been keyed.
`tools/pixel/cut_white_bg.py` floods in from the border and cuts neutral-bright pixels with a feathered edge.
**It is a separate tool from `cutbg.py` on purpose** — that one cuts chroma green and its header records why
a flood fill is wrong *for monsters* (a white chicken on a white ground got walked straight through). A UI
panel whose interior is warm parchment is the case where a fill is safe, and the tool says so.

### 원석, both doors

`docs/decisions/gems-from-bosses-and-levels.md` landed while this was being built and **the first
implementation contradicted it** — one flat material per boss, no level door. Now: `Progress.gems`,
`add_boss_gems()` rolling 3~4 inside `Progress` (which owns the RNG stream, so no call site can drift from
the decision), and `+1` inside the level-up loop beside `pending_picks`. **`reset()` does not clear it**, and
that absence is the whole town.

## What the nets measure

`net_town`, 254 checks, in four parts that are deliberately not the same thing:

1. **The room** — hollow, all bedrock (by *material*, not `is_solid`: a stone town would pass a solidity check
   and then be blasted open), wide enough to be worth walking, and **the character's whole box fits at the
   spawn tile with floor directly under it.** That last one is the check that would have caught
   `stage.SPAWN_TILE`'s own recorded accident — the map was repainted, the spawn stayed, and the character
   started sealed inside rock with nothing barking
2. **The door** — driven with made-up seats, so a moved bench cannot turn an arithmetic check red
3. **The art** — every path loads, the table's sizes are the pngs' own sizes, the zoom is an integer, the
   slot cuts are inside the sheet and do not overlap, the panel's nine slices tile the window exactly with
   the corners unscaled, both text baselines sit inside their row, **and the room's floor is above the
   background's ground line** (the check for the black-town bug)
4. **The wiring** — E at the gate really leaves, E between benches does nothing, E at the research bench
   opens and closes the window, being downed brings you back, **the terrain really changed** (the flag
   flipping without the room following would be the flag lying), and the window closes with the room

**Inversion**: nineteen mutations, all red, one no-op control green.
*The room and the door*: starting outside the town · the gate not leaving · downed not returning · always
building the stage map · the message not cleared · everything in reach · first-wins instead of nearest-wins ·
the spawn moved into the wall · the town built of stone · two benches on top of each other.
*The art*: a fixture path broken · a table size that is not the png's · a non-integer zoom · fixtures shorter
than the player · the town backdrop never called for · the town backdrop pointed at the farm's · a corner
slice stretched · rows overlapping · a slot cut running off the sheet · an icon path broken · the item row no
longer reading the pool · E never opening the window · the window surviving a departure.
*And in `net_progress`*: `reset()` wiping 원석 · the boss door overwriting instead of adding.

## What this is not

- **The fixtures' cast shadows.** The generator baked one into each sprite and it reads as a dark blob
  beside the bench — the user's own words were to ask whether it was a cat. **Confirmed not automatable**:
  the shadow is one connected opaque component with the fixture (measured), so a component cut has nothing
  to separate and a darkness cut would eat the sprite's own linework. It needs a hand pass
- **No research spending and no point budget** — see the table above. 원석 accrues and cannot be spent
- **The run-end settlement screen** (`../1.ready/run-end-settlement.md`) — today `E` while downed goes
  straight to the town and the run's 원석 is banked in silence. That plan replaces this door
- **No difference between dying and clearing** — `town.md`'s own TBD, and clearing does not exist yet
- **E is a raw keycode, not an input-map action.** Interaction survives into the real game and by that rule
  belongs in `project.godot`; adding an action there needs an editor restart and the town is a skeleton being
  stood up. **Move it the day the town stops being one**
