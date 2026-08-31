# 2026-08-31 — nine in a 블록 (칸), five ways

**The question**: nine 검사 fill one 블록 — which way of handing out their places lets them be as big
as possible while still reading as nine men?

**Where it came from** (the user, 2026-08-31): *「Could you make the soldiers bigger and have them look
clean? I think nine soldiers is the maximum. … I don't know how to work out whether that fits.」*

`sheet.png` — five arrangements across, two body sizes down (x1.00 is exactly what the game ships).

| | The seat belongs to | What it buys | What it CANNOT do |
|---|---|---|---|
| **01-now** | the 조각, ringed | nothing changes; the control | space bodies evenly across a 조각 boundary |
| **02-grid** | the 블록, 3x3 lattice | nine countable at a glance, densest packing | turn — nothing says which way they face |
| **03-ranks** | the squad, facing | the picture says where they look | say what happens when two squads share a 블록 |
| **04-stagger** | the 블록, rows nested | shallower, which is the axis that hides bodies | present a front |
| **05-spiral** | the 블록, golden angle | reads as men, not furniture | hold a shape — no row, no flank |

⚠ **The material is `.prototypes/nine/`** and each version's three lines live in its own `NOTES.md`.
**The losers are deleted once one has won.**

⚠ **What was measured on the way, and is not about the arrangements**: a body stood on the board by
hand is ASHORE with `soldier_hp` at 0, and the death phase kills it on the first sub-step — the first
ten shots came back with an empty island and no error anywhere.
