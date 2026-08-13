# docs/plans — the only folder that moves

`design/` holds concepts and `decisions/` holds rejected forks; **neither ever changes folder.** This one does,
and the folder a doc sits in *is* its status.

| Folder | Means | Who puts it there |
|---|---|---|
| `1.ready` | **A builder could start on it** | whoever finishes the design |
| `2.active` | Someone is building it right now | the build team, on start |
| `3.done` | **Implementation finished** — *not* "accepted" | the build team, on finish |

**`3.done` is not an acceptance record.** A doc lands there when the code is in and the nets are green; whether
the user has ever looked at the result is a separate axis, kept in `design/` headers. Merge the two and
"it runs but nobody has looked" stops being expressible — CLAUDE.md's own note about where this repo got burned.

**Moving a doc is three edits**: the `**Status**:` line inside it, every link pointing at it, and a report of
all three folders. **Links leak every single time** — `net_citations` catches the path form, not a stale claim.

---
## What is open right now

| Folder | Contents |
|---|---|
| `1.ready` | **[Grassland, the whole loop](1.ready/grassland-whole-loop.md)** — the index, and **three plans still under it, built in order**: [hands and commands](1.ready/hands-and-commands.md) → [the body and its parts](1.ready/body-and-parts.md) → [the grassland field](1.ready/grassland-field.md) |
| `2.active` | empty |
| `3.done` | **[The round trip](3.done/proto-round-trip.md)** — the first prototype. Built, played, and the fun confirmed · **[The run shell](3.done/run-shell.md)** — plan 1, built in three stages. 14 nets · 293 checks. ⚠ **Nobody has played it** |

The old game was deleted on 2026-08-12 (`../next-game.md`) and every plan went with it — thirty-four docs
describing a game that no longer exists. **They are recoverable at the tag `v1-sim` and should not be
recovered**: each was written against folder contracts and a tick rate the new game does not have.

⚠ **The four plans were written on 2026-08-14 to a standard the last one did not meet.** The user's report was
that **implementers keep coming back with questions**, and the cause was that
`grassland-whole-loop` was a table of pointers into design docs whose own *Open* lists were twenty items long.
⇒ **A plan carries data shapes, function names, key bindings, literal numbers and per-piece acceptance**, and
what is genuinely undecided is listed in one place where it can be seen not to block the build.

⇒ **The one doc in `3.done` is the exception to this folder's own rule about acceptance.** It sits in `3.done`
*and* carries a passed acceptance, because the user played it and said so — normally that half lives in a
`design/` header, and it is written in both places on purpose: this doc is the record of what the play
session changed.
