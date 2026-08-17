# Cell Army — GDD (rewritten 2026-08-16)

**Implemented**: none. **Not one line in `src/` was written for this document.**
**Accepted**: the direction and everything under "What is decided" was said by the user directly, in one
conversation. **"Undecided" means nothing was picked.**

**This is the English counterpart of `cell-army-gdd-ko.md`. The two must be edited together or they will
diverge** — a fact corrected in one and not the other is worse than no English file at all.

⚠ **This document replaces the cell-game GDD (deleted, tag `v2-openfield`).** The open field, the host,
`F`/`V` and the eleven slots all belong to that document and are all gone.
**Where the two disagree, this one is right.**
How the design got here is in [Lessons from two dead games](../lessons-from-two-dead-games.md), and the
arithmetic behind that diagnosis is in the same document.

---

## One line

> **You go and pick what to eat.**

You start as one lump of square cells, eat the islands one at a time, **build your own army out of what you
ate**, and fight an opposing army at the end.

⚠ **~~"bolt each island's specialty onto your bodies"~~ was overturned by the user on 2026-08-18.** A part
does not bolt onto the soldier who survived; **what it bolts onto is open again** (`plan-then-watch`,
undecided 1). **This paragraph was the ninth place that reversal failed to reach, and it is the one
`CLAUDE.md` points at with "read this before proposing anything."**

⚠ **This line came out of the user's mouth as it stands** — *"얘도 먹어보고 싶고, 쟤는 먹을까 하고 먹어보러
가는 거지."* (*"I want to try eating this one, and I go over to that one wondering whether to eat it too."*)
The previous GDD's one line (deleted) **had the swarm appear only as a means**, so parts bolted onto the
host alone, so the clones never belonged. **The game was built exactly as the document told it to be**, and
this line inverts that.

---

## The loop is three deep

> ### ⚠ The user renamed these (user, 2026-08-18)
>
> **This section said "meta · session · main"; the user calls them something else, and their names win.**
> Outside in it is **main → session → part** — the outermost is the **main loop**, one run is the
> **session loop**, one island is the **part loop**. They corrected a diagram that had the session loop
> containing the main loop, in as many words.
> **The three headings below carry the new names.** The session loop's detail is
> [the session loop](session-loop.md).

### Main loop — outside a run

```
start → begin the adventure with unlocks applied → [session loop] → die or clear
                        ↑                                              ↓
                        └────────── unlock ←── you carry something out ──┘
```

**Unlocks give both content and numbers** — new soldier types · new island types · a choice of starting
specialty, **and also** figures like the starting cell count. The user decided this, and in doing so
[reversed the older decision not to raise numbers](../decisions/meta-unlocks-not-stat-boosts.md).

⚠ **The trap that decision wrote down survives the reversal**: permanent upgrades only sell if there is
headroom, and **headroom is made by making the first run weak.** The first run is the one that decides
whether the player continues at all.
⇒ **Keep it as a condition: balance against zero unlocks, and stack unlocks on top of that.**
**Still undecided**: where the unlock screen lives — its own screen, or a slot on the title.

### Session loop — one run

```
map opens → pick an island → [part loop] → that island's reward (one of the three; an elite gives three) → back to the map → … → boss island → clear
                                 ↓ lose                ↑ a chest island arrives here without a fight
                              run over
```

⚠ **There is no refit in that diagram, and that absence was the hole.** A stretch of time goes between two
nodes — [the session loop](session-loop.md).

### Part loop — one island

```
the island unfolds → land them on the coastline (where · when · who) → auto-battle → a dead soldier is dead for good
                                                                        ↓ wipe them out
                                                                     victory
```

**And the smallest unit that repeats, at the innermost level, is this:**

> ~~**Drop → watch → drop again.**~~
> ⚠⚠ **Replaced on 2026-08-18: plan → start → watch.** There is no "again" —
> [plan it, then watch it](plan-then-watch.md).

✓ ~~**What gates the "again" is decided: the fleet count and the round trip**~~ — see "The boat" and the
"Updated" section under it.
⚠ **With the "again" gone there is nothing left for that sentence to gate.** The fleet count and the round
trip now decide **how many waves a plan splits into.**
⚠ **This slot used to read ~~the landing-craft interval~~. The interval is deleted.**
**That one choice sets the game's tempo.**

**Decisions the player makes**: which island to go to · **where on the coastline, when, and who to land** ·
**how many to send out** (the "contact line" section) · where to bolt an object · which artifact to take.
⚠ **2026-08-18: none of those went away — they all moved in front of the start button** —
[plan it, then watch it](plan-then-watch.md).

---

## What is decided

| Item | Content |
|---|---|
| Genre | **Autobattler.** No unit control during combat |
| Progression | **Node map.** You advance by clearing islands one at a time |
| Island types | **Chest · combat · elite · boss** — four |
| Combat | **Chest islands have no fight.** The other three are combat islands — i.e. **there is exactly one resting square** |
| Host | **None.** The very concept of a protagonist cell is deleted |
| `F` / `V` | **Deleted.** No splitting in half, no absorbing |
| Soldiers | **They carry across rounds.** Die and they are gone for good. **And HP carries too** — see its section below |
| Start | **A lump of square cells with one leg** attached |
| Rewards | **Three axes** — **cells** (eating grows the cell pool, not the soldier count) · **objects** (~~they fit into slots 1~5~~ ⚠ **what they fit into reopened on 2026-08-18** — see the Parts row below) · **artifact** (applies to the army). A combat island gives one, **an elite gives three** — the combat reward, an artifact, **and that elite's soldier type** (this row said "two" and undercounted the third; see "Elite"). ⚠ **The user replaced the first two axes on 2026-08-18** — they used to read "count" and "specialty (bolts onto one soldier)". See `session-loop` |
| Starting force | **Ten cells** (user: *"처음에 차라리 세포 열 마리를 주고."* — *"just give ten cells at the start."*) |
| Parts | An object *is* a part. ~~**It bolts onto one of the five slots.**~~ ⚠⚠ **Reopened later the same day (user, 2026-08-18)** — **deleting the summon key removed the grounds for five slots (there were five because there are five fingers).** Three candidates (a soldier · a boat · some slot still) are undecided 1 of [plan it, then watch it](plan-then-watch.md). ⚠ **The reason ~~it bolts onto a soldier~~ was overturned still stands** — five slots are distinguishable from each other and the third soldier is not distinguishable from the seventh |
| Theme | **Stays cellular.** A ladder climbing from mammals up to dinosaurs |
| Art | **Shapes drawn by code.** A square plus bolted-on parts. The original reason for picking cells survives intact |

---

## Deployment — **you arrive by boat. Position and timing are the whole of the controls**

**Decided (user, 2026-08-17): you go by boat.** The drop-from-the-sky option was **reversed** (see the
Status line in [that decision](../decisions/dropped-from-the-sky-not-landed-by-boat.md)).
**A boat sailing in to invade does not break the "cells are invaders" fiction** — that fiction was the
original reason for picking the sky drop, and a boat does not violate it. What the user wanted is
**the staging of riding in and invading.**

**Combat is real-time and the units fight on their own.** What the player does is **where** and **when** and
**who** — three things, no more.

⚠ **So this game's heart sits in the same place as Clash Royale's.** There too the units fight on their own
and the person only decides position and timing. That game made placement a decision in **two ways, and
both are restrictions**:

- **Resource** — the elixir fill rate stops you deploying everything at once. If you can pay for everything,
  the answer is always "all of it, immediately" and **the timing decision disappears**
- **Space** — you may only place on your own half. **If you can place anywhere, position is not a decision
  either**

⇒ **The boat gives the space restriction for free.** The landing point is bound **to the shoreline, i.e. to
one dimension.** **The whole "where can't you drop?" undecided item vanished** — it existed because the sky
drop opened up the entire second dimension.

### The boat is a rule, not a picture (user, 2026-08-17)

**The substance of the rule is one sentence — "you only come in from the shoreline" — and the boat is the
picture of it**; the user framed it that way first. **And then decided to promote the boat to the rule
side**: *"배는 규칙이지. 일단 규칙으로 해놓자."* (*"The boat is a rule. Let's make it a rule for now."*)

⇒ **So what stops simultaneous deployment is the boats themselves** — ~~the landing-craft interval~~, no:
**how many boats there are and how long the round trip takes** (updated below). Not a resource, not a cooldown.
**No resource UI is needed, and the restriction is already drawn on the screen** — if you can see a boat you
can deploy, if you can't you can't. One of the reasons `v2-openfield` died was that nothing on screen ever
went down, and this restriction **is itself the picture.**

#### ⚠ But **the unit of the restriction is also the unit of dead air**

Second adversarial review: a 60s island with a 3s interval gives 20 summon opportunities; at roughly 0.7s of
hand time each (number key + click) that is **14s total, 46s of dead air = 77%.** At a 5s interval, **86%.**
The measurement that killed `v2-openfield` was **61%**, against a baseline of 25%. **This reproduces a worse
number.**

⚠ **And "if the time limit is the lose condition then dead air is death, so the design can't ignore it" is
arithmetically wrong.** **Dead air is a ratio** — shorten the island and numerator and denominator shrink
together, leaving the ratio where it was. What a time limit prevents is **the run dragging**, not **the
hands idling.**

**The claim that there are two controls is not accurate either.** One summon actually answers four
questions — deploy now or wait for the next boat · which of the five · where on the shoreline · **and since
targeting is nearest-first, the landing point is the target choice.** **There are two inputs but four
decisions, and you exercise those four once every 3–5 seconds.**

> **~~Candidate: capacity 1 at a 0.5s interval~~ — the user produced a different answer. See "The boat"
> below.**
> That candidate's evidence was the Pikmin row in
> [What makes placement a decision](what-makes-placement-a-decision.md) —
> *"the real time spent throwing is itself the cost, so 'all of them on one side' is physically slow."*
> **That evidence survives intact inside the answer below.**

### The boat — **five per trip, ~~every 3 seconds~~, and the crossing takes time** (user, 2026-08-17)

⚠ **"Every 3 seconds" was updated the same day — the "Updated" section just below is the live rule.**
The capacity of five and the crossing time both survive intact.

*"한 척에 최대 다섯 마리로 하고, 배에 태워서 보내는 거지. 3초 기다렸다가 선착장 같은 데서 내리는
것도 있는 거지."* (*"Up to five per boat, and you load them aboard and send them. And there's waiting 3
seconds and then unloading at something like a dock."*)

| | |
|---|---|
| Capacity | **Up to five per boat** |
| Interval | **3 seconds** |
| Crossing | **It takes time.** Sending is not arriving |

⚠ **This inverts the "77% dead air" calculation.** That calculation treated the whole 3 seconds as idle,
but **filling one boat is five decisions**, so the 3 seconds is not dead air — it is **loading time.**
⇒ **A tempo appears** — fill, send, watch them arrive, fill again.

**And the crossing time creates two more things:**

- **Prediction becomes a decision.** Send now and they arrive 3 seconds later (a 6-second round trip), so
  you have to load for **the situation then, not the situation now**
- **A long crossing is dangerous.** Ranged enemies shoot the incoming boat — see the "Engagement rules"
  section.
  ⇒ **It is the only rule that makes landing cost something, and unlike the rejected landing tax it is
  plausible**

**Noted as meta-unlock candidates**: shorter boat travel time · higher capacity · ~~shorter interval~~ →
**one more boat** (the user proposed these; the last one changed when the interval went away).

### ⇒ Updated: **there is no interval. The fleet is a fixed count and boats come back** (user, 2026-08-17)

*"The number of boats is fixed, a boat is transport, and you use them strategically. I think one boat
leaving per click is best."* / *"The round trip is six seconds."* / *"Two to start with."*

| | |
|---|---|
| Fleet | **Two boats to start** |
| Capacity | **Up to five per boat** (unchanged) |
| Launch | **Not one readied every 3 seconds.** **Click and a boat leaves right then** |
| Round trip | **6 seconds.** It unloads and must sail back to port before you can use that boat again |

**One deployment looks like this**: load **up to five with the number keys → click a dock and that boat
sails.**
⚠ **Loading and launching being one action is the only reading that satisfies both the user's "one boat
per click" and the already-decided capacity of five.** The user did not say that sentence itself.

**What changing the interval into a fleet count buys:**

- **The restriction is drawn on screen.** A boat in port means you can send; no boat means you cannot. The
  "the unit of the limit is the unit of dead air" problem dissolves — **the player creates the waiting
  themselves, by choosing to spend the fleet**
- **Having the whole fleet at sea is the tension.** Send both to the far side, have the pull fail, and there
  is nothing to do but wait six seconds
- **The return trip is the rhythm.** A boat that never comes back makes a static puzzle; one that does makes
  a beat

#### ⚠ But **2 boats × capacity 5 = 10 = the entire starting force**

On the first island **two clicks land everyone.** The 6-second round trip only acquires a value after that.
⇒ **On the first island the boats do not limit throughput at all; they ask exactly one question — "which
two docks do I split across?"** That is the same question pulling asks, so **it is the intended shape rather
than a defect**, and the fleet only starts biting as a limit **once rewards push the army past 10.**
⚠ **The reason to hold back still does not come from the boats.** It comes from the width of the contact
line — see that section.

### Docks — **the island decides where you can land** (user, 2026-08-17)

*"어디에 내릴지는 선마다 이미 있는 걸로 하자. 선마다 이미 있고, 무시하는 병사도 있고."*
(*"Let where you land be something each island already has. Every one already has them, and there are
soldiers that ignore them too."*)

You pick **one of the few docks the island owns, not any point on the whole shoreline.**

⇒ **"Where" shrinks from a continuum to one-of-N.** That buys three things:

- **It reads.** In an autobattler the screen is everything, so it is better that the places you can pick
  are visible
- **It becomes level design.** Hand-authoring enemy strength is already decided, and **dock placement is
  that hand's main tool**
- **Pulling works at dock granularity.** "The other side" becomes **a different dock** instead of a vague
  direction

> ### ⚠⚠ The user reversed this decision themselves (user, 2026-08-17)
>
> **The quote above is from 2026-08-17 and this one is later**: *"완전히 막혀있는 데가 아니면 어디든지 보낼
> 수 있게"* (*let me send them anywhere that isn't completely blocked*).
> ⇒ **The whole unblocked coastline is a landing point. The one-of-N dock rule is dead.**
>
> **Play refuted the first argument (it reads)** — the docks were visible and **read as buttons**:
> *"그냥 버튼 여기 누르세요 이런 느낌"*. The other two survive and **blocked (cliff) coastline takes them
> over.** ⇒ The rules and the arithmetic live in [the boat and the landing](boat-invasion.md); the rejected
> branch is in [open coastline over fixed docks](../decisions/open-coastline-over-fixed-docks.md).

⚠ **And "a soldier type that ignores docks" is itself a build.** It overlaps naturally with the flying
type — ignore elevation *and* ignore docks and that one type opens the whole terrain. **Which is why what
that type costs matters** (an undecided item in the "Terrain" section).

**Still undecided**: how many docks an island has. **Too few and pulling does not work; too many and the
decision blurs.**

### ⚠⚠ Three holes the third adversarial review found — **all open**

**1. There is no rule for who boards the boat.** A soldier is an individual — permanent death, HP that
carries over, and a specialty that bolts onto **one soldier**. But summoning is **by type** (one type per
key).
⇒ **Press `1` five times and which five board?** A 3-HP one and a 10-HP one, one carrying a specialty and
one not, are all mixed together behind the same key. **The document answers this nowhere, and without it
HP carryover, specialty bolting and the bench threshold in the "contact line" section are all
unexecutable** — you can name who gets the part but you cannot name who ships out.
> Candidate: **the key picks the type, and the highest-HP individual of that type boards automatically.**
> One line of rule settles it and leaves room to add manual picking later.

**2. The range numbers have no unit, and the island's size is not in "What is decided".**
(The pulling section does state a 40-tile island width once while writing out its model, but **that is an
assumption inside one calculation, not a rule.**) "Range 0 · 3 · 30" is written down, but **if 30 is tiles
it crosses the island, and one constant then deletes docks, tiers, ramps and pulling all at once.**
If it is pixels, 3 is nothing.
⚠ It is exactly the shape of **"a constant is not what reaches the screen"** (the 4.8× error) in
[Lessons from two dead games](../lessons-from-two-dead-games.md).
> Candidate: **pin the unit of range and area to "tiles", and put the island's tile count in the
> "What is decided" table.**

**3. A flying type cannot be priced.** The three candidates written down (lower health · shorter range ·
takes more room on the boat) **are all non-prices.** If ground enemies cannot hit it, the damage taken is
zero, so **HP carryover, permanent death and the time limit are all void**, and low health is not a price
when nothing lands. Pricing by throughput fails too — even at 2 per boat, a force of 10 is fully deployed
in 5 boats and 15 seconds, so **the price never once bites.**
> Candidate: **a flying soldier ignores elevation and pathing, but is not removed from targeting.**
> The move the document wants (gather the enemy at a ramp and fly over the top) comes from **geometry**,
> not invulnerability, so it survives untouched.

### Controls — ~~**bind soldier types to the 1–5 keys and press to summon**~~ (user, 2026-08-17)

> ### ⚠⚠ This whole section was overturned (user, 2026-08-18)
>
> **The quote above is from 2026-08-17 and this is later**: *"전투 중에 손이 움직이는 거, 안 움직일 거
> 같은데."* (*"the hand moving during combat — I don't think it will."*) ⇒ **Nothing is pressed during
> combat. The plan is finished in front of the start button.**
> **The 1~5 summon keys are deleted** — the user asked directly: *"근데 칸을 왜 눌러? 이거 배 때문에 칸
> 누르는 거 맞아?"* **The answer was yes.**
>
> ⚠ **And the "pre-set orders" branch this section rejects below is exactly what was chosen.** It wrote
> *"the user's own first/middle/last example was on that side, but the hotkey summon is what was decided"* —
> **the user has come back to their own first example.** The stated ground for rejecting it (hands idle
> during combat) **was not refuted; the user chose to pay it.**
>
> ⇒ Rules and screens belong to [plan it, then watch it](plan-then-watch.md).
> The rejected fork is [commit before the fight, not during it](../decisions/commit-before-the-fight-not-during.md).

*"내가 얻은 몬스터들을 1, 2, 3, 4, 5 단축키에 넣어두고 그 몬스터들을 소환하는 게 맞을 듯."*
(*"I think the right thing is to put the monsters I've collected on the 1, 2, 3, 4, 5 hotkeys and summon
them from there."*)

**So it is real-time.** The island is already running; the player watches, **presses a number to pick a
soldier type, and clicks a point on the shoreline.** The alternative — numbering squads and issuing orders
to them (send squad 1 over there) — **was dropped because it means too many keypresses and there is already
plenty to look at on screen.**

⇒ **One hand for the type, one hand for the position.** Two controls, and both mean something at every
moment.
⇒ **Which is why the cap on soldier types is five** — the fingers set it. Only that many appear on screen too.

⚠ **There is a case against real-time.** Clash Royale is PvP, so the real-time pressure is itself the fun.
**In a single-player roguelite the same pressure can read as stress**, and it also moves away from "deploy
quickly and simply." The other branch, **pre-set orders** (decide first/middle/last before the fight and
then watch), has deeper decisions but **leaves the hands idle during combat** — the user's own
first/middle/last example was on that side, but **the hotkey summon is what was decided.**

---

## Rewards — **three axes, and a combat island gives exactly one**

> ### ⚠⚠ Two of the axes changed (user, 2026-08-18) — **do not read the table below as it stands**
>
> | This section's axis | Now |
> |---|---|
> | **Count** — soldiers +N | **Cells.** Eating grows cells, **not the soldier count** (user, decided 1) |
> | **Specialty** — bolts onto one soldier | **An object.** It bolts onto a **slot, `1`–`5`**, not onto a soldier |
> | **Artifact** — applies to the army | **Unchanged.** Just not built in the first round |
>
> ⇒ **And adversarial review item 2 below — "who to bolt a specialty onto is not a decision" — closes on
> this change.** Soldier three and soldier seven are indistinguishable; **slot 1 and slot 4 are not.**
> **It was not solved; it stopped existing.**
> ⚠ **A new load appears in its place**: "every object makes that slot dearer" is only a decision if the
> arithmetic works, and **it is proved not to under a linear cost.** Rules and arithmetic belong to
> [the session loop](session-loop.md).

The user decided: *"어떤 노드는 병사 수 증가가 있고, 어떤 노드는 병사의 붙이기가 있다. 두 개로 가자."*
(*"Some nodes give more soldiers, some give something to bolt on. Let's go with those two."*)
And the chest gives the third — below.

**Count** is how many soldiers you have, **specialty** is what those soldiers are, **artifact** is what the
army's rules are.
**Give them together on one island and picking an island stops being a decision** — every path hands you
everything. Split them and every fork in the map asks **which one you are short of right now.**

| Island | Axis | Reward | Why |
|---|---|---|---|
| Combat | **Count** | **+N** | The curve is predictable. No arithmetic required |
| Combat | **Specialty** | **One specialty**, you pick who it bolts onto | The specialty side needs a reason to fight too |
| Elite | **Combat + artifact** | **The same reward a combat island gives, plus one artifact** | See "Elite" below |
| Chest | **Artifact** | **One artifact.** It is not bolted on — **it applies to the army** | The resting square |
| Boss | — | **The run ends here. There is no reward** | There is no next island, so there is nowhere to spend it |

**Combat islands split in two.** Combat islands that give count and combat islands that give a specialty —
both involve fighting. That is what makes a fork in the map ask **"am I short of count or short of
specialties right now?"**

**The chest gives an artifact** (user: *"상자에서 아티팩트를 얻는 거다. 전체 HP 상승, 전체 공격력 증가 같은
것들."* — *"you get artifacts from chests. Things like +HP for everyone, +attack for everyone."*).
**A specialty and an artifact are different objects:**

| | Specialty | Artifact |
|---|---|---|
| Where from | Combat island | Chest island **and elite island** (this row used to say chest only, and elites give one too) |
| Where to | **Bolts onto one soldier** | **Applies to the army.** Not bolted on |
| If that soldier dies | **It dies with them** | **It stays** |
| The decision | Who to bolt it onto | Which artifact to take |

In one line: **a specialty changes a soldier; an artifact changes a rule.**

⚠ **"Applies to everyone" and "applies to one squad only" are not different axes — they are a condition
field on an artifact.** *Everyone +1 HP* and *soldiers with legs +2 attack* are two cards of the same form.

⇒ **Decided (user): build artifacts with army-wide effects only first, and extend the condition field
later.** Two reasons. In the first vertical slice there is only one soldier type, so **a condition does
nothing at all**, and what can even *be* a condition **only exists once the engagement rules are settled**
(range? cooldown? bolted parts?).

### ⚠ Multiplication multiplies **the survivors** — this one line decides everything else

Use multiplication as "win and you double" and **lost soldiers are simply restored next fight.** Permanent
death then exists in name only and does not hurt — **and loss hurting is the heart of this design, not a
side effect.**

⇒ **Multiply the survivors and loss compounds.** 10 → win, lose 2 → 8 → ×2 → 16.
10 → win, lose 5 → 5 → ×2 → **10.** The same victory, a twofold difference in outcome, **and that difference
comes from whether you placed well.** Bad North's "it hurts even when you win" structure appears for free,
from one line of rule.

> ### ⚠ The paragraph above is wrong — a 2026-08-17 adversarial review refuted it with arithmetic
>
> **16 against 10 is not two times, it is 1.6 times. And take the ×2 away and 8 against 5 is also 1.6.**
> Multiplication multiplies both sides equally, so it **preserves the gap exactly.** Loss did not start
> compounding — **the pain did not change at all.** Addition actually **shrinks** the gap: 11 against 8 is
> 1.375.
>
> **And multiplication has no livable band.** Write the casualty rate as `f` and one elite island's growth
> rate is `2(1−f)`: at `f < 0.5` it explodes, at `f = 0.5` it is exactly zero, at `f > 0.5` your force
> shrinks and nobody goes. **There is no `f` that is "favourable but not explosive."** Addition gets an
> equilibrium for free — the fixed point of `S → S(1−f)+N` is `S* = N/f`, and at N=3 · f=0.2 it converges
> on its own to **15**. No cap needed.
>
> **A dominant path falls out too.** Combat −2 +3, elite −4 ×2, start 10, six islands:
> combat only gives **16**; elite only gives 12 · 16 · 24 · 40 · 72 · **136**. The condition for elite to
> beat combat is `S > 2c₂−c₁+N = 9`, and **the start is already 10.** The threshold is a constant while `S`
> only grows, so **cross it once and you never come back** ⇒ +N becomes a dead square you take only when
> you are already losing.
>
> ⚠ **This is the same failure as in [Lessons from two dead games](../lessons-from-two-dead-games.md).** The
> price (the casualties) has **already** been paid before the multiply, and **the multiply itself is free.**
> Even the fact that optimal play collapses into one sentence is the same — the old game's "split to the cap
> and stay bunched" is **"only pick elites"** here.
>
> ⇒ **The user produced a third answer: they deleted multiplication from the rules.** See "Elite" below.

### Elite — **multiplication is deleted. It is a harder island that gives one more artifact** (user, 2026-08-17)

*"엘리트는 그냥 조금 어려운 섬인 거지. 다른 데랑 똑같이 하고 플러스로 아티팩트를 하나 더 주자.
그리고 엘리트 특성을 가진 병사들을 만들 수 있는 거지."* (*"An elite is just a slightly harder island.
Same as anywhere else, plus one more artifact on top. And you get to make soldiers that have that elite's
trait."*)

| | Combat island | Elite island |
|---|---|---|
| Difficulty | Baseline | **Harder** |
| Reward | Cells **or** an object | **The same, plus one artifact** |
| On top | — | **You gain that elite's soldier type** — from then on you can field soldiers with that trait |

⇒ **`×2` is gone from the game.** What the two refutation boxes above killed was exactly that
multiplication, and **this decision closes it by deleting the rule rather than repairing it.** The cap on
soldier count, the crossover point from addition to multiplication, and going all-in on a single soldier
type **all vanish with it** — there is no exponent, so no barrier is needed.

⚠ **And the reason to pick an elite is no longer the multiply, it is "the soldier type I want."** A fork in
the map now asks **"do I want that type?"** on top of "am I short of count or of specialties?"
**And "the build and the route becoming one decision" falls out here for free.** That is exactly what an
option briefly passed through and then deleted — **partial multiplication**, the rule that put the `×2` on
one soldier type instead of the whole army — was trying to build, and failed to build because the
arithmetic caught it.

### So these have to be decided alongside it — **only one is left**

~~Whether elites are multiplication at all~~ · ~~a cap on soldier count~~ · ~~where addition hands over to
multiplication~~ — **all three went away with multiplication.** With no exponent there is nothing to ask
about a cap or a crossover point.

- **Whether a chest gives one artifact or one of three.** One is no decision; three puts a decision in the
  resting square

### ⚠ The other three the adversarial review found — **one is half closed**

**1. A missing rule: what does enemy strength scale with.** A whole section goes to reward arithmetic while
**the number on the other side is never mentioned once.**

⚠ **Half of this item's original argument went away when multiplication was deleted.** It used to say there
are two answers and each kills one axis; the "scale with my soldier count and `×2` gives nothing" branch is
moot now that there is no `×2`, and the "scale with map depth and soldiers are exponential against a linear
enemy" branch **lost its premise when growth became addition.**

**What is left is the problem itself: what sets enemy strength is still not written down.** And the sentence
"that difference comes from whether you placed well" **depends entirely on how much placement changes
casualties, and that rule is not in the document.** If the landing point moves the casualty count by ±1
soldier, the entire reward arithmetic is meaningless.
⇒ **The first answer is settled as "hand-authored"** (undecided item 10). **The formula becomes necessary
only once there are more islands.**
⇒ **And the "contact line" section already supplies one rule connecting placement to casualties** — the
terrain sets the width, and the width sets the casualties.

**2. A specialty's "who do I bolt it onto" is not a decision.** The first vertical slice has so few soldier
types that the third soldier and the seventh are indistinguishable. The only question left is **"stack or
spread", and it ends in arithmetic** — with survival probability `p` and K specialties, the expected
surviving parts are `K·p` **either way**; only the variance differs, K times higher for stacking. It is an
autobattler, so **there is no way to protect the carrier**, which makes spreading strictly dominant.
⚠ **The document had already spotted this trap for the artifact condition field** ("in the first vertical
slice, with only one soldier type, a condition does nothing at all") **and had not written it down for
specialties, where the identical sentence applies.**
> Candidate: **each specialty also gives that soldier +1 HP.** Stacking then protects itself, the expected
> value genuinely rises, and only then is expected value vs variance a real trade-off. The carrier gets
> bigger, which also ties back into **the choice of dock.**
>
> ⇒ **This review item closed on 2026-08-18 — not solved, dissolved.** An object bolts onto a **slot**, not
> onto a soldier, so the question "onto whom" has no referent any more. See `session-loop`.
> ⚠ **The candidate above did not die with it.** "Does an object also give HP" is the value that **flips the
> sign between stacking and spreading** in `session-loop`'s arithmetic, and its adversarial review found the
> doc carries no entry for it at all. **This paragraph is the oldest form of that question.**

**3. Only specialties evaporate, and there is no recovery path anywhere in the game.** Artifacts survive at
⚠ **The 20% below is an input nothing in this document produces** — the live damage model gives per-soldier
damage `A·E/(k²·d)`, which is 2.5 of 10 HP at `k`=10, and the "send everyone" table in this same file reads
**"0 deaths."** So the paragraph's own premise contradicts the model two sections up, and it assumes eight
islands when the map length is undecided and the first slice is three. ⇒ **Read 20% as a target the enemy
tuning has to hit, not as a derived number.** The conclusion (a recovery path is needed) survives only if
the target is met.

100% and soldier count recovers, but at 20% casualties per island only `0.8⁸ =` **17%** of specialties
remain after eight islands. **"The path is the build" — and that build is 83% gone by the time you reach the
boss.** One of the two things distinguishing this from Bad North is erased by arithmetic.

> #### ⇒ This paragraph went void on 2026-08-18 — **its premise is gone**
>
> **Parts bolt onto slots, not soldiers, so a soldier dying does not take a part with it.** The `0.8⁸`
> above rests entirely on "a part dies with its soldier", and that rule no longer exists.
> ⇒ **The missing-recovery-path complaint (undecided 14) is still alive**, but it is now about soldier
> count and HP, not about the build.
> ⚠ **And the conclusion — "one of the two differences is erased" — is void too**: the user dropped
> "the path is the build" outright. What distinguishes this now is **building the army yourself out of what
> you were handed.** ⚠ **This read "designing the five slots", and later the same day the summon keys were
> deleted — taking the grounds for five (five fingers) with them.** What the parts attach to is undecided 1
> of `plan-then-watch`.
> See `session-loop`.
And the chest was called "a resting square", but **there is nothing to rest** — Slay the Spire's campfire
restores a resource that carries across rounds (HP), and here the resource that carries across rounds is
**soldier count**, which the chest does not touch.
(The death-spiral example assumed multiplication and went away with the rule.)
> Candidate: **the chest tops your soldiers back up to the starting count.** It becomes a state-dependent
> node that is "only strong when you are hurt right now", which creates a decision and blocks the death
> spiral at the same time.

---

## The two reference points — **do not remove them from this document (user's instruction)**

**These two gave opposite answers and both succeeded. The point is that there is no right answer to how much
control to hand over.**

| | [Bad North](https://store.steampowered.com/app/688420/Bad_North_Jotunn_Edition/) | [Despot's Game](https://store.steampowered.com/app/1227280/) |
|---|---|---|
| Team | **2 people** (Plausible Concept) | Konfa Games — acquired by tinyBuild during development for **up to $5.4M** |
| Sales | Steam estimate **~790k copies**, ~$8.1M gross ([estimate](https://steam-revenue-calculator.com/app/688420/bad-north:-jotunn-edition), not official) | **100k+ copies** (2022-09, [Wikipedia](https://en.wikipedia.org/wiki/Despot's_Game)) |
| Control | **You command the squads directly.** Where to put whom is the whole game | **No unit control.** You only set weapon combinations and formation |
| Unit loss | **Permanent.** It hurts even when you win | Closer to consumable |
| Art | Minimal | Minimal |

⇒ **Neither of them won on visuals.** And both are small teams. That is why these two were picked.
⇒ **This game sits between them** — the combat is automatic like Despot's Game, and the placement and
permanent death are on the Bad North side.

⚠ **Except that Bad North is not "place and done" — you keep moving squads during the fight.** The developer
himself says he did not remove control, he **lowered its granularity.** ⇒ **This game's no-control cannot be
justified by pointing at Bad North.**
See [What makes placement a decision](what-makes-placement-a-decision.md) — five games that made position a
decision with zero control after commit, and the price each of them paid.

⚠ **Recommended to the user**: play one of the two for a few hours. Once you have one reference point,
judgement gets faster — "like that, but not like this." It is cheaper than talking in circles here.

---

## ⚠ HP carries to the next island — **this is the reason to hold back** (user, 2026-08-17)

**The user found the hole first:** *"병사를 아낄 필요가 없잖아. 그냥 다 보내면 되잖아 사실상. 아껴서 이득
보는 점이 하나도 없는 게임이어서 그 부분이 살짝 걱정이네."* (*"There's no need to hold soldiers back. You
can basically just send everyone. There's no benefit at all to holding back, and that worries me a little."*)

**A correct diagnosis, and nothing else in this document answered it.** If the loss is zero as long as they
don't die, **sending everything is always right, and then "who and when" is not a decision.** Permanent
death only hurts when someone dies, and dying is mostly not my choice.

⇒ **The user's answer: HP carries over to the next fight as it stands.** *"그래야 로그라이크처럼 한 번에 못
깨게 될 거 같은데?"* (*"That's what would stop you clearing it in one go, like a roguelike."*)

**What that one line does:**

- **Deployment itself becomes a cost.** A soldier you send comes back chipped even if they live; only the
  ones you kept back are whole. **Attrition, not death, goes on the scale**
- **It stands directly opposite the time limit.** Hold back and the clock runs; pour everything in and the
  bodies wear down — **"when and how much" becomes a real question on every island.** It is the first
  real-time tension this game has had
- **What the adversarial review found multiplication failing to deliver shows up here.** Loss compounding
  comes not from multiplication but from **HP carryover**

### ⚠⚠ The three lines above are wrong — HP carryover creates **one more reason to send everything**

**A second adversarial review on 2026-08-17 refuted it with arithmetic. It holds per individual and reverses
per army.** What goes on the scale is not one soldier's HP but **the entire HP pool.**

The enemy's total DPS does not change with how many I deploy (the number of enemies on the island is fixed).
Combat time is `T = E/(k·d)`, **inversely proportional to the count `k` I deployed**, and therefore
**total damage taken = enemy DPS × T ∝ 1/k**. **The more you send, the less total HP you lose.**

10 soldiers · 10 HP each (pool 100) · enemy HP 100 · enemy total DPS 5 · soldier DPS 2:

| Deployed | Combat time | Total damage | Deaths | Carried to the next island |
|---|---|---|---|---|
| **5 (holding back)** | 10s | 50 | 10 each → **all 5 die** | 5 troops, 50 HP |
| **10 (everyone)** | 5s | 25 | 2.5 each → **0 deaths** | 10 troops, 75 HP |

**Holding back killed five soldiers and lost 25 more HP.** Permanent death only happens at 0 HP, so
**spreading the damage wide is the same thing as zero deaths**, and the way to spread it wide is to send
everyone.

⇒ **There is no cost term anywhere in this rule set that grows with `k`.** Bottleneck it with terrain tiers
and the soldiers above saturation take no damage either; give the enemy area damage and total damage becomes
a constant rather than rising.

> **~~Candidate: a landing tax of −1 HP~~ — rejected (user, 2026-08-17).**
> **Plausibility** — an animal stepping off a boat and losing blood for it is not a picture that works. And
> **it is not needed:**

### ⇒ Decided: **do not create a reason to hold back at all** (user, 2026-08-17)

The user inverted the question: *"그냥 안 아끼고 다 소환하게 하면 되잖아. 그럼 뭐가 문제가 생기는 거지?"*
(*"Just let them not hold back and summon everything. What problem does that actually cause?"*)

**The answer: only one thing is lost.** "When" and "who" drop out of the decision and **only "where"
remains.**

⚠ **A sentence that used to live here has since died**: *~~the landing-craft interval already physically
prevents "everything at once"~~*. **Deleting the interval removed that barrier** — 2 boats × capacity 5 = 10
= the entire starting force, and both can launch at t=0. ⇒ **Nothing prevents "everything at once" any
more.** The fleet only becomes a limit once the army passes 10.
⇒ The decision that remains is still real: **where do the first two boats each go?**

**Clash Royale works exactly that way.** Nobody hoards elixir over the long run — if you can pay, you play.
The decisions are **what · where · in what order**, not "should I hold back."

⚠ **HP carryover and permanent death both stay.** They cannot be the reason to hold back, but
**"the fight you lost stays with you into the next one"** is the skeleton of a roguelike, and that is what
these two do.

### ⚠⚠ The contact line — a reason to hold back **already exists** (third adversarial review, 2026-08-17)

**`T = E/(k·d)`, which was the whole basis for "the more you send, the less HP you lose", assumes that every
soldier sent hits and is hit at the same time.** Two rules decided on the same day break that assumption —
**"bodies never overlap"** and **"one per tile."**

⇒ **The width `w` of the contact line is a ceiling.** A soldier with range 0 can only hit `w` at a time and
can only be hit `w` at a time. **Anyone past `k > w` adds no DPS and absorbs no damage — they just queue.**

With the same figures (enemy HP 100 · enemy total DPS 5 · soldier DPS 2 · soldier HP 10), fighting at a
2-tile ramp:

| | Combat time | Total damage | Deaths |
|---|---|---|---|
| Open ground, all 10 in contact | 5s | 25 (2.5 each) | **0** |
| Ramp (`w`=2), 10 committed | — | **The damage they will take is 125, over the 100 HP pool** | **Wiped at t=20s while the enemy survives on 20 HP — a defeat** |

**The same enemy turns zero deaths into a defeat, on terrain alone.**

⇒ **`k = w` is optimal, and holding back anyone past that is correct.**

**There is a per-individual threshold on open ground too.** The HP **the whole army saves** by adding one
more soldier is `250/(k(k+1))`, which is **2.27** at `k`=10. But **what that eleventh soldier takes
directly** is **2.06**.
⇒ **The death line is 2.06** — send a soldier whose HP is under it and you are trading one permanent death
for 2.27 HP, and **above it, adding them is a net gain** (2.27 > 2.06).
**The bench threshold exists arithmetically.**

⚠ **So "do not create a reason to hold back", above, is half wrong.** The thing the user worried about —
*"아껴서 이득 보는 점이 하나도 없는 게임"* (*"a game with no benefit at all to holding back"*) — **was already
solved without adding a single rule.** What creates restraint is neither HP nor permanent death but **the
width of the contact line, which the terrain sets.**

⇒ **So "how many do I send" is a real question, and the answer differs per island.** Few at a narrow ramp,
everyone on an open shore. **Hand-authored level design becomes the tool that sets that answer.**

> ### ⚠⚠ The whole section above is wrong — a 4th adversarial review overturned it with arithmetic (2026-08-17)
>
> **1. The `w` cap was applied to my side and not the enemy's.** Two lines above it says *"can only hit `w`
> at a time and can only be hit `w` at a time"*, and then the table lets **the enemy's full 5 DPS land.**
> "Bodies never overlap" binds the enemy too, so **at a 2-wide ramp only two enemies can reach.** Redone:
> 25s × 2 = **50 damage, 5 deaths, and I win at t=25s.** Not a defeat.
> ⇒ The terrain effect is real but it is **"zero deaths becomes five deaths"**, not "zero deaths becomes a
> defeat."
>
> **2. The conclusion `k = w` is exactly backwards.** If the queue takes no damage the queue is **free**,
> and it is a reserve that replaces the front rank as it dies. On the same model `k`=6 and `k`=10 produce
> **identical deaths**, and the extra bodies are insurance against a fight being harder than estimated.
> ⇒ **`k = everyone` is still weakly dominant, and `k = w` is the worst play on the board.**
> ⚠ **The dilemma is exact: if the queue absorbs no damage, holding back is pointless; if it does, this
> section's premise is false.** Neither branch produces restraint.
>
> **3. The bench threshold compares two numbers that are not comparable.** 2.27 is the drop in the army's
> **total** damage (25 → 22.7); 2.06 is the newcomer's **share of that 22.7** — a slice of it, not a cost
> added to it. The real trade is **one permanent death against 4.4 HP saved across the other ten.** And the
> "death line" is not a constant but `250/(k+1)²` — **0.6 at k=20** — so it evaporates as the army grows.
>
> **4. So this section's overturning of a user decision is void too.** *"Do not create a reason to hold
> back"* is marked **(user, 2026-08-17)**; this section is marked **(review)**. The review's arithmetic does
> not hold, so **the user's decision stands as the live rule.**
> ⚠ **A review reports; it does not decide** — CLAUDE.md.
>
> ### ⇒ So where is the cost that grows with `k`? — **there is exactly one: area damage**
>
> Total damage taken = enemy DPS × T, and T is inversely proportional to `k`, so **against single-target
> enemies sending more is always better.** The one exception is **area**: one swing lands on several, so
> **bunching raises the total you take.**
> ⇒ **That is the axis this document already named as one of the two that make position a decision.**
> **Restraint comes from the enemy's attack area, not from the contact line.** In the first slice the unit
> carrying that job is **the lion.**
> ⚠ **Unverified.** Until the first slice is measured this is arithmetic too.
>
> ### ⇒ And the beak doubles `w` — nobody had computed that
>
> Range 1 means **the second rank can attack.** At a contact line of width `w`, a soldier with range `r`
> engages from `r+1` ranks, so **effective width is `w × (r+1)`.**
> ⇒ **The first slice's only specialty is the item that halves the terrain restriction.** It is the same
> line that makes the beak the boss's answer — the plan saw the upside and neither doc saw the cost.

### ⚠ And the "hold back vs the time limit" scale does not hold either

Same review: raise `k` and **all three axes push the same way.**

| Axis | If `k` ↑ |
|---|---|
| Time (the lose condition) | Margin of victory **↑** |
| HP pool | Loss **↓** |
| Permanent death | Deaths **↓** |

**All three inequalities point the same way, so there is no inequality left to form a scale.** Whatever value
you set the time limit to, the optimum is `k = everyone` — **tuning cannot fix it.**

⚠ **And the landing tax alone is not enough either.** With cost `c·k` and a win condition of
`k ≥ E/(d·L)`, the optimum is pinned to the single value `k = ceil(E/(d·L))` — **that is arithmetic, not a
decision.** Solving the same formula every island is the same dead right answer as "split and bunch" in
[Lessons from two dead games](../lessons-from-two-dead-games.md).

⇒ **A decision needs uncertainty, and this document has no source of uncertainty at all.** If enemy count,
placement and strength are all known before landing, `k` is always computed.

> **~~Candidate: the island's enemies are invisible until you land~~ — rejected for the first stage**
> (user, 2026-08-17). *"처음 초원은 보이는 게 맞아."* (*"For the first grassland, being able to see is
> right."*) The combat is automatic, so take the information away too and **you cannot see why you lost**,
> and then the roguelite does not work. ⇒ **Fog becomes a per-node/per-stage property, later**
> (undecided item 12).

### ⇒ Instead the user produced a different answer: **pulling** (2026-08-17)

*"배 타고 오면 원거리 공격을 했으면 좋겠거든. 그래서 소환하면 탱커를 먼저 보내야 하는, 유저가 알아서
학습하게 되는 그런 게 있었으면 좋겠어. 먼저 탱커들이 가면 그 섬에 있는 몬스터가 그쪽에 모일 거잖아.
그럼 그때 반대쪽으로 병사를 보낸다거나."* (*"I want them shot at from range while they come in on the boat.
So that when you summon, you have to send the tank first — the kind of thing the player learns on their own.
If the tanks go in first, the monsters on that island will gather over there. And then you send soldiers to
the opposite side."*)

**That one line ties "who first" and "where" into a single decision.**
Enemies also target the nearest, so **the first squad you land IS the aggro**, ⇒ **position becomes a tool
for pulling rather than a tool for attacking.** The second landing point is chosen from what the first one
pulled.

**So the three that died come back:**

- **"Who"** — the enemies are ranged, so landing a short-range soldier first means it takes hits the whole
  way in. **No rule teaches you that the tank has to go first; the player learns it**
- **"Where"** — whether the far side is empty is decided by the outcome of the first landing
- **"When"** — you wait for the pull to take hold and then land the second wave. **Timing came back without
  a landing tax**

⚠ **The condition for this to work: the enemies must have range** — settled in the "Engagement rules"
section.

⚠ **And this is also the answer to "dead air."** The time spent watching the pull take hold is not
spectating, it is **the input to the next decision.**

#### ⚠⚠ Third adversarial review: **pulling does not oscillate. It is stable, and the stable outcome is a loss**

**Oscillation first.** While the enemy walks toward dock A, its distance to A shrinks and its distance to B
grows ⇒ **nearest-first never flips.** The moment B could become nearest is the moment B's squad has walked
all the way to the enemy mass and stands at the same distance as A — i.e. **when it has already arrived at
the same melee.** ⇒ **What pulling produces is not a flank, it is "delayed reinforcement."**

**The model, stated** (without it the numbers do not reproduce): both sides move at **4 tiles/s**, the enemy
starts **at the island's centre** and so **20 tiles** from each dock, the island is **40 tiles** wide, the
docks are at either end, and the boat is **capacity 5 · interval 3s** — so massing at one dock lands the
second five at **t=3.0s** to walk 10 tiles:

| | Total damage | Combat time | Where the damage goes |
|---|---|---|---|
| 10 at one dock | **32.5** | 9.0s | spread over ten |
| 5 at A + 5 at the far dock B (pulling) | **45** | 11.5s | **40 of it onto A's five** → 2 HP each |

**B arrives at t=10.5s and the fight ends at 11.5s — one second of contribution.**

> ### ⚠ This model's premise disappeared the same day — **it has to be re-measured**
>
> The table above rests on **the 3-second interval.** The interval is deleted; there are **two boats and
> both can launch at t=0** (the "Updated" section). ⇒ **Ten at one dock and five-plus-five at A and B are
> now both simultaneous landings.** "The second five lands at t=3.0s" and "B contributes one second" **no
> longer follow from the rules.**
> ⚠ **So "pulling is the inferior play" is currently unproven** — not refuted, but **left without its
> evidence.** Pulling is no longer "delayed reinforcement", it is **"two directions at the same moment"**,
> and nobody has calculated whether that is good or bad.
> ⇒ **Recompute this table under the new rules before the first vertical slice.** The "first squad is a
> sacrifice" paragraph and the candidate below it both ride on that calculation.
~~⇒ ⚠ **Pulling violates "spreading the damage wide is the same thing as zero deaths" head-on.** The
definition of pulling is "pile it all onto one squad", so **under the current rules pulling is the play that
maximises permanent death.**~~

~~**And the first squad is a sacrifice, and the answer to that is a constant** — in a first vertical slice
with one enemy type, "send the cheapest one first" never changes.~~

> ⚠⚠ **Both paragraphs above are struck, and the reason is the box above them.** They are conclusions of
> the voided 3-second-interval model, and the premise they lean on — *"spreading the damage wide is the same
> thing as zero deaths"* — is itself the claim the contact-line section exists to attack. **A live
> conclusion standing on two retracted propositions is worse than no conclusion**, because the next reader
> inherits it as settled. Striking the table and leaving its conclusions was the exact leak CLAUDE.md names.
>
> **What is actually known about pulling right now**: nearest-first never flips while an enemy walks toward
> the first landing (that proof survives, it does not depend on the interval), so pulling produces
> **delayed reinforcement, not a flank**. With both boats launchable at t=0, sequencing them is now a
> *choice* rather than a constraint — **pulling means voluntarily leaving a loaded boat in port.**
> ⇒ **Whether that trade is worth it is uncomputed.** And pulling is one of only two things separating this
> game from Bad North, so it does not get to stay uncomputed for long.
[Lessons from two dead games](../lessons-from-two-dead-games.md) calls this **"a fact you learn once and
are done with"**, the shape that killed the old game.

> **Candidate (undecided)**: **ranged enemies prioritise an approaching boat over soldiers already ashore.**
> Then the price of pulling is not "B's eight seconds" but **"landing the boat intact"**, and **the choice of
> dock has a value on every single boat.** It is nothing more than promoting the existing "ranged attacks
> while they come in on the boat" **into one line of targeting priority.**

⇒ **And the "contact line" finding above bites here too.** Pull them to a narrow dock and `w` shrinks, so the
number of enemies that can hit at once shrinks with it. **Pulling's value may be "choosing the width you
fight at" rather than "the flank"** — not decided yet.

### ⚠ So a recovery path is now mandatory

**If HP carries and there is no recovery, a run is a one-way decline**, and that is not difficulty, it is
**a scheduled death.** The adversarial review already flagged it — *the chest was called "a resting square"
but there is nothing to rest.*
What Slay the Spire's campfire restores is **the resource that carries across rounds**, and the resource
that carries across rounds in this game **just became HP.**

⇒ **Having the chest island double as recovery is the cheapest answer** — no new node, and the name
"resting square" only becomes true then. **Not decided yet.**

---

## Engagement rules — **this is the TFT side. Hit the nearest, but every soldier has a trait**

**Decided (user, 2026-08-17):** *"TFT 같은데? 가까이 있는 적 때리고. 근데 이제 캐릭터마다 내가 보내는
애마다 조금 특성이 있는."* (*"Like TFT? Hit the enemy that's near. But each character, each one I send, has
a bit of a trait."*)

**That one line decides "is position a decision" all by itself.** TFT and Despot's Game share the same
placement rules (nearest-target · zero control after commit) and in one position is the core decision and in
the other it isn't — **the only difference was whether abilities respond to distance and direction.**
[What makes placement a decision](what-makes-placement-a-decision.md)

⇒ **So "traits" are not decoration; they are the condition under which this game works at all.** If every
soldier hits at the same range in the same way, no terrain you lay down makes position a decision, and
**the studio ends up adding an auto-arrange button.**

### "Trait" points at exactly two things

**It is not a stat list.** Only two things actually do the work of making position a decision; the rest are
numbers stacked on top of those two:

- **Range** — does it have to close, or does it hit from afar. **This is what turns "where do I land them"
  into a question.** Land a soldier that must close at the back and it takes hits while it walks; land a
  long-range soldier at the front and it dies first
- **Attack area** — how wide one hit reaches. **This is what turns "bunch or spread" into a question.**
  Without area, bunching is always right, and placement disappears

⚠ **Both are numbers, not categories like "single-target vs area"** (user, 2026-08-17: *"단일 하나라는 개념
말고 그냥 공격 범위라는 개념이 있게 하자"* — *"instead of a 'single target' concept, let there just be an
'attack area' concept"*). Range 0 · 3 · 30 and area 0 · 1 · 5, that sort of thing.
⇒ **Categories run out of slots as soldier types multiply; numbers do not.** And **enemies and soldiers use
the same table.**

**These two are what actually work in TFT and what Despot's Game did not have.** The rest — speed, health,
targeting priority — may or may not exist, but **drop either of these two and position stops being a
decision.**

⚠ **So "traits" is not a question of how many soldier types there are, but of whether the types are spread
across those two axes.** Five types that are all melee single-target is the same as having one trait.

### Bodies never overlap (user, 2026-08-17)

*"몬스터마다 절대로 겹치면 안 되고."* (*"No monster may ever overlap another."*)

**This is what makes position physical.** If they can overlap, stacking everything on one point is possible,
and then area attacks never generate anything to punish. If they cannot, **a squad necessarily occupies
area**, a narrow path is genuinely narrow, and **one ramp becomes a real bottleneck.**

⇒ **This also solves what [melee readability](../lessons-from-two-dead-games.md) could not solve in the old
game** — a big body swallowing a small one whole disappears structurally.

### Enemies sit on the same two axes — **enemies have range** (user, 2026-08-17)

**This is the condition under which pulling works.** If every enemy is melee, the first squad you land takes
no hits, and then there is no reason to send the tank first — **"who first" dies again.**

⇒ **The enemies' engagement rules are one and the same set as the soldiers'** — target the nearest, with
range and area varying by type. **Two rule sets are not needed.**

⚠ **And ranged enemies fire on the approaching boat** (user: *"배 타고 오면 원거리 공격을 했으면 좋겠거든"*
— *"I want them shot at from range while they come in on the boat"*).
**It is the only rule that makes landing itself cost something, and unlike the landing tax it is plausible**
— the thing shooting is visible on screen.

⚠ **And the first vertical slice has one soldier type.** One type means one trait, which means **position is
not a decision.** ⇒ **Either put two soldier types in the first vertical slice, or run it once with position
not being a decision and confirm that firsthand — one of the two must be chosen.** Not chosen yet.

---

## Terrain — **a block grid. There are tiers, and a tier's value is a "path", not a "bonus"**

### ⚠ The first slice has no tiers — **stay 2D, start with no drop** (user, 2026-08-17)

*"Stay 2D, and let's develop with no drop for now. No tiers for now. No tiers, but holes you fall into —
just that much."*

> ### ⚠⚠ "No tiers" was reversed by the user (user, 2026-08-17)
>
> **The quote above is from 2026-08-17 and this one is later**: *"격자로 보니까 살짝 이 층이 있어도 될 거
> 같아"* (*seeing it on a grid, I think a bit of elevation would be fine*).
> ⇒ **A second level (cliffs) comes in.** The reason is the boat, not the terrain — **cliff coastline is what
> "blocked" means**, and it is the only tool that attaches a cost to a landing point once the whole shoreline
> is open.
> ⚠ **"Stay 2D" was NOT reversed.** Elevation happens inside 2D — the Brood War / AoE2 grounds below stand.
> ⇒ **The tier sections below are now current rules, not "later".** Details in
> [the boat and the landing](boat-invasion.md).

| | First slice | Later |
|---|---|---|
| Tiers / elevation | **None.** Everything is one level | The sections below come back intact |
| Impassable tiles | **Hole tiles exist.** They are what narrows the route | Ramps and cliffs take that job over |
| Flying types | **Meaningless** (there is no elevation to clear) | They arrive with the tiers |

⇒ **The contact-line width `w` survives.** The tool that narrows it changed from a ramp to a **hole**, and
the basis for "sending everyone costs you" is unchanged.

⚠ **3D was considered and dropped.** Bad North really is 3D, but this document's own elevation table already
holds two precedents — **Brood War and Age of Empires II are both 2D sprite games and their high
ground reads perfectly, drawn as the side face of a cliff.** Going 3D **kills the "the body is a line drawn
by code" decision and the whole drawing harness**, and buys one thing: a rotatable camera. ⇒ **Stay 2D.**

**Everything below is the rule for the day tiers arrive. The first slice does not read it.**

### Decided: block grid (user, 2026-08-17)

The island is **divided into tiles.** The user worried about ending up too close to Bad North, and **the
grid was picked not because it belongs to that game but because it is the structure that hands over three
things just decided, all at once and for free**:

| What was decided | What the grid gives |
|---|---|
| Bodies never overlap | **One per tile.** No separate collision handling |
| There are tiers | **One elevation per tile.** The drop is an integer |
| Ramps are bottlenecks | **"A tile you can climb" exists as data** |
| You only land from the shoreline | **The landable tiles are simply a list** |

⚠ **Only occupancy is on the grid; movement stays continuous.** Move tile by tile and it looks angular.

⚠ **The grid is not the differentiator.** What differs from Bad North is **"eating" and pulling**, and the
grid is the floor those two stand on. **A shared floor does not make the games the same.**

### ⇒ Tiers split the soldier types — **flying units do not use ramps** (user, 2026-08-17)

*"새는 올라갈 필요도 없지. 그냥 위에서 이렇게 오는 거니까."* (*"A bird doesn't even need to climb. It just
comes in over the top."*)

**That one line makes elevation the third axis of the soldier-type table.** Ground types climb **only by
ramp**; flying types **ignore elevation entirely.**

⇒ **Which makes the ramp bottleneck a real decision.** Break through the bottleneck, or fly over it — and
**flying does not trigger the pull.** Gathering the enemy at a ramp and then flying over the top is where
this game's first "figured-out move" is going to live.

**Still undecided**: what a flying type costs. If ignoring elevation is free there is no reason to field
ground types. Candidates — lower health · shorter range · takes an extra slot on the boat.

---

## The rules of a tier — **no numbers are stacked on it**

**Raised by the user (2026-08-17):** *"그 맵도 특성이 계단처럼 뭐가 있을 듯? 내가 참고했었던 게임 중에도
그렇게 돼있던데."* (*"The map probably has staircase-like features too? One of the games I looked at was
built that way."*) — **Correct. Bad North's islands are split into several tiers, and early islands have only
one ramp up.**

### ⚠ But Stålberg himself never once mentions a height bonus

What he says about terrain is this: *"The shape of the terrain really matters — it creates different choke
points and different ways you need to position your units."*
([GamesBeat](https://gamesbeat.com/bad-north-shows-that-even-bloody-viking-battles-can-be-artsy-and-cute/))
The constraints on the generator are only three, and all three are **topological** — area for the army to
move in · a shoreline long enough for the whole invading force to land · **and a walkable route from beach to
house.** *"The generator doesn't know it's creating a level for a strategy game, it's just trying to make a
nice wee island."*
([Game Developer](https://www.gamedeveloper.com/blogs/how-townscaper-works-a-story-four-games-in-the-making))

⇒ **Height is a means of shaping routes, not a combat number.** The only confirmed mechanical effects are
that **archer range depends on elevation** and that **knockback drops enemies down a level or into the
water.**
⚠ **"25% damage on hills" is probably not from Bad North at all** — the identical sentence appears verbatim
in an Age of Empires II guide. **Do not use it.**

### The games that did use numbers all use a single constant step

| Game | Rule |
|---|---|
| StarCraft (Brood War) | Attacking from low ground to high ground: **70% hit chance** |
| StarCraft II | **Random miss removed.** The high-ground advantage is **vision blocking only** |
| Warcraft III | **25% miss** attacking uphill (`Combat - chance to miss` defaults to 0.25) |
| Age of Empires II | **×1.25** from above, **×0.75** from below. **Independent of how many elevation steps** |
| Battle Brothers | **+10% hit** on a higher tile, **−10% per level** when lower. Range and vision rise too |
| Into the Breach | **No elevation at all.** Instead of height, **tile type** — mountains block shots, water drowns |

**Pattern: all of them are binary flags in the ±10–30% band, independent of how large the height difference
is.** No case of a continuous height function was found.

### ⇒ So this game's tiers carry no numbers

**The counter-argument gets stronger the closer you get to zero control.** Blizzard **removed** Brood War's
high-ground random miss outright in SC2 and kept only vision — *"Additional miss chance would add more
RNG."* **If the player sees a miss and can do nothing about it, that is noise, not a decision.** This game
has zero control after commit, so that argument is at its maximum.

⚠ **And Bad North players argue on the forums about whether high ground is an advantage or a liability, and
there is not a single number in the thread.** They speak from feel, without knowing the rule — **that is
itself the evidence of a readability failure.**
([Steam discussion](https://steamcommunity.com/app/688420/discussions/0/2479690531131927224/))

⇒ **What tiers do is make the route singular.** One ramp means the enemy can only come up there, and then
**putting a soldier with range up top becomes a positional decision** — with no hidden bonus.
**One thing only gets stacked on: high ground buys range** (which is also the only effect confirmed in Bad
North).

**Still undecided**: whether to include knockback. It makes height **lethal**, the most readable effect
there is, but with no control the player has no way to steer it.

---

## Screen — **the absence of a section here is a hole**

⚠ **The live decision [the body is a line drawn by code](../decisions/the-body-is-a-line-drawn-by-code.md)
defers screen detail to "the GDD's *Screen* section", and the GDD it points at is `cell-game.md`, which this
document replaces.**
⇒ **The living screen spec exists only inside a superseded document.** It stays that way until it is copied
here.

**The only thing certain right now is one picture of the body**: a rounded square drawn in outline, one dot
in the middle, empty in between. **The emptiness is what makes overlap readable** — forty filled bodies
become one lump, forty outlines do not. It is also what the user picked after looking at three side by side.

**Auto-combat made the screen mandatory.** With direct control, the hands make the fun even if the screen
reads poorly; **when it is automatic, watching is all there is.** Above all **it has to show why you lost** —
if it doesn't, you cannot choose differently next run and the roguelite does not work.

**What the old game measured that constrains the new one** (these are constraints, not specs):

- **Past thirteen or fourteen simultaneous hits the flash never turns off.** Per-hit effects become void
  above that
- **Every body went through one leaf, and the only things separating two bodies were colour and size.**
  ⇒ **They have to be separated by shape**
- **A big body covers a small one entirely** — one lion hid about ten clones
- **Nothing on screen ever went down.** The only evidence that you were hitting anything was "it dies
  eventually"
- **All nine effects were about "something I did."** In an autobattler **the only thing I do is drop**, so
  that asymmetry gets worse
- **The engine was never the wall** — 300 `Node2D`s at 0.065ms. **The cap is set by the eye, not by
  performance**

**Nobody has decided any of this yet**: draw order · whether to show enemy health · floating damage numbers ·
animation · hitstop · colour · whether soldiers must look different from each other · **telegraphs**.
⚠ **All colours are placeholders, so every option of the form "use colour to resolve overlap" stands on top
of an undecided item.**

---

## The remaining rules, filled in so the first slice can be built — ⚠ **the user did not decide these**

This is the space the user delegated: *"the goal is to keep it light and get the whole thing running. Go
ahead."* **Everything here is a first value written on the assumption it gets fixed by playing, and none of
it carries user approval.** When approval comes, the line moves up into the sections above.

### Tile occupancy — **reserve the next tile**

Movement is continuous and occupancy is a grid. The rule that joins them:
**a unit reserves the one tile it is stepping into, then walks there. Nobody else may enter a reserved tile.
On arrival it releases the tile behind it. If every candidate tile is taken, it stands still.**
⇒ **"One per tile" and "bodies never overlap" both fall out of one place in the code.** There is no
collision handling.

### Enemy movement — **detect, then walk at the nearest**

An enemy stands where it was placed until **a soldier enters its detection radius, at which point it moves
toward the nearest one.** When none is left, it stops. No patrol, no leash-return.
⇒ **Pulling comes from here.** The first landing trips detection and the mass walks that way.

### Soldiers on a boat can be hit, but cannot hit

This honours the user's *"I want them shot at from range while they come in on the boat"* **without adding a
rule**: **the boat is a picture, and the soldiers aboard are simply soldiers in transit.** They are hit if
they are in range, and **they do not attack before landing.**
⚠ **"Ranged enemies prioritise the boat over soldiers ashore" is still not adopted.** Nearest-first stands.

**A boat does trip enemy detection**, at the boat's own position — otherwise a ranged enemy would never
begin shooting at one, and the picture the user asked for would never happen.
**Soldiers still aboard when the island ends** stay in the roster at their current HP; they simply never
landed.

### The starting leg does nothing

*"A lump of square cells with one leg"* is in "What is decided", and nothing says what the leg **does** —
while an artifact example elsewhere reads *"soldiers with legs +2 attack"*, which implies it is a part with
an effect. **In the first slice it is the picture of being able to move and carries no number.** If it ever
becomes a part with an effect, the artifact condition field is where that lands.

### Unloading — **a dock is one tile and a boat carries five**

"One per tile" leaves four soldiers with nowhere to stand. The rule: **the first soldier takes the dock
tile, the rest take the nearest free passable tiles by breadth-first search from it**, in the order they
were loaded.
⇒ **This sets the landing formation, which sets who is in the contact line.** It is not a detail.

### ⚠ Two tensions this document does not resolve, recorded so the first playtest knows to look

**1. An autobattler is what [planning principle 1](../planning-principles-ko.md) forbids.** That line reads
*"the hands must not idle"*, and it is the single reason a whole defence game was scrapped. **This genre is
defined by watching.**
⚠⚠ **And on 2026-08-18 the user answered this tension by maximising it rather than resolving it** — with
zero control during combat, dead air becomes **100% by design.** **The 94% below was written as a bad
number; it is now the target.** [Plan it, then watch it](plan-then-watch.md) carries what pays for it and
the **three replacement metrics.**
Working the numbers on the fleet: five key presses plus a click is about 1.9 s, two
boats is **3.8 s of hand time for the entire starting force**, and an island that runs its full 60 s is
**94% dead air** — worse than the 61% that killed `v2-openfield`. Shorten the island to ~15 s and it is
~75%, but then the time limit is decoration.
⚠ **This is not an arithmetic error that another pass can catch — it is the genre choice itself.**
⇒ **The first slice's probe prints the dead-air number.** It is the one measurement that decides whether
this direction survives, and no amount of design writing can settle it.

**2. Every reward in the first slice is a flat stat boost**, which is what
[planning principle 8](../planning-principles-ko.md) says is not a combination: *"order has to change the
outcome."* Range +1 and army-wide +HP are both pure increments. **The slice cannot demonstrate principle 8
and is not trying to** — but nobody should read a successful slice as evidence that the build axis works.

## Screen — only as much as the first slice needs

⚠ **The Screen section above says its own absence is a hole; this section fills that hole to exactly the
size of the first slice.** Pixel-level layout belongs to the plan.

| What | In the first slice |
|---|---|
| Grid | **Drawn faintly.** In a game where position is the decision, an invisible grid means you cannot pick a position |
| Land · hole · water | Three colours. **A hole has to read as impassable at a glance** |
| ~~Docks~~ | **Dead** — the whole shoreline is landable now. See `boat-invasion` |
| Bodies | Rounded square outline plus a centre dot. **Friend/foe by colour, type by size and shape** |
| The beak | **A triangle sticking out past the body** |
| HP | **A thin bar under the body.** One of the reasons the old game died was *"nothing on screen ever went down"* |
| Boats | Two boat icons at the port. **A berth empties while that boat is at sea** — the limit is the picture |
| Loading | The number currently aboard, shown beside the port |
| Time left | Top of screen |
| Map | ~~Three nodes in a row~~ → **a branching node map** (user, 2026-08-18: *"두 줄로 떠서 양쪽에서 하나씩 선택하는"* — two rows offered, pick one from each). See `session-loop` |
| Reward | ~~Click a soldier in the roster to bolt the beak onto them~~ → **fit objects in on the refit screen** (user, 2026-08-18). ⚠ ~~into slots 1~5~~ — **what they are fitted into reopened the same day**; see the Parts row of "What is decided" |
| Plan · execute | ⚠ **New (user, 2026-08-18)** — a **planning screen** showing the whole island and every enemy, where boats are placed and ordered before start is pressed, and an **execution screen where the only things pressable are the speed control and the pause.** [Plan it, then watch it](plan-then-watch.md) |
| Win · lose | Centre text. **A loss has to show why you lost** |

## Undecided — cannot be built without picking

⚠ **The phrase "combat rules" pointed at two different things inside this document, and because of that one
of them was missing from the list entirely.** They are now written separately:

- **Deployment restriction** — what gates "drop again" (resource · cooldown · landing-craft interval).
  **Item 8 below**
- **Engagement rules** — how a soldier hits an enemy (range · cooldown · bolted parts). **Item 7 below.**
  ⚠ **This was not on the undecided list, and the artifact condition field already depends on it** — what can
  be used as a condition comes out of the engagement rules

1. ~~When and how do soldiers increase~~ — **decided. See the "Rewards" section.**
2. ~~**Is there any intervention after the drop.**~~ — **decided: none** (user, 2026-08-18).
   *"전투 중에 손이 움직이는 거, 안 움직일 거 같은데."* **A pause exists and it does nothing either** —
   *"이시정지 한다고 해서 내가 또 뭔가를 해줄 수는 없어."*
   ⚠ **So the worry originally written here comes true: at exactly zero it is a game you only watch.**
   Despot's Game kept potions and formation adjustment; **this game keeps nothing.**
   The first line of [planning principles](../planning-principles-ko.md), *"the hands must not idle"*, is
   **broken on purpose** — what pays for it is the section of that name in
   [plan it, then watch it](plan-then-watch.md), and **not one of its three candidates is proven**
3. **Is a specialty fixed per island, or one of three at random.** ~~Fixed makes route choice into build
   choice~~
   ⚠ **Those grounds are dead (user, 2026-08-18).** The user **rejected "what you ate becomes the build"**,
   on level-design cost. **Fixed or random, the build is settled on the refit screen.**
   Rejected in the same breath: **"the island decides what drops"** (eat a swamp and amphibian parts get
   likelier). The fork is in
   [the build is designed, not inherited](../decisions/build-is-designed-not-inherited.md).
   ⇒ **The question itself survives** — random or fixed is still unpicked, and
   **[the session loop](session-loop.md) puts an inequality on the total drops in a run**
4. ~~Lose condition~~ — **decided: a time limit** (user, 2026-08-17). Each island has a clock, and failing to
   wipe them out within it loses.
   ⇒ **And being wiped out is also a loss** (added 2026-08-17). Death is permanent and there is no recovery,
   so **an empty roster arrives before the clock does.** Without this line you sit staring at a running timer
   with nobody left.
   ⚠ **The sentence that used to be here is deleted**: *~~if the time limit is the lose condition then dead
   air is death, so the design cannot ignore it~~*. **The "the unit of the limit is the unit of dead air"
   section in this same file already refuted it with arithmetic** — dead air is a ratio, so shortening the
   island shrinks numerator and denominator together. **A refuted sentence was still standing in another
   section.**
   ⇒ What survives: **"when do I drop" acquires a value** — hold back and you are safe, but the clock runs
5. **Map structure.** ~~Are there branches (Slay the Spire), or is it a straight line~~ — **branches, decided**
   (user, 2026-08-18: *"두 줄로 떠서 양쪽에서 하나씩 선택하는"*).
   ⚠ **Branch count and depth are still open, and the user's "two rows" reads two ways** —
   [the session loop](session-loop.md) records both readings
6. **What the per-soldier-type adjustment is.** The user pushed this to *"later."* Targeting priority?
   Formation? Position?
7. ~~Engagement rules~~ — **decided. See the "Engagement rules" section.**
8. ~~Is deployment real-time or pre-set~~ — ~~**decided: real time.**~~
   ⚠⚠ **Overturned: pre-set** (user, 2026-08-18). **The whole landing is laid out, then start is pressed.**
   [Plan it, then watch it](plan-then-watch.md) ·
   the rejected fork is [commit before the fight, not during it](../decisions/commit-before-the-fight-not-during.md)
9. ~~Cap on soldier count~~ — **decided: no cap** (user, 2026-08-17, *"for now"*).
   **Deleting multiplication removed the exponent itself, so a cap does not need to be a barrier.**
   ⚠ **But [Lessons from two dead games](../lessons-from-two-dead-games.md)' *"there is no readability cap
   anywhere"* still stands** — the decision was to not set a cap, **not a discovery of how many is readable.**
   Look at the first vertical slice and decide by eye
10. **What enemy strength scales with** — **the first answer is "hand-authored"** (user, 2026-08-17:
    *"처음엔 레벨 디자인을 하는 걸로"* — *"do level design at first"*). Not a formula; a person places each
    island.
    ⇒ **The first vertical slice is three islands, so this is enough, and the formula becomes necessary only
    once there are more islands**
11. ~~What stops going all-in on a single soldier type~~ — **gone.** Deleting multiplication removed the
    exponent
12. **Fog — some islands are only visible once you arrive.** As a node or stage property, **later** (user,
    2026-08-17). **The first grassland is fully visible from the start** — the combat is automatic, so with
    the information gone too you cannot see why you lost
13. **Does a soldier type gained from an elite arrive as a soldier on the spot, or get added to the summon
    list.** ~~If the latter, the picture is the 1–5 hotkeys filling up over the course of a run~~
    ⚠ **The question changed (user, 2026-08-18).** Once **the player designs slots `1`–`5`**, there is no
    summon list for the game to fill.
    ⇒ **What an elite hands over has to be material for a slot (an object), not a row in a list**, or the
    two rules contradict. **Not settled; [the session loop](session-loop.md) carries it**
    ⚠ **2026-08-18, later the same day: the slot itself reopened** — deleting the summon key removed the
    grounds for five slots. **This item is deferred behind undecided 1 of
    [plan it, then watch it](plan-then-watch.md)**
14. **The recovery path.** HP carries across islands, and with no recovery a run is a one-way decline.
    **The chest island doubling as it is the cheapest** — the name "resting square" only becomes true then
15. ~~**The boat does not read as a rule on screen**~~ — **closed (user, played it 2026-08-18).**
    The original complaint was *"The boat feels like a side-thing. It isn't needed, and it only makes the
    game harder."* · *"You should float a boat and it goes to the nearest dock — instead it feels like
    'press this button here'."*
    ⇒ **[The boat and the landing](boat-invasion.md) carried this item in full and was built. It replaces
    the 「선착장」 section above as well as 「지형」's "no elevation in the first slice"** (the user decided
    on a fully landable coastline and a second level).
    ⇒ **The user launched it again and "side dish" did not come back.** What came instead:
    *"참 애매하네. 그래도 그동안 중에서 제일 평범하네."* — *"it's really ambiguous. Still, the most
    ordinary of them so far."*
    ⚠ **This item closing and the game being fun are two different sentences.** "Ambiguous" is still
    open, and it is carried by the new item below, not by this number.
16. ~~**The sea is cramped and the terrain is one lonely shape**~~ — **decided: a 48×32 grid** (user,
    *"양쪽 다 키워봐"* — *grow both sides*). The original complaint was *"The terrain could stretch out long,
    but it feels like a quiz with one thing plonked in it."*
    ⇒ **The level design of the three islands is carried by [the boat and the landing](boat-invasion.md)** —
    the current three are 32×18-only, so every coordinate in them dies.
17. **2D or 3D — the user reopened it** (after the first play). *"I'm wondering whether to just do 3D."*
    ⚠ The terrain section decided **stay 2D**, and its grounds (Brood War and AoE2 both read height from
    2D sprites; going 3D kills the "the body is a line drawn by code" decision and the whole drawing
    harness) are untouched. **This is reopened, not overturned.** Judge it on the same screen once the
    presentation lands.
    ⇒ **2026-08-18: the user saw the 48×32 grid and the camera, and did not bring 3D up.**
    ⚠ **Not raised is not closed.** They judged nothing here; they said something else.

18. ⚠⚠ **"Ambiguous" — the one large item still open** (user, after playing 2026-08-18).
    *"참 애매하네. 그래도 그동안 중에서 제일 평범하네."* — *"it's really ambiguous. Still, the most
    ordinary of them so far."*
    **This is what is left once 15 closed.** It only means something read against the two verdicts before it:
    - the first game, eight months — **not one moment was fun**
    - the second game — *"it just isn't fun… I don't know why I'm doing this"*
    - **this one — *"the most ordinary of them so far"***
    ⇒ **"Ordinary" is the highest mark this repo has ever received, and it is still not fun.**
    ⚠ **Proposing a new system here is the failure this repo has circled six times** — see
    [what two dead games left behind](../lessons-from-two-dead-games.md): *when a complaint is one
    sentence, first ask whether a rule can answer it.*
    **Next session's first act is turning "ambiguous" into a number, not choosing what to add.**
    ⇒ **2026-08-18: the diagnosis came back, and it named a place rather than a system** — **the part loop
    (one island) is built and everything above and below it is missing.** No map, no time between rounds,
    no way to build anything. [The session loop](session-loop.md) takes that place.
    ⚠ **That document is an attempt, not an answer, and this item stays open until the user launches it
    again and says so.**
    ⇒ **2026-08-18, later the same day: the user replaced the part loop itself** — the hand does not move
    during combat and the plan finishes in front of the start button.
    [Plan it, then watch it](plan-then-watch.md)
    ⚠ **Half of the session loop died at that moment** (the 1~5 summon keys · its arithmetic section's
    variables · its in-combat bar). **Both documents are attempts, and this item is still open.**

---

## What is different from Bad North — **the user's own worry**

*"어디에 누구 내릴지, 섬 지형, 자동 전투. 지금 너무 똑같아서 살짝 고민인데."* (*"Where to land whom, island
terrain, auto-combat. It's so similar right now that I'm a bit worried."*)

**A correct worry, and right now there are only two differences.**

| | Bad North | This game |
|---|---|---|
| Verb | **Defend.** Waves come and you hold the island | **Eat.** I go and take it |
| Upgrades | Fixed tree (sword · spear · archer) | ~~**The specialty of the island you ate** — the path is the build~~ ⇒ **eating yields cells and objects; the build is assembled on the refit screen** |
| Units | Human squads, fixed classes | Cells plus bolted parts, **combinations open** |

~~⇒ **The whole differentiation rests on one word: "eat."**~~

> ### ⚠⚠ Half of that line survives (user, 2026-08-18)
>
> **The user rejected "what you ate becomes the build"** — *"먹은 걸로 빌드를 짜게 되면 중반 후반에 레벨
> 디자인을 하기가 어려워서"* (*level design gets hard mid- and late-run*). ⇒ **the load the upgrade row was
> carrying moves off it entirely.**
>
> **"Eat" survives as the verb** — cells and objects both come out of it, and **the moment of eating is
> still this game's face.** What changed is that **the verb no longer carries the differentiation alone**;
> the other half is carried by **"you build the army yourself out of what you were handed"** —
> [the session loop](session-loop.md). ⚠ **This said "five slots", a number the summon keys set and the same
> day deleted** — what gets designed is now undecided 1 of `plan-then-watch`.
> The fork is in
> [the build is designed, not inherited](../decisions/build-is-designed-not-inherited.md).

⚠ And having exactly one reference point is not a problem — Balatro's LocalThunk also
[started from Luck Be a Landlord alone](https://www.shacknews.com/article/139116/balatro-inspiration-luck-be-a-landlord-reddit-ama).
**It diverges as you build. The only thing that never diverges is the thing you never built.**

---

## The price of going autobattler — presentation stops being optional

A game you control directly can read poorly and the hands still make the fun. **When it is automatic,
watching is all there is.**

- **The combat has to read.** What the user flagged in the current build was exactly *"분신들이 때리는지도
  모르겠음"* (*"I can't even tell whether the clones are hitting anything"*), and
  [Lessons from two dead games](../lessons-from-two-dead-games.md) is a problem that survives any structure.
  Now it is **the game itself**
- **It has to show why you lost.** If it doesn't, you cannot choose differently next run and the roguelite
  does not work
- **The preparation screen is the real game.** If combat is automatic, the fun is in the preparation. Right
  now that screen does not exist at all

⇒ **The price of giving up control is that presentation becomes everything.** It is not a bad trade —
presentation is code, and it is more predictable than control design. And most of plan 5's presentation code
survives.

---

## Code — what lives and what dies

**The user's decision: rewrite. But tag it rather than delete it.** The previous game was kept the same way
as `v1-sim`, and the current prototype was already written down as *"a reference, not a foundation."*

**What survives** — not one line is thrown away
- **The whole net harness** (`tests/`, `run_nets.ps1`). Eight months of real asset, and the new game stands
  on it from day one
- **The one-file `look.gd` rule** and the `_paint_*` hook structure, plus the scans that enforce them
  (`net_draw_leaf`, `net_citations`)
- **Plan 5's presentation code** — hits, death, level-up. It matters more in an autobattler
- The shape of the `Parts` table (flat arrays + dodging the `const` trap)
- `tools/pixel/`, the Korean font, all of `docs/`

**What dies**
- Most of `src/sim/` — the open field, spawning, wander/hunt/flee, the host, `F`/`V`, the eleven slots,
  wearing/digestion
- Half of `src/view/` — the minimap, the zoom curve, the body panel
- All the level-curve documents and `tools/look/probe_run.gd` — **they were instruments for the open field
  only**

---

## What to do next session — **in order**

1. ~~Pick the commitment limiter~~ — **decided: the fleet.** ~~The landing-craft interval~~ was replaced the
   same day: **2 boats · capacity 5 · one leaves per click · 6-second round trip.** Neither a resource nor a
   cooldown was needed.
   ⇒ **Building it swappable is still the spec.** All of them differ by one or two constants.
   ⚠ **The numbers are now pinned, so this item is closed** — but the section *"the unit of the limit is the
   unit of dead air"* was written against the interval and **its conclusion has not been redone for a fleet**
2. **What do you start a run with** — force and body are under "What is decided." What is left is **whether
   you start with 0 or 1 specialty**
3. ~~Where can't you drop~~ — **gone.** Reversing to the boat pinned the landing point to the shoreline,
   which is one-dimensional
4. **Build the first vertical slice** — a straight-line map of three islands, all the way to a run finishing.
   ⚠ **Two soldier types — one melee single-target, one ranged area.** Everything else minimal: one
   specialty · ~~one enemy~~ **two enemies** · no chest island, no elite island, no map branches.

   ##### The first slice's stage and enemies — **grassland, a crow and a bison** (user, 2026-08-17)

   *"The first stage is a field, and there'd be crows and animals and horses and cattle and bison and lions.
   But it's the first one, so let's have just the crow and the bison for now."*

   | | What | Why these two are enough |
   |---|---|---|
   | Stage | **Grassland (open field)** | It fits a first slice with no tiers. The later ladder is mammals → dinosaurs |
   | Enemy 1 | **Crow** | **The range side.** Pulling only works if at least one enemy has range |
   | Enemy 2 | **Bison** | **The melee side.** Slow, large, comes straight at you |

   ⇒ **This closes the third review's demand that there be two enemies.** With only a ranged enemy the
   player's melee type is strictly inferior; with only a melee enemy pulling dies. **The crow and the bison
   are exactly those two seats.**

   ⚠ **And the open candidate "ranged enemies prioritise an approaching boat" gains its plausibility here** —
   **crows mobbing a landing boat** needs no explanation. Not adopted yet.

   ##### The grassland's specialty — **the beak** (user, 2026-08-17)

   *"The beak. A bird's beak. Just that for now."*

   | | |
   |---|---|
   | What | **The crow's beak.** It bolts onto one surviving soldier |
   | Effect | **Range +1** — a melee soldier becomes half-ranged |
   | Picture | **One triangle sticking out past the body**, seen from above |

   ⇒ **The first specialty lands on the range axis.** As this document pins down, **the only two axes that
   make position a decision are range and attack area** — had it been +attack, bolting it on would change
   nothing about where you land.
   ⇒ **And it fits "on a top-down body, only what sticks out reads"** (measured by `tools/pixel/`). A mane
   does not read; a beak does.

   ##### The three islands — **grassland · grassland · lion** (user approved, 2026-08-17)

   | Island | Enemies | Reward | Time limit |
   |---|---|---|---|
   | 1 | **Bison only** | +N soldiers | 60s |
   | 2 | **Bison + crow** | **The beak** | 60s |
   | 3 | **Lion (boss)** + bison + crow | none (the run ends) | 90s |

   ⇒ **The lion is the island you can lose on.** And the reason you can lose comes out of the rules —
   **the HP the first two islands took off you carries straight in.** Losing to the boss is the first proof
   that HP carryover does anything.
   ⚠ **Arrive undamaged and the boss is easy too. That is not a bug, that is having played well.**

   **Later candidates (user)**: an elephant, a chimera, some legendary creature. **Not in the first slice** —
   the user's goal is *"keep it light and get the whole thing running first."*

   ⚠ **One worry the user left on the record**: *"I don't know whether this will come out juicy in 2D."*
   **Planning cannot judge that.** It gets judged by running the first slice — the second line of
   [planning principles](../planning-principles-ko.md).

   ⚠ **Still undecided**: whether a specialty also gives **+1 HP**. The adversarial review wrote that down as
   a candidate — *without it, "who do I bolt it onto" is not a decision* — and it has not been adopted.
   **That is what lets you ask "is this fun?" for the first time** — the last game died because nobody ever
   ran the loop end to end

   #### ⚠⚠ And **holding it to one enemy type lands in the same place even with two soldier types** (third review)

   **The condition for pulling is "the enemies must have range", and with only one enemy type that one type
   has to be the ranged one.** That leaves zero melee enemies, and **the player's melee single-target type
   becomes a strictly inferior unit that only ever takes hits while it walks.**
   ⇒ **Two soldier types collapse into one in practice.** There have to be two enemies as well — one melee,
   one ranged.

   ⚠ **And losing is impossible in the first vertical slice.** The only lose condition is the time limit,
   but a fight ends in about ten seconds, and `T = E/(k·d)` **is computed before you land** ⇒ that is
   checking arithmetic, not deciding.
   **"It has to show why you lost" cannot be tested — because you cannot lose.**
   ⇒ **The first vertical slice needs at least one island you can lose on.** Not decided yet.

   #### ⚠ Hold it to one soldier type and none of this document's claims can be verified

   The second adversarial review counted **eight rules that die in a one-type slice**:
   ~~**the 1–5 hotkeys** (one type = one key)~~ ⚠ **void — the keys themselves were deleted on
   2026-08-18** · **range** · **area** ("bunch or spread" ceases to exist) ·
   **tiers and ramps** (with one range there is no "put the ranged soldier up top") · **map forks** ·
   a specialty's "who to bolt it onto" · the artifact condition field · **pulling** (there is only one thing
   to pull with and only one alternative).
   ⇒ **Pulling dying is the biggest of these.** It is the largest rule found today and it does nothing at
   all in the slice.

   ⇒ **If it comes out unfun, you cannot tell whether that is the design's fault or the slice's.** It repeats
   the failure that killed the last game, **except this time running it doesn't even give an answer.**
   **Adding one more soldier type is the price.**
5. **Nets land in groups of five or more.** Below that the wrapper refuses the round

---

## What the first play said — **the user ran it themselves** (2026-08-17)

The first vertical slice was built and **the user launched it and played.** This section is what came out of
that. **It is a kind of input that did not arrive once in eight months**, which makes it heavier than any
arithmetic above it.

| | What the user said | What it means for this doc |
|---|---|---|
| **The look** | *"I actually like what I'm seeing"* | **The body drawn by code** cleared its first gate |
| **Presentation** | *"the ranged one shooting at something — all of that is needed. Right now there's just nothing there"* · *"there has to be a joy in watching the action. The feel of squads colliding"* | Exactly what the section "the price of going autobattler" predicted. ⇒ [combat juice](combat-juice.md) |
| **The boat** | *"the boat feels like a side-thing… it only makes the game harder"* · *"it feels like 'press this button here'"* | ⚠ **Open as Undecided 15.** "The boat is a rule, not a picture" did not read as a rule on screen |
| **Sea and terrain** | *"the sea feels too cramped"* · *"the terrain could stretch out long, but it feels like a quiz with one thing plonked in it"* | ⚠ **16.** The 32×18 grid and the three islands' level design |
| **Dimension** | *"I'm wondering whether to just do 3D… but I can't picture this being fun in 2D yet either"* | ⚠ **17.** The terrain section's **stay 2D** decision is reopened |

⇒ **The user deferred all three (boat · terrain · 3D) themselves**: *"leave the detail bits out — it plays
fine, but the presentation needs to go in and be tested."*
**Presentation first, then look again.** ⚠ **Deferred is not closed** — all three live in Undecided.

⚠ **And one probe number attaches here: dead air 98.4–99.6%.** Under the "everything at once" policy the
hand has something to press for **0.10–0.20 s per island**, with all 12–16 commands landing in the first two
or three frames and nothing to press for the next 12–50 s.
**That is worse than the 94% the section "the two tensions this doc cannot resolve" predicted.** The user
played it in that state and said *"it plays fine"* — **the number and the felt experience disagree, and
which one is right has to be asked again once the presentation is in.**

---

## What this document cannot answer

**Whether it is fun.** That is the second line of [planning principles](../planning-principles-ko.md), and it
is also why one conversation went six rounds before this direction appeared. **The last line of the
reference-points section is the only prescription for it.**
