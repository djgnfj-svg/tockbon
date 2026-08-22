---
name: implement-plan
description: Implements one ticket with a team. Use when the user says "이거 구현하자" "만들어줘" "개발 시작" "let's build this", or points at a ticket under .scratch/. Spawns and coordinates five agents — spec, builder, verify-run, verify-look, verify-read. Also used for retries, resuming, and re-running verification only.
---

# Running the feature team

## Step 0 — ask how it should be run, BEFORE spawning anything

**Ask the user one question and wait**: sequential team, or `ultracode` / a workflow?

**You may not decide this yourself.** Parallel orchestration spends heavily and the permission to do it is
the user's alone — but *not asking* is how a build silently takes six hours. **One line, at the start:**

> 순차 팀으로 갈까요, 아니면 `ultracode`(멀티 워크플로우)로 갈까요? 뮤테이션 구간이 5~10배 빨라집니다.

**Recommend the workflow whenever the plan carries more than ~20 checks.** Measured on plan 1, 2026-08-14:

| | sequential | why |
|---|---|---|
| net round | **1.2s** | never the bottleneck |
| one mutation | **1–2 min** | open file · break it · run nets · restore · judge |
| a stage's mutation sweep | **20–40 min** | 20-odd mutations, one at a time |
| whole plan | **~24 agent round-trips** | three stages, four bounces on stage 2 alone |

**The nets cost 30 seconds of that. Everything else was agents reading and writing.** Mutations are the
single most parallelisable part of the job and they were run in single file — that is the thing the workflow
fixes.

If the user says workflow, follow *Running the mutation sweep as a workflow* below. If they say sequential,
run the flow as written and **keep the round-trips down** — batch findings, do not send one finding per
message, and do not spawn all three verifiers on a stage that changed nothing on screen.

## The most important rule

**Do not recreate an agent. Talk to it.**

```
Agent(name: "builder", run_in_background: true)   once
SendMessage(to: "builder", ...)                   everything after
```

**Give a `name` and it becomes a teammate; omit it and it's just a subagent.** Teammates are registered in
the roster and message each other directly.
**On screen the two look identical** — there is no setting that distinguishes them (confirmed in the docs).
⇒ **Say which one it is every time you spawn.**

And **idle is not dead.** Send a message and it resumes from the transcript, **without re-reading files** (measured).
If it really died, `SendMessage` fails with "not reachable" — spawn a new one only then.

### `CLAUDE.md` freezes at spawn time

**Auto-load works** — a teammate knows `CLAUDE.md` without any `Read` (measured: answered the reply rule
exactly with 0 tool calls).
**But that copy is from the spawn moment and never refreshes.** Measured — a folder was renamed mid-session
and the teammate's copy still had the old name; it learned the new one **from my message.**

⇒ **If you edit `CLAUDE.md` or a design doc mid-session, tell them directly with `SendMessage`.** Otherwise
they keep working from the old content.
Conversely, **editing an agent definition (`agents/*.md`) sends a change notification carrying the new body**
(measured). That side does reach them mid-flight.

Calling `Agent` again makes a new instance re-read all the code from scratch. `SendMessage` continues the context.
Verification bounces work back repeatedly, so this difference sets the total cost.

## Second rule: tell them to send results to main

**A teammate's final text does not reach me automatically.** Also measured — unasked, the agent finishes and
goes quietly idle.

Append to every instruction:

> Send the result via `SendMessage(to: "main")`.

Skip it and builder finishes the whole implementation with no report reaching me.

## Flow

```
0. Scale           ask: sequential or workflow. WAIT for the answer
1. Pick ticket     take a frontier ticket: open, unblocked, unclaimed
2. spec            plan into the ticket → Status: claimed
                   stuck → question to main → I ask the user
3. builder         implement per plan
4. Verifiers       verify-read · verify-run always
                   verify-look THE MOMENT the stage puts anything on screen — not at the end
5. Mutation sweep  sequential: the verifiers do it inline
                   workflow: fan out, one worktree per mutation (below)
6. Judgment        all pass → Status: resolved
                   any fail → batch the findings into ONE message to builder (back to 4)
7. Round report    ONE block per round, appended to the plan doc. NOT optional (below)
```

⚠ **Steps 0 and 7 are the two the user has actually complained about, and both are about them, not the
code.** Step 0 is the permission to spend; step 7 is *"여러 번 빌더가 도는데 각각 무엇을 개발하고 무엇을
수정하는지 말하지 않음. 그냥 여러 번 돌기만 함."* **Write it before the first round, not after the last.**

## Running the mutation sweep as a workflow

**Mutations are perfectly parallel and were the biggest cost.** Each one is: break one thing, run the nets,
read the colour, restore. **They are mechanical — no judgement — and they only ran in single file because two
agents breaking the same file at once invalidates both** (the user's own note: parallel mutators need isolated
copies).

⇒ **`isolation: 'worktree'` is the answer**, and it works here now: a fresh worktree has no `.godot` import
cache, which used to red every net in it, and `run_nets.ps1` now runs `--import` itself when it sees a `.gd`
with no `.uid`. **Re-branch from `main` right before starting** — a worktree freezes at the commit it branched
from, and two agents have already built against a stale base here.

**Split the work by what needs judgement:**

| Stage | Who | Model |
|---|---|---|
| Produce the mutation list — what to break, and which check must redden | verify-read | opus |
| Apply each mutation, run the round, report the colour and the failing labels | fan-out | haiku/sonnet |
| Interpret: which survived, is it a new layer or the same one, what closes it | verify-read | opus |

**The middle stage is the only one that fans out.** It is `break → 1.2s → restore`, and the whole point is
that thirty of them cost the same wall-clock as one.

```js
export const meta = {
  name: 'mutation-sweep',
  description: 'Apply each mutation in its own worktree, report which stayed green',
  phases: [{ title: 'Sweep' }],
}
// args = [{ id, file, find, replace, expect }] — produced by verify-read, not invented here
const VERDICT = { type: 'object', required: ['id', 'went_red', 'labels'], properties: {
  id: { type: 'string' }, went_red: { type: 'boolean' },
  labels: { type: 'array', items: { type: 'string' } },
  landed: { type: 'boolean' } } }

const results = await parallel(args.map(m => () => agent(
  `In this worktree: edit ${m.file}, replacing exactly:\n${m.find}\nwith:\n${m.replace}\n` +
  `CONFIRM THE REPLACEMENT LANDED before running anything — string replacement has silently matched ` +
  `zero times twice in this repo, and a mutation that never applied reads as a check that passed.\n` +
  `Then run: powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_nets.ps1\n` +
  `Report went_red, the exact failing check labels, and landed. Do NOT restore — the worktree is thrown away.`,
  { label: `mut:${m.id}`, phase: 'Sweep', schema: VERDICT, isolation: 'worktree', effort: 'low' })))

return { survivors: results.filter(Boolean).filter(r => r.landed && !r.went_red), all: results }
```

**Three things this must not lose**, all of them measured failures in this repo:
- **`landed` is not optional.** A mutation that did not apply is green for the wrong reason, and that has
  happened twice. The agent confirms the edit before it trusts the colour
- **Invert the instrument, not only the subject.** The sweep proves checks bite; it cannot prove a *check* is
  honest. Keep sending the shapes verify-read hunts by hand — a bound read out of the thing it measures, a
  spy that captures and never asserts, a hook that throws its own drawing away
- **No worktree writes docs.** Its edits live only in the copy. The sweep reports; the spawner writes.
  Afterwards `git worktree remove --force` + `prune` — automatic cleanup almost never fires (700MB in one
  night, measured)

## Verify **per stage**, not after the implementation ends

**If the plan is split into stages, loop 3↔4 per stage.** Never verify once at the end.

The reason is not cost but **role boundaries.** builder only checks "does it come up without errors"
(`agents/builder.md`) — so **the moment a stage finishes, nobody knows whether it matches the plan.**
Delaying verification stacks the next stage on top of an unknown one, and the rollback grows with the stage count.

### Models, and never lowering verification to save money

| Character | Who | Model |
|---|---|---|
| Judgment changes the outcome | spec · verify-read · verify-look · verify-run | opus |
| Executes a plan | builder | sonnet |
| Mechanical — reading values, finding files | — | haiku |

`net-tuner` pins sonnet in its own file, so the caller cannot override it. Nothing else is pinned.


The signature failure is "pretends to run", and verify-read · verify-look are what catch it. **And the
verifier is never the builder** — measured: a builder closed a hole in one file and left the identical one
open one file over; a verifier who had not built it found it.

**If builder "measures a value and reports it", that is crossing the boundary, not verification.** Do not use
that report as grounds for a judgment. Measuring your own work reads favorably. The verifiers exist to fill that gap.

**Do not pass builder's impressions to the verifiers.** The moment "builder said it looks good" is relayed,
it anchors them and they are no longer independent eyes. Pass only **what was written where, and where builder said it was unsure.**

## Stage by stage

**1. Before starting**

- If a ticket is already `Status: claimed`, finish that first. Never run two at once.
- If the doc's `## Acceptance` and `## Screen` are empty, stop here. The verifiers have no grounds to judge.

**2. spec**

Spawn and wait. When spec sends a question to main, relay it verbatim to the user. Do not answer on their behalf.

When the plan lands, **show it to the user once and get confirmation.** Wrong here and everything after it spins.

### Make spec write the checks against these four questions

**Plan 1's plan named 22 checks and the build needed 293.** The code was right every round; the checks were
shallow, and stage 2 bounced **four times** closing holes one layer deeper each time. Every single hole was
one of these four, so they go into the plan before the builder sees it:

- **Does the bound come from the thing it measures?** `t.eq(slots.size(), SLOT_COUNT)` moves both sides and
  passes at 10 or 12. Pin literals
- **Does it read only final state where an ordering was promised?** A beat that never pulls still ends with
  count 1
- **Does the spy assert everything it captures?** A captured-and-unread field reads exactly like coverage —
  four buttons with blank labels passed because only `rect` was ever read
- **Can the behaviour VANISH rather than diverge?** A/B catches "changed", never "gone". A hook that threw
  its own drawing away passed 54 of 54; the fix was cutting the terminal draw into a leaf hook so nothing
  above it can put a pixel on screen unwatched

**And require a named mutation per check, in the plan.** "Invert every check" as a sentence produced nothing;
the plans that named the mutation got them run.

**3. builder**

Hand over the plan. Remember where builder said "unsure". Tell the verifiers those spots.

**Two things builder does every round, for step 7's sake — say both in the spawn message:**

- **Quote the red labels verbatim in its round report.** Not "two checks failed" — the check names as the
  runner printed them, copied, plus the pass count, the seconds and the `[지문]` digest.
  ⚠ **That quote IS the "closed?" column's source**, so round N cannot be compared to round N+1 without it.
  **Nothing is written to disk for this** — no round-output files are left behind.
- **Commit at the end of its round**, one Korean sentence. ⚠ **In a worktree this is the ONLY thing that
  survives** — its doc edits never leave the copy, so the commit is the report's raw material

**4. The verifiers**

Spawn them **at once.** They look at different things, so there is no order.

⚠ **verify-look goes in the FIRST round that puts anything on screen — not at the end.** On plan 1 it was
held until the last stage, and with **279 checks green** it found three defects in minutes: the field had no
floor colour at all (`Look.BG` read in zero places, and `project.godot`'s key was nested inside its own
section so nobody read it), the victory beat was **a still frame for 62% of its length** while the HUD still
read `무리 39`, and the game filled **44% of the window**. Five of the previous round's seven surviving
mutations were the same family — a headline in the wrong band, labels 10,000px off, six rows past the left
edge. **All green. Numbers cannot see a picture**, and this repo has now measured that four separate times.

⇒ **Conversely, do not spawn it on a stage that draws nothing.** Plan 1's stages 1 and 2 changed no pixel the
player could reach; verify-read and verify-run were the whole job there. Spawning three verifiers on a stage
with nothing to see is a third of the round-trips for nothing.

Hand each:
- All three: design doc path, what builder wrote where
- verify-run · verify-look: acceptance criteria (`## Acceptance`, `## Screen`)
- verify-read: the spots builder was unsure about

### Freeze builder during verification

**If a verifier steps on the moment builder is editing a file, the entire verification result is void.**
It happened — the repo was broken **three times** while verify-run was observing (two parse errors, one broken
table monotonicity), all of them builder's intermediate saves.

⇒ Instruct builder: **"one chunk → nets green → report → halt until instructed."** That halt is the verification window.

### The editor bridge takes one agent at a time — and right now nobody has it

⚠ **The `godot` MCP server is switched off in `.claude/settings.local.json`, so `godot_*` exists in no session.**
verify-look captures with `tools/look/capture_map.gd` instead — a real window it opens and closes itself, no
bridge involved — so **none of the contention below applies until the user turns that server back on.** It is
kept because turning it back on brings all of it back.

`127.0.0.1:6550` holds **one client.** But each agent gets its own godot-mcp server instance, and
**going idle does not kill that connection.**

⇒ "Three verifiers at once" breaks here. verify-look actually failed to grab the bridge and **screen verification stopped entirely.**

#### "Don't use `godot_*`" does not prevent this

**A tool ban blocks calls, not connections.** Measured:

- **Three** godot-mcp clients were up on the machine, all spawned **at session start** — independent of any tool call
- They stayed alive through 30 minutes with no editor, and one grabbed 6550 **immediately** after an editor came up. No evidence that session ever called `godot_*`
- The client's own message states the retry loop — `"This client keeps retrying and will connect once the other disconnects"`. The refusal count grows **on its own** between calls
- Restarting the editor to re-run the race gave **the same winner again**

⇒ **The only reliable fix is not attaching the godot MCP server to any agent except the one using the bridge**,
not banning the tool in a prompt. That is why `agents/verify-run.md` and `agents/verify-read.md` say "headless only".

If it still blocks, **a godot-mcp (node) process from another session** is holding it. Killing it frees the bridge
but **cuts someone else's tools, so ask the user.** Never touch the parent `claude.exe` — that is the session itself.

#### When blocked, do not take the user's input

If the bridge won't come, **stop there and report to the user.** Launching the game via CLI, focusing the window
and injecting keys is **forbidden** — the user is on the same machine.

It happened. Global key injection (`keybd_event`) hit Windows foreground lock, the game never got focus, and
**the keys went into the user's Chrome.** The user stopped it on the spot.

**"Stopped, couldn't do it" beats "did it by taking the user's input".** What you couldn't see, write down as "couldn't see".

**Split this way and they run concurrently:**

| Who | How |
|---|---|
| **verify-look** | **Opens its own window via `tools/look`** (the bridge only if the server is re-enabled). Only this agent sees the screen |
| **verify-run** | **Headless only** — `Godot_*.exe --headless --script` (same as `run_nets.ps1`). Separate process, no collision |
| **verify-read** | Reads code. No conflict |
| **builder** | `godot_*` **forbidden** (`agents/builder.md`) |

If it still blocks, **an idle godot-mcp process is holding it.** Cleaning those up is allowed, but
**never kill the editor itself (`Godot_*.exe --editor`)** — the user launched it, and screen verification dies with it.

### Make verify-read mutate

"The nets are green" is not "the nets measure something". Have them **delete a guard and check that it goes red.**
That is how **two idle-spinning nets** and **a shader fully broken yet still green** were caught.

Mutation breaks a file briefly. **One at a time, restored immediately via `try/finally`** — otherwise the verifier
causes the "editing during verification" problem above.

**5. Judgment**

- **All pass** → set the ticket's `Status:` to `resolved`, append the answer under `## Answer`, and add one line to the map's Decisions-so-far. Report to the user.
- **Fail** → summarize the failures and `SendMessage(to: "builder")`. Back to 4.
- **Cannot judge** (criteria empty or ambiguous) → return to spec, or ask the user.

**6. The round report — you write it, in the main tree, after every round**

Not at the end. Not by the builder. **Append one block to the ticket's `## Round log`.** It stays in the ticket when the ticket resolves. Sources: `changed` from `git show --numstat` · `why` from the previous round's red check labels ·
`closed` is whether that label is green now. **"closed / not closed" is the whole point of the table** —
print `not closed` even when it is empty, because an absent line reads as an absent problem.
⚠ **An agent's own summary is not the report** — measuring your own work reads favourably. The shape:

```
## Round log

### Round 3 — builder-A

changed     src/sim/battle.gd +48 -12 · src/look.gd +9 -0        <- git show --numstat
why         red in round 2: `연출: 돌진이 항상 0이 아니다`         <- builder's round-2 report, quoted
closed      that label green in round 3
not closed  none
nets        1948 checks · 6.9s · fingerprint A31F...
```

⚠ **`net_process` reads this shape literally**: the section heading is `## Round log`, each block is
`### Round N — who`, and **all five field names must appear in every block.** It also reddens on a plan
that carries an `OPEN questions` section without a `**Sent to the user**:` line. **Four plans are
grandfathered and that list is pinned at four — plan number five is checked.**

⚠ **Print `not closed` even when it is empty.** An absent line reads as an absent problem.
⚠ **Never write it from your own recollection of what the agents said.** Measuring your own work reads
favourably; file names, line counts and check labels do not. **If builder did not quote the red labels,
say the column is missing** — do not fill it in from memory, and do not go re-run the round to reconstruct it
(a rerun measures a different tree, which the `[지문]` digest will say out loud).

## Rollback limit

If the same feature has bounced back **3 times** without passing, stop and take it to the user.

Keep going and builder starts bending the code to get past verification. That is the most common path to fake code.

## When to ask the user

- spec or builder sent a question to main
- verify-look can't make a subjective call like "does it look strong"
- rollbacks passed 3
- the plan has to go outside the design doc's scope

**Batch them into one ask.** Pulling the user in repeatedly costs more.

## Resuming

- A `claimed` ticket exists and the team is dead: read its progress and spawn only the agents you need.
- Want to re-verify only: spawn the three verifiers. Leave builder alone.
- Team is alive: just `SendMessage`.

---

## Running builders in parallel — what was measured, before the doc was deleted

**Never run.** These are the numbers and traps a first attempt needs; the full write-up was deleted on
2026-08-19 as a doc nobody had used.

- **The net round is not the bottleneck.** A round is ~6.7s; one mutation is 1–2 min (the round is 6–12% of
  it) and one plan is **24 agent round-trips**. ⇒ **Most of the wall clock is an agent reading and typing.**
  Making the runner faster changes nothing — it was taken from 6.1s to 3.7s once and the conclusion held
- ⚠ **One property of the runner is not for sale**: each net gets its own process so an amnesty stays inside
  its own net. Measured — net 1's forged bark was covered by net 3's declaration when they shared one
- **The mutation sweep is the bigger win.** No judgement, no merge, no ceiling — the worktrees are thrown
  away, so thirty cost one's wall clock. **If only one of the two ever gets built, build the sweep**
- **Worktree round trip**: re-branch from `main` immediately before starting · a fresh worktree has no
  `.godot` cache and `run_nets.ps1` runs `--import` itself (~2.5s) · finish with
  `git worktree remove --force` + `prune` (700MB in one night, measured)
- ⚠ **BLOCKING, unfixed**: `run_nets.ps1`'s timing cache is `tockbon_net_timings.json` in `$tmp` with
  **no per-tree scoping**, while every other temp path there is `_$PID`-suffixed. N worktrees read, merge and
  overwrite one file; the write sits in a swallowed `try/catch`, so losses are silent, and a worktree under
  CPU contention **reorders the main tree's next round.** Correctness is unaffected; **every timing
  measurement is not.** ⇒ Append the repo root's hash to that filename before running anything parallel
- **What collides is CPU, not files**: the runner runs `Min(16, cores)` wide, so three worktrees put 48
  processes on 16 threads. **How many builders at once is not measured** — take the cap from the first run
