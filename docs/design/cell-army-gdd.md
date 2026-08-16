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

You start as one lump of square cells, eat the islands one at a time, **bolt each island's specialty onto
your bodies** to build your own army, and fight an opposing army at the end.

⚠ **This line came out of the user's mouth as it stands** — *"얘도 먹어보고 싶고, 쟤는 먹을까 하고 먹어보러
가는 거지."* (*"I want to try eating this one, and I go over to that one wondering whether to eat it too."*)
The previous GDD's one line (deleted) **had the swarm appear only as a means**, so parts bolted onto the
host alone, so the clones never belonged. **The game was built exactly as the document told it to be**, and
this line inverts that.

---

## The loop is three deep

### Meta loop — outside a run

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
map opens → pick an island → [main loop] → one reward from that island (count · specialty · artifact) → back to the map → … → boss island → clear
                                 ↓ lose                ↑ a chest island arrives here without a fight
                              run over
```

### Main loop — one island

```
the island unfolds → land them on the coastline (where · when · who) → auto-battle → a dead soldier is dead for good
                                                                        ↓ wipe them out
                                                                     victory
```

**And the smallest unit that repeats, at the innermost level, is this:**

> **Drop → watch → drop again.**

⚠ **In the big picture, the only thing not decided is what gates the "again."** Resource, cooldown, or
landing-craft interval. **That one choice sets the game's tempo.**

**Decisions the player makes**: which island to go to · **where, when and who to land** · **how much to hold
back** · who to bolt a specialty onto · which artifact to take.

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
| Rewards | **Three axes, and one island gives exactly one** — **count** · **specialty** (bolts onto one soldier) · **artifact** (applies to the army). See its section below |
| Starting force | **Ten cells** (user: *"처음에 차라리 세포 열 마리를 주고."* — *"just give ten cells at the start."*) |
| Parts | A specialty *is* a part, and **it bolts onto a soldier** (there is no host) |
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

⇒ **So what stops simultaneous deployment is the landing-craft interval.** Not a resource, not a cooldown.
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

> **Candidate (undecided)**: **drop the landing craft's capacity to 1 and the interval to 0.5s.**
> Throughput per second (the total budget of the restriction) is unchanged, but **the decision rate becomes
> 2Hz** and the hands stop idling. The evidence is already in this repo —
> the Pikmin row in [What makes placement a decision](what-makes-placement-a-decision.md):
> *"the real time spent throwing is itself the cost, so 'all of them on one side' is physically slow."*
> ⇒ **And this partially pays off the "send everything" problem above too** — sending everything costs
> physical time.

### Controls — **bind soldier types to the 1–5 keys and press to summon** (user, 2026-08-17)

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

## Rewards — **three axes, and one island gives exactly one**

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
| Elite | **Count** | **×2 on one soldier type only** | See "Partial multiplication" below |
| Chest | **Artifact** | **One artifact.** It is not bolted on — **it applies to the army** | The resting square |
| Boss | **Count** | **×2 or more — multiplier undecided** | It is the end of the run, so there is no next island |

**Combat islands split in two.** Combat islands that give count and combat islands that give a specialty —
both involve fighting. That is what makes a fork in the map ask **"am I short of count or short of
specialties right now?"**

**The chest gives an artifact** (user: *"상자에서 아티팩트를 얻는 거다. 전체 HP 상승, 전체 공격력 증가 같은
것들."* — *"you get artifacts from chests. Things like +HP for everyone, +attack for everyone."*).
**A specialty and an artifact are different objects:**

| | Specialty | Artifact |
|---|---|---|
| Where from | Combat island | Chest island |
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
> ⇒ **The user produced a different answer. See "Partial multiplication" below** — instead of dropping to
> addition, **they narrowed what multiplication reaches.**

### Partial multiplication — **multiply one soldier type, not the whole army** (user, 2026-08-17)

*"곱셈은 사실상 특정 부분만 곱셈하게 하자. 예를 들면 근접 병사만 곱하기 2라든지, 까마귀 보스를 잡으면
까마귀 병사만 곱하기 2라든지."* (*"Let multiplication only actually multiply a specific part. Melee soldiers
×2, say, or kill the crow boss and only the crow soldiers ×2."*)

**This closes the refutation above with one line of rule.** Multiplying the whole army gave a growth rate of
`2(1−f)`, which mathematically had no livable band; **multiplying one type binds the growth rate to that
type's share** — if melee is three of ten, 10 → 13, and **multiplication effectively becomes "addition at a
size I chose."**

⇒ **And the build decides the size of the multiply.** Collect crows and the crow elite pays big; skip them
and it pays small. **"Which island do I go to" and "what have I collected" become, for the first time, one
decision.** The dominant elite-only path dies with it — **not every elite is a gain, only the elite that
matches my build.**

#### ⚠⚠ It is not an "extreme" — **it is an attractor.** The second adversarial review refuted it

**The share `p` is not a fixed parameter. The ×2 raises `p` directly:** `p → 2p/(1+p)`.
That island's growth rate is `1+p`, so **the growth rate itself rises every island.**

Start 10 (melee 3 / other 7), zero casualties, melee elite six times:

| Island | Melee | Total | `p` | Growth this island |
|---|---|---|---|---|
| 0 | 3 | 10 | 0.300 | — |
| 1 | 6 | 13 | 0.462 | 1.30 |
| 2 | 12 | 19 | 0.632 | 1.46 |
| 3 | 24 | 31 | 0.774 | 1.63 |
| 4 | 48 | 55 | 0.873 | 1.77 |
| 5 | 96 | 103 | 0.932 | 1.87 |
| 6 | 192 | **199** | 0.965 | 1.93 |

Six rounds of +3 gives **28**; whole-army ×2 gives **640**. **Partial multiplication only brought 640 down
to 199, and the growth rate approaches ×2 with every island.** Even with a flat 20% casualty rate the
explosion condition is `p > 0.25`, and **the start is 0.3, so it is above the threshold from the first
island**; even starting at 0.2, **one elite takes it to 0.333 and over.**

⚠ **This is exactly the shape the refutation box found in whole-army multiplication** — *"the threshold is a
constant while `S` only grows."* **Only the axis moved, from `S` to `p`.**

⇒ **"The player cannot choose which type an elite multiplies" is the only version that passes the
arithmetic.** With a uniform random pick among five types, each `p` rises evenly, settles near 1/5, and the
growth rate is bounded at `1.2`. **This is not an undecided item — it is the condition under which this rule
holds.**

> **Candidate (undecided)**: **the map decides which type an elite multiplies, and the player cannot pick.**

### So these have to be decided alongside it

- ⚠ **Whether elites are multiplication at all.** Read the refutation box first. Until this is settled the
  two items below are meaningless
- **A cap on soldier count.** The moment multiplication is in, the curve is exponential, and with no cap the
  screen bursts mid-run — **by the arithmetic above it passes 40 on the fourth island and 136 on the sixth.**
  What that number is, is undecided item 9
- **Where addition hands over to multiplication.** Early addition and late multiplication means **when you
  can first beat an elite** *is* the difficulty curve. Tune it with the depth at which elites appear on the
  map
- **Whether a chest gives one artifact or one of three.** One is no decision; three puts a decision in the
  resting square

### ⚠ The other three the adversarial review found — all open

**1. A missing rule: what does enemy strength scale with.** A whole section goes to reward arithmetic while
**the number on the other side is never mentioned once.** There are only two answers and **each kills one
axis** — scale with map depth and your soldiers are exponential against a linear enemy, so it is free from
mid-run onward; scale with your soldier count and **×2 gives nothing at all.**
And the sentence "that difference comes from whether you placed well" **depends entirely on how much
placement changes casualties, and that rule is not in the document.** If the landing point moves the
casualty count by ±1 soldier, the entire reward arithmetic is meaningless.
> Candidate: **enemy count is fixed per island (rising only with depth), and the pressure on each of my
> soldiers is inversely proportional to how many I have.** Fewer soldiers means a higher casualty rate, so
> **loss genuinely compounds without any multiplication.**

**2. A specialty's "who do I bolt it onto" is not a decision.** The first vertical slice has one soldier
type, so items 3 and 7 are indistinguishable. The only question left is **"stack or spread", and it ends in
arithmetic** — with survival probability `p` and K specialties, the expected surviving parts are `K·p`
**either way**; only the variance differs, K times higher for stacking. It is an autobattler, so **there is
no way to protect the carrier**, which makes spreading strictly dominant.
⚠ **The document had already spotted this trap for the artifact condition field** ("in the first vertical
slice, with only one soldier type, a condition does nothing at all") **and had not written it down for
specialties, where the identical sentence applies.**
> Candidate: **each specialty also gives that soldier +1 HP.** Stacking then protects itself, the expected
> value genuinely rises, and only then is expected value vs variance a real trade-off. The carrier gets
> bigger, which also ties back into **the landing position.**

**3. Only specialties evaporate, and there is no recovery path anywhere in the game.** Artifacts survive at
100% and soldier count recovers, but at 20% casualties per island only `0.8⁸ =` **17%** of specialties
remain after eight islands. **"The path is the build" — and that build is 83% gone by the time you reach the
boss.** One of the two things distinguishing this from Bad North is erased by arithmetic.
And the chest was called "a resting square", but **there is nothing to rest** — Slay the Spire's campfire
restores a resource that carries across rounds (HP), and here the resource that carries across rounds is
**soldier count**, which the chest does not touch. There is a death spiral too: at S=4, an elite gives
`(4−4)×2 = 0` — **a wipe.**
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

> **Candidate (undecided)**: **−1 HP the moment they step off the boat** — a **landing tax** unrelated to
> the outcome of the fight. Only then is the cost `c·k`, proportional to `k`. The boat is already on screen,
> so it is neither new UI nor a new system.

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

> **Candidate (undecided)**: **the island's enemies are invisible until you land and your sight reaches
> them.** `E` becomes an unknown and **"should I send more as insurance?"** becomes a question for the first
> time.
> ⚠ **It has to be paired with the landing tax** — add only one of the two and you fall straight back into
> one of the two refutations above.

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
- **Area** — does it hit one or several. **This is what turns "bunch or spread" into a question.** Without
  area damage, bunching is always right, and placement disappears

**These two are what actually work in TFT and what Despot's Game did not have.** The rest — speed, health,
targeting priority — may or may not exist, but **drop either of these two and position stops being a
decision.**

⚠ **So "traits" is not a question of how many soldier types there are, but of whether the types are spread
across those two axes.** Five types that are all melee single-target is the same as having one trait.

⚠ **And the first vertical slice has one soldier type.** One type means one trait, which means **position is
not a decision.** ⇒ **Either put two soldier types in the first vertical slice, or run it once with position
not being a decision and confirm that firsthand — one of the two must be chosen.** Not chosen yet.

---

## Terrain — **tiers like a staircase. But a tier's value is a "path", not a "bonus"**

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

## Undecided — cannot be built without picking

⚠ **The phrase "combat rules" pointed at two different things inside this document, and because of that one
of them was missing from the list entirely.** They are now written separately:

- **Deployment restriction** — what gates "drop again" (resource · cooldown · landing-craft interval).
  **Item 8 below**
- **Engagement rules** — how a soldier hits an enemy (range · cooldown · bolted parts). **Item 7 below.**
  ⚠ **This was not on the undecided list, and the artifact condition field already depends on it** — what can
  be used as a condition comes out of the engagement rules

1. ~~When and how do soldiers increase~~ — **decided. See the "Rewards" section.**
2. **Is there any intervention after the drop.** At exactly zero it becomes a game you only watch. Despot's
   Game kept potions and formation adjustment. The first line of
   [planning principles](../planning-principles-ko.md) is *"the hands must not idle."*
3. **Is a specialty fixed per island, or one of three at random.** Fixed makes route choice into build choice
4. ~~Lose condition~~ — **decided: a time limit** (user, 2026-08-17). Each island has a clock, and failing to
   wipe them out within it loses.
   ⇒ ⚠ **This blocks the problem that killed `v2-openfield` at the rule level.** That game's measured failure
   was **61% dead air**, and if the time limit is the lose condition then **dead air is death**, so the design
   cannot ignore it.
   ⇒ And **"when do I drop" acquires a value** — hold back and you are safe, but the clock runs
5. **Map structure.** Are there branches (Slay the Spire), or is it a straight line
6. **What the per-soldier-type adjustment is.** The user pushed this to *"later."* Targeting priority?
   Formation? Position?
7. ~~Engagement rules~~ — **decided. See the "Engagement rules" section.**
8. **Is deployment real-time or pre-set.** Pre-set makes **the preparation screen the game itself**, which
   reorders everything. The user's first/middle/last example was on the pre-set side
9. ~~Cap on soldier count~~ — **decided: no cap** (user, 2026-08-17, *"for now"*).
   **Partial multiplication already flattened the exponent, so a cap does not need to be a second barrier.**
   ⚠ **But [Lessons from two dead games](../lessons-from-two-dead-games.md)' *"there is no readability cap
   anywhere"* still stands** — the decision was to not set a cap, **not a discovery of how many is readable.**
   Look at the first vertical slice and decide by eye
10. **What enemy strength scales with** — **the first answer is "hand-authored"** (user, 2026-08-17:
    *"처음엔 레벨 디자인을 하는 걸로"* — *"do level design at first"*). Not a formula; a person places each
    island.
    ⇒ **The first vertical slice is three islands, so this is enough, and the formula becomes necessary only
    once there are more islands**
11. **What stops going all-in on a single soldier type.** Partial multiplication reverts to exponential in
    exactly that case — see the "Partial multiplication" section

---

## What is different from Bad North — **the user's own worry**

*"어디에 누구 내릴지, 섬 지형, 자동 전투. 지금 너무 똑같아서 살짝 고민인데."* (*"Where to land whom, island
terrain, auto-combat. It's so similar right now that I'm a bit worried."*)

**A correct worry, and right now there are only two differences.**

| | Bad North | This game |
|---|---|---|
| Verb | **Defend.** Waves come and you hold the island | **Eat.** I go and take it |
| Upgrades | Fixed tree (sword · spear · archer) | **The specialty of the island you ate** — the path is the build |
| Units | Human squads, fixed classes | Cells plus bolted parts, **combinations open** |

⇒ **The whole differentiation rests on one word: "eat."** If that verb does not read on screen, this game
really is a worse Bad North. **The moment of eating is this game's face.**

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

1. ~~Pick the commitment limiter~~ — **decided: the landing-craft interval.** Once the boat became a rule,
   neither a resource nor a cooldown was needed.
   ⇒ **Building it swappable is still the spec.** All three differ by one or two constants.
   ⚠ **What is left is the capacity and interval numbers**, and the section *"the unit of the limit is the
   unit of dead air"* bears directly on them
2. **What do you start a run with** — force and body are under "What is decided." What is left is **whether
   you start with 0 or 1 specialty**
3. ~~Where can't you drop~~ — **gone.** Reversing to the boat pinned the landing point to the shoreline,
   which is one-dimensional
4. **Build the first vertical slice** — a straight-line map of three islands, all the way to a run finishing.
   ⚠ **Two soldier types — one melee single-target, one ranged area.** Everything else minimal: one
   specialty · one enemy · no chest island, no elite island, no map branches.
   **That is what lets you ask "is this fun?" for the first time** — the last game died because nobody ever
   ran the loop end to end

   #### ⚠ Hold it to one soldier type and none of this document's claims can be verified

   The second adversarial review counted **eight rules that die in a one-type slice**:
   **the 1–5 hotkeys** (one type = one key) · **range** · **area** ("bunch or spread" ceases to exist) ·
   **partial multiplication** (`p = 1`, so it is **identical to whole-army ×2** — the rule the refutation box
   killed comes straight back) · **tiers and ramps** (with one range there is no "put the ranged soldier up
   top") · **map forks** · a specialty's "who to bolt it onto" · the artifact condition field.

   ⇒ **If it comes out unfun, you cannot tell whether that is the design's fault or the slice's.** It repeats
   the failure that killed the last game, **except this time running it doesn't even give an answer.**
   **Adding one more soldier type is the price.**
5. **Nets land in groups of five or more.** Below that the wrapper refuses the round

---

## What this document cannot answer

**Whether it is fun.** That is the second line of [planning principles](../planning-principles-ko.md), and it
is also why one conversation went six rounds before this direction appeared. **The last line of the
reference-points section is the only prescription for it.**
