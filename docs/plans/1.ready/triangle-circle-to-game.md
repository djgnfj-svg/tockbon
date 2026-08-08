# Wire the triangle circle into the game — the art exists and the code doesn't know

**Status**: ready
**One line**: the triangle circle's assets (skeleton · two socket glyph rings) exist, and **the code doesn't know
the triangle circle exists.** Stand up one more circle in `circle_defs` and draw three rune slots with a band per socket.

**Preceding doc**: [../3.done/triangle-circle-art.md](../3.done/triangle-circle-art.md) — generating the assets.
That doc's "Boundary" cut it off in advance with **"art coming out is where this work ends. Wiring it into the game
is a separate doc"**, and **this is that separate doc.**

**Source docs**: `docs/design/circle-art.md` (spec · art) · `docs/design/circle-rune-glyph.md` (the three circles' rules)

---

## Why

**The assets exist and not one pixel appears in the game.** This repo's signature fake is
"screen changes, sim doesn't (or the reverse)" — this is the stage before that: **neither changes.**

And **left long enough the assets go stale.** The spec was measured to 288 · 192 · 368, but until it's attached
**nobody knows whether those values are right on screen** (they were measured only on the asset originals).

---

## What blocks it — measured

| Where | Now | What the triangle circle needs |
|---|---|---|
| `src/sim/circle_defs.gd` | **Only `CIRCLE_ROUND`.** `ALL = [CIRCLE_ROUND]` | Stand up one more circle (`rune_slots` 3) |
| `rune_slots()` in `src/view/circle_layout.gd` | **Barks and returns an empty array when `n != 1`** | Place three at 12, 4 and 8 o'clock |
| Layer axis in the same file | Assumes **layer = concentric ring** | **One band per socket** — not concentric |

**The third is the biggest.** For round circles, "layers grow from the inside out" is in the picture itself
(`circle_layout` comment), but **the triangle scatters layers across three sockets.** ⇒ "Execute from the inside"
can't be expressed as a picture, and **clockwise order takes that job instead.**

The bark in `circle_layout.gd` was **planted deliberately** ("add a circle without deciding how runes lay out and
the wrapper's stderr check catches it for free"). ⇒ **Removing that bark is not this work's first line.**
Remove it after deciding the layout.

---

## To decide — **before any code**

**Carried straight over from the preceding doc. Unresolved, it can't be written.**

### ① The unit of spread's "only one per magic circle"

The triangle has **separate glyph slots per rune**, so what "one magic circle" means wobbles.

| If you pick | Result |
|---|---|
| One per slot | Three spreads ⇒ **24 bolts.** Hits the current cap of 32 |
| One per circle | **The picture lies** — three identical-looking sockets and only one gets spread |

### ② The triangle's sequence interval

**How many ticks apart** the three shots leave. Zero is effectively parallel; long reads as "broken".
**This value directly sets the size of ①'s explosion** — scattered impacts mean 24 bolts never coexist.

### ③ How the clockwise order gets taught

**The picture deliberately doesn't show order** (user decision). Two safeguards remain, the **12 o'clock socket**
and **onboarding**, and whether it goes into onboarding is undecided.

**The preceding doc's acceptance check 2 half-failed here** — beyond a socket at 12 o'clock there is no clue,
and **the three sockets look identical.** ⇒ "12 o'clock is #1" exists **as a rule, not as a picture.**
The GDD's "if order isn't visible on screen the player never learns the rule" is exactly this place.

---

## Look at again alongside — the 48 socket band

**An unresolved item the preceding doc handed over provisionally.** The box under "glyphs must be intuitive and
geometric" in `docs/design/circle-art.md` is the source.

```
thicker band  →  meaning reads          →  inner hole 72–75, intrudes on the rune's 96
thinner band  →  inner hole meets spec  →  the pattern becomes tick marks and the meaning is gone
```

The current asset is on the **intruding** side. **Verified only on the fire rune (line art)** — attached to the game,
**overlap with other runes becomes visible for the first time.** That is when to judge again.

**Game size 144 was measured in the preceding doc** — the two separate **even at 144.**
But **the hatching inside spread's wedges becomes a grey smudge** — the meaning survives, the texture dies.
**That rule comes first when generating the next 15 glyphs**: bold forms carry the meaning, and
**hatching, thin parallel lines and fine dots cannot travel.**

---

## Boundary

**Not doing**:
- Art for the basic and fusion circles — left in `docs/design/circle-art.md`, "Unresolved"
- 288 boards for the remaining 15 glyphs
- How circles are obtained (drops · shop) — no doc in the GDD

---

## Acceptance — what must be seen to call it done

1. **Is the triangle circle selectable and drawn in the assembly window** — three sockets · starting at 12 o'clock
2. **Do three runes each go into a socket**
3. **Does a glyph attach only to that rune's socket band** — attaching at the center means "one layer per rune" broke
4. **Do three shots go out when firing** — at the interval from ② above
5. **Do the two glyphs separate on the real screen** — at the asset stage this was checked by shrinking to 144.
   What is newly measured here is whether they separate **after circle, rune and glyph overlap**

---

## TBD — not its turn yet

**Do not force these full** (GDD "skeleton first").

- What the center ornament means — its size is set (radius 112). **It is not a glyph**
- Coordinates live in two places — `tools/pixel/draw_circle.py` (assets) and `src/view/circle_layout.gd` (game).
  Diverge and you get "the asset is right but the game is off", **with no error**
