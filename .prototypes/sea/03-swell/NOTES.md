# 03-swell — the mesh actually moves, and the colour is read off the height

**Where the open water comes from:** two crossed sine waves really displace the sea's vertices, and the
same height function is read again in the fragment to pick between a deep tone and a lighter one through
a **narrow window near the crest**. The displacement is faded to nothing within about three tiles of the
rock so the shoreline cannot move.
**Shipped precedent:** Sea of Thieves blends its deep and sub-surface colours through a mask taken off
the wave peaks (SIGGRAPH 2018); Bad North's own sea is *"a mesh that plays this sort of looping wavy
shader"*. ⚠ Sines rather than Gerstner is a choice DREDGE already paid for and reversed.

**What it buys** — **the sea moves in one piece and it reads from across the room.** It is the only
candidate whose pattern travels rather than sitting still, and the only one that also changes the
island's silhouette against the water when the swell passes.

**What it costs** — a subdivided sea plane and a vertex pass. ⚠ The plane is 200 x 200 over 400 tiles
today — two tiles a quad — so a swell shorter than about six tiles falls between vertices and the
displacement quietly stops being real while the colour keeps drawing it.

**What it CANNOT do** — ⚠⚠ **it cannot be subtle at this camera.** The tone window is what makes it
read, and a hard window on a long sine is a **stripe**: at the strength where the sea looks alive the
water wears a regular zig-zag corduroy across the whole screen, and softening the window turns it back
into the fog it was on the first shot. ⚠ **The displacement itself is nearly invisible from a 40° camera**
— what is being seen is the colour, so almost all the geometry is being paid for and not looked at.
