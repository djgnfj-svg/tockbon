# Monster placement — stage 1's mobs stand on the map before you arrive

**Status**: implemented (A~D) · verified · **screen unverified**. **Launching the game no longer finds an
empty map**, and the bosses are rows in the table too — **you walk to the ending, no `C` key.**
See "What landed" below: verification found **six false greens and two checks that never ran**, all fixed.
**One line**: a **table of `(tile x, kind)`** puts trash mobs along stage 1's ground, spread thin rather than
clumped, never overlapping, and **asleep until the player is near** — which is the half of `monsters.md` that
was handed to the map side and left empty.

**Design doc**: [../../design/monsters.md](../../design/monsters.md) — "Where they are — placed in advance",
whose own boundary section says placement coordinates belong to the map side and warns that
`terrain-baking.md` "currently contains not one instance of the word 'monster'". **It still doesn't.
This doc is that place.**
**Decision**: [../../decisions/mobs-lie-on-the-map-no-arena-room.md](../../decisions/mobs-lie-on-the-map-no-arena-room.md)
— why there is no combat room, no trigger, no spawner, and no clumping.
**Map**: [../3.done/stage1-map-layout.md](../3.done/stage1-map-layout.md) — the zones and their tile ranges.
**Sibling**: [monster-ai-jump-and-separation.md](monster-ai-jump-and-separation.md) — how they behave once
standing. Deliberately a separate doc (user's instruction).

---

## Why

**Launch the game today and there is not one monster in it.** The only way to make one is the debug key
(mouse + M → `stage._spawn_monster_at` → `world_step.spawn_monster`). There is no other caller anywhere.

`monsters.md` predicted this exact outcome in writing:

> **If monsters are implemented, the game launches and there isn't one, that is not a bug — it is the other
> side of this boundary being empty.**

And this repo has already lived it once with water: finished, launched, **not one cell appeared**, because
nothing called `set_water`.

---

## Behavior

### 1. The table is `(tile x, kind)` — **y is found, never written down**

A placement row is a **tile x column and a kind**. At load, each row drops from the top of that column to the
first solid cell and stands the mob on it.

**Why y is not in the table**: the map is 400×48 tiles and hand-authored (`terrain_map_generated.gd`), and it
has been redrawn at least once already ("왼쪽 절반이 다시 그려졌다", `stage1-map-layout.md`). **Hand-written
y values silently rot the moment a slope moves** — mobs end up buried in stone or floating a tile above the
ground, with no error. Finding the ground makes the table survive a redraw.

**It also makes the table readable as design**: "a pig at tx 40" is a decision; "a pig at (1280, 704)" is a
coordinate nobody can check against the picture.

**A row whose column has no ground is an error, not a silent skip.** `push_error` — and the wrapper's silence
check means the bark and its `t.expect_error` move together (CLAUDE.md).

### 2. Where they stand — the rhythm

Ranges are `stage1-map-layout.md`'s own zones. **Its coordinates are approximate by its own statement**
("좌표는 대략값이다 … 다음 세션이 이 표를 확정 수치로 읽으면 안 된다"), so these follow the **order**, and
the exact tile numbers get adjusted against the real map while building.

| Zone | tx | Screens | Mobs | What it teaches |
|---|---|---|---|---|
| Start | 0–10 | 0.3 | **0** | You get to look at the world before it wants anything |
| Warm-up A | 10–60 | 1.7 | **3 pigs** | One at a time, far apart. A pig walks at you and that is all |
| Warm-up B | 60–130 | 2.3 | **4 pigs · 4 hens** | **The hen's first appearance** — something shoots back, so distance becomes a thing you manage |
| Warm-up C | 130–190 | 2.0 | **3 pigs · 3 wolves** | **The wolf's first appearance** — fast and thin. Reacting matters |
| Approach to ① | 190–230 | 1.3 | **3 pigs · 4 hens** | Slightly denser. The last stretch before the bull |
| **① pit** | 230–265 | — | **0** | Midboss. `stage1-bosses.md` owns it |
| Buffer · wood wall | 265–290 | — | **0** | The wall must be burned. A mob here would fight the lesson |
| **② combat zone** | 290–355 | 2.2 | **6 pigs · 4 hens · 2 wolves** | **Post-fire.** The densest stretch — the first place burning a group is the obvious answer |
| **③ boss room** | 360–380 | — | **0** | Rooster |
| Gate | 380–400 | — | **0** | |

**Totals: 19 pigs · 12 hens · 5 wolves = 36 mobs**, against a live cap of 20 (see §4).

**"잔잔하게" is what sets the density** (the user's word, replacing the older "화면당 3~4마리씩 뭉쳐서"
plan). Warm-up runs at **~3 mobs per screen**, ② at ~5.5. **Neither is a clump** — the spacing rule below
prevents one from forming at authoring time.

### 3. Never overlapping — two different problems, two different fixes

- **At authoring**: a **minimum tile gap between adjacent rows**. Wide enough that no two boxes overlap at
  spawn, plus slack — the widest trash-mob box is the hen at 48px = 1.5 tiles, so **a 3-tile minimum gap** is
  comfortable and also reads as "spread out" rather than "a row of animals".
  **A net measures the table itself** — no two placed boxes intersect. This is a check that can run with no
  game at all, on the data.
- **At runtime**: they all walk toward the player and converge. **That is the sibling doc's separation
  behaviour** ([monster-ai-jump-and-separation.md](monster-ai-jump-and-separation.md) §3). Authoring gaps do
  nothing for it — three seconds in, spawn positions are irrelevant.

**Both are needed and neither substitutes for the other.** Fixing only authoring gives a tidy first frame and
a shuddering blob afterwards; fixing only runtime gives mobs standing inside each other at load.

### 4. Asleep until near — how 36 mobs fit under a cap of 20

`MAX_MONSTERS` = 20, and `world_step.spawn_monster` **refuses to create the 21st** (it does not evict — the
same idiom as the bolt cap, because "I spawn and some do not come out" reads as a malfunction).

**36 rows cannot all be live at once.** The chosen reading:

> **The cap counts live monsters. The table is not capped.**

- A row is **dormant data** until the player comes within an activation distance; then it becomes a real
  monster through **`spawn_monster` — still the only door** (its box-inside-the-grid check and cap check must
  keep applying, and putting a second door in `stage.gd` would put them out of the nets' reach).
- A row that has been **killed is marked spent and never comes back.** No respawn — walking a stretch twice
  must not farm it. (`GDD` "killing a lot is a gain, walking past is also a gain" — respawn quietly turns
  that into "walk back and forth", which is neither.)
- A live monster that gets far away **stops stepping but is not destroyed.** Its position, hp, burning state
  and the pit you dropped it into all persist.

**Why sleep and not despawn** — this is the fork the user closed with "배치되어 있는 게 가장 좋지 않을까":
digging terrain to trap a mob is this game's thesis, and **despawning erases the result of that work.** Walk
away from a pig you trapped, come back, and a despawn model shows you an untrapped pig standing on flat
ground. Sleep shows you the pig still in the hole.

**Sleep is nearly free**: monsters only **read** the grid (`monster.gd:2`), so a sleeping one wakes no chunk,
and a skipped `step()` is a skipped `box_free` sweep — the expensive part.

#### 4.1 Sleep is not "skip everything" — **fire still kills a sleeping mob** (decided by the user)

The user's words: **"자는 모습도 불에 탈 거고."** Set a fire, walk two screens away, and the mobs you set
alight **die.** The alternative — walking away rescues them — makes fire the one weapon that stops working
when you use it correctly, and burning a group and leaving is exactly the play ② is built to invite.

⇒ **The sleep skip is scoped to movement, not to state.** `monster.step()` today does five things in a
contract order (grounding → axis → gravity → move → `_burn`). **Sleep skips the middle three. `_burn` runs.**

- `_burn` reads the cells the box covers to ask "am I standing in fire" — **that is a `box_free`-shaped sweep
  and it is the expensive part of the frame.** Sleeping mobs are not free anymore; they are *cheaper*, not
  free. **The cost table must be re-measured with this in it**, and a sleeping mob's cost is now its own row
- **A sleeping mob does not fall.** If the terrain under it is destroyed while asleep, it hangs until it
  wakes. Nobody sees it (it is off screen by definition) and it resolves on the frame it wakes
- **A sleeping mob can die**, so the death path — corpse, xp, money, the death burst — has to work with no
  player nearby. **XP from an off-screen death still lands** (`progress` is not positional)
- **A corpse nobody watched still expires.** It is presentation with an age; ages do not sleep

**This is where the sleep model is most likely to be built wrong**, and the failure is silent in both
directions: skip `_burn` and fire quietly stops working at range; run the whole `step()` and there was never
any sleep at all. **A net must measure both halves separately** — a sleeping mob in fire loses hp, and a
sleeping mob on flat ground does not move.

**Activation distance**: the window is 960px wide. A half-width of **~720px** (1.5 screens each way) wakes
things before they are on screen, so nothing pops into view already walking. At the densities above that is
**~5–7 live at a time in warm-up and ~11 in ②** — comfortably under 20, with the cap acting as the safety net
it is supposed to be rather than a budget being spent.

### 5. What a full clear is worth — and why that number is load-bearing

`progress.xp_for_level(level)` = `60 + 30·level`. XP per kind: **pig 12 · hen 6 · wolf 15**.

| | Mobs | XP |
|---|---|---|
| ~~Warm-up (10–230)~~ ~~13 pigs · 8 hens · 3 wolves~~ | **as built: 11 pigs · 7 hens · 2 wolves** | ~~249~~ **204** |
| Cumulative to level 1 / 2 / 3 | | 60 / 150 / 270 |

**Four rows were cut from pre-① to fit `MAX_MONSTERS = 20`** — one from each of the four zones, never the row
that first introduces a kind, so pig → pig+hen → pig+wolf still happens in that order. The grounds are in
`stage1_monsters.gd`'s own header; **do not restate them here.**

⇒ **Clearing the warm-up lands at level 2, just short of 3** — **the conclusion survives the cut** (204 is
still past 150 and short of 270). Killing roughly half still reaches level 1.

**This is the thing the dropped combat room existed to guarantee.** With no room, the mob count *is* the
pacing knob — place too few and the player meets the bull at level 0 having never seen the three-pick, which
is the exact failure the decision doc names as its reopen condition. **A build must check this by playing,
not by arithmetic**: XP is only collected from mobs actually killed, and "walking past is also a gain" means
some players will arrive at ① with far less.

② adds another **126 XP** (6·12 + 4·6 + 2·15 — ~~114~~, this line's own arithmetic was wrong), which is
roughly one more level before the rooster. **② is placed but dormant in this build** — the step from ①'s pit
floor to ②'s shelf is 6 tiles against a 3.375-tile jump, so nothing reaches it until
`2.active/water-jump-and-escape.md` lands.

---

## Screen

**Nothing new is drawn.** Everything a placed mob shows — sprite, health bar, hit flash, damage numbers,
outline, fire on the body — is already built and already runs off the debug spawn.

What changes is what the screen has never shown: **mobs standing in the distance, before they notice you.**
That is the picture the whole "placed in advance, no trigger" decision is buying, and it is judged by eye.

**The HUD already reports the live count** (`stage.gd:1144`, "몬스터 %d / %d마리"), which becomes the readout
for whether sleep/wake is working — walk right and watch it rise and fall.

**Nobody has looked. Three things to carry in:**

- **Do they actually walk out at you** — headless proves they exist and are awake, not that they arrive
- **Do 20 of them jitter.** The separation pass runs at 60Hz over every awake pair; a shove that never settles
  reads as a shimmer, and that is invisible to a check that reads final positions
- **Do the per-zone gaps read as neither crammed nor barren** — §2's rhythm is the thing being judged

---

## Bounds

| Situation | What must happen |
|---|---|
| **A column with no ground** | `push_error`, not a silent skip |
| **A row inside terrain** (a slope moved under it) | The ground search fixes it automatically. **That is the point of not writing y** |
| **The player digs away the ground under a sleeping mob** | It wakes where it was and falls. Gravity is applied on wake, not retroactively |
| **The player burns a group and walks away** | **They keep burning and they die** (decided by the user: "자는 모습도 불에 탈 거고"). See §4.1 — sleep is not "skip everything" |
| **The player walks back over a cleared stretch** | Empty. Spent rows never return |
| **Live count hits 20** | The 21st is refused. With the densities above this should never happen — **if it does, it is a placement bug, and it must be visible** (the HUD count already shows it) |
| **A mob wakes inside the player** | Contact damage on the wake frame. Activation is ~720px out, so this cannot happen from walking; it could from a teleport that does not exist |
| **Save / restart** | There is no save. A run starts with every row unspent |

---

## Interaction with what exists

- **`world_step.spawn_monster`** — unchanged, and still the only door. The placement runner calls it.
- **`stage.gd`** — the shell, outside the file-count contract, and `ignite` is the precedent for "the stage
  wires a thing into the world". **The debug M key stays** — it is how anyone tests a mob without walking to it.
- **`terrain_map_generated.gd`** — read-only. The ground search asks the grid, not the map file.
- **`monster_defs.KIND_WOLF`** — its own comment says "**It is not assigned to a stage** … placement is the
  map's share, not this table's". **This doc is that share, and it assigns the wolf to stage 1.**
  `monsters.md`'s "Stage 1's trash mobs — two" is superseded on that point; see TBD.
- **`progress`** — untouched. XP arrives through the existing kill path.
- **The bosses** — ①③ get **zero placed mobs**. Bosses are `stage1-bosses.md`'s and are not in this table.

---

## Cost

- **The table is data.** ~~36~~ **34 rows** as built. **The measured numbers are in "What landed" below** —
  these are the estimates that were made before it, kept for the reasoning, not for the values.
- **The ground search runs once per row, at load**, or once per row at wake. Either is a column scan of ≤48
  cells. Negligible, and it is not per-frame.
- **The sleep check is per live monster per frame** — one distance compare against the player's x. Nothing
  next to the `box_free` sweeps it *avoids*.
- **The real number is what is live**: ~11 at the densest point in ②. Against `monster_defs.gd`'s measured
  table (20 pigs = 3,416µs = 20.5% of the 60Hz frame), **11 mixed mobs lands around 10–12%.**
- **What is still unmeasured is the overlap** — mobs *plus* fire on one screen, which is exactly what ② is
  designed to produce. `monsters.md`: "the problem is not monsters alone but the overlap". **Stage 1 has no
  water** (`stage1-map-layout.md`), so the chunk cliff is not in play here.

---

## What landed — and **six false greens**

`src/stage/stage1_monsters.gd` (new) holds the `(tx, kind)` table, now **34 rows**, and
`src/actor/monster_placement.gd` (new) is the pure resolver. **The ground search scans upward from the map's
floor** — top-down breaks on the **floating bedrock at tx149–150** and on **room ③'s roof at tx345–366**.

**The bosses are rows too** — bull at **tx245** (room ①), rooster at **tx358** (room ③). ⇒ **the chain is
walkable end to end with no debug key**, which is what `3.done/gate-ending-to-game.md` was waiting on.
The warm-up stretch before ① came down 24 → **20**, because `MAX_MONSTERS` is 20.

**Sleep** is `monster.asleep`, refreshed every tick by distance in `world_step`. Two exclusions, both found by
measurement, not by reasoning: **bosses never sleep** (room ① is 960px, wider than `SLEEP_PX`, so a bull froze
mid-charge and mid-leap), and **only monsters that came from the table sleep** — debug keys and tests stand up
monsters that must stay awake. A sleeping monster runs `_burn` and nothing else.

**The wiring line is in `_build_room()`, not `_ready()`.** The nets' `_wired_root()` never runs `_ready()`, so
a line put there is **green in every net and dead the first time the player presses R**.

### What verification found — six false greens, two checks that never ran

1. **Delete the placement wiring line from `stage.gd` entirely and all 31 nets stayed green** — the fifth
   "the shell is outside the nets" of that one day
2. **The hysteresis check never entered the [720, 840) band.** The net measured the box's **left edge**,
   production measured its **centre** ⇒ setting `SLEEP_PX` to **720 or to 100000** both stayed green
3. **The bosses were not pinned to their rooms.** `tx358 → tx367` (the rooster **on the roof**) and `tx395`
   (27 tiles outside the room) were both green. **The "no ground" bark cannot fire from any tx on this map** —
   of 3200 cells on the `FLOOR_CY` row, **zero** are not solid
4. **The 20-monster cap invariant was unguarded** — put 24 back and update the number and it goes green
5. **A real placement defect.** The hen at tx312 hung **4 of its 12 foot cells over a 96px cliff** (33% of the
   box). The surface check claimed "all 34 rows" while reading **one cell**. ⇒ **`resolve()` itself now checks
   the full box width**, and a sweep of the real map turned up exactly one row — **tx312 moved to tx311**
6. **Up-scan and down-scan did not differ on the real map** — reversing the direction passed all 34 rows; only
   two synthetic-grid checks went red
7. **Neither "contract" at `wake_scan()`'s seat was being measured** — they held by accident
8. **The measuring tool itself was lying.** `profile_monsters.gd` spread its monsters apart on purpose,
   **hiding separation's cost as zero**, and after Stage D it was **timing an all-asleep world.** Both fixed

**Measured cost**: 20 awake **+27.9%** (pigs) / **+41.0%** (hens); 20 asleep **+4.2% / +8.4%**; the dormant
34-row scan every tick **+0.01%**.

### Where this feature and the jump meet — one net had to change

**`net_monster_placement.gd` assumed "asleep exactly one tick later".** That broke when
`3.done/monster-ai-jump-and-separation.md`'s separation fix landed: a wall sits at the test monster's spawn
point, **so it jumps**, and a monster in the air does not go to sleep on schedule. The check now waits up to
**15 ticks**. **Sleep and jumping share the same `on_ground`** — that is the seam, and it is the only one.

## Acceptance — **1 · 3 · 6 · 8 · 9 are the screen's and none has been looked at**

1. **Launch the game, walk right, and meet monsters without pressing anything.** The whole point
2. **No two mobs overlap at spawn** — measured on the table, headless
3. **The live count rises and falls as you walk** (HUD), and never reaches 20
4. **A mob trapped in a pit is still in that pit after you walk two screens away and come back**
5. **A cleared stretch stays cleared**
6. **The warm-up produces at least one level-up before ①** — played, not computed
7. **Mobs stand on the ground, not in it and not above it**, everywhere on the map
8. **The hen appears after the pig, and the wolf after the hen** — the teaching order actually happens
9. **② reads as denser than the warm-up** — by eye
10. **Frame cost at ②'s density, with fire burning**

---

## TBD

- ~~**Is the wolf in stage 1?**~~ → **Decided by the user: yes.** Stage 1's full roster is
  **돼지 · 늑대 · 닭** as trash, **소** as midboss, **거대 수탉** as the stage boss. `monsters.md`'s
  "Stage 1's trash mobs" now reads three, and **`monster_defs.KIND_WOLF`'s "it is not assigned to a stage"
  comment is stale — it is a code edit and was deliberately not made** (another session is editing `src/`)
- **Every tile number here is a proposal against a map whose own doc calls its coordinates approximate.**
  The order and the rhythm are the decision; the numbers get adjusted on screen
- **Whether the counts are right at all.** They were chosen against the XP curve and "잔잔하게", and
  `stage1-map-layout.md` already labels its own density a rough value to adjust after playing
- **Does ② need its own kinds?** It is post-fire and pre-boss; right now it is the same three mobs, denser
- **Nothing places money or drops** — those ride the existing kill path

---

# Implementation plan

Written by spec against the code, not against the doc above. **Every claim below names the file and line it
was read from.** Where this plan and the Behavior section disagree, the disagreement is listed in
"Where this plan overrules the design doc" and the code is the reason.

## What the user has to decide (does not block the build — every stage below is buildable either way)

1. **36 rows against a cap of 20 does not survive a player who walks past.** §4 says "with the densities
   above this should never happen". It happens: the pre-① rows are **3 + 8 + 6 + 7 = 24**, nothing ever
   despawns (§4's own decision), and the activation half-width is 720px, so a player who kills nothing has
   **24 rows woken by the time they reach ①** and the cap refuses the last four. The choice is the user's:
   **cut the pre-① count to ≤20**, or **raise `MAX_MONSTERS`** (a user-set value —
   `monster_defs.gd:36`, and `net_monster._defs_accessors` asserts the literal 20), or **accept it**.
   **Stage B builds the honest version either way**: a refused wake leaves the row dormant and retries, so a
   row is never silently lost — but a mob then appears closer than 720px, which is the thing the 720px exists
   to prevent. **Nothing is decided here.**
2. **The ending stays unreachable after this build.** The rooster is not on the map and this table
   deliberately holds no bosses (§Interaction). So `gate-ending-to-game.md`'s wall, arch and ending still only
   fire after pressing `C`. **Two more rows in the same table close it** (the `kind` column already accepts
   any kind) — the user says whether that is this round or the next.
3. **② is not walkable in a normal run today.** Read off the baked map: the pit floor is ty 32 (tx 230–259)
   and the shelf east of it is ty 26 (tx 260–292) — **a 6-tile step against a 3.375-tile jump**
   (`character.gd:91-92`, 720²/(2·2400) = 108px). The only way up is the water escape, which is still
   `2.active/water-jump-and-escape.md`. ②'s 12 rows are correct to author now and will simply stay dormant.
   **The user decides whether ② is worth placing before that lands.**

## What was measured, and where the design doc is wrong

Every row below came from computing the terrain profile of `terrain_map_generated.gd` directly (first solid
tile per column, all 400 columns), and from reading the files the doc names.

| The doc says | The code says |
|---|---|
| §1 "each row drops **from the top** of that column to the first solid cell" | **Wrong twice on this exact map.** `tx 149–150` carries a **floating 2×2 bedrock block at ty 15–16** with real ground at ty 20 — a downward scan stands a mob 5 tiles in the air, inside Warm-up C's own 130–190 range. And `tx 345–368` is **room ③'s roof at ty 12** — a downward scan stands a mob on the roof of the boss room. ⇒ **scan upward from the map's bottom row.** From the bottom, tx 149 resolves to ty 20 (ignores the block) and tx 350 resolves to ty 24 (inside the room, on its floor at ty 25). Verified against all 400 columns: there is no cave anywhere on this map, so an upward scan is exact everywhere |
| §2 "**② combat zone** 290–355" | **345–355 is the room ③ roof.** ②'s usable range is **290–344**. The real ground there: 285–292 ty 26 · 293–312 ty 24 · 313–330 ty 27 · 331–344 ty 25 |
| §4 heading "**Asleep until near — how 36 mobs fit under a cap of 20**" | **Sleep frees no slot.** `world_step.spawn_monster` counts `_monsters.size()` (`world_step.gd:457`) and a sleeping monster is still in `_monsters`. What fits 36 rows under 20 is **activation + spent**, not sleep. Sleep buys two different things and they are the real reasons to build it: **a mob you left far away does not trail you across the map**, and **the pig stays in the pit you dug** |
| Bounds: "Live count hits 20 … this should never happen" | See user decision 1 — it happens at row 21 of 24 for a player who kills nothing, which the GDD explicitly supports |
| Bounds: "Activation is ~720px out, so this cannot happen from walking" | True at play scale. **`-` zooms out** (`stage.gd:316`, `ZOOM_STEPS` down to 0.075 ⇒ a 12,800px-wide view), so mobs pop in on screen at every zoom-out step. **Do not couple activation to zoom** — zoom is "a shell debug view, not a design axis" (that constant's own comment) and `world_step` cannot see it without pushing a debug axis into the world. Named, not fixed |
| §4.1 "`step()` today does **five** things (grounding → axis → gravity → move → `_burn`). Sleep skips the middle three" | `monster.step()` (`monster.gd:150-176`) does **nine**, including **two** `grounded()` box sweeps (lines 151 and 167) and the leap latch. Sleep must skip lines 151–173 and run only `_burn`. **The two `grounded()` calls are where most of the saving is**, not the axis pick |
| §Cost "the real number is what is live: **~11** at the densest point in ②" | **The ceiling is 20 live, not 11**, precisely because nothing despawns. Budget against `monster_defs.gd`'s measured 20-at-once column: 20 pigs +3,416µs (20.5%) · 20 hens +5,318µs (31.9%) · 20 wolves +4,004µs (24.0%) |
| §4 "**Sleep is nearly free**" (corrected by §4.1 itself) | Correct to correct it. `_burn` → `Body.standing_in_fire` sweeps the box **plus one row under the feet** (`body.gd:188-198`) — for the hen that is 12×17 = **204 cells**, the single largest sweep any monster does. The number is not guessable; Stage D measures it |
| §Interaction "`monster_defs.KIND_WOLF`'s … comment is stale — deliberately not made" | Still stale: `monster_defs.gd:28-30` reads "It is not assigned to a stage. Stage 1's pair is pig + hen". **And a second copy exists**: `stage_input.gd:99-101` reads "The wolf has no map placement, so this key is the only way one ever reaches the screen". **Both are this build's to fix** |
| §Bounds "Save / restart — a run starts with every row unspent" | The doors are `reset_stage()` (R), `enter_town()` and `_leave_town()` — all three funnel through `reset_stage()` (`stage.gd:1059-1069`), which calls `_world.reset()` then `_build_room()`. Answered by Stage C's placement of the wiring line |

**One thing the doc got exactly right for a reason it did not state**: the 265–290 buffer with **0 mobs**.
A player stuck on the pit floor at x259 is 22.5 tiles from x281 — so any ② row west of ~x282 would wake while
the player is 6 tiles below it, walk to the shelf edge at x260, and **fall into the bull fight**. The buffer
is what stops that. Write the reason down when the numbers get adjusted, or the next redraw will delete it.

## Structure — variant or new kind?

**A variant.** Adding one mob to stage 1 must be **one row in one file**, and adding stage 2's table must be
**one new data file plus one line in `_build_room()`**. Nothing else may grow.

- **The kind table does not change.** `monster_defs.DEFS` already carries every value a placed mob needs, and
  `spawn_monster` already holds all three creation conditions in one place (`world_step.gd:440-470`: the
  `_broken` door, the cap, the box-inside-the-grid check). **It stays the only door** — a second door in
  `stage.gd` would put the cap and the bounds check out of the nets' reach, which is that function's own
  recorded reason for existing.
- **What is genuinely new** is one thing the repo does not have: **a monster that exists as data before it
  exists as an object.** That is one new file (`monster_placement.gd`) with one new field on nothing — the
  precedent is `boss_ai.gd`, a pure decision object `monster.gd` calls and the nets drive directly.
- **Files that change to add one mob: one.** Files that change to add a stage: two.

### Where the table lives — `src/stage/`, and the shell pushes it in

`src/actor/` may not reference `src/stage/` (`world_step.gd` header, measured by `net_layers`). That single
rule decides it:

- **The table is map content** and belongs beside `terrain_map_generated.gd`, in `src/stage/`. It is a
  `const`, so `net_pick`'s no-inventory scan (which anchors on column-0 `var`) never sees it.
- **The runner is `src/actor/`** because the wake decision is per-frame world state and must run inside
  `world_step.frame()` — the one place the tick order lives, and the one thing the nets can drive headless.
- ⇒ **the shell hands the table down**, exactly as it already hands `_char`/`_grid`/`_progress` to the views
  (`stage.gd:374-401`). `src/actor/` never learns the table's name.
- **Nets reach the real table statically**, the same door `net_tables`/`net_water_rain`/`net_gate` already use
  for the real map (`Stage.build_terrain_into(g)`).

**Integer determinism is not in play** — `src/sim/` is untouched. The table is integers anyway; the resolver
uses `floori` on cell coordinates the way `body.gd:165-174` already does.

## Files to touch, and why — one line each

| File | Why |
|---|---|
| **new** `src/stage/stage1_monsters.gd` | The `(tx, kind)` table, `RefCounted`, `const ROWS: Array[Dictionary]` sorted by `tx`, plus `const FLOOR_CY` **derived** from `TerrainMap.MAP_H * Tuning.TILE_CELLS - 1` (never hand-copied — a redraw that changes `MAP_H` must follow for free) |
| **new** `src/actor/monster_placement.gd` | The runner: holds the rows, resolves ground, decides wake/sleep, marks rows spent. Pure `RefCounted`, no scene tree, no reference to `src/stage/`. Precedent: `boss_ai.gd` |
| `src/actor/world_step.gd` | Owns one `MonsterPlacement`; `set_placement(rows, floor_cy)`; the wake scan runs in `frame()`'s **tick branch**; the 60Hz `step()` loop passes each monster its sleep state; the death loop (line 204-235) calls `placement.on_monster_died(dying.id)`; `reset()` re-arms every row |
| `src/actor/monster.gd` | `step()` gains the sleep skip — lines 151–173 skipped, `_burn` (line 176) always runs |
| `src/stage/stage.gd` | **One line in `_build_room()`**: push the table for the room just built (`[]` in town). See "the wiring line" below |
| `src/actor/monster_defs.gd` | Comment only — `KIND_WOLF`'s "It is not assigned to a stage" is now false |
| `src/stage/stage_input.gd` | Comment only — `MONSTER_KEYS`' "The wolf has no map placement" is now false. **The M/N/B/C/V keys stay** (§Interaction) |
| `tools/stage/profile_monsters.gd` | One more measured row: **a sleeping monster**. The tool exists so this number is measured, not guessed |
| `src/actor/monster_defs.gd` (table comment) | Write the sleeping row into the profile table there, where every other measurement already lives |
| **new** `tests/nets/net_monster_placement.gd` | Its own file, its own process — `net_monster*.gd` is already split four ways for exactly this (that file's header) |
| `tests/nets/net_pick.gd` | Add `monster_placement.gd`'s bookkeeping fields to the no-inventory allowlist, **with the reason written in** — placement bookkeeping keyed by row index is not a glyph that left a spell layer. Widening the regex instead is the failure that allowlist's own comment names |

**Not touched**: `terrain_map_generated.gd` (read-only, §Interaction) · `progress.gd` (XP rides the existing
kill path) · `monster_view.gd` (nothing new is drawn — §Screen) · `spawn_monster`'s signature.

## The wiring line — and how a net measures it

**The line goes in `_build_room()` (`stage.gd:956`), not `_ready()`.** This is not style:

- `reset_stage()` (R), `enter_town()` and `_leave_town()` all route through `_build_room()`
  (`stage.gd:945, 1059-1069`). A push in `_ready()` runs **once**, and the first R would wipe the placement
  with `_world.reset()` and never restore it — **the game would work until you pressed R.**
- **The nets' own `_wired_root()` never runs `_ready()`.** It instantiates `stage.tscn`, sets the `@onready`
  fields by hand and then calls `reset_stage()` (`net_gate.gd:673-707`). A line in `_ready()` is therefore
  **invisible to every net in this repo** — the exact "the shell's wiring line is not measured" failure.
- ⇒ **the check**: `_wired_root(t)` → `root.call("_leave_town")` → place `_char` at the spawn tile → pump
  `root.call("_physics_process", 1.0/60.0)` → `_world.monster_count() > 0`. **Delete the line in
  `_build_room()` and this goes red.** Invert it and confirm.

**Do not add a source-text scan of `stage.gd`.** CLAUDE.md lists five separate evasions of exactly that shape
shipped in one feature; `net_monster`'s existing check 13 (grepping for `monster_requested.connect(`) is the
weaker precedent, not the one to copy. **Drive the value.**

## Stage A — the table and the resolver, pure

`stage1_monsters.gd` + the resolve half of `monster_placement.gd`. **Nothing changes in the game.**

The resolver, precisely:

1. Start at `floor_cy` in the column `tx` covers. **If that cell is not solid, the column has no ground** →
   `push_error` (English, one text) and the row is marked spent so it barks once, not every frame.
2. Walk **up** to the first empty cell. The tile below it is the surface.
3. Standing y = `surface_top_px - h_px(kind)`; x = `tx * TILE_CELLS * CELL_PX` (the table's tx is the box's
   left edge — not its centre, so the gap rule below is readable straight off the table).
4. `Body.box_free` at that position. **If the box does not fit** (a low ceiling), `push_error` and spend the
   row. This is what makes "mobs stand on the ground, not in it" a value rather than a hope.

**Resolve at wake, not at load.** A row resolved at load freezes a y the player can dig out from under; a row
resolved at wake follows the terrain, which is the whole reason y is not in the table. It is also cheaper —
only rows that actually wake pay the ≤384-cell column scan, once each.

**What a net measures here** (no game, no scene, `Stage.build_terrain_into(g)` for the real map):

- The table is **sorted by `tx`** — the gap rule and the wake scan both assume it, and an unsorted table makes
  "adjacent" meaningless
- **Every adjacent pair is ≥3 tiles apart** (§3's authoring rule) — bites a typo in the table
- **No two resolved boxes intersect** on the real map (`WorldStep._boxes_overlap`) — bites a terrain change
- **Every row's resolved feet sit exactly on the surface** — y + h_px == surface top, for all 36
- **The floating-platform trap**: a synthetic grid with ground plus a block floating above it resolves to the
  ground. *Inversion: flip the scan to downward-from-the-top and this goes red* — this is the check that
  encodes the map fact found above, so it must bite
- **The teaching order** (acceptance 8, and it is data, not a screenshot): first hen `tx` > first pig `tx`,
  first wolf `tx` > first hen `tx`
- **A groundless column barks** — a synthetic empty grid, `t.expect_error` on the exact `push_error` substring
  (CLAUDE.md: the bark and its forgiveness are one edit)
- **Zone totals** match §2's table (19 pigs · 12 hens · 5 wolves), because the counts are the pacing knob the
  dropped combat room used to be (`decisions/mobs-lie-on-the-map-no-arena-room.md`, "Conditions to reopen")

**Seen by eye: nothing.** That is correct for this stage.

## Stage B — rows become monsters

`world_step` owns the placement. `frame()`'s **tick branch** (20Hz) runs the wake scan; the 60Hz loop is
untouched except for the sleep flag.

- **Wake at 720px, sleep at 840px** — a hysteresis band, or a mob sitting on the threshold flips state every
  tick. Both constants live in `monster_placement.gd` (precedent: `MonsterBolts.BOLT_STOP_PX`), not in
  `sim_tuning` (not sim) and not in `fx_tuning` (not presentation).
- **20Hz, not 60Hz**: 3× cheaper and the granularity is 13px of player travel (`MOVE_SPEED_PX` 260) against a
  720px threshold. It also puts the decision on the same clock as `on_tick`, so a row that wakes gets its
  first `step()` in the same frame.
- **Distance is x only, centre to centre** — the same standard `monster._dist_to_target` already sets. A row
  has no y until it resolves, so there is no other choice, and on this map every zone is a single-height run.
- **`spawn_monster` stays the only door.** A refusal (cap, or box outside the grid) leaves the row **dormant**
  and it retries — never silently lost. See user decision 1.
- **Spent on death**: the death loop already knows the id (`world_step.gd:204-235`). `placement` holds
  `id → row`, so nothing is added to `Monster` and `spawn_monster`'s signature does not move. A debug-key
  monster has no entry and its death does nothing.
- **`reset()` re-arms every row** without changing which table is set, so both doors (`_world.reset()` alone,
  and `reset_stage()`) leave a full run. `set_placement()` only ever answers "which room".

**What a net measures** (headless, real map, no scene):

- Walk a character right from the spawn tile; **the live count rises**, and each mob was created within the
  activation band, not before
- **A killed row never comes back** — kill one, walk two screens away, walk back, count unchanged
- **`reset()` brings every row back** — the whole point of acceptance "a run starts with every row unspent"
- **The cap refuses and the row survives**: fill to 20, wake a 21st, assert `monster_count() == 20` **and**
  that the row is still dormant (not spent). *Inversion: mark it spent on refusal and this goes red*
- **The wake scan runs on the tick, not the frame** — count spawns across a run of frames with the divider in
  mind. A check that reads only the final count cannot tell the two apart (CLAUDE.md's ordering trap)
- **Hysteresis**: drive the character back and forth across 720px and assert the state flips **once**, not
  once per tick

**Seen by eye: still nothing** — no caller in the game yet.

## Stage C — the shell wiring line

One line in `_build_room()`. **This is the first stage with anything on screen**, and it is the stage the
whole doc exists for: launch, walk right, meet a monster without pressing anything.

Measured by the `_wired_root()` drive described above. Seen by eye: acceptance 1, 8, 9.

## Stage D — sleep

`monster.step()` skips lines 151–173 when asleep and always runs `_burn` (line 176).

- **`on_ground` goes stale while asleep.** Verified harmless: `monster_view` never reads it (grepped — zero
  hits), and its only other reader is `_try_step_up`, which lives inside the skipped `move_x`. It resolves on
  the frame the mob wakes, which is §4.1's own stated behaviour.
- **`on_tick` keeps running for sleeping monsters.** It is the reload clock, the invuln clock, the
  hit-by-bolt/blast check and the damage drain — none of them a box sweep unless a bolt is live, and the
  player is >720px away by definition. Keeping it uniform is what keeps the death path, the XP award and
  `Progress.damage_dealt` working with nobody watching (§4.1's own requirement).
- **`_burn` stays at 60Hz.** Moving it to the tick would need `dt` rescaling and would make burn damage read
  from two clocks — the exact shape this repo bans.

**What a net measures — both halves separately, as §4.1 demands:**

- A **sleeping mob standing in fire loses hp** and dies, with the player far away. *Inversion: skip `_burn`
  too and this goes red*
- A **sleeping mob on flat ground does not move**, over hundreds of frames, with a player far to one side.
  *Inversion: run the whole `step()` and this goes red*
- **XP from that off-screen death lands** in `Progress`, and the corpse notification fires
- **The pit holds** (acceptance 4, and it is a value, not a screenshot): trap a mob in a dug hole, walk two
  screens away, walk back, assert its x/y are unchanged
- **Waking restores movement** — the same mob moves after the player returns

**Measured, not by a net**: `tools/stage/profile_monsters.gd` gains a sleeping row, and the number goes into
`monster_defs.gd`'s profile table beside the others. **A threshold on it would be a fake net** — that tool's
own header says why. The number that matters for the budget is **20 live mixed**, not 11.

## Order, and what each stage can be seen by

| Stage | Why it must come first | Net can measure | Only the eye can |
|---|---|---|---|
| A | Nothing can wake a row that cannot resolve a y | the whole table + the resolver | — |
| B | The wiring line has nothing to call until rows become monsters | wake · spend · reset · cap | — |
| C | **The first stage anything reaches the screen** | the wiring line itself | acceptance 1 · 8 · 9 |
| D | The behaviour contract sleep exists for; B is shippable without it | both halves of sleep · the pit | acceptance 4 confirmed by hand |

## Risk

- **The signature fake, in its exact local shape**: rows resolve, `spawn_monster` returns 0, and **not one
  monster appears with no error at all**. Three separate guards — the retry (never spend on refusal), the HUD
  count (`stage.gd:1304`), and Stage B's cap check
- **The wiring line in `_ready()`** — works in the game, invisible to every net, and dies on the first R. The
  single most likely way this build ships broken
- **A source-text scan of `stage.gd`** instead of driving `reset_stage()` — five evasions of that shape are
  already recorded in CLAUDE.md
- **`t.ok(true, ...)` is banned**, and a net that runs zero checks is a failure (`run_nets.gd:102`)
- **`net_pick`'s no-inventory scan will bite `monster_placement.gd`** the moment it declares a column-0
  `var` typed `Array`/`Dictionary`. Add the allowlist entries with reasons; do not widen the regex
- **`net_monster._defs_accessors` asserts `MAX_MONSTERS == 20` as a literal.** If user decision 1 raises the
  cap, that net goes red **and it is right to** — the value is the user's
- **`monster_view` has no culling** — `_draw()` loops every monster wherever it stands (`monster_view.gd:509`).
  Not a regression (20 live cost the same on or off screen) but it is the first build where they are spread
  across 12,800px. Named, not fixed
- **Determinism**: `src/sim/` is untouched, no `randi`, no float in the resolver. `net_determinism` must stay
  green — if it moves, something crossed a folder boundary
- **Two stale comments** (`monster_defs.gd:28-30`, `stage_input.gd:99-101`). Leaving them is this repo's
  "a value counted in two places will diverge", in comment form

## Acceptance — which of §Acceptance's ten this plan can close, and how

| # | Closed by | How |
|---|---|---|
| 1 walk right and meet monsters | Stage C | eye |
| 2 no two overlap at spawn | Stage A | net, on the real map |
| 3 count rises and falls, never 20 | Stage B (rises/falls) · user decision 1 (never 20) | net + HUD |
| 4 a trapped mob is still trapped | Stage D | net **and** eye |
| 5 a cleared stretch stays cleared | Stage B | net |
| 6 one level-up before ① | — | **played, not computed.** The arithmetic (**204** XP vs 150 for level 2) is already in §5 and is not the acceptance |
| 7 stand on the ground everywhere | Stage A | net, all 36 rows |
| 8 hen after pig, wolf after hen | Stage A (data) · Stage C (eye) | both |
| 9 ② reads denser | Stage C | eye — and **only once ② is reachable** (user decision 3) |
| 10 frame cost at ②'s density with fire | Stage D | `profile_monsters.gd`, not a net |

## Out of scope

- **Bosses** — no rows for the bull or the rooster. The consequence (the ending needs `C`) is user decision 2
- **Despawning or respawning** — both are closed decisions (§4, and `decisions/mobs-lie-on-the-map-no-arena-room.md`)
- **Runtime separation** — mobs converging into a blob three seconds in is
  [monster-ai-jump-and-separation.md](monster-ai-jump-and-separation.md)'s, and §3 says so
- **Raising `MAX_MONSTERS`** — user-set
- **View culling**, per-species color, the jump behaviour, stage 2/3 tables
- **Adjusting the tile numbers on screen** — §TBD already owns that, and it is a table edit, not code
