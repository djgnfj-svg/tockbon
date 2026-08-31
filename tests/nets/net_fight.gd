extends RefCounted
## **The beasts get off the boat and the fight happens.** 티켓 41, the 목~일 slice.
##
## The claim under test is one sentence: **an arrived boat puts eight 늑대 on the landing ring as real
## bodies, they walk at the 성채, blows take the numbers `Rules.UNITS` carries, death latches in a later
## phase than the blow, a dead 검사 stands again at the 성채, and the 성채 reaching zero loses the run.**
##
## ⚠⚠ **NOTHING HERE TOUCHES THE TREE.** `Grid.new()`, `Army.new()`, `Battle.new()` and `step(dt)` are
## the whole of it — the `src/sim/` seam `CONTEXT.md` names.
##
## ⚠⚠ **THE DECIDED VALUES ARE PINNED AS LITERALS IN ONE FUNCTION AND DERIVED FROM `Rules` EVERYWHERE
## ELSE**, the same split `net_boats` carries and for the same reason: a row that drives the fight from
## `Rules.damage_of` **and** expects `Rules.damage_of` stays green at any damage. **Exactly one place
## holds the value that was decided**, and retuning a blow reddens it.
##
## ⚠ **The blow lands on the FIRST sub-step a target is in reach, not one period later.** That is a
## rule this file measures rather than inherits — 티켓 41's 「6 타 7.2 초」 column is the arithmetic for a
## body that waits a period first, and it is marked in the ticket as arithmetic rather than play.
## **Six blows at a 1.2 s period starting at zero is 6.0 s**, and the row that measures it says so.


## The board every hand-driven row runs on. 12 x 9, an 8 x 5 island in the middle, flat.
## ⚠ **Flat on purpose**: every height rule this file touches is `REACH_BONUS`'s window, and that is
## measured on a purpose-built stair board below rather than smuggled into the general fixture.
const ISLE := [
	"~~~~~~~~~~~~",
	"~~~~~~~~~~~~",
	"~~........~~",
	"~~........~~",
	"~~........~~",
	"~~........~~",
	"~~........~~",
	"~~~~~~~~~~~~",
	"~~~~~~~~~~~~",
]
const ISLE_W := 12
## The 성채's four 조각 on `ISLE` — a 2x2 in the middle, the same footprint the real island's keep has.
const ISLE_KEEP := [
	5 + 4 * ISLE_W,
	6 + 4 * ISLE_W,
	5 + 5 * ISLE_W,
	6 + 5 * ISLE_W,
]
## The doorstep on `ISLE` — free land just outside the 성채's footprint, where a 검사 appears.
const ISLE_MUSTER := 7 + 4 * ISLE_W

## **The same board with no water at all**, so no beach ring exists and **no boat is ever born.**
##
## ⚠⚠ **THE BURN ROWS BELOW CANNOT BE MEASURED ON A BOARD WITH A COAST, AND THAT WAS MEASURED THE HARD
## WAY.** Burning 240 HP with one 늑대 takes 119 seconds, and `BOAT_INTERVAL_SEC` is thirty — **three
## more boats land during the row**, so 「it had not fallen yet」 was already false at half the time and
## the floor under the burn read as a defect in the burn. **A landlocked board is the only place one
## 늑대 is one 늑대.**
## ⚠ Same 조각 numbers as `ISLE`, so `ISLE_KEEP` and `ISLE_MUSTER` name the same places.
const LAND := [
	"............",
	"............",
	"............",
	"............",
	"............",
	"............",
	"............",
	"............",
	"............",
]

## Tolerance on an accumulated distance in 조각. Positions are summed one sub-step at a time.
const NEAR := 1e-3
## Tolerance on an accumulated HP. Damage is subtracted whole, so this is float noise and nothing else.
const HP_NEAR := 1e-3


func run(t) -> void:
	_the_numbers_are_the_ones_that_were_chosen(t)
	_the_reach_is_the_range_plus_the_bonus_and_the_window_holds(t)
	_the_keep_is_read_off_the_island_file(t)
	_an_arrived_boat_puts_its_riders_on_the_board(t)
	_beasts_pack_a_piece_and_never_overfill_it(t)
	_the_beasts_walk_at_the_keep_and_stop_in_reach(t)
	_a_blow_takes_the_table_s_damage_on_the_table_s_period(t)
	_the_blow_and_the_death_are_different_phases(t)
	_a_dead_beast_lets_go_of_its_piece(t)
	_a_dead_swordsman_stands_again_at_the_keep(t)
	_the_keep_burns_and_the_run_is_lost(t)
	_a_lost_run_stops_the_clock(t)
	_the_fight_is_the_same_at_any_frame_rate(t)
	_nearest_ties_break_on_the_lower_id(t)
	# **The sentinel.** See `run_nets.done` — without it a `run()` that dies
	# half way still reports every check it managed first, in a shape a healthy net cannot be told from.
	t.done()


# == the numbers ======================================================================================

## **The one place a decided value is written as a literal.** Everything below reads `Rules`, so this is
## what goes red when somebody retunes the fight — and a fight that measures the same at any damage
## measures nothing.
func _the_numbers_are_the_ones_that_were_chosen(t) -> void:
	t.eq(Rules.REACH_BONUS, 1.75, "사거리 보너스는 1.75 다 — 162 판에서 잰 값이고 다시 안 잰다")
	t.eq(Rules.REVIVE_SEC, 20.0, "죽은 검사는 20초 뒤에 다시 선다 (⚠ 사용자가 안 고른 임시값)")
	t.eq(Rules.SWORDSMAN_START_COUNT, 4, "검사 넷으로 시작한다 (⚠ 사용자가 안 고른 임시값)")
	t.eq(Rules.KEEP_MAX_HP, 240.0, "성채 체력은 240 이다")
	t.eq(Rules.BOAT_RIDER_TYPE, Rules.WOLF, "배에 타고 오는 것은 늑대다")

	# ⚠⚠ **HOW MANY BODIES STAND ON ONE 조각, AND IT IS PINNED HERE FOR THE REASON THIS FUNCTION EXISTS.**
	# Every capacity row below is written off `Rules.TILE_CAPACITY`, so **all of them stay green at any
	# capacity** — this is the row that reddens when the number moves, and it is the only one.
	# ⚠ **The user's own figure is nine to a 칸**, which is four 조각; three per 조각 admits twelve, and
	# the overshoot is stated rather than hidden. See that constant.
	t.eq(Rules.TILE_CAPACITY, 3, "한 조각에 셋이 선다")
	t.eq(Rules.BLOCK_CAPACITY, 9, "한 블록(칸)에 아홉이 최대다 — 사용자가 말한 수다")
	t.eq(Rules.BLOCK_TILES, 2, "블록은 조각 둘 x 둘이다")
	t.ok(Rules.BLOCK_CAPACITY < Rules.TILE_CAPACITY * Rules.BLOCK_TILES * Rules.BLOCK_TILES,
		"블록 천장이 조각 천장 넷보다 낮다 — 안 그러면 아무것도 안 막는다")

	# The two rows the whole fight is arithmetic on. ⚠ **Both species, both columns each** — pinning
	# only the wolf lets the swordsman be retuned with every row below still green.
	#
	# ⚠⚠ **ALL FOUR OF THESE MOVED ON 2026-08-31 AND THESE FOUR REDDENED, WHICH IS THEM WORKING.**
	# The swing became eight frames (0.96 s) so the periods doubled to leave a gap — 「애니메이션을 좀더
	# 늘려줘 좀더 공격 텀이 있는 느낌?」. **The damage doubled with them on purpose.**
	# ⚠⚠ **WHAT THE PAIR IS FOR IS PINNED BELOW THEM, AND IT IS THE ROW THAT MATTERS**: damage per
	# second did NOT move. A future edit that changes one of the four without the other passes the
	# four `eq`s it edits and fails the two ratios — **which is the only reason a table of literals
	# is worth having.**
	t.eq(Rules.hp_of(Rules.WOLF), 14.0, "늑대 체력 14")
	t.eq(Rules.damage_of(Rules.WOLF), 4.0, "늑대 한 대 4.0")
	t.eq(Rules.period_of(Rules.WOLF), 2.0, "늑대는 2.0초마다 때린다")
	t.eq(Rules.hp_of(Rules.SWORDSMAN), 18.0, "검사 체력 18")
	t.eq(Rules.damage_of(Rules.SWORDSMAN), 5.0, "검사 한 대 5.0")
	t.eq(Rules.period_of(Rules.SWORDSMAN), 2.4, "검사는 2.4초마다 때린다")
	t.ok(absf(Rules.damage_of(Rules.WOLF) / Rules.period_of(Rules.WOLF) - 2.0) <= 0.001,
		"늑대의 초당 피해가 2.0 그대로다 — 텀을 늘린 편집이 승패를 안 바꿨다")
	t.ok(absf(Rules.damage_of(Rules.SWORDSMAN) / Rules.period_of(Rules.SWORDSMAN) - 2.0833) <= 0.001,
		"검사의 초당 피해가 2.083 그대로다 — 같은 이유로")
	# ⚠ **The swing must fit inside the period with room left over.** A body whose animation is longer
	# than its own attack period never stops swinging, and that is the state this edit was made to
	# leave: 8 frames at `Look.BEAST_FRAME_SEC` is 0.96 s against 2.0 s and 2.4 s.
	var swing := float(Look.MAN_ANIM_FRAMES[Look.Anim.ATTACK]) * Look.BEAST_FRAME_SEC
	t.ok(swing < Rules.period_of(Rules.SWORDSMAN) * 0.6,
		"검사의 휘두름이 제 주기의 절반 남짓이다 — 텀이 남는다 (%.2f초)" % swing)
	var bite := float(Look.WOLF_ANIM_FRAMES[Look.Anim.ATTACK]) * Look.BEAST_FRAME_SEC
	t.ok(bite < Rules.period_of(Rules.WOLF) * 0.6,
		"늑대도 그렇다 (%.2f초)" % bite)
	t.eq(Rules.range_of(Rules.SWORDSMAN), 0.0, "검이라 사거리 칸은 0 이다 — 검사의 사거리는 보너스가 전부다")

	# ⚠ **The 성채 has to outlast one boat and fall to two**, which is what `KEEP_MAX_HP`'s own comment
	# says it was chosen off. Derived here so a retune of either side moves this row rather than the
	# arithmetic quietly stopping being true.
	var one_boat_dps := float(Rules.BOAT_CAPACITY) * Rules.damage_of(Rules.WOLF) 			/ Rules.period_of(Rules.WOLF)
	var burn_sec := Rules.KEEP_MAX_HP / one_boat_dps
	t.ok(burn_sec > 0.0, "배 한 척이 아무도 안 막으면 성채를 %.1f초에 태운다 (자가 점검)" % burn_sec)
	t.ok(burn_sec < Rules.BOAT_INTERVAL_SEC,
		"그 %.1f초는 배 간격 %.1f초보다 짧다 — 한 척을 통째로 흘리면 진다"
			% [burn_sec, Rules.BOAT_INTERVAL_SEC])
	t.ok(burn_sec > Rules.BOAT_INTERVAL_SEC * 0.25,
		"그런데 간격의 4분의 1보다는 길다 — 한 척이 닿자마자 끝나지는 않는다")


## **`reach = range + REACH_BONUS`, in one place, and the window that number was measured into.**
##
## ⚠⚠ **THE WINDOW IS THE WHOLE OF WHY IT IS 1.75 AND NOT SOMETHING NEARBY.** 「Above the stair
## diagonal, below the flat two-조각 orthogonal」 — a notch is half a 조각, so the stair diagonal is
## `sqrt(2 + 0.25)` = 1.5 and the flat two-조각 orthogonal is 2.0. **Both bounds are computed here from
## `TIER_STEP_TILES` rather than typed**, so the day a notch changes height this row goes red instead of
## quietly passing on a stale margin.
func _the_reach_is_the_range_plus_the_bonus_and_the_window_holds(t) -> void:
	for ty in Rules.UNITS.size():
		t.eq(Rules.reach_of(ty), Rules.range_of(ty) + Rules.REACH_BONUS,
			"%s 의 사거리는 제 칸 + 보너스다" % Rules.label_of(ty))

	var notch := Rules.TIER_STEP_TILES
	var stair_diagonal := sqrt(2.0 + notch * notch)
	var flat_two := 2.0
	t.ok(absf(stair_diagonal - 1.5) <= NEAR,
		"계단 대각선이 %.4f 다 (자가 점검 — 눈금 %.2f 에서)" % [stair_diagonal, notch])
	t.ok(Rules.REACH_BONUS > stair_diagonal,
		"보너스 %.2f 가 계단 대각선 %.2f 보다 크다 — 계단 위 몸이 옆 고원에 대각선으로 닿는다"
			% [Rules.REACH_BONUS, stair_diagonal])
	t.ok(Rules.REACH_BONUS < flat_two,
		"그리고 평지 두 조각 %.2f 보다 작다 — 검사가 한 조각 건너를 못 때린다"
			% flat_two)

	# The claim driven rather than argued: two bodies a 조각 apart across a storey boundary really are
	# `sqrt(1 + 1)` apart and not 1. **The height comes from the 눈금 and never from the drawn mesh.**
	var g := _stair_board()
	var b := _battle_on(g, PackedInt32Array(), -1)
	var low := Vector2(1.0, 1.0)
	var high := Vector2(3.0, 1.0)
	var flat := Vector2(1.0, 3.0)
	t.eq(g.level_of(g.tile_index(1, 1)), 0, "낮은 조각이 눈금 0 이다 (자가 점검)")
	t.eq(g.level_of(g.tile_index(3, 1)), 2, "높은 조각이 눈금 2 이다 (자가 점검)")
	var across := b._dist(low, high)
	var along := b._dist(low, flat)
	t.ok(absf(along - 2.0) <= NEAR, "평지로 두 조각 떨어진 것은 2.00 이다 (자가 점검 — 얻은 값 %.4f)" % along)
	t.ok(across > along,
		"층을 건너 두 조각 떨어진 것은 %.4f 로 더 멀다 — 거리는 3D 고 높이는 눈금에서 온다" % across)
	t.ok(absf(across - sqrt(4.0 + (2.0 * notch) * (2.0 * notch))) <= NEAR,
		"그 값이 sqrt(4 + 높이차²) 다 (얻은 값 %.4f)" % across)


## **The 성채 is read out of the island file and it covers a footprint, not a corner.**
func _the_keep_is_read_off_the_island_file(t) -> void:
	var tiles := Islands.keep_tiles()
	var span := Builds.footprint_of(Builds.KEEP)
	t.ok(span.x > 0 and span.y > 0, "성채가 %d x %d 조각을 덮는다 (자가 점검)" % [span.x, span.y])
	t.eq(tiles.size(), span.x * span.y, "그리고 그 발자국만큼의 조각을 돌려준다 — 모서리 하나가 아니다")
	t.ok(tiles.has(Islands.home_tile()), "그 조각들에 낮은 모서리가 들어 있다")

	# Every one of them is real land the board can name. ⚠ **On the shipped island**, because 「성채가
	# 판 밖에 있지 않다」 is a claim about the board the game opens.
	var g := _real()
	var off := []
	for k in tiles.size():
		var tile := int(tiles[k])
		if tile < 0 or tile >= g.passable.size() or g.passable[tile] == 0:
			off.append(tile)
	t.eq(off.size(), 0, "성채의 조각이 전부 판 위의 걸을 수 있는 땅이다 %s" % str(off))

	# The battle actually gets them. **A run that opened with an empty keep would lose nothing, ever**,
	# and every loss row below would be measuring a board with no keep on it.
	var run := Run.new()
	var live := run.begin_island()
	t.ok(live != null, "회차가 섬을 연다 (자가 점검)")
	t.eq(live.keep_tiles.size(), tiles.size(), "그리고 전투가 성채의 조각을 실제로 들고 있다")
	t.eq(live.keep_hp, Rules.KEEP_MAX_HP, "성채가 꽉 찬 체력으로 선다")
	t.ok(not live.lost, "그리고 첫 프레임에 진 상태가 아니다")

	# ⚠⚠ **AND EVERY 검사 IS STANDING.** The roster used to open with ten and stand ONE, so nine bodies
	# existed and could never be seen. **The count and the picture are one number now.**
	t.eq(run.army.type_id.size(), Rules.SWORDSMAN_START_COUNT, "명부에 검사가 시작 수만큼 있다")
	t.eq(live.ashore_ids().size(), Rules.SWORDSMAN_START_COUNT,
		"그리고 그 전부가 판 위에 서 있다 — 명부에만 있고 안 보이는 몸이 없다")

	# ⚠⚠ **THE HOUSE HOLDS ITS OWN 조각, AND NOTHING MEASURED IT UNTIL THIS PAIR.** Measured by
	# mutation 2026-08-30: **deleting the reservation outright reddened NOTHING in this file.** What it
	# buys is that a body put at the 성채 stands beside the house and not inside it — which read as
	# 「아무도 안 세워졌다」 on the one screen the player looks at, once already (2026-08-27).
	# ⚠⚠ **THE HOUSE TAKES EVERY SLOT OF ITS 조각 AND NOT ONE.** A 조각 admits `Rules.TILE_CAPACITY`
	# bodies since 2026-08-30, so a keep holding a single slot leaves the rest open and **every body on
	# the island walks in through them** — which is the same 「아무도 안 세워졌다」 screen this pair was
	# written for, wearing a different cause.
	var unheld := []
	var half_held := []
	for k in live.keep_tiles.size():
		var kt := int(live.keep_tiles[k])
		if not live.grid.holds(kt, Battle.KEEP_UID):
			unheld.append(kt)
		if live.grid.has_room(kt):
			half_held.append(kt)
	t.eq(unheld.size(), 0, "성채가 제 조각을 전부 제 이름으로 잡고 있다 %s" % str(unheld))
	t.eq(half_held.size(), 0, "그리고 그 조각에 빈 자리가 하나도 없다 — 집이 반만 막혀 있지 않다 %s" % str(half_held))

	# **And the consequence, driven.** The row above is a fact about a table; this is the fact that
	# makes it worth having, and it is asked of BOTH sides — the rule must not know who is standing.
	var fix := _battle_on(_grid(LAND), _keep(), ISLE_MUSTER)
	var took := fix.place_ashore(0, int(fix.keep_tiles[0]))
	t.ok(took >= 0, "집 조각을 겨눠도 검사가 설 자리를 찾는다 (자가 점검 — %d)" % took)
	t.ok(not fix.keep_tiles.has(took), "그런데 그 자리가 집 안은 아니다 — 집 속에 선 몸은 안 보인다")
	var beast_at := fix.land_beast(Rules.WOLF, int(fix.keep_tiles[3]))
	t.ok(beast_at >= 0, "짐승도 집 조각을 겨눠서 세워 본다 (자가 점검)")
	t.ok(not fix.keep_tiles.has(fix._tile_of(fix.enemy_pos[beast_at])),
		"내리는 늑대도 집 안에 안 선다 — 규칙이 편을 안 가린다")


# == getting off the boat =============================================================================

## **An arrived boat unloads, and what it unloads is bodies.**
##
## ⚠⚠ **BOTH HALVES, BECAUSE EITHER ALONE IS GREEN ON A LIE.** 「The rider count went to zero」 is true
## of a boat that simply forgot its riders; 「eight bodies exist」 is true of a spawn loop that never
## read the boat. **The two are asserted against each other.**
func _an_arrived_boat_puts_its_riders_on_the_board(t) -> void:
	var b := _battle(ISLE)
	b.step(Rules.BOAT_FIRST_SEC)
	t.eq(b.boat_pos.size(), 1, "배가 한 척 떴다 (자가 점검)")
	t.eq(int(b.boat_riders[0]), Rules.BOAT_CAPACITY, "여덟이 타 있다 (자가 점검)")
	t.eq(b.living_enemy_ids().size(), 0, "그리고 아직 판에 짐승이 하나도 없다")

	# ⚠ **Stepped one sub-step at a time up to the landing and not a second past it.** Every 늑대 starts
	# walking at the 성채 the moment it is standing, so a fat step would measure them somewhere along the
	# way — 「내린 자리」 has to be read on the sub-step they were put there.
	_step_until_landed(b)
	t.eq(int(b.boat_state[0]), Battle.BoatState.ARRIVED, "배가 다 왔다 (자가 점검)")
	t.eq(int(b.boat_riders[0]), 0, "그리고 갑판이 비었다")

	var live := b.living_enemy_ids()
	t.eq(live.size(), Rules.BOAT_CAPACITY, "탄 수만큼이 판 위의 몸이 됐다")
	var wrong_type := 0
	var wrong_hp := 0
	for raw in live:
		var i := int(raw)
		if int(b.enemy_type[i]) != Rules.BOAT_RIDER_TYPE:
			wrong_type += 1
		if absf(float(b.enemy_hp[i]) - Rules.hp_of(Rules.BOAT_RIDER_TYPE)) > HP_NEAR:
			wrong_hp += 1
	t.eq(wrong_type, 0, "여덟이 전부 늑대다")
	t.eq(wrong_hp, 0, "그리고 전부 표가 준 체력으로 선다")

	# They came off at the beach the boat was aimed at, not somewhere else on the island.
	var beach := int(b.boat_beach[0])
	var beach_pt := Vector2(beach % b.grid.w, beach / b.grid.w)
	var far := 0
	for raw in live:
		if (b.enemy_pos[int(raw)] as Vector2).distance_to(beach_pt) > 4.0:
			far += 1
	t.eq(far, 0, "그리고 겨눈 해변 언저리에 내렸다 — 섬 아무 데나가 아니다")


## **Bodies pack a 조각 to `Rules.TILE_CAPACITY` and no further, and every one of them claims a slot.**
##
## ⚠⚠ **THIS FUNCTION SAID 「ONE BODY A 조각」 UNTIL 2026-08-30** (the user at the screen: bodies should
## be bigger and **about nine should fit in one 칸**). A 칸 is four 조각, so nine is more than two per
## 조각 and the old rule could not survive. **What did survive is the half that bites**: a 조각 has a
## ceiling, and every body standing on one holds a slot of its own.
##
## ⚠⚠ **THE RESERVATION IS STILL THE HALF THAT ACTUALLY BITES.** Distinct positions is true for one
## sub-step of a landing that wrote no reservation at all — and then the first time anything walks,
## bodies stand through each other with every position check still green. **`ENEMY_UID_BASE` is what
## keeps the claims apart from the 검사's**, and that is asserted rather than assumed: without it 늑대 0
## and 검사 0 release each other's 조각.
##
## ⚠ **Every row here is written off `Rules.TILE_CAPACITY` and so passes at any capacity.** The value
## itself is pinned in `_the_numbers_are_the_ones_that_were_chosen`, which is the row that reddens.
func _beasts_pack_a_piece_and_never_overfill_it(t) -> void:
	var b := _battle(ISLE)
	_step_until_landed(b)
	var live := b.living_enemy_ids()
	t.ok(live.size() > 1, "판에 짐승이 여럿이다 (자가 점검 — %d)" % live.size())

	var per_tile := {}
	var overfull := []
	var unclaimed := []
	var slots := {}
	var shared_slot := []
	for raw in live:
		var i := int(raw)
		var tile := b._tile_of(b.enemy_pos[i])
		per_tile[tile] = int(per_tile.get(tile, 0)) + 1
		if int(per_tile[tile]) > Rules.TILE_CAPACITY:
			overfull.append(tile)
		var slot := b.grid.slot_of(tile, Battle.ENEMY_UID_BASE + i)
		if slot < 0:
			unclaimed.append(tile)
		else:
			var seat := tile * Rules.TILE_CAPACITY + slot
			if slots.has(seat):
				shared_slot.append(seat)
			slots[seat] = i
	t.eq(overfull.size(), 0, "한 조각에 %d 을 넘겨 서지 않는다 %s" % [Rules.TILE_CAPACITY, str(overfull)])
	t.eq(unclaimed.size(), 0, "그리고 선 조각을 저마다 제 이름으로 잡고 있다 %s" % str(unclaimed))
	# ⚠ **The slot is what keeps two bodies out of one PLACE now that the 조각 no longer does.** Without
	# it 「both claimed the 조각」 is green for two bodies written into the same seat.
	t.eq(shared_slot.size(), 0, "두 짐승이 같은 자리를 안 쓴다 %s" % str(shared_slot))

	# **Driven, and this is the ceiling itself rather than a table read.** A 조각 filled to capacity
	# refuses the next body; one slot short of it does not. ⚠ **The control is the whole row** — a `hold`
	# that refused everybody would pass the refusal on its own.
	var g := _grid(LAND)
	var spot := g.tile_index(2, 2)
	for k in Rules.TILE_CAPACITY:
		t.ok(g.hold(9000 + k, spot), "%d 번째 몸이 그 조각에 선다" % (k + 1))
	t.eq(g.hold_count(spot), Rules.TILE_CAPACITY, "조각이 꽉 찼다 (자가 점검)")
	t.ok(not g.hold(9999, spot), "그 다음 몸은 거절당한다 — 조각에 천장이 있다")
	g.release_all(9000)
	t.ok(g.hold(9999, spot), "한 자리가 비면 바로 들어간다 (대조군 — 아무나 거절하는 게 아니다)")

	# ⚠⚠ **THE 블록 CEILING, DRIVEN** (2026-08-31, the user: 「nine soldiers is the maximum」).
	# **The tenth body is refused although the 조각 it asks for still has a free slot** — which is the
	# whole of why the ceiling had to be stated one unit up. A per-조각 check alone stays green all the
	# way to twelve, and twelve was what stood there yesterday.
	var gb := _grid(LAND)
	var b_tiles := [gb.tile_index(2, 2), gb.tile_index(3, 2), gb.tile_index(2, 3), gb.tile_index(3, 3)]
	var blk := gb.block_of(int(b_tiles[0]))
	t.ok(blk >= 0, "그 조각이 블록 안에 있다 (자가 점검)")
	for k in range(1, 4):
		t.eq(gb.block_of(int(b_tiles[k])), blk, "조각 넷이 한 블록이다 (자가 점검 %d)" % k)
	# ⚠ **Round-robin and not one 조각 at a time.** Filling one 조각 first would hit the 조각 ceiling
	# at three and never reach the 블록 ceiling at all — the row would pass measuring the wrong thing.
	var seated := 0
	for k in 12:
		if gb.hold(8000 + k, int(b_tiles[k % 4])):
			seated += 1
	t.eq(seated, Rules.BLOCK_CAPACITY, "한 블록에 아홉만 선다 — 열째부터 거절당한다")
	t.eq(gb.block_hold_count(blk), Rules.BLOCK_CAPACITY, "블록이 아홉으로 꽉 찼다 (자가 점검)")
	var last := int(b_tiles[3])
	t.ok(gb.hold_count(last) < Rules.TILE_CAPACITY,
		"그런데 마지막 조각에는 자리가 남아 있다 — 조각만 봐서는 거절할 근거가 없었다")
	t.ok(not gb.has_room(last), "그래도 has_room 이 거절한다 — 블록 천장을 같이 본다")
	t.ok(not gb.can_hold(last, 8500), "새 몸의 입장 검사도 거절한다")
	# **The control, and it is the row that stops this passing for a grid that refuses everybody.**
	# ⚠ **A body ALREADY in the 블록 is still admitted** — mid-step it holds two 조각 at once, and a
	# ceiling that forgot that would freeze a walker on the 조각 it was leaving.
	t.ok(gb.can_hold(last, 8000), "이미 그 블록에 선 몸은 옆 조각으로 계속 넘어간다")
	gb.release_all(8000)
	t.ok(gb.hold(8500, last), "한 몸이 빠지면 바로 새 몸이 들어간다")

	# ⚠ **The instrument's own inversion**: the ids really are disjoint from the soldiers'. A base of 0
	# would make the row above pass for a 늑대 standing exactly where 검사 0 stands.
	t.ok(Battle.ENEMY_UID_BASE > Rules.SWORDSMAN_START_COUNT * 1000,
		"짐승의 예약 이름이 검사 이름과 안 겹칠 만큼 멀다 (%d)" % Battle.ENEMY_UID_BASE)
	var b2 := _battle_on(_grid(ISLE), PackedInt32Array(), -1)
	var aim := b2.grid.tile_index(3, 3)
	b2.place_ashore(0, aim)
	var beast := b2.land_beast(Rules.WOLF, aim)
	t.ok(beast >= 0, "짐승 하나를 검사가 선 자리에 세워 본다 (자가 점검)")
	# ⚠⚠ **IT STANDS BESIDE HIM IN THE SAME 조각 NOW, AND THAT IS THE 2026-08-30 CHANGE.** It used to be
	# pushed onto the next 조각, because a 조각 took one body. **What has to stay true is the slot**: the
	# beast may share his ground and may never take his place.
	t.eq(b2._tile_of(b2.enemy_pos[beast]), aim, "짐승이 검사와 같은 조각에 선다 — 조각 하나에 여럿이다")
	var his := b2.grid.slot_of(aim, 0)
	var its := b2.grid.slot_of(aim, Battle.ENEMY_UID_BASE + beast)
	t.ok(his >= 0 and its >= 0, "둘 다 제 자리를 쥐고 있다 (자가 점검 — %d · %d)" % [his, its])
	t.ok(his != its, "그런데 같은 자리는 아니다 — 짐승이 검사를 밀어내지 않는다")

	# **And full is still full, whoever filled it.** ⚠ **The 조각 is topped up with a body that is
	# neither side**, so what pushes the next beast off is the CEILING and not a rule about factions.
	while b2.grid.has_room(aim):
		b2.grid.hold(77000 + b2.grid.hold_count(aim), aim)
	var pushed := b2.land_beast(Rules.WOLF, aim)
	t.ok(pushed >= 0, "꽉 찬 조각을 겨눠서 한 마리 더 세워 본다 (자가 점검)")
	t.ok(b2._tile_of(b2.enemy_pos[pushed]) != aim,
		"그런데 자리가 없어서 옆 조각으로 갔다 — 예약이 편을 안 가린다")


# == walking at the keep ==============================================================================

## **A beast walks at the 성채 and stops when it is in reach of it.**
##
## ⚠⚠ **BOTH ENDS, IN THE SAME ROW.** 「It got nearer」 is green for a body that walks straight through
## the house and out the other side; 「it stopped」 is green for a body that never moved. **The floor is
## that it closed most of the gap; the ceiling is that it did not end up inside the footprint.**
func _the_beasts_walk_at_the_keep_and_stop_in_reach(t) -> void:
	var g := _grid(ISLE)
	var b := _battle_on(g, _keep(), ISLE_MUSTER)
	var start_tile := g.tile_index(2, 2)
	var who := b.land_beast(Rules.WOLF, start_tile)
	t.ok(who >= 0, "짐승 하나를 섬 구석에 세웠다 (자가 점검)")

	var began: Vector2 = b.enemy_pos[who]
	var gap0 := _keep_gap(b, began)
	t.ok(gap0 > 3.0, "성채까지 %.2f 조각 떨어진 데서 출발한다 (자가 점검)" % gap0)

	b.step(8.0)
	var ended: Vector2 = b.enemy_pos[who]
	var gap1 := _keep_gap(b, ended)
	t.ok(gap1 < gap0 - 1.0, "8초 걸으면 성채에 가까워진다 (%.2f -> %.2f)" % [gap0, gap1])

	var reach := Rules.reach_of(Rules.WOLF)
	t.ok(gap1 <= reach + Rules.speed_of(Rules.WOLF) * Rules.SIM_SUBSTEP_SEC + NEAR,
		"그리고 사거리 %.2f 안까지 와서 선다 (%.2f)" % [reach, gap1])
	t.ok(not b.keep_tiles.has(b._tile_of(ended)),
		"그리고 성채 조각 위에 안 선다 — 집 속에서 때리지 않는다 (%.2f 조각 앞)" % gap1)
	t.eq(int(b.enemy_target[who]), Battle.TARGET_KEEP, "그 짐승이 겨누고 있는 것이 성채다")

	# It stopped and STAYED stopped. A body that oscillates in and out of reach would pass the row
	# above on the frame it was measured.
	var held: Vector2 = b.enemy_pos[who]
	b.step(3.0)
	t.ok((b.enemy_pos[who] as Vector2).distance_to(held) <= NEAR,
		"3초를 더 밀어도 그 자리다 (%.5f)" % (b.enemy_pos[who] as Vector2).distance_to(held))

	# ⚠⚠ **AND A BOARD WITH NO 성채 DOES NOT SEND IT WALKING SOMEWHERE.** The keep is the only
	# destination a beast has, so an island without one has to be a case rather than a body drifting to
	# (0,0) at walking speed — which is exactly what an unset goal does here.
	var idle := _battle_on(_grid(ISLE), PackedInt32Array(), -1)
	var lone := idle.land_beast(Rules.WOLF, idle.grid.tile_index(2, 2))
	var stood: Vector2 = idle.enemy_pos[lone]
	idle.step(5.0)
	t.ok((idle.enemy_pos[lone] as Vector2).distance_to(stood) <= NEAR,
		"성채가 없는 판에서는 짐승이 서 있다 (%.5f)"
			% (idle.enemy_pos[lone] as Vector2).distance_to(stood))


# == the blow =========================================================================================

## **What one blow takes, and how often.**
##
## ⚠ **Driven on the sim and read off `soldier_hp`**, both directions, because a fight where only one
## side can hit is a fight that ends the same way whatever the other side's row says.
func _a_blow_takes_the_table_s_damage_on_the_table_s_period(t) -> void:
	var b := _pair()
	t.eq(b.ashore_ids().size(), 1, "검사 하나가 서 있다 (자가 점검)")
	t.eq(b.living_enemy_ids().size(), 1, "늑대 하나가 그 옆에 서 있다 (자가 점검)")
	var full_s := b.army.max_hp_of(0)
	var full_e := Rules.hp_of(Rules.WOLF)
	t.eq(b.soldier_hp[0], full_s, "검사가 꽉 찬 체력이다 (자가 점검)")
	t.eq(b.enemy_hp[0], full_e, "늑대도 그렇다 (자가 점검)")

	# One sub-step: **each lands exactly one blow, and the first one is not a period away.**
	b.step(Rules.SIM_SUBSTEP_SEC)
	t.ok(absf(float(b.soldier_hp[0]) - (full_s - Rules.damage_of(Rules.WOLF))) <= HP_NEAR,
		"첫 서브스텝에 검사가 늑대 한 대만큼 깎인다 (%.3f)" % float(b.soldier_hp[0]))
	t.ok(absf(float(b.enemy_hp[0]) - (full_e - Rules.damage_of(Rules.SWORDSMAN))) <= HP_NEAR,
		"그리고 늑대도 검사 한 대만큼 깎인다 (%.3f)" % float(b.enemy_hp[0]))

	# Just under one wolf period later: still one blow, not two. **The floor and the ceiling of the
	# period are in the same row** — a cooldown that never resets would take the whole bar off here.
	b.step(Rules.period_of(Rules.WOLF) - 0.1)
	t.ok(absf(float(b.soldier_hp[0]) - (full_s - Rules.damage_of(Rules.WOLF))) <= HP_NEAR,
		"한 주기가 차기 전에는 아직 한 대다 (%.3f)" % float(b.soldier_hp[0]))
	b.step(0.2)
	t.ok(absf(float(b.soldier_hp[0]) - (full_s - Rules.damage_of(Rules.WOLF) * 2.0)) <= HP_NEAR,
		"주기가 차면 두 대다 (%.3f)" % float(b.soldier_hp[0]))

	# **How many blows a kill takes, counted rather than asserted from the table's own division.**
	var fresh := _pair()
	var blows := 0
	var was := float(fresh.enemy_hp[0])
	for _i in int(round(20.0 / Rules.SIM_SUBSTEP_SEC)):
		fresh.step(Rules.SIM_SUBSTEP_SEC)
		if fresh.enemy_alive[0] == 0:
			break
		if float(fresh.enemy_hp[0]) < was - HP_NEAR:
			blows += 1
			was = float(fresh.enemy_hp[0])
	var want_blows := int(ceil(Rules.hp_of(Rules.WOLF) / Rules.damage_of(Rules.SWORDSMAN)))
	t.eq(fresh.enemy_alive[0], 0, "검사가 늑대를 죽인다")
	# The last blow is the one that kills, so the loop above misses it — hence `blows + 1`.
	t.eq(blows + 1, want_blows, "그러는 데 %d 대 걸린다 — 표의 나눗셈 그대로다" % want_blows)
	t.ok(fresh.elapsed <= float(want_blows - 1) * Rules.period_of(Rules.SWORDSMAN) 			+ Rules.SIM_SUBSTEP_SEC * 2.0,
		"그리고 %.1f초 안에 끝난다 — 첫 대가 한 주기를 안 기다린다 (%.2f)"
			% [float(want_blows - 1) * Rules.period_of(Rules.SWORDSMAN), fresh.elapsed])

	# ⚠ **Out of reach, nothing happens.** Without this the rows above are green for a fight that
	# resolves at any distance, which would delete `REACH_BONUS` from the game entirely.
	var apart := _battle_on(_grid(ISLE), PackedInt32Array(), -1)
	apart.place_ashore(0, apart.grid.tile_index(2, 2))
	apart.land_beast(Rules.WOLF, apart.grid.tile_index(9, 6))
	var gap := (apart.soldier_pos[0] as Vector2).distance_to(apart.enemy_pos[0] as Vector2)
	t.ok(gap > Rules.reach_of(Rules.SWORDSMAN) and gap > Rules.reach_of(Rules.WOLF),
		"둘을 서로 사거리 밖에 세웠다 — %.2f 조각 (자가 점검)" % gap)
	apart.step(5.0)
	t.eq(apart.soldier_hp[0], apart.army.max_hp_of(0), "사거리 밖이면 검사가 안 깎인다")
	t.eq(apart.enemy_hp[0], Rules.hp_of(Rules.WOLF), "늑대도 안 깎인다")
	t.eq(int(apart.soldier_target[0]), -1, "그리고 아무도 겨누고 있지 않다")


## **Damage lands in one phase and death latches in a later one.**
##
## ⚠⚠ **THIS IS THE ROW THE WHOLE PHASE ORDER EXISTS FOR, AND IT IS THE ONE THAT CANNOT BE READ OFF
## FINAL STATE ANY OTHER WAY.** Two bodies that each need exactly one more blow are stepped once. **If
## the death latched inside the attack phase, whichever the loop reached first would kill the other and
## walk away alive** — and that free kill is invisible in a fight that merely 「ended」.
func _the_blow_and_the_death_are_different_phases(t) -> void:
	var b := _pair()
	# Each is left on exactly what the other's blow takes off.
	b.soldier_hp[0] = Rules.damage_of(Rules.WOLF)
	b.enemy_hp[0] = Rules.damage_of(Rules.SWORDSMAN)
	t.ok(float(b.soldier_hp[0]) > 0.0 and float(b.enemy_hp[0]) > 0.0,
		"둘 다 아직 살아 있다 (자가 점검)")

	b.step(Rules.SIM_SUBSTEP_SEC)
	t.eq(int(b.soldier_state[0]), Battle.SoldierState.DEAD, "한 서브스텝에 검사가 죽는다")
	t.eq(b.enemy_alive[0], 0, "그리고 늑대도 같은 서브스텝에 죽는다 — 먼저 도는 쪽이 공짜 킬을 안 먹는다")
	t.eq(b.living_enemy_ids().size(), 0, "판에 산 짐승이 없다")
	t.eq(b.ashore_ids().size(), 0, "그리고 선 검사도 없다")

	# ⚠⚠ **THE INSTRUMENT'S OWN INVERSION.** The row above is green for a step that killed BOTH for the
	# wrong reason — say, a phase that kills everything that took any damage at all. **A body left one
	# point above the blow must survive the same step**, or 「both died」 says nothing about ordering.
	var c := _pair()
	c.soldier_hp[0] = Rules.damage_of(Rules.WOLF) + 1.0
	c.enemy_hp[0] = Rules.damage_of(Rules.SWORDSMAN) + 1.0
	c.step(Rules.SIM_SUBSTEP_SEC)
	t.eq(int(c.soldier_state[0]), Battle.SoldierState.ASHORE, "한 점 더 있으면 검사는 그 서브스텝을 넘긴다")
	t.eq(c.enemy_alive[0], 1, "늑대도 넘긴다 — 위의 「둘 다 죽었다」가 순서를 재는 것이 맞다")


## **A dead beast lets go of its 조각.** A corpse holding a reservation is a doorway half as wide with
## nothing on screen to explain it.
func _a_dead_beast_lets_go_of_its_piece(t) -> void:
	var b := _pair()
	var tile := b._tile_of(b.enemy_pos[0])
	t.ok(b.grid.holds(tile, Battle.ENEMY_UID_BASE + 0), "늑대가 제 조각을 잡고 있다 (자가 점검)")
	b.enemy_hp[0] = Rules.damage_of(Rules.SWORDSMAN)
	b.step(Rules.SIM_SUBSTEP_SEC)
	t.eq(b.enemy_alive[0], 0, "늑대가 죽었다 (자가 점검)")
	t.eq(b.grid.hold_count(tile), 0, "그리고 잡고 있던 조각을 놓는다 — 자리 하나도 안 남는다")

	# The 검사's target went with it. A target column still naming a corpse is what draws a blow at
	# something that is not there.
	t.eq(int(b.soldier_target[0]), -1, "검사가 겨누던 것도 같이 지워진다")


## **A dead 검사 stands again at the 성채 after `REVIVE_SEC`, and comes back whole.**
##
## ⚠⚠ **「죽으면 영영 죽는다」 WAS OVERTURNED 2026-08-30.** `Army.alive` is what carried permanent death
## and **it must not move** — this row asserts the body is DEAD in the battle and still alive on the
## roster, because those are two different sentences now.
func _a_dead_swordsman_stands_again_at_the_keep(t) -> void:
	var b := _pair()
	b.soldier_hp[0] = Rules.damage_of(Rules.WOLF)
	b.step(Rules.SIM_SUBSTEP_SEC)
	t.eq(int(b.soldier_state[0]), Battle.SoldierState.DEAD, "검사가 죽었다 (자가 점검)")
	t.eq(b.army.alive[0], 1, "그런데 명부에서는 여전히 살아 있다 — 영구 죽음이 아니다")
	t.eq(b.ashore_ids().size(), 0, "판 위에는 없다")

	b.step(Rules.REVIVE_SEC - 0.2)
	t.eq(int(b.soldier_state[0]), Battle.SoldierState.DEAD, "부활 시간이 차기 전에는 아직 없다")

	b.step(0.4)
	t.eq(int(b.soldier_state[0]), Battle.SoldierState.ASHORE, "부활 시간이 지나면 다시 선다")
	t.eq(b.soldier_hp[0], b.army.max_hp_of(0), "그리고 체력이 꽉 차 있다")

	var stood: Vector2 = b.soldier_pos[0]
	var gap := _keep_gap(b, stood)
	t.ok(gap <= 2.0, "선 자리가 성채 옆이다 (%.2f 조각) — 죽은 자리가 아니다" % gap)
	var tile := b._tile_of(stood)
	t.ok(b.grid.holds(tile, 0), "그리고 그 조각을 제 이름으로 잡는다")


# == the keep burns ===================================================================================

## **The 성채 takes the table's damage and the run is lost when it reaches zero.**
func _the_keep_burns_and_the_run_is_lost(t) -> void:
	var b := _at_the_keep()
	t.eq(b.keep_hp, Rules.KEEP_MAX_HP, "성채가 꽉 차 있다 (자가 점검)")
	t.ok(not b.lost, "그리고 아직 안 졌다")
	t.eq(b.boat_pos.size(), 0, "이 판에는 바다가 없어서 배가 안 온다 (자가 점검 — 한 마리만 잰다)")

	b.step(Rules.SIM_SUBSTEP_SEC)
	t.eq(int(b.enemy_target[0]), Battle.TARGET_KEEP, "늑대가 성채를 겨눈다")
	t.ok(absf(b.keep_hp - (Rules.KEEP_MAX_HP - Rules.damage_of(Rules.WOLF))) <= HP_NEAR,
		"한 대에 늑대의 피해만큼 깎인다 (%.2f)" % b.keep_hp)

	# The whole burn, counted. ⚠ **One wolf and not eight**, so the arithmetic is one row of the table
	# and not a product of two.
	var blows := int(ceil(Rules.KEEP_MAX_HP / Rules.damage_of(Rules.WOLF)))
	var want_sec := float(blows - 1) * Rules.period_of(Rules.WOLF)
	b.step(want_sec + 1.0)
	t.ok(b.keep_hp <= 0.0, "%d 대를 맞으면 성채가 0 이하다 (%.2f)" % [blows, b.keep_hp])
	t.ok(b.lost, "그리고 회차가 진 상태가 된다")

	# ⚠ **The floor under that ceiling**: it did NOT burn faster than one wolf can swing. Without this
	# the row above is green for a keep that falls on the first blow.
	var c := _at_the_keep()
	c.step(want_sec - Rules.period_of(Rules.WOLF))
	t.ok(not c.lost, "그 시간에서 한 주기를 빼면 아직 안 졌다 (%.2f 남음)" % c.keep_hp)
	t.ok(c.keep_hp > 0.0, "성채도 아직 남아 있다")

	# ⚠ **Nothing else burns it.** A 검사 standing beside his own house must not knock it down, and a
	# keep that any blow damages is a keep the player loses to himself.
	var d := _battle_on(_grid(LAND), _keep(), ISLE_MUSTER)
	d.place_ashore(0, d.grid.tile_index(4, 4))
	d.step(10.0)
	t.eq(d.keep_hp, Rules.KEEP_MAX_HP, "검사가 성채 옆에 서 있어도 성채는 안 깎인다")
	t.ok(not d.lost, "그리고 안 진다")


## **A lost run stops the clock.** The verdict latches inside the sub-step loop, so nothing runs after
## the 성채 falls — 「졌는데 늑대가 계속 걷는다」 is one frame of the picture saying the opposite of the
## state.
func _a_lost_run_stops_the_clock(t) -> void:
	var b := _at_the_keep()
	var blows := int(ceil(Rules.KEEP_MAX_HP / Rules.damage_of(Rules.WOLF)))
	b.step(float(blows) * Rules.period_of(Rules.WOLF) + 1.0)
	t.ok(b.lost, "졌다 (자가 점검)")

	var was_elapsed := b.elapsed
	var was_substeps := b.substeps
	var was_pos: Vector2 = b.enemy_pos[0]
	b.step(5.0)
	t.eq(b.elapsed, was_elapsed, "그 뒤로는 시계가 안 간다")
	t.eq(b.substeps, was_substeps, "서브스텝도 안 는다")
	t.ok((b.enemy_pos[0] as Vector2).distance_to(was_pos) <= NEAR, "그리고 짐승도 안 움직인다")


# == determinism ======================================================================================

## **The same fight at 1x and at a tenth of the frame rate lands on the same state.**
func _the_fight_is_the_same_at_any_frame_rate(t) -> void:
	var total := Rules.BOAT_FIRST_SEC + _crossing_sec() + 12.0
	var fine := _battle_on(_grid(ISLE), _keep(), ISLE_MUSTER)
	var coarse := _battle_on(_grid(ISLE), _keep(), ISLE_MUSTER)
	fine.place_ashore(0, fine.grid.tile_index(4, 3))
	coarse.place_ashore(0, coarse.grid.tile_index(4, 3))
	var n := int(round(total * 60.0))
	for _i in n:
		fine.step(1.0 / 60.0)
	coarse.step(total)

	t.eq(fine.substeps, coarse.substeps, "서브스텝 횟수가 같다 (자가 점검)")
	t.eq(fine.enemy_type.size(), coarse.enemy_type.size(), "내린 짐승 수가 같다")
	t.ok(fine.enemy_type.size() > 0, "그리고 실제로 내렸다 (자가 점검 — 0이면 아래가 공허하다)")
	t.eq(fine.keep_hp, coarse.keep_hp, "성채 체력이 같다")
	var drift := 0.0
	var hp_off := 0.0
	for i in mini(fine.enemy_pos.size(), coarse.enemy_pos.size()):
		drift = maxf(drift, (fine.enemy_pos[i] as Vector2).distance_to(coarse.enemy_pos[i]))
		hp_off = maxf(hp_off, absf(float(fine.enemy_hp[i]) - float(coarse.enemy_hp[i])))
	t.ok(drift <= NEAR, "짐승이 선 자리도 같다 (어긋난 거리 %.6f)" % drift)
	t.ok(hp_off <= HP_NEAR, "그리고 체력도 같다 (어긋난 값 %.6f)" % hp_off)


## **Nearest is Euclidean and a tie goes to the lower id.** A tie broken by iteration order makes two
## runs from identical state diverge with every check about them green.
func _nearest_ties_break_on_the_lower_id(t) -> void:
	var b := _battle_on(_grid(ISLE), PackedInt32Array(), -1)
	# Two 검사 exactly the same distance either side of one 늑대.
	var mid := b.grid.tile_index(5, 4)
	t.eq(b.place_ashore(0, b.grid.tile_index(4, 4)), b.grid.tile_index(4, 4), "검사 0 이 (4,4) 에 섰다")
	t.eq(b.place_ashore(1, b.grid.tile_index(6, 4)), b.grid.tile_index(6, 4), "검사 1 이 (6,4) 에 섰다")
	var who := b.land_beast(Rules.WOLF, mid)
	t.eq(b._tile_of(b.enemy_pos[who]), mid, "늑대가 그 사이 (5,4) 에 섰다 (자가 점검)")
	var d0 := b._dist(b.enemy_pos[who], b.soldier_pos[0])
	var d1 := b._dist(b.enemy_pos[who], b.soldier_pos[1])
	t.ok(absf(d0 - d1) <= NEAR, "둘까지의 거리가 정확히 같다 (자가 점검 — %.4f · %.4f)" % [d0, d1])

	b.step(Rules.SIM_SUBSTEP_SEC)
	t.eq(int(b.enemy_target[who]), 0, "동점이면 낮은 번호를 문다")
	t.ok(float(b.soldier_hp[0]) < float(b.soldier_hp[1]),
		"그래서 0 번만 깎였다 (%.2f · %.2f)" % [float(b.soldier_hp[0]), float(b.soldier_hp[1])])

	# ⚠ **The instrument's own inversion**: move the higher id one 조각 closer and the tie-break must
	# lose to the distance. A rule that always answered 0 would pass the row above.
	var c := _battle_on(_grid(ISLE), PackedInt32Array(), -1)
	c.place_ashore(0, c.grid.tile_index(3, 4))
	c.place_ashore(1, c.grid.tile_index(6, 4))
	c.land_beast(Rules.WOLF, c.grid.tile_index(5, 4))
	c.step(Rules.SIM_SUBSTEP_SEC)
	t.eq(int(c.enemy_target[0]), 1, "동점이 아니면 가까운 쪽을 문다 — 번호가 이기는 게 아니다")


# == fixtures =========================================================================================

func _grid(rows: Array) -> Grid:
	var g := Grid.new()
	g.load_rows(rows)
	return g


func _real() -> Grid:
	var g := Grid.new()
	Islands.load_into(g)
	return g


func _keep() -> PackedInt32Array:
	var out := PackedInt32Array()
	for raw in ISLE_KEEP:
		out.append(int(raw))
	return out


func _battle(rows: Array) -> Battle:
	return _battle_on(_grid(rows), _keep(), ISLE_MUSTER)


## ⚠ **`keep` and `muster` are handed in separately here exactly as `Run` hands them in**, so a fixture
## with a 성채 and no doorstep, or a doorstep and no 성채, is a board this file can actually build. Both
## are real boards and both are used below.
func _battle_on(g: Grid, keep: PackedInt32Array, muster: int) -> Battle:
	var army := Army.new()
	army.add_starting_force()
	var b := Battle.new()
	b.setup(g, army, [], keep, muster)
	return b


## **One 검사 and one 늑대 standing next to each other on flat ground, in the island's far corner.**
##
## ⚠ **Far enough from the 성채 that it is not in reach of it**, so what the 늑대 is fighting is the body
## beside it and the rows below are measuring a blow rather than a wall. ⚠ **The 성채 is there anyway**,
## because a revival needs a doorstep to happen at.
func _pair() -> Battle:
	var b := _battle_on(_grid(ISLE), _keep(), ISLE_MUSTER)
	b.place_ashore(0, b.grid.tile_index(2, 2))
	b.land_beast(Rules.WOLF, b.grid.tile_index(3, 2))
	return b


## **One 늑대 standing in reach of the 성채 with nobody defending it, on the landlocked board.**
## ⚠ **Landlocked on purpose** — see `LAND`: on a board with a coast the burn is three boats, not one 늑대.
func _at_the_keep() -> Battle:
	var b := _battle_on(_grid(LAND), _keep(), ISLE_MUSTER)
	b.land_beast(Rules.WOLF, b.grid.tile_index(4, 4))
	return b


## **Steps one sub-step at a time until the first boat has put everybody ashore.** Bounded, because a
## net that hangs prints no verdict at all and that disarms mutation testing on the whole file.
func _step_until_landed(b: Battle) -> void:
	var guard := int(round((Rules.BOAT_FIRST_SEC + _crossing_sec() + 5.0) / Rules.SIM_SUBSTEP_SEC))
	for _i in guard:
		b.step(Rules.SIM_SUBSTEP_SEC)
		if not b.boat_riders.is_empty() and int(b.boat_riders[0]) == 0:
			return


## How long one crossing takes on this fixture, derived rather than pinned — the speed and the distance
## are `net_boats`' to hold.
func _crossing_sec() -> float:
	return (Rules.BOAT_START_DIST_TILES - Rules.BOAT_STANDOFF_TILES) / Rules.BOAT_SPEED_TILES


## **How far `p` is from the nearest 조각 of the 성채, height included** — this file's OWN arithmetic and
## not `Battle.keep_gap`, so the rows above are not reading the reach test back off the thing they check.
func _keep_gap(b: Battle, p: Vector2) -> float:
	var best := INF
	for k in b.keep_tiles.size():
		var tile := int(b.keep_tiles[k])
		var q := Vector2(tile % b.grid.w, tile / b.grid.w)
		var dh := b.grid.height_at(p) - b.grid.height_at(q)
		best = minf(best, sqrt(p.distance_squared_to(q) + dh * dh))
	return best


## A board with a level-0 strip, a stair and a level-2 plateau, for the reach window.
## ⚠ Legend: `.` is level 0, `1` is a stair, `4` is level 2 — see `Grid.TIER_CHARS` and `TIER_LEVELS`.
func _stair_board() -> Grid:
	var g := Grid.new()
	g.load_rows([
		"~~~~~~",
		"~....~",
		"~....~",
		"~....~",
		"~~~~~~",
	], [
		"......",
		".0122.",
		".0122.",
		".0122.",
		"......",
	])
	return g
