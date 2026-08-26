# tools/shot — what the game looked like, and the scripts that took the picture

**The shooters live here. Every picture they take lives in `out/`.**

⚠⚠ **`out/` carries a `.gdignore`, and that is the whole point of the split.** Godot imports every
image inside the project, so 97 screenshots meant **97 extra `.import` files** and 97 more things for
the editor to chew on at startup. A `.gdignore` stops the import without hiding the files from git —
**nothing was deleted, and `save_png` still writes there**, because `globalize_path` is a string
mapping and does not care whether Godot imported the folder.

## The shooters

| Script | What it shoots | Where it lands |
|---|---|---|
| `shoot_field.gd` | the board at a run of camera angles and distances | `out/field/` |
| `shoot_fx.gd` | one frame per effect, each also cropped in close | `out/fx/` |
| `shoot_water.gd` | six seas, one island, one camera — the candidates go side by side | `out/water/` |
| `shoot_big.gd` | one frame at 2560x1440, for looking at edges | `out/misc/` |
| `probe_shadow.gd` | shadows only, to see what is and is not falling on the ground | `out/misc/` |
| `what_is_3d.gd` | prints what is actually in the 3D tree — no picture | — |

Run one the same way each time, with **the engine that lives in this repo**:

```
Godot_v4.7.1-stable_win64.exe --path . -s tools/shot/shoot_field.gd
```

## The folders under `out/`

| Folder | What is in it |
|---|---|
| `field/` | the board: planning, crossing, fighting, and the camera turned and pushed in |
| `fx/` | aim · refuse · landing · blow · shards · death, each near and far |
| `loop/` | a whole run, screen by screen, in the order it was played |
| `species/` | the beast line-up, the slot row, bleed, and eight islands in a row |
| `water/` | every sea candidate the shader was tried with, numbered in the order they were judged |
| `misc/` | one-off probes |

⚠ **A picture here is a MEASUREMENT, not decoration.** The map and the tickets cite these by path when
the user judged something by eye, so **renaming or deleting one breaks a citation.** If a shot stops
being true, take a new one beside it rather than overwriting the old.
