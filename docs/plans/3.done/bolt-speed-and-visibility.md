# Bolt speed — give the art time to be seen

**Status**: implemented · **screen unverified**. Code landed at **gen0 12 · gen1 6**; nobody has looked at it.
Every item under "Acceptance" below is still open, because all of it is the screen.
**One line**: bolts skip 26.6px per frame. A 16px sprite was drawn and **there is no chance to see it.**
Lower the speed so the art shows — but how far is **decided on screen.**

**Preceding doc**: [../3.done/bolt-head-sprite.md](../3.done/bolt-head-sprite.md) — replacing the head with art.
That doc **deferred "bolt speed" to "later, while looking at the screen"** (user decision), and this is that.

**This doc alone requires the screen.** Everything else the preceding doc left was measured headless.

---

## Why — the argument changed

**For a while the argument was "range goes off screen". Measurement overturned it.**

```
                 horizontal      45° upward
 gen0(speed 20)   53 cells 6.6 tiles    193 cells 24.1 tiles
 gen1(speed 12)   32 cells 4.0 tiles    102 cells 12.8 tiles
                                        ↑ within the 30-tile screen width
```

**`sim_tuning`'s 320 cells (40 tiles) was a "if there were no gravity" value.** A ground-level shot **hits dirt in 4 ticks**
and never reaches it. ⇒ **"Blasts go off screen" (GDD "prices paid knowingly" #5) does not happen on flat ground.**
**Firing from a cliff makes it worse** — by the fall time. The values above are flat-ground and **cliffs were not measured.**

**⇒ The one real argument left is visibility:**

```
movement per frame = speed × 4px × 20Hz ÷ 60fps = speed × 1.33px
speed 20  →  26.6px/frame      the art is 16px    ⇒ it skips without overlapping
speed 12  →  16.0px/frame      same as the art     ⇒ exactly continuous
```

**The value of drawing the art leaks out here.** Carefully generate a 16px sprite and then move it
**farther than its own body length in one frame**, and what the player sees is the trail, not the art.

---

## There is a floor — speed 12

From the preceding doc's measurement:

> **Drop `speed` below 12 and "the tail is drawn in code" is overturned** —
> the painted tail starts being visible on screen, so putting the tail in the art becomes a candidate again.

The originals with tails (32×16) are in `tools/pixel/out/` but **gitignored, so they disappear** —
regenerate from the seed table in `docs/design/circle-rune-glyph.md`.

**And generation 1 is already 12.** Make generation 0 twelve and `net_tables`' "it must decrease every generation"
**goes red** — lowering gen 0 means **lowering gen 1 with it.**

```
now         gen0 20 · gen1 12      ratio 5:3
candidate   gen0 14 · gen1 8       ratio 7:4, 18.6px · 10.6px per frame
candidate   gen0 12 · gen1 8       ratio 3:2, 16.0px · 10.6px per frame  ← exactly at the floor
```

**Don't touch `rd` · `ignite_r` · `rune_r` · `carve_r`** — a different axis from range, and
`net_tables` already measures inequalities like `carve_r < rune_r`.

---

## What moves with it — unseen, it goes silently wrong

| What | How |
|---|---|
| **Horizontal range** | **Linear in speed** (measured 0.604 vs 0.600). At speed 14 it is 0.7× current |
| **45° range** | **Non-linear** (0.528). Initial vy drops too, shortening airtime ⇒ **it gives more** |
| **Trail length** | `trail_ticks` 12 ticks × speed. speed 20's 960px becomes 576px at 12 |
| **Gravity** | **Doesn't need lowering.** Drag-dominated, so range is proportional to v, not v² |

**The last row differs from the preceding doc.** That doc wrote "range falls as a square (v²/g)" and warned
**"not lowering gravity with it goes silently wrong"** — but that is **the formula for a drag-free parabola.**
**The shape of the trajectory does bend**, though — it covers less in the same time while gravity is unchanged, so it droops sooner.
**A feel problem, not a range problem**, which is why the screen is needed.

---

## What landed — **gen1 went to 6, not the 8 in the table above**

**The candidate row `gen0 12 · gen1 8` was implemented and verification rejected the second half.**
The rule this doc argued for is "movement per frame ≤ that generation's own head sprite width", and at speed 8
gen1 still **crossed 1.33× its own body length** each frame. The sprites are not the same size per generation,
so one ratio does not cover both. **⇒ gen0 20→12, gen1 12→6.** Both generations now sit at ratio 1.00.

**The check that makes this measurable**: `_bolt_head_keeps_up` in `tests/nets/net_tables.gd`, which walks the
inequality **per generation**. Before it existed, reverting the speeds to 20/12 left **all 5242 checks green** —
the whole of this doc rested on nothing.

Three nets had to be re-laid out because bolts now travel a shorter distance in the same time
(`net_damage` · `net_monster` · `net_water`). `net_monster` went to a **diagonal-corner placement** — an x-axis
crossing is now impossible in principle, and diagonal margin does not depend on box size, so growing the
monsters later will not break it again. Dead code (`_hits_to_kill` in those three nets) was deleted, and five
stale copies of the old numbers were corrected: `fx_tuning` (two), `monster_bolts.gd`, `stage.gd`, `GDD.md`.

## Acceptance — **still open, none of it has been seen**

**All of it is the screen. Nothing measurable headless remains in this doc.**

1. **Is the bolt head's art visible in flight** — currently only the trail may be
2. **Is it sluggish** — **directly at odds with #1.** Balancing those two is the whole of this work
3. **Does the trajectory read as "an arc"** — it bends more. Reading as "no power" is a failure
4. **Is the range frustrating** — at 45°, 24.1 → 12.8 tiles (at speed 12). Less than half the screen width.
   **And gen1 is at 6, half of what this line was written against** — the spread's 45° reach measured **4.8 tiles**
   after the change. Whether that is a spell or a puff of air is the question nobody has answered
5. **Is the shortened trail awkward**

**#1 and #4 pull opposite ways, so one value may not satisfy both.**
Then there is the path of **lengthening `trail_ticks` to compensate with the trail** — a different knob from speed.

### While the screen is up, look at this too — only the none bolt's head and trail disagree in color

```
        head art (mean)          glow drawn in code
 fire   (0.98, 0.69, 0.08)      (1.00, 0.48, 0.12)   agrees
 none   (0.59, 0.60, 0.60) grey (0.55, 0.35, 1.00) **purple**   disagrees
 water  (0.08, 0.67, 0.99)      (0.20, 0.62, 0.95)   agrees
```

It appeared in the change that made the trail use `glow` instead of `core` (preceding doc, "Result (3)").
**Nobody has looked at how "a purple tail with a grey head" reads.**
**It shows on the same screen as speed** — no reason to launch separately.

And **none's saturation is 0.03**, so the problem of sharing a color axis with "can't fire" grey
(`circle-rune-glyph.md`, "a contract broken knowingly") also becomes visible for the first time on that same screen.

---

## Why the screen still hasn't been launched — twice tried, twice stopped

**Tried twice, stopped twice. Both times because the user was using the computer.**

1. "I'm using it for something else right now, so you'll have to go headless" ⇒ only what headless allows was measured
2. Trying to grab the bridge, **yesterday's session's `godot-mcp` was found holding it.**
   Killing it with the user's permission **cut this session's MCP server too and the `godot_*` tools vanished.**
   Meanwhile the user said "the other thing needs it" ⇒ **stopped without launching the game window.**

**"Stopped, couldn't do it" beats "did it by taking the user's input"** (CLAUDE.md). So it stopped,
**and what wasn't seen is recorded here as not seen.**

**The bridge may not be needed next time** — the game can call
`get_viewport().get_texture().get_image().save_png()` itself. **The window still appears** (it steals focus).

---

## TBD

- **Range when firing from a cliff** — not measured. Only flat ground was, and stage 1 has elevation
- **Generation 2 and up** — the table has two rows (`SPLIT_MAX = 1`, so it can't happen yet)
