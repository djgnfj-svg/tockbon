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

| Decision | Status | Rejected |
|---|---|---|
| [No pixel simulation](no-pixel-simulation.md) | valid | Keeping water/fire cells · keeping only fire · keeping the grid for destructible terrain |
| [No multiplayer before launch](no-multiplayer-before-launch.md) | valid | Lockstep determinism · host-authoritative co-op at launch |
| [Top-down, not side-view floors](top-down-not-side-view-floors.md) | valid | A side-view floor-section tower · survivors-like with manual aim · the spellblade with a weapon roster |

**The old game's decisions went with it** and are at the tag `v1-sim`. They are not recovered here because
every one of them answered "why not do X in *that* game" — the question does not transfer.
