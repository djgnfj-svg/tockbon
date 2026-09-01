# tools/shot — what the game looked like, and the scripts that took the picture

**The shooters live here. Every picture they take lives in `out/`.**

⚠⚠ **`out/` carries a `.gdignore`, and that is the whole point of the split.** Godot imports every
image inside the project, so the 97 screenshots standing on the day of the split meant **97 extra
`.import` files** and 97 more things for the editor to chew on at startup. ⚠ **That 97 is the count on
2026-08-27, not a running total** — the folders have grown and been pruned since, and the reason holds
at any count. A `.gdignore` stops the import without hiding the files from git —
**nothing was deleted, and `save_png` still writes there**, because `globalize_path` is a string
mapping and does not care whether Godot imported the folder.

## The shooters

| Script | What it shoots | Where it lands |
|---|---|---|
| `shoot_field.gd` | the board at a run of camera angles and distances | `out/field/` |
| `shoot_fx.gd` | one frame per effect, each also cropped in close | `out/fx/` |
| `shoot_water.gd` | six seas, one island, one camera — the candidates go side by side | `out/water/` |
| `shoot_pad_seam.gd` | the merged 판, with the reveal key up and down, at yaw 0 and yaw 45 | `out/pads/` |
| `shoot_route_end.gd` | the 이동선's terminator against the 칸 it is aimed at | `out/pads/` |

⚠⚠ **THREE SHOOTERS WERE DELETED 2026-08-27 AND TWO OF THEM COULD NOT REACH THE ISLAND AT ALL.**
`shoot_big.gd` answered one question about edges at 2560x1440 and the answer is already applied.
`probe_shadow.gd` and `what_is_3d.gd` both walk the shell from the title, and **neither knows about
the refit screen**, so both stopped one screen short of the island they were written to photograph —
`probe_shadow.gd` was additionally hunting a drawn shadow blob that was itself deleted on 2026-08-26.
⇒ **A shooter that cannot reach the island is not a slow shooter, it is a broken one**, and this repo
has paid before for treating those as the same thing. `out/misc/` is empty because of it.

Run one the same way each time, with **the engine that lives in this repo**:

```
Godot_v4.7.1-stable_win64.exe --path . -s tools/shot/shoot_field.gd
```

## The folders under `out/`

| Folder | What is in it |
|---|---|
| `field/` | the board: planning, crossing, fighting, and the camera turned and pushed in |
| `fx/` | aim · refuse · landing · blow · shards · death, each near and far |
| `pieces/` | one piece at a time, bare and against the sea, plus the island from a ring of camera angles |
| `water/` | every sea candidate the shader was tried with, numbered in the order they were judged |
| `pads/` | the 판's two defects of 2026-09-02 — the dark seam down the middle of a merged mark, and the 이동선 ending in a corner. ⚠ **`pads/before/` is the same shots taken before the fix and is what the numbers were read off**, so it is a measurement and not a leftover |
| `misc/` | one-off probes |

⚠⚠ **`out/loop/` (25 shots) AND `out/species/` (12 shots) WERE DELETED 2026-08-27, AND NEITHER CAN BE
RETAKEN.** Both shooters had already died in the swap commit that made the beasts the enemy and the
swordsman the player, so the pictures had outlived the code that produced them by a fortnight:

- **`out/loop/`** was `shoot_loop.gd`: one whole run through the real shell, one PNG per screen it
  passed — title, cards, map, plan, fight, refit, lost — numbered in the order they were played. It
  photographed **screens that no longer exist**: the card screen, the refit screen and the island map
  are all from the folded cell game. ⚠ **The one piece of knowledge in it that outlives the shots is
  the reason it read `run.state()` each frame instead of replaying a scripted list of clicks** — a
  click list says what the loop was *believed* to be, while reading the state says what it *is*, so a
  stalled loop shows up as the same screen photographed twice rather than as a script that ran to the
  end regardless. **Whoever writes the next whole-run shooter should do the same thing.**
- **`out/species/`** was `shoot_species.gd`: four staged situations ticket 15 asked to judge by eye —
  all five summon boxes at once, all nine `Rules.UNITS` rows standing in one frame (so a row wearing
  another row's picture would show), a bleeding body beside an unbleeding one of the same species, and
  **the opening survey of each of the eight islands, one PNG apiece**. ⚠⚠ **Every one of those is a
  picture of a decision the user has since reversed**: there is now **ONE island, not eight** (drawing
  eight was the thing the project could not afford), the nine-species line-up is gone, and the beasts
  are the enemy rather than the roster. The shots are not stale, they are **wrong**.
- ⚠⚠ **The trap both shooters carried, and it is still live: never run a shooter `--headless`.** There
  is no swapchain to read a frame back from, so **every PNG comes out black with no error anywhere** —
  `shoot_species.gd` had to enforce the refusal in code because the silent black frames read as "the
  art does not draw". The surviving shooters run the same way, with a real window.

⚠ **A picture here is a MEASUREMENT, not decoration.** The map and the tickets cite these by path when
the user judged something by eye, so **renaming or deleting one breaks a citation.** If a shot stops
being true, take a new one beside it rather than overwriting the old.
