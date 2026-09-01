# `ore` — 철광석, and the colour lesson it dug up

**Nothing chosen yet — TWELVE shapes now** (2026-08-31, the user, after the first six: 「철광석은 좀더
뽑아보자」).

## ✅✅ **`o8b_band` WON** (2026-08-31, the user: 「철광석 2번」 — the second on the o8 variant sheet)

**It is installed.** `blend/props.blend`'s `ore` is the boulder with grey below and above and a band
of ore round its waist, and one of it stands on the island at 조각 (18, 11).

⚠⚠ **THE 철광석 KEEPS A CLEAR RING OF THREE 조각, AND THAT IS A RULE NOW.** The first planting put a
tree two 조각 in front of it: at a 40° pitch the ore drew directly on the tree's crown and read as a
grey lump growing out of the canopy. **It is the only ore on the island and it is a place a squad gets
sent to** — anything tall between it and the camera hides the one thing that has to be found.

⚠ **The colour was fixed in the same edit** — see the measurement below. The band renders as rust now
instead of clipping to peach, and the grey renders as grey instead of white.

---

## ⚠⚠ **`o8` WAS THE DIRECTION** (2026-08-31, the user: 「철광석 o8을 조금만 더 변경해줄래? 저부분이
## 마음에 들긴함」)

**o8 is the one where the ORE is the mass and the grey is only a crust** — the inverse of every other
shape, and the same squat silhouette as the chosen 돌 `r2`. **Six variations on it** are in
`2026-08-31-variants-c-o8.blend`, sheet `2026-08-31-sheet-o8-variants.png`, with the original at the end.

| | What the crust does |
|---|---|
| `o8a_slab` | one grey slab laid across the crown |
| `o8b_band` | grey below and above, a band of ore round the waist |
| `o8c_split` | grey plates stood round the base |
| `o8d_shards` | grey shards driven OUT of the ore, the crust broken rather than laid on |
| `o8e_bare` | **no crust at all**, and the top cut into two planes |
| `o8f_pair` | a small grey boulder beside it, the way `r2` pairs a mass with a shoulder |
| `o8_ORIGINAL` | three grey lumps on the crest — what was picked |

| Sheet | What is on it |
|---|---|
| `2026-08-31-sheet-o8-variants.png` | ⭐ **the six above plus the original.** This is the sheet to look at |
| `2026-08-31-sheet-all-twelve.png` | all twelve shapes, in ONE palette, with the chosen 돌 `r2` at the end |
| `2026-08-31-sheet.png` | the first six only, in the shipped (bright) tones |
| `2026-08-31-in-game.png` | two colourings of `o1` standing on the real island |

**Geometry**: the first six in `2026-08-31-variants.blend`, the second six in
`2026-08-31-variants-b.blend` — which also carries dim copies of the first six, which is what makes
the twelve-up sheet a fair comparison.

## The second six

| | What it is | Why it is in the set |
|---|---|---|
| `o7_vein` | two grey halves with a rust plate standing between them | the ore is a SEAM, continuous |
| `o8_rusted` | the ore is the mass and grey is the crust | **the inverse of every other shape** |
| `o9_cluster` | rust spikes straight out of the ground, no host rock | |
| `o10_plates` | grey and rust plates layered | the seam read edge-on |
| `o11_capped` | **the chosen 돌 `r2`'s own shape** with rust crystals on top | **the family match** |
| `o12_pit` | a ring of spoil stones with ore in the middle | the only one that reads as WORKED |

**There was no iron ore before today.** `blend/props.blend` held pine · tree · rock · stone · bush and
nothing else, and `GLOSSARY.md` says **one ore is embedded on the island** — so this is one prop, not a
scatter.

## The first six

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
