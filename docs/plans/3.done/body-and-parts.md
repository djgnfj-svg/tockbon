# Plan 3 — the body and its parts

**Status**: `3.done` — built 2026-08-15, **18 nets · 889 checks**, every mutation red. **Not accepted, and
`verify-look` has not run.** Part of [the grassland index](../1.ready/grassland-whole-loop.md); it followed
[hands and commands](hands-and-commands.md) and [the grassland field](../1.ready/grassland-field.md)
follows it.

✅ **Corrected for [the 2026-08-14 adversarial review](../../adversarial-review-2026-08-14-ko.md) and for
[hunting and the boss](../../design/hunting-and-the-boss-ko.md)** — `force_bonus()` is gone, the parts table
grew the four columns that were being read out of thin air (`HP`, `SELF_MUL`, `SELF_TIME`, `SUSTAINED`),
`Parts.Species` has `BOSS`, the dash survives **as a part** so no key goes empty, and every number is at the
×10 force scale. **This plan now inherits [plan 2 as corrected](hands-and-commands.md)** — read that first;
what it built is what this one moves.

**What it closes**: **the body changes.** Slots, a part table, cards that give nothing but parts, and the
horse's three parts actually worn and actually firing. After this plan a level-up alters what the hands can
do instead of nudging a multiplier.

---

## The slots

**Eleven, settled 2026-08-14** — six external, five internal. It was ten until the horse's lungs needed a
square and **the user ruled that eyes and gut both stay**, so breath got its own.

| # | Slot | Kind | Shows on the body as |
|---|---|---|---|
| 0 | head | external | a shape at the front anchor |
| 1 | torso | external | bulk on the front of the square |
| 2 | back | external | a shape at the rear anchor |
| 3 | forelimbs | external | lines at the front sides |
| 4 | hindlimbs | external | lines at the rear sides |
| 5 | tail | external | a line trailing the facing |
| 6 | eyes | internal | dot size — how smart a clone is |
| 7 | gut | internal | how much a clone brings home |
| 8 | bone | internal | corner sharpness — **base force**, the thing `F` halves |
| 9 | hide / fur | internal | outline and colour depth — defence |
| 10 | **lung** | internal | **breath — how long a movement active sustains** |

⚠ **Slot 10 was the day's one open question and it is closed.** Folding breath into `gut` was the cheap
answer and **the user refused it: eyes and gut both keep their jobs.** The internal count is therefore five,
not four, and `stages-and-evolution`'s *Ten slots* section is corrected rather than left to contradict this.
**Eleven is the number everywhere** — `RunResult.body_slots` is already sized by this table and by nothing else.

**External slots are what shows. Internal slots change drawing values rather than adding a picture** — muscle
thickens the body, fur puts an outline on it, hide deepens the colour, bone sharpens the corners. All eleven
read on screen and **the art bill does not move**, which is why the body is drawn by code
([the body is a line](../../decisions/the-body-is-a-line-drawn-by-code.md)).

## The part table

```gdscript
class_name Parts
extends RefCounted

## One row per part. This table IS the content of the game; everything else is machinery around it.
## Parallel arrays rather than dictionaries for the same reason the swarm is flat: a part that exists in
## two places diverges the day one is tuned.
##
## **Every column here exists because something reads it.** Four of them were added after review found the
## code reading columns the table did not have — an effect with no data source becomes `if part == X:`,
## and that is the sentence "this table is the content of the game" dying.

enum Slot { HEAD, TORSO, BACK, FORELIMBS, HINDLIMBS, TAIL, EYES, GUT, BONE, HIDE, LUNG }
enum Kind { PASSIVE, ACTIVE }
enum Species { NONE = -1, CROW = 0, HORSE = 1, BOSS = 2 }   ## plan 4 reads this; it does not redeclare it
enum { BITE = 0, DASH = 1, HORSE_LEGS = 2, HORSE_MANE = 3, HORSE_LUNG = 4 }

## ⚠ **Plain `Array`, not the packed forms this block was first written in.** Measured on 4.7.1:
## `const X := PackedInt32Array([1, 2, 3])` is a **parse error** — "Assigned value for constant isn't a
## constant expression" — and a plain array literal is fine, nests fine, and folds `deg_to_rad()` inside
## it. A `const` Array is read-only in 4.x, so immutability survives; element typing does not, which is
## why every read site casts. Rows are indexed by the enum above and every array is the same length; a net
## asserts that against the literal 5, because a short row here is an index error at a level-up.
const NAME := ["물기", "짧은 숨", "말 다리", "말 갈기", "말 폐활량"]
const SPECIES := [-1, -1, 1, 1, 1]
const SLOTS := [[],                                         ## BITE and DASH occupy nothing — see below
    [],
    [Slot.HINDLIMBS],
    [Slot.TORSO],
    [Slot.LUNG]]
const KIND := [Kind.ACTIVE, Kind.ACTIVE, Kind.ACTIVE, Kind.PASSIVE, Kind.PASSIVE]
const FORCE := [0, 0, 5, 5, 0]                              ## ×10 scale — a +1 part is invisible now
const HP := [0, 0, 0, 1, 0]                                 ## the mane's whole effect. **Read by Body**
const MOVEMENT := [0, 1, 1, 0, 0]                           ## what `space` will accept
const COOLDOWN := [0.5, 0.8, 0.0, 0.0, 0.0]
const BREATH := [0.0, 0.0, 0.0, 0.0, 2.5]                   ## added to BREATH_MAX while worn

## HOW AN ACTIVE REACHES SOMETHING IS PER PART (user, 2026-08-14). There is no single combat verb to
## design; each active carries its own shape, and the player binds whichever one to whichever key.
enum Shape { NONE, ARC, SELF }   ## ARC: a swing in the facing. SELF: changes the wearer, hits nothing
const SHAPE := [Shape.ARC, Shape.SELF, Shape.SELF, Shape.NONE, Shape.NONE]
const RANGE := [70.0, 0.0, 0.0, 0.0, 0.0]                  ## px from the body's CENTRE, not its edge
## ⚠ `deg_to_rad(70.0)`, NOT the `1.22` this line carried. Rounding plan 2's shipped arc down to two
## decimals is a silent retune wearing a refactor's clothes — both sides of the sim read whatever is
## written here, so nothing in the round can see it and only plan 2's tested value can.
const ARC := [deg_to_rad(70.0), 0.0, 0.0, 0.0, 0.0]

## SELF actives, both of them: a speed multiplier and how long it lasts. `SUSTAINED` means "while held,
## draining breath" — otherwise `SELF_TIME` is a one-shot burst on its own cooldown.
## ⚠ `SELF_MUL[DASH]` 2.8 is the deleted `Rules.DASH_SPEED` 560 ÷ `HOST_SPEED` 200. The move turns an
## ABSOLUTE speed into a relative one, so retuning `HOST_SPEED` now retunes the dash with it. Intended —
## a burst is "much faster than I walk" — but it is a behaviour change and nobody wrote the division down.
const SELF_MUL := [0.0, 2.8, 1.8, 0.0, 0.0]
const SELF_TIME := [0.0, 0.16, 0.0, 0.0, 0.0]
const SUSTAINED := [0, 0, 1, 0, 0]
```

⚠ **`RANGE` is measured from the body's centre and the number carries plan 2's value unchanged.** Plan 2
shipped `BITE` with `Rules.BITE_RANGE` 70.0 and `Rules.BITE_ARC` `deg_to_rad(70)`; this plan **moves those two
constants into the table row and deletes them from `rules.gd`**. Retyping them as 34 / 1.6 — which an earlier
draft of this file did — is a silent retune of the one attack the player has had since plan 2, disguised as
a refactor. `BITE_COOLDOWN` moves the same way, into `COOLDOWN[BITE]`.

⚠ **`Shape` is an enum with room to grow, not a switch over two cases.** The August build has one attacking
active, and the next habitat's parts are supposed to play differently — a projectile and a radius are the
two shapes already named in the design. **Adding one must be a row here, never a branch in the combat code.**

**Which slots a part takes is written on the part, not derived from a rule.** An adjacency graph over the
slots was raised and dropped as too complicated for what it buys.

### The August part table — three horse parts and the two you start with

| Part | 이름 | Slots | Kind | Force | HP | Movement | What it does |
|---|---|---|---|---|---|---|---|
| `BITE` | 물기 | none | ACTIVE | 0 | 0 | no | plan 2's forward cone, unchanged |
| `DASH` | 짧은 숨 | none | ACTIVE | 0 | 0 | **yes** | plan 2's burst, now a row instead of a hardcoded key |
| `HORSE_LEGS` | 말 다리 | hindlimbs | ACTIVE | 5 | 0 | **yes** | **갤럽** — sustained ×1.8 while held, drains breath |
| `HORSE_MANE` | 말 갈기 | torso | PASSIVE | 5 | **1** | no | **+1 to the host's maximum HP** |
| `HORSE_LUNG` | 말 폐활량 | lung | PASSIVE | 0 | 0 | no | +2.5s breath — how long 갤럽 sustains |

⇒ **These three horse parts are a set on purpose.** Legs are useless without breath and the mane is what lets
you stay in the fight you galloped into — so collecting horse feels like a build after three cards, not after
twelve.

⇒ **갤럽 is sustained, not explosive** — that is what `SUSTAINED` is for, and it is the whole difference
between the two movement actives now sitting side by side in the table. Binding 말 다리 to `space`
**replaces `DASH` and it is gone**, which is the trade the design wants: a burst you can spam, or a run you
have to breathe for.

### The two you start with

**Slot 0 (left click) holds `BITE` and slot 2 (`space`) holds `DASH`** — both parts in no slot, owned by
nobody, exactly as plan 2 shipped them. **The user was explicit: the basic attack is just the active you are
given first, and the square can be overwritten like any other.** So both are normal rows with
`SPECIES = NONE`, and a card that binds over them **replaces them and they are gone.**

⚠ **This is also what keeps the hands full across this plan.** An earlier draft deleted the dash and left
`space` empty until a horse leg dropped — planning principle 1, broken by a refactor.

## The body

```gdscript
class_name Body
extends RefCounted
## The host's own body. It lives on `World` as `var body := Body.new()`; a clone does NOT get one —
## a clone carries a single part index (plan 4's `Swarm.worn`), which is why this is not on `Swarm`.

var slot_part := PackedInt32Array()    ## eleven entries, -1 for empty
var slot_level := PackedInt32Array()   ## per slot, 1.. — the part's level, not the run's
var bound := PackedInt32Array()        ## three entries: which PART id fires on left / right / space, -1 = empty
var bound_cd := PackedFloat32Array()   ## three entries, ticked down by step()
var breath := 0.0

func step(dt: float) -> void                     ## cooldowns, breath drain and regen
func wear(part: int) -> Array                    ## returns the part ids that were digested
func can_bind(part: int, key: int) -> bool
func bind(part: int, key: int) -> bool
func fire(key: int, aim: Vector2) -> bool        ## false when empty, on cooldown, or out of breath
func hp_max(level: int) -> int
func breath_max() -> float
```

⚠ **`bound` and `bound_cd` are MOVED here from `Swarm`, not invented here.** Plan 2 put them on `Swarm`
because no `Body` existed yet and said so in as many words. Moving them means `src/sim/actives.gd` is deleted
outright — its three-value enum is replaced by the parts table — and every reference in `main.gd`, the panel
and the nets re-points at `world.body`. **Grep for `actives` and `swarm.bound` before declaring this done.**

⚠ **`bound` holds PART ids, not slot indices, and the first draft had it holding slots.** It cannot hold
slots: **`BITE` and `DASH` occupy no slot** — they are the actives you are handed, not things worn
([why](../../decisions/every-key-is-a-square.md)) — so slot-indexed binding has nowhere to put the two
actives every run starts with. **Written as slots, this plan does not compile.**
⇒ Digesting a part therefore means **scanning `bound` for that part id and clearing it**, which is three
comparisons and needs no back-pointer.

### Force is written, never derived

⚠ **There is no `force_bonus()`.** `wear()` does `swarm.force[0] += Parts.FORCE[part]` and **digesting does
`swarm.force[0] -= Parts.FORCE[part]` in the same call** — see
[force is stored, not derived](../../decisions/force-is-stored-not-derived.md). A derived bonus is either
double-counted (`force[0] + force_bonus()`) or a pure function nobody calls, and **the missing subtraction is
the version that ships**: every overwritten part leaves ghost force behind, and `F` then multiplies it.

**A net asserts the round trip**: wear a part, wear over it, and `total_force()` is back where it started plus
the new part alone.

### Wearing is irreversible and it can hurt

**This game has no bag, only a body.** All of it follows from refusing to build an inventory:

- **A new part in an occupied slot replaces the old one and the old one is digested** — not stored, not
  listed, not recoverable
- **A multi-slot part is evicted whole the moment any one of its slots is claimed**, and its other slots are
  left **empty**
- **Levelling only happens on the same species' same part.** `말 다리 Lv2` comes from another horse
- **When a digested part was bound to a key, that binding clears.** The key goes empty and the panel says so.
  A binding pointing at a part that is no longer worn is the kind of dangling index that reads fine and fires
  nothing
- **Digesting subtracts its force and its HP.** Both, in the same call as the removal

⇒ **A small part can cost a big one.** That is the point, and the user chose to keep it: without it there is
never a reason to refuse a good card.

## Cards give parts and nothing else

**`src/sim/cards.gd` is rewritten.** Plan 2 already deleted `SPLIT_1` and `SPLIT_3`; what is left is
`HOST_SPEED`, `HOST_BITE`, `CLONE_BITE`, `SENSE`, `DASH`, `TOUGH` — **every one of them is deleted**, and the
five multipliers they moved go with them.

⚠ **The multipliers live in more files than the card table.** `swarm.gd` reads `host_speed_mul`,
`host_eat_mul`, `clone_eat_mul`, `sense_mul` and `dash_cd_mul` across **ten lines** — the deletion list in the
first draft named `cards.gd` and `world.gd` and missed the file that actually uses them. Also
`net_cards.gd:60-74`, which exists precisely to prove those multipliers reach behaviour.

- **Three cards, as today.** Each names a part
- **A card for a part already worn is a level-up of that part** and says so on the face: `말 다리 → Lv2`.
  ⚠ **A level has to DO something**: `Lv2` adds **+5** to that part's effective `FORCE` and takes `10%` off
  its `COOLDOWN`. **Assert both with literals** — without a stated effect the net can only assert the number
  went up, and a no-op implementation stays green while the acceptance question — *does a card feel like a
  decision* — cannot be answered
- **The pool is rolled from what has been eaten.** A horse part cannot appear before a horse has been eaten.
  **This is the only lock on the card pool** — the price was deleted for being a second one on the same door
  ([why](../../decisions/card-price-removed.md)). ⚠ **It is not the only lock in the game**: the drop roll on
  a corpse is a different door and it is plan 4's
  ([parts drop by chance](../../decisions/parts-drop-by-chance.md) — two locks, and this is one of them)
- ⚠ **An empty pool must not freeze the game, and today it would.** `World::step()` refuses to step while
  `pending_levels > 0`, and the first level arrives long before the first horse. **Levels BANK**: with no
  card to offer, `pending_levels` keeps counting and the sim keeps running; the cards appear the moment the
  first horse is eaten, and they arrive as a stack. **That cascade is the rhythm the GDD already asks for**,
  and it costs one condition. **This is check 14 and it was missing from the numbered list while the prose
  demanded it** — failing it *freezes the game*, which is loud in play and completely silent in the nets
- **The level's force payout is unchanged.** Plan 2 made `_grow()` add `FORCE_PER_LEVEL`; cards do not touch
  force except through the parts they give
- **There is no skip.** Three cards, take one. The decision the design wants is *which*, not *whether*

### Species trait — filling slots from one species

**Going all-in buys a trait** (design doc). With one species in the August build, there is exactly one trait
and it is a placeholder:

> **말 특성** — wear `HORSE_TRAIT_COUNT` horse parts and 갤럽 stops draining breath.

**Nothing about traits is settled** and the doc says so. **Ship this one, marked as a placeholder in the
code comment**, because a trait nobody can reach is not testable and the user asked for traits in the August
build (2026-08-14).

## HP grows with the body

**The user, 2026-08-14: HP keeps rising through levels and parts.** So:

`hp_max(level) = Rules.HOST_HP + level * Rules.HP_PER_LEVEL + sum(Parts.HP[p] for p worn)`

`HOST_HP` (3) stays the floor. **Healing is not in this plan** — raising the maximum raises current HP by
the same amount, and there is no other source. Whether damage is ever recovered is open.

⚠ **`hud.gd` draws hearts with `maxi(world.host_hp, Rules.HOST_HP)`, which is wrong the moment the maximum
grows** — it reads the *current* value as the ceiling, so a damaged host with a mane loses a heart off the
row entirely instead of showing it empty. **It becomes `world.body.hp_max(world.level)`** in this commit.

⚠ **There is no separate "defence" number.** The first draft had the mane give *+1 defence: one extra
contact* **and** feed the HP formula, which is the same effect counted twice, and then asked the panel to
show three numbers. **One number: HP.** "One extra contact" and "+1 max HP" are the same sentence, and the
panel shows **force and HP**, not force, HP and defence.

## Drawing the body

`src/view/field_view.gd` gains a `_paint_body(...)` hook, and **the hook is what the net asserts** — not
`_draw()` running. `CLAUDE.md`: Godot refuses to override a native draw call, and counting the call measures
the engine, not the picture.

- The body stays a rounded square drawn by code; **each external part adds a line or a shape at its anchor,
  in the host's own colour**
- **Internal parts change values, not pictures**: corner radius, outline width, colour depth, dot size
- Every literal — anchor offsets, line widths, corner radius — goes in `src/look.gd`. **One file, measured**:
  scattering them once meant the power doubled and zero things changed on screen

## The `Tab` panel, filled

Plan 2 shipped it with eleven empty slots and three working key rows. Now: the slots show part names and
levels, the rows show `Parts.NAME[bound[i]]`, and the host's **force and HP** sit beside them. Binding is
click-slot then click-row, and `space` refuses anything without `MOVEMENT`.

**`RunResult.body_slots` is filled here too** — `Run::_snapshot()` writes `Parts.NAME[...]` (or `""`) for each
of the eleven. `run-shell` says twice that plan 3 fills it, and the first draft of this plan never mentioned
the field; the ending's eleven squares would have stayed empty forever with every check green.

## Numbers

| Constant | Value | Why |
|---|---|---|
| `HP_PER_LEVEL` | `1` | small, so a part's +1 still reads |
| `BREATH_MAX` | `2.0` s | 갤럽 without lungs is short enough to want lungs |
| `BREATH_REGEN` | `1.0` /s | full recovery in about the time it takes to re-engage |
| `HORSE_TRAIT_COUNT` | `3` | all three horse parts — the whole table, so the trait is reachable |
| `PART_LEVEL_FORCE` | `5` | one level of a part is worth half a part, at the ×10 scale |
| `PART_LEVEL_COOLDOWN` | `0.9×` | ten percent, compounding |

**Gallop's ×1.8, the dash's ×2.8 / 0.16s and every `BITE` number are in the parts table, not here** — they
are properties of a part, and a part's numbers living in `rules.gd` is the same value in two places.

## Nets

New `tests/nets/net_body.gd` and `tests/nets/net_parts.gd`; `net_cards.gd` is rewritten.

⚠ **Three files outside this plan's own list break here**, all found by review:

- **`src/view/card_panel.gd`** reads `Cards.TITLE[card]` and `Cards.DESC[card]`, keyed by card ids this plan
  deletes. The card face also has to render `말 다리 → Lv2`. **Rewrite it in this commit**
- **`tests/nets/net_hunt.gd`** calls `try_dash()`, which becomes `body.fire(2, aim)` — and `net_hunt` is not
  rewritten until plan 4. **It goes red for the whole of plan 3 unless those lines are fixed here.**
  A red net that everyone has agreed to ignore is how a real one gets ignored too
- **`tests/nets/net_paint.gd`** finds the host by `r >= Look.HOST_RADIUS` and counts `_paint_cell` calls.
  **Cutting `_paint_body` out of `_paint_cell` reddens both**, and this was the file the "two files break"
  count missed

**Every check names the mutation that must redden it.**

1. Wearing a part into an empty slot: the slot holds it and `swarm.force[0]` rises by exactly `Parts.FORCE`.
   *Mutation: drop the `+=`*
2. Wearing over an occupied slot returns the old part as digested, it is **not** anywhere in the body, and
   **`force[0]` is back to base plus the new part alone**. *Mutation: drop the subtraction — the ghost-force
   bug, which `F` then multiplies*
3. A multi-slot part evicted by a claim on one of its squares leaves **every** other square it held empty
4. A digested part that was bound to a key clears that binding — assert the key fires **nothing** afterwards,
   **by driving `fire()`**, not by reading the array
5. The same part again is `Lv2`, a different species' same-slot part is a **replacement**
6. `Lv2` is worth the literals: force +5 and cooldown ×0.9, **measured by firing** — time the second shot,
   do not read `COOLDOWN`. *Mutation: make the level a no-op*
7. `space` accepts `HORSE_LEGS` and `DASH`, refuses `HORSE_MANE`. **And binding 말 다리 over `DASH` leaves
   `DASH` gone** — assert the burst no longer fires
8. Card pool contains no horse part until a horse has been eaten; contains one after
9. `Cards` offers **only parts** — assert every offered id resolves in `Parts`, and that `Swarm` no longer
   carries any of the five `*_mul` fields
10. `take_card` never changes `swarm.count` **and never changes `force[0]` except through the part it gave**.
    *A/B comparison catches "diverged", never "vanished"* — assert a card was actually consumed
11. Wearing all three horse parts sets the trait; wearing two does not. **Then drive 갤럽 and assert breath
    does not fall** — the trait firing, not the flag being set
12. `hp_max` with level 3 and a mane is the **literal** 7, not a formula re-derived in the net. And the HUD
    draws seven hearts for it — captured at `_paint_text`/`_paint`, not grepped
13. ⚠ **Driven, and not A/B**: `_paint_body` is called with **literal** values per configuration — a bare
    body's corner radius, and a bone-wearing body's corner radius, each pinned. *"The arguments differ" is
    exactly the comparison that lets five internal slots change nothing on screen and stay green*, which is
    how a doubled power once changed zero pixels
14. **Three levels with an empty pool and the world still advances** — `elapsed` rises, `pending_levels` is
    3, and the moment a horse is eaten three cards appear. *Mutation: keep `World::step()`'s unconditional
    `pending_levels` guard. This one freezes the game*
15. Breath: 갤럽 held past `breath_max()` stops accelerating; assert the host's speed **was raised** and then
    dropped back to base. *A loop whose condition is false from the start never runs the check*
16. `RunResult.body_slots` has **eleven** entries after a run and the worn part's name is in the right index.
    *Mutation: leave `_snapshot()` alone*
17. Every array in `Parts` is the same length as `NAME`. A short row is an index error at a level-up

---

## Built 2026-08-15 — 18 nets · 889 checks · 1.7s

**The plan named 17 checks and the build needed 889** (baseline before it: 514). That is plan 1's ratio
again, and the index predicted it in writing. All 17 are in and every one of them reddens under the
mutation it names.

### Six things the build measured that this plan had wrong

1. **`const PackedInt32Array([...])` does not parse on 4.7.1.** The part table above is written in the
   packed form and it is a parse error — "isn't a constant expression". Corrected in place. A `const`
   Array is read-only either way; what is lost is element typing, so every read site casts.
2. **`ARC` was written `1.22` and plan 2 shipped `deg_to_rad(70)`.** Corrected in place. This is the exact
   shape the plan's own ⚠ warns about, one column over from where it was looking.
3. **`Body` cannot reach the world.** `wear()` writes `swarm.force[0]` and `fire()`'s ARC branch needs the
   food grid, the host's position and `eat()` — all on `Swarm`, none on `Body`. `World.setup()` wires
   `body.swarm`. There is deliberately **no back-pointer to `World`**: `World` holds `Body`, so one would
   be a RefCounted cycle that never frees.
4. **A sustained active has no input path through `fire()`.** The shell polls the just-pressed edge, and
   갤럽 is "while held" — wired to the edge it is a one-frame gallop, which reads as a dead key. `Body`
   gains `held`, three entries the shell writes every frame from `is_action_pressed`, and `fire()` returns
   **false** for a SUSTAINED part on purpose. See [the sustain is held, not fired](../../decisions/the-sustain-is-held-not-fired.md).
5. **The sentinel could not stay 0.** Plan 2's `Actives.NONE` was 0; `Parts.BITE` is 0. Carried across
   unchanged, "holding 물기" reads as "holding nothing" — and it compiles. `-1` instead, which is also a
   **legal GDScript index**: `Parts.NAME[-1]` returns 말 폐활량 rather than erroring, so every read tests
   `>= 0` first.
6. **Removing `World::step()`'s guard is six behaviours, not one.** The guard is the first two lines of
   `step()`, so an unspent level also froze the food, the ecosystem, `host_grace` and the spawn timer.
   Banking means the ecosystem is **live** while a stack of cards waits. And `_grow()`'s
   `offer.is_empty()` stopped being a sentinel and became a per-frame re-roll — it reads `species_eaten`
   now.

### Two more the plan simply did not decide, and the build did

- **`BITE` and `DASH` are not in the card pool.** They are the actives you are handed, not things offered.
  The filter is `SPECIES >= 0`, so there is no second list to maintain — and it is what makes the opening
  pool genuinely empty, which is the state check 14 exists for.
  ([why](../../decisions/the-given-actives-are-not-offered.md))
- **Exactly one sustain runs at a time, the fastest one held.** Two movement parts on two keys is a state
  the player can reach; summing or multiplying is a stacking rule nobody chose, and taking the first held
  key makes the answer depend on key order.

### Ten fake greens, found after the round was already green

Four read-only adversarial passes ran against a green round of 811 and found **ten holes that a mutation
confirmed**. Every one is now closed and the round is 889. The pattern is one sentence long: **the plan's
own fix was applied to one value and not to its siblings.**

- `_paint_body`'s four internal values were pinned as **arguments**. Only `corner` was chased through to a
  pixel. Emptying `_paint_outline`, `_paint_dot` or `col.darkened(colour_depth)` left the round green —
  the hide slot and the eyes slot moving zero pixels with every literal in check 13 passing.
- **All six external slots** could stop drawing at once (`_has()` → `false`, green). Check 13 asserted that
  the slot array *arrived*, never that anything was drawn from it. This is the plan's own acceptance
  question — *did the body visibly become a horse* — sitting outside every assertion in the round.
- **`main.gd`'s one line writing `Body.held`** was unmeasured, because every net supplied `held` by hand.
  갤럽 could be deleted out of the real game, green. `CLAUDE.md`'s "wiring a node by hand in the net hides
  the line that wires it in the shell", applied to a **poll** instead of a node.
- **`breath_max()` was measured as a pure function** and had exactly one behavioural consumer (the regen
  cap). Capping at `Rules.BREATH_MAX` instead left 말 폐활량 a no-op card, green.
- **"There is no healing" was stated twice and measured nowhere** — every check that read `host_hp` after a
  level did it from full health, so a full heal was arithmetically indistinguishable.
- **The body panel's HP ceiling** was only ever read at level 0 with an empty body, where `hp_max(0)` is
  exactly `HOST_HP`. It could print a constant 3 forever. The identical defect this plan fixed in
  `hud.gd`, one file over.
- **`hp_max()`'s multi-slot guard** was unreachable, and so were `breath_max()`'s and
  `_recompute_traits()`'s — found only by re-measuring the whole table rather than the row under argument.

⇒ **A spy on a hook sees the hook, never the native call inside it.** Emptying `_paint_dot` with the whole
argument chain closed was still green. `net_draw_leaf` now scans `field_view.gd` **per function** with a
call-count per name, and carries four cases that fail the scanner itself.

## Acceptance

**The user plays and reports whether a card feels like a decision** — whether refusing a good part because of
what it would evict ever happened, and whether the body visibly became a horse.

⚠ **Nothing here is accepted.** Looking has now happened — below — but that is an agent looking, not the
user playing, and the two questions above are still unheard.

## What looking found, 2026-08-15 — six defects the 889 checks did not see

**There was no godot-mcp bridge in this session** (zero `godot` node processes), so the game was made to
screenshot itself: `tools/look/capture.gd`, seven frames, windowed, quitting on its own. That tool is the
bridge-less half `CLAUDE.md` names in one line and nothing had implemented.

⇒ **The first pass photographed the wrong thing and said nothing.** `cam.zoom` was set from outside and
`_apply_zoom()` rewrote it from its own `_zoom` before the shot, so the "close-up" came back at play scale —
the one picture that cannot answer the acceptance question. Silent, and it reads as the zoom simply having
no effect. **The instrument needed inverting before the subject did**, one more time.

1. **말 갈기 draws nothing the eye can find, and it deletes the light doing it.** `PART_TORSO_ANCHOR` 0.12
   with `PART_TORSO_BULGE` 0.74 puts it **entirely inside the body's silhouette**, in the body's own colour
   lifted 0.22 — and it paints over `_paint_cell`'s overhead highlight, **the GDD's one hard art rule**
   ("lit from one direction for every body in the scene"). It becomes legible only when the HIDE slot
   darkens the body around it, and **no card in the August table can fill HIDE**. So one of the two
   external parts that exist draws, in practice, nothing.
   ⇒ `CLAUDE.md`'s own measurement, re-earned: **on a top-down body, only what sticks out reads.**
2. **The ending's eleven slot labels overflow their squares.** `FONT_SLOT` 12 against `SLOT_SIZE` 38 —
   말 폐활량 runs clear past its border. Four Korean glyphs do not fit and nothing clips them.
3. **The heart row has no cap and no wrap.** `hp_max` rises one per level forever; at banked 400 it drew
   about thirteen hearts marching toward the middle of the screen. It runs off the edge, not off a row.
4. **Breath reaches the screen nowhere.** Not in the HUD, not in the `Tab` panel. 갤럽 is gated on a
   resource the player cannot see, and **말 폐활량's entire effect is invisible** — a card whose face says
   nothing and whose effect shows nothing. The plan asked the panel for force and HP and got exactly that;
   this is the plan being complete and the screen still being wrong.
5. **A card is a name on a large empty rectangle.** `Cards.DESC` was deleted and nothing replaced it, so
   `말 다리 → Lv2` fills the top eighth of a 260×300 card and says nothing about what changes. **The
   acceptance question is "does a card feel like a decision"** and the card carries nothing to decide on.
6. **The limb pair paints over the hide outline**, cutting the silhouette that outline exists to draw.

⇒ **And three of the five internal slots — BONE, HIDE, EYES — have no part in the August table at all**, so
their drawing is unreachable in play and only a net has ever driven it. Forced on by hand, **the eye dots
are the most legible thing the whole system adds** and no card can grant them.

### What is the user's call, not a defect

- Two bars perpendicular to the facing, from 0.8r to 1.6r out, are what 말 다리 looks like. They read as
  **pegs**, not legs. Whether that is enough is an art judgement, and this repo decides those by looking at
  candidates, never by discussion.
- Whether the body, wearing everything August has, "visibly became a horse."

## ⚠ The acceptance above cannot be run until plan 4

**A real run today offers zero cards.** The pool is locked on `World.species_eaten` and **nothing in the
tree ever appends to it** — plan 4 is what puts a horse on the field and a corpse under it. So levels bank
forever, the card panel never opens, and *"does a card feel like a decision"* is unanswerable.

⇒ **This was already written down and was not read.** `adversarial-review-2026-08-14-round3-ko` names it as
finding **H**, a blocker found independently by two reviewers, and this plan's header only ever claimed
correction for the *round 2* review. Round 3's other plan-3 items came out better by luck than by reading:
`Array[-1]` returning the last row (2.9) was caught during the build, and the empty-pool freeze (2.8's
sibling) was check 14. **Read round 3 before plan 4** — most of its 101 findings are aimed there.

Round 3's own suggested fix is a design change and therefore not this plan's to make: give the crow a part
so a card lands in the first thirty seconds.

### What passed

The `Tab` panel reads correctly — 겉 six and 속 five, filled squares named, `힘 20 · 무리의 힘 80 · 체력 3/4`,
and the three key rows naming 물기 · 빈 칸 · 짧은 숨. The ending's eleven squares carry the right names in the
right indices (TORSO 1, HINDLIMBS 4, LUNG 10). The card panel offers exactly three, centred, all reading
`→ Lv2` when the part is already worn. Nothing was magenta, nothing flickered, nothing drew at zero size.
