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
## What happens next (decided by the user, 2026-08-15)

**Plan 4, then regroup.** That was the call, and **plan 4 is now built and green** — so what is left of it is
the regroup: nothing was re-planned, re-designed or re-scoped before the grassland field landed, and the
whole thing is reviewed now that there is a run to play.

⚠ **Nobody has played it.** Seven verifiers found eight defects, sixteen unmeasured surfaces and fifteen
doc/code disagreements after the build reported green; all eight defects are fixed and every unmeasured
surface named there is now measured. **None of that is acceptance**: a green round is not a user saying it
read right, and this folder's `3.done` means implementation finished and nothing more.

**Art is on the regroup side of that line, not the plan-4 side.** The user raised it and it is theirs to
decide; the state today is that **`src/` loads zero images** and every body is drawn by `field_view.gd`.
Swapping to pictures is a rewrite of that one file plus a column in `Parts` plus two nets — contained, but
not a file swap. Plan 4 keeps drawing by code.

| Folder | Contents |
|---|---|
| `1.ready` | **[Grassland, the whole loop](1.ready/grassland-whole-loop.md)** — the index. **All four plans under it are built** |
| `2.active` | **empty** — nothing is being built right now |
| `3.done` | **[연출 한 판](3.done/presentation-pass.md)** — plan 5, from [the presentation audit](../design/presentation-audit-ko.md). 22 nets · 2420 checks. Twelve things that were happening and were not on screen now are; **one rule change rode in it** (a corpse takes several bites and quitting keeps what you ate). ⚠ **Built and unlooked-at** — every one of its eight acceptance questions is an eye, including the three older ones it exists to unblock (plan 4's arena, plan 2's *does losing a fat clone hurt* and *does the hold read as an act*). **A second review found 29 problems in the built code and 20 were repaired**; what changed from the plan text is in the doc's 「지어진 뒤」 · **[The grassland field](3.done/grassland-field.md)** — plan 4. 22 nets · 1889 checks. **Unplayed, and the arena has no view at all** — its own acceptance question (*does the arena closing read as the run's last act*) cannot be answered by this build, because there is nothing on screen to read · **[The round trip](3.done/proto-round-trip.md)** — the first prototype. Built, played, and the fun confirmed · **[The run shell](3.done/run-shell.md)** — plan 1, built in three stages. ⚠ **Nobody has played it on its own** · **[Hands and commands](3.done/hands-and-commands.md)** — plan 2. 16 nets · 514 checks. **Played: the keys are accepted, the picture is not, and the three questions that decide the plan are still unheard** · **[The body and its parts](3.done/body-and-parts.md)** — plan 3. 18 nets · 889 checks, every mutation red. **Looked at (six defects, in the doc); unplayed.** ⇒ **Plan 4 unblocked its acceptance**: the corpse beat now appends to `World.species_eaten`, off the CROW rather than the horse ([why](../decisions/the-crow-gives-three-parts.md)) — the common creature, standing still on the opening minute — so a run offers cards. Whether the body visibly becomes a horse is still unasked |

The old game was deleted on 2026-08-12 (`../next-game.md`) and every plan went with it — thirty-four docs
describing a game that no longer exists. **They are recoverable at the tag `v1-sim` and should not be
recovered**: each was written against folder contracts and a tick rate the new game does not have.

⚠ **The four plans were written on 2026-08-14 to a standard the last one did not meet.** The user's report was
that **implementers keep coming back with questions**, and the cause was that
`grassland-whole-loop` was a table of pointers into design docs whose own *Open* lists were twenty items long.
⇒ **A plan carries data shapes, function names, key bindings, literal numbers and per-piece acceptance**, and
what is genuinely undecided is listed in one place where it can be seen not to block the build.

⇒ **`proto-round-trip` is the one exception to this folder's own rule about acceptance.** It sits in `3.done`
*and* carries a passed acceptance, because the user played it and said so — normally that half lives in a
`design/` header, and it is written in both places on purpose: this doc is the record of what the play
session changed.
