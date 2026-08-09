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
| [monsters.md](monsters.md) | **full** | partial pass (2026-08-08) | Farm animals that swallowed runes. **Five kinds** — pig · hen (enlarged to 48x64) · bull · rooster · **wolf** (new). **Every sheet animates** — 10 states, boss patterns among them (`3.done/monster-animation.md`). **Cost re-measured and sublinear in cells** (`tools/stage/profile_monsters.gd`; 20 hens = 32% of the 60Hz frame). **No AI** · the wolf has no lunge in the sim · **nobody has judged the motion** |
| [town.md](town.md) | **partial** | unseen | Where a run closes. **The room, the loop and the art all run** (`3.done/town-room-and-fixtures.md`) — one bedrock room · three fixture sprites · **a door that checks position** (E) · gate → stage 1 · dying → town · the burnt-village backdrop · **the research window** · **원석 from bosses and levels, surviving a reset**. **No points, no unlock, nothing to spend 원석 on** |
| [game-feel.md](game-feel.md) | **partial** | **fail (2026-08-08)** | **A menu of every juice lever, with its cost.** **The user reports moving · the camera · jumping as unpleasant.** **Coyote time and the jump buffer are now in** (unseen); **the camera is still locked to the character** and airtime is still 0.6s. **No sound anywhere** |
| [background.md](background.md) | **partial** | unseen | Two layers per place, tiled and parallaxed. **The art landed and the night sky was reversed** — stage 1 is a daylit farm, the town a burnt village. Not confirmed on screen |
| [underground-depth.md](underground-depth.md) | **none** | unseen | **Behind and below** the terrain. **Measured: the far picture is 92% glued to the window, so blue sky is drawn behind the bedrock floor** and every dug hole shows it. Four options — a depth fill in `sky_background.gd` · a `UV.y` dim in the shader · a Terraria background wall baked from the map · a `DIRT` material |
| [terrain-look.md](terrain-look.md) | **none** | unseen | Stone and wood are one flat color each. **A lit face computed from the neighbours** · a per-cell mottle · a material texture — **all in `cell_grid.gdshader`, nothing in `src/sim/`** |
| [gate-ending.md](gate-ending.md) | **full** | unseen | **The last square of the milestone chain.** The rooster's death drops room ③'s east wall and stands an arch behind it; standing at it ends the run, into **the settlement screen, not a second one**. **The seat is pinned by the camera, not by taste** |
| [glyph-accel-and-home.md](glyph-accel-and-home.md) | **none** | unseen | Two `MODIFY` glyphs — **가속 · 유도**. **Two `.png` exist and no code knows them.** Accelerate touches **drag, not launch speed** (`_bolt_head_keeps_up` has zero headroom **and would stay green while the art skips**); homing needs monster positions, which makes a lockstep trajectory depend on host-authoritative state. **These are the last two family seats — the nibble fills exactly** |
| [attack-prediction.md](attack-prediction.md) | **full** | unseen | The wind-up "!" is retired. **A red, pulsing ground mark shaped to the move** — a lane (charge) · a stream (fire) · a 54px reach band (gore, not the 120px gate) · a landing ring (slam/leap, +ignite ring for the slam). **Tracks the player live during wind-up**, converging on the real answer at the lock instant instead of holding the stale direction |

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
| Bosses · midbosses | **partial** | Stage-1 pair implemented → `docs/plans/3.done/stage1-bosses.md`. **Bull** (charge · stun · fire breath · slam · phases) and **giant rooster** (leap · pounce · land · phases) are both written and verified headless — **not accepted by the user.** Two screen fixes (the slam's fire ring, the phase-2 tell's shape) are unlooked-at, blocked by another session holding the editor bridge. **Acceptance 8b's own promise doesn't hold on this map** — the reward-then-water order is correct, but the water doesn't lift the player; a jump alone already clears the step in 1.6s (that doc's own Risk 13) |
| **More glyphs** | **2/17** | **Only spread and blast are real. The other fifteen are names** (pinned by the user). The three-pick runs on a **dummy glyph (damage up)** → `docs/plans/3.done/levelup-and-three-picks.md`. **Real ones go in before the demo** |
| Lightning | **none** | No rune. **It is water's counterpart** |
| ~~Stage transition~~ | **full** | Doc exists → [gate-ending.md](gate-ending.md). **The ending and the stage door are one object** — stage 2 does not exist, so today it ends the run. ~~Still zero code~~ **built, screen unverified** (`plans/3.done/gate-ending-to-game.md`); the shop at that moment is still undesigned |
| Gear | **none** | **Cut to three slots** (staff · robe · boots). ~~Bag · potions · ink~~ **removed** — collided with the no-inventory rule. Direction only; the user hasn't picked |
| ~~Home · meta (unlocks)~~ | **partial** | Doc exists → [town.md](town.md). **The room is built and the run loop closes** → `docs/plans/3.done/town-room-and-fixtures.md`. **Unlocks themselves are still zero code** — the research bench lists the rune pool and spends nothing |
| Multiplayer | **none** | The GDD has a policy. Not one line of code |
| UI | **none** | The HUD is a debug label |
| **Tutorial** | **none** | **Newly named by the user** — **it teaches how to use the magic circle**, and the town deliberately teaches nothing (`town.md`, "the starting kit is handed over here"). The GDD already leans on it twice ("the rule is taught in onboarding" — layer order, and the assembly window). **No doc, no owner** |
