# Research bench — the first three unlocks 원석 can actually buy

**Status**: done — **implementation finished, acceptance NOT passed.** `3.done/` means the code landed and
the nets are green (7,699 checks, 32 nets, `[래퍼] 통과. stderr 깨끗함.`, no `[경합]`; 31 mutations run, 30
bit — the one that does not is the `or`-chain reorder, a semantic no-op recorded in `character.gd` and in
`net_research`). **Nobody has looked at this on screen.** Still owed, and none of it is covered by any check:

- **That a real mouse click reaches the window.** Every click check drives `_gui_input` directly on the
  window, which bypasses Godot's own input routing. `stage.tscn`'s `mouse_filter` is now `STOP` and
  `net_render` asserts that off the instantiated scene — but "the property is right" is not "the click
  arrives". Needs a human or verify-look.
- **How the air jump feels.** One extra jump at `JUMP_VY_PX` unchanged. Whether it reads as a double jump
  rather than a stutter is the user's call, not a net's.
- **How the ring reads.** `AIR_JUMP_RING_*` are starting values nobody has seen — and whether a ring is even
  the right mark (versus a puff, a sprite stretch, or a sound) is still this doc's own TBD.
- **The body row's single chip spans ~299px**, because chips divide their band evenly and that row has one.
  Measured, not guessed. A full-width 1px box around a short label is the thing to look at first.
**One line**: At the research bench you press a locked thing — the 물 rune, the 불 rune, or the double jump —
10 원석 leaves the counter, and it is yours **forever**: it survives `reset()`, so the next run starts wider
than the last one did.

## Why

`docs/GDD.md`'s session loop says unlocks accumulate in town. Today the loop turns and **nothing carries**:

- 원석 accrues from two doors — a boss 3~4, a level 1 (`src/actor/progress.gd:88-90`,
  `docs/decisions/gems-from-bosses-and-levels.md`) — so **9–11 a full run, ~2 on an early death**
- The research window is **built** — panel, four slot frames, **five icon files (four unlock rows plus the
  원석 icon on the material line — not five rows)**, the live rune list
  (`src/view/research_window.gd`, `src/view/research_layout.gd`)
- **Nothing spends 원석 and no unlock exists.** `progress.gd:75` says so in its own comment, the window says
  so in its footer (`fx_tuning.gd:1568`), and `research_layout.gd:8-10` says the hit test is deliberately
  absent "until a price exists"

⇒ Die, come back, and the next run is **identical**. That is the loop's biggest hole.

**Three unlocks, 10 원석 each** (decided by the user — the double jump was added to the two runes with
*"더블 점프 같은 것도 해금이 되면 좋을 거 같고… 거기까지 하자"*). `town.md`'s 원석 section — its old "three per unlock"
arithmetic is void — it was written against 1–2 원석 a run. At 9–11 a run, 10 is **roughly one unlock per
run**, the shape the user picked: 한 번 갔다 오면 하나 열린다. **Three purchases is 30 원석, about three runs.**

**Points and dice stay deferred** (거기까지) — reasons in TBD.

## Behavior

### The catalogue — one table, three buyable rows

Three heterogeneous unlocks is where a table stops being premature. `src/actor/unlock_defs.gd`
(`RefCounted`, the seat `monster_defs.gd` already holds — a rule table, not presentation, not sim):

| id | axis (research row) | grants | cost |
|---|---|---|---|
| `UNLOCK_RUNE_NONE` | item | 무 — **already granted, never for sale** | — |
| `UNLOCK_RUNE_FIRE` | item | 불 rune, permanently | 10 |
| `UNLOCK_RUNE_WATER` | item | 물 rune, permanently | 10 |
| `UNLOCK_DOUBLE_JUMP` | body | one air jump | 10 |

`무` earns a row **because the item row's job is to show the whole pool** (`town.md`'s research-bench fixture row, "unlocked and locked
in one list"). Marking it not-for-sale is a fact, not a stub.

**The rune half of that table is the derivation the previous draft made structural, now checked instead**: a
net asserts the table's rune rows are exactly `Tuning.ELEM_ALL`, and that the ones marked buyable are exactly
`ELEM_ALL` minus `_starting_runes()` (`progress.gd:243-244`). Add a fourth rune and forget the row → red.

### Why these three and nothing else

**`owns_rune()` is the only ownership concept in this repo.** Measured — `grep "func owns_"` over `src/`
returns exactly one hit (`progress.gd:256`). Circles and glyphs have none (`palette_layout.gd:67-68`: "there
is no notion of owning"). And each of the three has its consumer already running:

| Link | Where | Runs today |
|---|---|---|
| The rune pool is stored | `progress._owned_runes`, `grant_rune()`/`owns_rune()` | yes |
| The palette veils an unowned rune | `circle_window._can_pick` → `_slot_accepts` (`circle_window.gd:177`) | yes |
| A revoked rune is pulled out of the seat | `stage._revoke_unowned_rune()` (`stage.gd:927`) | yes |
| The rune changes the world when fired | `sim_tuning.ELEM_DEFS` → `spell_sim.gd:561` (`TRACE_WET`) | yes |
| The jump condition is a single `if` with an `or` chain | `character.gd:364` | yes |

**물 and 불 are genuinely different purchases**, which is what makes `town.md`'s ordering question ("what do I buy first") real:
물 is otherwise unobtainable; 불 is obtainable in-run from the bull (`stage.gd:668`) **but that grant dies
with the run** (`reset()` reverts `_owned_runes`, `progress.gd:340`), so buying 불 buys **permanence**, not
first access. **This does not break "the midboss must be met as a wall once"** (`town.md`'s point-value TBD, "it must be met as a wall once") — run 1 starts
at 0 원석, so nothing is affordable before the bull has been met.

### Where the unlock state lives — and what `reset()` must not do

**This is the highest-risk part of the feature.** A permanent flag cleared by `reset()` erases every run's
purchases at once, and **nothing would bark** — the player would simply find the bench empty again.

**One set, not one field per axis.** `progress.gd`:

```gdscript
const GEMS_PER_UNLOCK := 10          # beside GEMS_PER_BOSS_MIN/MAX/GEMS_PER_LEVEL — earn and spend, one file

var _unlocked: Dictionary = {}       # permanent, set-shaped, keyed by UnlockDefs id

func can_buy(unlock_id: int) -> bool:
    return UnlockDefs.is_for_sale(unlock_id) and not _unlocked.has(unlock_id)

func buy(unlock_id: int) -> bool:
    if not can_buy(unlock_id) or gems < GEMS_PER_UNLOCK:
        return false
    gems -= GEMS_PER_UNLOCK
    _unlocked[unlock_id] = true
    var rune := UnlockDefs.rune_of(unlock_id)          # -1 for a non-rune unlock
    if rune >= 0:
        grant_rune(rune)                                # the existing single door — usable this instant
    return true

func air_jump_budget() -> int:                          # 0 or 1. Read every frame, never latched
    return 1 if _unlocked.has(UnlockDefs.UNLOCK_DOUBLE_JUMP) else 0

func _run_start_runes() -> Dictionary:                  # instance, not static: it reads _unlocked
    var out := _starting_runes()
    for id: int in _unlocked:
        var r := UnlockDefs.rune_of(id)
        if r >= 0:
            out[r] = true
    return out
```

and `reset()`'s last line becomes `_owned_runes = _run_start_runes()`.

**One permanent collection, not two.** Had the double jump been its own `var _unlocked_double_jump := false`,
`reset()` would have **two** things to not clear, and a bool is invisible to `net_pick`'s stash scan. One set
means one thing to protect and one inverted check to protect it with.

**Four properties, each the way the obvious version fails:**

1. **`reset()` does not mention `_unlocked` at all** — the same way it does not mention `gems`, and for the
   same reason its own comment already gives (`progress.gd:328-329`). Adding `_unlocked.clear()` there must
   turn a net red, exactly as adding `gems = 0` already does
2. **The guard is `_unlocked.has()`, never `owns_rune()`.** Fire granted by the bull makes `owns_rune(불)`
   true while nothing is unlocked — guarding on ownership would refuse a legitimate purchase, or (reversed)
   let a granted rune read as bought and survive a reset for free
3. **`buy` calls `grant_rune()` rather than writing `_owned_runes` directly.**
   `net_progress._grant_rune_is_the_only_door_in` (`net_progress.gd:525`) states that as a contract
4. **`air_jump_budget()` is a function, not a stored number.** Nothing caches it, so there is no moment at
   which it can be applied wrongly — see the timing section below

### The two effect-timing paths — and why one of them has no application moment

`town.md`'s research-bench table (the **items** and **body** rows — **named, not line-numbered**: that
table moved four lines the day town.md's header grew) splits them: **body is immediate from purchase, the other three are next-run.** Both paths
are specified here rather than left to analogy, because they are **not the same mechanism**.

**Runes — next-run, applied at `reset()`.** `_owned_runes` is genuinely run-scoped state that gets rebuilt
each run, and `reset()` is the one place that means "a run begins" (`progress.gd:48-51`). `_run_start_runes()`
folds the permanent set into it there. Note that `buy()` **also** calls `grant_rune()` so the rune is usable
the same town visit — and that this changes nothing observable, because **the bench is reachable only in
town**: `stage._interact()` returns early when `not _in_town` (`stage.gd:1017-1019`) and `_build_room()`
closes the window on every room switch (`stage.gd:989-990`). A purchase can never happen during a run, so
"the run after the purchase" is always the next one either way. What the immediate grant buys is that the
**town assembly bench can show it the same visit**, which is what `town.md`'s assembly-bench fixture row wants that bench to be for.

**Double jump — immediate, and therefore applied nowhere.** `Character` holds `var air_jump_budget := 0` as a
plain field, and `stage._physics_process` re-derives it from `Progress` every frame, immediately before
`_world.frame(...)` (`stage.gd:774`):

```gdscript
_char.air_jump_budget = _world.progress().air_jump_budget()
```

**Immediate is the absence of a latch.** This is the repo's own "derive, do not push" rule — the same one
`gate_view._process` states ("`visible` derived every frame, never latched… hold a second flag here and the
arch can go stale") and `stage._build_room` states for `_town_view.visible` ("derived from the latch every
time, never written at the two doors"). There is no purchase hook, no reset hook, and consequently no hook to
forget. The lead asked where the immediate path is applied: **the honest answer is that specifying an
application moment would itself be the bug.**

**`reset()` still must not clear `_unlocked`** — the double jump's permanence rides the exact same field as
the runes', and the same inverted check covers both (acceptance 6).

**Shell-scoped, deliberately.** That derivation line sits in `stage.gd` rather than `world_step.gd:314`
(which is where `_char.step()` is actually called, and which holds `Progress` too) **only to avoid colliding
with the other track**, which owns `world_step.gd`. The day `WorldStep` owns this wiring, **one line moves and
nothing else changes** — it is a per-frame derivation either way. Flagged rather than hidden.

### How the double jump composes with unlimited jumping underwater

`water-jump-and-escape.md` is **code done** for stage 1 (its own status table, and
`character.gd:359-364`). Underwater the jump is already unlimited. The two axes meet head on, and the repo
already decided they are one axis:

> ```
> ④  double-jump lock         ── somewhere you reach with one more jump
> ③  unlimited jumps in water ── in water there is no jump limit
> ```
> Not two unrelated gimmicks but **two instances of one grammar.** "Jump count" becomes this game's
> progression axis. — `water-jump-and-escape.md:138-144`

**Today's condition** (`character.gd:364`):

```gdscript
if _jump_buffer_left > 0.0 and (on_ground or in_water or _coyote_left > 0.0) and not downed:
    vy = JUMP_VY_PX
    _jump_buffer_left = 0.0
    _coyote_left = 0.0
```

**After** — one term added, one spend, one refill:

```gdscript
var ground_jump := on_ground or _coyote_left > 0.0
if _jump_buffer_left > 0.0 and (ground_jump or in_water or _air_jumps_left > 0) and not downed:
    vy = JUMP_VY_PX
    _jump_buffer_left = 0.0
    _coyote_left = 0.0
    # **Spent only when neither the ground nor the water paid for it.**
    if not ground_jump and not in_water:
        _air_jumps_left -= 1
```

and, beside the existing coyote refill on `character.gd:354`:

```gdscript
_air_jumps_left = air_jump_budget if on_ground else _air_jumps_left
```

**The unlock is a structural no-op underwater, not a special case.** `in_water` sits **before** the budget in
the `or` chain and gates the spend, so in deep water the water term satisfies the condition and
`_air_jumps_left` is never touched. There is no third state — the composition is "water short-circuits the
budget", which is one line of ordering, not a branch.

**Four consequences, all deliberate:**

- **Leaving the water gives you exactly one extra jump instead of zero.** `water-jump-and-escape.md`
  acceptance 3 ("leaving the water re-limits it") is about *limited*, not *zero*, and its verify-look trace
  (that doc's lines 400-411: above the surface "the jump cut out and it fell 58px back") stays true with one
  air jump instead of none. That is the unlock doing exactly what it says. **A builder must not "fix" this.**
- **Water does not refill a spent budget** (air-jump over land → 0 left → fall in water → jump freely → leave
  the surface with 0). Refilling would mean the water path *writes* the budget, which is precisely the
  no-op property being broken. **Ground is the only refill site**, the same single-site discipline
  `_coyote_left`'s own comment argues for (`character.gd:351-353`: "a counter that only counts down has to be
  reset somewhere else too, and the day a second grounding path appears that reset is the line that gets
  forgotten")
- **Do not implement the second jump through coyote time.** `character.gd:366-368` already says it:
  `_coyote_left = 0.0` on a jump is what stops a double jump today, and a double jump "is a town unlock — it
  must not fall out of a feel fix". `COYOTE_SEC`'s own comment (`character.gd:141`) forbids widening the
  forgiveness window into this. **The budget is a separate counter; the coyote line is untouched.**
- **With no unlock the condition is byte-identical to today's.** `air_jump_budget` defaults to 0, so
  `_air_jumps_left > 0` is never true and the added spend branch is unreachable. **That is what keeps
  `net_character`'s A-1–A-4 water checks green without editing them**, and a check asserts it directly.

**The jump's own value is `JUMP_VY_PX` unchanged, and that is provisional.** The water axis reuses it
unchanged for the same reason (`water-jump-and-escape.md:161`, which left "whether it should differ
underwater is TBD"). **No second-jump velocity is invented here** — whether the air jump should be weaker
than the first is in TBD, to be decided by eye.

## Screen

### The bench — the line the player already reads becomes the thing they press

The item row's state line today prints `룬 불(잠김) · 무 · 물(잠김)`. It becomes **chips on the same line** —
no new vertical space, which the window does not have. The body row gets **one** chip the same way.

**The geometry, hand-computed from the constants** (`RESEARCH_RECT` 480x400, `RESEARCH_PANEL_BORDER_PX` 46,
`PAD_PX` 18, `TITLE_BAND_PX` 40, `MATERIAL_BAND_PX` 34, `FOOTER_BAND_PX` 34, `ROW_GAP_PX` 8): inner area
352x272, rows get 272−40−34−34 = 164, so each row is (164−24)/4 = **35px**. Two baselines already sit in
that. **A third text line does not fit** ⇒ chips replace the state line rather than adding one.

**Measured, not assumed** (builder, driven headless against the real `RESEARCH_RECT`). The hand arithmetic
above is exactly right:

```
inner    = P:(64,64)  S:(352,272)
row 0..3 = P:(64,138/181/224/267) S:(352,35)   h=35.000 each
text_x   = 117.00
baselines= [153,170] / [196,213] / [239,256] / [282,299]
footer   = P:(64,302) S:(352,34)
```

**One correction to this section**: the slot frame draws at **35x35, not `RESEARCH_SLOT_PX`'s 56** —
`research_layout.slot()` clamps it to the row height, which at 35px rows is always the binding constraint.
Nothing else moves: chips still start at `text_x` = 117 and run to 416, so three chips come out ~94px wide,
far past acceptance 21's 40px floor.

| Chip state | When | How it draws |
|---|---|---|
| `CHIP_FIXED` | not for sale (무) | `RESEARCH_INK`, name only, no box |
| `CHIP_UNLOCKED` | bought | `RESEARCH_INK`, name only, no box |
| `CHIP_BUYABLE` | for sale and `gems >= 10` | `RESEARCH_INK` + a 1px box — **the one thing meant to be pressed**, the same rule `SETTLEMENT_BUTTON_BG`'s own comment follows |
| `CHIP_SHORT` | for sale and `gems < 10` | `RESEARCH_INK_DIM`, no box |

**The four constants live on `research_window.gd`** as `const CHIP_FIXED/CHIP_UNLOCKED/CHIP_BUYABLE/CHIP_SHORT`
— the file that both computes (`chip_state()`) and consumes them. Not `fx_tuning`: they are states, not
presentation values.

**Label**: owned → `물`. Not owned → `물 잠김 10`. The body chip: `2단 점프` / `2단 점프 잠김 10`.

**A `CHIP_SHORT` chip clicked does nothing, and needs no message.** The repo's own answer: the palette
refuses to even pick a veiled rune, and its comment says why a message is the wrong fix — "get it picked and
then have the slot refuse it and it becomes *I pressed it and nothing happened*" (`circle_window.gd:175-177`).
The dim chip, the printed price and the 원석 count directly above are the affordance.

**The chained-shut slot art finally means something.** `_draw_slot(r, locked)` already takes the flag and
already cuts the padlock third out of `slot_row.png` (`fx_tuning.gd:1529`); every row passes `false` today,
with a comment explaining that an empty frame means "not yet built" while the padlock would claim "locked
behind a cost" (`research_window.gd:161-163`). **A cost now exists**, so the **item** and **body** rows pass
`locked = any of that row's unlocks is still unbought`, and **점수** and **주사위** keep `false` — nothing is
buyable there, so "not yet built" is still the true thing about them.

**The footer stops lying.** `RESEARCH_FOOTER` (`fx_tuning.gd:1568`) reads `원석으로 푸는 해금은 아직 없다 ·
[E] 닫기`; it becomes `RESEARCH_FOOTER_FMT`, formatted with `GEMS_PER_UNLOCK`. `Stage.research_text()`
(`stage.gd:1059-1063`) carries the same sentence and changes with it.

### The double jump — a second jump with no mark reads as a bug the first time it fires

**One short ring at the character's feet on the frame an air jump is spent.**

State: `Character.air_jump_flash_left: int`, set to `AIR_JUMP_FLASH_TICKS` when the spend branch runs and
decremented in `on_tick()`. **That is `invuln_left`'s exact shape**, whose own comment already establishes
this precedent — "the screen reads this value too… make a separate clock for the blinking and there are two
clocks, and you get blinking after the invulnerability has ended" (`character.gd:262-265`). One field, one
clock, read by the view.

**⚠ Put the decrement *above* `on_tick()`'s invulnerability branch, not below it.** `on_tick` **returns
early** while invulnerable (`character.gd:468-470`: `if invuln_left > 0: invuln_left -= 1; return`). A flash
counter decremented after that line stops ticking for the whole invulnerability window, so an air jump taken
just after being hit leaves **the ring frozen on screen for four ticks**. Nothing barks. A check drives an
air jump while `invuln_left > 0` and asserts the flash still counts down.

`character_view.gd` draws it through a hook whose arguments a net asserts:

```gdscript
func _paint_air_jump_ring(center: Vector2, radius: float, color: Color) -> void:
```

**Not named `_paint`** — that name is taken twice already with different signatures, by `gate_view.gd:67` and
`monster_view.gd:196`. Godot refuses to override a native `draw_circle` (a hard parse error, measured —
`net_gate.gd:40-46`), so the hook is what makes "a ring was actually painted" measurable rather than
"`_draw()` ran". `net_gate.gd:452` is the pattern.

**The ring's look and feel are provisional and unseen.** Radius, colour, and `AIR_JUMP_FLASH_TICKS` are
starting values, not tuned ones — see Bounds and TBD.

### Driving it headless

**All of it.** CLAUDE.md records "it can't be driven headless" being claimed four times and wrong four times.

- **Values** — `chip_state()`/`chip_text()` are `static` and pure, the seat `row_state()` and
  `Stage.research_text()` already sit in. `UnlockDefs` is a pure table
- **Hit test** — `research_layout.unlock_chip_rects(row, count)` / `unlock_chip_at(row, count, p)`, static and
  pure, the shape `pick_layout.cards`/`card_at` hold. `research_layout.gd`'s own header said to add exactly
  this "the day a price exists". **Generic over unlocks, not rune-specific** — the item row passes 3, the body
  row 1
- **The click** — `ResearchWindow.new()` **untreed**, `call("_ready")` (it only writes `position`/`size`),
  `setup(pr)`, then `_gui_input()` with a hand-built `InputEventMouseButton`. `net_pick`'s recipe verbatim
- **The jump** — `Character` needs no scene at all; `net_character` already drives `step()` against a bare
  `CellGrid`, frame by frame. The whole air-jump budget is measurable by value
- **The drawing** — treed + `t.pump_frames(n)` (`net_circle._draw_actually_runs_headless`)

## Bounds

- **One axis per slot, three unlocks total.** 점수 and 주사위 stay locked and stay honest
- **The double jump is a new movement mechanic and its feel is unverified.** One air jump, at `JUMP_VY_PX`
  unchanged, with a provisional ring. **Whether it feels like a double jump rather than a stutter is
  verify-look's and the user's, not a net's** — no value in this doc claims otherwise
- **No save file.** 원석 and unlocks live for the process only (`town.md`'s Saving TBD); nothing in `src/` writes a file
- **No new sim code.** `src/sim/` is untouched
- **The sink is 30 원석 deep** — three purchases, about three runs, and then the counter climbs with nothing
  to spend on again. Stated rather than hidden; widening it is the dice axis's job
- **No tabs.** `town.md`'s "tabs or one list" TBD stays one list — this feature adds no row

## Interaction with what exists

**Two existing `net_town` checks must stay green untouched** — they are the bench's contract, not scaffolding:
`_the_research_bench_shows_locked_and_unlocked_together` (`net_town.gd:218`) and `_the_item_row_is_the_rune_pool`
(`net_town.gd:400`) both count `잠김` and require it to drop by **exactly one** on a `grant_rune`, and require
`row_state("item", null)` to fall back to `Fx.RESEARCH_LOCKED_TEXT`.

⇒ **`chip_text` keys the `잠김` marker on `owns_rune()`, not on `_unlocked`**, and `row_state("item")` stays
`"룬 " + join(chip_text over ELEM_ALL)` with its null guard intact. The price suffix keys on `can_buy()`,
which does not move when a rune is merely granted, so the `잠김` count still changes by exactly one.
**A builder who "fixes" these checks has broken the feature, not the checks.**

**`net_character`'s water checks (A-1–A-4) must stay green untouched**, and they do, because
`air_jump_budget` defaults to 0 and the added term is then unreachable. Acceptance 12 asserts that identity
directly instead of assuming it.

**`net_pick._no_pushed_out_glyph_is_stashed_anywhere` (`net_pick.gd:526`) will name `_unlocked`.** That scan
catches every class-level `Array`/`Dictionary` under `src/`, private ones included, and
`res://src/actor/progress.gd` is already on its allowlist with `["_drawn", "_owned_runes", "_reward_pending"]`.
**Add `_unlocked` there deliberately, with the reason in place** — a set of what has been bought, not a record
of a glyph that left a spell layer, the same argument `_owned_runes`'s own entry makes. Do **not** widen the
regex to miss it.

**`_gems_at_run_start` goes stale-negative in town, harmlessly.** `reset()` snapshots it (`progress.gd:334`);
spending afterwards drops `gems` below the snapshot, so `gems_this_run()` reads **negative** while the player
is in town. Nothing reads it there — the settlement screen is closed (`stage.gd:937`) and the next `reset()`
re-snapshots. Pinned by a check rather than left to be rediscovered.

**`dice_left` stays inert.** `net_progress._dice_left_is_zero_and_inert` (`net_progress.gd:325`) scans every
`.gd` under `src/` for any write to it. This feature writes none.

## Cost

| File | Change |
|---|---|
| `src/actor/unlock_defs.gd` | **new** — the four-row catalogue, `is_for_sale()`, `rune_of()`, `axis_of()` |
| `src/actor/progress.gd` | `GEMS_PER_UNLOCK`, `_unlocked`, `can_buy()`, `buy()`, `air_jump_budget()`, `_run_start_runes()`; one line in `reset()` |
| `src/actor/character.gd` | `air_jump_budget`, `_air_jumps_left`, `air_jump_flash_left`, `AIR_JUMP_FLASH_TICKS`; the `or` term, the spend branch and the ground refill in `step()`; one decrement in `on_tick()` |
| `src/view/character_view.gd` | `_paint_air_jump_ring()` and its call in `_draw()` |
| `src/view/research_layout.gd` | `unlock_chip_rects()`, `unlock_chip_at()`, one gap constant |
| `src/view/research_window.gd` | the four `CHIP_*` constants, `chip_state()`, `chip_text()`, `_paint_unlock_chip()`, `_gui_input()`; the item and body branches in `_draw_rows`; `_draw_slot`'s `locked` argument |
| `src/view/fx_tuning.gd` | `RESEARCH_FOOTER` → `RESEARCH_FOOTER_FMT`; `RESEARCH_CHIP_*`; `AIR_JUMP_RING_*`; the "no price column" comment on `RESEARCH_ROWS` is now wrong |
| `src/stage/stage.gd` | `research_text()`'s sentence; one line refreshing the HUD line after a purchase; **one line deriving `_char.air_jump_budget`** |
| `src/stage/stage.tscn` | `HUD/ResearchWindow` `mouse_filter` **2 → 0** |
| `tests/nets/net_pick.gd` | one allowlist entry |
| `tests/nets/net_research.gd` | **new** |

### ⚠ The one line that makes the whole feature invisible

**`HUD/ResearchWindow` has `mouse_filter = 2` (`IGNORE`) in `stage.tscn:96-101`.** Measured — the pick and
settlement windows beside it are `0` (`STOP`).

**Left as-is, every click specified in this doc is dead, and every net in it is still green**, because no net
path goes through the scene file. The bench would open, draw its chips, print its prices, and refuse to be
pressed. **This is exactly the failure CLAUDE.md is built around** — the settlement panel that shipped under
5,576 green checks with `visible` never set. Acceptance 15 exists for this line alone, and it reads the
property **off an instantiated `stage.tscn`**, never off the script.

## Acceptance

**Model — purchase**

1. Fresh `Progress`: `can_buy(불)`, `can_buy(물)`, `can_buy(2단 점프)` all true; `can_buy(무)` false
   (not for sale); an id outside the table false
2. `buy` at `GEMS_PER_UNLOCK - 1` returns false and moves nothing; at `GEMS_PER_UNLOCK` it returns true and
   `gems` drops by exactly that
3. `GEMS_PER_UNLOCK` is **10**, pinned as a literal — bounds must not come from the thing they check
4. Buying the same unlock twice charges once: 20 원석, two calls, second false, 10 원석 left
5. The catalogue's rune rows are exactly `Tuning.ELEM_ALL`, and the buyable ones are exactly `ELEM_ALL` minus
   `_starting_runes()` — add a rune and forget the row → red
6. **Buy → `reset()` → still unlocked, for a rune *and* for the double jump, and `gems` still shows the
   spend.** Inversion: adding `_unlocked.clear()` to `reset()` must turn this red
7. **A granted rune and a bought rune part ways at `reset()`**: `grant_rune(불)` alone → not owned after
   `reset()`; `grant_rune(불)` then `buy(불)` → still owned after `reset()`
8. `buy` touches nothing else — `xp`, `level`, `money`, `pending_picks`, `_reward_pending` unmoved
9. `gems_this_run()` reads negative between a town purchase and the next `reset()`, and 0 after it

**Model — the jump**

10. `air_jump_budget()` is 0 before the purchase and 1 after, and **1 again after `reset()`**
11. **Buying it is felt without a reset**: with the budget at 1, a character in mid-air over land, not
    grounded, no coyote left, jumps once more — and a second attempt in the same airtime does not
12. **With the budget at 0 the jump behaves exactly as today.** Drive the same frame sequences
    `net_character`'s A-1–A-4 use and read identical trajectories — this is what proves the water axis was
    not disturbed
13. **Underwater the unlock is a no-op**: submerged, jump five times — all five work (as they already do)
    **and `_air_jumps_left` never decreases**. Inversion: moving the budget term ahead of `in_water` in the
    `or` chain, or dropping the `not in_water` guard on the spend, must turn this red
14. **Leaving the water with the budget unspent gives exactly one more jump, then no more** — the
    `water-jump-and-escape.md` acceptance-3 gatekeeper still holds, one jump wider
15. Landing on ground refills the budget; being in water does not

**Wiring — the checks that catch "it works and nobody can reach it"**

16. **`HUD/ResearchWindow.mouse_filter == MOUSE_FILTER_STOP`, read off an instantiated `stage.tscn`**, not
    off the script. **Without this line the entire feature is unreachable with every other check green**
17. `stage._physics_process` really derives `_char.air_jump_budget` from `Progress` — drive a wired stage
    root, buy the unlock, pump one physics frame, read the field. Inversion: delete the line → red
18. A click at the 물 chip's centre, through `_gui_input` on an untreed window, spends 10 원석 and grants the
    rune. A click at 0 원석 changes nothing. A click on an already-unlocked chip changes nothing. The same
    three for the body row's chip
19. The HUD line is not stale: open the bench on a wired root, buy through `_gui_input`, pump a physics
    frame, and `_town_message` reflects it
20. `Stage.research_text()` changes when something is bought and states the cost — driven, not grepped

**Layout and drawing**

21. `unlock_chip_rects(row, n)` for n = 1 and 3: inside the row, clear of `slot(row)`, non-overlapping, each
    at least **40px** wide at the real `RESEARCH_RECT` (480x400) — a literal, not a re-read of the function
22. `unlock_chip_at` returns the right index at each rect's centre **and at its four inset corners**
    (`net_pick`'s own finding: a hit box shrunk on one side survives a centre-only check), −1 outside
23. `chip_state` driven as a table: fresh → 무 = `CHIP_FIXED`, the other three `CHIP_SHORT`; at 10 원석 →
    `CHIP_BUYABLE`; after buying 물 → `CHIP_UNLOCKED`, the rest unchanged
24. `_paint_unlock_chip` capture subclass, **treed and frame-pumped**: 3 calls on the item row and 1 on the
    body row, ids in table order, rects equal to `Layout.unlock_chip_rects(...)`, states equal to 23.
    Inversion: deleting a chip loop gives 0 calls for that row
25. `_draw_slot` capture: **item** and **body** receive `locked == true` before purchase and `false` once
    that row's unlocks are bought; **점수** and **주사위** receive `false` in both cases
26. `_paint_air_jump_ring` capture subclass, treed and pumped: called while `air_jump_flash_left > 0` and
    **not called** when it is 0; the centre follows the character. Inversion: deleting the call → red
27. **The flash counts down while invulnerable.** Air-jump with `invuln_left > 0`, run ticks, and
    `air_jump_flash_left` still reaches 0 on schedule — the early `return` in `on_tick()` must not freeze it

## Collisions

**The other track owns `stage.gd`, `fx_tuning.gd` and `world_step.gd`. Serialize on the first two.**

| File | This doc's edit | Where the other track is |
|---|---|---|
| `src/stage/stage.gd` | `research_text()` (**1059-1063**, a `static` with no other caller); one line in `_update_hud()` (**1221**); **one line in `_physics_process()` at 773**, immediately before the existing `_world.frame(...)` on 774 | `spawn_monster`'s cap path, the gate, terrain. The town block is 997-1080; the `_physics_process` line is a single insert at the top of a 15-line function |
| `src/view/fx_tuning.gd` | the `RESEARCH_*` block (**~1548-1571**) plus a small `AIR_JUMP_RING_*` group | `MONSTER_*` / `BG_*`. Different regions of the same file |
| `src/stage/stage.tscn` | one property on `HUD/ResearchWindow` (**~96-101**) | not listed as owned, but the other track adds nodes to this scene. **Merge by hand, not by tool** |
| `src/actor/world_step.gd` | **none — deliberately.** `_char.step()` is called at **314** and `WorldStep` holds `Progress`, which makes it the architecturally right home for the budget derivation. It is in `stage.gd` instead **only** to keep this file untouched | the `spawn_monster` cap path |
| `src/actor/character.gd` | the jump condition and the flash counter | not on the owned list, **but `monsters-bigger-boxes.md` sits in `1.ready/` and is about box sizes** — check before starting |
| `tests/nets/net_character.gd` | **no edit** — acceptance 12 exists to prove it needs none | not on the owned list |
| `tests/nets/net_pick.gd` | one allowlist entry | clear |

`net_town.gd` is **not** edited — see "Interaction with what exists".

## TBD

- **Should the air jump be weaker than the first?** `JUMP_VY_PX` (−720) is reused unchanged as a starting
  value, the same way the water axis reuses it and left the same question open
  (`water-jump-and-escape.md:161`). **Decided by eye, not computed.** `character.gd:105` warns that height is
  the square of speed (`v²/2g`) and must not be read off the velocity ratio — so if this is retuned, retune it
  as height, not as velocity.
  **(`water-jump-and-escape.md:192` cites this as `character.gd:75`, which is stale — line 75 is `STEP_PX`.
  The live comment is at 105.)**
- **The air-jump ring's look** — radius, colour and `AIR_JUMP_FLASH_TICKS` are starting values. Whether a
  ring is even the right mark (versus a puff, a stretch of the sprite, or a sound) is unseen
- **Does the double jump change the map** — it makes ledges reachable that stage 1's terrain was drawn
  against. **Not measured, and it interacts with the other track's terrain rewrite.** Nothing in this doc
  claims stage 1 is still shaped right for a player who can double jump
- **More than one air jump** — the budget is an `int` so it can grow, but nothing sells a second one and the
  catalogue has no row for it. A knob nothing turns is not built
- **Points** — deferred, and **not buildable today.** The point budget does not exist anywhere
  (`town.md`'s header lists it under "Not done"); an unlock raising a ceiling nothing reads would be a false handle
- **Dice** — deferred on an undecided rule, not on cost. The field (`progress.dice_left`) and the button
  (`three_pick_window.gd:196`, inert on purpose) both exist; what is missing is `town.md`'s dice TBD, "how many per
  run" and what a reroll draws from. **The cheapest next axis, and the one that deepens the 30-원석 sink.**
  Whoever writes it must also dismantle `net_progress._dice_left_is_zero_and_inert` deliberately
- **Circles and glyphs as unlock targets** — needs an ownership concept neither has
  (`palette_layout.gd:67-68`). Not a price question
- **Saving** (`town.md`'s Saving TBD) — unchanged and still ownerless. Unlocks die with the process, as 원석 already does
- **Is 10 원석 right** — the user's number; this doc does not second-guess it. What it records is the pace:
  **~1 unlock per full run**, and a total sink of three purchases
