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

## The state today — **all three folders are empty**

| Folder | Contents |
|---|---|
| `1.ready` | **empty** |
| `2.active` | **empty** |
| `3.done` | **empty** |

**Every plan this repo ever had was deleted on 2026-08-17**, together with the design docs describing the two
games those plans built. Nothing was lost that mattered: what the plans *measured* is distilled into
[what two dead games left behind](../lessons-from-two-dead-games.md), and the plan text itself is recoverable
at the tags `v1-sim` and `v2-openfield`.

⚠ **Do not recover a plan from either tag.** `v1-sim`'s plans were written against integer determinism and a
20Hz tick; `v2-openfield`'s were written against a host, an open field, and a swarm the player steers. The
current game — a cell autobattler — has none of those, so a recovered plan quietly re-imports constraints
that no longer exist.

---

## What a plan has to carry

**Written down because the last set failed this test.** The user's report was that
**implementers keep coming back with questions**, and the cause was a plan that was a table of pointers into
design docs whose own *Open* lists were twenty items long.

⇒ **A plan carries data shapes, function names, key bindings, literal numbers, and per-piece acceptance.**
What is genuinely undecided goes in one place, where it can be seen not to block the build.

**The live design is [the cell army GDD](../design/cell-army-gdd.md)** (Korean: `cell-army-gdd-ko`).
The next plan comes from there.
