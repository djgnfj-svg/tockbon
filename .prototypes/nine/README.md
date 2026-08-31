# `nine/` — **nine bodies in one 블록 (칸): where do they stand, and how big are they?**

**The question, in one sentence**: *nine 검사 fill one 블록 — which way of handing out their places
lets them be as big as possible while still reading as nine men?*

**The user's own words** (2026-08-31): *「Could you make the soldiers bigger and have them look
clean? I think nine soldiers is the maximum. … let both 칸 and 블록 work — we are going to do it that
way anyway.」*

⚠ **`scout` was NOT sent for this round.** The mechanisms below are geometry (a square lattice, a
staggered one, a facing-relative one, a spiral) rather than a technique somebody else shipped, and the
one outside reference the repo already holds — Bad North's squads — is what `03-ranks` is.

## Running it

```
Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/nine/lab.gd
    opens a window and stays. 1..5 pick · LEFT/RIGHT step · SPACE swaps body size · ESC quits.

Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/nine/lab.gd -- shoot
python .prototypes/nine/sheet.py
    ten shots into out/, then one sheet — five arrangements across, two body sizes down.
```

⚠ **Never `--headless`**: no swapchain, and every PNG comes back black with no error.

## The five, and what each one's seat belongs to

| | The seat belongs to | The picture |
|---|---|---|
| **01-now** | the **조각**, ringed | the control — what ships today, capped at nine |
| **02-grid** | the **블록**, one 3x3 lattice | evenly spaced, densest packing of nine in a square |
| **03-ranks** | the **squad**, turned to its facing | three ranks; the only one that says which way they look |
| **04-stagger** | the **블록**, rows nested | shallower than the grid, harder to count |
| **05-spiral** | the **블록**, golden angle | reads as a group of men, holds no shape |

**Each folder's `NOTES.md` carries the three lines that decide** — what it buys · what it costs · what
it CANNOT do.

## Two things about the lab that cost a round each, both measured 2026-08-31

1. **`soldier_hp` is 0 until `place_ashore` runs.** A body stood on the board by hand is ASHORE with no
   health, and the death phase kills all nine on the first sub-step. **The first ten shots came back
   with an empty island and no error anywhere.**
2. **The 블록 furthest from the 성채 is the one on the shore.** Picking for distance put five of the
   nine against open water and made the sheet half sea; the pick now demands a whole 조각 of walkable
   land on every side, at one level.

⚠ **The body size is applied to the `Sprite3D` nodes, not to `Look`** — every body size in the game is
a `const` and a const cannot be moved at runtime. **The ground disc does not grow with them**, so at
x1.25 it sits a quarter narrow. That is the lab, not a result.
