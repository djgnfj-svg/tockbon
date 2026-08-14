# Force is a stored number, not one recomputed from level and parts

**Status**: valid — settled 2026-08-14 after the second adversarial review, where four agents independently
found the two readings sitting in three docs at once.

## What was decided

**`force[i]` is written once and thereafter only added to and subtracted from.** Levelling adds, wearing a
part adds, digesting one subtracts, splitting halves, absorbing sums, dying deletes the row. Nothing
recomputes it from anything.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **`force = base + level + sum(parts)`, recomputed each frame** | **`F` becomes free.** Halve the host and the next frame puts it back, so the swarm doubles at no cost, the total is not conserved, and the one thing splitting costs — concentration — costs nothing. It fails **silently**: every positional check stays green |
| **`force[0] + force_bonus()`** — stored base, derived bonus | The double-counting version of the same thing. Read the base alone and `force_bonus()` is a pure function nobody calls; add them and every part counts twice |
| **Recomputing only for the host, storing for clones** | Two rules for one number. The host is row 0 of the same array and every check that sums the swarm would have to know which rows lie |

## What's tied to it

- **`F` and `V` are the whole of plan 2.** Both are arithmetic on this number
- **Plan 3's `wear()` / digest write `swarm.force[0]` directly.** A `force_bonus()` helper is the rejected
  branch wearing a different name
- **Conservation is assertable.** `total_force()` before and after a split is the check that catches every
  version of this bug at once — see [the swarm grows by a key](swarm-grows-by-a-key-not-a-level.md)

## Conditions to reopen

A part whose effect is genuinely multiplicative on force (×1.5 rather than +5). Stored addition cannot
express that, and the answer would be a second stored field, not a recomputation.
