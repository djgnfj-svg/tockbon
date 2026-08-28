# 02-depth — The depth buffer

Picture: `../out/02-depth.png`

**Buys** — the width comes out right for free, everywhere, with nothing baked. Look at the front of the block: the band is fat where the skirt spreads out shallow and thin where it drops. **Moving things get a shoreline too**, because the depth buffer sees whatever was drawn.

**Costs** — the sea has to be transparent so it does not write into the depth it reads, and the depth has to be linearised by hand. ⚠ In this renderer the clip-space z is -1..1 while the texture is 0..1, and getting that wrong produces a wrong picture with no error at all (measured, first run of this lab).

**Cannot** — see anything off the screen, or behind the camera, and the CPU cannot read it. **Nothing transparent is in the depth texture**, so a second water surface or a glass thing gets no shoreline.
