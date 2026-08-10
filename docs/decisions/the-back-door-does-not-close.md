# The bull's entrance has no door closing behind you

**Status**: valid

## What was decided

The bull arrives as **you reach the wood wall, turn around, and it is behind you** — with **no door, gate or
wall closing off the way you came.** The four things the user asked for that night were the bar, the name,
the roar and the camera; **the door was the fourth thing dropped**, after being told it was by far the most
expensive of them.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **A door that closes behind you when the fight starts** — the user's own first phrasing | **It is the only one of the four that has to write terrain.** The other three are a `Control`, a string and two float lerps on a camera. Filling cells means a new command path, a shape, an animation for the fill, and every consequence a solid wall has for the bull's own charge (`carve_r`'s confinement arithmetic is measured against room ①'s *current* boundary — 196 charges, 29 cells removed) |
| Reusing the gate's own terrain beat (`stage_gate.wall_cells()` + `cmd_fill`) | It is the right precedent and it is still not cheap: that one **removes** a wall on a boss death, once, on a fixed rectangle. Closing one behind a moving player is a different rectangle each run, and it is a wall the player can then **burn or blast** — which is this game's whole verb, so "the arena door" would be a door with a hole in it within seconds |
| Keeping the door and cutting the camera zoom instead | The user called the camera move "좀 중요하다" and said nothing of the kind about the door |
| Building the door later, in this same doc | A doc that carries a stage nobody has agreed to build is how a `TBD` reads as a plan. If it comes back it is its own feature |

## What's tied to it

- **The entrance still works without it.** "You reach the wall, you turn, it is behind you" is the picture,
  and the door was never what produced it — the bull materialising *west* of the player is
- **The player can walk away from the fight**, back west along the whole warm-up stretch. The bull follows
  (`Pattern.IDLE` walks toward the player), so the fight travels rather than being escaped — but **nobody has
  seen what that looks like**, and it is the thing this decision spends
- **Room ①'s boundary stays exactly as measured.** `MOVE_CHARGE.carve_r` = 3 gives a 7-cell hole against a
  14-row body, and that non-accumulation was measured on **this** boundary. A new wall re-opens it

## Conditions to reopen

If the fight travelling west turns out to read as "the boss chased me out of its room" rather than as a
fight. Then the cheapest version is the gate's own shape — **one fixed rectangle, filled once** — not a door
that tracks the player.
