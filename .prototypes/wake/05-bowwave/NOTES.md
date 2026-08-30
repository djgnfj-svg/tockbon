# 05-bowwave — a static V parented to the boat, and no trail at all

**What it buys** — **it costs almost nothing.** One mesh, built once, moved with the hull. Nothing to
rebuild, nothing to upload, no history to keep, and twenty boats cost exactly twenty times one boat. It
is also the only candidate whose shape can be authored in Blender against the hull it belongs to.

**What it costs** — one draw call per boat, and a mesh somebody has to make.

**What it CANNOT do** — **leave anything behind.** Water the boat has crossed is water again, so the
screen never says where a boat came from, and **the moment a boat stops — waiting off the coast, or
standing off after a landing — there is nothing on the water at all.** ⚠ This is the honest "do less"
row: Sea of Thieves ships with no persistent wake either, only foam where the hull meets water.
