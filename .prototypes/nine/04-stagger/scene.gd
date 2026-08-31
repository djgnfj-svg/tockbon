# **The seat belongs to the 블록, and every other row is pushed half a place sideways** — the
# staggered rows a crowd falls into when nobody is standing directly behind anybody.
#
# Rows sit closer together than a square lattice allows (a row of touching circles nests into the
# gaps of the row below at √3/2 of the pitch), so **the nine take less depth and each body may be
# wider than the square grid gives it.**
#
# ⚠ **What it cannot do is line up.** The three rows never read as three ranks, so a squad arranged
# this way cannot present a front — it always reads as a cluster, which is right for a mob and wrong
# for men under orders.
extends RefCounted

## Across a row. Same as the square lattice: three over the 블록's width.
const PITCH := Rules.BLOCK_TILES / 3.0
## Row to row. **√3/2 of the pitch** — what nesting one row into the gaps of the next actually buys.
const ROW := PITCH * 0.8660254
## How far the middle row is pushed. Half a place, which is what makes the nesting exact.
const SHIFT := PITCH * 0.5


static func title() -> String:
	return "블록이 자리를 갖는다 — 줄마다 반 칸씩 엇갈린 벌집 배치"


static func seats(c: Vector2, _face: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for j in 3:
		# The middle row shifts one way and the outer two the other, so the nine stay centred on the
		# 블록 rather than leaning off one edge of it.
		var dx: float = SHIFT * (0.5 if j == 1 else -0.5)
		for i in 3:
			out.append(c + Vector2((float(i) - 1.0) * PITCH + dx, (float(j) - 1.0) * ROW))
	return out
