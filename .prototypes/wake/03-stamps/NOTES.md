# 03-stamps — discrete foam quads dropped behind the boat

**What it buys** — the simplest of the five to write and to read, and the only one with **no geometry
that can fail**: every mark is independent, so no turn however sharp can fold it. The same code drops a
mark for anything else that touches the water — a landing, an oar, a body going in.

**What it costs** — one quad per living stamp, rebuilt every frame; about thirty per boat at this
spacing, and the count is whatever the spacing says.

**What it CANNOT do** — **read as one even ribbon.** Overlapping stamps compound their alpha under
`blend_mix`, so how bright the trail is depends on how densely it was stamped, and **a spatial shader
has no max blend mode to escape that with.** Spacing them far enough apart to stop it turns the trail
into a dotted line, so the only move is to tune between the two.
