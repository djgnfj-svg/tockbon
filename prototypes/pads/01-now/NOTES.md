# 01-now — a baked mark per 칸, all at once, on a held key

**What it buys** — every 칸 a body may stand on is marked with **that piece's own baked shape**, so the
mark bends with the ground it lies on instead of hovering over it, and the hovered one physically
rises. One object, one draw call, nothing computed at runtime.

**What it costs** — **forty-eight marks are on at the same time** and the island wears a pattern rather
than a surface; on this sand they read **darker** than the ground rather than lighter, so the board
looks stained. It only exists while a key is held, so the resting board says nothing.

⚠ **What it CANNOT do** — **say anything about a particular body.** It is the same picture wherever
anyone is standing, and it **marks the plateau and the islet exactly like the ground**, both of which
no body on this board can reach.
