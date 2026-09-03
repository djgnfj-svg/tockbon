extends RefCounted
## **A 칸 seats the bodies standing in it, centre first, and the seat lives in `Grid` beside the slot.**
## Ticket 03-17.
##
## The claim under test is one sentence: **every body that holds a 조각 of a 칸 holds exactly one of that
## 칸's nine seats, handed out centre → edge middles → corners, kept while it steps inside the 칸 and given
## back the moment it holds no 조각 there — and neither ceiling moved.**
##
## ⚠⚠ **NOTHING HERE TOUCHES THE TREE.** `Grid.new()` and `load_rows` are the whole fixture — the
## `src/sim/` seam `GLOSSARY.md` names. No `Battle`, no frame: every number below is the state one `Grid`
## call left behind.
##
## ⚠⚠ **WHY THE SEAT IS MEASURED HERE AND NOT WHERE IT IS DRAWN.** A per-조각 seat table assumed the
## split 3·2·2·2, the walk delivered 3·3·2·1, and a body fell through to no seat while a
## seat elsewhere stood empty. **The seat is a fact about the 칸**, and the row `_a_3_3_3_0_hold_still_seats_nine`
## is that measurement turned into a check. The lattice the seat is drawn on is `net_fx_view`'s.
##
## ⚠⚠ **THE SEAT INDEX IS ROW-MAJOR OVER A 3x3 AND 4 IS THE CENTRE**, so the tiers are literal lists here:
## the centre `[4]`, the edge middles `[1, 3, 5, 7]`, the corners `[0, 2, 6, 8]`. **Which 조각 a corner
## belongs to is `Grid.seat_fits_piece`'s answer** and the own-quadrant rows below read the sequence that
## answer produces, so a flipped column there reddens the sequence row and nothing else.
##
## ⚠ **The labels are Korean because they are printed output**, which is what every net in this folder
## does; the prose is English, which is what every file in this repo does.


## The id base for bodies stood here — far from any soldier index, so a seat table that confused an id
## with a slot number could not pass by coincidence.
const UID := 870_001

## An all-land, flat board — six 칸 across, four down. ⚠ **Flat on purpose**: `Grid.hold` asks nothing
## about height and a stair anywhere near a fixture 칸 would turn a refused seat into a refused step.
const FIELD := [
	"............",
	"............",
	"............",
	"............",
	"............",
	"............",
	"............",
	"............",
]
## The 칸 every seating row fills — its north-west 조각. **Not at the board's edge** so a walk in the
## invariant row can leave it on every side.
const BLOCK_TX := 4
const BLOCK_TY := 2


func run(t) -> void:
	_the_first_body_in_a_block_takes_the_centre(t)
	_nine_holds_take_nine_distinct_seats(t)
	_seats_go_centre_then_edges_then_corners(t)
	_a_body_keeps_its_seat_across_its_own_block_and_loses_it_leaving(t)
	_a_3_3_3_0_hold_still_seats_nine(t)
	_the_ceilings_still_hold(t)
	_the_keep_block_seats_eight(t)
	_release_all_and_a_reload_both_forget_the_seat(t)
	_seats_equal_holders_across_a_walk_that_crosses_blocks(t)
	# **The sentinel.** See `run_nets.done` — without it a `run()` that dies half way still reports
	# every check it managed first, in a shape a healthy net cannot be told from.
	t.done()


# == one body ==========================================================================================

## **A body alone in a 칸 sits in its middle**, and a body that holds nothing has no seat at all.
## ⚠ **The `-1` before the hold is the floor** — a `seat_of` that answered 4 for anybody would pass
## the second half on its own.
func _the_first_body_in_a_block_takes_the_centre(t) -> void:
	var g := _field()
	var tile := g.tile_index(BLOCK_TX, BLOCK_TY)
	var block := g.block_of(tile)
	t.eq(g.seat_of(block, UID), -1, "아무것도 안 잡은 몸은 자리가 없다 (-1)")
	t.ok(g.hold(UID, tile), "몸 하나가 조각을 잡는다 (자가 점검)")
	t.eq(g.seat_of(block, UID), 4, "칸의 첫 몸은 한가운데 자리(4)다")
	# Every 조각 of the 칸 gives the same answer: the seat is the 칸's, not the 조각's.
	for raw in g.tiles_of_block(block):
		var other := int(raw)
		if other == tile:
			continue
		var g2 := _field()
		g2.hold(UID, other)
		t.eq(g2.seat_of(g2.block_of(other), UID), 4,
			"어느 조각에서 시작해도 첫 몸은 한가운데다 (조각 %d)" % other)
		break


# == nine bodies =======================================================================================

## **Nine bodies over the four 조각 take nine DIFFERENT seats, and together they are exactly 0..8.**
func _nine_holds_take_nine_distinct_seats(t) -> void:
	var g := _field()
	var block := g.block_of(g.tile_index(BLOCK_TX, BLOCK_TY))
	var ids := _hold_split(g, block, [3, 2, 2, 2])
	t.eq(ids.size(), Rules.BLOCK_CAPACITY, "아홉이 다 섰다 (자가 점검)")
	var seats := {}
	for k in ids.size():
		var s := g.seat_of(block, int(ids[k]))
		t.ok(s >= 0 and s < 9, "몸 %d 의 자리가 0..8 안이다 (%d)" % [k, s])
		seats[s] = true
	t.eq(seats.size(), Rules.BLOCK_CAPACITY, "아홉 자리가 다 다르다")
	t.eq(_seats_held(g, block), Rules.BLOCK_CAPACITY, "칸의 자리표에도 아홉이 차 있다")


## **Centre, then the four edge middles, then the four corners — and inside a tier the body's OWN 조각
## first.**
##
## ⚠⚠ **THE SEQUENCE IS ONE ROW, ON PURPOSE.** The order of arrival here is three into the north-west
## 조각, three into the south-east, then one each into north-east and south-west and a last one into
## south-west. **Every seat below follows from the tier order and `Grid.seat_fits_piece`** — the ninth
## body is the one that stands off its quadrant, in the north-west corner, because that is the only
## corner left. A tier order that put corners first, or a quadrant test that flipped a column, changes
## the sequence and reddens this.
func _seats_go_centre_then_edges_then_corners(t) -> void:
	var g := _field()
	var block := g.block_of(g.tile_index(BLOCK_TX, BLOCK_TY))
	var tiles := g.tiles_of_block(block)
	var nw := int(tiles[0])
	var ne := int(tiles[1])
	var sw := int(tiles[2])
	var se := int(tiles[3])
	var arrive := [nw, nw, nw, se, se, se, ne, sw, sw]
	var got := PackedInt32Array()
	for k in arrive.size():
		t.ok(g.hold(UID + k, int(arrive[k])), "몸 %d 가 선다 (자가 점검)" % k)
		got.append(g.seat_of(block, UID + k))
	t.eq(got[0], 4, "첫 몸은 한가운데")
	var edges := [1, 3, 5, 7]
	var corners := [0, 2, 6, 8]
	for k in range(1, 5):
		t.ok(edges.has(got[k]), "%d 번째 몸은 변의 가운데 중 하나다 (%d)" % [k + 1, got[k]])
	for k in range(5, 9):
		t.ok(corners.has(got[k]), "%d 번째 몸은 모서리 중 하나다 (%d)" % [k + 1, got[k]])
	# The own-quadrant preference, as the sequence it produces. ⚠ Read `Grid.seat_fits_piece` for why
	# north-west gets 1 and 5 and not 1 and 3: the column index runs the other way from x.
	t.eq(Array(got), [4, 1, 5, 3, 7, 6, 0, 8, 2],
		"자리 순서가 한가운데 → 제 조각 쪽 변 → 제 조각 모서리 → 남은 모서리다")


# == across a step =====================================================================================

## **A body stepping between two 조각 of ONE 칸 keeps its seat; stepping into another 칸 it gives the
## old one back and takes a new one there** — and for the length of the step it holds both.
##
## ⚠⚠ **THE FREE HOOKS INTO `_release_except` AND NOT ONLY INTO `release_all`.** The walk never calls
## `release_all`; `_commit_step` is `hold(dest)` then `_release_except(cur, dest)`. A seat freed only
## on `release_all` would leave every 칸 a body ever walked through holding a seat for it, and the
## ninth body into such a 칸 would find no seat while eight stood there.
func _a_body_keeps_its_seat_across_its_own_block_and_loses_it_leaving(t) -> void:
	var g := _field()
	var home := g.block_of(g.tile_index(BLOCK_TX, BLOCK_TY))
	var tiles := g.tiles_of_block(home)
	var nw := int(tiles[0])
	var ne := int(tiles[1])
	# Two bodies first, so the walker's seat is NOT the centre and a table that simply re-seated from
	# scratch on every hold would hand it a different number.
	g.hold(UID + 1, nw)
	g.hold(UID + 2, nw)
	g.hold(UID, nw)
	var seat := g.seat_of(home, UID)
	t.ok(seat >= 0 and seat != 4, "걷는 몸의 자리가 한가운데가 아니다 (%d — 자가 점검)" % seat)

	# The two-tile swap inside the 칸: `_commit_step` holds BOTH 조각 until the next step lets the old
	# one go, which is the mid-step hold `Grid.block_hold_count`'s header describes.
	g._commit_step(UID, nw, ne)
	t.ok(g.holds(ne, UID) and g.holds(nw, UID), "걸음 도중 몸이 같은 칸의 두 조각을 든다 (자가 점검)")
	t.eq(g.seat_of(home, UID), seat, "같은 칸 안에서 걸음을 떼도 자리는 그대로다")
	g._release_except(UID, ne, ne)
	t.ok(g.holds(ne, UID) and not g.holds(nw, UID), "걸음을 마치면 옆 조각만 든다 (자가 점검)")
	t.eq(g.seat_of(home, UID), seat, "걸음을 마쳐도 자리는 그대로다")
	t.eq(_seats_held(g, home), 3, "그리고 칸의 자리는 여전히 셋만 차 있다")

	# Mid-step into the next 칸 east: both 조각 held, both seats held.
	var east_tile := g.tile_index(BLOCK_TX + Rules.BLOCK_TILES, BLOCK_TY)
	var east := g.block_of(east_tile)
	t.ok(east != home, "동쪽 조각은 다른 칸이다 (자가 점검)")
	g.hold(UID, east_tile)
	t.eq(g.seat_of(home, UID), seat, "걸음 도중에는 떠나는 칸의 자리를 아직 들고 있다")
	t.eq(g.seat_of(east, UID), 4, "그리고 들어가는 칸에서는 한가운데를 받았다 — 자리 둘을 잠깐 든다")
	g._release_except(UID, east_tile, east_tile)
	t.eq(g.seat_of(home, UID), -1, "떠난 칸의 조각을 다 놓으면 그 칸의 자리도 비운다")
	t.eq(g.seat_of(east, UID), 4, "새 칸의 자리는 남는다")
	t.eq(_seats_held(g, home), 2, "떠난 칸에는 남은 둘의 자리만 차 있다")
	t.eq(_seats_held(g, east), 1, "새 칸에는 하나")

	# The freed seat is actually free: the next body into the home 칸 takes it back.
	g.hold(UID + 3, nw)
	t.eq(g.seat_of(home, UID + 3), seat, "비운 자리를 다음 몸이 그대로 받는다 (%d)" % seat)


## **Three, three, three and none still seats nine.** A per-조각 table lost a body to exactly this split.
func _a_3_3_3_0_hold_still_seats_nine(t) -> void:
	var g := _field()
	var block := g.block_of(g.tile_index(BLOCK_TX, BLOCK_TY))
	var ids := _hold_split(g, block, [3, 3, 3, 0])
	t.eq(ids.size(), Rules.BLOCK_CAPACITY, "3·3·3·0 으로 아홉이 섰다 (자가 점검)")
	t.eq(g.hold_count(int(g.tiles_of_block(block)[3])), 0, "남동 조각은 비어 있다 (자가 점검)")
	var seats := {}
	var lost := 0
	for k in ids.size():
		var s := g.seat_of(block, int(ids[k]))
		if s < 0:
			lost += 1
		seats[s] = true
	t.eq(lost, 0, "자리를 못 받은 몸이 없다 — 조각별 표였다면 여기서 하나가 빠진다")
	t.eq(seats.size(), Rules.BLOCK_CAPACITY, "아홉 자리가 다 다르다")


# == the ceilings ======================================================================================

## **Three per 조각, nine per 칸, and the tenth is refused with no seat.** `net_fight` pins the two
## numbers as literals; this row reads them and asks the seat table beside them.
func _the_ceilings_still_hold(t) -> void:
	var g := _field()
	var block := g.block_of(g.tile_index(BLOCK_TX, BLOCK_TY))
	var tiles := g.tiles_of_block(block)
	var nw := int(tiles[0])
	for k in Rules.TILE_CAPACITY:
		t.ok(g.hold(UID + k, nw), "조각의 %d 번째 몸이 선다 (자가 점검)" % (k + 1))
	t.ok(not g.hold(UID + 50, nw), "조각의 넷째는 거절된다 — 조각 천장 %d 은 그대로다" % Rules.TILE_CAPACITY)
	t.eq(g.seat_of(block, UID + 50), -1, "거절된 몸은 자리도 못 받는다")
	# Fill the 칸 to nine through the other three 조각 (2, 2, 2).
	var k := Rules.TILE_CAPACITY
	for j in range(1, 4):
		for _n in 2:
			t.ok(g.hold(UID + k, int(tiles[j])), "칸의 %d 번째 몸이 선다 (자가 점검)" % (k + 1))
			k += 1
	t.eq(g.block_hold_count(block), Rules.BLOCK_CAPACITY, "칸에 아홉이 섰다 (자가 점검)")
	t.eq(_seats_held(g, block), Rules.BLOCK_CAPACITY, "자리도 아홉이 차 있다")
	# The south-east 조각 has one free slot, and the 칸 refuses anyway.
	t.eq(g.hold_count(int(tiles[3])), 2, "남동 조각에는 슬롯 하나가 남았다 (자가 점검)")
	t.ok(not g.hold(UID + 60, int(tiles[3])), "그래도 열째는 거절된다 — 칸 천장 %d 은 그대로다" % Rules.BLOCK_CAPACITY)
	t.eq(g.seat_of(block, UID + 60), -1, "열째는 자리가 없다")
	t.eq(_seats_held(g, block), Rules.BLOCK_CAPACITY, "자리표는 아홉을 넘지 않는다")


## **A 조각 taken whole by a building takes no seat, and the eight bodies beside it take eight.**
## `Grid.block_hold_count` counts the house as one body, so the ninth walker is refused — that is the
## 성채's 칸 as `Hand._seats` already knows it.
func _the_keep_block_seats_eight(t) -> void:
	var g := _field()
	var block := g.block_of(g.tile_index(BLOCK_TX, BLOCK_TY))
	var tiles := g.tiles_of_block(block)
	var house := 999_999
	t.ok(g.fill(house, int(tiles[0])), "집이 북서 조각을 통째로 잡는다 (자가 점검)")
	t.eq(g.seat_of(block, house), -1, "집은 자리를 받지 않는다")
	t.eq(_seats_held(g, block), 0, "그리고 자리표는 비어 있다")
	var seats := {}
	var stood := 0
	for k in 8:
		var tile := int(tiles[1 + k % 3])
		if g.hold(UID + k, tile):
			stood += 1
			seats[g.seat_of(block, UID + k)] = true
	t.eq(stood, 8, "여덟 몸이 집 옆에 선다 (자가 점검)")
	t.eq(seats.size(), 8, "여덟이 서로 다른 자리를 받는다")
	t.ok(not seats.has(-1), "그중 자리 없는 몸은 없다")
	t.ok(not g.hold(UID + 8, int(tiles[3])), "아홉째 몸은 거절된다 — 집이 하나로 센다")


## **`release_all` and a fresh `load_rows` both leave no seat behind.** A reused `Grid` carrying the
## last island's seats would sit the first body of the next island off-centre.
func _release_all_and_a_reload_both_forget_the_seat(t) -> void:
	var g := _field()
	var tile := g.tile_index(BLOCK_TX, BLOCK_TY)
	var block := g.block_of(tile)
	g.hold(UID, tile)
	g.hold(UID + 1, tile)
	t.eq(_seats_held(g, block), 2, "둘이 자리를 들었다 (자가 점검)")
	var other := g.seat_of(block, UID + 1)
	t.ok(other >= 0 and other != 4, "둘째 몸은 한가운데가 아닌 자리를 들었다 (%d — 자가 점검)" % other)
	g.release_all(UID)
	t.eq(g.seat_of(block, UID), -1, "release_all 은 자리를 비운다")
	t.eq(g.seat_of(block, UID + 1), other, "남의 자리는 건드리지 않는다")
	g.load_rows(FIELD)
	t.eq(g.seat_of(block, UID + 1), -1, "다시 load_rows 하면 자리표가 비어 있다")


# == the invariant ======================================================================================

## **Seats held in a 칸 == distinct holders in it, never above nine, after every step of a walk that
## crosses 칸.** This is amendment 1 of the plan as a check.
##
## ⚠⚠ **THE INSTRUMENT IS INVERTED FIRST.** A reader that compared the table with itself would be green
## for any table; so before the walk, one seat is forged by hand and the reader is required to see it,
## and the forgery is undone before anything is measured. **Then the walk**: a body crosses six 칸 with
## a crowd standing in its way, and the pair of counts is read after every single step.
func _seats_equal_holders_across_a_walk_that_crosses_blocks(t) -> void:
	var g := Grid.new()
	var rows: Array = []
	for _y in 12:
		rows.append(".".repeat(24))
	g.load_rows(rows)
	var target := g.tile_index(20, 6)
	var field := g.flow_field(target)

	# The forgery: a seat with nobody standing in the 칸.
	var far_block := g.block_of(g.tile_index(0, 0))
	var seats := PackedInt32Array()
	seats.resize(9)
	seats.fill(-1)
	seats[4] = UID + 500
	g.block_seats[far_block] = seats
	t.ok(not _every_block_consistent(g), "자가 점검 — 손으로 심은 자리 하나를 판독기가 잡아낸다")
	g.block_seats.erase(far_block)
	t.ok(_every_block_consistent(g), "자가 점검 — 심은 것을 지우면 다시 맞는다")

	# A crowd on the way, so the walker meets 칸 that already hold bodies and has to queue once.
	var crowd_tile := g.tile_index(10, 6)
	for k in Rules.TILE_CAPACITY:
		g.hold(UID + 100 + k, crowd_tile)
	g.hold(UID + 110, g.tile_index(11, 6))

	var at := Vector2(2.0, 6.0)
	var steps := 0
	var bad := 0
	var blocks_seen := {}
	for _i in 60:
		var next := g.step_toward(UID, at, field, -1, target)
		if next.is_equal_approx(at):
			break
		at = next
		steps += 1
		blocks_seen[g.block_of(g.tile_index(int(round(at.x)), int(round(at.y))))] = true
		if not _every_block_consistent(g):
			bad += 1
	t.ok(steps >= 10, "걸음을 %d 번 실제로 뗐다 (자가 점검 — 0 걸음짜리 초록이 아니다)" % steps)
	t.ok(blocks_seen.size() >= 4, "칸을 %d 개 지났다 (자가 점검 — 한 칸 안이 아니다)" % blocks_seen.size())
	t.eq(bad, 0, "걸음마다 칸의 자리 수 == 그 칸에 선 몸 수이고 아홉을 안 넘는다 (어긋난 걸음 %d)" % bad)
	# The walker ended in one 칸 holding one seat, and every 칸 behind it holds none for it.
	var mine := 0
	for raw in g.block_seats.keys():
		if g.seat_of(int(raw), UID) >= 0:
			mine += 1
	t.eq(mine, 1, "걷고 난 몸은 자리를 딱 하나 든다 — 지나온 칸에 남긴 자리가 없다")
	g.release_all(UID)
	t.ok(_every_block_consistent(g), "놓고 나서도 표는 맞는다")


# == fixtures ==========================================================================================

func _field() -> Grid:
	var g := Grid.new()
	g.load_rows(FIELD)
	return g


## Stands bodies `UID..` over the four 조각 of `block` in `split` order (north-west, north-east,
## south-west, south-east) and answers the ids that stood.
func _hold_split(g: Grid, block: int, split: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	var tiles := g.tiles_of_block(block)
	var k := 0
	for q in split.size():
		for _n in int(split[q]):
			if g.hold(UID + k, int(tiles[q])):
				out.append(UID + k)
			k += 1
	return out


## How many seats of `block` name a body — read off the table itself, so a `seat_of` that lied and a
## table that lied would have to lie the same way.
func _seats_held(g: Grid, block: int) -> int:
	if not g.block_seats.has(block):
		return 0
	var n := 0
	var seats: PackedInt32Array = g.block_seats[block]
	for k in seats.size():
		if int(seats[k]) != -1:
			n += 1
	return n


## **The invariant for every 칸 the table knows about**: seats held equals distinct holders, at most
## nine, and every seated id really stands in the 칸.
## ⚠ **Walks the TABLE's keys and the board's 칸 both**: a 칸 with holders and no table entry is a
## missed seat, and a table entry with seats and no holders is a leaked one.
func _every_block_consistent(g: Grid) -> bool:
	var per_row := (g.w + Rules.BLOCK_TILES - 1) / Rules.BLOCK_TILES
	var per_col := (g.h + Rules.BLOCK_TILES - 1) / Rules.BLOCK_TILES
	for block in per_row * per_col:
		var holders := g.block_hold_count(block)
		var seats := _seats_held(g, block)
		if seats != holders or seats > Rules.BLOCK_CAPACITY:
			return false
		if not g.block_seats.has(block):
			continue
		var table: PackedInt32Array = g.block_seats[block]
		for k in table.size():
			var id := int(table[k])
			if id != -1 and not g._block_holds(block, id):
				return false
	return true
