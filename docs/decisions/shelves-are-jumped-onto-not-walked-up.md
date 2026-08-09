# The left run's vertical axis is a shelf you jump onto — not a mound, and not 3 tiles

**Status**: valid

## What was decided

The flat gets `STONE` shelves whose top is **2 tiles (64px) above the local ground, with vertical sides,
filled solid to the ground.** Hens stand on them. The user's requirement was **"올라가기 편할 듯"** — a
comfortable hop, not a climb.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **A ground mound** (offered to the user, refused) | **Mechanical, not cosmetic.** `Character.STEP_CELLS` is 2 = **8px** of automatic step-up, so a 64px vertical face is a wall and the **only** way up is the jump — which is the whole affordance being bought. A mound is a slope you walk up, and it erases that. It is also the mobs' wall by 3px, which is what separates the hen on top from the ground fight |
| **3 tiles (96px)** — an earlier draft's height, to buy clearance underneath | The **measured** jump ceiling is 102px (`character.gd`'s hold-vs-height table at `JUMP_CUT_RATIO` 0.2 — the 108px beside it is the formula). 96px leaves **6px** and demands a near-full hold. Terrain is authored in tiles, so 64 and 96 were the only candidates; 64px is cleared exactly by a 0.10s press. **A near-frame-perfect hold is not "올라가기 편할 듯"** |
| A **floating** shelf | `resolve()` climbs upward while the cell above is solid, so a filled shelf resolves a hen onto its top **with today's code**. Floating needs a `ty` hint column in `stage1_monsters`, an author-time-vs-runtime split, and reopens that table's "`y` is never written down" principle |
| A cliff nook to hold the shelf | The flat has no cliffs. Authoring them inverts the terrain into trenches and reads as a different feature |
| Pillars with gaps too narrow to enter | The narrowest mob box is the pig at 44px, so gaps would have to be under 1.4 tiles — a filled shelf with decorative holes, at the cost of a rule nobody can check by looking |

## What's tied to it

- **Filling to the ground is what makes ordinary `STONE` survivable.** A 1-tile floating slab leaves 32px of
  clearance against a 64px hen box, and a blocked grounded mob *jumps* — a hen pogoing under a slab forever,
  with no error
- **The shelf ends up solid ground with a vertical face, which walks partway back toward the mound the user
  rejected.** That tension is a screen judgment, flagged in the design doc's Acceptance 3, not settled here
- **The shelf is across the corridor, not beside it — so continuing east requires the hop.** Everything above
  argues the 64px face as *how you get **onto*** a shelf; this is the same fact from the other side, and it
  was not written down until the map was built. A shelf is 11 tiles of solid ground standing on the flat the
  player walks along, spanning the full corridor height at those columns, so **the run to the stairs is three
  hops, not a walk.** There is no way around one.
  ⇒ **It also invalidates the number the whole compression was justified by.** The design doc's "17.5s to the
  bull" is distance ÷ `MOVE_SPEED_PX` and counts no hops; its Acceptance 1 says **driven, not computed**, and
  it has not been driven. **Nobody chose three forced hops — it fell out of this decision**, and whether that
  reads as a vertical axis or as an obstacle course is the first thing to look at on screen
- Mob jump apex is 61px against the 64px rise. **That 3px margin is already asserted** for the 2-tile pit and
  covers the shelf — it must not be restated
- The shelf must carry the hen's own 240px stopping distance west of it, or a stirred hen walks off its own shelf

## Conditions to reopen

**If a 2-tile block reads on screen as a lump of terrain rather than a platform.** The fork then is a floating
shelf plus the `ty`-hint work this decision deleted — **not to be taken without the user.**
