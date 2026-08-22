Type: research
Status: open

# 섬의 지형은 어떻게 만들어지나

## Question

**How do shipped games author combat terrain at this scale, and what did this repo's own refusal of a
generator actually object to?**

## Why it blocks the map

Row 73, the user's own closure of the map plan, ends: ***「how is terrain made」 is the question to answer
before terrain is added, and it is now the only thing standing between this game and more islands.***

The state it left behind, unresolved:

- **Seven island-opening nodes share three grids**, so **every route replays terrain it has already solved**
- The design's own probe found **the beak branch losing its second node** because node 2 opens the LION grid.
  **That measurement stands** — it was not disposed of by closing the plan
- The GDD says **섬 넷** — 48×32 셋, 144×32 하나
- **Hand-authoring six 10–15 minute continents is 188,928 characters against 4,608 today**, and **a generator
  was refused once**

## What to find

1. **Named techniques and the studios that ship them** for authoring combat maps in autobattlers, roguelikes
   and node-map runs — hand-authored sets, hand-authored chunks assembled by rule, wholly generated, and what
   each one costs in authoring time
2. **What a run-based game does about replayed terrain**, which is this game's actual defect
3. ⚠ **What the objection to a generator was.** The refusal is recorded but the reason is not, and a research
   answer that recommends a generator without addressing it will be re-refused

⚠ **Named techniques with studios attached, or it is not an answer** — `how-others-do-it` exists because this
repo has measured itself naming studios from memory.

⚠ **Capture the findings as a file and link it from this ticket.** Do not paste findings into the map.
