# Zone ② is removed — the bull's door opens onto the rooster, with no trash run between

**Status**: valid

## What was decided

**The 78 columns of trash-mob ground between the wood wall and room ③ (`x167-244`) go, and their 12 monster
rows with them.** The user's words: 「황소 잡고, **잡몹도 없이**, 넘어가면 불 룬으로 부시고 넘어가면 바로
보스가 있어.」

Design doc: [`plans/3.done/burn-out-of-the-bull-room.md`](../plans/3.done/burn-out-of-the-bull-room.md).

**Nothing that ever ran is being deleted.** `stage1_monsters.gd`'s own header records zone ②'s rows as
**dormant** — the step from ①'s floor (`ty32`) to ②'s shelf (`ty26`) is 6 tiles against a 3.375-tile jump, so
they were unreachable in normal play and were placed anyway, against the day the water escape landed.
**That day is not coming** — see [the-rune-is-used-where-it-is-won.md](the-rune-is-used-where-it-is-won.md).

## What wasn't chosen

| Rejected | Why |
|---|---|
| **A trash run between midboss and boss** | The user cut it in the same sentence that placed the door. Two boss fights back to back is the shape they asked for |
| **Keeping ②'s 12 rows and moving them elsewhere** | They were cut as a segment, not redistributed. The left run already carries 18 rows in 3 clumps and its density is a settled judgment (`left-run-clumps-and-platforms.md`) |
| **Keeping the columns and leaving them empty** | Not decided either way — **left as a TBD in the design doc.** The precedent ([cut-the-terrain-not-the-spawn.md](cut-the-terrain-not-the-spawn.md)) cut terrain for real and rejected leaving dead map behind, but that was 100 columns *behind the spawn*, and this is 78 *between two rooms* |
| **Waking ② by finally landing the water escape** | The escape is the thing this change replaces |

## What's tied to it

- **`stage1_monsters.ROWS`** — 12 rows deleted (6 pig · 4 hen · 2 wolf).
- **The boss reserve is not tied to it.** `spawn_monster`'s reserve is **the number of boss rows in the
  pushed table, derived, not typed** ([boss-slots-are-reserved-in-the-spawn-door.md](boss-slots-are-reserved-in-the-spawn-door.md))
  ⇒ still 2, and **no code changes.** `net_monster_placement`'s pre-① row-count bound only gets slacker.
- **Every coordinate east of the cut**, if the map is shortened: `stage_gate`'s six stage-1 constants,
  `net_gate`'s room-③ literals, the rooster's `tx`.
- **The run's XP curve is untouched** — ②'s rows never woke, so they were never worth anything.

## Conditions to reopen

- **Stage 1 plays as too short**, or the two boss fights read as one long fight with no breath between.
- **The player arrives at the rooster underlevelled.** The left run's three clumps are worth 192 XP and
  `left-run-clumps-and-platforms.md`'s own reopen condition ("one level-up before ①, played not computed") is
  still open — **②'s rows were never part of that arithmetic**, but the rooster's difficulty was never
  measured against a player who skipped them either.
