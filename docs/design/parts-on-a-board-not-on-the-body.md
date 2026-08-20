# Parts go on a board; the body is the result

**Implemented**: none — not one line of the refit screen exists
**Accepted**: pass (2026-08-20) — **the shape was chosen by looking at three mockups**, not by prose

**One line**: after a fight you take **two of six parts**, and in refit you **lay them into a slot's board
of six cells** — one part per cell — while the assembled body and its numbers stand beside it.

⚠ **This is the MVP.** Everything below that is marked *filled in* was written by the builder side, not
decided by the user, on the user's own instruction: ***"그냥 당연한 건 당연하게 채우자 … 이런 사소한 것까지
내가 하나하나 세밀하게 하는 건 이후에 한다니까. MVP잖아."*** **Each one says what it assumed and what
would overturn it.**

---

## What was decided by the user

| # | Rule | The user's words |
|---|---|---|
| 1 | **The screen is a board of part cells; the body stands beside it as the result** | picked concept C from three mockups |
| 2 | **Two steps** — a slot strip first, press a slot, that slot's board opens | *"처음에 막 칸이 있을 거 아니에요? 그 칸을 누르면 이게 개념 씨에 있는 게 뜨면서"* |
| 3 | **A cell is bound to one part.** Head goes in the head cell and nowhere else | *"머리는 머리 칸만 팔은 팔 칸만"* |
| 4 | **Six parts, on a 3×2 grid** — 머리 · 가슴 · 배 · 팔 · 손 · 다리 | *"일단 6개로 시작해도 될듯"*, and the 7 was 다리 counted twice |
| 5 | **Six cards come up after a fight and you take two** | *"6개중 2택"* |
| 6 | **A part belongs to a species** (포유류 · 조류 · 어류) | *"생명체별 부위"* |
| 7 | **Set effects are OUT this round, and the code leaves room for them** | *"세트는 이후에 추가할 수 있게 확장성있게 코드만 짜줘"* |
| 8 | **Refit shows the whole of a cell's numbers at once — a dashboard** | *"세포별로 공격력, 공격속도, 이속, 방어력, 체력 다 있겠지? 그걸 전체적으로 볼 수 있는 대시보드도 정비할 때 보여줘야겠지"* |

⚠ **Rule 8 arrived late and it is not decoration.** Without it every part a player fits is an invisible
number, and three of the six parts cannot show on the body at all (below).

---

## The MVP, filled in — **what was assumed, and what would overturn it**

**Nothing here was asked.** Each row is the obvious reading; each says what would make it wrong.

| What | Filled in as | Why this is the obvious one | What overturns it |
|---|---|---|---|
| **What a part does** | **It adds to the cell's existing numbers.** Different parts move different numbers | The numbers already exist and combat already reads them. Inventing a second stat system for parts is the "third noun" this repo refuses | A part that changes a *rule* rather than a number (a new attack shape). **Not this round** |
| ⚠⚠ **How that reaches combat** | **The per-soldier lookup that the beak already uses, widened to the rest of the numbers.** `Army.range_of(i)` reads `Rules.range_of(type)` and adds the beak on top; `Battle` calls **that**, not `Rules` | **An earlier draft of this row said combat keeps reading `Rules` unchanged, and that is FALSE.** Every other stat is read as `Rules.damage_of(type)` · `period_of(type)` · `speed_of(type)` · `hp_of(type)` **keyed on the TYPE, not the soldier** — two soldiers of one type cannot differ today. ⇒ **Those call sites move to `Army` lookups.** The beak is the proof the pattern works and the shape to copy | Nothing — this is the only road that keeps `Rules` as the one place constants live |
| **Which numbers** | **The five that exist**: 체력 · 공격력 · 공격주기 · 사거리 · 이동속도 | These are `Rules.UNITS`' own columns and combat reads them today | — |
| ⚠ **방어력** | **Not built.** The user named it; **the shipped tree has no defence column** and damage is applied straight | Adding one changes every damage calculation in the fight — that is a combat change wearing a refit change's clothes | The user asking for it explicitly. **Then it is its own round** |
| **The dashboard** | **The five numbers for the slot being edited, beside the board**, updating as a part lands | Rule 8, read literally. It is also the only way the three invisible parts show at all | — |
| **How many boards** | **One per slot.** Two slots today ⇒ two boards, twelve cells | Rule 2 says a board opens *from a slot*. A shared board would make the slot strip meaningless | — |
| **When refit opens** | **After the reward pick, before the map returns** | `session-loop` already calls refit *"the stretch of time between two nodes"*, and the parts have just arrived | — |
| **Taking a part off** | **Yes, and it returns to the held pile** | A board you cannot undo turns a mis-drop into a dead run, and nothing in the design asks for that | Making a fit permanent as a deliberate cost. **Then say so out loud** — it is a real rule, not a detail |
| **The six cards** | **Random part × random species**, six independent draws | Nothing has ever said otherwise, and any shaping rule is balance work | Duplicates reading as a wasted card. **Measure before fixing** |
| **What 종 does this round** | **Nothing. It is a label on the card and on the fitted part** | Rule 7 removed the only thing species was going to do. **It stays visible because it is where sets attach** | Rule 7 coming back |
| **머리 · 가슴 · 배 on the body** | **They do not appear on the body. They appear in the dashboard** | Rule 8 is what makes this survivable — see the box below | Giving them a protruding form. **A drawing decision, and it can land later without moving any rule** |
| **Cost** | **Not this round.** The mockups drew a cost number; nothing has ever set one | `session-loop`'s object economy is refuted twice over and **has no replacement yet.** Shipping a number nobody derived is worse than shipping none | The economy being redone |

> ### ⚠⚠ Adversarial pass on the rows above — **three of them are load-bearing and one is a real risk**
>
> - **⚠⚠ "This round does not touch combat" was wrong and is now corrected.** Combat reads every stat off
>   the **type**, so a fitted part cannot reach it without moving those reads to per-soldier lookups on
>   `Army`. **That is a change inside `battle.gd`, and it is the largest single piece of work in the
>   round** — larger than either new screen. It is also low-risk, because **the beak already did exactly
>   this for range** and the pattern is sitting in the tree to copy.
> - **⚠⚠ A fitted part must reach the soldier, and parts are fitted to a SLOT.** A soldier summoned from
>   slot 1 has to carry slot 1's board with it, which means **the roster gains a per-soldier record of
>   where it came from.** ⇒ **And that is where permadeath quietly changes shape**: a soldier dies and
>   its parts die with it, **but the board does not** — the next soldier out of that slot arrives with
>   the same parts. **This is a direct consequence of the user's own 「슬롯 자체를 강화하는거임」**, and
>   [summon on the sea](sea-summon.md) already named it: *a body's upgrade dies with the body and a
>   slot's upgrade does not — which is the axis that made the object economy interesting.* **It is not a
>   bug and it is not new; it is the price of upgrading slots, and it is written here so nobody
>   rediscovers it as one.**
> - **⚠⚠ The round DOES contain a decision, and an earlier reading of this doc missed it.** With two
>   slots, taking two parts is followed by **which board they go on** — deepening the melee cell or the
>   ranged one. **That is a real fork and it exists from the first fight.** ⇒ The claim below is narrower
>   than it first reads: *the board* has no decision in it, but *the pair of boards* does.
> - **The dashboard is now carrying the invisible-parts problem alone.** 머리 · 가슴 · 배 are surface on a
>   top-down body — the measurement that turned a generated lion into an orange square
>   ([the body is an outline](the-body-is-a-line-drawn-by-code.md)). **Rule 8 means fitting one still
>   shows something**, so the standing rule *「every rule that changes state has something on screen」*
>   is satisfied by the number moving. ⚠ **But it is satisfied by a NUMBER, not by the creature**, and
>   `session-loop`'s decided 5 asks for *「a cell became a creature」*. **Half of that is unmet this round
>   and it is unmet on purpose.**
> - **⚠ The real risk: this round has no decision in it.** With one part per cell and no set and no cost,
>   the board asks 「did you collect it」 and nothing else. **The pick of two out of six is the only
>   choice in the loop**, and it is a choice between numbers with no board-level consequence. See the
>   deferred box below — **this is known, it is the price of seeing the screen turn first, and it must
>   not be discovered later as a surprise.**

---

## What wasn't chosen

| Rejected | Why |
|---|---|
| **A — parts attach to the body itself** | **Strongest on continuity** — the silhouette built here is literally the one that lands on the island. **Lost on the art ceiling**: every part is a protruding line with nowhere to become a picture. The user's reason for C was exactly this: *"추후에는 조금 더 재밌게 그려질 수도 있을 거 같아서"* |
| **B — six labelled rows beside the body** | **Strongest on legibility** — the clearest sets of the three. **Lost on two counts**: six rows is six lines of text (「글자가 너무 많다」 is a verdict already taken), and it reads as *choosing* rather than *building* |
| **A paperdoll layout** (head up, legs down, arms out) | **Recommended by the builder side and withdrawn on a measurement.** A paperdoll presumes a **front-facing** body; **this game's body is seen from above**, so head-up/legs-down is the wrong viewpoint — the same problem that erased a lion's mane. Two more: a grid makes adjacency self-evident the day multi-cell occupancy returns, and adding a part costs a row instead of a re-layout |

⚠ **Do not re-derive A and B.** Both were drawn, both were looked at, and the fork closed on looking.

---

## ⚠⚠ A cell is bound to a part — **and what that costs this round**

**Two rules were decided together, and the second one left again.**

1. **A cell is bound to one part.** Head goes in the head cell and nowhere else
2. ~~**One object may occupy more than one cell.**~~ ⏸ **DEFERRED by the user the same day** —
   *"저 한 부위가 두 칸을 먹는 거는 뒤로 빼줘. 지금 당장 할 건 아닌 거 같아."* **Deferred, not refuted**

**Why rule 2 mattered, kept here so it does not have to be re-derived.** Rule 1 alone empties the board of
decisions: a part has exactly one legal cell, so 「where do I put it」 has one answer. Rule 2 replaced that
question with **「what do I give up」** — a two-cell arm is paid for with the hand.

⚠⚠ **And it was the first mechanism in this repo that escapes [the session loop](session-loop.md)'s two
self-refutations without new arithmetic.** That doc killed its own object economy twice — a **linear** cost
makes one extreme strictly dominant; a **convex** cost yields a single interior optimum, a calculation
rather than a decision. **Both are results about a cost CURVE.** Occupancy is not a curve — it is a fixed
number of cells and parts with sizes, a **knapsack** — and neither result touches it. ⇒ **Whoever brings
rule 2 back must not reach for `c(k)` and `p(k)`; they are about a different object.**

> ### What deferring it costs — **written down before it is felt**
>
> **This round's board asks 「did you collect it」 and nothing else.** The set is off, the cost is off, and
> placement has one answer. ⇒ **The round cannot be judged on whether the board is interesting**, and a
> flat first look is not a verdict on concept C.
>
> **Building the screen before the rule that fills it is the right order** — the standing rule here is the
> big loop first, and the refit screen has never once been on screen.
>
> ⚠ **The failure to guard against is the inverse**: a screen that turns, is accepted as "done", and never
> gets the rule that made it worth pressing. [What two dead games left
> behind](../lessons-from-two-dead-games.md) is thirty-four shipped features and no fun moment in eight
> months. ⇒ **When the board later reads as flat, the answer is rule 2 — not a new system.**

---

## ⚠⚠ What this overturns elsewhere — **found by cross-reading, not by the author**

**Four live documents say something this one contradicts. None of them knew.**

| Doc | What it says | What this doc does to it |
|---|---|---|
| **[The GDD](cell-army-gdd.md)** | *"Give them together on one island and picking an island stops being a decision — every path hands you everything. Split them and every fork in the map asks which one you are short of right now."* A combat island pays **exactly one axis** | ⚠⚠ **Overturned by the user, 2026-08-20, and replaced with a different job for a fork.** Every fight pays the same six cards, so there is no cells-node and object-node to be short of — **and the user does not want one**: *"갈림길은 일단 그 노드가 뭔지 표시해 주는 거거든. 뭐 상점이라든지 몬스터라든지 엘리트라든지."* **A fork shows what the node IS, not which axis it pays.** ⇒ **This round every node is a fight node and the forks are thin on purpose**; they thicken when node types arrive. ⚠ **상점 is a new type the GDD's four do not contain** |
| **[The title and the map](title-and-map.md)** | Floor 4 is a **chest node with no fight**, paying one of four artifacts; the shipped node table carries chest · heal · beak rewards | ⚠⚠ **Overturned the same way — 「전부 다 monster 노드」.** The chest leaves this round along with artifacts, and **every node on the map opens a fight.** ⚠ **That doc's HP schedule was derived with the chest in it**, and its own refutation box already found the cells–beak–beak route arriving at the boss below the wipe threshold. **Removing the chest does not fix that; it removes the node the fix was going to live on.** ⇒ **The recovery route is open and it is now more open than it was** |
| **[The session loop](session-loop.md)** | Refit is **five slots**, an object is **dragged** onto one, and *"exactly two numbers reach the screen"* | **Superseded on all three.** Two slots (the tree shipped two), a 3×2 board, and **a five-number dashboard the user asked for by name.** ⚠ **Decided 8 (「글자가 너무 많고 조금 더 단순하게」) is the rule the dashboard strains** — the user overturned their own constraint deliberately, and that is why it is quoted in rule 8 above |
| **[The session loop](session-loop.md)** again | The object economy — every object makes a slot dearer, with two self-refutations | **Untouched and unreplaced.** Sets are off, cost is off, occupancy is deferred. ⇒ **There is no object economy in this round at all**, which is stated rather than hidden |
| **[The title and the map](title-and-map.md)** | The chest pays **one of four artifacts** | **Not a contradiction — a different node.** ⚠ **But the run now holds two different pick widths** (six-take-two at fights, four-take-one at the chest) **and two different card screens.** Building one and reusing it for the other is the cheap road and nobody has said whether they are the same screen |
| **[Summon on the sea](sea-summon.md)** | *"a body's upgrade dies with the body and a slot's upgrade does not — which is the axis that made the object economy interesting"* | **Confirmed, not contradicted.** This doc now says it out loud in the adversarial box above |

## What's tied to it

- **The slot strip.** Slots are `Rules.SUMMON_SLOTS`, two of them today, and **nothing in the shipped tree
  draws them as a screen.** The two-step navigation makes that strip the entry point
- **The reward screen in front of it** — six cards, take two, each carrying a part and a species. **It is
  new too**; today a reward is applied on the spot or picks a soldier for the beak
- **`Rules.UNITS` is where the numbers live.** A board changes what a cell's numbers come out as, and
  **combat keeps reading `Rules` unchanged** — that is what keeps this round out of the fight
- **「six things sticking out of one small square is all that reads」** — the same measurement the six lands
  on rather than against
- **The permanent layer sits above this**: 세포연구소 with effects like *포유류 공속 +10*. It is permitted
  by a standing reversal (*"숫자도 올리고 둘 다 할 듯"*), and **two conditions survived that reversal** —
  a research tree as its own system was never approved, and **run one must be worth playing with zero
  unlocks.** ⇒ **Not this round**

---

## Still open — **and only these**

| # | Question | Why it is not filled in |
|---|---|---|
| ~~0~~ | ~~**If every fight pays the same six cards, what does a fork in the map ask?**~~ | ✅ **Closed by the user, 2026-08-20 — a fork shows what the node IS, and this round every node is a fight.** Forks are thin on purpose until 상점 · 엘리트 arrive. See the overturn table above |
| ⚠ **0b** | **Where does a beaten-up army recover, now that the chest is gone?** | **Not a new question — an old one that lost its answer.** `title-and-map`'s own arithmetic already had a route reaching the boss below the wipe threshold, and the three answers it listed were an HP-raising artifact, refit, or accepting that the route loses. **Artifacts and the chest both leave this round**, so two of the three are gone. ⇒ **Filled in as: ship it and measure.** The run is three short fights, the old arithmetic was derived with grids that do not exist yet, and **putting in a recovery rule before the wipe is observed is inventing a fix for a number nobody has taken.** ⚠ **The probe must actually be run** — if a route wipes, this row is the reason and the answer is one of the three above, not a new system |
| 1 | **What each of the six parts actually moves, and by how much** | **Balance, and it needs the screen to exist first.** The shape is settled (a part adds to the five numbers); the table is tuning |
| 2 | **Does 종 match as a second set axis when sets return?** | The user leaned toward yes twice and stopped short. **Deferred with sets** |
| 3 | **What a set pays** | Deferred with sets |
| 4 | **Whether 머리 · 가슴 · 배 get a protruding form** | A drawing decision that can land later without moving a rule |

⏸ **Deferred with rule 2, kept so they are not re-invented**: which cells one object may occupy, and
whether an eaten cell is blocked or lost.

---

## Sources — and the case against each

- **[Draft and Graft](https://xenozane.itch.io/draft-and-graft)** — an autobattler built on buying mutated
  limbs; arms lean offensive, legs utility, eyes the outlier. **Against**: a small itch.io title with no
  evidence its economy holds over a long run
- **[Diablo's paperdoll](https://www.diablowiki.net/Paper_doll)** — the body-shaped equipment screen, and
  its inventory settled into one window holding the doll, the grid and the stats together after many
  iterations. **Against**: it presumes a front-facing figure, which is why it was rejected here — **but
  the third part of that window is exactly the dashboard rule 8 asks for**
- **[Monster Hunter World](https://steamcommunity.com/app/1446780/discussions/0/3757723993435967012/)** —
  set bonuses large enough to matter, and players report builds collapsing onto them. **Against**: MH
  armour has far more pieces than six cells; the collapse may be a scale effect
- **[Albion Online](https://forum.albiononline.com/index.php/Thread/112909-Full-Set-Bonus/)** — a recurring
  argument that full-set bonuses narrow build space. **Against**: forum argument is not measurement, and
  a PvP gear economy is not a roguelike run economy
- **The opposite school** — no set bonuses at all, each piece distinct, so mixing is never a loss.
  **Against**: it removes the thing the user asked for (*"세트효과가 있어서 고민해야할듯"*)

## Conditions to reopen

The parts getting their real art and **the board reading as an inventory rather than a creature** — that is
the failure mode C buys its advantage against, and the one to watch for.
