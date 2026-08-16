# Plan 4 — the grassland field

**Status**: `3.done` — implementation finished and green, **not accepted**. Part of
[the grassland index](grassland-whole-loop.md).

## What the build changed about this plan

**Seven verifiers read the finished build**: eight defects, sixteen unmeasured surfaces and fifteen doc/code
disagreements. All eight defects are fixed and every unmeasured surface is now measured. Six of those repairs
left `src/` saying something this plan does not:

1. **A clone's admission band is the CLONE's, not the creature's reach.** The plan let `_contact` admit a
   clone at `critter_reach(k) + CLONE_BODY_RADIUS`, which for the boss is 126px — and then swung an 88px
   beak. Zero damage, a full cooldown burned, every period: **wearing the stage's own reward made a clone
   strictly worse against the boss.** The band is now `Parts.RANGE[worn] + critter_radius(k)` for an ARC part
   and `critter_radius(k) + CLONE_BODY_RADIUS` otherwise. ⚠ **This changes play on purpose** — an unworn
   clone chips the boss from 56px, not 110px, which is what `SPECIES_REACH_BONUS` is for.
2. **`push_out` is a nearest-point-outside-a-union-of-circles solver, not two passes.** Two rocks 10px apart
   pushed a body back and forth and it settled *inside* one, stably, for the rest of the run.
   `Rules.PUSH_OUT_ROUNDS` is **deleted** — dropping it to 1 was green, and every answer the sequential sweep
   could give is already in the candidate set.
3. **`_step_critters` walks FORWARDS over a bound re-read each iteration.** The frozen backwards list let a
   creature take two steps in one frame and let stale rows past `critter_count` act.
4. **`_step_arena` returns before `BOSS_HUNT_AT`**, and the boss — only the boss — is clamped into the arena
   it closed. A wandering boss could otherwise seal the host in a 900px circle at t = 20s and walk out of it.
5. **`_place_boss` is split into `_boss_spot(host, tries)` and `_boss_backstop(host)`**, and the "keep the
   FARTHEST sample" tracking is gone: the loop breaks on the first sample that clears the floor, so the
   tracking was dead code and `if d > best_d:` → `if true:` was green. The try count is an argument because
   at 200 the backstop is a 1-in-10¹¹ branch and cannot be reached by driving `setup()`.
6. **The minimap's camera box is clipped to the map.** A host against the west field edge drew a bright bar
   across the play area.

⚠ **And one thing this plan asked for is not in the build at all: the arena has no view.** Zero hits for
`arena` across `src/view/`, `src/shell/` and `src/look.gd`. The circle closes, the host is pinned inside it
and every clone is teleported in — and **nothing is drawn.** That is a gap in this plan's own spec, not a
builder miss, and it means the acceptance question at the bottom of this file (*does the arena closing read
as the run's last act*) **cannot be answered by this build.**

⚠ **Five things below were corrected on 2026-08-15 from the user's own answers**, and three of them have a
`decisions/` file: [the boss's speed is a deferral, not a number to fix
here](../../decisions/the-boss-speed-is-deferred.md) · [**a clone has hp and is not killed
outright**](../../decisions/the-clone-has-hp.md) · **the host's HP is a printed number, not hearts** ·
[**the crow gives three parts and the horse gives one**](../../decisions/the-crow-gives-three-parts.md).
Where a line still disagrees with the build spec, the spec is newer.

⚠ **And the numbers in this file's two tables were re-measured against `rules.gd` on the same day.** Three
rows are struck and point at the constant instead of restating it (`EXP_PER_FORCE`, `BOSS_SPAWN_MIN_DIST`,
`MINIMAP_SHOW_DIST`'s home), and the creature table gained a sixth column. **`BOSS_SPEED 0.75` and the speed
ordering are correct as written** — they were queued for a strike and the user's deferral put them back.

✅ **Rewritten 2026-08-14 for [the adversarial review](../../adversarial-review-2026-08-14-ko.md)'s NOT
BUILDABLE verdict and for [hunting and the boss](../../design/hunting-and-the-boss-ko.md).** The two things
the review found missing are now here in full: **what the field is made of** (*The field, at `t = 0`*) and
**what an attack hits** (*Hitting*). Everything is at the ×10 force scale, **the word is 경험치 and never
세포**, and this plan inherits [plan 2](../3.done/hands-and-commands.md) and [plan 3](../3.done/body-and-parts.md) as corrected —
read both first.

⚠ **Where this file and the review disagree, this file is newer and it is deliberate.** The review's fix for
the horse was to slow it to 1.05× so the swarm could catch it; **the design then said the opposite** — the
horse is not catchable at all, it is herded ([why](../../decisions/the-horse-is-herded-not-outrun.md)). What
survives from that finding is the part that was always right: **the speed ordering is load-bearing, it is
written in two comments in `rules.gd`, and nothing was guarding it.** It is guarded here.

**What it closes**: **the place.** Two species and a boss, terrain, a food layer that gives no parts, force
and disposition as two separate axes on every individual, the number under every body, the eating beat, and a
minimap. After this plan the loop closes: enter alone, split, grow, herd, fight the boss, ending.

---

## The two axes, and why they do not talk to each other

The prototype shipped one number, `threat`, and derived behaviour from it. **The user rejected that as the
model** ([why](../../decisions/force-and-disposition-are-separate.md)).

| Axis | What it is | Who holds it |
|---|---|---|
| **Disposition** | attacks, or flees | **the individual** — rolled at spawn, not derived from anything |
| **Force** | who wins if they meet | **the individual**, and it varies inside one species |

⚠ **`Rules.FORCE_PER_THREAT` and `World::is_hunter_of()` are deleted.** Nothing derives behaviour from a
comparison any more. (**The constant was `SWARM_PER_THREAT` when this plan was written**; plan 2 renamed it
and repointed the comparison at `Swarm.total_force()`, because counting bodies made `F` a free power-up.
It is the same deletion — only the name to grep for changed.)

⚠ **And `src/view/field_view.gd` is built on both of them**, which the first draft missed. It picks a
creature's colour from `is_hunter_of(k)` and its radius from `critter_radius(k)`, which reads
`critter_threat`; `World::_contact` uses the same radius for reach. **Deleting the pair leaves creatures with
no colour and no size.** Replacements are *Size* and *Colour* below.

### Size belongs to the species

`13 + force × 4` is dead — at force 120 it puts the boss at 493px and a strong crow above a horse
([why](../../decisions/size-belongs-to-the-species.md)).

```gdscript
func critter_radius(k: int) -> float:
    var s := critter_species[k]
    var t := clampf(float(critter_force[k] - FORCE_MIN[s]) / float(FORCE_MAX[s] - FORCE_MIN[s]), 0.0, 1.0)
    return SPECIES_RADIUS[s] * (1.0 + 0.5 * t)      ## at most 1.5×, never more
```

**Species order can never invert.** A maxed crow is 18px; the weakest horse is 22px. **A net asserts exactly
that** — max crow radius `<` min horse radius, computed from the constants, not from one spawned pair.

### Colour comes from the species

`Look.CROW_COLOR` · `HORSE_COLOR` · `BOSS_COLOR`, flat placeholders. `Look.CRITTER_PREY_COLOR` is orphaned
and goes. ⚠ **Species colour is the user's call, not the builder's** — `CLAUDE.md`: art is decided by
generating candidates and pointing at one. Ship placeholders and say so; do not invent a palette. **They must
still be legible against `Look.BG`** — a dark placeholder on a dark floor is the defect verify-look already
caught once on this build.

## The creature table

`World`'s flat arrays are extended, same discipline:

```gdscript
var critter_species := PackedInt32Array()   ## Parts.Species — CROW | HORSE | BOSS
var critter_force := PackedInt32Array()     ## per individual, varies inside a species
var critter_hp := PackedInt32Array()        ## force * Rules.HP_PER_FORCE, written at spawn
var critter_flees := PackedInt32Array()     ## 1 = flees, 0 = attacks. Rolled at spawn, never changes
var critter_atk_cd := PackedFloat32Array()  ## contact-attack cooldown, per creature
var critter_counter := PackedFloat32Array() ## seconds of crow counter left — the sixth, see below
var critter_pos, critter_dir, critter_count ## as today
```

⚠ **`critter_threat` goes away and ~~FIVE~~ SIX arrays take its place, and THREE functions must grow with
them — not two.** The first draft named `setup()` and `_remove_critter()` and **missed `_spawn_critter()`,
which is where every row is actually written.** `resize()` fills with zeros, so a missed line there is a
creature that spawns 45 seconds into the run as **species CROW, force 0, hp 0** with a perfectly normal body
on screen.

⚠ **The sixth is `critter_counter`** — seconds of crow counter left. The block above names five and the
counter has nowhere else to live: *The field, at `t = 0`* gives the crow a timed counter-attack two sections
down and the block was never extended for it. **Every "all five" below means all six**, and `boss_index` is a
seventh thing `_remove_critter()` must repair even though it is not a column.

| Function | What it must do |
|---|---|
| `World::setup()` | `resize(Rules.CRITTER_MAX)` — all six |
| `World::_spawn_critter()` | **write all six explicitly.** This is the one the review found missing |
| `World::_remove_critter()` | swap all six from the last row, then repair `boss_index` |

⇒ **The net has to kill a creature that is not the last row**, then assert the survivor's fields against
literals. Killing the only creature never enters the swap branch and every check stays green.

## The field, at `t = 0`

**This section is the answer to "NOT BUILDABLE".** Every number the builder needs to fill the field is here.

⚠ **This table is three species and the field is seven.** On 2026-08-15 the user played it, said the field
needed animals, and named four more — 다람쥐 · 코끼리 · 치타 · 사자, **none of which gives a part**
([the condition that fired](../../decisions/august-scope-two-species.md)). The three rows below are still
correct for the three they describe; **the `At t = 0` row is not**, because the opening is now
`SPECIES_START × SPECIES_HERD` and horses arrive four at a time. **Read `rules.gd` for the field's shape,
this table for the three species plan 4 built.**

| | `CROW` 까마귀 | `HORSE` 말 | `BOSS` 보스 |
|---|---|---|---|
| Force | **8–12** | **30–40** | **120** |
| HP | `force × 3` | `force × 3` | `force × 3` |
| Speed | `0.55 ×` host | **`1.15 ×` host** | `0.75 ×` host |
| Disposition | **never flees** — stands, and counters when hit | **always flees** — from host and clones alike | **always attacks** |
| Base radius | 12 | 22 | 48 |
| Gives | **까마귀 날개 · 까마귀 부리 · 까마귀 발** ([why](../../decisions/the-crow-gives-three-parts.md)) | **말 다리만** (same) | ends the run, and gives **no part** |
| At `t = 0` | **8** | **3** | **1** |

- **`_spawn_critter()` never rolls the boss.** The boss is placed once, by `setup()`, and there is exactly one
  for the run. ~~The periodic spawn rolls `CROW` at `Rules.SPAWN_CROW_CHANCE` (0.7) and `HORSE`
  otherwise~~ ⚠ **`SPAWN_CROW_CHANCE` was deleted on 2026-08-15** when the field went to seven species —
  it is `Rules.SPECIES_SPAWN_WEIGHT`, a relative weight per species, and the boss's row is 0. The rule this
  line states survives; the constant does not
- **`critter_flees` is not rolled.** The design gave each species one disposition and they are the three
  different hands the stage is made of — the crow that stands and counters
  ([why](../../decisions/the-crow-stands-and-fights-back.md)), the horse that flees everything
  ([why](../../decisions/the-horse-is-herded-not-outrun.md)), the boss that comes. The array stays because
  the movement code reads one field either way. ⚠ **The clause that said "plan 5's species will vary it" is
  dead twice over**: plan 5 became the presentation pass, and the four species that did land on 2026-08-15
  took *three new columns* (`SPECIES_WANDER` · `SPECIES_HUNTS` · `SPECIES_HERD`) rather than varying this one
- **The crow's counter**: it does not chase, but for `Rules.CROW_COUNTER_TIME` (2.0s) after being damaged it
  moves at the nearest body and attacks on contact. That is the entire "walk up and hit it" hand
- **The horse flees the nearest body within `CRITTER_SENSE`, host or clone**, and **stops dead against a rock,
  a clone or the field edge** — the three walls the design names. Nothing else catches it
- Boss placement: `Rules.BOSS_SPAWN_MIN_DIST` ~~(2200px)~~ from the host, so it is visible on the minimap from
  the first second and is a walk away. ⚠ **The number is wrong here and `rules.gd` is where it lives** — the
  field's centre-to-corner distance is smaller than 2200, so the band this asked for was four slivers a
  sampler cannot land in. Read the constant, never this line

⚠ **The speed ordering changed and it is now written down where it can be checked.**
`HORSE 230 > CLONE_FOLLOW 215 > HOST 200 > BOSS 150 > CLONE_SCATTER 125 > CROW 110`. `rules.gd` states this
ordering **in two separate comments** and one of them still names `PREDATOR_SPEED`, a constant that no longer
exists. **Fix both, and add literal-to-literal checks** — the horse being out-runnable by the swarm deletes
the reason `3` exists, and nothing was watching that number.

## Terrain

**Rocks and water both ship. Nothing is deferred** — the user was offered the cut twice and refused
([why](../../decisions/everything-goes-in-for-august.md)).

```gdscript
var rock_pos := PackedVector2Array()      ## ROCK_COUNT 40, radius 40–90, placed at setup, never move
var rock_radius := PackedFloat32Array()
var water_pos := PackedVector2Array()     ## WATER_COUNT 12, radius 90–180
var water_radius := PackedFloat32Array()
```

- **A rock cannot be entered — by anything.** One shared helper, `World::push_out(p, r) -> Vector2`, applied
  after every body's and every creature's move, in `Swarm::step()` and `_step_critters()`. **Rocks are placed
  at least `ROCK_CLEAR_DIST` (400px) from the host's start**, or the run opens wedged
- **Water slows and hides.** Inside a water circle a body moves at `Rules.WATER_SLOW` (0.6×) and **is invisible
  to creature sensing** — the fleeing horse does not see it, the crow does not counter toward it. It is the
  ambush half of herding
- ⚠ **`Swarm` may not read `World`** — the folder contract runs the other way. So the terrain arrays live on
  `World` and `Swarm` gets `var terrain: Terrain = null` (a tiny `RefCounted` in `src/sim/`), set by
  `World::setup()`. Writing it as a back-reference to `World` is the circular dependency that makes every
  `Swarm` net need a `World`

## Fighting, and the eating beat

**Nothing is eaten just by touching it any more** (user, 2026-08-14). The chain is:

**hit → it dies → a corpse → the body stands there and eats → 경험치, and maybe a part.**

### Hitting — the rule that was missing entirely

```gdscript
## In World. Returns how many creatures were hit. THE one place damage is dealt to a creature.
func strike(origin: Vector2, facing: Vector2, part: int, attacker_force: int) -> int
```

- **`Parts.SHAPE[part] == ARC`**: a creature at `k` is hit when **both** hold —
  `origin.distance_to(critter_pos[k]) <= Parts.RANGE[part] + critter_radius(k)` and
  `abs(facing.angle_to(critter_pos[k] - origin)) <= Parts.ARC[part] * 0.5`.
  **`RANGE` is measured from the attacker's centre and the target's radius is added**, so a boss is hittable
  from where it looks hittable
- **It hits EVERY creature that satisfies it**, not the nearest one. A cone that hits one target is a
  different weapon, and *how many it hits* is the axis the next habitat's parts vary
- **`SELF` and `NONE` hit nothing** and `strike()` is not called for them
- **Damage is the attacker's force, in both directions** ([why](../../decisions/the-boss-is-not-gated.md)).
  `critter_hp[k] -= attacker_force`; at `<= 0` the creature dies and leaves a corpse
- **A creature that reaches the host** takes **its own force** off `host_hp`, then `HOST_HIT_GRACE`.
- ⚠ **A creature that reaches a clone DAMAGES it** ([why](../../decisions/the-clone-has-hp.md)). This line said
  the clone died outright and it does not. **A clone carries hp like anything else**: `force × HP_PER_FORCE`,
  a stored column on `Swarm`, halved with the force it came from when `F` divides the body. Its cargo, its
  force and its worn part are lost **when that hp reaches zero and not before**
- **A clone attacks whatever it touches**, every `Rules.CLONE_ATTACK_PERIOD` (1.2s), no aiming, damage = its
  own force ([why](../../decisions/clones-attack-on-contact.md)). ⚠ **This is what makes a wide swarm cost
  something**: spread out among crows, clones trade hits and lose
- **Contact is centre-to-centre against the sum of the radii** — `Rules.BODY_RADIUS` for the host,
  `Rules.CLONE_BODY_RADIUS` for a clone, `critter_radius(k)` for the creature. Both constants exist since
  plan 2 for exactly this line

⇒ **This is what makes the boss dangerous without gating it.** A force-10 host **can** walk up to a force-120
boss and bite — that is allowed. What it costs is that the boss hits for 120: **one touch and the run is
over.** The wall is a consequence, not a threshold.

### The boss comes, and the arena closes

**The boss is on the field from the first second, visible on the minimap, and the player may go to it**
(user, 2026-08-14). After `Rules.BOSS_HUNT_AT` (150s) it stops wandering and **walks at the host for the rest
of the run.**

When it closes to `Rules.ARENA_RADIUS` (900px):

- **The arena closes.** `World.arena_centre` is set to the midpoint and the host's movement is clamped to the
  circle, exactly as `_clamp_field` already clamps to the field
- **Every clone is summoned into it** — position clamped to the arena on the same frame, wherever it was.
  The scattered swarm is handed back at the moment it matters
- **It never re-opens.** The fight ends the run one way or the other

⚠ **And the boss's SPEED is deliberately undecided too**
([why](../../decisions/the-boss-speed-is-deferred.md)): it ships at 0.75×, which is slower than the host, so
nothing forces the closing to happen. **The arena's mechanism ships and its trigger is a tuning number left
for the first play.** Do not write a check that waits for it — every arena check drives the boss to
`ARENA_RADIUS` by hand.

⚠ **Half of "you cannot escape" is deliberately undecided** — the user said so in as many words
([the boss cannot be out-run](../../decisions/the-boss-cannot-be-outrun.md)). **What ships is the wall and the
summon**; boss attack patterns stay undesigned. It walks and it hits. Say so out loud rather than inventing
three attacks nobody asked for.

### The corpse, and eating it

```gdscript
var corpse_pos := PackedVector2Array()
var corpse_species := PackedInt32Array()
var corpse_force := PackedInt32Array()        ## what it was worth. Copied at death, never a live index
var corpse_progress := PackedFloat32Array()   ## 0..1
var corpse_count := 0
```

⚠ **`_remove_corpse(i)` is a function this plan must write**, and the first draft did not have one at all.
Consuming a corpse removes a row from a five-column flat table; without the swap, another corpse's progress,
species and force are read from a stale row. **`CLAUDE.md`'s rule about never caching a corpse index stands
on this function existing.**

- A dead creature leaves a corpse **where it fell**, carrying **copies** of its species and force
- **`Rules.CORPSE_MAX` is 64 and the table is preallocated.** At the cap, a new kill leaves no corpse — it is
  not worth evicting an older one, because "I came back and my kill was gone" is a bug report
- **The reach is named and it exists**: `corpse_reach(i, is_host)` returns
  `(EAT_RADIUS_HOST if is_host else EAT_RADIUS_CLONE) + corpse_radius(i)`. ⚠ The first draft wrote
  `EAT_RADIUS`, **a constant that does not exist anywhere in the repo** — and the bug the user caught on the
  first play was exactly this: an eat radius smaller than the body, so food had to be run over dead centre.
  **Two constant-against-constant checks pin it forever**: `EAT_RADIUS_HOST > BODY_RADIUS` and
  `EAT_RADIUS_CLONE > CLONE_BODY_RADIUS` (both already written in plan 2 — do not write a third copy)
- ⚠ **Progress advances ONCE per frame, not once per eater.** Forty clones on the boss would finish a
  six-second meal in 0.15s — and forty on one point is exactly what `1` and `V` produce, so the beat would
  vanish at the one moment it was built for. **The meal takes the same time whoever is eating.** The reward
  goes to whoever is standing on it when it completes, **host first if the host is among them**
- **Progress is kept when the eater walks away.** Coming back resumes. This is what makes interrupting a meal
  a real cost rather than an annoyance
- **A body eats one corpse at a time** — the nearest in reach, recomputed every frame like `_nearest_food`
- At `1.0` the corpse is consumed: **`corpse_force × Rules.EXP_PER_FORCE` 경험치** goes to the eater —
  `swarm.eat(0, ...)` for the host, `swarm.eat(i, ...)` for a clone, which puts it in `carried` where it can
  still be lost. **A corpse is worth what the individual was worth**: a force-40 horse pays four crows
- **`EAT_TIME` is proportional to the corpse's force**: `corpse_force × Rules.EAT_TIME_PER_FORCE`. A crow is
  half a second; the boss is six. ⚠ **Three planned checks used it as if it were a single constant** — a flat
  implementation would have shipped green, and "a crow is a mouthful, the boss is the end of the run" is the
  whole beat
- ⚠ **The part roll is the CLONE's path only.** A clone that finishes a corpse wears a part from it; **the
  host gets nothing but 경험치.** The host's parts come from cards and only from there
  ([why](../../decisions/host-parts-come-from-cards-only.md))

### Clones wear what they kill

```gdscript
# on Swarm — declared HERE, and this plan is the one that owns it
var worn := PackedInt32Array()   ## one part id per body, -1 = none. Index 0 (the host) is always -1
```

⚠ **`worn` is the ~~ninth~~ TENTH column** — plan 2 landed `force` as the ninth and this line was written
before it — **and it needs THREE maintenance points, not four**: `setup()`'s resize (and `worn[0] = -1`),
`add_clone()` (a new body wears nothing), and `remove_at()`'s **swap**. Miss the swap and a dead clone's part
lands on a survivor, silently. ⚠ **The split is not a fourth point and adding one is the trap**: `_split_fire`
goes through `add_clone()`, which hardcodes every column, so the child inherits `-1` for free. Giving
`add_clone()` a `worn` argument is what would create the fourth point this line warned about.

⚠ **And `hp` is a second new column on `Swarm`** ([why](../../decisions/the-clone-has-hp.md)). It obeys the
same discipline and it is **the one column with a FOURTH maintenance point**: the split writes it twice,
because `F` lowers the parent's force after the child already exists, so there is nowhere else the parent's
hp can be corrected. **hp is conserved across the split, never recomputed to full** — a recompute makes `F` a
heal button, and splitting is not a power-up.

- A clone that finishes a corpse rolls `Rules.PART_DROP_CHANCE` (0.5) and on success wears the part, gaining
  `Parts.FORCE[part]` on its own `force` row **and `Parts.HP[part]` on its `hp` row**. ⚠ **A crow corpse rolls
  too, and it is the common one** ([why](../../decisions/the-crow-gives-three-parts.md)): the crow's three
  parts are what open the card pool on the
  first minute, so a run that never corners a horse still sees cards. The pool a corpse draws from is the
  `Parts` table filtered by species **and by the `DROPS` column** — 말 갈기 and 말 폐활량 are rows this build
  does not hand out
- **A clone wears one part, not eleven.** If it already wears one, the new part replaces it and the old
  force is subtracted — the same written-never-derived rule as the host's
  ([why](../../decisions/force-is-stored-not-derived.md))
- If the part is an active, the clone fires it on cooldown with no aiming
- **`V` takes the clone's force and cargo, not its part.** Absorbing is not wearing; the host's slots come
  from cards

⇒ **By the end of a run the swarm is forty creatures doing different things.** That is the screenshot this
game sells, and it costs one index per body.

## The food layer that gives no parts

Grass and scattered small food. `src/sim/food.gd` **stays exactly as it is** — eaten on contact, instantly,
no corpse. **Only creatures need the eating beat**; a timer on the game's calmest action buys nothing.

## The number under the body

**The user, 2026-08-14: draw force under every body, clones included.**

- **Under the host, under every clone, under every creature.** No UI panel — the comparison happens without
  moving your eyes
- **When bodies are packed together, draw one number: the sum.** Cluster at `Look.FORCE_CLUSTER_RADIUS`
  (48px), drawn at the cluster's centroid. Three rules, each of which would have destroyed the readout:
  - **Mine and theirs never share a cluster.** A swarm of 8 among crows of 3 must not read `11`
  - **The host is never absorbed into one.** It always draws its own number
  - **Do not use `SimGrid.neighbours()` for this.** It truncates at `NEIGHBOUR_CAP` (8) by design, so a pile
    of 40 would sum to 8. Walk the bodies
- **Only force gets a number.** Something coming at you is attacking; disposition needs no marker
- **A species never eaten shows `?`.** ⚠ **The boss is the exception and shows its 120 from the first
  second** — by the rule it would read `?` all run, and *seeing the number you cannot yet reach* is the arc.
  `species_eaten` is written when a corpse is **finished**, in first-eaten order, and lives on `World`

## The minimap

**The user asked for one at 3840×2160.** Bottom-right, `Look.MINIMAP_*`.

- The field's rectangle, the camera's rectangle inside it
- The host as one mark, clones as smaller marks, **the boss always shown**, other creatures only within
  ~~`Rules.`~~**`Look.MINIMAP_SHOW_DIST`** of the host. ⚠ **It decides what is DRAWN and nothing else**, so it
  goes in `look.gd` with the rest of the map's numbers — the folder contract, not a preference
- **It draws from `world`, never from the view**, through its own `_paint_minimap` leaf hook

## Numbers

| Constant | Value | Why this one |
|---|---|---|
| `HP_PER_FORCE` | `3` | a force-10 host kills a force-10 crow in **three** hits — the design's own words |
| `EAT_TIME_PER_FORCE` | `0.05` s | crow 0.5s · horse ~1.75s · boss 6s |
| `EXP_PER_FORCE` | ~~`1.0`~~ **read `rules.gd`** | ⚠ **1.0 was measured against the wrong thing and is superseded by the constant.** A crumb of grass pays 1.0 and there are 500 spots respawning: at 1.0 the optimal run is split-and-graze and hunting is a hobby, which is planning principle 1's own failure mode. The constant carries the ratio and its reasoning; do not restate it here |
| `CROW_FORCE` | `8–12` | the number under a body has to compare at a glance |
| `HORSE_FORCE` | `30–40` | three to four crows, and it cannot be caught by running |
| `BOSS_FORCE` | `120` | just a large number. Damage is the attacker's force, so one touch ends the run |
| `CROW_SPEED` | `0.55 ×` host | you walk up to it. It does not run |
| `HORSE_SPEED` | `1.15 ×` host | **faster than the swarm too** (230 > 215) — that is the point |
| `BOSS_SPEED` | `0.75 ×` host | you can walk away, until the arena closes. ⚠ **This number is deliberately left for the first play session** ([why](../../decisions/the-boss-speed-is-deferred.md)). It is below the host's 200, so **a player who keeps walking is never caught and the arena may never close on its own**; that is accepted, it is one constant to raise, and **no check asserts self-closure** |
| ~~`SPAWN_CROW_CHANCE`~~ **`SPECIES_SPAWN_WEIGHT`** | ~~`0.7`~~ **read `rules.gd`** | ⚠ **Deleted 2026-08-15** with the jump to seven species. A relative weight per species, summed at the call site rather than assumed to total anything — the crow still outweighs the horse, and the boss's row is 0 |
| `CROW_COUNTER_TIME` | `2.0` s | long enough that a careless second bite costs something |
| `BOSS_HUNT_AT` | `150` s | it comes for you before the run is old |
| `ARENA_RADIUS` | `900` px | wide enough to move in, tight enough that the swarm is one swarm |
| `BOSS_SPAWN_MIN_DIST` | ~~`2200` px~~ **read `rules.gd`** | ⚠ **2200 exceeds the field's own centre-to-corner distance**, so it asked for four slivers of a few pixels and a rejection sampler falls through them. Visible on the minimap from the first second and a walk away is the requirement; the constant is the number |
| `ROCK_COUNT` / radius | `40` / `40–90` | enough walls to herd against without a maze |
| `WATER_COUNT` / radius | `12` / `90–180` | rare enough that finding one is a plan |
| `WATER_SLOW` | `0.6 ×` | slow enough to feel, not slow enough to trap |
| `ROCK_CLEAR_DIST` | `400` px | the run does not open wedged in a rock |
| `CORPSE_MAX` | `64` | preallocated like every other flat table |
| `PART_DROP_CHANCE` | `0.5` | **a CLONE's chance off a corpse.** The host's parts never roll |
| `CLONE_ATTACK_PERIOD` | `1.2` s | slower than the host's bite, for the same reason its mouth is slower |
| `Look.MINIMAP_SHOW_DIST` | `1600` px | the map is orientation, not intelligence |
| `Look.FORCE_CLUSTER_RADIUS` | `48` px | a readout rule, not a rule about what happens |

**All guesses except the force scale. Expect every one to move on the first session.**

⚠ **Four rows above are named for what they describe, not for a constant that exists.** `CROW_FORCE`,
`HORSE_FORCE`, `BOSS_FORCE`, `CROW_SPEED`, `HORSE_SPEED` and `BOSS_SPEED` are **one row each of
`SPECIES_FORCE_MIN` / `SPECIES_FORCE_MAX` / `SPECIES_SPEED_MUL`**, indexed by `Parts.Species`. Grepping the
names in this table finds nothing; grep the arrays.

## Nets

New `tests/nets/net_field.gd`, `net_eating.gd` and `net_terrain.gd`; `net_hunt.gd` is rewritten around the
two axes. ⚠ **This plan lands the most checks of the four — call `harness-manager` the moment it is green**,
and watch net 7's seed loop and net 17's forty-clone beat, which are the two slow shapes.

**Every check names the mutation that must redden it.**

1. **The field at `t = 0`**: eight crows, three horses, exactly one boss — counted by species, against
   literals. *Mutation: let `_spawn_critter` roll the boss*
2. `_spawn_critter` writes **all ~~five~~ six** columns: spawn one at 45s and assert its force is in range and
   its hp is `force × 3`. *Mutation: drop the `critter_hp` line — resize's zero makes it a corpse on the first hit*
3. **Kill a creature that is not the last row**; the survivor's ~~five~~ six fields are its own, against
   literals — **and `boss_index` still points at the boss**, which is the one thing the swap can break that is
   not a column
4. Disposition never changes: step a horse for 10s beside a swarm of 40 and it still flees
5. The horse flees **a clone** as readily as the host — pin a clone-only case
6. **The horse cannot be caught in a straight line**: 5 seconds of a clone chasing at `CLONE_SPEED_FOLLOW`
   and the gap **grew**. *Mutation: `HORSE_SPEED` back below the clone's — this is the check the review
   found nobody had written*
7. **The speed ordering, literal to literal**: `HORSE > CLONE_FOLLOW > HOST > BOSS > CLONE_SCATTER > CROW`
8. **The crow counters**: it sits still beside a body, is struck, and then moves **toward** it for
   `CROW_COUNTER_TIME` and no longer. *Mutation: make it always passive*
9. `strike()` hits **every** creature in the cone — three crows in the arc, all three take damage; one behind
   the host takes none. *Mutation: return after the first hit*
10. `strike()`'s reach includes the target's radius: a boss at `RANGE + 40` is hit, a crow at the same
    distance is not. *Mutation: drop `critter_radius(k)` from the comparison*
11. Damage is the attacker's force both ways: a force-10 host needs exactly **three** hits on a force-10 crow
    (hp 30); **and a boss reaching the host takes 120 off `host_hp`** — the run ends in one touch. *The
    boss→host direction had no check at all*
12. ⚠ **Reaching a clone takes hp off it** (user decided). A hit leaves it alive and lighter; only the hit
    that empties `Swarm.hp` takes its cargo, its force and its worn part. **Both halves need a check** — the
    survival and the death — and the death one must kill a clone that is **not** the last row
13. A clone attacks on contact every `CLONE_ATTACK_PERIOD` — assert the creature's hp falls with **no key
    pressed**. *Mutation: delete the contact attack; nothing else in the round sees it*
14. Killing leaves a corpse **at the position it died**, and the creature is gone from the arrays
15. **Eating is not instant, and the check measures the process**: at half `EAT_TIME`, `corpse_progress` is
    within 0.05 of **0.5**, the corpse exists, and 경험치 has not moved. *"Zero cells at half time" is true
    when eating never started at all*
16. **`EAT_TIME` is proportional**: a boss corpse takes **twelve times** a crow corpse, measured by stepping.
    *Mutation: a flat constant — which is how all three original checks were written*
17. **Forty clones on one corpse take the same time as one** — elapsed time equal, not merely "it was eaten"
18. Walking away at 60% and returning finishes it; the total standing time is unchanged
19. Finishing a corpse pays `force × EXP_PER_FORCE`, into `carried` for a clone and into `banked` for the
    host — and **`eaten` moves exactly once**
20. **The part roll is the clone's only**: the host finishes ten horse corpses and wears nothing
21. **`PART_DROP_CHANCE` is measured as a ratio**, not as "sometimes": **ten seeds × 20 corpses**, and the
    rate lands in 0.35–0.65. *One seed is one sample fifty times over — `net_hunt` already wrote that lesson
    down. Mutation: 1.0 or 0.02 must both go red*
22. A clone that wears a second part **subtracts the first's force** before adding the new one
23. **`worn` survives the swap**: three clones with different parts, remove index 1, and the survivor at
    index 1 wears its own. And a **split child wears `-1`**, never its parent's part
24. Rocks: a body walked straight at a rock **stops outside it** — literal coordinates, and the same for a
    creature. *Mutation: apply `push_out` to bodies only*
25. Water: a body inside moves at `WATER_SLOW` (measured per frame) **and a fleeing horse 300px away does not
    react to it**. *Mutation: keep the slow, drop the hiding — two effects, two checks*
26. The boss walks at the host after `BOSS_HUNT_AT` and not before
27. **The arena closes and summons**: with a clone 3000px away, close the boss to `ARENA_RADIUS` and assert
    the clone is inside the arena on that frame, and that the host cannot leave it
28. Eating the boss sets `stage_cleared`; eating anything else never does
29. `Rules` no longer carries `FORCE_PER_THREAT`; `World` no longer has `is_hunter_of` or `critter_threat`
30. **Size never inverts**: max crow radius `<` min horse radius `<` min boss radius, from the constants
31. **Cluster labels, driven, and the two checks agree**: 40 clones on one point plus the host draw
    **exactly two** labels — one of the summed clone force, one of the host's — and the sum is **not** 8.
    Spread them past `FORCE_CLUSTER_RADIUS` and it is 41. *The first draft's nets 12 and 20 asserted 1 and 2
    for the same setup; no implementation could satisfy both*
32. A crow at force 10 and a clone at force 5 standing together draw **two** labels, not one `15`
33. A species never eaten draws `?`; after one is eaten it draws the number; **the boss draws `120` from
    `t = 0`**
34. `species_eaten` is in **first-eaten order** — eat horse then crow, and assert the order, not the set
35. Minimap: `_paint_minimap` receives the boss's mark **always** and a crow at `MINIMAP_SHOW_DIST + 100`
    **never** — literal coordinates, not coordinates read back from the map

## Acceptance

**The user plays one grassland run end to end** and reports: whether the horse stops being uncatchable at a
moment they can name, whether standing over a corpse feels tense rather than slow, whether the arena closing
reads as the run's last act, and whether the swarm of forty doing different things reads on screen.
