# The player's fall gets its own gravity constant — bosses keep the shared one

**Status**: valid

## What was decided

`Character.PLAYER_GRAVITY_PX` (1536) now drives the player's own fall and airtime (0.6s → 0.75s,
"게임이 빨라진 것 같다" — the user, looking at the screen). `Character.GRAVITY_PX` (2400) stays, unchanged,
and every monster — including both bosses — still falls under it.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **Lowering the shared `GRAVITY_PX` itself** | Every boss jump trajectory (`boss_ai.gd`'s `MOVES` table) is tuned against 2400 — the rooster's leap apex, the bull's slam arc. Lowering it stretches every one of those readings and is a boss feel change nobody asked for |
| **Leaving the player on the shared constant, unpatched** | Then "airtime feels floaty" (`design/game-feel.md`) has no lever that does not also retune every boss |

## What's tied to it

- `body.gd`'s static double-check (`JUMP_VY_PX² / (2 × PLAYER_GRAVITY_PX)`) — the one automatic guard
  against tuning only one side of the jump-height pair and silently changing reachable height
- `design/game-feel.md`'s airtime item — the direction taken (floatier, not snappier) is the opposite of
  what that doc originally proposed; see that doc for the current reading
- Any future boss added to `boss_ai.MOVES` is tuned against `GRAVITY_PX` 2400, not `PLAYER_GRAVITY_PX`

## Conditions to reopen

A boss whose jump is meant to feel like the player's own airtime, not the older 2400 curve.
