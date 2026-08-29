# 01-grow — the vertices walk from one shape to the other

**What it buys** — **one mesh, one draw call, and the board is never doubled.** At every distance you
are looking at exactly one board, and the thing between the two states is a real shape rather than two
pictures on top of each other. The merged 칸 is a true lump: rounded outside, no seam inside.

**What it costs** — **every ring point has to carry where it is going**, so both states are decided at
bake time. Changing what「merged」 looks like means re-baking the island, not turning a dial.

⚠ **What it CANNOT do** — **merge into anything the bake did not already draw.** The points can only
walk to the one place they were told; a second kind of merge (a whole coastline, say) is a second set
of deltas and there is only one spare channel.
