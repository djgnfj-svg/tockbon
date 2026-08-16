# Stages and evolution

**One line**: One cell eats its way through a habitat, **evolves into what it ate**, swallows the boss living
there, and walks into the next habitat carrying the body it built.

**Implemented**: partial — plan 3 built **the eleven slots, the part table, wearing and digesting, and the
species trait** (`body-and-parts`), and **plan 4 built the field they live in**: three species, the corpse
beat, the ground, the boss and its arena all run (`grassland-field`). Habitats, evolution across stages and
chimeras are still none of them in `src/`
**Accepted**: none. Every line below came out of one planning conversation on 2026-08-13. **Nothing here
has been played**, and planning principle 2 says planning cannot judge fun

⚠ **This doc supersedes parts of the GDD** (`cell-game.md`): the card **price** is deleted, the
five-minute boss cadence is replaced by "swallow the boss", and tiers are replaced by habitats.
Where the two disagree, this one is newer. The GDD has been edited at those points rather than left to rot.

⚠ **And a planning session on 2026-08-14 edited this doc in turn — twice.** First six changes, then six more
after four adversarial reviews of the plans. All from the user, all written into the sections below rather
than appended here. The first six: **slots are eleven** · **`1` gathers at the
host** · **`3` sends the swarm at the mouse point** · **every one of the three keys is an overwritable
square** · **eating a kill takes time and leaves a corpse** · **the August scope is two species**.
**And the word "apex" is dropped — it did not survive contact with the user. Say boss.**

The second six, from the review: **an active's reach is written on the part**, not on combat · **the host's
parts come from cards only** · **a corpse pays its own force in cells** · **nothing gates the boss —
damage is the attacker's force both ways** · **the run opens alone** · **the camera pulls back as the swarm
grows**, which is the answer to the field feeling small.
**The buildable form of all of it is [the grassland plans](../plans/3.done/grassland-whole-loop.md), and
where this doc and a plan disagree about an August number, the plan is newer.**

---

## The two loops

**The user requires both of these to be written down explicitly, in any GDD.** Rules alone do not show the
rhythm.

**Session loop — a round trip, tens of seconds**
`F` split → `2` scatter → clones farm on their own → ⚠ **`1` calls them to the host** (changed 2026-08-14;
it used to place a rendezvous on the ground) → `V` → level-up. **`3` is the other half of the pair**: it
sends the swarm into ground the host is not standing in, and it is the key that gets clones killed.
⚠ **Absorption kills the clone and takes its force back** — see *Splitting and absorbing* below. The
GDD's old rule that a harvest never shrinks the swarm is dead; `F` is what refills it, by hand.

**Main loop — one habitat, ~10 minutes**

1. Enter. Host alone, swarm 0
2. Grow the swarm — the session loop spins here
3. Level-up cards attach parts; evolution accumulates
4. **Force passes the boss's force — what hunted you becomes what you hunt**
5. Hunt the boss. ~~It is the only thing that drops that habitat's final part~~ — ⚠ **superseded by the
   grassland field plan: the boss gives 경험치 and the run's end, and no part at all.** See *Stages* below
6. **Absorb the entire swarm** — the great harvest, and the one time the bodies are eaten too
7. Next habitat. The old boss is now common trash, the build carries over → 1

**Step 4 is the heart.** The other six make it or follow from it.

## Splitting and absorbing — `F` and `V`

**Settled 2026-08-13.** This closes what the Open list called the largest hole: with cards turned
parts-only, nothing grew the swarm any more. **The player grows it, by hand.**

- **`F` held — split.** The host **and every clone** halve at once, so the swarm doubles: 1 → 2 → 4 → 8.
  **You cannot split yourself alone**; the user left the door open to changing that later
- **`V` — absorb everything inside a radius, in one press.** The clones in it die, and what they carried
  plus their force returns to the host
- ⚠ **Only ground food is automatic** (changed 2026-08-14). **A kill leaves a corpse and eating it takes
  time** — the body stands there, interruptible, progress kept if it walks away and comes back. The user
  asked for this in the word 쫀득, and it is a rule in `sim/` before it is an animation. See
  [Eating a kill takes time](../decisions/eating-a-kill-takes-time.md)

**`force` is the material, and the split is exact.** Halving conserves the total, so splitting buys nothing
by itself. **What it costs is concentration**: a scattered 10 cannot be spent at one point, and the lion is
a fight that only a thick body wins. That is the reason not to press it, and it needs no refund rule.

⇒ **The real risk is death, not the split.** A clone killed out there takes its share of force with it
permanently, so the total only survives if the swarm comes home. **Splitting wide is how force is lost.**

⇒ **The two keys are a pair in the hand** — `F` thins, `V` thickens — and `1` already decides where the
thickening happens. `G` was tried and dropped: the finger travels too far.

**Force is no longer parts-only.** The body carries a base force that rises with level; otherwise a bare
host has nothing to halve. Parts still add on top.

**Starting force is 1, and 1 cannot be split** — so the first level-up is what opens `F`. The onboarding is
the rule, not a tutorial line.

**Open here**: whether the 128 pool cap still means anything now that headcount comes from force · what a
clone's worn part does when it is absorbed. **Odd force and the absorb radius have placeholder answers** —
see *First numbers*.

⚠ **Force is a STORED number, not one recomputed from level and parts** (settled 2026-08-14 after review).
Recomputed, halving is undone on the next frame and **`F` becomes free** — the swarm doubles at no cost and
the conservation this whole section rests on is a fiction. Levelling and wearing a part **add** to the stored
value; splitting, absorbing and dying are the only other writers.

## Evolution replaced the card price

**The card still appears at level-up** — that was settled long before and is not reopened. What was deleted
is **the price**.

The GDD had a card read `species · slot · price` and charged that species' balance. On inspection it is
**two locks on one door**: the card pool is *already* rolled from what you have eaten, so a crocodile card
only appears once you have eaten crocodile — and then you paid crocodile again. The user rejected it on
sight. See [Card price removed](../decisions/card-price-removed.md).

What stands in its place:

- **Collect a species' parts and you evolve toward that species.** The blob visibly becomes a crocodile
- **Evolution is not a species swap — it is what you have in the slots.** A cannon on the back, cheetah
  legs, a crocodile head is the normal case. Mixing is the default
- **Going all-in on one species buys a trait.** Filling slots from one species attaches that species'
  unique trait; a mixture takes the part performance and no trait. **This is what makes going deep a
  choice instead of a bonus** — and it is where planning principle 8 (order changes the outcome) lives now:
  every card asks whether to protect the run or break it for a better part
- **Evolution is the host's alone.** Clones are free individuals: they gather and scatter on command and
  build themselves by killing, which the GDD already said and this does not change

### Depth comes from stacking, and the payout changes how you play

There are only six external slots, so a build runs out of room fast. **Three axes stack inside that
budget** (all from the user, 2026-08-13):

| Axis | What it is |
|---|---|
| **Part level** | eating the same part again levels it — `crocodile jaws Lv2`. A running total, not a replacement |
| **Class stacks** | parts from the same family combo — "amphibian ×3" fires a set effect. The family, not only the exact species |
| **The eleven slots** | the hard budget everything above competes for |

**The payout must change how the game is played, not raise a number.** The user's own example: frog legs
*and* frog thighs together turn `space` into **three chained jumps**. Each part added is another thing the
hands can do once, and by the end the same three keys play differently — which is what the GDD already
claimed and never had a mechanism for.

⇒ **This is where planning principle 8 finally lands.** Two parts producing an effect neither has alone is
a combination, not addition, and the slot budget is what makes taking one mean giving up another.

### Eleven slots — six external, five internal

Six ran out too fast to build in; twelve was too many to hold in the head; nine had no chest; ten had no
breath. **Eleven, settled 2026-08-14** after four moves in two days, all of them before anything was built
on it.

- **External slots are the ones that show.** ⚠ **They were "expensive" until 2026-08-13** — one sprite per
  species per slot — and that bill is gone: the body is drawn as a line and a worn part takes the host's
  colour, so nothing has to match anything. **What still caps them is the body**: six things sticking out of
  one small square is already as much as reads. **Six**: head · **torso** · back · forelimbs · hindlimbs · tail
- **Internal slots are free.** They were never drawn. **Five**: eyes · gut · bone · hide-or-fur · **lung**.
  **Eyes moved inside** — what they do is notice things, and that is a number, not a sprite.
  ⚠ **Lung was added on 2026-08-14** for the horse's breath, and the cheap alternative — folding it into
  `gut` — **was put to the user and refused: eyes and gut both keep their own jobs.**
  ⇒ **The count is a budget, not a shape.** It moved five times without anything being built on it, which is
  the argument for never writing it into more than one place

**Torso is the one thing that was added back.** Without it the body was head, back, limbs and tail — and a
gorilla's chest, a lion's mane and a bison's hump had nowhere to attach. It is **not** the same square as
`back`: wings and shells go on the back, bulk goes on the front.

**The three internal cuts were all duplicates.** Brain does what eyes do; lungs do what heart does; heart
does what hindlimbs already do. The five that remain **do not overlap at all** — one each for the swarm, the
economy, the fight, survival and breath:

| Internal | What it moves |
|---|---|
| **eyes** | how smart a clone is — whether it notices what is about to eat it |
| **gut** | how much a clone brings home |
| **bone** | the body's base force — the thing `F` halves |
| **hide / fur** | defence, and the body's colour |
| **lung** | **breath** — how long a movement active sustains before it drops back to base speed |

⚠ **Hide and torso split one job on purpose.** Torso is the **visible** bulk; hide is thickness that is only
a number. Folding hide into torso was the way to keep the count at nine and it was rejected — being seen and
being thick are two different things.

**Invisible was the only objection, and the body itself answers it.** The cell is a rounded square, so an
internal part changes **the drawing values rather than adding a picture**: muscle thickens the body, fur
puts an outline on it, hide deepens the colour, bone sharpens the corners. All eleven slots read on screen
and the art bill does not move — which is exactly the shape planning principle 7 asks for.

### The threshold is per set, and a part can take more than one slot

**There is no global stack number.** Two more rules came out of the same conversation and both change the
shape of the budget:

- **Each set names its own threshold.** Some fire at three parts, some at two, and **a fantastical beast's
  part can be a set of one** — catching that one thing is the whole combination
- **A part can occupy several slots.** The big ones cost more than their place: one part, three squares

⇒ **That is what turns eleven slots into a real budget rather than a bigger number.** Strong parts eat the
room the rest of the build needed, so **saving slots is itself a way to raise a build** — which is half an
answer to the open "how does a build go higher" problem, without inventing genes for it.

⇒ It also means the earlier worry is dead on both ends: the threshold was never one number to pick.

### Taking a card is irreversible — there is no inventory

**This game has no bag, only a body.** Everything below follows from refusing to build an inventory.

- **A new part in an occupied slot replaces the old one, and the old one is digested.** It is not stored, not
  listed, not recoverable. The only trace is a small push on the level gauge
- **Merging two parts was rejected on the slot budget.** Crocodile jaws plus hippo jaws is a third thing
  that has to live somewhere, and eleven slots are already spoken for. ⚠ **Its original grounds were art —
  "species art comes off one board per habitat" — and that cost no longer exists**: the body is drawn by
  code in the host's own colour ([why](../decisions/the-body-is-a-line-drawn-by-code.md))
- **Levelling only happens on the same species' same part.** `crocodile jaws Lv2` comes from another
  crocodile; a hippo jaw is a replacement, not a level
- **A multi-slot part is evicted whole the moment any one of its slots is claimed**, and the slots it also
  held are left **empty**. Wearing a head+eyes part and buying a head part digests the whole thing and
  leaves the eye slot bare
- **Which slots a part takes is written on the part, not derived from a rule.** An adjacency graph over the
  eleven slots was raised and dropped as too complicated for what it buys — **each part carries its own
  list of squares**, decided when that part is authored. One square or several, and the author picks which

⇒ **A small part can cost a big one.** That is the point of the complication, and the user chose to keep it:
without it there is never a reason to refuse a good card. Taking a card has to be able to hurt.

**Raising a build past that ceiling is an open problem the user has flagged.** Genes were floated as the
eventual answer — "three genes" — and explicitly deferred. Nothing about them is designed.

**Nothing here says what a trait actually gives.** Open.

### The clones use their actives too

**Every clone fires the active on the part it is wearing** (confirmed by the user, 2026-08-13). They eat
whatever they happen to catch, so the parts they wear are random, and **by the time the run reaches a boss
the swarm is forty different creatures doing forty different things.**

⇒ **That is the screenshot this game sells**, and it answers the GDD's standing complaint that the picture
only exists late in a run: it exists exactly where the run is going.

⇒ It also means the swarm's firepower is not a number the designer sets — it is whatever the swarm has been
eating. The host is **chosen**, the swarm is **grown**, and by the last stage the grown half is the noisier
of the two.

## Force and disposition are two separate axes

The prototype shipped one number, `threat`, and derived behaviour from it: a critter fled once the swarm
outgrew it. **The user rejected that as the model.** Two axes, and they do not talk to each other:

| Axis | What it is | Who holds it |
|---|---|---|
| **Disposition** | attacks, or flees | the **individual** — not derived from anything |
| **Force** | who wins if they meet | the **individual**, and it varies inside one species |

**Your force is the sum of the individuals' force, not the headcount.** Clones grow separately — each wears
a part from something it killed — so twenty well-fed clones can beat forty bare ones, and **the swarm's
composition is itself a build.**

The four combinations are four different problems, and folding the axes together collapses them to two:

| | weak | strong |
|---|---|---|
| **attacks** | free food — it walks into your mouth | the real threat — a scattered swarm gets shredded |
| **flees** | annoying — you have to chase it down | **the boss** — grow before you can catch it |

**When force is roughly even, left-click and right-click decide it.** A band the numbers do not settle is
what makes a fight worth taking; without it every encounter is already resolved before it starts.

### How it reads on screen

- **The number sits under the body**, not in a UI panel — mine under the host, theirs under them. The
  comparison happens without moving your eyes
- **Only force gets a number.** Disposition needs no marker: something coming at you is attacking and
  something moving away is fleeing, and that reads in one frame
- **No colour coding.** Each species will carry its own colour and an overlaid disposition tint would fight
  it. The user raised this and it is the reason colour was dropped from the readout
- **A species never eaten shows `?`** instead of a number — which is what turns the codex unlock into
  "the question marks become numbers" rather than a stat boost

## Stages

**A stage is one habitat.** ⚠ **It used to also be one art board** — species added later cost a whole board,
so a habitat was chosen first and generated in one pass. **That stopped being true on 2026-08-13**: parts
are drawn in the host's own line, so a species can be added whenever the design wants one.

- **Clearing a stage = swallowing that habitat's boss.** Not a timer, not a five-minute boss cadence
- ~~**The boss is the only source of that habitat's final part**, so clearing and building are the same act~~
  ⚠ **Struck.** [The grassland field](../plans/3.done/grassland-field.md) is newer and it gives the boss
  **no part**: it pays 경험치 like any other corpse and it ends the run. Parts come from the species you eat
  along the way, and the host's come from cards
  ([why](../decisions/host-parts-come-from-cards-only.md)). **Clearing and building stopped being the same
  act** — building happens on the way to the boss, not off it
- **On clearing, the whole swarm is absorbed** — bodies included, this once — and the next habitat starts
  with the host alone
- **The previous boss is laid out as common trash in the next habitat.** It did not get weaker; it now
  arrives in numbers. That is the reversal the GDD was built around, with no tier machinery
- **~10 minutes a stage, 4 to 6 stages.** Half-settled. Stage length is not a timer that can be set — it is
  how long the boss takes to catch, so it falls out of how fast force accumulates

### The ladder

**Insects are cut** — the user does not like them. It starts at beasts.

| Stage | Parts it gives | Why it works |
|---|---|---|
| **Swamp** | frog hindlegs · crocodile jaws · snake body | the first two cards land straight on the hands — leap is `space`, bite is left-click |
| **Jungle** | gorilla arms · leopard legs · monkey tail | the first big jump in force, and the first "strong and does not flee" |
| **Other habitats** | whatever the habitat gives | snow · deep sea · caves. Each swaps the whole species set |
| **Dinosaurs** | tyrannosaur jaws · tail · back plates · long neck · pterosaur wings | the top of the ladder. Silhouettes separate, and **it is still edible** |
| **Final boss** | undecided | after the dinosaurs, **on a stage of its own** |

Two rules pick the species:

- **The silhouette has to be strange.** On minimal art a deer and a wolf are the same shape. An anglerfish,
  a jellyfish, a crustacean, a mole are not
- **It has to be edible.** The game is chewing something and wearing its part

⚠ **Human civilisation is on hold, and the reason is not tone.** Cannons and tracks are the strongest
picture in the whole idea, but **a machine is not something you eat** — the one rule the game never breaks
would break at the last stage. Ending on dinosaurs keeps it intact. To put machines back, that sentence has
to be answered first.

**The final boss is a dragon, or human civilisation. Undecided, and it may not be reached at all.** What is
fixed is the slot: **one strong thing worth the finished build.**

## Every stage carries special individuals

**Habitat species alone is a bestiary, not a game.** Something of a different order has to show up or the
stage is not remembered. **Ordinary species are material; special individuals are events.**

| What | What it is | What it pays |
|---|---|---|
| **Fantastical beast** | the habitat's legend. Strong, and hard to catch | **a special part** — a certain reward for a hard kill |
| **Chimera** | wears several species at once. Can appear as a mid-boss | **a lot of experience** |
| **Mutant** | an ordinary species twisted — same animal, one thing different | recorded as heard: "a special cost". **The meaning was not pinned down** |

**What shows up is rolled per stage.** The same swamp comes out different every run, and **that roll carries
most of the run's randomness.**

All three are ideas, not rules. None of the payouts above is settled.

## Between runs — unlocks only

The standing decision holds: [meta unlocks, never stat boosts](../decisions/meta-unlocks-not-stat-boosts.md).
**No number is ever raised permanently**, because that forces the first run to be deliberately weak and the
first run is the one that decides whether there is a second.

What *does* get easier is a proposal, and every line of it adds **choice, information or hands** rather than
power:

| Unlock | What gets easier | Raises a number? |
|---|---|---|
| A new species enters the pool | more evolution branches; a build worth aiming at | no |
| Pick one starting part | start pointed in a direction instead of bare | no — direction only |
| A new swarm command | "hold here" and the like; the hands can do more | no — hands only |
| **Codex — species you have eaten** | the `?` under them becomes a number. You decide to fight knowing | no — information only |
| Start at a cleared habitat | the early stages are not re-ground | no — time only |

**The codex is the strongest of the five.** Without it the reversal is "I happened to win"; with it, it is
"I am taking this now" — and not one number moved.

---

## The August build — one stage, all the way

**Scope, decided 2026-08-13**: **stage 1 only, played end to end until the build is finished.** Not two
stages, not a ladder — one habitat, entered bare and left with a complete body.

⚠ **Narrowed much further on 2026-08-14, and this is the scope that is being built**: **two species — crow
and horse — plus the boss.** Small animals · herd · cheetah · lion · elephant are **not in the August build.**
⚠ ~~**three parts**, all horse: 말 다리 · 말 갈기 · 말 폐활량. **The crow gives no part**~~ — **reversed
2026-08-15** ([why](../decisions/the-crow-gives-three-parts.md)): **the crow gives three** — 까마귀 날개 ·
부리 · 발 — **and the horse gives 다리 only.** 말 갈기 and 말 폐활량 stay in the table and out of both pools.
The crow still is the opening's food; that turned out to be the argument *for* it carrying the pool, not
against.
⇒ **The four squares of the disposition × force table are still all filled**, because disposition is rolled
per individual: a crow that decided to attack is free food, a horse that decided to attack is a real fight.
**Two species is not two behaviours.** See [the grassland plans](../plans/3.done/grassland-whole-loop.md).

That pulls the art in with it: **everything stage 1 needs is made** — the monsters, the body, the parts, the
colours, the style. Nothing beyond stage 1 is drawn.

**The final boss is out of scope** and stays undecided.

### Stage 1 is grassland

**Settled 2026-08-13.** It was picked over swamp because **grassland fills all four squares of the
disposition × force table on its own**:

| | weak | strong |
|---|---|---|
| **attacks** | — | **lion**: the first time a scattered swarm gets shredded |
| **flees / ignores** | **herds** (the first food) · **cheetah** and **horse** (fast, have to be chased) | **elephant**: strong and slow, the wall before the boss |

### The boss is a chimera, not the elephant

**Settled 2026-08-13.** The elephant was the boss until the user asked whether the boss could be something
new. It is now **a strong ordinary species**, and the thing that closes the stage is built out of the
habitat's own parts:

**An elephant's bulk, a lion's head, wings, and a rhino's horn.**

⇒ **This costs no new system.** The GDD already says enemies are chimeras built from the same slots as the
player, so the boss is a part list, not a boss class. It reads on sight as *everything in this habitat at
once*, which is exactly what the player has spent the stage assembling.

⇒ It also puts **the rhino's horn in the habitat without giving the rhino a board** — the horn exists only
on the boss.

**Patterns are open.** A boss having attack patterns is expected and none is designed.

Two more things live there, and both were the user's:

- **Small animals in numbers** — crows, rodents. The bottom of the food chain, and what the swarm eats while
  it is still nothing
- **Plants are food too.** Grass and trees scattered on the ground are edible, which gives the opening
  minutes something to eat before anything has been killed — and it is the cheapest food in the game to draw

Swamp is not dead; it keeps the frog's chained `space` jump and the crocodile bite, and it is a candidate
for a later stage.

### Two layers of species, and only one of them costs art

**A habitat should be crowded, and crowding is cheap** — as long as most of what lives there gives no part.
The user asked for many species and a real food chain; the bill only lands on the half that drops parts.

- **Species that give parts** — ⚠ **the ceiling of five or six was an art bill, and the bill is gone**
  (2026-08-13, see the GDD's *Screen*). A worn part is drawn in the host's own line, so no board has to
  match another. **What limits them now is how many the player can tell apart**, which play decides
- **Everything else** — grass, ground plants, small animals, corpses. **Food only, no part, one picture
  each.** This layer can grow as long as you like, and it is what makes the field look alive
- **They eat each other too.** Force and disposition are already per-individual, so a lion hunting a herd
  needs no new machinery — and walking into that fight is a picture the design gets for free

⇒ **The only line that has to be drawn is which five or six give parts.** Everything else is a name in a
table.

### The grassland parts — candidates, nothing settled

Written down so the next session starts from something. **None of it is chosen**, and no part has a force
number.

**Six species give parts** — small animals · herd · **horse** · cheetah · lion · elephant. **This is no
longer a ceiling, only where the list stands**; more can be added when there is a reason.
⚠ **The August build ships one of them: the horse.** The table below is the habitat's eventual shape, not
the build's; read it as a list to draw from, and take the three horse rows.

| Slot | Grassland candidates |
|---|---|
| **head** | horns (herd) · jaws (lion) · trunk (elephant) |
| **torso** | mane (lion) · hump (bison) · bulk (elephant) · **horse mane** |
| **back** | crow wings — **the only one in the habitat** |
| **forelimbs** | claws (lion) · rodent paws |
| **hindlimbs** | dash (cheetah) · **gallop (horse)** · herd legs |
| **tail** | cheetah tail · **horse tail** |
| **eyes** | crow · cheetah |
| **gut** | rodent |
| **bone** | bison · elephant · horse |
| **hide/fur** | lion · cheetah · elephant |

⇒ **Only the back comes from one species**, so the crow is the one thing that has to be hunted on purpose.
⇒ **Three heads compete for left-click**, which is where the habitat's build decision sits.
⇒ **Cheetah and horse both bid for `space`, and they are not the same movement** — a dash is short and
explosive, a gallop is sustained. Two ways to move is what makes the slot a choice rather than a pickup.

**What a horse's legs look like on the body**: the first generation put them **radiating out of the rounded
square in every direction, four to eight of them** — the cell does not grow a horse, it sprouts horse legs.
Boards are in `tools/pixel/out/cell_horselegs/`. **Leg count is not controllable from the prompt**, which is
the reminder that a part ships as **one sprite bound to an anchor**, never as a whole redrawn body.

### First numbers — placeholders, so the build has something to run

**Nothing here is balanced and none of it was measured.** They exist because an implementation with no
numbers is not an implementation, and because planning principle 2 says only play can judge them.
**Expect every one of these to move on the first session.**

| Value | First number | Why this one |
|---|---|---|
| host's starting force | **10** | ~~1 cannot be split, so the first level-up is what opens `F`~~ — **splitting is the tutorial** ([why](../decisions/force-starts-at-ten.md)). The whole ladder was multiplied by ten with it |
| base force per level | ~~**+1**~~ **`Rules.FORCE_PER_LEVEL`** | ⚠ **It was re-cut for the ×10 scale in `rules.gd` and this row was not.** The constant is the number; the curve is still the user's call and still tunes in play |
| small animals · herd · horse · cheetah · lion · elephant | **10 · 20 · 30 · 30 · 50 · 80** | ⚠ **per-SPECIES centres. Force varies per individual**, and the August ranges are in [the grassland field plan](../plans/3.done/grassland-field.md) — crow **10**, horse **30–40**. Horse and cheetah tie: they differ by how they move, not by who wins |
| the boss chimera | **120** | ~~above a level-8 host, so it cannot be walked into early~~ — ⚠ **that was a gate, and [nothing gates the boss](../decisions/the-boss-is-not-gated.md).** 120 is simply large: damage is the attacker's force both ways, so contact ends the run as arithmetic, not as a rule |
| a part's force | ~~**1**, strong ones **2-3**~~ **`Parts.FORCE`, one cell per row** | parts add on top of the base and no part is worth a whole species — ⚠ **but these were pre-×10 numbers and a +1 part is invisible now.** The table is the content; read the column |
| ~~the clone tax~~ | **deleted** | ⚠ **It was never built and it is not the mechanism.** The host's mouth is worth ~2.5× a clone's because `EAT_PERIOD_HOST` is 0.6s against 1.5s — a speed, with no constant to tune and nothing to explain in the UI. This row said "inherited from the GDD unchanged" while the GDD said the opposite |
| a corpse's experience | ~~**force × 6**~~ **`Rules.EXP_PER_FORCE`** | a corpse pays what the individual was worth (user, 2026-08-14). ⚠ **The multiplier is in `rules.gd` and 6 is not it** — it is set against what grass pays, which this row never looked at. ⚠ **Say 경험치, not "cells"** — one quantity was reading as two. And ⚠ **the "every 10" threshold does not survive the ×10 scale**. The requirement **rises per level**; the numbers are set in build and tuned in play |
| damage, either direction | **the attacker's force** | [nothing gates the boss](../decisions/the-boss-is-not-gated.md) — one touch from something large ends the run, as arithmetic. ⚠ **The host's HP is `Rules.HOST_HP` and the ~~3~~ this row used to name went with the ×10 scale**; read the constant |
| starting swarm | **0** | [the run opens alone](../decisions/the-run-opens-alone.md) |
| gut, at its best | **90%** | it closes the gap and never inverts it |
| absorb radius | **4x the host's body** | wide enough that a rallied swarm goes in one press, tight enough to miss stragglers |

**Force is an integer and splitting is exact, so odd numbers need a rule: the host keeps the larger half.**
5 becomes 3 and 2. The total is conserved, and the host — which fights in front — is the one that keeps the
odd point.

⇒ **The reason they are all small**: the number is drawn under the body, and two digits stop being
comparable at a glance. If play needs finer resolution, the fix is more slots, not bigger numbers.

## Open

Everything on this list came up in the same conversation and none of it was closed.

- **What the five internal slots actually give in numbers.** Each has a job now — cutting the duplicates is
  what gave them one — but not one of them has a value
- ~~**How the swarm multiplies at all.**~~ **Closed 2026-08-13** — `F` splits, `V` absorbs. See
  *Splitting and absorbing*. The level-up no longer grows the swarm at all
- **How high a build can go, and by what.** Genes were named and deferred; nothing replaces them yet
- **Whether part level is capped**, and whether a levelled part still counts once toward a class stack
- **What a species trait actually gives.** The name exists, the content does not. ⚠ **The August build
  ships one placeholder trait** — three horse parts and a gallop stops draining breath — because a trait
  nobody can reach cannot be judged, and the user asked for traits in the August build (2026-08-14)
- **What each part's force contribution is.** Parts each carry a different amount and, outside the three
  horse parts numbered on 2026-08-14, no part has one. **The parts-only half of that rule is gone** — the body has a base force too, or `F` has nothing to
  halve at level 1
- **When a clone fires its active.** They all fire (below); on cooldown with no aiming is the shape that
  fits "clones are stupid", but it is not written down as a rule yet
- ~~**Whether the host's own evolution counts toward force.**~~ **Closed** — the host holds force of its own,
  or there is nothing for `F` to halve. What is still open is how much of it comes from parts
- **What a chimera drops when eaten.** It wears several species, so one part does not cover it
- **What a mutant gives.** The phrase used was "a special cost" and it was not pinned down
- **What separates a fantastical beast from a strong ordinary one** beyond "a special part"
- **How wide the even-force band is** — where the hands decide instead of the numbers
- **Whether the final boss is eaten or merely killed.** Eating it leaves nothing after; not eating it breaks
  the game's one rule at the very end
- **Where the ladder stops.** Dinosaurs, or machines with the eating rule solved
- **Six stages is a 60-minute run.** In a die-and-restart structure that may be too long to bear. Play decides
- ~~**Field size, and therefore whether a minimap is needed.**~~ **Closed 2026-08-14** — the field stays
  **3840x2160 and there is a minimap.** The swarm leaves the screen, which is exactly the condition that
  requires one
- ~~**Force numbers under forty clones would be a field of digits.**~~ **Closed 2026-08-14** — **every body
  carries its number, clones included, and a packed group draws one summed number instead.** The sum is the
  figure that actually decides the fight, so the readable form and the useful form are the same form
- ~~**What the ending is.**~~ **Closed 2026-08-14** — boss eaten or host dead, one ending screen, both
  routes back. Never a clock. See [the run shell](../plans/3.done/run-shell.md)
- **Colour, entirely.** No species colour, no field palette, nothing. This is decided by generating real
  candidates and pointing at one, never by discussion (`CLAUDE.md`, `tools/pixel/`)

## Where the pictures are

`cell-loops.html`, next to this file — the loops, the 2×2, the under-the-body readout, the slot body
and the stage table, drawn. It was published as an artifact for the user on 2026-08-13 and the copy in this
folder is the source it is published from.

**It is a view of this doc, not a second source.** When the two disagree, fix this file first, then the page.
