---
name: verify-run
description: Verifies by actually running. Launches the game and observes values to confirm it really works. Reading code belongs to verify-read.
---

# verify-run — verify by running

**Never look at what the code says. Only at what happens when it runs.**

## Acceptance criteria

The `## Acceptance` section of `docs/plans/2.active/<name>.md`. Observe what is written there, for real.

An empty acceptance section, or one written so it can't be observed, **is itself a failure.** Send it back to spec.

## What to catch

Failure in this repo is usually silent. So "no error" is not grounds for a pass.

- **Screen changes, sim doesn't** (or the reverse). Observe both separately.
- **Nothing happens at all.** Bypass the command gate and it is silently ignored, without error.
- **Numbers change, screen doesn't.** Power went up with no visible change — that's a failure.
- **Cost isn't zero at rest.** Nothing moving but active chunks remaining means performance collapses soon.

## How to observe — headless only

**No `godot_*` MCP tools** — reason is in `CLAUDE.md` under "godot MCP". Launch the game directly with
`Godot_*.exe --headless --script` (same as `tests/run_nets.ps1`). That script prints the values.

### Measuring a click headless requires `in_local_coords = true`

`root.push_input(ev)` **does not go through the GUI pipeline.** The headless window is 64×64 while
`visible_rect` is 960×960, so the non-local path mangles coordinates — `_gui_input` runs 0 times and
`gui_get_hovered_control()` is always null.

**Then every click leaks through to firing and reads as "the window doesn't block clicks".** That misreading
happened. Only a positive control (click inside a `STOP` Control I built) plus a negative control (click where
no Control exists) exposed it as a harness problem — both leaked identically.

`root.push_input(ev, true)` is the right call. `Input.parse_input_event(ev)` also skips the GUI.

**Measure a click as "did the command queue grow within that frame".** Independent of tick timing, so repeats don't wobble.

**Always attach a negative control.** "The window blocked it" and "the GUI is dead entirely" observe identically.
Clicking over an `IGNORE` Control and seeing the shot fire is what proves the former.

### The runner cannot measure parse errors in `src/`. Always run through the wrapper and read the last line

**`load()` returns a non-null object even on parse failure.** So `net_layers`' "it loads" **passes on a broken file.**
Confirmed by controlled experiment — `circle_window.gd` was fully broken and the runner printed:

```
o circle_window.gd loads          ← parse-failed file, passes
[net] 959 passed                  ← identical to clean. 0 failures
```

**The only thing that caught it was the wrapper's stderr check.** Warm cache or cold, it caught it on the first
run, and "green only on the first run" never occurred in 6/6.

⇒ **Do not read "N passed" as green.** The `[wrapper]` line below it is the verdict. And this is **not the kind
of thing repeated runs catch** — it looks green identically every time.

**And a check whose scene fails to build doesn't fail — it disappears.** `net_render`'s scene checks bail out via
`if scene == null: return`, so the pass count drops and nobody barks. A **drop** in the pass count is a signal too —
don't watch only for increases.

### Pin down that the tree didn't move during measurement, with a hash

builder and the verifiers run in parallel on this team. **If the repo changes while you observe, the result is void** —
it happened repeatedly. Hash immediately before and after; proving you measured one revision is part of the observation.

**Do not hold a fixed file list. Hash the directory recursively.** A **new file** isn't in the list, so a tree that
really did change reads as "unchanged". Measured: builder added one new file and the hash check answered "stable".

**If nets suddenly go red, suspect a new file first.** `net_layers` scans `src/` recursively and auto-parses new files.
A half-written file referencing a constant that doesn't exist yet throws a parse error the moment it lands.
**Pass count up by 3 per file is the evidence** — it's not your change, someone else is mid-work.

- **Do not take screenshots.** How it looks is verify-look's job. Numbers only.
- **You cannot measure aspect ratio.** Headless `visible_rect` is 960×960, a different ratio from the real window (960×540). "How much of the stage the window covers" is verify-look's.
- **Render cost (FPS) is impossible to measure headless, in principle.** Not yours — report that you couldn't and hand it to verify-look.
- **Never take the user's mouse or keyboard.** Focusing a window or injecting keys is forbidden. The user is on the same machine.

## Report

Pass or fail, write **what you observed and how.**

- Pass: observed value and expected value
- Fail: what happened and what didn't. Guess at a cause, but don't assert one

**Never write just "confirmed".** A pass with no record of what you saw is not a pass.
