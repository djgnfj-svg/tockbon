# 06-ranks-wide — `02-grid`'s square, turned

Built to answer one thing the user was torn on (2026-08-31): *「I do like 2's style, but 3 seems
right.」* `03-ranks` is `02-grid` squeezed front to back and turned, so this opens the squeeze back out
and keeps only the turning.

- **What it buys** — nothing that can be seen. **Measured with `seat_probe.gd`**: its nine seats do not
  move between south and east, and they are the same nine points as `02-grid`'s. `03-ranks`' seats do
  move.
- **What it costs** — a sixth version to read, for a difference that does not exist at right angles.
- **What it CANNOT do** — **show that it turned.** A square 3x3 lattice rotated a quarter turn maps
  onto itself, so「it faces east now」and「it faces south」are the same nine pixels.

## ⚠⚠ The finding this version exists to have made

**A formation can only be SEEN to turn if its two pitches differ.** Equal spacing across and along is
what makes the square, and a square is what makes the turn invisible. ⇒ **「02's look」 and 「it turns」
are the same choice asked twice, and they cannot both be had at 90° facings.**

## ⚠⚠ And how it was nearly measured wrong, twice

**The first instrument was a pixel difference between two screenshots, and it said this version DOES
turn** (≈6,500 changed pixels). It was wrong twice over:

1. **The board was not still.** The lab wrote the seats at the top of the frame and `Battle.step`
   nudged every body off them before the view drew — so any two frames differed by ~6,000 pixels no
   matter what. That was read as a noise floor; it was a bug, and `_freeze` is the fix.
2. **A screenshot carries each body's own idle-sway phase.** Even frozen, moving body 4 to a different
   seat changes the picture while the nine SEATS stay the same nine points. **The seat plan is a set of
   places; the picture also says who is standing in which.**

⇒ **`seat_probe.gd` answers this question and screenshots do not.** ⚠ The conclusion above survived
both errors, which is luck and not method.
