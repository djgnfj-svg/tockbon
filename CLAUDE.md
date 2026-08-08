# tockbon

Loaded into every session and every agent. **Keep only what applies to everyone.**

## Language — answer the user in Korean, always

**Every reply to the user is in 한국어.** Even when they write in English — they cannot read English.

Docs, comments and prompts are English. **Korean is what the user reads**: their own commands,
commit messages, in-game text (material names, HUD), **net check labels** and the net runner's console output.
Details and the terminology table are in `docs/plans/3.done/english-migration.md`.

**A `push_error` message and the `t.expect_error` that forgives it are one unit** — they are matched by plain
substring, so translating one side alone leaves the bark undeclared and the wrapper's silence check fails.
Change both in the same edit.

## Reply rule — **the whole reply under 50 characters**

"Be brief" didn't work, so it is a number now (decided by the user). Long replies go unread and block work.

- **Not one sentence — the entire reply is 50 chars.** Over that, write it in a doc and name the file
- **No tables or lists in chat.** Docs carry detail
- **Don't ask.** Look for the answer in the conversation first. If you must ask, one sentence
- **No emoji.** Bold is the only emphasis
- **No dates.** "Decided by the user" is enough. Only a reversed decision needs one
- **Cut every word that isn't load-bearing** — in docs and in chat

## Where things live

| Looking for | Go to |
|---|---|
| How nets die · mutation testing | `.claude/agents/verify-read.md` |
| Net speed · runner internals | `.claude/agents/harness-manager.md`, `tests/run_nets.ps1` |
| Headless observation traps | `.claude/agents/verify-run.md` |
| Editor bridge · screenshots | `.claude/agents/verify-look.md` |
| Team operation · when to verify | `.claude/skills/build-feature/SKILL.md` |

| Doc | Question it answers |
|---|---|
| `docs/GDD.md` | What is this game |
| `docs/design/` | What does this feature look like |
| `docs/decisions/` | **Why was that not done** |
| `docs/plans/` `1.ready` `2.active` `3.done` | What are we building now |

`design/` and `decisions/` never move between folders. Only `plans/` moves.

**Never state the same thing twice.** GDD holds the face and points at the detail.
A value counted in two places will diverge.

**When a fork is taken, record the rejected branch in `docs/decisions/`** — what was dropped
and why, nothing else. Format lives in that folder's README.

**When a feature comes up in conversation, create a `docs/design/` doc and add one row to its README.**
Head the doc with two lines, `Implemented` and `Accepted` — without them, "written down" reads as "exists".

**Moving a `plans/` doc means three edits**: fix the `**Status**:` line inside it (there is exactly one),
fix every link pointing at it, and report all three folders as a table. **Links leak every single time.**

## Acceptance goes into the doc the moment it happens

When the user says "confirmed" or "I can see it", whoever heard it writes it under the
design doc's `Accepted` section immediately.
**Conversations are lost; the repo is kept.** The next session sees only the repo.

**`3.done/` means "implementation finished", not "acceptance passed".**

**A verifier running in an isolated worktree cannot write docs** — its edits live only in the copy.
The spawner writes; the verifier only reports. Afterwards `git worktree remove --force` + `prune`
(automatic cleanup almost never fires — 700MB in one night, measured).

**Skeleton first, flesh later.** Do not demand every `TBD` in a design doc be filled before implementing.

## Folders are contracts

| Folder | Contract | Base type |
|---|---|---|
| `src/sim/` | **Integer determinism.** No float · `Vector2` · `sqrt` · `sin` · `randi` · `OS.` · `Time.`. Knows nothing of the scene tree | `RefCounted` |
| `src/actor/` | float allowed. Still knows nothing of the scene tree | `RefCounted` |
| `src/view/` | Screen only. Reads the sim, never writes it | `Node` |
| `src/stage/` | Shell — tick loop · input · HUD · stage. Will not survive into the real game | `Node` |

`fire_cmd()` in `src/actor/aim.gd` is the single door into integer land.
Presentation constants live in `src/view/fx_tuning.gd`, sim constants in `src/sim/sim_tuning.gd`.
Nets scan the folders recursively — no hand-maintained registry.

## Comments

- **Write why doing it differently dies silently.** What the code does, the code says
- Keep measurements where they were taken
- If the same explanation appears in two files, move it to one
- Point at a doc; never summarize one

## No fake code

Code that pretends to work is worse than code that doesn't.

- Hardcoding for this input or this test only
- Returning a plausible value instead of computing one
- Reporting a stub as finished
- Swallowing an error so it looks like success
- **Screen changes but sim doesn't (or the reverse)** — the signature fake

If you can't do it, say you can't.

## No fake nets

When the label claims more than the check measures, that green is a false guarantee.

**Invert every new check.** An uninverted check proves "it runs", not "it measures".
**If the inversion doesn't bite, suspect the check last — first confirm the mutation actually landed.**
String replacement has silently matched zero times, twice.

Failure shapes are listed in `verify-read.md`. Only these three live here — **they survive
even after you confirm every mutation goes red**:

- **A check that reads only final state cannot measure an ordering contract.** Iteration order was reversed, final state was identical, three checks stayed green. Add a check that measures the process
- **A/B comparison catches "diverged", never "vanished".** Fold two paths into one and `scan == scan` — 39 checks all green. "Slower without it" is caught only by timing
- **A loop whose condition is false from the start never runs the check at all.** A settle loop passed with zero iterations. Assert the iteration count too

## Running the nets

1. **"N passed" is not green.** `load()` returns non-null on a parse failure, so the count holds even with `src/` broken. Only the final `[wrapper]` line decides
2. **If `[race]` prints, distrust the result — green included.** Running while someone edits reads half-written files
3. **Each net runs in its own process, in parallel.** Not for speed — for honesty: amnesty stays inside its own net. Do not break this property
4. **If a full round exceeds 10s, call `harness-manager`.** Slow means verification gets skipped, and then none of the above matters

## Agent models

The caller decides `model`. A model pinned in the definition file wins (`harness-manager` = sonnet, the only one).

| Character | Model |
|---|---|
| Judgment changes the outcome — spec · verify-read · verify-look · design | opus |
| Executes a plan — builder | sonnet |
| Mechanical — reading values, finding files | haiku |

**Never lower verification to save money.** The signature failure is "pretends to run",
and verify-read · verify-look are what catch it.

## godot MCP

The bridge (`127.0.0.1:6550`) accepts one client. **`godot_*` is verify-look only.** Everything else is headless.
The server reconnects on its own even if no tool is called — resolve is not a mechanism. The fix is in `build-feature/SKILL.md`.

**Never take the user's mouse or keyboard.** No window focus, key injection, or OS screen capture.
The user is on the same machine.
**`godot_*` screenshots are the exception** — the editor captures its viewport directly and steals no input.

Check three things before launching:

1. Is the editor already up
2. The game window steals focus. If the user is working, ask
3. **Is there a path for the thing you want to see to reach the screen** — the most common miss.
   Water material and color were both in, but nothing called `set_water`, so not one cell appeared.
   If the path is missing, wire it into the stage first

**If you can't grab the bridge, stop and report.** Killing someone else's idle `godot-mcp` is not the answer —
it once killed this session's server too and the tools vanished entirely.
Without the bridge the game can `save_png()` itself. `--headless` cannot capture.
**Close any editor you launched when the session ends.**

### Closing the editor is not enough — `godot-mcp` (node) survives

**Agents do not launch that node.** Claude Code starts it automatically when a session opens,
and **it does not die when the session ends.** Measured: no editor running, **6 node processes** alive.

**The symptom is not "can't grab the bridge" — it is "the user can't see the screen".**
The moment an editor launches, all of them grab 6550, and the losers **retry forever**,
flooding the editor output panel with `Another client is already connected` until nothing else is readable.

**Count the competitors before launching verify-look:**
```powershell
Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object { $_.CommandLine -match 'godot' }
```
**More than one: tell the user before launching the editor.** Finding out afterwards is finding out too late.

Killing them stays the user's call — it also cuts this session's server (`godot_*` disappears
entirely) and new nodes restart immediately (killed 6, 2 came back). **It does not get clean.**
