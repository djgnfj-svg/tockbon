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

**Two docs in `1.ready`, and neither is a build order a builder could pick up.** That is worth knowing before
opening the folder looking for work.

| Doc | Why it is not startable |
|---|---|
| [1.ready/monsters-bigger-boxes.md](1.ready/monsters-bigger-boxes.md) | Part of it landed by another route, and its cost model was **re-measured and came out wrong in the direction that favours the change**. What remains is **a fork only the user can take** — regenerate three sheets at 1.5×, double them, or raise the zoom |
| [1.ready/stage2-water.md](1.ready/stage2-water.md) | **A skeleton, and it says so.** The shape and prerequisites are mapped; **23 `TBD`s** remain, four calls are marked `[mine]` (made without the user), and the map width — the number that sets the painting labour — is unset |

**`2.active` is empty.** Nothing is being built.

⇒ **The next piece of work starts with a decision, not with code.** The design side's counterpart to this —
which concepts are blocked on what — is [../design/README.md](../design/README.md), "The four docs at
`Implemented: none`".

**Skeleton first, flesh later**: a `TBD` in a design doc is not a reason to refuse to implement (CLAUDE.md).
`stage2-water.md`'s TBDs are listed because they are *choices*, not because every one blocks the first line
of code.
