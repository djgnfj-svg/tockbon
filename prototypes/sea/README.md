# sea — what the OPEN water is made of

## The question

> **The open sea — everything outside the white border — is a single flat colour, and nobody chose it.**
> **What is it made of?**

⚠⚠ **This does NOT reopen the shoreline.** Where the white line comes from was settled out of seven
mechanisms (`prototypes/shoreline/`) and how it moves was settled out of twenty-seven
(`prototypes/swash/`, the winner `27-gaps`). **Both ship, and every candidate here carries the shipped
border byte for byte and is handed the game's own shoreline dials** — so the only thing that differs
between two pictures is the water away from the rock.

## ⚠⚠ The far sea is part of the question, and that is the user's own framing

> **「섬에 해안가는 끝났음 먼 바다까지 생각했을 때의 바다를 어떻게 할지 고민하는 중임」** (2026-08-29)
> — *"the island's shore is finished; what I am working out is the sea when the far water is counted in."*

⇒ **A mechanism that only works as a halo around the island does not pass.** The user has already said
the sea will be sailed on (2026-08-28: 「나중에 바다를 항해도 할꺼여서」 — *"we are going to sail the sea
later too"*), so **every candidate is judged on the water a long way from any coast as well as beside it.**
⚠ That is the axis the shipped sea fails on hardest and the one most cheap fixes fail on too: anything
driven by distance-to-land has nothing left to say once there is no land in frame.

⚠ **The flat sea was confirmed twice** (2026-08-28 out of seven, 2026-08-29 by adding a foam band back
and taking it out). Neither of those was a set of mechanisms for the open water's own surface; both were
about the rim. **That is why this question is still open.**

## How to run it

```
Godot_v4.7.1-stable_win64.exe --path . -s prototypes/sea/island_lab.gd
Godot_v4.7.1-stable_win64.exe --path . -s prototypes/sea/island_lab.gd -- shoot
```

**0 is the sea as it ships · 1.. are the candidates · LEFT/RIGHT step · Q/E turn · W/S zoom ·
R/F tilt · ESC quit.** ⚠ **Never `--headless`** — every PNG comes out black with no error.

## Where each one takes the open water from

| | Where the open water comes from | Says something in the FAR sea |
|---|---|---|
| `shipped` | **nowhere** — one flat colour, and it got there by subtraction | it IS the far sea, and it is empty |
| `01-crests` | **a noise field in world space, cut with a threshold** (Alba, Ameye) | ✅ |
| `02-facets` | **a lattice of flat cells**, each one flat tone, bent so it is not a grid | ✅ |
| `03-swell` | **the mesh really moves**, and the colour is read off the height (Sea of Thieves, Bad North) | ✅ |
| `04-bands` | **how far the land is**, posterised into hard steps (Ameye, A Short Hike) | ⛔ nothing — the field ends at four tiles |
| `05-paper` | **the screen**, not the world: quantised on a pixel lattice and dithered (A Short Hike) | ✅ |

**Each folder carries a `NOTES.md` with three lines: what it buys, what it costs, and what it CANNOT
do.** ⚠ The third is the one that decides.

## Two cameras, and the second one is the question

`python prototypes/sea/sheet.py` lays every version out twice — **the island in frame, and open water
with no land in the picture at all.** ⚠⚠ **A mechanism can win the left column and be blank in the
right**, and `04-bands` is exactly that: it is the best thing on the sheet beside the coast and it is
the shipped flat sea, unchanged, forty tiles out.

⚠ **Every version is shot four times, seconds apart** (`out/island/<name>_0.png` .. `_3.png` and the
same under `out/far/`). One picture cannot answer 「움직이나」.

## How each one was built

**`build.py` splices, it does not copy.** Each folder holds only `mech.gdshader` — its own uniforms and
one function, `vec3 open_sea(vec2 p, float d, float t, vec2 sxy)` — and the script wraps the shipped
shader round it. **The border is therefore byte-identical in all six pictures by construction**, and
re-splices itself the day `src/view/water.gdshader` changes.
