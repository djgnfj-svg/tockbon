# Leveling and the three-pick — the only door rewards come through

**Status**: ready
**One line**: trash mobs drop XP and money, and on level up **you pick one of three glyphs.**
What you pick, **you also place into a layer right there.** **There is no stash.**

**Source doc**: `docs/GDD.md` "Progression" — "Drops" · "Leveling up" · "what is permanent is a pool, not an object".
**Do not duplicate it here.**

**Map placement** is in [stage1-map-layout.md](../3.done/stage1-map-layout.md) — **the shop does not go on the map** (below).

---

## Why

**Monsters are fully built and killing one does nothing.** The loop is broken here.

```
kill a trash mob  →  ???  →  get stronger
```

The GDD already set that middle — **XP → level up → glyph three-pick.**
**This doc actually builds it.**

**Why three-pick is already answered by the GDD.** Glyphs are **permutations, not a list**
("spread→blast ≠ blast→spread"), so **what you don't take separates builds more than what you do.**
⇒ Give everything and every run has the same magic circle.

**And why there is no reward unit called "zone clear" is in the GDD too** —
XP keeps both "killing a lot is a gain" and "walking past is a gain" alive **without creating a boundary.**

---

## Behavior

### Drops — split three ways

**The user stamped this settled.** Exactly the GDD's "Drops" table.

| Killing | Gives |
|---|---|
| **Ordinary monsters** | **XP · money** only. **Nothing used in assembly** |
| **Level up** | **A glyph three-pick** |
| **Midboss** (bull) | **A progression key** — the fire rune. **Already carrying fire, it gives a three-pick** (GDD "the midboss's role changes per run") — **this doc builds that branch** |
| **Boss** (giant rooster) | **Research material** (permanent) + **a glyph three-pick** |

**Permanent currency comes from bosses only. Everything else is money and XP.**

### Leveling up

- XP fills and the level rises
- **The only thing a level changes is the three-pick** (decided by the user).
  Health doesn't rise and circle layers don't grow — **a level is only "the door glyphs come through"**
  ⇒ **One path to getting stronger**, easy for the player to read, and it fits "skeleton first"
- **Three times per run (stage 1)** is the target — about once per zone.
  **A rough number.** With 20–30 trash mobs, **one level per 7–10 kills.** Adjust after playing

### When the three-pick appears — you don't pick immediately

**Exactly as the GDD says.**

```
level up  →  only a "level up" indicator  →  press a key in a safe place  →  three cards appear
```

**Same discipline as the assembly window** — **the world doesn't stop.** Choosing is for safe moments.

**Especially in this game** — freeze time while water flows and fire spreads and **those freeze too.**
"The world stays alive" is this game's thesis, and a reward screen would cut it.

### Where a pick goes — **the layer is chosen right there. There is no stash**

**The user reversed this.** That same morning it was decided as "stash it and assemble separately",
**and that decision is dropped.** **The source is `docs/GDD.md` "There is no inventory"** — not duplicated here.

```
three cards  →  pick one  →  on the same screen, choose which layer  →  done
                             if layers are full, also what gets pushed out
```

**Why it reversed**: this game is about **growing one magic circle across a run**, so a stash creates
**"I don't have to decide yet" and defers the weight of the choice.**
And roguelikes effectively have no inventory (Dead Cells · Skul · Isaac · Noita).

**The original argument survives the reversal.** The stash existed because
"auto-slotting into the last layer removes the order choice", and
**letting the receiving screen choose the layer removes that worry** — two screens merged into one.

**It actually gets stronger** — with full layers, **what to discard** comes with it.
The GDD's three-pick logic ("what you don't take separates builds") gains **"what you discard".**

**The price is the screen.** The three-pick window must carry **two steps**, "choose" and "place in a layer".
**The assembly window gets lighter** — all that's left is **reordering what is already equipped.**

### You can decline — and the **dice** (decided by the user)

**Dislike all three and you take none.** **The source is `docs/GDD.md` "Declining and the dice"** — not duplicated.

**This repays the cost of removing the inventory.** With no stash, **full layers mean a new glyph must push
something out**, and if all three are worse than what you have, **declining is the only right answer.**
⇒ **Without declining, the three-pick becomes a punishment.**

**Dice** — **reroll** instead of taking. **A permanent unlock, so you don't have it at first.**

**Within this doc's scope, the dice is only a reserved slot** — without a research bench nothing unlocks,
and the research bench is `docs/design/town.md` with **zero code.**
⇒ **What gets built now is up to declining.** For the dice, leave only **a button slot and a count variable.**

### How candidates are drawn

**Pool = glyph × rarity.** **Glyph rarity is what keeps the three-pick alive** — without it, a glyph you already
have appearing again wastes that slot.

```
spread · blast  ×  common · rare · unique  =  6 candidates
```

- **The same rarity of something you already have never appears** (decided by the user). **No dead slots**
- ⇒ "A **higher rarity** of the spread I have" is a valid option

### But the pool is only 6 — and the user chose dummies

**Two glyphs exist in code** (`glyph_defs.ALL` = spread, blast). The GDD lists 17 names and
**the rest are names only** — the user pinned it: **"other than spread, they're just names".**
**Do not read the phrasing "six have definitions" as settled.**

3 level-ups + 1 boss three-pick = **4 draws** from a 6-pool, so **the no-duplicates rule blocks immediately.**

**The user decided: "we'll build glyphs, but for now let's use dummy data".**

#### What the dummy does — **it only raises damage** (decided by the user)

**A dummy that does nothing is not built.** The dummy glyph **raises damage** — more at higher rarity.

**This is the only reason it avoids "screen changes, sim doesn't"** (CLAUDE.md's signature fake).
Picking from the three-pick and having the spell change nothing is exactly that place, and
**damage actually reaches the sim.**

#### But it gets no name — it is "dummy"

**Sixteen of the GDD's 17 glyphs are names only.** `docs/design/circle-rune-glyph.md` recorded
**"only 2/17 glyphs (spread, blast) are in code"** and went further, leaving
**"three pairs of names overlap — amplify/empower · manipulate/control · spread/split"** as
**not even having their differences decided.**

**⇒ Do not name it "amplify because it raises damage".** That makes the undecided look decided, and
**this repo has been burned there** (`docs/design/README.md` header: "being written reads as being present").
That misreading actually happened once in conversation and the user cut it.

⇒ **A dummy is called a dummy.** It gets a name the day the real glyph is decided.

#### Being a dummy must be visible

- **Marked in the name** — the screen literally shows "dummy"
- **`glyph_defs` must itself carry which ones are dummies** — recorded only in docs, they diverge

#### Cost — the pipeline gains one kind

`glyph_defs` has **only `KIND_SPAWN` and `KIND_TERMINAL`.**
**Raising damage neither spawns nor finishes** ⇒ **a third kind (modify) must be stood up.**

This is the place `docs/design/monsters.md` warned that **"adding homing is a different order of magnitude
from adding one glyph".** **But raising damage is the cheapest case of it** — it doesn't touch the trajectory,
it **multiplies one number.**
**So this dummy is also the work of opening the slot that homing, accelerate and spin will later enter.**

#### Growing the real glyph list is not this doc

**The user decided: "add them later. I have no ideas right now."**
⇒ **Broken out as separate work** — left in `docs/design/README.md`'s "features with no doc yet" table.
**Real glyphs go in before the demo** (user).

### Money — the shop at the stage transition

**The user decided: the shop is "when you clear a stage and move on".**

**⇒ The shop does not go on the map.** [stage1-map-layout.md](../3.done/stage1-map-layout.md)
**needs no change** — no merchant slot to reserve in the 400-tile map, no density to re-measure.

**Stage transitions don't exist yet** (`docs/design/README.md`: "stage transition — none").
**⇒ The shop is only slotted in this doc; the real implementation comes when stage transitions exist.**
**Stage 2 is planned for next week** (user), so it arrives then.

**What the shop sells is TBD.**

---

## Screen

- **XP bar** — where? **The HUD is currently only a debug label**
- **"Level up" indicator** — **it opens on a keypress, so "you can open it now" must stay visible.**
  Invisible, the player carries a three-pick until the run ends
- **The three-pick screen** — three glyph cards. Each with **name · rarity · what it does**
  - **Rarity must separate by color** (common · rare · unique). This game's palette is dark
  - **A dummy must show as one** (above)
- **Layer placement** — **the three-pick window's second step.** The circle picture shows layers, and a full slot shows what gets pushed out

**The world doesn't stop, so water, fire and monsters keep running behind the three-pick screen.**
**Whether a window over that is readable is judged by eye only** — `fx_tuning.gd:467` already carries
the user's note that "there probably needs to be a background color, like a window opening".

---

## Boundary

| | |
|---|---|
| **A level gives only the three-pick** | No health, no layers |
| **The world doesn't stop** | Water, fire and monsters run while the three-pick is open |
| **A pick isn't used immediately** | It goes through the assembly window |
| **No duplicates appear** | A 6-pool dries fast ⇒ **why the dummy is needed** |
| **There is nowhere to spend money yet** | The shop attaches to stage transitions, which don't exist |
| **Ordinary monsters don't give glyphs** | Don't make the assembly window open mid-fight (GDD) |
| **Levels don't accumulate in town** | The GDD leaves "run-scoped or accumulates in town" TBD, but **if a level gives only the three-pick, run-scoped is natural** — see "TBD" |

---

## Interaction with what exists

| What | How |
|---|---|
| **Monsters** | **There is no path emitting XP and money on death.** Make that slot in `monster.gd` |
| **Glyphs** | `glyph_defs.DEFS` has **no rarity axis.** Currently one id with name, kind and budget |
| **Magic circle** | Glyphs socket into layers (`spell_circle.gd`). **The three-pick screen sockets directly there** — no intermediate storage |
| **Assembly window** | **A debug label.** **Removing the stash reduced its job** — reordering only |
| **Bosses** | The rooster gives a three-pick + research material → [stage1-bosses.md](stage1-bosses.md) |
| **Map** | **Untouched** — the shop is off-map |
| **Stage transition** | **Doesn't exist.** The shop and research material hang on it |

---

## Cost

**Cheap. It doesn't touch the sim.**

| | |
|---|---|
| XP and money accumulation | A few integers |
| Drawing three | 4 times per run. Pick 3 of 6 candidates |
| **Screen** | **This is all of it** — the three-pick window (two steps) and the XP bar. **Render cost can't be measured headless** |

**There is one performance trap** — the GDD set "higher rarity spreads more", and
**spread's shot count is directly tied to performance** (the GDD blocks the 8→64 explosion by rule).
**How many bolts a unique spread makes must be decided within that constraint.**

---

## Acceptance

**Write what was seen by eye under this section immediately** (CLAUDE.md).

1. **Killing a trash mob raises XP** — visible on screen
2. **Full XP shows a "level up" indicator** — and **it doesn't disappear** (until the key is pressed)
3. **Pressing the key shows three cards** — **and the world keeps running** (water, fire, monsters)
4. **The three differ from each other** — no two cards of the same glyph at the same rarity
5. **The same rarity of something you already have never appears**
6. **Picking one leads into the layer-choosing step** — the other two disappear
7. **With full layers, what gets pushed out is visible, and it disappears**
7b. **Nothing is stashed anywhere** — there is no state in code that could be called a stash
8. **The socketed glyph actually changes the spell** — **the biggest risk in this doc.**
   **The dummy included — damage actually rises.** Measure it by value (how many hits kill the same monster).
   **"Nothing happens but it showed on screen" is the signature fake**
8b. **Higher rarity raises damage more** — common < rare < unique separates by value
8c. **Being a dummy is visible on screen** — and `glyph_defs` carries that marking
8d. **You can decline and close** — and **nothing changes** (layers untouched)
9. **Roughly 3 level-ups per run**
10. **What happens when the pool dries** — the dummy fills it. **A blank slot or a window that won't open is a failure**
11. **Beating the boss gives a three-pick + research material**
12. **The three-pick window is readable over the grid** — with water and fire running behind, is the text visible

---

## TBD

**Do not force these full.**

- **XP values** — how much per monster, how much per level. Only "three times" is the target
- **How much a rarity strengthens** — spread from 8 bolts to how many.
  **Must be decided within the GDD's explosion constraint**
- **Color per rarity** — must separate on screen
- **How many dummy glyphs to build** — the pool must support 4 draws
- **How much the dummy raises damage** — values per rarity
- **Which real glyphs to build first** — **separate work** (user: "I have no ideas right now").
  **They go in before the demo**
- **What the shop sells** — glyphs · healing · rarity upgrades.
  **Decided together with stage transitions**
- **Do levels accumulate in town** — the GDD's TBD. **If a level gives only the three-pick, run-scoped is natural,
  but the user hasn't decided explicitly.** (It previously read as "home" and didn't turn up in searches)
- **How many dice per run** · do unlocks raise the count · are more found in the dungeon
- **Leveling twice without opening the three-pick** — do they stack, or does only one remain
- **Do runes have rarity too** — the GDD's TBD. This doc covers glyphs only
- **How money is shown on screen**

---

## Decided — from the design conversation

| What | Value | Why |
|---|---|---|
| What a level does | **Three-pick only** | One path to getting stronger, easy to read |
| Three-pick timing | **Opened by key. The world doesn't stop** | Exactly the GDD. Same discipline as the assembly window |
| After picking | **Layer chosen right there. No stash** | A game about growing one circle doesn't create a place to defer |
| Declining | **You can decline all three** | With no inventory, full layers force a push-out; without declining the three-pick is a punishment |
| Dice | **Decline and reroll. A permanent unlock** | Infinite rerolls erase "what you don't take" |
| Duplicates | **The same rarity never appears** | No dead slots |
| Rarity | **Three tiers — common · rare · unique** | Exactly the three names in the GDD |
| Not enough candidates | **Fill with dummy glyphs** | User decision. **Being a dummy must be visible** |
| Level-up frequency | **Three per run** | About once per zone. A rough number |
| Permanent currency | **Bosses only** | Settled. Everything else is money and XP |
| Money | **The shop at the stage transition** | **It does not go on the map** |
