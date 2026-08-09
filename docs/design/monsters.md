# Monsters — beasts that swallowed runes

**One line**: farm animals that swallowed scattered runes walk at you brainlessly and take the world's laws exactly as the player does.

**Implemented**: **full** — stages 0–9 all run (`docs/plans/3.done/monsters-minimum.md`).
Stand · walk · die to bolts/blasts/fire · pig shoves with its body · chicken stops and shoots ·
sprites · health bars · hit flash (shader) · damage numbers (they merge) · fire on the body · corpses · death burst · outline.
**Animation runs** ([../plans/3.done/monster-animation.md](../plans/3.done/monster-animation.md)) — every sheet
in the table below now has a state that draws it, from `fx_tuning.MONSTER_ANIM` (kind → state → sheet).
Ten states, the boss patterns among them; walking's clock is the monster's own `x`, one-shots clamp on their
last cell, and **a corpse is the death sheet played by its own age.**
**They stand on the map now, and they react** — ~~AI is deferred~~ ~~placement belongs to the map side and is
empty~~. **Trash mobs jump when blocked and push each other apart**
([../plans/3.done/monster-ai-jump-and-separation.md](../plans/3.done/monster-ai-jump-and-separation.md)), and
**stage 1's map carries a `(tile x, kind)` table, bosses included, asleep until you are near**
([../plans/3.done/monster-placement-stage1.md](../plans/3.done/monster-placement-stage1.md)) ⇒ **launching the
game and walking right now meets monsters, and reaches the ending, with no debug key.**
**`_next_axis()` is still the one line** — the jump is a reaction to a move's result, not a choice of
direction, so it lives in the movement half. See "AI is deferred; the slot is left open" for why that is not
a violation.

**Not done**: real pathing in that slot · per-species color · **anyone judging whether any of it looks
right** — every `hold` value is a first guess, **and nothing above has been seen on screen.**

| Kind | Sheets in `assets/monster/` |
|---|---|
| **Pig** (44x32) | `walk` 9f · **`idle` 4f · `shove` 8f · `hurt` 4f · `death` 8f** · **`jump` 3f** |
| **Chicken** (24x28) | `walk` 9f · **`idle` 4f · `spit` 8f · `hurt` 4f · `death` 8f** · **`jump` 3f** (on the 48x64 hen) |
| **Wolf** (48x28) | `walk` 8f · `idle` 4f · `lunge` 8f · `hurt` 4f · `death` 8f · **`jump` 3f** |
| Bull (boss) | body · walk · idle · charge · gore · slam · stun · fire · death · roar |
| Rooster (boss) | body · walk · idle · leap · land · death · roar |

**The three `jump` sheets are wired now** —
[../plans/3.done/monster-ai-jump-and-separation.md](../plans/3.done/monster-ai-jump-and-separation.md) built
the `MON_AIRBORNE` state that draws them, and **airborne outranks attacking** (the pigs' and wolves'
"attacking" is a proximity condition, not an event, so ranking it higher would hide the jump entirely).
~~art on disk wired to nothing~~ — **but still art nobody has watched move.** That plan
records what `animate_image` refuses to do (lift feet off the bottom row) and the two-step workaround.

**The bull's sheets were 86x54 against an 88x56 box and were padded, never scaled** —
`tools/pixel/pad_sheet.py`, following this doc's own rule below ("pad, never resample"). `bull_roar.png` was
already the right size and was left alone.

**The user opened this with "the trash mobs are no fun"** — and the cause was in this table: **the bosses had
nine sheets each and the trash mobs had one.** The shove and the spit are exactly the two behaviours this doc
already names ("pig shoves with its body · chicken stops and shoots"); until now neither had a picture.

### Color — **the axis that separates them is brightness, and one pair already collides**

Measured off the actual sprites (the most common opaque pixel), against the terrain they stand on:

| | Color | Note |
|---|---|---|
| Chicken | `#FFCB5B` | **Too saturated** — the only neon thing on screen. Being retoned toward cream |
| Pig | `#884D41` | Red-brown |
| Bull (midboss) | `#625A58` | **Collides with stone `#5C574F`** — 6·3·9 per channel apart. **A grey bull in front of a stone wall is invisible**, and this was found by measuring, not by looking |
| Rooster (boss) | `#010101` | Black. Safe against everything, reads as a hole |
| Dirt · wood | `#6B4524` | The pig is close but brighter |
| Stone | `#5C574F` | See the bull |

**The user set the rule**: "the wolf can't be grey — the midboss is a grey bull". ⇒ **Species are told apart by
brightness first, hue second**, because hue alone dies against a brown-and-grey stage.

⇒ **The wolf is tawny/chestnut** — brighter than the pig and warmer than the dirt.
**The bull's collision is not fixed here** — it is a boss art problem and belongs to `stage1-bosses.md`.

### Size — **the trash mobs are too small** (decided by the user)

Chicken 24x28 and pig 44x32 read as tiny on a 960x540 screen. ⇒ **new trash-mob art targets ~48px**,
and **the bosses go much larger than that** ("I'm going to make the bosses huge").

### Making the art fit the box — **pad, never resample** (the user asked for this explicitly)

Two contracts already bind every sprite, and both are measured by nets:

1. **`net_monster_sprite`: the sheet's pixel size equals the box** (`w_px`/`h_px` in `monster_defs`)
2. **`net_monster._defs_preconditions`: the box is a multiple of `Tuning.CELL_PX` (4)**

A generator returns art trimmed to its own content — 46x25 for the wolf, 86x54 for the bull — which satisfies
neither. **The fix is padding with transparency, not scaling.** The bull set the precedent
(86x54 → 88x56, pixels placed unmoved) and the wolf followed it:

- **Round each side up to the next multiple of 4**
- **Bottom pad is 0** — the feet stay on the last row, or the beast floats above the terrain
- **Left/right pad is symmetric**, so `minx + maxx == w - 1` holds (the flip idiom depends on it)

⇒ **`wolf_body.png` is 48x28** (art 46x25, 1px each side, 3px on top, 0 below).
**Nothing is resampled**, so the pixel grid stays exactly what the generator produced and the sprite survives
whatever integer zoom the view applies later.

⇒ **`hen_body.png` is 48x64**, **`wolf_body.png` is 48x28**. `chicken_body.png` (24x28) is left untouched —
overwriting it would break contract 1 against the 24x28 box in `monster_defs`.

**Do not upscale to reach a target size — regenerate at a larger `--down`.** The first pass of the chosen hen
came out 26x34 because the beast fills only ~54% of the generation canvas. Doubling it to 52x68 would have made
its pixels twice the size of every other mob's, which reads as two art styles on one screen.
**Re-running the same prompt with the same `--seed` and `--down 88` returned the same bird at 48x63** —
same composition, real pixels. **The seed decides composition, so size is free** (`gen.py`'s own note).

**`monster_defs` is not edited here** — adding the wolf's row and enlarging the hen's box is code, and the user
asked for art only this session. **Until those rows exist the wolf and the new hen are art on disk and nothing more.**

### The chicken throws an egg (decided by the user)

**The projectile art is an egg, not a bolt.** The user floated it, doubted it out loud ("is that weird?") and
kept it — **"make it more like a game"**. It is the right call for a reason the doubt missed: this repo already
has **bolts that belong to the player's spells**, and `monsters.md` above spent a section on chicken bolts
having no owner. **An egg is unmistakably the chicken's** — nobody confuses it with their own spell.

**It is a sprite swap, not a system.** `monster_bolts.gd` already flies a straight projectile that hits only
the player; only the picture changes. Candidates: `tools/pixel/out/egg_shot/`.

**Generated with pixellab `animate_image`** (a loose sprite, no registered character), 1 generation each.
**The input was quantized to 12 colors** to survive MCP base64 truncation, so **frame 0 came back with a
different palette than the generated frames and was dropped** — the sheets start at the first generated frame.

**Accepted**: **partial pass (2026-08-08)** — **not seen by the user.** verify-look saw it in the editor.
- Pass: spawns run end to end · they stand exactly on terrain · the three sizes separate ·
  **the flash whitens as a silhouette** · **fire on the body reads as the same material as ground fire** ·
  **a corpse reads as "a dead monster"** · **damage numbers appear and merge on rapid hits** ·
  **chicken bolts separate from spell trails** · **hit feel — three signals in one frame**
- **One partial failure — the outline.** Stand a pig against **black sky** and **its legs and belly melt.**
  **Fixed but nobody has looked** (a bright cream outline was added via shader)
- **Two things for the user to decide** — **palette color count** (monsters 486/237 colors vs player 35) ·
  **the death burst reading as "summon" rather than "hit"**
- **Not looked at**: mixing with water · whether 20 at once are readable · render cost (flames and outlines grew)

**A concept stays alive and never changes folders.** The two header lines are only "how much runs now" —
format per [README.md](README.md).

**Why monsters exist is set by `docs/GDD.md` "World".** Do not duplicate it here.
**The hit-and-die skeleton (health · damage · invulnerability · burn duration · knockdown) is set by
`character-damage-minimum`** — it is already attached to the player, and monsters **reuse the same thing.**

---

## Why these two and not three

This is **#3** in the GDD's "build order". Decided over eight rounds with the user.

**Three were proposed — melee · swarm · flyer.** The flyer was dropped, and the reason matters:

**There is currently no way to hit a flyer.** Only **2/17** glyphs run (spread · blast) and
**homing exists only as an example in the docs** (`circle-rune-glyph.md`, glyph table). ⇒ A flyer could only be
hit by **manual aiming**, so adding it now makes "annoying", not "threatening".
⇒ **It opens when the homing glyph exists.**

**But "just build homing" is not the estimate — it is easy to get wrong here.**
Homing is a **modify** glyph, and `src/sim/glyph_defs.gd` has **only `KIND_SPAWN` and `KIND_TERMINAL`.**
⇒ **Adding homing means standing up a third kind in the pipeline** — a new execution path that edits a bolt
mid-flight without waiting for impact. **A different order of magnitude from adding one glyph.**

**And the user set a principle alongside it** — **roles need not be filled in every stage.**
Stage 2 can have no flyer and a **burrower** (mole-like) instead.
**Do not use "melee · swarm · flyer" as a per-stage checklist.** It is this stage's answer, not a spec.

**No insects** (user decision). Grasshoppers, grubs, bees and flies were all rejected for that.
**This is not a stage-1-only constraint** — it keeps applying when deciding stages 2 and 3.

**Chicks were dropped too** — the image of one **burning to death** was uncomfortable, so it was **promoted to a chicken** (user decision).

---

## Stage 1's trash mobs — **three** (the wolf was added by the user)

**The user set stage 1's full roster in one line: 돼지 · 늑대 · 닭 as trash, 소 as midboss, 거대 수탉 as the
stage boss.** ⇒ **The wolf is stage 1's**, closing the "it is not assigned to a stage" note that
`monster_defs.KIND_WOLF` carries and the open question in
[../plans/3.done/monster-placement-stage1.md](../plans/3.done/monster-placement-stage1.md)'s TBD.

**The two-mob pairing below is still the reasoning that built the stage**, and the wolf does not replace
either half of it — it is a third question (speed) on top of "terrain solves the pig, magic solves the hen".
**Its values are all provisional and nobody has set them** (`monster_defs`' own note): 24 hp, 240px/s —
faster and thinner than the pig, because the art is a lunging predator. **It has no lunge in the sim** —
`wolf_lunge.png` plays on contact, the same door the pig's shove uses.

| Mob | Role | How it comes | **What solves it** |
|---|---|---|---|
| **Pig** | Melee | Straight at the player. **Can't clear a ledge** | **Terrain** — dig a pit or raise a wall and it's trapped |
| **Chicken** | **Ranged** (the user changed this) | Approaches, then **stops and shoots.** Hops a one- or two-cell ledge | **Magic** — it crosses and keeps distance, so you chase and clear it |
| **Wolf** | **Fast melee** (added by the user) | Straight at the player, **1.5× the pig's speed and half its height** | **Reacting in time.** Thin and quick — the pig's answers work, but you get less of a moment to apply them |

**What separates them is not "strength" but "the tool that solves them".**
Pigs only and the game becomes a pit game; chickens only and there is no reason to dig terrain.
⇒ **That the two ask different questions is the whole point of this pairing.** Grow the roster on that criterion.

**The pig was also chosen for being "the same livestock"** — the midboss is a **bull.** Small livestock foreshadows large.

### What came with the chicken going ranged — **bolts have no owner**

**The user moved the chicken from "swarm" to "ranged".** But this repo's sim
**does not know who fired** (`character-damage-minimum`, "friendly fire is half of it").
⇒ **Left alone, a chicken's bolt hits the chicken.**

**⇒ Chicken bolts do not go into the spell sim (`spell_sim`).** They are built separately in `src/actor/` as a
**simple projectile** — flies straight, hits **only the player**, disappears on a solid cell. Does not dig terrain.

**Why split this way**: adding an owner to `spell_sim` **touches the entire glyph pipeline**
(a bolt that spreads into 8 means all 8 must carry the owner), and what is needed now is only
**one flying point that hurts.**
**Add owners the day monsters cast real spells.** Noted here that this workaround becomes debt that day.

### Size — go big

**User decision: "I want them big enough that hitting them feels good. Or that you use terrain to kill them."**

| | Box | Cells covered | Why |
|---|---|---|---|
| Player (baseline) | 20×32px | 40 | `character.gd` |
| **Pig** | **44×32px** | **88** | Wide and heavy. **A big body falling into a pit** is this mob's identity |
| **Chicken** | **24×28px** | 42 | Player-sized. **Ranged means it needs bulk to be a target** |

**Size is not free.** `character.gd` got burned there — "a bigger box makes this file expensive.
`_box_free` · `_grounded` · `_standing_in_fire` sweep the covered cells **in GDScript**, and it went **25 → 81 cells**."
⇒ **One pig is 2.2× the player.** The cost of 20 comes out **higher** than the estimate under "Cost" below.
**Build at this size anyway, then measure and adjust** (user decision: "do it once, and cut the count later if needed").

**⇒ That adjustment is now on the table.** The user says the monsters read too small on screen.
**[../plans/1.ready/monsters-bigger-boxes.md](../plans/1.ready/monsters-bigger-boxes.md)** costs 1.5× —
the four target boxes, the regeneration path (**the seeds and prompts do not survive; four beasts get
re-picked**), the projected 60Hz cost, and the one constant that silently stops working
(`MOVE_SLAM.ignite_spread_cells`). **Nothing is decided yet.**

### Swallowing barely shows — the art-side rule

**"How much it shows varies per mob" is a world fact, and `docs/GDD.md` "World" is the source.**
This doc records only **how that appears on screen.**

**Trash mobs have no runes floating or glowing on their bodies** (the user corrected this).
This doc's draft wrote "grey runes circling the body" and the user **cut it as over-interpretation.** This line stands in its place.

---

## How they find you — brainlessly. And that is temporary

**They walk toward the player. That's all.** No pathfinding.

**Pathfinding is especially expensive in this game.** Most games have fixed terrain and can bake paths;
**here the player punches through terrain every moment** — that hole is new, that wall is new.
Paths would rebuild every tick, and `src/sim/` being **integer-deterministic** means common algorithms don't transfer.

**And pathfinding kills one source of fun** — dig and they walk around, and **trapping stops being a tactic.**

### AI is deferred; the slot is left open

The user said "we'll probably need AI eventually, but leave it for later and change it then".
**That is "skeleton first, flesh later" exactly.**

**But "change it later" only works if the slot is left open now:**

> **Isolate "where does the next step go" into one function.**
> For now it holds the one line "toward the player". When AI arrives, **only that function is swapped** —
> movement, gravity, terrain collision and damage are untouched.

**Without this, adding AI later rewrites the monster code wholesale.**

**The first trash-mob behaviour to arrive does not go in that slot, and that is not a violation. It has
arrived** ([../plans/3.done/monster-ai-jump-and-separation.md](../plans/3.done/monster-ai-jump-and-separation.md)) —
**jump when `move_x` reports blocked** is a *reaction to the result of moving*, so it cannot be computed
before the move; it lives in the movement half of `step()`. `_next_axis()` stays the one line.
**Its real product is a number, and that number now exists**: **1 tile lets a mob out, 2 tiles hold it**,
with **3px of margin** measured. The user set the goal — "가두는 것도 조금 어렵게, 성공이 가능해야지" —
and **whether 3px delivers it is a screen question nobody has answered.** The value lives in the plan.

### Making brainless mobs hard

"Isn't brainless too easy" was the user's worry. **Difficulty usually comes from these four, not from AI:**

- **Count** — 20 arriving at once isn't easy no matter how dumb each is
- **Speed** — a fast pig charge becomes "no time to think"
- **Placement** — narrow corridors · spots they drop in from above · behind you. **Threat without intelligence**
- **No telegraph** — if contact hurts immediately, distance management never stops

⇒ **If it's too easy, tighten these four first.** AI only after that. Reverse the order and
**you build the expensive thing first and check the fun last.**

---

## They take all the world's laws

**Gravity · terrain blocking · burning · blast knockback · water** — the user set it as "everything from natural
phenomena to gravity".

**This is where the GDD thesis ("the world reacts") actually gets paid for.**
Dig under their feet and they fall; set a fire and they die on their own; a blast shoves them.
**The opposite (floating and ignoring terrain) is the closest thing to this repo's signature fake** —
"screen changes, sim doesn't". If digging terrain doesn't stop monsters, digging stops being fun.

### Water gets attached later — and the player at the same time

**The water sim itself is done** ([water.md](water.md), "Implemented: full"). `water-and-chunk-sleep` is still in
`2.active` **not because implementation is ongoing but because acceptance 7 (FPS) is open as a failure and four
user decisions remain.** **This is the live example of "implementation finished ≠ acceptance passed"** (CLAUDE.md).

And **the player doesn't take water either** — the water implementation punted on it.

**User decision: "eventually everything takes everything".** ⇒ When water closes, **attach it to player and monsters together.**
Decide it now and the monster design hangs on water decisions — **that is why this design ran in parallel with water.**

---

## How many — 20 at once

**20 is a value the user set.** Not a value to measure and adjust —
**raising or lowering it means asking the user again.** The budget below was the grounds for that decision, not the decision.

### There are two budgets. Do not mix them

| What | Runs at | Budget per pass |
|---|---|---|
| Grid · water · fire (`src/sim/`) | **20Hz tick** | **50,000μs** |
| **Character movement · landing · fire checks** (`src/actor/character.gd`) | **60Hz frame** | **16,667μs** |

**`character.gd` records this itself** — "this runs at **60Hz**, not per tick".
**Monsters reuse that code, so they are likely on the same side.** Then the divisor is **3× smaller.**

| What | Cost | % of which budget |
|---|---|---|
| One player walking (measured, **at 81 box cells**) | 77–249μs | **0.5–1.5% of the 60Hz budget** |
| **20 monsters** (**estimate** — borrowed from above) | **~5,000μs** | **30% at 60Hz.** 10% at 20Hz |
| Max fire, 16,384 cells (measured) | 16,400μs | 33% of the 20Hz budget |
| Water (measured, `WATER_SUBSTEPS=3`) | worst tick | **273–290%** of the 20Hz budget; 101.5% mean over 400 ticks |

**The problem is not monsters alone but the overlap.** The scene this game deliberately builds is
"the forest burns while water pours and monsters swarm", and **that moment adds all of it up.**

**Water already got burned there** — **acceptance 7 (FPS) is open as a failure.**
**`MAX_CHUNKS_PER_TICK` went 512 → 100** (decided by the user, `src/sim/sim_tuning.gd`).
**Read the comment above that constant — the cost rationale flipped twice in one day and this is the third value.**
**And the cliff comes not from the 512 cap but from ~33 active chunks** (`WATER_SUBSTEPS=3` runs each chunk 3 times).
**512 is 15× the effective limit** — it can't function as a safety net.

### Do not trust these numbers as-is

- **20 monsters at 5,000μs is not measured.** It was borrowed from the player, and monsters add "where do I go"
- **The borrowed original is stale too** — the box was 81 cells when measured, then **narrowed to 54 and never re-measured**
- **Whoever implements is the first person to measure monster cost. Leave the measurement in a comment there** (CLAUDE.md)
- **And answer "are monsters 20Hz or 60Hz" first.** The 30% and 10% above split on that one question

---

## Where they are — placed in advance

**They sit where they were placed and move when you approach.** No spawn effect, no spawner that keeps emitting.

**Spawners were dropped because they collide head-on with the GDD** — the GDD's "Leveling" pins the goal
**"killing a lot is a gain, walking past without killing is also a gain"**, and
**a spawner multiplies if left alone, which punishes walking past.**

### Boundary — **"how many go where on the map" is not this doc**

This doc holds only **what a monster is and how it behaves.** **Actual placement coordinates belong to the map side**
([terrain-baking.md](terrain-baking.md) — which currently contains not one instance of the word "monster".
**A place for it must be made there**).

**⇒ That place now exists and is built**:
[../plans/3.done/monster-placement-stage1.md](../plans/3.done/monster-placement-stage1.md)
— the `(tile x, kind)` table in `src/stage/stage1_monsters.gd`, the sleep model that lets its rows live under
a cap of 20, and the XP arithmetic that has to produce a level-up before the bull. **The bosses are rows in
that same table**, so the stage's ending is reachable by walking. Counts and coordinates live there; **do not
copy them here.**
**The wolf is assigned to stage 1** — decided by the user, so this doc's "Stage 1's trash mobs — two" is
**three**: 돼지 · 늑대 · 닭.

**This repo already knows what happens without that split.** The water design left exactly the same warning
("'where does water go on the map' is not this doc"), **and the accident happened anyway** —
water was finished, the game launched, and not one cell of water appeared
(CLAUDE.md, "is there a path for the thing you want to see to reach the screen").

**⇒ If monsters are implemented, the game launches and there isn't one, that is not a bug — it is the other side of this boundary being empty.**
**The implementation plan must include "a path that stands at least one on the stage"** — `src/stage/` is the shell,
outside the file-count contract, and `ignite` is the precedent.

**That warning was earned twice.** The path exists now (`stage.gd._build_room()`), and building it the build
**still found that deleting the wiring line left all 31 nets green** — the shell being outside the nets is the
same hole in a different place. Detail in the plan.

---

## When they die

**They vanish and drop XP and money** (GDD "Drops" as written — ordinary monsters give nothing used in assembly).

**The corpse lies briefly and disappears.** Presentation only; it does not touch the grid.

**Leaving it in the grid ("meat cells") was deliberately not chosen.** Material slots have room
(5 of 16 used: empty · stone · wood · bedrock · water), but **a corpse cell could wake a chunk and keep it awake,
and water failed acceptance 7 for exactly that problem.** ⇒ **Reopen after water closes and the real margin is visible.**

### Dying differently per cause — cheap. Any time later

The user said "later I'd like them to die differently per interaction, but it sounds hard". **It isn't:**

| What | Cost |
|---|---|
| **Corpse art per cause of death** (fire → charred, blast → scattered, fall → flattened) | **Cheap.** Record the cause and swap the art. **Does not touch the grid** |
| **Traces left in the grid** (burned to death leaves ash that burns again) | **Expensive.** Same place as "meat cells" — **after water** |

---

## Screen — display it excessively

User decision: **"you can display it as excessively as you want".**

| Display | Note |
|---|---|
| **Health bar overhead** | Warned that 20 mobs turns the screen into bars; **the user went ahead anyway** |
| **Flash on hit** | Needs a shader |
| **Damage numbers** | Appear where hit |
| **Fire on the body** | Attaches in **several places.** Same family as the player's burn duration |

**The HUD is currently a debug label, so there is nowhere for these four to attach** (`docs/design/README.md`).
**With all four attached they overlap grid, corpses, fire and water on one screen.** Whether it reads is
**judged by eye only** — headless can't measure it.

---

## TBD

**Do not force these full.** These are what gets asked during implementation.

- **Do monsters run on the 20Hz tick or the 60Hz frame** — the 30% vs 10% above splits on this alone.
  The player is 60Hz. **The implementation plan answers this first**
- **Health · damage · movement speed values** — none decided. "Skeleton first", so they get set on screen while building.
  **Box sizes are decided** ("Size") — only those were needed before the screen
- **Is the pig a "charge" or a "walk"** — the role is melee, but the speed curve is TBD
- **How the chicken shoots** — range · does it stop first · is there a telegraph · bolt speed ·
  **is the bolt blocked by terrain** (decided: yes) · reload interval. **It became ranged recently, so there is no detail**
- ~~**Sprites** — none~~ → **generated.** The user picked from candidates —
  **pig = boar** · **chicken = cartoon** (the **only one whose eyes read at 24px**. It's a ranged mob,
  so "it's aiming at me" must be visible). `assets/monster/pig_body.png` (44×32) · `chicken_body.png` (24×28).
  **The name follows the mob, not the art** — the art is a boar but the design item is "pig"
  - **Generated with local ComfyUI (`tools/pixel/`). Zero pixellab credits.** The user set that
  - **Generation size must be 4× the target — the opposite of other presets' "draw big and downscale".**
    16× and 8× **fail to fill** the 44×32 box, giving 41×24. **Downscaling picks the dominant color of a block,
    so the larger the factor, the more thin things like legs and outlines vanish entirely** (three were compared by measurement)
  - **Generating on a white background punches a hole straight through a white chicken** — alpha removal reads the
    white body as background. Switching to **chroma green** keeps both the black boar and the white chicken
  - **A black mob is unusable even when generated** — it sinks into the `#0e0e13` sky, its legs disappear, and only a blob remains.
    **The same happened with pixellab** ⇒ **the problem is the background, not the color**

- **There is no outline — and the generation stage cannot add one in principle**

  **The player's darkest color `(79,52,76)` (dark plum) forms an outline; monsters have none.**
  Four attempts **all failed**: `thick dark outline` in style · `every edge traced with a solid black outline`
  in the prompt · cfg 5.0 → 7.5 · generation size 16/8/4×.

  **Why in principle**: `k_centroid` downscaling picks a **dominant color** per block, and
  **an outline is a minority color in every block, so it is always discarded.** Even at low factors a 1–2px
  outline is a minority within its block.
  ⇒ To have one: **(a) an automatic outline pass after downscaling · (b) a shader · (c) go without.** **Currently (c).**
  **Open it when it's attached and visibly wrong.** Not hand-pixeled — the user blocked that

- **The color count differs from the player** — monsters **486 / 237 colors**, player **35**.
  `k_centroid` downscaling left soft shading as nearly unique colors.
  **Deliberately not reduced** — **what the user approved is that picture, and reducing the palette makes it a different picture.**
  ⇒ **Whether to reduce is the user's call** (one `quantize_to_palette` does it)
- **How many chickens cluster** — how the 20 cap is divided
- ~~**Midboss (a bull that swallowed the fire rune)** — role only~~ → **behavior decided**
  → `docs/plans/3.done/stage1-bosses.md`. **Charges and rams with a stun · breathes fire (it sticks to terrain) ·
  digs terrain only while charging · speeds up at half health.** The stage boss is a **giant rooster**
  (leaps, pounces, lands).
  **Health, damage and size values, and "how the fire rune is granted", are still TBD.**
  **And the boss is the first real code to enter the isolated `_next_axis()` slot** — see "AI is deferred"
- **Stage 2 and 3 monsters** — only "no insects" and "roles need not all be filled" are decided
- **How they meet water** — do they wash away · sink · drown. **After water closes**
- **How they meet lightning** — wet conducts (GDD). **There is no lightning rune**
