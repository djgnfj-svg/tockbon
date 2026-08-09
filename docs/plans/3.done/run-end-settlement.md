# Run-end settlement — the screen a run closes on

**Status**: implemented (A~D) · **screen unverified**. See "What landed" below — including the one thing
5,576 green checks did not catch. The four questions under "What only the screen can answer" are still open.
**One line**: the moment you go down, one full-screen panel shows **how long you played, how much damage you
dealt, and 원석 counting up** — one button on it sends you to the town.

**This is the last segment of the session loop** (`docs/GDD.md`, "session loop"). What follows it —
the town room, the benches — already runs (`3.done/town-room-and-fixtures.md`). What is missing is
**the join between the two**, and it is missing in the worst possible way: not blank, but *erasing*.

---

## Why

**Today a run does not close. It is deleted.**

`stage.gd:875` — going down, `E` calls `enter_town()` → `reset_stage()` → `Progress.reset()`, and
**xp, level and money go to 0 with nothing shown.** Thirty minutes of play leaves no trace and makes no sound.

Three consequences, all of them already visible in the repo:

1. ~~**Permanent progress has no entrance.**~~ **Half of this moved while the plan sat here.** `Progress.gems`
   exists now, both doors pay into it (boss 3~4, level 1), it survives `reset()`, and **the research window
   shows the count** (`3.done/town-room-and-fixtures.md`). ⇒ **What is left for this screen is the *showing*,
   not the earning**: today the run's 원석 is banked silently and the player sees the new number only if they
   walk to the bench. The count-up is still this doc's job, and its numbers are now real
2. **Death is the normal ending.** Early runs almost all end in a death, so a design that only pays out on a
   boss kill means most players never see permanent progress start
3. **The pool is invisible** — `town.md`'s own second reason for a town. A number that counts up on screen is
   the cheapest possible "something was kept"

---

## Behavior

### When it appears — **the instant you go down**

**Decided by the user.** Not on a keypress afterwards.

```
downed  ──▶  settlement screen  ──▶  [button]  ──▶  town
```

**This replaces the current `E`-while-downed door.** `_interact()`'s `if not _in_town: if _char.downed:
enter_town()` branch (`stage.gd:832-835`) and the HUD line `"   쓰러짐 — E로 마을에 돌아간다"`
(`stage.gd:1047`) both go away — **the screen is what tells you the run is over now.**

**Clearing uses the same screen.** There is no clear path in the game yet (`docs/design/README.md`:
"Stage transition — none", GDD's "An ending — None"), so **today only the death path can reach it.**
Building the ending is not this doc's job; **not making a second screen for it is.**

### What it records — **two numbers, and that is all**

| Number | Where it comes from | Exists today |
|---|---|---|
| **Total play time** | The run's tick count ÷ 20 (the sim is a 20Hz integer tick) | **No.** One counter |
| **Total damage dealt** | Summed where damage is applied — **two places, not one** (below) | **No.** One accumulator, two call sites |

**「one place」 was wrong, and getting it wrong makes a fire build read 0.**
`monster.gd:305` is the **direct-hit and blast** path only. **Burning damage never passes through it** —
`monster._burn()` shaves hp on its own, on its own contract ("it neither refreshes invulnerability nor is
stopped by it"). ⇒ Sum only line 305 and **a player who burns a whole forest down and dies sees 준 피해 0**,
in the game whose thesis is that fire spreads and water flows.

**Both paths feed the same accumulator.** Anything else that removes monster hp later (drowning, crushing)
joins here too — **the rule is "hp removed from a monster", not "a bolt connected".**

**No breakdown of which spell dealt what** (decided by the user — see "TBD"). It was wanted and was cut on
cost: a monster **does not know what hit it.** `hit_by_segment`/`hit_by_blast` return a bare power percent,
and `spell_sim`'s segment notice **deliberately carries neither rune nor generation** (`spell_sim.gd:175` —
"sending a value nobody uses makes it a false knob"). Attribution is a spell-pipeline change, not a screen
change, and putting the screen behind it would mean neither ships.

### What it settles — **원석**

**The research currency has a name: 원석.** It replaces the unnamed "material" in `docs/design/town.md`.

| Door | Amount |
|---|---|
| **A boss dies** | **3~4** |
| **A level is gained** | **1** |
| A trash-mob kill | **none** |

Trash mobs reach it **only through the level door** — they give XP, XP gives levels, levels give 원석.
Rejected branches and the farming argument: `docs/decisions/gems-from-bosses-and-levels.md`.

**Per-run yield**: a full clear ≈ 2 bosses × 3~4 + ~3 levels ≈ **9~11**. Dying at level 2 ≈ **2**.
⇒ **A death is never 0**, which is the whole reason this screen is worth opening in an early run.

### **원석 is already banked by the time this screen opens — so the screen shows a *delta***

~~**원석 is not awarded at the moment of the kill. It is derived on this screen.**~~ **Void, and it was
never safely true.** `Progress.gems` is raised **at the kill and at the level-up** (`add_boss_gems()`,
and the `add_xp` loop's `gems += GEMS_PER_LEVEL`), and it **deliberately survives `reset()`**.

⇒ Deriving it again here would **double-count**. And reading `Progress.gems` raw would count **every
previous run's** 원석 too, so the count-up would start at 40 and tick to 47.

**What the screen counts is this run's earnings**: `gems now − gems when the run began`.
**That is one new field** — a snapshot taken where the run starts (`_leave_town()`, the departure gate).
The earlier "no new run-state" claim in Cost is wrong and is corrected there.

**The boss amount is rolled, not fixed** — `randi_range(GEMS_PER_BOSS_MIN, GEMS_PER_BOSS_MAX)`, 3 or 4 per
boss. So **the total is not predictable from the run's events**, which is another reason the delta must be
measured rather than recomputed.

### The count-up is the whole animation

**Decided by the user**: 원석 climbs from 0 to the total, ticking as it goes ("띠리리링").
**It is the only motion on the screen.** Time and damage are printed; only 원석 moves.

---

## Screen

Full-screen. **The world is not visible behind it** and the sim stops — the run is over, so there is nothing
left to watch. (This is the one place the GDD's "a window never stops the world" does not apply; that rule
exists for multiplayer, and see "Bounds".)

```
        런 종료

   플레이 시간     12분 41초
   준 피해          8,420

   원석            ▸ 7        ← counts 0 → 7, ticking

        [ 마을로 ]
```

- **In-game text is Korean** (CLAUDE.md)
- **One button.** No "retry", no "quit" — the town is where a run closes and there is nowhere else to go
- Art discipline follows the existing windows (`docs/design/circle-art.md`). `assets/ui/icon_material.png`
  already exists (white-on-transparent, 24px) and **is the 원석 icon** — it was drawn for exactly this

---

## Bounds

- **원석 0** — died before any level and before any boss. **The screen still appears**; time and damage are
  non-zero, and the count-up stays at 0. It must not be suppressed: "you got nothing" is information
- **A very long run** — the time string needs an hour form, or it reads `241분`
- **Overkill** — `hp = maxi(0, hp - d)` clamps, so "damage dealt" and "hp actually removed" differ on the
  killing blow. **Pick one and say which** (see TBD); do not let the two exist unlabelled
- **Damage to the player, and self-damage** — the GDD's "magic hits the player too" means the player's own
  bolts hurt the player. **"Damage dealt" counts damage to monsters only**
- **`R` (rebuild the stage) does not settle.** It is a debug key; a run cancelled by hand pays nothing.
  **And `R` pressed while the screen is open must close it** — `reset_stage()` already cancels the circle
  window and the three-pick for exactly this reason; a settlement panel left standing over a fresh stage
  would be a screen reporting a run that no longer exists
- **Going down in the town must not open it.** The town allows casting and "magic hits the player too"
  still holds there, so **you can blow yourself down in the town.** The screen would then settle a run that
  never happened and offer a button to the room you are standing in.
  ⇒ **The trigger is `downed` AND not in the town.** The `_interact()` door being replaced already carried
  that guard (`if not _in_town`); removing the door must not remove the guard with it
- **Multiplayer breaks this** — see Cost

---

## Interaction with what exists

- **`Progress.reset()` erases the inputs — all but one.** `enter_town()` → `reset_stage()` →
  `_world.reset()` → `Progress.reset()` clears xp, level and money; **`gems` is the deliberate exception**
  and survives. ⇒ **Time, damage and the gem snapshot must be read before that chain runs**, and the button
  is what runs it. Get the order backwards and the screen counts 0 with no error anywhere — this repo's
  "screen and sim disagree" shape
- **Two strings still say 재료 on screen** — `stage.gd:890`'s research line and `fx_tuning.RESEARCH_FOOTER`
  ("재료로 푸는 해금은 아직 없다"), while the count beside them already reads 원석 (`RESEARCH_GEMS_FMT`).
  **One currency showing two names in one window.** Whoever builds this fixes those two strings; it is two
  words, and `town.md`'s own "home/town" story is what happens when a split name is left alone
- **`_char.downed` is the trigger**, the same state `stage.gd:1047` already reads for its HUD line
- **The three-pick may be open when you go down.** `Progress.is_pick_open()` — the settlement has to close
  it, the same way `reset_stage()` already calls `cancel_confirm()` for the circle window
- **The research bench must be able to spend 원석**, or it lands in a wallet with no shop. That is
  `town.md`'s work, not this doc's — but **this doc is what makes it possible**
- **`docs/GDD.md` "Drops"** — already fixed: "bosses only" is void, the two doors are boss and level.
  Read it there; do not restate the split here

---

## Cost

| Item | Price |
|---|---|
| Tick counter | One field. The tick loop already exists |
| Damage accumulator | **Two call sites** — `monster.gd:305` and `monster._burn()`. **`Progress` lives in `src/actor/`**, so no integer-determinism issue |
| 원석 delta | **One new field**: gems snapshotted at the departure gate. ~~No new run-state~~ — that claim was wrong (see Behavior) |
| The panel | A new window — and **cheaper than first written.** ~~UI is otherwise a debug label~~ is stale: `research_window.gd` already draws a panel, framed slots and tinted white icons, and `fx_tuning` already holds `RESEARCH_*` sizes and `RESEARCH_GEMS_FMT` |
| Damage-by-spell breakdown | **Not paid.** It needs rune/glyph provenance on the spell notice — a pipeline change |

**Two prices worth naming out loud:**

1. **There is no save file. None** — `user://`, `FileAccess` and `ConfigFile` appear **nowhere in `src/`.**
   ⇒ 원석 counts up, goes into memory, and **dies when the process exits.** This screen produces a permanent
   currency into a game that cannot yet keep anything permanent. **Building the count-up first is still
   right** (it is what makes the number real), but **the loop is not closed until saving exists**, and that
   has no doc and no owner
2. **Multiplayer.** "Down" is not "over" in co-op — an ally revives you (`character-damage-minimum`).
   A screen that opens the instant you go down is **single-player only** and reopens the day co-op arrives.
   The user chose the immediate screen knowing this

---

## Acceptance

1. Die in stage 1 → **the screen appears by itself**, with no key pressed
2. Play time on it matches roughly how long the run actually took
3. Damage shown is non-zero after killing anything, and 0 if you die having hit nothing
4. **Kill something with fire alone — never landing a direct hit — and the damage is still non-zero.**
   This is the check the first draft would have failed
5. Kill the bull, then die → 원석 counts up to **3~4 plus one per level**
6. Die at level 0 having killed no boss → the screen still appears and 원석 stays at 0
7. **Do a second run and die → the count-up shows only the second run's earnings**, not the running total.
   (The research bench is where the total lives)
8. Press the button → **the town**, and time, damage and level are gone; **원석 is not**
9. **Blow yourself down in the town → nothing opens**
10. **Press `R` while the screen is open → it closes** and a fresh stage stands, unsettled

---

## TBD

- **Do death and clearing look different on it** (`town.md`'s own TBD, now landing here). Same screen is
  settled; whether a clear adds a bonus or a line is not
- **"Damage dealt" or "hp actually removed"** — the overkill split above. One of them, named on screen
- **Damage broken down by spell** — the user asked for it and deferred it. **The unit is also undecided**:
  by rune · by glyph · by circle slot · **by pipeline stage** (direct hit / spread's children / blast).
  The last one is the only one where `spread→blast` and `blast→spread` produce different numbers, which is
  the GDD's own thesis appearing in figures for the first time
- **What one unlock costs in 원석.** `town.md` says three materials per unlock against a 1~2 per-run yield;
  at 9~11 per run that is far too cheap
- **Saving.** No doc, no owner (see Cost)
- **Whether the sim really stops behind the screen**, or the world keeps running unseen. Assumed stopped
- ~~**The exact boss number, 3 or 4**~~ — **settled by the code that shipped meanwhile**: it is *rolled*,
  `randi_range(3, 4)` per boss. **Whether the two stage-1 bosses should differ is still open**
- **Does self-damage subtract.** "Damage dealt" counts hp removed from monsters, so blowing yourself up
  shows nothing. Fine today; the day a "피해량" figure is meant to read as *skill* it stops being fine

---

# Implementation plan

## What was checked against the code first — three of this doc's claims are stale

**Read this before trusting a line number above.** The doc was written against an older `stage.gd`.

| The doc says | The code says |
|---|---|
| `stage.gd:875` — the downed door | **`stage.gd:843-846`.** Line 875 is `_toggle_research`'s own `decline()` call |
| `stage.gd:832-835` — `_interact()`'s branch | **`stage.gd:842-846`** |
| `stage.gd:1047` — the downed HUD line | **`stage.gd:1070`** |
| `stage.gd:890` — the research line still saying 재료 | **True.** `research_text()`, line 890 |
| `Progress.gems` exists, both doors pay, survives `reset()` | **True** (`progress.gd:67`, `:144`, `:155`, `:286`) |
| The research window shows the count | **True** — `research_window.gd:106`, `Fx.RESEARCH_GEMS_FMT` |
| `monster.gd:305` is the direct/blast path and `_burn` is separate | **True** — `:305` and `:347`, two independent writes to `hp` |

**And one thing this doc asks for cannot be built at all**: the count-up's "띠리리링". There is **no audio
anywhere in this project** — not one `AudioStream*`, no audio bus config in `project.godot`, no audio folder
under `assets/`. **Settled by team-lead: the count-up is silent** ("Decided" below).

## Structure — is this a variant or a new kind

**Three variants and one new kind.**

- The three run numbers are **one more field each on `Progress`**, beside `xp`/`money`/`gems`. Variant
- The damage accumulator is **one more door on `Monster`** — `hp` already has exactly two write sites, and
  folding them onto one function is a narrowing, not a new axis. Variant
- The 원석 delta is **one field plus one line inside `reset()`**. Variant
- **The panel is a new kind**: a full-screen window that stops the world. It cannot be a variant of
  `research_window` (takes no clicks) or `three_pick_window` (does not stop the sim), so it is its own node —
  but it copies `three_pick_window`'s node contract verbatim: seat from `Fx`, `mouse_filter = STOP`,
  `focus_mode = NONE`, its clock ticked from `stage._physics_process`, never its own `_process()`

**And it breaks a standing claim in the repo, which is why it has to be a new kind and not a variant.**
`circle_window.gd:13-15` says, about the whole codebase:

> Being able to shoot from outside is the evidence for "the world does not stop" (design acceptance 4).
> **That is why no full-screen `Control` is laid down** — the moment the screen is covered, `IGNORE` or
> `STOP` alike, that evidence disappears or firing dies.

This screen is **the declared exception** (this doc's own Screen section: "the one place the GDD's 'a window
never stops the world' does not apply"), and it is safe only because it exists solely once the run is over —
there is nothing left to shoot. **That sentence in `circle_window.gd` becomes false the day this ships**, so
Stage D narrows it to "no full-screen `Control` **while the run is live**" and points at this doc. Leave it
and the next person reads a rule this feature already broke.

**Files to add one more settlement number later: two** (`progress.gd`, the panel's layout). Under the three.

## Stages

### Stage A — the three run numbers, in `Progress`. No screen at all

| File | Change |
|---|---|
| `src/actor/progress.gd` | `run_ticks`, `damage_dealt`, `_gems_at_run_start` (all `int`). `advance_tick()`, `add_damage(n)`, `gems_this_run()`, `run_seconds()`. `reset()` zeroes the first two and **re-snapshots the third** |
| `src/actor/monster.gd` | **One door for hp removal.** `_apply_damage(n)` used by both `:305` and `_burn`, accumulating `_dealt_acc: float`→`int`. `take_dealt()` drains and returns |
| `src/actor/world_step.gd` | Tick branch: `_progress.advance_tick()`. Monster loop, right after `m.on_tick(...)`: `_progress.add_damage(m.take_dealt())` |

**Why the drain sits in the tick loop and not the 60Hz `step()` loop.** A monster that dies is removed inside
the tick branch and never reaches the 60Hz loop again — draining there would **lose the killing blow.** The
tick loop sees every monster, dying ones included, before removal.
**The bound this leaves**: up to one tick of burn on monsters *still alive* the instant the sim stops is
never drained. Named, not hidden.

**Why `_gems_at_run_start` is set inside `reset()` and not at the departure gate.** `reset()` is the one
place that means "a run begins" — the gate, R, and going home all route through it (`stage.reset_stage()` →
`_world.reset()` → `Progress.reset()`). Setting it at `_leave_town()` would be a second place, and `R`
mid-run would then leave the delta measuring across a run that no longer exists.

**Overkill, decided**: `_apply_damage` records `mini(hp, n)` — **hp actually removed**, which is this doc's
own stated rule ("hp removed from a monster"). **The on-screen word is 준 피해** — settled by team-lead.

**What nets measure — all of it, headless.** Extend `tests/nets/net_progress.gd`:
- `run_ticks` rises **once per tick, not once per frame** — drive `frame()` `TICK_DIVIDER * N` times, expect `N`
- A burn-only kill moves `damage_dealt` — **no spell fired at all.** This is acceptance 4, headless
- Overkill: a monster at 5 hp taking 100 adds **5**
- `_char.take_hit()` does not move `damage_dealt` (Bounds: monsters only)
- `reset()` zeroes both counters, leaves `gems`, and makes `gems_this_run()` **0 while `gems` stays**
- Two runs in one process: boss → reset → boss → `gems_this_run()` is the **second roll only**. Acceptance 7
- **Inversions to run**: put the drain back in the 60Hz loop (the killing-blow check must go red);
  revert `_burn` to writing `hp` directly (the burn check must go red); delete the `reset()` snapshot line
  (the two-run check must go red)

### Stage B — the constants and the pure layout. Still no node

| File | Change |
|---|---|
| `src/view/fx_tuning.gd` | A `SETTLEMENT_*` block at the end: `SETTLEMENT_RECT` (the **whole** 960x540 canvas), opaque bg, title `런 종료`, the three line formats, the button text `마을로`, the count-up rate. The 원석 icon is `RESEARCH_ICONS["material"]` reused, not a sixth entry |
| `src/view/settlement_layout.gd` (new) | Static/pure, the seat `research_layout.gd` and `pick_layout.gd` already hold. `rows(size)`, `button_rect(size)`, `time_text(seconds)`, `count_value(total, frames)` |

**`time_text` carries the hour form** — the Bounds item ("a very long run reads `241분`"). It is a pure
function of an integer, so it is measured by value, not looked at.

**`count_value` is where the animation lives**, not in the node — a pure `(total, frames) -> int` curve that
a net can walk end to end.

**Nets** — new `tests/nets/net_settlement.gd`:
- `button_rect` is inside the panel, has a size, and does not overlap any row rect
- `time_text`: `0초` · `41초` · `12분 41초` · and past an hour it is **not** `61분`
- `count_value` starts at 0, never decreases, lands **exactly** on the total, and lands within a bounded
  number of frames. **`count_value(0, k) == 0` for every k** — the 원석 0 case that must still open
- **Inversion**: make `count_value` return `total` immediately → the "starts at 0" check goes red

### Stage C — the window node

| File | Change |
|---|---|
| `src/view/settlement_window.gd` (new) | `extends Control`. `_ready()` seats from `Fx.SETTLEMENT_RECT`. `open(seconds, damage, gems)` snapshots **three ints** and starts the count-up. `is_showing()`, `close()`, `tick_countup()`, `_gui_input`, `_draw`. Emits a signal when the button is clicked |
| `src/stage/stage.tscn` | `SettlementWindow` (Control) under `HUD`, `visible = false`, **`mouse_filter = 0` (STOP)** |

**It snapshots, it does not read `Progress` live.** The button runs `enter_town()` → `reset_stage()` →
`Progress.reset()` in the same call; a live read would have the panel drawing 0 on the frame it closes, with
nothing barking. This is the doc's own "get the order backwards" trap, closed by construction.

**A signal, not a call into the shell.** ~~`src/view/` may not reference `src/stage/`~~ — **that rule does
not exist and this plan invented it.** `net_layers.RULES` (`:29`) is `"res://src/view": []` — view is
forbidden nothing, and `town_view.gd:14` already preloads `src/stage/town_map.gd`.
**The real reason is testability**: a window that calls the shell cannot stand up without a stage, and the
whole net technique below (drive an untreed node, read the result) dies with it. Signal, for that reason.

**`tick_countup()` is called by `stage._physics_process`, not by this node's `_process()`** — the exact
lesson `three_pick_window.tick_confirm()`'s own header records: a screen clock on the idle rate and a HUD
reader on the physics rate open a one-frame seam.

**Keep every field an `int`.** `net_pick._no_pushed_out_glyph_is_stashed_anywhere` scans **every** `.gd`
under `src/` for a column-0 `var`/`static var` of `Array`/`Dictionary`/`Packed*Array` — typed or literal,
**private counts too** (`_drawn`, `_icons` are on its allowlist), annotations consumed. A collection field
here means an allowlist entry, avoidable. **`const` is not scanned**, so a `SETTLEMENT_*` `const Dictionary`
in `fx_tuning.gd` is free.

**Nets** (`net_settlement.gd`, driving the **untreed** node — the technique `net_render` and `net_pick`
already use): `_ready()` produces exactly `Fx.SETTLEMENT_RECT`; `open()` then `tick_countup()` N times walks
the shown 원석 from 0 to the total; `_gui_input` inside the button rect fires the signal and outside it does
not. **`_draw()` is not measurable headless** (no font untreed) — that half is verify-look's.

### Stage D — the wiring. This is the stage that turns other nets red

`src/stage/stage.gd`, in this order:

1. `@onready var _settlement := $HUD/SettlementWindow`; `_ready()` calls `setup(...)` and connects its signal to `enter_town`
2. `_physics_process`: **gate the world** — `if not _settlement.is_showing(): if _world.frame(...)`. Then
   `_settlement.tick_countup()` beside `_pick_window.tick_confirm()`
3. **Derived open, not pushed.** `want := _char.downed and not _in_town`; on the rising edge, `open(pr.run_seconds(), pr.damage_dealt, pr.gems_this_run())`; when false, `close()`. Derivation is what makes Bounds
   "going down in the town must not open it" and "R closes it" true **by construction** — `_char.place()`
   restores hp (`character.gd:313`), so R and `enter_town` both clear `downed` on their own
4. The open path also calls `_world.progress().decline()` and `_pick_window.cancel_confirm()` — the
   three-pick may be open when you go down
5. **Delete** `_interact()`'s `if _char.downed: enter_town()` (`:844-845`). Keep the `if not _in_town: return`
6. **Delete** the HUD string `"   쓰러짐 — E로 마을에 돌아간다"` (`:1070`)
7. `_hud.visible` gains `and not _settlement.is_showing()` — otherwise the debug readout prints over the panel
8. `reset_stage()` calls `_settlement.close()`, beside `_pick_window.cancel_confirm()` and for the same
   reason: the count-up clock does not live in `Progress`, so nothing else would clear it
9. **The two 재료 strings** → 원석: `stage.research_text()` (`:890`) and `Fx.RESEARCH_FOOTER` (`fx_tuning.gd:1486`).
   **Checked: no net asserts either string's text**, so this is a two-word edit with no net to follow
10. `src/view/circle_window.gd:13-15` — narrow "no full-screen `Control` is laid down" to "…while the run is
   live", pointing at this doc. See Structure above

**Nets that must be edited in this same commit or they go red for the wrong reason:**

| File | Edit |
|---|---|
| `tests/nets/net_render.gd` | `INTERACTIVE` += `"HUD/SettlementWindow"` (it eats clicks — without it the `mouse_filter` contract demands IGNORE). `OUT_OF_TREE_SIZE_ZERO` += `"SettlementWindow"` (it sizes itself in `_ready()`). **`_wired_stage_root` must `set("_settlement", ...)`** — every check there that drives `_physics_process`/`_update_hud`/`reset_stage` dies on a null otherwise, which is the accident that file's own comments record four separate times |
| `tests/nets/net_town.gd` | Two edits, not one. (a) `_the_gate_leaves_and_being_downed_comes_back`'s second half (`:479-486`) **is now false by design**: E while downed no longer goes home. Rewrite it as downed → the panel opens → its button → the town. **Do not delete it** — it is the only check that measures the loop closing. (b) **`_wired_root` (`:502-532`) must `set("_settlement", ...)` too** — its last line is `root.call("reset_stage")` (`:531`), and item 8 above puts `_settlement.close()` inside `reset_stage()`, so every check in this file dies on a null before measuring anything |

**Checked, and they do *not* need wiring**: `net_damage.gd:557` and `net_background.gd:275` also instantiate
`stage.tscn`, but neither calls `reset_stage()`/`_physics_process()`/`_update_hud()` — `net_damage` drives
`_world.frame()` directly and `net_background` only reads nodes. `net_tables.gd` uses `Stage`'s statics only.
**Do not widen the edit to them.**

**New checks (`net_settlement.gd`, through its own `_wired_root` — copied, not imported, the duplication
`net_town.gd` already declares and justifies):**
- Go down in the stage, drive `_physics_process` → showing, and the three snapshot values equal `Progress`'s
  live values at that instant (**the fake this catches: a panel that prints a plausible number**)
- Blow yourself down **in the town** → not showing. Acceptance 9
- While showing, `_grid.get_tick()` **does not move** across N `_physics_process` calls. The sim really
  stops, measured as a value rather than assumed (this doc's own TBD)
- Click the button → `_in_town` true, `xp`/`level`/`damage_dealt`/`run_ticks` all 0, **`gems` unchanged**. Acceptance 8
- `reset_stage()` while showing → not showing, `_in_town` still false, a fresh stage. Acceptance 10
- `_interact()` while downed in the stage → **stays in the stage.** The old door is gone
- 원석 0: go down having killed nothing → **still showing**, count-up stays 0. Acceptance 6

### Stage E — docs

**Done with the move to `3.done`.** This doc was linked by path from six places
(`decisions/run-end-is-settlement-only.md`, `design/town.md` ×3, `GDD.md` ×2,
`plans/3.done/town-room-and-fixtures.md`) plus the source and net comments that name it; all were repointed
and the `**Status**:` line above rewritten. **Links leak every single time** — grep the whole repo for the
filename, not just `docs/`.

## Order — and why

**A → B → C → D.** A first because a panel built against numbers that do not exist yet is a panel drawing a
hardcoded lie, and that lie passes every screenshot. B before C because the node draws the layout. D last
because it is the only stage that touches other nets.

## What landed — and **what 5,576 green checks did not catch**

A~D are all in: `Progress` gained `run_ticks` · `damage_dealt` · `gems_this_run()`, the pure layout is
`src/view/settlement_layout.gd`, the node is `src/view/settlement_window.gd`, and `stage.gd` wires it.
The panel is opened by **derivation, not by pushing** — `want := _char.downed and not _in_town`, opened on the
rising edge. **Do not replace that with a latch** (Risk 3: a stranded-open STOP panel makes the whole game
unclickable and nothing barks).

**The find**: **nobody ever set `visible`.** All 5,576 checks were green, nothing appeared on screen, and there
was no way out of the state. `queue_redraw()` was missing too, so the count-up would have been a still frame.
**Both fixed, and the nets now measure both** — this is the exact failure shape CLAUDE.md names, a check that
reads state a real player never reaches.

Both open questions closed as recorded under "Decided" below: **no count-up sound** (this project has no audio
subsystem at all) and **damage = hp actually removed**, shown as 준 피해.

## What only the screen can answer (verify-look) — **still open, none of it has been seen**

Everything below is invisible to a headless net and must be looked at:
- Does the panel read as *the run is over* rather than as a window that failed to close
- Does the count-up read as counting — the rate, not the endpoints
- Is the 원석 icon legible at 24px on this panel's background
- Is the button obviously the only thing to press

## Risk

1. **`net_render._wired_stage_root` without `_settlement`** — ~15 checks die on a null before measuring
   anything. Highest-probability break in this whole plan
2. **`_hud.visible`** — forget item 7 and the debug readout prints on top of the panel. Nothing barks
3. **`mouse_filter = STOP` over the whole viewport**: correct while showing, and **the entire game is
   unclickable with no error** if `visible` is ever stranded true. The derivation in item 3 is what makes a
   stranded-open state impossible — do not replace it with a latch
4. **The signature fake for this feature**: the screen moves and the sim does not (a number derived on the
   panel instead of accumulated). The two nets that make it impossible are the burn-only damage check and
   the second-run gem-delta check. **Neither may be softened**
5. `Progress.reset()`'s snapshot line — add a second `reset()` call site mid-run later and the delta silently
   reads 0. Comment it where it sits
6. Up to one tick of burn on living monsters is never drained (Stage A). Bounded and named

## Out of scope

Saving. The clear path (there is no ending in the map). Damage broken down by spell. Unlock prices. Audio.
Multiplayer revive. Whether the two stage-1 bosses pay different amounts.

## Decided — both open questions are closed

1. ~~**The count-up's sound**~~ — **silent.** There is no audio subsystem in this project at all (not one
   `AudioStream*` under `src/`, nothing in `project.godot`, no audio assets), and standing one up is out of
   scope. Decided by team-lead. **The count-up is visual only**, and this doc's "띠리리링" is void
2. ~~**Damage dealt or hp removed**~~ — **hp actually removed** (`mini(hp, n)`), **shown as 준 피해.**
   Decided by team-lead. This closes the Overkill line in Bounds and the second TBD

## Correction log — what this plan claimed and got wrong

**One false rule was written into this plan and caught by team-lead. It is corrected in place above; it is
recorded here because a plan that quietly fixes itself teaches nothing.**

| Claimed | Actually |
|---|---|
| `src/view/` may not reference `src/stage/` (`net_layers.RULES`) | **False.** `net_layers.gd:29` is `"res://src/view": []` — view is forbidden nothing, and `town_view.gd:14` already preloads `src/stage/town_map.gd`. The conclusion (a signal) stands; only the reason changed |

**The other three net claims were re-checked against the files and hold** — `net_pick`'s scan really does
sweep all of `src/` for `var` collections (`const` excepted, now stated); `net_render`'s `INTERACTIVE` (`:43`),
`OUT_OF_TREE_SIZE_ZERO` (`:632`) and `_wired_stage_root` (`:1321`) are as described; `net_town`'s downed→E
check (`:479-486`) really does become false.
**And the re-check turned up two things the first pass missed**: `net_town._wired_root` needs the same
wiring, and `circle_window.gd:13-15` states a repo-wide "no full-screen `Control`" rule that this screen
breaks (both folded into Stage D above).
