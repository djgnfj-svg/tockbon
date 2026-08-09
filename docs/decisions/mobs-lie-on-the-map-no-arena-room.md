# Trash mobs lie on the map — there is no arena room and nothing is triggered

**Status**: valid — **one row reversed**: "spread thin and even" → **clumped**
(`../plans/3.done/left-run-clumps-and-platforms.md`). No arena, no triggers, no spawners: all still rejected.

## What was decided

Stage 1's trash mobs are **placed on the ground in advance, spread thin along the whole left run**.
(**The "spread thin" half is reversed — see the table.** Everything else stands.)
The user reached this by talking themselves out of the alternative: they proposed a **combat room before the
midboss** (kill what's in it → level up → the three-pick appears with 확산 or 폭죽), then dropped it in the same
breath — **"보상을 주잖아. 아니네. 주니까 필요 없나? 필요 없기도 하다. 그냥 가자"**.

The reasoning that killed it: **XP already drops from every kill**, so a room adds no reward the open run
doesn't already give. It would only add a wall around something that works without one.

Mobs must also **not overlap each other** (user's opening requirement in the same message).

## What wasn't chosen

| Rejected | Why |
|---|---|
| **A combat room before the midboss** (the user's own proposal) | The reward it was built to deliver — a level-up and a three-pick before the boss — **already arrives from ordinary kills**. The room adds a gate, not a reward |
| **Trigger spawning** (enter a zone, the mobs appear) | "배치되어 있는 게 가장 좋지 않을까" — the user wants them standing there when you arrive. A trigger also erases the quiet approach: you never see them before they see you |
| **Spawners that keep emitting** | Already rejected in `design/monsters.md` — the GDD pins "killing a lot is a gain, walking past is also a gain", and a spawner multiplies if left alone, which punishes walking past |
| ~~**All mobs bunched into a few clumps** (the older plan)~~ **— REVERSED, the clumps come back** | The original reasoning, kept: `plans/3.done/stage1-map-layout.md` wrote "화면당 3~4마리씩 뭉쳐서 몇 군데, 사이는 조용하다", and the user replaced it with **"그냥 바닥에 잔잔하게 깔아줘"** — thinner and more even, not clumped. **Why it reversed: the user played it.** An even sprinkle changes *what stands on* the flat and never the fact that it is flat — **"불의 룬을 얻으러 가는 과정이 재미없다"**. The walk to the midboss is long and boring, so the mobs bunch again: 3 clumps, quiet between them |
| **An arena / lock-in room, re-offered this round** | **Re-rejected.** Open Noita-style terrain instead — nothing is locked, the player can walk back and dig anywhere that is not bedrock. The row above it in this table is the original grounds and they did not change |

## What's tied to it

- **The level-up must arrive before the midboss from open-field kills alone.** With no room guaranteeing a
  fight, the mobs on the left run **are** the pacing knob. Place too few and the player enters ① at level 1
  having never seen the three-pick — which is exactly what the dropped room existed to prevent.
  **The clump reversal moves this invariant from a total to a per-clump one**: a clump is far easier to skip
  than an even spread — skipping one discards a third of the run's XP in a single decision, and nothing forces
  the fight (the player outruns wolf, hen and pig). ⇒ **every clump is worth ≥60 XP on its own**, so one
  engagement levels you. Argued in `../plans/3.done/left-run-clumps-and-platforms.md`, not asserted
- `plans/3.done/stage1-map-layout.md` "왼쪽 구간 — 워밍업 잡몹" — **its clump line is restored, not superseded**
- `design/monsters.md` "Where they are — placed in advance" — this is the map-side half that doc left empty

## Conditions to reopen

**If playing the left run does not reliably produce one level-up before ①.** The room was the guarantee;
without it, either the mob count carries the guarantee or the room comes back.
