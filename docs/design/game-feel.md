# Game feel — the list of ways to make it hit harder

**One line**: every lever that could make this game feel tighter, **with what it costs and where it is allowed to live.**
Nothing here is chosen — **the user asked for the list, not for the work.**

**Implemented**: partial — the blast side (screen shake + flash, `view/blast_fx.gd`) · damage numbers ·
**hit reaction** (white flash + a weak screen shake on taking damage) · **coyote time and the jump buffer**
(`character.gd`, `net_character` F-1–F-5) · **footfall dust** · **sound** (`sfx_bank.gd`, procedural synthesis —
fire, impact, jump, land, hit; `Fx.SFX_ENABLED` turns it off) · **camera 1.5× zoom with a vertical offset** and
a damped vertical parallax on the background (`BG_VERTICAL_FOLLOW_FRAC` 0.15) · **player airtime raised**
0.6s → 0.75s (`PLAYER_GRAVITY_PX`, split from the shared `GRAVITY_PX` so bosses keep the old value — their
jump trajectories are tuned against it). **"No sound anywhere" is no longer true.**
**Accepted**: the user has launched and looked at the game repeatedly this session, with fixes made each
time — **but no single item above was separately called out and judged as "does this feel right"**, and none
has a net measuring the *feel*, only that the code path runs. Treat all of it as seen-but-not-judged

**This doc is a menu, not a plan.** When one of these is picked it gets its own `docs/plans/` doc.

---

## The one report that exists — **"moving, the camera and jumping feel slightly unpleasant"** (the user)

**Not "there is no juice" — three separate defects that happen to land on the same finger.**
Everything below was read out of the code, not guessed.

### 1. The camera is glued to the character — **the most likely culprit**

`stage._process` sets `_camera.position` to the character's centre **every frame.** No smoothing, no dead zone,
no look-ahead. And `project.godot` has `snap_2d_transforms_to_pixel=true` ⇒ **the character is nailed to one
screen pixel and the entire world slides past in 1px steps.**

**That is the picture the eye reads as unpleasant**: nothing on screen ever moves *except* the background,
in stair-steps. It is not a bug — following was chosen deliberately (`stage.gd`'s camera box, and the price is GDD #5) —
**but "follow" was implemented as "lock", and those are different things.**

⇒ **A dead zone (roughly ±40px horizontally) plus 0.1–0.15s of smoothing**, and **look-ahead in the direction
of travel.** The character gets to move *within* the screen, which is the whole point of a following camera.
**Watch one thing**: whatever smooths it must still land on whole pixels, or the snap setting fights it.

### 2. Left/right has no acceleration and no friction

`character.gd`'s `recoil_vx` block — `move * MOVE_SPEED_PX` (180) straight into the position. **Full speed in one frame,
dead stop in one frame.**

**Instant start is probably right** — this is an aiming game and input latency is the enemy.
**Instant stop is what reads as weightless.** ⇒ Try **deceleration only** (2–3 frames of slide), leave the start alone.
This is the one item on the doc where the current behaviour might be correct; **it has to be tried and looked at.**

### 3. The jump — three causes stacked, and only one of them is the numbers

| Cause | Measured | State |
|---|---|---|
| **No coyote time, no jump buffer** | Neither existed in `character.gd` | **Fixed. 0.1s each** (`COYOTE_SEC` · `JUMP_BUFFER_SEC`), five nets in `net_character` F-1–F-5, every one confirmed to bite under mutation. **Not looked at on screen yet** |
| **0.6s of airtime feels floaty** | `GRAVITY_PX` 2400 · `JUMP_VY_PX` -720 ⇒ 3.4 tiles, 0.6s | **Addressed, in the opposite direction from the fix sketched below.** The player's fall now runs on its own `PLAYER_GRAVITY_PX` (1536, paired with a re-tuned `JUMP_VY_PX`) and airtime went **0.6s → 0.75s** — floatier, not snappier. Bosses keep the shared `GRAVITY_PX` 2400 unchanged, because their jump trajectories are tuned against it. **Not separately judged as feel** |
| ~~**Ground state is 20Hz**~~ | **Wrong, and it was mine.** `on_ground` is read at the top of `step()`, which runs every `_physics_process` — **60Hz.** The 20Hz warning on `character.on_ground` is about `in_water`, and it is the reason that value is **not** put in `on_tick()` | No defect. Nothing to fix |

**Raising falling gravity changes the level, not just the feel** — and the direction actually taken lowered it
instead (see the table above), which widens jump reach rather than shrinking it. **Stage 1's map was drawn by
hand and by eye against the old number**, so a gap that used to be a real check is now easier, **with nothing
in code to complain.** Re-walk the map's jump-only gaps before trusting any of them are still meaningful.

**Order for what is left**: camera dead zone + smoothing → falling gravity (on screen, with the map) →
walk deceleration.

---

## What the folder contract already decides for you

**Most of this list is free, and a few items are expensive — and it is the folder that tells you which.**

| Where it lands | What it may do | Cost |
|---|---|---|
| `src/view/` | shake · flash · squash · dust · trails · numbers · time-scaled *presentation* | **Free.** The sim never sees it. Cannot desync |
| `src/actor/` | knockback on monsters · coyote time · accel curves · pickup arcs | **Cheap.** Float allowed, host-authoritative |
| `src/sim/` | anything that changes bolts or the grid | **Expensive.** Integer only, and `g.step()` already runs **84ms/tick against a 50ms budget** at the active-chunk cap (`water.md`, "Cost") |

⇒ **Prefer view-side juice.** Not for purity — the sim has no headroom left.

**And two multiplayer walls, so they aren't discovered late** (GDD, "Multiplayer"):

- **Nothing global may stop time.** Hitstop and slow-motion freeze *everyone* in co-op, and in the lockstep half
  one client stopping alone **is desync outright.** `blast_fx.gd`'s header already paid this once and settled on
  shake + flash duration as the substitute
- **Anything the player's body does is host-authoritative** — fine — but **anything a bolt does is lockstep.**
  A "juicier bolt" is a determinism change, not a polish change

---

## A. The moment of contact — the shortest path to "it hit"

| # | Lever | Where | Note |
|---|---|---|---|
| 1 | **Monsters recoil when hit** | `actor/` | **The single biggest gap.** `monster.gd` only subtracts `hp` — a pig takes a bolt and **keeps walking at the same speed.** The player's own knockback was deleted on purpose; **the monster's was never built.** No art needed |
| 2 | **Hitstop, revisited** | `view/` | Dropped once, replaced by flash duration (`decisions/README`). **The reason was co-op, and it still holds** ⇒ if revived, it must be **per-target** (that one monster freezes, the world doesn't) |
| 3 | **Flash that scales with the hit** | `view/` | **A flash (white) + a weak screen shake now fire on every hit taken.** Still one shape — it does not yet scale with `power_pct`, so a 20 and a 10 read identically |
| 4 | **Damage numbers that pop** | `view/` | They exist as text. Scale-up-then-settle, drift, colour by size |
| 5 | **Death is currently instant disappearance** | `view/` | No pop, no gib, no fade. **A monster vanishing mid-step is the cheapest thing on this list to fix and one of the most felt** |

## B. The moment of firing — right now nothing happens at the staff

| # | Lever | Where | Note |
|---|---|---|---|
| 6 | **Muzzle flash / firing pose** | `view/` | The bolt appears out of nothing. The staff tip is already a known point (`staff-and-fire-origin`) |
| 7 | ~~**Slow the bolt so the art exists**~~ | sim | **Done in code, unseen** → `plans/3.done/bolt-speed-and-visibility`. 26.6px/frame is now 16.0, so the head sprite *can* be seen — **whether it now feels sluggish is the open question**, and it is answered on the screen |
| 8 | **Recoil the player can read** | `actor/` | `recoil_vx` is **15% of walk speed** and decays — measured to win against input. It is *felt* but **nothing on screen says it happened** |
| 9 | **Fire rhythm** | `actor/` | There is no wind-up and no cooldown texture — click and it goes. The GDD already gave this axis an owner: **the staff** (gear). Not free: it changes balance, not just feel |

## C. The body — the cheapest responsiveness wins are missing

| # | Lever | Where | Note |
|---|---|---|---|
| ~~10~~ | ~~Coyote time · jump buffer~~ | `actor/` | **Built.** 0.1s each, spent on the jump they pay for (so no double jump falls out of it). `net_character` F-1–F-5 |
| 11 | **Walk has no acceleration** | `actor/` | `move * MOVE_SPEED_PX` — full speed in one frame, dead stop in one frame. **Deceleration only** is the shape to try. Reported by the user — above |
| 11b | **Falling gravity · apex hang** | `actor/` | 0.6s of airtime. **Raise the fall, never the rise** — the jump height is a designed value. Reported by the user — above |
| ~~11c~~ | ~~Grounding is sampled at 20Hz~~ | — | **It is 60Hz. The claim was wrong** — see the diagnosis above. Kept here so it is not "found" again |
| 12 | **Land squash · dust · run dust** | `view/` | **Footfall dust is in.** Land squash is not |
| 13 | **Falling has no acceleration in water** | sim | The user already called this **"cheap"** (`water.md`). Constant 7.5 tiles/s. It is on the water doc's list, not a new item |

## D. The screen as a whole

| # | Lever | Where | Note |
|---|---|---|---|
| 13b | **Camera dead zone · smoothing · look-ahead** | `stage/` | **Reported by the user, and the top suspect** — the camera is locked to the character (diagnosis above). **A 1.5× zoom with a vertical offset landed this session, plus a damped vertical parallax on the background** (`BG_VERTICAL_FOLLOW_FRAC` 0.15) — neither is the dead-zone/smoothing/look-ahead fix sketched above; the lock itself is still there |
| 14 | **Shake that separates the causes** | `view/` | Shake exists **only for blasts**, keyed to generation. A bull's charge into a wall and a landing should not borrow the blast's curve |
| 15 | **Light from a blast** | `view/` | A flash of light on the terrain around a detonation. **Watch the price** — the terrain is a TileMapLayer, not lit geometry |
| 16 | **XP and money that fly to you** | `actor/` | Stage B put `xp`/`money` in the tables with **no object on screen at all.** Pickups that arc out and home in are, in this genre, one of the strongest per-kill rewards — and **the arc is `actor/`, so it costs the sim nothing** |
| 17 | **Low-health screen edge** | `view/` | Health exists (`character-damage-minimum`); the screen never says so except through numbers |

## E. **Sound — landed this session.** `sfx_bank.gd`, procedural synthesis, no audio files on disk

**"There is none" is no longer true.** Fire, impact, jump, land and hit each get a synthesized cue through
`sfx_bank.gd`; `Fx.SFX_ENABLED` turns the whole axis off. **Headless nets can only count that a cue fired,
never judge how it sounds** — that half of "feel" still needs eyes (ears), and it still needs its own doc for
anything beyond what shipped: which other moments get a cue, mixing, volume, buses.

Firing, impact, the wood wall catching, water pouring, a pig dying — coverage of *which* of these has a cue
and which don't is unaudited; go through this list against `sfx_bank.gd` before assuming more landed than the
five named above.

---

## If it were ordered — cheapest hit first

**Not chosen. This is what the list looks like sorted by (felt / cost).**
**The user's own three come first — they are reported defects, not improvements** (13b · 10 · 11b · 11c · 11).

0. **13b** camera dead zone + smoothing — the only one the user pointed at twice. **Zoom + vertical offset
   landed instead; the lock itself is still open**
1. ~~**10** coyote time + jump buffer~~ — **done, unseen**
2. **1** monster recoil on hit — hours, no art, every kill in the game gets it. **Still not built**
3. **5** death pop — one view effect
4. **16** XP/money pickups — the reward loop currently has no object
5. **7** bolt speed — a doc already exists and is waiting on the screen
6. ~~**E** sound~~ — **landed** (procedural, five cues). Coverage and mixing are still open

---

## TBD

- **Whether instant walk (11) is a defect or the identity.** Aim-first games often want no accel. **Try, look, decide**
- **Whether hitstop can come back per-target** without the co-op problem that killed it
- **Sound: engine path, source of assets, who owns the doc**
