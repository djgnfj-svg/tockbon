# sea — what the OPEN water is made of

⚠⚠ **THERE ARE TWO ROUNDS IN THIS FOLDER.** `01-crests` .. `05-paper` are the 2026-08-29 round, shot
by `island_lab.gd`, and **every one of them was turned down**. `06-fleck` .. `10-grain` are the
2026-08-30 round, shot by `open_lab.gd`, and they are asking the question again **with a boat in the
frame**. The second round's own head is at the bottom of this file.

## The question

> **The open sea — everything outside the white border — is a single flat colour, and nobody chose it.**
> **What is it made of?**

⚠⚠ **This does NOT reopen the shoreline.** Where the white line comes from was settled out of seven
mechanisms (`.prototypes/shoreline/`) and how it moves was settled out of twenty-seven
(`.prototypes/swash/`, the winner `27-gaps`). **Both ship, and every candidate here carries the shipped
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
Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/sea/island_lab.gd
Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/sea/island_lab.gd -- shoot
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

`python .prototypes/sea/sheet.py` lays every version out twice — **the island in frame, and open water
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

---

# The second round — 2026-08-30, and a boat is in it

## The question

> **「배가 건너다니는 열린 바다가 비어 보이지 않으려면 무엇이 있어야 하나」**
> — *what has to be in the open sea so it does not read as empty while a boat crosses it?*

The user, watching the wake lab: **「물이 좀 너무 없긴하다 뭔가」**.

## ⚠⚠ Why this is being asked twice, and what the ten above do NOT have to prove again

**On 2026-08-29 ten mechanisms went in front of the user and every one was turned down** — five here
and five in `.prototypes/wave/`. Not because a winner lost: **because nothing beat flat**. 「나중에
해야할껄로 정리」. **Rebuilding those ten is a wasted round.** `open_lab.gd`'s `SKIP` keeps them out of
this sheet and their `NOTES.md` files are the record.

**Two things are different now and they are the entire reason for a second asking:**

1. ⚠⚠ **That round judged EMPTY water.** No boat and no wake in any of the ten frames. **Every
   candidate here is judged with a hull crossing and its trail behind it** — and it may be that the
   sea does not need filling so much as it needs something to be relative to.
2. **The camera now roams `Look.CAM_ROAM_TILES` = 20 조각 out over open water**, and the emptiness is
   worst out there. **The old round never looked.**

⚠ **The flat sea has been confirmed three times and is not reopened. The 해안선 is not on the table
either.** Every candidate carries both byte for byte — see «How each one is built» above; the same
`build.py` splices this round.

## How to run it

```
Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/sea/open_lab.gd
Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/sea/open_lab.gd -- shoot
```

**0 is the sea as it ships · 1.. are the candidates · LEFT/RIGHT step · TAB steps the three frames ·
ESC quits.** ⚠ **Never `--headless`** — every PNG comes out black with no error.

## The three frames — `out/open2/<name>_<frame>.png`

| | what it is |
|---|---|
| `open` | **the island's opening framing**, 42 조각 of visible ground, and no boat. The baseline |
| `out` | ⚠⚠ **the camera at the far corner of its roam** — the middle of the screen 14.0 조각 across and 14.6 down, which is as far as `_clamp_cam` allows. The island falls into one quarter and open water fills the rest. **This is the frame the round exists for** |
| `cross` | **a hull mid-crossing with its trail**, at the opening framing |

⚠ **The hull, its speed, its three contact marks and its trail are the GAME's** — `Rules.BOAT_SPEED_TILES`
1.2 and section 7 of `look.gd`, driven through `field_view._paint_wake`'s own slot rule. **Not the wake
lab's 4.0**, which `look.gd` records as a stale copy that made the judged trail three times too long.

## ⚠⚠ What makes the 해안선 a control and not a second variable

**`Engine.time_scale` is zero while shooting.** The shipped border rides `TIME`, which cannot be pinned
from outside without editing the shipped shader — and editing it is disqualifying. **Measured before
that line existed: 0.6% of the `open` frame moved by more than 40 of 255 between two candidates, every
one of those pixels at the coast.** With the clock stopped the coast is byte-identical between pictures
and **no candidate moves any pixel by more than 32 of 255.** Each candidate's own animation reads
`lab_t`, a uniform this lab writes, for the same reason.

## Where each one takes the open water from

| | Where it comes from | `open` | `out` | `cross` |
|---|---|---|---|---|
| `shipped` | **nowhere** — one flat colour. **The control every candidate has to beat** | — | — | — |
| `06-fleck` | **discrete objects you can count**, drifting as one current | 1.0% | 1.9% | 1.0% |
| `07-near` | **the island and the hulls, and nowhere else** | 22.6% | 21.7% | 29.9% |
| `08-drift` | **a swell train** — three wavefronts travelling one way | 80.9% | 91.1% | 80.2% |
| `09-rim` | **how far out from the island it is** — the sea has an edge | 62.6% | 79.3% | 61.8% |
| `10-grain` | **a fine noise field everywhere.** ⚠ **THE CONTROL for 「무늬」, not a candidate** | 44.0% | 50.1% | 43.6% |

**The percentage is how much of the frame the candidate moved off `shipped`** — a measurement that it
does something, not that it does something good. **Each folder's `NOTES.md` carries the three lines:
what it buys, what it costs, and what it CANNOT do.** ⚠ The third is the one that decides.

⚠⚠ **`08-drift` CANNOT BE JUDGED FROM THE SHEET AND ITS `NOTES.md` SAYS SO.** A still of a travelling
swell is two soft bands; everything it is for happens in the next second. **That row is run in the live
lab or it is being judged on the wrong evidence.**
