# 02-grid — the 블록 owns the seat, as one 3x3 lattice

Nine equal cells over the 블록's 2 x 2 조각, pitch 2/3 of a 조각 in both axes.

- **What it buys** — **nine bodies that can be counted at a glance**, evenly spaced, at the densest
  packing nine equal circles have in a square (the optimum for n = 9 is exactly this grid, r = side/6).
  It is the only version in the sheet where every man is visible at x1.25.
- **What it costs** — the seat stops belonging to a 조각. The middle row and column straddle the line
  where the four 조각 meet, so **shipping it means the sim's seat index moves up a unit with it** —
  `Grid.slot_of` answers a place inside a 조각 today and would have to answer a place inside a 블록.
- **What it CANNOT do** — turn. The lattice is fixed to the board's axes, so a squad walking east and a
  squad walking north stand in the same square; nothing in the picture says which way they are facing.
