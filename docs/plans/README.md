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
| `1.ready` | **[Grassland, the whole loop](1.ready/grassland-whole-loop.md)** — one stage entered bare and left with a finished body. Built thin everywhere on purpose |
| `2.active` | empty |
| `3.done` | **The round trip** — the first prototype. Built, played, and the fun confirmed |

The old game was deleted on 2026-08-12 (`../next-game.md`) and every plan went with it — thirty-four docs
describing a game that no longer exists. **They are recoverable at the tag `v1-sim` and should not be
recovered**: each was written against folder contracts and a tick rate the new game does not have.

⇒ **The one doc here is the exception to this folder's own rule about acceptance.** It sits in `3.done`
*and* carries a passed acceptance, because the user played it and said so — normally that half lives in a
`design/` header, and it is written in both places on purpose: this doc is the record of what the play
session changed.
