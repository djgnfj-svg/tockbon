class_name Food
extends RefCounted
## Fixed spots scattered once per run. Eating one starts its cooldown; it comes back where it was.
##
## **Spots are fixed rather than respawning anywhere on purpose.** Respawning at a random point spreads
## food evenly however hard a region is worked, and then a region never empties — local depletion is one
## of the four rules the round trip stands on, and it dies quietly if food follows the swarm around.

var pos := PackedVector2Array()
var alive := PackedInt32Array()
var timer := PackedFloat32Array()
var alive_count := 0

var _respawn_credit := 0.0


func setup(field: Vector2, spots: int, rng: RandomNumberGenerator) -> void:
	pos.resize(spots)
	alive.resize(spots)
	timer.resize(spots)
	for i in spots:
		pos[i] = Vector2(rng.randf_range(0.0, field.x), rng.randf_range(0.0, field.y))
		alive[i] = 1
		timer[i] = 0.0
	alive_count = spots
	_respawn_credit = 0.0


func consume(i: int) -> bool:
	if i < 0 or i >= alive.size() or alive[i] == 0:
		return false
	alive[i] = 0
	timer[i] = Rules.FOOD_SPOT_COOLDOWN
	alive_count -= 1
	return true


## Cooldowns run for every dead spot, but only `FOOD_RESPAWN_PER_SEC` of the ready ones come back each
## second — so a region worked flat stays flat for a while even after its cooldowns expire.
func step(dt: float) -> void:
	_respawn_credit += Rules.FOOD_RESPAWN_PER_SEC * dt
	var budget := int(_respawn_credit)
	_respawn_credit -= float(budget)
	for i in alive.size():
		if alive[i] == 1:
			continue
		if timer[i] > 0.0:
			timer[i] -= dt
			continue
		if budget <= 0:
			continue
		alive[i] = 1
		alive_count += 1
		budget -= 1
