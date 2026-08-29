# 04-glint — the water stays flat and only the sun's road moves

**Where it comes from:** the diffuse light is untouched, so the sea is the colour it ships with corner
to corner. The only addition is a **specular highlight narrow enough to appear on almost nothing** — the
few slopes that face the sun back at the camera — and a wide slow patch map decides which stretch of sea
is allowed any at all.

**What it buys** — ⚠⚠ **it is silent by default and loud in a few places**, which is what 「살짝」
actually looks like on water. Every other version changes every pixel a little; this changes almost none
of them a lot. It is also the only one that says *sun* rather than *shape*.

**What it costs** — one extra dot product and a power. No geometry.

**What it CANNOT do** — ⚠⚠ **it only exists where the sun's road happens to be.** Turn the board and the
glints swing to the other side of the island or leave the frame entirely, so it is a different picture
from every angle and there are angles where the sea is exactly as bare as it is today. ⚠ It is also the
one candidate that fights the shoreline for the same colour: both are near-white on blue.
