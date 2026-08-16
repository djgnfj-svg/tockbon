class_name Cards
extends RefCounted
## The level-up pick. **A card names a part and does nothing else.** There is no price, no skip and no
## description table: the id IS a `Parts` row, its face is `Parts.NAME[p]`, and taking it calls
## `Body.wear()`. Everything a card can do to the run is a column in that table.
##
## **The pick exists on purpose.** A level-up with nothing to press is a notification, and a notification
## is something you watch happen — planning principle 1.
##
## **No card grows the swarm and no card moves a multiplier.** The level pays force into the host and `F`
## is what turns force into bodies; the five `*_mul` fields the old cards moved are deleted from `Swarm`
## outright, because a card that nudges a number is the level-up this plan replaced.


## Up to three DISTINCT parts, drawn without replacement from what the run has actually eaten.
##
## ⚠ **The pool starts EMPTY and opens on the first CREATURE EATEN**, and that is the design: a crow part
## cannot appear before a crow has. So this returns fewer than three when the pool is smaller and an empty
## array when nothing is unlocked — it may never assume three are available. The old implementation was
## `rng.randi() % pool.size()` against a fixed six-entry table; unchanged, the first level of every run
## divides by zero.
##
## **The crow is what opens it, and that is load-bearing.** While every droppable row was a horse part, a
## player who never cornered a horse — which no sustained speed can catch, and which arrives about once
## every `Rules.CRITTER_INTERVAL` — saw zero cards for a whole run. The crow stands still and dies in the
## first minute.
##
## ⚠ **An empty offer is a legal, long-lived state, not a "needs a roll" sentinel.** `World._grow()` used
## `offer.is_empty()` as exactly that, which becomes a roll every single frame once banking lands. It asks
## `pool_size()` now — **not** whether anything was eaten, which is a different question and was the same
## bug wearing a second face: seven of the eleven species drop nothing, so `species_eaten` goes non-empty
## while this still returns empty.
##
## `BITE` and `DASH` are not in the pool. They are the actives you are handed, not things offered — they
## are `SPECIES = NONE` and this filter is what keeps them out with no second list to maintain.
static func roll(rng: RandomNumberGenerator, species_eaten: PackedInt32Array) -> PackedInt32Array:
	var pool := _pool(species_eaten)
	var out := PackedInt32Array()
	for _i in mini(3, pool.size()):
		var k := rng.randi() % pool.size()
		out.append(pool[k])
		pool.remove_at(k)
	return out


## **How many distinct parts this run could be offered right now.** `World._grow()` asks before rolling.
##
## ⚠ **It exists because "something was eaten" is not "something can be offered".** Seven of the eleven
## species drop nothing at all (`Parts.DROPS` 0 — the split that makes a new species cheap), so a run whose
## only corpse is a 들쥐 has a non-empty `species_eaten` and an empty pool. A guard written on
## `species_eaten` alone is true forever in that state, `roll()` comes back empty forever, and it is called
## **every frame for the rest of the run** with nothing on screen to say so.
##
## **One function owns the filter**, so the guard and the roll can never disagree about what is in the pool
## — a second copy of these three conditions is the shape that diverges on the first row anyone adds.
static func pool_size(species_eaten: PackedInt32Array) -> int:
	return _pool(species_eaten).size()


## Every part id this run has unlocked and could be dealt: it belongs to a species, that species is
## droppable, and that species has actually been eaten.
static func _pool(species_eaten: PackedInt32Array) -> Array:
	var pool: Array = []
	for p in Parts.NAME.size():
		if Parts.SPECIES[p] < 0:
			continue
		# **The other half of the same lock, and it is a column rather than a list here.** A row with
		# `DROPS` 0 is a row and nothing else: 말 갈기 and 말 폐활량 exist in the table and are out of both
		# pools (user), so eating a horse offers 말 다리 alone. Written as a second array of ids it would
		# diverge from the table the day a row is added.
		if int(Parts.DROPS[p]) == 0:
			continue
		if not species_eaten.has(Parts.SPECIES[p]):
			continue
		pool.append(p)
	return pool
