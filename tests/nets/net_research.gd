extends RefCounted
## **The research bench's three unlocks — the first thing 원석 can be spent on**
## (`research-bench-unlocks.md`).
##
## Three things this net measures that nothing else can:
##
##  1. **A purchase survives `reset()`.** That is the whole feature — `reset()` is what "a run begins" means,
##     and a `_unlocked.clear()` added there would erase every purchase of every past run **with nothing
##     barking**. The bench would simply look empty again.
##  2. **The double jump is a structural no-op underwater.** `character.gd`'s `or` chain puts `in_water`
##     ahead of the budget and the spend is guarded on `not in_water`; both halves are measured, because
##     either one alone leaves water quietly eating the budget.
##  3. **The chips are really painted, and pressing one really spends.** `_paint_unlock_chip` is a hook cut
##     out of `_draw()` for exactly this (CLAUDE.md: "`_draw()` ran" is not "anything was drawn").
##
## **Two things this net cannot prove, stated rather than implied.** Neither is covered by any check here:
##  · **A real mouse click reaching the window.** Every click check below drives `_gui_input` directly on an
##    untreed node, which bypasses Godot's own input routing entirely — including `mouse_filter` on
##    `stage.tscn`, which is `IGNORE` until that scene is edited. That property is verify-read's and
##    verify-look's, not this file's.
##  · **How the air jump feels.** One extra jump at `JUMP_VY_PX` unchanged is a value; whether it reads as a
##    double jump rather than a stutter is the user's and verify-look's.

const Character := preload("res://src/actor/character.gd")
const CellGrid := preload("res://src/sim/cell_grid.gd")
const Fx := preload("res://src/view/fx_tuning.gd")
const Layout := preload("res://src/view/research_layout.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Progress := preload("res://src/actor/progress.gd")
const ResearchWindow := preload("res://src/view/research_window.gd")
const CharacterView := preload("res://src/view/character_view.gd")
const SpellSim := preload("res://src/sim/spell_sim.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const UnlockDefs := preload("res://src/actor/unlock_defs.gd")
const SpellCircle := preload("res://src/actor/spell_circle.gd")
const TownMap := preload("res://src/stage/town_map.gd")
const Fixtures := preload("res://src/actor/fixtures.gd")

const STAGE_SCENE := "res://src/stage/stage.tscn"

const DT := 1.0 / 60.0
const FLOOR_CY := 100
const FLOOR_TOP := FLOOR_CY * Tuning.CELL_PX
const REST_Y := FLOOR_TOP - Character.H_PX

## `net_character`'s own floor depth and reasoning — `mat_at()` reads STONE outside the grid, so a thick
##  floor only costs time.
const FLOOR_DEPTH_CY := 32

## **The water vessel's coordinates, `net_character`'s A-series verbatim.** Duplicated rather than shared for
##  this repo's usual reason: each net runs in its own process, so there is no shared base class.
const WATER_CX0 := 300
const WATER_CX1 := 314
const WATER_CY0 := 150
const WATER_CY1 := 230
const WATER_START_Y := (WATER_CY0 + 20) * Tuning.CELL_PX

## **Literal row indices into `Fx.RESEARCH_ROWS`, pinned rather than searched for.** CLAUDE.md: "a check whose
##  bounds come from the thing it checks proves nothing" — reorder that table and these must go red, not
##  quietly follow.
const ROW_ITEM := 1
const ROW_BODY := 2

## The inset used when probing a rect's corners — `net_pick`'s own finding, that a hit box shrunk on one side
##  survives a centre-only check.
const CORNER_INSET_PX := 2.0

## **The minimum chip width, as a literal at the real window size.** Not a re-read of `unlock_chip_rects`.
const MIN_CHIP_W_PX := 40.0


## **Captures both draw hooks the bench has.** Neither calls `super()`: the point is to read the arguments
##  `_draw_rows()` decided on, not to paint them, and the row's name line still draws through the real
##  `draw_string` above so the node is genuinely rendering.
class _CapturingResearchWindow extends ResearchWindow:
	var chip_calls: Array = []
	var slot_calls: Array = []
	func _paint_unlock_chip(_font: Font, unlock_id: int, r: Rect2, state: int) -> void:
		chip_calls.append({"id": unlock_id, "rect": r, "state": state})
	func _draw_slot(r: Rect2, locked: bool) -> void:
		slot_calls.append({"rect": r, "locked": locked})


func run(t) -> void:
	# -- the catalogue --
	_the_catalogue_is_the_rune_pool_plus_one_body_unlock(t)
	_an_id_outside_the_table_answers_no_everywhere(t)

	# -- buying --
	_a_fresh_bench_sells_three_things_and_not_the_none_rune(t)
	_the_price_is_ten_and_it_is_charged_exactly_once(t)
	_buying_moves_nothing_but_gems_and_the_unlock(t)

	# -- permanence, the highest-risk half --
	_a_purchase_survives_reset(t)
	_a_granted_rune_and_a_bought_rune_part_ways_at_reset(t)
	_gems_this_run_reads_negative_after_a_town_purchase(t)

	# -- the jump --
	_the_budget_is_zero_until_bought_and_one_after_every_reset(t)
	_with_no_unlock_the_jump_is_exactly_what_it_was(t)
	_the_bought_air_jump_fires_once_per_airtime(t)
	_the_ground_refills_the_budget_and_water_does_not(t)
	_underwater_the_unlock_is_a_no_op(t)
	_leaving_the_water_gives_exactly_one_more_jump(t)
	_the_flash_counts_down_while_invulnerable(t)

	# -- layout and the hit test --
	_chip_rects_sit_in_the_row_clear_of_the_slot_and_do_not_overlap(t)
	_chip_at_reads_the_same_rects_as_chip_rects(t)

	# -- what a chip says and how it reads --
	_chip_state_walks_the_whole_table(t)
	_a_granted_rune_still_shows_its_price_but_not_the_lock(t)

	# -- pressing one --
	_clicking_a_chip_spends_and_grants(t)

	# -- and that they are actually painted --
	await _the_rows_really_paint_their_chips(t)
	await _the_padlock_is_on_the_two_rows_that_have_a_price(t)

	# -- the shell path, driven through the real doors --
	_the_footer_states_the_price_instead_of_denying_one(t)
	await _the_air_jump_ring_is_painted_only_while_the_flash_is_up(t)

	await _the_shell_really_hands_the_bench_its_progress(t)
	await _the_shell_pushes_the_air_jump_budget_every_frame(t)
	_the_hud_line_states_the_cost_and_follows_a_purchase(t)
	await _a_bought_rune_survives_the_departure_gate(t)
	await _closing_the_bench_refreshes_the_town_message(t)


# ══════════════════════════════════════════════════════════════════
#  The catalogue
# ══════════════════════════════════════════════════════════════════

## **Acceptance 5.** The rune half of the table is a derivation the design deliberately did **not** make
##  structural — it is written out as four rows and checked here instead. Add a fourth rune to
##  `Tuning.ELEM_ALL` and forget the row and this goes red, which is the entire point.
func _the_catalogue_is_the_rune_pool_plus_one_body_unlock(t) -> void:
	var rune_rows: Array[int] = []
	var buyable_runes: Array[int] = []
	for id: int in UnlockDefs.ids():
		var r := UnlockDefs.rune_of(id)
		if r < 0:
			continue
		rune_rows.append(r)
		if UnlockDefs.is_for_sale(id):
			buyable_runes.append(r)
	t.eq(rune_rows, Array(Tuning.ELEM_ALL, TYPE_INT, "", null),
		"목록의 룬 줄이 정확히 룬 풀 전체다 (순서까지 — 칩이 이 순서로 그려진다)")

	# **`ELEM_ALL` minus the starting kit** — 무는 이미 갖고 시작하니 팔 것이 없다.
	var want_buyable: Array[int] = []
	var kit := Progress._starting_runes()
	for r: int in Tuning.ELEM_ALL:
		if not kit.has(r):
			want_buyable.append(r)
	t.eq(buyable_runes, want_buyable,
		"팔 수 있는 룬이 정확히 '룬 풀 빼기 시작 꾸러미'다 (%s)" % str(want_buyable))
	t.ok(want_buyable.size() == 2, "그 결과가 두 개다 (불·물 — 전제)")

	# The body axis: exactly one unlock, and it grants no rune.
	var body := UnlockDefs.ids_for_axis(UnlockDefs.AXIS_BODY)
	t.eq(body, [UnlockDefs.UNLOCK_DOUBLE_JUMP] as Array[int], "신체 줄엔 2단 점프 하나뿐이다")
	t.eq(UnlockDefs.rune_of(UnlockDefs.UNLOCK_DOUBLE_JUMP), -1, "2단 점프는 룬을 안 준다 (-1)")
	t.ok(UnlockDefs.name_of(UnlockDefs.UNLOCK_DOUBLE_JUMP) != "", "2단 점프엔 화면에 쓸 이름이 있다")
	for id: int in UnlockDefs.ids():
		if UnlockDefs.rune_of(id) >= 0:
			t.eq(UnlockDefs.name_of(id), "",
				"룬 줄은 제 이름을 안 들고 있다 (이름의 집은 Fx.ELEM_NAMES 하나다)")

	# **The axis keys are `Fx.RESEARCH_ROWS`' own first column**, not a second spelling of them.
	var keys: Array[String] = []
	for entry: Array in Fx.RESEARCH_ROWS:
		keys.append(String(entry[0]))
	t.ok(keys.has(UnlockDefs.AXIS_ITEM), "아이템 축이 연구창의 줄 키와 같은 문자열이다")
	t.ok(keys.has(UnlockDefs.AXIS_BODY), "신체 축도 그렇다")
	t.eq(String(Fx.RESEARCH_ROWS[ROW_ITEM][0]), UnlockDefs.AXIS_ITEM, "아이템 줄은 %d번째다" % ROW_ITEM)
	t.eq(String(Fx.RESEARCH_ROWS[ROW_BODY][0]), UnlockDefs.AXIS_BODY, "신체 줄은 %d번째다" % ROW_BODY)


## **Acceptance 1's tail.** An id nobody defined has to answer "no" at every door, not crash at one and
##  return something plausible at another.
func _an_id_outside_the_table_answers_no_everywhere(t) -> void:
	var ghost := 9999
	t.ok(not UnlockDefs.has_id(ghost), "표에 없는 id는 없는 것으로 읽힌다")
	t.ok(not UnlockDefs.is_for_sale(ghost), "표에 없는 id는 팔지 않는다")
	t.eq(UnlockDefs.rune_of(ghost), -1, "표에 없는 id는 룬을 안 준다")
	t.eq(UnlockDefs.axis_of(ghost), "", "표에 없는 id는 줄이 없다")
	var pr := Progress.new()
	pr.gems = 100
	t.ok(not pr.can_buy(ghost), "표에 없는 id는 살 수 없다")
	t.ok(not pr.buy(ghost), "사려고 해도 false다")
	t.eq(pr.gems, 100, "그리고 원석이 한 톨도 안 나간다 (없는 id로 지갑이 새지 않는다)")


# ══════════════════════════════════════════════════════════════════
#  Buying
# ══════════════════════════════════════════════════════════════════

## **Acceptance 1.** The three real unlocks are buyable and 무 is not — and 무 is not buyable because the
##  **catalogue** says so, not because the player happens to own it.
func _a_fresh_bench_sells_three_things_and_not_the_none_rune(t) -> void:
	var pr := Progress.new()
	t.ok(pr.can_buy(UnlockDefs.UNLOCK_RUNE_FIRE), "갓 만든 진행 상태에서 불 룬을 살 수 있다")
	t.ok(pr.can_buy(UnlockDefs.UNLOCK_RUNE_WATER), "물 룬도 살 수 있다")
	t.ok(pr.can_buy(UnlockDefs.UNLOCK_DOUBLE_JUMP), "2단 점프도 살 수 있다")
	t.ok(not pr.can_buy(UnlockDefs.UNLOCK_RUNE_NONE), "무 룬은 팔지 않는다 (표가 그렇게 말한다)")
	# **`can_buy` does not look at the wallet** — affordability is a separate answer with separate art
	#  (a dim chip, not a missing one).
	t.eq(pr.gems, 0, "이 시점의 원석은 0이다 (전제 — can_buy가 지갑을 안 본다는 뜻)")


## **Acceptances 2, 3 and 4.** The price is pinned as a literal — a bound read off the thing it bounds
##  proves nothing.
func _the_price_is_ten_and_it_is_charged_exactly_once(t) -> void:
	t.eq(Progress.GEMS_PER_UNLOCK, 10, "해금 하나가 10원석이다 (리터럴로 못 박는다)")

	# One short: nothing moves at all.
	var poor := Progress.new()
	poor.gems = Progress.GEMS_PER_UNLOCK - 1
	t.ok(not poor.buy(UnlockDefs.UNLOCK_RUNE_WATER), "9원석으로는 못 산다 (false)")
	t.eq(poor.gems, Progress.GEMS_PER_UNLOCK - 1, "그리고 원석이 그대로다 (반쯤 사지지 않는다)")
	t.ok(not poor.is_unlocked(UnlockDefs.UNLOCK_RUNE_WATER), "해금도 안 기록된다")
	t.ok(not poor.owns_rune(Tuning.ELEM_WATER), "룬도 안 들어온다")

	# Exactly enough: it takes, and it takes exactly the price.
	var pr := Progress.new()
	pr.gems = Progress.GEMS_PER_UNLOCK
	t.ok(pr.buy(UnlockDefs.UNLOCK_RUNE_WATER), "10원석이면 산다 (true)")
	t.eq(pr.gems, 0, "정확히 10원석만 빠진다")
	t.ok(pr.is_unlocked(UnlockDefs.UNLOCK_RUNE_WATER), "해금이 기록된다")
	t.ok(pr.owns_rune(Tuning.ELEM_WATER), "그리고 그 자리에서 룬이 손에 들어온다 (grant_rune을 탄다)")

	# **Acceptance 4** — the same unlock twice charges once.
	var twice := Progress.new()
	twice.gems = Progress.GEMS_PER_UNLOCK * 2
	t.ok(twice.buy(UnlockDefs.UNLOCK_DOUBLE_JUMP), "2단 점프를 처음 사면 산다")
	t.ok(not twice.buy(UnlockDefs.UNLOCK_DOUBLE_JUMP), "같은 걸 또 사려 하면 false다")
	t.eq(twice.gems, Progress.GEMS_PER_UNLOCK, "그래서 20원석에서 10원석만 나갔다 (두 번 안 물린다)")


## **Acceptance 8.** A purchase is a purchase — it must not quietly move the run's own counters.
func _buying_moves_nothing_but_gems_and_the_unlock(t) -> void:
	var pr := Progress.new()
	pr.gems = Progress.GEMS_PER_UNLOCK
	pr.xp = 37
	pr.level = 2
	pr.money = 55
	pr.pending_picks = 1
	pr.run_ticks = 400
	pr.damage_dealt = 123
	pr.set_boss_reward_pending(3)

	t.ok(pr.buy(UnlockDefs.UNLOCK_RUNE_FIRE), "불 룬을 샀다 (전제)")
	t.eq(pr.xp, 37, "경험치가 그대로다")
	t.eq(pr.level, 2, "레벨이 그대로다")
	t.eq(pr.money, 55, "돈이 그대로다")
	t.eq(pr.pending_picks, 1, "밀린 세 장 뽑기가 그대로다")
	t.eq(pr.run_ticks, 400, "달린 시간이 그대로다")
	t.eq(pr.damage_dealt, 123, "준 피해가 그대로다")
	t.ok(pr.is_reward_pending(3), "보스 보상 대기가 그대로다")
	t.eq(pr.dice_left, 0, "주사위는 여전히 0이고 아무도 안 건드린다")


# ══════════════════════════════════════════════════════════════════
#  Permanence — the half that dies silently
# ══════════════════════════════════════════════════════════════════

## **Acceptance 6 — the check this whole feature is built around.**
##
## **What goes red when inverted**: add `_unlocked.clear()` to `progress.reset()`. Every assertion below the
##  reset flips at once. Measured by hand before this net was declared done, not assumed.
##
## **Both kinds are driven, a rune and the double jump**, because they ride the same field but reach the game
##  through completely different paths (`_run_start_runes()` vs `air_jump_budget()`) — one surviving proves
##  nothing about the other.
func _a_purchase_survives_reset(t) -> void:
	var pr := Progress.new()
	pr.gems = Progress.GEMS_PER_UNLOCK * 3
	t.ok(pr.buy(UnlockDefs.UNLOCK_RUNE_WATER), "물 룬을 샀다 (전제)")
	t.ok(pr.buy(UnlockDefs.UNLOCK_DOUBLE_JUMP), "2단 점프도 샀다 (전제)")
	t.eq(pr.gems, Progress.GEMS_PER_UNLOCK, "30에서 20이 나가 10이 남았다 (전제)")

	pr.reset()

	t.ok(pr.is_unlocked(UnlockDefs.UNLOCK_RUNE_WATER), "달리기가 새로 시작해도 물 룬 해금이 남는다")
	t.ok(pr.is_unlocked(UnlockDefs.UNLOCK_DOUBLE_JUMP), "2단 점프 해금도 남는다")
	t.ok(pr.owns_rune(Tuning.ELEM_WATER),
		"그리고 새 달리기가 물 룬을 **손에 들고** 시작한다 (해금만 남고 룬이 빠지면 여기가 빨개진다)")
	t.eq(pr.air_jump_budget(), 1, "공중 점프도 1로 남는다")
	t.eq(pr.gems, Progress.GEMS_PER_UNLOCK, "쓴 원석이 되돌아오지 않는다 (10 그대로)")
	# The run's own counters really did revert — otherwise the reset above proved nothing.
	t.eq(pr.level, 0, "그러면서 달리기 값들은 되돌아간다 (전제 — reset이 정말 돌았다)")
	t.ok(pr.owns_rune(Tuning.ELEM_NONE), "시작 꾸러미의 무 룬은 여전히 있다")

	# **A second reset does not erode it either** — a fold that mutated the starting kit would show up here.
	pr.reset()
	t.ok(pr.owns_rune(Tuning.ELEM_WATER), "두 번째 리셋에서도 산 룬이 그대로다")
	t.eq(pr.air_jump_budget(), 1, "두 번째 리셋에서도 공중 점프가 1이다")


## **Acceptance 7.** The bull grants 불 mid-run and that grant dies with the run; buying 불 buys permanence.
##  **This is why the buy guard keys on `_unlocked`, never on `owns_rune()`** — measured from both sides.
func _a_granted_rune_and_a_bought_rune_part_ways_at_reset(t) -> void:
	# Granted only.
	var granted := Progress.new()
	granted.grant_rune(Tuning.ELEM_FIRE)
	t.ok(granted.owns_rune(Tuning.ELEM_FIRE), "황소가 준 불 룬을 그 달리기 동안엔 갖고 있다")
	t.ok(granted.can_buy(UnlockDefs.UNLOCK_RUNE_FIRE),
		"받아서 갖고 있어도 **여전히 살 수 있다** (사는 건 영속성이지 첫 접근이 아니다)")
	granted.reset()
	t.ok(not granted.owns_rune(Tuning.ELEM_FIRE), "달리기가 끝나면 받은 룬은 사라진다")
	t.ok(not granted.is_unlocked(UnlockDefs.UNLOCK_RUNE_FIRE), "받은 것은 산 것으로 기록되지 않는다")

	# Granted, then bought.
	var bought := Progress.new()
	bought.gems = Progress.GEMS_PER_UNLOCK
	bought.grant_rune(Tuning.ELEM_FIRE)
	t.ok(bought.buy(UnlockDefs.UNLOCK_RUNE_FIRE),
		"이미 받아서 갖고 있는 룬도 살 수 있다 (owns_rune으로 막았다면 여기가 빨개진다)")
	bought.reset()
	t.ok(bought.owns_rune(Tuning.ELEM_FIRE), "산 쪽은 달리기가 끝나도 남는다")
	t.ok(not bought.can_buy(UnlockDefs.UNLOCK_RUNE_FIRE), "그리고 두 번 사라고 권하지 않는다")


## **Acceptance 9.** `_gems_at_run_start` is snapshotted in `reset()`, so spending in town drops `gems` below
##  it and `gems_this_run()` reads **negative** until the next run begins. Nothing reads it there (the
##  settlement screen is closed in town), so this is pinned as a known-harmless fact rather than left to be
##  rediscovered as a bug.
func _gems_this_run_reads_negative_after_a_town_purchase(t) -> void:
	var pr := Progress.new()
	pr.gems = 12
	pr.reset()
	t.eq(pr.gems_this_run(), 0, "달리기가 막 시작하면 이번 달리기 벌이는 0이다")
	t.ok(pr.buy(UnlockDefs.UNLOCK_DOUBLE_JUMP), "마을에서 2단 점프를 샀다 (전제)")
	t.eq(pr.gems_this_run(), -Progress.GEMS_PER_UNLOCK,
		"그러면 마을에 있는 동안 '이번 달리기 벌이'가 음수로 읽힌다 (아무도 안 읽는다 · 알고 두는 값)")
	pr.reset()
	t.eq(pr.gems_this_run(), 0, "다음 달리기가 시작되면 다시 0이다 (스냅샷이 다시 찍힌다)")


# ══════════════════════════════════════════════════════════════════
#  The jump
# ══════════════════════════════════════════════════════════════════

func _floor_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, FLOOR_CY, CellGrid.W - 1, FLOOR_CY + FLOOR_DEPTH_CY - 1, Mat.STONE))
	return g


func _water_box(g: CellGrid, x0: int, x1: int, y0: int, y1: int, amount: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			g.set_water(x, y, amount)


## `net_character`'s A-series vessel: a floorless water column with the character in the middle of it.
func _submerged(amount: int) -> Array:
	var g := CellGrid.new()
	_water_box(g, WATER_CX0, WATER_CX1, WATER_CY0, WATER_CY1, amount)
	var ch := Character.new()
	ch.place(WATER_CX0 * Tuning.CELL_PX, WATER_START_Y)
	return [g, ch]


## `vy` on a frame in which the jump fired — one frame of gravity is already added inside `step()`, the same
##  reasoning `net_character`'s A-1 writes out.
func _fired_vy() -> float:
	return Character.JUMP_VY_PX + Character.GRAVITY_PX * DT


## **Acceptance 10.** The budget is a function of the permanent set, so there is no moment at which it can be
##  applied wrongly — including across a reset.
func _the_budget_is_zero_until_bought_and_one_after_every_reset(t) -> void:
	var pr := Progress.new()
	t.eq(pr.air_jump_budget(), 0, "사기 전엔 공중 점프가 0회다")
	pr.gems = Progress.GEMS_PER_UNLOCK
	t.eq(pr.air_jump_budget(), 0, "원석만 있어도 0회다 (지갑이 아니라 해금이 정한다)")
	t.ok(pr.buy(UnlockDefs.UNLOCK_DOUBLE_JUMP), "샀다 (전제)")
	t.eq(pr.air_jump_budget(), 1, "사면 1회다")
	pr.reset()
	t.eq(pr.air_jump_budget(), 1, "리셋해도 1회다")


## **Acceptance 12 — the one that proves the water axis was not disturbed.**
##
## **Absolute values, not an A/B against a second character.** CLAUDE.md: comparing two paths catches
##  "diverged" and never "vanished" — fold both into one and `scan == scan` stays green. So the four A-series
##  sequences are driven with the budget left at its default 0 and the **exact same trajectories** asserted
##  that `net_character` asserts, and `_air_jumps_left` is read as 0 throughout.
func _with_no_unlock_the_jump_is_exactly_what_it_was(t) -> void:
	var expected := _fired_vy()

	# A-1 — three air jumps in a row in deep water.
	var a1 := _submerged(Tuning.WATER_MAX)
	var g1: CellGrid = a1[0]
	var ch1: Character = a1[1]
	t.eq(ch1.air_jump_budget, 0, "해금 없는 캐릭터의 공중 점프 예산이 0이다 (전제 — 기본값)")
	ch1.step(g1, DT, 0.0, false, false)
	t.ok(not ch1.on_ground, "물기둥엔 바닥이 없어 공중이다 (전제)")
	for i in 3:
		ch1.step(g1, DT, 0.0, true, true)
		t.eq(ch1.vy, expected, "A-1 그대로: %d번째 물속 점프가 발사된다" % [i + 1])
	t.eq(ch1.get("_air_jumps_left"), 0, "그 세 번 동안 예산은 0에서 안 움직인다 (분기 자체가 닿지 않는다)")

	# A-2 — the boundary pair, 32 vs 33.
	var shallow := _submerged(Tuning.WATER_WET)
	var g0: CellGrid = shallow[0]
	var ch0: Character = shallow[1]
	ch0.step(g0, DT, 0.0, false, false)
	ch0.step(g0, DT, 0.0, true, true)
	t.ok(ch0.vy != expected, "A-2 그대로: 물 %d(얕음)에서는 안 먹는다" % Tuning.WATER_WET)
	var deep := _submerged(Tuning.WATER_WET + 1)
	var g2: CellGrid = deep[0]
	var ch2: Character = deep[1]
	ch2.step(g2, DT, 0.0, false, false)
	ch2.step(g2, DT, 0.0, true, true)
	t.eq(ch2.vy, expected, "A-2 그대로: 한 톨 더 깊으면 먹는다")

	# A-3 — leaving the water blocks the very next frame.
	var a3 := _submerged(Tuning.WATER_MAX)
	var g3: CellGrid = a3[0]
	var ch3: Character = a3[1]
	ch3.step(g3, DT, 0.0, false, false)
	ch3.step(g3, DT, 0.0, true, true)
	t.eq(ch3.vy, expected, "A-3 전제: 물속에서 먹는다")
	_water_box(g3, WATER_CX0, WATER_CX1, WATER_CY0, WATER_CY1, 0)
	var vy_before := ch3.vy
	ch3.step(g3, DT, 0.0, true, true)
	t.eq(ch3.vy, vy_before + Character.GRAVITY_PX * DT,
		"A-3 그대로: 물이 사라진 바로 다음 프레임엔 안 먹는다 (중력만 더해진다)")

	# A-4 — the foot row alone is enough.
	var g4 := CellGrid.new()
	var ch4 := Character.new()
	var px := 400 * Tuning.CELL_PX
	var py := 200 * Tuning.CELL_PX
	ch4.place(px, py)
	var cx0 := floori(px / float(Tuning.CELL_PX))
	var cx1 := floori((px + Character.W_PX - 1) / float(Tuning.CELL_PX))
	var cy1 := floori((py + Character.H_PX) / float(Tuning.CELL_PX))
	t.eq(g4.mat_at(cx0, cy1 - 1), Mat.EMPTY, "A-4 전제: 상자의 마지막 줄엔 물이 없다")
	for x in range(cx0, cx1 + 1):
		g4.set_water(x, cy1, Tuning.WATER_MAX)
	ch4.step(g4, DT, 0.0, true, true)
	t.ok(not ch4.on_ground, "A-4 전제: 공중이다")
	t.eq(ch4.vy, expected, "A-4 그대로: 발밑 한 줄만 깊어도 먹는다")


## **Acceptance 11 — buying it is felt with no reset and no hook.**
##
## The character stands, ground-jumps (the ground pays, so the budget is untouched), then in mid-air presses
## again — that one works and spends. A third press in the same airtime does not.
func _the_bought_air_jump_fires_once_per_airtime(t) -> void:
	var g := _floor_grid()
	var ch := Character.new()
	ch.place(160, REST_Y)
	ch.air_jump_budget = 1
	ch.step(g, DT, 0.0, false, false)
	t.ok(ch.on_ground, "바닥에 서 있다 (전제)")
	t.eq(ch.get("_air_jumps_left"), 1, "서 있는 동안 예산이 1로 채워진다")

	var expected := _fired_vy()
	ch.step(g, DT, 0.0, true, true)
	t.eq(ch.vy, expected, "첫 점프(땅)가 발사된다")
	t.eq(ch.get("_air_jumps_left"), 1, "땅이 냈으니 예산은 안 깎인다")

	# Fly up out of coyote range with no press, so the second jump can only be the air jump.
	for _i in 20:
		ch.step(g, DT, 0.0, false, true)
	t.ok(not ch.on_ground, "공중이다 (전제)")
	t.eq(ch.get("_coyote_left"), 0.0, "코요테 창도 다 닫혔다 (전제 — 두 번째 점프가 코요테일 리 없다)")

	ch.step(g, DT, 0.0, true, true)
	t.eq(ch.vy, expected, "공중에서 한 번 더 뛴다 (산 것이 리셋 없이 바로 느껴진다)")
	t.eq(ch.get("_air_jumps_left"), 0, "그리고 그때 예산이 깎인다")
	t.eq(ch.air_jump_flash_left, Character.AIR_JUMP_FLASH_TICKS, "공중 점프 표시가 켜진다")

	for _i in 10:
		ch.step(g, DT, 0.0, false, true)
	var vy_before := ch.vy
	ch.step(g, DT, 0.0, true, true)
	t.eq(ch.vy, vy_before + Character.GRAVITY_PX * DT,
		"같은 체공에서 세 번째는 안 먹는다 (중력만 더해진다 — 예산이 하나뿐이다)")


## **Acceptance 15.** The ground is the only refill site. Water must not be a second one — that is what makes
##  the underwater no-op a property rather than a coincidence.
func _the_ground_refills_the_budget_and_water_does_not(t) -> void:
	var g := _floor_grid()
	var ch := Character.new()
	ch.place(160, REST_Y)
	ch.air_jump_budget = 1
	ch.step(g, DT, 0.0, false, false)
	t.eq(ch.get("_air_jumps_left"), 1, "땅에서 채워졌다 (전제)")

	# Spend it in the air.
	ch.step(g, DT, 0.0, true, true)          # ground jump
	for _i in 20:
		ch.step(g, DT, 0.0, false, true)
	ch.step(g, DT, 0.0, true, true)          # the air jump
	t.eq(ch.get("_air_jumps_left"), 0, "공중 점프로 다 썼다 (전제)")

	# Land again.
	for _i in 80:
		ch.step(g, DT, 0.0, false, false)
	t.ok(ch.on_ground, "다시 착지했다 (전제)")
	t.eq(ch.get("_air_jumps_left"), 1, "땅에 닿으면 다시 채워진다")

	# **Water does not refill.** Spend it over land, then drop the character into a water column with it spent.
	var made := _submerged(Tuning.WATER_MAX)
	var wg: CellGrid = made[0]
	var wch: Character = made[1]
	wch.air_jump_budget = 1
	wch.set("_air_jumps_left", 0)
	wch.step(wg, DT, 0.0, false, false)
	t.eq(wch.get("_air_jumps_left"), 0, "물속에 있어도 예산이 다시 안 채워진다 (땅만 채운다)")

	# **The same rule from the other side**: a character that has never touched ground has 0 to begin with,
	#  even holding the unlock. Deliberate — the budget is filled by landing, not by owning.
	var never := _submerged(Tuning.WATER_MAX)
	var ng: CellGrid = never[0]
	var nch: Character = never[1]
	nch.air_jump_budget = 1
	nch.step(ng, DT, 0.0, false, false)
	t.eq(nch.get("_air_jumps_left"), 0, "땅을 한 번도 안 밟았으면 해금이 있어도 예산이 0이다")


## **Acceptance 13 — the unlock is a structural no-op underwater.**
##
## **What goes red when inverted**: drop the `not in_water` guard on the spend in `character.step()`. Water
##  then charges the budget on every jump and the count below walks 1 → 0 → −1 → −2.
##
## **The design doc asked for a second inversion here and it is not written, on purpose.** Acceptance 13 of
##  `research-bench-unlocks.md` also asks that moving `_air_jumps_left > 0` ahead of `in_water` in the `or`
##  chain go red. **It was run and everything stayed green, and that is correct**: a disjunction's truth value
##  is order-independent and both operands are pure reads, so the reorder is a semantic no-op that no check
##  can detect. Claiming a check covers it would be exactly the false guarantee CLAUDE.md's "no fake nets"
##  section is about. `character.gd`'s own box at the `or` chain records the same finding.
func _underwater_the_unlock_is_a_no_op(t) -> void:
	var made := _submerged(Tuning.WATER_MAX)
	var g: CellGrid = made[0]
	var ch: Character = made[1]
	ch.air_jump_budget = 1
	# **The budget is seeded by hand because this vessel has no floor at all** — the ground is the only refill
	#  site, so a character that has never touched ground would sit at 0 and this check would then measure
	#  nothing (a budget that was never there cannot be shown to survive). This is the state of someone who
	#  walked off the ground and into the water with the jump unspent, which is how it is actually reached.
	ch.set("_air_jumps_left", 1)
	ch.step(g, DT, 0.0, false, false)
	t.ok(not ch.on_ground, "물기둥엔 바닥이 없다 (전제)")
	t.eq(ch.get("_air_jumps_left"), 1, "물에 들어온 뒤에도 예산이 그대로 1이다 (물은 채우지도 쓰지도 않는다)")

	var expected := _fired_vy()
	for i in 5:
		ch.step(g, DT, 0.0, true, true)
		t.eq(ch.vy, expected, "물속 %d번째 점프가 먹는다 (원래 무제한이다)" % [i + 1])
		t.eq(ch.get("_air_jumps_left"), 1,
			"그리고 %d번째까지 예산이 한 번도 안 깎인다 (물이 먼저 조건을 만족시킨다)" % [i + 1])
	t.eq(ch.air_jump_flash_left, 0, "물속 점프는 공중 점프 표시도 안 켠다 (공중 점프가 아니다)")


## **Acceptance 14.** `water-jump-and-escape.md`'s acceptance 3 ("leaving the water re-limits it") is about
##  *limited*, not *zero* — with the unlock bought it is one jump wide, not none. **A builder must not "fix"
##  this**: it is the unlock doing exactly what it says.
func _leaving_the_water_gives_exactly_one_more_jump(t) -> void:
	var made := _submerged(Tuning.WATER_MAX)
	var g: CellGrid = made[0]
	var ch: Character = made[1]
	ch.air_jump_budget = 1
	# Seeded for the same reason as the check above — this vessel has no ground to refill from.
	ch.set("_air_jumps_left", 1)
	ch.step(g, DT, 0.0, false, false)
	var expected := _fired_vy()
	ch.step(g, DT, 0.0, true, true)
	t.eq(ch.vy, expected, "물속에서 뛴다 (전제)")
	t.eq(ch.get("_air_jumps_left"), 1, "예산은 그대로다 (전제)")

	# The water vanishes; the character is still airborne (this vessel has no floor).
	_water_box(g, WATER_CX0, WATER_CX1, WATER_CY0, WATER_CY1, 0)
	t.ok(not ch.on_ground, "물이 사라져도 여전히 공중이다 (전제 — 바닥이 없다)")

	ch.step(g, DT, 0.0, true, true)
	t.eq(ch.vy, expected, "물 밖으로 나온 뒤 정확히 한 번 더 뛴다 (산 공중 점프 하나)")
	t.eq(ch.get("_air_jumps_left"), 0, "그 한 번으로 예산을 다 쓴다")

	var vy_before := ch.vy
	ch.step(g, DT, 0.0, true, true)
	t.eq(ch.vy, vy_before + Character.GRAVITY_PX * DT,
		"그 다음은 막힌다 (물 밖에선 다시 제한된다 — 한 번 넓어졌을 뿐이다)")


## **Acceptance 27 — the trap the design caught late.**
##
## `on_tick()` **returns early** while invulnerable. A flash counter decremented below that line stops ticking
## for the whole invulnerability window, so an air jump taken just after being hit leaves the ring frozen on
## screen. Nothing barks.
##
## **What goes red when inverted**: move the decrement below the `if invuln_left > 0:` branch. The counter
## then sits at its full value for every tick measured here.
func _the_flash_counts_down_while_invulnerable(t) -> void:
	var g := _floor_grid()
	var ch := Character.new()
	ch.place(160, REST_Y)
	ch.air_jump_budget = 1
	ch.step(g, DT, 0.0, false, false)
	ch.step(g, DT, 0.0, true, true)              # ground jump
	for _i in 20:
		ch.step(g, DT, 0.0, false, true)
	ch.step(g, DT, 0.0, true, true)              # the air jump
	t.eq(ch.air_jump_flash_left, Character.AIR_JUMP_FLASH_TICKS, "공중 점프 표시가 켜졌다 (전제)")

	# Get hit, so `on_tick` takes its early return from here on.
	t.ok(ch.take_hit(Character.DAMAGE_HIT, true), "맞았다 (전제)")
	t.eq(ch.invuln_left, Character.INVULN_TICKS, "무적이 켜졌다 (전제)")
	t.ok(Character.INVULN_TICKS >= Character.AIR_JUMP_FLASH_TICKS,
		"무적 창이 표시 창보다 짧지 않다 (전제 — 그래야 이 검사가 조기 return을 실제로 통과한다)")

	var spell := SpellSim.new()
	for i in Character.AIR_JUMP_FLASH_TICKS:
		ch.on_tick(spell)
		t.eq(ch.air_jump_flash_left, Character.AIR_JUMP_FLASH_TICKS - (i + 1),
			"무적 중에도 표시가 한 틱씩 줄어든다 (%d틱째)" % [i + 1])
	t.eq(ch.air_jump_flash_left, 0, "무적이 아직 안 끝났어도 표시는 제때 0이 된다 (화면에 얼어붙지 않는다)")
	# **The counter has a floor** — an unclamped decrement would run negative forever and the screen would
	#  read "not showing" only by accident of a `> 0` test somewhere else.
	ch.on_tick(spell)
	t.eq(ch.air_jump_flash_left, 0, "0에서 더 내려가지 않는다")


# ══════════════════════════════════════════════════════════════════
#  Layout and the hit test
# ══════════════════════════════════════════════════════════════════

## **Acceptance 21.** Literal bounds at the real window size — `MIN_CHIP_W_PX` is written down here, not read
##  back out of the function being measured.
func _chip_rects_sit_in_the_row_clear_of_the_slot_and_do_not_overlap(t) -> void:
	var sz: Vector2 = Fx.RESEARCH_RECT.size
	t.eq(sz, Vector2(480.0, 400.0), "연구창이 480x400이다 (전제 — 아래 40px 하한이 이 크기의 값이다)")
	var rows := Layout.rows(sz)
	t.eq(rows.size(), 4, "줄이 넷이다 (전제)")
	# **Driven against the real axes, not an invented count.** Chips are now sized to their own labels, so
	#  "3 chips" is only meaningful as *the item row's three*. A bare count would measure nothing real.
	var pr := Progress.new()
	for pair: Array in [[ROW_ITEM, UnlockDefs.AXIS_ITEM], [ROW_BODY, UnlockDefs.AXIS_BODY]]:
		var row_i: int = pair[0]
		var ids := _ids(pair[1])
		var row: Rect2 = rows[row_i]
		t.eq(row.size.y, 35.0, "%d번 줄의 높이가 35px다 (문서의 손계산과 같은 값 — 리터럴)" % row_i)
		var slot := Layout.slot(row)
		var chips := Layout.unlock_chip_rects(row, _widths(ids, pr))
		t.eq(chips.size(), ids.size(), "%d번 줄에 해금 수(%d)만큼 칩이 나온다" % [row_i, ids.size()])
		for c in chips.size():
			var r: Rect2 = chips[c]
			t.ok(row.encloses(r), "%d번 줄 칩 %d(%s~%s)가 줄 안이다" % [row_i, c, r.position, r.end])
			t.ok(not r.intersects(slot), "그 칩이 슬롯 틀(%s~%s)을 안 침범한다" % [slot.position, slot.end])
			t.ok(r.size.x >= MIN_CHIP_W_PX,
				"그 칩이 %.0fpx 이상 넓다 (실측 %.1fpx)" % [MIN_CHIP_W_PX, r.size.x])
			t.ok(r.size.y > 0.0, "그 칩에 높이가 있다 (%.1fpx)" % r.size.y)
		for i in chips.size():
			for j in range(i + 1, chips.size()):
				t.ok(not chips[i].intersects(chips[j]), "%d번 줄에서 칩 %d·%d가 안 겹친다" % [row_i, i, j])
		t.eq(Layout.unlock_chip_rects(row, PackedFloat32Array()).size(), 0, "%d번 줄에 0개를 요청하면 없다" % row_i)

	# **The contract verify-look's complaint actually names: a chip hugs its label.** The old rects divided
	#  the row, so the body row's single chip came out **299px** for a short label — *"a stretched empty box
	#  reads as a text input, not a button"*. Now each chip is its own text plus the inset, floored.
	#
	# **Asserted as the equation, not as a ratio.** A ratio between the widest and narrowest chip was tried
	#  first and it is a proxy: it fails on `무` being genuinely one character (21px of text) while nothing is
	#  stretched at all. **The equation is the thing that was wrong before and is right now.**
	var pr2 := Progress.new()
	for pair2: Array in [[ROW_ITEM, UnlockDefs.AXIS_ITEM], [ROW_BODY, UnlockDefs.AXIS_BODY]]:
		var ri: int = pair2[0]
		var ids2 := _ids(pair2[1])
		var w2 := _widths(ids2, pr2)
		var rects2 := Layout.unlock_chip_rects(rows[ri], w2)
		for k in rects2.size():
			var want: float = maxf(w2[k] + Layout.CHIP_TEXT_INSET_PX * 2.0, Layout.CHIP_MIN_W_PX)
			t.ok(absf(rects2[k].size.x - want) < 0.01,
				"%d번 줄 칩 %d의 폭이 제 글자폭(%.1f)+여백이다 (%.1f) — 줄을 나눠 가진 게 아니다"
					% [ri, k, w2[k], rects2[k].size.x])
		# **And no chip spans the whole band any more** — that is the shape of the 299px complaint.
		var band := Layout.chip_band(rows[ri])
		for r2: Rect2 in rects2:
			t.ok(r2.size.x < band.size.x * 0.9,
				"%d번 줄 칩이 띠 전체(%.0fpx)를 차지하지 않는다 (%.0fpx)" % [ri, band.size.x, r2.size.x])


## **Acceptance 22.** Centres **and** the four inset corners — `net_pick`'s own finding is that a hit box
##  shrunk on one side survives a centre-only check entirely.
func _chip_at_reads_the_same_rects_as_chip_rects(t) -> void:
	var rows := Layout.rows(Fx.RESEARCH_RECT.size)
	var pr := Progress.new()
	for pair: Array in [[ROW_ITEM, UnlockDefs.AXIS_ITEM], [ROW_BODY, UnlockDefs.AXIS_BODY]]:
		var row_i: int = pair[0]
		var ids := _ids(pair[1])
		var row: Rect2 = rows[row_i]
		var w := _widths(ids, pr)
		var chips := Layout.unlock_chip_rects(row, w)
		for i in chips.size():
			var r := chips[i]
			t.eq(Layout.unlock_chip_at(row, w, r.get_center()), i,
				"%d번 줄에서 칩 %d 한가운데를 찍으면 %d다" % [row_i, i, i])
			for corner: Vector2 in [
					r.position + Vector2(CORNER_INSET_PX, CORNER_INSET_PX),
					Vector2(r.end.x - CORNER_INSET_PX, r.position.y + CORNER_INSET_PX),
					r.position + Vector2(CORNER_INSET_PX, r.size.y - CORNER_INSET_PX),
					r.end - Vector2(CORNER_INSET_PX, CORNER_INSET_PX),
			]:
				t.eq(Layout.unlock_chip_at(row, w, corner), i,
					"칩 %d의 안쪽 모서리(%s)를 찍어도 %d다" % [i, corner, i])
		t.eq(Layout.unlock_chip_at(row, w, Vector2(-50.0, -50.0)), -1,
			"%d번 줄에서 창 밖을 찍으면 -1이다" % row_i)
		# **Above the band is a miss** — the chips are the row's lower half, and the name line above them
		#  must not be pressable.
		t.eq(Layout.unlock_chip_at(row, w, Vector2(row.get_center().x, row.position.y + 1.0)), -1,
			"%d번 줄에서 이름 줄(윗절반)을 찍으면 -1이다" % row_i)
		# **The gap between chips is a miss too** — content-sized chips leave real space between them, and a
		#  click there must buy nothing. With the old row-divided rects there was no such space to test.
		if chips.size() >= 2:
			var gap_x := chips[0].end.x + Layout.CHIP_GAP_PX * 0.5
			t.eq(Layout.unlock_chip_at(row, w, Vector2(gap_x, row.end.y - 4.0)), -1,
				"%d번 줄에서 칩 사이 틈을 찍으면 -1이다 (내용 맞춤이라 진짜 틈이 생긴다)" % row_i)
		t.eq(Layout.unlock_chip_at(row, PackedFloat32Array(), row.get_center()), -1,
			"칩이 0개면 어디를 찍어도 -1이다")


# ══════════════════════════════════════════════════════════════════
#  What a chip says
# ══════════════════════════════════════════════════════════════════

## **Acceptance 23**, driven as a table.
func _chip_state_walks_the_whole_table(t) -> void:
	var fresh := Progress.new()
	t.eq(ResearchWindow.chip_state(UnlockDefs.UNLOCK_RUNE_NONE, fresh), ResearchWindow.CHIP_FIXED,
		"갓 시작하면 무 룬은 고정 칩이다 (팔지 않는다)")
	for id: int in [UnlockDefs.UNLOCK_RUNE_FIRE, UnlockDefs.UNLOCK_RUNE_WATER,
			UnlockDefs.UNLOCK_DOUBLE_JUMP]:
		t.eq(ResearchWindow.chip_state(id, fresh), ResearchWindow.CHIP_SHORT,
			"갓 시작하면 %d번 해금은 원석 부족 칩이다" % id)

	var rich := Progress.new()
	rich.gems = Progress.GEMS_PER_UNLOCK
	t.eq(ResearchWindow.chip_state(UnlockDefs.UNLOCK_RUNE_NONE, rich), ResearchWindow.CHIP_FIXED,
		"원석이 10이어도 무 룬은 여전히 고정이다 (지갑이 표를 못 이긴다)")
	for id: int in [UnlockDefs.UNLOCK_RUNE_FIRE, UnlockDefs.UNLOCK_RUNE_WATER,
			UnlockDefs.UNLOCK_DOUBLE_JUMP]:
		t.eq(ResearchWindow.chip_state(id, rich), ResearchWindow.CHIP_BUYABLE,
			"원석이 딱 10이면 %d번 해금이 살 수 있는 칩이다" % id)

	# **9원석 — the boundary.** Measuring only at 0 and 10 would pass with the price read as `> 9` or `>= 11`.
	var almost := Progress.new()
	almost.gems = Progress.GEMS_PER_UNLOCK - 1
	t.eq(ResearchWindow.chip_state(UnlockDefs.UNLOCK_RUNE_WATER, almost), ResearchWindow.CHIP_SHORT,
		"9원석이면 아직 부족 칩이다 (경계)")

	var bought := Progress.new()
	bought.gems = Progress.GEMS_PER_UNLOCK * 3
	t.ok(bought.buy(UnlockDefs.UNLOCK_RUNE_WATER), "물 룬을 샀다 (전제)")
	t.eq(ResearchWindow.chip_state(UnlockDefs.UNLOCK_RUNE_WATER, bought), ResearchWindow.CHIP_UNLOCKED,
		"산 뒤엔 물 룬이 해금된 칩이다")
	t.eq(ResearchWindow.chip_state(UnlockDefs.UNLOCK_RUNE_FIRE, bought), ResearchWindow.CHIP_BUYABLE,
		"나머지는 안 변한다 (불 룬은 여전히 살 수 있다 — 20원석 남음)")
	t.eq(ResearchWindow.chip_state(UnlockDefs.UNLOCK_RUNE_NONE, bought), ResearchWindow.CHIP_FIXED,
		"무 룬도 안 변한다")

	# **A null `Progress` is not pressable** — the same fallback `row_state()` holds.
	t.eq(ResearchWindow.chip_state(UnlockDefs.UNLOCK_RUNE_WATER, null), ResearchWindow.CHIP_SHORT,
		"진행 상태가 없으면 살 수 있는 칩으로 안 읽힌다 (터지지도 않는다)")
	t.eq(ResearchWindow.chip_state(UnlockDefs.UNLOCK_RUNE_NONE, null), ResearchWindow.CHIP_FIXED,
		"진행 상태가 없어도 무 룬은 고정이다 (표만 보면 답이 나온다)")


## **The 잠김 marker and the price are two different questions**, and the bull is where they come apart:
##  granted 불 is owned (so no 잠김) and still buyable (so the price stays on).
##
## **This is also what keeps `net_town`'s two counting checks green untouched** — they read `row_state()` and
##  `Stage.research_text()`, neither of which this feature moved, and the price suffix lives only on chips.
func _a_granted_rune_still_shows_its_price_but_not_the_lock(t) -> void:
	var pr := Progress.new()
	var locked := Fx.RESEARCH_LOCKED_TEXT
	var price := "%d" % Progress.GEMS_PER_UNLOCK

	var fire_before := ResearchWindow.chip_text(UnlockDefs.UNLOCK_RUNE_FIRE, pr)
	t.ok(fire_before.contains(str(Fx.ELEM_NAMES[Tuning.ELEM_FIRE])), "칩이 룬 이름을 말한다 (%s)" % fire_before)
	t.ok(fire_before.contains(locked), "안 가진 룬 칩엔 잠김이 붙는다")
	t.ok(fire_before.contains(price), "그리고 값이 붙는다")

	pr.grant_rune(Tuning.ELEM_FIRE)
	# **The state the two label rules collide in, covered rather than left implicit.** "Owned → no 잠김" and
	#  "price whenever `can_buy()`" are *both* true here, and `chip_state` has to answer anyway: ownership is
	#  not what it reads, purchase is. So a granted-but-unbought rune reads exactly like an unowned one —
	#  buyable when you can afford it, dim when you cannot.
	pr.gems = Progress.GEMS_PER_UNLOCK
	t.eq(ResearchWindow.chip_state(UnlockDefs.UNLOCK_RUNE_FIRE, pr), ResearchWindow.CHIP_BUYABLE,
		"받기만 한 룬도 원석이 있으면 살 수 있는 칩이다 (소유가 아니라 구매를 읽는다)")
	pr.gems = 0
	t.eq(ResearchWindow.chip_state(UnlockDefs.UNLOCK_RUNE_FIRE, pr), ResearchWindow.CHIP_SHORT,
		"받기만 한 룬도 원석이 없으면 부족 칩이다 (해금된 칩으로 안 읽힌다)")
	var fire_granted := ResearchWindow.chip_text(UnlockDefs.UNLOCK_RUNE_FIRE, pr)
	t.ok(not fire_granted.contains(locked),
		"황소가 준 뒤엔 잠김이 빠진다 (팔레트가 이미 풀어 준 룬을 잠겼다고 하면 모순이다)")
	t.ok(fire_granted.contains(price), "그래도 값은 남는다 (10원석이 사는 건 영속성이다)")

	pr.gems = Progress.GEMS_PER_UNLOCK
	t.ok(pr.buy(UnlockDefs.UNLOCK_RUNE_FIRE), "그걸 샀다 (전제)")
	var fire_bought := ResearchWindow.chip_text(UnlockDefs.UNLOCK_RUNE_FIRE, pr)
	t.ok(not fire_bought.contains(locked), "산 뒤에도 잠김은 없다")
	t.ok(not fire_bought.contains(price), "그리고 값도 사라진다 (두 번 사라고 안 한다)")

	# 무 — owned from boot and never for sale, so the name and nothing else, always.
	t.eq(ResearchWindow.chip_text(UnlockDefs.UNLOCK_RUNE_NONE, pr),
		str(Fx.ELEM_NAMES[Tuning.ELEM_NONE]), "무 룬 칩은 처음부터 끝까지 이름뿐이다")

	# The body chip says its own name, which does not live in `ELEM_NAMES`.
	var body := ResearchWindow.chip_text(UnlockDefs.UNLOCK_DOUBLE_JUMP, pr)
	t.ok(body.contains(UnlockDefs.name_of(UnlockDefs.UNLOCK_DOUBLE_JUMP)),
		"신체 칩이 제 이름을 말한다 (%s)" % body)
	t.ok(body.contains(locked) and body.contains(price), "그리고 아직 잠김이고 값이 붙어 있다")

	# **`row_state("item")` did not move** — `net_town`'s two checks read exactly this and must stay green.
	t.eq(ResearchWindow.row_state("item", null), Fx.RESEARCH_LOCKED_TEXT,
		"진행 상태가 없으면 아이템 줄은 여전히 잠김으로 떨어진다 (net_town의 계약)")
	var counting := Progress.new()
	var before_n := ResearchWindow.row_state("item", counting).count(locked)
	counting.grant_rune(Tuning.ELEM_FIRE)
	t.eq(before_n - ResearchWindow.row_state("item", counting).count(locked), 1,
		"룬 하나를 받으면 아이템 줄의 잠김이 정확히 하나 줄어든다 (net_town의 계약)")


# ══════════════════════════════════════════════════════════════════
#  Pressing one
# ══════════════════════════════════════════════════════════════════

## `net_pick._click`'s recipe verbatim — the same event shape `_gui_input`'s own guard checks, so a wrong
## button or a release event would silently do nothing here too, exactly as in play.
func _click(win: Control, pos: Vector2) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = pos
	win.call("_gui_input", mb)


## Where the chip for `unlock_id` sits, in window-local coordinates.
## **`pr` is required, not read off the window** — chip widths depend on the label, and the label depends on
##  what has been bought (`물 잠김 10` is wider than `물`). A helper that guessed the state would point at
##  where the chip *used* to be.
func _chip_center(win: Control, row_i: int, axis: String, unlock_id: int, pr: Progress) -> Vector2:
	var row: Rect2 = Layout.rows(win.size)[row_i]
	var ids := UnlockDefs.ids_for_axis(axis)
	return Layout.unlock_chip_rects(row, _widths(ids, pr))[ids.find(unlock_id)].get_center()


## **Acceptance 18.** Untreed window, `_ready()` by hand (it only writes `position`/`size`), then real
##  `InputEventMouseButton`s at real chip centres.
##
## **What this does not prove, and it matters**: that a real click ever reaches `_gui_input` in the running
##  game. `HUD/ResearchWindow` carries `mouse_filter = IGNORE` in `stage.tscn`, and no path in this net goes
##  through the scene file, so every check here would stay green with the window unpressable. That one is
##  verify-read's, off an instantiated scene.
func _clicking_a_chip_spends_and_grants(t) -> void:
	var pr := Progress.new()
	pr.gems = Progress.GEMS_PER_UNLOCK
	var win := ResearchWindow.new()
	win.call("_ready")
	win.setup(pr)
	t.eq(win.size, Fx.RESEARCH_RECT.size, "창 크기가 자리 잡혔다 (전제 — 좌표계가 맞아야 한다)")

	# -- a chip you can afford --
	var water_at := _chip_center(win, ROW_ITEM, UnlockDefs.AXIS_ITEM, UnlockDefs.UNLOCK_RUNE_WATER, pr)
	_click(win, water_at)
	t.ok(pr.is_unlocked(UnlockDefs.UNLOCK_RUNE_WATER), "물 칩을 누르면 해금이 기록된다")
	t.ok(pr.owns_rune(Tuning.ELEM_WATER), "그리고 룬이 손에 들어온다")
	t.eq(pr.gems, 0, "원석 10이 정확히 나간다")

	# -- the same chip again: already unlocked, nothing happens --
	pr.gems = Progress.GEMS_PER_UNLOCK
	_click(win, water_at)
	t.eq(pr.gems, Progress.GEMS_PER_UNLOCK, "이미 산 칩을 다시 눌러도 원석이 안 나간다")

	# -- a chip you cannot afford --
	pr.gems = 0
	_click(win, _chip_center(win, ROW_ITEM, UnlockDefs.AXIS_ITEM, UnlockDefs.UNLOCK_RUNE_FIRE, pr))
	t.ok(not pr.is_unlocked(UnlockDefs.UNLOCK_RUNE_FIRE), "원석 0에서 불 칩을 눌러도 아무 일도 없다")
	t.eq(pr.gems, 0, "원석도 음수로 안 내려간다")

	# -- the 무 chip is never for sale, however much you hold --
	pr.gems = Progress.GEMS_PER_UNLOCK * 5
	_click(win, _chip_center(win, ROW_ITEM, UnlockDefs.AXIS_ITEM, UnlockDefs.UNLOCK_RUNE_NONE, pr))
	t.eq(pr.gems, Progress.GEMS_PER_UNLOCK * 5, "무 칩을 눌러도 원석이 안 나간다 (팔지 않는다)")
	t.ok(not pr.is_unlocked(UnlockDefs.UNLOCK_RUNE_NONE), "무 룬이 '샀다'로 기록되지도 않는다")

	# -- the body row's own chip, the same three --
	var jump_at := _chip_center(win, ROW_BODY, UnlockDefs.AXIS_BODY, UnlockDefs.UNLOCK_DOUBLE_JUMP, pr)
	pr.gems = Progress.GEMS_PER_UNLOCK
	_click(win, jump_at)
	t.ok(pr.is_unlocked(UnlockDefs.UNLOCK_DOUBLE_JUMP), "2단 점프 칩을 누르면 산다")
	t.eq(pr.air_jump_budget(), 1, "그리고 그 자리에서 공중 점프 예산이 1이 된다")
	t.eq(pr.gems, 0, "원석 10이 나간다")
	pr.gems = Progress.GEMS_PER_UNLOCK
	_click(win, jump_at)
	t.eq(pr.gems, Progress.GEMS_PER_UNLOCK, "이미 산 2단 점프를 또 눌러도 원석이 안 나간다")

	# -- a click that is not on a chip --
	var row: Rect2 = Layout.rows(win.size)[ROW_ITEM]
	_click(win, Vector2(row.get_center().x, row.position.y + 1.0))
	t.eq(pr.gems, Progress.GEMS_PER_UNLOCK, "칩이 아닌 곳(이름 줄)을 눌러도 아무 일도 없다")

	# -- a right click and a release are not presses --
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	rmb.pressed = true
	rmb.position = _chip_center(win, ROW_ITEM, UnlockDefs.AXIS_ITEM, UnlockDefs.UNLOCK_RUNE_FIRE, pr)
	win.call("_gui_input", rmb)
	t.eq(pr.gems, Progress.GEMS_PER_UNLOCK, "오른쪽 클릭으론 안 사진다")
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = rmb.position
	win.call("_gui_input", up)
	t.eq(pr.gems, Progress.GEMS_PER_UNLOCK, "버튼을 떼는 것만으론 안 사진다")

	win.free()


# ══════════════════════════════════════════════════════════════════
#  And that they are actually painted
# ══════════════════════════════════════════════════════════════════

## **Acceptance 24.** Treed and frame-pumped, capturing the hook `_draw_rows()` calls — CLAUDE.md: counting
##  `_draw()` measures the engine, not the picture.
##
## **What goes red when inverted**: delete the chip loop for either row and that row's call count is 0.
func _the_rows_really_paint_their_chips(t) -> void:
	var pr := Progress.new()
	pr.gems = Progress.GEMS_PER_UNLOCK
	var win := _CapturingResearchWindow.new()
	win.call("_ready")
	win.setup(pr)
	t.root.add_child(win)
	await t.pump_frames(3)

	var item_ids := UnlockDefs.ids_for_axis(UnlockDefs.AXIS_ITEM)
	var body_ids := UnlockDefs.ids_for_axis(UnlockDefs.AXIS_BODY)
	t.eq(item_ids.size(), 3, "아이템 줄에 칩이 셋이다 (전제)")
	t.eq(body_ids.size(), 1, "신체 줄에 칩이 하나다 (전제)")

	# **One frame's worth of calls**, taken as the tail of the list — the node redraws on every pumped frame.
	var per_frame := item_ids.size() + body_ids.size()
	t.ok(win.chip_calls.size() >= per_frame,
		"프레임을 돌리면 칩이 실제로 그려진다 (%d회 — 0이면 그리는 고리가 없는 것)" % win.chip_calls.size())
	# **Bail rather than index into an empty list.** Deleting the chip loop leaves 0 calls, and the checks
	#  below would then die on an out-of-range read — a bark, not a clean red. The line above is the one that
	#  reports it; everything after it only has meaning once there is something to inspect.
	#  (`% per_frame == 0` is deliberately *not* used as the gate: 0 satisfies it, which is exactly the
	#  "a loop whose condition is false from the start never runs the check" trap CLAUDE.md names.)
	if win.chip_calls.size() < per_frame:
		t.root.remove_child(win)
		win.queue_free()
		return
	t.eq(win.chip_calls.size() % per_frame, 0,
		"한 프레임에 정확히 %d개씩 그린다 (%d회)" % [per_frame, win.chip_calls.size()])
	var last: Array = win.chip_calls.slice(win.chip_calls.size() - per_frame)

	var rows := Layout.rows(win.size)
	var want_item := Layout.unlock_chip_rects(rows[ROW_ITEM], _widths(item_ids, pr))
	var want_body := Layout.unlock_chip_rects(rows[ROW_BODY], _widths(body_ids, pr))
	for i in item_ids.size():
		var call: Dictionary = last[i]
		t.eq(call["id"], item_ids[i], "아이템 줄 %d번 칩이 표 순서대로 %d번 해금이다" % [i, item_ids[i]])
		t.eq(call["rect"], want_item[i], "그 칩이 배치가 말한 자리에 그려진다")
		t.eq(call["state"], ResearchWindow.chip_state(item_ids[i], pr),
			"그 칩의 상태가 chip_state가 말한 값이다")
	var body_call: Dictionary = last[item_ids.size()]
	t.eq(body_call["id"], body_ids[0], "신체 줄 칩이 2단 점프다")
	t.eq(body_call["rect"], want_body[0], "그 칩도 배치가 말한 자리에 그려진다")
	t.eq(body_call["state"], ResearchWindow.CHIP_BUYABLE, "원석 10을 들고 있으니 살 수 있는 칩으로 그려진다")

	# **The state really follows the model** — buy it and the very next frame draws it differently.
	t.ok(pr.buy(UnlockDefs.UNLOCK_DOUBLE_JUMP), "2단 점프를 샀다 (전제)")
	win.chip_calls.clear()
	win.queue_redraw()
	await t.pump_frames(3)
	t.ok(win.chip_calls.size() >= per_frame, "사고 나서도 계속 그린다 (전제)")
	var after: Array = win.chip_calls.slice(win.chip_calls.size() - per_frame)
	t.eq((after[item_ids.size()] as Dictionary)["state"], ResearchWindow.CHIP_UNLOCKED,
		"산 뒤엔 신체 칩이 해금된 칩으로 그려진다 (화면이 모델을 따라온다)")

	t.root.remove_child(win)
	win.queue_free()


## **Acceptance 25.** The padlock third of `slot_row.png` finally carries meaning — and only on the two rows
##  that have a price. 점수 and 주사위 must keep the empty frame in **both** states, or the art starts
##  claiming a cost that does not exist.
func _the_padlock_is_on_the_two_rows_that_have_a_price(t) -> void:
	var pr := Progress.new()
	pr.gems = Progress.GEMS_PER_UNLOCK * 3
	var win := _CapturingResearchWindow.new()
	win.call("_ready")
	win.setup(pr)
	t.root.add_child(win)
	await t.pump_frames(3)

	var n := Fx.RESEARCH_ROWS.size()
	t.eq(n, 4, "줄이 넷이다 (전제)")
	t.ok(win.slot_calls.size() >= n, "네 줄의 슬롯 틀이 실제로 그려진다 (%d회)" % win.slot_calls.size())
	# Same guard as the chip check above, for the same reason.
	if win.slot_calls.size() < n:
		t.root.remove_child(win)
		win.queue_free()
		return
	var before: Array = win.slot_calls.slice(win.slot_calls.size() - n)
	t.ok(bool((before[ROW_ITEM] as Dictionary)["locked"]), "사기 전 아이템 줄은 자물쇠다")
	t.ok(bool((before[ROW_BODY] as Dictionary)["locked"]), "사기 전 신체 줄도 자물쇠다")
	for i in n:
		if i == ROW_ITEM or i == ROW_BODY:
			continue
		t.ok(not bool((before[i] as Dictionary)["locked"]),
			"%s 줄은 자물쇠가 아니다 (값이 없는 줄에 값이 있다고 주장하지 않는다)" % Fx.RESEARCH_ROWS[i][1])

	# **A rune the bull handed over must not take the padlock off.** This is the hazard the design names
	#  outright: key the row on `owns_rune()` instead of on "has it been bought" and a boss reward silently
	#  unlocks the bench's art — and puts it back at the next `reset()`, which reads as the game forgetting a
	#  purchase. The body row cannot catch this (it grants no rune), so it is measured on the item row here.
	pr.grant_rune(Tuning.ELEM_FIRE)
	pr.grant_rune(Tuning.ELEM_WATER)
	win.slot_calls.clear()
	win.queue_redraw()
	await t.pump_frames(3)
	t.ok(win.slot_calls.size() >= n, "룬을 받은 뒤에도 계속 그린다 (전제)")
	var granted: Array = win.slot_calls.slice(win.slot_calls.size() - n)
	t.ok(bool((granted[ROW_ITEM] as Dictionary)["locked"]),
		"황소가 룬을 줘도 아이템 줄의 자물쇠는 그대로다 (받은 것은 산 것이 아니다)")

	# Buy everything on both rows.
	t.ok(pr.buy(UnlockDefs.UNLOCK_RUNE_FIRE), "불을 샀다 (전제)")
	t.ok(pr.buy(UnlockDefs.UNLOCK_RUNE_WATER), "물을 샀다 (전제)")
	t.ok(pr.buy(UnlockDefs.UNLOCK_DOUBLE_JUMP), "2단 점프를 샀다 (전제)")
	win.slot_calls.clear()
	win.queue_redraw()
	await t.pump_frames(3)
	t.ok(win.slot_calls.size() >= n, "산 뒤에도 계속 그린다 (전제)")
	var after: Array = win.slot_calls.slice(win.slot_calls.size() - n)
	t.ok(not bool((after[ROW_ITEM] as Dictionary)["locked"]), "다 사면 아이템 줄의 자물쇠가 풀린다")
	t.ok(not bool((after[ROW_BODY] as Dictionary)["locked"]), "신체 줄의 자물쇠도 풀린다")
	for i in n:
		if i == ROW_ITEM or i == ROW_BODY:
			continue
		t.ok(not bool((after[i] as Dictionary)["locked"]),
			"%s 줄은 그 뒤에도 자물쇠가 아니다 (양쪽 상태 모두에서 false)" % Fx.RESEARCH_ROWS[i][1])

	t.root.remove_child(win)
	win.queue_free()


# ══════════════════════════════════════════════════════════════════
#  The shell path — the half a pure-function check cannot see
# ══════════════════════════════════════════════════════════════════

## **`stage.gd:408`'s `_research_window.setup(_world.progress())` is the shell's only wiring line, and a net
##  that wires the window by hand cannot see it** — CLAUDE.md names exactly this: `_wired_root` helpers
##  pre-set the `@onready` fields, so deleting the real `setup()` call stays green while the game shows an
##  empty bench.
##
## **So the scene is added to the tree and Godot runs `_ready()` itself.** No hand wiring at all: `@onready`
##  resolves from the scene's own paths, every `setup()` in `_ready()` runs for real, and what is asserted is
##  that the window holds **the very same `Progress` object** the world owns — not a copy, which would show a
##  원석 count that stopped moving the moment a boss died, with nothing barking.
##
## **`_ready()` cannot be hand-called instead**: neither `net_town._wired_root` nor
##  `net_render._wired_stage_root` wires `_terrain`/`_char_view`/`_gate_view`, so the body null-derefs on its
##  fourth line. Treeing it is not a workaround here, it is the only honest door.
## **Stands the real `stage.tscn` in the tree and lets Godot run it.** No hand wiring anywhere in this file.
##
## **That is deliberate, and it is the difference between measuring the shell and measuring the net.**
##  CLAUDE.md: a `_wired_root` helper pre-sets the `@onready` fields, so deleting the shell's own
##  `setup()` call stays green while the game shows nothing. Treeing the scene resolves every `@onready`
##  from the scene's own paths and runs every line of `_ready()` for real, so there is no pre-set field left
##  to hide anything behind.
##
## **It also survives `reset_stage()` reaching nodes no hand-written helper wires** — `_gate_view`,
##  `_terrain`, `_char_view`. `net_town._wired_root` stops at `_settlement`, which is why borrowing it here
##  barked `reset_gate() in base 'Nil'` (reported to the lead; that helper is red on its own today).
func _treed_stage(t) -> Node:
	var scene: PackedScene = load(STAGE_SCENE)
	t.ok(scene != null and scene.can_instantiate(), "무대 씬을 세웠다 (전제)")
	if scene == null or not scene.can_instantiate():
		return null
	var root := scene.instantiate()
	t.root.add_child(root)
	await t.pump_frames(2)
	return root


func _drop_stage(t, root: Node) -> void:
	t.root.remove_child(root)
	root.queue_free()


func _the_shell_really_hands_the_bench_its_progress(t) -> void:
	var root: Node = await _treed_stage(t)
	if root == null:
		return

	var win: Variant = root.get("_research_window")
	t.ok(win != null, "셸이 연구창을 잡고 있다 (전제 — @onready가 풀렸다)")
	var world: Variant = root.get("_world")
	t.ok(world != null, "셸이 세계를 잡고 있다 (전제)")
	if win == null or world == null:
		_drop_stage(t, root)
		return

	var held: Variant = (win as Object).get("_progress")
	t.ok(held != null,
		"셸이 연구창에 진행 상태를 실제로 넘겼다 (stage.gd의 _research_window.setup 한 줄 — 지우면 빈 선반이 된다)")
	t.ok(held == world.call("progress"),
		"그리고 그건 세계가 들고 있는 **바로 그 객체**다 (사본이면 원석이 안 움직인다)")

	# **Driven, not read**: buy through the window's own model and the shell's `Progress` must move with it.
	#  A copy passes the identity check above only if `==` is reference equality — this makes it a value too.
	if held != null:
		(held as Object).set("gems", Progress.GEMS_PER_UNLOCK)
		t.ok((held as Object).call("buy", UnlockDefs.UNLOCK_DOUBLE_JUMP), "연구창이 든 진행 상태로 샀다 (전제)")
		t.eq(world.call("progress").call("air_jump_budget"), 1,
			"세계의 진행 상태에서도 공중 점프가 1이다 (하나의 객체다)")

	_drop_stage(t, root)


## **The purchase has to survive the actual departure gate, not just `Progress.reset()` in isolation.**
##
## The real path is `_leave_town()` -> `reset_stage()` -> `_world.reset()` -> `Progress.reset()`, and then
## `reset_stage()` calls `_revoke_unowned_rune()` **after** it. That ordering is a contract: swap the two and
## a purchased rune is stripped out of the seat on the way through the gate. **This check is what makes the
## ordering measurable** — a bought rune parked in the seat must still be there on the other side.
##
## **And the negative, in the same vessel**: a rune the bull merely granted must be revoked. Without that
## half, "the seat survives" would pass equally for a `_revoke_unowned_rune()` that never revokes anything.
func _a_bought_rune_survives_the_departure_gate(t) -> void:
	var root: Node = await _treed_stage(t)
	if root == null:
		return
	var world: Variant = root.get("_world")
	var pr: Variant = world.call("progress")
	var circle: Variant = root.get("_circle")

	# -- bought: it comes through the gate --
	pr.set("gems", Progress.GEMS_PER_UNLOCK)
	t.ok(pr.call("buy", UnlockDefs.UNLOCK_RUNE_WATER), "마을에서 물 룬을 샀다 (전제)")
	circle.call("set_rune", 0, Tuning.ELEM_WATER)
	t.eq(circle.call("rune_at", 0), Tuning.ELEM_WATER, "물 룬을 자리에 앉혔다 (전제)")

	root.call("_leave_town")
	t.ok(not bool(root.get("_in_town")), "출발문으로 마을을 떠났다 (전제 — reset_stage가 실제로 돌았다)")
	t.ok(pr.call("owns_rune", Tuning.ELEM_WATER),
		"문을 지나고도 산 물 룬을 갖고 있다 (reset이 영구 해금을 접어 넣는다)")
	t.eq(circle.call("rune_at", 0), Tuning.ELEM_WATER,
		"그리고 자리에서도 안 뽑힌다 (_world.reset() 다음에 _revoke_unowned_rune()이 오는 순서가 계약이다)")

	# -- granted only: it is revoked at the same gate --
	pr.call("grant_rune", Tuning.ELEM_FIRE)
	circle.call("set_rune", 0, Tuning.ELEM_FIRE)
	t.eq(circle.call("rune_at", 0), Tuning.ELEM_FIRE, "황소가 준 불 룬을 자리에 앉혔다 (전제)")
	root.call("_leave_town")
	t.ok(not pr.call("owns_rune", Tuning.ELEM_FIRE), "받기만 한 불 룬은 문을 못 지난다")
	t.eq(circle.call("rune_at", 0), Tuning.ELEM_NONE,
		"그래서 자리에서 뽑혀 무로 내려온다 (revoke가 정말 도는지 — 안 돌면 여기가 빨개진다)")
	# Bought is still there after the second pass too — one gate crossing could have been luck.
	t.ok(pr.call("owns_rune", Tuning.ELEM_WATER), "두 번째로 문을 지나도 산 물 룬은 그대로다")

	_drop_stage(t, root)


## **The HUD line is not stale — and it needs no refresh line to say so.**
##
## The design asked for one added to `_update_hud()`. It is **dead code**: `HUD/Stats` (which draws
## `_town_message`) is hidden while the bench is open (`stage.gd:1239`), and `_toggle_research()` already
## rebuilds `_town_message` on **both** open and close (`stage.gd:1053`). So by the moment anyone can read
## the line, it has already been rebuilt. What is measured here is that real property, driven through
## `_interact()` — not the line that would have been added.
func _closing_the_bench_refreshes_the_town_message(t) -> void:
	var root: Node = await _treed_stage(t)
	if root == null:
		return
	var ch: Variant = root.get("_char")
	var pr: Variant = (root.get("_world") as Object).call("progress")
	var seats := TownMap.fixture_seats()
	ch.call("place", int(float(seats[Fixtures.KIND_RESEARCH]) - Character.W_PX * 0.5),
		TownMap.SPAWN_TILE.y * 16)

	root.call("_interact")
	t.ok(bool((root.get("_research_window") as Object).get("visible")), "연구창이 열렸다 (전제)")
	var opened := String(root.get("_town_message"))
	t.ok(opened.contains("연구대"), "연구대가 말했다 (전제 — %s)" % opened)

	# Buy through the window's own click path, then close the bench the way the player does.
	pr.set("gems", Progress.GEMS_PER_UNLOCK)
	var win: Control = root.get("_research_window")
	# **The window's own `_ready()` already ran — the scene is treed** — so `size` is the seat `fx_tuning`
	#  gives it rather than whatever `stage.tscn` happens to pin. Measured while this ran off an untreed root:
	#  `size` was the scene's, the chip rects came out degenerate, and **every click missed silently.**
	#  Asserting it here is what would catch a scene that pinned its own size behind the window's back.
	t.eq(win.size, Fx.RESEARCH_RECT.size, "연구창이 fx_tuning이 말한 크기로 앉는다 (전제)")
	var row: Rect2 = Layout.rows(win.size)[ROW_ITEM]
	var ids := UnlockDefs.ids_for_axis(UnlockDefs.AXIS_ITEM)
	_click(win, Layout.unlock_chip_rects(row, _widths(ids, pr))[ids.find(UnlockDefs.UNLOCK_RUNE_WATER)].get_center())
	t.ok(pr.call("is_unlocked", UnlockDefs.UNLOCK_RUNE_WATER), "창 안에서 클릭으로 물 룬을 샀다 (전제)")

	root.call("_interact")
	t.ok(not bool((root.get("_research_window") as Object).get("visible")), "한 번 더 눌러 닫았다 (전제)")
	var closed := String(root.get("_town_message"))
	t.ok(closed != opened,
		"닫는 순간 마을의 말이 새로 만들어진다 (%s -> %s — 갱신 줄이 따로 없어도 최신이다)" % [opened, closed])

	_drop_stage(t, root)


# ══════════════════════════════════════════════════════════════════
#  The air-jump ring
# ══════════════════════════════════════════════════════════════════

## **Acceptance 26.** Captures the paint hook rather than counting `_draw()` — a `super()` that draws nothing
##  keeps a call counter climbing, which is how three features shipped erasable under 6,163 green checks.
class _CapturingCharacterView extends CharacterView:
	var ring_calls: Array = []
	func _paint_air_jump_ring(center: Vector2, radius: float, color: Color) -> void:
		ring_calls.append({"center": center, "radius": radius, "color": color})


## **The ring is painted while the flash is up, and not painted when it is down.**
##
## **Both halves, because either alone is worthless**: "it draws" passes for a view that draws the ring every
##  single frame, and "it does not draw" passes for a view that never draws it at all.
##
## **What goes red when inverted**: delete the `_paint_air_jump_ring(...)` call from `character_view._draw()`.
func _the_air_jump_ring_is_painted_only_while_the_flash_is_up(t) -> void:
	var g := _floor_grid()
	var ch := Character.new()
	ch.place(160, REST_Y)
	var view := _CapturingCharacterView.new()
	view.setup(ch, SpellCircle.new(), g)
	t.root.add_child(view)

	# -- flash down: the ring must not appear --
	t.eq(ch.air_jump_flash_left, 0, "아직 공중 점프를 안 했다 (전제)")
	await t.pump_frames(3)
	t.eq(view.ring_calls.size(), 0, "공중 점프 표시가 꺼져 있으면 고리를 안 그린다")

	# -- flash up: it must appear, at the character's feet --
	ch.air_jump_flash_left = Character.AIR_JUMP_FLASH_TICKS
	view.queue_redraw()
	await t.pump_frames(3)
	t.ok(view.ring_calls.size() > 0,
		"표시가 켜지면 고리를 실제로 그린다 (%d회 — 0이면 _draw()에 부르는 줄이 없는 것)" % view.ring_calls.size())
	if view.ring_calls.is_empty():
		t.root.remove_child(view)
		view.queue_free()
		return
	var call: Dictionary = view.ring_calls[view.ring_calls.size() - 1]
	t.eq(call["radius"], Fx.AIR_JUMP_RING_R_PX, "고리의 크기가 fx_tuning이 말한 값이다")
	t.eq(call["color"], Fx.AIR_JUMP_RING_COLOR, "고리의 색도 fx_tuning이 말한 값이다")
	# **The centre is pinned to the box by literal arithmetic, not read back off the view** — a ring drawn at
	#  the sprite's top-left instead of the feet would otherwise pass.
	t.eq(call["center"], Vector2(float(ch.x) + Character.W_PX * 0.5, float(ch.y + Character.H_PX)),
		"고리가 발밑 한가운데에 그려진다")

	# -- the centre follows the character --
	var moved_x := ch.x + 64
	ch.place(moved_x, REST_Y)
	ch.air_jump_flash_left = Character.AIR_JUMP_FLASH_TICKS
	view.ring_calls.clear()
	view.queue_redraw()
	await t.pump_frames(3)
	t.ok(view.ring_calls.size() > 0, "옮긴 뒤에도 계속 그린다 (전제)")
	var moved: Dictionary = view.ring_calls[view.ring_calls.size() - 1]
	t.eq((moved["center"] as Vector2).x, float(moved_x) + Character.W_PX * 0.5,
		"캐릭터가 움직이면 고리도 따라간다 (고정 좌표가 아니다)")

	# -- and it stops when the flash runs out --
	ch.air_jump_flash_left = 0
	view.ring_calls.clear()
	view.queue_redraw()
	await t.pump_frames(3)
	t.eq(view.ring_calls.size(), 0, "표시가 0으로 떨어지면 고리가 사라진다")

	t.root.remove_child(view)
	view.queue_free()


## **The footer stopped lying, and it prints the price it actually charges.**
##
## The old string said `원석으로 푸는 해금은 아직 없다`, which was true until this feature and is a lie now.
## **The price is not asserted as a literal string** — it is asserted to contain `GEMS_PER_UNLOCK`'s own
## value, so retuning the price moves both the charge and the sentence, or this goes red.
func _the_footer_states_the_price_instead_of_denying_one(t) -> void:
	var foot := Fx.RESEARCH_FOOTER_FMT % Progress.GEMS_PER_UNLOCK
	t.ok(foot.contains("%d" % Progress.GEMS_PER_UNLOCK), "바닥 줄이 실제 값(%d)을 말한다 (%s)" % [
		Progress.GEMS_PER_UNLOCK, foot])
	t.ok(not foot.contains("아직 없다"), "그리고 '해금은 아직 없다'고 더는 말하지 않는다")
	t.ok(foot.contains("[E]"), "닫는 키 안내는 그대로 남아 있다")
	# **A format, not a finished sentence** — a literal with the number baked in would leave the printed price
	#  behind the day `GEMS_PER_UNLOCK` moves, and nothing would bark.
	t.ok(Fx.RESEARCH_FOOTER_FMT.contains("%d"), "바닥 줄은 값을 박아 넣은 문장이 아니라 서식이다")


## **Acceptance 17 — the line without which the double jump is unreachable in play.**
##
## The model is complete and measured, but `Character.air_jump_budget` is a plain field that something has to
## fill. `stage._physics_process` re-derives it from `Progress` every frame. **Delete that line and every
## other check in this file stays green while the player can never jump twice** — the sim changes and the
## screen does not, CLAUDE.md's signature failure.
##
## **Driven on a treed scene and read as a value**: buy the unlock, let real physics frames turn, and read
## the field off the real character. Nothing here is a text scan.
func _the_shell_pushes_the_air_jump_budget_every_frame(t) -> void:
	var root: Node = await _treed_stage(t)
	if root == null:
		return
	var ch: Variant = root.get("_char")
	var pr: Variant = (root.get("_world") as Object).call("progress")

	t.eq(ch.get("air_jump_budget"), 0, "사기 전엔 캐릭터의 공중 점프 예산이 0이다")
	pr.set("gems", Progress.GEMS_PER_UNLOCK)
	t.ok(pr.call("buy", UnlockDefs.UNLOCK_DOUBLE_JUMP), "2단 점프를 샀다 (전제)")

	# **Not read immediately** — the point is that a *frame* is what carries it, with no purchase hook.
	root.call("_physics_process", 1.0 / 60.0)
	t.eq(ch.get("air_jump_budget"), 1,
		"물리 프레임 한 번이면 캐릭터가 예산을 갖는다 (구매 훅이 없다 — 매 프레임 파생이다)")

	# **And it follows the model back down**, which is what proves it is derived and not written once.
	#  A latch would sit at 1 forever here.
	(pr.get("_unlocked") as Dictionary).clear()
	root.call("_physics_process", 1.0 / 60.0)
	t.eq(ch.get("air_jump_budget"), 0,
		"해금이 사라지면 예산도 따라 내려온다 (한 번 쓰고 마는 래치가 아니다)")

	_drop_stage(t, root)


## **Acceptance 20.** The HUD line states the cost and moves when something is bought — driven through the
##  real `Stage.research_text()`, not grepped.
##
## **`net_town._the_research_bench_shows_locked_and_unlocked_together` still counts `잠김` on this string and
##  requires it to drop by exactly one on a `grant_rune`.** That is why the price suffix is not on this line
##  per rune: it names the pool and states one cost at the end.
func _the_hud_line_states_the_cost_and_follows_a_purchase(t) -> void:
	var Stage := load("res://src/stage/stage.gd")
	var pr := Progress.new()
	var before: String = Stage.research_text(pr)
	t.ok(before.contains("%d" % Progress.GEMS_PER_UNLOCK),
		"연구대의 HUD 줄이 해금 값을 말한다 (%s)" % before)
	t.ok(not before.contains("아직 없다"), "그리고 '해금은 아직 없다'고 더는 말하지 않는다")

	pr.gems = Progress.GEMS_PER_UNLOCK
	t.ok(pr.buy(UnlockDefs.UNLOCK_RUNE_WATER), "물 룬을 샀다 (전제)")
	var after: String = Stage.research_text(pr)
	t.ok(after != before, "사고 나면 HUD 줄이 달라진다")
	t.eq(before.count("잠김") - after.count("잠김"), 1,
		"잠긴 룬이 정확히 하나 줄어든다 (net_town이 세는 것과 같은 계약)")
	t.ok(after.contains("%d" % Progress.GEMS_PER_UNLOCK), "사고 나서도 값은 계속 적혀 있다 (아직 살 게 남았다)")


## Chip widths the way the window measures them — `ResearchWindow.chip_widths` itself, not a second
## measurement. Measuring separately here would make every geometry check below assert its own arithmetic.
func _widths(ids: Array[int], pr: Progress) -> PackedFloat32Array:
	var font: Font = ThemeDB.fallback_font
	return ResearchWindow.chip_widths(font, ids, pr)


## The item/body id lists, in table order — what the window itself lays out.
func _ids(axis: String) -> Array[int]:
	return UnlockDefs.ids_for_axis(axis)
