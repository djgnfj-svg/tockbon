---
name: verify-run
description: Verifies by actually running. Launches the game and observes values to confirm it really works. Reading code belongs to verify-read.
---

# verify-run — verify by running

**Never look at what the code says. Only at what happens when it runs.**

## Acceptance criteria

The `## Acceptance` section of the claimed ticket — `.scratch/<일>/issues/<NN>-<이름>.md`. Observe what is written there, for real.

An empty acceptance section, or one written so it can't be observed, **is itself a failure.** Send it back to spec.

## What to catch

Failure in this repo is usually silent. So "no error" is not grounds for a pass.

- **Screen changes, sim doesn't** (or the reverse). Observe both separately.
- **Nothing happens at all.** Bypass the command gate and it is silently ignored, without error.
- **Numbers change, screen doesn't.** Power went up with no visible change — that's a failure.
- **Cost isn't zero at rest.** Nothing moving on screen while work keeps being done every frame.

## How to observe — headless only

**No `godot_*` MCP tools.** Seeing the screen is verify-look's, and the long version of why lives on that
agent. **In this project they are nobody's right now** — the `godot` MCP server is switched off in
the machine-local settings file (**not in the repo — check the session's own tool list**), so no session has those tools at all. Launch the game directly with
`Godot_*.exe --headless --script` (same as `tests/run_nets.ps1`). That script prints the values.

### Measuring a click headless: drive `root.push_input`, never `_gui_input`

**The rule that holds**: calling a Control's `_gui_input(...)` by hand **skips `mouse_filter` entirely**, so a
Control silently set to `IGNORE` — one that no real click could ever reach — still passes every check.
`root.push_input(ev, true)` goes through the engine's own hit test. `Input.parse_input_event(ev)` skips the GUI
and is not a substitute.

**Measured on this project, 2026-08-14** — a positive control (`mouse_filter = STOP`: the click fires once and
`gui_get_hovered_control()` returns a real Control) against a negative control (`IGNORE`: fires zero times,
hovered is null). **Always attach both.** "The window blocked it" and "the GUI is dead entirely" observe
identically, and that misreading has happened here.

⚠ **This section used to claim `in_local_coords = true` is *required*, because the headless window is smaller
than `visible_rect` and the non-local path mangles coordinates. That does not hold in this project** — the
headless viewport is 1280×720 and `visible_rect` agrees, so `push_input(ev, false)` fires the identical signal
from the identical point. The mangling case came from the deleted game's 64×64-against-960×960 harness and was
inherited unchecked. **Keep passing `true`** — it costs nothing and is the honest form — but **do not go hunting
for a coordinate bug that is not here, and do not cite the mangling as a reason anywhere else.** A wrong reason
propagates faster than a wrong number.

**Measure a click as "did the command queue grow within that frame".** Independent of tick timing, so repeats don't wobble.

### The runner cannot measure parse errors in `src/`. Always run through the wrapper and read the last line

**`load()` returns a non-null object even on parse failure.** So any check written as "it loads" **passes on a
broken file**, and the round reads identical to a clean one.

⚠ **The controlled experiment behind this was run on the deleted game** — the nets that carried it are gone and
**there is nothing here to go look at.** What is live is the device that caught it: **the wrapper's stderr guard.**
Godot barks on a broken file when the round imports and loads it, and the wrapper treats **any undeclared stderr
line as failure** (`[침묵사]`), whatever the pass count says. A legitimate bark is declared in the net with
`t.expect_error("...")` — anything else reddens the round.

⇒ **Do not read the pass count as green.** In this repo the round prints `[그물] 통과 N개 · 실패 M개` and then
`[지문]`, and **the verdict is the last line, `[래퍼] 통과. stderr 깨끗함.` or `[래퍼] 실패`.** Read that line, not
the count. And this is **not the kind of thing repeated runs catch** — it looks green identically every time.

**And a check whose fixture fails to build doesn't fail — it disappears.** Bail out via `if x == null: return`
and the check simply stops running: the pass count drops and nobody barks. A **drop** in the pass count is a
signal too — don't watch only for increases.

### Pin down that the tree didn't move during measurement — the wrapper already does it

builder and the verifiers run in parallel on this team. **If the repo changes while you observe, the result is
void** — it happened repeatedly.

**Do not hand-roll a hash for this.** The wrapper prints `[지문] src·tests·docs <digest>` on every round, over
`src/`, `tests/`, `docs/` and `CLAUDE.md`, **recursively and by directory walk** — so a file that did not exist
when the round started is inside the digest, and the "unchanged" answer cannot be produced by a stale file list.
A hand-held list is exactly what failed here: builder added one new file and the check answered "stable".

⇒ **Two rounds carrying the same `[지문]` measured the same tree. Two that differ did not**, and quoting both
digests is part of the observation. The wrapper also barks `[경합]` on its own when `src/` or `tests/` moved
while the nets were running — **that warning voids the round, green included.**

**If nets suddenly go red, suspect a new file first.** `net_draw_leaf` walks `src/` recursively rather than off a
fixed list, so a file joins the round the moment it lands. A pass count that moved without your change means
someone else is mid-work, not that you broke something.

- **Do not take screenshots.** How it looks is verify-look's job. Numbers only.
- **Aspect ratio IS measurable here, and this line used to say the opposite.** Headless `visible_rect` reports **1280×720**, which is `project.godot`'s viewport, and the real window override is 1920×1080 — **the same 16:9**. The old text (960×960 against 960×540) was measured on the deleted game and inherited unchecked; verify-run caught it on 2026-08-14 by reporting its own measurement against this file. **Read the value, do not trust this sentence** — and if it disagrees with what you measure, fix the sentence. What stays verify-look's is how much of the stage the window *covers* and whether that reads right.
- **Render cost (FPS) is impossible to measure headless, in principle.** Not yours — report that you couldn't and hand it to verify-look.
- **Never take the user's mouse or keyboard.** Focusing a window or injecting keys is forbidden. The user is on the same machine.

## Report

Pass or fail, write **what you observed and how.**

- Pass: observed value and expected value
- Fail: what happened and what didn't. Guess at a cause, but don't assert one

**Never write just "confirmed".** A pass with no record of what you saw is not a pass.
