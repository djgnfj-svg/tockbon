# Trash mobs lie on the map — there is no arena room and nothing is triggered

**Status**: valid

## What was decided

Stage 1's trash mobs are **placed on the ground in advance, spread thin along the whole left run**.
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
| **All mobs bunched into a few clumps** (the older plan) | `plans/3.done/stage1-map-layout.md` wrote "화면당 3~4마리씩 뭉쳐서 몇 군데, 사이는 조용하다". The user replaced it with **"그냥 바닥에 잔잔하게 깔아줘"** — thinner and more even, not clumped |

## What's tied to it

- **The level-up must arrive before the midboss from open-field kills alone.** With no room guaranteeing a
  fight, the number of mobs on the left run **is** the pacing knob. Place too few and the player enters ①
  at level 1 having never seen the three-pick — which is exactly what the dropped room existed to prevent
- `plans/3.done/stage1-map-layout.md` "왼쪽 구간 — 워밍업 잡몹" — its clump line is superseded by this
- `design/monsters.md` "Where they are — placed in advance" — this is the map-side half that doc left empty

## Conditions to reopen

**If playing the left run does not reliably produce one level-up before ①.** The room was the guarantee;
without it, either the mob count carries the guarantee or the room comes back.
