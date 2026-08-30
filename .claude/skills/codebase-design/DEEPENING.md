# Deepening

How to deepen a cluster of shallow modules safely, given its dependencies. Assumes the vocabulary in [SKILL.md](SKILL.md): **module**, **interface**, **seam**, **adapter**.

## Dependency categories

When assessing a candidate for deepening, classify its dependencies. The category determines how the deepened module is tested across its seam.

### 1. In-process

Pure computation, in-memory state, no I/O. Always deepenable: merge the modules and test through the new interface directly. No adapter needed.

⚠⚠ **In this repo that is `src/sim/`, and it is most of the game.** The folder rule — no `Node`, no
tree, constructible with `.new()` — exists so this category stays the big one.

### 2. Local-substitutable

Dependencies with a local stand-in. **Here that is the engine itself**: a view needs the tree, and the
tree can be stood up headless. Deepenable, and tested with the stand-in running. The seam is internal;
no port at the module's external interface.

### 3. True external

⚠⚠ **The game has no network boundary and no third-party service** — the user settled 2026-08-30 that
it is single-player and stays deterministic. **What is genuinely outside is the art pipeline**: Blender,
the local ComfyUI, pixellab. **None of them run while the game runs** — they bake a file and the game
loads it. ⇒ **The seam is the file on disk, not a port**, and nothing needs mocking.

## Seam discipline

- **One adapter means a hypothetical seam. Two adapters means a real one.** Don't introduce a port unless at least two adapters are justified (typically production + test). A single-adapter seam is just indirection.
- **Internal seams vs external seams.** A deep module can have internal seams (private to its implementation, used by its own tests) as well as the external seam at its interface. Don't expose internal seams through the interface just because tests use them.

## Testing strategy: replace, don't layer

- Old unit tests on shallow modules become waste once tests at the deepened module's interface exist; delete them.
- Write new tests at the deepened module's interface. The **interface is the test surface**.
- Tests assert on observable outcomes through the interface, not internal state.
- Tests should survive internal refactors, since they describe behaviour, not implementation. If a test has to change when the implementation changes, it's testing past the interface.
