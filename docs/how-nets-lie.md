# How nets lie — every green that was measured to be false

**Where this came from**: it lived inside `CLAUDE.md` until 2026-08-19 and had grown to 129 of its 726
lines. **Nothing here is edited** — it is moved so it can keep growing without CLAUDE.md growing with it.

⚠ **CLAUDE.md keeps the rule and points here for the cases.** A rule is short enough to auto-load; a
casebook is not. **Read this file before writing a check, and before believing a green round.**

⚠ **Every entry below is a measurement, not a worry.** Each one is a green round in this repo, or in one of
the two deleted games, that turned out to guarantee nothing. **Do not delete an entry because it looks
unlikely** — the whole point is that each of them looked unlikely to whoever shipped it.

---

## No fake code

Code that pretends to work is worse than code that doesn't.

- Hardcoding for this input or this test only
- Returning a plausible value instead of computing one
- Reporting a stub as finished
- Swallowing an error so it looks like success
- **Screen changes but sim doesn't (or the reverse)** — the signature fake

If you can't do it, say you can't.

**And one whole class of it was structural, not dishonest.** The deleted game ran three clocks (render,
60Hz physics, a 20Hz simulation tick) and **five separate defects came out of the seam between them** — a
60Hz event whose period shared a factor with the divider was invisible to the tick; a check that pumped one
physics frame measured nothing at all; a hit test sampling one position in three let a player and a
projectile pass through each other, which read as "this tuning value cannot be changed" for two sessions.

⇒ **If the new game ever runs a fixed timestep under its render loop, read this paragraph again and write
the traps down as they are measured.** They are not in the general case — they are what happens when two
clocks meet, and they cost more than anything else in that codebase.

## No fake nets

When the label claims more than the check measures, that green is a false guarantee.

**Invert every new check.** An uninverted check proves "it runs", not "it measures".
**If the inversion doesn't bite, suspect the check last — first confirm the mutation actually landed.**
String replacement has silently matched zero times, twice.

**A truncated search is not a search.** `grep ... | head` on a term with many hits **silently drops the one
that matters**, and an empty tail reads as an absence. That is how "there is no scan of this file" was
asserted confidently about a scan that exists — the noisy match filled the window and hid the quiet one.
⇒ **Count the hits before reading them**, and never conclude *absence* from a truncated result.

**Invert the instrument, not only the subject.** Twice in one night a check was written to catch a defect and
**shipped carrying that same defect**: a scanner for citations wrapped across comment lines joined only on
spaces, so the mid-token wrap — the shape it existed to find — stayed invisible; and a dim-check folded two
alphas into one array, so deleting one outright stayed green because the other's minimum held. **Neither was
caught by inverting the code. Both were caught by inverting the check.** ⇒ A new check needs a case that
fails *it*, not only one that fails what it points at.

These survive **even after you confirm every mutation goes red**:

- **A check that reads only final state cannot measure an ordering contract.** Iteration order was reversed,
  final state was identical, three checks stayed green. Add a check that measures the process
- **A/B comparison catches "diverged", never "vanished".** Fold two paths into one and `scan == scan` — 39
  checks all green. "Slower without it" is caught only by timing
- **A loop whose condition is false from the start never runs the check at all.** A settle loop passed with
  zero iterations. Assert the iteration count too
- **A check that greps a file measures its text, never what it computes.** Five scans shipped in one feature
  and **every one was evaded** — a decoy line, one added term, an `@export` moving the declaration off
  `^var`, the same write from another file, an early `return` between the two lines a scan compared.
  **Drive the value instead.** `_ready()` · `_gui_input()` · `_physics_process()` and ordinary methods are
  all callable on an **untreed node** with enough wiring — **and `_draw()` too**, once the runner pumps
  frames. **Nothing in this engine resists headless.**
  **"It can't be driven headless" has been claimed four times and was wrong four times.** The fourth cost
  the most: a panel that **never set `visible`** shipped under 5,576 green checks, because the same file had
  written down "no font outside the tree" as if it were a fact
- **A spy on a hook sees the HOOK, never the native call inside it.** Measured on plan 3: with the whole
  argument chain closed — a literal pinned at `_paint_body`'s call site and read back off the spy —
  **emptying `_paint_dot`'s and `_paint_outline`'s bodies left the round green.** There are no pixels to
  read back headless, so the last inch has to be pinned **structurally**: `net_draw_leaf` now counts
  `draw_*` calls **per function** in `field_view.gd` (each leaf exactly 1, `_paint_cell` 7) and carries
  four cases that fail the *scanner*. ⇒ **Argument capture proves a value was computed and handed on. It
  never proves the value was used.** Chase it to a leaf, then pin the leaf by counting
- **The plan's own fix gets applied to one value and not to its siblings.** Plan 3 predicted in writing
  that five internal slots could change nothing on screen and stay green; the builder closed **corner**
  through `_blob` and left `outline_width`, `colour_depth` and `dot_radius` open one line over — and all
  six *external* slots could stop drawing at once. Four read-only passes found ten of these on an
  already-green round of 811, each confirmed by a mutation. ⇒ **Re-measure the whole table, not the row
  someone is arguing about** — this file's older sentence, re-earned
- **"`_draw()` ran" is not "anything was drawn."** Counting the call — even through a `super()` that draws
  nothing — measures the engine, not the picture. Three separate features shipped this way in one day, each
  erasable with 6,163 checks still green. **Godot refuses to override a native draw call**
  (`draw_texture_rect`, `draw_string`) — it is a parse error. ⇒ **Cut a `_paint(...)`-shaped hook out of
  `_draw()` and override that**, then assert the arguments. And drive it **treed with `pump_frames`** —
  calling `_draw()` by hand barks "drawing outside NOTIFICATION_DRAW"
- **Wiring a node by hand in the net hides the line that wires it in the shell.** Helpers that pre-set
  `@onready` fields let you delete the real `setup()` call and stay green while the game shows nothing.
  **Null the field back out before calling `_ready()`**
- **A check whose bounds come from the thing it checks proves nothing.** A wall test read the wall's own
  extent and asserted inside it — shrink the rectangle and the test shrinks with it. **Pin literal
  coordinates**
- **Measuring a pure function is not measuring that anything calls it.** A rect function was asserted
  correct; `_draw()` was then free to pass a bare `Rect2()` and **320 checks stayed green** — the notice
  painting at zero size, invisible. **Capture the argument at the hook and assert it equals what the pure
  function returns.** The builder had closed this exact hole one file over and left it open here; a verifier
  who had not built it found it. **This is the case for the verifier never being the builder** — measured,
  not assumed
- **`visible` is not "on screen", and neither is being wired.** `set_anchors_preset` sets anchors and
  **leaves the offsets alone**, so a `Control` added to a bare `CanvasLayer` keeps `size == (0, 0)` — and
  a panel that lays itself out from `size` then piles into the top-left corner while every check about it
  passes. Assert the size against the viewport and assert the laid-out rectangles land inside it
- **A tuning constant with a floor on one end and none on the other is half-measured.** One frame-count
  constant carried `>= 12`; its twin did not, so **2 through 11 were green** and the fade collapsed to a pop —
  the very thing the beat existed to remove. **One bite does not prove the range**
- ⚠ **A ceiling with no floor passes an effect that never happens.** The presentation round found this on
  **four items at once**: every row bounded *"the lunge never overlaps more than 6px"* and none of them said
  *"the lunge is not always zero"*, so **deleting the whole animation stayed green.** ⇒ **Bound both ends,
  in the same row.** The floor is the half that proves the feature exists
- ⚠ **Mouse clicks cannot be driven through `root.push_input()` headless, and they fail silently.**
  The headless window is **64×64**, so the stretch transform is **0.05**; `Viewport.push_input` divides the
  incoming coordinate by it and a click aimed at a dock **arrives at (2000, 6520), hits nothing, and raises
  no error.** Keys carry no coordinate and pass through fine — so **half an input suite can be green while
  the other half is dead.** ⇒ Call `game._unhandled_input(ev)` directly, or multiply by
  `root.get_final_transform()` before pushing. Measured with a spy node: the `InputEventMouseButton` itself
  does reach `_unhandled_input`; **only the coordinate is wrong**
- ⚠ **A `const` Array cannot be mutated at runtime, so "zero this table entry and watch it redden" is not a
  mutation you can write.** Twelve planned net rows died on this. **Drive the accessor instead** — the
  off-by-one in `fx_gain_of` is reachable and the raw table is not
- ⚠ **A spy that CAPTURES an argument no row ever reads is a hole with a lid on it.** The map's seven
  leaves captured `col` on four of them and **not one check inspected any of the four** — so the
  you-are-here ring, the border on every reachable node, all six reward glyphs and the screen's only two
  numbers could each be drawn at **alpha 0 with 1911 checks green.** The capture *looks* like coverage in
  a code review, which is why it survived a first adversarial pass. ⇒ **List the keys a spy stores and
  grep for a reader of each.** And read them as CONTRAST against what they are drawn on, not only as a
  non-zero alpha: the shipped glyph cleared any alpha floor at **1.3 : 1** and was unreadable
- ⚠ **A bounding box of zero extent still returns the right centre.** A helper that read each captured
  ring's centre back — written precisely to prove *a count cannot say WHERE* — could not see
  `_ring_points(centre, radius * 0.0, …)` collapse every polygon and polyline to a single point.
  ⇒ **When a check reads geometry back, read the EXTENT beside the position.** This is
  `draw_circle(p, 0.0, col)` again, arriving at the geometry argument instead of the radius one
- **Measuring a pure function is not measuring that anything calls it — and the scanner has a hole shaped
  exactly like that.** `net_draw_leaf._scan` skips any function with `draw` count 0, so building geometry
  inside a helper and passing an **empty** array to the leaf reads as *1 draw call, 4/4 arguments used* —
  green, with nothing on screen. ⇒ **Build the points in `_draw()` and hand them to the leaf as an
  argument**, so the spy captures the geometry itself
- ⚠⚠ **A GREEN CHECK CAN BE AN ARTEFACT OF THE DEFECT BESIDE IT.** `net_run._timeout_loses` landed one
  soldier, held nine at the harbour, and asserted the island took **all 3600 sub-steps** of its 60 s
  limit. It had been green in every round since it was written. What made it pass was the bug in the loss condition one file over:
  `_phase_clock` lost on `army.living_count() == 0`, which counts reserves, so an island whose whole
  beachhead was dead could not end. The lone soldier actually died at **477 sub-steps (7.95 s)** — **52
  of the 60 seconds that check asserted were the defect**, and the moment the loss rule was fixed the
  fixture reddened. ⇒ **When a defect is fixed, the checks that were green around it are suspects, not
  controls.** A check that survives a fix unchanged has been re-verified; one that reddens was
  measuring the defect, and the two look identical until the fix lands
