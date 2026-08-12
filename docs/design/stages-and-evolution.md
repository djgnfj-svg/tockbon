# Stages and evolution

**One line**: One cell eats its way through a habitat, **evolves into what it ate**, swallows the strongest
thing living there, and walks into the next habitat carrying the body it built.

**Implemented**: none — not one line of this is in `src/`. The prototype (`proto-round-trip`) holds the
session loop and an ecosystem rule that **this doc partly replaces**
**Accepted**: none. Every line below came out of one planning conversation on 2026-08-13. **Nothing here
has been played**, and planning principle 2 says planning cannot judge fun

⚠ **This doc supersedes parts of the GDD** (`cell-game.md`): the card **price** is deleted, the
five-minute boss cadence is replaced by "swallow the apex", and tiers are replaced by habitats.
Where the two disagree, this one is newer. The GDD has been edited at those points rather than left to rot.

---

## The two loops

**The user requires both of these to be written down explicitly, in any GDD.** Rules alone do not show the
rhythm.

**Session loop — a round trip, tens of seconds**
`2` scatter → clones farm on their own → `1` places a rendezvous → the host walks in and absorbs → level-up.
Absorption **empties a clone without killing it**, so the swarm never shrinks on a harvest and the same
wheel keeps turning.

**Main loop — one habitat, ~10 minutes**

1. Enter. Host alone, swarm 0
2. Grow the swarm — the session loop spins here
3. Level-up cards attach parts; evolution accumulates
4. **Force passes the apex's force — what hunted you becomes what you hunt**
5. Hunt the apex. It is the only thing that drops that habitat's final part
6. **Absorb the entire swarm** — the great harvest, and the one time the bodies are eaten too
7. Next habitat. The old apex is now common trash, the build carries over → 1

**Step 4 is the heart.** The other six make it or follow from it.

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
| **The twelve slots** | the hard budget everything above competes for |

**The payout must change how the game is played, not raise a number.** The user's own example: frog legs
*and* frog thighs together turn `space` into **three chained jumps**. Each part added is another thing the
hands can do once, and by the end the same three keys play differently — which is what the GDD already
claimed and never had a mechanism for.

⇒ **This is where planning principle 8 finally lands.** Two parts producing an effect neither has alone is
a combination, not addition, and the slot budget is what makes taking one mean giving up another.

### Twelve slots — five external, seven internal

Six slots ran out too fast to build in. **The budget opened to twelve on 2026-08-13**, and it opened on the
cheap side on purpose:

- **External slots are expensive.** Each one is a sprite per species, and species art comes off one board
  per habitat. **Five**: head · back · forelimbs · hindlimbs · tail
- **Internal slots are free.** They were never drawn. **Seven**: eyes · brain · gut · lungs · heart · bone ·
  hide-or-fur. **Eyes moved inside** — what they do is notice things, and that is a number, not a sprite

**Seven internal is deliberately one too many.** The user listed all seven to hold the space and expects to
cut one later; nothing is designed around exactly seven.

**Invisible was the only objection, and the body itself answers it.** The cell is a rounded square, so an
internal part changes **the drawing values rather than adding a picture**: muscle thickens the body, fur
puts an outline on it, hide deepens the colour, bone sharpens the corners. All twelve slots read on screen
and the art bill does not move — which is exactly the shape planning principle 7 asks for.

### The threshold is per set, and a part can take more than one slot

**There is no global stack number.** Two more rules came out of the same conversation and both change the
shape of the budget:

- **Each set names its own threshold.** Some fire at three parts, some at two, and **a fantastical beast's
  part can be a set of one** — catching that one thing is the whole combination
- **A part can occupy several slots.** The big ones cost more than their place: one part, three squares

⇒ **That is what turns twelve slots into a real budget rather than a bigger number.** Strong parts eat the
room the rest of the build needed, so **saving slots is itself a way to raise a build** — which is half an
answer to the open "how does a build go higher" problem, without inventing genes for it.

⇒ It also means the earlier worry is dead on both ends: the threshold was never one number to pick.

### Taking a card is irreversible — there is no inventory

**This game has no bag, only a body.** Everything below follows from refusing to build an inventory.

- **A new part in an occupied slot replaces the old one, and the old one is digested.** It is not stored, not
  listed, not recoverable. The only trace is a small push on the level gauge
- **Merging two parts was rejected on art.** Crocodile jaws plus hippo jaws would need a sprite per
  species × species pair, and species art comes off **one board per habitat** — the pairing explodes it
- **Levelling only happens on the same species' same part.** `crocodile jaws Lv2` comes from another
  crocodile; a hippo jaw is a replacement, not a level
- **A multi-slot part is evicted whole the moment any one of its slots is claimed**, and the slots it also
  held are left **empty**. Wearing a head+eyes part and buying a head part digests the whole thing and
  leaves the eye slot bare
- **Which slots a part takes is written on the part, not derived from a rule.** An adjacency graph over the
  twelve slots was raised and dropped as too complicated for what it buys — **each part carries its own
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
| **flees** | annoying — you have to chase it down | **the apex** — grow before you can catch it |

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

**A stage is one habitat**, and a habitat is one art board. Species added later cost a whole board
(`CLAUDE.md` measured this), so the habitat is chosen first and its species are generated in one pass.

- **Clearing a stage = swallowing that habitat's apex.** Not a timer, not a five-minute boss cadence
- **The apex is the only source of that habitat's final part**, so clearing and building are the same act
- **On clearing, the whole swarm is absorbed** — bodies included, this once — and the next habitat starts
  with the host alone
- **The previous apex is laid out as common trash in the next habitat.** It did not get weaker; it now
  arrives in numbers. That is the reversal the GDD was built around, with no tier machinery
- **~10 minutes a stage, 4 to 6 stages.** Half-settled. Stage length is not a timer that can be set — it is
  how long the apex takes to catch, so it falls out of how fast force accumulates

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

That pulls the art in with it: **everything stage 1 needs is made** — the monsters, the body, the parts, the
colours, the style. Nothing beyond stage 1 is drawn.

**The final boss is out of scope** and stays undecided.

### Stage 1 is grassland

**Settled 2026-08-13.** It was picked over swamp because **grassland fills all four squares of the
disposition × force table on its own**:

| | weak | strong |
|---|---|---|
| **attacks** | — | **lion**: the first time a scattered swarm gets shredded |
| **flees / ignores** | **herds** (the first food) · **cheetah** (fast, has to be chased) | **elephant**: the apex, untouchable until the swarm is grown |

Two more things live there, and both were the user's:

- **Small animals in numbers** — crows, rodents. The bottom of the food chain, and what the swarm eats while
  it is still nothing
- **Plants are food too.** Grass and trees scattered on the ground are edible, which gives the opening
  minutes something to eat before anything has been killed — and it is the cheapest food in the game to draw

Swamp is not dead; it keeps the frog's chained `space` jump and the crocodile bite, and it is a candidate
for a later stage.

## Open

Everything on this list came up in the same conversation and none of it was closed.

- **What each of the seven internal slots does.** Only the gut is written; eyes, brain, lungs, heart, bone
  and hide/fur are names with nothing behind them
- ⚠ **How the swarm multiplies at all.** The GDD gave +1 clone per level-up and the prototype guaranteed one
  of the three cards grew the swarm. **Cards are parts-only now, so the growth card is gone** and nothing
  replaced it. Linear growth on level-up is the obvious patch; doubling is not — the pool cap is reached in
  a handful of levels and every level-up after that stops growing the swarm. **This is the largest hole
  open.**
- **How high a build can go, and by what.** Genes were named and deferred; nothing replaces them yet
- **Whether part level is capped**, and whether a levelled part still counts once toward a class stack
- **What a species trait actually gives.** The name exists, the content does not
- **What each part's force contribution is.** The rule is settled — **force is carried on the equipped parts
  and every part carries a different amount** — but no part has a number yet
- **When a clone fires its active.** They all fire (below); on cooldown with no aiming is the shape that
  fits "clones are stupid", but it is not written down as a rule yet
- **Whether the host's own evolution counts toward force**, or force is the swarm's sum alone
- **What a chimera drops when eaten.** It wears several species, so one part does not cover it
- **What a mutant gives.** The phrase used was "a special cost" and it was not pinned down
- **What separates a fantastical beast from a strong ordinary one** beyond "a special part"
- **How wide the even-force band is** — where the hands decide instead of the numbers
- **Whether the final boss is eaten or merely killed.** Eating it leaves nothing after; not eating it breaks
  the game's one rule at the very end
- **Where the ladder stops.** Dinosaurs, or machines with the eating rule solved
- **Six stages is a 60-minute run.** In a die-and-restart structure that may be too long to bear. Play decides
- **Colour, entirely.** No species colour, no field palette, nothing. This is decided by generating real
  candidates and pointing at one, never by discussion (`CLAUDE.md`, `tools/pixel/`)
- **Field size**, and therefore whether a minimap is needed at all — a minimap is required exactly when the
  swarm leaves the screen, and that has not been chosen
- **Force numbers under forty clones would be a field of digits.** Whether clones are excluded, or reduced
  to a mark, is unresolved

## Where the pictures are

`cell-loops.html`, next to this file — the loops, the 2×2, the under-the-body readout, the twelve-slot body
and the stage table, drawn. It was published as an artifact for the user on 2026-08-13 and the copy in this
folder is the source it is published from.

**It is a view of this doc, not a second source.** When the two disagree, fix this file first, then the page.
