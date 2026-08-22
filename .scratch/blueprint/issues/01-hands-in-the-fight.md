Type: grilling
Status: open

# 전투 중에 손이 몇 번 움직이나

## Question

**How many times does the player's hand move during one island, and what makes each of those a decision
rather than a dump?**

## Why this one is first

**Planning principle 1 is 「손이 놀면 안 된다」, and it is the principle this game bends the hardest** — the
user's own 2026-08-18 decision was **plan the landing, press start, watch**. The principle's own file carries
a ⚠⚠ added 2026-08-19 saying the payment for that bend **was deleted and the bend got 19–29× wider**, and it
ends with ***"Re-read this line now."***

The arithmetic on that line: **a node offers at most R landing decisions in total**, which is
**one action every 3.1 to 90 seconds depending on R**, and **R is undecided.**

## What already stands, so it is not re-opened

- **커밋은 전투 전에** is **partially reversed** (2026-08-19): ***「저 배만 좀 참여하는 걸로」*** — the hand
  moves during the fight, **but only on boats.** A landed soldier still cannot be touched
- **배는 무한하다** — the cap is not made out of boats
- **소환 띠 is six tiles off the shore, minimum**, and a boat sails itself to the nearest harbour. The player
  never aims at a harbour — a design that lets them is re-importing a rejected fork
- 내 병사는 탐지 범위가 없다; 적은 있다. ⇒ **어디에 내리느냐가 누구와 붙느냐를 정한다.** The GDD calls this
  *the* decision of the game
- Time limits today are **60 · 60 · 90초**

## What is actually open

1. **R** — how many landings one island offers. It is bounded by the cell pool, and nothing decides the pool
2. Whether R is **spent** (a budget) or **paced** (a cooldown), which is the difference between one decision
   made five times and five decisions
3. Whether the fight being **31 seconds measured** against a stage the user set at **10–15 minutes** is a
   fight problem or a stage problem

⚠ **This ticket does not decide whether the fight is fun** — nothing on this map does. It decides the shape
whose fun a person can then judge.
