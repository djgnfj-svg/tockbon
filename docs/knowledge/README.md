# docs/knowledge — 개발지식, **the things the tools do that nobody tells you**

**What lives here**: a fact about Godot, Blender, or an instrument that **cost this repo a round**, will
still be true next month, and **no other file owns.**

⚠⚠ **Read before writing code against a tool, not after the tool surprises you.** Every page below was
written the second time something bit, and the first time cost a whole round.

## ⚠⚠ What does NOT live here — **this table is the whole discipline**

**The same fact in two files drifts, and the older copy is the one that gets believed.** So before a page
is written here, it is checked against this list.

| The fact is about | It goes | Why not here |
|---|---|---|
| **A check that went green while lying** | `docs/how-nets-lie.md` | That is a casebook of measured false greens, and it is already 587 lines of them |
| **How to drive THIS repo's Blender scripts** | `tools/blender/README.md` | Five traps, each one a round, all specific to those scripts |
| **What a word in this game means** | `CONTEXT.md` | The glossary. The Korean word IS the name |
| **Why a decision came out that way** | `docs/roadmap/log.md` | Every quotation lives there and nowhere else |
| **A search that took real work** | `docs/reference/` | Dated, one question per file, sources linked |
| **What is being built and when** | `docs/roadmap/README.md` | The map |

⚠ **A fact that fits a row above is written there instead**, and a page here that starts to overlap one
is cut down to a pointer.

## The pages

⚠⚠ **None yet. The folder, the bar and the skill stand; what goes in is the user's to design.**

**Three were drafted on 2026-08-31 and pulled the same day** — the model wrote them alone, out of
`log.md` and the net runner's comments. **They are recoverable from commit `f0dd191`** if the shape turns
out to be right.

**What they covered, so the ground is not surveyed twice**

| Draft | What it held |
|---|---|
| **What Godot does quietly** | The runtime error that abandons its function, `push_error` not stopping anything, `.call()` dropping a coroutine, the import cache, `DIFFUSE_LIGHT` already carrying `ALBEDO` |
| **What survives the Blender export** | The non-planar quad that becomes a bright/dark seam, and the flat-shading trick that finds it without a render |
| **Measuring a thing that has size** | A point instrument against a hull 2 조각 wide, and two grids half a 조각 apart |

## The bar a page has to clear

| | |
|---|---|
| **Measured** | ⚠⚠ **A number and how it was taken**, never「it is known that」. **Nothing pretends to work** applies to documents |
| **Durable** | It is still true after this island, this ticket and this week. **A fact about the current board is a fact about the board, not the tool** |
| **Unowned** | Nothing in the table above already holds it |
| **Actionable** | It changes what the next agent writes. **A fact nobody would act on is a fact to delete** |

⚠ **A page found to be wrong is corrected in place and the old claim kept with a line saying it was
measured false.** That is not the `docs/reference/` rule — **research notes are frozen, this folder is
maintained** — and the difference is that an agent reads this folder to decide what to type.

## The shape of a page

**One heading per fact.** Under it: **what happens · how it was measured · what to do instead.**
⚠⚠ **The last one is the reason the page exists** — a symptom with no instruction is a war story.
