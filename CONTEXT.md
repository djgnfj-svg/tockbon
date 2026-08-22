# CONTEXT — the words this repo uses

**Written 2026-08-22** because `tdd` and `domain-modeling` both read this file for the vocabulary that test
names and interfaces are built out of, and it did not exist. **Terms are taken from the code, not invented
here** — every one below is a name that appears in `src/`.

⚠ **The user speaks Korean and the code speaks English.** Both columns are load-bearing: **an answer that
uses only the English word is not an answer to the user**, and a symbol named in Korean is not a symbol.

---

## The army

| 한국어 | Code | What it is |
|---|---|---|
| 세포 | **cell** | The currency you spend to summon. Eating an island grows the **pool**, not the roster |
| 병사 | **soldier** | One body on the field. **Carries across islands, HP included. Dead is dead** |
| 군대 | **army** | Every soldier in the run. Owns `living_count`, and combat reads it |
| 슬롯 | **slot** | A summon template. Press it, spend cells, a body of that shape comes out. **There are two** |
| 부품 | **part** | What a slot's body is built from. Six body places: 머리 가슴 배 팔 손 다리 |

⚠ **A cell is not a soldier.** Cells are the pool; a soldier is what a slot turns them into. Collapsing
these two is the oldest vocabulary mistake in this repo.

## The field

| 한국어 | Code | What it is |
|---|---|---|
| 섬 | **island** | One combat map. A `grid` of tiles plus the rows that fill it |
| 판 | **grid** | The tile map itself — land, water, cliff |
| 소환 띠 | **band** | The strip of sea you may press. **Six tiles off the shore, minimum** |
| 배 | **boat** | Carries a summoned soldier from the band to the nearest shore. **It sails itself** |
| 항구 | **harbour** | A shore tile a boat can arrive at |

⚠ **`harbour` survives from the deleted drag control.** It is now an arrival point the sim picks, **never a
thing the player aims at.** A design that makes the player choose a harbour is re-importing a rejected fork.

## The run

| 한국어 | Code | What it is |
|---|---|---|
| 판(한 회차) | **run** | Title to boss. Holds `State`: MAP · BATTLE · REWARD · PICK · REFIT · WON · LOST |
| 노드 | **node** | One stop on the map. Five floors, seven nodes |
| 파트 루프 | — | One island |
| 세션 루프 | — | One run, between islands |
| 메인 루프 | — | Outside a run |

⚠ **The three loop names are the user's own** and they beat any other naming. Outside in: **main → session
→ part.**

## The tools

| 한국어 | Code | What it is |
|---|---|---|
| 그물 | **net** | A test. Lives in `tests/nets/`. **A green that measures less than its label says is worse than a red** |
| 잎 | **leaf** | A drawing hook a net can assert the arguments of |
| 프로브 | **probe** | Drives whole runs headless and prints numbers |

---

## Where the seams are

`tdd` will not write a test at an unagreed seam. **These are the agreed ones**, and they come from the
folder rule in `CLAUDE.md`:

- **`src/sim/`** — constructible with `.new()`, never touches the tree. **The main seam.** A net drives the
  whole game here in seconds
- **`src/view/`** — reads `sim`, never writes it. **Seam is the paint hook**, not the Node
- **`src/shell/`** — the only reader of `Input`. **Seam is `_ready()`**, which builds the real wiring

**Do not add a seam inside a file.** If something is hard to test, it is in the wrong folder.
