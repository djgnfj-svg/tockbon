# The next game

**Status**: **a cell autobattler.** Islands on a node map, a squad of square cells, and the island's
특산물 bolted onto the soldiers that survived it. **Target: end of August 2026** — a finished thing,
not a shippable product.

⇒ **The design lives in [the cell army GDD](design/cell-army-gdd.md)** (Korean: `cell-army-gdd-ko`)
**and nothing is built yet.** `src/` was emptied on 2026-08-16 at the tag `v2-openfield`.

**One line**: **먹을 것을 고르러 간다.** (*Going out to pick what to eat.*)

**Why cells, still**: almost no art is needed — a square with parts drawn on it is code, not pixels — and
the theme survived two direction changes because of that. **What did not survive** was "you steer a
growing mass": there is no host to steer any more, the battle is automatic, and the hands are spent on
**where to land whom** and **what to bolt onto whom**.

## The two resets

| | Deleted | Tag | What it was |
|---|---|---|---|
| 1st | 2026-08-12 | `v1-sim` | Eight months of side-view magic action + a pixel water/fire simulation. **No moment in it was fun**, and 34 features had shipped with 5 acceptance checks open |
| 2nd | 2026-08-16 | `v2-openfield` | An open-field cell game — one host, a swarm that splits and rallies, eleven part slots, a grassland with seven species and a boss. Five plans in four days, **25 nets and 3541 green checks**, and the user played it and said *"그냥 재미가 없다"* (*it's just not fun*) |

⚠ **The second one was not a failure of execution.** It was built, verified, and measured. What it lacked
was a reason for its own central mechanic: **splitting cost nothing and absorbing undid it for free, so
splitting was never a decision.** The arithmetic is in
[what two dead games left behind](lessons-from-two-dead-games.md).

**Do not restore code from either tag.** Both were written against constraints this design does not have —
`v1-sim` against integer determinism and a 20Hz tick, `v2-openfield` against a host, an open field, and a
swarm the player steers.

## What carried across both resets

| | |
|---|---|
| **[The planning principles](planning-principles-ko.md)** | The only file kept through both resets on purpose. Its second line — **planning cannot decide whether something is fun** — is what both resets proved |
| **[What two dead games left behind](lessons-from-two-dead-games.md)** | Measured numbers and repeating failure shapes. ⚠ **Nothing in it is a spec** |
| The harness | `CLAUDE.md`, `.claude/`, the net runner, `tools/pixel/`, the Korean font |

## The third reset that was not a reset — the docs

**On 2026-08-17, 60-odd docs were deleted.** They were not wrong; they were about games that no longer
exist, and a fresh session reads them as constraints. What they measured was distilled into one file
first, and only then were they removed.

⇒ **The rule this bought**: a doc describing a deleted game is not archived in place. It is distilled
into the lessons file and deleted, and the original stays recoverable at its tag.
