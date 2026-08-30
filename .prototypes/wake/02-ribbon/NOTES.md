# 02-ribbon — a strip of triangles extended behind the boat

**What it buys** — one continuous ribbon with a real head and a real tail, textured with foam along its
own length, at a few hundred triangles and no buffer at all. **The cheapest thing on this sheet for the
GPU**, and the only one whose froth can be authored as a picture rather than as noise.

**What it costs** — the mesh is rebuilt from the history every frame, on the CPU, and each boat is its
own history and its own draw call.

**What it CANNOT do** — **survive a turn tighter than its own half-width.** The two sides are laid out
on each sample's own heading, so once the turn radius drops below the strip's half-width the inner edge
crosses itself and the triangles fold inside out. The strip reaches 2.5 조각 half-width at its tail
against a 2.55 조각 turn radius in the turn frame — it is standing on that edge in this picture. **It
also cannot be anything but one strip**: no arms, no crests, no shape that is not a widening band.
