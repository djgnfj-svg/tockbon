# A boss always has a slot because `spawn_monster` reserves one — not because the table is short

**Status**: valid

## What was decided

`spawn_monster` refuses a **non-boss** kind at `MAX_MONSTERS − reserve` and a **boss** kind only at
`MAX_MONSTERS`, with the reserve **derived** from the boss-kind rows in the pushed table. `BossAi.has_pattern()`
is already this repo's boss gate. A refused boss row then `push_error`s as an unreachable backstop.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **Keeping pre-① rows under the cap by convention** — what today's build does | **It is already off by one.** 20 trash rows + the bull = 21 against a cap of 20; `world_step` returns 0 at the cap and `wake_scan` never spends the row on refusal, so a player who kills nothing arrives at the pit and **the midboss does not exist** — and the fire rune behind it, and the wall behind that. **No error anywhere.** CLAUDE.md's signature fake, in the build right now |
| "18 rows so it fits" | The same convention one level down. A future edit adds one row and deletes the guarantee; the failure stays exactly as silent |
| A hand-typed reserve count (`2`) | Same again. `set_rows()` already walks the table — **the number of boss rows in it *is* the reserve** |
| **`push_error` alone**, with no reserve | Honest, and still ships a stage whose fire rune is unreachable. **"Say you can't" is about not lying, not about leaving the stage broken** |

## What's tied to it

- **The pre-① mob budget stops being a tightrope.** Clumps can be counted for pacing instead of for headroom
- The existing row-count net asserted `pre_count <= MAX_MONSTERS` — 20 ≤ 20, green, while 21 is the number that
  mattered. Its bound becomes `MAX_MONSTERS − boss_rows`, and a **driving** check (fill to the trash ceiling,
  wake a boss row, assert it lives) is what actually measures this
- ⚠ **The reserve is measured. The bark is not, and no net in this repo can measure it.** `t.expect_error`
  (`tests/run_nets.gd`) is a bare `print("[EXPECT] …")` — it hands the wrapper an **amnesty** so a legitimate
  bark does not fail the silence check, and it **never asserts the bark happened.** ⇒ **Delete the
  `push_error` line outright and the check beside it stays green.** Confirmed by reading the runner.
  **So this decision is half-covered**, and the covered half is the half that matters (a boss always lands);
  the backstop rides on nothing but the next reader. **Not worked around here** — a net grepping
  `world_step.gd` for the string would measure the file's text and never what it computes, which CLAUDE.md
  lists as a fake-net shape this repo has been evaded on five times in one feature. The real fix is an
  "and it must actually fire" mode on `expect_error`, which closes this and several others at once

## Conditions to reopen

If a stage ever wants more bosses live at once than the cap leaves room for. Then the cap moves, not the reserve.
