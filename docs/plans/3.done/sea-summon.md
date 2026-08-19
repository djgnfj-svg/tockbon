# Plan — summon on the sea: arm a slot, press the water, cells come out there on boats

**Status**: `3.done` — **four builder rounds, 2026-08-19. Round: 17 nets / 2473 checks / 4.5 s green.**
✅ **And the user played it and accepted the gesture** — ***"동작방식은 맞음"*** then ***"잘되네"***.
⚠⚠ **`3.done` is not blanket acceptance**: what they accepted is the gesture and the distance. **The
catchment price, the slot contents and the cost question are all still open**, and so is every row below
marked *user only*.
⚠ **The check count went DOWN 2576 → 2473 and that is the signal, not a regression** — the drag suite was
**deleted with its subject** rather than repaired to keep passing.
Was: `2.active` — implementation landed, verification open. See the round log at the foot of this
file, and ⚠⚠ **question 1 is still unanswered** — §8's four seams are the receipt.
Design owner: [summon on the sea](../../design/sea-summon.md). ⚠ **Read it whole before starting** — it is
~700 lines and it did the arithmetic, including **the refutation of its own most attractive claim**
(section 3.3: a sea press is NOT an easier target — median catchment is **1–2 tiles**, the same as the drop
it replaces).

> ***"바다에 소환할 수 있어야할듯 ㅇㅇ"*** · ***"꾹 누르면 쭉 소환되는 형식으로"*** ·
> ***"이 삼 사 오에 내가 만든 세포 끼워 놓고 일 번 누르고"*** (user)

⚠⚠ **The user asked for this four times and it has never been built** — the earliest is 2026-08-18, at the
head of `plan-then-watch`, and it was read for its second half (boats are unlimited) while its first half
(*where the player's hand goes*) was not. This is the standing instance of 「내가 말한대로 개발을 안하네」
for the part loop.

⚠ **A previous plan named `slot-summon` was deleted because its press target was a landable COAST tile.**
**The press target is the SEA.** Nothing below may drift back onto land.

---

## 0. OPEN questions — **none of these closes by inference**

**Sent to the user**: **YES — 2026-08-19, at wrap-up.** ⚠ **`net_process` is what forced it**: the plan was
moved to `3.done` with this line reading `NO` and the round **went red on the move**, naming the file. That
is the check working exactly as `title-and-map`'s failure taught it to. **The line was not flipped; the
questions were sent.**

**What the user's play already answered, without being asked** — recorded separately, because play is not
an answer to a question nobody put:
- **4 (does the drag die)** — ✅ **YES**, explicitly: ***"ㅇㅇ 지워주줘"***, pointing at a screenshot of the
  harbour markers and the reserve stack. Built.
- **2 (a drawn band)** — ✅ shipped and played twice with no complaint about the band existing; ⚠ **that is
  absence of complaint, not a decision.** The contradiction with 「못내림만 표시하면 됨」 is **still unheard.**
- **3 (band width)** — **superseded.** The band became a *minimum distance* (`SUMMON_BAND_MIN_TILES` 6) at
  the user's own instruction, so `d` no longer exists as a question.

**Sent at wrap-up and still open**: **1** (before 시작 or during the fight — the one this build assumed) ·
**5** (a type or a designed cell) · **6** (healthiest or most hurt first) · **7** (five boxes or two) ·
**8** (does an armed slot still pan) · **9** (`CLAUDE.md`'s two false sentences) · **10** (a hull on the
pressed tile). ⚠⚠ **Every one shipped as its assumed default and none is closed.**

⚠⚠ **That value is the honest one today and it must be changed the moment the message is sent**, with the
answers written into the rows. `title-and-map`'s plan opened with five questions marked *"these go to the
user in ONE message"*, **the message was never sent**, all five defaults shipped silently, and one of them
descoped a whole step. `net_process` exists because of that day.

⚠ **Question 1 must go out first and alone.** Every other row is buildable under either answer.

| # | Question | What this build assumes, and what changes on the other answer |
|---|---|---|
| **1** | ⚠⚠ **Does the press-and-hold happen BEFORE 시작, or DURING the fight?** | **ASSUMED: BEFORE.** Three checkable reasons: it replaces the drag, which is planning-time · `Battle.step` returns on `not _committed` and `Battle.send` already refuses after the commit · 「손은 전투 중에 움직이지 않는다」 is still the shipped rule. ⇒ **`SLOT_HOLD_SEC` is a `look.gd` constant** (it is the repeat rate of an input; a player at 0.50 s reaches the same committed plan as one at 0.05 s). **On DURING**: it moves to `rules.gd` as arrival spacing, holding costs **6.5–16.1% of a 31 s fight**, and the gesture acquires a cost for the first time. ⚠ **`push-inland`'s 「저 배만 참여」 does NOT close this** — it decided you may act on boats during a fight; it did not decide that this gesture is how. **§8 names the four seams a live-fire version plugs into, and this build must leave all four visible** |
| **2** | **Allowlist (a drawn band) or the whole sea?** | **ASSUMED: BAND.** 「바다위에 초록색 지역」 is the user's own word, and a sea DENYLIST has an **empty denyset on all three islands** (measured, §2.1) — nothing to draw, nothing refused. ⚠ **It contradicts 「못내림만 표시하면 됨」 on its face and the user has to hear that.** §2.1 is why they are not the same rule |
| **3** | **How wide is the band?** `d` = 1 / 2 / 3 | **ASSUMED: 2.** Reachable landings are **82 / 75 / 80 at every value** (re-measured, §2.2), so this is purely how thick the green reads and how comfortable it is to hit: **18 / 36 / 54 px** at `ZOOM_MIN`, median catchment **1 / 2 / 3** tiles |
| **4** | ⚠ **Does the drag die?** | **ASSUMED: IT STAYS.** Both gestures coexist this round. ⇒ `grid.start_harbour`, `_derive_start_harbour`, `idle_soldier_rect`, `_soldier_hit_at` and the harbour stack are all untouched, and 「이 열세 중 누가 죽기 직전인지」 keeps its picture. **On DIES**: those five come out together, `H` may leave the map legend, and **the three nets that read `boat["home"]` lose their subject.** ⚠ **Do not delete any of them in this round** |
| **5** | **What does a slot hold — a type, or a designed cell?** | **ASSUMED: A TYPE.** Slot 1 = `CELL_MELEE`, slot 2 = `CELL_RANGED`, **slots 3–5 unbound and drawn empty.** ⚠ **NOT `BISON` / `CROW` / `LION`** — `TYPE_LABELS` has five entries and nothing range-checks it. The 세포 economy is blocked twice in `session-loop` and this build does not step over it |
| **6** | **Which body does a slot send first — healthiest or most hurt?** | **ASSUMED: HEALTHIEST.** That is `army.living_ids_of_type`'s already-documented order and costs no new rule. Most-hurt-first needs a new ordering in `army.gd` |
| **7** | **Five boxes on screen, or two that grow later?** | **ASSUMED: FIVE.** The user's own 「1~5번까지」. ⚠ Glyph count on the planning screen goes **3 → 8**, against 「글자가 너무 많고」. Two boxes would be 3 → 5 |
| **8** | ⚠ **While a slot is armed, does a left-drag on the field still pan the camera?** | **ASSUMED: NO** — an armed slot consumes every field press, so a press outside the band marks a refusal instead of silently starting a pan. Mitigations: the **wheel is ungated**, and the same number key disarms. **On YES**: a press on non-band water has to fall through to the pan and the refusal mark is lost, which is the failure the mark exists to prevent |
| **9** | ⚠ **`CLAUDE.md` says 「the keyboard does nothing in this game at all」 and 「the 1~5 summon keys are deleted」. This build makes both false.** | The user corrected the record themselves (*"정확히는 배 속이 별로여서 뺀거임 1~5번키"*), **but `CLAUDE.md` is not a file this plan may edit.** ⇒ **The builder must not touch it.** It goes up with question 1 |
| **10** | **Is a hull drawn on the pressed tile before the commit?** | **ASSUMED: NO** — §5 refuses the design's section-7 item 1, with the reason. `field_view`'s existing rule (no hull before the commit) exists because stacked hulls are a blob, and a pinned hold is exactly the stacking case. What marks the press instead is the **route line's own start point**, plus the ghost at the landing and the bar dropping a notch — three marks. Re-open this if the drag dies (question 4) |

---

## 1. What is being built, in one paragraph

**Five boxes appear bottom-right on the planning screen.** A number key arms one; the same key disarms it.
With a slot armed, a **green band of water hugging every coast** is what you press. A press puts one body
of that slot's type on a boat **at the pressed tile**, aimed at the **nearest landable coast tile by water
route**; holding puts out one more every `SLOT_HOLD_SEC` from the tile currently under the cursor. Release
stops it. Nothing departs until 시작, exactly as today.

⚠ **The structural sentence of the whole design**, quoted so it cannot be lost in the edits:

> **Today the press picks the DESTINATION and the sim derives the ORIGIN** (`grid.home_harbour_for`).
> **Sea summon picks the ORIGIN and the sim derives the DESTINATION.**

⚠ **This adds no cost and it is not allowed to invent one.** The design's §5 works it out: the hold changes
the SPEED of placing, never the AMOUNT (the roster is the cap), and flattening the crossing sets the one
term that ranked plans to a constant. **No cap, no cooldown, no wallet, no per-tile limit** —
「일단 빼고 만든 이후에 추가하자는 거임」 and 「병사수 제한은 없음」.

---

## 2. The measurements this plan is sized to — **re-run in Python off `islands.gd`, all three islands**

⚠ **Every figure below was reproduced for this plan** by re-implementing the shipped 8-way water rule
including `_water_step_open`'s diagonal shoulder guard, and **every one agrees with the design and with the
shipped docs** (water 724 / 690 / 726 · sendable 84 / 76 / 82). **That is a cross-check, not a run** —
§6's net rows reproduce them inside the engine.

### 2.1 Why the band is an ALLOWLIST while the land stays a DENYLIST

| Island | water tiles | water a boat cannot reach from land | **a sea denyset would be** |
|---|---|---|---|
| 0 | 724 | 0 | **empty** |
| 1 | 690 | 0 | **empty** |
| 2 | 726 | 0 | **empty** |

⇒ **A sea denylist draws nothing and refuses nothing.** 「소환할 수 있는 곳」 would have no referent.
⇒ **The two rules answer different questions.** The land rule answers 「어디에 상륙하나」 and stays a
denylist. The sea rule answers 「어디에 손을 대나」 and the user described it as a *place*.
⚠ **This is the one place this build deliberately does not copy the denylist, and the reason is written
here so nobody "fixes" it into consistency and deletes the region.**

### 2.2 The band, and what it costs you — **measured, at every `d`**

| | island 0 | island 1 | island 2 |
|---|---|---|---|
| water tiles | 724 | 690 | 726 |
| **band, `d = 1`** | **90** | **82** | **88** |
| **band, `d = 2`** ← this build | **190** | **174** | **186** |
| **band, `d = 3`** | **254** | **230** | **248** |
| landings reachable from the band, **at every `d`** | **82** | **75** | **80** |
| sendable coast tiles (today's drag) | 84 | 76 | 82 |
| ⇒ **the derivation costs** | **2 tiles** | **1 tile** | **2 tiles** |
| median / max catchment at `d = 2` | 2 / 10 | 2 / 10 | 2 / 10 |

⇒ **98% / 99% / 98% of the coastline stays reachable.** Whatever else is wrong with this gesture, it is not
that it takes your choices away.
⚠ **And the reachable-landing count does not move with `d` at all**, so question 3 is a comfort call and
nothing else. A check written to bite on `d` must bite on the **band size**, never on the landing count.

### 2.3 ⚠ The refutation, kept because a builder would otherwise assume its opposite

**「a sea press is easier to aim at than a 40 px coast tile」 is FALSE.** The real target is the *catchment*
— the sea tiles that map to one particular landing — and at `d = 2` the median catchment is **2 tiles**,
against a drop target that is already 1 tile. Out in open water the press is enormous and worthless:
55–118 sea tiles all resolve to the same four corner landings.

⇒ **The gesture does not fix aiming. It fixes the NUMBER of aims: 20–26 precision acts become 1**, and
wall clock falls from 7.4–12.9 s to 2.0–3.8 s. Both halves are kept.

### 2.4 The cadence — the derivation, because the derivation is the argument

`SLOT_HOLD_SEC = 0.20 s`.

- **Roster**: 10 at the start of a run (`START_MELEE` 6 + `START_RANGED` 4), at most 19
  (`10 + 3 × 3`, from `map_max_count_nodes_on_a_route()`). At 0.20 s that is **2.0 s** and **3.8 s**
- **Floor 0.084 s** — five rendered frames at 60 fps, the beat this repo has measured going entirely unseen
- **Ceiling 0.50 s** — the probe's figure for the gesture this replaces is **0.6–1.0 s a drag**; at 0.50 s
  the hold is no faster than the drag it exists to delete

---

## 3. The sim — exact edits, file by file

### 3.1 `src/sim/rules.gd` — the slot table and the band radius. **Nothing reads them yet.**

```gdscript
const SUMMON_UNBOUND := -1
const SUMMON_SLOTS := [CELL_MELEE, CELL_RANGED, SUMMON_UNBOUND, SUMMON_UNBOUND, SUMMON_UNBOUND]
const SUMMON_BAND_TILES := 2

static func summon_slot_count() -> int
static func summon_type_of(slot: int) -> int   # casts, like every other const-Array read
```

- ⚠ **`CELL_MELEE` is 0**, so the unbound test is `< 0` and **never `<= 0`**. A `<= 0` there refuses slot 1
  forever and every count check still passes, because slot 1 refusing looks exactly like an empty roster
- ⚠ **Slots 3–5 are `SUMMON_UNBOUND` and are NOT `BISON` / `CROW` / `LION`.** `session-loop`'s buildability
  review measured a previous attempt shipping *"bison, crow and lion with correct names and correct
  bodies"*
- ⚠ `SUMMON_BAND_TILES` is a **rule** constant: it decides what the sim refuses. The view never reads it —
  it asks `grid.can_summon_at`, so the picture and the refusal are one fact
- ⚠ Plain `const` Arrays. `const X := PackedInt32Array([...])` is a parse error on 4.7.1

### 3.2 `src/sim/grid.gd` — **ONE multi-source BFS, built in `load_rows`.** Independent of 3.1.

**New public surface:**

```gdscript
var summon_hops := PackedInt32Array()      # w*h. hops of WATER travel to the coast; UNREACHABLE elsewhere
var summon_landing := PackedInt32Array()   # w*h. the landing a boat born here sails to, or -1
var summon_field_builds: int = 0           # its own counter — see below

func can_summon_at(t: int) -> bool
func summon_landing_of(t: int) -> int
func summon_route(from_tile: int) -> PackedVector2Array
func _summon_field() -> void               # private; fills both arrays, bumps its own counter
```

**`_summon_field()` — the algorithm, in full, because the tie-break is the whole of the determinism:**

1. **The landing set is `coastal`**: every tile with `passable[t] != 0` that has at least one **8-way**
   water neighbour. ⚠⚠ **It is derived from water adjacency alone and NEVER from `sendable` or
   `water_fields`.** A summon has no harbour, and reading `sendable` is how the refused harbour rule comes
   back in through the back door. **Measured: on all three shipped islands `coastal` equals
   `sendable[hb]` for every harbour** (84 / 76 / 82), so nothing is lost by not asking
2. **Seed layer (hops = 1)**: every water tile 8-adjacent to a `coastal` tile. Its landing is the
   **lowest-indexed** such `coastal` tile
3. **BFS level by level over water**, honouring `_water_step_open` exactly as `_water_field` does. Within
   each level the frontier is walked in ascending `(summon_landing, tile)` order and a tile is claimed
   only once (`hops == UNREACHABLE`). ⚠ **That sort is what makes the tie-break exactly "lowest landing
   tile index"** — the same tie-break `_entry_water_tile` and `home_harbour_for` already use — rather than
   "whatever the queue happened to do", which silently changes the day `NEIGHBOURS` is reordered.
   **Proof it is exact**: a tile at level k+1 can carry any landing carried by an adjacent level-k tile and
   no other, so the min over those is the min over all shortest paths; by induction on k it holds
4. `summon_field_builds += 1`, once

**Where it goes in `load_rows`: immediately after the legend loop, BEFORE the `water_fields` / `sendable`
loop.** That ordering is structural: placed there it *cannot* read either table.

**`can_summon_at(t)`** — range-check, then `water[t] != 0 and summon_hops[t] >= 1 and
summon_hops[t] <= Rules.SUMMON_BAND_TILES`. ⚠ **There is deliberately no third `summonable` byte array.**
It would be a second copy of a fact `summon_hops` already holds, and this repo has watched a value counted
in two places diverge. The terrain pass asks per visible tile per frame — ~2,400 calls against 4,800 draw
calls it already makes.

**`summon_route(from_tile)`** — refuses (empty) unless `can_summon_at(from_tile)`. Then, exactly the shape
`water_route` already is:

- descend `summon_hops` one strictly-lower 8-way water neighbour at a time, **restricted to neighbours
  carrying the SAME `summon_landing`**, ties to the earliest `NEIGHBOURS` entry, guarded at `w * h`
- ⚠ **The same-landing restriction is not defensive padding.** Without it the descent drifts onto a tile
  whose lex-min landing is a different beach, and the drawn line then ends somewhere the appended landing
  is not. **Step 3 guarantees such a neighbour always exists**: `summon_landing[u]` is the min over exactly
  those neighbours
- reverse, run `_smooth_water_path` (unchanged), then append `tile_point(summon_landing_of(from_tile))`
- ⚠ **The landing must not be inside the array `_smooth_water_path` sees.** It is land, and a smoother that
  could see it would be free to pull a straight line across the beach — that file's own comment says so

**⚠⚠ `summon_field_builds` is a SECOND counter and `water_field_builds` is NOT reused.**
`water_field_builds`'s stated meaning is *one per harbour per `load_rows`*, and `net_coast` asserts
`water_field_builds == harbour_tiles.size()` exactly. Folding the summon BFS into it would force that
expected value up — **which is the design's own named trap** (*"Do not raise its expected value to make a
red go away"*). Two counters, two facts.
⇒ **`grid.gd`'s comment on `water_field_builds` is edited in the same commit** to name the sibling.

### 3.3 `src/sim/battle.gd` — the summon call. Needs 3.1 and 3.2.

```gdscript
func slot_reserve_ids(slot: int) -> Array
func summon(slot: int, tile: int) -> int
```

**`slot_reserve_ids(slot)`** — `army.living_ids_of_type(Rules.summon_type_of(slot))` filtered to
`soldier_state[i] == SoldierState.RESERVE`, order preserved (**highest HP first, ties to the lower id**).
Empty for an unbound or out-of-range slot. **There is no second `slot_reserve_count`** — the HUD calls
`.size()`; a count written twice diverges.

**`summon(slot, tile)`** returns the boat's **uid**, or **-1 with nothing at all changed**. Refused when:

1. `_committed` ⚠ **this line is seam #1 of question 1**
2. `grid == null or army == null`
3. `slot < 0 or slot >= Rules.summon_slot_count()`
4. `Rules.summon_type_of(slot) < 0` (unbound)
5. `not grid.can_summon_at(tile)`
6. `slot_reserve_ids(slot).is_empty()` (dry)
7. `grid.summon_route(tile).size() < 2` — a separate line, not an assumption, exactly as `send` carries it

On success it builds the boat **the same way `send` does** — `_arc_lengths`, `uid`, `TRANSIT`,
`soldier_pos = path[0]`, `pos = path[0]`, `target = grid.summon_landing_of(tile)` — with one difference:

```gdscript
"home": -1,
```

⚠⚠ **-1 is the honest value, not a sentinel.** `home`'s two stated jobs are (a) a diagnostic printed by
`tools/look/capture_landing.gd` and (b) *the only record of WHICH harbour this boat was judged against*.
**A summoned boat was judged against no harbour.** `_phase_landings` never reads it; nothing in `src/`
reads it. ⇒ **`battle.gd`'s `home` comment is edited in the same commit** to say so — a refutation that
lands in a different file than the claim does not propagate.

**⚠ `boat["target"]` must come from `grid.summon_landing_of(tile)` and from nothing else.** A `summon` that
called `home_harbour_for` to satisfy an existing net is the exact failure the design names, and §6's G6 is
the check that bites it.

**✅ Two expected walls that are NOT there — do not build for them:**

- **The return leg needs no change.** `_phase_landings` reverses the boat's own `path` and deletes it on
  arrival, so a summoned boat sails back to **the tile it was summoned at** and vanishes. **Do not add a
  return-to-harbour branch**
- **`_free_tiles_from` already spreads a stacked landing** — it walks *over* reserved tiles and collects
  only unreserved ones, so ten boats aimed at one beach unload in rings outward

**✅ No new `class_name` file**, so the `--import` trap does not bite. **No new `Run.State`**, so
`panel_view`'s red-패배-over-a-new-screen trap does not fire.

---

## 4. The shell — `src/shell/game.gd`. **The only file that may read `Input`.**

**New fields** (four):

```gdscript
var _armed_slot := -1          # which slot a number key has armed, or -1
var _summon_down := false      # a summon press is being held
var _summon_at := -1           # the tile under the cursor right now, or -1
var _summon_beat_sec: float = 0.0
```

⚠ **`_summon_beat_sec` is declared with an explicit type and NOT `:= 0.0`**, for the reason `_hold_sec`
one field up already carries in its own comment: `net_draw_leaf`'s literal scan reads `src/shell/`, `sec`
is one of its suffixes, and `_x_sec := <number>` is exactly the shape it is widened to catch. The zero is a
"no beat is pending" sentinel, not a duration.
⚠ **It is a different clock from `_hold_sec`** (the verdict / beak / map-travel hold) and the two never
overlap: a hold cancels every gesture on the first event it sees.

**The key branch** — `_unhandled_input`, a new `InputEventKey` branch placed **below** the title branch,
the hold guard and the map branch, and **above** the mouse block:

```
if event is InputEventKey and (event as InputEventKey).pressed:
    if (event as InputEventKey).echo: return          # ⚠ seam
    if battle == null or battle.committed(): return   # ⚠ seam #2 of question 1
    slot = KEY_1..KEY_5 -> 0..4, else return
    if slot == _armed_slot: _disarm(); return
    if battle.slot_reserve_ids(slot).is_empty():      # unbound OR dry — one test, because
        hud_view.note_chip(HudView.CHIP_SLOT_BASE + slot, false)   # slot_reserve_ids() is empty for both
        return
    _arm(slot)
```

⚠⚠ **The `echo` guard is not optional.** OS auto-repeat on a held number key delivers `pressed = true,
echo = true` many times a second and would toggle the arm silently. §6's L2 pushes that exact event.

⚠ **`KEY_1`..`KEY_5` are read as raw keycodes off the `InputEvent`.** There is no `[input]` section in
`project.godot` and none is added — what a net drives is the shell, not a settings file. Numpad keycodes
and rebinding are **out of scope**.

**The press branch** — inside `_on_left_press`, in this order:

1. panel (unchanged)
2. the start button (unchanged — chrome sits on top)
3. a placed boat's landing ring, `_ring_hit_at` (unchanged) — **before the summon, deliberately.** A
   landing ring is 18 px around a LAND tile and can overlap the water beside it; **losing undo is the worse
   failure**, which is the same argument the file already makes for "2 before 3"
4. ⇒ **NEW: `if _armed_slot >= 0`** — begin the stream and **consume the press** (question 8)
5. a soldier at the harbour, `_soldier_hit_at` (unchanged)
6. otherwise a pan (unchanged)

Beginning the stream is: `_summon_down = true`, `_summon_at = _tile_at(at)`, **fire one beat immediately**,
`_summon_beat_sec = Look.SLOT_HOLD_SEC`, and `field_view.set_summon_aim(_armed_slot, _summon_at)`.

⚠ **One body leaves on the frame of the press**, not one cadence later. Swink's bound on
input-to-response is under 100 ms and `SLOT_HOLD_SEC` is 200.

**Motion**, in `_unhandled_input`'s motion block, as a branch beside the drag branch and above the pan:
if `_summon_down`, `_summon_at = _tile_at(motion.position)` and `field_view.set_summon_aim(...)`.
If `_armed_slot >= 0` but the button is up, still update the aim — **the ring and the route have to be
readable before the press, not after it.**

**The beat**, in `_process`, placed after `if run.state() != Run.State.BATTLE: return` and **above**
`battle.step(delta)`:

```
if _summon_down and battle != null and not battle.committed():   # ⚠ seam #3 of question 1
    _summon_beat_sec -= delta
    while _summon_beat_sec <= 0.0:
        _fire_one_summon()
        _summon_beat_sec += Look.SLOT_HOLD_SEC
```

⚠ **`+=` and not `=`**, so a long frame does not swallow beats. **It terminates unconditionally**: each
pass adds a positive constant, whether or not the summon succeeded. That argument is written in the code,
because a `while` in a `_process` is the shape that hung a net for 148.7 s in this repo once.

**`_fire_one_summon()`**: if `battle.summon(_armed_slot, _summon_at) < 0`, call
`field_view.note_refusal(field_view.screen_to_world_px(...))` — **once per beat and never once per frame.**
「더 없다」 is a picture, not a silence, and a mark fired every frame is a solid disc.
⚠ The refusal position must come from the last cursor position the shell saw; `_summon_at` is a tile and
`tile < 0` (off the grid) is a refusal too, so the shell keeps the raw screen point beside it.

**Release** (`_on_left_release`): `_summon_down = false`, clear the aim's tile, **and leave the slot
armed** — the next press streams again with no key press in between.

**`_arm(slot)` / `_disarm()`**: set `_armed_slot`, call `hud_view.set_armed(_armed_slot)` and
`field_view.set_summon_aim(_armed_slot, _summon_at)`. **Two callers, one place**, so the HUD and the field
can never disagree about which slot is armed.

**`_disarm()` is also called from `_open_island` and `_enter_map_screen`** — a slot armed on island 1 must
not survive onto island 2, exactly as `_drag_soldier` does not.

⚠⚠ **`game.gd`'s comment 「three plan branches are gated, not four」 becomes false and must be rewritten in
the same commit** — it is now **five gated branches** (drag press, drag motion, drag release, the summon
key, the summon press) with the wheel still deliberately ungated. **The same sentence is in
`plan-then-watch`, section "Input", and that file must be edited too.** A refutation that lands in a
different doc than the claim does not propagate.

⚠ **Three stale comments say the keyboard is dead and all of them move in this round or none does**:
`game.gd` (twice — the header and the block above the mouse branch), `look.gd` (the deleted-key-boxes
paragraph), `hud_view.gd` (its header), `net_draw_leaf.gd` (the hud table's preamble) and `net_shell.gd`
(the `_key` helper's neighbours). ⚠ **`CLAUDE.md` is NOT in that list — see question 9.**

---

## 5. The screen — **pictures a person can judge**

⚠ **A feature is not done until its presentation is done.** *"이번 것처럼 무조건 연출까지 개발하는 게
기본임."*

### 5.1 `src/look.gd` — eleven new names, each with its floor and its ceiling

| Name | Value | Floor / ceiling, and the arithmetic |
|---|---|---|
| `SLOT_HOLD_SEC` | `0.20` | `>= 0.084` (five rendered frames, the beat this repo has measured going unseen); `<= 0.50` (at 0.50 the hold is no faster than the 0.6–1.0 s drag it replaces). §2.4 |
| `HUD_SLOT_ORIGIN_PX` | `Vector2(956.0, 632.0)` | **Measured, not chosen.** `956 + 5*56 + 4*8 = 1268 = 1280 - HUD_MARGIN_PX`. `y` shares the start button's own 632 so the two bottom widgets sit on one baseline; `632 + 64 = 696 <= 720` |
| `HUD_SLOT_SIZE_PX` | `Vector2(56.0, 64.0)` | `y` equals `HUD_START_SIZE_PX.y` — no new press height enters the game. `x >= 44` or a 34 px digit plus the bar's inset does not fit; `x <= 72` or five boxes run past 1268 |
| `HUD_SLOT_GAP_PX` | `8.0` | `>= 6` or two boxes read as one bar; `<= 14` (from the width sum) |
| `HUD_SLOT_FONT_SIZE_PX` | `34` | `> HUD_TIMER_FONT_SIZE_PX` 30 is **refused** — the clock must stay the loudest thing. `>= 28` (`HUD_START_FONT_SIZE_PX`, the smallest glyph that has ever read on this HUD); `<= 40` or a digit fills its box |
| `HUD_SLOT_TEXT_OFFSET_PX` | `Vector2(20.0, 44.0)` | `> (0, 0)` — **a glyph at the rect's own origin is a glyph that was never placed**, and that floor is the half proving the label exists. `20 + ~20 <= 56` across; `44 <= 64 - HUD_SLOT_BAR_H_PX - HUD_SLOT_BAR_BOTTOM_PX = 50` down, so the digit clears the bar |
| `HUD_SLOT_BAR_INSET_PX` | `6.0` | `>= 4` (a visible margin); `<= 16` or the bar is under 24 px and a notch drops under the snap floor |
| `HUD_SLOT_BAR_H_PX` | `8.0` | `>= 2.0` (snap floor, and this is HUD space with no zoom under it); `<= 14` or the bar competes with the digit |
| `HUD_SLOT_BAR_BOTTOM_PX` | `6.0` | `>= 4`; `<= 20` (from the offset sum above) |
| `COL_SUMMON_BAND` | `Color(0.353, 0.769, 0.475, 0.35)` | ⚠⚠ **The alpha is the load-bearing number.** `PRESS_ALPHA_OFF`'s own paragraph names **0.18** as the measured failure — the drop tint the user read as terrain. `0.35` is that failure doubled. Floor `0.25`; ceiling `0.50`, over which the sea reads as land. ⚠ Deliberately **not** `COL_START` / `COL_WIN` / `COL_NODE_CHEST`: those are a press, a verdict and a map node, and a value shared by two concepts diverges the first time one is tuned |
| `slot_rect_px(i)` · `slot_bar_rect_px(i)` | accessors | **The bar rect is derived from the box rect here and nowhere else.** `hud_view` draws it and `net_slots` hit-tests it; geometry written twice is what the two accessors exist to prevent |

**Two constants are REUSED and the paragraph that owns them is edited rather than duplicated:**

- `PRESS_BORDER_WIDTH_PX` (3.0) → the resting border · `PRESS_HOVER_BORDER_WIDTH_PX` (6.0) → the **armed**
  border. Their block says *"the hover is the border getting thicker"*; that sentence is widened to *"a
  resting border and a live one, of which hover is one instance and armed is the other"* — **edited in the
  file that makes the claim.** The pair's own inequality (`> PRESS_BORDER_WIDTH_PX + 2`, the snap floor)
  is exactly what makes the armed state readable
- `COL_SLOT_OFF` → an unbound or exhausted box. It is already *"the one tone the title needs that nothing
  else can stand in for: a slot that does not press"*, and these do not press either
- `COL_ALLY` (bar fill) and `COL_HP_EMPTY` (the rail) — the bar counts bodies, so it wears the body's
  colour, and the empty half already exists as *"the length a bar has before it is filled"*
- `CHIP_FX_SEC` and `REFUSE_SHAKE_PX` → the refusal shake, through `hud_view`'s **existing** `_chip_fx`
  drawer and `_chip_offset`, keyed `HudView.CHIP_START = 0` for the start button and
  `HudView.CHIP_SLOT_BASE + i` for the five boxes. ⚠ `note_chip`'s comment (*"Slot 0 is … the only slot
  there is"*) is edited in the same commit

⚠ **`look.gd`'s rule 「one rectangle must not answer to two verbs」 does not bite the armed box being
green.** That rule is about a press landing on the wrong thing, and **the slot boxes are not clickable at
all** — no hover, no press dip, no hit rect. `title-and-map` set the precedent with 설정하기: *a slot drawn
as unpressable behaves as unpressable, and those two are the same claim.*

⚠ **No new `Look.*_WIDTH_PX` name is introduced**, so `net_draw_leaf`'s world-width closure stays at
**twelve** rows. §6 asserts that literal so a builder who adds one has to place it on a side.

### 5.2 `src/view/field_view.gd` — **the band, and zero new leaves**

**New function (one): `set_summon_aim(slot: int, tile: int) -> void`** — 0 draws, the same shape as
`set_drag`: one call site for "armed", "moved" and "cleared", so the two fields can never disagree.
New private fields `_summon_slot := -1`, `_summon_aim := -1`.

**The band is a BLEND inside the existing terrain pass, not a new pass.**

```
fill = Look.terrain_colour_of_char(row[tx])
if battle.grid.can_summon_at(t): fill = fill.blend(Look.COL_SUMMON_BAND)
_paint_tile(Look.tile_rect_px(tx, ty), fill, Look.COL_GRID_LINE, Look.GRID_LINE_WIDTH_PX)
```

⚠⚠ **This is deliberate and it is what makes the band checkable.** A separate `_paint_band` leaf would add
a leaf, a draw call per band tile, and a new width row. As a blend it costs **zero extra draw calls**, and
a spy on `_paint_tile` sees the `fill` argument — so **"the band was drawn" is measured by two fills being
DIFFERENT, and dropping the blend makes the behaviour VANISH rather than diverge** (§6, V1).
⚠ `can_summon_at` must answer `false` outside the grid: the terrain loop runs `WATER_MARGIN_TILES` wide.

**The band is drawn from the moment the island opens, with no slot armed.** It is the answer to
*"뭐 어떻게 동작시키는지 전혀모르겠는데?"* — the region on screen at frame one is what says a press belongs
there.

**The aim marks reuse the drag's own two leaves and add nothing.** Inside the existing
`if not battle.committed():` block, beside the drag branch:

```
if _summon_slot >= 0 and _summon_aim >= 0 and not battle.slot_reserve_ids(_summon_slot).is_empty():
    landing = battle.grid.summon_landing_of(_summon_aim)
    ring col = COL_WIN if landing >= 0 else COL_LOSE, at Look.tile_point_px(grid.tile_point(landing))
    _paint_ring(..., Look.TARGET_RING_R_PX, ring col, Look.AREA_RING_WIDTH_PX)
    if landing >= 0: _paint_route(summon_route(_summon_aim) mapped through tile_point_px,
                                 Look.COL_ROUTE, Look.ROUTE_WIDTH_PX)
```

- ⚠⚠ **The ring sits on the DERIVED LANDING, not on the pressed tile.** The landing is the thing the player
  is choosing; the pressed tile is only how they said it
- ⚠ **The route is built from `grid.summon_route` — the same call `Battle.summon` builds its boat from** —
  so the screen cannot promise a crossing the sim does not make. That is the same guarantee the drag's own
  route already carries, inherited rather than re-derived
- **A dry slot draws neither** — *"the absence is the answer, and it arrives before the press instead of
  after it"*

**✅ Everything after the press already works with no edit at all.** A summoned boat is an ordinary `boats`
entry, so §6 of `_draw` gives it its landing ring, its remaining route, its ghost (fanned per landing tile)
and — after the commit — its hull, unchanged. **Written down so the round does not spend itself building
what is there.**

⚠ **No hull before the commit** — question 10, and the existing rule is untouched.

### 5.3 `src/view/hud_view.gd` — the five boxes

**New: two consts (`CHIP_START := 0`, `CHIP_SLOT_BASE := 1`) and five functions:**

| Function | Draws | What it is |
|---|---|---|
| `set_armed(slot: int)` | 0 | the shell's one call; clears in `bind` too |
| `_slot_colour(slot: int) -> Color` | 0 | armed → `COL_START` · bound → `COL_BUTTON` · unbound/exhausted → `COL_SLOT_OFF` |
| `_paint_slot_box(rect, bg, border_col, border_w)` | **2** | fill, then border. `border_w` is an **argument** so a spy can bite it |
| `_paint_slot_digit(face, at, text, fsize, col)` | **1** | the single digit |
| `_paint_slot_bar(back, back_col, fill, fill_col)` | **2** | the same two-rect shape `_paint_hp` already uses |

**`_draw` gains one block, and it is gated exactly like the start button:**

```
if not battle.committed():
    for i in Rules.summon_slot_count():
        rect = Look.slot_rect_px(i);  rect.position += _chip_offset(CHIP_SLOT_BASE + i)
        _paint_slot_box(rect, _slot_colour(i), COL_HUD_TEXT,
                        PRESS_HOVER_BORDER_WIDTH_PX if i == _armed else PRESS_BORDER_WIDTH_PX)
        _paint_slot_digit(face, rect.position + HUD_SLOT_TEXT_OFFSET_PX, str(i + 1), ..., COL_HUD_TEXT)
        if Rules.summon_type_of(i) >= 0:
            _paint_slot_bar(bar, COL_HP_EMPTY, filled part, COL_ALLY)
```

- ⚠ **The shake rides `rect.position` AND the glyph's `at` is derived from the shifted rect.** Shake the
  box alone and the text walks out of it; shake the text alone and it reads as nothing having moved —
  `combat-juice` item 8, and `hud_view` already does exactly this for the start button
- **The bar's fraction is `slot_reserve_ids(i).size() / army.living_ids_of_type(type).size()`**, with a
  zero denominator drawn as an empty rail. ⚠ **That denominator is only honest before the commit**, which
  is why the whole block is inside the commit gate: nobody dies during planning, so the denominator cannot
  move under the numerator. **This is seam #4 of question 1** — a live-fire version needs a real
  denominator recorded at island open
- **An unbound slot draws NO bar; an exhausted one draws an empty rail.** That rail is the only thing
  separating 「다 내보냈다」 from 「아직 아무것도 안 넣었다」
- ⚠ **Notch size, measured**: the bar is `56 - 2*6 = 44` px. Six melee → **7.3 px** a notch; the worst case
  the map can produce is 12 melee (`START_MELEE 6 + 3 × REWARD_MELEE 2`) → **3.7 px**, still above the
  2.0 px snap floor. A continuous fill is therefore enough and no per-notch geometry is built

### 5.4 The six pictures — **verify-look's whole grounds**

⚠ **Written as pictures, not as code facts. A row that can be satisfied by reading a file is not a screen
row.**

| # | What is on screen | How it is judged |
|---|---|---|
| **S1** | **Five boxes, bottom right, on the planning screen.** Two solid with a bar under the digit, three flat grey with no bar at all. They read as *"there is a place here and nothing is in it"* | A shot of an island the moment it opens. ⚠ **They must not sit over the army stack at the harbour** — measured clear (stack at screen x ≈ 597..701, boxes at 956..1268), but the shot is what decides |
| **S2** | **The armed box is unmistakable.** Green fill AND a doubled border — **two channels, so neither carries the read alone** | Press 1; a shot. Then press 1 again and the box goes back |
| **S3** | **A green band of water hugs every coast, from frame one, with nothing armed.** At `ZOOM_MIN` it is a **36 px ribbon** — thick enough to see at the zoom an island opens at, thin enough that it reads as a shoreline rather than as *"the sea is green"* | The same opening shot. ⚠⚠ **This is the one positive mark on the field and it is the exact shape the user deleted for the land** (「못내림만 표시하면 됨」). §2.1 is why it is not that rule coming back, and the picture has to be argued to the user on that basis — **because it will look like it** |
| **S4** | **While you hold, boats appear where the cursor is** — one route line and one ring on the shore per beat, fanning out as you sweep. Held on one spot for two seconds, **ten routes fan ashore from one stretch of water** | A driven press-hold-sweep, shots across it. ⚠ **This is the frame this design has that the drag never had, and it is what is being judged** |
| **S5** | **An empty slot says so.** Hold past the roster: the bar sits empty, a refusal mark blinks at the cursor **once per beat and not once per frame**, and **the hold does not end** | Driven. ⚠ A solid red disc at the cursor means the refusal is firing per frame |
| **S6** | **A press outside the band says no**, on the frame of the press, and no boat appears | Press on open ocean far from any coast |

---

## 6. The nets — **each row with the mutation that must redden it**

⚠ **Invert every one.** An uninverted check proves "it runs", not "it measures". **If the inversion does
not bite, suspect the check LAST** — first confirm the mutation actually landed. String replacement has
silently matched zero times, twice.
⚠ **Every bound below is a LITERAL.** Nothing is read back off the grid or the constant under test.

**Two new nets, landing together** (**15 → 17**; the round today is 15 nets / 2263 checks / 4.4 s green, and ⚠ **`CLAUDE.md`'s 「14 nets, 1933 checks」 is already stale** — re-derive it, never nudge it). `net_summon.gd` is pure sim (`.new()`, no tree);
`net_slots.gd` drives the shell and spies the two views.

### 6.1 `tests/nets/net_summon.gd` — the grid and the battle

| # | Check | ⚠ Mutation that must redden it |
|---|---|---|
| **G1** | The band at `SUMMON_BAND_TILES = 2` holds exactly **190 / 174 / 186** water tiles on islands 0 / 1 / 2 | `can_summon_at`'s `<=` → `<` (⇒ 90 / 82 / 88) |
| **G2** | **No `passable` tile is ever summonable**, on any island; every summonable tile has `water[t] != 0` | drop the `water[t] != 0` clause in `can_summon_at` |
| **G3** | Every band tile's landing is `>= 0`, is `passable`, and has an 8-way water neighbour | seed the BFS from every `passable` tile instead of `coastal` (⇒ inland landings) |
| **G4** | The landings reachable from the band are exactly **82 / 75 / 80**, against sendable **84 / 76 / 82** | seed only from **orthogonally** adjacent water (4-way) ⇒ the corner landings drop out ⇒ 82 → 80. ⚠ **`SUMMON_BAND_TILES` 2 → 1 does NOT bite this row** (§2.2) and that is stated in the net |
| **G5** | For **every** band tile: `summon_route(t).size() >= 2`, `path[0] == tile_point(t)`, `path[last] == tile_point(summon_landing_of(t))`, and **every waypoint except the last is a water tile** | make `_straight_is_all_water` return `true` unconditionally ⇒ routes cut over land |
| **G6** | ⚠⚠ **A grid with ZERO harbours still fills the band**, `can_summon_at` answers true somewhere, and `Battle.summon` succeeds on it — **while `Battle.send` refuses every tile** | make `_summon_field` seed from `sendable[0]`, or make `summon` derive its landing from `home_harbour_for`. **This is the design's named trap written as a check** |
| **G7** | `summon_field_builds == 1` after `load_rows`, and **still 1** after sixty `can_summon_at` / `summon_landing_of` / `summon_route` calls. `water_field_builds` is **unchanged** at `harbour_tiles.size()` | build the summon field inside `can_summon_at` (the per-press BFS the design refuses) |
| **G8** | On a hand-built fixture where one water tile touches two landings, `summon_landing_of` is the **lower tile index**; on a second fixture where ascending-water-tile order and ascending-landing order **disagree**, a hop-2 tile still carries the lower landing. ⚠ **Both fixtures carry a self-check that the two orders really do disagree** — otherwise the row is vacuous | fixture 1: `t < best` → `t > best` in the seed loop. fixture 2: delete the per-level frontier sort |
| **B1** | `summon(0, band tile)` returns `uid >= 0`, `boats` grew by one, the soldier is `TRANSIT` at the pressed tile, `boat["target"] == summon_landing_of(tile)`, **`boat["home"] == -1`** | `"home": 0` |
| **B2** | **Seven refusals, each with `boats.size()` unchanged and the soldier still `RESERVE`**: committed · slot -1 · slot 5 · unbound slot 2 · a land tile · a water tile with `hops > 2` (with a self-check that 534 such tiles exist on island 0) · a dry slot | drop any one guard. ⚠ For the unbound arm: `summon_type_of(slot) < 0` → `<= 0`, which refuses slot 0 (`CELL_MELEE == 0`) — the row must bite that too |
| **B3** | Repeated `summon(0, t)` hands out bodies **highest-HP first, ties to the lower id**, on a fixture where HP order ≠ id order | `slot_reserve_ids` returns them in id order |
| **B4** | Summoning slot 0 **twenty times** on island 0 with the starting force yields exactly **6** boats and refuses the other fourteen. Literal 6 | drop the `RESERVE` filter in `slot_reserve_ids` |
| **B5** | A summoned boat lands, turns `RETURNING`, its reversed path's last waypoint is **the tile it was summoned at**, and it leaves `boats` on arrival | delete `back.reverse()`, or add a `harbour_tile(boat["home"])` branch to `_phase_landings` |
| **B6** | ⚠ **Side by side in one function**: a `send` boat has `home >= 0`, a `summon` boat has `home == -1`, and both land | make `summon` call `home_harbour_for` |
| **B7** | A mixed plan (one `send`, one `summon`) commits, both cross, both unload, and `_free_tiles_from` puts them on different tiles | make `_free_tiles_from` refuse to walk over reserved tiles |
| **R1** | `SUMMON_SLOTS` has exactly 5 entries, exactly **two** are `>= 0`, **none is `>= 2`** (no `BISON` / `CROW` / `LION`), and `summon_type_of` returns `CELL_MELEE` / `CELL_RANGED` for 0 / 1 | put `BISON` in slot 2 |

### 6.2 `tests/nets/net_slots.gd` — the shell and the two views

⚠⚠ **Every input row calls `game._unhandled_input(ev)` DIRECTLY and never `root.push_input()`.** Headless
the window is 64x64 so the stretch transform is 0.05: a click aimed at a widget **arrives at (2000, 6520),
hits nothing, and raises no error.** Keys pass through `push_input` fine — so **half an input suite can be
green while the other half is dead.** The key rows go through the same call as the mouse rows so the two
are not driven by two mechanisms.
⚠ The camera is parked at `zoom = 1.0`, `cam_px = Vector2.ZERO`, no shake, so world px and screen px
coincide — the same setup `net_shell` already uses.
⚠ The beat rows drive `game._process(dt)` **by hand with explicit dt literals**; a headless frame is
~6.9 ms and `pump_frames` cannot pin a 0.20 s cadence.

| # | Check | ⚠ Mutation that must redden it |
|---|---|---|
| **L1** | `KEY_1` arms slot 0; `KEY_1` again disarms it; `KEY_2` moves the arm | delete the `KEY_1..KEY_5` branch |
| **L2** | ⚠ An event with `pressed = true, echo = true` on an armed slot **leaves it armed** | delete the `echo` guard |
| **L3** | `KEY_3` (unbound) leaves `_armed_slot == -1` **and** puts a refusal entry in `hud_view._chip_fx` at `CHIP_SLOT_BASE + 2` | drop the unbound test; or pass `ok = true` |
| **L4** | A press on a band tile while armed creates **one** boat **before any `_process` runs at all** | move the first summon into `_process` |
| **L5** | Holding: `_process(0.05)` × 3 (0.15 s) ⇒ still **1** boat; one more 0.05 (0.20 s) ⇒ **2**. Separately, `t.eq(Look.SLOT_HOLD_SEC, 0.20)` as a self-check ⚠ **the dt and the counts are literals; the constant is pinned once, elsewhere** | fire one per frame (drop the accumulator); or read the cadence as 0.0 |
| **L6** | Motion during the hold moves the origin: boat 2's `path[0]` is tile **B**, not tile A | use the press tile for every beat |
| **L7** | Release stops the stream (5 × 0.2 s ⇒ no new boat) **and the slot stays armed** | never clear `_summon_down`; or disarm on release |
| **L8** | Holding a **dry** slot pushes exactly **one** `FxKind.REFUSE` into `field_view._fx` per beat over three beats, and `_summon_down` is still true. ⚠ Only `game._process` is pumped, so `_fx` never ages | fire the refusal every frame |
| **L9** | A press outside the band creates **no** boat and pushes **one** refusal | drop the `can_summon_at` test in `Battle.summon` |
| **L10** | After `commit()`: the key arms nothing, a press creates nothing, and the beat fires nothing | remove any of the three commit gates |
| **L11** | The **wheel still zooms while armed**, and disarming restores the pan | gate `_on_wheel` on `_armed_slot < 0` |
| **L12** | The five `Look.slot_rect_px` rects land on screen, do not overlap each other, and are **disjoint from every `idle_soldier_rect` converted to screen space at `ZOOM_MIN`** | `HUD_SLOT_ORIGIN_PX.x` 956 → 600 |
| **V1** | ⚠⚠ **Spy `_paint_tile`.** In one frame, the `fill` handed for a **summonable** water tile **differs** from the one handed for a non-summonable water tile, and its green channel is higher than `COL_WATER`'s. Self-check first: both kinds occur in the frame | delete the blend ⇒ the two fills become **equal** — the behaviour VANISHES rather than diverges |
| **V2** | V1 holds **with no slot armed and on the first drawn frame** | gate the blend on `_summon_aim >= 0` |
| **V3** | Spy `_paint_ring`. With slot 0 armed and the aim on a band tile, a ring is drawn at `Look.tile_point_px(grid.tile_point(summon_landing_of(aim)))` — **the landing, not the pressed tile** | draw the ring at the pressed tile |
| **V4** | Spy `_paint_route`. The drawn `points` equal `summon_route(aim)` mapped through `tile_point_px`, **more than two entries on a bent route** | draw a two-point straight line (⚠ `net_draw_leaf`'s whole-array shape check already pins `draw_polyline(points)` and cannot see this one — that is why V4 is a runtime row) |
| **V5** | A **dry** armed slot draws **zero** rings and **zero** routes for the aim | drop the dry test |
| **V6** | Spy `_paint_slot_bar`. On island 0 with the starting force, one summon on slot 0 shrinks the fill rect's width to exactly **5/6** of the back rect's. Literal 6 | draw the fill at the back's full width |
| **V7** | Slots 3–5 produce **zero** `_paint_slot_bar` calls; an exhausted slot 1 produces **one**, with fill width 0 | draw a bar for unbound slots |
| **V8** | Spy `_paint_slot_box`. The armed box gets `PRESS_HOVER_BORDER_WIDTH_PX`, the others `PRESS_BORDER_WIDTH_PX`, and the two differ by **more than 2.0** (literal) | pass the resting width in both branches |
| **V9** | The slot row is drawn (5 boxes) before the commit and **0 times** after it | drop the commit gate in `hud_view._draw` |

### 6.3 Rows that move in existing nets

| Net | What changes |
|---|---|
| `net_draw_leaf` | `_table()` gains `set_summon_aim` (field_view 45 → **46**) and five hud names (13 → **18**). **`total_funcs` 125 → 132 and `total_leaves` 31 → 34, both re-derived by hand from the five per-file tables** — ⚠ *a literal that moves by whatever the last edit happened to be is a literal nobody re-derives*. **`_world_widths` stays at twelve rows** and the net asserts that literal, so a width added tomorrow has to land on a side |
| `net_coast` | untouched, **and that is the point** — `water_field_builds == harbour_tiles.size()` must still hold. ⚠ **If it goes red, the summon BFS was folded into `_water_field`; do not raise the expectation** |
| `net_boat` · `net_plan` | untouched — `send` is unchanged and the three `boat["home"]` rows keep their subject (question 4) |
| `net_citations` | the new comments **name docs, never path them, never cite a line number.** ⚠ A pathed citation inside a doc is not caught by that net — check the ones in this file by hand |

---

## 7. The order the pieces land in

1. `rules.gd` — the slot table and the band radius. Nothing reads them yet
2. `grid.gd` — `_summon_field` in `load_rows`, plus the three readers. **Independent of 1** except for
   `SUMMON_BAND_TILES`
3. `battle.gd` — `summon` and `slot_reserve_ids`. Needs 1 and 2
4. `look.gd` — the eleven constants, the two accessors, and the three edited paragraphs
5. `field_view.gd` **plus `net_draw_leaf`'s table, in ONE edit**
6. `hud_view.gd` **plus `net_draw_leaf`'s table, in ONE edit**
7. `game.gd` — the key branch, the press branch, the beat, the clears, and the rewritten
   「three plan branches」 comment
8. `net_summon.gd`, then `net_slots.gd`, then the docs

⚠ **Split 5 or 6 across two edits and the round is red for the gap, and a red that is expected is a red
nobody reads.**

---

## 8. ⚠⚠ Question 1's four seams — **named, and none of them may be sealed**

This build assumes planning-time. **A live-fire version is four edits, and this plan's job is to leave all
four visible rather than to design around them.**

| # | Seam | What a live-fire version does to it |
|---|---|---|
| **1** | `Battle.summon`'s first line, `if _committed: return -1` | deleted, and the boat's `t` starts at 0 while `elapsed` is already running |
| **2** | `game.gd`'s key branch: `if battle == null or battle.committed(): return` | the commit test comes out; the slot row keeps drawing |
| **3** | `game.gd`'s beat: `if _summon_down and battle != null and not battle.committed():` | the commit test comes out. ⚠ **`Look.SLOT_HOLD_SEC` moves to `rules.gd`** — during the fight it is the arrival spacing of reinforcements and it changes what happens |
| **4** | `hud_view._draw`'s `if not battle.committed():` around the slot row, and the bar's denominator | the denominator must become a value recorded at island open, because bodies die during a fight and the bar would otherwise climb |

⚠ **Do NOT** hard-code the cadence in `game.gd`, fold the summon into a planning-only helper, or delete the
`_committed` test by construction. **The seam a live-fire version plugs into is the thing worth
preserving** — the same argument `speed-off-open-landing` made for keeping `Battle.step(dt)` taking a bare
delta after the multiplier was deleted.

---

## 9. What this plan does NOT do

- **The 세포 / 오브젝트 economy.** Slots 3–5 stay unbound and are **not** filled with `BISON` / `CROW` /
  `LION`. Re-binding a slot at runtime IS the economy
- **Any brake, cap, cost, wallet, cooldown or per-tile limit.** The user deferred it knowingly, twice
- **Delete the drag**, `grid.start_harbour`, `_derive_start_harbour`, `idle_soldier_rect`,
  `_soldier_hit_at`, the harbour stack, or `H` from the map legend — question 4
- **Edit `CLAUDE.md`** — question 9
- **Retune `GHOST_FAN_PX`, `BOAT_SPEED`, `TIME_LIMITS` or `ZOOM_MIN`.** `GHOST_FAN_PX` is *named* in §10 as
  the constant that moves **if** the user says a pinned hold stops reading as one landing. **Naming is not
  tuning**
- **Mid-crossing redirect, recall of a summoned boat by ring, or steering after the commit.** ⚠ The
  existing `_ring_hit_at` recall works on a summoned boat for free and is left working
- **Click the slot boxes with the mouse**, hover them, or dip them on press
- **Numpad keycodes, key rebinding, `project.godot`'s `[input]` section**
- **`title-and-map` step 5, the long map, the chest's payout, or the loss condition**
- ⚠ **Measure whether this is fun.** §10 lists what has no number; **planning cannot decide it**

---

## Acceptance — **written so inference cannot pass a row**

⚠⚠ **A build existing, a net being green, or an agent having walked through it are NOT acceptance.**
Rows marked **user only** close when the user says so, and **nobody else may close them.**

| # | Row | Who closes it |
|---|---|---|
| **A1** | On all three islands the band at `d = 2` is **190 / 174 / 186** tiles and reaches **82 / 75 / 80** landings, against sendable **84 / 76 / 82** | verify-run, against §2.2's literals |
| **A2** | **No land tile is summonable**, and a water tile more than 2 hops from the coast is refused | verify-run |
| **A3** | ⚠⚠ **On a grid with no harbours at all, a summon still works and a `send` still refuses everything** | verify-run. **This is the row that proves the summon has no harbour** |
| **A4** | A summoned boat's every waypoint except the last is water; its `target` is `summon_landing_of(pressed)`; its `home` is **-1**; it lands, reverses, and vanishes **at the tile it was summoned at** | verify-run |
| **A5** | Holding slot 1 for ten seconds on the starting force places exactly **6** bodies and then refuses forever | verify-run |
| **A6** | `summon_field_builds == 1` per island and does not move across sixty reads; `water_field_builds` is unchanged at `harbour_tiles.size()` | verify-run |
| **A7** | Every mutation in §6 reddens the row it is paired with. ⚠ **A mutation that does not bite is reported as a finding, not silently dropped** — first confirm the edit landed | verify-run |
| **A8** | S1–S6 all read right | verify-look |
| **A9** | ⚠ **The band does not read as the deleted green wash.** It is a ribbon along the coast, not "the sea is green", and it is legible at `ZOOM_MIN` without being louder than the terrain | verify-look. ⚠ **This is the row most likely to be reported green from code alone** |
| **A10** | ⚠ **The user launches it and finds the control without being told** — 「1~5」 and a press on the green | **user only.** ⚠ The last round failed on exactly this (*"뭐 어떻게 동작시키는지 전혀모르겠는데?"*) with every check green. **No instrument in this repo measures it** |
| **A11** | ⚠ **The user says 「조작감이 너무 ㅈ같음」 is answered** — the hand is deciding rather than aiming | **user only** |
| **A12** | ⚠ **The user says the five boxes plus the green band are not too much on screen**, against their own 「글자가 너무 많고」 | **user only** |
| **A13** | ⚠⚠ **The user answers question 1.** Until then this build is a bet, and §8 is the receipt | **user only** |

---

## 10. Where a number was wanted and there is none

**Written down rather than estimated.**

1. ⚠⚠ **What a 2.0 s trickle costs in HP.** The only version of a cost that does not invent a system turns
   on it. `tools/probe/run_run.gd` can measure it: land ten bodies simultaneously vs at 0.20 s spacing, on
   the same beach, and read the casualty difference. **Not in this round**
2. **What the gesture count actually becomes.** The probe counts 10–13 drags today; **nobody has counted a
   hold**, and §2.3's "1" is arithmetic
3. **Whether the region is findable without being told.** A10. Only the user
4. **Whether flattening the crossing changes which beach wins.** The probe has never run with a flat
   crossing
5. **What `d` is comfortable at `ZOOM_MIN`.** A 36 px ribbon is arithmetic off `TILE_PX * 0.45`; nobody has
   looked at one
6. **How the band reads on the long map.** Every number here is off the three 48 × 32 islands. The shipped
   long map is 144 × 32 and **was not measured**
7. ⚠ **Whether a pinned hold's ghost fan still reads as one landing.** `GHOST_FAN_PX` is 9 px a rank, so
   ten ghosts reach 81 px and nineteen reach 162 px — **and that constant's own comment says past 14 px
   thirteen ghosts stop reading as ONE landing.** Mitigated by the sweep; judged by the user; if it fails,
   `GHOST_FAN_PX` is the one constant that moves

---

## 11. Risks carried into this plan

1. ⚠⚠ **Question 1 is unanswered and this build bets on one side of it.** If the answer is DURING, seam 3
   moves a constant between files and the gesture acquires a cost — a change to what the plan *means*, not
   only to where a number lives
2. ⚠⚠ **The band is a positive mark on the field and the user deleted exactly that shape for the land.**
   §2.1 argues they are different questions; **the user has not heard that argument.**
3. **The alpha.** `PRESS_ALPHA_OFF`'s own paragraph names 0.18 as a measured failure the user read as
   terrain. 0.35 is a bet on double being enough
4. **Five more glyphs on a screen the user asked to simplify.** A12
5. **`net_draw_leaf`'s two hand-derived totals both move.** A literal nudged rather than re-derived is this
   repo's named failure, and it has already happened once on this table
6. **`CLAUDE.md` carries a sentence this build makes false** for as long as question 9 is unanswered
7. **The pinned hold.** Ten hulls and ten ghosts on one tile in two seconds is a state that previously took
   nineteen deliberate drags. §10 row 7
8. **The drag survives beside its replacement**, so the plan screen carries two gestures at once. That is
   deliberate (question 4) and it is more to explain, not less
9. **Nothing here puts a cost anywhere**, and the design's §5 says the game has none that binds. **This
   round must not invent one**, and that restraint is itself a risk carried forward

---

## Round log

### Round 1 — builder, main tree

changed   `src/sim/rules.gd` (the slot table, the band radius, two accessors) ·
`src/sim/grid.gd` (`summon_hops` · `summon_landing` · `summon_field_builds` · `_summon_field` ·
`_summon_frontier_before` · `can_summon_at` · `summon_landing_of` · `summon_route`, built in
`load_rows` ABOVE the harbour loop) · `src/sim/battle.gd` (`slot_reserve_ids` · `summon`, with
`"home": -1`; `send` untouched) · `src/look.gd` (eleven names, two accessors, three existing
paragraphs edited rather than duplicated) · `src/view/field_view.gd` (`set_summon_aim`, the band as a
BLEND inside the existing terrain pass, the aim ring and route on the existing two leaves) ·
`src/view/hud_view.gd` (`CHIP_START` / `CHIP_SLOT_BASE` · `set_armed` · `_slot_colour` and three
leaves) · `src/shell/game.gd` (`_on_summon_key` · `_slot_of_keycode` · `_arm` / `_disarm` ·
`_begin_summon` · `_fire_one_summon`, the press branch, the motion branch, the beat) ·
`tests/nets/net_summon.gd` and `tests/nets/net_slots.gd` (both new) · `net_draw_leaf`'s table ·
`plan-then-watch`'s "Input" section, where the 「three plan branches」 claim lived.

why       §7's order, whole, in one round. Every figure in §2 was reproduced INSIDE the engine rather
than trusted from the plan: the band is **190 / 174 / 186**, it reaches **82 / 75 / 80** landings
against sendable **84 / 76 / 82**, and island 0 holds **534** water tiles outside it. `net_coast` was
not touched and is still green — the summon BFS got its own counter, which is the trap §3.2 named.

closed    **Nothing.** A green round is not acceptance, and A1–A7 are verify-run's to close, A8–A9
verify-look's, A10–A13 the user's. What can be said is that every §6 row exists and runs.

not closed  **All thirteen acceptance rows.** ⚠⚠ **Question 1 is still unanswered and this build
stands on one side of it** — §8's four seams are all present and none is sealed (`Battle.summon`'s
first line, the key branch's commit test, the beat's commit test, and `hud_view._draw`'s gate around
the slot row, each with a comment naming it as a seam). ⚠ **`CLAUDE.md` now carries three false
sentences and this plan forbids the builder from editing it** (question 9): 「the keyboard does nothing
in this game at all」, 「the 1~5 summon keys are deleted」, and — new today — its `docs/plans/` row,
which says `1.ready` is empty and `2.active` holds only `title-and-map`. The first two are question
9's; **the third is a folder-state fact with nothing to do with question 9 and it is open only because
the prohibition is written as a blanket.** ⚠ Its 「14 nets, 1933 checks」 round line was already stale
before this round and is now 17 / 2508.

nets      **17 nets · 2508 checks · 4.8 s · green**, stderr clean. Was 15 / 2263 / 5.8 s. Two new:
`net_summon` (122, pure sim) and `net_slots` (123, shell + two view spies). **Twenty-six mutations
were run, each as one command carrying its own run**, so no two fingerprints are compared across an
edit; every one bites except the three recorded below.

---

**Shipped**, in the order §7 names:

| File | What landed |
|---|---|
| `src/sim/rules.gd` | `SUMMON_UNBOUND` · `SUMMON_SLOTS` · `SUMMON_BAND_TILES` · `summon_slot_count` · `summon_type_of` |
| `src/sim/grid.gd` | `summon_hops` · `summon_landing` · `summon_field_builds` · `can_summon_at` · `summon_landing_of` · `summon_route` · `_summon_field` · `_summon_frontier_before`, built in `load_rows` **above** the harbour loop |
| `src/sim/battle.gd` | `slot_reserve_ids` · `summon`, with `"home": -1`. `send` untouched |
| `src/look.gd` | 11 new names + `slot_rect_px` / `slot_bar_rect_px`; three existing paragraphs edited rather than duplicated |
| `src/view/field_view.gd` | `set_summon_aim`, the band as a BLEND in the existing terrain pass, the aim ring and route on the existing two leaves |
| `src/view/hud_view.gd` | `CHIP_START` / `CHIP_SLOT_BASE` · `set_armed` · `_slot_colour` · `_paint_slot_box` · `_paint_slot_digit` · `_paint_slot_bar` |
| `src/shell/game.gd` | `_on_summon_key` · `_slot_of_keycode` · `_arm` / `_disarm` · `_begin_summon` · `_fire_one_summon`, the press branch, the motion branch, the beat |
| `tests/nets/` | **`net_summon` (120 checks)** and **`net_slots` (121)**; `net_draw_leaf`'s table |

**Measured, and every figure in §2 reproduced inside the engine**: the band is **190 / 174 / 186**,
it reaches **82 / 75 / 80** landings against sendable **84 / 76 / 82**, and island 0 holds **534**
water tiles outside it. `net_coast` is untouched and still green — the summon BFS has its own counter.

### ⚠⚠ Three checks in §6 were paired with a mutation that DOES NOT BITE, and all three are structural

**Measured, not argued.** Each one is now written into the code AND into the net beside the row, so
the green is not read as covering a line it does not.

| Row | The mutation §6 named | What was measured |
|---|---|---|
| **G2** | drop `water[t] != 0` in `can_summon_at` | **Green.** `_summon_field` writes `summon_hops` on water only, so land already carries `UNREACHABLE`. The clause is kept as the statement of the rule; what bites a seed change is **G1's band size** (measured: `can_summon_at` forced to `true` takes island 0 from 190 to 724) |
| **B2**, land / far-water arms | drop `can_summon_at` in `Battle.summon` | **Green.** `grid.summon_route` refuses on the same predicate and `summon` then refuses on the short path. Both lines are kept for the reason `send` keeps its own pair |
| **G5** | — | **The same-landing restriction in `summon_route` was not measurable on ANY shipped island**: their coasts are long enough that neighbouring hop-1 tiles share a landing. ⇒ G5 grew a *last water waypoint touches the landing* clause, and **G8's fixture 2** is where it bites — without the restriction the walk ends three tiles from the landing that gets appended |

**Two more holes were found by inverting and are now closed:**

- **The beat's own commit gate was unmeasurable** because `Battle.summon` refuses after the commit
  anyway (seam #1), so no boat appeared either way. ⇒ L10 now reads the **refusal count** as well:
  an ungated beat blinks a mark at the cursor every 0.20 s for the whole fight. It also had to stop
  releasing the press before committing, or `_summon_down` was already false and the gate was never
  reached at all.
- **`while _summon_beat_sec <= 0.0` held a beat back a whole frame** on a `1.4e-17` float residue
  (four 0.05 frames against a 0.20 cadence). ⇒ `<= Rules.EPS`, the same boundary `Battle._arrived`
  already carries.

**Twenty-six mutations were run, each as one command with its own run**, so no two rounds' fingerprints
are being compared across an edit. Every one bites except the three recorded above.

### What did NOT change, deliberately

The drag, `grid.start_harbour`, `_derive_start_harbour`, `idle_soldier_rect`, `_soldier_hit_at`, the
harbour stack, `H` in the legend (question 4) · `TIME_LIMITS` · `GHOST_FAN_PX` · any cap, cooldown or
wallet · `CLAUDE.md` (question 9 — **it still carries two sentences this round makes false**) ·
`docs/design/`.

### ⚠ One number in §6 was wrong and was re-derived rather than copied

§6.3 said `net_draw_leaf`'s `hud_view` table held **13** names and that `total_funcs` would land on
**132**. It has held **12** since the speed chips died, so the answer is **131** (46 + 17 + 21 + 18 +
29) and leaves are **34** (13 + 6 + 4 + 4 + 7). Both totals were re-derived by hand from the five
per-file tables. **This is exactly the failure the plan warned about, caught by obeying the warning.**

### Open

**A1–A7 are verify-run's, A8–A9 are verify-look's, and A10–A13 are the user's.** Nothing here closes
any of them: a green round is not acceptance, and **question 1 is still a bet.**

---

### Round 2 — fixer

changed   `src/shell/game.gd` (`_arm` cancels a drag in flight; the false ring/band geometry in
`_on_left_press` corrected) · `src/view/field_view.gd` (`band_on` — the band goes with the boxes) ·
`src/view/hud_view.gd` (`_chip_tint` pulled out of `_chip_colour`; `_slot_colour` tests empty before
armed and now carries the tint) · `tests/nets/net_slots.gd` (five new rows and two helpers) ·
`tests/nets/net_summon.gd` (`_fresh` uses its argument) · `tests/nets/net_draw_leaf.gd` (the table) ·
`CLAUDE.md`, `docs/plans/2.active/title-and-map.md`, `docs/design/sea-summon.md` (doc rot).

why       An adversarial judge bounced round 1 on eight findings. **The sim half was measured and
closed** — the band, the routes, the one-pass BFS, the beat. **Every defect was in the shell, the view
and the docs.**

closed    **F1 — the signature fake, and it was one missing line.** `_arm` set `_armed_slot` and left
`_drag_soldier` alone; the motion branch is `if _armed_slot >= 0 … elif _drag_soldier >= 0`, so arming
mid-drag froze the candidate ring on the tile the key was pressed over while `_on_left_release` went on
handing `battle.send` the tile the cursor ended on — **screen 1461, sim 146.** `_arm` now cancels the
drag the same way the `_hold_sec` gate does, and `net_slots._arming_mid_drag_cancels_the_drag` presses
the harbour stack, arms, moves, releases and asserts the sim did nothing. ⚠ This file had pressed
`KEY_1` twelve times and **never touched `_drag_soldier` once**: the two gestures were each measured
alone and their collision was measured nowhere.
**F2 — the band goes with the boxes.** ⚠ **The choice and what pins it**: after the commit
`Battle.summon` refuses everything and `hud_view` stops drawing the slot row, so the sea was left
wearing the only mark on the field that says 「your hand goes here」 — the deleted coast wash's failure
on the other side of the commit, under a paragraph promising it could not happen. `_band_fills` is read
**on both sides of `commit()`** (190 → 0) with a floor that the water is still being drawn at all, so
the zero is 「the blend went」 and not 「the terrain pass stopped」.
**F3 — the three lines are driven now, not claimed.** The `_hold_sec` gate's `_summon_down = false`
(hold, deliver one event, end the hold, beat five times), `field_view.setup`'s two `-1`s, and
`hud_view.bind`'s `_armed = -1` — each with the floor that the shell's own arm is still live, so none
of the three zeroes is 「everything is -1 anyway」.
**F5 — the false measurement is corrected in place and marked as false.** It read *"a landing ring is
18 px around a LAND tile and can overlap the water beside it"*. `_ring_hit_at` converts to WORLD px
first, `TARGET_RING_R_PX` is 18.0 against `TILE_PX` 40.0, so the hit circle is **strictly inside its own
land tile** and disjoint from the nearest water by 2 px. The ORDERING is unchanged and its real reason
is written down instead: the summon **consumes** the press, so anything with a specific target has to
be asked first or it can never be reached.
**F6 — `_fresh(g: Grid)` took a grid and ignored it.** It takes the island INDEX now, so the rows, the
spawns and the limit all come out of one number and cannot name different islands.
**F7 (two of three)** — a refused key **flashes as well as shakes**: `_chip_tint` is pulled out of
`_chip_colour`, so the five boxes get the tint the start button has had since item 8 shipped while
`_chip_offset` already served both. And **an armed slot that has run dry is no longer green**:
`_slot_colour` tested `armed` before `empty`, so the box read 「ready」 for a key that would bark. The
fill says what comes out, the border still says which key — both asserted.
**F8 — four doc sites.** `title-and-map` §5.5's *"the keyboard still does nothing in this game"* is
**struck rather than edited** (fourth stale site, and the only one in an ACTIVE plan). `CLAUDE.md` is
17 / 2558 / 5.2 s and its `docs/plans/` row says `2.active` holds two. `sea-summon` §5.3's collapse to
**0.00 s is marked REFUTED**: the band shipped at `d = 2`, not `d ≤ 1`, and the measured spread is
**0.46 s** (0.25 / 0.60 / 0.71). The direction survives — 1.4–1.5% of a fight instead of 14.5–15.3% —
but 「identical」 is a word this doc may not use.

not closed  ⚠⚠ **F7's third item is NOT built and I am pushing back on it with the measurement.**
*"nothing ties the band to the five boxes — no arrow, no label, no shared tone"*. The shared-tone answer
is **refused by a decision already written in `look.gd`**: `COL_SUMMON_BAND`'s own paragraph says it is
*"deliberately NOT `COL_START` / `COL_WIN` / `COL_NODE_CHEST` re-typed — a value shared by two concepts
diverges the first time one of them is tuned."* Overriding that is a design call, not a fix. An arrow or
a label is **new presentation nobody has specified and verify-look has not scored** — and this plan's
own rule is that presentation ships with its design, not invented by the builder. ⇒ **The
discoverability of 1~5 is a question for the user or for a design round**, and it is the one finding of
the eight left standing.
⚠ **Independent mutation coverage for this feature remains ZERO.** All 8 dispatched worktrees were at
`20ff378` — a tree with no `grid.gd` and no `battle.gd` — so they measured nothing and reported cleanly.
**Second time.** Everything below was run by hand in the main tree.
⚠ **A11–A13 are the user's and A8–A9 are verify-look's**; nothing here closes any of them, and F7's
three items were verify-look's photographs, so **two of the three are fixed unseen**.
⚠ **Carried**: `flow_field`/`step_toward` have no diagonal-shoulder guard · `SPARK_LEN_PX` is under the
snap floor at `ZOOM_MIN` · `TARGET_LINE`, `SPARK` and the `CLIFF_FACE` line are `speed-off-open-landing`
round 3's three recorded-not-fixed findings · the probe has not been re-run since the loss rule changed.

nets      **17 nets · 2558 checks · 5.1 s · green**, stderr clean. Was 17 / 2508 / 5.4 s. Fingerprint
`3F6D9170B420`.

⚠⚠ **The round was green at 2508 with F1, F2 and F3 all present** — the fixes moved the count by 50
because the checks did not exist, not because the behaviour was covered.

**Seven mutations, each edited and re-run in ONE command, each asserting the replacement landed
before running:**

| # | Mutation | Result |
|---|---|---|
| 1 | `_arm` stops cancelling the drag | **red** — slots, 4 rows, printing 1461 against -1 |
| 2 | the band's `band_on` test removed | **red** — slots (190 band tiles after the commit) |
| 3 | `_slot_colour` tests armed before empty again | **red** — slots (`COL_START` on a dry slot) |
| 4 | `_slot_colour` returns `rest` without `_chip_tint` | **red** — slots, both colour rows |
| 5 | the `_hold_sec` gate stops clearing `_summon_down` | **red** — slots (6 boats where 1 was expected) |
| 6 | `field_view.setup` stops clearing the aim | **red** — slots, 2 rows |
| 7 | `hud_view.bind` stops clearing `_armed` | **red** — slots |

---

### Round 3 — fixer

changed   `src/sim/rules.gd` (`SUMMON_BAND_TILES := 2` -> `SUMMON_BAND_MIN_TILES := 4`, and the sweep it
was chosen from) · `src/sim/grid.gd` (`can_summon_at` inverted, plus an explicit `UNREACHABLE` guard the
inversion made load-bearing) · `tests/nets/net_summon.gd` (every band literal re-derived, two fixtures
grown, three new rows) · `docs/design/sea-summon.md` (§3.2, §3.3 and §5.3).

why       The user played it. ✅ **The gesture is accepted** — *"동작방식은 맞음"*, the first thing in
this repo they have said works — and the region is not:
***"해안선에 배를 배치하는게 아니라 좀 거리를 둬야함 지형하고 많이 줘도됨 배가 가는게 중요하니까"***.
**The reason is a design reason and not a preference: the crossing is the thing worth watching, and a
band hugging the shore deletes it.**

closed    **The band is a MINIMUM distance from land and has no maximum.** The constant was RENAMED with
its meaning — a constant whose sense inverts under the same name is one nobody re-reads.

**D = 4, chosen from a sweep, compared against `≥ 3` and `≥ 6`.** Band tiles · distinct reachable
landings · crossing min/median/max at `BOAT_SPEED` 4.0, all three islands:

| rule | band | landings | crossing | spread |
|---|---|---|---|---|
| `≤ 2` (replaced) | 190 / 174 / 186 | 82 / 75 / 80 | 0.25 / 0.60 / 0.71 | 0.46 s |
| `≥ 3` | 534 / 516 / 540 | 45 / 40 / 43 | 0.85 / 2.47 / 5.96 | **5.11 s** |
| **`≥ 4` — adopted** | **470 / 460 / 478** | **42 / 38 / 40** | **1.10 / 2.47 / 5.96** | **4.86 s** |
| `≥ 6` | 360 / 360 / 366 | 34 / 35 / 34 | 1.60 / 2.83 / 5.96 | 4.36 s |

⚠⚠ **The MAXIMUM crossing is 5.96 s at every value, because the water is finite** — distance lifts the
FLOOR and SHRINKS the spread, and the spread peaks at `≥ 3`. **4 is one step past the peak**, bought for
a guaranteed 1.10 s minimum so no summon is ever instant. ⚠ **4.86 s is §5.2's drag figure restored**
(the drag's crossing spread was 4.50–4.75 s) — reached now by one press instead of 10–13.

**The destination rule did not have to move, and that is measured rather than assumed.** `_summon_field`
is already a multi-source BFS whose `summon_landing[t]` is the landing of the NEAREST seed, min over all
shortest paths. **「가까운 곳으로 자동이동」 was already built** — what the distance changes is not the
rule but its answer.

⚠⚠ **THE CATCHMENT COST, said as a number rather than papered over.** §3.3 predicted this and it is half
right: the four biggest catchments really are corner landings (**40 / 40 / 72 / 84** tiles at `≥ 4`,
against a MEDIAN catchment of **8**), but *"the same four corner landings"* overstates it —
**42 of 84 coast tiles on island 1 stay individually addressable, 38 of 76, 40 of 82.** ⇒ **Half the
coastline is the price**, and `net_summon` asserts the loss as 42 / 38 / 42 tiles rather than letting it
read as the old two.

**The long map (144 × 32)**: **1424 band tiles · 140 of 174 landings · crossing 1.10 / 2.83 / 17.96 s**,
all 1424 producing a route. ⚠ **The catchment barely collapses there** — the coast is one straight line
rather than a ring, so far sea drains to many nearest landings instead of to four corners. It has its own
net row now; it is still not wired into `Rules.MAP_NODES`.

**No island's band went empty or unreachable.** 470 / 460 / 478 pinned, and **all 1408 band tiles walk a
route** (was 550). ⚠ **No island had to be given a smaller D** — the smallest band is island 2's 460,
still 2.5x the 190 it replaced.

⚠⚠ **THE GUARD THE INVERSION MADE LOAD-BEARING, AND IT WAS GREEN WHEN DELETED.** `UNREACHABLE` is
`1 << 30`: under `<= max` it failed the test for free, under `>= min` it **passes**. Dropping the guard
reddened NOTHING on the three islands or the long map, because all their water is one connected body —
**the same shape this feature was bounced for last round.** So it has a fixture: a lake ringed by `#`,
whose water touches no passable tile and is therefore never seeded. With it, mutation 2 reddens.

not closed  ⚠⚠ **THE BAND/BOX TIE GOT WORSE, exactly as predicted.** The finding I pushed back on last
round — nothing ties the green band to the five slot boxes, so 1~5 is undiscoverable until pressed — is
**strictly worse now**: the band is no longer touching the island, so the only thing on screen anywhere
near it is open water. **No fix built** (the shared-tone answer is still refused by `COL_SUMMON_BAND`'s
own decision in `look.gd`, and an arrow or a label is unspecified presentation). **It is now the biggest
open thing in this feature.**
⚠ **I did not take a capture.** Whether the band still reads as a place to aim when it is no longer
touching the shore is a screen judgement and **verify-look's**; a builder measuring its own picture is
the bias this repo separates the roles for. **Where to look**: the green now starts four tiles out and
runs to the map edge, so the question is whether it reads as *a region* or as *the whole sea*.
⚠ **A new ranking question, and it is the interesting one this round leaves.** §5.4 worried that
flattening the crossing removed the cost pulling toward the harbour-adjacent beach. **Term 2 is back at
full size and it no longer points at a harbour at all** — it points at whatever coast is nearest to where
you pressed. **Nobody has measured whether THAT ranking is dominated.**
⚠ **Independent mutation coverage is still zero** (both sweeps landed in a worktree at `20ff378`, a tree
with no `grid.gd`). Everything below is hand-run in the main tree.
⚠ **Carried**: `flow_field`/`step_toward` have no diagonal-shoulder guard · `SPARK_LEN_PX` is under the
snap floor at `ZOOM_MIN` · `TARGET_LINE`, `SPARK` and the `CLIFF_FACE` line · the probe has not been
re-run since the loss rule changed.

nets      **17 nets · 2576 checks · 4.5 s · green**, stderr clean. Was 17 / 2558 / 5.1 s. Fingerprint
`C3311EBFE3B2`.

⚠ **Every literal in this round was derived OUTSIDE Godot** from a from-scratch reimplementation of
`_summon_field`, its tie-break, `_water_step_open`, the string-puller and GDScript's own
round-half-away-from-zero — the same discipline `net_summon`'s own header already required.

**Three mutations, each edited and re-run in ONE command, replacement asserted before running:**

| # | Mutation | Result |
|---|---|---|
| 1 | `can_summon_at` back to `>= 1 and <= 2` | **red** — summon, 14 checks |
| 2 | the `UNREACHABLE` guard dropped | **red** — summon, 3 checks ⚠ **green before the lake fixture existed** |
| 3 | `SUMMON_BAND_MIN_TILES` 4 -> 3 | **red** — summon, 14 checks (band, landings, near-water, the long map) |

---

### Round 4 — fixer

changed   **The drag is deleted**: `src/shell/game.gd` (the press branch, the release block, the motion
branch, `_drag_soldier`, `_soldier_hit_at`, and `_arm`'s drag-cancel) · `src/view/field_view.gd` (the
harbour markers and `_paint_dock`, the candidate ring, the route preview, the reserve stack,
`idle_soldier_rect`, `set_drag`, `_drag_soldier`/`_drag_tile`) · `src/look.gd` (`IDLE_SOLDIER_*` and
`idle_soldier_offset_px`) · `src/sim/battle.gd` (`boat["home"]`, both writers) ·
**`tools/look/capture_landing.gd` deleted whole** · six nets · `src/sim/rules.gd`
(`SUMMON_BAND_MIN_TILES` 4 -> 6) · `docs/design/sea-summon.md` §3.2 · §3.3 · §5.3.

why       ***"ㅇㅇ 지워줘 그리고 그냥 섬 이랑 더 거리를 더줘"*** — pointing at the yellow harbour
markers and the reserve stack. Both belong to the drag, and the drag is what they had already called
not fun (`idea-inbox` row 26). The summon replaced it and the gesture is accepted (*"동작방식은 맞음"*).

closed    **THE THREE FACTS, ESTABLISHED BEFORE ANYTHING WAS CUT:**
1. **`_summon_field` seeds from the COAST, not from harbours** — a seed is a water tile 8-adjacent to a
   PASSABLE land tile, and there is no harbour anywhere in it. `net_summon._a_grid_with_no_harbours`
   already proved a zero-harbour grid has a band. ⇒ **deleting harbours does not touch the feature**,
   and no seed had to move.
2. **A landing with no harbour is `summon_landing_of(t)`** — derived from the press by the summon BFS.
   `sendable` / `can_land_at` / `home_harbour_for` / `water_route` are `Battle.send`'s machinery and
   nothing else's. **No hidden harbour was kept.**
3. **The return leg needed no change** — a summoned boat's path is `summon_route` and `_phase_landings`
   REVERSES it, so it sails back to the sea tile it was summoned at and vanishes there. Confirmed by
   reading, and `boat["home"]` was already -1 for a summon before it was deleted.

**The band: `>= 4` -> `>= 6`.** Band 470/460/478 -> **360/360/366**, landings 42/38/40 ->
**34/35/34**, crossing 1.10/2.47/5.96 -> **1.60/2.83/5.96**, spread 4.86 -> **4.36 s**. Long map:
**1128 tiles · 138 of 174 landings · 1.60/3.18/17.96 s**, all 1128 producing a route.
⚠⚠ **AND THE CEILING IS A CLIFF: at `>= 12` the band is 48 tiles and resolves to TWO landings on every
island and on the long map.** 10 is the last usable value. `rules.gd` carries the whole sweep.

**Checks DELETED, subject and all** — never repaired to pass:
- `net_slots._arming_mid_drag_cancels_the_drag` (round 2's signature-fake fix — no drag to collide with)
  and the slot-boxes-vs-harbour-stack overlap half of `_the_boxes_clear_the_army`;
- `net_shell`: the dock rows, the whole reserve-stack pass, **the entire drag suite (~320 lines)**, the
  post-commit body/release branches, the panel release guard, the five `IDLE_SOLDIER_*` bound rows and
  two layer-order rows;
- `net_summon._the_boat_has_no_harbour`'s two `boat["home"]` rows — **rewritten onto the PATH**, which
  is a stronger claim (a `send` boat starts on a harbour tile, a summoned one on the pressed sea tile);
- `net_boat` / `net_plan`'s `boat["home"]` rows — same rewrite onto `path[0]`.

**What replaced them measures the summon and not nothing.** `net_shell`'s plan is authored with
`battle.summon` now (two derived landings, then both slots emptied to ten boats), so every downstream
row — ghosts, the fan rank, the routes, the commit, the hulls, the crossing, the verdict — still runs.
`net_slots` (158 checks) owns the summon's INPUT path end to end.

not closed  ⚠⚠ **`H`, `start_harbour`, `sendable`, `home_harbour_for` and `Battle.send` ARE STILL IN
THE TREE, and the reason is one file.** Nothing in `src/` reads any of them any more. **Their last
reader is `tools/probe/run_run.gd`** — the instrument that grades every design decision in this repo
and that `plan-then-watch` 8.2's stop condition is measured with. Removing `H` from the legend makes
`send` return -1 forever, which does not break the game and **silently kills the probe**. Porting the
probe onto `summon` is a rewrite of the measuring instrument, and doing it in the same round that
deletes what it measures is how a measurement quietly stops meaning anything. ⇒ **Decision needed;
not a builder's.**

⚠⚠ **THE BAND/BOX TIE IS NOW BLOCKING, NOT OPEN.** Nothing ties the green band to the five slot boxes,
so 1~5 is undiscoverable until pressed — and **the band is now the ONLY control in the game.** There is
no drag to fall back on and the band sits six tiles off the shore, further from anything that could
explain it. Still no fix invented (the shared-tone answer is refused by `COL_SUMMON_BAND`'s own
decision in `look.gd`; an arrow or a label is unspecified presentation).

⚠⚠ **`tools/look/capture_landing.gd` IS DELETED and its capability is gone with it.** Every gesture in
it called `idle_soldier_rect` / `_soldier_hit_at`, so it would have crashed on its first shot. **What
it uniquely photographed and nothing replaces**: the route line compared on screen against the sim's
route, the refusal mark at the cursor, and the zoom sweep that found `ROUTE_WIDTH_PX` at 1.35 px.
`capture_summon.gd` is verify-look's to write.

⚠⚠ **THREE THINGS THE DRAG SUITE MEASURED HAVE NO REPLACEMENT ANYWHERE**, named in the net where they
stood: (1) the route preview compared **point for point** with the sim's own route — the only runtime
catch for `_paint_route` cutting a corner; (2) the refusal mark's whole life, including that it is
ABSENT on an accepted press; (3) hit-test precedence, which is gone rather than unmeasured.
⚠ **And one more hole**: 6.3's row — the HUD chrome never sits on top of what the hand reaches for —
died with the stack. The five slot boxes are what the hand reaches for now and **nothing checks the
start button against them.**

⚠ **Per-soldier HP has no home.** The stack drew a bar under every reserve body because 「which of
these thirteen is nearly gone」 is a planning fact. **A slot bar is a COUNT, not a health readout.**
`sea-summon` §6 raised this as Open 4 and it is still unanswered.
⚠ **`net_shell`'s bottom-right corner argument is now unforced**: the boxes were put there to clear the
harbour stack, and the stack is gone.
⚠ **Carried**: `flow_field`/`step_toward` have no diagonal-shoulder guard · `SPARK_LEN_PX` is under the
snap floor at `ZOOM_MIN` · `TARGET_LINE`, `SPARK`, the `CLIFF_FACE` line · the probe has not been re-run.

nets      **17 nets · 2473 checks · 4.6 s · green**, stderr clean. Was 17 / 2576 / 4.5 s.
⚠ **The count went DOWN by 103 and that is the point of the round** — a deletion that left the number
alone would mean the checks had been repaired instead of removed.

**Three mutations, each edited and re-run in ONE command, replacement asserted before running:**

| # | Mutation | Result |
|---|---|---|
| 1 | `SUMMON_BAND_MIN_TILES` 6 -> 4 | **red** — summon, 13 checks (band · landings · near-water · long map) |
| 2 | the harbour markers drawn again | **red** — shell (an idle frame draws nothing extra) |
| 3 | the reserve stack drawn again | **red** — shell, 3 checks (body count · centres · HP bars) |

⚠ **Two fixtures in `net_summon` had to GROW rather than be re-valued**, for the second round running:
a minimum distance empties any fixture whose sea is shallower than the constant. Both are sized for the
**ceiling** now (24x24 and 24x20, holding a band at `>= 10`) so the next distance change does not empty
them again. Every hand-derived literal in the tie-break fixture survived the growth, and the comment
says which indices moved with the width.
