# 01-now — Distance to the outline (what the game ships)

Picture: `../out/01-now.png`

**Buys** — total control and total predictability. The band sits exactly N tiles from the coastline, it never swims when the camera turns, it costs one texture read, and it works in any renderer. It is also the only one of the five the CPU could read.

**Costs** — a CPU bake per island, and a texel budget: the field is 16 texels per tile in the game and a line thinner than one texel comes out dashed.

**Cannot** — ⚠⚠ **vary its width with the ground.** A distance field does not know how deep the water is, so the band is the same width on a gentle shelf and against a vertical cliff. **This is the whole reason the shipped shoreline reads as a traced outline**, and no setting of it reaches the reference pictures. It also cannot react to anything that moves: a boat, a body wading, a block the player places.
