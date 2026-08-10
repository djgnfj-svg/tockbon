# Unlimited jumping underwater and the escape — water touches the character for the first time

**Status**: active — **the code is finished. The user deferred the screen check** (decided by the user).

> ## ⚠ The K key this doc is built on was removed (2026-08-10)
>
> **The user cut the debug water** (「물 이제 필요 없고 빼주고」), and what went with it is
> **`rain_requested` + `KEY_K` + `stage.gd`'s `_water_source` / `_toggle_rain_at`** — every line this doc's
> "What actually landed" block lists under those names. `src/sim/water_source.gd` itself is **untouched and
> still runs**: room ①'s reward pour holds the only instance now (`stage.gd`'s `_room1_reward_water`).
>
> ⇒ **What is dead is the way a developer could pour water on demand**, which is exactly how this doc's
> screen check was going to be performed. **The deferred check now has no path to the screen** unless the
> bull is killed first, or K is put back for the day.
>
> **Room ③'s water escape — this doc's actual subject — is not affected**; it was never on the K key.
> `F` is now the town interaction, so **K is free and F is not**, if the key ever comes back.

**Deferred, not passed.** Water took long enough that the user cut it back to **"unlimited jumping underwater is
enough for now"**; the pour, the current and the escape **come back out and get looked at when that work reopens.**
⇒ **Nothing below is accepted**, and this doc does not move to `3.done/` on that decision.

**The line above goes stale more often than anything in this doc.** The table below is the source.

| Stage | State |
|---|---|
| **1 unlimited jumping underwater** | **Code done · passes by value** (acceptance 1·2·3). `net_character` A-1–A-4 |
| **2 fall acceleration K = 4** | **Code done.** **Measured 3.0×** (not 4.0 — band-boundary loss) |
| **3 approach-A pouring** | **Code done.** 12 seconds to 95% (target 5–15s). **One net, B-5, is red — below** |
| **4 current pushes** | **Code done.** F key 45 px/s. **It is 0 in the boss room** (design collision — below) |
| 5 underwater gravity | **Not doing it.** Acceptance 4 passed on screen — **no flailing. No grounds to open it** |

### Screen — verify-look looked twice. **Nobody has seen it since the striping fix**

**First pass (before the striping fix)**: **the reason this work started failed** — falling water was not a stream
but **horizontal stripes 48px apart.** The cause was not K but **the pour's temporal resolution** (one row per tick).
Acceptance 4·6·7 passed · no stutter · pooled surface clean · F-key current confirmed.

**Fix**: the pour was widened to a **`WATER_FALL_CELLS × WATER_SUBSTEPS` band of rows** ⇒ gaps are 0 in principle.

**Second pass**: **couldn't grab the bridge, so the screen wasn't seen** (another session's `godot-mcp` held it).
Confirmed by value only — **0 gaps** (was 11 cells) · fill time held at 12.0s · 0 shallow cells in pooled water.
**Instead a new worry was confirmed by value — per-cell amount dropped to 9, below `WATER_WET` (32)** ⇒
**for the first 1–2 seconds, 84% of the falling column takes the "shallow water" color (near-white pale blue).**
**It could read as a waterfall's white foam or as a malfunction. Value can't separate them.**

**⇒ Two things only the user can close**: ① does the falling water **read as a stream** (0 gaps is only necessary)
② **is the pale-blue column a waterfall or a malfunction.** And the original question — **"is water still background?"**

### Three things undecided — close them before moving this doc to `3.done/`

1. **Acceptance 5 ("it comes in from the side") doesn't match approach A.** A rains across the full width from above —
   nothing on screen would read as "the side wall collapsed". **Whether to fix the design or the pour is the user's call**
2. **Current strength** — `WATER_PUSH_PX` 130 is **10–17% of walking.** Visible standing still, barely felt while walking
3. **`g.step()` is 84ms/tick at the active-chunk cap** — **168% of budget (50ms).**
   It hasn't shown on screen yet (60 FPS) but **widening or speeding it up goes over.** Detail in `docs/design/water.md`, "Cost"
4. **A pour in room ③ can make a cleared run impossible to end.** The gate landed while this doc sat
   (`3.done/gate-ending-to-game.md`, its Risk 6): the ending seat's y band is 96px, **three tiles above the
   floor line**. Fill the seat deeper than that and the player floats out of the band — the arch is there, the
   clear is earned, and **nothing ends the run, with no error.** Room ③'s pour is this doc's, so the band is
   a constraint on it. **The gate does not solve this and does not claim to**

### Why the current is 0 in the boss room — three candidates hit the same wall

**A room that fills fast and evenly is by definition near equilibrium, and equilibrium means no force in any direction.**
Horizontal, vertical and inflow are all 0. "Fills fast" and "pushes" are **two ends of one knob.**
⇒ spec recommends **④ accept it** (the axis for water touching you in the boss room was always unlimited jumping).
Detail in `docs/design/water.md`.

### One net is red — carried over from the map doc

```
net_water: active chunks stay below the cap (100) while pouring (max 100)
```

**Caused by removing the pit's temporary ramp** (`3.done/stage1-map-layout.md`). A flat floor means
**water falls across a wider area at once** and hits the cap. With the ramp it measured **39–81 chunks.**
FPS doesn't die — **water gets delayed.** The cap is a safety net.

⇒ **Two knobs, both on this doc's side**: lower the pour rate (`WATER_RAIN_PER_TICK` 20,000) or
step the pit floor. **Re-baking the map is the last resort** — removing the ramp is the grounds for
"the only exit is water", so reverting kills the design.

###  그 그물은 통과했다. 대신 다른 셋이 빨개졌다 — **구덩이가 없어졌다** (2026-08-08 저녁)

**사용자가 맵 전체를 처음 눈으로 보고 왼쪽 절반을 다시 그리게 했다**(「이걸로 해줘 이게 맞아」) →
[../3.done/stage1-map-layout.md](../3.done/stage1-map-layout.md) 머리. **① 은 이제 구덩이가 아니라
계단 6단으로 걸어 내려가는 넓은 평지다.**

```
 net_water_rain_cap: 활성 청크가 상한 아래에 머문다     ← 계단 바닥이 위 두 손잡이를 대신했다
 net_water_rain: 구덩이 오른쪽 끝도 열려 있다 (전제)
 net_water_rain: 물이 안 샌다 · 부은 양이 소스와 정확히 같다
```

`_PIT_ROW`(타일 26)에서 **좌우가 막힌 그릇**을 전제하는데, 그 행이 이제 계단이라 **열려 있다.**
⇒ 물이 왼쪽 계단으로 넘어간다.

 **좌표를 옮겨서 될 일이 아니다.** 이 문서의 뼈대가 **「① 에서 나가는 길이 물뿐」**인데
**지금은 계단으로 걸어 나온다.** 사용자는 「구덩이보다는 계단」이라고 명시했고 그 화면을 보고 확정했다.
⇒ **먼저 정할 것은 하나다: 물이 여전히 ① 의 탈출 수단인가, 아니면 물 장면이 ③ 보스방으로만 가는가.**
**정하기 전에는 `net_water_rain` 을 손대지 않는다** — 좌표만 맞춰 초록으로 만들면
**죽은 설계를 재는 가짜 그물**이 된다.

**This doc's title is now narrower than its scope.** The user said, having seen it —
**"I keep feeling the water is background. The water has no effect on me whatsoever."**
⇒ The user decided **"put in the current too and finish water this round".** **There are four axes**:
**① unlimited jumping underwater · ② fall acceleration · ③ the current pushes · ④ approach-A pouring**
(concepts for ②③ in `docs/design/water.md`, "falling has no acceleration" and "water pushes the character").

**Still out of scope**: the boss-death hook · the gate and water · monsters and water · fallback text · drowning · buoyancy.
**One line**: underwater there is no jump limit. Beat stage 1's boss and water rises, and the player
**climbs by jumping repeatedly and works that out for themselves.**

**Map placement is a separate doc** → [../3.done/stage1-map-layout.md](../3.done/stage1-map-layout.md)
**Concept source**: `docs/design/water.md` — especially the last section, "water pushes the character"

---

## Why

**The character currently knows nothing about water.** Sweeping `character.gd` and `body.gd`,
`WATER` references number **zero.** Water is `BEHAVIOR_NONE`, so `is_solid()` is false and
**to the character it is identical to empty.** No buoyancy, no drag, no sinking.

**Asymmetric with fire** — `character.gd:302` calls `_body.standing_in_fire(grid)` and that function
(`body.gd:155-164`) sweeps the box cells plus the row underfoot asking `grid.is_burning()`, so fire reaches the character.
**Only water doesn't.**

`docs/design/water.md` left this:

> **Water has weight. Enough of it flowing at you pushes you** — this is the core
> **Floating on water** came up too. **Buoyancy or swimming was not decided**

⇒ **Decided. Neither buoyancy nor swimming — the jump limit is removed.**

### Why this is a good answer — three reasons

**1. Nearly free.** The jump condition is currently:

```gdscript
# src/actor/character.gd:262
if jump and on_ground and not downed:
    vy = JUMP_VY_PX
```

The condition is **only `on_ground`.** Adding `or in_water` does it.
**No new physics axis called buoyancy** — the water doesn't push you up; **you climb on your own.**

**2. The progression language locks together.**

```
④  double-jump lock     ── somewhere you reach with one more jump
③  unlimited jumps in water ── in water there is no jump limit
```

Not two unrelated gimmicks but **two instances of one grammar.**
"Jump count" becomes this game's progression axis.

**3. Stage 1's final scene is stage 2's tutorial.**
Stage 2 is the water stage, so the movement grammar learned here transfers directly.
**The body learns before any text does** — that is what the user wanted
("I want the player to jump around and realize that jumps are unlimited in water").

**Text is the fallback** — put it on screen if they don't work it out (the user said so). See "TBD".

---

## Behavior

### ① Unlimited jumping underwater

- **If the water amount in the character's cell is at or above the threshold**, the jump limit lifts
- **Jump any number of times**, regardless of being grounded
- The jump's own value (`JUMP_VY_PX` −720) is reused — **whether it should differ underwater is TBD**

### ② How "am I in water" is known

Read the water amount at the character's position from the grid.

**The folder contract isn't broken.** `body.grounded(grid)` already reads the grid, and
`is_solid` and `is_burning` are the precedent. **Water → character is a read and safe.**
**The reverse is not** — a character pushing water lets float (`src/actor/`) invade integer determinism (`src/sim/`).

**A threshold is needed.** Unlimited jumping in an ankle-deep wet stain would be strange.

- `WATER_WET` (32) is already **the shallow-water line** and **the fire-extinguishing line**
  ⇒ reusing it means "not in bright sky-blue, only in dark navy" is **already drawn on screen**
- **The price**: `WATER_WET` now sets **color · fire-proofing · jumping.** Tune one and the other two follow
- **Which cell to look at must also be decided** — underfoot · torso center · head.
  The character is 32×32px = 8×8 cells, so **different cells give different answers**

### ③ Underwater gravity

**At current gravity, a jump may sink back fast enough that "jump jump" feels like flailing.**

```
GRAVITY_PX     2400.0
MAX_FALL_PX    (character.gd)
JUMP_VY_PX     -720.0     ⇒ peak height 108px = 3.4 tiles
```

Lowering gravity and max fall speed underwater is standard.
**This is a value you must see to know. Measure and tune** — the doc doesn't pre-set the number.

**Touching only one of `GRAVITY_PX` and `JUMP_VY_PX` goes silently wrong**
(`character.gd:75` gives the reason — reachable height moves as a square).

### ④ Beat the boss and water comes in

**Room and source are settled**: **a 20×12-tile room · the side wall collapses.**

**"Side wall" was chosen for performance** — terrain having held the water back is natural, and
**the collapsed hole's size becomes the pour-rate knob directly.** Pouring from above is the most
expensive (water in mid-fall), and there is no path for it to well up from below.

- **The side wall of boss room ③ (20×12 tiles) collapses and water fills the room**
- The player escapes **by climbing with repeated jumps**
- Rising water is **both the pressure and the means of escape** — **it works without building drowning**

**The path for pouring water already exists.** `cell_grid.set_water()` (`cell_grid.gd:1088`) is the grid's official door
and `stage.gd:304` calls it — the function is `_pour_water_at` (`stage.gd:293`), wired at `stage.gd:241`,
key at `stage_input.gd:104` (F). Same place as `ignite()`. Attaching it to boss death is the same place.

**But "at what rate does it pour" is this feature's core value.** See "Cost".

---

## Screen

- Water **comes in from the side and rises.** The surface visibly climbs
- Entering the water, **jumps keep working** — **with no indicator.**
  **That is intended** (the player works it out). Fallback text is TBD
- **Is being underwater distinguishable on screen** — shallow and deep water already differ in color (`FLAG_SHALLOW`).
  **Nothing changes on the character** — no wet marking, no bubbles

**What `docs/design/water.md` warns about**: a still surface isn't uniform, so
**"short sky-blue fragments floating above the surface" read as a stain.** It may look different while rising,
and **that was never measured.**

---

## Boundary

| | |
|---|---|
| **Not in shallow water** | At or below the threshold (`WATER_WET` 32) it behaves as usual |
| **The character doesn't push water** | Folder contract. Read only |
| **Monsters?** | **TBD.** What happens to pigs and chickens in water is undecided |
| **There is no drowning** | Being submerged does nothing. Unlimited jumping takes that place |
| **Being pushed by current is not this doc** | `docs/design/water.md`'s "water has weight" is **still TBD** |

---

## Cost — the **nature of the risk changed in one day**

**Check dates when reading this section. This value flipped three times in two days.**

**Measured** (verify-look, with `MAX_CHUNKS_PER_TICK` = 512):

| Water cells | Active chunks | Real FPS |
|---|---|---|
| 16,384 | 85 | **229** |
| 24,576 | 126 | **6** |
| 32,768 | 165 | **4** |

**Not a slope — a cliff.**

### But then **the cliff disappeared**

Lowering `MAX_CHUNKS_PER_TICK` **512 → 100** made **cost independent of water volume**
(`docs/design/water.md`, "Acceptance 7": at 65,677 cells, 512 is **724%** of budget, 100 is **a flat 219%**).

**⇒ This feature's risk changed from "the game freezes" to "water flows slowly".**

**That does not mean it's an easier problem.** The cap is **a safety net, not a tuning knob**,
and overflow chunks push to the next tick ⇒ **on screen the water rises slowly.**
**Water slowing during the escape scene means the presentation is broken** — the FPS survives and the scene dies.

**And there is still a user decision pending — cap 100 vs 33** (`water.md`, "Acceptance").
**Dropping to 33 makes water slower** ⇒ **this scene is that decision's first stakeholder.**

### The arithmetic — no longer "does FPS survive" but "does water arrive at the right rate"

**The boss room is settled at 20×12 tiles.**

```
20×12 tiles = 160×96 cells = 15,360 cells
one surface row of 160 cells = 10 chunks wide × 2–3 bands ≈ 20–30 chunks
```

**Still water is cheap** — at equilibrium that piece sleeps (measured: still water is 7–18 chunks).
⇒ With the bottom asleep and only the surface band active, that is **20–30 chunks.**

**`WATER_SUBSTEPS` is 3, so one chunk runs 3 times per tick** ⇒ the cap of 100 has an effective width of **≈33 chunks**
(`sim_tuning.gd:120`. `MAX_CHUNKS_PER_TICK` is at `:160` — don't confuse the two).
**The estimated 20–30 sits right on that line.**

**Crossing the line doesn't kill FPS — water gets delayed.** That is how the cap was designed (a safety net).
⇒ **Measure acceptance as "how many tiles per second does it rise".** **Watching FPS alone passes while the scene is dead.**

A 30×20 room would have been 30–45 chunks and definitely over — **shrinking the room bought headroom.**
**Still an estimate, not a measurement.**

### So measure before building

**It can be measured headless** — build a boss-room-sized grid, pour N cells per second, and
**observe active chunk count per tick.** That is the first job for whoever opens this doc.

**The knob is the pour rate.**
- Pour slowly → the bottom reaches equilibrium and sleeps, only the surface band active ⇒ cheap
- Dump it all at once → the whole room flows at once ⇒ hits the cap and **water gets delayed**
  **In the cap-512 era that was 6 FPS.** Now it doesn't die, it **slows**

**`MAX_CHUNKS_PER_TICK` (100) is a safety net, not a tuning knob.**
Over it, you see **"water flows slowly for a moment"** and it never stops or vanishes —
**but water slowing during the escape scene means the presentation is broken.**

### Room size is the budget — which is why 20×12 can't grow

**The user chose 20×12 for this reason** (from 30×20 · 40×10 · 16×24).

**That value is written in the map doc (`stage1-map-layout`) but its grounds are here.**
**If someone enlarges the room because "the boss fight is cramped", this scene dies.** The two docs meet here.

**Two pressures come from the boss side** ([stage1-bosses.md](../3.done/stage1-bosses.md)):
- **The rooster leaping and pouncing needs vertical room** — 12 tiles may be tight
- **"Does the rooster break terrain on landing" is TBD.** If it does, **the room when water arrives is larger
  than 20×12** ⇒ decided that way, **the measurement must be redone at that larger size**

The bull's charge destruction belongs to room ① and is unrelated here.

---

## Acceptance

**Write what was seen by eye under this section immediately** (CLAUDE.md).

1. **Jumps keep working underwater** — any number of times, without ground
2. **They don't work in shallow water** — an ankle-deep stain behaves as usual
3. **Leaving the water re-limits it** — going above the surface mid-air stops further jumps
4. **You can climb by jumping** — **climbing, not flailing.** The underwater gravity value splits here
5. **Beating the boss brings water in** — it rises from the side
6. **Water arrives at the right rate** — **this feature's biggest risk.**
   **Do not measure it with FPS.** The cap dropped to 100, **the cliff is gone**,
   and overflow now delays **water, not FPS.** ⇒ **Measure "how many tiles per second it rises"
   and look at whether that value works as presentation**
7. **The escape works** — the rise rate and the climb rate match so there is **tension without being trapped**
8. **The player works it out alone** — with no text. **If this fails, add fallback text**
9. **The surface doesn't read as a stain** — how `water.md`'s "short sky-blue fragments" look while rising

### Result — verify-look **saw the screen for the first time**

**Scene**: the real pit ① (cells x1888–2063 · entrance y208 · floor y312 = **176 cells wide · 104 tall**,
exactly matching the headless measurement). `_toggle_rain_at()` was hooked to the pit's entrance row,
**pouring through the shipping path.** The game was frozen and stepped frame by frame.

#### The biggest thing — **the trickle didn't go away. It got more pronounced**

**This was the reason the work started, and it fails here.**

Falling water is not a stream but **horizontal stripes.** Confirmed by reading the grid (column cx=1975):

```
y208 aux=112      ← source row
y209–219 all 0
y220 aux=112
y221–231 all 0
y232 aux=112 …    repeating exactly every 12 cells (9 stripes at the observed moment)
```

**Counting per row gives the same — rows with water are 176 cells full, rows between are 0.**
⇒ On screen, **several bright sky-blue horizontal lines crossing the pit's width descend 48px apart.**
**A continuous stream never forms, not for one instant.**

**The cause is not K — K only widened the gaps.**

```
the pour makes one row per tick        (approach A: one pass over 176 cells per tick)
the fall drops K × WATER_SUBSTEPS per tick = 4 × 3 = 12 cells
⇒ stripe spacing = 12 cells = 48px      (exactly the observed value)
```

**When K was 1, the spacing was 3 cells (12px) and it effectively looked continuous.**
⇒ **Stage 2 (fall acceleration) went in to fix the trickle and went backwards on screen.**
**The values were right** (3.0× faster). **What was wrong is the premise that "faster looks like a stream".**

⇒ **The knob is not K but the pour's temporal resolution** — as long as one whole row is made per tick,
the spacing is always `K × SUBSTEPS`. (This doc records only the direction. What to do is the design's call.)

#### Per acceptance check

| # | Result | What was seen |
|---|---|---|
| 4 | **Pass — no flailing** | Trajectory below |
| 5 | **"From the side" doesn't hold** | A pours **from above across the full width.** **Nothing** on screen would read as "the side wall collapsed and it's coming in" |
| 6 | **Pass — the right rate in the real game** | Volume 13.6%@2.3s → 39%@5.4s → **85%@10.7s** ⇒ 95% around 12s. Matches the headless 12.6s |
| 7 | **Pass — the water level is the gatekeeper** | Below |
| 8 | **Not seen** | Only the user judges it |
| 9 | **Half** | Below |

**Acceptance 4 — the trajectory was measured frame by frame and watched.** Standing on the floor, jump was
tapped at **5Hz (every 200ms).** y sampled every 100ms (smaller is higher):

```
1216 1171 1174 1129 1132 1087 1090 1045 1049 1003 1007 961 965 919 923 877 881 836
```

⇒ **Exactly 42–45px of rise per 200ms cycle, with only 3–4px of sag between.**
**Not a picture of flailing. It climbs as regularly as a staircase.**
**From the floor (y1216) to above the entrance (y800) is 416px = 13 tiles, climbed in about 2.0 seconds.**
⇒ **No grounds to open stage 5 (underwater gravity).** Default gravity is fine.

**Acceptance 7 — "tension without being trapped" actually holds.** The trajectory's tail showed it:

```
… 836 839 (867 897) 854 844 801
              ↑ above the surface the jump cut out and it fell 58px back
```

**Acceptance 3 (limited outside water) worked live on screen, and that *is* the gatekeeper** —
a jump only reaches **surface + one jump height (108px)**, so **you can't leave until the water level is
within 108px of the entrance** (computed 74% ≈ 9 seconds). ⇒ **Waiting is enforced.**
**But once you can leave, the margin is large** — climbing at **208 px/s** against a **35 px/s** surface rise, **6×**.
**It doesn't feel like being chased.** The tension comes from "I can't get out yet", not from "it's catching me".

**Acceptance 9 — the pooled surface is clean, and floating stripes took its place.**
**`water.md`'s warned-about "short sky-blue fragments above the surface" were not visible** — pooled water is
**a completely flat, uniform navy mass** with a knife-straight top. No stain.
**Instead, bright sky-blue lines crossing the full width float in the air above the surface** (2 lines at the 85% mark).
**It is not `FLAG_SHALLOW`** — confirmed (`shallow=false`). **The brightness splits by amount (112 vs 255).**
⇒ **Worse than warned.** Not short fragments but **bands crossing the screen.**

#### Current (F key) — **it pushes. Just not "shoves"**

Standing on flat ground (the pit floor), a water blob was dropped to the left with F. 2.0 seconds observed:

| | Value |
|---|---|
| Movement | **+49px** (to the right) |
| `water_flow()` max | **87** / 255 ⇒ push speed **44 px/s** |
| Steady segment | flow 44–50 ⇒ **23–25 px/s** |
| Vs walking speed | **max 17% · typical 10%** (`MOVE_SPEED_PX` 260) |

**Standing still, you visibly drift** (1.5 tiles in 2 seconds).
**Start walking and it's barely felt.** Matches the plan's "45 px/s" — **the value is right, the strength judgment remains.**

#### Performance — **no stutter. B-5's failure isn't visible on screen**

**60 FPS held** (throughout the pour). Active chunks ranged **76–100**, frequently touching the cap of 100, and
**no break or jitter in the water was visible on screen.** The fill rate was as even as the table above.
⇒ **B-5 (the net) doesn't need fixing for this reason.**

**But the pour's first 0.3 seconds only stack on the source row and don't descend one cell** (all 176 cells saturate to 255).
**It looks like nothing happens for a moment after pressing the key.** The HUD's "accumulated" counter is the only signal.

#### Scope of confirmation

- Seen via **4 screenshots** with the game frozen and stepped. **The user has not seen it.**
- **Acceptance 8 (do they work it out) cannot be closed here in principle.**
- **The boss doesn't exist in code** ⇒ **the "beat the boss" part of acceptance 5 wasn't and couldn't be seen.**
  What was seen is only "how approach-A pouring looks on screen".
- **The HUD was toggled while watching** — the rain status line ("rain on · accumulated N") **is visible and its values move** (confirmed).

---

### Result — **after the striping fix** (verify-look). **The screen wasn't seen — the bridge wasn't available**

**Pin the scope first. This block is not a screen judgment.**
The editor came up, but **another session's `godot-mcp` (PID 30544) grabbed the bridge first** and this client
was refused repeatedly (`Another client is already connected`, 11 times).
**No workaround was attempted** (CLAUDE.md · `agents/verify-look.md`). ⇒ **Everything below is headless values.**
**"Does it read as a continuous stream" and "is the bright sky-blue ugly" remain unseen by anyone.**

**Method**: the **shipping `WaterSource`** was run in the same place as the net —
`Stage.build_terrain_into()` built the real pit ①, settled for 400 ticks (active chunks confirmed 0), then
`WaterSource(1888, 2063, 208, 20000)` ran for 240 ticks (12 seconds) watching **column x=1975** (the exact column where striping was seen).

#### 1. Striping — **gone, by value**

**All 12 samples (every 20 ticks to 240) had a maximum gap of 0 cells.** The previous observation was 11 (`K×substeps−1`).

```
per-cell amount = 20,000 / (176 × 12) = 9      ← the old way was 113
band = WATER_FALL_CELLS(4) × WATER_SUBSTEPS(3) = 12 rows
```

**But that is only "there are no empty cells".** **"Does it read as a continuous stream" is a different question and wasn't seen** —
even with 0 gaps, **an amount that steps per row can still read as banding.** Item 2 below is exactly that worry.

#### 2. Color — **the worry is confirmed by value. Falling water turns bright sky-blue**

**9 per cell is at or below `WATER_WET` (32)** ⇒ `_write_water` sets `FLAG_SHALLOW`, and
**the shader swaps the color wholesale on that flag alone** (`cell_grid.gdshader:66` — **no shading by amount at all**).

| | Value | What it looks like |
|---|---|---|
| Deep water | `0x1B3E5E` = RGB(27,62,94) | **Dark navy** |
| Shallow water | `Color(0.62,0.86,1.0)` = RGB(158,219,255) | **Near-white pale blue** |

**These two were deliberately pushed as far apart as possible by the user** (to make "why can't this water put out
fire" readable on screen). ⇒ **They don't blend in between. They split hard.**

**Measured shallow-cell ratio** (above the surface = mid-fall):

| Tick | Sec | Shallow / total, falling | Shallow, pooled | Fill % |
|---|---|---|---|---|
| 20 | 1.0 | **14,784 / 17,600 = 84%** | **0** | 8.1% |
| 40 | 2.0 | 3,696 / 17,072 = 22% | **0** | 16.3% |
| 100 | 5.0 | 1,584 / 11,968 = 13% | **0** | 40.7% |
| 200 | 10.0 | 1,584 / 3,168 = 50% | **0** | 81.4% |
| 240 | 12.0 | 352 / 352 = 100% | **0** | 95.3% |

**How to read it — two phases:**

- **First 1–2 seconds: the falling column is bright end to end** (84%). Water hasn't merged yet, so whole columns are 9–27.
  **This is the most visible moment** — the first impression of "water pours in" is **a pale-blue column**
- **After that: only the top 9 rows are bright, the rest dark.** 1,584 = **176 × 9 rows**, fixed
  (merging pushes it past 32 further down). ⇒ **only a 36px band under the source is a bright gradient**
- **Pooled water has not one bright cell — 0 throughout.** The surface will be as clean as last time

**And unlimited jumping doesn't break** — the jump condition is "WATER and not `FLAG_SHALLOW`", and
**pooled water's shallow count is 0 throughout.** ⇒ **Acceptance 1–4 are unaffected by this change.**
**But jumping doesn't work inside the falling water** (as designed — though nobody has seen that situation).

#### 3. Acceptance 6 (fill rate) — **no noticeable change**

| | 25% | 50% | 80% | 95% |
|---|---|---|---|---|
| **Before** (real game) | ~4s | ~6.5s | ~10s | ~12s |
| **After** (headless) | 3.1s | 6.1s | 9.8s | **12.0s** |

**Effectively the same.** Per-cell dropped 113→9 and the band became 12 rows, taking per-tick total from
19,712 → 19,008 (−3.6%), **which is not a visible difference.**
**One side of the comparison is the real game and the other headless** — they matched well last time, so they're
placed side by side, but **strictly they are different scales.**

#### What remains — **it needs human eyes to close**

1. **Does the falling water read as a stream** (0 gaps is necessary, not sufficient)
2. **Does the first 1–2 seconds' pale-blue column read as a waterfall or a malfunction?**
   **It runs the same direction as real waterfall foam, so it may be better. Value can't separate them**

**Only noting that a knob exists** (what to do is the design's call): raising per-cell 9 above `WATER_WET` (32)
requires **raising the per-tick total ~3.6× (≈72,000)** or lowering the band, but **the former makes filling 3.6×
faster and breaks acceptance 6, and the latter brings the striping back.** **Three things are tied to one knob.**

---

### Result — after stages 1·2, verify-read · verify-run (headless, both independent)

**Nobody has seen the screen.** Everything below is values. **Acceptance 4·5·7·8·9 do not close here.**

**Acceptance 1·2·3 — pass by value.**
`net_character` A-1–A-4 green (38/38). And verify-run separately measured **combinations the net doesn't see** —
the net deleted water to get the character out, so it **never left by actual movement**:

| Scene | Result |
|---|---|
| Jump in a shallow pool → body fully above the surface 8 frames later → attempt a jump | **Didn't work** (gravity only) |
| Submerged again 30 frames later → attempt a jump | **Worked** (vy = −680) |
| **Horizontal** deep/shallow boundary | Transitioned exactly at cell 800 (0 cells of error) |

**But A-4 was fake** — its label says "includes the row underfoot" and it **never measured that row at all.**
Deleting the underfoot check still gave 38/38 green. The cause was that between one `step()` call,
**the character fell 1px and the box's own bottom edge entered the water row.** ⇒ **Being rewritten.**

**Fall K=4 — not "4×" but 3.0×.** Detail in `docs/design/water.md`, "falling has no acceleration".
Two independent measurements agreed (640 · 642.9 px/s). **Zero ticks stalled in mid-air.**

**Acceptance 6 — the time is within target while chunks touch the cap. The two disagree.**

| % | Now (K=4 · volume basis) | Old measurement (row basis — **different method, not directly comparable**) |
|---|---|---|
| 25% | **4.0s** | 5.0s |
| 50% | **7.1s** | 8.0s |
| 75% | **10.2s** | 9.0s |
| 95% | **12.6s** | 11.0s |

**All within target (5–15s).** No overflow either (the scan box's top boundary was never reached).

**But B-5 ("active chunks stay below the cap of 100 while pouring") is failing.** Ticks 1–51 sit at the cap
(terrain-building spikes excluded). This differs from "39–81, never touching the cap" above.

⇒ **The current state is "delayed but fills on time".** **Do not fix the net to make it green** —
acceptance 6 was always **"measure how many tiles per second it rises and look at it"**, not a chunk count.
**Handed to the screen judgment.**

**Cause diagnosis — the two verifiers disagreed, and the direct-evidence side was taken:**

| Who | What | Grounds |
|---|---|---|
| verify-read | **The map** | **Setting K back to 1 fails identically** (peak 100). K only makes it arrive sooner (37 ticks → 13) |
| verify-run | **Possibly** the fall K | Stated as an estimate itself |

⇒ **verify-read has the direct evidence** (it actually reverted K and measured). **The map change is taken as the cause** —
another session re-baked the map during this work (08:50:39), removing the pit's ramp and making it a square shaft.
That map work is **finished** (`stage1-map-layout` went to `3.done/`). The floor is stable now.

**Observation discipline** — verify-run's first run **stepped on a window where the tree was moving**
(`body.gd` · `character.gd` · `cell_grid.gd` · `sim_tuning.gd` mtimes all changed at once), producing a
**fake failure value** ("892 cells don't even arrive in 200 ticks"). **That value was discarded**, and every
adopted value came from runs whose **before/after hashes matched** (reproduction confirmed).

---

### Result — earlier, verify-run measured headless

**Acceptance 6 failed. "The side wall collapses and it comes in" does not fill the room.**

Measured with the real stage-1 pit ① (x236–258 · y28–42 = 22,080 cells).

| Pour method | Max active chunks | Time to sleep | Surface rise |
|---|---|---|---|
| **Fill everything at once** | **100 (at the cap)** | **17 ticks = 0.85s** | None — flat from the start |
| **From the side (dam break, left third only)** | **100 (at the cap)** | **5,631 ticks = 281.6s** | initial **0.19 tiles/s** → after 1,500 ticks **under 0.01 tiles/s** |

**Neither is usable.** All at once means **there is no rising picture at all** (over in 0.85s);
from the side takes **4 minutes 30 seconds.**

**The cause is diffusion.** Amount-based water halves, so **flattening takes time proportional to the square of the width**
(same place as the measurement box in `docs/design/water.md`, "the decisive reason for amount").
⇒ **This doc's assumption "the hole size tunes the pour rate" is wrong** — the bottleneck is not the hole but
**how fast water spreads sideways**, which has nothing to do with the hole.

**Active chunks hit the cap of 100 both ways** (3× the effective width of ≈33) ⇒ **water gets delayed.**
FPS still doesn't die (the cliff is gone).

**Leakage is 0** — not one cell escaped past the walls (x232–235 · x259–262) or below the floor. The bowl is sound.

**⇒ A different method is needed** (TBD. Candidates):
- **Add a little across the pit's full width every tick** (like rain) — the surface rises evenly and doesn't wait on diffusion
- **Add at several points at once** — shortens the distance to spread
- **Make the pit narrower** — halving width cuts diffusion time quadratically

**The presentation speed must be decided first** — "how many seconds should 15 tiles take".
Once that value exists, which of the three fits follows.

### Result — verify-run re-measured alternatives A/B/C headless

**The map changed in between** — the pit ① now measures **x1888–2063 cells (tiles 236–258) ·
entrance y208 (tile 26) · floor y311 (tile 38) · 13,312 empty cells = 208 tiles · 13 tiles tall.**
Measured by building the real terrain with `Stage.build_terrain_into()`, matching the 208 tiles / 13,312 cells above exactly.
**The first scan was wrong** — taking wide x·y ranges and looking only for EMPTY also caught **the open sky above the pit,
giving 889 tiles.** Only after requiring that a row have STONE at one point inside the left wall (tile 231) did 208 come out —
**the observation tool itself must be inverted before it can be trusted**, a lesson that recurred inside this re-measurement.

**A. Full width (176 cells), like rain every tick** (the total divided across the entrance row every tick):

| Per-tick total | 25% | 50% | 75% | 95% (near full) | Max active chunks | At cap (100) |
|---|---|---|---|---|---|---|
| 2,000 | 22.0s | 41.0s | never (>60s) | never (>60s) | 100 | first 29 ticks only |
| 8,000 | **9.0s** | 14.0s | 19.0s | 23.0s | 100 | first 29 ticks only |
| 20,000 | **5.0s** | **8.0s** | **9.0s** | **11.0s** | 100 | first 29 ticks only |

**20,000 per tick lands exactly in the 5–15 second range** (5.0–11.0s). 8,000 is also in range for 25–50% (9–14s)
with only 95% slightly over at 23s — **if the escape doesn't require a full room, 8,000 works too.**
**Active chunks touch the cap of 100 only during the first terrain-building ticks; while pouring they range 39–81,
staying under 100** — "water gets delayed" doesn't occur at this width (23 tiles) and this rate.

**B. From 5 points only** (each hole 1 tile = 8 cells, 40 cells total):

| Per-tick total | 25% | 50% | 75% | 95% | Max active chunks | At cap |
|---|---|---|---|---|---|---|
| 2,000 | 22.0s | 43.0s | never | never | 100 | first 28 ticks only |
| 8,000 | 9.0s | 15.0s | 20.0s | 23.0s | 100 | first 28 ticks only |
| 20,000 | 7.0s | 12.0s | 16.0s | 19.0s | 100 | first 28 ticks only |

**B is worse than A** — same total, slower (at 20,000, A reaches 95% in 11s, B in 19s).
**Concentrating into 5 points gains nothing at this width (176 cells) since diffusion isn't the limiter there;
it only adds time for locally piled water to spread sideways.** ⇒ **No reason to choose B. A is simpler and faster.**

**Do not make the holes 1 cell** — the first measurement used five 1-cell holes and **2,000 · 8,000 · 20,000 all gave
identical results (down to 1,503,225 total poured).** Different amounts giving identical results was itself the evidence
that **the cell's drain rate (capped at 255) is the bottleneck, not the pour rate** — only widening the holes to
8 cells (1 tile) made the totals matter.

**C. Bowl width vs time to fully sleep** (dam break — the whole amount into the left third at once):

| Width | Time to sleep | Max active chunks |
|---|---|---|
| 22 tiles (close to the real width) | 195.4s | 17 |
| 12 tiles | 71.0s | 13 |
| 8 tiles | 36.2s | 10 |

**Narrowing doesn't get the dam-break method to target (5–15s)** — even the narrowest, 8 tiles, is 36.2 seconds.
The hypothesis's direction is right (22→8 tiles is 5.4× faster, short of the 7.6× width-squared ratio but clearly superlinear).
**But this measures "flattening completely and going to sleep", which is too strict a bar** — the escape only needs the
surface near the entrance, not the whole grid asleep.
⇒ **C is valuable as hypothesis confirmation but is not this problem's solution.**

**⇒ Conclusion: use A (rain across the full width, around 15,000–20,000 per tick).** The current boss room width
(20×12; the pit measures 23 tiles) needs no shrinking — **changing only the pour method fills this width in 5–15 seconds.**
B gains nothing and is dropped. C (narrowing) is kept only as grounds that more headroom is available if needed.

**Not measured**: "95%" was measured on a uniform-fill basis (a row counts as risen once over 50% of the width is wet),
which should roughly match the impression of "nearly full" on screen but **hasn't been seen** — verify-look's job.
And **whether the player really escapes by jumping within those seconds** (jump height and speed against the surface rise)
was not measured — no character was instantiated.

**Tree stability during observation**: `src/` and `tests/` had identical start and end hashes.
`stage1-map-layout.md` (then in `2.active/`, now `3.done/`) changed mid-measurement (another session was recording
verify-look results), but that file is not the terrain source and matched the pit measurements above (x1888–2063 etc.)
exactly — they confirmed each other, so the results stand.

---

## TBD

**Do not force these full.**

- **Underwater gravity and max fall speed** — decided by eye.
  **Still TBD, and that is the plan** — stage 1 goes with **default gravity** and this opens **after acceptance 4** (stage 2)
- ~~**Which cell's water to read**~~ — **closed: the same range as fire.**
  `body.gd:155 standing_in_fire()` already sweeps "the cells the box covers + the row underfoot". **Put it beside that, same shape.**
  Reason: a new range produces **"fire is extinguished but jumping doesn't work"**, and nobody can explain that mismatch
- ~~**Use `WATER_WET` (32) as the threshold?**~~ — **closed: yes. No new constant.**
  The price (color, fire-proofing and jumping tied to one value) is already recorded above
- **When to show fallback text** — after some seconds of not working it out, or always.
  The UI is only a debug label right now
- ~~**How fast the water rises**~~ — **closed: approach A, starting at 20,000 per tick.**
  The A/B/C re-measurement gave the values (25%→5.0s · 50%→8.0s · 95%→11.0s, within the 5–15s target).
  **15,000–20,000 is the range and 20,000 is the starting value** — move within it after seeing the screen
- **Monsters and water** — what happens to pigs and chickens in water
- ~~**Does current push the character** — out of scope~~ — **now in scope.**
  The user judged "water is background" and decided **"put in the current too and finish water this round".**
  ⇒ **Implementation stage 4.** Only the strength (`WATER_PUSH_PX`) is set on screen
- **Falling has no acceleration** — in scope. ⇒ **Implementation stage 2.** K starts at 4
- **How the gate and water meet** — the gate was placed behind room ③ (to the right) (`stage1-map-layout.md`)
  **and water also comes from the side wall.** Does water lock the gate · is the gate high enough to need a jump ·
  must you leave before it fills. **Unresolved, the escape scene doesn't hold**
- **Is this the only water in stage 1** — the map doc says "no water" and this is the sole exception.
  **Then the player's first sight of water is right after the boss fight** — confirm that is intended

---

## Decided — from the design conversation

| What | Value | Why |
|---|---|---|
| Underwater movement | **Unlimited jumps** | No new physics axis called buoyancy or swimming. It is one line of condition |
| Buoyancy | **Not built** | The water doesn't push you; you climb on your own |
| Drowning | **Not built** | Unlimited jumping creates pressure and escape at once |
| How it's learned | **Worked out alone** | Text is the fallback |
| Where it's used | **Right after stage 1's boss ③** | It becomes stage 2's (the water stage) movement tutorial |

⇒ **`docs/design/water.md`'s "buoyancy or swimming was not decided" closes with this.**

---

# Implementation plan

## Diagnosis first — what is this plan fixing

**The user's three complaints look separate and share one cause:**

```
"feels like background · has no effect on me"   ← the diagnosis
"trickles down one row at a time · cheap"       ← symptom (falling has no acceleration)
"there is no current"                           ← symptom (water can't push the character)
```

**Water does not touch the character at all** (zero `WATER` references in `character.gd`).
⇒ **Making the water "prettier" will not remove this feeling. Only touching will.**

**That judgment sets the order below** — of the four axes, **only ① and ③ touch the character**,
**② is water looking like water**, and **④ is the screen changing.**

## Structure — only one is a new kind. The other three are all "variants"

| Axis | Variant or new kind | Grounds |
|---|---|---|
| **① underwater jump** | **Variant.** 0 new files | One sibling of `standing_in_fire` in `body.gd` + one term in the jump condition |
| **② fall acceleration** | **Variant.** 0 new files | `_water_fall` looks at K cells instead of 1. **No new state** |
| **③ current** | **Variant.** 0 new files | See "current is recoil's sibling" |
| **④ pouring** | **New kind** | This repo has no "presentation state that progresses across many ticks" |

### Current is recoil's (`recoil_vx`) sibling — not a new physics axis

**Found while planning.** The character's horizontal movement is already **the sum of "input + external force"**:

```gdscript
# src/actor/character.gd:287
_body.move_x(grid, (move * MOVE_SPEED_PX + recoil_vx) * dt)
```

**`recoil_vx` is exactly "an external horizontal velocity pushing the character".** Current is **one more term in
that sum**, and `move_x` already handles wall blocking and stair climbing. ⇒ **No new axis, no new state, no new files.**

**One difference from recoil — current does not decay.**
Recoil is an **impulse** dying down via `recoil_vx *= pow(RECOIL_DECAY_PER_SEC, dt)` (`character.gd:289`), but
current is **a field re-read from the grid every frame.** **Adding decay counts it twice** —
force falls while the water is unchanged, and force lingers after the water is gone.

### Only ④ (pouring) stands up a new file

`spell_sim` holds bolts and `cell_grid` holds cells, but **nothing holds "pour a little over N ticks".**
⇒ Stand up one `src/sim/water_source.gd` (`RefCounted`). Grounds below.

### Where pouring lives — `src/sim/`. The grounds are not the folder contract but **the nets**

The contract first: pouring uses **only integers** (one row · an x range · a per-tick amount · a remaining amount).
No float, no `Vector2`, no `randi`, no `Time.`, and it knows nothing of the scene tree ⇒ **it satisfies `src/sim/` literally.**

**But the contract alone leaves `stage.gd` as a candidate too** — the shell is where debug doors go, and
`_pour_water_at` (F) and `ignite` (G) are the precedent. **What decides it is this:**

> **This feature's biggest risk is "does water arrive at the right rate" (acceptance 6), and that is measurable only by value.**
> Put the pour state inside `stage.gd` and **the nets can't build a scene, so they can't run that code** ⇒
> the net would **reimplement pouring inside itself** to measure it.
> **Then what is measured and what ships are different code.** That is CLAUDE.md's "No fake nets",
> **the label claiming more than the check measures** — a green result while nobody has measured the game's water rate.

⇒ **State and arithmetic live in `src/sim/water_source.gd`; `stage.gd` knows only "when to start" and "call it every tick".**
The net runs **the very object the game runs**, headless.
There is a side benefit — the day the boss hook exists, `world_step` holds **the same object**, and
**there is no code to move** from the shell into the real game.

### Do not put it inside `cell_grid.step()`

Putting the water source inside the grid's tick **changes what `step()` means for every net** (39 call it now).
**The caller runs the source.** The grid stays "the thing that holds cells".

---

## The pour's arithmetic — it is "add", not "overwrite"

**This is accuracy, not taste. Pinned into the plan.**

`set_water(x, y, amount)` (`cell_grid.gd:1088`) **overwrites** — internally `_write_water(i, amount)`
**sets `_aux[i]` to that value** (`cell_grid.gd:309`). ⇒ "Pouring" 113 into a cell already holding 200
**destroys 87.** **No error is raised.** Water quietly shrinks and all that remains is "why won't it fill".

⇒ **Read, add, write.** Both are existing public doors:

```
new = mini(WATER_MAX, aux_at(x, row) + per_cell)
set_water(x, row, new)
```

**Walls reject themselves** — `set_water` returns `false` for anything but `EMPTY` and `WATER`
(`cell_grid.gd:1096`). Nothing leaks outside the bowl (the same property as "leakage 0" above).
**And the source counts what actually went in this tick** — excluding rejected cells and the portion blocked by
`WATER_MAX`. **That counter is one side of net B-1.**

---

## Where current's strength and direction come from — **not stored in the grid. The character reads**

`docs/design/water.md:452` flagged this spot — **`_water_share` already computes `diff` and discards it**
(`cell_grid.gd:537`) — and called keeping or discarding it a design call. The call: **leave it discarded.**

### The cost of both paths

| | **A. Store in the grid** | **B. The character reads neighbor cells** |
|---|---|---|
| Memory | **1 byte/cell × 4,128,768 ⇒ 4.1MB** (`cell_grid.gd:53-54`) | **0** |
| Sim change | Writes added inside `_water_share` (the hottest loop) | **None** |
| New axis | **The residual must be cleared or decayed every tick** — otherwise force remains after the water stops | None — it always reads the current grid |
| Existing nets | All 39 of `net_water`'s premises (grid state) move | **Not one touched** |
| Folder contract | Safe inside `src/sim/` but the contract grows | **Pure read** — cannot violate "the reverse is not allowed" in principle |
| Where cost lands | Every tick · every water cell | **Every frame · around the character's box only** (same size as what fire already does) |

**B wins. Not close.** What A buys with 4.1MB and a new "decay the residual" axis is **slightly more accuracy**,
and what ③ measures is not a physical quantity but **feel.**

### What B reads — the very amount `_water_share` looks at

```
body.water_flow(grid) -> int          # signed integer. Positive pushes right
  range: the same cell range as standing_in_fire (cells the box covers)
  left  = Σ aux_at(cx0 - 1, cy)       the column just outside on the left
  right = Σ aux_at(cx1 + 1, cy)       the column just outside on the right
  diff  = left - right                heavier on the left pushes right
  returns 0 if |diff| <= WATER_MIN_DIFF × row count
```

**That last line is "no push in still water".** `_water_share` doesn't move anything when `diff <= WATER_MIN_DIFF`
(`cell_grid.gd:540`), so **a settled puddle's left-right difference is below that line in principle.**
⇒ **Reusing the same constant gives "it only pushes where water actually flows" for free.**
**Standing up a new threshold here produces "the water stopped but I'm still being pushed".**

### B's limit — **the sentence that was here was wrong** (demolished by measurement)

**It used to read:**

> ~~This scene is not that case — water pouring into a room and rising forms a **front**, so the imbalance is large.~~

**Wrong. That sentence belongs to the "side wall collapse" era.** When pouring was replaced with approach A,
**the premise vanished and nobody carried it forward.** ⇒ Measured: **in the middle of open water the left-right
difference is exactly 0 every tick.**

**This is the accident this repo guards against** — a sentence called a "structural argument" whose structure was
**removed by another decision**, leaving only the sentence.
**Without checking the claim against reality, the next person builds on it.**

#### Why it's 0 — and why **changing direction is also 0**

**Approach A pours the same amount across all 176 cells of width every tick** ⇒ every column fills equally ⇒
**left and right are always level.** **Integer sim keeps that symmetry exact.**

**And this is not just a horizontal problem.** Computed from shipping constants (matching the measured 12.6s — below, 11.7s):

```
per cell/tick = 20,000 / 176 = 113
water rise    = 113/255 = 0.44 cells/tick = 8.9 cells/s = 1.11 tiles/s
filling 13 tiles (104 cells) = 11.7s        ← matches the measured 95% at 12.6s
one cell going 0 → 255 = 2.26 ticks
```

⇒ **Below the surface everything is 255. Above it is 0. Between them is only a 2-tick band.**
**A submerged character is surrounded by 255 vs 255 in every direction — vertical difference 0, inflow 0.**

**This paragraph is arithmetic from measurement, not measurement.** But **the inputs are shipping constants and
the result matches an independent measurement (12.6s)** ⇒ usable as evidence. **If it's wrong, one of the four lines above is.**

#### ⇒ So switching to candidates ② (inflow) or ③ (vertical) doesn't survive in this scene either

**A room that fills fast and evenly is by definition near equilibrium, and equilibrium means "no force in any direction".**
**The 12.6 seconds is itself the evidence of near-equilibrium.** The dam break had current for exactly the reason that
**it stayed far from equilibrium for 4:30.**

**⇒ "Fills fast" and "pushes" are two ends of one knob. You can't have both.**

---

## Order — different from what the user said. Grounds first

**The user said "do the water rising first" twice** (`water.md:386`). **The plan doesn't use that order.**
**That was said before the "feels like background" diagnosis**, after which the user widened the scope to
**"put in the current too and finish it".** In the widened scope, the same order breaks two things:

**1. Showing the rise first shows the user a scene filled by the very fall they just called "cheap".**
Approach A drops water across **all 176 cells of width** ⇒ the trickle appears not as one line but **176 lines.**
The initial fall distance is 13 tiles ≈ 104 cells and the current fall is 60 cells/s, so **the first 1.7 seconds is
entirely "falling water".**
**`water.md:389` says it itself** — "what changes is the shape of the falling stream, **and that is what the escape
scene shows**". ⇒ **Don't show that scene before fixing that shape.**
**This is inference, not measurement.** To measure it, capture the same scene before and after ②.

**2. The pour would be measured twice.** ② (fall K) invalidates "25%→5s · 95%→11s" (`water.md:381`).
Doing ④ first means **measuring, then measuring again after ②.**

### Update — **pouring is already done. One argument weakened, one stands**

**builder finished stage 3 before the stop instruction arrived** (nets green). ⇒ Revisiting the two arguments:

- **Argument 2 (measuring twice) weakened.** **`water_source.gd` doesn't change when the fall changes** —
  all that needs revisiting is **whether `WATER_RAIN_PER_TICK` (20,000) still gives 5–15 seconds**,
  and **a net measuring that already stands.** "Measure twice" shrank to **the cost of one run**
- **Argument 1 (showing a scene filled by an unfixed fall) stands.** In fact it got **more urgent** —
  launch the game now and press K and **the user sees exactly that scene**

**⇒ The order becomes:**

```
stage 1  ① unlimited jumping underwater    2 files · fully headless · completely independent of the other axes
   ↓
stage 2  ② fall acceleration K             land it before looking at the screen (argument 1)
   ↓
   ★ verify-look sees three things in one pass — jumping · fall shape · the already-standing pour scene
   ↓
stage 4  ③ the current pushes              tune strength over the real scene (the strongest flow)
   ↓
stage 5  underwater gravity                conditional. Only if acceptance 4 reads as "flailing"
```

### Progress — **this table is more current than the order above**

**Reading the order above without this section reads as "fall K isn't done yet".** That misreading happened
(spec reported "what remains is stage 2" twice when **it was already in**).

| Stage | State | Grounds |
|---|---|---|
| **1. Unlimited jumping underwater** | **In** | `body.gd` `standing_in_water` · `character.gd:262` condition. `net_character` A-1–A-4 |
| **2. Fall acceleration K = 4** | **In** | `sim_tuning.WATER_FALL_CELLS` · `cell_grid._water_fall` K-cell scan. **Measured 3.0×** (not 4.0) |
| **4. Pouring (approach A)** | **In** | `src/sim/water_source.gd` · K key. **Done first, out of order** (the stop instruction arrived late) |
| **3. Current** | **In** | `body.gd` `water_flow` · `character.WATER_PUSH_PX` 130. **It is 0 in the flooding scene — see above** |
| **5. Underwater gravity** | **Not opening — the condition never triggered** | verify-look saw acceptance 4: **42–45px of regular rise per cycle with 3–4px of sag.** Not flailing |

**⇒ No code work remains. What remains is the screen (`verify-look`) and the tuning after it.**

### Update — **the screen was seen, and one axis failed on screen**

**The five rows in the progress table mean "the code is in", not "the screen works".** What was seen:

| Axis | Value | **Screen** |
|---|---|---|
| ① unlimited jumping | | **Works. It climbs regularly** |
| ② fall acceleration K=4 | 3.0× | **Failed. It only widened the stripe spacing 4×** |
| ③ current | 44 px/s | **Visible standing still, unfelt while walking** (10–17% of walking) |
| ④ approach-A pouring | 12s | **The rate is right but it doesn't read as "coming in from the side"** |

**② was the reason this work started.** Detail in the verify-look result block under "Acceptance".

**Three net holes were filled too** — `net_character` **76 checks · 0 failures**, overall **2,122 · 1 failure** (B-5, known).

| What | How |
|---|---|
| **C-4** tautology | Rewritten with a puddle the character **actually submerges in.** Inversion (threshold `<=0`) **confirmed red** |
| **C-7** new | `water_flow() == 0` beside a burning wood column. Deleting two guard lines **confirmed red** (expected 0, got 200) |
| **C-8** new | **Delete the water after being pushed and it stops that frame.** The sibling of A-3 (jumping) |

**C-4's rewrite spun idle once more — builder caught and reported it.**
Poured to a depth of 30 rows, **both neighbor columns filled to 255 within the scan range**, pushing the real residual
(the top row of the surface) **above the scan range** ⇒ deleting the threshold still gave green.
**Only reducing the depth to 16 rows (the box height) brought the residual into range.**
**The same check spun idle twice for different reasons** — the real condition was not "make it submerge" but
**"is the residual inside the scan range".** That history lives in the check's comment.

**Only C-8 has no inversion** — builder stated that being a new check, there was no natural mutation to invert.
verify-read had already shown by value that "no check measures the absence of decay", so **the need is confirmed,
but whether this check itself measures has not been inverted.**

**Why ① is still first**: it is completely independent of ② (it reads only the water **amount**, never speed) and is
**2 files, fully headless** — the cheapest. **Landing it first lets you separate "is the jump broken or is the water
weird" when something downstream breaks.** Putting ① later removes that separation.

**And the screen is seen once.** verify-look **needs the editor and steals the user's focus**
(CLAUDE.md check #2) ⇒ **judging all three after landing ①+② is cheaper than looking twice.**

**There is also the option of "looking at the pour first"** — what the nets don't cover is the **stage wiring**
(K key → signal → toggle → once per tick → HUD), so a break there is found late. **Why it was deferred anyway**:
a wiring break looks like **"pressing K does nothing"** and a fall break looks like **"water trickles down"**, so
**the symptoms don't overlap** ⇒ one viewing still separates the causes. **The price is one editor session and the user's focus.**

**Why ③ is last hasn't changed**: current strength must be **tuned on the strongest flow** to also fit weak flows.
The F-key disc is a small radial spread, weak as a tuning reference. **⇒ With pouring already standing, that reference
exists now.** The reverse doesn't hold — pouring doesn't lean on current at all (the character doesn't push water).

---

## Stages — five. builder stops after each and verification runs

### Stage 1 — unlimited jumping underwater (**2** `src/` files touched)

| File | What | Why |
|---|---|---|
| `src/actor/body.gd` | `standing_in_water(grid) -> bool` **directly below** `standing_in_fire` (:155) | Placing it beside, in the same shape, is the only way to keep the range identical to fire's |
| `src/actor/character.gd` | `in_water = ...` beside `on_ground = ...` in `step()` (:261), and `or in_water` in the jump condition (:262) | "Am I in water" must be re-read **every frame** (below) |

**How "is it deep water" is asked — read the same value the screen does:**

```
mat_at(cx, cy) == Mat.WATER and (flag_at(cx, cy) & Mat.FLAG_SHALLOW) == 0
```

**`FLAG_SHALLOW` is the exact flag the renderer looks at to paint shallow water bright.**
`_write_water` (`cell_grid.gd:319`) sets it when `amount <= WATER_WET`, and
extinguishing (`_deep_water`, `cell_grid.gd:687`) uses `aux > WATER_WET`, the same line.
⇒ **Three things looking at one line is guaranteed by value.** "Jumping works only in dark navy" is already drawn on screen.
Measuring `aux_at() > WATER_WET` directly gives **the same answer today**, but then **the line exists in two copies.**

**Do not put it in `on_tick()` (:302, where `burning` is set).** That runs **per tick** and
`TICK_DIVIDER` is 3, so jumping would be judged on **an answer up to 2 frames stale** —
you'd get two extra jumps after leaving the water. **Invisible to the eye.** Net A-3 catches it.

**Acceptance measured here**: 1 · 2 · 3 — **all headless** (verify-run).
Acceptance 4 (climbing without flailing) **cannot be measured here** — that's stage 5.

### Stage 2 — fall acceleration K (**2** `src/` files + net repair)

| File | What | Why |
|---|---|---|
| `src/sim/sim_tuning.gd` | One constant, `WATER_FALL_CELLS` (K) | The only knob for fall speed |
| `src/sim/cell_grid.gd` | `_water_fall` (:480) scans **up to K consecutive empty cells** below | `_aux` is full with the amount; no new velocity byte fits (`water.md:370`) |

**The exact rule**: descend at most K cells **only while empty cells are consecutive** and **place the whole amount in
the lowest empty cell.** **On hitting water or solid, stop there and handle it exactly as today**
(merge by `space` for water; leave the remainder to ② (left-right) for solid). ⇒ **Stacking and blocking keep their meaning.**

#### K's starting value = **4**. There is a reason not to defer it

**Unlike underwater gravity, K can't be deferred** — with no constant, builder can't write a line.
And **there is a measurable target** (underwater gravity has none):

```
now        60 cells/s =  240 px/s      one tenth of the character's, and it never speeds up
K=4       240 cells/s =  960 px/s      half the character's fall cap (1800)
character  MAX_FALL_PX 1800 px/s  (= 450 cells/s ⇒ K equivalent 7.5)
```

**But a net limits how high it can go.** The scene in `net_water._water_falls_per_tick` has
**27 cells of free-fall headroom**, and the way that check catches row/band order reversal is that
**"it goes up to 27 cells in one tick" exceeds the ceiling** (`net_water.gd:420-422`).

| K | Max fall per tick | Still catches order reversal? |
|---|---|---|
| 4 | 12 cells | Yes (15 cells of margin) |
| 6 | 18 cells | Yes (9 cells of margin) |
| 8 | 24 cells | **3 cells of margin — effectively no** |

⇒ **Start at 4. Up to 6 is safe with the current scene; going to 8 or above means enlarging the net's scene first.**
**The final value is the user's, decided on screen** — 6 if 4 is "still slow", above that only after the scene grows.

**Acceptance measured here**: headless, **did fall speed become K×** (net D). **"Does it look like water" is screen-only.**

### Stage 3 — approach-A pouring — **implementation complete. The screen hasn't been seen**

**What actually landed** (as planned + one constants file):

```
src/sim/water_source.gd  NEW  _init(x0,x1,row,per_tick) · tick(grid) · poured()
src/sim/sim_tuning.gd         WATER_RAIN_HALF_W 88 · WATER_RAIN_PER_TICK 20000
src/stage/stage_input.gd      rain_requested signal + KEY_K (the same door as F/T/G)
src/stage/stage.gd            _water_source (null=off) · _toggle_rain_at() ·
                              tick() in _on_ticked() · null on reset · HUD status line
tests/nets/net_water.gd       B-1–B-5 ("stage 7" section, the real pit ① terrain)
```

**Most important — the `set_water` overwrite trap was avoided.** It reads with `aux_at()`, writes
`mini(WATER_MAX, before + per_cell)`, and **doesn't count rejected cells into `_poured`**
(`water_source.gd`). ⇒ B-1 (conservation) is not a tautology.

**Two things builder flagged as uncertain — judged. Both correct:**

- **Putting a constant in `sim_tuning.gd` (outside the 3 files specified)** — **correct. The contract requires it.**
  CLAUDE.md: "sim constants all live in `src/sim/sim_tuning.gd`". Anywhere else would be the violation.
  **It doesn't conflict with the file-count contract** — the designated constants file **is not a new structural site.**
  (Same idiom as "three spots in one file are one place")
- **Adding a rain status line to the HUD** — **correct. Its absence would have been wrong.**
  **A toggle with no visible state reads as "the key doesn't work"** — the same place `_pour_water_at` recorded
  "leave it at one drop and the user reads it as the key not working".
  It is also what CLAUDE.md check #3 ("a path for the thing you want to see to reach the screen") demands

#### Two nets builder wrote differently from the plan — **both better than the plan. Adopted**

**1. B-3·B-4 measured as a "halve it and it takes about twice as long" ratio, not an absolute tick count.**
**My "160 ticks" was a wrong value.** That number came from a **row basis** ("a row counts as risen once over 50%
of the width is wet") while builder measures on a **volume basis** — **different units.**
**Pinning a wrong absolute would have been worse** — it goes red for nothing, or more commonly
**the number gets edited until it's green, at which point the assertion is decoration.** A ratio **doesn't move when the terrain does.**

**2. B-5 became "settle completely before pouring" instead of "exempt the first 30 ticks".**
**My 30-tick exemption was an amnesty, exactly the shape CLAUDE.md warns about in width and lifetime.**
builder **removed the segment needing exemption entirely** (`_build_settled_pit`) — stronger.
And it **asserts `peak > 0` alongside**, blocking "passes while measuring nothing".

**The original plan table stays below** — what was intended must survive for the next person to compare.

### (Original plan) Stage 3 — approach-A pouring (**3** `src/` files, 1 of them new)

| File | What | Why |
|---|---|---|
| `src/sim/water_source.gd` NEW | `RefCounted`. State (x0 · x1 · row · per-tick total · accumulator) + `tick(grid)` + `poured()` | See "where it lives" |
| `src/stage/stage.gd` | One source instance · `tick(_grid)` in `_on_ticked()` (:384) · a start function | The shell knows only "when" |
| `src/stage/stage_input.gd` | **K key** → `rain_requested(world_px)` signal | Goes through the **same door** as F (:104) · T · G |

**Why K**: 1–5 · F · G · M · N · R · T are taken (`stage_input.gd:41-113`).

**It pours at the mouse** — same as F · T · G. Into the **row** of the mouse cell, across **±88 cells (176 total)** of width.
**176 is not arbitrary; it is the width from measurement A** — the same width is required for the 5.0/8.0/9.0/11.0s table to mean anything.
**Press again to stop** (toggle). Otherwise turning it off requires resetting the stage with R.

**`tick()` goes inside `_on_ticked()`, not `_physics_process`** (`stage.gd:377-379`).
Called per frame, the pour rate becomes **`TICK_DIVIDER`× (3×)** and wobbles with the refresh rate.
**No error. It just looks like "it fills faster than expected".** Net B-2 catches it.

**Acceptance measured here**:
- **6 (water arrives at the right rate) — headless** (verify-run). **Re-measured. Two reasons:**
  (a) the earlier A/B/C measurements used **values the measuring script poured**, and that code doesn't ship —
  this time it is measured with **the shipping `water_source.gd`**.
  (b) **Stage 2 (fall K) invalidated "25%→5s · 95%→11s"** (`water.md:381`).
  **Ordering it this way means measuring once here** — doing ④ first would have measured twice.
  **It moves faster, so the target (5–15s) can be exceeded from above** ⇒ **lowering the per-tick total is the knob**
- **5 (it rises from the side) · 9 (does the surface read as a stain) — screen only** (verify-look)
- **7 (the escape works) — screen only.** **Lines 334–335 already recorded "no character was instantiated"** —
  whether the surface rise and jump height mesh **is seen here for the first time**
- **8 (they work it out alone)** — only the user judges

---

### Stage 4 — current — **implementation complete. But it is 0 in the boss room**

**The code landed correctly as planned and verify-read confirmed it.** **But the force is exactly 0 in the target scene**
(see "B's limit"). **A scene problem, not a feature problem** — on the F-key disc it **actually pushes at 45 px/s** (measured).

#### Judgment — **choose ④ (accept it). It doesn't push in this scene**

**Three of the four candidates hit the same wall**: as the arithmetic shows, **a room near equilibrium has no force in
any direction, and "fills in 12.6 seconds" *is* "near equilibrium".**

- **① reopen the pour method** — **collides head-on with the constraint of not breaking the fill time.**
  Method B (5 points) was already slower than A (95% at 19s vs 11s), and narrowing raises diffusion time **quadratically**
- **② inflow** — from the arithmetic: a cell goes 0→255 in **2.26 ticks**, so it's a **2-tick pulse.** Submerged, it's 0
- **③ vertical** — below the surface it is **255 vs 255**, so the vertical difference is 0 too
- **④ accept it** — **0 cost · 0 new axes · 0 to revert.** And **nothing about it is wrong**

**④ is not "giving up".** Current is felt at **dams · waterfalls · near walls · the F-key puddle · stage 2's river.**
**The axis for "water touching me" in the boss room was always unlimited jumping** — that was this doc's "Decided",
and **current was not built to replace it.**

#### So the verify-look plan changes — **show the current with F, not K**

**Without this change the user sees "there is no current" one more time.** That was the reason this stage existed.

| What | How |
|---|---|
| **The current pushes** | **F key.** Stand on flat ground and drop a water blob beside you — measured 45 px/s · 35px in 2 seconds |
| The rising scene · fall shape | K key |
| Unlimited jumping underwater | After filling with K |

### (Original plan) Stage 4 — the current pushes the character (**2** `src/` files touched)

| File | What | Why |
|---|---|---|
| `src/actor/body.gd` | `water_flow(grid) -> int` — the four lines from "what B reads" | Every grid read lives here (same place as `standing_in_fire`) |
| `src/actor/character.gd` | A `WATER_PUSH_PX` constant + one term in `move_x`'s sum | The same line as `recoil_vx` (`:287`) |

```gdscript
# now
_body.move_x(grid, (move * MOVE_SPEED_PX + recoil_vx) * dt)
# after
_body.move_x(grid, (move * MOVE_SPEED_PX + recoil_vx + water_push) * dt)
```

**`water_push` is recomputed every frame and never decayed** (see "recoil's sibling").
**Do not hold it as a member variable and accumulate like `recoil_vx`** — you'd keep being pushed after leaving the water.

**`water_flow` is also read per frame** — the reason is **not** "water changes every frame" (it changes per tick).
It is that **the character moves every frame**, so which cells it sees changes. Same reason as `in_water`.

**`WATER_PUSH_PX` gets no pinned starting value.** **Same category as underwater gravity** — the target is
"is being pushed fun", a feel with no measurable anchor. ⇒ **Set it on screen, over stage 3's scene.**
builder puts in **one clearly visible value** and stops (invisible reads as "the key doesn't work").

**Acceptance measured here**: headless — **sign · proportionality · 0 in still water** (net C). **Strength is screen-only.**

### Stage 5 — underwater gravity (**conditional. The value is not set now**)

**Do not open this stage before seeing acceptance 4 by eye.** Run stages 1–4 with **default gravity** and open the
value **after** verify-look sees "does it climb by jumping, or flail".
**If it doesn't flail, this stage is never done.**

**If opened, look at `GRAVITY_PX` and `MAX_FALL_PX` together** — `character.gd:75` already records
"touch one and it goes silently wrong (reachable height is `v²/2g`)".
**Start by lowering only gravity underwater, not `JUMP_VY_PX`** — so the jump's feel
(the recoil assignment, `character.gd:255-262`) isn't different in and out of water.

**Acceptance measured here**: 4 — **screen only** (verify-look). Once the value stands, run A-1 once more under underwater gravity.

---

## Net plan — what each check goes red on when inverted

**Written against CLAUDE.md's "No fake nets". A check with no inversion doesn't go in.**

**Group names differ from stage order.** Read by stage:

| Stage | Group | Where |
|---|---|---|
| 1 underwater jump | **A** (4) | `net_character.gd` |
| 2 fall K | **D** (repair existing + 3 inversions) + **B-6** | `net_water.gd` |
| 3 pouring | **B-1–B-5 — already standing** | `net_water.gd`, "stage 7" |
| 4 current | **C** (6) | `net_character.gd` |
| 5 underwater gravity | None — screen only | — |

### A. Stage 1 — attached to `tests/nets/net_character.gd`

**Not `net_water`.** What is measured is **the character's behavior**, not water's.
**`net_character` was 46 seconds over 274 lines** (CLAUDE.md's example). **Do not lay a fresh floor** — use the existing helpers.

| Check | What goes red when inverted |
|---|---|
| **A-1 a mid-air jump works in deep water** — lift off the ground, submerge (33+), jump **3 times in a row**, `vy == JUMP_VY_PX` each time | Reverting the jump condition to `on_ground` only → red |
| **A-2 the boundary pair — 32 doesn't work, 33 does** | Swapping `>` ↔ `>=` → red. **Both must be measured** — measuring only at 0 passes even with the threshold changed to 200 ("the value happens to be right") |
| **A-3 leaving the water blocks it that frame** — delete the water and the **next `step()`** fails to jump | Moving `in_water` into `on_tick()` or caching it once → red. **This is where "is it read per frame" is caught by value** |
| **A-4 the range includes the row underfoot** — empty inside the box, deep water **only in the row underfoot** → the jump must work | Using `standing_in_water`'s `cy1` without `+1` → red. The same place `body.gd:151` records that fire's one row is "this feature's life" |

**Do not write A-4 as "does it agree with `standing_in_fire`".** Folding both into one helper makes it a
**`scan == scan` tautology** (CLAUDE.md, "A/B comparison catches diverged, never vanished").
**Build the cell layout directly and assert the absolute answer.**

### B. Stage 3 — attached to `tests/nets/net_water.gd`

| Check | What goes red when inverted |
|---|---|
| **B-1 conservation — the source's accumulated count == the grid's total water** (sum of `aux_at` over `mat == WATER` cells) | **Changing add back to overwrite → red.** The only check catching "add, not overwrite" by value |
| **B-2 exactly once per tick, exactly that row** — run one tick and check **no row other than the entrance grew** | Calling `tick()` twice or pouring into two rows → red. **Final state can't catch it** — once full, which row it entered by is identical |
| **B-3 target time — 50% level arrives within the expected tick count** (20,000/tick, 20 ticks/s ⇒ 8.0s ≈ **160 ticks**) | Halving the per-tick amount → red |
| **B-4 the loop actually ran** — **assert the iteration count** alongside (`ticks > 1`, and that the target **was reached**) | Blocks a false start condition passing with 0 iterations (CLAUDE.md's `settle > 1` case) |
| **B-5 the cap (100) isn't touched while pouring** — max `active_chunk_count()` < 100, **excluding the first 30 terrain-building ticks** | Widening or raising the amount → red. **Pin the amnesty narrowly at 30 ticks** — used as a blanket exemption, the check may as well not exist |

#### B-6 — **doesn't exist yet. A hole opened by switching to ratios** (goes in with stage 2)

**builder's ratio assertion is right, but nobody measures the absolute speed.**
B-3's only absolute guard is `ticks1 < 400` (**20 seconds** at 20Hz), **far looser than acceptance 6's target (5–15s).**

**⇒ The value this doc calls "the biggest risk" is not caught by any standing net.**
**Both failure modes the doc records as unusable currently pass this net:**

```
over in 0.85 seconds (no rising picture)  → passes because ticks1 is small
takes 281 seconds (4:30)                  → caught by missing the target within 400 ticks, but everything between passes
```

**⇒ B-6: the tick count to reach 50% of settled capacity is inside a generous band** (e.g. **60–400 ticks = 3–20s**).
**Deliberately loose** — pinned narrowly, **healthy code goes red** every time terrain or K changes.
**The band's purpose is not "guaranteeing 5–15 seconds" but "catching an order-of-magnitude slip".**
**5–15 seconds is judged by verify-look and the user** — a net must not pretend to judge feel.

#### How stage 2 (fall K) affects group B — **recorded in advance**

**B-5 is the most at risk.** At K=4 water falls 4× farther per tick ⇒ **more cells move per tick and active chunks grow.**
B-5 asserts `peak < 100`.
**⇒ If it goes red there, that is not a fake failure** — it is **a real signal** that "water started getting delayed
at this width and this rate".
**The knob to fix it is not the net but `WATER_RAIN_PER_TICK`** (lower it and active chunks drop).
**Which lengthens the fill time and returns you to acceptance 6** — **the two are tied to one knob.**

**B-3's ratio may wobble too.** Currently the entrance row is capped at `WATER_MAX`, so there is a segment where the
source pours slower than nominal (compressing the full/half-speed difference); **a larger K empties that row faster
and releases the throttle** ⇒ the ratio moves **toward** 2.0, so it should stay within the band (1.6–2.4).
**A prediction, not a measurement. Land stage 2 and actually run it.**

**B only means something with real terrain built** (`Stage.build_terrain_into()`, `stage.gd:477` — static, so it can be
called headless with no scene. `net_tables` already uses it that way).
**But that is the sole reason this net is slow** — 400×48 tiles.
⇒ **Build the terrain exactly once inside the net and share it across B-1–B-5.** Building per check pays
CLAUDE.md's "floor fill 2,719ms" five times. **If a round exceeds 10 seconds, call `harness-manager`.**

### D. Stage 2 — **fix the net that breaks, and confirm it still measures after the fix**

**The very check CLAUDE.md cites as its example of "a check that measures the process" breaks** —
`net_water._water_falls_per_tick` (`net_water.gd:426`). It currently asserts:

```gdscript
t.ok(delta <= Tuning.WATER_SUBSTEPS, ...)          # never exceeded N cells in one tick
t.eq(max_delta, Tuning.WATER_SUBSTEPS, ...)        # some tick hit exactly N (substeps really run)
```

**The fix is only `WATER_SUBSTEPS` → `K × WATER_SUBSTEPS`, twice.** **But stopping there is not enough** —
you must invert to confirm **the check still measures something.** **Run all three:**

| Inversion | Must still go red after the fix | Why look at this |
|---|---|---|
| **Reverse row/band traversal order** | 27 cells in one tick > ceiling of 12 ⇒ red | **This check's reason to exist.** As K grows, the ceiling approaches 27 and it **silently stops catching** (K table above) |
| **Reduce the substep loop to 1 iteration** | `max_delta` is `K×1` ≠ `K×3` ⇒ red | Do substeps really run |
| **Set K back to 1** (= void this change) | `max_delta` is `3` ≠ `12` ⇒ red | **Does the K path actually run.** Without it, "fixed" is indistinguishable from "loosened the ceiling" |

**And make the scene bark for itself.** Where `t.ok(WATER_SUBSTEPS >= 1 and <= 8, ...)` sits, also assert
**`K × WATER_SUBSTEPS <= 20`** (safety margin against 27 cells of free-fall headroom).
**Without it, the next person raising K reads green as fine, and by then this check has no teeth.**

**Also touch**: `_water_falls_and_stacks` (:477), the `sim_tuning.WATER_SUBSTEPS` comment's "the fall scales N× too",
and the measurement box in `water.md:355-357`. **Change the value and that box changes.**

### C. Stage 4 — current. **Measuring "it's pushed" by final position alone can't be distinguished from gravity and input**

⇒ **Measure the force-returning function (`body.water_flow`) separately, and pair it with whether that force reaches movement.**

| Check | What goes red when inverted |
|---|---|
| **C-1 symmetric left/right is 0** — the same amount on both sides | Counting only one side or dropping the sign → red |
| **C-2 sign** — water only on the left ⇒ **positive (rightward)**, only on the right ⇒ negative. **Measure both** | Flipping the sign → red. Measuring one side lets **a sign flip half-pass** |
| **C-3 strength is proportional to the difference** — double the difference and the force **strictly increases** | **Returning a constant → red.** The place that catches "returning a plausible value instead of computing" |
| **C-4 still water gives 0** — measured after running the puddle **to equilibrium** (`active_chunk_count() == 0`) | Removing the `WATER_MIN_DIFF` threshold → red. **Assert the settle loop's iteration count too** (0 iterations passes for free) |
| **C-5 paired check — force reaches movement** ① 0 input · on ground · water on one side ⇒ **x moves** ② **delete only the water in the same layout and it doesn't move** | Not adding `water_push` to the sum makes ① red. **② alone is a tautology** — always paired |
| **C-6 the character doesn't push water** — run ① for several frames and **the grid's total water is unchanged** | Accidentally writing to the grid → red. Where the folder contract (`src/actor/` → `src/sim/`) is held by value |

**Don't pin C-3 as "double the difference, exactly double the force"** — the threshold is subtracted, so it isn't
exactly proportional. **Measure it as "strictly increases".** Asserting an exact multiple turns **healthy code red**
the day the threshold changes.

---

## Risk — what could break silently

1. **Water leaking via overwrite** — written large above. **No error is raised.** B-1 is the only defense
2. **Calling the pour per frame** — 3× the rate, visible only as "it fills faster than expected". B-2
3. **Reading `in_water` only per tick** — two extra jumps outside water. **Invisible to the eye.** A-3
4. **`WATER_WET` now sets three things** (color · fire-proofing · jumping). **Tune one and the other two follow.**
   `sim_tuning.gd:184` already reserves "the user decides at acceptance 6" — **open this doc that same day**
5. **The bowl measured and the bowl used are different.** Measurement A was done in **pit ①** (23 tiles wide · 13 tall ·
   13,312 empty cells, **open sky above**), and the scene is **boss room ③** (interior 20×12 tiles = 15,360 cells,
   **ceilinged** — row y13 of `terrain_map_generated.gd`'s MAP is `####`). Similar in size but **not the same.**
   ⇒ **The pour row must be inside the room (below the ceiling).** Measure acceptance 6 **again in boss-room coordinates**
6. **`water_source` being a "new kind" invites the next person to add flesh** (rain · fountains · taps).
   **This time it is one uniform row.** Anything more is out of scope
7. **A-1 passing without underwater gravity, then stage 5 changing gravity, shakes A-1's value** —
   `vy == JUMP_VY_PX` measures right after assignment, so it's gravity-independent. **Write it to measure that spot**
   (measuring after gravity is applied goes red)
8. **Stage 2 can silently pull the net's teeth** — the higher K, the closer "the per-tick ceiling" gets to the
   free-fall distance (27 cells), **and order reversal stops being caught. The label stays green.**
   CLAUDE.md's "the label was accurate and the path reaching it died". **D's scene guard above is the defense**
9. **Stage 2 crosses a band boundary in one hop** — at most 3 cells per tick today, so a 16-row band can't be
   skipped, but K=4 gives 12 cells and **a band can be passed in one hop.**
   Waking the destination cell's chunk is `_write_water`'s job, so it's correct in principle —
   **but verify-read must check "does a skipped band stay asleep and leave water hanging in mid-air"**
10. **Current can ram the character into a wall or wedge it into terrain** — `move_x` handles blocking, but
   `_try_step_up` (`body.gd:96`) means **current can push the character up a stair.** Watch it by eye when raising strength
11. **Stage 4 adding "being pushed" can make stage 1's jump look shaky** — jumping underwater while also
   drifting sideways reads as "the jump is weird". **In this order, jumping is already closed headless** ⇒
   **don't suspect the net, suspect the strength**
12. **Two acceptance checks hang on one `WATER_RAIN_PER_TICK`** — lower it and active chunks drop so B-5 survives
   **but the fill time grows and acceptance 6 is at risk**; raise it and the reverse. **K pushes that balance.**
   ⇒ **Expect to re-pick this value after stage 2, and when you do, measure both sides**
13. **Stage 3 already being in makes "did my change break it" ambiguous** — stage 2 touches `cell_grid`, so
   **if group B goes red, K is the likely cause.**
   **Don't confuse it with CLAUDE.md's "fake failure"** — with no `[race]`, it is a real failure

---

## Acceptance — what tells you it's done

**Closed headless** (verify-run): acceptance 1 · 2 · 3 · 6 + **did the fall become K×** (D) + **current's sign, proportionality and 0** (C)
**Closed only on screen** (verify-look): acceptance 4 · 5 · 7 · 9 + **did the trickle go away** + **current strength**
**Closed only by the user**: acceptance 8, and **the diagnosis itself — "does water affect me now?"**

**That last line is this plan's real acceptance.** Even with 1–9 all green, if the user still says
**"it feels like background", it isn't done.** ⇒ **When stage 4 finishes, ask that sentence verbatim.**

### Still open for stage 3 — the list handed to the verifiers

**Green nets are not the end.** Three remain:

| What | Who | Why not yet |
|---|---|---|
| **Nobody has seen the screen** — does K work · is water visible · does the HUD count · is the surface a stain (acceptance 5·9) | **verify-look** | Only headless ran. ⇒ **Seen all at once after stage 2** (see "Order") |
| **Not measured in boss-room (③ 20×12) coordinates** — what was measured is pit ① (23×13, **open sky**). The boss room is **ceilinged** | verify-run | With no boss, that terrain doesn't stand yet. **Include it in the re-measurement after stage 2** |
| **Do B-3's ratio and B-5's cap survive K** | verify-run | See "how stage 2 affects group B" |

**This table must be empty when the doc moves to `3.done/`** — "implementation finished" and "acceptance passed"
are different (CLAUDE.md).

**Every path to the screen already exists.** Water via the F key (`stage_input.gd:104` → `stage.gd:241` → `:304`),
and the character via `stage.gd:377` → `world_step.gd:138`, which **hands the grid over every frame.**
⇒ **CLAUDE.md's "no path for the thing you want to see" doesn't apply.** Stage 3 adds one more, the K key.

---

## Out of scope — not this round

| What | Why |
|---|---|
| **The boss-death hook** | **The boss doesn't exist in code** — `monster_defs.gd:19-24` has only pig and chicken. That is `stage1-bosses.md`'s job. **The K key stands in for it** |
| **The side wall actually collapsing** | The pour became A (rain), so **presentation and mechanism diverged.** Wall collapse is a picture, not a water path |
| **How the gate and water meet** | See "TBD". **Unresolved, the escape scene doesn't hold, but the water rising can be seen without it** |
| **Monsters and water** · **fallback text** | Left in "TBD" |
| **The underwater gravity value** | Stage 5. **Opened after seeing acceptance 4; if it doesn't flail, never** |
| **Drowning · buoyancy · swimming** | Closed as not-built under "Decided" |
| **The character pushing water** | Crosses the folder contract (`src/actor/` float → `src/sim/` integer determinism). **Net C-6 blocks it by value** |
| **The current's vertical component** | **Horizontal only** this round. The upward axis is already closed by unlimited jumping, and pushing down is a drowning conversation |
| **Storing per-cell flow state in the grid** | B was chosen over A. **We don't buy 4.1MB and a decay axis** |
| **Current in a wide, even river** | B's limit (above). **Reopen the day a river is built** |
| **Raising K to 8 or above** | **The net's scene must be enlarged first** (D above). This round starts at 4, max 6 |
