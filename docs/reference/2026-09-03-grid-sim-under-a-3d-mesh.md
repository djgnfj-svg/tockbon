# Is it normal to run the simulation on a 2D tile grid with integer heights while the screen is a real 3D mesh?

**Yes — it is the default for tactics and colony games, and it is normal for the 3D mesh to carry no
collision at all. The known sharp edge is exactly the one we hit: the drawn body's height must come
from the LOGICAL cell, never from the mesh under the drawn point.**

The industry names the two halves the **visual grid** and the **logic grid** (collision grid,
path-finding grid) — MDN's tilemap overview uses those words. A grid game that hides its grid behind
art is a named craft, not a compromise.

## Cases

| Who | What they did | How it turned out | Source |
|---|---|---|---|
| **Plausible Concept — Bad North** | Islands are procedurally assembled from handcrafted tiles; the player positions squads on the grid, and each unit then decides how and when to attack from there. The devs' stated reason is legibility: "It's much easier to understand and predict the outcome of your positioning if you have a discrete possibility space." | Shipped 2018, sold over a million copies | [Nintendo UK dev interview](https://www.nintendo.com/en-gb/News/2018/April/Interview-Taking-on-hordes-of-invading-Vikings-in-Bad-North-1368315.html) |
| **Plausible Concept — Bad North (movement layer)** | Stålberg's own talk outline lists "Using the generated voxels for lighting, wind, collision.." and "Generating a nav mesh and running flow fields on it" — i.e. tiles are the authoring and command unit, but a navmesh is DERIVED from them for movement. ⚠ **Index-level evidence only**: X/Twitter refused every fetch; the text above is the search engine's indexed tweet body, not a page I opened. | Not independently confirmed | [tweet (could not open)](https://x.com/OskSta/status/1121395490535374848) · [EPC2018 talk, unread](https://www.youtube.com/watch?v=0bcZb-SsnrA) |
| **Firaxis — XCOM 2** | One grid tile is 96 × 96 Unreal units. A Firaxis environment artist: "the pathing generation, cover generation, and line of sight was all generated through the squares of the grid". Props were authored at 80 × 80 so decoration would not "bother the pathing or cover the neighboring tile". | Shipped 2016; the grid is invisible but total | [80.lv interview with Firaxis](https://80.lv/articles/environment-storytelling-in-xcom-2) |
| **Larian — Divinity: Original Sin 2 (Divinity Engine)** | An **AI grid**: "a 2D representation of the world, where every patch of 0.5m² gets a property that either allows creatures to stand on it, or prevents them from doing so." Height per cell is BAKED by raycasting once ("rain drops" falling on each cell), not sampled at runtime. Too-steep slope forces the cell to WalkBlocked: "This prevents you from running off a wall of a cliff." | Shipped; the same grid drives surfaces, and Larian carried it into BG3's engine lineage | [Larian official engine docs](https://docs.larian.game/AI_grid) |
| **Trudy's Mechanicals (small indie 3D tactics)** | Square cells with **integer height**; an incline of 1 is half a cube. Movement cost 2 cardinal / 3 diagonal. Falling is allowed within "unit height + vertical jump + 2", beyond that it is fall damage. | Shipped devlog on Game Developer | [Pathing & Movement on a 3D Grid](https://www.gamedeveloper.com/design/pathing-movement-on-a-3d-grid) |
| **Filip Hráček (Knights of San Francisco)** | "the game AI needs tiles to make sense of the space… tile-based A* is by far the most well-understood and simplest-to-implement approach", then "even when you have tiles, it doesn't mean you have to show them" — string-pulling, path counting, marching squares. | The whole article is about hiding a grid under non-grid visuals | [Making a tile-based game look like it's not](https://filiph.net/text/making-a-tile-based-game-look-like-it's-not.html) |
| **Naming** | Tile games keep "a visual grid… and a logic grid which can be a collision grid, a path-finding grid, etc." | The standard vocabulary | [MDN — Tiles and tilemaps overview](https://developer.mozilla.org/en-US/docs/Games/Techniques/Tilemaps) |

## Who did the opposite

| Who | What they did | Why |
|---|---|---|
| **Radiant Entertainment — Stonehearth** | Started on a **navigation grid** with A* stepping voxel by voxel; **moved off it to a navigation mesh** so the pathfinder "steps in big, meaty chunks", estimated 5× to over 200× faster. Beta in Alpha 12 behind `simulation.use_subspace_pathfinder`. Building a navmesh in real time in a fully dynamic voxel world was called a really hard problem and took months. ⚠ **stonehearth.net refused every fetch (ECONNRESET, three URL forms)** — this is two independent search engines quoting the same page, not a page I opened. | Grid A* did not scale to a large voxel world with many colonists |
| **Bad North itself** (see above) | Tiles for authoring and command, generated navmesh + flow fields for movement | Legibility on top, smooth motion underneath |

**The shape of the opposite case matters: nobody moved off the grid for CORRECTNESS. They moved off it
for SPEED, on maps far larger than one island, and it cost them months.**

## The symptom — a drawn body offset inside its cell, next to a height discontinuity

Nobody names this as a famous problem, because the architectures above never create it:

- **Larian bakes one height per 0.5 m cell** and blocks cells whose slope is too steep. The height is a
  property of the CELL. Nothing ever raycasts the render mesh under a moving body.
- **Trudy's Mechanicals lerps the visual Y "between the bottom of the cube and its top while walking"** —
  the two endpoints are the two cells' heights, so the drawn body is on a straight line between two
  LOGICAL heights and can never take a third value.
- **Unity RTS Engine caches per-cell terrain height before the game starts** "so that no runtime
  Raycasting is required each time the height information is needed"
  ([docs](https://docs.gamedevspice.com/rtsengine/manual/01_Setup_New_Map/02_Setup_Terrain.html)).

⇒ **The practice is: height is a function of the logical cell, and the visual offset only interpolates
between logical heights.** Sampling the height under the OFFSET point is the step none of them take.

## What this does not settle

- **Bad North's actual movement layer.** X and YouTube both refused; the navmesh/flow-field claim rests
  on an indexed tweet body. The EPC2018 talk (`youtube.com/watch?v=0bcZb-SsnrA`) and Konsoll 2018
  (`youtube.com/watch?v=6JcFbivo8dQ`) are unwatched and would settle it.
- **How big a sub-tile offset is safe.** No source gives a number or a clamping rule; the sources
  instead remove the question by deriving height from the cell.
- **XCOM's height/level representation.** The 96-unit tile is sourced; the vertical unit is not.
