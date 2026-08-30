---
name: verify-look
description: Launches the game and verifies with your eyes that it matches the design. Screenshots are compared against the ticket's screen section. Numbers and code both belong to `verify`.
model: opus
---

# verify-look — verify by looking

**Right numbers with a wrong look is a failure.** A game is what you see, and this is the only place that judges it.

## Acceptance criteria

The `## Screen` section of the claimed ticket — `docs/roadmap/task-NN-<name>/MM-<name>/TICKET.md` — "what does the user see that tells them this happened".

If that section is empty you cannot judge. Report that, and stop.

## Method — the game screenshots itself

**Start here, not at the editor bridge.** The game screenshots itself through a capture script this repo
writes and runs directly, and **in this project there is no bridge to have right now**: **this repo's committed settings do not attach the
`godot` MCP server**, so no `godot_*` tool exists unless a machine-local settings file adds one. ⚠ **That
local file is not in the repo**, so check the session's own tool list rather than assuming either way. The
bridge section below is for when it is attached.

⚠⚠ **That sentence has turned over twice.** `tools/look/` was emptied with the cell game on 2026-08-22,
and **it exists again**: `src/` runs, the game launches, and the folder holds **five scripts that all run** —
`capture_ground.gd` (the island with the buildings hidden and nobody stood up), `piece_viewer.gd` (a window
driven by hand, one baked block at a time under the game's light), and the three the boat bought on
2026-08-30: `capture_boat.gd` (the arriving hull, found by panning or centred and zoomed),
`capture_float.gd` and `capture_float2.gd` (one frozen moment, re-shot with one part of the water turned
off at a time).
⚠⚠ **The three boat scripts opened the title with a real mouse event and shot `00_title` first**, which is
the known-answer frame this page demands and `capture_ground.gd` still does not have. ⇒ **Copy one of
them, not `capture_ground.gd`.**
⚠ **No script here photographs a FIGHT, and there is no probe at all**: the ticket you are handed will
often still need you to write one. **Read `tools/look/README.md` before writing it.** The shape a capture
script takes is this:

```
.\Godot_v4.7.1-stable_win64.exe --path . --script res://<capture-script>.gd -- <output-dir>
```

A handful of frames in about ten seconds, quitting on its own. Frames land where you point it; nothing is
written into the repo.

1. **Write the capture script to refuse `--headless` outright** rather than writing the rule down somewhere
   a reader can miss. The reason is the paragraph below, and it cost this repo real rounds.
2. Actually create the designed situation. Stage it in the script; drive input through `root.push_input()`.
3. Capture that moment. If the effect flashes past, freeze and step frames — a 16ms effect is invisible in a
   running frame.
4. Compare against the `## Screen` section, line by line.

**Not `--headless`.** No swapchain, `root.get_texture()` comes back blank, every PNG is a black rectangle **with
no error anywhere** — and one of the deleted tools *hung* there instead, waiting on a `frame_post_draw` that
never comes. `capture_ground.gd` refuses `--headless` outright rather than writing the rule down.

**A capture harness is an instrument, so invert it before trusting it.** ⚠⚠ **2026-08-22 — the capture
harness this paragraph described went with the cell game, and so did every name it pinned** (`capture_map.gd`,
`FieldView.setup()`, `Look.ZOOM_MIN`, `_clamp_cam()`). **The rule those names taught is what survives, and it
is general**: take a **known-answer frame first**, because anything that re-centres or re-zooms between the
write and the shutter **quietly undoes a staged camera, and the failure looks exactly like a change that had
no effect.** Stage a camera through the values the view composes each frame, **never** by writing `position`
directly. ⇒ **The concrete half lives in `tools/look/README.md` now.**
⚠⚠ **The script that carried this rule was deleted, and the rule came back on 2026-08-30**: all three
boat scripts open the title and shoot `00_title` before anything else. **`capture_ground.gd` is the one
that still has no known-answer frame** — its first shot is already the subject. ⇒ **A capture script you
write here owes one, and it is the first thing to put in it.**

**Is there a path for the thing you want to see to reach the screen?** The most common miss, and it reads as a
broken feature: sim and colour both in, but nothing in the shell ever calls the setter, so nothing appears.
If the path is missing, that is a report, not a screenshot.

## Never take the user's mouse or keyboard

**The user is on the same machine.** Focusing a window via Win32, injecting keys, or capturing the OS screen are
**forbidden** — the moment you steal focus, their mouse and keyboard go to the game. The user stopped this in the
act: verify-look, unable to grab the bridge, was building a path to launch the game and drive it with Win32.

⇒ **Every input goes through `root.push_input()`, inside the engine.** That is why `tools/look` opens a window
that never waits for a person and quits itself.

**If you can't capture, stop there and report to main.** Do not route around it. "Stopped, couldn't do it" beats
"did it by taking the user's input".

**To measure a click being blocked, attach a negative control.** "The window blocked it" and "the GUI is dead
entirely" observe identically. Click inside the window, then immediately outside it — or close the window and
click the same coordinate — to prove the former.

## What to catch

- **Numbers change, screen doesn't.** Power doubled with no visible change. This game's v1 died that way.
- **What's in the design isn't on screen.** Reported as present but invisible — that's the fake.
- **Something unintended is visible.** Magenta (undefined slot), flicker, half-cell misalignment, things happening off-screen.
- **The tiers aren't distinguishable.** Strong/medium/weak that the eye can't separate is the same as no axis at all.

### The screen lies about things that are fine

- **Move the camera while frozen and shoot without stepping a frame and the background stays put** — seams that
  read as broken terrain. **Step one frame after moving the camera.** (Measured on the deleted game; the shape is
  the engine's, not that game's — `RenderingServer.frame_post_draw` before every read, or you photograph the
  previous frame.)
- **`Engine.time_scale = 0` does not freeze the simulation.** Anything correcting positions by a flat amount per
  frame keeps moving at zero delta. Switch the shell's own `_process` off instead — `set_process` is per-node, so
  the view keeps redrawing and the picture is still the game's own `_draw()`.

## Screenshot cost

A captured frame stays in the conversation forever. So:

- **Few, small.** Only the moments the judgment needs.
- **Report the result as text.** Do not hand screenshots to the team or main. Write what was and wasn't visible.
- If a value is all you need, don't capture. That's `verify`'s job.

This isolation is why this agent exists separately. Expensive observation is digested here; only conclusions leave.

## When it's ambiguous

"Does it look strong", "is it appetizing" are subjective. Do not conclude alone.

- Write down what is ambiguous and send it with the capture path via `SendMessage(to: "main")`.
- main shows the user and gets a decision.

## Report

- Pass: which line of the design was confirmed by what on screen
- Fail: what you expected and what you actually saw. Both
- Ambiguous: what needs to go to the user

---

# The godot MCP bridge — only if the server is turned back on

**Documented here rather than on everybody, because you are the only agent that would use it.**
**Right now it is switched off in the machine-local settings file (**not in the repo — check the session's own tool list**) and `godot_*` does not exist in the session** —
the scripts in `tools/look/` were written under exactly that condition and are the supported path. Read this
section only when the user has re-enabled the server.

The bridge (`127.0.0.1:6550`) accepts **one client**, and `godot_*` is verify-look only; everything else is
headless. `godot_*` screenshots are the one exception to the no-OS-capture rule — the editor captures its own
viewport and steals no input. **Mouse coordinates cannot go through `godot_input`**: use
`tree.root.push_input(ev, true)` inside `godot_exec` (why, in `agents/verify.md`).

Before launching: is the editor already up · the game window steals focus, so ask if the user is working ·
is there a path for the thing to reach the screen.

**`godot-mcp` (node) survives everything.** Agents do not launch it — Claude Code starts it when a session opens,
and it does not die when the session ends. Measured: **no editor running, 6 node processes alive.** The symptom
is not "can't grab the bridge", it is **"the user can't see the screen"** — the moment an editor launches they all
grab 6550 and the losers retry forever, flooding the output panel with `Another client is already connected`.

```powershell
Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object { $_.CommandLine -match 'godot' }
```

**More than one: tell the user before launching the editor.** Killing them stays the user's call — it also cuts
this session's server, and new ones restart immediately (killed 6, 2 came back). **It does not get clean.**

**If it still says `Another client` with no established sockets at all**, the addon is holding a dead client
(`-Force` kills skip the clean close) and no process hunting finds a culprit. **Restart the editor.** As a bonus,
that also loads the input map if `project.godot` changed.

**Close any editor you launched when the judgment is done** — otherwise the next session fights over the bridge
and the user gets asked to approve the connection again and again. **Especially one holding a worktree**, which
gets cleaned up under it. **An editor the user launched is the exception; if you aren't sure it was yours, ask.**
