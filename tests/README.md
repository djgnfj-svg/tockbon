# tests — the nets, and every trap measured while writing them

**A net is `tests/nets/net_*.gd` with one method, `func run(t)`.** Run the round with

```
powershell -ExecutionPolicy Bypass -File tests/run_nets.ps1
```

⚠ **Read `how-nets-lie` before writing a check and before believing a green round.** This file is how the
runner behaves; that one is the casebook of greens that guaranteed nothing.

**17 nets, 2473 checks, 4.7 seconds, green.** The old game reached 25 / 3541 / 4.6s — ⚠ **a scale marker,
not a target.** Those nets drove a game deleted for not being fun.

A net is `tests/nets/net_*.gd` with one method, `func run(t)`; `t` gives `ok` · `eq` · `pump_frames` ·
`expect_error` · `root`. **The wrapper reds below five nets** — that is the scan-broken detector, so nets
land in groups, never one at a time.

1. **"N passed" is not green.** `load()` returns non-null on a parse failure. Only the final `[wrapper]` line
   decides. **A net that ran zero checks is a failure** — added the day a missing `await` made a net vanish
   with exit code 0
2. **If `[race]` prints, distrust the result — green included.** ⚠ It catches an edit *during* a round, never
   one *between* rounds, and comparing two rounds is the whole of mutation testing. ⇒ **`[지문]` hashes the
   content of every scanned file** (`src`, `tests`, `docs`, `CLAUDE.md`): **two rounds with different
   fingerprints did not measure the same tree.** ⇒ **When the tree is contested, do the edit and the run in
   ONE command.** `git status --porcelain` is deliberately NOT a red — an uncommitted tree is the normal
   state of every builder round
3. ⚠ **A hung net is not a slow net**, and for two plans the round could not tell them apart — one net spun
   148.7s with no verdict printed at all, silently disarming mutation testing. The runner now kills any net
   past `$NetTimeoutSec` (120s), reports it red, and **zeroes its pass count**
4. **Each net runs in its own process, in parallel.** Not for speed — **for honesty**: amnesty stays inside
   its own net. Measured: net 1's forged bark was covered by net 3's declaration when they shared one.
   **Do not break this property**
5. **`_draw()` is measurable headless.** The runner pumps real frames (`t.pump_frames(n)` after
   `t.root.add_child`). **"It can't be driven headless" has been claimed four times and was wrong four
   times.** Only pixel appearance is verify-look's
6. ⚠ **Mouse clicks cannot be driven through `root.push_input()` headless, and they fail silently.** The
   headless window is 64x64 so the stretch transform is 0.05; a click aimed at a dock **arrives at
   (2000, 6520), hits nothing, and raises no error.** Keys pass through fine — so **half an input suite can
   be green while the other half is dead.** Call `game._unhandled_input(ev)` directly

**Call `harness-manager` when a round grows.** The old game's round was ~28s and **one net was 24.3s of it,
unnoticed for weeks.** Slow means verification gets skipped, and then none of the above matters.

---

## Writing one

`t` gives `ok` · `eq` · `pump_frames` · `expect_error` · `root`.

- **Invert every new check.** An uninverted check proves "it runs", not "it measures". If the inversion
  doesn't bite, **suspect the check last** — first confirm the mutation actually landed
- **Invert the instrument, not only the subject.** Twice in one night a check was written to catch a defect
  and shipped carrying that same defect. ⇒ A new check needs a case that fails *it*
- **A truncated search is not a search.** `grep ... | head` on a term with many hits silently drops the one
  that matters. **Count the hits before reading them**
- **Net check labels are Korean** — they are what the user reads. A `push_error` message and the
  `t.expect_error` that forgives it are **one unit**, matched by plain substring
