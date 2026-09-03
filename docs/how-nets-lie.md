# How nets lie — the shapes a false green comes in

**Read this before writing a check, and before believing a green round.** Every line below is a shape that
was measured in this repo or in the two games before it. **No case histories, no dates** — the shape is the
whole of what carries forward.

⚠ **This file holds shapes, not incidents.** When a new shape is measured, add one line. When an incident
only re-proves a line already here, add nothing.

---

## No fake code

**Code that pretends to work is worse than code that doesn't.**

- Hardcoding for this input or this test only
- Returning a plausible value instead of computing one
- Reporting a stub as finished
- Swallowing an error so it looks like success
- **Screen changes but sim doesn't, or the reverse** — the signature fake

**If you can't do it, say you can't.**

⇒ **If this game ever runs a fixed timestep under its render loop, write the traps down as they are
measured.** Two clocks meeting cost more than anything else in the deleted game — five defects out of one
seam.

## No fake nets

**When the label claims more than the check measures, that green is a false guarantee.**

**Invert every new check.** An uninverted check proves "it runs", not "it measures". If the inversion
doesn't bite, suspect the check last — first confirm the mutation actually landed.

**Invert the instrument, not only the subject.** A check written to catch a defect has twice shipped
carrying that same defect. A new check needs a case that fails *it*, not only one that fails what it
points at.

**A truncated search is not a search.** `grep ... | head` silently drops the hit that matters and an empty
tail reads as an absence. **Count the hits before reading them**, and never conclude absence from a
truncated result.

### These survive even after every mutation goes red

- **A check that reads only final state cannot measure an ordering contract.** Add a check that measures
  the process
- **A/B comparison catches "diverged", never "vanished".** Fold two paths into one and `scan == scan` is
  green. "Slower without it" is caught only by timing
- **A loop whose condition is false from the start never runs the check at all.** Assert the iteration count
- **A check that greps a file measures its text, never what it computes.** Every text scan shipped here has
  been evaded — a decoy line, an added term, a declaration moved off `^var`, the same write from another
  file, an early `return`. **Drive the value instead.** `_ready()`, `_gui_input()`, `_physics_process()`,
  ordinary methods and **`_draw()`** are all callable on an untreed node. ⚠⚠ **"It can't be driven
  headless" has been claimed four times and was wrong four times.** Nothing in this engine resists headless
- **A spy on a hook sees the HOOK, never the native call inside it.** Argument capture proves a value was
  computed and handed on; it never proves the value was used. **Chase it to a leaf, then pin the leaf by
  counting `draw_*` calls per function**
- **"`_draw()` ran" is not "anything was drawn."** Godot refuses to override a native draw call, so cut a
  `_paint(...)`-shaped hook out of `_draw()`, override that, assert the arguments — and drive it treed with
  `pump_frames`
- **A spy that CAPTURES an argument no row ever reads is a hole with a lid on it.** It looks like coverage
  in review. **List the keys a spy stores and grep for a reader of each**, and read colour as CONTRAST
  against what it is drawn on, not only as a non-zero alpha
- **A bounding box of zero extent still returns the right centre.** When a check reads geometry back, read
  the EXTENT beside the position
- **Wiring a node by hand in the net hides the line that wires it in the shell.** Null the field back out
  before calling `_ready()`
- **A check whose bounds come from the thing it checks proves nothing.** Pin literal coordinates
- **Measuring a pure function is not measuring that anything calls it.** Capture the argument at the hook
  and assert it equals what the pure function returns. ⚠ **`net_draw_leaf._scan` skips any function with
  draw count 0** — build the points in `_draw()` and hand them to the leaf as an argument
- **`visible` is not "on screen", and neither is being wired.** `set_anchors_preset` leaves the offsets
  alone, so a `Control` on a bare `CanvasLayer` keeps `size == (0, 0)`. Assert size against the viewport
  and assert the laid-out rectangles land inside it
- **A ceiling with no floor passes an effect that never happens.** "never overlaps more than 6px" without
  "is not always zero" stays green when the whole animation is deleted. **Bound both ends, in the same row**
- **A tuning constant with a floor on one end and none on the other is half-measured.** One bite does not
  prove the range
- **The plan's own fix gets applied to one value and not to its siblings.** Re-measure the whole table, not
  the row someone is arguing about
- ⚠ **Mouse clicks cannot be driven through `root.push_input()` headless, and they fail silently.** The
  headless window is 64×64 so the stretch transform is 0.05, and a click aimed at a panel arrives thousands
  of pixels away with no error. Keys pass through fine, so half an input suite can be green while the other
  half is dead. ⇒ Call `game._unhandled_input(ev)` directly
- ⚠ **A `const` Array cannot be mutated at runtime**, so "zero this table entry and watch it redden" is not
  a mutation you can write. Drive the accessor instead
- ⚠⚠ **A HAND-WRITTEN TABLE ROW CAN PIN AN INPUT THE SIMULATION CAN NEVER PRODUCE.** An
  accumulated clock is a sum of fixed substeps, so it lands on no round tick: the frame a warning opens
  reads `179.999999999944`, and a row pinning `180.0` stays green while the screen never shows that
  string. **Ask whether the sim can produce a value before writing it down**, and pin what a replay
  actually yields. ⚠ The residue is per-case, not global — four of eight waves reached exactly `0.0`
  and four did not, so one probe proves nothing about its siblings. ⚠ **A `%.1f` label rounds the
  value and plants the unreachable number a second time**, in the row's own name
- ⚠⚠ **A GREEN CHECK CAN BE AN ARTEFACT OF THE DEFECT BESIDE IT.** When a defect is fixed, the checks that
  were green around it are suspects, not controls. A check that survives a fix unchanged has been
  re-verified; one that reddens was measuring the defect — and the two look identical until the fix lands

### The instrument itself

- **A crashed net is counted as "0 failures" by a wrapper that reads only its header.** Assert the net ran
- ⚠⚠ **A net PROCESS can die at startup leaving 75 bytes of stdout and 0 bytes of stderr** — no parse
  error, no bark. Three different nets have done it. What the round loses is its whole count, and the
  header still prints as one whole number. ⇒ **A net that ran no checks and exited 0 must be red**, judged
  on the check TOTAL off the runner's own summary line — not on the presence of that line (it prints on
  every path that reaches the end) and not on the pass count (a net whose every check failed also passes 0)
- ⚠ **One process running a batch prints one summary, so a net vanishing inside a batch is invisible.**
  Measured: two nets in one process with one class unresolvable printed `[net] 21 passed` at exit code 0,
  91 checks gone and the guard silent
- **Renaming a thing leaves the check written for the old name quietly measuring something else.** This is
  why the glossary carries a table of names that mean the opposite of what they say
- **A skip list that covers no file is not an exception to the scan, it is a hole in it**
- **When a table goes empty, the check that read it becomes an always-true inequality**
- **A translated `push_error` and the `t.expect_error` that forgives it are one unit**, matched by plain
  substring. Translate one side only and the net reds on a bark nobody changed, or forgives one it was
  never meant to
- **A check that only clicks the middle of the screen measures no screen-coordinate transform at all**
- **Writing one projection in two places lets both be green while they disagree with each other**
- **A control that resolves the deadlock it was meant to observe measured nothing**
- **Two guards added as a pair hide each other** — remove one and the other holds the green
