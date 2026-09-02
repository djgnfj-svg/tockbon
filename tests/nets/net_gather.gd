extends RefCounted
## **A body gathers where it stands — fish on the water's edge, wood beside a tree 칸 — and it goes
## into the 창고.** Tickets 05-05 and 05-09.
##
## The claim under test is one sentence: **a body ashore with no order and nothing to fight and a 창고
## standing puts one unit in the 창고 every `Rules.GATHER_SEC` — fish if it is on the coast, the resource
## of the 칸 beside it if there is one, and nothing at all inland, while walking, or with no 창고.**
##
## ⚠⚠ **THE POND IS NOT DECORATION — IT IS WHAT KEEPS THE BOATS OUT.** A board with open sea launches a
## beast boat at `Rules.BOAT_FIRST_SEC`, and a catch takes ten seconds, so every row here would be
## measuring a fight it did not ask for. **An inland pool is water with no crossing to it**:
## `Grid._build_ring` refuses an inner shore whose seaward line runs into the island, which is a
## measured rule with a number on it (22 조각 went back into the ring the day it was dropped). **The
## first row asserts no hull was born**, so if that ever stops being true this file says so rather than
## quietly starting to measure wolves.
##
## ⚠⚠ **NOTHING HERE TOUCHES THE TREE.** `Grid.new()`, `Army.new()` and `Battle.new()` are the fixture.
##
## ⚠ **The good spot two 칸 out is NOT measured here and cannot be.** It needs the 나무 배, and there is
## no player boat in this game — 05-09 says so and this net covers the coast half only.
##
## ⚠ **The labels are Korean because they are printed output**; the prose is English.

## **All land but a pool in the middle and one resource 칸 in the south-east.** The 조각 around the pool
## are the water's edge; the corner is as far from water as this board goes; the `#` 칸 is impassable
## and dry, which is exactly what `Grid.set_resources` looks for.
## ⚠⚠ **THE `#` PATCH IS ALIGNED TO THE 칸 GRID AND THE FIRST VERSION OF IT WAS NOT.** Written at rows
## 5-6 it covered (6,5) (7,5) (6,6) (7,6) — four 조각 straddling TWO 칸, because a 칸 starts on an even
## row. **`Grid.block_of` then answered a 칸 that was half resource and half open ground**, and every
## row below would have measured that instead. Rows 4-5, columns 6-7, is one whole 칸.
const POND := [
	".........",
	".........",
	"...~~~...",
	"...~~~...",
	"...~~~##.",
	"......##.",
	".........",
]
## On the pool's edge, and as far from it as the board allows.
const SHORE_TX := 2
const SHORE_TY := 3
const INLAND_TX := 0
const INLAND_TY := 0
## Where the 창고 goes — on land, off the shore, so it is never the 조각 being worked from.
const STORE_TX := 8
const STORE_TY := 3
## The resource 칸's north-west 조각; it covers (6,4) (7,4) (6,5) (7,5) — one whole 칸.
const WOOD_TX := 6
const WOOD_TY := 4
## Beside the 칸 and NOT on the water's edge, so what a body gathers there can only be the 칸.
const BESIDE_TX := 7
const BESIDE_TY := 6
## Beside the 칸 AND on the water's edge — the 조각 that makes the two rules compete.
const BOTH_TX := 5
const BOTH_TY := 5
## A pine standing on WALKABLE ground, which is what the hand-drawn island's 54 props are.
## ⚠ **In the northern strip, well away from the pool**, so the 조각 beside it is not the water's edge
## — a body that fished there would answer 「fish」 and the row would never see the scenery question.
const SCENERY_TX := 1
const SCENERY_TY := 0


func run(t) -> void:
	_the_pond_is_water_with_no_boats(t)
	_a_body_on_the_shore_fills_the_store(t)
	_a_body_inland_catches_nothing(t)
	_with_no_store_there_is_no_catch(t)
	_a_body_that_walks_away_loses_the_catch(t)
	_the_fish_it_caught_is_what_feeds_it(t)
	_a_prop_on_walkable_ground_is_scenery(t)
	_a_body_beside_a_resource_block_gathers_it(t)
	_the_block_never_runs_out(t)
	_the_resource_block_beats_the_coast(t)
	_pressing_a_resource_block_sends_the_squad_beside_it(t)
	_the_squad_that_walks_there_gathers(t)
	_a_block_with_no_resource_takes_no_gather_order(t)
	# **The sentinel.** See `run_nets.done` — without it a `run()` that dies half way still reports
	# every check it managed first, in a shape a healthy net cannot be told from.
	t.done()


# == the fixture is what it says ======================================================================

## **The pool is water, its edge is coast, the corner is not — and no boat is ever born.**
##
## ⚠⚠ **EVERY ROW BELOW RESTS ON THE LAST LINE.** A hull on this board would land 늑대 into the middle of
## a ten-second catch and the rows would go red for a reason that has nothing to do with fishing.
func _the_pond_is_water_with_no_boats(t) -> void:
	var b := _battle()
	var g := b.grid
	t.ok(g.is_coast(g.tile_index(SHORE_TX, SHORE_TY)), "웅덩이 옆 조각은 물가다")
	t.ok(not g.is_coast(g.tile_index(INLAND_TX, INLAND_TY)), "구석 조각은 물가가 아니다")
	t.ok(not g.is_coast(g.tile_index(4, 3)), "물 위는 물가가 아니다 — 서지도 못한다")
	t.eq(g.beach_ring(Rules.BOAT_START_DIST_TILES).size(), 0,
		"자가 점검 — 배가 댈 해변이 하나도 없다")
	_run_for(b, Rules.BOAT_FIRST_SEC + Rules.GATHER_SEC * 2.0)
	t.eq(b.boat_pos.size(), 0, "자가 점검 — 그래서 배가 한 척도 안 뜬다")
	t.eq(b.enemy_type.size(), 0, "짐승도 하나도 안 내린다")


# == the catch ========================================================================================

## **One fish every `Rules.GATHER_SEC`, and none before the first one is due.**
##
## ⚠ **The 「not yet」 assertion is half the row.** A build that put a fish in on every sub-step would
## satisfy 「there is a fish after ten seconds」 perfectly.
func _a_body_on_the_shore_fills_the_store(t) -> void:
	var b := _battle()
	var g := b.grid
	b.place_ashore(0, g.tile_index(SHORE_TX, SHORE_TY))
	t.ok(b.place_store(g.tile_index(STORE_TX, STORE_TY)), "자가 점검 — 창고가 섰다")
	t.ok(g.is_coast(b._tile_of(b.soldier_pos[0])), "자가 점검 — 몸이 물가에 섰다")
	t.eq(int(b.soldier_order[0]), -1, "자가 점검 — 아무 명령도 없다")

	_run_for(b, Rules.GATHER_SEC * 0.5)
	t.eq(b.store.count("fish"), 0, "절반 시간에는 아직 한 마리도 안 잡힌다")
	_run_for(b, Rules.GATHER_SEC * 0.6)
	t.eq(b.store.count("fish"), 1, "%.0f 초에 한 마리가 창고에 들어간다" % [Rules.GATHER_SEC])
	_run_for(b, Rules.GATHER_SEC)
	t.eq(b.store.count("fish"), 2, "그다음 %.0f 초에 한 마리가 더 들어간다" % [Rules.GATHER_SEC])
	t.eq(b.store.count("wood"), 0, "다른 종류는 안 늘어난다")


## **A body nowhere near water catches nothing, however long it stands there.**
func _a_body_inland_catches_nothing(t) -> void:
	var b := _battle()
	var g := b.grid
	b.place_ashore(0, g.tile_index(INLAND_TX, INLAND_TY))
	t.ok(b.place_store(g.tile_index(STORE_TX, STORE_TY)), "자가 점검 — 창고가 섰다")
	t.ok(not g.is_coast(b._tile_of(b.soldier_pos[0])), "자가 점검 — 몸이 물가가 아닌 데 섰다")
	_run_for(b, Rules.GATHER_SEC * 3.0)
	t.eq(b.store.count("fish"), 0, "물가가 아니면 아무리 서 있어도 안 잡힌다")


## **With no 창고 there is nowhere to put a fish, so there is no catch.**
func _with_no_store_there_is_no_catch(t) -> void:
	var b := _battle()
	b.place_ashore(0, b.grid.tile_index(SHORE_TX, SHORE_TY))
	t.eq(b.store_tile, -1, "자가 점검 — 창고가 없다")
	_run_for(b, Rules.GATHER_SEC * 3.0)
	t.eq(b.store.total(), 0, "창고가 없으면 잡아도 둘 데가 없다 — 안 잡는다")


## **A body that walks off loses what it had spent, and starts from nothing when it comes back.**
##
## ⚠ **Nobody asked for progress to be kept**, and a catch that survives being interrupted is a
## different rule from the one the user gave. This row is what says which one is built.
func _a_body_that_walks_away_loses_the_catch(t) -> void:
	var b := _battle()
	var g := b.grid
	b.place_ashore(0, g.tile_index(SHORE_TX, SHORE_TY))
	t.ok(b.place_store(g.tile_index(STORE_TX, STORE_TY)), "자가 점검 — 창고가 섰다")
	_run_for(b, Rules.GATHER_SEC * 0.9)
	t.ok(float(b.soldier_gather[0]) > Rules.GATHER_SEC * 0.5, "자가 점검 — 거의 다 잡았다")

	t.ok(b.order_walk(0, g.tile_index(INLAND_TX, INLAND_TY)), "자가 점검 — 구석으로 보냈다")
	b.step(Rules.SIM_SUBSTEP_SEC)
	t.eq(b.soldier_gather[0], 0.0, "걸어가기 시작하면 잡던 것이 없어진다")
	_run_for(b, Rules.GATHER_SEC * 0.5)
	t.eq(b.store.count("fish"), 0, "그래서 물고기는 한 마리도 안 들어간다")


# == the loop closes ==================================================================================

## **A body fishes, gets hungry, and eats what it caught.**
##
## ⚠⚠ **THIS IS THE ONLY ROW IN THE REPOSITORY WHERE FOOD IS PRODUCED AND THEN CONSUMED.** 허기 kills
## (05-07) and the 창고 counts (05-08), and until this ticket nothing anywhere put a single thing into
## it — the hunger loop was a death sentence with no answer. **The row is here to say the two halves
## meet**, not to measure either one of them again.
func _the_fish_it_caught_is_what_feeds_it(t) -> void:
	var b := _battle()
	var g := b.grid
	# **The 창고 is next to the shore for this row**, so the body's walk to eat is short and the row is
	# about the loop rather than about how fast a body walks.
	b.place_ashore(0, g.tile_index(SHORE_TX, SHORE_TY))
	t.ok(b.place_store(g.tile_index(SHORE_TX, SHORE_TY + 2)), "자가 점검 — 창고가 물가 옆에 섰다")
	_run_for(b, Rules.GATHER_SEC * 1.2)
	t.eq(b.store.count("fish"), 1, "자가 점검 — 한 마리를 잡아 뒀다")

	b.army.hunger[0] = Rules.HUNGER_SEEK - 5.0
	var hungry: float = b.army.hunger_of(0)
	# ⚠ **Under `Rules.GATHER_SEC`, deliberately.** The body walks two 조각 and eats in a second or two;
	# giving it a whole catch's worth of time would land a SECOND fish in the 창고 and the count below
	# would read 1 for two different reasons.
	_run_for(b, Rules.GATHER_SEC * 0.8)
	t.eq(b.store.count("fish"), 0, "배고파지면 그 물고기를 먹는다")
	t.ok(b.army.hunger_of(0) > hungry, "허기가 다시 찬다 (%.1f → %.1f)" % [hungry, b.army.hunger_of(0)])
	t.eq(int(b.soldier_starving[0]), 0, "굶는 중이 아니다")


# == the resource 칸 ==================================================================================

## **A prop standing on ground a body can WALK on is scenery, and gathering never sees it.**
##
## ⚠⚠ **THIS IS THE WHOLE OF WHAT SEPARATES THE DRAWN ISLAND FROM A GENERATED ONE.** The island the
## user drew carries 31 pines, 17 bushes, 3 rocks and an ore standing on walkable land — placed as
## 풍경 on 2026-08-31, 「게임이 도는 동안 이것에 대해 정하는 것이 없다」. **A generated island cuts its
## resource 칸 out of the board and stands the same props on the hole.** If passability stopped being
## the test, every pine on the drawn island would become a woodpile the day this shipped.
func _a_prop_on_walkable_ground_is_scenery(t) -> void:
	var b := _battle()
	var g := b.grid
	var scenery := g.tile_index(SCENERY_TX, SCENERY_TY)
	t.eq(g.passable[scenery], 1, "자가 점검 — 그 조각은 걸어 다닐 수 있다")
	g.set_resources([{"kind": "tree_pine", "x": SCENERY_TX, "y": SCENERY_TY}])
	t.eq(g.resource_at(scenery), "", "걸어 다니는 땅에 선 나무는 풍경이다 — 자원 칸이 아니다")

	b.place_ashore(0, g.tile_index(SCENERY_TX + 1, SCENERY_TY))
	t.ok(b.place_store(g.tile_index(STORE_TX, STORE_TY)), "자가 점검 — 창고가 섰다")
	t.eq(b.gatherable_at(b._tile_of(b.soldier_pos[0])), "", "그 옆에 서도 캘 것이 없다")
	_run_for(b, Rules.GATHER_SEC * 2.0)
	t.eq(b.store.count("wood"), 0, "아무리 서 있어도 나무가 안 들어온다")


## **A body standing beside a tree 칸 gathers wood into the 창고.**
##
## ⚠ **Beside it and never on it** — a resource 칸 blocks (「막힌다」), which is why the body stands on
## the 조각 next door and why the 칸 needs no rule of its own on the walking side.
func _a_body_beside_a_resource_block_gathers_it(t) -> void:
	var b := _wooded()
	var g := b.grid
	var wood := g.tile_index(WOOD_TX, WOOD_TY)
	var beside := g.tile_index(BESIDE_TX, BESIDE_TY)
	t.eq(g.passable[wood], 0, "자가 점검 — 자원 칸은 못 지나간다")
	t.eq(g.water[wood], 0, "자가 점검 — 그리고 물도 아니다")
	t.eq(g.resource_at(wood), "wood", "자가 점검 — 그 칸은 나무 칸이다")
	t.ok(not g.is_coast(beside), "자가 점검 — 그 옆 조각은 물가가 아니다 — 물고기와 안 겹친다")

	b.place_ashore(0, beside)
	t.eq(b._tile_of(b.soldier_pos[0]), beside, "자가 점검 — 몸이 그 옆에 섰다")
	t.ok(b.place_store(g.tile_index(STORE_TX, STORE_TY)), "자가 점검 — 창고가 섰다")
	t.eq(b.gatherable_at(beside), "wood", "그 자리에서 캐는 것은 나무다")

	_run_for(b, Rules.GATHER_SEC * 0.5)
	t.eq(b.store.count("wood"), 0, "절반 시간에는 아직 안 들어온다")
	_run_for(b, Rules.GATHER_SEC * 0.6)
	t.eq(b.store.count("wood"), 1, "%.0f 초에 나무 하나가 창고에 들어간다" % [Rules.GATHER_SEC])
	t.eq(b.store.count("fish"), 0, "물고기는 안 들어온다 — 물가가 아니다")


## **The 칸 never runs out** (2026-09-02, the user: 「계속 나와야 될 거 같아」).
##
## ⚠ **Three turns and not one.** A 칸 that emptied after the first would satisfy the row above whole.
func _the_block_never_runs_out(t) -> void:
	var b := _wooded()
	var g := b.grid
	b.place_ashore(0, g.tile_index(BESIDE_TX, BESIDE_TY))
	t.ok(b.place_store(g.tile_index(STORE_TX, STORE_TY)), "자가 점검 — 창고가 섰다")
	_run_for(b, Rules.GATHER_SEC * 3.2)
	t.eq(b.store.count("wood"), 3, "세 번을 캐도 계속 나온다")
	t.eq(g.resource_at(g.tile_index(WOOD_TX, WOOD_TY)), "wood", "그리고 그 칸은 그대로 나무 칸이다")
	t.eq(g.passable[g.tile_index(WOOD_TX, WOOD_TY)], 0, "여전히 못 지나간다 — 캔다고 뚫리지 않는다")


## **A 조각 that is both beside a resource 칸 and on the water's edge gathers the 칸.**
##
## ⚠⚠ **NOBODY CHOSE THIS AND THE ROW IS HERE TO SAY SO.** A body cannot do two things at once, and
## the argument for the 칸 is that somebody put it there while the coast is most of the island's rim.
## **It goes red the day the user says the opposite**, which is the point of writing it down.
func _the_resource_block_beats_the_coast(t) -> void:
	var b := _wooded()
	var g := b.grid
	var both := g.tile_index(BOTH_TX, BOTH_TY)
	t.ok(g.is_coast(both), "자가 점검 — 그 조각은 물가다")
	t.eq(g.resource_at(g.tile_index(WOOD_TX, WOOD_TY)), "wood", "자가 점검 — 그 옆은 나무 칸이다")
	b.place_ashore(0, both)
	t.ok(b.place_store(g.tile_index(STORE_TX, STORE_TY)), "자가 점검 — 창고가 섰다")
	t.eq(b.gatherable_at(both), "wood", "둘 다 되는 자리에서는 자원 칸이 이긴다")
	_run_for(b, Rules.GATHER_SEC * 1.2)
	t.eq(b.store.count("wood"), 1, "그래서 나무가 들어온다")
	t.eq(b.store.count("fish"), 0, "물고기는 안 들어온다")


# == pressing one =====================================================================================

## **A press on a resource 칸 sends the 부대 to the 조각 AROUND it** (2026-09-03, the user: 「딱 눌렀을 때
## 채집하러 갔을 때 잘 갈 거 아니야 ... 거기 가면 채집이다」).
##
## ⚠⚠ **THE 칸 IS NOT LIT AND THAT IS THE WHOLE DIFFICULTY.** It blocks, so no 조각 of it is standable,
## so `can_reach_block` is false and until now the press was swallowed with nothing on screen to say
## why. **The row asserts the 칸 is dark FIRST**, or it would be measuring an ordinary move order.
func _pressing_a_resource_block_sends_the_squad_beside_it(t) -> void:
	var b := _wooded(3)
	var g := b.grid
	var block := g.block_of(g.tile_index(WOOD_TX, WOOD_TY))
	var ids := PackedInt32Array()
	for i in 3:
		if b.place_ashore(i, g.tile_index(INLAND_TX, INLAND_TY)) >= 0:
			ids.append(i)
	t.eq(ids.size(), 3, "자가 점검 — 몸 셋이 구석에 섰다")
	t.ok(b.place_store(g.tile_index(STORE_TX, STORE_TY)), "자가 점검 — 창고가 섰다")

	var hand := Hand.new()
	t.ok(hand.pick_many(b, ids), "자가 점검 — 손이 셋을 쥐었다")
	t.ok(not hand.can_reach_block(block), "자가 점검 — 자원 칸은 불이 안 켜진다 — 막혀 있으니까")
	t.ok(hand.can_gather_block(b, block), "그래도 캐러 갈 수는 있는 칸이다")

	var ring := hand.gather_ring(b, block)
	t.ok(ring.size() >= 3, "자가 점검 — 그 칸 옆에 설 자리가 %d 개 있다" % [ring.size()])
	for k in ring.size():
		t.ok(g.block_of(int(ring[k])) != block, "옆자리는 그 칸 밖이다")

	t.eq(hand.order(b, block), 3, "셋 다 명령을 받는다")
	var seats := PackedInt32Array()
	for k in ids.size():
		seats.append(int(b.soldier_order[int(ids[k])]))
	var on_ring := 0
	for k in seats.size():
		for m in ring.size():
			if int(seats[k]) == int(ring[m]):
				on_ring += 1
				break
	t.eq(on_ring, 3, "셋 다 그 칸 옆자리로 간다 %s" % [seats])
	# **The preview says the same thing**, which is the invariant `routes` exists for.
	var lines := hand.routes(b, block)
	t.eq(lines.size(), 3, "이동선도 셋이 나온다")


## **They walk there and the wood starts coming in.**
##
## ⚠ **The whole chain in one row**: the press, the walk, the order clearing on arrival, and the
## gathering that standing there IS. **Each half is measured on its own elsewhere**; this says they
## meet.
func _the_squad_that_walks_there_gathers(t) -> void:
	var b := _wooded()
	var g := b.grid
	var block := g.block_of(g.tile_index(WOOD_TX, WOOD_TY))
	b.place_ashore(0, g.tile_index(INLAND_TX, INLAND_TY))
	t.ok(b.place_store(g.tile_index(STORE_TX, STORE_TY)), "자가 점검 — 창고가 섰다")
	var hand := Hand.new()
	t.ok(hand.pick_many(b, PackedInt32Array([0])), "자가 점검 — 손이 하나를 쥐었다")
	t.eq(hand.order(b, block), 1, "자가 점검 — 캐러 가라는 명령이 나갔다")
	t.eq(b.store.count("wood"), 0, "자가 점검 — 아직 나무는 0 이다")

	_run_for(b, Rules.GATHER_SEC * 2.0)
	t.ok(b.store.count("wood") >= 1, "걸어가서 서 있으면 나무가 들어온다 (실측 %d)" % [b.store.count("wood")])
	t.ok(b.gatherable_at(b._tile_of(b.soldier_pos[0])) == "wood",
		"몸은 그 칸 옆에 서 있다 — 캐는 것은 나무다")


## **A 칸 with nothing on it is not a gather order**, whatever else it is.
##
## ⚠⚠ **THE CONTROL, AND WITHOUT IT 「the press goes through」 IS TRUE OF EVERY 칸 ON THE BOARD.** The
## middle of the pool is water: unlit, unwalkable and holding no resource — exactly the shape a
## resource 칸 has from `can_reach_block`'s side, and the one that must still answer no.
func _a_block_with_no_resource_takes_no_gather_order(t) -> void:
	var b := _wooded()
	var g := b.grid
	var wet := g.block_of(g.tile_index(4, 3))
	t.eq(g.passable[g.tile_index(4, 3)], 0, "자가 점검 — 물 위는 못 지나간다")
	b.place_ashore(0, g.tile_index(INLAND_TX, INLAND_TY))
	t.ok(b.place_store(g.tile_index(STORE_TX, STORE_TY)), "자가 점검 — 창고가 섰다")
	var hand := Hand.new()
	t.ok(hand.pick_many(b, PackedInt32Array([0])), "자가 점검 — 손이 하나를 쥐었다")
	t.ok(not hand.can_reach_block(wet), "자가 점검 — 물 칸은 불이 안 켜진다")
	t.ok(not hand.can_gather_block(b, wet), "물 칸은 캐러 갈 수 있는 칸이 아니다")
	t.eq(hand.gather_ring(b, wet).size(), 0, "옆자리도 안 나온다")
	t.eq(hand.order(b, wet), 0, "그래서 아무도 안 간다")
	t.eq(int(b.soldier_order[0]), -1, "명령도 안 걸린다")


# == fixtures =========================================================================================

## **The pond board, one 검사 on the roster, no 성채 and no doorstep.** ⚠ **No 성채 on purpose** — this
## board has no beach, so nothing can attack one, and a house would only take a 조각 out of the count.
func _battle(n: int = 1) -> Battle:
	var g := Grid.new()
	g.load_rows(POND)
	var army := Army.new()
	var slot := army.register_species(Rules.SWORDSMAN)
	for _i in n:
		army.recruit(slot)
	var b := Battle.new()
	b.setup(g, army, [], PackedInt32Array(), -1)
	return b


## **The same board with the resource 칸 filled in.** ⚠ **The props are handed to `Grid.set_resources`
## by hand here** — the drawn island's props arrive through `Islands.load_into`, and a fixture that
## went through the file would be measuring the drawn island instead of this board.
func _wooded(n: int = 1) -> Battle:
	var b := _battle(n)
	var props: Array = []
	for dy in Rules.BLOCK_TILES:
		for dx in Rules.BLOCK_TILES:
			props.append({"kind": "tree_pine", "x": WOOD_TX + dx, "y": WOOD_TY + dy})
	b.grid.set_resources(props)
	return b


## Steps `seconds` of simulated time in whole frames — the shell's own step, so a rule that only holds
## for one giant `dt` is a rule that never runs in the game.
func _run_for(b: Battle, seconds: float) -> void:
	for _k in int(seconds * 60.0):
		b.step(1.0 / 60.0)
