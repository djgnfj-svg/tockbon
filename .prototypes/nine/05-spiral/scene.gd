# **The seat belongs to the 블록 and comes off a sunflower spiral** — nine places on the golden angle,
# spread out from the middle.
#
# Every seat is a different distance and a different bearing from the centre, so **no two bodies line
# up on any axis and the arrangement reads as a group of men rather than as furniture.** It is fully
# deterministic: the k-th seat is a closed form, so the same nine land in the same places every run
# and on every machine.
#
# ⚠ **What it cannot do is hold a shape.** There is no row, no front and no flank, so a player cannot
# read which way the squad is facing or where its edge is — and the spacing is uneven by construction,
# which means the tightest pair is always tighter than the grid's.
extends RefCounted

## How far the outermost seat sits from the middle, in 조각. Just inside the 블록's half-width, so the
## crowd fills it without spilling into the 블록 next door.
const REACH := Rules.BLOCK_TILES * 0.5 * 0.95
## The golden angle, in radians — 2π(1 − 1/φ). **What makes the spiral fill evenly instead of
## clumping into arms**, which is the whole reason this is the mechanism rather than a random scatter.
const GOLDEN := 2.39996323


static func title() -> String:
	return "블록이 자리를 갖는다 — 해바라기 나선 (줄이 안 보인다)"


static func seats(c: Vector2, _face: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in 9:
		# `sqrt` and not a straight fraction: area grows with the square of the radius, so a linear
		# radius would pack the middle and leave the rim empty.
		var r: float = REACH * sqrt((float(k) + 0.5) / 9.0)
		var a: float = float(k) * GOLDEN
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out
