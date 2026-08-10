# docs/decisions — what wasn't chosen, and why

Decisions come out of conversation and only the outcome dissolves into the GDD and design docs.
**The answer to "why didn't we do that?" survives nowhere, so the same deliberation happens again.**

**Record only the rejected side.** The chosen side survives in code and design docs.

**If "what wasn't chosen" is empty, it isn't a decision. Don't file it.** Nor is picking a value ("let's make it 20").

Never moves folders. Don't delete a reversed one — why it reversed is the grounds for the next decision.

## Format

```markdown
# <the decision in one sentence>

**Status**: valid | reversed (by what)

## What was decided
Two or three lines.

## What wasn't chosen
| Rejected | Why |

## What's tied to it
Where it shakes if this reverses.

## Conditions to reopen
"None" if none.
```

## Index

| Decision | Status | Rejected |
|---|---|---|
| [No inventory](no-inventory.md) | valid | Stash it and equip from the assembly window |
| [Shot explosion is blocked by rule](shot-explosion-by-rule.md) | valid | Using the simultaneous-projectile cap as a knob |
| [The town is a mode of the stage shell](town-is-a-mode-of-the-stage-shell.md) | valid | A `town.tscn` of its own · a smaller town map · painting it in the editor · real bench windows |
| [The run-end screen is settlement only](run-end-is-settlement-only.md) | valid | A run summary (the circle you assembled) · a second screen · a cause-of-death shot · the end-of-content notice in the town |
| [원석 comes from bosses and levels](gems-from-bosses-and-levels.md) | valid | Every kill drops it · trash mobs give a little · bosses only (the old GDD line) |
| [Trash mobs lie on the map](mobs-lie-on-the-map-no-arena-room.md) | valid, **one row reversed** | A combat room before the midboss · trigger spawning · spawners · ~~clumps~~ (**reversed — clumps are back**) |
| [Cut the terrain, not the spawn](cut-the-terrain-not-the-spawn.md) | valid | Moving `SPAWN_TILE` east · calling the redraw a day's work |
| [Shelves are jumped onto, not walked up](shelves-are-jumped-onto-not-walked-up.md) | valid | A ground mound · 3 tiles · a floating shelf · a cliff nook · narrow-gap pillars |
| [Boss slots are reserved in the spawn door](boss-slots-are-reserved-in-the-spawn-door.md) | valid | A row-count convention · a hand-typed reserve · `push_error` alone |
| [No pass-through platform material](no-pass-through-platform-material.md) | valid | A one-way platform material · "there are no palette slots" as the reason |
| [Unlocks are runes and the double jump](unlocks-are-runes-and-the-double-jump.md) | valid | The 점수 axis · the 주사위 axis · circles and glyphs · one field per axis |
| [The back door does not close](the-back-door-does-not-close.md) | valid | A door closing behind you at the bull · reusing the gate's terrain beat · cutting the camera zoom instead |
| [The palette hides what you do not own](palette-hides-what-you-do-not-own.md) | valid, **reverses `rune-lock-and-receiving`'s "veiled, not hidden"** | Veiled cells · gating in `_slot_accepts` · a harder dim · hiding everything unplaceable |
| [「마법진 완성」 confirms, it does not apply](circle-done-button-is-confirm-not-apply.md) | valid | An apply button · a draft circle · no button at all · a cancel button |
| [The 응축 pillar leaves no material](condense-leaves-no-material.md) | valid | Leaving water · leaving standing fire · a material of its own |
| [The rune is used where it is won](the-rune-is-used-where-it-is-won.md) | valid | **The pit's water escape** · the wood wall outside room ① · a ramp out of the pit · keeping the flood as the exit |
| [No trash run between the two bosses](no-trash-run-between-the-two-bosses.md) | valid | A trash run between midboss and boss · redistributing ②'s 12 rows · waking ② by landing the water escape |
| [The door burns only from the fire rune](the-door-burns-only-from-the-fire-rune.md) | valid | A sill above the fire's reach · accepting the room opening mid-fight · the bull's fire no longer sticking |
| [The 문양 tab shows the circle](the-glyph-tab-shows-the-circle.md) | valid | A held-glyph stash in `Progress` · everything that exists, undimmed |
| [The click radius does not scale with the bigger art](click-radius-does-not-scale-with-the-bigger-art.md) | valid | Leaving `SLOT_HIT_RATIO` at 1.8 · 1.3 (measured insufficient) |
| [Player gravity is split from the shared constant](player-gravity-split-from-the-shared-constant.md) | valid | Lowering the shared `GRAVITY_PX` itself · leaving the player unpatched |

## Decisions not yet written down

| Decision | Where it's buried |
|---|---|
| The three circles are not a ladder — more runes means fewer layers | `GDD.md`, Circle |
| The bull's fire sticks to terrain → move the wood wall outside ① | `plans/3.done/stage1-bosses.md`. ⚠ **The second half is reversed** — the wall comes back *into* room ① ([the rune is used where it is won](the-rune-is-used-where-it-is-won.md)); the fire sticking is untouched |
| Unlimited jumping underwater — neither buoyancy nor swimming | `plans/2.active/water-jump-and-escape.md` |
| The map is fixed (dungeons are not generated) | `design/terrain-baking.md` |
| The shop is at the stage transition (not inside the map) | `plans/3.done/levelup-and-three-picks.md` |
| Permanent currency comes from bosses only | Same doc |
| There are no potions | `GDD.md`, Equipping and firing |
| Hitstop was dropped — replaced by flash duration | Code comments only |
| The rooster lands (it doesn't stay airborne) | `plans/3.done/stage1-bosses.md` |
| Pit ①'s water comes from the bull — reward first, then the wall collapses | Same doc. ⚠ **The escape it served is dropped** — see [the rune is used where it is won](the-rune-is-used-where-it-is-won.md); whether the pour itself is deleted is that design doc's TBD |
