# 01-bake — the boat paints into a texture the water shader samples

**What it buys** — the mark is in WORLD space, so it stays exactly where it was put and every case comes
out right with no special handling: a turn, a stop, a reverse, two boats crossing each other's trail.
**And it is an extension of machinery this repo already runs** — `FieldView` bakes the coastline into an
`ImageTexture` and this same water shader already samples it every frame.

**What it costs** — a float buffer for every patch of sea it covers, re-uploaded whole on any frame the
boat moved, plus a CPU brush that walks every texel the stern passes over. Here that is 384 x 384
texels, 1.2 MB, and about 1700 texel writes per step.

**What it CANNOT do** — **cover the sea.** The game's water plane is 400 조각 across; at this
resolution that is 82 MB, so the choice is a bounded square with a hard invisible edge, or a buffer that
follows the camera and loses the trail at the frame edge, or fewer texels per 조각. **And it can never be
finer than one texel** — the staircase on the turn frame is the mechanism's own floor, not a bug.
