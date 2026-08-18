# Parallel build — one worktree per builder, and the report the user reads

**Status**: protocol. **Never run.** The first execution re-measures every number in it.
About the order in which the game is built, not about the game. The settled design is `cell-army-gdd`.

Why the user asked for it, in their words: ***"개발이 너무 느린 게 지금 답답한 점임"*** and
***"여러 번 빌더가 도는데 각각 무엇을 개발하고 무엇을 수정하는지 말하지 않음. 그냥 여러 번 돌기만 함."***

⇒ **Speed and visibility belong in one document.** Getting faster alone means less is known about what
happened, not more.

⚠ **Section 6 is an adversarial review of this document, run the day it was written, and it moved four
claims in the body.** Read it before executing anything here. **One of its findings is a defect in
`run_nets.ps1` that blocks this protocol** — see 6-A.

---

## 0. What was measured — what is actually slow

**The net round is not the bottleneck.** Measured 2026-08-19 on this tree:

| Piece | Measured |
|---|---|
| Whole net round (14 nets · 1933 checks · 16-wide) | **6.7s** |
| One mutation (open · break · round · restore · judge) | **1–2 min** — the round is 6.7s of it, **6–12%** |
| One stage's mutation sweep, 20 of them | **20–40 min**, single file |
| One plan | **24 agent round-trips** |
| `src/` | **14 files, 6894 lines** |
| Godot process start (`--headless --script`) | **~300ms** |
| One `--import` pass | **~2.5s.** Only when a `.gd` has no `.uid` beside it. Editor boot cost, irreducible |
| The wrapper itself (PS start · fingerprint · unimported scan) | **0.3–0.8s, independent of net count** |

⇒ **Most of the wall clock is an agent reading, thinking and typing.** Not lines of code — **round-trips.**
Making the runner faster changes nothing: it was already taken from 6.1s to 3.7s once, on a load of 49
throwaway nets, and the conclusion then was the same one.

⚠ **One property of the runner is not for sale**: each net gets its own process so that **an amnesty stays
inside its own net**. Measured — net 1's forged bark was covered by net 3's declaration when they shared a
process. **Do not merge net processes for speed.**

### How much do the chokepoints overlap — measured, and it did not mean what it looked like

`look.gd` · `rules.gd` · `shell/game.gd` are touched by every feature, because of the one-file rules.
Their share of **new `src/` lines** in the last three rounds:

| Commit | Chokepoint 3 | Rest of src | Share |
|---|---|---|---|
| `642dbb5` first slice | 918 | 2927 | **24%** |
| `8a67a79` boat landing | 318 | 927 | **26%** |
| `a7dc19b` title and map | 1232 | 1697 | **42%** |

⚠ **This table answers a narrower question than its own heading did, and the heading was corrected.**

> **Refutation (same day, out of the user's question)**: 24–42% is **file** overlap, not **line** overlap.
> Git does not conflict per file — it conflicts on **adjacent hunks**. `look.gd` is 1161 lines, and two
> builders appending constant blocks in different places **merge automatically.**
> ⇒ **What has to be pre-allocated is names, never code** (section 2). The first draft had spec write all
> the chokepoint code up front, which sized the serial section far larger than it is.
>
> ⚠ **And the denominator is contaminated**, found in the review: `a7dc19b`'s "rest of src" includes
> `map_view.gd` (556) and `title_view.gd` (249) — **brand-new files, zero conflict risk.** Two of the three
> rows are inflated the same way. ⇒ **Treat this table as an order of magnitude only.** The number that
> would actually predict merge cost is conflicting hunks per round, and **that is measured after the first
> run, not before it.**

**Where text actually conflicts is one place**: `shell/game.gd`'s wiring — the same `_ready()`, the same
branch. A few lines, resolved by hand. **The merge is not the expensive part.**

---

## 1. The real hazard is not a text conflict — it is a **semantic** one

Cases where **git merges cleanly and the tree is wrong**:

- Both builders add a **constant of the same name** to `look.gd` — duplicate declaration, or one silently wins
- Both builders add **the same value to the same enum** (`NodeKind`, `Reward`)
- Both builders add **the same meaning under different names** — the merge is clean and `CLAUDE.md`'s
  *"a value counted in two places will diverge"* happens exactly as written. **This one is the quietest**
- One adds a column to a table in `rules.gd` while the other edits a function that reads that table —
  the merge is clean and every index is off by one

⇒ **First defence is spec's name pre-allocation; second is the net round after the merge.** Both are
required, and **neither alone is enough** — see the correction in 2-2.

---

## 2. What spec does — **boundaries, not code**

spec runs once, serially, and **writes no code.** It produces three things.

### 2-1. A file ownership table

| File | Owner |
|---|---|
| `src/sim/battle.gd` | builder-A |
| `src/view/map_view.gd` | builder-B |
| `src/look.gd` | **shared — additions only, each in its own section** |
| `src/shell/game.gd` | **shared — wiring only, resolved by hand at merge** |

**Two owners on one file means that place is not parallel.** The table says so in as many words.

### 2-2. Name pre-allocation

spec fixes the **constant, enum-value and function names** each builder will use, and hands them over.
Names and owning file only — never values, never code.

```
builder-A -> look.gd:  FX_LUNGE_PX, FX_LUNGE_SEC
             rules.gd: NodeKind.SHOP (= 4)
builder-B -> look.gd:  MAP_GLYPH_PX, MAP_RING_ALPHA
             rules.gd: none
```

⚠ **This blocks three of section 1's four cases, not all four** — corrected in the review. It says nothing
about the **shape** of a table: one builder adding a column while another edits its reader is untouched by
name allocation, and **only the post-merge net round can see it.** If a round changes a table's arity, spec
declares that file serial (2-3) instead.

### 2-3. ⚠ spec must be able to say **"these two are not parallel"**

When two slices overlap outside the chokepoints — both editing `battle.gd` — **name pre-allocation cannot
help.** The answer spec owes then is not "split it somehow" but **"go serial."**

**A protocol in which that declaration cannot be produced is lying.** If spec always returns a parallel
plan, that is compliance, not measurement.

---

## 3. The order

```
1. spec        slices · ownership table · name pre-allocation · parallel or not   serial, once
2. builder xN  one worktree each. Each to its own green round                     parallel
3. Merge       serial, once + a net round in the main tree (6.7s)
4. verify x3   verify-read · verify-run · verify-look on the MERGED tree           parallel
5. Rework      findings batched into ONE message per builder -> back to 2
6. Done        the report (section 4)
```

**Step 4 is after the merge, always.** What was verified inside a worktree says nothing about the merged
tree — a semantic conflict comes into existence at exactly the moment of the merge.

### 3-1. The worktree round trip — the skill does it; by hand one step always goes missing

- **Re-branch from `main` immediately before starting.** A worktree freezes at the commit it branched from;
  two agents once built a session's work on a base that did not know the day's other changes had landed
- **A fresh worktree has no `.godot` import cache.** `run_nets.ps1` runs `--import` itself when it sees a
  `.gd` with no `.uid` (~2.5s). Bypass that guard and it has to be run by hand
- **Finish with `git worktree remove --force` + `prune`.** Automatic cleanup almost never fires — 700MB in
  one night, measured

### 3-2. ⚠ What collides between worktrees is **CPU**, and — found in the review — **one shared file**

Each worktree has its own `.godot`, its own `tests/`, its own Godot processes. **The nets do not collide on
the tree's files.** They collide on cores: `run_nets.ps1` runs `Min(16, cores)` wide, so three worktrees put
48 processes on 16 threads. That is a concurrency-cap question, not a documentation one.

⚠ **But "no file collision" was asserted without checking, and it is false.** See **6-A**: the runner's
timing cache is a single shared path with no per-tree scoping. **Fix that before running this protocol.**

**How many builders at once is not measured.** Any starting number here would be invented; take the cap from
the first run instead — record cores, worktree count, and each round's wall clock, and set it from that.

### 3-3. The mutation sweep is separate — **and it is the bigger win**

20–40 min per stage, **no judgement, therefore perfectly parallel**, and — unlike builder parallelism —
**it has no merge and no ceiling**: the worktrees are thrown away. Thirty of them cost one's wall clock.
The protocol is already written in the `build-feature` skill and is not repeated here.

⚠ **Read that against this document's own subject.** Builder parallelism is capped by the serial spec pass,
the serial merge and the slowest single builder. **The sweep is capped by nothing.** If only one of the two
gets built, **build the sweep.**

⚠ **`landed` is not optional.** A mutation that never applied is green for the wrong reason, and that has
happened twice here.

### 3-4. When one builder is stuck

Wall clock is **the slowest builder**, so a stuck one is not a local problem.

- **`build-feature`'s limit carries over: three bounces without passing and it stops and goes to the user.**
  With N builders it stops **that builder**, not the round
- **Merge what is green and drop the stuck slice back to `1.ready`.** A half-finished slice held in a
  worktree while the others wait is the whole speedup, spent
- ⚠ **This is untested.** It is the first thing the first real run will exercise

---

## 4. The report — **the thing the user reads**

In the user's words: ***"완료 할 때 각각의 작업에서 무엇을 했는지 말하는 내가 읽어야 하는 보고서가 필요함."***

### 4-1. One commit per round in the worktree — **that is the raw material**

Every builder commits to its own worktree at the end of each of its rounds. One-line message, Korean.
**The report is extracted from those commits.**

⚠ **An agent's own summary is not the report.** `CLAUDE.md` already carries the reason — **measuring your own
work reads favourably.** File names, line counts and check labels do not.

### 4-2. What goes in it

| Column | Where it comes from |
|---|---|
| Round number · who | The orchestrator |
| **Files changed and ±lines** | `git show --numstat` — machine |
| **Why it ran** | Round 1: the plan. Round 2+: **the red check labels from the round before**, or a verifier's finding |
| **Closed?** | Is that label green in the next round. **Otherwise it stays as "not closed"** |
| Nets | check count · seconds · fingerprint |

**"Closed / not closed" is the whole point of the table.** Everything else is context for reading it.

⚠ **Two of these columns are not machine-derived, and the review caught the doc claiming otherwise.**
A verifier's finding is prose. And the red labels *are* machine-readable — the runner regex-matches
`[net] N failed / M` and keeps each failing line — **but nothing persists the runner's stdout**, so nothing
can compare round N to round N+1. ⇒ **Either the round's stdout is captured to a file per round, or the
"closed?" column is an agent's memory wearing a table's clothes.** Capturing it is the cheaper half and it
is a prerequisite, not a nicety.

### 4-3. Shape

```
## Round 3 — builder-A

changed     src/sim/battle.gd +48 -12 · src/look.gd +9 -0
why         red in round 2: `연출: 돌진이 항상 0이 아니다` · `연출: 돌진이 6px를 안 넘는다`
closed      both green
not closed  none
nets        1948 checks · 6.9s · fingerprint A31F...
```

⚠ **Print the "not closed" line even when it is empty.** An absent line reads as an absent problem.

### 4-4. Where it is written, and by whom

⚠ **Not by the builder, and not inside the plan doc.** The first draft said each builder appends its round
to a `## Round log` section of the plan in `2.active`, and the review killed it on two counts:
**a worktree's doc edits never leave the copy** (`CLAUDE.md` says so about verifiers; it is the same for
builders), and **two builders appending to one section conflicts on every single merge** — the document
would manufacture the exact collision it exists to prevent.

⇒ **The orchestrator writes it, in the main tree, after each merge**, from the worktree commits and the
captured round output. It lands in the plan doc and travels with it to `3.done`.

**Per round, not once at the end.** Written all at once at completion it is an agent's recollection again,
not a record.

---

## 5. What would make this document wrong

- ⚠ **Speedup has to be stated as a number or this is not a test.** Target for the first run: **two builders
  finish a two-slice round in under 70% of the wall clock the same two slices take serially**, measured from
  spec's start to the merged tree going green. **Under that, worktree overhead is eating the win** and this
  document is wrong. (The naive ceiling for two is 50%; 70% leaves room for spec, the merge and the slower
  builder.) ⚠ **The floor matters more than the ceiling** — this repo has already shipped a bound with a
  ceiling and no floor and passed an effect that never happened
- **More than five hand-resolved conflicts per round** means name pre-allocation is too thin. Grow 2-2
- **A semantic conflict the nets miss** is a net problem, not an ordering problem. Write that net first
- ⚠ **If "not closed" is always empty, distrust it.** This repo has more records of green-and-broken than the
  reverse — 3541 checks green with the game unplayable, 279 green with verify-look finding three defects in
  minutes, 1933 green with the user saying the controls were unusable

---

## 6. Adversarial review of this document — 2026-08-19, the day it was written

**Four findings changed the body above.** Recorded here rather than silently patched, because a document
that shows no sign of having been wrong reads as one that was never checked.

### 6-A ⚠ **BLOCKING — `run_nets.ps1`'s timing cache is shared across worktrees**

The runner caches each net's duration to drive **longest-first scheduling**. The path is

```
$timingFile = Join-Path $tmp "tockbon_net_timings.json"
```

**No `$PID`, no per-root scoping** — and every other temp path in that file is `_$PID`-suffixed, so this one
is an omission, not a decision. Under this protocol, N worktrees read, merge and overwrite **the same file**:

- Interleaved writes lose rounds; the write sits inside `try {} catch {}`, so **nothing is reported**
- A worktree running under CPU contention records **inflated** durations, which then **reorder the main
  tree's next round**
- A read landing mid-write throws, is swallowed, and every timing is lost at once — longest-first degrades
  to "unknown sorts first" and **the round gets slower with nothing said**

**Correctness is not affected; scheduling and every timing measurement are.** ⇒ **Scope the path by tree
before running anything here** — the repo root's hash appended to the filename is the whole fix.
⚠ **And it invalidates timing comparisons taken while worktrees were live**, which is precisely when this
protocol wants to measure itself.

### 6-B The report mechanism conflicted with its own isolation

4-4's first draft had builders append round records to a shared section of the plan doc from inside their
worktrees. Both halves were wrong; **4-4 is rewritten.**

### 6-C The report claimed to be machine-derived and was not

4-2's "why it ran" is a verifier's prose, and nothing persists the runner's stdout, so "closed?" had no
mechanism at all. **4-2 now names the prerequisite.**

### 6-D Name pre-allocation was claimed to close all four semantic cases

It closes three. **2-2 corrected.**

### Two findings that did NOT change the body, recorded so they are not re-raised

- **"The chokepoint table measures the wrong thing"** — true, and the body already said so; the review added
  the contaminated-denominator note to the same box rather than moving the claim
- **"This document optimises the smaller half"** — true, and it is now stated in 3-3 with the instruction to
  build the sweep first if only one gets built. It is not grounds for deleting the document: the sweep does
  not make two plans run at once, which is what the user asked for
