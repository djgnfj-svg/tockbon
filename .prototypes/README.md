# `.prototypes/` — throwaways that settle a look by being LOOKED at

**One question per subject folder. Three or more genuinely different answers to it, standing side by
side, photographed, and put in front of the user.** The winner becomes a ticket; the losers are
deleted. Nothing in here is imported by `src/`, and nothing in here obeys that folder's rules.

⚠ **This file is the MACHINERY.** How the round is run — how many candidates, how the sheet is put in
front of the user, what happens to the losers — is the `prototype` skill, and it is not repeated here.

## ⚠⚠ Do not write a lab runner from scratch. One of these already fits.

**Ten lab runners exist and they total 4,106 lines** (twelve entry points counting the two probes). **Two of them share 143 lines verbatim.** A new
subject is a COPY of the nearest runner with its candidate list swapped — that is the whole rhythm, and
it is the difference between a round that takes an hour and a round that takes a day.

| Your question is about… | Copy this | It hands you, already working |
|---|---|---|
| **water, a shoreline, a sea shader** | `sea/open_lab.gd` | a hull crossing open water, the shipped sea spliced in, two camera columns (land in frame · no land anywhere) |
| **the same, but judged against the island** | `shoreline/lab.gd` | one 2×2 piece on a sea plane, the game's camera angle and sun, a signed `land_field` and a `depth_field` handed to every candidate |
| **a mark on the ground, a 판, a HUD** | `pads/lab.gd` | the REAL game opened and 시작하기 pressed, candidates hung in the field's own world, the game's own keys still live |
| **a prop, a tree, a bush — a card in the world** | `props/lab.gd` | a lit card with a baked normal map, a soft shadow pool, the double-draw outline |
| **what happens BETWEEN two camera distances** | `merge/lab.gd` | the real game with the baked 판 hidden, and every candidate photographed at three zooms |
| **something moving over time** | `wake/lab.gd` | a boat sailing a path, four frames per candidate seconds apart, the shipped sea as the control |
| **whether a body can physically get somewhere** | `stairs/walk_probe.gd` | a probe that prints numbers instead of taking a picture |
| **where a crowd STANDS, and how it gets there** | `nine/lab.gd` | the real game opened, nine 검사 in one 블록, the sim frozen for stills and stepped by hand for a walk, plus two probes |
| **a HAND gesture — a drag, a box, a press that picks or orders** | `selection_box/lab.gd` | a copy of `pads` that drives the real game: the left drag does the WHOLE gesture through the game's own `pick_many`, reach and order, so the user tries it by hand; candidates mount on screen or in the field's world; `-- drive` feeds the gesture through `parse_input_event` as the harness's own proof |

## The three families, and which one you are in

- **Builds its own little world** — `shoreline`, `swash/lab.gd`, `sea/island_lab.gd`, `sea/open_lab.gd`, `wave`, `wake`.
  One block, one sea plane, the game's camera and sun. **Seconds to run, and nothing else in frame.**
  ⚠ Use it when the thing being judged is the SURFACE, not the place.
- **Drives the REAL game** — `pads`, `props`, `merge`, `selection_box`, `swash/island_lab.gd`, `palette/shoot_one.gd`.
  Opens `Game`, presses 시작하기, hangs candidates in the field's own world. **Slower, and the only
  honest answer when the candidate has to sit on ground the game actually ships.**
- **A probe, not a picture** — `stairs/walk_probe.gd`. Prints measurements. No swapchain needed.

## What every runner already carries — take it, do not re-derive it

```
extends SceneTree

const DIR    := "res://.prototypes/<subject>"
const OUT    := "res://.prototypes/<subject>/out/%s_%d.png"
const FRAMES := 4     # ⚠ ONE PICTURE CANNOT ANSWER 「움직이나」 — a still shore and a shore caught
const GAP    := 26    #   mid-swing look identical in it, and the shader clock cannot be advanced
                      #   by hand. The only way to photograph a change is to wait for it.
```

- **Two ways to run, and the default is the one you WATCH** — bare opens a window and stays,
  `-- shoot` photographs everything and quits.
- **The keys overlap, they are not a standard.** `LEFT`/`RIGHT` step and `ESC` quits in every runner;
  `shoreline` and `swash` add `1`..`9` to pick, `Q`/`E` to turn and `W`/`S` to zoom, and that set is the
  one worth copying. A game-driving lab keeps the game's own keys on top.
- **The candidate's name is on screen**, or the picture cannot be talked about.

## ⚠⚠ Four traps, each measured, each of which has already cost a round

1. **Never `--headless`, either way.** There is no swapchain to read a frame back from and **every PNG
   comes out black with no error anywhere.**
2. **Godot does not import this folder** — measured 2026-08-30 by dropping a new `.png` in and running
   `--import`: no sidecar appeared. **That is what the leading dot is for.** So:
   **`res://.prototypes/…` works for scripts, shaders and `#include`** — and **not for a texture or a
   `.glb`.** Read those with `Image.load(ProjectSettings.globalize_path(…))` and `GLTFDocument`, the
   way `bush/common.gd` and `props/lab.gd` already do. **`.import` sidecars are git-ignored here.**
3. **The shipped shader is SPLICED, never hand-copied.** `build.py` (`sea`, `wake`, `wave`) wraps
   `src/view/water.gdshader` around each folder's own `mech.gdshader`, so the water is byte-identical
   across every picture by construction — **the eye finds a difference in the water before it finds
   the difference being asked about** — and it re-splices the day the shipped one changes.
4. **The user reads a SHEET, not a folder of shots.** `sheet.py` (`merge`, `pads`, `sea`, `wave`) lays
   every candidate on one image with `PIL`. A round that ends at `out/` has not ended.

## The shape on disk

```
.prototypes/<subject>/
    README.md          <- the question, in the user's own words, and the run commands
    lab.gd             <- the runner. ONE per subject; a second sheet reuses the same harness
    common.gd          <- only if two candidates genuinely share code (bush, merge, wake)
    build.py           <- splices the shipped shader into each candidate, if the subject is water
    sheet.py           <- lays the shots on one sheet
    <NN-name>/
        NOTES.md       <- what it buys · what it costs · what it CANNOT do
        scene.gd       <- or wake.gd / mech.gdshader — the candidate itself
    out/               <- the shots. Regenerated by one command; kept so a round can be re-read
```

**Seventy-three `NOTES.md` exist.** A candidate without one is a picture nobody can argue about a week
later.

## What is duplicated in here — said out loud so nobody mistakes this for a clean folder

**The camera rig, the sun, the block mesh, the sea plane, the key handling and the shoot loop are
re-typed in every runner.** `shoreline/lab.gd` and `swash/lab.gd` share 143 lines verbatim out of
roughly 350 each. **Nothing has been extracted, and extracting it has never been the cheapest move**:
a shared harness that every subject must bend to is how a lab stops being a throwaway, and a throwaway
that has to be maintained is worse than a copy that gets deleted.

⇒ **Copy the nearest runner. Delete what your question does not ask.** ⚠ If you find yourself changing
the copy's camera, sun and ground as well as its candidates, **you are in the wrong family** — go back
to the table above and copy the other one.

## Two subjects have no README, and that is a defect

**`bush/`** (three candidates: a baked mesh, quads, a Bad North card) and **`props/`** carry no
`README.md` and `bush/` has no runner at all — its candidates are opened one at a time. Anyone who
touches either should leave one behind.

✅ **`selection_box/04-ground-decal` WON on 2026-09-02** (the user, playing the game: 「선말고 선택된 부분을
약간 드래그 영역 안쪼 생상이 보여야함」 — *"not the line, the colour inside the drag area"*). It grew into
**`FieldView.set_box`** — a mint fill on the terrain at alpha 0.28 with a thin outline. **The four losers
were deleted** the same night, per the skill; the sheet is `docs/reference/2026-09-02-selection-box-prototypes/`.
⚠ The lab's README still describes five candidates and a right-button order — read it as the round's record.

✅ **`bush/03-badnorth` WON on 2026-08-31** (the user: 「2d로해서 적용만해줘」). Its `card.gdshader`
grew into **`src/view/prop_card.gdshader`**, with the shared `wind.gdshaderinc` folded in because the
other two candidates stayed behind. **The bush in the game is that card.** ⚠ The three candidates are
kept here anyway — the losers are what say why the winner won, and nobody has asked to clear them.
