# 원석 (the research currency) comes from bosses and levels — never from a trash-mob kill

**Status**: valid

## What was decided

The permanent research currency has a name — **원석** — and exactly two doors:

- **A boss** — 3~4 per kill
- **A level** — 1 per level

Trash mobs give **no 원석 directly.** They already give XP, and XP is what levels you, so they reach the
currency **through the level door only** — the same single-door shape the GDD already uses for glyphs
("glyphs enter through the single door of levelling up").

## What wasn't chosen

| Rejected | Why |
|---|---|
| **Every kill drops 원석** | Makes grinding strictly profitable and breaks the GDD's "killing is a gain, walking past is also a gain" — XP was safe to give per kill because it dies with the run; a permanent currency is not |
| **Trash mobs give a little, bosses a lot** | The middle option. Same farming pressure, only weaker — it buys a longer count-up with a rule that has to be capped to stay honest |
| **Bosses only** (the GDD's own line, unchanged) | Kept the rule but left 1~2 per run. **The settlement screen's count-up has nothing to count** — two ticks and it is over |

## What's tied to it

- **`docs/GDD.md` "Drops" says permanent currency comes from bosses only.** That line now has a second door
  (level). It is not a reversal of the farming logic — no *kill* pays out — but the sentence needs fixing
- **The per-run yield**: a full clear ≈ 2 bosses × 3~4 + ~3 levels ≈ **9~11 원석**. A death that reached
  level 2 ≈ **2**. ⇒ **A death is never 0**, which is what makes the settlement screen worth opening early on
- `docs/design/town.md`'s unlock price ("three materials per unlock") was written against 1~2 per run and
  is now far too cheap

## Conditions to reopen

If levelling ever gives something else again (it gives only the three-pick today), the level door becomes a
second reward on one event and this splits.
