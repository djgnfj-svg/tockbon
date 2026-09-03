extends RefCounted
## **짓기 모드 — the player takes up a building, presses a 조각, and the 창고 stands there.** Ticket 05-08.
##
## The claim under test is one sentence: **a run opens with no 창고; the hand can take one up without
## letting go of the 부대 it is holding; a build lands only where `can_place_store` says it would; a
## second build leaves ONE 창고 and not two; and what a body gathers goes into the building that press
## put up.**
##
## ⚠⚠ **THE MODE IS WHY THIS FILE EXISTS AND NOT ONLY THE PLACING.** `Battle.place_store` was built
## 2026-09-03 and called by nothing — a door with no handle. **What was missing was the hand**, and the
## user chose a mode for it over a building list and over reviving the right button:
## ***"Build mode seems right."*** (「짓기모드가 맞을듯」). The rows here drive `Hand` and `Battle`
## straight; **the keys and the press that reach them are `net_shell`'s**, at the `_ready()` seam.
##
## ⚠⚠ **NOTHING HERE TOUCHES THE TREE.** `Grid.new()`, `Army.new()`, `Battle.new()` and `Hand.new()`
## are the whole fixture — the `src/sim/` seam `GLOSSARY.md` names.
##
## ⚠⚠ **THE POND IS WHAT KEEPS THE BOATS OUT**, the same measured trick `net_gather` uses: an inland
## pool has no beach a hull can reach, so no 늑대 lands in the middle of a ten-second catch. **The
## first row asserts no hull was born**, or the rows below would quietly start measuring a fight.
##
## ⚠ **What it COSTS to build is NOT decided** (05-08's own 「not decided」 section — a 창고 that costs
## wood before any wood can be stored is a chicken and an egg, and the user was never asked). **It is
## free, and one row below says so out loud** so the day a price is chosen that row goes red rather
## than the change landing unnoticed.
##
## ⚠ **The labels are Korean because they are printed output**; the prose is English.

## **All land but a pool in the middle.** The 조각 around the pool are the water's edge; the corners are
## as far from water as this board goes; nothing on the rim touches open sea, so no boat can dock.
const POOL := [
	".........",
	".........",
	"...~~~...",
	"...~~~...",
	"...~~~...",
	".........",
	".........",
]
const W := 9
const H := 7
## On the pool's edge — where a body fishes.
const SHORE_TX := 2
const SHORE_TY := 3
## Dry land, off the shore, two different 조각 — where the 창고 goes and where it is moved to.
const SPOT_TX := 7
const SPOT_TY := 1
const OTHER_TX := 7
const OTHER_TY := 5
## The middle of the pool.
const WET_TX := 4
const WET_TY := 3
## The 성채's two 조각 on the keep fixture — dry land in the north-west, well clear of everything else.
const KEEP_TX := 0
const KEEP_TY := 6


func run(t) -> void:
	_the_pool_carries_no_boats(t)
	_a_run_opens_with_no_store(t)
	_taking_a_building_up_and_putting_it_down(t)
	_the_squad_survives_the_mode(t)
	_a_press_inside_the_mode_stands_the_store(t)
	_the_mark_and_the_press_answer_the_same(t)
	_the_refusals(t)
	_a_second_store_does_not_make_two(t)
	_the_first_store_is_free(t)
	_what_is_gathered_goes_into_the_store_that_was_built(t)
	# **The sentinel.** Without it a `run()` that dies half way still reports every check it managed
	# first, in a shape a healthy net cannot be told from.
	t.done()


# == the fixture is what it says ======================================================================

## **No hull is ever born on this board**, which is what every row below rests on.
func _the_pool_carries_no_boats(t) -> void:
	var b := _battle()
	t.eq(b.grid.beach_ring(Rules.BOAT_START_DIST_TILES).size(), 0,
		"자가 점검 — 배가 댈 해변이 하나도 없다")
	_run_for(b, Rules.BOAT_FIRST_SEC + 1.0)
	t.eq(b.boat_pos.size(), 0, "자가 점검 — 그래서 배가 한 척도 안 뜬다")


# == the opening =====================================================================================

## **A run opens with no 창고 and with nothing in it** (2026-09-02, asked whether it stands on the first
## run or has to be built, the user: 「지어야 되고」 — *it has to be built*).
##
## ⚠ **`store_tile` is what says 「none」 and `store` is never null** — an empty 창고 and no 창고 at all
## are two different boards, and a reader that told them apart by the counts would let a body eat out
## of a building nobody built.
func _a_run_opens_with_no_store(t) -> void:
	var b := _battle()
	t.eq(b.store_tile, -1, "판이 열릴 때 창고가 없다")
	t.ok(b.store != null, "그래도 창고 셈은 있다 — null 이 아니다")
	t.eq(b.store.total(), 0, "그리고 아무것도 안 쌓여 있다")
	t.ok(not b.can_place_store(-1), "격자 밖에는 못 짓는다")
	# **The island file opens with the 성채 alone**, which is what makes 「the 창고 is the first thing
	# the player builds」 true of the real board and not only of this fixture.
	var kinds := PackedStringArray()
	for row in Islands.builds():
		kinds.append(str((row as Dictionary)["kind"]))
	t.ok(not kinds.has(Builds.STORE), "섬 파일에도 창고가 안 적혀 있다 %s" % [kinds])

	var hand := Hand.new()
	t.ok(not hand.is_building(), "그리고 손은 짓기 모드가 아니다 — 그것이 쉬는 자리다")
	t.ok(not hand.build(b, b.grid.tile_index(SPOT_TX, SPOT_TY)),
		"짓기 모드가 아니면 눌러도 아무것도 안 선다")
	t.eq(b.store_tile, -1, "그래서 창고는 여전히 없다")


# == the mode ========================================================================================

## **The hand takes a building up and puts it down**, and a kind no table row answers to does neither.
##
## ⚠⚠ **THE UNKNOWN-KIND ROW IS THE INVERSION OF THE WHOLE MODE.** Without it 「entering works」 is
## satisfied by a field that accepts any string at all, and the mode would open on a kind whose press
## can never place anything — on screen, a game that has stopped answering the mouse.
func _taking_a_building_up_and_putting_it_down(t) -> void:
	var hand := Hand.new()
	t.ok(hand.take_the_building(Builds.STORE), "창고를 집으면 짓기 모드가 켜진다")
	t.ok(hand.is_building(), "손이 그것을 들고 있다")
	t.eq(hand.building, Builds.STORE, "손이 든 것은 창고다 — 무엇을 드는지가 값이다")

	hand.put_the_building_down()
	t.ok(not hand.is_building(), "내려놓으면 꺼진다")
	t.eq(hand.building, "", "그리고 아무것도 안 들고 있다")

	t.ok(not hand.take_the_building("없는건물"),
		"건물표에 없는 이름은 안 집힌다 — 누를 때마다 실패하는 모드가 안 열린다")
	t.ok(not hand.is_building(), "그래서 모드도 안 켜진다")

	# **`clear` drops the building too, and ESC therefore does not come through it** — the shell's own
	# ESC branch calls `put_the_building_down`. This is the half that makes a new island safe.
	t.ok(hand.take_the_building(Builds.STORE), "자가 점검 — 다시 집었다")
	hand.clear()
	t.ok(not hand.is_building(), "손을 비우면 든 건물도 같이 내려간다 — 새 섬이 모드를 물려받지 않는다")


## **Entering and leaving 짓기 모드 does not touch the 부대 or its lit 조각.**
##
## ⚠⚠ **THIS IS THE ROW THE MODE'S SHAPE WAS CHOSEN FOR.** A mode that emptied the hand and put it back
## would hold two copies of the selection with a moment in between where the game owns both; here there
## is one list and nothing ever writes it. **The reach is asserted as well as the ids** — a mode that
## kept the ids and dropped the lit ground would leave the player holding a 부대 that cannot be sent.
func _the_squad_survives_the_mode(t) -> void:
	var b := _battle(2)
	var g := b.grid
	var ids := PackedInt32Array()
	for i in 2:
		if b.place_ashore(i, g.tile_index(SHORE_TX + i, 6)) >= 0:
			ids.append(i)
	t.eq(ids.size(), 2, "자가 점검 — 몸 둘이 판 위에 섰다")

	var hand := Hand.new()
	t.ok(hand.pick_many(b, ids), "자가 점검 — 손이 둘을 쥐었다")
	var held := hand.ids.duplicate()
	var lit := hand.reach.duplicate()
	t.ok(lit.size() > 0, "자가 점검 — 갈 수 있는 자리가 깔렸다 (%d 조각)" % [lit.size()])

	t.ok(hand.take_the_building(Builds.STORE), "자가 점검 — 그 상태로 창고를 집었다")
	t.eq(hand.ids, held, "짓기 모드에 들어가도 쥔 몸은 그대로다")
	t.eq(hand.reach, lit, "불 켜진 자리도 그대로다")

	hand.put_the_building_down()
	t.eq(hand.ids, held, "나와도 쥔 몸이 그대로 돌아온다 — 다시 고를 것이 없다")
	t.eq(hand.reach, lit, "불 켜진 자리도 그대로 돌아온다")
	t.ok(not hand.is_empty(), "손은 여전히 부대를 들고 있다")


## **A build inside the mode stands the 창고 on that 조각, and the 조각 stops being walkable ground.**
##
## ⚠ **`grid.hold_count` is the ceiling half.** A building that only wrote `store_tile` would leave its
## 조각 free for a body to walk into and stand INSIDE the house — the measured 2026-08-27 defect the
## 성채 already carries a reservation for.
func _a_press_inside_the_mode_stands_the_store(t) -> void:
	var b := _battle()
	var g := b.grid
	var spot := g.tile_index(SPOT_TX, SPOT_TY)
	var hand := Hand.new()
	t.ok(hand.take_the_building(Builds.STORE), "자가 점검 — 창고를 집었다")
	t.ok(hand.can_build(b, spot), "그 조각은 지을 수 있다고 답한다")
	t.ok(hand.build(b, spot), "누르면 창고가 선다")
	t.eq(b.store_tile, spot, "그리고 그 조각이 창고 자리가 된다")
	t.ok(g.hold_count(spot) > 0, "창고가 제 조각을 통째로 잡는다 — 안에 들어가서 설 수 없다")
	t.eq(b.store_doorstep().size() > 0, true, "옆에 서서 쓸 자리가 생긴다 (%d 조각)"
		% [b.store_doorstep().size()])
	for k in b.store_doorstep().size():
		t.ok(int(b.store_doorstep()[k]) != spot, "그 옆자리는 창고 자리가 아니다")
	# **The building takes the whole 조각, so nobody may stand on it** — asked of the board rather
	# than of the building, because it is the board every walker reads.
	# ⚠ **`place_ashore` takes a WISH and answers the 조각 it actually used**, walking outwards to the
	# nearest free one — so 「refused」 reads as 「it put him somewhere else」, never as -1.
	t.ok(b.place_ashore(0, spot) != spot, "그 조각에는 몸이 안 선다 — 옆으로 밀린다")


## **`can_build` and `build` answer the same thing about every 조각 on the board.**
##
## ⚠⚠ **THIS IS THE ANTI-DRIFT ROW AND IT IS THE REASON `can_place_store` WAS CUT OUT OF
## `place_store`.** The mark 짓기 모드 lays on the ground is painted from the first and the press goes
## through the second; two copies of one rule is how the ground comes to light for a press the
## simulation refuses, with nothing anywhere going red. **A fresh board per 조각**, because a build
## that succeeded would change the answer for every 조각 after it.
##
## ⚠ **Both arms are counted.** A row that only saw refusals would pass on a `can_build` stuck at false.
func _the_mark_and_the_press_answer_the_same(t) -> void:
	var probe := _battle()
	var yes := 0
	var no := 0
	var disagreed := PackedInt32Array()
	for tile in probe.grid.w * probe.grid.h:
		var b := _battle()
		var hand := Hand.new()
		hand.take_the_building(Builds.STORE)
		var said := hand.can_build(b, tile)
		var did := hand.build(b, tile)
		if said != did:
			disagreed.append(tile)
		if did:
			yes += 1
		else:
			no += 1
	t.eq(disagreed.size(), 0, "판의 모든 조각에서 「지을 수 있다」와 「지어졌다」가 같은 답이다 %s"
		% [disagreed])
	t.ok(yes > 0, "지을 수 있는 조각이 실제로 있다 (%d개)" % [yes])
	t.ok(no > 0, "그리고 못 짓는 조각도 있다 (%d개) — 전부 된다면 위 줄은 공허하다" % [no])


## **Water, the 성채, a body, a 바리케이트 and the 창고's own 조각 all refuse.**
##
## ⚠⚠ **THE REFUSALS ARE THE HALF THE PLAYER MEETS.** 「It builds where it can」 is satisfied by a rule
## that builds everywhere; what the mark on the ground has to be able to say is 「not here」, and every
## one of these is a 조각 a player will aim at.
func _the_refusals(t) -> void:
	var g := _battle().grid
	t.eq(g.passable[g.tile_index(WET_TX, WET_TY)], 0, "자가 점검 — 못 위는 못 지나간다")

	var wet := _battle()
	t.ok(not wet.can_place_store(wet.grid.tile_index(WET_TX, WET_TY)), "물 위에는 못 짓는다")
	t.ok(not wet.can_place_store(-1), "격자 밖에도 못 짓는다")
	t.ok(not wet.can_place_store(W * H), "격자 끝 너머도 못 짓는다")

	# -- on the 성채 --------------------------------------------------------------------------------
	var keeper := _battle_with_keep()
	var house := keeper.grid.tile_index(KEEP_TX, KEEP_TY)
	t.ok(keeper.keep_tiles.has(house), "자가 점검 — 그 조각이 성채 자리다")
	t.ok(not keeper.can_place_store(house), "성채 위에는 못 짓는다")
	t.ok(keeper.can_place_store(keeper.grid.tile_index(SPOT_TX, SPOT_TY)),
		"대조군 — 그 옆 빈 땅에는 지을 수 있다")

	# -- on a body ---------------------------------------------------------------------------------
	var manned := _battle()
	var under := manned.grid.tile_index(SPOT_TX, SPOT_TY)
	t.ok(manned.can_place_store(under), "자가 점검 — 아무도 없을 때는 지을 수 있다")
	t.eq(manned.place_ashore(0, under), under, "자가 점검 — 거기에 몸을 세웠다")
	t.ok(not manned.can_place_store(under), "몸이 선 조각에는 못 짓는다 — 사람을 벽 안에 가두지 않는다")

	# -- on a 바리케이트 ---------------------------------------------------------------------------
	var walled := _battle()
	var wall_tile := walled.grid.tile_index(OTHER_TX, OTHER_TY)
	walled.store.add("wood", Rules.BARRICADE_WOOD)
	t.ok(walled.place_barricade(wall_tile), "자가 점검 — 바리케이트를 세웠다")
	t.ok(not walled.can_place_store(wall_tile), "바리케이트 위에는 못 짓는다")

	# -- on the 창고 itself -------------------------------------------------------------------------
	var built := _battle()
	var spot := built.grid.tile_index(SPOT_TX, SPOT_TY)
	t.ok(built.place_store(spot), "자가 점검 — 창고를 세웠다")
	t.ok(not built.can_place_store(spot), "이미 선 창고 자리에는 다시 못 짓는다 — 제자리로 옮기는 것도 아니다")


## **Two builds leave ONE 창고** — 「one building」 is the user's own word for it.
##
## ⚠⚠ **THE SECOND BUILD MOVES IT AND DOES NOT REFUSE IT, AND NOBODY CHOSE WHICH.** `store_tile` is one
## integer, so two 창고 are unrepresentable and the count can only ever be one; **what is open is
## whether the second press should have been refused instead.** The row asserts what the code does —
## the old 조각 released, the new one held — so the day the user says 「refuse it」 exactly one line
## here goes red and says where.
func _a_second_store_does_not_make_two(t) -> void:
	var b := _battle()
	var g := b.grid
	var first := g.tile_index(SPOT_TX, SPOT_TY)
	var second := g.tile_index(OTHER_TX, OTHER_TY)
	var hand := Hand.new()
	hand.take_the_building(Builds.STORE)
	t.ok(hand.build(b, first), "자가 점검 — 첫 창고가 섰다")
	t.eq(b.store_tile, first, "자가 점검 — 그 조각이다")

	t.ok(hand.take_the_building(Builds.STORE), "자가 점검 — 다시 집었다")
	t.ok(hand.build(b, second), "둘째로 누른 자리에도 선다")
	t.eq(b.store_tile, second, "창고 자리는 둘째 조각 하나다 — 둘이 되지 않는다")
	t.eq(g.hold_count(first), 0, "첫 조각은 도로 걸어 다닐 수 있게 놓인다")
	t.ok(g.hold_count(second) > 0, "그리고 둘째 조각을 잡고 있다")
	t.eq(b.place_ashore(0, first), first, "그래서 첫 조각에 다시 설 수 있다")


## **The first 창고 costs nothing, and that is a decision nobody has made.**
##
## ⚠⚠ **05-08's OWN 「NOT DECIDED」**: 「a 창고 that costs wood before any wood can be stored is a chicken
## and an egg, and the first 창고 may cost nothing — that was not asked.」 **Left free, exactly as the
## code stands.** This row is here so the price arriving is a red line with a name on it rather than a
## silent change, and it is written with a full 창고 so a charge of any kind would show.
func _the_first_store_is_free(t) -> void:
	var b := _battle()
	var g := b.grid
	b.store.add("wood", 9)
	b.store.add("rock", 4)
	var before := b.store.total()
	var hand := Hand.new()
	hand.take_the_building(Builds.STORE)
	t.ok(hand.build(b, g.tile_index(SPOT_TX, SPOT_TY)), "자가 점검 — 창고가 섰다")
	t.eq(b.store.total(), before, "짓는 데 아무것도 안 든다 — 값은 아직 안 정해졌다")
	t.eq(b.store.count("wood"), 9, "나무도 그대로다")


# == the loop closes ==================================================================================

## **The 창고 the hand put up is the 창고 a catch goes into.**
##
## ⚠⚠ **THIS IS THE LOOP THAT HAS NEVER CLOSED.** Gathering needs somewhere to put a thing
## (`_phase_gather` refuses outright while `store_tile` is -1), and until 짓기 모드 there was no way for
## a player to make that somewhere. **The row drives the whole chain**: take the building up, press a
## 조각, and then stand a body on the water's edge and watch the count rise. ⚠ Each half is measured on
## its own elsewhere; this says they meet.
func _what_is_gathered_goes_into_the_store_that_was_built(t) -> void:
	var b := _battle()
	var g := b.grid
	t.ok(b.place_ashore(0, g.tile_index(SHORE_TX, SHORE_TY)) >= 0, "자가 점검 — 몸이 물가에 섰다")
	t.ok(g.is_coast(b._tile_of(b.soldier_pos[0])), "자가 점검 — 그 조각은 물가다")

	# **Nothing comes in before the building does** — the floor without which the row below is true of
	# a board that never had a 창고 at all.
	_run_for(b, Rules.GATHER_SEC * 1.5)
	t.eq(b.store.total(), 0, "창고를 짓기 전에는 아무것도 안 들어온다")

	var hand := Hand.new()
	hand.take_the_building(Builds.STORE)
	t.ok(hand.build(b, g.tile_index(SPOT_TX, SPOT_TY)), "자가 점검 — 눌러서 창고를 세웠다")
	_run_for(b, Rules.GATHER_SEC * 1.2)
	t.eq(b.store.count("fish"), 1, "그러고 나면 잡은 것이 그 창고에 쌓인다")


# == fixtures =========================================================================================

## **The pool board, `n` 검사 on the roster, no 성채.**
func _battle(n: int = 1) -> Battle:
	return _stand(n, PackedInt32Array())


## **The same board with a two-조각 성채 in the south-west corner.**
func _battle_with_keep() -> Battle:
	var g := Grid.new()
	g.load_rows(POOL)
	var keep := PackedInt32Array([g.tile_index(KEEP_TX, KEEP_TY),
		g.tile_index(KEEP_TX + 1, KEEP_TY)])
	return _stand(1, keep)


func _stand(n: int, keep: PackedInt32Array) -> Battle:
	var g := Grid.new()
	g.load_rows(POOL)
	var army := Army.new()
	var slot := army.register_species(Rules.SWORDSMAN)
	for _i in n:
		army.recruit(slot)
	var b := Battle.new()
	b.setup(g, army, [], keep, -1)
	return b


## Steps `seconds` of simulated time in whole frames — the shell's own step, so a rule that only holds
## for one giant `dt` is a rule that never runs in the game.
func _run_for(b: Battle, seconds: float) -> void:
	for _k in int(seconds * 60.0):
		b.step(1.0 / 60.0)
