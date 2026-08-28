# 03-clear — See-through water

Picture: `../out/03-clear.png`

**Buys** — the shore is not painted at all: it is the submerged rock showing through shallow water, so it is right by construction and it moves correctly under any camera. Gives the pale shelf, the tint with depth and the soft edge from one mechanism instead of three dials.

**Costs** — a screen texture read on top of the depth read, and the sea must be transparent, which puts it after the opaque pass and out of the depth buffer.

**Cannot** — hide what is under it. ⚠ **Everything below the water has to be worth looking at**: the island's underside is a plain wall dropping 1.15 tiles and it is now on screen. It also cannot show another transparent thing through itself.
