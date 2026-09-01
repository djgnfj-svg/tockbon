extends RefCounted
## **The player commands a 칸, and `Hand` is driven straight to say so.** 태스크 03, the 2026-09-01 flip.
##
## The claim under test is one sentence: **`reach_blocks` is `reach` collapsed through `Grid.block_of`,
## an order onto a 칸 already holding `Rules.BLOCK_CAPACITY` bodies still goes out, a 칸 seats its
## ceiling and no more, and the surplus is seated in a 칸 the bodies may WALK to rather than being
## dropped.**
##
## ⚠⚠ **「TOUCHES」 STOOD IN THAT SENTENCE UNTIL 2026-09-01 AND IT WAS THE WRONG WORD.** Two 조각 either
## side of a cliff touch BY NUMBER and no body may cross between them — measured that day, twelve
## bodies ordered onto an upper-tier 칸 seated nine upstairs and dropped three over the wall. **The
## last two rows below are the ones that hold the walk to `Grid.can_step`**, and the flat boards above
## them cannot say anything about it, because on flat ground every numeric neighbour is a walkable one.
##
## ⚠⚠ **NOTHING HERE TOUCHES THE TREE.** `Grid.new()`, `Army.new()`, `Battle.new()` and `Hand.new()` are
## the whole of it — the `src/sim/` seam `GLOSSARY.md` names. **No frame is pumped and `Battle.step` is
## never called**, so no boat is ever born and nothing walks: every number below is the state one
## `Hand` call left behind.
##
## ⚠⚠ **THIS FILE EXISTS BECAUSE THE WHOLE FLIP COULD HAVE LANDED GREEN.** Before it, nothing under
## `tests/` called `Hand.order` by name and nothing drove `Hand` at all — every order in the suite goes
## through the shell's `_unhandled_input`, and **the shell cannot reach a full 칸**: it aims where the
## reach lights, and until 2026-09-01 a full 칸 did not light. So the two halves that carry the new
## rule — the seating and the relaxed lighting — had no check anywhere.
##
## ⚠⚠ **NO DECIDED NUMBER IS TYPED IN HERE.** `Rules.BLOCK_CAPACITY`, `Rules.TILE_CAPACITY` and
## `Rules.BLOCK_TILES` are read, never repeated — `net_fight` is the one file that pins them as
## literals, and two files pinning one number is two files to edit and one of them forgotten. **What IS
## typed here is the fixture's own shape**, and every expected count below is arithmetic on those four
## board constants rather than a number copied off a run.
##
## ⚠ **The labels are Korean because they are printed output**, which is what every net in this folder
## does; the prose is English, which is what every file in this repo does.


## **A small island in a sea, and the only board where the collapse is worth measuring.** ⚠⚠ **A board
## of nothing but land would make `reach_blocks` and 「every 칸 on the board」 the same list**, and a
## `reach_blocks` that simply enumerated the board would pass. **Here twelve 칸 of eighteen light, and
## eight of the twelve are half water** — so the union rule and the collapse both have to be right.
const SHORE := [
	"~~~~~~~~~~~~",
	"~~........~~",
	"~~........~~",
	"~~........~~",
	"~~........~~",
	"~~~~~~~~~~~~",
]
## The land rectangle of `SHORE`, in 조각, inclusive. **Every expected count in the first row is
## arithmetic on these four**, so a board edited without editing them goes red rather than quietly
## measuring a different island.
const SHORE_X0 := 2
const SHORE_X1 := 9
const SHORE_Y0 := 1
const SHORE_Y1 := 4

## **All land, landlocked, flat** — the board every seating row runs on.
##
## ⚠⚠ **LANDLOCKED ON PURPOSE.** The surplus rows below need a 칸 with free neighbours on every side,
## and a coast would put water where the spill is supposed to go — 「the surplus was dropped」 and 「the
## surplus had nowhere to sit」 are two different failures and they look identical in a count.
## ⚠ **Flat on purpose too**: `_standable` refuses a stair, and a stair anywhere near the pressed 칸
## would make a missing seat read as a ceiling.
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
## Where every body that is not part of a fixture's crowd is stood — the far corner of `FIELD`.
## ⚠ **Far from `PRESSED_TX`/`PRESSED_TY` on purpose**: the picked bodies must not be standing inside
## the 칸 they are ordered onto, or `_seats` subtracts them from that 칸's occupancy and the ceiling
## rows would be measuring an allowance instead of a ceiling.
const HOME_TX := 1
const HOME_TY := 1
## A 조각 of the 칸 every order below is aimed at. **Four 칸 away from `HOME`**, so nothing the fixture
## stood at home is in the pressed 칸 or in any 칸 touching it.
const PRESSED_TX := 6
const PRESSED_TY := 4

## **Two storeys with one door — the board the cliff rows run on.** All land, no water: columns 0-5
## stand at level 0, columns 6-11 at level 2, and the single stair 조각 at (6,2) is the only way
## between them.
##
## ⚠⚠ **THE FLAT BOARDS ABOVE CANNOT MEASURE THIS AND THAT IS WHY THIS ONE EXISTS.** On `FIELD` every
## 8-way neighbour is also a step a body may take, so a spill walk that asks nothing about height is
## right there and wrong here. **The whole defect lives in the gap between 「a neighbour by number」 and
## 「a step a body may take」**, and a board with no height has no gap.
##
## ⚠ **No water on purpose.** 「the surplus was refused by the sea」 and 「the surplus was refused by the
## wall」 look identical in a seat count, and this file already has water rows for the first one.
const CLIFF := [
	"............",
	"............",
	"............",
	"............",
	"............",
	"............",
]
const CLIFF_TIERS := [
	"......222222",
	"......222222",
	"....../22222",
	"......222222",
	"......222222",
	"......222222",
]
## A 조각 of the upper-tier 칸 the cliff row presses, and the low 조각 immediately west of it.
## ⚠ **`CLIFF_OVER` is what the pre-fix walk actually handed out** (2026-09-01, driven headless): it is
## an 8-way neighbour of the pressed 칸 by arithmetic, it is lit, it has room — and `Grid.can_step`
## refuses it. The row below asserts all four of those before it asserts nobody was seated there.
const CLIFF_PRESSED_TX := 6
const CLIFF_PRESSED_TY := 0
const CLIFF_OVER_TX := 5
const CLIFF_OVER_TY := 0
## Where the cliff row's 부대 stands: the far low corner, so it is not inside the pressed 칸 and not in
## anything the spill can reach.
const CLIFF_HOME_TX := 0
const CLIFF_HOME_TY := 0

## **One 칸 of plateau whose only door is a stair** — level 2 at (4,2),(5,2),(4,3),(5,3), the stair 조각
## at (3,2), and flat ground everywhere else.
##
## ⚠⚠ **THE FIRST ASSERTION OF THE ROW BELOW IS THAT THIS SHAPE IS WHAT IT SAYS**: exactly ONE 조각
## outside the pressed 칸 is `Grid.can_step` from it, and it is the stair. **That is what makes seating
## twelve bodies proof that the walk went through the stair**, rather than proof that it found some
## other way out.
const PLATEAU := [
	"........",
	"........",
	"........",
	"........",
	"........",
	"........",
]
const PLATEAU_TIERS := [
	"........",
	"........",
	".../22..",
	"....22..",
	"........",
	"........",
]
const PLATEAU_PRESSED_TX := 4
const PLATEAU_PRESSED_TY := 2
const PLATEAU_STAIR_TX := 3
const PLATEAU_STAIR_TY := 2


func run(t) -> void:
	_the_lit_blocks_are_the_lit_tiles_collapsed(t)
	_an_order_onto_a_full_block_still_goes_out(t)
	_a_block_seats_its_ceiling_and_no_more(t)
	_the_surplus_sits_in_a_block_that_touches_the_pressed_one(t)
	_the_hover_line_ends_where_the_press_puts_the_body(t)
	_the_line_is_redrawn_from_where_the_body_now_stands(t)
	_the_surplus_does_not_spill_over_a_cliff(t)
	_the_surplus_walks_down_the_stair_when_that_is_the_only_door(t)
	# **The sentinel.** See `run_nets.done` — without it a `run()` that dies half way still reports
	# every check it managed first, in a shape a healthy net cannot be told from.
	t.done()


# == the two units ====================================================================================

## **`reach_blocks` is `reach` put through `Grid.block_of`, and `reach` is still 조각.**
##
## ⚠⚠ **TWO NAMES, TWO UNITS, AND MIXING THEM GOES NOWHERE NEAR RED.** A 칸 index handed to a 조각-keyed
## reader lands on a real 조각 somewhere else on the board — a plausible number for the wrong place.
## **So the first row here is that `reach` did NOT become 칸**: if it had, its size would be the 칸 count
## and every 조각-strided reader (the mask the picture is painted from) would be reading a quarter of the
## board with nothing going red.
##
## ⚠⚠ **THE EXPECTED COUNTS COME FROM THE BOARD AND NEVER FROM `Hand`.** A row that took its bound off
## the thing it checks passes for any implementation of it — this repo has that failure written down.
## Here the land rectangle is declared above and the two counts are arithmetic on it.
##
## ⚠ **A 칸 lights when ANY of its 조각 is lit**, which is why eight of the twelve on this board are half
## water. The rows at the end drive exactly that case rather than trusting it.
func _the_lit_blocks_are_the_lit_tiles_collapsed(t) -> void:
	var b := _battle(SHORE, 1)
	var g := b.grid
	var hand := Hand.new()
	t.ok(b.place_ashore(0, g.tile_index(SHORE_X0 + 1, SHORE_Y0 + 1)) >= 0,
		"자가 점검 — 몸 하나가 섬에 섰다")
	t.ok(hand.pick(b, 0), "자가 점검 — 손이 그 몸을 쥐었다")

	var step := Rules.BLOCK_TILES
	var land_tiles := (SHORE_X1 - SHORE_X0 + 1) * (SHORE_Y1 - SHORE_Y0 + 1)
	var lit_blocks := (SHORE_X1 / step - SHORE_X0 / step + 1) * (SHORE_Y1 / step - SHORE_Y0 / step + 1)
	var board_blocks := ((g.w + step - 1) / step) * ((g.h + step - 1) / step)

	t.eq(hand.reach.size(), land_tiles,
		"불이 들어온 조각이 섬의 땅 조각 수 그대로다 (%d개) — reach 는 아직 조각이다" % land_tiles)
	t.eq(hand.reach_blocks.size(), lit_blocks,
		"그리고 불이 들어온 칸은 %d개다 — 판의 모양에서 나온 수지 받아 적은 수가 아니다" % lit_blocks)
	# ⚠ **Both bounds, in the same breath.** 「fewer 칸 than 조각」 alone is green for a list of one, and
	# 「some 칸 are dark」 alone is green for a list that dropped half the island.
	t.ok(hand.reach_blocks.size() < hand.reach.size(),
		"칸 수가 조각 수보다 적다 — 뭉쳐진 것이지 그대로 옮겨진 게 아니다")
	t.ok(hand.reach_blocks.size() < board_blocks,
		"그리고 판의 칸 %d개보다도 적다 — 「전부 켠다」로는 이 줄을 못 지난다" % board_blocks)

	# **The definition, driven.** Collapse `reach` here, independently, and compare the two lists whole.
	var want := PackedInt32Array()
	var seen := {}
	for k in hand.reach.size():
		var bk := g.block_of(int(hand.reach[k]))
		if bk < 0 or seen.has(bk):
			continue
		seen[bk] = true
		want.append(bk)
	want.sort()
	t.eq(hand.reach_blocks.size(), want.size(), "손이 든 칸 수가 직접 뭉친 수와 같다")
	var wrong := 0
	for k in mini(hand.reach_blocks.size(), want.size()):
		if int(hand.reach_blocks[k]) != int(want[k]):
			wrong += 1
	t.eq(wrong, 0, "그리고 칸 하나하나가 같다 — 오름차순으로, 겹치지 않고")

	# ⚠ **`can_reach_block` and `reach_blocks` are one fact.** Two containers that can disagree about
	# the same thing is how a lit 칸 refuses a press, so every 칸 on the board is asked both ways.
	var disagree := 0
	for bk in board_blocks:
		if hand.can_reach_block(bk) != hand.reach_blocks.has(bk):
			disagree += 1
	t.eq(disagree, 0, "칸 %d개를 다 물어봐도 목록과 조회가 어긋나지 않는다" % board_blocks)
	t.ok(not hand.can_reach_block(-1), "칸 -1 은 거절이다 — block_of 가 판 밖에 주는 답이다")
	t.ok(not hand.can_reach_block(board_blocks), "판 끝 너머의 칸도 거절이다")

	# -- the union: half a 칸 in the water still lights ------------------------------------------------
	var wet := g.tile_index(SHORE_X0, SHORE_Y0 - 1)
	var dry := g.tile_index(SHORE_X0, SHORE_Y0)
	t.eq(g.passable[wet], 0, "자가 점검 — 물 조각을 하나 잡았다")
	t.eq(g.block_of(wet), g.block_of(dry), "자가 점검 — 그 물 조각과 바로 밑 땅 조각이 같은 칸이다")
	t.ok(not hand.can_reach(wet), "물 조각에는 불이 안 들어온다")
	t.ok(hand.can_reach(dry), "그 밑 땅 조각에는 들어온다")
	t.ok(hand.can_reach_block(g.block_of(dry)),
		"그래서 반이 물인 그 칸에도 불이 들어온다 — 조각 하나면 칸이 켜진다")
	# The control that keeps the union honest: a 칸 with no land at all stays dark.
	var open_sea := g.block_of(g.tile_index(0, 0))
	t.ok(not hand.can_reach_block(open_sea), "그런데 통째로 물인 칸은 안 켜진다")

	hand.clear()
	t.eq(hand.reach_blocks.size(), 0, "놓으면 칸도 같이 꺼진다 — 조각만 꺼지고 칸이 남지 않는다")


# == the new rule =====================================================================================

## **An order onto a 칸 that already holds nine goes out** (2026-09-01, the user: "let us do it by the
## block", and "the order goes out even when it is full, and if the 칸 holds enemies they fight").
##
## ⚠⚠ **THIS IS THE ROW THE REVERSAL IS, AND IT HAS A CONTROL BUILT INTO IT.** Until that day
## `_standable` asked `Grid.can_hold`, which folds in `block_has_room` — a 칸 holding
## `Rules.BLOCK_CAPACITY` bodies went dark, fell out of `reach_blocks`, and `Hand.order` refused the
## press. **`Grid.can_hold` is still there and is still the walker's admission test**, so the old rule
## can be computed by hand right beside the new one: it answers false on all four 조각 of this 칸 while
## the press goes through. **Without that control this row is 「an order went out」 and says nothing
## about which rule allowed it.**
##
## ⚠ **The ceiling did not move, and the second half of this row is that.** Nobody is seated inside the
## full 칸 — every body sent lands outside it, which is `_seats` honouring `Rules.BLOCK_CAPACITY` while
## the lighting stops asking about it.
func _an_order_onto_a_full_block_still_goes_out(t) -> void:
	var crowd := Rules.BLOCK_CAPACITY
	var squad := 4
	var b := _battle(FIELD, crowd + squad)
	var g := b.grid
	var pressed := g.block_of(g.tile_index(PRESSED_TX, PRESSED_TY))
	var seats_in := g.tiles_of_block(pressed)
	t.eq(seats_in.size(), Rules.BLOCK_TILES * Rules.BLOCK_TILES,
		"자가 점검 — 누를 칸이 조각 넷을 통째로 들고 있다 (판 밖으로 안 걸친다)")

	# **The crowd, packed into the pressed 칸 by hand.** `Rules.TILE_CAPACITY` to a 조각, so the ids
	# walk down the 칸's own 조각 list rather than being scattered by the landing search.
	var misplaced := 0
	for i in crowd:
		var want_tile := int(seats_in[i / Rules.TILE_CAPACITY])
		if b.place_ashore(i, want_tile) != want_tile:
			misplaced += 1
	t.eq(misplaced, 0, "자가 점검 — 아홉을 그 칸의 조각들에 그대로 세웠다")
	t.eq(g.block_hold_count(pressed), crowd,
		"자가 점검 — 그 칸이 천장까지 찼다 (%d)" % crowd)

	var squad_ids := _hand_ids(crowd, squad)
	var hand := _squad(b, squad_ids)
	t.eq(hand.ids.size(), squad, "자가 점검 — 손이 넷을 쥐었다, 전부 그 칸 밖에서")

	# **The old rule, computed by hand.** ⚠ `Grid.can_hold` is what `_standable` used to ask; it is
	# still live and still refuses, which is what makes this a control rather than a restatement.
	var old_rule_open := 0
	for raw in seats_in:
		for k in hand.ids.size():
			if g.can_hold(int(raw), int(hand.ids[k])):
				old_rule_open += 1
	t.eq(old_rule_open, 0,
		"대조군 — 옛 규칙(can_hold)이라면 그 칸의 네 조각이 아무도 안 받는다")
	t.ok(hand.can_reach_block(pressed),
		"그런데 가득 찬 칸에 불이 들어온다 — 2026-09-01 에 뒤집힌 그 규칙이다")

	var sent := hand.order(b, pressed)
	t.eq(sent, squad, "그리고 명령이 나간다 — 넷이 다 보내진다")
	var inside := 0
	var outside := 0
	var dropped := 0
	for k in squad_ids.size():
		var dest := int(b.soldier_order[int(squad_ids[k])])
		if dest < 0:
			dropped += 1
		elif g.block_of(dest) == pressed:
			inside += 1
		else:
			outside += 1
	t.eq(dropped, 0, "아무도 목적지 없이 남지 않는다")
	t.eq(inside, 0, "가득 찬 칸에는 하나도 안 앉힌다 — 천장은 그대로다")
	t.eq(outside, squad, "넷이 다 그 칸 바깥에 앉는다")
	t.eq(g.block_hold_count(pressed), crowd,
		"그리고 그 칸의 인원은 그대로다 — 명령은 자리를 잡는 것이 아니다")


## **A 칸 seats `Rules.BLOCK_CAPACITY` bodies and puts them on its own 조각.**
##
## ⚠⚠ **THE 조각 CEILING IS THE OTHER HALF AND IT IS ASSERTED IN THE SAME ROW.** Nine seats inside four
## 조각 means a 조각 is handed out more than once — `_spread`, which handed out DISTINCT 조각, could not
## have done this — but nothing may take more than `Rules.TILE_CAPACITY`. **A seating that put all nine
## on one 조각 would pass 「all nine are inside the 칸」 on its own.**
##
## ⚠ **The 부대 stands far away**, so the 칸's room is its real room. `_seats` subtracts the hand's own
## bodies from a 칸's occupancy on purpose, and a fixture standing on its own destination would measure
## that allowance instead of the ceiling.
func _a_block_seats_its_ceiling_and_no_more(t) -> void:
	var crowd := Rules.BLOCK_CAPACITY
	var b := _battle(FIELD, crowd)
	var g := b.grid
	var pressed := g.block_of(g.tile_index(PRESSED_TX, PRESSED_TY))
	var seats_in := g.tiles_of_block(pressed)

	var squad_ids := _stand_at_home(b, crowd)
	var hand := _squad(b, squad_ids)
	t.eq(hand.ids.size(), crowd, "자가 점검 — 손이 아홉을 쥐었다")
	t.eq(g.block_hold_count(pressed), 0, "자가 점검 — 누를 칸은 비어 있다")

	t.eq(hand.order(b, pressed), crowd, "빈 칸에 아홉을 보내면 아홉이 다 간다")
	var per_tile := {}
	var inside := 0
	for k in squad_ids.size():
		var dest := int(b.soldier_order[int(squad_ids[k])])
		if dest >= 0 and g.block_of(dest) == pressed:
			inside += 1
			per_tile[dest] = int(per_tile.get(dest, 0)) + 1
	t.eq(inside, crowd, "아홉이 다 그 칸의 조각 위에 앉는다")
	var over := 0
	for raw in per_tile.keys():
		if int(per_tile[raw]) > Rules.TILE_CAPACITY:
			over += 1
	t.eq(over, 0, "그런데 한 조각이 셋을 넘게 받지는 않는다 — 조각 천장은 그대로다")
	# ⚠ **The floor under the row above.** Nine bodies on `Rules.TILE_CAPACITY` per 조각 cannot sit on
	# fewer than three 조각, and a seating that used one 조각 nine times would clear every row but this.
	var least := (crowd + Rules.TILE_CAPACITY - 1) / Rules.TILE_CAPACITY
	t.ok(per_tile.size() >= least,
		"그래서 조각 %d개 이상에 나눠 앉는다 (%d개) — 한 조각에 몰아넣지 않는다"
			% [least, per_tile.size()])
	# The seats repeat a 조각, which is the whole reason the distinct-조각 spreader could not be kept.
	t.ok(per_tile.size() < crowd,
		"그리고 조각 수가 몸 수보다 적다 — 한 조각에 여럿이 선다")


## **The tenth body is seated in a 칸 that TOUCHES the pressed one, and never dropped.**
##
## ⚠⚠ **「NOT DROPPED」 IS THE HALF THAT WOULD HAVE ROTTED SILENTLY.** A `_seats` that simply stopped at
## the ceiling would hand back nine seats, `order` would report nine sent, and the tenth body would keep
## standing where it was with nothing going red — the press would look like it worked. **So the sent
## count and the tenth body's own destination are both read.**
##
## ⚠⚠ **ADJACENCY IS ASKED IN 조각 AND NOT IN 칸 ARITHMETIC.** A second copy of the row-major 칸 decode
## living in a net is how a check starts counting a real, wrong 칸 — the seat is required to be 8-way
## next to one of the pressed 칸's own 조각, and to be in a different 칸. That is what 「a neighbouring
## 칸」 means on the board, with no second decode to drift.
##
## ⚠ **WHICH neighbouring 칸 it is has not been chosen by anybody.** `_seats` walks the 8-way 조각 order
## `_spread` used, whose table is an inherited tie-break — so this row asks 「touching」 and deliberately
## does not pin a side. Pinning one here would freeze a decision nobody has made.
func _the_surplus_sits_in_a_block_that_touches_the_pressed_one(t) -> void:
	var over_by := 1
	var squad := Rules.BLOCK_CAPACITY + over_by
	var b := _battle(FIELD, squad)
	var g := b.grid
	var pressed := g.block_of(g.tile_index(PRESSED_TX, PRESSED_TY))
	var seats_in := g.tiles_of_block(pressed)

	var squad_ids := _stand_at_home(b, squad)
	var hand := _squad(b, squad_ids)
	t.eq(hand.ids.size(), squad, "자가 점검 — 손이 열을 쥐었다")
	t.eq(g.block_hold_count(pressed), 0, "자가 점검 — 누를 칸은 비어 있다")

	t.eq(hand.order(b, pressed), squad, "천장보다 하나 많아도 열이 다 보내진다 — 남는 하나를 안 버린다")
	var inside := 0
	var spilled := PackedInt32Array()
	for k in squad_ids.size():
		var dest := int(b.soldier_order[int(squad_ids[k])])
		t.ok(dest >= 0, "몸 %d 이 갈 자리를 받았다" % int(squad_ids[k]))
		if g.block_of(dest) == pressed:
			inside += 1
		else:
			spilled.append(dest)
	t.eq(inside, Rules.BLOCK_CAPACITY, "그 칸 안에는 딱 천장만큼만 앉는다")
	t.eq(spilled.size(), over_by, "그리고 넘친 하나만 밖으로 나간다")

	var touching := 0
	for k in spilled.size():
		var dest := int(spilled[k])
		if g.block_of(dest) == pressed:
			continue
		var dx := dest % g.w
		var dy := dest / g.w
		for raw in seats_in:
			var tx := int(raw) % g.w
			var ty := int(raw) / g.w
			if absi(dx - tx) <= 1 and absi(dy - ty) <= 1:
				touching += 1
				break
	t.eq(touching, spilled.size(),
		"넘친 몸은 누른 칸에 맞닿은 칸에 앉는다 — 판 어딘가가 아니라 옆이다")


# == fixtures =========================================================================================

## **A board, an army of `n` 검사, and a `Battle` on it with no 성채 and no doorstep.**
##
## ⚠ **No 성채 on purpose.** `Grid.block_hold_count` counts the house as one body, so a keep standing
## anywhere near the pressed 칸 would take one of the nine and every ceiling row would be off by one for
## a reason that has nothing to do with the rule.
## ⚠ **`tiers` defaults to flat**, which is what every row above this one wants and what
## `Grid.load_rows` already means by an empty second argument — the cliff rows are the only callers
## that pass one.
func _battle(rows: Array, n: int, tiers: Array = []) -> Battle:
	var g := Grid.new()
	g.load_rows(rows, tiers)
	var army := Army.new()
	var slot := army.register_species(Rules.SWORDSMAN)
	for _i in n:
		army.recruit(slot)
	var b := Battle.new()
	b.setup(g, army, [], PackedInt32Array(), -1)
	return b


## **Stands `n` bodies in the far corner and answers their ids**, which are `0 .. n - 1` because a fresh
## `Army` numbers a body by the order it was recruited in.
## ⚠ **They spread as they land** — `Battle.place_ashore` takes the nearest free 조각 at the wish's own
## level, so nine of them fill the corner 칸 and the tenth steps outside it, exactly as bodies do.
func _stand_at_home(b: Battle, n: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var home := b.grid.tile_index(HOME_TX, HOME_TY)
	for i in n:
		if b.place_ashore(i, home) >= 0:
			out.append(i)
	return out


## The ids `crowd .. crowd + squad - 1` — the bodies of a fixture that stood a crowd first.
func _hand_ids(crowd: int, squad: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in squad:
		out.append(crowd + k)
	return out


## **Stands the given ids at home if they are not standing yet, and picks the lot.**
## ⚠ **`pick_many` and never `pick` in a loop** — `pick` clears the hand first, so a loop would leave a
## 부대 of one and the ceiling rows would all measure a single body.
func _squad(b: Battle, want: PackedInt32Array) -> Hand:
	var home := b.grid.tile_index(HOME_TX, HOME_TY)
	for k in want.size():
		var i := int(want[k])
		if int(b.soldier_state[i]) != Battle.SoldierState.ASHORE:
			b.place_ashore(i, home)
	var hand := Hand.new()
	hand.pick_many(b, want)
	return hand
# == the 이동선 promises what the press does ===========================================================

## **The last 조각 of the hover line is the 조각 the press actually sends that body to.**
##
## ⚠⚠ **THIS IS THE ROW A MEASURED FALSE GREEN LEFT BEHIND** (2026-09-01, driven headless with `.new()`).
## `Hand.routes` cached its answer against the pressed 칸 alone. The 칸 is a fine name for the QUESTION
## and stopped being a name for the ANSWER the day `_seats` started reading live occupancy — so a hover
## over an empty 칸, a crowd walking into it, and a second hover gave **the line that was drawn before
## the crowd arrived**. Measured on this very fixture: the preview ended on 조각 54 while `order` seated
## the 부대 on 조각 41, **three bodies, three wrong lines, nothing red anywhere**.
##
## ⚠⚠ **THE CONTROL IS THE FIRST HALF OF THE ROW AND IT IS NOT OPTIONAL.** 「the preview agrees with the
## press」 is green for a board that never moved, and green for a `routes` that simply called `order`.
## **So the row first proves the answer MOVED** — the ends before the crowd and the ends after it are
## different 조각 — and only then that the moved answer is the one the press honours.
##
## ⚠ **The 부대 stands far from the pressed 칸**, because `_seats` does not count the hand's own bodies:
## a 부대 standing on its own destination would be measuring an allowance rather than a full 칸.
func _the_hover_line_ends_where_the_press_puts_the_body(t) -> void:
	var crowd := Rules.BLOCK_CAPACITY
	var squad := 3
	var b := _battle(FIELD, crowd + squad)
	var g := b.grid
	var pressed := g.block_of(g.tile_index(PRESSED_TX, PRESSED_TY))
	var squad_ids := _hand_ids(crowd, squad)
	var hand := _squad(b, squad_ids)
	t.eq(hand.ids.size(), squad, "자가 점검 — 손이 셋을 쥐었다, 전부 누를 칸 밖에서")
	t.eq(g.block_hold_count(pressed), 0, "자가 점검 — 누를 칸은 아직 비어 있다")

	var before := _route_ends(hand.routes(b, pressed))
	t.eq(before.size(), squad, "빈 칸에 커서를 얹으면 이동선이 셋 나온다")

	# **The board moves under the cursor**, which is the only thing this row needs to be true.
	var seats_in := g.tiles_of_block(pressed)
	var misplaced := 0
	for i in crowd:
		var want_tile := int(seats_in[i / Rules.TILE_CAPACITY])
		if b.place_ashore(i, want_tile) != want_tile:
			misplaced += 1
	t.eq(misplaced, 0, "자가 점검 — 그 사이에 아홉이 그 칸을 채웠다")
	t.eq(g.block_hold_count(pressed), crowd, "자가 점검 — 칸이 천장까지 찼다 (%d)" % crowd)

	var after := _route_ends(hand.routes(b, pressed))
	t.eq(after.size(), squad, "커서는 그대로인데 이동선은 다시 셋 나온다")
	var moved := 0
	for k in squad:
		if int(after[k]) != int(before[k]):
			moved += 1
	# ⚠ **The control.** Without this the row passes on a board where nothing ever changed.
	t.eq(moved, squad, "그리고 셋 다 끝점이 옮겨졌다 — 칸이 차면 답이 달라진다는 대조군이다")

	t.eq(hand.order(b, pressed), squad, "그 자리에서 누르면 셋이 다 간다")
	var wrong := 0
	for k in squad:
		if int(after[k]) != int(b.soldier_order[int(squad_ids[k])]):
			wrong += 1
	t.eq(wrong, 0, "이동선의 마지막 조각이 그 몸이 실제로 받은 목적지다 — 셋 다")


## **A line drawn while a body was walking is redrawn from where he now stands.**
##
## ⚠⚠ **THE SAME CACHE, THE OTHER HALF.** Keyed on the pressed 칸, a line built at the door kept every
## 조각 the body had since walked past — so the drawn line ran BACKWARDS from his feet to where he used
## to be. `route_points` starts the line at his real `soldier_pos`, so the two ends of the first segment
## disagreed by however far he had got.
##
## ⚠ **He is ordered somewhere ELSE first and the hover aims at a third 칸**, which is what a hand
## hovering while its last order is still running looks like. **`order` forgets the routes**, so a hover
## aimed at the 칸 he was sent to could not measure this.
func _the_line_is_redrawn_from_where_the_body_now_stands(t) -> void:
	var b := _battle(FIELD, 1)
	var g := b.grid
	var home := g.tile_index(HOME_TX, HOME_TY)
	t.ok(b.place_ashore(0, home) >= 0, "자가 점검 — 몸 하나가 구석에 섰다")
	var hand := Hand.new()
	t.ok(hand.pick(b, 0), "자가 점검 — 손이 그 몸을 쥐었다")

	var hover := g.block_of(g.tile_index(PRESSED_TX, PRESSED_TY))
	t.ok(b.order_walk(0, g.tile_index(HOME_TX + 8, HOME_TY)), "자가 점검 — 그 몸에게 다른 데로 가라고 했다")

	var was := _tile_under(b, 0)
	var head_was := _route_head(hand.routes(b, hover))
	t.eq(head_was, was, "자가 점검 — 이동선의 첫 조각이 지금 서 있는 조각이다")

	for _i in 90:
		b.step(1.0 / 60.0)
	var now := _tile_under(b, 0)
	# ⚠ **The control**: a body that never left would make the row below green for a frozen cache.
	t.ok(now != was, "대조군 — 그 몸이 조각 %d 에서 %d 로 걸어갔다" % [was, now])

	t.eq(_route_head(hand.routes(b, hover)), now,
		"커서를 안 움직였는데도 이동선이 지금 발밑에서 다시 그려진다 — 지나온 조각을 안 물고 있다")


## The last 조각 of each line, `ids`-aligned. **-1 for a body already standing on its seat**, which is a
## line of no 조각 at all and not a destination.
func _route_ends(lines: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in lines.size():
		var line: PackedInt32Array = lines[k]
		out.append(int(line[line.size() - 1]) if line.size() > 0 else -1)
	return out


## The first 조각 of the first line, or -1.
func _route_head(lines: Array) -> int:
	if lines.is_empty():
		return -1
	var line: PackedInt32Array = lines[0]
	return int(line[0]) if line.size() > 0 else -1


## The 조각 a body's `soldier_pos` is standing in.
func _tile_under(b: Battle, i: int) -> int:
	var p: Vector2 = b.soldier_pos[i]
	return b.grid.tile_index(int(floor(p.x)), int(floor(p.y)))


# == the spill is a walk, not a neighbourhood =========================================================

## **A 조각 over a tier edge is a neighbour by arithmetic and no body may go there, so the surplus does
## not go there either.**
##
## ⚠⚠ **THIS ROW IS WHAT A MEASURED FALSE GREEN LEFT BEHIND** (2026-09-01, driven headless with
## `.new()`). `_seats` gated every step of its outward walk on `can_reach` alone — 「is that 조각 lit」 —
## and lighting says nothing about whether a body may step from HERE to THERE. On this very board:
## **twelve bodies onto the upper 칸 3 seated nine upstairs and put the surplus three on 조각 5, which
## is downstairs across the wall.** The order went out, the three walked the long way round through the
## stair, and every net in the suite stayed green.
##
## ⚠⚠ **THE SELF-CHECKS ARE THE CONTROL AND THEY ARE NOT DECORATION.** 「nobody was seated over the
## wall」 is green for a board with no wall, green for a 부대 too small to overflow, and green for a
## 조각 that was full anyway. **So the row first proves the trap is laid**: the low 조각 is lit, it has
## room, it is one of the pressed 칸's eight numeric neighbours, and `Grid.can_step` refuses it.
##
## ⚠ **The measure is `Grid.can_step` and never a second reachability rule.** `Grid.flow_field`,
## `Grid.path_from` and `_build_reach`'s flood all ask exactly it; a row that re-derived 「walkable」
## here would go green on a `_seats` that had drifted away from the walker.
func _the_surplus_does_not_spill_over_a_cliff(t) -> void:
	var squad := Rules.BLOCK_CAPACITY + Rules.TILE_CAPACITY
	var b := _battle(CLIFF, squad, CLIFF_TIERS)
	var g := b.grid
	var pressed_tile := g.tile_index(CLIFF_PRESSED_TX, CLIFF_PRESSED_TY)
	var pressed := g.block_of(pressed_tile)
	var over := g.tile_index(CLIFF_OVER_TX, CLIFF_OVER_TY)

	var ids := _stand_all(b, squad, g.tile_index(CLIFF_HOME_TX, CLIFF_HOME_TY))
	t.eq(ids.size(), squad, "자가 점검 — 아래층 구석에 열둘이 섰다")
	var hand := Hand.new()
	t.ok(hand.pick_many(b, ids), "자가 점검 — 손이 그 열둘을 쥐었다")

	# **The board is what it says it is.** Every land 조각 lights except the one stair, and both
	# storeys are in there — a fixture that came up flat would make every row below meaningless.
	t.eq(hand.reach.size(), g.w * g.h - 1, "자가 점검 — 계단 하나만 빼고 판 전체가 밝다")
	t.ok(hand.can_reach(over), "자가 점검 — 벽 너머 아래층 조각도 밝다")
	t.eq(g.level_of(pressed_tile), 2, "자가 점검 — 누를 칸은 위층이다")
	t.eq(g.level_of(over), 0, "자가 점검 — 그 옆 조각은 아래층이다")
	t.eq(g.hold_count(over), 0, "자가 점검 — 그 조각은 비어 있어서 자리가 있다")

	# **The trap**: that 조각 is one of the pressed 칸's eight numeric neighbours, and the walker
	# refuses it. Both halves, or the row is measuring an unreachable place instead of a wall.
	var numeric := false
	var walkable := false
	for raw in g.tiles_of_block(pressed):
		var p := int(raw)
		if absi(p % g.w - over % g.w) <= 1 and absi(p / g.w - over / g.w) <= 1:
			numeric = true
			if g.can_step(p, over):
				walkable = true
	t.ok(numeric, "자가 점검 — 그 조각은 누른 칸의 여덟 이웃 중 하나다 (숫자로는)")
	t.ok(not walkable, "대조군 — 그런데 can_step 은 그리로 가는 걸 거부한다")

	t.eq(hand.order(b, pressed), squad, "열둘이 다 명령을 받는다")
	var dests := _orders_of(b, ids)
	var over_the_wall := 0
	for k in dests.size():
		if int(dests[k]) == over:
			over_the_wall += 1
	t.eq(over_the_wall, 0, "그런데 벽 너머 조각에 앉은 몸은 하나도 없다 %s" % [dests])
	t.eq(_far_seats(g, pressed, dests, 1), 0,
		"넘친 몸도 누른 칸에서 한 걸음 안이다 — 맞닿은 게 아니라 걸어갈 수 있는 곳이다 %s" % [dests])


## **When the only way off a 칸 is a stair, the surplus walks down it.**
##
## ⚠⚠ **THIS IS THE OTHER HALF OF THE ROW ABOVE AND WITHOUT IT THE GATE COULD BE A WALL.** A `_seats`
## that simply refused every step off the pressed 칸's own storey would pass every assertion up there —
## the surplus would go nowhere at all, which is a different failure that counts the same. **When a
## check says a thing cannot happen there must be a neighbouring check that it DOES happen where it
## should**, which is the rule `net_tiers` wrote down after missing it once.
##
## ⚠⚠ **THE DOOR ASSERTION IS WHAT MAKES THE SEAT COUNT PROOF.** Exactly one 조각 outside the pressed
## 칸 is `Grid.can_step` from it and it is the stair, so twelve seats on a 칸 that holds nine can only
## mean the walk went through the stair — there is no other way out to find.
func _the_surplus_walks_down_the_stair_when_that_is_the_only_door(t) -> void:
	var squad := Rules.BLOCK_CAPACITY + Rules.TILE_CAPACITY
	var b := _battle(PLATEAU, squad, PLATEAU_TIERS)
	var g := b.grid
	var pressed_tile := g.tile_index(PLATEAU_PRESSED_TX, PLATEAU_PRESSED_TY)
	var pressed := g.block_of(pressed_tile)
	var stair := g.tile_index(PLATEAU_STAIR_TX, PLATEAU_STAIR_TY)
	t.eq(g.level_of(pressed_tile), 2, "자가 점검 — 고원은 위층이다")
	t.ok(Grid.is_stair_level(g.level_of(stair)), "자가 점검 — 그 옆 조각은 계단이다")

	var ids := _stand_all(b, squad, g.tile_index(CLIFF_HOME_TX, CLIFF_HOME_TY))
	t.eq(ids.size(), squad, "자가 점검 — 아래층 구석에 열둘이 섰다")
	var hand := Hand.new()
	t.ok(hand.pick_many(b, ids), "자가 점검 — 손이 그 열둘을 쥐었다")
	t.ok(hand.can_reach_block(pressed), "자가 점검 — 계단이 있어서 고원 칸이 밝다")
	t.ok(not hand.can_reach(stair), "자가 점검 — 계단 자체는 서는 자리가 아니라 안 밝다")

	# **The door is one 조각 wide and it is the stair.** This is what turns the seat count below into a
	# statement about the stair rather than about the board being roomy.
	var doors := _doors_out_of(g, pressed)
	t.eq(doors.size(), 1, "자가 점검 — 그 칸에서 걸어 나갈 수 있는 바깥 조각은 딱 하나다 %s" % [doors])
	t.eq(int(doors[0]) if doors.size() > 0 else -1, stair, "자가 점검 — 그리고 그 하나가 계단이다")

	t.eq(hand.order(b, pressed), squad, "그래도 열둘이 다 명령을 받는다 — 계단으로 내려가서 앉는다")
	var dests := _orders_of(b, ids)
	var upstairs := 0
	var on_stair := 0
	for k in dests.size():
		if g.block_of(int(dests[k])) == pressed:
			upstairs += 1
		if int(dests[k]) == stair:
			on_stair += 1
	t.eq(upstairs, Rules.BLOCK_CAPACITY, "고원 칸에는 천장만큼만 앉는다")
	t.eq(on_stair, 0, "계단 위에는 아무도 안 앉는다 — 지나는 자리지 머무는 자리가 아니다")
	t.eq(_far_seats(g, pressed, dests, 2), 0,
		"내려간 셋도 계단 바로 아래다 — 누른 칸에서 두 걸음 안이다 %s" % [dests])


## **Every 조각 outside `block` that a body standing in `block` may step onto**, ascending in discovery
## order. ⚠ **`Grid.can_step` and nothing else** — see `_far_seats` for why no second rule is written.
func _doors_out_of(g: Grid, block: int) -> PackedInt32Array:
	var doors := PackedInt32Array()
	for raw in g.tiles_of_block(block):
		var p := int(raw)
		var px := p % g.w
		var py := p / g.w
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var nx: int = px + int(dx)
				var ny: int = py + int(dy)
				if nx < 0 or ny < 0 or nx >= g.w or ny >= g.h:
					continue
				var nt := ny * g.w + nx
				if g.block_of(nt) == block or doors.has(nt):
					continue
				if g.can_step(p, nt):
					doors.append(nt)
	return doors


## **How many of `seats` are further than `bound` walking steps from `block`.**
##
## ⚠⚠ **THE STEPS ARE COUNTED WITH `Grid.can_step` AND NOTHING ELSE**, which is what `Grid.flow_field`,
## `Grid.path_from` and `Hand._build_reach` all walk on. **A second notion of 「walkable」 written here
## would let `_seats` drift away from the walker with this row still green** — the failure
## `how-nets-lie` collects, and the one the two rows above exist for.
## ⚠ **A seat the walk never reaches counts as far**, which is what an unreachable seat is.
func _far_seats(g: Grid, block: int, seats: PackedInt32Array, bound: int) -> int:
	var n := g.w * g.h
	var d := PackedInt32Array()
	d.resize(n)
	d.fill(-1)
	var q := PackedInt32Array()
	for raw in g.tiles_of_block(block):
		var tt := int(raw)
		if g.passable[tt] == 1:
			d[tt] = 0
			q.append(tt)
	var head := 0
	while head < q.size():
		var cur := int(q[head])
		head += 1
		var cx := cur % g.w
		var cy := cur / g.w
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var nx: int = cx + int(dx)
				var ny: int = cy + int(dy)
				if nx < 0 or ny < 0 or nx >= g.w or ny >= g.h:
					continue
				var nt := ny * g.w + nx
				if d[nt] != -1 or not g.can_step(cur, nt):
					continue
				d[nt] = d[cur] + 1
				q.append(nt)
	var far := 0
	for k in seats.size():
		var dist := int(d[int(seats[k])])
		if dist < 0 or dist > bound:
			far += 1
	return far


## **Stands `n` bodies on one 조각 and answers the ids that landed.** ⚠ **The twin of `_stand_at_home`
## for a board that is not `FIELD`** — the corner is the caller's, because the cliff boards have their
## own low corner and `HOME_TX`/`HOME_TY` belong to the flat one.
func _stand_all(b: Battle, n: int, home: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in n:
		if b.place_ashore(i, home) >= 0:
			out.append(i)
	return out


## The 조각 each of `ids` has been told to walk to, in `ids` order.
func _orders_of(b: Battle, ids: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in ids.size():
		out.append(int(b.soldier_order[int(ids[k])]))
	return out
