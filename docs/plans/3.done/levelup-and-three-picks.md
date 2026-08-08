# Leveling and the three-pick — the only door rewards come through

**Status**: done — **stages A–E built, verified by value · mutation · screen, and the user ran it and accepted it.**
**Acceptance 11 (the boss three-pick) was never in scope** — no bosses exist in code (see "Out of scope")
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

### **Accepted — the user ran the game and said 「다 잘된다」**

The user drove it themselves: killed monsters and watched XP rise, levelled up, pressed **P**, read the three cards,
picked one, chose a layer, and fired. **Items 1 · 2 · 3 · 4 · 5 · 6 · 7 · 7b · 8 · 8b · 8c · 8d · 9 · 10 · 12 are
closed** — by value, by mutation, by verify-look's eyes, and now by the user's.

**Item 11 (the boss gives a three-pick + research material) is NOT closed and was never in scope** — there are no
bosses in code. No slot was built for it either: a `grant_pick(reason)` with no caller is a false knob. **The day
`stage1-bosses` lands, it calls the same `grant_pick()` Stage B already built.**

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

---

# Implementation plan

**Read this first**: the doc above says "**Cheap. It doesn't touch the sim.**" **That is false and it was the first
thing this plan had to settle.** The dummy raises damage, damage is dealt by **a bolt**, and the bolt lives in
`src/sim/`. The doc's own line — "**damage actually reaches the sim**" — is the true one.
⇒ **Stage A is a sim change.** It is the biggest risk (acceptance 8), so **it goes first**, and it is verified
**before one line of new UI exists.**

## Structure — one new axis, folded into the id that already exists

### The question: is rarity a variant or a new kind

**Variant.** `glyph_defs.DEFS` gains rows. **Rarity does not become a second integer anywhere.**

```
GLYPH_SPREAD = 1                    ->   SPREAD_C = 1 · SPREAD_R = 2 · SPREAD_U = 3
GLYPH_BLAST  = 2                         BLAST_C  = 4 · BLAST_R  = 5 · BLAST_U  = 6
                                         DUMMY_C  = 7 · DUMMY_R  = 8 · DUMMY_U  = 9
```

**Why folded into the id and not carried beside it.** The alternative — the circle holds a parallel rarity list
and the bolt carries a second packed integer — was priced and rejected:

- `glyph_defs.gd`'s header says "**Shifting happens only inside these three functions.** Shift in two places and
  they will diverge." A parallel list makes it **six** functions, or three functions taking two integers each
- `_spread()` hands `rest` to eight children as **one integer assignment** (the file calls that "the whole of the
  GDD's hand-the-list-over"). A second list must be handed in lockstep — **that is the exact shape of "one gets
  fixed and the other doesn't"**
- The deferred queue (`_pend_*`) would grow a second column with the same lockstep requirement
- **And the decisive one — every consumer already carries the id.** The palette (`palette_layout.items_of`),
  the layer slots, `packed_glyphs()`, the fire command, `Fx.GLYPH_TINT`, the staff tip. Fold rarity in and
  **all of them follow for free.** Carry it beside and **every one of them needs a second argument**
  — that is the plan-contract question "if you add an axis, does every consumer follow?", answered by not adding one.

### The price, written down before it is paid

**The nibble ceiling becomes real.** `GLYPH_BITS` is 4 ⇒ 15 ids ⇒ **5 families, not 15 glyphs.**
Nine ids are used, six spare.

**This is not solved here and it must not be discovered later.** The answer is written now:
the day a **6th family** arrives, `Tuning.GLYPH_BITS` goes 4 → 6 (63 ids) and `GLYPH_MAX_LAYERS` goes 7 → 5
(6 × 5 = 30 bits, under the sign bit — `net_tables` already measures that inequality). Circles have 2 layers, so
5 costs nothing today.
⇒ **Stage A adds a net that goes red the moment `ALL.size()` passes the nibble.** Without it the 16th id is
refused by `pack()`'s range check and returns `GLYPH_NONE` — **which reads as "the glyph I socketed does nothing".**

### The second price — `max_per_circle` must count **families**, not ids

**This is the GDD's entire explosion defense and it breaks silently if missed.**
`spread, max_per_circle: 1` counted by id lets **common-spread + rare-spread** into one circle ⇒ 8 → 64 bolts.
`_launch` barks on the 32-projectile cap so it is not fully silent, but what the user sees is
**"most of my spread doesn't come out"**, and the cause is nowhere near the symptom.

⇒ `Glyph.count_of(g, id)` becomes `Glyph.count_family(g, family)`. **Two consumers, one function**:
`spell_sim._valid_glyphs` and `spell_circle._list_ok` (they already read the same table — that property must survive).

## `power_pct` — one column, and every kind reads it in its own natural place

**The doc asks for a third kind (modify).** It arrives, but the interesting part is that **rarity does not need
a per-kind mechanism.** One column on every row:

| kind | `power_pct` applies to | why that is the natural seat |
|---|---|---|
| **MODIFY** (dummy) | **the bolt carrying it**, at `_launch` | it is the bolt's own property from birth |
| **SPAWN** (spread) | **the children it spawns** | the parent already flew; only what it makes can change |
| **TERMINAL** (blast) | **the blast it makes** | there is nothing else it could touch |

**Base power is 100. Damage = `Character.DAMAGE_HIT * power / 100`, integer.**
Common rows are **100** ⇒ **stage A is behavior-neutral for every combination that exists today, and the whole
existing net suite must stay green.** That is the honesty check on the refactor.

### Why MODIFY is applied at launch and not at impact — this is load-bearing

A modify glyph that ran inside `_resume` (at impact) **cannot raise the damage of the bolt carrying it**, because
the direct hit is tested per tick during flight (`_notify_seg` → `body.hit_by_segment`) and has **already happened**
by the time the pipeline runs. Build it as a `_run_glyph` branch and you get the signature fake:
**the screen shows the glyph socketed and the number never moves.**

⇒ **`_launch` consumes the leading run of MODIFY glyphs off the list**, applying each one's `power_pct`, and stores
what is left in `_glyphs[i]`. `_resume` therefore never sees a MODIFY id — **no skip branch, no double-apply.**

**And the order still means something, for free**:

```
[dummy, spread]  ->  launch strips dummy  ->  the parent hits harder, the 8 children do not
[spread, dummy]  ->  parent normal  ->  spread hands [dummy] to 8 children  ->  each child strips it at ITS launch
```

**Both fire and spread go through `_launch`** — that file already pinned "Fire and spread go through the same
door. Normalize separately in each and only the 8 spread bolts get a different speed." **Same door, same reason.**

### What rarity does **not** change this round

**Spread's bolt count stays 8 at every rarity.** The GDD says "higher rarity spreads more" and the doc's TBD
repeats it — **it is deliberately not built, and the reason is integer determinism**:
`SPREAD_DX/DY` is `(±1,0) (0,±1) (±1,±1)` — **exactly 8 vectors, and there is no 10 or 12 that is even and
integer.** (16 exists — the 8 plus `(±1,±2) (±2,±1)` — but the angular steps go 26.6°/18.4°, i.e. **not even**.)
`src/sim/` bans `sin`/`cos`, so there is no cheap way in.
⇒ Rarity's spread axis is **`power_pct` on the children** instead: a rare spread throws **the same eight bolts,
harder.** It is measurable by value, it needs no new direction table, and it keeps one axis.
**This is a substitution, not a nothing — it is flagged to the user.**

**Blast radius is not scaled by rarity either.** `rd` and `ignite_r` live in `SIM_SIZES` under two contracts
(`ignite_r > rd`, `carve_r < rune_r`), both of which `net_tables` measures **per generation**. Multiplying them
by a rarity percent means re-proving both inequalities for nine combinations. **Not worth it for a skeleton.**

## Stages — five. Verification runs after each one

**Every stage below has a path to the screen.** No stage moves the sim without the screen following, and none
moves the screen without the sim following (CLAUDE.md's signature fake, both faces).

### Progress — Stage A is code-done and verified by value and by code. **The screen has not been looked at**

| Stage | State |
|---|---|
| **A** damage carries a power percent | **Done — value · mutation · screen all three.** Only the user's own eyes are left |
| **B** XP · money · level | **Done — value · mutation · screen all three.** Only the user's own eyes are left |
| **C** the draw | **Done — value · mutation · screen all three.** **One question open for the user — below** |
| **D** the pick window, step 1 | **Done — mutation · screen.** **One low-severity hole left, named below** |
| **E** the layer step | **Done — value · mutation · screen all three.** Only the user's own eyes are left |

**Measured (verify-run, headless, 18 byte-identical runs on a hash-bracketed stable tree).**
Pig `max_hp` 30, `DAMAGE_HIT` 10, both read from the tables:

| loadout | hits to kill a pig | damage per hit | bolt power |
|---|---|---|---|
| no glyph | 3 | 10 | 100 |
| `DUMMY_C` | 3 | 12 | 120 |
| `DUMMY_R` | 2 | 15 | 150 |
| `DUMMY_U` | 2 | 20 | 200 |

⇒ **acceptance 8 closed by value** (absolute counts on both sides, not a difference) · **8b** separates as
12 < 15 < 20 · **10** the pool is 9 ids with no holes, all packable and firable.
**Neutrality held**: first-tick segment power is 100 for every pre-Stage-A combination, and a pig with no glyph
still dies in 3 hits of 10.

**One caveat for whoever writes an 8b net elsewhere**: **hits-to-kill does not separate all three rarities** —
rare and unique both kill a pig in 2. The plan's own idiom for acceptance 8 is too coarse for 8b.
**Only damage-per-hit separates all three.**

**A real bug was found by mutation and fixed** — `count_family` walked the whole packed list while `_valid_glyphs`
had validated only the ids before the current one, so an unknown id sitting **after** a capped one crashed
`family_of` instead of barking. Reachable over the wire, not from the palette — which is the entire reason
that check exists.

**Six checks were green while measuring nothing** and were rebuilt until each one bit under mutation.
The one worth remembering: `_deferred_blast_keeps_its_power` never observed a deferred blast at all, because
`_remove`'s swap-remove pulls the last-fired bolt into slot 0 — **the boosted blast detonated inside the budget
every time.** `_pend_pow`, a named row in this plan's own risk table, had zero coverage.

**Two harness facts learned here, worth carrying past this doc:**

- **`tests/run_nets.gd:38` prints the pass count only on success**, so a red net contributes **0** to the headline
  total. One red net silently subtracted 394 from a reported "2255". **Pass counts are not a trend** unless you
  know which nets were red.
- **Hash-bracket each run, not the session.** A bracket wide enough to span another agent's edit-and-revert cycle
  reads a moved tree as unmoved. Two of twenty runs were void this way, and one nearly shipped as a false bug report.

**Seen on screen (verify-look, editor bridge).** Four of five pass; the fifth is Stage D's by the plan's own split:

- **the palette grew to 9 cells on its own**, laid out 3+3+3 by family. **No magenta** — every id has a `GLYPH_TINT`
- **rarity separates on the dark panel**: common muted grey-blue · rare violet · unique amber, checked magnified
  *and* at native size, because "does grey-blue survive on near-black" is exactly the call that fails quietly.
  **One for the user's eye**: the rare violet ring and the violet rune bead in the section above it are close in hue
- **MODIFY is its own silhouette** — a hollow diamond against SPAWN's six-ray burst and TERMINAL's filled disc.
  Being an **outline** is what makes it read as "touches neither trajectory nor list"
- **the damage number rises, both sides absolute**: key 1 shows **`-10`** (hp 30→20), key 6 (`DUMMY_U → BLAST_C`)
  shows **`-20`** (hp 30→10). **The screen agrees with the headless numbers** — the dummy reaches the sim and
  comes back out as a bigger red number
- **8c is half-closed.** `더미` renders in the HUD (`장착 더미 → 폭발`) but **the assembly palette draws symbols
  with no names at all**, so inside that window a dummy is marked only by color and shape.
  That is Stage A's own line — "the marking is in the name, the screen part finishes in D" — **but do not read
  today's palette as having closed 8c.**

---

### Stage B — and **the HUD had never been on screen**

**Acceptance 1 · 2 · 9 closed.** Pig 12 XP / 5 money, hen 6 / 3, read from the table by the nets, never as literals.
The award sits in `world_step`'s single death sweep beside the one `remove_at`, so **every cause of death pays** and
**each death pays once** (a corpse left 200 ticks moves nothing). The remainder carries over, and one award crossing
two thresholds grants **two** picks — the `while` loop's iteration count *is* `pending_picks`, so the count is measured,
not just the final state.

**`xp_for_level` was retuned twice, both times against measurement rather than arithmetic.** The doc's grounds are
"20-30 trash mobs → three level-ups", and **the population matters more than the formula**:

| threshold | pure pig — level 3 at | mixed pig+hen — level 3 at |
|---|---|---|
| `40 + 20*level` | kill 15 | — far too fast |
| `80 + 40*level` | kill 30 | **kill 40** — misses the range |
| **`60 + 30*level`** (shipped) | **kill 23** | **kill 30** |

⇒ **the first retune met the target only for pure pigs at the very top of the range.** A realistic mixed run gave two
level-ups, not three. Recorded because the same trap waits for every later tuning pass: **measure the mixed
population, not the convenient one.**

**The rate is stored as a record, not an assertion** (`_leveling_rate_measured_by_value`) — the same idiom as
`net_damage._spread_hit_count_is_recorded`. It is a real measurement: five separate mutations each moved it to a
different array, and it caught two that nothing else did.

#### **Three HUD labels had been painted off the canvas — one of them since long before this feature**

**The UI canvas is 960×540**, not 1920×1080 (`stretch/mode = "canvas_items"` blows it up 2×). Three rects were
authored in window coordinates:

| node | was | verdict |
|---|---|---|
| `HUD/Progress` | (1320,900)-(1904,980) | new, entirely off-canvas |
| `HUD/Health` | (1320,988)-(1904,1060) | **`체력 100 / 100` had never been visible in this repo** |
| `HUD/Stats` | (16,16)-(1800,420) | 840 px past the right edge — **looked fine only because a `Label` paints from its top-left origin** |

**The shape of the failure is the point**: `.visible == true`, the text string correct, and **nothing on screen.**
Every value check passed. Only eyes could see it.

**Why no net caught it.** The repo has a well-developed notion of the canvas — `encloses` is used in five places —
but **every one of them is on a constant** (`Fx.WINDOW_RECT`, `circle_layout` rects). **Not one was on a `Control`
node's actual rect.** So `WINDOW_RECT` is correct *because it is checked*, and the three labels were wrong *because
nothing checked them*. Two coordinate conventions coexisted in one scene, split exactly along that line.

And `_window_does_not_cover_the_health` **had been passing for free** — its rects are 408 px apart horizontally.
Its comment reasons carefully about one way it could pass for free (a zero-size rect) and guards it. **The guard
checked size and never position.**

⇒ **`net_render._hud_controls_are_inside_the_viewport`** now enumerates every `HUD` child (never a name list — Stage D's
window must not drop out silently), asserts `encloses` against the viewport read from `ProjectSettings`, and asserts
the loop actually ran. `CircleWindow` is skipped by a named list with the reason written down: **it is 0×0 outside the
tree, and a 0×0 rect at the origin is trivially enclosed** — this very bug class, nearly reintroduced by its own fix.

**Also unmeasured until now**: repointing `_progress_label` at `$HUD/Stats` was green across the whole suite, and it
would have made the XP readout invisible at *all* times. The shell half of a stage rests on nets that drive the real
`_update_hud()` / `_toggle_assembly()`, not on path scans that only prove a node exists.

**The level-up indicator was legible and too quiet** — same white, same size, appended to the status line after two
spaces. It is now its own node in warm gold (`#ffd140`), the only non-white text in that corner.
**It still says `(1개 대기)` — a count, not an instruction. Stage C must put the key in that string.**

**Layout ceiling, measured**: the assembly window ends at y 384 and the right-hand column starts at y 404 — **a 20 px
gap.** One more line in that column, or any growth in the window, closes it. Stage D should know this.

---

### Stage C — the rule holds. **A valid draw can still read as a bug**

**Acceptance 4 · 5 · 10 closed.** 60,000 seeded draws: zero duplicates, zero owned ids, all 9 reachable, never fewer
than 3 candidates with a full circle. Exclusion is **by exact id** — owning `SPREAD_U` still offers the common and
rare, which is the half a one-sided check would miss.

#### **The open question — three cards can all say 확산**

verify-look's first live draw was `확산(희귀) · 확산(일반) · 확산(유니크)`, and 2 of 19 draws were single-family.
**The draw is correct** — three distinct ids, and the rule permits it. **The reading is the problem**: `glyph_defs`
gives all three spreads the name `확산`, so the screen shows one word three times, separated only by a parenthesised
rarity.

**And for 확산 it is worse than cosmetic.** `max_per_circle` is 1, counted by **family** ⇒ a circle can hold
**exactly one 확산, ever**. Three 확산 cards are **three mutually exclusive options**, and the screen says none of it.

**Asked of the user; unanswered at the time of writing.** The cheap directions: let rarity carry a distinct name or
a card color (`RARITY_TINT` already does this in the palette), or bias the draw toward distinct families.
**Stage D draws the cards, so it lands there.**

#### A biased shuffle passed all 21 checks — the sharpest net hole so far

The shipped partial Fisher-Yates is correct: 200,000 draws, every id 33.13%–33.48%, worst deviation **0.60%**.
But `j := i + randi_range(0, pool.size() - i - 1)` → `j := randi_range(0, pool.size() - 1)` — **the classic naive
shuffle, a one-token edit anyone could believe equivalent** — was **green across every check**, while measuring:

```
naive:  SPREAD_U 47.6%  ·  dummies 29.6%      worst deviation 42.8pp
```

It survives because a swap always leaves a permutation — **no duplicates**, so distinctness can't see it — and every
id still appears, so reachability can't either. **Nothing asserted how often, only whether.**

⇒ a frequency band over 10k seeded draws now holds it. **The band and the sample size are one unit**: ±3.0pp is
**6.4σ** at 10k (sampling error 0.47pp) and the defect exceeds it 4.7×; at 1k the same band is 2σ and **stops biting.**

**Four more holes, all green until measured**: `drawn()` handed out the live `_drawn` array — and `_drawn` *is* the
open/closed flag, so a consumer that sorts or pops it corrupts pick state silently (**Stages D and E are exactly those
consumers**). P as a **one-way door** — opens a pick, never closes it. `Progress._rng` **bypassable entirely**, because
the nets seeded their own generator and never drove the field. And `dice_left`'s inertness check read **one file**,
missing `set("dice_left", …)` even inside it.

**One behavior wart, found by driving 480 Tab/P sequences**: P with nothing pending **closed the assembly window for
nothing** — it force-closed before knowing whether the pick would open. Check first, close second.

---

### Stage D — **the answer to the 확산 question is a number, not a color**

**Acceptance 3 · 6 (first half) · 8c · 8d · 12 closed.** The world runs behind the window; a click **inside** the
rect is swallowed and **outside** it fires and detonates — measured both ways, so "you can still shoot" is proven,
not assumed. The background is opaque (sampled `#0c0e15`). Declining leaves `packed_glyphs()` **byte-identical**
and does not consume the pick.

**The single-family draw reads correctly, and the reason matters**: three cards saying `폭발` are separated by
border color, the rarity word — and **the effect line, `위력 150% / 120% / 100%`.** verify-look's call: **the number
is what makes it unambiguous; color alone would have been thinner.** ⇒ **a card must always print what it does,
not only what it is.** (`일반`'s grey-blue is the weakest tier and sits near the window's own edge color — noted for
the user, not changed.)

**What is still not said on the card**: 확산's `max_per_circle` is 1 counted by family, so three 확산 cards are
**three mutually exclusive options.** Only Stage E can show that.

#### The same off-canvas bug, in its third costume

`PICK_RECT := WINDOW_RECT` with a comment claiming it "inherits every position guarantee `WINDOW_RECT` has".
**It inherited none** — moving it entirely off the 960×540 canvas was green across all 3211 checks. Three
independent reasons, each sufficient: no net named `PICK_RECT`; `net_pick` held a **hardcoded twin** of its size
(`Vector2(864, 372)`); and `HUD/ThreePickWindow` passed the enclosure check **for free**, because untreed it is
`Rect2(0,0,0,0)` and a zero rect at the origin is enclosed — **a silent skip in the check written one stage earlier
to stop exactly this.**

#### **Text scans do not measure values — three were written, all three were evaded**

The fixes were first written as greps over one file. Every one fell:

| Scan | Evasion that stayed green across the full suite |
|---|---|
| `_draw` uses the live count | count moved into `var n := 3`, plus a **decoy** `Layout.cards(size, drawn.size())` line |
| the window reads `Fx.PICK_RECT` | `position = Fx.PICK_RECT.position + Vector2(600, 500)` — still reads it, lands off-canvas |
| `mouse_filter` not written at runtime | written from **`stage.gd`** instead; the scan read only `three_pick_window.gd` |

**The last one was not a new lesson** — `dice_left`'s check had the identical defect one stage earlier and was
already widened to scan all of `src/`. **The corrected idiom existed in the repo and was not reused.**

⇒ **All three became measurements.** The move that unlocked it: **`_ready()` and `_gui_input()` are ordinary
methods, callable on an untreed `Control`.** Instantiate, set `size`, `call("_ready")`, and assert where the window
**actually lands** — no text pattern can see an arithmetic transformation of a value it only checks for the presence
of. `_draw()` genuinely cannot be driven (it needs a live font, `get_theme_default_font()` returns null untreed), so
**the pixels stay verify-look's — but the input handling and the geometry do not.**

#### `HUD/Stats` was left clipped under the window — and the fix changed shape

The pick window took the same 90%-of-screen rect as the assembly window but not its `_hud` hide, leaving a **32 px
strip** of every line — a column of two-character stubs down the left edge. **`stage.gd:320-324` already recorded
that exact look as measured and rejected.**

The first fix restored `_hud` at toggle time, and **the `취소` button escaped it** — that button calls
`Progress.decline()` directly, so the stage never learned the pick closed. ⇒ **`_hud.visible` is no longer written
at toggle time anywhere.** It is derived every frame:

```gdscript
_hud.visible = not _world.progress().is_pick_open() and not _circle_window.visible
```

**One writer, zero readers**, both terms independently held (dropping either goes red on its own side; `and`→`or`
goes red on both). On screen: **7156 frames sampled across 15 rapid toggles, 0 invariant violations**, and the
watchdog was inverted to prove it bites (291 violations when the derivation was frozen).

**Left open, deliberately**: nothing measures **when** `_update_hud()` runs. Moving it inside the
`if _world.frame(...)` branch is green across all 3330 — the nets call it by hand, so they cannot tell whether the
game calls it every frame or only on tick frames. Today's code is on the right side of it; nothing holds it there.
Severity is **~50 ms of HUD lag** (`TICK_DIVIDER = 3`), so it is sluggishness, not a wrong state.
**Stage E adds a second window to that same expression** — the more terms it carries, the less "lag" and "wrong
state" look different. The check that closes it drives `_physics_process()` itself and **needs fuller wiring than
the existing helper provides** (`_input` must be wired or the call aborts before reaching `_update_hud`, and both
variants then read green).

---

### Stage E — the loop closes. **The mechanics landed first try; the picture took four rounds**

**Acceptance 6 · 7 · 7b closed, and acceptance 8 re-hung at the top**: level up → P → pick → place →
**`packed_glyphs()` 0 → 9** → fire → **pig 3 hits of 10 becomes 2 hits of 20.** Absolute on both sides.
An occupied layer **replaces** — `glyph_list().size()` does not grow and the pushed-out glyph is gone, not
relocated. A rejected placement changes **nothing**: not the circle, not the counter, and `take()` is never called.

**The 확산 question from Stage C resolves here, and honestly**: holding `확산(일반)`, a second 확산 is **refused**
on the other layer and **replaces** on its own. That is what three mutually exclusive cards mean, and only the
layer step could say it.

**`take(glyph_id)` dropped the plan's `layer` argument** — placement happens through `place_glyph()` before `take()`
is reached, so `take()` only guards a stale id, clears `_drawn`, decrements. **Accepted**: the two failure modes a
layerless `take()` invites are both measured — *take without place* (12 red) and *place without take* (7 red).

**One sentence had to be corrected**: "nothing but `place_glyph()` places" is **false as written**. `_layers` has
**two** write sites — `place_glyph()` and `apply_preset()`, the debug-loadout door — **both gated by the same
`_list_ok`**. The property holds for this feature's path; the claim did not.

#### The picture is where the work was

| Round | What was wrong |
|---|---|
| 1 | **No circle was drawn at all** — an empty 608×286 box with two 14 px dots. Nothing said which was layer 1 |
| 1 | **The push-out was invisible** whenever the incoming glyph was TERMINAL — a dimmed diamond sits **entirely inside** an incoming disc (`RATIO` 0.8 vs 0.75). Geometry, not luck |
| 2 | **The afterglow emptied the panel** and kept the title `세 장 중 하나` — "one of three" — while the choosing was over. It read as **the window failing to close** |
| 3 | The order check was a **text scan**, defeated by an early `return` between the two lines it compared |

**Each fix was the previous stage's lesson turned around.** The push-out moved **beside** the incoming glyph rather
than under it, because *alpha cannot fix an occlusion*. The afterglow now **draws the circle with the glyph sitting
in its layer** — which also closed the older gap that nothing confirmed a placement at all. **The window stopped
previewing where the rule would refuse**, so the player no longer learns by being rejected.

#### The one-frame seam — two clocks, and the fix was to delete one

A watchdog over the two-term `Stats` expression caught **4 violations in 4 placements**, one per cycle: for one
render frame after the afterglow expired, the window was gone and `Stats` had not returned.

**Cause**: the countdown decremented in `three_pick_window._process()` (idle clock) while `_hud.visible` derives in
`stage._physics_process()`. **Every other close is input-driven, and input runs before physics** — so those land in
the same frame and the earlier 4178-frame watchdog had nothing to catch.

⇒ the decrement moved into `tick_confirm()`, called from `_physics_process()` **immediately before** `_update_hud()`.
**5 cycles, 0 violations in 1090 frames**, and the watchdog was inverted (377 violations when forced) so the zero is
not hollow.

**The pre-empt staying on the idle clock cannot reopen it**, for a reason stronger than inspection: it fires **only
when `pick_open` is true**, and in exactly that region the first term of `pick_open or _confirm_ticks > 0` dominates
the `or`.

#### **Text scans failed a third, fourth and fifth time — and the ceiling was never real**

| Scan | Evasion that stayed green |
|---|---|
| no stashed container | `var _pushed_out := []` — **untyped, in the file it reads, with the exact name it claimed to catch** |
| " | `Dictionary`, `static var` in a third file, and later **`@export var`** — an annotation moves the line off `^var` |
| `tick_confirm` before `_update_hud` | an early `return` **between the two lines** — text order untouched, `_update_hud()` simply stops running |
| `reset_stage` cancels the afterglow | never tested; the stated reason was that driving it would crash |

**The stated ceiling was three lines.** `reset_stage()` was said to need `_camera`/`_monster_view`/`_char`, none of
which the harness stood up — **three `root.set()` calls and it runs clean.** Wiring `_input` as well made
`_physics_process()` drivable, and **that closed the hole carried since Stage D**: gating the HUD tail behind a tick
now goes **red**.

**The probe deliberately drives only 1-2 frames** — `TICK_DIVIDER` is 3, so `_world.frame()` returns false and a
tick-gated `_update_hud()` **never runs at all**, which is the most visible form of the defect. **The boundary**:
nothing inside `_on_ticked()` is reachable this way, and `_on_ticked()` touches `_renderer`, which the helper still
does not stand up — **raising the call count will crash rather than measure more.**

⇒ the rule this stage earned: **`_ready()`, `_gui_input()`, `_physics_process()` and `reset_stage()` are all ordinary
methods, callable on an untreed node with enough wiring.** Only `_draw()` genuinely resists (no live font untreed).
**If you are grepping a file to prove a behavior, you have not measured it.**

#### Left for whoever is next in that file

The newly placed glyph draws **identically to the one already there** — the sentence carries `1층`, but the picture
does not point at what changed. A brief ring or flash on the placed layer would land the eye. Cheap; not a defect.

---

### **The tree is shared right now**

**Another session is building `stage1-bosses` in this same working tree**, concurrently: `monster_defs.gd` gained
`KIND_ROOSTER` and a `contact_damage` column, `net_monster`/`net_monster_sprite` grew mid-session.
**Stage B wants two columns in that same `monster_defs.gd`** (`xp`, `money`) ⇒ **do not start Stage B until that
is resolved with the user.** Three verification runs tripped `[race]` before this was noticed.

**Also pre-existing and not this feature's**: `net_water_rain` (3 red) from the user's uncommitted map-layout work
in `src/stage/`. And `net_tables._wood_clumps` was rewritten mid-session by someone — its gap check now returns
early when `clumps < 2`, so **`_closest_gap` never executes with today's map.** A measurement was retired; recorded
here, not fixed.

### Stage A — the socketed glyph changes the spell, by value

**The biggest risk, first, using only the assembly window that already exists.**
`palette_layout.items_of(KIND_GLYPH)` returns `Glyph.ALL` verbatim, so **the palette grows from 2 cells to 9 on
its own** — there is no new UI to build for this stage.

| File | What changes and why |
|---|---|
| `src/sim/glyph_defs.gd` | `FAMILY_*` · `RARITY_*` · `KIND_MODIFY` · 9 rows with `family` `rarity` `power_pct` · `ALL` · `count_family()` replacing `count_of()` · `family_of()` `rarity_of()` `power_pct_of()` accessors |
| `src/sim/spell_sim.gd` | `_power` parallel array + `_seg_pow` + `_fx_pow` + `_pend_pow`; `_launch` strips leading MODIFY and takes a `power` argument; `_run_glyph` branches on **family**, not id; `_spread` multiplies the child power; `_valid_glyphs` counts by family; `_remove` swaps `_power`; `_clear_notices` clears the two new notice arrays **in the same one place** |
| `src/sim/sim_tuning.gd` | `POWER_BASE := 100` and `POWER_MAX` (the bark ceiling) |
| `src/actor/body.gd` | `hit_by_segment` / `hit_by_blast` return **`int` power percent, 0 = not hit** (not `bool`) |
| `src/actor/character.gd` | `on_tick` takes the **max** of the two and passes `DAMAGE_HIT * pow / 100` to `take_hit` |
| `src/actor/monster.gd` | same; the `Character.DAMAGE_HIT` line becomes the scaled one |
| `src/actor/spell_circle.gd` | `_list_ok` counts by family |
| `src/view/fx_tuning.gd` | `GLYPH_TINT` gains the 7 new ids; `RARITY_TINT` (three colors); the MODIFY shape constants |
| `src/view/circle_window.gd` | `_draw_glyph` gains the **MODIFY shape** branch (it already barks on an unknown kind — that bark is what forces this) and rarity coloring |
| `src/stage/stage.gd` | `LOADOUTS` uses the new common-rarity names; **add key 6 = `[DUMMY_U, BLAST_C]`** so acceptance 8 is one keypress |

**Order inside the stage**: table → sim → actor → view → shell. The table first because everything below reads it.

**Why `max` and not "first one found"**: `if hit_by_segment(...) or hit_by_blast(...)` short-circuits today. Return
a number and "whichever the array order found first" silently decides the damage. **Take the larger and write it down.**

**Closes**: 8 · 8b · 8c (the marking is in the name — the screen part finishes in D) · 10 (the pool is 9)

**Nets** (`net_spell` · `net_circle` · `net_tables` · `net_damage`, plus the new checks):

- **`ALL.size() <= MASK`** — the nibble ceiling. Inversion: add a 16th id → red
- **every family has exactly one row per rarity** — a hole in the pool means a draw with no candidate
- **`power_pct` is strictly increasing common < rare < unique, per family** — the same idiom as `SIM_SIZES`
  monotonicity, and **its column name must be hand-written into the check** (`net_tables`'s own comment: a
  non-decreasing column was added once and 1038 checks stayed green)
- **`count_family` blocks common-spread + rare-spread in one circle** — inversion: count by id → red.
  **Measure the bolt count too**, not just the rejection: force the illegal list past the check and count 64
- **damage by value, absolute and not only relative.** How many hits kill a pig at common vs at `DUMMY_U`.
  **A/B alone catches "diverged", never "vanished"** — assert the absolute number of hits on both sides
- **the composition is a product**: `[DUMMY_U, DUMMY_R]` gives `100 * 200/100 * 150/100 = 300`
- **`[dummy, spread]` and `[spread, dummy]` differ** — parent buffed vs children buffed. This is the check that
  proves MODIFY is applied at launch and not at impact
- **a deferred blast keeps its power** — `_pend_pow`. Inversion: drop the column → the deferred blast falls to 100
- **every id in `ALL` has a `GLYPH_TINT` entry** — the missing color is magenta and silent otherwise

**Screen (verify-look)**: the palette shows 9 cells in 3 colors; the MODIFY shape is not the SPAWN or TERMINAL
shape; **the damage number over a monster rises** — `monster_view` derives it from the hp diff, so **that path
already exists and needs no work.**

### Stage B — XP, money, level

| File | What changes and why |
|---|---|
| `src/actor/progress.gd` | **new.** `xp` `level` `money` `pending_picks`. `src/actor/` because it is host-authoritative run state — **exactly the argument `spell_circle.gd`'s header already makes** ("the player's loadout is host-authoritative"), and it must not go in `src/sim/` where `randi` is banned (stage C needs it) |
| `src/actor/monster_defs.gd` | `xp` and `money` columns. **One more cell in an existing table — a variant.** (That file says "damage taken and fire DPS get no columns"; these two are different — they are **per-kind by nature**, a pig is worth more than a hen) |
| `src/actor/world_step.gd` | owns `Progress`; the death loop already builds `_died_*` — **award there, in the same one place**, or "who died" lives twice |
| `src/stage/stage.tscn` | **new `HUD/Progress` Label**, `mouse_filter = 2` |
| `src/stage/stage.gd` | draws XP / level / money / "레벨업" into it; `reset_stage()` reverts `Progress` |

**`HUD/Progress` must be a different node from `HUD/Stats`.** `Stats` **hides when the assembly window opens**
(`_toggle_assembly`) — put the level-up indicator there and **acceptance 2 ("it doesn't disappear") is false by
construction.** Seat it in the same band as `HUD/Health`, which `WINDOW_RECT` deliberately does not cover
(`net_render._window_does_not_cover_the_health` already measures that band).

**Provisional values** (see the table at the end): pig 12 XP / 5 money · hen 6 XP / 3 money ·
level N needs `40 + 20 * N` XP.

**Closes**: 1 · 2 · 9

**Nets**: killing a pig raises xp by exactly the table value (**read from the table, not the literal**) ·
xp crossing the threshold raises the level by exactly 1 and **the remainder carries over** ·
**two levels in one tick grant two pending picks** (the doc's TBD — see below) ·
`reset_stage` reverts all four · **the award happens once per death, not per tick** (inversion: move the award
out of the death branch → a monster at 0 hp pays every tick).
**Acceptance 9 is measured as a rate**: kill N pigs headless, assert 1 level per 7–10 kills.

### Stage C — the draw, on the HUD as text

**No window yet.** The three candidates are printed into `HUD/Stats`. That is a real path to the screen and it is
what this shell's HUD is for — it lets the **rule** be accepted before the **picture** is argued about.

| File | What changes and why |
|---|---|
| `src/actor/three_pick.gd` | **new.** `static func draw(owned: Array[int], rng: RandomNumberGenerator) -> Array[int]`. **Static and rng-injected so the nets call it headless and seeded** — the same idiom as `stage.camera_center` and `monster_view.hp_bar_rect` |
| `src/actor/progress.gd` | holds the drawn set + `open_pick()` / `decline()` / `dice_left` (**0, and no code path raises it** — the doc says leave only a slot) |
| `src/stage/stage_input.gd` | a key that opens the pick. **An input-map action (`open_pick`), not a raw keycode** — it survives into the real game, same as `toggle_assembly` |
| `project.godot` | the `open_pick` action. **⚠ the editor must be restarted before verify-look**, or the key is silently dead (`stage_input.gd` records that trap for Tab) |
| `src/stage/stage.gd` | prints the three candidates; **opening one window closes the other** (see Risk) |

**The draw rule, in one function**: candidates = `Glyph.ALL` minus **every id already socketed** (that is exactly
"the same rarity of something you already have never appears" — the id *is* the (family, rarity) pair, so the rule
is one `has()`), then pick 3 distinct at random. If fewer than 3 remain, **take what remains rather than repeat**
— and assert the pool is large enough that the branch is unreachable today (9 ids, ≤ 2 socketed ⇒ ≥ 7 left).

**Closes**: 4 · 5 · 10 (the "won't open" face)

**Nets**: 1,000 seeded draws — **no two of the three are ever equal** · **an owned id never appears** ·
**a different rarity of an owned family does appear** (inversion: exclude by family → this goes red, and that
mutation is exactly the one that turns 5 into "you never see spread again") · **every id in the pool is reachable**
over enough draws (inversion: an off-by-one in the index → one id never appears and nothing barks) ·
**a full-layer circle still yields 3 candidates**.

### Stage D — the three-pick window, step 1 (choose · decline)

| File | What changes and why |
|---|---|
| `src/view/pick_layout.gd` | **new.** Static card rects + `card_at()`, and the decline / dice button rects. **Static so the nets measure the same coordinates the drawing uses** — `circle_window.gd`'s header records that `Control` methods are unmeasurable and that judgment must therefore be pushed into the coordinate file |
| `src/view/three_pick_window.gd` | **new `Control`.** Draws three cards — **name · rarity · what it does · the dummy marking** — plus decline and a **disabled** dice button |
| `src/view/fx_tuning.gd` | `PICK_RECT` and the card colors. **One file for presentation constants** |
| `src/stage/stage.tscn` | the node under `HUD`, `mouse_filter` set in the scene **and not overwritten at runtime** |
| `src/stage/stage.gd` | `setup()` + open/close wiring |

**`mouse_filter` and the window rect are the whole of acceptance 3 and 12.** Copy `CircleWindow`'s contract exactly:
**STOP inside its own rect, and no full-screen `Control` anywhere.** The moment the screen is covered,
"you can still shoot with the window open" — the evidence that the world did not stop — **disappears**, and no
error is raised. Opaque background for acceptance 12; `fx_tuning.gd:467` already carries the user's
"there should be a background color, like a window opening".

**Closes**: 3 · 6 (the first half — the other two disappear) · 8c (the marking on screen) · 8d · 12

**Nets**: the three card rects **do not overlap and sit inside `PICK_RECT`** (inversion: widen a card → red) ·
`card_at()` and the drawing read **the same** rects · a **declined** pick leaves `packed_glyphs()` **byte-identical**
(acceptance 8d — assert the packed integer, not "it looks the same") · the pick window and the assembly window are
**never both visible**.

### Stage E — step 2 (the layer), and what gets pushed out

| File | What changes and why |
|---|---|
| `src/view/three_pick_window.gd` | a second step: after a card is picked the window shows the circle's layers and takes a layer click. **It calls `circle_layout` — that file is already page-agnostic** ("the palette does not know which page it sits on"), so it drops straight in |
| `src/view/pick_layout.gd` | the rect the circle occupies in step 2 |
| `src/actor/progress.gd` | `take(glyph_id, layer)` — consumes one pending pick |

**Placement goes through `spell_circle.place_glyph()` and nothing else.** That is the single source
(`spell_circle.gd`'s header), and it already enforces `max_per_circle` from the same table `fire()` reads.
**Do not add a second placement path here** — the doc's "there is no stash" is exactly the property that
"one more place holding a glyph" would destroy.

**What gets pushed out**: a layer that already holds a glyph shows **that glyph, dimmed, with the incoming one over
it**; clicking replaces. **There is nowhere for the old one to go and no code that could hold it** — that is
acceptance 7b, and the net measures it as **the absence of a container**, not as a behavior.

**Closes**: 6 · 7 · 7b

**Nets**: placing into an occupied layer **replaces** and `glyph_list().size()` does not grow ·
after a pick, `pending_picks` drops by exactly 1 · **`progress.gd` and `three_pick_window.gd` hold no array of
glyphs** (a text check for a held collection — weak, but it is the only automatic detector of "a stash grew back",
and it is written knowing that) · **the full round trip**: level up → open → pick → place → **`packed_glyphs()`
changed → fire → the damage number changed.** That last chain is acceptance 8 re-hung at the top level and is the
one check that dies if any stage regressed.

## Risk — what breaks silently

| Risk | Where it shows | What catches it |
|---|---|---|
| **`max_per_circle` counted by id, not family** | 8 → 64 bolts, then the cap barks with the cause nowhere near | stage A net, counting the bolts and not just the rejection |
| **MODIFY built as a `_run_glyph` branch** | the glyph is socketed and the number never moves — **the signature fake** | the `[dummy, spread]` vs `[spread, dummy]` net |
| **The new notice arrays cleared somewhere other than `_clear_notices`** | one notice lives forever; the same power replays | that function is the one place — `spell_sim.gd` already pins it |
| **`_pend_pow` forgotten** | a deferred blast falls back to power 100 — visible only when the 4-blast budget bites | the deferred-power net |
| **The level indicator put in `HUD/Stats`** | it vanishes the moment Tab is pressed ⇒ acceptance 2 false | verify-look; the plan puts it in the `Health` band instead |
| **A full-screen `Control` for the pick window** | firing dies, or "the world kept running" becomes unprovable | `CircleWindow`'s existing contract, copied; `net_render` measures the rect |
| **`project.godot` edited without an editor restart** | the pick key is dead and looks identical to a wiring bug | written into stage C; `stage_input.gd` records the same trap for Tab |
| **The nibble ceiling** | id 16 is refused by `pack()` ⇒ "the glyph I socketed does nothing" | the `ALL.size() <= MASK` net |
| **Power overflow** | 7 layers of 200% is 12,800 — inside int32, but a future 1000% column is not | `POWER_MAX` + a bark |
| **Both windows open at once** | clicks land in the wrong one; two `STOP` rects overlap | stage D net: never both visible |
| **A/B nets that only compare** | fold the buffed and unbuffed paths into one and `scan == scan` stays green — **39 checks did that once** | every damage check asserts an **absolute** number, not only a difference |

**Against CLAUDE.md's fake-code list**: the dice is a **count variable and a disabled button with no path that
raises it** — the doc asks for exactly that, so it is written as **visibly disabled**, not as a working button
that silently does nothing. The shop is **not built at all** (stage transitions do not exist); no slot, no constant.

## Out of scope — say it or builder expands into it

- **Acceptance 11 (the boss gives a three-pick + research material) cannot be closed by this doc.**
  **There are no bosses in code** — `stage1-bosses.md` is still in `1.ready`. No slot is built for it either: a
  `grant_pick(reason)` with no caller is a false knob. The day bosses land, they call the same `grant_pick()`
  stage B builds for the level-up path.
- **The midboss fire-rune branch** ("already carrying fire, it gives a three-pick") — same reason.
- **The shop and money spending.** Money accumulates and is shown; there is nowhere to spend it. That is the
  doc's own Boundary row.
- **Real glyphs.** The user pinned "add them later. I have no ideas right now." The dummy family is the pool.
- **Rarity changing spread's bolt count or blast's radius** — the reasons are above, under "What rarity does not
  change this round".
- **`GLYPH_BITS` widening.** The trigger and the values are written down; the net makes the day it is needed loud.
- **Do levels accumulate in town** — no town exists in code, so run-scoped is the only thing that can be built.

## Provisional values — chosen by this plan, **not by the user**

**Every one of these is a knob to turn while looking at the screen. None of them blocks implementation.**

| What | Provisional | Why this number |
|---|---|---|
| XP per kill | pig 12 · hen 6 | The hen is 10 hp and dies in one hit; the pig is 30 |
| Level threshold | `40 + 20 * level` (60 · 80 · 100 …) | At ~8 XP per mixed kill this is **7–8 kills per level** — the doc's "one level per 7–10 kills" |
| Money per kill | pig 5 · hen 3 | Nothing spends it yet; only the ratio has to be readable |
| `power_pct` — dummy | 120 · 150 · 200 | Unique doubles. Big enough that **the hit count to kill a pig visibly changes** (3 → 2), which is how acceptance 8 is measured |
| `power_pct` — spread | 100 · 120 · 150 | Applied to the children |
| `power_pct` — blast | 100 · 120 · 150 | Applied to the blast |
| Dummy families | **one**, three rarities | 9 ids total. Two dummies that both only raise damage differ by nothing but a number — that is the fake the doc warned about |
| Rarity colors | common grey-blue · rare violet · unique amber | The palette is dark; these three separate on it. **A verify-look call, not a net call** |
| Levelling twice before opening | **they stack** (`pending_picks` counts) | The doc's TBD. Stacking is the only option that cannot silently eat a reward, and the net measures the count |
| Dice per run | **0**, with no path that raises it | The doc: "a button slot and a count variable" |
