# Plan it, then watch it — the hand only moves before the start

**Implemented**: **all four stages of the plan `plan-then-watch` are in `src/`** — the planning state and
the commit gate inside `step()`, unlimited boats created by a drag, `recall`, the sub-step and the
0/1/2/3/6× ladder, the plan drawn as ghosts · routes · rings · the army standing at the harbour, the
camera pulled back to `ZOOM_MIN` 0.45, and the enemy counts raised to **8 · 12 · 14** with
`TARGET_LINE_MAX_COUNT` at 14. The 1/2 keys are deleted. The round is **12 nets / 1328 checks**, and
`tools/probe/run_run.gd` plans-commits-watches. ⚠ **Not built, on purpose**: any brake on the boats
(「infinite is free」 at the top) and any mother ship (undecided 14).
**Accepted**: ⚠ **No. The user played it on 2026-08-19 and it failed twice.**
① They could not find the controls at all — *"뭐 어떻게 동작시키는지 전혀모르겠는데?"* (*"I have no idea
how to even operate this"*) and *"조작감이 너무 ㅈ같음"* (*"the controls feel like shit"*).
⇒ **The first acceptance row — 「계획이 커밋 전에 읽힌다」, the plan reads before the commit — failed on
contact with a human**, and by this doc's own 「two reference games」 section that row is not decoration
but the condition on which the whole design stands. Measured: the drag source is a ~10px stack in open
water, the droppable coast is alpha 0.18 over dark green, and the probe counts **10–13 separate
precision drags per island**.
② Then *"싸움이 좀 아직은 별로네? 일단 다음 세션에서 꽉 잡아봐야겠다"* (*"the fighting still isn't good;
I'll get a proper grip on it next session"*) — **the first verdict on what happens AFTER the start button.**
Every complaint before this one was about the frame around the fight. **The user parked it themselves;
parked is not answered.**
The ten 「decided」 lines below are still the user's own words from 2026-08-18 and each carries its quote.
Nothing else is confirmed.

**One line**

> **You lay out the whole landing, press start, and watch the island get taken.**

⚠ **This line is derived.** The user did not say it; it joins two things they did say —
*"이렇게 이렇게 시작합니다"* (*"we start like this, and like this"*) and *"쫙 움직이면서 점령을 하는
느낌"* (*"the feeling of everything sweeping out and taking the place"*).

---

## ⚠⚠ A named hole, left open on purpose — **"infinite is free"** (deferred by the user, 2026-08-18)

**It sits at the very top so it cannot be walked past. Nothing below fills it.**

**Boats are unlimited.** You put your monsters on the green water region and boats sail without limit —
*"배는 너무 곁다리 느낌이다 그냥 바다위에 초록색 지역에 내가 설계한 몬스터들을 무한으로 배를 띄워서
보낼 수 있는걸로하고 싶어"* (*"the boat feels like a side-show; I want to just send my designed monsters
from the green area on the sea, on infinitely many boats"*). ⇒ **the cap is not the boats. It is how many
monsters you own.**

⚠ **And apart from that cap there is no brake at all.** Infinite plus free freezes one dominant line:
**send everything at once to the nearest beach.** That is **the exact shape that killed the second game** —
[what two dead games left behind](../lessons-from-two-dead-games.md): *an advantage with no cost is not a
decision, and a mechanic that is not a decision is not fun.* And the probe section below has **already
measured that domination in the current tree** (item 1).

**The main session put that arithmetic to the user and offered three brakes with it:**

| Candidate brake | What it bites |
|---|---|
| **Sail time** | A far beach lands later ⇒ "everything at the nearest one" starts paying in seconds |
| **Landing-tile capacity** | Caps how many bodies one beach can take at once ⇒ piling onto one point stops being physically possible |
| **Permanent death** | **Already structurally true** (`Army` never compacts a dead row). Once bodies are a finite resource, over-sending costs something |

**The user's answer**: ***"일단 빼고 만든 이후에 추가하자는 거임"*** (*"leave it out, build it, add it
after"*) ⇒ **build with no brake.**

⚠⚠ **So this is deferred, not forgotten, and the next session must not read its absence as a decision.**

- **A builder does not quietly add a brake because "the arithmetic does not work."** Doing so decides, on
  the user's behalf, the thing they deliberately postponed
- **This repo's own rule binds here**: *deleting a metric without standing one up in its place is how a
  repo starts lying to itself.* **A deleted cap is the same.** So the **cap that was deleted (the boat
  count)** and the fact that **nothing stands in its place today** are written down right here
- **Closing condition**: the user picks one of the three above. Until then this section stays open

---

## This is the **part loop** — and it replaces how that loop is played

The user renamed the loops; outside in it is **main → session → part**.
[The session loop](session-loop.md) holds that table — it is not repeated here.

| Loop | This doc |
|---|---|
| Main (outside a run) | not covered |
| Session (one run) | not covered — [the session loop](session-loop.md) carries it |
| **Part (one island)** | ✅ **this document, replacing what is built** |

**The part loop as built**: an island opens, the clock starts, the player boards soldiers with number keys
*during the fight* and drags boats out, watches the auto-battle, boards again, sends again.

**The part loop in this document**: an island opens, **the clock is not running**, the player fills every
boat, places every one of them, sets the order they go in, **presses start** — and then **does nothing.**

⇒ **What changes is not what gets decided but when.** *Where*, *who* and *in what order* are questions the
shipped game already asks; this document moves all three **in front of the start button.**

---

## Why this document exists

The user played the [boat and landing](boat-invasion.md) round and said
*"참 애매하네. 그래도 그동안 중에서 제일 평범하네."* (*"really ambiguous — still the most ordinary of
them so far."*)

**[The session loop](session-loop.md) was the first attempt at that sentence, and half of it died today.**
It tried to build what sits **above and below** the part loop — the map, the refit, cells, objects — and
left the part loop as built. **Today the user replaced the part loop itself.**

⇒ **So this document does not replace the session loop; it replaces the floor underneath it.** What died
and what survived is written in the refutation box at the head of that document.

---

## ⚠⚠ An adversarial review ran the probe — **the plan is neither a decision nor a calculation. It is indifference** (2026-08-18)

**This is the most important section in the document. Read it before building anything below.**
Every number here comes from actually running `tools/probe/run_run.gd` against the current tree, and **the
main session ran it a second time to confirm.** None of it is derived.

**Five policies × three islands = fifteen island-runs. All fifteen won.**

| Policy | Island 1 damage / time | Island 2 | Island 3 |
|---|---|---|---|
| everything at once | 29.0 / 22.7 s | 26.0 / 15.8 s | 52.0 / 30.3 s |
| one boat at a time | 24.0 / 17.9 s | 32.0 / 16.6 s | 52.0 / 31.7 s |
| the far shore | 21.0 / 22.5 s | 28.5 / 24.2 s | 74.0 / 31.5 s |
| the quiet shore | 32.0 / 29.1 s | 26.0 / 23.9 s | 62.5 / 31.8 s |

- **The worst plan finishes at 49% of the limit** (island 1, 29.1/60). Island 3 sits at **35%** (31.8/90).
- **Island 3's entire spread is 1.50 s.** To discriminate, `TIME_LIMITS[2]` would have to land inside
  (30.30, 31.80] — **narrower than the error on the next plan nobody has run yet.** ⇒ **the clock cannot be
  given discriminating power by tuning.**
- **`src/sim/` contains zero randomness** (grep: zero hits; two control runs identical to the decimal).
  ⇒ **three fixed islands + no randomness + one commit + no preview = a three-level puzzle, and the probe
  has already solved it.**
- **Clearing island 3 ends the run as `WON`, so leftover HP has nothing to spend itself on** — finishing on
  a pool of 28.5 scores the same as 45.0. **Both currencies are dead.**

> ### ⚠⚠ Update box — **this section's "fifteen wins" predates the enemy raise (2026-08-18, later the same day)**
>
> The table above was measured at **4 · 6 · 5** enemies; this doc's stage 4 raised them to
> **8 · 12 · 14**, and the sub-step landed after that. ⇒ **Read the table and the four lines below it as
> a record of what things looked like BEFORE the fix.**
>
> **The same probe was re-run on today's tree while writing [the title and the map](title-and-map.md):**
>
> | Policy | Island 1 dmg | Island 2 | Island 3 | Run |
> |---|---|---|---|---|
> | nearest coast (baseline) | 27.0 | 41.0 | 77.0 | cleared · 2 soldiers · **7.0** pool left |
> | nearest coast, drop order reversed | 27.0 | 47.0 | 47.5 | cleared · 4 soldiers · 30.5 |
> | coast farthest from enemies | 30.0 | 37.0 | 60.0 | cleared · 5 soldiers · 25.0 |
> | farthest coast | 36.0 | 54.5 | 61.5 | ⚠ **lost — wiped on island 3** |
> | half onto each of two coasts | 41.0 | 65.0 | 46.0 | ⚠ **lost — wiped on island 3** |
>
> ⇒ **It is not fifteen wins out of fifteen. Two of five policies lose the run.**
> ⇒ **"Both currencies are dead" is no longer true either** — enter island 3 with a pool of 84 and you
> come out alive; **enter with 61.5 and you are wiped.** Leftover HP is now **the scarcest thing in this
> game.**
> ⚠ **The baseline worst is 61.8%, not 49%** (this section itself says "not directly comparable to the
> old 49%").
> ⇒ **Line 1 above (over-boarding is free) still stands** — the dominant plan is still dominant.
> **What died is the other half: "an island takes nothing away."**
>
> ### ⚠⚠ And that table is itself superseded — **the map changed what a run IS (2026-08-19)**
>
> The rows above were produced by a driver that walked **island indices**. `Run` now starts in
> `State.MAP` and `_advance()` lands back in `MAP`, so that driver played **zero islands** and the
> table cannot be reproduced on this tree at all. The probe was repaired to walk a ROUTE, and **a run
> is now five nodes and four islands** — nothing above is comparable with anything below.
> ⇒ **The live numbers are in [the title and the map](title-and-map.md)'s probe box.** What survives
> from here unchanged: over-boarding is still free, and HP is still the scarcest thing.

### ⇒ What that breaks — four items

1. **Over-boarding is free.** No upkeep, no per-body cost, and an unhit soldier carries to the next island
   at zero HP loss. The only bunching penalty is the lion's `area 1.5`, and **splash saturates around five
   bodies while DPS grows linearly with N.** Ranged bypasses it outright — reach `4 + 1.5 = 5.5` against the
   lion's `detect 2.0`, so **the lion never sees them, never moves and never swings.**
   ⇒ **"everything, at the cheapest beach, in one wave" dominates.**
2. ⚠⚠ **Boat order is completely inert.** Arrival time, aggro, tile reservation and pathing — **none of the
   four reads order.** `launch` has no departure-time field and `setup` puts both boats at the same harbour,
   so **a committed plan sails on the same frame.** The one thing order does is backwards:
   `_phase_landings` iterates in reverse, so **the boat that launched later unloads first and takes the tile
   nearer the target.** ⇒ **decided rule 2's "in what order" has no referent in the sim.**
3. **Island 1 admits exactly one plan.** Of the four bison's `detect 6.0` circles, only the pair 11.05 apart
   can ever overlap, and that lens is **3.0 tiles²** against 744 land tiles — **0.4%.** Soldiers have no
   detect radius (`NO_DETECT`), so **wherever you land you meet the same bison one at a time, in an order
   geometry already fixed.**
4. **There are about 8 things to plan against in a whole run, not 15** (island 1: 1 · island 2: ~3 ·
   island 3: ~4). ⇒ **More of the same enemy adds kills, not plans. What adds plans is enemy types whose
   `range`, `area` and `detect` differ, and terrain that separates them.** There are three types today.

### ⚠ All three replacement health metrics improve as the game gets worse

- **Time to reach maximum speed** — max speed at t=0 could mean "boring" or "the plan reads and I already
  know the outcome". **Success and failure score identically**, and lowering the speed cap scores full marks.
- **Planning time and actions taken** — **the sign is inverted.** The score rises the *less* readable the
  planning screen is. Deliberation and confusion are the same number.
- **Pause presses** — deleting the button scores full marks, and it **moves opposite to the first one**
  ⇒ **no design satisfies all three, and the one that satisfies the first is the bad one.**

### ⚠ Correction — **the boat already makes return trips**

Both this document and the conversation carried *"capacity 4+2 = 6, so four soldiers can never land."*
**That is not a property of the sim.** `_phase_landings`' RETURNING branch restores `boat_at` and removes the
boat from `boats`, so it becomes loadable again, and **the probe launches 4–5 times an island and lands all
10–13 soldiers.**
⇒ **The shortfall is true only if "the hand does not move" ships without automatic re-launch.** And automatic
re-launch bites from the other side: 13 soldiers is 3 waves, and a sailing clock of
`(2w−1)·t_c ≈ **19.5 s`** then **runs on a schedule the player cannot express.** ⇒ that is undecided 8.

### ⇒ What did not break

- **Step 4's axis argument survives** — island 3 pairs a crow (range 3) with a lion (area 1.5), so two
  templates are genuinely needed.
- **The sim is deterministic** — zero randomness, two control runs identical, and the probe's own inversion
  (one soldier at 1 HP) really did lose.
- **Permadeath is structurally true** — `Army` never compacts a dead row.

⚠ **This section does not reject the design. It shows that what the design hangs on is not a rule but an
island you can lose on** — and the tree does not contain one.

---

---

## ⚠⚠ Superseded, 2026-08-19 — four of this doc's rules were taken when a fight was one minute

**Nothing below is deleted and nothing here is built.** The user redesigned what one combat node contains
(a continent-scale push, 10–15 minutes) and the derivation lives in `push-inland`. **Implemented: none.
Accepted: nothing chosen.** These boxes say a claim no longer stands unsupported — **not that anything
changed.**

| This doc's claim | What overturns it |
|---|---|
| **Decided 1** — *"전투 중에 손이 움직이는 거, 안 움직일 거 같은데."* | **The user reversed it**: *"저 배만 좀 참여하는 걸로 해서 기획 한번 해보자"* (2026-08-19). **You may act during the fight, on boats only; a soldier ashore still cannot be touched** |
| **Decided 8** — *"싸움 자체가 일 분은 안 넘어갈 거 같은데 … 배속이 있을 거 같고"* | **A stage is now 10–15 minutes** (*"스테이지당 10~15분 정도가 좋을듯"*). ⚠ **And the second half of that sentence is already gone**: the speed ladder and the pause were deleted earlier the same day. **A 10–15 minute node runs at 1× with no brake, no skip and no pause — a thing the user has never seen** |
| **Decided 20** and the screen table's **「The whole island — fits one screen」** | **Arithmetically impossible at continent scale.** `push-inland` derives a node **984–1,476 columns** long = 39,360–59,040 px. Fitting that into 1,280 px needs zoom **0.0325**, **13.8× below `ZOOM_MIN` 0.45**, at which the smallest body (the crow, 10.0 px at zoom 1.0) draws at **0.33 px** against the **8 px body floor** `look.gd` records as `ZOOM_MIN`'s own reason. ⇒ **`field_view` can never draw a whole node**, so decided 2's *"배치나 이런 게 미리 보이는 거지"* needs a second view that does not exist |
| **Decided 3** — the 48×32 grid it plans against | Reopened; see the same box in `boat-invasion` |

### ⚠⚠ And the sharpest consequence is this doc's own sentence, turned on itself

> *"Rules 1, 4 and 5 are one block that props itself up. All three say **nothing exists after the commit**.
> Soften any one of them and the other two collapse."*

**Rule 1 has been softened.** ⇒ **By this doc's own argument, decided 4 (a pause you can do nothing with)
and decided 5 (no preview, no pre-run simulation) are now unsupported.**

⚠ **Neither has been re-decided. This is a hole, not a change.** Nobody has asked the user whether a pause
survives, whether it acquires a verb, or whether a preview returns — and the pause was separately deleted
with the speed ladder, so **there is currently no pause to attach the question to.**

⚠ **A second thing survived that this doc never recorded here.** The rejected real-time branch in
`commit-before-the-fight-not-during` was rejected for **two** reasons, and the boat-only reversal answers
only the first. The second — *"게임이 Clash Royale처럼 보일까 걱정"* — is untouched, because sending units
into a live fight from a home edge **is** that shape. **It has never been put back to the user.**

### What this doc keeps

Decided 2 · 3 · 6 · 7 · 9 · 15 · 16 · 17 · 18 · 19 are unaffected, and **its case against itself is the
most reusable thing in it** — Frozen Synapse and Door Kickers both hand the player what this design
refuses. ⚠ **The boat-only reversal moves this design one step toward Door Kickers** and makes that
citation half-usable for the first time; it does not make it evidence, because Door Kickers pays by
letting you return to *planning*, and here there is one verb and no pause.


## What is decided — **all ten said by the user, 2026-08-18**

| # | Rule | The user's words |
|---|---|---|
| 1 | **The hand does not move during combat.** Everything is decided before the fight starts | *"전투 중에 손이 움직이는 거, 안 움직일 거 같은데."* (*"the hand moving during combat — I don't think it will."*) |
| 2 | **You plan on the map and press start.** The map is laid out, there is a region you may place into, **you drag boats onto it and set the order they go in**, and **the plan is visible before you commit** | *"이렇게 이렇게 시작합니다"*, and once started, *"쫙 움직이면서 점령을 하는 느낌"* |
| 3 | **Before the start the boat is free.** Loading and placing are unrestricted | *"배는 언제든지 내가 태울 수 있는 거지. 언제든지 시작하기 전에 어디서든지 내가 넣을 수 있는 느낌."* (*"I can load a boat any time, put it anywhere, any time before the start."*) |
| 4 | ⚠⚠ **DELETED IN CODE 2026-08-19 — there is no pause.** It was slot 0 of the speed ladder and went with it at the user's request (「일시정지 지워주고」, `speed-off-open-landing`). ⚠ **Nobody decided whether a pause should exist in a 10–15 minute node** — see the collapse box above; **this row is history, not a rule.** ~~Pause exists during execution, and you can do nothing with it~~ | *"이시정지가 있긴 한데 이시정지 한다고 해서 내가 또 뭔가를 해줄 수는 없어."* (*"there's a pause, but pausing doesn't let me do anything more."*) |
| 5 | **No pre-run simulation and no preview of the outcome** | *"미리 보긴 없고."* (*"no previewing."*) |
| 6 | **If you get wrecked, you lose. That is all** | *"딱 시작을 했는데 이제 개털리면 지는 거지. 그냥 지면 지는 거야."* |
| 7 | **"When do you find out you were wrong" is not a question.** The user closed it themselves | *"지면 틀린 거거든. 그래서 이건 뭐 틀린 걸 언제 알았을 필요는 없지."* (*"losing is being wrong, so there is no need to know when you were wrong."*) |
| 8 | **A fight is around a minute.** It may run longer, and **there is a speed-up** | *"싸움 자체가 일 분은 안 넘어갈 거 같은데. 넘어가도 되는데 배속이 있을 거 같고."* |
| 9 | **The 1~5 summon keys are dead.** They existed because boat capacity forced "who goes first", and that question moved into the plan | The user asked directly: *"근데 칸을 왜 눌러? 이거 배 때문에 칸 누르는 거 맞아?"* (*"why am I pressing a slot at all? is it because of the boat?"*) — **the answer was yes, and the key went with it** |
| 10 | **Variety is a later problem.** Parked, not solved | *"다양성이나 이런 건데 이건 추후에 계속해서 생각해 보자고."* |

⚠ **Rule 9 is the most expensive line here.** On its own it pulls the floor out from under
[the session loop](session-loop.md)'s central feature, *"you design five slots"* — **there were five slots
because there are five fingers, and there is no finger left to press.** What survives is undecided 1 below.

⚠ **Rules 1, 4 and 5 are one block that props itself up.** All three say *nothing exists after the commit*.
Soften any one of them and the other two collapse — which is what the counter-case box below is about.

### ⇒ A second conversation the same day settled six more — **all of them the user's own words**

| # | Rule | The user's words |
|---|---|---|
| 15 | **Boats round-trip.** Drop the cargo, come back, take the next | *"배는 왕복"* (*"the boat goes and comes back"*) |
| 16 | **There is no queue widget.** The monsters stand at the launch point, and **you drag one onto a landing spot and that boat departs from that moment** | *"대기열은 없고 ... 내가 내릴 수 있는 곳 위치에 딱 나서 ... 그걸 누가 늘어서 끌어서 탁 놓으면은 그때부터 출발하는 거지. 대기열이라는 게 사실 좀 애매해."* (*"no queue … they stand right at the place I can land … you line them up, drag one and drop it, and from then it departs. A queue is honestly a bit ambiguous."*) |
| 17 | **The order you drop them IS the order.** There is no separate handle for it | The same sentence — *"끌어서 탁 놓으면은 그때부터 출발하는 거지"* |
| 18 | ⚠⚠ **The boat is plumbing, not a resource, and it is unlimited.** The cap moves off the boat count and onto **how many monsters you own** | *"배는 너무 곁다리 느낌이다 그냥 바다위에 초록색 지역에 내가 설계한 몬스터들을 무한으로 배를 띄워서 보낼 수 있는걸로하고 싶어"* |
| 19 | **The brake is left out on purpose.** It gets added after the thing is built | *"일단 빼고 만든 이후에 추가하자는 거임"* — the "infinite is free" section at the top |
| 20 | **The planning camera pulls further back.** The whole island in one frame | *"조금 더 카메라를 뒤로 빼야 될"* (*"the camera has to pull back a bit more"*) |

⚠ **Watch the word 「곁다리」 in rule 18 — it has come back a third time, pointed somewhere else.**
The user said *"배가 곁다리다"* (*"the boat is a side-show"*) **twice**, and the
[boat and landing](boat-invasion.md) round stopped it — that document's `Accepted` line records it, and
**it did not come back this time either.** **What came back is "the boat *being a resource* is the
side-show."** ⇒ **Opening the coastline and the fleet was not the wrong move; making the boat the object
of the plan was. The object of the plan is the monsters.**

⚠ **Rules 16 and 17 close undecided 11.** *How is the order assigned* is no longer a question —
**the sequence of drops is the order, and a drop departs.** ⇒ **no order widget and no queue widget
get built.**

⚠ **The mother ship is NOT settled — undecided 14.** Four mockups were drawn; the user liked **variant 2's
size** but said it was **too close**, said **a big boat from the start is not fun**, and then moved
straight to rule 18 without settling it. ⇒ **Do not invent a mother ship.** This round builds on the
**harbours already in the code** — **zero new rules.**

---

## ⚠⚠ **Both reference games hand the player exactly what this design refuses**

**This is the strongest case against this document, which is why it is near the top and not buried.**

Two shipped games succeeded on "plan it, then execute it". **Both give the player one safety net after the
commit.**

| Game | The safety net | This design |
|---|---|---|
| **[Frozen Synapse](https://en.wikipedia.org/wiki/Frozen_Synapse)** | **You simulate the outcome before committing** — *"The game provides a facility to review all previous turns and simulate the projected results of the current turn, assuming that enemy forces maintain their current strategies, allowing the player to refine their actions."* And a turn resolves over about **5 seconds** | **Decided 5 deletes the preview.** And a fight is not 5 seconds but **a minute** (decided 8) |
| **[Door Kickers](https://en.wikipedia.org/wiki/Door_Kickers)** | **You go back to planning mid-execution** — *"the player can still draw paths during the engagement stage, and can switch between engagement and planning at any time."* | **Decided 4 deletes it.** The pause carries no verb |

⇒ **So this design cannot cite either of them as evidence for itself.** Both hold something a player can do
the moment they realise the plan is wrong. This one holds nothing.

### ⇒ Then what has to stand in its place — **there is exactly one answer**

**The plan has to be readable before the commit.** Frozen Synapse reads it out with a simulation; Door
Kickers lets execution read it out and then lets you go back. **This design has one screen before the commit
and no other source of information at all.**

⇒ **That makes the planning-screen section a condition of this design working, not decoration.** If the
screen does not read, the player is not deciding but **guessing**, and decided 6 (*"you lose, that's it"*)
stops being a design and becomes a **punishment**.

⚠ **The user already accepted half of that risk in decided 7** — *"losing is being wrong."*
**What they accepted is "when did I find out", not "could I have known."** The second is still open, and it
is this document's job to answer it.

---

## What the pause is for — **honestly**

**Decided 4 creates a button with no verb.** Such a button can do exactly three things, and there is no
third:

1. **Reading.** It freezes a moving picture so the eye can catch up. That information **cannot change this
   fight**; it feeds the plan for the next one. ⇒ **the pause's output is the next island, not this one**
2. **Interrupting.** The phone rings. A comfort feature, not a design one
3. **Nothing.** A decision needs an action, and it was decided there is none

### Is it a different widget from the speed control — **on what is known, it is the same axis**

Speed-up and pause are **one time multiplier**: 0× · 1× · 2× · … ⇒ **pause is 0×, and there is no
mechanical reason to build it separately.** Only the reason for pressing differs — **speed-up is pressed
when there is nothing to read, pause when there is too much.** ⇒ whether they are separate widgets is
**undecided 4**.

### ⚠ And this button is the door through which the whole design gets undone

**A verbless pause is exactly where "well, while we're stopped, let it turn one boat around" walks in.**
The moment that line lands, decided 1 is dead and this document has become Door Kickers.
⇒ **The pause has no verb. That sentence is the rule.**

### ⇒ Instead the button becomes an instrument — **derived**

**How often the player presses pause is evidence that execution does not read at 1×.** Never pressed, it
costs nothing; pressed constantly, it is not a comfort feature but **a measurement of a legibility fault.**
⚠ **Derived, not measured.** This repo has never once counted that number.

---

## ⚠ This design breaks [planning principle](../planning-principles.md) 1 **on purpose**

> **1. The hand must not idle** — *"time spent watching something roll on automatically makes a game
> frustrating. That one line is the whole reason defence was scrapped."*

**That is the first line of the one five-page document deliberately carried across two resets.** This design
makes **100% of combat time watching**, up from today's 46–72%. **There is nowhere to hide it, so this
section exists.**

### What pays for it — **three candidates, none of them proven**

1. **The hand works before the fight instead of during it.** Today's dead-air figure is a ratio measured
   **inside the island's clock**, and that denominator is combat time. If planning is real work the
   denominator should be **plan + execute**.
   ⚠ **And that fixes the metric, not the problem** — precisely the shape
   [the session loop](session-loop.md)'s adversarial review caught in that document
   (*the metric improves while what it proxies does not*). **Changing the denominator is not evidence**
2. **What principle 1 actually measured was frustration, not actions per second.** Defence was scrapped
   because it was frustrating, not because of an input rate. ⇒ **whether watching a plan you authored is
   the same experience as watching something you did not author is unknown.** This repo has never measured
   that difference
3. **A fight is short** (decided 8, about a minute) **and there is a speed-up.** The dead game's 61% sat on
   top of **150-second gaps**; a 60-second execution at 4× is 15 real seconds.
   ⚠ **But "short is fine" is a sentence this repo has already refuted** —
   [what two dead games left behind](../lessons-from-two-dead-games.md): *dead air is a ratio, so shortening
   the round shrinks numerator and denominator together.* **Shortening does not move the ratio.** This
   candidate only survives if the problem is **absolute time rather than proportion**, and which it is has
   not been decided

### What would tell you it did not pay — **the metric is not deleted without a replacement**

⚠ **"Dead-air ratio" becomes the constant 100% under this design and therefore stops being an instrument.**
**Deleting a metric without standing one up in its place is how a repo starts lying to itself.**
⇒ **Three replacements. All derived; the targets are the user's to set:**

| Replacement | What it measures | Who can measure it |
|---|---|---|
| **Time until maximum speed is pressed** | If maximum speed is pressed at t=0 every fight, **execution is not being watched, it is being endured.** That is principle 1 failing | A person. **A probe never presses the speed-up** |
| **Time spent planning, and actions taken while planning** | If planning takes 3 seconds the hand works **nowhere**, and the 100% bought nothing | ⚠ **A person only.** A bot plans instantly — [the boat and landing](boat-invasion.md)'s *"a probe cannot measure the time a human spends looking"* binds here |
| **Pause press count** | The pause section above — a legibility instrument | A person |

⚠ **All three are human numbers.** ⇒ **This design is not verifiable by probe.** That is a weakness of the
document, not of the probe, and it is the place [planning principles](../planning-principles.md) line two
predicted.

---

## Screens — **fewer glyphs, larger targets**

⚠ **A correction first**: [the session loop](session-loop.md) wrote *"no more than two numbers on screen"*,
and **the user never said two.** What they said is *"글자가 너무 많고 조금 더 단순하게 해줄래? 아니면 좀
UI를 크게 해서"* and nothing else. ⇒ **no number is invented here.**

**Three constraints on every screen:**

1. **A picture before a glyph.** Whatever glyphs remain get counted and written down — there is an
   acceptance row for it
2. **Anything you press is visibly larger than today's HUD key boxes**
3. **No sentences.** Prose belongs in documents

### The planning screen — **in front of the start button**

**This screen is the whole of what the player will ever know.** There is no preview (decided 5) and nowhere
to go back to (decided 4).

| What | How |
|---|---|
| **The whole island** | Fits one screen. **The camera already exists** — [the boat and landing](boat-invasion.md)'s zoom-out holds all of 48×32. ⚠ **It still pulls further back** (decided 20): *"조금 더 카메라를 뒤로 빼야 될"*. The mockups stood on a slice of coast, not on the island |
| **The enemies** | **Visible.** The GDD already decided 「첫 초원은 처음부터 다 보인다」, and its reason — an autobattler with no information makes the loss unreadable — is at its maximum here. ⚠ **Fog is a later node property** and not this round |
| **The placeable region** | Where a boat may be put shows **before** you put it. ⚠ **Where and how large is undecided 7** |
| **The monsters at the launch point** | ⚠ **Bodies, not a widget.** The monsters you own **stand lined up** at the launch point — *"내가 내릴 수 있는 곳 위치에 딱 나서"*. **No queue box, no slots, no count** (decided 16) |
| **Boats** | ⚠ **What you drag is a monster, not a boat.** Drag one onto a landing spot and **the boat carrying that body departs from that moment** — *"끌어서 탁 놓으면은 그때부터 출발하는 거지"*. Boats are unlimited, so they are **not a thing to choose** (decided 18) |
| **Order** | ⚠ **No widget. The sequence of drops IS the order** (decided 17). Whether the screen needs to show it back is open — **the only person who knows the drop order is the one who dropped**, and during execution it reads as *the bodies still standing at the launch point* |
| **Routes** | One line per crossing, launch point to landing. **The whole plan on one page** |
| **Start** | **One large button.** From the moment it is pressed there is nothing to press |

**On screen at the moment of commit**: the island · every enemy · a landing point for every body dropped ·
the bodies still standing at the launch point. **And that is all of it.**

⚠⚠ **Decided 16's "a drop departs from that moment" and decided 2's start button do not join into one
sentence — and nothing is invented to make them.** Both readings survive it: ① **a drop IS that boat's
commit** and the start button only starts the clock · ② everything dropped **leaves on the start button, in
that order**. **Decided 1 (the hand does not move during combat) survives either way** — all it needs is
that nothing can be dropped while the clock runs. ⇒ **undecided 16.**

⚠ **What is *not* there is this design's core risk**: no projected outcome, no projected engagements, no
signal at all about whether the plan is any good.

### The execution screen — **behind the start button**

| What | How |
|---|---|
| **The plan runs as drawn** | The lines drawn while planning become the actual crossings. **A different picture means the plan lied** |
| **Bodies that have not gone yet** | ⚠ **The unspent part of the plan has to stay on screen** — it is exactly the bodies still standing at the launch point. Without it "why has that one not left" is nowhere, and **decided 6's loss becomes an unreadable loss** |
| **What can be pressed** | **The speed control and the pause. Nothing else** (decided 1 · 4 · 8) |
| **The clock** | As today |
| **The twelve pieces of [combat juice](combat-juice.md)** | **All of them live.** Every one is view-side and driven by `Battle.events`, so removing the controls kills none of them |

---

## ⚠⚠ Correction — **why the 1~5 keys were actually deleted** (user, 2026-08-19)

This doc records the reason as *"왜 슬롯을 누르는 거지? 배 때문인가?"* — read as **the slot existed only
because of the boat, so it dies with the boat.** ⚠ **The user says that is not the reason.**

> ***"정확히는 배 속이 별로여서 뻐 거임 1~5번 키"*** (2026-08-19)

⇒ **What was bad was loading soldiers INTO a boat with a number key** — which is exactly what
[the boat and the landing](boat-invasion.md) parked by name (*"병사 태우는 게 숫자 키인 게 좀 별로야"*).
**The slots themselves were never the defect.**

⚠ **This matters because it changes what reviving them costs.** Under this doc's version, bringing the
1~5 keys back reverses a decision. Under the user's own version **there is nothing to reverse** — the keys
were collateral. `idea-inbox` rows 29 and 30. ⚠ **`CLAUDE.md`'s 「키보드는 아무것도 안 한다」 still
describes the shipped tree and stays true until something is built.**

## ⚠⚠ Refutation — **the speed ladder is being deleted, and this doc's metric loses its instrument** (2026-08-19)

The user watched the built game, asked what the `0 1 2 3 6` chips at the bottom right were, and then said:
***"일단 배속 개념은 지워주고, 저거는 아직은 필요 없을 때 추후에 추가해도"***

⇒ **What this doc decided — that the speed control and the pause are the only things that can be pressed
during a fight — becomes: nothing can be pressed at all.** The pause is slot 0 of the same row and has no
widget of its own, so it goes with it unless the user says otherwise.

⚠ **The metric below loses its instrument.** *"Time until maximum speed is pressed"* was this doc's test
for principle 1 — *is execution being watched or endured* — and **after the deletion there is nothing to
press, so the question cannot be asked that way.** It is not answered; it is unmeasurable. **Do not read
its absence as a pass.**

⚠ **`Rules.SPEED_STEPS` stays in the tree**, read by nothing, so restoring this is an edit rather than a
design job. The plan is
`speed-off-open-landing`.
⚠⚠ **Everything below this box describes a feature that is on its way out.** It is kept because the
arithmetic in it — the telegraph floor, and the derived ceiling of 7× — is what the restore has to obey.

## The speed-up — **it is `step(delta × k)` and it is not free**

⚠ **Derived by reading the code. Not measured.**

`battle.gd`'s `_phase_attacks` lets a unit strike **at most once per `step`**, and on a strike it resets the
cooldown to **the whole period** — the overshoot is not carried. ⇒ the real blow-to-blow interval is
`ceil(period / dt) × dt`, **up to one frame longer than the period.**

| At 60 fps | `dt` | Worst-case loss on a 1.0 s period |
|---|---|---|
| 1× | 16.7 ms | **1.7%** |
| 4× | 66.7 ms | **6.7%** |
| 8× | 133 ms | **13%** |

⇒ **The speed-up does not create the fault; it multiplies an existing one by `k`.**
And **the loss is asymmetric** — it scales as `dt/period`, so the bison (period 2.0) loses **half** of what
everything on a 1.0 s period loses. ⇒ **the same plan can win at 1× and lose at 8×.**

⚠ **`CLAUDE.md`'s "where two clocks meet" is exactly this shape.** There is only one clock here, so the five
defects that section names are absent — **but a multiplier produces the same class of error without needing
a second clock.**

### ⇒ And the telegraph sets the ceiling on the speed-up — derived

`rules.gd`'s `LION_WINDUP_SEC` is 0.6 s, and the comment beside it records that **this repo measured a beat
under five frames going entirely unseen.**
At 60 fps, 0.6 s falls to five frames at **`k = 0.6 × 60 / 5 = 7.2`.**

⇒ **Past 7× the lion's telegraph stops being visible.** And that telegraph is the item **the user chose
knowing it costs the boss 29% of its damage** ([combat juice](combat-juice.md)).
⇒ **Derived constraint: maximum speed ≤ 7×, or the telegraph gets a floor of its own for high speeds.**

---

## What this touches in code — **inside the folder contracts**

⚠ **This document writes no code.** Below is the list a plan fills in, and **"dies" and "its meaning dies"
are kept apart** — the second kind is what breaks silently.

### Dies outright — **everything the key dragged with it**

| File | What |
|---|---|
| `src/shell/game.gd` | **The whole of `_on_key`.** `_unhandled_input`'s `InputEventKey` branch empties, and start / pause / speed take its place. **The contract that this is the only file reading `Input` is untouched** |
| `src/view/hud_view.gd` | `KEY_TYPES` · `key_slot_count` · `key_type_of` · `note_key` · `_key_fx` · `_key_offset` · `_key_colour` · `_paint_key` · `reserve_count`. ⚠ `TYPE_LABELS` **survives** — `panel_view` reads it |
| `src/look.gd` | `HUD_KEY_ORIGIN_PX` · `HUD_KEY_SIZE_PX` · `HUD_KEY_GAP_PX` · `HUD_KEY_TEXT_OFFSET_PX` · `key_rect_px` · `KEY_FX_SEC`. ⚠ **`KEY_REFUSE_SHAKE_PX` survives** — `_berth_offset` reads it too, and deleting it kills the berth shake with it |
| `tests/nets/net_shell` | The key-slot check. ⚠ **Correction (measured): losing it costs a lot.** Only the count check measures itself; **eleven other sites index `hs.keys[0]`/`[1]` literally**, so emptying `KEY_TYPES` **crashes the net rather than passing it** — and what disappears with it is `Look.COL_BUTTON` pinned as a literal and **both ends of item 8's refusal-shake bound**, which is exactly the floor-and-ceiling pair `CLAUDE.md` earned the hard way. **Re-pin those elsewhere before deleting the key HUD** |
| [Combat juice](combat-juice.md) item 8 | **Half of it.** The key half dies; **the berth half (`note_launch`) survives and becomes a planning gesture** |

⚠ **`net_draw_leaf`'s per-function table names `_paint_key`.** That scanner is closed against **names the
table does not hold**; a name the table holds that no longer exists is **not the direction it was built to
catch.** ⇒ **invert the instrument** — the exact move this repo named as *invert the instrument, not only
the subject*.

### Its meaning dies — **the quiet half**

| File | What changes | ⚠ Why it is quiet |
|---|---|---|
| `src/sim/battle.gd` `load_soldier` | From an in-combat action to a **planning-time action**. Same domain, same return | **Every old call site stays green.** What becomes wrong is *when it may be called*, and **`battle` knows nothing about a planning phase** ⇒ a net that calls it mid-`step` still passes. **Unless a state forbids it, the rule lives only inside `game.gd` and every other caller breaks it silently** |
| `src/sim/battle.gd` `launch` | From "sails immediately" to **"queued to sail"** | Today a successful `launch` puts the boat at sea on that frame. Planning needs a **placed-but-not-sailing** state, and **there is no such state** |
| `src/sim/battle.gd` `setup` / `step` | **There is no before-the-start state.** `step` straight after `setup` is combat | Without a new state, "planning" exists only as *the shell not calling `step`* — which is a calling habit, not a rule |
| `src/sim/islands.gd` `TIME_LIMITS` | **The clock has to start at the start button, not when the island opens** | The comment beside that constant says *the clock starts when the island OPENS, so waiting for a full boat costs the same as a bad landing.* **Decided 3 deletes that reasoning** — planning is unlimited, so waiting is free. ⇒ **fix the comment and the rule in one edit** |
| `src/sim/run.gd` | `State` gains a planning state | ⇒ see the next row |
| `src/view/panel_view.gd` | — | ⚠⚠ **`panel_active()` is `run.state() != BATTLE`.** Adding a planning state makes it true, every branch of `_message_text()` falls through, and **a red 「패배」 paints over the planning screen.** ⚠ **Correction (measured): nets DO watch it.** `net_shell` drives `panel_active()` from both sides — false during combat, true on the panel — and pins `MSG_LOST` as a literal. **It is not silent**, though the false-side check sits after the start press and could still stay green, so treat it as loud-but-not-guaranteed. ⇒ **Fix as an allowlist (`REWARD or finished`), never a denylist** |
| `src/shell/game.gd` `_process` | `battle.step(delta)` → `battle.step(delta × speed)` | The whole speed-up section above hangs off this one line |
| `tools/probe/run_run.gd` | From summon-and-send mid-fight to **plan, then run** | ⚠ **And the probe cannot measure planning time** — a bot plans instantly |

### What grows

| Folder | What | The contract |
|---|---|---|
| `src/sim/` | **One planning state** — which boat goes where, in what order. **Flat arrays**, `RefCounted`, built with `.new()` | no `Node` · no `_draw` · no `Input` · no `$` |
| `src/sim/rules.gd` | Speed-up steps, and any constant the placement region needs | **Every constant that changes what happens, in one file** |
| `src/view/` | The planning overlay — routes, the bodies at the launch point, the placeable region. ⚠ **No order number is drawn** (the measurement under the acceptance table) | ⚠ **`net_draw_leaf` reddens any function its per-function table does not name.** A new function opens the table in the same edit |
| `src/look.gd` | Every size and colour of the overlay, the start button, the speed widget | **Every presentation constant, one file** |
| `tests/nets/` | The planning state · `step` doing nothing before the commit · the order being honoured · a 1× control for the speed-up · the new leaves | **Under five nets the wrapper refuses the round.** ⚠ **Every row gets a floor as well as a ceiling** |

---

## Inherited findings — **only the ones that survive**

⚠ **Of [the session loop](session-loop.md)'s three adversarial reviews, everything hanging off the summon
key died with the key** (five slots collapsing into one, `load_soldier`'s domain clash, the HUD key boxes
running off screen). **That document's own head records what died.** Below survived, and some got
**more** important.

| Finding | What it means here |
|---|---|
| **A whole run contains 15 kills** — counted from `islands.gd`: island 1 = **4** · island 2 = **6** · island 3 = **5** | ⚠ **It stopped being an economy fact and became a planning fact.** Four enemies on an island means **four things to plan against.** ⇒ the review's economy fix — **30 to 40 enemies an island** — is the same lever that gives the planning screen anything to plan about. **Two problems, one answer** |
| **Ten starting cells cannot win island 1** — 4 bison = 80 HP at 6.0 total DPS; a bare cell is 14 HP at 2.0 DPS ⇒ `14N > 240/N` ⇒ **`N ≥ 5`** | **Dormant.** This document settles no economy, so nothing collides yet. ⚠ **It comes straight back the day a cell economy lands** — do not forget it and re-derive it |
| **The clock does not bind** — twelve controlled runs all won inside half the limit, 46–72% of each island empty | ⚠⚠ **Empty time is now 100% by design and is not a defect. What it stops being is an instrument** — the three replacements above take its place. **And a clock that does not bind means decided 6's loss is effectively a wipe and nothing else**: the time limit is close to decoration, and **`TIME_LIMITS` went to the user as [the boat and landing](boat-invasion.md)'s undecided 15 and was never answered** |
| **`panel_view.panel_active()` is `run.state() != BATTLE`** | See the code table. **This design adds a state, so it walks straight into it** |
| **The only axes that make position a decision are range and area** (the GDD) | ⚠⚠ **At its maximum here.** With zero control after commit, **position is the only decision left**, and [what makes placement a decision](what-makes-placement-a-decision.md) pins that one difference as the reason **TFT and Despot's Game share a rule and land in opposite places.** **Both axes exist in shipped code** — melee (range 0, area 0) and ranged (range 4, area 1). **This design stands on the TFT side by one thread, and the thread is having two soldier types** |
| **The landing point already picks which enemies engage** — soldiers have no detect radius and enemies do (bison 6, crow 12, lion 2) | ⚠ **This is the one hidden rule the planning screen ought to show.** [The boat and landing](boat-invasion.md)'s section 1-A measured it: the structure is real and **nobody pays for it.** ⇒ **whether detect radii are drawn while planning is undecided 6**, and drawing them turns an invisible rule into a readable one |

### ⚠ And the GDD rejected this branch once — **the user has come back to it**

**[The cell army GDD](cell-army-gdd.md)'s controls section wrote this down:**
*"the other branch — commit everything before the fight (first, middle, last) and watch — is deeper as a
decision but leaves the hand idle during combat. The user's own first/middle/last example was on that side,
**but the hotkey summon is what was decided.**"*

⇒ **This document is that branch.** And **it is the side the user originally exampled.**
⚠ **The stated grounds for rejecting it (the hand idles during combat) were not refuted — the user has
chosen to pay them.** What pays them back is the whole "the hand must not idle" section above, and **none of
the three candidates is proven.**

---

## ⇒ The user answered "how does it become losable" (2026-08-18)

**That was the only question the probe section raised, and the answer is three things. The order is part of
the answer.**

| # | Rule | When |
|---|---|---|
| 11 | **More enemies** | **Now.** No rule changes at all — only the rows in `islands.gd` |
| ~~14~~ | ~~**One soldier per boat. Five boats to start**~~ ⚠⚠ **DEAD** — the user reversed it the same day | **Never.** `Rules.BOATS` is not a cap any more — see the box below |
| 12 | **More enemy types** | **Gradually.** Not all at once |
| 13 | **Terrain gets harder** | **Gradually.** Cliffs and ramps already exist; what grows is the use made of them |

### ⚠⚠ Rule 14 is **struck** — the same user reversed it the same day (2026-08-18)

**It is left struck through rather than deleted.** This repo would rather have a document that records its
own reversal than one that reads as if it had always been right.

**Rule 14's whole argument was one line**: **"the boat count becomes the cap on bodies per wave"** ⇒ buying
more bodies cannot land more of them at once, so "wider or stronger" finally becomes an axis, and the
boarding gesture disappears.

**Why it no longer holds — the premise was deleted, not the reasoning.** That line hung entirely on
**boats being finite**, and the user made them **infinite**:
*"배는 너무 곁다리 느낌이다 그냥 바다위에 초록색 지역에 내가 설계한 몬스터들을 무한으로 배를 띄워서
보낼 수 있는걸로하고 싶어"*
⇒ **If the boat count is not the cap, "five boats" stops blocking anything.** Capacity 1 loses its meaning
with it — **whether a hull carries one body or four, an unlimited number of hulls lands the whole roster at
once anyway.**
⇒ **The cap moved off the boat and onto the monsters.** What the player plans is not boats but **the bodies
they own**, and **the boat is plumbing** (decided 18).

⚠ **Rule 14's own problem died with it.** *"Flattening capacity to 1 kills the axis that separated the two
boats (capacity 4/2 at speeds 3.0/5.0, held by the throughput inequality `2×5 = 10 < 4×3 = 12`), so a new
axis is needed"* — **no new axis is needed. Boats no longer have to differ from one another.** The whole
rejected branch is held by
[unlimited boats, not a five-boat cap](unlimited-boats-not-a-five-boat-cap.md).

⚠ **Arithmetic that died with it**: *bare cells need `N ≥ 5` to take island 1 (four bison, 6.0 enemy DPS),
so five boats is exactly the minimum that wins and calling a second wave becomes a real choice.*
**There are no waves any more** — infinite means it all goes at once. That `N ≥ 5` **comes back the day an
economy lands**, as *"how few bodies can you own and still win"*.

> ### ⚠ Measured — the reinforcement period the dead branch carried (kept for the record only)
>
> **A wave was five, and the next landed `2 × steady / boat_speed` later — 3.50 s to 7.28 s on island 1.**
> So under that branch **the ten-body state never existed**, and enemy counts had to be measured against
> *"five now, five more every `2 × steady / boat_speed`"*, never against the roster total.
> ⚠ **Infinite boats deleted that premise.** The round-trip period still exists, because boats still
> round-trip — but **the player can send everything at once, so it is no longer a cap.** This number is
> needed again the day **landing-tile capacity** or **sail time** is picked as the brake.

⚠⚠ **And what rule 14 was buying has still not been bought.** It was **the only item that put a price on
over-sending**, and that place is **empty right now** — "infinite is free" at the top of this document is
that empty place, and **the user deferred it knowingly.**

⚠ **Rule 11 runs straight into the review's arithmetic, and the user chose it knowing that.** The review
measured that *"more of the same enemy adds kills, not plans"* — what adds plans is types whose `range`,
`area` and `detect` differ. **The user's answer does not overturn that arithmetic; it sets an order**:
count first, then types and terrain on top of it.
⇒ **So rule 11 is not "this makes the plan a decision" but "this makes losing possible first."** They are
different claims, and **whether count alone turns the plan into a decision is for the probe to answer** —
what 15/15 becomes is that measurement.

**Rejected branch**: **cut our own side** (a smaller starting roster, or smaller boat capacity).
The cheapest option, but **it does not close the hole where ranged units at reach 5.5 beat the lion from
outside its detect 2.0** — shrinking the roster leaves that intact and just moves the optimum toward
"bring fewer and still win."

---

## Undecided — **cannot be built without picking**

1. ⚠⚠ **What does an object bolt onto now.** Decided 9 **deleted the grounds for five slots** — there were
   five because there are five fingers. The phrase **「배가 칸이 된다」** (*the boat becomes the slot*) was
   used in conversation, and **the user did not confirm it.**
   ⇒ Three candidates: **onto a soldier** (the value before the GDD overturned it) · **onto a boat** ·
   **onto some slot still.** **The whole of [the session loop](session-loop.md)'s arithmetic hangs on this**
2. **What cells buy, and whether the session loop's cost curve survives at all.** With no summon there is
   no summon cost
3. ~~**How many boats, and whether they still differ in capacity and speed.**~~ ✅ **Closed 2026-08-18 by
   decided 18. Unlimited, and identical.** The boat is plumbing, so neither count nor capacity nor speed is
   an object of the plan. ⚠ **What closed is the question, not what the question was holding up** — the cap
   the boat count used to carry moved to "infinite is free" at the top and **is still open there**
4. **Whether pause is a separate widget or the same one at 0×**
5. **Node count, branch shape, and whether there are node kinds beyond the GDD's four**
6. **How much of the enemy is visible while planning.** ✅ The GDD already decided 「첫 초원은 처음부터 다
   보인다」 and **fog is a later node property** — that is carried unchanged.
   ⚠ **What is open is the layer above: whether detect radii are shown.** See the last inherited finding
7. **Where the placement region is and how large.** ⚠ **One already exists in shipped code** —
   `grid.can_land_at(harbour, tile)` picks **38–47** of an island's 76–82 landable tiles. Whether the new
   region is that one or something else is unsettled
8. ~~**Whether the order carries timing.**~~ ✅ **Closed 2026-08-18 by decided 16 and 17.**
   **A drop departs** — *"끌어서 탁 놓으면은 그때부터 출발하는 거지"*. ⇒ the spacing is **made by the hand
   that drops**, not by a rule. And **boats still round-trip** (decided 15), unchanged
9. **When the clock starts** — when the island opens, or when start is pressed. `islands.gd`'s comment says
   the former today and its grounds are gone (see the code table)
10. **The speed-up's multipliers and steps.** The section above derives a **ceiling of 7×**; the steps are
    unsettled
11. ~~**How the order is assigned**~~ ✅ **Closed 2026-08-18 by decided 17. The placing sequence IS the
    order.** No separate handle, and no queue widget — *"대기열이라는 게 사실 좀 애매해."*
12. **Whether a plan can be undone before the commit.** Decided 3 only says you may *put things in* any
    time. **It never says you may take them out or move them.** ⚠ A trap this repo has already named lands
    here — *if undo is free, the choice before it was free too*
13. **The session loop's open items that were not hanging off the summon key** — do cells come back on
    death · do levels attach to the individual or the slot · what the families are · drop frequency · the
    ratio of cells to cost · what a run starts with. **That document holds them and they are not copied
    here**
14. ⚠⚠ **Whether there is a mother ship and what it looks like.** Four mockups were drawn; **variant 2's
    size** was liked but called **too close**, **a big boat from the start is not fun**, and the
    conversation moved to decided 18 without settling it. ⇒ **This round builds on the harbours that
    already exist. Do not invent a mother ship**
15. ⚠⚠ **What the brake is** — "infinite is free" at the top. **Three candidates, and the user deferred it
    until after the thing is built.** ⚠ **This is the only undecided item the user deferred knowingly**;
    the rest are simply unasked
16. **Whether a drop IS the commit, or whether everything dropped leaves together on the start button** —
    the box in the planning-screen section. Decided 16's single sentence does not separate them.
    ⚠ **What was BUILT is ②** (2026-08-18): the drop **creates** the boat, it sits at `t == 0.0`, and
    every boat departs on the **same frame** at the start button. There is no departure-time field at
    all. **That is an assumption, not a choice** — decision 1 survives under both readings and ② needs
    no per-boat state. **If the user picks ①, `send` grows a per-boat departure time — which is the
    same lever the deferred brake would be built from** (「infinite is free」 at the top)

---

## Not this round

- **Variety** — the user parked it themselves (decided 10). **Parked, not solved**
- **The whole cell / object economy** — nothing can be built until undecided 1 is answered
- **The node map and the refit screen** — [the session loop](session-loop.md) holds them, and with only
  three islands authored the map has no islands to offer
- **Artifacts** · **main-loop unlocks** · **fog** · **3D**
- **Mid-crossing redirect** — [the boat and landing](boat-invasion.md) parked it by name, and **decided 1
  now forbids it as a rule**
- **Squad assignment** — `CLAUDE.md` names it as one of the four systems that circled a conversation six
  times without closing. ⇒ **decided 1 closes it too** — with nothing to command after the commit there is
  nothing to assign a squad for

---

## Acceptance — **written so it cannot pass by inference**

⚠ **No row closes on "the round is green", "the effect was built", or "an agent walked through it".**
`CLAUDE.md`: *acceptance is written down when it is heard.*

| What must be true | How it is known | ⚠ What does not pass it |
|---|---|---|
| **The plan reads before the commit** | The user **describes what is about to happen before pressing start, and the description matches what happens.** Open until one or the other is written here | The overlay having been built |
| **Planning takes time** | **A person times the gap from the island opening to start being pressed, and counts the actions in between.** Today's counterpart is "last command at 7.4–12.9 s" | ⚠ **A probe figure.** A bot plans instantly |
| **Execution is watched, not endured** | **Measure when maximum speed gets pressed.** Every fight at t=0 is a failure | ⚠ **Writing "there's a speed-up so it isn't boring."** Nothing is fixed before it is measured |
| **The pause is not needed** | **Count the presses.** Frequent presses mean execution does not read at 1× | "We added a pause" |
| **The speed-up does not change the game** | **Run the same plan at 1× and at maximum and print casualties, outcome and duration side by side** | ⚠ **The arithmetic in the speed-up section.** It is derived, not measured. **If they differ, the rule is wrong, not the multiplier** |
| **Order is a decision** | The user **plans the same island twice in different orders and says why** | The probe producing two different orders — a proxy. ⚠⚠ **And as of today this row cannot pass** — order is inert in the sim (probe section, item 2), so there is no reason to plan it differently. **Order needs a referent before this row can be scored at all** |
| **Glyph count fell** | **Count the glyphs per screen and write the number** | "It looks simpler" |
| **⚠ Final verdict** | **The user does not say "ambiguous" again** (GDD undecided 18) | All seven rows above are proxies |

⚠ **Why the order row cannot pass, measured**: every island is **ONE passable component** (744 · 760 · 716
tiles), so a boat dropping one or two bodies **always** finds a free tile to unload onto. ⇒ landing order
cannot decide *who waits*; it only decides *which of two boats aiming at one tile stands on it* — **at most
1.41 tiles**.
⚠ **That measurement was taken assuming capacity 1, and decided 14's death took the assumption with it.**
**The conclusion gets stronger, not weaker**: on an island with 700-odd free tiles no cargo size the game
can hold makes an unload refuse.
⇒ **Drawing a big order number on screen would be exactly "screen changes but sim doesn't".**

---

## Sources — **and the case against each**

`CLAUDE.md`: *name checkable sources, several that disagree with each other, and give the argument against
your own recommendation.*

| Game | What was borrowed | ⚠ The case against |
|---|---|---|
| **[Door Kickers](https://en.wikipedia.org/wiki/Door_Kickers)** | **Routes, breach points and go-conditions drawn onto a top-down floor plan before execution.** The picture of a planning screen that *is* the game | ⚠⚠ **That game goes back to planning mid-execution** — *"can switch between engagement and planning at any time."* **Decided 4 deletes it.** This design cannot borrow its success |
| **[Frozen Synapse](https://en.wikipedia.org/wiki/Frozen_Synapse)** | **Lay out waypoints, commit, and both sides resolve simultaneously.** A shipped case of zero control after commit | ⚠⚠ **You can simulate the result before committing, and decided 5 deletes that.** And a turn there is **5 seconds** — decided 8's **minute** is twelve times that, **so a wrong plan is endured twelve times as long** |
| **[Despot's Game](https://gamecritics.com/eugene-sax/despots-game-dystopian-army-builder-review/)** | **Compose before the round, zero control.** The only shipped game standing where this design stands | ⚠ **It failed at exactly this spot.** Reviewers named the **absence of player agency**, and the studio shipped an **auto-arrange button** — when placement is not a decision, players ask for placement to be automated |
| **[Bad North](https://bad-north.fandom.com/wiki/Commander)** | **More landing points than squads**, which is what makes "what do I give up" a decision | ⚠ **That game keeps moving squads after the commit.** The developer says he did not remove control but **lowered its granularity** ⇒ **this design's zero control cannot be justified with Bad North** |
| **Clash Royale** | **The real-time-commit branch.** Decided 1 took the other one | ⚠ **The user rejected it, and the reason is recorded: they were worried the game would look like it.** ⚠ **No link** — a user-rejected row, so it carries no weight in this table |

⚠ **Three of the five stand against this design** (Door Kickers · Frozen Synapse · Despot's Game).
**That is the only evidence this table is an honest one, so do not trim it.**

---

## What this document cannot answer

**Whether any of it is fun.** [Planning principles](../planning-principles.md), line two.

⚠ **And one thing on top of that: this design is not verifiable by probe.** All three replacement metrics
are human numbers, and the decisive one — **whether watching your own plan execute is frustrating** — has
no instrument at all.
**The second game died with 25 nets and 3541 green checks.** The tables above are weaker evidence than that.
