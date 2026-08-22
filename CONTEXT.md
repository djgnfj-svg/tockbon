# CONTEXT — the words this repo uses

**Rewritten 2026-08-22** when the cell game was folded and the magic-circle game came back. `tdd` and
`domain-modeling` both read this file for the vocabulary that test names and interfaces are built from.

⚠ **The user speaks Korean and the code speaks English.** Both columns are load-bearing: **an answer that
uses only the English word is not an answer to the user**, and a symbol named in Korean is not a symbol.

⚠⚠ **Nothing here is taken from code yet — `src/` is empty.** Every term below comes from
`docs/design/circle-rune-glyph.md`, which is a design and not a measurement. **The moment a name reaches
`src/`, this file is corrected to match the code, not the other way round.**

---

## The spell — three axes, cut along time

**They do not overlap in time. Overlap and they eat each other.**

| 한국어 | Code | What it is |
|---|---|---|
| 진 (마법진) | **circle** | **The moment of firing.** How many go out, how they are grouped, how many layers |
| 룬 | **rune** | **After it leaves.** What it is, how it travels, what it leaves in the world |
| 문양 | **glyph** | **After it lands** (and while travelling). What is added on top |

⚠ **A glyph cannot change the element** — that is the rune's. **A glyph cannot change the arrangement** —
that is the circle's. Break either and the axis it stole from becomes unnecessary.

## Inside a circle

| 한국어 | Code | What it is |
|---|---|---|
| 층 | **layer** | A glyph seat. ⚠ **Two different meanings** — total glyph seats (variety) vs layers one bolt passes (permutation depth). **Never collapse them** |
| 룬 칸 | **rune slot** | Where a rune sits |
| 융합 · 병렬 · 순차 | **fuse · parallel · sequence** | The three ways runes combine. **Only fusion needs a table** |

⚠ **Shot count is not set by the circle** — it falls out of the rune arrangement. Three runes in parallel
**is** three shots, and they carry different elements.

## What a glyph does, by when

| 한국어 | Code | When |
|---|---|---|
| 바꿈 | **modify** | **Immediately** on being reached. Alters how it flies |
| 낳음 | **spawn** | After landing. Creates new bolts, **each carrying the rest of the list** |
| 끝냄 | **finish** | After landing. Happens there and ends |

## The fight

⚠⚠ **Every row here is UNDECIDED and is on the map as a live ticket.** They are named so the words exist,
not because the thing does.

| 한국어 | Code | State |
|---|---|---|
| 근접 | **melee** | **What the player presses is not decided.** 패링 · 휘두르기 · 대시 · 피격 are the candidates |
| 방아쇠 | **trigger** | **What fires a circle is not decided** — 얹힘 · 행동 · 전용 키 |

## The tools

| 한국어 | Code | What it is |
|---|---|---|
| 그물 | **net** | A test. Lives in `tests/nets/`. **A green that measures less than its label says is worse than a red** |
| 지도 | **map** | One effort's plan under `.scratch/<일>/`. `wayfinder` owns it |
| 티켓 | **ticket** | One question. Its answer, once written, **is** the design |

---

## Where the seams are

`tdd` will not write a test at an unagreed seam. **These are the agreed ones**, and they come from the
folder rule in `CLAUDE.md`:

- **`src/sim/`** — constructible with `.new()`, never touches the tree. **The main seam.** A net drives the
  whole game here in seconds
- **`src/view/`** — reads `sim`, never writes it. **Seam is the paint hook**, not the Node
- **`src/shell/`** — the only reader of `Input`. **Seam is `_ready()`**, which builds the real wiring

**Do not add a seam inside a file.** If something is hard to test, it is in the wrong folder.

⚠ **These three survived two deletions and are not re-decided per game.** They are what lets a net drive a
whole game headless in seconds.
