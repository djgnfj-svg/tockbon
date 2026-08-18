# Plan — the title and the map: building the outside of a run

**Status**: `2.active` — **steps 1–4 and 6 are BUILT and the round is green (14 nets, 1933 checks).
Step 5 — the three new grids — is NOT done, and step 7's instrument had to be repaired.** Moved out of
`1.ready` on 2026-08-19 because it is part-built, not startable-from-scratch. ⚠ **A SECOND adversarial
pass ran after the first one's fixes landed and found six more fake greens** — findings 16–21 below, all
of them the same shape: *the value was computed and handed to a leaf, and nothing measured that it was
visible.* Design: `title-and-map`.

⚠ **What the user has and has not seen.** They looked at the title and the map, judged both readable, and
named two defects — reachable nodes indistinguishable at rest, and reward glyphs too small. **Both are now
fixed and the round is green at 1933 checks**, with the four node states told apart by size AND brightness
AND what is drawn on top, so the read survives a still frame. **Nothing beyond that is accepted.**

⚠⚠ **What is owed, and it is written here because nothing else in the repo said it.**

- **Step 5 — the three new grids — was not done.** `Rules.MAP_NODES`'s island column is still the
  step-1 temporary `[0, 1, 2, 1, 2, -1, 2]`: **three grids serve six island-opening nodes**, so island
  1 serves nodes 0 and 3, and island 2 serves nodes 2, 4 **and the boss.** Every route replays terrain
  it has already solved, which is the branch the design REJECTED on record. `rules.gd`'s own header
  declares the temporary; **no doc did until now.** ⇒ **What lands with those grids**: `TIME_LIMITS`,
  the invariant/fingerprint rewrite, `net_islands`'s 「두 칸이 같은 격자를 안 쓴다」, and the island
  column `[0, 1, 3, 4, 5, -1, 2]`
- **The measured consequence is not cosmetic.** The probe walked both branches and the **beak branch
  loses the run on its second node**, because node 2 opens the LION grid — see the design's probe box.
  ⇒ **The fork cannot be measured until the grids exist**
- **`net_islands`'s landing-region floor was half-applied** and is now fixed: `_min_region_floor()`
  counted ONE reward application (14) while a route can step on three (20). It never bit on the three
  shipped grids and would have passed a 15-tile landing region on a new one

**What this plan does NOT do.** Elite nodes · artifacts · map generation or any RNG in `src/sim/` ·
unlocks, saving, anything a run carries out · fog and unknown nodes · the refit screen and the
cell/object economy · retuning `TIME_LIMITS` · new enemy TYPES · 3D · a settings screen with real
settings (open B below) · replacing `tools/look/`'s capture scripts · touching `project.godot`'s
`run/main_scene`, which **stays `res://src/shell/game.tscn`** — the title is a state inside the shell,
not a scene, so there is no second scene file and no autoload.

⚠ **Read the design doc's five refutation boxes before writing a line.** Four of them overturn a
sentence that was in the previous draft of that same doc, and the plan below is built on the corrected
side of each.

---

## 0. OPEN questions — **the build does not stop for them, and each has a default**

**These go to the user in ONE message.** If no answer comes back, the default is what gets built.

| # | Question | Default this plan assumes | What changes if the answer differs |
|---|---|---|---|
| **A** | ⚠⚠ **「두 줄」 is ① (one of two per floor) or ② (two columns, one from each)?** The user's own sentence — ***"두 줄로 떠서 양쪽에서 하나씩 선택하는"*** — reads as **②**; the only thing pointing at ① is today's word ***"슬더슬식"*** | **①** | ⚠⚠ **Step 1's `MAP_NODES` / `MAP_EDGES`, step 2's coordinate table and step 5's three grids are ALL re-derived.** ⇒ **Ask before step 5 starts.** Steps 1–4 are cheap to redo; three hand-authored grids are not |
| **B** | **What does 설정하기 do?** `src/` has no audio, no window mode, no input map, no saved config; `FX_GAIN` is a `const` Array and cannot be written at runtime | **It does not press.** Drawn at `PRESS_ALPHA_OFF`, zero saturation, no border, **no hover response** | If the user wants real settings: `FX_GAIN` `const` → `static var` (one edit, and `net_draw_leaf`'s array-literal case still bites it), plus a fourth screen. **That is a separate round** |
| **C** | **What does the chest pay?** | **Every LIVING soldier back to full HP.** Dead rows untouched | ⚠⚠ **This is not a preference.** The design's HP schedule shows the cells–beak–beak route reaching the chest at **43.0 pool** against island 3's measured wipe threshold (between **61.5** and **84**). A smaller chest makes that route unwinnable; a chest paying cells makes it free value |
| **D** | **The roster grows 14 → 20 and the panel 560×400 → 560×480.** Consequence of C and of a route taking up to three cell nodes (`10 + 3×3 = 19` soldiers) | **Yes, do it** | If the user refuses, the map must be re-authored so a route can take at most **one** cell node — which removes ①'s question from one of the two forks |
| **E** | **Which grid goes on which node.** Island 3 (the lion) is the boss; island 1 is floor 1; island 2 is one floor-2 node; the three NEW grids are the other floor-2 node and both floor-3 nodes | **Yes** | Only the `MAP_NODES` island column moves |

⚠ **Do not fill any of these in from the conversation.** The design doc records that the previous round
failed exactly by inferring an answer nobody gave.

---

## 1. Build order — **seven steps, each one a place to stop with a green round**

**The big loop closes at step 4.** Everything before it exists so step 4 can be played end to end.

| # | Step | Green at its halt means | Nets that must be green |
|---|---|---|---|
| **1** | **The sim**: `rules.gd` node/edge tables + enums · `src/sim/map.gd` · `run.gd`'s `MAP` state and per-node rewards · `army.heal_all()` | **A whole run walks a route headless**, chest included, with no view and no shell | `net_map` (new, sim half) · `net_run` (rewritten) · `net_battle` `net_boat` `net_plan` `net_coast` unchanged and still green |
| **2** | **`look.gd`**: every constant of both screens, each with a floor and a ceiling in its own comment. Plus roster/panel growth (open D) | Nothing is drawn yet; **the numbers exist in one file and nowhere else** | `net_draw_leaf` (the loose-constant half only — its per-function table is still 3 files) |
| **3** | **The two views**: `src/view/title_view.gd` · `src/view/map_view.gd`, drawing for real, driven by nets on an untreed and a treed instance | **Both screens draw and every leaf's arguments are pinned** | `net_title` (new) · `net_map` (view half) · `net_draw_leaf` (full table, 5 files) |
| **4** | ⚠⚠ **The shell**: title/map/island states, the input branches, `battle` nulled on the map, restart → title | **The loop plays: launch → title → 시작하기 → map → node → island → map → … → boss → panel → title.** ⚠ **Three grids are still serving six nodes here** — declared, temporary, and closed by step 5 | `net_shell` (rewritten) · everything above |
| **5** | **Three new grids** + `TIME_LIMITS` + `net_islands`'s invariant rewrite + fingerprints + the enemy bound + `_min_region_floor()` 14 → 20 + `MAP_NODES`' island column | **Six grids, six island-opening nodes, no two nodes sharing a grid** | `net_islands` (rewritten) |
| **6** | **Presentation**: the reveal stagger, the travelling ring, the clear-fill, the chest's climbing number, the scene fade, hover and press | **Every rule that changes state says so on screen** | `net_title` · `net_map` grow their beat rows (floor AND ceiling on every one) |
| **7** | **The instruments**: `tools/probe/run_run.gd` walks a ROUTE · `src/sim/islands.gd`'s stale `TIME_LIMITS` comment · `docs/` acceptance lines | The probe can answer *do different routes produce different outcomes* | full round |

⚠ **A stage boundary is "what can be green at its halt", not "which files it touches"** — the same rule
`plan-then-watch` used. Step 2 touches `look.gd` alone precisely so step 3 has nothing to invent.

⚠⚠ **Step 4's temporary island column is the one deliberate lie in this plan, and it is bounded**:
`MAP_NODES` ships at step 1 with islands `[0, 1, 2, 1, 2, -1, 2]` and **step 5 replaces it with
`[0, 1, 3, 4, 5, -1, 2]`**. The check that forbids two nodes sharing a grid **lands in step 5 with the
grids**, so no round is ever red for it. Write that sentence into `map.gd`'s header, not only here.

---

## 2. Files — **what DIES**

| File | What dies | Why it cannot simply stay |
|---|---|---|
| `src/sim/run.gd` | **`const _REWARDS := [Reward.COUNT, Reward.BEAK, Reward.NONE]`** and **`static func _reward_for_island(i)`** | Indexed by ISLAND. A fourth island silently pays nothing (the guard returns `NONE`), and the design moved the reward onto the NODE |
| `src/sim/run.gd` | **`enum Reward { NONE, COUNT, BEAK }`** — moves to `Rules.Reward` and gains `HEAL` | The node table lives in `rules.gd` and must name a reward. `rules.gd` referencing `Run` and `Run` referencing `rules.gd` is a class cycle; **only one direction survives, and it is `Rules` at the bottom.** ⚠ Sites to rewrite: `run.gd` (7) and `tests/nets/net_run.gd` (9). **`Run.State` does NOT move** — it is referenced by `panel_view`, `net_shell`, `net_run` and the probe, and nothing in `rules.gd` needs it |
| `src/sim/run.gd` | The header sentence *"This lives here and not in `rules.gd` because it is the shape of the session"* | It was true of `_REWARDS`. It is false of the node table, which is a rule about what a node pays |
| `src/shell/game.gd` | **`_unhandled_input`'s first two statements, `if run == null:` / `return`** | ⚠⚠ **They are what make 시작하기 unpressable.** Not moved, not layered over — **deleted, and the title branch takes that position.** See the design's refutation box |
| `src/shell/game.gd` | `_ready()`'s `run = Run.new()` and its `_open_island()` call | The game must open on the title |
| `tests/nets/net_islands.gd` | **`EXPECT_HARBOUR_TILES` · `EXPECT_START_TILE` · `EXPECT_SENDABLE` · `EXPECT_SENDABLE_UNION` · `EXPECT_COAST` · `EXPECT_CUTS` · `EXPECT_SPAWNS` · `EXPECT_WAVE1` · `EXPECT_STEADY` · `EXPECT_RELOCATES` · `EXPECT_STRICT_UNREACHED` · `EXPECT_UNCOVERED_COAST` · `EXPECT_DROPPABLE` · `EXPECT_START_SENDABLE` · `EXPECT_LIMITS`** — fifteen per-island tables | Every one grows by an entry per island and fourteen demand a measurement. Replaced by literal floor-and-ceiling invariants plus one fingerprint per island |
| `tests/nets/net_islands.gd` | `t.eq(Islands.count(), 3, "섬은 셋이다")` | A literal island count. Becomes *the island count equals `TIME_LIMITS`'s length*, which is a real invariant |
| `tests/nets/net_run.gd` | `t.eq(r.army.has_beak[2], 0, "부리는 슬라이스 전체에 하나뿐이다 …")` | **False now** — a route can hold two beak nodes. Rewritten as *one node pays the beak exactly once* |

⚠ **`EXPECT_ROWS` (32) and `EXPECT_COLS` (48) do NOT die.** They are scalars that do not move when an
island is added, which is exactly what makes them invariants already.

---

## 3. Files — **what CHANGES MEANING SILENTLY**

**This table is the one a builder must read twice.** Every row is a place where the code keeps compiling,
the round keeps printing green, and the game is wrong.

| File · symbol | What changes | ⚠ Why it is quiet |
|---|---|---|
| `run.gd` `_advance()` | `if island_index + 1 < Islands.count(): island_index += 1; _state = State.BATTLE` → **`_state = State.MAP`**, and `island_index` is no longer written here at all | ⚠⚠ **Skip this and the map never appears.** `finish_island(true)` currently walks to the next island by itself, so **a map added on top just gets walked past.** Adding the map is cheap; removing the automatic +1 is the expensive half |
| `run.gd` `island_index` | Stops being the run's position. It becomes **"the island the node I am standing on opens"**, written only by `enter_node` | Its header comment argues at length that it never leaves the range of real islands. That argument survives; the OWNER changes |
| ⚠⚠ `net_run` — five labels | *「첫 섬을 이기면 곧장 둘째 섬이다 — 수 보상은 고를 것이 없다」* · *「고르는 동안 섬 번호는 둘째 섬에 머문다」* · *「셋째 섬이다」* · *「이겨도 없는 넷째 섬으로 넘어가지 않는다」* · *「첫 섬으로 돌아간다」* | **Lines to rewrite, not breakage.** ⚠ **The risk named here is that a builder meeting five surprise reds on the round's core edit WEAKENS them instead.** Each one gets a named replacement in §8. ⚠ **And one new row in the opposite direction**: `finish_island(true)` leaves the run in `MAP` and **does not move `island_index` on its own** — a floor as well as a ceiling |
| `game.gd` `_open_island()` | On entering the map it must **explicitly set `battle = null`** | ⚠⚠ **Today it deliberately does not** (the last island has to stay drawable behind the panel). Leave it and the just-finished island **keeps drawing under the map, keeps panning, and the HUD's clock and start button come with it.** `field_view._draw` gates on `battle == null or army == null or battle.grid == null`; `hud_view._draw` gates on `battle == null`. **That one field is the only lever that silences both at once** |
| `game.gd` `_unhandled_input` order | The title branch replaces the `run == null` return; the map branch sits **above the `battle != null` block** | ⚠ Below it, a click on the map pans the camera on the island behind it — the current fall-through is `_panning = true` |
| `game.gd` `_process` first line | **Stays exactly as it is**: `if run == null or battle == null: return` | ⚠ **Both new views age their own clock in their own `_process`** — `panel_view._panel_age` is the precedent. Godot calls a child's `_process` even when the parent returned early. **Making the shell hand time down puts one clock in two places.** ⚠ Do NOT "fix" this early return |
| `game.gd` `_release_hold()` | The beak branch's `_open_island()` becomes **"go to the map screen"** | `apply_beak` now ends in `MAP`, not `BATTLE`. Calling `_open_island()` there would ask `begin_island()` for a fight the run is not in, get `null`, and leave the previous island's `battle` on screen under the map |
| `game.gd` `_close_island()` | Its comment *"Island 1's reward has nothing to click, so this re-opens unconditionally"* is now **wrong** | `take_count_reward()` ends in `MAP`. Re-opening unconditionally re-enters the island just won |
| `panel_view`'s restart button (`game.gd::_click_panel`) | `run.restart(); _open_island()` → **`run = null; battle = null`** and re-bind | Returning to a finished map after the run ended shows a dead map. `run == null` IS the title, so this is one line — **but `battle` must be nulled in the same breath** or the boss island draws behind the title |
| `panel_view.panel_active()` | ✅ **NOTHING** | It is already `run != null and (state == REWARD or is_finished())` — an **allowlist**, false on both new screens for free. ⚠ **Do not re-file this as a risk and do not "harden" it**; it is closed in the tree. Just drive it from both new states in `net_shell` |
| `net_shell` — three literals | *「_ready 가 Run 을 만들었다」* · *「_ready 가 첫 섬을 열었다」* · **`t.eq(game.get_child_count(), 3, "_ready 가 자식 셋을 만들었다")`** | The third is the one the design doc originally missed. **Five children now**, and the `field → hud → panel` order assertion below it is rewritten too |
| `look.gd` `roster_capacity()` | `ROSTER_ROWS` 7 → **10** (capacity 14 → 20); `PANEL_SIZE_PX` y 400 → **480**; `PANEL_ORIGIN_PX` y 160 → **120**; `BUTTON_OFFSET_PX` y 320 → **420** | ⚠ A three-cell-node route fields **19** soldiers. `panel_view.roster_ids` caps at capacity and **silently drops the rest** — its comment currently reads *"the run holds at most 13 soldiers against 14 slots, so the cap never actually bites."* **It bites.** Checks: `72 + 10×(28+6) = 412 ≤ 480` · `420 + 48 = 468 ≤ 480` · `(720−480)/2 = 120` |
| `net_islands` `_min_region_floor()` | `START_MELEE + START_RANGED + REWARD_MELEE + REWARD_RANGED + 1` = 14 → **`… + Rules.map_max_count_nodes_on_a_route() * (REWARD_MELEE + REWARD_RANGED) + 1`** = **20** | ⚠ The formula assumes exactly ONE count reward per run. A landing region narrower than the simultaneous demand stalls a boat forever and the island runs to TIMEOUT **with nothing in the sim saying why.** ✅ **Measured today: the three shipped islands' smallest landing regions are 744 · 760 · 716 tiles**, so this raise breaks none of them and lands purely as a constraint on the three new grids. ⚠ **And its literal self-check `t.eq(min_region_floor, 14, …)` moves to 20 in the same edit, or the raise is invisible** |
| `net_draw_leaf` — **five totals** | view files **3 → 5** · `table.size()` **3 → 5** · `total_funcs` **77 → 120** · `total_leaves` **21 → 31** · `wide_scanned` **4 → 6** | **A name the table does not hold is red that day.** Both new files' per-function tables open in the SAME edit. ⚠ **A function with `draw` count 0 skips the argument check entirely** ⇒ **geometry is built in `_draw()` and handed to the leaf as an argument** (`_spark_points` is the precedent) |
| `tools/probe/run_run.gd` | Walking `island_index` → **choosing a route through the map** | ⚠ It calls `run.finish_island` and reads `run.state()`; with `MAP` in the enum it would sit on the map forever, print nothing, and **a probe that hangs prints nothing at all** — the failure shape that once disarmed a whole net here |
| `src/sim/islands.gd` `TIME_LIMITS` comment | Its ⚠⚠ block says *"15 wins out of 15, the worst plan finishing at 49%"* | ⚠ **Re-measured 2026-08-18: two of five policies now LOSE the run, and the baseline worst is 61.8%.** The comment is stale in the direction that matters — it argues the clock can never bind, on numbers taken before the enemy raise. **Design cannot edit `src/`; the builder does this** |

---

## 4. The sim

### 4.1 `rules.gd` — the tables

⚠⚠ **Naming trap, and it is not hypothetical.** `net_draw_leaf._pixel_hits` sweeps
`px|width|radius|size|margin|alpha|ratio|offset|gap|font_size|cols` over **all of `src/` except
`look.gd`**, matching `NAME_<suffix> := <digit>`. **`MAP_COLS` or `MAP_ROW_SIZE` would redden a sim
constant.** The names below are chosen against that list. (`count` is in the *widened* list, which is
swept over `src/view/` + `src/shell/` only — so `Rules.map_node_count()` as a FUNCTION is safe, but no
`const MAP_NODE_COUNT := 7` is written.)

```gdscript
## rules.gd — the map's shape. It is here and not in run.gd because what a node PAYS changes what
## happens, and because run.gd already reads this file: rules.gd referencing Run would close a class
## cycle. `Run.State` stays on Run for the same reason in reverse — nothing here needs it.
enum NodeKind { FIGHT, CHEST, BOSS }

## What a node pays on the way out. Moved here from Run so the table below can name it.
## `HEAL` is new: it restores every LIVING soldier to full and touches no dead row, which is why the
## chest cannot undo a death. `COUNT` is applied on the win with nothing to choose; only `BEAK` opens
## a REWARD state; `HEAL` is applied the instant the node is entered, because a chest has no fight.
enum Reward { NONE, COUNT, BEAK, HEAL }

## One row is ONE NODE: floor, kind, reward, island index (-1 = opens no island).
## ⚠ The reward is the NODE's and not the KIND's: keyed by kind, every fight node pays the identical
## thing and the fork can never ask "cells or beak". See title-and-map, the reward-belongs-to-the-node
## refutation box.
## ⚠ `const X := PackedInt32Array([...])` is a parse error on 4.7.1, so this is a plain const Array
## and every read casts.
## ⚠ The island column ships as [0, 1, 2, 1, 2, -1, 2] in stage 1 — three grids serving six nodes —
## and stage 5 replaces it with [0, 1, 3, 4, 5, -1, 2]. The check that forbids two nodes sharing a
## grid lands WITH the grids, so no round is red for the gap.
const MAP_NODES := [
	[0, NodeKind.FIGHT, Reward.COUNT, 0],   # 0 — floor 1, fixed
	[1, NodeKind.FIGHT, Reward.COUNT, 1],   # 1 — floor 2 left
	[1, NodeKind.FIGHT, Reward.BEAK,  3],   # 2 — floor 2 right
	[2, NodeKind.FIGHT, Reward.BEAK,  4],   # 3 — floor 3 left
	[2, NodeKind.FIGHT, Reward.COUNT, 5],   # 4 — floor 3 right
	[3, NodeKind.CHEST, Reward.HEAL, -1],   # 5 — floor 4, no grid
	[4, NodeKind.BOSS,  Reward.NONE,  2],   # 6 — floor 5, the lion
]

## Directed, upward only. A run never walks down, so an edge is a permission and nothing else.
const MAP_EDGES := [[0,1],[0,2],[1,3],[1,4],[2,3],[2,4],[3,5],[4,5],[5,6]]
```

**Accessors** (every one casts, because a `const` Array loses element typing):
`map_node_count()` · `map_floor_of(n)` · `map_kind_of(n)` · `map_reward_of(n)` · `map_island_of(n)` ·
`map_floor_count()` · `map_edge_count()` · `map_edge_from(e)` / `map_edge_to(e)` ·
**`map_max_count_nodes_on_a_route()`** — the last one is walked over `MAP_EDGES` rather than written as
a literal 3, because `_min_region_floor()` and the roster capacity both ride on it and **a hand-written
3 beside a table that can grow is the second copy that rots.**

### 4.2 `src/sim/map.gd` — `class_name RunMap`, `extends RefCounted`

**Flat arrays. No `Node`, no `_draw`, no `Input`, no `get_node`, no `$`.** Constructible and drivable by
a net with `.new()` and nothing else.

```gdscript
## The route walked so far, in order, as node ids. THIS IS THE WHOLE OF THE STATE.
## ⚠ There is deliberately no `cleared` array and no `at` field: "where I am" is the last entry and
## "what I cleared" is membership, so the picture the view draws (travelled lines) and the sim's own
## progress are READ OFF THE SAME ARRAY and cannot diverge. A second array would be the same fact
## written twice, which is how a soldier ends up standing on a node the line does not reach.
var path := PackedInt32Array()
```

| Method | Returns | Contract |
|---|---|---|
| `at() -> int` | the last entry of `path`, or **-1** before the first node | -1 is "the run has landed nowhere yet", not an error |
| `is_cleared(n) -> bool` | `n in path` **and** `n != at()` | ⚠ **`at()` is not cleared** — the run is standing on it, and during `BATTLE` it has not been won. This is the one place the two states differ and it must not be folded |
| `is_reachable(n) -> bool` | `path.is_empty() and floor_of(n) == 0`, else **an edge `at() → n` exists** | ⚠ The empty case is not an edge case bolted on — floor 0 has no predecessor by construction |
| `reachable_nodes() -> PackedInt32Array` | every `n` with `is_reachable(n)` | The view draws from this; the shell hit-tests against it |
| `enter(n) -> bool` | false and **changes nothing** if `not is_reachable(n)` | Validating a click is the caller's job (`grid.load_rows` is the precedent) and a bark here would have to be forgiven by every net that pokes the map |
| `edge_is_travelled(e) -> bool` | both endpoints consecutive in `path`, in that direction | The 8px line. Derived, never stored |
| `is_finished() -> bool` | `at() >= 0 and Rules.map_kind_of(at()) == BOSS` | |
| `reset()` | `path.clear()` | Shared by `_init` and `Run.restart`, same reason `Run._reset` is |

### 4.3 `run.gd` — what moves

- `enum State { BATTLE, REWARD, WON, LOST }` → **`{ MAP, BATTLE, REWARD, WON, LOST }`**.
  ⚠ **`MAP` goes FIRST so it is 0 and a default-constructed int lands on the map**, not in a battle
  against an island nobody entered.
- `var map: RunMap = null`, built in `_reset` beside `army` — **the two places a run's state is built
  stay exactly two**.
- `_reset()` sets `_state = State.MAP` (not `BATTLE`) and `island_index = 0`.
- **`enter_node(n: int) -> bool`** — public, the map screen's one verb:
  1. refuse unless `_state == State.MAP` and `map.is_reachable(n)`
  2. `map.enter(n)`
  3. if `Rules.map_island_of(n) >= 0`: `island_index = that`, `_state = State.BATTLE`
  4. else (a chest): **apply `Rules.map_reward_of(n)` immediately and stay in `MAP`** — there is no
     fight to wait for, and a state that means "standing on a chest" would have exactly one frame of
     life and one caller
- `finish_island(won)` — unchanged except the reward lookup: `_pending = Rules.map_reward_of(map.at())`
  instead of `_reward_for_island(island_index)`. The `NONE` branch still calls `_advance()`.
- **`_advance()`** — `_state = State.WON` if `map.is_finished()`, else `_state = State.MAP`.
  ⚠ **It no longer touches `island_index`.**
- **`take_heal_reward()`** — public, mirrors `take_count_reward`'s shape: refuse unless
  `_pending == Reward.HEAL`, call `army.heal_all()`, clear `_pending`, `_advance()`.
  ⚠ It is public **only so that applying a reward and naming it are the same function in all three
  cases**, which is the reason `take_count_reward` is public today.

### 4.4 `army.gd` — one function

```gdscript
## Every LIVING soldier back to its type's maximum. Dead rows are not touched and are not resurrected:
## a row this file has never deleted is what makes permanent death structurally true, and healing one
## would undo that in the one place nothing is watching. The chest's whole cost model is that wounds
## come back and deaths do not.
func heal_all() -> void:
```

⚠ **It reads `Rules.hp_of(type_id[i])` rather than storing a max**, or the maximum lives in two files.

### 4.5 How a run advances and ends — **the whole state walk, once**

```
_ready            run == null                     → TITLE screen
시작하기          run = Run.new()                  → State.MAP, path empty, floor-1 node reachable
press node 0      run.enter_node(0)                → State.BATTLE, island_index 0, shell opens it
win               finish_island(true)              → reward COUNT applied → _advance → State.MAP
press node 2      enter_node(2)                    → State.BATTLE, island 3
win               finish_island(true)              → reward BEAK        → State.REWARD (panel)
pick a soldier    apply_beak(id)                   → _advance           → State.MAP
press node 5      enter_node(5)  (chest, island -1)→ heal applied inside enter_node, stays State.MAP
press node 6      enter_node(6)                    → State.BATTLE, island 2 (the lion)
win               finish_island(true)              → map.is_finished()  → State.WON (panel)
restart button    run = null; battle = null        → TITLE screen
lose anywhere     finish_island(false)             → State.LOST (panel) → restart → TITLE
```

⚠ **A loss does not clear `path`.** The panel is drawn over whatever was last on screen, exactly as
today, and `run = null` is what discards the map.

---

## 5. The shell — **three screens in one node**

### 5.1 `_ready()`

```gdscript
field_view = FieldView.new()
hud_view   = HudView.new()
map_view   = MapView.new()
title_view = TitleView.new()
panel_view = PanelView.new()
add_child(field_view); add_child(hud_view); add_child(map_view)
add_child(title_view); add_child(panel_view)
run = null
```

**Draw order is tree order for `Node2D` siblings**, so: field · hud · **map · title** · panel.
The panel stays last because it is the overlay over everything. Map and title never coexist (one needs
`run == null`, the other needs a `Run` in `MAP`), so their relative order decides nothing — it is fixed
anyway so nobody has to reason about it twice. **`get_child_count()` is 5.**

⚠ **`panel_view.bind()` is not called here.** `panel_view.run` stays null and `panel_active()` is false
for free. It is bound when the run is created.

### 5.2 `panel_active()` — **exactly what it becomes: nothing**

```gdscript
return run != null and (run.state() == Run.State.REWARD or is_finished())
```

**It is already an allowlist and it already answers correctly on both new screens:**

| Screen | `run` | `state()` | `panel_active()` |
|---|---|---|---|
| Title | **null** | — | **false** — the first clause |
| Map | a `Run` | `MAP` | **false** — `MAP` is in neither branch |
| Island | a `Run` | `BATTLE` | **false** |
| Beak pick | a `Run` | `REWARD` | true |
| Won / lost | a `Run` | `WON`/`LOST` | true |

⚠⚠ **Do not touch this function, and do not add `MAP` to it "for symmetry".** Its header records that
the denylist form (`state() != BATTLE`) broke five ways on one added state — **the allowlist is what
makes adding `MAP` free.** What the plan owes it is not an edit but a **check**: `net_shell` drives
`panel_active()` in all five rows above and asserts both directions.

### 5.3 `_unhandled_input` — the new top

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if run == null:
		_title_input(event)      # ⚠ the deleted `return` lived exactly here
		return
	if _hold_sec > 0.0:
		_panning = false
		_drag_soldier = -1
		field_view.set_drag(-1, -1)
		return
	if run.state() == Run.State.MAP:
		_map_input(event)
		return
	... the existing wheel / left-press / left-release / motion block, unchanged ...
```

⚠ **The hold guard stays BELOW the title branch and that is safe, measured against the code**: a hold
can only be armed by `_process` (which returns on `run == null`) or by `_click_panel` (which itself
returns early while a hold runs). The only path to `run == null` is the restart button inside
`_click_panel`, and `_hold_sec` is 0 there. **Write that reasoning into the comment**, because the next
reader will otherwise "fix" the order.

⚠ **The map branch sits above the `battle != null` block**, or a click on a node pans the camera on the
island still behind it (`_panning = true` is the current fall-through).

**`_title_input(event)`** — `InputEventMouseMotion` → `title_view.set_hover(pos)`;
`InputEventMouseButton` LEFT pressed → `title_view.slot_at(pos)`:
0 (시작하기) → `title_view.note_press(0)` then start a run · 1 (설정하기) → **`note_press` is NOT called**
and nothing happens, because the slot is not pressable and a press animation on it would be the picture
lying · 2 (종료) → `note_press(2)` then `get_tree().quit()`.

**`_map_input(event)`** — motion → `map_view.set_hover(pos)`; LEFT pressed →
`map_view.node_at(pos)`, and if `run.map.is_reachable(n)` then `map_view.note_press(n)` and
`_enter_node(n)`. ⚠ **The reachability test is asked of the SIM, not of the view** — the view's own
answer is drawn from the same call, so the picture can never offer a node the sim refuses.

⚠⚠ **Every net that presses a title slot or a map node drives `game._unhandled_input(ev)`**, the entry
point the OS uses — **not a title-specific helper.** Headless the window is 64×64 and
`root.push_input` divides by a 0.05 stretch, so a pushed click lands thousands of px away **and raises
no error**; a net that routes around that measures a path the player never takes.

### 5.4 `_start_run()` · `_enter_node()` · `_enter_map_screen()`

```gdscript
func _start_run() -> void:
	run = Run.new()
	_enter_map_screen()

func _enter_node(n: int) -> void:
	if not run.enter_node(n):
		return
	if run.state() == Run.State.BATTLE:
		_open_island()
	else:
		_enter_map_screen()      # a chest: the reward already landed inside enter_node

func _enter_map_screen() -> void:
	battle = null                # ⚠ the one lever that silences field_view AND hud_view at once
	_drag_soldier = -1
	_speed_slot = Rules.SPEED_SLOT_DEFAULT
	map_view.bind(run)
	panel_view.bind(run, null)
	hud_view.bind(null)
	field_view.setup(null, null, [])
```

⚠ **`field_view.setup(null, …)` and `hud_view.bind(null)` are belt-and-braces on top of `battle = null`,
and they are not redundant in the way that matters**: `field_view` holds its own `battle` reference and
would keep drawing the last island's terrain if only the shell's field were cleared. **Verify by
mutation**: comment out `battle = null` alone and the round must redden.

`_close_island()` becomes: `run.finish_island(won)`; then **if `run.state() == Run.State.MAP` →
`_enter_map_screen()`, else `_open_island()`** (which handles `REWARD`/`WON`/`LOST` exactly as today by
returning null from `begin_island` and leaving the last island drawable behind the panel).

`_release_hold()`'s beak branch: `run.apply_beak(...)` then **`_enter_map_screen()`**, not
`_open_island()`.

`_click_panel`'s restart branch: **`run = null; battle = null; panel_view.bind(null, null)`** — and
`run.restart()` is not called at all, because a fresh `Run` is built by 시작하기. ⚠ **`Run.restart()`
does not die** — `net_run` still drives it, and it is the only thing keeping `_reset` honest about
fields added to one path and not the other.

### 5.5 `project.godot`

**Unchanged.** `run/main_scene` stays `res://src/shell/game.tscn`; there is no `[input]` section and
none is added; **the keyboard still does nothing in this game.**

---

## 6. The screens — **every constant named, valued, floored and ceilinged**

⚠ **All of these go in `look.gd` and nowhere else**, and each carries its bounds in its own comment
beside it (this file's own convention). **Mouse only.**

### 6.1 Shared — the "it looks pressable" set

| Constant | Value | Floor | Ceiling |
|---|---|---|---|
| `PRESS_HIT_PAD_PX` | **8.0** | ≥ 4 — a slightly-off aim must still land | **≤ 11** — the title's slot pitch is `88 + 24 = 112`, so a hit height of `88 + 2p` must stay under 112 ⇒ `p < 12` |
| `PRESS_ALPHA_ON` | **1.0** | ≥ 0.9 | ≤ 1.0 |
| `PRESS_ALPHA_OFF` | **0.30** | ≥ 0.20 — below it a disabled thing is invisible rather than disabled | ≤ 0.45 — above it, it stops reading as disabled. The ratio is **3.3×**, and **the ratio is the rule**, not the absolute: the last failure's 0.18 failed for being indistinguishable from terrain |
| `PRESS_BORDER_WIDTH_PX` | **3.0** | ≥ 2.0 (this repo's snap floor) | ≤ 5 |
| `PRESS_HOVER_BORDER_WIDTH_PX` | **6.0** | **> `PRESS_BORDER_WIDTH_PX` + 2** or the change is under the snap floor and the hover is invisible | ≤ 10 |
| `PRESS_HOVER_BRIGHTEN` | **0.12** | ≥ 0.08 | ≤ 0.25 (above it the hover reads as a different colour, not the same thing lit) |
| `PRESS_HOVER_SEC` | **0.10** | **≥ 0.084** — five frames, this repo's floor. ⚠ **The design's first draft said 0.08 and claimed in the same file that every duration exceeds 0.084. Raised, not restated** | ≤ 0.20 or the hover lags the cursor |
| `PRESS_DOWN_SEC` | **0.10** | ≥ 0.084 | ≤ 0.15 (Swink's 100 ms input-to-response is the reason this is short) |
| `PRESS_DOWN_SCALE` | **0.96** | ≤ 0.98 — at a 360px slot, `0.98` is a 7.2px inset; **at 0.99 it is 3.6px and reads as a wobble** | ≥ 0.92 or the slot visibly shrinks |
| `PRESS_DOWN_DIM` | **0.15** | ≥ 0.10 | ≤ 0.30 |
| `SCENE_FADE_SEC` | **0.35** | ≥ 0.20 — under it the fade reads as a hard cut, which is the thing it exists to remove | ≤ 0.60 or the title feels slow to leave |
| `COL_SLOT_OFF` | `Color(0.42, 0.42, 0.44)` | — | the ONE new colour the title needs. **시작하기 reuses `COL_START`** (literally the same verb) and **종료 reuses `COL_BUTTON`** — `look.gd`'s own rule that one rectangle must not answer to two verbs is about the START/RESTART pair, and this is its other half: the same verb keeps the same tone |

### 6.2 The title

| Constant | Value | Both ends |
|---|---|---|
| `TITLE_TEXT_POS_PX` | `Vector2(400.0, 200.0)` | y ≥ 120 (the 72px glyph's own height above the baseline) · y ≤ 280 (or it collides with the slot block at 340) |
| `TITLE_FONT_SIZE_PX` | **72** | > `TITLE_SLOT_FONT_SIZE_PX` **+ 16** or the title stops being the loudest thing on its own screen · ≤ 96 |
| `TITLE_SLOT_ORIGIN_PX` | `Vector2(460.0, 340.0)` | x = `(1280 − 360) / 2` exactly · y ≥ 260 · **y ≤ 408** because `y + 3×88 + 2×24 ≤ 720` |
| `TITLE_SLOT_SIZE_PX` | `Vector2(360.0, 88.0)` | ≥ **(220, 64)** — the largest press in the game today, and **no new press is smaller** · ≤ (480, 120) |
| `TITLE_SLOT_GAP_PX` | **24.0** | ≥ 12 or two slots read as one bar · ≤ 44 (from the origin arithmetic above) |
| `TITLE_SLOT_FONT_SIZE_PX` | **40** | **> 30** = `HUD_TIMER_FONT_SIZE_PX`, today's largest glyph. ⚠ **The design's first draft said the largest was the start button's 28 and was wrong** · ≤ 56 or 「시작하기」 at ~0.6em per glyph overruns 360 |
| `TITLE_SLOT_TEXT_OFFSET_PX` | `Vector2(96.0, 58.0)` | **> (0, `TITLE_SLOT_FONT_SIZE_PX`)** — a glyph at the rect's own origin is a glyph that was never placed, and **that floor is the half proving the label exists at all** · `96 + ~200 = 296 ≤ 360` and `58 ≤ 88` |
| `TITLE_CELL_COUNT` | **9** | ≥ 5 or the background is not a drift, it is three dots · ≤ 16 or it competes with the slots |
| `TITLE_CELL_RADIUS_PX` | **14.0** | ≥ 8 · ≤ 24 |
| `TITLE_CELL_SPEED_PX` | **8.0** (px/s) | ≥ 3 — under it nothing visibly moves over a title's dwell · ≤ 20 or it reads as gameplay |
| `TITLE_CELL_ALPHA` | **0.14** | ≥ 0.06 or there is no background at all · ≤ 0.30 or it competes with `PRESS_ALPHA_OFF` 0.30 and a drifting cell reads as a disabled button |
| `TITLE_CELL_A_FREQ` · `TITLE_CELL_B_FREQ` | **0.13** · **0.19** | deterministic `sin`/`cos` of index and age — ⚠ **no RNG**, the same reason `SHAKE_A_FREQ` is a constant: a random drift cannot be measured. Coprime-ish so nine cells do not march in step |

**Pressable rects, in pixels**: 시작하기 `Rect2(460, 340, 360, 88)` · 설정하기 `Rect2(460, 452, 360, 88)`
· 종료 `Rect2(460, 564, 360, 88)`. **Hit rects are each grown by `PRESS_HIT_PAD_PX` on all four sides**
⇒ `(452, 332, 376, 104)`, `(452, 444, …)`, `(452, 556, …)`. `564 + 88 = 652 ≤ 720` ✓ and
`556 + 104 = 660 ≤ 720` ✓.

### 6.3 The map

**Node centres** — a `const` Array of `Vector2` in `look.gd`, indexed by node id:

```gdscript
const MAP_NODE_POS_PX := [
	Vector2(640.0, 620.0), Vector2(470.0, 500.0), Vector2(810.0, 500.0),
	Vector2(470.0, 380.0), Vector2(810.0, 380.0), Vector2(640.0, 250.0),
	Vector2(640.0, 110.0),
]
```

⚠ **If that does not parse** (a `const` Array of `Vector2` literals — `HUD_TIMER_POS_PX` proves a bare
`Vector2` literal is a const expression, and `BODY_RADIUS_RATIO` proves a const Array is, but the
combination is exactly the shape this repo has been bitten by twice), **fall back to
`const MAP_NODE_XY_PX := [640.0, 620.0, 470.0, …]` read in pairs by an accessor** and say so in the
comment. **Do not ask; take the fallback.**

| Constant | Value | Both ends |
|---|---|---|
| `MAP_NODE_R_PX` | **40.0** | ≥ 28 — below it a glyph inside the node draws at under 2px strokes · **≤ 52**, because `2 × 52 = 104` against a 120px vertical gap leaves 16px and two nodes read as touching |
| `MAP_BOSS_R_PX` | **56.0** | **> `MAP_NODE_R_PX`** or the boss is not the biggest thing on the map · ≤ 70, from `56 + 48 = 104 < 140` (the chest→boss gap) |
| `MAP_NODE_PAST_SCALE` | **0.86** | **> `MAP_NODE_LOCKED_SCALE` + 0.08** · ≤ 0.94, and `1 − 0.86 = 0.14` is 5.6px on a 40px radius, above the 2.0px snap floor |
| `MAP_NODE_LOCKED_SCALE` | **0.75** | ≥ 0.62 — below it the widest glyph (`1.08 × 21 = 22.7px`) no longer fits inside `40 × scale` · ≤ 0.86, or the size channel says nothing |
| `MAP_NODE_PAST_ALPHA` | **0.62** | ≥ 0.45, or a walked node is confused with a locked one · ≤ 0.85, or with a node on offer |
| `MAP_HERE_RING_R_PX` | **52.0** | **> `MAP_NODE_R_PX`** or the you-are-here ring hides inside the node it marks · **≤ 68**, from `68 + 48 = 116 < 120` |
| `MAP_HERE_RING_WIDTH_PX` | **6.0** | ≥ 4 — at 2px this ring is a hairline and the one thing on screen saying where you are stops carrying · ≤ 8, over which it swallows the node it points at |
| `MAP_BOSS_RING_WIDTH_PX` | **5.0** | ≥ 2.0 (snap floor) · ≤ `MAP_BOSS_RING_STEP_PX − 4`, or two neighbouring rings' strokes touch. ⚠ **Its own constant, not `MAP_HERE_RING_WIDTH_PX` reused** — they were one number, and thickening the here-ring silently thickened the boss |
| `MAP_RING_SEGMENTS` | **32** | ≥ 16, under which a 56px circle visibly has corners · ≤ 64, over which the outlines cost more than they show. ⚠ **And a multiple of 4**, so a vertex lands on each axis and a captured ring's half-extent equals its radius exactly |
| `MAP_LINE_PAST_WIDTH_PX` | **9.0** | **> `MAP_LINE_OPEN_WIDTH_PX` + 2** · ≤ 12. ⚠⚠ **It was 8.0, and `8 − 6 = 2` is the snap floor rather than more than it** — its sibling one line down carried the `+ 2` and it did not |
| `MAP_LINE_OPEN_WIDTH_PX` | **6.0** | **> `MAP_LINE_DIM_WIDTH_PX` + 2** (snap floor between them) · ≤ 8 |
| `MAP_LINE_DIM_WIDTH_PX` | **3.0** | ≥ 2.0 · ≤ 4 |
| `MAP_LINE_PAST_ALPHA` · `_OPEN_ALPHA` · `_DIM_ALPHA` | **1.0** · **0.9** · **0.25** | past ≥ open ≥ dim, and **open − dim ≥ 0.3** · dim ≥ 0.15 (or the unwalked map is invisible and "the whole map is always visible" dies) · dim ≤ 0.45 |
| `MAP_PULSE_SEC` | **0.9** | ≥ 0.5 or it flickers · ≤ 1.4 or it is not read as motion. ⚠ Xbox Accessibility Guideline 118 forbids flashing above ~3/s; this is 1.1/s |
| `MAP_PULSE_R_PX` | **4.0** | **≥ 2.0** — the snap floor, and **±4 on a 40px radius is 10%**, the smallest change that reads · ≤ 8 or a pulsing node overlaps its neighbour's hit circle |
| `MAP_NODE_FADE_SEC` | **0.18** | **≥ 0.084** (five frames) · ≤ 0.40 |
| `MAP_REVEAL_STEP_SEC` | **0.06** | ⚠⚠ **This one is deliberately BELOW the five-frame floor and it is not an oversight**: it is the offset BETWEEN beats, not a beat. Floor ≥ 0.03 (below it seven nodes appear in 0.21s and the direction is not taught) · ceiling ≤ 0.12 or the reveal is `0.12 × 5 = 0.60s` of waiting |
| `MAP_TRAVEL_SEC` | **0.45** | ≥ 0.25 or the ring teleports and the map's work is invisible · ≤ 0.70 or it is a wait |
| `MAP_CLEAR_FILL_SEC` | **0.25** | ≥ 0.084 · ≤ 0.50 |
| `MAP_HEAL_SEC` | **0.60** | ≥ 0.30 — the number has to be watched climbing, not just be different afterwards · ≤ 1.00 |
| `MAP_GLYPH_R_PX` | **21.0** | ⚠⚠ **RAISED 13 → 21 because 13 did not work** — the reward read as 「a few pixels of line art inside a 40px circle」. ≥ 12, from the COUNT glyph's own arithmetic (`2 × 0.28 × 12 = 6.7px` squares against a 3px stroke fill solid) · ≤ 26, from the widest glyph having to fit inside the SMALLEST drawn node, `40 × 0.75 = 30px` |
| `MAP_GLYPH_WIDTH_PX` | **3.0** | ≥ 2.0 · ≤ 5 — half of a COUNT square's 11.8px side, over which three squares read as three blobs |
| `MAP_GLYPH_PAST_ALPHA` | **0.80** | ⚠⚠ **NEW, and it exists because the ink was reusing the FILL's alpha.** ≥ 0.70, under which a walked node's reward drops below the 1.8 luminance ratio · ≤ 1.0. Deliberately above `MAP_NODE_PAST_ALPHA` 0.62: the node dims, the answer written on it does not |
| `MAP_GLYPH_LOCKED_ALPHA` | **0.75** | ⚠⚠ **NEW.** ≥ 0.65 (the same floor, against the dimmer LOCKED fill) · ≤ 1.0. **It must not be folded back into `PRESS_ALPHA_OFF`** — that sharing measured **1.31 : 1** on the shipped pixels, with six of seven nodes locked on the opening frame |
| `MAP_BOSS_RINGS` | **3** | = 3 exactly (the design's "three nested circles") |
| `MAP_BOSS_RING_STEP_PX` | **14.0** | ≥ 6 or three rings are one thick ring · ≤ 18, from `56 − 2×18 = 20 > 0`. ⚠⚠ **Its only coverage used to be `WIDTH ≤ STEP − 4`, which gets MORE true as STEP grows** — at 60 the two inner rings land at radius −4 and −64 |
| `MAP_ARMY_POS_PX` | `Vector2(24.0, 44.0)` | y ≥ `MAP_ARMY_FONT_SIZE_PX` (a baseline at 0 is off screen) · x + text width ≤ 470 − 48 = 422, clear of the leftmost node column |
| `MAP_ARMY_FONT_SIZE_PX` | **26** | **> `HUD_FONT_SIZE_PX` 22** — it is the only readout on this screen · ≤ 30 |
| `MAP_NODE_SIDES` | `[0, 4, 0]` indexed by `NodeKind` | 0 = circle, 4 = diamond. ⚠ **The kind → picture mapping is a TABLE, not a branch**, so adding the elite one day costs `rules.gd` + `look.gd` and no view edit |
| `COL_NODE_FIGHT` · `COL_NODE_CHEST` · `COL_NODE_BOSS` | three distinct tones | ⚠ **All three differ in shape AND colour AND size** — the Hexagarden critique of Slay the Spire's map is that its symbols differed in neither |

⚠⚠ **This table was RE-MEASURED against `look.gd` in full, not row by row as each was argued about.**
Four rows had rotted quietly while the build moved past them — `MAP_HERE_RING_WIDTH_PX` (4 → 6),
`MAP_GLYPH_R_PX` (13 → 21), `MAP_GLYPH_WIDTH_PX`'s ceiling (4 → 5) and `MAP_LINE_PAST_WIDTH_PX`
(8 → 9) — and five constants that exist in the tree had **no row at all**: the two state scales,
`MAP_NODE_PAST_ALPHA`, `MAP_BOSS_RING_WIDTH_PX` and `MAP_RING_SEGMENTS`. This repo's own sentence,
earned again: *re-measure the whole table, not the row someone is arguing about.*

**Hit radii, derived**: fight/chest `40 + 8 = 48` · boss `56 + 8 = 64`. **Nothing writes 48 or 64.**

**The non-overlap and on-screen arithmetic** is in the design doc's coordinate table and is not repeated
here. **The net row that enforces it asserts against the literals 1280 and 720**, never against the
layout's own extent.

### 6.4 `net_draw_leaf._table()` — the two new entries, in full

⚠ **The class is CLOSED: a `func` line the table does not hold is red.** Both tables open in the same
edit as the files.

```gdscript
"title_view.gd": {
	"slot_rect_of": 0, "slot_hit_rect_of": 0, "slot_at": 0, "is_slot_pressable": 0,
	"note_press": 0, "set_hover": 0, "_hover_of": 0, "_press_of": 0,
	"_slot_fill": 0, "_slot_box": 0, "_cell_centre": 0,
	"_fx_step": 0, "_process": 0, "_draw": 0,
	"_paint_cell": 1, "_paint_title": 1, "_paint_slot_box": 2, "_paint_slot_label": 1,
},                                                    # 18 funcs, 4 leaves
"map_view.gd": {
	"bind": 0, "node_at": 0, "node_centre_of": 0, "node_hit_radius_of": 0,
	"is_node_pressable": 0, "set_hover": 0, "note_press": 0, "note_cleared": 0,
	"_hover_of": 0, "_press_of": 0, "_reveal_alpha_of": 0, "_pulse_scale_of": 0,
	"_here_centre": 0, "_node_fill": 0, "_edge_style": 0, "_glyph_points": 0,
	"_fx_step": 0, "_process": 0, "_draw": 0,
	"_paint_edge": 1, "_paint_node": 2, "_paint_node_border": 1, "_paint_glyph": 1,
	"_paint_here_ring": 1, "_paint_army": 1,
},                                                    # 25 funcs, 6 leaves
```

- ⚠ **`_paint_node` is 2, not 1**, and that is not a mistake: it holds `draw_circle(...)` in one branch
  and `draw_colored_polygon(...)` in the other, and `_draw_calls` counts **call sites textually**. One
  runs per call. **Writing 1 here reddens the round on day one.**
- ⚠ **`_glyph_points` is 0 and is called FROM `_draw()`**, handing its `PackedVector2Array` to
  `_paint_glyph` as an argument — the `_spark_points` precedent. **Built inside the leaf it never
  leaves it, and the unused-argument check skips every function whose count is 0**, so a leaf holding
  `draw_polyline(PackedVector2Array(), …)` would read as *1 draw call, all arguments used* with nothing
  on screen. **`net_map` therefore asserts the array handed to `_paint_glyph` is non-empty.**
- **Totals**: `total_funcs` **77 + 18 + 25 = 120** · `total_leaves` **21 + 4 + 6 = 31** ·
  `view_files.size()` **5** · `table.size()` **5** · `wide_scanned` **6**.
  ⚠ **Re-derive these by hand at the halt.** A literal that does not move is the one nobody re-derives —
  `plan-then-watch` recorded a draft that landed both totals back on their old values while five
  per-file counts had moved.

---

## 7. Presentation — **shipping this round, step 6**

| When | What moves | The rule it says fired |
|---|---|---|
| Hover on a title slot | border 3 → 6px, +0.12 brightness, over **0.10s** | ⚠ **The only picture that says "this presses."** No hover reads as "does not press", not as "no effect" |
| Press a slot / a node | **0.10s** squash to 0.96×, −0.15 brightness | The press was accepted |
| 시작하기 → map | the screen dims and returns over **0.35s** | The scene changed. A hard cut reads as a glitch |
| The map appearing | nodes fade in **floor by floor, 0.06s apart**, each over 0.18s (`0.06 × 4 + 0.18 = 0.42s`) | **Teaches the map's direction, bottom to top.** This is what replaces an explanatory sentence |
| A reachable node | 0.9s pulse, radius ±4px | On a still screen it is the only motion saying "here" |
| Choosing a node | the you-are-here ring travels **along the edge over 0.45s**, then the island opens | ⚠ **Cut straight to the island and the map's work is invisible.** The travel IS the progress readout |
| Returning from a win | cleared node fills over **0.25s** → the travelled line thickens → the next floor brightens. **In that order** | Progress accumulates on screen; this is why there are no floor numbers |
| ⚠ **Pressing the chest** | the 「힘」 number top-left **climbs over 0.60s** | ⚠⚠ **The chest is the only node this round that changes state without a fight.** Without the climb, pressing it and not pressing it look identical on screen |
| The two numbers | 「병사 %d · 힘 %.0f」 fade in with the map | **The only data on screen that can answer "what am I short of"** — `hud_view._draw` returns on `battle == null` and draws nothing here |
| Boss won / run lost | the existing panel, and from there back to the title | §5.4's restart branch |

⚠⚠ **Every one of these gets a FLOOR as well as a ceiling in its net row.** The presentation round found
four items at once bounded only above — *"the lunge never overlaps more than 6px"* with nothing saying
*"the lunge is not always zero"* — so **deleting the whole animation stayed green.**

---

## 8. Nets — **fourteen, and every check names its mutation**

**The wrapper refuses a round under five nets.** Two are new; the round goes 12 → 14.

### 8.1 `net_map` — NEW (sim half in step 1, view half in step 3)

| Korean label | Floor | Ceiling | The mutation that reddens it |
|---|---|---|---|
| 「지도는 일곱 칸이고 변은 아홉이다」 | `map_node_count() == 7` | `map_edge_count() == 9` | drop a row from `MAP_NODES` |
| 「층은 다섯이고, 층마다 칸 수가 1·2·2·1·1이다」 | each ≥ 1 | floor 5 has ≤ 1 | move a node to another floor |
| 「모든 변은 한 층만 올라간다」 | every edge's `to` floor = `from` floor + 1 | — | add `[0,3]` to `MAP_EDGES` |
| ⚠ 「두 칸이 같은 격자를 안 쓴다」 (step 5) | island ids of nodes with `island >= 0` are all distinct | count == 6 | point two nodes at island 0 |
| 「경로가 넷이다」 | ≥ 4 (walk every path from floor 0 to the boss) | ≤ 4 | delete edge `[1,4]` ⇒ 3 |
| ⚠ 「어느 경로도 부리 칸을 하나 이상 지난다」 | min over routes ≥ 1 | — | set node 2's reward to `COUNT` |
| ⚠ 「한 경로가 지나는 세포 칸은 최대 셋이다」 | max over routes ≥ 3 (**the floor is the half proving the fork exists**) | ≤ 3 | set node 3's reward to `COUNT` ⇒ 4 |
| 「`map_max_count_nodes_on_a_route()` 가 그 최대와 같다」 | — | — | hardcode it to 1 — **and `net_islands`'s region floor must move with it** |
| 「런을 시작하면 1층 칸 하나만 갈 수 있다」 | exactly 1 reachable | not 2 | make `is_reachable` return true for every floor-0 node |
| 「1층을 밟으면 2층 두 칸이 다 열린다」 | 2 | 2 | drop the second edge out of node 0 |
| 「2층 어느 칸에서도 3층 두 칸에 다 닿는다」 | 2 from node 1 **and** 2 from node 2 | — | delete `[2,4]` — **the rejoin is what stops one bad turn locking the map** |
| 「닿을 수 없는 칸은 `enter` 가 거절하고 아무것도 안 바꾼다」 | `path` unchanged | returns false | let `enter` append unconditionally |
| 「서 있는 칸은 아직 깬 칸이 아니다」 | `is_cleared(at()) == false` | — | fold `is_cleared` into plain membership |
| 「상자 칸은 섬을 안 열고 그 자리에서 회복한다」 | pool rises | state stays `MAP` | give the chest an island index |
| 「회복은 살아 있는 줄만 만피로 만든다」 | a wounded living soldier reaches max | **a dead row stays 0 HP and stays dead** | make `heal_all` skip the `alive` test |
| ⚠ 「회복이 안 다쳤을 때의 풀을 못 넘는다」 | — | pool == sum of living max HP | make `heal_all` add instead of set |
| **(view)** 「칸 일곱의 판정 원이 전부 `Rect2(0,0,1280,720)` 안이다」 | — | asserted against **literal** 1280 · 720 | move node 6 to y 40 |
| **(view)** 「어느 두 칸의 판정도 안 겹친다」 | min centre distance ≥ 120 | — | move node 3 to (470, 460) |
| **(view)** 「`_paint_glyph` 가 받은 점이 비어 있지 않다」 | ≥ 3 points | ≤ 24 | return an empty array from `_glyph_points` |
| **(view)** 「갈 수 있는 칸과 못 가는 칸의 알파가 3배 넘게 다르다」 | ratio ≥ 3.0 | — | set `PRESS_ALPHA_OFF` to 0.9 |
| **(view)** 「맥동이 0이 아니고 4px을 안 넘는다」 | max radius delta **> 0** | ≤ `MAP_PULSE_R_PX` | multiply the pulse by 0.0 — ⚠ **the floor is the half that proves the beat exists** |
| **(view)** 「고리가 0.45초 동안 선을 따라 실제로 이동한다」 | ≥ 3 distinct positions sampled | endpoints match the two node centres | freeze `_here_centre` at the source |

### 8.2 `net_title` — NEW (step 3)

| Korean label | Floor | Ceiling | Mutation |
|---|---|---|---|
| 「칸 셋의 사각형이 겹치지 않고 화면 안에 있다」 | all inside `Rect2(0,0,1280,720)` (**literal**) | no two hit rects intersect | `TITLE_SLOT_GAP_PX` → 0 |
| 「판정 사각형이 그림보다 사방 8px 크다」 | hit ⊇ drawn | hit area ≤ drawn area × 1.6 | make the hit rect the drawn rect |
| 「가장 작은 누름이 220×64보다 작지 않다」 | 360 ≥ 220 **and** 88 ≥ 64 | — | shrink `TITLE_SLOT_SIZE_PX` |
| 「칸의 글자가 30px보다 크다」 | `TITLE_SLOT_FONT_SIZE_PX > HUD_TIMER_FONT_SIZE_PX` | ≤ 56 | set it to 28 |
| 「제목 글자가 칸 글자보다 16px 이상 크다」 | ≥ 40 + 16 | ≤ 96 | set `TITLE_FONT_SIZE_PX` to 44 |
| 「글자가 칸 원점에 안 찍힌다」 | offset.x > 0 **and** offset.y ≥ font size | inside the rect | zero `TITLE_SLOT_TEXT_OFFSET_PX` |
| ⚠ 「설정하기는 안 눌린다고 그려진다」 | its alpha ≤ 0.30 **and** it has no border | — | give it `PRESS_ALPHA_ON` |
| ⚠ 「설정하기는 호버해도 안 변한다」 | hover delta == 0 | — | let `set_hover` match every slot |
| 「호버하면 테두리가 3에서 6으로 간다」 | delta ≥ 2.0 (snap floor) | ≤ 10 | make hover a no-op |
| 「누르면 0.96배로 눌리고 0.10초 뒤 돌아온다」 | scale < 1.0 at t=0.05 | scale == 1.0 at t=0.11 | make `note_press` a no-op |
| ⚠ 「배경 세포가 실제로 움직이고 화면을 안 벗어난다」 | position at t=2.0 differs by **≥ 2.0px** from t=0 | every centre inside the viewport | zero `TITLE_CELL_SPEED_PX` |
| 「배경 세포가 난수를 안 쓴다」 | two `TitleView`s at the same age agree exactly | — | seed it from `randf()` |
| 「배경 알파가 못 누르는 칸보다 어둡다」 | `TITLE_CELL_ALPHA < PRESS_ALPHA_OFF` | ≥ 0.06 | raise it to 0.4 |

### 8.3 `net_run` — rewritten (step 1)

| Was | Becomes | Why |
|---|---|---|
| 「런은 첫 섬에서 시작한다」 | 「런은 지도에서 시작하고 밟은 칸이 없다」 — `state() == MAP` **and** `map.path.is_empty()` | The run no longer starts on an island |
| 「시작 상태는 전투다」 | 「시작 상태는 지도다」 | |
| 「첫 섬을 이기면 곧장 둘째 섬이다 — 수 보상은 고를 것이 없다」 | 「수 보상은 그 자리에서 붙고 런은 **지도로** 돌아간다」 — `state() == MAP`, `army` grew by 3 | ⚠⚠ **The floor as well**: 「`finish_island(true)` 는 `island_index` 를 혼자 안 옮긴다」 — mutation: put `island_index += 1` back into `_advance` |
| 「고르는 동안 섬 번호는 둘째 섬에 머문다」 | 「부리를 고르는 동안 서 있는 칸이 안 바뀐다」 — `map.at()` is stable | The index is no longer the position |
| 「셋째 섬이다」 | 「부리를 달고 나면 지도로 돌아간다」 | |
| 「이겨도 없는 넷째 섬으로 넘어가지 않는다」 | 「보스 칸을 이기면 `WON` 이고 지도로 안 돌아간다」 | |
| 「첫 섬으로 돌아간다」 (restart) | 「재시작하면 지도가 비고 상태가 `MAP` 이다」 — `map.path.is_empty()` | |
| 「부리는 슬라이스 전체에 하나뿐이다」 | 「한 칸은 부리를 한 번만 낸다」 — a second `apply_beak` on the same node changes nothing | **A route can hold two beak nodes now** |
| — (new) | 「상자 칸은 회복을 주고 `MAP` 에 머문다」 | |
| — (new) | 「경로가 다르면 명부가 다르다」 — walk cells-cells vs cells-beak-beak and assert **different living counts AND different beak counts** | ⚠ **This is the row that measures whether the fork does anything at all**, and it is a floor, not a ceiling |

**Everything about HP carrying across islands, dead rows staying dead, and `restart` building a new
`Army` stays exactly as written.** Those checks were never about the walk.

### 8.4 `net_shell` — rewritten (step 4)

| Korean label | Floor | Ceiling | Mutation |
|---|---|---|---|
| 「`_ready` 는 런을 안 만든다 — 켜면 타이틀이다」 | `run == null` | `battle == null` | put `Run.new()` back in `_ready` |
| 「`_ready` 가 자식 **다섯**을 만들었다」 | 5 | 5 | drop one `add_child` |
| 「자식 순서가 field → hud → map → title → panel 이다」 | by identity | | swap map and panel |
| ⚠⚠ 「`run == null` 일 때 `_unhandled_input` 이 시작하기 클릭을 받는다」 | after the call `run != null` | | ⚠ **put `if run == null: return` back** — this is THE mutation this net exists for |
| 「시작하기는 섬이 아니라 지도를 연다」 | `state() == MAP` | `battle == null` | call `_open_island()` from `_start_run` |
| 「종료 칸은 트리를 닫으라고 부른다」 | a spy sees exactly 1 quit | ≤ 1 | wire 종료 to `_start_run` |
| 「설정하기 칸은 아무것도 안 한다」 | `run` still null | no quit | make slot 1 pressable |
| 「지도에서 칸을 누르면 섬이 열린다」 | `battle != null` | `state() == BATTLE` | ignore the press |
| ⚠⚠ 「지도로 돌아가면 `battle` 이 null 이 된다」 | `game.battle == null` | **and `field_view.battle == null`** | delete the `battle = null` line — ⚠ **without this the last island keeps drawing, panning, and its clock and start button come with it** |
| 「지도에서 누른 클릭이 카메라를 안 움직인다」 | `_panning == false` after a node press | | move the map branch below the `battle != null` block |
| 「지도에서는 패널이 안 뜬다」 | `panel_active() == false` in `MAP` **and** with `run == null` | **true in `REWARD` and in `WON`** | ⚠ both directions, or an allowlist that always returns false passes |
| 「보스를 이기고 다시 하기를 누르면 타이틀이다」 | `run == null` | `battle == null` | call `run.restart()` instead |
| 「타이틀에서는 섬이 안 그려진다」 | `field_view.battle == null` and `hud_view.battle == null` | | drop `battle = null` from the restart branch |
| 「부리를 달고 나면 섬이 아니라 지도로 간다」 | `state() == MAP` | `battle == null` | leave `_open_island()` in `_release_hold` |

⚠ **Every press in this net is built as an `InputEventMouseButton` with `position` set and handed to
`game._unhandled_input(ev)`.** Not `root.push_input` (the 64×64 headless window's 0.05 stretch sends a
click thousands of px away, silently) and **not a title-specific helper** (which measures a path the
player never takes).

### 8.5 `net_islands` — rewritten (step 5)

- The fifteen per-island tables become the **invariant table in the design doc**, every row with a
  literal floor **and** a literal ceiling.
- ⚠ **`EXPECT_SPAWNS` does not simply vanish**: it becomes `enemies >= 6` and `enemies <= 20`.
  **Without that row an island with one enemy (won at frame 1) or forty ships green**, and "cheap to
  add" becomes "cheap to add wrong" — worse than today, because the person adding them is the user.
- ⚠ **`EXPECT_STRICT_UNREACHED` `[0, 63, 0]` cannot be expressed as a literal bound and is DROPPED.**
  What survives is `strict_with_no_nearer_blocker == 0`, which is already an invariant and is already
  the property that made those 63 benign. **Say so in the file: the strict walker's exact count is no
  longer pinned.**
- **`EXPECT_FINGERPRINT`** — one `int` per island, `"\n".join(rows).hash()`. ⚠ **The net PRINTS the
  computed value in its failure label**, so adding an island is paste-back and not measurement.
  ⚠ **It says only "the rows did not change"**, never that the derived properties still hold.
- `_min_region_floor()` → 20, **and its literal self-check moves to 20 in the same edit.**
- `t.eq(Islands.count(), 3, …)` → 「섬 수와 `TIME_LIMITS` 길이가 같다」 **and** 「섬을 여는 칸 수와 섬 수가
  같다」 — the second is what makes an island attached to no node a red round rather than dead content.
- **Self-check rows stay**: the shape scanner, the legend scanner, the cut fixture, the sealed-wall
  fixture. ⚠ **A scanner that never matches reads exactly like a clean tree.**

### 8.6 The rest

| Net | What moves |
|---|---|
| `net_draw_leaf` | the five totals and the two new per-function tables (§6.4). ⚠ **The scanner's own synthetic cases are untouched** — they fail the scanner, not the tree |
| `net_battle` `net_boat` `net_plan` `net_coast` `net_camera` `net_fx` `net_fx_view` | ✅ **untouched.** If any of them reddens, the cause is a real regression, not this round's edit — **do not adjust them to fit** |
| `net_citations` | ⚠ it reads `docs/` and `CLAUDE.md` too. **The design twins now cite `first-slice` by bare name** (a pathed link into the plans folder was there and is gone), and nothing in this round adds a path or a line number |

---

## 9. Acceptance — **from the design doc, marked by who can close it**

| Row | Closed by |
|---|---|
| ⚠⚠ **It is operable without explanation** — someone who has never had this game explained launches it, is told nothing, starts a run, picks a node. Who they were and where they stalled goes into the design doc | **USER ONLY.** ⚠ Not a net, not a screenshot, not an agent clicking. **Last round failed this row the moment it met a human** |
| **What presses is readable as a picture** — show the screen 5s, have them point at everything pressable; pointing at something unpressable is a failure | **USER ONLY** |
| ⚠⚠ **What a node IS is readable** — they point at "the node with no fight" and "the node the run ends on" | **USER ONLY.** ⚠ "they differ in shape, colour and size" does not pass this — that is differentiation, not identification |
| **The fork has a reason behind it** — the user takes the same map twice by different routes and says why | **USER ONLY**, with **PROBE** as the proxy (§10) |
| **The map shows progress** — from the screen alone they say where they have been and how much is left | **USER ONLY** |
| ⚠⚠ **Adding an island is cheap** — the user adds one themselves and **it shows up in a run**, unassisted | **USER ONLY.** ⚠ "we replaced the tables with invariants" does not pass it. ⚠ **And it is only passable because the cost is four edits including the node row** — at three, the island is attached to nothing and cannot appear |
| **The title is not friction** — count presses from launch to the first island: today 0, by this design **2** (시작하기, then one node). **More than three is a failure** | **NET** — `net_shell` counts the calls |
| **The glyph count did not grow** — count the glyphs per screen and write the number down | **NET** for the count, **USER** for the verdict. Title: 3 slot labels + 1 title = 4 items. Map: **2 numbers, 0 sentences** |
| **Every hit target is on screen** — all seven hit circles and both rings inside `Rect2(0,0,1280,720)`, against the literals | **NET** (`net_map`) |
| **The map is a decision, conditionally** — the three new grids cost as much as the shipped three | **PROBE**, re-run after step 5 |
| **⚠ Final verdict** — the user does not say 「애매하다」 again (GDD undecided 18) | **USER ONLY.** **Every row above is a proxy** |

---

## 10. The probe — **step 7, and what it buys**

`tools/probe/run_run.gd` walks `island_index` today. It becomes **a route chooser**: a policy is now a
*(route, landing plan)* pair, and the probe prints, per route, the pool entering each node, soldiers
lost, and whether the run cleared.

**What that buys, and it is the reason the rewrite is not optional:**

1. ⚠⚠ **Without it the probe hangs.** With `MAP` in the enum, its `while state() == BATTLE` shape sits
   on the map forever and **prints nothing at all** — the failure that once disarmed a whole net here.
2. **It re-measures the HP schedule against the three new grids.** The design's table uses island 2's
   41 as the model for a middle island; **only the probe can replace that with a measurement.**
3. **It answers the fork question as a number**: do the four routes produce different outcomes, or does
   one dominate? ⚠ **The forum hypothesis is recorded and untested** — *"always take the path with the
   most rest sites"* ⇒ **a map that collapses into a constant**, which is the sentence that killed this
   repo's second game.

⚠⚠ **The probe must not grade itself.** It reads `TIME_LIMITS`, `MAP_NODES` and every rule constant as
they stand; **it never tunes one to make its own run look better.** Its existing inversion — a run that
MUST be reported as a loss (one soldier, one HP) — stays, and **one more is added: a route the map
forbids must be refused, not walked.**

**And in the same step**: `src/sim/islands.gd`'s `TIME_LIMITS` ⚠⚠ comment, which still says *"15 wins
out of 15, worst plan at 49%"*. **Re-measured 2026-08-18: two of five policies lose the run and the
baseline worst is 61.8%.** Replace the numbers; **keep the sentence that lowering the limits cannot make
the landing point a decision**, which is unaffected.

---

## 11. Structure — **the questions this repo's own gate asks**

**Is this a variant or a new kind?** ⇒ **A new kind, and here is why the existing structure cannot hold
it**: `Run` today has no representation of *where you are* other than an integer that only ever counts
up. A branching route is not a bigger integer — it is an ordered set with a predecessor relation, and
`island_index + 1` cannot express "either of two". **That is the sentence; if it could not be written,
this would be a variant and `RunMap` would not exist.**

**How many files change to add one new ISLAND?** `islands.gd` (rows + limit) · `rules.gd` (one node
row) · `net_islands` (one fingerprint). ⇒ **Three files.** At the limit, and that is deliberate — the
user does this alone and repeatedly.

**How many to add one new NODE KIND** (the elite, one day)? `rules.gd` (enum + table row) · `look.gd`
(a colour and a `MAP_NODE_SIDES` entry). ⇒ **Two files, because the kind → picture mapping is a table
and not a branch in `map_view`.** ⚠ **Build it that way even though no elite ships this round** — the
branch version costs a view edit forever after.

**If an axis is added, does every consumer follow?** The axis added here is *the reward a node pays*.
Its consumers: `run.gd` (applies it) · `map_view` (draws its glyph) · `net_map` (bounds it per route) ·
`net_run` (walks two routes and asserts different rosters) · the probe (reports it). ⚠ **`map_view` is
the one that would be forgotten** — a reward that changes in the sim while the node on screen looks
identical is, as far as the user is concerned, nothing happening.

---

## What the build was attacked with

Two adversarial verifiers went at the finished, green build (1816 checks at the time). **Fifteen
findings, and not one was refuted** — every mutation below was reproduced, and every fix was
re-verified by re-running the same mutation and watching it redden. The round afterwards is **14 nets ·
1870 checks · green**, and **1933 after the second pass below**.

⚠ **Every one of these was a fake green, not a broken feature.** The picture on screen was correct in
each case; what was missing was the check that would notice if it stopped being correct. That is the
whole of this repo's 「No fake nets」 list, earned again on two new screens in one round.

| # | What was claimed | What the mutation proved | Disposition |
|---|---|---|---|
| 1 | *the map answers the cursor — a reachable node lights and its border thickens* | a bare `return` at the top of `MapView.set_hover` — **`set_hover` was called by no net at all**, so `_hover_node` was never anything but -1 | **Fixed.** `net_map` drives the hover on the spy and reads the widened border AND the risen luminance back off the picture, plus the -1 cases (unreachable node, empty space, cursor leaving). `net_shell` drives it through `_unhandled_input` |
| 2 | *pressing a node starts the ring walking the edge* | `map_view.note_press(n)` deleted from the shell — `_pending_node` and `_hold_sec` on the next two lines run unconditionally, so a press became **0.45 s of a frozen screen** and then the island | **Fixed.** `net_shell` asserts `_travel_to` / `_travel_from` / `_press_node` after the press, and half-steps the view's own clock to prove the ring is between the two nodes |
| 3 | *pressing 시작하기 or 종료 dips the slot* | `title_view.note_press(slot)` deleted — only the NEGATIVE claim (설정하기 does not press) was asserted | **Fixed.** `net_shell` asserts `_press_slot` and `_press_of` on both live slots, the positive twin of the row already there |
| 4 | *three line weights say three things* | `MAP_LINE_PAST_ALPHA` → 0 (the travelled route invisible) and `MAP_LINE_OPEN_ALPHA` → 0, both green. Only the DIM sibling had bounds | **Fixed.** Both ends on all three alphas, a 0.3 separation row, and the alpha that reaches `_paint_edge` is read off the capture rather than off the constant |
| 5 | *the glyph says what a node PAYS* | two holes: `MAP_GLYPH_R_PX` → 0 collapsed all six glyphs to a point, and the 「2층 두 칸의 무늬가 다르다」 row compared **absolute** point arrays, which differ by a constant translation whatever shape is drawn — the beak branch was replaced with a copy of the cells branch and the round stayed green | **Fixed.** The radius is bounded at both ends; every glyph must reach ≥ 6 px from its own node centre; and the comparison recentres each glyph on its node first. ⚠ **The instrument carries its own inversion**: nodes 1 and 4 pay the same reward at different centres and are asserted EQUAL, so a positional comparison reddens that row |
| 6 | *the 「병사 · 힘」 readout lands where `look.gd` puts it* | `MAP_ARMY_POS_PX` → (-900, -900), the screen's only text drawn off screen, green — the check read its expectation out of the constant it was checking | **Fixed.** Pinned against `net_map`'s literal `SCREEN`, plus the baseline and the left-column clearance the constant's own comment states |
| 7 | *a node's SIZE is one of the three axes* | `MAP_NODE_R_PX` → 4, green — every row about it was a `>` relation that gets MORE true as it shrinks | **Fixed.** Floor and ceiling from the constant's own comment, and every kind's hit circle must be ≥ 64 px across — the same literal `net_title` pins for the title's smallest pressable box |
| 8 | *the node just won fills in* | `note_cleared` made a no-op, green — `MAP_CLEAR_FILL_SEC` was only ever a duration to step PAST, and after the fill lands the colour is identical either way | **Fixed.** Read MID-RAMP: start (dim), half (strictly between), done (`PRESS_ALPHA_ON`), in one row |
| 9 | *reachability is asked of the sim, so an offer is never refused* | the guard's `is_reachable` clause removed, green — the two lines under it run unconditionally, so a dim node armed a hold that swallowed every input and then did nothing | **Fixed.** `net_shell` presses the boss from node 0 and asserts `_pending_node`, `_hold_sec` and `_travel_to` all stay at rest |
| 10 | *the probe re-measures the HP schedule* | **`tools/probe/run_run.gd` was DEAD.** A `Run` now starts in `State.MAP`; the driver handled only `BATTLE` and `REWARD`, fell into `else: break` on its first iteration, and every policy played **zero islands with exit code 0** | **Fixed and re-measured.** The driver takes a ROUTE; `_state_name` learned `MAP`; the two callers that opened an island on a fresh `Run` now enter node 0 first. A new section walks **both branches** and prints them side by side. The design's probe box is rewritten with the real table |
| 11 | *the docs say what was built* | five places said **nothing is built** while 1816 checks were green — both design twins' `Implemented`, the plan's `Status`, `plans/README.md`, `design/README.md` and `CLAUDE.md`'s doc table | **Fixed in one pass**, and `Accepted` was left alone: **no user verdict has been heard** |
| 12 | *the fork's two nodes are told apart on screen* | same as 5 — the row could never fail | **Fixed** (see 5). Floor 3's pair, which nothing compared at all, is now compared too |
| 13 | *`net_islands`'s landing-region floor tracks the roster* | `_min_region_floor()` counted ONE reward application (14) while `map_max_count_nodes_on_a_route()` is 3 (19 + 1 = 20). `look.gd` got the plan's fix; its sibling did not | **Fixed.** The floor reads the accessor, the self-check is the literal 20, and a second row pins the 19 against `look.gd`'s roster capacity |
| 14 | *three grids are hand-authored this round* | **step 5 was never done** and no doc said so. `MAP_NODES`'s island column is the step-1 temporary; island 1 serves nodes 0 and 3, island 2 serves nodes 2, 4 and the boss | **Descoped, in writing.** The plan's `Status` names everything still owed, and the design twins, both READMEs and `CLAUDE.md` carry it. ⚠ **The probe measured the cost**: node 2 opens the LION grid, so the beak branch loses the run on its second fight |
| 15 | *every route passes at least one beak node* | **false on this map, in BOTH twins** — `[0, 1, 4, 5, 6]` passes three cell nodes and zero beak nodes, which is the same route the 19-soldier roster arithmetic is derived from. The nets already encoded the truth and said so | **Fixed in both twins in one edit.** A route passes 0–2 beak nodes; a beakless route IS the cost of the cells branch. ⚠ **Whether that is acceptable is a `MAP_NODES` question, not a wording one, and it is left open** |

### ⚠⚠ The second pass — **six more, and every one is "computed, handed on, and invisible"**

**The first pass closed fifteen findings and the round went to 1911 checks. A second verifier then
found six more, all of them in the same seam.** Every mutation below was reproduced green at 1911 and
is red now; the round afterwards is **14 nets · 1933 checks · green**.

| # | What was claimed | What the mutation proved | Disposition |
|---|---|---|---|
| 16 | ⚠⚠ *the you-are-here ring answers 「지금 내가 어디 있나」* — **the user's own fourth clause** | `mark.a = Look.PRESS_ALPHA_ON * 0.0` — the ring drawn fully transparent, **1911 green**. The spy captured `col` and `width` and **no row read either**; `MAP_HERE_RING_WIDTH_PX >= 4.0` was asserted of the CONSTANT and never of what reached the leaf | **Fixed.** The captured alpha, the captured width, and a luminance ratio against the node the ring wraps. HERE and OPEN share a hue AND a radius, so this ring is the only channel separating them |
| 17 | *a reachable node is bordered, at rest* | `edge.a = reveal * 0.0` — **the round's headline fix drawn invisible, 1911 green.** The border was pinned by COUNT and by CENTRE; `borders[i]["col"]` was read by no row | **Fixed.** Captured alpha ≥ 0.8 plus a luminance gap against the fill it sits on, so a border drawn in the node's own tone reddens as well |
| 18 | *the glyph says what a node PAYS* | `ink.a = … * 0.0` — all six glyphs invisible, **1911 green**. ⚠⚠ **And the SHIPPED value was already most of the way there**: the ink reused `PRESS_ALPHA_OFF` 0.30 against a fill also at 0.30, measured at **1.31 : 1** on real pixels, with six of seven nodes LOCKED on the opening frame | **Fixed on both sides.** The ink got its own two constants (`MAP_GLYPH_PAST_ALPHA` · `MAP_GLYPH_LOCKED_ALPHA`), and the net computes a luminance ratio **off the captured colours** with a floor of 1.8. ⚠ The shipped 0.30 measures 1.25 under that row — **the check bit the tree, not only the mutation** |
| 19 | *the chest is a diamond and a fork node is bordered* | `_ring_points(centre, radius * 0.0, …)` — every polygon and polyline collapsed to a single point, **1911 green.** `draw_circle` survived because its radius argument is asserted; `_ring_centre` could not see it because **a bounding box of zero extent still returns the right centre** | **Fixed.** A sibling `_ring_extent` compares the captured half-extent to the radius the same capture carries, for all seven nodes and both fork borders |
| 20 | *three line weights say three things* | `MAP_LINE_PAST_WIDTH_PX 8.0 → 6.1`, **1911 green.** The row bounding 「the tightest two」 **named a pair, and named the wrong one** — OPEN↔DIM is 3.0 apart while PAST↔OPEN was exactly 2.0 with only a bare `>`. And `look.gd`'s own header said *more than the snap floor*, which 8.0 did not satisfy | **Fixed both ways.** The row takes the minimum over the whole ladder with a floor above 2.0, the alpha ladder got its ordering row, and the constant moved to 9.0 so the sentence above it is true |
| 21 | *the boss's rings are cut out of the boss* | `MAP_BOSS_RING_STEP_PX 14 → 60`, **1911 green** — the two inner rings at radius −4 and −64, a 64px ring painted in the backdrop tone OUTSIDE the disc. Its only coverage was `WIDTH ≤ STEP − 4`, **which gets more true as STEP grows** — the same shape already flagged for `MAP_NODE_R_PX` and applied to that sibling only | **Fixed.** Bounded 6–18, plus the drawn radii read back off the capture as strictly decreasing and strictly positive |

⇒ **Four of the seven leaves were capturing a `Color` that no row inspected** — border, glyph,
here-ring and the army readout. All four are read now. **Capturing an argument proves it was computed
and handed on; it never proves anything could see it.**

⚠ **The sweep that came out of finding 21 re-bounded five constants** whose only protection was a `>`
or `≤` against another constant: `MAP_BOSS_R_PX`'s ceiling, `MAP_HERE_RING_R_PX`'s ceiling,
`MAP_BOSS_RING_STEP_PX`, `MAP_ARMY_FONT_SIZE_PX`, and `MAP_RING_SEGMENTS` — **which no row referenced
at all.**

**What is still open after this pass:**

- **Step 5 — the three new grids.** Everything that lands with them is in the `Status` block above
- **Acceptance.** Nobody has looked at the title screen or the map. The round's whole reason for
  existing — 「대충하지말고 제대로」, and a screen a human can operate without explanation — **cannot be
  closed by a net**
- **Whether a beakless route is acceptable design** (finding 15). That is a table change if the answer
  is no, and it is the user's call
- ⚠ **The glyph contrast floor is 1.8 and the tree’s tightest value is 2.02** (a locked chest). That is
  a 12% margin, and **it is the smallest margin any row in this round carries.** WCAG’s 3 : 1 is
  unreachable on this ink and this fill — see the design doc’s arithmetic — so **if the user still
  cannot read a locked node’s reward, the answer is a lighter INK, not a higher alpha**
