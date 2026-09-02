# selection_box — five ways of drawing the drag-selection box on the real island

## The question

**2026-09-02, the user:** 「땅에 깔리는 거랑 그냥 사각형이랑 둘 다 해야할듯? 그렇게 프로토타입으로 보는거지
해보면서」 — *"the ground-laid one and the plain rectangle both have to be tried; that is what a
prototype is for, you see it by trying."*

**The subject is THE DRAG-SELECTION BOX** — the marquee the hand pulls with the left button to pick
several 검사 at once, StarCraft's rectangle. The set compares boxes drawn ON THE GLASS (screen space,
they do not turn with the board) against boxes LAID ON THE GROUND (they sit on the terrain and turn
with it).

## How to run it

```
./Godot_v4.7.1-stable_win64.exe --path . --script res://.prototypes/selection_box/lab.gd            # watch it
./Godot_v4.7.1-stable_win64.exe --path . --script res://.prototypes/selection_box/lab.gd -- shoot   # photograph it
python .prototypes/selection_box/sheet.py                                                          # all on one sheet
```

**Watching**: `LEFT`/`RIGHT` cycle the candidates, `ESC` quits. A bare number on the command line
opens on that candidate. **The game's own keys still work** — `Q`/`E` turn a quarter through the
game's own sweep, `W`/`A`/`S`/`D` pan, `R`/`F` tilt, the wheel zooms. ⚠ The game has no zoom on W/S;
those pan. The candidate's `NAME` is drawn top-left.

**Shooting**: for every candidate — mount, photograph `out/<NN-name>_yaw0.png`, send the game its own
`Q`, wait for `cam_yaw_deg` to stop changing with nothing owed to the sweep, three more ticks, photograph
`out/<NN-name>_yaw90.png`, unmount, send `E`, settle, next. Then quit.

⚠ **Never `--headless`**: there is no swapchain to read a frame back from and every PNG comes out
black with no error anywhere.

⚠⚠ **This lab drives the REAL game.** It presses 시작하기, waits until the four starting 검사 are
ashore, and hangs each candidate in the field's own world — every box is judged on the island that
ships, under its camera and its sun.

## The fixed drag

**One drag for every candidate**, in screen px at the opening camera (zoom 0.762, yaw 0, pitch 40):

| | Screen px | Terrain hit under it, field world space (x, y, z) — measured 2026-09-02 |
|---|---|---|
| **A** (button down) | `(440, 345)` | `ground[0]` TL `(8.4375, 0.21, 12.4846)` |
| **B** (pointer now) | `(660, 445)` | `ground[2]` BR `(15.6563, 0.21, 17.5893)` |
| | | TR `(15.6563, 0.21, 12.4846)` · BL `(8.4375, 0.21, 17.5893)` |

All four corners land on 1층 (y 0.21 is the level-0 top with the mesh's `base_h` in it). The rect is
`Rect2(440, 345, 220, 100)`. It closes over the four starting 검사 standing at the 성채
door (feet at about `(457, 375)` and `(488, 375)`) and the open flat ground to their right; its top
edge crosses the foot of the 2층 tongue the 성채 stands on. The lab prints every body's screen point
and whether it is inside the rect at boot — read that line before trusting a picture.

## The candidate contract — code against this exactly

A candidate is a folder **`NN-name/`** beside this file holding **`scene.gd`** and **`NOTES.md`**.
The lab finds every sibling folder with a `scene.gd`, sorted by name.

`scene.gd`:

- `extends RefCounted`
- `const NAME := "NN-name"`
- `func mount(game: Node, fv: Node, drag: Dictionary) -> void` — `game` is the shell (`Game`),
  `fv` is the field view (`FieldView`, its 3D world is `fv._world`, its camera `fv._cam`), and
  `drag` is:
  - `"a"`: `Vector2` — where the button went down, screen px
  - `"b"`: `Vector2` — where the pointer is now, screen px
  - `"rect"`: `Rect2` — screen px, normalised so `position` is the min corner
  - `"ground"`: `PackedVector3Array` — the four terrain hits under the rect's corners in the field's
    world space, order **TL TR BR BL**; `y` is the terrain top with **no lift** (add
    `Look.FX_GROUND_LIFT_TILES` = 0.02 yourself or the ground z-fights through)
  - `"camera"`: `Camera3D` — the field's real camera
  The candidate adds its own nodes — a `CanvasLayer`/`Control` under `game` or the root for screen
  space, `Node3D` children under `fv._world` for ground-laid — and keeps references to them.
- `func unmount() -> void` — removes everything `mount` added.
- `func lines() -> PackedStringArray` — the three NOTES lines, **buys · costs · cannot**, so the sheet
  can print them.

`NOTES.md`: a heading line, then exactly three lines beginning `- buys — `, `- costs — `,
`- cannot — `. `sheet.py` reads the lines that begin with `- `.

**Shared code** is `common.gd`, called as a static script
(`var common: GDScript = load("res://.prototypes/selection_box/common.gd")`):

- `common.load_ink(path) -> ImageTexture` — a PNG from `.candidates/selection_box/` with its white
  ground turned to alpha and every inked pixel set to the mint. ⚠ That folder is not imported by
  Godot; this reads it off disk. The lab prints the loader's coverage at boot on
  `selbox_frame_01_seed2137183347_64px.png` (peak alpha about 0.72 on the 64 px downsamples).
- `common.ink_colour() -> Color` — the mint, (158, 245, 212).
- `common.nearest(node)` — nearest-neighbour sampling on the `CanvasItem` or `SpriteBase3D` that
  draws the texture; an `ImageTexture` carries no filter of its own in Godot 4.

A ground-laid candidate that wants the surface along its edges and not only at the corners can call
the lab's `ground_hit(screen_px) -> Vector3` — but the lab is not handed to `mount`, so read
`fv.screen_to_terrain_px` and `fv._ground_h` directly the way `lab.gd` does.

## The five, and what each is

| | Where it is drawn | What it is made of |
|---|---|---|
| `01-screen-frame-picture` | **screen** | the pulled `frame_01` picture, its edges stretched to the rect |
| `02-screen-corners` | **screen** | the pulled `plain_02` ㄴ corner rotated four times, lines between them |
| `03-screen-line` | **screen** | a code-drawn 1 px mint rectangle — **the StarCraft control** |
| `04-ground-decal` | **ground** | a rectangle projected onto the terrain, following its height |
| `05-ground-quad` | **ground** | a flat textured quad at ground level; turns with the board, ignores height |

**Each folder carries a `NOTES.md` with three lines: what it buys, what it costs, and what it CANNOT
do.** ⚠ The third is the one that decides.

## What the harness proved before any candidate existed

A throwaway `00-empty/` (mounts nothing) was run through `-- shoot` on 2026-09-02: the island opened,
four 검사 were ashore, both PNGs came back non-black, the Q notch settled at -90 and E brought it back
to 0, and `sheet.py` laid the row out. It was deleted afterwards with its shots.
