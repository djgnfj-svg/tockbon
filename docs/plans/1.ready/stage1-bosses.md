# Stage 1's two bosses — the bull that swallowed fire, and the giant rooster

**Status**: ready
**One line**: the midboss **bull** charges, rams and breathes fire. The stage boss **giant rooster**
leaps and pounces. Both **speed up at half health.**

**Map placement** is in [stage1-map-layout.md](../3.done/stage1-map-layout.md), **the water escape** in
[water-jump-and-escape.md](../2.active/water-jump-and-escape.md). **The three constrain each other** — see "Interaction".

**Source docs**: `docs/design/monsters.md` (trash-mob rules and the AI slot) ·
`docs/GDD.md` "Inside a stage — the zone loop" (midboss reward = progression key)

---

## Why

**Stage 1 doesn't roll without this.** The monster table holds **only pig and chicken** (`monster_defs.DEFS`),
and the map doc records ① and ③ as **"empty rooms".**

And **the midboss is the center of the GDD's design** — not "a place to get stronger" but
**"a place you can't pass without it".** Kill the bull, get the fire rune, burn the wood wall, open the path.

**The bull was already decided** — `docs/design/monsters.md` recorded "the midboss is a **bull.**
Small livestock foreshadows large" and that was part of why the pig was chosen as a trash mob.
**This doc fills in that bull's behavior.**

### Start from knowing there is no AI

`_next_axis()` in `monster.gd` is **one line, "toward the player".**
The monster doc isolated that function with **"AI is deferred; the slot is left open".**

⇒ **The boss is the first real code to enter that slot.** Built as "a big pig", it isn't a boss.
**Still, do not build general AI** — build only these two bosses' patterns. There is still no pathfinding.

---

## Behavior

### Midboss — the bull (①, the pit)

| What | How |
|---|---|
| **Charge** | **Runs straight at the player and rams** |
| **Ramming digs** | **Terrain destruction only while charging.** The impact point is carved |
| **Ramming stuns it** | Hitting a wall **briefly stuns it** — **that is the window to hit back** |
| **Breathes fire** | **It sticks to terrain.** Wood burns |
| **Phases** | **Speeds up at half health.** Faster charges or more frequent fire |
| **On death** | **You take the reward, and then the side wall collapses and water comes in** (decided by the user) |

#### The charge is not one move — it is a family (decided by the user)

**One charge is not a fight.** The user split it into variants that share the same tell and differ in what
they ask of the player:

| Pattern | What | Art |
|---|---|---|
| **Triple charge** | Three charges back to back, no pause between | **`bull_charge` replayed 3×** — no new sheet |
| **Sweeping charge** | Charges, turns, charges back — left and right | **`bull_charge` mirrored** — no new sheet |
| **Jump slam** | Leaps and slams both front hooves down; **the impact throws fire outward across the ground** | **`bull_slam`, 17 frames** |
| **Gore** | The close-range answer — **when you are next to it, it swings its horns** | **`bull_gore`, 17 frames** |

**Two of the four need no art at all.** Repetition and mirroring are code, and spending generations on them
would produce a second, slightly different charge — **the tell would stop being one thing the player can learn.**

**The jump slam is the one that changes the room.** Fire that spreads along the ground is the bull's fire
under a new delivery, so **every constraint in "the bull's fire sticks to terrain" applies to it unchanged** —
including the wood wall. **A slam near the wall is the same failure as a breath near the wall.**

**Gore exists because a charge has a dead zone.** Standing under the bull's nose beats a move that needs
runway, and without an answer the fight's lesson becomes "hug it".

**Frame count is 17 (16 generated + the input frame), deliberately** — the user asked for as many frames
as possible on these two. The others sit at 5–9.

#### The way out of the pit — **this doc owns it** (decided by the user)

**The pit is a bedrock bowl whose only exit is rising water** (`3.done/stage1-map-layout`), and until this
decision **no doc owned the water** — the map asserted it, this doc said "there is no water in ①", and
`2.active/water-jump-and-escape` scoped only the pour after the rooster. **It came out of the F key.**

**The same shape as the rooster's**: the wall collapses and water pours in from the side.
**One thing differs and it is load-bearing — the order.** Death alone does not open it;
**the reward is taken first, then the wall goes.** With one rune slot and no stash, the fire rune has to be
received before the room starts filling, or the player is choosing a layer while drowning.

⇒ **The trigger is "the reward closed", not "hp reached 0".**

**"Terrain having held the water back" is the reason it reads as natural** rather than as a scripted flood —
the same argument already made for the rooster's wall, and **the hole size tunes the pour rate** the same way.

**And it settles `water-jump-and-escape`'s open item 1** — that doc's acceptance 5 ("water comes in from
the side") did not match approach A, which rains across the full width from above. **This pour is genuinely
from the side.** Whether the two pours share one implementation is that doc's call, not this one's.

**"Ram and get stunned" is the whole of this boss.** Brainless charging becomes its own weakness —
the player **dodges, makes the bull ram, and hits in that gap.** A fight works without making the AI smart.

**Destruction is bound to an attack pattern.** Not "breaks what blocks it while walking" but **only while charging**,
so the player **can predict it.** And the room's shape changes as you fight.

#### The fire is not on the body — the **rune** is (decided by the user)

The first sprite breathed a flame at the nose **all the time.** The user cut it: **fire appears only while the
pattern is running**, and what the body carries is **the swallowed fire rune, burning under the hide.**

**Two things are bought at once.**
The GDD's "**bosses swallowed almost all of it**" ("World") stops being a line in a doc and becomes
**visible on the beast** — the player sees what they are about to be given before they win it.
And **the telegraph gets its channel back**: with flame on the face permanently, the wind-up before a fire
breath has nothing to say. Fire appearing *is* the tell.

⇒ **The idle sprite carries no flame.** Every flame on screen belongs to a pattern that is currently running.

**What actually shipped is only the removal.** The user kept the bull they had already picked and had the
nose flame **erased from it** (60 pixels, cut by "red dominates" — the beast is grey, so no body pixel is
near that hue), rather than take one of the regenerated candidates that wore the rune on its shoulder.
**So the rune is not on the body yet.** The candidates sit in `tools/pixel/out/boss_bull_rune` and
`boss_bull_red` — **regenerating is not needed if one of those is picked later.**

#### The bull's fire sticks to terrain — and that constrains the map

**Decided by the user.** "It doesn't stick (it only hits the player)" was an option, and
**the side that preserves the GDD thesis "the world reacts"** was chosen.

**The price lands on the map.** The **wood wall** on the path from ① to ② is the progression key,
and if the bull's fire reaches it, **the wall burns on its own before the player gets the fire rune.**
⇒ The GDD's "the midboss reward is the key to progression" collapses entirely.

**⇒ Move the wood wall outside room ①** (user decision). The map doc reflects this.

**"Is the wood connected" matters more than distance** — fire spreads **through wood.**
With **not one cell of wood** between room ① and the wood wall, no amount of fire reaches it.
`net_tables._wood_clumps` already measures "are the gaps wider than an ignition source".

**Put no wood inside room ①.** With wood there, the whole room burns and there is no fight.

### Stage boss — the giant rooster (③, a 20×12-tile room)

| What | How |
|---|---|
| **Leaps** | **Leaps with its wings and pounces.** **It lands — it does not stay airborne** |
| **Pounce telegraph** | A wind-up before leaping is required (it must be dodgeable) |
| **Phases** | **Speeds up at half health** |
| **On death** | **The side wall collapses and water comes in** → [water-jump-and-escape.md](../2.active/water-jump-and-escape.md) |

**Why not "permanently airborne"**: `docs/design/monsters.md` **deliberately dropped flyers** —
only 2/17 glyphs run and **there is no homing, so only manual aiming exists.** Permanently airborne makes
**"annoying", not "threatening".** ⇒ **The landing is the window to hit**, the same grammar as the bull's stun.

**The order fits** — pig (trash) → bull (midboss) → king of chickens (boss). Two trash mobs foreshadow two bosses.

---

## Screen

- **Bull** — charge telegraph · dust on impact · a stun indicator (**you must know it's time to hit**) · the fire it breathes
- **Rooster** — leap telegraph · landing impact
- **Both** health bars · flash · damage numbers · fire on the body — **same family as trash mobs** (already exists)
- **The standing sprites exist** — `assets/monster/bull_body.png` (86×54) · `rooster_body.png` (72×80), local ComfyUI.
  **The 4× generation rule held at this size too** (bull 384×256 → 96, rooster 288×336 → 72).
  **Every pattern in this doc now has a sheet** (`assets/monster/`, one horizontal row each):

  | Bull | Rooster |
  |---|---|
  | `bull_idle` 5 · `bull_walk` 9 · `bull_charge` 9 | `rooster_idle` 5 · `rooster_walk` 9 |
  | `bull_stun` 7 · `bull_fire` 9 · `bull_death` 7 | `rooster_leap` 9 · `rooster_land` 7 · `rooster_death` 7 |

  Generated by **pixellab** from the standing frame (**1 generation each**), since the local pipeline's walk
  LoRA is for human characters only. **The input had to be quantized to 16–32 colors first** — the MCP client
  truncates a base64 argument past roughly 3,000 characters and the call fails with "could not decode image".
  **The trash mobs got walks in the same pass** — `pig_walk` 9 · `chicken_walk` 9.
  **What is still not drawn**: the phase change at half health, and being hit (the hit flash shader covers it today)
- **The walk sheet has no way onto the screen yet.** `fx_tuning.MONSTER_SHEETS` is **one image per kind** and
  `monster_view` fits that whole texture to the box — hand it a 9-frame sheet and the beast draws squashed.
  Playing it needs the character's idiom (`CHAR_SHEET` + a state→frame table) brought over to monsters,
  which is **`docs/design/monsters.md` open question 16**, not this doc's
- **There is no outline** — impossible in principle for trash mobs, so a shader was used. **Same for bosses**

---

## Boundary

| | |
|---|---|
| **Still no pathfinding** | Bosses are brainless-forward at base. Patterns go on top |
| **No wood inside room ①** | The bull's fire burning the room means no fight |
| **The wood wall is outside ①** | It must be out of the bull's fire's reach for the progression key to survive |
| **Destruction only while charging** | Not "breaks what blocks it" — terrain trapping still works on trash mobs |
| **The rooster lands** | Permanently airborne is unkillable with no homing glyph |
| **Water only after a boss dies — now both of them** | ① after the bull's reward, ③ after the rooster. **Neither overlaps its fight** ⇒ no performance problem while fighting |
| **Bolts have no owner** | Putting the bull's fire or the rooster's attacks into `spell_sim` means **they hit themselves.** Like chicken bolts, they go in `src/actor/` |

---

## Interaction with what exists

**This doc cannot stand alone. Three constrain each other.**

```
stage1-bosses          the bull's fire sticks to terrain
      ↓ constrains
stage1-map-layout      ⇒ wood wall outside ①.  No wood in room ①.  Boss room 20×12
      ↓ constrains
water-jump-and-escape  ⇒ 20×12 = 15,360 cells.  The side wall collapses and water comes
```

| What | How |
|---|---|
| **Fire** | The bull's fire goes through `_ignite_cell`. It must fit within `MAX_BURNING` |
| **Water** | **Fire doesn't catch next to water** (`_deep_water`). **Room ① now floods too** — but only after the fight ends, so it costs the fight nothing. **The bull's leftover fire goes out as it fills**, and that is the correct picture |
| **Terrain destruction** | Charge destruction wakes chunks. Same path as a blast's `carve` |
| **Trash mobs** | Reuses the same `monster.gd`. **The `_next_axis()` isolation earns its keep here** |
| **The 20-mob cap** | A boss is 1. **Whether trash mobs appear during a boss fight is TBD** |
| **Damage · invulnerability · knockdown** | `character-damage-minimum` is the source. Bosses reuse it |

---

## Cost

**The boss itself is cheap — it's one.** What's expensive is **what comes with it.**

| What | Cost |
|---|---|
| Boss movement and checks | 1 mob. The 20-mob estimate was ~5,000μs, so negligible |
| **The bull's fire** | A terrain fire. Measured max fire at 16,384 cells is **33% of the 20Hz budget** |
| **Charge destruction** | Wakes chunks. Same place as blasts |
| **Water (post-rooster)** | **Outside the fight** — water costs 0 while fighting. 20×12 = 15,360 cells |

**One thing is unanswered** — the first TBD in `docs/design/monsters.md`:
**"do monsters run on the 20Hz tick or the 60Hz frame".** 30% vs 10% of budget splits on that alone.
**The implementation plan answers it first.**

---

## Acceptance

**Write what was seen by eye under this section immediately** (CLAUDE.md).

**Bull**
1. **It charges and rams** — running in a straight line
2. **The impact point is carved** — and **only while charging** (not when blocked while walking)
3. **Ramming stops it briefly** — **and it's visible that this is the window**
4. **It breathes fire and that fire sticks to terrain**
5. **That fire does not reach the wood wall** — **the biggest risk in this doc.**
   A wall that opens on its own kills the progression key
6. **Room ① does not burn entirely** — there is no wood in the room
7. **It speeds up at half health** — distinguishable by eye
8. **The bull doesn't break out of the room** — charge destruction could accumulate and breach a wall
8b. **The reward is taken, and only then the side wall collapses and water comes in** — and
   **the water carries the player out of the pit.** Reversing the order (water first, reward second) is the failure

**Rooster**
9. **It leaps, pounces and lands** — it doesn't stay airborne
10. **It can be hit at the moment of landing**
11. **The telegraph is visible** — it can be dodged
12. **It speeds up at half health**
13. **On death the side wall collapses and water comes in**

**Both**
14. **They can be killed with manual aim** — there is no homing glyph
15. **They don't hit themselves with their own attacks** — bolts have no owner

---

## TBD

**Do not force these full.**

- **How the fire rune is received** (the user left this open) —
  auto-equipped · dropped and picked up and assembled · the corpse burns and you pick it out of that.
  **The GDD pushed assembly to "safe moments"**, and auto-equipping shakes that discipline.
  **The assembly window is a debug label right now, so this decision is tied to that**
- **Health · damage · speed values** — none decided. "Skeleton first", set on screen
- **Box size** — how much larger than a pig (44×32) is a bull. **Size is not free**
  (`character.gd`: a bigger box sweeps cells quadratically).
  **The sprites came out at 86×54 (bull) and 72×80 (rooster)** — that is the art's size, **not a decided box.**
  Deciding the box smaller than the art means regenerating, not scaling (downscaling breaks the pixels)
- **How it breathes fire** — cone · projectile · range · telegraph
- **How many seconds the stun lasts** — the fight's rhythm comes from here
- **How deep charge destruction goes** — accumulated, it breaches the room
- **Does the rooster break terrain on landing** — same axis as the bull, undecided
- **Do trash mobs appear during a boss fight**
- **Boss reward** (rooster) — the GDD says "research material (permanent) + a glyph three-pick". **The three-pick screen doesn't exist yet**
- ~~**Sprites**~~ → **generated and picked by the user.**
  `assets/monster/bull_body.png` (86×54) · `assets/monster/rooster_body.png` (72×80).
  Local ComfyUI, `--preset monster`, generated at 4× and downscaled — same path as the trash mobs.
  **The rooster took two rounds** — the first came out as a farm rooster and the user said "more like a boss";
  what was picked is the **grey monstrous** one, not the red-plumed demon of the third round.
  **Only the standing pose exists.** Charge, stun, leap and landing frames are not drawn
- **Phase transition presentation** — what is visible at half health

---

## Decided — from the design conversation

| What | Value | Why |
|---|---|---|
| Midboss | **Bull** | Already decided earlier. The pig foreshadows it |
| Bull behavior | **Charge+stun · fire breath · terrain destruction**, all three | Brainless charging becomes its own weakness |
| Bull destruction | **Only while charging** | Bound to an attack pattern and predictable. "Breaks what blocks it" would kill trapping entirely |
| Bull's fire | **Sticks to terrain** | Preserves "the world reacts". ⇒ **wood wall outside the room** |
| Stage boss | **Giant rooster** | pig → bull → king of chickens. Two trash mobs foreshadow two bosses |
| Rooster's flight | **Only while leaping. It lands** | With no homing glyph, permanently airborne is unkillable |
| Phases | **Two — speeds up at half health** | |
| Boss room | **20×12 tiles** | The water escape's performance is set here (15,360 cells). Enlarge it and water slows |
| Water source | **The side wall collapses** | Terrain having held the water back is natural, and **the hole size tunes the pour rate** |
