# 2026-08-31 night — the sixteen BLACK wolves, pulled on the local GPU

**Free.** Local ComfyUI (FLUX.2 klein), `monster` preset, 640 -> 64 px, ~8 s an image. ⚠ **This is a
different route from every wolf before it** — `g5` and the other 38 candidates in this folder came from
pixellab and their prompts were never written down, only their job ids.

## Why black was asked for

**The user saw the chosen grey wolf on screen and it was brown** (2026-08-31: 「the wolf needs re-pulling,
in black」). ⚠⚠ **The brown is not the art, it is `BEAST_TEAM_TINT`** — enemies are multiplied by
`COL_ENEMY` at 0.45, which is a per-channel gain of `(1.00, 0.739, 0.712)`. Measured on the actual values:

| fur as drawn | on screen after the tint |
|---|---|
| `g5`'s grey `(120, 118, 120)` | `(120, 87, 85)` — **a visible brown/purple shift** |
| a black `(20, 20, 22)` | `(20, 15, 16)` — **still black; the shift has nothing to work on** |

⇒ **Black is the one fur colour the team tint cannot turn brown.** The darker the fur, the smaller the
distortion, and this is arithmetic rather than taste.

## The four prompts

All four ride `--preset monster --batch 4 --down 64` with one shared negative:

```
front view, facing the camera, head on view, extra legs, six legs, duplicated limbs,
pink, red tongue, bright saturated colors, text, ground shadow, rocks, scenery
```

| Run | The prompt |
|---|---|
| `k1_pure` | a single pure black wolf standing in profile on the ground, solid black fur, only two shades of black, thick black outline, four legs visible, no other colour |
| `k2_muzzle` | a single black wolf standing in profile on the ground, deep black fur with dark charcoal shading, pale grey muzzle and paws, thick black outline, four legs visible |
| `k3_back` | a single wolf standing in profile on the ground, black back and head fading to dark grey belly, flat cel shading, thick black outline, four legs visible |
| `k4_ink` | a single black wolf standing in profile on the ground, inky black silhouette with a few lighter grey facets on the shoulder and haunch, no outline, four legs visible |

## ⚠⚠ What the sixteen measured

**Asked for black, the model returns a SILHOUETTE.** Fifteen of sixteen came back with the interior
collapsed to one flat black — the shading words (`two shades`, `charcoal`, `lighter grey facets`) were
swallowed. **Only `k2_muzzle` kept anything readable inside the outline**, and only because the pale
parts were named as separate body parts (muzzle, paws) rather than as shading.

⚠ **And at the size it ships this does not matter.** Stood in the real game at 0.85 (a 20.9 px animal on
pale sand), the flat blacks read as wolves **more clearly than the grey they replace** — the silhouette
carries it and there is no room for interior shading anyway. The evidence is
`docs/reference/2026-08-31-black-wolf-in-game/`.

⚠ **The body is not `g5`'s body.** These stand square and lean; `g5` crouches. Nothing here matches the
animal the user picked this morning — **the pose changed with the route**, and that is the cost of the
free pull.

## The chroma green

`monster` output carries a bright green ground and **cannot be moved into `assets/` as-is**. Every file
here has already been through `tools/pixel/cutbg.py`.
