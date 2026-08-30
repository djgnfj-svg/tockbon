# 17-drainthin — The drain takes width away instead of adding it

Pictures: `../out/island/17-drainthin_*.png`

**One difference from 16**: while the water pulls back off the rock the line is drawn NARROWER than
its resting width, not wider.

**Buys** — an unambiguous answer to 「미리 흔적이 너무 남아있는」. There is no frame in which a passed
wave is still wide.

**Costs** — one mix.

**Cannot** — ⚠⚠ **have the wide, faint film a real drain leaves.** Wide-and-faint needs the alpha to
carry the fade, and at this line thickness there is not enough alpha range left for the eye to see it.
**The two readings cannot both be had with one width** — this file spends that choice on thinness.

⚠ Judge it against 16 only on the frames just after a wave has passed. Everywhere else they are the
same shader.
