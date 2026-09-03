extends RefCounted
## **허기 wears down, an unfed body dies, and a body that can reach the 창고 feeds itself.**
## Tickets 05-07 and 05-08.
##
## The claim under test is one sentence: **every body ashore loses 허기 at `Rules.HUNGER_DRAIN_PER_SEC`,
## a body at zero loses 체력 at `Rules.STARVE_HP_PER_SEC` until it dies with `soldier_starving` raised
## the whole way, and a body below `Rules.HUNGER_SEEK` walks to a 창고 that has food and eats — while a
## body already carrying the player's order is left alone.**
##
## ⚠⚠ **NOTHING HERE TOUCHES THE TREE.** `Grid.new()`, `Army.new()`, `Battle.new()` and `Store.new()`
## are the whole fixture — the `src/sim/` seam.
##
## ⚠⚠ **THE STARVING COLUMN IS MEASURED AND IT IS NOT DECORATION.** The picture reads 「health went
## down」 as 피격 — the simulation keeps no event list at all — so without that column a starving body
## flinches on every frame until it falls, beaten by nothing for half a minute. **`field_view` skips
## the flinch while the column is 1**, so a column that stopped being written would put the flinch loop
## back with every other number here still green.
##
## ⚠ **The numbers are the builder's, not the user's** — 05-07 records that being asked and refused
## (「몇 초까지는 너무 커」). **So every row below asserts against `Rules`, never against a literal**: a
## row written to 0.4 would go red the moment the user changes the pace on screen, which is what the
## constant is for.
##
## ⚠ **The labels are Korean because they are printed output**; the prose is English.

## An all-land flat board. ⚠ **No 성채**: `Grid.block_hold_count` counts the house as one body and a
## keep near the fixture 조각 would change what fits beside the 창고 for a reason unrelated to hunger.
const FIELD := [
	"........",
	"........",
	"........",
	"........",
	"........",
	"........",
]
const HOME_TX := 1
const HOME_TY := 1
## Where the 창고 goes in the rows that build one — far from home, so a body has to walk to it.
const STORE_TX := 6
const STORE_TY := 4


func run(t) -> void:
	_the_store_stacks_by_kind(t)
	_wood_is_not_food(t)
	_an_island_opens_with_no_store(t)
	_a_store_stands_on_its_own_piece(t)
	_hunger_wears_down_at_the_rate_the_rules_give(t)
	_at_zero_hunger_health_drains_and_the_body_dies(t)
	_a_hungry_body_walks_to_the_store_and_eats(t)
	_a_body_under_orders_is_not_pulled_off_them(t)
	_a_body_that_stands_again_stands_fed(t)
	# **The sentinel.** See `run_nets.done` — without it a `run()` that dies half way still reports
	# every check it managed first, in a shape a healthy net cannot be told from.
	t.done()


# == the 창고 as a pile of numbers =====================================================================

## **Six kinds, each its own count, and taking more than is there takes what is there.**
func _the_store_stacks_by_kind(t) -> void:
	var s := Store.new()
	t.eq(s.total(), 0, "새 창고는 비어 있다")
	t.eq(s.counts.size(), Store.KINDS.size(), "자가 점검 — 칸이 종류 수만큼 있다")
	s.add("fish", 3)
	s.add("wood", 5)
	t.eq(s.count("fish"), 3, "물고기가 셋 쌓인다")
	t.eq(s.count("wood"), 5, "나무가 다섯 쌓인다 — 물고기와 따로다")
	t.eq(s.count("rock"), 0, "안 넣은 종류는 0 이다")
	t.eq(s.total(), 8, "전부 합치면 여덟이다")
	t.eq(s.take("fish", 10), 3, "열을 꺼내려 해도 있는 셋만 나온다")
	t.eq(s.count("fish"), 0, "그러고 나면 물고기는 0 이다 — 음수가 아니다")
	t.eq(s.add("gold", 4), 0, "없는 종류는 안 들어간다")
	t.eq(s.take("gold", 4), 0, "없는 종류는 안 나온다")
	t.eq(s.total(), 5, "그 사이 나무 다섯은 그대로다")


## **A 창고 holding nothing but wood starves the island.**
##
## ⚠⚠ **THIS IS THE ROW `total() > 0` WOULD HAVE PASSED.** 「Is there anything in the store」 and 「is
## there anything to eat」 are different questions, and a hungry body asking the first one walks to a
## woodpile and stands there.
func _wood_is_not_food(t) -> void:
	var s := Store.new()
	s.add("wood", 9)
	s.add("rock", 9)
	s.add("ore", 9)
	t.eq(s.total(), 27, "자가 점검 — 창고에 스물일곱이 쌓여 있다")
	t.ok(not s.has_food(), "그런데 먹을 것은 하나도 없다")
	t.eq(s.take_meal(), "", "한 끼도 안 나온다")
	s.add("fish", 1)
	t.ok(s.has_food(), "물고기 하나가 들어오면 먹을 것이 생긴다")
	t.eq(s.take_meal(), "fish", "그리고 그 한 끼는 물고기다")
	t.eq(s.count("wood"), 9, "먹는 것은 나무를 안 건드린다")


# == the building =====================================================================================

## **A run opens with no 창고** (2026-09-02, the user: 「지어야 되고」 — *it has to be built*).
func _an_island_opens_with_no_store(t) -> void:
	var b := _battle(1)
	t.eq(b.store_tile, -1, "첫 판에는 창고가 없다")
	t.ok(b.store != null, "자가 점검 — 그래도 셀 것은 서 있다")
	t.eq(b.store.total(), 0, "쌓인 것도 없다")
	t.eq(b.store_doorstep().size(), 0, "창고가 없으니 서서 먹을 자리도 없다")


## **The 창고 takes its whole 조각, and a body eats from beside it.**
##
## ⚠⚠ **`grid.fill` AND NOT `grid.hold`, THE SAME RULE THE 성채 HOLDS.** A 조각 admits
## `Rules.TILE_CAPACITY` bodies, so a building holding one slot leaves the rest free and every body on
## the island walks into it. **The doorstep row below is what says the building is reachable at all.**
func _a_store_stands_on_its_own_piece(t) -> void:
	var b := _battle(1)
	var g := b.grid
	var tile := g.tile_index(STORE_TX, STORE_TY)
	t.ok(g.has_room(tile), "자가 점검 — 세우기 전에는 그 조각에 자리가 있다")
	t.ok(b.place_store(tile), "창고가 선다")
	t.eq(b.store_tile, tile, "그리고 그 조각에 선다")
	t.ok(not g.has_room(tile), "그 조각에는 이제 아무도 못 선다 — 건물이 조각을 통째로 쥔다")
	t.eq(b.store_doorstep().size(), 8, "가운데 조각이라 서서 먹을 자리가 여덟이다")
	# **Moved, never doubled.** One 창고 an island is the user's own word for it.
	var other := g.tile_index(STORE_TX - 2, STORE_TY)
	t.ok(b.place_store(other), "다른 조각에 다시 세우면 옮겨간다")
	t.eq(b.store_tile, other, "창고는 새 조각에 있다")
	t.ok(g.has_room(tile), "옛 조각은 다시 비었다 — 창고가 둘이 되지 않는다")


# == 허기 ============================================================================================

## **허기 falls at the rate `Rules` gives, and by no other amount.**
##
## ⚠ **Ten simulated seconds and not one**, so the drop is far bigger than a sub-step's rounding.
func _hunger_wears_down_at_the_rate_the_rules_give(t) -> void:
	var b := _battle(1)
	var ids := _stand(b, 1)
	t.eq(ids.size(), 1, "자가 점검 — 몸 하나가 섰다")
	t.eq(b.army.hunger_of(0), Rules.HUNGER_MAX, "자가 점검 — 서는 순간 허기는 가득이다")
	_run_for(b, 10.0)
	var want: float = Rules.HUNGER_MAX - Rules.HUNGER_DRAIN_PER_SEC * 10.0
	t.ok(absf(b.army.hunger_of(0) - want) < 0.05,
		"십 초에 허기가 %.2f 로 내려간다 (실측 %.3f)" % [want, b.army.hunger_of(0)])
	t.eq(int(b.soldier_starving[0]), 0, "아직 굶는 중이 아니다 — 허기가 남아 있다")
	t.eq(b.soldier_hp[0], b.army.max_hp_of(0), "체력은 하나도 안 깎였다")


## **At zero 허기 the 체력 falls, `soldier_starving` says so the whole way, and the body dies.**
##
## ⚠⚠ **THE STARVING COLUMN IS ASSERTED WHILE IT MATTERS, NOT ONCE.** The picture reads a drop in
## health as 피격, so a column raised on the first sub-step and dropped on the second would still put
## a flinch on the body every frame after that. **It is sampled every step of the fall.**
## ⚠ **The 허기 is set straight to a sliver rather than waiting four minutes for it.** Driving the
## rate is the row above; this row is about what happens at the bottom.
func _at_zero_hunger_health_drains_and_the_body_dies(t) -> void:
	var b := _battle(1)
	_stand(b, 1)
	b.army.hunger[0] = 0.5
	var full: float = b.soldier_hp[0]
	t.ok(full > 0.0, "자가 점검 — 몸이 온전히 섰다")
	_run_for(b, 2.0)
	t.eq(b.army.hunger_of(0), 0.0, "허기가 0 까지 닳는다")
	t.ok(b.soldier_hp[0] < full, "그리고 체력이 깎이기 시작한다 (%.2f → %.2f)" % [full, b.soldier_hp[0]])
	t.eq(int(b.soldier_starving[0]), 1, "굶는 중이라는 표시가 서 있다")

	var raised := 0
	var samples := 0
	while b.soldier_hp[0] > 0.0 and int(b.soldier_state[0]) == Battle.SoldierState.ASHORE and samples < 200:
		b.step(0.5)
		samples += 1
		if int(b.soldier_starving[0]) == 1 or int(b.soldier_state[0]) != Battle.SoldierState.ASHORE:
			raised += 1
	t.eq(raised, samples, "떨어지는 내내 굶는 중 표시가 서 있다 — 한 프레임도 안 빠진다")
	t.eq(int(b.soldier_state[0]), Battle.SoldierState.DEAD, "굶으면 죽는다")
	t.ok(samples < 200, "자가 점검 — 죽기까지 %d 번 밟았다, 한없이 도는 게 아니다" % [samples])


## **A hungry body walks to the 창고 on its own and eats — and the fish is gone from the pile.**
##
## ⚠⚠ **THE SELF-CHECKS ARE THE TRAP.** 「허기 went up」 is green for a body that started next to the
## 창고, green for a 창고 that fed it without being reached, and green for a body nobody made hungry.
## **So the row proves the trap is laid first**: the body is far from the 창고, it is below the seeking
## line, the pile has exactly one fish, and nobody ordered it anywhere.
func _a_hungry_body_walks_to_the_store_and_eats(t) -> void:
	var b := _battle(1)
	var g := b.grid
	_stand(b, 1)
	t.ok(b.place_store(g.tile_index(STORE_TX, STORE_TY)), "자가 점검 — 창고가 섰다")
	b.store.add("fish", 1)
	b.army.hunger[0] = Rules.HUNGER_SEEK - 5.0
	var start: float = (b.soldier_pos[0] as Vector2).distance_to(Vector2(STORE_TX, STORE_TY))
	t.ok(start > Rules.EAT_RANGE_TILES + 2.0,
		"자가 점검 — 몸은 창고에서 %.1f 조각 떨어져 있다" % [start])
	t.eq(int(b.soldier_order[0]), -1, "자가 점검 — 아무도 명령을 안 내렸다")
	t.eq(b.store.count("fish"), 1, "자가 점검 — 창고에 물고기가 딱 하나다")

	# One sub-step is enough for the body to give itself the order; the walk takes longer.
	b.step(Rules.SIM_SUBSTEP_SEC)
	t.ok(int(b.soldier_order[0]) >= 0, "몸이 스스로 창고로 갈 명령을 낸다")
	var doorstep := b.store_doorstep()
	var to_door := false
	for k in doorstep.size():
		if int(doorstep[k]) == int(b.soldier_order[0]):
			to_door = true
	t.ok(to_door, "그 명령은 창고 옆 조각이다 — 건물 위가 아니다")

	_run_for(b, 30.0)
	t.eq(b.store.count("fish"), 0, "물고기가 창고에서 없어진다")
	t.ok(b.army.hunger_of(0) > Rules.HUNGER_SEEK, "먹어서 허기가 찬다 (실측 %.1f)" % [b.army.hunger_of(0)])
	t.eq(int(b.soldier_starving[0]), 0, "굶는 중이 아니다")
	var ended: float = (b.soldier_pos[0] as Vector2).distance_to(Vector2(STORE_TX, STORE_TY))
	t.ok(ended <= Rules.EAT_RANGE_TILES + 0.5, "몸은 창고 옆에 서 있다 (%.2f 조각)" % [ended])


## **A body already carrying the player's order is left to starve rather than pulled off it.**
##
## ⚠⚠ **THIS IS THE HALF THAT WAS NOT ASKED** (05-07: 「whether an eating body stops what it was doing
## — not asked」). **A 부대 that walked out of a fight to eat is a decision nobody made**, so the
## cautious answer is what is built, and this row is what says which answer that is. ⚠ **It goes red
## the day the user says the opposite, which is the point of writing it down.**
func _a_body_under_orders_is_not_pulled_off_them(t) -> void:
	var b := _battle(1)
	var g := b.grid
	_stand(b, 1)
	t.ok(b.place_store(g.tile_index(STORE_TX, STORE_TY)), "자가 점검 — 창고가 섰다")
	b.store.add("fish", 5)
	b.army.hunger[0] = Rules.HUNGER_SEEK - 5.0
	var far := g.tile_index(1, 5)
	t.ok(b.order_walk(0, far), "자가 점검 — 플레이어가 반대쪽으로 보냈다")
	b.step(Rules.SIM_SUBSTEP_SEC)
	t.eq(int(b.soldier_order[0]), far, "명령은 플레이어가 준 자리 그대로다 — 창고가 안 가로챈다")
	t.eq(b.store.count("fish"), 5, "그 사이 창고의 물고기는 하나도 안 줄었다")


## **A body that stands again stands fed** — the revival is not a formality.
##
## ⚠⚠ **WITHOUT THIS A STARVED BODY DIES AGAIN ON ITS FIRST SUB-STEP BACK**, at zero 허기, forever.
## `place_ashore` is the one door onto the island and 「standing whole」 is one sentence, so 허기 refills
## exactly where 체력 does.
func _a_body_that_stands_again_stands_fed(t) -> void:
	var b := _battle(1, true)
	_stand(b, 1)
	# **Starved to nothing, on purpose.** The body has to go through a real death and a real revival —
	# writing 허기 back by hand would measure the assignment rather than the door it goes through.
	b.army.hunger[0] = 0.0
	b.soldier_hp[0] = 0.0
	b.step(Rules.SIM_SUBSTEP_SEC)
	t.eq(int(b.soldier_state[0]), Battle.SoldierState.DEAD, "자가 점검 — 몸이 죽었다")

	# ⚠⚠ **READ ON THE SUB-STEP THE BODY STANDS, AND THAT IS THE WHOLE OF THIS ROW'S CORRECTION.** It
	# used to run a whole second past the revival and then demand an untouched `HUNGER_MAX` — and 허기
	# drains every sub-step a body is ASHORE, so that second cost it 0.4 and the row was red for
	# something the sim does on purpose. **The ordering is what says the sim is right**: `step` runs
	# `_phase_hunger` FIRST and `_phase_muster` LAST, so the refill is the last write on the sub-step a
	# body stands and nothing drains between them. ⚠ **The expectation did not move** — it is still
	# exactly `HUNGER_MAX`; the moment it is read did.
	var stood := _step_until_ashore(b, 0, Rules.REVIVE_SEC + 1.0)
	t.ok(stood > 0, "자가 점검 — 다시 서기까지 서브스텝 %d 번을 돌았다 (0 이면 아무것도 안 잰 것이다)" % stood)
	t.eq(int(b.soldier_state[0]), Battle.SoldierState.ASHORE, "자가 점검 — 다시 섰다")
	t.eq(b.army.hunger_of(0), Rules.HUNGER_MAX, "다시 선 몸의 허기는 가득이다")
	t.eq(int(b.soldier_starving[0]), 0, "굶는 중 표시도 내려간다")

	# ⚠ **And it stays standing.** Reading 허기 on the standing sub-step alone is green for a refill
	# that is undone on the next one — which is the very failure this row exists for (a body back at
	# zero 허기 dies again immediately, forever). One more second, and the body is still on the board
	# with 허기 above the 창고 line.
	_run_for(b, 1.0)
	t.eq(int(b.soldier_state[0]), Battle.SoldierState.ASHORE, "일 초 더 돌아도 그대로 서 있다 — 바로 다시 안 죽는다")
	t.ok(b.army.hunger_of(0) > Rules.HUNGER_SEEK,
		"그 사이 허기는 창고를 찾는 선 위에 있다 (실측 %.1f)" % [b.army.hunger_of(0)])


# == fixtures =========================================================================================

## **A flat board, `n` 검사, and a `Battle` on it with no 성채.** ⚠ **No 성채 on purpose** — see `FIELD`.
func _battle(n: int, muster: bool = false) -> Battle:
	var g := Grid.new()
	g.load_rows(FIELD)
	var army := Army.new()
	var slot := army.register_species(Rules.SWORDSMAN)
	for _i in n:
		army.recruit(slot)
	var b := Battle.new()
	# ⚠ **A muster 조각 only where a row needs a body to come BACK.** `Battle.stand_at_keep` answers -1
	# without one, so a revival row on a board with no muster point would measure nothing at all — and
	# every other row here wants the 성채 out of the way, per `FIELD`.
	b.setup(g, army, [], PackedInt32Array(), g.tile_index(HOME_TX, HOME_TY) if muster else -1)
	return b


## Stands `n` bodies in the home corner and answers the ids that landed.
func _stand(b: Battle, n: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var home := b.grid.tile_index(HOME_TX, HOME_TY)
	for i in n:
		if b.place_ashore(i, home) >= 0:
			out.append(i)
	return out


## **Steps `seconds` of simulated time in whole frames.** ⚠ **1/60 a call and not one big `dt`** — the
## sub-step loop swallows a large `dt` in one go either way, and stepping in frames is what the shell
## does, so a rule that only holds for a giant step is a rule that never runs in the game.
func _run_for(b: Battle, seconds: float) -> void:
	var frames := int(seconds * 60.0)
	for _k in frames:
		b.step(1.0 / 60.0)


## **Steps one sub-step at a time and stops on the sub-step body `id` is standing.** Answers how many
## sub-steps that took, or 0 if it never stood inside `limit` seconds.
##
## ⚠⚠ **A VALUE WRITTEN AT A DOOR HAS TO BE READ AT THAT DOOR.** `_run_for` swallows the whole duration,
## so anything the sim changes per sub-step has already moved by the time it returns — which is exactly
## how the revival row came to demand a full 허기 a second after the refill.
## ⚠ **The count is answered rather than the state** so the caller can put a floor under it: a loop that
## exits on its first pass, or never enters, is green in every reading of final state.
func _step_until_ashore(b: Battle, id: int, limit: float) -> int:
	var steps := int(limit / Rules.SIM_SUBSTEP_SEC)
	for k in steps:
		b.step(Rules.SIM_SUBSTEP_SEC)
		if int(b.soldier_state[id]) == Battle.SoldierState.ASHORE:
			return k + 1
	return 0
