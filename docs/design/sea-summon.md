# Summon on the sea — press the water, a cell appears there on a boat, and it sails itself ashore

**Implemented**: none. **Not one line of code.** Every number below is either read out of the shipped tree
or computed by this document from the shipped island rows; nothing here has been run in the engine.
**Accepted**: nothing chosen. The user decided the gesture (quoted in section 1) and **no arithmetic in
this document has been put to them.** Two of its findings contradict things they said the same day, and
both halves are kept.

**One line**

> **You arm one of five slots, press a place on the sea, and hold: cells come out there on boats, one
> after another, and each sails to the nearest shore it can land on.**

---

## 0. Why this document exists — **the user said it three times and nobody designed it**

***"이걸 또 말하고 또 말하고 또 말하고 말이 되니 이게? 다시 깊게 기획해."***

The record is in `idea-inbox`, rows 29 · 30 · 56. Each time it was filed as 미정 and answered with more
questions. **This document answers instead.**

### ⚠⚠ It is not three times. It is four, and the first one is a day older than the other three

`plan-then-watch` carries the user's own sentence from **2026-08-18**, at the very top of the document,
inside the section named 「infinite is free」:

> ***"배는 너무 곁다리 느낌이다 그냥 바다위에 초록색 지역에 내가 설계한 몬스터들을 무한으로 배를 띄워서
> 보낼 수 있는걸로하고 싶어"***

**「바다위에 초록색 지역」 — a green region on the sea.** That sentence has been sitting at the head of the
part-loop design for a day, and it was read for its second half (boats are unlimited) while its first half
— *where the player's hand goes* — was never built. **The drag against a coast tile was built instead.**

⇒ **This is the standing instance of 「내가 말한대로 개발을 안하네」 for the part loop**, the same shape as
`boat-invasion`'s decided #1 shipping inverted (`idea-inbox` row 27). ⚠ **The failure is not that nobody
wrote it down. It was written down, in the right document, in bold, and read for the wrong half.**

### `slot-summon` is superseded by this document

A plan named `slot-summon` was written on 2026-08-19 and is sitting in `1.ready`. **It is wrong on
its central gesture**: it presses a **landable coast tile** and treats 「바다에 소환」 as withdrawn.
**It is not withdrawn** — see section 1. Everything in it downstream of *where the press lands* (the
`echo` guard, the cadence derivation, the four clears, the headless-click trap, the leaf table) is sound
and is re-used here by name. **Nothing in this document authorises building that plan as written.**

---

## 1. What the user decided, in their own words

| # | Rule | The user's words |
|---|---|---|
| 1 | **Five slots hold cells you made, and a number key picks one** | *"1~5 번까지 내가만든 몬스터를 등록할 수 있잖아?"* · *"이 삼 사 오에 내가 만든 세포 끼워 놓고 일 번 누르고"* |
| 2 | ⚠⚠ **The press target is the SEA** — a place on the water you are allowed to summon at | *"바다에 소환할 수 있어야할듯 ㅇㅇ"* · *"바다에 내가 소환할 수 있는 곳을 누르면 그쪽에 소환된다"* |
| 3 | **There is a region, and it is drawn** | *"그냥 바다위에 초록색 지역에 … 배를 띄워서 보낼 수 있는걸로"* (2026-08-18) |
| 4 | **Hold and they keep coming** | *"꾹 누르면 쭉 소환되는 형식으로"* |
| 5 | **The boat is not replaced. It still carries them** | *"배라는 개념은 존재하고 일단은 그렇게 해서 보내야 될 거 같은데?"* |
| 6 | **The 1~5 keys were dropped for the BOAT-LOADING, not for being keys** | *"정확히는 배 속이 별로여서 뺀거임 1~5번키"* |

### ⚠ Rules 2 and 5 are both true and the docs resolved them by dropping one

`idea-inbox` row 33 reads rule 5 as **withdrawing** rule 2, and `slot-summon` built on that reading.
Row 56 corrects it: **the unit appears at sea, aboard a boat, and sails in from there.** Nothing about
`boat-invasion` reopens — the boat is still the vehicle. **What moves is where the boat is born.**

⇒ **The structural sentence of this whole design:**

> **Today the press picks the DESTINATION and the sim derives the ORIGIN** (`grid.home_harbour_for`).
> **Sea summon picks the ORIGIN and the sim derives the DESTINATION.**

⚠ **And that inversion is what the user already described from the other side.** `idea-inbox` row 55:
*"처음에 바다에있는 내 병사들은 뭐여 … 가까운곳으로 자동이동이였잖아"*. The row records that
「가까운 곳으로 자동이동」 **appears nowhere in this repo** and files it as new. **It is not new — it is
rule 2 with the derivation spelled out**: a body placed on the water goes to the nearest place it can
land, by itself. **Row 55 and row 56 are one design, recorded one turn apart as two unexplained remarks.**

---

## 2. What a slot holds — and the smallest honest version

**The user says 「내가 만든 세포」. The 세포/오브젝트 economy does not exist in code.** `Rules.UNITS` holds
five rows, of which **two are the player's** (`CELL_MELEE`, `CELL_RANGED`); the other three are the enemy
types. `Army` is a flat roster with no template, no currency and no construction step.

| | What a slot holds | Where the bodies come from | Does the hold change the AMOUNT? |
|---|---|---|---|
| **(a) Today's honest version** | **a soldier TYPE** — slot 1 = melee, slot 2 = ranged, 3–5 unbound | the existing roster, filtered to `SoldierState.RESERVE` | **No.** The hold changes only the SPEED of placing |
| **(b) What the user is describing** | **a cell you designed** — a template with objects bolted on | created on the spot, paid for out of 세포 | **Yes**, and that is the whole problem |

⇒ **Build (a). Say out loud that it is (a).**

⚠ **(b) is not merely unbuilt — it is blocked twice, and this document must not step over the block.**
`session-loop` derived the economy and **refuted itself twice on the way**:

1. **A linear cost makes one extreme strictly dominant.** With `c(k) = c₀ + k·Δc` and `p(k) = p₀ + k·Δp`,
   the sign of `d(p/c)/dk` is `sign(Δp·c₀ − Δc·p₀)` — so either `k = max` or `k = 0` always wins.
   **Indifference is a coin flip, not a decision.**
2. **A convex cost yields a single interior optimum, which is a calculation and not a decision.** With
   `c(k) = c₀ + Δc·k(k+1)/2` the table peaks at `k = 2` (power/cost 0.429) — **and it peaks there at every
   refit, forever.**

**What that document left standing is narrow**: objects must be **axes rather than power**, and they must
stay **scarce** (total drops per run < slots × family threshold). ⚠ **Do not invent a third curve here.**
⚠ **And it found the defect (b) reproduces exactly**: with one shared wallet and no per-slot limit, **the
five slots collapse into one** — you press whichever slot has the best power/cost, forever. **The thing
that stops that today is the roster itself**: slot 1 can be pressed six times and slot 2 four times,
because that is what the army contains. **The roster IS the per-slot quota**, and (b) deletes it.

⇒ **Under (a) the five slots are five quotas.** That is not a placeholder for the economy; it is the one
property the economy has already been measured to lose.

### What a slot must eventually hold

Whatever `idea-inbox` row 38 settles — *"파티 구성하는 축이 지금 사실상 좀 없지?"* — **is what a slot
holds.** It is the same open question, and this gesture does not answer it and must not be read as
answering it. **Slots 3–5 stay unbound and are drawn empty**, which is exactly true and is the only thing
that keeps 「다섯 개가 있다」 visible without lying about what is in them.

⚠ **Slots 3–5 are NOT filled with `BISON` / `CROW` / `LION`.** `TYPE_LABELS` has five entries and nothing
range-checks it — `session-loop`'s buildability review measured a previous attempt coming out as *"bison,
crow and lion with correct names and correct bodies"*.

---

## 3. ⚠⚠ Where you may press — this is the whole design

**「바다의 소환할 수 있는 곳」. What makes a sea tile summonable?**

### 3.1 First: work the inversion the landing rule already uses

`speed-off-open-landing` shipped landing as a **denylist** on the user's own sentence
(*"상륙 못하는 데가 있는 거지 상륙 가능한 데가 있는 게 아니야"*). The obvious move is to do the same on
the water: **press anywhere on the sea except where you cannot.**

**Measured, on the three shipped island rows** (this document parsed `islands.gd` and re-implemented the
shipped 8-way water rules in Python; it did not run the engine):

| Island | water tiles | water a boat cannot reach from land | **the denyset** |
|---|---|---|---|
| 0 | 724 | 0 | **empty** |
| 1 | 690 | 0 | **empty** |
| 2 | 726 | 0 | **empty** |

⇒ ⚠⚠ **A sea denylist has an empty denyset on every island that exists.** It draws nothing, refuses
nothing, and explains nothing. **「소환할 수 있는 곳」 would have no picture at all**, because there would
be no *place* — there would only be "the sea".

⚠ **And it collides head-on with a decision the user made two hours earlier.** They deleted the green
landable wash and said ***"못내림만 표시하면 됨 ㅇㅇ"*** — mark only what is refused. **Under a sea
denylist there is nothing refused to mark.** Under rule 3 there is a **초록색 지역** to draw. **Those two
sentences point opposite ways and both are the user's.**

⇒ **The resolution, and it is not a fudge**: the two rules answer different questions.
**The land rule answers 「어디에 상륙하나」** and the user wants it unrestricted — denylist, and it stays.
**The sea rule answers 「어디에 손을 대나」** and the user described it as a *place* — **an allowlist, a
region, drawn.** ⚠ **This is the one place this design deliberately does not copy the denylist**, and the
reason is written here so nobody "fixes" it into consistency and deletes the region.

### 3.2 The candidates, each with its measurement

**Rule A — the whole sea.** Refused nowhere.
**Rule B — a band along the shore**: water within `d` tiles of a landable coast tile.
**Rule C — a band around the harbours**: water within `d` water-hops of an `H` tile.

Each is measured against the same question: **how much of the coastline can you still reach**, given that
a summoned boat sails to the nearest landing it can reach from where it was born.

| Rule | sea tiles you may press (i0 / i1 / i2) | share of the sea | **landings still reachable** |
|---|---|---|---|
| A — the whole sea | 724 / 690 / 726 | 100% | **82 / 75 / 80 of 84 / 76 / 82 = 98–99%** |
| B, `d ≤ 1` | 90 / 82 / 88 | 12% | **82 / 75 / 80 = 98–99%** |
| B, `d ≤ 2` | 190 / 174 / 186 | 25–26% | **82 / 75 / 80 = 98–99%** |
| B, `d ≤ 3` | 254 / 230 / 248 | 33–35% | **82 / 75 / 80 = 98–99%** |
| C, `≤ 3 hops` | 119 / 119 / 119 | 16–17% | ⚠ **25 / 24 / 20 = 24–32%** |
| C, `≤ 5 hops` | 264 / 253 / 264 | 34–38% | ⚠ **35 / 32 / 28 = 34–46%** |
| C, `≤ 8 hops` | 487 / 468 / 500 | 67–69% | ⚠ **42 / 40 / 42 = 50–53%** |

#### ⚠⚠ SHIPPED, THEN INVERTED BY THE USER — **rule B is a MINIMUM distance now, not a maximum**

The build shipped rule B at `d ≤ 2` and the user played it. **The gesture was accepted** —
*"동작방식은 맞음"* — and the region was not:

> ***"해안선에 배를 배치하는게 아니라 좀 거리를 둬야함 지형하고 많이 줘도됨 배가 가는게 중요하니까"***

⇒ **`SUMMON_BAND_TILES` (a maximum) became `SUMMON_BAND_MIN_TILES` (a minimum), and there is no maximum
at all.** The reason is a design reason and not a preference: **the crossing is the thing worth watching,
and a band hugging the shore deletes it.** The sweep, measured on all three islands — band tiles ·
distinct reachable landings · crossing min/median/max at `BOAT_SPEED` 4.0:

| Rule | sea tiles (i0 / i1 / i2) | **landings reachable** | crossing min / med / max | spread |
|---|---|---|---|---|
| B `≤ 2` (shipped, replaced) | 190 / 174 / 186 | **82 / 75 / 80** | 0.25 / 0.60 / 0.71 | 0.46 s |
| B `≥ 3` | 534 / 516 / 540 | 45 / 40 / 43 | 0.85 / 2.47 / 5.96 | **5.11 s** |
| B `≥ 4` (adopted, then replaced) | 470 / 460 / 478 | 42 / 38 / 40 | 1.10 / 2.47 / 5.96 | **4.86 s** |
| **B `≥ 6` — adopted** | **360 / 360 / 366** | **34 / 35 / 34** | **1.60 / 2.83 / 5.96** | **4.36 s** |
| B `≥ 8` | 256 / 256 / 256 | 32 / 33 / 27 | 2.10 / 3.18 / 5.96 | 3.86 s |
| B `≥ 10` | 152 / 152 / 152 | 30 / 31 / 25 | 2.60 / 3.54 / 5.96 | 3.36 s |
| ⚠⚠ B `≥ 12` | **48 / 48 / 48** | **2 / 2 / 2** | 3.21 / 4.59 / 5.96 | 2.76 s |

⚠⚠ **THE CEILING IS 10 AND IT IS A CLIFF, not taste.** At `≥ 12` the band resolves to **two distinct
landings on every island** and on the 144-column map — the corners of the sea, and nothing else. Every
press anywhere would produce one of two beaches. 10 is the last usable value; 8 the last comfortable one.

⚠ **4 was adopted, played, and replaced by 6 on the user's own sentence** — *"그냥 섬 이랑 더 거리를
더줘"*. The price, stated rather than argued down: **6–8 more coast tiles stop being individually
addressable** (42/38/40 → 34/35/34 of 84/76/82), the minimum crossing rises 1.10 → 1.60 s, and the
spread NARROWS 4.86 → 4.36 s. The long map at 6: **1128 band tiles · 138 of 174 landings ·
1.60 / 3.18 / 17.96 s**.

⚠⚠ **The MAXIMUM crossing is 5.96 s at every value, because the water is finite.** So distance lifts the
FLOOR and shrinks the SPREAD — the spread peaks at `≥ 3` and decays from there. **4 is one step past the
peak**, bought for a guaranteed 1.10 s minimum so that no summon is ever instant. The trade is three
landings and 0.25 s of spread for a visible crossing on every press.

⚠ **The band is now BIGGER, not smaller** — 470 against 190 — because a minimum with no maximum is most
of the sea. 「많이 줘도됨」 is the whole of that.

**The long map (144 × 32)**: 1424 band tiles · **140 of 174 landings** · crossing **1.10 / 2.83 / 17.96 s**.
⚠ **The catchment barely collapses there**, because the coast is one long straight line rather than a
ring, so far-out sea drains to many different nearest landings instead of to four corners.

⇒ **Rule C is refused, and by a number rather than by taste.** Anchoring the region to the harbours throws
away **half to three quarters of the coastline** — which is the exact defect the user already threw out
once: *"39% · 42% · 40% of each island's own coastline"* refused by the old harbour line-of-sight test,
and their words on it were 「상륙 못하는 데가 있는 거지」. **C is that rule coming back wearing a different
coat.** ⚠ And it would restore harbour-adjacency dominance, which the probe already measured as
*"land next to a harbour dominates 3 of 3"*.

⇒ **Rule B is the recommendation, and `d` is the one number this document leaves for the user** — see
Open 3. **A and B are indistinguishable in what they let you DO** (98–99% either way). **They differ only
in whether there is something to draw**, and rule 3 says the user wants something drawn.

### 3.3 ⚠ The refutation of the paragraph I wanted to write

The natural claim — *"pressing the sea is easier to aim at than a 40 px coast tile"* — **is false, and the
measurement kills it.**

A press only means something if it produces the landing you wanted. So the real target is not the band; it
is **the catchment**: the set of sea tiles that map to one particular landing.

| Where you press | median catchment | biggest catchment |
|---|---|---|
| band `d ≤ 1` | **1 tile** | 3 |
| band `d ≤ 2` | **2 tiles** | 10 |
| band `d ≤ 3` | **3 tiles** | 15 |
| the open ocean (rule A, far from shore) | — | **55 · 87 · 98 · 118 tiles**, four corner landings |

⇒ **Near the shore the press is exactly as precise as the drop it replaces** — one tile is 40 px at zoom
1.0 and **18 px at `ZOOM_MIN`, which is where an island opens.** Widening `d` buys precision at 2–3 tiles
of catchment, but only by moving the press away from the thing it is aiming at.
⇒ ⚠ **Out in the open ocean the press is enormous and worthless**: 55–118 sea tiles all resolve to the
same four corner landings. **The sea press is imprecise exactly where it is useless and precise exactly
where it is hard.**

⇒ **So the gesture does not fix aiming. What it fixes is the NUMBER of aims** — see section 6. **Both
halves are kept because the first one is the one a builder would otherwise assume.**

#### ⚠⚠ REFUTED BY THE USER'S DECISION — **the measurement was right and it is overridden**

**Nothing above is withdrawn. The verdict on it is.** *"The sea press is imprecise exactly where it is
useless and precise exactly where it is hard"* assumed the point of the gesture was AIM. The user's
reason for moving the band out is a different axis entirely — *"배가 가는게 중요하니까"*, the crossing is
the thing worth watching — so **precision at the shore was never the thing being bought.**

**What it costs, measured at the adopted `≥ 4` rather than argued about:**

| | median catchment | four biggest | landings reachable |
|---|---|---|---|
| `≤ 2` (replaced) | **2 tiles** | 8 / 8 / 10 / 10 | 82 / 75 / 80 |
| `≥ 4` (adopted, then replaced) | 8 tiles | 40 / 40 / 72 / 84 | 42 / 38 / 40 |
| **`≥ 6` (adopted)** | **6 tiles** | **36 / 36 / 54 / 69** | **34 / 35 / 34** |

⇒ **§3.3's shape was exactly right** — the four biggest catchments really are the corner landings, and
they really do swallow 40–84 tiles each. ⚠ **But "the same four corner landings" overstates it**: the
MEDIAN catchment is 6 tiles and **34 of 84 coast tiles stay individually addressable on island 1**. The
collapse is a 60% loss, not a collapse to four. **That is the price**, and it is written here as a number
so a later round prices it rather than re-deriving the argument.

### 3.4 What the derived landing actually is

**The nearest landable coast tile, by water route, from the tile you pressed.** Ties to the lowest tile
index, the same tie-break `_entry_water_tile` and `home_harbour_for` already use, so two runs from
identical state cannot diverge.

**Measured: over every water tile on every island, that rule reaches 82 / 75 / 80 distinct landings out of
84 / 76 / 82 sendable ones — 98%, 99%, 98%.** ⇒ **The derivation costs you two landing tiles out of
eighty.** Whatever else is wrong with this gesture, **it is not that it takes your choices away.**

---

## 4. The press, frame by frame

| Moment | What happens |
|---|---|
| **A number key** | that slot arms. The same key again disarms it. An unbound or empty slot refuses and its box shakes |
| **The cursor over the sea, slot armed** | a **ring under the cursor** at the derived landing, and the **water route** from the cursor to it — the same two marks a drag draws today, read off the same call the press will use, so the screen cannot promise a landing the sim refuses |
| **Press** | **one body leaves immediately, on the frame of the press.** A boat is created at the pressed tile with that soldier aboard, path = the water route from there to the derived landing |
| **Hold** | one more body every `SLOT_HOLD_SEC`, from the tile **currently** under the cursor — so sweeping spreads the landing and standing still stacks it |
| **The slot runs dry** | the stream keeps marking a refusal at the cadence and **does not end the hold**. 「더 없다」 is a picture, not a silence |
| **Release** | the stream stops. Nothing is committed; every boat is still at `t == 0` |
| **시작** | every boat departs on the same frame, as today |
| **Landfall** | the boat unloads and reverses its own path back to **the tile it was summoned at**, then vanishes — `_phase_landings` already does exactly this and needs no change |

⚠ **A body summoned at sea is drawn standing on the water, and that is now on purpose.** It is `TRANSIT`
inside a hull, at `path[0]`. Today RESERVE bodies are *also* drawn on water, by accident — the harbour is
a water tile — and the user asked what they were (`idea-inbox` row 55). **After this change the only
bodies on the sea are ones you put there.**

### The cadence

`SLOT_HOLD_SEC = 0.20 s`, derived by `slot-summon` and re-derived here because the derivation is the
argument, not the number:

- **The roster is 10 at the start of a run** (`START_MELEE` 6 + `START_RANGED` 4) **and at most 19**
  (`10 + 3 × 3`, from `map_max_count_nodes_on_a_route()`). At 0.20 s that is **2.0 s** and **3.8 s**.
- **Floor 0.084 s** — five rendered frames at 60 fps, the beat this repo has measured going entirely
  unseen. Below it the placements do not read as separate events.
- **Ceiling 0.50 s** — the probe's figure for the gesture this replaces is *last command at 7.4–12.9 s*
  over 10–13 actions, i.e. **0.6–1.0 s a drag**. At 0.50 s the hold is no faster than the drag.

⚠⚠ **Whether `SLOT_HOLD_SEC` belongs in `look.gd` or `rules.gd` is decided by Open 1 and by nothing
else.** Before the commit, `Battle.step` returns on `not _committed`, `elapsed` never advances, and a
player at 0.50 s reaches the same committed plan as a player at 0.05 s ⇒ **it is the repeat rate of an
input, and it is `look.gd`'s.** **During the fight it is the arrival spacing of reinforcements**, it
changes what happens, and it is `rules.gd`'s. **The same constant, two files, one open question.**

---

## 5. ⚠⚠ What it costs — the arithmetic, and what the arithmetic says

The user reached this repo's own central test unprompted, one turn after proposing the idea:
*"소환할때 코스트가 없기 때문이지?"* and *"많이 소환하면 그만큼 그냥 유리하기 때문에"*.

### 5.1 First, the half that is answered by construction

**Under version (a) a hold cannot inflate the army.** `slot_reserve_ids(slot)` returns the living soldiers
of that type still in `RESERVE`; holding slot 1 for ten seconds places **six** bodies and then marks
refusals forever. ⇒ **The hold changes the SPEED of placing, not the AMOUNT placed**, and the ceiling is
the roster — which is the cap the user themselves already chose (`plan-then-watch` decided 18:
*"the cap is not the boats. It is how many monsters you own"*).

⇒ **Row 32's fear — 「많이 소환하면 그냥 유리」 — does not bite under (a). It bites in full under (b).**

### 5.2 Now the half that is not answered — **price a plan**

Boats all depart on the commit frame, so a plan's sail cost is the **slowest** boat, not the sum.
Writing `R` for the roster, `g` for the seconds one drag costs and `s_i` for a landing's crossing:

> **price(plan) = R · g  +  max_i s_i**

**Term 1, the gesture** — `R · g` = 10–13 drags × 0.6–1.0 s = **6–13 s**. ⚠ **It does not depend on the
plan.** One beach or five, concentrated or spread, every soldier needs exactly one drag. **A constant term
does not change an argmax.** ⇒ **The drag friction is a tax, not a cost: it is paid by every plan
equally and it cannot rank any of them.**

**Term 2, the crossing** — measured on the shipped rows, harbour-to-landing in water hops at
`BOAT_SPEED = 4.0`:

| Island | hops min / median / max | seconds min / median / max | **spread** |
|---|---|---|---|
| 0 | 6 / 11 / 25 | 1.50 / 2.75 / 6.25 | **4.75 s** |
| 1 | 7 / 9 / 25 | 1.75 / 2.25 / 6.25 | **4.50 s** |
| 2 | 6 / 11 / 25 | 1.50 / 2.75 / 6.25 | **4.75 s** |

Against the probe's measured fight length on island 3 (**30.30–31.80 s**), that spread is **14.5–15.3% of
a fight.** ⚠ **Term 2 is the only term in the whole price that depends on which plan you chose.**

### 5.3 ⇒ **What this gesture does to the price**

**Term 1 → one press.** 10–13 gestures become 1.
**Term 2 → a constant.** A boat summoned in the band `d ≤ 1` is **one hop from its landing: 0.25 s, for
every landing on the island. The spread goes from 4.50–4.75 s to 0.00 s.**

> ## ⇒ **After this change the price of every plan is identical. Not "small" — identical.**
> **The one term that ranked plans is set to a constant, and the term that was already constant is
> deleted. There is no cost left in the game that depends on what you decided.**

#### ⚠⚠ REFUTED BY MEASUREMENT — the spread is **0.46 s**, not 0.00

**Struck rather than edited**, because the arithmetic above is the reasoning that produced the design and
the correction is worth more than a tidy number.

**The band shipped at `d = 2`, not `d ≤ 1`**, and the crossing off a `d = 2` tile is not one hop. Measured
on the shipped build, min / median / max seconds per island:

| Island | measured crossing | 
|---|---|
| 0 | **0.25 / … / 0.71** |
| 1 | **0.25 / … / 0.60** |
| 2 | **0.25 / … / 0.71** |

⇒ **spread 0.46 s at the adopted `d`.**

⚠ **The paragraph's DIRECTION survives and its headline does not.** 0.46 s against a 30.30–31.80 s fight
is **1.4–1.5%**, down from 14.5–15.3% — so term 2 really has stopped ranking plans in any way a player
could feel, which is what 5.4 and 5.5b are arguing about. But it is a **flattening, not a collapse**, and
"identical" is a word this doc may not use: a later round pricing plans off this line would build on a
zero that does not exist. **A number cited as exact and reaching the build as something else is the shape
this repo has paid for four times.**

#### ⚠⚠ AND THEN THE USER PUT THE TERM BACK — the spread is **4.86 s**

**5.3, 5.4 and 5.5b were all arguing about a term this gesture had flattened.** The user played the build
and moved the band away from the shore (§3.2), and the crossing came back with it: **1.60 / 2.83 /
5.96 s, a spread of 4.36 s** at the adopted `≥ 6`.

⇒ **That is §5.2's own drag figure restored.** The drag's crossing spread was **4.50–4.75 s**, and 4.36 s
is within that band, reached by a gesture that costs one press instead of 10–13.
⚠⚠ **And the drag it is compared against no longer exists**: round 4 deleted it outright.

⚠ **So 5.4's worry is answered by the same edit, and not by an argument.** 5.4 said flattening term 2
removed the cost that pulled toward the harbour-adjacent beach, leaving casualties as the only axis.
Term 2 is back at full size — and it no longer points at the harbour at all, because a summoned boat has
no harbour. ⚠ **It now points at *whatever coast is nearest to where you pressed*, which is a different
ranking**, and nobody has measured whether THAT one is dominated. **Open, and it is the interesting
question this round leaves behind.**

### 5.4 ⚠ And that paragraph is half wrong — the deleted cost was pointing the wrong way

**Term 2 was a cost, and it was a cost that pushed toward the plan the probe already measured as
dominant.** `boat-invasion` measured *"land next to a harbour dominates 3 of 3"*, and the crossing is
exactly why: the harbour-adjacent beach is the cheapest one to reach. **Flattening the crossing removes
the thing that made the harbour beach special.**

**The two axes, side by side**, on island 3: the landing point moves casualties **53.0 vs 79.0, a 49%
spread**; the crossing moves **14.5–15.3%** of the clock. ⇒ **With the crossing flat, the beach is chosen
on casualties alone, and casualties have three times the leverage.**

⇒ **Keep both halves. This gesture deletes one real ranking cost and one non-ranking tax; the ranking
cost it deletes was pulling toward the known-dominant plan, so its removal makes the remaining axis
cleaner, not dirtier. What it does not do is put a cost anywhere.**

### 5.5 One thing this gesture makes cheaper *relative* to something else — and it is small

The hold is one continuous press. **Landing on two distant coasts needs two presses.**

| | one beach | two beaches | ratio |
|---|---|---|---|
| drag, today | 10–13 gestures | 10–13 gestures | **1.00** |
| hold | 1 press | 2 presses | **2.00** |

⇒ **The relative penalty for dispersion doubles and the absolute penalty falls from 10–13 gestures to
one.** ⚠ **Neither is a cost in this repo's sense** — a difference of one press does not rank plans that
differ by 26 casualties. **Written down because it is the only asymmetry the gesture introduces, and
because it points the wrong way.**

### 5.5b ⚠⚠ A shipped game disagrees with 5.2, and it is in this repo's own verified table

**Pikmin**, in `what-makes-placement-a-decision`: *"The only means of command is throwing them one at a
time to a coordinate … the real time spent throwing is itself the cost, so 'all of them on one side' is
physically slow."* ⇒ **There is a shipped game in which the gesture IS the cost, and this design deletes
exactly that gesture.** Section 5.2's *"a tax, not a cost"* is not a general truth; it is a claim about
**this** tree.

**Why it still holds here, and it is a measurement rather than an argument**: Pikmin is real-time, so
throwing time is paid *while the fight runs*. **Every drag in this game is paid before the commit, and
`Battle.step` returns on `not _committed` — the clock does not advance.** ⇒ **the drag costs the player
seconds and costs the plan nothing**, which is the difference between a cost and a tax.
⚠⚠ **And that is exactly what Open 1 puts back in play**: hold *during* the fight and this design becomes
the Pikmin shape, in which the gesture is a cost again.

**Two more from the same table, disagreeing with each other about whether a placement region is enough:**

- **Loop Hero** — every placement raises reward and difficulty at once, so *"where do I defend"* becomes
  *"how much do I take on"*. ⚠ **Its case against is the sharpest one in that document and it lands
  squarely here**: *"Because you have no direct control over your character … you always want to play it
  safe when it comes to card placement. This reduces … the number of viable ways to play"* — **no control
  narrows the options rather than widening them.**
- **Despot's Game** — the same rule as TFT (place, then nearest-target, zero control) and **the opposite
  outcome**: position is not a decision at all, and *the studio admitted it by adding an auto-arrange
  button*. ⚠ **The single difference is whether abilities respond to distance and area** — which is
  `idea-inbox` row 39's warning, not this document's, and **it is not answered by any gesture.**

⇒ **The honest reading of three sources that disagree: none of them says a placement REGION makes position
a decision. Clash Royale's does, and only by converting position into time — the exact quantity section 5.3
sets to a constant.**

### 5.6 ⚠ What the cost WOULD have to be — **no cap is written, and none may be**

The user deferred the brake knowingly: ***"일단 빼고 만든 이후에 추가하자는 거임"***, and `idea-inbox`
row 47 adds ***"병사수 제한은 없음"***. **Nothing here licenses a cap, a cooldown, a wallet or a
per-tile limit.** What follows is what a cost would have to SATISFY, with the arithmetic that rules
candidates out.

**The three tests it has to pass**, and they are not this document's — they are already in the tree:

1. **Not linear in one quantity** — `session-loop` step 1: one extreme strictly dominates.
2. **Not a single interior optimum** — `session-loop` step 3: solved once, it is a calculation forever.
3. **In the same sentence as the advantage** — `lessons-from-two-dead-games`: bolted on later it is
   friction, not a cost.

**Candidate 1 — distance from shore.** The press is on the sea, so distance to the landing is a quantity
the player picks in the same gesture. **Refuted by section 3.3's own measurement**: pressing far out is
*both* slower *and* coarser — 55–118 sea tiles collapse to four corner landings. **Far is strictly
dominated, so there is no trade and no decision.**

**Candidate 2 — the Clash Royale shape**, the one verified game in `what-makes-placement-a-decision` whose
rule is a *placement region*: you may only place on your own half, and **position converts into time** —
back is safe but slow, the bridge is instant but leaves you no answer. **Applied here the region is the
sea and the conversion is the crossing.** ⚠ **Bounded by arithmetic on today's map**: the farthest water
tile is **25 hops = 6.25 s**, against a fight of **30.30–31.80 s** ⇒ **any position-derived cost tops out
at 20.1% of a fight and its median is 7–9%.** ⚠ **Whether that is enough is unmeasured.** ⚠ And its own
case against is in that document: **there is no Supercell primary source for the intent**, and Clash
Royale charges elixir as well, **so position is not the only cost there and cannot be shown to carry the
decision alone.**

**Candidate 3 — the hold happens DURING the fight** (Open 1). Then the cadence is not an input repeat rate
but **seconds of the fight spent trickling bodies in**: 10 bodies at 0.20 s is **2.0 s**, at 0.50 s is
**5.0 s** — **6.5% to 16.1% of a 31 s fight**, the same order as the crossing spread it replaces, and it
is paid in the same gesture that grants the advantage (test 3). ⚠ **Refuted as a plan-ranking cost by its
own arithmetic**: total streaming time is `R × cadence` whether you spend it on one beach or five, so it
is **flat in the number of fronts** — the same defect as term 1. **What is not flat is that the last body
lands `R × cadence` after the first, so a stream is a piecemeal landing by construction**, and piecemeal
costs HP only when the first arrivals are losing. ⚠⚠ **What a 2.0 s trickle costs in HP is a number this
document does not have.** `tools/probe/run_run.gd` can measure it. See section 10.

**Candidate 4 — permadeath.** Already structurally true: `Army` never compacts a dead row, and the probe
measured **2 of 5 landing policies lose the run** post-raise, so bodies really are scarce. ⚠ **It caps the
amount over a run and does nothing at all to one press.** It is why (a) is safe; it is not a brake.

⇒ **The honest conclusion, in bold, as the brief demands:**

> **This gesture adds no cost, and the arithmetic says the game has none that binds. The nearest thing to
> a cost that could live in this gesture without inventing a system is the crossing — and this gesture is
> what flattens it. ⇒ If a brake is ever wanted here, the lever is the SHAPE OF THE REGION (how far
> offshore you must press), not a cap on how many bodies come out.** That sentence is written so the next
> round does not re-derive it, and **it is not a licence to build it.**

---

## 6. What it replaces — the drag, and the stack it grabs from

**The drag is what the user complained about**, twice, in two different wordings:

- *"조작감이 너무 ㅈ같음"* — measured: the source is a **~10 px stack in open water**, verify-look put the
  whole stack at **~100 × 25 px for eight bodies**, and the probe counts **10–13 precision drags an
  island.**
- *"이걸 드래그해서 저기까지 이렇게 끌고 가는 게 그렇게 play가 재밌진 않아"* (`idea-inbox` row 26) — ⚠ **the
  wording moved**: not *the hand is aiming* but **the gesture itself is not fun.**

### The count, which is the whole gain

| | grabs | drops | **precision acts** | wall clock |
|---|---|---|---|---|
| **today** | 10–13, at ~12 px each | 10–13, at 18 px each (`ZOOM_MIN`) | **20–26** | last command at **7.4–12.9 s** |
| **hold** | **0** | **1**, at 18–54 px (section 3.3) | **1** + a sweep | **2.0–3.8 s** at 0.20 s |

⇒ **20–26 precision acts become one. Wall clock falls 3.4–3.7×.** ⚠ **And the per-act precision does not
improve** (section 3.3). **The grab is what dies — the worse half, at 12 px against the drop's 18.**

### ⇒ What happens to the harbour stack

**The drag dies with it, and so does the stack's job as a drag source.** But the stack carries a second
thing the design named on purpose: *「which of these thirteen is nearly gone」 is a planning fact, and it
is only readable before anything is dropped.* **Soldiers carry HP across islands and a dead one is dead
for good**, so that readout is not decoration.

⇒ **Three things the round has to decide together, and they are one decision:**

- `field_view`'s 6b block (RESERVE bodies drawn at `start_harbour`) — the only reason those bodies are on
  the water at all.
- `Look.IDLE_SOLDIER_*` (pitch 34, cols 7, origin (-102, -48)) and `field_view.idle_soldier_rect`.
- `grid.start_harbour` and `_derive_start_harbour` — **their only reader is that stack.**

**Recommendation: the roster readout moves into the slot boxes** — a slot shows how many bodies it can
still send, so the number goes down as you hold, which is the *"something on screen goes down"* the last
game died for the want of. ⚠ **Per-soldier HP has no home under that**, and this document does not invent
one. **Open 4.**

⚠⚠ **And the `H` legend character's last job is at stake with them.** If the region is rule B, **no code
path reads a harbour any more**: the boat is born where you pressed, the landing is derived from that,
`home_harbour_for` is never called, `water_fields` is replaced (section 7), and the only thing anchored to
a harbour was the stack. **Under rule C the harbour survives and pays for it with half the coastline.**
⇒ **Section 3's choice decides whether `H` stays in the map legend.** Nothing else does.

---

## 7. Presentation — pictures a person can judge

**A feature is not done until its presentation is.** What follows is what a person looks at, not code
facts.

### The five boxes

One row, bottom right — the corner `speed-off-open-landing` emptied. ⚠ **That document's sentence *"a
widget added to fill the gap would be one more thing to explain"* is overturned here and the overturn goes
into that file, not left implicit: this is the widget, and what explains it is the number inside it.**
Bottom-centre is refused for the reason the start button already gives.

- **Slot 1 and 2** — a solid box with a single large digit, and **a bar underneath that shortens by one
  notch every time a body leaves.** Full on the opening frame.
- **Slots 3, 4, 5** — flat grey, **no bar at all**. They read as *"there is a place here and nothing is in
  it"*, which is exactly true.
- **The armed slot** — green, the same green as 시작 (one verb, one tone), **and its border doubles.**
  Two channels, so neither carries the read alone.
- **An exhausted slot** — flat grey like 3–5 **but it keeps its bar, empty.** That empty rail is the only
  thing separating 「다 내보냈다」 from 「아직 아무것도 안 넣었다」.

⚠ **The boxes are a readout of a keyboard press and are not clickable** — no hover, no press dip.
`title-and-map` set the precedent with 설정하기: *a slot drawn as unpressable behaves as unpressable, and
those two are the same claim.*

### The summonable sea — **the 초록색 지역**

**A band of water hugging every coast**, drawn from the moment the island opens, in the tone this repo
already uses for *"you may drop here"*. At `ZOOM_MIN` one tile is 18 px, so `d = 2` is a **36 px ribbon**
around the island — thick enough to see at the zoom an island opens at, thin enough that it reads as a
shoreline rather than as "the sea is green".

⚠⚠ **This is the one positive mark on the field**, and it is the exact shape the user deleted for the
land (「못내림만 표시하면 됨」). **Section 3.1 is why it is not the same rule coming back**; the picture has
to be argued to the user on that basis, because it will look like it.

⚠ **The band is drawn always, not only while a slot is armed.** It is the answer to *"뭐 어떻게
동작시키는지 전혀모르겠는데?"* — the region on screen at frame one is what says a press belongs there.

### While you hold

**Nothing new is drawn, and that is the point.** Four things that already exist move, once a cadence tick:

1. **A hull appears on the pressed tile**, with a body visible inside it.
2. **A route line runs from it to its landing**, and a ring sits on the landing.
3. **A ghost appears at the landing** — the picture of a plan already built.
4. **The slot's bar drops one notch.**

⇒ Held for two seconds on one stretch of water, **ten hulls stand on the sea in a line with ten routes
fanning ashore.** That is the frame `planning-principles` line 6 asks for, and it is the one frame this
design has that the drag never had.

⚠ **The pinned hold spreads by itself and does not need a rule.** `_free_tiles_from` walks *over* reserved
tiles and collects only unreserved ones, so ten boats aimed at one beach unload in rings outward. ⚠ **The
ghost fan does NOT spread by itself**: `GHOST_FAN_PX` is 9 px per rank on one landing tile, so ten ghosts
reach 81 px and nineteen reach 162 px — **and that constant's own comment says past 14 px thirteen ghosts
"stop reading as ONE landing".** ⇒ **A hold pinned to one spot reaches in two seconds a state that
previously took nineteen deliberate drags.** Mitigated by the sweep, judged by the user, and if it fails
**`GHOST_FAN_PX` is the one constant that moves.**

### The three refusals — three different pictures

| What was refused | What the screen does |
|---|---|
| a number key for an **unbound or exhausted** slot | **that box shakes** sideways once and flashes toward the lose tone. The armed slot does not change |
| a press **outside the band** | the existing **red refusal mark** at the cursor, fired by the sim's own refusal, **once per cadence tick and not once per frame** |
| the cursor is over good water but **the slot is dry** | **no ring and no route are drawn at all.** The absence is the answer, and it arrives *before* the press instead of after it |

### The glyph count, because there is an acceptance row for it

| Screen | today | after |
|---|---|---|
| planning | **3** — 「시간 %.1f」 · 「적 %d」 · 「시작」 | **8** — those three plus five single digits |
| fighting | **2** | **2** — unchanged, the row is not drawn after the commit |

⚠ **The case against, stated because it is real: the user asked for fewer glyphs (「글자가 너무 많고」) and
this is more.** The case for: they are single digits inside boxes and **they are the instruction for a
control the user asked for by number.** **Only the user settles it.**

---

## 8. What it costs in code — the walls actually found

### The folder contracts it has to obey

| Folder | The rule | What this design puts there |
|---|---|---|
| `src/sim/` | never touches the tree; `.new()` is the whole construction | the slot table, the summon call, the nearest-landing field |
| `src/view/` | reads `sim`, never writes it; every drawing file exposes a hook | the band, the slot boxes, three new leaves |
| `src/shell/` | **the only place that reads `Input`** | the key branch, the press branch, the `_process` tick, the clears |
| `src/look.gd` | **every presentation constant** · `src/sim/rules.gd` **every constant that changes what happens** | the box geometry and the band tone here; the slot table and the band radius there |

### ⚠⚠ The wall — **`water_route` is indexed by HARBOUR and a summon has no harbour**

`grid.water_route(harbour_idx, landing)` descends `water_fields[harbour_idx]`, one BFS per `H` tile, built
once in `load_rows`. **A boat born at an arbitrary water tile has no such field**, and there are two ways
out with very different prices:

- ❌ **BFS from the pressed tile, per press.** 1,536 tiles on the shipped islands is cheap — **but
  `field_view` calls `water_route` EVERY FRAME while a gesture is in flight**, and the aiming ring needs
  it before the press. That turns a per-press BFS into a per-frame one. On the shipped long map (144 × 32
  = 4,608 tiles) it is 3× worse, and `push-inland` warns it goes further.
- ✅ **One multi-source BFS in `load_rows`**, seeded at every water tile that touches a sendable coast
  tile, carrying *(nearest landing, hops)*. Every water tile gets its landing in one pass, and the route
  is the descent of that field — **exactly the shape `sendable` already is**: filled once, read back
  forever. **This is the version this document computed all of section 3's numbers with.**

⚠ **`water_field_builds` counts every BFS and a net asserts it does not move across pumped frames.** The
new field must be built inside `load_rows` or that net is the thing that catches this being done wrong —
**which is what it is for. Do not raise its expected value to make a red go away.**

### The other things reading found

| # | What | Why it matters |
|---|---|---|
| 1 | ✅ **The return leg needs no change.** `_phase_landings` reverses the boat's own `path` and deletes it on arrival — a sea-summoned boat sails back to the tile it was summoned at and vanishes | An expected wall that is not there. **Do not add a return-to-harbour branch** |
| 2 | ✅ **`_free_tiles_from` already spreads a stacked landing** (it walks over reserved tiles, collects unreserved) | An expected wall that is not there |
| 3 | ⚠ **`boat["home"]` is a harbour index and a sea summon has none.** Its readers are `tools/look/capture_landing.gd` and **three nets that assert `send` and `home_harbour_for` answered as one** | **Those three nets have no subject for a summoned boat.** ⚠ **Do not "fix" them by making the summon pick a harbour** — that is rule C smuggled in through a test |
| 4 | ⚠ **`_soldier_hit_at` and `idle_soldier_rect` become dead** the moment the drag goes, and `grid.start_harbour` / `_derive_start_harbour` with them | Section 6. **Dead code that still draws is how a screen starts lying** |
| 5 | ⚠ **`CLAUDE.md` says 「키보드는 이 게임에서 아무것도 안 한다」 and this makes it false** | **It is not the reversal it looks like** — the user corrected the record themselves (rule 6). ⚠ **`CLAUDE.md` is not a file a design doc may edit. It goes up with the open questions** |
| 6 | ⚠ **Three stale comments say the keyboard is dead** — in `game.gd` (twice), `look.gd`, and `net_draw_leaf.gd` | **A refutation that lands in a different file than the claim does not propagate.** All four sites move in the same round or none does |
| 7 | ⚠⚠ **Mouse clicks cannot be driven headless and fail silently** — a 64×64 window, stretch 0.05, a click arrives at (2000, 6520) and raises nothing. **Keys pass fine** | ⇒ **half an input suite can be green while the other half is dead.** Every net row calls `game._unhandled_input(ev)` directly — the mouse half because it must, **the key half so the two are not driven by two mechanisms** |
| 8 | ⚠ **OS auto-repeat (`echo`) on a held number key** toggles the arm many times a second, silently | Guarded, with a net row that pushes `pressed = true, echo = true` |
| 9 | ✅ **`Look.GRID_W` / `GRID_H` are no longer a wall.** `field_view` reads `battle.grid.w` / `h`; the constants survive as a fallback | `push-inland` lists this as a wall and it has since been fixed. **Named so it is not "fixed" twice** |
| 10 | ✅ **No new `class_name` file is needed**, so the `--import` trap does not bite; **no new `Run.State`**, so `panel_view`'s red-패배-over-a-new-screen trap does not fire | Written down so the round does not spend itself defending against traps that are not here |
| 11 | ⚠ **`net_draw_leaf`'s per-file table is closed against each file's own `func` lines.** Every new `_paint_*` and every helper lands in the table **in the same edit as the file** | A name it does not hold is red, in both directions |

### The order the pieces have to land in

1. `rules.gd` — the slot table and the band radius. Nothing reads them yet.
2. `grid.gd` — the nearest-landing field in `load_rows`, and the route off it. Independent of 1.
3. `battle.gd` — the summon call and `slot_reserve_ids`. Needs 1 and 2.
4. `look.gd` — the box geometry, the band tone, the cadence.
5. `field_view.gd` + its leaf table, **in one edit** — the band and the aiming marks.
6. `hud_view.gd` + its leaf table, **in one edit** — the five boxes.
7. `game.gd` — the key branch, the press branch, the `_process` tick, the clears.
8. The nets, then the docs. ⚠ **Split 5 or 6 across two edits and the round is red for the gap, and a red
   that is expected is a red nobody reads.**

---

## 9. Open questions — **none of these closes by inference**

⚠ **The repo has been burned exactly that way and it cost a whole step**: `title-and-map`'s plan opened
with five questions marked *"these go to the user in ONE message"*, **the message was never sent**, all
five defaults shipped silently, and one of them descoped step 5.

| # | Question | What changes on each answer |
|---|---|---|
| **1** | ⚠⚠ **Does the hold happen before 시작, or during the fight?** | **Before**: `SLOT_HOLD_SEC` is a `look.gd` constant, planning time is free, the gesture has no cost, and this is a pure replacement for the drag. **During**: it is a `rules.gd` constant, the cadence is arrival spacing, holding costs **6.5–16.1% of a 31 s fight**, and it becomes the natural body of `push-inland`'s decided 8 (「저 배만 좀 참여하는 걸로」). ⚠ **`idea-inbox` row 29 already named this as the load-bearing question and it has stood unanswered since.** ⚠ **It is NOT closed by push-inland's decision** — that decided you may act on boats during the fight; it did not decide that this gesture is how |
| **2** | **Is the region an allowlist (a drawn band) or the whole sea?** | **Band**: there is a 초록색 지역, matching the user's own word, and 0.6% of the sea's meaning is lost (98–99% of landings either way). **Whole sea**: nothing to draw, and 「소환할 수 있는 곳」 has no referent. ⚠ **Recommended: band**, section 3.2 — **but it contradicts 「못내림만 표시하면 됨」 on its face and the user has to hear that** |
| **3** | **How wide is the band?** `d = 1` / `2` / `3` | 90 / 190 / 254 sea tiles on island 0; a **18 / 36 / 54 px** ribbon at `ZOOM_MIN`; median catchment **1 / 2 / 3** tiles. ⚠ **Reachable landings are 98–99% at every value**, so this is purely a question of what is comfortable to hit and how thick the green reads. **Recommended `d = 2`** and it is a taste call, which is why it goes out rather than being chosen here |
| **4** | ⚠ **Does the drag die, and where does per-soldier HP go?** | **Dies**: the ~100 × 25 px stack goes, `start_harbour` loses its only reader, `H` may leave the legend — **and 「이 열세 중 누가 죽기 직전인지」 loses its picture.** **Stays**: the complained-about gesture survives beside its replacement, and it is the only way to place one specific wounded body. ⚠ **The user asked whether it was already deleted** (row 55), which reads as expecting it gone — **reads as, which is not said** |
| **5** | **What does a slot hold — a type, or a designed cell?** | Section 2. **Type**: buildable now, the hold changes speed only, five slots are five quotas. **Designed cell**: the 세포 economy, which is blocked twice and whose own review found the five slots collapsing into one. ⚠ **Answering "designed cell" does not unblock it** — it re-opens `session-loop`'s arithmetic against new variables |
| **6** | **Which body does a slot send first — healthiest or most hurt?** | Healthiest-first is `army.living_ids_of_type`'s already-documented order and means your best bodies take the first blows. Most-hurt-first spends the dying ones and needs a new ordering rule in `army.gd` |
| **7** | **Five boxes on screen, or two that grow later?** | Five is the user's own 「1~5번까지」 and says five exist. Two is less to read now and a layout change later. **Glyph count 3 → 8 either way is 3 → 5 with two boxes** |

⚠ **Question 1 is the one that must go out first.** Every other row is buildable under either answer;
**question 1 changes which file a constant lives in, whether the gesture has a cost at all, and whether
this document is a replacement for the drag or the first live control the game has ever had.**

---

## 10. Where a number was wanted and there is none

**Written down rather than estimated.** `lessons-from-two-dead-games`: *a design complaint can become a
number*, and the probe that does it exists.

1. ⚠⚠ **What a 2.0 s trickle costs in HP.** Section 5.6 candidate 3 turns on it, and it is the only
   version of a cost that does not invent a system. **The probe can measure it**: land ten bodies
   simultaneously vs at 0.20 s spacing, on the same beach, and read the casualty difference.
2. **What the drag count actually becomes.** The probe counts 10–13 today. **Nobody has counted the
   gesture count of a hold**, and section 6's "1" is arithmetic, not a measurement.
3. **Whether the region is findable without being told.** The last round failed on exactly this
   (*"뭐 어떻게 동작시키는지 전혀모르겠는데?"*) with every check green. **No instrument in this repo
   measures it. Only the user does.**
4. **Whether flattening the crossing changes which beach wins.** Section 5.4 argues it should; **the probe
   has never been run with a flat crossing** and the argument is unmeasured.
5. **What `d` is comfortable to press at `ZOOM_MIN`.** A 18–54 px ribbon is arithmetic off `TILE_PX × 0.45`;
   **nobody has looked at one.**
6. **How the band reads on the long map.** Every number here is off the three 48 × 32 islands. The shipped
   long map is 144 × 32 and **was not measured** — the band's share of a long map's water is unknown, and
   `push-inland` says the direction is to grow slowly from 48 × 32 rather than to jump.
7. ⚠ **The measurements in sections 3 and 5 were computed in Python off `islands.gd`'s rows**, by
   re-implementing the shipped 8-way water rule including the diagonal shoulder guard. **They agree with
   every figure the shipped docs already carry** (water 724 / 690 / 726, sendable 84 / 76 / 82) — **which
   is a cross-check, not a run.** A net or the probe should reproduce the catchment and hop tables inside
   the engine before a plan sizes anything to them.

---

## 11. What this contradicts, and where the correction has to land

**A refutation that lands in a different doc than the claim does not propagate.** Each row below names the
document that has to be edited — **not this one.**

| Document | The claim this contradicts |
|---|---|
| `slot-summon` (the plan, `1.ready`) | **Superseded whole.** Its press target is a landable coast tile; its section 11 lists *"summoning onto the sea"* as out of scope on the strength of `idea-inbox` row 33, and row 56 corrects that reading |
| `idea-inbox` row 33 | *"Row 30's 「바다에 소환」 is withdrawn in the same turn it was raised"* — **it was not.** The boat stays AND the summon is on the sea |
| `plan-then-watch` | Its 「infinite is free」 box quotes 「바다위에 초록색 지역」 and reads it only for *boats are unlimited*. **The first half is a gesture and it was never built.** Its decided 16 (*"no queue — they stand at the launch point and you drag one"*) is what this replaces |
| `speed-off-open-landing` | *"the bottom right is now empty on purpose … a widget added to fill the gap would be one more thing to explain"* — **overturned**, section 7 |
| `boat-invasion` | *"one control — drag a boat to the shore"*. ⚠ **Its finding survives intact**: the landing point still picks which enemies engage, because that is about detect radii and not about how the boat got there |
| `CLAUDE.md` | 「**the keyboard does nothing in this game at all**」 and 「the 1~5 summon keys are deleted」. ⚠ **Needs the user's word — a design doc may not edit that file** |
| `grid.gd`'s header | *"`home_harbour_for` … is what `Battle.send` answers to"* — true today, and **false for a summoned boat**, whose origin is the press |

---

## 12. Out of scope — **unwritten, a builder expands into it**

- **The 세포 / 오브젝트 economy.** Slots 3–5 stay unbound and are **not** filled with `BISON` / `CROW` /
  `LION`.
- **Re-binding a slot at runtime.** That IS the economy.
- **Any brake, cap, cost, wallet or cooldown.** Section 5.6, and the user deferred it knowingly, twice.
- **`GHOST_FAN_PX`, `Rules.BOAT_SPEED`, `Islands.TIME_LIMITS`, `ZOOM_MIN`** and every other tuned constant.
  ⚠ `GHOST_FAN_PX` is *named* in section 7 as the constant that moves **if** the user says a pinned hold
  stops reading as one landing. **Naming is not tuning.**
- **Mid-crossing redirect**, recall of a summoned boat, or steering a boat after the commit.
- **Clicking the slot boxes with the mouse**, hovering them, or a press dip on them.
- **Numpad keycodes, key rebinding, `project.godot`'s `[input]` section.** The shell reads a raw
  `InputEvent` deliberately, so what a net drives is the shell rather than a settings file.
- **The loss condition, the chest's payout, `title-and-map` step 5, and the map's shape.** All open
  elsewhere; none is touched here.
