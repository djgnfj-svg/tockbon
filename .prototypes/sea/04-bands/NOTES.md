# 04-bands — how far the land is, cut into hard steps

**Where the open water comes from:** the baked distance-to-coast, wobbled by a slow noise so the steps
are not rings, then **posterised** into four tones between a shoal colour and a deep one.
**Shipped precedent:** Alexander Ameye's stylised-water breakdown builds exactly this — a world-space
depth fade, then `Posterize` — and names A Short Hike as the shipped example; A Short Hike's author
confirms his water reads the shore off the depth buffer.

**What it buys** — **it is the only candidate that tells you anything about the island.** The steps say
where the water is shallow, they make the small outlying block read as sitting on a shelf rather than
floating, and they give the coast a silhouette wider than the white line.

**What it costs** — one extra noise sample. It reads the field that is already baked, so nothing new is
built. ⚠ It spends the sea's colour range on the four tiles nearest the rock.

**What it CANNOT do** — ⚠⚠ **it has nothing at all to say about the far sea, and that is the question
that was asked.** The baked field reaches four tiles and then saturates, so every pixel past that falls
in the last band and **the open water is one flat colour again** — the right-hand column of the sheet is
identical to the one it was supposed to replace. Widening the field is not a dial: the bake is scattered
per coast segment, and a span wide enough to reach open water is hundreds of times the work.
⚠ It is also 여울 under a new name, and 여울 was switched on once and taken straight back out for wearing
the island as a halo.
