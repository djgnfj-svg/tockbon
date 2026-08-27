extends RefCounted
## What one island's fight actually does, measured **through `battle.step(dt)`** and never by calling a
## helper on its own.
##
## Every check below builds a `Battle`, drives it with `step`, and reads the public columns afterwards.
## Calling `grid.step_toward` or `_within` directly would prove a pure function correct and prove nothing
## about whether `step` ever reaches it — that hole is why `net_grid` was folded into this net in the
## first slice plan, and it is the same shape that once shipped a notice painting at zero size under a
## green round.
##
## **The grids here are hand-built, not the three real islands.** A fixture that moves when someone edits
## an island measures the island; `net_islands` owns the real grids and this net owns the rules.
##
## ⚠ **`step` runs whole `Rules.SIM_SUBSTEP_SEC` sub-steps and carries the leftover** (`plan-then-watch`,
## 5.2), so there is no longer any such thing as a step too small to do anything: `step(1e-5)` runs ZERO
## phases and every column stays at its fixture value, which reads as "the rule did not fire" on every
## check in this file at once. That is exactly what the old `TICK_ONE` became the day sub-stepping
## landed. ⇒ **One sub-step is the smallest thing that happens**, and it is what every "measure the
## blow at the distance the fixture wrote" row is driven with now.
##
## A unit already inside its reach does not walk (`_phase_movement` returns before `_walk` for it), so
## one sub-step still leaves those fixtures standing exactly where they were written — which is the
## property those rows actually needed. A unit OUTSIDE its reach closes `speed / 60` of a tile, and no
## row in this file is bounded tightly enough for that to matter.
##
## A real 0.1 s frame (six sub-steps) is used wherever the thing being measured IS movement.


## One whole sub-step — the smallest amount of simulated time that exists. See the header.
const TICK_ONE := Rules.SIM_SUBSTEP_SEC

const ARENA_W := 24
const ARENA_H := 12
const LANE_W := 24
const LANE_H := 5
const CORR_W := 12
const CORR_H := 9


func run(t) -> void:
	_setup_barks_on_empty_grid(t)
	_no_two_units_share_a_tile(t)
	_nearest_first(t)
	_reach_is_range_plus_bonus(t)
	_epsilon_edge(t)
	_area_splash(t)
	_no_friendly_fire(t)
	_stops_when_target_is_in_range(t)
	_death_is_permanent(t)
	_phase_order(t)
	_in_transit_is_hit_but_cannot_hit(t)
	_reserves_do_not_hold_the_run_open(t)
	_a_soldier_at_sea_does_hold_it_open(t)
	_the_gate_itself(t)
	_wiped_wins_when_both_are_true(t)
	# -- ticket 11: the status table reaches the fight ---------------------------------------------
	_bleed_drips_after_the_blow(t)
	_bleed_off_below_threshold(t)
	_bleed_refreshes_and_never_stacks(t)
	_bleed_death_passes_the_same_substep(t)
	_the_bleed_stops_when_its_tier_runs_out(t)
	_status_rides_the_splash(t)
	_a_status_tier_is_strong_the_way_its_kind_reads(t)
	_slow_makes_the_hit_enemy_walk_less(t)
	_slow_expires_back_to_full_speed(t)
	_slow_refreshes_and_never_stacks(t)
	_enemy_blows_carry_no_status(t)
	# -- 티켓 15: the passives that are still ON THE BOARD ---------------------------------------------
	# ⚠⚠ **THREE ROWS WERE DELETED HERE 2026-08-27 AND ALL THREE HAD STOPPED MEASURING.**
	# 「까마귀는 장비 없이도 문다」, 「늑대가 무리로 사냥한다」 and 「까마귀 제 종의 출혈이 장비를 안
	# 덮어쓴다」 went with `Rules.SPECIES_STATUS` and `Rules.SPECIES_PACK`. Both tables are looked up
	# against the PLAYER's roster and **both held a single beast row that became an ENEMY on 2026-08-26**,
	# so `species_status_of` answered `{}` and `pack_radius_of` answered 0.0 on every call in the game.
	# ⇒ **What survived the cut did so by moving to a live source**: the bleed CEILING is now driven off
	# the equipment tag (`_the_bleed_stops_when_its_tier_runs_out`), and the kind-dependent strength
	# comparison is now labelled as the arithmetic it is
	# (`_a_status_tier_is_strong_the_way_its_kind_reads`). The reasoning each deleted row carried is
	# written where the row stood.
	_the_bear_sweeps(t)
	# ⚠⚠ **THREE SHOVE ROWS WERE DELETED HERE 2026-08-27, AND THEY HAD ALREADY STOPPED MEASURING.**
	# 「다람쥐 끌어당김 · 소 돌진」, 「막힌 밀치기는 충전을 안 태운다」 and 「밀치기가 목표와 예약을 함께
	# 옮긴다」 went with `Rules.SPECIES_SHOVE`. The table emptied on 2026-08-26 when 다람쥐 and 소 left
	# `UNITS`, and the three had been rewritten to pass `Rules.SWORDSMAN` where those two stood — so
	# they asked a swordsman for a shove distance, got 0.0, and asserted it was positive. **Red for a
	# reason that had nothing to do with the behaviour they were named after.**
	#
	# What they held: the sign convention (positive pulls the victim TOWARD the attacker, negative
	# pushes it away), the 「once per island」 column that told a charge from a pull, that a blocked
	# shove must not spend the charge, and that `enemy_pos` alone undoes itself within one sub-step
	# unless `_enemy_goal` and `grid.reserved` move with it.
	# ⇒ **The full reasoning is in `battle.gd` where `_shove` stood**, including the user's 티켓 19
	# decision that a body never changes tier by being pushed.


# -- 상태이상 층의 강약: 종류마다 반대로 읽는다 ---------------------------------------------------------
## ⚠⚠ **THE FIXTURE THAT STOOD HERE IS DELETED AND THE ARITHMETIC IT PROTECTED IS NOT.** It was
## 「까마귀 제 종의 출혈이 장비를 약하게 만들지 않는다」: a crow, five bleed items, a wolf control wearing
## the identical five, and a bare crow — all of it aimed at a REAL defect that
## `Rules.stronger_status_tier` fixed. **`Rules.SPECIES_STATUS` is deleted (2026-08-27)**, so a blow now
## has exactly one source and the fixture has nothing to resolve.
##
## ⚠⚠ **THE DEFECT IS WORTH KEEPING BECAUSE THE NEXT SECOND SOURCE WILL REPEAT IT.** Written as two
## writes in a row, the species value landed LAST: a full bleed set (2층, 초당 1.5 · 3초) reached a
## crow's target as **0.5 / 2.0 — 22% of what the same set gives a 늑대.** Equipment fitted ANYWHERE on
## the board penalised the crow specifically, because `tag_count` sums every board. ⚠ **It needed FIVE
## copies to show**, since tier 2's threshold is five and nothing else in this file drives more than
## three — which is exactly why nothing caught it.
##
## ⚠⚠ **AND THE ONE ROW THAT SURVIVES IS A DIRECT CALL, WHICH THIS FILE'S HEADER OTHERWISE FORBIDS.**
## No two rows of `TAG_STATUS_TIERS` name the same `Status`, so through `step` one argument is always
## `{}` and **only the empty-arms of `stronger_status_tier` can fire.** The kind-dependent comparison —
## a DOT is stronger when BIGGER, a SLOW when SMALLER, and one comparison for both hands a slowed enemy
## the weakest slow on the field — is therefore unreachable from a fight today. ⇒ **It is measured as
## arithmetic, labelled as arithmetic, and a green here is NOT evidence that a fight resolves two
## sources.** The day a second source lands, this becomes a `step`-driven row again.
func _a_status_tier_is_strong_the_way_its_kind_reads(t) -> void:
	var slow_a := {"mag": 0.5, "sec": 2.0}
	var slow_b := {"mag": 0.7, "sec": 2.0}
	t.eq(float(Rules.stronger_status_tier(Rules.Status.SLOW, slow_a, slow_b)["mag"]), 0.5,
		"감속은 배율이 작은 쪽이 강하다 — DOT 과 반대로 읽는다")
	t.eq(float(Rules.stronger_status_tier(Rules.Status.BLEED, slow_a, slow_b)["mag"]), 0.7,
		"출혈은 큰 쪽이 강하다 — 같은 두 값을 종류에 따라 반대로 고른다")
	# ⚠ Either side may be empty, and that is the arm a fight actually runs today.
	t.eq(float(Rules.stronger_status_tier(Rules.Status.BLEED, {}, slow_b)["mag"]), 0.7,
		"한쪽이 비면 남은 쪽이 그대로 선다 — 지금 싸움이 실제로 도는 갈래다")
	t.ok(Rules.stronger_status_tier(Rules.Status.BLEED, {}, {}).is_empty(),
		"둘 다 비면 아무것도 안 남는다")
	# ⚠ Ties on magnitude break on the LONGER duration, so an equally strong source that lasts longer
	# is not silently discarded.
	t.eq(float(Rules.stronger_status_tier(Rules.Status.BLEED,
			{"mag": 0.5, "sec": 2.0}, {"mag": 0.5, "sec": 3.0})["sec"]), 3.0,
		"세기가 같으면 오래가는 쪽이 이긴다")


## The `TAG_STATUS_TIERS` row that carries 출혈, found rather than written as an index.
func _bleed_row() -> int:
	for r in Rules.tag_status_row_count():
		if Rules.tag_status_status_of(r) == Rules.Status.BLEED:
			return r
	return -1
func _with_char(row: String, at: int, ch: String) -> String:
	return row.substr(0, at) + ch + row.substr(at + 1)
# -- 무리사냥: 「늑대가 무리로 사냥한다」 삭제됨 2026-08-27 --------------------------------------------
## ⚠⚠ **THIS ROW AND ITS HELPER `_max_pair` ARE DELETED WITH `Rules.SPECIES_PACK`, `Rules.pack_radius_of`
## AND `Battle._seek_point_of`.** It asked `pack_radius_of(Rules.WOLF)` for a radius of 6.0 and then
## drove five fixtures through it; the table was read against the PLAYER's roster and the wolf has been
## an ENEMY since 2026-08-26, so **the rule under test had not run once in a real fight since that day.**
##
## ⚠⚠ **WHAT IT CAUGHT, WHICH IS THE ONLY REASON THIS PARAGRAPH EXISTS.** An earlier version of the same
## row had ONE enemy on the board, and `_nearest_enemy` answers the same id from any point at all — so
## three bodies walking at one target converge whatever the rule says. **Forcing the radius to 0.0 left
## it green and pack-on and pack-off printed the identical decimal**, which `tools/probe/pack_spread.gd`
## then measured properly and `how-nets-lie` records. ⇒ **A row about a rule that CHOOSES
## between things must put at least two things in front of it to choose between**, and the rewrite that
## fixed it — two enemies placed so a lone hunter SPLITS, plus a control species that demonstrably does
## split — is the shape to copy, not the wolf.
##
## ⚠ **Two more things it knew.** The bound on 「도착했을 때 서로 얼마나 가까운가」 was DERIVED and never
## guessed: three bodies all inside one enemy's reach are at most twice that reach from each other, by
## the triangle inequality. And its far target had to be a **LION**: `REACH_BONUS` went 1.5 -> 1.75 and a
## 20 HP body then died before the third attacker was inside reach, so the loop broke with the
## measurement never taken — **a target that outlives the arrival is what lets the arrival be measured.**
##
## ⇒ **The rule itself, why it was hollow as well as dead, and the reverted cohesion throttle are in
## `rules.gd` where `SPECIES_PACK` stood.** Do not rebuild this row from this comment alone.


# -- 티켓 11: the bleed CEILING — a lit tier stops when its own duration runs out ----------------------
## ⚠⚠ **THIS ROW WAS 「까마귀는 장비 없이도 문다」 AND ITS SUBJECT IS DELETED** (2026-08-27,
## `Rules.SPECIES_STATUS`). The crow's innate bleed was looked up against the PLAYER's roster and the
## crow has been an ENEMY since 2026-08-26, so the source it measured answered `{}` on every blow.
## **What it also measured is alive and had no other home**, which is why this is a rewrite and not a
## deletion: `_bleed_drips_after_the_blow` runs 30 sub-steps of a 2-second tier and therefore never
## reaches the end of one. ⇒ **The ceiling — 「표의 지속 시간이 지나면 멎는다」 — lives here**, driven off
## the equipment tag instead of the species row.
##
## ⚠⚠ **THE ENEMY IS PARKED FAR AWAY RATHER THAN THE SOLDIER BEING PULLED OFF THE ISLAND, AND THAT WAS
## MEASURED.** Sending the biter back to RESERVE ends the island on the spot
## (`_the_landing_force_is_gone`), `step` returns before `_phase_status`, and **the bleed clock then
## FREEZES instead of expiring** — the ceiling read 1.97 of its 2.00 seconds with the whole fixture
## looking correct.
##
## ⚠ **The geometry is load-bearing and is the crow's, deliberately.** 19 tiles of parked distance
## against a 4.0-speed body is what keeps the biter out of its own 5.75 reach for the whole measured
## window; the closing self-check at the bottom is what proves it rather than assuming it.
##
## ⚠ Mutation: drop the ageing line in `_phase_status`; clamp `tag_status_tier_at`'s `sec` to a large
## number (both ends bite).
func _the_bleed_stops_when_its_tier_runs_out(t) -> void:
	var army := _army_of([Rules.CROW])
	_worn(army, ITEM_BLEED, 3, Rules.SWORDSMAN)
	var lit := Rules.tag_status_tier_at(_bleed_row(), 3)
	t.ok(not lit.is_empty(), "출혈 딱지 셋이면 1층이 켜진다 (자가 점검)")
	var b := _battle_of(_open(ARENA_W, ARENA_H), army,
		[_spawn(ARENA_W, Rules.WOLF, 6, 5)])
	_ashore(b, 0, Vector2(3, 5))
	b.begin_frame()
	b.step(TICK_ONE)
	t.ok(b.enemy_hp[0] < Rules.hp_of(Rules.WOLF), "실제로 때렸다 (자가 점검)")
	t.ok(b.status_left(Rules.Status.BLEED, 0) > 0.0, "맞은 적에게 출혈이 걸렸다 (자가 점검)")

	var parked := Vector2(ARENA_W - 2, 5)
	b.enemy_pos[0] = parked
	b._enemy_goal[0] = parked
	b._settle(Battle.ENEMY_UID_BASE + 0, parked)
	var hp_before := b.enemy_hp[0]
	for _k in 30:
		b.begin_frame()
		b.step(TICK_ONE)
	t.ok(b.enemy_hp[0] < hp_before,
		"손이 떨어진 뒤에도 피가 계속 흐른다 (%.3f -> %.3f) — 바닥" % [hp_before, b.enemy_hp[0]])

	# The CEILING: it stops when the lit tier's own duration runs out, and never before.
	var secs: float = float(lit["sec"])
	t.ok(secs > 0.0, "켜진 층이 지속 시간을 갖고 있다 (자가 점검)")
	var settle := int(ceil(float(secs) / Rules.SIM_SUBSTEP_SEC)) + 4
	for _k in settle:
		b.begin_frame()
		b.step(TICK_ONE)
	t.eq(b.status_left(Rules.Status.BLEED, 0), 0.0, "켜진 층의 지속 시간이 지나면 멎는다 — 천장")
	var hp_stopped := b.enemy_hp[0]
	for _k in 30:
		b.begin_frame()
		b.step(TICK_ONE)
	t.eq(b.enemy_hp[0], hp_stopped, "그리고 그 뒤로는 한 방울도 안 흐른다")
	# The fixture's own floor: the biter never got back into reach, so nothing above was re-applied.
	t.ok(b.soldier_pos[0].distance_to(b.enemy_pos[0])
			> Rules.range_of(Rules.CROW) + Rules.REACH_BONUS,
		"그동안 무는 쪽은 사거리 밖에 머물렀다 — 재적용이 아니라 만료다 (자가 점검)")
# -- 티켓 15: 곰 — 휘두르기 ---------------------------------------------------------------------------
## **The bear's whole passive is one number in `UNITS`' `area` column** — `_phase_attacks` already
## hands `Rules.area_of(st)` to `_hit_enemies`, and `_hit_enemies` already walks a radius. `battle.gd`
## is not opened for it.
##
## ⚠⚠ **The floor and the ceiling are in ONE fixture**: three enemies inside the radius all lose HP,
## and one outside it does not. A ceiling alone (「반경 밖은 안 맞는다」) is green when the bear never
## swings at all, which is `how-nets-lie`'s own four-at-once finding from the presentation round.
##
## ⚠ Mutation: `BEAR`'s `area` back to 0.0 (the floor bites); widen it past the outside enemy (the
## ceiling bites).
func _the_bear_sweeps(t) -> void:
	var army := _army_of([Rules.BEAR])
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [
		_spawn(ARENA_W, Rules.WOLF, 12, 5),   # primary, 1.0 from the bear
		_spawn(ARENA_W, Rules.WOLF, 13, 5),   # 1.0 from the primary
		_spawn(ARENA_W, Rules.WOLF, 13, 6),   # 1.41421 from the primary
		_spawn(ARENA_W, Rules.WOLF, 12, 8),   # 3.0 from the primary — outside
	])
	_ashore(b, 0, Vector2(11, 5))
	b.begin_frame()
	b.step(TICK_ONE)

	var full := Rules.hp_of(Rules.WOLF)
	t.eq(b.soldier_target[0], 0, "곰의 주 표적은 최근접이다 (자가 점검)")
	t.ok(b.enemy_hp[0] < full, "주 표적이 맞았다 — 바닥")
	t.ok(b.enemy_hp[1] < full, "반경 안 직교 형제도 같이 맞았다 — 바닥")
	t.ok(b.enemy_hp[2] < full, "반경 안 대각 형제도 같이 맞았다 — 바닥")
	t.eq(b.enemy_hp[3], full, "반경 밖 하나는 그대로다 — 천장")
	# The radius itself, so 「휘두른다」 is a number and not a direction.
	t.ok(Rules.area_of(Rules.BEAR) > 0.0, "곰의 area 칸이 0 보다 크다")
	t.eq(Rules.area_of(Rules.BEAR), 1.5, "그 값이 1.5 다 (리터럴 — 첫 값이고 잰 값이 아니다)")
	# The CONTROL: the wolf has no area, so the same arrangement leaves the siblings whole.
	var lone := _army_of([Rules.WOLF])
	var w := _battle_of(_open(ARENA_W, ARENA_H), lone, [
		_spawn(ARENA_W, Rules.WOLF, 12, 5),
		_spawn(ARENA_W, Rules.WOLF, 13, 5),
	])
	_ashore(w, 0, Vector2(11, 5))
	w.begin_frame()
	w.step(TICK_ONE)
	t.ok(w.enemy_hp[0] < full, "늑대도 주 표적은 때렸다 (자가 점검)")
	t.eq(w.enemy_hp[1], full, "그러나 형제는 멀쩡하다 — 휘두르는 것은 이 종이지 아무 타격이나가 아니다")


# -- the one bark this file owns -------------------------------------------------------------------

func _setup_barks_on_empty_grid(t) -> void:
	t.expect_error("battle.setup: 격자가 비어 있다")
	var dud := Battle.new()
	dud.setup(Grid.new(), _army_of([Rules.WOLF]), [_spawn(1, Rules.WOLF, 0, 0)])
	t.eq(dud.soldier_state.size(), 0, "빈 격자로 setup 하면 짖고 병사 열을 세우지 않는다")
	t.eq(dud.enemy_alive.size(), 0, "빈 격자로 setup 하면 적 열도 세우지 않는다")


# -- reservation, seen from outside ----------------------------------------------------------------

## Four soldiers funnelling through a one-tile neck at a lion that never leaves its post (detect 2).
##
## **The check reads POSITIONS, not `grid.reserved`.** Deleting `step_toward`'s "skip a tile someone else
## holds" test leaves the reservation table looking sane — `_hold` still refuses to overwrite — while the
## units walk straight through each other. Only where they ARE catches that.
func _no_two_units_share_a_tile(t) -> void:
	var army := _army_of([Rules.WOLF, Rules.WOLF, Rules.WOLF, Rules.WOLF])
	var b := _battle_of(_corridor(), army, [_spawn(CORR_W, Rules.LION, 9, 4)])
	_ashore(b, 0, Vector2(2, 3))
	_ashore(b, 1, Vector2(2, 4))
	_ashore(b, 2, Vector2(2, 5))
	_ashore(b, 3, Vector2(3, 4))

	var observations := 0
	var clashes := 0
	var through := {}
	for _f in 100:
		b.begin_frame()
		b.step(0.1)
		var seen := {}
		for raw in b.ashore_ids():
			var i := int(raw)
			var k := _tile_key(b.soldier_pos[i], CORR_W)
			if seen.has(k):
				clashes += 1
			seen[k] = true
			observations += 1
			if b.soldier_pos[i].x > 5.5:
				through[i] = true
		for e in b.enemy_alive.size():
			if b.enemy_alive[e] == 0:
				continue
			var ke := _tile_key(b.enemy_pos[e], CORR_W)
			if seen.has(ke):
				clashes += 1
			seen[ke] = true
			observations += 1

	# A loop whose body never ran would report zero clashes just as loudly.
	t.ok(observations >= 300, "좁은 목 100프레임에서 유닛 위치를 %d번 읽었다 (최소 300)" % observations)
	t.eq(clashes, 0, "살아 있는 유닛 둘이 한 칸을 같이 쓰지 않는다")
	t.ok(through.size() >= 3, "네 병사 중 %d명이 좁은 목을 통과했다 — 줄서기가 실제로 일어났다" % through.size())
	t.ok(b.enemy_hp[0] < Rules.hp_of(Rules.LION), "통과한 병사가 사자를 실제로 때렸다 — 검사가 빈 채로 초록이 아니다")


# -- targeting -------------------------------------------------------------------------------------

func _nearest_first(t) -> void:
	var army := _army_of([Rules.CROW])
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [
		_spawn(ARENA_W, Rules.WOLF, 12, 1),   # 4 tiles up
		_spawn(ARENA_W, Rules.WOLF, 12, 7),   # 2 tiles down
	])
	_ashore(b, 0, Vector2(12, 5))
	b.begin_frame()
	b.step(TICK_ONE)
	t.eq(b.soldier_target[0], 1, "더 가까운 적을 고른다 (2칸 대 4칸)")

	# The near one dies; the next frame must hand the soldier the far one.
	b.enemy_hp[1] = 0.0
	b.begin_frame()
	b.step(TICK_ONE)
	t.eq(b.enemy_alive[1], 0, "가까운 적이 죽었다")
	b.begin_frame()
	b.step(TICK_ONE)
	t.eq(b.soldier_target[0], 0, "표적이 죽으면 남은 최근접으로 다시 고른다")

	var tie_army := _army_of([Rules.CROW])
	var tied := _battle_of(_open(ARENA_W, ARENA_H), tie_army, [
		_spawn(ARENA_W, Rules.WOLF, 12, 3),
		_spawn(ARENA_W, Rules.WOLF, 12, 7),
	])
	_ashore(tied, 0, Vector2(12, 5))
	tied.begin_frame()
	tied.step(TICK_ONE)
	t.eq(tied.soldier_target[0], 0, "거리가 같으면 id 가 작은 쪽을 고른다")


# -- reach -------------------------------------------------------------------------------------

## Melee range is 0, so its reach is exactly `Rules.REACH_BONUS`. 1.0 is an orthogonal neighbour,
## 1.41421 a diagonal one, and 2.0 is the first distance that must not reach.
func _reach_is_range_plus_bonus(t) -> void:
	var full := Rules.hp_of(Rules.WOLF)
	var hit := full - Rules.damage_of(Rules.WOLF)
	t.eq(_melee_probe(Vector2(-1, 0), TICK_ONE), hit, "정확히 1.0 칸에서 때린다")
	t.eq(_melee_probe(Vector2(-1, -1), TICK_ONE), hit, "정확히 1.41421 칸(대각)에서도 때린다")
	t.eq(_melee_probe(Vector2(-2, 0), TICK_ONE), full, "2.0 칸에서는 못 때린다")


## The comparison is `<=` with `Rules.EPS` of slack, so half an epsilon past the reach is inside and
## three epsilons past it is outside. Without the slack a diagonal — exactly sqrt(2) — is a coin flip.
##
## ⚠ **The OUTSIDE half cannot be read off damage any more, and pretending it can is a fake green.**
## One sub-step is the smallest amount of time there is, and a melee cell walks `4 / 60` = 0.067 tiles
## in it — three epsilons is 0.0003 — so a soldier outside its reach closes the gap and lands the blow
## in the very same sub-step, `_phase_movement` running before `_phase_attacks`. ⇒ **`_within` is read
## through the OTHER decision it makes**: it is also the test that decides whether to walk at all, so
## the outside case is "it had to walk first" and the inside case is "it never moved."
func _epsilon_edge(t) -> void:
	var full := Rules.hp_of(Rules.WOLF)
	var hit := full - Rules.damage_of(Rules.WOLF)
	var inside := _reach_probe(Rules.REACH_BONUS + 0.5 * Rules.EPS)
	t.eq(inside["hp"], hit, "사거리+엡실론 절반 안쪽은 때린다")
	t.eq(inside["moved"], 0.0, "그리고 한 발짝도 안 걸었다 — 이미 사거리 안이라는 뜻이다")

	var outside := _reach_probe(Rules.REACH_BONUS + 3.0 * Rules.EPS)
	t.ok(float(outside["moved"]) > 0.0,
			"사거리+엡실론 세 배 바깥은 사거리 밖이다 — 때리기 전에 걸어야 했다 (%.4f칸)"
			% float(outside["moved"]))
	# The ceiling: it walked ONE sub-step's worth and not to the target. Without it, "moved" is also
	# satisfied by a unit that teleported.
	t.ok(float(outside["moved"]) <= Rules.speed_of(Rules.WOLF) * Rules.SIM_SUBSTEP_SEC + Rules.EPS,
			"그리고 딱 한 서브스텝만큼만 걸었다")
	t.eq(outside["hp"], hit,
			"바깥이어도 그 한 발짝이 사거리 안으로 데려다줘서 같은 서브스텝에 때렸다 — 이동이 공격보다 먼저 돈다")
	t.eq(full - Rules.damage_of(Rules.WOLF), hit, "때린 값은 근접 한 방이다 (자가 점검)")


## One melee soldier `gap` tiles west of one bison, driven exactly one sub-step. Returns the bison's HP
## and how far the soldier moved — the two halves `_within` decides between.
func _reach_probe(gap: float) -> Dictionary:
	var army := _army_of([Rules.WOLF])
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [_spawn(ARENA_W, Rules.WOLF, 12, 5)])
	var start := Vector2(12.0 - gap, 5.0)
	_ashore(b, 0, start)
	b.begin_frame()
	b.step(TICK_ONE)
	return {"hp": b.enemy_hp[0], "moved": start.distance_to(b.soldier_pos[0])}


# -- area ------------------------------------------------------------------------------------------

## **Two sibling tiles, not one.** The orthogonal neighbour is 1.0 away and the diagonal one 1.41421, and
## the two area values in the table are 1.0 and 1.5 — a case with only one kind of sibling cannot tell
## them apart, so an area silently widened from 1.0 to 1.5 would stay green.
func _area_splash(t) -> void:
	# area 1.0 (the ranged cell): the orthogonal sibling burns, the diagonal one does not.
	var small := _army_of([Rules.CROW])
	var b := _battle_of(_open(ARENA_W, ARENA_H), small, [
		_spawn(ARENA_W, Rules.WOLF, 12, 5),   # primary, 4.0 from the soldier
		_spawn(ARENA_W, Rules.WOLF, 13, 5),   # 1.0 from the primary
		_spawn(ARENA_W, Rules.WOLF, 13, 6),   # 1.41421 from the primary
	])
	_ashore(b, 0, Vector2(8, 5))
	b.begin_frame()
	b.step(TICK_ONE)
	var full := Rules.hp_of(Rules.WOLF)
	var splash := full - Rules.damage_of(Rules.CROW)
	t.eq(b.soldier_target[0], 0, "광역 공격의 주 표적은 최근접이다")
	# ⚠⚠ **AN EQUALITY AGAIN SINCE 2026-08-27, AND THE LOOSENING IS WORTH REMEMBERING.** This read
	# `t.ok(hp <= expected + EPS)` for two days: 까마귀 carried an innate bleed (`Rules.SPECIES_STATUS`)
	# that rode its own blow, and `_phase_status` took its first sip inside the SAME sub-step — so the
	# exact figure carried a tick of drip on top. **That table is deleted and the drip with it**, so the
	# blow is once more the only thing that touches this number. ⇒ **A bound loosened to admit a second
	# effect is tightened back the day that effect goes**, or the row quietly stops pinning the blow.
	t.eq(b.enemy_hp[0], splash, "주 표적이 타격 몰만큼 정확히 깎였다")
	t.eq(b.enemy_hp[1], splash, "반경 1.0 — 직교 1.0 칸의 형제도 같은 몴만큼 맞았다")
	t.eq(b.enemy_hp[2], full, "반경 1.0 — 대각 1.41421 칸의 형제는 안 맞았다")

	# area 1.5 (the lion): now the diagonal sibling burns too.
	#
	# ⚠ **The lion declares before it strikes**, so one frame measures the telegraph and not the blow —
	# this block used to read the splash off a single `step` and went red the day `LION_WINDUP_SEC`
	# landed. Waiting the wind-up out is only sound because nobody walks while it runs: all three are
	# already inside their 1.5 reach and the lion is inside its own, so the distances the splash is
	# measured at are still the ones written below. The position checks after the wait are what hold
	# that — without them a soldier could drift and the two area values stop being distinguishable.
	var wide := _army_of([Rules.WOLF, Rules.WOLF, Rules.WOLF])
	var w := _battle_of(_open(ARENA_W, ARENA_H), wide, [_spawn(ARENA_W, Rules.LION, 12, 6)])
	_ashore(w, 0, Vector2(12, 5))   # 1.0 from the lion
	_ashore(w, 1, Vector2(13, 5))   # 1.0 from soldier 0
	_ashore(w, 2, Vector2(13, 6))   # 1.41421 from soldier 0
	var whole := Rules.hp_of(Rules.WOLF)
	w.begin_frame()
	w.step(TICK_ONE)
	t.eq(w.enemy_target[0], 0, "사자의 주 표적은 id 가 작은 쪽이다 (1.0 동점)")
	t.eq(wide.hp[0], whole, "예고 프레임에는 광역이 아직 안 터졌다")
	# Break on the first blow: the next one is a whole `period + windup` away, and reading after two
	# would double every expectation below without changing which siblings were caught.
	var burst := false
	for _f in 40:
		w.begin_frame()
		w.step(0.05)
		if wide.hp[0] < whole:
			burst = true
			break
	t.ok(burst, "예고가 끝나자 사자의 광역이 실제로 터졌다")
	t.eq(w.soldier_pos[0], Vector2(12, 5), "기다리는 동안 주 표적은 안 걸었다 — 잰 거리는 fixture 의 것이다")
	t.eq(w.soldier_pos[1], Vector2(13, 5), "직교 형제도 안 걸었다")
	t.eq(w.soldier_pos[2], Vector2(13, 6), "대각 형제도 안 걸었다")
	var left := whole - Rules.damage_of(Rules.LION)
	t.eq(wide.hp[0], left, "주 표적이 맞았다")
	t.eq(wide.hp[1], left, "반경 1.5 — 직교 1.0 칸의 형제도 맞았다")
	t.eq(wide.hp[2], left, "반경 1.5 — 대각 1.41421 칸의 형제까지 맞았다")


## A ranged soldier splashing an enemy with a friendly standing 1.0 tile away — inside its own area.
## The friendly loses exactly the bison's blow and not a tile more.
func _no_friendly_fire(t) -> void:
	var army := _army_of([Rules.CROW, Rules.WOLF])
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [_spawn(ARENA_W, Rules.WOLF, 12, 5)])
	_ashore(b, 0, Vector2(8, 5))
	_ashore(b, 1, Vector2(13, 5))
	b.begin_frame()
	b.step(TICK_ONE)
	# ⚠⚠ **AN EQUALITY AGAIN SINCE 2026-08-27, AND THE LOOSENING IS WORTH REMEMBERING.** This read
	# `t.ok(hp <= expected + EPS)` for two days: 까마귀 carried an innate bleed (`Rules.SPECIES_STATUS`)
	# that rode its own blow, and `_phase_status` took its first sip inside the SAME sub-step — so the
	# exact figure carried a tick of drip on top. **That table is deleted and the drip with it**, so the
	# blow is once more the only thing that touches this number. ⇒ **A bound loosened to admit a second
	# effect is tightened back the day that effect goes**, or the row quietly stops pinning the blow.
	t.eq(b.enemy_hp[0],
			Rules.hp_of(Rules.WOLF) - Rules.damage_of(Rules.CROW) - Rules.damage_of(Rules.WOLF),
			"원거리와 근접의 몴이 정확히 둘 다 들어갔다 — 광역이 실제로 터졌다")
	t.eq(army.hp[1], Rules.hp_of(Rules.WOLF) - Rules.damage_of(Rules.WOLF),
			"아군 오사 없음 — 광역 반경 안에 선 아군은 들소 몫만 잃었다")
	t.eq(army.hp[0], Rules.hp_of(Rules.CROW), "쏜 병사 자신도 안 다쳤다")


# -- movement --------------------------------------------------------------------------------------

## A ranged soldier walking a one-tile-wide lane at a lion whose detect is 2, so the lion never moves and
## the distance measured at the end is the soldier's own doing. Reach is 5.5; without the stop rule it
## walks all the way into contact and the ranged type stops existing.
##
## ⚠ **Measured at two frame sizes, because the rule is enforced twice.** The frame gate in the movement
## phase and the per-tile break inside the walk are redundant at 0.1 s — a soldier covers 0.4 tiles, so
## deleting the inner break moves the stopping point by nothing at all and a single-frame-size check
## stays green about it. At 0.5 s the same soldier covers two tiles in one call, and only the inner break
## can stop it inside the frame.
func _stops_when_target_is_in_range(t) -> void:
	var fine := _lane_approach(0.1, 60)
	t.eq(fine["lion"], Vector2(18, 2), "탐지 2인 사자는 제자리에 있었다 — 거리는 병사가 만든 것이다")
	t.ok(float(fine["x"]) > 10.0, "병사가 실제로 걸어왔다 (x=%.2f)" % float(fine["x"]))
	t.ok(float(fine["d"]) >= 4.5, "0.1초 프레임 — 사거리에 들어오자 멈췄다 (%.2f칸)" % float(fine["d"]))
	t.ok(float(fine["d"]) <= 6.0, "0.1초 프레임 — 그렇다고 사거리 밖에 멈추지도 않았다 (%.2f칸)" % float(fine["d"]))
	t.ok(float(fine["hp"]) < Rules.hp_of(Rules.LION), "멈춘 자리에서 실제로 쐈다")

	var coarse := _lane_approach(0.5, 12)
	t.ok(float(coarse["d"]) >= 4.9,
			"0.5초 프레임 — 한 프레임에 두 칸을 가도 사거리를 지나치지 않는다 (%.2f칸)" % float(coarse["d"]))
	t.ok(float(coarse["d"]) <= 6.0, "0.5초 프레임 — 그리고 사거리 밖에 서 있지도 않다 (%.2f칸)" % float(coarse["d"]))


# -- death -----------------------------------------------------------------------------------------

## A dead soldier's row stays and never boards again, on this island or the next one.
func _death_is_permanent(t) -> void:
	var army := _army_of([Rules.WOLF, Rules.WOLF])
	army.hp[0] = 1.0
	var b := _battle_of(_lane(), army, [_spawn(LANE_W, Rules.WOLF, 13, 2)])
	_ashore(b, 0, Vector2(12, 2))
	b.begin_frame()
	b.step(TICK_ONE)
	t.eq(army.alive[0], 0, "1 HP 병사가 들소의 3 을 맞고 죽었다")
	t.eq(army.hp[0], 0.0, "죽은 병사의 HP 는 0 으로 잘린다 — 음수 잔액이 남지 않는다")
	t.eq(army.type_id.size(), 2, "죽어도 명부의 줄은 남는다")
	t.eq(b.soldier_state[0], Battle.SoldierState.DEAD, "이번 섬에서 DEAD 로 바뀌었다")
	t.eq(army.living_count(), 1, "살아 있는 병사는 한 명이다")

	# The next island is left in the PLANNING state on purpose: 「a dead soldier never boards again」 is
	# a refusal only the boarding call can be asked, and **that call is `summon` now.**
	#
	# ⚠⚠ **`send` NAMED A BODY AND `summon` NAMES A SLOT, so the question moved and the row moved with
	# it.** The old pair read `send(1, ...) >= 0` and `send(0, ...) == -1`: the caller chose which
	# soldier boarded, and the refusal was aimed at the dead one by id. Nothing chooses by id any more —
	# a press draws from the LIVING half of the slot (`Battle.slot_reserve_ids` ->
	# `Army.living_ids_of_slot`), so the same rule is measured as **what the slot can still supply**:
	# a roster of two rows of one species, one of them dead, fills exactly ONE boat and refuses the
	# second. The dead row sits in the roster the whole time and never reaches the water.
	#
	# ⚠ It is `_port()` and not `_lane()`, and that reason survived the harbour deletion with a new
	# subject. It used to be 「`_lane()` has no harbour」; it is now 「`_lane()` is a one-tile channel,
	# so no water in it is `Rules.SUMMON_BAND_MIN_TILES` hops off the shore」 — every press there is
	# refused for a reason that has nothing to do with death, which is a check passing for the wrong
	# reason either way.
	var next_island := _planning_battle_of(_port(), army, [_spawn(ARENA_W, Rules.WOLF, 18, 9)])
	var sea := _summonable_water_on(next_island)
	# The fixture's own floor, and it is stated HERE because this is the first row in `run()` that
	# summons: a bay holding no water inside the band would redden every summon row in this file at
	# once, and this is the one line that says which of the two things went wrong.
	t.ok(sea >= 0, "픽스처의 만 안에 소환 가능한 물칸이 있다 (자가 점검)")
	t.eq(next_island.soldier_state[0], Battle.SoldierState.DEAD, "다음 섬에서도 예비가 아니라 DEAD 로 선다")
	t.ok(next_island.summon(0, sea) >= 0, "살아남은 병사는 불러낼 수 있다")
	var aboard: Array = (next_island.boats[0] as Dictionary)["soldiers"]
	t.eq(int(aboard[0]), 1, "배에 탄 것은 살아남은 1번이다 — 죽은 0번이 아니다")
	t.eq(next_island.summon(0, sea), -1, "그 칸에 살아 있는 예비가 없으면 두 번째 소환은 거절이다 — 죽은 줄은 칸을 채워 주지 않는다")
	t.eq(next_island.boats.size(), 1, "그 거절은 배를 한 척도 안 늘렸다")


# -- the phase order is a contract -----------------------------------------------------------------

## boats -> landings -> targeting -> movement -> attacks -> deaths -> clock, each seam measured by a
## consequence that only that order produces.
func _phase_order(t) -> void:
	# boats BEFORE landings: a crossing that completes this frame unloads this frame, not next.
	var ferry_army := _army_of([Rules.WOLF])
	var ferry := _planning_battle_of(_port(), ferry_army, [_spawn(ARENA_W, Rules.LION, 20, 9)])
	# ⚠⚠ **ONE ASSERTION WAS DELETED HERE, 2026-08-27, AND IT IS THE ONLY ONE IN THIS FILE WHOSE
	# SUBJECT WAS THE HARBOUR ITSELF.** It read 「부두 없는 항구에서도 배가 뜬다」 — a `send` onto a beach
	# whose origin harbour `grid.home_harbour_for` derived, on a `_port()` whose single `H` tile has no
	# dock tile beside it. **`send`, `home_harbour_for` and the dock table are all deleted**, and a
	# summon has no harbour at all to be dockless with: the press is on open water inside the band and
	# the landing is derived from the press. ⇒ **There is nothing left for that sentence to be about.**
	# What it knew and what outlives it: **a departure must not need a second tile's blessing**, which
	# `summon` now satisfies by construction rather than by measurement here — `net_summon` owns the
	# grid with zero harbour tiles that says so, and that is where a reader should go looking.
	var sea := _summonable_water_on(ferry)
	t.ok(ferry.summon(0, sea) >= 0, "만 안쪽 물칸을 눌러 배 한 척을 띄웠다 (자가 점검)")
	t.ok(ferry.commit(), "그리고 시작 버튼이 그 배를 실제로 출발시킨다 (자가 점검)")
	# ⚠ **Driven one sub-step at a time, never as one coarse `step(dist / speed)`.** A coarse call
	# stops a sub-step short: `_substep_acc` subtracts the sub-step repeatedly and the last residue
	# lands a hair under it in IEEE double, so this row would read as "it did not unload" when what it
	# measured was floating point.
	#
	# ⚠⚠ **RE-MEASURED A THIRD TIME, 2026-08-27, AND THE ARRIVAL SUB-STEP IS NO LONGER A LITERAL.**
	# The two earlier figures were the harbour route's: `4 x sqrt(2) = 5.656854` off the raw hop-count
	# field, then `sqrt(10) + sqrt(2) = 4.576491` once the smoother string-pulled it, arriving on 69.
	# **Both were `grid.water_route`'s, which is deleted**, and the summon route is a different walk:
	# it descends `summon_hops` from the pressed tile `(2,5)` rather than climbing to a harbour, the
	# smoother pulls `(2,5) (1,4) (0,3)` straight, and `summon_landing_of` beaches it at `(1,2)` — so
	# the crossing is `2 x sqrt(2) + sqrt(2) = 3 x sqrt(2) = 4.242641` tiles, `63.640` sub-steps,
	# arrival on **64**.
	#
	# ⚠⚠ **THE LITERAL AND THE SEAM ARE NOW TWO SEPARATE ASSERTIONS, ON PURPOSE.** The route moved
	# three times in five days and each move silently invalidated the loop count below it — a row that
	# reddens on the count alone cannot tell 「the route changed」 from 「the phase order broke」, which
	# are opposite verdicts. So the literal is a SELF-CHECK that names the route, and the arrival
	# sub-step is DERIVED from the boat's own `dist` and `speed` against `_arrived`'s own test
	# (`t * speed + EPS >= dist`). ⚠ The derivation is not a restatement of the phase order: swap
	# `_phase_landings` in front of `_phase_boats` and the unload slips to the sub-step AFTER this one,
	# which is exactly what the pair below refuses.
	var dist: float = float(ferry.boats[0]["dist"])
	var per_substep: float = float(ferry.boats[0]["speed"]) * Rules.SIM_SUBSTEP_SEC
	t.ok(absf(dist - 4.242641) <= 1e-5,
			"이 항로는 정확히 3 x sqrt(2) = 4.242641칸이다 (자가 점검 — 소환 항로가 움직이면 여기가 먼저 빨개진다)")
	var arrive := int(ceil((dist - Rules.EPS) / per_substep))
	t.eq(arrive, 64, "곧 64번째 서브스텝에 닿는다 (자가 점검 — 63.640 서브스텝짜리 항해다)")
	for _i in arrive - 1:
		ferry.begin_frame()
		ferry.step(TICK_ONE)
	t.eq(ferry.soldier_state[0], Battle.SoldierState.TRANSIT,
			"닿기 한 서브스텝 전에는 아직 배 위다 (자가 점검)")
	ferry.begin_frame()
	ferry.step(TICK_ONE)
	t.eq(ferry.soldier_state[0], Battle.SoldierState.ASHORE,
			"배가 도착한 그 서브스텝에 내린다 — 보트가 상륙보다 먼저 돈다")

	# targeting BEFORE movement: a soldier picks a target and walks on its very first frame.
	var first_army := _army_of([Rules.CROW])
	var first := _battle_of(_lane(), first_army, [_spawn(LANE_W, Rules.LION, 18, 2)])
	_ashore(first, 0, Vector2(2, 2))
	first.begin_frame()
	first.step(0.1)
	t.eq(first.soldier_target[0], 0, "첫 프레임에 표적을 잡았다")
	t.ok(first.soldier_pos[0].x > 2.0, "그리고 같은 프레임에 걸었다 — 타겟팅이 이동보다 먼저 돈다")

	# movement BEFORE attacks: the first blow lands the instant movement brings the target into reach.
	var full := Rules.hp_of(Rules.LION)
	t.eq(_lane_march(TICK_ONE), full, "처음엔 4.0 칸이라 못 때린다")
	t.eq(_lane_march(0.7), full - Rules.damage_of(Rules.WOLF),
			"걸어 들어간 그 프레임에 첫 발이 나간다 — 이동이 공격보다 먼저 돈다")

	# attacks BEFORE deaths: two units that finish each other off both land the blow.
	var trade_army := _army_of([Rules.WOLF])
	trade_army.hp[0] = Rules.damage_of(Rules.WOLF)
	var trade := _battle_of(_lane(), trade_army, [_spawn(LANE_W, Rules.WOLF, 13, 2)])
	trade.enemy_hp[0] = Rules.damage_of(Rules.WOLF)
	_ashore(trade, 0, Vector2(12, 2))
	trade.begin_frame()
	trade.step(TICK_ONE)
	t.eq(trade.enemy_alive[0], 0, "동시에 끝난 교환 — 들소가 죽었다")
	t.eq(trade_army.alive[0], 0, "그리고 들소도 마지막 한 방을 쳤다 — 공격이 사망보다 먼저 돈다")

	# deaths BEFORE the clock, and WON before either loss: an island cleared on the expiring frame is a win.
	var wire_army := _army_of([Rules.WOLF])
	var wire := _battle_of(_lane(), wire_army, [_spawn(LANE_W, Rules.WOLF, 13, 2)])
	wire.enemy_hp[0] = Rules.damage_of(Rules.WOLF)
	_ashore(wire, 0, Vector2(12, 2))
	wire.begin_frame()
	wire.step(0.5)
	t.eq(wire.outcome(), Battle.Outcome.WON, "타이머가 끝나는 그 프레임에 비운 섬은 승리다")
	t.eq(wire.lose_reason(), Battle.Lose.NONE, "승리에는 패배 사유가 없다")

	# ... and the timeout arm is live, so the win above is not "the clock never fires".
	var late_army := _army_of([Rules.WOLF])
	var late := _battle_of(_lane(), late_army, [_spawn(LANE_W, Rules.WOLF, 13, 2)])
	_ashore(late, 0, Vector2(12, 2))
	late.begin_frame()
	late.step(0.5)
	# ⚠⚠ **INVERTED, 2026-08-24** (the user: 「제한 시간 안에 클리어 조건은 일단 지워」). This pair used
	# to assert the timeout arm was live. It is gone, and the check is kept POINTING THE OTHER WAY
	# rather than deleted: 「the clock does not decide」 is a rule, and a rule with nothing measuring it
	# comes back by accident.
	t.eq(late.outcome(), Battle.Outcome.RUNNING, "시간이 다 가도 지지 않는다 — 시계는 판정하지 않는다")
	t.eq(late.lose_reason(), Battle.Lose.NONE, "그러므로 패배 사유도 없다")


# -- the run ends when nobody is left in the fight -------------------------------------------------

## ⚠⚠ **THE USER SAT WATCHING AN EMPTY ISLAND UNTIL THE TIMER RAN OUT**, and reported it:
## ***"실패조건은 시작하기하고 못깨면 이지 제한시간을 계속 기다리고 있길래"***.
##
## `_phase_clock` lost on `army.living_count() == 0`, and `living_count` counts every soldier that is
## not dead — **every unsummoned reserve included.** After the commit the boarding call refuses
## everything, so a reserve can never be landed: hold anyone back, lose everyone you put ashore, and
## the run is decided and cannot end. The old test could not fire at all.
## ⚠ **That sentence used to say 「reserves at the harbour」 and there is no harbour** (2026-08-27):
## a reserve now stands nowhere at all — `setup` parks it at `OFFMAP` — until a press on the water
## draws it out of its slot. The RULE is untouched; only where the held-back body is imagined to be
## standing has gone.
##
## ⚠ **The margin is the whole check.** `elapsed <= time_limit` was also true of the behaviour being
## fixed — that is `how-nets-lie`'s *a ceiling with no floor* exactly — so this asserted the GAP to a
## 90 s limit rather than the elapsed time alone.
## ⚠⚠ **THE LIMIT WAS DELETED 2026-08-27 AND THE FLOOR IS WHAT SURVIVED IT.** With no clock to run
## out, the gap has nothing to be a gap FROM; what still says the island ended early is the pair of
## bounds below — the fight really ran (`elapsed > 0`) and it was over inside two seconds against a
## crossing of about 1.06 (**it was 1.14 under the deleted harbour route**, and the two-second ceiling
## was chosen wide enough that the change did not move it). **The ceiling went, the floor stayed**,
## which is the right half to keep.
##
## ⚠ **And `living_count() == 2` is the floor under it.** Two soldiers are still alive when the island
## is lost. Restore the old condition and that is the line that cannot be satisfied.
func _reserves_do_not_hold_the_run_open(t) -> void:
	var army := _army_of([Rules.WOLF, Rules.WOLF, Rules.WOLF])
	var b := _planning_battle_of(_port(), army, [_spawn(ARENA_W, Rules.WOLF, 20, 1)])
	var sea := _summonable_water_on(b)
	t.ok(b.summon(0, sea) >= 0, "셋 중 한 명만 불러냈다 (자가 점검)")
	t.ok(b.commit(), "그리고 시작을 눌렀다 (자가 점검)")
	# ⚠ **Which of the three boards is `slot_reserve_ids`' choice and not this fixture's** — the slot's
	# living reserves, lowest HP first and ties to the lower id, so three untouched wolves hand over 0.
	# The two rows below are what say so; nothing here names a body.
	t.eq(b.soldier_state[1], Battle.SoldierState.RESERVE, "1번은 예비로 남았다 (자가 점검)")
	t.eq(b.soldier_state[2], Battle.SoldierState.RESERVE, "2번도 남았다 (자가 점검)")
	# The premise, asserted rather than assumed: a reserve can never join the fight after the commit,
	# which is what makes holding one back a decision that is already over.
	t.eq(b.summon(0, sea), -1, "확정 뒤에는 남은 병사를 못 불러낸다 — 이 검사의 전제다")

	var n := 0
	while n < 400 and b.soldier_state[0] != Battle.SoldierState.ASHORE:
		b.begin_frame()
		b.step(TICK_ONE)
		n += 1
	t.eq(b.soldier_state[0], Battle.SoldierState.ASHORE, "보낸 한 명이 상륙했다 (%d 서브스텝)" % n)
	t.eq(b.outcome(), Battle.Outcome.RUNNING, "아직 굴러간다 (자가 점검)")

	# It dies. `army.hp = 0` and one sub-step, so `_phase_deaths` writes DEAD the way the fight does —
	# never by poking `soldier_state` here, which would make this a check about the poke.
	army.hp[0] = 0.0
	b.begin_frame()
	b.step(TICK_ONE)
	t.eq(b.soldier_state[0], Battle.SoldierState.DEAD, "그리고 죽었다 (자가 점검)")

	t.eq(b.outcome(), Battle.Outcome.LOST, "상륙한 병사가 다 죽으면 그 자리에서 진다")
	t.eq(b.lose_reason(), Battle.Lose.LANDING_LOST,
		"패인은 전멸이 아니라 상륙 실패다 — 아직 안 불러낸 산 병사가 남아 있다")
	t.ok(b.enemies_left() > 0, "적은 아직 남아 있다 — 승리와 헷갈릴 여지가 없다 (%d마리)" % b.enemies_left())
	# ⚠⚠ **THE LINE THE OLD RULE CANNOT PASS.**
	t.eq(army.living_count(), 2, "그런데 병사는 아직 둘이 살아 있다 — 한 번도 안 불러낸 예비 병력이다")
	# The margin. Both ends: the fight really ran, and it ended nowhere near the clock.
	t.ok(b.elapsed > 0.0, "시계는 실제로 돌았다 (%.4f초)" % b.elapsed)
	t.ok(b.elapsed < 2.0,
		"그런데 2초도 안 걸렸다 (%.4f초) — 건너는 데 약 1.06초다. 기다릴 것이 없어졌으면 기다리지 않는다"
			% b.elapsed)


## ⚠⚠ **THE COUNTER-CASE, and it is where the fix breaks silently if it is written as ASHORE-only.**
## A soldier aboard an OUTBOUND boat has not landed and has not lost. Collapse the rule to "nobody
## ashore" and the last crossing on an island whose beachhead just died is thrown away one sub-step
## before it resolves — a fake failure, and one the player would read as the game giving up on them.
func _a_soldier_at_sea_does_hold_it_open(t) -> void:
	var army := _army_of([Rules.WOLF, Rules.WOLF, Rules.WOLF])
	var b := _planning_battle_of(_port(), army, [_spawn(ARENA_W, Rules.WOLF, 20, 1)])
	var sea := _summonable_water_on(b)
	# ⚠ **Two presses on the SAME water tile, and each is its own statement.** They were one `and`ed
	# line under `send`; a short-circuit there would have hidden a refused second boat behind a true
	# first, and with `summon` the second press is the interesting one — it must draw the NEXT living
	# reserve of the slot rather than the body already aboard.
	t.ok(b.summon(0, sea) >= 0, "한 명을 불러냈다 (자가 점검)")
	t.ok(b.summon(0, sea) >= 0, "같은 물칸에서 한 명 더 불러냈다 (자가 점검)")
	t.eq(b.boats.size(), 2, "배가 두 척 떴다 — 둘째 소환이 첫째를 덮어쓰지 않았다 (자가 점검)")
	t.ok(b.commit(), "2번은 예비로 남긴 채 시작했다 (자가 점검)")

	# Five sub-steps in, both are still at sea — the crossing is sixty-four of them.
	for _f in 5:
		b.begin_frame()
		b.step(TICK_ONE)
	t.eq(b.soldier_state[0], Battle.SoldierState.TRANSIT, "0번은 아직 바다 위다 (자가 점검)")
	t.eq(b.soldier_state[1], Battle.SoldierState.TRANSIT, "1번도 바다 위다 (자가 점검)")

	army.hp[0] = 0.0
	b.begin_frame()
	b.step(TICK_ONE)
	t.eq(b.soldier_state[0], Battle.SoldierState.DEAD, "0번이 바다에서 죽었다 (자가 점검)")
	t.eq(b.soldier_state[1], Battle.SoldierState.TRANSIT, "1번은 여전히 건너는 중이다")
	t.eq(b.outcome(), Battle.Outcome.RUNNING,
		"아무도 뭍에 없어도 배 위에 한 명이 있으면 아직 안 졌다 — 마지막 항해가 남았다")

	# And then it lands, so the RUNNING above is not "this fixture can never end".
	var n := 0
	while n < 400 and b.soldier_state[1] != Battle.SoldierState.ASHORE:
		b.begin_frame()
		b.step(TICK_ONE)
		n += 1
	t.eq(b.soldier_state[1], Battle.SoldierState.ASHORE, "1번이 상륙했다 (%d 서브스텝 더)" % n)
	t.eq(b.outcome(), Battle.Outcome.RUNNING, "상륙한 뒤에도 계속 굴러간다")

	army.hp[1] = 0.0
	b.begin_frame()
	b.step(TICK_ONE)
	t.eq(b.outcome(), Battle.Outcome.LOST, "그 마지막 한 명까지 죽고 나서야 진다")
	t.eq(b.lose_reason(), Battle.Lose.LANDING_LOST, "패인은 상륙 실패다 — 2번이 아직 살아 있다")
	t.eq(army.living_count(), 1, "한 번도 안 불러낸 2번은 그때도 살아 있다")


## ⚠⚠ **BOTH LOSS REASONS ARE TRUE AT ONCE HERE, AND THE PRECEDENCE IS THE CHECK.** Summon everybody,
## kill everybody: the landing force is gone AND every soldier is dead. `WIPED` wins, because "every
## soldier is dead" is the stronger claim and the more useful one to read. **An unstated precedence is
## what diverges later** — a reader of `_phase_clock` who reordered the two would break nothing that
## anyone could see, because both arms end the island.
##
## ⚠ The floor beside it is the round-4 fixture two functions up, which reaches the SAME condition and
## must answer `LANDING_LOST`. Neither reason is reachable-by-default: one holds reserves back and one
## does not, and that single difference is the whole of what the screen now says.
func _wiped_wins_when_both_are_true(t) -> void:
	var army := _army_of([Rules.WOLF, Rules.WOLF])
	var b := _planning_battle_of(_port(), army, [_spawn(ARENA_W, Rules.WOLF, 20, 1)])
	var sea := _summonable_water_on(b)
	t.ok(b.summon(0, sea) >= 0, "한 명을 불러냈다 (자가 점검)")
	t.ok(b.summon(0, sea) >= 0, "둘 다 불러냈다 — 예비에 아무도 안 남는다 (자가 점검)")
	# The floor under 「nobody is left behind」: with the slot emptied a third press must be refused,
	# and without this line the row is also satisfied by a slot that only ever handed over one body.
	t.eq(b.summon(0, sea), -1, "그리고 세 번째 소환은 거절이다 — 칸이 실제로 비었다 (자가 점검)")
	t.ok(b.commit(), "그리고 시작을 눌렀다 (자가 점검)")
	for _f in 5:
		b.begin_frame()
		b.step(TICK_ONE)
	army.hp[0] = 0.0
	army.hp[1] = 0.0
	b.begin_frame()
	b.step(TICK_ONE)

	t.eq(army.living_count(), 0, "병사가 하나도 안 남았다 (자가 점검)")
	t.eq(b.outcome(), Battle.Outcome.LOST, "그래서 졌다 (자가 점검)")
	t.eq(b.lose_reason(), Battle.Lose.WIPED,
		"두 조건이 다 참일 때는 전멸이 이긴다 — 「병사가 다 죽었다」가 「상륙 부대가 없어졌다」보다 큰 말이다")


## ⚠⚠ **THE GATE, driven directly, because `step` hides it.** `step` returns before `_phase_clock`
## while uncommitted, so the `_committed` test inside `_the_landing_force_is_gone` is unreachable
## through the public path today — and an unreachable guard is exactly the kind that gets deleted as
## dead code by the next person. Every soldier is RESERVE during planning, so without it an island is
## lost on the frame it opens.
func _the_gate_itself(t) -> void:
	var army := _army_of([Rules.WOLF, Rules.WOLF])
	var b := _planning_battle_of(_port(), army, [_spawn(ARENA_W, Rules.WOLF, 20, 1)])
	t.eq(b.soldier_state[0], Battle.SoldierState.RESERVE, "계획 중에는 전원이 RESERVE 다 (자가 점검)")
	t.eq(b.soldier_state[1], Battle.SoldierState.RESERVE, "둘 다 그렇다 (자가 점검)")
	t.ok(not b._the_landing_force_is_gone(),
		"확정 전에는 전원이 RESERVE 여도 '병력이 없어졌다'가 아니다 — 게이트가 없으면 섬이 열리자마자 진다")

	# The same roster with the flag flipped: now it IS gone. Without this line the row above would
	# also be green if the function simply always answered false.
	b._committed = true
	t.ok(b._the_landing_force_is_gone(),
		"같은 명부라도 확정 뒤에는 '병력이 없어졌다'가 된다 — 게이트가 읽는 것은 _committed 하나다")


# -- the boat is cargo, not a fighting position ----------------------------------------------------

## A soldier still aboard is shot at and cannot shoot back, and the enemies that CAN walk stay put,
## because chasing a target standing on water asks `flow_field` for a path to an impassable tile.
##
## ⚠ **Pinned from both sides, per `boat-and-landing` 4.7 / 8.6 — and pinned so the two sides cannot
## collapse into the same final state.** An earlier version of this fixture gave the bison ONLY the
## boat in range: under the correct rule it has no valid target and stands; under an
## `ashore_only = true -> false` mutation it targets the boat, asks `flow_field` for a path to a water
## tile, gets `UNREACHABLE` everywhere, and `step_toward` returns its own position — so it ALSO stands,
## at the exact same tile. "Excluded from the scan" and "frozen by an unreachable field" read
## identically in final position, and the mutation stayed green.
##
## The bison below has BOTH a boat (nearer, moving) and a real ashore soldier (farther, at a NAMED
## tile) inside its detect radius at once. Under the correct rule it can only ever see the ashore
## soldier and walks toward THAT tile. Under the mutation the boat is nearer than the ashore soldier
## for the whole window, so the bison targets it instead, asks `flow_field` for a path to water, and
## freezes at its start tile — two different, checkable outcomes, not the same one twice.
##
## ⚠⚠ **THE WHOLE ARRANGEMENT WAS RE-MEASURED 2026-08-27, BECAUSE THE CROSSING MOVED.** `send` sailed
## from the `H` tile at (2,5) EAST to the beach at (6,5), straight across the middle of the map, and
## the bison stood at (7,4) reading ~4.8 tiles to the boat against the ashore soldier's constant 5.0.
## **`summon` sails the other way**: the press lands on (2,5) — the only band tile this bay holds with
## a lower index than (3,5) — and `summon_landing_of` beaches it at (1,2), so the boat runs NORTH-WEST
## into the corner and away from (7,4) entirely. At (7,4) the boat ends the window 8.8 tiles off, past
## the bison's detect 6 and FARTHER than the ashore soldier — **the mutation would have stopped biting
## while every assertion below stayed green.** ⇒ **The bison moved to (2,8)**, under the corner the
## boat now sails into.
##
## ⚠ **The two distances, measured on the new route** (boat speed 4.0, so 0.3 s is 1.2 tiles along
## `(2,5) -> (0,3)`): the bison reads **3.00 tiles to the boat at the first sub-step and 3.94 at the
## last**, against **5.10 tiles to the ashore soldier**, which does not move. Both are inside its
## detect 6, and the boat is the nearer of the two at every sub-step of the window — which is the one
## property the mutation needs in order to bite.
##
## ⚠ **The ashore soldier is RANGED, not melee, and that is load-bearing.** A melee ashore soldier
## advances on ITS OWN nearest enemy — this bison — independent of anything under test here, which
## moves the "static, named tile" the assertions below are built on and corrupted an earlier draft of
## this fixture (measured: a melee stand-in closed enough distance in 0.3s to occasionally overtake the
## boat as nearest even under the CORRECT rule, and the check passed by accident). Placed within its
## own 5.75-tile reach of the bison, a ranged soldier stops and shoots instead of walking, so it never
## moves at all. ⚠⚠ **That fixed point is now ASSERTED and not assumed** — the row below reads the
## ashore soldier's position back, because every distance in this function is measured from it and a
## silent drift would leave the whole arrangement looking correct.
func _in_transit_is_hit_but_cannot_hit(t) -> void:
	var army := _army_of([Rules.CROW, Rules.CROW])
	var b := _planning_battle_of(_port(), army, [
		_spawn(ARENA_W, Rules.CROW, 3, 2),   # 3.16 tiles from the boat at the press, inside its 5.75
		_spawn(ARENA_W, Rules.WOLF, 2, 8),   # sees BOTH the boat and the ashore soldier below
	])
	var ashore_target := Vector2(7, 9)   # 5.10 tiles from the bison, inside its detect 6 and inside
	                                      # the ranged soldier's own 5.75 reach of it — so it stops
	_ashore(b, 1, ashore_target)
	var bison_start: Vector2 = b.enemy_pos[1]
	# ⚠ **The ashore soldier is placed BEFORE the press, and the order is load-bearing.** `summon`
	# draws from `slot_reserve_ids`, which is the slot's RESERVE bodies — soldier 1 is already ashore
	# by this line, so the one who boards is soldier 0 without this fixture naming him.
	var sea := _summonable_water_on(b)
	b.summon(0, sea)
	b.commit()
	for _f in 3:
		b.begin_frame()
		b.step(0.1)
	t.eq(b.soldier_state[0], Battle.SoldierState.TRANSIT, "병사는 아직 배 위다")
	t.ok(b.is_hittable(0), "배 위의 병사는 맞을 수 있다")
	t.eq(army.hp[0], Rules.hp_of(Rules.CROW) - Rules.damage_of(Rules.CROW),
			"까마귀가 배 위의 병사를 실제로 쐈다")
	t.eq(b.enemy_hp[0], Rules.hp_of(Rules.CROW), "배 위의 병사는 사거리 안이어도 못 때린다")
	t.eq(b.soldier_pos[1], ashore_target,
			"상륙해 있는 병사는 한 발짝도 안 움직였다 — 아래 거리들이 재는 기준점이다 (자가 점검)")
	t.ok(b.enemy_pos[1].distance_to(bison_start) > 0.1,
			"그리고 들소는 실제로 움직였다 (%.2f칸) — 배를 쫓다 얼어붙은 게 아니라는 증거다"
			% b.enemy_pos[1].distance_to(bison_start))
	t.ok(b.enemy_pos[1].distance_to(ashore_target) < ashore_target.distance_to(bison_start) - 0.3,
			"움직인 방향이 상륙한 병사 쪽이다 (남은 거리 %.2f칸, 시작 5.10칸) — 배 쪽으로 얼어붙지 않고 이름 붙은 그 칸을 향해 실제로 걸었다는 뜻이다"
			% b.enemy_pos[1].distance_to(ashore_target))


# -- ticket 11: statuses — the table rows reach the fight, measured through step -------------------

## Fixture item ids, pinned with what each is for and asserted below to carry that tag.
## ⚠ **The boards they land on are BEAR's and COW's** — player species nobody summons yet — so the items' own
## stat columns cannot move the melee/ranged arithmetic every expectation below is built from, and the
## rows double as "the count is army-wide" measured through the fight.
const ITEM_BLEED := 7    # 부싯돌 이빨 — 출혈 딱지, 문턱 3 (0.5/초 · 2초)
const ITEM_SLOW := 1     # 돌 목걸이 — 디버프(감속) 딱지, 문턱 2 (이동속도 70% · 2초)


## `n` copies of `item` onto `beast_type`'s board, through the real take/fit path.
func _worn(a: Army, item: int, n: int, beast_type: int) -> void:
	for _i in n:
		a.loadout.take_card(item)
		a.loadout.fit(beast_type, 0)


## One melee soldier adjacent to one bison, with `bleed_items` copies of the bleed item on the crow's
## board, driven exactly one sub-step — the blow lands (and, when the tier is lit, the bleed with it).
func _bled_bison_battle(bleed_items: int) -> Battle:
	var army := _army_of([Rules.WOLF])
	_worn(army, ITEM_BLEED, bleed_items, Rules.BEAR)
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [_spawn(ARENA_W, Rules.WOLF, 12, 5)])
	_ashore(b, 0, Vector2(11, 5))
	b.begin_frame()
	b.step(TICK_ONE)
	return b


## 「층이 켜진 채 한 대 맞은 적은 손이 떨어져도 피가 흐른다」. Mutation: delete the DOT arm of
## `_phase_status`. ⚠ 기대값 0.5/초는 리터럴이다 — 표를 되읽으면 검사가 표와 같이 움직인다.
func _bleed_drips_after_the_blow(t) -> void:
	var b := _bled_bison_battle(3)
	t.eq(b.army.loadout.tag_count(Rules.Tag.BLEED), 3, "출혈 딱지가 셋이다 (자가 점검)")
	var after_blow := b.enemy_hp[0]
	t.ok(after_blow < Rules.hp_of(Rules.WOLF), "첫 타격이 실제로 들어갔다 (자가 점검)")
	# 30 sub-steps with the hand off: the cooldown is 1.0 s, so no second blow can land inside them.
	for _f in 30:
		b.begin_frame()
		b.step(TICK_ONE)
	var drained := after_blow - b.enemy_hp[0]
	t.ok(absf(drained - 0.5 * 30.0 / 60.0) <= 1e-3,
		"손이 떨어진 30 서브스텝 동안 피가 초당 0.5 로 흘렀다 (%.4f칸)" % drained)
	t.eq(b.enemy_alive[0], 1, "그리고 그 출혈로는 아직 안 죽었다 (자가 점검)")


## 「층이 꺼져 있으면 출혈 0」 — 딱지 둘은 문턱 셋 미달이고, 전투를 지나도 아무것도 흐르지 않는다.
func _bleed_off_below_threshold(t) -> void:
	var b := _bled_bison_battle(2)
	t.eq(b.army.loadout.tag_count(Rules.Tag.BLEED), 2, "출혈 딱지가 둘뿐이다 (자가 점검)")
	var after_blow := b.enemy_hp[0]
	t.ok(after_blow < Rules.hp_of(Rules.WOLF), "타격 자체는 들어갔다 (자가 점검)")
	for _f in 30:
		b.begin_frame()
		b.step(TICK_ONE)
	t.eq(b.enemy_hp[0], after_blow, "문턱 미달이면 타격 뒤에 아무것도 흐르지 않는다")


## 「두 대 맞아도 크기가 안 는다」 — 갱신이지 누적이 아니다. 두 번째 타격(약 61 서브스텝) 뒤의 흐름이
## 여전히 초당 0.5 다. Mutation: make the status write ADD the magnitude instead of overwriting it.
func _bleed_refreshes_and_never_stacks(t) -> void:
	var b := _bled_bison_battle(3)
	# through sub-step 70 — the second blow lands at ~61, the third at ~121.
	for _f in 69:
		b.begin_frame()
		b.step(TICK_ONE)
	var hits := Rules.hp_of(Rules.WOLF) - b.enemy_hp[0]
	t.ok(hits > 2.0 * Rules.damage_of(Rules.WOLF),
		"두 번째 타격이 실제로 들어갔다 (자가 점검 — 깎인 피 %.3f > 직격 두 방)" % hits)
	var at70 := b.enemy_hp[0]
	for _f in 30:
		b.begin_frame()
		b.step(TICK_ONE)
	var drained := at70 - b.enemy_hp[0]
	t.ok(absf(drained - 0.5 * 30.0 / 60.0) <= 1e-3,
		"두 대 맞은 뒤에도 흐름은 초당 0.5 그대로다 — 크기는 갱신이지 누적이 아니다 (%.4f칸)" % drained)


## 「출혈로 죽은 적이 같은 서브스텝의 죽음 처리를 지난다」 — alive 가 그 서브스텝에 꺼지고 DEATH 가
## 그 프레임의 events 에 실린다. Mutation: move `_phase_status` after `_phase_deaths`.
func _bleed_death_passes_the_same_substep(t) -> void:
	var b := _bled_bison_battle(3)
	# under one sub-step's drip (0.5/60 ≈ 0.0083), and the soldier's cooldown blocks a direct blow.
	b.enemy_hp[0] = 0.004
	b.begin_frame()
	b.step(TICK_ONE)
	t.eq(b.enemy_alive[0], 0, "출혈만으로 그 서브스텝에 죽었다 — 지속피해가 죽음 처리보다 먼저 돈다")
	var saw := false
	for ev in b.events:
		if int(ev["kind"]) == Battle.Event.DEATH and bool(ev["is_enemy"]) and int(ev["id"]) == 0:
			saw = true
	t.ok(saw, "그리고 그 프레임의 events 에 DEATH 가 실렸다")


## 「상태는 광역의 형제에게도 실린다」 — both status fixtures above are single-target, so the splash
## arm of the apply walk had no row of its own. A ranged blow catches an orthogonal sibling inside its
## 1.0 area, and the sibling bleeds like the primary. Mutation: delete the splash loop in
## `_apply_statuses`.
## ⚠⚠ **THE SHOOTER IS THE BEAR AND THAT IS THE WHOLE OF WHY THIS ROW MEASURES ANYTHING.** It was the
## 까마귀, which used to carry a bleed of its own through `Rules.SPECIES_STATUS`, and **deleting the
## splash arm of the tag loop entirely left this row GREEN**: the species table re-supplied identical
## values through the other door. **Measured — the named mutation did not bite.** The bear splashes
## (`area` 1.5) and has no passive of any kind, so the equipment tag is the only source that can reach
## the sibling. ⚠⚠ **`SPECIES_STATUS` is deleted (2026-08-27) and this row keeps the bear anyway**: the
## rule it taught is 「a fixture whose subject has a SECOND source of the thing being measured measures
## nothing」, and the next passive to arrive would silently re-arm the same hole here.
func _status_rides_the_splash(t) -> void:
	var army := _army_of([Rules.BEAR])
	_worn(army, ITEM_BLEED, 3, Rules.SWORDSMAN)
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [
		_spawn(ARENA_W, Rules.WOLF, 12, 5),   # primary, 1.0 from the soldier
		_spawn(ARENA_W, Rules.WOLF, 13, 5),   # orthogonal sibling — inside the 1.5 splash
	])
	_ashore(b, 0, Vector2(11, 5))
	b.begin_frame()
	b.step(TICK_ONE)
	var sib: float = b.enemy_hp[1]
	t.ok(sib < Rules.hp_of(Rules.WOLF), "광역이 형제도 실제로 때렸다 (자가 점검)")
	# 30 sub-steps with the hand off: the bear's cooldown is 1.8 s, so no second blow lands.
	for _f in 30:
		b.begin_frame()
		b.step(TICK_ONE)
	var drained: float = sib - b.enemy_hp[1]
	t.ok(absf(drained - 0.5 * 30.0 / 60.0) <= 1e-3,
		"광역에 맞은 형제에게도 출혈이 흐른다 (%.4f칸) — 상태는 주 표적만의 것이 아니다" % drained)


## A ranged soldier at (4,5) and a bison at (9,5): the gap 5.0 is inside the soldier's 5.5 reach (the
## blow lands on sub-step 1) and inside the bison's detect 6 (it walks). Distance TRAVELLED is summed
## per sub-step, so a flow-field zigzag cannot shrink what is measured. Returns tiles travelled over
## the 30 sub-steps AFTER the blow landed.
func _slow_probe(slow_items: int) -> float:
	var army := _army_of([Rules.CROW])
	_worn(army, ITEM_SLOW, slow_items, Rules.SWORDSMAN)
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [_spawn(ARENA_W, Rules.WOLF, 9, 5)])
	_ashore(b, 0, Vector2(4, 5))
	b.begin_frame()
	b.step(TICK_ONE)
	var travelled := 0.0
	var prev: Vector2 = b.enemy_pos[0]
	for _f in 30:
		b.begin_frame()
		b.step(TICK_ONE)
		travelled += prev.distance_to(b.enemy_pos[0])
		prev = b.enemy_pos[0]
	return travelled


## 「층이 켜진 채 맞은 적은 한 서브스텝에 덜 걷는다」 — 같은 fixture 를 딱지 0개와 2개로 돌려 겉는
## 거리를 잰다. ⚠ 배율 0.7 은 리터럴이다. Mutation: drop the slow multiplier from `_phase_movement`.
func _slow_makes_the_hit_enemy_walk_less(t) -> void:
	var plain := _slow_probe(0)
	var slowed := _slow_probe(2)
	t.ok(absf(plain - Rules.speed_of(Rules.WOLF) * 30.0 / 60.0) <= 0.02,
		"안 맞은 들소는 30 서브스텝에 제 속도 그대로 걷는다 (자가 점검, %.3f칸)" % plain)
	t.ok(absf(slowed - 0.7 * Rules.speed_of(Rules.WOLF) * 30.0 / 60.0) <= 0.02,
		"감속 걸린 들소는 그 70%% 만 걷는다 (%.3f칸)" % slowed)


## 「시간이 다하면 원래 속도로 돌아온다」. The shooter dies right after the blow so nothing can
## refresh; a second ranged soldier is parked where the bison keeps walking, and HIS trigger finger is
## pinned on a second bison inside his own reach, so no friendly blow ever lands on the measured one.
## Mutation: make the slow permanent (drop the time check from the multiplier).
func _slow_expires_back_to_full_speed(t) -> void:
	var army := _army_of([Rules.CROW, Rules.CROW])
	_worn(army, ITEM_SLOW, 2, Rules.SWORDSMAN)
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [
		_spawn(ARENA_W, Rules.WOLF, 12, 5),   # 0 — the measured one, slowed once then left alone
		_spawn(ARENA_W, Rules.WOLF, 6, 9),    # 1 — soldier 1's pinned target, 4.0 from him
	])
	_ashore(b, 0, Vector2(9, 5))   # the shooter: 3.0 from bison 0 — its nearest, inside 5.5
	_ashore(b, 1, Vector2(6, 5))   # the bait: bison 1 at 4.0 is his nearest and inside his reach
	b.begin_frame()
	b.step(TICK_ONE)
	t.ok(b.enemy_hp[0] < Rules.hp_of(Rules.WOLF), "0번 들소가 한 대 맞았다 (자가 점검)")
	b.army.hp[0] = 0.0   # the shooter dies — nothing refreshes the slow again
	# sub-steps 2..89: the shooter's death latches, bison 0 walks west toward soldier 1, slowed.
	for _f in 88:
		b.begin_frame()
		b.step(TICK_ONE)
	t.eq(b.soldier_state[0], Battle.SoldierState.DEAD, "쏜 병사는 죽었다 (자가 점검)")
	t.eq(b.soldier_pos[1], Vector2(6, 5), "미끼 병사는 제자리다 (자가 점검 — 제 사거리 안 표적을 쏜다)")
	# slowed window, sub-steps 90..107 (the slow runs out at ~121).
	var travelled := 0.0
	var prev: Vector2 = b.enemy_pos[0]
	for _f in 18:
		b.begin_frame()
		b.step(TICK_ONE)
		travelled += prev.distance_to(b.enemy_pos[0])
		prev = b.enemy_pos[0]
	t.ok(absf(travelled - 0.7 * Rules.speed_of(Rules.WOLF) * 18.0 / 60.0) <= 0.02,
		"감속이 살아 있는 동안은 70%% 로 걷는다 (자가 점검, %.3f칸)" % travelled)
	# through sub-step 121, where the 2.0 s run out.
	for _f in 14:
		b.begin_frame()
		b.step(TICK_ONE)
	# full-speed window, sub-steps 122..139 — it stops at reach of the bait only past ~145.
	travelled = 0.0
	prev = b.enemy_pos[0]
	for _f in 18:
		b.begin_frame()
		b.step(TICK_ONE)
		travelled += prev.distance_to(b.enemy_pos[0])
		prev = b.enemy_pos[0]
	t.ok(absf(travelled - Rules.speed_of(Rules.WOLF) * 18.0 / 60.0) <= 0.02,
		"시간이 다하면 원래 속도로 돌아온다 (%.3f칸)" % travelled)
	t.eq(b.enemy_alive[1], 1, "미끼의 들소도 창 밖에서 살아 있다 (자가 점검 — 표적이 안 바뀌었다)")


## 「다시 맞아도 배율이 안 겹친다」 — 두 번째 타격(~61 서브스텝) 뒤에도 70% 이지, 70%×70%=49% 가
## 아니다. Mutation: make the status write MULTIPLY the magnitude onto the stored one.
func _slow_refreshes_and_never_stacks(t) -> void:
	var army := _army_of([Rules.CROW])
	_worn(army, ITEM_SLOW, 2, Rules.SWORDSMAN)
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [_spawn(ARENA_W, Rules.WOLF, 9, 5)])
	_ashore(b, 0, Vector2(4, 5))
	# through sub-step 69 — the second blow lands at ~61 and refreshes.
	for _f in 69:
		b.begin_frame()
		b.step(TICK_ONE)
	# ⚠⚠ **AN EQUALITY AGAIN SINCE 2026-08-27, AND THE LOOSENING IS WORTH REMEMBERING.** This read
	# `t.ok(hp <= expected + EPS)` for two days: 까마귀 carried an innate bleed (`Rules.SPECIES_STATUS`)
	# that rode its own blow, and `_phase_status` took its first sip inside the SAME sub-step — so the
	# exact figure carried a tick of drip on top. **That table is deleted and the drip with it**, so the
	# blow is once more the only thing that touches this number. ⇒ **A bound loosened to admit a second
	# effect is tightened back the day that effect goes**, or the row quietly stops pinning the blow.
	t.eq(b.enemy_hp[0], Rules.hp_of(Rules.WOLF) - 2.0 * Rules.damage_of(Rules.CROW),
		"타격이 정확히 두 번 들어갔다 (자가 점검)")
	var travelled := 0.0
	var prev: Vector2 = b.enemy_pos[0]
	for _f in 30:
		b.begin_frame()
		b.step(TICK_ONE)
		travelled += prev.distance_to(b.enemy_pos[0])
		prev = b.enemy_pos[0]
	t.ok(absf(travelled - 0.7 * Rules.speed_of(Rules.WOLF) * 30.0 / 60.0) <= 0.02,
		"두 대 맞아도 배율은 70%% 그대로다 — 겹쳐 곱하면 49%% 가 된다 (%.3f칸)" % travelled)


## 「적의 타격은 병사에게 아무 상태도 못 건다」 — 출혈과 감속 두 층이 다 켜진 무리에서, 맞은 병사의
## 피는 흐르지 않고 총 맞은 병사의 걸음은 그대로다. Mutation: apply statuses inside `_hit_soldiers`.
func _enemy_blows_carry_no_status(t) -> void:
	# the bleed half: a melee soldier adjacent to a bison takes its blow, and nothing drips afterwards.
	var army := _army_of([Rules.WOLF])
	_worn(army, ITEM_BLEED, 3, Rules.BEAR)
	_worn(army, ITEM_SLOW, 2, Rules.SWORDSMAN)
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [_spawn(ARENA_W, Rules.WOLF, 12, 5)])
	_ashore(b, 0, Vector2(11, 5))
	b.begin_frame()
	b.step(TICK_ONE)
	var after_blow: float = army.hp[0]
	t.ok(after_blow < Rules.hp_of(Rules.WOLF), "들소의 타격이 들어갔다 (자가 점검)")
	# the bison's period is 2.0 s, so 60 sub-steps hold no second blow.
	for _f in 60:
		b.begin_frame()
		b.step(TICK_ONE)
	t.eq(army.hp[0], after_blow, "맞은 병사의 피는 흐르지 않는다 — 적 타격은 출혈을 못 건다")

	# the slow half: soldier 0 trades blows with the crow (enemy 0), so a SLOW is live at enemy
	# index 0; the crow dies and the soldier walks to the far bison — a soldier/enemy index confusion
	# that read the slow onto the walker would bite exactly here, because the indices coincide.
	var walk_army := _army_of([Rules.WOLF])
	_worn(walk_army, ITEM_BLEED, 3, Rules.BEAR)
	_worn(walk_army, ITEM_SLOW, 2, Rules.SWORDSMAN)
	var w := _battle_of(_open(ARENA_W, ARENA_H), walk_army, [
		_spawn(ARENA_W, Rules.CROW, 8, 5),     # 0 — adjacent, trades a blow, then dies
		_spawn(ARENA_W, Rules.WOLF, 16, 5),   # 1 — the far target the soldier walks to afterwards
	])
	_ashore(w, 0, Vector2(7, 5))
	w.begin_frame()
	w.step(TICK_ONE)
	t.ok(walk_army.hp[0] < Rules.hp_of(Rules.WOLF), "까마귀가 실제로 쐈다 (자가 점검)")
	t.ok(w.enemy_hp[0] < Rules.hp_of(Rules.CROW), "병사도 까마귀를 때렸다 — 0번 적에 감속이 걸려 있다 (자가 점검)")
	w.enemy_hp[0] = 0.0
	for _f in 2:
		w.begin_frame()
		w.step(TICK_ONE)
	t.eq(w.enemy_alive[0], 0, "까마귀가 죽었다 (자가 점검)")
	var travelled := 0.0
	var prev: Vector2 = w.soldier_pos[0]
	for _f in 20:
		w.begin_frame()
		w.step(TICK_ONE)
		travelled += prev.distance_to(w.soldier_pos[0])
		prev = w.soldier_pos[0]
	t.ok(absf(travelled - Rules.speed_of(Rules.WOLF) * 20.0 / 60.0) <= 0.02,
		"총 맞은 병사의 걸음은 그대로다 — 적 타격은 감속을 못 건다 (%.3f칸)" % travelled)


# -- fixtures --------------------------------------------------------------------------------------

## One melee soldier `offset` tiles from one bison, stepped once. Returns the bison's HP.
func _melee_probe(offset: Vector2, dt: float) -> float:
	var army := _army_of([Rules.WOLF])
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [_spawn(ARENA_W, Rules.WOLF, 12, 5)])
	_ashore(b, 0, Vector2(12, 5) + offset)
	b.begin_frame()
	b.step(dt)
	return b.enemy_hp[0]


## A ranged soldier walking the lane at the lion from 16 tiles out. Returns where it ended up.
func _lane_approach(dt: float, frames: int) -> Dictionary:
	var army := _army_of([Rules.CROW])
	var b := _battle_of(_lane(), army, [_spawn(LANE_W, Rules.LION, 18, 2)])
	_ashore(b, 0, Vector2(2, 2))
	for _f in frames:
		b.begin_frame()
		b.step(dt)
	return {
		"d": b.soldier_pos[0].distance_to(b.enemy_pos[0]),
		"x": b.soldier_pos[0].x,
		"lion": b.enemy_pos[0],
		"hp": b.enemy_hp[0],
	}


## One melee soldier 4.0 tiles down the lane from the lion, stepped once by `dt`. Returns the lion's HP.
func _lane_march(dt: float) -> float:
	var army := _army_of([Rules.WOLF])
	var b := _battle_of(_lane(), army, [_spawn(LANE_W, Rules.LION, 18, 2)])
	_ashore(b, 0, Vector2(14, 2))
	b.begin_frame()
	b.step(dt)
	return b.enemy_hp[0]


## Water border, land inside, no docks.
func _open(w: int, h: int) -> Array:
	var rows := []
	for y in h:
		if y == 0 or y == h - 1:
			rows.append("~".repeat(w))
		else:
			rows.append("~" + ".".repeat(w - 2) + "~")
	return rows


## One tile tall. The walk down it is forced straight, so "how far did it stop" is not confounded by the
## diagonal drift an open field produces when two neighbours tie on hop count.
func _lane() -> Array:
	var rows := []
	for y in LANE_H:
		if y == 2:
			rows.append("~" + ".".repeat(LANE_W - 2) + "~")
		else:
			rows.append("~".repeat(LANE_W))
	return rows


## The open arena with a bay on its west side: rows 3-7 are open water for the first six columns, and
## the coast begins at column 6. **This is the one fixture in this file a boat can sail on**, and every
## row that summons uses it.
##
## ⚠⚠ **BOTH OF THIS FIXTURE'S TILE CONSTANTS ARE DELETED (2026-08-27) AND NEITHER HAS A SUCCESSOR.**
## `_PORT_HARBOUR` (2,5) named the `H` tile a boat departed from and `_PORT_LANDING` (6,5) named the
## beach `send` was handed; the pair was 4.0 tiles apart in a straight line and the boat sailed
## 4.576491 of `grid.water_route`'s smoothed polyline. **`send`, `water_route` and `home_harbour_for`
## are all deleted**: a summon names ONE tile, the water the player pressed, and the grid derives the
## other end from it. ⇒ **Neither end of a crossing is a fixture constant any more** — the origin comes
## out of `_summonable_water_on` and the landing out of `grid.summon_landing_of`, and a row that wants
## the length asks the boat.
##
## ⚠ **The `H` tile at (2,5) STAYS, and it is decoration now.** `grid.harbour_tiles` is still filled
## from it and nothing in `summon`'s path reads that table — which makes this bay the fixture that
## would catch a harbour creeping back into a departure, not the one that proves it has not.
##
## ⚠⚠ **THE BAND THIS BAY HOLDS IS TWO TILES WIDE AND THAT IS WORTH KNOWING BEFORE EDITING IT.**
## `Rules.SUMMON_BAND_MIN_TILES` is 3 hops off the shore and `Grid.summon_radius()` is
## `max(w, h) * 0.46 = 11.04` about the centre (12,6), and the only water satisfying both is **(2,5)
## and (3,5)** — (1,5) misses the ring by 0.005 of a tile. **Narrowing the bay or moving the coast east
## empties the band**, and then every summon row in this file reddens at once;
## `_death_is_permanent` carries the one line that says so out loud.
func _port() -> Array:
	var rows := _open(ARENA_W, ARENA_H)
	for y in range(3, 8):
		rows[y] = "~~~~~~" + ".".repeat(ARENA_W - 7) + "~"
	rows[5] = "~~H~~~" + ".".repeat(ARENA_W - 7) + "~"
	return rows


## The lowest-indexed WATER tile a summon may be pressed on, or -1. **The name says which kind of tile
## it hands back, deliberately** — `net_run` carries the identical helper for the identical reason.
##
## ⚠⚠ **THE DELETED `send` TOOK A BEACH AND `summon` TAKES WATER, AND CONFUSING THE TWO COST A RED
## ROUND.** A land tile handed to `summon` is refused by `Grid.can_summon_at` and comes back as -1 —
## a refusal that looks exactly like a broken plan and has nothing to do with what any row here
## measures. Searching the grid is also what keeps the fixture honest: a hard-coded tile is a tile that
## describes one bay, and this bay's band has moved twice already.
func _summonable_water_on(b: Battle) -> int:
	var g := b.grid
	for tile in g.w * g.h:
		if g.can_summon_at(tile):
			return tile
	return -1


## A wall pierced by a single tile at (5,4).
func _corridor() -> Array:
	var rows := []
	for y in CORR_H:
		if y == 0 or y == CORR_H - 1:
			rows.append("~".repeat(CORR_W))
		elif y == 4:
			rows.append("~" + ".".repeat(CORR_W - 2) + "~")
		else:
			rows.append("~....#.....~")
	return rows


func _grid_of(rows: Array) -> Grid:
	var g := Grid.new()
	g.load_rows(rows)
	return g


## `Army.add(type_id)` is gone — a body is `recruit`ed from a SLOT now. Every `type_id` this file passes
## is a PLAYER row, so it is registered into the army's own slots
## here rather than at every call site.
func _army_of(types: Array) -> Army:
	var a := Army.new()
	# ⚠ **The slots are the ARMY's now, so the resolution asks the army rather than a constant table.**
	# `register_species` is idempotent-by-refusal, so asking for the same species twice costs one slot.
	for raw in types:
		var ty := int(raw)
		var slot := a.slot_of_type(ty)
		if slot < 0:
			slot = a.register_species(ty)
		a.recruit(slot)
	return a


func _spawn(w: int, type_id: int, x: int, y: int) -> Dictionary:
	return {"type_id": type_id, "tile": y * w + x}


## An island already under way. ⚠ **The commit flag is set directly, and that is deliberate.** `step`
## refuses everything until the island is committed (`plan-then-watch`, 4.3) — which is a RULE, and it
## is measured thoroughly by `net_plan`. Calling `commit()` here is not possible anyway: it refuses a
## plan with no boats, and almost every fixture in this file puts its soldiers ashore by hand rather
## than sailing them. This file owns the combat rules, so it starts from an island already under way,
## the same way `_ashore` below starts from a soldier who has already landed.
## **A fixture that has to author a plan uses `_planning_battle_of` and calls the real `commit()`.**
func _battle_of(rows: Array, army: Army, spawns: Array) -> Battle:
	var b := _planning_battle_of(rows, army, spawns)
	b._committed = true
	return b


## The same island, left in the planning state, so a check can drive `send` and `commit` for real.
func _planning_battle_of(rows: Array, army: Army, spawns: Array) -> Battle:
	var b := Battle.new()
	# load_rows first, always: setup writes a reservation per enemy and load_rows clears the table.
	b.setup(_grid_of(rows), army, spawns)
	return b


## Puts a soldier on the island the way a landing would. **All three of state, position and goal**, plus
## the tile reservation `battle` writes on unload — set only the state and the unit teleports back to its
## stale goal on the first frame it moves.
func _ashore(b: Battle, i: int, p: Vector2) -> void:
	b.soldier_state[i] = Battle.SoldierState.ASHORE
	b.soldier_pos[i] = p
	b._soldier_goal[i] = p
	var claimed := b.grid.reserved
	claimed[_tile_key(p, b.grid.w)] = i
	b.grid.reserved = claimed


func _tile_key(p: Vector2, w: int) -> int:
	return int(round(p.y)) * w + int(round(p.x))
