# docs/design index — what is designed, and what actually runs

This folder holds **concepts**. Unlike `docs/plans/`, **nothing moves between folders** — a concept stays alive.
But **every doc carries "how much of this is built" in its header.**

**Why carry status**: without it, **being written reads as being present.**
This project has been reset twice, and both times a doc kept describing a game that no longer existed. If that gap is recorded nowhere,
the next person (and the next session) **plans on top of something that doesn't exist.**

## Two separate axes — `Implemented` and `Accepted`

The distinction `CLAUDE.md` pins down holds here too. **Implementation finished ≠ acceptance passed.**

| Axis | Value | Meaning |
|---|---|---|
| **Implemented** | `none` | Doc only. Not one line of code |
| | `partial` | Some of it runs. **Write in the doc what does and doesn't** |
| | `full` | Everything the doc describes runs |
| **Accepted** | `unseen` | The user has never confirmed it on screen |
| | `pass (date)` | The user looked and said yes |
| | `fail (date)` | They looked and it wasn't. **Write the story in the doc** |

**`Implemented: full` + `Accepted: unseen` is a normal combination.** Merge those two into one column and
"it runs but nobody has looked" becomes inexpressible — this repo got burned exactly there.

## Header format

Goes directly under `# Title` and `**One line**:`.

```markdown
**Implemented**: partial — circles 1/3 · runes 2/N · glyphs 2/17
**Accepted**: unseen
```

For `partial`, **always attach what works and what doesn't, briefly.** "Partial" alone carries no information.

---

## Index

⚠ **`src/` is empty.** Every doc here is `Implemented: none` and will stay that way until the first vertical
slice is built. That is the true state, not an oversight.

**Korean and English are two files, not one.** A `-ko` file and its English twin hold the same facts and
**must be edited together or they diverge.** Korean is what the user reads; English is what agents read.

| Concept | Implemented | Accepted |
|---|---|---|
| **[The cell army GDD](cell-army-gdd.md)** · [한국어](cell-army-gdd-ko.md) — **the live GDD.** One line: **「먹을 것을 고르러 간다」** (*going out to pick what to eat*). An autobattler on a node map of islands. A squad of square cells lands **by boat, on the coastline**; combat is automatic; **soldiers carry across islands, HP included, and a dead one is dead for good.** Reward axes are three and an island gives one: **count · 특산물 (a part bolted onto one soldier) · artifact (bound to the whole army)**. Real time, 1~5 hotkeys summon by unit type. Loss condition is a **time limit** | none — not one line of `src/` was written for it | direction and 「정해진 것」 were said by the user; **nothing in 「미정」 is chosen** |
| **[What makes placement a decision](what-makes-placement-a-decision.md)** · [한국어](what-makes-placement-a-decision-ko.md) — nine shipped games and the different rule each used to make **choosing a position** interesting, split by whether they need unit control after commitment. ⚠ **Bad North is not "place and watch"** — corrected from the developer's own words. The sharpest finding: **TFT and Despot's Game share a rule and land in opposite places**, and the only difference is whether units have abilities that respond to distance and direction | none | **nothing chosen** |

---

## What was deleted on 2026-08-17

**Eleven design docs were deleted**, all describing the two games that no longer exist (tags `v1-sim`,
`v2-openfield`): the previous GDD and its review, the stage ladder, the hunting and boss doc, the level curve,
the melee legibility study, the play notes, the presentation audit, the swarm diagnosis, the round-by-round
argument, and the magic-circle glyph doc.

**What they measured survives** in [what two dead games left behind](../lessons-from-two-dead-games.md)
(Korean: `lessons-from-two-dead-games-ko`) — measured numbers and repeating failure shapes, and **nothing in
it is a spec.**

⇒ **Read that file for shapes. Never recover a deleted doc from a tag as a spec.**
