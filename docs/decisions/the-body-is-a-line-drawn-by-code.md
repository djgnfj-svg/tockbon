# The body is an outline drawn by code, not a sprite

**Status**: valid

## What was decided

**A rounded square drawn as a line, one dot at the centre, empty between them.** Drawn by code, not loaded
from an image, **with images left open as a later swap** (the user's words: build it this way and change it
later if it wants changing). Details in the GDD's *Screen*.

**And a worn part takes the host's colour, not the prey's.** Eating a cheetah's legs does not paste cheetah
onto the body — the cell digested it.

Decided by generating candidates and looking at them: `tools/pixel/out/cell_*` · `gl_*` · `part_*`.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **Two dot eyes** | Made it a face, and a face has a front — which fights a top-down body that parts attach to on all six sides |
| **No dot at all** | Did not read as alive. A plain square |
| **A filled white body** | Generated and shown; the user cut the fill. Outline and dot, nothing between |
| **Sprites for the body** | Squash and stretch are free on numbers and destructive on pixels, and the whole shape is a radius, a thickness and a dot |
| **Generating each species as a whole creature** | Naming an animal overrode the top-down view every time — six species came out in front view (`tools/pixel/out/gl_*`) |
| **Forcing top-down on a whole creature** | The view came back and the animal left: a lion became an orange square, because a mane is surface and surface does not show from above (`gl_lion_td`) |
| **Every part as a generated sprite** | Jaws survive being cut off a body; **a leg does not** — detached it is a brown stick (`part_horse_leg` against `part_jaws`) |
| **Parts keeping the prey's colours** | The user rejected it on sight: what you eat does not arrive looking like what you ate |

## What's tied to it

- ⚠ **The board-per-species rule does not bind this game.** It is the biggest art constraint in this repo —
  parts from different presets can never be made to match — and it is void here because **a worn part has no
  colour of its own.** Two things were resting on it and both are released:
  **the cap of five or six part-giving species per habitat**, and **half the reason external slots were kept
  to six.** Slots stay at six because six things sticking out of one small square is all that reads —
  see [Ten slots](ten-slots-no-duplicates.md)
- **Being empty inside is why an overlapping swarm still reads.** Forty filled bodies blend into one mass;
  forty outlines do not. **The known cost is that the ground shows through**, and the user accepted it on
  the grounds that the cells are small
- **Swapping in images later is only cheap if drawing stays in one place** — `src/look.gd`'s rule

## Conditions to reopen

The bodies getting big enough that seeing the ground through them reads as a mistake rather than a style.
