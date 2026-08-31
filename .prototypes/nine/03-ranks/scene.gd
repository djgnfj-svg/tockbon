# **The seat belongs to the SQUAD, and the squad faces a direction** — three ranks of three, turned
# to face whatever the nine are pointed at.
#
# The pitch is not square: **shoulder to shoulder across the rank, and looser front to back**, which
# is what a line of men looks like and what Bad North's squads read as. The lattice turns with the
# facing, so the same nine present a wall when they meet something and a column when they walk.
#
# ⚠ **The cost is that the seat now depends on a fourth thing** — where the squad is looking. Two
# squads on one 블록 facing different ways would interleave, and nothing here says what happens then.
extends RefCounted

## Across the rank — the tight axis. Three men over a 블록's width leaves 2/3 of a 조각 each.
const ACROSS := Rules.BLOCK_TILES / 3.0
## Front to back — the loose axis. Half a 조각, so the three ranks read as three lines rather than as
## a square. ⚠ **Tighter than `ACROSS` on purpose**: a rank is a line, and a line is what is being
# tested here.
const ALONG := 0.5


static func title() -> String:
	return "부대가 자리를 갖는다 — 보는 쪽을 향해 3열 (어깨는 붙고 앞뒤는 뜬다)"


static func seats(c: Vector2, face: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	# A zero facing would collapse every seat onto the centre; south is the game's own resting facing.
	var fwd := face.normalized() if face.length() > 0.001 else Vector2(0, 1)
	var right := Vector2(-fwd.y, fwd.x)
	for j in 3:
		for i in 3:
			out.append(c + right * (float(i) - 1.0) * ACROSS + fwd * (float(j) - 1.0) * ALONG)
	return out
