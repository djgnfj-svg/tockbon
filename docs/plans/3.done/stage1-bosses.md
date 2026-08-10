# Stage 1's two bosses — the bull that swallowed fire, and the giant rooster

**Status**: done — **implementation finished, stages A–I all written and verified headless** (Risks 1–13,
this doc's own record). **"Done" means implementation, not acceptance** (CLAUDE.md) — see the three lists
right below before reading this as more settled than it is.

> ## ⚠⚠ **The wood wall comes back *into* room ① — acceptance 5's protection is deleted** (decided by the user)
>
> **Room ①'s east wall becomes the wood door.** Kill the bull, take the fire rune, burn the wall you are
> standing in front of. ⇒ [`burn-out-of-the-bull-room.md`](burn-out-of-the-bull-room.md) (built) ·
> [`decisions/the-rune-is-used-where-it-is-won.md`](../../decisions/the-rune-is-used-where-it-is-won.md)
>
> **What in this doc stops being true:**
>
> - **"⇒ Move the wood wall outside room ①" (the Risk-4/Risk-8 fork, and the summary row "The wood wall is
>   outside ①") is reversed.** The wall comes back in. **The fire sticking to terrain is untouched.**
> - **Acceptance 5 ("that fire does not reach the wood wall") loses its grounds.** This doc already wrote why:
>   it survives *"only because Stage C confines the bull to room ① and the wall sits far enough outside it …
>   **If the map ever changes to put the bull within reach of that wall, this acceptance breaks with no code
>   change at all.**"* **That map change is this one.** Measured here (before the fix): a bull next to the
>   wood burned all 1,152 cells from either side; `BOLT_RANGE_PX` 480 = 15 tiles, and tx145 → x160 is
>   **exactly 15**. ⇒ **A protection fork must land or the decision reverses** — the four forks are in the
>   plan doc's Bounds. **Fork 1 landed** (`burn-out-of-the-bull-room.md` §0, built) — see the `rune_only`
>   bullet below for the measurement re-taken after it.
> - **Risk 4's "no fuel in room ①, so the sticking is unobservable there" ends, and so does the sticking
>   itself.** There is wood in room ① now, but it is `rune_only`
>   (`burn-out-of-the-bull-room.md` §0, built) — **the bull's own fire, and any blast that is not a fire
>   circle, no longer ignites it at all.** This is stronger than "the map keeps them apart" (the fork this doc
>   priced) — it is a rule, not a distance. **Acceptance 4's own measurement below ("the bull burned in its
>   own fire on screen, 300 → 280") still holds** — that is a monster taking *segment/blast damage* from its
>   own bolt, unrelated to whether the bolt's terrain-ignition can catch wood — but **"a bull next to the wood
>   burned all 1,152 cells, from either side" (this box's own next bullet, and Risk 4's original measurement)
>   is reversed: driven again after the fix, a bull built beside a `rune_only` wall left it fully intact,
>   every time, from either side. `net_monster_breath`/`net_monster_slam` hold this now, inverted and
>   confirmed red on the old behavior.**
> - **Stage I's `_room1_reward_water` loses its job.** The escape it poured for is dropped; whether the pour
>   itself is deleted is the plan doc's TBD. **The reward gate (`boss_died` → rune) is untouched.**
> - **Risk 13's "zone ② is unreachable until the water escape lands"** — ② is deleted instead
>   ([`decisions/no-trash-run-between-the-two-bosses.md`](../../decisions/no-trash-run-between-the-two-bosses.md)).
> - **Room ③ may move down 7 rows** (the plan's geometry fork A). **Nobody has driven the rooster at `ty32`.**
>
> Everything else in this doc — both bosses' patterns, phases, and every measurement — is unaffected.

**Not accepted.** Nothing in this doc has the user's own `Accepted` mark yet. Two screen fixes (Risk 11's fire
ring, Risk 12's phase-2 tell shape) are **unlooked-at** — correct by the numbers, blocked from a screen
re-check by another session holding the editor bridge, neither passed nor failed. The rooster's art (reads
closer to a gargoyle than a rooster) and the windup "!" size are open questions sitting with the user.

**Out of scope by design, not by oversight.** The rune-card reward itself (milestone step 3 — the three-pick
window still can't carry anything but a glyph, Stage I's own "honest gap"). Room ③'s automatic water pour
(the gate is generic and already answers correctly for the rooster; no pour is wired to it — Risk 13). "The
fire sticks to terrain" is unobservable in room ① by design (no fuel there — Risk 4). And **acceptance 8b's
"the water carries the player out of the pit" is false on this map** — 300s of pouring lifts the player 0px,
and one ordinary jump already clears the left step in 1.6s with no water at all (Risk 13-addendum) — the
mechanism and the order are both correct; the map is `stage1-map-layout.md`'s call, not this doc's.

**Open tuning items, with the numbers already measured.** Phase 2 halves the windup telegraph (0.85s → ~0.4s)
right when the boss gets more dangerous — not touched, tied to the "!" size question above (Risk 12). The
slam's own reach (+80px) rarely finds a moving player — barely changes the fight (36.5s vs. the pre-fix
37.5s; retreating stays 26.1s) — a tuning item, not a defect (Risk 11). The gore gate (120px) doesn't match
gore's own real reach (54px), a ~66px dead band a fresh bull can whiff into (Risk 8-addendum).

**One line**: the midboss **bull** charges, rams and breathes fire. The stage boss **giant rooster**
leaps and pounces. Both **speed up at half health.**

**Map placement** is in [stage1-map-layout.md](stage1-map-layout.md), **the water escape** in
[water-jump-and-escape.md](../2.active/water-jump-and-escape.md). **The three constrain each other** — see "Interaction".

> ## ⚠ **Two of this doc's own constraints are reversed by the map** (decided by the user)
>
> **Room ①'s east wall becomes wood** and the player burns out of the room with the rune they just won ⇒
> [`burn-out-of-the-bull-room.md`](burn-out-of-the-bull-room.md) (built) ·
> [`decisions/the-rune-is-used-where-it-is-won.md`](../../decisions/the-rune-is-used-where-it-is-won.md)
>
> | This doc says | What happens |
> |---|---|
> | **"Move the wood wall outside room ①"** · **Boundary: "the wood wall is outside ①"** | **Reversed.** The wall comes back in, as the room's own east face |
> | **Acceptance 5** — "that fire does not reach the wood wall", *the biggest risk in this doc* | ⚠ **It will reach it.** Bolt range is **480px = 15 tiles**; the room is 30 tiles and the bull starts 15 from the east wall **and walks toward the player.** This doc already measured the outcome: a bull next to the wood **burned all 1,152 cells, from either side** (Risk 4). **Which lever protects the door is unpicked** — that feature's own blocking TBD |
> | **Acceptance 8b** — "the reward is taken, then water, and the water carries the player out" | **The escape half is dropped.** The **order** (reward, then the wall) is untouched; **whether the pour survives at all** is that feature's TBD, and this doc's own Risk 13-addendum already measured the escape as false (0px in 300s) |
> | **Boundary: "water only after a boss dies — neither overlaps its fight"** | ⚠ **At risk.** With room ③ adjacent and the door burned, room ①'s water can flow into the rooster fight. That is the strongest argument for deleting the pour |
>
> **"No wood inside room ①" is not reversed by anything measured here** — it was written because *wood in the
> room means the room burns and there is no fight.* **A door in the wall is still wood the bull can light.**

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
so the player **can predict it.** ~~And the room's shape changes as you fight.~~ **Measured false at
`carve_r`=3 (Stage C's implementation plan, Risk 3 addendum): it changes once, at the first ram into a given
spot, and never again** — the bull's own box is taller than the hole one impact digs, so it can never step
into what it just carved to dig further. See that Risk for the exact numbers.

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

**verify-look's observation, stages A–E, on the real map — not the user's acceptance.** Only the user writes
`Accepted`; this is what the agent saw on screen, recorded so the next session does not re-measure it blind.

- **Acceptance 1** — windup freeze, straight run, rams the left staircase, player 100 → 60. Charge contact
  damage is visibly real.
- **Acceptance 2** — the crater is visible at 3× zoom and confirmed by value (rows 246–252 eaten to a max of
  4 cells at row 249, a symmetric round bite, 28px tall × 16px deep — smaller than one 32px tile). **It does
  not read as broken** — the bite is clearly a bite, and it appears exactly where the bull hit, so the
  causality reads. **But the design's "the room's shape changes as you fight" is not what is on screen**: one
  half-tile nick and then nothing (Risk 3-addendum's own finding — `carve_r`=3 does not accumulate). It reads
  as "it leaves a mark", not "a breakable wall" — a player will notice quickly that ramming the same spot
  again does nothing.
- **Acceptance 3, split.** **The stun ring reads well** — a bright pulsing cyan circle, legible against the
  grey bull and inside a fire sea; staying far from the reds on the color wheel paid off, and it does not
  collide with the green hp bar. **The windup "!" is weak** — sharp at 2.5× zoom, but at play scale (1.0) it
  reads as a small orange dot, easy to miss and further buried by the debug HUD text. ⇒ **"when to hit" reads
  clearly; "when to dodge" does not** — the window's closing is more visible than its opening. **Not acted on
  yet** — the user has been asked about the "!" size; wait for the answer before touching it.
- **Acceptance 4** — measured on painted wood (the T key's own door): ignition at 13 cells grew to 629 cells
  two seconds later, a large orange terrain fire spreading through the block. Bolt color is unmistakably the
  ground-fire family, nothing like the hen's green. **And the bull burned in its own fire on screen, 300 →
  280** — the Risk 4 decision (kept, not exempted) is visible exactly as written.
- **The bull's art at 88×56 shows no sign of the padding** — no clipping, no jump when it turns around (both
  facings checked), the outline shader is fine.
- **A real gap, found here, not dropped work**: the design doc's list above names "dust on impact" for the
  bull. There is no `dust` anywhere in `src/` — no stage scheduled it. **Recorded as unbuilt, not missing** —
  and it would likely have covered the weak windup telegraph too, so it is worth folding into whatever fixes
  acceptance 3's split above.

**verify-look's observation, stages F–I, on the real map — not the user's acceptance.** Two fixes already
folded back into Risk 11 (fire ring) and the phase-2 tell (Risk 12) — this section is what was seen, not a
duplicate of what changed.

- **Acceptance 8b's order reads cleanly from the HUD alone** — 3 seconds of `방① 보상 대기 중 (L로 수령)` ·
  `물 0칸`, then a real injected L key flips it to `수령함` · `물 1320칸`. The pour itself is worth
  looking at: it comes in from the left side, forms a big navy mass with a stepped slope running right (reads
  as still moving, not a static puddle), and a thin tongue creeps along the floor ahead of the mass.
- **Phase 2's tell (before the bracket fix) was unmissable at 1.0 zoom** — same visibility class as the stun
  ring, and circle-vs-square kept the two apart on sight (before the shape itself was found to read as a
  selection box — see Risk 12's own fix). **Phase 2 also reads as faster by eye, not just by the numbers**:
  two bulls released simultaneously, the phase-2 one started 120px behind and was 178px ahead 1.15 seconds
  later.
- **The slam's fire ring (before the spread-cells fix) read as "the bull is standing on a small fire", not
  "the impact threw fire outward"** — the burning band was narrower than the bull's own torso and mostly
  hidden behind the sprite, confirming Risk 11's own ±32px-vs-44px arithmetic by eye, not just by the number.
- **The rooster's leap reads as a hop, and height is not the cause** — the gap under its feet at the apex is
  clearly half its own body height, so the apex/travel ratios (Risk 11's own fix list) are fine on screen.
  **The pose never changes.** It is the standing idle sprite carried upward — wings already spread while
  standing, so nothing in the art signals "it pushed off the ground". It reads as "a standing bird was moved
  upward" rather than "it leapt". **Not this stage's defect** — the fix is `rooster_leap` (9 frames, already
  generated, unused, `monsters.md` open question 16, explicitly out of scope for this doc). Recorded as "how
  it reads until animation lands."
- **Water's navy sits too close in value to the underground stone grey** — the boundary between them is
  nearly invisible where the pool meets the pit wall, though the same water reads fine against the sky
  further up. **Nothing responds when water touches the character** — no splash, no ripple. Both are
  presentation notes for whoever next reopens the water work, not this doc's fix.
- **A trap for whoever verifies on screen next, not a finding about this stage**: moving `Camera2D.
  global_position` while the game is frozen and screenshotting **without stepping a frame** leaves
  `SkyBackground` behind the moved camera, producing dark-grey seams that read as broken terrain but are only
  a stale background layer. Step one frame after moving the camera, before the screenshot. **Recorded here
  because this doc is where it was found — belongs in verify-look's own observation-trap list
  (`.claude/agents/verify-look.md`), not permanently in this feature doc.**

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
15. **They cannot be hit by their own bolts** — bolts have no owner. **Narrowed on purpose (Stage D, verify-run's
    finding): this is about bolt collision only.** A monster standing in its own terrain fire is a different
    channel entirely (`monster._burn`) and is *not* exempt — see the "Decided" table below

---

## Implementation plan

**Every number below is provisional and set on screen** (the doc's own "skeleton first"). What is *not*
provisional is the structure, the order, and the five findings under "Risk" — those were measured.

**Net baseline before any of this starts** (measured, full round 15.6s): **3,514 pass · 3 fail**, all three
inside `net_water_rain` (`그 왼쪽은 벽이다` · `그 오른쪽도 막혀 있다` · `물 총량`). They were **already red** —
`stage1-map-layout` predicted them when the bedrock bowl was replaced by walk-in stairs. **Do not read them
as damage from this work, and do not fix them here.**

### The two questions answered before any code

#### 1. Do monsters run on the 20Hz tick or the 60Hz frame — **both, and the split already exists**

`monsters.md`'s first TBD says the plan answers this first. The answer is not a new choice; it is the split
`monsters-minimum` already shipped, made explicit and extended to bosses:

| What | Clock | Why it cannot be the other one |
|---|---|---|
| **Movement** (`monster.step`) | **60Hz** (`world_step.frame`, after `_char.step`) | Tie a charge to ticks and it moves in 21px jumps. The target is `_char.center()` *this frame* |
| **The pattern clock · stun · phase · cooldowns** | **20Hz** (`monster.on_tick`) | Damage, invulnerability, `_drain_queue`, `_grid.step()` and fire spread are **all 20Hz.** A pattern counted in frames would carve and ignite at moments no tick exists to apply them |

⇒ **The pattern state machine is a tick counter**, the same idiom as `reload_left` and `invuln_left`
(integer, decremented in `on_tick`). `step()` only *reads* the current pattern to decide speed and direction.
**Cost lands on the 60Hz side and it is one monster** — see "Cost" below.

#### 2. Variant, or a new kind — **variant in the table, new only in behavior**

- **Box · hp · speed · invuln · xp · money** → one row each in `monster_defs.DEFS`. Nothing new.
- **What is genuinely new is one axis: "which pattern is running right now".** `_next_axis()` is one line
  today and `monsters.md` demanded it stay the only place answering "where does the next step go".
  Growing it by one branch per pattern turns that function into the boss AI — **the thing this doc forbids.**

⇒ **One new file, `src/actor/boss_ai.gd`**: a per-kind pattern table plus the tick machine that walks it.
`_next_axis()` gains **exactly one** delegation branch, not one per pattern.

**File count to add one more boss after this lands** — 3 inside the contract:

| File | What |
|---|---|
| `src/actor/monster_defs.gd` | one row |
| `src/actor/boss_ai.gd` | one row (its pattern list) |
| `src/view/fx_tuning.gd` | one `MONSTER_SHEETS` line |
| ~~`src/stage/stage_input.gd`~~ | one `MONSTER_KEYS` line — **the shell, explicitly outside the file-count contract** (`monsters.md`, "Boundary") |

**To add one more *pattern* to an existing boss: 1 file** (2 if it draws differently).

**Behavior does not go into `monster_defs.gd`.** That file's own header forbids "how it attacks" columns.
Now that something would actually consume them the "false knob" argument weakens — but the isolation is worth
more: the table stays readable as "what a monster *is*", `boss_ai` holds "what it *does*".

#### The axis's consumers — **all five must follow, or this is the signature fake**

`pattern` growing in the sim while the screen stays put is CLAUDE.md's "screen changes but sim doesn't" in
reverse. Every stage below carries its own screen half for that reason.

```
boss_ai.pattern ─┬─ monster.step()      speed · direction · frozen while stunned
                 ├─ world_step          cmd_carve · cmd_ignite · gore contact damage · charge contact damage
                 ├─ monster_bolts       fire bolts (a kind column, not a second file)
                 ├─ monster_view        telegraph · stun indicator · phase tell
                 └─ net_monster         the pattern sequence measured as a sequence, not as final state
```

**Charge contact damage was assigned to no stage at all until B's own review caught it** — Stage E as first
written opens `world_step._char_hit_by_monsters`'s one lump only for gore, so a charging bull would pass
straight through the player with zero damage, forever, and E as written would not close it. **Fixed: Stage E
adds both in the same edit** — gore *and* a charging bull's contact both go through that one lump, the same
"one hit and that is the end of it" discipline the lump already holds for pig/hen.

### Files to touch, and why

| File | Why |
|---|---|
| `src/actor/monster_defs.gd` | `KIND_BULL`/`KIND_ROOSTER` + two `DEFS` rows + `ALL` |
| **`src/actor/boss_ai.gd`** (new) | The pattern table and the tick machine. The only new file |
| `src/actor/monster.gd` | Holds the boss state; `_next_axis` delegates; `on_tick` drives the machine |
| `src/actor/body.gd` | `move_x` returns "was I blocked" — **symmetric with `move_y`, which already does** |
| `src/actor/monster_bolts.gd` | A bolt-kind column (plain · fire) + an impact notification the world reads |
| `src/actor/world_step.gd` | Enqueues `cmd_carve`/`cmd_ignite`; gore contact; boss-death reward gate |
| `src/actor/progress.gd` | The reward gate's one field (see stage I) |
| `src/view/fx_tuning.gd` | Two `MONSTER_SHEETS` lines + telegraph/stun/phase presentation constants |
| `src/view/monster_view.gd` | Draws the telegraph, the stun indicator and the phase tell from `pattern` |
| `src/stage/stage_input.gd` | Two `MONSTER_KEYS` lines + the reward-close debug key |
| `src/stage/stage.gd` | Wires the reward key and the ①-side water pour |
| `tests/nets/net_monster.gd` | Pattern **sequence** checks (see "Risk", the ordering trap) |
| `tests/nets/net_tables.gd` | The two new rows |
| `assets/monster/bull_body.png` | **Padded 86×54 → 88×56, transparent, 1L·1R·2T·0B, then re-imported** (Risk 1). The only asset edit in this plan, and it cuts no pixel |

**`src/sim/` is not touched at all.** Every grid change goes through commands that already exist
(`cmd_carve` · `cmd_ignite`). **No new door into the grid is opened** — but Stage C's carve does not go
through `_drain_queue()` (that door is for callers *outside* `world_step`, e.g. the shell's fire input);
collision detection already runs inside `world_step.frame()`'s own tick branch, so it calls `_grid.apply(...)`
**synchronously, from the monster loop, which runs *after* this tick's `_grid.step()`/`_spell.step()`.**

⇒ **Corrected from this doc's earlier claim**: a carve (or, when Stage D lands, a fire bolt's `cmd_ignite`
through the same door) does not affect the grid on the tick it is issued — `_grid.step()` for that tick
already ran. It settles and is visible starting the **next** tick, one tick later than "a bull's fire lit
this tick burns this tick" said. **Harmless for a carve** (nothing depends on same-tick carving); **Stage D
inherits this unchanged** — state it as the contract instead of moving the tick order to chase the old
sentence, which is a far bigger risk than a one-tick delay on ignition.

 **One rule collision, named rather than broken**: `sim_tuning.gd`'s header says "every value touching the
grid lives here". The boss's carve/ignite radii touch the grid but live in `boss_ai.gd`, because this doc's
own Boundary put boss attacks in `src/actor/` ("bolts have no owner"). `monster_bolts.gd` is the precedent.
**Add one line to `sim_tuning.gd`'s header naming that exception** — silently breaking the sentence is worse
than the split.

### Order

Each stage is verifiable on its own. Each carries its own screen half.

| # | Stage | Verified by |
|---|---|---|
| **A** | **The two kinds exist and stand on screen.** Two `DEFS` rows · two `MONSTER_SHEETS` lines · two `MONSTER_KEYS` lines. **Boxes = art size: bull 88×56 (after a lossless transparent pad, +import), rooster 72×80** — forced by two nets, see Risk 1 | Press the key: it stands on terrain, faces, flips, takes a bolt, flashes, dies, leaves a corpse. All of that follows for free. `net_monster_sprite` goes green on the new kinds |
| **B** | **The pattern machine + charge → ram → stun.** `boss_ai.gd`; `move_x` returns blocked; `pattern`/`pattern_left` on `Monster`; `_next_axis` delegates. **Triple and sweeping are two more rows in the same table** — a repeat count and a direction flip, no new code. Screen: wind-up and stun indicator | Headless: drive `world.frame()` and read the **pattern sequence** (idle→wind-up→charge→stun→idle), not the final state. On screen: it charges, hits the wall, stops, and you can see that it stopped |
| **C** | **The charge carves — only while charging.** On a blocked charge, `world_step` enqueues `cmd_carve` at the impact point | Headless: charge into a wall → cells gone; **walk into the same wall → cells unchanged.** That second half is the whole of acceptance 2 |
| **D** | **The fire breath.** `monster_bolts` gains a kind column; a fire bolt records an impact the world turns into `cmd_ignite`. The bolt hurts the player on its own — **it must, see Risk 4** | Headless: bolts fly, hit wood, wood burns; bolts pass over stone and leave nothing. **The bull cannot be hit by its own bolts** (acceptance 15 — structurally free, the bolts do not know monsters exist). **It is not exempt from its own terrain fire** — a different channel, kept as decided behavior, see Risk 4's addendum |
| **E** | **Gore, and charge contact damage in the same edit** — both are a contact-range attack in `world_step._char_hit_by_monsters`'s one lump, not two damage paths. **Stage B shipped the charge with no contact damage at all** (found in B's own review) — a charging bull passed through the player untouched; this is where that closes | Stand next to it: it gores instead of charging. Charge does not fire inside gore range. **Run into a charging bull and it hurts** |
| **F** | **The rooster — leap, pounce, land.** Reuses `stun_left` for the landing window: **one field is "the window to hit" for both bosses** | It leaves the ground, lands, and stands still long enough to aim at. It does not stay airborne |
| **G** | **Jump slam** — reuses D (fire) and F (leap). Lands → fire thrown outward along the ground | One row in the pattern table + the landing hook. **Every constraint on the bull's fire applies unchanged** (the doc's own words) |
| **H** | **Phases.** At `hp <= max/2`, pattern durations and charge speed scale by integer ratios. Screen: a phase tell | Headless: the same pattern measured before and after the threshold differs by the ratio. On screen: distinguishable by eye |
| **I** | **Reward, *then* the wall collapses, *then* water.** Boss death sets a **reward-pending** flag; water starts only when it clears. **In this build the only thing that clears it is a declared debug key** (see below) | Headless: kill the bull → water total stays 0 while pending; clear the reward → water rises. **Reversing the order is the failure** (acceptance 8b) |

####  Stage I's honest gap — the reward has nowhere to go, and that is step 3's job

**Closed** — [`rune-lock-and-receiving.md`](rune-lock-and-receiving.md) (Stage C), not through the
three-pick card path predicted below; the assembly window already had a rune-placement path, so that plan
reused it instead of widening this one.

`planning-review-order` flagged one risk to confirm: **is the three-pick window's card and placement path
glyph-only in a way a rune cannot pass through.** It is. Confirmed by reading, four independent places:

- `three_pick.draw()` (`src/actor/three_pick.gd:21`) draws only from `Glyph.ALL`
- `progress._drawn` holds glyph ids; `Progress.take(glyph_id)` checks membership in that same list
- `three_pick_window._draw_card` (`src/view/three_pick_window.gd:477`) indexes `Glyph.DEFS[glyph_id]` for
  kind · rarity · name · `power_pct_of`. **A rune id has none of those.** Worse: `Tuning.ELEM_FIRE == 0 ==
  Glyph.GLYPH_NONE`, so a fire rune passed as a card id **is indistinguishable from "no glyph"** everywhere
- `_gui_input_step2` (`three_pick_window.gd:217`) hit-tests `CircleLayout.layer_at()` and places with
  `place_glyph(layer, …)`. `CircleLayout.rune_slot_at()` **exists** (`circle_layout.gd:142`) and this window
  **never calls it**; `SpellCircle.set_rune()` is not called from any window in the repo

**The review's claim is optimistic but not wrong in kind.** The window *shell* genuinely reuses — the rect,
the two-step flow, the circle drawing, the confirmation afterglow, the reject message. What has to change is
that a card becomes **typed** (glyph | rune) in `three_pick.gd` · `progress.gd` · `three_pick_window.gd` ·
`fx_tuning.gd` — **four files, inside a `3.done` feature.** That is step 3 of the milestone chain, not step 2.

⇒ **This plan builds the seam, not the reward.** `world_step` exposes "a boss reward is pending"; the water
in ① is gated on it clearing; and the **only** thing that clears it in this build is a shell debug key,
declared as one in the same breath as M · N · F · T · G · K. That is not fake code — it is the shell standing
in for a decision the user has explicitly left open ("how the fire rune is received"). **Step 3 replaces the
key with the real card and touches nothing else in this feature.**

### Risk

**1. Two net contracts decide the box, and the bull's art satisfies only one of them.**
**This risk was written naming one net and there are two.** Builder found the second while building stage A.

| Net | Asserts, for every kind in `Defs.ALL` | bull 86×54 | rooster 72×80 |
|---|---|---|---|
| `net_monster_sprite._sheet_fits_the_box` (`:53-56`) | texture size **==** `w_px`/`h_px` | — | — |
| `net_monster._defs_preconditions` (`:126-131`) | `w_px % CELL_PX(4) == 0` · `h_px % 4 == 0` | **fails** (86%4=2 · 54%4=2) | ok |

Box = art and box % 4 == 0 cannot both hold at 86×54. **The rooster is unaffected** — 72 and 80 are already
multiples of 4.

 **Resolved by padding the png, which bends neither net and cuts no pixel.** Measured on the actual files:

```
bull_body.png     canvas 86x54  opaque bbox x[0..85] y[0..53]   margins L0 R0 T0 B0
rooster_body.png  canvas 72x80  opaque bbox x[0..71] y[0..79]   margins L0 R0 T0 B0
pig_body.png      canvas 44x32  opaque bbox x[2..41] y[5..31]   margins L2 R2 T5 B0
```

**Bull and rooster have zero transparent margin — opaque pixels touch all four edges.** ⇒ **cropping to 84×52
cuts live pixels off the beast.** Padding does not.

⇒ **Pad `bull_body.png` to 88×56 with transparent pixels: 1 left · 1 right · 2 top · 0 bottom.
Box becomes 88×56. Re-run the import.** Every contract holds and the drawn pixels are identical:

- `_sheet_fits_the_box`: 88×56 == 88×56
- `_defs_preconditions`: 88%4 = 0 · 56%4 = 0
- **the flip check** (`net_monster_sprite:85`, `minx + maxx == w-1`): 1 + 86 = 87 = 88−1 ✓
  **This is what forces 1+1 rather than 2 on one side** — pad 2 to the right alone and the bull jumps 2px
  every time it turns around
- **the feet check** (`:92-93`, `maxy == h-1`): padding only the **top** keeps maxy at 55 = 56−1 ✓
- `img size == tex size` (`:67`, import freshness) — **which is why the import must be re-run in the same
  edit.** Skip it and the game draws the stale `.ctex` while the net measures the new png.
  **Use a headless `--import` pass, not `--editor`** — measured while building stage A: `--editor` left the
  `.ctex` stale mid-scan, so the net kept reading the old 86×54 texture against the new 88×56 png

 **Done, and confirmed by value** (builder, stage A): padded with aseprite (`create_canvas` 88×56
transparent → `import_image_as_layer` at x=1 y=2 → export; **no resampling**). Pixel identity checked —
`original(43,30) == padded(44,32)`, exactly the +1x/+2y offset — and the new last row (y=55) carries opaque
foot pixels, which is what proves 0px was added at the bottom. `net_monster` 287/287 ·
`net_monster_sprite` 41/41 · **3,558 pass**, with only the 3 pre-existing `net_water_rain` reds left.

**Price, named**: the collision box is now 1px wider than the beast on each side, so it floats 1px off walls.
`fx_tuning`'s `MONSTER_FILL` comment already records that symptom at 12px; 1px on a 32px tile is invisible.

**Second price, not yet due**: only `bull_body.png` was padded. The other 8 bull sheets (`bull_charge`,
`bull_stun`, …) are still 86×54 — inert today (`MONSTER_SHEETS` holds one image per kind, the standing pose
only). The day the animation open question (16) lands a state->frame table, every one of those frames sits
1px/2px off the standing pose's silhouette unless it is padded the same way first.

 **And write down what the `%4` premise actually is, because it has no recorded grounds.**
`net_monster.gd:122-131` states it as a bare premise with no comment. **The code does not require it** —
`body.box_free`, `standing_in_fire`, `standing_in_water` and `water_flow` all compute
`floori(px / 4.0)` … `floori((px + w_px - 1) / 4.0)`, which is correct for any width; `_boxes_overlap`,
`spawn_monster`'s bounds check and `monster_view.box_rect` are plain px arithmetic. The one place size
matters is `stage._spawn_monster_at`'s `roundi(w / 2.0)`, whose own comment says the trap is **odd** widths —
**even**, not multiple-of-four. ⇒ the premise is tidiness, not a contract.
**Do not delete it as part of this work.** Padding satisfies it for free, and retiring a premise is a harness
decision (`harness-manager`), not a stage-A side effect.

**2. 13 of the 19 monster pngs have no `.import`** (measured — `bull_charge` · `bull_death` · `bull_fire` ·
`bull_gore` · `bull_idle` · `bull_slam` · `bull_stun` · `rooster_death` · `rooster_idle` · `rooster_land` ·
`rooster_leap` · `pig_walk` · `chicken_walk`). `load()` returns **null** for all of them.
**Stages A–I are unaffected** — `bull_body` and `rooster_body` are imported. **It blocks the animation work
entirely**, which is why that is out of scope below. A headless `--import` pass fixes it when that day comes.

**3. Acceptance 8 is the load-bearing one, and acceptance 5 hangs off it — measured on the baked map.**
Room ① is **x230–259, floor top y32, flat, 30 tiles wide**, and:

```
left  boundary   a 2-tile step up at x229/230          STONE
right boundary   a 6-tile rise at x260, ~4 tiles thick STONE
bedrock          only at y45-47 — nowhere near the room
wood wall        x264-266  ← 4 tiles right of the room edge, 12 tiles above its floor
```

`_disc(…, destroy=true)` (`cell_grid.gd:911-915`) skips only `_indestructible` = **bedrock**. Both of the
bull's boundaries are stone. ⇒ **charge carving can flatten them**, and the **left 2-tile step (16 cells)
gives way long before the right wall (32 cells thick)**. If the bull leaves the room it walks toward the wood
wall, and **acceptance 5 ("the fire never reaches the wood wall") falls with acceptance 8.** They are one
measurement, not two. Measure the left step first.

 The map doc calls ① "a bedrock bowl whose only exit is water". **That is stale** — the redrawn left half
made it a walk-in stone shelf, and the doc says so itself. **Do not report acceptance 8b's "the water carries
the player out" as passing on this map**: you can walk out up the stairs. Fixing that is `stage1-map-layout`'s
call, not this one's.

**3-addendum. Acceptance 8 holds — for a reason nobody wrote down, and it is not the reason this Risk
assumed.** The assumption above was "measure the left step first, because it gives way first". **Measured
instead: it never gives way at all, at `carve_r`=3** — not "slower than the right wall", genuinely zero
across repeated hits at the same spot. Two independent measurements agree: a synthetic-wall pass during
Stage C's own implementation, and verify-run-b's pass on room ①'s **real baked geometry**. The real-map
numbers are the ones that matter and are recorded below; the synthetic ones stay only for the controlled
`carve_r` sweep nothing else could produce.

**The cause is arithmetic, not tuning**: a disc of radius `r` is `2r+1` cells tall at its widest row. The
bull's box (`h_px`=56 = 14 cells) needs all 14 rows of a cell column clear to advance one cell into it.
`r`=3 gives a 7-cell-tall hole — `7 < 14`, so the bull can never step into what it just carved.

**Real-map measurement (verify-run-b, room ①'s baked geometry, `carve_r`=3 as shipped)**: 1,000 simulated
seconds, **196 charges** (99 left-facing, 97 right-facing), the player run laps so every charge had real
runway (mean run-up 533px, 133 of 196 over 200px — see the methodology note below on why this matters).
The boundary band went **16,640 → 16,611 cells = 29 cells removed total, and every one of the 29 came out of
the first two charges** (11 on the left face, 18 on the right) — **charges #3 through #196 removed zero.**
The bull never left the room across the full run; the floor (3,840 cells) was unchanged; **the wood wall
stayed untouched at 1,152 cells**, so acceptance 5 survives with room to spare.

**Corroboration on a free-standing wall**: a single charge can pierce up to 4 cells deep, yet the bull still
cannot pass even a **1-cell-thick** wall, for the identical 7-vs-14 reason (a single-cell disc's own vertical
reach already exceeds a 1-cell wall's thickness, but the bull's box still can't fit through the resulting gap).
16 charges were run against every thickness from 1 to 16 cells; the bull ended every run flush at its start
position, never past it.

**This is a cliff, not a curve** — measured by raising only `carve_r` (nothing else), driven directly through
`cmd_carve`:

| `carve_r` | hole height (`2r+1`) | vs. `h_px`=14 cells | accumulates? |
|---|---|---|---|
| 3 (shipped) | 7 | 7 < 14 | no — **better than 2x margin** |
| 5 | 11 | 11 < 14 | no |
| 6 | 13 | 13 < 14 | no |
| 7 | 15 | 15 ≥ 14 | **yes — the bull passes** |

**7 is the number for the TBD below.** `net_monster._charge_destruction_does_not_accumulate_across_cycles`
is the check that goes red the moment someone crosses it, but nothing on screen changes gradually beforehand
to hint at it — raising `carve_r` after seeing 3's bite look small on screen steps off this cliff blind.

**The left/right off-by-one, measured the same way from both sides** — `dir=+1` (rightward) centres the disc
at `cx200`, outside the box: **18 cells** eaten. `dir=-1` (leftward, pre-fix) centred at `cx132`, *inside*
the box: **11 cells** — **39% shallower purely from which way the bull happened to be facing**, nothing to
do with the wall. Fixed (`else m.x - 1`). **Fixing it makes the left face erode *more*, not less** — the
loaded face (Risk 3's own "the left step gives way first" assumption) now digs deeper than before the fix,
so this is re-measured, not assumed: **~18 cells on the corrected left face, still nowhere near the 16-cell
boundary width being fully removed** (the boundary count above, 29 cells over the whole run, already
reflects the fixed code).

**Determinism holds**: 3 runs, 2 bulls + 1 pig in the same loop (so one bull's carve is visible to the
other), grid hash / positions / tick identical across all three. The synchronous `_grid.apply()` call
(not routed through `enqueue()`) is fine.

**Methodology, so nobody re-measures this wrong**: parking the player near the bull reproduces the
zero-runway degenerate cycle (verify-run measured 313 "charges" all lasting 1 tick under that setup) and the
accumulation number that comes out is meaningless — every charge starts already touching the wall it just
hit. **Check the run-up distances first** before trusting any accumulation measurement.

**Decided: keep `carve_r`=3 (better than 2x margin below the r=7 cliff), because acceptance 8 carries
acceptance 5** (the wood wall staying out of the bull's fire's reach depends on the bull staying in the
room). Raising it toward 6 is still safe by this measurement; raising it to 7 or past is a real option for
later, but it is now a **decision with its own named cost and its own cliff**, not a free tuning knob.

**4. Acceptances 4 and 6 pull against each other, and 4 cannot be seen in room ① at all.**
`_ignite_cell` (`cell_grid.gd:728-730`) refuses when `fuel <= 0`. Stone and empty have zero fuel. Rule 6 puts
**no wood in room ①**. ⇒ **the bull's fire leaves no mark whatsoever in its own arena, by design.**
Two consequences, both load-bearing:

- **The fire bolt must hurt the player by itself.** If the only effect were ignition, the fire breath would be
  a completely inert attack inside the room where it is used. That is why stage D's bolt carries damage
- **Acceptance 4 ("the fire sticks to terrain") is unobservable in room ①.** Verify it in a wooded scene
  (the T key lays a forest) and say so in the report. A verifier who tests it in ① will report a working
  feature as broken

⇒ **In room ① the breath is purely an 8-damage projectile — no ignition is possible there by design.**
Nobody will ever see "fire sticks to terrain" in the bull's own arena. verify-look needs the T-key forest;
without it, a working feature reads as broken.

**4-addendum. Acceptance 15 measures less than its old label claimed, and the missing half was decided, not
found broken.** `consume_hits(ch: Character)` never looks at `_monsters` — bolt collision is structurally
free of self-hits, and that half of acceptance 15 holds exactly as written ("cannot be hit by its own
bolts", the label narrowed to say only that). **But `monster._burn`/`Body.standing_in_fire` are a separate
channel and were never exempted** — measured (verify-run): a bull standing on burning wood takes damage from
it like any other monster, 300 → 287 hp over the measurement window.

⇒ **Kept, decided by the user.** The bull burns in its own terrain fire. It fits the design's own thesis —
brainless charging becomes its own weakness, and "the world reacts" should not carve out an exception for
the monster that lit the fire. Unreachable in room ① (no fuel there by design); reachable the moment a bull
meets wood anywhere else. **The bull's own default `IDLE` behavior is walking toward the player** — walking
through its own leftover fire is its default behavior, not a bug to fix.

> ⚠ **This whole "acceptances 4 and 6" analysis rests on two premises that `burn-out-of-the-bull-room.md`
> both changed** (built, §0). First, **room ① now has wood** — rule 6's "no wood in room ①" is gone the day
> the east wall becomes a door. Second, and the one that actually matters here: **`WOOD` is `rune_only`
> now**, so "acceptance 4 is unobservable in room ① because there is no fuel" is replaced by a stronger fact
> — **the bull's own fire bolt cannot ignite wood *anywhere*, fuel or not**, because its ignition source
> (`IGNITE_ANY`) is never the fire rune's own. The burning-in-its-own-fire finding just above (300 → 287 hp)
> is untouched — that is segment/blast damage from the bolt itself, not terrain ignition — but "a bull meets
> wood anywhere else and it catches" no longer holds anywhere in the game, not only in room ①.

**Acceptance 5 is protected by level design, not by any mechanism that forbids it.** verify-run debug-spawned
a bull directly next to the wood wall and it burned — **all 1,152 cells, from either side.** Nothing in the
fire/ignite code itself distinguishes "the wood wall" from any other wood. It survives in the real map only
because Stage C confines the bull to room ① and the wall sits far enough outside it (the muzzle's reach is
measured ~42 cells short of the wall) — a map-shape fact, not a code guarantee. If the map ever changes to
put the bull within reach of that wall, this acceptance breaks with no code change at all.

**5. A check that reads only final state cannot measure a pattern.** The whole of stage B is an *ordering*
contract (wind-up **before** charge, stun **after** the ram). Final state is identical whichever order runs.
⇒ `net_monster` must record the **pattern sequence across ticks** and assert the sequence, and assert the
**iteration count** too — a machine that never leaves idle produces a green loop that ran zero times
(CLAUDE.md's three surviving failure shapes, two of which apply here directly).

**6. `move_x` changing `-> void` to `-> bool`.** Callers that ignore the return still compile. `move_y`
already carries exactly this contract, which is the argument for doing it this way rather than diffing `x`
across a frame. Check `net_character` for a static reference before editing.

**7. The full round is 15.6s.** CLAUDE.md's threshold is 10s. Adding boss nets pushes it further —
**call `harness-manager` once stage C lands**, not at the end.

**8. Stage E's gore gate needs both axes, and a charge's contact cost is not the sticker number.**
Measured (verify-read):

- **Horizontal-only range disables the boss entirely.** `_dist_to_target` (already used for the hen's stop
  range) measures the x-axis alone. Using it bare for gore's gate meant a player standing on a ledge above
  the bull — close in x, far in y — won the gate every time: gore's boxes never actually overlapped (so it
  dealt zero damage) and, because gore always won, the bull never charged either — no ram, no carve, no stun
  window. **Fixed: the gate now also requires the boxes to vertically overlap**
  (`Monster._vertically_overlaps_target`), reconstructed from `target_y` and `Character.H_PX`. Horizontal-only
  distance stays correct everywhere else it is used (the hen's own gate is exactly this shape) — this was
  specific to a melee move needing the boxes to be able to touch.
- **One charge pass costs `BULL_CHARGE_CONTACT_DAMAGE` × hits-per-pass, not × 1.** The bull's box (88px) plus
  the player's (20px) gives a 108px combined overlap window; at the charge's 280px/s that window lasts
  ~7.7 ticks (20Hz). `Character`'s invulnerability (4 ticks, effective 5-tick interval) fits **two** hits
  inside that window. **Kept as the real behavior** — a charge should cost more than a graze, and the number
  is provisional regardless — but whoever tunes `BULL_CHARGE_CONTACT_DAMAGE`(20) on screen needs to know the
  actual cost of standing in the path is 40, not 20. The dependency is on invulnerability-frame count and
  charge speed both; changing either changes hits-per-pass. **Confirmed independently by verify-run-b** on
  the real map: 8 overlapping ticks, invulnerability spacing lands hits 5 ticks apart, exactly 2 hits,
  40/pass (`f204:-20 f216:-20`). Contact is checked once per **tick** (20Hz), not per frame.

**8-addendum (verify-run-b).** Two more numbers the vertical-overlap fix above did not close, left as
information for a tuning pass rather than patched blind:

- **Gore's 120px gate and gore's actual reach (54px) do not match.** Box overlap needs centre distance
  < (88+20)/2 = 54px, so there is a **~66px band where the bull commits to a swing it cannot reach** — and
  it is frozen during gore (this doc's own contract), so it cannot close the gap either. Measured at launch
  instant: 0–49px → gore, connects; 55–113px → gore, **whiffs**; 125px+ → a real charge. **Its practical cost
  is near zero today** — in a 500s fight against a player who does not retreat, the boss's own idle-walk
  closes the gap before the gate is ever checked again (measured: 66 gores, 66 connects, 0 whiffs) — the dead
  band only shows up because a **fresh** bull's first tick fires the gate before it has taken a single step.
  **Not treated as a bug to patch here** — a real design choice (shrink the gate to 54px, or give the swing a
  short lunge) that a tuning pass gets to make once this is on screen.
- **Two reference numbers for whoever tunes this next**: a player who never fights back dies in **24.8s**
  running fixed laps, **20.4s** retreating (bull 100hp-scale contact, player ~100hp). Retreating dodges
  **55 of 55** fire breaths but eats **twice** the charge damage (2,200 vs 1,040 over the run) — "retreating
  pays the price" (the design's own line, GDD "direction of progress"), measured rather than assumed.
- **392 damage landed while the bull's `pattern` was `IDLE`/`WINDUP`/`STUN` in one run — this is fire bolts
  still in flight after the breath ended, not a contact-gating leak.** A bolt is its own projectile with its
  own lifetime (`MonsterBolts.BOLT_RANGE_PX`), deliberately not tied to the pattern that spawned it — the
  same reason the hen's bolts already outlive the hen's own state. **Contact damage itself stays strictly
  pattern-gated** (measured: IDLE 42 overlapping ticks → 0 damage, WINDUP 47 → 0, STUN 42 → 0, GORE 22 → 100)
  — the 392 is a different channel and should not be misread as a gate leaking.

**9. Stage F reuses `MOVES`/`Pattern` for a physics-driven move, not a fixed-tick one, and that had to stay
out of the round-robin's kind-agnostic arithmetic.** The rooster's `LEAP` ends when the body actually lands
(`Body.grounded`, latched through `Monster._leaped_landed` — the same 60Hz-collision-reaches-the-20Hz-clock
channel `_charge_blocked` already opened for the charge), not on a fixed duration; `leap_max_ticks` is a
safety net only, proven separately (`net_monster._leap_with_no_floor_ends_via_the_safety_cap`) from the
normal landing path (`_rooster_pattern_sequence_is_idle_windup_leap_stun_idle`, which also asserts the leap's
run-length stays under a fixed 30-tick bound — **not `leap_max_ticks / 2` any more, see Risk 10** — otherwise
a broken landing detector and a working one produce the identical state sequence, only the tick count tells
them apart).

**Not built** — `stage1-bosses.md`'s own TBD, still open, not guessed at: **does the rooster break terrain on
landing.** `LEAP` carries no `carve_r`; landing does nothing to the grid.

**Acceptance 11's telegraph deliberately left untouched.** It rides the same shared `WINDUP` indicator
channel (the "!" text) verify-look already measured as weak at play-scale zoom (Risk 8's own screen
observation, above) — the rooster's leap-windup reads exactly as strong or weak as the bull's charge-windup,
automatically, since the indicator is driven by `Pattern.WINDUP` alone, not by kind. **Per the team's
instruction, this was not touched here** — the user has been asked about the "!" size and the fix (if any)
is shared work belonging to whichever stage picks it up after the answer, not a Stage F-specific change.

**10. Stage F's fix list — four gaps found by re-reading the stage after it shipped, all closed here.**

- **The fall-through bark.** `advance`'s `WINDUP` transition falls through to the bull's `MOVE_CHARGE` for
  any kind that reaches it without its own `kind ==` branch (Risk header, `boss_ai.gd`). A third kind added
  with only its own `MOVES` row would silently run the bull's charge, forever, with no error. **Fixed: a
  `push_error`** on that fall-through when `kind != Defs.KIND_BULL`. **Not net-driven** — with only two real
  kinds today the branch is structurally unreachable (the rooster's own `kind == KIND_ROOSTER` check always
  intercepts it first; the bull reaching it is the legitimate path). A net cannot drive a third `MOVES` entry
  that does not exist without adding one to production code first, which would itself be the "while I'm here"
  CLAUDE.md rules out — so this is documented as reasoned-through, not measured by a run, same as the
  `_rune_trace_has_the_none_branch` precedent (`net_spell.gd`) for an analogous unreachable-by-real-input bark.
- **The leap's three provisional values were table-read only.** `_leap_values_are_read` and the sequence test
  only ever read `BossAi.MOVE_LEAP`/`leap_jump_vy_px`/`speed_mult` back out of the same table a mutation would
  edit, so none of them could catch a wrong *value* landing there. Three mutations were green: ignoring
  `leap_speed_mult` (`speed_mult` returning 1.0 for `LEAP`, halving horizontal distance), `jump_vy_px` × 0.4
  (apex ~40px → ~8px, with `min_y_during_leap < stand_y` satisfied by a single pixel of lift), and
  `leap_max_ticks` 40 → 80 (nothing reads it except the safety-cap test, which only needs *some* cap to exist).
  **Fixed**: `_leap_moves_at_the_leap_speed_not_walking_speed` (copies `_charge_moves_at_the_charge_speed_
  not_walking_speed`'s one-frame-displacement idiom) catches the first; a **fixed pixel window (25..55px)**
  on the measured apex, independent of what `MOVE_LEAP` currently holds, catches the second.
- **Nothing measured that the rooster stops.** The sequence test recorded `seq`/`min_y_during_leap`/
  `saw_airborne`, never `m.x`. Fixed by adding `xs` tracking and a stun-window 0px assertion, the same shape
  the bull's own sequence test already had — except the bull's version turned out to be **a tautology of its
  own setup**: that test's charge ends flush against the wall it just rammed, so `move_x` reports blocked on
  every later tick whether or not the `STUN` freeze code exists at all (measured: deleting the freeze left it
  green). **Fixed for both**: the rooster's own assertion is real because nothing else stops it on open
  floor; the bull's was moved to a new dedicated test,
  `_bull_does_not_move_during_stun_with_no_wall_involved`, that reaches `STUN` via the safety cap on an open
  floor with no wall anywhere near it — genuinely testing the freeze rather than the wall.
- **`leap_max_ticks / 2` secretly coupled two provisional values that have no business being coupled.**
  Raising `|jump_vy_px|` toward ~1200 stretches a real landing to ~20 ticks and the ratio bound goes red with
  nothing broken; lowering `leap_max_ticks` to 16 drops the bound to 8 and a normal ~8-tick landing fails
  `8 < 8`, also with nothing broken. **Fixed: pinned as an absolute 30-tick bound**, independent of both
  tunables — above the shipped landing (measured ~8 ticks) and above the raised-`jump_vy_px` example, below
  the 41-tick safety cap, so a genuine "never lands" regression still goes red.

**Two doc corrections, both measured, neither a code change:**
- The apex comment on `MOVE_LEAP` said "roughly 52px" (the continuous formula, `vy²/(2·GRAVITY_PX)`).
  **Real measured behavior is 40px, 0.400s airtime, 153px across** (verify-run-b) — 60Hz Euler integration
  plus `Body.move_y`'s integer-pixel rounding, not a bug. **The rooster's own box is 80px tall, so it leaps
  roughly half its own height** — corrected in `boss_ai.gd`'s own comment, since that is the number worth
  judging on screen, not the continuous formula's ceiling.
- **Low ceilings degrade the leap silently** — measured: 8px headroom above the rooster's spawn point gives
  2 ticks of leap and 4px of lift; 2px headroom gives 1 tick and the rooster never reads as airborne at all,
  while `STUN` still hands out the full 21-tick landing window regardless. **Unreachable on the real map**
  (room ③ is 20×12 tiles = 384px tall, far more headroom than either number) — recorded as a **map-authoring
  hazard** for whoever places a rooster in a lower room later, not a bug to fix here.

**11. Stage G — the jump slam.** Built exactly to the plan's own scope: one row (`boss_ai.gd`'s `MOVE_SLAM`,
provisional, same status as every tuning number in this file) plus the landing hook (`WorldStep.
_ignite_slam_impact`, wired through a new `Monster.leap_landed_now()` read window mirroring
`charge_blocked_now()`). Round-robin now cycles `CHARGE -> FIRE -> SLAM -> CHARGE -> ...`
(`MOVES[Defs.KIND_BULL].size()` 2 -> 3); no other file's structure changed.

**`Pattern.LEAP` is now entered by two different kinds for two different reasons** — the rooster's own leap
and the bull's slam. `speed_mult`/`leap_jump_vy_px` were already keyed on `kind`, so they only needed one more
branch each; the two places that hardcoded `MOVE_LEAP["stun_ticks"]` for *every* `LEAP` ending (the `landed`
early-out and the safety-cap fallback, both inside `advance`) did not generalize for free and were wrong for
the bull without a fix — pulled into one shared helper, `_leap_stun_ticks(kind, move_choice)`, so the two call
sites cannot drift from each other. **Named, not just fixed**: `_leap_stun_ticks` keys on `kind + move_choice`
while every one of this file's other five `kind ==` accessors (`speed_mult`, `carve_r`, `fire_reload_ticks`,
`leap_jump_vy_px`, `gore_range_px`) keys on `kind` alone — safe today (one leap-shaped move per kind, so the
combination is never ambiguous), but one place standing in a different posture than its neighbours is exactly
the shape the next kind's own review pass should look at first.

**Applied Stage F's own postmortem before shipping, not after.** Every value-is-read check for the slam is
pinned against **fixed literals**, not re-read from `MOVE_SLAM` — the apex window, the ignite ring (exact
columns), the landing bound (a fixed 30 ticks, not `leap_max_ticks / 2`). All were confirmed to bite by
mutation before this stage was first reported: zeroing `slam_ignite_r` (4 checks red), dropping the
`leap_landed_now()` gate in `world_step.gd` (1 check red, by a mechanism worth naming below), forcing
`_leaped_landed = true` unconditionally (5 checks red), and deleting the `MoveChoice.SLAM` branch from
`advance`'s `WINDUP` transition so it silently ran the bull's own charge instead (9 checks red — this is `①`'s
exact fall-through shape, except this time the kind was real, so it's the first mutation in this doc's history
that a real net *can* drive).

**The gate-drop mutation's actual failure mode was not the one predicted.** The expectation was "burning
spreads further than the landing point allows." What was measured: with the `leap_landed_now()` gate removed,
`_ignite_slam_impact` fires **every tick the bull exists**, including through `IDLE`'s ordinary walk toward the
player — so the fire ring gets re-drawn at a different `m.x` on every tick of the approach, well before any
real landing, and the final "outside the expected boundary" check catches the resulting wider scorch mark. The
mechanism is different from what was guessed; the check still measured the right thing.

**Two things this stage's own first pass got wrong, both corrected by rereading — not by re-guessing:**

- **The ring geometry comment was wrong, and the arithmetic mistake inverted the conclusion.** `ignite_points`
  =5 spread `ignite_spread_cells`=3 apart puts the outermost pair at offset `(i - half) * spread_cells` =
  **±6 cells**, not the ±12 the comment first claimed (that number silently doubled the half-count into the
  offset). Add each point's own `ignite_r`=2 and the true outer edge is **±8 cells = ±32px** — measured
  against the bull's own **44px half-width** (`w_px`=88), **32 < 44**. ⇒ **the ring lands entirely under the
  bull's own footprint**, the opposite of the design doc's "the impact throws fire outward across the
  ground". The check itself was always right (fixed literals, ±8 cells, matching real behaviour) — only the
  comment justifying the shipped numbers was wrong, now fixed in `boss_ai.gd`.
  **Left as an open tuning item first, then verify-look saw it on the real map and confirmed the arithmetic
  by eye** — burning cells narrower than the bull's torso, mostly hidden behind the sprite, reading as "the
  bull is standing on a small fire" rather than "the slam threw fire outward". **Fixed**:
  `ignite_spread_cells` 3 -> 6, outer offset now ±12 cells (+`ignite_r`=2 = ±14 cells/±56px), clearing the
  44px half-width with margin instead of sitting 12px short of it. Confirmed by mutation, headless
  (`net_monster_slam.gd`'s exact-column check moved ±8 -> ±14). **Not yet seen on screen — record this
  plainly, do not read the arithmetic as the acceptance**: the fix has not been looked at. verify-look's
  screen re-check for stages F–I was blocked (another session's `godot-mcp` node held the editor bridge and
  would not release it, twice, including across a restart — killing it is the user's call, not made yet), so
  this fix is neither passed nor failed on screen, only correct by the numbers.
- **A claimed blind spot in Stage C's own analogous check was asserted, not verified, and was wrong.**
  The first version of this Risk said Stage C's "stun 동안 같은 자리를 또 파지 않는다" (`g.consume_changed()==0`
  after a carve) "may share" the ignite test's blind spot, since re-carving an empty cell "is also presumably
  a no-op". **Checked, not presumed**: it is not a no-op. `CellGrid._write_cell` raises `_changed` even when
  the value written is unchanged, and a carve **writes** to already-empty cells rather than early-returning the
  way `_ignite_cell` does — a repeat carve during `STUN` does register (measured: 696 cells vs. 0). The two
  operations only look symmetric from their outcome ("nothing visibly changes"); they are gated at different
  points internally, and only one is a true no-op. **The ignite side's blind spot is real and unique to
  it** — `CellGrid._ignite_cell` (`cell_grid.gd:726`) guards `if _burn_slot[i] >= 0: return false` *before* any
  write, so a repeat `_ignite_slam_impact` call during `STUN` genuinely leaves no trace on the grid. What
  **is** measurable is the signal `WorldStep` reads, not the grid: `Monster.leap_landed_now()` must read false
  once `STUN` has begun (`_leaped_landed` is only ever assigned while `pattern == LEAP`, cleared unconditionally
  every tick `on_tick` runs — the same precedent as `_charge_blocked_resets_between_cycles`, Stage B's own
  review). Added as an assertion inside `_third_cycle_is_slam_and_it_leaps`. **This proves the signal is
  single-shot, not that every possible caller respects it** — a caller ignoring the signal and calling
  `_ignite_slam_impact` unconditionally would still be invisible to the grid, per the paragraph above. Recorded
  as the honest boundary of what this stage measures, not closed further.

**11-addendum — the slam's apex cleared a real ledge, reopening acceptance 8/5. Reproduced on the real map,
fixed, and now pinned by a net — resolved, not just retuned.** `verify-run` reproduced it on room ①'s actual
baked geometry, not a synthetic ledge: player parked on the room's own first step (a spot a player can simply
walk to — `stage1-map-layout`'s "walk-in stone shelf"), bull **outside room ① in 11.0 seconds** (frame 660,
leftmost x 7124px, 236px past the real 7360px boundary, 89 slams), measured apex **70px** against the real
**64px** step. Reproduced identically on two revisions. **And no net measured this at all** — `verify-run`
grepped `net_monster` for any check on "does the bull stay in room ①" at any stage before this one and found
none; Stage C's own confinement was structural (Risk 3-addendum's 7-cell-hole-vs-14-cell-body arithmetic), not
watched by a net either, so a second, unrelated door (a jump arc, no destruction involved at all) opened over
the same wall with nothing positioned to notice.

- **Fixed: `jump_vy_px` -600 -> -450, measured 38px real apex** (not derived — the continuous formula has
  overshot by roughly 30% every time it has been checked against this game's discrete integration; see
  `MOVE_LEAP`'s own correction earlier in this Risk). 38px leaves 26px of margin under the 64px step, and sits
  clearly below the rooster's own 48px real apex so the two moves' fixed-window checks still can't wear each
  other's constant (`net_monster.gd`'s slam apex window moved to `30..44`). **The slam is now shorter than the
  rooster's own leap** — the opposite of the flavor text that shipped with `-600` ("a bigger hop than the
  rooster's"), a real, visible trade of screen presence for keeping the bull in its own room.
- **Fixed: pinned with a net, on the real baked geometry** —
  `net_monster._bull_slam_does_not_leave_room1_on_the_real_map` builds the actual map
  (`Stage.build_terrain_into`, the same static door `net_water_rain.gd`/`net_tables.gd` already use), parks the
  player on the real first step, and asserts the bull's leftmost x never crosses a **fixed literal** measured
  once from the baked map (cx=1840/px=7360 — confirmed independently here by scanning `is_solid` down the
  actual wall: a clean 4-step, 16-cell-tall/64-cell-wide staircase, the lowest tread of which is exactly Risk
  3's own "2-tile step"). **Confirmed by mutation**: reverting to `-600` makes this check fail with
  min-x=7092px (268px past the boundary) — the same order of magnitude verify-run measured on the real map,
  from a synthetic run with far fewer ticks. **Cost matters here**: the first version ran 4,000 ticks "to be
  safe" and pushed this file from ~11s to ~23s (the full round to 23s with it); cut to 600 ticks (2.7x the
  real repro's own 220-tick breach window) brings the file back to ~13-14s. The round is still over CLAUDE.md's
  10s line (it already was before this session — Risk 7 flagged calling `harness-manager` once Stage C landed,
  and that has not happened since) — flagged again here, not fixed by this builder.
- **Fixed: the slam now deals contact damage on landing** (fix ③, below) — before this, a third of the bull's
  turns were completely inert in room ① (no wood there by design, so the fire ring landed nothing either);
  time-to-death moved from 24.8s to 37.5s running laps and 20.4s to 26.1s retreating, measurably *weaker* for a
  stage meant to add a threat. `BULL_SLAM_CONTACT_DAMAGE`=18 (provisional, same status as every number here),
  gated `Pattern.LEAP and kind == KIND_BULL` in the same one-lump `_char_hit_by_monsters` check that already
  gates `GORE`/`CHARGE` — **and the kind half of that gate is not assumed, it was inverted and found missing
  once**: dropping `kind == KIND_BULL` (leaving `Pattern.LEAP` alone) let the *rooster's* own leap hurt the
  player on landing too, passing every existing check silently (acceptance 10's own words: landing is the
  *player's* window to hit, not the reverse) — closed by
  `net_monster._rooster_leaping_onto_the_player_does_not_hurt_them`, added once the gap was found, not assumed
  safe because "the bull test only spawns a bull."

**Two more things recorded here, both from `verify-run`, not derived:**

- **Acceptance 5 survives this breach, but only behaviourally, not structurally — the exact coupling Risk 3
  names, now paid rather than merely predicted.** The bull went out *leftward* (toward the player, who was
  parked on the step), away from the wood wall on the room's opposite side; 2,000 simulated seconds after the
  breach the wall was still 1,152 cells intact and ignites landed 264 cells short of it. The right boundary (a
  6-tile, 192px rise) stayed sealed throughout. **Stage C made the wall's safety structural** (the carve
  physically cannot dig through); **Stage G, before its own fix above, made it depend on "the bull happens to
  chase the player instead of wandering toward the wall on its own"** — true today, not guaranteed by anything
  that would notice if it stopped being true. Recorded as the price Risk 3 already named, now measured instead
  of assumed.
- **"Ignites once per slam, not every tick" turned out to be measurable after all — by the door, not the
  grid.** This Risk's own first version said the grid channel could not see repeated `_ignite_slam_impact`
  calls (`CellGrid._ignite_cell`'s `_burn_slot[i] >= 0` early return makes a repeat call a true no-op) and that
  claim still stands. What was wrong was concluding *nothing* could measure it: `verify-run` subclassed
  `CellGrid` and counted calls to `apply(cmd_ignite(...))` at the door itself, independent of what the grid
  does with them afterward — **5 calls per slam, one grid tick per slam, across 4 slams = 4 distinct ticks**,
  with a positive control (29 `apply(cmd_carve(...))` calls against 29 real charges) proving the counter itself
  works. A second detector relayed fresh wood mid-`STUN` to clear the burning flag and found **0 further
  ignites across the whole 45-frame stun window**. The latch-based check added earlier in this Risk
  (`m.leap_landed_now()` reads false the tick after landing) stays — it is cheaper and already in the suite —
  but the door-counting technique is recorded here because "the grid cannot see it" was true and "it cannot be
  measured, full stop" was not, and the next person hitting this exact wall should not re-derive that the hard
  way.

**Confirmed passing, and the right kind of margin, not a lucky one.** At `-600` the failure was a *race* —
clear the step's height, then translate 88px sideways before landing — and it won that race at 11 seconds.
At `-450` the bull **never once reaches the required altitude in 60,000 frames**: closest approach lands
exactly flush with the boundary, the box's own top 25px short of the step. Every other edge of room ① stays
clear by 153px. The rooster's own negative control holds under the same scrutiny — its leap overlapped the
player on 124 ticks in the same run, for 0 damage.

**Fixed — the apex windows stopped separating the two owners, and the fix moved to a different axis
entirely.** Measured after the `-450` fix: the bull's slam apex is **32px on a flat floor, 39px in room ①**
(context-dependent — the exact number moves with terrain, not one fixed value the way the continuous formula
implied), and the rooster's leap is **40px**. `net_monster.gd`'s slam apex window (`30..44`) contains **both**
real values, so swapping the two constants would no longer be caught by height alone — the exact failure
Stage F's fix ③ closed, reopened by fix ① moving the slam's number 50px closer to the rooster's. **Kept the
apex window as a real measurement (it still asserts the true apex correctly) and moved the cross-mutation
guard to horizontal travel instead** — `leap_speed_mult` (1.5 vs. the rooster's 2.0) plus the shorter
`jump_vy_px` give the slam much less hang time, so total horizontal distance during the jump separates
cleanly: **measured 80px (bull) vs. 153px (rooster), 130px apart** where the apex was only 1-8px apart.
Added to both sequence tests (`_rooster_pattern_sequence_is_idle_windup_leap_stun_idle`'s own window `130..170`,
`_third_cycle_is_slam_and_it_leaps`'s own window `60..100`) using the same `xs`-tracking idiom the stun-freeze
checks already use. **Confirmed by mutation, both directions**: swapping either move's `leap_speed_mult` for
the other's is caught by its own travel-distance check (107px and 115px respectively, both still outside the
*other* move's window too — not a near-miss).

**Two numbers recorded for tuning, not for fixing — the slam still rarely connects against a moving player.**
Contact damage (fix ③) works in isolation (a landed slam deals 324 to a stationary target vs. gore's 1050 in
the same window — not a wiring failure), but the fight-level numbers barely moved: time-to-death went 24.8s
(Stage E) -> 37.5s (Stage G before fix ③) -> **36.5s** running laps, and retreating is **26.1s, unchanged to
the decimal**. Cause: the slam only travels **+80px** now (fix ① shortened the whole arc, not just its
height), so it lands near where it launched, and a player who is moving — especially retreating — is rarely
still there. **A third of the bull's turns are no longer inert in principle, but still connect rarely in
practice.** Left as an open tuning item, the same status as every number in this file.

**Also recorded**: the lower arc's ignite footprint landed **52 cells further left** (cx1835 vs. the old
cx1887, since a shorter jump lands nearer the launch point) — margin to the wood wall is unchanged at 112px
horizontal / 168px below it, and the wall is still 1,152 cells intact 500s in.

**Not built, same as Stage F's own leap** — does the slam's landing itself carve terrain (separate from the
fire it throws). The design doc names only "the impact throws fire outward"; adding a carve nobody described
would be new scope, not implementation of what's written.

**12. Stage H — phases.** Built to the Order table's own words: "at `hp <= max/2`, pattern durations and
charge speed scale by integer ratios."

- **`Monster.is_phase2()`** — `hp * 2 <= Defs.max_hp(kind)`, recomputed every call, never cached (the same
  "re-decided every frame" discipline `burning` already holds). The multiply form avoids the rounding
  ambiguity `hp <= max_hp / 2` would have for an odd `max_hp`.
- **Durations**: every `pattern_left` assignment inside `BossAi.advance` now flows through one function,
  `_phase_ticks(v, phase2)`, which halves (`PHASE2_DURATION_DIVISOR`=2) and floors no lower than 1 — a boss
  has one set of numbers, phase 2 is a multiplier read at the moment a duration is chosen, not a second
  parallel table that could drift from the first.
- **Speed**: only the bull's own `CHARGE` multiplier doubles (`PHASE2_SPEED_MULT`=2.0) — the plan's own words
  name "charge speed" specifically, not a general pattern-speed multiplier, so both leap-shaped moves
  (rooster's leap, bull's slam) are untouched by phase 2. A later pass may decide otherwise; today's build
  does only what the doc's own sentence commits to.
- **Screen — the TBD's first provisional answer, not the user's decision**: thick (4px), unblinking, always
  visible, in a strong indigo/blue (~230° hue, clear of every color already meaning something on this screen —
  telegraph orange, damage-number red, terrain/monster fire, the stun ring's cyan, the reserved scream-magenta).
  Deliberately on the strong side of verify-look's own finding that the windup "!" reads as a small orange dot
  at 1.0 zoom while the stun ring reads well — size and constancy, not a cleverer shape.
  **Composes with the pattern indicator rather than replacing it** (a boss can be mid-`WINDUP` and below half
  hp at the same instant; both tells draw). `_draw_phase2_tell` calls `Monster.is_phase2()` rather than
  re-deriving the threshold — one rule, read from its one place, the same discipline the sim side already
  holds for itself.
  **Shape — a full box outline first, corrected to four corner brackets.** verify-look saw the original
  rectangle on screen and named the exact mistake this repo already made once for body fire ("an orange
  selection box", acceptance 13, `monster_view.gd`'s own header): a full outline around a sprite reads as an
  editor's selection box, carrying no "this got more dangerous" meaning. **Fixed**: four corner marks (an "L"
  of two short lines per corner, `Fx.MONSTER_PHASE2_BRACKET_ARM_PX`=12px), color unchanged. The middle of
  every edge is deliberately empty — what a selection rectangle never leaves out — and the shape is neither
  the stun ring's circle nor the outline shader's own silhouette line. **Not yet seen on screen** — the same
  blocked re-check named in Risk 11's own fire-ring entry; this fix is correct by the same "not a rectangle"
  reasoning verify-look's finding demands, but nobody has looked at it yet.
- **Trash mobs are exempted from the screen tell — decided, not left open.** A first version had no kind
  guard: `is_phase2()` was pure hp arithmetic, and a pig at low hp (`max_hp`=30, well inside the same
  formula) drew the same "this got more dangerous" outline a boss does — wrong on its face, since a pig at
  12 hp got weaker, not stronger. Team-lead's call: gate it on the kinds that actually have a `MOVES` row
  ("the doc says nothing because nobody imagined it applying to a pig; that is an absence of intent, not
  permission"). **Fixed in `is_phase2()` itself** (`BossAi.has_pattern(kind) and hp * 2 <= max_hp`), not at
  the screen call site — one gate, not a copy guarding every caller separately. Confirmed by mutation:
  dropping the kind check fails 4 checks, including a pig at hp=1 drawing the tell.
- **Verified**: table values (fixed literals, not `PHASE2_SPEED_MULT`/`PHASE2_DURATION_DIVISOR` re-read), the
  `_phase_ticks` zero-guard driven directly at its boundary (`v`=1), the `is_phase2` threshold at all four
  edges (300/151/150/1 hp), `BossAi.advance` driven directly through three different transitions in both
  phases, the same ratio re-measured **end to end** through `Monster.on_tick`/`world.frame()` (not just the
  pure function), the charge-speed doubling through actual one-frame displacement (mirroring
  `_charge_moves_at_the_charge_speed_not_walking_speed`), and both screen-side wiring (text-scan) and driven
  (recording-subclass) checks — the same split `_draw_pattern_indicator`'s own test pair already established.
  Every check above confirmed to bite by hand-mutation before this stage was reported (`PHASE2_DURATION_
  DIVISOR` 2->3, `PHASE2_SPEED_MULT` 2.0->1.5, `is_phase2`'s threshold 1/2->1/3, the `_phase_ticks` guard
  removed, the screen wiring call deleted — five mutations, each caught).

**12-addendum — verify-read's own pass on Stage H, three closed, two recorded.**

- **① `_phase_ticks` has 13 call sites in `advance()`; the first version of `_phase2_scales_pattern_durations`
  measured 3.** Bypassing the scaling at exactly one of the other 10 (`WINDUP`->`FIRE`'s own
  `MOVE_FIRE["breathe_ticks"]`) stayed green — nothing forced every transition to actually run. **Fixed**: the
  test now drives one row per call site (18 rows — two call sites, the `LEAP`-ends-by-landing and
  `LEAP`-ends-by-safety-cap `STUN` transitions, are each exercised for both kinds sharing `Pattern.LEAP`),
  `advance()` called directly at both phases, **each phase-1 value pinned as its own fixed literal** rather
  than derived by halving phase-2's own result — an A/B comparison alone cannot catch "both sides silently
  vanished together" (this exact failure shape, CLAUDE.md's own words). Confirmed by mutation at two
  representative sites (`MOVE_FIRE["breathe_ticks"]` and `IDLE_TICKS`, one dict-backed and one bare constant):
  both caught immediately, one check each.
- **② The room ① confinement net spawned at full hp and never took damage, so it never measured phase 2** —
  the phase where every duration halves and the slam lands more often in the same wall-clock window.
  **Fixed**: one line, `m.hp = Defs.max_hp(kind) / 2`, before the fight loop starts. Confinement still holds
  at phase 2 (matches verify-run's own real-map measurement: 172 slams over 1,000s, leftmost x landing exactly
  on the boundary, box top 25px short — identical margin to phase 1, because `jump_vy_px` itself is not
  phase-scaled, only durations and charge speed are, per Stage H's own scope).
- **③ Recorded, not fixed — a charge that starts in phase 1 and crosses the half-hp threshold mid-run keeps
  the phase-1 duration but picks up phase-2 speed.** `speed_mult` is read every frame (live); `pattern_left`
  (the charge's own duration) is latched once, at the `WINDUP -> CHARGE` transition, and never re-read.
  verify-run measured it directly: **279.1 -> 558.1 px/s inside one 60-tick charge, 1,586px travelled** — 1.85x
  longer than either phase's own design produces on its own, and longer than room ①'s own 960px width. Nothing
  breaks (the bull still stops at a wall or the safety cap, whichever comes first) — but the number is real and
  is not what either phase's own tuning describes. **Not fixed here** — latching duration at launch and reading
  speed live are both deliberate, independent decisions from different stages (Stage B's own "a charge already
  launched does not abort... just because the player closed the distance mid-run", applied here to a stat
  crossing mid-run instead of a player); resolving the interaction is a design call (freeze the phase read at
  launch too, or accept the outlier), not a bug this stage introduced blind.

**Two more, both from verify-run, recorded because they read as defects later if nobody writes them down:**

- **Phase 2 changes the charge's speed, not its reach.** Pure phase-2 distance (a charge that starts and ends
  entirely within phase 2) measures 859px against phase 1's 849px — **the duration halving and the speed
  doubling cancel almost exactly**, so no room-geometry relationship (wall distance, the 960px room width)
  moves across the phase change. This is worth relying on, not an accident to "fix" later.
- **Phase 2 is not more dangerous to a player who keeps their distance.** A lap-running player takes 2.58 ->
  4.56 dmg/s (**1.77x**) but a retreating player takes 3.40 -> **3.00** dmg/s (**0.88x** — phase 2 is *safer*
  to retreat from). Cause: the charge covers the same ground twice as fast, so it overlaps the player's box for
  half as many ticks, and the 5-tick invulnerability spacing lands fewer hits per pass. **Faster, not
  stickier** — a tuning item for whoever balances this fight next, not a defect in this stage. The real fight's
  own shape, measured: phase 2 opens at 19.9s with a lap-running player on 36hp, who dies 9.9s later.
- **Phase 2 halves the windup telegraph too — verify-look's own finding, not acted on yet.** `_phase_ticks`
  scales every duration it touches, windup included, so `MOVE_CHARGE.windup_ticks`'s 0.85s telegraph becomes
  ~0.4s the instant a boss crosses into phase 2. The windup "!" was already measured weak at 1.0 zoom
  (acceptance 3's own split, stages A–E) — phase 2 lights it for **half as long, exactly when the boss gets
  more dangerous**, so the "when to dodge" channel gets *worse*, not better, right when it matters most.
  **Deliberately not changed here** — the user is being asked about the "!" size and this finding together, in
  one pass, rather than this stage guessing at a fix for a question already in front of the user.

**13. Stage I — the reward, then the wall collapses and water comes in.** Built to the plan's own scope: **the
seam only**, not the reward itself — the rune card through the three-pick window is milestone step 3
("Stage I's honest gap", above), untouched here. Acceptance 8b's own order is what this stage exists to
enforce: reward taken first, water second — water-first is the named failure.

- **The gate — `Progress._reward_pending`, keyed by kind, private** (the file's own no-inventory scan,
  `net_pick._no_pushed_out_glyph_is_stashed_anywhere`, forced this — a first version left it public and the
  scan caught it immediately, the same discipline `_drawn` already holds). **One field carries two facts**:
  presence as a *key* means "this boss has died at all"; the stored value means "is the reward still
  pending". `boss_died(kind)`/`is_reward_pending(kind)` ask the two questions separately so no caller has to
  re-derive the distinction (`false` alone cannot tell "never died" from "died, reward taken long ago" —
  both read `false` if the value were the only signal).
- **Set once, from `WorldStep`'s own death loop**, in the same one place XP/money are already awarded —
  `if BossAi.has_pattern(dying.kind): _progress.set_boss_reward_pending(dying.kind)`. Only bosses; a trash
  mob has no reward to gate, and setting one would leave a dict entry nothing would ever clear.
- **Cleared by one new debug key, L** (`stage_input.gd`'s `reward_taken_requested` signal ->
  `stage.gd._take_boss_reward()`), declared the same way as the plan's own words name — "in the same breath
  as M · N · F · T · G · K". **Only clears the gate** — it does not call `add_xp`/`add_money` (those already
  happen unconditionally for every kind) and does not grant a rune; granting the actual reward is step 3,
  explicitly out of scope.
- **Room ①'s water — new, not reused from the K-key debug rain.** A separate `WaterSource` instance
  (`stage.gd`'s `_room1_reward_water`), started automatically by `_take_boss_reward()` once the bull's
  reward clears, ticked in `_on_ticked()` alongside the existing K/F-driven `_water_source`. **Reuses
  `WaterSource` as-is, a known and named simplification, not a hidden one**: its own shape is "rain across a
  width, falling from above" (`water_source.gd`'s header), not literally "from the side" the way the design
  doc pictures the wall collapsing — `stage1-bosses.md`'s own earlier words already deferred this exact
  question ("whether the two pours share one implementation is [water-jump-and-escape.md]'s call, not this
  one's"), so reusing the one pour mechanism that exists, rather than inventing a second shape, is that
  deferral honored. The mismatch (rain, not a side breach) is recorded here, not hidden.
- **Room ③ (the rooster's own water) is not wired in this pass.** The mechanism (`Progress.reward_pending`,
  keyed by kind) is generic and already works for `KIND_ROOSTER` — `boss_died`/`is_reward_pending` answer
  correctly for it today — but no automatic room ③ pour is started on clearing it.
  `water-jump-and-escape.md` already owns a working, tested pour (the K key); this stage does not reach into
  that doc's own territory to wire it automatically. **A real, named gap**, not a silent one — the acceptance
  this doc's own headless test describes ("kill the bull -> water total stays 0 while pending; clear the
  reward -> water rises") is bull/room①-specific in its own wording, and that is exactly what got built.
- **Verified**: `Progress`'s own gate methods in isolation (`net_progress.gd` — starts empty, independent per
  kind, survives a no-op clear, reverts on `reset()`), the full sequence through a real `WorldStep` (die ->
  pending -> still pending after 200 ticks -> cleared by the explicit call -> `boss_died` stays true forever),
  and the debug key + water pour driven through the real `_physics_process()`/`_on_ticked()` loop
  (`net_render.gd` — water is absent before clearing, starts after, a second press does not create a second
  source, and pressing the key before any death does nothing). **Confirmed by mutation**: disabling the
  death-hook gate fails 5+ checks across two files (some as clean assertions, one as a null-pointer crash on
  `_room1_reward_water`, both counted as red by the wrapper); hardcoding `clear_pending_boss_rewards()` to
  only the bull fails the per-kind-independence check and, as a side effect, the before-any-death negative
  control too (creating a stray dict entry that reads as "died").
- **One shared-helper gap found and fixed along the way**: driving `_physics_process()` through
  `net_render.gd`'s existing `_wired_stage_root()` helper crashed the moment the water pour actually changed
  the grid (`_on_ticked()` calling `_renderer.refresh()` on a null `_renderer` — no earlier test using that
  helper had touched the grid enough to reach that line). Fixed by wiring `_renderer` in the shared helper
  itself, the same way `_ready()` does, rather than working around it in just this one test — the fix benefits
  every future test that drives a real tick through this helper, not only this stage's own.

**13-addendum — verify-read's own pass on Stage I, closed, and one finding that is not this stage's to fix but
must be written here regardless.**

- **Fixed: the dead guard in `_take_boss_reward`.** `clear_pending_boss_rewards()` ran on the line above the
  water-start `if`, so `not progress.is_reward_pending(KIND_BULL)` was **always true** by the time it was
  read — deleting the whole term changed nothing (moving the `clear` below the `if` would have). It read as
  protection and was actually a coupling to the line above it. **Fixed by dropping the term** — `boss_died(
  KIND_BULL)` plus the existing `_room1_reward_water == null` guard is the whole of what actually decides
  this, named honestly now instead of carrying a term that looked like a check.
- **Fixed: the room ③ gap is now cross-referenced from both places someone would actually look.** It was
  previously named only inside `_room1_reward_status()`'s own comment — someone chasing "I killed the rooster
  and nothing happened" reads the death loop (`world_step.gd`) and `_take_boss_reward` (`stage.gd`) first, and
  found nothing there before this fix. Both now carry a one-line pointer to the full account.
- **Recorded, not fixed — the water does not do what acceptance 8b says it does, on this map, and that is
  `stage1-map-layout`'s call, not this doc's.** Measured: **300s of pouring lifts the player 0px** —
  `standing_in_water` only re-opens the double-jump gate (`water-jump-and-escape.md`'s own mechanism);
  nothing in this game lifts a body with rising water. **And the gate is not needed on this map either**: one
  ordinary jump (102px rise) already clears room ①'s own 64px left step, so with **no water poured at all**
  the player is out of the room in **1.6 seconds**. The pool does eventually rise past the step's lip
  somewhere between 60s and 120s of pouring — **about 100 seconds after the player could already have
  jumped it.** The mechanism this stage built is correct and the order is correct (acceptance 8b's own
  words: reward first, water second) — but **"the water carries the player out of the pit"** is not true on
  the real map, and a reader who sees this stage marked verified must not mistake that for the sentence
  itself being satisfied. Whether room ①'s geometry should change, or the water should do more than gate a
  jump, is `stage1-map-layout`'s decision.
- **Recorded — "pressing L twice does not start a second pour" cannot be verified by watching the water, and
  should not be re-checked that way.** Measured: one source vs. two running from the same start point gave
  6,491 vs. 6,540 cells at 60s — 0.8% apart, because the pour saturates the room regardless of how many
  sources feed it. **The actual guarantee is a code invariant** (`_room1_reward_water == null`, checked before
  every assignment — verify-read's own finding: the variable is assigned in exactly two places in the whole
  file, one of them `null`), not a fact water volume happens to demonstrate. A future check of "does pressing
  L twice do something extra" belongs on that guard directly, the same way `net_render._reward_key_gates_
  room1_water`'s own "second press, same instance" assertion already reads the variable itself rather than
  the water total.

### Cost

**The boss is one monster; the expensive thing is its box.** `Body.box_free` sweeps covered cells in GDScript:

```
pig   44×32  ≈ 108 cells
bull  86×54  ≈ 345 cells   3.2× a pig
rooster 72×80 ≈ 399 cells  3.7× a pig
```

Scaling `monsters.md`'s player measurement (77–249μs at 81 cells) linearly puts one bull at roughly
**330–1,060μs = 2–6% of the 60Hz budget**. **That is a reading, not a measurement** — the same warning that
doc already carries about its own borrowed number. **Whoever builds stage A is the first person to measure a
boss box. Leave the measurement in a comment there.**

Fire, carving and water are all costs this repo has already measured and they are unchanged by this work —
the bull's fire runs through the same `_ignite_cell` and the same `MAX_BURNING` safety net.

### Out of scope

- **Per-state sprite animation.** `MONSTER_SHEETS` stays one image per kind. The 13 multi-frame sheets exist
  and stay unused. ⇒ **acceptances 3 and 11 ("it's visible that this is the window", "the telegraph is
  visible") ride on a `monster_view` indicator drawn from `pattern`, not on animation frames.**
  Doing it properly means making the table kind→state→sheet for **every** kind including trash mobs — one
  structure, not two — and that is `monsters.md` open question 16, which this doc explicitly disowned
- **The rune card** (step 3 of the milestone chain) — see stage I above
- **Map placement.** Nothing places monsters on the map today; only debug keys do. Bosses are the same. That
  boundary is `stage1-map-layout`'s
- **Whether trash mobs appear during a boss fight** — structurally "no" in this build, because nothing spawns
  monsters on the map at all
- **The rooster's reward** (research material + a glyph three-pick) — the three-pick half already exists
  (`grant_pick()`); the research material has no owner anywhere
- **Fixing `net_water_rain`'s 3 red checks** — they were red before this started

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
- ~~**How deep charge destruction goes** — accumulated, it breaches the room~~ → **measured, not undecided**:
  at the shipped `carve_r`=3, it does not accumulate at all (Risk 3-addendum — the `h_px`/`carve_r`
  cliff, box height 14 cells vs. hole height `2r+1`). What is still open is only whether `carve_r`
  should ever be raised past that cliff (`r`≥7) — a real design choice now, not a measurement gap
- **Does the rooster break terrain on landing** — same axis as the bull, undecided
- **Do trash mobs appear during a boss fight**
- **Boss reward** (rooster) — the GDD says "research material (permanent) + a glyph three-pick". **The three-pick screen doesn't exist yet**
- ~~**Sprites**~~ → **generated and picked by the user.**
  `assets/monster/bull_body.png` (86×54) · `assets/monster/rooster_body.png` (72×80).
  Local ComfyUI, `--preset monster`, generated at 4× and downscaled — same path as the trash mobs.
  **The rooster took two rounds** — the first came out as a farm rooster and the user said "more like a boss";
  what was picked is the **grey monstrous** one, not the red-plumed demon of the third round.
  **Only the standing pose exists.** Charge, stun, leap and landing frames are not drawn
- ~~**Phase transition presentation** — what is visible at half health~~ → **a first provisional answer
  shipped (Stage H)**: a thick, unblinking indigo/blue box outline (`Fx.MONSTER_PHASE2_COLOR`, ~230° hue),
  chosen deliberately on the strong side of verify-look's own finding (the windup "!" reads weak at 1.0
  zoom; the stun ring reads well) — size and constancy over a cleverer shape. **Not the user's decision
  yet** — TBD stays open until it is judged on screen

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
