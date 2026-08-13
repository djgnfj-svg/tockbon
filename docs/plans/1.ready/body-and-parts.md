# Plan 3 — the body and its parts

**Status**: `1.ready`. Part of [the grassland index](grassland-whole-loop.md). Build after
[hands and commands](hands-and-commands.md).

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
**Eleven is the number everywhere.**

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

enum Slot { HEAD, TORSO, BACK, FORELIMBS, HINDLIMBS, TAIL, EYES, GUT, BONE, HIDE, LUNG }
enum Kind { PASSIVE, ACTIVE }
enum { BITE = 0, HORSE_LEGS = 1, HORSE_MANE = 2, HORSE_LUNG = 3 }

## GDScript requires a const to be assigned. Rows are indexed by the enum above and every array is the
## same length; a net asserts that, because a short row here is an index error at a level-up.
const NAME := ["물기", "말 다리", "말 갈기", "말 폐활량"]
const SPECIES := PackedInt32Array([-1, 1, 1, 1])          ## -1 = no species. Species ids are plan 4's
const SLOTS := [PackedInt32Array([]),                      ## BITE occupies nothing — see below
    PackedInt32Array([Slot.HINDLIMBS]),
    PackedInt32Array([Slot.TORSO]),
    PackedInt32Array([Slot.LUNG])]
const KIND := PackedInt32Array([Kind.ACTIVE, Kind.ACTIVE, Kind.PASSIVE, Kind.PASSIVE])
const FORCE := PackedInt32Array([0, 1, 1, 0])
const MOVEMENT := PackedInt32Array([0, 1, 0, 0])
const COOLDOWN := PackedFloat32Array([0.5, 0.0, 0.0, 0.0])

## HOW AN ACTIVE REACHES SOMETHING IS PER PART (user, 2026-08-14). There is no single combat verb to
## design; each active carries its own shape, and the player binds whichever one to whichever key.
enum Shape { NONE, ARC, SELF }   ## ARC: a swing in the facing. SELF: changes the wearer, hits nothing
const SHAPE := PackedInt32Array([Shape.ARC, Shape.SELF, Shape.NONE, Shape.NONE])
const RANGE := PackedFloat32Array([34.0, 0.0, 0.0, 0.0])   ## px from the body edge
const ARC := PackedFloat32Array([1.6, 0.0, 0.0, 0.0])      ## radians, centred on the facing
```

⚠ **`Shape` is an enum with room to grow, not a switch over two cases.** The August build has one attacking
active, and the next habitat's parts are supposed to play differently — a projectile and a radius are the
two shapes already named in the design. **Adding one must be a row here, never a branch in the combat code.**

⚠ **`SPECIES` points at ids that plan 4 declares, and plan 3 is built first.** Put the species enum in
`Parts` **now** — `enum Species { NONE = -1, CROW = 0, HORSE = 1 }` — and have plan 4's `World` read it.
The alternative is plan 3 inventing numbers that plan 4 then has to match, which is the same value in two
places.

**Which slots a part takes is written on the part, not derived from a rule.** An adjacency graph over the
slots was raised and dropped as too complicated for what it buys.

### The August part table — three parts, all horse

| Part | 이름 | Slots | Kind | Force | Movement | What it does |
|---|---|---|---|---|---|---|
| `HORSE_LEGS` | 말 다리 | hindlimbs | ACTIVE | 1 | **yes** | **갤럽** — sustained acceleration while held, drains breath |
| `HORSE_MANE` | 말 갈기 | torso | PASSIVE | 1 | no | **+1 to the host's maximum HP** |
| `HORSE_LUNG` | 말 폐활량 | lung | PASSIVE | 0 | no | +`LUNG_BREATH` breath — how long 갤럽 sustains |

⇒ **These three are a set on purpose.** Legs are useless without breath and the mane is what lets you stay in
the fight you galloped into — so collecting horse feels like a build after three cards, not after twelve.

⇒ **갤럽 is sustained, not explosive.** The design doc is explicit that a dash and a gallop are two different
movements; the cheetah's dash is not in the August build, so **the existing `DASH_*` constants and
`Swarm::try_dash()` are deleted** and `space` holds nothing until 말 다리 is worn. The starting active in
slot 0 is what keeps the hands busy at minute one.

### The starting active

**Slot 0 (left click) starts holding `BITE`**, a part in no slot, owned by nobody, that does the host's
ordinary attack. **The user was explicit: the basic attack is just the active you are given first, and the
left-click square can be overwritten like any other.** So `BITE` is a normal row in the table with
`SPECIES = NONE`, and taking a head part and binding it to left click **replaces it and it is gone.**

## The body

```gdscript
class_name Body
extends RefCounted
## The host's own body. It lives on `World` as `var body := Body.new()`; a clone does NOT get one —
## a clone carries a single part index (plan 4's `Swarm.worn`), which is why this is not on `Swarm`.

var slot_part := PackedInt32Array()    ## eleven entries, -1 for empty
var slot_level := PackedInt32Array()   ## per slot, 1.. — the part's level, not the run's
var bound := PackedInt32Array()        ## three entries: which PART id fires on left / right / space, -1 = empty

func wear(part: int) -> Array          ## returns the part ids that were digested
func force_bonus() -> int
func can_bind(part: int, key: int) -> bool
func fire(key: int) -> int             ## the part id to fire, or -1
```

⚠ **`bound` holds PART ids, not slot indices, and the first draft had it holding slots.** It cannot hold
slots: **`BITE` occupies no slot** — it is the active you are handed, not a thing worn
([why](../../decisions/every-key-is-a-square.md)) — so slot-indexed binding has nowhere to put the one
active every run starts with. **Written as slots, this plan does not compile.**
⇒ Digesting a part therefore means **scanning `bound` for that part id and clearing it**, which is three
comparisons and needs no back-pointer.

### Wearing is irreversible and it can hurt

**This game has no bag, only a body.** All of it follows from refusing to build an inventory:

- **A new part in an occupied slot replaces the old one and the old one is digested** — not stored, not
  listed, not recoverable
- **A multi-slot part is evicted whole the moment any one of its slots is claimed**, and its other slots are
  left **empty**
- **Levelling only happens on the same species' same part.** `말 다리 Lv2` comes from another horse
- **When a digested part was bound to a key, that binding clears.** The key goes empty and the panel says so.
  A binding pointing at a slot that no longer holds that part is the kind of dangling index that reads fine
  and fires nothing

⇒ **A small part can cost a big one.** That is the point, and the user chose to keep it: without it there is
never a reason to refuse a good card.

## Cards give parts and nothing else

**`src/sim/cards.gd` is rewritten.** Today it offers `SPLIT_1`, `SPLIT_3`, `HOST_SPEED`, `HOST_BITE`,
`CLONE_BITE`, `SENSE`, `DASH`, `TOUGH` — **every one of them is deleted**, and the multipliers they moved
(`host_speed_mul`, `host_eat_mul`, `clone_eat_mul`, `sense_mul`, `dash_cd_mul`) go with them.

- **Three cards, as today.** Each names a part
- **A card for a part already worn is a level-up of that part** and says so on the face: `말 다리 → Lv2`.
  ⚠ **A level has to DO something**: `Lv2` adds `+1` to that part's `FORCE` and takes `10%` off its
  `COOLDOWN`. Without a stated effect the net can only assert the number went up, and a no-op implementation
  stays green while the acceptance question — *does a card feel like a decision* — cannot be answered
- **The pool is rolled from what has been eaten.** A horse part cannot appear before a horse has been eaten.
  **This is the only lock** — the price was deleted for being a second one on the same door
  ([why](../../decisions/card-price-removed.md))
- ⚠ **An empty pool must not freeze the game, and today it would.** `world.gd:58` refuses to step while
  `pending_levels > 0`, and the first level arrives long before the first horse. **Levels BANK**: with no
  card to offer, `pending_levels` keeps counting and the sim keeps running; the cards appear the moment the
  first horse is eaten, and they arrive as a stack. **That cascade is the rhythm the GDD already asks for**,
  and it costs one condition. Assert it: level three times with an empty pool and the world still advances
- **The level no longer grows the swarm.** `F` does that now. `World::take_card` loses its `add_clone()` arms
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

`host_hp_max = HOST_HP + level * HP_PER_LEVEL + sum of worn parts' HP`

`HOST_HP` (3) stays the floor. **Healing is not in this plan** — raising the maximum raises current HP by
the same amount, and there is no other source. Whether damage is ever recovered is open.

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

Plan 2 shipped it empty. Now: eleven slots showing part names and levels, the three key rows showing what is
bound, and the host's force, HP and defence. Binding is click-slot then click-row, and `space` refuses
anything without `MOVEMENT`.

## Numbers

| Constant | Value | Why |
|---|---|---|
| `HP_PER_LEVEL` | `1` | small, so the mane's +1 defence still reads |
| `GALLOP_ACCEL` | `1.8×` host speed | sustained, not explosive — a dash it is not |
| `BREATH_MAX` | `2.0` s | 갤럽 without lungs is short enough to want lungs |
| `LUNG_BREATH` | `+2.5` s | one part more than doubles it — the set has to be felt |
| `BREATH_REGEN` | `1.0` /s | full recovery in about the time it takes to re-engage |
| `HORSE_TRAIT_COUNT` | `3` | all three horse parts — the whole table, so the trait is reachable |
| `BITE_COOLDOWN` | `0.5` s | the hands are never idle |
| `BITE_RANGE` / `BITE_ARC` | `34` px / `1.6` rad | a swing just past the body. **A property of the part, not of combat** |

## Nets

New `tests/nets/net_body.gd` and `tests/nets/net_parts.gd`; `net_cards.gd` is rewritten.

⚠ **Two files outside this plan's own list break here**, both found by review:

- **`src/view/card_panel.gd:99,101`** reads `Cards.TITLE[card]` and `Cards.DESC[card]`, keyed by the eight
  card ids this plan deletes. The card face also has to render `말 다리 → Lv2`. **Rewrite it in this commit**
- **`tests/nets/net_hunt.gd:32-33`** calls `try_dash()`, which this plan deletes — and `net_hunt` is not
  rewritten until plan 4. **It goes red for the whole of plan 3 unless those two lines are fixed here.**
  Fix them here; a red net that everyone has agreed to ignore is how a real one gets ignored too

1. Wearing a part into an empty slot: the slot holds it, `force_bonus()` rises by exactly its `FORCE`
2. Wearing over an occupied slot returns the old part as digested, and it is **not** anywhere in the body
3. A multi-slot part evicted by a claim on one of its squares leaves **every** other square it held empty
4. A digested part that was bound to a key clears that binding — assert the key fires **nothing** afterwards,
   by driving it, not by reading the array
5. The same part again is `Lv2`, a different species' same-slot part is a **replacement**
6. `space` accepts `HORSE_LEGS` and refuses `HORSE_MANE`
7. Card pool contains no horse part until a horse has been eaten; contains one after
8. `Cards` offers **only parts** — assert every offered id resolves in `Parts`, and that `Rules` no longer
   carries `DASH_SPEED`, `DASH_TIME`, `DASH_COOLDOWN`
9. `take_card` never changes `swarm.count`. *A/B comparison catches "diverged", never "vanished"* — assert
   the count both before and after, and assert a card was actually consumed
10. Wearing all three horse parts sets the trait; wearing two does not. **Then drive 갤럽 and assert breath
    does not fall** — the trait firing, not the flag being set
11. HP maximum with level 3 and a mane is the literal expected number, not a formula re-derived in the net
12. **Driven**: `_paint_body` is called with a part count matching the body, and the arguments for a bare
    body and a three-part body **differ**. *"`_draw()` ran" is not "anything was drawn"*
13. Breath: 갤럽 held past `BREATH_MAX` stops accelerating; assert the host's speed drops back to base **and**
    that it was ever raised. *A loop whose condition is false from the start never runs the check*

## Acceptance

**The user plays and reports whether a card feels like a decision** — whether refusing a good part because of
what it would evict ever happened, and whether the body visibly became a horse.
