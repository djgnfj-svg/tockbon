# The map offers one node per floor — not two columns you take one from each of

**Status**: ⚠⚠ **the frame is dead (2026-08-26)** — **there is no map screen.** The map, node walking, node
rewards, the eight islands and the species cards were all deleted from the code that day. **A game with one
island has no floors to offer nodes on**, so the decision below has nothing left to be true about.
⇒ **What survives is the second row of the rejected table, and it is not about maps at all**: a whole round
once shipped on a single word inferred from one turn, and **the word happened to be right while the method
was still wrong.** That lesson is live, and this repo has repeated the shape since. The map half is kept
because a deleted branch comes back as a fresh argument.

**Status (original)**: valid (user, 2026-08-19)

## What was decided

***"층마다 둘 중 하나"*** — at each floor two nodes are on offer and **one** of them is taken.
Slay-the-Spire's shape. The five floors, seven nodes and four routes already written in
the title and the map *(지운 문서)* are the correct table, and **step 5's grids can be
authored against them.**

## What wasn't chosen

| Rejected | Why |
|---|---|
| **② two columns come up at once and you take one from each** | The user's own earlier sentence — ***"두 줄로 떠서 양쪽에서 하나씩 선택하는"*** (2026-08-18) — **plainly reads as ②**, and the design doc recorded on the record that the evidence was one-sided against the shape it was written for. Asked directly on 2026-08-19, the user answered ①. **The plain reading of a sentence lost to the person who wrote it** |
| **Deciding it by inference from 「슬더슬식」** | One word from one turn was the *only* thing pointing at ①, and a whole round shipped on it silently. ⇒ The word was right and **the method was still wrong**. ⚠ It was logged in `idea-inbox`, **which was deleted on 2026-08-26 by the user** — this row is now the only copy |

## What's tied to it

⚠⚠ **All three are gone.** They are kept as the record of what a map screen cost, not as work to do.

- `Rules.MAP_NODES` / `MAP_EDGES` — under ② both are re-derived, and so is the coordinate table.
  ⚠ **Both constants were deleted; `rules.gd` carries only a note that they were.** Four nets and one probe
  still call them by name and are red for it
- **Step 5's three new grids.** Six island-opening nodes need six grids; under ② the node count itself moves,
  which is why the design forbade authoring grids before this answer. ⚠ **There is one island, and its grid
  comes out of Blender** — one script emits a mesh and a coordinate file, and the game only reads them
- The HP schedule, and with it the chest's value — a route's fight count changes under ②. ⚠ **There are no
  routes.** What paces a run now is a timer that brings a boss

⚠ **What this decision does NOT settle**: what the chest pays. The user said **미정** in the same breath,
against a **✅ Decided** heading in the design doc quoting them saying artifacts.
**Two of the user's own quotes disagree and neither was overwritten.** ⚠ Both quotes lived in `idea-inbox`
and in a design doc, **and both files are gone** — the disagreement survives only as this paragraph, and
**there is no chest to pay anything now.**
