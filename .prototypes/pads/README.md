# pads — five ways of saying where a body may go

## The question

**어떻게 하면 판을 보고 「몸이 어디로 갈 수 있는가」를 알 수 있나** — one sentence, and every version is
judged against it rather than against 「which is prettier」.

## How to run it

```
Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/pads/lab.gd            # watch it
Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/pads/lab.gd -- shoot   # photograph it
python .prototypes/pads/sheet.py                                            # all ten on one sheet
```

**Watching**: `1`..`5` pick a version, `←`/`→` step through them, `ESC` quits. **The game's own keys
still work** — `Q`/`E` turn, `R`/`F` tilt, the wheel zooms, `TAB` is the shipped 판.

⚠ **Never `--headless`**: there is no swapchain to read a frame back from and every PNG comes out
black with no error anywhere.

⚠⚠ **This lab drives the REAL game.** It presses 시작하기 and hangs each version's marks in the
field's own world, so every version is judged on the island that ships, under its camera and its sun.

## The five, and where each one gets its answer from

| | Where the mark comes from | What it needs |
|---|---|---|
| `01-now` | **a baked object** — one mark per 칸, inside `island.glb`. **What the game ships** | a held key |
| `02-turf` | **the ground's own texture** — patchy turf where you may walk, and nothing on top | a bake |
| `03-seams` | **the edges of the grid** — lines between 칸, no fill | nothing |
| `04-reach` | **a walk of the rules** outward from one body, faded by step count | a selected body |
| `05-forbid` | **the same walk read inside out** — the ground you cannot reach is dressed | nothing |

**Each folder carries a `NOTES.md` with three lines: what it buys, what it costs, and what it CANNOT
do.** ⚠ The third is the one that decides.

⚠ **No fresh scout was sent.** The outside material for this question was already gathered on
2026-08-27 and lives in ticket 06 — Bad North's own developer on patchy grass and on forests, XCOM 2's
move preview, and the games that mark nothing at all. `02-turf`, `04-reach` and `05-forbid` come
straight out of it.

⚠ **`02-turf` and `05-forbid` would be baked into the island** in a shipped version, not floated over
it. Here they are a layer 0.02 above the ground because a prototype may not re-bake the island for
every idea.

## What is NOT in the set

**Marking the reachable region with one outline and nothing inside.** It was dropped because on this
board the walkable region is the island, so the outline would land on the coast and duplicate the white
line the sea already draws there.
