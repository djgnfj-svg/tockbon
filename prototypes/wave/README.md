# wave — the sea with light on it

## The question

> **The shipped sea takes no light at all. If the sun is allowed to touch the water, what does the
> water do?**

⚠⚠ **This is the second sea lab and it asks a different question from the first.** `prototypes/sea/`
next door asked what the open water is MADE of and painted five patterns into its colour; every one was
turned down. **Every one of those five was painted in ALBEDO, because the sea shader is `unshaded` and
light was never part of the answer.** Here light is the whole answer.

**Measured before any of this was built:** every pixel of open water on the screen is the same value
corner to corner, and the island casts a shadow that has no surface to land on.

## ⚠⚠ The shadow is the floor of the sheet, not a candidate

The user asked for it outright — 「근데 조명이나 그림자도 안생기나?」 — so it is spliced into **every**
version by `build.py` rather than written five times. **`01-shadow` is the shadow and nothing else**, so
the sheet answers 「그림자만으로 충분한가」 before it answers anything else.

## ⚠⚠ Three cameras, and the middle one is a correction

> 「니가 만드는게 너무 자글자글함 이게 멀리서 봤을때도 고려해야해서」 (2026-08-29)
> — *"what you are making is too fine-grained; it has to hold up seen from a distance too."*

⇒ **A pattern judged only at the opening zoom is judged at its best size.** Every version is shot from
**the opening view · zoomed back to 40 tiles · open water with no land at all**, and the sheet puts the
three side by side.

## How to run it

```
Godot_v4.7.1-stable_win64.exe --path . -s prototypes/wave/island_lab.gd
Godot_v4.7.1-stable_win64.exe --path . -s prototypes/wave/island_lab.gd -- shoot
Godot_v4.7.1-stable_win64.exe --path . -s prototypes/wave/island_lab.gd -- shoot wide
Godot_v4.7.1-stable_win64.exe --path . -s prototypes/wave/island_lab.gd -- shoot far
python prototypes/wave/sheet.py
```

**0 is the sea as it ships · 1.. are the candidates · LEFT/RIGHT step · TAB island/open sea ·
Q/E turn · W/S zoom · R/F tilt · ESC quit.** ⚠ **Never `--headless`** — every PNG comes out black.

## How the sun is allowed to touch the water

| | Where the light comes from |
|---|---|
| `01-shadow` | **the island blocking the sun**, and nothing else at all |
| `02-ripple` | **a bent normal, smooth** — two long crossed sines and plain lambert |
| `03-steps` | **the same normal, quantised** — the lambert term cut into three hard levels (cel) |
| `04-glint` | **a narrow specular only** — the diffuse stays exactly the flat sea |
| `05-swell` | **real displaced geometry** — the mesh moves and only the light shows it |

**Each folder carries a `NOTES.md` with three lines: what it buys, what it costs, and what it CANNOT
do.** ⚠ The third is the one that decides.

## How each one is built

**`build.py` splices, it does not copy.** A folder holds only `mech.gdshader` — its own uniforms and
three hooks (`open_sea`, `sea_normal`, `light`) — and the script wraps the shipped shader round it with
`unshaded` swapped for `ambient_light_disabled`. **The shoreline is byte-identical in every candidate by
construction**, and the normal bend is faded to nothing near the rock so the white line is lit the same
way in all six pictures.

## ⚠ Two engine facts this lab paid for

- **Godot multiplies `ALBEDO` into `DIFFUSE_LIGHT`.** Writing `DIFFUSE_LIGHT += ALBEDO * ...` squares
  the colour; all five came out two shades dark before this was found
- **`VIEW_MATRIX` cannot be read from a global function** — "Unknown identifier". It has to be passed
  in, which is why `sea_normal` takes a `mat4`
