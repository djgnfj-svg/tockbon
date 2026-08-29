# 28 — Fuse the chosen shoreline (27-gaps) with the new blocks

Status: open
Type: task
Chunk: 1 맵

## What was decided

**2026-08-29. Twenty-seven sea shaders were built side by side and the user chose `27-gaps`.** They
live in `prototypes/swash/`, each folder carrying a `NOTES.md` with what it buys, what it costs and
what it cannot do. **Nothing in `src/` was touched** (the user: 「프로토 타입 view를 만들어주는거임 ㅇㅇ
본코드 건들지말고」).

**The chosen sea, in one list** — every line of it is a measurement the user made by eye:

- **Two whites, not one.** A line on the rock and a second stroke about **0.22 tiles** off it, with dark
  water between. ⚠⚠ **The second one is a LINE, not a band** — every 거품 drawn before it was a soft
  wash fading outward, and the user's reference frames have a hard stroke
- **Thin and hard-edged** — `line_tiles` **0.035**, `line_hard` **0.85**. ⚠⚠ **The hardness, not the
  width, is what makes a line read as thin**: a soft edge spends most of its width fading, so it looks
  thick however narrow it is set
- **Slow** — `rate` **0.16**, a run about every six seconds (the user: 「너무 자주 하는데 파형이 좀더
  느리게」)
- **A resting width and a surge, kept separate** — `rest_frac` **0.45** of the line is on the rock doing
  nothing, and the wave ADDS `surge` **0.80** on top, riding `up`. ⚠ The one-width version left a trace
  on screen before any wave arrived (the user: 「미리 흔적이 너무 남아있는느낌이야 기본값이 너무 있어」)
- **It breaks up** — the outer stroke is cut both ways: a slow drifting noise gate AND the coast's own
  curvature, so it is missing off some stretches and absent inside the coves
- **The refraction and the travel from 06 and 08** — the bays stay quiet because they are bays, and the
  pattern crawls along the shore so a quiet stretch does not stay quiet forever

## What this ticket is

**Put that shader on the game's sea, against the island as it is NOW.**

⚠⚠ **The island was re-baked several times during that session and the block builder changed by 565
lines.** The outline went from 112 segments to 280 to 168 while the candidates were being judged, so
**every distance in the chosen shader was tuned against a coast that no longer exists.** The numbers
above are the starting point, not the answer.

**What has to be re-judged by eye on the new blocks**, and nothing else:

- **`second_at` 0.22 tiles** — how far off the rock the outer stroke sits. If the new blocks are a
  different size, this is the first number that will look wrong
- **`curve_step` 0.30 tiles** — the stencil the bend is measured with. ⚠ **It cannot see a bend smaller
  than about a third of a tile**, and the outline now turns on a different unit
- **`cut_scale` 0.55** — how long a surviving piece of the outer stroke is

## How to see it

```
Godot_v4.7.1-stable_win64.exe --path . -s prototypes/swash/island_lab.gd 27
```

**0..9 pick, SHIFT+n for the tens, CTRL+n for the twenties · LEFT/RIGHT step · Q/E turn · W/S zoom ·
R/F tilt.** Index 0 is the shipped sea, so the comparison is one keypress away.

⚠ **The lab reads `src/` for its dials only** — `look.gd` — and does everything else itself. It called
the game's own bake for one round and went down with `src/` when that would not parse.

## ⚠⚠ It contradicts the glossary, and that is the decision

`CONTEXT.md` defines 해안선 as the line **whose thickness does not change wherever the wind blows from —
because the water is always touching the land**, ringing the island without a gap.

**`27-gaps` thins the inner line where the outer one is missing.** It never removes it, but 「빠짐없이」
is no longer true. ⇒ **When this ships, that row in the glossary is corrected, and the reversal is
written onto it rather than deleting it.**

## What is NOT in this ticket

- **Bodies, boats and the HUD.** The island lab shows the island and the sea only. **A sea that survives
  it still has to be looked at with a fight running on top of it** — that is a separate look
- **The wafer lab** (`prototypes/swash/lab.gd`). It answered *how does the line move*; this ticket is
  about the island
