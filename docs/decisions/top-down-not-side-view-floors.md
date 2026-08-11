# Top-down with monsters from every direction, not a side-view floor tower

**Status**: valid

## What was decided

**Top-down. A core at the centre, monsters arriving from all sides.** Magic circles are the turrets that
hold them off, and the player also fights directly.

Side view was held as settled for most of the conversation and **was given up at the end**, once it became
clear the novelty it offered came from the floors rather than from the circle.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **Side-view floor-section defense** — a 3-4 storey building in cross-section, monsters entering each floor, the player climbing ladders to plug the breach | Genuinely rarer, and it justified side view. **But the novelty was the floors, not the magic circle** — and a circle's shape wants *angles*, not storeys. Placing one circle per floor is a tower; placing runes around a ring is a magic circle. Also unproven: no reference work confirms the format is fun |
| **Survivors-like with manual aim** | The user does not enjoy aiming at range and said so directly; it was the diagnosis for eight months of the previous game not being fun |
| **Spellblade with a weapon roster** (one-hander, greatsword, dagger, katana) | A weapon list competes with the magic circle for the same job. Four weapons are already four different games, and whatever they carry, the circle stops carrying. **The surviving form of this idea**: one weapon whose character is decided by what is assembled — a "greatsword feel" is an *outcome* of the build, not an item |
| **8-direction sprites** | Assumed necessary for top-down and it is not — Vampire Survivors and Brotato ship two-direction sprites and flip them. **This was the only real cost of top-down and it evaporated when the user pointed it out** |
| **3D** | A first completed project plus a new discipline plus four months. The 2D generation pipeline (`tools/pixel/`) is the one asset that survived the reset and works |

## What's tied to it

- **The circle's shape becomes the game's shape.** Rune sockets sit at angles around a rim, so
  "which direction is strong" is read straight off the assembled circle
- **Ranged monsters stop being flavour.** They are what forces the player off the centre, which is where
  close-quarters combat — the user's stated taste — earns its place structurally instead of being bolted on
- **One map.** The variety budget goes into monsters. This only holds because direction, not geography,
  is the axis of variety

## Conditions to reopen

**If playtesting shows the centre is a boring place to stand.** The side-view floor version's real virtue —
that being *pushed upward* floor by floor is a legible losing state — has no equivalent here yet, and if the
top-down build has no shape to its defeat, that is the branch to look at again.
