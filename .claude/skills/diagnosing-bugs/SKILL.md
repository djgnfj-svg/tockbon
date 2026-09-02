---
name: diagnosing-bugs
description: Diagnosis loop for hard bugs and performance regressions. Use when the user says "diagnose"/"debug this", or reports something broken/throwing/failing/slow.
---

# Diagnosing Bugs

A discipline for hard bugs. **Skip a phase only when you say why.**

Read `GLOSSARY.md` first for the modules and the agreed seams. ⚠ **There is no `docs/adr/` here** — what
was decided lives in `docs/roadmap/log.md`, and **every green already measured false lives in
`docs/how-nets-lie.md`.** Read that one before believing any loop you build.
⚠ **Redact every secret out of anything you paste** — write `<REDACTED>` in its place.

## Phase 1: Build a feedback loop

**This is the skill; everything else is mechanical.** With a tight pass/fail signal that goes red on
_this_ bug you will find the cause. Without one, no amount of staring at code will save you.
**Spend disproportionate effort here.**

### Ways to construct one, in roughly this order

**This is a Godot game driven from PowerShell — no dev server, no browser, no HTTP.**

1. **A net** at a seam the glossary already agrees on, run by `tests/run_nets.ps1`.
   ⚠ **No net at a seam `GLOSSARY.md` does not name**; needing a new one is the user's call
2. **A throwaway `--headless --script` runner** building `sim` objects with `.new()`. `src/sim/` is
   constructible without the tree, which is what makes this cheap
3. **A throwaway under `.prototypes/<subject>/`.** ⚠ **Ten runners already exist there** — copy the nearest
4. **A photograph**, only when the pixels ARE the symptom. ⚠ **Never `--headless` for this**: no
   swapchain, every PNG comes back black, and no error is raised
5. **Replay a fixed input** — the sim is deterministic; pin the seed and the input list
6. **Fuzz the seed** for "sometimes wrong" — a thousand seeds headless, collect the failures
7. **`git bisect run`**, when the bug appeared between two known-good commits
8. **Differential** — the same input through two commits, or two values of one constant, diffed
9. **The user, in front of the running game.** ⚠ **Last resort, and it costs a round**

⚠⚠ **The traps that each cost a round live in `docs/how-nets-lie.md`**: mouse clicks pushed headless fail
silently, and `--headless --script` does not re-import, so a brand-new `class_name` file is invisible.
⚠⚠ **The commonest failure in this repo is wrong with no error** — a loop that only checks "it did not
crash" measures nothing here.

### Tighten it

Faster (cache setup, narrow the scope) · sharper (assert the symptom, not "didn't crash") · more
deterministic (pin time, seed the RNG). **A 30-second flaky loop is barely better than none; a 2-second
deterministic one is a superpower.**

**Non-deterministic bugs**: the goal is a higher reproduction RATE, not a clean repro. Loop the trigger
100×, parallelise, add stress, narrow timing windows. **50% is debuggable; 1% is not.**

### Done when one command goes red

Name **one command you have already run** (show the invocation and its output), and that is:

- [ ] **Red-capable** — drives the actual bug path and asserts the **user's exact symptom**
- [ ] **Deterministic** — same verdict every run
- [ ] **Fast** — seconds, not minutes
- [ ] **Agent-runnable** — ⚠ a loop that needs the user to launch the game and look is not one

**No red-capable command, no Phase 2.** Reading code to build a theory first is the exact failure this
skill prevents. **If you genuinely cannot build a loop, stop and say so** — list what you tried, and ask
for the exact steps, a screenshot of the moment, or what the game printed.

## Phase 2: Reproduce, then minimise

Run the loop and watch it go red. Confirm it is the **user's** failure mode, not a nearby one — wrong
bug, wrong fix — and that it reproduces across runs.

**Then shrink to the smallest scenario that still goes red.** Cut inputs, callers, config and steps **one
at a time**, re-running after each. **Done when removing any remaining element makes it go green.**

## Phase 3: Hypothesise

**Generate 3–5 ranked hypotheses before testing any**, each **falsifiable**:
*"If X is the cause, changing Y makes it disappear."* A hypothesis with no prediction is a vibe.

**Show the ranked list to the user before testing** — they re-rank it instantly. Do not block on it.

## Phase 4: Instrument

**Each probe maps to one prediction. Change one variable at a time.**

- **A breakpoint** when the bug is reachable in the editor. ⚠ **Headless has none** — there one print at
  the right boundary beats ten
- **Targeted logs** at the boundaries that separate hypotheses. **Never "log everything and grep"**
- **Tag every debug log** with a unique prefix such as `[DEBUG-a4f2]`, so cleanup is one grep
- **Performance**: baseline with `Time.get_ticks_usec()` or Godot's profiler, then bisect. Measure first
- ⚠⚠ **Stop measuring the moment the user is waiting on you** (2026-08-30) — four probes were run on a
  stall and the user cut it off. **Say the one number you have and ask**

## Phase 5: Fix + regression test

**Write the regression test before the fix, but only if a correct seam exists** — one where the test
exercises the real bug pattern as it occurs at the call site. **A too-shallow seam gives false confidence.**

⚠ **If no correct seam exists, that is itself the finding.** Note it and move on.

Otherwise: turn the minimised repro into a failing test · watch it fail · fix · watch it pass · re-run
the Phase 1 loop against the original scenario.

## Phase 6: Cleanup

- [ ] The original repro no longer reproduces
- [ ] The regression test passes, or the absent seam is written down
- [ ] Every `[DEBUG-...]` probe removed
- [ ] Throwaway prototypes deleted
- [ ] **The hypothesis that turned out right is in the commit message**, and in the ticket that owns the spot
