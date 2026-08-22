Type: grilling
Status: open

# 섬 하나가 무엇을 주나

## Question

**What does winning one island pay, and does every island pay the same thing?**

## Why it is open: four statements in the record disagree

| Where | What it says |
|---|---|
| **The GDD** | 보상 축이 셋이고 **섬 하나는 하나만 준다** — 수 · 특산물 · 아티팩트. This is what makes a map fork ask 「무엇이 아쉬운가」 |
| **Row 59** (2026-08-20) | ***"클리어했을떄 3택 보상"*** — every clear pays a pick. **This hands the choice to the node instead of to the fork** |
| **Row 60** (2026-08-20) | ***"6개중 2택"*** — ✅ **the pick width is settled by the user at 6→2.** Not open |
| **Row 72** (2026-08-20) | ***"일단 전부 다 monster 노드로 만들면 될듯"*** — ✅ every node is a fight node, the chest is gone |

## What the tree actually does today

Read out of `Rules`, not out of a doc:

- **Seven nodes over five floors**, and a route walks **five of them** — floor 1, one of floor 2, one of
  floor 3, floor 4, then the boss
- A node pays `COUNT` (applied on the win, nothing to choose) or `BEAK` (opens a pick). **The reward belongs
  to the node, not to the kind** — that is what lets a fork put 「세포냐 부리냐」 side by side
- **Every non-boss win pays six cards and takes two.** The boss pays none
- ⇒ **four card-paying wins per run**

## What is actually open

1. Does a node pay **one axis** (GDD) or **a pick at every clear** (row 59)? Both cannot be true, and the
   code today does both at once — a per-node `COUNT`/`BEAK` axis **and** six cards at every win
2. If every clear pays a pick, **what is left for the fork to ask?** The GDD's reward axis is the only reason
   the map branches at all, and row 72 already thinned the forks to nothing this round
3. `BEAK` predates the card pick and still routes through it. Is it a third thing, or a card?

⚠ **Do not resolve this by inference.** Row 20 (***"상자 보상은 아직 미정이고"***) is still open underneath,
and it contradicts an older quote from the same user. Both are theirs.
