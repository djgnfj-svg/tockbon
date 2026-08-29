# merge — four ways for the 조각 판 to become one 칸 as the camera pulls back

## The question

**멀어질수록 조각 판이 칸 하나로 합쳐지려면 무엇을 움직이나** — settled with the user before anything was
built (2026-08-29): 「멀면 칸단위로 하려고함 줌에따라」, and the seams inside a 칸 go **completely**
(「넷다 없애봐」).

## How to run it

```
Godot_v4.7.1-stable_win64.exe --path . -s prototypes/merge/lab.gd            # watch it
Godot_v4.7.1-stable_win64.exe --path . -s prototypes/merge/lab.gd -- shoot   # photograph it
python prototypes/merge/sheet.py                                            # twelve on one sheet
```

**Watching**: `1`..`4` pick a version, `←`/`→` step, **the wheel zooms and the merge follows it live** —
which is the thing to look at. The label shows the zoom and the merge. `ESC` quits.

⚠ **Never `--headless`**: there is no swapchain to read a frame back from and every PNG comes out black
with no error anywhere.

## The four, and where the merge comes from

| | Where the merge comes from | What is on screen mid-way |
|---|---|---|
| `01-grow` | **the vertices move** — every ring point carries where it goes | one board, a real in-between shape |
| `02-carve` | **the gutter is a shader number** on a whole-조각 quad | one board, the cut moving |
| `03-crossfade` | **two finished boards**, faded across | ⚠ **both at once** — a double exposure |
| `04-filler` | **a bar over each seam**, fading in | the resting board plus the bars |

**Each folder carries a `NOTES.md` with three lines: what it buys, what it costs, and what it CANNOT
do.** ⚠ The third is the one that decides.

## What is fixed for all four, on purpose

- **The ramp** — fully merged at zoom 0.72, fully apart at 1.45, straight line between. Not what is
  being judged
- **The tone** — one flat value. **The tone is ticket 33's question**, and a version that also moved it
  would be two changes photographed as one
- **The shipped 판 is switched off** while a version is up. Two boards on one island is two answers
  photographed as one

⚠ **These are throwaways in GDScript.** The shipped 판 is baked in Blender; **the winner gets rebuilt
there.** ⚠ **No fresh scout was sent** — the four mechanisms were put to the user as a list and chosen
before building.
