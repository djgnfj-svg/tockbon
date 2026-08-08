extends RefCounted
## The three-pick draw rule (`docs/plans/3.done/levelup-and-three-picks.md`, Stage C).
##
## **A pure function, rng-injected** — the same idiom as `stage.camera_center` and `monster_view.hp_bar_rect`:
##  a value can be produced and checked with no scene and no character, so the nets call it directly, headless
##  and seeded, instead of driving a screen to observe a draw.

const Glyph := preload("res://src/sim/glyph_defs.gd")

## **Candidates = `Glyph.ALL` minus every id already socketed.** That single `has()` *is* acceptance 5
##  ("the same rarity of something you already have never appears") — the id **is** the (family, rarity)
##  pair (Stage A's whole reason for folding rarity into the id rather than carrying it beside), so excluding
##  by exact id is already excluding by exact rarity. **Do not exclude by family** — that would also remove
##  every other rarity of an owned family, and acceptance 5 would read as "you never see spread again".
##
## **Picks 3 distinct at random. If fewer than 3 remain, takes what remains rather than repeating** — with
##  9 ids today and at most `CircleDefs.layers(CIRCLE_ROUND)` (2) socketed at once, at least 7 always remain,
##  so this branch is structurally unreachable through the real game (`net_three_pick` asserts that directly,
##  then drives this function past it anyway, since `draw()` itself does not know it is unreachable).
static func draw(owned: Array[int], rng: RandomNumberGenerator) -> Array[int]:
	var pool: Array[int] = []
	for id: int in Glyph.ALL:
		if not owned.has(id):
			pool.append(id)

	var take := mini(3, pool.size())
	# **Partial Fisher-Yates.** The first `take` slots end up a uniformly random selection without
	#  repetition, and nothing past `take` is ever touched or needs to be — a full shuffle of the whole pool
	#  would do the same job at a cost this doesn't need to pay.
	for i in take:
		var j := i + rng.randi_range(0, pool.size() - i - 1)
		var tmp: int = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, take)
