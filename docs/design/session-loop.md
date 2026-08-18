# The session loop — you design the number keys

**Implemented**: none. **Not one line in `src/` was written for this document.**
**Accepted**: the ten rules under "What is decided" were **said by the user directly, 2026-08-18.**
**Nobody has seen a screen or checked a number — `unseen`.**

> ## ⚠⚠ **Half of this document is dead — the part loop was replaced** (user, 2026-08-18, later the same day)
>
> **This document left the part loop as built and tried to build what sits above and below it. Later that
> same day the user replaced the part loop itself** — **the hand does not move during combat**, and the
> whole plan is finished in front of the start button.
> ⇒ **The rules live in [plan it, then watch it](plan-then-watch.md). Read this box before anything below.**
>
> ⚠ **The single biggest thing**: the user asked directly — *"근데 칸을 왜 눌러? 이거 배 때문에 칸 누르는
> 거 맞아?"* (*"why am I pressing a slot at all? is it because of the boat?"*). **The answer was yes, and the
> 1~5 summon keys went with it.** There were five slots because there are five fingers, and **there is no
> finger left to press.**
>
> | What this document holds | Today |
> |---|---|
> | **The one line, "you design the number keys"** | ⚠ **Half survives.** "You design" lives; **"the number keys" is dead.** What an object bolts onto now is undecided 1 of [plan it, then watch it](plan-then-watch.md) |
> | **Decided 3, second half** — *"pressing the key in combat summons"* | **Dead.** Nothing is pressed during combat |
> | **Decided 3, first half** — *"you fit objects into slots during refit"* | **Alive.** Only what they fit *into* has reopened |
> | **Decided 10, "the boat is not fixed"** | ⚠⚠ **Reversed. The boat is now the centre of the game** — the plan *is* where the boats go and in what order |
> | **The whole arithmetic section** (`p/c` · `C/c(k)` · convex cost · families · scarcity) | ⚠ **Its referents are gone** — with no summon there is no summon count and no summon cost. **The shape of the argument survives** (linear is not a decision · one interior optimum is a calculation · the advantage and its cost in the same sentence) **and every variable has to be re-attached.** Re-read after undecided 1 is answered |
> | **The screens section, "the `1`–`5` bar in combat"** | **Dead.** The only things pressable in combat are the speed control and the pause |
> | **The screens section, refit and evolution** | **Alive.** The gesture is a drag and it happens **outside** combat, so decided 1 does not touch it |
> | **The code table's `hud_view` and `game.gd` rows** | **Their meaning changed.** Not "`1`–`5` map to slots" but **the keys die outright.** The file-by-file list belongs to [plan it, then watch it](plan-then-watch.md) |
> | **Undecided 3, "do cells grow during combat"** | ⚠ **Its stakes are gone.** Its stated grounds were *"yes and the hands keep working"*, and **decided 1 settles that the hand does not move either way** |
> | **Undecided 9, "per summon or a design-time cap"** | **Half dead.** "Per summon" is gone; **only the design-time cap remains** |
> | **Undecided 10, "does capacity count bodies or cost"** | ~~⚠ Alive and sharper~~ ⚠⚠ **VOID as of 결정 14R (2026-08-18, later still).** **Boats are unlimited and free, one soldier each, created by a drag** — there is no capacity to count anything in. `Rules.BOATS`, `boat_count`, `cap_of` and `boat_speed_of` are deleted from the code and `battle.load_soldier` with them. **The scarce thing is the roster, not a seat.** See `plan-then-watch` |
>
> **What died and what survived out of the adversarial-review box below:**
>
> | Review item | Today |
> |---|---|
> | ① **The five slots collapse into one** | **Void.** There is nothing to press repeatedly |
> | ② **`load_soldier`'s new meaning overlaps its old domain (49 call sites)** | **Void twice over.** The domain was unchanged, and then **`load_soldier` was DELETED outright** — `battle.send(soldier_id, tile)` replaced it, and `battle` now owns the planning phase as a commit gate inside `step()`. [Plan it, then watch it](plan-then-watch.md) |
> | ② **The five slots have no screen coordinates** · **slot indices leak into the type table** · **`net_shell`'s self-measuring check** | **All void.** There are no slots and no keys |
> | ② **`panel_view` paints a red 「패배」 over the new screens** | ⚠⚠ **Alive and more important.** The new design also adds a `run` state |
> | ① **A whole run contains 15 kills** | ⚠ **Alive, and it means something else** — not the grain of the economy but **the number of things there are to plan against.** Four enemies on an island is four |
> | ① **Ten starting cells cannot win island 1** | **Alive, dormant** — the new document settles no economy, so nothing collides yet, **and it returns intact the day one lands** |
> | ① **The dead-air acceptance row passes a change that makes the game worse** | ⚠ **The shape survives.** The row itself goes, because the metric becomes a constant 100%, and **the new document stands up three replacements** |
> | ① **the closed form for `k*`** · ① **`p/c` is the wrong objective** · ① **the scarcity inequality's units** | **Deferred behind undecided 1.** Not refuted — **there is nothing to apply them to yet** |

> ## ⚠⚠ Three adversarial reviews ran, and the verdict is **"not buildable as written"** (2026-08-18)
>
> **Arithmetic · buildability · document integrity**, three independent lenses. **Do not build anything
> below this box before reading it.** What was fixed says so; **what needs a decision was left alone** —
> that is the user's call, not a doc's.
>
> ### ① Arithmetic — "sound inside its own model, and unanswerable at the numbers given"
>
> - ⚠⚠ **The five slots collapse into one.** The wallet `C` is shared and **there is no per-slot limit**,
>   so the optimum is to press whichever slot has the highest `p/c`, forever. **The arithmetic gives no
>   reason to ever press the second-best slot.**
>   ⇒ **And this document deletes the only per-slot quota the code has today** — `load_soldier` draws from
>   `army.living_ids_of_type`, so `1` can be pressed `START_MELEE` = 6 times and `2` four times.
>   **The roster *was* the quota**, and swapping it for one fungible resource removes it.
>   ⇒ **This is a missing rule, not a tuning fault.** Three candidates — a per-slot cooldown, a per-slot
>   living cap, "only as many as you hold objects for". **None of the three is in this document.**
>   That is undecided item 9.
>   ⚠ Inverting the instrument: step 4(a)'s axis argument survives — island 3 has a crow (range 3) and a
>   lion (area 1.5) together, so **two** templates are genuinely needed. **Two, not five.**
> - **The interior optimum does not move under tuning — there is a closed form.** With `r = p₀/Δp` and
>   `s = c₀/Δc`: **`k* = −r + √(r² − r + 2s)`** (checked against integer argmax and brute force over eight
>   combinations). At `p₀ = Δp = 1`, moving `k*` from 2 to 4 needs **`c₀` to go from 4 to 12.**
>   ⇒ Worse than step 3's own confession that the answer repeats every refit: **the answer survives tuning
>   too.** Convex cost succeeds at killing both ends and **structurally fails at moving the optimum.**
> - ⚠ **`p/c` is the wrong objective.** HP is absent from the model and area damage is invisible to it.
>   The lion's area 1.5 covers the diagonal 1.414, so all eight neighbours are inside — up to **36 damage a
>   swing**. Over 100 cells: **if objects give no HP, spreading wins; if they do, stacking survives 29%
>   longer. The sign flips.**
>   ⇒ **"Does an object also give HP" has no entry in this document at all.** The GDD's parked candidate is
>   the oldest form of that question.
>   ⇒ And step 4(a) says *"`p(k)` is not a scalar"* while the acceptance row cites the scalar table from
>   step 2. **Both cannot be load-bearing.**
> - ⚠⚠ **A whole run contains 15 kills.** Counted straight out of `islands.gd`: island 1 = **4** ·
>   island 2 = **6** · island 3 = **5**. ⇒ **Fifteen payment events, so the grain of the resource is the
>   grain of the decision.** Make cells-per-kill tight and summoning becomes impossible and the island times
>   out; make it workable and the wallet is never empty. **The cause is not the rate, it is the 15.**
>   ⇒ The fix is level design, not a rule — **30 to 40 enemies an island**. ~~which would tighten the clock
>   at the same time~~ ⚠ **that clause went false on 2026-08-18** — the probe measured 15/15 wins with the
>   worst plan at 49% of the limit, so **the clock never bound in the first place.** See `plan-then-watch`.
> - ⚠ **Ten starting cells cannot win island 1.** Four bison = 80 enemy HP at 6.0 total DPS; a bare cell is
>   14 HP at 2.0 DPS ⇒ `14N > 240/N` ⇒ **`N ≥ 5`** (`N` = 4 loses, 56 pool against 60 damage). **That is 20
>   cells at `c₀` = 4, or 35 at `k` = 2.** The GDD's "start with ten cells" is **not an open question — it is
>   already in conflict with the derived cost.** Side finding: `N` = 5 clears in **8 s** against a 60 s
>   limit, so the clock fails to bind without needing the probe.
> - **The scarcity inequality compares two different units.** The left side counts **drops**; the right side
>   (`slots × threshold`) counts **distinct** objects per slot, and nothing says what a duplicate does. With
>   4 families × 3 members and 10 uniform drops, inclusion–exclusion gives **0.69 families completed on
>   average, and 47% of runs open no family at all.** ⇒ the same failure as *"a run that missed never saw a
>   single card, and nothing told it why"*. **Undecided 11 asks the frequency and not the distribution.**
> - ✅ **Fixed — 6.8% came out of neither denominator.** See below step 4.
> - **Undecided 10's own proposal fails on its own numbers.** `Rules.BOATS` is 4 and 2; at `c₀` = 4 the big
>   boat carries **one bare cell** and the fast boat **carries nothing**. Rescaling does not help: capacity
>   `Q` sets the maximum `k` via `c(k) ≤ Q`, so **`Q < c(threshold)` means a soldier who completed a family
>   cannot board.** Capacity and the family threshold are two numbers that do not know about each other.
> - ⚠ **The dead-air acceptance row passes on a change that makes the game worse.** If undecided 3 is
>   "cells accrue during combat", income comes from kills and kills cluster at the end of a fight, so **the
>   last-command timestamp improves while those commands land after the fight is already decided.** And the
>   hand does *less*: island 1 takes 12 actions today, and under this document only **5** summons are
>   affordable before the fight resolves. ⇒ **The metric improves while what it proxies does not — a fake
>   net, inside a design document.**
>
> ### ② Buildability — 9 blockers, 8 silent breakages
>
> - ⚠⚠ **`load_soldier(int)`'s new meaning overlaps its old domain exactly.** Type ids are `0..4`; slots are
>   `0..4`. ⇒ **49 call sites** (`net_boat` 31 · `net_battle` 4 · `net_fx_view` 6 · `net_fx` 2 ·
>   `net_shell` 2 · the probe 3 · `game.gd` 3) **stay green with only their labels false, and exactly one
>   line reddens — which reads as "just one line to fix."** The most expensive item on the list.
> - **Undecided 1 blocks this document's own central feature — a circle.** The code table says *"do not
>   touch `army.gd` until undecided 1 is answered"*, and **summoning by definition appends a row to
>   `army`.** `battle.gd` sizes **six** parallel soldier arrays once, at `setup`; summoning mid-combat has
>   to grow all six.
> - **There is no column to carry a slot's silhouette into combat.** `field_view` draws a body **only** from
>   `army.type_id[i]`, and none of `army`'s four columns records which slot a soldier came from.
> - ⚠ **The five slots have no screen coordinates that exist.** `HUD_KEY_ORIGIN_PX` is y = 640 and the
>   stride is 32, so the slots land at 640 · 672 · 704 · 736 · 768 against a **720** viewport ⇒ **slot 2 is
>   clipped by 10 px and slots 3 and 4 are off screen** — before decision 8's "bigger than today" is applied
>   at all. (Verified directly.)
> - ⚠ **`panel_view` paints a red 「패배」 over the map and refit screens.** `panel_active()` is
>   `run.state() != BATTLE`, so adding `MAP`/`REFIT` makes it true, and every branch of `_message_text()`
>   falls through to **`MSG_LOST` with `COL_LOSE`.** ⚠ **Corrected 2026-08-18: `net_shell` does watch it** — it drives `panel_active()` from both sides and pins `MSG_LOST` literally. **Not silent.** See `plan-then-watch`.
> - **Screen constraint 1 contradicts itself inside its own section.** *"No more than two numbers"*, then a
>   refit table drawing **six** (five slot costs plus the cell count), then a conclusion reading *"exactly
>   two numbers reach the screen."* Present identically in both twins.
> - **Slot indices leak into the type table.** `TYPE_LABELS` has five entries, so **slots 2, 3 and 4 come
>   out as bison, crow and lion** with correct names and correct bodies. Nothing range-checks.
> - **`net_shell`'s key-slot check derives both sides from `KEY_TYPES.size()`** — it measures itself, so at
>   five slots it stays green with a false label. (Verified directly.)
> - Also: a summon that only `resize`s `soldier_state` inherits `RESERVE == 0` and **inflates the HUD's
>   reserve count**; the beak roster **truncates silently at 14** (with a comment guaranteeing the cap "never
>   bites"); and a summon that bypasses the boat **skips tile reservation, so two bodies share a tile.**
> - ✅ **Not one folder contract is violated.** `net_draw_leaf`'s five literals redden **loudly**.
> - **Sizing: this is three plans, not one.** The recommended first slice is **(cell wallet + five slots +
>   summoning) + (refit screen + objects + families), minus family *abilities*.** The node map goes last —
>   with only three islands authored, the map has no islands to offer.
>
> ### ③ Document integrity
>
> - ✅ **The overturned "a part bolts onto a soldier / the path is the build" was still live in eight
>   places, and all eight are fixed** — two rows of each GDD twin's decided table, three rows of the screen
>   table, the casualty-rate paragraph, the adversarial-review box, the elite reward row, plus
>   `design/README` and `CLAUDE.md`'s one-line summary. **The refutation had landed in exactly one place.**
> - ✅ **One twin divergence fixed.** Only the English said *"walks off the boat"* — and **that violated
>   undecided 10**, which leaves open whether a summon passes through a boat at all.
> - ⚠ **The screen section carries no "derived" marker.** The arithmetic section says *"every number below
>   is derived and none of it is measured"*; the screen section does not. **"No more than two numbers on
>   screen" — the user never said two.** What they said was *"there are too many glyphs."*
> - ⚠ **"A ten-node map" carries a conclusion.** Undecided 8 says the node count is unsettled, and step 5
>   puts ten in and returns a verdict of **"it binds." At twelve it does not.**
> - ⚠ **Five of the decided table's ten rows (1 · 2 · 5 · 7 · 9) carry no user quote**, under a heading that
>   says all ten were said by the user. **Rows 1 and 9 carry the weight of the entire arithmetic section** —
>   they need confirming.
> - **Calling the refit gesture a "drag" collides with decision 10.** Its stated grounds are *"the boat
>   already taught this gesture"*, and the boat is not fixed.
> - ✅ Only the Clash Royale line lacks a link; the other five sources check out, links and counter-cases.
> - ✅ Zero citation-shape violations · zero re-raised refutations · every item in `gdd-audit`'s refuted list
>   checked against.

**One line**

> **You design the five number keys.**

The user's own phrase: *"한 칸을, 숫자 칸을 설계하는 느낌"* (*"it should feel like designing a slot — a
number slot"*). Eating monsters yields **cells**; **objects** drop occasionally. Between nodes you fit
those objects into ~~slots `1`–`5`, and pressing a number during combat **summons a soldier built to that
slot's template, spending cells.**~~

⚠ **The struck half died the same day** — see the refutation box above. **Fitting survives; pressing during
combat is gone.** What they are fitted into is undecided 1 of [plan it, then watch it](plan-then-watch.md).

---

## Why this document exists

The user played the [boat and landing](boat-invasion.md) round and said:
*"참 애매하네. 그래도 그동안 중에서 제일 평범하네."* (*"really ambiguous — still the most ordinary of them
so far."*)

**Diagnosis: the part loop (one island, real-time combat) is built and everything above and below it is
missing.** No map, no time between rounds, no way for the player to build anything. The only build decision
the [cell army GDD](cell-army-gdd.md) had was *who to bolt a specialty onto*, and **that document's own
adversarial review already refuted it as a decision.**

⇒ **This document is an attempt at GDD undecided 18 ("ambiguous").** ⚠ **An attempt, not an answer** —
[planning principles](../planning-principles.md), line two, still binds.

---

## The three loops — **the user renamed them (2026-08-18)**

⚠ **The GDD said "meta · session · main". The user used different names, the user's names win, and
both GDD twins have been edited to match.**

| Name | What | This doc |
|---|---|---|
| **Main loop** | **Outermost.** Runs repeat; you die or clear, carry something out, and the next run starts on top of it | not covered |
| **Session loop** | **One run.** map → node → **refit** → map → … → boss | ✅ **this document** |
| **Part loop** | **One island.** land → auto-battle → win or lose | ~~already built~~ ⚠ **replaced the same day** — [plan it, then watch it](plan-then-watch.md) replaces how that loop is played |

⚠ **An earlier diagram had the session loop containing the main loop and the user said it was wrong.**
Outside in, it is **main → session → part.**

```
[main loop]
   └─ [session loop]  map → pick one node → [part loop] → cells + objects → refit → map → … → boss
                                                ↓ lose
                                             run over
```

---

## What is decided — **all of it said by the user, 2026-08-18**

| # | Rule | The user's words |
|---|---|---|
| 1 | **Eating grows cells, not soldiers.** A monster eaten yields **cells**, one fungible resource | user's decision |
| 2 | **Objects drop occasionally.** These are the parts | user's decision |
| 3 | **You design slots `1`–`5`.** In refit you fit objects into slots; ~~in combat the key summons a soldier built to that template and **spends cells**~~ ⚠ **the second half died the same day** — see the refutation box | *"한 칸을, 숫자 칸을 설계하는 느낌."* |
| 4 | **There is a cost, and every object bolted onto a slot makes that slot more expensive** | *"전체 코스트가 있어서 특정 세포들을 사용하면은 코스트가 더 되는 거지. 특정 특산물을 붙일 때마다."* |
| 5 | **It has to read as a cell evolving into a creature.** Plain bolting-on is *"조금 단순하다"* (*a bit simple*) | user's decision |
| 6 | **A node map, Slay the Spire style** | *"두 줄로 떠서 양쪽에서 하나씩 선택하는"* (*two rows come up and you pick one from each side*) |
| 7 | **Refit is the stretch of time between two nodes** | user's decision |
| 8 | **There are far too many glyphs on screen.** Simpler and bigger | *"글자가 너무 많고 조금 더 단순하게 해줄래? 아니면 좀 UI를 크게 해서"* |
| 9 | **Variety comes from combination, not from a longer list.** Collecting different objects of one family unlocks an ability for that whole family | adopted after seeing Despot's Game do it |
| 10 | ~~**The boat is not fixed**~~ ⚠⚠ **Reversed (user, 2026-08-18, later the same day)** — **the boat is now the centre of the game.** [Plan it, then watch it](plan-then-watch.md) | *"배 부분은 바꾸긴 할 거야. 얘 픽스는 아니야."* |

⚠ ~~**Rule 3 adds no control at all.** **The `1`–`5` hotkeys already exist in the shipped game** — they
currently carry two soldier types. This document **gives them a meaning**; it does not add a key or a
gesture.~~ **Void — those keys were deleted.** See the refutation box.

⚠ ~~**What rule 10 binds here**: **this document does not depend on the boat's current shape.** Nothing in
refit, cells, slots or the map assumes capacities of 4 and 2, or drag-to-send. **The two touch in exactly
one place — how a summoned soldier gets onto the island** — and that place is undecided item 10 below.~~
**Reversed.** With the boat at the centre, **they touch across the whole part loop, not in one place.**

---

## ⚠ This weakens the GDD's one line — **stated, not hidden**

The GDD's one line is **「먹을 것을 고르러 간다」** (*going out to pick what to eat*), and its Bad North
table says the whole differentiation **rests on the verb "eat."** What that line actually meant was
**"what you ate becomes the build" — the path is the build.**

**The user rejected it**: *"먹은 걸로 빌드를 짜게 되면 중반 후반에 레벨 디자인을 하기가 어려워서."*
(*"if the build comes from what you ate, level design gets hard in the mid and late game."*)

| The GDD's claim | After this document |
|---|---|
| **"The path is the build"** (the upgrade row of the Bad North table) | **Dead.** The build is designed in refit; islands supply **material** |
| **"The whole differentiation rests on 'eat'"** | **Half survives.** The verb is intact — cells and objects come from eating. **It no longer carries the differentiation alone**; the other half is carried by **"you design five slots"** |
| **Undecided 3's "fixed per island makes route choice into build choice"** | **Its grounds are gone.** Fixed or random, the build is decided in refit |

⇒ **The rejected fork is recorded in
[the build is designed, not inherited](../decisions/build-is-designed-not-inherited.md).**
⇒ **And both GDD twins were edited directly.**
[What two dead games left behind](../lessons-from-two-dead-games.md): *a refutation lands where the claim
is, or it does not propagate.*

### ⇒ And the same change **closes** one of the GDD's open holes

GDD adversarial review, item 2: **"who to bolt a specialty onto is not a decision"** — in the first
vertical slice the third soldier and the seventh are indistinguishable, so the only question left is
*stack or spread*, and that ends in arithmetic.

⇒ **Once objects bolt onto a slot rather than onto a soldier, the problem stops existing.** There are five
slots and **they are distinguishable** — slot 1 and slot 4 are not "soldier three and soldier seven."
**It was not solved; the container changed** — the same shape as *"when a measurement keeps failing in the
same place, suspect the container"*.

---

## The arithmetic — **rule 4 is the only load-bearing rule in this document**

The second game in this repo died on **"an advantage with no cost is not a decision."** Rule 4 is a direct
answer to that sentence, so **the arithmetic is pushed all the way, and where it fails it says so.**

⚠ **Every number below is derived by this document and none of it is measured.** They are placeholders
chosen to show the shape; **the real values belong to `rules.gd` and are settled by the probe.**

> ### ⚠⚠ And this section's **referents disappeared the same day**
>
> The model below is built on `C / c(k)` — **how many summons one island buys. Summoning was deleted.**
> ⇒ **The shape of the argument stands**: a linear cost is not a decision · a single interior optimum is a
> calculation · the advantage and its cost belong in one sentence · objects are axes rather than power ·
> without scarcity the answer collapses to one.
> **What died are the variables.** Nothing has been decided about what `k` attaches to, so `c(k)` and
> `p(k)` have nowhere to attach either.
> ⇒ **Rewrite this whole section against new variables once undecided 1 of
> [plan it, then watch it](plan-then-watch.md) is answered.**

### The model

| Symbol | What |
|---|---|
| `k` | objects on one slot |
| `c(k)` | cells one summon from that slot costs |
| `p(k)` | the power of one such soldier |
| `C` | cells available over one island |

Summons = `C / c(k)`, total army power `P = C · p(k)/c(k)`.
⇒ **There is exactly one thing to maximise: `p(k)/c(k)`.**

### Step 1 — **read linearly, it is not a decision** (proof)

With `c(k) = c₀ + k·Δc` and `p(k) = p₀ + k·Δp`:

> the sign of `d(p/c)/dk` is `sign(Δp·c₀ − Δc·p₀)`

⇒ **positive and `k = max` is the unique answer; negative and `k = 0` is.** They are equal at exactly one
ratio, `Δp/Δc = p₀/c₀`, and indifference is a coin flip, not a decision.

⚠ **So "each object adds a fixed cost" does not satisfy rule 4.** Either "stack everything on slot 1" or
"five bare slots" **always** wins. **This is the first refutation this document makes of itself.**

### Step 2 — **make the m-th object on a slot cost m, and an interior optimum appears**

`c(k) = c₀ + Δc·k(k+1)/2`. Derived placeholders: base cell `c₀ = 4`, `Δc = 1`, bare power `p₀ = 1`, each
object `Δp = 1`.

| `k` | cost | power | **power/cost** |
|---|---|---|---|
| 0 | 4 | 1 | 0.250 |
| 1 | 5 | 2 | 0.400 |
| 2 | 7 | 3 | **0.429** |
| 3 | 10 | 4 | 0.400 |
| 4 | 14 | 5 | 0.357 |
| 5 | 19 | 6 | 0.316 |

⇒ **The dominance check answers: both named extremes are dominated.**
**"Everything on slot 1" (0.316) and "five bare slots" (0.250) both lose to `k`=2 (0.429).**

⚠ **Only while `c₀ > 0`.** If the bare cell is free, `power/cost` is unbounded at `k`=0 and spamming bare
cells strictly dominates again. ⇒ **One derived constraint: a bare cell must cost something real.**

### Step 3 — ⚠ **but a single interior optimum is a calculation, not a decision**

If `k`=2 is the answer, **it is the answer at every refit.** That is a fact you learn once — the same
shape as the sentence that killed the second game (*"split to the cap and stay bunched"*), and the same
reason the GDD rejected a landing tax: *solving the same formula every island is arithmetic, not a choice.*

⇒ **The optimum has to move. Here is what moves it:**

### Step 4 — **two forces, pushing opposite ways**

**(a) Objects are axes, not "power."**
The GDD pins the only two axes that make position a decision: **range** and **area**. A range object and an
area object do not add into one scalar `p`, and **which is worth more differs island to island** (enemy
mix, terrain, the shape of the coast). ⇒ **`p(k)` is not scalar, so the optimal `k` is not one number.**

**(b) A family unlock rewards concentration** (decided 9).
N objects of one family **on the same slot** open that family's ability.

⇒ **Convex cost pushes toward spreading; the family unlock pushes toward stacking.**
**The advantage and its cost are in the same sentence** — exactly what
[what two dead games left behind](../lessons-from-two-dead-games.md) demands: *design the cost in the same
sentence as the advantage; bolted on later it is friction, not a cost.*

**The crossing, in numbers** (derived: family threshold 3, budget 100 cells):

| | summons | power each | **total power** |
|---|---|---|---|
| `k`=2 (efficiency optimum) | 100/7 = 14.28 | 3 | **42.9** |
| `k`=3 (family complete) | 100/10 = 10.00 | 4 | **40.0** |

⇒ **A family ability has to be worth more than 6.67% of the army's power to be worth taking.**
**(42.857 − 40.0 = 2.857; over the better army, 42.857, that is 6.667%. Over the family army, 40.0, it is 7.14%.)
⚠ **This read 6.8%, which comes out of neither denominator — the adversarial review caught it.****

### Step 5 — ⚠ **and even that is not enough: objects must be scarce**

If the family ability is worth **much** more than 6.67%, the answer collapses back to one sentence:
**"stack to the threshold and stop."** Applied to five slots five times, refit is a calculation again.

⇒ **The only condition under which the decision survives: you can never complete a family in every slot.**

> **Derived inequality: total objects dropped in a run < slot count × family threshold.**
> With the derived values (5 slots, threshold 3) that is **fewer than 15**. A ten-node map dropping one per
> node gives 10 ⇒ it binds.

⇒ **Only then does refit ask "which families, in which slots, and how many slots do I commit" instead of
"how many do I bolt on."** And **what dropped differs run to run, so the answer does too.**

### ⚠⚠ Two open questions that would invert all of the above

**1. ~~If a boat's capacity counts bodies, none of this holds.~~** ⚠⚠ **MOOT — 결정 14R deleted capacity.** Every boat carries exactly one soldier and boats are unlimited, so there is no seat to compete for. **The paragraph below is kept as the record of why it mattered**, and its conclusion inverts: what "everything on one slot" now dominates is not a seat but nothing at all — the shape it warned about moved to the BEACH, and that is `plan-then-watch`'s deferred brake.
In shipped code a boat carries a number of **soldiers** (big 4, fast 2). If capacity counts bodies, **a
five-object monster and a bare cell each eat one seat** ⇒ **the scarce resource is a body slot, not cells**,
and **"everything on slot 1" strictly dominates whatever shape the cost curve has.**
⇒ **Undecided 10.** Either capacity is read in cost units, or summoning does not pass through a boat.

**2. If cells are not scarce, the cost gates nothing.**
The [boat and landing](boat-invasion.md) probe already measured it: **all twelve controlled runs won inside
half the time limit.** A clock that does not bind means cells do not bind either — keep earning, keep
summoning. ⇒ **This document's arithmetic sits on top of `TIME_LIMITS`, which was put to the user and never
answered** (boat and landing, undecided 15).

---

## Screens — **few glyphs, large targets** (decided 8)

**Three constraints on every screen here:**

1. **No more than two numbers on screen.** Everything else speaks through shape, size and colour
2. **Anything you press is larger than a finger** — visibly larger than today's HUD key boxes
3. **No sentences.** Prose belongs in documents

### The refit screen — between two nodes

| What | How |
|---|---|
| **Five slots** | Five across the screen. One slot = **a drawn creature plus one large number (its summon cost)**. No stat list |
| **Objects held** | Below, **as drawings**. No names. One family shares a family of shapes |
| **Control** | **Drag** an object onto a slot — the gesture [the boat and the landing](boat-invasion.md) already established, so nothing new is learned |
| **Family unlocked** | **One mark** above that slot. Not a word |
| **Cells held** | One large number, one place |
| **Leave** | One large button |

⇒ **Exactly two numbers reach the screen**: a slot's cost, and cells held.

### Evolution — **decided 5 is a screen requirement, not a rule**

The user called plain bolting-on *"a bit simple."* **What has to read is not "equipped an item" but "a cell
became a creature."**

| When | What happens on screen |
|---|---|
| An object lands on a slot | **That slot's body is redrawn.** No icon appears beside it — **the outline itself grows** |
| A family completes | **One metamorphosis.** The whole silhouette changes once, and **the big effect is spent only here** |
| ~~That key is pressed in combat~~ | **The same silhouette the refit screen showed is what arrives** — ⚠ **the pressing died (2026-08-18).** Only the half about the silhouette carrying over survives. **How it arrives is undecided 10 of `plan-then-watch`** |

⚠ **Why "the outline grows"**: `tools/pixel/` measured it — **on a top-down body only what sticks out
reads.** A mane does not; a beak does. ⇒ **every object is a protrusion.**

⚠ **Why the big effect only on a family completing**:
[what two dead games left behind](../lessons-from-two-dead-games.md) — *put a big effect on the event that
happens several times a second and it buries the other eleven.* Bolting happens many times per refit;
completing a family happens a handful of times per run.

⚠ **And every rule that changes state has something on screen** (`CLAUDE.md`): **cells going down, an
object attaching, a family opening** — all three are in the table above.

### The node map

*"두 줄로 떠서 양쪽에서 하나씩 선택하는"* — Slay the Spire style.

| What | How |
|---|---|
| Nodes | **Told apart by shape**: chest · combat · elite · boss (the GDD's four). **No text** |
| Paths | Lines between nodes; only reachable ones lit |
| Where you are | One highlight |

⚠ **Branch count and depth are not decided** — undecided 8. The user said "two rows", and that reads two
ways: **one of two at each step**, or **two columns offered and one taken from each.**

### ~~The `1`–`5` bar in combat~~ — ⚠⚠ **dead (user, 2026-08-18, later the same day)**

**The only things pressable during combat are the speed control and the pause.** The table below is kept as
a record — **"cells as one bar that goes down" and "dim what you cannot afford" are candidates to move to
the planning screen, not to the combat screen.** [Plan it, then watch it](plan-then-watch.md)

**Today it reads `1 근접 3` in glyphs.** Decided 8 points straight at this.

| What | How |
|---|---|
| Five slots | **A drawn creature plus its cost.** No words |
| Cells held | **One bar that goes down.** One of the things `v2-openfield` died for was *"nothing on screen ever decreased"* |
| A slot you cannot afford | **Dimmed.** "Why won't this press do anything" has to be on screen |

---

## What this touches in code — **inside the folder contracts**

⚠ **This document writes no code.** Below is the list a plan fills in.

| Folder | What grows | The contract |
|---|---|---|
| `src/sim/rules.gd` | Cell costs · the object table · the family table · the family threshold | **Every constant that changes what happens, in one file.** ⚠ A `const` Array loses element typing, so every read casts, and **a `const` packed array is a parse error** |
| `src/sim/` — one new file | **What each of the five slots holds · a slot's cost · the stats of the soldier it summons.** `RefCounted`, built with `.new()`, never touches the tree. **Per-slot objects in flat arrays** | `sim` uses no `Node`, no `_draw`, no `Input`, no `$` |
| `src/sim/army.gd` | ⚠ **Undecided 1 (do cells come back on death) decides what this file is for. Do not touch it before that answer** | Today's contract — a row is never removed, which is what makes permadeath structurally true — only survives if the answer is "permanent" |
| `src/sim/battle.gd` | ⚠⚠ **`load_soldier` no longer exists** (deleted 2026-08-18 with the summon keys). Whatever spends the cell wallet has to be hung on something else; `send`/`recall`/`commit` are what `battle` offers now | **`events` is the only path from sim to view** and carries three kinds today — a kind is added. No clock grows inside `sim` |
| `src/sim/run.gd` | **Wallet · inventory · the map graph · the refit state.** `State` gains map and refit; the fixed per-island reward table becomes node kinds | The only state that crosses islands |
| `src/view/hud_view.gd` | **`KEY_TYPES` dies as a constant** — slots change during a run, so it reads slot state instead. Key boxes go from glyphs to drawings | `view` reads `sim` and never writes it |
| `src/view/` — two new files | **A map view and a refit view.** `Node2D` with `_paint_*` hooks, **exactly one `draw_*` per leaf** | ⚠ **`net_draw_leaf` reddens any function its per-function table does not name**, so a new file opens its table in the same edit |
| `src/shell/game.gd` | `1`–`5` map to **slots**, not types. The refit drag and the map click | **The only file that reads `Input`** |
| `src/look.gd` | Every size and colour of the new screens, **and the evolution beat's durations** | **Every presentation constant, one file** |
| `tests/nets/` | At minimum — **slot cost arithmetic · the map graph · the refit gesture · the new views' leaves · the cell economy** | **Under five nets the wrapper refuses the round.** ⚠ **Every row gets a floor as well as a ceiling** — a ceiling alone passes an effect that never happens |

---

## Undecided — **cannot be built without picking**

1. **Do cells come back when they die, or is death permanent?**
   - **They come back**: the roster shrinks to a single count, and **HP carryover and permadeath both stop
     meaning anything** — the reason `army.gd` never removes a row disappears. Failure stops hurting
   - **Permanent**: today's structure stands and cells are **money that buys a new body.** Then a
     **recovery path becomes mandatory** (the same hole as GDD undecided 14)
2. **One template per slot, or template plus upgrades?** One template makes the refit decision exactly five
   choices, **and it closes after a single run**
3. ~~**Do cells grow during combat?**~~ ⚠ **Its stakes are gone (2026-08-18, later the same day).**
   The grounds for this item were *"yes and the hands keep working"*, and **decided 1 settles that the hand
   does not move either way.** ⇒ when cells accrue is now **an economy question only.** The record:
   - **Yes** and the hands keep working
   - **No** and everything is decided before landing; combat is watching.
     ⚠ The [boat and landing](boat-invasion.md) probe already measured today's number — **46–72% of an
     island has nothing to press, with the last command landing at 7.4–12.9 s.** "No" inherits that figure.
     ⇒ **Under the new design that figure is 100%, and it is a definition rather than a defect** —
     [plan it, then watch it](plan-then-watch.md)
4. **Where do levels/experience attach — the individual cell, or the slot?** **On the individual a death
   hurts; on the slot it does not**
5. **Squad-level control (assigning squads).** ⚠ **`CLAUDE.md` names it as one of the four systems that
   circled a conversation six times without closing.** ⇒ **named and parked, not planned**
6. **A slot that summons several bodies at once.** The user raised it **and said it is a later idea** —
   recorded as such, not as scope
7. **What the families are.** No list. **Step 5 of the arithmetic depends directly on family count and
   threshold**
8. ~~**Map branch count, depth, and node kinds.**~~ ⚠⚠ **CLOSED (2026-08-18) —
   [the title and the map](title-and-map.md) answers it: five floors, seven nodes, four routes, four fight
   islands per run, and three types (fight · chest · boss) with the elite deferred.** ⚠ **One thing is
   still open**: whether the user's "two rows" is ① or ② — that doc's open 1 carries the quote verbatim
   and is with the user. An answer of ② rewrites the five floors.
   ⚠ **And closing this changes one number elsewhere**: [the cell army GDD](cell-army-gdd.md)'s
   recovery-path section assumes **eight islands** while the real map is **four fight islands**.
   ~~Original: nothing settled beyond reusing the GDD's four; the user's "two rows" reads two ways.~~
9. **Is the cost paid per summon, a design-time budget cap, or both?** The user said *"전체 코스트가 있어서"*
   (*"there's a total cost"*), which reads both ways. ~~Decided 3 pins **per-summon spending**;~~
   ⚠ **Half died (2026-08-18, later the same day)** — with summoning deleted, **"per summon" is no longer an
   available answer.** What is left is **one design-time cap**, and it is not decided
10. ~~⚠⚠ **Does a boat's capacity count bodies or cost?**~~ ⚠⚠ **CLOSED BY DELETION, 결정 14R.** There is no capacity: one boat, one soldier, unlimited boats.
    ~~And **decided 10 (the boat is not fixed) keeps it open alongside the boat itself**~~
    ⚠ **Decided 10 reversed and this item got sharper** — decided 3 says loading is unrestricted before the
    start, so **what capacity counts is exactly how free the plan is**
11. **How often objects drop.** The arithmetic demands one inequality —
    **total drops per run < slot count × family threshold**
12. **The ratio of cells earned to summon cost.** It is one body with `TIME_LIMITS` (boat and landing,
    undecided 15, **asked and unanswered**)
13. **What a run starts with.** The GDD says ten cells; **now that a cell is a resource rather than a body,
    whether that ten means ten bodies or ten cells is open again**

---

## Not this round

- **Artifacts** — the GDD's third reward axis. Slots have to stand before a condition field has anything to
  hang on
- **Main-loop (between-run) unlocks** — the GDD already ranked this below "balance against zero unlocks"
- **Fog** (GDD undecided 12) · **a tier/ramp-ignoring type** · **3D** (GDD undecided 17)
- **Squad assignment** (undecided 5) · **multi-summon slots** (undecided 6)
- ~~**Changing the boat rules** — the user said the boat will change (decided 10), and **nothing is built on
  top of something about to move**~~
  ⚠⚠ **Reversed.** With the boat at the centre, **changing the boat rules is now the work itself** —
  [plan it, then watch it](plan-then-watch.md)
- **A pile of new soldier types** — variety comes from combination, not from a longer list (decided 9)

---

## Acceptance — **written so it cannot pass by inference**

⚠ **No row below closes on "the round is green", "the effect was built", or "an agent walked through it".**
`CLAUDE.md`: *acceptance is written down when it is heard.*

| What must be true | How it is known | ⚠ What does not pass it |
|---|---|---|
| **It reads as evolution** | The user looks at the refit screen and **says something on the "it evolves" side, or says "it still just feels like attaching things."** Open until one of those is written here | Every effect having been built |
| **The slot is a decision** | The user **designs differently on two runs and says why** | The probe producing two different builds — a proxy |
| **Both extremes are dominated** | The probe runs **"everything on slot 1" · "five bare slots" · the derived optimum** on **the same roster** and prints all three | The table above. ⚠ **If an extreme wins, the rule is wrong, not the tuning** |
| **Objects are scarce** | **Count the drops in a run and write the number against slot count × family threshold** | "We decided not to give many" |
| ~~**The idle-hands problem shrank**~~ ⚠⚠ **This row is dead (2026-08-18, later the same day)** | ~~Re-measure the last-command time and the dead-air ratio~~ ⇒ **dead air is a constant 100% by design and stops being an instrument.** **[Plan it, then watch it](plan-then-watch.md) stands up three replacements** — time until maximum speed is pressed · time spent planning · pause press count | ⚠ **Deleting a metric without standing one up in its place.** That is how a repo starts lying to itself |
| **Glyph count fell** | **Count the glyphs per screen and write the number** | "It looks simpler" |
| **⚠ Final verdict** | **The user does not say "ambiguous" again** (GDD undecided 18) | All six rows above are proxies |

---

## Sources — **and the case against each**

`CLAUDE.md`: *name checkable sources for a recommendation, and give the argument against your own.*

| Game | What was borrowed | ⚠ The case against |
|---|---|---|
| **[Despot's Game](https://gamecritics.com/eugene-sax/despots-game-dystopian-army-builder-review/)** ([preview](https://screenrant.com/despots-game-preview/)) | Every human starts identical and **the weapon defines the class**; different weapons of one family **unlock that family's ability** — this is decided 9 | **Placement was not a decision there, so the studio added an auto-arrange button**, and it landed mixed on Metacritic. **A family unlock did not stop the combat being a spectator sport** ([what makes placement a decision](what-makes-placement-a-decision.md)) |
| **Clash Royale** | **An eight-card deck is built before the match and only those eight can be played.** Five slots are the same shape | **It is PvP, where real-time pressure is itself the fun.** In a single-player roguelite the same pressure can just be stress — the GDD already records this counter |
| **[Slay the Spire](https://slay-the-spire.fandom.com/wiki/Card_Rewards)** | One of three after a fight, **with the rarity mix set by what was just beaten** | ⚠ **This source argues against this document.** It is "what you ate decides the build", and **the user just rejected that direction on production grounds** |
| **[Vampire Survivors](https://vampire-survivors.fandom.com/wiki/Level_up)** | Three or four options per level-up; **growth pinned to the clock** | **A reward you cannot refuse is not a decision** ([two dead games](../lessons-from-two-dead-games.md)). If every level-up is a notification, **the refit screen stops being needed at all** |
| **[Total War](https://www.twcenter.net/threads/unit-experience-mechanics.400360/)** | Kills are recorded **per individual soldier** and shown as the unit's average; **replenishing with green troops lowers unit experience** ⇒ a shipped answer to undecided 4 | A unit there is dozens of men, so an average means something. **Here there are five slots and nothing to average** |
| **[Bad North](https://bad-north.fandom.com/wiki/Commander)** | Soldiers **regenerate** on the next island, but a commander's death loses the squad **permanently** ⇒ a shipped answer to undecided 1: **split the layers and have both** | **There is no commander here, and inventing one is inventing a host** — the exact concept the GDD deleted, coming back through the side door |

---

## What this document cannot answer

**Whether any of it is fun.** [Planning principles](../planning-principles.md), line two.
⚠ **And every number here is derived, none of it measured.** The second game died with **25 nets and 3541
green checks**, and the tables above are weaker evidence than that. **Nothing here is true until it runs.**
