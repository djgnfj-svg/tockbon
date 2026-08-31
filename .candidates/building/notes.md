# `building` — what already stands, and 시안 for the next two

**Nothing chosen yet.** Geometry in `2026-08-31-variants.blend`; three sheets beside it.

## ⚠⚠ **FIVE BUILDINGS ALREADY EXIST** — `2026-08-31-sheet-what-already-stands.png`

**`blend/buildings.blend` holds keep · house · tower · store · wall**, and they are finished shapes:
62–123 vertices, one flat material per part, red roofs on a beige wall. **Only the keep is placed** —
`island.json`'s `builds` is one row, `{"kind": "keep", "x": 10, "y": 12}` — so 망루, 창고 and 돌담 have
never been on screen. **The sheet is the first time they have been looked at side by side.**

⇒ **No 시안 was cut for those five.** Re-drawing a finished shape nobody has complained about is
rework; the sheet is there so a complaint can be made.

## The two the roadmap needs next, and neither exists

**Read out of `docs/roadmap/README.md`**: week 5 is 연구대와 테크트리, week 6 is 포탑. Both are
buildings; `buildings.json` has no row for either.

### 연구대 — `2026-08-31-sheet-research-bench.png`

| | What it is |
|---|---|
| `s1_canopy` | an open workbench, a canopy over the back half only, papers and a small fire on the bench |
| `s2_hut` | a stone hut with a tall chimney — research as a fire that never goes out |
| `s3_pavilion` | a cloth awning falling away from the camera, a table under the open front |
| `s4_plinth` | no walls at all: a stone plinth, a sloped desk, two braziers |

### 포탑 — `2026-08-31-sheet-turret.png`

| | What it is |
|---|---|
| `t1_platform` | a timber platform on four legs, a bolt thrower on the deck |
| `t2_battlement` | a stone turret with merlons — the heavy answer, 1.14 조각 tall |
| `t3_emplacement` | waist-high stone with a big bow resting on it, **the only one under half a 조각** |
| `t4_spire` | a thin banded spire under a hipped roof, **the tallest at 1.36 조각** |

## ⚠⚠ **MEASURED: at this camera a full roof hides everything under it**

**The first cut of `s1` and `s3` was a bench under a full roof, and both rendered as a coloured box on
legs.** The camera pitch is `Look.MAP_TILT_DEG` **40°**, which is shallow enough to see a building's
front and steep enough that a roof covering the whole footprint covers the whole interior.

⇒ **An open building has to have its roof pulled back off the front**, which is what both of them do
now. ⚠ **This applies to anything with an interior the player is meant to read** — a forge, a stable,
a market stall.

## ⚠ **And read `../ore/notes.md` about colour**

**`b_wall` is 0.683 and renders as pure white in the game; `b_stone` is 0.319 and renders white too.**
Every shape on these sheets is painted from that palette, so **the sheets show shape and lie about
colour.** The measurement is in the ore's note and it covers the buildings as well as the props.
