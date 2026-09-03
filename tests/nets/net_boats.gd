extends RefCounted
## **The beasts cross the water.** 티켓 41, the 월~수 slice.
##
## The claim under test is one sentence: **a boat is born out at sea on a clock, sails at one speed
## along open water toward one coast 조각, stops short of it and never moves again, with `BOAT_CAPACITY`
## riders aboard and none of them on the board.**
##
## ⚠⚠ **NOTHING HERE TOUCHES THE TREE.** `Grid.new()`, `Army.new()`, `Battle.new()` and `step(dt)` are
## the whole of it — the `src/sim/` seam `GLOSSARY.md` names. The one exception is the hull the deck
## offsets were read off, which is a RESOURCE load and an orphan node, at the foot of this file.
##
## ⚠⚠ **THE RING AND THE STRIDE ARE MEASURED ON THE REAL ISLAND AND NOTHING ELSE.** A hand-built board
## can be given a coast whose size happens to be coprime with the stride, or happens not to be, and
## either way the green says nothing about the board the game opens. **The pure motion — how far out,
## how fast, how short it stops — is measured on a fixture**, because that half is arithmetic and a
## small board makes the arithmetic checkable by hand.
##
## ⚠ **The numbers are pinned as literals in `_the_numbers_are_the_ones_that_were_chosen` and derived
## from `Rules` everywhere else.** That split is deliberate: the dynamics below would stay green at any
## speed if they read the constant for both the drive and the expectation, so **exactly one place holds
## the value that was decided** and moving `BOAT_SPEED_TILES` reddens it.


## The board the motion checks run on. 9 x 7, a 5 x 3 island in the middle.
## ⚠ **Hand-countable on purpose.** Twelve of its fifteen land 조각 touch water and three do not.
const ISLE := [
	"~~~~~~~~~",
	"~~~~~~~~~",
	"~~.....~~",
	"~~.....~~",
	"~~.....~~",
	"~~~~~~~~~",
	"~~~~~~~~~",
]
## The three 조각 of `ISLE` with land on all eight sides. Written out rather than counted, so a ring
## that quietly grew to 「every land 조각」 fails on the members and not only on the size.
const ISLE_INLAND := [
	3 + 3 * 9,
	4 + 3 * 9,
	5 + 3 * 9,
]
const ISLE_LAND_COUNT := 15
const ISLE_RING_COUNT := 12

## A board with no water at all. The ring is empty there, and an empty ring is what makes「no boat is
## born」 a case rather than an accident.
const DRY := [
	"...",
	"...",
	"...",
]

## **One land 조각 and nothing else**, so a boat that comes to it can only ever put `Rules.TILE_CAPACITY`
## 늑대 down and keeps the rest. ⚠⚠ **It exists to falsify the WAIT, not the landing**: the wait must not
## run while anybody is still aboard, and on every other board here the deck empties in one sub-step and
## a wait that ignored the riders would be green.
const PERCH := [
	"~~~~~~~",
	"~~~~~~~",
	"~~~.~~~",
	"~~~~~~~",
	"~~~~~~~",
]

## **The detached islet on the shipped board**, as 조각 numbers on a 30-wide island: a 2x2 at
## (20,22)–(21,23) with no walk to the other 280 land 조각. **All four touch water**, so a bare coast
## test hands them back as beaches — and a boat that came to one would put its whole load somewhere
## they can never leave. `net_islands` names the same four in its own reachability row.
## ⚠ **If the island is re-baked these four move**, and this row is meant to go red rather than be
## quietly widened: it is the only place the exclusion is measured against named 조각 rather than
## against the rule that produced them.
const ISLET := [680, 681, 710, 711]

## Tolerance for a distance in 조각. Positions are accumulated one sub-step at a time, so an exact
## `==` on a crossing of 8 조각 is a coin flip on the last bit.
const NEAR := 1e-3


func run(t) -> void:
	_the_numbers_are_the_ones_that_were_chosen(t)
	_the_ring_is_the_land_that_touches_water(t)
	_the_real_island_s_ring_is_its_walkable_coast(t)
	_the_islet_is_not_a_beach(t)
	_the_ring_goes_round_the_island(t)
	_the_stride_visits_every_beach(t)
	_seaward_points_off_the_land(t)
	_no_boat_before_the_first_clock(t)
	_the_first_boat_is_born_out_at_sea(t)
	_it_closes_the_distance_at_the_boat_speed(t)
	_it_stops_short_of_the_shore_and_stays(t)
	_an_emptied_hull_waits_and_is_gone(t)
	_a_hull_with_riders_still_aboard_never_goes(t)
	_the_second_boat_comes_one_interval_later_and_far_round(t)
	_the_stored_stop_is_measured_from_the_water(t)
	_the_drawn_shore_is_not_the_tile_grid(t)
	_the_riders_are_aboard_and_not_on_the_board(t)
	_the_crossing_is_the_same_at_any_frame_rate(t)
	_a_board_with_no_coast_launches_nothing(t)
	_the_switch_decides_whether_boats_come_at_all(t)
	_the_switch_on_leaves_the_launch_times_where_they_were(t)
	_the_deck_offsets_are_the_mesh_s_own_benches(t)


# == the numbers ======================================================================================
	# **The sentinel.** See `run_nets.done` — without it a `run()` that dies
	# half way still reports every check it managed first, in a shape a healthy net cannot be told from.
	t.done()


## **The one place a decided value is written as a literal.** Everything below reads `Rules`, so this is
## what goes red when somebody retunes the crossing — and a crossing that measures the same at any speed
## measures nothing.
func _the_numbers_are_the_ones_that_were_chosen(t) -> void:
	t.eq(Rules.BOAT_FIRST_SEC, 5.0, "첫 배는 5초에 온다")
	t.eq(Rules.BOAT_INTERVAL_SEC, 30.0, "그 뒤로는 30초마다다 — 일정하게, 랜덤이 아니다")
	t.eq(Rules.BOAT_LINGER_SEC, 3.0, "내려놓은 배는 3초 있다가 사라진다")
	t.eq(Rules.BOAT_SPEED_TILES, 1.2, "배는 초당 1.2조각으로 간다")
	t.eq(Rules.BOAT_START_DIST_TILES, 24.0, "해변 조각에서 24조각 떨어진 데서 뜬다")
	t.eq(Rules.BOAT_BEACH_GAP_TILES, 0.6, "뱃머리와 해안 사이에 0.6조각이 남는다")

	# ⚠⚠ **THE STANDOFF IS A SUM AND THE FLOOR UNDER IT IS THE BOAT'S OWN LENGTH.** It was a flat 2.0
	# against a hull whose bow is 2.6 조각 from its origin, so **every boat parked 0.6 조각 inland** —
	# measured on the running game, on all four beaches watched, worst on a diagonal approach where
	# about a third of the hull stood on the turf. **The number was smaller than the boat and nothing
	# could see it**, because the sim's boat is a point and a point is never on the grass.
	t.eq(Rules.BOAT_STANDOFF_TILES, Rules.BOAT_HULL_HALF_TILES + Rules.BOAT_BEACH_GAP_TILES,
		"서는 거리가 선체 반길이 + 틈이다 — 따로 적은 숫자가 아니다")
	t.ok(Rules.BOAT_STANDOFF_TILES > Rules.BOAT_HULL_HALF_TILES,
		"그래서 서는 거리(%.2f)가 선체 반길이(%.2f)보다 크다 — 뱃머리가 뭍에 안 올라간다"
			% [Rules.BOAT_STANDOFF_TILES, Rules.BOAT_HULL_HALF_TILES])
	t.ok(Rules.BOAT_START_DIST_TILES > Rules.BOAT_STANDOFF_TILES + 1.0,
		"자가 점검 — 그러고도 건널 거리가 남는다")

	# ⚠⚠ **THE DRAFT, BOUNDED AT BOTH ENDS.** `boat.glb`'s origin is its KEEL, so a draft of 0 stood the
	# whole hull on top of the water — measured on the running game, and **nothing could catch it while
	# the constant was 0**, which is the hole this pair closes.
	t.ok(Look.BOAT_DRAFT_TILES + Look.BOAT_BOB_TILES < 0.0,
		"용골이 흔들림의 꼭대기에서도 물 아래다 (%.3f + %.3f)"
			% [Look.BOAT_DRAFT_TILES, Look.BOAT_BOB_TILES])
	var lowest_seat := 9999.0
	for raw_slot in Look.BOAT_DECK_SLOTS:
		lowest_seat = minf(lowest_seat, (raw_slot as Vector3).y)
	t.ok(Look.BOAT_DRAFT_TILES - Look.BOAT_BOB_TILES + lowest_seat > 0.0,
		"그런데 제일 낮은 자리(%.4f)는 흔들림의 바닥에서도 물 위다 — 늑대가 안 잠긴다" % lowest_seat)

	# ⚠⚠ **THE VALUE IS PINNED, BECAUSE THE REAL CEILING IS AN EYE'S AND NOT AN ARITHMETIC ONE.** The
	# binding distance is **seat-to-seat on ONE bench** — 0.292 조각 on `boat.glb` — and **6x had already
	# reached it**: the two riders sharing a bench overlapped, and that deck read as four pairs rather
	# than eight figures. There was no headroom left to bound, so what keeps 6x from drifting is this
	# pin.
	# ⚠⚠ **THE BENCH-TO-BENCH BOUND BELOW IS A FAR BACKSTOP AND NOTHING MORE.** It reddens near 10.1x —
	# **measured: a mutation to 9.0 does not touch it** — and the 「about 8x」 and 「~10.1x headroom」
	# written here on two earlier rounds were both taken against bench-to-bench, which is the wrong
	# spacing for the thing that goes wrong. **A check must not be described as stricter than it is**,
	# and the pin is what actually holds the decision.
	# ⚠⚠ **THE PIN READ 6.0 UNTIL 2026-08-30 AND THE DECK IS UNCHANGED.** `BODY_SPRITE_SCALE` used to
	# be multiplied in downstream, so the drawn width was always `6.0 x 0.45`; the 0.45 is folded into
	# the ratio now and the row below no longer multiplies it. **The pin moves with the arithmetic, not
	# with a judgement** — see that constant for why the two were separated.
	# ⚠⚠ **EVERY MEASUREMENT ABOVE WAS TAKEN ON THE BIG HULL AND THE SMALL ONE ARRIVES NOW**
	# (2026-09-01). Its benches are 0.84 조각 apart with a 0.600 조각 seat gap, so the seat-to-seat
	# ceiling the pin was set against is **not where it was**. ⚠ **Nothing here is re-aimed for that**:
	# where the ratio stops is an eye's answer on a running screen, and the two rows below hold the same
	# two arithmetic bounds they always held.
	t.eq(Look.BOAT_RIDER_W_RATIO, 2.70, "갑판 늑대는 몸 반지름의 2.7배로 그린다")
	var bench_gap := absf((Look.BOAT_DECK_SLOTS[2] as Vector3).x - (Look.BOAT_DECK_SLOTS[0] as Vector3).x)
	var rider_wide := Look.body_radius_of(Rules.WOLF) * Look.BOAT_RIDER_W_RATIO / Look.TILE_PX
	# The two seats on one plank — the spacing that actually binds. ⚠ Read off the table, not typed.
	var seat_gap := absf((Look.BOAT_DECK_SLOTS[1] as Vector3).z - (Look.BOAT_DECK_SLOTS[0] as Vector3).z)
	t.ok(bench_gap > 0.0, "판자 사이 간격이 %.2f 조각이다 (자가 점검)" % bench_gap)
	# ⚠⚠ **THE FLOOR DOES NOT ENCODE THE 4x -> 6x CHANGE AND IT IS NOT PRETENDING TO.** 4x already
	# cleared 「invisible」 — countable marks in pairs — and what it failed was 「identifiable」: they
	# read as generic dark animals rather than as wolves. **That is an eye's answer and this row holds
	# only the arithmetic one**, a quarter of the bench spacing. **Measured: a mutation back to 4.0 does
	# not redden this**, and that is stated rather than papered over with a threshold reverse-engineered
	# to bite.
	t.ok(rider_wide > bench_gap * 0.25,
		"갑판 늑대가 %.3f 조각 폭으로 그려진다 — 판자 간격의 4분의 1은 넘는다" % rider_wide)
	t.ok(rider_wide < bench_gap,
		"그리고 판자 사이 간격보다는 좁다 — 판자 줄끼리 안 붙는다 (%.3f < %.2f). ⚠ 한 판자 위 두 자리 간격은 %.3f 다"
			% [rider_wide, bench_gap, seat_gap])
	t.eq(Rules.BOAT_CAPACITY, 4, "한 배에 넷이 탄다")
	t.eq(Rules.BOAT_BEACH_TURN, 0.42, "다음 배는 고리를 0.42 바퀴 돌아온 자리로 온다")

	# **How long the crossing lasts, derived rather than pinned.** ⚠ **Deliberately not asserted against
	# a number**: the speed and the distance are look values the user is choosing by eye, so a duration
	# literal here would be one more thing to edit when they land rather than a measurement of anything.
	var crossing := (Rules.BOAT_START_DIST_TILES - Rules.BOAT_STANDOFF_TILES) / Rules.BOAT_SPEED_TILES
	t.ok(crossing > 0.0, "그래서 건너는 데 %.1f초 걸린다 — 건널 시간이 실제로 있다" % crossing)


# == the beach ring ===================================================================================

## **The ring is every land 조각 with water in any of the eight directions, and nothing else** — on a
## board with one body of land, where「walkable to the rest」cannot be what is doing the work.
##
## ⚠⚠ **BOTH DIRECTIONS ARE ASSERTED.** A ring that answered 「every land 조각」 has the right kind of
## members and the wrong set, and a size check alone would pass the day an island grew a coastline all
## the way round. The three inland 조각 are named individually for the same reason.
func _the_ring_is_the_land_that_touches_water(t) -> void:
	var grid := _grid(ISLE)
	var ring := grid.beach_ring(Rules.BOAT_START_DIST_TILES)

	var land := 0
	for tile in grid.passable.size():
		if grid.passable[tile] != 0:
			land += 1
	t.eq(land, ISLE_LAND_COUNT, "판에 땅이 열다섯 조각이다 (자가 점검)")
	t.eq(ring.size(), ISLE_RING_COUNT, "그중 열두 조각이 해변이다")

	var in_ring := {}
	for k in ring.size():
		in_ring[int(ring[k])] = true
	t.eq(in_ring.size(), ring.size(), "고리에 같은 조각이 두 번 안 들어 있다")

	var inland_in_ring := []
	for raw in ISLE_INLAND:
		if in_ring.has(int(raw)):
			inland_in_ring.append(int(raw))
	t.eq(inland_in_ring.size(), 0,
		"사방이 땅인 세 조각은 해변이 아니다 %s — 「땅이면 전부」가 아니다" % str(inland_in_ring))

	var wrong := _ring_disagrees_with_the_board(grid, ring)
	t.eq(wrong.size(), 0, "고리가 판과 한 조각도 안 어긋난다 %s" % str(wrong))


## **The same claim on the island the game actually opens**, as a property and not as a count.
##
## ⚠⚠ **THE COUNT IS DELIBERATELY NOT PINNED.** 티켓 41 carries 84, and that number is island 0's — a
## board that is deleted. Today's board answers its own number, `net_islands` reads a third one off a
## stale expectation, and re-stating any of them here would make this net go red for somebody else's
## reason. **The count is printed in the label so a round can read it without a check owning it.**
func _the_real_island_s_ring_is_its_walkable_coast(t) -> void:
	var grid := _real()
	var ring := grid.beach_ring(Rules.BOAT_START_DIST_TILES)
	t.ok(ring.size() > 0,
		"진짜 섬에 해변이 %d 조각 있다 (자가 점검 — 0이면 아래가 전부 공허하다)" % ring.size())
	var wrong := _ring_disagrees_with_the_board(grid, ring)
	t.eq(wrong.size(), 0, "진짜 섬의 고리도 판과 한 조각도 안 어긋난다 %s" % str(wrong.slice(0, 8)))

	# ⚠⚠ **THE THREE TERMS ARE COUNTED APART, AND WITHOUT THIS THE ROW ABOVE COULD BE VACUOUS.** It
	# tests the ring against the same three conditions the ring is built from, so it would stay green if
	# the whole rule were wrong in one direction. **Each cut has to actually remove something here.**
	var coastal := 0
	var walkable := 0
	var main := grid.main_land()
	for tile in grid.passable.size():
		if grid.passable[tile] == 0 or not _touches_water(grid, tile):
			continue
		coastal += 1
		if main[tile] != 0:
			walkable += 1
	t.ok(coastal > walkable,
		"물에 닿은 땅 %d 조각 중 %d 만 본섬이다 — 떨어진 땅 %d 조각을 잘라냈다"
			% [coastal, walkable, coastal - walkable])
	t.ok(walkable > ring.size(),
		"그 %d 중 %d 만 해변이다 — 안쪽 윤곽 %d 조각은 바다에서 못 온다"
			% [walkable, ring.size(), walkable - ring.size()])


## **Four coast 조각 that are coast and are NOT beaches**, because nothing can walk off them.
##
## ⚠⚠ **THIS IS THE INSTRUMENT'S OWN INVERSION AND NOT ONLY THE SUBJECT'S.** `_ring_disagrees_with_the_board`
## above tests the ring against 「land AND touches water AND in the main body」 — the same three terms the
## ring is built from, so it would stay green if all three were wrong together. These four 조각 satisfy
## the first two and fail the third, and they are named rather than derived.
func _the_islet_is_not_a_beach(t) -> void:
	var grid := _real()
	var ring := grid.beach_ring(Rules.BOAT_START_DIST_TILES)
	var in_ring := {}
	for k in ring.size():
		in_ring[int(ring[k])] = true
	var main := grid.main_land()

	var coastal := 0
	var detached := 0
	var wrongly_in := []
	for raw in ISLET:
		var tile := int(raw)
		if tile >= grid.passable.size() or grid.passable[tile] == 0:
			continue
		if _touches_water(grid, tile):
			coastal += 1
		if main[tile] == 0:
			detached += 1
		if in_ring.has(tile):
			wrongly_in.append(tile)
	t.eq(coastal, ISLET.size(), "떨어진 섬 네 조각은 전부 물에 닿아 있다 (자가 점검)")
	t.eq(detached, ISLET.size(), "그리고 전부 본섬에서 걸어갈 수 없다 (자가 점검)")
	t.eq(wrongly_in.size(), 0, "그래서 넷 다 해변이 아니다 %s — 못 나오는 해변에는 안 내린다" % str(wrongly_in))


## **The ring is a loop round the island, not a list read row by row.**
##
## ⚠⚠ **THIS IS WHAT MAKES THE STRIDE MEAN ANYTHING.** In 조각-number order a stride of 37 walks 37 rows
## down the same coast and settles onto a handful of fixed beaches; the whole of「consecutive boats come
## to different sides」rides on this ordering and on nothing else.
func _the_ring_goes_round_the_island(t) -> void:
	var grid := _real()
	var ring := grid.beach_ring(Rules.BOAT_START_DIST_TILES)
	var centre := grid.island_centre()

	var backwards := 0
	var last := -100.0
	for k in ring.size():
		var tile := int(ring[k])
		var a := (Vector2(tile % grid.w, tile / grid.w) - centre).angle()
		if a < last - NEAR:
			backwards += 1
		last = a
	t.eq(backwards, 0, "고리가 섬 가운데를 도는 각도 순서다 — 뒤로 가는 자리가 없다")

	# The self-check that makes the row above a claim: 조각-number order is NOT angle order on this
	# board, so a ring that forgot to sort would have to fail it.
	var row_major := ring.duplicate()
	var as_ints := []
	for k in row_major.size():
		as_ints.append(int(row_major[k]))
	as_ints.sort()
	var same := true
	for k in as_ints.size():
		if int(as_ints[k]) != int(ring[k]):
			same = false
			break
	t.ok(not same, "자가 점검 — 그 순서는 조각 번호 순서와 다르다: 안 정렬하면 위가 문다")
	t.ok(grid.island_centre().length() > 0.0, "섬 가운데가 (0,0) 이 아니다 (자가 점검)")


## **The stride and the ring's size are coprime, so every beach is visited before any repeats.**
##
## ⚠⚠ **ASSERTED AS A PROPERTY, NEVER AS A NUMBER.** A stride sharing a factor with the ring collapses
## the spread onto `size / gcd` beaches and nothing else changes — the boats still come, still cross,
## still stop, and every other check in this file stays green. **The ring's size moves with the island**,
## so pinning today's would make this red for the next bake rather than for a real defect.
func _the_stride_visits_every_beach(t) -> void:
	var grid := _real()
	var n := grid.beach_ring(Rules.BOAT_START_DIST_TILES).size()
	t.ok(n > 1, "고리에 조각이 둘 이상이다 (자가 점검)")
	var stride := Rules.beach_stride_for(n)
	t.eq(_gcd(stride, n), 1, "보폭 %d 와 해변 수 %d 가 서로소다" % [stride, n])
	t.ok(stride >= 1 and stride < n, "그리고 보폭이 고리 안에 있다 (%d / %d)" % [stride, n])

	# The walk itself, not only the arithmetic: the cursor is what the sim actually advances.
	var seen := {}
	var cursor := 0
	for _k in n:
		seen[cursor] = true
		cursor = (cursor + stride) % n
	t.eq(seen.size(), n, "그래서 %d 척이 %d 해변을 하나도 안 겹치고 다 밟는다" % [n, n])
	t.eq(cursor, 0, "그리고 %d 척째에 처음 자리로 돌아온다" % n)

	# ⚠⚠ **THE LIVE RING IS PINNED FIRST, AND IT IS PINNED AGAINST THE DERIVATION AND NOT A LITERAL.**
	# The ring's size moves whenever `BOAT_START_DIST_TILES` does — it decides which 조각 a hull can fit
	# in front of — so a number typed here would go red for the next tuning rather than for a defect.
	# **What is fixed is the rule**: the stride is the coprime nearest `round(size * BOAT_BEACH_TURN)`,
	# and nothing nearer to that target is coprime.
	var want := int(round(float(n) * Rules.BOAT_BEACH_TURN))
	var nearer := []
	for cand in range(1, n):
		if absi(cand - want) < absi(stride - want) and _gcd(cand, n) == 1:
			nearer.append(cand)
	t.eq(nearer.size(), 0,
		"지금 고리 %d 의 보폭 %d 는 목표 %d 에 가장 가까운 서로소다 — 더 가까운 것 %s"
			% [n, stride, want, str(nearer)])

	# ⚠⚠ **THESE TWO ARE A RECORD OF WHERE 0.42 CAME FROM AND NOT RINGS THIS GAME HAS.** 37 was picked by
	# hand against a ring of 88 and 31 against a ring of 74; **the fraction was chosen to reproduce both**,
	# and that is the whole reason it is 0.42 rather than a number somebody liked. They are kept so a
	# later round cannot re-tune the fraction without noticing what it was fitted to. ⚠ Neither size is
	# reachable on today's board.
	t.eq(Rules.beach_stride_for(88), 37, "옛 고리 88 에서는 37 이었다 (기록 — 지금 판에는 없는 크기다)")
	t.eq(Rules.beach_stride_for(74), 31, "옛 고리 74 에서는 31 이었다 (기록)")

	# ⚠⚠ **AND A SIZE WHERE THE NEAREST TARGET IS *NOT* COPRIME, OR THE SEARCH IS NEVER EXERCISED.**
	# ⚠ **This one is an instrument case and not a ring either** — today's 67 is prime, so its own target
	# is already coprime and the walk never runs. For a ring of 66 the target is 28 and `gcd(28, 66)` is
	# 2, so a function that only ever returned its first guess would hand back 28.
	t.ok(_gcd(28, 66) != 1, "자가 점검 — 66 짜리 고리의 첫 후보 28 은 서로소가 아니다")
	t.eq(_gcd(Rules.beach_stride_for(66), 66), 1,
		"그런데 66 이 돌려주는 %d 는 서로소다 — 첫 후보에서 실제로 옮겨간다" % Rules.beach_stride_for(66))
	t.ok(Rules.beach_stride_for(66) != 28, "그리고 그 값이 28 이 아니다")

	# A one-조각 and a two-조각 ring have nothing to spread over; 1 is coprime with both and the search
	# must not run off the end looking for something better.
	t.eq(Rules.beach_stride_for(1), 1, "고리가 하나면 보폭은 1 이다")
	t.eq(Rules.beach_stride_for(2), 1, "둘이어도 1 이다")

	# The inversion, on the instrument: a stride that DOES share a factor visits fewer. Without this the
	# row above would be green for a stride of `n` itself, which visits one beach forever.
	var bad_stride := n / 2 if n % 2 == 0 else n
	var bad_seen := {}
	var c2 := 0
	for _k in n:
		bad_seen[c2] = true
		c2 = (c2 + bad_stride) % n
	t.ok(bad_seen.size() < n,
		"자가 점검 — 서로소가 아닌 보폭 %d 은 %d 해변만 밟는다: 위가 산수를 실제로 본다"
			% [bad_stride, bad_seen.size()])


## **The way out to sea from a beach 조각 points at the sea.**
##
## ⚠⚠ **A BEARING THAT POINTED INLAND WOULD LEAVE EVERY DISTANCE CHECK IN THIS FILE GREEN.** The
## crossing is measured from the beach 조각 and knows nothing about which side of it the water is on —
## a boat born inland sails exactly its start distance to a point exactly the standoff short, straight
## over the island.
##
## ⚠⚠ **ONE 조각 ALONG THE BEARING, NOT THE WHOLE LINE, AND THE DIFFERENCE IS DELIBERATE.**
## `Grid.seaward_at` is a LOCAL rule and this is the local claim it actually makes. **The whole line is
## not open water on this board** — 14 of the island's beaches stand on inland water, and a hull born
## 24 조각 out along their bearing lands on the island. That is recorded on `seaward_at` itself as a
## live defect rather than measured here as though it were fixed: **a check must not promise more than
## the rule it watches**, and a green here that read「every crossing is clear」would be exactly the
## label-promises-more failure `how-nets-lie` collects.
func _seaward_points_off_the_land(t) -> void:
	var grid := _real()
	var ring := grid.beach_ring(Rules.BOAT_START_DIST_TILES)
	var not_unit := 0
	var into_land := []
	for k in ring.size():
		var tile := int(ring[k])
		var out := grid.seaward_at(tile)
		if absf(out.length() - 1.0) > NEAR:
			not_unit += 1
		# ⚠ **NO `+0.5` here, and that is not an oversight.** This row walks the 조각 table and a 조각's
		# own coordinate is its integer — the shift belongs to the baked OUTLINE's space, which this row
		# never touches. Mixing the two is how a diagonal ends up measured 0.707 조각 out.
		var here := Vector2(tile % grid.w, tile / grid.w)
		var one_out := here + out
		var sx := int(round(one_out.x))
		var sy := int(round(one_out.y))
		if sx < 0 or sy < 0 or sx >= grid.w or sy >= grid.h:
			continue
		if grid.water[sy * grid.w + sx] == 0:
			into_land.append(tile)
	t.eq(not_unit, 0, "해변마다 길이 1인 바다 쪽 방향이 하나씩 나온다")
	t.eq(into_land.size(), 0,
		"그리고 그 방향으로 한 걸음이 전부 물이다 %s" % str(into_land.slice(0, 8)))

	# ⚠⚠ **THE BOW CLEARS EVERY 조각 OF LAND ON THE APPROACH, AND NOT JUST THE 조각 IT IS AIMED AT.**
	# This is the row that did not exist while two arrivals in four parked on the grass: the standoff was
	# checked against the mesh's half-length, **which is a check about a NUMBER**. A hull is 2.6 조각 to
	# the bow and the stop was 3.2 out from the beach — correct arithmetic, blind to a headland lying
	# nearer on the same line. Measured on the running game: 0.38 조각 of hull over land on one straight
	# approach, 0.80 on a diagonal.
	#
	# ⚠⚠ **THE STOP COMES FROM THE SUBJECT AND THE LAND COMES FROM THIS FILE'S OWN WALKER.** `Grid` says
	# where it will stop; the net finds the land itself and asks whether that stop is far enough. A row
	# that took both sides from `Grid` would be green for any walker, right or wrong.
	var aground := []
	var tightest := 9999.0
	for k in ring.size():
		var tile2 := int(ring[k])
		var dir2 := grid.seaward_at(tile2)
		var stop_at := _sim_stop(grid, tile2, dir2)
		var bow := stop_at - Rules.BOAT_HULL_HALF_TILES
		for raw_land in _land_on_line(grid, tile2, dir2, Rules.BOAT_START_DIST_TILES):
			var clear: float = bow - float(raw_land)
			tightest = minf(tightest, clear)
		# ⚠⚠ **THE FOOTPRINT AGAINST THE OUTLINE, WHICH IS THE ROW THAT ACTUALLY GUARDS THIS.** The
		# 조각-grid clearance above is kept only for the label below; **a point against `passable` is
		# exactly what stayed green while four of the five worst beaches put a hull on drawn grass.**
		if _hull_touches_drawn_land(grid, tile2,
				dir2, Vector2(tile2 % grid.w, tile2 / grid.w) + dir2 * stop_at):
			aground.append(tile2)
	t.eq(aground.size(), 0,
		"해변 %d 곳 전부에서 선체 앞머리가 그려진 땅을 안 밟는다 %s"
			% [ring.size(), str(aground.slice(0, 8))])

	# ⚠⚠ **AND AN UPPER BOUND, BECAUSE THE FIX FOR THE GRASS OVERSHOT INTO OPEN SEA.** Taking the
	# outermost land on the approach line parked the furthest boat **7.89 조각 out against a normal of
	# 3.82–3.90** — clear water on every side, eight wolves standing on it, nothing in frame explaining
	# it. **A boat stopped in open water reads worse than a boat on the grass**, because a beached one
	# at least looks like something happened. ⚠ **Nothing measured this**, which is how it shipped.
	# ⇒ **A hull length beyond the plain standoff is the bound.** Past that the geometry is not being
	# corrected, it is being fled.
	var cap := Rules.BOAT_STANDOFF_TILES + Rules.BOAT_HULL_HALF_TILES

	# ⚠⚠ **HOW MANY 조각 THE STOP RULE THREW AWAY, AND WHY THIS IS A ROW.** A 조각 the hull cannot stand
	# near is dropped from the ring rather than left stranding a boat in open sea — **so a stop rule that
	# regresses does not show up as a boat parked far out, it shows up as a shorter ring**, and the bound
	# below would stay green while the game quietly lost a third of its coast. Measured: the rule as
	# written drops **6**; putting the hull's STERN back in the window drops **8**. ⚠⚠ **THE BOUND IS 6
	# AND IT IS TIGHT ON PURPOSE**: a first draft used 8 and the stern regression slipped straight
	# through it, which is the one mutation the round exists to catch. **A loose bound here catches
	# nothing** — the drop count is the only place a stop rule going backwards still shows.
	# ⚠ **Re-aim this the day the island is re-baked** — it is a number about this board, like `ISLET`.
	var standable := 0
	var lead_ok := 0
	var main_l := grid.main_land()
	for tile_x in grid.passable.size():
		if grid.passable[tile_x] == 0 or main_l[tile_x] == 0 or not _touches_water(grid, tile_x):
			continue
		var d_x := grid.seaward_at(tile_x)
		var lead_x := _land_reach(grid, tile_x, d_x, Rules.BOAT_START_DIST_TILES)
		if lead_x >= Rules.BOAT_STANDOFF_TILES:
			continue
		lead_ok += 1
		if _sim_stop(grid, tile_x, d_x) <= cap:
			standable += 1
	t.eq(standable, ring.size(), "설 수 있는 해변이 곧 고리다 (자가 점검)")
	t.ok(lead_ok - standable <= 6,
		"선체가 못 서서 버린 해변이 %d 곳이다 — 여섯을 넘으면 규칙이 물러난 것이다 (%d 중 %d 가 남았다)"
			% [lead_ok - standable, lead_ok, standable])

	var far := []
	var furthest := 0.0
	for k in ring.size():
		var tile3 := int(ring[k])
		var stop3 := _sim_stop(grid, tile3, grid.seaward_at(tile3))
		furthest = maxf(furthest, stop3)
		if stop3 > cap:
			far.append(tile3)
	t.eq(far.size(), 0,
		"그리고 %.1f 조각보다 멀리 서는 배가 없다 — 제일 먼 것이 %.2f 다 %s"
			% [cap, furthest, str(far.slice(0, 8))])

	# The beach that produced the overshoot, named. ⚠ **A literal 조각 on purpose** — it is the case the
	# rule was rewritten for, and if the island is re-baked this row is meant to be re-aimed rather than
	# quietly widened.
	var worst_tile := 8 + 15 * 30
	if ring.has(worst_tile):
		var stop4 := _sim_stop(grid, worst_tile, grid.seaward_at(worst_tile))
		t.ok(stop4 <= cap,
			"오버슛을 만든 해변 (8,15) 이 %.2f 조각에 선다 — 7.89 였다" % stop4)
	# ⚠⚠ **THIS IS 0.60 FROM THE 조각 GRID AND NOT 0.60 FROM THE SHORE THE PLAYER SEES.** `passable` is
	# a square 조각 table; the drawn coast is a cut and curved outline from Blender that only bends on
	# block boundaries and does not sit on 조각 edges. **The two are different boundaries**, and this
	# label used to say 「틈」 without saying which — measured on the rendered frame, the drawn clearance
	# on three arrivals was 0.93, 0.50 and 0.39 while this row said 0.60 for all three.
	# ⇒ **The number is right and the word was wrong.** The drawn shore is
	# `_the_drawn_shore_is_not_the_tile_grid`, which measures against `Islands.coast()` directly.
	# ⚠⚠ **A FLOOR AND NO LONGER AN EQUALITY.** It used to read 「exactly 0.60」 and that was true while
	# the 조각 grid was the only rule. **The drawn outline can ask for more and does**, so the 조각-space
	# clearance is now 0.60 or better — an equality here would go red on the fix itself.
	t.ok(tightest >= Rules.BOAT_BEACH_GAP_TILES - NEAR,
		"그리고 제일 빠듯한 자리가 조각 격자 기준으로 %.2f 조각 이상이다 (얻은 값 %.4f) — 화면의 윤곽이 아니라 판의 조각이 기준이다"
			% [Rules.BOAT_BEACH_GAP_TILES, tightest])

	# The self-check that makes the pair above a claim: some beaches DO have land jutting seaward of
	# them, so the stop is not the same number everywhere and a standoff measured to the target 조각
	# alone would differ from this one.
	# ⚠⚠ **THE SELF-CHECK MOVED FROM 「JUTTING」 TO 「PUSHED OUT」, BECAUSE THE JUTTING ONES ARE NO LONGER
	# IN THE RING.** Every 조각 whose approach line ran into land is now either stopped correctly or
	# dropped, so `land_reach_along` answers 0 across the whole ring and a row demanding otherwise would
	# be asserting the defect back. **What still varies — and what makes the rows above non-vacuous — is
	# the outline pushing a stop past the 조각 floor.**
	var pushed := 0
	for k in ring.size():
		var tile3 := int(ring[k])
		if _sim_stop(grid, tile3, grid.seaward_at(tile3)) > Rules.BOAT_STANDOFF_TILES + NEAR:
			pushed += 1
	t.ok(pushed > 0,
		"자가 점검 — %d 곳은 그려진 윤곽이 조각 규칙보다 더 밀어낸다: 전부 같은 거리면 위가 공허하다"
			% pushed)


# == the crossing =====================================================================================

func _no_boat_before_the_first_clock(t) -> void:
	var b := _battle(ISLE)
	b.step(Rules.BOAT_FIRST_SEC - 0.1)
	t.eq(b.boat_pos.size(), 0, "첫 시각 전에는 배가 하나도 없다")
	t.ok(b.elapsed > 0.0, "그런데 시계는 돌았다 (자가 점검 — 안 돌았으면 위가 공허하다)")


func _the_first_boat_is_born_out_at_sea(t) -> void:
	var b := _battle(ISLE)
	b.step(Rules.BOAT_FIRST_SEC)
	t.eq(b.boat_pos.size(), 1, "첫 시각에 배가 하나 뜬다")
	t.eq(b.boat_state.size(), 1, "상태 칸도 같이 하나다 (자가 점검)")
	t.eq(int(b.boat_state[0]), Battle.BoatState.SAILING, "그 배는 오는 중이다")

	var beach := int(b.boat_beach[0])
	t.ok(beach >= 0, "겨눈 해변 조각을 갖고 있다")
	t.ok(b.grid.beach_ring(Rules.BOAT_START_DIST_TILES).has(beach), "그 조각은 해변 고리 위다 — 아무 데나 겨누지 않는다")

	var here: Vector2 = b.boat_pos[0]
	var target := Vector2(beach % b.grid.w, beach / b.grid.w)
	t.ok(absf(here.distance_to(target) - Rules.BOAT_START_DIST_TILES) <= NEAR,
		"뜬 자리가 해변 조각에서 정확히 %.1f조각 떨어져 있다 (얻은 값 %.4f)"
			% [Rules.BOAT_START_DIST_TILES, here.distance_to(target)])
	# Born and NOT moved on its own birth sub-step: the distance above is the whole of the crossing.
	t.ok(_water_or_off_board(b.grid, here), "그리고 그 자리는 물이다 — 땅 위에 뜬 배가 아니다")

	# The stored resting point, rebuilt from the board rather than read back — see `boat_stop`.
	t.ok((b.boat_stop[0] as Vector2).distance_to(_stop_point(b, 0)) <= NEAR,
		"설 자리도 판에서 다시 세운 값과 같다")


func _it_closes_the_distance_at_the_boat_speed(t) -> void:
	var b := _battle(ISLE)
	b.step(Rules.BOAT_FIRST_SEC)
	var start: Vector2 = b.boat_pos[0]
	var beach := int(b.boat_beach[0])
	var target := Vector2(beach % b.grid.w, beach / b.grid.w)

	b.step(1.0)
	var after: Vector2 = b.boat_pos[0]
	var moved := start.distance_to(after)
	t.ok(absf(moved - Rules.BOAT_SPEED_TILES) <= NEAR,
		"1초에 %.1f조각 간다 (얻은 값 %.4f)" % [Rules.BOAT_SPEED_TILES, moved])
	t.ok(after.distance_to(target) < start.distance_to(target),
		"그리고 간 쪽이 해변 조각 쪽이다 — 멀어지지 않는다")

	# On the segment, not merely nearer: a boat that drifted sideways and then back would pass a bare
	# distance test on both ends.
	var stop := _stop_point(b, 0)
	var off_line := start.distance_to(after) + after.distance_to(stop) - start.distance_to(stop)
	t.ok(absf(off_line) <= NEAR, "지나온 자리가 뜬 자리와 설 자리를 잇는 직선 위다 (얻은 값 %.5f)" % off_line)


func _it_stops_short_of_the_shore_and_stays(t) -> void:
	var b := _battle(ISLE)
	var crossing := (Rules.BOAT_START_DIST_TILES - Rules.BOAT_STANDOFF_TILES) / Rules.BOAT_SPEED_TILES
	b.step(Rules.BOAT_FIRST_SEC)
	b.step(crossing - 0.1)
	t.eq(int(b.boat_state[0]), Battle.BoatState.SAILING, "다 오기 전에는 아직 오는 중이다")

	b.step(0.2)
	t.eq(int(b.boat_state[0]), Battle.BoatState.ARRIVED, "건널 시간이 지나면 서 있다")
	var beach := int(b.boat_beach[0])
	var target := Vector2(beach % b.grid.w, beach / b.grid.w)
	var stood: Vector2 = b.boat_pos[0]
	t.ok(absf(stood.distance_to(target) - Rules.BOAT_STANDOFF_TILES) <= NEAR,
		"선 자리가 해변 조각에서 %.1f조각 앞이다 (얻은 값 %.4f)"
			% [Rules.BOAT_STANDOFF_TILES, stood.distance_to(target)])

	b.step(10.0)
	var later: Vector2 = b.boat_pos[0]
	t.ok(stood.distance_to(later) <= NEAR, "그 뒤로 10초를 더 밀어도 안 움직인다 (얻은 값 %.5f)"
		% stood.distance_to(later))
	# ⚠ **「항해로 안 돌아간다」 이고 「그대로 서 있다」 가 아니다** (2026-09-01). Ten seconds is past
	# `Rules.BOAT_LINGER_SEC`, so by here the hull has counted itself out — **and it counted out where it
	# stood**, which is what the distance above is now measuring. The wait itself is the next row's.
	t.ok(int(b.boat_state[0]) != Battle.BoatState.SAILING, "그리고 다시 건너기 시작하지 않는다")


## **A hull that has put its 늑대 on the beach waits, and then is not there.**
##
## ⚠⚠ **THIS REVERSES 티켓 41's 「배는 쌓인다」, WHICH WAS A DELIBERATE LINE** (2026-09-01, the user:
## 「the boat should just arrive, sit for a few seconds and then disappear — call it a game-y
## allowance」). **The two halves are asserted against each other**: 「사라졌다」 alone is true of a hull
## that vanished the instant it stopped, and 「기다린다」 alone is true of one that never leaves. The row
## below the flip is the leak — **a hull that took its riders with it would satisfy both.**
func _an_emptied_hull_waits_and_is_gone(t) -> void:
	var b := _battle(ISLE)
	var crossing := (Rules.BOAT_START_DIST_TILES - Rules.BOAT_STANDOFF_TILES) / Rules.BOAT_SPEED_TILES
	b.step(Rules.BOAT_FIRST_SEC)
	b.step(crossing + 0.1)
	t.eq(int(b.boat_state[0]), Battle.BoatState.ARRIVED, "배가 다 와서 서 있다 (자가 점검)")
	t.eq(int(b.boat_riders[0]), 0, "그리고 갑판이 비었다 (자가 점검)")
	var stood: Vector2 = b.boat_pos[0]
	var landed := b.living_enemy_ids().size()
	t.eq(landed, Rules.BOAT_CAPACITY, "자가 점검 — 넷이 다 내렸다, 아니면 아래의 셈이 공허하다")

	# **Still there while the wait runs.** Without this row a hull that disappeared on the sub-step it
	# emptied is green, and 「몇 초 있다가」 would be a number nothing reads.
	b.step(Rules.BOAT_LINGER_SEC - 0.4)
	t.eq(int(b.boat_state[0]), Battle.BoatState.ARRIVED,
		"%.1f초가 안 찼으면 아직 그 자리에 있다" % Rules.BOAT_LINGER_SEC)

	b.step(0.6)
	t.eq(int(b.boat_state[0]), Battle.BoatState.GONE, "%.1f초가 지나면 없다" % Rules.BOAT_LINGER_SEC)
	t.ok((b.boat_pos[0] as Vector2).distance_to(stood) <= NEAR,
		"그런데 어디로도 안 갔다 — 되돌아 항해하는 게 아니라 선 자리에서 끊긴다 (움직인 거리 %.5f)"
			% (b.boat_pos[0] as Vector2).distance_to(stood))
	t.eq(b.boat_pos.size(), 1, "선체 줄은 그대로 하나다 — 지운 게 아니라 상태만 넘긴 것이다")
	t.eq(b.boat_state.size(), 1, "상태 칸도 그대로 하나다 (자가 점검 — 칸이 어긋나면 그림이 남의 배를 입는다)")

	# **Nothing went with it, and nothing comes out of it afterwards.**
	b.step(5.0)
	t.eq(b.living_enemy_ids().size(), landed, "사라진 뒤에도 판 위의 짐승 수가 그대로다")
	t.eq(int(b.boat_state[0]), Battle.BoatState.GONE, "그리고 다시 나타나지 않는다")


## **A hull that could not put everybody down does not leave.**
##
## ⚠⚠ **THE ONLY ROW THAT FALSIFIES THE WAIT'S RIDER GATE.** Everywhere else here the beach has room and
## the whole deck walks off in the sub-step the hull arrives, so **a wait counted from the arrival alone
## is green on every other board in this file** — and it would be carrying the leak: four riders paid
## for, three delivered, and the count that would show it is the one that just disappeared.
func _a_hull_with_riders_still_aboard_never_goes(t) -> void:
	var perch := _grid(PERCH)
	t.ok(perch.beach_ring(Rules.BOAT_START_DIST_TILES).size() > 0,
		"조각 하나짜리 섬에도 해변이 있다 (자가 점검 — 없으면 배가 아예 안 온다)")

	var b := _battle(PERCH)
	var crossing := (Rules.BOAT_START_DIST_TILES - Rules.BOAT_STANDOFF_TILES) / Rules.BOAT_SPEED_TILES
	# Well past the arrival and three times the wait, and still inside the first interval.
	#
	# ⚠⚠ **THE STEP HAS TO LAND INSIDE THE FIRST INTERVAL OR THE ROWS BELOW ARE ABOUT A SECOND HULL.**
	# It read four times the wait until 2026-09-01 and that left 0.25 초 of margin — **the small hull
	# ate it**: a shorter hull stops further out, so the crossing takes longer, and this row started
	# counting two boats. ⚠ **The self-check is here and not left to 「배가 한 척 왔다」**, which reads as
	# a boat-clock defect rather than as a fixture whose arithmetic ran out.
	var waited := Rules.BOAT_LINGER_SEC * 3.0
	t.ok(crossing + waited < Rules.BOAT_INTERVAL_SEC,
		"자가 점검 — 건너기 %.2f초에 기다림 %.2f초가 배 간격 %.1f초 안에 든다"
			% [crossing, waited, Rules.BOAT_INTERVAL_SEC])
	b.step(Rules.BOAT_FIRST_SEC + crossing + waited)
	t.eq(b.boat_pos.size(), 1, "배가 한 척 왔다 (자가 점검)")
	t.eq(int(b.boat_state[0]), Battle.BoatState.ARRIVED, "그리고 다 와서 서 있다 (자가 점검)")
	t.ok(b.living_enemy_ids().size() > 0, "설 자리가 있는 만큼은 내렸다 (자가 점검)")
	t.ok(int(b.boat_riders[0]) > 0,
		"그런데 %d 마리가 아직 갑판에 남아 있다 — 조각 하나에 다 못 선다" % int(b.boat_riders[0]))
	t.ok(int(b.boat_state[0]) != Battle.BoatState.GONE,
		"그래서 기다림이 안 돈다 — 태운 채로 사라지지 않는다")


## **On the real island, because「the other side」 is a fact about a real coast.**
##
## ⚠ **The separation is derived, not read off a run**: the stride moves the cursor about
## `Rules.BOAT_BEACH_TURN` of the way round, so the two beaches stand roughly that fraction of a full
## turn apart as seen from the island's middle. Asserted as「more than a quarter turn」rather than as
## the angle itself, because the stride is rounded to a whole 조각 and then nudged to the nearest
## coprime one — the exact angle is a consequence of the ring's size, and the claim is 「a different
## side」.
func _the_second_boat_comes_one_interval_later_and_far_round(t) -> void:
	var b := _battle_real()
	b.step(Rules.BOAT_FIRST_SEC + Rules.BOAT_INTERVAL_SEC - 0.1)
	t.eq(b.boat_pos.size(), 1, "한 간격이 차기 전에는 아직 한 척이다")

	b.step(0.2)
	t.eq(b.boat_pos.size(), 2, "한 간격 뒤에 둘째가 뜬다")
	var a0 := int(b.boat_beach[0])
	var a1 := int(b.boat_beach[1])
	t.ok(a0 != a1, "그리고 첫 배와 다른 조각으로 온다 (%d · %d)" % [a0, a1])

	var centre := b.grid.island_centre()
	var v0 := Vector2(a0 % b.grid.w, a0 / b.grid.w) - centre
	var v1 := Vector2(a1 % b.grid.w, a1 / b.grid.w) - centre
	var apart := absf(rad_to_deg(v0.angle_to(v1)))
	t.ok(apart > 90.0, "섬 가운데에서 보면 둘이 %.0f도 떨어져 있다 — 옆이 아니라 반대편이다" % apart)

	# ⚠⚠ **THE FIRST ONE IS ALREADY GONE BY THE TIME THE SECOND IS BORN** (2026-09-01), which is a fact
	# about the SCREEN and not only about this array: it landed at about 23 seconds and waited
	# `Rules.BOAT_LINGER_SEC`. **Two hulls are never on the water together any more.** ⚠ Its ROW is still
	# here and still index 0 — that is what keeps 「둘째」 meaning the second boat.
	t.eq(int(b.boat_state[0]), Battle.BoatState.GONE, "먼저 온 배는 이미 사라졌다")
	t.eq(int(b.boat_state[1]), Battle.BoatState.SAILING, "둘째는 오는 중이다")


## **What the sim actually STORED, on the real island, for beaches that really do have land jutting out
## in front of them.**
##
## ⚠⚠ **EVERY OTHER ROW ABOUT THE STOP RECOMPUTES IT, AND RECOMPUTING IS NOT READING.** The bow row
## takes `Grid.land_reach_along` and adds the standoff — that measures `Grid`'s arithmetic and says
## nothing about whether `Battle` used it. **Measured: reverting `Battle` to the old
## `centre + seaward * STANDOFF` reddened NOTHING in this file**, which is the same defect the game
## shipped, sitting inside the net that was supposed to catch it.
##
## ⚠ **On the real island and not the fixture.** `ISLE` is a rectangle: nothing juts out of it, every
## `lead` is 0, and the two formulas agree — a fixture where the bug is invisible cannot catch the bug.
## ⚠ **Eight boats, because one is not enough**: the first beach in the ring may be a clean straight
## approach, and then this row is green for a boat the defect never touched. The self-check below
## refuses the round if none of the eight is a jutting one.
func _the_stored_stop_is_measured_from_the_water(t) -> void:
	var probe := _real()
	var ring := probe.beach_ring(Rules.BOAT_START_DIST_TILES)
	# Which beaches actually have land jutting seaward of them — the only ones on which the two formulas
	# differ at all, and therefore the only ones this row can be written on.
	# The beaches the outline pushes past the 조각 floor — the only ones on which the two rules differ,
	# and therefore the only ones this row can be written on. ⚠ **It used to look for 「jutting」 land on
	# the approach line; there is none left in the ring**, because those 조각 are now stopped correctly
	# or dropped.
	var juts := []
	for k in ring.size():
		var tile := int(ring[k])
		if _sim_stop(probe, tile, probe.seaward_at(tile)) > Rules.BOAT_STANDOFF_TILES + NEAR:
			juts.append(k)
	t.ok(juts.size() > 0,
		"고리 %d 곳 중 %d 곳은 그려진 윤곽이 더 밀어낸다 (자가 점검 — 0이면 아래가 전부 공허하다)"
			% [ring.size(), juts.size()])

	# ⚠⚠ **THE CURSOR IS SET BY HAND RATHER THAN WAITED FOR.** Left to itself the stride walks the ring
	# in its own order, and the first eight boats of a round happened to be **eight straight approaches**
	# — measured, and the self-check above is what caught it. Waiting for a jutting one would mean
	# stepping most of an hour of simulated time.
	# ⚠ **`_beach_cursor` is set AFTER `setup`**, which resets it.
	var wrong := []
	var checked := 0
	for k in mini(juts.size(), 4):
		var idx := int(juts[k])
		var b := _battle_on(_real())
		b._beach_cursor = idx
		b.step(Rules.BOAT_FIRST_SEC)
		if b.boat_pos.is_empty():
			continue
		checked += 1
		var beach := int(b.boat_beach[0])
		var dir := b.grid.seaward_at(beach)
		var lead := _land_reach(b.grid, beach, dir, Rules.BOAT_START_DIST_TILES)
		# ⚠ **The larger of the two rules**, rebuilt here: the 조각 grid is a floor and the drawn shore can
		# ask for more. A row that expected the 조각 answer alone would go red the moment the outline
		# pushed a hull further out, which is the fix and not a defect.
		var want_d := _hull_stop(b.grid, beach, dir, lead + Rules.BOAT_STANDOFF_TILES)
		var want := Vector2(beach % b.grid.w, beach / b.grid.w) + dir * want_d
		# ⚠ **The sweep's own step is the tolerance, not `NEAR`.** `Grid` solves this on the crossings
		# and lands on an exact number; this file WALKS it in 0.02 조각 steps, so the two agree to a step
		# and not to a float. **A tighter tolerance here would be measuring the step size**, and a looser
		# one would stop measuring the answer.
		if (b.boat_stop[0] as Vector2).distance_to(want) > 0.03:
			wrong.append(beach)
		if _hull_touches_drawn_land(b.grid, beach, dir, b.boat_stop[0] as Vector2):
			wrong.append(beach)
	t.eq(checked, mini(juts.size(), 4), "밀려난 해변 %d 곳에 배를 실제로 띄웠다 (자가 점검)" % checked)
	t.eq(wrong.size(), 0, "그 배들이 다 윤곽에서 잰 자리에 선다 — 해변까지의 거리로 잰 게 아니다 %s"
		% str(wrong))


## **What the bow actually clears on screen, measured against the outline the mesh was cut to.**
##
## ⚠⚠ **THE RING AND THE STOP WALK `Grid.passable`; THE PLAYER SEES `Islands.coast()`.** The first is a
## square 조각 table. The second is the line Blender ended the island on — corners cut, edges pushed,
## bending only on block boundaries — and it does **not** run along 조각 edges. **A row that says 「the
## bow clears the shore by 0.60」 while measuring 조각 is the label-promises-more failure this repo
## keeps paying for**, and the rendered frame said 0.93 / 0.50 / 0.39 where the grid said 0.60 all three
## times.
##
## ⚠ **The question here is not 「do the two agree」 — they do not and need not.** It is **「can the drawn
## clearance reach zero」**: if the outline cuts further seaward of a 조각's centre than the gap, there
## is a beach where the hull touches drawn land while the grid says it is clear. **That is the only
## thing that would move any code**, and it is the last row below.
func _the_drawn_shore_is_not_the_tile_grid(t) -> void:
	var grid := _real()
	var ring := grid.beach_ring(Rules.BOAT_START_DIST_TILES)
	var coast := Islands.coast()
	t.ok(coast.size() > 0, "구워진 윤곽이 %d 토막이다 (자가 점검 — 0이면 아래가 전부 공허하다)" % coast.size())
	# ⚠⚠ **AND THAT THE BOARD ACTUALLY GOT IT.** Every rule that reads the outline falls back to the
	# 조각 grid when `Grid.coast` is empty, and **so does every check in this file** — so cutting the
	# outline out of `Islands.load_into` degraded both sides together and reddened NOTHING. **This is
	# the one row that can tell 「the outline is honoured」 from 「there is no outline」.**
	# ⚠⚠ **THE INSTRUMENT IS CALIBRATED BEFORE IT IS BELIEVED.** 「Inside the outline」 has to agree with
	# `passable` 조각 by 조각, or every footprint answer below is measuring the reader's own bug. This is
	# the same score the offset was calibrated on: **+0.5 agrees on 100%, +0.0 on 94.4%, -0.5 on 88.5%.**
	var agree := 0
	var total := 0
	for tile_c in grid.passable.size():
		var pt := Vector2(tile_c % grid.w, tile_c / grid.w) + Vector2(0.5, 0.5)
		total += 1
		if _inside_coast(grid.coast, pt) == (grid.passable[tile_c] != 0):
			agree += 1
	t.eq(agree, total, "안팎 판정이 %d 조각 전부에서 passable 과 일치한다 (%d)" % [total, agree])

	t.eq(grid.coast.size(), coast.size(),
		"그리고 판이 그 윤곽을 실제로 들고 있다 — 빈 채로 두면 규칙도 검사도 조각 격자로 내려앉는다")

	var tightest := 9999.0
	var widest := -9999.0
	# The outline's own numbers, kept apart from the clearance so the row below cannot be satisfied by
	# the 조각 grid varying on its own — **measured: it was.**
	var edge_lo := 9999.0
	var edge_hi := -9999.0
	var seen := {}
	for k in ring.size():
		var tile := int(ring[k])
		var dir := grid.seaward_at(tile)
		# ⚠ **`+0.5`** — the outline lives half a 조각 off raw tile coordinates. **An earlier round measured
		# this from the raw coordinate and answered -0.97 where an independent instrument said -0.23**;
		# the difference is one diagonal half-조각.
		var here := Vector2(tile % grid.w, tile / grid.w) + Vector2(0.5, 0.5)
		# ⚠ **The bow where the boat ACTUALLY stops**, which is the larger of the 조각 rule and the drawn
		# one — not the 조각 rule alone. Reading the grid's answer here made these three numbers land on
		# 0.01 / -0.01 / -0.01 and mean nothing.
		var bow := _sim_stop(grid, tile, dir) - Rules.BOAT_HULL_HALF_TILES
		var edge := _coast_crossing(coast, here, dir, Rules.BOAT_STANDOFF_TILES + 1.0)
		var drawn := bow - edge
		tightest = minf(tightest, drawn)
		widest = maxf(widest, drawn)
		edge_lo = minf(edge_lo, edge)
		edge_hi = maxf(edge_hi, edge)
		seen[tile] = drawn

	# The three the screen was scanned on, carried in the label so both measurements can be read on one
	# line. ⚠ **Not asserted** — see the block below on why this instrument is not trusted to a number.
	var named := ""
	for raw in [4 + 9 * 30, 14 + 2 * 30, 21 + 6 * 30]:
		var tile2 := int(raw)
		if seen.has(tile2):
			named += " (%d,%d)=%.2f" % [tile2 % grid.w, tile2 / grid.w, float(seen[tile2])]

	# **The claim this row actually makes, and the only one it can stand behind: the two boundaries are
	# not the same boundary.** The grid answers `BOAT_BEACH_GAP_TILES` for every beach on the ring; the
	# baked outline answers a spread. **That is what makes 「0.60 from the shore」 a wrong label** and
	# 「0.60 from the 조각 grid」 a right one, which is the whole point of measuring this.
	# ⚠⚠ **ASSERTED ON THE OUTLINE'S OWN CROSSINGS AND NOT ON THE CLEARANCE.** A first draft asserted the
	# clearance spread — and **neutering the coast reader entirely left it green**, because `bow` already
	# varies by itself wherever a headland juts. **The row has to bite on the thing it claims to read.**
	t.ok(edge_hi - edge_lo > 0.01,
		"구워진 윤곽이 조각 중심에서 해변마다 다른 거리에 있다 — %.2f 부터 %.2f 까지 (조각 격자라면 전부 같은 값이다)"
			% [edge_lo, edge_hi])
	t.ok(widest - tightest > 0.01,
		"그려진 윤곽과 조각 격자가 다른 경계다 — 그려진 여유가 좁은 쪽 %.2f, 넓은 쪽 %.2f 로 갈리는데 조각 격자로는 전부 %.2f 다.%s"
			% [tightest, widest, Rules.BOAT_BEACH_GAP_TILES, named])

	# ⚠⚠ **THE ZERO QUESTION IS DELIBERATELY NOT ASSERTED HERE, AND THAT IS A REFUSAL RATHER THAN AN
	# OMISSION.** 「Can the drawn clearance reach zero」 is what would move code, and this instrument
	# answers YES — 25 of the 67 at or below zero, worst about -0.97 조각. **The rendered frame says
	# no**: eight arrivals scanned pixel-wise, no bow on turf, and on the one beach both were pointed at
	# — (21,6) — the pixel scan read +0.39 where this reads -0.52.
	#
	# ⇒ **Two instruments, one disagreement, and no way to tell from here which is right.** This one is
	# a top-down ray against the outline; that one is a silhouette in a tilted, turned camera. **A red
	# row built on the measure that loses the comparison would be this repo's own named failure — a
	# check that is confident about something it cannot see.** The numbers are in the label above and
	# the disagreement is reported to whoever can look at the screen.
	# ⚠ **Do not "fix" this by asserting the number this file happens to produce.**


func _the_riders_are_aboard_and_not_on_the_board(t) -> void:
	var b := _battle(ISLE)
	b.step(Rules.BOAT_FIRST_SEC)
	t.eq(int(b.boat_riders[0]), Rules.BOAT_CAPACITY, "첫 배에 넷이 타 있다")

	# Nothing landed. **Both halves**: no body is standing, and no 조각 is claimed by one.
	t.eq(b.ashore_ids().size(), 0, "그런데 판 위에 선 몸은 하나도 없다")
	# ⚠ **Counted over `Grid.hold_count` and not by indexing `reserved`.** That array is
	# `Rules.TILE_CAPACITY` slots per 조각 since 2026-08-30, so a raw index names a slot of some other
	# 조각 entirely — a plausible number for the wrong place, which is this repo's own named false green.
	var claimed := 0
	for tile in b.grid.w * b.grid.h:
		claimed += b.grid.hold_count(tile)
	t.eq(claimed, 0, "판의 어느 조각도 잡혀 있지 않다 — 아직 아무도 안 내렸다")

	# ⚠⚠ **THE SECOND HALF USED TO READ 「다 와서도 여덟이 그대로 타 있다」 AND IT IS DEAD** (2026-08-30).
	# 티켓 41's 목~일 slice unloads an ARRIVED boat, so that row now asserts the landing away. **What
	# survives is the claim this file actually owns — the CROSSING**: a hull still at sea carries every
	# one of its riders and puts nobody on the board. **The landing itself is `net_fight`'s subject** and
	# is not re-measured here; two files measuring one rule is how they come to disagree.
	b.step((Rules.BOAT_START_DIST_TILES - Rules.BOAT_STANDOFF_TILES) / Rules.BOAT_SPEED_TILES - 0.5)
	t.eq(int(b.boat_state[0]), Battle.BoatState.SAILING, "아직 건너는 중이다 (자가 점검)")
	t.eq(int(b.boat_riders[0]), Rules.BOAT_CAPACITY, "건너는 내내 넷이 그대로 타 있다")
	t.eq(b.ashore_ids().size(), 0, "그리고 판 위에 선 몸은 여전히 없다")
	var claimed_late := 0
	for tile2 in b.grid.w * b.grid.h:
		claimed_late += b.grid.hold_count(tile2)
	t.eq(claimed_late, 0, "잡힌 조각도 여전히 없다 — 바다 위의 늑대는 판에 없다")


## **The same crossing at 1x and at a tenth of the frame rate.** `step` decomposes into whole sub-steps,
## so a boat driven one frame at a time and one driven in fat chunks must land on the same 조각.
## ⚠ **Position AND beach 조각 both**, because a stride that read a frame counter instead of a launch
## counter would diverge in the beach and never in the position.
func _the_crossing_is_the_same_at_any_frame_rate(t) -> void:
	var fine := _battle(ISLE)
	var coarse := _battle(ISLE)
	var total := Rules.BOAT_FIRST_SEC + Rules.BOAT_INTERVAL_SEC + 3.0
	var n := int(round(total * 60.0))
	for _i in n:
		fine.step(1.0 / 60.0)
	coarse.step(total)

	t.eq(fine.boat_pos.size(), coarse.boat_pos.size(), "두 프레임률이 같은 수의 배를 띄운다")
	t.eq(fine.substeps, coarse.substeps, "서브스텝 횟수 자체가 같다 (자가 점검)")
	var drift := 0.0
	var beach_differs := 0
	for i in mini(fine.boat_pos.size(), coarse.boat_pos.size()):
		drift = maxf(drift, (fine.boat_pos[i] as Vector2).distance_to(coarse.boat_pos[i]))
		if int(fine.boat_beach[i]) != int(coarse.boat_beach[i]):
			beach_differs += 1
	t.ok(drift <= NEAR, "그리고 배가 선 자리도 같다 (어긋난 거리 %.6f)" % drift)
	t.eq(beach_differs, 0, "겨눈 조각도 같다")


## **A board with no coast launches nothing, and stepping it does not fall over.** The ring is the only
## thing that decides where a boat may aim, so an empty ring has to be a case rather than a crash.
func _a_board_with_no_coast_launches_nothing(t) -> void:
	var grid := _grid(DRY)
	t.eq(grid.beach_ring(Rules.BOAT_START_DIST_TILES).size(), 0, "물이 없는 판에는 해변이 없다 (자가 점검)")
	var b := _battle(DRY)
	b.step(Rules.BOAT_FIRST_SEC + Rules.BOAT_INTERVAL_SEC + 1.0)
	t.eq(b.boat_pos.size(), 0, "그런 판에서는 배가 한 척도 안 뜬다")
	t.ok(b.elapsed > Rules.BOAT_FIRST_SEC, "그래도 시계는 돌았다 (자가 점검)")


## **`Battle.boats_come` decides whether the drip happens at all, and BOTH arms are driven here.**
## 2026-09-03, the user: 「일단 이제 늑대 안와도 됨」 — *"For now the wolves don't have to come any
## more."*
##
## ⚠⚠ **THE TWO BOARDS ARE THE SAME BOARD AND THE DRIVE IS THE SAME NUMBER.** A 「no boat」 measured on
## a board or a drive the ON arm never saw would be green for a fixture that could not have launched
## one anyway — which is exactly what `_a_board_with_no_coast_launches_nothing` is, and why that row
## cannot stand in for this one.
##
## ⚠⚠ **THE ON ARM IS WHAT FALSIFIES THIS CHECK ITSELF.** Without it, 「하나도 안 온다」 stays green if
## the drive is too short, if the fixture has no coast, or if `step` stopped stepping — three ways to
## pass while measuring nothing. With it, the same board and the same seconds must produce boats.
##
## ⚠ **The DEFAULT is what the ON arm reads**, never `boats_come = true` written back in. Every other
## net in this repo builds a `Battle` and expects boats; if that default flipped, this row is where it
## is caught rather than in the twenty rows above that would silently stop measuring a crossing.
func _the_switch_decides_whether_boats_come_at_all(t) -> void:
	# Four intervals past the first launch — long enough that 「아직 이르다」 cannot be the reason.
	var driven := Rules.BOAT_FIRST_SEC + Rules.BOAT_INTERVAL_SEC * 4.0 + 1.0

	var on := _battle_real()
	t.ok(on.boats_come, "새로 지은 Battle 은 배가 오는 쪽이다 — 기본값이 뒤집히면 여기서 잡힌다")
	on.step(driven)
	t.ok(on.boat_pos.size() > 0,
		"켠 채로 %.0f초를 돌리면 배가 %d척 왔다 (자가 점검 — 안 오면 아래가 공허하다)"
			% [driven, on.boat_pos.size()])

	var off := _battle_real()
	off.boats_come = false
	off.step(driven)
	t.eq(off.boat_pos.size(), 0, "끈 채로 같은 판을 같은 %.0f초 돌리면 한 척도 안 온다" % driven)
	t.eq(off.living_enemy_ids().size(), 0, "그래서 늑대도 한 마리 안 내린다")
	t.ok(absf(off.elapsed - on.elapsed) <= NEAR,
		"두 판의 시계가 같은 데까지 갔다 (%.3f · %.3f) — 끈 쪽이 덜 돈 게 아니다"
			% [off.elapsed, on.elapsed])


## **With the switch on, the clock is untouched: the first boat is still at 5.0 s and the second at
## 35.0 s.** The two rows above measure that boats come at all; this measures that the switch did not
## quietly become a delay on the way in.
##
## ⚠ **The boundary is asserted from BOTH sides at each launch** — a hair before, nothing new; a hair
## after, one more. A one-sided 「there are two by 35 s」 is green for a drip that fires everything on
## the first sub-step.
func _the_switch_on_leaves_the_launch_times_where_they_were(t) -> void:
	var b := _battle_real()
	t.ok(b.boats_come, "이 판은 켜져 있다 (자가 점검)")

	b.step(Rules.BOAT_FIRST_SEC - 0.1)
	t.eq(b.boat_pos.size(), 0, "5.0초 직전에는 아직 없다")
	b.step(0.2)
	t.eq(b.boat_pos.size(), 1, "5.0초에 첫 배가 뜬다")

	b.step(Rules.BOAT_INTERVAL_SEC - 0.2)
	t.eq(b.boat_pos.size(), 1, "35.0초 직전까지는 그대로 한 척이다")
	b.step(0.2)
	t.eq(b.boat_pos.size(), 2, "35.0초에 둘째가 뜬다")


# == the hull the deck offsets were read off ===========================================================

## **`Look.BOAT_DECK_SLOTS` is twelve numbers copied out of the arriving hull, and this is what stops
## them being a second copy of it.** Offsets sitting in `look.gd` with nothing tying them to the benches
## they were measured from is exactly the shape this repo has watched rot: the mesh gets re-exported
## with a bench moved, the constants stay, and the wolves stand in mid-air with every check green.
##
## ⚠⚠ **NOTHING HERE IS READ BY NODE NAME ANY MORE** (2026-09-01). `boat.glb` carried `boat_stem`,
## `boat_tail` and `boat_bench_0..3` as separate objects and this row asked for them by name;
## `boat_small.glb` is **one joined mesh**, so the bow and the benches are found in the geometry
## instead. ⚠ **That is not a loosening**: a name can sit on a node somebody moved anywhere, while the
## vertices cannot lie about where a plank is.
##
## ⚠ **It also proves the file loads at all.** `boat.glb` had never been imported by Godot before 티켓
## 41 — no `.import` sat beside it — and everything else in this net would stay green if the load came
## back null, because the sim's boat is a `Vector2` and knows nothing about a mesh.
##
## ⚠ **The scene is INSTANTIATED and freed, never added to a tree.** An orphan node has no viewport and
## draws nothing; this reads authored transforms and lets go.
func _the_deck_offsets_are_the_mesh_s_own_benches(t) -> void:
	var packed := load(FieldView.BOAT_SCENE) as PackedScene
	t.ok(packed != null, "배 메시가 PackedScene 으로 읽힌다")
	if packed == null:
		return
	var hull := packed.instantiate() as Node3D
	t.ok(hull != null, "그리고 Node3D 하나로 세워진다")
	if hull == null:
		return

	var pts := _mesh_points(hull, "")
	t.ok(pts.size() > 0, "선체 정점을 실제로 읽었다 (자가 점검 — 0이면 아래가 전부 공허하다)")

	# The bow. `_boat_yaw` turns the model's +X along the heading, and that is only right because the
	# sharp end is the positive one — a re-export that turned the hull round would sail every boat
	# backwards with every position check in this file still green.
	# ⚠ **Asked of the shape, in the last fifth at each end.** The named `boat_stem` and `boat_tail`
	# went with the big hull, and a joined mesh answers 「which end is sharp」 only by how wide it is
	# there.
	var end_x := Rules.BOAT_HULL_HALF_TILES * 0.8
	var fore := 0.0
	var aft := 0.0
	for raw_p in pts:
		var p := raw_p as Vector3
		if p.x >= end_x:
			fore = maxf(fore, absf(p.z))
		elif p.x <= -end_x:
			aft = maxf(aft, absf(p.z))
	t.ok(fore > 0.0 and aft > 0.0, "양 끝 오분의 일에 정점이 있다 (자가 점검)")
	t.ok(fore < aft, "뱃머리 쪽 끝이 고물 쪽보다 좁다 — 배의 앞이 +X 다 (%.3f < %.3f)" % [fore, aft])

	t.eq(Look.BOAT_DECK_SLOTS.size(), Rules.BOAT_CAPACITY,
		"자리가 탈 수 있는 수만큼 있다 — 넷에 넷")

	# ⚠⚠ **`Rules.BOAT_HULL_HALF_TILES` IS READ BACK OFF THE MESH'S OWN BOX.** It is the number the
	# standoff is built on, and a hull re-exported longer would put the bow back on the grass with every
	# distance check in this file still green — the sim's boat is a point and a point is never aground.
	var box := _hull_box(hull)
	t.ok(box.size.x > 0.0, "선체 상자를 실제로 읽었다 (자가 점검)")
	t.ok(absf(box.size.x * 0.5 - Rules.BOAT_HULL_HALF_TILES) < 0.05,
		"선체 반길이가 %.2f 조각이다 — 규칙이 든 값(%.2f)과 같다"
			% [box.size.x * 0.5, Rules.BOAT_HULL_HALF_TILES])
	# ⚠⚠ **THE BEAM TOO, AND WITHOUT IT THE SHOULDER IS UNMEASURED.** The stop sweeps the hull's width
	# and this file sweeps the same width from the same constant — **so zeroing that constant collapsed
	# both to the centre line and reddened nothing.** Reading it back off the mesh is what breaks the
	# tie: the model is the third party neither side controls.
	t.ok(absf(box.size.z - Rules.BOAT_HULL_BEAM_TILES) < 0.05,
		"선체 너비가 %.2f 조각이다 — 규칙이 든 값(%.2f)과 같다"
			% [box.size.z, Rules.BOAT_HULL_BEAM_TILES])
	t.ok(absf(box.position.x + box.size.x * 0.5) < 0.05,
		"그리고 원점이 길이 한가운데다 — 반길이가 뱃머리까지의 거리다 (%.3f)"
			% (box.position.x + box.size.x * 0.5))
	# The keel, which is what `Look.BOAT_DRAFT_TILES` is measured against.
	t.ok(absf(box.position.y) < 0.05,
		"바닥이 원점 높이다 — 흘수는 여기서부터 잰다 (%.3f)" % box.position.y)

	# ⚠⚠ **THE END POSTS WEAR THE BENCH MATERIAL TOO, AND THEY ARE NOT BENCHES.** Four runs of bench
	# geometry stand along the hull; the two amidships cross the whole beam and the two at the ends are
	# 0.27 and 0.13 조각 wide. **Taking every run would hand back four planks and two of them would have
	# no seat table to match**, so the filter is 「crosses more than the half-beam」 and the half-beam
	# comes off `Rules` rather than being typed here.
	var planks := _thwarts(_mesh_points(hull, "bench"), Rules.BOAT_HULL_BEAM_TILES * 0.5)
	t.eq(planks.size(), Look.BOAT_DECK_SLOTS.size() / 2,
		"빔을 가로지르는 판자가 자리 표의 절반만큼 있다 — 자리 둘에 판자 하나 %s" % str(planks))
	# ⚠ **A wrong count leaves rather than indexing off the end.** Measured: without this the row above
	# goes red and the function then dies on the seat index, and the runner's own header says a net that
	# dies half way reports a partial pass count in a shape a healthy net cannot be told from.
	if planks.size() != Look.BOAT_DECK_SLOTS.size() / 2:
		hull.free()
		return

	var off_bench := []
	for k in planks.size():
		var plank: AABB = planks[k]
		# Two seats a bench, a quarter of the plank's own width either side of its middle.
		var want_x := plank.position.x + plank.size.x * 0.5
		var want_y := plank.position.y + plank.size.y
		var want_z := plank.size.z * 0.25
		for side in 2:
			var slot: Vector3 = Look.BOAT_DECK_SLOTS[k * 2 + side]
			var sign_z := -1.0 if side == 0 else 1.0
			if absf(slot.x - want_x) > NEAR:
				off_bench.append("%d 번 자리의 x %.3f · 판자 %.3f" % [k * 2 + side, slot.x, want_x])
			if absf(slot.y - want_y) > NEAR:
				off_bench.append("%d 번 자리의 y %.4f · 판자 위 %.4f" % [k * 2 + side, slot.y, want_y])
			if absf(slot.z - sign_z * want_z) > NEAR:
				off_bench.append("%d 번 자리의 z %.3f · 판자 폭의 4분의 1 %.3f"
					% [k * 2 + side, slot.z, sign_z * want_z])
	t.eq(off_bench.size(), 0, "네 자리가 전부 제 판자 위다 %s" % str(off_bench))
	hull.free()


## Every vertex of the surfaces whose material name holds `tag`, in the hull's own space. **An empty
## `tag` takes every surface.**
## ⚠ **The mesh and not a node.** `boat_small.glb` is one object, so the only thing that can say where a
## bench is, is the geometry wearing the bench material.
func _mesh_points(n: Node3D, tag: String) -> Array:
	var out := []
	for raw in _mesh_children(n):
		var mi: MeshInstance3D = raw
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			if tag != "":
				var mat := mi.mesh.surface_get_material(s)
				if mat == null:
					mat = mi.get_surface_override_material(s)
				if mat == null or not mat.resource_name.contains(tag):
					continue
			var arrays := mi.mesh.surface_get_arrays(s)
			if arrays.size() <= Mesh.ARRAY_VERTEX:
				continue
			for v in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				out.append(mi.transform * v)
	return out


## The given points cut into runs along the hull's length, keeping only the runs that cross more than
## `half_beam`, ordered stern to bow. **One box per plank somebody sits on.**
##
## ⚠⚠ **THE CUT IS 0.3 조각 OF EMPTY x, AND THE WINDOW IT SITS IN IS BOTH-SIDED.** A box has vertices
## only at its two end faces, so **a cut narrower than a plank is thick splits every plank into two
## slabs of zero length** — measured: at 0.1 this handed back four flat boxes for two benches. The
## planks are 0.135 thick, and the narrowest empty run between two pieces of bench geometry is 0.557
## 조각, so the cut has to sit between those two. ⚠ **Either wall of that window fails loudly** — too
## narrow doubles the plank count, too wide merges two planks into one — and the count asserted above
## is what catches both.
func _thwarts(pts: Array, half_beam: float) -> Array:
	if pts.is_empty():
		return []
	var xs := []
	for raw in pts:
		xs.append((raw as Vector3).x)
	xs.sort()
	var runs := []
	var lo: float = xs[0]
	var prev: float = xs[0]
	for k in range(1, xs.size()):
		var x: float = xs[k]
		if x - prev > 0.3:
			runs.append([lo, prev])
			lo = x
		prev = x
	runs.append([lo, prev])

	var out := []
	for raw_run in runs:
		var run: Array = raw_run
		var box := AABB()
		var first := true
		for raw_p in pts:
			var p := raw_p as Vector3
			if p.x < float(run[0]) - NEAR or p.x > float(run[1]) + NEAR:
				continue
			if first:
				box = AABB(p, Vector3.ZERO)
				first = false
			else:
				box = box.expand(p)
		if not first and box.size.z > half_beam:
			out.append(box)
	out.sort_custom(func(a, c): return (a as AABB).position.x < (c as AABB).position.x)
	return out


## Every mesh under `n`, merged into one box in `n`'s own space. **The model's real extent**, which is
## what a length taken off it has to agree with.
func _hull_box(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for raw in _mesh_children(n):
		var mi: MeshInstance3D = raw
		if mi.mesh == null:
			continue
		var one := mi.transform * mi.mesh.get_aabb()
		if first:
			box = one
			first = false
		else:
			box = box.merge(one)
	return box


func _mesh_children(n: Node) -> Array:
	var out := []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_mesh_children(c))
	return out


# == fixtures =========================================================================================

func _grid(rows: Array) -> Grid:
	var g := Grid.new()
	g.load_rows(rows)
	return g


func _real() -> Grid:
	var g := Grid.new()
	Islands.load_into(g)
	return g


## A battle on `rows` with the real opening force. **The soldiers are there on purpose**: 「아무도 안
## 내렸다」 measured on an empty roster is measured on nothing.
func _battle(rows: Array) -> Battle:
	return _battle_on(_grid(rows))


func _battle_real() -> Battle:
	return _battle_on(_real())


func _battle_on(g: Grid) -> Battle:
	var army := Army.new()
	army.add_starting_force()
	var b := Battle.new()
	b.setup(g, army, [])
	return b


## Where boat `i` is going to come to rest, rebuilt here from the beach 조각 and the board rather than
## read out of the battle — a stop point read back from the thing under test proves nothing about it.
##
## ⚠⚠ **THIS CARRIED THE SAME BLIND SPOT AS THE CODE IT CHECKS, AND THAT IS WHY IT CAUGHT NOTHING.** It
## read `target + seaward * STANDOFF`, measuring to the beach 조각 and ignoring any headland nearer on
## the line — **exactly the defect that put two hulls in four on the grass.** Mutating `Battle` back to
## that formula reddened nothing, because the net was computing the same wrong number to compare
## against. ⇒ **the lead comes from this file's OWN walker**, never from `Grid.land_reach_along`.
func _stop_point(b: Battle, i: int) -> Vector2:
	var beach := int(b.boat_beach[i])
	var target := Vector2(beach % b.grid.w, beach / b.grid.w)
	var dir := b.grid.seaward_at(beach)
	var lead := _land_reach(b.grid, beach, dir, Rules.BOAT_START_DIST_TILES)
	return target + dir * (lead + Rules.BOAT_STANDOFF_TILES)


## Every 조각 the two sets disagree about: in the ring but not a beach, or a beach and not in the ring.
##
## **A beach is three things at once** — land with water beside it, walkable to the rest of the island,
## and with room for a hull to stop in front of IT rather than in front of some other headland.
## ⚠ **All three are recomputed here from `passable`, `water`, `main_land` and this file's OWN line
## walker**, so this is a claim about the board and not a read-back of whatever the ring decided.
func _ring_disagrees_with_the_board(grid: Grid, ring: PackedInt32Array) -> Array:
	var in_ring := {}
	for k in ring.size():
		in_ring[int(ring[k])] = true
	var main := grid.main_land()
	var reach := Rules.BOAT_START_DIST_TILES
	var bad := []
	for tile in grid.passable.size():
		var is_beach := grid.passable[tile] != 0 and main[tile] != 0 and _touches_water(grid, tile)
		if is_beach:
			# **A hull has to fit in front of it, and it has to be THIS beach it fits in front of.**
			var lead := _land_reach(grid, tile, grid.seaward_at(tile), reach)
			is_beach = lead < Rules.BOAT_STANDOFF_TILES and lead + Rules.BOAT_STANDOFF_TILES < reach
			# ⚠⚠ **THIS TERM IS READ BACK OFF THE SUBJECT AND THE OTHER TWO ARE NOT, AND THAT IS A COST
			# STATED RATHER THAN HIDDEN.** 「Can a hull stand near this 조각」 is a search, and running
			# this file's own sweep for all 88 candidates is minutes rather than seconds. **The
			# footprint rows below are what measure the answer independently** — this one only measures
			# that the ring's membership follows the rule the stop actually uses.
			if is_beach:
				is_beach = _sim_stop(grid, tile, grid.seaward_at(tile)) 						<= Rules.BOAT_STANDOFF_TILES + Rules.BOAT_HULL_HALF_TILES
		if is_beach != in_ring.has(tile):
			bad.append(tile)
	return bad


func _touches_water(grid: Grid, tile: int) -> bool:
	var tx := tile % grid.w
	var ty := tile / grid.w
	for k in Grid.NEIGHBOURS.size():
		var nx := tx + int(Grid.NEIGHBOURS[k][0])
		var ny := ty + int(Grid.NEIGHBOURS[k][1])
		if nx < 0 or ny < 0 or nx >= grid.w or ny >= grid.h:
			continue
		if grid.water[ny * grid.w + nx] != 0:
			return true
	return false


## **Where the baked outline crosses the ray, in 조각 — the crossing NEAREST the 조각's own centre.**
##
## ⚠⚠ **NEAREST AND NOT OUTERMOST, AND THE DIFFERENCE WAS MEASURED.** A first draft took the outermost
## crossing within a few 조각 and answered that 30 of 67 beaches had the hull on drawn land, worst by
## 2.41 조각 — **against a rendered frame in which no bow touched turf on any of eight arrivals.** The
## outline is a closed loop: a ray leaving the island crosses it once at the shore and can clip a
## neighbouring headland's loop further out, and that far crossing is not land under the hull. **The
## beach 조각's centre sits on the shore, so the shore is the crossing nearest it.**
## ⚠ Checked against the screen on the three arrivals it was scanned on: this answers 0.53 / 0.48 /
## 0.39 where the pixel scan said 0.93 / 0.50 / 0.39 — see the row that reads them.
##
## ⚠ **Negative is a real answer and not a floor**: the outline can run INLAND of a 조각's own centre,
## and where it does the drawn clearance is wider than the grid's. Clamping at 0 would hide exactly the
## half of the spread that is not a defect.
## ⚠ Ray against segment, solved rather than sampled — the outline is straight pieces, so there is
## nothing here to approximate.

## **How far seaward of `tile`'s own centre the land on its approach line reaches** — this file's own
## answer to `Grid.land_reach_along`, so the two can be compared instead of one trusting the other.
## **What the subject says the stop is** — the 조각 floor handed to `Grid.hull_stop_along`. ⚠ **Read
## back on purpose here**: the rows that use it are testing the hull's FOOTPRINT against the outline
## with this file's own instrument, and the stop is the input to that question, not its answer.
func _sim_stop(grid: Grid, tile: int, dir: Vector2) -> float:
	var floor_d := grid.land_reach_along(tile, dir, Rules.BOAT_START_DIST_TILES) 			+ Rules.BOAT_STANDOFF_TILES
	var got := grid.hull_stop_along(tile, dir, Rules.BOAT_HULL_HALF_TILES,
			Rules.BOAT_HULL_BEAM_TILES * 0.5, Rules.BOAT_BEACH_GAP_TILES, floor_d)
	return floor_d if got == -INF else got


## **Where the hull must stop for its forward footprint to clear the drawn shore** — this file's own
## answer to `Grid.hull_stop_along`, so the two can be compared instead of one trusting the other.
func _hull_stop(grid: Grid, tile: int, dir: Vector2, floor: float) -> float:
	if grid.coast.is_empty():
		return floor
	# ⚠⚠ **STEPPED INWARD-OUT, WHERE `Grid` SOLVES IT ON THE CROSSINGS.** Same claim, different machine:
	# start at the beach and walk seaward until the whole forward body is clear of drawn land, and take
	# the first place it is. **A closed form and a sweep cannot share an arithmetic blind spot.**
	# ⚠ The step is fine enough that the answer is inside `NEAR` of the exact one, and the cap is the
	# same upper bound the rows above assert — past it the answer is a defect, not a number.
	var cap := floor + Rules.BOAT_HULL_HALF_TILES + 1.0
	var walked := floor
	while walked <= cap:
		if not _hull_touches_drawn_land(grid, tile, dir,
				Vector2(tile % grid.w, tile / grid.w) + dir * walked, Rules.BOAT_BEACH_GAP_TILES):
			return walked
		walked += 0.02
	return floor


## **Whether any of the hull's forward half, grown by the gap, stands on drawn land.**
##
## ⚠⚠ **POINT-IN-POLYGON AND NOT RAY-CROSSING, DELIBERATELY.** `Grid.hull_stop_along` finds where the
## outline crosses a ray; this asks a different question of the same data — **is this point inside the
## island** — by counting crossings of a ray to +x. Two formulations of one claim; a shared blind spot
## in the crossing arithmetic cannot hide in both.
## ⚠ **The `+0.5`** — the outline lives half a 조각 off raw tile coordinates, calibrated at 100% against
## `passable`. A footprint tested without it is off by up to 0.707 조각 on a diagonal.
func _hull_touches_drawn_land(grid: Grid, tile: int, dir: Vector2, stop: Vector2,
		grow: float = 0.0) -> bool:
	if grid.coast.is_empty():
		return false
	var origin := stop + Vector2(0.5, 0.5)
	var side := Vector2(-dir.y, dir.x)
	var half_beam := Rules.BOAT_HULL_BEAM_TILES * 0.5
	# ⚠⚠ **THE HULL ITSELF AND NOT THE HULL PLUS THE GAP.** A first draft swept `half_len + gap` forward
	# and called 41 of 67 aground — **including beaches the screen shows clean with 0.93 to spare.** The
	# gap strip is defined to reach the land 조각's own CENTRE, so on a straight approach it lands on
	# land by construction and the test could only ever fail. **What the screen measures, and what this
	# measures now, is whether the HULL is on drawn grass.**
	# ⚠ **`grow` is the gap, and only the STOP search passes it.** The rows that ask 「is the hull on the
	# grass」 pass 0 — the gap is clear water the hull is entitled to, not part of the hull.
	var ahead := Rules.BOAT_HULL_HALF_TILES + grow
	for a in 6:
		var along := (float(a) / 5.0) * ahead
		for c in 5:
			var across := ((float(c) / 4.0) * 2.0 - 1.0) * half_beam
			if _inside_coast(grid.coast, origin - dir * along + side * across):
				return true
	return false


## Whether `p` is inside the baked outline. Crossing number against a ray to +x — odd is inside.
func _inside_coast(coast: Array, p: Vector2) -> bool:
	var crossings := 0
	for raw in coast:
		var seg := raw as Array
		var ay := float(seg[1])
		var by := float(seg[3])
		if (ay > p.y) == (by > p.y):
			continue
		var ax := float(seg[0])
		var bx := float(seg[2])
		var xin := ax + (p.y - ay) / (by - ay) * (bx - ax)
		if xin > p.x:
			crossings += 1
	return (crossings % 2) == 1


## The furthest the outline crosses this ray within `window` either side, or `-INF`.
func _coast_far_within(coast: Array, from: Vector2, dir: Vector2, window: float) -> float:
	var best := -INF
	for raw in coast:
		var seg := raw as Array
		var a := Vector2(float(seg[0]), float(seg[1]))
		var b := Vector2(float(seg[2]), float(seg[3]))
		var ab := b - a
		var denom := dir.cross(ab)
		if absf(denom) < 1e-9:
			continue
		var ao := a - from
		var hit := ao.cross(ab) / denom
		var along := ao.cross(dir) / denom
		if along < 0.0 or along > 1.0:
			continue
		if hit < -window or hit > window:
			continue
		best = maxf(best, hit)
	return best


func _coast_crossing(coast: Array, from: Vector2, dir: Vector2, reach: float) -> float:
	var best := 9999.0
	for raw in coast:
		var seg := raw as Array
		var a := Vector2(float(seg[0]), float(seg[1]))
		var b := Vector2(float(seg[2]), float(seg[3]))
		var ab := b - a
		var denom := dir.cross(ab)
		if absf(denom) < 1e-9:
			continue
		var ao := a - from
		var hit := ao.cross(ab) / denom
		var along := ao.cross(dir) / denom
		if along < 0.0 or along > 1.0:
			continue
		if absf(hit) > reach:
			continue
		if absf(hit) < absf(best):
			best = hit
	return best


func _land_reach(grid: Grid, tile: int, dir: Vector2, reach: float) -> float:
	var far := 0.0
	for raw in _land_on_line(grid, tile, dir, reach):
		far = maxf(far, float(raw))
	return far


## Every land 조각 on the line out of `tile`, as its distance from `tile`'s centre projected on `dir`.
## **The 조각 itself is included at distance 0** — it is land, and it is the thing the hull stops for.
func _land_on_line(grid: Grid, tile: int, dir: Vector2, reach: float) -> Array:
	var from := Vector2(tile % grid.w, tile / grid.w)
	var out := []
	for raw in _line_tiles(grid, from, dir, reach):
		var nt := int(raw)
		if grid.passable[nt] == 0:
			continue
		out.append((Vector2(nt % grid.w, nt / grid.w) - from).dot(dir))
	return out


## Whether the straight line out of `tile` along `dir` clears land for `reach` 조각.
##
## ⚠⚠ **A DIFFERENT ALGORITHM FROM `Grid._clear_water_line`, DELIBERATELY, AND IT WAS A COPY OF IT
## FIRST.** The first draft sampled at the same quarter-조각 interval with the same `round()` — the
## same formulation, line for line — while its own comment claimed the sampler under test must not be
## the one that says it passed. **A check that shares its defect with its subject cannot catch that
## defect**: any 조각 the interval steps over is stepped over by both, and both go green together.
## `how-nets-lie` collects exactly this shape.
##
## ⇒ **This walks 조각 instead of sampling points** — an Amanatides-Woo grid traversal: start in the
## 조각 the beach is in, and at every step cross whichever of the two 조각 boundaries is nearer along
## the ray. **It visits every 조각 the ray passes through and cannot skip one at any step size**,
## because it has no step size. The two agree on this board; the day they stop agreeing, one of them
## is wrong and the disagreement is the finding.
##
## ⚠ **The starting 조각 is skipped and it has to be** — a beach IS land, so a ray leaving one would be
## refused by its own origin at every angle.
## ⚠ **Off the board is open water.** The board is the only thing this net knows and the ray leaving it
## has left the island behind — the same reading `Grid` takes, and the one place the two must agree.
func _line_is_all_water(grid: Grid, tile: int, from: Vector2, dir: Vector2, reach: float) -> bool:
	for raw in _line_tiles(grid, from, dir, reach):
		var nt := int(raw)
		if nt == tile:
			continue
		if grid.passable[nt] != 0:
			return false
	return true


## Every 조각 the ray from `from` along `dir` passes through, out to `reach`. See the header above for
## why this walks boundaries instead of sampling, and why an exact tie steps both axes at once.
func _line_tiles(grid: Grid, from: Vector2, dir: Vector2, reach: float) -> PackedInt32Array:
	var hit := PackedInt32Array()
	# 조각 centres sit on integers, so the 조각 a point is in is its rounded coordinate and the 조각's
	# own span runs from -0.5 to +0.5 about that.
	var cx := int(round(from.x))
	var cy := int(round(from.y))
	if cx >= 0 and cy >= 0 and cx < grid.w and cy < grid.h:
		hit.append(cy * grid.w + cx)
	var step_x := 0
	var step_y := 0
	if dir.x > 0.0:
		step_x = 1
	elif dir.x < 0.0:
		step_x = -1
	if dir.y > 0.0:
		step_y = 1
	elif dir.y < 0.0:
		step_y = -1
	# How far along the ray the next 조각 boundary is, per axis, and how far one whole 조각 costs.
	# ⚠ **An axis the ray does not move along never crosses a boundary** — INF rather than a division
	# by zero, which would poison every comparison below with a NAN.
	var next_x := INF
	var delta_x := INF
	if step_x != 0:
		var edge_x := float(cx) + 0.5 * float(step_x)
		next_x = (edge_x - from.x) / dir.x
		delta_x = 1.0 / absf(dir.x)
	var next_y := INF
	var delta_y := INF
	if step_y != 0:
		var edge_y := float(cy) + 0.5 * float(step_y)
		next_y = (edge_y - from.y) / dir.y
		delta_y = 1.0 / absf(dir.y)

	var travelled := 0.0
	# A bound on the loop rather than on the geometry: a ray crosses at most one boundary per 조각 per
	# axis, so twice the reach plus a couple is past any real count. **A net that can hang prints no
	# verdict at all**, which disarms mutation testing on the whole file.
	for _guard in int(ceil(reach * 2.0)) + 4:
		if travelled > reach:
			return hit
		# ⚠⚠ **AN EXACT TIE CROSSES BOTH BOUNDARIES AT ONCE AND THE RAY ENTERS THE *DIAGONAL* 조각.**
		# `seaward_at` hands back an exact 45 degrees whenever a beach's watery neighbours sum to a
		# diagonal, which is most corner beaches — and such a ray passes through 조각 CORNERS. Stepping
		# one axis and then the other would report the two side 조각 as crossed when the ray only ever
		# touched their corner points, and this net would then refuse beaches the board is right to
		# allow. **Measured: without this branch it disagreed with `Grid` about four 조각.**
		if absf(next_x - next_y) <= 1e-9:
			travelled = next_x
			cx += step_x
			cy += step_y
			next_x += delta_x
			next_y += delta_y
		elif next_x < next_y:
			travelled = next_x
			cx += step_x
			next_x += delta_x
		else:
			travelled = next_y
			cy += step_y
			next_y += delta_y
		if travelled > reach:
			return hit
		if cx < 0 or cy < 0 or cx >= grid.w or cy >= grid.h:
			continue
		hit.append(cy * grid.w + cx)
	return hit


func _water_or_off_board(grid: Grid, p: Vector2) -> bool:
	var px := int(round(p.x))
	var py := int(round(p.y))
	if px < 0 or py < 0 or px >= grid.w or py >= grid.h:
		return true
	return grid.water[py * grid.w + px] != 0


func _gcd(a: int, b: int) -> int:
	var x := absi(a)
	var y := absi(b)
	while y != 0:
		var r := x % y
		x = y
		y = r
	return x
