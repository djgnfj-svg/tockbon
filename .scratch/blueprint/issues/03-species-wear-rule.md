Type: grilling
Status: open
Blocked by: 02

# 「생명체별 부위만 입을 수 있는」은 ⓐ냐 ⓑ냐

## Question

**Row 69, verbatim**: ***"으 그냥 일단 생명체별 부위만 입을 수 있는걸로 세트는 이후에 추가할 수 있게
확장성있게 코드만 짜줘"*** (2026-08-20).

**The first half reads two ways, and the record says explicitly: asked, never assumed.**

- **ⓐ** — a part **carries a species tag**, and that is the whole of what species does this round
- **ⓑ** — **one board is locked to one species**: a mammal board takes only mammal parts

## Why it is not a detail

**ⓑ is a much bigger rule than the set effects it replaces**, and it puts **species back at the centre of the
6→2 pick** — every card would then be read as 「내 판에 낄 수 있나」 before 「좋은가」. ⓐ leaves the pick where
row 60 put it.

**It also changes the arithmetic in ticket 04**: under ⓑ a share of every pick is unwearable, so the board
fills slower by however much the pool is split.

## What already stands

- ✅ **A set is matched BY PART** (row 63). ⚠ **A second axis — 종끼리도 맞추나 — is half-open**: the user
  leaned toward yes twice in one breath and **stopped short**, so it is not decided
- ✅ **Set effects are OUT of this round** (row 69), and the code must leave room for them
- `Rules.Species` exists — MAMMAL · BIRD · FISH — and **nothing reads it.** That is decided, not forgotten
- ✅ **A board cell is bound to one part** (row 66), and **multi-cell occupancy was deferred by the user**
  (row 67), not refuted. ⚠ Row 67 records the consequence out loud: occupancy was the **only** rule making
  placement a decision, so **this round's board asks 「모았나」 and nothing else**

## The shape either answer takes in code

**The same one**: a part carries a species tag and **the wear rule lives in exactly one place**, so ⓐ→ⓑ is
one function. That is already true of the tree, so this ticket costs a decision and not a refactor.
