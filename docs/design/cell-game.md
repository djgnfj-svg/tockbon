# Cell game — the GDD

**One line**: One square cell splits into a swarm, eats whatever it can catch, and spends what it digested
on **real animals' body parts** — until it stands at the top of the food chain.

**Implemented**: partial — the swarm and its two commands, the rendezvous, carrying and absorption, the
level-up pick, automatic eating and the ecosystem all run — see `proto-round-trip`. **Not built**: parts,
slots, chimeras, bosses, biomes, meta unlocks, the `3` command. ⚠ **Species currencies and tiers are not
unbuilt — they were CUT from the design** (2026-08-13). Listing them as unbuilt is how a later session goes
and builds them.
**Accepted**: **the core loop passed** — the user played the prototype and confirmed the fun. Everything
above that is unbuilt is still `unseen`, and the parts economy is the largest unlooked-at piece.

⚠ **A planning conversation on 2026-08-13 changed this document again.** Card prices are gone, evolution
replaces the parts economy's gate, force and disposition are two axes, and tiers are habitats.
**`stages-and-evolution` holds all of it** — the sections below are edited where they were made false, and
that doc is newer wherever the two still disagree.

⚠ **And a second one on 2026-08-14 changed it once more.** **Slots are eleven, not ten** (lungs got a
square); **`1` gathers the swarm at the host**, not at a placed point; **every one of the three keys is an
overwritable square**, `bite` included; **eating a kill takes time and leaves a corpse**, it is not
automatic; and **the word "apex" is dead — say boss.** The August scope came down to **one stage, two
species and one boss**. All of it is in
[the grassland plans](../plans/1.ready/grassland-whole-loop.md), and the paragraphs below are edited where
they were made false rather than left to rot.

⚠ **The prototype already changed this document once, and will again.** Predators became critters carrying
a `threat`, and the swarm's size against that number decides which of the two is the meal — **that is this
doc's tier reversal, with no tiers and no boss.** What tiers are still for is open; see the tail of the
prototype doc.

**View: top-down.** Carried over unchanged from the previous direction. Nothing in this design needs
gravity, and `scatter` spreading in every direction needs the opposite of a side view.

Reference point: *Everything is Crab* crossed with a roguelike, **more minimal than either**
(`next-game.md`). Art is a square body with parts stuck on its sides.

---

## Why this is a game

Scored against the planning principles — **including the ones it does not pass.**

- **1, hands never idle — passes.** You drive one body directly while the swarm takes commands and you
  fight with left / right / space. Nothing plays itself
- **5, one sentence — passes.** The line at the top of this doc is the whole pitch
- **6, one screenshot — passes late.** A square blob wearing a crocodile jaw, cheetah legs and bird wings,
  dragging forty smaller blobs behind it. The first minutes are one bare square, and nothing yet fixes that
- **7, art doesn't block — passes with a bill.** A square plus part sprites, and the same system draws the
  enemies. But the sprites come off one generation board per species, so **a species added later is a whole
  board**, not one picture
- **4, two systems — over budget.** ~~Six nouns are live: host · clone · species experience · parts ·
  chimera · tier.~~ **Five: host · clone · experience · parts · chimera.** Tiers were cut for habitats
  ([why](../decisions/ladder-of-habitats-not-tiers.md)); "species experience" is just experience now
  ([why](../decisions/force-starts-at-ten.md)). The defence is that they collapse into two verbs — hunt
  with the swarm, spend what it brings home
- **8, order changes the outcome — weakest score here.** ~~One rule carries it: a part bought into an
  occupied slot replaces it and refunds half.~~ **There is no half-refund** — the price went with the
  currency ([why](../decisions/card-price-removed.md)). What carries it now is **traits**: going deep on one
  species buys one, breaking the set gives it up. See *Order changes the outcome* in `stages-and-evolution`

---

## Behavior

### The body and the swarm

- You control **one cell — the host**. It moves, it eats, it uses the three bound actions
- ⚠ **Splitting is a button after all — `F` held.** It was a level-up reward until 2026-08-13, and the rule
  now lives in *Splitting and absorbing* in `stages-and-evolution`. You still never select a clone
  individually
- **The swarm array is 128 long; the live cap is `CLONE_CAP` at 40.** 128 is an allocation bound, not a
  reachable headcount — **a net written against 128 tests a state the game cannot produce.** ⚠ Its design
  grounds are gone — headcount comes from force since 2026-08-13, not from level — but the allocation
  stands until something measures otherwise
- Clones obey **commands on the number keys** — ⚠ **`1` gathers them at the host** (changed 2026-08-14) ·
  `2 scatter` · `3` sends them at the mouse point and they stay and fight there. They are pressed like
  abilities, not chosen from a menu, and **`3` requires you to point**: no auto-targeting, or the game
  fights on its own
- **The command list is expected to grow** ("gather here", and others) as play shows what is missing. Three
  is the floor, not the design
- A scattered clone **feeds itself automatically** and carries what it ate **in its own body**

**Clones are rows in one flat array driven by a single manager. No clone is a Node.** The pool is allocated
once and never grows.

**Clones do not collide with each other.** Separation is a per-clone push away from the nearest few
neighbours found on a uniform grid — it exists so forty blobs read as forty blobs, and it is a rendering
requirement, not physics. Clones still meet the world and the enemies.

### Clones are stupid, and that is the whole answer to "what are your hands doing"

A scattered clone **eats and fights, and understands nothing else.** It does not flee, it does not notice
what is about to kill it, and it will happily stand still eating while something eats it.

⇒ Scattering does not free the player's hands, it **fills them**. You are hunting personally at the same
time, and `follow` doubles as the rescue button — a clone that dies out there takes everything it was
carrying, so watching the swarm is not optional.

**Intelligence is a thing you buy.** The eyes slot is what makes a clone notice danger, and a clone that
has eaten its way into a pair of eyes gets smarter on its own. Stupidity is the floor, not the ceiling.

⇒ This is the answer to planning principle 1 — "watching something run itself" is what the defense
direction was scrapped over, and an auto-feeding swarm sat in exactly that failure mode until the clones
were made this dumb.

### Harvest — why you ever regroup

**A clone's experience is not yours until it comes home.**

1. Scattered clones eat and accumulate species experience privately
2. ⚠ **`1` gathers the swarm at the host, and the point moves as the host moves** (user, 2026-08-14). The
   rule below it — a rendezvous placed on the ground — **lost**, and the reasoning that argued for it is
   kept struck through so the same case is not re-argued
3. ⚠ **`V` absorbs every clone inside a radius in one press** (2026-08-13). It is not contact-automatic and
   it is not one clone at a time — forty clones would be forty presses. **The absorbed clones die**, and
   their force comes back to the host
4. A clone killed before it is absorbed **takes everything it carried with it** — its force included

> ~~**The press is a placed rendezvous**, not a recall to wherever the host happens to be. The host must
> walk into ground it chose while the swarm was still out. Recalling to the host instead lets it park in
> cleared ground while the clones bear the whole return trip — the exact inverse of the tension here.~~
>
> **Dead 2026-08-14.** The user wants `1` to mean *come to me* and gave `3` the job of *go there*. The
> tension the struck paragraph protected is not lost: **`3` is the key that sends the swarm into ground the
> host is not standing in**, and it is the one that gets clones killed. See
> [Rally is to the host](../decisions/rally-is-to-the-host.md).

⇒ Scattering wide earns more and risks more. **Density is the combat axis and the economy axis at once.**

⚠ **This rule is dead as of 2026-08-13**: absorption *does* shrink the swarm, and nothing refills it on its
own. **`F` refills it**, at the price of halving everyone — so the forty-blob picture is something the
player rebuilds by hand each round trip rather than something the game hands back.
The old text read: *absorption spends what a clone carried, not the clone; the swarm's size is set by level
and refills over the next few seconds.*

### The economy — one gauge, two numbers per species

Three things are tracked and they never collapse into each other.

| Tracked | Behaviour | What it drives |
|---|---|---|
| **Level gauge** | one bar. Fills from **any** food regardless of species, and is **never spent** | Level-ups |
| **Species total** | per species. **Only ever rises** | Which species show up on the cards |
| ~~**Species balance**~~ | ~~per species, drops when a part is bought~~ | **Deleted 2026-08-13** — nothing spends it any more |

⚠ **A level-up now does one thing: three cards appear.** The **+1 clone** half died on 2026-08-13 — the
swarm is grown with `F`, never by levelling. What the level does raise is the host's **base force**, which
is what `F` has to halve.

⚠ **Cards have no price.** Each reads `species · slot`, and taking one costs nothing.
The rule that charged the species' balance is dead and the reason is one sentence — the pool is *already*
rolled from what you ate, so the price was a second lock on the same door. See
[Card price removed](../decisions/card-price-removed.md); what replaced it as the reason to go deep on one
species is the **species trait** in `stages-and-evolution`.

**A part bought into an occupied slot replaces it.** Slots are the only scarce thing on the body. With the
balance gone there is no half-refund, and the order parts arrive in becomes a decision through **traits**
instead: filling slots from one species buys its trait, and breaking the set for a better part gives it up.

**Which species a card shows is rolled from the totals, weighted by experience amount rather than kill
count** — a big crocodile is not one rabbit. Three crocodiles' worth against one rabbit's makes each card
3/4 crocodile. Once a species is drawn, the part is rolled *within* that species.

⇒ **Totals and balances are separate on purpose.** Merge them and buying crocodile parts is what stops
crocodiles appearing.

⚠ **The 50% tax was never built and is not the mechanism.** The prototype expressed it as a **speed**
instead — the host's mouth is worth ~2.5× a clone's because `EAT_PERIOD_HOST` is 0.6s against the clone's
1.5s — with no constant to tune and nothing to explain in the UI. `rules.gd` is where that lives.
**What keeps the host in front is its bite rate, not a percentage.**

**The gut raises what a clone brings home, and nothing else.** The host's own bite is always 100% and the
gut can never exceed it — it closes the gap, it never inverts it. It also spends one of the **five** internal
slots, so **gut is bought against eyes, bone, hide and lung.**

> **Cross-species conversion was cut.** It read as a tax on mixing species — the thing the game is selling —
> and on inspection it was never a tax at all, only a bailout nobody had to take. Removing it takes a
> number, a rule and a UI panel out of the game at once.

⇒ **The rhythm this produces is the point.** Scatter, hunt wide, call them home, and the gauge lurches as a
dozen clones are swallowed in a row — **level-ups firing back to back, cards stacking up.** Growth is not a
trickle; it arrives when the swarm does.

Other ratios exist (gut rates, candidate weights, the rising chance on a miss) and **none of them has been
picked.**

### Parts — eleven slots

⚠ **Was eight, then twelve, then nine, then ten, and **eleven since 2026-08-14** — the horse's lungs needed
a square and the user ruled that eyes and gut both keep theirs. The reasoning and the five internal jobs are
in `stages-and-evolution`.

Species experience is a currency, and what it buys is **that species' body parts.**

**External 6 — visible on the body**: head (jaws · beak · horns) · **torso** (chest · mane · hump) ·
back (wings · shell) · forelimbs · hindlimbs · tail

**Internal 5 — numbers only**: eyes · gut · bone · hide-or-fur · **lung**. ⚠ **Eyes moved inside** —
noticing things is a number, not a sprite. **Lung is breath** — how long a movement active sustains — and it
was added on 2026-08-14 rather than folded into gut, because gut has a job of its own. What the gut does,
and what it costs to take, is in *The economy*

Every species offers only some slots. Rabbit gives ears and hindlimbs; crocodile gives jaws, tail and hide;
bird gives wings and eyes. **That is what makes hunting selective.**

Parts are **not bought on demand**. Three locks stack:

- A part **appears among the candidates by chance**, and the strong ones are rare
- ~~If it appears, it still **costs**~~ — **deleted 2026-08-13 with the price.** Two locks remain, not three
- **Missing it raises its chance next time**, so hunting cheetahs repeatedly is a strategy rather than a
  prayer

⇒ You can aim at a build. You cannot complete one in a single run.

### Left · right · space

A part is a passive by being equipped, and **an active by being bound**. There is no separate skill list.

**Not every part carries an active** (confirmed by the user, 2026-08-13). A part is one of three shapes:
stats only, an active only, or both. Legs raise move speed *and* replace what `space` does; crocodile jaws
bring `bite` in as a new left-click. ~~**That is why force has to be derived from the stats rather than being
a stat of its own.**~~ ⚠ **Dead — and it cited the doc that refutes it.** **Force is STORED**; parts add to
it when worn and subtract when digested. Recomputed, halving is undone on the next frame and `F` becomes
free. See *Splitting and absorbing* in `stages-and-evolution`.

- **Left / right click** — any part with an active
- **Space** — movement only, and only from **hindlimbs or back**. ~~**It has exactly one implementation**: an
  impulse along the facing~~ — ⚠ **dead**: what a key does is written on the part, not on the key
  ([why](../decisions/hit-shape-comes-from-the-part.md)). The horse's gallop is sustained acceleration while
  held, which is not an impulse. **The parameters still belong to the part**; what varies is more than
  their values
- **At the start**: left click is `BITE`, **a narrow forward cone**. Right click and space are **empty**
- ⚠ **All three are squares, and `bite` is only the active you are handed first** (user, 2026-08-14, said
  three times). There is no fixed basic attack: **the player binds any active to any of the three keys**,
  left click included, and binding over `bite` throws it away. `space` is the one square with a rule — it
  takes movement actives only

Movement is what the player feels most, which makes the space slot the strongest reason to go hunt a
specific animal.

**All three keep changing across a run.** `bite` is only the opening left click; every binding is replaced
as parts are bought, so the same three keys do something different by the end.

| Input | What it is |
|---|---|
| move | the host's own movement |
| left click | **an active square** — `bite` is only what is in it at the start |
| right click | a part's active |
| space | a movement part |
| `1` `2` `3` | swarm commands, `3` pointed at a target |
| **`F` held** | **split** — the host and every clone halve at once |
| **`V`** | **absorb** — every clone inside a radius, in one press |

**Right hand fights, left hand commands**, and neither rests while the swarm is scattered.

> Pressing a command and then **dragging with the mouse** to place or aim it was raised as the likely final
> shape. Left for later — the keys work without it.

### Fighting and eating are two different things

- **Contact is combat.** Anything hostile in contact trades damage on its own — the host, the clones and
  the enemy alike. **Clones fight without being told**, and the player fights by hand on top of that
- **Ground food is automatic.** Walk near grass and it goes in. There is no eat button
- ⚠ **A kill is NOT automatic** (user, 2026-08-14). It leaves a **corpse**, and eating the corpse **takes
  time** — the body stands there while something else can walk up to it. **Progress is kept if you leave and
  come back.** The user's word for what this is for was 쫀득: the meal is the beat that makes a kill land
- **Two kinds of food**: what is lying on the ground, and the corpse an enemy leaves. Killing and eating
  are separate acts — the kill makes the meal, and **now the meal costs something too**

### Individuals differ — and a clone builds itself by killing

Clones are **not** a uniform species. Different cells carry different parts, and the swarm's composition is
itself part of the build.

**A clone gets its part by eating.** When a clone kills something, a **random part of that prey attaches to
that clone** — no menu, no choice. The cards are the host's; the swarm's composition is whatever it has
been hunting.

**A clone carries at most one part, at one anchor**, and a later kill replaces it. **The host keeps all
eleven slots.** A hundred cells wearing eleven parts each is neither readable on screen nor renderable at
once.

⇒ Two build paths that do not look alike: the host is **chosen**, the swarm is **grown**.

### Losing

**The host dies, the run ends.** Immediately, with no succession.

### The run — climbing the food chain

⚠ **This whole section was replaced on 2026-08-13.** A stage is a **habitat** cleared by swallowing its
**boss**; the ladder is beasts by habitat → dinosaurs → a final boss on its own stage; insects and human
civilisation are both out, the second because **a machine is not something you eat**. Every stage carries
special individuals — a fantastical beast, a chimera, a mutant — rolled per run.
**`stages-and-evolution` holds it**, and
[A stage is a habitat](../decisions/ladder-of-habitats-not-tiers.md) holds what lost.

⚠ **Three rules below are NOT dead and the blanket "the paragraphs below are the dead version" hid them** —
`stages-and-evolution` even cites one of them while it sits under a tombstone. **These three stand**:
enemies are chimeras built from the same slots as the player · a chimera pays into every species it wears ·
the map is one open field with biomes. **Everything else below is the dead tier version**, kept only so the
change is visible.

**It starts at animals.** Small animals → large animals → **humans and their war machines** → space, and
the escalation is meant to be faintly ridiculous. **What you fled from last stage is food in the next
one**, and that reversal is the run's whole shape.

> **The microbe tier was cut.** It had no jaws, legs or wings to hand out, so the opening minutes gave the
> player nothing — and on minimal art a microbe is a dot that reads as nothing at all. Starting at animals
> means the first part arrives in the first level-up.

**Every five minutes a boss comes hunting for you.** Kill it inside its arena and the next tier opens.

**A tier opening is bounded accumulation, not replacement.** Clearing the boss adds the new tier's species
to the field permanently and re-weights the spawns; **the field carries exactly the current tier and the
one before it**, and the tier before that falls out. That is the rule that makes what you fled from into
food, and it caps the live spawn table at two tiers of art.

Enemies are **chimeras built from the same eleven slots as the player** — a boss is "the thing with three
parts bolted on". No separate enemy system, no separate art pipeline.

**A chimera pays into every species it visibly wears**, split evenly by part count: three crocodile parts
and one cheetah part pay 3/4 crocodile and 1/4 cheetah. The run's biggest kill credits the run's economy.

**The map is one open field with biomes.** No rooms, no corridors, no navigation graph — regions differ by
colour and by what lives and grows in them. A tier change is a visible change of ground, and biomes are
close to free because they are a palette and a spawn table.

### Between runs

**Unlocks only** — new species and new parts entering the pool. **No permanent stat boosts**, because
those force the first run to be deliberately weak.

**This layer is built last.** The core has to stand on its own first.

---

## Screen

⚠ **The whole of this section was decided on 2026-08-13 by generating candidates and looking at them.**
`tools/pixel/out/cell_*` and `tools/pixel/out/gl_*` hold the boards it was decided from.

**The cell is an outline, not a fill.** A rounded square **drawn as a line**, one dot at the centre, and
**everything between them is empty** — the ground shows through. The juice comes from **squash, stretch and
overshoot** in the movement, not from the art.

- **Two eyes were tried and rejected.** They made it a face, and a face has a front, which fights a top-down
  body that parts attach to on all six sides. A centred dot reads as a nucleus and stays centred under
  rotation
- **Featureless with no dot did not read as alive** — it came out as a plain square
- **A filled white body was the step before this one.** The user cut the fill: outline and dot, nothing else
- **Colour is undecided**, including whether the line is white. What is decided is line, not fill

⇒ **Being empty inside is worth more than it costs.** Forty overlapping clones do not blend into one mass,
because each one is a line and you see through it. The known cost is that the ground shows through the
body; the cells are small enough at first that the user chose to accept it.

### It is drawn by code, and images can replace it later

**Nothing above needs a sprite.** A rounded outline, a dot, and a part's line are radius · thickness ·
length — numbers, and squash and stretch are free on numbers and destructive on pixels.

⇒ **This is a stage, not a verdict.** The user's call: build it as drawing code now and swap in images later
if it wants them. That only stays cheap if **every drawing call goes through one place** — see
`src/look.gd`'s rule in `CLAUDE.md`.

⇒ **A part is worn in the host's own colour, not the prey's.** Eating a cheetah's legs does not paste
cheetah onto the body — the cell digested it. **So a part carries no colour of its own**, and the whole
"every species-slot sprite must come off one board or the tones fight" problem — the biggest art constraint
in this project — **does not apply to this game.** What was eaten is read from **shape alone**.

⇒ **Generated boards showed which parts could ever be images**: jaws, horns and wings survive being cut off
a body and still read. **A leg does not** — detached, it is a brown stick (`tools/pixel/out/part_horse_leg`).

**How parts attach**: **six anchors around the body** — one per external slot — with the parts drawn
**behind** the blob so they read as silhouette: a jaw juts forward, wings spread behind, legs show
underneath. **The five internal slots are not drawn at all; they change the body's drawing values** — fur
outlines it, hide deepens the colour, bone sharpens the corners, lung is read from how long a gallop holds.

**A part is a shape, an anchor index and a facing flip.** No rotation, no per-part z-sort, no scaling.
A boss is drawn **bigger**, never as a scaled rig.

⚠ **The board-per-species rule is lifted for this game** (2026-08-13). It said every species × slot sprite
had to come off one board on one preset or the tones could never be made to match, and it was the single
biggest constraint here — it is what capped a habitat at five or six species that give parts.
**It does not bind, because a worn part has no colour of its own**: the host draws it in the host's own
line. Tones cannot fight when there is only one tone.
⇒ **The cap on how many species give parts is gone.** What still limits them is how many the player can
tell apart, which is a design question, not a bill.

- A square host with parts protruding from its sides, surrounded by smaller squares
- `scatter` visibly spreads them out; ⚠ **`1` gathers them at the host and the ring follows the host as it
  moves** (changed 2026-08-14 — this line still said *at the spot the key was pressed* after the rest of the
  doc had been corrected, which is how one file came to say both). **`V` pops the whole ring at once** — that is the harvest, and it must be readable without a number.
  ⚠ **The swarm does not grow back on its own**; the next `F` is what refills it, and the body visibly
  thins as it does
- One level bar, always visible, filling from every mouthful
- ⚠ The level-up pause shows **three cards, each `species · slot`** — **no price, no balance** (the price
  died on 2026-08-13 and this line was the last place still claiming otherwise). A card for a part already
  worn reads as a level-up of it
- **The force number sits under every body** — the host's, every clone's, every creature's — and a packed
  group draws **one summed number** instead of forty digits (user, 2026-08-14)
- **A minimap**, because the field is 3840×2160 and the swarm leaves the screen (user, 2026-08-14)
- A clone being swallowed on `follow` shoves the gauge forward. **A dozen arriving at once should read as a
  cascade**, not as twelve small increments
- A boss is visibly a chimera: parts you recognise, on something far bigger

---

## The August cut

⚠ **Narrowed again on 2026-08-14, and much further than "two tiers".** The August build is **one stage
(grassland), two species (crow and horse), one boss**, and **three parts** — horse legs, horse mane, horse
lungs. The crow gives no part; it is what you eat while the horse is still uncatchable. Everything else in
the ladder is content that does not fit in the time.
[The grassland plans](../plans/1.ready/grassland-whole-loop.md) are the buildable form of that cut.

> ~~The August build ships two tiers and one boss.~~ Superseded by the line above.

**The clone pool is 128, allocated once — and `CLONE_CAP` 40 is what the game can actually reach.**
Also a cut: 128 is the allocation, chosen so a regression is catchable rather than because play asked for
it. **Nets bound-test at 40.**

**Between runs is built last**, if at all.

---

## Bounds

- **Zero clones** — the host alone must not crash, ~~and it is not the opening state~~ — ⚠ **it is exactly
  the opening state now.** `START_CLONES` is **0** ([why](../decisions/the-run-opens-alone.md)), and the
  minute of nothing the prototype measured is answered by the host opening at **force 10** so the first `F`
  is immediate ([why](../decisions/force-starts-at-ten.md))
- **40 clones** — `CLONE_CAP`, the reachable maximum. **128 is the array, not a state.** No per-unit orders
  exist, so input cost does not grow; drawing and separation do, and neither is measured
- **A slot with no part** — starting state. Empty right click and space must not read as broken
- **Every clone dies far from home** — the run must be recoverable, not over

---

## Cost

⚠ **`src/` exists and two of the three costs below are measured.** The uniform grid: 300 items 0.42ms
against a naive 3.01ms, 600 items 1.03ms against 12.19ms (`sim_grid.gd`). 300 `Node2D`s: 0.065ms
(`proto-round-trip`). **The per-clone decision is the one still unmeasured.**

The one structural trap from `CLAUDE.md` applies: **128 independently-feeding clones are 128 awake
agents.** Being rows in an array rather than nodes takes the scene-tree cost out; it does not take out the
per-clone decision, the separation query or the draw. Measure before any of the three is tuned.

---

## Acceptance

⚠ **This section said "Nothing is accepted" while the header three hundred lines above said the core loop
passed.** The header is right and this was left to rot.

**Passed**: *one square that moves, eats, and splits.* The user played the prototype and confirmed the fun —
the record is `proto-round-trip`. **That is the only thing accepted.**

**Not accepted, and next in front of the user**: a run that starts at a title and ends at an ending screen
(plan 1), and then the whole grassland loop (plan 4). Everything between is unlooked-at.

---

## TBD

**Not filled in on purpose.** A spec that pretends to know produces a fake implementation.

- **Whether the stupid-clone answer actually fills the hands.** Designed above, unproven. Principle 2 says
  only play decides this one, and it stays the largest open risk
- **Whether the clone tax earns its keep.** *The economy* carries the number. If the host's bite being
  worth double is not felt, the rule is one deletion away
- ~~**What the ending is.**~~ **Closed 2026-08-14.** A run ends **the moment the boss is eaten or the host
  dies** — never on a clock — and both land on **one ending screen** that reads out time, cells eaten,
  species eaten and the finished body. See [the run shell](../plans/1.ready/run-shell.md). What comes
  *after* grassland is still undefined and stays that way
- ~~**The tier list** beyond the two that ship.~~ **Void** — there are no tiers, and the August scope is one
  stage, not two. How many habitats there eventually are is open; nothing about it is being decided now
- **Whether the host visibly grows in size across tiers.** Raised, wanted, deferred
- **Whether commands end up as press-and-drag** rather than a plain keypress. Raised, deferred
- **Meta unlocks diluting the card pool.** A wider pool makes the part you want rarer, and the pity rule
  fights it. **Deferred** — between-runs is built last, so nothing can be measured yet
- **The screenshot that sells this only exists late in a run.** Known, unfixed, and no opening hook is
  being invented before play says one is needed
- **Whether breeding survives as a distinct verb.** Discussed and then absorbed: regrouping means
  *absorption*, and combinations come from buying parts. Nothing in the loop needs a separate breed action
