# The map offers one node per floor — not two columns you take one from each of

**Status**: valid (user, 2026-08-19)

## What was decided

***"층마다 둘 중 하나"*** — at each floor two nodes are on offer and **one** of them is taken.
Slay-the-Spire's shape. The five floors, seven nodes and four routes already written in
the title and the map *(지운 문서)* are the correct table, and **step 5's grids can be
authored against them.**

## What wasn't chosen

| Rejected | Why |
|---|---|
| **② two columns come up at once and you take one from each** | The user's own earlier sentence — ***"두 줄로 떠서 양쪽에서 하나씩 선택하는"*** (2026-08-18) — **plainly reads as ②**, and the design doc recorded on the record that the evidence was one-sided against the shape it was written for. Asked directly on 2026-08-19, the user answered ①. **The plain reading of a sentence lost to the person who wrote it** |
| **Deciding it by inference from 「슬더슬식」** | One word from one turn was the *only* thing pointing at ①, and a whole round shipped on it silently. ⇒ The word was right and **the method was still wrong** — see `idea-inbox` row 14 |

## What's tied to it

- `Rules.MAP_NODES` / `MAP_EDGES` — under ② both are re-derived, and so is the coordinate table
- **Step 5's three new grids.** Six island-opening nodes need six grids; under ② the node count itself moves,
  which is why the design forbade authoring grids before this answer
- The HP schedule, and with it the chest's value — a route's fight count changes under ②

⚠ **What this decision does NOT settle**: what the chest pays. The user said **미정** in the same breath
(`idea-inbox` row 20), against a **✅ Decided** heading in the design doc quoting them saying artifacts.
**Two of the user's own quotes disagree and neither was overwritten.**
