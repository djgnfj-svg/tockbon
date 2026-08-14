# Plan 3 — the body and its parts

**Status**: `1.ready`. Part of [the grassland index](grassland-whole-loop.md). Build after
[hands and commands](hands-and-commands.md).

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

## GDScript requires a const to be assigned. Rows are indexed by the enum above and every array is the
## same length; a net asserts that, because a short row here is an index error at a level-up.
const NAME := ["물기", "짧은 숨", "말 다리", "말 갈기", "말 폐활량"]
const SPECIES := PackedInt32Array([-1, -1, 1, 1, 1])
const SLOTS := [PackedInt32Array([]),                       ## BITE and DASH occupy nothing — see below
    PackedInt32Array([]),
    PackedInt32Array([Slot.HINDLIMBS]),
    PackedInt32Array([Slot.TORSO]),
    PackedInt32Array([Slot.LUNG])]
const KIND := PackedInt32Array([Kind.ACTIVE, Kind.ACTIVE, Kind.ACTIVE, Kind.PASSIVE, Kind.PASSIVE])
const FORCE := PackedInt32Array([0, 0, 5, 5, 0])            ## ×10 scale — a +1 part is invisible now
const HP := PackedInt32Array([0, 0, 0, 1, 0])               ## the mane's whole effect. **Read by Body**
const MOVEMENT := PackedInt32Array([0, 1, 1, 0, 0])         ## what `space` will accept
const COOLDOWN := PackedFloat32Array([0.5, 0.8, 0.0, 0.0, 0.0])
const BREATH := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 2.5])  ## added to BREATH_MAX while worn

## HOW AN ACTIVE REACHES SOMETHING IS PER PART (user, 2026-08-14). There is no single combat verb to
## design; each active carries its own shape, and the player binds whichever one to whichever key.
enum Shape { NONE, ARC, SELF }   ## ARC: a swing in the facing. SELF: changes the wearer, hits nothing
const SHAPE := PackedInt32Array([Shape.ARC, Shape.SELF, Shape.SELF, Shape.NONE, Shape.NONE])
const RANGE := PackedFloat32Array([70.0, 0.0, 0.0, 0.0, 0.0])   ## px from the body's CENTRE, not its edge
const ARC := PackedFloat32Array([1.22, 0.0, 0.0, 0.0, 0.0])     ## radians, centred on the facing (70°)

## SELF actives, both of them: a speed multiplier and how long it lasts. `SUSTAINED` means "while held,
## draining breath" — otherwise `SELF_TIME` is a one-shot burst on its own cooldown.
const SELF_MUL := PackedFloat32Array([0.0, 2.8, 1.8, 0.0, 0.0])
const SELF_TIME := PackedFloat32Array([0.0, 0.16, 0.0, 0.0, 0.0])
const SUSTAINED := PackedInt32Array([0, 0, 1, 0, 0])
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

## Acceptance

**The user plays and reports whether a card feels like a decision** — whether refusing a good part because of
what it would evict ever happened, and whether the body visibly became a horse.
