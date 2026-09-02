# **The seat belongs to the 조각, and the 조각 rings it** — what the game does today, capped at nine.
#
# Three seats per 조각: seat 0 is the 조각 centre and seats 1 and 2 sit on a ring of
# `Look.CROWD_SPREAD_RATIO` about it. Bodies arrive round-robin over the 블록's four 조각, which is
# how `Grid._free_slot` hands them out, so the nine land 3 · 2 · 2 · 2.
#
# ⚠ **This is the CONTROL and it is the only version that is not a proposal.** Every other picture in
# the sheet has to beat what is already on screen.
extends RefCounted


static func title() -> String:
	return "조각이 자리를 갖는다 — 중심 하나에 고리 둘 (지금 것)"


static func seats(c: Vector2, _face: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var half := (float(Rules.BLOCK_TILES) - 1.0) * 0.5
	var tiles := [
		c + Vector2(-half, -half), c + Vector2(half, -half),
		c + Vector2(-half, half), c + Vector2(half, half),
	]
	# Round-robin, exactly as the reservation table fills: everybody takes seat 0 of a different
	# 조각 first, then everybody takes seat 1, and the ninth body takes the first 조각's seat 2.
	for k in 9:
		var t: Vector2 = tiles[k % tiles.size()]
		var slot: int = k / tiles.size()
		out.append(t + _ring(slot))
	return out


## The ring the game drew on 2026-08-31, in 조각. ⚠⚠ **IT READ `Look.crowd_offset_px` AND THAT FUNCTION
## IS DELETED** (2026-09-02, ticket 03-17 — the user chose 06 off this very sheet and the ring went with
## it). This is now the ONLY place the ring lives, kept so the sheet's control stays the picture it was
## photographed as: slot 0 the 조각 centre, slots 1 and 2 on a ring of 0.30 조각 around it.
static func _ring(slot: int) -> Vector2:
	if slot <= 0:
		return Vector2.ZERO
	var around := maxi(Rules.TILE_CAPACITY - 1, 1)
	var a := TAU * float(slot - 1) / float(around)
	return Vector2(cos(a), sin(a)) * 0.30
