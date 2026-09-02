extends RefCounted
## **A body standing on the water's edge fishes, and the fish goes into the 창고.** Ticket 05-09.
##
## The claim under test is one sentence: **a body ashore on a coast 조각, with no order and nothing to
## fight and a 창고 standing, puts one fish in the 창고 every `Rules.FISH_SEC` — and a body inland, a body
## walking, or an island with no 창고 puts in none.**
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

## **All land but a pool in the middle.** The 조각 around the pool are the water's edge; the corners are
## as far from water as this board goes.
const POND := [
	".........",
	".........",
	"...~~~...",
	"...~~~...",
	"...~~~...",
	".........",
	".........",
]
## On the pool's edge, and as far from it as the board allows.
const SHORE_TX := 2
const SHORE_TY := 3
const INLAND_TX := 0
const INLAND_TY := 0
## Where the 창고 goes — on land, off the shore, so it is never the 조각 being fished from.
const STORE_TX := 8
const STORE_TY := 3


func run(t) -> void:
	_the_pond_is_water_with_no_boats(t)
	_a_body_on_the_shore_fills_the_store(t)
	_a_body_inland_catches_nothing(t)
	_with_no_store_there_is_no_catch(t)
	_a_body_that_walks_away_loses_the_catch(t)
	_the_fish_it_caught_is_what_feeds_it(t)
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
	_run_for(b, Rules.BOAT_FIRST_SEC + Rules.FISH_SEC * 2.0)
	t.eq(b.boat_pos.size(), 0, "자가 점검 — 그래서 배가 한 척도 안 뜬다")
	t.eq(b.enemy_type.size(), 0, "짐승도 하나도 안 내린다")


# == the catch ========================================================================================

## **One fish every `Rules.FISH_SEC`, and none before the first one is due.**
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

	_run_for(b, Rules.FISH_SEC * 0.5)
	t.eq(b.store.count("fish"), 0, "절반 시간에는 아직 한 마리도 안 잡힌다")
	_run_for(b, Rules.FISH_SEC * 0.6)
	t.eq(b.store.count("fish"), 1, "%.0f 초에 한 마리가 창고에 들어간다" % [Rules.FISH_SEC])
	_run_for(b, Rules.FISH_SEC)
	t.eq(b.store.count("fish"), 2, "그다음 %.0f 초에 한 마리가 더 들어간다" % [Rules.FISH_SEC])
	t.eq(b.store.count("wood"), 0, "다른 종류는 안 늘어난다")


## **A body nowhere near water catches nothing, however long it stands there.**
func _a_body_inland_catches_nothing(t) -> void:
	var b := _battle()
	var g := b.grid
	b.place_ashore(0, g.tile_index(INLAND_TX, INLAND_TY))
	t.ok(b.place_store(g.tile_index(STORE_TX, STORE_TY)), "자가 점검 — 창고가 섰다")
	t.ok(not g.is_coast(b._tile_of(b.soldier_pos[0])), "자가 점검 — 몸이 물가가 아닌 데 섰다")
	_run_for(b, Rules.FISH_SEC * 3.0)
	t.eq(b.store.count("fish"), 0, "물가가 아니면 아무리 서 있어도 안 잡힌다")


## **With no 창고 there is nowhere to put a fish, so there is no catch.**
func _with_no_store_there_is_no_catch(t) -> void:
	var b := _battle()
	b.place_ashore(0, b.grid.tile_index(SHORE_TX, SHORE_TY))
	t.eq(b.store_tile, -1, "자가 점검 — 창고가 없다")
	_run_for(b, Rules.FISH_SEC * 3.0)
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
	_run_for(b, Rules.FISH_SEC * 0.9)
	t.ok(float(b.soldier_fish[0]) > Rules.FISH_SEC * 0.5, "자가 점검 — 거의 다 잡았다")

	t.ok(b.order_walk(0, g.tile_index(INLAND_TX, INLAND_TY)), "자가 점검 — 구석으로 보냈다")
	b.step(Rules.SIM_SUBSTEP_SEC)
	t.eq(b.soldier_fish[0], 0.0, "걸어가기 시작하면 잡던 것이 없어진다")
	_run_for(b, Rules.FISH_SEC * 0.5)
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
	_run_for(b, Rules.FISH_SEC * 1.2)
	t.eq(b.store.count("fish"), 1, "자가 점검 — 한 마리를 잡아 뒀다")

	b.army.hunger[0] = Rules.HUNGER_SEEK - 5.0
	var hungry: float = b.army.hunger_of(0)
	# ⚠ **Under `Rules.FISH_SEC`, deliberately.** The body walks two 조각 and eats in a second or two;
	# giving it a whole catch's worth of time would land a SECOND fish in the 창고 and the count below
	# would read 1 for two different reasons.
	_run_for(b, Rules.FISH_SEC * 0.8)
	t.eq(b.store.count("fish"), 0, "배고파지면 그 물고기를 먹는다")
	t.ok(b.army.hunger_of(0) > hungry, "허기가 다시 찬다 (%.1f → %.1f)" % [hungry, b.army.hunger_of(0)])
	t.eq(int(b.soldier_starving[0]), 0, "굶는 중이 아니다")


# == fixtures =========================================================================================

## **The pond board, one 검사 on the roster, no 성채 and no doorstep.** ⚠ **No 성채 on purpose** — this
## board has no beach, so nothing can attack one, and a house would only take a 조각 out of the count.
func _battle() -> Battle:
	var g := Grid.new()
	g.load_rows(POND)
	var army := Army.new()
	var slot := army.register_species(Rules.SWORDSMAN)
	army.recruit(slot)
	var b := Battle.new()
	b.setup(g, army, [], PackedInt32Array(), -1)
	return b


## Steps `seconds` of simulated time in whole frames — the shell's own step, so a rule that only holds
## for one giant `dt` is a rule that never runs in the game.
func _run_for(b: Battle, seconds: float) -> void:
	for _k in int(seconds * 60.0):
		b.step(1.0 / 60.0)
