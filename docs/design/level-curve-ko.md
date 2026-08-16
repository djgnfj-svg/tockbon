# The level curve — roster, gates, density, damage, gestures

**Implemented**: 대부분. 로스터 넷(들쥐·토끼·들개·멧돼지) · `SPECIES_UNLOCK_AT` · `OPENING_POCKET` ·
`CRITTER_START_MIN_DIST` · `MAX_HIT_FRACTION` · 종별 공격 동작이 지어졌다.
**미구현**: §7의 치타 손, `BOSS_HUNT_AT` 150 대 120, 물속 생물·시체 도둑(§1-3에서 예산 문제로 잘림).
**Accepted**: 없음 — **사용자가 「나쁘지는 않네」라고 말했고 그것은 인수가 아니다.** 계기가 아직
「진행 불가」를 찍는다(빈 시간 61%, 기준 25%). 눈으로 확인된 것은 하나도 없다.

⚠ **이 문서는 워크플로 안의 에이전트가 쓴 스펙이고, 지어진 것은 여기서 두 군데 다르다** — 문서 끝의
「지어진 뒤」를 보라. 나머지 본문은 지을 때 쓴 그대로다.

---


**Scope**: design only. Every number below is a literal a builder types in. Nothing here is code.
**Target it serves**: one person opens a run and reaches the boss and finishes it. That is not currently
possible and the reason is level design, not tuning.

---

## 0. Three facts the brief got close but not exact. Correct these before building.

### 0-1. The opening screen is not "one creature". It is **provably zero**, at every seed.

`probe_field.gd` measures against a raw 1920x1080 rect. The real camera does not show that.
`main._apply_zoom()` opens at `lerpf(ZOOM_NEAR 1.6, ZOOM_FAR 0.8, swarm.count / ZOOM_FULL_AT 30)`, and
`swarm.count` at t=0 is **1** (the host, `START_CLONES` 0). So the opening zoom is **1.573**, and the
visible world rect is `1920/1.573 x 1080/1.573` = **1221 x 687 px**, half-diagonal **700px**.

`Rules.CRITTER_SPAWN_MIN_DIST` is **900**. 900 > 700.

⇒ **No ordinary creature may be placed anywhere the opening camera can see.** Not by chance — by
construction, for every seed, forever. The probe's "1 creature on the first screen" is an artefact of
measuring a 1920x1080 box that the player never sees; that box has a half-diagonal of 1101px and only the
900–1101 band inside it is legal, which is 12.2% of its area.

And it is worse for four species. `World._anchor_min_dist()` adds `SPAWN_HERD_SPREAD` (220) for any species
with `SPECIES_HERD > 1`, giving **1120** for 말·다람쥐·코끼리·사자. 1120 > 1101, so those four cannot open
inside the raw probe box either.

**Expected creatures visible at t=0 under today's table: 0.00.** This is the whole of "몬스터가 내 주변에 없어."

### 0-2. Three species one-shot the host, not four. The horse is not one of them.

`World._contact()` pass 2 opens `if critter_flees[k] == 1 ... return false`. **A fleeing creature never
attacks anything.** `SPECIES_FLEES` is `[0,1,0,1,0,1,0]`, so 말 · 다람쥐 · 치타 deal zero damage ever.

The probe's `한 방인가` column reads `force >= HOST_HP` and does not consult `SPECIES_FLEES`, so it reports
말 as lethal. It is not. The real one-shot list is **사자 (57–68) · 코끼리 (75–82) · 보스 (120)**.

⇒ `probe_field.gd`'s table needs a `SPECIES_FLEES` gate on that column, or the next reader inherits the
same wrong number. (This spec cannot edit it — read-only task.)

### 0-3. A live bug the new roster walks straight into: an empty card offer spins forever.

`World._grow()` guards with `pending_levels > 0 and offer.is_empty() and not species_eaten.is_empty()`, then
`Cards.roll()` returns an **empty array** when every eaten species has `DROPS 0`. `offer` stays empty, the
guard is true again next frame, and `roll()` runs **every frame for the rest of the run** — the exact shape
`Cards.roll`'s own comment claims was fixed.

It is reachable **today**: eat a 다람쥐 (or 코끼리/치타/사자) before any crow and the loop opens. Every new
species below has `DROPS 0` too, and the curve deliberately makes a 들쥐 the run's first corpse, so this
goes from "reachable" to "happens in the first five seconds of every run."

⇒ The guard has to become "the pool can produce something", not "something was eaten". Cheapest honest
form: a `Cards.pool_size(species_eaten)` the guard calls, so one function owns the filter.
**This is a prerequisite, not a nice-to-have.**

---

## 1. The roster

### 1-1. The seven that exist (unchanged, for reference)

| species | idx | radius | force | speed× | flees | wander | hunts | herd | the hand it asks for |
|---|---|---|---|---|---|---|---|---|---|
| 까마귀 | 0 | 12 | 8–12 | 0.55 | 0 | 0 | 0 | 1 | walk up and hit it; it counters |
| 말 | 1 | 22 | 30–40 | 1.15 | 1 | 1 | 0 | 4 | herd it — no speed catches it |
| 보스 | 2 | 48 | 120 | 0.75 | 0 | 1 | 0 | 1 | it comes; the arena closes |
| 다람쥐 | 3 | 7 | 3–5 | 0.85 | 1 | 1 | 0 | 2 | run it down |
| 코끼리 | 4 | 40 | 70–90 | 0.35 | 0 | 1 | 0 | 3 | do not touch it |
| 치타 | 5 | 15 | 25–35 | 2.20 | 1 | 1 | 0 | 1 | **none — it cannot be caught by anything** |
| 사자 | 6 | 26 | 55–70 | 0.95 | 0 | 1 | 1 | 2 | walk away |

⚠ **치타 has no hand and never has.** 2.2× is above every sustained speed *and* above the wall you would
herd it into, so it is scenery that moves. Not fixed here; listed in §7.

### 1-2. The four new ones

**None of them drops a part. `Parts.DROPS` is untouched, per `august-scope-two-species`.**

| species | idx | radius | force min/max | speed× | flees | wander | hunts | herd | weight | unlock |
|---|---|---|---|---|---|---|---|---|---|---|
| **들쥐** | 7 | 5.0 | 2 / 3 | 0.45 | 0 | 1 | **1** | 6 | 18 | 0s |
| **토끼** | 8 | 8.0 | 6 / 8 | **1.05** | 1 | 1 | 0 | 4 | 16 | 0s |
| **들개** | 9 | 10.0 | 12 / 16 | 0.90 | 0 | 1 | **1** | 3 | 12 | **45s** |
| **멧돼지** | 10 | 18.0 | 18 / 22 | 0.80 | 0 | 1 | 0 | 1 | 9 | **75s** |

`SPECIES_REACH_BONUS` = **0.0** for all four (only the boss has one).

#### 들쥐 — colour `Color(0.70, 0.60, 0.80)`, 7.49:1 against `Look.BG`

**What it is for**: the run's first kill, at second three. `hp = force x HP_PER_FORCE 3` = **6–9**, and the
host's opening bite deals its force, **10** — so it dies to exactly one click, always, at level 1. It hits
back for 2–3, a tenth of `HOST_HP`, which is the whole of "contact costs something" taught at a price you
cannot lose to.

**Why it is not a re-skin of 다람쥐**: 다람쥐 `FLEES 1` — you chase it, and it never touches you.
들쥐 `FLEES 0, HUNTS 1` — it walks to you, and it bites. Those are the two halves of a pair the field is
currently missing one of: today **nothing in the game arrives and is safe to fight.** Everything that walks
at you (사자, 보스) one-shots you.

**Why `HUNTS 1` on something this slow is safe**: 90 px/s against `HOST_SPEED` 200. Walking away always
works — the same guarantee `SPECIES_HUNTS`'s own comment makes for the lion.

#### 토끼 — colour `Color(0.86, 0.64, 0.66)`, 8.85:1

**What it is for**: **the missing rung of the flee ladder.** 1.05× = **210 px/s**, which sits above
`HOST_SPEED` 200 and below `CLONE_SPEED_FOLLOW` 215 — the only body in the game in that band.

⇒ You cannot catch a rabbit by holding a direction. A **rallied swarm** can. It is the herding hand taught
on something with 18–24 hp that dies in two or three bites, so that when the horse (1.15×, above *every*
sustained speed, uncatchable by construction) shows up, the player is meeting a harder version of a hand
they already have rather than meeting the hand for the first time.

Today the flee ladder is 다람쥐 (0.85×, trivially caught by walking) → 말 (uncatchable, requires the full
herd). There is no middle.

⚠ **1.05 > 1.0 puts it inside the afterimage gate** (`field_view._paint_critter` draws trailing ghosts for
`SPECIES_SPEED_MUL > 1.0`). That is correct and wanted: the trail is the "this one out-runs you" mark, and
the rabbit is the first thing that should wear it.

#### 들개 — colour `Color(0.60, 0.40, 0.82)`, 4.66:1

**What it is for**: **the first thing that makes `1` (rally) an act.** `HUNTS 1` targets the *nearest body*,
not the host (`_step_critters`, the `SPECIES_HUNTS` branch), and it arrives **three at a time**. A swarm left
scattered across half a screen gets picked off one clone at a time by three dogs walking different ways.

That closes a hole `gap-check-2026-08-15-ko` names out loud — *"nothing kills a scattered clone"*.

Force 12–16 against `HOST_HP` 30 is **two hits**, at 0.9× (180 px/s) so retreat is always open. It is the
first pressure in the run that is neither harmless nor instantly fatal.

#### 멧돼지 — colour `Color(0.20, 0.58, 0.55)`, 5.17:1

**What it is for**: **the first thing that is a fight, and the first reason to press `3`.**
hp 54–66. At the level you first meet it (see §4) the host bite is ~70–90, so it is one or two bites for the
host alone — but it hits for 18–22 and it does not flee, so trading with it face to face costs most of a
health bar. Six clones parked on it kill it in about two seconds and cost nothing.

**Why it is not a re-skin of 코끼리**: the elephant is 23 host bites and one-shots — it is not a fight, it is
terrain that walks. The boar is the size at which "send the swarm" is strictly better than "do it yourself",
which is the sentence the whole game is about, and nothing currently occupies that size.

### 1-3. Cut, with the reason — these were designed and rejected

| cut | why |
|---|---|
| **참새 떼** — tiny, flees, huge herd | Re-skin of 다람쥐 with a bigger `SPECIES_HERD`. Same hand (chase a thing slower than you), same one-bite death, no new column exercised |
| **물속 생물** (a species that lives in ponds) | The right idea — 12 ponds do exactly two things and nothing lives in them — but "spawn near water" is not a row in any `SPECIES_*` table. It needs a terrain-aware sampler in `_spawn_at`. That is sim work, and it breaks the budget that makes new species cheap |
| **시체 도둑** (walks at the nearest corpse and eats it) | Genuinely new and genuinely good — it would make "stand on your kill" a decision. But the movement branch in `_step_critters` reads `swarm.pos` only; corpse-seeking is a new target class, not a column. Same budget objection |
| **매 / 까치** — ignores rocks | Needs a per-species exemption inside `_place_critter`/`terrain.push_out`. Not a row |

### 1-4. The speed chain, rewritten (this lives in `rules.gd`'s file header and is load-bearing)

```
치타 440 > 말 230 > CLONE_SPEED_FOLLOW 215 > 토끼 210 > HOST_SPEED 200 > 사자 190
  > 들개 180 > 다람쥐 170 > 멧돼지 160 > 보스 150 > CLONE_SPEED_SCATTER 125
  > 까마귀 110 > 들쥐 90 > 코끼리 70
```

The one entry that carries a rule rather than a feel is **토끼 210**, wedged between the host and a following
clone. If it ever crosses either neighbour the species deletes itself.

### 1-5. Size ladder, and an existing violation to stop repeating

`World._radius_of()` is `SPECIES_RADIUS[s] x (1 + 0.5 x force_ramp)`, so drawn radius maxes at 1.5x base.

```
들쥐 5(7.5) · 다람쥐 7(10.5) · 토끼 8(12) · 들개 10(15) · 까마귀 12(18)
  · 치타 15(22.5) · 멧돼지 18(27) · 말 22(33) · 사자 26(39) · 코끼리 40(60) · 보스 48(72)
```

⚠ `hunting-and-the-boss-ko` says **"종 순서는 절대 뒤집히지 않는다"**, and the shipped table already breaks
it: **치타 maxes at 22.5 and 말 starts at 22.** A maxed cheetah is bigger than the weakest horse, today.
`net_numbers` never caught it because it only asserts the property for CROW→HORSE→BOSS.

**Decision: the strict property is abandoned across eleven species and kept for the original three.**
Chasing non-overlap over eleven rows forces radii nobody wants (들쥐 would have to be 4.0 to clear 다람쥐,
and 토끼 could not exceed 6.6 without swallowing 들개).
The three assertions in `net_numbers` stay green because none of the four new rows touches CROW/HORSE/BOSS.
⇒ **The comment on `SPECIES_RADIUS` must be corrected to say what is actually true**, or the next reader
inherits a rule the table has not obeyed since the cheetah landed.

### 1-6. Colour separation

Warm hues are full (다람쥐 tan, 사자 orange, 까마귀 red, 호스트/클론 yellow, 바위 warm grey, 시체 warm
grey). The four new colours take the **violet / rose / teal** block, which nothing else occupies:

| pair at risk | what separates them |
|---|---|
| 들쥐 (0.70,0.60,0.80) vs 보스 (0.85,0.35,0.85) | saturation 0.25 vs 0.59, and **radius 5 vs 48**. The boss also arrives under a full-screen wash and a screen-edge arrow |
| 들쥐 vs 들개 (0.60,0.40,0.82) | same hue family on purpose (both are 잡몹), separated by lightness and by **radius 5 vs 10** — the same device `look.gd` already uses for 다람쥐/사자 |
| 멧돼지 (0.20,0.58,0.55) vs 치타 (0.35,0.80,0.78) | teal vs cyan, and the cheetah carries three **afterimage ghosts** the boar never has |
| 토끼 (0.86,0.64,0.66) vs 호스트 (0.96,0.88,0.52) | rose vs yellow; the rabbit also carries afterimages |

All four clear the file's stated 3.9:1 floor against `Look.BG` (L = 0.0056). Ratios computed WCAG-style,
listed in the table above.

⚠ These are placeholders like the other seven. **Colour is picked by generating candidates and pointing at
one** — these exist only to clear the legibility floor.

---

## 2. What gates on time, and how

### 2-1. A new column: `Rules.SPECIES_UNLOCK_AT`

Seconds of `World.elapsed` before a species may exist at all. Read in exactly two places — `setup()`'s t=0
layout and `_roll_species()`.

```
SPECIES_UNLOCK_AT := [0.0, 0.0, 0.0, 0.0, 120.0, 0.0, 105.0, 0.0, 0.0, 45.0, 75.0]
#                  까마귀  말  보스 다람쥐  코끼리  치타   사자  들쥐 토끼  들개  멧돼지
```

- **사자 105s** — the user, verbatim: *"사자가 왜 이렇게 처음부터 있으면 안 되지. 시간이 좀 지나고 생겨야
  될 거 같아."*
- **코끼리 120s** — split from the lion by 15s so 105 is not a wall of two.
- **보스 0.0** — it is on the field from the start and visible on the minimap, and you may walk to it. That
  is `hunting-and-the-boss-ko`'s explicit call and it is not reopened. `BOSS_HUNT_AT` 150 is a different
  clock and stays.

`_roll_species()` must **skip locked rows and re-normalise the divisor.** It currently sums the whole weight
table once; summing over unlocked rows only is the change, and its "falls back to the last non-zero row"
behaviour has to become "the last unlocked non-zero row" or a locked species leaks through the fallback.

### 2-2. `SPECIES_START` — the t=0 layout, in **herds**

```
SPECIES_START := [10, 2, 0, 4, 0, 1, 0, 3, 2, 0, 0]
#              까마귀 말 보스 다람쥐 코끼리 치타 사자 들쥐 토끼 들개 멧돼지
```

Heads at t=0, `START x HERD`:

| species | herds | x herd | heads | safe to touch at level 1? |
|---|---|---|---|---|
| 까마귀 | 10 | 1 | 10 | yes — 3 bites, counters for 10 |
| 다람쥐 | 4 | 2 | 8 | yes — 1 bite, never attacks |
| 들쥐 | 3 | 6 | 18 | yes — 1 bite, bites for 3 |
| 토끼 | 2 | 4 | 8 | yes — 3 bites, never attacks |
| 말 | 2 | 4 | 8 | yes (never attacks), but uncatchable |
| 치타 | 1 | 1 | 1 | yes (never attacks), uncatchable |
| **total** | | | **53** | **44 of 53 are killable at level 1** |

plus one boss from `_place_boss()`. **54 bodies at t=0.**

Today it is 31 heads of which 14 are killable. The change is not "more creatures" — it is **44 killable
instead of 14, and none of them one-shots you.**

### 2-3. `SPECIES_SPAWN_WEIGHT` — arrivals

```
SPECIES_SPAWN_WEIGHT := [34, 14, 0, 20, 4, 6, 5, 18, 16, 12, 9]
#                     까마귀  말 보스 다람쥐 코끼리 치타 사자 들쥐 토끼 들개 멧돼지
```

Weights roll a **species**, and `_spawn_herd` then writes `SPECIES_HERD` bodies. So the arriving *head*
share is `weight x herd`: 들쥐 108 · 토끼 64 · 말 56 · 다람쥐 40 · 들개 36 · 까마귀 34 · 코끼리 12 ·
사자 10 · 멧돼지 9 · 치타 6 — **375 heads per full cycle of the table**, 들쥐 29%, 까마귀 9%.

까마귀 keeps the largest single-species *weight* (34) despite the small head share, because it is the only
part source in the game and a run that meets no crow gets no cards. Ten of them are also placed at t=0 and
they **stand still**, so unlike every other species they are not consumed by wandering off.

⚠ 코끼리/사자's weights are non-zero but their `UNLOCK_AT` keeps them out of the roll until 105/120s. Both
mechanisms are needed: the unlock decides *when*, the weight decides *how often after that*.

### 2-4. `CRITTER_INTERVAL` stays **20.0**

Over 150s that is 7 arrivals x ~2.6 heads = ~18 bodies, against ~15–20 killed in the same window. Balanced,
and the shaping is done by `UNLOCK_AT` rather than by the interval. **Do not tune this to fix density** —
density is `SPECIES_START` and the two spawn distances, below.

---

## 3. Density, and the two spawn distances

### 3-1. The target: **4–6 creatures inside the camera at the opening**

The opening camera sees 1221 x 687 = **0.84 Mpx²**; the field is 3840 x 2160 = **8.29 Mpx²**, so the opening
shows **10.1%** of the field. Five creatures in 0.84 Mpx² is one per ~410 x 410 px — at `HOST_SPEED` 200 the
nearest is about **one second's walk away**, at all times.

Arithmetic against §2-2: with 53 creatures placed uniformly and a 260px exclusion disc (0.21 Mpx²) cut out
of both the visible rect and the legal field, expected on camera is
`53 x (0.84 - 0.21) / (8.29 - 0.21)` = **4.1**, of which ~3.4 are safe to touch.
The placed pocket in §4 adds four more deterministically, so the true opening frame holds **~8**, thinning
to ~4 as the pocket is eaten.

### 3-2. `CRITTER_SPAWN_MIN_DIST` **900 → 1450** (arrivals only)

Not a relaxation — a **tightening**, and it fixes a bug. At `ZOOM_FAR` 0.8 the visible rect is 2400 x 1350,
half-diagonal **1377px**. 900 < 1377, so **once the swarm passes ~15 bodies, arrivals already materialise on
screen today** — the exact thing the constant's own comment says it prevents. 1450 clears 1377 with margin.

### 3-3. New: `Rules.CRITTER_START_MIN_DIST := 260.0` (the t=0 layout only)

Read by `setup()`'s layout loop and nowhere else. 260px is:
- outside `EAT_RADIUS_HOST` (26) and `BODY_RADIUS` (14) by an order of magnitude — nothing is in your lap;
- **inside the opening camera's 700px half-diagonal** — so it is on screen;
- about 1.3 seconds of walking.

`_anchor_min_dist()` adds `SPAWN_HERD_SPREAD` 220 on top for herds → anchors at ≥480, members at ≥260. The
far edge of a 480-anchored herd lands at 700, exactly the camera corner. That is the intent: **a herd
straddles the screen edge, so part of it is visible and part of it is somewhere to walk to.**

⇒ `_anchor_min_dist()` gains a parameter (or a sibling) for which of the two base distances it is adding to.
It currently reads `Rules.CRITTER_SPAWN_MIN_DIST` directly.

### 3-4. `CRITTER_MAX` **64 → 96**

53 at t=0 + a boss + 7 arrivals x ~2.6 = **~72 before any kill.** At 64 the opening itself hits the cap and
**every later arrival silently does nothing** — `_spawn_at` returns -1 and `_spawn_herd` breaks the loop
with no bark. That is already nearly true today (31 + ~18 = 49 against 64) and the new roster crosses it.

Cost: `_contact` is O(creatures x clones) = 96 x 41 ≈ 3900 distance checks/frame, against 64 x 41 ≈ 2600
today. The flat tables are preallocated to the cap, so this is memory-flat and CPU-linear. Not a wall.

### 3-5. The conflict this cannot resolve, stated rather than hidden

`ZOOM_FAR` shows 3.24 Mpx², **3.9x** the opening. Holding a constant on-screen creature count is impossible
while the zoom is a function of `swarm.count`: tuning for 5-at-open gives **15–23 at ZOOM_FAR.**

**Tune the opening and accept the late number.** By the time the camera is fully out the player has 30+
clones and a brawl is the correct picture. This is the same collision `melee-legibility-ko` §A-6 opens, and
it is not being decided here — only which end this spec tunes.

---

## 4. The one-shot problem, as a rule

Today: `World._contact()` pass 2 writes `host_hp -= critter_force[k]`, and `_damage_clone(i, critter_force[k], ...)`
does the same to a clone. Against `HOST_HP` 30, 사자 (57–68), 코끼리 (75–82) and 보스 (120) kill from full
health on contact.

### Option A — damage a body takes is a fraction of the attacker's force

`Rules.CREATURE_DAMAGE_MUL := 0.35`, applied to what a creature deals to a body only, never to what a body
deals to a creature.

| | | |
|---|---|---|
| does | 코끼리 78 → 27 · 사자 62 → 22 · 보스 120 → 42 (still lethal at level 1) | |
| **breaks** | 까마귀 10 → **4**, so the crow goes from 3 hits to 8. `HOST_HP`'s own comment pins "three crow hits is what it buys instead" and `net_field` asserts `HOST_HP >= SPECIES_FORCE_MAX[CROW] * 2`. **The opening's only teacher of "you can be hit" is deleted.** | |
| **breaks** | Knockback stays `force x KNOCKBACK_PER_FORCE`, so the shove and the damage stop agreeing — a hit that flings you 62px takes 22 hp | |
| **breaks** | *"피해는 공격자의 force, 양방향"* — a design sentence that survived two review rounds | |

### Option B — the host's HP scales the way monsters did (the RoR2 treadmill)

`HOST_HP` 30 → 40 and `HP_PER_LEVEL` 3 → 8, with the time gates doing the rest. Level 5 → 80 hp, survives a
lion; level 10 → 120, survives the boss.

| | |
|---|---|
| **breaks** | `Parts.HP` is 5 (말 갈기) and 3 (까마귀 발). Against 8/level a part's whole HP column is noise, and `HP_PER_LEVEL`'s own comment ("a tenth of one crow hit, so ten levels buy the hit back") becomes false |
| **breaks, fatally** | It makes **levels** the answer, levels come from eating, and eating is what the player cannot do because everything either flees or one-shots them. **Circular** — it fixes the late game with a resource only the late game has |

### Option C — a cap: no single blow may take more than half the victim's own maximum ★ recommended

`Rules.MAX_HIT_FRACTION := 0.5`. Every damage write to a **body** (host and clone alike) becomes
`dealt = mini(incoming, maxi(1, int(hp_max x MAX_HIT_FRACTION)))`. Two call sites: `_contact` pass 2's host
branch and `_damage_clone`. **Damage a body deals to a creature is untouched** — the cap is about surviving,
not about killing.

| what it does | |
|---|---|
| 까마귀 10 vs 30 hp | cap 15, deals **10 — unchanged**. Three crow hits survives verbatim, literal for literal |
| 들쥐 3 · 들개 14 · 멧돼지 20 | all under their caps at the level they are met. **Unchanged** |
| 사자 62 vs 60 hp (level 10) | cap 30 → **two hits** |
| 코끼리 78 vs 63 hp | cap 31 → **two hits** |
| **보스 120 vs 63 hp** | cap 31 → **two hits, at `CLONE_ATTACK_PERIOD` 1.2s with `HOST_HIT_GRACE` 1.0s.** ⇒ **2.2 seconds of contact ends the run.** Still the thing that kills you; no longer a thing that kills you before you saw it |

**No species exemption and no new column.** `hunting-and-the-boss-ko` says *"보스 force 120은 그냥 센 것이다
— 즉사 규칙 같은 예외는 없다"*, and this keeps that literally true: the boss is not exempted, it is simply
strong enough that half your bar is one touch.

Knockback keeps reading full force, deliberately: **an elephant still shoves you 62px while taking 31 hp.**
The hit reads enormous and costs half. That is the correct split between 연출 and rule.

It also scales with nothing added: the *ratio* is what is designed, so at level 20 a lion still takes half.

### Gating alone (Option D) is not a fix, and here is the proof

With §2's gates and no damage rule, you meet 사자 at 105s at roughly level 10 → `HOST_HP 30 + 10 x HP_PER_LEVEL 3` = **60 hp**, against force **62**. It still one-shots you. Postponement does not reach.

### The case against C — three objections, and they are real

1. **It deletes the meaning of force on the incoming side.** Above `2 x hp_max` a lion (62) and a boss (120)
   deal *exactly the same number*. The whole ×10 force rescale existed so that a boss is not a crow, and
   this hides that at the one moment it matters most. Only the knockback still separates them, and knockback
   is presentation.
2. **It half-refunds the cost of spreading wide.** A force-5 clone has `hp_max` 15; today a lion deletes it,
   under C it takes 7 and lives. *"흩어둔 무리는 갈려나간다. 그게 값이다"* is a design sentence, and nobody
   asked for it to be softened. ⇒ **The fork: apply the cap to the host only.** That keeps the swarm's cost
   intact — at the price of an asymmetry between the host and its clones, which is exactly the class of
   thing `melee-legibility-ko` §A-2 spent a page on. **Recommend the symmetric version**, and put the
   host-only variant in front of the user as the alternative.
3. **Two hits is a short window against a pack.** Three 들개 at 1.2s each is a swing every 0.4s against a
   1.0s grace, so the run ends in about three seconds regardless of the cap. **C fixes "I touched an
   elephant once"; it does not fix "I was surrounded".** `HOST_HIT_GRACE` is what would fix the second and
   this spec does not touch it.

---

## 5. The opening thirty seconds, beat by beat

### 5-0. The pocket must be **placed**, not rolled

§3 makes ~4 creatures *expected* on camera. Expected is not guaranteed, and the first thirty seconds of
every run is not a place to gamble. So `setup()` gets one extra step after the uniform layout:

**`Rules.OPENING_POCKET`** — a small table read once, at `setup()`, after the `SPECIES_START` loop:

```
OPENING_POCKET := [[들쥐, 280.0], [들쥐, 340.0], [까마귀, 520.0], [다람쥐, 640.0]]
```

Four bodies, at those distances from the host, at angles `i x TAU/4 + seeded_offset`. Deterministic per
seed, same **shape** every run — which is the property `SPECIES_START`'s own comment already claims
(*"counted rather than rolled so the opening is the same shape every run"*) and which the uniform layout
alone cannot deliver near the host.

All four go through `terrain.push_out` like every other placement, so none opens inside a rock.

### 5-1. The beats

| t | what is on screen | what the player does | what changes |
|---|---|---|---|
| **0.0s** | Host alone, centre. ~16 food spots. **2 들쥐 at 280/340px walking toward you at 90 px/s**, 1 까마귀 standing at 520, 1 다람쥐 at 640, plus ~4 uniform strays at the edges. Legend line up for 12s | reads the screen | — |
| **1.0s** | closing speed 290 px/s | walks at the near 들쥐 | contact |
| **1.2s** | | **left click** — 물기, RANGE 70, ARC 70°, cd 0.5 | force 10 vs hp 7 → **one bite, it dies.** Corpse + death burst |
| **1.4s** | corpse under you | stands still | 3 bites over 0.13s → `banked += 7.5` |
| **~4s** | second 들쥐 arrives on its own | kill, eat | `banked` 15 → **level 1 fires at 10.0** |
| | | | force **20**, hp 33, `LEVEL_POP` + bar flash. ⚠ **card offer is EMPTY** — 들쥐 drops nothing. §0-3's guard must handle this or the run enters the every-frame roll here |
| **6–11s** | 까마귀 at 520px, standing still (`SPECIES_WANDER[CROW]` 0) | walks to it, bites | force 20 vs hp 30 → **two bites.** It counters for 2s and hits for 10 → **hp 33 → 23**. First time the player is hit, from something two bites from dead |
| **11.5s** | crow corpse | eats — 3 bites, 0.5s | `banked` 45 → **level 2 (23.5) and level 3 (41.7) both fire.** force **40**, hp 39. **The card offer rolls for real** — 까마귀 날개 · 부리 · 발 are in the pool. First part worn |
| **13–20s** | 다람쥐 at 640px, fleeing at 170 px/s | chases (200 > 170), corners it | 1 bite. `banked` 57 |
| **20–30s** | pocket exhausted; the uniform field's 토끼 herd and more 들쥐 are the next things visible | **holds `F`** (0.45s) — force 40 splits to 20 + 20 | first clone. `1` and `3` become meaningful |
| **30s** | | | **level 4, force 50, hp 42, 1–3 bodies, one part worn** |

**The first click lands at 1.2 seconds and the first level at 4.** Today the first creature is off screen at
every seed and the first level is ~20 seconds of grass.

⚠ **The crow is placed at 520 and the squirrel at 640, deliberately in that order.** The squirrel is a
chase and the crow is a stand-and-hit; putting the chase first makes the run's second act a 15-second run
across empty grass. And the crow is the **only** thing in the pocket that opens the card pool.

---

## 6. Per-species attack gesture

### 6-1. Four species get none, and that must be written down

`_contact` pass 2 returns before attacking if `SPECIES_FLEES == 1`. **말 · 다람쥐 · 치타 · 토끼 never attack
anything, ever.** Specifying a gesture for them would be built, would never fire, and would pass every net.
Their "gesture" is the afterimage trail they already have (말·치타·토끼) or nothing (다람쥐).

### 6-2. Where it plugs in

Today there is exactly **one** attack mark for every creature: `field_view._paint_critter` line ~460,
a single `_paint_part_line` from the body toward `critter_swing_dir` of length `r x CRITTER_SWING_RING`,
plus the shared `_lunge_offset` body push.

⇒ Replace that one call with **`_paint_swing(c, s, at, r, dir, t)`**, a composer (`draw_*` count **0**) that
dispatches by species to the leaves below. `t` is `critter_swing_show / Look.CRITTER_SWING_TIME`, 0..1.

⚠ **Every one of these needs a row in `net_draw_leaf`'s `FIELD_LEAF_CALLS` with its exact count**, or
`_every_function_is_in_the_table()` reds the round by design. And every parameter handed to a leaf must be
**used in its body** — the scan that caught `_paint_disc` drawing at radius 0.

### 6-3. The gestures

| species | name | geometry | leaf | calls |
|---|---|---|---|---|
| **까마귀** | 쪼기 | Two strokes from the body edge to `edge + dir x r x 1.5`, at **±14°** around `dir`. Both drawn full length for the whole window — a fork, not a sweep | `_paint_part_line` | **2** |
| **들쥐** | 갉기 | One filled dot at the contact point `at + dir x r`, radius `r x 0.5 x (1 - t)`. **No line at all** — the quietest mark in the game, because it is 3 damage | `_paint_disc` | **1** |
| **들개** | 물어뜯기 | One stroke from `at` to `at + rotated(dir, θ) x r x 2.0`, where **θ sweeps -20° → +20°** across `t`. A rotating line, not a static one — it reads as a shake | `_paint_part_line` | **1** |
| **멧돼지** | 들이받기 | An arc of **90°** centred on `dir`, radius `r x 1.4`, drawn from `angle(dir) - 45°` to `angle(dir) - 45° + 90° x t` — it **wipes upward through the window** rather than appearing whole. Tusks | `_paint_arc` | **1** |
| **코끼리** | 밀치기 | One stroke **perpendicular** to `dir`, centred at `at + dir x r`, half-length `r x 0.8`, width `CRITTER_SWING_WIDTH x 2`. A bar shoved forward. Paired with a **doubled** lunge (`SWING_LUNGE_PUSH x 2` for this species) | `_paint_part_line` | **1** |
| **사자** | 덮치기 | **The lunge itself is the gesture** — `SWING_LUNGE_PUSH x 3` for this species — plus one shrinking dot at the landing point `at + dir x r x 1.8`, radius `HIT_SPARK_R x (1 - t)` | `_paint_disc` | **1** |
| **보스** | 내려찍기 | A full ring **on the ground at the boss's feet**, radius growing `r → r x 2.2` across `t`, width `ARENA_WALL_WIDTH`, alpha `1 - t`. Drawn as a `0 → TAU` arc | `_paint_arc` | **1** |

⚠ **`_paint_ring` may not be used for the boss stomp.** It draws **two** circles (the second at `r x 0.45`),
which is exactly the defect that dragged a 405px companion circle across the arena wall. `_paint_arc` from
0 to TAU is the one-circle leaf.

### 6-4. What the lunge multiplier costs

`SWING_LUNGE_PUSH` is one absolute number today, and its comment says so on purpose (*"a crow and an
elephant lunge the same distance, because it is a gesture and not a size"*). 코끼리 x2 and 사자 x3 **reverse
that sentence.** That is a deliberate change and it needs a `Look.SPECIES_LUNGE_MUL` table with eleven rows,
not two magic numbers at the call site — and the comment above `SWING_LUNGE_PUSH` has to be rewritten, or
the file states the opposite of what it does.

---

## 7. Sources — and they disagree with each other

The two calls that need one are **pacing** (fixed table vs. adaptive) and **density** (how many on screen).

- **Vampire Survivors — a fixed, per-minute wave table.** *Mad Forest* debuts enemy types at 0:00, 1:00,
  2:00, 3:00, 4:00, 5:00, 7:00, 8:00, 9:00, 12:00, 17:00, 21:00, and the on-screen minimum climbs 15 → 30 →
  50 → 80 → 100 → 300 while the spawn interval falls 1.0s → 0.5s → 0.25s → 0.1s. Density *is* the game and
  nothing about it adapts to the player.
  ⇒ This is the model §2 copies: a hand-authored unlock schedule, not a director.
  <https://vampire.survivors.wiki/w/Mad_Forest>
- **Valve — Left 4 Dead's AI Director** (Michael Booth, GDC 2009, *The AI Systems of Left 4 Dead*). The
  opposite call: an estimated per-survivor intensity drives a Build Up → Peak → **Relax** cycle, and the
  system **deliberately empties the field** after a hard fight. Booth's phrase is *"structured
  unpredictability"* — population functions that are "not purely random, nor deterministically uniform."
  ⇒ Argues directly against §2-2's fixed opening layout and against a constant density target.
  <https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf>
- **Hopoo Games — Risk of Rain 2's Directors.** A third answer: neither a table nor an intensity model, but
  a **credit budget that grows linearly with a difficulty coefficient over time**, spent on groups of up to
  four. Enemy selection is by cost, so *what* appears is an emergent consequence of *when*.
  ⇒ Would replace §2-1's unlock column with a price list. Cheaper to tune, much harder to author a
  30-second opening with.
  <https://riskofrain2.wiki.gg/wiki/Directors>
- **Hopoo Games — RoR2's symmetric level scaling**: players gain **+30% health and +20% damage** per level
  and monsters gain **exactly the same**, which the wiki notes makes late fights *longer* because health
  outruns damage. This is Option B in §4, in a shipped game, with the failure mode named.
  <https://riskofrain2.wiki.gg/wiki/Level>
- **Subset Games — Into the Breach.** The case for *keeping* one-shot damage: every enemy attack is
  telegraphed a full turn ahead, so a lethal blow is information rather than an ambush. Justin Ma on the
  one place they broke perfect information (the Resist mechanic): without it, *"if you knew you were going
  to lose the game from the next enemy attack, there was no reason to hit End Turn."*
  ⇒ Argues §4 is solving the wrong problem — that the lion should still one-shot, and what is missing is a
  wind-up the player can read. **§6's per-species gestures are half of that argument already**, and a
  builder could take C *and* the gestures and find the gestures did the work.
  <https://cliqist.com/2018/03/06/into-the-breach-building-a-better-mech-with-subset-games-justin-ma/>
- **Nintendo — Super Mario Bros. World 1-1**, on §5. Miyamoto: the level had to contain everything a player
  needs to *"gradually and naturally understand what they're doing."* The load-bearing detail is that the
  **first enemy was going to be a Koopa Troopa and was changed to a Goomba**, because teaching jump-and-kick
  before the player had the basics did not work.
  ⇒ That is exactly why §5-0 places a **들쥐** at 280px and not a 까마귀: a creature that dies to one click
  and cannot punish you comes before one that counters.
  <https://blog.adafruit.com/2025/09/14/miyamoto-explains-how-super-mario-bros-world-1-1-was-created/>
- **Bungie — Jaime Griesemer's "30 seconds of fun"**, and the correction: in the 2011 Engadget interview he
  says *everyone uses the quote to mean the opposite of what he intended* and that the second half was cut
  from the documentary. Cited here **as a caution**, not as support — §5 is a 30-second script, and the
  original claim was about a repeatable combat loop, not about an opening.
  <https://www.engadget.com/2011-07-14-half-minute-halo-an-interview-with-jaime-griesemer.html>

### The case against my own pick

**I picked the Vampire Survivors shape (a fixed table) over the Left 4 Dead shape (a director).** Against it:

1. **A fixed table cannot answer "the player is doing badly."** L4D's whole finding was that constant
   pressure is exhausting and constant emptiness is boring, and a table is blind to which one is happening.
   The user's complaint here — *"도저히 게임이 진행이 안 돼"* — is precisely the state a director exists to
   detect. A table fixes the average run and can still strand the bad one.
2. **RoR2's credit model is cheaper to retune than eleven `UNLOCK_AT` literals.** One coefficient moves the
   whole curve; my table needs eleven edits and a re-measurement each time.
3. **The counter-argument I am actually leaning on is authorability**, and it is weak: a director's opening
   thirty seconds is whatever the director happens to roll, and §5 is a *script*. The honest statement is
   **"a table because the first thirty seconds must be authored, and after 60s a director would probably be
   better"** — which is a real design debt this spec is choosing to take on.
4. **Into the Breach argues §4 is the wrong fix entirely.** If a lion's pounce were readable a full second
   ahead, one-shot damage would be fair and `MAX_HIT_FRACTION` would be an unnecessary softening of a game
   about a fragile cell. I do not believe a 190 px/s creature at this camera distance can telegraph that
   legibly, but **that is a belief, not a measurement, and eyes settle it.**

---

## 8. The joints — everything a builder must touch, because this repo leaks at joints

| # | file / symbol | edit |
|---|---|---|
| 1 | `Parts.Species` enum | `MOUSE = 7, RABBIT = 8, DOG = 9, BOAR = 10` |
| 2 | `Parts.SPECIES_NAME` | **four entries.** It is `Species.size()` long, not `ROWS`, and `net_parts` skips it **by name** — a short row here prints `?` on the ending screen and nothing goes red |
| 3 | `Rules.SPECIES_RADIUS · _FORCE_MIN · _FORCE_MAX · _SPEED_MUL · _FLEES · _REACH_BONUS · _WANDER · _HUNTS · _HERD · _START · _SPAWN_WEIGHT` | **eleven tables x four rows.** A table one row short is the silent failure of this whole plan |
| 4 | `Rules.SPECIES_UNLOCK_AT` | new, eleven rows |
| 5 | `Rules.CRITTER_START_MIN_DIST` 260 · `CRITTER_SPAWN_MIN_DIST` 900→1450 · `CRITTER_MAX` 64→96 · `MAX_HIT_FRACTION` 0.5 · `OPENING_POCKET` | new / retuned |
| 6 | `Look` | four colours |
| 7 | `Look.SPECIES_LUNGE_MUL` | new, eleven rows (§6-4) — and `SWING_LUNGE_PUSH`'s comment is now false and must be rewritten |
| 8 | `FieldView.SPECIES_COLOR` | four entries. `_force_labels` already loops `SPECIES_COLOR.size()`, so it follows for free |
| 9 | `World._roll_species()` | skip locked rows; **re-normalise the divisor**; the "last non-zero row" fallback becomes "last *unlocked* non-zero row" |
| 10 | `World.setup()` | skip locked rows at t=0; use `CRITTER_START_MIN_DIST`; place `OPENING_POCKET` after the uniform loop |
| 11 | `World._anchor_min_dist()` | must know which of the two base distances it is adding `SPAWN_HERD_SPREAD` to |
| 12 | `World._contact()` pass 2 host branch · `World._damage_clone()` | the `MAX_HIT_FRACTION` cap. **Knockback keeps reading full force** |
| 13 | `World._grow()` / `Cards` | §0-3's empty-pool guard. **Prerequisite** |
| 14 | `FieldView._paint_critter` | the single `_paint_part_line` becomes `_paint_swing(...)`; six new leaves |
| 15 | `net_draw_leaf.FIELD_LEAF_CALLS` | `_paint_swing: 0` plus **six leaf rows with exact counts**. `_every_function_is_in_the_table()` reds until every one is listed |
| 16 | `net_field` — the hunts check | today it asserts `hunters == 1` and `그 하나는 사자다`. **It becomes three, named**, and each must be asserted under `HOST_SPEED`. ⚠ This is a design reversal (`_step_critters`' comment: *"여섯 개가 타이머로 걸어오는 것은 사용자가 거절한 것"*) and **it needs a line in `docs/decisions/`**: the user's own words reopened it |
| 17 | `net_field` — the opening-count check | `SPECIES_START x SPECIES_HERD` sum moves 31 → 53 |
| 18 | `net_numbers` | four new radius/force literals; the three CROW/HORSE/BOSS ordering assertions are untouched |
| 19 | `Rules.SPECIES_RADIUS` comment | **correct it** — the "종 순서는 절대 뒤집히지 않는다" claim is already false (치타 22.5 vs 말 22) |
| 20 | `rules.gd` file header | the speed chain, rewritten with four new entries (§1-4) |
| 21 | `tools/look/probe_field.gd` | gate the `한 방인가` column on `SPECIES_FLEES` (§0-2) |

**What is NOT touched**: `Parts.DROPS`, `Parts.SPECIES`, the card pool, the horse trait, `Parts.RANGE/ARC`,
`EXP_PER_FORCE`, `LEVEL_COST_*`, `FORCE_PER_LEVEL`, `HP_PER_FORCE`, `HP_PER_LEVEL`, `HOST_HP`,
`CRITTER_INTERVAL`, `BOSS_HUNT_AT`, `FOOD_SPOTS`, `ROCK_*`, `WATER_*`.

---

## 9. The curve, mark by mark

Exp arithmetic: a corpse pays `force x EXP_PER_FORCE 3.0`; a grass crumb pays 1.0.
Level *n* costs `LEVEL_COST_BASE 10 x 1.35^n`, cumulative:
`10.0 · 23.5 · 41.7 · 66.3 · 99.6 · 144.4 · 204.9 · 286.6 · 397.0 · 545.9 · 747.0 · 1018.4`.
Force = `10 + 10 x level`. Host hp_max = `30 + 3 x level`. A creature's hp = `force x 3`.
A host bite deals the host's **whole force**, so a creature dies in one bite once `host_force >= creature_force x 3`.

Corpse values: 들쥐 7.5 · 다람쥐 12 · 토끼 21 · 까마귀 30 · 들개 42 · 멧돼지 60 · 치타 90 · 말 105 ·
사자 186 · 코끼리 234 · 보스 360.

| t | new on the field | plausible banked | level | force | hp | what the run feels like |
|---|---|---|---|---|---|---|
| **0s** | 들쥐 18 · 다람쥐 8 · 까마귀 10 · 토끼 8 · 말 8 · 치타 1 · 보스 1 = **54** | 0 | 0 | 10 | 30 | four creatures within 700px, all safe |
| **30s** | — | ~102 | **4** | 50 | 42 | a crow dies in one bite. First part worn. 1–3 clones |
| **60s** | — | ~305 | **8** | 90 | 54 | 까마귀·토끼·다람쥐·들쥐 are all one bite. A 말 herd is now the interesting problem, and 토끼 taught the hand |
| **45s** | **들개 unlocks** (3 at a time, hunts the nearest body) | | | | | the first reason to press `1`. A scattered swarm loses clones |
| **75s** | **멧돼지 unlocks** | | | | | the first thing worth pressing `3` at. hp 60 against a force-90 bite is one bite for the host and free for the swarm |
| **90s** | — | ~560 | **10** | 110 | 60 | the host's own force is now above every unlocked creature. This is the peak of the growth curve |
| **105s** | **사자 unlocks** (2 at a time, hunts) | | | | | 186 exp each, 3 bites, capped to 30 damage → two hits. The first genuine danger |
| **120s** | **코끼리 unlocks** (3 at a time) | ~750 | **11** | 120 | 63 | 234 exp each. 120–150 is not a growth window — it is a survival window, and that is the intent |
| **150s** | **`BOSS_HUNT_AT` — the boss comes, arena closes** | | 11 | **120** | 63 | boss force **120**, host force **120**. hp 360 → **3 host bites** plus the swarm. It takes 31 a hit → **2.2s of contact ends the run** |

**The run's whole arc is force 10 → 120, and the boss is 120.** That is not a coincidence to be tuned away —
it is the statement the curve makes, and it is the check that says the numbers are right.

⚠ **The growth curve tops out at ~90s and the last 60 seconds pay nothing.** That is deliberate under this
spec (105–150 is 사자/코끼리/보스 and is about surviving), but it is the weakest part of the design and the
first thing play will find. **The fallback is `BOSS_HUNT_AT` 150 → 120**, with 사자 at 90 and 코끼리 at 105.
I am not taking it now because 150 is the shipped number and moving it changes the arena beat as well as the
curve — but if the user's read is that 120–150 is empty, **that is the one-line answer.**

---

## 10. What I could not decide — this list is part of the deliverable

1. **Symmetric cap or host-only cap** (§4 objection 2). The symmetric version softens *"흩어둔 무리는
   갈려나간다. 그게 값이다"*; the host-only version introduces the host/clone asymmetry `melee-legibility-ko`
   §A-2 already complains about. **No document in the repo ranks those two costs.** The user picks.
2. **Whether the cap is right at all, versus telegraphed one-shots** (Into the Breach). §6's gestures might
   do the whole job. Only play answers it, and the cheap experiment is to build **both** and turn
   `MAX_HIT_FRACTION` to 1.0 for one session.
3. **`BOSS_HUNT_AT` 150 vs 120** (§9). The arithmetic says 120; the shipped number says 150; nothing in the
   repo says which the arena beat wants.
4. **치타's hand.** It is the one species with no answer, and this spec did not give it one. Options nobody
   has ranked: drop it to 1.10 (into 토끼's band, catchable by clones), give it a stamina that expires, or
   delete it. All three are one line and all three change what it *is*.
5. **Whether three hunters is right.** The user's *"몬스터가 내 주변에 없어"* reopens a decision that was
   made in the other direction ("six things walking at you on a timer is what the user rejected"). Three at
   three threat levels is my read; **it is a reversal and it needs the user's word before it goes in
   `docs/decisions/`.**
6. **Ponds.** The user said *"물만 존나 있고"*, and by area they are 7.8%, so the complaint is about what
   *else* there is. §1–§3 is my answer. The untested alternative is `WATER_COUNT` 12 → 16 at radius 70–130
   — more, smaller ponds, **less** total water, better herding walls. **Unmeasured, and I did not put it in
   the spec.**
7. **Whether the opening pocket should be visible from frame one or walked to.** I placed the nearest 들쥐
   at 280px (visible, 1.4s away). L4D would argue for an empty first five seconds so the first creature is
   an event. **Untested either way.**
8. **`SPECIES_HERD[들쥐] = 6` may be too many.** Six mice converging is a nice picture and also six bodies
   worth 7.5 exp each, i.e. 45 exp from one herd — four and a half levels' worth at the opening cost curve.
   If the opening levels too fast, this is the number, not `LEVEL_COST_BASE`.
9. **Nothing here is drawn.** Every colour is a placeholder; art in this repo is decided by generating
   candidates and pointing at one, and four new species is four new candidates the user has not seen.


---

## 지어진 뒤 — 이 문서와 달라진 것

1. **`CRITTER_SPAWN_MIN_DIST`는 1450이 아니라 950이다.** §3이 1450을 고른 근거는 「가장 멀리 물러난
   카메라의 반대각선 1377px」이었는데 **그 값이 1.5배 틀렸다.** 뷰포트 1280×720에 `Look.ZOOM_FAR` 0.8이면
   보이는 세계는 1600×900이고 반대각선의 절반은 `hypot(800,450)` = **918**이다. 1450은 필요한 것보다
   1.6배 멀었고, 그 차이는 전부 「다음 놈까지 걸어가는 빈 시간」으로 나왔다. 950이 918을 32px 넘긴다.
   `net_numbers`가 1377을 그대로 들고 있었고, 지금은 918을 파생해서 재고 리터럴도 함께 못박는다.

2. **`OPENING_POCKET`의 뒤 두 줄이 520·640에서 400·440으로 당겨졌다.** 개막 카메라의 보장 반경은
   **459px**(`hypot(400,225)`)이라, 520과 640은 **60개 시드 중 0번** 화면에 들어왔다 — 그리고 그중 하나가
   **카드 풀을 여는 유일한 몸인 까마귀**였다. 「굴리지 않고 놓는다」가 사려던 것이 그것이므로 넷 다 안으로
   넣었다.

3. **§0-3(빈 카드 제안이 매 프레임 도는 버그)은 이 문서가 말한 버그가 아니다.** 뮤테이션으로 되돌려도
   초록이었다 — `pool_size()`가 `roll()`과 같은 루프를 돌고, 빈 풀에서는 `roll()`이 rng를 안 뽑으므로 두
   가드가 행동상 동일하다. 변경은 유지했지만(한 함수가 필터를 소유한다) **매 프레임 일이 없어진 것은
   아니다.**

4. **§4의 산술이 홀수 최대치에서 한 대 어긋난다.** `int()`가 버리므로 레벨 11(최대 63)에서 상한은 31이고
   31+31=62 < 63 — 보스가 두 대가 아니라 **세 대**다. 공식대로 지었고 `net_hunt._m4`가 측정된 셋을 이유와
   함께 못박는다. 그리고 그 「두 대」는 **레벨의 성질이 아니라 입은 것의 성질**이다 — `Parts.HP`가
   홀수(까마귀 발 3, 말 갈기 5)면 패리티가 바뀐다.

5. **`PLACE_TRIES` 12 → 40**, 이 문서에 없던 결정이다. 60개 씨앗으로 실제 스포너를 재서, 12번이면 무리
   몸의 7.6%가 보장 거리 안에서 태어났다. 40에서 0/2880.

6. **계기 자신이 두 번 틀렸었다.** `probe_run.gd`의 봇이 「힘 ≥ 체력이면 즉사」로 판단했는데
   `MAX_HIT_FRACTION`이 그것을 거짓으로 만들었고, `SPECIES_FLEES`도 안 봤다. 고친 뒤의 정직한 값은
   48%가 아니라 **58%**였다. **자기 성적을 매기는 계기가 자기에게 유리하게 틀려 있었다.**
