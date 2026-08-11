# Attack rhythm — where the "펑 펑 펑" would come from

**One line**: firing today has **no cadence of its own** — one left-click press is one shot, gated by nothing
but "is the circle assembled", so the rhythm of combat is **the rhythm of the player's mouse hand**. This doc
maps what a rhythm could be made of here. It **decides nothing.**

**Implemented**: **none.** Not one line was written for this doc
**Accepted**: **unseen** — there is nothing built to look at

**A concept stays alive and never changes folders.** The two header lines are only "how much runs now" —
format per [README.md](README.md).

**Opened by the user**: "공격의 리듬을 좀 넣고 싶긴 하거든. 펑 펑 펑 이렇게." Then deferred in the same breath
("그건 나중에 해야 될 일이고"). **That sentence is the entire input.** Everything below is options, not a design.

**This is not a new axis** — [game-feel.md](game-feel.md) lever **#9 "Fire rhythm"** already names it and points
at the staff. That row stays the one-line entry; this doc is the space behind it, and does not repeat its list.

---

## 1. What fires today — the foundation

| Step | Where | What it does |
|---|---|---|
| Left mouse **press** | `stage_input`'s `fire_requested` emit | **`mb.pressed` only** — no hold-repeat, no auto-fire |
| Gate | `stage._fire_at` | `_circle.can_fire()` — a circle exists and no rune slot is empty (`spell_circle.can_fire`). **That is the only gate** |
| Shot list | `spell_circle.shots()` | `[{element, glyphs, delay}]` |
| Queue | `world_step.enqueue` | seats the cmd at `tick + 1 + delay` |
| Drain → fire → push | `world_step._drain_queue` | `_spell.fire(cmd)`; **on true only**, `_char.recoil(adx, ady)` |

**There is no cooldown, no wind-up, no rate limit, and no shot budget per second anywhere in that path.**
Searched: nothing in `src/` counts ticks between shots for the player. Click twice in one frame's worth of
human speed and both go.

⇒ **Answer to "is there any rhythm today": one, and it is not the attack's.**

### The one rhythm that already exists — `seq_ticks`

A **triangle** circle's `shots()` returns three entries with `delay = i * seq_ticks`, and
`seq_ticks = 6` (`circle_defs.DEFS`, the triangle row). At `TICK_DIVIDER = 3` (`sim_tuning`, 20Hz) that is

```
bolt 0   tick +0     0 ms
bolt 1   tick +6   300 ms
bolt 2   tick +12  600 ms
```

**That is literally 펑 · 펑 · 펑, in code, today.** Three separated detonations from one press, each with its
own recoil (`stage._fire_at`'s own comment says so explicitly — three shots means three recoils).

Two things keep it from being the answer:

- **It belongs to one circle, not to attacking.** Own the round circle and there is no rhythm at all
- **6 is provisional and no one has looked at it.** `circle_defs.DEFS`'s own comment — "the default from the
  doc's 'To decide' table — reversible, one integer, until the user judges it on screen"

⇒ **The cheapest experiment in this whole doc is to put a triangle circle in the user's hands and ask whether
that is the 펑 펑 펑 they meant.** No new mechanism, one integer to tune. **TBD: has the user ever fired one.**

### Recoil, the other half that already exists

`RECOIL_SPEED_PX = 40.0`, `RECOIL_DECAY_PER_SEC = 0.02` (`character.gd`, the recoil block) against
`MOVE_SPEED_PX = 180.0` — **22% of walk speed**, horizontal only (the vertical line was deleted;
`character.step` records why, and `_firing_down_does_not_lift_me` asserts it stays deleted).

> **Corrected 2026-08-11.** This read "260.0 — 15%" and both halves were stale: the walk was **lowered to
> 180** and nobody came back here. **Recoil is half again as large a share of the walk as this doc claimed**,
> which matters for row D below, where the whole proposal is to raise it. Found by sweeping line-number
> citations, not by anyone reading the paragraph.

**Rhythm is already being pushed into the body and nothing on screen says so** — [game-feel.md](game-feel.md) #8.

---

## 2. The axis map — what "펑 펑 펑" could mean here

Each row is an option with its price **in this codebase**, not in general.

### A. Fixed cadence / cooldown

A minimum tick gap between shots; clicking faster does nothing.

- **Cost**: cheapest possible — one integer of ticks and one counter. Ticks are the sim's own clock, so it is
  deterministic for free
- **Collides with**: **it is a nerf before it is a feel change.** Today's DPS ceiling is the mouse hand; a cap
  lowers it, and `game-feel.md` #9 already flags "it changes balance, not just feel"
- **Collides with**: the GDD gives **rate** to the **staff** slot (`GDD.md`, "Not settled — a direction that came out of conversation") — so the number is gear's,
  and hardcoding it in `character.gd` today plants a constant that gear later has to fight
- **Note**: a cooldown alone is not "펑 펑 펑". It is "펑 ... 펑 ... 펑" — even, not grouped

### B. Burst — one press, a three-shot volley

Exactly what the user's onomatopoeia describes.

- **Cost**: **the mechanism already exists.** `shots()` + `enqueue(cmd, delay)` carry it; a burst is that same
  `delay` ladder driven by something other than the circle's picture
- **Cost**: **three bolts per press instead of one.** `MAX_BLASTS_PER_TICK = 4` and four large blasts measured
  **8,940us = 54% of budget** in v1, **1,291us re-measured on this machine at `rd` 12**
  (`sim_tuning.MAX_BLASTS_PER_TICK`'s own box). Overflow **defers to the next tick** rather than discarding, so a burst
  does not vanish — it **smears**, which is itself a rhythm change nobody chose
- **Collides, hard**: [../decisions/shot-explosion-by-rule.md](../decisions/shot-explosion-by-rule.md) —
  the simultaneous cap was **explicitly rejected as a design knob**, because "a bolt that fails to fire because
  of a cap reads as a malfunction". **A burst tuned against that cap reopens a closed decision.** The rule that
  doc set is: constrain the **glyph**, at assembly time. Burst × spread (8 bolts) is 24 detonations from one
  press and must be answered by a glyph constraint, not by a cap
- **Collides**: three recoils per press. At 22% of walk each, a burst is a noticeable shove backward —
  that may be the feature (see D) or may make aiming unpleasant. **TBD, and only the screen answers it**

### C. Charge and release

Hold to wind up, release to fire; longer hold, bigger 펑.

- **Cost**: highest of the six. It needs a held-input state, a visible charge tell, and a release edge
- **The trap lives here** — see §3. The release is a **single-frame fact** read by 20Hz code
- **Collides**: it makes the first shot *slower*, which is the opposite of "펑 펑 펑". Charge gives
  **one big 펑**, not three
- **Collides**: multiplayer — a charge level is player state, and the player is host-authoritative
  (`GDD.md`, "Multiplayer"), while the bolt it produces is deterministic. **That is a widening of exactly the
  boundary the GDD says to keep narrow** — that section's own closing instruction

### D. Rhythm from recoil and repositioning — **the gun is not the metronome, the body is**

Firing already pushes the player (`character.step`). Raise it and each shot costs a step back; the loop
becomes fire · fire · reposition · fire, and the cadence is **emergent** rather than enforced.

- **Cost**: **one constant.** `RECOIL_SPEED_PX` is already there, already decays frame-rate-independently
- **Cost**: `src/actor/` only. **The sim is not touched at all** — no determinism question, since the player is
  host-authoritative anyway (`src/actor/staff.gd` header)
- **Collides**: `game-feel.md` #8 — recoil is *felt* but **nothing on screen says it happened.** Raising it
  without a screen tell risks reading as "the controls are drifting"
- **Collides**: the user has already called movement and the camera unpleasant (`game-feel.md`,
  **fail 2026-08-08**). **Adding motion the player did not ask for, on top of a movement feel already
  rejected, is the highest-risk row here** — and it is also the cheapest to try and revert
- **Note**: the deleted vertical recoil (rocket jump, `character.step`'s own note) is the extreme form of this row.
  Reviving it takes more than one line, and a net currently **asserts it stays dead**

### E. Rhythm from the circle's own structure

`seq_ticks` per circle — the shape of the assembly decides the beat, so a build *is* a rhythm.

- **Cost**: **already built** (§1). Extending it means new circle rows, not new mechanism
- **Fits the game's spine**: the circle is the identity system; making rhythm one more thing you assemble costs
  no new rule
- **Collides**: it is **not available to everyone.** The starting round circle is `seq_ticks: 0`, so a new
  player's attack still has no rhythm — this row improves the late build, not the first minute
- **Collides**: `shots()` splits a triangle's glyphs one-per-socket (`spell_circle.shots`'s header), so its three
  bolts are already *different spells*. That is a **melody**, not a drum — whether that reads as rhythm or as
  chaos is unknown. **TBD**

### F. Audio / visual cadence, no mechanical change

The beat is *heard and seen*, the sim is untouched.

- ⚠ **This row said "this game has no sound at all" and that has been false for some time.** `sfx_bank.gd`
  synthesizes fire · impact · jump · land · hit at boot, with no audio files on disk, and `Fx.SFX_ENABLED`
  turns the axis off. **`game-feel.md` had already been corrected** — its section E is titled "Sound —
  landed this session" — **and the correction never walked over here.** That is CLAUDE.md's own named
  failure: *a refutation that lands in a different doc than the claim does not propagate.*
  ⇒ **"펑 펑 펑" can be made audible today.** The user described the rhythm with a sound and the game can
  now make one; what is missing is a cue tied to *cadence* rather than to each individual shot.
- **Cost**: audio is view-side and **never re-enters the sim** — none of the determinism or budget arguments
  apply (`game-feel.md`, section E). It still **needs its own doc**, which does not exist yet
- **Visual half is cheap**: shake exists **only for blasts, keyed to generation** (`game-feel.md` #14), and
  there is **no muzzle flash** (#6) — the bolt appears out of nothing, from a staff tip that is already a
  known point (`src/actor/staff.gd`)
- **Collides**: nothing mechanical. **This row cannot be wrong, only insufficient** — if what the user wants is
  a felt cadence in the hand, dressing the existing single shot will not deliver it

---

## 3. The 60Hz / 20Hz trap, applied to cadence

`TICK_DIVIDER = 3` (`sim_tuning`). CLAUDE.md's trap: **a 60Hz event whose period shares a factor
with 3 lands on the same tick phase every time and the tick never sees it** — the symptom is not a wrong value
but **a thing that never happens.**

**Which cadences are dangerous, precisely:**

| Shape | Verdict |
|---|---|
| Cadence counted in **sim ticks** (`seq_ticks`, `enqueue` delay) | **Safe.** The tick is the sim's own clock; there is no sampling |
| Cadence counted in **60Hz frames**, any multiple of 3 (3 · 6 · 9 · **a 3-beat volley**) | **Dangerous.** Every beat lands on the same phase, so a 20Hz observer sees one phase forever and a check written against it can be green while a beat is silently lost |
| **Single-frame input facts** — `just_pressed`, `just_released`, a charge crossing its threshold | **Dangerous, and this is where C lives.** The fact is true for one 60Hz frame; the tick that consumes it may never be looking |

**A three-beat rhythm is exactly the shape this trap eats**, and it is the shape the user asked for.

**The fix is already written three times in this repo**: `_charge_blocked` · `_leaped_landed` ·
`_grounded_recently` (CLAUDE.md). **Latch the 60Hz fact in a bool, let the tick read it and clear it.**
Reach for that shape before inventing a fourth. Note that the name `_charge_blocked` is the bull's, not a
player charge — the *pattern* is what transfers, not the field.

**Multiplayer is the second reason.** Host-authoritative co-op with a deterministic grid and deterministic
projectiles (`GDD.md`, "Multiplayer"). **Anything frame-timed rather than tick-timed is a desync**, and the
GDD's own instruction is to keep the boundary between the two sides narrow — same section.

---

## 4. Where each row would live

| Row | Folder | Sim touched |
|---|---|---|
| A cooldown | `src/actor/` (a tick counter) | no — but the number belongs to gear |
| B burst | `src/actor/spell_circle.gd` + `world_step.enqueue` delay | no new sim code; **sim load rises** |
| C charge | `src/actor/` + `src/stage/` input + a `src/view/` tell | no, but widens the host/deterministic seam |
| D recoil | `src/actor/character.gd` — one constant | no |
| E circle structure | `src/sim/circle_defs.gd` table row | table only |
| F audio · flash · shake | `src/view/` | no |

`fire_cmd()` in `src/actor/aim.gd` stays the single door in every row. **No row above requires a new integer
primitive** — the delay ladder, the tick queue and the recoil constant are all already standing.

---

## TBD — everything below is undecided

- **What "펑 펑 펑" means to the user**: three shots from one press (B), an enforced beat (A), a felt push (D),
  or **just a sound** (F). The onomatopoeia is compatible with all four
- **Whether the triangle circle already is it.** Nobody has fired one and judged it. **This is the first
  question to ask, and it costs nothing**
- **Whether `seq_ticks = 6` (300ms) is the right beat.** Provisional by its own comment
- **Whether rate belongs to gear (staff) or to the base action.** The GDD says staff; nothing is built
- Whether a burst's answer to `MAX_BLASTS_PER_TICK` is a **glyph constraint** (the standing rule) or something
  new — and if something new, `docs/decisions/shot-explosion-by-rule.md` must be reopened, not quietly ignored
- **Who owns sound.** `game-feel.md` says it needs its own doc; that doc does not exist
