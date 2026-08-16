# docs/decisions — what wasn't chosen, and why

Decisions come out of conversation and only the outcome dissolves into the GDD and design docs.
**The answer to "why didn't we do that?" survives nowhere, so the same deliberation happens again.**

**Record only the rejected side.** The chosen side survives in code and design docs.

**If "what wasn't chosen" is empty, it isn't a decision. Don't file it.** Nor is picking a value ("let's make it 20").

Never moves folders. Don't delete a reversed one — why it reversed is the grounds for the next decision.

## Format

```markdown
# <the decision in one sentence>

**Status**: valid | reversed (by what)

## What was decided
Two or three lines.

## What wasn't chosen
| Rejected | Why |

## What's tied to it
Where it shakes if this reverses.

## Conditions to reopen
"None" if none.
```

## Index

**Three decisions survive. Everything else was deleted on 2026-08-17** — see the note below.

| Decision | Status | Rejected |
|---|---|---|
| [Meta unlocks, never stat boosts](meta-unlocks-not-stat-boosts.md) | ⚠ **REVERSED by the user on 2026-08-16 — unlocks AND stat boosts are both in** | Permanent rate upgrades · a research tree · no meta layer |
| [Dropped from the sky, not landed by boat](dropped-from-the-sky-not-landed-by-boat.md) | ⚠ **REVERSED by the user on 2026-08-17 — the boat is back, and it is a rule, not just a picture** | Beach landing · a boat that limits the drop point · an edge-only insertion |
| [The body is an outline drawn by code](the-body-is-a-line-drawn-by-code.md) | valid — **the only decision here that was never reversed and still binds** | Two eyes · no dot · a filled body · body sprites · generating whole creatures · every part as a sprite · parts keeping the prey’s colours |

⚠ **Two of the three are reversed, and they are kept for exactly that reason.** A reversed decision is not
waste: it records the fork, the ground the first answer stood on, and the argument that knocked it over.
Deleting one means the same options get laid out from scratch months later — which this project has now
lived through twice.

---

## What was deleted, and why it is safe

**Forty-three decision docs were deleted on 2026-08-17.** Every one of them answered *"why not do X"* about a
game that no longer exists — a side-view magic-circle game (tag `v1-sim`) or an open-field cell game with a
host you steer (tag `v2-openfield`). **The question does not transfer**, and a fresh session reading them
mistakes them for constraints on the game being built now.

They are recoverable at those two tags. **Do not recover one.** What they measured, as opposed to what they
decided, is distilled in [what two dead games left behind](../lessons-from-two-dead-games.md).
