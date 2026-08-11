# tests/nets — empty on purpose

Every net was deleted with the game on 2026-08-12 (`docs/next-game.md`). **The runner above is intact**;
this folder is what it scans, and it must exist or `run_nets.ps1` dies before it starts.

**Do not restore the old nets from the tag `v1-sim`.** Every one of them asserted against a cell grid, a
20Hz tick, or folder contracts that no longer exist. They are a reference for *shape*, never for content.

## The first net to write is `net_citations`

It needs no game — it greps `src/`, `tests/` and `tools/` for two forbidden citation forms (a
`docs/plans/[0-9]` path, and any backticked file-and-line reference). `CLAUDE.md`'s Comments section records
why it exists: the honour-based version rotted for weeks, **six of seventeen line-number citations were
already dead**, and the moment the net covered them it found five more that a hand sweep had just missed.

**It must rejoin wrapped comment lines before matching.** A line-wise version passed three of eleven.

## ⚠ A hole that only shows while this folder is empty

**Measured 2026-08-12**: with zero nets present, `run_nets.ps1` prints "필터 ''에 맞는 그물이 없다" and
**exits 0.** An empty harness reports success.

Today that is harmless — the emptiness is the known state. **It stops being harmless the moment there are
nets**, because "someone deleted the scan" and "everything passed" then look identical from the outside,
which is exactly the fake-green shape `CLAUDE.md` is built around. The runner already guards the
*per-net* version of this (a net that ran zero checks fails); the *zero-nets* case is unguarded.

⇒ **When the first net lands, make a zero-net round exit non-zero** — and invert that guard to prove it
bites, the same as any other check.

## What every net after it owes

- **An inversion.** Without one it proves "it runs", not "it measures" (`CLAUDE.md`, No fake nets)
- **A non-zero check count.** The runner fails a net that asserted nothing — added the day a missing
  `await` made one vanish with exit code 0
