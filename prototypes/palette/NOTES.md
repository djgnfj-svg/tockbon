# palette — seven whole palettes for one island, photographed from one camera

**The question, in one sentence.** *The island's colours were each decided in a different round — the
water yesterday, the cliff today, the ground before either — and have never once been laid out
together. What does the island look like when all thirteen are chosen as one set?*

⚠ **This is a candidate sheet, not a spike set.** The `spike` skill's own test is that each version
gets its result from a **different mechanism**; these differ by constants. The mechanism for getting
them on screen is shared, and it is the interesting part of this folder — see below.

## Where it came from

**2026-08-29, the user**: 「전체적인 그 색을 맞추고 깔아라 맞춰야 되는데 왜 이렇게 뭔가 베드노스에 비해
이렇게 맛이 없을까?」 and 「팔레트 꼭 뽑아야겠어」.

## The seven

| # | Principle | What it buys | What it costs | ⚠ What it CANNOT do |
|---|---|---|---|---|
| **00** | today, as the control | nothing — it is the baseline every other one is read against | — | — |
| **01** | **fog** — sky and sea the same pale grey, saturation pulled out | Bad North's actual answer: a quiet screen, so anything saturated placed later is the only thing the eye finds | land and sea part on value alone, so the white 해안선 nearly disappears | carry more than one saturated thing. The moment two colours are loud on it, its whole argument is gone |
| **02** | **one green** — everything neutral but the ground | walkable ground is the only saturated surface, so *where a body can stand* is readable as colour | the sea is neutral and stops reading as water — it reads as floor | separate the two storeys: both are the same green, so height carries no hue |
| **03** | **warm / cold** — land warm, sea cold, values kept close | land and sea separate by temperature, leaving value free for something else (height, or a body) | closest to what is on screen now, and the saturation stays high | fix the complaint that started this. The yellow ground is still yellow |
| **04** | **value ladder** — one hue, brightness does all the work | height reads by itself: rock brightest, sea darkest, so the plateau lifts without an outline | one hue over the whole screen is monotonous | tell two buildings apart later; there is no hue left to give them |
| **05** | **deep sea** — dark water, bright island, contrast at maximum | the island is unmistakably the subject, and its silhouette survives at small sizes | the white shore line becomes the loudest thing on screen — the current complaint gets worse | show boats. A dark hull on dark water is invisible, and boats are next week's ticket |
| **06** | **paper** — bright ground, form from value and ink | anything placed on it stands out immediately | the island itself nearly vanishes; land and sea are both bright | use cast shadow for height. A pale shadow on a pale ground does not read |

## How they were put on screen, and what it cost to get right

**Nothing here re-baked Blender.** The island carries its tone in **vertex colours**; the buildings
wear **one flat material per part**. Both are swapped at runtime — a shader for the first, an albedo
write for the second — so seven palettes cost one run instead of seven bakes.

⚠⚠ **THE CONTROL SHOT IS THE WHOLE REASON THIS IS TRUSTWORTHY, AND IT CAUGHT FOUR BUGS.** `00-raw`
bypasses the swap; `00-now` runs the swap with **keys == values**. They must come back identical, and
four times they did not:

1. **`source_color` on the palette uniforms.** Blender writes vertex colours linear and glTF keeps them
   linear, so `COLOR` arrives linear — `source_color` put the uniforms through an sRGB→linear
   conversion the vertex colours never had. Every base sat darker than the tone it addressed and the
   roof came out white.
2. **Buildings fed through the vertex-colour path.** They have no colour layer at all, so `COLOR` was
   (1,1,1,1) and they painted white. `CONTEXT.md` already said the two are painted differently.
3. **The second sweep did not recognise its own material.** Re-collecting each palette (the view
   remakes some meshes as the run ticks) read the recolour shader as "some ShaderMaterial the game
   owns" and walked past it — so every palette after the first painted nothing.
4. **Nearest-match has no working setting.** Narrow: ground lying *between* two bases fell outside all
   of them, every weight underflowed, and the original colour went straight through — cliffs recoloured
   and the ground did not. Wide: the bases bled into each other and the control was visibly wrong
   across a third of the frame. A full barycentric solve is exact but the four baked tones are nearly
   coplanar (determinant 0.003), so every candidate came back a white island.

⇒ **What works is a SHIFT**: weigh the four bases by hue distance, take that blend of the old bases and
of the new, add the difference, scaled by the pixel's own brightness. **With keys == values the shift
is zero**, so the control is exact by construction rather than by tuning. Residual: **max 54/255 on
about 0.17% of the frame**, all of it on the cliff face.

⚠ **`00-raw` is the honest picture of today.** `00-now` exists only to prove the instrument.
