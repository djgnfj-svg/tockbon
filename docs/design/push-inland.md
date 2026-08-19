# Push inland — one combat node becomes a continent

**One line**: **land on a coastline, push inward for 10–15 minutes, and the only thing your hand touches
after the start button is the next boat.**

**Implemented**: none — not one line of code. Every number below is derived or read out of the shipped
tree; nothing here has been run.
**Accepted**: nothing chosen. The user decided the shape (2026-08-19, quoted throughout); **no arithmetic
in this doc has been put to them, and three of its findings contradict things they said the same day.**

---

## 0. What this doc is, and the one thing it refuses to do

It replaces **what happens inside one combat node**. The node map is untouched — five floors, seven
nodes — and so is 「층마다 둘 중 하나」. What changes is that a node stops being a 48×32 island with a
one-minute skirmish and becomes a long tile map you land on repeatedly and grind forward through.

⚠ **It does not decide the loss condition, does not invent a party-composition axis, and does not touch
the chest, artifacts, meta unlocks, 3D, the refit screen, or the node map's layout.** Where the user's
2026-08-19 conversation left something open, it is in section 12 and it stays open.

⚠⚠ **Read section 4 before section 3.** The loop in section 3 is what was decided; section 4 is the
arithmetic, and **the arithmetic breaks two of the decided rules.** A reader who takes section 3 as
buildable will size the map wrong by a factor between 9.3 and 19.2.

---

---

## ⚠⚠ CORRECTION — **this doc ran ahead of the user, and three of its premises are wrong** (2026-08-19)

> ***"대륙이 왜 캐넓어졌어? 혼자 어디까지 간 거요? … 일단은 그대로 하면은 너무 키우지 마 일단. 일단
> 잡기 시작해서 천천히 늘리자"*** (user, 2026-08-19)

**Read this before section 4, section 6 or section 11.**

**① The map size was never asked for.** The user said only ***"엄청 길어도 돼 그 맵이"*** — **a permission,
not a specification.** The 984–1,476 columns are this doc's own derivation from 10–15 minutes, and the
user's answer on seeing them was that it had run ahead. ⇒ **Map size is 미정, and the stated direction is
to start from today's 48×32 and grow it slowly.**

**② Camera only.** No minimap, no strategic view, no second renderer. Section 11's strategic-view row and
7.3's whole-island argument are **withdrawn as requirements** — the arithmetic in them still holds against
a big map, and that is a reason not to build a big map yet, not a reason to build a renderer.

**③ 「배치가 미리 보인다」 meant the ENEMIES are visible, and that already ships.** It was read here as a
new visibility requirement. It is not one, and nothing has to be built for it.

⇒ **What this does to the rest of the doc.** Every number downstream of *a node lasts 10–15 minutes*
— the 19–29× multiplier, the 9.3–19.2× body shortfall, R's 3.1–to–90-second interval, the 41× authoring
cost, the walls in section 9 — **is the arithmetic of a TARGET, not a specification for the next build.**
⚠ **They are not wrong and they must not be deleted**: they say what breaks *if* the size is reached, and
growing slowly is precisely how each one gets measured on the way rather than met head-on. **But no plan
may take a figure out of section 4 and build to it.**

⚠ **The lesson, recorded because this repo keeps them**: the user gave a permission (「엄청 길어도 돼」)
and a target (10–15분), and this doc turned both into dimensions. **A permission is not a number.**

---

## 1. What was decided (2026-08-19, the user's own words)

| # | Rule | The user's words |
|---|---|---|
| 1 | **One combat node's contents become a continent.** The node map is NOT replaced | *"노드하나하나가 저정도의 대륙이여야할듯? 이해했나? 지금 니가한 제안이 전투노드 하나임"* |
| 2 | **Land on the coastline, then push inward — that is the whole of a node.** The layout is visible up front | *"섬 단위로 클리어하는 게 맞고 배로 가는 것도 맞는데, 그니까 처음은 해안선으로 가는 거지. 해안선으로 들어와서 그걸 쭉 미는 게 하나의 과정인 것이. 그리고 배치나 이런 게 미리 보이는 거지"* |
| 3 | **It is a continent, not an island, and the map may be very long. A tile map** | *"섬이라기보단 대륙 단위죠. 엄청 길어도 돼 그 맵이. 타일맵"* |
| 4 | **Landings repeat, and may come in on the flanks** | *"구지 꼭 정면만 배가 들어올 수 있는건 아니여서 측변도 가능하잖아? 그래서 상관없을듯"* |
| 5 | **A stage is 10–15 minutes**, thinking time included | *"스테이지당 10~15분 정도가 좋을듯 다만 고민하는 시간이 있으니 문제없을듯"* |
| 6 | **The time limit is deleted** | *"지금 제한 시간 개념은 없어져야 될 거 같고"* |
| 7 | **Speed stays as it is.** 1× is the only rate | *"처음에는 아마 지금 정도의 속도가 맞을 거 같아"* |
| 8 | ⚠⚠ **You may act during the fight, but only on boats.** A soldier already ashore cannot be touched | asked *"전투 중간에 참여할 수 있게 할래? 아니면 처음에 세팅하고 끝날 때 정도여서?"* and answered *"저 배만 좀 참여하는 걸로 해서 기획 한번 해보자"* |
| 9 | **Landing is a denylist and boats route over water** — only what is blocked is painted | *"상륙 못하는 데가 있는 거지 상륙 가능한 데가 있는 게 아니야"* · *"못내림만 표시하면 됨"* |
| 10 | **Attributes exist (range, area, speed, attack speed); element and damage types do not** | *"사거리 범위 속도 다 있을 거 같은데? … 근데 속성은 없을 거 같아"* |

⚠ **Rule 10 carries a warning that must survive**: *many numbers is not many axes*. If range, area, speed
and attack speed never punish each other they add into one 총 전투력 and 「많이 뽑으면 이긴다」 comes
back. Without a type system **the numbers themselves have to collide** — ranged wants to bunch, area
punishes bunching. That is not a proposal; it is the condition rule 10 has to satisfy, and
`what-makes-placement-a-decision` measured it on two shipped games (section 10 below).

---

## 2. What the shipped tree actually measures — the baseline every number below stands on

Read out of `src/sim/` and the probe, 2026-08-19. **Not one of these is an estimate.**

| Quantity | Value | Where |
|---|---|---|
| Grid | 48 × 32 = **1,536 tiles**, 40 px each = 1,920 × 1,280 px | `islands.gd`, `look.gd` |
| Land tiles per island | **744 · 760 · 716** = 2,220 of 4,608 ⇒ **48.2% land** | counted off `ISLAND_ROWS` |
| Enemies per island | **8 · 12 · 14** = 34 ⇒ **one per 65.3 land tiles** | counted off `ISLAND_ROWS` |
| Enemy HP per island | **160 · 184 · 330** = 674 ⇒ **mean enemy 19.8 HP** | counted against `Rules.UNITS` |
| HP a node costs | **27 · 41 · 77** — ⚠ **per island, paired with that island's enemy HP** | the probe, recorded in `title-and-map` |
| Harbours per island | **3 · 3 · 3** | counted off `ISLAND_ROWS` |
| Starting roster | **10** (6 melee + 4 ranged), pool **116 HP** | `Rules.START_MELEE` / `START_RANGED` |
| Roster ceiling on a route | **19** (10 + 3 `COUNT` nodes × 3) | `Rules.map_max_count_nodes_on_a_route()` |
| Nominal army DPS at 10 | **18.0** (6×2.0 + 4×1.5) | `Rules.UNITS` |
| Soldier speed | **4.0 tiles/s**, both types | `Rules.UNITS` |
| Boat speed | **4.0 tiles/s** | `Rules.BOAT_SPEED` |
| Time limit | **60 · 60 · 90 s** | `Islands.TIME_LIMITS` |
| **Actual play time** | **30.30–31.80 s** on island 3; worst plan of 15 runs at **49%** of its limit | the probe, recorded in `islands.gd` |
| Planning drags an island | **10–13** — ⚠ **and the probe reports 「실행 중 조작 0회」.** Every drag happens **before** the start button, and `islands.gd` says planning is free | the probe |
| Visible world at `ZOOM_MIN` 0.45 | **2,844.4 px = 71.1 tiles wide** | `look.gd` |

### ⚠ Refutation — the multiplier is not 7–15×, it is 19–29×

The obvious reading of rule 5 is against `TIME_LIMITS`: 600–900 s against 60–90 s is **7–15×**.
**That is the wrong denominator.** The clock has never once bound — 15 runs, worst at 49% — so the limit
was never the play time. **The play time is 31 s.**

⇒ **600 ÷ 31.05 = 19.3 · 900 ÷ 31.05 = 29.0.** Every scaling number in this doc uses **19–29×**, and any
plan that sizes a continent off the 7–15× figure builds a node that ends in four minutes.

---

## 3. The loop — plan → land → push → plan again

**The three phases are the user's; the minute counts are derived in section 4 and are the first thing to
distrust.**

**Minute 0 — plan.** The continent is laid out and *"배치나 이런 게 미리 보이는 거지"*: enemy placement,
terrain, the whole coast. Boats are free — load, place, reorder, undo, nothing costs anything until the
start button. You commit a first wave: N boats, N soldiers, one landing zone or several.

**Minutes 0–1 — land.** The boats cross. Each carries **one** soldier (`Battle.send` takes a
`soldier_id`, singular) and unloads onto its target tile. The beachhead is whatever survived the
crossing; coastal enemies fire into boats already (`_nearest_soldier(..., ashore_only = false)` is why),
so a landing under a crow's 12-tile detect radius is paid for before anyone is ashore.

**Minutes 1–13 — push.** Soldiers walk toward the nearest enemy and fight. **You do not touch them.**
The one live verb is the boat: watch where the front stalls, and send the next soldier — to the front, or
to a flank, or behind. This is the whole of rule 8.

**Minute n — plan again.** A flank landing is not an interruption of the push; it is the next planning
moment. Rule 4 exists precisely to chop the 10–15 minutes into these.

**Node end.** Every enemy dead. The node pays what its `MAP_NODES` row says, the survivors carry, the
dead stay dead, back to the map.

### ⚠ Refutation — this loop has between 10 and 19 planning moments in it, total, and they front-load

`Battle.SoldierState` runs **RESERVE → TRANSIT → ASHORE and never backwards**; the one reverse edge is
`recall`, refused after the commit. A boat carries one soldier. Boats are unlimited but **soldiers are
not** — the user's own rule: *"배는 너무 곁다리 느낌이다 … 무한으로 배를 띄워서 보낼 수 있는걸로하고
싶어"*, and `plan-then-watch` records the cap moving off the boat count and onto **how many monsters you
own**.

⇒ **A node offers at most R landing decisions, where R is the roster: 10 at the first node, 19 at the
last.** Not 10 per minute — 10 for the entire node.

| R | 600 s | 900 s |
|---|---|---|
| 10 | one decision per **60 s** | one per **90 s** |
| 19 | one per **31.6 s** | one per **47.4 s** |

**And they decay to zero.** A player who lands eight of ten in the opening wave has **two** actions left
for the remaining nine to fourteen minutes.

⚠ **There is no baseline to compare this against, and an earlier draft of this doc manufactured one.**
That draft divided today's 10–13 drags by the 31-second fight to get "one action every 2.4–3.1 s". **It is
not a rate at all**: the probe prints 「실행 중 조작 0회」, the drags are 「계획 행동」, and `islands.gd`
records that the clock starts at the start button and planning is free. **The 10–13 drags happen while
the clock is stopped, in a phase with no duration.** And the user's 「조작감이 너무 ㅈ같음」 was about
**aiming** — a ~10 px drag source, a 0.18-alpha drop zone — not about cadence.

⇒ **The count stands and the rate does not.** What is structural is: **a node offers at most R landing
decisions, R is a free variable nobody has set, and the decision supply of rule 8 IS R.** Section 4
derives the map from R too, and section 5.3's second payer wants **R = 93–192** — at which the same
600–900 seconds hold **3.1 to 9.7 seconds** between actions instead of 60–90.

⇒ ⚠⚠ **This design cannot currently say whether the player acts every 3 seconds or every 90 — a factor
of 29 — and the only thing standing between those two answers is R.** That, not "rule 8 fails", is the
finding.

---

## 4. How big is one node — the arithmetic, and its free variable

Nobody has fixed the dimensions. Three independent-ish paths, all from section 2.

**Path A — from enemy HP.** Contact efficiency: island 3 has 330 enemy HP, the army does 18.0 nominal
DPS, and the fight takes 31.05 s. `330 ÷ 18.0 ÷ 31.05` = **59% of the node is spent in contact**; the
other 41% is crossing and walking. ⚠ **This is island 3 alone** — the probe's per-island times for
islands 1 and 2 are not in this repo.

> enemy HP for t seconds = 18.0 × 0.59 × t
> t = 600 → **6,372 HP** · t = 900 → **9,558 HP**
> ÷ the three-island mean enemy of **19.8 HP** → **322 to 482 enemies**

**Path B — from walk speed.** The 41% not in contact is walking, at 4.0 tiles/s.

> push length = 0.41 × t × 4.0
> t = 600 → **984 columns** · t = 900 → **1,476 columns**

⚠ **Paths A and B share the 59% efficiency figure**, so they are not independent and their agreeing
proves nothing.

**Path C — from density. ⚠⚠ It looked like a cross-check and it is an identity.** Three-island density is
one enemy per **65.3** land tiles at **48.2%** land:

> 322 × 65.3 = 21,000 land tiles ÷ 0.482 = **43,600 tiles** · 482 × 65.3 ÷ 0.482 = **65,300**
> ÷ path B's length → height = 43,600 ÷ 984 = **44.3** · 65,300 ÷ 1,476 = **44.3**

### ⚠⚠ Refutation of this doc's own first draft — path C carries no information about t

Substituting the definitions, `height = [(18 × 0.59 × t ÷ 19.8) × 65.3 ÷ 0.482] ÷ (0.41 × t × 4.0)`.
**`t` cancels.** Both ends of the range land on the same number **because it is the same number for every
t**, including t = 31 s. It is not a confirmation; **it is an identity whose value is fixed entirely by
the source islands' tiles-per-enemy and mean enemy HP.**

⚠ **And it moves 47% depending on which islands you average.** An earlier draft of this section used
island 3's constants alone (51.1 tiles per enemy, 46.6% land, 23.6 HP) and got **30.1** — one row off
today's 32, which read as a striking confirmation. **On all three islands the same identity returns 44.3.**
Nothing about the design changed between the two figures; only which rows were counted.

⇒ **The height is NOT derived by this doc.** Section 13's question *"confirmation or coincidence"* has a
third answer: **tautology.** **The height floor needs a real source and does not have one.**

### ⇒ The candidate: **984 to 1,476 columns. The height is open.**

| | 600 s node | 900 s node |
|---|---|---|
| **Length (derived)** | **984 columns** | **1,476 columns** |
| vs today's 48 columns | **20.5×** | **30.8×** |
| Pixels wide at 40 px/tile | **39,360** | **59,040** |
| Viewport-widths at zoom 1.0 | **30.8** | **46.1** |
| Viewport-widths at `ZOOM_MIN` 0.45 | **13.8** | **20.8** |
| **Enemies (derived)** | **322** | **482** |
| **Enemy HP (derived)** | **6,372** | **9,558** |
| Tiles at today's height of 32 | 31,488 (**20.5×**) | 47,232 (**30.8×**) |
| Tiles at today's density instead | 43,600 (**28.4×**) | 65,300 (**42.5×**) |

**Length and enemy count are derived. Height is not, and the two ways of getting a tile count disagree by
38%.** Everything in section 9 is sized at the **31,488** floor, so every performance figure there is a
lower bound.

**Grow the length.** That much is both derived and what the user said — *"엄청 길어도 돼 그 맵이"*.

### ⚠⚠ The free variable is R, the roster — and it moves DENSITY, not length

An earlier draft of this section said the map size is proportional to R. **Path B refutes it: `0.41 × t ×
4.0` does not contain R.** A bigger army walks the same distance in the same time; it only kills faster.
So holding t fixed at 10–15 minutes:

> **length is set by t alone** — 984 to 1,476 columns at any R
> **enemy HP, enemy count and therefore density are linear in R**
> R = 50 → **31,900–47,800 enemy HP, 1,610–2,410 enemies** in the same 984–1,476 columns
> ⇒ one enemy per **13 to 20** land tiles, against today's 65.3

⇒ **R does not lengthen the continent, it thickens it.** ⚠ **A plan that reads column counts off a table
scaled by R oversizes the map by up to 7.5×** — and 12.2 says the same thing from the other side: length
and decision count are independent knobs.

⇒ **You still cannot finish sizing a continent until R is decided, and nobody has decided it.** 12.1a (the
1~5 slot keys, hold-to-summon) is the one that would move R. **It is the single largest undetermined
quantity in the design**, and the density, the authoring cost and every figure in section 9 inherit it.

---

## 5. ⚠⚠ The cost — what a 10–15 minute node with no clock actually charges

CLAUDE.md's sharpest sentence: **an advantage with no cost is not a decision, and a mechanic that is not a
decision is not fun.** Rule 6 deletes the clock. So: what costs anything?

### 5.1 First, the proposal is already in the tree

⚠⚠ **The replacement — *losing = running out of bodies* — is a PROPOSAL. It was put to the user and they
did not confirm it, and nothing below may be read as closing it.**

What *is* on the record is narrower, and it predates the clock's deletion:

- `battle.gd` has `Lose.WIPED`, checked in `_phase_clock` on `army.living_count() == 0`
- The GDD's 미정 4 wrote it down on **2026-08-17**: *"And being wiped out is also a loss … Death is
  permanent and there is no recovery, so an empty roster arrives before the clock does."*

⚠ **Read that sentence's reasoning, not just its conclusion.** It says an empty roster arrives **before
the clock does** — it is an argument for a *second* loss condition standing behind a first one. **Nobody
has confirmed it as the ONLY one, in a world with no clock at all**, and that is a different rule with a
different consequence. ⇒ **It stays open**, and the two questions the arithmetic can actually reach are
**whether an empty roster is reachable** (5.3) and **whether waiting costs anything once the clock is
gone** (5.2). They answer in opposite directions.

### 5.2 Waiting costs nothing — and that strengthens the dominant strategy the probe already measured

Boats are unlimited, they round-trip, and **there is deliberately no brake**. Delete the clock and there
is no term left that makes an earlier landing better than a later one. The probe has already measured
what happens when nothing charges for time: **「land next to a harbour」 dominated 3 of 3 islands**, all
twelve controlled runs won inside half the limit, and avoiding detection bought **zero** HP on island 2
(26.0 either way). `boat-invasion` called it *a clock failure, not a coastline failure*.

⇒ **Rule 6 removes the half of the decision that was still there.** And it takes rule 4 with it: the only
reason to open a second front on a flank is to save time, and **time is now free**.

### 5.3 Bodies cost everything — by a factor of 9.3 to 19.2

Let **ρ** = the fraction of enemy HP that comes back as damage to the army. ⚠ **It must be paired island
by island** — an earlier draft of this doc measured all three HP costs against island 3's enemy HP alone,
which is section 13's own warning, applied to the wrong file:

| Island | HP the node cost | that island's enemy HP | ρ |
|---|---|---|---|
| 1 | 27 | 160 | **16.9%** |
| 2 | 41 | 184 | **22.3%** |
| 3 | 77 | 330 | **23.3%** |
| **all three** | 145 | 674 | **21.5%** |

⇒ **ρ = 16.9% to 23.3%**, not the 8.2–23.3% the mispairing produced. **The floor doubles and the
conclusion strengthens.**

> damage taken on a continent node = ρ × (6,372 to 9,558) = **1,077 to 2,227 HP**
> army pool at R = 10 = **116 HP**
> ⇒ **the army dies 9.3 to 19.2 times over before the node is cleared**

Inverted: at pool 116, the enemy HP a node can survive is `116 ÷ ρ` = **498 to 686 HP** — that is
**1.5× to 2.1× island 3**, against the **19–29×** rule 5 demands.

### ⇒ **The gap is a factor of 9.3 to 19.2, and exactly three things can pay it. None is decided.**

| Payer | What it is | What it costs |
|---|---|---|
| **ρ falls** | soldiers take less damage per enemy HP killed — i.e. range and area start mattering | this is rule 10's condition. `what-makes-placement-a-decision` measured that **range and area are the only thing separating TFT from Despot's Game**, so this payer and the 총 전투력 warning are the same problem |
| **R rises** | the roster grows **9.3–19.2×** → **93 to 192 soldiers** | one-seat boats ⇒ **93–192 landing drags a node**, against today's 10–13. And R thickens the map (section 4), so the same 984–1,476 columns hold **1,610–2,410 enemies** at R = 50 — one per 13–20 land tiles |
| **Soldiers recover during a push** | nothing in the tree does this | the only heal is a `CHEST` node's `Reward.HEAL`, which lands **between** nodes. Adding one inside a push is a new mechanic and nobody has asked for it |

⚠ **These are not three options to pick from — this doc is not allowed to pick, and does not.** They are
the complete set of places the factor can go, derived rather than listed. Any plan that sizes a continent
without naming which one is paying has hidden a factor of up to 19.

### 5.4 ⚠⚠ Refutation — section 4 and section 5.3 cannot both feed one plan

**Section 4 sizes the map assuming the node runs 600–900 seconds at 18.0 sustained DPS. Section 5.3 says
the army is dead long before that.** Both cannot be handed to a builder. Working it out:

> enemy HP killed per second = 18.0 × 0.59 = **10.62 HP/s**
> damage taken per second = ρ × 10.62 = **1.80 HP/s** (ρ = 16.9%) to **2.47 HP/s** (ρ = 23.3%)
> pool 116 ÷ that = **the node ends in 47 to 65 seconds**

⇒ **At today's ρ and R = 10, a continent node is over in 47–65 seconds — 1.5× to 2.1× today's 31 s — and
the 10–15 minutes rule 5 asks for is unreachable by exactly the 9.3–19.2× of 5.3**, which is what it has
to be, since both come out of the same ratio.

⇒ **Section 4's table is what the map must be IF one of 5.3's payers pays. It is not what the map should
be built as today.** A plan that takes section 4's 984–1,476 columns without also taking a payer builds a
continent whose fight ends in the first 5% of it.

### 5.5 And this is the real name of hole 6 (permadeath vs careful building)

The open hole was: *a carefully built soldier dying for good makes people stop building carefully.* It now
has a number. **A continent node kills 9.3 to 19.2 full rosters' worth of HP.** At today's ρ, permadeath
at continent scale does not threaten a build — **it deletes the entire army every node.** The hole goes
from "open, untouched" to "open, with a factor attached", and 12.2's version of it is the one that
matters.

---

## 6. ⚠⚠ Dead air — the number this doc exists to compute

Both dead games were measured on it, and **the definition matters more than the value**: dead air is
**the percentage of the run with nothing killable on screen**, the bar was **25%**, game two failed at
**83%**, and after a level-curve rewrite it still failed at **61%**.

Three different clocks get confused here. All three, separately:

| Metric | Definition | Bar | This design |
|---|---|---|---|
| **Dead air** | % of the node with nothing killable on screen | 25%; game two 83% → 61% | **≈1.4%** — see below. **Not the risk** |
| **Longest empty stretch** | game two: *walking 150 seconds to the boss*, listed as a **container fault** | none stated | **a landing 600 tiles from the front is exactly 150 s of walking**. **Reproduced by construction** |
| **Interval between player actions** | never measured in either dead game | **none exists** | **3.1 to 90 s, depending entirely on R** |

**Dead air, computed.** The viewport is 1,280 px = 32 tiles at zoom 1.0, 18 tiles tall. At the
**three-island** density that window holds `32 × 18 × 0.482 ÷ 65.3` = **4.25 enemies**. Treating placement
as Poisson, `P(nothing on screen) = e^-4.25` = **1.4%**. Against a 25% bar.

⚠ An earlier draft used island 3's constants alone and got 0.5%. **The conclusion survives the correction
by a factor of eighteen**, but the label had to stop saying "today's islands" while measuring one of them.

⇒ **At today's density a push does not produce dead air by the measured definition**, as long as the
camera is at the front.

⚠ **That last clause is where it fails.** Two ways:

1. **Behind the front is cleared ground.** Every tile already pushed through is permanently empty, and by
   minute 10 that is most of the continent. Any moment the camera is not at the front is dead air, and
   **rule 4 is an instruction to look away from the front.**
2. **The flank landing IS the 150-second walk.** A soldier landed L tiles from the nearest enemy does
   nothing for `L ÷ 4.0` seconds. On a 984–1,476 tile map, a genuinely flanking landing is 300–700 tiles
   out ⇒ **75 to 175 seconds of one soldier walking through territory it already owns.** Game two's
   150-second walk to the boss is inside that range, and `lessons-from-two-dead-games` files it under
   *things that were the container's fault* — the failure that a round-based structure made **nonexistent
   rather than fixed**. This design puts the container back.

⇒ **Derived constraint: a landing's walk-to-contact must not exceed the interval between decisions**, or
the player is permanently waiting on a move they already made. ⚠ **Pair the ends correctly** — a 126-tile
reach comes from R = 19 on a **600 s** node (984 columns), and 360 tiles from R = 10 on a **900 s** node
(1,476 columns). Both give the same fraction, because both scale with t:

> R = 19 → 31.6 s × 4.0 = 126 tiles of 984 = **12.8%**
> R = 10 → 90 s × 4.0 = 360 tiles of 1,476 = **24.4%**

⇒ **Only 12.8% to 24.4% of the coastline is worth landing on at any moment.** The rest is landable and
worthless. (An earlier draft crossed the ends and reported 9–37%.)

### ⇒ The single most important number

**The interval between the player's two consecutive actions is 3.1 to 90 seconds, and which end it lands
on is set entirely by R.** At R = 10 it is 60–90 s and decays to zero as the roster empties onto the
beach; at the R = 93–192 that 5.3's second payer requires it is 3.1–9.7 s.

**It clears no bar, because this repo has never measured one — and it cannot even be placed on a scale
until R is decided.** ⚠ **There is also no comparable figure to hold it against.** An earlier draft
offered "today the player acts every 2.4–3.1 s"; that number does not exist (section 3). ⇒ **I wanted an
acceptable decision interval and a baseline to compare it with. This repo has neither.**

---

## 7. ⚠⚠ Refutation boxes — what this doc overturns

### 7.1 `plan-then-watch` decided 1 — the hand does not move during combat

> *"전투 중에 손이 움직이는 거, 안 움직일 거 같은데."* — user, 2026-08-18

**Rule 8 overturns it.** The hand moves during combat, on boats and only on boats.

⚠ **And that doc names the price itself.** Its own words: *"Rules 1, 4 and 5 are one block that props
itself up. All three say nothing exists after the commit. Soften any one of them and the other two
collapse."* Rule 8 softens rule 1. ⇒ **By `plan-then-watch`'s own sentence, its decided 4 (a pause you
can do nothing with) and decided 5 (no preview) are now unsupported.** Neither has been re-decided.

⚠ The reason the old decision was taken is also on the record and it does not transfer: it was taken when
**a fight was one minute** (decided 8, below), and the second reason the user gave was *"게임이 Clash
Royale처럼 보일까 걱정"* — recorded in `commit-before-the-fight-not-during`. **That worry is untouched by
rule 8**, because sending units into a live fight from a home edge is precisely the Clash Royale shape.
**Nobody has put that to the user.**

### 7.2 `plan-then-watch` decided 8 — a fight is around a minute

> *"싸움 자체가 일 분은 안 넘어갈 거 같은데. 넘어가도 되는데 배속이 있을 거 같고."*

**Rule 5 replaces it with 10–15 minutes.** And the second half of that sentence is already gone —
the speed ladder and the pause were deleted the same day, so **a 10–15 minute node runs at 1× with no
brake, no skip and no pause**, which is a thing the user has never seen.

### 7.3 `plan-then-watch` decided 20 and `boat-invasion` decided 5 — the whole island fits one screen

> *"조금 더 카메라를 뒤로 빼야 될"* — user, 2026-08-18, quoted as **"The whole island in one frame"**
> and *"Without zoom-out there is no way to survey the island at all"* — `boat-invasion`

**Arithmetically impossible.** Fitting 39,360 px into a 1,280 px viewport needs zoom **0.0325**, which is
**13.8× below `ZOOM_MIN` 0.45**. At that zoom a 40 px tile draws at **1.30 px**, and the smallest body
(the crow, ratio 0.25 → 10.0 px at zoom 1.0) draws at **0.33 px** — against the **8 px body floor**
`look.gd` records as the reason `ZOOM_MIN` sits where it does, which `net_camera` holds. ⚠ **The floor to
cite is that one, not the 2.0 px snap floor** — the snap floor governs line weights and motion amplitudes,
which is a different question. **The conclusion is the same under either, by a factor of 24.**

⇒ **`field_view` cannot ever draw a whole node.** Not "should not" — cannot, on legibility grounds, not
on constants. And decided 2 (*"배치나 이런 게 미리 보이는 거지"*, restated by rule 2) **requires** the
player to survey the layout before committing. ⇒ **A second, non-`field_view` strategic view is required
and nothing decides one exists.**

⚠ **Do not resolve this with 2f.** The user did say *"맵이 굳이 한 맵 한 화면이 안 들어가도 돼요"* — but
**they said it about the node map, not about a combat node**, and `title-and-map` records it there. It is
the exact sentence a continent needs and **it may not be transferred by inference.** If the user extends
it, decided 20 and `boat-invasion` decided 5 both fall cleanly; if they do not, rule 1 is unbuildable.

### 7.4 `boat-invasion` decided 3 — the grid is 48×32

> *"양쪽 다 키워봐"* — the decision that took the grid from 32×18 to 48×32, closing GDD 미정 16

**Void.** Section 4 derives 984–1,476 × 32. ⚠ **The height survives and the width does not** — which is
the opposite of *"grow both sides"*, and it is derived rather than chosen.

### 7.5 The GDD's 미정 4 — the loss condition is a time limit

> *"~~Lose condition~~ — decided: a time limit (user, 2026-08-17). Each island has a clock, and failing to
> wipe them out within it loses."*

**Rule 6 reverses a decided item.** The GDD's own follow-on line survives and is now the whole of it:
*being wiped out is also a loss.* ⇒ **The decided box in the GDD has to be edited, not annotated** — a
refutation written in a different file does not propagate.

### 7.6 `session-loop`'s 「a whole run contains 15 kills」 — and it was already rotted

> *"A whole run contains 15 kills. Counted straight out of `islands.gd`: island 1 = **4** · island 2 =
> **6** · island 3 = **5**."* — kept alive as *"the number of things there are to plan against"*

**Counted again today: 8 · 12 · 14.** A route steps four fights and a chest, so a run is **46–50 kills,
not 15** — already **3× stale before this doc**, because the enemy counts were raised by `plan-then-watch`
and the sentence was never re-measured.

⚠ **And an earlier draft of this box corrected 15 → 46–50 and then computed the continent multiplier
against the 15 it had just killed** ("~70×"). Against the corrected figure: **per node 8 · 12 · 14 becomes
322–482, and per run 46–50 becomes 1,288–1,928** — **23× to 42×**, not 70.

⇒ Its own recommendation — *"the fix is level design, not a rule: 30 to 40 enemies an island"* — is
overshot by an order of magnitude by rule 1. **The doc's paragraph does not survive; the reason it was
written (the grain of the resource is the grain of the decision) does.**

### 7.7 ⚠ And a refutation of this doc's own section 3

Section 3 describes a loop with repeated planning moments. **Section 3's own arithmetic box shows there
are 10–19 of them in the entire node, front-loadable to zero.** Both paragraphs stand. The loop as the
user described it is real; **the supply of moments that make it a loop is not, at R = 10.**

---

## 8. Docs this disproves — **the spawner must go and edit these; I cannot**

A refutation that lands in a different doc than the claim does not propagate. Each row is a claim held
**in that file** that this doc contradicts.

| Doc | The claim, and what breaks it |
|---|---|
| `plan-then-watch` | **decided 1** (the hand does not move during combat) → rule 8. **decided 8** (a fight is about a minute) → rule 5. **decided 20** and its 「The whole island」 screen row → section 7.3. **decided 4 and 5**, which that doc says collapse if 1 is softened |
| `boat-invasion` | **decided 3** (the grid is 48×32) → section 7.4. **decided 5**'s justification (*"without zoom-out there is no way to survey the island at all"*) → section 7.3. Its whole section on the clock's cost is re-based by rule 6 |
| `cell-army-gdd` | **미정 4** — *decided: a time limit* → rule 6 (section 7.5). **미정 16** (48×32) reopens. Its **Plan · execute** row — *"a planning screen showing the whole island and every enemy"* and *"an execution screen where the only things pressable are the speed control and the pause"* — is wrong on all three counts (no whole-island view, no speed control, no pause, and the boat is pressable) |
| `session-loop` | the **15 kills** paragraph → section 7.6, **and it was already 3× stale independently of this doc** |
| `title-and-map` | **the three hand-authored grids.** That doc decided six grids are needed and three would be hand-written, and made *cutting the cost of adding one* a design goal because the user grows the set themselves. At **31,488 characters per node** (section 9) hand-authoring is finished |
| `commit-before-the-fight-not-during` | **Status: valid** — *"섬에 들어가기 전에 계획을 통째로 짜고, 시작을 누르고, 그 뒤로는 아무것도 하지 않는다."* Rule 8 partially reverses it. ⚠ Its rejected branch **실시간 커밋** was rejected for two reasons and **only the first is answered by rule 8**; the Clash Royale worry is untouched |
| `idea-inbox` | **two rows, and it is the file everything else is indexed from.** **Row 42** carries *"⚠⚠ That is 7–15× today"* against `TIME_LIMITS` — section 2 refutes the denominator, and the correct figure is **19–29×**. **Row 45** is still marked **「Not decided」** for 「전투 중간에 참여할 수 있게 할래?」, which the user closed on 2026-08-19 with *"저 배만 좀 참여하는 걸로 해서 기획 한번 해보자"* (rule 8). ⚠ **Nothing is deleted from that file** — both rows get their state updated in place |
| `planning-principles` line 1 | 「손이 놀면 안 된다」. That file already records the current design as bending it hardest, paid for by *a fight is short*. **Rule 5 deletes the payment.** The line's own instruction applies: *if the fight ever feels like dead air, this is the first thing to re-read* |
| `what-makes-placement-a-decision` | header says **Implemented: none — `src/` is empty**. `src/` is not empty; the field, the grid and the battle all ship. A stale header, found in passing |
| `src/sim/islands.gd` | its `TIME_LIMITS` comment block, its 48-character format contract, and the 40 px canvas note |
| `src/sim/rules.gd` | the `MAP_NODES` island-column note promising `[0, 1, 3, 4, 5, -1, 2]` *once the three new grids exist* |
| `src/look.gd` | `GRID_W` 48 / `GRID_H` 32 as constants, and `WATER_MARGIN_TILES` 12, whose stated reason (the map is narrower than the zoomed-out view) is inverted |

---

## 9. What it costs in code — walls found by reading, not walls expected

Sized at the **600-second end** (984 × 32 = **31,488 tiles, 20.5× today**) with **R = 10**. The 900 s end
is 1.5× worse and every R above 10 multiplies again.

### 9.1 ⚠⚠ `field_view._draw()` paints the whole grid every frame, with no culling — **the first wall**

The terrain pass is `for ty in range(-margin, Look.GRID_H + margin)` × the same in x, one `_paint_tile`
each. Today that is `72 × 56` = **4,032 rects per frame**, and it works.

At 984 columns: `1,008 × 56` = **56,448 rects per frame**, 60 times a second = **3.4 million rect + outline
draws per second** — and the camera can see at most **71 × 40 = 2,840** of them. **95% of the work is off
screen.** ⇒ **The presentation is the frame-rate wall, and it arrives before the sim's.**

⚠ **And the view cannot express a variable-size grid at all**: `Look.GRID_W`/`GRID_H` are `const 48`/`32`
and `_draw` iterates them rather than `battle.grid.w`/`h`. **Two nodes of different sizes are
unrepresentable today.**

### 9.2 ⚠⚠ `Grid.load_rows`'s `sendable` table — **the hard wall, and it is a load-time freeze**

For every harbour, for every landable tile, `water_line_clear` walks the line at
`Rules.LINE_SAMPLE_STEP = 0.05` tiles — **20 samples per tile of distance**.

- Today: 3 harbours × ~80 landable tiles × ~20 tiles distance = **~96,000 samples**, once per island
- At 984 × 32, both long shores landable ≈ **1,968 tiles**, mean harbour-to-tile distance ~250 tiles =
  **5,000 samples per line**
  - at today's 3 harbours: 3 × 1,968 × 5,000 = **29.5 million samples** (**307×**)
  - ⚠ **but rule 4 requires harbours along the whole coast.** At one per 20 tiles = **98 harbours**:
    98 × 1,968 × 5,000 = **964 million samples in one call**

⇒ **A multi-second to multi-minute freeze on entering a node**, in `load_rows`, with nothing on screen.
⚠ **The code already knows this shape**: the table was precomputed *because* computing it live at
"1536 tiles × ~500 samples a FRAME" was unaffordable. **The precomputation is unaffordable at continent
scale too.** Memory is fine (98 × 31,488 bytes = **3.1 MB**); the time is the wall.

⚠ **And the rule itself stops meaning anything.** *"The straight line from that harbour does not cross
land"* was designed for a 48-tile island. A straight line from a harbour 900 tiles away is not a boat
route; it is a ruler laid across a continent. **The landing rule has to be re-derived, not re-tuned** —
and rule 9 (denylist, `cliff + inland`) is the user's own answer to half of it and has not been built.

### 9.3 `field_view.setup` builds `_droppable_rects` over every tile × every harbour

`for t in g.passable.size(): if g.home_harbour_for(t) >= 0`, and `home_harbour_for` loops all harbours.
Today **1,536 × 3 = 4,608**. At 98 harbours: **31,488 × 98 = 3.09 million** `can_land_at` + distance
calls, **on top of 9.2**, in the same island-entry frame.

### 9.4 `Grid.flow_field` BFSes the entire map, however near the target is

One BFS = `n × 8` neighbour tests = **252,000** (today: 12,288). `FIELD_TTL` is 0.5 s ⇒ **two rebuilds a
second per distinct target tile**. With soldiers and 322 enemies spread along a front, 20–50 distinct
targets is conservative:

> 50 × 2 × 252,000 = **25.2 million operations per second** (today's comparable: **492,000**) — **51×**

⚠ **And the waste is structural, not incidental**: a soldier fighting an enemy two tiles away still
rebuilds a field over all 31,488 tiles. Memory is fine — 128 KB a field, 6.4 MB for fifty.

### 9.5 ⚠ `_nearest_enemy` has no radius — a flank landing walks to the front immediately

`Rules.NO_DETECT`: *"Soldiers have no detect radius at all — they always advance on the nearest enemy."*
On a 48-tile island that is correct and invisible. **On a 984-tile continent it means a soldier landed on
a flank starts walking toward whatever enemy is nearest anywhere on the map** — which, after the front has
been cleared behind it, may be 700 tiles away. **The flank landing does nothing except produce section
6's 175-second walk.**

⇒ **This is a rule-level defect the continent creates, not a performance one, and it is the cheapest
thing in the whole design to get wrong.** It is also the first thing that has to be decided about what a
landed soldier does: hold the beachhead, or walk. **Nobody has said.**

### 9.6 Targeting is O(R × E) every sub-step, at 60 Hz, with no spatial index

`_phase_targeting` calls `_nearest_enemy` per soldier and `_nearest_soldier` per enemy, each a full scan.

> today: 10 × 14 = 140 pairs, both directions ≈ 280 per sub-step × 60 = **16,800 distance tests/s**
> at 322 enemies: **386,000/s** · at 482: **578,000/s** · ⚠ at R = 50 the enemy count rises with it
> (section 4), so 50 × 2,410 = **14.5 million/s** — **R enters this one quadratically**

There is **no spatial index anywhere in `src/sim/`**. ⚠ The fix is already measured, in
`lessons-from-two-dead-games`: a uniform grid at **300 items 0.42 ms against a naive 3.01 ms**, at
**600 items 1.03 ms against 12.19 ms**. **The measurement exists; the code does not.**

### 9.7 Things that are **not** walls — do not optimise these

- **`battle.gd`'s flat per-body arrays at 322–482 enemies.** `lessons-from-two-dead-games` measured 300
  `Node2D`s at **0.065 ms**. ⇒ **The engine was never the wall.** The flat arrays are a *correctness*
  contract — `_drop_from_boats` on death is structurally true because of them — and they should not be
  restructured for speed.
- **`enemies_left()` full-scanning every sub-step**: 482 × 60 = **28,900 comparisons/s.** Noise.
- **Memory**: `sendable` 3.1 MB + fifty flow fields 6.4 MB + terrain arrays ~0.4 MB. Fine at every scale
  in this doc.

### 9.8 Rule 8 in code: **delete one guard**, and read why it was put there

`Battle.send` opens with `if _committed: return -1`. That single line is the whole of "no boat after the
start button", and `battle.gd`'s header explains it: *"That is a RULE and not a calling habit: without
`_committed` 'planning' would exist only as the shell choosing not to call `step`, and every net, probe
and future caller would break it in silence."* ⇒ **Rule 8 is cheap in code and expensive in contract.**
Open with it: does `recall` stay refused after the commit? Nobody has said.

⚠ Side effect: `plan-then-watch`'s 미정 16 (does a dropped boat depart immediately, or does everything
leave together at the start?) **becomes the same question for post-commit boats — they can only depart
immediately.** It stays open for the pre-commit batch.

### 9.9 Deleting the clock — small in code, and it disarms the probe

Touched: `islands.gd` (`TIME_LIMITS`, `time_limit_of`) · `battle.gd` (`time_limit`, `time_left`,
`Lose.TIMEOUT`, the `_phase_clock` branch) · `run.gd` (the `setup` call) · `hud_view.gd` (`_paint_timer`) ·
`panel_view.gd` (`MSG_LOST_TIMEOUT` and its branch) · nets `net_islands`, `net_run`, `net_battle`,
`net_shell`, `net_plan` · `tools/probe/run_run.gd`.

⇒ **4 source files, 5 nets, 1 probe.**

⚠⚠ **The probe is the casualty, not the code.** It grades every run as a **percentage of the time limit**
— the 49% figure, the *"won inside half the limit"* finding, its whole reporting scale. **With no limit
there is no denominator, and the probe cannot grade a push until a new one is chosen.** This repo's only
instrument for turning 「애매하다」 into a number goes dark on the same commit that deletes the clock.
**Whatever replaces the denominator has to land in the same round.**

⚠ **Retracted from an earlier draft of this section**: *"the timer is the only monotone quantity the HUD
paints"*. **It is not.** `hud_view` paints `"적 %d" % battle.enemies_left()` every frame, and its own
comment records that the counter **survives onto the lose screen on purpose**. Both dead games' lesson —
*if nothing on screen decreases monotonically, there is no way to tell hitting from swinging at air* — is
already answered.

⇒ **The real question is different and harder: does a counter reading 482 still read as progress over ten
minutes?** A number falling from 14 to 0 in 31 seconds is an event. A number falling from 482 to 481 is
not. **Section 11.**

### 9.10 Hand-authored terrain grows **41×**, and `title-and-map` already called that the wrong direction

`ISLAND_ROWS` is strings of exactly 48 characters. At 984 columns: **31,488 characters per node**, written
as **32 source lines of 984 characters each** — undiffable and unreadable. Six nodes (the decided six):
**188,928 characters**, against **4,608** today.

⚠ `title-and-map` decided the three new grids would be **hand-authored, no generator**, and made *cutting
the cost of adding one* an explicit design goal **because the user grows the set themselves**. `rules.gd`
states the same stance for the map: *"Nothing in this section is generated and no seed is read."*

⇒ **At 31,488 characters a node, hand-authoring is over, and a generator is required.** **This is a
blocking open question for the six-node map**, and it is the one place where the design cannot proceed
by decision alone.

---

## 10. Sources — every one with its case against

**Only sources this repo has already checked, with URLs, in `what-makes-placement-a-decision`.** Nothing
here is cited from memory, and nothing new was added.

**Bad North** — the developer lowered the *granularity* of control, he did not remove it: *"We have this
very low granularity of interaction, which means that mostly players will be simply positioning their
squads on a grid and then each of the units in that squad decide how/when to attack from there."*
⇒ **This is the closest verified precedent for rule 8** — one live verb, low granularity, no unit control.
⚠ **Against, twice.** Metacritic 65–74, Destructoid 5.5/10, *"shallow combat"* — **one positional rule on
its own does not produce depth**, and with three unit classes you have seen it all in two hours. ⚠⚠ **And
the second one is sharper**: `what-makes-placement-a-decision` records that no developer statement exists
on why Bad North's islands are small, but that **the reason given for procedural generation was
readability — everything happening in a fight must be visible.** ⇒ **The one game whose control scheme
this design copies deliberately kept its maps small for exactly the reason section 7.3 says a continent
breaks.**

**TFT vs Despot's Game** — the same rule (place, then nearest-target, zero control) and opposite outcomes.
**The only difference is that TFT's abilities respond to distance and area**, and Despot's Game's studio
admitted placement was not a decision by adding an auto-arrange button. ⇒ **Rule 10 lands on the TFT side
if range and area collide, and on the Despot's side if the numbers only add.** That is the same fork as
section 5.3's first payer. ⚠ **Against**: both are single-screen autobattlers with a frozen board, and
neither is evidence about a 984-tile map or a moving front.

**Frozen Synapse** (pre-commit simulation) and **Door Kickers** (return to planning at any time) — ⚠ the
two verified plan-then-execute games **both hand the player what this design refuses**, so neither could
be cited FOR zero control. ⇒ **Rule 8 moves this design one step toward Door Kickers** and makes the
citation half-usable for the first time. ⚠ **Against**: Door Kickers pays for that by letting you go back
to *planning* — pausing and re-issuing everything. Rule 8 gives one verb and no pause at all
(`plan-then-watch` decided 4 is deleted with the speed ladder), so **the precedent covers the direction
and not the amount.**

**Loop Hero** — *"Because you have no direct control over your character, it means that you always want to
play it safe… This reduces not only the number of viable ways to play, but also what cards to take."*
⇒ **No control narrows the options rather than widening them.** ⚠ **Against this design specifically**:
rule 8 gives back exactly one control, and section 3 shows it fires 10–19 times in 10–15 minutes.
**Whether that is enough to escape the Loop Hero result is not answerable from the source.**

**Into the Breach** — full telegraphing works **because the turn is frozen**, and reviewers still called
it *"more puzzle than strategy"*. ⚠ **It does not port to real time.** Rule 2's *"배치나 이런 게 미리
보이는 거지"* is full pre-information in real time — the exact port. ⇒ **The one argument I found FOR
rule 1**: over 600–900 seconds full pre-information decays. What you read at minute 0 is stale by minute
10, so a continent cannot be solved as a frozen puzzle the way a 48×32 island can. ⚠ **And the case
against my own argument**: staleness is not tension, it is forgetting. Loop Hero's finding is that
removing information makes players play *safe*, which narrows the options — **so length may buy the
opposite of what it looks like it buys.** Nobody has measured either.

---

## 11. Presentation — a feature is not done until its presentation is

Not a wish list. **Each row is a rule that changes state with nothing on screen to say it happened**, or a
thing the tree draws today that stops working at 984 columns.

| What the player must see | Why, and what breaks |
|---|---|
| **Where the front is, on a map 31–46 screens wide** | `field_view` cannot draw the node (7.3). **A second, strategic view is required and nothing decides what it is.** Its renderer cannot be `field_view`'s: at 1.30 px a tile, bodies are sub-pixel against `look.gd`'s own 2.0 px snap floor |
| **A monotone quantity that still reads at 482** | ⚠ **`hud_view` already paints one** — `"적 %d" % enemies_left()`, top right, surviving onto the lose screen. **The lesson is satisfied; the scale is not.** 14 → 0 across 31 s is an event; 482 → 481 across ten minutes is not. **Open: what shape does progress take at 20–30× the count?** `army.living_count()` is the other candidate and it is on screen nowhere |
| **How many soldiers are left to send** | The roster is the only limiter (the user's own rule) and the only supply of decisions (section 3). It is the resource bar of the whole node and there is no widget for it |
| **That a landing arrived, when you are looking somewhere else** | `Battle.Event.LAND` exists and `combat-juice` draws it — **and an event off screen draws nothing at all.** Rule 4 is an instruction to be looking somewhere else. **An off-screen event indicator is required and none exists** |
| **Where a boat may not land**, along ~2,000 tiles of coast | Rule 9 makes it a denylist. ⚠ The 0.18-alpha green overlay the user rejected was **per tile**; at 984 columns a per-tile overlay is invisible at any zoom that shows the coast. The mark has to be a coastline, not a tile set |
| **How to move the camera 984 tiles** | Drag-pan and wheel-zoom are what `boat-invasion` decided. Panning 39,360 px by drag, repeatedly, for 10–15 minutes, is not a control scheme. **Open** |
| **That the push is progressing** | 10–15 minutes with 10–19 inputs needs a shape. The node has no midpoint, no marker and no beat today — the clock was the only structure and it is being deleted |

⚠ **`look.gd`'s `WATER_MARGIN_TILES` = 12 inverts.** It exists because the 1,920 px map is *narrower*
than the 2,844 px zoomed-out view. At 39,360 px the map is wider than any view and the margin becomes 24
columns of wasted work in the hottest loop in the tree (9.1).

---

## 12. Open questions

**Section 12.1 and 12.2 are the floor — they were given and none of them may be closed by inference.**
12.3 are ones this doc found.

### 12.1 Things the user said that are NOT decided

| # | What was said | What changes on the answer |
|---|---|---|
| **a** | *"1~5 번까지 내가만든 몬스터를 등록할 수 있잖아? … 1번 누르고 소환할 수 있는 곳에서 꾹 누르면 쭉 소환되는"* | ⚠⚠ **This sets R, and R sets the map size, the enemy count, the decision interval and the drag count — every number in this doc.** ⚠ The user corrected why the old 1~5 keys died: *"정확히는 배 속이 별로여서 뺀 거임"* — loading soldiers INTO a boat by number key was the bad part, **not the slots**. And they proposed *"바다에 소환할 수 있어야할듯"* and **withdrew it the same turn**: *"배라는 개념은 존재하고 일단은 그렇게 해서 보내야 될 거 같은데?"* ⇒ **the boat still carries them** |
| **b** | *"먹을 걸 정하러 간다는 게 조금 어색해 … 나만의 군대를 만드는 느낌이 조금 더 맞을 거 같나요?"* | **Proposes replacing the GDD's one line.** Phrased as a question. The reason is arithmetic — a floor offers two nodes, and 「고르러 간다」 promises a choosing two options do not carry |
| **c** | *"파티 구성하는 축이 지금 사실상 좀 없지?"* | **Open, and the user is right — but blocked twice, not unwritten.** `session-loop` refuted itself: a **linear** object cost makes one extreme strictly dominant (**not a decision**), and even a **convex** cost yields one interior optimum (**a calculation**). ⚠ **The two surviving conditions**: objects must be **axes rather than power**, and **scarce** (total drops per run < slots × family threshold). ⚠⚠ **This doc proposes no third curve and none may be inferred from it** |
| **d** | *"이걸 드래그해서 저기까지 이렇게 끌고 가는 게 그렇게 play가 재밌진 않아"* | ⚠ **The push changes this in two directions at once.** The drag COUNT does not grow with the map — it is bounded by R (10–13 today), so at R = 10 a continent has **the same 10–13 drags**, spread over 19–29× the time. **But 5.3's second payer needs R = 93–192**, which makes it 93–192 drags. ⇒ **12.1a and 12.1d are the same question.** ⚠ And the complaint itself is about **aiming**, not count — a ~10 px source and a 0.18-alpha target, per `plan-then-watch` |
| **e** | What the chest pays | **Open. Both quotes stand**: 미정 on 2026-08-19, against the user's own 2026-08-18 *"아티팩트 녗개중 선택"*. **Neither may be picked by inference.** Untouched by this doc |
| **f** | *"맵이 굳이 한 맵 한 화면이 안 들어가도 돼요. 마우스 움직이면서 볼 수 있어도 되고"* | **Said about the node map.** ⚠ It is the exact sentence a continent needs and **may not be transferred** — section 7.3. **If it extends to a combat node, `plan-then-watch` decided 20 and `boat-invasion` decided 5 fall cleanly. If it does not, rule 1 is unbuildable** |

### 12.2 The six holes put to the user

| Hole | State |
|---|---|
| **보상을 줄 자리가 없다** | ✅ **dissolved by rule 1** — the node map survives, so the attachment point does. ⚠ **A new version is open and section 5.3 makes it load-bearing**: is anything gained DURING a 10–15 minute push, or only at the node's end? **At ρ = 16.9–23.3% the army dies 9.3–19.2× over inside one node**, so "something arrives mid-push" stops being a nicety and becomes one of only three ways the node is finishable |
| **배가 첫 1회만 쓰인다** → 「배가 곁다리」 returns | ✅ **dissolved by rule 4** (flank landings, repeated) — ⚠ **and re-opened by 9.5**: with `NO_DETECT`, a flank-landed soldier walks straight to the front, so a flank landing is currently a front landing with a 75–175 second delay |
| **길이는 선택지를 만들지 않는다** | ⚠ **Open, and this doc strengthens it rather than weakening it.** The decision count is bounded by **R** (section 3); the map length is set by **t** alone, since path B's `0.41 × t × 4.0` contains no R (section 4). **Two genuinely independent knobs, and length is the one that does not make decisions.** Length multiplies watching |
| **다 보이는 배치 + 통제 없음 = 계산** | ⚠ **Weakened by rule 8, not closed.** Section 10 gives the one argument in its favour (pre-information decays over 600–900 s) **and the case against that argument** (staleness is forgetting, and Loop Hero measured that removing information makes players play safe) |
| **시계가 안 문다** | ⇒ **becomes "what is the loss condition".** Section 5: an empty roster is `Lose.WIPED` in code and written into the GDD as a **second** condition standing behind the clock — **never confirmed as the only one in a clockless world**, so it stays a proposal. The arithmetic says it would bind violently. ⚠ **The real question is what makes WAITING cost anything (5.2)**, and nothing in section 1 supplies it. **This doc does not decide it** |
| **영구사망과 정성스러운 빌드가 서로 잡아먹는다** | ⚠⚠ **Open, and now with a factor attached (5.5): a continent node kills 9.3–19.2 rosters' worth of HP.** It does not threaten a build — it deletes the army every node |

### 12.3 What this doc found and cannot answer

1. **What is R?** — 12.1a, restated because it is the free variable of the entire design. **It sets the
   decision interval (3.1 s or 90 s — a factor of 29), the enemy density, the drag count and the targeting
   cost.** It does **not** set the map's length (section 4). Nothing else in this doc is undetermined by
   as much.
1b. **What is the height?** Section 4's path C returns 44.3 for every t and 30.1 on a different choice of
   source islands. **It is an identity, not a derivation, and today's 32 has no argument behind it either.**
2. **What does a landed soldier do?** Hold the beachhead, or walk to the nearest enemy anywhere on the
   continent? `NO_DETECT` answers "walk" today and that makes flank landings pointless (9.5). **This is
   the cheapest thing in the design to get wrong.**
3. **What is the boat routing rule on a continent?** `sendable`'s straight-line-over-water test is a
   48-tile rule and does not survive 9.2, in cost or in meaning.
4. **Is terrain generated?** At 31,488 characters a node it must be, and `title-and-map` and `rules.gd`
   both record the opposite stance. **Blocking for the six-node map** (9.10).
5. **What is the probe's new denominator?** Deleting the clock takes away the scale every measurement this
   repo owns is expressed in (9.9).
6. **Does `recall` survive the commit?** Rule 8 opens `send`; nothing says what happens to undo (9.8).
7. **What does the strategic view look like, and is it a second renderer?** (7.3, section 11.)
8. **Is the Clash Royale worry answered?** The user gave it as an independent reason for the old decision
   and rule 8 does not address it (7.1).

---

## 13. Numbers I wanted and this repo does not have

**Written out because a plan that treats these as known will invent them.**

- **An acceptable interval between player actions, and anything at all to compare one against.** Neither
  dead game measured it. ⚠ **An earlier draft manufactured a baseline** — "today the player acts every
  2.4–3.1 s" — by dividing planning drags by a fight they do not happen during (section 3). **The headline
  number of section 6 clears no bar and has no comparison, because neither exists.**
- **What R is.** Not a missing measurement — a missing decision — but it is why so much of this doc is a
  range instead of a number.
- **A source for the height.** Section 4's path C is an identity in t (44.3 on three islands, 30.1 on
  one), and today's 32 rows come from *"양쪽 다 키워봐"* rather than from anything measured.
- **The split of today's 31 s into crossing / walking / contact.** Section 4's 59% is derived from
  `330 ÷ 18.0 ÷ 31.05`, **assumes nominal DPS with every soldier in reach** (false in detail), and is
  **island 3 alone** — the probe's per-island times for islands 1 and 2 are not written down anywhere.
  Paths A, B and C all inherit it. **One probe run reporting the split would replace it.**
- **ρ measured directly.** 16.9–23.3% is inferred from three per-island HP costs against three per-island
  enemy totals, at different roster states. **The 9.3–19.2 factor in 5.3 is a factor of 2.1 wide because
  of this alone.** ⚠ An earlier draft measured all three costs against island 3's enemy HP and got
  8.2–23.3%, **which is the exact error this section warns about, committed in the same doc.**
- **Whether GDScript survives 25.2 M flow-field operations per second** (9.4). Every performance number
  in section 9 is **arithmetic on operation counts, not a profile.** The engine has surprised this repo
  in the cheap direction before — 300 `Node2D`s at 0.065 ms — so **9.1, 9.2, 9.4 and 9.6 should be
  measured before any of them is designed around.**
- **How many harbours a continent has.** 9.2's worst case (98) is invented from "one per 20 tiles of
  shore". The real number follows from rule 4 and nobody has set it. **`sendable`'s cost is LINEAR in it**
  — the loop is `for hb: for t:`, and an earlier draft of this line said quadratic.
