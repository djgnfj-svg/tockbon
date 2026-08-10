# The 문양 tab lists what's seated in the circle, not a held-glyph stash

**Status**: valid

## What was decided

The 문양 tab reads the circle directly: it shows exactly the glyphs currently placed in `SpellCircle`'s
layers, in order. It starts empty (no circle → no glyphs), gains an entry the instant a level-up three-pick
calls `place_glyph()`, and its one job is letting the player pick a seated glyph back up to move it between
1층/2층 — order changes the effect (확산→폭발 ≠ 폭발→확산).

No new ownership field. `palette_layout.items_of(KIND_GLYPH)` reads `_circle`'s layers, the same object the
muzzle and fire command already read.

## What wasn't chosen

| Rejected | Why |
|---|---|
| A held-glyph set in `Progress` (stash it, equip from the assembly window) | Exactly what `no-inventory.md` rejects — it defers the weight of the three-pick's choice, the same argument that closed the door on a bag |
| Everything that exists, undimmed, as today | Contradicts "문양 탭이 빈 채로 시작" |

## What's tied to it

- `docs/plans/3.done/onboarding-and-palette-tabs.md`, Behavior §2 and its TBD section — this closes the
  "what does the 문양 tab list" question that doc left open
- `no-inventory.md` — this decision extends its line ("growing during a run is an inventory; visible only
  in town is a list") to glyphs: there is nothing here that grows *behind* the screen, only what is already
  on it
- `net_pick._no_pushed_out_glyph_is_stashed_anywhere` — stays green with no allowlist entry, because no new
  top-level collection is added anywhere in `src/`

## Conditions to reopen

None.
