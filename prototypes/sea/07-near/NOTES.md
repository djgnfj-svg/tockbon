# 07-near — the sea only answers what is in it

**Where the open water comes from**: the island and the hulls, and nowhere else. A lift against the
rock out to the field's own limit, and rings leaving every boat. **Away from both it is the shipped
flat colour exactly.**

- **What it buys** — **presence instead of pattern.** It adds nothing the player has to learn to
  ignore, it cannot be 「자글자글」 anywhere, and it makes the boat an event in the water rather than a
  sprite over it. **It moves 22% of the `open` frame and 30% of `cross`** — the highest share of any
  candidate at the moments something is actually happening.
- **What it costs** — a loop over twelve hull blocks per pixel, on top of the one `hulls()` already
  runs. **The ring is a second thing the water does about a boat** and the shipped shader already
  draws three (shadow, break, halo), so a fourth is a fourth thing to retune when any of them moves.
- **⚠ What it CANNOT do** — **it draws NOTHING in open water**, and that is measured, not feared: in
  the `out` frame it moves 22% and every one of those pixels is beside the island or beside the hull.
  ⚠⚠ **The land half is also capped at four 조각 for good**: `sdf` clamps at `field_span`, so it is the
  same value from four 조각 out to the horizon. **Widening it is a change to how the island is baked,
  not a dial** — `04-bands` died on this exact limit on 2026-08-29.
