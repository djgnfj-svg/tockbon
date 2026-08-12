# Cell game — the GDD

**One line**: One square cell splits into a swarm, eats whatever it can catch, and spends what it digested
on **real animals' body parts** — until it stands at the top of the food chain.

**Implemented**: partial — the swarm and its two commands, the rendezvous, carrying and absorption, the
level-up pick, automatic eating and the ecosystem all run — see `proto-round-trip`. **Not built**: parts,
slots, species currencies, chimeras, bosses, tiers, biomes, meta unlocks, the `3 attack that` command.
**Accepted**: **the core loop passed** — the user played the prototype and confirmed the fun. Everything
above that is unbuilt is still `unseen`, and the parts economy is the largest unlooked-at piece.

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
- **4, two systems — over budget.** Six nouns are live: host · clone · species experience · parts ·
  chimera · tier. The defence is that they collapse into two verbs — hunt with the swarm, spend what it
  brings home. If play says otherwise, **species experience is the first noun out**
- **8, order changes the outcome — weakest score here.** One rule carries it: a part bought into an
  occupied slot replaces it and refunds half. Everything else is order-free addition

---

## Behavior

### The body and the swarm

- You control **one cell — the host**. It moves, it eats, it uses the three bound actions
- **Splitting is a level-up reward, not a button.** The count comes from the level — the rule is in
  *The economy*. You never select a clone individually
- **The swarm is a fixed pool of 128.** A hard bound the renderer and the nets are built against, not a
  target to reach
- Clones obey **commands on the number keys** — `1 follow` · `2 scatter` · `3 attack that`. They are pressed
  like abilities, not chosen from a menu, and **`3` requires you to point at something**: no auto-targeting,
  or the game fights on its own
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
2. **`1 follow` gathers the swarm at the point where the key was pressed**, and they wait there.
   Absorption still requires touching the host
3. A clone the host touches is **absorbed**: it hands over what it carried and **returns to the pool**
4. A clone killed before it is absorbed **takes everything it carried with it**

⇒ **The press is a placed rendezvous**, not a recall to wherever the host happens to be. The host must
walk into ground it chose while the swarm was still out. Recalling to the host instead lets it park in
cleared ground while the clones bear the whole return trip — the exact inverse of the tension here.

⇒ Scattering wide earns more and risks more. **Density is the combat axis and the economy axis at once.**

⚠ **Absorption does not shrink the swarm.** It spends what a clone carried, not the clone. The swarm's
size is set by level and **refills to its full count over the next few seconds** — otherwise the
forty-blob picture dies at every harvest, which is the one picture this game sells.

### The economy — one gauge, two numbers per species

Three things are tracked and they never collapse into each other.

| Tracked | Behaviour | What it drives |
|---|---|---|
| **Level gauge** | one bar. Fills from **any** food regardless of species, and is **never spent** | Level-ups |
| **Species total** | per species. **Only ever rises** | Which species show up on the cards |
| **Species balance** | per species. **Drops when a part is bought** | Paying for a card |

**A level-up does exactly two things**: **+1 clone, automatically** — the card alone once the pool is full —
and **three cards appear.**

Each card reads `species · slot · price` — `crocodile · head · 12`. Taking one deducts from that species'
**balance**, and **there is no way to pay for it with anything else.** Short on crocodile, the crocodile
card is simply not affordable this level. Go eat another crocodile.

**Every level-up produces at least one affordable card.** If no roll is affordable, the cheapest is
discounted to the current balance — a level-up never hands the player nothing.

**A part bought into an occupied slot replaces it, and the replaced part refunds half its species
balance.** Slots are the only scarce thing on the body, and this is where the order parts arrive in
becomes a decision instead of addition.

**Which species a card shows is rolled from the totals, weighted by experience amount rather than kill
count** — a big crocodile is not one rabbit. Three crocodiles' worth against one rabbit's makes each card
3/4 crocodile. Once a species is drawn, the part is rolled *within* that species.

⇒ **Totals and balances are separate on purpose.** Merge them and buying crocodile parts is what stops
crocodiles appearing.

**There is exactly one tax: a clone hands over 50% of what it carried.** What the host bit itself is worth
double what a clone brings home, which is the whole reason the host stays in front.

**The gut raises what a clone brings home, and nothing else.** The host's own bite is always 100% and the
gut can never exceed it — it closes the gap, it never inverts it. It also spends one of the two internal
slots, so **gut is bought against hide.**

> **Cross-species conversion was cut.** It read as a tax on mixing species — the thing the game is selling —
> and on inspection it was never a tax at all, only a bailout nobody had to take. Removing it takes a
> number, a rule and a UI panel out of the game at once.

⇒ **The rhythm this produces is the point.** Scatter, hunt wide, call them home, and the gauge lurches as a
dozen clones are swallowed in a row — **level-ups firing back to back, cards stacking up.** Growth is not a
trickle; it arrives when the swarm does.

Other ratios exist (gut rates, candidate weights, the rising chance on a miss) and **none of them has been
picked.**

### Parts — eight slots

Species experience is a currency, and what it buys is **that species' body parts.**

**External 6 — visible on the body**: head (jaws · beak · horns) · eyes · back (wings · shell) ·
forelimbs · hindlimbs · tail

**Internal 2 — numbers only**: gut · hide (defence · camouflage). What the gut does, and what it costs to
take, is in *The economy*

Every species offers only some slots. Rabbit gives ears and hindlimbs; crocodile gives jaws, tail and hide;
bird gives wings and eyes. **That is what makes hunting selective.**

Parts are **not bought on demand**. Three locks stack:

- A part **appears among the candidates by chance**, and the strong ones are rare
- If it appears, it still **costs** — a cheetah's legs cost many times a rabbit's ears
- **Missing it raises its chance next time**, so hunting cheetahs repeatedly is a strategy rather than a
  prayer

⇒ You can aim at a build. You cannot complete one in a single run.

### Left · right · space

A part is a passive by being equipped, and **an active by being bound**. There is no separate skill list.

- **Left / right click** — any part with an active
- **Space** — movement only, and only from **hindlimbs or back**. **It has exactly one implementation**: an
  impulse along the facing, with a duration, an ignore-collision flag and a distance. A cheetah's dash, a
  bird's glide and a frog's leap are three parameter sets of it, **never three controllers**
- **At the start**: left click is `bite`. Right click and space are **empty**
- **`bite` is overwritable.** A part bought into the head slot replaces it. Nothing is lost by doing so —
  eating is not on a button (below)

Movement is what the player feels most, which makes the space slot the strongest reason to go hunt a
specific animal.

**All three keep changing across a run.** `bite` is only the opening left click; every binding is replaced
as parts are bought, so the same three keys do something different by the end.

| Input | What it is |
|---|---|
| move | the host's own movement |
| left click | basic attack — `bite` at first, whatever is bound later |
| right click | a part's active |
| space | a movement part |
| `1` `2` `3` | swarm commands, `3` pointed at a target |

**Right hand fights, left hand commands**, and neither rests while the swarm is scattered.

> Pressing a command and then **dragging with the mouse** to place or aim it was raised as the likely final
> shape. Left for later — the keys work without it.

### Fighting and eating are two different things

- **Contact is combat.** Anything hostile in contact trades damage on its own — the host, the clones and
  the enemy alike. **Clones fight without being told**, and the player fights by hand on top of that
- **Eating is automatic.** Walk near food and it goes in. There is no eat button, which is why `bite` can
  be overwritten
- **Two kinds of food**: what is lying on the ground, and **the corpse an enemy leaves.** Killing and eating
  are separate acts — the kill makes the meal

### Individuals differ — and a clone builds itself by killing

Clones are **not** a uniform species. Different cells carry different parts, and the swarm's composition is
itself part of the build.

**A clone gets its part by eating.** When a clone kills something, a **random part of that prey attaches to
that clone** — no menu, no choice. The cards are the host's; the swarm's composition is whatever it has
been hunting.

**A clone carries at most one part, at one anchor**, and a later kill replaces it. **The host keeps all
eight slots.** A hundred cells wearing eight parts each is neither readable on screen nor renderable at
once.

⇒ Two build paths that do not look alike: the host is **chosen**, the swarm is **grown**.

### Losing

**The host dies, the run ends.** Immediately, with no succession.

### The run — climbing the food chain

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

Enemies are **chimeras built from the same eight slots as the player** — a boss is "the thing with three
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

**The cell is a rounded square blob** — cute, nearly featureless, and it reads at any size. Depth comes from
**an ellipse shadow underneath and a lighter top edge**, not from shaded spheres; the juice comes from
**squash, stretch and overshoot** in the movement, not from the art.

**How parts attach**: **six anchors around the body** — one per external slot — with the parts drawn
**behind** the blob so they read as silhouette: a jaw juts forward, wings spread behind, legs show
underneath. **The two internal slots are not drawn at all; they change the body's colour.**

**A part is a sprite, an anchor index and a facing flip.** No rotation, no per-part z-sort, no scaling.
A boss is drawn with **bigger part sprites**, never a scaled rig.

⚠ **Every species × slot sprite is generated in one board on one preset.** Parts drawn from different
presets can never be made to match however the prompt is tuned — `CLAUDE.md` measured it. So art is cheap
**once**: one board per species, paid up front, and **a species added later costs a whole board.**

- A square host with parts protruding from its sides, surrounded by smaller squares
- `scatter` visibly spreads them out; `follow` gathers them **at the spot the key was pressed**, and each
  one **pops as the host touches it** — that pop is the harvest, and it must be readable without a number.
  The swarm visibly grows back afterwards
- One level bar, always visible, filling from every mouthful
- The level-up pause shows **the cards, each `species · slot · price`**, and the balance each would draw
  from. A card you cannot afford is visibly out of reach — there is no second way to pay for it
- A clone being swallowed on `follow` shoves the gauge forward. **A dozen arriving at once should read as a
  cascade**, not as twelve small increments
- A boss is visibly a chimera: parts you recognise, on something far bigger

---

## The August cut

**The August build ships two tiers and one boss.** That is a cut, not a detail — the ladder above is the
shape of the run, and the rest of it is content that does not fit in the time.

**The clone pool is 128, allocated once.** Also a cut: it is the number the nets test against, chosen so a
regression is catchable rather than because play asked for it.

**Between runs is built last**, if at all.

---

## Bounds

- **Zero clones** — the host alone must still be playable. This is the opening state of every run
- **128 clones** — the pool cap. No per-unit orders exist, so input cost does not grow; drawing and
  separation do, and neither is measured
- **A slot with no part** — starting state. Empty right click and space must not read as broken
- **Every clone dies far from home** — the run must be recoverable, not over

---

## Cost

Nothing is measured. `src/` does not exist and no number here has been profiled.

The one structural trap from `CLAUDE.md` applies: **128 independently-feeding clones are 128 awake
agents.** Being rows in an array rather than nodes takes the scene-tree cost out; it does not take out the
per-clone decision, the separation query or the draw. Measure before any of the three is tuned.

---

## Acceptance

Nothing is accepted. The first thing to put in front of the user:

**One square that moves, eats, and splits.** If steering a growing mass is not fun with zero parts and zero
species, no amount of the rest fixes it.

---

## TBD

**Not filled in on purpose.** A spec that pretends to know produces a fake implementation.

- **Whether the stupid-clone answer actually fills the hands.** Designed above, unproven. Principle 2 says
  only play decides this one, and it stays the largest open risk
- **Whether the clone tax earns its keep.** *The economy* carries the number. If the host's bite being
  worth double is not felt, the rule is one deletion away
- **What the ending is, and what happens after the apex tier.** No finish line is defined and none is being
  defined now — the August build stops far short of it. **Deferred on purpose**
- **The tier list** beyond the two that ship — how many stages, and what lives in each
- **Whether the host visibly grows in size across tiers.** Raised, wanted, deferred
- **Whether commands end up as press-and-drag** rather than a plain keypress. Raised, deferred
- **Meta unlocks diluting the card pool.** A wider pool makes the part you want rarer, and the pity rule
  fights it. **Deferred** — between-runs is built last, so nothing can be measured yet
- **The screenshot that sells this only exists late in a run.** Known, unfixed, and no opening hook is
  being invented before play says one is needed
- **Whether breeding survives as a distinct verb.** Discussed and then absorbed: regrouping means
  *absorption*, and combinations come from buying parts. Nothing in the loop needs a separate breed action
