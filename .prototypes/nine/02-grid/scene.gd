# **The seat belongs to the 블록, laid out as one 3x3 lattice across it.**
#
# Nine equal cells over a 2 x 2 조각 square, so the pitch is 2/3 of a 조각 in both axes and every body
# has exactly the same room. ⚠ **This is the densest possible packing of nine equal circles in a
# square** — the optimum for n = 9 is the 3 x 3 grid at r = side/6 — so no other arrangement in this
# sheet can make the bodies bigger without overlapping them.
#
# ⚠⚠ **The 조각 stops owning a seat here**, and the middle row and column of the lattice straddle the
# line where the four 조각 meet. That is the cost, and it is not a drawing cost: the sim seats bodies
# per 조각, so shipping this means the seat index has to move up a unit with it.
extends RefCounted

## The lattice pitch, in 조각. **`BLOCK_TILES / 3`, written as the division it is** — three ranks over
## the 블록's two 조각, and the day a 블록 stops being 2 조각 across this follows it.
const PITCH := Rules.BLOCK_TILES / 3.0


static func title() -> String:
	return "블록이 자리를 갖는다 — 3x3 격자 (가장 촘촘한 배치)"


static func seats(c: Vector2, _face: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for j in 3:
		for i in 3:
			out.append(c + Vector2(float(i) - 1.0, float(j) - 1.0) * PITCH)
	return out
