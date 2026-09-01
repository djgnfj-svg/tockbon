---
name: diagnosing-bugs
description: Diagnosis loop for hard bugs and performance regressions. Use when the user says "diagnose"/"debug this", or reports something broken/throwing/failing/slow.
---

# Diagnosing Bugs

A discipline for hard bugs. Skip phases only when explicitly justified.

Read `GLOSSARY.md` first for the modules and the agreed seams. ⚠ **There is no `docs/adr/` here** — what was decided and what was reversed live in `docs/roadmap/log.md`, and **every green already measured false lives in `docs/how-nets-lie.md`.** Read that one before believing any loop you build.

⚠ **Redact every secret out of anything you paste** — write `<REDACTED>` in its place.

## Phase 1: Build a feedback loop

**This is the skill.** Everything else is mechanical. If you have a **tight** pass/fail signal for the bug (one that goes red on _this_ bug), you will find the cause; bisection, hypothesis-testing, and instrumentation all just consume it. If you don't have one, no amount of staring at code will save you.

Spend disproportionate effort here. **Be aggressive. Be creative. Refuse to give up.**

### Ways to construct one, in roughly this order

**This is a Godot game driven from PowerShell. There is no dev server, no browser and no HTTP** — every
loop below is the engine, run headless, or the game with the user in front of it.

1. **A net** at a seam the glossary already agrees on — `tests/nets/`, run by `tests/run_nets.ps1`.
   ⚠ **No net is written at a seam `GLOSSARY.md` does not name**; needing a new one is the user's call.
2. **A throwaway `--headless --script` runner** that builds the `sim` objects with `.new()` and asserts
   the symptom. **`src/sim/` is constructible without the tree, which is what makes this cheap.**
3. **A throwaway under `.prototypes/<subject>/`.** ⚠ **Ten runners already exist there** — copy the
   nearest one rather than writing a runner from scratch; `.prototypes/README.md` says which.
4. **A photograph**, and only when the pixels ARE the symptom — `tools/shot/`.
   ⚠ **Never `--headless` for this**: there is no swapchain, every PNG comes back black, and no error is raised.
5. **Replay a fixed input.** The sim is deterministic: pin the seed and the input list, and the same run
   comes back every time.
6. **Fuzz the seed.** For "sometimes wrong", drive a thousand seeds through the sim headless and collect
   the ones that fail.
7. **`git bisect run`**, when the bug appeared between two known-good commits.
8. **Differential.** The same input through two commits, or two values of one constant in
   `src/sim/rules.gd`, diffed.
9. **The user, in front of the running game.** ⚠ **Last resort, and it costs a round.** Say exactly what
   they should do and exactly what to look at.

⚠⚠ **The traps that have each cost a round are written down, not here** — `docs/how-nets-lie.md` holds
them: **mouse clicks pushed headless fail silently** (the window is 64×64 and the transform eats them),
and **`--headless --script` does not re-import**, so a brand-new `class_name` file is invisible. Read it
before you conclude the loop is telling you the truth.

⚠⚠ **The most common failure in this repo is wrong with no error.** `run_nets.ps1` treats anything on
stderr as a failure for that reason — a loop that only checks "it did not crash" measures nothing here.

### Tighten the loop

Treat the loop as a product. Once you have _a_ loop, **tighten** it:

- Can I make it faster? (Cache setup, skip unrelated init, narrow the test scope.)
- Can I make the signal sharper? (Assert on the specific symptom, not "didn't crash".)
- Can I make it more deterministic? (Pin time, seed RNG, isolate filesystem, freeze network.)

A 30-second flaky loop is barely better than no loop; a 2-second deterministic one is tight, a debugging superpower.

### Non-deterministic bugs

The goal is not a clean repro but a **higher reproduction rate**. Loop the trigger 100×, parallelise, add stress, narrow timing windows, inject sleeps. A 50%-flake bug is debuggable; 1% is not, so keep raising the rate until it's debuggable.

### When you genuinely cannot build a loop

Stop and say so explicitly. List what you tried. Ask the user for: **(a) the exact steps that make it happen** in the running game, **(b) a screenshot or a recording of the moment**, or **(c) what the game printed** — `push_error` does not stop the game, so the bark is often sitting in the output nobody read. Do **not** proceed to hypothesise without a loop.

### Completion criterion: a tight loop that goes red

Phase 1 is done when the loop is **tight** and **red-capable**: you can name **one command** (a net, a `--headless --script` runner, a shot script) that you have **already run at least once** (show the invocation and its output, redacted), and that is:

- [ ] **Red-capable**: it drives the actual bug code path and asserts the **user's exact symptom**, so it can go red on this bug and green once fixed. Not "runs without erroring"; it must be able to _catch this specific bug_.
- [ ] **Deterministic**: same verdict every run (flaky bugs: a pinned, high reproduction rate, per above).
- [ ] **Fast**: seconds, not minutes.
- [ ] **Agent-runnable**: you can run it unattended. ⚠ **A loop that needs the user to launch the game and look is not one** — it is the last resort above, and it costs a round.

If you catch yourself reading code to build a theory before this command exists, **stop: jumping straight to a hypothesis is the exact failure this skill prevents.** No red-capable command, no Phase 2.

## Phase 2: Reproduce + minimise

Run the loop. Watch it go red as the bug appears.

Confirm:

- [ ] The loop produces the failure mode the **user** described, not a different failure that happens to be nearby. Wrong bug = wrong fix.
- [ ] The failure is reproducible across multiple runs (or, for non-deterministic bugs, reproducible at a high enough rate to debug against).
- [ ] You have captured the exact symptom (error message, wrong output, slow timing) so later phases can verify the fix actually addresses it.

### Minimise

Once it's red, shrink the repro to the **smallest scenario that still goes red**. Cut inputs, callers, config, data, and steps **one at a time**, re-running the loop after each cut, and keep only what's load-bearing for the failure.

Why bother: a minimal repro shrinks the hypothesis space in Phase 3 (fewer moving parts left to suspect) and becomes the clean regression test in Phase 5.

Done when **every remaining element is load-bearing**: removing any one of them makes the loop go green.

Do not proceed until you have reproduced **and** minimised.

## Phase 3: Hypothesise

Generate **3–5 ranked hypotheses** before testing any of them. Single-hypothesis generation anchors on the first plausible idea.

Each hypothesis must be **falsifiable**: state the prediction it makes.

> Format: "If <X> is the cause, then <changing Y> will make the bug disappear / <changing Z> will make it worse."

If you cannot state the prediction, the hypothesis is a vibe: discard or sharpen it.

**Show the ranked list to the user before testing.** They often have domain knowledge that re-ranks instantly ("we just deployed a change to #3"), or know hypotheses they've already ruled out. Cheap checkpoint, big time saver. Don't block on it; proceed with your ranking if the user is AFK.

## Phase 4: Instrument

Each probe must map to a specific prediction from Phase 3. **Change one variable at a time.**

Tool preference:

1. **A breakpoint**, when the bug is reachable in the editor. ⚠ **Headless has none** — there the probe is a print, and one print at the right boundary beats ten.
2. **Targeted logs** at the boundaries that distinguish hypotheses.
3. Never "log everything and grep".

**Tag every debug log** with a unique prefix, e.g. `[DEBUG-a4f2]`. Cleanup at the end becomes a single grep. Untagged logs survive; tagged logs die.

**Perf branch.** For performance regressions, logs are usually wrong. Instead: establish a baseline (`Time.get_ticks_usec()` around the suspect, or Godot's own profiler), then bisect. Measure first, fix second.

⚠⚠ **Stop measuring the moment the user is waiting on you** (2026-08-30): four probes were run to find the cause of a stall and the user cut it off. **Say the one number you have and ask**, rather than widening the measurement.

## Phase 5: Fix + regression test

Write the regression test **before the fix**, but only if there is a **correct seam** for it.

A correct seam is one where the test exercises the **real bug pattern** as it occurs at the call site. If the only available seam is too shallow (single-caller test when the bug needs multiple callers, unit test that can't replicate the chain that triggered the bug), a regression test there gives false confidence.

**If no correct seam exists, that itself is the finding.** Note it. The codebase architecture is preventing the bug from being locked down. Flag this for the next phase.

If a correct seam exists:

1. Turn the minimised repro into a failing test at that seam.
2. Watch it fail.
3. Apply the fix.
4. Watch it pass.
5. Re-run the Phase 1 feedback loop against the original (un-minimised) scenario.

## Phase 6: Cleanup

Required before declaring done:

- [ ] Original repro no longer reproduces (re-run the Phase 1 loop)
- [ ] Regression test passes (or absence of seam is documented)
- [ ] All `[DEBUG-...]` instrumentation removed (`grep` the prefix)
- [ ] Throwaway prototypes deleted (or moved to a clearly-marked debug location)
- [ ] The hypothesis that turned out correct is stated in the commit message, and — when a ticket owns this spot — in that ticket, so the next round learns
