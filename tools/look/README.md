# tools/look — the game screenshots itself

**This is verify-look without the bridge.** `CLAUDE.md` says in one line that "without the bridge the game
can `save_png()` itself" and nothing implemented it; `capture.gd` is that. Written 2026-08-15, when plan 3
needed looking at and there were **zero `godot-mcp` node processes** on the machine to grab 6550 with.

```
.\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture.gd -- <output-dir>
```

Seven PNGs, about fifteen seconds, and it quits on its own.

## The three rules it exists to obey

- **Not `--headless`.** A headless run has no swapchain, `root.get_texture()` comes back blank, and every
  PNG is a black rectangle **with no error anywhere**. The net runner pumps real frames headless and
  `_draw()` genuinely runs — that is why a net can assert *arguments*. What headless cannot do is hand back
  *pixels*.
- **It never takes the user's mouse or keyboard.** Every input goes through `root.push_input()`, inside the
  engine. No Win32, no key injection, no OS screen capture — the rule `agents/verify-look.md` is built
  around. A window does open and hold focus while it runs, which is why nothing in it ever waits for a
  person and why it quits itself.
- **`RenderingServer.frame_post_draw` before every read.** `root.get_texture()` at any other moment hands
  back the PREVIOUS frame, so a shot taken right after a state change photographs the state *before* it —
  silently, and it looks like the change never landed.

## The trap it walked into first, which is the point of this file

The close-up shot set `main.cam.zoom` and got a picture **at play scale**. `_apply_zoom()` runs every frame
in PLAY and rewrites `cam.zoom` from the shell's own `_zoom`, so the camera was undone before the shot.
Nothing errored. The one frame that existed to answer *"did the body visibly become a horse"* came back
unable to answer it, and read exactly like a zoom that had no effect.

⇒ **A capture harness is an instrument, and `CLAUDE.md`'s rule about inverting the instrument rather than
the subject applies to it too.** Take one shot you already know the answer to before trusting the rest.

## What it is not

It cannot judge. It produces frames; a person or an agent looks at them, and **only the conclusions leave**
— a captured frame stays in a conversation forever, which is the whole reason `verify-look` is a separate
agent. Do not hand the PNGs around. Write down what was and was not visible.

Frames land wherever the argument points. Nothing is written into the repo.
