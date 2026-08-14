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
## ⚠ **The pool starts EMPTY and stays empty until the first horse is eaten**, and that is the design:
## a horse part cannot appear before a horse has. So this returns fewer than three when the pool is
## smaller and an empty array when nothing is unlocked — it may never assume three are available. The old
## implementation was `rng.randi() % pool.size()` against a fixed six-entry table; unchanged, the first
## level of every run divides by zero.
##
## ⚠ **An empty offer is a legal, long-lived state, not a "needs a roll" sentinel.** `World._grow()` used
## `offer.is_empty()` as exactly that, which becomes a roll every single frame once banking lands; it
## checks `species_eaten` too now.
##
## `BITE` and `DASH` are not in the pool. They are the actives you are handed, not things offered — they
## are `SPECIES = NONE` and this filter is what keeps them out with no second list to maintain.
static func roll(rng: RandomNumberGenerator, species_eaten: PackedInt32Array) -> PackedInt32Array:
	var pool: Array = []
	for p in Parts.NAME.size():
		if Parts.SPECIES[p] < 0:
			continue
		if not species_eaten.has(Parts.SPECIES[p]):
			continue
		pool.append(p)
	var out := PackedInt32Array()
	for _i in mini(3, pool.size()):
		var k := rng.randi() % pool.size()
		out.append(pool[k])
		pool.remove_at(k)
	return out
