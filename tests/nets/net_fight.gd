extends RefCounted
## **The beasts get off the boat and the fight happens.** 티켓 41, the 목~일 slice.
##
## The claim under test is one sentence: **an arrived boat puts its 늑대 on the landing ring as real
## bodies, they walk at the 성채, blows take the numbers `Rules.UNITS` carries, death latches in a later
## phase than the blow, a dead 검사 stands again at the 성채, and the 성채 reaching zero loses the run.**
##
## ⚠⚠ **NOTHING HERE TOUCHES THE TREE.** `Grid.new()`, `Army.new()`, `Battle.new()` and `step(dt)` are
## the whole of it — the `src/sim/` seam `GLOSSARY.md` names.
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
## WAY.** Burning `KEEP_MAX_HP` with one 늑대 takes sixty seconds, and boats used to land every thirty —
## **another boat lands during the row**, so 「it had not fallen yet」 was already false at half the time and
## the floor under the burn read as a defect in the burn. **A landlocked board is the only place one
## 늑대 is one 늑대.** ⚠ The wave clock of 2026-09-03 puts the first hull 461.75 s out, which would HIDE
## that collision rather than fix it — the board stays landlocked so these rows cannot start depending
## on a launch time again.
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

## **A 성채 standing on 눈금 2 with the flat ground hugging it and exactly one 계단 up** — the board
## 티켓 02-01 is about, and the shape the shipped island has around its own house.
##
## ⚠⚠ **LANDLOCKED, FOR THE REASON `LAND` IS**: a coast launches boats, and every row below counts one
## 늑대. ⚠ **No doorstep either** — `_on_the_plateau` hands `-1` as the muster, so nothing but the 늑대
## being placed is ever on the board and a blow that lands cannot have come from a defender.
const PLATEAU := [
	"........",
	"........",
	"........",
	"........",
	"........",
	"........",
	"........",
]
## ⚠ Legend: `0` is 눈금 0, `1` is a 계단 tread, `2` is 눈금 2 — see `Grid.TIER_CHARS`.
## ⚠⚠ **The 계단 is a SINGLE tread and it is west of the house, not beside the low ring**, so the two
## cases the rule has to tell apart — flat ground hugging the plateau and a tread hugging it — are both
## on this board at once.
const PLATEAU_TIERS := [
	"00000000",
	"00000000",
	"00022000",
	"00122000",
	"00000000",
	"00000000",
	"00000000",
]
const PLATEAU_W := 8
## The 성채's four 조각 on `PLATEAU`, all four on 눈금 2 — the footprint the shipped island's keep has.
const PLATEAU_KEEP := [
	3 + 2 * PLATEAU_W,
	4 + 2 * PLATEAU_W,
	3 + 3 * PLATEAU_W,
	4 + 3 * PLATEAU_W,
]

## **A 성채 on 눈금 0 walled in on every side by 눈금 2** — the one board where the doorstep exists and
## has nowhere free beside it.
##
## ⚠⚠ **WALLED WITH HEIGHT AND NOT WITH WATER, DELIBERATELY.** A one-조각 island in a sea launches boats,
## and a 늑대 unloading onto the 조각 the row is about to free could take it before the recruit is
## called. **Landlocked, so the only thing that can take that 조각 is the thing under test.**
## ⚠ The house fills its own 조각 (`Battle.setup`), and a body may not climb two 눈금, so
## `_free_tiles_from` can reach nothing at all from the doorstep.
const BOXED := [
	".....",
	".....",
	".....",
	".....",
	".....",
]
const BOXED_TIERS := [
	"22222",
	"22222",
	"22022",
	"22222",
	"22222",
]
const BOXED_W := 5
const BOXED_KEEP := 2 + 2 * BOXED_W

## Tolerance on an accumulated distance in 조각. Positions are summed one sub-step at a time.
const NEAR := 1e-3
## Tolerance on an accumulated HP. Damage is subtracted whole, so this is float noise and nothing else.
const HP_NEAR := 1e-3
## **Seconds from two bodies meeting to the first blow LANDING.** The swing starts on the first
## sub-step (0 is ready) and the blow lands `Rules.SWING_LAND_SEC` later (2026-09-02 — until then the
## first sub-step dealt the damage itself). Half a sub-step of slack so the landing sub-step is inside
## the step whatever the float sum does.
const FIRST_BLOW_SEC := Rules.SWING_LAND_SEC + Rules.SIM_SUBSTEP_SEC * 1.5

## The Variant types `_columns_match` accepts as a column. Anything else with a matching name is not a
## per-body array and is skipped rather than being asked for a size it does not have.
## ⚠ A plain `const` Array, not a typed packed one — `const X := PackedInt32Array([...])` does not parse
## on 4.7.1, which every flat table in this repo has walked into.
const _ARRAY_TYPES := [
	TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY,
	TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY,
	TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY,
]
## **Floors on how many columns the sweep found**, counted on 2026-09-03: sixteen per 검사, eleven per
## 짐승. They exist so a sweep that matches nothing cannot report a clean pass — see `_columns_match`.
const _SOLDIER_COLUMNS := 16
const _ENEMY_COLUMNS := 11


func run(t) -> void:
	_the_numbers_are_the_ones_that_were_chosen(t)
	_the_reach_is_the_range_plus_the_bonus_and_the_window_holds(t)
	_a_blow_crosses_no_more_notches_than_a_body_climbs(t)
	_the_keep_cannot_be_burned_from_low_ground(t)
	_the_keep_is_read_off_the_island_file(t)
	_an_arrived_boat_puts_its_riders_on_the_board(t)
	_beasts_pack_a_piece_and_never_overfill_it(t)
	_the_beasts_walk_at_the_keep_and_stop_in_reach(t)
	_a_blow_takes_the_table_s_damage_on_the_table_s_period(t)
	_the_blow_and_the_death_are_different_phases(t)
	_a_dead_beast_lets_go_of_its_piece(t)
	_a_dead_swordsman_stands_again_at_the_keep(t)
	_the_keep_turns_out_a_new_swordsman(t)
	_the_recruiting_stops_at_the_ceiling(t)
	_a_recruit_with_nowhere_to_stand_is_refused(t)
	_the_keep_burns_and_the_run_is_lost(t)
	_a_lost_run_stops_the_clock(t)
	_the_fight_is_the_same_at_any_frame_rate(t)
	_nearest_ties_break_on_the_lower_id(t)
	_two_bodies_that_come_near_each_other_stop_walking_past(t)
	_a_defender_pulls_a_landed_wolf_off_its_line(t)
	_a_wolf_at_the_wall_keeps_the_wall(t)
	_a_blow_between_bodies_crosses_no_more_notches_than_a_body_climbs(t)
	_the_reach_tier_takes_the_further_body_it_can_strike_over_the_nearer_it_cannot(t)
	_a_wolf_that_cannot_strike_its_target_walks_up_and_stands(t)
	_a_chase_builds_one_field_per_piece_the_target_crosses(t)
	_the_shipped_island_s_first_wave_meets_the_watch_at_the_door(t)
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
	# ⚠⚠ **NINE IS THE USER'S, AND IT IS NOT `BLOCK_CAPACITY`** even though the two agree today. 티켓
	# 02-09: 「천장 아홉 개」. ⚠ **The twenty beside it is gone** — `MUSTER_PERIOD_SEC` was deleted with the
	# automatic muster on 2026-09-02 (the user: 「자동 병사 생성 지워줘」), so there is no period to pin.
	t.eq(Rules.MUSTER_CAP, 9, "검사는 아홉이 천장이다")
	# ⚠⚠ **240 -> 120 ON 2026-09-01, WITH THE BOATLOAD** (the user: 「내려」). 240 was fifteen seconds
	# of one undefended boat at `BOAT_CAPACITY` 8; at four the same arithmetic hit the whole 30-second
	# boat interval of that day and 「a boat ignored whole loses you the run」 went false. **120 puts
	# those fifteen seconds back.** See the burn row below, which is what this pin protects — and read
	# its note: the interval it was measured against died with the wave table on 2026-09-03.
	t.eq(Rules.KEEP_MAX_HP, 120.0, "성채 체력은 120 이다")
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
	# ⚠⚠ **The blow lands while the picture's sword is furthest out** (2026-09-02). The sim does not
	# read the strip and the strip does not read the sim, so this row is the only thing holding
	# `Rules.SWING_LAND_SEC` inside the lunge's hold window — `Look.SWING_WINDUP + SWING_SNAP` to
	# `+ SWING_HOLD`, as fractions of the attack strip. Move either and this reddens.
	var reach_at := (Look.SWING_WINDUP + Look.SWING_SNAP) * swing
	var reach_until := reach_at + Look.SWING_HOLD * swing
	t.ok(Rules.SWING_LAND_SEC >= reach_at - 1e-6 and Rules.SWING_LAND_SEC <= reach_until + 1e-6,
		"피해는 칼이 끝까지 나간 사이에 들어간다 — %.2f 초는 %.2f~%.2f 안이다"
			% [Rules.SWING_LAND_SEC, reach_at, reach_until])
	t.ok(Rules.SWING_LAND_SEC < Rules.period_of(Rules.WOLF) and Rules.SWING_LAND_SEC < swing,
		"그리고 휘두르는 시간이 주기보다도 동작 길이보다도 짧다")
	t.ok(absf(Rules.SWING_LAND_SEC / Rules.SIM_SUBSTEP_SEC - round(Rules.SWING_LAND_SEC / Rules.SIM_SUBSTEP_SEC)) < 1e-6,
		"휘두르는 시간이 서브스텝의 정수배다 — 닿는 서브스텝이 반올림에 안 걸린다")

	# ⚠⚠ **THE DETECT RADII, TICKET 07-01** (2026-09-02). **3.0 is a new number** — a 칸's diagonal 2.828
	# rounded up, so a 검사 notices anything on a 칸 touching his own and nothing further; **6.0 is the
	# only detect number any design in this repo ever wrote** and it stands unchanged, so a difference on
	# screen is attributable to its first reader and not to a retune.
	t.eq(Rules.detect_of(Rules.SWORDSMAN), 3.0, "검사는 세 조각 안의 늑대를 알아챈다")
	t.eq(Rules.detect_of(Rules.WOLF), 6.0, "늑대는 여섯 조각 안의 검사를 알아챈다 — 표에 있던 수 그대로다")
	# ⚠ **6.0 and not 7.75.** `reach_of` is the ONE place `REACH_BONUS` is added; a `detect_of` that
	# mirrored it would make the 늑대's detection 7.75 with nothing on screen or in the table saying so.
	t.ok(absf(Rules.detect_of(Rules.WOLF) - (6.0 + Rules.REACH_BONUS)) > NEAR,
		"탐지는 표의 칸 그대로다 — 사거리 보너스가 두 번 더해지지 않는다")

	# ⚠⚠ **THE ANCHOR THIS ROW WAS WRITTEN AGAINST DIED ON 2026-09-03 AND HAS NOT BEEN REPLACED.** It
	# read 「그 초는 배 간격보다 짧고 간격의 4분의 1보다는 길다」 — one boat must not end the run, two
	# must, inside one 30-second interval — and the constant it named is deleted. **No candidate
	# replacement makes both halves true**: the wave's 15 s gap gives `15 < 15` false, its 10 s gap
	# gives `15 < 10` false, and the 480 s wave interval gives `15 > 120` false.
	#
	# ✅ **The user kept 120 and had the row rewritten to pin the fact instead** (「추천대로 해줘」).
	# What survives is the fifteen seconds as a NUMBER: the row still goes red if the 성채, the boatload,
	# the damage or the period moves, which is what it was for. **It no longer claims a rule it cannot
	# measure.**
	# ⚠ **Stated and not hidden**: wave 1 is one boat, so an unopposed first wave ends the run at 8:15.
	# Balance is decided by playing, not by this file.
	var one_boat_dps := float(Rules.BOAT_CAPACITY) * Rules.damage_of(Rules.WOLF) 			/ Rules.period_of(Rules.WOLF)
	var burn_sec := Rules.KEEP_MAX_HP / one_boat_dps
	t.ok(absf(burn_sec - 15.0) < 0.001,
		"배 한 척이 아무도 안 막으면 성채를 15.0초에 태운다 (얻은 값 %.3f)"
			% burn_sec)
	t.ok(Rules.KEEP_MAX_HP == 120.0 and Rules.BOAT_CAPACITY == 4,
		"그 15초를 만드는 네 값 중 하나라도 움직이면 위가 빨강이다 (자가 점검)")


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


# == the keep has to be climbed to ====================================================================

## **`Grid.can_strike` — a blow crosses no more 눈금 than a body climbs, and it asks nothing else.**
##
## ⚠⚠ **THE 눈금 GAP IS THE ONLY THING THAT SEPARATES THE TWO CASES, WHICH IS THE WHOLE CLAIM.** Flat
## ground beside the plateau and a 계단 tread beside it are both about 1.4 조각 from the 조각 above, so
## these rows drive the LEVELS and never a distance.
func _a_blow_crosses_no_more_notches_than_a_body_climbs(t) -> void:
	var g := Grid.new()
	g.load_rows(PLATEAU, PLATEAU_TIERS)
	var low := g.tile_index(2, 2)
	var low2 := g.tile_index(1, 2)
	var stair := g.tile_index(2, 3)
	var high := g.tile_index(3, 2)
	var high2 := g.tile_index(4, 2)
	t.eq(g.level_of(low), 0, "낮은 조각이 눈금 0 이다 (자가 점검)")
	t.eq(g.level_of(stair), 1, "계단 조각이 눈금 1 이다 (자가 점검)")
	t.eq(g.level_of(high), 2, "고원 조각이 눈금 2 이다 (자가 점검)")

	t.ok(g.can_strike(low, low2), "같은 눈금끼리는 때린다")
	t.ok(g.can_strike(high, high2), "높은 눈금끼리도 때린다")
	t.ok(g.can_strike(low, stair), "눈금 하나 차이는 때린다")
	t.ok(g.can_strike(stair, high), "계단에서 고원을 때린다 — 이것이 사거리 값을 못 내리는 이유다")
	t.ok(not g.can_strike(low, high), "눈금 둘 차이는 못 때린다 — 1층에서 성채를 못 태운다")
	t.ok(not g.can_strike(high, low), "위에서 아래로도 못 때린다 — 고원이 사격대가 되지 않는다")
	t.ok(not g.can_strike(low, -1), "격자 밖은 거절이다")
	t.ok(not g.can_strike(-1, low), "반대쪽 끝도 거절이다")
	t.ok(not g.can_strike(low, g.w * g.h), "격자 끝 너머도 거절이다")

	# ⚠⚠ **THE ROWS THAT GO RED FOR A `can_strike` THAT IS `can_step` UNDER A NEW NAME.** Everything
	# above is equally green for a copy of the walk rule, and the day somebody folds the two together a
	# 검사 stops hitting what is standing in front of him. **Two places where walking is refused and
	# striking must not be**: water, and a wall corner.
	var sea := _grid(ISLE)
	var shore := sea.tile_index(2, 2)
	var surf := sea.tile_index(1, 2)
	t.eq(sea.passable[surf], 0, "물 조각을 하나 잡았다 (자가 점검)")
	t.ok(not sea.can_step(shore, surf), "거기로는 걸어 들어가지 못한다 (자가 점검)")
	t.ok(sea.can_strike(shore, surf), "그런데 때리기는 한다 — 통행을 안 묻는다")

	var corner := _grid([
		"~~~~",
		"~.~~",
		"~~.~",
		"~~~~",
	])
	var a := corner.tile_index(1, 1)
	var b := corner.tile_index(2, 2)
	t.ok(not corner.can_step(a, b), "양 어깨가 막힌 대각선은 걸어서 못 지난다 (자가 점검)")
	t.ok(corner.can_strike(a, b), "그런데 때리기는 한다 — 어깨를 안 묻는다")


## **A 늑대 on the flat ground hugging the 성채 cannot burn it, and one on the 계단 still can.**
##
## ⚠⚠ **BOTH HALVES OR NEITHER IS WORTH ANYTHING.** 「낮은 땅에서 못 태운다」 is green for a 성채
## nothing can ever hurt, and that is the same defect inverted — a round that cannot be lost. **The
## 계단 rows below are the floor**, and the last pair walks a 늑대 up there on its own feet so that
## 「low ground has to climb」 is what is measured rather than 「low ground never wins」.
func _the_keep_cannot_be_burned_from_low_ground(t) -> void:
	var fixture := _on_the_plateau()
	var g := fixture.grid
	var low_ring := PackedInt32Array()
	var stair_ring := PackedInt32Array()
	var seen := {}
	for k in fixture.keep_tiles.size():
		var kt := int(fixture.keep_tiles[k])
		var kx := kt % g.w
		var ky := kt / g.w
		for n in Grid.NEIGHBOURS.size():
			var nx := kx + int(Grid.NEIGHBOURS[n][0])
			var ny := ky + int(Grid.NEIGHBOURS[n][1])
			if nx < 0 or ny < 0 or nx >= g.w or ny >= g.h:
				continue
			var nt := ny * g.w + nx
			if seen.has(nt) or fixture.keep_tiles.has(nt):
				continue
			seen[nt] = true
			if g.level_of(nt) == 0:
				low_ring.append(nt)
			elif g.level_of(nt) == 1:
				stair_ring.append(nt)
	t.eq(low_ring.size(), 11, "성채를 두른 1층 자리가 열하나다 (자가 점검)")
	t.eq(stair_ring.size(), 1, "그리고 그중 계단이 하나다 (자가 점검)")

	# **Every 자리, not a sample.** Eight of them hugged the shipped island's 성채 and all eight burned
	# it; a row that probes one is green for a rule that only refuses one direction.
	var stood := PackedInt32Array()
	var in_gap := PackedInt32Array()
	var targeted := PackedInt32Array()
	var hurt := PackedInt32Array()
	for i in low_ring.size():
		var tile := int(low_ring[i])
		var b := _on_the_plateau()
		var who := b.land_beast(Rules.WOLF, tile)
		if who < 0 or b._tile_of(b.enemy_pos[who]) != tile:
			stood.append(tile)
			continue
		if not is_inf(b.keep_gap(b.enemy_pos[who])):
			in_gap.append(tile)
		b.step(Rules.SIM_SUBSTEP_SEC)
		if int(b.enemy_target[who]) != Battle.TARGET_NONE:
			targeted.append(tile)
		if b.keep_hp < Rules.KEEP_MAX_HP:
			hurt.append(tile)
	t.eq(stood.size(), 0, "1층 자리 열하나에 늑대가 하나씩 실제로 섰다 (자가 점검) %s" % str(stood))
	t.eq(in_gap.size(), 0, "그 자리에서는 때릴 성채 조각이 하나도 없다 %s" % str(in_gap))
	t.eq(targeted.size(), 0, "그래서 아무도 성채를 안 겨눈다 %s" % str(targeted))
	t.eq(hurt.size(), 0, "성채 체력이 한 점도 안 깎였다 %s" % str(hurt))

	# ⚠ **The planar distance is IDENTICAL for the 계단**, which is why the rows above cannot be a
	# distance rule wearing a level rule's name.
	var s := _on_the_plateau()
	var stair := int(stair_ring[0])
	var climber := s.land_beast(Rules.WOLF, stair)
	t.ok(climber >= 0, "계단 조각에 늑대를 세웠다 (자가 점검)")
	t.eq(s._tile_of(s.enemy_pos[climber]), stair, "그 조각에 진짜로 섰다 (자가 점검)")
	var gap := s.keep_gap(s.enemy_pos[climber])
	t.ok(gap <= Rules.reach_of(Rules.WOLF) + Rules.EPS,
		"계단에서는 성채까지 %.3f 조각이고 사거리 %.2f 안이다" % [gap, Rules.reach_of(Rules.WOLF)])
	s.step(FIRST_BLOW_SEC)
	t.eq(int(s.enemy_target[climber]), Battle.TARGET_KEEP, "그리고 성채를 겨눈다")
	t.ok(s.keep_hp < Rules.KEEP_MAX_HP, "한 대가 실제로 들어간다 (%.2f)" % s.keep_hp)

	# **And it gets up there on its own feet.** ⚠ The budget is 40 조각 of walking at the table's own
	# speed — far more than this board's route needs, so the row measures whether it climbs and never
	# how fast.
	var climb := _on_the_plateau()
	var far := climb.grid.tile_index(0, 6)
	var walker := climb.land_beast(Rules.WOLF, far)
	t.ok(walker >= 0, "판 구석에서 한 마리 출발시킨다 (자가 점검)")
	t.eq(climb.grid.level_of(climb._tile_of(climb.enemy_pos[walker])), 0, "1층에서 출발한다 (자가 점검)")
	t.ok(is_inf(climb.keep_gap(climb.enemy_pos[walker])), "출발 자리에서는 성채를 못 때린다 (자가 점검)")
	climb.step(40.0 / Rules.speed_of(Rules.WOLF))
	t.eq(climb.grid.level_of(climb._tile_of(climb.enemy_pos[walker])), 1,
		"걸려 두면 계단 위에 올라와 있다 — 낮은 땅이 못 이기는 게 아니라 올라와야 하는 것이다")
	t.ok(climb.keep_hp < Rules.KEEP_MAX_HP, "그리고 성채를 때리기 시작한다 (%.2f)" % climb.keep_hp)


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
## of a boat that simply forgot its riders; 「the bodies exist」 is true of a spawn loop that never
## read the boat. **The two are asserted against each other.**
func _an_arrived_boat_puts_its_riders_on_the_board(t) -> void:
	var b := _battle(ISLE)
	b.step(_first_hull_sec())
	t.eq(b.boat_pos.size(), 1, "배가 한 척 떴다 (자가 점검)")
	t.eq(int(b.boat_riders[0]), Rules.BOAT_CAPACITY, "넷이 타 있다 (자가 점검)")
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
	t.eq(wrong_type, 0, "넷이 전부 늑대다")
	t.eq(wrong_hp, 0, "그리고 전부 표가 준 체력으로 선다")

	# They came off at the beach the boat was aimed at, not somewhere else on the island.
	var beach := int(b.boat_beach[0])
	var beach_pt := Vector2(beach % b.grid.w, beach / b.grid.w)
	var far := 0
	for raw in live:
		if (b.enemy_pos[int(raw)] as Vector2).distance_to(beach_pt) > 4.0:
			far += 1
	t.eq(far, 0, "그리고 겨눈 해변 언저리에 내렸다 — 섬 아무 데나가 아니다")

	# ⚠ **The beast side of the short-column sweep.** `land_beast` appends its own list, and 검사 쪽 was
	# two columns short for a day before anything read it back — the same hole here would be an
	# out-of-range read on the sub-step after a landing.
	_enemy_columns_are_level(t, b, "내린 뒤")


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

	# ⚠⚠ **THE FIRST SUB-STEP STARTS THE SWING AND DEALS NOTHING** (2026-09-02). Both bars are whole
	# after it — a sim that dealt the damage at the start of the swing is the one the user watched
	# and called 「애니메이션하고 코드적 액션이 안맞음」.
	b.step(Rules.SIM_SUBSTEP_SEC)
	t.eq(b.soldier_hp[0], full_s, "첫 서브스텝에는 검사가 아직 안 깎인다 — 휘두르기가 시작만 됐다")
	t.eq(b.enemy_hp[0], full_e, "늑대도 아직 안 깎인다")
	t.ok(float(b.soldier_cool[0]) > 0.0 and float(b.enemy_cool[0]) > 0.0,
		"그런데 둘 다 재사용 대기는 감겼다 — 휘두르기가 시작됐다는 표시")
	t.ok(float(b.soldier_swing[0]) > 0.0 and float(b.enemy_swing[0]) > 0.0,
		"그리고 둘 다 휘두르는 중이다")
	t.eq(int(b.soldier_swing_at[0]), 0, "검사의 휘두르기는 늑대 0 을 향한다")
	t.eq(int(b.enemy_swing_at[0]), 0, "늑대의 것은 검사 0 을 향한다")
	# `Rules.SWING_LAND_SEC` later: **each lands exactly one blow, and the first one is not a period away.**
	b.step(FIRST_BLOW_SEC - Rules.SIM_SUBSTEP_SEC)
	t.ok(absf(float(b.soldier_hp[0]) - (full_s - Rules.damage_of(Rules.WOLF))) <= HP_NEAR,
		"휘두르기 시간이 지나면 검사가 늑대 한 대만큼 깎인다 (%.3f)" % float(b.soldier_hp[0]))
	t.eq(int(b.soldier_blows[0]), 1, "검사가 한 대 맞혔다고 센다")
	t.eq(int(b.enemy_blows[0]), 1, "늑대도 한 대")
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
	t.ok(fresh.elapsed <= float(want_blows - 1) * Rules.period_of(Rules.SWORDSMAN) 			+ Rules.SWING_LAND_SEC + Rules.SIM_SUBSTEP_SEC * 2.0,
		"그리고 %.1f초 안에 끝난다 — 첫 대가 한 주기를 안 기다린다, 휘두르는 시간만 기다린다 (%.2f)"
			% [float(want_blows - 1) * Rules.period_of(Rules.SWORDSMAN) + Rules.SWING_LAND_SEC,
				fresh.elapsed])

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
	# ⚠ **Re-derived from the detect number since 07-01.** 3.0 and 6.0 both sit under this pair's 8.06,
	# and the three reads above fall together the day either passes it — so the gap is measured against
	# the wider radius here rather than left standing as a coincidence.
	var widest := maxf(Rules.detect_of(Rules.SWORDSMAN), Rules.detect_of(Rules.WOLF))
	t.ok(gap > widest + NEAR,
		"그리고 둘 다의 탐지 반경 %.1f 밖이다 — 이 대조군은 탐지가 %.2f 를 넘는 날 여기서 붉어진다 (자가 점검)"
			% [widest, gap])


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

	b.step(FIRST_BLOW_SEC)
	t.eq(int(b.soldier_state[0]), Battle.SoldierState.DEAD, "첫 대가 닿는 서브스텝에 검사가 죽는다")
	t.eq(b.enemy_alive[0], 0, "그리고 늑대도 같은 서브스텝에 죽는다 — 먼저 도는 쪽이 공짜 킬을 안 먹는다")
	t.eq(b.living_enemy_ids().size(), 0, "판에 산 짐승이 없다")
	t.eq(b.ashore_ids().size(), 0, "그리고 선 검사도 없다")

	# ⚠⚠ **THE INSTRUMENT'S OWN INVERSION.** The row above is green for a step that killed BOTH for the
	# wrong reason — say, a phase that kills everything that took any damage at all. **A body left one
	# point above the blow must survive the same step**, or 「both died」 says nothing about ordering.
	var c := _pair()
	c.soldier_hp[0] = Rules.damage_of(Rules.WOLF) + 1.0
	c.enemy_hp[0] = Rules.damage_of(Rules.SWORDSMAN) + 1.0
	c.step(FIRST_BLOW_SEC)
	t.eq(int(c.soldier_state[0]), Battle.SoldierState.ASHORE, "한 점 더 있으면 검사는 그 서브스텝을 넘긴다")
	t.eq(c.enemy_alive[0], 1, "늑대도 넘긴다 — 위의 「둘 다 죽었다」가 순서를 재는 것이 맞다")


## **A dead beast lets go of its 조각.** A corpse holding a reservation is a doorway half as wide with
## nothing on screen to explain it.
func _a_dead_beast_lets_go_of_its_piece(t) -> void:
	var b := _pair()
	var tile := b._tile_of(b.enemy_pos[0])
	t.ok(b.grid.holds(tile, Battle.ENEMY_UID_BASE + 0), "늑대가 제 조각을 잡고 있다 (자가 점검)")
	b.enemy_hp[0] = Rules.damage_of(Rules.SWORDSMAN)
	b.step(FIRST_BLOW_SEC)
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
	b.step(FIRST_BLOW_SEC)
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


# == the doorstep turns out new bodies ================================================================

## **`recruit` stands one more 검사 beside the 성채 — and NOTHING ELSE DOES.**
##
## ⚠⚠ **THE TWENTY-SECOND CLOCK IS DELETED** (2026-09-02, the user: 「자동 병사 생성 지워줘」). Until then
## the 성채 turned out a body every `MUSTER_PERIOD_SEC` with nobody pressing anything; now a body appears
## only when the door is called, and today nothing in `src/` calls it (티켓 02-09 deferred the picture).
## **The first check below is the deletion itself**: time alone must stand nobody.
##
## ⚠ **Landlocked** (`LAND`): a board with a coast lands 늑대 inside twenty seconds, and the row would
## be measuring a fight instead of the door.
func _the_keep_turns_out_a_new_swordsman(t) -> void:
	var b := _battle_on(_grid(LAND), _keep(), ISLE_MUSTER)
	var opened := b.living_soldier_count()
	t.eq(opened, Rules.SWORDSMAN_START_COUNT, "판이 시작 인원으로 열린다 (자가 점검)")

	# ⚠⚠ **THE FLOOR, AND IT IS THE WHOLE POINT.** Sixty seconds is three of the old periods; a clock
	# that survived anywhere in the sim puts three bodies here.
	b.step(60.0)
	t.eq(b.living_soldier_count(), opened, "육십 초가 지나도 아무도 안 늘어난다 — 자동 생성이 없다")
	t.eq(b.army.type_id.size(), opened, "명부도 그대로다")

	var fresh := b.recruit(Rules.MUSTER_SLOT)
	t.eq(fresh, opened, "문을 부르면 하나 나온다, 명부의 다음 줄로")
	t.eq(b.living_soldier_count(), opened + 1, "산 검사가 하나 늘었다")
	t.eq(b.army.type_id.size(), opened + 1, "명부에도 한 줄 늘었다")
	t.eq(int(b.soldier_state[fresh]), Battle.SoldierState.ASHORE, "그 몸은 판 위에 서 있다")
	t.eq(b.soldier_hp[fresh], b.army.max_hp_of(fresh), "그리고 체력이 꽉 차 있다")
	var gap := _keep_gap(b, b.soldier_pos[fresh])
	t.ok(gap <= 2.0, "선 자리가 성채 옆이다 (%.2f 조각)" % gap)
	t.ok(b.grid.holds(b._tile_of(b.soldier_pos[fresh]), fresh), "그리고 그 조각을 제 이름으로 잡는다")
	t.eq(int(b.army.slot_id[fresh]), Rules.MUSTER_SLOT, "성채가 뽑는 칸은 정해진 그 칸이다")
	t.eq(int(b.army.type_id[fresh]), Rules.SWORDSMAN, "그래서 나오는 것은 검사다")
	_columns_are_level(t, b, "새로 뽑은 뒤")

	# ⚠ **No clock between two calls** — the second body stands in the same sub-step as the call.
	t.eq(b.recruit(Rules.MUSTER_SLOT), opened + 1, "바로 다시 부르면 둘째가 바로 나온다 — 기다리는 시계가 없다")
	t.eq(b.living_soldier_count(), opened + 2, "산 검사가 둘 늘었다")

	# ⚠⚠ **NO DOORSTEP, NO RECRUITING.** Every net fixture in this repo but one hands the fight a board
	# with no house, and a doorstep of -1 must be a refusal rather than a body standing at 조각 -1.
	var c := _battle_on(_grid(LAND), _keep(), -1)
	var rows := c.army.type_id.size()
	t.eq(c.recruit(Rules.MUSTER_SLOT), -1, "문간이 없는 판에서는 불러도 거절이다")
	t.eq(c.army.type_id.size(), rows, "그리고 명부가 그대로다 — 아무것도 안 변했다")

	# ⚠ **An unbound slot fields nobody, and the refusal happens before a single column grows.**
	# Appending the columns first and asking `Army` second is the shape that leaves a row of type -1
	# on the board: alive, countable, and with no stats and no picture.
	var d := _battle_on(_grid(LAND), _keep(), ISLE_MUSTER)
	var before := d.army.type_id.size()
	t.eq(d.recruit(d.army.slot_count()), -1, "빈 칸은 아무도 안 내놓는다")
	t.eq(d.army.type_id.size(), before, "명부가 그대로다")
	t.eq(d.soldier_state.size(), before, "그리고 판 쪽 칸도 그대로다 — 반쯤 만들다 만 몸이 없다")
	_columns_are_level(t, d, "거절당한 뒤")


## **Nine and no more — the door refuses past the ceiling, and a refusal leaves no row behind.**
func _the_recruiting_stops_at_the_ceiling(t) -> void:
	var b := _battle_on(_grid(LAND), _keep(), ISLE_MUSTER)
	# ⚠⚠ **THE OPENING WATCH IS STOOD FIRST, EXACTLY AS `Run` STANDS IT.** Left in reserve, the row
	# would fill the ceiling with five bodies instead of nine and **the crowding around the house would
	# never happen** — which is the one thing the ticket asks to be confirmed rather than assumed.
	for i in b.army.type_id.size():
		b.stand_at_keep(i)
	var opened := b.living_soldier_count()
	t.eq(b.ashore_ids().size(), opened, "시작 인원이 전부 성채 옆에 서 있다 (자가 점검)")
	t.ok(opened < Rules.MUSTER_CAP,
		"시작 인원이 천장보다 적다 (자가 점검 — %d < %d)" % [opened, Rules.MUSTER_CAP])

	# ⚠ **Four calls past what the ceiling needs**: a row that stopped calling the moment the ceiling
	# was reached cannot tell a limit from a coincidence.
	var stood := 0
	for _n in Rules.MUSTER_CAP + 4:
		if b.recruit(Rules.MUSTER_SLOT) >= 0:
			stood += 1
	t.eq(stood, Rules.MUSTER_CAP - opened, "천장까지만 받는다 — 그 뒤의 부름은 전부 거절이다")
	t.eq(b.living_soldier_count(), Rules.MUSTER_CAP, "천장에서 멈춘다")
	t.eq(b.army.type_id.size(), Rules.MUSTER_CAP, "명부에도 그만큼뿐이다 — 거절이 줄을 안 남겼다")
	_columns_are_level(t, b, "천장에서")

	# ⚠⚠ **THE 성채's OWN 블록 ADMITS EIGHT AND NOT NINE** — the house fills one 조각 whole — so the
	# ninth body has to stand FURTHER OUT rather than not stand at all. **Measured here rather than
	# assumed**: a refusal would have left a row on the roster with nothing on the board, and the
	# ceiling would still have read as nine.
	t.eq(b.ashore_ids().size(), Rules.MUSTER_CAP, "아홉이 전부 판 위에 서 있다 — 아홉째도 밀려나 선다")
	for i in b.soldier_state.size():
		var tile := b._tile_of(b.soldier_pos[i])
		t.ok(b.grid.holds(tile, i), "%d 번이 제 조각을 제 이름으로 잡는다" % i)
		t.ok(_keep_gap(b, b.soldier_pos[i]) <= 4.0, "%d 번이 성채 언저리에 있다" % i)

	# The door refuses at the ceiling, and changes nothing when it does.
	var rows := b.army.type_id.size()
	t.eq(b.recruit(Rules.MUSTER_SLOT), -1, "천장에서는 불러도 거절이다")
	t.eq(b.army.type_id.size(), rows, "그리고 명부가 그대로다")
	t.eq(b.soldier_state.size(), rows, "판 쪽 칸도 그대로다")


## **Nowhere to stand is a refusal, and the same call succeeds the moment there is room.** A door that
## appended the row first and looked for a 조각 second would leave a body on the roster, counted against
## the ceiling, and never on the board.
func _a_recruit_with_nowhere_to_stand_is_refused(t) -> void:
	var g := Grid.new()
	g.load_rows(BOXED, BOXED_TIERS)
	var keep := PackedInt32Array()
	keep.append(BOXED_KEEP)
	var b := _battle_on(g, keep, BOXED_KEEP)
	var opened := b.living_soldier_count()
	var rows := b.army.type_id.size()

	t.eq(b.recruit(Rules.MUSTER_SLOT), -1, "설 자리가 없으면 거절이다")
	t.eq(b.living_soldier_count(), opened, "아무도 안 섰다")
	t.eq(b.army.type_id.size(), rows, "명부에도 안 올랐다 — 거절이 줄을 안 남긴다")
	_columns_are_level(t, b, "막힌 판에서 거절당한 뒤")

	# ⚠⚠ **THE INVERSION.** Open the ground and the same call stands exactly one body.
	b.grid.release_all(Battle.KEEP_UID)
	t.ok(b.recruit(Rules.MUSTER_SLOT) >= 0, "자리가 나면 같은 부름이 하나 세운다")
	t.eq(b.living_soldier_count(), opened + 1, "산 검사가 하나 늘었다")
	t.eq(b.army.type_id.size(), rows + 1, "명부에 한 줄 늘었다")
	_columns_are_level(t, b, "막힌 판에서")


## **Every column this file indexes by 검사 is the same length as the roster.** A column left short is
## not a wrong number — it is an out-of-range read on the first sub-step that touches the new body.
##
## ⚠⚠ **THE NAMES ARE READ OFF THE OBJECT AND NEVER TYPED HERE, AND THAT IS THE WHOLE FIX.** This
## helper used to hold a written-out list of fourteen, which was a second copy of the list `recruit`
## appends — so when 05-07 added 허기's column and 05-05 added 채집's, **both copies missed both, and
## the check that existed to catch a short column went green over two of them.** A list typed twice
## drifts in the same direction on the same day. `get_property_list` cannot.
func _columns_are_level(t, b: Battle, when: String) -> void:
	_columns_match(t, b, ["soldier_", "_soldier_"], b.army.type_id.size(), "명부", when, _SOLDIER_COLUMNS)


## **The beast side of the same sweep**, against the length `land_beast` grows. Same reason, same shape:
## the landing appends its own list and nothing else was reading it back.
func _enemy_columns_are_level(t, b: Battle, when: String) -> void:
	_columns_match(t, b, ["enemy_", "_enemy_"], b.enemy_type.size(), "짐승 줄 수", when, _ENEMY_COLUMNS)


## Sizes of every array-valued property on `b` whose name starts with one of `prefixes`, each against
## `rows`.
##
## ⚠⚠ **THE COUNT IS PINNED BECAUSE A SWEEP THAT MATCHES NOTHING IS GREEN.** A prefix typo, a rename,
## or `get_property_list` answering differently would leave this loop running zero times and reporting
## a clean pass — `how-nets-lie` carries that exact shape ("a loop whose condition is false from the
## start never runs the check at all"). **`least` is a floor and not a census**: it rises when a column
## is added, and it is lowered only when one is genuinely deleted.
func _columns_match(t, b: Battle, prefixes: Array, rows: int, of_what: String, when: String, least: int) -> void:
	var found := 0
	for prop: Dictionary in b.get_property_list():
		var col := String(prop["name"])
		var mine := false
		for pre: String in prefixes:
			if col.begins_with(pre):
				mine = true
		if not mine:
			continue
		var val: Variant = b.get(col)
		if not _ARRAY_TYPES.has(typeof(val)):
			continue
		found += 1
		t.eq(int(val.size()), rows, "%s — %s 가 %s와 같은 길이다" % [when, col, of_what])
	t.ok(found >= least, "%s — %s 로 시작하는 칸을 %d 개 훑었다 (바닥 %d)"
		% [when, String(prefixes[0]), found, least])


# == the keep burns ===================================================================================

## **The 성채 takes the table's damage and the run is lost when it reaches zero.**
func _the_keep_burns_and_the_run_is_lost(t) -> void:
	var b := _at_the_keep()
	t.eq(b.keep_hp, Rules.KEEP_MAX_HP, "성채가 꽉 차 있다 (자가 점검)")
	t.ok(not b.lost, "그리고 아직 안 졌다")
	t.eq(b.boat_pos.size(), 0, "이 판에는 바다가 없어서 배가 안 온다 (자가 점검 — 한 마리만 잰다)")

	b.step(FIRST_BLOW_SEC)
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
	var total := _first_hull_sec() + _crossing_sec() + 12.0
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

	b.step(FIRST_BLOW_SEC)
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


# == noticing =========================================================================================
## Ticket 07-01: **two bodies that come near each other stop walking past.** A 검사 names the nearest
## 늑대 inside `Rules.detect_of(SWORDSMAN)`; a 늑대 still walking names the nearest 검사 inside
## `Rules.detect_of(WOLF)` and walks at him. ⚠ **Nothing new gets hit** — both blow gates stay at
## `reach_of`, so every row here that reads HP is reading a body that WALKED into reach.

## **The complaint, measured.** The user watched a 검사 and a 늑대 pass within two 조각 of each other
## and walk on (2026-09-02). **2.236 and not 2.5**: bodies snap to integer centres, so a gap is
## `sqrt(dx² + dy²)` over integers and 6.25 is not a sum of two squares — (1, 2) is the attainable gap
## nearest 「두 조각」 that sits above reach 1.75 and below both detect radii.
## ⚠ **No 성채 on the board**, so the 늑대 has nothing else to walk at — before this ticket it froze
## here, which is exactly the half a careless edit of the movement gate drops (`anchor < 0` alone is
## not 「stand」).
func _two_bodies_that_come_near_each_other_stop_walking_past(t) -> void:
	var b := _battle_on(_grid(ISLE), PackedInt32Array(), -1)
	t.eq(b.place_ashore(0, b.grid.tile_index(2, 2)), b.grid.tile_index(2, 2), "검사가 (2,2) 에 섰다 (자가 점검)")
	var who := b.land_beast(Rules.WOLF, b.grid.tile_index(3, 4))
	t.eq(b._tile_of(b.enemy_pos[who]), b.grid.tile_index(3, 4), "늑대가 (3,4) 에 섰다 (자가 점검)")
	var gap := b._dist(b.soldier_pos[0], b.enemy_pos[who])
	t.ok(absf(gap - sqrt(5.0)) <= NEAR, "둘 사이가 2.236 조각이다 (자가 점검 — %.3f)" % gap)
	# The gap sits in the one band this ticket is about: above both reaches, below both detects.
	# ⚠ Derived from `Rules`, so a detect that shrinks under 2.236 reddens this line and not the fight.
	t.ok(gap > Rules.reach_of(Rules.SWORDSMAN) + Rules.EPS and gap > Rules.reach_of(Rules.WOLF) + Rules.EPS,
		"그 거리는 둘 다의 사거리 밖이다 (자가 점검)")
	t.ok(gap < Rules.detect_of(Rules.SWORDSMAN) and gap < Rules.detect_of(Rules.WOLF),
		"그리고 둘 다의 탐지 반경 안이다 (자가 점검 — 검사 %.1f · 늑대 %.1f)"
			% [Rules.detect_of(Rules.SWORDSMAN), Rules.detect_of(Rules.WOLF)])
	t.ok(Rules.detect_of(Rules.SWORDSMAN) < Rules.detect_of(Rules.WOLF),
		"사냥꾼이 먼저 알아챈다 — 늑대의 탐지가 검사의 것보다 넓다")

	# **Aiming is not hitting.** One sub-step: both target columns name each other and nobody has bled.
	# The 늑대 covers at most `speed / 60` in that sub-step and the 검사 does not move, so the pair is
	# still outside 1.75 — a blow here would be a hit from further than the rule allows.
	b.step(Rules.SIM_SUBSTEP_SEC)
	t.eq(int(b.soldier_target[0]), who, "한 서브스텝에 검사가 늑대를 겨눈다")
	t.eq(int(b.enemy_target[who]), 0, "그리고 늑대도 검사를 겨눈다")
	var gap1 := b._dist(b.soldier_pos[0], b.enemy_pos[who])
	t.ok(gap1 > Rules.reach_of(Rules.WOLF) + Rules.EPS,
		"그런데 아직 사거리 밖이다 (자가 점검 — %.3f)" % gap1)
	t.eq(b.soldier_hp[0], b.army.max_hp_of(0), "그래서 검사는 안 깎였다 — 겨눈 것이지 때린 것이 아니다")
	t.eq(b.enemy_hp[who], Rules.hp_of(Rules.WOLF), "늑대도 안 깎였다")

	# **And then they fight.** ⚠ Read HP and never `enemy_alive`: the 검사's third blow lands at about
	# 4.9 s, a margin of one tenth of a second on a 5 s read. Before this ticket both stood at full HP.
	b.step(5.0 - Rules.SIM_SUBSTEP_SEC)
	t.ok(float(b.soldier_hp[0]) < b.army.max_hp_of(0),
		"5초 뒤 검사가 꽉 찬 체력이 아니다 — 늑대가 걸어와서 물었다 (%.1f)" % float(b.soldier_hp[0]))
	t.ok(float(b.enemy_hp[who]) < Rules.hp_of(Rules.WOLF),
		"늑대도 꽉 찬 체력이 아니다 — 검사가 받아쳤다 (%.1f)" % float(b.enemy_hp[who]))


## **A defender pulls a landed 늑대 off its line to the 성채.** The control beside
## `_the_beasts_walk_at_the_keep_and_stop_in_reach`, which survives this ticket only because no 검사 is
## ever ashore on it — without this row 「beasts walk at the 성채」 and 「beasts notice a defender」 are
## one untested pair.
##
## ⚠⚠ **MEASURED OVER THREE SECONDS AND NOT ONE STEP.** The first draft read 「its position moves on the
## next step」, and that is green for the freeze: a 늑대 whose target is set but whose walk is gated
## off still glides out the 조각 it reserved, up to 1.414. **A gap that closes by more than three and a
## 검사 who was hit are what a glide-out cannot produce.**
## ⚠ **`keep_hp` still full is the discriminating read against the code before this ticket**, which
## had the 늑대 at the wall by 0.5 s and the 성채 at 112 by 3 s.
func _a_defender_pulls_a_landed_wolf_off_its_line(t) -> void:
	var b := _battle_on(_grid(LAND), _keep(), ISLE_MUSTER)
	var who := b.land_beast(Rules.WOLF, b.grid.tile_index(2, 2))
	t.eq(b._tile_of(b.enemy_pos[who]), b.grid.tile_index(2, 2), "늑대가 (2,2) 에 내렸다 (자가 점검)")
	var wall := _keep_gap(b, b.enemy_pos[who])
	t.ok(wall > Rules.reach_of(Rules.WOLF) + Rules.EPS,
		"성채까지 %.2f 조각 — 사거리 밖이라 검사가 없으면 집으로 걷는다 (자가 점검)" % wall)
	t.eq(b.place_ashore(0, b.grid.tile_index(2, 7)), b.grid.tile_index(2, 7), "검사가 (2,7) 에 섰다 (자가 점검)")
	var gap0 := b._dist(b.enemy_pos[who], b.soldier_pos[0])
	t.ok(absf(gap0 - 5.0) <= NEAR, "둘 사이가 5.0 조각이다 (자가 점검 — %.3f)" % gap0)
	t.ok(gap0 < Rules.detect_of(Rules.WOLF) and gap0 > Rules.detect_of(Rules.SWORDSMAN),
		"늑대의 탐지 안, 검사의 탐지 밖이다 (자가 점검)")

	b.step(Rules.SIM_SUBSTEP_SEC)
	t.eq(int(b.enemy_target[who]), 0, "한 서브스텝에 늑대가 검사를 겨눈다")
	t.eq(b.keep_hp, Rules.KEEP_MAX_HP, "그리고 성채는 멀쩡하다")

	b.step(3.0 - Rules.SIM_SUBSTEP_SEC)
	var gap1 := b._dist(b.enemy_pos[who], b.soldier_pos[0])
	t.ok(gap1 <= Rules.reach_of(Rules.WOLF) + Rules.speed_of(Rules.WOLF) * Rules.SIM_SUBSTEP_SEC + NEAR,
		"3초 뒤 늑대가 검사의 사거리 안까지 와 있다 (%.2f -> %.2f)" % [gap0, gap1])
	t.ok(gap0 - gap1 > 3.0, "사이가 세 조각 넘게 좁혀졌다 — 예약한 조각을 마저 밟는 것으로는 안 나오는 값이다")
	t.ok(float(b.soldier_hp[0]) < b.army.max_hp_of(0),
		"그리고 검사가 물렸다 (%.1f) — 늑대가 실제로 걸어왔다" % float(b.soldier_hp[0]))
	t.eq(b.keep_hp, Rules.KEEP_MAX_HP, "성채는 그동안 한 대도 안 맞았다 — 늑대가 집이 아니라 사람에게 갔다")


## **[A] A 늑대 at the wall keeps the wall.** The user's answer 1 on 07-01 (2026-09-02): a 늑대 that can
## already hit the 성채 is NOT pulled off by a 검사 three 조각 away — the detect tier sits BELOW the
## wall. ⚠⚠ **This is the tripwire the HELD block said did not exist**: written 검사-first, the loss
## condition leaves the board and this row goes red on its first read, while the two burn rows stay
## green because nothing on them ever stands a 검사.
##
## Three reads, and each is the inversion of a rule the other two would let through:
##  · the wall holds its 늑대 — red for 「검사 first」
##  · the wall takes a 늑대 walking past it — red for 「성채 only when no 검사 is seen」
##  · a 검사 at arm's length still outranks the wall — red for 「the wall beats everything」
func _a_wolf_at_the_wall_keeps_the_wall(t) -> void:
	var b := _at_the_keep()
	var wall := _keep_gap(b, b.enemy_pos[0])
	t.ok(wall <= Rules.reach_of(Rules.WOLF), "늑대가 성채 사거리 안에 서 있다 (자가 점검 — %.2f)" % wall)
	t.eq(b.place_ashore(0, ISLE_MUSTER), ISLE_MUSTER, "검사가 문간 (7,4) 에 섰다 (자가 점검)")
	var gap := b._dist(b.enemy_pos[0], b.soldier_pos[0])
	t.ok(absf(gap - 3.0) <= NEAR, "늑대와 검사가 평지에서 3.0 조각이다 (자가 점검 — %.3f)" % gap)
	t.ok(gap <= Rules.detect_of(Rules.SWORDSMAN) + Rules.EPS and gap <= Rules.detect_of(Rules.WOLF),
		"둘 다의 탐지 안이다 (자가 점검)")
	var parked: Vector2 = b.enemy_pos[0]

	b.step(Rules.SIM_SUBSTEP_SEC)
	t.eq(int(b.enemy_target[0]), Battle.TARGET_KEEP,
		"한 서브스텝에 늑대가 겨누는 것은 성채다 — 세 조각 밖의 검사가 아니다")
	t.eq(int(b.soldier_target[0]), 0, "검사 쪽은 그 늑대를 겨눈다 — 3.0 은 제 탐지 안이다")
	# The swing was thrown on that sub-step; the blow lands `Rules.SWING_LAND_SEC` later (03-19,
	# merged 2026-09-03 after this row was written against the instant blow).
	b.step(Rules.SWING_LAND_SEC)
	t.ok(absf(b.keep_hp - (Rules.KEEP_MAX_HP - Rules.damage_of(Rules.WOLF))) <= HP_NEAR,
		"그리고 성채가 한 대 맞았다 (%.1f)" % b.keep_hp)

	# Swings at 0, 2 and 4 s land at 0.4, 2.4 and 4.4 — the burn row's own arithmetic over five seconds.
	b.step(5.0 - Rules.SIM_SUBSTEP_SEC - Rules.SWING_LAND_SEC)
	var blows := int(floor(5.0 / Rules.period_of(Rules.WOLF))) + 1
	t.eq(int(b.enemy_target[0]), Battle.TARGET_KEEP, "5초 뒤에도 성채다")
	t.ok(absf(b.keep_hp - (Rules.KEEP_MAX_HP - float(blows) * Rules.damage_of(Rules.WOLF))) <= HP_NEAR,
		"성채가 %d 대 맞았다 (%.1f)" % [blows, b.keep_hp])
	t.eq(b.soldier_hp[0], b.army.max_hp_of(0), "검사는 꽉 찬 체력이다 — 늑대가 그에게 안 갔다")
	t.ok((b.enemy_pos[0] as Vector2).distance_to(parked) <= NEAR,
		"그리고 늑대가 그 자리에서 안 움직였다 (%.5f)" % (b.enemy_pos[0] as Vector2).distance_to(parked))

	# **The wall takes a 늑대 walking past it.** Landed at (2,4): 3.0 from the house (outside reach),
	# 5.0 from the doorstep (inside 6.0). It notices the man and sets off; the house sits between them
	# and the wall-in-reach clause catches it on the way. ⚠ An order written 「성채 only when no 검사 is
	# seen」 is green on the read above and red here.
	var c := _battle_on(_grid(LAND), _keep(), ISLE_MUSTER)
	var walker := c.land_beast(Rules.WOLF, c.grid.tile_index(2, 4))
	t.eq(c._tile_of(c.enemy_pos[walker]), c.grid.tile_index(2, 4), "늑대가 (2,4) 에 내렸다 (자가 점검)")
	t.ok(_keep_gap(c, c.enemy_pos[walker]) > Rules.reach_of(Rules.WOLF) + Rules.EPS,
		"거기서는 성채가 사거리 밖이다 (자가 점검 — %.2f)" % _keep_gap(c, c.enemy_pos[walker]))
	c.place_ashore(0, ISLE_MUSTER)
	var far := c._dist(c.enemy_pos[walker], c.soldier_pos[0])
	t.ok(far > Rules.reach_of(Rules.WOLF) and far < Rules.detect_of(Rules.WOLF),
		"검사는 %.1f 조각 — 사거리 밖, 탐지 안이다 (자가 점검)" % far)
	c.step(Rules.SIM_SUBSTEP_SEC)
	t.eq(int(c.enemy_target[walker]), 0, "한 서브스텝에 늑대가 검사를 겨눈다 — 걷는 중이라 알아챈다")
	c.step(3.0 - Rules.SIM_SUBSTEP_SEC)
	t.eq(int(c.enemy_target[walker]), Battle.TARGET_KEEP,
		"3초 뒤에는 성채를 겨눈다 — 가는 길에 벽이 사거리 안에 들어왔다")
	t.ok(c.keep_hp < Rules.KEEP_MAX_HP, "그리고 성채가 깎이고 있다 (%.1f)" % c.keep_hp)
	t.eq(c.soldier_hp[0], c.army.max_hp_of(0), "검사는 꽉 찬 체력이다 — 늑대가 그에게 닿지 않았다")

	# **A 검사 at arm's length still outranks the wall, exactly as before this ticket.** Without this
	# read answer 1 could be built as 「the wall beats everything」 and nothing would say so. ⚠ Read at
	# 3 s and not 5: the 검사's third blow kills the 늑대 at 4.8 s.
	var d := _at_the_keep()
	t.eq(d.place_ashore(0, d.grid.tile_index(4, 3)), d.grid.tile_index(4, 3), "검사가 (4,3) 에 섰다 (자가 점검)")
	var near := d._dist(d.enemy_pos[0], d.soldier_pos[0])
	t.ok(near <= Rules.reach_of(Rules.WOLF), "늑대에서 %.2f 조각 — 사거리 안이다 (자가 점검)" % near)
	t.ok(_keep_gap(d, d.soldier_pos[0]) <= 2.0, "그리고 성채 바로 옆이다 (자가 점검)")
	d.step(3.0)
	t.eq(int(d.enemy_target[0]), 0, "사거리 안의 검사는 벽보다 먼저다 — 이 티켓 전과 같다")
	t.ok(float(d.soldier_hp[0]) < d.army.max_hp_of(0), "그래서 검사가 물렸다 (%.1f)" % float(d.soldier_hp[0]))
	t.eq(d.keep_hp, Rules.KEEP_MAX_HP, "그리고 성채는 안 맞았다")

	# **A 늑대 holding the wall stands where the wall is, and does not walk at the anchor.** The
	# movement gate's 「stand」 for `TARGET_KEEP` is its own clause, and every board above has the 늑대
	# within reach of `keep_tiles[0]` too — so a gate that lets `TARGET_KEEP` fall through to the anchor
	# walk is green on all of them. Here the 늑대 stands at (7,5) on `LAND`: 1.0 from the house's
	# (6,5), 2.236 from its first 조각 (5,4), so that mutant walks it round the house while it is
	# hitting it. ⚠ **Not on the shipped island** — there every 눈금 2 조각 beside the house is (10,11)
	# or (11,11), both inside 1.75 of the anchor, and the flat ring cannot strike 눈금 2 at all.
	var e := _battle_on(_grid(LAND), _keep(), ISLE_MUSTER)
	var east := e.land_beast(Rules.WOLF, e.grid.tile_index(7, 5))
	var post: Vector2 = e.enemy_pos[east]
	t.eq(e._tile_of(post), e.grid.tile_index(7, 5), "늑대가 (7,5) 에 섰다 (자가 점검)")
	t.ok(_keep_gap(e, post) <= Rules.reach_of(Rules.WOLF),
		"거기서 성채가 사거리 안이다 (자가 점검 — %.2f)" % _keep_gap(e, post))
	var to_anchor := e._dist(post, e._point_of_tile(int(e.keep_tiles[0])))
	t.ok(to_anchor > Rules.reach_of(Rules.WOLF) + Rules.EPS,
		"그런데 성채의 첫 조각은 사거리 밖이다 (자가 점검 — %.3f)" % to_anchor)
	e.step(Rules.SIM_SUBSTEP_SEC)
	t.eq(int(e.enemy_target[east]), Battle.TARGET_KEEP, "한 서브스텝에 성채를 겨눈다")
	e.step(3.0 - Rules.SIM_SUBSTEP_SEC)
	var wall_blows := int(floor(3.0 / Rules.period_of(Rules.WOLF))) + 1
	t.ok(absf(e.keep_hp - (Rules.KEEP_MAX_HP - float(wall_blows) * Rules.damage_of(Rules.WOLF))) <= HP_NEAR,
		"3초에 성채가 %d 대 맞았다 (%.1f)" % [wall_blows, e.keep_hp])
	t.ok((e.enemy_pos[east] as Vector2).distance_to(post) <= NEAR,
		"그리고 늑대는 그 자리다 (%.5f) — 첫 조각을 향해 집을 돌지 않는다" % (e.enemy_pos[east] as Vector2).distance_to(post))


## **[B] A blow between bodies crosses no more 눈금 than a body climbs, in both directions.** The user's
## answer 2 on 07-01 (2026-09-02): the body-against-body blow gets the same `Grid.can_strike` guard the
## 성채 blow got in 02-01. ⚠⚠ **The gap was real and unreachable in play**, because a beast only ever
## walked at the 성채 — the chase is what walks it under a plateau, so the guard lands in the same edit.
##
## ⚠ **「0 is ready」 is what makes 5 s a real read**: without the guard the first blow lands on the
## first sub-step, so full HP at 5 s means the guard refused every one of about 150 chances.
## ⚠⚠ **The floor is the 계단 pair at the end** — a guard written 「same 눈금 only」 is green on every
## read above it and red there, and that is the reach-from-a-계단 rule 02-01 refused to give up.
func _a_blow_between_bodies_crosses_no_more_notches_than_a_body_climbs(t) -> void:
	var b := _plateau_no_keep()
	t.eq(b.place_ashore(0, b.grid.tile_index(3, 2)), b.grid.tile_index(3, 2), "검사가 고원 (3,2) 에 섰다 (자가 점검)")
	t.eq(b.grid.level_of(b._tile_of(b.soldier_pos[0])), 2, "그 조각이 눈금 2 다 (자가 점검)")
	var who := b.land_beast(Rules.WOLF, b.grid.tile_index(3, 1))
	t.eq(b._tile_of(b.enemy_pos[who]), b.grid.tile_index(3, 1), "늑대가 바로 북쪽 (3,1) 에 섰다 (자가 점검)")
	t.eq(b.grid.level_of(b._tile_of(b.enemy_pos[who])), 0, "그 조각은 눈금 0 이다 (자가 점검)")
	var gap := b._dist(b.enemy_pos[who], b.soldier_pos[0])
	t.ok(absf(gap - sqrt(2.0)) <= NEAR, "3D 거리가 1.414 다 (자가 점검 — %.3f)" % gap)
	t.ok(gap <= Rules.reach_of(Rules.WOLF) and gap <= Rules.reach_of(Rules.SWORDSMAN),
		"둘 다의 사거리 안이다 — 눈금이 안 막으면 첫 서브스텝에 맞는 거리다 (자가 점검)")
	var s_at: Vector2 = b.soldier_pos[0]
	var e_at: Vector2 = b.enemy_pos[who]

	b.step(Rules.SIM_SUBSTEP_SEC)
	t.eq(int(b.soldier_target[0]), who, "한 서브스텝에 검사가 아래의 늑대를 겨눈다 — 알아채는 데는 높이가 안 막는다")
	t.eq(int(b.enemy_target[who]), 0, "늑대도 위의 검사를 겨눈다")
	t.eq(b.soldier_hp[0], b.army.max_hp_of(0), "그런데 검사는 안 깎였다")
	t.eq(b.enemy_hp[who], Rules.hp_of(Rules.WOLF), "늑대도 안 깎였다")

	b.step(5.0 - Rules.SIM_SUBSTEP_SEC)
	t.eq(b.soldier_hp[0], b.army.max_hp_of(0), "5초 뒤에도 검사가 꽉 찬 체력이다 — 1층에서 고원 위를 못 때린다")
	t.eq(b.enemy_hp[who], Rules.hp_of(Rules.WOLF), "늑대도 꽉 찬 체력이다 — 위에서 아래로도 못 때린다, 규칙이 대칭이다")
	t.eq(int(b.soldier_target[0]), who, "둘은 여전히 서로를 겨눈다")
	t.eq(int(b.enemy_target[who]), 0, "늑대 쪽도")
	t.ok((b.soldier_pos[0] as Vector2).distance_to(s_at) <= NEAR, "검사는 안 움직였다")
	t.ok((b.enemy_pos[who] as Vector2).distance_to(e_at) <= NEAR, "늑대도 안 움직였다 — 사거리 안이라 걷지 않는다")

	# **The floor.** Same pair, the 늑대 on the 계단 tread — 눈금 1, planar 1.0, 3D 1.118 — both bleed.
	var c := _plateau_no_keep()
	t.eq(c.place_ashore(0, c.grid.tile_index(3, 3)), c.grid.tile_index(3, 3), "검사가 고원 (3,3) 에 섰다 (자가 점검)")
	var climber := c.land_beast(Rules.WOLF, c.grid.tile_index(2, 3))
	t.eq(c._tile_of(c.enemy_pos[climber]), c.grid.tile_index(2, 3), "늑대가 계단 (2,3) 에 섰다 (자가 점검)")
	t.eq(c.grid.level_of(c._tile_of(c.enemy_pos[climber])), 1, "그 조각은 눈금 1 이다 (자가 점검)")
	var tread := c._dist(c.enemy_pos[climber], c.soldier_pos[0])
	t.ok(absf(tread - sqrt(1.25)) <= NEAR, "3D 거리가 1.118 다 (자가 점검 — %.3f)" % tread)
	c.step(5.0)
	t.ok(float(c.soldier_hp[0]) < c.army.max_hp_of(0),
		"계단에서는 검사가 물린다 (%.1f) — 눈금 하나는 넘는다" % float(c.soldier_hp[0]))
	t.ok(float(c.enemy_hp[climber]) < Rules.hp_of(Rules.WOLF), "그리고 늑대도 맞는다 (%.1f)" % float(c.enemy_hp[climber]))


## **The reach tier takes the further body it can strike over the nearer one it cannot.** This is the
## `must_strike` flag on the reach tier of BOTH scans, and it is the case the plan gave as the reason
## the flag exists: 「a 검사 on the plateau with a 늑대 below at 1.414 and one on the 계단 at 1.5 would
## stand aiming down forever」. ⚠⚠ **Every other row in this file is green with the flag off** — the
## verifier flipped `true` to `false` on both calls and 419 checks stayed green — because no other
## board has two bodies inside one reach where the NEARER is the unstrikable one. Here it is, twice.
##
## Both halves stand on `PLATEAU` with no 성채: the plateau is (3,2)·(4,2)·(3,3)·(4,3) on 눈금 2 and
## the 계단 tread is (2,3) on 눈금 1. The unstrikable body is landed FIRST, so with the flag off it wins
## on distance AND on the tie-break — the mutant has no way to pick the tread.
## ⚠ **Read at 3 s and not 5**: the 검사's third blow (period 2.4) kills a 늑대 at 4.8 s, and a row that
## reads a dead body's HP is reading the death phase, not the choice.
func _the_reach_tier_takes_the_further_body_it_can_strike_over_the_nearer_it_cannot(t) -> void:
	# **The 검사's scan.** He stands on (3,2); 늑대 A is straight below at (3,1) on 눈금 0 — 3D 1.414,
	# two 눈금 down, unstrikable; 늑대 B is on the tread (2,3) — 3D 1.5, one 눈금 down, strikable.
	var b := _plateau_no_keep()
	t.eq(b.place_ashore(0, b.grid.tile_index(3, 2)), b.grid.tile_index(3, 2), "검사가 고원 (3,2) 에 섰다 (자가 점검)")
	var below := b.land_beast(Rules.WOLF, b.grid.tile_index(3, 1))
	var tread := b.land_beast(Rules.WOLF, b.grid.tile_index(2, 3))
	t.eq(b._tile_of(b.enemy_pos[below]), b.grid.tile_index(3, 1), "늑대 A 가 바로 아래 (3,1) 에 섰다 (자가 점검)")
	t.eq(b._tile_of(b.enemy_pos[tread]), b.grid.tile_index(2, 3), "늑대 B 가 계단 (2,3) 에 섰다 (자가 점검)")
	var d_below := b._dist(b.soldier_pos[0], b.enemy_pos[below])
	var d_tread := b._dist(b.soldier_pos[0], b.enemy_pos[tread])
	t.ok(absf(d_below - sqrt(2.0)) <= NEAR and absf(d_tread - 1.5) <= NEAR,
		"A 는 1.414, B 는 1.5 — A 가 가깝다 (자가 점검 — %.3f · %.3f)" % [d_below, d_tread])
	t.ok(d_tread <= Rules.reach_of(Rules.SWORDSMAN), "둘 다 검사의 사거리 안이다 (자가 점검)")
	t.ok(not b.grid.can_strike(b._tile_of(b.soldier_pos[0]), b._tile_of(b.enemy_pos[below])),
		"A 는 눈금 둘 아래라 못 때린다 (자가 점검)")
	t.ok(b.grid.can_strike(b._tile_of(b.soldier_pos[0]), b._tile_of(b.enemy_pos[tread])),
		"B 는 눈금 하나 아래라 때릴 수 있다 (자가 점검)")

	b.step(Rules.SIM_SUBSTEP_SEC)
	t.eq(int(b.soldier_target[0]), tread,
		"한 서브스텝에 검사가 겨누는 것은 계단의 B 다 — 더 가깝지만 못 때리는 A 가 아니다")
	b.step(3.0 - Rules.SIM_SUBSTEP_SEC)
	t.eq(int(b.soldier_target[0]), tread, "3초 뒤에도 B 다")
	t.ok(float(b.enemy_hp[tread]) < Rules.hp_of(Rules.WOLF),
		"그리고 B 가 깎였다 (%.1f) — 가까운 것을 겨눴으면 아무도 안 맞고 검사만 물린다" % float(b.enemy_hp[tread]))
	t.eq(b.enemy_hp[below], Rules.hp_of(Rules.WOLF), "A 는 꽉 찬 체력이다 — 아무도 A 를 못 때린다")

	# **The 늑대's scan, the same shape upside down.** It stands on the flat at (3,4); 검사 A is straight
	# above at (3,3) on 눈금 2 — 3D 1.414, unstrikable; 검사 B is on the tread (2,3) — 3D 1.5, strikable.
	var c := _plateau_no_keep()
	t.eq(c.place_ashore(0, c.grid.tile_index(3, 3)), c.grid.tile_index(3, 3), "검사 A 가 고원 (3,3) 에 섰다 (자가 점검)")
	t.eq(c.place_ashore(1, c.grid.tile_index(2, 3)), c.grid.tile_index(2, 3), "검사 B 가 계단 (2,3) 에 섰다 (자가 점검)")
	var who := c.land_beast(Rules.WOLF, c.grid.tile_index(3, 4))
	t.eq(c._tile_of(c.enemy_pos[who]), c.grid.tile_index(3, 4), "늑대가 평지 (3,4) 에 섰다 (자가 점검)")
	var w_above := c._dist(c.enemy_pos[who], c.soldier_pos[0])
	var w_tread := c._dist(c.enemy_pos[who], c.soldier_pos[1])
	t.ok(absf(w_above - sqrt(2.0)) <= NEAR and absf(w_tread - 1.5) <= NEAR,
		"A 는 1.414, B 는 1.5 — A 가 가깝다 (자가 점검 — %.3f · %.3f)" % [w_above, w_tread])
	t.ok(w_tread <= Rules.reach_of(Rules.WOLF), "둘 다 늑대의 사거리 안이다 (자가 점검)")
	t.ok(not c.grid.can_strike(c._tile_of(c.enemy_pos[who]), c._tile_of(c.soldier_pos[0])),
		"A 는 눈금 둘 위라 못 때린다 (자가 점검)")

	c.step(Rules.SIM_SUBSTEP_SEC)
	t.eq(int(c.enemy_target[who]), 1, "한 서브스텝에 늑대가 겨누는 것은 계단의 B 다 — 더 가깝지만 못 때리는 A 가 아니다")
	c.step(3.0 - Rules.SIM_SUBSTEP_SEC)
	t.eq(int(c.enemy_target[who]), 1, "3초 뒤에도 B 다")
	t.ok(float(c.soldier_hp[1]) < c.army.max_hp_of(1),
		"그리고 B 가 물렸다 (%.1f) — 가까운 것을 겨눴으면 늑대는 아무도 못 문다" % float(c.soldier_hp[1]))
	t.eq(c.soldier_hp[0], c.army.max_hp_of(0), "A 는 꽉 찬 체력이다 — 아무도 A 를 못 문다")


## **[stands] A 늑대 whose target it cannot strike walks to the stop distance and stands.** Also the
## measurement of the Risk line 「a path to something unreachable」: a field to a 눈금 2 조각 is asked
## for by a body on 눈금 0, and the body neither spins nor stalls.
##
## Derived on the field, not guessed: the field from (3,2) reaches the flat only through the 계단 at
## (2,3), so from (3,0) the cheapest neighbour is (2,1), which is 1.732 from the 검사 — inside 1.75. The
## 늑대 walks one diagonal and the stop test ends the walk on the flat; the 계단 is two field steps
## further and it never gets there.
## ⚠⚠ **The level read is the discriminating one**: a 늑대 that reached the 계단 would be at 눈금 1,
## 1.5 from him, and would land a blow — which is the 07-02 chase arriving early, not this ticket.
func _a_wolf_that_cannot_strike_its_target_walks_up_and_stands(t) -> void:
	var b := _plateau_no_keep()
	t.eq(b.place_ashore(0, b.grid.tile_index(3, 2)), b.grid.tile_index(3, 2), "검사가 고원 (3,2) 에 섰다 (자가 점검)")
	var who := b.land_beast(Rules.WOLF, b.grid.tile_index(3, 0))
	var began: Vector2 = b.enemy_pos[who]
	t.eq(b._tile_of(began), b.grid.tile_index(3, 0), "늑대가 (3,0) 에 섰다 (자가 점검)")
	var gap0 := b._dist(began, b.soldier_pos[0])
	t.ok(absf(gap0 - sqrt(5.0)) <= NEAR, "3D 거리가 2.236 다 (자가 점검 — %.3f)" % gap0)
	t.ok(gap0 > Rules.reach_of(Rules.WOLF) and gap0 < Rules.detect_of(Rules.WOLF),
		"사거리 밖, 탐지 안이다 (자가 점검)")

	b.step(Rules.SIM_SUBSTEP_SEC)
	t.eq(int(b.enemy_target[who]), 0, "한 서브스텝에 늑대가 검사를 겨눈다 — 못 때리는 것도 알아채기는 한다")

	b.step(1.0 - Rules.SIM_SUBSTEP_SEC)
	var at1: Vector2 = b.enemy_pos[who]
	t.ok(at1.distance_to(began) > 1.0,
		"1초 뒤 (3,0) 에서 한 조각 넘게 떨어져 있다 — 걸었다 (%.3f)" % at1.distance_to(began))
	var gap1 := b._dist(at1, b.soldier_pos[0])
	t.ok(gap1 <= Rules.reach_of(Rules.WOLF) + NEAR, "그리고 검사까지 사거리 거리 안에 서 있다 (%.3f)" % gap1)
	t.eq(b.grid.level_of(b._tile_of(at1)), 0, "눈금 0 이다 — 계단도 고원도 아니다, 평지에서 올려다본다")

	b.step(4.0)
	t.ok((b.enemy_pos[who] as Vector2).distance_to(at1) <= NEAR,
		"5초 뒤에도 그 자리다 (%.5f) — 돌지도 떨지도 않는다" % (b.enemy_pos[who] as Vector2).distance_to(at1))
	t.eq(int(b.enemy_target[who]), 0, "여전히 검사를 겨눈다")
	t.eq(int(b.soldier_target[0]), who, "검사도 아래의 늑대를 겨눈다 — 1.732 는 제 탐지 안이다")
	t.eq(b.soldier_hp[0], b.army.max_hp_of(0), "그런데 아무도 못 때린다 — 검사가 꽉 찬 체력이다")
	t.eq(b.enemy_hp[who], Rules.hp_of(Rules.WOLF), "늑대도 꽉 찬 체력이다")
	# **It stood the way a stopped body stands: on a 조각 centre, holding that one 조각.** The stop test
	# ends the walk at 1.75 from the 검사, which is 0.18 조각 SHORT of the (2,1) centre — so a gate that
	# keeps calling `_walk` on a body already in reach leaves it there mid-조각 forever, never settled,
	# still holding (3,0) behind it. ⚠ The reads above are green for that mutant: it walked more than
	# 1.0, it is on 눈금 0, and it does not move again. **These two are what the mutant cannot produce.**
	var stood: Vector2 = b.enemy_pos[who]
	var centre := b._point_of_tile(b._tile_of(stood))
	t.ok(stood.distance_to(centre) <= NEAR,
		"그리고 조각 한가운데 서 있다 (%.3f) — 예약한 조각을 다 건너고 섰다, 중간에서 얼어붙은 게 아니다" % stood.distance_to(centre))
	t.eq(b.grid.hold_count(b.grid.tile_index(3, 0)), 0,
		"내렸던 (3,0) 은 놓았다 — 선 몸이 뒤의 조각까지 잡고 있으면 목이 절반이 된다")
	t.ok(b.grid.holds(b._tile_of(stood), Battle.ENEMY_UID_BASE + who), "선 조각 하나만 잡고 있다")


## **A chase builds one field per 조각 the target crosses, and not one per sub-step.** The flow field,
## not the scan, is what a chase costs — `Battle.field_to` records one field at about 3.7 ms on the
## shipped island and `Battle.FIELD_TTL` retires it after 0.5 s, so the number that matters is how
## many distinct keys a chase asks for and how often they rebuild.
##
## ⚠ **Counted off `_field_age` and not off key presence.** A key that expires and is rebuilt inside
## one sub-step — which is every rebuild a beast asks for, since `_age_fields` and `_walk` run in the
## same phase — is present at both samples, so 「a key that was not there the sub-step before」 misses
## it. An age that went DOWN between two samples is a rebuild, and a key that was absent is a build.
## ⚠ **The distinct-key count is the discriminating read** (2 before this ticket against about 8
## after); the build count is the bound that catches a key written off the 검사's position instead of
## his 조각, which would build sixty times a second. **Timing is printed, never asserted** — a timing
## assert is flaky across machines and the counts are the deterministic half.
func _a_chase_builds_one_field_per_piece_the_target_crosses(t) -> void:
	var g := _real()
	var b := _battle_on(g, Islands.keep_tiles(), Islands.beside_home_tile(g.w))
	var start := g.tile_index(4, 14)
	var dest := g.tile_index(4, 8)
	t.eq(b.place_ashore(0, start), start, "검사가 (4,14) 에 섰다 (자가 점검)")
	var who := b.land_beast(Rules.WOLF, g.tile_index(9, 14))
	t.eq(b._tile_of(b.enemy_pos[who]), g.tile_index(9, 14), "늑대가 (9,14) 에 섰다 (자가 점검)")
	var gap := b._dist(b.enemy_pos[who], b.soldier_pos[0])
	t.ok(absf(gap - 5.0) <= NEAR, "둘 사이가 5.0 조각이다 (자가 점검 — %.3f)" % gap)
	t.ok(is_inf(b.keep_gap(b.enemy_pos[who])), "거기서는 성채를 못 때린다 — 눈금 2 아래다 (자가 점검)")
	# Six 조각 straight north, all on 눈금 0 with no 계단 in the column — read off the island file.
	for y in range(8, 15):
		t.eq(g.level_of(g.tile_index(4, y)), 0, "(4,%d) 는 눈금 0 이다 (자가 점검)" % y)
	t.ok(b.order_walk(0, dest), "검사를 (4,8) 로 보낸다 (자가 점검)")

	var ages := {}
	var seen := {}
	var builds := _count_builds(b, ages, seen)
	for _i in int(round(3.0 / Rules.SIM_SUBSTEP_SEC)):
		b.step(Rules.SIM_SUBSTEP_SEC)
		builds += _count_builds(b, ages, seen)
	# One field timed on the same grid, carried in a label — never asserted: a timing assert is flaky
	# across machines. ⚠ It rides on a real check rather than on `us >= 0`, which no duration fails.
	var t0 := Time.get_ticks_usec()
	g.flow_field(dest)
	var us := Time.get_ticks_usec() - t0
	t.ok(seen.size() >= 5,
		"3초 동안 서로 다른 흐름장 열쇠가 %d 개다 — 검사가 건넌 조각마다 하나 (이 티켓 전에는 2)" % seen.size())
	t.ok(builds <= 30,
		"그동안 흐름장을 %d 번 지었다 — 초당 예순 번이 아니다 (이 판에서 하나가 %d us — 보고만 한다)" % [builds, us])
	t.ok(builds >= seen.size(), "지은 횟수가 열쇠 수 이상이다 (자가 점검)")


## **[watch] The shipped island's first wave meets the watch at the door.** The only row in this file on
## the board the player actually plays: four 검사 stood by `stand_at_keep` exactly as `Run.begin_island`
## and `_stand_the_watch` stand them, the first boat landed, thirty seconds read.
##
## ⚠⚠ **Measured 2026-09-02 on the code before this ticket**: the four 늑대 climbed the 계단, crossed the
## plateau, came down the spine to 1.0 from the wall on 눈금 2, and the run was LOST at 38.98 s with the
## watch never targeting anything. **After**: each 늑대 comes inside 6.0 of a 검사 at the plateau's edge,
## the field to the door leads back down the 계단, and it paces between (8,8) and (9,9) — the wave that
## burned past the watch now goes after the watch and never arrives.
## ⚠⚠ **It is not a claim that the picture is right.** Four 늑대 pacing while the 성채 stands untouched
## is the 07-02 leash question arriving on the opening frame, and it is the user's off the screenshot.
## **The row is rewritten the day the rule that produces the pacing changes.**
## ⚠ **Positions and 눈금 are printed, never asserted** — a row that pinned the exact 조각 would go red
## on a reservation jam between four bodies on two 조각 while measuring nothing the reads missed.
func _the_shipped_island_s_first_wave_meets_the_watch_at_the_door(t) -> void:
	var g := _real()
	var b := _battle_on(g, Islands.keep_tiles(), Islands.beside_home_tile(g.w))
	for i in b.army.type_id.size():
		b.stand_at_keep(i)
	# The board, self-checked against the island file.
	var door := g.tile_index(10, 14)
	t.eq(b.muster_tile, door, "문간이 (10,14) 다 (자가 점검)")
	t.eq(g.level_of(door), 0, "문간이 눈금 0 이다 (자가 점검)")
	t.eq(b.ashore_ids().size(), Rules.SWORDSMAN_START_COUNT, "검사 넷이 판 위에 서 있다 (자가 점검)")
	t.eq(g.hold_count(door), Rules.TILE_CAPACITY, "문간 조각에 셋이 선다 (자가 점검)")
	var elsewhere := []
	for raw in b.ashore_ids():
		var tile := b._tile_of(b.soldier_pos[int(raw)])
		if tile != door:
			elsewhere.append("(%d,%d) L%d" % [tile % g.w, tile / g.w, g.level_of(tile)])
	t.eq(elsewhere.size(), 1, "넷째는 옆 조각에 선다 (자가 점검) %s" % str(elsewhere))
	var high := 0
	for k in b.keep_tiles.size():
		if g.level_of(int(b.keep_tiles[k])) == 2:
			high += 1
	t.eq(high, b.keep_tiles.size(), "성채의 조각 넷이 전부 눈금 2 다 (자가 점검)")
	var stairs := []
	for tile in g.w * g.h:
		if g.level_of(tile) == 1:
			stairs.append(Vector2i(tile % g.w, tile / g.w))
	t.eq(stairs.size(), 4, "계단이 조각 넷뿐이다 (자가 점검) %s" % str(stairs))

	# The landing, one sub-step at a time and not a second past it. Unchanged by this ticket: the
	# nearest 검사 is outside 6.0 of the beach.
	var guard := int(round((_first_hull_sec() + _crossing_sec() + 10.0) / Rules.SIM_SUBSTEP_SEC))
	var landed_at := -1.0
	for _i in guard:
		b.step(Rules.SIM_SUBSTEP_SEC)
		if not b.boat_riders.is_empty() and int(b.boat_riders[0]) == 0:
			landed_at = b.elapsed
			break
	t.ok(landed_at > 0.0, "첫 배가 %.2f초에 다 내렸다 (자가 점검)" % landed_at)
	t.eq(b.enemy_type.size(), Rules.BOAT_CAPACITY, "늑대 넷이 내렸다 (자가 점검)")
	var nearest := INF
	for e in b.enemy_type.size():
		for raw in b.ashore_ids():
			nearest = minf(nearest, b._dist(b.enemy_pos[e], b.soldier_pos[int(raw)]))
	t.ok(nearest > Rules.detect_of(Rules.WOLF),
		"내린 자리에서 가장 가까운 검사가 %.2f — 탐지 밖이다 (자가 점검)" % nearest)
	t.eq(b.keep_hp, Rules.KEEP_MAX_HP, "내린 순간 성채는 멀쩡하다 (자가 점검)")

	# Thirty seconds, with a flag set the first sub-step each 늑대 of the FIRST wave names a 검사.
	# ⚠ **The second boat can land inside this window on the shipped coast** — it launches at 35 s and
	# the crossing is under 18 s — so the per-늑대 reads below name the first `BOAT_CAPACITY` rows and
	# the board-wide reads (the 성채, the verdict) take whatever is ashore. Measured: this row indexed
	# past a four-long flag array on its first run.
	var first := Rules.BOAT_CAPACITY
	var noticed := PackedByteArray()
	noticed.resize(first)
	for _i in int(round(30.0 / Rules.SIM_SUBSTEP_SEC)):
		b.step(Rules.SIM_SUBSTEP_SEC)
		for e in first:
			if int(b.enemy_target[e]) >= 0:
				noticed[e] = 1
		if b.lost:
			break
	var blind := []
	var wolves_hurt := []
	var at_wall := []
	var where := []
	for e in first:
		if noticed[e] == 0:
			blind.append(e)
		if absf(float(b.enemy_hp[e]) - Rules.hp_of(Rules.WOLF)) > HP_NEAR:
			wolves_hurt.append(e)
		if b.keep_gap(b.enemy_pos[e]) <= Rules.reach_of(Rules.WOLF) + Rules.EPS:
			at_wall.append(e)
		var p: Vector2 = b.enemy_pos[e]
		where.append("e%d (%.1f,%.1f) L%d" % [e, p.x, p.y, g.level_of(b._tile_of(p))])
	var men_hurt := []
	for i in b.soldier_state.size():
		if int(b.soldier_state[i]) != Battle.SoldierState.ASHORE \
				or absf(float(b.soldier_hp[i]) - b.army.max_hp_of(i)) > HP_NEAR:
			men_hurt.append(i)
	# ⚠ The two reported-only facts — where the first wave stands, and how many 늑대 are on the board
	# at the read — ride on the labels of real checks. A check written `where.size() == first` or
	# `enemy_type.size() >= first` is true by construction and counts a pass for nothing.
	t.eq(blind.size(), 0, "늑대 넷이 전부 한 번은 검사를 겨눴다 — 파수를 알아챘다 %s" % str(blind))
	t.eq(b.keep_hp, Rules.KEEP_MAX_HP,
		"상륙 30초 뒤 성채가 그대로다 — 파수를 지나쳐 태우던 물결이 파수에게 가서 집에 안 닿는다 (%.1f · 읽는 순간 판 위의 늑대 %d 마리, 둘째 배가 이 창 안에 닿을 수 있다)" % [b.keep_hp, b.enemy_type.size()])
	t.ok(not b.lost, "그리고 안 졌다 — 이 티켓 전에는 여기서 이미 진 뒤다")
	t.eq(wolves_hurt.size(), 0, "늑대 넷이 다 꽉 찬 체력이다 — 아무도 안 싸웠다 %s" % str(wolves_hurt))
	t.eq(men_hurt.size(), 0, "검사 넷도 다 서 있고 꽉 찬 체력이다 %s" % str(men_hurt))
	t.eq(at_wall.size(), 0, "벽의 사거리 안에 선 늑대가 없다 %s — 첫 물결이 선 자리 (보고만 한다): %s" % [str(at_wall), str(where)])


## How many fields `b` built since the last call: a key that was absent, or whose age went down.
## `ages` is the previous sample and is rewritten here; `seen` collects every key ever present.
func _count_builds(b: Battle, ages: Dictionary, seen: Dictionary) -> int:
	var n := 0
	for key in b._field_age:
		var age := float(b._field_age[key])
		if not ages.has(key) or age < float(ages[key]) - NEAR:
			n += 1
		seen[key] = true
	# Keys that expired drop out of `ages`, so their next build reads as absent.
	ages.clear()
	for key in b._field_age:
		ages[key] = float(b._field_age[key])
	return n


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


## **The plateau board with its 성채 standing and nobody else on it.** See `PLATEAU`: landlocked so no
## boat is born, and `-1` for the doorstep so no 검사 stands — a blow that lands here can only have
## come from the 늑대 the row put there.
func _on_the_plateau() -> Battle:
	var g := Grid.new()
	g.load_rows(PLATEAU, PLATEAU_TIERS)
	var keep := PackedInt32Array()
	for raw in PLATEAU_KEEP:
		keep.append(int(raw))
	return _battle_on(g, keep, -1)


## **The plateau board with NO 성채**, so its four 눈금 2 조각 are free ground a 검사 can stand on.
## Landlocked like `PLATEAU` is, and `-1` for the doorstep — the [B] and [stands] rows of 07-01.
func _plateau_no_keep() -> Battle:
	var g := Grid.new()
	g.load_rows(PLATEAU, PLATEAU_TIERS)
	return _battle_on(g, PackedInt32Array(), -1)


## **Steps one sub-step at a time until the first boat has put everybody ashore.** Bounded, because a
## net that hangs prints no verdict at all and that disarms mutation testing on the whole file.
func _step_until_landed(b: Battle) -> void:
	var guard := int(round((_first_hull_sec() + _crossing_sec() + 5.0) / Rules.SIM_SUBSTEP_SEC))
	for _i in guard:
		b.step(Rules.SIM_SUBSTEP_SEC)
		if not b.boat_riders.is_empty() and int(b.boat_riders[0]) == 0:
			return


## How long one crossing takes on this fixture, derived rather than pinned — the speed and the distance
## are `net_boats`' to hold.
func _crossing_sec() -> float:
	return (Rules.BOAT_START_DIST_TILES - Rules.BOAT_STANDOFF_TILES) / Rules.BOAT_SPEED_TILES


## **When the first hull of a run is born**, in seconds: one crossing before the first wave lands.
##
## ⚠⚠ **IT WAS FIVE SECONDS UNTIL 2026-09-03 AND IT IS NOW 461.75.** Four rows in this file open a
## coastal board and wait for a hull; **they go quiet rather than red** if the time they wait for stops
## being reachable, which is why the number lives in one function here.
## ⚠ **`net_boats` is what holds the wave clock itself.** This is a caller, not a second copy of it.
func _first_hull_sec() -> float:
	return Rules.WAVE_FIRST_SEC - Rules.BOAT_CROSSING_SEC


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
