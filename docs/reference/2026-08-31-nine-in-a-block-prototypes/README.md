# 2026-08-31 — nine in a 블록 (칸), five ways

**The question**: nine 검사 fill one 블록 — which way of handing out their places lets them be as big
as possible while still reading as nine men?

**Where it came from** (the user, 2026-08-31): *「Could you make the soldiers bigger and have them look
clean? I think nine soldiers is the maximum. … I don't know how to work out whether that fits.」*

**Two sheets, in the order they were made.**
`sheet.png` — five arrangements across, two body sizes down (x1.00 is exactly what the game ships).
`sheet-facing.png` — six across, the same nine facing south then east. **The second one exists because
of the question the first one raised**, and both are kept: the size answer lives only in the first.

| | The seat belongs to | What it buys | What it CANNOT do |
|---|---|---|---|
| **01-now** | the 조각, ringed | nothing changes; the control | space bodies evenly across a 조각 boundary |
| **02-grid** | the 블록, 3x3 lattice | nine countable at a glance, densest packing | turn — nothing says which way they face |
| **03-ranks** | the squad, facing | the picture says where they look | say what happens when two squads share a 블록 |
| **04-stagger** | the 블록, rows nested | shallower, which is the axis that hides bodies | present a front |
| **05-spiral** | the 블록, golden angle | reads as men, not furniture | hold a shape — no row, no flank |

## The judging round, and what it measured

**The user, on the sheet**: *「It looks like 2 or 3. … What is this turning? Tell me about the turning
first.」* ⇒ the sheet was re-shot: **the same nine at two FACINGS instead of two body sizes**, and
`06-ranks-wide` was added — `02-grid`'s square spacing with `03-ranks`' turning.

⚠⚠ **A FORMATION CAN ONLY BE SEEN TO TURN IF ITS TWO PITCHES DIFFER.** Measured with `seat_probe.gd`:
**`06-ranks-wide`'s nine seats do not move between south and east, and they are the same nine points as
`02-grid`'s**, while `03-ranks`' seats do move. A square 3x3 rotated a quarter turn maps onto itself.
⇒ **「02's look」 and 「it turns」 cannot both be had.**

⚠⚠ **THE SAME CLAIM WAS MADE FIRST OFF A PIXEL DIFFERENCE AND THAT INSTRUMENT WAS BROKEN TWICE OVER.**
The lab wrote the seats and `Battle.step` nudged the bodies off them before the view drew, so **every
검사 vibrated once per frame** (the user, watching it: 「the character's frames keep jittering back
and forth — it's horrible」) and any two frames differed by ~6,000 pixels. And even on a frozen board a
screenshot carries each body's own idle-sway phase, so **moving a body to a different seat changes the
picture while the seats stay identical.** The conclusion survived; the evidence did not.

**What the user said the nine should FEEL like** (2026-08-31): *「Moving them all at once would work
too, of course, but really it should feel like they go one after another, streaming along — a bit like
a fluid? Because they can't all move at the same time.」*
⚠ **That is not decided by anything on this sheet.** Every version here is a plan for where a body
STANDS; the streaming is how a body TRAVELS between two of those places, and it belongs to the
movement work — week 3, 「부대를 쪼개고 합치고 명령한다」.

⚠ **The material is `.prototypes/nine/`** and each version's three lines live in its own `NOTES.md`.
**The losers are deleted once one has won.**

⚠ **What was measured on the way, and is not about the arrangements**: a body stood on the board by
hand is ASHORE with `soldier_hp` at 0, and the death phase kills it on the first sub-step — the first
ten shots came back with an empty island and no error anywhere.
