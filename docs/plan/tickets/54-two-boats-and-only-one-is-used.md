Type: grilling
Status: open

# 배가 두 척인데 한 척만 쓴다

## What exists

| | Size | Carries | In the game |
|---|---|---|---|
| `boat.glb` | 5.2 x 1.9 조각 | **eight**, four benches of two | ✅ every beast boat |
| `boat_small.glb` | **3.0 x 1.5 조각** | **four**, two benches of two | ⛔ **nothing reads it** |

**Both were baked 2026-08-30 and both have build scripts.** They share six colours deliberately so the two
read as one fleet. ⚠ **The small one is one merged mesh against the big one's twelve nodes**, so code that
walks children will trip on it.

## The user asked for it in passing, and no reason was settled

*"While you're at it, make a smaller boat too — one that only carries about four."* **That is all there is.**

## What has to be answered

- **What is it FOR?** A weaker early wave · a scout landing two beasts · the player's own boat in week 10 ·
  a boss escort. **Nothing in the game currently needs a second boat.**
- **If it is a beast boat, what decides which kind comes?** Time, wave number, random, the island.
  ⚠ 「일정하게. 랜덤은 나중」 was settled for the INTERVAL on 2026-08-30; a boat KIND is a new axis.
- **Does anything change but the count?** Faster because lighter, or the same 1.2 조각/s.

## ⚠⚠ Do not build a boat-kind field before this is answered

**A per-boat-kind branch was deliberately NOT built into the wake on 2026-08-30** — the user deferred
their own boat's different wake and the builder confirmed no such structure exists — **and the same
discipline holds here: no structure for a distinction nobody has made yet.**
`Rules.BOAT_CAPACITY` is one number today; two kinds make it a table row.
