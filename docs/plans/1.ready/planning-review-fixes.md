# Fixing design-doc contradictions — 12 found by adversarial review

**Status**: ready — **the 8 doc-side items are applied. The remaining three are design decisions and can't be closed by docs**

| | What | State |
|---|---|---|
| 1 | The fire rune already exists | **Fixed** — the milestone table went from "build" to "lock" |
| 2 | The old "none every run" premise | **Fixed** — two places in the GDD, one in town |
| 3 | Who owns pit ①'s water | **Open** — added to the milestone gap table. **Who pours it must be decided** |
| 4 | Water missing from the chain diagram | **Fixed** |
| 5 | The wood-wall lock is broken | **Open** — added to the table. **Cause: the blast doesn't carry element** |
| 6 | The rune-receiving screen is on the cut side | **Open** — added to the table. Recorded as **break out only the minimum rune-receiving path** |
| 7 | decisions' reopen condition | **Fixed** |
| 8 | README ink | **Fixed** |
| 9 | Town's "0 runes" | **Fixed** — it's the reverse. Three are open for free |
| 10 | The inventory section collides with the assembly bench | **Fixed** — added the test line (growing during a run is an inventory; visible only in town is a list) |
| 11 | The midboss three-pick branch | **Fixed** — into the levelup drop table |
| 12 | Leftover "home" | **Fixed** — four in plans |

**One line**: as town, points and no-inventory landed, **the old premises were never deleted.**
And **the first-milestone table recorded the code state exactly backwards.**

**Found by an agent that never saw the conversation, reading only the docs.** That is the point —
whoever saw the conversation fills holes with "it must have been decided".

---

## High — the milestone won't close because of these

### 1. "There is no fire rune" is the exact opposite of the code

GDD first-milestone table: "there is no rune definition file at all. The quietest hole"

**Actually**: three runes already run.
```
sim_tuning.gd:280   ELEM_ALL = [ELEM_FIRE, ELEM_NONE, ELEM_WATER]
spell_circle.gd:48  DEFAULT_RUNE := Tuning.ELEM_FIRE      ← the starting kit is fire
palette_layout.gd:71 return Tuning.ELEM_ALL               ← always all visible in the assembly window
```

**The real hole is the reverse** — fire is socketed from the start and selectable any time, so
**"get fire from the midboss" is already meaningless.**
⇒ The work is **not creating a rune definition file but changing the starting rune to none and locking the palette.**

### 2. "You start with none every run" was never deleted

A premise killed by the point-based start, alive in three places.

- `town.md`, "A run's start" — "the starting kit is the same every run"
- `GDD.md`, "what is permanent is a pool" — "starting with none every run keeps the fire rune meaningful"
- `GDD.md`, "the three-pick shows only glyphs" — **the argument itself for excluding runes is a dead premise**

`town.md` **contradicts itself** (the assembly bench section says it's chosen with points).

### 3. No doc owns pit ①'s water

```
map:  "pit ① is a bedrock bowl whose only exit is water"
boss: "there is no water in room ①, so it's irrelevant for now"     ← asserts absence
water:"where it's used = right after stage 1's boss ③"              ← doesn't count the pit in scope
```

**It is the only way out after killing the bull, and none of the three docs owns it.**
Currently it takes an F press. ⇒ **The chain is broken at its second link and the gap table missed it.**

### 4. Water is missing a link in the milestone chain diagram

```
GDD:    map → bull → fire rune → wood wall → rooster → water escape → gate
Actual: … kill the bull for the fire rune → [water rises → ride it up] → wood wall → …
```

**Acceptance is judged on this one chain.** Missing from the diagram means missing from the gap list
⇒ **fill all five gaps and it still can't be walked end to end.**

### 5. The wood-wall lock is already broken by value while the milestone table shows green

`stage1-map-layout.md` measured: **three blasts get you through the wood wall. No fire rune needed**
(the blast at `spell_sim.gd:525-526` doesn't carry `element`, so a runeless blast ignited 159 cells).

**The GDD's "the midboss reward is the key to progression" is void in code.**
The only open item left in the table is "acceptance 3·4 unconfirmed on screen", so **reading the table alone, it looks done.**
That doc recorded that **no net measures it.**

### 6. "The screen for receiving the fire rune" is inside the chain and on the cut side

With no inventory, a rune's **placement must be decided on receipt.** The repo's only receiving screen is the
three-pick window, and the milestone cut the three-pick. With one rune slot, **the choice to push out none is unavoidable.**
⇒ "It's outside the chain, so it walks without it" does not hold.

---

## Medium — deletion scars and split names

### 7. `docs/decisions/no-inventory.md`'s reopen condition points at something deleted

It says "revisit when a bag slot opens" and **the bag was deleted** ⇒ **it never reopens.**
Ink's real reopen condition as recorded in the GDD ("it must take a form you don't carry") never reached that doc.

### 8. `design/README.md`'s unimplemented table still lists "gear · ink"

Ink was deleted. That table is the list of **"places that need a doc"**, so the next session goes off to design it.

### 9. `town.md`'s "0 runes" is wrong

**All three runes are open for free.** The reason the research bench is thin is the reverse, and
**everything already being open** changes the premise of the entire point design.

### 10. "There is no state of carrying it unequipped" collides with the assembly bench

The GDD's "there is no inventory" is worded **absolutely**, so "a UI listing unequipped circles/runes/glyphs"
reads as forbidden. **The assembly bench is exactly that list.** `town.md` re-pins it with
"don't build an inventory in town either", so **whoever builds the assembly bench can't tell from the docs which to follow.**

### 11. The midboss's "choice of reward" branch is absent from the implementation doc

The GDD decided "carrying the fire rune, it gives a three-pick", but `levelup-and-three-picks.md`'s drop table
has **only "midboss = progression key"** and it isn't in acceptance.
⇒ Implemented as written, the midboss **always gives only the fire rune.**

### 12. Three docs in `plans/` violate the "home" ban

Only ten places in the GDD were fixed. "Home" remains in `levelup-and-three-picks` and `stage1-map-layout`, and
**"does a level accumulate in town" doesn't turn up in a search alongside the GDD's identical TBD.**

---

## Fix order

1. **1 · 2** — delete the old premises and correct the milestone table. Everything else stands on this
2. **3 · 4** — put the pit's water in the chain and assign an owner
3. **5 · 6** — the wood-wall lock and the rune-receiving screen. **The milestone's scope may change**
4. **7–12** — doc cleanup. Cheap
