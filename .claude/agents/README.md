# .claude/agents — the five, and the order they are called in

**Six definitions live here.** Five of them are one team, and the sixth (`net-tuner`) is called on its own
when a round gets slow. ⚠ **The skill that used to drive this team was deleted on 2026-08-22** as 394 lines
whose verification half was already in `how-nets-lie`. **This page is what was worth keeping.**

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

**Judgment stays on opus** — spec and all three verifiers. Lowering a verifier to save money is how a round
goes green for the wrong reason. `net-tuner` pins its own model so the caller cannot override it.

⚠ **The godot MCP server is off**, so the screen verifier opens its own window with a capture script it runs
directly. ⚠⚠ **That script does not exist right now** — `tools/look/` went with the cell game and `src/` is
empty, so **the first stage that draws anything writes it.** If the server is ever switched back on,
`127.0.0.1:6550` holds **one client at a time** and three verifiers at once will fight over it — that is why
the two headless verifiers are told headless-only.
