# Burn out of the bull room — the back wall is the door, and zone ② goes

**Status**: done
**Seen on screen, repeatedly, by the user — with fixes made each time.** Fork A shipped: the wood door
in room ①'s back wall, zone ② gone, the rooster reachable straight through.
The user decided the beat and fork A; the plan proposes the geometry, the door's size, the `src/sim/` shape
and what happens to the water.

**One line**: room ①'s **east wall becomes wood**, so the fire rune is used **in the room it was won in** —
kill the bull, take the rune, burn the back wall, and the rooster is on the other side. **Zone ②'s trash run
and the pit's water escape both disappear**, and stage 1 keeps one water escape instead of two.

**The user's words**: 「그냥 황소 맵에 뒤쪽이 그냥 나무인 거고 거기 가면 바로 보스인 거야. 황소 잡고, 잡몹도
없이, 넘어가면 불 룬으로 부시고 넘어가면 바로 보스가 있어.」 **The reason, also theirs**: 「그래야 바로
직관적으로 나갈 수 있어.」

**The onboarding beat hangs off this** — get the rune, be told to slot it, slot it in the assembly window,
fire, the wood goes. **That is not this doc's** → [`design/tutorial.md`](../../design/tutorial.md) and its
first slice, [`onboarding-and-palette-tabs.md`](onboarding-and-palette-tabs.md).

**Constrains and is constrained by**: [stage1-map-layout.md](stage1-map-layout.md) ·
[stage1-bosses.md](stage1-bosses.md) · [water-jump-and-escape.md](../2.active/water-jump-and-escape.md) ·
[left-run-clumps-and-platforms.md](left-run-clumps-and-platforms.md) ·
`docs/design/terrain-baking.md` (how the map is changed at all)

---

## Why

**The rune is won 4 tiles from a wall it cannot reach.** Measured on the baked map, not read out of a doc:

```
x130-159   ty32   room ① — the bull, tx145. 30 tiles wide, flat
x160-163   ty26   room ①'s east wall. 4 columns, top at ty26, solid down to ty31
                  => 6 tiles = 192px of face inside the room, against a 102px jump ceiling
x164-166   ty20   the wood wall. 3 wide x 6 tall = 18 tiles = 1,152 cells. The map's only wood
x167-244   ty26/24/27/25  zone ② — 78 columns of trash-mob ground
x245-268   ty25   room ③ — interior x247-266 (20 tiles), floor ty25, ceiling ty12
x270              the gate seat
```

So today the chain is: kill the bull → take the rune → **wait for the room to flood** → jump-climb 6 tiles →
walk 4 tiles → burn the wall → **cross 78 tiles of trash mobs** → rooster.

**Three things are wrong with that, and the user named the first one.**

1. **The rune is used somewhere else than where it was won.** A flood, a climb and a walk sit between them.
   For the one moment in the game that teaches "a rune is how you get past terrain", that is three subjects.
2. **The flood does not do what every doc says it does.** `stage1-bosses.md`'s own Risk 13-addendum measured
   it: **300 seconds of pouring lifts the player 0px**, and **one ordinary jump already clears room ①'s west
   step in 1.6s with no water at all.** The escape scene the map was shaped around is not happening on this map.
3. **Zone ② is already dormant and unreachable.** `stage1_monsters.gd`'s own header says its 12 rows "stay
   dormant in this build" because the step from ①'s floor (`ty32`) to ②'s shelf (`ty26`) is 6 tiles against a
   3.375-tile jump. **Nobody has ever fought in ②.** Removing it removes something that has never run.

⇒ **The rune's door moves to the wall of the room the rune comes out of.** That is the whole feature.

---

## Behavior

### 1. **This is not a material swap — east of the wall is solid rock, not a room**

**The single most important fact in this doc, and it is easy to get wrong.** Room ① is a pit **dug into
ground whose surface is `ty26`.** Columns `x167-192` are solid `#` from `ty26` all the way down to the
bedrock floor at `y45`. There is no space behind the wall.

⇒ **Burning a door at room ①'s floor level (`ty32`) as the map stands today opens into stone.**

**Two forks, and the user has not picked** (see TBD):

| | **A · bring room ③ down to room ①'s floor** | **B · the door is a climb** |
|---|---|---|
| Room ③ floor | `ty32`, ceiling `ty20` (still 20x12) | stays `ty25` |
| What the player does after burning | **walks through, flat** | burns, then climbs 7 tiles |
| Reads as | 「넘어가면 바로 보스가 있어」 | a shaft between two rooms |
| Cost | room ③ and the gate move down 7 rows | the climb needs a means the player has |
| Risk | none found | **the player has no 7-tile climb.** Jump ceiling is **102px = 3.19 tiles** |

**[mine] A.** B needs a climbing means that does not exist, and the only one the game has ever had for that
height is the water this feature is removing. **A is what the user's sentence describes.**

### 2. The door

**The east wall's inner face is 6 tiles tall and 4 tiles thick.** The door is cut out of it, in `WOOD`.

| | Value | Grounds |
|---|---|---|
| **Where** | room ①'s east wall, `x160-163` | the user's 「뒤쪽」 |
| **Width (thickness)** | **TBD** — the wall is 4 columns thick today | a 3-tile-thick wall is what exists now (`x164-166`) and it burns whole |
| **Height** | **TBD** | the player is **32px = 1 tile**; 2 tiles reads as a doorway |
| **Sill height above ①'s floor** | **TBD, and it is not cosmetic** — see "the bull lights it" below | 0 tiles = walk through · 2 tiles = a 64px hop, inside the 102px ceiling |
| **Material** | `WOOD`, one connected block | `net_tables._wood_clumps` asserts **exactly 1 wood clump on the map**. Moving the wall keeps that at 1; **splitting it into a door plus a leftover wall breaks it** |

**The old wood wall at `x164-166` goes.** Two wood clumps on the map is a red net and a fire that crosses
between them.

### 3. Zone ② goes, and with it 12 dormant rows

`stage1_monsters.ROWS` holds **12 rows in `tx194-244`** (6 pig · 4 hen · 2 wolf). **They are deleted, not
moved** — the user cut the segment, not the mobs.

**The spawn door does not care.** `world_step.spawn_monster`'s boss reserve is
**the number of boss rows in the pushed table, derived, not typed**
([boss-slots-are-reserved-in-the-spawn-door.md](../../decisions/boss-slots-are-reserved-in-the-spawn-door.md)).
Deleting 12 trash rows leaves **2 boss rows** ⇒ the reserve is still 2 and no code changes.
`net_monster_placement._pre_stage1_row_count_stays_under_the_cap` is bounded by
`MAX_MONSTERS − boss_rows` and only gets slacker.

**Whether the map gets shorter is TBD** — see there. The precedent is
[cut-the-terrain-not-the-spawn.md](../../decisions/cut-the-terrain-not-the-spawn.md): when the left run was
too long the user rejected "leave the columns and move the player" outright and **the terrain was cut for
real, 400 → 300.** Its grounds ("~100 tiles of drawn, walkable, empty map") apply here at 78.

### 4. **The water in room ① loses its job — [mine] delete the pour, keep the object**

**Recommendation, with the other branch priced.** The user's decision costs the pit escape and they took that
price; **what to do with the code that poured it was not decided.**

`stage.gd`'s `_room1_reward_water` is **the only live `WaterSource` in the game** — the debug `K` key was cut
(`water-jump-and-escape.md`'s own header) and **room ③'s pour was never wired** (`stage1-bosses.md`, Risk 13).
⇒ **After this feature, stage 1 contains no water at all until room ③'s pour is built.** That is the honest
statement, and it is not what "the rooster's escape stays" sounds like.

**Why the pour cannot simply stay:**

- **An open door plus a filling room breaks a Boundary that was written as a cost line, not a taste.**
  `stage1-bosses.md`: *"Water only after a boss dies — now both of them. **Neither overlaps its fight** ⇒ no
  performance problem while fighting."* With room ③ adjacent and the door burned, **room ①'s water flows into
  the rooster fight.** Water at the chunk cap is **219% of the 20Hz budget** (`water.md`, acceptance 7).
- **It drains east the moment the door burns.** Room ①'s water vessel is bounded on the right by
  **`x160-163`'s own top at `ty26`** (`net_water_rain._MOUTH_X0/_X1` = cells 912/1279 = tiles 114-159).
  Cut a door in that column range and the bowl has a hole in it.
- **Its own acceptance already fails.** "The water carries the player out" lifts them 0px (above).

**What is kept**: `src/sim/water_source.gd` itself, **untouched.** It is the engine room ③'s pour will use,
and the three nets that measure a pour (`net_water_rain`, `net_water_rain_cap`, `net_water_rain_speed`) build
the real pit and run it there.

⚠ **And that is the price, said plainly**: those three nets would then be **measuring a rig, not the game** —
CLAUDE.md's "the label claims more than the check measures". **They must be re-pointed at room ③'s pour the
day it is built**, and until then their labels should say "the pour, measured in the pit's geometry", not
"the game's water". **`net_render`'s six `_room1_reward_water` checks die with the code** and are deleted, not
re-pointed.

**The reward gate itself does not die.** `progress.boss_died(KIND_BULL)` → reward-pending → the rune is
granted is the whole of `rune-lock-and-receiving`; only the **water** hanging off that gate goes. The side
wall collapsing (the visible beat) can stay as a beat with no water behind it — **TBD, that is a screen call.**

---

## Screen

- **The wall the player is looking at while fighting is the wall they are about to burn.** That is the
  feature. The door needs to read as wood **from inside room ①** — today the only wood on the map is judged
  "맵에서 제일 잘 읽히는 물건" (`stage1-map-layout.md`, acceptance 7: brown 3x6 on grey), so the material
  reads; **what is untested is wood set into a stone face rather than standing free on a plateau.**
- **The burn is the payoff shot.** 1,152 cells of wood ignited and gone was measured on screen already
  (`stage1-bosses.md` acceptance 4: 13 cells → 629 two seconds later, "a large orange terrain fire"). A door
  is smaller and will go faster.
- **The rooster is visible through the doorway the moment it opens.** With fork A the two rooms are on one
  floor line, so 「넘어가면 바로 보스가 있어」 is literally a sightline. **Nobody has checked what the camera
  does at that seam.**
- **Room ① no longer floods** ⇒ the navy-vs-stone value problem recorded in `stage1-bosses.md` ("water's navy
  sits too close in value to the underground stone grey") stops being stage 1's problem and becomes room ③'s.

---

## Bounds

| Situation | What must happen |
|---|---|
| **The bull's fire reaches the door** | ⚠ **It does, and this is the feature's biggest risk.** See the box below |
| **A runeless blast opens the door** | ⚠ **It does today.** See the box below |
| **The player walks into room ① with no rune** | **They are not trapped, and they are not trapped today either** — measured: the west boundary is a **2-tile step** at `x129/130` (64px) against a **102px** jump ceiling. Walk in, jump out. **`stage1-map-layout.md`'s "기반암 그릇이고 나가는 길이 물뿐" is false on the baked map** and is corrected there |
| **Wood clumps** | **Exactly 1**, or `net_tables._wood_clumps` goes red and fire can cross between blocks |
| **Room ① does not move** | Keeping `x130-159` where it is keeps the bull's row (`tx145`), the left run, the clumps, the shelves, `net_monster_slam`'s cell pins (cx1040) and the water nets' vessel all untouched. **Only `x160` eastward changes** |
| **The bull stays in its room** | Unchanged — `carve_r`=3 gives a 7-cell hole against the bull's 14-cell box, measured over 196 charges (29 cells removed, all in the first two). **But the east wall is now partly wood, and wood is not what that measurement was taken on** — re-measure |
| ~~⚠ **The bull's charge digs the door**~~ | **False, corrected by spec against the code.** This row said *"`_disc(destroy=true)` skips only `_indestructible` = **bedrock** — wood carves exactly like stone"*. **`WOOD` carries `"indestructible": true`** in `cell_materials.gd`'s own `DEFS` row, whose comment states it outright — *"Blasts cannot dig it · Fire consumes it ⇒ **fire is the only way to remove wood**"*. `_disc`'s destroy branch filters on the baked `_indestructible` array, so **the bull's charge, a blast and the player's carve all skip the door.** ⇒ Acceptance 7b is held by the material table, not by luck — but it stays an acceptance, and it gains a **net on the table row** so deleting `"indestructible"` goes red |
| **Zone ②'s rows** | Deleted. **The boss reserve is derived**, so nothing else moves |
| **④, the locked zone** | **It is not on the baked map.** The only bedrock above the left run is a **2x2 slab at `x49-50`, `y15-16`**, which `left-run-clumps-and-platforms.md` §9 calls "a net fixture that happens to be in the scenery". **This feature does not touch it either way** — and `stage1-map-layout.md`'s ④ section is describing something that no longer exists |
| **The gate** | Moves with room ③ (fork A moves it down 7 rows; a map cut moves it left). `stage_gate.STAGE1_*` are the six constants |

### ⚠ **The bull lights its own door, and this was measured before this doc existed**

`stage1-bosses.md` made this its **acceptance 5**, called it "the biggest risk in this doc", and protected it
with **map shape**: *"It survives in the real map only because Stage C confines the bull to room ① and the
wall sits far enough outside it (the muzzle's reach is measured ~42 cells short of the wall) — a map-shape
fact, not a code guarantee. **If the map ever changes to put the bull within reach of that wall, this
acceptance breaks with no code change at all.**"*

**This feature is that map change.** The numbers:

```
fire bolt range      BOLT_RANGE_PX 480px = 15 tiles     (monster_bolts.gd)
bull start           tx145, room ① is x130-159          => exactly 15 tiles to x160
the bull walks toward the player                        => it closes that distance
slam ground fire     5 points, outermost ±56px from impact, along the floor
verify-run, measured: a bull spawned next to the wood wall burned all 1,152 cells, from either side
```

⇒ **A door in room ①'s east wall is inside the bull's fire, at floor level, during the fight.**
The wall opens before the player wins, and **the GDD's "the midboss reward is the key to progression"
collapses** — the same collapse the wood wall was moved out of room ① to prevent.

**Decided — fork 1**: `docs/decisions/the-door-burns-only-from-the-fire-rune.md`. The door is exempt from
any ignition that isn't the fire rune; the bull's own fire and a runeless blast both pass over it.

| | What | Cost |
|---|---|---|
| **1 · only the fire rune lights it — chosen** | The door is exempt from monster fire | A sixth material or a flag, and `_ignite_cell` learning who lit it — a **`src/sim/` change**. `no-pass-through-platform-material.md` records what a new material costs. **Closes the runeless-blast hole in the same stroke** |
| ~~2 · the sill is above the fire~~ | Door sill 2 tiles up; the player hops 64px through it | Rejected — **not airtight**: a player standing *on* the sill still draws the bolt straight onto the door |
| ~~3 · accept it~~ | The room opens during the fight | Rejected — contradicts the user's own beat |
| ~~4 · the bull's fire stops sticking~~ | — | Rejected — **reverses a user decision** |

**Which of the three `src/sim/` shapes (material, flag, or `_ignite_cell` learning its source) is still the
builder's call** — the outcome is the same regardless. See "Fork 1 is named, not designed" below.

### ⚠ **A runeless blast opens it, and the map's shape stops protecting the lock**

`spell_sim.gd`'s blast passes an ignition radius **regardless of `element`** — the GDD already records this
and files it as **"not a problem"**, for one reason and one reason only:

> *"the wall is on the far side of pit ①, and the only way out of the pit is the water the bull's death
> brings ⇒ you cannot stand in front of that wall without already holding fire. **The lock is held by the
> map's shape, not by the ignition rule.**"*

**This feature deletes that shape.** The door is on the near side of the pit, reachable the moment the player
walks in. ⇒ **A first-ever run can blast the door, skip the bull, skip the rune, and walk to the rooster.**

**That is not the same thing as the GDD's intended skip** ("carrying the fire rune, you can skip the
midboss") — this one needs no rune at all, and the fire rune stops being step 3 of the milestone chain.

---

## Interaction with what exists

| What | How |
|---|---|
| **`src/stage/stage.tscn`'s `Terrain`** | The editing original. **The baked `.gd` is a re-export and is never hand-edited** |
| **`src/stage/terrain_map_generated.gd`** | Rewritten by the bake. `MAP_W`/`MAP_H` come free from `get_used_rect()` |
| **`src/stage/stage1_monsters.gd`** | 12 zone-② rows deleted; the rooster's `tx258` moves with room ③ |
| **`src/actor/stage_gate.gd`** | `STAGE1_SEAT_TILE_X` 270 · `STAGE1_FLOOR_TILE_Y` 25 · `STAGE1_WALL_TILE_X0/X1` 267/268 · `Y0/Y1` 13/24 — **all six move with room ③** |
| **`src/stage/stage.gd`** | `ROOM1_WATER_X0/X1/ROW` (1040/1060/200) and `_room1_reward_water` — **deleted**, per "the water loses its job" |
| **`src/sim/`** | **Untouched under fork 2 or 3.** **Fork 1 changes `_ignite_cell`** and that is the whole reason it is expensive |
| **`net_tables._wood_clumps`** | Measures the baked map directly. **1 clump, and gaps wider than an ignition source** |
| **`net_gate`** | `ROOM3_INTERIOR_X0/X1` 247/266, plus **four more places that spell `267`/`268`/`266`/`269`/`270` as bare literals.** Grep the file for them — naming the lines here would rot on the next edit above them |
| **`net_monster_placement`** | `tx258` and the "room ③ interior 245-266" range |
| **`net_water_rain` · `_cap` · `_speed`** | `_MOUTH_X0/_X1` = 912/1279 in **each of the three files separately** — `left-run-clumps-and-platforms.md` §1 was four sites short on exactly this and says so |
| **`net_render`** | Six `_room1_reward_water` checks, deleted with the code |
| **`net_monster_slam`** | Room ①'s left wall pinned in **cells** (1040/1900/1800), not tiles. **Safe if room ① does not move** |
| **The bull's entrance beat** | [`boss-entrance-and-hp-bar.md`](boss-entrance-and-hp-bar.md) and [`the-back-door-does-not-close.md`](../../decisions/the-back-door-does-not-close.md) picture it as *"you reach the wood wall, turn around, and it is behind you"* — **this feature is what puts a wood wall where the player can stand in front of it.** The two fit; the entrance's own "no door closes behind you" is untouched, and **room ①'s west step staying open is what both rely on** |

### How the map is actually changed — **nobody has to redraw it by hand**

**This is the most important practical line in this doc.** `docs/design/terrain-baking.md` carries two doors
into the terrain and **both are scripted**:

```
bake  →  map_png.gd --to-png     →  a paint tool, 1 pixel = 1 tile   →  map_png.gd --to-map
      →  paint_terrain_from_map.gd  →  bake_terrain.gd  →  the game
```

- **The user redraws only if they want to.** The png round trip exists **because** the editor brush cannot
  show a 300-tile level ("에디터 브러시로는 레벨을 볼 수 없다"), and round-trip losslessness was measured at
  400x48 — **0 differing tiles**.
- **Claude can make the whole edit as text.** `paint_terrain_from_map.gd` stamps an ASCII map into the
  `Terrain` layer; the door is `#`→`=` in four columns, and zone ② is a column deletion — the same operation
  as the 100-column cut, which that doc calls "not a day's work".
- **Traps, all recorded and all silent**: bake without saving the scene and **the old terrain is re-baked,
  no error**; feed an unknown character and it barks and stops (that one is safe); and `get_used_rect()`
  means **deleting columns on the left re-origins the whole bake**. Deleting on the *right* (zone ②) does not.

⇒ **Cutting zone ② is cheaper than the left-run cut was**, because nothing west of the cut moves.

---

## Cost

**Terrain and coordinates. No new sim axis — unless fork 1 is picked, and then it is a `src/sim/` change.**

| | |
|---|---|
| **Terrain** | A door in 4 columns; room ③ moved; ~78 columns cut. **Scripted, not drawn** |
| **Coordinate re-derivation** | ~8 sites (the table above). `left-run-clumps-and-platforms.md` measured this exact job at "ten sites, all mechanical" |
| **Table** | 12 rows deleted, 1 row moved. **No schema change, no reserve change** |
| **Code** | Deleting `_room1_reward_water` and its three constants. **Fork 1 adds a sim change; forks 2-3 add none** |
| **Sim** | **Nothing**, forks 2-3 |
| **Frame cost** | **Goes down.** 12 fewer rows, and **no water in stage 1 at all** — the 219%-of-budget pour disappears from the run |
| **What gets shorter** | The run loses ~78 tiles of walking and 12 mobs that have never woken |

**What this feature does *not* buy back**: the rooster's own water escape is still unbuilt, so **stage 1's
one remaining water scene is still a promise, not code.**

---

## Acceptance

**Write what was seen by eye under this section immediately** (CLAUDE.md).

1. **The wall behind the bull reads as wood while you are fighting** — from inside room ①, at play zoom
2. **Kill the bull, take the rune, and the next thing you do is burn that wall** — no climb, no wait, no walk
3. **The door opens onto the rooster** — 「넘어가면 바로 보스가 있어」. Fork A means a sightline
4. **The bull never opens its own door** — ⚠ **the load-bearing one.** Fight the bull to death with the door
   in reach and the door is still standing. *Driven headless: 200 charges' worth, count the door's cells*
5. **A runeless blast does not open it** — or, if fork 3, the user has looked at the skip and accepted it
6. **You are not trapped in room ①** — walk in with nothing, jump out west. *Driven, not computed*
7. **The bull still cannot leave room ①** — re-measured, because **its east boundary is now partly wood** and
   the 29-cells-over-196-charges figure was taken on stone
7b. **The bull does not dig the door open either** — charge carving ignores material below bedrock.
   *Driven headless: charge the wooden face to exhaustion and check whether a **32px player box** fits through*
8. **Exactly one wood clump on the map** — `net_tables._wood_clumps`, and the old `x164-166` wall is gone
9. **The map has no dead stretch** — walking from the door to the gate passes nothing empty
10. **Stage 1 runs end to end** — the milestone's own single check: the user starts once and reaches the gate

---

## TBD

**Do not force these full** (CLAUDE.md, "skeleton first").

- **Which geometry fork** — A (room ③ comes down to `ty32`) or B (the door is a climb). **[mine] A**, and B
  needs a climbing means the player does not have
- ~~Which fork protects the door from the bull's fire and from a runeless blast~~ — **decided, fork 1**
  (`docs/decisions/the-door-burns-only-from-the-fire-rune.md`). Every other TBD here can be closed while
  building
- **The door's width, height and sill** — the wall is 4 columns thick and 6 tiles tall; the player is
  **1 tile**; the jump ceiling is **102px = 3.19 tiles**. The sill is not cosmetic (fork 2 above)
- **Does the map get shorter, or does zone ② stay as empty columns** — the precedent
  ([cut-the-terrain-not-the-spawn.md](../../decisions/cut-the-terrain-not-the-spawn.md)) cut for real and
  rejected the alternative outright, but that was 100 columns *behind the spawn*, which is not the same
  argument as 78 columns *between two rooms*
- **Whether the side wall still collapses with no water behind it** — the visible beat and the pour are
  separable. A screen call
- **Whether room ①'s pour is deleted or kept** — this doc recommends deleting and prices the other branch.
  **The user has not said.** Note that keeping it puts water into the rooster fight
- **Where room ③'s own pour comes from** — still unbuilt (`stage1-bosses.md`, Risk 13). **After this feature
  it is stage 1's only water**, so it stops being optional
- **What the three water-rain nets measure once the game stops pouring in the pit** — re-point or re-label.
  Leaving them as they are is a fake net
- **The onboarding beat's own text and timing** — 「불 룬을 껴 보세요」. **Owned by `design/tutorial.md`**,
  whose first slice teaches assembling at the *start* of the run; **whether the rune step is a second slice
  or part of the first is that doc's call, not this one's**

### Read this doc back and it cannot be built from — **what is still missing**

**Self-check, run after writing.** Everything above says *what changes*; these are the places an implementer
would have to invent an answer, and inventing is how a design gets decided by whoever happened to type it.

- **No coordinates are proposed for the new room ③.** Fork A says "floor `ty32`, ceiling `ty20`, still 20x12"
  and stops. **Its x span, whether it butts straight onto the door at `x164` or sits behind a short corridor,
  and where the gate seat lands are all unwritten.** A rectangle has to be drawn before anything can be baked
- **Fork 1 is named, not designed.** "The door is exempt from monster fire" could be a sixth material, a
  per-cell flag, or `_ignite_cell` learning a source — **three different sizes of `src/sim/` change**, and
  this doc prices none of them
- **Whether the net re-point is inside this feature or after it.** `net_water_rain*` re-pointing depends on
  room ③'s pour, which is a different doc. **Left inside the same feature it blocks; left out it ships a fake
  net.** Somebody has to choose
- **Nothing is said about what the player sees between "the wall is gone" and "the rooster notices".** The
  rooster is a placed row woken by distance (`WAKE_PX` 720 = 22.5 tiles). With the rooms adjacent it may
  already be awake and walking at the doorway before the wood finishes burning — **unmeasured**
- **The onboarding beat has a seat but no text**, and this feature is where it lands. ~~no owner~~ —
  `design/tutorial.md` owns the concept (its rule #3) and `onboarding-and-palette-tabs.md` (built, `3.done`)
  deferred the beat on purpose. **Nobody has written the line 「불 룬을 껴 보세요」 or said when it fires**

### What this doc is least sure of

- **Nobody has driven room ③ at `ty32`.** Its 20x12 size is pinned by the water scene's cost model
  (`water-jump-and-escape.md`, "Room size is the budget"), which assumed a room that fills. **Moving it down
  7 rows is assumed free and has not been checked** — the ceiling would sit at `ty20`, and nothing was
  measured about the rooster's leap against a room at that depth.
- **"The door reads as a door" is a screen judgment with no precedent.** Every wood judgment so far was on a
  free-standing block against sky, not wood set into a stone face.
- **Whether removing ② makes stage 1 too short** is a play judgment, not a value. The left run was cut once
  already for being too long; **this cuts again, and nobody has walked the result.**

---

# Implementation plan

**Written by spec against the code and the baked map, not against this doc's prose.** Every coordinate below
was read out of `src/stage/terrain_map_generated.gd` with a run-length scan, not copied from the "Why" section.

---

## 0 · The one judgment this plan owes — **which `src/sim/` shape**

The doc named three and priced none: **a sixth material · a per-cell flag · `_ignite_cell` learning its
source.** They are not three alternatives. **All three need the source**, because the bull's fire and the fire
rune go through *the same command* — `world_step.gd`'s bolt-impact line and `spell_sim.gd`'s `_rune_trace`
both call `CellGrid.cmd_ignite(...)`. Nothing in the command distinguishes them. So the real question is only
**how the protected cell is marked**, and the source parameter is common cost.

### Chosen — **`WOOD` gains one column, and `_ignite_cell` gains one argument**

```
cell_materials.DEFS[WOOD]  +  "rune_only": true        (one column, beside "indestructible")
cell_grid._ignite_cell(x, y, src)                      (one argument, threaded through _disc/_blast)
```

**Not a door-only rule — a wood-wide law: only the fire rune lights wood, anywhere.**

| | Sixth material (`DOOR`) | Per-cell `_flag` bit | **`rune_only` on `WOOD`** |
|---|---|---|---|
| Marks the cell | new id in `ALL` | bit 4 of `_flag` | the material it already is |
| Authoring path | new char in `terrain_baker.CHAR_BY_MAT` **and** `NAME_BY_MAT`, re-bake, atlas + tileset rebuild + `--import` — `terrain-baking.md`'s own "adding one material" list, which **has been wrong twice** | **none exists.** `cmd_fill` writes materials; a flag needs a new command and a new baked field | **nothing.** `=` already bakes |
| Survives the sim | yes | **no.** `_write_cell` zeroes `_flag` — and `_burn`'s water-adjacent branch calls `_write_cell(idx, _mat[idx])` every tick a door cell is wet, so **a door that got splashed loses its lock, silently, forever** | yes — `_mat` is the cell |
| `net_tables._wood_clumps` | goes to **0 clumps** — the door is not `WOOD` and the check's contract has to be rewritten | unaffected | unaffected, **and still measures the real door** |
| Cost of the fire-rune rule itself | still needs the source argument | still needs it | needs it |

**And it closes the second hole for free.** `spell_sim.gd`'s blast glyph passes `blast_ignite_r(gen)`
**regardless of `element`** — the runeless-blast skip the GDD files as "not a problem, the map's shape holds
it". Deriving the blast's source from `element` at that one line makes the lock a *rule*, which is exactly what
`the-door-burns-only-from-the-fire-rune.md` decided. `cell_materials.gd`'s `WOOD` comment **already argues for
this in the present tense** — *"one runeless blast ignited 159 cells ⇒ the progression key was never a lock at
all"* — and stopped one step short. This finishes it.

### Why spread needs no source check — **and the invariant that makes that true**

`_burn`'s four `_ignite_cell` calls pass `IGNITE_RUNE_FIRE` unconditionally. Grounds, checked in the table:
**`WOOD` is the only material with `fuel > 0`** (`EMPTY 0 · STONE 0 · BEDROCK 0 · WATER 0`). ⇒ every burning
cell is wood ⇒ every burning cell already passed the rune check ⇒ **spread cannot carry ordinary fire into
wood, because ordinary fire never got in.**

**That argument dies the day a second fuel-bearing material is added.** It is not a comment — it is a check:

> `net_tables` · **every material with `fuel > 0` has `rune_only`.** Two lines. Without it, adding a burnable
> that anything can light lets its spread hand `IGNITE_RUNE_FIRE` to the door.

**A real coverage loss, built in Step ①, recorded here rather than left to be rediscovered**: with `WOOD` the
*only* fuel-bearing material, a monster's own fire bolt (`IGNITE_ANY`) can no longer ignite anything in the
game, at any distance — so the pre-existing precision checks for a monster bolt's own ignition (does it reach
*exactly* `FIRE_IGNITE_R`, does the fuel value settle exactly one tick after `_grid.step()`) became
unmeasurable and were rewritten to assert non-ignition instead (`net_monster_breath`'s
`_fire_ignite_reaches_exactly_its_radius` / `_ignite_settles_after_this_ticks_grid_step`,
`net_monster_slam`'s `_slam_does_not_ignite_wood_at_any_ring_point`) — kept as checks that measure something
real, not a check pretending to measure a radius that can never be reached. **The day a second `fuel > 0`
material without `rune_only` exists, that precision can be measured again** — against *that* material, driven
through a monster bolt exactly as these checks used to be. Until then, `net_tables`'s two-line "every material
with `fuel > 0` has `rune_only`" check is what actually guards this: the day someone adds a burnable material
open to ordinary fire, that check goes red before anyone has to rediscover why the monster-fire radius tests
went quiet.

### The exact shape

```gdscript
# cell_grid.gd — two constants
const IGNITE_ANY := 0        ## monster fire, a blast from a circle that is not fire
const IGNITE_RUNE_FIRE := 1  ## the fire rune's trace, and a blast from a fire circle

_rune_only := Mat.bake_rune_only()          # flat array, mirrors bake_indestructible() exactly

func _ignite_cell(x, y, src) -> bool:
    ...
    if fuel <= 0: return false
    if _rune_only[_mat[i]] == 1 and src != IGNITE_RUNE_FIRE: return false   # <- here, before _water_adjacent
```

`_disc(cx, cy, rd, destroy, src)` · `_blast(cx, cy, rd, ignite_r, src)` · `cmd_ignite(x, y, r, src)` ·
`cmd_blast(x, y, rd, ignite_r, src)` all thread it. **`cmd_ignite`/`cmd_blast` take it with no default** —
`cmd_blast`'s own header already states the reason for its other arguments ("a call site that omits them
silently becomes a blast with no fire"), and this is the same shape.

**The public `ignite(x, y, src := IGNITE_RUNE_FIRE)` keeps its default**, documented as *"the nets' and the
stage's door, and what comes through it is the rune's fire"* — ~40 net call sites use it purely as setup.
**The rule is never measured through that door.** It is measured through `world_step` and `spell_sim`.

**No new `push_error`.** An `src` that is not `IGNITE_RUNE_FIRE` means ordinary, full stop — a bark would need
a matching `t.expect_error` twin (CLAUDE.md) for no gain.

---

## 1 · The geometry, as a rectangle that can be baked

The doc's self-check said *"no coordinates are proposed for the new room ③ · a rectangle has to be drawn"*.
Here it is. **Column and row numbers are tiles.** Read off the baked map:

```
today                                             proposed
x130-159  ty32   room ①, bull tx145               unchanged - nothing west of x160 moves
x160-163  ty26   room ①'s east wall, 6 tall       x160-163  ty19-31  the shared wall, 13 tall
                                                  x160-163  ty30-31  ** the WOOD door ** (4x2 tiles, 512 cells)
x164-166  ty20   the wood wall (free-standing)    gone
x167-244         zone ②, 78 columns               gone
x245-246         room ③ west wall                 gone - room ①'s east wall IS room ③'s west wall
x247-266  ty25   room ③ interior, 20x12           x164-183  floor ty32, ceiling ty19 - 20x12, same size
x267-268  ty13-24 room ③ east wall / gate wall    x184-185  ty20-31
x270      ty25   the gate seat                    x187      ty32
x298-299         right border                     x215-216  => MAP_W 300 -> 217
```

**Room ③ moves down exactly 7 rows and left exactly 83 columns.** Interior rows `13..24` become `20..31`,
ceiling `12` becomes `19`, floor surface `25` becomes `32` — the same floor line as room ①. **Fork A, literally.**

### The door

| | Value | Why |
|---|---|---|
| **Thickness** | **all 4 columns, x160-163** | leave one stone column and the door does not open |
| **Height** | **2 tiles, ty30-31 (64px)** | the player is `H_PX` **32px = 1 tile**. The doc's own "2 tiles reads as a doorway". Rows 19-29 stay stone — the wall still reads as a wall |
| **Sill** | **0 — flush with room ①'s floor** | fork 1 protects the door, so the sill is free to be what the user's 「바로」 asks for. One continuous floor line ty32 through both rooms |
| **Material** | `WOOD`, one connected block, 512 cells | `net_tables._wood_clumps` stays at **exactly 1** |

**The shared wall is now 13 tiles tall, not 6** — room ③'s ceiling has to rest on something, and this is it.
**That is a visible change to room ① and it is verify-look's**: the bull's back wall goes from a 6-tile step
under open cavern to a full 13-tile face with a doorway at its foot.

**If 2 tiles does not read on screen, 3 (ty29-31) is a one-row edit.** Not decided by value; decided by eye.

### Where the rooster stands — **tx175 is wrong, use tx181**

The mechanical shift puts `tx258` at `tx175` (11 tiles from the room's west edge, exactly as today).
**Measured against the camera:** `MATERIALIZE_PX` 720 · `STIR_ENTER_PX` 300 · the camera shows
`480 + CAM_LEAD_PX 72 = 552px`. A player pressed against the door at ~x5110px is **506px** from a rooster at
tx175 ⇒ **the rooster is on screen, standing inside the wall, while you fight the bull.**

At **tx181** that distance is **698px** — outside 552 (never drawn from room ①), inside 720 (it materialises
early, which costs nothing: it does not stir until 300px, i.e. not until the player is through the door).
**Room ③'s east wall is x184, so tx181 leaves 3 tiles of clearance for the boss box.**

**The rooster materialising during the bull fight is new, and it was `boss-entrance-and-hp-bar.md`'s problem
too** — that doc has since shipped (`3.done`); confirm it did not key the entrance beat off materialisation.

---

## 2 · How the map is actually changed — **the user does not redraw**

Answered, because the doc asked and because a wrong answer here blocks on a human.

**Claude writes the whole thing as text.** `terrain-baking.md`'s round trip is scripted end to end:

```
1. read src/stage/terrain_map_generated.gd's MAP (48 strings)   <- the current truth
2. transform it (below) into a plant file, e.g. tools/stage/_stage1_v2.txt
3. Godot_v4.7.1-stable_win64.exe --headless --script tools/stage/paint_terrain_from_map.gd -- <plantfile>
4. Godot_v4.7.1-stable_win64.exe --headless --script tools/stage/bake_terrain.gd
```

The engine binary lives in the repo root (`tests/run_nets.ps1` finds it with `Godot_v*.exe`).
Step 3 **backs the current Terrain up as text first** and **barks and stops on an unknown character**.
Cutting on the **right** is safe — `get_used_rect()` only re-origins when the *left* edge moves, and x0-1 stays.

**No atlas, no tileset, no `--import`** — no material is added.

### The transform, exactly

Build each of the 48 new rows as `west + east`, width 217:

- **west = the old row, columns 0..163, verbatim**, then two overrides on that slice:
  - `x160..163` ← `#` for **rows 19..29**  (today those rows are open air above the wall's ty26 top)
  - `x160..163` ← `=` for **rows 30..31**  (**the door**)
- **east = columns 164..216, written fresh** (do *not* slice-and-shift the old columns — the row move makes
  that wrong in exactly the rows that change):

| rows | x164..183 | x184..185 | x186..214 | x215 | x216 |
|---|---|---|---|---|---|
| 0..18 | `.` | `.` | `.` | `B` | `B` |
| 19 | `#` | `#` | `.` | `B` | `B` |
| 20..31 | `.` | `#` | `.` | `B` | `B` |
| 32..47 | `#` | `#` | `#` | `#` | `B` |

Row 19's ceiling is continuous with the west override (`#` from x160 through x185). Rows 32..47 are the
floor mass that already exists — `#` to x215, `B` at x216, mirroring today's `#…298` + `B299`.

**Sanity, before planting**: every row is 217 characters · exactly one wood clump · row 32 solid from x2 to
x214 · `x187` open from row 0 to row 31 (the arch column, `net_gate`'s roof case).

---

## 3 · Files to touch, and why — one line each

### Sim (stage A)

| File | Why |
|---|---|
| `src/sim/cell_materials.gd` | `"rune_only": true` on `WOOD`; `bake_rune_only()` mirroring `bake_indestructible()` |
| `src/sim/cell_grid.gd` | `IGNITE_ANY`/`IGNITE_RUNE_FIRE`; the `_rune_only` array; `src` through `_ignite_cell`, `_disc`, `_blast`, `cmd_ignite`, `cmd_blast`, `apply`; `_burn`'s spread passes `IGNITE_RUNE_FIRE` with the fuel-table grounds written down |
| `src/sim/spell_sim.gd` | `_rune_trace`'s `cmd_ignite` → rune. `_run_glyph`'s `cmd_blast` → **derived from `element`** via one local static (`ELEM_DEFS[element]["trace"] == TRACE_IGNITE`). This is the runeless-blast fix |
| `src/actor/world_step.gd` | both fire sites — the bolt's terrain impact and the slam's ground fire — pass `IGNITE_ANY` |
| `src/stage/stage.gd` | the debug ignite passes `IGNITE_RUNE_FIRE`; it stands in for the rune |

### Terrain and coordinates (stage B)

| File | Why |
|---|---|
| `src/stage/stage.tscn` `Terrain` | planted by script (§2). The editing original |
| `src/stage/terrain_map_generated.gd` | re-baked. `MAP_W` 300 → **217** comes free from `get_used_rect()` |
| `src/actor/stage_gate.gd` | the six `STAGE1_*`: seat **187** · floor **32** · wall x **184/185** · wall y **20/31** |
| `src/stage/stage1_monsters.gd` | delete the 12 zone-② rows (`tx194`…`tx244`); rooster `tx258` → **`tx181`** (not 175 — §1); rewrite the header paragraph that explains why the zone-② rows are dormant |
| `src/stage/stage.gd` | delete `ROOM1_WATER_X0/X1/ROW`, `_room1_reward_water`, the `WaterSource` preload if it falls unused, the tick call, the reset line and the debug-HUD line |

`src/stage/stage_defs.gd` needs **no edit** — its gate row references `StageGate.STAGE1_*` by name.
`world_step`'s boss reserve needs **no edit** — it is the count of boss rows in the pushed table, derived.

### Nets (stage C)

| File | Why |
|---|---|
| `net_tables.gd` | **two new checks** (fuel ⇒ `rune_only` · `WOOD` is still `indestructible`). `_wood_clumps` unchanged and must still read **1** |
| `net_fire.gd` | new: the rule at grid level — ordinary fire refused on wood, rune fire accepted, spread crosses the whole door once lit |
| `net_spell.gd` | new: **a none-element blast leaves the door standing; a fire blast burns it.** Driven through `SpellSim`, not through `ignite()` |
| `net_monster_breath.gd` · `net_monster_slam.gd` | new: **the bull's bolt fire and its slam fire leave wood untouched.** Driven through `world_step`, the only honest path |
| `net_damage.gd` | its bare `cmd_ignite(wx, wy, 1)` gains a source |
| `net_gate.gd` | `ROOM3_INTERIOR_X0/X1` 247/266 → **164/183**, plus the bare literals — grep the file for `266` `267` `268` `269` `270` and for the camera pair `270`/`284` (→ `187`/`201`, the same +14 offset) |
| `net_monster_placement.gd` | `tx258` → `tx181`; the "room ③ interior 245-266" range → 164-183; the zone-② row count |
| `net_render.gd` | delete the six `_room1_reward_water` checks with the code they measure |
| `net_water_rain.gd` · `_cap.gd` · `_speed.gd` | **coordinates unchanged — labels changed.** See §4 |
| `net_monster_slam.gd` | its room-① cell pins (1040/1800/1900) are **safe** — nothing west of x160 moves. Confirm, do not edit |

---

## 4 · The water — **delete the pour, keep the vessel, fix the labels**

The recommendation is adopted: `_room1_reward_water` and its three constants **go**. The reward gate
(`progress.boss_died(KIND_BULL)` → pending → the rune) is untouched; only the water hanging off it dies.

**And the three water-rain nets need no coordinate change at all.** The doc feared the bowl would leak once a
door is cut in `x160-163`. **It does not**: `WOOD` is `BEHAVIOR_STATIC` ⇒ `is_solid()` ⇒ **an unburned door is
a wall**, and the nets build fresh terrain, where the door is intact. `_PIT_ROW` 208 (tile row 26) and
`_MOUTH_X0/_X1` 912/1279 (tiles 114-159) sit **above and west of** the door; the premises `is_solid(911, 208)`
and `is_solid(1280, 208)` still read stone.

**What is dishonest is the label, and that is what changes.** After this feature **nothing in the game pours
water into that bowl.** Each of the three headers must say so in one line — *what is measured is
`water_source.gd`'s pour, run in room ①'s real vessel; the game itself pours nowhere until room ③'s pour is
built* — and name `water-jump-and-escape.md` as owing it. **Re-pointing the vessel to room ③ is the right move
the day that pour exists, and it is not this feature's** (room ③'s new bowl is watertight — walls x160-163 and
x184-185, floor ty32, ceiling ty19 — so the move will be three constants).

**Whether the side-wall collapse beat stays with no water behind it is a screen call and stays open.** The
plan does not touch it; that collapse is `_room3_gate_open`'s, a different wall.

---

## 5 · Order — what must happen first

1. **Sim rule + its nets, green, and inverted.** Terrain first would ship a door the bull opens. This stage
   changes no coordinate and can be reviewed on its own
2. **Plant + bake the terrain.** One command each. Nothing reads the new numbers yet, so **many nets go red
   here** — that is the expected state, not a failure
3. **Coordinates**: `stage_gate`'s six numbers → `stage1_monsters` rows → the nets in the §3 table
4. **Delete the pour** and `net_render`'s six checks; **re-label the three water-rain headers**
5. **A full round green**, then the driven acceptances (§7), then verify-look

Steps 2 and 3 are one commit. Splitting them checks in a red repo.

---

## 6 · Risk — what this breaks silently

- **A wood-wide rule reverses a shipped acceptance.** `stage1-bosses.md` acceptance 4 measured a bull burning
  all 1,152 cells of the wood wall. **After this it cannot.** CLAUDE.md: *go and edit that doc* — the
  refutation must land there, not only here. Same for the GDD's "the blast ignores element, filed as not a
  problem" row, which this closes
- **`_ignite_cell` is the whole fire system's choke point.** Every ignition in the game goes through it. Get
  the argument threading wrong in one branch of `_disc` and **fire quietly stops happening** — the "screen
  changes but sim doesn't" family. The inversion that catches it is *deleting the `rune_only` line* and
  confirming the monster-fire checks go red, **not** confirming that fire still works
- **`net_water_rain`'s premise reads `is_solid`, so a door made of anything non-solid breaks all three nets at
  once.** If the door is ever changed to a pass-through, re-read §4 first
- **A tuning constant with a floor on one end and none on the other is half-measured** (CLAUDE.md). The door
  is 4×2; assert **both** that all 4 columns are wood (3 wide leaves a stone jamb) **and** that rows 19-29 are
  *not* wood (a 4×13 door is not a door)
- **`world_size()` returns the grid's 4096 cells, not `MAP_W`** — so the camera already clamps 212 tiles east
  of the map today, and after the cut it is 295. **Pre-existing, found while planning, deliberately out of
  scope** (fixing it would move `net_gate`'s camera checks a second time inside one feature)
- **Comments must name docs, never path them.** `net_citations` greps `src/`, `tests/` and `tools/` for
  `docs/plans/[0-9]` and fails. Every comment written in this feature is subject to it
- **Bake without saving the scene and the old terrain is re-baked with no error.** The plant script writes the
  scene file directly, so this only bites if someone opens the editor mid-way

---

## 7 · Acceptance — what is looked at

**Driven headless** (this feature's own nets):

1. **Ordinary fire never opens the door.** Through `world_step`: the bull's bolt impact and its slam ground
   fire, both aimed at the door's cells, leave **512 wood cells standing**. Inverted by deleting the
   `rune_only` line ⇒ red
2. **A runeless blast never opens it.** Through `SpellSim` with `ELEM_NONE`, at the door, at the generation-0
   radius ⇒ 512 standing. With the fire rune ⇒ it lights and **spread takes the whole door**
3. **The bull's charge cannot dig it.** 200 charges into the wooden face, then a **32px-tall × 20px-wide
   player box** swept along ty30-31 finds no gap. (Held by `"indestructible"`, which now has its own check)
4. **Exactly one wood clump**, 4 columns × 2 rows, and rows 19-29 of those columns are stone
5. **Room ① is not a trap, with coordinates**: rows 30 and 31 are solid at every `x <= 129`, so the west step
   is **exactly 64px** against a 102px jump ceiling. Driven, not computed from this sentence
6. **The rooster is not drawn during the bull fight**: from every standable cell in room ①, centre-to-centre
   distance to `tx181` exceeds **552px**
7. **The gate still works**: `net_gate`'s whole Stage A/B at the new numbers, with the arch column x187 open
   from row 0 to row 31

**Looked at by eye** (verify-look) — the doc's own list 1, 2, 3, 9, 10, plus:

8. **The 13-tile shared wall reads as the back of the boss room**, and the 2-tile door reads as a door in it
9. **The burn**: 512 cells is under half the old wall's 1,152 — confirm it still reads as "a large orange
   terrain fire" and not a pop

**Every new check gets inverted, and the inversion must be confirmed to have landed** — string replacement has
silently matched zero times twice in this repo. **Invert the instrument too**: for check 1, make the check
itself pass a source the game never passes there, and confirm the check goes red.

---

## 8 · Out of scope — **do not expand into these**

- **Room ③'s own water pour.** Still unbuilt, still `water-jump-and-escape.md`'s. This feature leaves stage 1
  with **no water at all**, and that is the honest statement to carry forward
- **Re-pointing the three water-rain nets' vessel to room ③.** Labels only, this round (§4)
- **The onboarding line 「불 룬을 껴 보세요」 and its timing.** `design/tutorial.md` owns it
- **The side wall's collapse beat.** A screen call, still open in TBD
- **`world_size()` deriving from `MAP_W`.** Found here, recorded above, not fixed here
- **The boss entrance beat / HP bar.** `boss-entrance-and-hp-bar.md` (built, `3.done`) — this feature only
  handed it the new fact that the rooster materialises during the bull fight
- **Making the door 3 tiles tall.** A one-row edit if verify-look asks; not decided in advance

---

## 9 · For the user — **nothing blocks the start**

The build can begin on §5 step 1 immediately, and **the user does not have to redraw the map** (§2). Three
things want a look, in order of how expensive they are to get wrong:

1. **The door is 2 tiles tall (64px) at floor level, and the shared wall grows from 6 tiles to 13.** Room ①
   looks different while you fight the bull. Cheap to change after seeing it
2. **The rooster moves to the far end of room ③ (`tx181`), not the middle** — so it is not on screen through
   the wall. It costs a 17-tile sightline instead of a point-blank reveal
3. **Wood becomes rune-only everywhere, not only at the door.** The bull can no longer set any wood alight
   anywhere in the game. Stronger than the decision asked for, and the reason is that it needs no new material
