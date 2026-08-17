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

⚠ **The first vertical slice is built and runs** — three islands, one run, end to end, with the twelve
presentation items on top. **Each row below carries its own status**; the GDD stays `Implemented: partial`
because the slice built a straight-line subset of it, not the whole design.

**Korean and English are two files, not one.** A `-ko` file and its English twin hold the same facts and
**must be edited together or they diverge.** Korean is what the user reads; English is what agents read.

| Concept | Implemented | Accepted |
|---|---|---|
| **[The cell army GDD](cell-army-gdd.md)** · [한국어](cell-army-gdd-ko.md) — **the live GDD.** One line: **「먹을 것을 고르러 간다」** (*going out to pick what to eat*). An autobattler on a node map of islands. A squad of square cells lands **by boat, on the coastline**; combat is automatic; **soldiers carry across islands, HP included, and a dead one is dead for good.** Reward axes are three and an island gives one: **count · 특산물 (a part bolted onto one soldier) · artifact (bound to the whole army)**. Real time, 1~5 hotkeys summon by unit type. Loss condition is a **time limit** | **partial** — the straight-line slice runs (3 islands, 2 soldier types, 3 enemies, the beak, boats, permadeath, HP carry). **Not built**: chest/elite islands, artifacts, map branches, meta unlocks, tiers/ramps/flying, fog, a recovery path | **partial** — the user played it 2026-08-17 and the presentation passed; **the game did not**: *"침공하는 느낌이 전혀 없어서"*. 「미정」 15·16·17 are open |
| **[Twelve pieces of combat juice](combat-juice.md)** · [한국어](combat-juice-ko.md) — **the twelve effects the user picked after playing the first slice**, because *"액션을 보는 맛이 있어야 돼"*. Its heart is one rule: **the sim reports only what happened (a one-frame `Battle.events` list of three kinds), and every duration, colour and pixel is the view's.** Carries the full closed hook table (**68 functions, 20 leaves**), the draw-layer order, the shell's `_hold_sec` pseudocode, all **44** new `look.gd` timing and size constants plus **7** colours with their pixel conversions, and a per-item "what must redden when this breaks" table where **every row has a floor as well as a ceiling**. ⚠ **Item 2 is two layers, not one** — the user corrected it after the doc was finished (*"이팩트가 있어야 할 듯"*), so the body's lunge (2①) now carries **a hit spark thrown out of the contact point (2②)** with its own leaf, constants and net rows. ⚠ **All twelve are closed — the user chose to add the lion's wind-up (2026-08-17), knowing it weakens the boss.** ⚠ **Boats, terrain and 3D are out of scope — the user deferred them in the same conversation**, and juice fixes none of that layer. **Its seventeen refutation boxes are the most valuable paragraphs in it** — each one disproves an earlier claim of its own with arithmetic (a quotation that did not exist, "no window stretch" against `project.godot`, a lunge that swallowed bodies, "forty lines" against six, a gait amplitude under its own visibility floor, and **a shard fan that would have been drawn inside the attacker's own body**) | **full** — all twelve plus the lion wind-up; the round is **9 nets / 725 checks** green | **pass (2026-08-17)** — the user played it: *"연출은 좋아."* ⚠ **The presentation passed, the game did not** — see the doc header |
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
