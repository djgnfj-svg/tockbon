---
name: build-feature
description: Implements one design doc with a team. Use when the user says "이거 구현하자" "만들어줘" "개발 시작" "let's build this", or points at a doc in docs/plans/1.ready/. Spawns and coordinates five agents — spec, builder, verify-run, verify-look, verify-read. Also used for retries, resuming, and re-running verification only.
---

# Running the feature team

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
1. Pick design     choose a doc in 1.ready/
2. spec            plan → move to 2.active/
                   stuck → question to main → I ask the user
3. builder         implement per plan
4. Three verifiers verify-run · verify-look · verify-read, together
5. Judgment        all pass → 3.done/
                   any fail → SendMessage the details to builder (back to 4)
```

## Verify **per stage**, not after the implementation ends

**If the plan is split into stages, loop 3↔4 per stage.** Never verify once at the end.

The reason is not cost but **role boundaries.** builder only checks "does it come up without errors"
(`agents/builder.md`) — so **the moment a stage finishes, nobody knows whether it matches the plan.**
Delaying verification stacks the next stage on top of an unknown one, and the rollback grows with the stage count.

**If builder "measures a value and reports it", that is crossing the boundary, not verification.** Do not use
that report as grounds for a judgment. Measuring your own work reads favorably. The verifiers exist to fill that gap.

**Do not pass builder's impressions to the verifiers.** The moment "builder said it looks good" is relayed,
it anchors them and they are no longer independent eyes. Pass only **what was written where, and where builder said it was unsure.**

## Stage by stage

**1. Before starting**

- If something is already in `docs/plans/2.active/`, finish that first. Never run two at once.
- If the doc's `## Acceptance` and `## Screen` are empty, stop here. The verifiers have no grounds to judge.

**2. spec**

Spawn and wait. When spec sends a question to main, relay it verbatim to the user. Do not answer on their behalf.

When the plan lands, **show it to the user once and get confirmation.** Wrong here and everything after it spins.

**3. builder**

Hand over the plan. Remember where builder said "unsure". Tell the verifiers those spots.

**4. Three verifiers**

Spawn all three **at once.** They look at different things, so there is no order.

Hand each:
- All three: design doc path, what builder wrote where
- verify-run · verify-look: acceptance criteria (`## Acceptance`, `## Screen`)
- verify-read: the spots builder was unsure about

### Freeze builder during verification

**If a verifier steps on the moment builder is editing a file, the entire verification result is void.**
It happened — the repo was broken **three times** while verify-run was observing (two parse errors, one broken
table monotonicity), all of them builder's intermediate saves.

⇒ Instruct builder: **"one chunk → nets green → report → halt until instructed."** That halt is the verification window.

### The editor bridge takes one agent at a time

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
| **verify-look** | **Uses the editor bridge.** Only this agent sees the screen |
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

- **All pass** → move the doc to `3.done/` and fix `**Status**:`. Report to the user.
- **Fail** → summarize the failures and `SendMessage(to: "builder")`. Back to 4.
- **Cannot judge** (criteria empty or ambiguous) → return to spec, or ask the user.

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

- A `2.active/` doc exists and the team is dead: read the doc's progress and spawn only the agents you need.
- Want to re-verify only: spawn the three verifiers. Leave builder alone.
- Team is alive: just `SendMessage`.
