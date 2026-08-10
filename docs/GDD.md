# tockbon GDD

**One line**: a side-scrolling roguelike co-op where you combine circles, runes and glyphs into your own magic
circle and watch it unfold in the world as you descend.

This doc has no status. Unlike the design docs in `docs/plans/`, it is **a living reference.**
Implementation specs for individual features live in `docs/plans/1.ready/`.

---

## Where the fun comes from

**Watching the magic circle you assembled unfold.** That one line is the criterion for everything else.

So the priorities split like this:

- **A spell's trajectory, shape and chaining** — first. The glyph list (spread · condense · blast · home · spin · deploy) being *all about bolt shape* rather than terrain is the evidence
- **The world reacting** — next. Terrain breaks, water pours, monsters die
- **The precision of the world itself** — last. Melting individual pixels is not the goal

Invert this order and it dies the way v1 died: the sim was precise and **the screen didn't follow**, so nobody felt stronger.

---

## World — why you go collecting magic circles (decided by the user)

**The magic circle collapsed.** The circles, runes and glyphs inside it scattered into the world, and
**beasts swallowed them.** The player is **a mage recovering what was scattered.**

**This explains three of the game's structures at once** — each of which stood alone until now:

| Structure | The reason the world gives |
|---|---|
| **The starting kit is meager** | Because you lost everything. Starting with one none-rune becomes natural |
| **Why monsters are there** | They are the ones that swallowed. Not "it's a farm, so there are pigs" |
| **Why the midboss is a progression key** | **A bull that swallowed the fire rune.** Kill it, get the rune back, and burn wood to open a path |

**How much the swallowing shows varies per beast** (the user corrected this).
**Trash mobs barely show it** — they swallowed only a little. **Bosses swallowed almost all of it.**
**How that appears on screen (or doesn't) is set by `docs/design/monsters.md`.**

**So it doesn't collide with "ordinary monsters don't drop runes"** (see "Drops") —
what trash mobs swallowed is **none-element fragments**, and none is already the starting kit, so there is nothing new to give.
⇒ **It comes out converted into XP and money.**

**Monster detail is set by `docs/design/monsters.md`.** Do not duplicate it here.

**Not decided**: **why** the circle collapsed · who did it · what the town and research are in this story.
What the beasts of stages 2 and 3 swallowed is also TBD.

---

## The magic circle

Exactly the usual magic-circle picture. **A round frame with a rune at the center and concentric layers outside it.**

```
   ╭──────────────╮ ← circle (the frame)
   │ ╭──────────╮ │
   │ │ ╭──────╮ │ │
   │ │ │  ⬢   │ │ │   ⬢  rune       — what goes out
   │ │ ╰──────╯ │ │   layer 1 glyph — what it does on impact
   │ ╰──────────╯ │   layer 2 glyph — what it does next
   ╰──────────────╯
      interpreted inside ──▶ outward
```

**A magic circle is a pipeline, not a list.** Layer order is execution order.

**What each of the three axes holds is set by `docs/design/circle-rune-glyph.md`.**
This doc records not a summary of it but **only the face visible from the game side** — duplicate it and the two diverge.

**How it looks is set by `docs/design/circle-art.md`** (the user decided by eye).
The picture above's "rune at the center · one symbol per layer" **both changed** — **a glyph is a ring that fills a layer**
and **runes socket into the circle's rim** (gather 8 runes at the center and they mush to 34px diameter — measured).

### Circle — the frame

- **One circle per magic circle**
- **It sets the frame** — layer count · rune slots · **how runes combine** (fusion · parallel · sequential)
- **Layer count varies per circle.** The circle *is* "the size of the vessel"
- Starting circle: **round, 2 layers**
- **There are three circles** (decided by the user) — **basic · fusion · triangle.** More will be added.
  Their rune slots, layers and combining modes are set by "the circle list" in `docs/design/circle-rune-glyph.md`

**The three are not a ladder — runes are added by taking layers away.**
The 3-slot triangle circle gives **one layer per rune**, so one bolt passes through exactly one layer,
⇒ **there is no order combination at all.** The permutations from "glyphs, inside out" below don't exist for it.
That this is **a different kind of circle** rather than a defect is the point of this design —
if only the layer count differs, that's an upgrade, not a choice, and in a roguelike an upgrade needs no deciding.

**The triangle circle fires clockwise from 12 o'clock, and the picture does not show that** (user decision).
It is **the one place where "if order isn't visible on screen the player never learns the rule" was broken knowingly** —
the story and remaining safeguards are in `docs/design/circle-rune-glyph.md`, "the picture doesn't state the order".

**The circle does not set how things fly. The rune does.**
If the circle set the firing shape, **every element flies identically under the same circle and the rune dies as a color axis.**
Lightning arcing slowly through the air is not lightning.

**The circle doesn't set the shot count either — it derives from the rune layout.** Three runes in parallel *is*
three shots, each a different element. ⇒ N circles × M runes falls out of **two tables.**

### Rune — the element

- Goes in the center
- **Several can fit.** The count varies per circle
- With several, they **fuse** (water + fire = steam) or go **parallel/sequential** as the circle dictates
- The starting circle takes **1** rune

**The rune is both element and behavior — being that element, it flies that way.**
Fire flies as a slow drooping mass, lightning goes very fast and straight, water drops heavily.
⇒ The player never memorizes a table. **"Lightning is fast and straight" is common sense.**

### Glyph — the added effect

- **One per layer.** A 2-layer circle takes 2 glyphs
- **There are seventeen** (decided by the user) — spread · blast · condense · accelerate · home · spin · split ·
  refract · amplify · emit · empower · distort · absorb · manipulate · control · deploy · convert
  **Which of the three kinds (modify/spawn/finish) each belongs to is set by the glyph table in `docs/design/circle-rune-glyph.md`.**
  **Only two exist in code — spread and blast** (`glyph_defs.ALL`). The other fifteen are names or examples.
  **Do not restate the count here.** It is counted in that one table — count it in two places and they diverge (they did)
- Starting glyph: **one spread.** The rest are found in the dungeon

**Glyphs have rarity** (decided by the user) — common · rare · unique.
**The same glyph at a higher rarity does more** — spread spreads more, and more, and more.
⇒ "Spread" and "unique spread" are **not different glyphs but different rarities of one glyph.**

**Rarity is what keeps the three-pick alive.** Without it, a glyph you already have appearing again wastes that slot;
with it, **"a higher rarity of the spread I have" is a valid option.**
**Three tiers settled — common · rare · unique.** The rarity numbers (how much more it spreads) are still **TBD**, and
**spread's shot count is directly tied to performance, so it must be set within "glyph constraints" below.**
**Whether runes have rarity is undecided.**

**A glyph creates nothing new. It adds to what exists.**
If a glyph can do anything it eats the other two — an "apply fire element" glyph makes runes unnecessary,
and a "split into 3 shots" glyph makes circles unnecessary.
⇒ Changing the element is the rune's job; changing the firing arrangement is the circle's.

**Glyphs are interpreted from the inner layer outward. Change the order and it's a different spell.**

Even with two identical glyphs, a different order gives a different **kind** of result:

| Combination | What happens | Result |
|---|---|---|
| **spread → blast** | On hit, spreads in 8 directions, and **each of those blasts when it hits** | **8 blasts** — a wide area detonating in eight places |
| **blast → spread** | On hit, blasts first, then **spreads in 8 directions from there** | **1 blast + 8 embers** — one big detonation with fire spreading out |

That is why this game's combinations run deep. With N glyphs it is **permutations, not combinations** — 3 gives 6, 4 gives 24.

### Glyph execution rules

A bolt carries a **remaining glyph list.** On impact it executes the **first** glyph in the list.

Glyphs split into three kinds, and that distinction is the entire pipeline:

- **Modify** (accelerate · home · spin) → doesn't wait for impact; **alters flight the moment it is reached in the list.** Continues straight into the next glyph
- **Spawn** (spread) → **hands the remaining list to the newly created bolts.** The next glyph runs when those bolts land
- **Finish** (blast) → no bolt is created, so **the next glyph continues at the same spot**

An empty list ends it.

**Modify does not overwrite the rune's behavior; it modifies it.** Accelerate is not "make the velocity straight"
but "increase whatever the velocity is" — on fire it gives a fast arc, on lightning a longer straight line.
Overwrite and the rune dies again. Layering keeps both alive.

**Order lives in modify too:**

| Combination | What happens |
|---|---|
| **accelerate → spread** | Flies fast, lands, 8 bolts there. **Those 8 are not fast** |
| **spread → accelerate** | Lands, 8 bolts, **each of the 8 accelerates** |

### Glyph constraints — block the explosion with rules, not a cap

"Spread → spread" is 8 → 64 bolts in principle, and 256 with four players. How you block that is the fork.

**Do not use the simultaneous-projectile cap as a tuning knob.** A bolt that fails to fire because of a cap
**reads as a malfunction** to the player.
⇒ Instead, **constrain the glyph itself so it's blocked at assembly time.** Then it's a rule, not a malfunction.
**The problem surfacing at assembly time rather than firing time** is the whole of this choice.

Kinds of constraint:

- **Count** — only **one** spread per magic circle
- **Position** — some glyphs only in the last layer, some only in the first

⇒ With one spread, the 8 → 64 explosion becomes **structurally impossible.**

**Constraints are the tuning knob for performance and network budget.** When a four-player combination blows up later,
you don't tighten the cap — **you add a constraint to that glyph.** The budget is expressed as rules.

Per-glyph constraints are **TBD.** Nothing is decided beyond spread being "one only".

**Parallel runes walk around this constraint.**

```
3 runes parallel × spread each = 3 × 8 = 24 bolts.  96 with four players
```

There is one spread, but **effectively three magic circles**, so the logic blocking 8 → 64 doesn't apply.
And **the unit of "one per magic circle" itself wobbles** — with per-rune layers, is it one per line or one per circle?
The former reproduces the explosion; the latter gives three runes with spread on only one line.

⇒ **TBD.** Candidates: circles with many rune slots can't take spread / pin a total shot cap per circle /
parallel circles are shallow and naturally blocked.

### Size floor

Each spread makes what comes out **smaller and weaker.** And **there is a floor below which it can't split.**
At the floor, spread doesn't apply.

The floor value is **TBD.**
**"Small things being weak" saves performance too** — weak means a smaller blast radius, and half the radius is a quarter the cost.

### The relationship between runes and glyphs

A glyph's **picture varies by rune. The rule is the same** — **but only when the runes differ in coefficients only.**

- fire rune + spread → 8 **small flames** after impact
- water rune + spread → 8 **small waters** after impact
- lightning rune + spread → 8 **small bolts** after impact

**Eight directions fit the integer contract perfectly.** `(±1,0) (0,±1) (±1,±1)` come out as integers with no
`sin` or `cos`. Here the glyph's integer constraint costs nothing.

**Some runes fly as an entirely different kind.** If lightning is a **line** rather than a projectile, "spread" splits
into "8 directions at the line's end" or "splitting along the line" — **for such runes the rule differs too.**

So **they are not all opened.** Start with coefficient-only differences and open runes with strong identity one at a time
(lightning as a line, water pouring). Open everything and **6 glyphs × 4 runes = 24 cases must be defined**,
most of which go stale before they're built. Detail in `docs/design/circle-rune-glyph.md`, "behavior splits into two stages".

### Equipping and firing

- There are **exactly two equip slots, 1 and 2**
- Left click fires
- **There are no potions** (decided by the user). The ~~separate fixed key~~ idea went with it

Two slots is design, not constraint. It means **"choose and use", not "swap mid-fight"**, which makes assembly
something you do outside combat.

### Assembly — any time during a dungeon

- **Tab opens it any time** inside a dungeon
- **The world doesn't stop.** Monsters approach while you assemble
- **Layer order is visible just by looking at the window.** Concentric rings drawn inside-out put the order in the picture
- The rule itself is taught **in onboarding**

**If order changes the effect and order isn't visible on screen, the player never learns the rule.**
However deep the combinations, nobody uses them. ⇒ The assembly window's picture and onboarding are that place.

**The reason it doesn't stop is multiplayer.** In 2–4 player co-op, freezing everyone every time one person opens a window
makes the game unplayable.
**The price**: long assembly means nobody uses it in a real fight. That is why the base circle is 2 layers and there are 2 slots.
As layer counts grow, **assembly naturally gets pushed to safe moments** — that pressure is itself part of the design.

### There is no inventory (decided by the user)

**The rejected side and the conditions for reopening are in `docs/decisions/no-inventory.md`.**

**There is nowhere to stash what you pick up. The moment you receive it, you also decide where it goes.**
Decline to place it and **it disappears.**

**The game-side reason is stronger than genre convention.**
This game is about **growing one magic circle across a run**, not swapping per situation
(the same pressure as "choose and use, not swap mid-fight" above).
⇒ **A stash creates "I don't have to decide yet", and the weight of the choice is deferred wholesale.**

**Genre convention agrees** — Dead Cells · Skul · Isaac · Noita **all have no inventory.**

**So "receiving" becomes one act with "discarding".**
With a 2-layer circle already full, a new glyph means choosing **what it pushes out.**
⇒ The logic the GDD attached to the three-pick (**"what you don't take is what separates builds"**)
**gets one notch stronger** — beyond what you don't take comes **what you discard.**

**Order selection doesn't die.** "Without a stash it auto-slots into the last layer and order disappears" was the
argument for a stash, but **letting the receiving screen choose the layer removes that worry** —
the step doesn't vanish; **two screens merge into one.**

⇒ **All that remains in the assembly window is reordering what is already equipped.** That is not a stash.

**Gear follows the same discipline** — step on something on the ground and decide there whether to wear it; decline and walk past.

### But **an equipment screen is not an inventory** (the user sorted this out)

**They are different things. Blur them and gear becomes unbuildable.**

| What | What it holds | Verdict |
|---|---|---|
| **Inventory** | Stashes **what isn't equipped.** Slots grow | **None** |
| **Equipment screen** | Shows **what is equipped.** Fixed slot count | **Exists** |

**The core (circles · runes · glyphs) has no room for an inventory** — all three **socket directly into the magic circle**,
so there is no state of "carrying it unequipped during a run".

**The "unlock list" doesn't fall under this.** The town assembly bench shows unlocks and lets you choose,
but that is **a list opened on the account, not objects you carry** — a catalog, not a bag.
**One test: growing during a run is an inventory; visible only in town is a list.** ⇒ **Nothing to stash, so no window is needed.**
Skul and Dead Cells having equipment screens while "having no inventory" is exactly this distinction.

**So the earlier claim that "a bag collides head-on" is resolved** —
**bag, potions and ink were all deleted** (see "Gear"). With nothing to carry, no slots are needed.

---

## The world

### The grid

| Value | Size | Relation |
|---|---|---|
| Cell | **4px** | The sim's smallest unit |
| Terrain tile | 32px | = **8×8 cells** |
| Character | **32px** | = **8 cells** = exactly one terrain tile |

**Raised 16px → 32px. Cells stayed at 4px.**
The reason is that **"reads as a mage" never came out within 16px** — the silhouette was reworked several times and
the user judged it by eye. Detail in **`character-sprite`**.
**The two paragraphs below survive this change.** Character and tile still match and cells are still 4px, so
"you can count it" got **finer, from 4 steps to 8.**

Matching character and tile thickness is **the device that makes power tiers visible.**
"Breach that wall and I can get through" can be counted on screen.
Raise cells to 16px and **one hole is a passage**, mushing the power distinction entirely. Hence 4px.

### Natural law

- **Terrain is destructible.** Magic digs walls — **it digs even with no glyph.** Detail in **`spell-carves-terrain`**
  That doc left **"breached ≠ passable"** unresolved — disc carving leaves 4px teeth on a tunnel's ceiling and
  the character gets stuck even in a fully pierced tunnel. **The device in "matching character and tile thickness" wobbles there**
- **Water flows.** It pours and pools — detail in **`docs/design/water.md`**
- **Water touches the player and monsters.** They get wet, and wet conducts.
  **Wet is not a separate state but "a little water"** (decided by the user)
- **Fire spreads.** Only where there is fuel
- **Lightning follows conductors.** It travels through water and wet things, then dies
- You can make platforms, and spell recoil can push the character **sideways**
- **Magic hits the player too.** Your bolts and your ally's bolts both hit you

**"Different order, different result" is this game's thesis.**
Wetting first and then striking with lightning gives a different **kind** of result than lightning first.

**So the player is the first subject of these laws.** Even with no monsters, you learn the thesis with your body.
Detail (health · damage · invulnerability · knockdown) is set by **`character-damage-minimum`**.
**Two things were deleted from recoil** — **hit knockback** (being pushed when hit) and **rocket jumping**
(shooting down to rise). What remains is **"firing pushes you sideways"**. That doc has the story.
**Losing the rocket jump also lost "danger and mobility come from the same action"** — shooting at your feet is now
only danger. "Magic hits the player too" above survives.

**The same day, jump height became a function of how long you hold** (user request) — a tap gives 1.2 tiles,
a hold gives 3.2. ⇒ **Mobility moved from the rocket jump to the jump itself.** Values and measurements in `character.gd`.

**Name docs, don't path them** — docs under `docs/plans/` change folders with their status, so a path dies that day.

### State runs on burn-slot lists — outside chunks

Water has to sweep the grid (matter moves), but **fire and lightning don't.**
Both only need to iterate "the cells currently burning/conducting".

**This removes the "a timed state keeps a region awake" problem entirely.**
Burn-slot lists are **independent** of chunk sleep, so fire burns and lightning spreads even with the grid asleep.
v1's charge already had this structure and it was proven. Fire uses the same structure.

**The reason lightning wouldn't go out in v1 was not TTL** — water ping-ponged forever on a flat floor,
and moving water re-registered into the burn slot every tick. **Fire doesn't move, so it doesn't have that problem.**
**It was promoted to the first section of `docs/design/water.md` because whoever builds water needs to read it.**
What remains here is only the contrast — **fire doesn't have that problem.** The water story lives in that doc.

### Fire fuel — natural law is the budget

- Every cell has **fuel.** Wood has a lot, stone has 0 (doesn't burn), water puts fire out
- Burning consumes fuel, and **at 0 it goes out and leaves the list**

**Total fire is limited by fuel, not by a cap.**
"Nothing to burn, so it doesn't burn" reads to the player as **a rule**;
"fire won't catch past N" does the same job and reads as **a malfunction.**
⇒ Exactly the same judgment as choosing glyph constraints over a projectile cap.

**So where you put fuel is level design.**
A room full of wood makes fire terrifying, a stone room doesn't burn, a room with water makes lightning terrifying.
**Terrain decides which rune is strong in which room.**

A total cap exists **only as a safety net** — a guard that trips only in the extreme of a whole forest burning.

---

## Multiplayer — 2 players required, 4 the goal

**Host-authoritative co-op.** But half the world runs deterministically.

| What | How | Why |
|---|---|---|
| Grid · spell projectiles | **Deterministic** — send input only and everyone computes identically | Flowing water changes hundreds of cells a tick and **cannot go over the network** |
| Monsters · players · items | **Host-authoritative** — the host is truth and broadcasts positions | Allows mid-join, allows float, and frees prediction and correction |

**Destruction is an event, so it's free.** A few bytes of `(x, y, radius)` and everyone erases the same circle.
Bandwidth doesn't grow with blast size.
**Flowing water can't do that.** Active, it's 500 cells/tick × 20Hz × 3 players ≈ 720kbps upstream, peaking exactly
**when the most water is pouring (= when magic is at its most spectacular).** So everyone computes it.

**Keep the boundary between the deterministic and host-authoritative sides narrow.** Judgments like "is it wet"
are made by the host and broadcast. A wide meeting point between the two worlds is the maximum desync risk zone.

### Team kill is fun, not an accident

**An ally's bolt hits you.** "Get out of the way" coming up every fight is **intended.**

⇒ So death is not instant — **you go down and an ally revives you.**

Why the safe option wasn't chosen, why revival is mandatory, and what health/damage/invulnerability are
is set by **`character-damage-minimum`**. Do not duplicate it here.

---

## Progression

It is a roguelike. **Two tiers** (decided by the user) — stages on top, zones within them below.

### Session loop — one run

```
town → stage 1 (farm) → stage 2 → stage 3 → clear
              ↓ on death
             town
```

- One stage = **one continuous scene.** You walk through it with no loading (see "Dungeon generation")
- Between stages is **a real transition** — the theme changes. **Beat the boss and a gate opens**
- Die or clear and you return to town
- **Unlocks accumulate in town.** More circles, runes and glyphs become available next run

**The first build is two stages** (decided by the user). The diagram shows three, but that is the final form —
first see **one run rolling across two stages.** The final count is still TBD.
⇒ **A fixed map means this number is the amount to hand-draw** (see "Dungeon generation"). Two × 4 zones = **eight zones.**
**How many minutes a run takes is also TBD** — that determines stage size and zone count.

### Inside a stage — the zone loop

```
enter → pass zones, fighting and looting → midboss → keep going → boss (gate) → next stage
```

**The midboss reward is the key to progression.** Not "a place to get stronger" but **"a place you can't pass without it".**
⇒ In stage 1, you need the **fire rune** to burn wood and open a path.
**Natural law ("fire spreads") becoming the means of progression** is the point of this design —
combat abilities and traversal abilities are not separate systems.

**Drops split three ways** (decided by the user). **Ordinary monsters give nothing used in assembly.**

| Killing | Gives |
|---|---|
| Ordinary monsters | **XP · money** only. **No kill pays permanent currency** |
| **Level up** | **A glyph — three appear, pick one** + **1 원석** |
| Midboss | **A progression key** (stage 1 = fire rune) |
| Boss | **3~4 원석** (permanent) + **a glyph three-pick** |

**원석 is the permanent research currency, and it has two doors — a boss and a level.**
**~~"Bosses only"~~ is void**: with the boss door alone a run yields 1–2 and a death yields 0, so most runs
would start no permanent progress at all. **No *kill* pays out** — trash mobs reach 원석 only through XP and
the level, the same single-door shape the three-pick already uses.
Rejected branches: `docs/decisions/gems-from-bosses-and-levels.md`. Where it is handed over:
`docs/plans/3.done/run-end-settlement.md`.

**Why ordinary monsters don't drop glyphs directly**: it would mean opening the assembly window constantly mid-fight,
breaking head-on the pressure the GDD built toward "assembly is for safe moments".
⇒ They give **XP and money** instead, and glyphs enter **through the single door of leveling up.**

**One-of-three fits this game particularly well.** Glyphs are **permutations, not a list**
("spread→blast ≠ blast→spread"), so **what you don't take separates builds** more than what you do.
⇒ Give everything and every run has the same magic circle. The three-pick blocks that structurally.

**For now the three-pick shows only glyphs.** Mixing in runes and circles came up but was **held.**
**The original argument ("start with none and get fire at the midboss" wobbles) is dead** —
the point-based start overturned that premise. **One argument remains: less to build.**
Since glyphs have rarity (above), **glyphs alone fill the three-pick with no blanks.**

### Leveling up — the reward door (decided by the user)

XP from monsters accumulates and you level. **A level grants a glyph three-pick.**

- **You don't pick immediately.** Only a "level up" indicator appears; **you press a key in a safe place** and pick then
- **Same discipline as the assembly window** — the world doesn't stop, and choosing is for safe moments
- **You can decline and move on** (decided by the user)

#### Declining and the dice (decided by the user)

**Dislike all three and you take none.** ⇒ The problem "no inventory" created
(**layers full and all three worse than what you have, so you must discard something anyway**) is solved here.

**And there is a "dice" — reroll instead of taking.**

**The dice is a permanent unlock.** Opened by research in town — **you don't have it at first.**
⇒ Early on there is only declining; as unlocks accumulate, **"decline and reroll" appears.**

**Why it isn't free**: with infinite rerolls, **a three-pick stops being a three-pick** —
roll until you get what you want and the GDD's "what you don't take" disappears entirely.
⇒ It must be **a permanent unlock and a consumable** for that axis to survive.

**TBD**: how many dice per run · do unlocks raise the count · can more be found in the dungeon.

**This design's goal is "killing a lot is a gain, walking past is also a gain".**
- Kill → XP accumulates and **leveling comes faster**
- Don't kill → **save time and move forward**

**So there is no reward unit called "zone clear".** A zone is a conceptual division with no physical boundary,
so judging a clear would require **closing a door**, and closing the door makes "walking past is also a gain"
impossible in principle. ⇒ **XP keeps both choices alive without creating a boundary.**

**Filled in later** — **the only thing a level changes is the three-pick.**
Health doesn't rise and circle layers don't grow. ⇒ **One path to getting stronger**, easy to read.
**Three times per run** is the target (about once per zone). **Whether it is run-scoped or accumulates in town is still TBD.**
Detail in `docs/plans/3.done/levelup-and-three-picks.md`.

### The stage template — what defining a stage means

**Defining a new stage means filling four slots.** Fill them and the stage is defined.

| Slot | Stage 1 |
|---|---|
| **Theme** (= material layout) | Farm — lots of wood |
| **Direction** | Right |
| **Midboss reward** (= progression key) | **Fire rune** — burn wood to open a path |
| **Boss reward** | Permanent material (gear enchanting came up, unconfirmed) |

**Stage 1's actual terrain and bosses are settled** — **300×48 tiles, three zones + a locked fourth.**
Trash section → ①**bull** (midboss, fire rune) → burn the wood wall → ②trash → ③**giant rooster** (boss)
→ **escape as water rises.** **Jumps are unlimited underwater** — that becomes stage 2's movement grammar.
Detail in `3.done/stage1-map-layout` · `3.done/stage1-bosses` · `2.active/water-jump-and-escape`
— **do not duplicate it here.**

**The GDD assumed 4 zones per stage; stage 1 has three.** The fourth slot is taken by a
**locked zone reachable only with a double jump** — visible on the first run, entered on the next.

Stages 2 and 3's four slots are **TBD.** **Water is stage 2** (decided by the user).

### Starting kit — **chosen with points, not fixed** (decided by the user)

**Before leaving town, choose which of your unlocked circles, runes and glyphs to take.**
**How much you can choose is set by "points".**

**Those points are the axis of permanent unlocking** — raise points through research and **you take more out with you.**
⇒ **"Getting stronger" arrives as a budget, not an object.** The same shape as the already-chosen "a pool, not an object".

**The initial points come to one none-rune · a basic (2-layer) circle · one spread.**
⇒ **The first run's starting kit is identical to the old fixed values.** What changes is **after unlocks accumulate.**

**Re-pinned by the user: you leave with the none rune and the basic circle. That is fixed.**
The points system does not make the *first* departure negotiable — **there is nothing else unlocked to spend on.**
⇒ Whoever builds the starting kit **builds the fixed pair first**; points are the shape it grows into, not a
step-one feature. (~~`spell_circle.DEFAULT_RUNE` is still `ELEM_FIRE` — that is the gap~~ — **void, it is
`Tuning.ELEM_NONE` in code**; the lock landed in `plans/3.done/rune-lock-and-receiving.md`.)

⚠ **And the fixed pair stops being *seated* at boot.** `plans/3.done/onboarding-and-palette-tabs.md` (built) starts
the run with an **empty circle that cannot fire** — the none rune and the basic circle are **owned and in the
palette**, and assembling them is the first thing the game asks for. **"one spread" above is not in that
plan's starting kit** (its 문양 tab opens on 「현재 문양이 없습니다」); whether the player still owns spread
at boot is **that doc's open TBD**, not a settled line here.

### So **the midboss's role changes per run** (decided by the user)

**Buy the fire rune in town and stage 1's midboss stops being the key to progression.**
**That is intended, not broken.**

| When | What the midboss is |
|---|---|
| **Can't afford the fire rune** (early) | **A place you can't pass without it.** Kill it and the wood wall opens |
| **Took the fire rune** (after unlocks) | **Just a monster that gives a reward.** Kill it and **a choice of reward** appears |

**Dropping from "key" to "reward" is where permanent progress is felt.**
What was a wall yesterday is an option today — **the terrain proves the player got stronger.**

**This also repays the price of the fixed map** — in exchange for terrain holding no surprises,
**the same terrain means something different each run.**

**The price still matters.** Priced cheap, the key disappears **from the first run** and the left column above never occurs.
⇒ **It must be met as a wall once.** The value is TBD.

**The reward is the same thing as the level-up three-pick** — **choose one of what appears.** No new axis.

**And whether to kill it becomes the player's choice** (decided by the user).
**Carrying the fire rune, you can skip the midboss** — burn the wood wall directly and walk on.
⇒ **The pit becomes "a reward if you enter, skippable if you don't".**

**The map needs no change.** What "fixed map" already recorded —
**"a player who memorized the route passing faster becomes skill"** — is exactly this.

**Build it only so it can expand later** (user instruction). Make the point ceiling and item values come
**from a table rather than numbers** and code won't change as unlocks grow.

### What is permanent is a pool, not an object (decided by the user)

**Beat a boss for the first time and the pool of possible appearances widens from then on** — later bosses
draw from more glyphs and runes.

| What | Permanent? |
|---|---|
| Glyphs and runes picked up this run | **No.** Lost when the run ends |
| **The pool of what can appear** | **Permanent.** Widens each time a boss is first beaten |
| Research material · town unlocks | **Permanent** |

**This split resolves the earlier dilemma.** With permanent objects, stage 1's midboss has nothing to give from the
second run on; with everything run-scoped, stage 1 is identical every run.
⇒ **Objects run-scoped, pool permanent** avoids both — **what appears differs per run, so no two runs are the same.**
**"Starting with none every run keeps the fire rune meaningful" is the old argument.** "Starting kit — points" overturned it —
**now, if you can buy the fire rune, you buy it and leave with it.**

**The double jump is unlocked by research in town** (decided by the user).
The ~~give it as stage 1's boss reward~~ option is dropped. Why it tipped: town unlocks are
**an axis already declared permanent**, so it doesn't disturb the split above.

**And terrain now stands on top of that.** Stage 1's map has a **zone (④) reachable only with a double jump**,
visible but unreachable on the first run ⇒ **a double jump obtained within a run would make that zone meaningless.**
Detail in `docs/plans/3.done/stage1-map-layout.md`.

---

## Gear

**Staff · robe · boots. Three** (decided by the user — **the bag was deleted**).
Expansion goes on a new axis.

### Not settled — a direction that came out of conversation

**The user raised the problem "only the magic circle gets stronger; there is no character build"**, and this came out then.
**The user did not choose it** — pick this section up here next time.

> **The magic circle sets "what goes out"; the character sets "how you use it".**

**Make both strengthen the same thing and one of them dies.** Gear giving "+20% fire damage" steals the circle's job.
Gear should instead make **the same magic circle play differently.**

| Slot | The axis it owns |
|---|---|
| Staff | Firing rhythm — rate · range · recoil |
| Robe | Enduring — health · invulnerability · **elemental resistance** |
| Boots | Moving — movement · jump · dash |

**~~The bag~~ was deleted.** "Slots you carry" made slots into an inventory, colliding head-on with "there is no inventory",
and **what would go in it (potions, ink) was deleted too, so the slots became unnecessary.**
If a fourth slot is needed, open it **on a different axis** — never as "things you carry".

**The link between the two axes is elemental resistance.** It falls out for free from the GDD's
**"magic hits the player too"** — the more you sharpen a fire build, the more your own fire burns you,
so **a fire-resistant robe becomes necessary.**
⇒ The magic-circle build **forces** the gear choice. Two systems become one with no new rules.

**~~Ink~~ was deleted too** (decided by the user).
**The idea itself was good** — painting it onto a circle's layer to alter bolts passing through that layer
**reused the permutation axis.** **What killed it was not that but "you have to carry it"** —
unpainted ink is **an object held unequipped**, which is an inventory.
⇒ Reviving it requires **a form you don't carry** (e.g. it paints onto a layer the moment you receive it). **Not now.**

**Not built now** ("skeleton first"). There are no monsters and no water, so there is nothing to measure against.

---

## Build order — skeleton first

**Stand up the whole skeleton before adding flesh.**
Build each part **only until it works** and move on. Do not exhaust one part's detail before moving on.

**The reason is experience.** Detail without a skeleton has no reference for what it's for, and most of it
gets rebuilt as the skeleton comes up. That already happened once in this project.

⇒ **TBDs and constraints in `docs/plans/` docs are not all filled during the skeleton stage.**
Decide only the minimum needed to run; decide the rest **when that part reopens for flesh.**
Remaining TBDs are not an unfinished doc but **something whose turn hasn't come.**

### The current order (decided by the user)

Do them **one at a time**, across sessions. Never open several at once.

1. **Water + map** — the water sim and stage 1's terrain together
2. **Flying magic** — bolt trajectory and shape
3. **Monsters**
4. **The three-pick screen** — level-up rewards

**What comes after (gear · town · multiplayer) opens once these four run.**
**What actually runs right now is set by the table in `docs/design/README.md`** — being written in the GDD does not mean it exists.

### First milestone — "stage 1 rolls end to end" (decided by the user)

**Goal**: **build stage 1** this week.
**One acceptance check** — **the user starts once and reaches the end without getting stuck.**

**Why it was needed**: "the current order" above says **what** to do and never **when it's done.**
The user named that **"the absence of a goal"** — not even where you get stuck was written down.

**It is one chain. One gap and everything after it is invisible:**

```
map → pit → bull → fire rune → burn the pit's own back wall → rooster
→ [water rises, escape the stage] → gate
```

**The chain lost two links** (decided by the user): the wood wall moved **into** room ①'s east wall, so the
rune is used where it is won, and **the pit's water escape and zone ②'s trash run both go.**
⇒ `docs/plans/3.done/burn-out-of-the-bull-room.md`, built

⇒ **This week the work is linking the chain, not depth.**

| Gap to fill | Now | Where |
|---|---|---|
| ~~**Map terrain**~~ | **Filled** — **300×48** baked and in (was 400×48; the left run's 100 flat columns were cut). Acceptance 3·4 still unconfirmed on screen, and the cut's own screen half is unlooked-at too | `docs/plans/3.done/stage1-map-layout.md`, `3.done/left-run-clumps-and-platforms.md` |
| ~~**Fire rune**~~ | **Implemented, not accepted** — `spell_circle.DEFAULT_RUNE` is `ELEM_NONE`; the palette veils any rune not owned instead of offering all of `ELEM_ALL`; the bull's reward grants fire (`Progress.grant_rune`) | `docs/plans/3.done/rune-lock-and-receiving.md` |
| ~~**Two bosses**~~ | **Implemented, not accepted** — bull and rooster both written and verified headless. Two screen fixes (the slam's fire ring, the phase-2 tell's shape) are unlooked-at, blocked by another session holding the editor bridge | `docs/plans/3.done/stage1-bosses.md` |
| **Three of water's four** | Only pouring works | `docs/plans/2.active/water-jump-and-escape.md` |
| ~~**Water in pit ①**~~ | **The row itself is gone — closed by the user's decision, seen on screen.** Reward-then-water order was correct (take the bull's reward, then the wall/water), but **the water never carried the player out** — 300s of pouring lifts them 0px, and an ordinary jump alone already cleared the step in 1.6s. ⚠ **The call was made — the escape is dropped and this row leaves the chain** (`3.done/burn-out-of-the-bull-room.md`, built) | `docs/plans/3.done/stage1-bosses.md` |
| ~~**The wood-wall lock is broken**~~ | **Not a problem — decided by the user.** A runeless blast does open the wall (`spell_sim.gd:633` ignites without `element`), but **the wall is on the far side of pit ①, and the only way out of the pit is the water the bull's death brings** ⇒ **you cannot stand in front of that wall without already holding fire.** **The lock is held by the map's shape, not by the ignition rule** | `3.done/stage1-map-layout.md` |
| ~~**…and that shape is being deleted**~~ | **Closed, and built.** Moving the wall into room ①'s east face puts it **on the near side of the pit**, reachable the moment you walk in — the bull's own fire (bolt range 480px vs. 15 tiles of room) and a runeless blast would both open it. **The fix**: `WOOD` is `rune_only` now (`burn-out-of-the-bull-room.md` §0) — only the fire rune's own trace or a fire-circle blast ignites it, never monster fire or an elementless blast. The lock moved from map shape to a rule, wood-wide, not door-only | `docs/decisions/the-door-burns-only-from-the-fire-rune.md` |
| ~~**The screen for receiving the fire rune**~~ | **The premise was wrong — the screen already exists.** `circle_window.gd:158-161` has always placed runes (pick from the palette → click the rune seat), so nothing has to be broken out of the three-pick. **Ownership was the only thing actually missing, and it is filled too now** (same doc — see the "Fire rune" row above) | `docs/plans/3.done/rune-lock-and-receiving.md` |
| ~~**An ending**~~ | **Filled — the chain's last square. Implemented, not accepted.** The rooster's death drops room ③'s east wall and stands an arch beyond it; walking into the arch opens the settlement screen, **with a clear title instead of the death one.** No second screen. Neither the arch nor the clear title has been looked at on screen | `docs/plans/3.done/gate-ending-to-game.md`, `docs/plans/3.done/run-end-settlement.md` |

**The chain has every square now — in code. Not one of them is accepted.**
`map → wood wall → pit → bull → fire rune → water out of the pit → rooster → gate` runs end to end, and
**the mobs and both bosses stand on it before you arrive** (`3.done/monster-placement-stage1.md`) ⇒ **the
chain is walked, not debug-keyed.**

**And that sentence was not true until the monster cap was fixed** — the spawn door was first-come-first-served,
so **a player who killed nothing on the left run filled the cap with trash and the bull was silently refused**,
taking the fire rune and everything behind it with it, with no error anywhere. It was live in the build while
this paragraph claimed the chain ran. The door now reserves the boss slots
(`3.done/left-run-clumps-and-platforms`) — **the fix is in the spawn door, not in the boss docs**, and it is
driven headless. ⇒ **The claim holds now; it is worth remembering it read as true for a while before it was.** **The one acceptance check this milestone has is "the user starts once
and reaches the end without getting stuck" — which only the user can run.** ~~The single row still open above
is water's other three (`2.active`)... and the reason zone ② is placed but unreachable~~ — **void.** Zone ②
is deleted, not merely unreachable (`3.done/burn-out-of-the-bull-room.md`), and stage 1 now has **no water
pour at all** — the pit's reward pour was removed with it, and room ③'s own pour (water's remaining three
axes, `2.active/water-jump-and-escape.md`) is still unbuilt, so it is no longer "a constraint on the ending",
just an open axis with nothing built against it yet.
⇒ **What is left of this milestone is a playthrough, not a build.**

**What was cut**: leveling and the three-pick · wiring the triangle circle · bolt speed · the shop · **town.**
~~**"All five are outside the chain" is no longer accurate** — "the screen for receiving the fire rune" is tied to the three-pick.~~
⇒ **Void.** The receiving screen is **the assembly window, which already places runes** — nothing has to be
broken out of the three-pick, and the three-pick shipped anyway (`3.done/levelup-and-three-picks.md`).
The rune work is **the lock, not a screen** → `docs/plans/3.done/rune-lock-and-receiving.md`.

~~**Cutting town has a price** — **there is nowhere to go when you die.**~~
⇒ **Paid.** The town's room and the loop are built (`docs/plans/3.done/town-room-and-fixtures.md`):
you start there, the departure gate builds stage 1, and dying sends you back with E instead of restarting in
place. **The loop closes.** What is still missing is what the town is *for* — points, materials, unlocks —
so the benches list state and spend nothing (`docs/design/town.md` carries the split).

## Prices paid knowingly

Things chosen with the price known at design time. "We didn't know" must never happen later.

1. **Code touching the grid is integer, forever.**
   Determinism is the premise, so `float` · `sqrt` · `sin` · `atan2` · `randi()` are unavailable.
   **Glyphs like home, spin and spread fall under this too.** Every new glyph crosses this wall.

2. **GDScript may not be enough.**
   Measured: native 5μs = GDScript loop 520μs (100×).
   When that day comes, move **only the grid loop** to GDExtension (C++/Rust) and leave the rest in GDScript.
   **Do not pre-empt it.** Move after it is actually slow.

3. **The grid has no scrolling.**
   A dungeon is wider than a screen. **Streaming sleeping chunks in and out of memory must be built** — while preserving determinism.

4. **v1 (the current `src/`) is discarded.**
   It was a prototype that confirmed the fun and the multiplayer potential, and it did its job. Keep the findings, rewrite the code.

5. **Blasts can go off screen.** (from choosing camera follow)
   The old contract was "the whole stage fits on one screen", because **"detonating out of sight reads as 'it didn't detonate'"** —
   v1 got burned exactly that way.
   **That reason hasn't gone away, but the number under it has been replaced.** It read "spread bolt range
   (40 tiles) exceeds the visible width (30 tiles), so firing horizontally lands off-screen in principle" —
   40 tiles was the **gravity-free drag ceiling of a `speed` 20 bolt**, and bolt speed has since come down for
   head-sprite visibility. Driven today: a generation 0 bolt reaches **12.8 tiles at 45°**, a spread bolt
   **4.8**, against a 15-tile half-screen. ⇒ **One bolt no longer leaves the screen; the spread chain
   (impact + 4.8 tiles ≈ 17.6) and cliff shots still can.** The price stands, as an edge rather than the norm.
   The live arithmetic lives at `src/sim/sim_tuning.gd`'s `DRAG_NUM`.
   What remains is **"at least my surroundings are always visible".**
   ⇒ If "it didn't detonate" comes back, **this is the cause.** It's one of zoom-out · shrink the stage · shorten the range,
   and **range is the magic-circle design's call** (a screen problem, not a GDScript performance one).
   **Performance was not the price** — full forest burn plus 10 blasts gave **0/711** dropped frames.
   Item 2 above (GDScript 100×) did not arrive early.

---

## TBD

What is written here is **not yet decided.** Do not fill it in by pretending to know.

- **Direction — varies per stage.** Do not pin "right" globally — stage 1 (theme: farm) goes right, but a stage
  descending diagonally is possible. Within one stage the direction is fixed.
- **Rune combination table** — nothing decided beyond water+fire = steam. **It is the fusion circle's prerequisite** — parallel and sequential need no table
- ~~**Circle types**~~ → **decided** (the three under "Circle — the frame"). **The max layer count is still TBD** —
  the deepest of the three is 2 layers, so that wall hasn't been reached (`docs/design/circle-art.md`, "the 7-layer problem")
- **The parallel-rune explosion constraint** — see "Glyph constraints"
- **Where a spell's numbers come from** — **half decided.**
  Decided: health 100 · base damage 10 · **rune, glyph and gear can all take part** (`character-damage-minimum`).
  **Undecided: how those three combine.**
  Combine as a multiplication chain and **commutativity kills order in the numbers** — this game's thesis quietly disappears there.
  Detail in `docs/design/circle-rune-glyph.md`, "multiplication kills order"
- ~~**Monsters** — types, behavior, water interaction~~ → **stage 1's are decided** (by the user).
  ~~Two trash mobs (pig · chicken)~~ **three — 돼지 · 늑대 · 닭** (the user assigned the wolf) · brainless
  movement, **plus jumping when blocked and pushing each other apart** · 20 at once · all natural laws apply
  — **source is `docs/design/monsters.md`**.
  **They stand on the map before you arrive now**, bosses included, so the stage is walked rather than
  debug-keyed (`docs/plans/3.done/monster-placement-stage1.md`).
  **Still TBD**: health and damage values · the midboss's (the bull that swallowed the fire rune) behavior · stages 2 and 3 monsters
- ~~**Dungeon generation — rooms or continuous**~~ → **decided as a two-tier structure** (by the user):
  **within a stage (chapter), a "room" is not a scene-transition unit.** One stage = one continuous scene —
  walkable throughout, no loading, no doors. A "room" is only **a conceptual zone** dividing it (a material-theme unit,
  e.g. the fields, canals and barn of a farm stage). **It was first wrongly decided as "room = independent scene + door
  transition" (Isaac-style) and reversed the same day** — the user did not want that room-by-room-by-room feel.
  **The boss room is the only exception.** The one place physically sealed by an actual gate — no other zone has such a boundary.
  **Between stages is a real transition** (the theme changes) — this is the only place price #3 (chunk streaming) could
  become a problem, and if one stage's size is finite (the user's sense: about 4 zones), existing chunk sleep may suffice.
  **How large one stage can get is still TBD** — grow it and price #3 returns.
  **Still TBD**: whether forks (physical branches) survive this continuous structure, what the Tab "map" shows
  (the whole stage or part — the user is still thinking), and how materials are distributed across zones
  (one dominant per zone vs evenly).

- ~~**Seed distribution · procedural generation**~~ → **Not doing it. The map is fixed** (decided by the user).
  **The map the user designed and drew is used as-is.** Stage 1 is already drawn — **300×48 tiles**
  (`terrain_map_generated.gd`, `MAP_W`/`MAP_H`). **This line has now been wrong twice** — it read 312×126,
  then 400×48 — because the size is counted in one place only, and that place is the baked file, not here.
  **It shrank because the left run was cut**: 100 columns of uniform flat deleted from the map itself, so
  the walk to the midboss stops being 30 seconds of unchanging ground (`left-run-clumps-and-platforms`).
  ⇒ **No seeds, no room composition.** The same terrain every run.

  **So the variation per run comes only from what you bring** — assembly (circle · rune · glyph) ·
  the level-up three-pick · drops. The GDD's thesis was always assembly, so this decision sharpens that axis.
  **The price is known**: from the second run on, **terrain holds no surprises.** "What's behind that wall" lives once.
  In exchange, **a player who memorized the route passing faster becomes skill.**

  **And level design is entirely by hand.** Three stages × 4 zones is a finite amount to draw, and that is
  **cheaper and more certain** than building and tuning a generator — but **the amount is fixed.**

  **`src/stage/`'s folder contract wobbles because of this.** CLAUDE.md pins that folder as
  "the shell — it won't survive into the real game", but **with a fixed map, `terrain_map_generated.gd` is real-game data.**
  The terrain baking tools (`tools/stage/`) likewise become **real-game tools.**
  ⇒ When and how to fix that contract is **TBD.** For now all that's known is that the placement is provisional.
- **Camera** — **single-player is decided: follow the character, stop at the stage boundary.**
  **Four-player is still TBD** — scatter and you can't see anyone's magic. Locked screen / tether / individual?
  **The price of choosing single-player follow is price #5 above.**
- **Final engine** — Godot is likely but not settled
- **Screen scale** — **2× at the default window (1920×1080)** (viewport 960×540, Nearest filtering).
  A 32px character appears at **64px on screen.**
  **This once read as 1× (viewport 1920×1080) and that differed from reality** — this line was corrected by reading
  `project.godot` directly. **A reference doc diverging from code is the most expensive lie there is.**
  **It remains a function of window size, not a constant** — `stretch/aspect="expand"` plus a fullscreen key means
  2560×1440 gives a **non-integer scale** like 2.67. Under Nearest, a non-integer scale makes pixel sizes uneven and
  breaks the silhouette.
  **Whether to force integer scaling is still TBD.** 32px probably hurts less than 16px, but **it wasn't measured.**
  Detail in **`character-sprite`**
