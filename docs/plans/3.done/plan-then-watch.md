# Plan — plan it, then watch it: the whole landing before the start button

**Status**: `3.done` — **all four stages built, the round green (12 nets / 1328 checks), moved 2026-08-19.**
⚠⚠ **`3.done` means the implementation finished; it does not mean acceptance passed, and here it did not.**
The user played the finished build and could not operate the plan screen — *「뭐 어떻게 동작시키는지 전혀모르겠는데?」*
and then *「조작감이 너무 ㅈ같음」*. Measured on the captured frame: the drag source is a ~10px stack in open
water, the droppable coast is tinted at alpha 0.18 over dark green and reads as terrain, and the probe already
counted **10–13 separate precision drags per island**. ⇒ **The acceptance row 「계획이 커밋 전에 읽힌다」
— this design's own stated survival condition — FAILED on contact with a human.** That is the open wound this
doc hands forward, and it is a rule question (what one drag places), not a new system.
See section 17 for what the finished build was attacked with and what else is still open.

**Design**: `plan-then-watch`. **The part loop above and below this one**: `session-loop`. **What the shipped
build does today**: `boat-invasion` and `first-slice`, both in `3.done`. **The presentation contract every
`draw_*` count here answers to**: `combat-juice`, whose authority is `net_draw_leaf._table()`.
**The rejected branch of the reversal below**: `unlimited-boats-not-a-five-boat-cap`.

**Goal, in the user's words**: *"전투 중에 손이 움직이는 거, 안 움직일 거 같은데."* — and the sentence this
round is aimed at, which the boat round did not move: *"참 애매하네. 그래도 그동안 중에서 제일 평범하네."*

---

> # ⚠⚠ OPEN 0 — **the brake is deliberately absent, and that is a user decision on the record**
>
> **Read this before any other line of this plan.**
>
> Boats are **unlimited and free** (결정 14R, section 1). The main session put to the user, in as many
> words, that infinite + free means *"send everything at once to the nearest beach"* dominates — **the
> exact shape that killed the second game** (*an advantage with no cost is not a decision*) — and offered
> three brakes: **sail time · landing-tile capacity · permanent death.** The user's answer:
>
> > **「일단 빼고 만든 이후에 추가하자는 거임」**
>
> ⇒ **Build WITHOUT a brake. Do not invent one to make the arithmetic close.**
>
> - **No step in this plan may reintroduce a cap** — not a boat count, not a per-harbour throughput, not
>   a soldiers-per-beach limit, not a launch cooldown. If a builder finds themselves writing one, the
>   answer is to stop and report, not to ship it. **9.1 and 9.5 each carry the row that catches it.**
> - **The hole is named, not hidden.** Section 8 measures what dominates and **prints the number**; it
>   does not tune it away. Section 12's losability row is scored against the dominant plan **as it is**.
> - **What the missing brake costs, stated up front so nobody later reads its absence as a decision**:
>   ① 「어느 순서로」 loses its *timing* meaning entirely (4.4 — it survives only as **formation**);
>   ② the reinforcement period disappears, so *"one wave cannot take the island, two can"* has no
>   referent and section 8 is rewritten around an aggregate instead;
>   ③ beach choice becomes the **only** axis the player expresses.
> - **The three candidate brakes are recorded here and nowhere else in this plan**, so the next session
>   picks one rather than re-deriving three: **sail time** (a departure interval, which would give order
>   its timing meaning back) · **landing-tile capacity** (a cap on bodies per beach, which would make
>   splitting mandatory) · **permanent death** (already structurally true — `Army` never compacts a dead
>   row — but currently free, because an unhit soldier carries at full HP).
>
> ⚠ **This box does not move further down and does not get summarised away.** It is the single most
> likely thing for a later reader to mistake for an oversight.

> # ⚠ OPEN 1 — **the mother ship is undecided, and this round does not build one**
>
> Four mockups were drawn in the main session. The user liked **variant 2's size**, said it was **too
> close**, said **a big boat from the start is not fun**, and then moved to the reversal below without
> settling it.
>
> ⇒ **This round builds on the harbours that already exist in the code — zero new rules.** `grid` already
> derives `harbour_tiles`, `start_harbour`, `sendable` and `home_harbour_for`. **No plan step assumes a
> mother ship, and no step may add one.** When the user settles it, the departure point is the only thing
> that changes: 4.2's `send()` reads `grid.home_harbour_for(tile)` and nothing else.

---

> ## ⚠⚠ What this plan does NOT buy — read this before anything else
>
> **The design doc's own probe section says the plan is not a decision today, and this plan does not
> refute it.** It builds the *machinery* — a state before the start button, a commit that cannot be
> taken back, a drag that authors the whole landing, and a fight that runs identically at every speed.
> **Whether authoring that plan is a decision is measured in stage 4 and by the user, not proved here.**
>
> - **「순서」 lost half of what it had.** 4.4 works out exactly what survives: with unlimited boats
>   departing on the same frame, order carries **no timing at all**. What it still decides is
>   **formation** — who takes the inner tiles when several boats aim at one beach. That is a real sim
>   quantity and 4.4 derives it; it is also **less** than the design doc's 「어느 순서로」 implies, and no
>   glyph in this round may claim more.
> - **Raising the enemy count does not make the plan a decision.** The design doc's inherited review
>   already measured that *more of the same enemy adds kills, not plans.* Stage 4 buys **the
>   possibility of losing**, which is a different claim and the user set that order themselves.
> - **The speed widget is built to change nothing ABOUT THE SIM.** Section 5's whole point is that a 6×
>   run and a 1× run land on identical `enemy_hp`. If the round ships a widget that changes the outcome,
>   it has shipped the defect it was written to remove.
>   ⚠ **It changes the PICTURE and there is no way for it not to.** 5.4 is that repair, and it is **not
>   optional decoration.**

---

## 0. OPEN questions the build does not stop for

**Both carry the default this plan builds, so a builder is never stuck.** If an answer comes back
different, only the named section moves.

**Sent to the user**: NO. ⚠ **Never sent.** Both defaults shipped and the plan reached `3.done` anyway —
recorded 2026-08-19, when `net_process` was written. This plan is grandfathered by that net; **nothing
after it is.**

| # | Question | **Default this plan builds** | Where it lands |
|---|---|---|---|
| **A** | Pre-commit, is the un-sent army drawn on the MAP at the harbour, or in a HUD strip? | **On the map, as bodies standing at `grid.start_harbour`.** The user's sentence is *"내가 내릴 수 있는 곳 위치에 딱 나서 … 끌어서 탁 놓으면"* — they stand somewhere and you drag one. A HUD strip would be a second place the same fact lives, and it would eat the chrome budget the camera pull-back just bought | 6.1 · 6.4 |
| **B** | Does a sent-but-not-departed soldier show as a **ghost at its destination** or as a **hull at the harbour**? | **A ghost at the destination**, fanned in drop order. It is the only picture that makes *"the plan reads before the commit"* — this design's stated survival condition — answerable at a glance | 6.1 |

---

## 1. What is settled, what this plan decided, and what stays a guess

> ### ⚠⚠ 결정 14 IS DEAD — **the user reversed it, and the reversal is the whole shape of this revision**
>
> **What 결정 14 said**: 「**배 한 척에 병사 한 명. 다섯 척으로 시작한다**」 — five boats, capacity 1, the
> boat count being the cap on bodies per wave.
>
> **What the user said instead**:
>
> > **「배는 너무 곁다리 느낌이다 그냥 바다위에 초록색 지역에 내가 설계한 몬스터들을 무한으로 배를 띄워서
> > 보낼 수 있는걸로하고 싶어」**
>
> and, on the interface:
>
> > **「대기열은 없고 … 내가 내릴 수 있는 곳 위치에 딱 나서 … 그걸 누가 늘어서 끌어서 탁 놓으면은 그때부터
> > 출발하는 거지. 대기열이라는 게 사실 좀 애매해.」**
>
> and, on the round trip: **「배는 왕복」**.
>
> ⇒ **The boat is plumbing, not a resource.** There is no fleet, no boat table, no capacity, no queue and
> no boat count. **What the player plans is the monsters**, and the cap moves from the boat count to how
> many monsters they own — `Rules.START_MELEE + START_RANGED` (10), rising to 13 after island 1.
>
> ⚠ **The word 곁다리 is load-bearing.** The user said *"배가 곁다리다"* twice before the boat round; the
> boat round made it stop, and `boat-invasion`'s `Accepted` line records that. **It has now come back a
> third time pointed at a different thing** — not at the boat's absence from the fiction, but at the boat
> being a **resource the player has to manage.** ⇒ The fix is not more boat, it is **less boat**.
>
> **The strike belongs in both design twins; the rejected branch is `unlimited-boats-not-a-five-boat-cap`.
> Section 15 carries the wording. This plan does not edit those files.**

**Decided by this plan**, because the design doc left them open and a builder cannot proceed without them:

| Design doc | This plan's answer | Section |
|---|---|---|
| 미정 3 — how many boats, and do they still differ | **Unlimited, created per drop, all identical.** `Rules.BOATS` is deleted whole; one `Rules.BOAT_SPEED` survives | 3.1 · 4.2 |
| 미정 4 — is pause a separate widget | **No. It is 0× on the same ladder.** One widget, one row of chips | 5.3 |
| 미정 6 — are detect radii drawn while planning | **No.** Enemy positions only, as the GDD already decided | 10 |
| 미정 7 — where the placement region is | **The UNION over every harbour**: tile `t` is droppable iff `grid.home_harbour_for(t) >= 0`. The overlay already draws a per-harbour region; this is the same predicate widened, and `send()` answers to the same call so the screen cannot promise a tile the sim refuses | 4.2 · 6.1 |
| 미정 8 — does the order carry timing | **No, and it now cannot.** Every boat departs on the commit frame. Order is **formation only** | 4.4 |
| 미정 9 — when the clock starts | **At the start button, and planning is free.** Structural: `_phase_clock` is the only writer of `elapsed`, and an uncommitted `step()` returns before it | 4.3 |
| 미정 10 — the speed multipliers and steps | **0× · 1× · 2× · 3× · 6×**, over a fixed inner sub-step | 5 |
| 미정 11 — how the order is assigned | **The drop sequence, and there is no separate handle.** The user's own rule: *"그때부터 출발하는 거지"* | 4.4 |
| 미정 12 — can a plan be undone before the commit | **Yes, freely.** Press a placed boat's ring to recall it. 결정 3 is *"언제든지 어디서든지"* | 4.2 · 7 |
| 결정 11 — how far the enemy count rises | **8 · 12 · 14**, by adding characters to `islands.gd` rows and nothing else. ⚠ **The doc's carried-over 「섬당 30~40」 is refuted by arithmetic in 8.1 and must be corrected in both twins** | 8 |
| **결정 14R** — what a boat is | **A vehicle created on demand by one drag, carrying one soldier, round-tripping, unlimited.** The whole fleet axis is deleted, not replaced | 3.1 · 4.2 |
| **NEW** — how far back the plan camera sits | **`Look.ZOOM_MIN` 0.5625 → 0.45.** The existing `field_view.setup()` framing then centres the island on **both** axes with real margin. 6.3 carries the arithmetic and the two constants that move with it | 6.3 |

**Still a guess, and named as such**: every enemy coordinate in section 8, `BOAT_SPEED` 4.0, every constant
in 6.4, the zoom value 0.45, and — stated plainly in 4.4 — **how much formation order actually changes.**
Stage 4 measures the last one and **reports**; it does not tune the design.

---

## 2. Order — four stages, each green at its halt

| # | Stage | Picture? | Green means |
|---|---|---|---|
| 1 | **The loop** — the planning state, the commit gate, the sub-step, boats on demand, the drag that replaces the keys | **yes, minimally** | `net_plan` · `net_boat` · `net_battle` · `net_shell` · `net_fx` · `net_fx_view` · `net_islands` · the probe runs |
| 2 | **The plan as a picture** — the army standing at the harbour, the ghosts at their landings, persistent routes and rings, the unspent plan during execution, **and the camera pulled back (6.3)** | **yes** | `net_draw_leaf` · `net_camera` · `net_shell` · **verify-look** |
| 3 | **The time widget** — 0/1/2/3/6× chips, the whole ladder wired, **and the view clock scaled with it (5.4)** | **yes** | `net_shell` · `net_plan`'s equivalence rows · **`net_fx_view`'s ladder rows (9.7)** · **verify-look, watching one fight at 6×** |
| 4 | **Losable** — enemy counts up, `TARGET_LINE_MAX_COUNT` raised with them, `net_islands` re-measured, the probe baseline re-measured under sub-stepping and then re-run and **reported** | no | numbers on the console |

### ⚠⚠ The boundary rule: a stage is what can be GREEN at its halt, not which files it touches

**Stage 1 is atomic and there is no way to make it smaller.** `battle.load_soldier` has exactly one
production caller — `game.gd::_on_key` — and it is the only writer of `pending`, which is the only thing
`launch` will accept. ⇒ **Delete the keys without the drop gesture in the same edit and the game becomes
unplayable, not merely different**: nothing can board, so nothing can launch, so no island can be
finished. Six nets and the probe drive that same call, so they move in the same edit too.

⚠ **The keys are `1` and `2`. There are two of them, not five.** `HudView.KEY_TYPES` has two entries and
`_on_key` binds `KEY_1 + slot` over that count. **`CLAUDE.md` and the design doc both say 「1~5」 and both
are wrong about the shipped build.** An acceptance row counting five deletions cannot pass.

⚠ **Stage 1's halt is playable but plain**: the plan reads as bodies at the harbour, tinted coast and
lines, with a start button and no polish. **That is expected and it must not ship alone — stage 2 lands
in the same round.** *"이번 것처럼 무조건 연출까지 개발하는 게 기본임"* is the user's own line and it
governs this plan.

⚠ **Stage 4 is last on purpose.** Its target needs the loop to exist first.

---

## 3. Files

```
stage 1 — ATOMIC. The sim, its only caller, and every net and tool that drives it
  src/sim/rules.gd        BOATS + boat_count + cap_of + boat_name_of + boat_speed_of DELETED WHOLE ·
                          BOAT_SPEED added (one float) · the throughput-inequality comment DELETED,
                          not edited · SIM_SUBSTEP_SEC · SPEED_STEPS · SPEED_SLOT_DEFAULT ·
                          speed_slot_count · speed_mul_of added (5.3 — they are NOT presentation)
  src/sim/battle.gd       boat_at + pending + load_soldier + boat_busy DELETED ·
                          _committed · _substep_acc · _next_boat_uid added ·
                          send() · recall() · commit() · committed() added ·
                          launch() folded into send() · boats[] entries keyed by "uid" ·
                          _drop_from_pending DELETED · _phase_landings split in two passes (4.4) ·
                          the guards split per-call vs per-sub-step · sub-stepping
  src/shell/game.gd       _on_key DELETED whole · _boat_hit_at/_boat_grabbable REPLACED by
                          _soldier_hit_at/_ring_hit_at · the drag calls send() not launch() ·
                          the start-button gesture · the commit gate on the THREE plan branches
                          (never on _on_wheel — section 7) · step(delta * k) ·
                          set_time_scale/set_speed handed down
  src/view/hud_view.gd    KEY_TYPES · key_slot_count · key_type_of · reserve_count · boat_label ·
                          note_launch · _berth_offset · _paint_berth · _paint_load DELETED ·
                          note_key/_key_offset/_key_colour/_paint_key RENAMED to the chip family ·
                          set_speed added · the start button and the speed row
  src/view/field_view.gd  idle_hull_rect -> idle_soldier_rect · _deck_slots DELETED ·
                          _hull_rect loses its cap and slot arguments · the overlay and routes read
                          battle.boats, not _drag_boat · the ghost pass ·
                          set_time_scale + _fx_step aged by delta * k (5.4)
  src/look.gd             the six key constants and every HUD_BERTH_* + berth_rect_px +
                          HULL_BERTH_OFFSET_PX + COL_BERTH_EMPTY + BERTH_FX_SEC deleted ·
                          KEY_FX_SEC -> CHIP_FX_SEC · KEY_REFUSE_SHAKE_PX -> REFUSE_SHAKE_PX ·
                          the start button, the speed row, the idle-army stack and the ghost fan
  src/view/panel_view.gd  panel_active() becomes an allow-list (hardening — see 6.6)
  tests/nets/net_plan.gd  NEW — the planning state, the commit gate, formation order, sub-step
  tests/nets/            net_boat rewritten · net_battle · net_fx · net_fx_view · net_shell ·
                         net_islands · net_draw_leaf · net_camera patched
  tools/probe/run_run.gd  plan -> commit -> watch, and the new inversion rows

stage 2 — src/view/field_view.gd the ghost + idle-army passes · src/view/hud_view.gd the button and
          the speed row · src/look.gd the constants in 6.4 AND ZOOM_MIN + WATER_MARGIN_TILES +
          CLIFF_FACE_WIDTH_PX (6.3) · tests/nets/net_draw_leaf.gd the table and totals ·
          tests/nets/net_camera.gd the re-measured literals (6.3)
stage 3 — src/shell/game.gd the speed chips + set_time_scale/set_speed · src/view/hud_view.gd the
          speed row · src/view/field_view.gd the scaled fx clock (5.4) · src/sim/rules.gd
          SPEED_STEPS + SPEED_SLOT_DEFAULT · src/look.gd the chip rects only ·
          tests/nets/net_shell.gd · tests/nets/net_fx_view.gd the ladder rows (9.7)
stage 4 — src/sim/islands.gd rows only · tests/nets/net_islands.gd re-measured literals ·
          tools/probe/run_run.gd re-measure the 49% BASELINE under sub-stepping FIRST, then run
          and REPORT
```
⚠ **`TARGET_LINE_MAX_COUNT` moves in stage 4's edit, not stage 2's** — it is a consequence of the enemy
counts (6.2's box), and moving it early makes island 1's opening read differently for no reason.

**No new file under `src/view/`.** `net_draw_leaf` asserts that folder holds exactly three drawing files.
**No new file under `src/sim/` either** — the planning state is **one bool and one counter** on `Battle`,
which is already a `RefCounted` a net builds with `.new()`. That is deliberate: a new `class_name` file is
**invisible to `--headless --script` until an `--import` pass**, and adding none means `run_nets.ps1`'s
import guard has nothing to catch here.

⚠ **Cite this plan by NAME in comments — never by path and never by line number.** It changes folder with
its status, and `net_citations` greps `src/`, `tests/` and `tools/` for both shapes. **The new net file is
the likeliest offender.**
⚠ **`const X := PackedInt32Array([...])` does not parse.** `Rules.SPEED_STEPS` is a plain `const` Array
and every read casts.
⚠ **A `const` Array cannot be mutated at runtime.** Every table mutation below edits the source and
re-runs, and the two rounds must differ in the `[지문]` fingerprint by that edit alone.

### 3.1 `Rules.BOATS` — exactly what it becomes

**It is deleted whole, and so are all four of its accessors.** There is no boat table because there is no
boat identity to tabulate: a boat exists between one drag and one round trip, and every boat is the same
boat.

```gdscript
## rules.gd — how fast a boat crosses, tiles per second. The ONE surviving number of the old
## `BOATS` table: with unlimited boats there is no capacity column (a boat carries the one soldier
## that was dragged onto it), no name column (nothing distinguishes two boats) and no count
## (`boats` is as long as the player made it).
##
## ⚠ It is a rule constant and not a look constant because it sets the crossing time, which is the
## only thing between the commit and the first blow. **It is also the lever the deferred brake would
## be built from** — a departure interval is this number's sibling — so do not retune it as a feel
## value.
const BOAT_SPEED := 4.0
```

**Deleted with the table**: `boat_count()` · `cap_of()` · `boat_name_of()` · `boat_speed_of()`.
**Every one of their call sites moves**, and they are counted in 4.6.

⚠ **The old comment above `BOATS` states the throughput inequality `cap_fast × speed_fast < cap_big ×
speed_big`. DELETE IT; do not edit it.** With no capacity and no per-boat speed it is arithmetically
vacuous, and *a comment stating a refuted claim is worse than no comment.*

---

## 4. The sim

### 4.1 The plan is `boats` itself — there is no second structure

**A drop creates the boat immediately**, sitting at its harbour with `t == 0.0`. It does not move because
`step()` refuses before the commit (4.3). ⇒ **The plan and the fleet are one array**, and the user's
sentence — *"탁 놓으면은 그때부터 출발하는 거지"* — is literally true: from the drop the boat is on its
way, and only the clock is stopped.

```gdscript
## False until `commit()`. **`step()` refuses to do anything at all while it is false** — 4.3.
var _committed := false
## Monotonic boat id. `boats` entries carry "uid" instead of the deleted "boat" INDEX: with boats
## created on demand there is no fleet slot to index, and the view keys its per-boat effects by it.
## Never reused inside one island — a recalled boat's uid dies with it, so a stale reference cannot
## silently name a different boat.
var _next_boat_uid := 0
```

**That is the whole of the new state.** No `plan_tile`, no `plan_order`, no `queue`, no `pending`, no
`boat_at`. `setup()` zeroes all three of `_committed`, `_next_boat_uid` and `_substep_acc` — a leftover
carried across islands is a fraction of a frame of the previous island's fight, and `setup()` exists to
make a reused `Battle` indistinguishable from a fresh one.

**Why nothing flatter is needed.** The old plan argued for flat arrays so that *a soldier who dies leaves
every queue it is in* needed no bookkeeping. **With no queues that problem is gone**: a soldier is either
`RESERVE` (standing at the harbour), `TRANSIT` (in exactly one boat), `ASHORE` or `DEAD`, and
`_drop_from_boats` — which already exists — is the only cleanup. **`_drop_from_pending` is deleted.**

### 4.2 The API: `send` · `recall` · `commit`

| Was | Becomes | Why |
|---|---|---|
| `load_soldier(type_id) -> int` | **DELETED** | It picks both the soldier and the boat itself. 결정 3 is *"아무나 아무 데나"*, and the rule cannot be expressed through it at all |
| `launch(boat, tile) -> bool` | **folded into `send`** | There is no boat to launch; the drop makes one |
| `boat_busy(boat) -> bool` | **DELETED** | Membership in `boats` was the state of a fleet slot. There are no slots |
| — | **`send(soldier_id, tile) -> int`** | Returns the new boat's **uid**, or **-1** on refusal |
| — | **`recall(uid) -> bool`** | Free undo, 미정 12 |
| — | **`commit() -> bool`** · **`committed() -> bool`** | 4.3 |

**`send(soldier_id, tile)`** refuses (returns -1, **and nothing at all happens**) when:
`_committed` · `grid` or `army` is null · `soldier_id` is out of range · `soldier_state[soldier_id] !=
SoldierState.RESERVE` (dead, already sent, or already ashore) · `grid.home_harbour_for(tile) < 0` (no
harbour can reach that tile). Otherwise:

```
hb   = grid.home_harbour_for(tile)          # the nearest harbour that can SEE this landing
from = _point_of_tile(grid.harbour_tiles[hb])
to   = _point_of_tile(tile)
soldier_state[soldier_id] = TRANSIT ; soldier_pos[soldier_id] = from
boats.append({uid, phase OUTBOUND, speed Rules.BOAT_SPEED, from, to,
              dist max(from.distance_to(to), EPS), t 0.0, pos from,
              soldiers [soldier_id], target tile, home hb})
```

⚠ **`home_harbour_for` is the ONE predicate for both legs, and that is what buys OPEN 1 for free.** It
already returns *the nearest harbour among those that can still see the landing*, so a boat departs from
and returns to the same harbour by construction, and no mother ship has to exist for the round to close.
It also makes the droppable region the **union over every harbour** (미정 7) with no new table: `t` is
droppable iff `home_harbour_for(t) >= 0`.

⚠ **This widens the region and the widening is measured, not assumed.** `net_islands` pins start-sendable
counts of **47 · 38 · 46** against landable coasts of **82 · 76 · 80**. The union is bounded above by the
landable count and below by the start-sendable one; **`net_islands` gains one hand-measured literal per
island, `EXPECT_DROPPABLE`, and it is measured, never derived** (9.3).

**`recall(uid)`** refuses when `_committed`, or when no boat carries that uid. Otherwise it removes the
entry, sets every soldier aboard back to `SoldierState.RESERVE` with `soldier_pos = OFFMAP` — **exactly
what `setup()` left** — and returns true. ⇒ **Free undo is one call and cannot leave a duplicate**, which
is what makes 미정 12 structural rather than a rule someone has to remember.

⚠ **`recall` is not the inverse of `send` for a MOVED boat and must never be called on one.** Post-commit
it is refused by the `_committed` test; there is no other window in which a boat has `t > 0`.

### 4.3 The commit gate is a RULE, in `step()`, not a calling habit

`step()` has two guard lines today. **It gets a third — `if not _committed: return`.** ⚠ **The other two
do not survive unchanged**: 5.2 splits them, because one of them (`_outcome != Outcome.RUNNING`) has to be
answered per SUB-STEP and the rest per call. **5.2's code block is the one authority on the guard order.**

**Why here and nowhere else.** Without a state, "planning" exists only as *the shell choosing not to call
`step`* — a calling habit that every net, every probe and every future caller breaks silently. With the
guard, **an uncommitted `Battle` is inert to anybody who drives it.**

⚠ **`PLANNING` must NOT be added to `Battle.Outcome`.** `game.gd::_process` arms `_hold_sec =
Look.HOLD_OUTCOME_SEC` whenever `outcome() != RUNNING` immediately after `step`, so an `Outcome` member
would fire a verdict hold on frame one of every island and close it.
⚠ **And it must NOT be added to `Run.State`.** `panel_view.panel_active()` is `run.state() != BATTLE`, a
negative test; a new member makes it true, and then the reward panel paints a red 「패배」 band over the
planning screen **and** swallows every click, drag, pan and zoom. **One predicate, five failures.** `Run`
needs no change at all — 4.7.

⇒ **This one guard closes 미정 9 for free.** `_phase_clock` is the only writer of `elapsed`, so planning
costs zero seconds with no extra code. ⚠ **`islands.gd`'s `TIME_LIMITS` comment says the opposite in its
first sentence and already carries a ⚠ predicting this day.** Rewrite it in the same edit.

**`commit()`** refuses when already committed and when **`boats` is empty** — a start press that would
land nobody is a refusal with a shake, not a fight nobody can win. Otherwise it sets `_committed = true`
and **returns true, launching nothing**: every boat is already built and already at `t == 0.0`. That is
the point of 4.1 — the commit adds no motion of its own, it only lets the clock run.

### 4.4 ⚠ How far 「순서」 is load-bearing under unlimited boats — **timing dies, formation survives**

**The design doc's probe verified that the sim reads boat order nowhere, and the reversal makes half of
that permanent.** All four candidate paths, re-derived against `send()`:

- **Departure time**: every boat is at `t == 0.0` when the commit lands, so **all boats depart on the
  same frame.** There is no departure-time field and OPEN 0 deliberately does not add one. ⇒ **dead.**
- **Arrival time**: `dist / Rules.BOAT_SPEED`. Pure geometry. ⇒ **dead as an order axis.**
- **Aggro**: `_nearest_enemy` / `_nearest_soldier` replace only on `d < best_d - EPS`, so ties go to the
  smaller **soldier id**, never to drop order. ⇒ **dead.**
- **Tile reservation on landing**: ⚠ **ALIVE, and it is bigger than it was.** `_try_unload` calls
  `_free_tiles_from(target, 1)`, which breadth-firsts out from the target collecting tiles with
  `passable != 0 and reserved == -1`, and it **writes `grid.reserved` as it lands each soldier.** Two
  boats aiming at the **same tile** from the **same harbour** have identical `dist` and identical
  `speed`, so they arrive on **exactly the same sub-step** — the sim is deterministic and carries no
  randomness (`grep` for rand in `src/sim/` returns 0 hits, and two controlled runs match to the
  decimal). ⇒ **whoever unloads first stands on the target tile and the next stands on the BFS-next.**

> ### ⇒ **What order therefore means, in one sentence, and it is the only thing a picture may claim**
>
> **The order you drop decides who stands in FRONT when several boats aim at one beach.**
> Not who leaves first, not who arrives first, not who is targeted first.

**Why this is worth building rather than deleting.** Under OPEN 0 the dominant plan is *everything at the
cheapest beach* — which means **many boats aiming at one or two tiles is the common case, not the corner
case.** A 13-body drop onto one tile spreads over a BFS disc of radius ~2 tiles, and "melee first so the
ranged land behind them" versus "ranged first" is expressed entirely by the drop sequence. **This is a sim
quantity, and 9.1 measures it on a real island fixture, not a synthetic one.**

⚠ **The one thing order does today is BACKWARDS and must be fixed in the same edit.** `_phase_landings`
walks `boats` from the end down to 0 — descending, so `boats.remove_at(i)` is safe — and **the
later-dropped boat therefore unloads first.** That is the exact opposite of *"the order you drop them is
the order"*. **The descending walk cannot simply be reversed; it is load-bearing for the removal.**
⇒ **Split the pass in two.** First, collect the indices of arrived OUTBOUND boats, **walk them ASCENDING**
(`boats` append order IS drop order) and run `_try_unload` — this pass removes nothing. Second, walk
descending as today for the RETURNING arrivals, which is where `remove_at` lives.

> ### ⚠ What is NOT built, and must not be drawn as if it were
>
> - **No order glyph.** The old plan's `_paint_number`, `PLAN_ORDER_FONT_SIZE_PX` and `COL_PLAN_ORDER`
>   are **dropped from this round entirely.** A big number over a quantity whose whole meaning is
>   "you are 40 px further forward" is *"screen changes but sim doesn't"* with extra steps.
>   **The picture that carries the order is the ghost fan** (6.1): ghosts stack in drop order, so the
>   front of the stack is the front of the landing. Same information, no glyph, no claim.
> - **No order handle.** 미정 11's answer is the drop sequence and nothing else — the user closed it:
>   *"대기열이라는 게 사실 좀 애매해."*
> - ⚠ **If stage 4's probe finds that reversing the drop order changes nothing measurable**, say so in
>   the report and **leave the fan** — it costs nothing and it is honest about being a picture of the
>   input. **Do not add a glyph to compensate**, and **do not add a departure delay to give order teeth**;
>   that is OPEN 0's brake and it is the user's call, not a builder's.

### 4.5 The round trip — **「배는 왕복」**, and it ends there

`_phase_landings`' RETURNING branch already sails the empty boat to `grid.home_harbour_for(target)`.
**Two changes and no more:**

1. The arrival branch **no longer writes `boat_at`** (deleted) — it just does `boats.remove_at(i)`.
   **The boat ceases to exist.** There is nothing to reload and nothing to re-launch.
2. **No automatic re-launch.** The pre-reversal plan's open question A is answered by the reversal: with
   unlimited boats every soldier already has one, so a second wave is not a thing the sim has to arrange.

⚠ **The return leg stays simulated and drawn, and that is not decoration.** The user asked for it
(*"배는 왕복"*), it is the only thing on screen that says a crossing costs something, and **it is the hook
OPEN 0's sail-time brake would hang on.** Deleting it would have to be undone the day a brake lands.

### 4.6 The call sites that move — **counted, including the ones that are not tests**

**`Rules.boat_count()`** — `battle.gd` ×4 · `game.gd` ×2 · `field_view.gd` ×1 · `hud_view.gd` ×2 ·
`run_run.gd` ×3 · `net_boat` ×1 · `net_islands` ×1 · `net_shell` ×5.
**`Rules.cap_of()`** — `battle.gd` ×1 · `field_view.gd` ×2 · `hud_view.gd` ×1 · `run_run.gd` ×1 ·
`net_boat` ×3 · `net_islands` ×1 · `net_shell` ×5.
**`Rules.boat_speed_of()`** — `battle.gd` ×1 · `net_boat` ×4. **`boat_name_of()`** — `hud_view.gd` ×1.
**`battle.pending`** — `battle.gd` ×7 · `game.gd` ×1 (`_boat_grabbable`) · `hud_view.gd` ×1 (`_draw`) ·
`run_run.gd` ×2 · `net_shell` ×4. **`battle.boat_at`** — `battle.gd` ×5 · `field_view.gd` ×3 ·
`run_run.gd` ×2.

⚠ **Two of those are production readers that a test-only inventory would miss, and one changes the
feature rather than a name:**

- **`game.gd::_boat_grabbable` and `_boat_hit_at` are DELETED, not patched.** They test a berth rect and
  an idle hull rect for a **fleet slot**, and there is no fleet. They are replaced by
  **`_soldier_hit_at(at) -> int`** (which un-sent soldier's drawn rect is under the cursor) and
  **`_ring_hit_at(at) -> int`** (which placed boat's landing ring is under the cursor, for `recall`).
  ⚠ **Both must read the EXACT rect that reaches the screen** — `field_view.idle_soldier_rect(i)` and the
  ring's own centre and radius — never a re-derived anchor. *A hand-rolled hit test that tested a tile
  index instead of the drawn rect once left ~70% of a hull dead to a press.*
- **`hud_view.gd::_draw` reads `battle.pending[b]` to build the berth label.** The whole berth section is
  deleted (6.1), so this reader dies with it rather than being renamed.

⚠ **The old `if battle.load_soldier(...)` trap inverts.** `send` returns an **int uid**, so
`if battle.send(i, t):` is a bug — **uid 0 is falsy**. **Every call site must compare `>= 0`.** `recall`
and `commit` return real bools. ⚠ **uid 0 is the first boat of every island, so this is the common case,
not the rare one.**

### 4.7 What `Run` needs: nothing

`begin_island()` opens `if _state != State.BATTLE: return null`, and `game.gd::_open_island` deliberately
leaves `battle` alone when it gets null. **The planning window is simply the gap between `_open_island`
and the first committed `step`**, with the run still in `BATTLE` the whole time. ⇒ **No `Run.State`
member, no change to `restart()`.**

---

## 5. The speed multiplier — built so that it changes nothing

**This whole section survives the reversal untouched.** It is about the clock, not about the boats.

### 5.1 The audit: five things in `step` are per-STEP, not per-second

⚠ **Derived by reading the code, and the derivation is the reason for 5.2.**

| Where | What is per-step | What `step(dt × k)` does to it |
|---|---|---|
| `_phase_attacks` | A cooldown drains linearly but is **reset to the whole period on fire** — the overshoot is discarded, and at most one blow lands per step per unit | Effective cycle becomes `ceil(period/dt) × dt`. **The error is not monotonic in `k` and it is asymmetric between the player and the boss** |
| `_phase_landings` | On the OUTBOUND→RETURNING turn `t` is set to 0.0 after `from`/`to`/`dist` are rebuilt — the excess travel is thrown away | Each leg transition discards up to `dt × speed` tiles of progress |
| `_phase_targeting` · `_phase_deaths` | Take no `dt` at all. Retargeting and death latching happen exactly once per step | A unit chases a stale target for `k` times longer in simulated time, and staggered deaths land in one batch |
| `_phase_movement` | `_walk` calls `grid.step_toward` once per tile crossed, and `step_toward` writes `grid.reserved` | A fast unit claims and releases several tiles before anyone else has moved; **reservation contention resolves by iteration order far more strongly than at 1×** — and 4.4 just made that contention load-bearing |
| `_age_fields` | Linear in `dt`, but `FIELD_TTL` is 0.5 | At `dt >= 0.5` every flow field rebuilds every step — a 1536-tile BFS per requested target per frame |
| **the outcome guard** | `_outcome != Outcome.RUNNING` is answered **once per call** | A verdict latched partway through a long `dt` does not stop the rest of that call — 5.2's box |
| **the view clock** | Nothing in `step` — but `field_view._process(delta)` and `hud_view._process(delta)` age every drawer with the **real** frame delta | Every `look.gd` duration keeps its real-time length while the interval it is budgeted against shrinks by `k` — **5.4** |

⇒ **A speed widget implemented as `battle.step(delta × k)` and nothing else does not speed the game up.
It plays a different game.** And the direction is the worst one available: the boss's long period loses a
larger fraction than the cells' short one, so **speeding up is a quiet buff to the player.**

### 5.2 ⇒ `step` sub-steps internally, and the multiplier becomes arithmetically inert

```gdscript
## rules.gd — the discretisation the whole fight is computed at. It changes WHAT HAPPENS (every row
## in the per-step table above is measured against it), so it lives here and not in look.gd.
const SIM_SUBSTEP_SEC := 1.0 / 60.0
```

**`Battle` carries the leftover; `step` runs WHOLE sub-steps only and never a remainder.**

```gdscript
var _substep_acc := 0.0

func step(dt: float) -> void:
    if grid == null or army == null:        # per-CALL facts, answered once
        return
    if not _committed:
        return
    if dt <= 0.0:
        return
    _substep_acc += dt
    while _substep_acc >= Rules.SIM_SUBSTEP_SEC:
        if _outcome != Outcome.RUNNING:     # <- INSIDE. See the box below
            break
        _substep_acc -= Rules.SIM_SUBSTEP_SEC
        <the seven phases>(Rules.SIM_SUBSTEP_SEC)
```

⇒ **Every sub-step is exactly `h`, so the decomposition is additive over ANY sequence of `dt`s.**

> ### ⚠⚠ Two things the first draft of this section got wrong, and the arithmetic that shows it
>
> **① "The guards stay outside the loop" would have let a decided island keep fighting.** Hoisted out,
> a WIN latched on sub-step 3 of 6 lets 4, 5 and 6 run `_phase_attacks`, `_phase_deaths` and
> `_phase_clock`. **`army` carries to the next island and death is permanent**, so a soldier could die
> *after* the island was already won — at 6× and not at 1×. ⇒ **The test moves inside as a `break`. The
> null and `dt <= 0.0` tests stay outside — those are per-call facts.**
>
> **② The "whole sub-steps plus one remainder" shape is not additive, but NOT for the reason offered.**
> An attack predicted 120 versus 70 phase passes per simulated second at k = 6, on the grounds that
> `6.0/60.0 / (1.0/60.0)` is `6.0000000000000008`. **Measured in IEEE double: `6 × (1.0/60.0) == 0.1`
> exactly, `0.1 / (1.0/60.0) == 6.0` exactly, remainder exactly `0.0`.** That specific number is refuted.
> ⚠ **The structural half stands**: `_phase_targeting`, `_phase_landings` and `_phase_deaths` take **no
> `dt` at all**, so a remainder pass is a free extra retarget/death-latch, and in the shipped shell the
> remainder is never zero — `_process` hands `battle.step(delta * k)` a vsync delta, and `net_shell`
> already records a headless frame at 6.9 ms. ⇒ **Carrying the leftover removes the whole class.**
> ⇒ **9.1 gains the two rows that can actually fail this**: an **uneven, non-multiple** `dt` sequence at
> 1× against the same sequence scaled by `k` at `k`×, and a **sub-step COUNT** asserted equal.

⚠ **What this does NOT fix**: the leg-transition remainder and the one-blow-per-step ceiling still exist
**at 1×**, unchanged. What changes is that **they no longer vary with the widget.**

⚠ **Cost**: at 6× and a 16.7 ms frame this runs six sub-steps a frame over ~25 units. **`net_plan`'s
equivalence rows step a whole island twice, so every `while outcome() == RUNNING` in that file carries an
explicit step counter and asserts it.** `run_nets.ps1` kills a net at 120 s, reports it red and **zeroes
its pass count**, and a hung net disarms mutation testing on the entire file.

### 5.3 The ladder — and why these five numbers

**The ladder lives in `rules.gd`, beside `SIM_SUBSTEP_SEC`, and NOT in `look.gd`.**

```gdscript
## rules.gd — the rates the fight may be computed at. Every step ABOVE zero is arithmetically inert
## under SIM_SUBSTEP_SEC and changes only whether the picture can be read.
## ⚠ 0x IS NOT A VIEWING RATE. `step` returns on `dt <= 0.0` before `_phase_clock`, which is the only
## writer of `elapsed` — and `elapsed` is the loss condition. This table decides whether the island's
## clock advances, so it is a constant that changes WHAT HAPPENS and it belongs in this file.
const SPEED_STEPS := [0.0, 1.0, 2.0, 3.0, 6.0]
## The slot the shell opens every island at. Pinned to the 1x entry by a net, never to a bare 0.
const SPEED_SLOT_DEFAULT := 1
```

> ### ⚠ Why it is not in `look.gd`, written down so nobody moves it there
>
> A draft put it in `look.gd` under a comment reading *"a viewing rate… it changes nothing about what
> happens."* **Slot 0 is 0.0**, `step` returns at `if dt <= 0.0: return` before `_phase_clock`, and
> `_phase_clock` is the sole `elapsed += dt` and the sole writer of `Lose.TIMEOUT`. ⇒ **that comment
> states the opposite of what the code does. Nothing would have caught it**: `net_draw_leaf`'s literal
> sweep covers `src/view/` and `src/shell/`, and `look.gd` is scanned by no rule that reads a comment.

- **0× is the pause** (미정 4). One widget, one row, and **the pause carries no verb.**
- **2, 3 and 6 are exact divisors of every period in the game** — 1.0 (cells and the crow), 1.5 (the
  lion), 2.0 (the bison) and the lion's 0.6 s wind-up. **Belt-and-braces on top of 5.2**, so a future
  edit that removes the sub-step by accident does not silently start changing outcomes.
- **The ceiling is 7×, derived and honoured.** `Rules.LION_WINDUP_SEC` is 0.6 s and this repo has measured
  a beat under five frames going entirely unseen ⇒ `0.6 × 60 / 5 = 7.2`. **6× puts the telegraph at six
  rendered frames.**
  ⚠⚠ **This was the ONLY constant the ceiling was derived from, and that is exactly why it found
  nothing.** The telegraph is drawn from sim STATE (`enemy_windup`), so it is the one timed item that
  scales with `k` on its own — **every view-OWNED countdown was left out, and three of them break.** 5.4
  is that omission repaired.
- **4× and 5× are deliberately absent** — the divisor argument, not the ceiling.

**Where the number lives**: `game.gd` holds `var _speed_slot := Rules.SPEED_SLOT_DEFAULT` — **an index
into the ladder, never the float.**

⚠⚠ **The default is NOT slot 0.** A shell that opens there calls `step(0.0)` every frame and **the fight
is frozen from the moment the start button is pressed.** ⇒ `SPEED_SLOT_DEFAULT` is **pinned by a net to
the index whose value is 1.0**, and 9.5 carries a row that pumps frames with **no chip pressed** and
asserts `battle.elapsed > 0.0`.
⚠ **A field named `_speed_mul` or `_speed` in `game.gd` reddens `net_draw_leaf`'s widened literal scan**
(`mul` and `speed` are both in `TIME_SUFFIXES`). **`_speed_slot` ends in `slot`, which is in neither
list. Do not evade the scan with a type annotation — there is a name that is simply correct.**

⚠ **At 0× the shell must still call `step(0.0)`**, not skip it — one path handles pause, and two tests
for one fact diverge.

### 5.4 ⚠⚠ The VIEW clock takes the same multiplier — and it is the half that was missing

**5.2 makes the sim inert under `k`. It does nothing at all to the picture, and the picture is where the
damage is.** Three of `look.gd`'s own written inequalities break at 6×, where `CELL_MELEE` and the crow
both fire on a 1.0 s period:

| Constant | What its own comment claims | What happens at k = 6 (period 1.0 s → 0.1667 real s) |
|---|---|---|
| `HIT_FLASH_SEC` `0.14` | *"14% duty against the 1.0 s attack period"* | **84% duty** — every body is permanently white-tinted |
| `LUNGE_SEC` `0.18` | *"exactly 0 at both ends, so no body is ever left sitting displaced"* | 0.18 > 0.1667, and `_lunge_offset` is reset to full on every attack ⇒ **no melee body ever returns to rest** |
| `SPARK_SEC` `0.12` | *"8 neighbours × (SPARK_SEC / 1.0 s period) must stay under 1.0"* | `8 × 0.12 / 0.1667 = 5.76`. One body's rim is never clean |

⇒ **`field_view` and `hud_view` age their drawers by `delta × k`, not by `delta`.**

- **The shell owns the number and hands it down**: `field_view.set_time_scale(k)` and
  `hud_view.set_speed(slot, k)` from `_process`, read before `_fx_step`. **A view must not read
  `Rules.SPEED_STEPS` itself.**
- **At `k = 0` the views freeze too** — the pause is a still frame, not a still sim under a running
  animation.
- ⚠ **Capping the ladder instead is not an option**: `LUNGE_SEC 0.18 < 1.0/k` gives k ≤ 5, and
  `SPARK_SEC`'s eight-neighbour bound gives **k ≤ 1.04**, which deletes the ladder.
- ⚠ **No net sees any of this today.** ⇒ **`net_fx_view` gains a row per ladder step** — 9.7.

---

## 6. The screens

**Three constraints from the design doc govern both**: a picture before a glyph · anything you press is
**visibly larger** than today's key boxes (150 × 26 px) · no sentences.

### 6.1 The planning screen — what is on it, and what says each rule fired

| # | What | How it is drawn | The rule it makes visible |
|---|---|---|---|
| **P1** | **The whole island, framed further back** | `field_view.setup()` already sets `zoom = Look.ZOOM_MIN` and calls `_clamp_cam()`, which **centres** an axis whose map is narrower than the visible world. **The framing function already exists; only the constant moves** — 6.3 | the camera |
| **P2** | **Every enemy, visible** | Unchanged. The GDD already decided 「첫 초원은 처음부터 다 보인다」 | — |
| **P3** | **The droppable region** — the whole green coast, always, not only while dragging | `_paint_overlay(rects, Look.sendable_tint())` fed from the union `home_harbour_for(t) >= 0`. **Already-built leaf, and the SAME predicate `send` answers to**, so the screen cannot promise a tile the sim refuses. ⚠ **Drawn from the moment the island opens** — the user's *"바다위에 초록색 지역"* is a standing invitation, not a hover state | `home_harbour_for` |
| **P4** | **The un-sent army, standing at the harbour** | `_paint_body` + `_paint_hp`, one per `RESERVE` soldier, laid out by **`idle_soldier_rect(i)`** in a stack going up from `grid.start_harbour`'s tile. **Zero new leaves.** This is what you drag | `soldier_state` |
| **P5** | **One route per sent boat**, its own harbour to its landing — all of them at once | `_paint_route(from, to, colour, width)`, one call per entry of `battle.boats`. **This is the "whole plan on one page"**, and it also shows WHICH harbour each boat leaves from | `boats[i].from/to` |
| **P6** | **A ring on each landing tile** | `_paint_ring(centre, radius, colour, width)`, same call site. **It is also the `recall` hit target** (section 7) | `boats[i].target` |
| **P7** | **A ghost body at each landing, fanned in DROP ORDER** | `_paint_body` at `Look.tile_point_px(boat.to) + k × Look.GHOST_FAN_PX`, dimmed. **Zero new leaves.** `k` is the boat's index in `boats`, i.e. the drop sequence ⇒ **the front of the fan is the front of the landing**, which is exactly and only what 4.4 says order means | drop order |
| **P8** | **One large start button** | `_paint_button` (the renamed `_paint_key`; rect + string, 2 draws) | `commit()` |
| **P9** | **A refused gesture** | The drag ring is already `COL_WIN` / `COL_LOSE` per tile — **already built, already netted.** A refused **start** shakes the button: `note_chip(0, false)` | the refusal |

> ### ⚠⚠ What was DELETED from this screen by the reversal, and why each deletion is load-bearing
>
> - **The five berth rows and their queue chips.** There are no berths. `_paint_berth`, `_paint_load`,
>   `berth_rect_px`, every `HUD_BERTH_*`, `COL_BERTH_EMPTY`, `BERTH_FX_SEC`, `_berth_offset` and
>   `note_launch` all go.
> - **The HUD roster strip.** OPEN question A: the army stands on the map instead. **Drawing it twice —
>   once as bodies at the harbour and once as chips in a strip — is the same value under two names**,
>   which `look.gd`'s own header forbids, and it would spend the chrome budget 6.3 just bought.
> - **The order number** (`_paint_number`, `PLAN_ORDER_FONT_SIZE_PX`, `COL_PLAN_ORDER`). 4.4's box.
>   ⇒ **`field_view` gains no new leaf in this round at all**, which is the strongest evidence that the
>   reversal made the screen smaller rather than larger.
> - **The idle hulls at the harbours** (`idle_hull_rect`, `HULL_BERTH_OFFSET_PX`, `_deck_slots`). A hull
>   is what a soldier rides AFTER the start; before it, what stands at the harbour is the army.

**Glyph budget, counted rather than asserted**: the timer + 적 N + the start label + 5 speed chip labels
= **8 text items**, against today's 2 berth labels + 2 key labels + timer + 적 N = **6** — **and the
pre-reversal version of this screen would have been 26.** The acceptance row asks for the number written
down, so write this one down after building and correct it if it is wrong.

### 6.2 The execution screen — behind the start button

| What | How |
|---|---|
| **The plan runs as drawn** | The same route lines and rings stay on screen. **A different picture means the plan lied** |
| **The unspent plan stays visible** | ⚠ **Load-bearing, not decoration.** A route is drawn while its boat is in `boats`, and disappears with the boat. Without it *"why is that one still at sea"* has no answer on screen |
| **The ghosts become passengers** | The ghost pass is drawn only while `not battle.committed()`; after the commit the existing transit-body pass draws the real soldier on its hull. **One `if`, one fact** |
| **What can be pressed** | **The speed chips. Nothing else.** All three plan branches gate on `battle.committed()` — section 7 |
| **The clock** | As today, and it starts moving on the commit frame and not before |
| **The twelve `combat-juice` items** | **Removing the controls kills none of them** — every one is view-side and driven by `Battle.events`. ⚠ **But two other things in this round do reach them, and both are below** |
| **The start button** | **Gone from the screen the moment `committed()` is true.** A button that cannot be pressed and is still drawn is the *"well, while we're stopped…"* door |

> ### ⚠⚠ "All live" is false in two places
>
> **① Item 6 (enemy target lines) is gated on `enemies_left() <= Look.TARGET_LINE_MAX_COUNT`, which is
> 8.** That constant's own comment reads *"⚠ THIS NEVER BITES IN PLAY. The three islands hold 4, 6 and 5
> enemies"*. ⇒ **Section 8 raises the counts to 8 · 12 · 14 and the guard bites for the first time
> ever**: islands 2 and 3 draw **zero** intent lines until 4 and 6 enemies are dead — the opening of the
> fight, which is precisely the phase where the hand cannot move and the player can only read.
> ⇒ **Raise `TARGET_LINE_MAX_COUNT` to 14, in the same edit as the counts.** verify-look scores it; if 14
> lines read as noise the number comes back down and `combat-juice` records the measurement.
> ⚠ **The refutation goes into `combat-juice` AND `combat-juice`, not here** — that is where the claim
> lives, and a refutation that lands in a different doc does not propagate. Section 15 carries the row.
>
> **② Every timed effect in `look.gd` is measured against the attack period, and the speed ladder moves
> the period and not the effect.** That is 5.4, and it is a blocker rather than a note.

### 6.3 ⚠ The camera — **the user asked for it further back, and one constant does it**

> **「조금 더 카메라를 뒤로 빼야 될」**

**The function that frames the island already exists and needs no new call.** `field_view.setup()` sets
`zoom = Look.ZOOM_MIN` and calls `_clamp_cam()`; `_clamp_cam()` **centres** any axis where the map is
narrower than the visible world, and clamps the other. ⇒ **The framing is a constant, not a code path,
and no plan-screen framing function has to be written.**

**Measured on the shipped numbers.** Map = `GRID_W 48 × GRID_H 32 × TILE_PX 40` = **1920 × 1280 world px**;
viewport 1280 × 720.

| | at `ZOOM_MIN` 0.5625 (today) | at `ZOOM_MIN` **0.45** (this plan) |
|---|---|---|
| visible world | 2275.6 × **1280.0** | 2844.4 × **1600.0** |
| island on screen | 1080 × **720** — the full height, **zero vertical margin** | 864 × **576** |
| x band | 100 … 1180 | 208 … 1072 |
| y band | **0 … 720** | **72 … 648** |
| `_clamp_cam` behaviour | x centred, **y clamped to a zero-length range** | **both axes centred** |
| one tile | 22.5 px | **18.0 px** |
| smallest body (ranged, `BODY_RADIUS_RATIO` 0.25 ⇒ 20 px across) | 11.3 px | **9.0 px** |

⇒ **`Look.ZOOM_MIN` 0.5625 → 0.45.** Floor **0.40** — below it the smallest body drops under 8 px, and
**`net_camera` already carries that row and that reason** (`ZOOM_MIN 은 0.4 이상이다 — 못 미치면 14px 몸이
6px 밑으로 준다`). Ceiling **0.50** — at 0.5625 the island touches both screen edges with **zero** vertical
margin, which is the framing the user asked to move back from; 0.50 leaves one tile of margin top and
bottom and is the loosest value that is visibly further back.

> ### ⚠⚠ Lowering `ZOOM_MIN` reddens TWO existing checks, and one of them is a real defect
>
> **These are not incidental literal churn. Chase both.**
>
> - **`net_camera::_painted_area_covers_the_viewport` goes RED**, and it should. The terrain loop paints
>   `WATER_MARGIN_TILES` of water outside the grid; at 0.45 the visible world runs from **x = −462.2**
>   (`(1920 − 2844.4) / 2`) and **y = −160.0**, i.e. **11.6 tiles** of bare ground on the x axis against a
>   margin of **5**. ⇒ **`WATER_MARGIN_TILES` 5 → 12** (11.6 rounded up, plus `SHAKE_MAX_PX` 6 px =
>   0.15 tile). Floor **12**; ceiling **16**.
>   ⚠ **Cost, and it must be measured rather than assumed**: the terrain loop goes from `58 × 42 = 2436`
>   tiles to `72 × 56 = 4032`, and `_paint_tile` is **2 draw calls**, so **4872 → 8064 draw calls a
>   frame.** *300 `Node2D`s cost 0.065 ms here — the engine was never the wall* is this repo's own
>   measurement about NODES, not about immediate-mode calls, and it may not be cited for this.
>   **verify-run reports the frame time; if it moved, the alternative is one filled rect behind the grid
>   instead of a per-tile loop**, which is a `_draw()` change and a `net_draw_leaf` table change.
> - **`look.gd`'s `CLIFF_FACE_WIDTH_PX` comment goes false and the constant moves with it.** Its own
>   text: *"at `ZOOM_MIN` it is 2.25 px, so the floor of 3 is what it has to clear to still read zoomed
>   out"*. At 0.45 a 4.0 px line draws at **1.8 px**. ⇒ **4.0 → 5.0** (2.25 px at the new `ZOOM_MIN`, the
>   value the comment's own floor was derived from). Floor **5.0**; ceiling **8** (the existing one).

**And the chrome no longer needs a coordinate fix, because it has a structural one.** At 0.45 the island
occupies x 208…1072, y 72…648. The start button is **bottom-LEFT** (x 24…244) and the speed chips are
**bottom-RIGHT** (x 1060…1260), so between them the **bottom-centre band is clear** — and all three
islands put `start_harbour` on the bottom centre (`EXPECT_WAVE1`'s island-1 minimum is
`distance((24,31), (28,20))`). ⇒ **the thing you drag is never under chrome, by layout rather than by
luck**, and 9.5 carries the row that measures it: **every `idle_soldier_rect` and every harbour dock rect,
at `ZOOM_MIN`, is disjoint from every HUD chrome rect.** The two corners chrome does cover are grid
corners in the last row.

⚠ **An 18 px tile is a small drop target and the mitigation is already shipped**: the camera is
unrestricted before the commit, so one wheel notch to `ZOOM_MIN × ZOOM_STEP` puts a tile at 20.7 px and
four notches at 31.5 px. **verify-look scores whether the un-zoomed drop is comfortable; if it is not, the
answer is `ZOOM_STEP`, not a bigger ring.**

### 6.4 Every new constant, and both of its ends

**All of them in `look.gd`** — except `BOAT_SPEED`, `SPEED_STEPS`, `SPEED_SLOT_DEFAULT` and
`SIM_SUBSTEP_SEC`, which are `rules.gd` and 3.1 / 5.3 explain why. ⚠ **Each is a first value to be
re-measured by eye**, and each row carries a **floor as well as a ceiling** — *a ceiling with no floor
passes an effect that never happens* was earned on four items at once in the presentation round.
⚠ **A pair of bounds is only a pair if it brackets ONE quantity**: two constraints on different axes read
as two ends and are not.

| Constant | Value | Floor | Ceiling |
|---|---|---|---|
| `HUD_START_ORIGIN_PX` | `Vector2(24.0, 632.0)` | y ≥ 560 — the "not floating in the middle of the screen" bound | y + `HUD_START_SIZE_PX.y` ≤ 720 |
| `HUD_START_SIZE_PX` | `Vector2(220.0, 64.0)` | **strictly larger than the old key box (150, 26) on both axes** — it is the one press that ends the planning phase | ≤ (320, 96), or it reaches the speed row |
| `HUD_START_TEXT_OFFSET_PX` | `Vector2(70.0, 42.0)` | **> (0, `HUD_START_FONT_SIZE_PX`)** — a glyph at the rect's own origin is a glyph that was never placed, and **that floor is the half proving the label exists at all** | `x + label width ≤ HUD_START_SIZE_PX.x` and `y ≤ HUD_START_SIZE_PX.y` |
| `HUD_START_FONT_SIZE_PX` | 28 | > `HUD_FONT_SIZE_PX` (18) | ≤ `HUD_TIMER_FONT_SIZE_PX` + 8 |
| `HUD_SPEED_ORIGIN_PX` | `Vector2(1060.0, 648.0)` | x ≥ 1000 — clear of the start button with the island band between them | `x + 5 × size.x + 4 × gap ≤ 1280` |
| `HUD_SPEED_SIZE_PX` | `Vector2(36.0, 40.0)` | ≥ (30, 30) — a touchable chip | ≤ (48, 48) |
| `HUD_SPEED_GAP_PX` | 5.0 | ≥ 3 — two chips must not read as one bar | ≤ 10 (five chips + four gaps ≤ 220) |
| `IDLE_SOLDIER_PITCH_PX` | 34.0 | **≥ 30** — a melee body is `0.35 × 40 × 2 = 28` px across, so anything smaller overlaps its neighbour | ≤ 48, or 7 across is 7 tiles wide and the stack covers the harbour's own approach |
| `IDLE_SOLDIER_COLS` | 7 | ≥ 5 — **13 soldiers in fewer than 5 columns is 3 rows and the stack walks off the bottom edge** | ≤ 9, or the row is wider than 8 tiles and reaches the neighbouring coast |
| `IDLE_SOLDIER_ORIGIN_PX` | `Vector2(-102.0, -48.0)` | offset from the harbour tile centre; y ≤ −40 — **the stack sits ABOVE the harbour, because a harbour is on the bottom row of all three islands and below it is off-map** | `abs(x) ≤ 3 × TILE_PX` and `abs(y) ≤ 3 × TILE_PX` — the stack must read as *at* the harbour |
| `GHOST_FAN_PX` | `Vector2(9.0, 9.0)` | **≥ (6, 6)** — below that two ghosts are one blob and drop order has no picture at all, which is the floor 4.4 depends on | ≤ (14, 14), or 13 ghosts span 168 px = 4 tiles and stop reading as *one* landing |
| `GHOST_ALPHA` | 0.55 | **≥ 0.35** — dimmer than that and the plan is invisible, which deletes this design's stated survival condition | ≤ 0.75, or a ghost is indistinguishable from a landed body |
| `ZOOM_MIN` | **0.5625 → 0.45** | **≥ 0.40** (existing `net_camera` row: the smallest body under 8 px) | **≤ 0.50** — above it the island stops having visible margin (6.3) |
| `WATER_MARGIN_TILES` | **5 → 12** | **≥ 12** — `(2844.4 − 1920) / 2 / 40 = 11.6` tiles of bare ground at the new `ZOOM_MIN`, plus the shake | ≤ 16 — `80 × 64 = 5120` tiles is 10240 draw calls a frame |
| `CLIFF_FACE_WIDTH_PX` | **4.0 → 5.0** | ≥ 5 — 2.25 px at the new `ZOOM_MIN`, the value its own comment derived the old floor from | ≤ 8 (existing) |

**New colours**: `COL_START` · `COL_SPEED_ON`.
⚠ **Reuse rather than add, wherever the concept already has a value.** The routes and rings use
`COL_ROUTE` and `COL_DROP_OK`/`COL_DROP_NO`; the droppable tint uses `COL_SENDABLE` and `DROP_TINT_ALPHA`;
a resting chip uses `COL_BUTTON`. **The same value under two names is what `look.gd`'s own header
forbids** — which is why **a ghost gets no colour of its own**: it is `COL_ALLY` at `GHOST_ALPHA`, exposed
as **`Look.ghost_tint()`** beside the existing `sendable_tint()`.

**Renames, not deletions**: `KEY_FX_SEC` → **`CHIP_FX_SEC`** · `KEY_REFUSE_SHAKE_PX` →
**`REFUSE_SHAKE_PX`**. ⚠ **`_berth_offset` was the second reader of the shake constant and it is now
deleted**, so `REFUSE_SHAKE_PX` has exactly one reader (the start button). **That is fine, but it means
deleting the start-button shake deletes the constant's last reader** — 9.5 pins both ends of the shake.

**Deleted outright**: `HUD_KEY_ORIGIN_PX` · `HUD_KEY_SIZE_PX` · `HUD_KEY_GAP_PX` ·
`HUD_KEY_TEXT_OFFSET_PX` · `key_rect_px` · `HUD_BERTH_ORIGIN_PX` · `HUD_BERTH_SIZE_PX` ·
`HUD_BERTH_ROW_PX` · `HUD_BERTH_LABEL_OFFSET_PX` · `berth_rect_px` · `HULL_BERTH_OFFSET_PX` ·
`COL_BERTH_EMPTY` · `BERTH_FX_SEC`. **Thirteen.**

**New statics in `look.gd`**: `start_rect_px()` · `speed_rect_px(i)` · `ghost_tint()` ·
`idle_soldier_offset_px(i)`.
**New statics in `rules.gd`**: `speed_slot_count()` · `speed_mul_of(i)`. ⚠ **Not in `look.gd`** — 5.3.
⚠ **`Look.button_rect_px()` must NOT be reused for the start button.** `panel_view.button_hit` already
owns that rect for restart, and one rect answering to two verbs is how a restart gets pressed by someone
aiming at start.

### 6.5 The hook table moves — `net_draw_leaf._table()` is the authority

| File | Change | Functions | Leaves |
|---|---|---|---|
| `field_view.gd` | **+ `set_time_scale`** (0 draws, 5.4) · **− `_deck_slots`** (a one-soldier deck is the hull centre) · **rename `idle_hull_rect` → `idle_soldier_rect`** (still 0) · `_hull_rect` loses its `cap`/`slot` arguments (still 0) | 43 → **43** | 14 → **14** |
| `hud_view.gd` | **− `key_slot_count` · `key_type_of` · `reserve_count` · `boat_label` · `note_launch` · `_berth_offset` · `_paint_berth` · `_paint_load`** · **+ `set_speed`** (0) · renames `note_key`→`note_chip`, `_key_offset`→`_chip_offset`, `_key_colour`→`_chip_colour`, `_paint_key`→`_paint_button` (still 2) | 20 → **13** | 5 → **3** |
| `panel_view.gd` | unchanged | 21 | 4 |

**The two totals**: `t.eq(total_funcs, 77, …)` — 43 + 13 + 21 — and `t.eq(total_leaves, 21, …)` —
14 + 3 + 4.

⚠⚠ **Both totals MOVE, and that is a deliberate improvement over the pre-reversal plan**, whose version of
this table landed both totals back on today's 84 and 23 while five per-file counts moved — *a literal that
does not move is the one nobody re-derives.* **Recount both by hand, write the addition into the label,
and never sum `found.size()`.**
⚠ **`field_view`'s count is the one that does not move (43 → 43) and it is therefore the one to
re-derive**: one function added, one deleted, one renamed. **Check the rename actually landed in both the
file and the table** — a name the table holds that the file no longer has is caught by `_scan`'s
`표에는 있는데 파일에 없는 함수` direction, and its synthetic case (c2) already proves that direction bites.

⚠ **`set_speed` carries two facts on purpose** — which chip is lit, and what the drawers age by. They are
one number handed down from the shell on the same frame, and splitting them is two readers of one ladder.
**A view never reads `Rules.SPEED_STEPS` itself**, which is also why `field_view.set_time_scale` takes the
bare float and not the slot.

⚠ **Two presentation constants and one magic number already live outside `look.gd` where the scan cannot
see them** — `CORNER_SEGMENTS`, `RING_SEGMENTS` and a bare `colour.darkened(0.35)` inside `_paint_hull`.
⇒ **No new constant may be named with a suffix outside `PIXEL_SUFFIXES`/`TIME_SUFFIXES`, and none may be
passed as a bare literal into a call.** ⚠ **`IDLE_SOLDIER_COLS` and `GHOST_ALPHA` end in `_cols` and
`_alpha`, which are in NEITHER list, so the scan cannot see them. Confirm that before assuming they are
covered**, and if they should be, widen the lists in the same edit.

⚠ **Geometry is built in `_draw()` and handed to the leaf.** `_scan` skips the unused-argument check for
any function the table gives a count of 0, so **geometry built inside a leaf and drawn empty reads as
"1 draw call, all arguments used" — green, with nothing on screen.** The ghost fan positions and the idle
stack rects are built in `_draw()`, the way `_spark_points` is.

### 6.6 `panel_view.panel_active()` — hardening, and honestly labelled as such

**This feature does not add a `Run.State` member, so `panel_active()` is correct today and stays correct.**
It is still changed, to an **allow-list**:

```gdscript
func panel_active() -> bool:
    return run != null and (run.state() == Run.State.REWARD or is_finished())
```

⚠ **Never a denylist** (`!= BATTLE and != PLANNING`) — it breaks again on the next state, and the failure
mode is silent and five-fold. **This row is insurance, not a requirement of the round**, and it is written
that way so nobody later reads it as evidence the planning state lives in `Run`.

---

## 7. Input — one table, and the commit gate on the three plan branches

`game.gd` stays the only file that reads an event. **`_on_key` is deleted whole**, and the
`InputEventKey` branch of `_unhandled_input` empties with it.

| Input | **Before commit** | **After commit** |
|---|---|---|
| Left press on an **un-sent soldier's body** (`_soldier_hit_at`) | grab that soldier (`_drag_soldier = i`) | **nothing** |
| Left drag with a soldier grabbed | the candidate ring tracks the cursor; the droppable tint is already on screen (P3) | **nothing** |
| Left release over a droppable tile | `battle.send(soldier, tile)` — **the boat is created and the route appears** | **nothing** |
| Left release anywhere else | cancel; nothing is created. **The ring was already `COL_LOSE` under the cursor**, so the refusal was readable before the release | **nothing** |
| Left press on a **placed boat's landing ring** (`_ring_hit_at`) | `battle.recall(uid)` — free undo, 미정 12 | **nothing** |
| Left press on the **start button** | `battle.commit()`; on refusal `note_chip(0, false)` | **nothing** |
| Left press elsewhere on the field | begin a camera pan | begin a camera pan |
| **Wheel** | zoom about the cursor | zoom about the cursor |
| **Left press on a speed chip** | ⚠ **nothing** — there is nothing running to speed up | `_speed_slot = i` |
| Left click on a roster entry, in REWARD · on the restart rect, in WON/LOST | unchanged | unchanged |

⚠ **Hit-test precedence, and it is not arbitrary.** `_ring_hit_at` is tested **before** `_soldier_hit_at`,
which is tested before the pan fall-through. A landing ring can sit on top of the harbour when a player
drops a boat onto the beach beside it, and **undo losing to grab is the worse failure**: a grab that
should have been an undo starts a drag the player then has to cancel, whereas an undo that should have
been a grab is one press to recover.

⚠⚠ **The commit gate does NOT come for free from `panel_active()`.** `_on_left_press`, `_on_left_release`
and `_unhandled_input`'s motion branch contain **no `run.state()` test at all** today — only
`panel_active()` and the `_hold_sec` guard. **`_on_key` was the only handler that tested the run state,
and it is being deleted.** ⇒ A stray click mid-fight would call into the plan and break 결정 1 with the
whole round green.

⇒ **Gate the three PLAN BRANCHES, not the handlers:**

- `_on_left_press` — the `_ring_hit_at`, `_soldier_hit_at` and start-button hit tests
- `_on_left_release` — the `_drag_soldier` branch
- `_unhandled_input`'s motion branch — its `_drag_soldier` arm

⚠⚠ **`_on_wheel` is NOT gated, and neither is `_on_left_press`'s `_panning = true` fall-through.** Both
read **the same before and after commit** (the two table rows above), and `_on_wheel` in the shipped shell
is `if panel_view.panel_active(): return` plus `field_view.zoom_at(at, factor)` — **there is no plan
gesture in it to gate.** A builder who gates it turns 9.5's anti-inert-shell row red, which is the one row
that stops the post-commit check from being satisfied by a dead screen. **Three labels, not four.**

**Camera pan and zoom stay live after the commit on purpose.** They change nothing about the fight, and
watching is the whole activity; removing them would make 결정 4's *"pausing doesn't let me do anything
more"* into *"and you cannot even look."*

⚠ **A hold (`_hold_sec > 0`) still refuses everything at the one existing line**, and it now has to be
re-driven by a net with the **start press**, not with a key — see 9.5.

⚠ **Drive real clicks through `root.push_input(ev, true)`.** The `in_local_coords` flag is the whole of
it: `true` delivers intact, omitted or `false` lands thousands of pixels off with no error. **Build and
push the motion and the release too** — a drag suite that pushes only presses is half a suite.

---

## 8. Losable — the enemy count, and the arithmetic that sets it

### 8.1 ⚠ The design doc's 「섬당 30~40」 is refuted, and the refutation goes in BOTH twins

**30 enemies on one island is not a harder island, it is a wall.** Thirty bison are 600 HP and 45 DPS; a
13-soldier roster is 152 HP and 23.5 DPS. **It would take 26 seconds to clear and the army would be gone
in seven.** The number came from a review arguing about the cell economy — a round where the player's side
grows too — and **carrying it into a round where only the enemy side grows inverts what it was for.**

⇒ **This plan raises the counts to 8 · 12 · 14.** ⚠ **Go and edit the design doc, not this one.**

### 8.2 ⚠⚠ The wave band is DEAD — the reversal deleted the thing it measured

> **The pre-reversal plan's target was *"one wave of five must not take the island; two waves must"*, and
> it carried a whole box restating that band against a reinforcement period of `2 × steady /
> boat_speed` = 3.50 s to 7.28 s on island 1.**
>
> **Under unlimited free boats there are no waves.** Every soldier gets a boat, every boat departs on the
> commit frame, and arrival differs only by distance. Measured off `net_islands`' own `EXPECT_STEADY` for
> island 1 (`7.00` to `14.56` tiles) at `BOAT_SPEED` 4.0, **the whole roster is ashore between 1.75 s and
> 3.64 s** after the commit — and if they all aim at one beach, within a few hundredths of each other.
> ⇒ **The reinforcement period does not exist. Both the band and its restatement are deleted, not
> repaired.**

**The band that replaces it is aggregate, and it is one line:**

> **The whole roster, landed at once at the cheapest beach, must be able to lose.**

**The arithmetic, from `Rules.UNITS`:**

| Side | Composition | HP | DPS |
|---|---|---|---|
| roster, island 1 | 6 melee (14 HP, 2.0 dps) + 4 ranged (8 HP, 1.5 dps) | **116** | **18.0** |
| roster, islands 2–3 | 8 melee + 5 ranged | **152** | **23.5** |
| island 1 at 8 bison | 8 × (20 HP, 1.5 dps) | **160** | **12.0** |
| island 2 at 8 bison + 4 crow | | **184** | **18.0** |
| island 3 at 8 bison + 5 crow + lion | lion 140 HP, 1.90 dps with the telegraph | **330** | **21.4** |

⇒ Island 1 at 8 bison: 160 HP at 18.0 DPS is **8.9 s** of killing, during which 12.0 DPS deals **107** of
the roster's **116**. **That is a 92% wipe on the aggregate, which is the first time any island has been
close.** ⚠ **It is an upper bound on the danger, not a prediction** — the bison have `detect 6.0` and are
spread, so they engage in groups, and the ranged cells' reach `4 + 1.5 = 5.5` beats the bison's own reach
and the lion's `detect 2.0` outright. **The probe is what closes it. This arithmetic only says the band is
not obviously empty.**

⚠ **The stop condition, and it is the only one:**

> **The BASELINE policy — the whole roster onto the single cheapest sendable tile — loses at least one
> island, or its worst island finishes above 70% of the time limit.**
>
> Today the worst plan spends **49%** and all fifteen island-runs win. ⚠ **That 49% is a pre-sub-step
> number and must be RE-MEASURED before it is compared against** — section 11.

> ### ⚠ Two probe faults the pre-reversal plan found, and what the reversal does to each
>
> **(a) `_policy_dribble` no longer exists as a policy.** It sent the roster one body at a time across
> sequential round trips, which was a TIMING policy — and there is no timing axis left: every boat
> departs on the commit frame whatever order they were dropped in. ⇒ **It is deleted, not excluded.**
> The bad-play control it provided is carried by **`_inverted_must_lose`**, which already exists.
> **Do not resurrect dribbling by inventing a departure delay — that is OPEN 0's brake.**
> **(b) There are not five policies — there are four, and now three plus one new one.** `_all_cfg()` and
> `_policy_landing("near")` build the **identical dictionary**; `_same_beach_is_a_control` re-runs *near*
> a third time and asserts the two match to the decimal, which is what made the duplication invisible.
> ⇒ **Delete policy 1 and let *near* be the baseline.**
> ⇒ **The surviving policy set is: `near` (baseline) · `far` · `quiet` · `split` (half the roster to each
> of the two cheapest beaches that are not adjacent).** ⚠ **`split` is NEW and it is the only policy that
> exercises the one axis the player still has**, so it is not optional padding.

⚠ **If every policy loses an island, remove enemies from the OUTER ring first** on island 3 and from the
beach-adjacent pairs on islands 1 and 2: those are the ones that stack their DPS onto the landing before
it has spread out.

### 8.3 The characters to add — every one verified against the shipped rows as land

**Nothing but these characters changes.** `spawns_of` is a scan, so an added `B` is an added enemy with no
table to widen. **Row length and legend are unaffected — every replaced character is a `.`**

| Island | Add | Result |
|---|---|---|
| **1** | `B` at **(4,8) · (7,20) · (19,17) · (33,20)** | **8 bison** |
| **2** | `B` at **(6,8) · (14,12) · (34,8) · (40,14)** and `C` at **(10,6) · (30,19)** | **8 bison + 4 crow = 12**, and the west shore stops being the free side |
| **3** | `B` at **(19,8) · (29,13) · (10,5) · (38,5) · (36,12) · (12,17)** and `C` at **(29,8) · (6,12) · (20,17)** | **8 bison + 5 crow + the lion = 14.** Three inside the ring so the boss is not fought alone; six outside so the walk costs something |

> ### ⚠⚠ MEASURED — island 1's placement is chosen, not eyeballed, and the reason is a dominance
>
> Reproduced off the shipped rows (**landable = passable and orthogonally beside water**, which returns
> **82 · 76 · 80** and matches `net_islands`' own `EXPECT_COAST` exactly), with BISON/CROW detect 6.0:
>
> **The four bison originally proposed for island 1 left 36 of 82 coast tiles in NO detect circle — and
> `(28,20)` was one of them.** `EXPECT_WAVE1[0][0]` is `11.70` = `distance((24,31), (28,20)) = √137`, so
> **the single cheapest sendable tile from the start harbour is `(28,20)`.** ⇒ *the quiet beach and the
> cheap beach were the same beach*, and the shortest crossing was free on both axes: **an advantage with
> no cost is not a decision.** ⚠ **Under OPEN 0 that dominance is not merely a flaw, it is the whole
> game** — with unlimited free boats the cheapest beach is where everything goes.
>
> ⇒ **The four bison above take island 1 from 36 uncovered coast tiles to 13, and `(28,20)` is inside a
> circle.** Measured, and still a first value.
> ⇒ ⚠ **STOP ASSERTING THIS IN PROSE.** It goes into `net_islands` as `EXPECT_UNCOVERED_COAST`, one
> hand-written literal per island, **plus one row asserting the cheapest start-sendable tile is inside
> some detect circle** — the half that has the plan in it. **A sentence in a plan cannot redden; a
> literal can.**
>
> ⚠ **Do NOT maximise the cover.** A greedy cover reaches **zero** uncovered tiles on all three islands
> at these counts, **but only by putting every enemy on the shore**, which deletes the *quiet shore*
> policy outright and with it one of the probe's discriminating axes. **The number is a design choice,
> not a bound.**

⚠ **`net_islands`' hand-pinned per-island literals move and must be RE-MEASURED, never derived.**
`EXPECT_STRICT_UNREACHED` moves for certain — its island-2 figure comes from bison jamming the strict
walker on each other's tiles, and this doubles the bison. `EXPECT_RELOCATES` is geometry and probably does
not move, **which is exactly the row that gets waved through**: re-measure the whole table, not the row
someone is arguing about.

### 8.4 ⚠ `_min_region_floor()` — its premise died and the rewrite is NOT the obvious one

`net_islands._min_region_floor()` returns `max over b of Rules.cap_of(b) + 1` — today **5**. Its own header
explains why: a boat whose cargo does not fit **waits forever**, `_try_unload` never lands part of a load,
and the island runs to LOST/TIMEOUT with nothing in the sim saying why.

**With `Rules.BOATS` deleted the formula does not compile, and every obvious replacement is wrong:**

- **`Rules.boat_count() + 1`** — the pre-reversal answer. **The function no longer exists.**
- **`1 + 1 = 2`** — "a boat carries one soldier". ⚠ **This is exactly the trap `CLAUDE.md` names**: a
  bound that shrinks with the thing it checks. The real simultaneous demand went **up**, not down.
- ⇒ **The demand is the ROSTER**, because unlimited boats means every living soldier can aim at one
  region on one sub-step:

```gdscript
## The smallest passable region a sendable tile may sit in without risking the silent stall the
## header names. **Demand, not cargo**: with boats created per drag (`plan-then-watch`, 4.2) every
## living soldier can aim at ONE region on one sub-step, so the floor is the largest roster a run can
## ever field plus one tile of margin for a neighbour already occupied when the last boat arrives.
func _min_region_floor() -> int:
	return Rules.START_MELEE + Rules.START_RANGED + Rules.REWARD_MELEE + Rules.REWARD_RANGED + 1
```

⇒ **6 + 4 + 2 + 1 + 1 = 14**, and the self-check literal moves **5 → 14** with its Korean label rewritten
from `(BIG 정원 4 + 여유 1)` to `(최대 병력 13 + 여유 1)`. ⚠ **A builder who bumps 5 to 14 and leaves the
label reading 「BIG 정원 4」 ships a green round under a label stating a claim the same edit refuted**, and
a builder who "fixes" the literal by deriving it from `_min_region_floor()` **guts the self-check.**

> ### ⚠⚠ MEASURED — the guarded assertion cannot redden on the shipped islands, under ANY of these
> ### formulas, and that was already true before the reversal
>
> The floor guards `t.ok(min_region >= min_region_floor, …)`, where `min_region` is the size of the
> smallest passable region containing a sendable tile. **Measured off the shipped rows: every island is
> ONE connected passable component — 744, 760 and 716 tiles** (island 2's ridge is bridged by its `//`
> ramps, island 3's ring by its `/` ramps). **Moving the floor between 2, 5, 6 and 14 never crosses
> 716.** ⇒ Any mutation of the formula moves **nothing but the self-check one line above.**
>
> ⇒ **Keep the rewrite** — it is the correct formula and it stops the floor shrinking with the thing it
> checks. **Give it bite the way `net_islands` already gives its sealed-enemy fixture one: a synthetic
> `Grid` with a pocket of exactly 13 passable tiles holding a sendable tile**, which the rewritten floor
> must REJECT and a floor of 5 must ACCEPT. 9.3 carries it.
> ⚠ **This also refutes the worry that a bigger floor tightens the shipped islands.** It tightens
> nothing: 716 ≥ 14 with 702 tiles to spare, and no island has to move.

⚠ **`TIME_LIMITS` is not touched.** It has never bound; the probe re-measures after the counts rise and
**reports**. Changing it is a separate decision with the user.

---

## 9. Nets — twelve, and every check names its mutation

The wrapper reds below five nets and a net that runs zero checks is a failure. **Today's round is 11 nets
/ 967 checks / 2.8 s; this adds one net** — `net_plan`. The twelve: `net_plan` `net_boat` `net_battle`
`net_shell` `net_islands` `net_draw_leaf` `net_fx` `net_fx_view` `net_camera` `net_coast` `net_run`
`net_citations`. **`net_shell` alone is 234 checks — a quarter of the round — and it is the file this
feature cuts deepest into.**

⚠⚠ **Every row below carries three things: a floor, a ceiling and a mutation that reddens it.** A row that
names only one end is not finished. **The floor is the half that proves the effect happens at all.**
⚠ **A pair of bounds is only a pair if it brackets ONE quantity.**

⚠ **Invert every new check, and invert the instrument as well as the subject.** A mutation whose PRE and
POST `[지문]` fingerprints differ from each other **only by that mutation** is the only one that proves
anything — and the fingerprint covers `docs/` too, so **do not edit this plan between two mutation
rounds.** Do the edit and the run in one command when the tree is contested.

### 9.1 `net_plan` — NEW. The planning state, the commit, formation order, the sub-step

| Check (label is Korean) | Floor | Ceiling | Mutation that must redden it |
|---|---|---|---|
| `커밋 전에는 step 이 아무것도 안 건드린다` — with two boats sent, drive `step(1/60)` 600 times and assert `elapsed`, every `soldier_pos`, every `enemy_hp` and every `boats[i].t` are **exactly** unchanged | 600 iterations really ran | all four asserted, not just `elapsed` | `battle.gd` · delete `if not _committed: return` → the label |
| `배를 안 띄우고 누른 시작은 거절된다` — `commit()` false with `boats` empty, **true** with one boat sent | the true case | the false case | `battle.gd` · drop the empty test → `빈 계획으로는 시작이 안 된다` |
| `커밋 뒤에는 계획을 못 바꾼다` — `send` returns -1 and `recall` returns false after `commit()` | both calls made | two separate labels | `battle.gd` · remove the `_committed` test from each → two labels |
| `한 번 끌면 배 한 척이 생긴다` — `boats.size()` 0 → 1 → 2 → 3 over three `send`s, **and the uids are distinct** | the size moved | the uids differ | `battle.gd` · reuse `_next_boat_uid` → `배마다 다른 번호를 받는다` |
| **`배 수에 상한이 없다`** — send the **whole 13-soldier roster** and assert `boats.size() == 13` and every soldier is `TRANSIT` | 13 sends attempted | **13 succeeded — not "more than five"** | `battle.gd` · any cap → the label. ⚠⚠ **This is OPEN 0 as a check. It is the row that catches a builder quietly reintroducing a brake** |
| `이미 보낸 병사는 다시 못 보낸다` — a second `send` of the same id returns -1 and `boats.size()` is unchanged | the first succeeded | the second refused **and** nothing was appended | `battle.gd` · drop the `RESERVE` test → the label |
| `죽은 병사는 못 보낸다` | a living send succeeds | the dead one refuses | `battle.gd` · drop the state test → the label |
| `배는 상륙지에서 가장 가까운 항구에서 뜬다` — send to a tile whose `home_harbour_for` is NOT `start_harbour`, assert `boats[0].from` is that harbour's point | the two harbours really differ (self-check) | `from` equals the right one | `battle.gd` · use `start_harbour` → `배가 시작 항구가 아니라 제 항구에서 뜬다` |
| `어느 항구도 못 보는 칸은 거절된다` | a reachable tile succeeds | the unreachable one returns -1 | `battle.gd` · drop the `home_harbour_for` test → the label |
| `무르면 병사가 항구로 돌아온다` — `recall(uid)`: `boats` shrinks by one, the soldier is `RESERVE`, `soldier_pos` is `OFFMAP`, **and the soldier can be sent again** | the recall returned true | **all four**, especially the re-send | `battle.gd` · leave the state at `TRANSIT` → the label |
| **`놓은 순서대로 앞자리를 가져간다`** — ⚠ **on a real `Islands` fixture, not a synthetic one.** Send soldier A then soldier B **to the same tile** from the same harbour, commit, step to their arrival: **A stands ON the target tile and B on a neighbour** | both landed (`ASHORE`) | A's tile **is** the target and B's **is not** | `battle.gd` · leave `_phase_landings` walking descending for OUTBOUND arrivals → the label. ⚠ **This mutation restores today's reversed behaviour, so it must bite** |
| `순서를 바꾸면 앞자리도 바뀐다` — the same fixture with B sent first | run A | run B | if one ordering passes both ways, the drop order is not being read |
| **`같은 칸을 노린 열셋이 열세 칸에 선다`** — send the whole roster to one tile, commit, step to arrival: **13 distinct tiles, none reserved twice** | all 13 are `ASHORE` | the 13 tiles are pairwise distinct | `battle.gd` · skip the `grid.reserved` write in `_try_unload` → the label |
| **`빈 배는 항구까지 돌아가서 사라진다`** — after unloading, the boat is in `boats` as RETURNING with no cargo, arrives at `home_harbour_for(landing)`, **and then `boats` no longer holds that uid** | the return leg really ran (`t > 0` while RETURNING) | the uid is gone at the end | `battle.gd` · remove on unload → `배는 왕복하고 나서 사라진다` |
| **`1배속 60프레임과 6배속 10프레임이 완전히 같다`** — two identical battles, one driven 60 × `step(1/60)`, the other 10 × `step(6/60)`; assert **`elapsed`, every `enemy_hp`, every `army.hp`, every `soldier_pos` and `boats.size()`** equal within `Rules.EPS` | both really advanced (`elapsed > 0`, at least one `enemy_hp` moved) | all five compared | `battle.gd` · run the phases once on the whole `dt` → the label. ⚠ **Without the floor, two runs that both did nothing compare equal** |
| **`판정이 난 뒤까지 몰아도 같다`** — the same pair driven PAST the verdict, `army.living_count()` compared too | **both reached a verdict** | `elapsed`, every `army.hp` and `living_count()` equal | `battle.gd` · hoist `_outcome != Outcome.RUNNING` out of the loop → the label. ⚠⚠ **The row above stops before the verdict and stays green through that mutation** |
| **`고르지 않은 프레임 간격에서도 같다`** — run A at 1× with an uneven, non-multiple `dt` sequence (`0.0069, 0.011, 0.023, 0.0141, …`, ~200 entries), run B at `k`× with the same sequence scaled | both advanced | all five compared, **at k = 2, 3 and 6** | `battle.gd` · consume the leftover as a remainder pass → the label. ⚠⚠ **The `1/60` fixture CANNOT fail this way** — `6 × (1.0/60.0) == 0.1` exactly |
| **`서브스텝 횟수 자체가 같다`** — a counter incremented **inside** the loop, compared across arms | each arm > 0 | the counts **equal** | `battle.gd` · any change to the loop bound → the label. **Comparing final state catches *diverged*, never *vanished*** |
| `서브스텝 상수를 키우면 갈라진다` — the self-check | — | — | `rules.gd` · `SIM_SUBSTEP_SEC := 1.0 / 20.0` → the 6× row must go red. **If it does not, the equivalence rows measure nothing** |
| **`0배속은 시계를 세운다`** — `step(0.0)` leaves `elapsed` at exactly its old value; `step(1/60)` moves it | the 1× half moved | the 0× half moved by **exactly** 0.0 | `battle.gd` · drop the `dt <= 0.0` guard → the label |
| every `while outcome() == RUNNING` carries a step counter and asserts it | — | — | a hung net prints no verdict and disarms mutation testing on the whole file |

### 9.2 `net_boat` — rewritten

| Check | Floor / Ceiling | Mutation |
|---|---|---|
| **`Rules.BOAT_SPEED == 4.0`, written as a literal** | — / exact | `rules.gd` · 3.0 → `배 속력은 4.0 이다` |
| crossing time is `distance / BOAT_SPEED`; the ratio of two arrival times equals the ratio of the distances | both crossings finished / the ratio matches within `EPS` | `battle.gd` · a constant divisor → `먼 해안일수록 오래 걸린다` |
| **thirteen boats coexist, each with exactly one soldier** | 13 created / **every `soldiers.size() == 1`** | `battle.gd` · put two aboard one → `배 한 척에 한 명이다` |
| the return leg is simulated and the boat then vanishes | the RETURNING phase was observed / `boats` is empty at the end | `battle.gd` · remove on unload → `내려놓은 배는 빈 채로 항구까지 돌아간다` |
| `send` refuses: post-commit · a dead soldier · an already-sent soldier · a non-landable tile · a tile no harbour can see · an out-of-range id | one per clause / six labels | one mutation each |
| a soldier waits aboard when its ONE target region has no free tile | the boat is still OUTBOUND and `arrived` / the soldier is still `TRANSIT` | `battle.gd` · land it anyway → `빈 칸이 모자라면 안 내린다` |
| cargo rides the boat's coordinate and cannot shoot back | unchanged | unchanged |

⚠ **DELETED with the axis they measured**: the throughput-inequality row (`cap_fast × speed_fast <
cap_big × speed_big`), the two capacity rows, the two per-boat speed rows, `Rules.boat_count() == 2`, and
the whole of `_load_soldier_picks_the_boat`. **Delete the `rules.gd` comment stating the inequality in the
same edit** — with no capacity it is arithmetically vacuous. **Do not "fix" the comment; remove it.**

### 9.3 `net_islands` — re-measured (stage 4, except the three rows marked stage 1)

Shape, legend, harbour tiles, start harbour tile, per-harbour sendable counts, narrowest cut, coast counts
and the crossing bounds are **geometry and do not move.** What moves:

- **spawn counts → `[8, 12, 14]`, written as literals**
- **`EXPECT_STRICT_UNREACHED` re-measured from the new rows** — not derived from `Islands`
- **`EXPECT_RELOCATES` re-measured too**, even though it is expected not to move
- **NEW — `EXPECT_DROPPABLE`, one hand-measured literal per island** (stage 1): how many tiles satisfy
  `home_harbour_for(t) >= 0`. **Bounded below by the start-sendable counts (47 · 38 · 46) and above by
  `EXPECT_COAST` (82 · 76 · 80)** — assert both bounds as well as the literal, so a formula that collapses
  to one harbour or opens to every tile is caught even if the literal was mis-transcribed
- **`_min_region_floor()` rewritten to the roster formula** (stage 1) — 8.4
- ⚠⚠ **the floor's own self-check moves with it** (stage 1): `t.eq(min_region_floor, 5, "…(BIG 정원 4 +
  여유 1) — 자가 점검")` becomes **14** with its Korean label rewritten to `(최대 병력 13 + 여유 1)`
- **NEW — `EXPECT_UNCOVERED_COAST`, one hand-written literal per island** (8.3's box), plus one row
  asserting **the cheapest start-sendable tile is inside some enemy's detect radius**
- **the walker still reaches every enemy from every sendable tile**, field cached per enemy, not per pair

| Mutation | Label that must redden |
|---|---|
| `islands.gd` · delete one added `B` from island 1 | `섬 1 의 적 수` |
| `islands.gd` · put a `,` in a row | `섬 %d 에 범례 밖 글자가 없다` — the existing bait, kept |
| **a synthetic `Grid` with a pocket of exactly 13 passable tiles holding a sendable tile** | `상륙 구역은 최대 병력보다 크다` — **the rewritten floor must REJECT it and a floor of 5 must ACCEPT it.** ⚠⚠ **This is the only bite the floor has: every shipped island is one component of 744 / 760 / 716 tiles and no formula ever crosses it** (8.4's box) |
| `islands.gd` · move one bison off the south beach of island 1 | `섬 1 의 아무 적에게도 안 걸리는 해안 칸 수` |
| `grid.gd` · make `home_harbour_for` return `start_harbour` always | `배를 보낼 수 있는 칸 수` — the new `EXPECT_DROPPABLE` literal **and** its lower-bound row |
| the sealed-enemy fixture | `벽 저쪽에 갇힌 적에게는 못 간다고 말한다` — the self-check, kept |

### 9.4 `net_draw_leaf`

- `_table()['field_view.gd']` gains **`set_time_scale` at 0**, loses **`_deck_slots`**, renames
  **`idle_hull_rect` → `idle_soldier_rect`** (still 0). **43 names, 14 leaves — unchanged in COUNT.**
- `_table()['hud_view.gd']` loses **`key_slot_count`, `key_type_of`, `reserve_count`, `boat_label`,
  `note_launch`, `_berth_offset`, `_paint_berth`, `_paint_load`**, gains **`set_speed` at 0**, renames
  `note_key`→`note_chip`, `_key_offset`→`_chip_offset`, `_key_colour`→`_chip_colour`,
  `_paint_key`→`_paint_button` (still 2). **20 → 13 names, 5 → 3 leaves.**
- **`total_funcs` 84 → 77** (43 + 13 + 21) and **`total_leaves` 23 → 21** (14 + 3 + 4). **Recount both by
  hand and write the addition into each label; never sum `found.size()`.**
- The seven scanner self-checks are unchanged, `src/view/` still holds exactly three files, and
  `wide_scanned` stays 4 (no fifth view or shell file is added).

| Mutation | Label |
|---|---|
| leave `_paint_key` / `_paint_load` / `idle_hull_rect` in the table after renaming or deleting | `표에는 있는데 파일에 없는 함수` — **already inverted by case (c2)** |
| add `set_time_scale` to `field_view.gd` without listing it | `표에 없는 함수` — already inverted by case (a) |
| `game.gd` · `var _speed_mul := 1.0` | `뷰와 셸에는 시간·비율 이름에 박힌 리터럴도 없다` |
| `look.gd` · a bare `Color(...)` for the ghost instead of `ghost_tint()` | the colour half of the one-file rule |
| ⚠ **`IDLE_SOLDIER_COLS` and `GHOST_ALPHA` are invisible to the literal sweep** (`_cols`, `_alpha` are in neither suffix list) | **confirm before assuming coverage, and widen the lists in the same edit if they should be covered** |

### 9.5 `net_shell` — the gestures, and the re-pinning the key HUD takes with it

⚠⚠ **Deleting `KEY_TYPES` does not redden this net cleanly — it CRASHES it.** Eleven sites index
`hs.keys[0]` / `hs.keys[1]` literally; the count check passes as `0 == 0` and the next line raises
*Invalid access to index '0' on base: 'Array'*. The round then goes red through the
**undeclared-stderr** verdict, **not** through the zero-check rule, and a partial pass count is still
printed. **A builder must not read "shell 180 passed" as "mostly fine."**

⚠ **And roughly the back two-thirds of the file stands on the key section.** Its self-check asserts both
boats are full *"앞 절 키 입력들이 다 태웠다"*, and everything after it — the drag, the launch, the hull
positions, the camera, the verdict hold, the reward panel, the lose panel, restart — is downstream.
⇒ **Replace the boarding gesture with the drop gesture in the same edit, before touching anything
downstream**, or the file cannot be run at all while the work is in flight.

**Three things that lose their only pin and must be re-pinned, not dropped:**

| What | Where it is re-pinned |
|---|---|
| **`Look.COL_BUTTON`** — compared as a literal at three key-box sites and nowhere else, while `panel_view` still hands it to `_paint_message` and `_paint_button` with no net comparing those arguments | `ps.messages[0]["bg"] == Look.COL_BUTTON` and `ps.buttons[0]["bg"] == Look.COL_BUTTON` — **one line each, on captures `net_shell` already collects** |
| **The refuse shake, both ends** | on the **start button**, driven by a refused `commit()`: floor `shift.length() > 0.0`, **and a ceiling that does not exist today — `shift.length() <= Look.REFUSE_SHAKE_PX + 0.01`.** ⚠ The current pair is *accepted == rest* vs *refused > 0*, which is a pair of CASES and **not a bounded magnitude**: re-pinning is not a copy, it is an addition |
| **`Look.key_rect_px(0)` as the resting rect** | `Look.start_rect_px()`, asserted as the rect an unshaken button is drawn at |

> ### ⚠⚠ Rows that measure the boat axis 결정 14R deletes — **all of them go, and none is "unchanged"**
>
> - **The hull-width literals and the comparison built on them.** `net_shell` pins
>   `fs.hulls[0]["rect"].size == Vector2(124.0, 56.0)` and `fs.hulls[1]["rect"].size ==
>   Vector2(72.0, 56.0)` as deliberate literals, then asserts `hulls[0].size.x > hulls[1].size.x` under
>   *"큰 배가 빠른 배보다 실제로 넓다"*. **Every hull is now `BOAT_SLOT_PX 26 + 2 × BOAT_HULL_PAD_PX 10 =
>   46` px wide.** ⇒ **the literal becomes `Vector2(46.0, 56.0)` and the `>` row is DELETED with its
>   axis, not repaired** — `46 > 46` is false and the property no longer exists. **Its measured-mutation
>   comment goes with it**, since it documents a defect in a check being removed.
> - **The idle-hull rows.** `t.eq(fs.hulls.size(), Rules.boat_count(), "아직 아무것도 안 띄웠어도, 항구에
>   앉은 배 수만큼 선체를 그렸다")` and its two siblings. **Before the commit there are no hulls at all** —
>   there is the army. ⇒ **replaced by rows asserting one idle body per `RESERVE` soldier at
>   `idle_soldier_rect(i)`.**
> - **The berth rows and the berth load label.** `hs.berths.size() == boat_count()`, `hs.loads.size() ==
>   boat_count()`, and both `"%s %d/%d"` text comparisons. **All deleted with `_paint_berth` and
>   `_paint_load`.**
> - **The HUD draw-order row**, hardcoded as `berths[0] → loads[0] → berths[1] → loads[1] → keys[0] →
>   enemies[0]` and naming the deleted key section. ⇒ rewritten for **the timer, the enemy count, the
>   start button and the speed chips.**
> - **`t.eq(int(b.pending[0].size()), Rules.cap_of(0), …)`** and its three siblings — the self-checks that
>   made the key section's downstream rows meaningful. ⇒ **replaced by `battle.boats.size()`.**

**New rows:**

| Check | Floor / Ceiling | Mutation |
|---|---|---|
| press on an idle soldier's body → motion → release on a droppable tile **creates one boat** with that soldier aboard | `boats.size()` moved 0 → 1 / **the right soldier** is aboard | `game.gd` · always send soldier 0 → `끌어 놓은 병사가 탄다` |
| **the drop does NOT start the clock** — after the release, `battle.elapsed == 0.0` and `boats[0].t == 0.0` | a boat exists / both exactly 0 | `game.gd` · call `commit()` on release → `놓기는 계획일 뿐 시작이 아니다` |
| **the whole roster can be sent** — thirteen press/motion/release triples, `boats.size() == 13` | 13 gestures driven / 13 boats, **no cap** | `game.gd` or `battle.gd` · any cap → `열세 명 전부 보낼 수 있다`. ⚠⚠ **OPEN 0 as a shell check** |
| release on a shadowed tile creates nothing | a valid drop worked (self-check) / `boats.size()` unchanged | `game.gd` · drop the reachability test → the label |
| **press on a placed boat's landing ring recalls it** | `boats.size()` 1 → 0 / the soldier is `RESERVE` and drawn at the harbour again | `game.gd` · drop `_ring_hit_at` → `고리를 누르면 무른다` |
| **the ring beats the body in the hit test** — a ring drawn over the harbour: the press recalls, it does not grab | both rects contain the point (self-check) / `boats.size()` fell **and** `_drag_soldier == -1` | `game.gd` · swap the two tests → `고리가 병사보다 먼저 잡힌다` (section 7) |
| pressing the start button calls `commit()`; `battle.committed()` goes false → true | it was false / it is true | `game.gd` · drop the branch → `시작 버튼이 계획을 확정한다` |
| **the default speed is not the pause** — send, press start, pump frames with **no chip pressed**, assert `battle.elapsed > 0.0` | frames were pumped / `elapsed > 0` | `rules.gd` · `SPEED_SLOT_DEFAULT := 0` → `시작하면 아무것도 안 눌러도 시계가 간다` |
| **`SPEED_SLOT_DEFAULT` names the 1× entry** — `float(Rules.SPEED_STEPS[Rules.SPEED_SLOT_DEFAULT]) == 1.0` | — / exact | `rules.gd` · reorder the ladder → the label |
| **after commit: a press on a body, a motion, and a release on a droppable tile all change nothing** — `boats` identical before and after | the same gesture worked pre-commit / `boats` identical | `game.gd` · remove the gate from each of the **three plan branches** → three labels. ⚠ **Three, not four** (section 7). ⚠ **This is 결정 1 as a check** |
| **camera pan and zoom still work after commit** | the camera really moved / it stayed inside the clamp | `game.gd` · gate `_on_wheel`, or gate the `_panning` fall-through → `전투 중에도 화면은 움직인다`. **Without this row the previous one is satisfied by an inert shell** |
| **the hold guard, re-driven** — a **start press** during `_hold_sec > 0` does not commit | the hold was armed / `battle.committed()` still false | ⚠ **Today this is checked with `KEY_2` and asserts `pending` is unchanged. Once `_on_key` is gone that check passes while measuring nothing.** Assert `committed()` — a state the sim owns |
| a speed chip press before commit does nothing; after commit it moves `_speed_slot` | the after case moved it / the before case did not | `game.gd` · drop the commit test → two labels |
| **the routes drawn equal the plan** — capture every `_paint_route` call and assert one per entry of `battle.boats`, ending at that boat's `to` | at least one route / **exactly** one per boat, no more | `field_view.gd` · draw from the drag only → `계획한 항로가 전부 그려진다` |
| **the ghosts equal the plan, in drop order** — capture every ghost `_paint_body` call and assert the k-th is at `tile_point_px(boats[k].to) + k × GHOST_FAN_PX` | at least one ghost, alpha > 0 / the fan offsets are **strictly increasing** — the floor 4.4 depends on | `field_view.gd` · drop the fan (`k × 0`) → `유령이 놓은 순서대로 늘어선다` |
| **the ghosts stop at the commit and the passengers start** | ghosts > 0 before / ghosts == 0 after **and** transit bodies > 0 | `field_view.gd` · drop the `committed()` test → two labels |
| **the unspent plan survives the commit** — after commit, with one boat still at sea, its route is still captured | it was captured before / still captured after | `field_view.gd` · stop drawing on commit → `아직 안 간 배의 항로는 남아 있다` |
| **the idle army is drawn where it can be pressed** — every `RESERVE` soldier has one body at `idle_soldier_rect(i)`, **and none of those rects intersects `Look.start_rect_px()` or any `Look.speed_rect_px(i)` at `ZOOM_MIN`** | 10 bodies drawn, rects non-empty / **zero intersections** | `look.gd` · `HUD_START_ORIGIN_PX := Vector2(560.0, 632.0)` → `항구에 선 병사는 버튼 밑에 안 깔린다` (6.3) |
| **thirteen idle bodies fit on the map** — the 13th `idle_soldier_rect` is inside the painted map rect | 13 rects / all inside | `look.gd` · `IDLE_SOLDIER_COLS := 2` → `병사 열셋이 지도 안에 다 선다` |
| every laid-out rect lands inside the 1280 × 720 viewport (HUD and panel) | the rects are non-empty / all inside | `look.gd` · any layout function returning a bare `Rect2()` |
| three children, the two holds, the beak, restart | unchanged | ⚠ **This row covers those five things and nothing else** — the box above says what moves |

### 9.6 The rest

- **`net_battle`** — the call sites that name `load_soldier`, **and more than that.**
  ⚠⚠ **Sub-stepping re-discretises 1× itself for every caller that passes `dt > SIM_SUBSTEP_SEC`, and
  this file does.** It drives `step(0.1)`, `step(0.5)`, `step(0.7)` and `step(cross_t)`; each becomes 6,
  30, 42 and N phase passes instead of one. **5.1's own table says what that changes**, and 4.4 just made
  reservation contention load-bearing. ⇒ **Budget the re-measurement in the same stage as the sub-step.**
  Two acceptable shapes, and the builder picks one and says which: **(i)** drive the existing fixtures at
  `dt == Rules.SIM_SUBSTEP_SEC` so the phase-order rows stay a one-frame contract, or **(ii)** keep the
  coarse dts and **re-pin every literal that moves**, one mutation each. **(i) is preferred** — those rows
  exist to pin the phase ORDER, and a one-sub-step call is the only `dt` at which "one frame" is an
  unambiguous thing to pin.
  ⚠ **Its step-order check now runs inside a sub-step**; confirm it still measures the process and not
  only final state.
- **`net_fx` · `net_fx_view`** — 11 call sites move to `send` + `commit`. **A battle that is never
  committed produces no events at all**, so every fixture in both files gains a `commit()` — eleven silent
  no-ops waiting to happen if it is missed, and the zero-check rule will not catch them because the files
  still run plenty of checks.
- **`net_camera`** — ⚠ **not "untouched".** `_painted_area_covers_the_viewport` goes red until
  `WATER_MARGIN_TILES` moves (6.3's box); the `ZOOM_MIN <= 0.5625` ceiling row's **label and bound are
  rewritten to `<= 0.50` with the new reason**; the comment recording *"at ZOOM_MIN the visible world is
  2275.56 px wide"* is re-measured to **2844.4**; the `0.7` too-tight self-check still holds and stays.
  ⚠ **The `ZOOM_MIN >= 0.4` floor row is kept exactly as it is** — it already carries the body-size
  reason and it is what makes 0.45 a bounded choice rather than a taste.
- **`net_run` · `net_coast` · `net_citations`** — untouched, except where they name a deleted constant.

### 9.7 `net_fx_view` — the ladder, driven at every step (5.4)

⚠ **No net drives a view above 1× today**, because the multiplier does not exist yet and lives in
`game.gd` when it does. **These rows are the only thing standing between the ladder and a destroyed
picture**, and acceptance's *"the speed-up does not change the game"* row goes green without them.

| Check | Floor | Ceiling | Mutation |
|---|---|---|---|
| **`빠르게 감아도 몸이 하얗게 물들지 않는다`** — at k = 1, 2, 3, 6, drive one attack period of real frames and measure the fraction on which `_flash_of` is above 0 for a given body | **> 0.05** — the flash happens at all | **≤ 0.25** at every k. ⚠ At k = 6 unscaled it is **0.84** | `field_view.gd` · age `_fx_step` by `delta` instead of `delta × k` → the label |
| **`빠르게 감아도 몸이 밀린 채로 안 남는다`** — `_lunge_offset(key).length()` returns to **exactly 0.0** at least once per attack period | **> 0** at the peak — the lunge exists | **== 0.0** at rest, at every k | the same mutation → a second label. ⚠ **`LUNGE_SEC 0.18` > the 0.1667 s period at k = 6** |
| **`불꽃이 몸 테두리를 다 덮지 않는다`** — `8 × SPARK_SEC / (1.0 / k)` stays under 1.0 at every ladder step | the expression is > 0 | **< 1.0** at k = 6. Unscaled it is **5.76** | the same mutation → a third label |
| **`0배속이면 연출도 멈춘다`** — at k = 0 the fx list does not age between pumped frames | the list is non-empty | ages by exactly 0 | `field_view.gd` · floor the scale at 1.0 → `멈추면 화면도 멈춘다` |
| **the shell is what hands the number down** — null the scale field back out, call `game._ready()` and `_process`, assert it is set | it is set at all | it equals `Rules.SPEED_STEPS[_speed_slot]` | `game.gd` · drop the `set_time_scale` call → `셸이 배속을 뷰에 넘긴다`. ⚠ **Pre-setting the field in the net hides the line that wires it** |

---

## 10. Deliberately not in this round

The whole cell / object economy (미정 1 · 2 · 13) · the node map and the refit screen (미정 5) ·
**a mother ship** (OPEN 1) · **any brake on the boats** (OPEN 0) · **an order glyph or an order handle**
(4.4) · **drawing enemy detect radii** (미정 6) · new enemy types (결정 12) and new use of terrain
(결정 13), which the user set to 「차차」 · **`TIME_LIMITS`** · fog · 3D · artifacts · mid-crossing
redirect · squad assignment · preview · simulation · **any verb on the pause** · variety (결정 10, the
user parked it).

⚠ **The pause carrying no verb is on this list as a rule, not an omission.** *"A verbless pause is exactly
where 'well, while we're stopped, let it turn one boat around' walks in"* — the design doc's own sentence,
and the moment that line lands, 결정 1 is dead.

⚠ **「배가 칸이 된다」 is NOT decided here, and the reversal makes it harder rather than easier.** 결정 9
deleted the grounds for five slots and the phrase was used in conversation without the user confirming it;
**결정 14R now deletes the boat as a persistent object entirely**, so a boat cannot hold a part slot even
in principle. **Nothing here may be cited as having settled 미정 1** — it has narrowed it to *the soldier*
or *some other slot*, and that is a report, not a decision.

---

## 11. The probe — and what it cannot measure

`tools/probe/run_run.gd` today interleaves loading, launching and stepping **on every frame** inside one
`while outcome() == RUNNING` loop. That shape is exactly what this design deletes.

**The new shape**: build the plan (`send` every soldier to its policy's tile, in the policy's order),
`commit()`, then step to a verdict touching nothing. **The landing policies become plan generators.**

⚠⚠ **`const DT := 0.05` becomes exactly three sub-steps**, so the probe's own discretisation changes with
this round. ⇒ **The 49% figure quoted in 8.2 and in `islands.gd`'s `TIME_LIMITS` comment must be
RE-MEASURED under sub-stepping BEFORE the new counts are judged against it.** Comparing a post-sub-step
70% against a pre-sub-step 49% compares two different simulations, and the round would book a design win
that is a discretisation artefact. **Print the re-measured baseline first, at the OLD enemy counts, and
only then raise them.**

| Policy / row | The number it has to produce |
|---|---|
| **the baseline — the whole roster onto the single cheapest sendable tile** | **It must LOSE at least one island, or its worst island must finish above 70% of the limit.** ⚠ **The gate is on the BASELINE**, never on "at least one of N policies" |
| the far shore · the quiet shore | kept as discriminators. ⚠ **The "near" policy IS the baseline** — `_all_cfg()` and `_policy_landing("near")` build the identical dictionary today, so one of the two is deleted rather than counted twice (8.2's box) |
| **NEW — `split`** | half the roster to each of the two cheapest non-adjacent beaches. ⚠ **The only policy that exercises the one axis the player still has** |
| **DELETED — `dribble`** | it was a TIMING policy and there is no timing axis left (8.2's box). ⚠ **Do not resurrect it by inventing a departure delay — that is OPEN 0's brake** |
| the worst surviving plan | **≥ 70% of the island's time limit.** Below that the clock is still decoration |
| **NEW — drop order matters** | Same tiles for every soldier, **drop sequence reversed**: report whether casualties, duration or the landed formation differ. ⚠ **4.4 predicts this DOES differ now** (the reservation BFS reads the walk order) — **but predicts the effect is small.** Report the number; do not tune to it |
| **NEW — everything on one tile** | the dominant plan under OPEN 0, run explicitly: **report the landed spread in tiles and the time to the first blow.** This is the shape the missing brake produces, and the next session needs the number |
| **NEW — the speed ladder is inert** | The same plan at 1× and at 6×: **identical `enemy_hp`, identical outcome, identical `elapsed`** |
| `_same_beach_is_a_control` (kept) | Two runs with the identical plan must match to the decimal — **the inversion that keeps the rows above honest** |
| `_inverted_must_lose` (kept) | The run the probe must report as a loss. ⚠ **It is now the ONLY bad-play control**, since dribble is gone |
| dead air, `_input_open` (kept) | ⚠ **It becomes the constant 0 after the commit, by design.** Keep printing it, and print **planning actions** beside it, or the number silently stops meaning anything |

⚠ **`--headless --script` does not re-import and `run_nets.ps1`'s guard does not cover `tools/`.** This
plan adds no `class_name` file, so nothing here needs a hand `--import` — **but do not bypass the guard.**

> ### ⚠ What the probe cannot measure about this design — honestly
>
> **All three of the design doc's replacement health metrics are human numbers**: time until maximum
> speed is pressed, time spent planning and actions taken while planning, and pause presses. **A bot
> plans instantly and never presses a speed button.** The doc goes further and shows all three **improve
> as the game gets worse** — the planning-time score rises the *less* readable the screen is, and
> deleting the pause button scores full marks on the third.
>
> ⇒ **The probe can prove this round's machinery is correct and cannot say whether the round is any
> good.** It can say the commit gate holds, the drop order changes the formation, the speed ladder is
> inert and an island is losable. It cannot say whether watching a plan you authored is a different
> experience from watching one you did not — **this repo has never measured that difference and has no
> instrument for it.** `planning-principles`, line two, and this design breaks its line one on purpose.
>
> ⚠ **And the probe grades in its owner's favour unless it is inverted.** The last one modelled one-shot
> as `force >= hp` after a cap made that false, and never read the flee table. **Both inversions above
> stay, and each new row carries one.**

---

## 12. Acceptance

⚠ **No row closes on "the round is green", "the effect was built", or "an agent walked through it."**

| What must be true | Scored by | How it is known |
|---|---|---|
| **The plan reads before the commit** | **user only** | The user describes what is about to happen **before** pressing start, and the description matches what happens |
| **Planning takes time** | **user only** | A person times the gap from the island opening to the start press, and counts the actions in between. ⚠ A probe figure does not pass it |
| **Execution is watched, not endured** | **user only** | Measure when maximum speed gets pressed. Every fight at t=0 is a failure |
| **The pause is not needed** | **user only** | Count the presses |
| **The whole island is in one frame, further back** | **user + net** | ⚠ **The user's own sentence is the bar**: 「조금 더 카메라를 뒤로 빼야 될」. `net_camera`'s re-measured rows say the island fits with margin; **the user says whether it is far enough** |
| **The boat stopped being a resource** | **user only** | ⚠ **The word to listen for is 곁다리.** It has been said three times; the third was about the boat being something to manage. **This round is scored by its absence, not by a feature** |
| **The speed-up does not change the SIM** | **net + probe** | `net_plan`'s 1×/6× equivalence rows **including the past-the-verdict and uneven-`dt` rows**, and the probe printing both runs side by side. ⚠ **If they differ, the rule is wrong, not the multiplier** |
| **The speed-up does not destroy the PICTURE** | **net + verify-look** | ⚠ **A separate row on purpose.** `net_fx_view`'s ladder rows (9.7) bound the flash duty and the lunge's return to rest at every step; **verify-look watches one fight at 6×.** Without this row the row above goes green with every body permanently white and displaced |
| **Order is a decision** | **probe, then user** | ⚠ **Restated by the reversal.** The probe's reversed-drop-order row reports whether the landed formation differs at all — **and 4.4 says formation is the ONLY thing it can differ in.** Then the user plans the same island twice in different orders and says why. ⚠ **If the user cannot name a reason, this row FAILS and the honest response is OPEN 0's brake, not a widget** |
| **Glyph count fell** | **user + a written number** | Count the glyphs per screen and write the number down. 6.1 predicts **8**; correct it after building |
| **The island is losable** | **probe** | **The BASELINE policy loses an island, or its worst island spends ≥ 70% of the limit.** ⚠ **The 49% figure it is compared against is re-measured under sub-stepping first** |
| **The hand does not move during combat** | **net** | `net_shell`'s three post-commit rows, paired with the row proving pan and zoom still work |
| **⚠ Final verdict** | **user only** | **The user does not say 「애매하다」 again** (GDD 미정 18). Every row above is a proxy |

⚠ **Acceptance is written into `plan-then-watch` AND `plan-then-watch` the moment it is heard.**
Conversations are lost; the repo is kept.

---

## 13. Documents that go false the day this ships

**Fix them in the same edit as the code, and Korean and English together.**

| Doc / comment | What dies |
|---|---|
| `islands.gd` `TIME_LIMITS` comment | *"the clock starts when the island OPENS"* — its own ⚠ already predicts this day. **The clock starts at the start button and planning is free** |
| `rules.gd` `BOATS` comment | the whole table and the throughput-inequality paragraph. **Delete; do not edit** |
| `battle.gd` `load_soldier` comment | the function is gone and the choice is the player's now |
| `battle.gd` `pending` / `boat_at` comments | both fields are gone; **the `boats` comment's `{boat, …}` key list becomes `{uid, …}`** |
| `battle.gd` `SoldierState` comment | LOADED is gone as a state anyone reaches — a soldier goes RESERVE → TRANSIT directly |
| `battle.gd` header | *"two guard lines"* becomes three, the phase-order contract gains the sub-step, **and `_phase_landings`' one-pass description becomes two passes** (4.4) |
| `hud_view.gd` header | the whole 1/2-key paragraph, and *"the berth box IS half of the resource meter"* — there is no berth and no resource |
| `look.gd` key + berth sections | thirteen constants and two renames (6.4) |
| `look.gd` `BOAT_SLOT_PX` / `HULL_BERTH_OFFSET_PX` comments | the **124 / 72 px** arithmetic and the `>= 98` floor derived from it. **Every hull is 46 px and `HULL_BERTH_OFFSET_PX` is deleted** |
| `look.gd` `ZOOM_MIN` / `WATER_MARGIN_TILES` / `CLIFF_FACE_WIDTH_PX` comments | **all three carry arithmetic derived from `ZOOM_MIN` 0.5625** — the 2275 px visible width, the 4.45-tile margin, the 2.25 px cliff line. **Re-measure all three, not the one being edited** (6.3) |
| `look.gd` `TARGET_LINE_MAX_COUNT` comment | *"⚠ THIS NEVER BITES IN PLAY. The three islands hold 4, 6 and 5 enemies"* — section 8 makes it 8 · 12 · 14 |
| `combat-juice` | its hook table (item 8's key half renames to the chip family, **and its berth half is DELETED, not renamed**), **and `TARGET_LINE_MAX_COUNT`'s row**, which records the constant as unreachable in both twins. ⚠ **Write the refutation there, not here** |
| `net_shell` comment on the hull literals | it documents a defect in a check being deleted with its axis (9.5's box) |
| `net_islands` header | the `_min_region_floor` paragraph — *"the largest single boat's capacity plus a tile"* becomes *the largest roster plus a tile* (8.4) |
| `net_camera` comment | *"at ZOOM_MIN the visible world (2275.56 px wide)"* → **2844.4** (6.3) |
| `game.gd` `_on_key` | the whole function and its two comment blocks |
| `plan-then-watch` | **① 결정 14 is DEAD and replaced by 결정 14R, with the user's own three sentences quoted** · **② the 「1~5 키」 claim — there are two keys** · **③ the `net_draw_leaf` misreading in the code table — the scanner already catches deletions, and case (c2) proves it** · **④ the 「섬당 30~40」 figure, with 8.1's arithmetic written in** · **⑤ 미정 3 · 4 · 6 · 7 · 8 · 9 · 10 · 11 · 12 close, and section 1 records the answers** · **⑥ OPEN 0 and OPEN 1 are added as named open items** |
| `cell-army-gdd` | **「투입」's boat arithmetic** — there is no wave and no capacity. ⚠ **It appears TWICE in each twin**, once in 「투입」 and once inside a later refutation box, and *re-measuring only the row someone is arguing about* is this repo's named failure. 미정 18 stays open |
| `session-loop` | whatever still assumes `load_soldier`, per-boat capacity, or a boat as a persistent object 미정 1 could bolt a slot onto |
| `boat-invasion` | ⚠ **its `Accepted` line records 곁다리 stopping. It did not — it came back a third time, pointed at the boat as a RESOURCE.** Add that; do not overwrite the original |
| `CLAUDE.md` | the 「1~5 소환 키」 line, and the state-of-the-tree net/check counts |

⚠ **A refutation that lands in a different doc from the claim does not propagate.** Every row above says
*go and edit that file*, not *record it here*.

---

## 14. Risk — what this can break silently

- ⚠⚠ **OPEN 0's missing brake is the biggest risk in the round and it is a user decision.** *Everything
  onto the cheapest beach* is expected to dominate. **A builder must not fix it.** 9.1's `배 수에 상한이
  없다` and 9.5's `열세 명 전부 보낼 수 있다` are the two rows that catch a quiet fix.
- ⚠⚠ **Deleting the keys before the drop gesture exists makes the game unplayable, not merely
  different.** `boats` would be permanently empty ⇒ nothing to commit ⇒ no island finishable. Section 2's
  atomic stage 1 is the mitigation and it is not optional.
- ⚠⚠ **`send` returns an int and `if battle.send(...)` reads uid 0 as a refusal** — and uid 0 is the first
  boat of every island, so it is the common case. 4.6.
- ⚠ **Lowering `ZOOM_MIN` without raising `WATER_MARGIN_TILES` reddens an existing `net_camera` row**, and
  raising it 5 → 12 nearly doubles the per-frame draw calls. **Measure the frame time.** 6.3.
- ⚠ **`_min_region_floor` has no compiling replacement and every obvious one is wrong** — including
  "1 + 1", which shrinks the bound while the real demand rises. 8.4.
- ⚠ **A planning state in the wrong enum breaks the shipped shell two ways and both look like the feature
  merely not working** — an outcome hold on frame one, or an uninteractive planning screen under a red
  「패배」 band. 4.3.
- ⚠ **Nothing today stops the planning gesture firing after the commit.** Three branches, no state test.
  A stray click breaks 결정 1 with the whole round green. Section 7.
- ⚠ **`_phase_landings` unloads in REVERSE drop order today**, which is the exact opposite of the user's
  rule, and it is invisible unless two boats aim at one tile. 4.4.
- ⚠ **A speed widget without the sub-step plays a different game, and it favours the player.** 5.1.
- ⚠⚠ **The speed widget destroys the PICTURE even after 5.2 makes it inert for the sim**, and no net in
  the tree drives a view above 1×. 5.4 and 9.7.
- ⚠⚠ **A verdict latched inside a long `dt` kills soldiers after the island is already won**, at 6× and
  not at 1×, and `army` carries to the next island. 5.2's box.
- ⚠⚠ **The default speed slot freezes the game at the start button** if it is left at 0. 5.3.
- ⚠ **Sub-stepping re-discretises `net_battle` and the probe as well as the shell**, so the 49% baseline
  is not comparable across this round unless it is re-measured. 9.6 and 11.
- ⚠ **`net_fx` and `net_fx_view` fixtures that forget `commit()` produce no events and still run plenty of
  checks**, so the zero-check rule does not catch them. 9.6.
- ⚠ **The hold-guard check becomes a fake green by construction** once the key it drives is deleted. 9.5.
- ⚠ **`field_view`'s function count does not move (43 → 43)** while one function is added, one deleted and
  one renamed. **It is the one to re-derive by hand.** 6.5.
- ⚠ **`IDLE_SOLDIER_COLS` and `GHOST_ALPHA` may be invisible to the literal scan** — neither suffix is in
  `PIXEL_SUFFIXES` or `TIME_SUFFIXES`. 6.5.
- **Fake-code shapes to watch, from `CLAUDE.md`'s list**: a route drawn from the drag rather than from
  `battle.boats` (the picture and the plan would be two facts); a ghost fan drawn with a constant offset
  so drop order has no picture; a "committed" look driven by a view flag rather than by
  `battle.committed()`; `_paint_body` handed a zero radius for the ghost.

---

## 15. Design doc corrections owed — **NOT applied by this plan**

⚠ **The two twins must be edited in the SAME edit, and this plan does not touch either.** Several agents
can be writing them at once; the main session applies these. **A fact changed in Korean and not in English
means the next agent builds the old design.**

| Doc pair | What is wrong | Korean wording to add | English wording to add |
|---|---|---|---|
| `plan-then-watch` | ⚠⚠ **결정 14 is reversed and must be STRUCK, with the user's own words and the reason** | 「⚠⚠ **결정 14 는 죽었다 (사용자 본인).** 「배 한 척에 병사 한 명, 다섯 척」이 아니라 **배는 무한이다.** 사용자의 말: 「배는 너무 곁다리 느낌이다 그냥 바다위에 초록색 지역에 내가 설계한 몬스터들을 무한으로 배를 띄워서 보낼 수 있는걸로하고 싶어」 ⇒ **상한은 배 수가 아니라 가진 몬스터 수로 옮긴다.** 그리고 **대기열 위젯은 없다** — 「대기열이라는 게 사실 좀 애매해」. 병사를 끌어다 놓으면 그 배가 출발하고, **놓은 순서가 곧 순서다.** 배는 왕복한다. ⚠ **제동 장치는 일부러 뺐다** — 「일단 빼고 만든 이후에 추가하자는 거임」. 버린 갈래는 `unlimited-boats-not-a-five-boat-cap`」 | 「⚠⚠ **Decision 14 is DEAD, by the user.** Not *"one soldier per boat, five boats"* — **boats are unlimited.** In their words: *"배는 너무 곁다리 느낌이다 … 무한으로 배를 띄워서 보낼 수 있는걸로하고 싶어."* ⇒ **the cap moves from the boat count to how many monsters you own.** And **there is no queue widget** — *"대기열이라는 게 사실 좀 애매해."* You drag a soldier onto a landing spot, that boat departs, and **the order you drop them is the order.** Boats round-trip. ⚠ **The brake is deliberately deferred** — *"일단 빼고 만든 이후에 추가하자는 거임."* The rejected branch is `unlimited-boats-not-a-five-boat-cap`」 |
| `plan-then-watch` | The 「어느 순서로」 acceptance row is graded 통과 불가능 **without the reason**, and the reason has now changed | 「⚠ **측정**: 배가 무한이면 **출항 시각 축이 아예 없다** — 커밋 프레임에 전부 뜬다. 순서가 정하는 것은 **대형 하나뿐**이다: 여러 배가 같은 해변을 노리면 `_free_tiles_from` 이 예약을 순서대로 써서 **먼저 놓은 쪽이 목표 칸에, 나중이 그 옆에** 선다. ⇒ 「어느 순서로」는 「누가 앞에 서나」이고 그 이상이 아니다」 | 「⚠ **Measured**: with unlimited boats there is **no departure-time axis at all** — every boat leaves on the commit frame. The only thing order decides is **formation**: when several boats aim at one beach, `_free_tiles_from` writes reservations in walk order, so **the first dropped stands on the target tile and the next stands beside it.** ⇒ 「어느 순서로」 means *who stands in front*, and nothing more」 |
| `plan-then-watch` | The wave arithmetic (a wave is five, the next lands `2 × steady / boat_speed` later) is **deleted, not corrected** | 「⚠ **파도라는 것이 없어졌다.** 배가 무한이면 병사마다 배가 하나이고 전부 커밋 프레임에 뜬다. 섬 1 기준 **1.75 s ~ 3.64 s** 안에 전원이 상륙한다 ⇒ 적 수는 「한 파」가 아니라 **병력 총합**에 맞춰 잰다」 | 「⚠ **There are no waves.** Every soldier gets a boat and all of them depart on the commit frame; on island 1 the whole roster is ashore in **1.75 s to 3.64 s.** ⇒ Enemy counts are measured against the **roster total**, never against a wave」 |
| `plan-then-watch` | The 「배가 곁다리」 history is recorded as closed by `boat-invasion` | 「⚠ **곁다리가 세 번째로 돌아왔고, 겨눈 곳이 다르다.** 앞의 두 번은 「배가 이야기에서 곁다리다」였고 배와 상륙 라운드가 그것을 멈췄다. 세 번째는 **「배가 관리할 자원이라 곁다리다」**이고, 답은 배를 더 넣는 것이 아니라 **배를 없애는 것**이다」 | 「⚠ **곁다리 came back a third time, pointed somewhere else.** The first two were *the boat is a side-thing in the fiction*, and the boat round stopped that. The third is *the boat is a resource I have to manage*, and the answer is **less boat, not more**」 |
| `combat-juice` | Both twins record `TARGET_LINE_MAX_COUNT` **8** as *"unreachable on these three islands (6 enemies max); the check is synthetic"* | 「⚠ **반증**: 섬당 적이 **8 · 12 · 14** 로 올라가면서 이 상수는 **처음으로 문다.** 섬 2·3 은 적이 4마리·6마리 죽을 때까지 의도선을 **한 줄도** 안 그린다 — 손이 안 움직이는 그 구간이 바로 읽어야 하는 구간이다. **14 로 올린다**」 | 「⚠ **Refuted**: with the counts raised to **8 · 12 · 14** this constant **bites for the first time.** Islands 2 and 3 draw **no** intent lines until 4 and 6 enemies are dead — the phase where the hand cannot move and reading is the whole activity. **Raised to 14**」 |
| `combat-juice` | Item 8's hook table names the berth family | 「⚠ 항목 8 의 **정박지 절반은 죽는다** — 정박지가 없어졌다. 키 절반은 시작 버튼의 거절 흔들림으로 이름만 바뀐다」 | 「⚠ Item 8's **berth half DIES** — there are no berths. The key half is renamed to the start button's refusal shake」 |
| `boat-invasion` | its `Accepted` line reads 곁다리 as closed | 「⚠ **이 줄은 여전히 참이지만 완결이 아니다** — 곁다리가 다른 뜻으로 한 번 더 나왔다. 위 행 참조」 | 「⚠ **Still true, but not the end of it** — 곁다리 returned in a different sense. See the row above」 |
| `cell-army-gdd` | ⚠ Repeated here only because 「투입」's boat arithmetic appears **TWICE in each twin** — once in 「투입」 and once inside a later refutation box. **Re-measure both, not the one being argued about** | — | — |

⚠ **The rejected branch is already written**: `unlimited-boats-not-a-five-boat-cap`. **This plan does not
edit it** — another agent holds the design docs this round — but any later reader looking for *what was
dropped and why* is sent there, not here.

---

## 16. What this plan was attacked with, and what the reversal did to each finding

**Twenty findings from an adversarial pass over the pre-reversal plan.** Recorded so the next session does
not re-raise them. ⚠ **Three were refuted by arithmetic against the real files, and those three rows are
the most useful ones here** — re-deriving them costs an hour each.

| # | Attack, in one line | Disposition **after the reversal** |
|---|---|---|
| 1 | The view clock is not scaled by `k`, so `HIT_FLASH_SEC`, `LUNGE_SEC` and `SPARK_SEC` all break at 6× | **STANDS — FIXED** by 5.4; 9.7 is the net |
| 2 | The outcome guard outside the sub-step loop lets a decided island keep killing | **STANDS — FIXED** by 5.2; 9.1 has the past-the-verdict row |
| 3 | "Whole sub-steps plus one remainder" is not additive over arbitrary `dt` | **STANDS — FIXED** by `_substep_acc`; 9.1 has the uneven-`dt` and sub-step-count rows |
| 4 | `_boat_grabbable` and `hud_view._draw` read `pending`; the first makes an empty boat unplaceable | **MOOT** — both are deleted (4.6). The empty-boat problem cannot exist: a boat is created BY a soldier |
| 5 | `net_shell`'s 124 / 72 hull literals, the `>` row, the berth load label and the draw-order row all break, and 9.5 called them unchanged | **WIDENED** — 9.5's box now also deletes the idle-hull rows and the four `pending`/`cap_of` self-checks |
| 6 | Sub-stepping re-discretises `net_battle` and the probe's `DT`, and the 49% baseline is pre-sub-step | **STANDS — FIXED** by 9.6 and 11 |
| 7 | `net_islands`' `t.eq(min_region_floor, 5, …)` self-check and its Korean label were missing from the move list | **STANDS, and the literal is now 14, not 6** — 8.4 |
| 8 | *"Gate all four handlers"* gates `_on_wheel`, which holds no plan gesture, and reddens the anti-inert-shell row | **STANDS — FIXED**; section 7 gates three plan BRANCHES |
| 9 | Three constant rows carried one bound written twice, or two bounds on different axes | **STANDS** — 6.4 keeps the rule; the offending rows (`HUD_BERTH_*`, `HUD_ROSTER_*`) are deleted with their features |
| 10 | `SPEED_STEPS` in `look.gd` with a comment saying it changes nothing, while slot 0 halts `_phase_clock` | **STANDS — FIXED** by 5.3 |
| 11 | (duplicate of 2, from the sim lens) | with 2 |
| 12 | (duplicate of 3) plus: the remainder makes per-second passes 120 at 1× versus 70 at 6× | **REFUTED in part.** **Measured in IEEE double: `6 × (1.0/60.0) == 0.1` exactly, quotient exactly `6.0`, remainder exactly `0.0`.** Both arms run 60 passes. The structural half is real for non-multiple `dt` and the accumulator fixes it anyway |
| 13 | `_speed_slot := 0` is the pause, so the fight is frozen the moment start is pressed | **STANDS — FIXED** by `SPEED_SLOT_DEFAULT`; 9.5 pumps frames with no chip pressed |
| 14 | The "ten bodies trade" band ignores the reinforcement period, so the two waves never coexist and the stage-4 target has no solution | **DELETED BY THE REVERSAL** — there are no waves at all. 8.2 replaces the band with an aggregate one |
| 15 | "At least one of five policies loses" is satisfied by the dribble control; policy 1 and *near* are byte-identical | **HALF DELETED, HALF STANDS** — dribble no longer exists as a policy (no timing axis); the duplicate policy still has to go |
| 16 | `plan_order`'s tie-break is unreachable on the shipped islands, and the probe row guarding the on-screen number reverses `queue`, a different array | ⚠ **REVERSED BY THE REVERSAL.** It was unreachable because capacity 1 meant one soldier per landing on a 700+-tile component. **With every soldier arriving simultaneously at one beach, the reservation contention is the common case** — 9.1's order rows move from a synthetic fixture onto a real island. **And the array confusion is gone: there is only one order now** |
| 17 | *"Every beach meets at least two detect circles"* is false on all three islands | **STANDS — FIXED** by 8.3's box and `EXPECT_UNCOVERED_COAST`. ⚠ **It matters MORE now**: under OPEN 0 the cheapest beach is where everything goes |
| 18 | The `boat_count() → 2` mutation cannot redden the region floor under either formula | **STANDS AND WIDENED** — **no formula reddens it**, because every island is one component of 744 / 760 / 716 tiles. The synthetic one-pocket `Grid` is the only bite. 8.4 |
| 19 | P7 draws a queue COUNT while the doc asks *"배마다 누가 탔는지 보인다"*, and `soldier_state` carries no boat | **MOOT** — there is no queue. The ghost fan (P7) shows *who* and *where* directly, with zero new leaves |
| 20 | `TARGET_LINE_MAX_COUNT` 8 switches item 6 off for the opening of islands 2 and 3 once the counts rise | **STANDS — FIXED** by 6.2's box; the refutation goes to `combat-juice` (section 15) |

---

## 17. What the build was attacked with — **three adversarial passes over the FINISHED tree**

**Section 16 records what the PLAN was attacked with. This section records what the CODE was**, after all
four stages landed. Seventeen findings came back (several were the same defect seen through different
lenses and are folded here). ⚠ **Every "fixed" row below was confirmed by a mutation that reddens the new
check, run as one command with the round so the `[지문]` fingerprints differ by that mutation alone.**

| # | Finding | Disposition |
|---|---|---|
| 1 | **The ghost's body could be drawn at radius 0.0 with the round green** — `field_view._draw`'s P7 pass, `Look.body_radius_of(gtype)` → `0.0` left 13 identical 3 px dots with melee and ranged indistinguishable, and the fan offsets still perfect. This is verbatim the fake section 14 predicted | **FIXED.** `net_shell`'s ghost loop now reads the captured `radius` off the spy and compares it to `Look.body_radius_of` of the carried soldier's type, with a floor above 0. The mutation reddens `유령마다 반지름이 그 병종의 몸 크기다` |
| 2 | **The idle army at the harbour could be drawn at radius 0.0 too, and worse** — `idle_soldier_rect` computes its rect from the same call INDEPENDENTLY, so `game._soldier_hit_at` kept answering over a ~28 px box while a 3 px dot reached the screen. The picture and the hit target were two facts | **FIXED.** The idle loop asserts the captured `radius` is above 0 **and** that `2 × radius` equals `idle_soldier_rect(i).size.x` — that second half is the row that says they are one fact. The mutation reddens |
| 3 | **`GHOST_ALPHA` could be 0.02 with the round green.** The shipped floor was `> 0.0`; 6.4's written floor is `>= 0.35`, and at 0.02 the only picture carrying drop order is invisible | **FIXED**, and **the whole 6.4 table was re-measured rather than the row that was caught.** `net_shell._the_plan_constants_have_both_ends` now asserts both ends of `HUD_START_ORIGIN_PX` · `HUD_START_SIZE_PX` · `HUD_START_TEXT_OFFSET_PX` · `HUD_START_FONT_SIZE_PX` · `HUD_SPEED_ORIGIN_PX` · `HUD_SPEED_SIZE_PX` · `HUD_SPEED_GAP_PX` · `IDLE_SOLDIER_PITCH_PX` · `IDLE_SOLDIER_COLS` · `IDLE_SOLDIER_ORIGIN_PX` · `GHOST_FAN_PX` · `GHOST_ALPHA` · `CHIP_FX_SEC` · `REFUSE_SHAKE_PX` · `CLIFF_FACE_WIDTH_PX`. Inverted on three of them |
| 4 | **`hud_view._process` could age its drawer by `delta` instead of `delta * _speed_scale` with the round green.** `net_shell` read the FIELD and proved the number was handed down, never that it was used — `CLAUDE.md`'s named shape exactly | **FIXED.** `net_fx_view._the_hud_ladder_ages_with_the_speed` drives a real `HudView` at 1× and at 6×, over the same REAL interval, and reads the shake off the **drawn rect**: at 6× it is back at exactly zero, at 1× it is still displaced (the self-check that the interval is genuinely short). The mutation reddens |
| 5 | **The ghost fan was offset by the boat's GLOBAL index in `battle.boats`**, so from the fourth boat on a ghost stood outside the ring it belonged to and the thirteenth sat ~3.8 tiles away — over other terrain. The net could not see it because all three of its boats aimed at one tile | **FIXED — a real defect in `src/`, not only in a net.** `field_view` now ranks the fan by **how many earlier boats share the same `target`**. `net_shell`'s fixture drops two boats on one beach and a third on another, and asserts each ghost is within `TARGET_RING_R_PX` of **its own** ring. Restoring the global index reddens two labels |
| 6 | **BLOCKER — `tools/probe/run_run.gd` did not parse.** It drove `Rules.boat_count`, `Rules.cap_of`, `battle.load_soldier`, `battle.pending`, `battle.boat_at`, `battle.boat_busy` and `battle.launch`, every one deleted this round. Three acceptance rows and the whole of section 11 are scored by it, and **the round was green over a dead instrument** because the runner loads `res://tests/nets/` and nothing else | **FIXED — rewritten to section 11's shape.** Policies became plan generators (`_make_plan` → `send` in drop order → `commit()` → step to a verdict touching nothing). `_policy_dribble` deleted (no timing axis survives), the duplicate policy 1 deleted, **`split` added**, and the reversed-drop-order, one-tile-spread, first-blow and 1×/6× rows added. `_input_open` is gone and its absence is reported: the hand does nothing during execution **by design**, so planning actions are printed in its place |
| 7 | **Nothing in `tests/` loads `tools/`, so finding 6 could happen again silently** | **FIXED — new guard.** `net_citations._tools_still_parse` loads every `.gd` under `tools/` and pins the probe's shape (`_make_plan` and `_play_island` must exist), so an emptied stub does not pass either. Renaming `_make_plan` reddens three labels plus stderr |
| 8 | **Stage 4 was not built while `combat-juice`'s refutation box already asserted the counts WERE 8 · 12 · 14** | **FIXED BY BUILDING IT.** `islands.gd` gained 19 characters at the coordinates in 8.3 (all 19 verified `.` first); `net_islands` reads **8 · 12 · 14**. `Look.TARGET_LINE_MAX_COUNT` → **14**. `EXPECT_UNCOVERED_COAST` is a new hand-measured literal per island — **13 · 14 · 4**, and island 1's 13 is exactly what 8.3's box predicted — with a row asserting the cheapest start-sendable tile is inside some detect circle (on island 1 it was NOT before this) |
| 9 | **`EXPECT_STRICT_UNREACHED` moved 14 → 63 on island 2**, and the paragraph certifying the old 14 by hand cannot be scaled to 63 | **FIXED, and the prose became a check.** The property that made those jams benign — a nearer enemy exists, so `_nearest_enemy` sends the soldier at the blocker first and its tile frees — is now asserted on **every** blocked pair (`_a_nearer_enemy_exists`), and it passes with zero exceptions. The terrain-only walker still reaches every enemy from every sendable tile on all three islands |
| 10 | **`net_fx_view`'s target-line row was pinned at 9 enemies against a cap of 8** | **FIXED and re-measured at both ends.** At exactly `TARGET_LINE_MAX_COUNT` (14) living enemies all fourteen lines draw — **that arm is now a real island's opening rather than a synthetic fight** — and at 15 none do |
| 11 | **`battle.gd`'s `boats` header claimed 미정 16 was settled the way the user said.** The boat does NOT depart on the drop; it sits at `t == 0.0` and nothing moves until `commit()` | **FIXED.** The comment now says what is true and that it is a CHOICE: the drop creates the boat, every boat departs on the commit frame (reading ②), and **the question is still the user's to close.** A line recording which reading the build assumed was added under 미정 16 in **both** design twins |
| 12 | **Both `plan-then-watch` twins still read `Implemented: none`**, `docs/design/README.md`'s row said `none` / `nothing chosen`, and this plan's `Status` said `written, nothing built` | **FIXED.** All three now name what shipped and what did not. **`Accepted` was left alone on purpose** — no user has looked at a screen, and acceptance does not close by inference |
| 13 | **`docs/plans/README.md`'s new row advertised "five one-seat boats"** — 결정 14, the decision the user reversed the same day, restated in one of the three indexes `CLAUDE.md` calls the whole of `docs/` | **FIXED.** The row now reads *unlimited one-seat boats created by the drop, round-tripping*, names `unlimited-boats-not-a-five-boat-cap`, and carries OPEN 0's warning so the index cannot be read as licence to write a cap |
| 14 | **`combat-juice` still described the deleted HUD** — item 8's berth half, `_paint_key`, `_paint_berth`, `note_launch`, `key_rect_px`, `KEY_FX_SEC`, `BERTH_FX_SEC`, and a hook table of 18 names none of which `hud_view.gd` holds | **FIXED in both twins, same edit.** Item 8 rewritten to the chip family with the berth half deleted rather than renamed; the hook table rewritten to the 13 names `net_draw_leaf._table()` actually holds; the totals re-derived to **77 / 21**; the constants table renamed and `BERTH_FX_SEC` struck. ⚠ **`WATER_MARGIN_TILES` was re-measured in the same pass** — it said 5 / 2436 tiles and the tree holds 12 / 4032 |
| 15 | **`cell-army-gdd` still carried the boat arithmetic, TWICE in each twin** | **FIXED in both twins, same edit, and all three occurrences in each** — the 「투입」 section head now carries a 결정 14R box, and the 「hold back」 refutation and the next-session list each carry the strike. ⚠ The 「hold back」 conclusion got **stronger**, not weaker: *nothing prevents everything-at-once* is now the shipped rule rather than a side effect of a deleted interval |
| 16 | **`boat-invasion`'s `Accepted` line recorded 곁다리 as closed** | **FIXED — added, not overwritten.** Both readings are true at once: the first two occurrences were *a side-thing in the fiction* and this round genuinely stopped those; the third is *a resource I have to manage* |
| 17 | **`session-loop` still assumed `load_soldier` and per-boat capacity** | **FIXED in both twins.** Undecided 10 (*does capacity count bodies or cost*) is **closed by deletion** — there is no capacity; the `load_soldier` rows record that it was deleted outright, not re-signified |

### ⚠ What the re-measured probe actually says — **the numbers, not a verdict**

**The baseline was printed at the OLD counts first, exactly as section 11 demands**, so the comparison
below is not a discretisation artefact.

| | worst island, % of its limit | islands lost by the baseline |
|---|---|---|
| pre-sub-step, 4 · 6 · 5 enemies (the 49% this plan quotes) | **49%** | none |
| **post-sub-step, 4 · 6 · 5** | **27.6%** | none |
| **post-sub-step, 8 · 12 · 14** | **61.8%** | none |

- ⚠⚠ **The 49% figure is not comparable to anything after the sub-step, and it now has a replacement**: at
  the old counts under sub-stepping the baseline's worst island is **27.6%**, not 49%.
- **The losability gate is still 미달, by 8.2 points.** Section 12's row is *the BASELINE loses an island,
  or its worst island finishes above 70%*; the baseline wins all three at 61.8%. ⚠ **It was not tuned to.**
  What did happen at these counts: island 3 costs the baseline **10 of its 12 soldiers** and ends on a pool
  of **7.0**; the **far-shore plan LOSES island 3 outright (wiped)**; the **split plan loses it too.**
  ⇒ **The game is losable — the dominant plan is not the one that loses.** Raising the counts again is
  결정 11's number and therefore the user's, not a builder's.
- **Order is a decision, measured.** Same tiles, drop sequence reversed: the soldier standing ON the target
  tile changes on all three islands (0 → 9 · 0 → 12 · 0 → 12), and island 3 moves **29.5 HP and 12.63 s**.
  4.4 predicted the effect would be small; **on island 3 it is not.**
- **The speed ladder is inert**, printed side by side: 1× and 6× land on `elapsed` 24.633 s, the same
  outcome, and a maximum `enemy_hp` difference of **0.000000**.
- **The dominant plan under OPEN 0, run explicitly**: the whole roster onto one tile spreads over a disc of
  radius **2.83 tiles** and lands its first blow at **1.75 s**. Those are the two numbers a landing-tile
  capacity brake would be sized from.
- **`_same_beach_is_a_control` and `_inverted_must_lose` both pass**, so the rows above are a measurement
  and not noise.

### ⚠ Still open after this pass

1. **The losability gate reads 미달 (61.8% against 70%).** Not tuned away. It is 결정 11's number and the
   user's call.
2. **`CLAUDE.md` was NOT edited** — this agent does not edit that file. Three things in it are now false:
   the 「1~5 소환 키」 line (the shipped build had **two** keys and now has none), the state-of-the-tree
   **11 nets / 967 checks** (it is **12 / 1328**), and 「`tools/look/` — only its `README.md`」
   (`capture_map.gd` is there and it parses).
3. **The `[지문]` fingerprint covers `src·tests·docs` and NOT `tools/`.** A mutation inside the probe leaves
   it unmoved — measured while inverting finding 7 — which is exactly the claim the print exists to make.
4. **This plan is still in `1.ready` although all four stages are built.** Moving it is three edits and the
   main session makes them.
5. **Nothing is accepted.** No user has looked at a screen, and every 「user only」 row of section 12 is open.
