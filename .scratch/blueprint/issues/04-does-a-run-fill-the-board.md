Type: grilling
Status: open
Blocked by: 02, 03

# 정비 판이 한 판에 채워지나

## Question

**A run pays eight parts into twelve holes. Is filling two-thirds of one board the intended shape, or is the
run, the pick width, or the board wrong?**

## The arithmetic, measured off the tree today

- A route walks **five nodes**, **four of them pay cards** (the boss pays none) — `Rules.MAP_NODES`
- **6 cards, take 2** — `CARDS_PER_WIN = 6`, `CARD_PICKS = 2`
- ⇒ **8 parts per run**
- **2 summon slots × 6 board cells = 12 holes** — `SUMMON_SLOTS`, `Rules.Part` (머리 가슴 배 팔 손 다리)
- ⇒ **a run fills 8 of 12, and never fills both boards**

⚠ **Row 60's arithmetic is stale and must not be quoted.** It said *"3 fight nodes ⇒ 6 objects, 2 slots × 9
cells = 18 holes, a run fills a third"* — the run has since become **five nodes** and the board **six cells**
(row 68: 3×2 격자 · 부위 여섯). **The gap is 67%, not 33%.**

## Why the answer is not obvious in either direction

- **Filling it is not automatically right.** Row 67 already recorded that with one part per cell, placement
  has one answer, so **a full board asks nothing** — it is a collection, not a build
- **Not filling it is not automatically right either.** A run that ends with a third of the board empty is a
  run whose last reward was 「아직 못 채운 칸」, which is a checklist, not a fork
- ⚠ **Deterministic acquisition converges every run on the same best build** — measured in the second dead
  game. A pool that is smaller than the holes has the opposite problem and the same ending

## What this ticket may not do

**It may not fix the gap by widening the pick.** Row 60 settled 6→2 **by the user**, so the pick width is
theirs to move, not this ticket's. The three levers this ticket may put in front of them are **run length**,
**board size**, and **whether the board spans runs** — and the last one is out of scope on this map.
