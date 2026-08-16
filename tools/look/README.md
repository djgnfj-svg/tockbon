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

## `capture_bodies.gd` — the second one, and why it is a second one

`capture.gd`'s seven shots are one body: bare, worn, close, its internal slots, the panel, a card, the
ending. **Not one of them is a crowd**, and a crowd is the whole subject of `melee-legibility-ko`'s fork —
so that file was left alone and this one joins it.

```
.\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_bodies.gd -- <dir> <fill|line|rim>
```

Nine staged scenes, one candidate per process, into `<dir>/<style>/`. Same names in every folder, so
`fill/03_host_in_pile.png` pairs with `line/03_host_in_pile.png` with nothing to look up.

Three things it measured that the file above did not know:

- **`Engine.time_scale = 0` does NOT freeze the simulation.** `Swarm._separate()` corrects positions by a
  flat `Rules.SEPARATION_MIN` on every frame it runs whatever the delta is, so a staged pile spreads a
  little before the shutter; and `World._contact()` fires on `atk_cd == 0.0`, which every freshly added
  clone opens at, so the first stepped frame lands a hit nobody staged — and at zero delta the flash it
  writes never turns off again. The shell's own `_process` is switched off instead. `Node.set_process` is
  per-node, so `FieldView` keeps redrawing and the picture is still the game's own `_draw()`.
- **`--headless` does not merely come back black here — it hangs.** The dummy renderer never emits
  `RenderingServer.frame_post_draw`, so the first shot waits for a draw that will never happen. The tool
  now refuses `DisplayServer.get_name() == "headless"` outright rather than writing the rule down.
- **A known-answer shot taken at the host's own start point proves nothing about the camera's position.**
  `main._bind_world()` leaves `_cam_base` exactly there, so deleting the tool's own `_cam_base` write still
  lands the picture correctly. Measured — the first version of the shot did that. It is staged off-centre
  now, and deleting that write reddens it.

## `capture_bodies.gd --  <dir> <style> push` — the same file, frame SEQUENCES

```
.\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_bodies.gd -- <dir> <style> push
```

The nine scenes above are stills, and **a still cannot photograph a push**: a body resting at a creature's
surface and a body that was never inside it produce the identical frame. `push` advances the simulation and
shoots every few frames instead — five sequences (host into a lion · forty clones rallied with `1` · the
arena summon · a horse herded · one at play zoom), 92 frames, `<dir>/<style>/<sequence>/NN.png`.

Three things it added, each of which the still mode does not need and would be wrong to inherit:

- **The shell's `_process` stays off and `_tick()` calls the shell's own functions in the shell's own order.**
  `main._read_input()` is the one that is skipped, because it polls the real `Input` singleton — a window
  holding focus while a person types would put their hands in the picture. `host_input` is written directly
  and every command goes to the `Swarm` function the key would have reached.
- **`FieldView._process` and `Hud._process` come off the engine's clock too, and are called by hand with the
  SIM's dt.** They consume one-frame lists that `World.begin_frame()` clears, so on the engine's clock they
  append the same death burst once per RENDERED frame — and a shot costs several of those.
- **`host_grace` is topped up every frame in every sequence.** It suppresses exactly two things — the host's
  hp and the knockback `Swarm.damage()` applies — and both are a SECOND force moving the host in a picture
  that is about separation. The camera shake rides on the same hit and would move every body on the frame
  together.

⚠ **Two stagings that read as obvious were measured wrong, and the numbers are in the file.** A horse driven
at a parked wall of clones never reaches it — it flees the NEAREST body and it out-runs the host, so the wall
becomes nearer than the player long before contact and it turns away every time. **That is the design
working**, and photographing a horse actually stopped needs the swarm sent at it. And run at the field's
centre in this seed the horse crossed a pond, where `Rules.WATER_SLOW` cut it to 60% for most of the
sequence; the corridor is scanned for clear ground now rather than written down.

## `probe_run.gd` — the third one, and it reads no pixels at all

```
.\Godot_v4.7.1-stable_win64.exe --headless --path . --script res://tools/look/probe_run.gd
.\Godot_v4.7.1-stable_win64.exe ... res://tools/look/probe_run.gd -- seed=123 attempts=10
.\Godot_v4.7.1-stable_win64.exe ... res://tools/look/probe_run.gd -- check
```

`probe_field.gd` measures the opening FRAME. This one **plays the whole run** — the real shell, the title's
own `start_pressed`, then a scripted stick until the host is dead or `Rules.BOSS_HUNT_AT` has passed — and
prints a row every fifteen simulated seconds plus a four-number verdict: reached the boss alive · times
died · seconds with nothing killable on screen · longest gap between kills.

**Headless is correct here and the two rules above do not apply**: nothing reads a pixel, so there is no
swapchain to need and no window to steal. It quits itself.

Three things it measured:

- **The screen is 800x450 WORLD pixels, not 1920x1080.** `project.godot` stretches a 1280x720 viewport into
  a 1920x1080 window (`canvas_items`), and `Look.ZOOM_NEAR` is 1.6 — so `probe_field.gd`'s `SCREEN`
  constant names a box **5.76x too large in area**. That file is deliberately unchanged; this one prints
  both at boot so the difference cannot be inherited quietly.
- **A control is not a control until the staged field survives the game's own spawner.** `World._spawn_critter()`
  keeps arriving every `CRITTER_INTERVAL`, so a control written as *"if the field is empty, place one"* is
  never empty again after the first arrival and quietly measures the ordinary field with a head start.
- **The positive control cannot be a species that hits back.** Written with crows, four counters took the
  opening host to 9 hp; `Rules.HP_PER_LEVEL` gives 3 back per level and **nothing else in the build heals**,
  so from then on a force-10 crow read as a one-shot threat and the policy fled every crow for the rest of
  the run. The instrument was right and the control was wrong — it is a 다람쥐 now, which flees and
  therefore never retaliates.

⚠ **`-- check` is the instrument inverting itself, in BOTH directions.** An empty field must come back
진행 불가 (surviving nothing is not playing), a ring of eight lions must come back 죽었다, and one squirrel
at a time must come back 진행 가능. A probe that can only ever say 「못 한다」 passes the first two.

## What it is not

It cannot judge. It produces frames; a person or an agent looks at them, and **only the conclusions leave**
— a captured frame stays in a conversation forever, which is the whole reason `verify-look` is a separate
agent. Do not hand the PNGs around. Write down what was and was not visible.

Frames land wherever the argument points. Nothing is written into the repo.
