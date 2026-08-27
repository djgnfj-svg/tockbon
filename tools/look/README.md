# tools/look — the game screenshots itself

**This is verify-look without the bridge.** Three scripts live in this folder and **all three run**:

| Script | Reads pixels? | The one question it answers |
|---|---|---|
| `piece_viewer.gd` | on `S` and `--shot1` | **what does one baked block look like under the GAME's light?** Driven by hand: a window, one piece at a time, turn it, tilt it, outline on and off |
| `capture_refit.gd` | yes | what the reward pick and the refit board actually look like — fourteen frames |
| `probe_refit_hits.gd` | no | on the refit screen the slot strip and the board's cells share pixels; which one does a press reach? |

⚠⚠ **`piece_viewer.gd` is the answer to 「블록 하나하나를 내가 보고 싶어」** (2026-08-27, the user). It
exists because a piece shown under BLENDER's light lies: ticket 01 records over and over that a value
which reads correctly there goes wrong in the game. (`one_piece.py`, the Blender-side viewer it was
written against, was deleted 2026-08-27.) **Its sun, ambient, camera and outline
pass are copied from `field_view.gd` line for line** — retuning any of them makes it lie.

⚠⚠ **Everything this file used to describe is gone.** `capture.gd`, `capture_bodies.gd`, `capture_map.gd`,
`capture_landing.gd` and `probe_run.gd` drove the two dead games and were deleted with them, and their
sections sat here afterwards documenting **zero runnable scripts**. The rule for that is written in the
prose those sections themselves carried: **a thing whose subject is dead is distilled and deleted, not
archived in place.** What they measured that still binds is the four rules below; the rest is gone.

⚠ `capture_refit.gd`'s header sends the reader to `capture_map.gd` for "the same three measured rules its
header states", and `probe_refit_hits.gd`'s header cites `probe_run.gd`'s argument for headless.
**Both of those files are deleted — the rules they name are the ones on this page.**

## Running the three

```
.\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/piece_viewer.gd
.\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/piece_viewer.gd -- --glb res://assets/terrain/island.glb
.\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_refit.gd -- <output-dir>
.\Godot_v4.7.1-stable_win64.exe --headless --path . --script res://tools/look/probe_refit_hits.gd
```

**The viewer's hand**: `← →` the piece · `Tab` one / all ten · **left-drag pan** · `H` re-centre ·
right-drag or `Q E` turn · `R F` tilt · wheel zoom · `O` outline · `G` sea · `S` save · `Esc` quit.
**Flags**: `--glb <path>` · `--at X,Z` · `--zoom N` · `--shot1` (this aim, three yaws, then quit). **Not
`--headless`** — there is nothing to look at.
⚠ **`--shot` was deleted 2026-08-27.** It walked EVERY mesh in the loaded glb and shot each one twice,
which made sense against `pieces.glb` and its ten blocks; the live target `island.glb` holds exactly one
mesh, so the mode had degenerated to photographing one piece twice and calling it a row. **What it knew
is recorded in the viewer itself** — why the second shot turns the sea off, and why two angles exist. Shots land in `tools/shot/out/pieces/`, which sits behind a `.gdignore`.

Fourteen PNGs from `capture_refit.gd`, in about ten seconds, and it quits on its own.
`probe_refit_hits.gd` prints rows and reads no pixels at all.

## The three rules a capture script here obeys

- **Not `--headless`.** A headless run has no swapchain, `root.get_texture()` comes back blank, and every
  PNG is a black rectangle **with no error anywhere**. Worse than blank: the dummy renderer never emits
  `RenderingServer.frame_post_draw`, so the first shot waits for a draw that will never happen and the
  tool **hangs**. `capture_refit.gd` refuses `DisplayServer.get_name() == "headless"` outright rather than
  writing the rule down. The net runner pumps real frames headless and `_draw()` genuinely runs — that is
  why a net can assert *arguments*. What headless cannot do is hand back *pixels*.
- **It never takes the user's mouse or keyboard.** Every input is an `InputEvent` built in the script and
  handed to `game._unhandled_input` inside the engine. No Win32, no key injection, no OS screen capture —
  the rule the `verify-look` agent is built around. A window does open and hold focus while it runs, which
  is why nothing in it ever waits for a person and why it quits itself.
- **`RenderingServer.frame_post_draw` before every read.** `root.get_texture()` at any other moment hands
  back the PREVIOUS frame, so a shot taken right after a state change photographs the state *before* it —
  silently, and it looks like the change never landed.

**Headless is correct for a probe and the first two rules do not apply to one**: nothing reads a pixel, so
there is no swapchain to need and no window to steal.

## The fourth rule, and it is why this file exists

⚠⚠ **Take one shot you already know the answer to, before trusting any of the rest.**

The trap that bought this rule: a close-up shot set the camera's zoom by hand and got a picture **at play
scale**, because the shell rewrites the camera from its own state every frame — the staging was undone
between the write and the shutter. Nothing errored. The one frame that existed to answer a question came
back unable to answer it, and read exactly like a zoom that had no effect.

⇒ **A capture harness is an instrument, and `CLAUDE.md`'s rule about inverting the instrument rather than
the subject applies to it too.** `capture_refit.gd` shoots `00_title` first — a screen this repo has
already looked at — for exactly this. **If that frame is wrong, every frame after it is unreadable**, and
the failure looks exactly like a stage that had no effect.

## Two staging rules that made the frames honest

- **The shell's `_process` is switched off** (`game.set_process(false)`), so the simulation cannot walk
  between shots and a survey frame photographs a state rather than a fight. `Node.set_process` is
  per-node, so each view keeps its own `_process`, keeps redrawing, and the picture is still the game's
  own `_draw()`.
- ⚠ **`await process_frame` after `add_child` is not optional.** A child added during `_initialize` has not
  run `_ready` yet, so every view on the shell is still `null` and each press faults instead of routing —
  measured, and it reads exactly like a dead input table.

## What it is not

It cannot judge. It produces frames; a person or an agent looks at them, and **only the conclusions leave**
— a captured frame stays in a conversation forever, which is the whole reason `verify-look` is a separate
agent. Do not hand the PNGs around. Write down what was and was not visible.

Frames land wherever the argument points. Nothing is written into the repo.
