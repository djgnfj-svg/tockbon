# What Godot does quietly

**Godot 4.7, GDScript, measured in this repo.** ⚠⚠ **Every entry here fails without an exception, without
a red, and with exit code 0.** That is the whole reason the page exists — nothing below announces itself.

⚠ **The net runner is the worked case for the first three** (`tests/run_nets.gd`, `tests/run_nets.ps1`).
**This page is here so the fact reaches game code**, where nobody opens the runner.

## A runtime error abandons only the function it lands in

**GDScript 4.7 has no try/catch.** When a call throws, **that function stops, the CALLER resumes on its
next line, receives `null`, and the process exits 0.**

**Measured 2026-08-30: 70 checks across the suite had never executed, behind a reported 752.** A net that
asserted 56 rows and then threw inside `run()` moved the counter by 56 and printed 「통과 56」 — **the
same shape a healthy net prints.**

⇒ **A `null` coming back from your own call is a possible death, not a missing value.** Where the work
after a call must not silently vanish, **put a sentinel the caller can check** — the runner's `t.done()`
is one line at the foot of every `run()`, and it exists because a counter moving is not proof of arrival.

⚠ **It has two costs and they are indistinguishable from the summary.** A death in the top function
discards everything below it; a death one frame down discards only that frame. **A sentinel catches the
first shape and cannot catch the second** — for that you read the stderr backtrace's first `at:` line,
which names the frame the error actually landed in.

## `push_error` does not stop anything

**It prints `USER ERROR` and the code carries on.** It is a log line. ⚠⚠ **A `SCRIPT ERROR` abandons a
function; a `push_error` never does** — the two look equally alarming on stderr and mean opposite things.

⇒ **Anything appearing on stderr is treated as a failure here.** The game stays green while only the
world goes wrong, so the bark has to be caught by something that is not the code that barked.

## `.call()` throws away a coroutine's suspension

**`obj.call("run", self)` does NOT carry an `await` inside `run` back to the caller.** Everything after
that `await` is abandoned, silently.

**Measured**: reverting the runner's `await net.run(self)` to `net.call("run", self)` **does not turn the
net red — it makes it vanish**, `0 passed`, exit code 0. **Only the pass COUNT dropping catches it.**

⇒ **Call a function that awaits with `await`, never with `.call()`.** And **a count that dropped to zero
is a symptom to chase**, not a net that had nothing to say.

## An imported asset is served from a cache that `--script` never refreshes

**Blender writes `assets/terrain/island.glb`; Godot reads its own converted copy under `.godot/imported/`.
A `--script` run does not re-convert a changed source.**

**Measured 2026-08-27: three bakes in a row came back identical** and the third was investigated as a
modelling bug — the source was minutes old and the screen was drawing the previous evening's island.

⇒ **A bake that skipped the re-import is not evidence.** `tools/blender/bake_island.ps1` bakes, clears
the cache, re-imports, and errors out if Godot's copy is older than the source.

## `DIFFUSE_LIGHT` already carries `ALBEDO`

**Godot multiplies `ALBEDO` into it.** Writing `ALBEDO * ...` inside a `light()` function **squares the
colour and comes out two steps dark.**

⇒ **In a `light()` function the albedo is already there.** ⚠ This one is quiet in the worst way — the
picture is merely darker, which reads as a value that wants tuning rather than as arithmetic done twice.
