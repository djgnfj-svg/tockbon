# Run-end settlement — the screen a run closes on

**Status**: ready
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
