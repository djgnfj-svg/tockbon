# The 응축 pillar leaves no material behind

**Status**: valid

## What was decided

The condense glyph's pillar **goes up and ends**. It does not leave a pool of water, a standing flame, or any
other cell state that outlives the effect. The user's own words: *"그냥 착탄 후 기둥 푱 나오고 끊어도 돼."*

**Scope, because the sentence is easy to over-read**: this is about **the column**. Every impact already carves
(`spell_sim._impact` step (1), rune-blind) and every impact already leaves its rune's trace (step (2)). A
fire-rune condense will still leave the *rune's* burning patch at its foot. That patch is not the pillar's.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **The pillar leaves water where it stood** | It is the stronger design — it hooks into the GDD's natural law, and "condense water, then shock it" is where the thesis lives. **It is also the most expensive cell state the sim has.** Water does not settle; it flows, and a chunk with moving water **never sleeps**, which is the prerequisite chunk sleep exists to protect (`sim_tuning.CHUNK_CELLS`: one full grid sweep is 62,676 µs against a 20 Hz budget of 50,000). `MAX_CHUNKS_PER_TICK` was already cut 512 → 100 because verify-look measured a cliff — **85 chunks 229 FPS, 126 chunks 6 FPS.** A glyph that pours a new column of water on every impact aims straight at that cliff, from the one place the player triggers over and over |
| **The pillar leaves standing fire** | Cheaper than water, and it collides with the rune instead: the fire rune's trace already ignites at the impact point, so a glyph that also leaves fire makes the rune and the glyph the same axis. `circle-rune-glyph.md`'s standing rule — a glyph adds on top, it does not become the rune |
| **The pillar leaves its own material** (steam, ash, a new cell kind) | A new material is a `cell_materials` row, a behaviour, a fuel value, a colour and a shader branch. Not the cost of a glyph |

## What's tied to it

- **`glyph-condense.md`** — its §2.4 and the cost model in §6. If residue comes back, the cell-count table
  stops being the cost. (**§11 already overturned §6.3**: the pillar writes no cells at all, so the cost
  today is a scan, not a table of writes)
- **`design/water.md` and `water-and-chunk-sleep.md`** — the settling and chunk-sleep measurements this
  rejection rests on. **If those numbers move, this decision is what should be re-read**
- **`sim_tuning.MAX_CHUNKS_PER_TICK`** — the 100 that made the cliff a tuning question rather than a crash
- **The 물 rune's own status is unsettled** (the plan doc's §2.3): the brief said the water rune does not
  exist, and the code, the assets and the research bench all say it does. **This decision does not depend on
  that answer** — it refuses residue for every rune

## Conditions to reopen

- **Water gets cheap enough that a new column per impact is affordable** — that is a chunk-sleep measurement,
  not an opinion. The number to beat is the cliff in `MAX_CHUNKS_PER_TICK`'s comment
- **A lightning rune arrives.** "Wet it, then shock it" is the interaction the water residue would have bought,
  and today there is nothing to shock with (`sim_tuning.ELEM_WATER`: *"there is no lightning rune yet"*)
- **The pillar turns out to read as nothing on screen.** If "it left no mark" makes the glyph feel like it did
  not happen, residue is one of the answers — but so is the fx path, and the fx path is far cheaper
