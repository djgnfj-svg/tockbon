# The boat and the landing — making 「침공」 read

**Implemented**: **all of it (2026-08-18).** Built in six stages; the round is **11 nets / 967 checks**
green. Two independent verify-read passes ran **59 mutations**, and every hole they found was closed and
re-confirmed red by separate sweeps. The plan is `boat-and-landing` — **named, not pathed: it changes
folder with its status and the path dies that day.**
**Accepted**: **the user launched it and looked (2026-08-18). Partial.** Verbatim:
*"참 애매하네. 그래도 그동안 중에서 제일 평범하네."* — *"it's really ambiguous. Still, the most ordinary
of them so far."*
⇒ **"the boat is a side dish" did not come back** — the one sentence this doc exists to answer was said
twice and not a third time. **But "ambiguous" came instead, and that is not acceptance.** verify-look
never ran; the user's own eyes are the stronger instrument, so it is not being run after the fact.

⚠ **Implementation and acceptance are two axes, and these two lines are them.** The verdict is the last
row of 「What success means」 below, not the 967 above it.

**One line**: turn the boat from *a dock button* into **reading an island and choosing where to hit it.**

This doc takes over **미정 15** of the [cell army GDD](cell-army-gdd.md) in full, **closes 미정 16 (grid
size)**, and **replaces both the GDD's 「선착장」 section and 「지형」's "the first slice has no tiers".**
**A refutation box sits in each of those two sections** — both are user decisions reversed by the same user.
The rejected branch is [open coastline over fixed docks](../decisions/open-coastline-over-fixed-docks.md).

---

## Why this doc exists

The user played the first slice: *"배가 그냥 곁다리로 있는 느낌"* (*the boat is just a side dish*) ·
*"보고 어떻게 공략할지 대충 생각해서 배를 보내야 되는데 전혀 그런 느낌이 없어. 그냥 배 보내기, 적과
싸우는 거 구경하기 전부"* (*you should look, work out roughly how to attack, and then send the boat —
none of that is there. It is send the boat, then watch the fight, and that is all*).

**Diagnosis**: with two dock tiles, *where do I land* is **pressing one of two buttons.**
⇒ **There is nothing on the island worth reading before you send.** Nothing to read means no act of
looking, and no act of looking means this is a start button, not an invasion.

⚠ **The user conceded the cost of this direction first**: *"조금 어려워지긴 하는데 게임 디자인이.
근데 그래도 될 거 같아 그 정도는."* (*It does make the design harder. But that much is fine.*)

---

## What changed — **the old value and the built one**

⚠ **This section held a "what runs today" snapshot, and it said of itself that it is deleted the day this
doc is implemented. That day is 2026-08-18.** Only the left column survives — without it there is no
reason to reread this doc at all.

| What | Old | Built |
|---|---|---|
| Grid | 32×18 (576 tiles) | **48×32 (1536 tiles)**, still 40 px tiles |
| Camera | **none.** `CAMERA_ZOOM` 1.0, unread | **drag to pan, wheel to zoom**, `ZOOM_MIN` 0.5625 – `ZOOM_MAX` 1.0. Still no `Camera2D` — `field_view` carries one transform itself |
| Landable | **`D` tiles only, two per island** | **the whole coastline.** 76–82 landable tiles per island, of which 38–47 are sendable from the starting harbour |
| Boat origin | the border water nearest the target | **a harbour.** Three per island, and a boat **relocates** to the nearest harbour that can still see where it unloaded |
| Crossing distance | **2 tiles on all three islands** | **11.0–26.4 tiles on wave 1 · 7.0–14.6 once the fleet has moved up** |
| Crossing time | 3.0 s constant | **distance / speed** |
| Fleet | 2 boats · 5 each · 6 s | **big cap 4 at 3.0 tiles/s · fast cap 2 at 5.0.** `2×5 < 4×3` |
| Boat sprite | a 26×14 px filled rectangle | **a hull sized from capacity** (124 px / 72 px) with **its passengers and their HP visible** |
| Terrain | water · land · hole | **cliffs `^` and ramps `/` arrived** |

> ### ⇒ `rules.gd` set its own trigger condition, and the constant died of it
>
> The comment beside `CROSSING` read: *"…the first thing to change if 「which dock」 turns out not to be a
> decision."* **The user ruled that it is not a decision**, and this doc was that "first thing to change".
> ⇒ **`CROSSING`, `CAP` and `FLEET` are all deleted.** A constant that wrote down its own trigger was
> killed by it.

✅ **The three comments that would go false were all fixed in the build** — `islands.gd`'s 「`D` dock」,
`field_view.gd`'s 「The boat IS the cargo on screen」, and the 「576 tiles」 inside `battle.gd`'s `FIELD_TTL`.

---

## Decided (by the user)

| # | Rule | The user's words |
|---|---|---|
| 1 | **The whole coastline is a landing point.** Anywhere not blocked | *"완전히 막혀있는 데가 아니면 어디든지 보낼 수 있게"* |
| 2 | **Terrain gains elevation — a second level (cliffs).** Cliff coast is what "blocked" means | *"격자로 보니까 살짝 이 층이 있어도 될 거 같아"* |
| 3 | **The grid is 48×32** (up from 32×18) | *"양쪽 다 키워봐"* (*grow both sides*). An open coastline is only worth anything if the shore is long, and *surveying* needs a map bigger than the viewport |
| 4 | **The control is one gesture: drag a boat to the shore.** It carries **which boat** and **where** together | *"드래그 좀 좋긴 하다. 니 추천대로 해도 될 거 같은데?"* |
| 5 | **The camera pans by drag and zooms by wheel** | *"삼 번으로 해줘"* (*go with number three*). 48×32 does not fit one screen, and without zoom-out there is no way to survey the island at all |
| 6 | **The two boats differ in capacity as well as speed — big boat cap 4 / slow, fast boat cap 2 / fast** | *"큰 배가 있고 빠른 배가 있을 듯."* Per-boat speed was settled earlier: *"배마다 속도가 있어서 보낼 때 막 고민하고 그런 것도 좋긴 하다"* |
| 7 | **A cliff is just a wall this round.** No landing, no climbing. **Except that some cliffs have ramps you can climb** | *"일단은 그냥 못 가는 것뿐이야."* · *"램프가 있어서 올라갈 수 있는 절벽도 있는 거고"* |
| 8 | **The boat is drawn bigger and the soldiers aboard are visible** | *"내가 뭐를 보내는지도 보이고, 어디로 보내는지도 보이고"* |
| 9 | **The clock is not touched this round.** A bigger grid lengthens every walk on its own, so `TIME_LIMITS` is re-tuned **after the build, from probe measurements** | told to the user, not objected to |
| 10 | **Redirecting a boat mid-crossing is deferred — a named TODO** | *"중간에 바꿀 수도 있을 거 같은데"* → *"이건 추후에 투두로 남겨두고"* |

### Deferred by name — **parked, not closed**

- **How soldiers are loaded onto a boat.** The 1~5 hotkeys stay for now, and the user marked that temporary:
  *"병사 태우는 게 숫자 키인 게 좀 별로야 근데 일단은 저렇게 하고 나중에 이건 조작감은 나중에 개선해야
  했듯"* ⇒ **a feel item, not a rule item**
- **A unit type that ignores cliffs.** Parked together with decided #7's "a wall and nothing more this round"
- **An enemy keeping watch from a clifftop** (*"저 절벽에서 망본 애가 있을 수도 있어"*).
  ⚠ **So "a cliff-top archer shoots down" is NOT in this round** — it has been removed from the proposals
- **More boats.** The user confirmed it (*"나중에 배를 추가할 수도 있는 거지?"*).
  **The GDD's meta unlock list already carries 「배 한 척 추가」** — not restated here

⚠ **A cliff is an element, not the subject** (the user: *"요소일 뿐이야. 현재는. 추후에는 조금 더 어렵게
만들 수 있어."*). ⇒ **Do not grow the cliff rules this round.**

⚠ **#6 kills both the `CROSSING` constant and the `CAP` constant.** Per-boat speed makes crossing time
`distance / speed`, and **`CAP` stops being one constant and becomes a column of the boat.** The four code
changes are in section 8.

⚠ **What #1 and #2 overturn**: the GDD's 「선착장」 and 「지형」 sections. **Both were user decisions and the
same user reversed both.** The refutation boxes live **inside those two sections** — recorded only here, the
next reader inherits the older quote.

---

## Proposed — **the user has NOT confirmed these**

| Proposal | For | Against |
|---|---|---|
| **Island at the top, sea below.** A long climb from the bottom edge to the shore | **The crossing becomes an event.** ⚠ **And decided #3 (48×32) grew partly to make room for it — it is load-bearing while still unconfirmed** | ⚠ **It came up in conversation and the user did not object. That is not confirmation** |
| **Distance is the cost** — a farther beach is a longer crossing | *Where* and *how soon* become one question. Adds no rule | 48×32 is what first gives it a value — section 3 |
| **Landing is a moment of exposure** — helpless stepping off | A direct cost attached to landing near enemies | ⚠ **Section 1 demoted it** |
| **A narrow beach is a narrow contact line** | Bolts onto the GDD's existing 접촉선 rule | ⚠ **The GDD's fourth review already refuted 접촉선** — section 4 |

---

## The arithmetic — **honestly**

This repo's second game died on **"an advantage with no cost is not a decision"**
([what two dead games left behind](../lessons-from-two-dead-games.md)).
**Opening the whole coastline is exactly that shape.** Hence this section.

### 1. The landing point is **already** a decision — and measured, its value **is half of one**

`battle.gd`'s movement rule is asymmetric:

| | When does it move |
|---|---|
| **Soldiers** | `detect_of` is `NO_DETECT` (−1). **No radius at all — they always advance on the nearest enemy** |
| **Enemies** | `_phase_movement` uses `_nearest_soldier(…, detect_of(type), true)`. **Outside its detect radius it stands** (bison 6 · crow 12 · lion 2) |

⇒ **The landing point already selects which enemies engage, and in what order.** No new rule, in shipped code.
The lion's detect is 2.0, so **landing far away means it never moves at all** — killing the rest first and
taking the lion separately **already works with two docks today.**
⚠ **No island coordinates are quoted here.** The three islands are authored for 32×18 and **will be redrawn
at 48×32**, so those coordinates die with them. **What survives is the structure** — land outside a detect
radius and the garrison engages piecemeal.

**Piecemeal is a real HP saving, and it is paid in walk-clock. How much that costs is this doc's heart.**

> ### ⇒ The bigger grid raises that cost **1.7×** — **and it still does not bind**
>
> With a 2-tile water border the land is **44×28** and its diagonal is **52 tiles ≈ 13.0 s** (at 4 tiles/s).
> At 32×18 the land was 28×13, diagonal **31 tiles ≈ 7.7 s**. ⇒ **every walk grows about 1.7×.**
> A piecemeal detour scales the same way — a 3 s one becomes about 5 s, which is **5.6%** of a 90 s limit.
> ⇒ **The grid alone does not make the clock bind.**

> ### ⚠⚠ **The question this section left open — and what the probe answered (2026-08-18)**
>
> **What it asked**: decided #9 leaves the clock alone, so **"one optimal landing spot exists on every
> island" stays unresolved until the build is done and the probe measures it.** Building it and then
> reading it as "a cost now exists" is not allowed.
> ⚠ **It was also why no new rule (landing exposure, a cost for the line) went in.**
>
> ⇒ **It was measured. The answer is half a decision** — the next section has the numbers.
> **The null result this doc feared did not happen. Something else did: the difference is real and
> nobody pays for it.**

### 1-A. What the probe measured — **half a decision** (2026-08-18)

**One measurement caveat first**: ⚠ **the probe plays a whole run per policy, so islands 2 and 3 start
each policy with a different HP pool** (123/128/131/120 on island 2). **Only island 1 is a clean
comparison in the probe's own output**, and every figure below came from **re-running each island on a
fresh identical roster.** Left unwritten, the next reader takes the raw output at face value.

**The live half — the landing point really does change casualties:**

- **Island 3: 53.0 vs 79.0 damage — a 49% spread.** Island 1: 29.0 vs 21.0
- **Fleet relocation genuinely fires.** Island 1's later launches leave from the western harbour on a
  **28.5-tile crossing — longer than the first one.** "Where you land sets the next crossing" happens
  on screen
- ⇒ **The coastline is not scenery.**

**The dead half — but nothing makes the player pay for it:**

- **All 12 controlled runs won, and the worst finished at 49% of the time limit** (29.10 s of 60 s).
  Island 3's worst was 36% of 90 s. ⇒ **the 4.8–8.0 s a far beach costs buys nothing**
- ⚠ **Avoiding engagement does not convert into HP.** On island 2, landing where 2–3 enemies detect you
  and landing where **none** do produced **identical damage, 26.0**. The quiet beach bought **8.35 s** of
  extra walking and nothing else. **Soldiers have no detect radius and always advance, so dodging
  detection just fights the same fight later.**
  ⇒ **Section 1's structure — the landing point chooses which enemies engage — is real and does not price.**
- ⇒ **"Always land next to a harbour" dominates 3 of 3 islands.** The plan's section 4.6 wrote its own
  re-open condition and **it has fired** — recorded in the rejected-branch doc's 「다시 열 조건」 as well

**And the shape of what a player learns is bad:**

- ⚠ **The casualty difference reverses direction by island** — island 1's far beach is **cheaper**,
  island 3's is **far more expensive.** ⇒ what a player takes away is **per-island trial and error, not a
  readable rule.** In an autobattler that is expensive
- ⚠ **46–72% of every island is time with nothing left to press.** The last command always lands at
  **7.4–12.9 s**. A roster of 10 against a wave capacity of 6 means **two sends empty the reserve and the
  rest is spectating.** ⇒ section 6's *"it works as a limit from the first island"* was right, **and the
  limit stops binding early**
- ⚠ **One plan prediction failed**: the dribble policy was required to cost more on all three islands and
  holds on **2 of 3**. **On island 1 dribbling wins on casualties, damage and time** — hoarding is free

> ### ⇒ So what is true
>
> **"An advantage with no cost is not a decision" is standing here again.** The landing point moves
> casualties by up to 49%, and **because the clock does not bind, those casualties stop nothing** — all
> twelve runs won inside half the limit.
> ⇒ **This is not a failure of the open coastline; it is a failure of the clock.** The next handle is
> `TIME_LIMITS`, not a new rule, and it is below.

> ### The clock — **asked, not answered**
>
> **`TIME_LIMITS` is untouched at 60/60/90.** Decided #9 said not to touch it this round and it was kept.
> **What was measured**: islands 1 and 2 could go **60 → 30** and **only one of the twelve runs** would be
> threatened.
> ⚠ **This is a question, not a decision.** It went to the user and no answer has come back.
> **It must not be read as settled.**

**The three things this doc said could supply a cost — what they look like built:**

1. **Blocked (cliff) coastline** — built. ⚠ **Still level design rather than a rule, re-supplied per
   island.** Island 2's cliff ridge really does pin the fleet to one side
2. **Being shot during the crossing** — already existed, and now **reaches the screen** (the passengers
   are drawn). Section 2
3. **Distance = crossing time** — built. **11.0–26.4 tiles on wave 1, 7.0–14.6 after.** ⚠ **And as above,
   those seconds buy nothing** — distance turned out to be the *unit* of a cost, not the cost

### 2. Fire during the crossing — **an existing rule whose current value is small**

`battle.gd` counts a TRANSIT soldier as `is_hittable`. A crow has range 3 + `REACH_BONUS` 1.5 = **4.5 tiles**,
damage 1.5, period 1.0 s. **Time inside reach = 4.5 tiles / boat speed.**

| | Boat speed | Inside reach | Shots | Damage |
|---|---|---|---|---|
| **Today** (2 tiles · 3 s) | 0.67 tiles/s | the whole route = **3 s** | 3 | **4.5** |
| **A long crossing** (12 tiles · 4 s) | 3 tiles/s | **1.5 s** | 1–2 | **1.5–3.0** |

⚠ **So "a longer crossing means the boat gets shot more" is false — it goes DOWN.** Time under fire is set by
**time spent inside the reach band**, not by distance, and a faster boat shortens it.
⇒ **What an open coastline actually opens is not "which tile" but "which angle".**
⇒ **And this is what separates decided #6's two boats**: the slow big boat sits in the band longer.

> **And one thing nobody has used**: every soldier on a boat shares one coordinate
> (`soldier_pos[sid] = here`). A crow has area 0, so it **hits exactly one of them, ties going to the
> lowest id** ⇒ **fire concentrates on one soldier instead of spreading.** A ranged cell has 8 HP, so
> **six shots kill it mid-crossing** and `_drop_from_boats` removes it.
> ⚠ **On the cap-2 fast boat, one soldier is half the cargo.**
>
> ⚠ **The presentation is only half there.** `field_view.gd` reads the ATTACK tracer's endpoint from
> `soldier_pos[to_id]`, so **the bullet does fly at a TRANSIT soldier**, and the target line is filtered on
> `is_hittable`, so **it is drawn out to the boat**.
> **The real gap is narrower: a TRANSIT soldier's body is not drawn** (the boat is drawn instead) ⇒
> **the flash and knock entries are created and never painted, and there is no HP bar at sea.**
> ⇒ **"The boat arrives whittled down" happens in the rules and never reaches the screen.** Decided #8 is
> where that gets fixed.

### 3. Does distance become a cost — **at 48×32, for the first time**

At 32×18 the crossing was **2 tiles on all three islands.** **With nothing to choose, distance was a
constant.** At 48×32 with island-above / sea-below the sea is **more than 10 tiles deep**, and every coastal
tile gives a different route length.
⇒ **The "12 tiles, `t_c` = 4 s" used by sections 2, 5 and 7 is now geometrically reachable.** It was not before.

⚠ **But this was bought by decided #3, not by a confirmed proposal** — island-above / sea-below is still a
proposal, and **if it is not adopted the spread of route lengths shrinks with it.**

### 4. Landing formation — **not a decision. `_try_unload` picks it**

⚠ **First**: the GDD's 접촉선 section **was already overturned by its own fourth review.** **Do not build on
it.** Its one surviving conclusion: **the only cost that grows with `k` is area attack.**

`_try_unload` fills free tiles via `_free_tiles_from`, **breadth-first and 8-way from the target tile**.
⇒ **The player has no lever on the formation.** What comes out is an **L-shaped clump**, not a plus.

The splash centres on the **lion's primary target** (`_hit_soldiers` uses `soldier_pos[primary]`), not on the
landing tile. **The capacities of 4 and 2 changed the values:**

| Boat | Landing shape | Caught by one lion blow (area 1.5, damage 4.0) | Total |
|---|---|---|---|
| **Big (cap 4)** | L-shaped clump | **4** | **16** |
| **Big (cap 4)** | A line | **2** (at an end) – **3** (in the middle) | **8–12** |
| **Fast (cap 2)** | any shape | **2** | **8** |

⇒ **Shore shape moves the big boat's area damage by 25–50%, and does nothing at all to the fast boat.**
⚠ **At cap 2 the notion of formation disappears** — two tiles are always adjacent.
⚠ **And this is level design, not a player decision** — **the same weakness** flagged against cliffs.
⚠ **The line still has no cost** — it also strikes across a wider front, so **the line purely dominates.**

### 5. Baiting — **an open coastline revives it, and it costs more than it looks**

The GDD's 「유인」 section proves why nearest does not flip with two docks. **It is not restated here** — read
that section.

**An open coastline breaks that proof's premise**, because you can pick the coastal tile beside wherever the
enemy has walked to. And the code makes it **both stronger and costlier**:

- **Stronger**: `_phase_targeting` keeps a held target **only while it is in reach**, otherwise it re-picks
  nearest every frame ⇒ **a new landing flips it immediately**
- **Costlier**: the enemy scan in `_phase_movement` passes `ashore_only = true` ⇒ **an approaching boat pulls
  nobody.** **The flank starts only on the frame soldiers land, so it costs a full `t_c` plus that boat's
  berth for `2·t_c`**

> ### ⇒ **Crossing time is this design's only source of uncertainty**
>
> The GDD says so itself: *"결정이 되려면 불확실성이 필요한데, 이 문서에 불확실성의 원천이 하나도 없다"*
> (*a decision needs uncertainty, and this doc has no source of any*), and fog was rejected for stage one.
> **The `t_c`-second prediction is that source** — at `t_c` = 4 s a bison covers 10 tiles and a crow 24.

### 6. ⚠⚠ **Capacities 4+2 deleted the "roster over 10" threshold — the biggest change in this doc**

**An earlier draft wrote**: the three benefits the boat buys (throughput limit, distance cost, prediction)
**all start once the roster passes 10, and the starting force is exactly 10, so the boat does nothing on the
first island.** The ground for that was **2 boats × cap 5 = 10 = the whole army in one wave.**

**Decided #6 deleted that ground. A wave is now 4 + 2 = 6.**

| | Earlier draft (cap 5·5) | **Now (cap 4·2)** |
|---|---|---|
| One wave | 10 | **6** |
| Waves for a starting roster of 10 | **1 — two clicks and it is done** | **2** |
| Threshold where the three benefits start | roster > 10 | **roster > 6** |
| ⇒ On the first island the boat | **does nothing** | **works as a limit from the start** |

⇒ **Half of "the boat is a side dish" is closed by one constant.** The whole army cannot land at once even on
island 1, so **"who are the first six, and where do they go" is a real question from the first click.**

### 7. The time limit and the crossing — **it now genuinely eats the clock**

Waves are `w = ceil(roster / (cap_big + cap_fast))` = `ceil(roster / 6)`, and **the last wave is one-way**, so
**total crossing clock = `(2w − 1) · t_c`**.

| Island | Roster | Waves `w` | Crossing clock (`t_c` = 4 s) | Limit | Share |
|---|---|---|---|---|---|
| 1 | 10 | **2** | **12 s** | 60 s | **20%** |
| 2 | 13 | **3** | **20 s** | 60 s | **33%** |
| 3 | 13 | **3** | **20 s** | 90 s | **22%** |

**The earlier draft had 6.7% · 20% · 13%.** ⇒ **Cutting capacity is what made the crossing a real load on the
clock.**
⚠ **`t_c` here is the big boat's, which is the conservative reading.** The fast boat can complete **more than
one** round trip while the big boat completes one, so the real wave count is at most this — **the table is an
upper bound.**
⚠ **And decided #9 leaves `TIME_LIMITS` alone this round.** These shares are against **today's** limits, and
**re-measuring after the build is the content of that decision.**

### 8. The two boats — **one inequality, and four places in the code**

Capacity and speed both differ, so the trade only exists when the fast boat **loses on throughput and wins on
latency.** Round-trip throughput is `cap × speed / (2 × distance)`, so:

> **`cap_fast × speed_fast < cap_big × speed_big`**
> With capacities fixed at **2 and 4**, this collapses to one line: **`speed_fast < 2 × speed_big`**

⚠ **At exactly 2× it ties and the decision dies** — 4×3 = 12 = 2×6. **"The fast boat is twice as fast" cannot
be used.** ⇒ **The build plan picks the speeds; this inequality is the acceptance condition.** Example: big
3 tiles/s, fast 5 tiles/s (12 > 10 ✓).

**And the code has no notion of "per boat" at all. Four things change:**

| What | Today | Why it blocks |
|---|---|---|
| **Boat identity** | `boats` is a list of **anonymous Dictionaries**, created on launch and gone after unload | **Which boat this is does not survive a launch.** There is nowhere to hang "this one is the fast boat" |
| **Capacity and speed columns** | `Rules.CAP` is **one constant for the whole fleet** | Capacities of 4 and 2 require a boat to be a **row** |
| **Crossing time** | `_phase_boats` interpolates on `t / Rules.CROSSING` | It reads neither distance nor speed ⇒ must become `distance / speed` |
| **Berth release** | `launch()` hardcodes `2.0 * Rules.CROSSING`, and `berth_free_in` is **per berth, not per boat** | Different speeds must free at different times ⇒ `2 × distance / speed` |

---

## The screen

### Grid and camera — **decided #3 and #5**

| | |
|---|---|
| Grid | **48×32.** At 40 px that is **1920×1280 px** |
| Viewport | 1280×720 ⇒ **at zoom 1.0 you see 37.5% of the map** (66.7% wide × 56.3% tall) |
| To see all of it | **zoom 0.5625**, which puts a tile at **22.5 px** |
| Control | **drag to pan, wheel to zoom** |

⇒ **Without zoom-out there is no way to survey the island at all.** That is the point of this session, so
**the camera is part of the rules, not decoration.**
⚠ **Tile count goes from 576 to 1536, 2.67×.** One `flow_field` BFS costs the same factor more, and the
**"576 tiles" figure in `battle.gd`'s `FIELD_TTL` comment — plus the 23k-operations-a-second estimate built
on it — dies with it.**

### Layout — island above, sea below **(proposed, unconfirmed, and load-bearing)**

| | |
|---|---|
| Island | **Upper** part of the screen |
| Sea | Everything below. **The boat starts at the bottom edge and climbs to the shore** |
| Harbour | Bottom of the screen. A berth reads empty while its boat is out (today's rule, unchanged) |

⚠ **Decided #3 (48×32) grew partly to make room for this layout.** ⇒ **An unconfirmed proposal is acting as
grounds for a confirmed decision.** The user has **never** confirmed it in words.
⇒ **If it is not adopted, the spread in section 3 (distance as a cost) shrinks with it.**

### Camera — **the source already wrote down the cost**

From `_click_dock` in `game.gd`: *"The event position needs no zoom conversion because there is no camera…
Add one and this line is wrong everywhere on screen at once."*

⇒ **Adding a camera breaks everything that uses screen coordinates at once** — the landing drag, the panel's
soldier list, HUD rectangles. And `field_view.position` **is the screen-shake offset**, which the click
already subtracts, so **the camera is a second offset on the same axis.** ⇒ **Compose the two in one place or
the same bug ships twice.**
⚠ **Zoom then stacks a scale factor on top of those two offsets** — and the drag control (decided #4) runs
through that transform.

### The boat — what it shows

| What | Today | What it must become |
|---|---|---|
| Size | **26×14 px** (0.04% of the screen) | Much larger — bigger than a tile. **The big boat and the fast boat must be distinguishable by eye** |
| Soldiers aboard | **Their bodies are not drawn.** The boat is drawn instead | **Each soldier aboard is visible, HP included** (decided #8) |
| Destination | Nothing | **Where it is going is visible for the whole crossing** (decided #8) |
| During the drag | Nothing | **Landable vs blocked must show while you are dragging** — undecided 1 |

---

## Undecided — **1 through 12 are closed (2026-08-18)**

⚠ **Items 1–12 were answered by the plan `boat-and-landing` and built as answered.** Each answer is one
row of that doc's section 0, so **it is not restated here** — the same fact in two places diverges. In
brief: landable is **land orthogonally touching water** (3), `D` is **deleted** (4), the speeds are
**3.0 / 5.0** (5), the berth is **deleted rather than indexed** (6), crossing time is **distance / speed**
(7), a cliff is **the legend character `^` with no elevation axis** (9), and a ramp is **`/`, a doorway
this round and not a climb** (10).

**The list below is kept as the record of what was open at the time. Only 13 and 14 still are.**

**Input and screen**
1. **How the screen says a stretch of coast is blocked.** With drag as the control (decided #4) there is now
   a chance to say it **during** the drag. **Dropping and having nothing happen is the same failure as
   today's docks**
2. **The details of the drag.** What do you grab (the harbour's boat icon?), is the drop a tile or a point,
   how do you cancel
3. ⚠ **What counts as a landable tile.** Land adjacent to water? Water adjacent to land? **Does diagonal
   adjacency count** (`Grid.NEIGHBOURS` is 8-way)?
4. **What the `D` tiles become.** Deleted, or kept as tiles with a landing bonus

**Numbers**
5. **The two boats' speed values.** Capacities are fixed at 4 and 2. **The acceptance condition is
   `speed_fast < 2 × speed_big`** (section 8)
6. **What state carries boat identity and per-boat berth timing** — a **data-shape** question, not a value
   (the table in section 8)
7. **Whether crossing time scales with distance** — forced by decided #6, never stated by the user
8. **How the three islands are redrawn at 48×32.** The current three are 32×18-only and **every coordinate
   in them dies**

**Terrain**
9. ⚠ **How cliff coast is stored** — a legend character, a second layer, or an elevation int.
   **`grid.passable` is one byte in which water and hole already both read 0** ⇒ a third kind cannot ride
   on top of it
10. **What a ramp is in the data** (decided #7 put ramps in this round). A tile kind, or a link between two
    levels

**Rules**
11. **Whether "the whole boat waits if there aren't enough free tiles" survives an open coastline.**
    `_try_unload` does that today. ⚠ **Target a 2-tile spit and the boat never unloads, and the island stalls
    to a timeout with nothing on screen explaining it.** ⚠ **Capacities of 4 and 2 make this asymmetric** —
    on the same spit the fast boat unloads and the big one cannot
12. **Whether enemy movement starts seeing boats.** `ashore_only = true` exists for a reason — chasing a
    water tile makes `flow_field` come back unreachable everywhere and **every enemy on the island freezes
    with nothing logged**
13. **Whether landing exposure exists** (proposed). ⚠ **Still open.** Section 1 demoted it behind the clock
    measurement, and **that measurement is now done** — 1-A. **The answer it points at is the clock, not a
    new rule, so this stays low**
14. **A cost for landing in a line** (section 4). ⚠ **Still open, and the player still cannot choose it** —
    `_try_unload` picks the formation, so it remains a **level-design** item

**15. ⚠ Newly opened — `TIME_LIMITS`.** 1-A measured it: all twelve runs won inside **half** the limit, and
islands 1 and 2 could go **60 → 30** with only one run threatened. **It was put to the user and no answer has
come back.** ⚠ **This is the exact place decided #9 pointed at when it said the clock would be re-tuned from
probe measurements after the build. The measurement is done; the decision is not.**

---

## What success means

**In the user's terms**: 「침공」 — invading — reads, and the boat stops being a side dish.

| What | How you know | 2026-08-18 |
|---|---|---|
| **You look at the island before you send** | Time to the first launch is **not zero** | **unmeasured** — a probe cannot time a person looking. Only verify-look and the user answer this |
| **The whole army cannot go at once** | A roster of 10 goes out in **two waves** (sections 6 and 7) | ✅ **true, and it finishes too soon.** The last command lands at 7.4–12.9 s and 46–72% of the island is empty time — 1-A |
| **The same island can be attacked two different ways** | Two runs with different landing points give **different casualties and durations** | ✅ **true.** 53.0 vs 79.0 damage on island 3, a 49% spread — **but the difference changes no outcome** |
| **There is something to read on screen** | Cliffs, ramps and enemies visible before you send; zooming out takes in the island | **seen, and the opposite was not said** — the user complained about nothing on screen. The word was "ambiguous", not "I can't see it" |
| **The crossing is an event** | Something to watch while the boat crosses — passengers, HP, destination, incoming fire | **seen, and it did not read as an event** — the same place as 1-A's "the clock does not bind" |
| **The two boats are genuinely different** | `cap_fast × speed_fast < cap_big × speed_big` (section 8) | ✅ **2 × 5 = 10 < 4 × 3 = 12**, a 20% margin, with both sides written out as literals in the net |
| ⚠ **The real verdict** | **The user does not say "the boat is a side dish" again.** Everything above is a proxy | ✅ **That sentence did not come back.** What came instead: *"참 애매하네. 그래도 그동안 중에서 제일 평범하네."* ⇒ **this doc hit what it aimed at, and the game still has not landed** |

⚠ **This doc cannot judge whether it is fun** — [planning principles](../planning-principles-ko.md), line two.
⚠⚠ **And re-read 1-A.** "An open coastline has a cost" is no longer *unproven* — it is **measured as half
true**: the landing point moves casualties by up to 49%, and **the clock does not bind, so those casualties
stop nothing.** Reading 967 green checks as "so it works" is the failure this repo has lived through twice.
