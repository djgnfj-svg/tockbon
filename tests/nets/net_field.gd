extends RefCounted
## The creature table: what is on the field at `t = 0`, what a spawn writes, what a removal carries down,
## and the two axes that replaced `threat`.
##
## **The shape this file exists for is the flat-table swap.** `_remove_critter()` moves the last row down
## over the dead one; a column it does not know about lands a stranger's number on a survivor with no error
## and nothing on screen. It only shows when the row removed is **not** the last one — killing the only
## creature never enters the swap branch and every missing line stays green.
##
## `boss_index` is the seventh thing that removal repairs and it is not a column, so it needs its own
## assertions on **both** halves: the boss dying, and the boss being the last row swapped down over someone
## else. One of them alone leaves an index pointing at a stranger.
##
## Seeds 400–419 are this file's own block, so two nets can never share a world by accident.

const DT := 1.0 / 60.0
const CROW := int(Parts.Species.CROW)
const HORSE := int(Parts.Species.HORSE)
const BOSS := int(Parts.Species.BOSS)
## How many real species there are — `Parts.Species.NONE` is a member of the enum and is NOT one, so this is
## `Species.size() - 1`. **A literal on purpose**: every `SPECIES_*` table is compared to this number and
## never to another table's length, because arrays that agree with each other pass on a set where all of
## them are short. See `_c31_every_species_table_is_eleven_rows`.
const ROWS := 11


## A `World` with one species held shut, so **`setup()`'s own unlock gate can be driven.**
##
## ⚠ **That branch is unreachable through the shipped tables** — every row with a non-zero `SPECIES_START`
## also has `SPECIES_UNLOCK_AT` 0.0, so deleting the `continue` in `setup()` changes nothing today and stays
## green. It is not decoration: it is what makes "a start of N and a gate of 105s" impossible to ship as a
## contradiction the layout quietly wins. Overriding the one function the comparison lives in is the only
## way to ask the question without a second copy of the rule.
class LockedWorld extends World:
	var locked := -1

	func species_unlocked(s: int, at: float) -> bool:
		return s != locked and super.species_unlocked(s, at)


func run(t) -> void:
	_c1_opening_field(t)
	_c2_spawn_writes_every_column(t)
	_c3_removal_swap(t)
	_c4_disposition(t)
	_c5_the_horse_flees_a_clone(t)
	_c21_drop_rate(t)
	_u7a_only_droppable_parts_roll(t)
	_u7b_a_swap_cannot_drop_a_clone_below_the_floor(t)
	_c29_instruments(t)
	_c30_size_never_inverts(t)
	_c31_every_species_table_is_eleven_rows(t)
	_c32_every_species_spawns_walks_and_dies(t)
	await _c33_the_opening_pocket(t)
	_f1b_a_crow_does_not_one_shot(t)
	_f2_boss_placement(t)
	_u12_where_the_boss_opens(t)
	_f2b_the_boss_dies(t)
	_f3_nothing_spawns_in_a_rock(t)
	_f4_spawn_species_roll(t)
	_f5_each_creature_walks_once_per_frame(t)
	_g1_wandering_is_a_column(t)
	_g2_the_lion_is_the_only_hunter(t)
	_g3_a_herd_is_born_together(t)
	_a3_knockback_is_proportional_and_survives_a_rock(t)
	_d1_boss_hunt_announces_once(t)


# -- 1: the field at t = 0 -------------------------------------------------------------------------------
## Counted by species against literals, never against `Rules.CRITTER_START_*` read back — read through the
## constants this check passes at every value including the zero that would open an empty field.
func _c1_opening_field(t) -> void:
	var w := World.new()
	w.setup(400)
	# ⚠ **Eleven counters, because the opening is `SPECIES_START × SPECIES_HERD` and a `match` over three
	# names silently counts a four-species field as three.** The literals below are that product written out
	# per species — a herd count read as a head count is the exact bug this check exists to catch. The array
	# is sized to the whole enum rather than to what happens to spawn: a row whose `SPECIES_START` is turned
	# on later must land in a counter that exists, not past the end of this list.
	var per := [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	t.eq(per.size(), ROWS, "설정: 세는 칸이 종의 수만큼 있다 — 짧으면 새 종이 배열 밖으로 떨어진다")
	for k in w.critter_count:
		var s := int(w.critter_species[k])
		per[s] = int(per[s]) + 1
	# ⚠ **Every number below is `START × HERD` PLUS what `OPENING_POCKET` places, written out by hand.**
	# Derived from the tables these lines would move with whatever they check; and the pocket is exactly the
	# part a table-derived count cannot see — it is four bodies placed after the layout loop, and asserting
	# only the product would stay green if `_place_pocket()` were deleted outright.
	t.eq(int(per[CROW]), 11, "런은 까마귀 열하나로 연다 — 열 무리 + 주머니의 한 마리")
	t.eq(int(per[HORSE]), 8, "그리고 말 두 무리 — 네 마리씩 여덟")
	t.eq(int(per[Parts.Species.SQUIRREL]), 9, "다람쥐 네 무리 여덟 + 주머니의 한 마리")
	t.eq(int(per[Parts.Species.CHEETAH]), 1, "치타 하나 — 무리를 짓지 않는다")
	t.eq(int(per[Parts.Species.MOUSE]), 20, "들쥐 세 무리 열여덟 + 주머니의 둘 — 개막에 가장 많은 몸이다")
	t.eq(int(per[Parts.Species.RABBIT]), 8, "토끼 두 무리 — 넷씩 여덟")
	t.eq(int(per[BOSS]), 1, "보스는 정확히 하나다 — 주기적 스폰은 보스를 굴리지 않는다")
	# ⚠ **Four rows are absent from the opening on purpose, and NOT because their tables are empty.**
	# 코끼리·사자 one-shot a fresh host and 들개·멧돼지 are the 45s and 75s beats; all four carry a non-zero
	# `SPECIES_SPAWN_WEIGHT`, so "it has a weight" and "it is on the opening field" are two different
	# questions and this is the line that keeps them apart. Bare zeros on purpose — read as
	# `START × HERD` this loop passes for a species whose start was turned on and whose gate was forgotten.
	for s in [Parts.Species.ELEPHANT, Parts.Species.LION, Parts.Species.DOG, Parts.Species.BOAR]:
		t.eq(int(per[s]), 0,
				"%d종은 개막에 한 마리도 없다 — 시간이 지나야 생긴다 (SPECIES_UNLOCK_AT %.0f초)"
						% [s, float(Rules.SPECIES_UNLOCK_AT[s])])
		t.ok(int(Rules.SPECIES_SPAWN_WEIGHT[s]) > 0,
				"그런데 가중치는 0이 아니다 — 잠금은 「언제」고 가중치는 「얼마나 자주」다")
	t.eq(w.critter_count, 58, "합쳐서 쉰여덟 마리다 (리터럴)")
	t.ok(w.critter_count < Rules.CRITTER_MAX,
			"그리고 그 서른둘은 상한 아래다 — 상한에 닿으면 이후의 도착은 전부 조용히 무시된다 (%d < %d)"
					% [w.critter_count, Rules.CRITTER_MAX])
	t.ok(w.boss_index >= 0 and int(w.critter_species[w.boss_index]) == BOSS,
			"boss_index가 실제 보스 줄을 가리킨다 (%d)" % w.boss_index)

	# The periodic spawn never rolls the boss, over enough calls that a one-in-three roll could not hide.
	var w2 := World.new()
	w2.setup(401)
	var rolled_boss := 0
	for _n in 60:
		w2.critter_count = 0
		w2.boss_index = -1
		w2._spawn_critter()
		if int(w2.critter_species[0]) == BOSS:
			rolled_boss += 1
	t.eq(rolled_boss, 0, "예순 번을 더 굴려도 두 번째 보스는 나오지 않는다")

	# -- `setup()` reads the gate too, driven through `LockedWorld` -----------------------------------
	# The control first: the same subclass with nothing locked has to lay out the same field as `World`,
	# or the fixture below is measuring the subclass rather than the gate.
	var wc := LockedWorld.new()
	wc.setup(400)
	t.eq(wc.critter_count, w.critter_count,
			"설정: 아무것도 잠그지 않은 하위 클래스는 같은 필드를 편다 (%d)" % wc.critter_count)
	var wl := LockedWorld.new()
	wl.locked = int(Parts.Species.MOUSE)
	wl.setup(400)
	var mice := 0
	for k in wl.critter_count:
		if int(wl.critter_species[k]) == int(Parts.Species.MOUSE):
			mice += 1
	# The pocket is placed by hand and does NOT consult the gate — it is the run's authored first ten
	# seconds, not a rolled species — so two survive. The eighteen from the layout do not.
	t.eq(mice, 2,
			"들쥐를 잠그면 개막의 열여덟 마리가 사라진다 — 주머니의 둘만 남는다 (%d)" % mice)
	t.ok(wl.critter_count < wc.critter_count,
			"그래서 필드도 그만큼 작다 — 시작 칸이 켜진 채 잠긴 종은 배치가 조용히 이기지 못한다 (%d < %d)"
					% [wl.critter_count, wc.critter_count])


# -- 2: `_spawn_at` writes EVERY column ------------------------------------------------------------------
## ⚠ **`resize()` zero-fills**, so a dropped line is not an error — it is a creature that walks the field as
## species CROW at force 0 with hp 0, or one whose direction is `Vector2.ZERO` and therefore never wanders
## and is drawn at rotation 0. Every one is asserted, because "any one of six" left `dir` and `counter`
## uncovered — and the two columns whose opening value EQUALS the zero-fill need a vacated row to be measured
## at all, which is the second fixture at the bottom of this function. The count itself is stated once, in
## `world.gd`'s own declaration block, and nowhere here.
func _c2_spawn_writes_every_column(t) -> void:
	var w := World.new()
	w.setup(402)
	_silence_food(w)
	# The opening field is cleared so the row this check reads is the one the TIMER made, not one of the
	# twelve `setup()` placed. `boss_index` goes with it — an index into an emptied table is a stranger.
	w.critter_count = 0
	w.boss_index = -1
	# 20 steps at dt = 1.0 is exactly `CRITTER_INTERVAL`, and the spawn fires on the step that reaches zero.
	# Stepping the real clock rather than calling `_spawn_critter()` by hand is what keeps the timer itself
	# in the check: a spawner nothing ever calls is the same picture as one that writes nothing.
	#
	# ⚠ **An arrival is a HERD, so the count is a range and not 1.** Pinned at 1 this check would red for
	# every species whose `SPECIES_HERD` row is above one — which is four of the six that can be rolled.
	for _s in 20:
		w.step(1.0)
	var s := int(w.critter_species[0])
	t.ok(w.critter_count >= 1 and w.critter_count <= int(Rules.SPECIES_HERD[s]),
			"설정: 20초에 무리 하나가 통째로 들어왔다 (%d마리, %d종의 무리는 %d)"
					% [w.critter_count, s, int(Rules.SPECIES_HERD[s])])
	t.ok(s != BOSS and int(Rules.SPECIES_SPAWN_WEIGHT[s]) > 0,
			"20초에 들어온 것은 가중치가 있는 종이다 — 보스는 굴려지지 않는다 (%d)" % s)
	var lo := int(Rules.SPECIES_FORCE_MIN[s])
	var hi := int(Rules.SPECIES_FORCE_MAX[s])
	var f := int(w.critter_force[0])
	t.ok(f >= lo and f <= hi, "그 힘은 제 종의 범위 안이다 (%d ∈ [%d, %d])" % [f, lo, hi])
	t.eq(int(w.critter_hp[0]), f * 3, "체력은 힘 × 3이다 (리터럴 3) — 0이면 첫 대에 시체가 된다")
	t.eq(int(w.critter_flees[0]), int(Rules.SPECIES_FLEES[s]), "성향은 제 종의 것으로 태어난다")
	t.eq(w.critter_atk_cd[0], 0.0, "공격 시계는 0에서 — 모든 몸과 모든 생물이 준비된 채로 연다")
	t.eq(w.critter_counter[0], 0.0, "반격 시계는 0에서 연다")
	var d: Vector2 = w.critter_dir[0]
	t.ok(absf(d.length() - 1.0) < 0.001,
			"방향은 길이 1짜리 단위 벡터다 — 0이면 영영 안 움직이고 회전 0으로 그려진다 (%.4f)" % d.length())
	# `INF`는 zero-fill이 아니다 — 이 값 하나만으로도 실제로 써진 것을 잰다.
	t.eq(w.critter_hit_show[0], INF, "피격 시계는 INF로 연다 — 아직 한 번도 안 맞았다")
	t.eq(w.critter_swing_show[0], INF, "휘두른 시계도 INF로 연다 — 아직 한 번도 안 휘둘렀다")

	# ⚠ **`critter_hit_dir`는 `Vector2.ZERO`로 여는데, 그것이 zero-fill과 같아서 갓 만든 세상에서는 이 줄이
	# 빠져도 티가 안 난다.** 그래서 그 줄을 지워도 초록이었다 — 그리고 이 검사의 주석은 "`_c3`가 대신한다"고
	# 적어 두었지만 `_c3`가 재는 것은 제거 스왑이지 스폰 쓰기가 아니다. 미룬 부류는 아무도 안 집었다.
	# **비워진 줄에 구분되는 값을 남긴 뒤 그 줄에 새로 태어나게 한다** — `resize()`로 잡아 둔 배열은 지워지지
	# 않으므로, 초기화가 빠지면 새 생물이 죽은 생물의 마지막 피격 방향을 그대로 물려받는다.
	var wr := World.new()
	wr.setup(409)
	_silence_food(wr)
	_clear_terrain(wr)
	wr.critter_count = 0
	wr.boss_index = -1
	var doomed := wr._write_critter(CROW, wr.swarm.pos[0] + Vector2(600.0, 0.0), 10)
	t.eq(doomed, 0, "설정: 그 생물은 0번 줄에 태어났다")
	wr.critter_hit_dir[0] = Vector2(0.6, 0.8)
	wr.critter_hit_show[0] = 1.23
	wr.critter_swing_dir[0] = Vector2(0.8, -0.6)
	wr.critter_swing_show[0] = 2.34
	wr._remove_critter(0)
	t.eq(wr.critter_count, 0, "설정: 그 줄이 비었다 — 배열의 값은 그대로 남아 있다")
	t.eq(wr.critter_hit_dir[0], Vector2(0.6, 0.8), "설정: 남은 값이 실제로 zero가 아니다")
	var born := wr._write_critter(HORSE, wr.swarm.pos[0] + Vector2(-600.0, 0.0), 30)
	t.eq(born, 0, "설정: 새 생물이 바로 그 줄에 태어났다")
	t.eq(wr.critter_hit_dir[0], Vector2.ZERO,
			"갓 태어난 생물의 피격 방향은 0이다 — 죽은 생물의 마지막 방향을 물려받지 않는다 (%s)"
					% str(wr.critter_hit_dir[0]))
	t.eq(wr.critter_hit_show[0], INF, "그리고 피격 시계도 INF로 다시 열린다 — 1.23이 남지 않는다")
	t.eq(wr.critter_swing_dir[0], Vector2.ZERO,
			"갓 태어난 생물의 휘두른 방향도 0이다 — 죽은 생물의 마지막 휘두름을 물려받지 않는다 (%s)"
					% str(wr.critter_swing_dir[0]))
	t.eq(wr.critter_swing_show[0], INF, "그리고 휘두른 시계도 INF로 다시 열린다 — 2.34가 남지 않는다")

	# -- the two distances, and they are two different rules ------------------------------------------
	# ⚠ **This used to drive `setup()` and assert 900, and it was measuring the wrong rule the whole time.**
	# `CRITTER_SPAWN_MIN_DIST` is about ARRIVALS — a creature that pops into existence in your lap — and
	# `setup()` places a field that was simply always there. Reading the opening layout through the arrival
	# constant is what kept every creature 900px off the opening camera at every seed, forever, and bumping
	# this literal to the arrival number would have left the check green while still measuring `setup()`.
	#
	# So: arrivals are driven through `_spawn_critter()`, and the opening gets its own check below.
	var worst := INF
	for n in 10:
		var w3 := World.new()
		w3.setup(403 + n)
		w3.critter_count = 0
		w3.boss_index = -1
		# Eight arrivals a seed = 80 herds. **A herd, not a body**: a member is placed within
		# `SPAWN_HERD_SPREAD` of the anchor without re-testing, so a member is the one that lands short.
		for _r in 8:
			w3._spawn_critter()
			for k in w3.critter_count:
				worst = minf(worst, w3.critter_pos[k].distance_to(w3.swarm.pos[0]))
			w3.critter_count = 0
	# 1450 as a LITERAL. Read back off the constant this passes at any value including zero.
	t.ok(worst >= 950.0,
			"열 판 × 여덟 무리를 굴려도 도착은 화면 밖에서 일어난다 (%.0f, 리터럴 950)" % worst)
	# **And the rejection sampler actually reaches that distance**, which is a separate claim from the
	# constant being large. `_spawn_at` gives up after `PLACE_TRIES` and takes the last rejected sample, so
	# at the arrival distance the legal area is a fraction of the field for a herd anchor and twelve tries fell through on
	# **7.6% of herd bodies** — measured. The count above is what says forty tries closed it; this line
	# names the number so the next person who lowers `PLACE_TRIES` sees why it is 40.
	t.ok(Rules.PLACE_TRIES >= 40,
			"그리고 뽑기가 그 거리에 실제로 닿는다 — 시도가 40 미만이면 무리는 화면 안에서 태어난다 (%d)"
					% Rules.PLACE_TRIES)

	# The opening field is the OTHER rule, and it is the one the player was complaining about.
	var opening := INF
	for n in 10:
		var w4 := World.new()
		w4.setup(423 + n)
		for k in w4.critter_count:
			if k == w4.boss_index:
				continue
			opening = minf(opening, w4.critter_pos[k].distance_to(w4.swarm.pos[0]))
	t.ok(opening >= 260.0,
			"개막의 필드는 무릎 위에서 시작하지 않는다 (%.0f, 리터럴 260)" % opening)
	# ⚠ **The upper bound is the whole point and it is what nothing measured for two plans.** The opening
	# camera's half-diagonal is 700px; a floor alone is satisfied by an empty screen, which is exactly what
	# shipped. 700 as a literal — read back off `Look.ZOOM_NEAR` it moves with whatever it is checking.
	t.ok(opening <= 700.0,
			"그리고 첫 화면 안에 뭔가가 서 있다 — 700px는 개막 카메라의 반대각선이다 (%.0f, 리터럴 700)"
					% opening)


# -- 3: the removal swap, EVERY column and `boss_index` --------------------------------------------------
## ⚠ **The row removed is NOT the last one.** `_remove_critter(k)` only enters its swap branch when
## `k != last`; removing the only creature leaves every missing line green.
##
## The last row is the BOSS on purpose, so one fixture measures the swap and the `last == boss_index` half
## of the repair at once — and the eight values it carries down are literals written before the removal,
## never read back off the table afterwards.
func _c3_removal_swap(t) -> void:
	var w := World.new()
	w.setup(404)
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(CROW, Vector2(100.0, 100.0), 10)
	w._write_critter(HORSE, Vector2(200.0, 200.0), 30)
	var b := w._write_critter(BOSS, Vector2(1234.0, 567.0), 120)
	w.boss_index = b
	t.eq(w.critter_count, 3, "설정: 세 줄을 세웠다")
	t.eq(b, 2, "설정: 보스가 마지막 줄이다 — 이 검사는 그 줄이 내려오는 것을 잰다")
	# Written by hand so every value below is a literal rather than whatever `_write_critter` rolled.
	# ⚠ **`flees` is 1, and it is the one column here whose value had to be CHOSEN rather than picked.**
	# The boss's own disposition is 0 and so is the crow's, so `= 0` / expect `0` was a value the
	# DESTINATION row already held: dropping `critter_flees[k] = critter_flees[last]` from
	# `_remove_critter` left this whole check green while its seven siblings reddened. Every other column
	# here is distinctive by luck; this one is distinctive on purpose. A dead creature's disposition
	# landing on a survivor is a horse that stops fleeing and a crow that starts running.
	w.critter_dir[b] = Vector2(0.0, 1.0)
	w.critter_hp[b] = 361
	w.critter_flees[b] = 1
	w.critter_atk_cd[b] = 0.75
	w.critter_counter[b] = 1.25
	# ⚠ **`critter_hit_dir`는 zero-fill과 같은 `Vector2.ZERO`로 열린다.** `flees`의 주석이 이미 말한 그
	# 함정이다 — 목적지 줄이 이미 들고 있는 값을 기대하면 스왑이 빠져도 초록이다. `0.42`와 `(-1,0)`은 그
	# 어떤 줄의 zero-fill도 아닌, 손으로 고른 값이다.
	w.critter_hit_show[b] = 0.42
	w.critter_hit_dir[b] = Vector2(-1.0, 0.0)
	w.critter_swing_show[b] = 0.31
	w.critter_swing_dir[b] = Vector2(0.0, -1.0)

	w._remove_critter(0)
	t.eq(w.critter_count, 2, "가운데가 아니라 첫 줄을 지웠고 두 줄이 남았다")
	t.eq(w.critter_pos[0], Vector2(1234.0, 567.0), "자리를 그대로 들고 내려왔다")
	t.eq(w.critter_dir[0], Vector2(0.0, 1.0), "방향도 제 것이다")
	t.eq(int(w.critter_species[0]), BOSS, "종도 제 것이다")
	t.eq(int(w.critter_force[0]), 120, "힘도 제 것이다")
	t.eq(int(w.critter_hp[0]), 361, "체력도 제 것이다")
	t.eq(int(w.critter_flees[0]), 1, "성향도 제 것이다 — 목적지가 이미 들고 있던 0이 아니다")
	t.eq(w.critter_atk_cd[0], 0.75, "공격 시계도 제 것이다")
	t.eq(w.critter_counter[0], 1.25, "반격 시계도 제 것이다")
	# `t.eq`가 아니라 오차 비교다: `critter_hit_show`는 `PackedFloat32Array`라 0.42는 float64 리터럴과
	# 정확히 같지 않다 — 정밀도 손실이지 스왑의 결함이 아니다.
	t.ok(absf(w.critter_hit_show[0] - 0.42) < 0.0001, "피격 시계도 제 것이다 (%.6f)" % w.critter_hit_show[0])
	t.eq(w.critter_hit_dir[0], Vector2(-1.0, 0.0), "피격 방향도 제 것이다")
	t.ok(absf(w.critter_swing_show[0] - 0.31) < 0.0001,
			"휘두른 시계도 제 것이다 (%.6f)" % w.critter_swing_show[0])
	t.eq(w.critter_swing_dir[0], Vector2(0.0, -1.0), "휘두른 방향도 제 것이다")
	t.eq(w.boss_index, 0, "그리고 boss_index가 따라 내려왔다 — 열이 아니라 인덱스라 따로 고쳐야 한다")


# -- 4: disposition comes from the species and damage does not change it ---------------------------------
## **Replaces the plan's "step a horse for 10s and it still flees"**, which measures the absence of code
## nobody wrote and can never fail. What CAN go wrong is `_damage_critter` arming the counter for every
## species instead of the crow's, or clearing `flees` on damage — so the check damages a horse and reads
## both columns back.
func _c4_disposition(t) -> void:
	var w := World.new()
	w.setup(414)
	var seen := {}
	for k in w.critter_count:
		var s := int(w.critter_species[k])
		var right: bool = int(w.critter_flees[k]) == int(Rules.SPECIES_FLEES[s])
		seen[s] = bool(seen.get(s, true)) and right
	# ⚠ **Seven of ELEVEN, and WHICH seven is the assertion — the count alone is not.** The set changed
	# under this check without the number moving: 코끼리 and 사자 left the opening field and 들쥐 and 토끼
	# took their places, six either way. A check on `seen.size()` alone was green through that swap, which
	# is the whole of "a check that reads only final state cannot measure what changed".
	var opens := [CROW, HORSE, BOSS, int(Parts.Species.SQUIRREL), int(Parts.Species.CHEETAH),
			int(Parts.Species.MOUSE), int(Parts.Species.RABBIT)]
	t.eq(opens.size(), 7, "설정: 개막에 있어야 할 종을 일곱으로 못 박는다 (리터럴)")
	for s: int in opens:
		t.ok(seen.has(s), "%d종은 개막의 필드에 실제로 있다" % s)
	t.eq(seen.size(), opens.size(), "그리고 그 일곱 말고는 아무도 없다 %s" % str(seen.keys()))
	# The other four, by the two tables that keep them out — a start of 0, or a gate above 0.
	for s in [int(Parts.Species.ELEPHANT), int(Parts.Species.LION), int(Parts.Species.DOG),
			int(Parts.Species.BOAR)]:
		t.ok(not seen.has(s), "%d종은 개막에 없다" % s)
		t.eq(int(Rules.SPECIES_START[s]), 0, "그 종의 시작 칸은 0이고")
		t.ok(float(Rules.SPECIES_UNLOCK_AT[s]) > 0.0,
				"잠금도 0초가 아니다 — 둘 중 하나만이면 나머지 하나가 조용히 뒤집을 수 있다 (%.0f초)"
						% float(Rules.SPECIES_UNLOCK_AT[s]))
	var all_right := true
	for s: int in seen:
		all_right = all_right and bool(seen[s])
	t.ok(all_right, "필드에 있는 일곱 종 모두 제 종의 성향을 들고 태어난다")

	var w2 := World.new()
	w2.setup(415)
	_silence_food(w2)
	_clear_terrain(w2)
	w2.critter_count = 0
	w2.boss_index = -1
	w2._write_critter(HORSE, Vector2(1500.0, 1000.0), 30)
	w2.critter_hp[0] = 900
	for _n in 5:
		w2._damage_critter(0, 1)
		for _s in 120:
			w2._step_critters(DT)
	t.eq(int(w2.critter_flees[0]), 1, "열 초 동안 다섯 번 맞아도 말은 여전히 도망치는 쪽이다")
	t.eq(w2.critter_counter[0], 0.0, "그리고 말에게는 반격 시계가 걸리지 않는다 — 그건 까마귀의 것이다")

	var w3 := World.new()
	w3.setup(416)
	w3.critter_count = 0
	w3.boss_index = -1
	w3._write_critter(CROW, Vector2(1500.0, 1000.0), 10)
	w3._damage_critter(0, 1)
	t.eq(w3.critter_counter[0], Rules.CROW_COUNTER_TIME,
			"대조: 같은 한 대가 까마귀에게는 반격 시계를 건다 — 아무에게도 안 걸리는 검사가 아니다")


# -- 5: the horse flees a CLONE as readily as the host ---------------------------------------------------
## The host is 3000px away and outside `CRITTER_SENSE` entirely, so the only body this horse can see is a
## clone. A flee scan written against `swarm.pos[0]` finds nothing at all and the horse stands still.
func _c5_the_horse_flees_a_clone(t) -> void:
	var w := World.new()
	w.setup(405)
	_silence_food(w)
	_clear_terrain(w)
	w.swarm.pos[0] = Vector2(100.0, 100.0)
	var c := w.swarm.add_clone(0, 2)
	w.swarm.pos[c] = Vector2(3000.0, 1000.0)
	w.swarm.command_strike(Vector2(3000.0, 1000.0))
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(HORSE, Vector2(3300.0, 1000.0), 30)
	w.critter_dir[0] = Vector2.ZERO
	var host_gap: float = w.critter_pos[0].distance_to(w.swarm.pos[0])
	t.ok(host_gap > Rules.CRITTER_SENSE,
			"설정: 호스트는 감지 범위 밖이다 — 볼 수 있는 몸은 분신뿐이다 (%.0f)" % host_gap)
	var before: float = w.critter_pos[0].distance_to(w.swarm.pos[c])
	t.ok(absf(before - 300.0) < 0.01, "설정: 분신과 300px 떨어져 섰다 (%.2f)" % before)
	for _s in 60:
		w._step_critters(DT)
	var after: float = w.critter_pos[0].distance_to(w.swarm.pos[c])
	t.ok(after > before + 100.0,
			"말은 호스트가 아니라 분신에게서도 똑같이 도망친다 (%.0f → %.0f)" % [before, after])
	t.ok(w.critter_pos[0].x > 3300.0, "그리고 도망친 방향은 분신의 반대편이다")


# -- 21: `PART_DROP_CHANCE` as a RATIO -------------------------------------------------------------------
## ⚠ **Ten seeds × twenty DISTINCT clones, each alone on its own corpse.** `swarm.worn[eater] = p`
## overwrites and `_step_corpses` picks the lowest clone index in reach, so twenty corpses in one pile feed
## the same clone twenty times and "clones wearing something" undercounts every run.
##
## ⚠ **`_step_corpses` is driven directly.** Two hundred real meals through `world.step()` is ~21,000
## frames; seeding `progress` one frame short is the same measurement at a two-hundredth of the cost.
## ⚠ **§C floors every corpse at three bites regardless of `corpse_progress`.** One `_step_corpses()` call
## used to finish all twenty at `progress = 0.999`; now it only closes their first bite, so each round loops
## to `corpse_count == 0` instead. `_add_corpse()` replaces the hand-set rows — it is the production path and
## sets `corpse_bites_left` for free, and `progress = 0.999` is applied straight after to keep the first bite
## fast the same way the old fixture kept the whole meal fast.
func _c21_drop_rate(t) -> void:
	const BOUND := 200
	var trials := 0
	var wins := 0
	for n in 10:
		var w := World.new()
		w.setup(406 + n)
		_silence_food(w)
		_clear_terrain(w)
		w.critter_count = 0
		w.boss_index = -1
		for i in 20:
			var at := Vector2(200.0 + float(i) * 150.0, 500.0)
			var c := w.swarm.add_clone(0, 4)
			# Written straight into `pos`, not through `place()`: this fixture is about the roll and a body
			# nudged off its corpse by anything would simply not eat.
			w.swarm.pos[c] = at
			w._add_corpse(at, CROW, 10)
			w.corpse_progress[i] = 0.999
		if n == 0:
			t.eq(w.swarm.count, 21, "설정: 분신 스무 마리를 각자 제 시체 위에 세웠다")
			t.eq(w.corpse_bites_left[0], 3, "설정: 까마귀 시체는 세 입이다")
		var m := 0
		while w.corpse_count > 0 and m < BOUND:
			w._step_corpses(DT)
			m += 1
		if n == 0:
			t.eq(w.corpse_count, 0, "설정: 그 스무 구가 (세 입씩) 전부 끝났다 (%d프레임)" % m)
		for i in range(1, w.swarm.count):
			trials += 1
			if w.swarm.worn[i] >= 0:
				wins += 1
	t.eq(trials, 200, "설정: 시행 횟수가 200이다 — 분모를 먼저 못 박는다")
	var rate := float(wins) / float(trials)
	t.ok(rate >= 0.35 and rate <= 0.65,
			"부품이 떨어지는 비율은 0.5 언저리다 — 「가끔」이 아니라 비율이다 (%.3f)" % rate)


# -- U7a: the corpse roll obeys `Parts.DROPS` ------------------------------------------------------------
## ⚠ **`_c21_drop_rate` measures the RATE and never the pool.** Its callers roll until a wanted part appears
## and nothing anywhere says a `DROPS == 0` row may not come out, so dropping the
## `and int(Parts.DROPS[p]) == 1` term left the round green while `Cards.roll`'s identical term reddened.
## What that costs in play: 말 갈기 and 말 폐활량 — the two rows 결정 5 removed from BOTH pools — come back
## onto clones off horse corpses, so the deferral written into `HORSE_TRAIT_COUNT`'s own comment is false.
##
## ⚠ **`worn` is reset to -1 before every call and the successes are COUNTED.** Left set, the swap branch
## runs and the loop measures the last roll only; uncounted, a pool that produced nothing at all would pass
## with `bad == 0` for free.
func _u7a_only_droppable_parts_roll(t) -> void:
	var w := World.new()
	w.setup(452)
	_silence_food(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	var c := w.swarm.add_clone(0, 4)
	var rolls := 0
	var bad := 0
	for _n in 200:
		w.swarm.worn[c] = -1
		w._roll_part(c, HORSE)
		var p := int(w.swarm.worn[c])
		if p >= 0:
			rolls += 1
			if p != Parts.HORSE_LEGS:
				bad += 1
	t.ok(rolls >= 70 and rolls <= 130,
			"설정: 200번을 굴려 절반쯤은 실제로 떨어졌다 — 빈 풀이면 아래가 공짜로 통과한다 (%d)" % rolls)
	t.eq(bad, 0, "말 시체에서 나오는 부품은 말 다리뿐이다 — DROPS 0인 갈기와 폐활량은 굴러 나오지 않는다")

	# The other side of the same column: a BOSS corpse has no droppable row at all, so the pool is empty and
	# the roll returns having written nothing. Without this the check above passes on a filter that simply
	# rejects everything.
	w.swarm.worn[c] = -1
	for _n in 50:
		w._roll_part(c, BOSS)
	t.eq(int(w.swarm.worn[c]), -1, "대조: 보스 시체는 쉰 번을 굴려도 아무것도 남기지 않는다")


# -- U7b: a swap may not put a clone under `BODY_HP_MIN` -------------------------------------------------
## ⚠ **The `maxi(0, ...)` on the FORCE line one statement above reddens and this one did not**, because no
## fixture anywhere damages a clone before swapping its part — which is the exact state the floor's own
## two-line comment describes. A clone at 0 or negative hp is alive until something touches it.
##
## The loop rolls until a part with `HP 0` (날개 or 부리) replaces 까마귀 발 (`HP 3`); its count is asserted
## so a pool that never produced one cannot pass this as a zero-iteration walk.
func _u7b_a_swap_cannot_drop_a_clone_below_the_floor(t) -> void:
	var w := World.new()
	w.setup(453)
	_silence_food(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	var c := w.swarm.add_clone(0, 4)
	var tries := 0
	while tries < 400:
		w.swarm.worn[c] = Parts.CROW_FOOT
		w.swarm.hp[c] = 2
		w.swarm.force[c] = 20
		w._roll_part(c, CROW)
		tries += 1
		if int(w.swarm.worn[c]) != Parts.CROW_FOOT:
			break
	t.ok(tries > 0 and tries < 400, "설정: 까마귀 발이 아닌 부품이 실제로 굴러 나왔다 (%d번째)" % tries)
	t.eq(int(Parts.HP[int(w.swarm.worn[c])]), 0, "설정: 갈아 낀 그 부품의 HP는 0이다 (날개거나 부리)")
	t.eq(int(w.swarm.hp[c]), 1,
			"체력 2에서 HP 3짜리를 벗어도 1로 멈춘다 — 소화가 몸을 0 아래로 데려가지 않는다")
	t.eq(int(w.swarm.hp[c]), Rules.BODY_HP_MIN, "그리고 그 1은 BODY_HP_MIN 그 자체다")


# -- 29: the threat model is GONE, on four instruments ---------------------------------------------------
## ⚠ **This check was written inverted and the deletion step flipped it**, which is the only reason it can
## be trusted: every `not` below was once a `true` that passed against the live symbol, so each instrument is
## already proven to discriminate rather than merely to answer.
##
## **Four instruments, because no one of them sees all four kinds**: a `const` lives in the script's constant
## map, a method answers `has_method`, a `var` is invisible to both and only appears in
## `get_property_list()`, and `look.gd` has no `class_name` so its constants are reached through `load()`. A
## grep would measure a file's letters instead, and five greps shipped on this repo in one feature and every
## one of them was evaded.
##
## ⚠ **An absence check passes for free the day its instrument breaks.** An empty constant map, a `World`
## that failed to construct, an empty property list — each turns every `not` here into a green that measures
## nothing. So every instrument carries a **positive control naming a symbol that must still be there**, and
## `CRITTER_SENSE` is deliberately the surviving NEIGHBOUR of the deleted block: it proves the sweep took
## eight named constants and not the whole `# -- critters ---` section.
func _c29_instruments(t) -> void:
	var consts: Dictionary = Rules.new().get_script().get_script_constant_map()
	t.ok(consts.has("HP_PER_FORCE"), "설정: 상수 계기가 실제로 Rules를 읽었다 — 비면 아래가 저절로 통과한다")
	# The whole threat model's constant list, named one by one — `rules.gd`'s own comment points here rather
	# than repeating it. ⚠ **The size is pinned first**, because an absence check shrinks silently: drop a
	# name from this array and the round stays green while covering one symbol less, which is the same shape
	# as a loop whose condition is false from the start.
	var dead_names := ["FORCE_PER_THREAT", "CRITTER_THREAT_MIN", "CRITTER_THREAT_MAX", "CRITTER_RADIUS_BASE",
			"CRITTER_RADIUS_PER_THREAT", "CRITTER_MEAT", "CRITTER_SPEED", "CRITTER_START"]
	t.eq(dead_names.size(), 8, "설정: 지운 상수 여덟 개를 전부 이름으로 세운다 — 분모를 먼저 못 박는다")
	for dead in dead_names:
		t.ok(not consts.has(dead), "상수 계기: Rules.%s는 사라졌다" % dead)
	t.ok(not consts.has("FORCE_PER_NOTHING"), "대조: 없는 상수는 없다고 답한다")
	t.ok(consts.has("CRITTER_SENSE"),
			"대조: 이웃한 CRITTER_SENSE는 남아 있다 — 블록째 지운 게 아니라 여덟 개를 골라 지웠다")
	t.ok(consts.has("SPECIES_START") and consts.has("SPECIES_SPEED_MUL"),
			"대조: 지운 둘을 대신하는 종별 표는 실제로 있다")
	t.ok(not consts.has("CRITTER_START_CROW") and not consts.has("SPAWN_CROW_CHANCE"),
			"그리고 두 종만 알던 상수 둘은 표에 자리를 내주고 사라졌다")

	var w := World.new()
	t.ok(w.has_method("strike"), "설정: 메서드 계기가 실제로 World를 읽었다")
	t.ok(not w.has_method("is_hunter_of"), "메서드 계기: World.is_hunter_of는 사라졌다")
	t.ok(not w.has_method("is_hunter_of_nothing"), "대조: 없는 메서드는 없다고 답한다")

	# ⚠ **A `var` is invisible to both instruments above**, and a dead column surviving as a second source of
	# truth is exactly what the deletion exists to prevent. Revision 1 of the build spec used only the first
	# two instruments and would have let both of these through.
	var props := {}
	for p: Dictionary in w.get_property_list():
		props[String(p["name"])] = true
	t.ok(props.has("critter_species"), "설정: 속성 계기가 실제로 목록을 읽었다")
	t.ok(not props.has("critter_threat"), "속성 계기: World.critter_threat은 사라졌다")
	t.ok(not props.has("critters_eaten"), "속성 계기: World.critters_eaten도 사라졌다")
	t.ok(not props.has("critter_nothing"), "대조: 없는 속성은 없다고 답한다")

	var look_consts: Dictionary = (load("res://src/look.gd") as GDScript).get_script_constant_map()
	t.ok(look_consts.has("CROW_COLOR"), "설정: 색 계기가 실제로 look.gd를 읽었다")
	t.ok(not look_consts.has("CRITTER_COLOR"), "색 계기: Look.CRITTER_COLOR는 사라졌다")
	t.ok(not look_consts.has("CRITTER_PREY_COLOR"),
			"색 계기: 사냥감 파란색도 사라졌다 — 뒤집을 색이 없으니 남길 상수도 없다")
	t.ok(not look_consts.has("CRITTER_NOTHING_COLOR"), "대조: 없는 색은 없다고 답한다")


# -- 30: size never inverts ------------------------------------------------------------------------------
## ⚠ **Driven through `_radius_of`, not written as three bare literals.** The mutation this exists for is
## the missing `maxi(1, MAX - MIN)` span guard, and the boss's `120 / 0` NaN is only observable through the
## function: `18.0 < 22.0 < 48.0` as literals is true forever and measures nothing at all.
func _c30_size_never_inverts(t) -> void:
	var w := World.new()
	var crow_max := w._radius_of(CROW, 12)
	var horse_min := w._radius_of(HORSE, 30)
	var boss := w._radius_of(BOSS, 120)
	t.ok(is_finite(crow_max) and is_finite(horse_min) and is_finite(boss),
			"세 반지름 모두 실수다 — 보스의 span 0이 NaN을 만들지 않는다 (%.2f / %.2f / %.2f)"
					% [crow_max, horse_min, boss])
	t.ok(absf(crow_max - 18.0) < 0.001, "가장 센 까마귀도 18px다 (리터럴) (%.3f)" % crow_max)
	t.ok(absf(horse_min - 22.0) < 0.001, "가장 약한 말이 22px다 (%.3f)" % horse_min)
	t.ok(absf(boss - 48.0) < 0.001, "보스는 48px다 — 힘이 최소이자 최대라 램프가 0이다 (%.3f)" % boss)
	t.ok(crow_max < horse_min and horse_min < boss, "그래서 종의 순서는 뒤집히지 않는다")
	t.ok(absf(w._radius_of(-1, 100)) < 0.0001,
			"종이 없으면 반지름은 0이다 — -1은 GDScript에서 마지막 줄을 읽는 합법적인 인덱스다")


# -- 31: FOURTEEN parallel tables, each one measured against a literal -----------------------------------
## ⚠ **A table one row short is the silent failure of the whole species system.** The read is an
## out-of-range index on a `const` Array, which GDScript throws at RUNTIME inside `_step_critters` or, for
## `SPECIES_COLOR`, inside `_creature()` and `Hud._minimap_marks()` at draw time — never at parse time. So
## the run dies on the frame the new species first walks or is first painted, and every check in this round
## that does not happen to spawn that species stays green.
##
## Three things this does that a looser version would not:
##
## - **Each table is compared to the literal `ROWS`, never to another table's length.** Arrays compared only
##   to each other pass on a set where every one of them is short — the same trap `net_parts` names.
## - **The hand-written list is checked against a SCAN of the constant map**, so a twelfth `SPECIES_*` table
##   added to `rules.gd` and forgotten here goes red by name rather than disappearing.
## - **The scanner is inverted against synthetic tables that must fail IT**, because a scan that finds
##   nothing at all reports a perfectly clean set — the shape of a loop whose condition is false from the
##   start.
##
## `SPECIES_COLOR` had **no length assertion anywhere for two plans**, which is why it is in here and not
## only in the view's own net: the pixel side and the rule side are one table's worth of rows.
func _c31_every_species_table_is_eleven_rows(t) -> void:
	# -- the enum itself, member by member. `NONE` is a member and is not a species. --
	t.eq(Parts.Species.size(), ROWS + 1,
			"Species는 종 열하나 + NONE 하나다 — Species.size()를 종의 수로 읽으면 안 된다 (%d)"
					% Parts.Species.size())
	t.eq(int(Parts.Species.NONE), -1, "NONE은 -1이다 — GDScript에서 합법적인 인덱스라 마지막 줄을 읽는다")
	# ⚠ **Every index as a literal.** `BOSS` moving off 2 silently re-points fourteen tables at once, and a
	# renumbering that shifted them all together would keep every "the tables agree" check green.
	var index := {"CROW": 0, "HORSE": 1, "BOSS": 2, "SQUIRREL": 3, "ELEPHANT": 4, "CHEETAH": 5,
			"LION": 6, "MOUSE": 7, "RABBIT": 8, "DOG": 9, "BOAR": 10}
	t.eq(index.size(), ROWS, "설정: 이름을 붙여 세운 종이 열하나다 — 분모를 먼저 못 박는다")
	var members: Dictionary = Parts.Species
	for name: String in index:
		t.ok(members.has(name), "Species.%s가 실제로 있다" % name)
		t.eq(int(members.get(name, -99)), int(index[name]),
				"그리고 그 번호는 %d다 (리터럴) — 뒤로만 자란다" % int(index[name]))

	# -- the twelve tables in `rules.gd`, by name --
	var tables := ["SPECIES_RADIUS", "SPECIES_FORCE_MIN", "SPECIES_FORCE_MAX", "SPECIES_SPEED_MUL",
			"SPECIES_FLEES", "SPECIES_REACH_BONUS", "SPECIES_WANDER", "SPECIES_HUNTS", "SPECIES_HERD",
			"SPECIES_START", "SPECIES_SPAWN_WEIGHT", "SPECIES_UNLOCK_AT"]
	t.eq(tables.size(), 12, "설정: rules.gd의 종별 표는 열두 개다 — 손으로 세운 목록의 길이를 먼저 못 박는다")
	var consts: Dictionary = Rules.new().get_script().get_script_constant_map()
	t.ok(consts.has("SPECIES_RADIUS"), "설정: 상수 계기가 실제로 Rules를 읽었다 — 비면 아래가 저절로 통과한다")
	for name: String in tables:
		t.ok(consts.has(name), "Rules.%s가 실제로 있다" % name)
		var arr: Array = consts[name] if consts.has(name) else []
		t.eq(arr.size(), ROWS, "Rules.%s는 열한 줄이다 (리터럴 11)" % name)

	# The scan that closes the class: a table added to `rules.gd` and not added to `tables` above.
	var scanned := _species_tables(consts)
	t.eq(scanned.size(), tables.size(),
			"rules.gd가 선언한 SPECIES_ 배열의 수가 손으로 적은 목록과 같다 (%d) %s"
					% [scanned.size(), str(scanned)])
	t.eq(_short_species_rows(consts).size(), 0,
			"그리고 그중 열한 줄이 아닌 것은 하나도 없다 %s" % str(_short_species_rows(consts)))

	# -- the two tables that live outside `rules.gd` and are just as parallel --
	t.eq(Parts.SPECIES_NAME.size(), ROWS,
			"Parts.SPECIES_NAME도 열한 줄이다 — net_parts는 이 배열을 이름으로 건너뛰므로 여기 말고는 아무도 안 잰다")
	for s in ROWS:
		t.ok(String(Parts.SPECIES_NAME[s]) != "",
				"%d종의 이름은 빈 문자열이 아니다 — 빈 칸은 엔딩의 먹은 종 줄에 빈 항목으로 찍힌다" % s)
	t.eq(FieldView.SPECIES_COLOR.size(), ROWS,
			"FieldView.SPECIES_COLOR도 열한 줄이다 — 짧으면 그리는 순간 인덱스 밖이고, 두 그림 파일이 같이 죽는다")
	# ⚠ **`look.gd` grew a species-keyed table with §6's gestures**, and it is the same trap the two above
	# are: read at DRAW time, out of range at draw time, never at parse time. The `SPECIES_` scan below is
	# pointed at `Look`'s own constant map as well, so a second one added there tomorrow is not outside every
	# check the way `SPECIES_COLOR` was for two plans.
	t.eq(Look.SPECIES_LUNGE_MUL.size(), ROWS,
			"Look.SPECIES_LUNGE_MUL도 열한 줄이다 — 짧으면 종이 하나 늘어난 날 그리는 순간 인덱스 밖이다")
	var look_consts: Dictionary = Look.new().get_script().get_script_constant_map()
	t.ok(look_consts.has("SPECIES_LUNGE_MUL"), "설정: 상수 계기가 실제로 Look을 읽었다 — 비면 아래가 저절로 통과한다")
	var look_tables := _species_tables(look_consts)
	t.eq(look_tables.size(), 1,
			"look.gd가 선언한 SPECIES_ 배열은 하나다 (리터럴) %s" % str(look_tables))
	t.eq(_short_species_rows(look_consts).size(), 0,
			"그리고 그것도 열한 줄이다 %s" % str(_short_species_rows(look_consts)))

	# ⚠ **`parts.gd` and `field_view.gd` were named by hand and NOT scanned, which is the shape CLAUDE.md
	# closed for `net_draw_leaf`: naming a table fixes the day it is done and nothing after it.** A second
	# `SPECIES_` array added to either file tomorrow would have been outside every check in the round, in
	# exactly the way `SPECIES_COLOR` itself was for two plans. Both constant maps join the same scan.
	var parts_consts: Dictionary = Parts.new().get_script().get_script_constant_map()
	t.ok(parts_consts.has("SPECIES_NAME"), "설정: 상수 계기가 실제로 Parts를 읽었다 — 비면 아래가 저절로 통과한다")
	t.eq(_species_tables(parts_consts).size(), 1,
			"parts.gd가 선언한 SPECIES_ 배열은 하나다 (리터럴) %s" % str(_species_tables(parts_consts)))
	t.eq(_short_species_rows(parts_consts).size(), 0,
			"그리고 그것도 열한 줄이다 %s" % str(_short_species_rows(parts_consts)))
	# ⚠ **`FieldView` is a `Node`, so the instance has to be freed by hand** — a `RefCounted` like `Rules`
	# or `Parts` drops on its own and this one does not: left dangling it prints
	# "1 resources still in use at exit" on stderr and the wrapper's silence check reds the whole round.
	var view_probe := FieldView.new()
	var view_consts: Dictionary = view_probe.get_script().get_script_constant_map()
	view_probe.free()
	t.ok(view_consts.has("SPECIES_COLOR"), "설정: 상수 계기가 실제로 FieldView를 읽었다 — 비면 아래가 저절로 통과한다")
	t.eq(_species_tables(view_consts).size(), 1,
			"field_view.gd가 선언한 SPECIES_ 배열은 하나다 (리터럴) %s" % str(_species_tables(view_consts)))
	t.eq(_short_species_rows(view_consts).size(), 0,
			"그리고 그것도 열한 줄이다 %s" % str(_short_species_rows(view_consts)))

	# **Invert the instrument, not only the subject.** Both scanners are run against tables built to fail
	# them, or a scanner that returned an empty array would bless every short row above.
	var synthetic := {"SPECIES_ONE": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], "SPECIES_TWO": [1, 2],
			"NOT_A_SPECIES_TABLE": [1], "SPECIES_NOT_AN_ARRAY": 11}
	var found := _species_tables(synthetic)
	t.eq(found.size(), 2, "SPECIES_로 시작하는 배열만 스캔에 잡힌다 (계기 자가 점검) %s" % str(found))
	var shorts := _short_species_rows(synthetic)
	t.ok(shorts.size() == 1 and String(shorts[0]) == "SPECIES_TWO",
			"그리고 짧은 줄은 이름으로 나온다 — 스캐너가 빈 배열을 돌려주고 있지 않다 (계기 자가 점검) %s"
					% str(shorts))


## Every `SPECIES_`-prefixed array constant in a constant map, sorted so the report is stable.
func _species_tables(consts: Dictionary) -> Array:
	var out: Array = []
	for key: Variant in consts:
		if not String(key).begins_with("SPECIES_"):
			continue
		if typeof(consts[key]) != TYPE_ARRAY:
			continue
		out.append(String(key))
	out.sort()
	return out


func _short_species_rows(consts: Dictionary) -> Array:
	var out: Array = []
	for name: String in _species_tables(consts):
		if (consts[name] as Array).size() != ROWS:
			out.append(name)
	return out


# -- 32: every species, one at a time — it is born, it walks, and it can be killed -------------------------
## ⚠ **Driven over the table's own length, never over a list of names.** Four species were added and the
## whole risk is that one of them is a set of rows nothing ever executes: a `SPECIES_HERD` that spawns
## nobody, a `SPECIES_SPEED_MUL` that walks nowhere, an hp of 0 that dies to the first frame. Naming the
## four here would close them and leave the twelfth open the day it lands — this loop reddens for a row
## added to the tables and never exercised.
##
## Each fixture uses `SPECIES_FORCE_MIN`, so `_radius_of`'s ramp is exactly 0 and the radius is the species'
## own literal — the same trick `net_overlap._o5` uses, and it is what lets the radius be asserted at all.
##
## ⚠ **The host is parked in the far corner, outside `CRITTER_SENSE`.** With a body in sight a fleeing
## species runs, a hunter closes and the crow's stand-still branch never runs — three different walks, and
## the one thing under test here is what a species does with NOTHING in sight, which is `SPECIES_WANDER`.
func _c32_every_species_spawns_walks_and_dies(t) -> void:
	const FRAMES := 120
	var walkers := 0
	var standers := 0
	for s in ROWS:
		# -- born: a herd is `SPECIES_HERD` bodies through the production path --
		var wh := World.new()
		wh.setup(470 + s)
		_silence_food(wh)
		_clear_terrain(wh)
		wh.critter_count = 0
		wh.boss_index = -1
		var born := wh._spawn_herd(s)
		t.eq(born, int(Rules.SPECIES_HERD[s]),
				"%d종 한 무리는 SPECIES_HERD만큼 실제로 태어난다 (%d)" % [s, born])
		t.eq(wh.critter_count, born, "그리고 그 수가 표의 셈이다")
		var f := int(wh.critter_force[0])
		t.ok(f >= int(Rules.SPECIES_FORCE_MIN[s]) and f <= int(Rules.SPECIES_FORCE_MAX[s]),
				"%d종의 힘은 제 범위 안에서 굴려진다 (%d ∈ [%d, %d])"
						% [s, f, int(Rules.SPECIES_FORCE_MIN[s]), int(Rules.SPECIES_FORCE_MAX[s])])
		t.eq(int(wh.critter_hp[0]), f * Rules.HP_PER_FORCE, "%d종의 체력은 제 힘 × 3이다" % s)
		t.ok(int(wh.critter_hp[0]) > 0, "그리고 0보다 크다 — 0이면 첫 프레임에 시체다")
		t.eq(int(wh.critter_flees[0]), int(Rules.SPECIES_FLEES[s]), "%d종은 제 성향으로 태어난다" % s)

		# -- walks: its own speed, nothing in sight --
		var w := World.new()
		w.setup(480 + s)
		_silence_food(w)
		_clear_terrain(w)
		w.swarm.pos[0] = Vector2(3800.0, 2100.0)
		w.critter_count = 0
		w.boss_index = -1
		var at := Vector2(1500.0, 1100.0)
		w._write_critter(s, at, int(Rules.SPECIES_FORCE_MIN[s]))
		t.ok(absf(w.critter_radius(0) - float(Rules.SPECIES_RADIUS[s])) < 0.001,
				"%d종은 제 최소 힘에서 반지름이 제 종의 수 그대로다 (%.3f)" % [s, w.critter_radius(0)])
		t.ok(at.distance_to(w.swarm.pos[0]) > Rules.CRITTER_SENSE,
				"설정: 호스트는 감지 밖이다 — 이 검사는 「아무것도 안 보일 때」에 관한 것이다")
		# **Path length, not displacement.** A wanderer turns, so a straight-line measurement is a function
		# of how the turns happened to cancel; the path is `speed × time` exactly, whatever it turned.
		var path := 0.0
		var prev: Vector2 = w.critter_pos[0]
		for _n in FRAMES:
			w._step_critters(DT)
			path += w.critter_pos[0].distance_to(prev)
			prev = w.critter_pos[0]
		var want := float(Rules.SPECIES_SPEED_MUL[s]) * Rules.HOST_SPEED * (float(FRAMES) * DT)
		if int(Rules.SPECIES_WANDER[s]) == 1:
			walkers += 1
			t.ok(absf(path - want) < 0.5,
					"%d종은 2초 동안 제 걸음만큼 걷는다 (%.2fpx, 기대 %.2f) — 종의 속도가 실제로 읽힌다"
							% [s, path, want])
		else:
			standers += 1
			t.ok(path < 0.001,
					"%d종은 아무것도 안 보이면 한 발짝도 안 걷는다 (%.4f) — 걸어가서 치는 것이다" % [s, path])

		# -- dies: exactly its own hp, and it leaves a corpse of itself --
		var hp := int(w.critter_hp[0])
		t.ok(not w._damage_critter(0, hp - 1),
				"%d종은 제 체력에서 하나 모자란 한 방으로는 안 죽는다 — 아래가 공짜로 통과하지 않는다" % s)
		t.ok(w._damage_critter(0, 1), "그리고 마지막 하나에 죽는다")
		t.eq(w.critter_count, 0, "%d종의 줄이 실제로 빠졌다" % s)
		t.eq(w.corpse_count, 1, "그리고 시체가 하나 남았다 — 죽는 것 자체는 아무것도 안 준다")
		t.eq(int(w.corpse_species[0]), s, "그 시체는 제 종의 것이다")

	# The two counters, so a loop that silently took one branch for every row cannot pass. `SPECIES_WANDER`
	# is 0 for the crow alone, and that is the whole of "the common creature is a thing you walk up to".
	t.eq(standers, 1, "열한 종 중 제자리에 서는 것은 하나뿐이다 (%d)" % standers)
	t.eq(walkers, ROWS - 1, "나머지 열은 다 걷는다 — 한 갈래만 탄 반복문이 아니다 (%d)" % walkers)
	t.eq(int(Rules.SPECIES_WANDER[CROW]), 0, "그리고 그 하나는 까마귀다")


# -- 33: the opening pocket — four bodies PLACED, not rolled ---------------------------------------------
## ⚠ **The uniform layout can only make the opening likely, and the first ten seconds is not a place to
## gamble.** `SPECIES_START`'s own comment already claims the opening is "the same SHAPE every run"; four
## creatures at fixed distances from the host is what makes that true near the host, and nothing else in
## `setup()` can.
##
## **Driven, never grepped, and never counted through `setup()` alone.** `_c1` counts heads by species, and
## the pocket's contribution to those counts is four — so a `_place_pocket()` that placed the right species
## at wildly wrong distances, or all four on top of each other, is invisible there. This drives the function
## on cleared terrain so the placement is the only thing between the table and the answer.
func _c33_the_opening_pocket(t) -> void:
	var rows: Array = Rules.OPENING_POCKET
	t.eq(rows.size(), 4, "설정: 주머니는 네 줄이다 (리터럴) — 분모를 먼저 못 박는다")
	# The table's species, by NAME. Written as bare indices in `rules.gd` because a const cannot index
	# another script's const, so this is the only place the two are tied together.
	t.eq(int(rows[0][0]), int(Parts.Species.MOUSE), "첫 줄은 들쥐다 — 한 입에 죽고 3만 물어간다")
	t.eq(int(rows[1][0]), int(Parts.Species.MOUSE), "둘째도 들쥐다")
	t.eq(int(rows[2][0]), int(Parts.Species.CROW),
			"셋째는 까마귀다 — 주머니에서 카드 판을 여는 유일한 몸이다")
	t.eq(int(rows[3][0]), int(Parts.Species.SQUIRREL), "넷째는 다람쥐다 — 쫓아가서 잡는 것")
	t.ok(float(rows[2][1]) < float(rows[3][1]),
			"그리고 서 있는 까마귀가 도망치는 다람쥐보다 가깝다 — 순서를 뒤집으면 두 번째 막이 빈 풀밭 15초다")

	# -- driven, on cleared ground so `push_out` cannot move anything --
	var w := World.new()
	w.setup(468)
	_silence_food(w)
	_clear_terrain(w)
	var host: Vector2 = w.swarm.pos[0]
	w.critter_count = 0
	w.boss_index = -1
	w._place_pocket()
	t.eq(w.critter_count, rows.size(), "네 마리가 실제로 놓인다")
	var angles: Array = []
	for i in rows.size():
		var p: Vector2 = w.critter_pos[i]
		t.eq(int(w.critter_species[i]), int(rows[i][0]), "%d번째 몸은 표가 말한 종이다" % i)
		t.ok(absf(host.distance_to(p) - float(rows[i][1])) < 0.01,
				"그리고 표가 말한 거리에 선다 (%.1f, 기대 %.1f)" % [host.distance_to(p), float(rows[i][1])])
		angles.append((p - host).angle())
	# ⚠ **Spread apart, or four bodies at four distances stacked on one bearing is a single-file queue.**
	# `TAU / 4` between consecutive rows, as a literal.
	for i in rows.size() - 1:
		var gap: float = fposmod(float(angles[i + 1]) - float(angles[i]), TAU)
		t.ok(absf(gap - TAU * 0.25) < 0.001,
				"이웃한 둘은 정확히 90도 벌어져 있다 (%.4f rad)" % gap)

	# -- the same SHAPE every run, in a different arrangement --
	# Two seeds: the distances are identical and the bearings are not. Either half alone is satisfied by a
	# pocket that is entirely fixed, or by one that is entirely rolled.
	var w2 := World.new()
	w2.setup(469)
	_silence_food(w2)
	_clear_terrain(w2)
	w2.critter_count = 0
	w2.boss_index = -1
	w2._place_pocket()
	var same_dist := true
	for i in rows.size():
		same_dist = same_dist and absf(
				w2.swarm.pos[0].distance_to(w2.critter_pos[i]) - float(rows[i][1])) < 0.01
	t.ok(same_dist, "다른 씨앗에서도 거리는 그대로다 — 개막의 모양은 매 판 같다")
	t.ok(absf(float(angles[0]) - (w2.critter_pos[0] - w2.swarm.pos[0]).angle()) > 0.001,
			"그런데 방향은 다르다 — 매 판 같은 자리에 같은 것이 서 있지는 않다")

	t.ok(float(rows[0][1]) >= Rules.CRITTER_START_MIN_DIST,
			"그리고 가장 가까운 줄도 개막의 바닥 거리 밖이다 — 무릎 위에서 시작하지 않는다")
	await _c33b_the_opening_screen_is_not_empty(t, rows)


## **The pocket's actual purpose, driven off the camera the game actually has.**
##
## ⚠ **This block used to compare the table against a literal `700.0`, call it 「개막 카메라의 반대각선」 and
## label every row 「걸어갈 필요 없이 보인다」 — and both halves were false.** `project.godot` stretches a
## **1280x720 viewport** into a 1920x1080 window (`canvas_items`), so the window's size is not the world's:
## at `Look.ZOOM_NEAR` 1.6 the opening camera shows **800x450 world pixels** — half-extents 400x225,
## half-diagonal **459** — and 700 is exactly what that arithmetic gives when the window override is
## mistaken for the viewport. Measured against the real rect over sixty seeds, 까마귀 (520px) and 다람쥐
## (640px) were inside it in **zero** of them while that line passed all four rows. `tools/look/probe_run.gd`
## records the same 1.5x mistake living in `probe_field.gd`.
##
## ⇒ **A bound on a column cannot say this and a driven rect can.** The claim is the pocket's own reason to
## exist — 「개막이 도박이 아니다」 — so it is measured as 「every seed opens with something already on
## screen」 over many seeds, through `main.gd`'s own `_true_camera_rect()`. Pushing any row out of the
## camera moves the count; a literal could not see it.
##
## ⚠ **The rows are read off a freshly re-placed pocket, never off `critter_count - 5`.** `setup()` puts the
## boss down after the pocket, so an index counted back from the end is one row of arithmetic away from
## measuring the boss instead — which is what the throwaway that found this bug did on its first run.
func _c33b_the_opening_screen_is_not_empty(t, rows: Array) -> void:
	var m: Node = load("res://src/shell/main.gd").new()
	t.root.add_child(m)
	# ⚠ **Two frames, because `_ready()` does not run inside `add_child` under this runner** — every fixture
	# in `net_shell` pumps the same two before touching `title`, and without them `m.title` is null.
	await t.pump_frames(2)
	# And the shell's own clock is switched off from here: nothing below wants a frame, and a shell left
	# running would step the run between the restart and the read.
	m.set_process(false)
	m.set_process_unhandled_key_input(false)
	# The real path in: `_bind_world()` snaps `_cam_base` to the host and `_zoom` to `ZOOM_NEAR`, so the
	# opening camera is centred on the host and no field is poked by hand.
	m.title.start_pressed.emit()
	var box: Rect2 = m._true_camera_rect()
	t.ok(absf(box.size.x - 800.0) < 2.0 and absf(box.size.y - 450.0) < 2.0,
			"개막 카메라는 800x450 월드픽셀이다 (리터럴) — 1920x1080은 창이지 뷰포트가 아니다 %s"
					% str(box.size))
	t.ok(box.size.length() * 0.5 < 500.0,
			"그래서 반대각선은 459px 남짓이고, 이 검사가 예전에 들고 있던 700px이 아니다 (%.0f)"
					% (box.size.length() * 0.5))
	t.ok(box.get_center().distance_to(m.run.world.swarm.pos[0]) < 1.0,
			"설정: 그 사각형은 호스트를 한가운데 두고 있다 — 아니면 아래 셈은 엉뚱한 땅을 잰다")

	# ⚠ **Two lines that exist because this check was inverted against ITSELF and failed twice.**
	# `seeds := 0` made every `t.eq(count, seeds)` below read `0 == 0` and the whole block passed with the
	# loop never entered — CLAUDE.md's "a loop whose condition is false from the start never runs the check".
	# And swapping the loop's `_true_camera_rect()` for the padded `_camera_rect()` also stayed green,
	# because a rectangle 20% too big only makes "something is on screen" easier: the pinned rect above
	# proves nothing about the rect the loop actually used, so the loop's own is counted and compared.
	var seeds := 24
	t.ok(seeds >= 20, "설정: 판 수는 스무 판 이상이다 (%d) — 0판이면 아래 세 줄이 저절로 통과한다" % seeds)
	var field_not_empty := 0
	var pocket_not_empty := 0
	var same_rect := 0
	var per_row := [0, 0, 0, 0]
	for n in seeds:
		m.run.restart(3100 + n)
		m._bind_world()
		var w3: World = m.run.world
		var b: Rect2 = m._true_camera_rect()
		if b.size.is_equal_approx(box.size) and b.get_center().distance_to(w3.swarm.pos[0]) < 1.0:
			same_rect += 1
		for k in w3.critter_count:
			if b.has_point(w3.critter_pos[k]):
				field_not_empty += 1
				break
		# The pocket alone, re-placed onto row 0 so the indices are the table's own.
		w3.critter_count = 0
		w3.boss_index = -1
		w3._place_pocket()
		var seen := 0
		for i in w3.critter_count:
			if b.has_point(w3.critter_pos[i]):
				seen += 1
				per_row[i] = int(per_row[i]) + 1
		if seen > 0:
			pocket_not_empty += 1
	t.eq(same_rect, seeds,
			"매 판 쓴 사각형은 위에서 못 박은 그 800x450이고, 매 판 호스트를 가운데 둔다 (%d/%d)"
					% [same_rect, seeds])
	t.eq(field_not_empty, seeds,
			"%d판을 돌려도 개막 화면이 빈 판은 없다 — 사용자의 「그냥 몬스터가 내 주변에 없어」가 이 줄이다"
					% seeds)
	t.eq(pocket_not_empty, seeds,
			"그리고 그중 한 마리는 언제나 주머니의 것이다 — 균일 배치에 맡기지 않는 이유가 그것이다")
	# ⚠ **Deliberately a floor and not an equality.** 520px and 640px are outside the camera at every
	# bearing today, and pinning that as `== 0` would go red the day someone pulls them in, which is a
	# repair and not a regression. What must never happen is the two near rows going the same way.
	t.ok(int(per_row[0]) + int(per_row[1]) >= seeds,
			"가까운 두 줄이 화면에 든 횟수를 합치면 판 수 이상이다 — 걸어가야 보이는 개막이 아니다 (%d/%d) %s"
					% [int(per_row[0]) + int(per_row[1]), seeds, str(per_row)])
	# ⚠ **The last two rows get a shape check and NOT a place on the screen.** 520px and 640px are outside
	# the camera at every bearing today; pinning that as a fact would go red the day someone pulls them in,
	# which is a repair and not a regression. What the pocket owes is a SEQUENCE — near enough to see, then
	# a short walk — so that is what is measured, in the direction neither a repair nor a regression can fake.
	var rising := true
	for i in rows.size() - 1:
		rising = rising and float(rows[i + 1][1]) > float(rows[i][1])
	t.ok(rising, "네 줄의 거리는 계속 멀어진다 — 보이는 것부터 걸어가는 것까지가 한 줄기다 %s" % str(rows))
	t.ok(float(rows[rows.size() - 1][1]) / Rules.HOST_SPEED <= 4.0,
			"그리고 가장 먼 줄도 %.1f초 걸음이다 — 개막의 다음 막이지 원정이 아니다"
					% (float(rows[rows.size() - 1][1]) / Rules.HOST_SPEED))

	t.root.remove_child(m)
	m.queue_free()


# -- F1b: the crow does not one-shot the host ------------------------------------------------------------
## ⚠ **Nothing asserted the entire justification for the ×10.** "It does not one-shot the host" was a
## sentence in a design doc, and `HOST_HP` at 12 satisfies every other check in the round.
func _f1b_a_crow_does_not_one_shot(t) -> void:
	t.eq(Rules.HOST_HP, 30, "호스트의 체력은 30이다 (리터럴)")
	t.eq(int(Rules.SPECIES_FORCE_MAX[CROW]), 12, "가장 센 까마귀의 힘은 12다 (리터럴)")
	t.ok(Rules.HOST_HP >= int(Rules.SPECIES_FORCE_MAX[CROW]) * 2,
			"가장 센 까마귀라도 한 대로는 못 죽인다 — 체력은 그 두 배 이상이다")


# -- F2: boss placement, and the OTHER half of the index repair ------------------------------------------
## ⚠ **`Rules.BOSS_PLACE_TRIES` alone is NOT what this measures, and that was measured.** Dropping it to 1
## leaves this check green, because the sampler falls back to a deterministic inset corner — the backstop
## is what makes the distance provable rather than green seven times in ten. The two cover for each other
## here by design; **`_u12_where_the_boss_opens` below is what separates them.**
##
## ⚠ **The floor is a hand-written 1800.0 and it was `Rules.BOSS_SPAWN_MIN_DIST` on both sides.** Read off
## the constant under test, the check shrinks with it: at 900 the boss can open inside `MINIMAP_SHOW_DIST`
## and "it is out there, visible on the map, and it is a walk" is silently deleted with this green.
func _f2_boss_placement(t) -> void:
	var worst := INF
	for n in 10:
		var w := World.new()
		w.setup(417 + n)
		if w.boss_index < 0:
			worst = -1.0
			break
		worst = minf(worst, w.critter_pos[w.boss_index].distance_to(w.swarm.pos[0]))
	t.ok(worst >= 1800.0,
			"열 판을 돌려도 보스는 1800px 밖에 놓인다 — 미니맵에 보이고 걸어갈 거리다 (%.0f)" % worst)

	# The `last == boss_index` half: the boss is the last row, so removing anyone else swaps it down.
	var w2 := World.new()
	w2.setup(427)
	var b := w2.boss_index
	t.eq(b, w2.critter_count - 1, "설정: 보스는 마지막 줄에 놓인다")
	w2._remove_critter(5)
	t.eq(w2.boss_index, 5, "보스가 아닌 줄이 죽으면 boss_index가 새 자리를 따라간다")
	t.eq(int(w2.critter_species[w2.boss_index]), BOSS, "그리고 그 자리에 실제로 보스가 있다")
	# And it still walks: a stale index is a boss that stops moving with nothing on screen to say so.
	_silence_food(w2)
	_clear_terrain(w2)
	w2.elapsed = Rules.BOSS_HUNT_AT
	var gap: float = w2.critter_pos[w2.boss_index].distance_to(w2.swarm.pos[0])
	w2._step_critters(DT)
	t.ok(w2.critter_pos[w2.boss_index].distance_to(w2.swarm.pos[0]) < gap - 2.0,
			"고쳐진 인덱스의 보스는 여전히 걸어온다")


# -- U12: the sampler and the backstop, one at a time ----------------------------------------------------
## **They covered for each other and neither was measured alone.** Three verifiers found this independently
## and every one of these was green: `BOSS_PLACE_TRIES` 200 → 0 (the sampler dead, the backstop still
## satisfying F2's floor), the guard → `if false:` (the backstop dead), the backstop rewritten to
## `best = host` — **the boss opens on top of the player** — and its four corner comparisons inverted.
##
## `_boss_spot` takes its try count as an argument for exactly this: at 200 the backstop is a 1-in-10¹¹
## branch and cannot be driven, at 0 it is the only branch there is.
func _u12_where_the_boss_opens(t) -> void:
	var w := World.new()
	w.setup(430)
	_clear_terrain(w)
	var mid := Rules.FIELD * 0.5

	# (a) The backstop, four quadrants, literal corners. `inset` is 200 and the field is 3840×2160.
	t.eq(w._boss_backstop(Vector2(100.0, 100.0)), Vector2(3640.0, 1960.0),
			"호스트가 왼쪽 위에 있으면 보스는 오른쪽 아래 구석이다")
	t.eq(w._boss_backstop(Vector2(3700.0, 100.0)), Vector2(200.0, 1960.0),
			"오른쪽 위면 왼쪽 아래다")
	t.eq(w._boss_backstop(Vector2(100.0, 2000.0)), Vector2(3640.0, 200.0),
			"왼쪽 아래면 오른쪽 위다")
	t.eq(w._boss_backstop(Vector2(3700.0, 2000.0)), Vector2(200.0, 200.0),
			"오른쪽 아래면 왼쪽 위다 — 네 비교가 뒤집혀도 초록이었다")
	# The middle is the case `setup()` actually opens in, and it must not be the host's own square.
	t.ok(w._boss_backstop(mid).distance_to(mid) >= 1800.0,
			"필드 한가운데서도 그 구석은 1800px 밖이다 (%.0f)"
					% w._boss_backstop(mid).distance_to(mid))

	# (b) With no samples allowed the backstop is the whole answer, and it is NOT the host.
	var none := w._boss_spot(mid, 0)
	t.eq(none, w._boss_backstop(mid), "뽑기를 0번 하면 남는 것은 그 구석뿐이다")
	t.ok(none != mid, "그리고 그것은 호스트 자리가 아니다 — 보스가 플레이어 위에 태어나지 않는다")

	# (c) With the real count the SAMPLER answers, and its answer moves with the seed. A backstop-only
	# placer puts every run's boss on one of four fixed corners; ten seeds and four corners cannot fill
	# ten distinct points.
	var seen := {}
	var corners := 0
	for n in 10:
		var wn := World.new()
		wn.setup(500 + n)
		var p: Vector2 = wn.critter_pos[wn.boss_index]
		seen[str(p.round())] = true
		if p.distance_to(wn._boss_backstop(wn.swarm.pos[0])) < 1.0:
			corners += 1
	t.ok(seen.size() >= 8,
			"열 씨앗이 보스를 여덟 자리 이상에 놓는다 — 뽑기가 죽으면 네 구석뿐이다 (%d)" % seen.size())
	t.eq(corners, 0, "그 열 판 중 구석으로 떨어진 판은 하나도 없다 — 200번 뽑기는 실제로 통한다")


# -- F2b: the boss's own death ---------------------------------------------------------------------------
## ⚠ **F2 never reaches this half.** `k == boss_index` fires only when the boss itself dies, and that is the
## one place the run's ending walks through — `_step_arena()` then reads `critter_pos` of whatever swapped
## in, or a row past `critter_count`, with no error because the arrays are sized to the cap.
func _f2b_the_boss_dies(t) -> void:
	var w := World.new()
	w.setup(428)
	_silence_food(w)
	var b := w.boss_index
	t.ok(b >= 0, "설정: 보스가 있다")
	var was_closed: bool = w.terrain.arena_closed
	t.ok(not was_closed, "설정: 아레나는 아직 열려 있다")
	t.ok(w._damage_critter(b, 400), "설정: 보스를 실제로 죽였다 (체력 360)")
	t.eq(w.boss_index, -1, "보스가 죽으면 boss_index는 -1이 된다")
	# ⚠ **Past `BOSS_HUNT_AT`, or the frame below is quiet for the wrong reason.** `_step_arena` returns
	# before it reads `boss_index` at all while the hunt has not started, so at `elapsed = 0` this passes
	# with the `boss_index < 0` guard deleted.
	w.elapsed = Rules.BOSS_HUNT_AT
	w.step(DT)
	t.eq(w.terrain.arena_closed, false, "죽은 보스는 아레나를 닫지 못한다 — 다음 프레임도 조용히 지나간다")


# -- F3: nothing spawns inside a rock --------------------------------------------------------------------
## ⚠ **The precondition is not decoration.** `push_out` is the identity on an empty rock array and
## `Terrain.setup()`'s rejection can legitimately skip every rock, so without the floor this check passes
## perfectly on a field with no ground at all.
##
## ⚠ **It takes BOTH of `_spawn_at`'s rock tests to redden this, and that was measured, not assumed.**
## Deleting the trailing `push_out` alone leaves the round GREEN — the in-loop rejection almost always
## accepts a clear point, so the fall-through never fires. Deleting the in-loop test alone is green too:
## the trailing push cleans up after it. The two are redundant with each other on purpose and this check is
## what says the protection exists at all; its named mutation is **the pair**.
func _f3_nothing_spawns_in_a_rock(t) -> void:
	var rocks := INF
	var inside := 0
	var checked := 0
	for n in 10:
		var w := World.new()
		w.setup(429 + n)
		rocks = minf(rocks, float(w.terrain.rock_pos.size()))
		for k in w.critter_count:
			checked += 1
			var r := w.critter_radius(k)
			if w.terrain.push_out(w.critter_pos[k], r) != w.critter_pos[k]:
				inside += 1
	t.ok(rocks >= 30.0, "설정: 바위가 서른 개 이상 놓였다 (%.0f) — 빈 땅에서는 이 검사가 공짜로 통과한다" % rocks)
	t.eq(checked, 580, "설정: 열 판 × 쉰여덟 마리를 다 봤다 — 주머니의 넷까지 포함이다")
	t.eq(inside, 0, "바위 안에서 태어나는 생물은 하나도 없다")


# -- F4: `SPECIES_SPAWN_WEIGHT`, as a ratio --------------------------------------------------------------
## Round 3 named the constant this replaced in its "nothing checks it" list. Check 1 counts the opening
## field, which comes from `SPECIES_START` and never touches the roll at all.
##
## ⚠ **`_roll_species()` is driven, not the creature rows counted afterwards.** Counting bodies measures the
## roll multiplied by `SPECIES_HERD` — a horse is rolled half as often as a squirrel and arrives four at a
## time — so a body count is a check on two tables at once and pins neither. It was written that way for the
## two-species build, where every herd was 1 and the distinction did not exist.
## ⚠ **"every non-zero weight appears" is FALSE at `elapsed` 0 once `SPECIES_UNLOCK_AT` exists**, and a
## check that kept saying it would have to be satisfied by deleting the gate. So the roll is driven at two
## clock values and the claim splits in two: a locked species is **impossible before its gate and possible
## after it**, which is the behaviour, and neither half alone is it.
##
## ⚠ **And the DIVISOR is the whole of the gate.** Skipping a locked row while still dividing by the full
## 138 breaks nothing visibly — every unlocked species just comes up less often than its weight says, and
## the leftover picks fall out of the loop's bottom into the fallback. That is why the rates below are
## measured against **108** at t = 0 and against **138** at t = 130, as two literals: written as
## `Σ weight` either way, both sums move with whatever the code happens to do.
func _f4_spawn_species_roll(t) -> void:
	var rolls := 2000
	var total_weight := 0
	for weight in Rules.SPECIES_SPAWN_WEIGHT:
		total_weight += int(weight)
	t.eq(total_weight, 138, "설정: 가중치의 합은 138이다 (리터럴) — 분모를 먼저 못 박는다")

	# -- t = 0: 코끼리 · 사자 · 들개 · 멧돼지 are locked, so the divisor is 108 --
	var w := World.new()
	w.setup(439)
	t.eq(w.elapsed, 0.0, "설정: 갓 만든 월드의 시계는 0이다")
	var locked := [int(Parts.Species.ELEPHANT), int(Parts.Species.LION), int(Parts.Species.DOG),
			int(Parts.Species.BOAR)]
	var open_sum := 0
	for s in Rules.SPECIES_SPAWN_WEIGHT.size():
		if not locked.has(s):
			open_sum += int(Rules.SPECIES_SPAWN_WEIGHT[s])
	t.eq(open_sum, 108, "설정: 그중 0초에 풀려 있는 몫은 108이다 (리터럴)")
	var per := {}
	for _i in rolls:
		var s := w._roll_species()
		per[s] = int(per.get(s, 0)) + 1
	for s in Rules.SPECIES_SPAWN_WEIGHT.size():
		var weight := int(Rules.SPECIES_SPAWN_WEIGHT[s])
		var got := int(per.get(s, 0))
		if weight == 0:
			t.eq(got, 0, "가중치 0인 %d종은 한 번도 굴려지지 않는다" % s)
			continue
		if locked.has(s):
			t.eq(got, 0,
					"%d종은 %.0f초 전에는 2000번을 굴려도 한 번도 안 나온다 — 잠긴 종은 대체값으로도 새지 않는다"
							% [s, float(Rules.SPECIES_UNLOCK_AT[s])])
			continue
		# **108, not `total_weight`.** Against 138 this line would be satisfied by a roll that divides by the
		# full sum and lets the excess fall into the fallback — the exact defect the divisor exists to stop.
		var want := float(weight) / 108.0
		var rate := float(got) / float(rolls)
		t.ok(absf(rate - want) < 0.04,
				"%d종은 풀린 몫에 대한 가중치대로 나온다 (%.3f, 기대 %.3f)" % [s, rate, want])
	t.ok(int(per.get(CROW, 0)) > int(per.get(HORSE, 0)),
			"까마귀는 말보다 흔하다 — 말은 사건이고 까마귀는 일상이다")

	# -- t = 130: every gate is open, so the divisor is the whole 138 --
	var w2 := World.new()
	w2.setup(440)
	w2.elapsed = 130.0
	var per2 := {}
	for _i in rolls:
		var s := w2._roll_species()
		per2[s] = int(per2.get(s, 0)) + 1
	for s in Rules.SPECIES_SPAWN_WEIGHT.size():
		var weight := int(Rules.SPECIES_SPAWN_WEIGHT[s])
		var got := int(per2.get(s, 0))
		if weight == 0:
			t.eq(got, 0, "가중치 0인 %d종은 시계를 돌려도 안 나온다 — 보스는 언제까지나 하나다" % s)
			continue
		var want := float(weight) / 138.0
		var rate := float(got) / float(rolls)
		t.ok(absf(rate - want) < 0.04,
				"130초에는 %d종이 138분의 제 가중치로 나온다 (%.3f, 기대 %.3f)" % [s, rate, want])

	# -- the gate itself, one species at a time, on both sides of its own second --
	# ⚠ **Just under and just over**, or a check that only ever asks at 0 and at 130 is satisfied by a gate
	# hardcoded to any threshold between them.
	for s: int in locked:
		var gate := float(Rules.SPECIES_UNLOCK_AT[s])
		var w3 := World.new()
		w3.setup(441)
		w3.elapsed = gate - 0.1
		var before := 0
		for _i in 600:
			if w3._roll_species() == s:
				before += 1
		t.eq(before, 0, "%d종은 %.0f초의 0.1초 전까지 나오지 않고" % [s, gate])
		w3.elapsed = gate
		var after := 0
		for _i in 600:
			if w3._roll_species() == s:
				after += 1
		t.ok(after > 0, "제 초가 되는 바로 그 순간부터 나온다 (%d번) — 경계는 이상이다" % after)


# -- F5: one frame is one step, per creature -------------------------------------------------------------
## ⚠ **The loop BOUND, not the swap.** `_c3` covers what a removal carries down; this covers who the walk
## visits afterwards. A range materialises its index list once, and a clone's cone kills **every** creature
## it covers — including rows below the one being stepped. `_remove_critter` then copies the last row down
## over the dead one, and a BACKWARDS walk has already stepped that row: it is reached a second time and
## takes two steps in one frame. The tail of the frozen list also indexes rows past the new
## `critter_count`, which are stale, never cleared, and still contact and damage.
##
## ⚠ **The horse is found by SPECIES, not by index.** After the crow dies the horse IS row 0, so an
## index-keyed assertion would have to know where the swap left it — and that is the thing under test.
##
## ⚠ **The two `설정` lines pass either way on purpose.** The kill and the swap are identical under both
## walks; only the distance separates them, and 3.8333 is `230px/s × 1/60` written by hand.
##
## ⚠ **Since §A-3, this frame carries a SECOND event.** The horse stands in the same cone as the crow, so
## the one swing that kills the crow also knocks the horse back — `40 × KNOCKBACK_PER_FORCE` — before the
## swap ever runs. The walk this check is actually about is the piece ON TOP of that: one step, not two.
func _f5_each_creature_walks_once_per_frame(t) -> void:
	var w := World.new()
	w.setup(450)
	_silence_food(w)
	_clear_terrain(w)
	var at := Vector2(1500.0, 1000.0)
	var c := w.swarm.add_clone(0, 40)
	w.swarm.pos[c] = at
	w.swarm.worn[c] = Parts.CROW_WING
	w.swarm.atk_cd[c] = 0.0
	w.critter_count = 0
	w.boss_index = -1
	# The crow is the BYSTANDER and it is written first, so the row the cone kills sits below the horse's.
	w._write_critter(CROW, at + Vector2(40.0, 0.0), 10)
	w._write_critter(HORSE, at + Vector2(25.0, 0.0), 30)
	var start: Vector2 = w.critter_pos[1]
	t.eq(w.critter_count, 2, "설정: 까마귀 한 마리와 말 한 마리가 분신의 원뿔 안에 섰다")
	w._step_critters(DT)
	t.eq(w.critter_count, 1, "설정: 날개 한 번이 까마귀만 죽였다 (말은 체력 90)")
	t.eq(int(w.critter_species[0]), HORSE, "설정: 빈 줄로 마지막 줄의 말이 내려왔다")
	# `40 × KNOCKBACK_PER_FORCE`, the swing's own knockback on the horse, PLUS one walk step (3.8333). Two
	# steps would read 39.6667 instead — the knockback is fixed, so only the walk half can double.
	var knockback: float = 40.0 * Rules.KNOCKBACK_PER_FORCE
	var walked: float = w.critter_pos[0].distance_to(start)
	t.ok(absf(walked - (knockback + 3.8333)) < 0.05,
			"곁의 까마귀가 죽어도 말은 밀리고, 걸음은 한 프레임에 한 번뿐이다 (%.4f, 기대 %.4f — 두 걸음이면 %.4f)"
					% [walked, knockback + 3.8333, knockback + 2.0 * 3.8333])

	# ⚠ **The bound is RE-READ, and that half was free while the direction was pinned.** The fix's own
	# comment claims two things — forwards, over a bound re-read every iteration — and only the first is
	# measured above. Freeze the bound at entry and the walk direction stays correct, so the check above
	# still passes: `_remove_critter(0)` swaps the horse down and shrinks the count, and the loop then runs
	# one more iteration at the old bound over row 1, which the swap left holding the horse's own stale
	# copy. That ghost flees the clone and walks 3.83px out of a row nobody is supposed to be in.
	# **`start` is the horse's position on entry. Row 1 keeps the swing's KNOCKBACK — that lands inside the
	# same `strike()` call the swap runs from, before the row is vacated — but not the walk that follows.**
	var ghost_expected: Vector2 = start + Vector2(knockback, 0.0)
	t.eq(w.critter_pos[1], ghost_expected,
			"줄어든 셈은 그 자리에서 읽힌다 — 밀림은 남아도 걸음은 아니다 (기대 %s)" % str(ghost_expected))

	_f5b_the_row_past_the_end_does_not_act(t)


# -- F5b: the walk's UPPER edge, which nothing touched --------------------------------------------------
## ⚠ **F5 above measures the direction of the walk and its lower end; `while k < critter_count` has another
## end and it was free.** Every critter table is `resize(Rules.CRITTER_MAX)` at setup and **never cleared**,
## so index `critter_count` is not empty — it holds whatever creature died there last, complete with
## species, force, hp, position, direction and disposition. One character (`<` → `<=`) makes that row a
## live creature again: it walks, it senses, it contacts, it damages a clone or the host, and it can itself
## be "killed", at which point `_remove_critter(count)` copies the row at `last` — **a real, living
## creature** — into the ghost slot and decrements the count, deleting that creature from the field.
## At the cap (`critter_count == CRITTER_MAX` 24) it is a straight out-of-range read on a 24-element array.
##
## Nothing in the round could see it, because no fixture ever looks at a row it did not write. This one
## writes the ghost **on purpose** and then asserts it is inert — three ways, so a mutation cannot be half
## caught: the per-frame clocks the loop decrements before anything else, the walk, and the retaliation.
func _f5b_the_row_past_the_end_does_not_act(t) -> void:
	var w := World.new()
	w.setup(451)
	_silence_food(w)
	_clear_terrain(w)
	var host := Vector2(1500.0, 1000.0)
	w.swarm.pos[0] = host
	w.critter_count = 0
	w.boss_index = -1
	# Row 0, the only creature the world knows about: far away, standing, harmless.
	w._write_critter(CROW, host + Vector2(2000.0, 0.0), 10)
	# Row 1, the GHOST — written through the same door and then hidden by winding the count back. It is
	# armed to do every single thing a stepped creature does: its counter is up so it CHASES rather than
	# standing, it is 300px away (inside `CRITTER_SENSE` 520) so it has a target, and it is close enough
	# that one step plus its own reach would put it on the host.
	w._write_critter(CROW, host + Vector2(300.0, 0.0), 10)
	w.critter_counter[1] = 5.0
	w.critter_atk_cd[1] = 0.0
	var ghost_at: Vector2 = w.critter_pos[1]
	w.critter_count = 1
	t.eq(w.critter_count, 1, "설정: 세상은 생물이 하나라고 알고 있다")
	t.eq(int(w.critter_species[1]), CROW, "설정: 그런데 1번 줄에는 죽은 까마귀의 값이 그대로 남아 있다")

	w._step_critters(DT)

	# The clocks are the first thing the loop touches, before any geometry — so this bites even on a ghost
	# that would not have moved anyway. `_write_critter` leaves `critter_counter` at 0 for a fresh creature,
	# which is why it is wound up by hand here: 5.0 is a value only this row holds.
	t.eq(w.critter_counter[1], 5.0,
			"끝 너머의 줄은 제 시계조차 돌지 않는다 — 걸어 보기 전에 이미 안 밟히는 줄이다")
	t.eq(w.critter_pos[1], ghost_at,
			"그리고 걷지 않는다 — 표는 CRITTER_MAX만큼 잡혀 있고 지워지지 않으니 그 줄은 비어 있지 않다")
	t.eq(w.host_hp, 30, "설정 겸 확인: 300px 밖의 까마귀는 어차피 호스트를 못 때린다")

	# **The damage half, and it needs its own fixture**: the check above passes on a ghost that acts and
	# simply cannot reach. Here the ghost stands ON the host, so a single stepped frame costs 10 hp.
	var w2 := World.new()
	w2.setup(452)
	_silence_food(w2)
	_clear_terrain(w2)
	w2.swarm.pos[0] = host
	w2.critter_count = 0
	w2.boss_index = -1
	w2._write_critter(CROW, host + Vector2(2000.0, 0.0), 10)
	w2._write_critter(CROW, host, 10)
	w2.critter_atk_cd[1] = 0.0
	w2.critter_count = 1
	t.eq(w2.host_hp, 30, "설정: 호스트는 체력 30으로 서 있다")
	w2._step_critters(DT)
	t.eq(w2.host_hp, 30,
			"호스트 위에 겹쳐 선 유령 줄도 반격하지 않는다 — 없는 생물에게 맞을 수는 없다")
	t.eq(w2.critter_atk_cd[1], 0.0, "그 줄의 공격 쿨다운도 그대로다 — 때린 적이 없으니 물 것도 없다")

	# The control, and without it every assertion above passes on a `_step_critters` that does nothing at
	# all: the same creature, one row lower, IS stepped and DOES take the host's health.
	var w3 := World.new()
	w3.setup(453)
	_silence_food(w3)
	_clear_terrain(w3)
	w3.swarm.pos[0] = host
	w3.critter_count = 0
	w3.boss_index = -1
	w3._write_critter(CROW, host, 10)
	w3.critter_atk_cd[0] = 0.0
	w3._step_critters(DT)
	t.eq(w3.host_hp, 20, "대조: 셈에 들어 있는 같은 까마귀는 제 힘 10만큼 그대로 깎는다")


# -- G1: wandering, and the crow that does not -----------------------------------------------------------
## `SPECIES_WANDER` is the third disposition column and it decides what a creature does with **nothing in
## sight**. Both directions are measured in one fixture because either alone is satisfied by the wrong code:
## a creature that always walks passes the elephant half, and one that never walks passes the crow half.
##
## ⚠ **The host is moved off the field's far corner rather than deleted**, so `target` is genuinely -1 by
## distance (`CRITTER_SENSE`) and not by an empty swarm — an empty swarm is a state play never reaches.
func _g1_wandering_is_a_column(t) -> void:
	var w := World.new()
	w.setup(416)
	_silence_food(w)
	_clear_terrain(w)
	w.swarm.pos[0] = Vector2(3800.0, 2100.0)
	w.critter_count = 0
	w.boss_index = -1
	var start := Vector2(500.0, 500.0)
	w._write_critter(int(Parts.Species.ELEPHANT), start, 80)
	w._write_critter(CROW, start + Vector2(0.0, 400.0), 10)
	var e_at: Vector2 = w.critter_pos[0]
	var c_at: Vector2 = w.critter_pos[1]
	t.ok(e_at.distance_to(w.swarm.pos[0]) > Rules.CRITTER_SENSE,
			"설정: 둘 다 호스트를 감지할 수 없는 거리다 — 이 검사는 「아무것도 안 보일 때」에 관한 것이다")
	for _s in 600:
		w._step_critters(DT)
	var e_moved: float = w.critter_pos[0].distance_to(e_at)
	var c_moved: float = w.critter_pos[1].distance_to(c_at)
	t.ok(e_moved > 100.0,
			"코끼리는 아무것도 안 보여도 10초 동안 100px 넘게 걷는다 — 배회는 표의 한 칸이다 (%.0f)" % e_moved)
	t.ok(c_moved < 0.001,
			"대조: 같은 10초 동안 까마귀는 한 발짝도 안 움직인다 — 걸어가서 치는 것이지 오는 것이 아니다 (%.4f)"
					% c_moved)
	t.eq(int(Rules.SPECIES_WANDER[CROW]), 0, "그 차이는 SPECIES_WANDER의 까마귀 칸이 0이라는 것뿐이다")
	t.eq(int(Rules.SPECIES_WANDER[Parts.Species.ELEPHANT]), 1, "그리고 코끼리 칸이 1이라는 것")

	# ⚠ **Wandering is not vibrating.** `dir` is left alone on the frames that do not turn; re-rolling it
	# every frame produces a creature that moves nowhere while every "it walked" assertion above still
	# passes, because the walk is measured over 600 frames and a vibration's net displacement is ~0.
	# **This is the check that separates the two**, and it is why the one above is not enough.
	var turns := 0
	var prev: Vector2 = w.critter_dir[0]
	for _s in 600:
		w._step_critters(DT)
		if w.critter_dir[0] != prev:
			turns += 1
			prev = w.critter_dir[0]
	t.ok(turns >= 2 and turns <= 40,
			"10초에 방향은 두 번에서 마흔 번 사이로 바뀐다 — 0은 직진이고 600은 제자리 진동이다 (%d)" % turns)


# -- G2: who hunts, and every one of them is slower than you ---------------------------------------------
## ⚠ **This check used to say `hunters == 1` and it is now THREE, which is a reversal and not a retune.**
## `_step_critters()`' own comment records the refusal it reverses — 여섯 개가 타이머로 걸어오는 것은
## 사용자가 거절한 것 — and what reopened it is the user's read after playing: 내가 때릴 수 있는 애가 없고
## ... 그냥 몬스터가 내 주변에 없어. Bumping the number alone would have hidden a design decision inside a
## test edit, so **each hunter is named** and the property that makes three survivable is asserted on every
## one of them: `SPECIES_SPEED_MUL < 1.0`, so walking away is always an answer.
##
## A hunter above `HOST_SPEED` would be an unavoidable chase, which is the boss's job — and the boss has an
## arena to make it fair.
func _g2_the_lion_is_the_only_hunter(t) -> void:
	var w := World.new()
	w.setup(417)
	_silence_food(w)
	_clear_terrain(w)
	w.swarm.pos[0] = Vector2(1000.0, 1000.0)
	w.critter_count = 0
	w.boss_index = -1
	# Inside `CRITTER_SENSE` and outside every reach, so the frames measured are walking and not contact.
	w._write_critter(int(Parts.Species.LION), Vector2(1400.0, 1000.0), 60)
	var gap: float = w.critter_pos[0].distance_to(w.swarm.pos[0])
	for _s in 60:
		w._step_critters(DT)
	t.ok(w.critter_pos[0].distance_to(w.swarm.pos[0]) < gap - 100.0,
			"사자는 아무 도발 없이 호스트를 향해 걸어온다 (%.0f → %.0f)"
					% [gap, w.critter_pos[0].distance_to(w.swarm.pos[0])])

	var hunters := 0
	for s in Rules.SPECIES_HUNTS.size():
		hunters += int(Rules.SPECIES_HUNTS[s])
	t.eq(hunters, 3, "사냥하는 종은 정확히 셋이다 — 늘린 것은 결정이고, 이름으로 못박는다")
	# **Named, not counted.** A count alone is satisfied by any three rows; the reversal is about WHICH three.
	var named := [Parts.Species.MOUSE, Parts.Species.DOG, Parts.Species.LION]
	t.eq(named.size(), hunters, "설정: 이름으로 적은 수가 표의 합과 같다 — 분모를 먼저 못 박는다")
	for s: int in named:
		t.eq(int(Rules.SPECIES_HUNTS[s]), 1, "%d종은 걸어온다 — 들쥐·들개·사자, 세 단계의 위협이다" % s)
		# ⚠ **The half that makes three survivable, and it must hold for EVERY one of them.** One hunter over
		# `HOST_SPEED` and "walking away always works" is false for the whole field, not for one row.
		t.ok(float(Rules.SPECIES_SPEED_MUL[s]) < 1.0,
				"그리고 %d종은 호스트보다 느리다 — 걸어서 떨어지는 것이 언제나 답이다 (%.2f × HOST_SPEED)"
						% [s, float(Rules.SPECIES_SPEED_MUL[s])])
	# The negative control: the count above passes on a table where a fleeing species also hunts, which would
	# be dead data — `_contact()` returns on `SPECIES_FLEES` before it ever reaches the hunt branch.
	for s in Rules.SPECIES_HUNTS.size():
		if int(Rules.SPECIES_HUNTS[s]) == 1:
			t.eq(int(Rules.SPECIES_FLEES[s]), 0,
					"대조: 사냥하는 %d종은 도망치지 않는다 — 도망치는 사냥꾼은 절대 때리지 않는다" % s)
	t.ok(float(Rules.SPECIES_SPEED_MUL[Parts.Species.SQUIRREL]) < 1.0,
			"다람쥐도 호스트보다 느리다 — 쫓아가서 잡을 수 있는 유일한 것이다")
	t.ok(float(Rules.SPECIES_SPEED_MUL[Parts.Species.CHEETAH])
					> float(Rules.SPECIES_SPEED_MUL[HORSE]),
			"치타는 말보다도 빠르다 — 어떤 수단으로도 잡히지 않는 것이다")


# -- G3: a herd is born together -------------------------------------------------------------------------
## "무리 지어 다닌다" is one spawn call and nothing else — no cohesion code, because a herd that is held
## together cannot produce the straggler the design wants you to catch.
##
## ⚠ **The spread is asserted as a CEILING and the count as an equality.** A `_spawn_herd` that fell back to
## placing each member independently would still write four horses; only the distance says they arrived
## together.
func _g3_a_herd_is_born_together(t) -> void:
	var w := World.new()
	w.setup(418)
	_silence_food(w)
	w.critter_count = 0
	w.boss_index = -1
	var born := w._spawn_herd(HORSE)
	t.eq(born, int(Rules.SPECIES_HERD[HORSE]), "말 한 무리는 SPECIES_HERD만큼 태어난다")
	t.eq(w.critter_count, 4, "그리고 그 수는 넷이다 (리터럴)")
	var anchor: Vector2 = w.critter_pos[0]
	var worst := 0.0
	for k in w.critter_count:
		worst = maxf(worst, w.critter_pos[k].distance_to(anchor))
	t.ok(worst <= Rules.SPAWN_HERD_SPREAD,
			"넷은 SPAWN_HERD_SPREAD 안에 모여 태어난다 (%.0f ≤ %.0f)" % [worst, Rules.SPAWN_HERD_SPREAD])
	t.ok(worst > 0.0, "그리고 한 점에 겹쳐 있지는 않다 (%.0f)" % worst)

	# ⚠ **The herd's ANCHOR pays for the spread**, and this is the check that says so. A member does not
	# re-test its distance to the host, so a flat `CRITTER_SPAWN_MIN_DIST` on the anchor puts the far side
	# of the herd inside the guarantee — measured at 865px against the literal 900 the first time this ran.
	var closest := INF
	for n in 12:
		var w2 := World.new()
		w2.setup(460 + n)
		w2.critter_count = 0
		w2.boss_index = -1
		for _h in 3:
			w2._spawn_herd(HORSE)
		for k in w2.critter_count:
			closest = minf(closest, w2.critter_pos[k].distance_to(w2.swarm.pos[0]))
	t.ok(closest >= Rules.CRITTER_SPAWN_MIN_DIST,
			"무리의 어느 한 마리도 화면 안에서 태어나지 않는다 (%.0f ≥ %.0f)"
					% [closest, Rules.CRITTER_SPAWN_MIN_DIST])
	t.ok(w._anchor_min_dist(HORSE, false) > w._anchor_min_dist(CROW, false),
			"무리를 짓는 종의 닻은 혼자 오는 종보다 멀리서 굴려진다 — 퍼짐값을 미리 치른다")
	# **And the two base distances are two different rules, asserted through the one function that picks
	# between them.** Written only as literals in `net_numbers` this branch could be deleted outright —
	# `_anchor_min_dist` ignoring `at_start` and always returning the arrival number is the mutation that
	# re-opens 몬스터가 내 주변에 없어, and it changes no constant.
	t.eq(w._anchor_min_dist(CROW, true), Rules.CRITTER_START_MIN_DIST,
			"개막의 혼자 오는 종은 CRITTER_START_MIN_DIST에서 시작한다 (%.0f)"
					% w._anchor_min_dist(CROW, true))
	t.eq(w._anchor_min_dist(HORSE, true), Rules.CRITTER_START_MIN_DIST + Rules.SPAWN_HERD_SPREAD,
			"개막의 무리도 제 퍼짐값을 치른다 — 480px이다 (%.0f)" % w._anchor_min_dist(HORSE, true))
	t.ok(w._anchor_min_dist(CROW, true) < w._anchor_min_dist(CROW, false),
			"그리고 개막은 도착보다 가깝다 — 이 부등호가 뒤집히면 첫 화면은 다시 풀밭뿐이다")


# -- A3: the knockback is proportional to the attacker's force, and it never lands a body inside a rock ---
## ⚠ **Distance must be MEASURED, not merely "did the position change".** A knockback that always moved a
## body by a fixed 5px would pass a check that only asserts `pos != before`; the proportionality half is
## what a fixed-distance mutation cannot satisfy.
func _a3_knockback_is_proportional_and_survives_a_rock(t) -> void:
	var w := World.new()
	w.setup(500)
	_silence_food(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	var at := Vector2(1500.0, 1000.0)
	w._write_critter(CROW, at, 10)
	var before_crow: Vector2 = w.critter_pos[0]
	w._damage_critter(0, 10, Vector2(1.0, 0.0))
	var moved_crow: float = w.critter_pos[0].distance_to(before_crow)
	t.ok(absf(moved_crow - 10.0 * Rules.KNOCKBACK_PER_FORCE) < 0.01,
			"힘 10짜리 한 방은 그 힘 × KNOCKBACK_PER_FORCE만큼 민다 (%.2f, 기대 %.2f)"
					% [moved_crow, 10.0 * Rules.KNOCKBACK_PER_FORCE])

	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(BOSS, at, 120)
	var before_boss: Vector2 = w.critter_pos[0]
	w._damage_critter(0, 120, Vector2(1.0, 0.0))
	var moved_boss: float = w.critter_pos[0].distance_to(before_boss)
	t.ok(absf(moved_boss - 120.0 * Rules.KNOCKBACK_PER_FORCE) < 0.01,
			"힘 120짜리 한 방은 그만큼 더 세게 민다 (%.2f, 기대 %.2f)"
					% [moved_boss, 120.0 * Rules.KNOCKBACK_PER_FORCE])
	t.ok(moved_boss > moved_crow * 10.0,
			"그리고 보스가 훨씬 더 크게 밀린다 — 세기는 힘 하나에서 나온다, 상수가 아니다 (%.2f vs %.2f)"
					% [moved_boss, moved_crow])

	# `hit_dir`가 `Vector2.ZERO`거나 데미지가 0이면 밀지 않는다 — 죽지 않는 검사도 방향이 없으면 안 민다.
	var w0 := World.new()
	w0.setup(502)
	_silence_food(w0)
	_clear_terrain(w0)
	w0.critter_count = 0
	w0.boss_index = -1
	w0._write_critter(CROW, at, 10)
	var before_zero: Vector2 = w0.critter_pos[0]
	w0._damage_critter(0, 10)
	t.eq(w0.critter_pos[0], before_zero, "방향 없는 피해는 밀지 않는다 — 기본값 Vector2.ZERO는 안전하다")

	# push_out survival: a rock sits directly in the knockback's path. Without `terrain.push_out` in the
	# sequence the creature teleports INSIDE it — the same "not knocked back, TELEPORTED" bug §A-3 forbids.
	var w2 := World.new()
	w2.setup(501)
	_silence_food(w2)
	_clear_terrain(w2)
	w2.critter_count = 0
	w2.boss_index = -1
	var at2 := Vector2(1500.0, 1000.0)
	w2._write_critter(CROW, at2, 10)
	var rock_r := 40.0
	# 8px is where a force-10 hit lands (10 × 0.8) — the rock sits centred just past it, so an UNGUARDED
	# knockback lands dead inside it.
	w2.terrain.rock_pos.append(at2 + Vector2(8.0 + rock_r * 0.5, 0.0))
	w2.terrain.rock_radius.append(rock_r)
	t.ok(w2.terrain.push_out(at2 + Vector2(8.0, 0.0), w2.critter_radius(0))
					!= at2 + Vector2(8.0, 0.0),
			"설정: 바위를 실제로 그 밀리는 자리에 놓았다 — 안 밀어내는 자리라면 아래는 아무것도 재지 않는다")
	w2._damage_critter(0, 10, Vector2(1.0, 0.0))
	var final_pos: Vector2 = w2.critter_pos[0]
	t.ok(final_pos.distance_to(w2.terrain.rock_pos[0]) >= rock_r - 0.01,
			"밀린 자리는 바위 밖이다 — push_out을 거치지 않으면 바위 속으로 순간이동한다 (%.2f, 반지름 %.2f)"
					% [final_pos.distance_to(w2.terrain.rock_pos[0]), rock_r])


# -- D1: the boss-hunt announcement fires exactly once ----------------------------------------------------
## §D-1 needs "the hunt has started" to be a single crossing, and `World.boss_hunting()` is where it is
## written — **once, derived from `elapsed`, replacing a latched flag and two hand-written copies of the
## same comparison** (see that function). This crosses the threshold with many small steps and counts the
## flips: a value that could be re-armed would flash the announcement more than once, and one that reverses
## would take the boss back to wandering with the screen still saying it comes.
##
## ⚠ **And it asserts the OTHER readers agree on the same frames** — the boss actually walking at the host
## and the arena being allowed to close both used to compare `elapsed >= Rules.BOSS_HUNT_AT` on their own.
func _d1_boss_hunt_announces_once(t) -> void:
	var w := World.new()
	w.setup(503)
	_silence_food(w)
	_clear_terrain(w)
	t.eq(w.boss_hunting(), false, "설정: 갓 만든 세상은 아직 사냥 중이 아니다")

	# Start five seconds short of the threshold and step small frames across it and well past it — the
	# crossing itself, not merely "eventually true", is what has to be caught exactly once.
	w.elapsed = Rules.BOSS_HUNT_AT - 5.0
	var flips := 0
	var was: bool = w.boss_hunting()
	for _s in 600:
		w.step(DT)
		if w.boss_hunting() != was:
			flips += 1
			was = w.boss_hunting()
	t.eq(flips, 1,
			"elapsed가 BOSS_HUNT_AT을 넘는 순간은 한 번뿐이고, 사냥 여부도 딱 한 번만 뒤집힌다 (%d)" % flips)
	t.ok(w.boss_hunting(), "그리고 넘은 뒤로는 참이다")

	# Many more frames on the far side — it must never flip back, and must not flip a SECOND time either.
	for _s in 300:
		w.step(DT)
	t.ok(w.boss_hunting(), "몇 초가 더 지나도 여전히 참이다 — 왔다 갔다 하지 않는다")

	# **One truth, three readers.** The threshold is not restated in `_step_critters` or `_step_arena` any
	# more, so a world one frame SHORT of it must have a wandering boss and a shut arena, and the same world
	# one frame past it must have neither — driven, on the same fixture, either side of the same line.
	var wb := World.new()
	wb.setup(504)
	_silence_food(wb)
	_clear_terrain(wb)
	for k in range(wb.critter_count - 1, -1, -1):
		if k != wb.boss_index:
			wb._remove_critter(k)
	var host: Vector2 = wb.swarm.pos[0]
	# Dead ahead and well inside `ARENA_RADIUS`: on the hunting side the boss closes and the arena shuts.
	wb.critter_pos[wb.boss_index] = host + Vector2(400.0, 0.0)
	wb.elapsed = Rules.BOSS_HUNT_AT - DT
	t.ok(not wb.boss_hunting(), "설정: 한 프레임 모자란 세상은 아직 사냥 중이 아니다")
	# ⚠ **The negative side is asserted on the DIRECTION, not on the distance.** A wanderer moves 2.5px a
	# frame in whatever direction it already had, and that direction can point at the host by luck — a
	# distance test would be a coin flip. Hunting writes exactly `(host - p).normalized()`, which here is
	# `(-1, 0)`; a random wander landing within 0.0001 rad of it has probability ~3e-5.
	var at_host := (host - wb.critter_pos[wb.boss_index]).normalized()
	wb._step_critters(DT)
	wb._step_arena()
	t.ok(not wb.terrain.arena_closed,
			"사냥 전이면 코앞의 보스여도 아레나는 닫히지 않는다 — _step_arena도 같은 하나를 읽는다")
	t.ok(absf(wb.critter_dir[wb.boss_index].angle_to(at_host)) > 0.0001,
			"그리고 배회하는 보스는 호스트 쪽을 정확히 향하지 않는다 (%s)" % str(wb.critter_dir[wb.boss_index]))

	wb.elapsed = Rules.BOSS_HUNT_AT
	t.ok(wb.boss_hunting(), "설정: 같은 세상을 한 프레임 넘기면 사냥 중이다")
	var mid := wb.critter_pos[wb.boss_index].distance_to(host)
	wb._step_critters(DT)
	t.ok(wb.critter_pos[wb.boss_index].distance_to(host) < mid - 0.01,
			"넘긴 뒤로는 보스가 호스트 쪽으로 좁힌다 — _step_critters도 같은 하나를 읽는다 (%.2f → %.2f)"
					% [mid, wb.critter_pos[wb.boss_index].distance_to(host)])
	wb._step_arena()
	t.ok(wb.terrain.arena_closed, "그리고 이제 아레나가 닫힌다")


func _silence_food(w: World) -> void:
	for i in w.food.alive.size():
		w.food.alive[i] = 0
	w.food.alive_count = 0


## Forty rocks sit wherever a fixture writes a coordinate, and `push_out` moves a hand-placed body or
## creature off one by up to a rock's radius. **A check that is not about the ground removes the ground.**
func _clear_terrain(w: World) -> void:
	w.terrain.rock_pos.clear()
	w.terrain.rock_radius.clear()
	w.terrain.water_pos.clear()
	w.terrain.water_radius.clear()
