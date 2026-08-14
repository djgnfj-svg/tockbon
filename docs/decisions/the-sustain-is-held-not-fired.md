# A sustained active is held, not fired

**Status**: valid — settled 2026-08-15 while building plan 3, which named `SUSTAINED` as a column and gave
it no input path.

## What was decided

**`Body.fire(key, aim)` returns `false` for a part with `SUSTAINED == 1`, on purpose.** The sustain runs off
`Body.held` — three entries the shell writes **every frame** from `Input.is_action_pressed`, resolved in
`Body.step(dt)`, which drains breath and writes `Swarm.active_speed_mul`.

**Exactly one sustain runs at a time: the fastest one held.** And `Body.step()` is called by `World.step()`
**before** `swarm.step()`, because the multiplier it writes is what `_move_host()` reads that same frame.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **`fire()` on the just-pressed edge, as the other two shapes use** | 갤럽 lasts one frame and reads as a **dead key**. The edge is the wrong event for "while held" — the plan wrote `SUSTAINED` as a column and the shell only ever polled `just_pressed` |
| **A `SELF_TIME` burst for gallop too, re-triggered by holding** | That is the dash. The whole difference the table exists to carry is "a burst you can spam, or a run you have to breathe for", and re-triggering makes them the same key with two numbers |
| **Summing or multiplying two held sustains** | Two movement parts on two keys is a state the player can reach. Stacking is a rule nobody chose; taking the *first held key* instead makes the answer depend on key order |
| **Regenerating breath while the key is still down** | Measured: `breath` hits 0, one frame of regen lifts it above 0, the next frame the sustain drains it — the host **flutters** between 1.8× and 1.0× forever, averaging well above base. "Held past `breath_max()` drops back to base" is then false for the rest of the hold. Releasing the key is what buys the recovery |

## What's tied to it

- **`Swarm.dash_cd` is deleted.** `Body.bound_cd[key]` is the one cooldown in the game now — plan 2 kept a
  second one and wrote a comment saying the two must never both exist
- **The panel-open input gate zeroes `held`** exactly as it drops the `F` wind-up. A poll left alone keeps
  its last value, so a gallop would latch across a menu
- **The shell's one line writing `held` was unmeasured for a whole round**, because every net supplied
  `held` by hand — `CLAUDE.md`'s "wiring a node by hand hides the line that wires it in the shell",
  applied to a poll. `net_hands` now presses `fire_2` for real with 말 다리 bound
- [Every key is a square](every-key-is-a-square.md) — the sustain is what makes binding 말 다리 over
  `space` a real trade rather than a swap

## Conditions to reopen

A sustained active that is not movement — something the player holds while standing still. `held` carries
that unchanged, but "exactly one at a time" would stop being obviously right.
