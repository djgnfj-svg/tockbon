# `bush` — the words each candidate was pulled with

**Nothing chosen yet.** Nine candidates, all pixellab `pixen`, **32x32**, `no_background`, `low detail`.

**32x32 is 0.8 조각** at `Look.TILE_PX` 40 — generated at the size it will be drawn, for the reason
written out in `../tree/prompts.md`.

| File | The words |
|---|---|
| `a01_round_seed5505` | a small round leafy bush, muted green mound, no flowers, flat solid colors, simple silhouette |
| `a02_scrub_seed6606` | a low scrubby shrub clump, three uneven leafy lumps, dusty sage green, flat solid colors |
| `b01_mound_seed5506` | a flat two-tone green shrub mound, no border line, no leaf detail, one solid silhouette |
| `b02_grass_seed5507` | a tuft of tall dry grass, pale yellow-green blades fanning out from the ground, sparse and simple |
| `b03_bramble_seed5508` | a dense dark green bramble bush, rounded and squat, a few pale berries, flat solid colors |
| `c01_hedge_seed5509` | a low wide hedge of three overlapping olive green domes, squat and simple, no flowers |
| `c02_gorse_seed5510` | a spiky gorse shrub, dark yellow-green needles bristling outward, wild and dry |
| `c03_fern_seed5511` | a clump of green ferns, broad fronds fanning up and out from a single base |
| `c04_thorn_seed5512` | a bare thorn bush, tangled grey-brown twigs and no leaves, sparse dry silhouette |

**`view`**: `low top-down` on `a01`, `a02`, `b03`, `c01`; `side` on the rest.
**`outline`**: `lineless` on `a01`, `a02`, `b01`, `b02`; `selective outline` on the rest.

## What the first two waves got wrong

- **`a02_scrub` reads as three grey STONES, not a bush.** 「dusty sage green」 came back nearly
  colourless, and beside the real 돌 it would be a second rock.
- **`a01_round` came back BLUE-green.** Against the island's grass — a sandy olive
  (0.76, 0.735, 0.52) — a blue-green mound is the only cold thing on the board.

⇒ The `c` wave names the plant rather than the colour, and four of the nine are now dry or bare
rather than lush, which is what the island's own palette asks for.

## ✅ **ALL NINE ARE STANDING IN THE GAME**

**Installed as `bush_a01` … `bush_c04` in `assets/props/flat/`** and placed in a row across the
island's south edge, two 조각 apart, **left to right in this table's order.** ⚠ **The swordsmen stand
in the middle of the row**, which is the comparison that matters: a 32 px bush against a 27 px man.

The code that carries a picture prop went in with the trees — see `../tree/prompts.md`.

## Still unsettled

**Which one.** Nothing chosen. ⚠ **All but the winner comes out of `assets/` when it is** — nine PNGs
and nine `.import` files.
