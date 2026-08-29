Type: task
Status: open

# A beast stands on the island — **the first slice of the fight**

## What "done" looks like

**One wolf stands on the island, is drawn, and walks like the swordsman walks.** It does not attack,
it cannot be attacked, and nothing wins or loses.

## Where this came from

**2026-08-30, the user set next week and this is its first cut.**

> ***"Next week is monsters coming and fighting, then."***

**The five slices were ordered here on purpose**: the fight's tombstone carries seven rules, and
pushing all seven plus the boats into one week means a defect cannot be attributed to the line that
caused it.

## ⚠ What already stands here — do not build it twice

| What | Where |
|---|---|
| **The unit table, with the wolf's numbers intact** | `Rules.UNITS` — HP 14, damage 2.0, period 1.0, range 0, speed 4.0, detect 6.0 |
| **The three surviving accessors** | `Rules.speed_of`, `Rules.side_of`, `Rules.label_of` |
| **Spawn letters, whole** | `Islands.spawns`, `spawn_type_of_char`, `spawn_chars`, `spawn_char_of` |
| **`setup`'s `spawns` parameter** | `Battle.setup` still takes it and still reads nothing from it |
| **The walk** | `Grid.flow_field`, `Grid.step_toward`, the pulled route, `Battle._field_for` |
| **The reservation** | `grid.reserved`, `Grid._hold`, `_release_except` |
| **The body on screen** | `FieldView`'s pooled Sprite3D bodies and the swordsman's four facings |

## ⚠⚠ What the tombstones already paid for

**`battle.gd` line 71 and line 159 are the design document for this slice.** Read both before typing.

- **Eleven parallel columns stood here** — type, HP, alive, position, target, windup, windup target,
  cooldown, goal, stale, home level. **This slice rebuilds only the ones a walking body needs**:
  type, HP, alive, position, goal, stale.
- ⚠⚠ **`ENEMY_UID_BASE` kept enemy ids disjoint from soldier ids in `grid.reserved`.** Without it
  enemy 0 and soldier 0 release each other's 조각, **and the symptom is one body walking through
  another with every reservation check still green.** Restore it in this slice, not a later one.
- ⚠ **The island file carries no spawn letters today.** The board is 30x26 and every tier row is
  `.` or `2`. **A wolf has to be written into `island.json` by the Blender bake**, or this slice has
  nothing to place. ⚠ **`assets/terrain/` and `tools/blender/` belong to whoever is on the stair** —
  coordinate before touching them.
- **`_enemy_home_level` is the one to read before rebuilding**: only a defender that STARTED high
  held its storey. **Do not give every body a holding behaviour** — measured, the fight then never
  comes to the player.

## What this slice does NOT do

- **No targeting, no reach, no damage, no death** — 티켓 42 and 43.
- **No boats** — 티켓 44. The wolf is placed by the board, not landed.
- **No verdict** — 티켓 45. ⚠ **A commit with no enemies reads as a win on the first frame**, which is
  exactly why the gate existed; there is no verdict in this slice to be wrong.
- **No new beast rows.** The wolf is the only row a whole run was ever fought on.

## Acceptance

1. **A net builds a `Battle` with `.new()`, loads a board carrying one wolf letter, and the wolf is
   in the enemy columns with the table's HP.**
2. **The wolf walks toward the nearest swordsman** and its route is the pulled route, not the raw
   descent — the same walker 티켓 37 settled.
3. **A wolf and a swordsman never occupy one 조각**, and neither releases the other's reservation.
   ⚠ **Invert the uid offset and see this check bite** — it is the whole reason the offset exists.
4. **The wolf is on screen** as a pooled body, at the standing height the stair round fixed.
5. **`src/sim/` still constructs with `.new()` alone.**
6. **The net count does not go down.** Record before and after.

## ⚠ Extensibility — what this slice must leave open

- **The columns are parallel arrays indexed by enemy id, not an object per beast.** The four beast
  rows differ only by table row, and the day a golem is added it is a row.
- **Nothing branches on `WOLF`.** A species name in an `if` is the defect this repo has removed twice.
