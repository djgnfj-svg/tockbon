# **`03-ranks`'s rotation with `02-grid`'s square spacing** — three ranks of three that turn to face,
# but with the front-to-back gap opened out to the same 2/3 조각 the sides already have.
#
# ⚠⚠ **THIS EXISTS BECAUSE THE TWO THE USER WAS TORN BETWEEN DIFFER BY ONE NUMBER** (2026-08-31, the
# user: 「I do like 2's style, but 3 seems right」). `03-ranks` is `02-grid` squeezed front to back from
# 0.667 to 0.5 and turned; **open that one number and the squeeze goes away while the turning stays.**
# ⚠ **`03-ranks` is NOT deleted for this.** Tight ranks are a real look and this repo writes a
# reversal down rather than by removing what it replaced.
#
# ⚠ **Facing south it is pixel-for-pixel `02-grid`.** That is the point and not a defect: the whole
# difference lives in what happens when the nine walk east.
extends RefCounted

## Both axes, and deliberately ONE constant rather than two that happen to be equal. **The day they
## differ, this version is `03-ranks` again** — the difference between the two is exactly this line.
const PITCH := Rules.BLOCK_TILES / 3.0


static func title() -> String:
	return "3열인데 앞뒤도 어깨만큼 넓다 — 2번 모양이 도는 것"


static func seats(c: Vector2, face: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var fwd := face.normalized() if face.length() > 0.001 else Vector2(0, 1)
	var right := Vector2(-fwd.y, fwd.x)
	for j in 3:
		for i in 3:
			out.append(c + right * (float(i) - 1.0) * PITCH + fwd * (float(j) - 1.0) * PITCH)
	return out
