# 01-now — the 조각 owns the seat, and rings it

**The control.** Three seats per 조각: the centre, then two on a ring of `Look.CROWD_SPREAD_RATIO`.
Nine bodies arrive round-robin over the 블록's four 조각, so they land 3 · 2 · 2 · 2.

- **What it buys** — nothing has to change. The seat is already the reservation slot, the sim already
  hands out the lowest free one, and a lone body still stands dead centre of its own 조각.
- **What it costs** — the nine read as **two overlapping clumps rather than as nine men.** The ring is
  0.30 조각 wide and a 검사 is drawn 0.686 조각 wide, so the three in one 조각 sit almost entirely on
  top of each other while the gap between 조각 stays a whole 조각 wide.
- **What it CANNOT do** — put even spacing between bodies that are in different 조각. The seat is
  computed inside one 조각 and knows nothing about the 조각 next to it, so **two bodies a hair apart
  across a 조각 boundary will always be drawn a full 조각 apart.** No constant fixes that.
