extends RefCounted
## Fire — the burn slot list + fuel (design acceptance 5: **it spreads · it stops at stone · it eventually goes out**).
##
## **The total amount of fire is bounded by fuel, not by a cap** (GDD). "It does not burn where there is nothing
##  to burn" reads to the player as a **rule**, whereas "fire does not catch past N" does the same job but
##  reads as a **malfunction**. => Everything measured here is "is fuel really the budget".
##
## In v1 the cause of lightning never going out was not TTL but **water's round-trip bug** (moving water
##  re-registered into the burn slot every tick). Fire does not move so it has no such problem, and
##  **the one remaining cause is "fuel not draining"** — which is what the checks below measure head-on.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")

## Ticks for one cell of wood to burn out. The value is not hardcoded here — if either of the two changes,
## a hand-written number goes quietly stale.
const BURN_TICKS := int(Mat.DEFS[Mat.WOOD]["fuel"]) / Tuning.FIRE_BURN_PER_TICK


func run(t) -> void:
	_ignite_rules(t)
	_fuel_drains(t)
	_spreads_through_wood(t)
	_stops_at_stone(t)
	_cannot_cross_air(t)
	_always_goes_out(t)
	_blast_lights_wood(t)
	_front_has_no_ghosts(t)
	_burn_slot_has_no_orphans(t)
	_reset_clears_front(t)
	# -- burn-out-of-the-bull-room §0 — rune_only --
	_rune_only_refuses_ordinary_fire_but_spread_still_crosses_it(t)


## **The burn slot = the set of BURNING cells.** That equation is the whole of the burn slot data structure.
##
## The original scene of a ghost was **the moment a blast erased a burning cell** — only `_flag` went to 0
## while the index stayed in the burn slot. Measured: at key 4, 90 of 217 cells (**41%**) were ghosts.
## **But a blast can no longer erase wood** (`WOOD indestructible` in `cell_materials.gd`) —
##  `_disc(...,true)` `continue`s past all wood (around line 888). => **That scene no longer occurs.**
##  The risk itself is not dead — there is one more place that calls `_write_cell(idx, Mat.EMPTY)`:
##  **the spot where `_burn()` erases a cell that finished burning at fuel 0** (around line 630). Erased by a
##  blast or erased by burning out, both pass through **the same door (`_write_cell` -> `_unburn`)** —
##  the same risk may be measured at this door instead. => Below catches **the tick where a wide patch of
##  fire lit at once all burns out simultaneously.**
## If water or terrain regeneration comes in and refills that spot with wood, a ghost becomes a real bug:
##  the new wood has `_aux` 0, so it becomes empty on the next tick and the same cell enters the burn slot twice.
## => The equation is measured **within that tick**. "It heals on the next tick" cannot measure it.
func _front_has_no_ghosts(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, 127, 63, Mat.WOOD))
	for y in range(20, 45):
		for x in range(50, 80):
			g.ignite(x, y)
	var lit := g.burning_count()
	t.ok(lit > 0, "먼저 넓게 불이 붙는다 (%d칸)" % lit)
	t.eq(lit, _flagged(g), "붙인 직후 파면과 BURNING 칸 수가 같다")

	# **The tick where everything burns out — where the ghost-producing spot moved to.** All of it was lit on
	#  the same tick, so the fuel hits 0 on the same tick (the `BURN_TICKS`-th) together — these 750 cells pass
	#  through `_write_cell(EMPTY)` simultaneously. Spreading widens the border meanwhile, so it is measured as a
	#  **net decrease**.
	for _i in BURN_TICKS - 1:
		g.step()
	var before_extinguish := g.burning_count()
	g.step()  # on this tick the original 750 cells go fuel 0 -> EMPTY all at once
	t.ok(g.burning_count() < before_extinguish,
		"다 탄 칸이 그 틱에 실제로 사라진다 (%d → %d)" % [before_extinguish, g.burning_count()])
	t.eq(g.burning_count(), _flagged(g), "대량으로 사라진 **그 틱에** 파면이 안 부푼다 (유령이 없다)")

	# Does the equation hold one tick later too (does the extinguish path pass the same door).
	g.step()
	t.eq(g.burning_count(), _flagged(g), "한 틱 뒤에도 등식이 유지된다")


## **The reverse direction of the slot table — orphan slots.**
##  A cell that is not in the burn slot but claims membership is blocked by `_ignite_cell`'s duplicate guard
##  and **can never burn again.** No error, nothing on screen.
##
## **The `_flag` equation cannot catch this.** `_write_cell` clears `_flag` properly so that side always matches,
##  and the only thing that diverges is the **third data structure**, the slot table — measured: moving the last
##  line of `_unburn` forward left the `_flag` equation green while orphans piled up 1 -> 9 -> 168 cells.
## **All four stretches are looked at**: right after lighting · right after a blast erases · after burning out ·
##  after reset. Self-swap (`at == last`) only comes up in "after burning out".
func _burn_slot_has_no_orphans(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, 127, 63, Mat.WOOD))
	for y in range(20, 45):
		for x in range(50, 80):
			g.ignite(x, y)
	t.eq(g.claimed_slot_count(), g.burning_count(), "붙인 직후 고아 슬롯이 없다")

	# **It can no longer be measured with a blast — wood is indestructible so the destruction pass erases nothing**
	#  (`cell_materials.gd`). **This used to erase the middle of the burning patch with `cmd_blast(...,rd,0)`** —
	#  now that call is a no-op end to end, making it a dead check that does not go red when inverted.
	#  => The same risk (the slot table diverging from actual BURNING) is moved to the **burn-out path** —
	#  the same event as `_front_has_no_ghosts` (750 cells lit on the same tick hit fuel 0 together), and what
	#  differs here is that it measures the **slot table** (`claimed_slot_count`) rather than `_flag`.
	for _i in BURN_TICKS - 1:
		g.step()
	t.eq(g.claimed_slot_count(), g.burning_count(), "다 타기 직전에도 고아 슬롯이 없다")
	g.step()  # on this tick the 750 cells lit first go fuel 0 -> EMPTY all at once
	t.eq(g.claimed_slot_count(), g.burning_count(), "대량으로 사라진 그 틱에도 고아 슬롯이 없다")

	# **Burn the rest down.** The removal of the last cell is where the self-swap (`at == last`) runs.
	for _i in BURN_TICKS * 6:
		g.step()
		if g.burning_count() == 0:
			break
	t.eq(g.burning_count(), 0, "숲이 다 탄다")
	t.eq(g.claimed_slot_count(), 0, "다 타서 꺼진 뒤 고아 슬롯이 0이다")

	# And that spot must be **able to burn again** — a leftover orphan makes the duplicate guard block it forever.
	g.apply(CellGrid.cmd_fill(60, 30, 70, 40, Mat.WOOD))
	t.ok(g.ignite(64, 32), "다 탔던 자리에 나무를 채우면 다시 붙는다")

	g.apply(CellGrid.cmd_reset())
	t.eq(g.claimed_slot_count(), 0, "리셋 뒤 고아 슬롯이 0이다")


## Number of cells in the grid with the BURNING bit set. A measurement **independent** of the burn slot length,
## which is what makes the equation measurable.
func _flagged(g: CellGrid) -> int:
	var n := 0
	var flags := g.get_flag()
	for i in CellGrid.CELL_COUNT:
		if (flags[i] & Mat.FLAG_BURNING) != 0:
			n += 1
	return n


## "Only where there is something to burn" (GDD). Stone and empty cells have fuel 0 and it stops here.
func _ignite_rules(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(10, 10, 10, 10, Mat.WOOD))
	g.apply(CellGrid.cmd_fill(20, 10, 20, 10, Mat.STONE))

	t.ok(g.ignite(10, 10), "나무에는 불이 붙는다")
	t.eq(g.burning_count(), 1, "파면에 한 칸 올라간다")
	t.eq(g.flag_at(10, 10) & Mat.FLAG_BURNING, Mat.FLAG_BURNING, "타는 칸에 BURNING이 선다")
	t.eq(g.fuel_at(10, 10), int(Mat.DEFS[Mat.WOOD]["fuel"]), "연료가 재료 표에서 온다")

	t.ok(not g.ignite(20, 10), "돌에는 불이 안 붙는다")
	t.ok(not g.ignite(50, 50), "빈칸에는 불이 안 붙는다")
	t.ok(not g.ignite(10, 10), "이미 타는 칸에 두 번 안 올라간다")
	t.eq(g.burning_count(), 1, "파면 길이가 안 늘어난다")
	t.ok(not g.ignite(-1, 10), "격자 밖은 조용히 무시된다")


## **If fuel does not drain, fire never goes out.** That is the only candidate v1 left behind.
func _fuel_drains(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(10, 10, 10, 10, Mat.WOOD))
	g.ignite(10, 10)
	var before := g.fuel_at(10, 10)
	g.step()
	t.eq(g.fuel_at(10, 10), before - Tuning.FIRE_BURN_PER_TICK, "한 틱에 연료가 정확히 그만큼 준다")

	# Burned out, it leaves the list and **that cell becomes empty** — otherwise fire leaves zero trace on screen.
	for _i in BURN_TICKS:
		g.step()
	t.eq(g.burning_count(), 0, "연료가 0이면 파면에서 빠진다")
	t.eq(g.mat_at(10, 10), Mat.EMPTY, "다 탄 자리는 빈칸이 된다")
	t.eq(g.flag_at(10, 10) & Mat.FLAG_BURNING, 0, "꺼진 칸의 BURNING이 내려간다")
	t.eq(g.aux_at(10, 10), 0, "꺼진 칸의 연료 자리가 0으로 돌아간다")


func _spreads_through_wood(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(10, 10, 40, 10, Mat.WOOD))  # one horizontal row
	g.ignite(10, 10)
	var reach := 0
	for _i in BURN_TICKS:
		g.step()
		var x := 10
		while x <= 40 and (g.flag_at(x, 10) & Mat.FLAG_BURNING) != 0:
			x += 1
		reach = maxi(reach, x - 10)
	t.ok(reach > 1, "불이 이웃 나무로 번진다 (%d칸까지)" % reach)


## **This is the body of acceptance 5.** One cell of stone cuts the fire — for "which rune is strong in a room
##  is decided by the terrain" (GDD) to hold, this must be true.
func _stops_at_stone(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(10, 10, 14, 10, Mat.WOOD))
	g.apply(CellGrid.cmd_fill(15, 10, 15, 10, Mat.STONE))   # one cell of wall
	g.apply(CellGrid.cmd_fill(16, 10, 20, 10, Mat.WOOD))    # wood on the far side
	g.ignite(10, 10)
	for _i in BURN_TICKS * 3:
		g.step()
	t.eq(g.mat_at(15, 10), Mat.STONE, "돌은 안 탄다")
	# **Not a single cell** on the far side may burn. Diagonal spread would be caught here.
	var crossed := false
	for x in range(16, 21):
		if g.mat_at(x, 10) != Mat.WOOD:
			crossed = true
	t.ok(not crossed, "돌 건너편 나무는 안 탄다")
	t.eq(g.burning_count(), 0, "이쪽이 다 타고 나면 불이 0이다")


func _cannot_cross_air(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(10, 10, 14, 10, Mat.WOOD))
	g.apply(CellGrid.cmd_fill(16, 10, 20, 10, Mat.WOOD))    # one empty cell across
	g.ignite(10, 10)
	for _i in BURN_TICKS * 3:
		g.step()
	var crossed := false
	for x in range(16, 21):
		if g.mat_at(x, 10) != Mat.WOOD:
			crossed = true
	t.ok(not crossed, "불이 허공을 못 건넌다 (이 단계에 물이 없어 연료가 유일한 규칙이다)")


## **It must go out.** Even filled entirely with wood it is finite — fuel drains every tick, a burned-out cell
##  becomes empty, and an empty cell has fuel 0 so it **cannot catch again.**
func _always_goes_out(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, 63, 31, Mat.WOOD))
	var cells := g.count_material(Mat.WOOD)
	g.ignite(32, 16)

	var peak := 0
	var ticks := 0
	# The cap is generous relative to "time to spread + time for one cell to burn". Hitting it means it really did not go out.
	var cap := 64 * Tuning.FIRE_SPREAD_TICKS + BURN_TICKS * 4
	while g.burning_count() > 0 and ticks < cap:
		g.step()
		peak = maxi(peak, g.burning_count())
		ticks += 1
	t.ok(g.burning_count() == 0, "나무 %d칸을 태우고도 %d틱 안에 꺼진다 (실제 %d틱)" % [cells, cap, ticks])
	t.ok(peak > 1, "한 번에 여러 칸이 탄다 (최대 %d칸)" % peak)
	# A safety net **must not be reached in normal play** (GDD). If this bites, look at the stage, not the value.
	t.ok(peak < Tuning.MAX_BURNING,
		"총량 안전망(%d)에 평소엔 안 닿는다 (최대 %d)" % [Tuning.MAX_BURNING, peak])
	t.eq(g.count_material(Mat.WOOD), 0, "탈 것이 남지 않는다")


## **The ignition radius must exceed the destruction radius — except the reason is no longer about wood.**
##  **The original grounds**: a blast turns everything inside `rd` into EMPTY = sets fuel to 0. Unless the
##  ignition radius exceeds the destruction radius, fire cannot catch in principle — it erases what it would burn.
## **`indestructible: true` on `WOOD` removed those grounds for wood.**
##  The destruction pass (`_disc(...,true)`) `continue`s past all wood (around line 888) — **wood is not erased
##  even inside the destruction radius.** Whether `ignite_r` is larger or smaller than `rd`, the wood stays put
##  and is caught by the ignition pass. => **For wood, today's only flammable material, this inequality is not
##  "fire's way in".**
##  The value is kept anyway — the day a **future material that breaks and also burns** appears, this inequality
##  becomes a live rule again for that material (it is also the value `net_tables` measures per generation).
func _blast_lights_wood(t) -> void:
	t.ok(Tuning.blast_ignite_r(0) > Tuning.blast_rd(0),
		"점화 반경 %d이 파괴 반경 %d보다 크다 (미래의 부서지고 또 타는 재료를 위한 하한)" % [
			Tuning.blast_ignite_r(0), Tuning.blast_rd(0)])

	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, 127, 63, Mat.WOOD))
	# **`IGNITE_RUNE_FIRE`** — this is a blast from a fire circle (`burn-out-of-the-bull-room.md` §0); wood is
	#  `rune_only` and a runeless blast's own refusal is `_wood_ignores_a_runeless_blast` below.
	g.apply(CellGrid.cmd_blast(64, 32, Tuning.blast_rd(0), Tuning.blast_ignite_r(0), CellGrid.IGNITE_RUNE_FIRE))
	t.ok(g.burning_count() > 0, "폭발이 나무에 불을 붙인다 (%d칸)" % g.burning_count())

	# **There is no crater.** Wood is indestructible so the destruction pass erases nothing, the center is still
	#  wood, and the ignition pass covers it too.
	#  **This used to say "it does not burn"** — the crater was empty (fuel 0) so it could not catch. With
	#  `indestructible` the crater itself is gone, so that observation flips.
	t.eq(g.mat_at(64, 32), Mat.WOOD, "폭발 한가운데도 나무 그대로다 (안 파인다)")
	t.eq(g.flag_at(64, 32) & Mat.FLAG_BURNING, Mat.FLAG_BURNING, "그리고 그 나무에 불이 붙는다")
	t.eq(g.flag_at(64 + Tuning.blast_rd(0) + 2, 32) & Mat.FLAG_BURNING, Mat.FLAG_BURNING,
		"파괴 반경 밖도 점화 반경 안이면 탄다")
	t.eq(g.flag_at(64 + Tuning.blast_ignite_r(0) + 2, 32) & Mat.FLAG_BURNING, 0,
		"점화 반경 밖은 안 탄다")

	var stone := CellGrid.new()
	stone.apply(CellGrid.cmd_fill(0, 0, 127, 63, Mat.STONE))
	stone.apply(CellGrid.cmd_blast(64, 32, Tuning.blast_rd(0), Tuning.blast_ignite_r(0), CellGrid.IGNITE_RUNE_FIRE))
	t.eq(stone.burning_count(), 0, "돌방에서는 폭발해도 불이 안 난다 (지형이 곧 룬의 세기다)")
	# The control — **stone is still carved.** It separates "wood is special-cased" from "the destruction pass is dead".
	t.eq(stone.mat_at(64, 32), Mat.EMPTY, "그런데 돌은 파괴 패스로 지워진다 (재료를 가린다)")


## If reset does not clear the burn slot, old fire sits on **the same index** of the new terrain and turns that
##  cell empty one tick later — holes appear in the new stage built with R.
func _reset_clears_front(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(10, 10, 20, 10, Mat.WOOD))
	g.ignite(10, 10)
	t.ok(g.burning_count() > 0, "먼저 불을 붙인다")

	g.apply(CellGrid.cmd_reset())
	t.eq(g.burning_count(), 0, "리셋이 파면을 비운다")

	g.apply(CellGrid.cmd_fill(10, 10, 20, 10, Mat.WOOD))
	var before := g.count_material(Mat.WOOD)
	g.step()
	t.eq(g.count_material(Mat.WOOD), before, "리셋 뒤 새 지형이 옛 불에 안 깎인다")


## **The rule at grid level** (`burn-out-of-the-bull-room.md` §0). `WOOD` is `rune_only`: `IGNITE_ANY` (the
##  bull's own fire, a runeless blast) must not catch it, `IGNITE_RUNE_FIRE` (the fire rune, a fire-circle
##  blast) must. And once it does catch, ordinary **spread** must still cross the whole block — the fuel-table
##  invariant `_burn`'s own comment argues for (every burning cell already passed the rune check the moment it
##  first caught, so `_burn`'s unconditional `IGNITE_RUNE_FIRE` on spread is not a loophole).
func _rune_only_refuses_ordinary_fire_but_spread_still_crosses_it(t) -> void:
	t.ok(bool(Mat.DEFS[Mat.WOOD].get("rune_only", false)), "나무가 rune_only다 (검사의 전제)")

	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, 63, 31, Mat.WOOD))
	t.ok(not g.ignite(30, 15, CellGrid.IGNITE_ANY), "IGNITE_ANY로는 안 붙는다 (혼자 켜는 반환값)")
	t.eq(g.burning_count(), 0, "실제로 안 붙었다 (타는 칸이 0)")

	t.ok(g.ignite(30, 15, CellGrid.IGNITE_RUNE_FIRE), "IGNITE_RUNE_FIRE로는 붙는다")
	t.ok(g.burning_count() > 0, "실제로 불이 났다")

	# Spread crosses the whole 64x32 block once lit — the same cap `_always_goes_out` already uses.
	var cap := 64 * Tuning.FIRE_SPREAD_TICKS + BURN_TICKS * 4
	var ticks := 0
	while g.count_material(Mat.WOOD) > 0 and ticks < cap:
		g.step()
		ticks += 1
	t.eq(g.count_material(Mat.WOOD), 0,
		"%d틱 안에 블록 전체가 탄다 (rune_only가 확산까지는 안 막는다, 실제 %d틱)" % [cap, ticks])
