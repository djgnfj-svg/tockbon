extends RefCounted
## `src/actor/three_pick.gd` — the draw rule (`docs/plans/2.active/levelup-and-three-picks.md`, Stage C).

const Glyph := preload("res://src/sim/glyph_defs.gd")
const ThreePick := preload("res://src/actor/three_pick.gd")
const CircleDefs := preload("res://src/sim/circle_defs.gd")

## 1,000 seeded draws. Cheap and deterministic — a seed is just an int, so re-running is exact and free.
const SEEDS := 1000

## **The frequency check needs more samples than the others** — "does every id ever appear" settles fast,
## "does every id appear at roughly the same *rate*" needs enough draws for sampling noise to shrink below
## the gap between a correct shuffle (measured: 0.60% worst deviation) and a biased one (measured: 42.76%).
const FREQ_SEEDS := 10000
## **±3 percentage points — about 6 standard deviations of sampling noise at this sample size**
## (`sqrt(p(1-p)/n)` at `p=1/3, n=10000` is ~0.47%), nowhere near flaking on the correct shuffle and nowhere
## near wide enough to let the naive one (13+ points off) through.
const FREQ_TOLERANCE := 0.03


func run(t) -> void:
	_three_distinct_candidates(t)
	_owned_id_never_appears(t)
	_different_rarity_of_owned_family_appears(t)
	_every_id_is_reachable(t)
	_every_id_appears_at_a_uniform_frequency(t)
	_full_layers_still_yield_three(t)
	_fallback_branch_is_unreachable_today(t)
	_fallback_takes_what_remains_without_repeating(t)


## **1,000 seeded draws — no two of the three are ever equal.** Acceptance 4's whole claim.
func _three_distinct_candidates(t) -> void:
	var rng := RandomNumberGenerator.new()
	var bad := 0
	var wrong_size := 0
	for s in SEEDS:
		rng.seed = s
		var drawn := ThreePick.draw([], rng)
		if drawn.size() != 3:
			wrong_size += 1
			continue
		if drawn[0] == drawn[1] or drawn[0] == drawn[2] or drawn[1] == drawn[2]:
			bad += 1
	t.eq(wrong_size, 0, "빈 서고에서는 %d번 다 정확히 세 장이 나왔다" % SEEDS)
	t.eq(bad, 0, "%d번 뽑는 동안 세 장 중 둘이 같았던 적이 한 번도 없다" % SEEDS)


## **An owned id never appears.** Acceptance 5's exclusion half.
func _owned_id_never_appears(t) -> void:
	var rng := RandomNumberGenerator.new()
	var owned: Array[int] = [Glyph.SPREAD_C, Glyph.BLAST_R]
	var bad := 0
	for s in SEEDS:
		rng.seed = s
		for id: int in ThreePick.draw(owned, rng):
			if owned.has(id):
				bad += 1
	t.eq(bad, 0, "%d번 뽑는 동안 이미 가진 문양(%s)이 나온 적이 없다" % [SEEDS, owned])


## **A different rarity of an owned family does appear.** Acceptance 5's other half — and the one an id-list
## exclusion can silently fail if rewritten to exclude by family instead: excluding `family_of(owned)` would
## remove every rarity of spread the moment any one is owned, and "the same rarity never appears" would read
## as "you never see spread again". `Glyph.pack`/`family_of` are untouched by this file — it only calls
## `three_pick.draw`, so this net is the one that actually catches that exact class of mistake.
func _different_rarity_of_owned_family_appears(t) -> void:
	var rng := RandomNumberGenerator.new()
	var owned: Array[int] = [Glyph.SPREAD_C]
	var saw_other_rarity := false
	for s in SEEDS:
		rng.seed = s
		for id: int in ThreePick.draw(owned, rng):
			if id == Glyph.SPREAD_R or id == Glyph.SPREAD_U:
				saw_other_rarity = true
				break
	t.ok(saw_other_rarity,
		"확산(일반)을 가진 채로도 확산(희귀/유니크)이 뽑힌 적이 있다 (계통 전체를 막지 않는다)")


## **Every id in the pool is reachable over enough draws.** Inversion: an off-by-one in the shuffle index
## would leave exactly one id permanently unreachable while every other check here stays green (nothing
## asserts *coverage*, only "no repeats" and "no owned ids") — nobody barks, one candidate just never shows.
func _every_id_is_reachable(t) -> void:
	var rng := RandomNumberGenerator.new()
	var seen: Dictionary = {}
	for s in SEEDS:
		rng.seed = s
		for id: int in ThreePick.draw([], rng):
			seen[id] = true
	t.eq(seen.size(), Glyph.ALL.size(),
		"%d번 뽑는 동안 %d개 문양이 전부 최소 한 번은 나왔다" % [SEEDS, Glyph.ALL.size()])
	for id: int in Glyph.ALL:
		t.ok(seen.has(id), "문양 %d가 최소 한 번은 뽑혔다" % id)


## **A biased-but-passing shuffle survives every check above.** Replacing the partial Fisher-Yates index
## (`i + randi_range(0, pool.size()-i-1)`) with the naive `randi_range(0, pool.size()-1)` keeps every draw a
## valid permutation with no duplicates and every id still individually reachable — the two properties
## every check above measures — so none of them see it. Only *how often* each id appears differs: measured,
## the naive form skews as high as 47.6% for `SPREAD_U` against an ideal 33.33% (id 9, the last position in
## `Glyph.ALL` — the bias comes from index, not content), a 42.76% relative deviation driven by nothing but
## where an id happens to sit in the list.
func _every_id_appears_at_a_uniform_frequency(t) -> void:
	var rng := RandomNumberGenerator.new()
	var counts: Dictionary = {}
	for id: int in Glyph.ALL:
		counts[id] = 0
	for s in FREQ_SEEDS:
		rng.seed = 500000 + s
		for id: int in ThreePick.draw([], rng):
			counts[id] = int(counts[id]) + 1

	var want := 3.0 / float(Glyph.ALL.size())
	var worst := 0.0
	for id: int in Glyph.ALL:
		var freq := float(counts[id]) / float(FREQ_SEEDS)
		var dev := absf(freq - want)
		worst = maxf(worst, dev)
		t.ok(dev <= FREQ_TOLERANCE,
			"문양 %d의 등장 빈도(%.4f)가 이상값(%.4f)에서 %.1f%%p 넘게 안 벗어난다 (실제 벗어남 %.2f%%p)" % [
				id, freq, want, FREQ_TOLERANCE * 100.0, dev * 100.0])
	t.ok(worst <= FREQ_TOLERANCE,
		"%d번 뽑는 동안 가장 벗어난 문양도 허용 범위 안이다 (최대 벗어남 %.2f%%p)" % [FREQ_SEEDS, worst * 100.0])


## **A full-layer circle still yields 3 candidates.** The default circle has 2 layers, so `owned` can hold at
## most 2 ids today — nowhere near draining the 9-id pool, but this is the check that actually drives that
## real ceiling through `draw()`, not just the arithmetic below.
func _full_layers_still_yield_three(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var owned: Array[int] = [Glyph.SPREAD_C, Glyph.BLAST_C]
	t.eq(CircleDefs.layers(CircleDefs.CIRCLE_ROUND), owned.size(),
		"오늘 진의 층수가 owned 크기와 같다 (검사의 전제)")
	var drawn := ThreePick.draw(owned, rng)
	t.eq(drawn.size(), 3, "층이 가득 차 있어도 여전히 세 장이 나온다")


## **The pool is large enough that "take what remains" is unreachable today, asserted directly** (the plan's
## own instruction) — 9 ids total, at most `CircleDefs.layers(CIRCLE_ROUND)` (2) socketed at once, so at
## least 7 always remain, comfortably above 3.
func _fallback_branch_is_unreachable_today(t) -> void:
	var max_owned := CircleDefs.layers(CircleDefs.CIRCLE_ROUND)
	var remaining := Glyph.ALL.size() - max_owned
	t.ok(remaining >= 3,
		"오늘 최대로 채워도(%d칸) 최소 %d개가 남는다 (3보다 적게 남는 경우가 없다)" % [max_owned, remaining])


## **`draw()` itself does not know the branch above is unreachable through the real game** — it is a pure
## function, so it is driven past that ceiling directly (an `owned` list no in-game circle could ever build)
## to prove the fallback behaves correctly *if* it were ever reached, not just that it currently cannot be.
func _fallback_takes_what_remains_without_repeating(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var owned: Array[int] = Glyph.ALL.duplicate()
	owned.remove_at(0)
	t.eq(owned.size(), Glyph.ALL.size() - 1, "전부 하나만 빼고 가졌다 (전제)")
	var drawn := ThreePick.draw(owned, rng)
	t.eq(drawn.size(), 1, "남은 게 하나뿐이면 하나만 준다 (반복해서 채우지 않는다)")
	if drawn.size() == 1:
		t.eq(drawn[0], Glyph.ALL[0], "그 하나가 실제로 안 가진 문양이다")

	# Zero remaining — draw() must not crash or wrap around to owned ids.
	var owned_all: Array[int] = Glyph.ALL.duplicate()
	var drawn_none := ThreePick.draw(owned_all, rng)
	t.eq(drawn_none.size(), 0, "남은 게 하나도 없으면 빈 목록을 준다 (죽지 않는다)")
