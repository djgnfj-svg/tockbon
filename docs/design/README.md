# docs/design index — what is designed, and what actually runs

This folder holds **concepts**. Unlike `docs/plans/`, **nothing moves between folders** — a concept stays alive.
But **every doc carries "how much of this is built" in its header.**

**Why carry status**: without it, **being written reads as being present.**
The GDD lists seventeen glyphs; two of them run. If that gap is recorded nowhere,
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

| Concept | Implemented | Accepted |
|---|---|---|
| [Cell game](cell-game.md) — **the current game.** Split, harvest, buy animal parts, climb the food chain | partial — swarm · commands · rendezvous · carrying · level-up pick · ecosystem run. Parts, species, bosses, tiers do not | **the core loop passed**; everything unbuilt is unseen |
| [Circle · rune · glyph](circle-rune-glyph.md) — the three axes, cut along time | none | the split itself |

**Recovered from `v1-sim`, not written for the current game.** Its axes survive the genre change; its
numbers and timings do not. Read the warning box in its header before trusting a line of it.

The summon/build/fit defense structure that briefly lived here was **shelved whole** on 2026-08-12 and is
preserved in [Core defense is off](../decisions/defense-shelved.md).

**A concept never changes folder, so this folder only grows.** `CLAUDE.md`: when a feature comes up in
conversation, it gets a doc here and a row in this table, headed by `Implemented` and `Accepted` on separate
lines — **without both, "written down" reads as "exists".**
