# `ore` — 철광석, and the colour lesson it dug up

**Nothing chosen yet.** Six shapes in `2026-08-31-variants.blend`, photographed in
`2026-08-31-sheet.png`, and **two colourings of the winner-so-far standing in the real game** in
`2026-08-31-in-game.png`.

**There was no iron ore before today.** `blend/props.blend` held pine · tree · rock · stone · bush and
nothing else, and `CONTEXT.md` says **one ore is embedded on the island** — so this is one prop, not a
scatter.

## The six shapes

| | What it is | Why it is in the set |
|---|---|---|
| `o1_crag` | one mass, a tilted top, ore on one flank and standing on the crest | **the tallest silhouette** — reads from across the board |
| `o2_seam` | a boulder split in two, ore standing in the cleft | the ore is the thing between, not the thing on top |
| `o3_band` | a low outcrop with a band of ore across its top | **the only one that reads from directly above** |
| `o4_spire` | a spire with ore clustered at its foot | ore where a pick would actually reach |
| `o5_heap` | no host rock at all, a heap of loose ore | **the one a cart is filled from** |
| `o6_geode` | a cracked shell, ore filling the mouth | ore visible from one side only |

⚠ **Each is cut from the same library as the existing `rock`** — flat shaded, 20–45 vertices, the same
winding, `p_rock`/`p_rock_d` for stone. **No shape here uses a technique the island does not already use.**

⚠⚠ **A single apex reads as a PYRAMID, not a rock.** The first cut of `o1` was a seven-sided cone and
looked like a tent; every shape here is closed by a flat, tilted top instead. ⚠ **And a crystal has to
be wide before it is long** — the first side spurs were 2.6x as long as they were wide and read as flat
fins the moment the camera turned. They are 1.8x now.

## ⚠⚠ **THE MEASUREMENT: a prop's colour is set in Blender and JUDGED IN THE GAME, and the two are three stops apart**

**No prop has ever been placed on this island.** `island.json`'s `props` array was `[]`, so the five
meshes in `props.blend` had **never once been drawn by the game** — their colours were picked in
Blender's viewport and never checked.

**What the game actually does to them**, read off `tools/shot/out/field/field_7_close.png`:

| glTF base colour (linear) | On screen |
|---|---|
| `p_rock` **0.290, 0.287, 0.265** — a warm mid grey | **(237, 245, 252)** — near WHITE, and COLDER than the albedo |
| `p_ore` **0.335, 0.171, 0.098** — rust | **(255, 206, 170)** — the red channel CLIPS and it reads pale peach |
| the dimmed twin **0.098, 0.097, 0.090** | **(143, 147, 152)** — an actual mid grey |

⇒ **This world's sun plus fill plus ambient multiplies a linear albedo by about 2.9, and the ambient
is BLUE**, so a warm tone lands cold and anything above roughly **0.31 in one channel clips to that
channel's maximum**. ⚠ `field_view.gd` already carried half of this finding — a tombstone there records
`COL_BOAT`'s 0.85 tan rendering *"as a solid white rectangle"* — but it was written about a mark on the
water and nobody carried it to the meshes.

⚠⚠ **This is not only the ore.** `b_wall` is **0.683** and the house's walls are pure white on screen;
`b_stone` is **0.319** and the keep's footing is white. **The whole prop-and-building palette was set
against Blender's light**, and it is one decision, not six.

## What is standing in the working tree right now

**Both colourings are in `props.blend` and both are placed on the island**, at 조각 (18,11) and (16,11),
so they can be compared on the screen that decides. **`ore` is the bright one, `ore_dim` is the other.**
⚠ **One of the two comes out** once the choice is made — they are a comparison, not two props.
