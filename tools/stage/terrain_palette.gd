extends RefCounted
## **The single source for the brush palette. "What can be painted" and "which slot is it" come only from here.**
##
## Before this file existed the same thing was written **by hand in two places** —
## the slot order of `assets/stage/terrain_tiles.png` and the `TILES` table in `build_terrain_tileset.gd`.
## **Even when the two diverge the game screen is not wrong** (the screen is drawn by the cell grid) — it only
##  confuses you **when picking up a brush**, which is why `docs/design/terrain-baking.md` wrote "nobody notices".
##
## **Not a table but a derivation.** What can be painted = `Mat.ALL` minus `EMPTY` —
##  an empty cell is "not placing a tile", so it cannot be a brush. => **Adding a material does not change this file.**
##
## **The order is a contract.** Atlas coordinates come from the order inside `Mat.ALL`, so **changing the order
##  of the front of `ALL` turns every tile of an already painted map into a different material.** Only **appending** is safe.
##  (Current order: stone 0 · wood 1 · bedrock 2 · water 3 — water was appended **at the end**.)

const Mat := preload("res://src/sim/cell_materials.gd")


## The materials that become brushes, **in order**. The index is the atlas column.
static func paintable() -> Array[int]:
	var out: Array[int] = []
	for id: int in Mat.ALL:
		if id == Mat.EMPTY:
			continue
		out.append(id)
	return out


## Palette order -> atlas coordinates. **Laid out in one row** — fold it vertically and the two scripts each
##  get their own folding rule, which is exactly what this file exists to remove.
static func atlas_of(index: int) -> Vector2i:
	return Vector2i(index, 0)


## Px of one slot of the brush image. It is both the tile size and the atlas grid, so **the two must be the same value.**
##  A terrain tile is 8x8 cells = 32px (`sim_tuning.TILE_CELLS` x `CELL_PX`) — not hardcoded here but
##   derived from those two. Otherwise the day the tile size changes, only the brush goes stale.
const Tuning := preload("res://src/sim/sim_tuning.gd")

static func tile_px() -> int:
	return Tuning.TILE_CELLS * Tuning.CELL_PX
