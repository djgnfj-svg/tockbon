# tools/look — the game screenshots itself

**This is verify-look without the bridge.** Five scripts live in this folder and **all five run**:

| Script | Reads pixels? | The one question it answers |
|---|---|---|
| `piece_viewer.gd` | on `S` and `--shot1` | **what does one baked block look like under the GAME's light?** Driven by hand: a window, one piece at a time, turn it, tilt it, outline on and off |
| `capture_ground.gd` | yes | **what does the ground actually look like?** Two frames — the island, the sea and the mats, with the buildings hidden and nobody stood up |
| `capture_boat.gd` | yes | **where is the arriving hull, and what does it look like up close?** Opens the title, presses 시작하기 through a real mouse event, then `find` (scan with the pan keys) or `close` (centre one and zoom in) |
| `capture_float.gd` | yes | **what makes the boat read as floating?** One frozen moment, shot once with everything on and then once per part removed — the part that takes the floating with it is the answer |
| `capture_float2.gd` | yes | **which white mark stands off the hull?** The water draws four things about a boat — halo, contact shadow, break line, trail — and this turns them off one at a time |

⚠⚠ **The last three were written on 2026-08-30 for the boat and they are one-off sheets by shape**, not
standing instruments: each stages one framing and answers one question. **Read one before writing a sixth**
— `capture_boat.gd` is the closest thing here to a template, because it opens the game the way a player
does and shoots a known-answer frame first.

⚠⚠ **`piece_viewer.gd` is the answer to 「블록 하나하나를 내가 보고 싶어」** (2026-08-27, the user). It
exists because a piece shown under BLENDER's light lies: ticket 01 records over and over that a value
which reads correctly there goes wrong in the game. (`one_piece.py`, the Blender-side viewer it was
written against, was deleted 2026-08-27.) **Its sun, ambient, camera and outline
pass are copied from `field_view.gd` line for line** — retuning any of them makes it lie.

⚠⚠ **`capture_ground.gd` HIDES, it does not delete.** The keep and the scatter go invisible and every
body goes back to `RESERVE` off the map; nothing it does changes what the game builds. **A frame that
removed the keep from the board would be a picture of an island this game does not have.**

⚠⚠ **Everything else this file used to describe is gone.** `capture.gd`, `capture_bodies.gd`,
`capture_map.gd`, `capture_landing.gd` and `probe_run.gd` drove the two dead games and were deleted with
them. **`capture_refit.gd` and `probe_refit_hits.gd` went the same way on 2026-08-29**, when the reward
pick and the refit screens they photographed were deleted — and **this page went on documenting both for
a commit afterwards**, run commands included, which is the exact failure the paragraph below names. The
rule is written in the prose those sections themselves carried: **a thing whose subject is dead is
distilled and deleted, not archived in place.** What they measured that still binds is the four rules
below; the rest is gone.

## Running them

```
.\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/piece_viewer.gd
.\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/piece_viewer.gd -- --glb res://assets/terrain/island.glb
.\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_ground.gd -- <output-dir>
.\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_boat.gd -- <output-dir> find
.\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_boat.gd -- <output-dir> close
.\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_float.gd -- <output-dir>
.\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_float2.gd -- <output-dir>
```

**The viewer's hand**: `← →` the piece · `Tab` one / all ten · **left-drag pan** · `H` re-centre ·
right-drag or `Q E` turn · `R F` tilt · wheel zoom · `O` outline · `G` sea · `S` save · `Esc` quit.
**Flags**: `--glb <path>` · `--at X,Z` · `--zoom N` · `--shot1` (this aim, three yaws, then quit). **Not
`--headless`** — there is nothing to look at.
⚠ **`--shot` was deleted 2026-08-27.** It walked EVERY mesh in the loaded glb and shot each one twice,
which made sense against `pieces.glb` and its ten blocks; the live target `island.glb` holds exactly one
mesh, so the mode had degenerated to photographing one piece twice and calling it a row. **What it knew
is recorded in the viewer itself** — why the second shot turns the sea off, and why two angles exist. Shots land in `tools/shot/out/pieces/`, which sits behind a `.gdignore`.

Two PNGs from `capture_ground.gd` — the board, then the same board zoomed five steps in — and it quits
on its own.

## The three rules every capture script here obeys

- **Not `--headless`.** A headless run has no swapchain, `root.get_texture()` comes back blank, and every
  PNG is a black rectangle **with no error anywhere**. Worse than blank: the dummy renderer never emits
  `RenderingServer.frame_post_draw`, so the first shot waits for a draw that will never happen and the
  tool **hangs**. `capture_ground.gd` refuses `DisplayServer.get_name() == "headless"` outright rather
  than writing the rule down. The net runner pumps real frames headless and `_draw()` genuinely runs —
  that is why a net can assert *arguments*. What headless cannot do is hand back *pixels*.
  ⚠ **A probe is the exception and headless is correct for one**: it reads no pixel, so there is no
  swapchain to need and no window to steal. **No probe lives here today** — the last one was deleted
  with the refit screen.
- **It never takes the user's mouse or keyboard.** Any input a capture script needs is an `InputEvent`
  built in the script and handed to the engine — no Win32, no key injection, no OS screen capture, which
  is the rule the `verify-look` agent is built around. ⚠ **`capture_ground.gd` sends no input at all**;
  it stages by calling the shell's own methods. **`piece_viewer.gd` is the deliberate opposite** — it
  reads the user's real keys through `root.window_input`, because a hand is the whole point of it.
  A window does open and hold focus while a capture runs, which is why nothing in one ever waits for a
  person and why it quits itself.
- **`RenderingServer.frame_post_draw` before every read.** `root.get_texture()` at any other moment hands
  back the PREVIOUS frame, so a shot taken right after a state change photographs the state *before* it —
  silently, and it looks like the change never landed.

## The fourth rule, and it is why this file exists

⚠⚠ **Take one shot you already know the answer to, before trusting any of the rest.**

The trap that bought this rule: a close-up shot set the camera's zoom by hand and got a picture **at play
scale**, because the shell rewrites the camera from its own state every frame — the staging was undone
between the write and the shutter. Nothing errored. The one frame that existed to answer a question came
back unable to answer it, and read exactly like a zoom that had no effect.

⇒ **A capture harness is an instrument, and `CLAUDE.md`'s rule about inverting the instrument rather than
the subject applies to it too.** The script that carried this rule was `capture_refit.gd`, which shot
`00_title` first — a screen this repo had already looked at — for exactly this reason.
⚠⚠ **It is deleted, and the rule came back on 2026-08-30**: `capture_boat.gd`, `capture_float.gd` and
`capture_float2.gd` all shoot `00_title` first — a screen this repo has looked at many times — before they
touch their subject. **`capture_ground.gd` is the one still without one**: its first frame is the island at
play scale, which is the nearest thing to a known answer it has, but it is the subject and the check at
once, and **if it is wrong the second frame is unreadable** in exactly the way this paragraph describes.

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
