# Twelve pieces of combat juice

**Implemented**: full — all twelve, plus the lion's wind-up from section 0. ⚠ **Item 8 was relocated on 2026-08-18 by `plan-then-watch`**: its key half became the start button's chip family, its berth half is DELETED, and the whole `hud_view.gd` hook table below was re-measured (20 functions / 5 leaves → 13 / 3). Every other item is untouched — they are all view-side and driven by `Battle.events`, so deleting the controls killed none of them. The round is 12 nets / 1328 checks green
**Accepted**: **pass (2026-08-17)** — the user launched it, looked, and said *"연출은 좋아"* (the presentation is good)

⚠ **What was accepted is the presentation, not the game.** In the same breath the user went on:
*"but the game is a bit vague now. There's no feeling of **invading** at all. Maybe it's because it's 2D —
it just feels too simple. Though really, combat would be the same in 2D or 3D."* And, for the second time:
*"the boat still feels like a side-thing."*
⇒ **That sentence answers the 3D question itself** — if *combat would be the same in 2D or 3D*, then
**what is missing is not the dimension; it is that 「침공」— invading — does not read**, and the boat is the
thing that was meant to carry it.
⇒ **Next session's problem is the boat** (user: *"let's fix that next session"*).
The [GDD](cell-army-gdd.md) holds it as Undecided 15 · 16 · 17.

⚠ **One item is an exception.** After this doc was finished the user corrected item 2:
*"2번이 조금 다른데 이팩트가 있어야 할 듯. 맛있게 나가는"* — item 2 is a bit different, it needs an effect, one that goes out tastily.
⇒ **Item 2 is no longer "the body lunges" alone; it is two layers** — the body's motion (2①) plus
**a hit spark that bursts at the contact point on touch (2②).** C item 2 is that, and the two refutation
boxes under it work out **why shards and not an arc**, and **why it does not share a leaf with item 1.**
**This is a thing the user said, not an acceptance** — nobody has seen the screen yet.

**One line**: **the sim reports only what happened. Not one character of "for how long, and looking how" lives in `src/sim/`.**

---

## 0. ~~The one thing the user must answer before this is built~~ — **decided: yes** (user, 2026-08-17)

**All twelve get built. Nothing is left open.**

> ~~**Should the lion's first blow get a wind-up?**~~
> ⇒ **The user chose "yes".** `rules.gd` gains `LION_WINDUP_SEC` and `_phase_attacks` becomes
> **announce-then-fire**. What the user approved — *"the area is drawn first and then it goes off"* —
> gets built as approved.
> **The cost was chosen knowingly: the boss gets weaker.**

⚠ **That cost is currently closer to a gain than a price.** The probe swept the boss band and the army
**wins entering island 3 on 5% of its HP pool (12.0)** — there is no band at all. Weakening the lion
loses nothing from where this stands. ⚠ **This is a reason, not a balance plan** — why the boss cannot
be lost is held as an open item by the [GDD](cell-army-gdd.md), not here.

⚠ **Calling the after-the-fact ring "item 5" was the worst possible answer.** The user would accept it
believing they had seen a telegraph. Why a telegraph was impossible under the current rules is still
worked out in C, item 5 — **that arithmetic is the reason for this decision.**

---

## A. Why this doc exists

The user played the first vertical slice and said (2026-08-17):

> *"보이는 것 자체는 마음에 드는데, 조금 플레이적으로 조정이 필요하겠네"* — I like what I see, but it needs play adjustment
> *"원거리가 뭔가에 쏘는 연출 이런 게 다 필요할 거 같아. 지금은 너무 연출적으로 없어서"* — ranged needs a firing effect; right now there is nothing
> *"상대가 맞았을 때 뭔가 있어야 하고. 액션을 보는 맛이 있어야 돼. 패끼리 싸우는 맛"* — something has to happen when they get hit; watching the action has to taste like something, squad against squad

They picked twelve items in that conversation and **agreed to leave sound out**, because it needs assets and is a different kind of work.

⚠ **Out of scope — a later session must not open these from this doc.** In the same conversation the user also said the boats feel bolted on, the sea is cramped and the terrain reads like a single puzzle, and that they are wondering about 3D — **and then deferred all of it themselves**: *"이런 디테일 부분적인 건 빼고"*. Boats, level design and 3D are not this doc's subject. **Juice fixes none of that layer** — see H.

---

## B. How an event crosses from sim to view — the heart of this doc

### Chosen: **`Battle.events`, a one-frame list of facts**

`Battle` gains `var events: Array = []`. It holds **facts that happened inside `step()`** and holds **no duration, no colour and no pixel**. The view drains it every frame; it is cleared at the head of the next frame.

**There are exactly three kinds.**

| kind | payload | appended in |
|---|---|---|
| `ATTACK` | `from` (attacker id) · `from_enemy` (bool) · `to` (primary target) · `dmg` · `area` (tiles) · `splash` (indices actually damaged as secondaries) | `_hit_enemies` · `_hit_soldiers` |
| `DEATH` | `id` · `is_enemy` | `_phase_deaths` |
| `LAND` | `id` (soldier) — **and nothing else** | `_try_unload` |

**No position is carried.** `enemy_pos` and `soldier_pos` are not cleared on death and `army` never compacts a row (see its own "Never compact these arrays"). ⇒ **the view reads the spot straight off the id. The same value is not written in two places.**

⚠ **That rule is why `LAND` carries no tile.** The draft carried one and **it was ambiguous which**: inside `_try_unload` there is `boat["dock"]` (where the boat was sent) and `spots[k]` (where that soldier actually stands), and they differ. And `_try_unload` has already written `soldier_pos[sid] = _point_of_tile(spots[k])` **before** the append. ⇒ **the view reads `soldier_pos[id]` and the ambiguous field disappears.**

### The sim changes in **six** places and no more

1. `var events: Array = []` and `func begin_frame()` — one `events.clear()`
2. `_hit_enemies(from_id, primary, damage, area)` — **the attacker id becomes a leading parameter.** The side is already implied by which function it is: only soldiers hit enemies, only enemies hit soldiers
3. the same for `_hit_soldiers`
4. the two call sites in `_phase_attacks` pass `i` / `e`
5. one appended line each in `_phase_deaths` and `_try_unload`
6. **every driver that calls `step()` calls `begin_frame()` first** — below

### ⚠ Where it is cleared — the dead game lost two effects, 100%, right here

`step()` returns early when `outcome != RUNNING` or `dt <= 0.0`. So **clearing at the head of `step()` is wrong**: from the frame a panel opens, the last frame's events survive forever and the view replays them without end. Clearing at the tail of `step()` is also wrong: nobody ever sees them.

⇒ **`Battle.begin_frame()` is called by whoever calls `step()`, first, every frame.** There are three of them:

| driver | where the line goes |
|---|---|
| `src/shell/game.gd` | in `_process`, **right after the null guard and ahead of everything else** (pseudocode in C, item 10) |
| `tools/probe/run_run.gd` | inside `_play_island`'s `while`, immediately before `battle.step(DT)` |
| `net_fx.gd` · `net_battle.gd` · `net_boat.gd` | the same spot in every loop that steps |

⚠ **It cannot be pinned as "the first line of `_process`".** `game.gd`'s first line is `if run == null or battle == null: return`, and `battle.begin_frame()` on a null battle dies. **"After the null guard, before the `run.state()` check" is the exact spot.**

Frame order makes that safe. Godot dispatches **input → parent `_process` → child `_process`**, and `Game` is the parent of all three views. So on frame N the views read, and on frame N+1's head the list is cleared. And **feedback born of input (#8, #9) never travels through this list** — the shell pushes it into the view directly.

> **Refutation box — `events` gets no cap.**
> A review asked this doc to decide whether to cap `events` so that forgetting `begin_frame` cannot blow up. **It does not get one.** A cap does not fix the defect, it **makes it quiet**: the probe runs 1800 steps on island 3 and would pile up thousands of `ATTACK`s, and truncating at 256 leaves memory fine and **nobody feeling anything wrong.** The next person who forgets the call gets no signal at all.
> ⇒ **A net catches it instead**: `net_fx` runs 200 steps *calling* `begin_frame` and asserts `events.size()` never exceeds one frame's ceiling (6 enemies + 13 soldiers = 19), and removing the call makes that check bite. The view-side cap `FX_MAX_COUNT` is a different animal — it bounds the picture, not the list of facts.

### What the view owns

**An effect outlives a frame.** A 0.14s flash is nine frames at 60fps; the event is one frame long. ⇒ **the view keeps its own effect stores and its own clock.** `_process(delta)` ages entries and drops the dead ones.

There is **one reason and it is checkable in the code**: `game.gd`'s `_process` skips `step` whenever `run.state() != BATTLE` ⇒ **while a panel is up the sim is stopped dead.** Anything hanging off the sim clock freezes mid-animation behind the win screen. #4 (death) and #10 (transition) are precisely the effects that must play at that moment, so **a view clock is a requirement here, not a convenience.**

> **Refutation box — this decision does NOT reverse an older sentence in this repo.**
> An earlier draft of this paragraph opened with *"`lessons-from-two-dead-games` says «the view does not own a timer», and here the opposite is correct."* **That sentence is not in that file.** Sweeping all of `docs/`, `CLAUDE.md` and `.claude/` for "own a timer" / "own clock" / "자기 타이머" / "자기 시계" returns **nothing outside the two combat-juice files themselves.** The only line in lessons containing "timer" is *"growth that arrives on a timer is a notification, not a choice"* — nothing to do with juice. **Quoting a sentence that does not exist and then reversing it records a rule as reversed that was never held.**
> ⇒ The case for a view clock is the one `game.gd` line above, and that is enough.

**Two stores, not one.** With a single list, item 3's "one per body" rule and `FX_MAX_COUNT`'s "drop the oldest" eat each other.

| store | what lives there | size | on overflow |
|---|---|---|---|
| `_fx: Array` | things that pass through — `SHOT` (1) · **`SPARK` (2)** · `BURST` (4) · `AREA` (5) · `LAND` (7) | `FX_MAX_COUNT` **256** | the oldest are dropped |
| `_body: Dictionary` | things attached to a body — flash (3①) · flinch (3③) · lunge (2) · gait phase (12) · last frame's position | keyed `"e3"` / `"s7"`, so **bounded by the body count (19 max) by construction** | cannot overflow |

⚠ **`FX_MAX_COUNT` can never drop a body-attached effect.** That is why "drop the oldest" and "a body hit twice restarts its age rather than stacking" do not conflict — they are rules about different stores.

#### ⚠ `SPARK` is not bounded by the body count — it is **bounded by its lifetime**

`_body` is keyed by body, so 19 bounds it by construction. **A hit spark cannot use that argument**: several are born in one frame and none is attached to a body (the attacker retreats from its lunge, but the spark must stay where the two touched). So it lives in `_fx`, and **the reason it cannot overflow is not a cap but three lines of arithmetic.**

- **The most `SPARK`s born in one frame = the number of bodies that struck at range 0 that frame.** In `Rules.UNITS` only `CELL_MELEE`, `BISON` and `LION` have range 0. Melee soldiers are `START_MELEE` 6 + `REWARD_MELEE` 2 = **8**; melee enemies peak at island 2's **4** bison (island 1 also 4, island 3 is 2 bison + 1 lion = 3) ⇒ **12 at most**
- **One `SPARK` lives `LUNGE_SEC × 0.5` + `SPARK_SEC` = 0.09 + 0.12 = 0.21s**
- **The shortest gap before one attacker strikes again = the minimum period among those three types.** `Rules.UNITS`' `attack_period` gives `CELL_MELEE` **1.0** · `BISON` **2.0** · `LION` **1.5** ⇒ **1.0s**

⇒ inside a 0.21s window one attacker lands **exactly one** blow ⇒ **live `SPARK` ≤ 12.**
The general form is `melee attackers × ceil(lifetime ÷ minimum period)`, and reaching 24 would need **a period under 0.105s.**

⚠ **So `FX_MAX_COUNT` 256 is not a safety net where `SPARK` is concerned.** 12 is under 5% of it — and **calling an unreachable guard a guard means the next person believes it** (the same spot where item 6's cap of 12 came down to 8). **F measures 12, not 256.**

**The price is pinned instead: `field_view.setup()`, `hud_view.bind()` and `panel_view.bind()` must clear both of their stores.** Without it island 2 opens with island 1's explosions still on screen. **F carries a check that bites this** — today `setup` sits in the table at 0 and nothing measures what it resets.

### Do the twelve obey the one line?

| # | what the sim emits | what the view decides | does the sim know about the effect |
|---|---|---|---|
| 1 ranged shot | `ATTACK` where range > 0 | travel time, length, colour | no |
| 2 melee lunge | `ATTACK` where range == 0 | push distance and time · **shard count, reach, fan angle, when they fly** | no |
| 3 body hit | `ATTACK`'s `to` and `splash` | flash time, strength, knock px | no |
| 4 death | `DEATH` | burst time, growth factor | no |
| 5 area | `ATTACK`'s `area` | ring time, width | no |
| 6 target line | **nothing** — `enemy_target` is already public | alpha, width, when to draw none | no |
| 7 landing | `LAND` | ring time, radius | no |
| 8 press feedback | **nothing** — the shell forwards `commit()`'s bool into `note_chip(0, ok)` | response time, colour | no |
| 9 beak attach | **nothing** — the shell tells the panel first and calls `apply_beak` after the hold | tint time | no |
| 10 outcome | **nothing** — a shell hold plus the panel's own age | hold seconds, fade seconds | no |
| 11 camera | `ATTACK`'s `dmg` | amplitude, decay, frequencies | no |
| 12 gait | **nothing** — a `soldier_pos` difference | stride, squash | no |

**Five of the twelve touch the sim not at all.** `events` exists for the other seven.

⚠ **Item 9 lives by calling `Run` LATER, not by changing it.** See C item 9 — `run.apply_beak`'s signature and body are untouched. The only thing that changes is **when the shell calls it.**

### The candidates that were not chosen, one line each

- **Per-unit timestamp columns** (`enemy_last_hit_at` and friends) — `battle.gd` **deliberately lets one body be hit twice in one frame** (it damages targets already at 0 HP so that no attacker gets a free kill), and one column collapses those into one. It also cannot name the attacker. And `elapsed` resets to 0 per island, so an initial value of 0.0 makes **every unit flash on the island's first frame**
- **`signal`** — verified to work on a `RefCounted` in 4.7.1. Rejected because ① a listener runs **in the middle of `_phase_attacks`**, where deaths have not been applied yet ② `Battle` is rebuilt per island, so it must be reconnected each time and **forgetting produces no error at all, just a silently missing effect** ③ it creates a sim → view push, which inverts the arrow the folder contract is built on
- **The view diffing sim state** — the only option that edits no sim, but **who dealt the damage is not recoverable in principle and splash is invisible entirely.** And the moment the view holds a copy of sim state there are two sources of truth
- **Reading `_soldier_cd` / `_enemy_cd`** — GDScript has no access control so it works. Rejected for the reason written under item 5: **with no target the cooldown drains to 0 and stays there, so the lion's first blow has no countdown at all**

---

## C. The twelve specs

⚠ **Every number below is a first value to be re-measured, not a truth.** In the dead game the white flash was built at 0.09s, **was invisible, and doubled to 0.18**; the attacker's line at 0.08s was **under five frames at 60fps and the user never saw it once.** These are numbers of that kind.

**Every constant name lives in `look.gd`** — the values and their pixel conversions are written once, in E. **One tile is 40 canvas px.**

### ⚠ The real floor under pixel snapping is **2px**, not 3

> **Refutation box — this doc contradicted itself.**
> The earlier draft wrote *"under 3px nothing is visible at all"* in C item 3 and *"pixel snapping is on; under 2px is invisible"* on E's `HIT_KNOCK_PX` row — **the same claim as two different numbers**, neither derived. The arithmetic: `project.godot`'s `snap_2d_vertices_to_pixel` rounds each vertex to the **nearest whole canvas pixel**. A displacement `d` renders as `round(x+d) − round(x)`, so **`d < 0.5` is 0px at half the phases and can never exceed 1px, while `d ≥ 1.0` always moves at least 1px.** Reading as *motion* needs at least two steps, so the practical floor is **2.0 canvas px**.
> ⇒ **This doc specs no peak displacement below 2.0px.** `HIT_KNOCK_PX` 3.0 clears it. Item 12's amplitude was recomputed because of it — see there.

### 1. Ranged shot

- **What is seen**: one short tracer flies from the shooter to the target. Not the whole line — a segment `SHOT_LEN_PX` long sweeping from origin to destination. Drawing the whole line turns this into item 6
- **File / hook**: `field_view.gd` / **new leaf `_paint_shot(from, to, colour, width)`** (1 `draw_line`)
- **Seconds**: `SHOT_SEC` **0.10** — `CELL_RANGED`'s 4-tile range is 160px, so 1600px/s
- **Sim emits**: the `ATTACK` events whose attacker type has `Rules.range_of() > 0`
- **⚠ This effect lies about time.** The sim already applied the damage on the firing frame. So **item 3's flash is delayed by `SHOT_SEC`**: set `_body[key].flash` to `HIT_FLASH_SEC + SHOT_SEC` and **tint the body only while `flash <= HIT_FLASH_SEC`.** Without it the target flashes before the bullet arrives. **F carries two lines that measure this delay**
- **Both endpoints are frozen into the fx on the firing frame.** Re-reading `soldier_target` every frame bends the bullet onto **a different body** the instant the target dies and retargeting happens. The dead game held the line's length as a constant and **it ended in empty grass in one case and lay buried under the target's body in the other** — two failures in opposite directions, which is why any fixed length only fixes half
- **Layer**: **above** the bodies. See "Draw layers"

### 2. Melee lunge — **the body goes out, and the place it touched bursts**

⚠ **The user corrected this one item after the doc was finished**: *"2번이 조금 다른데 이팩트가 있어야 할 듯. 맛있게 나가는"*
⇒ **"squad against squad" does not live in the body going out; it lives in something appearing where they collided.**
So this item is **two layers**, and every line below states both.

- **What is seen**: ① the attacking body shoots toward its target and returns
  ② **at the instant the body is furthest out, six short shards spray sideways out of the seam where the two bodies meet — a fan on each side of the contact tangent**
- **File / hook**: `field_view.gd` / ① is **an offset added to the centre passed to the existing `_paint_body` — not a leaf**,
  ② is a **new leaf `_paint_spark(points, colour, width)`** (**1** `draw_multiline`) plus the pure function
  that builds those points, **`_spark_points(centre, facing, progress) -> PackedVector2Array`** (**0** draws).
  ⚠ **The point array is built in `_draw` and handed to the leaf as an argument** — built inside the leaf,
  the last inch does not close. `_beak_points` → `_paint_beak(tip, left, right, colour)` in the same file is
  the precedent; the arithmetic is in D
- **Seconds**: ① `LUNGE_SEC` **0.18**, **maximum at the halfway point, exactly 0 at both ends** — a body is never left displaced.
  ② starts **`LUNGE_SEC × 0.5` late** and lives `SPARK_SEC` **0.12** ⇒ the fx's whole life is **0.21s**.
  **The delay gets no constant of its own** — it is the moment the lunge peaks, a value ① already writes down.
  ⚠ **Without the delay the spark arrives before the body does**: on the striking frame the lunge is still 0, so it
  bursts in the empty gap between two bodies, and that reads as a telegraph rather than a collision
- **How far**: ① **`LUNGE_PUSH_RATIO` × its own radius**, capped so it never exceeds **`gap + LUNGE_BITE_PX`**, where `gap = centre distance on the firing frame − own radius − target radius`, floored at 0.
  ② out to `SPARK_REACH_PX` **18** from the contact point, `SPARK_COUNT` **6** shards (three per side of the
  tangent), each `SPARK_LEN_PX` **5** long, fan **half-angle** `SPARK_SPREAD_DEG` **12°** — **measured off the
  tangent axis**
- **How `progress` moves the geometry — without this line half of F's expectations are undefined.**
  At progress `p` one shard occupies from `max(0, SPARK_REACH_PX × p − SPARK_LEN_PX)` to
  `SPARK_REACH_PX × p` out from the contact point ⇒ **13 – 18px on the last frame.**
  **Alpha does not change over its life** — a fade on a 7.2-frame effect turns its last three or four frames
  into nothing, and those are half of it. ⚠ **The travel itself is what this effect rests on**:
  `18 ÷ 7.2` = **2.5px per frame**, above the **2.0px snap floor**
- **The contact point and the fan's direction**: **contact point = the firing frame's centre + `_facing_of` × (own radius + that blow's push)**.
  ⚠ **Why "plus the push" and not just "one radius out"**: the contact point is frozen on the firing frame, and
  **on that frame the lunge is still 0.** The spark is only seen `LUNGE_SEC × 0.5` later, with the body already
  `push` further out, so **it is that moment's body edge** that has to be frozen for the picture and the coordinate
  to agree. `push` is a value ① already fixes on the firing frame, so nothing new is computed.
  ⇒ **on the halfway frame `contact = the drawn body centre + _facing_of × own radius` holds exactly.**
  That identity is how a net recovers the contact point, and F measures with it.
  **The fan opens along the contact tangent (`_facing_of`'s perpendicular), on both sides** — the arithmetic
  is in the second refutation box below. **Opening it away from the target throws the shards back inside the
  attacker's own body**
- ⚠ **`_facing_of` gains one parameter — today it is soldier-only.** It reads `soldier_target`, `soldier_pos`
  and `enemy_pos`, but **two of the three range-0 types (bison, lion) are enemies.** ⇒
  **`_facing_of(i: int, is_enemy: bool)`**, reading `enemy_target[e]` (already public) and `is_hittable(tgt)`
  on the enemy side. **The sim is still untouched**, and since the name does not change **D's hook table
  (68 / 20) does not move either.** It is ripple 4 in D.
  ⚠ **`_beak_points`' call site goes along with it** — `_facing_of(i, false)`
- **Colour**: one `COL_SPARK`. **Not the attacker's colour** — a hit is an event, not an allegiance, and tying it to a
  side leaves the contact point between two sides with no defined answer
- **Sim emits**: for ① and ② alike, the `ATTACK`s whose attacker range is 0 — `CELL_MELEE` (0), `BISON` (2) and `LION` (4), **and only those three.** **The spark changes the sim by not one character**
- **Layer**: ① is the body itself (layers 7–8); ② is **above** the bodies — **the same layer 9 as the tracer**, below the burst ring (10). See the layer table. **The halo is at layer 5 (under the bodies), so the spark has to be above them or it slips under the two outlines**
- ⚠ **A shard can overlap a diagonal neighbour's body.** 18px along the tangent from the contact point is at
  least 28.6px from a diagonal tile's centre, which touches a lion's halo (radius 22, halo 29.7). **Layer 9
  means it is overlapped, never hidden** — left unspecified on purpose
- **⚠ ① is a draw offset, never `soldier_pos`.** The grid reserves the next tile to make "one body per tile" true, and `_within` reads positions directly. **A real position change makes a unit attack from where it is not standing, and changes who is inside whose reach** — the effect would be editing the sim, which is exactly what Swink's definition of polish forbids
- **⚠ ② freezes its contact point into the fx on the firing frame**, for item 1's reason: re-reading it each frame lets the shards' root follow the attacker as it returns from the lunge or dies
- **⚠ The *shape* — shards — has no developer statement from any shipped game.** What the user asked for is "an effect at the moment of contact", **not shards.** The only support is **two lines of arithmetic about this screen** (every point moves monotonically away from both centres; 2.5px of travel per frame), which puts it at the same grade as H item 7's unverified list. Do not promote it

> **Refutation box — the draft's `LUNGE_PUSH_PX 14` × `LUNGE_MUL [1.0, 0.6, 1.6, 0.8, 2.4]` put bodies inside each other, and two of its five slots were never read.**
> A melee unit has range 0 + `REACH_BONUS` 1.5, so it stops at most 1.5 tiles away, and the grid's one-body-per-tile rule means **the real separation is either 1 tile (40px) or a diagonal √2 tiles (56.6px).**
> At the worst case (40px) lion↔melee cell: radii 22 + 14 = **36px**, leaving a **4px** gap. The draft's lion lunge was **33.6px** — centre separation drops to 6.4px and **the lion's outline swallows its target whole.** The bison lunged 22.4px and **overlapped by 12.4px.**
> And slots 1 (ranged, 0.6) and 3 (crow, 0.8) **can never be read, because those types do not have range 0.** The draft printed exact pixel conversions for both — **nothing is more dangerous than a precise number attached to dead code.**
> ⇒ **The array is gone, replaced by "a ratio of one's own radius, clipped by an overlap ceiling."** Re-measured with the new values, the worst overlap is **exactly `LUNGE_BITE_PX` 6.0px for every type pair** — by construction. See E's table. 6px is not swallowing, it is **bumping**, and that is the taste the user asked for.

⚠ **That box's last sentence is now only half true.** The user afterwards corrected it — *"2번이 조금 다른데 이팩트가 있어야 할 듯"* — which means **the 6px bump is right but is not enough taste on its own.** The overlap arithmetic stands untouched; the only change is that **② is laid on top of it.**

> **Refutation box — a short arc (a slash line) was NOT chosen. "The body is only lines, it has no area" is what kills the arc.**
> There were two candidates — **one short arc** at the contact point, or **a few short shards** flying out of it. Both are not built.
> **The criterion is "what reads on a picture with no area", and this doc already measured that once**: item 3 abandoned the white tint for a **filled halo** because "a hollow body has no area for a tint to fill."
>
> **An arc stays at the contact point for its whole life. And that spot is the busiest 15px of the frame** — the attacker's 2px outline, the target's 2px outline, and **item 3②'s filled halo**, all there at once, and **that halo is raised by the very same blow.**
> The arithmetic: `contact ↔ target centre = 40 − (own radius + push)`, `target halo radius = HIT_HALO_MUL × target radius`. The worst orthogonal-neighbour (40px) pair is **melee cell → lion**: the contact point sits **18.3px** from the lion's centre while its halo is **29.7px** ⇒ **11.4px inside the halo.** A 2px arc on a disc filled with `COL_HIT_HALO` (white at alpha 0.35) does not read.
> ⚠ **And it would read on some pairs and not others** — melee cell → **crow** puts the contact point 4.8px outside the halo, where it shows fine. (⚠ **The draft named the bison here, and E's table gives that row +3.3, i.e. inside the halo, not −4.8.** Wrong pair; the point stands with the crow.) **An effect that appears for some pairings and vanishes for others is worse than no effect at all**, because the eye cannot tell which one is the truth.
>
> ⇒ **Shards do not stay at that spot. That is the only difference and it is the decisive one.** Over their 0.12s they travel from the contact point out to `SPARK_REACH_PX` at **2.5px a frame**, and **motion over a static disc reads even at half the contrast.**
> ⚠ **The draft's grounds — "the shards clear the halo" — have been withdrawn**; the refutation box below kills them with arithmetic, and even with the corrected fan the worst pair leaves the tip **6.9px inside** the target's halo.
> ⇒ **What kills the arc is the other two: it stands still for its whole life, and its readability changes with the pairing.** **A shard's travel does not change with the pairing** — the same 2.5px a frame in every combination.
> ⇒ **No arc is built. One leaf, one shape.** And this screen already has three kinds of arc (4, 5, 7), so a fourth adds no new kind at all.

> **Refutation box — "open the fan away from the target and the shards clear the halo" was wrong twice.
> 14.7px was a value for the shard's *tip*, and a −facing fan throws the shards back *inside* the attacker's own body.**
> ① **A tip value was applied to all ten points.** A shard is `SPARK_LEN_PX` long, so on the last frame it spans **13 – 18px** out, and **half the points `_spark_points` emits are the inner end (13px).** `18 × cos 35°` = 14.7 is **the tip only**; the inner end is `13 × cos 35°` = **10.65px** ⇒ **the draft's two F rows redden an implementation built exactly to spec.** Solving the real worst case (35°, ρ=13), the escape radius from the target's halo is `ρ² + 2 × 18.3 × ρ cos 35° = 29.7² − 18.3²` ⇒ ρ\* = **12.79px**, a margin of **0.21px** — **below the 2.0px snap floor this doc set.** **The check had been built on whichever end flattered it.**
> ② **And it missed the bigger one — only the target's halo was measured.** By construction the contact point is **inside the attacker's own halo**, at a depth of exactly `(HIT_HALO_MUL − 1) × own radius` = **4.9 · 5.6 · 7.7px**, with no exception in any pairing. A −facing fan opens from that point **back toward its own body**: `|X − drawn centre|² = r² + ρ² − 2ρr cos θ`, peaking at **10.4px** (melee cell), **10.4px** (bison) and **12.6px** (lion) ⇒ **all ten points land inside the attacker's own radius (14 · 16 · 22)** — drawn in the hollow interior of its own outline. That is not "the place they touched bursts", it is **"the striker's insides sparkle"**, and G has already proved the lion stays white underneath it.
> ⇒ **The fan was turned onto the tangent (`_facing_of`'s perpendicular), both sides.** That is **the only axis that increases the distance from both centres at once**, and narrowing the half-angle to **12°** makes `ρ ≥ 2 × max(own radius, contact distance) × sin 12°` hold even at the inner end of 13px (worst `2 × 22 × sin 12°` = **9.2 < 13**). The full arithmetic is E's "where the shards land" table and the two inequalities under it.
> ⇒ **And the escape claim is withdrawn.** Even on the tangent, the worst pair (melee cell → lion) leaves the tip **6.9px inside** the target's halo. **Two grounds remain: every point moves monotonically away from both centres, and the shard advances 2.5px a frame.**
> ⚠ **What this box changed is the axis, not a value.** Buying the escape by raising `SPARK_REACH_PX` was the alternative, and **carrying the inner end out past the lion's halo needs `SPARK_REACH_PX` at 31px — 78% of a tile** — at which point the shards walk into the neighbouring tile. **The value was unaffordable, so the axis moved.**

> **Refutation box — item 1 (the ranged impact) does NOT get the same shards. One leaf serving two items is one the nets cannot tell apart.**
> A reviewer will ask, so it is written first. **It does not. Three reasons.**
> ① **They are not the same event.** Melee puts **two** bodies at the contact point and there is a collision; ranged lands one 12px tracer with **one** body there. And **the ranged arrival beat is already occupied** — item 1's `SHOT_SEC`-delayed flash and halo light up at exactly that instant.
> ② **Sharing a leaf weakens a row in F.** This doc has already paid that price once, in a refutation box, for `_paint_ring` shared by 4, 5 and 7 — `FX_GAIN[4] = 0` did not bite, and one line had to become twelve. Keeping `_paint_spark` exclusive to item 2 means **`FX_GAIN[2] = 0` ⇒ `_paint_spark` called 0** bites as written. ⚠ **Half of this reason collapsed later** — `FX_GAIN` is a `const` Array and no net can set a slot to 0 (see F's `FX_GAIN` box). **The exclusive leaf is still right; the value now comes from F's other rows.**
> ③ What the user corrected is item 2. **Item 1's spec passed two adversarial reviews and closed.**
> ⚠ **If "the tracer just disappears" does turn out to bother the eye**, the move then is **not a new leaf but one more kind on `SPARK`** (`SPARK_MELEE` · `SPARK_SHOT`) — the same shape as `_paint_ring` serving three — and **the price is that item 2's `FX_GAIN` row weakens to "calls originating from that kind are 0"**, a price this doc has already put a number on. **The difference between paying it knowingly and unknowingly is this paragraph.**

### 3. The body being hit

- **What is seen**: three things at once — ① the body's colour mixes toward white ② a filled halo lights up **under** the body ③ the body flinches away from the attacker
- **File / hook**: `field_view.gd` / ① is the colour argument of the existing `_paint_body`, ③ is the centre offset, **only ② is a new leaf, `_paint_halo(centre, radius, colour)`** (1 filled `draw_circle`)
- **Seconds**: `HIT_FLASH_SEC` **0.14** · strength `HIT_FLASH_STRENGTH` **0.70** · flinch `HIT_KNOCK_SEC` **0.10** over `HIT_KNOCK_PX` **3.0**
- **Sim emits**: the `to` of an `ATTACK` plus everything in its `splash`
- **⚠ Without the halo this effect does not exist.** A body today is **a 2px outline plus a 3px centre dot**. **A tint has no area to fill on a hollow body** — mixing white repaints the 2px rim and nothing else, and in the dead game that is exactly why "there is no flash" was the verdict. The halo sits **beneath** the body at `HIT_HALO_MUL` times its radius
- **⚠ The halo's colour is `COL_HIT_HALO`, and the draft had no such name at all.** `_paint_halo` takes a
  colour argument and nothing said what to pass — **while both the argument that killed the arc and the
  argument that chose the shards stood on "a filled white disc."** The value is in E's colour table (white,
  alpha 0.35)
- **⚠ Strength 1.0 is not mixing, it is replacing**, and with several bodies hit at once *which* body was hit disappears
- **A body hit twice in one frame restarts its fx age; it does not stack one.** Stacking multiplies the halo alpha into white. **That is why the `_body` store is a Dictionary** — keyed by body, stacking is structurally impossible
- **Layer**: all halos are drawn **beneath every body**, in one pass of their own. See the table

### 4. Death

- **What is seen**: a ring grows and fades out where the body stood, in that body's own colour
- **File / hook**: `field_view.gd` / **new leaf `_paint_ring(centre, radius, colour, width)`** (1 `draw_arc`)
- **Seconds**: `BURST_SEC` **0.32**, starting at that body's radius and reaching `BURST_GROWTH` **2.2**×
- **Sim emits**: `DEATH`
- **The segment count is a file constant in `field_view.gd`, `RING_SEGMENTS` 24, and it does not go in `look.gd`** — same reason as `CORNER_SEGMENTS`: it decides whether an arc looks faceted, not what the player reads. **It must not be a parameter**: as one it only adds a row to `net_draw_leaf`'s unused-argument check and buys nothing
- **The position is free** — `enemy_pos` / `soldier_pos` survive the death
- **Layer**: **above everything.** Painted with the ground, a 10px burst is buried under a 22px lion
- **⚠ Today the last enemy's death cannot be seen at all.** On the frame the win latches, the shell opens the next island immediately. **Item 10's hold is this item's precondition** — without it this effect never plays once on island 1

### 5. The lion's area attack

- **What is seen**: a ring expands from the blast point out to the real area radius. The lion's `area` 1.5 tiles is **60px**; `CELL_RANGED` also has `area` 1.0 = **40px** — **nothing on screen currently says the ranged cell splashes at all**
- **File / hook**: `field_view.gd` / **`_paint_ring` reused** — same leaf as item 4, different colour, duration and layer
- **Seconds**: `AREA_RING_SEC` **0.25**, from `AREA_RING_START_RATIO` **0.4** out to 1.0
- **Sim emits**: `ATTACK` where `area > 0`; the ring is centred on `to`'s position
- **Layer**: **beneath** the bodies. This is a mark on the ground, not an event on top of a body
- **⚠ What the user approved was "the area is drawn FIRST and then it goes off", and this spec is not that.** Under the current rules **telegraphing the lion's first blow is structurally impossible**: in `_phase_attacks` the cooldown decrement comes **before** the target and reach tests, so while there is no target `_enemy_cd` drains to 0 and **sits there**. On the frame a soldier walks into reach: cooldown 0 → **instant**. Every blow after the first telegraphs for free, and **telegraphing some attacks is worse than telegraphing none** — Into the Breach's whole value comes from *every* attack being announced (**Justin Ma: *"We wanted to make something where every death felt like your own fault"*** — Game Developer's piece on its redesign). A real telegraph needs a wind-up state in `_phase_attacks`, and **that is a rules change that moves combat balance.**
  ⇒ **That is section 0's question, and the one item this doc could not close.** If the answer is "no", item 5 leaves the list of twelve

### 6. Target line

- **What is seen**: one line, **from an enemy to the soldier it is targeting.** Never from the soldiers' side
- **File / hook**: `field_view.gd` / **new leaf `_paint_target_line(from, to, colour, width)`** (1 `draw_line`)
- **Seconds**: none. It is a state readout
- **Sim emits**: **nothing.** `enemy_target` is already public
- **Layer**: above the docks, **beneath** the boats and bodies. A line crossing a body is the cloud Riot removed
- **⚠ This is the only one of the twelve that can be a net loss of readability.** Into the Breach does draw intent, but it is **turn-based with fewer than ten units**, and **neither TFT nor Bad North draws target lines at all.** They are another form of the *"cloud of visual effects and particles"* Riot explicitly removed
- **So it is narrowed two ways**: ① **enemies only** ② if living enemies exceed `TARGET_LINE_MAX_COUNT` ~~**8**~~ **14**, **draw none.** Alpha in `COL_TARGET_LINE` is 0.12

> **Refutation box — "forty lines at once" is impossible in this game, and a cap of 12 could never bite.**
> Counting `islands.gd`'s `ISLAND_ROWS`: **island 1 = 4 bison, island 2 = 2 crows + 4 bison = 6, island 3 = 2 crows + 2 bison + 1 lion = 5.** The line is drawn **from the enemy side only**, so **the on-screen maximum is 6.** The draft's "forty" was **inflated 6.7×**, and the judgement "this item can be a net loss of readability" was built on top of it. That is the shape this repo recorded as *"a radius of 8 reached the screen at 38px and a design argument was built on a number off by 4.8×."*
> **At six lines the net-loss judgement is itself in doubt** — the item stays (the user picked it), but **the cap of 12 was an unreachable safety net.** It is 8 now, and **8 does not bite on these three islands either** (max 6).
> ⇒ **F's check for it is a synthetic battle,** and that row says so. **Calling an unreachable guard a guard means the next person believes it.**
>
> ### ⚠ **Refuted 2026-08-18** — the box above's "it never bites" is overturned
>
> With the counts raised to **8 · 12 · 14** this constant **bites for the first time.** Islands 2 and 3
> draw **no** intent lines until 4 and 6 enemies are dead — the phase where the hand cannot move and
> reading is the whole activity. **Raised to 14.**
> ✅ **Both landed in code on 2026-08-18.** `islands.gd` now holds **8 · 12 · 14** (measured off the rows by
> `net_islands`' `EXPECT_SPAWNS`) and `look.gd` holds **`TARGET_LINE_MAX_COUNT := 14`**.
> ⚠ **14 is the largest island's count, so the guard is once again unreachable in play — deliberately.**
> Its job was never to fire; it is a ceiling on a screen nobody has yet had to read. `net_fx_view` therefore
> checks **both ends**: at exactly `TARGET_LINE_MAX_COUNT` enemies all of them draw (**this arm is a real
> island's opening, not a synthetic one**), and at one over, none do (**that arm is still synthetic and says
> so**). ⚠ **14 is a FIRST value and verify-look scores it** — if fourteen lines read as noise it comes down,
> and the measurement is recorded here.

### 7. Landing

- **What is seen**: the boat disappears and a ring spreads once under each soldier that stepped off
- **File / hook**: `field_view.gd` / **`_paint_ring` reused**
- **Seconds**: `LAND_RING_SEC` **0.40**, 0 out to `LAND_RING_R_PX` **20**
- **Sim emits**: one `LAND` per soldier; the position is read from `battle.soldier_pos[id]`
- **Layer**: same as item 5 — **beneath** the bodies
- **⚠ Five appear in one frame and they appear touching.** `_free_tiles_from` is a BFS from the dock, so **the five land on adjacent tiles.** The draft wrote *"the grid's one-body-per-tile rule keeps the rings from piling into each other"* and **that is false** — two 26px rings on a 40px grid overlap by 12px.
  ⇒ **The radius is 20.0 now. 20 × 2 = 40 = one tile, so two orthogonally adjacent rings meet exactly and never overlap.** A diagonal neighbour (56.6px) had room to spare already

### 8. Summon feedback

> #### ⚠⚠ Half of this item is dead — **the summon keys were deleted** (user, 2026-08-18)
>
> **Deciding that the hand does not move during combat removes the 1~5 keys entirely** ⇒ **there is no key
> to press, so there is no key-box accept/refuse feedback.** See `plan-then-watch`.
> ⚠ **The surviving half**: the rule that **the screen says "took" or "refused" immediately** is untouched.
> Only its carrier moves — onto **boat placement on the planning screen**, where dropping somewhere illegal
> must visibly refuse.
> ⚠⚠ **And something has to be relocated before this is deleted.** Through `_paint_key`, `net_shell` holds
> **`Look.COL_BUTTON` pinned as a literal** and **both ends of the refusal-shake bound** — precisely the
> floor-and-ceiling pair `CLAUDE.md` earned the hard way. **Deleting `_paint_key` deletes that
> measurement.** The hook table and constants below are **to be moved, not dropped.**

> ### ✅ **Relocated 2026-08-18, and the berth half is DELETED rather than renamed**
>
> `plan-then-watch` shipped. **The key boxes and the berths are both gone from `hud_view.gd`** — there
> are no 1/2 keys and there is no fleet to meter — and the SHAPE they drew (a pressable box with one word
> in it) survives as the **start button and the five speed chips**, which is why the leaf was renamed
> instead of deleted. The bullets below are the shipped ones. **`_paint_berth`, `_paint_load`,
> `note_launch`, `_berth_offset`, `berth_rect_px`, every `HUD_BERTH_*`, `COL_BERTH_EMPTY` and
> `BERTH_FX_SEC` do not exist.** The `Look.COL_BUTTON` literal and the refusal-shake pair the old box
> above worried about were **re-pinned in `net_shell`, not lost**: the colour onto `panel_view`'s message
> and button captures, and the shake onto the start button with **a ceiling added that never existed**
> (`shift.length() <= Look.REFUSE_SHAKE_PX + 0.01`).

- **What is seen**: the **start button** brightens toward `COL_WIN` when the commit took, and tints toward `COL_LOSE` and shakes sideways when it was refused (`boats` empty). **The speed chips carry no feedback of their own — the chip that is lit IS the feedback**
- **File / hook**: `hud_view.gd` / **the `bg`, `rect` and `at` of `_paint_button` (renamed from `_paint_key`). No new leaf**, and the same leaf draws the speed chips
- **⚠ The shake rides on `rect` AND on the text's `at`, with the same offset.** Shake the box alone and the label falls outside it; shake the label alone and the box stands still, which reads as nothing having moved
- **Seconds**: `CHIP_FX_SEC` **0.18**, refusal shake `REFUSE_SHAKE_PX` **4.0**. ⚠ **`_chip_offset` is `REFUSE_SHAKE_PX`'s only reader now** that `_berth_offset` is gone, so deleting the shake deletes the constant's last reader — which is why `net_shell` pins the amplitude at **both** ends
- **Sim emits**: **nothing.** `battle.commit()` already returns a bool; the shell keeps it and calls `hud_view.note_chip(0, ok)` on every start press. **Slot 0 is the start button and it is the only slot anything writes**
- ⚠ **The drawer is aged by `delta * _speed_scale`, not by `delta`** — the speed ladder moves the interval every duration here was budgeted against. `net_fx_view` drives the HUD at 6× and asserts the shake is back at exactly zero inside `CHIP_FX_SEC / 6` REAL seconds; **without that row the multiplier could be handed down and never used**
- **The reason for a refusal is not distinguished.** There are three (boat full, no reserve of that type, both docks on water) and one bool cannot separate them. **Turning the return into an enum disturbs existing checks in `net_battle` and `net_boat`** — this doc does not buy that
- **⚠ This is the one item with an outside number on it.** Swink's *Game Feel* puts real-time control's input-to-response window **under 100ms**. ⇒ **the screen must change on the frame the key is pressed, and that is measurable by a net.** (⚠ the research took that figure from three agreeing secondary sources, not from the book itself)

### 9. Beak attach

- **What is seen**: the picked roster row's **box colour (`bg`)** snaps to `COL_BEAK` and eases back to `COL_BUTTON` over `HOLD_BEAK_SEC`. And **there is time for it to be seen**
- **File / hook**: `panel_view.gd` / **the `bg` argument of the existing `_paint_roster_entry`. No new leaf.** New helpers `note_beak(id)` and `_entry_bg(entry_index, id)`
- **Seconds**: **`HOLD_BEAK_SEC` itself.** A separate `BEAK_FLASH_SEC` **has been removed** — the moment the two diverge, either the panel vanishes mid-tint or the screen sits blank for the leftover tenth of a second. **One concept, one constant**
- **Sim emits**: **nothing**

> **Refutation box — the draft's diagnosis and its prescription were both wrong, and its net check was green with the feature deleted.**
> Draft: *"`_click_panel` calls `_open_island()` right after `apply_beak`, so the panel is gone that same frame. Item 10's hold is a precondition here too."* **`_open_island()` is not the cause.**
> `run.gd`'s `apply_beak` **ends with `_advance()`**, and `_advance` sets `_state = State.BATTLE`. `panel_view.panel_active()` is `run.state() != Run.State.BATTLE`, and `_draw()`'s first line is `if not panel_active(): return`. ⇒ **however long the shell defers `_open_island()`, the panel stops drawing on that same frame.** The draft's shell hold plays item 9 for **zero frames.**
> The check was dead too: the draft measured *"after the pick, only that row's `_paint_roster_entry` colour differs"* — but `panel_view._draw()` **already** reads `a.has_beak[i] != 0` and paints that row `COL_BEAK`. ⇒ **that row differs even with `note_beak` deleted entirely.**
>
> ⇒ **New prescription: defer `apply_beak` past the hold. The sim is not edited by one character.**
> ```
> _click_panel(at):
>     if _hold_sec > 0.0: return          # a panel click does not take during a hold
>     picked = panel_view.soldier_id_at(at)
>     if picked >= 0:
>         panel_view.note_beak(picked)    # the view tints now
>         _pending_beak = picked          # the sim does not know yet
>         _hold_sec = Look.HOLD_BEAK_SEC  # run.state() is still REWARD ⇒ the panel keeps drawing
>         return
>     if panel_view.button_hit(at): run.restart(); _open_island()
> ```
> **This is a gain, not a side effect.** During the hold `army.has_beak[picked]` is **still 0**, so the only thing that can make that row differ is `note_beak` ⇒ **F's item-9 check becomes real.** Fixing one cause killed one fake net with it.

- **The weakest item of the twelve** — no developer statement from a shipped game was found for it (research: unverified). Its only support is this repo's own rule that a rare event is safe to draw loudly

### 10. Outcome transition

- **What is seen**: after the verdict the screen **stays put for a moment** and then the panel rises from alpha 0
- **File / hook**: `game.gd` + `panel_view.gd` / **the colour argument of the existing `_paint_panel`. No new leaf**
- **Seconds**: `HOLD_OUTCOME_SEC` **0.80** · `HOLD_BEAK_SEC` **0.50** · `PANEL_FADE_SEC` **0.25**
- **Sim emits**: **nothing.** The shell gains one `var _hold_sec: float` and one `var _pending_beak: int`
- **⚠ This is the precondition for items 4 and 9, and what is missing today is time itself.** Island 1's reward has nothing to click, so `finish_island → _advance → _open_island → field_view.setup(new battle)` all happens **inside one frame**
- **While the panel is up the sim is stopped but the view's stores keep flowing** — this line is why B chose a view clock
- **Do not cover with full alpha.** The fade itself is what reads as "a moment is passing"
- **The fade's age is measured by `panel_view` itself**: `_fx_step` holds the age at 0 while `panel_active()` is false and accumulates while it is true. The shell never has to push "start now"

**The shell's pseudocode — build exactly this.**

```
var _hold_sec := 0.0
var _pending_beak := -1

func _process(delta):
    if run == null or battle == null: return
    battle.begin_frame()                      # B. After the null guard, ahead of everything else
    if _hold_sec > 0.0:
        _hold_sec = maxf(0.0, _hold_sec - delta)
        if _hold_sec <= 0.0: _release_hold()
        return                                # no step, no run advance
    if run.state() != Run.State.BATTLE: return
    battle.step(delta)
    if battle.outcome() != Battle.Outcome.RUNNING:
        _hold_sec = Look.HOLD_OUTCOME_SEC     # replaces the `_close_island()` that stood here

func _release_hold():
    if _pending_beak >= 0:
        run.apply_beak(_pending_beak); _pending_beak = -1; _open_island(); return
    _close_island()

func _unhandled_input(event):
    if _hold_sec > 0.0: return                # one line stops keys, dock clicks and panel clicks alike
    ...
```

⚠ **What leaks without that one line**: during an outcome hold `finish_island` has not been called yet, so **`run.state()` is still `BATTLE`.** `_on_key`'s guard and `_click_dock` both read that state and let the input through ⇒ **1 and 2 keep working for 0.8s on an island already won, and a boat `launch` creates cannot move because `step` is not running, so `_close_island` throws it away.** Rather than re-testing the state in three places, the entrance is closed once.

⚠ **`_hold_sec` can never be armed twice.** While it is held `step` is not called, so the outcome cannot be seen again, and `_release_hold` closes the island or attaches the beak on that same frame.

### 11. Camera

- **What is seen**: the bigger the hit, the harder the screen shakes
- **File / hook**: `field_view.gd` / **its `position` is shaken. No new leaf**
- **Seconds**: exactly 0 at `SHAKE_SEC` **0.30**. Amplitude = `dmg` × `SHAKE_PER_DAMAGE_PX` **1.2**, capped at `SHAKE_MAX_PX` **6.0**. The offset is `sin(t × SHAKE_A_FREQ)` and `sin(t × SHAKE_B_FREQ)` — **randomness cannot be measured by a net**
- **Sim emits**: the `dmg` of an `ATTACK`. Damage 2 → 2.4px, the lion's 4 → 4.8px. **If strength does not scale with damage, half of this effect is dead**
- **⚠ There is no `Camera2D` in the tree, and do not add one.** `game.gd`'s `_click_dock` hit-tests canvas pixels against `Look.tile_rect_px()`. Adding a camera makes **that arithmetic wrong across the entire screen at once**, and every px comment in `look.gd` becomes silently false. `Look.CAMERA_ZOOM` is read by nobody today
- **⚠ Assignment, never `+=`.** In the dead game `+=` became the basis of the next frame's lerp and **accumulated roughly 9×**, with a 28px cap stopping nothing: 67.9px at 60fps, 160.4px at 144fps. **Keep the unshaken position separately and assign**
- **⚠ The grid fills the screen exactly, so shaking exposes empty bands at the edges.** The fix: widen `_draw`'s terrain loop by `WATER_MARGIN_TILES` **1**. **It reuses the existing `_paint_tile`, so the hook table does not move** (34 × 20 = **680** tiles, up from 576). **Tiles outside the grid are handed `Look.COL_WATER` directly** — `terrain_colour_of_char` takes a legend character, there is no legend outside the grid, and inventing one would put `islands.gd`'s legend in two places
- **HUD and panel do not shake** — they are siblings

> **Refutation box — the draft's "input is unaffected" was true about the code path and false about the finger.**
> `_click_dock` hit-tests absolute canvas coordinates with `Look.tile_rect_px(...).has_point(at)`. Shaking `field_view.position` does not move that rectangle — **but it moves the dock that is drawn by up to `SHAKE_MAX_PX` 6px.** On a 40px tile that is **15% at the edge**, 12px across both sides, split between a band that is visible but unclickable and a band that is clickable but invisible. **The very argument given for not adding a camera applies to the shake.**
> ⇒ **Correct it. One line**: `_click_dock` tests `at - field_view.position`. `position` *is* the assigned shake offset, so it is exact and needs no new function and no new argument.
> **F measures that one line** — click the centre of the dock rectangle *as drawn* on a shaken frame and see whether `launch` takes.

### 12. Gait

- **What is seen**: the body **compresses along its direction of travel and spreads across it.** **The phase advances with distance covered, not with time** ⇒ a body that is not moving does not move. That is the whole of "not sliding"
- **File / hook**: `field_view.gd` / **one `squash: Vector2` parameter is added to `_paint_body` and `_rounded_square`. No new leaf; no name and no count in the hook table changes**
- **Seconds**: none. One cycle per `GAIT_PERIOD_TILES` **0.7** (= 28px), amplitude `GAIT_SQUASH` **0.20**
- **Sim emits**: **nothing.** The view keeps last frame's positions in the `_body` store and accumulates `distance_to`
- **Definition of the squash**: `1 − s·sin(φ)` along the travel axis, `1 + s·sin(φ)` across it. `_rounded_square` scales each vertex on those two axes

> **Refutation box — the draft specced a directional squash through a single scalar radius, and its amplitude was under the floor the same doc set.**
> The real signature is `_paint_body(centre, radius: float, corner: float, ...)`, and `_rounded_square(centre, radius: float, corner: float)` inside it is a scalar too. **One float cannot express different compression on x and y.** The draft's own E-table conversion — *"a 14px body reads between 12.3 and 15.7px"* — describes **a directionless uniform pulse**, not "squashes along its direction of travel."
> And 0.12 against the real radii gives **1.68 · 1.34 · 1.92 · 1.20 · 2.64 px** — five out of five at or under the **2.0px** floor set above. H item 7 already recorded this item as *unverified* for want of any shipped-game statement; **with an invisible amplitude on top of that there is no reason to build it at all.**
> ⇒ **A `squash: Vector2` parameter was added and the amplitude raised to 0.20.** On the smallest body (the crow, 10px) `0.20 × 10 = 2.0px`, exactly on the floor; melee cell 14px → 2.8px; lion 22px → 4.4px.
> **This parameter does not move D's hook table, but `net_shell`'s `FieldSpy._paint_body` override MUST follow the same signature** — an override whose signature drifts simply stops overriding, silently. It is in D's ripple list.
- **The weakest external support of the twelve** — no developer statement from any shipped game was found for it (research: unverified), and it is not on Vlambeer's list either

---

## C-2. Draw layers — the order of one `field_view._draw()` pass

⚠ **The draft had no such table and an implementer stops dead here.** Item 3 said the halo goes "under the body" and item 4 said the burst goes "above every body"; the other six had no layer at all. Today `_draw` is a **single pass** — terrain → docks → boats → enemies → soldiers — so "walk `_fx` more than once" is itself a decision that has to be written down.

> ### ⚠ Rewritten by `boat-and-landing` (2026-08-18) — **this table is the current tree**
>
> `_paint_boat` **no longer exists**; the boat is `_paint_hull`. Three layers were inserted and the
> terrain count moved. **The pre-boat order is in git, not here** — a layer table that describes a tree
> nobody is running is not history, it is a wrong instruction. **Section D below is the opposite case
> and is deliberately left as written.**

| layer | what | hook | why here |
|---|---|---|---|
| 1 | terrain (**2436** tiles, 58 × 42, water margin **5** included) | `_paint_tile` | the ground |
| 1b | **cliff faces** | `_paint_cliff_face` | a line along a cliff tile's seaward edge, so height reads in 2D |
| 2 | harbours | `_paint_dock` | above terrain, below events. ⚠ **The hook kept its name and the thing it draws did not** — harbours replaced docks |
| 2c | **idle hulls, each at the harbour its boat is actually sitting at** | `_paint_hull` | part of the ground until it sails |
| 2b | **the drag overlay and its route** | `_paint_overlay` · `_paint_route` | over the ground it describes, under everything that moves. **Drawn after 2c on purpose** — the overlay must not be hidden by the hull you are dragging |
| 3 | **6 target lines** | `_paint_target_line` | crossing a body is what turns it into the cloud |
| 4 | **5 area rings · 7 landing rings** | `_paint_ring` | these are marks on the ground |
| 5 | **3② halos (every hit body)** | `_paint_halo` | must be under **every** body, so it is its own pass ahead of them |
| 6 | **boats at sea: the hull, the destination route, and the passengers aboard** | `_paint_hull` · `_paint_route` · `_paint_body` · `_paint_hp` | ⚠ **the passengers are drawn now**, which is what finally lets item 3's flash and flinch paint at sea |
| 7 | enemy bodies + HP | `_paint_body` · `_paint_hp` | |
| 8 | soldier bodies + beaks + HP | `_paint_body` · `_paint_beak` · `_paint_hp` | an ally on the same tile reads on top (existing rule) |
| 9 | **1 tracers** | `_paint_shot` | a bullet passes over bodies |
| 9 | **2② hit sparks** | `_paint_spark` | **the halo (layer 5) is under the bodies, so the spark must be over them** — below |
| 10 | **4 burst rings** | `_paint_ring` | a 10px burst must not be buried under a 22px lion |

⚠ **The spark is above the bodies because of layer 5, not because of taste.** Its whole reason to exist is that "a 2px line does not read on a filled halo" — and putting it **under** the bodies, while still above the layer-5 halo, drops it beneath **the struck body's 2px outline and the attacker's**, and the contact point is by definition between those two lines. **A layer that puts the thing back underneath what it was made to escape is no layer at all.** It shares layer 9 with the tracer and their order is left unpinned because they cannot collide: item 1 is ranged and item 2 is range 0, so **one blow can never emit both.**

⇒ **the two stores are walked five times a frame** — `_fx` **four** times (layer 4, layer 9's tracer, layer 9's sparks, layer 10) and `_body` **once** (layer 5). **That four, and what it costs, belongs to G as "256 calls × 4 passes"** — the number is not written in two places.

**A count that changes every frame is solved with a loop inside `_draw`.** Terrain already loops `_paint_tile` 680 times; the new leaves are the same shape. **`_draw`'s own draw count is still 0.**

### ⚠ The body offset rides on one `centre` and propagates to the beak and the HP bar

`_hp_rects(centre, ...)` and `_beak_points(scentre, ...)` are **computed from the same `centre`.**
⇒ **add the lunge (2) and flinch (3③) offsets to `centre` once, then hand that value to all four** — `_paint_body`, `_paint_halo`, `_beak_points`, `_hp_rects`.

**Otherwise the body lunges out and the beak and HP bar stay behind.** And **`net_draw_leaf` can never catch that** — per-function draw counts and argument usage are all unchanged. F measures it.

The computation lives in one place: `_body_offset_of(key) = _lunge_offset(key) + _knock_offset(key)`.

⚠ **The spark (2②) alone does not ride that `centre`.** It is a coordinate frozen into `_fx`, because **the spark must stay where the two touched even after the attacker returns from its lunge or dies** — the same rule item 1 uses for its endpoints. **That is why the spark lives in `_fx` and not in `_body`** (B's store table).

---

## D. The whole hook table

> ### ⚠⚠ Superseded in part by `boat-and-landing` (2026-08-18) — **and kept as written on purpose**
>
> **`net_draw_leaf._table()` is the authority. This section is not, and was not even when it shipped.**
> What changed underneath it:
>
> - **`_paint_boat` was deleted.** The boat is **`_paint_hull` (2 draws)** — a hull sized from the
>   boat's capacity, with its passengers drawn on deck as real bodies.
> - **Four leaves were added** on top of juice's eleven: `_paint_hull` · `_paint_overlay` ·
>   `_paint_route` · `_paint_cliff_face`.
> - **The totals moved from 68 / 20 to 84 functions (43 + 20 + 21) and 23 leaves (14 + 5 + 4).**
>   ⚠ **And again on 2026-08-18** — `plan-then-watch` cut `hud_view` to 13 and 3, so the totals are
>   **77 functions (43 + 13 + 21) and 21 leaves (14 + 3 + 4)**. `field_view`'s 43 did not move while
>   one function was added, one deleted and one renamed, **which is why it is the one to re-derive by
>   hand.**
> - Nine pure functions came with the camera and the drag (`_compose_position` · `screen_to_world_px` ·
>   `world_to_tile` · `pan_by` · `zoom_at` · `_clamp_cam` · `_visible_world_rect` · `set_drag` ·
>   `idle_hull_rect`), all at 0 draws — **and 0 is as load-bearing as a leaf's count**, because it is
>   what forbids a draw call leaking out of a hook.
> - The terrain pass paints **2436 tiles (58 × 42)**: the grid is 48 × 32 and `WATER_MARGIN_TILES` is 5.
>   ⚠ **Re-measured 2026-08-18**: `plan-then-watch` pulled `ZOOM_MIN` back to 0.45 for the plan screen, which
>   exposes 11.6 tiles of bare ground on the x axis, so the margin went **5 → 12** and the pass paints
>   **4032 tiles (72 × 56)** — **8064 draw calls a frame**, up from 4872.
>
> ⚠ **The table and the ripple list below are left unedited, and that is deliberate.** They are the
> record of what *this* feature's build had to do, and they were correct instructions for the build
> that ran. Rewriting them to today's tree would falsify a build that already happened, and it would
> put the hook table in a fourth place. **C-2 above is the opposite case** — a layer table is a claim
> about the tree that is running, so it was rewritten rather than annotated.

⚠ **`net_draw_leaf` is a closed class.** It walks **every `func` line** in the three view files and reddens on any name the table does not hold. **So the existing functions are restated in full.** Bold rows are new.

### `src/view/field_view.gd` — 29 functions, 11 leaves

**The `field_view.gd` in the tree today has 15 functions** (`setup` through `_rounded_square`). This table **adds 14.**

| function | draw | function | draw |
|---|---|---|---|
| `setup` | 0 | `_tile_xy` | 0 |
| `_process` | 0 | `_boat_rect` | 0 |
| `_draw` | 0 | `_hp_rects` | 0 |
| `_paint_tile` | 2 | `_beak_points` | 0 |
| `_paint_dock` | 1 | `_facing_of` | 0 |
| `_paint_body` | 2 | `_rounded_square` | 0 |
| `_paint_beak` | 1 | **`_drain_events`** | **0** |
| `_paint_hp` | 2 | **`_fx_step`** | **0** |
| ~~`_paint_boat`~~ **→ `_paint_hull`, 2** | ~~1~~ | **`_shake_offset`** | **0** |
| **`_paint_shot`** | **1** | **`_body_offset_of`** | **0** |
| **`_paint_halo`** | **1** | **`_lunge_offset`** | **0** |
| **`_paint_ring`** | **1** | **`_knock_offset`** | **0** |
| **`_paint_target_line`** | **1** | **`_flash_of`** | **0** |
| **`_paint_spark`** | **1** | **`_gait_squash`** | **0** |
| | | **`_spark_points`** | **0** |

⚠ **`_paint_spark`'s `draw_multiline` draws all six shards in one call** — raising `SPARK_COUNT` never moves a number in this table.

⚠ **But building the geometry *inside* the leaf leaves the last inch unlocked, and that is exactly what the draft did.** A spy captures a hook's arguments, and the point array never leaves the leaf — and **`net_draw_leaf._scan`'s unused-argument check skips `_spark_points` entirely, because of `if want <= 0: continue`.** ⇒ one line of `var pts := _spark_points(centre, dir, progress)` followed by `draw_multiline(PackedVector2Array(), colour, ...)` is **green at 1 draw and 4/4 arguments used**, with zero shards on screen. **Measuring a pure function is not measuring that anything calls it.**
⇒ **Build the points in `_draw` and hand them to the leaf as an argument.** `_beak_points` → `_paint_beak(tip, left, right, colour)` in the same file is the precedent, and **no name and no count in the hook table moves.** The spy then captures the array itself and really measures **length, distance, fan axis and travel**, and the leaf becomes one line, `draw_multiline(points, colour, width)`, closing the argument chain to its end.
⚠ **`SPARK_WIDTH_PX` only becomes measurable then** — the three line leaves (`_paint_shot`, `_paint_ring`, `_paint_target_line`) all take a width argument, and **the draft's `_paint_spark` was the only one that did not, so no row in F bit it.**

### `src/view/hud_view.gd` — 13 functions, 3 leaves

⚠ **Re-measured 2026-08-18 for `plan-then-watch`, which cut this file hardest — 20 functions and 5 leaves
became 13 and 3.** Eight names died with the 1/2 keys and the berths (`key_slot_count`, `key_type_of`,
`reserve_count`, `boat_label`, `note_launch`, `_berth_offset`, `_paint_berth`, `_paint_load`), one arrived
(`set_speed`), and four were renamed into the chip family (`note_key`→`note_chip`,
`_key_offset`→`_chip_offset`, `_key_colour`→`_chip_colour`, `_paint_key`→`_paint_button`).
**`net_draw_leaf._table()` is the authority and these are its names.**

| function | draw | function | draw |
|---|---|---|---|
| `default_font` | 0 | `_paint_timer` | 1 |
| `type_label` | 0 | **`_paint_button`** | **2** |
| `bind` | 0 | `_paint_enemies_left` | 1 |
| **`set_speed`** | **0** | | |
| `_process` | 0 | | |
| `_draw` | 0 | | |
| **`note_chip`** | **0** | | |
| **`_fx_step`** | **0** | | |
| **`_chip_offset`** | **0** | | |
| **`_chip_colour`** | **0** | | |

### `src/view/panel_view.gd` — 21 functions, 4 leaves

| function | draw | function | draw |
|---|---|---|---|
| `bind` | 0 | `_paint_panel` | 1 |
| `panel_active` | 0 | `_paint_message` | 2 |
| `is_reward` | 0 | `_paint_roster_entry` | 2 |
| `is_finished` | 0 | `_paint_button` | 2 |
| `roster_ids` | 0 | `_entry_text` | 0 |
| `roster_rect_of` | 0 | `_message_text` | 0 |
| `soldier_id_at` | 0 | `_message_colour` | 0 |
| `button_rect` | 0 | **`note_beak`** | **0** |
| `button_hit` | 0 | **`_fx_step`** | **0** |
| `_process` | 0 | **`_entry_bg`** | **0** |
| `_draw` | 0 | | |

### What moves with this table — **twelve places**

1. `net_draw_leaf.gd`'s `_table()` — all three dictionaries above
2. the two totals in the same file: **68 functions (29 + 18 + 21)** and **20 leaves (11 + 5 + 4)**. **The numbers and the label text both** (today they are 46 / 15)
3. `net_shell.gd`'s three spy classes must **override every new hook.** Otherwise the spy calls the real hook and **actual `draw_*` calls run headless — silently.** The new arrays also belong in the `*.clear()` list at the head of each spy's `_draw()`, or a check reads more than one frame's worth. ⚠ **`_paint_spark` is on that list too** — give `FieldSpy` a `sparks` array and clear it at the head of `_draw`. **`_spark_points` is NOT overridden**: it is a pure function that draws nothing, and its check is that the net calls **the real implementation** at `progress` 0.25 and 0.75 and measures the growth
4. **Two signatures widen, and the hook table does not move because it reads names only (68 / 20 stands).**
   ① **`_paint_body` and `FieldSpy._paint_body` gain `squash: Vector2`** (item 12) — an override whose
   signature drifts silently stops overriding. ② **`_facing_of` gains `is_enemy: bool`** (item 2) — it reads
   `soldier_*` only today and **two of the three range-0 types are enemies.** `_beak_points`' call site goes
   with it, as `_facing_of(i, false)`
5. **`net_shell.gd`'s two "576 tiles were all drawn" assertions** (the battle screen and the new island after the beak pick) become `(Look.GRID_W + 2 * Look.WATER_MARGIN_TILES) * (Look.GRID_H + 2 * Look.WATER_MARGIN_TILES)` = **680**
6. **The margin tiles must NOT go into `net_shell._rects_land_on_screen`.** `Look.tile_rect_px(-1, -1)` is `Rect2(-40, -40, 40, 40)`, so **all 68 margin tiles break "everything lands inside 1280x720."** ⇒ **feed only the 576 inside-grid tiles to that list.** Widening the screen rectangle itself would kill the same check for docks, HP bars and the HUD, and that check is what catches a layout walking off the screen
7. **All three view files' `_process(_delta)` become `delta`** — not just `field_view` and `panel_view`. This table gives `hud_view` a `_fx_step` too, and item 8 gives it `CHIP_FX_SEC` (⚠ **the draft also named `BERTH_FX_SEC`; it is deleted — see item 8**). **The function names do not change, so the table does not move**
8. **All three view files' header comments.** In particular `field_view.gd`'s *"every `draw_*` call in the file lives inside one of those **six hooks**"* — with **eleven** leaves that sentence is false. ⚠ **That file's header says "six" in two places** (*"one of those six hooks"* and *"outside the six hooks"*). **Fix one and the other stays a lie into the next round**
9. **`look.gd`'s own header comment restates the suffix list in full.** F widens that list, so the two diverge. ⇒ **the better fix: delete the list from that comment and point at `net_draw_leaf`'s `_literal_hits` instead.** Never state the same thing twice
10. **`first-slice`, section 6's hook table.** ⚠ **That table was already rotted independently of this doc** — its `hud_view.gd` row omitted `_paint_load` and its `panel_view.gd` row omitted `_paint_message`. **It was fixed while writing this doc** (2026-08-17). A table in four places diverges four times
11. **There are still exactly three view files.** Do not add a fourth; two `3`s in `net_draw_leaf` move with it if you do
12. `_draw()` is pinned at **0 in all three files.** New juice is either a `_paint_*` hook or a bump to an existing hook's count. One `draw_` inside `_draw()` is red immediately

### `net_shell`'s spies need one **call sequence number**

⚠ **Today each spy accumulates a separate array per hook** (`tiles` · `docks` · `bodies` · `beaks` · `hps` · `boats_seen`). ⇒ **the order of calls *between* hooks is not recoverable in principle.** But C-2's layer order is a contract: **a filled halo at 1.35× radius drawn *after* `_paint_body` covers the 2px outline and the 3px dot completely — the body vanishes and the round stays green.** A check that reads only final state can never measure iteration order.

⇒ **give each spy one monotonic `var _seq := 0` that every hook records alongside its arguments** (`{"seq": _seq, ...}` then `_seq += 1`, reset to 0 at the head of `_draw`). Then these become checks: **for one body, `halo.seq < body.seq`**; **every `burst ring.seq` > every `body.seq`**; **every `target_line.seq` < every `body.seq`**; and **every `spark.seq` > every `body.seq` while staying below every `burst ring.seq`** (layer 9 sits between the bodies and layer 10).

---

## E. New constants for `look.gd`

⚠ **Every ratio carries its pixel conversion in a comment beside it.** In the dead game a radius of 8 was quoted as *"8px"* and reached the screen at **38px** — it was a radius not a diameter, and a 1.6× camera and a 1.5× window stretch multiplied it. **The same shape bit four separate times.**

### ⚠ Every px here is a **canvas pixel**, and the window stretch multiplies on top

> **Refutation box — the draft's "no window stretch" was false. The numbers survive anyway.**
> Draft: *"This repo has no multiplier at all today (zoom 1.0, **no window stretch**, 32 × 40 = 1280, 18 × 40 = 720). **So the pixel values written here are true.**"* **`project.godot`'s `[display]` carries `window/stretch/mode="canvas_items"`.** `game.gd`'s `_click_dock` comment records the transform from a direct measurement — *"headless the window is 64x64, the transform is 0.05"* (64 ÷ 1280 = 0.05). **The stretch exists and it is not 1.0.** At a 1920 window it is 1.5×, which is exactly the "1.5× window" this paragraph cites from the dead game.
>
> **But the review's conclusion — "all of E hangs on that one sentence" — is too strong. Two lines of arithmetic:**
> ① **The stretch is uniform.** The tile, the body and the halo all grow by the same factor ⇒ **every ratio and relative size stays true**: "35% of a tile", "1.35× the radius", "6px of overlap". That was never the dead game's failure — its failure was **an absolute claim (a radius read as a diameter)** meeting a multiplier and coming out 4.8× off.
> ② **Pixel snapping happens BEFORE the stretch, in canvas space.** ⇒ the **2.0px floor set above is true in canvas px**, and at a 1.5× window it reaches the eye as 3.0 screen px — **more visible, not less.**
> ⇒ **What has to change is the sentence, not the table. The sentence is:**
> **every px written here is a canvas pixel and reaches the screen multiplied by `window width ÷ 1280`. Ratios, overlaps and the snap floor are independent of that factor; only "how large it actually is on the display" varies with the window.**

### Colours (the only file allowed to write `Color(`)

| name | first value | used by |
|---|---|---|
| `COL_FLASH` | `Color(1.0, 1.0, 1.0)` | 3 — the white a body colour mixes toward |
| `COL_SHOT` | `Color(1.0, 0.925, 0.667)` | 1 — the tracer |
| `COL_AREA_RING` | `Color(1.0, 0.600, 0.350, 0.55)` | 5 |
| `COL_LAND_RING` | `Color(0.451, 0.847, 1.0, 0.60)` | 7 |
| `COL_TARGET_LINE` | `Color(1.0, 0.420, 0.361, 0.12)` | 6 — the enemy hue at alpha 0.12 |
| `COL_SPARK` | `Color(1.0, 0.855, 0.600)` | 2② — the hit shards. **One colour, independent of side** |
| `COL_HIT_HALO` | `Color(1.0, 1.0, 1.0, 0.35)` | 3② — the filled halo under a body. **Not a reuse of `COL_FLASH`** |

**Item 8 reuses `COL_WIN` / `COL_LOSE`, item 9 reuses `COL_BEAK` / `COL_BUTTON`, item 4 reuses `COL_ALLY` / `COL_ENEMY`, and item 11's water margin reuses `COL_WATER`.** The same value does not get a second name.

⚠ **The draft had no halo colour at all — while the argument that killed the arc and the argument that chose
the shards both stood on "a filled white disc."** Leave the premise unwritten and the next person passes the
body colour at a low alpha, and both arguments collapse that moment.
**The reason it is not a reuse of `COL_FLASH` is the alpha**: what 3① mixes toward has to be opaque, and
mixing a white at alpha 0.35 silently turns `HIT_FLASH_STRENGTH` 0.70 into 0.245. **Two concepts, not one.**
One line of arithmetic: white at alpha 0.35 over `COL_LAND` (luma **0.242**) gives luma **0.507**, against the
cream shard (`COL_SPARK`, luma **0.867**) — a difference of **0.36** (Rec.709 `0.2126R + 0.7152G + 0.0722B`).
**F measures that difference**, so editing the colours until the shards stop reading on a halo bites.

### Times and sizes — **all 44**

⚠ **The draft called this table "39" and counting it gives 38.** With the spark's six it is **44**.
**Re-measure the whole table, not the row someone is arguing about** — this repo's own line, and that total is
what holds up F's claim that *every* name in E is caught by the suffix scan. Left wrong, nobody knows how many
the scan is missing.

⚠ **All 44 names are built to be caught by F's widened suffix list — but `FX_GAIN` escapes it on its value,
not its name.** `_literal_hits`' regex requires the value to **start with a digit or `Vector2(`**, and
`[1.0] × 12` starts with `[`. ⇒ **F widens the regex's value side with `\[\s*-?[0-9]` and adds a tenth
synthetic case.** Until then the number caught is **43**. **Writing "all 44 are caught" is how nobody ever
learns which ones the scan is missing.**

Eight of the draft's names (`BURST_GROWTH` · `TARGET_LINE_MAX` · `SHAKE_FREQ_A` · `SHAKE_FREQ_B` · `GAIT_PERIOD_TILES` · `GAIT_SQUASH` · `WATER_MARGIN_TILES` · `FX_MAX`) **matched no suffix at all** — see F's box.

| name | first value | pixels / note |
|---|---|---|
| `SHOT_SEC` | `0.10` | a 4-tile range is **160px**, so 1600px/s |
| `SHOT_LEN_PX` | `12.0` | |
| `SHOT_WIDTH_PX` | `2.0` | |
| `LUNGE_SEC` | `0.18` | 11 frames at 60fps. **0.08 was under five frames and invisible in the dead game** |
| `LUNGE_PUSH_RATIO` | `0.55` | 55% of its own radius ⇒ melee cell **7.7** · bison **8.8** · lion **12.1 px** (the other two have range > 0 and never lunge) |
| `LUNGE_BITE_PX` | `6.0` | **maximum overlap; by construction it can never be exceeded** — table below |
| `SPARK_SEC` | `0.12` | **7.2 frames at 60fps** (under five was invisible in the dead game). Starts after a delay of `LUNGE_SEC × 0.5` = **0.09s** ⇒ fx lifetime **0.21s**. ⚠ **not a free first value — above 0.125 the inequality in G breaks** |
| `SPARK_COUNT` | `6` | shard count. **Three per side of the tangent — the fan is symmetric.** Raising it does not move D's hook table (one `draw_multiline`) |
| `SPARK_REACH_PX` | `18.0` | contact point to shard tip = **45% of a tile.** Travel per frame `18 ÷ 7.2` = **2.5px**, above the snap floor |
| `SPARK_LEN_PX` | `5.0` | one shard's length; on the last frame it occupies **13 – 18px** out. ⚠ **Every margin is built on the inner end (13)** — built on the tip (18) as in the draft, the inner half sails through the checks |
| `SPARK_WIDTH_PX` | `2.0` | the same width as a body outline. **The leaf takes it as an argument** — see D |
| `SPARK_SPREAD_DEG` | `12.0` | **half-angle off the tangent axis** (24° per side). `2 × 22 × sin 12°` = **9.2 < 13** is the inequality behind "every point is farther from both centres than the contact point is" — table below. ⚠ **the `deg` suffix is added to F's list for this name** |
| `HIT_FLASH_SEC` | `0.14` | **14%** duty against an attack period of 1.0s — see G |
| `HIT_FLASH_STRENGTH` | `0.70` | 1.0 replaces rather than mixes |
| `HIT_HALO_MUL` | `1.35` | × body radius ⇒ **18.9 · 15.1 · 21.6 · 13.5 · 29.7 px** — overlap in G |
| `HIT_KNOCK_PX` | `3.0` | **above the 2.0px snap floor** — see the head of C |
| `HIT_KNOCK_SEC` | `0.10` | |
| `BURST_SEC` | `0.32` | |
| `BURST_GROWTH` | `2.2` | lion 22px → **48.4px**, crow 10px → **22.0px** |
| `BURST_WIDTH_PX` | `2.0` | |
| `AREA_RING_SEC` | `0.25` | |
| `AREA_RING_START_RATIO` | `0.4` | the lion's 60px radius **starts at 24px** |
| `AREA_RING_WIDTH_PX` | `3.0` | |
| `TARGET_LINE_WIDTH_PX` | `1.0` | |
| `TARGET_LINE_MAX_COUNT` | ~~`8`~~ **`14`** | ~~**unreachable on these three islands (6 enemies max); the check is synthetic**~~ ⚠ **Refuted 2026-08-18** — at 8 the raised counts (8 · 12 · 14) made it bite for the first time, hiding the OPENING of islands 2 and 3. **Raised to 14 in code, and both the counts and the constant have landed.** See C item 6's box |
| `LAND_RING_SEC` | `0.40` | |
| `LAND_RING_R_PX` | `20.0` | **50% of a tile. 20 × 2 = 40, so two orthogonally adjacent rings meet exactly and never overlap** |
| `LAND_RING_WIDTH_PX` | `2.0` | |
| `SHAKE_SEC` | `0.30` | |
| `SHAKE_PER_DAMAGE_PX` | `1.2` | damage 2 → **2.4px**, the lion's 4 → **4.8px** |
| `SHAKE_MAX_PX` | `6.0` | **the width of the exposed band, and the size of the dock-click error if it is not corrected** |
| `SHAKE_A_FREQ` | `61.0` | deterministic `sin` — randomness is unmeasurable |
| `SHAKE_B_FREQ` | `47.0` | |
| `GAIT_PERIOD_TILES` | `0.7` | one stride per **28px** |
| `GAIT_SQUASH` | `0.20` | `1−s·sinφ` along travel, `1+s·sinφ` across. Peak displacement **crow 2.0 · ranged 2.2 · melee 2.8 · bison 3.2 · lion 4.4 px** — above the 2.0px floor |
| `CHIP_FX_SEC` | `0.18` | ~~`KEY_FX_SEC`~~ — **renamed 2026-08-18**: the keys are gone and the shape is the start button |
| `REFUSE_SHAKE_PX` | `4.0` | ~~`KEY_REFUSE_SHAKE_PX`~~ — **renamed**, and `_chip_offset` is now its ONLY reader |
| ~~`BERTH_FX_SEC`~~ | — | **DELETED 2026-08-18 with the berths.** There is no fleet to meter |
| `PANEL_FADE_SEC` | `0.25` | |
| `HOLD_OUTCOME_SEC` | `0.80` | how long the shell sits still before opening the next island |
| `HOLD_BEAK_SEC` | `0.50` | **also item 9's tint duration. There is no second constant for it** |
| `WATER_MARGIN_TILES` | ~~`1`~~ ~~`5`~~ **`12`** | width of `COL_WATER` painted outside the legend ⇒ ~~680~~ ~~2436~~ **4032 tiles (72 × 56)**. ⚠ **Raised twice, and neither time for the shake**: `boat-and-landing` took it to 5 because at the old `ZOOM_MIN` the visible world was 4.45 tiles wider than the map on each side; `plan-then-watch` took it to 12 because `ZOOM_MIN` fell to **0.45** and the gap became **11.6 tiles**. `net_camera`'s `_painted_area_covers_the_viewport` is what reddens if it lags behind `ZOOM_MIN` |
| `FX_MAX_COUNT` | `256` | **caps the pass-through store only.** Body-attached effects do not live there — see B |
| `FX_GAIN` | `[1.0] × 12` | **per-item strength.** Below |

### The lunge cannot swallow a body — one table

`gap = centre distance − r_self − r_target`, `push = min(RATIO × r_self, gap + 6.0)`.
**The worst case is always an orthogonal neighbour (40px).**

| attacker | target | gap | RATIO × r | actual push | remaining overlap |
|---|---|---|---|---|---|
| melee 14 | bison 16 | 10.0 | 7.7 | **7.7** | 0 |
| melee 14 | lion 22 | 4.0 | 7.7 | **7.7** | 3.7 |
| bison 16 | melee 14 | 10.0 | 8.8 | **8.8** | 0 |
| bison 16 | ranged 11.2 | 12.8 | 8.8 | **8.8** | 0 |
| lion 22 | melee 14 | 4.0 | 12.1 | **10.0** | **6.0** ← lands exactly on the ceiling |
| lion 22 | ranged 11.2 | 6.8 | 12.1 | **12.1** | 5.3 |

⇒ **no type pair can overlap by more than `LUNGE_BITE_PX` 6.0.** The draft's lion overlapped by **29.6px** in the same situation. F measures the ceiling.

### Where the shards land — one table, **for both halos**

`contact ↔ target centre = 40 − (r_self + push)`, **`contact ↔ own centre = r_self`** (exactly, by
construction), `halo = HIT_HALO_MUL × r`, `depth = halo − contact distance` (positive means the contact point
is inside that halo).
**The worst case is the lunge's worst case, an orthogonal neighbour at 40px.** Only the three range-0 types strike.

| attacker | target | push | ↔target centre | target halo | target depth | ↔own centre | own halo | **own depth** |
|---|---|---|---|---|---|---|---|---|
| melee 14 | bison 16 | 7.7 | 18.3 | 21.6 | 3.3 | 14 | 18.9 | **4.9** |
| melee 14 | crow 10 | 7.7 | 18.3 | 13.5 | **−4.8** (outside) | 14 | 18.9 | **4.9** |
| melee 14 | lion 22 | 7.7 | 18.3 | 29.7 | **11.4** ← worst | 14 | 18.9 | **4.9** |
| bison 16 | melee 14 | 8.8 | 15.2 | 18.9 | 3.7 | 16 | 21.6 | **5.6** |
| bison 16 | ranged 11.2 | 8.8 | 15.2 | 15.1 | −0.1 (outside) | 16 | 21.6 | **5.6** |
| lion 22 | melee 14 | 10.0 | 8.0 | 18.9 | 10.9 | 22 | 29.7 | **7.7** |
| lion 22 | ranged 11.2 | 12.1 | 5.9 | 15.1 | 9.2 | 22 | 29.7 | **7.7** |

⚠ **The right-hand three columns were missing from the draft, and they are what kills "the shards clear the
halo."** **Own depth is always exactly `(HIT_HALO_MUL − 1) × r_self`**, so **the contact point is inside the
attacker's own halo in every pairing.** And even on the tangent, the worst pair (melee → lion) leaves the tip
**6.9px inside the target's halo** (`√(18.3² + 18²)` = 25.7 < 29.7). **The escape cannot be bought** — see C's
second refutation box.

### What the shards do guarantee instead — **two inequalities**

A point is `X = P + ρd` (P the contact point, ρ ∈ [13, 18], `d` at ±`SPARK_SPREAD_DEG` off the tangent).

1. **Every point is farther from both body centres than the contact point is.**
   From the target's centre `|X − T|² = C² + ρ² − 2ρC sinθ` ⇒ never below C once `ρ ≥ 2C sinθ`; worst `2 × 18.3 × sin 12°` = **7.6**.
   From its own centre `|X − B|² = r² + ρ² − 2ρr sinθ` ⇒ worst `2 × 22 × sin 12°` = **9.2**.
   ⇒ in general **`SPARK_REACH_PX − SPARK_LEN_PX ≥ 2 × max(r_self, contact distance) × sin(SPARK_SPREAD_DEG)`**
   = **13 ≥ 9.2** ✓. **The tangent is the only axis with that property** — a ±facing axis turns back into one of the bodies
2. **Travel per frame `SPARK_REACH_PX ÷ (SPARK_SEC × 60)` = 2.5px ≥ the 2.0px snap floor.**
   **What makes them read on a static halo is this line, not an escape**

⚠ **Inequality 1 moves with four constants** (`SPARK_REACH_PX`, `SPARK_LEN_PX`, `SPARK_SPREAD_DEG`, and the
radii `HIT_HALO_MUL` sets); inequality 2 with `SPARK_REACH_PX` and `SPARK_SEC`.
**F measures both directly** — editing one value and staying green would be a green that lies.
**Whatever table a constant lives in, what gets re-measured is this whole table.**

### `FX_GAIN` — what makes accessibility structural rather than a later feature

**A 12-slot array indexed by the item numbers in this doc. Every effect multiplies its own amplitude by its own slot, and 0 turns it off completely.**

The case for it: **every shipped game gives these a toggle.** Vampire Survivors' Display section carries **Damage Numbers · Flashing VFX · Weapons ScreenShake · Disable Blood** as separate switches; the League of Legends client has *"Enable screen shake"*; Nuclear Throne exposes screenshake and freeze frames as sliders that go to 0%. And it is not a taste question — **Xbox Accessibility Guideline 118 forbids flashing above approximately three per second and flashing covering approximately 20% or more of the screen.**

⚠ **The draft wrote that area threshold as 25%, and that is not XAG 118's number.** 25% is **WCAG's general flash threshold**, and that one is measured against **the area within a 10-degree visual field**, not the screen — so it is not the same figure. The 3Hz half is correct. **Citing the two blended together makes neither checkable.**

⚠ **An options screen is out of scope here.** `FX_GAIN` is a place to edit values by hand; its purpose is that **adding a UI later touches no effect code.**

---

## F. Nets — what protects these effects

⚠ **"No fake nets" has failed in this repo repeatedly at exactly this spot.**
*"`_draw()` ran is not anything was drawn"* — three features shipped that way in one day and **each was deletable with 6,163 checks green.**
*"A spy on a hook sees the hook, never the native call inside it"* — with the whole argument chain closed, emptying `_paint_dot`'s body left the round green.
*"Argument capture proves a value was computed and handed on, never that it was used"* — one `draw_circle(p, 0.0, col)` inside a leaf turned forty rocks invisible with the round green.

### ⚠ The rule for this table: **every row has a floor**

> **Refutation box — the draft's items 2, 10, 11 and 12 measured only a ceiling, so the effect could be zero everywhere and stay green.**
> Item 2: *"`soldier_pos` does not change"* + *"the centre on the fx's last frame equals `tile_point_px`"* ⇒ **a lunge that is always 0 passes both.**
> Item 11: *"position is exactly (0,0) after `SHAKE_SEC`"* + *"peak offset ≤ `SHAKE_MAX_PX`"* ⇒ **no shake passes both.**
> Item 12: *"pump 20 frames without moving and the squash does not change"* ⇒ **a squash that never changes passes.**
> Item 10: *"the first frame's alpha is below `COL_PANEL_BG`'s"* ⇒ **a panel at alpha 0 forever passes.**
> This is precisely the defect CLAUDE.md names: *"a tuning constant with a floor on one end and none on the other is half-measured."* **And item 2 is the one the user called "패끼리 싸우는 맛".**
> ⇒ **Every row below carries a ceiling and a floor as a pair.**

### Per item — **what must redden when broken**

| # | break this | this goes red |
|---|---|---|
| 1 | ignore the tracer's progress and always draw it at the origin | the `_paint_shot` position captured on two frames is **identical** |
| 1 | re-read `soldier_target` each frame instead of freezing the endpoints | after the target dies, the next frame's destination points at **a different enemy** |
| 1 | **drop the `SHOT_SEC` delay** | just after the firing frame the target's `_paint_body` colour **differs** from `Look.body_colour_of` (floor), and `SHOT_SEC` later it is **equal** (ceiling) |
| 2 | write the lunge into `soldier_pos` | `battle.soldier_pos` **differs** across one pumped view frame |
| 2 | **the lunge is always 0 (floor)** | at the fx's **halfway** frame the centre is **at least `min(RATIO × r, gap + BITE) × 0.9`** away from `Look.tile_point_px`, and in the **same direction** as `_facing_of` |
| 2 | drop the overlap ceiling | with a lion hitting a melee cell 40px away, the two bodies overlap by **no more than `LUNGE_BITE_PX`** at the halfway frame |
| 2 | the lunge offset is non-zero at the ends | the centre on the fx's **last** frame equals `Look.tile_point_px` **exactly** |
| 2② | **no shards appear at all (floor)** | on the lunge's **halfway** frame `_paint_spark` is called **exactly once**, and on the **striking** frame **zero** times (the delay's ceiling) |
| 2② | hand `draw_multiline` an empty or one-point array | the `points` captured at the hook are exactly `SPARK_COUNT × 2` = **12** long and **no two are equal** |
| 2② | **the shards never move (floor)** | the **first** frame's greatest distance from the contact point is **below** the **last** frame's, by **at least 2.0px**; and calling `_spark_points` directly at `progress` **0.25** and **0.75** raises **both the greatest and the least** distance (the only row that bites whether the pure function uses `progress` at all) |
| 2② | put the shards on the body centre instead of the contact point | rebuild **`P = B + f × own radius`** from that frame's `_paint_body` centre B and `_facing_of`, and **every** captured point lies between `SPARK_LEN_PX` and `SPARK_REACH_PX` from P. ⚠ **measure it in a setup where the attacker is not itself hit that frame** — a flinch offset in B makes it the wrong origin |
| 2② | turn the fan onto the ±`_facing_of` axis | on the last frame **every** point's `v = X − P` satisfies `\|v·f\| ≤ SPARK_REACH_PX × sin(SPARK_SPREAD_DEG)` (= **3.74px**) **and** `\|v·t\| ≥ (SPARK_REACH_PX − SPARK_LEN_PX) × cos(SPARK_SPREAD_DEG)` (= **12.7px**), `t` being `f`'s perpendicular. ⚠ **one point failing is red** — not an average. ⚠ **the threshold is built on the inner end (13)**; built on the tip (18) it reddens a correct implementation |
| 2② | open the fan on one side only | on the last frame **6** points have `v·t > 0` and **6** have `v·t < 0` |
| 2② | edit a constant so the tangent margin disappears | `SPARK_REACH_PX − SPARK_LEN_PX ≥ 2 × max(r_self, 40 − r_self − push) × sin(SPARK_SPREAD_DEG)` (= **13 ≥ 9.2**) — E's inequality 1, biting three constants at once |
| 2② | drop the per-frame travel below the snap floor | `SPARK_REACH_PX ÷ (SPARK_SEC × 60) ≥ 2.0` (= **2.5**) — E's inequality 2 |
| 2② | edit the colours until the shards vanish on a halo | `COL_HIT_HALO.a ≤ 0.4`, and the luma gap between `COL_SPARK` and `COL_HIT_HALO` composited over `COL_LAND` is **at least 0.25** (= **0.36**, Rec.709) |
| 2② | draw the shards under the bodies | every `spark.seq` is **greater than every `body.seq`** and **less than every `burst ring.seq`** |
| 2② | the shards never die | `_paint_spark` is called **0** times after `LUNGE_SEC × 0.5 + SPARK_SEC`, and across 200 steps the `SPARK` count in `_fx` **never exceeds 12** (B's lifetime bound) |
| 2② | raise `SPARK_SEC` past 0.125 | `SPARK_SEC × 8 < Rules.period_of(Rules.CELL_MELEE)` (G's inequality) |
| 3 | **delete the white mix entirely (floor)** | the hit body's `_paint_body` colour **differs** from `Look.body_colour_of` by exactly `HIT_FLASH_STRENGTH`, and **an unhit body is exactly equal** |
| 3 | never call `_paint_halo`, or pass radius 0 | the halo radius **equals** that body's radius × `HIT_HALO_MUL` |
| 3 | draw the halo **after** the body | for one body, `halo.seq < body.seq` (D's sequence number) |
| 3 | reduce the flinch to 1px | the peak offset is **at least `HIT_KNOCK_PX`** (the snapping floor) |
| 3 | stack fx when a body is hit twice in one frame | a body carries **exactly one** flash entry |
| 2·3 | **offset the body but not the beak and HP bar** | at the lunge's halfway frame, `_beak_points`' tip and `_hp_rects`' back moved by **the same offset** |
| 4 | the burst ring does not grow | `_paint_ring`'s radius three frames later is **larger**, and just before `BURST_SEC` it is **at least 90%** of start × `BURST_GROWTH` (floor) |
| 4 | draw the burst with the ground | every `burst ring.seq` is **greater than every `body.seq`** |
| 4 | open the next island without `_hold_sec` | after the winning frame `battle` is **still the same object**, and after `HOLD_OUTCOME_SEC` it **has changed** (floor) |
| 5 | hard-code the ring radius | the lion (1.5 tiles = 60px) and the ranged cell (1.0 = 40px) get **different radii** |
| 5 | draw the area ring above the bodies | every `area ring.seq` is **less than every `body.seq`** |
| 6 | draw lines above the cap | ⚠ **re-measured 2026-08-18 for `TARGET_LINE_MAX_COUNT` 14.** Both ends: at exactly **14** living enemies `_paint_target_line` is called **fourteen** times — **that arm is a real island's opening, not a synthetic one** — and at **15** it is called **zero**, which is still synthetic and says so |
| 6 | draw the line above the bodies | every `target_line.seq` is **less than every `body.seq`** |
| 7 | never emit `LAND` | the unloading frame's `events` holds one `LAND` per soldier |
| 7 | the ring does not grow | the first frame's radius is **near 0** and the last is **at least 90%** of `LAND_RING_R_PX` |
| 8 | the shell discards `commit()`'s bool again | press start with `boats` empty, **pump one frame**, `_paint_button`'s `bg` **differs from the accepted case**, and the shift is above 0 and at most `REFUSE_SHAKE_PX` |
| 8 | shake only the `rect` | on the refusal frame `rect.position` and the text `at` moved by **the same offset** |
| 9 | never call `note_beak` | the picked frame's row `bg` and the frame after `HOLD_BEAK_SEC` **differ**, and removing `note_beak` makes **the two frames equal** |
| 9 | call `apply_beak` before the hold | on the frame right after the pick, `run.state()` is **still REWARD** and `army.has_beak[picked]` is **still 0** |
| 10 | skip the fade and open at full alpha | the first frame's `_paint_panel` alpha **<** the last frame's alpha **==** `COL_PANEL_BG.a` |
| 10 | leave input open during a hold | ⚠ **re-driven 2026-08-18**: the 1/2 keys are gone, so it presses **start** during an outcome hold and asserts `battle.committed()` is **still false** — a state the sim owns |
| 11 | accumulate the shake with `+=` | after `SHAKE_SEC`, `field_view.position` is **exactly (0,0)**, and the peak offset is ≤ `SHAKE_MAX_PX` |
| 11 | **strength does not scale with damage (floor)** | the peak offsets for damage 2 and damage 4 **differ from each other** and each is **at least `dmg × SHAKE_PER_DAMAGE_PX × 0.8`** |
| 11 | forget to subtract the shake from the dock click | clicking the centre of the dock rectangle **as drawn** on a shaken frame increases `battle.boats.size()` |
| 11 | skip the water margin | the terrain pass calls `_paint_tile` **680** times (34 × 20) |
| 12 | drive the phase from time | pump 20 frames **without moving a body** and the squash **does not change** |
| 12 | **the squash never changes at all (floor)** | move the body by half of `GAIT_PERIOD_TILES` and the squash **changes**, by at least `GAIT_SQUASH × 0.5` |
| 12 | make the squash isotropic | the squash `Vector2`'s x and y **differ** (one above 1, the other below) |
| all | `setup` / `bind` does not clear both stores | fill the stores, call `setup` again, **zero hook calls on the first frame** |

### ⚠ ~~Invert with `FX_GAIN[n] = 0.0`~~ — **no net can do that. Measure the accessor** (measured, 2026-08-17)

> **Refutation box — not one of the twelve rows this section demanded could be built. Found while building `net_fx_view`.**
> **`Look.FX_GAIN` is a `const` Array and therefore read-only at runtime**, and the three view files read it through `Look.fx_gain_of()` and nothing else — there is no seam to inject through. ⇒ **a net has no way to set one slot to 0 at all.** (Same property as CLAUDE.md's "a `const` packed array does not parse", wearing the other face: there immutability was the win, here it is the cost.)
> ⇒ **What `net_fx_view` bites instead is the accessor's off-by-one**: does `fx_gain_of(1)` read `FX_GAIN[0]`, does `fx_gain_of(12)` read `FX_GAIN[11]`, are there twelve slots. **It is the only defect in this array a net can reach, and it is also the quietest one** — the round stays green and the effect that switches off is simply the neighbour's.
> ⚠ **The table below is no longer a check list. It is the record of each item's un-juiced value**, i.e. what must disappear from the screen when a slot is edited to 0 by hand in `look.gd`. **No net walks it.**

> **Refutation box — the draft's single line "that item's hook is called never" read as covering twelve and actually covered two.**
> The same doc pins **"no new leaf" for items 3①③, 8, 9, 10, 11 and 12 — seven of them.** The hooks they ride (`_paint_body` · `_paint_button` · `_paint_roster_entry` · `_paint_panel` — ⚠ `_paint_key` and `_paint_berth` were their names until 2026-08-18) are **called every frame regardless, as long as there are bodies, a button and a panel.** And **items 4, 5 and 7 share one `_paint_ring`**, so `FX_GAIN[4] = 0` leaves 5 and 7 calling it. The ones it actually bites are **1 (`_paint_shot`), 2② (`_paint_spark`) and 6 (`_paint_target_line`) — three.**
> ⚠ **Item 2 left that list by owning a leaf, and is bitten only halfway** — the shards (②) bite, **the lunge (①) rides `_paint_body` and does not. That is why the item-2 row below states both layers separately.**
> ⇒ **One line becomes twelve. The rule: not "the hook is not called" but "the value that item puts into the argument becomes exactly the un-juiced value."**

| # | what must vanish from the screen when `FX_GAIN[n]` is hand-edited to 0 (**an eye reads this, not a net**) |
|---|---|
| 1 | `_paint_shot` called **0** times |
| 2 | the centre at the lunge's halfway frame == `Look.tile_point_px` **and** `_paint_spark` called **0** times (this row is what keeping the leaf exclusive to item 2 bought) |
| 3 | colour == `Look.body_colour_of`, centre == `tile_point_px`, `_paint_halo` called **0** times |
| 4 | `_paint_ring` calls originating from `BURST` are **0** (5 and 7's rings remain) |
| 5 | `_paint_ring` calls originating from `AREA` are **0** |
| 6 | `_paint_target_line` called **0** times |
| 7 | `_paint_ring` calls originating from `LAND` are **0** |
| 8 | `_paint_button`'s `bg` == `Look.COL_START` and `rect` == `Look.start_rect_px()` |
| 9 | that row's `bg` == `Look.COL_BUTTON` |
| 10 | the first frame's `_paint_panel` alpha == `COL_PANEL_BG.a` |
| 11 | `field_view.position` == `(0, 0)` |
| 12 | the squash == `Vector2.ONE` |

### **Four** nets move — two new, two edited

**① `net_draw_leaf.gd` (edit) — swap in D's table and set the two totals to 68 / 20.** And **widen the literal scan's suffix list.** Today it is only `_px _width _radius _size _margin _alpha _ratio _offset _gap _font_size`, so **`const HIT_FLASH_SEC := 0.14` sitting in a view file passes green** — and **juice is half time constants.** The colour half of the one-file rule once shipped with the pixel half never written, and its green did not mean what it said; this time the time half is that gap. ⇒ add **`sec dur time speed freq mul strength gain tiles growth squash count deg`**.
⚠ **`deg` is the spark's doing** — `SPARK_SPREAD_DEG` matches none of the other twelve. **The list was widened rather than the name twisted**: angles will keep coming up as presentation constants, and sweeping all of `src/` for `deg` hits nothing at all (`deg_to_rad(...)` is a call, so it never matches the `name_deg := number` regex).

> **Refutation box — the draft's widened list missed eight of its own constants, and both examples it gave for narrowing the scope were names that never matched anything.**
> `_literal_hits`'s regex is `[A-Za-z0-9_.]*_(suffix)\s*(:=|=)\s*number`, so **the name has to END in the suffix.** Checking the draft's own table against the draft's additions (`sec dur time speed freq mul strength gain`) leaves **`BURST_GROWTH` · `TARGET_LINE_MAX` · `SHAKE_FREQ_A` · `SHAKE_FREQ_B` · `GAIT_PERIOD_TILES` · `GAIT_SQUASH` · `WATER_MARGIN_TILES` · `FX_MAX` — eight — matching nothing.** (`SHAKE_FREQ_A` ends in `_A`, so adding `freq` does nothing for it.)
> ⇒ **The names were changed**: `SHAKE_A_FREQ` · `SHAKE_B_FREQ` · `TARGET_LINE_MAX_COUNT` · `FX_MAX_COUNT`, and `tiles growth squash count` were added to the list. **43 of E's 44 match on their name now** — five of the spark's six already match on `_SEC` · `_COUNT` · `_PX`, and `SPARK_SPREAD_DEG` is what brought `deg` in.
> ⚠ **The forty-fourth is `FX_GAIN`, and it escapes on its value rather than its name** — an array literal, so the regex's *value* side has to widen to `\[\s*-?[0-9]`, which is the tenth synthetic case. **Written down as "all of them match", that one stays invisible forever.**
>
> **And the reason given for narrowing was wrong.** Draft: *"`rules.gd`'s `CROSSING` and `FIELD_TTL` are rules, not presentation."* **Neither `CROSSING` nor `FIELD_TTL` matches any suffix, now or after the widening.** (And `FIELD_TTL` is not in `rules.gd` at all — it is **`battle.gd`**'s constant.) Sweeping all of `src/` with the widened list actually hits exactly two names: **`rules.gd`'s `const _COL_SPEED := 6` and `const TYPE_COUNT := 5`**, both table column indices rather than presentation.
> ⇒ **The time half is scoped to `src/view/` + `src/shell/`.** `src/shell/` is not optional: **`HOLD_OUTCOME_SEC`, `HOLD_BEAK_SEC` and `PANEL_FADE_SEC` are used in `game.gd`.** Scoped to `src/view/` alone, **`var _hold_sec := 0.8` written straight into `game.gd` stays green.**

⚠ **And carry a synthetic case that fails the widened scan itself.** Twice in one night a check written to catch a defect shipped carrying that same defect, and neither was caught by inverting the code. **Put those eight names into the synthetic cases verbatim** — e.g. `_literal_hits("const BURST_GROWTH := 2.2\n").size() > 0`. **That is the only way this particular defect gets caught.**
⚠ **Add `SPARK_SPREAD_DEG` as a ninth synthetic case** — if `deg` is ever dropped from the list, that line has to bite.
⚠ **And widen the regex's *value* side too.** It reads `(-?[0-9]|Vector2\s*\(\s*-?[0-9])`, so the value must **start with a digit or `Vector2(`**, and **`FX_GAIN`'s `[1.0] × 12` starts with `[` and is missed** — the one hole among E's 44. Add `\[\s*-?[0-9]` and a **tenth synthetic case**: `_literal_hits("const FX_GAIN := [1.0, 1.0]\n").size() > 0`.
⚠ **Widening it does not redden the tree** — sweeping `src/` with the widened suffixes and array values hits only `look.gd`'s `BODY_RADIUS_RATIO` and `BODY_CORNER_RATIO`, and **`look.gd` is excluded from that scan.**

**② `net_fx.gd` (new) — sim only.** Build a `Battle` with `.new()`, feed it frames, read `events`: the attacker id is right, `splash` matches the real number of secondary victims, `DEATH` arrives on the frame `alive` flips, `begin_frame` clears — **and, calling `begin_frame` each step, 200 steps leave `events.size()` under one frame's ceiling (19).** **Two inversions**: drop the attacker parameter from `_hit_enemies` and `from` must be wrong; drop `begin_frame()` from the loop and `events` must pile up.

**③ `net_fx_view.gd` (new) — the views treed, driven with `pump_frames`.** Everything in the **per-item table** above lives here — **not the `FX_GAIN` table** (see the box above it). **Comparing two frames is this net's character** — a check that reads one frame's final state **cannot see "it stopped"**, and nearly every juice defect has that shape.

**④ `net_shell.gd` (edit) — new hook overrides and `_seq` in all three spies, 576 → 680 in two places, margin tiles removed from `_rects_land_on_screen`, plus `_hold_sec`, the key feedback and the corrected dock click.** **`FieldSpy` also gains a `_paint_spark` override and a `sparks` array** — without it the spy calls the real leaf and `draw_multiline` runs headless, silently.

⇒ the round goes from **7 nets to 9.** Well clear of the below-five detector.

### ⚠ Two ways these nets go quietly green while measuring nothing

- **GDScript lambdas capture by value. Measured on 4.7.1**: `sig.connect(func(_a): n += 1)` and two emits leaves **`n` at 0.** Array capture is by reference and works. ⇒ **never count with a local int.** Count into an Array, a Dictionary, or a spy field
- **Headless frame pacing is pinned at 6.900ms regardless of load.** Timing juice cost with `pump_frames` measures nothing. **Headless gives no pixels; the frames and `_draw()` are real**

---

## G. Performance — the ceiling is the eye, not the engine

**Performance was never the wall and is not the wall here.** Measured in the dead game: 300 `Node2D`s at **0.065ms**, and 300 `CharacterBody2D`s costing what 60 did. This is lighter — everything is immediate-mode `draw_*` inside a single `FieldView`, and the pass-through store is capped at `FX_MAX_COUNT` **256**. Terrain already draws **680 tiles** a frame (water margin included), so the worst juice adds on top is **256 calls × 4 passes**.

### The real counts in this game — **three lines, counted off the tree**

- **Enemies per island**: counting `ISLAND_ROWS`, **island 1 = 4 (bison) · island 2 = 6 (2 crows + 4 bison) · island 3 = 5 (2 crows + 2 bison + 1 lion)**
- **Soldier maximum**: 10 to start (6 melee + 4 ranged) + island 1's reward of 3 (2 melee + 1 ranged) = **13**
- ⇒ **the most bodies on screen is island 2's 13 + 6 = 19.** The boss island is 13 + 5 = 18

### How many attackers can be on one body

- **Melee**: range 0 + `REACH_BONUS` 1.5 ⇒ within 1.5 tiles. With one body per tile, **the eight neighbours are the ceiling** (they sit at 1.0 and 1.414; no tile lands on 1.5) ⇒ **8**
- **Ranged**: range 4 + 1.5 = **5.5 tiles** ⇒ about 95 tiles inside that radius, so **every living ranged soldier**, at most 5
- ⇒ **the ceiling on one lion is 8 + 5 = 13**

> **Refutation box — the draft's "island 1 fields 10 allies; the boss island fields one lion ⇒ the boss fight lands exactly on that ceiling" was wrong twice.**
> ① **The boss island has five enemies, not one.** ② **It is not ten soldiers on the lion but up to thirteen** — melee is capped at 8 by the neighbour count, but every ranged soldier is inside 5.5 tiles.
> The conclusion (the lion stays white) survives, but this is the failure this repo recorded as **"re-measure the whole table, not the row someone is arguing about."**

### The ceiling past which the flash never clears

**Duty = `HIT_FLASH_SEC` ÷ attack period.** Both cell types have period 1.0s ⇒ **0.14 ÷ 1.0 = 14%.**
⇒ with phases evenly spread, **1 ÷ 0.14 = 7.15, so eight attackers fill the whole second.** Thirteen can attach, so **this ceiling really is exceeded.**

⚠ **But the phases are not spread here — they lock.** `battle.gd`'s `_soldier_cd[i] = Rules.period_of(st)` is set on the frame that soldier first swings, both cell types have a period of exactly 1.0, and every unit decrements by the same `dt`. **Five landing off one boat and walking in together swing on nearly the same frame** ⇒ locked phase. **A locked phase produces "they all flash once together", not "it is always lit".**

⇒ **the condition that actually hurts readability is not "how many on one body" but "how spread their phases are".** Several boats arriving at intervals spread them, and past eight the lion stays white.
**So item 3 keeps one fx per body (restarting the age rather than stacking), and if that is not enough the first handle to turn is `HIT_FLASH_SEC` down.** The halo means a short flash still reads.

> **Refutation box — the draft misstated the state of the lessons doc and wrote the same arithmetic there for a third time.**
> Draft: *"This repo's older line that «past thirteen or fourteen the flash never clears» is a 0.09s-era number. `lessons-from-two-dead-games` **still stands on it**; after the doubling to 0.18 the real ceiling was 6–7."* **That file is already corrected** — its "screen and readability" section reads *"⚠ this line stood for a long time as 0.09 ÷ 1.2 ≈ 7.5% ⇒ thirteen or fourteen … at the value that actually shipped, 0.18 ÷ 1.2 = 15%, so the ceiling is six or seven."*
> ⇒ **The correction paragraph is deleted. The 6–7 ceiling belongs to lessons' "screen and readability"** — it is the dead game's value (period 1.2, flash 0.18) — **and this game's value (period 1.0, flash 0.14 ⇒ 8) belongs here.** Two docs each writing the same formula diverge. **What differs is the value, not the formula.**

### Halo and ring **area** — the half nobody had looked at

At `HIT_HALO_MUL` **1.35** the halo radii are **18.9 · 15.1 · 21.6 · 13.5 · 29.7 px**.
**Overlap between two halos on orthogonal neighbours (40px):**

| pair | radius sum | overlap |
|---|---|---|
| melee + melee | 37.8 | **0** |
| melee + bison | 40.5 | 0.5 |
| bison + bison | 43.2 | 3.2 |
| melee + lion | 48.6 | 8.6 |
| lion + lion | 59.4 | 19.4 — **there is only one lion, so it cannot happen** |

⇒ **the worst case that actually occurs is melee + lion at 8.6px, and there is one lion.** At the draft's 1.8× multiplier, melee + melee overlapped by **10.4px** and the lion's halo was **79.2px across — two tiles wide.**

**Are the photosensitivity thresholds actually crossed? Answered with arithmetic.**
Worst frame = all 19 bodies hit at once. Mean halo radius ≈ 19px ⇒ 19 × π × 19² ≈ **21,500 px²** against 1280 × 720 = 921,600 px² ⇒ **2.3%.** Adding the lion's area ring (60px radius, an unfilled arc) does not change that.
⇒ **the area threshold (≈20%) is not reached.**
**The frequency threshold (≈3Hz) is**: three to seven attackers with spread phases toggle one body's halo three to seven times a second. ⇒ **`FX_GAIN[3]` exists because of frequency, not area.** H item 6 is half closed by those two lines.

### How many hit sparks are up at once — and why **"thirteen or fourteen" does not transfer here**

**The ceiling on live sparks is 12.** The arithmetic is in **B's store section** (8 melee soldiers + island 2's 4 bison, lifetime 0.21s < the 1.0s minimum melee period). **It is not restated here — a value written in two places diverges.**

⚠ **Do not stand that 12 next to the dead game's "past thirteen or fourteen it stops reading".** That line is a **duty ceiling for one body's flash**, not a ceiling on how many things are on screen, and the refutation box above already corrected where it came from. **What transfers is the formula, not the number.** Rebuilt for sparks, the question becomes **how many ring one body.**

- The melee attackers that can reach one body are capped by **the eight neighbouring tiles** (counted just above) ⇒ **at most 8 fans around one body**
- Duty = `SPARK_SEC` ÷ the minimum melee period = **0.12 ÷ 1.0 = 12%.** ⚠ **The 0.09s delay draws nothing, so it does not count** — measuring with the 0.21s lifetime gives 21% and that is a lie about the screen
- ⇒ even with **perfectly spread phases**, `8 × 0.12 = 0.96 < 1.0` ⇒ **there is always a gap around that body**

**Item 3's flash crosses its ceiling (eight fill a whole second and thirteen can attach); the spark just barely does not** — because 8 can attach and the ceiling is 8.33.
⚠ **So `SPARK_SEC` is not a free first value.** Above `0.125` that property breaks, and the shards stop reading as "it burst" and start reading as "the body is permanently scruffy". **To make it bigger, reach for `SPARK_REACH_PX` before `SPARK_SEC`.** F measures the inequality directly.

**Neither area nor frequency is the problem here — the opposite of item 3.**
Worst frame = 12 fans × 6 shards × (`SPARK_LEN_PX` 5 × `SPARK_WIDTH_PX` 2) = **720 px²** against 921,600 ⇒ **0.078%**, a rounding error beside the halos' 2.3%.
Frequency: **one contact point repeats at its attacker's period (1.0s at the fastest) ⇒ 1Hz**, a third of the ≈3Hz threshold.
⇒ **`FX_GAIN[2]` is a clutter handle, not a photosensitivity handle.** It exists for a different reason than `FX_GAIN[3]`, and **explaining both with the same reason makes neither checkable.**

---

## H. What this doc cannot answer

**1. Whether any of this becomes fun is not decided here.** The sentence that killed the second game was *"그냥 재미가 없다"* and the diagnosis was **"the swarm has no cost."** **Twelve pieces of juice fix nothing in that layer.** Writing that they do is the smokescreen.

**2. Whether "impact feel" can close without sound is unknown.** The study that trained on Steam action-game reviews and dissected the top and bottom eight (arXiv:2208.06155) names **hit stop, sound coherence and camera control**, and states that *"a lack of dedicated design on one of these three features may ruin players' impact feel."* ⇒ **all twelve can ship and "it still has no taste" is a possible outcome, with sound the remaining candidate.** ⚠ Its sample is **entirely directly-controlled action games**; no autobattler is in it. Do not transplant it whole.

**3. Hit stop is undecided.** That study names it one of three, and it is not among the twelve, so this doc does not spec it. ⚠ **And this repo's Sakurai citation was wrong** — his stated reason for shortening hitstop in a brawl is not readability but **fairness: while both parties are frozen, a third player moves in and hits for free** (Famitsu column Vol. 490-1). **An autobattler has no controlling third party, so that reason does not carry over.** The sentence has been corrected in `lessons-from-two-dead-games` and its Korean twin. The real reason to be careful is different: **a global freeze with many bodies attacking becomes a permanent freeze.** If it is used it must be **local to the struck pair**, and implemented as the view holding those two interpolated positions ⇒ **`step(dt)` never stops. The loss condition is a time limit, so stopping the sim would itself be a rules change.**

**4. Item 5's real telegraph needs a rules decision — that is section 0's question.** Adding a wind-up to `_phase_attacks` **changes combat balance**, and only the user can decide it. **It is the one item of the twelve this doc could not close.**

**5. Every first value is probably wrong.** C says so. Which one is wrong in which direction **only the eye answers** — in the dead game a whole juice pass went to `3.done` with 22 nets and 2420 checks green and **not one of its eight acceptance questions answered**, and the user played it and said *"그냥 재미가 없다"*.

**6. Photosensitivity — half closed.** G answers it with arithmetic: **the area threshold (≈20%) is not reached (2.3% at the worst frame) and the frequency threshold (≈3Hz) is.** The other half is **whether that calculation matches the actual screen**, and only the eye answers that.

**7. Items 12, 7, 9 and 10 have no developer statement from any shipped game.** The research left them **unverified** and this doc records them as unverified. Do not promote them. ⚠ **Item 12 had an amplitude problem on top of that** — see its refutation box in C. The amplitude now clears the floor, but **the absence of any support is unchanged.**
⚠ **2② (the hit shards) is the same grade.** What the user asked for is *"an effect at the moment of contact"* — **not shards** — and shards were chosen on **two lines of arithmetic about this screen** (every point moves monotonically away from both centres; 2.5px of travel per frame), not on any shipped game. ⚠ **The grounds the draft gave — "they clear the halo" — were withdrawn by C's refutation box**; those two lines replaced them. **The grounds changed; nothing was promoted.** **The item itself is settled because the user asked for it; what is unverified is the shape.** Do not conflate the two.

**8. Boats, terrain and 3D are not answered.** See A. The user deferred them.
