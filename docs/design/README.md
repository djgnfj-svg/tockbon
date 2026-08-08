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

| Doc | Impl | Accepted | One line |
|---|---|---|---|
| [circle-rune-glyph.md](circle-rune-glyph.md) | **partial** | partial pass (2026-08-08) | What each of the three axes holds. **All five bolt-head-art checks pass** — three by value. **Bare-head grey and trail purple disagree** |
| [circle-art.md](circle-art.md) | **partial** | partial pass (2026-08-05) | How a circle is drawn. Triangle skeleton + **two socket glyph rings** (**provisional — no user judgment**). **Band 48 collides with "the meaning is readable"** |
| [water.md](water.md) | **full** | partial pass (2026-08-08) | Water is an **amount** per cell. Wet is a small amount. **Acceptance 7's cliff is gone** (cap 100). **Reads as "fire burns underwater"** · **falling has no acceleration — the user called it cheap** (constant 7.5 tiles/s) |
| [terrain-baking.md](terrain-baking.md) | **full** | pass (2026-08-06) | Drawn as an image, baked as text. The map is fixed |
| [monsters.md](monsters.md) | **full** | partial pass (2026-08-08) | Farm animals that swallowed runes. Two trash mobs (pig · chicken) · brainless movement · 20 at once. **No AI** · outline unconfirmed |
| [town.md](town.md) | **none** | unseen | Where a run closes. **One walkable room** · research bench · assembly bench · departure gate · all bedrock. **The only place a widened pool is visible** |
| [game-feel.md](game-feel.md) | **partial** | **fail (2026-08-08)** | **A menu of every juice lever, with its cost.** **The user reports moving · the camera · jumping as unpleasant.** **Coyote time and the jump buffer are now in** (unseen); **the camera is still locked to the character** and airtime is still 0.6s. **No sound anywhere** |
| [background.md](background.md) | **partial** | unseen | The layer stands up — empty cells go transparent and `SkyBackground` stands behind. Currently **night sky + stars**, **no art, no parallax**. Not confirmed on screen |

## Features with no doc yet

**Being listed here means there is no design.** Decided only in conversation, or not decided at all —
overlaps GDD's "TBD", but this is the list of **places that need a doc.**

**Order follows GDD "Build order — the current order"** — 1) water + map 2) flying spells 3) monsters 4) three-pick screen.

| Feature | Impl | State |
|---|---|---|
| **Map (stage 1)** | **full** | **Baked and in the game** → `docs/plans/3.done/stage1-map-layout.md`. **400×48 tiles · three zones + a locked fourth.** ① The pit is **a bedrock bowl whose only exit is water** (the ramp was removed). **Acceptance 3·4 unconfirmed on screen** · **no boss in code, so ① and ③ are empty rooms** (`stage1-bosses.md`) |
| Flying spells | **partial** | Bolts fly. Trajectory and shape are the next pass |
| ~~Monsters~~ | — | Doc exists → [monsters.md](monsters.md). Implementation done too |
| **World** | — | Settled — the circle collapsed, beasts swallowed the runes. **`docs/GDD.md` "World" is the source** (no separate doc) |
| Three-pick screen | **done** | → `docs/plans/3.done/levelup-and-three-picks.md`. **All five stages built and accepted by the user.** `P` opens the window, three cards carry name · rarity · `위력 %`, picking one leads into the layer step, and placement goes through `spell_circle.place_glyph()` — **there is no stash.** **Only two glyphs are real, so dummies fill the pool** |
| Level · XP | **done** | Same doc. `src/actor/progress.gd` (xp · level · money · `pending_picks`), `xp`/`money` columns in `monster_defs`, `net_progress.gd`. **Level 3 lands near kill 23 pure-pig and kill 30 mixed** (`60 + 30*level`) — measured, and the mixed population is the one that matters |
| Glyph rarity | **done** | Rarity folded into the glyph id, `power_pct` reaches damage, the palette shows 9 cells in three families. **Three tiers** — common · rare · unique, separated on screen by border color **and by the `위력 %` line, which is what actually makes three same-named cards readable.** Numbers still provisional |
| Drops · economy | **none** | **Stamped settled** — **permanent currency drops from bosses only.** Money is spent **at the shop between stages** (not inside the map) |
| Bosses · midbosses | **none** | Stage-1 pair designed → `docs/plans/1.ready/stage1-bosses.md`. **Bull** (charge + stun · fire breath) · **giant rooster** (leaps, pounces, lands). **Not one line of code** — the monster table has only pig and chicken |
| **More glyphs** | **2/17** | **Only spread and blast are real. The other fifteen are names** (pinned by the user). The three-pick runs on a **dummy glyph (damage up)** → `docs/plans/3.done/levelup-and-three-picks.md`. **Real ones go in before the demo** |
| Lightning | **none** | No rune. **It is water's counterpart** |
| Stage transition | **none** | **Method settled** — **beat the stage-1 boss, a gate appears behind it, you go through.** The shop is at this moment too. Zero code |
| Gear | **none** | **Cut to three slots** (staff · robe · boots). ~~Bag · potions · ink~~ **removed** — collided with the no-inventory rule. Direction only; the user hasn't picked |
| ~~Home · meta (unlocks)~~ | — | Doc exists → [town.md](town.md). Settled as **one walkable room**. Zero code |
| Multiplayer | **none** | The GDD has a policy. Not one line of code |
| UI | **none** | The HUD is a debug label |
| **Tutorial** | **none** | **Newly named by the user** — **it teaches how to use the magic circle**, and the town deliberately teaches nothing (`town.md`, "the starting kit is handed over here"). The GDD already leans on it twice ("the rule is taught in onboarding" — layer order, and the assembly window). **No doc, no owner** |
