# The title and the map — building the outside of a run

**Implemented**: **most of it, and the round is green — 14 nets, 1933 checks.** `src/sim/map.gd`
(`RunMap`) · `src/view/map_view.gd` · `src/view/title_view.gd` · the `MAP_NODES` / `MAP_EDGES` tables in
`rules.gd` · the title and map branches in `src/shell/game.gd` · every `look.gd` constant below ·
`tests/nets/net_map.gd` and `net_title.gd`.
⚠ **NOT built: the three new island grids.** `MAP_NODES`'s island column is still the temporary
`[0, 1, 2, 1, 2, -1, 2]` — **three grids across six island-opening nodes** — and the plan's `Status`
line names everything that lands with them.
**Accepted**: **nothing has been confirmed.** What is decided below is what the user said; **nobody has
looked at a screen.**

⚠⚠ **A second pass landed on the map after the first one was read**, and it is the four-state table and
the 21px glyph below. The user's sentence was *"기능은 확실하게 내가 나중에 변경할 수 있어야 돼 …
현재 위치 제대로 표현해야 되고"*. **That is still not acceptance** — it is the correction, and nobody
has said the corrected screen reads either.

**One line**

> **Launching the game opens a title, and a run starts on a map — an island is chosen, not handed to you.**

⚠ **This line is induced, not quoted.** It stitches three of the user's phrases together —
*"그냥 메인루프잡고가자"* (let's take the main loop) · *"슬더슬식 노드선택 + 메인 시작 타이틀"*
(Slay-the-Spire-style node selection + a main title screen) · *"지금 너무 그냥 떵하니 나와서 답이 없네"*
(right now it just drops you in flat and there is no answer to it).

---

## ⚠⚠ Up front — **four things the user decided, one still open**

**These sit first so they cannot be skipped. No section below fills the open one in.**

⚠ **Both former Opens were answered on 2026-08-19, and the answer to Open 1 was the reading this doc was
already written for.** That is luck, not method — the doc says so under Decided 3.

### ✅ Decided 1 — **author a few more islands by hand; the user grows the set later** (user, 2026-08-18)

> ***"섬은 그냥 네가 예시로 몇 개 더 만들어주고, 추 내가 차차 추가할게."***
> (*Just make a few more example islands yourself, and I'll keep adding more over time.*)

⇒ **No generator.** ⇒ **Hand-written islands land this round.** ⇒ And **cutting the cost of "add one more
island" becomes a first-class design goal of this round**, not a nicety — the whole *island shortage*
section below is that.

### ✅ Decided 3 — **one node per floor** (user, 2026-08-19). *Was: Open 1 — "two rows" reads two ways*

> ⚠⚠ **The user's own sentence, reproduced here. The previous draft did not carry it, and that was the
> defect** — it showed the user only the induced reading and never the original, which leans the other way.
>
> ***"두 줄로 떠서 양쪽에서 하나씩 선택하는"*** — *two rows come up and you pick one from each side*
> (user, 2026-08-18; the same quote sits in [the cell army GDD](cell-army-gdd.md)'s undecided 5 and in
> [the session loop](session-loop.md)'s decided table)

① **one of two at each step** · ② **two columns offered at once, one taken from each.**

> ✅ ***"층마다 둘 중 하나"*** (user, 2026-08-19) ⇒ **①.** The rejected branch is filed as
> [one node per floor](../decisions/one-node-per-floor-not-two-columns.md).
>
> ⚠ **This doc had already been written for ① on the strength of one word.** It happened to be right,
> **and a round shipped before anyone asked** — `idea-inbox` row 14. ⇒ **Being right does not retire the
> question of whether it was asked.**

⚠ **The plain reading of that sentence is ②.** "One from each side" is not "one from one side."
**The only thing pointing at ① is one word from today** — ***"슬더슬식"*** (Slay-the-Spire-style), and
that game is ①. ⇒ **This doc is written for ①, and records here that the evidence is one-sided.**

⚠⚠ **This item had to be answered BEFORE the grids were authored** — under ② the five floors, seven
nodes, four routes and the six-grid arithmetic below were **all rewritten**. ✅ **It is answered, so
step 5 is unblocked**: the tables below stand and six grids is the number.

### ✅ Decided 4 — **설정하기 does not press** (user, 2026-08-19). *Was: Open 2*

**Measured, not remembered**: `src/` has no audio, no window mode, no input map, no persisted config —
none of it. The closest thing is `look.gd`'s `FX_GAIN`, and **it is a `const` Array, so it cannot be
written at runtime.**
⇒ **Recommendation: draw 설정하기 as a slot that does not press** (the "not pressable" rule in the screens
section). **Why**: a button that presses and does nothing is **the exact failure the user hit one round ago.**
**The other branch is real too**: build two settings that genuinely exist — window mode and effect
intensity (which costs one edit, `FX_GAIN` from `const` to `static var`). ⇒ **The user picks.**

### ✅ Decided 2 — **the chest pays an artifact. Four come up and you take one** (user, 2026-08-18)

> ***"아티팩트 녗개중 선택"*** — reproduced verbatim, typo and all. **You pick one of four artifacts.**

⚠⚠ **The previous draft recommended in this slot that "the chest restores every living soldier to full HP",
and that was wrong.** It is recorded here rather than deleted quietly — that recommendation was made
**before reading the GDD**, and [the cell army GDD](cell-army-gdd.md) **already carried artifacts, with the
user's own quote beside them.** ⇒ **Healing is not the chest's reward.**
⚠ **And this correction opens something else**: the recovery route is still open as the GDD's
**undecided 14**, and **the HP schedule below shows arithmetically that this map is the first thing to
make it bite.**

> ⚠⚠ **2026-08-19 — the user reopened this, and the two quotes are both theirs.** Asked what the chest
> pays, they answered ***"상자 보상은 아직 미정이고"***. The ✅ above quotes them on 2026-08-18 saying
> artifacts. **Neither is overwritten here.** ⇒ **Treat the chest as UNDECIDED** and do not let this
> heading's tick mark read as an answer — `idea-inbox` row 20.
>
> ⚠ **The consequence is arithmetic, not taste.** The HP schedule below reaches the chest at **43.0 pool**
> against island 3's measured wipe threshold (between **61.5** and **84**). An artifact that does not heal
> leaves the cells–beak–beak route **unwinnable at the boss**; healing makes it free value. ⇒ **Whatever is
> decided, the schedule is re-run against it.**

#### Three words, three different things — **the GDD already separated them**

[The cell army GDD](cell-army-gdd.md)'s *the reward has three axes* section carries the table and the
one-line summary. **It is not restated here.** Only the vocabulary this doc uses is pinned.

| In this doc | What it changes | In code |
|---|---|---|
| **세포 (cells)** | **the count.** Eating raises cells; **it does not raise soldiers** | ✅ exists |
| **오브젝트 (object)** (= 부품/part, formerly 특산물) | **one soldier.** ⚠ **What it attaches to was reopened on 2026-08-18** ([plan it, then watch it](plan-then-watch.md)'s undecided 1) | ✅ **the beak, and nothing else** |
| **아티팩트 (artifact)** | hangs on **the whole army** and changes **a rule** (user's examples: *"전체 HP 상승, 전체 공격력 증가 같은 것들"* — army-wide HP up, army-wide attack up) | ❌ **does not exist. This round builds it** |

⚠⚠ **Artifacts have nothing to do with evolution.** "Spend an artifact to evolve a species" appears
nowhere in the GDD. The theme is a **mammal → dinosaur ladder** and that is all.
⇒ **No line in this doc may read otherwise.**

#### A clear reward and a chest reward are **different things** — the GDD already fixed them per node

**Fight = cells OR one object** · **Elite = the same + one artifact** · **Chest = artifact only.**
⇒ **The chest pays no cells and no object.** If what you are paid for fighting and what you choose on the
rest node were the same axis, "only the chest has no fight" would become free value — that is why the
separation exists.

⇒ **And this sentence closes one of the GDD's own undecideds**: *"does the chest give ONE artifact or ONE
OF THREE? One and there is no decision; three and the rest node gets one."* — **the answer is one of four.**
⚠ **That line has to be fixed in the GDD itself.** Writing it here does not propagate it — this is exactly
the shape `CLAUDE.md` named: *a refutation landing in a different doc than the claim does not propagate.*

---

## This is the **main loop** — and it closes the session loop's map questions

The loop names are the user's own correction, outside in: **main → session → part.**
[The cell army GDD](cell-army-gdd.md) owns that table — **it is not redrawn here.**

| Loop | This doc |
|---|---|
| **Main (outside a run)** | ✅ **The first doc to hold it in detail.** The title is its container |
| **Session (one run)** | ⚠ **Half.** [The session loop](session-loop.md) owns it, and **this doc closes the map item it left open (undecided 8 — branch count and depth).** Refit and economy stay its |
| Part (one island) | Not covered — [plan it, then watch it](plan-then-watch.md) holds it |

⚠ **And this doc builds only the container of the main loop.** The GDD's main-loop diagram has
**「you carry something out → unlock」**, and **that is not this round** (see *what this round does not do*).
⇒ **「시작하기」 always opens the same run.** **Do not read that as a decision** — there is nowhere to
store it (`run.gd`'s `_reset` carries the comment *a run carries no meta and no unlock*).

---

## Why this doc exists — **two reasons, and the second is the expensive one**

**First**: the user launched the game and said *"지금 너무 그냥 떵하니 나와서 답이 없네."* Island 1 is on
screen at frame 1. There is no frame around it.

**Second, and this is half the round**: **the title screen and the node map were decided in conversation
and written into no document.** The only mention of a title anywhere in `docs/` is 「is unlocking its own
screen or a slot on the title」 — **and that is recorded as undecided.** So the plan scoped the map out,
nobody checked it against the conversation, and **the user had to ask why it was not built.**

⇒ **Write the design down before building it. That is the other half of this round.**

### ⚠ And this round wears a failure shape this repo has already named

[Two dead games](../lessons-from-two-dead-games.md) 2-2: *answering a one-sentence complaint with a new
system is how a conversation goes six rounds.* **A title and a map are two new systems.**

**What licenses it — two things, and both must be on record or the next review will correctly reject it:**

1. **The user commissioned them by name.** This is not induced
2. **These are containers, not mechanics.** The diagnosis was never *"a mechanic is missing"* — it was
   **"a whole layer is missing"**: the part loop is built and there is nothing above or below it.
   **A container introduces no unknowns**: the map adds no rule, it only decides **in what order** the
   islands that already exist are met

⚠ **Neither line buys the claim that the map makes the game fun.** That is the next section's job.

---

## The title screen — **three slots, and the user named them**

> ***"메인 시작 타이틀"***, and in the message before it the three slots by name:
> ***시작하기 (start) · 설정하기 (settings) · 종료 (quit)***

**Three slots is all of it. No fourth slot is invented.** (Whether unlocking becomes a slot here is a GDD
undecided and **this round does not answer it** — drawing the slot before unlocks exist makes the slot a lie.)

| Slot | What it does | Does it exist in code today |
|---|---|---|
| **시작하기** | Builds a fresh `Run` and **opens the map.** It does not jump into an island | ✅ `Run.new()` / `restart()` already rebuilds the army too |
| **설정하기** | ⚠ **Open 2.** On the recommendation, **it does not press** — greyed, and no hover response | ❌ there is nothing to configure |
| **종료** | The game closes | ✅ one line in the shell |

⚠ **Greying 설정하기 is a decision, not an unfinished edge.** A greyed slot is **a picture that says it
does not press**; a slot that presses and does nothing is **a picture that lies.** The user was hit by
the second one round ago.

---

## The node map — **five floors, seven nodes, four routes**

### Floors and branches

```
                     [BOSS]                floor 5 · fixed · no reward · island = the lion
                       │
                     [CHEST]               floor 4 · fixed · no fight · artifact · no island
                    ╱      ╲
        [FIGHT·beak]        [FIGHT·cells]  floor 3 · one of two · two new grids
                  ╲    ╳    ╱
        [FIGHT·cells]       [FIGHT·beak]   floor 2 · one of two · island 2 + one new grid
                    ╲      ╱
                 [FIGHT·cells]             floor 1 · fixed · the run starts here · island 1
```

⚠ **The two nodes on a floor pay DIFFERENT axes. That is the fork's question** — see the *reward belongs
to the node* refutation box below. ⚠⚠ **A route passes 0–2 beak nodes and 1–3 cell nodes** (floor 1 is fixed and pays cells, plus
floor 2, plus floor 3). **The earlier draft said "every route passes at least one beak node" and that
is FALSE on this table** — `[0, 1, 4, 5, 6]` steps on three cell nodes and no beak node at all, which
is exactly the branch the 19-soldier roster arithmetic below is derived from. **The two claims were
mutually exclusive**: every route steps on exactly three fight nodes, so three cell nodes is zero beak
nodes. ⇒ **A beakless route IS the cost of taking the cells branch**, and `net_map` pins it as such.

- **A run steps on five nodes**, and **four of them open an island** (floors 1–3 and the boss)
- **Four routes** (two at floor 2 × two at floor 3). ⚠ **A run makes two choices.** If that sounds thin,
  it is — see the refutation box below
- **Branches split and rejoin.** Either floor-2 node reaches both floor-3 nodes ⇒ **one bad turn does not
  lock the rest of the map.** This is the property Slay the Spire's map lives on and it is borrowed intact
- **The map is fixed** — not generated per run. See *where we depart*

### Node types — **three of the GDD's four appear this round**

[The cell army GDD](cell-army-gdd.md) fixed the four — **chest · fight · elite · boss** — and **only the
chest has no fight.**

| Type | This round | Reward | Why |
|---|---|---|---|
| **Fight** | ✅ appears | **one axis only** — cells **or one object.** ⚠ **The beak is the only object in code, so this doc writes "beak node" below** — and which axis a node pays is carried by **the node**, not by the type (box below) | The GDD's rule as written. **Give both and the fork stops being a decision** |
| **Chest** | ✅ appears, **with no island** | **one of four artifacts** (decided 2) | No fight means no grid. **It saves one grid** |
| **Boss** | ✅ appears | **none.** The run ends here | The GDD as written — there is no next island to pay into |
| **Elite** | ❌ **does not appear** | — | ⚠ **The previous draft said two of three rewards are missing; artifacts land this round, so one is missing** — **that elite's soldier type.** While there is one soldier type an elite is a fight node and a chest node stacked ⇒ **it does not earn a fifth floor** |

⚠ **Cutting the elite is deferral, not forgetting.** ~~the day artifacts exist~~ — **artifacts exist this round.**
⇒ **The day it bolts on is the day there is a second soldier type**, and that belongs to [plan it, then watch it](plan-then-watch.md)'s decision 11.

> ### ⚠⚠ Refutation box — **keyed by node TYPE, ① dies. So it is keyed by the NODE**
>
> **Two sentences in the previous draft killed each other:**
>
> - The table above: *"a fight pays one axis only — cells **or** the beak"* ⇒ the fork asks **what am I
>   short of** (①)
> - *What one more island costs*, move 1: *"reward belongs to the **node type**, not the island index"*
>
> ⇒ **Keyed by type, every fight node pays the identical thing.** Floor 2's left and right pay the same,
> and so do floor 3's. **① is then a question the map can never put to the player** — no fork ever offers
> two axes side by side. And ② is re-established by the second refutation box below ⇒ **left as written,
> the fork has no reason at all behind it and the map is a picture.**
>
> ### ⇒ Fixed: **the reward belongs to the NODE, not to the node type and not to the island**
>
> **The GDD's four node types are untouched** — no fifth type is invented. One row of the `MAP_NODES`
> table **is one node**, and that row carries four things: `floor · type · reward · island index`.
>
> ```
> floor 5   boss    no reward               island = the lion
> floor 4   chest   one of four artifacts   no island
> floor 3   fight beak · fight cells        island = two new grids
> floor 2   fight cells · fight beak        island = island 2 · one new grid
> floor 1   fight cells                     island = island 1
> ```
>
> ⇒ **Both floor 2 and floor 3 put "cells or beak" side by side. ① becomes true.**
> ⇒ **And "adding an island does not grow a reward table" still holds** — the reward belongs to the
> **node**, not the island, so `run.gd`'s `_REWARDS` (indexed by island) still dies. **What adding an
> island does cost is one node row — and that edit is unavoidable anyway, because an island attached to
> no node cannot appear in a run.** *What one more island costs* recounts the four below.
>
> ⚠ **This also fixes "two fight nodes are indistinguishable on screen"**: a fight node carries a
> **code-drawn glyph of the axis it pays** (see *what is on the map*).

### What is visible ahead — **everything**

**The whole map is visible from the first frame to the last.** Node kinds, lines, what is reachable.
**Nothing is hidden.**

**Two grounds, pointing from opposite sides:**
- Slay the Spire shows the whole act map at all times. **That is why planning exists there at all**
- FTL does the reverse, and the critique of the reverse comes back **in the user's own word**:
  *a choice made without information does not read as risk* (see sources). ⇒ **Fog is not something to add
  while the game is being told 「애매하다」.** The GDD had already deferred fog to a later node property

### What the player is choosing between — ⚠⚠ **and the claim this doc buys vs the one it does not**

**Slay the Spire's map is not a decision because it is a graph.** It is a **schedule of HP and resources**,
and it is a decision because **HP carries between fights and cannot be freely restored** (see sources).

**This game already has that structure**: soldiers carry across islands **with their HP**, and **a dead one
is dead for good.** ⇒ **A fork asks two things**: ① **what am I short of** (cells or the beak — a combat
island pays one axis only) ② **how much HP can I spend here** (how many floors until the floor-4 chest).

> ### ⚠⚠ Refutation box — **the previous draft quoted a dead number here. Re-measured today it says the opposite**
>
> **What the previous draft wrote**: *"five policies × three islands, fifteen wins out of fifteen, and
> leftover HP has no use, so both currencies are dead ⇒ ② is not a question"* — and on that basis it
> wrote the acceptance row *the fork has a reason behind it* off as **"close to unpassable."**
>
> **⇒ Those fifteen wins predate [plan it, then watch it](plan-then-watch.md) raising the enemies from
> 4 · 6 · 5 to 8 · 12 · 14, and predate the sub-step.** That doc's own probe section says *"not directly
> comparable to the old 49%"* — **and this doc made exactly that comparison.**
>
> ### The probe, re-run — **and the probe itself had to be repaired first**
>
> ⚠⚠ **The table this box used to carry could not be reproduced on this tree, and the reason is the
> map.** `tools/probe/run_run.gd` walked island indices; a `Run` now starts in `State.MAP` and
> `_advance()` lands back in `MAP` instead of stepping `island_index`, so the driver's loop fell out on
> its FIRST iteration and **every policy played zero islands** — with no `[!!]` line, because a `break`
> is that loop's normal exit. The probe was given a route to walk (both branches, as node-id
> constants) and everything below is the first measurement this tree has produced.
>
> `Godot_v4.7.1-stable_win64.exe --headless --path . --script res://tools/probe/run_run.gd`
>
> **A run is now FIVE nodes and FOUR islands**, so nothing here is comparable with the three-island
> rows this box used to hold. The policy sweep walks the **cells branch** `[0, 1, 4, 5, 6]`, because
> the beak branch dies on its second node and would leave the sweep with two rows — and that branch is
> measured on its own below rather than left out, so the harsher answer is on screen either way.
>
> | Policy (cells branch) | node 0 · isle 1 | node 1 · isle 2 | node 4 · isle 3 | node 6 · boss | Run |
> |---|---|---|---|---|---|
> | **nearest coast (baseline)** | 27.0 | 41.0 | 91.5 | 48.0 | cleared · 6 soldiers · 36.0 pool |
> | nearest coast, drop order reversed | 27.0 | 47.0 | 82.0 | 65.5 | cleared · 5 · 32.5 |
> | coast farthest from enemies | 30.0 | 37.0 | 90.5 | 49.0 | cleared · 8 · 49.0 |
> | farthest coast | 36.0 | 54.5 | 64.0 | 58.5 | cleared · 7 · 45.5 |
> | **half onto each of two coasts** | 41.0 | 65.0 | 82.0 | — | ⚠ **lost — wiped on node 4** |
>
> | The fork — same plan, both branches | Islands played | Won | Total damage |
> |---|---|---|---|
> | **beak branch** `[0, 2, 3, 5, 6]` | 2 | 1 | 152.0 · ⚠ **lost — wiped on node 2** |
> | cells branch `[0, 1, 4, 5, 6]` | 4 | 4 | 207.5 · cleared |
>
> Starting pool **116.0** (6 melee × 14 + 4 ranged × 8). **The chest lifts the baseline run 28.5 → 84.0**,
> which is the single largest number on the whole schedule.
>
> ⇒ **Four things, and one of them is not what this box expected:**
>
> 1. **Islands do cost HP.** 27–91.5 apiece, and the baseline finishes at 36.0 having been healed once
> 2. **One of the five policies loses the run** on the cells branch, and **the whole beak branch loses**
> 3. ⚠⚠ **The beak branch does not lose because of its reward — it loses because of the island
>    shortage.** The island column is still `[0, 1, 2, 1, 2, -1, 2]`: three grids across six
>    island-opening nodes, so **node 2 opens island 3, the lion's grid, as the run's SECOND fight.**
>    That is a level-design fact, not a fork fact. ⇒ **This table does not yet measure the fork, and it
>    cannot until the three new grids land** — see the descope note at the top of the plan
> 4. ⚠ **The baseline stop condition now reads 미달 on the cells branch**: worst island 48.3 % of its
>    limit, no island lost. The clock still never binds. It reads 충족 on the beak branch only because
>    that branch loses outright, which is not the same claim
>
> ⇒ **So ② ("how much HP can I spend here") holds** — HP is spent, and running out ends runs. ① is
> established by the *reward belongs to the node* box above. **The acceptance row "the fork has a
> reason behind it" is not unpassable — that is reverted** — but it is **not measured yet either**,
> for the reason in 3.
>
> ⚠ **The doc still keeps two claims apart:**
> - ✅ **Bought**: **the map gives a run a shape.** A start, a fork, a visible boss, progress on screen
> - ⚠ **Not bought yet**: **"the fork is a decision."** Today the two branches differ by which GRIDS
>   they draw, not by what they pay. ⇒ **the three new grids are what turns this table into evidence**
>
> ⚠⚠ **`CLAUDE.md`: a refutation is edited into the doc it refutes.** So the same edit fixes
> [plan it, then watch it](plan-then-watch.md)'s probe section and `docs/design/README.md`'s row for this
> doc. **`src/sim/islands.gd`'s `TIME_LIMITS` comment carries the same fifteen wins, and the plan hands
> that one to the builder** (design does not touch `src/`).

### Where we **depart** from Slay the Spire — and why

⚠ **A departure with no reason is how a map ends up feeling arbitrary.** So each one carries its reason.

| Slay the Spire | Here | Why we depart |
|---|---|---|
| **An act is 15 floors + boss + boss chest = 17** ⚠ **two sources disagree, 15 vs 17** (see sources) | **Five floors** | **The scarce resource is island grids, not code.** Seventeen floors want seventeen grids |
| Up to six nodes per floor, 1–3 paths out | **At most two per floor, 1–2 out** | Same reason. Plus **hit targets that never overlap** constrains the layout (arithmetic in the screens section) |
| **The map is generated per run** — six upward walks, no crossing, no duplicate destinations | **A fixed map** | ① `src/sim/` contains **zero** random numbers and that is an asset the probe uses ② **with six islands a generator has nothing to shuffle** — four routes already consume every grid. ⚠ **The cost**: a fixed map is **learnable once, and then over**, which is the sentence that killed this repo's second game. ⇒ **Generation becomes necessary when the island pool comfortably exceeds the route length** |
| **Floor 1 is enterable at any node** (at least two entries guaranteed) | **Floor 1 is one node** | Saves a grid, and **the first fight is chosen with no information anyway** |
| **Floor 9 treasure, floor 15 rest, both fixed** | **Floor 4 chest, fixed** | **The position is borrowed; the contents are not.** ⚠ **StS's floor 15 is a campfire (recovery); this floor 4 is treasure (an artifact)** — what is guaranteed before the boss is **power, not healing.** ⇒ **The HP schedule below writes out arithmetically what that difference costs** |
| **No rest site on floor 14** (stops the guaranteed rest doubling) | No rule needed | With one chest it is true for free. ⚠ **The day a second chest lands, this line is needed** — and that same day **can the same artifact come up twice** has to be answered (the draw rule in *the chest* below) |
| **The unknown node** — hidden contents with a self-correcting counter | **None** | The GDD deferred fog, and **FTL's counter-case is exactly this** |
| **The whole map is always visible** | ✅ **Borrowed intact** | **It is the only reason planning is possible** |
| Merchant and rest-site nodes | **None** | Outside the GDD's four node types. **Not invented here** |
| Node type weights (fight 53%, …) | **None** | A fixed map has no distribution. **Needed the day generation lands** |

---

## The chest — **four artifacts come up and you take one**

**The GDD left a question mark in this slot**: *one and there is no decision; three and the rest node gets
one.* **The user answered four.** ⇒ **The chest is the only pure decision on this map** — no fight, no HP
spent, no time spent, **nothing to do but choose.**

### ⚠⚠ So if the four can be RANKED, it is not a decision but a formality

**If one of them is always best, the other three are wallpaper.** That is this repo's own test —
*an advantage with no cost is not a decision, and a mechanic that is not a decision is not fun*
([two dead games](../lessons-from-two-dead-games.md)).
⇒ **The four have to satisfy exactly one condition: they cannot be ranked without knowing the run.**

**On this map that condition holds for free, because the HP schedule below hands different routes
different pools** — cells–cells arrives at the chest on **115.0**, cells–beak–beak on **43.0**.
**A factor of 2.7.**

| Artifact | What it changes | On the 43.0 route | On the 115.0 route |
|---|---|---|---|
| **army-wide HP up** (user's quote) | max HP across the army | **the run hangs on this** | redundant — already above the threshold |
| **army-wide attack up** (user's quote) | kills faster ⇒ takes fewer hits | too thin already; it does not save it | **it closes the boss out** |
| ⬜ **third** | **does not exist yet** | | |
| ⬜ **fourth** | **does not exist yet** | | |

⚠ **The bottom two rows are left blank deliberately, not forgotten.** **The user gave two as quotes**, and
inventing the other two here would be **this doc writing the GDD.** ⇒ **The user picks the four.**
**What is written down here is the test they must pass**: an artifact whose two right-hand columns do
**not** fill in opposite directions does not belong in the four. If both routes rank it the same way, that
row kills the other three.

### Four out of how many — **four out of four means the choice is gone on run two**

**There is one chest on the map, so one draw per run.** ⇒ **If the pool is exactly four, the same four
come up every time, and one run teaches the answer forever.** That sentence is what killed the second game
in this repo.

⇒ **Recommendation: a pool of eight, drawn four without replacement.** `C(8,4) =` **70 combinations**, so
the same four recur at **1 in 70** per run. **No artifact appears twice inside one offer.**
**The other branch is real**: **fix the four** — zero new machinery, and two artifacts to design instead of
eight. **The cost is the paragraph above.** ⇒ **The user picks.**

> ### ⚠⚠ Refutation box — **the draw puts the first RNG into `src/sim/`, and this doc calls that an asset two sections up**
>
> The *where we depart* table justified the fixed map with: *"`src/sim/` has **zero** RNG and that is the
> probe's asset."* ⇒ **Drawing four from eight makes that sentence false.**
>
> ⇒ **The sentence is what needs fixing, not the design.** The asset was never "no RNG" — it was **"the
> same input produces the same run."** **A seeded RNG keeps that property exactly**: `run.gd` owns one
> `RandomNumberGenerator` and **exposes the seed as a public field.** The probe pins the seed and runs stay
> reproducible.
> ⇒ **And it buys the probe a new instrument**: run one route under many seeds and **"are the four
> rankable" becomes something you measure** rather than argue.
>
> ⚠ **Choose the fixed four and this whole box is unnecessary.** No RNG arrives and the old sentence lives.

### The screen — **four cards, and four hit rects that do not touch**

⚠ **These use this doc's own screen rules** — minimum edge **64px**, hit rect is the drawn rect **+8px**,
the screen is **1280 × 720**.

| What | Number |
|---|---|
| Card | **240 × 320**, four of them |
| Gap between cards | **32px** |
| Width of the four | `4 × 240 + 3 × 32 =` **1056** ⇒ side margin `(1280 − 1056) / 2 =` **112** |
| Card x | **112 · 384 · 656 · 928** |
| Card y | `(720 − 320) / 2 =` **200** (200 – 520) |
| **Hit rect** | card + 8px all round = **256 × 336**, x = **104 · 376 · 648 · 920**, y = **192** |

**The non-overlap is arithmetic, not assertion** — a hit rect ends at `104 + 256 =` **360** and the next
starts at **376** ⇒ **a 16px gap.** Same for all four.
**All four are on screen** — left **104 ≥ 0**, right `920 + 256 =` **1176 ≤ 1280**, top **192 ≥ 0**,
bottom `192 + 336 =` **528 ≤ 720**. ⚠ **Measured against the literals 1280 · 720**, never against the
layout's own extent.

**How a pick is confirmed**: **one click takes it.** Press **0.10 s** with brightness −0.15, then the
screen fades **0.35 s** down and up and **returns to the map** — the two durations come straight from the
screens section.
**The other branch**: a click only *selects*, and a 「가져간다」 (take it) button confirms. **A misclick
becomes recoverable** — this is a run-long, irreversible choice. ⚠ **The cost is one more click, and this
doc counts clicks as an acceptance row** (*the title is not friction*). ⇒ **The user picks.**

⚠ **The four have to be told apart on screen.** The map's nodes are separated by shape with no text
(decided in [the session loop](session-loop.md)), and **that rule does not carry here** — artifacts differ
by *meaning*, not by number: "army-wide HP" and "army-wide attack" are not two sizes of one thing.
⇒ **This screen uses text.** **It is the only screen in this doc that does**, and the *no more text*
acceptance row counts it.

### ⚠ This round BUILDS artifacts — without them floor 4 is an empty node

**Stated plainly, because "the chest gives four artifacts" must not read as built.**
**There is no artifact in the code today.** ⇒ **The minimum this round builds:**

- **Four artifacts** (or eight), **whole-army application only.** ⚠ **No condition column** — the GDD
  already decided *"whole-army first, the condition column is a later extension"*
- **One place for them to hang** — `army.gd` holds the list, and every rule read goes through it
- **One pick screen** — the table above

**Why it cannot be deferred**: floor 4 is a **fixed node** every route steps on. **With no artifact it is a
node that does nothing when pressed**, and that is **the exact failure the user hit one round ago** (open 2
draws 설정하기 unpressable for the same reason). ⇒ **The round that draws the chest is the round that
builds artifacts.**

---

## ⚠⚠ The HP schedule — **three fights become four, and that arithmetic was missing**

⚠ **Its absence was the previous draft's largest hole.** The map was written up as "a container that only
decides in what order the islands that already exist are met" — **but it changes a run from three fights
to four**, and as the refutation box above shows, **the baseline finishes at 116 → 7 today.** Insert a
fourth fight and that does not survive as written.

**Measured (table above)**: island 1 = 27 · island 2 = 41 · island 3 (the lion) = 77. The count reward is
2 melee + 1 ranged = **+36 pool**.
**Island 3's wipe threshold**: **entering with a pool of 84 leaves two alive; entering with 61.5 is a wipe.**

### The dominant route's pool — **node by node**

⚠ **The damage of the three new grids is a number that does not exist yet.** Below uses **island 2's 41 as
the model for a middle island**, and **the probe re-measures the day the grids land.** That re-measurement
replaces this table.

| Node | What | Pool in | Damage | Reward | Pool out |
|---|---|---|---|---|---|
| Floor 1 fight (island 1) | cells | **116.0** | −27 | +36 | **125.0** |
| Floor 2 fight | cells or beak | 125.0 | −41 | +36 if cells, 0 if beak | **120.0** or **84.0** |
| Floor 3 fight | beak or cells | as above | −41 | the opposite of above | **115.0** / **79.0** / **43.0** |
| **Floor 4 chest** | artifact | 43 ~ 115 | 0 | **one artifact** — no HP | **unchanged** |
| Floor 5 boss (the lion) | — | as above | −77 | — | what is left if it is won |

> ### ⚠⚠ Refutation box — **losing the heal inverts this table's conclusion. The previous draft had the chest rescuing the run**
>
> **What stood here**: *"A chest that restores ten living soldiers to full (6 melee + 4 ranged =
> `6×14 + 4×8 =` **116.0**) puts the run back above it."* ⇒ **That sentence is dead.**
> **The chest pays an artifact and pays no HP** (*decided 2* above).
>
> ⇒ **The cells–beak–beak route passes the chest still on 43.0, below island 3's wipe threshold
> (somewhere in 61.5 – 84).** **As designed today, that route loses.**
>
> ### ⇒ Three answers remain, and **all three live outside this doc**
>
> - **① "army-wide HP up" raises CURRENT HP too** — then the artifact doubles as the heal and the chest
>   rescues the run again. ⚠ **Raising max HP and raising current HP are different rules, and the
>   difference decides whether a run can finish.** Few one-line decisions bite this hard
> - **② recovery comes from somewhere else** — the refit screen in [the session loop](session-loop.md)
> - **③ that route is SUPPOSED to lose** — take two beaks and a thin army is the price.
>   ⚠ **Then "the fork is a decision" is true, and a first-time player has no way to know it.**
>   Slay the Spire putting a **campfire** in that slot is the known answer to this problem
>
> ⇒ ⚠⚠ **[The cell army GDD](cell-army-gdd.md)'s undecided 14 (the recovery route) is not closed — this
> map is the first thing to make it bite.** The GDD wrote *"the chest island doubling as it is the cheapest
> answer"*; **fixing the chest's reward as an artifact narrows that answer to ①.**
> ⇒ **That line has to be fixed in the GDD itself.**

### ⚠ What happens to the beak — **the previous draft never said**

Had the reward been keyed by **type**, every fight node would pay one axis; had that axis been cells,
**the beak would become unreachable content** and `run.apply_beak`, `State.REWARD`,
`panel_view.soldier_id_at`, `note_beak`, `_pending_beak`, `Look.HOLD_BEAK_SEC` and
[combat juice](combat-juice.md)'s item 9 would all die with it.
⇒ **Keying the reward to the node stops that happening** — the beak stays reachable, because two
nodes on the map pay it and a route can collect up to two.
⚠ **It does NOT make the beak unavoidable, and an earlier draft claimed it did.** The cells branch
`[0, 1, 4, 5, 6]` passes **zero** beak nodes, so on that route `Run.State.REWARD`, `apply_beak`,
`panel_view.soldier_id_at`, `Look.HOLD_BEAK_SEC` and [combat juice](combat-juice.md)'s item 9 never
fire. **That is a real property of the map, not a bug**, and whether a beakless route is acceptable is
a `MAP_NODES` question rather than a wording one. `net_map` asserts the minimum is 0 and says why.

### ⚠⚠ And three cell nodes make a 19-row roster — **two screens break quietly**

**A route can pass at most three cell nodes** (floor 1 fixed, plus one at floor 2, plus one at floor 3), so
the **maximum roster is `10 + 3 × 3 =` 19.** Today's maximum is 13, and **two places are pinned to it:**

| Place | Today | If it is not fixed |
|---|---|---|
| `look.gd` `roster_capacity()` = `ROSTER_COLUMNS × ROSTER_ROWS` = **14** | its comment says "13, so the cap never actually bites" | **it bites.** `panel_view.roster_ids` **silently drops** everyone past the 14th ⇒ soldiers the beak cannot be bolted onto |
| `net_islands` `_min_region_floor()` = `START + REWARD + 1` = **14** | a landing region narrower than this stalls a boat forever | it must be **20** (`10 + 3×3 + 1`). ✅ **Measured: the three shipped islands' smallest landing regions are 744 · 760 · 716 tiles, so raising the floor breaks none of them and lands purely as a real constraint on the three new grids** |

⇒ **Roster capacity grows 14 → 20 and the panel grows 560×400 → 560×480** (`ROSTER_ROWS` 7 → 10,
`PANEL_ORIGIN_PX` y 160 → 120, `BUTTON_OFFSET_PX` y 320 → 420). Checks: `72 + 10 × (28 + 6) =` 412 ≤ 480,
`420 + 48 =` 468 ≤ 480, `(720 − 480) / 2 =` 120.

---

## ⚠⚠ The island shortage — **decided**

> ***"섬은 그냥 네가 예시로 몇 개 더 만들어주고, 추 내가 차차 추가할게."*** (user, 2026-08-18)

### The arithmetic — **why six**

| | Count |
|---|---|
| Nodes on the map | **7** |
| Of those, nodes that open an island | **6** (the chest has no fight, so no grid) |
| **Grids required** | **6** |
| Grids that exist | **3** |
| **Grids hand-authored this round** | **3** ⚠⚠ **and hand-authoring does not survive 2026-08-19** — see the box below |

### ⚠⚠ Superseded 2026-08-19 — hand-authoring ends at continent scale, and the generator was refused

**Nothing here is deleted and nothing is built.** The user decided one combat node's contents become a
continent (*"엄청 길어도 돼 그 맵이. 타일맵"*), 10–15 minutes long. `push-inland` derives **984–1,476
columns**. **Implemented: none. Accepted: nothing chosen.**

> This doc's own words: *"because the user grows the set themselves, **cutting the cost of adding one
> becomes a design goal**"* — and *"three are hand-authored this round, **no generator**"*, on the user's
> *"섬은 그냥 네가 예시로 몇 개 더 만들어주고, 추 내가 차차 추가할게"*.

**The cost went the other way by 41×.** `ISLAND_ROWS` is strings of exactly 48 characters; at 984 columns
one node is **31,488 characters**, written as 32 source lines of 984 characters each — undiffable and
unreadable. **Six nodes: 188,928 characters, against 4,608 today.**

⇒ **The 「six grids, three by hand」 plan below does not survive, and a generator becomes required — which
is the thing the user refused.** ⚠ **This is the one place in the continent design where nothing can
proceed by decision alone**, and it is not decided either way. `rules.gd` states the same refusal for the
map itself (*"Nothing in this section is generated and no seed is read"*).

⚠ **The rest of this section is untouched.** Six is still six, the no-sharing rule still holds, and the
island column is still `[0, 1, 2, 1, 2, -1, 2]` — **three grids across six island-opening nodes, unbuilt.**

⚠ **Six has exactly one reason: no two nodes on the map share a grid.**
Point two nodes at the same grid and **choosing a branch becomes "the same island twice"** — at which
point the fork is a picture, not a decision. ⇒ **grids = island-opening nodes** is this round's rule.

**The boss node uses island 3 (the lion).** Floor 1 is island 1; floor 2's pair is island 2 plus one new
grid; floor 3's pair is two new grids.

⚠ **Three rejected branches, kept on record because the user chose** (do not re-derive them later):

| Branch | Arithmetic | Why not |
|---|---|---|
| **Fewer nodes** (a straight line matching the three islands) | 3 grids = 3 nodes, 0 forks | **Branching is already decided** (GDD undecided 5). And `first-slice` already cut this once: *clicking the only next node is not a decision* |
| **Reuse grids with different enemy sets** | 3 grids → 6 nodes, 0 new grids | **Cheapest.** ⚠ **And the user said to make islands.** Also the second time you see a terrain the plan is a problem already solved |
| **Generate islands** | unbounded grids | **The user reserved the growth for themselves**, and it imports randomness into a sim that has none |

### ⚠ What one more island costs today — **nineteen places, fourteen of them measured. Target: four**

**The user said 「차차 추가할게」, so the cost of adding one grid is a first-class design goal.**

> ### ⚠⚠ Refutation box — **the previous draft's "sixteen places, thirteen tables" is wrong, and so are both reviewers' corrections**
>
> Counted against `tests/nets/net_islands.gd` there are **seventeen `EXPECT_` constants.** One review
> said "fifteen"; another said "seventeen, therefore twenty places." **All three were counting in
> different units** — the same failure family this repo named when a line count was compared against a
> file-count contract.
>
> **So the counting rule is pinned first: one place = one thing a hand must edit to add one island.**
>
> | | Count | Why |
> |---|---|---|
> | `EXPECT_` constants in the file | **17** | as written |
> | of those, **scalar invariants** (`EXPECT_ROWS` 32 · `EXPECT_COLS` 48) | −2 | they **do not move** when an island is added ⇒ not places |
> | ⇒ **tables that grow by one entry per island** | **15** | |
> | of those, one needing no measurement (`EXPECT_LIMITS` — a copy of `TIME_LIMITS`) | −1 | |
> | ⇒ **tables demanding a measurement** | **14** | harbour tiles · start harbour tile · per-harbour reachable coast · their union · landable coast · narrowest cut · enemy count · wave-1 distance · steady distance · relocations · strict-walker unreached · uncovered coast · droppable tiles · start-harbour-alone reachable |
> | `islands.gd` `ISLAND_ROWS` · `TIME_LIMITS` | +2 | |
> | `run.gd` `_REWARDS` | +1 | a fourth island **silently pays nothing** |
> | `net_islands`'s `t.eq(Islands.count(), 3, ...)` literal | +1 | it bites the day a fourth island lands |
> | **⇒ total** | **19 places, 14 of them measured** | |
>
> ⚠ **One review said `EXPECT_STRICT_UNREACHED` `[0, 63, 0]` cannot become a literal floor/ceiling, and
> that is correct.** Move 2 below names what happens to it — **it is dropped, and only the property that
> made those 63 benign survives (`strict_with_no_nearer_blocker == 0`).** That is a genuine loss and it
> is recorded here: **the strict walker's exact count is no longer pinned.**

**⇒ So this round builds the cost down, in four moves:**

1. **`_REWARDS` dies.** Reward belongs to **the node**, not the island index and not the node type — see
   the refutation box above. ⇒ **Adding an island no longer grows a reward table.** ⚠ **What it does cost
   is one row in the node table** (move 4)
2. **The fifteen per-island tables become invariants plus a fingerprint.**
   - An **invariant** is not measured per island — it is a **literal floor and ceiling every island must
     satisfy**. ⚠ **Both ends on the same row** — a ceiling alone passes an island where the thing never
     happens at all:

     | Invariant | Floor | Ceiling | Today |
     |---|---|---|---|
     | rows · cols | 32 · 48 exactly | same | — |
     | characters outside the legend | 0 | 0 | 0 |
     | harbours | 3 | 3 | 3 |
     | landable coast tiles | **>= 40** | **<= 200** | 82 · 76 · 80 |
     | narrowest cut | **>= 2** | **<= 30** | 15 · 2 · 10 |
     | droppable tiles | **>= 30** | <= landable coast | 50 · 44 · 48 |
     | start harbour alone reaches | **>= 20** (one harbour must land the whole army) | — | 47 · 38 · 46 |
     | landing region size | **>= 20** (`max roster 19 + 1`) | — | 744 · 760 · 716 |
     | ⚠ **enemy count** | **>= 6** | **<= 20** | 8 · 12 · 14 |
     | enemies standing off walkable ground | 0 | 0 | 0 |
     | uncovered coast | **> 0** | **< the whole coast** | 13 · 14 · 4 |
     | time limit | **>= 45.0** | **<= 120.0** | 60 · 60 · 90 |
     | strict-walker pairs with no nearer blocker | 0 | 0 | 0 |
     | droppable tile -> every enemy, pairs that cannot walk | 0 | 0 | 0 |

     ⚠⚠ **The enemy-count row is new, and without it this move makes things worse**: on invariants alone
     **an island with one enemy (won at frame 1) or forty is green.** **"Cheap to add" becoming "cheap to
     add wrong" is worse than "expensive today"** — because the person adding them is the user, alone
   - ⚠ **Invariants alone let someone quietly edit a shipped island and stay green.** So **one fingerprint
     line per island** of its own rows goes in beside them — touch an island and that line bites.
     ⚠ **And a fingerprint says only "the rows did not change." It does not say the derived properties
     are still what was measured** — that is the price of this move
   - ⚠ **The bounds must be literals.** *A check whose bounds come from the thing it checks proves
     nothing* — `CLAUDE.md` named that trap and this is precisely where it lives
3. **The `Islands.count()` literal dies**, replaced by "the island count equals `TIME_LIMITS`'s length"
4. ⇒ **After that, one more island costs four things**: rows, a time limit, one fingerprint line, and
   **one row in the map's node table** — **and none of the four requires measuring anything** (the net
   prints the fingerprint to paste back)

> ### ⚠⚠ Refutation box — **"the cost is three" and the acceptance row "it shows up in a run" cannot both stand**
>
> The previous draft wrote **three edits**, and in the same file wrote **"the map is fixed"** and
> **"grids = island-opening nodes."** ⇒ **An island that got rows, a time limit and a fingerprint is
> attached to no node and therefore cannot appear in a run.** **The acceptance row was unpassable by
> construction.**
>
> ⇒ **Fixed: the cost is four, and the fourth is one row in the node table.** That row carries floor,
> type, reward and island index, and **appending one row IS a floor gaining a node.**
> ⚠ **And it is not free**: a floor with three nodes forces the horizontal layout below to be re-derived
> (today at most two per floor, 340px apart). **Three per floor does fit 1280** — 300 · 640 · 980 is a
> 340px pitch against two 48px hit radii summing to 96. **Four does not** ⇒ **three per floor is this
> layout's ceiling, and that line is recorded here.**

⚠⚠ **This gets an acceptance row**: **the user adds an island themselves and it shows up in a run.**
**There is no other evidence that the cost came down.**

---

## The screens — **what presses has to look like it presses**

⚠ **This is the most expensive section of the round, and the reason is measured.** The user launched the
previous round's plan screen and said *"뭐 어떻게 동작시키는지 전혀모르겠는데?"* and *"조작감이 너무 ㅈ같음."*
**Its grab target was 10px and its drop zone was alpha 0.18, which read as terrain.**
⇒ **So every size and every contrast here is a number in the doc.** A green round does not close this section.

**Input is mouse only.** The keyboard does nothing in this game (`game.gd` is built that way).

### Rules that bind every screen — **as numbers**

| Rule | Value | Why this value |
|---|---|---|
| **Minimum pressable size** | **at least 64px on the short edge**, and **the hit rect is bigger than the picture** | The largest press in the game today is the start button at `220 × 64`. **No new press is smaller than that** |
| **How much bigger the hit rect is** | **+8px on every side** | A slightly-off aim still lands. ⚠ **Built the other way round (picture > hit), it becomes "I pressed it and nothing happened"** |
| **Fill of a pressable thing** | **alpha 1.0** | The last failure was 0.18 |
| **Fill of a non-pressable thing** | **alpha 0.30, zero saturation** | **3.3× apart from the pressable.** ⚠ **The rule is the ratio, not the absolute** — 0.18 failed because it was indistinguishable from terrain, not because 0.18 is a bad number |
| **Contrast against the background** | pressable things ≥ **0.35** in lightness | The background is `default_clear_color` (0.09 · 0.06 · 0.05), nearly black |
| **Hover changes it** | **border 3px → 6px, +0.12 brightness, within 0.10 s** ⚠ **not 0.08** — the previous draft wrote 0.08 and, in the same file, *"every duration above is longer than 0.084 s"*. The two sentences kill each other ⇒ **raised to 0.10** | **This is the only picture that says "this presses."** ⚠ **No hover response reads as "does not press", not as "no effect"** |
| **The press itself** | **0.10 s squash to 0.96×, −0.15 brightness** | Longer than this repo's **five-frame floor** (0.084 s), which [combat juice](combat-juice.md) owns |
| **No sentences** | nothing on screen but slot names | Inherited from [plan it, then watch it](plan-then-watch.md)'s three screen constraints |

⚠ **"No text" binds the map, not the title.** The user named the three title slots in words —
*시작하기 · 설정하기 · 종료*. ⇒ **Labels yes, sentences no.** This split has to be stated because
[the session loop](session-loop.md) once wrote *"never more than two numbers on screen"* — **a number the
user never said** — and [plan it, then watch it](plan-then-watch.md) had to retract it.

### What is on the title

| What | How |
|---|---|
| **The title text** | Upper part of the screen, **72px** glyphs. ⚠ **Not a logo image** — [the body is a line drawn by code](../decisions/the-body-is-a-line-drawn-by-code.md) forbids sprites |
| **Three slots** | Stacked vertically, horizontally centred. **360 × 88px** each, **24px** apart ⇒ `88×3 + 24×2 = 312px` tall, comfortable in 720 |
| **Slot glyphs** | **40px.** ⚠ **The largest glyph on screen today is not the start button's 28px but the clock's `HUD_TIMER_FONT_SIZE_PX` at 30px** — the previous draft said 28 and was wrong. 40 clears that 30 |
| **A pressable slot** | alpha 1.0 fill + 3px border; hover takes the border to 6px |
| **A non-pressable slot** (설정하기, if open 2 lands on greyed) | alpha 0.30 · zero saturation · no border · **hover does nothing** |
| **Background** | a few code-drawn cells drifting very slowly. ⚠ **no image files** |
| **What is NOT here** | continue · records · unlocks · achievements. **None of it, and none invented** |

### What is on the map

| What | How |
|---|---|
| **Node type** | **told apart by shape** — fight = **circle** · chest = **diamond** · boss = **three nested circles**. ⚠ **no text** (already decided in [the session loop](session-loop.md)) |
| **Node size** | drawn radius **40px** at full size, boss **56px**. Hit radius **48px** / boss **64px** (drawn + the shared `+8`). ⚠ **A node shrinks with its state** — the four-state table below |
| **Node spacing** | ⚠⚠ **the coordinate table below replaces this row. The minimum is 120px, not 160px** |
| ⚠ **What a node pays** | **one code-drawn glyph inside the node, radius 21px.** Cells node = **three squares 11.8px on a side, 16.8px apart**, beak node = **one triangle 36.5px across the base** (the same shape a body's beak is), chest = **a cross 42px across**. ⚠ **no text, no image file** — without it **the two nodes on a floor are pixel-identical**. ⚠⚠ **21 and not 13 — see the refutation below** |
| ⚠ **What the army is right now** | top left, **26px** glyphs, **two numbers**: 「병사 %d · 힘 %.0f」 (living count · HP pool). ⚠ **Without it there is no data on screen to answer "what am I short of"** — `hud_view._draw` gates on `battle == null`, so it draws nothing on a map screen |
| **The four states a node is in** | ⚠⚠ **replaces the three rows the first build shipped. Its own table is below** |
| **Lines** | travelled **9px / alpha 1.0** · currently choosable **6px / alpha 0.9** · everything else **3px / alpha 0.25**. ⚠⚠ **travelled was 8px and that broke `look.gd`'s own sentence one line above it** — *"each by more than the 2.0px snap floor"*, and `8 − 6 = 2` is the floor exactly. The net's row named the OPEN↔DIM pair (3px apart) and called it the tightest, so `8 → 6.1` was green with two of the three lines the same picture. **The row takes the minimum over the whole ladder now**, and 9px makes both steps 3px |
| **Where you are** | a **52px-radius ring, 6px thick**, on the node the army is standing on — larger than the 40px node, so it reads outside it. ⚠ **It does not pulse**; the pulse belongs to the nodes on offer, and one screen with two things breathing says neither |
| **Colour per type** | all three differ. ⚠ **Shape is not the only axis — colour and size differ too** — Slay the Spire's map was criticised for *small symbols distinct in neither size nor colour* (see sources), **and that is the same shape as the failure the user just hit** |
| **What is NOT here** | floor numbers · a nodes-remaining count · explanatory sentences · previews |

⚠ **The only pressable things on the map are the reachable nodes on the next floor.** Cleared nodes and
distant nodes do not press — **and they are drawn as not pressing, by the rules above.**

#### ⚠⚠ The four states — **and the refutation of the three the first build shipped**

**The first build gave a node three states** — *on offer* (full colour, a 3px border, a pulse),
*walked* (full colour, no border) and *out of reach* (no colour, alpha 0.30) — **and the user could
not read the screen**: 「기능은 확실하게 … 현재 위치 제대로 표현해야 되고」. Two separate things were
wrong and only one of them was a missing state:

- **"Where I am" and "where I may go" were the same picture** apart from a 3px border. The node the
  army is standing on is a *walked* node, so it was drawn exactly like every node behind it.
- ⚠⚠ **Every difference that did exist needed an input or a moving frame.** The hover answers only
  once the cursor is already on the node, and the pulse is invisible in a still frame. **A player
  reads a still frame first** — and this repo has shipped that exact failure shape before, on the
  plan screen the user could not work out how to operate at all.

⇒ **Four states, and each differs from its neighbours on three channels that all survive a
screenshot: SIZE, BRIGHTNESS, and what is drawn on top.**

| State | Radius | Fill alpha | Reward glyph alpha | Drawn on top |
|---|---|---|---|---|
| **HERE** — the army is standing on it | **40px** (full) | 1.0, own hue | 1.0 (**5.25 : 1**) | ⚠ **the 52px white ring** |
| **OPEN** — it may step onto it next | **40px** (full), pulsing ±4px | 1.0, own hue | 1.0 (**5.25 : 1**) | **a 3px white border** (6px under the cursor) |
| **PAST** — walked and finished with | **34.4px** (×0.86) | **0.62**, own hue | **0.80** (**2.46 : 1**) | nothing |
| **LOCKED** — not reachable from here | **30px** (×0.75) | 0.30, **no hue at all** | **0.75** (**2.02 : 1**) | nothing |

⚠ **Both scales are below 1.0 and that is arithmetic rather than taste.** The hit radius is one
number per kind (`drawn + 8`), so a state drawn LARGER than the full radius would put a node's
visible rim outside the circle that can be pressed. The pulse already spends the whole of that
margin: 40 + 4 = 44 against 48.

⚠ **The glyph does NOT shrink with the node.** What a place pays is how the route TO it gets chosen,
so it stays 21px on a locked node as well — which is also where its ceiling comes from: the widest
glyph reaches `1.08 × 21 + 1.5 = 24.2px` and the smallest drawn node is `40 × 0.75 = 30px`.

#### ⚠⚠ And the glyph's BRIGHTNESS is its own ladder — **the size fix alone left it unreadable**

**Raising the glyph 13px → 21px fixed one half of "you cannot tell what a node gives" and the second
half shipped anyway.** The ink is `COL_PANEL_BG`, a dark tone drawn ON the node so the reward reads
as cut out of it — and the first build handed that ink **the fill's own alpha**. So as the state gets
colder both sides of the same contrast darken together and the two converge instead of separating.
**Measured on the shipped pixels: the LOCKED glyph came out at 1.31 : 1, and on the opening frame six
of the seven nodes are LOCKED.**

⇒ **`MAP_GLYPH_PAST_ALPHA` and `MAP_GLYPH_LOCKED_ALPHA` are the ink's own two numbers**, deliberately
above the fill alphas they used to copy (0.80 against 0.62, 0.75 against 0.30). The ratios in the
table are what that buys, and the net computes them **off the captured colours** rather than off any
constant — an ink drawn in the node's own tone fails the row exactly as an ink at alpha 0 does.

⚠ **The floor is a plain Rec.709 luminance ratio of 1.8 and NOT WCAG's 3 : 1**, and that is arithmetic
rather than a lowered bar: the ink's own luminance is 0.088 and a LOCKED fill over the clear colour is
0.328, so WCAG's `(L + 0.05)` form **tops out at 2.7 : 1 with the glyph fully opaque**. 3 : 1 is
unreachable on this pair without changing the ink or the fill, and a floor nothing can pass is not a
floor. The tightest value the tree actually carries is **2.02 : 1**, on a locked chest.

**Every number above is a named constant with a floor and a ceiling in `look.gd`'s node-map block**,
which now opens with a plain-language header naming its six groups. The user asked for exactly that:
*「기능은 확실하게 내가 나중에 변경할 수 있어야 돼」*.

### ⚠⚠ The coordinate table — **the previous draft had no vertical arithmetic at all, and 160px does not fit 720**

**Refutation**: five floors at a 160px centre-to-centre minimum is four gaps = 640px, plus the boss's 56px
and the you-are-here ring's 52px at the bottom = **748px**. **The viewport is 720px and no margin has been
spent yet.** ⇒ **it does not fit.**

⇒ **So each node gets a coordinate** (absolute 1280 × 720 viewport space, origin top-left):

| Node | Floor | Centre (x, y) |
|---|---|---|
| 0 · fight (cells) | 1 | **(640, 620)** |
| 1 · fight (cells) | 2 | **(470, 500)** |
| 2 · fight (beak) | 2 | **(810, 500)** |
| 3 · fight (beak) | 3 | **(470, 380)** |
| 4 · fight (cells) | 3 | **(810, 380)** |
| 5 · chest | 4 | **(640, 250)** |
| 6 · boss | 5 | **(640, 110)** |

**Margin check** — everything lands inside `Rect2(0, 0, 1280, 720)`:
- bottom: floor 1 at 620 + the 52px ring = **672 ≤ 720** · hit 620 + 48 = 668 ≤ 720
- top: boss 110 − hit 64 = **46 ≥ 0** · drawn 110 − 56 = 54 ≥ 0
- sides: 470 − 48 = 422 ≥ 0 · 810 + 48 = 858 ≤ 1280

**The non-overlap check** — centre distance for every neighbouring pair:
- same floor, left/right: **340** > 48 + 48 = 96 ✓
- floor 1↔2 and 2↔3 at the same x: **120** > 96 ✓ ← **this is the real minimum, not 160**
- floor 1 ↔ floor 2 (diagonal): √(170² + 120²) = **208** ✓
- floor 3 ↔ chest: √(170² + 130²) = **214** ✓
- chest ↔ boss: **140** > 48 + 64 = 112 ✓

⇒ **The rule is "centre to centre ≥ 120px", and its reason is `48 × 2 = 96 < 120`.**
> ⚠⚠ **2026-08-19 — the user removed the constraint this whole section was built on.**
>
> ***"맵이 굳이 한 맵 한 화면이 안 들어가도 돼요. 마우스 움직이면서 볼 수 있어도 되고"***
>
> ⇒ **The refutation above — *748px does not fit 720* — stops being a wall.** It is still TRUE arithmetic;
> it just no longer forces the compression. The table below was authored to squeeze five floors into one
> viewport, and **that squeeze is now optional.**
>
> ⚠ **What this does NOT license.** It is not a mandate to spread the map out, and **nothing here is
> built.** Panning is a real feature with real cost — the field already owns `_panning` in `game.gd`, and
> `map_view` draws in **absolute viewport space with no camera of its own**, so a pannable map means the
> map grows a transform and **every hit rect on it is tested in map space, not screen space.** That is
> exactly the seam where a click lands somewhere the eye did not aim.
>
> ⇒ **Until it is designed, the coordinate table below stands as written and still fits.** What changed is
> that **the six-floor / bigger-map branch is no longer refuted by geometry** — it is merely unbuilt.
> `idea-inbox` row 21.

⚠ **And this table buys one new acceptance row and one new net row**: **every node's hit circle and the
boss's ring lie inside `Rect2(0, 0, 1280, 720)`, asserted against the literal 1280 · 720 and never against
the layout's own extent.** That is the antidote to the trap `CLAUDE.md` names as *a check whose bounds come
from the thing it checks*.

---

## Presentation — **same round, same doc**

`CLAUDE.md`: *a plan that ships rules and leaves the picture for later is an incomplete plan.*
None of the below is decoration; each one is **a rule that changed state saying so on screen.**

| When | What moves | Why |
|---|---|---|
| **Hover on a title slot** | border 3→6px, +0.12 brightness, **0.08 s** | Without it, "this presses" is nowhere on screen |
| **Pressing a slot** | **0.10 s** squash to 0.96× plus −0.15 brightness | The only evidence the press was accepted |
| **시작하기 → map** | the screen dims and comes back over **0.35 s**, and the map is there | It says the scene changed. ⚠ A hard cut reads as a glitch |
| **The map appearing** | nodes fade in **floor by floor, 0.06 s apart** (`0.06 × 7 = 0.42 s`) | **It teaches the map's direction** — bottom to top. This replaces an explanatory sentence |
| **A reachable node** | 0.9 s pulse | On a still screen it is the only motion saying "here" |
| **Choosing a node** | the you-are-here ring travels **along the line over 0.45 s**, and the island opens when it arrives | ⚠ **Cutting straight to the island hides what the map just did.** The travel *is* the progress readout |
| **Returning from a win** | the cleared node fills over **0.25 s** → the travelled line thickens → the next floor brightens. **In that order** | **Progress accumulates on screen.** This is why there are no floor numbers |
| ⚠ **Pressing the chest** | the screen fades **0.35 s** down and up and **four artifact cards** are there, appearing left to right **0.06 s apart** (`0.06 × 4 = 0.24 s`) | ⚠ **The previous draft said the 「힘」 number climbs here, which was the picture from when the chest was a heal.** The chest is **the only node this round that changes state without a fight**, and `CLAUDE.md`'s line is *every rule that changes state has something on screen that says it happened* |
| ⚠ **Taking an artifact** | the card presses **0.10 s**, **the other three fade out over 0.20 s**, and the screen returns to the map over **0.35 s** | **Taken and not-taken are separated on screen.** ⚠ **If all four leave together, nothing says which one you took** |
| ⚠ **The artifact hangs on the army** | back on the map, **one artifact row appears top-left** | ⚠ **Without it the artifact is in the sim and not on the screen** — the **mirror image** of what this repo named *the screen changes but the sim doesn't* |
| ⚠ **The two numbers on the map** | 「병사 · 힘」 fade in with the map over its 0.42 s | **The only data on screen that can answer the fork's ①** |
| **Boss won / run lost** | goes to the existing panel screen, and **from there back to the title** | See the `restart()` row in the code section |

⚠ **Every duration above is longer than 0.084 s (five frames)** — this repo measured that beats under that
floor are invisible outright ([combat juice](combat-juice.md)) — **with one deliberate exception, named
here so it is not read as a slip**: the map's **0.06 s floor-by-floor stagger** is not a beat, it is the
offset between beats. **Each node's own fade is 0.18 s**, and it is that number the floor binds.

---

## What this touches in code — **while keeping the folder contracts**

⚠ **This doc writes no code.** Below is what the plan will fill in, **splitting "dies" from "its meaning
dies"** — the second kind is the one that breaks quietly.

### What grows

| Folder | What | Contract |
|---|---|---|
| `src/sim/` | **one map graph** — floors, nodes, kinds, edges, where you are. **Flat arrays**, `RefCounted`, built with `.new()` | no `Node` · no `_draw` · no `Input` · no `$` |
| `src/sim/rules.gd` | **the node table `MAP_NODES` (floor · type · reward · island index) and the edge table `MAP_EDGES`**, plus the `Kind` and `Reward` enums | ⚠⚠ **Naming trap**: `net_draw_leaf`'s pixel-suffix sweep (`px\|width\|radius\|size\|margin\|alpha\|ratio\|offset\|gap\|font_size\|cols`) covers **all of `src/` except `look.gd`.** ⇒ `MAP_COLS` or `MAP_ROW_SIZE` **reddens a sim constant.** Write `MAP_FLOOR_COUNT`, `MAP_NODES_ON_FLOOR` |
| `src/sim/run.gd` | **`MAP`** in `State`, a public `enter_island(node)`, **reward keyed by node kind** | see below |
| `src/sim/islands.gd` | three islands → **six** | see the island shortage |
| `src/view/title_view.gd` · `src/view/map_view.gd` | **two new files** | ⚠ **all five of `net_draw_leaf`'s totals change** — below |
| `src/look.gd` | **every** size, colour and duration of both screens | ⚠ **Do not reuse `start_rect_px()` or `button_rect_px()`.** That file already records that *one rectangle answering to two verbs is how a restart gets pressed* |
| `src/shell/game.gd` | the title **is `run == null`** | the "only reader of `Input`" contract is unchanged |
| `tests/nets/` | `net_title` · `net_map` | **the wrapper refuses a round under five nets.** ⚠ **Every row gets a floor as well as a ceiling** |

> ### ⚠⚠ Refutation box — **the previous draft cited "it already returns" as a benefit. That line is what makes 시작하기 unpressable**
>
> Previous draft: *"`game.gd`'s `_unhandled_input` **already returns immediately when `run == null`** —
> the frame exists without adding a sim state."*
>
> **`_unhandled_input`'s first two statements are `if run == null:` / `return`, above every branch.**
> ⇒ **While the title is drawn, not one mouse event arrives.** **It is the only screen in the design
> whose entire purpose is being pressed.**
> And the previous draft's *what quietly changes meaning* table listed this handler only for **ordering**
> (*"the title/map branch must sit above the `battle != null` block"*) — **nowhere did it say the guard
> must be deleted.**
> ⇒ A builder following the table places the branch **below the `return`** and ships **a title that draws
> perfectly and does nothing.** And it fails in exactly this repo's named way: `net_shell` drives handlers
> **directly** (headless a pushed click lands thousands of px off), so a net calling a title-specific
> helper like `game._click_title(at)` **stays green while the real path is dead.**
>
> ⇒ **Fixed: `if run == null: return` BECOMES the title branch.** A branch, not a return.
> **And it is named in *what quietly changes meaning* as a line that must be removed** (two rows below).
> **The net must press through `game._unhandled_input(ev)` — the entry point the OS uses.**

⚠ **Why the title is `run == null` rather than a `Run.State`**: before 시작하기 is pressed there is **no
run**. That is the whole reason, and **the guard above is not a reason but a line to delete.**
**The map is the opposite: `Run.State.MAP`**, because by then a run exists and is in progress.
⚠ **And `panel_view.panel_active()` is `run != null and (...)`, so it is automatically false on both new
screens** — the allowlist already does that job. **Nothing to change, and it is not re-filed as a risk.**

### What quietly changes meaning

| File | What changes | ⚠ Why it is quiet |
|---|---|---|
| `run.gd` `_advance()` | **stops choosing the next island.** Instead of `island_index + 1` it enters `MAP` | ⚠⚠ **Skip this and the map never appears.** `finish_island(true)` currently walks to the next island by itself — **adding a map just gets walked past.** Adding the map is cheap; **removing the automatic +1 is the expensive half** |
| `run.gd` `_REWARDS` | island index → **the node's own column.** The table moves whole into `rules.gd`'s `MAP_NODES` | it is 3 entries today, and a fourth island **silently pays nothing** (`_reward_for_island` guards the index, so nothing crashes). ⚠ **Not keyed by node type** — see the refutation box above |
| `game.gd` `_ready()` | **stops calling** `Run.new()` + `_open_island()`, and its children go from three to **five** | ⚠ **`net_shell` pins three literals**: *「_ready 가 Run 을 만들었다」* · *「_ready 가 첫 섬을 열었다」* · ⚠ **`t.eq(game.get_child_count(), 3, "_ready 가 자식 셋을 만들었다")`** — the previous draft missed the third. Two more views make it **5**, and the *field → hud → panel* order row below it is rewritten with it |
| `game.gd` `_open_island()` | must **explicitly null `battle`** when entering the map | ⚠⚠ **Today it deliberately does not** (the last island has to stay drawable behind the panel). ⇒ Leave it and **the just-finished island keeps drawing under the map, keeps panning, and the HUD's clock and start button come with it.** `field_view._draw` and `hud_view._draw` **both gate only on `battle == null`** — that one field is the only lever that silences both at once |
| ⚠⚠ `game.gd` `_unhandled_input`'s **first two lines** | `if run == null:` / `return` **becomes the title branch.** Deleted and replaced, not layered on top of | ⚠⚠ **Leave it and the title draws while not one click gets in.** And a net calling a title-only helper is **green with the real path dead** ⇒ **the net drives `game._unhandled_input(ev)`** |
| `game.gd` `_unhandled_input` | the title/map branch must sit **above the `battle != null` block** | ⚠ **Below it, a click on the title pans the camera on the island behind it.** The current fall-through is `_panning = true` |
| ⚠ `game.gd` `_process`'s first line | `if run == null or battle == null: return` **stays as it is** | ⚠ **Both new views age their own clock in their own `_process`** (`panel_view._panel_age` is the precedent). Godot calls a child's `_process` even when the parent returned early ⇒ **the drifting cells and the pulse run without the shell handing time down.** Making the shell hand it down puts one clock in two places |
| ⚠⚠ `net_run` | `_advance()` going to `MAP` **reddens the five lines that pin the automatic walk** — *「첫 섬을 이기면 곧장 둘째 섬이다」* · *「고르는 동안 섬 번호는 둘째 섬에 머문다」* · *「셋째 섬이다」* · *「이겨도 없는 넷째 섬으로 넘어가지 않는다」* · *「첫 섬으로 돌아간다」*. **Lines to rewrite, not breakage** | ⚠⚠ **The previous draft's table had no `net_run` row at all** — the net whose subject IS the thing being changed. ⇒ the builder meets surprise reds on the round's core edit, **and may weaken the checks instead of rewriting them.** ⚠ **And one row in the opposite direction is newly needed**: `finish_island(true)` leaves the run in `MAP` and **does not move `island_index` on its own** — a floor as well as a ceiling |
| ⚠ `net_run` — the beak | *「부리는 슬라이스 전체에 하나뿐이다」* **becomes false** | a route can hold up to two beak nodes ⇒ that line is rewritten as **"one node pays the beak exactly once"** |
| `panel_view.panel_active()` | — | ✅ **already an allowlist** (`REWARD` or finished). **Adding a state does not paint a red 「패배」 over the new screens.** ⚠ **Do not re-file this as a risk** — it is closed in the tree. Just confirm `net_shell` still drives it both ways |
| `panel_view`'s restart button | today `run.restart()` + first island. ⇒ **goes to the title** | Returning to a finished map after the run ended shows a dead map. ⇒ **`run = null` is the title, so it is one line** |
| `net_draw_leaf` | ⚠⚠ **all five totals move**: view files **3 → 5**, ⚠ **6 if the artifact screen gets its own file** · table **3 → 5 (or 6)** · total funcs **77 → ?** · leaves **21 → ?** · wide scan **4 → 6** | **Any name the table does not hold is red.** Open the per-function tables for both new files **in the same edit.** ⚠ And **a function with draw count 0 skips the argument check entirely** ⇒ **build geometry in `_draw()` and hand it to the leaf as an argument** |
| `net_islands` | the **fifteen** per-island expectation tables → **invariants plus a per-island fingerprint**; `_min_region_floor()` goes **14 → 20** | see *what one more island costs*. ⚠ **Not thirteen: seventeen `EXPECT_` constants, fifteen of which grow per island and fourteen of which demand a measurement** |
| ⚠ `look.gd`'s roster | `ROSTER_ROWS` 7 → **10**, panel 400 → **480**, button y 320 → **420** | ⚠ **A three-cell-node route fields 19 soldiers.** Leave it and `panel_view.roster_ids` **silently drops** everyone past the 14th — its comment currently reads "13, so the cap never bites" |
| ⚠ `army.gd` | ~~`heal_all()`~~ → **one artifact list, and every place that reads it.** Whole-army only | ⚠ **The previous draft said `heal_all()`, which was the line from when the chest was a heal.** ⇒ **Hanging the artifact is not the end of it** — every rule read has to pass through the list, and **one read that does not means the artifact appears on screen and does nothing.** That is the quietest breakage in this round |
| ⚠⚠ `src/sim/` — new | **one artifact table** (a `rules.gd` constant) + the draw | ⚠ **The draw puts the first RNG into `src/sim/`** — the refutation box in *the chest*. **Without the seed as a public field the probe cannot reproduce a run** |
| `tools/probe/run_run.gd` | walking island indices → **choosing a route** | ⚠ **And this buys a new instrument**: whether different routes produce different outcomes becomes measurable (the arXiv paper below is that move) |

---

## What this round does NOT do — **absence must not read as a decision**

- **Elite nodes** — ⚠ **one of three rewards is now missing** (that elite's soldier type). **Deferred, not dropped**
- ~~**Artifacts**~~ — ⚠⚠ **they are built this round** (*decided 2*). **The previous draft's line here is dead**
- **The artifact condition column** — the GDD already decided *whole-army first*. **Whole-army only**
- **Dropping or swapping an artifact** — what you take stays hung for the rest of the run
- **Map generation and randomness** — the user reserved growth for themselves, and zero RNG in `src/sim/`
  is an asset
- **Unlocks, saving, what a run carries out** — **the other half of the main loop.** ⇒ **시작하기 always
  opens the same run.** There is nowhere in code to store it
- **Whether unlocking is a title slot or its own screen** — a GDD undecided, and **not worth asking while
  unlocks do not exist**
- **The refit screen and the cell/object economy** — [the session loop](session-loop.md) holds them, and
  [plan it, then watch it](plan-then-watch.md)'s undecided 1 has to answer first
- **Fog and unknown nodes**
- **Retuning the time limit** — [the boat and the landing](boat-invasion.md)'s undecided 15 went to the
  user and **no answer came.** ⚠ **Going from three islands to six makes a clock that never binds bind
  even less.** This doc does not fix it
- **New enemy types or enemy counts** — that is [plan it, then watch it](plan-then-watch.md)'s decision 11
- **Continue, records, achievements** — the user named three slots and that is all of them

---

## Acceptance — **written so inference cannot pass a row**

⚠ **No row below closes on "the round is green", "a screenshot exists" or "an agent clicked it."**
`CLAUDE.md`: *acceptance is written down when it is heard.*

| What must be true | How we know | ⚠ What does NOT pass it |
|---|---|---|
| ⚠⚠ **It is operable without explanation** | **A person who has never had this game explained launches it, is told nothing, starts a run and picks a node.** Who that person was and where they stalled goes into this doc | an agent clicking · nets · screenshots. ⚠ **Last round failed this row the moment it met a human** |
| **What presses is readable as a picture** | Show the screen for **5 seconds** and have them point at everything pressable. Pointing at something that does not press is a failure | "we made it bigger" · the numbers in the tables above. **Numbers are the condition, not the evidence** |
| **The fork has a reason behind it** | The user takes **the same map twice by different routes and says why** | the probe producing different routes — a proxy. ~~⚠⚠ And this row is close to unpassable today~~ ⚠ **Reverted**: the refutation box re-measured today and **islands cost 27–77 HP apiece while two of five policies lose the run.** Not unpassable |
| ⚠⚠ **What a node IS is readable** (identification, not differentiation) | **A person who has had nothing explained looks at the map and points at "the node with no fight" and "the node the run ends on."** | ⚠ **"they differ in shape, colour and size" does not pass this.** That says only that two nodes are **different**, never **what** either one is. The Hexagarden source is not evidence that a legend can be dropped — it is an observation that Slay the Spire's symbols were not distinguishable. ⚠ **And "point at everything pressable" does not pass it either** — pointing at the one pulsing node passes that row |
| ⚠ **Every hit target is on screen** | **All seven nodes' hit circles, the boss's ring and the you-are-here ring lie inside `Rect2(0, 0, 1280, 720)`**, asserted against the literal 1280 · 720 | ⚠ **Measuring against the layout's own extent.** Shrink the rectangle and the check shrinks with it — the trap `CLAUDE.md` names |
| **The map shows progress** | The user, **from the screen alone**, says where they have been and how much is left | "we drew the lines" |
| ⚠⚠ **Adding an island is cheap** | **The user adds one island themselves and it shows up in a run.** Unassisted | "we replaced the tables with invariants" · "it's down to three edits". **Nothing is proven until the user does it** |
| **The title is not friction** | **Count the presses from launch to the first island.** Today 0; under this design **2** (start, then one node). **More than three is a failure** | "there is a title screen" |
| **The glyph count did not grow** | **Count the glyphs per screen and write the number down** | "it looks simple". ⚠ This round adds two screens, so it **newly loads this row** |
| **⚠ Final verdict** | **The user does not say 「애매하다」 again** (GDD undecided 18) | **all seven rows above are proxies** |

---

## ⚠⚠ The verification pass — **six things could be drawn invisibly with 1911 checks green**

**Every one was confirmed by a mutation that left the round green, and every one is red now.** They
are recorded here rather than in a report because the shape repeats: **the round measured that a
value was computed and handed to a leaf, and never that the value was visible.**

| What could vanish | The mutation that stayed green | What closed it |
|---|---|---|
| ⚠⚠ **The you-are-here ring** — the user's own fourth clause | `mark.a = PRESS_ALPHA_ON * 0.0` | The captured Color and width are read back and the ring's luminance is compared to the node it wraps. HERE and OPEN share a hue AND a radius, so this ring is the **only** channel separating them |
| ⚠ **The white border on reachable nodes** — this round's headline fix | `edge.a = reveal * 0.0` | Same: the captured colour's alpha, plus a luminance gap against the fill it sits on. The hover rows had closed the WIDTH channel and left visibility open |
| ⚠⚠ **Every reward glyph** | `ink.a = … * 0.0` | The contrast row above. ⚠ **And the shipped LOCKED value measured 1.25 : 1 under that same row** — the check bit the tree as well as the mutation |
| **All ring geometry** — the chest's diamond and both fork borders | `_ring_points(centre, radius * 0.0, …)` | `_ring_centre` reads a bounding box, and **a bounding box of zero extent still returns the right centre.** A sibling `_ring_extent` compares the half-extent to the radius the same capture carries |
| **Two of the three line weights** | `MAP_LINE_PAST_WIDTH_PX 9.0 → 6.1` | The row **named one pair and named the wrong one.** It takes the minimum over the whole ladder now, floored above 2.0 rather than at it |
| **The boss's nested rings, drawn outside the boss** | `MAP_BOSS_RING_STEP_PX 14 → 60` | Its only coverage was `WIDTH <= STEP − 4`, which gets **more** true as STEP grows. Bounded 6–18, and the drawn radii are read back off the capture as strictly decreasing and positive |

⇒ **Four of the seven leaves captured a Color that no row inspected.** `net_map` reads every one now —
border, glyph, here-ring and the army readout — because **capturing an argument proves it was computed
and never that anything could see it**, which is `CLAUDE.md`'s own sentence arriving at this file.

⚠ **The same sweep re-bounded five constants whose only coverage was a `>` or `<=` against another
constant**, which is the shape that let the boss's step through: `MAP_BOSS_R_PX`'s ceiling,
`MAP_HERE_RING_R_PX`'s ceiling, `MAP_RING_SEGMENTS` (referenced by **no** row at all),
`MAP_BOSS_RING_STEP_PX` and `MAP_ARMY_FONT_SIZE_PX`.

---

## Sources — **and the case against each**

`CLAUDE.md`: *attach a checkable source, cite several that disagree with each other, and give the case
against your own recommendation.*

| Source | What was borrowed | ⚠ The case against |
|---|---|---|
| **Slay the Spire — [Map Generation (wiki.gg)](https://slaythespire.wiki.gg/wiki/Map_Generation)** · **[Steam guide, jomami, 2022-07-03](https://steamcommunity.com/sharedfiles/filedetails/?id=2830078257)** | floor structure · paths that split and rejoin · **fixed floors** (treasure and rest at known depths) | ⚠⚠ **The two sources disagree on the two most basic numbers** — the wiki says *17 floors, up to six per floor*, the guide says *"7×15 grid", 15 floors*. **And the wiki page carries an "under construction, may be wrong" banner.** ⇒ **Cite neither number as settled.** This repo once built an argument on a constant that was off by 4.8× |
| **[Say the Spire mod docs](https://bradjrenshaw.github.io/say-the-spire/mod/map.html)** | **the whole map is visible at all times** — the ground for having no fog | ⚠ **A mod's documentation, not the developer's.** Nothing there guarantees the accessibility mod reads out exactly what the original screen shows |
| **[Ludo Guide — map generation and branching](https://www.ludo.guide/guide/slay-the-spire/pathing-risk-assessment/map-generation-and-branching)** | **the map is a schedule of HP and resources, not a graph.** The whole *what the player is choosing* section comes from here | ⚠ **A strategy guide, not a design document.** And the same page hands out **fixed rules** (per-act elite quotas) — **the existence of a standing rule is itself evidence of "learnable once"** |
| **[Game Developer — Anthony Giovannetti interview, 2020-01-22](https://www.gamedeveloper.com/game-platforms/road-to-the-igf-mega-crit-games-i-slay-the-spire-i-)** | the designer's own argument: *depth without a ton of complexity* · **it came from FTL** | ⚠ **A designer defending his own game.** And the same interview **names FTL as the parent** ⇒ "Slay-the-Spire-style" is one point on an axis, not the axis |
| **[Bazzaz & Cooper, "Analysis of Uncertainty in Procedural Maps in Slay the Spire", arXiv, 2025-04](https://arxiv.org/html/2504.03918v1)** | **the only quantitative evidence that route choice correlates with outcome** — 20,000 runs sampled from 77 million; winning runs carry significantly higher path entropy. ⇒ **the template for what our probe should measure** | ⚠ **Correlation, not causation** — the paper does not claim otherwise. And **it makes no claim that the design is good** |
| **[The Hexagarden — "Let's Make a Map! pt 1", 2024-01-31](https://thehexagarden.com/blog/lets-make-a-map-1)** | ⚠ **the heaviest row in this table for this round.** A UX critique of Slay the Spire's map: *small symbols distinct in neither size nor colour*, forcing you to comb the paths, **and needing a legend is itself evidence it is not read** | ⚠ **This is less a counter-argument than a prediction about us.** The failure the user just hit has the same shape (small, low contrast). ⇒ **which is why our nodes differ in shape, colour and size all three.** A personal blog, and not a measurement |
| **[Steam discussion — "Which route do you usually opt for?"](https://steamcommunity.com/app/646570/discussions/0/1692659135901079565/)** | — | ⚠ **A case against the map itself**: players who *"always take the path with the most rest sites"* ⇒ **the map collapses into a constant.** That is the sentence that killed this repo's second game. ⚠ **Forum posts, not measurement** — **record it as a hypothesis for the probe, not as a fact** |
| **[PCGamesN — Slay the Spire 2 map redesign, 2026-03-27](https://www.pcgamesn.com/slay-the-spire-2/patch-notes-regent-buffs)** | **the developer correcting themselves** — generation reworked to stop early maps overflowing with monster rooms, and floor-six elites restored | ⚠ **It reads both ways.** ① **the fun is in the generation constraints, and even the inventors got them wrong first** ⇒ our first map will be wrong too ② **the structure itself survived a sequel almost unchanged** ⇒ copying it is low risk |
| **FTL: Faster Than Light** — [Sectors](https://ftl.fandom.com/wiki/Sectors) · [Beacons](https://ftl.fandom.com/wiki/Beacons) | **the opposite branch**: hide the map's contents and put a chase clock on exploration. A case where the clock makes the decision | ⚠⚠ **Not read directly** — fandom.com returned HTTP 402, so this is from search snippets. **The numbers need one more check.** And **the reason we did not take this branch is the next row** |
| **[Shamus Young, "FTL: Random vs. Skill", 2012-10-02](https://www.shamusyoung.com/twentysidedtale/?p=17335)** · [Fast Fixes for Faster Than Light](https://howell.seattle.wa.us/ggggd/ftl.html) | **the ground for having no fog**: *the random noise is so loud it drowns out the mechanics* · *the problem isn't luck, it's inadequate information when deciding* | ⚠ **Both are old personal essays, and the second carries neither author nor date on the page.** ⇒ **Treated as weak sources.** What earns them a row is that **their conclusion lands on the user's exact word** — a choice made without information reads as **「애매하다」** |

⚠ **Four of the ten argue against this design or its parent** (Hexagarden · the Steam thread · the StS2
rework · Ludo's standing rules). **That is the only evidence this table is honest, so do not trim it.**

---

## What this doc cannot answer

**Whether it is fun.** That is line two of [the planning principles](../planning-principles.md).

⚠ **And it cannot prove half of itself:**

- ~~**Whether the map is a decision is not this doc's to settle.** It rides on whether islands actually
  cost HP, and the probe measured that today they do not~~
  ⚠ **Half revoked, 2026-08-18.** The probe was re-run on today's tree and **islands cost 27–77 HP each
  and two of five policies lose the run** — see the refutation box. **What survives is narrower and still
  real**: whether the map is a decision now rides on **the three new grids being as costly as the three
  shipped ones**, and that cannot be known until they exist and the probe re-measures
- **Nobody knows how many runs a fixed map survives.** With four routes, **four may be the ceiling.**
  This repo killed a game with the sentence *learnable once, and then over*, and **the same blade is
  pointed here**
- **"Operable without explanation" has no instrument but a person.** 1328 green checks did not stop the
  user from being unable to work a screen. **The numbers in this doc are the condition, not the evidence**
