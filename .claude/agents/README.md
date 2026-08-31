# .claude/agents — four that build, and one that goes outside

**Five definitions live here.** **`research` is the only one that leaves the repo.**

## ⚠⚠ **`spec` is gone — planning is a conversation** (2026-08-29, the user)

***"I do not think that agent is needed — the process is splitting into tickets, talking one ticket
through with me, turning that into a planning document, and handing it to the builder."***

**`spec` read a ticket and planned it alone.** ⚠⚠ **Everything the user said that was not written into
the ticket never reached it**, so the plan carried the ticket's gaps and **builder filled them by
guessing.** An agent cannot have the conversation the plan depends on.
⇒ **The main session interviews the user and writes the plan into the ticket.** `plan-into-ticket` holds
what to ask and the shape it takes; `adversary` attacks the result.

## ⚠⚠ **Reading this repo is not an agent's job any more** (2026-08-29, the user)

**`lookup` read the inside and `research` reads the outside, and the split was set on 2026-08-27.** ⚠⚠
**`lookup` was deleted after 149 sessions and ZERO calls** — nothing ever sent it, because the skill that
was supposed to send it never fired either. **An agent nothing can reach is not a prepared path, it is
an unmeasured one.**
⇒ **The main session reads `src/`, `docs/`, the nets and `git log` itself.** `plan-into-ticket` carries
the four questions and where to find each.
⚠ **The outside half stands**: `research` never answers from memory, and `scout` is what sends it.

## ⚠⚠ **`sculpt` is gone — Blender is back in the main session** (2026-08-29, the user)

**It was pulled out on 2026-08-27 because the 3D ate the conversation**, and it went back because **twice
it did the work and sent no result**, so the caller measured everything by hand anyway. The agent saved
context and spent a round each time.
⇒ **What it knew is `docs/manual/blender.md`** — the traps, the mirror rule, the loop and the
numbers. **Read that before touching a mesh**; the reading step is no longer somebody else's.
⚠ **`tools/blender/` was deleted 2026-08-31.** The meshes are `.blend` originals in `blend/` now, and
that page is where the rule lives.

## ⚠ **`net-tuner` is gone too** (2026-08-29, the user: *"when it gets long, we check it then"*)

**Called once in 149 sessions**, and it was the second-largest file here. **When a round of nets gets slow
or a net spins idle, measure it in the main session at that moment** rather than keeping a specialist
standing by for it.

## The order

```
(main)      interviews the user on the ticket, writes the plan into it, sets Status: claimed
adversary   ALWAYS, and before builder — attacks the plan. No small-ticket exception
builder     implements per that plan. One chunk → nets green → report → HALT
verify      always. Reads it to prove it wrong, then runs it headless. Both passes, never one
verify-look the moment anything reaches the screen, and not before
judgment    all pass → Status: resolved + the answer under ## Answer + one line on the map
            any fail → batch the findings into ONE message back to builder
```

⚠⚠ **`verify` was two agents until 2026-08-29** — `verify-read` and `verify-run`, merged because three
verifiers on every ticket was too much ceremony. **The split survives as two passes inside one agent**,
and it has to: reading catches "runs fine, but only for this case", running catches "reads plausibly,
fails when run", and **fake code is always one of the two.**

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

**Judgment stays on opus** — `adversary`, `verify` and `verify-look`, and ⚠⚠ **each says so in its
own frontmatter** (2026-08-27). Until then this paragraph was the only thing holding the rule: the files
named no model at all, so they silently took whatever the session happened to be running, and the promise
was kept by luck. Lowering a verifier to save money is how a round goes green for the wrong reason.
⚠ **`builder` alone names no model** and takes the session's.

⚠ **The godot MCP server is off**, so the screen verifier opens its own window with a capture script it runs
directly. ⚠⚠ **`tools/look/` holds five scripts and none photographs a fight** — read that folder's README
before writing a third. If the server is ever switched back on, `127.0.0.1:6550` holds **one client at a
time**, which is why the headless verifier is told headless-only.
