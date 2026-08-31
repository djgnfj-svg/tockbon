# `tree` — the words each candidate was pulled with

**Nothing chosen yet.** Eight candidates, all pixellab `pixen`, all `no_background`, `low detail`.

⚠⚠ **The tree is going 2D** (2026-08-31, the user: *"the tree is 2D, the bush is 2D too, and the stone,
the iron ore and the buildings are 3D"*). A pine, a tree and a bush already stand as MESHES in
`blend/props.blend`; whichever of these wins replaces two of those three.

## Size — **64x64, and that is not arbitrary**

**Generated at the size the game will draw it.** The wolf round measured what happens otherwise: a
64 px picture drawn at 20.9 px keeps **one texture pixel in 9.4** and drops the rest, which is why
a leg or an ear disappears and reappears as the animal walks. At `Look.TILE_PX` 40, a 64 px tree is
**1.6 조각 tall** — half again the 27 px swordsman, which is the height a tree should read at.

⚠ **The bush is pulled at 32x32** for the same reason: 0.8 조각.

| File | The words |
|---|---|
| `a01_broadleaf_seed1101` | a single small deciduous tree, rounded leafy canopy, short thick brown trunk, flat muted olive green, simple solid shapes, no texture detail |
| `a02_pine_seed2202` | a single conifer pine tree, dark muted green triangular tiered canopy, short brown trunk, flat solid colors, no texture detail |
| `a03_blob_seed3303` | a single broadleaf tree with a wide soft blob canopy in two tones of muted green, thin dark trunk, storybook shape, flat solid colors |
| `a04_cypress_seed4404` | a tall slender cypress tree, narrow dark green column, tiny trunk, minimal flat shapes |
| `b01_slabs_seed1102` | a single tree made of three flat slabs of solid green, no leaf texture, no dark border, thick pale trunk, poster-simple |
| `b02_olive_seed1103` | a windswept olive tree with a dry sage green canopy and a pale bent trunk, muted desaturated colors, simple shapes |
| `b03_dead_seed1104` | a bare dead tree, twisted grey trunk and thin branches, no leaves, stark simple silhouette |
| `b04_twopine_seed1105` | two conifer pines standing together, one tall one short, dark green tiers, tiny trunks, flat colors |

**`view`**: `low top-down` on the `a` set and on `b02`/`b04`; `side` on `b01`/`b03`.
**`outline`**: `lineless` on `a01`–`a04`, `b01`, `b03`; `selective outline` on `b02`, `b04`.

## ⚠ **`lineless` did not take, and it matters**

**Every one of the eight came back wearing a dark border** — the parameter is documented as weakly
guiding and it behaved that way. **The game adds its own outline at 1.04** (개발지식 01 기법 17,
measured as exactly one screen pixel at 27 px and at 20.9 px), so **a picture that already carries a
black rim is double-outlined once it is installed**. ⚠ The wolf round measured what a rim that is too
heavy does at this size: **1.10 ate a 21 px animal whole.**

⇒ **Whichever of these wins, its border comes off before it is installed**, or the outline pass is
turned off for props — **and that is a decision, because the outline is what lifts a flat picture off
the ground.**

## Not settled

- **Which one.** Nothing chosen.
- **Whether a tree is one picture or four.** The four-view rule in `../README.md` is for BODIES; a tree
  does not turn. **One picture, billboarded, is the assumption here and it has not been agreed.**
- **How `_rebuild_props` puts a 2D prop on the board.** It instances a `MeshInstance3D` out of
  `props.glb` today and knows nothing about a picture. **That is a code round, not a drawing round.**
