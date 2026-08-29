Type: task
Status: open

# The boat lands beasts on the coast — **the fourth slice**

## What "done" looks like

**A boat carrying wolves is visible on the sea, sails toward the island, reaches the shore and puts
its wolves on land.** The player never places one.

## Where this came from

**2026-08-30**, fourth of the five cuts. **티켓 10 is the same work and is superseded by this file** —
10 was written while boats were still the player's, and its own header records the reversal.

> ***"Boats will exist later, but building them then is what is right."*** (the user, 2026-08-29)

## ⚠⚠ Build it from the tombstones, not from the deleted code

**The boats were deleted 2026-08-29 because they were the player placing them.** `Grid`'s water half,
`Battle`'s four boat phases, and the view's hull and route line all went. **What survived is measured
and is the only design document:**

- **Reachable coast is 8-directional, not 4.** The user: there are places you cannot land, not places
  you can. **Measured: 82 orthogonal coast 조각, 84 with diagonals** — those two are the corner
  beaches, and "anywhere" meant them.
- **The water grid is built ONCE when the board loads and only read afterwards.** Rebuilding on every
  query walks 1536 조각 x three harbours in one frame.
- **Ties go to the lower 조각 index.** ⚠⚠ **Invert it and every landing point on every island moves.**
  **This is not a detail, it is the whole of determinism** — and the multiplayer decision the user
  took on 2026-08-30 rests on it.
- **A body on a boat can be hit and cannot hit back.** A voyage nobody can shoot at is a voyage with
  no tension. ⚠ **`SoldierState.TRANSIT` was deleted for exactly this** — an enum member no code path
  can enter is a slot a future writer fills by accident. **Rebuild the state only when it is entered.**
- **A body on a boat still counts as "still in the fight".** Without it, the last voyage of an island
  whose landed bodies are all dead is thrown away one sub-step early.
- **A boat starts at a distance from the coast.** The user: do not place the boat on the shoreline,
  give it some distance — the boat travelling is what matters. **A band hugging the shore erases the
  voyage, which is the part worth watching.**

## ⚠ The phase order is a contract

**Boats before landings** means a boat that reaches the shore this sub-step unloads this sub-step
instead of next. **`Battle.step`'s header states it** and the fight slices already depend on it.

## ⚠ What already stands here

| What | Where |
|---|---|
| **The coast, block by block** | `Islands.coast`, and the Blender bake that exports it |
| **The sea on screen** | the chosen shoreline — two white lines, flat water |
| **Enemy columns and the walk** | 티켓 41 |
| **Damage, death and reach** | 티켓 42 · 43 |

## What this slice does NOT do

- **No verdict, no wave table, no clock** — 티켓 45 and week 9.
- **No boat the player builds or sails.** That is the wooden boat of week 10.
- **The shoreline does not follow land added in play** — 티켓 16, and no land is added this week.

## Acceptance

1. **A net loads the board, asks for the landing points, and gets 84 — the diagonal beaches included.**
2. **The water grid is built once**; a second query allocates nothing.
3. **Two runs from identical state land in identical 조각, in identical order.**
4. **A boat is hit while sailing, loses a body, and lands the rest.**
5. **An island whose landed bodies are all dead does not end while a boat is still sailing.**
6. **The boat is drawn on the water at a distance from the coast**, and the voyage is visible for long
   enough to watch. ⚠ **The user judges this one by eye** — the number is not the acceptance.
7. **Every check inverted and seen to bite**, and the net count does not go down.

## ⚠ Extensibility — what this slice must leave open

- **A boat carries a list of table rows, not wolves.** The golem of week 8 and the boss of week 9 ride
  the same hull.
- **The landing point search takes the coast as data**, so the island growing by four 조각 in week 8
  changes nothing here.
