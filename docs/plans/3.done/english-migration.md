# English migration — harness and docs in English, conversation in Korean

**Status**: done — all three stages landed. Nets held at 2432 pass / 1 pre-existing failure
**Why you'd reopen**: only when deciding whether net check labels or in-game text should also move to English. Both were deliberately kept Korean — see "What stays Korean".
**One line**: prompts, docs and comments are English. **Everything said to the user stays Korean.**

## Why

Decided by the user. What the model reads lands more precisely in English, and it costs fewer tokens.

**The user cannot read English.** So the migration applies **only to what the model reads.**

## What stays Korean — the rule that makes this safe

| What | Why |
|---|---|
| **Every reply to the user** | They cannot read English |
| The user's own commands and questions | Their choice |
| Commit messages | The user reads them |
| In-game text — HUD, material / circle / glyph / monster names | It appears on the user's screen |
| **Net check labels** (`t.ok(..., "…")`, ~1085 of them) | **The user reads these when a net fails.** Cost of translating is high, value is low |
| The wrapper's own console output (`run_nets.ps1` `Write-Host`) | Same reason |
| Skill `description` trigger phrases | The user types those words; a mismatched description means the skill never fires |

**If this rule dies the whole migration fails.** CLAUDE.md carries
"Every reply to the user is in 한국어" **at the very top** so it can't get buried.

## What landed

### Stage 1 — the harness (read every session)

`CLAUDE.md` · `.claude/agents/` (6) · `.claude/skills/` (4).
**This is where the value is** — loaded into every session and every agent.

### Stage 2 — living docs

`docs/GDD.md` · `docs/design/` (8) · `docs/decisions/` (3) · `docs/plans/1.ready/` (5) · `docs/plans/2.active/`.

**Korean filenames were renamed and every link updated in one pass:**

```
진-룬-문양.md    -> circle-rune-glyph.md      물.md        -> water.md
마법진-그림.md   -> circle-art.md             배경.md      -> background.md
몬스터.md        -> monsters.md               지형-굽기.md -> terrain-baking.md
마을.md          -> town.md
인벤토리를-안-넣는다.md        -> no-inventory.md
발수-폭증은-규칙으로-막는다.md -> shot-explosion-by-rule.md
```

### Stage 3 — code comments

`src/` (32 files) · `tests/` (20) · `tools/` (15). Run as **nine parallel subagents**, one file group each.

**Comments are this repo's asset** (CLAUDE.md) — they were moved, not shrunk. Every measured number,
every "why it breaks silently" and every warning survived.

**Emoji were dropped** (`🔴 ⚠ 🟢`) with their emphasis carried into bold, and **dates were removed**,
rewritten as plain past tense. `사용자가 정했다` became `decided by the user` — that authority marker had to survive,
or the next session overturns the decision.

## The trap this hit — error strings and amnesty strings are one unit

**`push_error` text in `src/` and `t.expect_error(...)` in `tests/` are matched by plain substring**
(`run_nets.ps1`'s `Get-Noise`). Translating one side alone leaves the bark undeclared and the wrapper's
silence check fails — **it happened**, three amnesties in `net_water.gd` went dead the moment
`cell_grid.gd` was translated.

⇒ **Strings were done in a separate coordinated pass, both sides in the same edit round**, after all
comment work was finished. 53 `push_error` messages, 31 amnesties.

**Two amnesties were narrowed while passing through**, closing a hole that predated the migration:
`net_spell.gd` declared a bare `모르는 룬`, which forgave `SpellCircle:` barks as well as `SpellSim:` ones
for the whole run. Both now carry their prefix.

### The quietest one — the runner's summary line is parsed by the wrapper

`run_nets.ps1` reads the pass count out of `run_nets.gd`'s printed summary with a regex.
**Translate one side alone and every net reports 0 passes while the wrapper still exits 0** — green while
measuring nothing, exactly the failure CLAUDE.md names.

⇒ Both sides changed in one edit, **and verified with a negative control**: against the new
`[net] 143 passed` line, the old regex matches nothing and the new one returns 143. The pair is genuinely
coupled, not coincidentally green.

### `terrain_baker.gd` writes a checked-in file

Its emitter strings become the header of `src/stage/terrain_map_generated.gd`. Hand-editing the generated
file is undone by the next bake ⇒ the emitter was translated **and the map re-baked**; only the 7 header
lines changed, `MAP` byte-identical.

## Not migrated — `docs/plans/3.done/`

11 files, ~490k characters. **68% of the total and nobody reads it.**
An archive with no value to move. **Only the header — title, `Status`, "Why you'd reopen" — went to English**,
which is what a reader scans before deciding to open it.

## Terminology — fixed to match code identifiers

| Korean | English |
|---|---|
| 진 | circle (the whole assembly is **the magic circle**) |
| 룬 | rune |
| 문양 | glyph |
| 탄 | bolt |
| 그물 | net |
| 검사 | check |
| 뒤집기 · 뮤테이션 | inversion · mutation |
| 사면 | amnesty |
| 파면 | burn slot |
| 청크 재우기 | chunk sleep |
| 바닥 채우기 | floor fill |
| 판정 | acceptance |
| 항진명제 | tautology |
| 헛돈다 | spins idle |
| 껍데기 | the shell |
| 뼈 먼저 | skeleton first |
| 대표 가짜 | the signature fake |
| 사용자가 정했다 | decided by the user |

**Code identifiers were already English** (`glyph_defs`, `CIRCLE_ROUND`, `carve_r`).
**Matching comment terminology to code identifiers settled the table by itself.**

## Acceptance — result

1. Replies still come out **in Korean** — held throughout
2. **Dead links: 0** — checked after the renames (the only hits are placeholders like `<name>.md` and gitignored output paths)
3. Nets give **the same pass count as before**: 2432 pass · 1 failure (`net_water_rain_cap`, pre-existing) · no `[침묵사]` · no `[경합]`
4. `docs/design/README.md`'s table still matches each doc's header values — values were carried, not re-derived
5. New docs come out in English — this doc is one

## Found along the way — not caused by the migration, not fixed here

- **`fx_tuning.HUD_FONT_SIZE`**: the comment says it was pinned to 32 and verified on screen; the constant is 16
- **`stage.gd`'s MAP comment** carries stale grid numbers (512x288 cells / 64x36 tiles / 2048x1152 world px)
  against the real `W=4096 · H=1008` and a 400x48-tile map. `camera_center`'s comment repeats them
- **`stage.gd`'s `_update_hud`** references a `WATER_HUD_TICKS` constant that does not exist (it is `HUD_COUNT_TICKS`)
- **`net_water.gd:665`** carries a cross-reference to "line 511" that no longer points at anything
