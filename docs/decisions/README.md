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
| [No multiplayer before launch](no-multiplayer-before-launch.md) | valid — ⚠ **written for the December build, and December is now August** | Lockstep determinism · host-authoritative co-op at launch |
| [Top-down, not side-view floors](top-down-not-side-view-floors.md) | valid — ⚠ **only "top-down" survives**; its core and its magic circles are gone | A side-view floor-section tower · survivors-like with manual aim · the spellblade with a weapon roster |
| [No leaving the core to fight](no-leaving-the-core-to-fight.md) | **reversed** by [Core defense is off](defense-shelved.md) — the player's hands do the killing now | Player melee combat · "where should I be standing" as the core question |
| [The circle modifies the tower, it doesn't fire](circle-modifies-the-tower-not-fires.md) | valid | The circle as the turret · planted vs carried · placement as the core decision |
| [Not everything is a magic circle](one-noun-for-everything.md) | valid | One noun for the whole game · turrets and buildings as circles · soldier population simulation · an NPC (deferred) |
| [Core defense is off](defense-shelved.md) | valid | **The whole defense game** — soldiers · towers · workers · fitted circles · reward-marked wave forks. Shelved intact, not disproved |
| [The magic circle is dropped](magic-circle-dropped.md) | valid | **The magic circle itself** — as identity, as a survivors-like, as anything. The designer could not picture it |
| [The swarm takes commands, not selection](swarm-obeys-commands-not-selection.md) | valid — its "no clone cap" claim is false | Individual RTS control · control groups · a density slider alone · orderless boids |
| [The swarm is a mixture](cells-differ-individually.md) | valid | Host-only evolution · one uniform swarm trait · host as a non-fighting queen |
| [A part is the skill](parts-are-the-skills.md) | valid — written at eight slots, now eleven | A separate ability roster · species-fixed skills · everything usable at once |
| [Parts appear by chance](parts-drop-by-chance.md) | valid — two locks, not three | Deterministic purchase · pure per-kill drops · price as the only gate |
| [Meta unlocks, never stat boosts](meta-unlocks-not-stat-boosts.md) | valid | Permanent rate upgrades · a research tree · no meta layer |
| [The run climbs a food chain](food-chain-not-a-timer.md) | **partly reversed** by the habitat ladder | Survival timer · region conquest · wave defense · purpose-built monsters |
| [A stage is a habitat you clear by swallowing its boss](ladder-of-habitats-not-tiers.md) | valid — its one-board-per-habitat premise is dead | Five-minute boss cadence · tiers · insects as the opener · human civilisation at the top · ordinary beasts · one continuous map |
| [A level-up card has no price](card-price-removed.md) | valid | Price paid from the species balance · a shared currency · a gate-free card |
| [Disposition and force are two axes](force-and-disposition-are-separate.md) | valid | The prototype's flee-when-outgrown rule · headcount as the comparison · three force-derived bands · colour-coded disposition · force in a UI panel |
| [One level gauge, two numbers per species](one-level-gauge-two-species-numbers.md) | **twice reversed in part** — the +1 clone and the spendable balance both died | One combined level · species XP alone · per-species level-ups · no levels at all · biomass · one number doing both jobs |
| [One open field with biomes](open-field-with-biomes.md) | valid | Rooms and corridors · a flat field with no biomes |
| [Clones are stupid by default](clones-are-stupid-by-default.md) | valid | Self-preserving clones · clones fleeing home · AI as a permanent upgrade |
| [The swarm grows by a key, not by levelling](swarm-grows-by-a-key-not-a-level.md) | valid | +1 clone per level-up · doubling on level-up · a one-way split · contact-automatic absorption · one clone per press · `G` · absorb as a swarm command · a force refund |
| [Ten slots, and no internal slot duplicates another](ten-slots-no-duplicates.md) | **partly reversed** by the lung | Eight slots · twelve slots · nine without a torso · `back` widened to mean the torso · folding hide into the torso · brain · heart |
| [Breath gets its own slot — eleven, not ten](lung-gets-its-own-slot.md) | valid | Folding breath into `gut` · two horse parts instead of three · breath as a property of the legs part · cutting `hide` to stay at ten |
| [`1` calls the swarm to the host](rally-is-to-the-host.md) | valid | The placed rendezvous the prototype shipped · one key with a modifier · keeping both the placed rendezvous and `3` |
| [A kill leaves a corpse, and eating it takes time](eating-a-kill-takes-time.md) | valid | Contact-automatic eating · an animation over an instant grant · slow ground food · a press-to-eat key |
| [All three keys are empty squares](every-key-is-a-square.md) | valid | A permanent basic attack on left click · the slot deciding the key · a separate skill list · drag-to-bind |
| [The August build is two species](august-scope-two-species.md) | **partly reversed** by [the crow gives three parts](the-crow-gives-three-parts.md) — the species survive, the part distribution does not | Six species giving parts · ~~the crow's wings~~ · starting with the lion · one species and the boss |
| [The run opens alone](the-run-opens-alone.md) | valid — **reverses `START_CLONES = 6` by changed premise** | Six starting clones · giving them a starting force · shrinking the field · a fixed camera zoom |
| [Nothing gates the boss](the-boss-is-not-gated.md) | valid | A force threshold · flat 1-HP contact · gating by level or swarm size · spawning the boss late |
| [Host parts come from cards only](host-parts-come-from-cards-only.md) | valid | The host rolling parts off corpses · cards for clones · corpses paying nothing |
| [The body is an outline drawn by code](the-body-is-a-line-drawn-by-code.md) | valid | Two eyes · no dot · a filled body · body sprites · generating whole creatures · every part as a sprite · parts keeping the prey's colours |
| [The host starts at force 10](force-starts-at-ten.md) | valid — **partly reverses the opening of `the-run-opens-alone`** | Force 1 with a faster first level · force 1 with a tutorial line · force 2 · leaving monsters at the old scale |
| [Size belongs to the species](size-belongs-to-the-species.md) | valid | One radius formula for everyone · the same formula with a smaller coefficient · a square-root curve · hand-written sizes with no force term |
| [The horse is herded, not out-run](the-horse-is-herded-not-outrun.md) | valid — **reverses "catchable by a swarm"** | Lowering the horse's speed · raising the clones' · fleeing only from the host · a fourth encircle key · terrain doing all the walling |
| [The crow stands and fights back](the-crow-stands-and-fights-back.md) | valid | A crow that is simply harvested · a fast scattering crow · one aggressive from the start |
| [Clones attack on contact](clones-attack-on-contact.md) | valid — narrows `clones-are-stupid-by-default` | Attacking only what `3` was pointed at · clones that never attack |
| [The boss cannot be out-run](the-boss-cannot-be-outrun.md) | valid — ⚠ **half of it is deliberately undecided** | Indefinite escape · escape at the cost of hunting time · a boss that grows while avoided · timed or cleared-triggered spawning · an arena that opens · carrying on in a clone · leaving the swarm scattered |
| [The hit shape comes from the part](hit-shape-comes-from-the-part.md) | valid | One hit rule for the key · `BITE` hitting everything touching · `BITE` auto-targeting |
| [Everything goes in for August](everything-goes-in-for-august.md) | valid — **a date decision, not a design one** | Dropping water · dropping parts and cards · water that only slows · water clones cannot cross |
| [Force is stored, not derived](force-is-stored-not-derived.md) | valid | Recomputing from level and parts · a stored base plus a derived bonus · recomputing for the host only |
| [The level counts what came home](level-counts-what-came-home.md) | valid | Levelling from `eaten` · two gauges · reporting `banked` at the ending |
| [A sustained active is held, not fired](the-sustain-is-held-not-fired.md) | valid — **found by building plan 3**, which named the column and gave it no input | Firing on the just-pressed edge · a re-triggered burst · stacking two held sustains · regenerating breath while the key is down |
| [물기 and 짧은 숨 are given, never offered](the-given-actives-are-not-offered.md) | valid — same build | Both in the card pool · a second starter list · always rolling three |
| [A clone has hit points](the-clone-has-hp.md) | valid — **reverses plan 4's own "one touch kills a clone"** | One-touch death · recomputing both halves to full at the split · deriving hp from force · a second host health number on the swarm |
| [The crow gives three parts and the horse gives one](the-crow-gives-three-parts.md) | valid — **partly reverses [the August scope](august-scope-two-species.md)** | A multi-slot part · deleting 말 갈기 and 말 폐활량 · one crow part · lowering `HORSE_TRAIT_COUNT` to keep the trait reachable |
| [The boss's speed is left for the first play](the-boss-speed-is-deferred.md) | valid — ⚠ **a DEFERRAL, not a chosen number.** The arena may never close on its own | Raising it above the host now · gating the ending on a timer or a kill count · cutting the arena until the speed is settled |

**The old game's decisions went with it** and are at the tag `v1-sim`. They are not recovered here because
every one of them answered "why not do X in *that* game" — the question does not transfer.
