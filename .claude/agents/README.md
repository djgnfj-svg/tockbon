# .claude/agents — the build team, and the two that only read

**Nine definitions live here.** Five of them are one build team; `net-tuner` is called on its own when a
round gets slow, **`sculpt` owns the 3D**, and **`lookup` and `research` only find things out.**

## ⚠⚠ The two readers, and why they are two

**Inside and outside are different jobs and they were one blur until 2026-08-27** (the user: *"there
should be one that checks the documents inside and one that finds the facts outside the repo — how
others do it"*). **The skills used to say "dispatch a subagent" with no name**, so whoever ran them
picked whatever was nearest and the two halves got mixed.

| Agent | Reads | Never |
|---|---|---|
| **`lookup`** | This repo — `src/`, `docs/`, the nets, `git log` | **Never touches the web** |
| **`research`** | Outside — primary sources, with links | **Never answers from memory** |

**`survey` sends `lookup`. `scout` sends `research`. `grilling` sends whichever the question needs.**
⚠ **Neither writes a file, edits anything, or decides.** Their whole output is findings.

⚠⚠ **`sculpt` exists because the 3D ate the conversation** (2026-08-27, the user: 「앞으로 3d 만드는거
에이전트로 빼자 컨텍스트를 너무 먹는거 같은데」). Baking a mesh is a loop of change · bake · look · miss ·
change again, and every turn of it lands a render and a tool dump in the main window. **Send it out and
take back the picture and the numbers.**
⚠ **It carries five traps that each cost a round** — the MCP client that hangs, the Godot import cache
that serves yesterday's island in silence, face winding deciding whether a face exists, swallowed
geometry errors, and a shadowed variable name. **Read it before doing any Blender work yourself.** ⚠ **The skill that used to drive this team was deleted on 2026-08-22** as 394 lines
whose verification half was already in `how-nets-lie`. **This page is what was worth keeping.**

✅ **A driver came back on 2026-08-24: the `build-loop` skill**, and it is deliberately thin — it reads
this page's order and calls the agents, nothing more. **The user says 「짜줘」 and it runs.**
⚠⚠ **It is model-invocable on purpose**: the imported planning skills are human-typed-only, which is
what kept this team from ever being called. **The one place it stops is after the plan, for the user to read.**

## The order

```
spec        plans into the ticket, sets Status: claimed. Stuck → the question goes to the user, unanswered
builder     implements per that plan. One chunk → nets green → report → HALT
verifiers   verify-read + verify-run always. verify-look THE MOMENT anything reaches the screen
judgment    all pass → Status: resolved + the answer under ## Answer + one line on the map
            any fail → batch the findings into ONE message back to builder
```

## The four rules that cost rounds to learn

- ⚠⚠ **The verifier is never the builder.** Measured: a builder closed a hole in one file and left the
  identical one open one file over; a verifier who had not built it found it. **If builder "measures a value
  and reports it", that is crossing the line, not verification**
- ⚠ **Do not pass builder's impressions to the verifiers.** The moment 「builder said it looks good」 is
  relayed they are no longer independent eyes. Pass **what was written where**, and **where builder said it
  was unsure** — nothing else
- ⚠ **Verify per stage, never once at the end.** Delaying it stacks the next stage on an unknown one, and the
  rollback grows with the stage count. **Conversely, do not spawn the screen verifier on a stage that draws
  nothing** — that is a third of the round-trips for nothing
- ⚠ **Bounced three times without passing → stop and take it to the user.** Past that, builder starts bending
  the code to get past verification, which is the most common path to code that pretends to work

**Judgment stays on opus** — spec and all three verifiers, and ⚠⚠ **each of the four now says so in its own
frontmatter** (2026-08-27). Until then this paragraph was the only thing holding the rule: the files named
no model at all, so they silently took whatever the session happened to be running, and the promise was
kept by luck. Lowering a verifier to save money is how a round goes green for the wrong reason.
`net-tuner` pins sonnet on purpose — it measures, it does not judge.

⚠ **The godot MCP server is off**, so the screen verifier opens its own window with a capture script it runs
directly. ⚠⚠ **Two such scripts exist again** — `tools/look/` was rebuilt after the cell game took the old
ones, and `src/` runs. **Read that folder's README before writing a third.** If the server is ever switched back on,
`127.0.0.1:6550` holds **one client at a time** and three verifiers at once will fight over it — that is why
the two headless verifiers are told headless-only.
