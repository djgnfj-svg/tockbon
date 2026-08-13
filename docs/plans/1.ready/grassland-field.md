# Plan 4 — the grassland field

**Status**: `1.ready`. Part of [the grassland index](grassland-whole-loop.md). Build last.

**What it closes**: **the place.** Two species, a food layer that gives no parts, a boss that walks the field
from the first second, force and disposition as two separate axes on every individual, the number under every
body, the eating beat, and a minimap. After this plan the loop closes: enter bare, grow, pass the boss, eat
it, ending.

---

## The two axes, and why they do not talk to each other

The prototype shipped one number, `threat`, and derived behaviour from it. **The user rejected that as the
model** ([why](../../decisions/force-and-disposition-are-separate.md)).

| Axis | What it is | Who holds it |
|---|---|---|
| **Disposition** | attacks, or flees | **the individual** — rolled at spawn, not derived from anything |
| **Force** | who wins if they meet | **the individual**, and it varies inside one species |

| | weak | strong |
|---|---|---|
| **attacks** | free food — it walks into your mouth | the real threat — a scattered swarm gets shredded |
| **flees** | annoying — you have to chase it down | **the boss** — it does not flee; it is the one that hits for 12 |

⇒ **Two species fill all four squares** because disposition is per-individual. A crow that decided to attack
is free food; a horse that decided to attack is a real fight at level 2. **This is why the axes are separate,
and the August build is the proof of it.**

⚠ **`Rules.SWARM_PER_THREAT` and `World::is_hunter_of()` are deleted.** Nothing derives behaviour from a
comparison any more.

⚠ **And `src/view/field_view.gd` is built on both of them**, which the first draft missed. `field_view.gd:71`
picks a creature's colour from `is_hunter_of(k)`, and `:72` takes its body radius from
`world.critter_radius(k)`, which reads `critter_threat`. `World::_contact` uses the same radius for reach.
**Deleting the pair leaves creatures with no colour and no size.** Replacements, in this plan:

- **Radius comes from force**: `CRITTER_RADIUS_BASE + force * CRITTER_RADIUS_PER_FORCE`. A dangerous one is
  still visibly bigger before it is close, which is what the old rule bought
- **Colour comes from species, not from a comparison.** `Look.CROW_COLOR` · `Look.HORSE_COLOR` ·
  `Look.BOSS_COLOR`, flat placeholders until the user picks real ones. `Look.CRITTER_PREY_COLOR` is orphaned
  and goes
- ⚠ **Species colour is the user's call, not the builder's** — `CLAUDE.md`: art is decided by generating
  candidates and pointing at one. Ship flat placeholders and say so; do not invent a palette

## The creature table

`World`'s flat arrays are extended, same discipline:

```gdscript
var critter_species := PackedInt32Array()   ## Parts.Species — CROW | HORSE | BOSS
var critter_force := PackedInt32Array()     ## per individual, varies inside a species
var critter_hp := PackedInt32Array()
var critter_flees := PackedInt32Array()     ## 1 = flees, 0 = attacks. Rolled at spawn, never changes
var critter_pos, critter_dir, critter_count ## as today
```

⚠ **`critter_threat` goes away and FOUR arrays take its place, so two functions must grow with them.**
`World::setup()` resizes three arrays today and `World::_remove_critter()` hand-swaps three rows.
**Miss one line in the swap and killing a creature hands its species, force, HP or disposition to a
survivor** — a horse becomes a crow, the boss's force lands on something else, and there is no error and
nothing wrong on screen. Every flat-array removal in this build has this shape and this is the fourth time
the repo has had to learn it.

⇒ **The net has to kill a creature that is not the last row**, then assert the survivor's four fields
against literals. Killing the only creature never enters the swap branch and every check stays green.

| Species | 이름 | Force | Attacks | Speed | Gives |
|---|---|---|---|---|---|
| `CROW` | 까마귀 | `1–2` | 30% | slow | **cells only, no part** |
| `HORSE` | 말 | `3–4` | 20% | **faster than the host** | 말 다리 · 말 갈기 · 말 폐활량 |
| `BOSS` | 보스 | `12` | always | slower than the host | ends the run |

**The crow gives no part.** The design doc lists crow wings as grassland's only back part; the user named the
crow purely as early food (2026-08-14), **because catching a horse first is too hard.** Wings stay unbuilt.

**The horse is faster than the host on purpose.** It is the species that has to be caught with the swarm
rather than with `WASD` — which is what makes `3` a key worth pressing.

### The boss

**One chimera, on the field from the first second, wandering** (user, 2026-08-14). Not spawned on a trigger,
not gated behind a level. Seeing it early, with its 12 written under it, **is** the stage's arc.

- **Elephant bulk, a lion's head, wings, a rhino's horn** — a part list, not a boss class, so it costs no new
  system
- Force `12`. ⚠ **That is not a gate** — see *Fighting*. It is how hard it hits and how much chewing it
  takes, and a level-1 host is welcome to try
- **It attacks.** Disposition is not rolled for it
- **Patterns are undesigned and stay undesigned in the August build.** It walks and it hits. Say so out loud
  rather than inventing three attacks nobody asked for

## Fighting, and the eating beat

**Nothing is eaten just by touching it any more** (user, 2026-08-14). The chain is:

**hit → it dies → a corpse → the body stands there and eats → cells, and maybe a part.**

### Hitting

- **Damage comes from actives**, not from contact. The host fires what is bound to its three keys, and
  **how each one reaches is written on the part** — `Parts.SHAPE` · `RANGE` · `ARC` (user, 2026-08-14).
  There is no single combat verb
- **A clone is stupid**: it attacks whatever it touches, on `Rules.CLONE_ATTACK_PERIOD`, with no aiming
  ([why](../../decisions/clones-are-stupid-by-default.md))
- **Damage equals the attacker's force, in both directions.** A creature's HP is
  `force * Rules.HP_PER_FORCE`; **a creature that reaches the host takes that creature's force off the
  host's HP**, then `HOST_HIT_GRACE`. Reaching a **clone** kills it outright, and **its cargo and its force
  die with it**

⇒ **This is what makes the boss dangerous without gating it** (user, 2026-08-14). A level-1 host **can**
kill a force-12 boss by walking backwards and biting — **that is allowed.** What it costs is that the boss
hits for 12 against a 3-HP body: **one touch and the run is over.** The wall is a consequence, not a
threshold, and it means the fight is available early and almost nobody takes it.

⇒ **So the boss must be hard to disengage from.** Slower than the host in a straight line, but its reach and
its grace-free contact mean a mistake is not survivable. **If play shows it can be kited safely, the fix is
the boss's reach — not a level requirement.**

⇒ **The even-force band falls out with no extra rule.** Much stronger and it dies in one hit; much weaker
and you cannot chew through it; close and it takes several exchanges — **which is exactly where the hands
decide instead of the numbers.**

### The corpse, and eating it

```gdscript
var corpse_pos := PackedVector2Array()
var corpse_species := PackedInt32Array()
var corpse_force := PackedInt32Array()        ## what it was worth. Copied at death, never a live index
var corpse_progress := PackedFloat32Array()   ## 0..1
var corpse_count := 0
```

- A dead creature leaves a corpse **where it fell**, carrying **copies** of its species and force. ⚠ **A
  corpse never holds an index into the creature arrays** — those rows get swapped out from under it
- **`Rules.CORPSE_MAX` is 64 and the table is preallocated**, like every other flat table here
  (`POOL` 128, `CRITTER_MAX` 24, `FOOD_SPOTS` 500). "Corpses do not decay" plus no ceiling is unbounded
  growth. **At the cap, a new kill leaves no corpse** — it is not worth evicting an older one, because
  "I came back and my kill was gone" is a bug report
- A body standing within `EAT_RADIUS` of a corpse raises `corpse_progress` by `dt / EAT_TIME`
- ⚠ **Progress advances ONCE per frame, not once per eater.** Forty clones on the boss would finish a
  six-second meal in 0.15s — and forty on one point is exactly what `1` and `V` exist to produce, so the
  beat would vanish at the one moment it was built for. **The meal takes the same time whoever is eating.**
  The reward goes to **whoever is standing on it when it completes**, host first if the host is among them
- **Progress is kept when the eater walks away.** Coming back resumes. This is what makes interrupting a meal
  a real cost rather than an annoyance
- **A body eats one corpse at a time** — the nearest one in reach, recomputed every frame like
  `_nearest_food` already is. **Never cache a corpse index across frames**
- At `1.0` the corpse is consumed: **`corpse_force × Rules.CELLS_PER_FORCE` cells** go to the eater
  (`cells_eaten` and `banked` for the host, `carried` for a clone). **A corpse is worth what the individual
  was worth** (user, 2026-08-14) — a force-4 horse pays twice a force-2 crow
- ⚠ **The part roll is the CLONE's path only.** A clone that finishes a corpse wears a part from it; **the
  host gets nothing but cells.** The host's parts come from level-up cards, and only from there (user,
  2026-08-14). Rolling a part for the host as well would make the card redundant
- **`EAT_TIME` scales with the corpse's force.** A crow is a mouthful; the boss is the end of the run

⇒ **This is the "쫀득" the user asked for**, and it is a mechanic before it is an animation: the moment of
standing still over a kill, with something able to walk up to you, is where the tension lives. The animation
sells it — see *Drawing* — but the beat has to be in `sim/` or the screen and the sim are two different games,
which `CLAUDE.md` names as the signature fake.

### Clones wear what they kill

**Confirmed by the user, 2026-08-14.** A clone that finishes eating a horse corpse rolls a horse part and
**wears it in one slot** — clones carry one part, not eleven. It gains that part's force and, if the part is
an active, fires it on cooldown with no aiming.

⇒ **By the end of a run the swarm is forty creatures doing different things.** That is the screenshot this
game sells, and it costs nothing beyond a single index per clone.

### The great absorption eats the bodies too

Plan 1 built the beat. Here it gains its meaning: on clearing, **the clones' own force and worn parts are
absorbed as well.** It is the one time bodies are eaten.

## The food layer that gives no parts

Grass, plants and scattered small food. `src/sim/food.gd` already does this and **it stays as it is** — eaten
on contact, instantly, no corpse. **Only creatures need the eating beat**; making grass take time would put a
timer on the game's calmest action.

⇒ **This layer is what the opening minutes eat**, and it is the cheapest content in the game.

## The number under the body

**The user, 2026-08-14: draw force under every body, clones included.**

- **Under the host, under every clone, under every creature.** No UI panel — the comparison happens without
  moving your eyes
- **When bodies are packed together, draw one number: the sum.** Forty digits in a pile is unreadable, and
  the sum is the number that actually decides the fight. Cluster at `Look.FORCE_CLUSTER_RADIUS` (48px), and
  draw the total at the cluster's centroid. Three rules the first draft left open, each of which would have
  destroyed the readout:
  - **Mine and theirs never share a cluster.** A swarm of 8 standing among crows of 3 must not read `11` —
    the number exists to be compared, and summing across the comparison erases it
  - **The host is never absorbed into one.** It always draws its own number; a rallied host is always
    surrounded, so folding it in means your own force disappears exactly when you need it
  - **Do not use `SimGrid.neighbours()` for this.** It truncates at `NEIGHBOUR_CAP` (8) by design — its own
    comment says so — so a pile of 40 would sum to 8. Walk the bodies
- **Only force gets a number.** Disposition needs no marker — something coming at you is attacking
- **No colour coding**, and a species never eaten shows `?` instead of a number. ⚠ **The boss is the
  exception and shows its 12 from the first second.** By the rule it would read `?` for the entire run, and
  *seeing the number you cannot yet reach* is the stage's whole arc. `species_eaten` is the store, it is
  written when a corpse is finished, and it lives on `World` for the run

⚠ **The cluster rule is the one thing here that can quietly not work.** A net that only checks "a number was
drawn" passes whether it drew 40 or 1. **Assert the count of drawn labels and the value of each.**

## The minimap

**The user asked for one at 3840×2160** (2026-08-14). Bottom-right, `Look.MINIMAP_*`.

- The field's rectangle, the camera's rectangle inside it
- The host as one mark, clones as smaller marks, **the boss always shown**, other creatures shown only inside
  a radius of the host
- **It draws from `world`, never from the view.** `src/view/` reads `sim` and never writes it

## Numbers

| Constant | Value | Why this one |
|---|---|---|
| `HP_PER_FORCE` | `3` | a two-force gap is about two extra exchanges — the band is wide enough to feel |
| `EAT_TIME_PER_FORCE` | `0.5` s | a crow is ~0.5s, a horse ~1.75s, the boss ~6s |
| `CROW_FORCE` | `1–2` | the number under a body has to compare at a glance |
| `HORSE_FORCE` | `3–4` | uncatchable alone at level 1, routine by level 5 |
| `BOSS_FORCE` | `12` | above a level-8 host, so it cannot be walked into early |
| `ATTACK_CHANCE_CROW` | `0.30` | enough that the opening has some danger in it |
| `ATTACK_CHANCE_HORSE` | `0.20` | rarer, and much worse when it happens |
| `HORSE_SPEED` | `1.15 ×` host | faster than `WASD`, catchable by a swarm. ⚠ **This breaks the speed ordering `rules.gd:10-12` calls load-bearing** — host > critter > scattered clone. **Rewrite that comment in the same commit**; the ordering it protected assumed one critter speed, and now the horse is the species you cannot outrun and the crow is the one you can |
| `CORPSE_MAX` | `64` | preallocated like every other flat table. At the cap a kill leaves no corpse |
| `CRITTER_RADIUS_PER_FORCE` | `4.0` | replaces the per-threat version; a strong one still reads as bigger |
| `FORCE_CLUSTER_RADIUS` | `48` px | in `look.gd` — it is a readout rule, not a rule about what happens |
| `BOSS_SPEED` | `0.75 ×` host | you can disengage in a straight line. **Its reach, not its speed, is what makes a mistake fatal** |
| `PART_DROP_CHANCE` | `0.5` | **a CLONE's chance of wearing a part off a corpse.** The host's parts never roll ([why](../../decisions/parts-drop-by-chance.md)) |
| `CELLS_PER_FORCE` | `6` | a corpse pays its individual's force × this. Levels arrive every 10 cells, so this one number is the level curve |
| `CLONE_ATTACK_PERIOD` | `1.2` s | a clone hits whatever it touches. Slower than the host's bite, for the same reason its mouth is slower |

**All guesses. Expect every one to move on the first session.**

## Nets

New `tests/nets/net_field.gd` and `tests/nets/net_eating.gd`; `net_hunt.gd` is rewritten around the two axes.

1. Disposition is rolled at spawn and **never changes** — step a fleeing horse for 10 seconds next to a swarm
   of 40 and assert it still flees. *The old model would have flipped it*
2. A fleeing creature moves **away**; an attacking one moves **toward**. Pin both directions
3. Damage equals the attacker's force: a force-5 host needs exactly 2 hits on a force-3 horse (`hp = 9`)
4. Killing leaves a corpse **at the position it died**, and the creature is gone from the creature arrays
5. **Eating is not instant**: standing on a corpse for half `EAT_TIME` yields **zero** cells and the corpse
   still exists. *A check that reads only final state cannot measure an ordering contract*
6. Walking away at 60% and returning finishes it — assert the total time is the same as standing still
7. Finishing a horse corpse rolls a part; **finishing a crow corpse never does** — run it 50 times with a
   pinned seed and assert exactly zero
8. A clone that finishes a corpse **wears** the part and its force rises by that part's `FORCE`
9. A clone killed while eating leaves the corpse's progress intact and **loses its own cargo and force**
10. The boss exists at `t = 0` — assert it is in the arrays the frame after `setup()`
11. Eating the boss sets `stage_cleared`; eating anything else never does
12. **Cluster labels, driven**: place 40 clones on one point and assert `_paint_force_label` is called
    **once** with the summed value; spread them past `FORCE_CLUSTER_RADIUS` and assert it is called 40 times.
    *Assert the count and the value, not that something was drawn*
13. A species never eaten draws `?`; after one is eaten it draws the number
14. Minimap: `_paint_minimap` receives the boss's mark **always**, and a distant crow's mark **never** —
    with literal coordinates, not coordinates read back from the map
15. `Rules` no longer carries `SWARM_PER_THREAT`, and `World` no longer has `is_hunter_of`
16. **Kill a creature that is not the last row** and assert the survivor's species, force, HP and
    disposition against literals. *Killing the only creature never runs the swap*
17. **Forty clones on one corpse take the same time as one** — assert the elapsed time is equal, not merely
    that the corpse was eaten
18. At `CORPSE_MAX`, a further kill leaves the existing corpses untouched and adds none
19. A crow at force 2 and a horse at force 3 standing together draw **two** labels, not one summed `5`
20. Forty clones on one point draw **one** label of the correct sum **plus** the host's own — assert both,
    and assert the sum is not 8. *`SimGrid` truncates at 8 and would pass a naive check*
21. The boss draws `12` before anything has been eaten; a crow draws `?` until one has

## Acceptance

**The user plays one grassland run end to end** and reports: whether the horse stops being uncatchable at a
moment they can name, whether standing over a corpse feels tense rather than slow, and whether the swarm of
forty doing different things reads on screen.
