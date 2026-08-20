 이# Plan — parts on a board: the reward pick, the refit screen, and parts reaching the fight

**Status**: `2.active` — ⚠⚠ **MOSTLY BUILT AND CURRENTLY RED. Do NOT start this plan from stage 1.**
Design: `parts-on-a-board-not-on-the-body`.

> ### ⚠⚠ Read this before touching anything — the tree already holds most of this round, uncommitted
>
> **Measured 2026-08-20, immediately after both sessions stopped**: `18 nets · 1828 checks · 83 failures`.
> **Nothing is committed.** Every line below sits in the working tree only.
>
> ⚠ **This round was built by TWO Claude sessions at once on one tree**, which is why it is red and why
> the redness is not a normal mid-stage red. Two agents wrote the same files from opposite ends; one was
> stopped. **Before resuming, make sure only one session is writing, and run the suite from one place** —
> two concurrent runs already produced an exit-137 kill and a read of the shell with zero children.
>
> | Stage | State |
> |---|---|
> | 1 · parts and the board, sim only | **built** — `Part`/`Species`, `PART_STATS`, `part_bonus`, `unit_stat`, `CARDS_PER_WIN`/`CARD_PICKS`, `src/sim/loadout.gd` (new), `tests/nets/net_parts.gd` (new) |
> | 2 · a soldier belongs to a slot | **built** — `SUMMON_SLOTS` grew to three columns; `Army.add`→`recruit(slot)` with `slot_id`; the five per-soldier stat lookups; `Battle` reads `army.*_of(i)` for soldiers and stays type-keyed for enemies |
> | 3 · every node is a fight | **built in sim, NOT finished in the nets** — chest gone (`NodeKind{FIGHT,BOSS}`, `Reward{NONE,COUNT,BEAK}`), node 5 is `FIGHT`/`COUNT` on grid 0, six cards drawn on every non-boss win |
> | 4 · the reward screen | **built** — `src/view/reward_view.gd` (new, untracked) |
> | 5 · the refit screen | **built** — `src/view/refit_view.gd` (new, untracked); `game.gd` wires seven children, `_show_state()`, `_enter_pick_screen`, `_enter_refit_screen`, the `PICK`/`REFIT` input tables |
> | 6 · the dashboard | **partly** — the refit view already carries dashboard code. Unverified |
> | 7 · presentation, the probe, the docs | **not started** |
>
> ### What is actually left
>
> - **§8.4's four `net_shell` rows.** The file still asserts `get_child_count() == 5` against a shell that
>   builds seven, and still asserts a `COUNT` win lands on `MAP` when it now routes through `PICK`.
>   ⚠⚠ **Rewrite those to WALK `PICK` → `REFIT` → `MAP`. Do NOT loosen them to accept either state** —
>   a weakened check and a correct fix are indistinguishable in a green round, and this is the exact spot
>   where meeting a surprise red turns into deleting the measurement.
> - **`net_slots` is broken too** — `Game._open_island` calls `begin_island` on a null run, so the slot
>   checks fault rather than fail. Not in §8.4; found when the suite was measured after the stop.
> - **Stage 6 verified, stage 7 whole.**
> - **The probe must actually be RUN**, per the design's row 0b — the chest left this round, so there is
>   no recovery path at all, and a route wiping before the boss must be reported out loud rather than
>   discovered later.
>
> ### The one open question that never came back from the user
>
> **When a 체력 part is fitted, does a living soldier's CURRENT hp rise to the new maximum?** Built
> against **no** (max rises, current hp does not move), isolated to five lines in `Run.fit` so it can be
> flipped cheaply. ⚠ **It is the only recovery path this round could have**, which is why it was asked
> rather than filled in.

⚠ **Read the design doc's adversarial boxes before writing a line.** Two of them overturn sentences that
were in an earlier draft of that same doc, and this plan is built on the corrected side of both. The one
that matters most: **"this round does not touch combat" is FALSE.** Every stat is read off the TYPE today,
so a fitted part cannot reach a soldier without moving those reads onto `Army`.

**What this round is, in one line**: a won fight pays six cards and you take two; the parts you took are
laid into a slot's board of six cells; the board changes what the bodies that slot summons actually do in
the fight; and every node on the map becomes a fight.

**The largest piece is not either new screen.** It is stage 2 — `Rules.damage_of(type)` becoming
`army.damage_of(i)` in four places, with every consumer of a maximum HP following it.

---

## 0. OPEN questions — **the build does not stop for them, and each has a default**

**Sent to the user**: YES — all four handed to `main` in one message on 2026-08-20, which is the only
route this agent has to the user. **Three came back answered the same day and all three matched the
default**, so nothing in this plan moved on them; the fourth is still out and is built against its default.
`net_process` reddens on this section without this line, because the last round's five questions were
written down and never sent.

| # | Question | Answer / default | What it decides |
|---|---|---|---|
| **A** | ⚠⚠ **Do 세포 셋 (`Reward.COUNT`) and 부리 (`Reward.BEAK`) survive, now that every node is a fight and every fight pays six cards?** | ✅ **CLOSED — both survive untouched, and the six cards are paid by every fight node ON TOP of the node's own reward** | Had it gone the other way: without `COUNT` the roster is pinned at 10 for a whole run and `net_islands`' landing-region floor drops from 20; without `BEAK` the `REWARD` state, `apply_beak`, `panel_view`'s pick list and `Rules.BEAK_RANGE` all die together |
| **B** | **The ex-chest node (floor 4, the one node every route passes) becomes a fight — what does it pay, and on which grid?** | ✅ **CLOSED — `Reward.COUNT`, on a grid already in use.** Three grids now serve SEVEN island-opening nodes; that temporary is `title-and-map`'s and is declared in `rules.gd`'s own map header, so this adds a reader of it rather than a new lie | One row of `MAP_NODES` |
| **C** | ⚠⚠ **When a 체력 part is fitted, does an existing soldier's CURRENT hp rise with its maximum?** | ⏳ **STILL OPEN. Built against NO** — the maximum rises, the current value does not move, so a soldier already on the roster reads as wounded and a soldier recruited afterwards arrives full | ⚠⚠ **It decides whether any reconciliation code exists at all**, and a yes makes refit a heal — with the chest gone there is no other recovery in this game, so it is a balance rule and not a detail. ⚠ **Isolated on purpose**: the whole of a `yes` is one sibling of `recruit` — raise `hp[i]` by the change in `max_hp_of(i)` — called from `Loadout.fit` and `unfit` and from nowhere else. **Nothing else in this plan moves either way** |
| **D** | **Does refit open only after a pick, or from the map at any time?** | ✅ **CLOSED — only after the pick, once; 완료 returns to the map.** The design's own *when refit opens* row, read literally | A map-screen press and one more shell branch |

⚠ **Do not fill any of these in from the conversation.** The previous round is on record for inferring an
answer nobody gave, and `net_process` exists because of it.

---

## 1. Stages — **seven, each one a place to stop with a green round**

| # | Stage | On screen at its halt? | Green at its halt means | Nets |
|---|---|---|---|---|
| **1** | **The parts and the board** — `Rules`' part table, `src/sim/loadout.gd`, the held pile, fit/unfit | **NO** | A board can be filled and emptied by `.new()` and nothing else, and no number has moved in the fight yet | `net_parts` (new) |
| **2** | ⚠⚠ **Parts reach combat** — `Army` gains a slot column and the five per-soldier lookups; `Battle`'s four type-keyed reads move onto `Army`; `SUMMON_SLOTS` becomes a three-column table | **NO** (nothing is fitted yet, so every number is still its base) | **Two soldiers of one type can differ**, and every consumer of a maximum reads the same function | `net_parts` (grows) · `net_battle` · `net_run` · `net_summon` · `net_slots` · `net_plan` · `net_islands` |
| **3** | **Every node is a fight** — the chest, `HEAL` and `heal_all` leave; node 5 becomes a fight; six cards are drawn on every win | **YES** — the diamond is gone and floor 4 opens an island | `net_map` · `net_run` · `net_shell` |
| **4** | **The reward screen** — six cards, take two, `State.PICK`, `src/view/reward_view.gd` | **YES** — a new screen | `net_cards` (new) · `net_draw_leaf` · `net_shell` |
| **5** | **The refit screen** — `State.REFIT`, the slot strip, the board, the held pile, fit and unfit | **YES** — a new screen | `net_refit` (new) · `net_draw_leaf` · `net_shell` |
| **6** | **The dashboard** — the five numbers of the slot being edited, moving as a part lands | **YES** | The number that lands is the number the fight will read — **one function computes both** | `net_refit` (grows) |
| **7** | **Presentation, the probe and the docs** — the card reveal, the fit beat, the dashboard climb; `tools/probe/run_run.gd` learns the new states; acceptance lines | **YES** | Every rule that changes state says so on screen, and a probe can walk a run that fits parts | full round |

⚠ **A stage boundary is "what can be green at its halt", not "which files it touches"** — the rule
`plan-then-watch` used and `title-and-map` repeated. Stage 1 writes no view precisely so stage 5 has
nothing left to invent.

⚠⚠ **Stages 1 and 2 put nothing on screen, and that is the round's one real risk.** Two stages can be
green, complete and invisible. The countermeasure is not a screenshot — it is that **stage 2's checks are
written against `Army`, not against `Rules`**, so a lookup that quietly kept reading the type reddens
without a picture. If a stage-2 check can pass while `battle.gd` still calls `Rules.damage_of`, it is the
wrong check.

---

## 2. Structure — **the questions this repo's gate asks, answered before any code**

**Is this a variant or a new kind?**

- **The two screens are VARIANTS.** `look.gd` already carries the whole press vocabulary — `PRESS_HIT_PAD_PX`,
  `PRESS_ALPHA_ON`/`OFF`, the hover border pair, `PRESS_DOWN_SCALE`, `hover_lit`, `press_dipped`, `dimmed`,
  `scene_fade_colour` — and `title_view` is a working instance of it. **Neither new view invents a press.**
- **The loadout is a NEW KIND, and here is the sentence**: `Army` today has exactly one per-soldier
  modifier, `has_beak`, and it is one byte with one meaning. A board is six cells per slot, each holding a
  species, and it belongs to the SLOT rather than to the body — so it survives the body's death, which no
  column of `Army` can express. **If that sentence could not be written, `Loadout` would not exist and the
  board would be five more byte columns.**

**How many files change to add one new PART?** `rules.gd` (one row of `PART_STATS`, one enum name) ·
`look.gd` (one label). ⇒ **Two files.** The board's cell count is `Rules.part_count()` everywhere and no
view holds a 6.

**How many to add one new SPECIES?** `rules.gd` (one enum name) · `look.gd` (one label, one colour).
⇒ **Two files.**

**How many to add one new SUMMON SLOT?** `rules.gd`, **one row.** ⚠ **That is not true today and the claim
in `rules.gd`'s own slot header is half wrong**: `summon_slot_count()` and `hud_view`'s loop do follow the
table, but **the ROSTER does not** — `Army.add_starting_force` loops over `START_MELEE` and `START_RANGED`
by name, so a third slot would arrive with no bodies and no reward bodies, and every count check downstream
would stay green. **Stage 2 makes the header's claim true** by moving those two counts into the table as
columns.

**If an axis is added, does every consumer follow?** The axis is *a soldier's numbers depend on its slot's
board*. Its consumers, in full:

| Consumer | What it must read | ⚠ If it is forgotten |
|---|---|---|
| `battle.gd` `_phase_move` | `army.speed_of(i)` | a leg part changes nothing in the fight |
| `battle.gd` `_phase_attack` | `army.period_of(i)` · `army.damage_of(i)` | 팔 and 손 change nothing |
| `battle.gd` `_soldier_reach` | already `army.range_of(i)` — the beak's own precedent | — |
| `army.gd` `recruit` | `max_hp_of` for the birth value | a new body is born on the base maximum and reads as wounded forever |
| `field_view.gd` — **two HP-bar denominators** | `army.max_hp_of(i)` | ⚠⚠ **the bar overflows its own rect** at hp > base max, and nothing barks |
| `panel_view.gd` — the roster line `%.0f/%.0f` | `army.max_hp_of(i)` | the panel says 18/14 |
| `refit_view.gd` — the dashboard | the SAME function the fight reads | ⚠⚠ **the signature fake: the screen and the sim disagree** |
| `tools/probe/run_run.gd` | the new states, or it hangs | ⚠ a probe that hangs prints nothing at all — measured once here already |

⚠ **`map_view`'s 힘 readout is NOT on this list and that was checked, not assumed**: it sums `army.hp`,
never a maximum, so a raised cap does not move it. **A raised cap moving that number would be wrong** — the
pool is what the army has, not what it could have.

---

## 3. Files — **what DIES**

| File | What dies | Why it cannot simply stay |
|---|---|---|
| `src/sim/rules.gd` | **`NodeKind.CHEST`** | Every node opens a fight. A kind with no row is a kind whose picture nobody maintains |
| `src/sim/rules.gd` | **`Reward.HEAL`** | It was the chest's alone |
| `src/sim/rules.gd` | **`START_MELEE` · `START_RANGED` · `REWARD_MELEE` · `REWARD_RANGED`** | They are per-TYPE and the roster is now per-SLOT. They become columns of `SUMMON_SLOTS`. ⚠ **Fifteen reader sites across six nets** — listed in §9 |
| `src/sim/army.gd` | **`heal_all()`** | Its only caller was the chest. A rule constant or verb nobody reads rots silently — `rules.gd`'s own deleted-coastline block is the precedent |
| `src/sim/army.gd` | **`add(type_id)`** → **`recruit(slot)`** | ⚠⚠ **RENAMED, not re-typed, and this is the trap of the round.** `CELL_MELEE` is 0 and `CELL_RANGED` is 1, and slot 0 and slot 1 hold exactly those — so **`add(Rules.CELL_MELEE)` left unmigrated would keep working, meaning something else, forever.** A rename is what makes every call site move |
| `src/sim/run.gd` | **`take_heal_reward()`** and the `Rules.Reward.HEAL` arm of `_queue_reward` | with `HEAL` |
| `src/sim/run.gd` | **`enter_node`'s island-less branch** (`_queue_reward(n); return true`) | No node has `island < 0` any more. ⚠ **Delete the branch, do not leave it unreachable** — an unreachable arm reads as a supported case |
| `src/look.gd` | the chest's entry in `MAP_NODE_SIDES` and `COL_NODE_CHEST` | with the kind |
| `tests/nets/net_map.gd` | the chest rows — 「상자 칸은 섬을 안 열고 그 자리에서 회복한다」 · 「회복은 살아 있는 줄만 만피로 만든다」 · 「회복이 안 다쳤을 때의 풀을 못 넘는다」 | ⚠ **Rewritten, not deleted:** they become 「4층 칸도 섬을 연다」 and the heal rows are replaced by the two card rows in `net_cards`. **A deleted row is a check that stopped existing; say which row took its place** |

⚠ **`Rules.BEAK_RANGE`, `apply_beak` and the `REWARD` state do NOT die** — see open question A. If A comes
back "no", they die together and this table grows.

---

## 4. Files — **what CHANGES MEANING SILENTLY**

**This is the table a builder reads twice.** Every row keeps compiling, keeps printing green, and is wrong.

| File · symbol | What changes | ⚠ Why it is quiet |
|---|---|---|
| `army.gd` `hp[i]` | Stops being "out of `Rules.hp_of(type)`" and becomes "out of `army.max_hp_of(i)`" | ⚠⚠ **Three drawing sites divide by the old denominator** (two in `field_view`, one in `panel_view`). At hp > base max the ratio exceeds 1.0 and the bar draws past its own rect **with no error anywhere** |
| `army.gd` `range_of(i)` | base + beak → **base + beak + the head part** | ⚠ It is the ONE lookup that already existed. A builder who "already did that one" ships a board whose head cell does nothing |
| `battle.gd` `_phase_attack` | `Rules.damage_of(st)` → `army.damage_of(i)`, **but `Rules.area_of(st)` stays** | ⚠ 면적 is not one of the five numbers and no part moves it. Moving it too invents a sixth stat with no table behind it |
| `battle.gd` `slot_reserve_ids(slot)` | filters on `army.slot_id[i] == slot`, **not on the slot's type** | ⚠ Identical behaviour today (one slot per type) and **different the day two slots share a type** — which is what the whole three-column table exists for. Leaving it type-keyed makes two slots draw from one pool with every count green |
| `hud_view.gd` — the slot pool readout | `army.living_ids_of_type(want).size()` → the slot-keyed count | ⚠ Same shape. The HUD would say six bodies while the summon has three |
| `run.gd` `_advance()` | `WON` / `MAP` → **`WON` / `PICK` / `REFIT` / `MAP`**, in that priority | ⚠⚠ **Skip the `PICK` arm and the cards are drawn and never shown** — the roster grows, the run walks back to the map, and every existing check stays green |
| `run.gd` `State` | gains `PICK` and `REFIT` | ⚠ `MAP` stays **first and therefore 0**, for the reason its own comment gives. ⚠ **Nothing anywhere may compare a state against a literal int**; a net pins `State.MAP == 0` and the rest by name |
| `game.gd` `_close_island()` | its two-arm `if state == MAP` becomes a dispatch | ⚠ **Extract `_show_state()` and call it from all three sites** (`_close_island`, `_release_hold`'s beak branch, `_enter_node`'s else). Three copies of a state→screen mapping is three places to forget `REFIT` |
| `game.gd` `_enter_pick_screen` / `_enter_refit_screen` | must null `battle` exactly as `_enter_map_screen` does | ⚠⚠ **The one lever that silences `field_view` AND `hud_view` at once.** Leave it and the island just won keeps drawing under the cards, keeps panning, and its clock and start button come with it |
| `game.gd` `_unhandled_input` order | the `PICK` and `REFIT` branches sit **beside the `MAP` branch, above the `battle != null` block** | ⚠ Below it, a click on a card falls through to `_panning = true` |
| `panel_view.panel_active()` | ✅ **NOTHING** | It is `run != null and (state == REWARD or is_finished())` — an **allowlist**, false on both new states for free. ⚠ **Do not "harden" it and do not add the new states "for symmetry".** What it is owed is a check driving all seven states, not an edit |
| `net_draw_leaf` — five totals | view files **5 → 7** · `table.size()` **5 → 7** · `total_funcs` **129 → re-derive** · `total_leaves` **33 → re-derive** · `wide_scanned` **6 → 8** | ⚠ **Re-derive by hand at the halt.** A literal that does not move is the one nobody re-derives — a previous draft landed both totals back on their old values while five per-file counts had moved |
| `net_islands` `_min_region_floor()` | `START_MELEE + START_RANGED + …` → `roster_start_count() + map_max_count_nodes_on_a_route() * roster_reward_count() + 1`, **and the number moves 20 → 23** | ⚠⚠ **THE NUMBER DOES CHANGE THIS ROUND, and an earlier draft of this row said it did not.** Stage 3 makes node 5 a `COUNT` fight, so the route `0 → 1 → 4 → 5` steps on **four** count nodes and `map_max_count_nodes_on_a_route()` goes 3 → 4. ⇒ **Both literal self-checks move in the same edit or the raise is invisible**: the floor `20` → **23**, and the max-roster line `19` → **22**. ✅ Measured: the three shipped islands' smallest landing regions are **744 · 760 · 716** tiles, so 23 breaks none of them and lands purely as a constraint on grids that do not exist yet |
| ⚠⚠ `look.gd` — the beak panel's roster block | `ROSTER_ROWS` **10 → 11** (capacity 20 → **22**) · `BUTTON_OFFSET_PX` y **420 → 456** · `PANEL_SIZE_PX` y **480 → 520** · `PANEL_ORIGIN_PX` y **120 → 100** | ⚠⚠ **Same cause, one screen over, and it is the cap this repo has already been bitten by.** The roster's ceiling goes 19 → **22** against a panel that holds 20; `panel_view.roster_ids` caps at `roster_capacity()` and **drops the overflow silently**. ⚠ **It is NOT reachable on the map as authored** — a `REWARD` screen only opens on a `BEAK` node, and the most count nodes a route passes *before* reaching one is two (`0 → 1 → 3`), so the panel tops out at 16 today. **That is exactly why it is fixed rather than documented**: the reason it does not bite is a property of where the beak nodes sit, and **this round is editing the node table.** A comment saying "the cap never bites" is the sentence `panel_view` already shipped once before it bit. ⇒ **Pin the CONSERVATIVE bound** — the panel holds every soldier a run can field, with no clause about beak placement — and the coupling is deleted instead of explained. **Arithmetic**: `72 + 11 × (28 + 6) = 446 ≤ 456` · `456 + 48 = 504 ≤ 520` · `(720 − 520) / 2 = 100`, and `100 + 520 = 620 ≤ 720` · width unchanged at `40 + 240 + 24 + 240 = 544 ≤ 560`. ⚠ **`look.gd`'s own `PANEL_SIZE_PX` comment and `panel_view.roster_ids`' comment both state the old `10 + 3 × 3 = 19` and both go stale in this edit** — they are two of the three places this number is written down |
| `tools/probe/run_run.gd` | learns `PICK` and `REFIT`, and takes both cards | ⚠⚠ **A driver whose `match` has no arm for a new state falls into `else: break` and plays zero islands with exit code 0.** That exact failure was measured here on the last round |

---

## 5. The sim

### 5.1 `rules.gd` — the parts

⚠ **Naming trap, and it is not hypothetical.** `net_draw_leaf._pixel_hits` sweeps
`px|width|radius|size|margin|alpha|ratio|offset|gap|font_size|cols` over **all of `src/` except `look.gd`**,
matching `NAME_<suffix> := <digit>`. **`BOARD_COLS := 3` would redden a sim constant.** It is also the
right answer for another reason: **3×2 is a layout, so the sim does not know it.** The sim knows six parts;
`look.gd` knows they are drawn three across.

```gdscript
## The six parts a board has a cell for. ⚠ A cell is bound to one part — head goes in the head cell and
## nowhere else — so this enum IS the cell index and there is no second numbering to keep in step.
enum Part { HEAD, CHEST, BELLY, ARM, HAND, LEG }

## What a part belongs to. ⚠ **It does NOTHING this round and that is decided, not forgotten**: the user
## took set effects out and left the species in as the place they will attach. Nothing below reads it.
enum Species { MAMMAL, BIRD, FISH }

## The five columns a part may move — declared in UNITS' own order so the two tables read alike.
const PART_COL_HP := 0
const PART_COL_DAMAGE := 1
const PART_COL_PERIOD := 2
const PART_COL_RANGE := 3
const PART_COL_SPEED := 4
const PART_COL_TOTAL := 5

## One row per part, five columns, ADDED to the type's own number. Nothing multiplies: two rules for one
## column is the second copy that diverges.
## ⚠ **These are first values, not measured ones.** `parts-on-a-board-not-on-the-body` records that what a
## part moves and by how much is balance work that needs the screen to exist first.
## ⚠ There is deliberately NO clamp on the result anywhere in the code. One part per cell means a period
## can fall by at most one row's worth, so a floor would be a branch no input can reach — dead code
## wearing a safety belt. **The bound lives in `net_parts` as a literal instead**, so a table edit that
## drove a period to zero reddens where a dead clamp would have hidden it.
const PART_STATS := [
	[0.0, 0.0,  0.00, 1.0, 0.0],   # HEAD  머리 — 사거리
	[4.0, 0.0,  0.00, 0.0, 0.0],   # CHEST 가슴 — 체력
	[3.0, 0.0,  0.00, 0.0, 0.0],   # BELLY 배   — 체력
	[0.0, 1.0,  0.00, 0.0, 0.0],   # ARM   팔   — 공격력
	[0.0, 0.0, -0.15, 0.0, 0.0],   # HAND  손   — 공격주기 (내려간다)
	[0.0, 0.0,  0.00, 0.0, 0.8],   # LEG   다리 — 이동속도
]
```

**Accessors** — `part_count()` = `PART_STATS.size()` · `species_count()` · `part_bonus(part, col)` (casts,
because a `const` Array loses element typing) · **`unit_stat(type_id, col)`**, which maps a `PART_COL_*`
onto the matching `UNITS` column. ⚠ **`unit_stat` is what stops the five columns being named twice** — every
base number in the game is still read through the existing `hp_of` · `damage_of` · `period_of` · `range_of`
· `speed_of`, and `unit_stat` is a `match` over those five and nothing else.

**The cards**: `const CARDS_PER_WIN := 6` · `const CARD_PICKS := 2`, both from the user's 「6개중 2택」.

### 5.2 `rules.gd` — `SUMMON_SLOTS` gains two columns

```gdscript
## Columns: unit type, how many bodies a run STARTS with in this slot, how many a COUNT node adds to it.
## ⚠⚠ **The starting counts moved here from START_MELEE / START_RANGED because they were per-TYPE and the
## roster is per-SLOT.** A third row used to arrive with no bodies at all and every count check stayed
## green; the header above already claimed a third binding costs one line, and for the roster it did not.
const SUMMON_SLOTS := [
	[CELL_MELEE, 6, 2],
	[CELL_RANGED, 4, 1],
]
```

`summon_type_of(slot)` keeps its signature and its `SUMMON_UNBOUND` answer (reading column 0 now) ·
`slot_start_count(slot)` · `slot_reward_count(slot)` · **`roster_start_count()`** and
**`roster_reward_count()`**, the two sums that replace `START_MELEE + START_RANGED` and
`REWARD_MELEE + REWARD_RANGED` at fifteen sites.

### 5.3 `src/sim/loadout.gd` — `class_name Loadout`, `extends RefCounted`

**Flat arrays. No `Node`, no `_draw`, no `Input`, no `get_node`, no `$`.** Constructible and drivable with
`.new()` and nothing else.

```gdscript
## The boards, flat: `board[slot * Rules.part_count() + part]` is the SPECIES fitted in that cell, or -1.
## ⚠ The cell holds a species and not a part id, because the cell IS the part. There is no arrangement in
## which a leg can sit in the head cell, so there is no rule anywhere that has to forbid it.
var board := PackedInt32Array()

## The pile a card pays into and an unfit returns to. Two parallel arrays, index-aligned, the shape
## `army.gd` uses and for the same reason.
var held_part := PackedInt32Array()
var held_species := PackedInt32Array()
```

| Method | Contract |
|---|---|
| `fitted_species(slot, part) -> int` | the cell, or **-1** for empty. Out of range is -1, not a fault |
| `bonus(slot, col) -> float` | sums `Rules.part_bonus(part, col)` over the cells that are filled. ⚠⚠ **This one function is the whole of the room sets need** — a set term is added here and no consumer moves |
| `stat_of(slot, col) -> float` | **`Rules.unit_stat(Rules.summon_type_of(slot), col) + bonus(slot, col)`**. ⚠⚠ **Every number in the game that a part can move comes out of THIS call — the fight's and the dashboard's alike.** That is what makes "the screen and the sim disagree" unbuildable rather than merely checked |
| `fit(slot, held_index) -> bool` | false and **changes nothing** on a bad slot or index. Otherwise: read the card, **remove it from the pile, then** push any occupant of its cell back onto the pile, then write the cell. ⚠ **That order is a contract**: pushing first and removing second renumbers the pile under the index being removed |
| `unfit(slot, part) -> bool` | false on an empty cell. Otherwise appends `(part, species)` to the pile and clears the cell |
| `take_card(part, species)` | appends to the pile. The only way anything enters it |
| `reset()` | every cell -1, the pile empty. Shared by `_init` and `Army`'s own construction, the same reason `Run._reset` is shared |

⚠ **The pile COMPACTS and the roster does not, and the difference is deliberate.** A soldier's index is its
identity for a whole run; a held index is an argument to one call and nothing holds it across two.
⇒ **`refit_view` must re-read the pile after every fit** and may not cache a row's index between frames.

### 5.4 `army.gd`

```gdscript
## Which summon slot this body belongs to. Written once, by `recruit`, and never again.
## ⚠⚠ **A body belongs to a slot from BIRTH and not from the moment it is summoned.** Bound at summon, a
## reserve body's numbers would be the base ones while it waits and the slot's ones once it sails — so a
## fresh body would arrive at less than full HP the first time a 체력 part was fitted, with the bar saying
## it was wounded when nothing had hurt it.
var slot_id := PackedInt32Array()
```

- **`recruit(slot) -> int`** replaces `add(type_id)`. Appends `Rules.summon_type_of(slot)` to `type_id`,
  `slot` to `slot_id`, **`max_hp_of(id)`** to `hp`, 0 to `has_beak`, 1 to `alive`.
  ⚠ **The HP is read back off the same function combat reads**, so a body is never born on a number nothing
  else uses.
- **`add_starting_force()`** loops over `Rules.summon_slot_count()` and `Rules.slot_start_count(s)`.
  ⚠ **No type is named in this function any more.**
- **`living_ids_of_slot(slot) -> Array`** — the slot's living bodies, highest HP first.
  ⚠ **`living_ids_of_type` stays** and keeps its documented order: `tools/probe/run_run.gd` reads `ids[0]`
  to put the beak on the healthiest body, and that is a design instrument, not a caller. The two share
  their comparator; neither re-derives the other's predicate.
- **The five lookups**, each one line:
  `max_hp_of(i)` · `damage_of(i)` · `period_of(i)` · `speed_of(i)` — all `loadout.stat_of(slot_id[i], COL)`;
  **`range_of(i)`** — the same, **plus `Rules.BEAK_RANGE` when `has_beak[i]`**.
  ⚠ **There is no `slot_id < 0` arm.** `recruit` is the only way a row exists and it always writes a slot,
  so a fallback would be an unreachable branch that reads as a supported case. `net_parts` asserts every
  row of a fresh army has a slot.
- **`var loadout := Loadout.new()`**, built in `Army`'s own construction.
  ⚠⚠ **The boards hang off the ARMY, not off the `Run`, and that is the load-bearing choice:** `Battle` is
  handed `army` and nothing else, so this is what lets `army.damage_of(i)` reach a board without a new
  argument on `Battle.setup` and without `Battle` learning what a slot's loadout is. It also makes the
  design's own sentence structural — **a body dies and its parts die with it, the board does not** — because
  `Army` outlives every `Battle` and no code has to remember to move a board across an island.

### 5.5 `run.gd`

- `enum State { MAP, BATTLE, REWARD, PICK, REFIT, WON, LOST }`. ⚠ **`MAP` stays 0.**
- `var cards := PackedInt32Array()` — **`CARDS_PER_WIN` pairs, flat**: `cards[2*k]` is the part,
  `cards[2*k + 1]` the species. `var cards_taken := PackedByteArray()`.
  ⚠ **Flat and parallel, not an Array of Arrays**, for the reason `army.gd`'s header gives.
- `var _rng := RandomNumberGenerator.new()`, seeded in `_reset` with `_rng.randomize()`, plus
  **`seed_cards(s: int)`** for nets and the probe.
  ⚠⚠ **This is the first RNG in `src/sim/`, and it is bounded on purpose**: one object, one reader
  (`_draw_cards`), one seed verb. **The map stays authored** — `title-and-map`'s reason for that (four
  routes a net can walk exhaustively) is untouched.
- `_draw_cards()` — `CARDS_PER_WIN` independent draws of `(randi_range(0, part_count()-1),
  randi_range(0, species_count()-1))`, `cards_taken` cleared. Called from `finish_island(true)` **before**
  `_queue_reward`.
- **`take_card(k) -> bool`** — refuse unless `_state == PICK`, `k` in range, `cards_taken[k] == 0`, and
  fewer than `Rules.CARD_PICKS` taken. Then mark it, `army.loadout.take_card(...)`, and **when the
  `CARD_PICKS`th is taken, `_state = State.REFIT`**.
- **`close_refit()`** — refuse unless `REFIT`; then `_state = State.MAP`, or `WON` if the map is finished.
  ⚠ **The boss pays no cards** (`Reward.NONE`, and `_advance` checks `map.is_finished()` first), so this
  arm exists only so a future boss-that-pays cannot end a run on the refit screen.
- **`_advance()`** — `WON` if `map.is_finished()`; **else `PICK` if any card is undrawn-from**
  (`cards.size() > 0 and taken < CARD_PICKS`); else `MAP`.
  ⚠⚠ **The `PICK` arm goes ABOVE the `MAP` arm.** Below it, the cards are drawn and never shown and the
  round stays green.

**The whole state walk, once**:

```
시작하기          run = Run.new()              → MAP, path empty
press node 0      enter_node(0)                → BATTLE, island 0
win               finish_island(true)          → 6 cards drawn → COUNT applied → _advance → PICK
take two cards    take_card(k) ×2              → REFIT
fit / unfit       loadout.fit / unfit          → REFIT (state does not move)
완료              close_refit()                → MAP
press a BEAK node … win                        → 6 cards drawn → REWARD (the beak pick, as today)
pick a soldier    apply_beak(id)               → _advance → PICK → REFIT → MAP
press the boss    … win                        → map.is_finished() → WON (panel)
restart           run = null; battle = null    → TITLE
```

⚠ **The beak pick comes BEFORE the cards** because `_queue_reward` already routes it and nothing about the
cards belongs inside that dispatch. Two reward screens in a row for one node is the price; it is written
here so nobody discovers it as a bug.

### 5.6 `rules.gd` — the map becomes all fights (stage 3)

```gdscript
## ⚠ The chest is GONE — 「일단 전부 다 monster 노드로 만들면 될듯」. Every node opens an island, so the
## island column has no -1 in it any more and `NodeKind` has two entries.
## ⚠ The island column is still the declared temporary from `title-and-map` — three grids serving SEVEN
## island-opening nodes now, one more than before. The check that forbids two nodes sharing a grid still
## lands WITH the grids and no round is red for the gap.
const MAP_NODES := [
	[0, NodeKind.FIGHT, Reward.COUNT, 0],   # 0 — floor 1, fixed, where every run lands
	[1, NodeKind.FIGHT, Reward.COUNT, 1],   # 1 — floor 2 left
	[1, NodeKind.FIGHT, Reward.BEAK,  2],   # 2 — floor 2 right
	[2, NodeKind.FIGHT, Reward.BEAK,  1],   # 3 — floor 3 left
	[2, NodeKind.FIGHT, Reward.COUNT, 2],   # 4 — floor 3 right
	[3, NodeKind.FIGHT, Reward.COUNT, 0],   # 5 — floor 4, WAS THE CHEST (§0 question B, closed)
	[4, NodeKind.BOSS,  Reward.NONE,  2],   # 6 — floor 5, the lion, the run ends here
]
```

**`MAP_EDGES` does not move.** ⚠ **A route is now four fights and a boss**, where it was three fights, a
chest and a boss. `title-and-map`'s HP schedule was derived **with the chest in it** and this removes the
node the recovery fix was going to live on — see §12.

**One new accessor**: **`map_max_card_nodes_on_a_route()`** — the most card-paying nodes a single route can
step on, walked over the table exactly as `map_max_count_nodes_on_a_route()` is, never written as a literal
4. `Look.refit_held_capacity()`'s floor rides on it, and a hand-written 4 beside a table that can grow is
the second copy this repo has watched rot twice.

⚠ **A node pays cards iff it is not the boss**, and that is the whole rule. `finish_island(true)` draws
them under `if not map.is_finished()`; the accessor counts nodes whose kind is not `BOSS`. **Those are the
same fact asked from two directions — where the run is standing, and what a route contains — and neither
re-derives the other's predicate.** A route walk cannot ask `map.is_finished()` and a standing run cannot
ask a route.

---

## 6. The shell

`_unhandled_input`, directly under the existing hold guard and **above** the `battle != null` block:

```gdscript
	if run.state() == Run.State.MAP:
		_map_input(event)
		return
	if run.state() == Run.State.PICK:
		_pick_input(event)
		return
	if run.state() == Run.State.REFIT:
		_refit_input(event)
		return
```

- **`_pick_input`** — motion → `reward_view.set_hover(pos)`; LEFT press → `reward_view.card_at(pos)`, and
  if `run.take_card` would accept it, `reward_view.note_press(k)` then `run.take_card(k)`, then
  **if the run left `PICK`, `_enter_refit_screen()`**.
  ⚠ **Whether a card may be taken is asked of the SIM**, exactly as the map asks `run.map.is_reachable` —
  the view's own `is_card_pressable` calls the same predicate, so the picture can never offer a card the
  sim refuses.
- **`_refit_input`** — motion → `refit_view.set_hover(pos)`; LEFT press, in this order:
  1. **the 완료 button** → `run.close_refit()` then `_show_state()`
  2. **the 뒤로 button** (only while a board is open) → `refit_view.open_slot(-1)`
  3. **a slot box** (only on the strip) → `refit_view.open_slot(s)`
  4. **a held row** → `run.army.loadout.fit(open_slot, row)`
  5. **a filled cell** → `run.army.loadout.unfit(open_slot, part)`
- **`_show_state()`** — the one mapping from `run.state()` to a screen: `MAP` → `_enter_map_screen()`,
  `PICK` → `_enter_pick_screen()`, `REFIT` → `_enter_refit_screen()`, anything else → `_open_island()`.
  Called from `_close_island`, from `_release_hold`'s beak branch and from `_enter_node`'s else arm.
- **`_enter_pick_screen()` / `_enter_refit_screen()`** — the shape of `_enter_map_screen`:
  `battle = null` · `field_view.setup(null, null, [])` · `_disarm()` · `hud_view.bind(null)` ·
  `panel_view.bind(run, null)` · bind the new view · **hide the other three**.
- `_ready()` builds **seven** children: `field · hud · map · reward · refit · title · panel`.
  **Draw order is tree order for `Node2D` siblings**, and the panel stays last because it is the overlay.
  `get_child_count()` is **7**.

⚠⚠ **Every net that presses a card or a cell drives `game._unhandled_input(ev)`**, the entry point the OS
uses — **not a screen-specific helper.** Headless the window is 64×64 and `root.push_input` divides by a
0.05 stretch, so a pushed click lands thousands of px away **and raises no error**.

---

## 7. The screens — every constant, valued, floored and ceilinged

⚠ **All of these go in `look.gd` and nowhere else.** Screen is **1280 × 720**. Mouse only.
⚠ **The press vocabulary is REUSED, not re-declared**: `PRESS_HIT_PAD_PX` 8 · `PRESS_ALPHA_ON` 1.0 ·
`PRESS_ALPHA_OFF` 0.30 · `PRESS_BORDER_WIDTH_PX` 3 · `PRESS_HOVER_BORDER_WIDTH_PX` 6 ·
`PRESS_HOVER_BRIGHTEN` 0.12 · `PRESS_DOWN_SCALE` 0.96 · `SCENE_FADE_SEC` 0.35. **A new press constant on
either screen is a defect** unless its comment says what the shared one could not do.

### 7.1 The reward screen — six cards, 3 across and 2 down

| Constant | Value | Floor | Ceiling |
|---|---|---|---|
| `CARD_SIZE_PX` | `Vector2(280.0, 200.0)` | ≥ **(220, 64)** — the largest press in the game, and no new press is smaller | `3×280 + 2×32 = 904 ≤ 1280` |
| `CARD_GAP_PX` | **32.0** | ≥ 12 or two cards read as one bar | ≤ 80, from the width arithmetic above |
| `CARD_GRID_ORIGIN_PX` | `Vector2(188.0, 180.0)` | x = `(1280 − 904) / 2` **exactly** · y ≥ 120 (clear of the hint line above) | `180 + 2×200 + 32 = 612 ≤ 720` |
| `CARD_PART_FONT_SIZE_PX` | **34** | **> `HUD_TIMER_FONT_SIZE_PX` 30** — the part name is the loudest thing on its own card | ≤ 44, from 4 glyphs at ~0.6em inside `280 − 2×24` |
| `CARD_SPECIES_FONT_SIZE_PX` | **20** | ≥ 16 (unreadable below) | **≤ `CARD_PART_FONT_SIZE_PX` − 12**, or 부위 and 종 read as one line |
| `CARD_PART_OFFSET_PX` | `Vector2(24.0, 84.0)` | **x > 0 and y ≥ the part font size** — a glyph at the rect's own origin is a glyph that was never placed | inside the card |
| `CARD_SPECIES_OFFSET_PX` | `Vector2(24.0, 132.0)` | **y ≥ `CARD_PART_OFFSET_PX.y + CARD_PART_FONT_SIZE_PX`**, or the two lines overlap | inside the card |
| `CARD_TAKEN_MARK_R_PX` | **26.0** | ⚠⚠ **≥ 18.** A taken card and a card that can no longer be taken both fall to `PRESS_ALPHA_OFF`, so **alpha alone cannot tell them apart** — the map measured exactly this and answered it with size AND brightness AND what is drawn on top. This mark is that third channel | ≤ 40, or it covers the part name |
| `CARD_HINT_POS_PX` · `CARD_HINT_FONT_SIZE_PX` | `Vector2(500.0, 120.0)` · **26** | y ≥ the font size · **> `HUD_FONT_SIZE_PX` 22** | y ≤ 160, clear of the grid at 180 |
| `COL_CARD` | one new tone | — | ⚠ **시작하기 reuses `COL_START` and 종료 reuses `COL_BUTTON`** by `look.gd`'s own same-verb-same-tone rule; a card is a new verb and gets one tone |
| `COL_SPECIES` | three tones, indexed by `Species` | pairwise luminance ratio **≥ 1.4** | — |

**Card rects, derived**: `Rect2(188 + c×312, 180 + r×232, 280, 200)`. **Hit rects grow by
`PRESS_HIT_PAD_PX` on all four sides** ⇒ 296×216 at a 312×232 pitch, so **no two hit rects touch**
(312 − 296 = 16 > 0, 232 − 216 = 16 > 0). **Nothing writes 296 or 216.**

### 7.2 The refit screen

**Step one — the slot strip.**

| Constant | Value | Both ends |
|---|---|---|
| `REFIT_SLOT_SIZE_PX` | `Vector2(360.0, 120.0)` | ≥ (220, 64) · `200 + 2×120 + 24 = 464 ≤ 720` |
| `REFIT_SLOT_GAP_PX` | **24.0** | ≥ 12 · ≤ 60 |
| `REFIT_SLOT_ORIGIN_PX` | `Vector2(460.0, 200.0)` | x = `(1280 − 360) / 2` **exactly** |
| `REFIT_BUTTON_SIZE_PX` | `Vector2(240.0, 80.0)` | ≥ (220, 64) · ≤ (360, 120) |
| `REFIT_DONE_ORIGIN_PX` | `Vector2(520.0, 600.0)` | `600 + 80 = 680 ≤ 720`, and 600 > 464 so it never touches the strip |

⚠ **The strip is drawn on BOTH steps and the boxes do not move**, so a slot that opened is the slot the
board belongs to and the player never loses it. The open one is drawn at `PRESS_ALPHA_ON` and the others at
`PRESS_ALPHA_OFF` — **the same two constants the title uses for the same claim.**

**Step two — the board, the pile, the dashboard, the body.**

| Constant | Value | Both ends |
|---|---|---|
| `REFIT_CELL_SIZE_PX` | `Vector2(220.0, 140.0)` | ≥ (220, 64) — **exactly at the width floor, deliberately**: the board is the densest press on any screen · `3×220 + 2×20 = 700` |
| `REFIT_CELL_GAP_PX` | **20.0** | ⚠⚠ **≥ 17, and the reason is the hit pad, not the eye**: a hit rect grows 8 on each side, so at a gap of 16 two neighbours' hit rects share an edge exactly and `Rect2.intersects` (borders excluded by default) calls that no overlap — **a press between two cells would then be legal for both and the check that forbids it would still be green.** 20 leaves 4 px clear · ≤ 40 (`80 + 3×220 + 2×40 ≤ 800`) |
| `REFIT_BOARD_ORIGIN_PX` | `Vector2(80.0, 320.0)` | `80 + 700 = 780 ≤ 800` (clear of the pile column) · `320 + 2×140 + 20 = 620`, hit bottom **628** |
| `REFIT_CELL_PART_FONT_SIZE_PX` | **26** | **> `HUD_FONT_SIZE_PX` 22** · ≤ 34 |
| `REFIT_CELL_SPECIES_FONT_SIZE_PX` | **18** | ≥ 16 · **≤ the part font − 6** |
| `REFIT_HELD_ORIGIN_PX` | `Vector2(800.0, 300.0)` | x > 780 (clear of the board **and** of the dashboard) · `800 + 240 + 220 = 1260`, hit right edge **1268 ≤ 1280** |
| `REFIT_HELD_SIZE_PX` | `Vector2(220.0, 64.0)` | **exactly the smallest legal press**, and its comment says so |
| `REFIT_HELD_GAP_PX` | **20.0** | **≥ 17**, the same hit-pad arithmetic as the cells · ≤ 32 from the row count below |
| `REFIT_HELD_COL_PITCH_PX` | **240.0** | **≥ 237** (220 + 8 + 8 + 1) or the two columns' hit rects overlap · ≤ 250 from the right edge |
| `REFIT_HELD_ROWS` | **5** | ⚠⚠ **`refit_held_capacity()` = `2 × 5 = 10` and it must stay ≥ `Rules.CARD_PICKS × Rules.map_max_card_nodes_on_a_route()` = 8.** `panel_view.roster_ids` shipped a cap that silently dropped the overflow and its comment said the cap never bit — **it bit.** This one is pinned against the map, not against a guess | `300 + 4×84 + 64 = 700`, hit bottom **708 ≤ 720** |
| `REFIT_STAT_ORIGIN_PX` | `Vector2(80.0, 150.0)` | y ≥ the value font size · `80 + 5×140 = 780 ≤ 800` |
| `REFIT_STAT_PITCH_PX` | **140.0** | ≥ 110 (the widest label 「공격주기」 at ~0.6em of 20px is 48px, and the value below it needs the same again) · ≤ 144 from the arithmetic above |
| `REFIT_STAT_LABEL_FONT_SIZE_PX` | **20** | ≥ 16 · **< the value font − 10**, or the label competes with the number |
| `REFIT_STAT_VALUE_FONT_SIZE_PX` | **34** | **> `HUD_TIMER_FONT_SIZE_PX` 30** — these five numbers are the point of the screen | ≤ 44 |
| `REFIT_BODY_CENTRE_PX` | `Vector2(1030.0, 180.0)` | y − radius ≥ 90 · **y + radius ≤ 300**, clear of the pile · x ± radius inside 780…1280 |
| `REFIT_BODY_SCALE` | **5.0** | ≥ 3 — under it the ranged body is 34 px and its corner rounding, which is half of how the two types are told apart, is invisible | ≤ 8, from `0.35 × 40 × 8 = 112 > the 210 px band` |
| `REFIT_DONE_ORIGIN_PX` (step one) | `Vector2(520.0, 600.0)` | `600 > 472` (the strip's hit bottom) · `600 + 80 = 680`, hit bottom **688 ≤ 720** |
| `REFIT_DONE_BOARD_ORIGIN_PX` · `REFIT_BACK_ORIGIN_PX` (step two) | `Vector2(80.0, 632.0)` · `Vector2(340.0, 632.0)` | ⚠ **The button has two positions and that is why**: on step two the board occupies y 320…628 including its pad, so a button at 600 would sit on top of it. `632 > 628` · `632 + 80 = 712 ≤ 720` · the two are 260 apart against a 240 width, so their hit rects clear by 4 |

⚠⚠ **The body preview is NOT decoration and it is NOT a paperdoll.** It draws the slot's own type at
`body_radius_of(type) × REFIT_BODY_SCALE` with that type's corner rounding — **14 px vs 11.2 px radius and
0.25 vs 0.85 corner ratio**, so the two slots are told apart on two channels. **No part is drawn on it**:
the design's row on 머리·가슴·배 says those cannot show on a top-down body and that the dashboard is what
carries them, and giving the other three a protruding form is an open drawing question. ⇒ **The body says
which slot you are editing and nothing else, and that is written down so the next reader does not add
limbs to it.**

**Dashboard labels**: 체력 · 공격력 · 공격주기 · 사거리 · 이동속도 — **the five that exist.**
⚠ **방어력 is NOT drawn.** The user named it; the shipped tree has no defence column and adding one changes
every damage calculation in the fight. `parts-on-a-board-not-on-the-body` carries the row.

---

## 8. Nets — **twenty, and every check names its mutation**

**The wrapper refuses a round under five nets.** Three are new; the round goes **17 → 20**.

⚠ **Every mutation below is a find/replace pair to be applied mechanically in an isolated copy.** Where a
line is one this plan dictates rather than one that exists today, the find string is quoted from §5–§7.

### 8.1 `net_parts` — NEW (stages 1 and 2)

| Korean label | Floor | Ceiling | Mutation |
|---|---|---|---|
| 「부위는 여섯이고 종은 셋이다」 | `part_count() == 6` | `species_count() == 3` | `rules.gd`: delete the `[0.0, 0.0, 0.00, 0.0, 0.8],   # LEG` row |
| 「부위 표의 모든 줄이 다섯 칸이다」 | every row `.size() == PART_COL_TOTAL` | — | `rules.gd`: drop the last column of the `ARM` row |
| ⚠ 「어떤 부위도 아무 숫자도 안 움직이지 않는다」 | **every row has at least one non-zero** | — | `rules.gd`: `[0.0, 1.0,  0.00, 0.0, 0.0],   # ARM` → `[0.0, 0.0,  0.00, 0.0, 0.0],   # ARM` — ⚠ **this is the row that catches a part that exists and does nothing**, which is the shape a green round cannot otherwise see |
| ⚠ 「여섯을 다 끼워도 공격주기가 0.2초 밑으로 안 간다」 | **≥ 0.2, a LITERAL** | — | `rules.gd`: `-0.15` → `-1.50` — ⚠ **the bound is a literal and not `PART_STATS`' own sum**; read out of the table it would pass at any value |
| 「빈 판의 숫자는 UNITS 그대로다」 | slot 0: 14 · 2 · 1.0 · 0 · 4, **literals** | — | `loadout.gd`: make `stat_of` return `bonus(...)` alone |
| 「가슴을 끼우면 체력이 4 오르고 나머지 넷은 안 움직인다」 | hp 14 → **18** | the other four **exactly** unchanged | `loadout.gd`: make `bonus` return 0.0 |
| ⚠ 「부위를 빼면 숫자가 정확히 원래대로 돌아온다」 | equals the empty-board value | — | `loadout.gd`: make `unfit` clear the cell without appending to the pile |
| 「한 칸에는 한 부위뿐 — 가슴을 두 번 끼우면 앞엣것이 더미로 돌아온다」 | pile size unchanged | the old species is **in the pile** | `loadout.gd`: in `fit`, push the occupant **before** removing the card — ⚠ **an ordering contract, and reading only the final board size cannot see it** |
| 「머리 칸에 다리를 넣을 함수가 없다」 | `fit` takes no cell argument | — | ⚠ **A source scan, and it is declared as one**: `net_parts` greps `loadout.gd` for `func fit(` and asserts its parameter list. **A grep measures text and never what it computes** — the behaviour it stands for is unbuildable, which is why a text check is all there is to buy here |
| 「판은 슬롯의 것이라 몸이 죽어도 안 사라진다」 | kill every soldier of slot 0, board unchanged | a body recruited afterwards reads the fitted numbers | `army.gd`: clear the board inside `kill` |
| ⚠ 「모든 명부 줄에 슬롯이 적혀 있다」 | every `slot_id[i] >= 0` | `< summon_slot_count()` | `army.gd`: `slot_id.append(slot)` → `slot_id.append(-1)` |
| 「시작 병력은 표의 열 명이고 슬롯별로 6과 4다」 | `roster_start_count() == 10` | per slot 6 · 4 | `rules.gd`: `[CELL_RANGED, 4, 1],` → `[CELL_RANGED, 0, 1],` |
| ⚠⚠ 「같은 종류 병사 둘이 서로 다를 수 있다」 | two armies, one with a fitted 팔, **different `damage_of`** | same `type_id` | `army.gd`: `damage_of` → `Rules.damage_of(int(type_id[i]))` — ⚠⚠ **this is THE row of the round** |
| 「부리는 사거리에 그대로 얹힌다」 | beak + head = base + 1.0 + 1.0 | — | `army.gd`: drop `Rules.BEAK_RANGE` from `range_of` |
| 「전투가 병사 숫자를 `Army` 에서 읽는다」 | drive a `Battle` with a fitted board: **DPS differs** | enemy numbers unchanged | `battle.gd`: `army.damage_of(i)` → `Rules.damage_of(st)` · `army.period_of(i)` → `Rules.period_of(st)` · `army.speed_of(i)` → `Rules.speed_of(int(army.type_id[i]))` — **three separate mutations, three separate rows** |
| ⚠ 「적 숫자는 종류에서 그대로 읽는다」 | a fitted board moves **nothing** about the enemies | — | `battle.gd`: `Rules.damage_of(et)` → `army.damage_of(e)` — ⚠ **the opposite direction, and without it a check that only watched the fight get faster would pass on an army whose parts leaked into the enemies** |
| 「슬롯 예비 병력은 슬롯으로 걸러진다」 | slot 0 sees only slot-0 bodies | ⚠ **build a THIRD slot bound to `CELL_MELEE` in a net-local table and assert the two do not share a body** | `battle.gd`: `army.slot_id[i] == slot` → `army.type_id[i] == want` |

### 8.2 `net_cards` — NEW (stage 4)

| Korean label | Floor | Ceiling | Mutation |
|---|---|---|---|
| 「이기면 카드가 여섯 장 나온다」 | `cards.size() == 6 × 2` | none taken | `run.gd`: delete the `_draw_cards()` call from `finish_island` |
| 「둘을 고르면 정비로 넘어간다」 | after 1 pick state is still `PICK` | after 2 it is `REFIT` | `run.gd`: `Rules.CARD_PICKS` → 1 |
| 「같은 카드를 두 번 못 고른다」 | second call returns false | pile size 1 | `run.gd`: drop the `cards_taken[k] == 0` clause |
| ⚠ 「고른 카드가 더미에 그대로 들어간다」 | pile part **and** species equal the card's | — | `run.gd`: `take_card` marks the card and does not call `loadout.take_card` |
| ⚠⚠ 「같은 씨앗이면 여섯 장이 똑같고, 씨앗이 다르면 어딘가 다르다」 | two runs, one seed → identical | **over 8 seeds, at least two draws differ** | `run.gd`: `_rng.randi_range(0, Rules.part_count() - 1)` → `0` — ⚠ **the ceiling is the half that catches a draw that always returns 머리** |
| ⚠ 「씨앗을 여럿 돌리면 부위 여섯과 종 셋이 전부 나온다」 | all 6 parts **and** all 3 species appear over 40 seeds | — | `run.gd`: `randi_range(0, Rules.species_count() - 1)` → `randi_range(0, 1)` |
| 「카드 여섯의 사각형이 안 겹치고 화면 안이다」 | inside `Rect2(0,0,1280,720)`, **literals** | no two hit rects intersect | `look.gd`: `CARD_GAP_PX` → 0.0 |
| 「판정 사각형이 그림보다 사방 8px 크다」 | hit ⊇ drawn | hit area ≤ drawn × 1.6 | `reward_view.gd`: make the hit rect the drawn rect |
| 「가장 작은 누름이 220×64보다 작지 않다」 | 280 ≥ 220 **and** 200 ≥ 64 | — | `look.gd`: `CARD_SIZE_PX := Vector2(280.0, 200.0)` → `Vector2(180.0, 60.0)` |
| ⚠ 「카드에 부위와 종이 둘 다 찍힌다」 | **two** text leaf calls per card, both non-empty | the species string is one of three | `reward_view.gd`: delete the `_paint_card_species` call |
| ⚠⚠ 「가져간 카드에 표가 그려진다」 | `_paint_taken_mark` fires **exactly twice** after two picks | its captured **alpha ≥ 0.8** and its radius > 0 | `reward_view.gd`: `mark.a = Look.PRESS_ALPHA_ON` → `mark.a = Look.PRESS_ALPHA_ON * 0.0` — ⚠⚠ **the exact mutation that stayed green four times on the map screen: the leaf was called, the colour was captured, and no row read it** |
| ⚠ 「고를 수 있는 카드와 못 고르는 카드의 알파가 3배 넘게 다르다」 | ratio ≥ 3.0, **read off the capture** | — | `look.gd`: `PRESS_ALPHA_OFF` → 0.9 |
| 「호버하면 테두리가 3에서 6으로 간다」 | delta ≥ 2.0 (snap floor) | ≤ 10 | `reward_view.gd`: `set_hover` → a bare `return` |
| 「누르면 0.96배로 눌렸다가 0.10초 뒤 돌아온다」 | scale < 1.0 at t = 0.05 | == 1.0 at t = 0.11 | `reward_view.gd`: `note_press` → a bare `return` |
| ⚠ 「안내 글이 몇 장 골랐는지 말한다」 | the string contains `0` before, `1` after one pick | — | `reward_view.gd`: hard-code the hint to 「둘을 고르세요」 |

### 8.3 `net_refit` — NEW (stages 5 and 6)

| Korean label | Floor | Ceiling | Mutation |
|---|---|---|---|
| 「처음엔 슬롯 띠만 보이고 칸은 안 보인다」 | `_paint_cell_box` fires **0** times at `open_slot == -1` | the strip's boxes fire `summon_slot_count()` times | `refit_view.gd`: draw the board unconditionally |
| ⚠ 「슬롯을 누르면 그 슬롯의 판이 열린다」 | after the press `open_slot == 0` | **and `_paint_cell_box` fires `part_count()` times** | `refit_view.gd`: `open_slot` → a bare `return` |
| ⚠ 「연 슬롯이 띠에서 밝고 나머지는 어둡다」 | ratio ≥ 3.0, **off the capture** | — | `refit_view.gd`: draw every strip box at `PRESS_ALPHA_ON` |
| 「판은 여섯 칸이고 겹치지 않고 화면 안이다」 | 6 **hit** rects inside `Rect2(0,0,1280,720)`, **literals** | ⚠ **no two hit rects come within 1 px of each other** — `Rect2.intersects` excludes borders by default, so two rects sharing an edge report no overlap and a press on the seam is legal for both. **The check measures the gap, not `intersects`** | `look.gd`: `REFIT_CELL_GAP_PX := 20.0` → `16.0` — ⚠ **the mutation is 16 and not 0, deliberately: 0 would be caught by any version of this row and 16 is only caught by the version that measures a distance** |
| 「가장 작은 누름이 220×64보다 작지 않다」 | cells 220×140, held rows 220×64 | — | `look.gd`: `REFIT_HELD_SIZE_PX := Vector2(220.0, 64.0)` → `Vector2(200.0, 48.0)` |
| ⚠⚠ 「더미 자리가 한 판에서 얻을 수 있는 부위 수보다 많다」 | `refit_held_capacity() >= CARD_PICKS × map_max_card_nodes_on_a_route()` | — | `look.gd`: `REFIT_HELD_ROWS := 5` → 2 — ⚠ **`panel_view.roster_ids` shipped this exact cap and its comment said it never bit** |
| 「더미의 부위를 누르면 그 부위의 칸에 들어간다」 | the cell's species == the card's | pile shrinks by exactly 1 | `game.gd`: `_refit_input`'s `fit` call → a no-op |
| ⚠ 「채워진 칸을 누르면 더미로 돌아온다」 | cell == -1 | pile grows by exactly 1 **and carries the same species** | `game.gd`: `_refit_input`'s `unfit` call → a no-op |
| ⚠ 「빈 칸을 눌러도 아무 일도 안 난다」 | pile unchanged | board unchanged | `loadout.gd`: make `unfit` return true on an empty cell |
| ⚠⚠ 「대시보드 다섯 숫자가 전투가 읽는 숫자와 같은 함수에서 나온다」 | each drawn value == `loadout.stat_of(slot, col)` | **and, as literals, an empty slot 0 reads 14 · 2 · 1.0 · 0 · 4** | `refit_view.gd`: `Look`-side formatting reads `Rules.hp_of(type)` instead — ⚠ **the two halves are both needed**: the first alone passes when both are wrong, the second alone passes when the view computes its own number correctly by accident |
| ⚠ 「부위를 끼우면 그 자리에서 숫자가 움직인다」 | the captured 체력 string changes 14 → 18 **within the same frame batch** | the other four strings are byte-identical | `refit_view.gd`: cache the dashboard values at `bind` |
| ⚠ 「미리보기 몸이 슬롯마다 다르다」 | slot 0 and slot 1 differ in **radius AND corner radius** | both radii > 0 | `look.gd`: `REFIT_BODY_SCALE` → 0.0 |
| 「완료를 누르면 지도로 간다」 | `run.state() == MAP` | `battle == null` | `game.gd`: `run.close_refit()` → a no-op |
| 「정비 중에는 패널이 안 뜬다」 | `panel_active() == false` in `PICK` **and** in `REFIT` | **true in `REWARD` and in `WON`** | ⚠ **both directions, or an allowlist that always returns false passes** |

### 8.4 `net_map` · `net_run` · `net_shell` — rewritten (stage 3, stages 4–6)

| Was / new | Becomes | Mutation |
|---|---|---|
| `net_map` 「상자 칸은 섬을 안 열고 그 자리에서 회복한다」 | **「모든 칸이 섬을 연다」** — every node's `map_island_of(n) >= 0` | `rules.gd`: `[3, NodeKind.FIGHT, Reward.COUNT, 0],` → `… , -1],` |
| `net_map` — new | **「칸 종류는 전투와 보스뿐이다」** — no node's kind is outside `{FIGHT, BOSS}` | `rules.gd`: give node 5 back a third kind |
| `net_map` — new | **「한 경로가 카드를 내는 칸을 넷 지난다」** — floor **and** ceiling 4 | `rules.gd`: delete edge `[3, 5]` |
| `net_run` 「런은 지도에서 시작한다」 | unchanged | — |
| `net_run` — new | **「이기면 카드 고르기로 가고, 고르고 나면 정비로 가고, 정비를 닫아야 지도다」** — all three transitions in one row | `run.gd`: move the `PICK` arm below the `MAP` arm in `_advance` |
| `net_run` — new | ⚠ **「경로가 다르면 명부가 다르다」** grows a second half: **the two routes' BOARDS differ too** after a fixed fit policy | `run.gd`: make `take_card` ignore its argument and always take card 0 |
| `net_shell` 「`_ready` 가 자식 **다섯**을 만들었다」 | **일곱** | `game.gd`: drop one `add_child` |
| `net_shell` — new | **「카드 화면에서는 섬이 안 그려진다」** — `game.battle == null` **and** `field_view.battle == null` | `game.gd`: delete `battle = null` from `_enter_pick_screen` |
| `net_shell` — new | **「카드 화면의 클릭이 카메라를 안 움직인다」** — `_panning == false` after a card press | `game.gd`: move the `PICK` branch below the `battle != null` block |
| `net_shell` — new | **「부리를 달고 나면 지도가 아니라 카드 화면이다」** | `game.gd`: `_release_hold`'s beak branch calls `_enter_map_screen()` directly |
| `net_islands` `_min_region_floor()` | the expression moves to the accessors, and **the literal self-check moves 20 → 23** (its sibling, the max roster, moves 19 → 22) | `rules.gd`: `[CELL_MELEE, 6, 2],` → `[CELL_MELEE, 6, 0],` — the floor must fall. ⚠ **This row said "the literal stays 20" until stage 3's node 5 was closed as `COUNT`; §4's row is where the arithmetic lives and this one points at it rather than restating it** |
| `net_draw_leaf` | five totals + two new per-function tables | ⚠ **A `func` line the table does not hold is red that day.** Both tables open in the SAME edit as the files |

### 8.5 The rest

| Net | What moves |
|---|---|
| `net_slots` | `Rules.START_MELEE` → `Rules.slot_start_count(0)`; `SUMMON_SLOTS.size() == 2` **stays a literal** (rows, not columns) |
| `net_summon` · `net_plan` · `net_shell` · `net_run` · `net_islands` | the fifteen `START_* / REWARD_*` sites → `roster_start_count()` / `roster_reward_count()`. ⚠ **Mechanical, and the risk is that a builder meeting fifteen surprise reds WEAKENS one instead.** Every one keeps its number |
| `net_battle` `net_boat` `net_coast` `net_camera` `net_fx` `net_fx_view` `net_citations` `net_title` `net_process` | ✅ **untouched.** If any reddens, the cause is a real regression — **do not adjust them to fit** |

**⚠⚠ The roster's new ceiling owes three checks, and one of them is not arithmetic.** Stage 3 lifts
`map_max_count_nodes_on_a_route()` 3 → 4 and the roster's ceiling 19 → 22 — see §4's two rows. A capacity
assertion on its own is two constants compared to each other and would stay green while `roster_ids`
truncated to nothing, so the third row drives the bodies.

| Check (label) | Net | Bound | ⚠ Named mutation — this label must redden |
|---|---|---|---|
| 「명단 정원이 한 판이 낼 수 있는 최대 병력을 담는다」 | `net_shell` | `Look.roster_capacity() >= Rules.roster_start_count() + Rules.map_max_count_nodes_on_a_route() * Rules.roster_reward_count()`. ⚠ **No clause about where the beak nodes sit** — the whole point is that the panel is correct for any node table | `look.gd`: `const ROSTER_ROWS := 11` → `const ROSTER_ROWS := 10` |
| 「그 최대가 22다 — 10 + 세포 칸 넷 × 3 (자가 점검)」 | `net_islands` | the **literal 22**, on one side only, beside the floor's **literal 23**. ⚠ Writing the formula on both sides lets the roster grow and the expectation grow with it — the shape that proves nothing, and the reason the existing row already carries its 20 as a literal | `rules.gd`: `[3, NodeKind.FIGHT, Reward.COUNT, 0],   # 5` → `[3, NodeKind.FIGHT, Reward.NONE,  0],   # 5` |
| ⚠ 「스물두 번째 병사도 명단에 있고 눌린다」 | `net_shell` | walk a run to a **22-body roster** and force `State.REWARD`, then `roster_ids().size() == 22` **and** `soldier_id_at(roster_rect_of(21).position + Vector2(4, 4)) == 22의 id` **and** `roster_rect_of(21)` lies inside the literal `Rect2(0, 0, 1280, 720)` | `panel_view.gd`: `if ids.size() >= Look.roster_capacity():` → `if ids.size() >= Look.roster_capacity() - 2:` |

⚠ **The third row is the floor and the first two are the ceiling.** Capacity ≥ demand is arithmetic over
two accessors; it cannot see the list itself coming back short, and **coming back short is the defect that
actually shipped last time.** ⚠ **It also needs the rect inside the viewport**: a row the panel "has" but
draws off screen answers `has_point` perfectly and is unclickable — `visible` is not "on screen".

### 8.6 ⚠⚠ Every check above was read against the four questions this repo's fake greens came from

| Question | Where it bit this plan |
|---|---|
| **(a) does the bound come from the thing it measures?** | The period floor is the **literal 0.2**, never `PART_STATS`' own sum. The dashboard row carries **literal 14 · 2 · 1.0 · 0 · 4** beside the same-function row. Every rect row asserts against **literal 1280 · 720** |
| **(b) does it read only final state where an ordering was promised?** | 「가슴을 두 번 끼우면 앞엣것이 더미로 돌아온다」 measures the **pile between the two writes**; the final board is identical either way. 「부위를 끼우면 그 자리에서 숫자가 움직인다」 reads the dashboard **mid-batch**, not after |
| **(c) does the spy assert everything it captures?** | The taken-mark row reads the **captured alpha and radius**, not the constants — four of seven leaves on the map screen were capturing a `Color` no row inspected. Every new leaf's captured colour has a row |
| **(d) can the behaviour VANISH rather than diverge?** | 「어떤 부위도 아무 숫자도 안 움직이지 않는다」 catches a part that exists and does nothing. The seed row's ceiling catches a draw that always returns 머리. The strip row asserts `_paint_cell_box` fires **zero** times on step one and `part_count()` times on step two — a count on both sides, so a board that never draws cannot pass as a board that is closed |

---

## 9. Acceptance

| Row | Closed by |
|---|---|
| ⚠⚠ **The card screen is operable without explanation** — someone told nothing wins a fight, sees six cards, and takes two | **USER ONLY.** Not a net, not a screenshot, not an agent clicking |
| ⚠⚠ **The refit screen is operable without explanation** — they press a slot, land a part, and know they landed it | **USER ONLY.** ⚠ **The two-step navigation is the risk**: a strip that reads as a list rather than as a door |
| **What presses is readable as a picture** — show either screen for 5s and have them point at everything pressable; pointing at something unpressable is a failure | **USER ONLY** |
| ⚠⚠ **Fitting a part visibly does something** — they fit one and say what changed **without being told where to look** | **USER ONLY.** ⚠ **"the dashboard number moved" does not pass this** — that is the claim, not the verdict. The design's own box says half of 「a cell became a creature」 is unmet on purpose this round |
| ⚠⚠ **The part reaches the fight** — the same board, played twice, produces a fight the user can tell apart | **USER ONLY**, with **PROBE** as the proxy (stage 7) |
| **A body that dies does not take the board with it** — they lose a soldier and the next one out of that slot still has the parts | **NET** (`net_parts`) for the rule, **USER** for the verdict |
| **The board is 3×2, one part per cell, and a part has one legal cell** | **NET** (`net_refit` · `net_parts`) |
| **Every hit target is on screen** — every card, cell, held row and button inside `Rect2(0,0,1280,720)`, against the literals | **NET** |
| **The glyph count did not grow past what the user already refused** — count the strings per screen and write the number down. Cards: 6 × 2 + 1 hint = **13**. Refit board: 6 cells × 2 + 5 labels + 5 values + up to 10 pile rows × 2 = **42** | **NET** for the count, **USER** for the verdict. ⚠⚠ **42 strings is the most this game has ever put on one screen**, and 「글자가 너무 많다」 is a verdict this user has already given once. The design records rule 8 as the user deliberately overturning their own constraint — **this row is where that gets tested** |
| **Adding a part is cheap** — the user adds a seventh part themselves and it shows up in a run, unassisted | **USER ONLY.** ⚠ Only passable because the cost is two files |
| ⚠ **Final verdict** — the user does not say 「애매하다」. **Every row above is a proxy** | **USER ONLY** |

⚠⚠ **What this round cannot be judged on, written down before it is felt.** With one part per cell, no set,
no cost and no multi-cell occupancy, **the board asks 「did you collect it」 and nothing else** — the pick of
two out of six is the only choice, and it is a choice between numbers. `parts-on-a-board-not-on-the-body`
records this as the price of seeing the screen turn first. ⇒ **When the board reads as flat, the answer is
multi-cell occupancy, which the user deferred and did not refute — not a new system.**

---

## 10. Screen — **what is on it, stage by stage**

| Stage | What a viewer sees that they could not see before |
|---|---|
| **1** | **Nothing.** No file under `src/view/` or `src/shell/` is touched |
| **2** | **Nothing.** Every board is empty, so every number is still its base. ⚠ **Two HP-bar denominators and one panel line change what they divide by and draw identically** — that is the point |
| **3** | The map's **diamond is gone**; floor 4 opens an island like every other node. The run is **four fights and a boss** |
| **4** | **A new screen after every win**: six cards, three across and two down, each carrying a part name and a species name in its own colour, a hint line counting the picks, and a mark on the two that were taken |
| **5** | **A second new screen**: a strip of two slot boxes; pressing one opens a 3×2 board of six labelled cells beside a pile of held parts and a preview of that slot's own body. A part presses into its cell and out of it |
| **6** | **Five numbers under the body**, and the one a part moves moves while the player watches |
| **7** | The cards **fade in one after another**, a landed part **flashes its cell**, and the dashboard number **climbs** rather than jumping |

⚠⚠ **The one thing that is NOT on screen this round and it is deliberate**: a fitted part never appears on
the body. 머리·가슴·배 are surface on a top-down body — the measurement that turned a generated lion into an
orange square — and whether the other three get a protruding form is an open drawing question in the design.
**The dashboard is carrying that alone.**

---

## 11. Presentation — stage 7

| When | What moves | The rule it says fired |
|---|---|---|
| The card screen opening | six cards fade in **0.06 s apart**, each over 0.18 s — the reveal stagger `look.gd` already carries for the map | The screen arrived; it was not always there |
| Hover on a card, a slot, a cell, a held row | border 3 → 6 px, +0.12 brightness over **0.10 s** | ⚠ **The only picture that says "this presses."** No hover reads as "does not press" |
| Press | **0.10 s** squash to 0.96×, −0.15 brightness | The press was accepted |
| A card taken | the mark grows over **0.20 s** and the other four dim to `PRESS_ALPHA_OFF` when the second is taken | ⚠ **Two channels, because alpha alone cannot tell "taken" from "no longer takeable"** |
| A part landing in a cell | the cell fills over **0.25 s** — `MAP_CLEAR_FILL_SEC`'s sibling | Something happened where the player pressed |
| The dashboard | the changed number **climbs over 0.60 s** — the 힘 readout's chase, reused | ⚠⚠ **Without the climb, fitting a part and not fitting it look identical on screen** |
| Screen changes | the existing **0.35 s** `SCENE_FADE_SEC` | A hard cut reads as a glitch |

⚠⚠ **Every one of these gets a FLOOR as well as a ceiling in its net row.** The last presentation round
found four beats bounded only above — *"never overlaps more than 6px"* with nothing saying *"is not always
zero"* — so **deleting the whole animation stayed green.**

---

## 12. Out of scope — **not built, and a stage that drifts into one of these is over**

**Set effects** (the code leaves room: `Loadout.bonus` is the one function a set term is added to, and no
consumer moves) · **any cost or economy number** · **multi-cell occupancy** · **artifacts** · **species
having any effect** — it is a label · **상점 and 엘리트 node types** · **방어력** — there is no defence
column and adding one is a combat change · **new terrain grids** — three still serve six nodes and that
temporary is `title-and-map`'s, not this round's · **the 세포연구소 permanent layer** · **saving, unlocks,
anything a run carries out** · **retuning `TIME_LIMITS`** · **`project.godot`**, whose `run/main_scene`
stays `res://src/shell/game.tscn`.

⚠ **And one thing that looks in scope and is not**: **a recovery rule to replace the chest.** The design's
still-open row fills it in as *ship it and measure*, and a fix invented before a wipe is observed is a fix
for a number nobody has taken. **The probe must actually be run in stage 7** — if a route wipes, that row is
the reason.

---

## Round log
