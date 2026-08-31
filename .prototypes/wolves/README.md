# `wolves/` — **which wolf, judged in the game rather than on a contact sheet**

**The question, in the user's words (2026-08-31):**
> ***"Looking at it only like this I cannot tell. I think we need to pull a prototype — on the boat and
> on the ground."***

⚠ **This is not a prototype SET in the usual sense.** Every candidate here is the same mechanism — one
picture in a `Sprite3D` — and only the drawing changes. What was borrowed from `prototype` is the
photography: **one instant, one camera, the wolf as the only thing that moves between frames.**

## How it works, and the one trick worth keeping

`lab.gd` opens the REAL game, presses 시작하기, then **turns the game's own `_process` off** so nothing
advances unless the file says so. Time is then spent by hand, and at the chosen instant every candidate
is dropped into `field_view._tex_facing[Rules.WOLF]`, the field is repainted **with a zero delta**, and
the frame is saved. **Nothing in the world differs between the shots but the animal.**

- **`installed` is a name with no picture behind it** — it overrides nothing, so it photographs what the
  game itself loaded. It is the only shot that can say the chosen wolf really reached `assets/`.
- **The camera is panned onto the subject** (`pan_by` toward the viewport centre) before each sweep.
  ⚠ The roam ring stops the pan short of the boat, so the hull sits at the left edge by design.
- ⚠ **Never `--headless`** — no swapchain, every PNG comes out black with no error.

```
Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/wolves/lab.gd
python .prototypes/wolves/sheet2.py one .prototypes/wolves/out/_sheet.png
```

## The pictures are NOT here

**Every candidate lives in `.candidates/wolf/`, under the date it was pulled, and nothing there is ever
deleted.** `lab.gd` reads them from there. The job ids that fetch any of them again are in that folder's
`2026-08-31-job-ids.md` — the pixen tool returns no seed, so the id is the handle.

**The shots the decision was made from are in `docs/reference/`**, dated. `out/` is scratch.

## `ground.py` — and the version of it that caught nothing

**Some pulls come back with a patch of dirt or a painted shadow welded under the paws**, and on a
billboard that patch slides over the grass with the animal.

⚠⚠ **The first check measured the widest opaque run in the bottom four rows and called all three
known-dirty candidates clean.** A painted ground patch is a slanted quad, so its last row is a narrow
corner — exactly like a paw. **It was only caught because a fixture of three dirty and three clean
images existed to point it at.**

The separation is at the **seventh of eight bands**, the height of the shins: one unbroken bar there,
against legs with gaps between them.

| | seventh band, over ink width |
|---|---|
| **known dirty** | **84% · 57% · 59%** |
| **known clean** | **25% · 16% · 18%** |

`python .prototypes/wolves/ground.py <name>...` runs the fixture first and then screens the names.
⚠ **Six images set the 40% line. It is a screen, not a proof** — anything it clears still gets looked at.

## The other scripts

| File | What it does |
|---|---|
| `install.py` | writes the winner into `assets/beast/wolf_h/`, **mapping the generator's compass words onto the game's screen directions** — they do not line up, and the mapping was made by looking |
| `fit.py` | puts a raw pull on the shipped wolf's canvas at the shipped ink width, so a comparison measures the drawing and not the frame |
| `palette.py` | the game's own colours: the written-down ones read from source, the lit-mesh ones measured off a real frame |
| `keep.py` | copies a round's pulls into `.candidates/wolf/` |
| `sheet2.py` | crops the shots and lays them out |
