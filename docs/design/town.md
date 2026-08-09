# Town — where a run closes

**One line**: one walkable room. Unlock permanent progress at the **research bench**, pick what you take with you
at the **assembly bench**, and leave through the **departure gate**. Die or clear and you come back here.

**Implemented**: **partial** — **the room, the loop and the art all run** ([../plans/3.done/town-room-and-fixtures.md](../plans/3.done/town-room-and-fixtures.md)).
One bedrock room · three fixtures with their own sprites · **the position-checking door** (E) · the gate
builds stage 1 · dying sends you back · **the burnt-village backdrop** · **the research window** (panel,
slot frames, the four unlock icons) · **원석 that survives a run**, from both doors (boss 3~4, level 1).
**Not done**: the point budget · **any unlock, and therefore any way to spend 원석** · the assembly bench's
own "choose what to equip" half (it opens the existing reorder window)
**Built since, screen unverified**: the run-end settlement screen
([../plans/3.done/run-end-settlement.md](../plans/3.done/run-end-settlement.md)) — **`E` while downed no
longer goes straight to the town**; the panel opens on its own and its button is the door. Nobody has looked at it
**Accepted**: **unseen** — walked end to end by an agent in the editor, never by the user

**A concept stays alive and never changes folders.** The two header lines are only "how much runs now" —
format per [README.md](README.md).

**The GDD used to call this "home". The name was unified to "town"** — ten places in the GDD were fixed.
**Do not write "home" again.** A split name makes two docs unable to find each other.

**Why permanence is a pool and not an object is set by `docs/GDD.md`, "what is permanent is a pool, not an object".**
Do not duplicate it here.

---

## Why — the run doesn't close right now

The GDD's session loop is **town → stage 1 → die or clear → town**, and **there is no town.**
That row in `docs/design/README.md` was **Implemented: none** with no doc at all.

⇒ Walk stage 1 to the end and **there is nowhere to go, so it isn't a roguelike.**

**And there is a quieter hole — a pool is invisible.**

The GDD pins "what is permanent is a pool, not an object", and **a pool is not something you can hold.**
Beat a boss for the first time, widen the pool, and **if nothing happens on screen, it is the same as having no permanent progress.**
⇒ **The town's fixtures are the only place that becomes visible.** That is this doc's first reason for a town.

**The second reason is death.** While only stage 1 exists, clearing ends the game so there's no visible need to return —
**but death already happens.** With no town, there is nowhere to go when you die.

---

## Form — you walk. One room

**Decided by the user.** Not a menu screen.

**Why**: "I'm home" has to be felt with the body. Made as one screen it is not a town but a **menu**,
and if a roguelike's home is a menu, the space between runs is just a loading screen.

**Start with one room and widening it later makes it a town.** Draw it at town scale from the start and
NPCs, buildings and roads all follow, making it **as heavy as stage 1** — not its turn ("skeleton first").

### It reuses the stage scene — not a new engine

Same grid (4px cells) · same character · same movement · same terrain baking tool (`terrain-baking.md`).

**So the cost is not "a new system" but "one terrain + interaction".**

**But interaction genuinely doesn't exist.** "Stand in front of a fixture, press a key, a window opens" has never
existed in this repo — the window that exists (the assembly window) is **Tab from anywhere.**
⇒ **A door that checks position** is new. That is the town's only new machine.

**It exists now** — `src/actor/fixtures.gd`, a seat table and one lookup. **x only, no y**, because the room
is flat; the day a second storey arrives that is the line that changes. The reach is **48px**, widened from
40 after walking to the gate on screen and finding a band where the character stood **on** the block with no
prompt (`town-room-and-fixtures.md`).

### Can you cast in town — yes. Terrain doesn't dig

The grid is the same, so **unblocked, the town gets dug up.** And it would need repair every run.

⇒ **Casting is not blocked** (messing around in town is fun). Instead, **all town terrain is bedrock.**
**No new rule at all** — stage 1's pit ① is already a bedrock bowl and "even blasts can't breach it" already runs there
(`stage1-map-layout`).

**Fire is different.** Bedrock has zero fuel and doesn't burn, but **wood placed as decoration does.**
⇒ **Put nothing burnable in town.** To place it anyway, "repair per run" must be decided — left TBD for now.
**The map's character table has exactly one entry (`B`)**, so this is unwritable rather than merely undone.

### The room sits on the surface, and it has to

**The town's floor is `fx_tuning.BG_NEAR_GROUND_Y` exactly.** The room was first cut twelve tiles lower and
**the town rendered as a black box with the right backdrop loaded and swapped in.** `sky_background` clamps
the far picture at the ground line and fills everything below with the underground bands — a room below that
line is *underground* by the background's own definition, so both town pictures were drawn and then covered
by rock. **Nothing barked.** ⇒ Moving the room down again needs `background.md` to answer "what is behind a
town below the ground line" first.

---

## What stands there — three

| Fixture | What it does |
|---|---|
| **Research bench** | Spends materials on permanent unlocks. **Unlocked and locked appear in one list together** |
| **Assembly bench** | **Build within a point budget and take it with you** — **this is the heart of the town** |
| **Departure gate** | Enters stage 1 |

**There is no separate compendium — the research bench doubles as one.**
**Unlocked and locked sitting in one list** is the best possible demonstration of "the pool widened".
A separate compendium **splits "where you look" from "where you unlock" and then neither gets looked at.**

---

## Assembly bench — building with points. **The heart of the town**

**Decided by the user.** This decision made the assembly bench the most important object in town.

```
unlocked circles · runes · glyphs are in a list
        ↓
choose within a point budget  ←─ the budget grows through research
        ↓
leave through the gate with that build
```

**The source is `docs/GDD.md`, "starting kit — chosen with points, not fixed".** Do not duplicate it here.

**At first there is no choice.** The budget covers one none-rune · one basic 2-layer circle · one spread,
so **there is effectively one option** — the same result as the old fixed kit.
**That is not a defect.** The assembly bench is **a fixture that fills as unlocks accumulate.**

**So the reason to build it now is not "it's usable now" but "so it can expand later"** (user instruction).
⇒ **The point ceiling and item values must come from a table, not numbers baked into code.**
That code doesn't change as unlocks grow is this fixture's entire requirement.

### How it differs from the in-dungeon assembly window

**It is the same window.** Same picture and same rules as the one Tab opens in the dungeon
(GDD "assembly — any time during a dungeon").

| | Dungeon assembly window | Town assembly bench |
|---|---|---|
| What you can do | **Reorder what is already equipped** | **Choose what to equip** (points) + reorder |
| The world | Doesn't stop | May stop |

**With no inventory, the dungeon side is left with reordering only** (GDD "there is no inventory") —
a glyph is **socketed into a layer the moment you receive it**, so there is nothing left to equip later.
⇒ **"What you take with you" is decided only in town.** That is the only difference between the two windows.

**So in town the window may stop the world.** The GDD pins "the world doesn't stop" because
**in multiplayer one person opening a window must not freeze everyone else**, and nothing chases you in town.
**Though in multiplayer the town is also shared** — revisit then. Single-player doesn't hit it.

---

## Research bench — two lists

**Feed materials, buy permanent unlocks. Four things to buy.**

| Slot | What you buy | When it takes effect |
|---|---|---|
| **Points** | **How much you can take with you** | Next run. **Immediately visible at the assembly bench** |
| **Items** | **Being able to choose** new circles/runes/glyphs | Next run |
| **Body** | Things like a double jump | **Always, from purchase** |
| **Dice** | **Rerolling** a three-pick instead of taking it | Next run |

### What runs today — the list, not the shop

**The window is built** (`src/view/research_window.gd`): the four slots above, each with its icon and its
state, and the material count. **The item row is the rune pool**, read live from `Progress`, so earning fire
visibly moves it — which is this bench's whole stated purpose.

**Nothing can be bought, and the window says so.** There is no price table (see the TBD list) and therefore
no button; a button that took a material and returned nothing would be worse than an honest empty shelf.
⇒ **Material accrues and cannot be spent.** That split is deliberate: the drop was already decided (the GDD's
"Drops"), the price was not.

**"Items" and "points" are a pair.** Opening items grows what there is to buy;
raising points grows the vessel — **you need both for a build to widen.**
⇒ **Two unlock axes means "what do I buy first" comes up every time.** With one, there is no ordering.

### "Item unlock" and the GDD's "pool" are the same thing

The GDD's **pool** in "what is permanent is a pool, not an object" is **what can appear in a run's three-pick**,
and "items" here is **what can be chosen and taken from town.**

⇒ **Keep them as one.** Unlock it and **you can choose it in town and it appears during runs.**
**Split them and the list becomes two, and the player doesn't know which one they bought.**

### The list is no longer empty — points and dice fill it

**There used to be exactly one thing to buy (double jump), making the research bench a one-button screen.**
**Points removed that problem** — **even with no items unlocked, points can always be bought.**

**The rune side has the opposite problem** — `sim_tuning.ELEM_ALL` already holds **fire, none and water, all free.**
⇒ **It isn't that there's nothing to buy; it's that everything is already open.** For the bench to stand, **they must be locked first.**
Glyphs really are thin — **2** (spread · blast). Circles: **1**.
**Filling the list is the job of growing glyphs and runes**, not this doc.

---

## 원석 — bosses and levels, so nine to eleven per full run

**The material has a name now: 원석**, and **two doors, not one** —
**a boss gives 3~4, a level gives 1** ([../decisions/gems-from-bosses-and-levels.md](../decisions/gems-from-bosses-and-levels.md)).
A trash-mob kill still gives nothing directly; it reaches 원석 only by way of XP and the level.

⇒ A full clear ≈ **9–11**. A death at level 2 ≈ **2** — **never 0**, which is what lets research start in a
run that ends the normal way. **This replaced the old "1–2 per run"**: with the boss door alone, the
settlement screen's count-up had two ticks to show.

**Implemented** — `Progress.gems`, both doors: `add_boss_gems()` rolls 3~4 on a boss's death, and the
level-up loop adds 1 per level crossed (so one big XP award that crosses two thresholds pays both, exactly as
`pending_picks` does). **It is the one field `Progress.reset()` does not clear**, and `net_progress` measures
that — including that the roll really spans its range rather than pinning to the minimum.
**On screen it is `원석 N` at the research bench; in code the field is `gems`.**

**That number is the pace of research.** ~~Three materials per unlock means one unlock every three runs.~~
**Void — that arithmetic was written against 1–2 per run.** At 9–11 a run, three 원석 an unlock would open
three or four unlocks per run. **The price is TBD and must be re-derived from the new yield.**
**There is one kind of material** (decided by the user). Splitting kinds would create "beat this boss to unlock that",
giving each boss its own reason to be fought, **but with two bosses that axis is still thin** — nothing to split.
Revisit as stages grow.

---

## Relationship to the shop — there is no shop in town

Money is spent **at the shop between stages** (`docs/plans/3.done/levelup-and-three-picks.md`). **That is inside the run.**

⇒ **Town spends materials; the shop spends money.** Different currencies, so they don't overlap.

**So leftover money vanishes when a run ends.** Whether that's right is **TBD** —
keeping it means **town needs somewhere to spend money, which muddies the clean split above.**
⇒ **Leave it vanishing for now.** "What's in the run ends in the run" has the same shape as the GDD's split.

---

## A run's start and end

**Start**: through the departure gate, **carrying the build chosen with points at the assembly bench.**
**It is not "the same every run"** — only the first run matches the old fixed values, and **it changes as unlocks accumulate.**

### **The starting kit is handed over here** (decided by the user)

**You receive the none rune and the basic circle in town and leave with them** — town is where the very first
socketing happens, not the dungeon. **The first departure is fixed** (GDD, "Starting kit"): there is nothing
else unlocked, so the bench has nothing to offer yet. **The bench is the same object either way** — on run one
it hands over a fixed pair, later it spends points.

**And the usage is taught by a tutorial, not by this room.** ⇒ **The town does not explain anything.**
No tooltip, no fixture whose job is to teach — **that pressure goes to the tutorial**, which has no doc yet
(`README.md`, "Features with no doc yet").

**What this settles for the milestone**: the in-run "screen for receiving a rune" (GDD's first-milestone gap)
is **the bull's fire rune only.** The *start* is not a receiving problem — **it is a town problem, and town is cut
from this week** ⇒ until town exists, **code holds the fixed pair directly** (`spell_circle.DEFAULT_RUNE`).

**End**: die or clear and **you go through the settlement screen first**, then return to town —
[../plans/3.done/run-end-settlement.md](../plans/3.done/run-end-settlement.md). It opens the instant you
go down, prints play time and damage dealt, and **counts 원석 up.** The button on it is what enters the town.
**That doc names the currency this one calls "material": 원석.**

**Whether death and clearing look different** is still **TBD** — but it is now a question about **that
screen**, not about this room. **With no difference at all, clearing loses its weight.**

---

## Art — the three fixtures exist as pictures (nothing else)

Picked by the user out of three candidates each, in `assets/town/`:

| File | Size | What it is |
|---|---|---|
| `research_bench.png` | 36x36 | A stone bench with vials and a rune tablet |
| `assembly_bench.png` | 44x32 | A wooden bench with an open spellbook |
| `departure_gate.png` | 36x44 | A stone arch with glowing runes in the pillars |

Sized against the player (32px) and padded to a multiple of `CELL_PX` 4 the same way the monsters are
(`monsters.md`, "pad, never resample"). **The gate is taller than the player** — it has to read as walk-through.

**TODO — the generator baked a cast shadow into each one.** It reads as a dark blob beside the fixture
(**the user asked whether it was a cat**). **Still open, and confirmed not automatable**: the shadow is one
connected opaque component with the fixture itself (measured — 590px, one blob, on the assembly bench), so
there is nothing for a component cut to separate, and a darkness cut would eat the sprite's own linework.
**It needs the hand pass this line already said it needs.** **No cat, and no animals or NPCs at all** —
this doc's boundary already says "a home with no people".

~~**TODO — nothing places these.**~~ **Placed.** `town_map.FIXTURE_TILES` seats them, `town_view` draws them
at **2x** — at 1:1 a 36px bench barely clears the 32px player and reads as scenery rather than as something
to walk up to. `net_town` measures that the table's sizes are the pngs' own sizes and that the zoom is an
integer (a 1.5x upscale of pixel art gives some pixels twice the size of others).

### The research window's art — **stone, not a spellbook** (decided by the user)

Both tones were generated and compared. **The user picked stone**: *"a spellbook is something you carry around"* —
⇒ **a fixture that stays in the room should not look like the thing in your hands.** The assembly window keeps
its grimoire (`circle-art.md`); **the two windows differing is the point, not a mismatch.**
Then: **"make it brighter"** — the first stone pass was a dark grey slab and the town is meant to read bright
(this doc's "Screen").

In `assets/ui/`:

| File | What it is |
|---|---|
| `research_panel.png` | Pale sandstone frame, carved border, empty center (512x512) |
| `slot_row.png` | A row of carved slots, one chained shut — **"locked" has a picture** (512x320) |
| `icon_material.png` · `icon_point.png` · `icon_item.png` · `icon_body.png` · `icon_dice.png` | The four research slots plus the material, 24px |

**The icons are pure white on transparency** (decided by the user: *"the material has to be more obvious —
a white drawing would do"*). Solid white means **the UI tints them per state instead of storing a colored
copy per state**; the dice's pips are holes punched through the silhouette, not painted dots.

~~**TBD — how big the panel is on screen.**~~ **Settled by building it**: `Fx.RESEARCH_RECT` is
**480x400**, centred. Smaller than the assembly window's 864x372 on purpose — that one is a workbench you
arrange things on, this is a list you read, and four short lines across 864px is a field of parchment.

**It does 9-slice, and it is clean.** ~~`circle-art.md` already measured that 9-slice misaligns the
corners~~ — **that cross-reference was wrong; `circle-art.md` contains no such measurement.** The panel is
cut into nine regions by `research_layout.nine()` with the four corners drawn 1:1 and never scaled;
`net_town` measures that the nine destinations tile the window exactly (area, with each corner's position
and size checked separately, because area alone cannot see a stretched corner), and it was looked at on
screen.

**The panel shipped with an opaque white background** and was drawn into the game wearing a white rectangle
around its rounded frame. `tools/pixel/cut_white_bg.py` keys it out by flooding in from the border — safe
here, and **not** safe for monsters, which is why `cutbg.py` uses chroma green instead (that file's own
header records a white chicken on a white ground being walked straight through).

## Screen

- **One room. Bright** — contrast with the dungeon is half of "I'm home"
- **What stands behind it is a broken village** (decided by the user) — daylight, but **ruined**: caved roofs,
  a snapped windmill. **A warm workshop interior was generated and rejected** — "that isn't a town".
  ⇒ "I'm home" here is **not cosiness; it is a place that survived.** Candidate picking lives in `background.md`
- **Standing at a fixture shows a "press this" prompt** — one position-checking door is needed here (see "interaction")
- Windows follow the same art discipline as the assembly window (`circle-art.md`)

**This is where the background first becomes useful.** `background.md` is currently night sky + stars, and
**if the town must be bright, that layer needs two variants.** That doc is where it gets looked at.

---

## Boundary — what this doc is not

- **Actually painting the town terrain** — that belongs in `docs/plans/`. This doc goes as far as "one room · all bedrock · three fixtures"
- **NPCs · dialogue · quests** — **none.** It is a home with no people
- **Inventory** — **none** (GDD "there is no inventory"). **The assembly bench's unlock list is not an inventory** —
  **growing during a run is an inventory; visible only in town is a list**
- **What the town becomes in multiplayer** — TBD. "The window stops the world" reopens there
- **Growing glyphs and runes** — the cause of the research bench's empty list, but not the place to fix it
- **How the research and assembly screens are actually drawn** — there is no UI at all (`README.md`: UI implemented none).
  **This doc goes as far as "what must be visible", not "what it looks like"**

---

## TBD

- **How the research bench's four slots are separated on screen** — tabs or one list. **Only "body" behaves differently** (effective immediately); the other three are next-run
- **The point value table** — how many points is one circle/rune/glyph.
  **The fire rune's value matters most** — cheap and **stage 1's midboss stops being a wall from the very first run.**
  **It becoming not-a-wall later is intended** (GDD "the midboss's role changes per run").
  The only thing to preserve is that **it must be met as a wall once**
- **How many dice per run** · do unlocks raise the count · are more found in the dungeon
- **The price of one unlock** — how many 원석. **Re-derive against 9–11 per run**, not the old 1–2
- **Do death and clearing look different** — moved onto the settlement screen (`../plans/3.done/run-end-settlement.md`)
- **Saving.** 원석 is permanent and **nothing in `src/` writes a file** — no `user://`, no `FileAccess`.
  Research cannot outlive the process until this exists. No doc, no owner
- **Leftover money** — left as vanishing, not final
- **Do we put anything burnable (wood) in town** — doing so requires deciding "repair per run"
- **Town in multiplayer** — the window stopping the world breaks there
- **With no inventory, does "carry what you received back to town" hold** — it does not.
  ⇒ **Glyphs gained in a run die with the run** (same conclusion as GDD "the pool is permanent, objects are run-scoped").
  Then **the only thing you can bring to town is material.** Needs confirming
- **Does town go in the first milestone** — GDD "first milestone" is where that gets looked at
