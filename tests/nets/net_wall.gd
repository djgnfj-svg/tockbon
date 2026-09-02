extends RefCounted
## **A 바리케이트 stands on one 조각, nothing walks through it, and a beast it has sealed in breaks it
## down.** Ticket 09-02.
##
## The claim under test is one sentence: **a wall raised on a 조각 costs wood out of the 창고, is refused
## by `Grid.can_step` for both sides, is walked AROUND by a beast that can still reach the 성채, is
## ATTACKED by a beast that cannot, and disappears at zero health — after which the way through opens
## again.**
##
## ⚠⚠ **NOTHING HERE TOUCHES THE TREE.** `Grid.new()`, `Army.new()` and `Battle.new()` are the whole
## fixture — the `src/sim/` seam.
##
## ⚠⚠ **THE 「FIND ANOTHER PATH」 HALF NEEDS NO CODE AND THAT IS WHAT THE ROUND ROW MEASURES.** A wall is
## refused inside `Grid.can_step`, so the flow field, the straightened route and `Hand`'s reach all route
## round it without knowing what a wall is. **The rule that needed writing is the other half** — a beast
## with no way through at all — and the two rows are deliberately next to each other: a build that made
## every beast attack every wall would pass the second and fail the first.
##
## ⚠ **The board is landlocked** — no water anywhere, so no boat is born and every beast on it is one a
## row put there. `#` is impassable and DRY, which is what makes a pocket without making a coast.
##
## ⚠ **The labels are Korean because they are printed output**; the prose is English.

## **A pocket with one neck.** `#` walls off column 1 for three rows and the whole top row, so the
## 조각 (0,1) (0,2) (0,3) can be left only through (0,4) — the diagonal out of (0,3) is refused because
## its shoulder (1,3) is blocked, which is `Grid.can_step`'s corner rule and not this file's.
const POCKET := [
	"##########",
	".#........",
	".#........",
	".#........",
	"..........",
	"..........",
]
## The neck — the one 조각 a wall has to stand on to seal the pocket.
const NECK_TX := 0
const NECK_TY := 4
## Inside the pocket, and where the 성채 stands outside it.
const IN_TX := 0
const IN_TY := 2
const KEEP_TX := 8
const KEEP_TY := 4
## A 조각 out in the open, far from the neck — where the 창고 goes and where a free wall is raised.
const OPEN_TX := 5
const OPEN_TY := 5


func run(t) -> void:
	_a_wall_costs_wood_and_stands(t)
	_a_wall_is_refused_where_something_already_stands(t)
	_nothing_walks_through_a_wall(t)
	_a_wall_blocks_my_own_side_too(t)
	_a_beast_that_can_still_reach_the_keep_goes_round(t)
	_a_sealed_beast_breaks_the_wall_and_the_way_opens(t)
	# **The sentinel.** See `run_nets.done` — without it a `run()` that dies half way still reports
	# every check it managed first, in a shape a healthy net cannot be told from.
	t.done()


# == raising one =======================================================================================

## **A wall is paid for out of the 창고, and without the wood there is no wall.**
func _a_wall_costs_wood_and_stands(t) -> void:
	var b := _battle()
	var neck := b.grid.tile_index(NECK_TX, NECK_TY)
	t.eq(b.store.count("wood"), 0, "자가 점검 — 창고에 나무가 없다")
	t.ok(not b.place_barricade(neck), "나무가 없으면 바리케이트가 안 선다")
	t.ok(not b.grid.is_built(neck), "그리고 그 조각은 그대로다")

	b.store.add("wood", Rules.BARRICADE_WOOD)
	t.ok(b.place_barricade(neck), "나무가 있으면 선다")
	t.eq(b.store.count("wood"), 0, "나무 %d 이 창고에서 빠진다" % [Rules.BARRICADE_WOOD])
	t.ok(b.grid.is_built(neck), "그 조각에 벽이 섰다")
	t.eq(b.barricade_tiles.size(), 1, "바리케이트가 하나 선다")
	t.eq(b.barricade_hp[0], Rules.BARRICADE_HP, "체력을 갖고 선다")
	t.eq(b.barricade_at(neck), 0, "그 조각을 물으면 그 바리케이트가 나온다")
	t.ok(not b.place_barricade(neck), "같은 조각에 둘은 안 선다")


## **A wall is refused where a body stands, and on top of another building.**
##
## ⚠⚠ **THE OCCUPIED CASE IS NOT TIDINESS.** `Grid.can_hold` lets a body keep the 조각 it already
## holds, so a wall raised under somebody leaves that body standing inside a wall — able to stay and
## unable to come back once it steps off.
func _a_wall_is_refused_where_something_already_stands(t) -> void:
	var b := _battle()
	var g := b.grid
	b.store.add("wood", Rules.BARRICADE_WOOD * 4)
	var under := g.tile_index(OPEN_TX, OPEN_TY)
	b.place_ashore(0, under)
	t.eq(b._tile_of(b.soldier_pos[0]), under, "자가 점검 — 몸이 그 조각에 섰다")
	t.ok(not b.place_barricade(under), "몸이 선 조각에는 안 선다")

	var store_tile := g.tile_index(OPEN_TX + 2, OPEN_TY)
	t.ok(b.place_store(store_tile), "자가 점검 — 창고가 섰다")
	t.ok(not b.place_barricade(store_tile), "창고 위에도 안 선다")
	t.ok(not b.place_barricade(g.tile_index(KEEP_TX, KEEP_TY)), "성채 위에도 안 선다")
	t.eq(b.store.count("wood"), Rules.BARRICADE_WOOD * 4, "거부된 만큼 나무도 안 나갔다")


# == what a wall does to the walk ======================================================================

## **The step, the field and the route all refuse it — and none of them was told what a wall is.**
##
## ⚠⚠ **THE BEFORE IS HALF THE MEASUREMENT.** 「The pocket is unreachable」 is green for a board where it
## never was, so the row asserts the neck is walkable and the pocket reachable FIRST, then raises the
## wall and asserts both flipped.
func _nothing_walks_through_a_wall(t) -> void:
	var b := _battle()
	var g := b.grid
	var neck := g.tile_index(NECK_TX, NECK_TY)
	var inside := g.tile_index(IN_TX, IN_TY)
	var keep := g.tile_index(KEEP_TX, KEEP_TY)
	var above := g.tile_index(NECK_TX, NECK_TY - 1)

	t.ok(g.can_step(above, neck), "자가 점검 — 벽 서기 전에는 목으로 내려갈 수 있다")
	var before := b.field_to(keep)
	t.ok(int(before[inside]) != Grid.UNREACHABLE, "자가 점검 — 주머니에서 성채까지 길이 있다")

	b.store.add("wood", Rules.BARRICADE_WOOD)
	t.ok(b.place_barricade(neck), "자가 점검 — 목에 벽이 섰다")

	t.ok(not g.can_step(above, neck), "벽을 밟고 지나갈 수 없다")
	t.ok(not g.can_step(g.tile_index(NECK_TX + 1, NECK_TY), neck), "옆에서도 못 들어간다")
	t.ok(not g.has_room(neck), "벽 위에는 설 자리도 없다")
	var after := b.field_to(keep)
	t.eq(int(after[inside]), Grid.UNREACHABLE, "주머니에서 성채로 가는 길이 없어진다")
	t.ok(int(after[g.tile_index(OPEN_TX, OPEN_TY)]) != Grid.UNREACHABLE,
		"밖은 그대로 다닌다 — 섬 전체가 막힌 게 아니다")


## **It blocks the player's own 부대 too** (2026-09-02, the user: 「네 편도 맞고」).
##
## ⚠ **Measured through `Hand`, which is what the player actually presses.** The reach is one flood per
## picked body through `Grid.can_step`, so a wall the hand could see past would mean the wall is not in
## `can_step` at all.
func _a_wall_blocks_my_own_side_too(t) -> void:
	var b := _battle()
	var g := b.grid
	var inside := g.tile_index(IN_TX, IN_TY)
	var neck := g.tile_index(NECK_TX, NECK_TY)
	var outside := g.tile_index(OPEN_TX, OPEN_TY)
	b.place_ashore(0, inside)
	t.eq(b._tile_of(b.soldier_pos[0]), inside, "자가 점검 — 몸이 주머니 안에 섰다")

	var open_hand := Hand.new()
	t.ok(open_hand.pick_many(b, PackedInt32Array([0])), "자가 점검 — 손이 그 몸을 쥐었다")
	t.ok(open_hand.can_reach(outside), "자가 점검 — 벽 서기 전에는 밖으로 갈 수 있다")

	b.store.add("wood", Rules.BARRICADE_WOOD)
	t.ok(b.place_barricade(neck), "자가 점검 — 목에 벽이 섰다")
	var shut := Hand.new()
	t.ok(shut.pick_many(b, PackedInt32Array([0])), "자가 점검 — 다시 쥐었다")
	t.ok(not shut.can_reach(outside), "이제 내 몸도 밖으로 못 간다")
	t.ok(not shut.can_reach(neck), "벽 자체도 갈 수 있는 자리가 아니다")
	t.eq(shut.reach.size(), 3, "갈 수 있는 곳은 주머니 세 조각뿐이다")


# == what a beast does about it ========================================================================

## **A beast that can still reach the 성채 walks round the wall and never touches it.**
##
## ⚠⚠ **THIS IS THE CONTROL FOR THE ROW BELOW AND IT IS NOT DECORATION.** 「A sealed beast attacks the
## wall」 is green for a build where every beast attacks every wall, which is the opposite of what the
## user said (「다시 길을 찾거나」 — *it finds another path*, first).
func _a_beast_that_can_still_reach_the_keep_goes_round(t) -> void:
	var b := _battle()
	var g := b.grid
	b.store.add("wood", Rules.BARRICADE_WOOD)
	# A wall out in the open, sealing nothing at all.
	t.ok(b.place_barricade(g.tile_index(OPEN_TX, OPEN_TY)), "자가 점검 — 한가운데 벽 하나가 섰다")
	var e := b.land_beast(Rules.WOLF, g.tile_index(OPEN_TX, OPEN_TY - 2))
	t.ok(e >= 0, "자가 점검 — 늑대가 그 근처에 내렸다")
	var keep := g.tile_index(KEEP_TX, KEEP_TY)
	t.ok(int(b.field_to(keep)[b._tile_of(b.enemy_pos[e])]) != Grid.UNREACHABLE,
		"자가 점검 — 늑대는 아직 성채까지 갈 수 있다")

	# ⚠ **Two seconds of sub-steps and no assertion inside the loop.** A check that is always true
	# counts toward the round's total and says nothing — the failure `how-nets-lie` collects. The loop
	# only looks for the wall being targeted; the row's answer is the assertion after it.
	for _k in 120:
		b.step(Rules.SIM_SUBSTEP_SEC)
		if b.wall_of_target(int(b.enemy_target[e])) >= 0:
			break
	t.ok(b.wall_of_target(int(b.enemy_target[e])) < 0, "늑대는 벽을 안 노린다 — 돌아서 간다")
	t.eq(b.barricade_hp[0], Rules.BARRICADE_HP, "벽은 한 대도 안 맞았다")


## **A beast the wall has sealed in turns on it, breaks it, and the way through opens again.**
##
## (2026-09-02, the user: 「갈 길이 없으면 바리게이트 부시는거」 · 「체력과 갖고 있고 깎여서 영 이 되면
## 사라집니다」.)
##
## ⚠ **The 성채 is outside the pocket**, so the beast really has nowhere to go — which is the whole
## condition the rule is written on.
func _a_sealed_beast_breaks_the_wall_and_the_way_opens(t) -> void:
	var b := _battle()
	var g := b.grid
	var neck := g.tile_index(NECK_TX, NECK_TY)
	var inside := g.tile_index(IN_TX, IN_TY)
	var keep := g.tile_index(KEEP_TX, KEEP_TY)
	var e := b.land_beast(Rules.WOLF, inside)
	t.ok(e >= 0, "자가 점검 — 늑대가 주머니 안에 내렸다")
	b.store.add("wood", Rules.BARRICADE_WOOD)
	t.ok(b.place_barricade(neck), "자가 점검 — 목에 벽이 서서 늑대가 갇혔다")
	t.eq(int(b.field_to(keep)[b._tile_of(b.enemy_pos[e])]), Grid.UNREACHABLE,
		"자가 점검 — 늑대는 성채로 갈 길이 없다")

	var noticed := false
	for _k in 600:
		b.step(Rules.SIM_SUBSTEP_SEC)
		if b.wall_of_target(int(b.enemy_target[e])) >= 0:
			noticed = true
			break
	t.ok(noticed, "갇힌 늑대는 벽을 노린다")

	var hurt := false
	var gone := false
	for _k in 3000:
		b.step(Rules.SIM_SUBSTEP_SEC)
		if float(b.barricade_hp[0]) < Rules.BARRICADE_HP:
			hurt = true
		if int(b.barricade_tiles[0]) < 0:
			gone = true
			break
	t.ok(hurt, "벽의 체력이 깎인다")
	t.ok(gone, "체력이 0 이 되면 벽이 사라진다")
	t.ok(not g.is_built(neck), "그 조각은 다시 지나갈 수 있다")
	t.eq(b.barricade_hp[0], 0.0, "쓰러진 벽의 체력은 0 이다")
	t.eq(int(b.enemy_target[e]), Battle.TARGET_NONE, "벽이 없어지면 노리던 것도 없어진다")
	t.ok(int(b.field_to(keep)[inside]) != Grid.UNREACHABLE, "주머니에서 성채로 다시 길이 난다")


# == fixtures =========================================================================================

## **The pocket board with a 성채 outside the pocket and one 검사 on the roster.** ⚠ **No doorstep**
## (`-1`), so nothing musters and every body on the board is one a row put there.
func _battle() -> Battle:
	var g := Grid.new()
	g.load_rows(POCKET)
	var army := Army.new()
	var slot := army.register_species(Rules.SWORDSMAN)
	army.recruit(slot)
	var b := Battle.new()
	b.setup(g, army, [], PackedInt32Array([g.tile_index(KEEP_TX, KEEP_TY)]), -1)
	return b
