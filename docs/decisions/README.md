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
| [No leaving the core to fight](no-leaving-the-core-to-fight.md) | valid | Player melee combat · "where should I be standing" as the core question |
| [The circle modifies the tower, it doesn't fire](circle-modifies-the-tower-not-fires.md) | valid | The circle as the turret · planted vs carried · placement as the core decision |
| [Not everything is a magic circle](one-noun-for-everything.md) | valid | One noun for the whole game · turrets and buildings as circles · soldier population simulation · an NPC (deferred) |
| [Core defense is off](defense-shelved.md) | valid | **The whole defense game** — soldiers · towers · workers · fitted circles · reward-marked wave forks. Shelved intact, not disproved |
| [The magic circle is dropped](magic-circle-dropped.md) | valid | **The magic circle itself** — as identity, as a survivors-like, as anything. The designer could not picture it |
| [The swarm takes commands, not selection](swarm-obeys-commands-not-selection.md) | valid | Individual RTS control · control groups · a density slider alone · orderless boids |
| [The swarm is a mixture](cells-differ-individually.md) | valid | Host-only evolution · one uniform swarm trait · host as a non-fighting queen |
| [A part is the skill](parts-are-the-skills.md) | valid | A separate ability roster · species-fixed skills · everything usable at once |
| [Parts appear by chance](parts-drop-by-chance.md) | valid | Deterministic purchase · pure per-kill drops · price as the only gate |
| [Meta unlocks, never stat boosts](meta-unlocks-not-stat-boosts.md) | valid | Permanent rate upgrades · a research tree · no meta layer |
| [The run climbs a food chain](food-chain-not-a-timer.md) | **partly reversed** by the habitat ladder | Survival timer · region conquest · wave defense · purpose-built monsters |
| [A stage is a habitat you clear by swallowing its apex](ladder-of-habitats-not-tiers.md) | valid | Five-minute boss cadence · tiers · insects as the opener · human civilisation at the top · ordinary beasts · one continuous map |
| [A level-up card has no price](card-price-removed.md) | valid | Price paid from the species balance · a shared currency · a gate-free card |
| [Disposition and force are two axes](force-and-disposition-are-separate.md) | valid | The prototype's flee-when-outgrown rule · headcount as the comparison · three force-derived bands · colour-coded disposition · force in a UI panel |
| [One level gauge, two numbers per species](one-level-gauge-two-species-numbers.md) | valid | One combined level · species XP alone · per-species level-ups · no levels at all · biomass · one number doing both jobs |
| [One open field with biomes](open-field-with-biomes.md) | valid | Rooms and corridors · a flat field with no biomes |
| [Clones are stupid by default](clones-are-stupid-by-default.md) | valid | Self-preserving clones · clones fleeing home · AI as a permanent upgrade |
| [The swarm grows by a key, not by levelling](swarm-grows-by-a-key-not-a-level.md) | valid | +1 clone per level-up · doubling on level-up · a one-way split · contact-automatic absorption · one clone per press · `G` · absorb as a swarm command · a force refund |
| [Ten slots, and no internal slot duplicates another](ten-slots-no-duplicates.md) | valid | Eight slots · twelve slots · nine without a torso · `back` widened to mean the torso · folding hide into the torso · brain · lungs · heart |
| [The body is an outline drawn by code](the-body-is-a-line-drawn-by-code.md) | valid | Two eyes · no dot · a filled body · body sprites · generating whole creatures · every part as a sprite · parts keeping the prey's colours |

**The old game's decisions went with it** and are at the tag `v1-sim`. They are not recovered here because
every one of them answered "why not do X in *that* game" — the question does not transfer.
