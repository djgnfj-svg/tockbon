extends RefCounted
## Projectile and glyph pipeline. **This net running at all is thanks to `spell_sim.gd` being RefCounted.**
##
## Everything caught here is of the "silently wrong with no error" kind:
##  · passing through a thin wall — one frame, so **the eye can never see it.** To the user it only looks like "sometimes it doesn't go off"
##  · asymmetric left/right drag — it only looks like "firing left goes a little less far"
##  · id reuse — an old trail sticks to a new bolt. No error, only the screen goes wrong
##
## **The determinism contract (integers only) cannot be measured by this net.** Two instances in the same process
##  give the same answer even with floats — `net_determinism`'s folder text scan is the only detector.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const SpellSim := preload("res://src/sim/spell_sim.gd")
const Aim := preload("res://src/actor/aim.gd")
## **Borrows** the comment/string stripper — several nets sweep source text and there must be exactly one stripper.
const NetDeterminism := preload("res://tests/nets/net_determinism.gd")

const SPELL_SIM_SCRIPT := "res://src/sim/spell_sim.gd"

## Launch speed (fixed point). Aim normalization has to produce this magnitude in every direction.
const SPEED_FP := Tuning.SIM_SIZES[0]["speed"] << SpellSim.FP_SHIFT

## The stone pillar columns of the wall grid (`_wall_grid`). **Kept in one place** — measuring "how many shots pierce it"
##  needs to know where the wall starts and ends, and with that number in two places moving the wall silently splits them.
const WALL_X0 := 40
const WALL_X1 := 43

## Bounds (cells) of the room dug into stone/wood. **Kept in one place** — measuring trace depth needs to know
##  where the wall starts, and with that number in two places moving the room silently splits them.
const CAVE_X0 := 20
const CAVE_X1 := 60
const CAVE_Y0 := 55
const CAVE_Y1 := 85

## **The side length (cells) `_solid_grid()` and `_wood_cave_grid()` fill** (CLAUDE.md, "when the net is slow...").
##  The old code filled the whole grid (4096x1008 = 4,128,768 cells) — `_cave_grid()` is called more than 15 times
##  in this file, so that alone made this file eat 125 seconds of the whole net run.
##  **The reason the cave has to be "thick stone on every side" (`_cave_grid` comment) does not die** — this value
##  wraps the room bounds (X 20-60, Y 55-85) and every coordinate this file uses directly (cx=100, cy=70, blast radius rd=8)
##  with dozens of cells still to spare. 200x200 = 40,000 cells is 1/103 of the old value.
const SOLID_EXTENT := 200

## Launch origin (cells) for the checks that fire upward. **Fires up from near the floor of the box** —
##  there has to be room to fall back as far as it rose, so that vx reaching 0 can be seen **in flight.**
## Doubled at the 32px switch (128,130 -> 256,260). `_box_grid` below derives from the grid, so it doubled on its own.
const UP_OX := 256
const UP_OY := 260


func run(t) -> void:
	_pack_unpack(t)
	_list_is_finite(t)
	_aim_normalizes(t)
	_drag_and_gravity(t)
	_drag_is_symmetric(t)
	_thin_wall(t)
	_up_and_back(t)
	_command_boundary(t)
	_aim_boundary(t)
	_id_across_reset(t)
	_every_glyph_runs(t)
	_blast_command(t)
	_changed_counter(t)
	_blast_glyph(t)
	_blast_chain(t)
	_blast_budget(t)
	_blast_notice(t)
	_spread_makes_eight(t)
	_spread_hands_over_list(t)
	_spread_advances_on_birth_tick(t)
	_order_changes_the_spell(t)
	_spread_capped_per_circle(t)
	_kind_decides_continuation(t)
	_every_impact_carves(t)
	_repeated_shots_pierce_the_wall(t)
	_carve_follows_gen(t)
	_rune_leaves_a_trace(t)
	_every_rune_traces(t)
	_rune_trace_has_the_none_branch(t)
	_empty_list_bolts_leave_marks(t)
	_glyph_bolt_also_traces(t)
	_rune_trace_follows_gen(t)
	_spread_without_room(t)
	_spread_partial(t)
	_crater_follows_gen(t)
	# -- levelup-and-three-picks Stage A — power_pct / MODIFY --------
	_power_composition_is_a_product(t)
	_modify_composes_at_launch_not_impact(t)
	_modify_never_reaches_the_pipeline(t)
	_family_cap_blocks_mixed_rarity(t)
	_deferred_blast_keeps_its_power(t)
	_terminal_compounds_carried_power(t)
	_spawn_does_not_compound_carried_power(t)
	_blast_power_does_not_leak_between_layers(t)
	_spread_power_pct_reaches_the_children(t)
	_notice_power_arrays_clear_with_the_rest(t)
	_power_clamp_actually_fires(t)
	_unknown_id_after_a_capped_glyph_barks_not_crashes(t)
	# -- burn-out-of-the-bull-room.md §0 — the runeless-blast fix --
	_blast_ignites_wood_only_from_the_fire_rune(t)
	# -- glyph-condense §11.6 Step 2 — the pillar's own pipeline --
	_condense_notice_is_literal(t)
	_condense_climbs_up_and_stops_at_the_first_solid(t)
	_condense_leaves_no_material(t)
	_condense_and_blast_both_run_in_either_order(t)
	_spread_condense_raises_eight_pillars(t)
	_condense_height_follows_gen(t)
	_condense_power_does_not_leak_between_layers(t)
	_condense_runs_for_every_rune(t)
	_condense_never_defers(t)


# ══════════════════════════════════════════════════════════════════
#  The remaining glyph list — a single integer
# ══════════════════════════════════════════════════════════════════

## Pack/unpack round trip. **Order has to survive** — glyphs are interpreted from the inner layer outward,
##  and reversing the order turns spread->blast into blast->spread. That is **a different spell**, and it does not look like a bug.
func _pack_unpack(t) -> void:
	var cases: Array[Array] = [
		[],
		[1],
		[1, 2],
		[2, 1],                    # the same two glyphs as above in a different order — the result has to differ
		[3, 1, 4, 1, 5, 9, 2],     # the cap, 7 layers
	]
	for list: Array in cases:
		var typed: Array[int] = []
		typed.assign(list)
		t.eq(_unpack(Glyph.pack(typed)), typed, "목록 %s가 팩/언팩을 왕복한다" % [typed])

	# Does a different order actually become a different integer? If the same integer comes out, the round-trip check above is entirely meaningless.
	var ab: Array[int] = [1, 2]
	var ba: Array[int] = [2, 1]
	t.ok(Glyph.pack(ab) != Glyph.pack(ba), "순서가 다르면 다른 정수다")

	# Structural validation. "Does such a glyph actually exist" is not looked at here but by `spell_sim.fire()`.
	var too_many: Array[int] = [1, 1, 1, 1, 1, 1, 1, 1]
	t.expect_error("Glyph: 8 layers")
	t.eq(Glyph.pack(too_many), Glyph.GLYPH_NONE, "8층은 짖고 빈 목록이 된다")

	var has_zero: Array[int] = [1, 0]
	t.expect_error("Glyph: glyph id 0")
	t.eq(Glyph.pack(has_zero), Glyph.GLYPH_NONE, "예약값 0은 문양 id가 될 수 없다")

	var too_big: Array[int] = [Glyph.MASK + 1]
	t.expect_error("Glyph: glyph id 16")
	t.eq(Glyph.pack(too_big), Glyph.GLYPH_NONE, "니블을 넘는 id는 짖고 버려진다")

	# **`count_of` is no longer the `max_per_circle` consumer as of Stage A** (`glyph_defs.gd`'s own comment on
	#  the function — `count_family` replaced it at both call sites). This block only measures that `count_of`
	#  still correctly counts exact-id repeats, a real and separate fact from what enforces the cap.
	var twice: Array[int] = [1, 2, 1]
	t.eq(Glyph.count_of(Glyph.pack(twice), 1), 2, "count_of가 같은 문양을 두 번 센다")
	t.eq(Glyph.count_of(Glyph.pack(twice), 2), 1, "count_of가 다른 문양을 한 번 센다")


## **blast -> blast -> ... cannot become infinite.** `rest` shaves 4 bits every time, so
##  `_impact`'s while loop **needs no cap guard in principle** — that argument is measured here.
##  If this breaks, the frame stops entirely (the game freezes with no error).
func _list_is_finite(t) -> void:
	var full: Array[int] = []
	for _i in Tuning.GLYPH_MAX_LAYERS:
		full.append(Glyph.MASK)
	var g := Glyph.pack(full)

	# Touch the sign bit and `>> 4` is an arithmetic shift, so sign extension makes it **spin forever with no error.**
	t.ok(g > 0, "가득 찬 목록이 양수다 (부호 비트에 여유가 있다)")

	var steps := 0
	while g != Glyph.GLYPH_NONE and steps <= Tuning.GLYPH_MAX_LAYERS:
		g = Glyph.rest(g)
		steps += 1
	t.eq(g, Glyph.GLYPH_NONE, "가득 찬 목록도 반드시 빈다")
	t.eq(steps, Tuning.GLYPH_MAX_LAYERS, "정확히 %d번에 빈다" % Tuning.GLYPH_MAX_LAYERS)


# ══════════════════════════════════════════════════════════════════
#  Firing — integer normalization
# ══════════════════════════════════════════════════════════════════

## The speed magnitude has to be the same whichever direction you fire. Otherwise it becomes "firing diagonally goes farther".
##
## **Measuring with a short aim vector is the whole point.** Kill `AIM_SHIFT` to 0 and at aim (100,100)
##  the error is 0.2% and invisible — at (1,1) it is **41% faster** (`isqrt(2)=1`, so sqrt(2) times).
##  The mouse sitting right next to the character is exactly that case.
func _aim_normalizes(t) -> void:
	var aims: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1),
		Vector2i(3, 1), Vector2i(100, 0), Vector2i(100, 100),
	]
	for a: Vector2i in aims:
		var sim := SpellSim.new()
		t.ok(_fire(sim, 128, 70, a.x, a.y), "조준 %s로 발사된다" % a)
		if sim.active_count() == 0:
			continue
		var vx: int = sim.get_vx()[0]
		var vy: int = sim.get_vy()[0]
		# Compared squared — the net has no reason to use sqrt, and the 2% margin is truncation's share.
		var got2 := vx * vx + vy * vy
		var want2 := SPEED_FP * SPEED_FP
		t.ok(absi(got2 - want2) * 100 <= want2 * 4,
			"조준 %s의 속도 크기가 %d에 붙는다 (v²=%d · 기대 %d)" % [a, SPEED_FP, got2, want2])

	# Left/right symmetry. Mirror the aim horizontally and the absolute value of vx has to be **exactly** the same.
	var r := SpellSim.new()
	var l := SpellSim.new()
	_fire(r, 128, 70, 3, -1)
	_fire(l, 128, 70, -3, -1)
	t.eq(absi(r.get_vx()[0]), absi(l.get_vx()[0]), "좌우 조준의 속도가 대칭이다")
	t.eq(r.get_vy()[0], l.get_vy()[0], "좌우 조준의 세로 속도가 같다")


# ══════════════════════════════════════════════════════════════════
#  Trajectory — drag + gravity (the net's proxy for design acceptance 3)
# ══════════════════════════════════════════════════════════════════

## **Fires almost straight up.** Fired horizontally it reaches a wall first and cannot fill the ticks,
##  and then "vx eventually becomes exactly 0" below cannot be confirmed **in flight.**
##  At aim (1,-100), vx starts at about 1/100 of the speed and drag truncates it to 0,
##   while the flight lasts longer than that.
##
## **The origin was doubled at the 32px switch** (128,130 -> 256,260). `speed` and `GRAVITY_FP` doubled
##  **together**, so **the flight tick count stayed the same and only the distance doubled** — leave the origin alone
##  and the bolt punches up through the ceiling of the box and **dies while rising**, and then "it rises and then sags"
##  cannot be measured (it went red exactly that way in measurement).
##  `_box_grid` derives from the grid size, so it doubled on its own. **Only the origin is moved by hand.**
func _drag_and_gravity(t) -> void:
	var g := _box_grid()
	var sim := SpellSim.new()
	t.ok(_fire(sim, UP_OX, UP_OY, 1, -100), "거의 수직으로 위로 쏜다")

	var vxs: Array[int] = [sim.get_vx()[0]]
	var vys: Array[int] = [sim.get_vy()[0]]
	while sim.active_count() > 0 and vxs.size() <= Tuning.LIFETIME_TICKS:
		sim.step(g)
		if sim.active_count() == 0:
			break
		vxs.append(sim.get_vx()[0])
		vys.append(sim.get_vy()[0])

	var shrinking := true
	for k in range(1, vxs.size()):
		if absi(vxs[k]) > absi(vxs[k - 1]):
			shrinking = false
	t.ok(shrinking, "항력이 vx를 매 틱 줄인다 (%d → %d · %d틱)" % [vxs[0], vxs[-1], vxs.size()])

	# **This is a contract, not a bug** (design doc, "trajectory"). Integer truncation makes the horizontal speed
	#  eventually exactly 0, and from then the bolt only falls straight down — it reads as "it runs out of force and drops in".
	#  If the net does not measure this, the next person sees it as a bug and fixes it.
	t.eq(vxs[-1], 0, "정수 절삭으로 가로 속도가 결국 정확히 0이 된다 (계약이다)")

	var falling := true
	for k in range(1, vys.size()):
		if vys[k] < vys[k - 1]:
			falling = false
	t.ok(falling, "중력이 vy를 단조로 키운다")
	t.ok(vys[0] < 0 and vys[-1] > 0,
		"위로 나갔다가 아래로 처진다 (vy %d → %d)" % [vys[0], vys[-1]])


## **Measures that drag is `/` and not `>>`.** `>>` floors on negatives, so only bolts flying left
##  get 0.5/256 more decay — to the eye it only looks like "firing left goes a little less far",
##  and nobody reports a difference that small as a bug.
func _drag_is_symmetric(t) -> void:
	var right := _vx_series(1)
	var left := _vx_series(-1)
	t.eq(right.size(), left.size(), "좌우 비행이 같은 틱 수를 산다")
	var same := right.size() == left.size()
	for k in mini(right.size(), left.size()):
		if right[k] != -left[k]:
			same = false
	t.ok(same, "좌우 vx 수열이 부호만 다르다 (%d틱)" % right.size())


## The vx series of a bolt fired almost straight up. A `sign` of +1 leans slightly right.
func _vx_series(sign: int) -> Array[int]:
	var g := _box_grid()
	var sim := SpellSim.new()
	_fire(sim, UP_OX, UP_OY, sign, -100)
	var out: Array[int] = [sim.get_vx()[0]]
	while sim.active_count() > 0 and out.size() <= Tuning.LIFETIME_TICKS:
		sim.step(g)
		if sim.active_count() == 0:
			break
		out.append(sim.get_vx()[0])
	return out


# ══════════════════════════════════════════════════════════════════
#  Movement — does it step on every cell it passes through
# ══════════════════════════════════════════════════════════════════

## **The wall is 1 cell.** The bolt jumps 20 cells on the first tick, so the wall falls **between** two ticks —
##  written as "check only the arrival cell" it passes straight through, and **it is one frame, so the eye can never see it.**
##  To the user it only looks like "sometimes it doesn't go off".
func _thin_wall(t) -> void:
	var walled := CellGrid.new()
	walled.apply(CellGrid.cmd_fill(25, 0, 25, CellGrid.H - 1, Mat.STONE))
	var hit := SpellSim.new()
	t.ok(_fire(hit, 10, 70, 100, 0), "1셀 벽 앞에서 수평으로 쏜다")
	for _i in 3:
		hit.step(walled)
	t.eq(hit.active_count(), 0, "1셀 벽을 통과하지 않는다 (Bresenham)")

	# **Without a control, the green above cannot tell "it hit the wall" from "it just died".**
	#  Same spot, same tick count, only the wall removed.
	var open := CellGrid.new()
	var miss := SpellSim.new()
	t.ok(_fire(miss, 10, 70, 100, 0), "같은 자리에서 벽 없이 쏜다")
	for _i in 3:
		miss.step(open)
	t.eq(miss.active_count(), 1, "벽이 없으면 같은 3틱을 살아서 난다")


## Design doc "extreme values": fire straight up and it **comes back and lands on your own head.**
##
## And that is **why lifetime is a real safety net** — with gravity the bolt must reach the ground or
##  leave the grid, so a projectile spinning forever is impossible in principle.
##  Conversely, if lifetime is shorter than the flight the bolt **just vanishes in mid-air**, and that reads as a malfunction.
func _up_and_back(t) -> void:
	var g := _box_grid()
	var sim := SpellSim.new()
	var ox := UP_OX
	var oy := UP_OY
	t.ok(_fire(sim, ox, oy, 0, -1), "수직으로 위로 쏜다")

	var turned := false
	var ticks := 0
	var last_x := ox
	var last_y := oy
	var top_y := oy
	while sim.active_count() > 0 and ticks <= Tuning.LIFETIME_TICKS:
		last_x = sim.get_px()[0] >> SpellSim.FP_SHIFT
		last_y = sim.get_py()[0] >> SpellSim.FP_SHIFT
		top_y = mini(top_y, last_y)
		sim.step(g)
		ticks += 1
		if sim.active_count() > 0 and sim.get_vy()[0] > 0:
			turned = true

	t.eq(sim.active_count(), 0, "위로 쏜 탄이 반드시 착탄한다")
	t.ok(turned, "올라가다 방향이 뒤집힌다")
	t.ok(top_y < oy - 20, "실제로 높이 올라간다 (최고점 셀 y=%d · 발사점 %d)" % [top_y, oy])
	t.eq(last_x, ox, "자기 머리 위에 떨어진다 (x가 그대로다)")
	t.ok(last_y > oy, "쏜 자리보다 아래에서 착탄한다 (y=%d)" % last_y)
	t.ok(ticks < Tuning.LIFETIME_TICKS,
		"수명 %d틱에 안 걸린다 — 진짜 안전망이다 (%d틱 비행)" % [Tuning.LIFETIME_TICKS, ticks])


# ══════════════════════════════════════════════════════════════════
#  Command boundary
# ══════════════════════════════════════════════════════════════════

## **Firing is by design the only command that crosses the line — validate it here or there is nowhere to.**
##  These values are unreachable from a local mouse, but **the network opens that door.**
func _command_boundary(t) -> void:
	var sim := SpellSim.new()

	# A zero aim vector is **normal input** (clicking dead center on the character). It must not bark —
	#  the wrapper counts stderr as failure, so barking here makes ordinary play turn the net red.
	t.ok(not _fire(sim, 100, 70, 0, 0), "조준 0벡터는 조용히 버린다")
	t.eq(sim.active_count(), 0, "조준 0벡터는 탄을 안 만든다")

	# `_px` is a PackedInt32Array, so an out-of-range origin is **truncated to 32 bits with no error** —
	#  the projectile starts on the opposite side of the grid, and the truncation is deterministic so not even a desync shows up.
	t.expect_error("outside the grid - discarding")
	t.ok(not _fire(sim, CellGrid.W + 10, 70, 1, 0), "격자 밖 원점은 짖고 버린다")

	t.expect_error("SpellSim: unknown rune")
	t.ok(not sim.fire(SpellSim.cmd_fire(100, 70, 1, 0, 99, Glyph.GLYPH_NONE)),
		"모르는 룬은 짖고 버린다")

	t.expect_error("unknown spell command")
	t.ok(not sim.fire({"spell_kind": 77}), "모르는 주문 커맨드는 짖고 버린다")

	# If `len2 << 16` overflows, normalization silently goes wrong.
	t.expect_error("outside i16 range")
	t.ok(not _fire(sim, 100, 70, SpellSim.AIM_MAX + 1, 0), "i16 밖 조준은 짖고 버린다")

	# A glyph that is not in the table. Once the assembly window (B) exists it reads the same table and blocks it beforehand,
	#  but even then the command boundary has to look at **lists coming from the network.**
	t.expect_error("unknown glyph id")
	t.ok(not _fire(sim, 100, 70, 1, 0, Glyph.MASK), "표에 없는 문양은 발사 시점에 짖고 버린다")
	t.eq(sim.active_count(), 0, "버린 발사가 탄을 안 남긴다")

	# The cap **barks and drops** — it does not build a queueing machine (plan 9). Spread is limited to one
	#  per circle, so in single player 1 -> 8 bolts is the ceiling and 32 is unreachable in principle.
	#  Reaching it means a bug, so it has to bark.
	var full := SpellSim.new()
	for _i in Tuning.MAX_PROJECTILES:
		_fire(full, 100, 70, 1, 0)
	t.eq(full.active_count(), Tuning.MAX_PROJECTILES, "상한까지 채워진다")
	t.expect_error("simultaneous projectile cap")
	t.ok(not _fire(full, 100, 70, 1, 0), "상한을 넘으면 짖고 버린다")
	t.eq(full.active_count(), Tuning.MAX_PROJECTILES, "상한을 넘긴 발사가 배열을 안 늘린다")


## **The boundary function must not hand out an unusable command.**
##
## This is not an unreachable state — the design doc "extreme values" settled on "shoot at your feet and the terrain
##  disappears and the character falls; we do not block it", so **the character really does go below the grid.**
##  Without the clamp, left click then dies on `push_error` and on screen it only looks like "nothing happens".
func _aim_boundary(t) -> void:
	var sim := SpellSim.new()
	var mouse := Vector2(500.0, 300.0)

	var below := Vector2(400.0, float((CellGrid.H + 40) * Tuning.CELL_PX))
	var c1 := Aim.fire_cmd(below, mouse, Tuning.ELEM_FIRE, Glyph.GLYPH_NONE)
	t.eq(int(c1["oy"]), CellGrid.H - 1, "격자 아래로 나간 원점이 마지막 줄로 클램프된다")
	t.ok(sim.fire(c1), "격자 밖에서 쏴도 발사가 산다 (짖지 않는다)")

	var left := Vector2(-500.0, 200.0)
	var c2 := Aim.fire_cmd(left, mouse, Tuning.ELEM_FIRE, Glyph.GLYPH_NONE)
	t.eq(int(c2["ox"]), 0, "왼쪽 밖 원점이 0열로 클램프된다")
	t.ok(sim.fire(c2), "왼쪽 밖에서도 발사가 산다")

	# Aim has to be **relative to the clamped origin.** Move only the origin and subtract the raw mouse cell
	#  and the direction silently goes wrong when firing from outside the grid.
	t.eq(int(c2["adx"]), _cell(mouse.x) - 0, "조준이 클램프한 원점 기준으로 계산된다")

	# The cell conversion has to be `floori` — `int()` truncates toward 0 and jumps one cell
	#  **only outside the left and top of the screen**, which the eye can barely see.
	var c3 := Aim.fire_cmd(Vector2(4.0, 4.0), Vector2(-1.0, -1.0),
		Tuning.ELEM_FIRE, Glyph.GLYPH_NONE)
	t.eq(int(c3["adx"]), -2, "음수 px가 내림으로 셀이 된다 (floori)")


static func _cell(px: float) -> int:
	return floori(px / float(Tuning.CELL_PX))


## **Rolling ids back on reset makes an old trail stick to a new bolt.** The renderer pairs trails by id,
##  and it goes wrong on screen with not one error.
func _id_across_reset(t) -> void:
	var sim := SpellSim.new()
	_fire(sim, 100, 70, 1, 0)
	var before: int = sim.get_id()[0]
	sim.reset()
	t.eq(sim.active_count(), 0, "리셋이 탄을 전부 지운다")
	_fire(sim, 100, 70, 1, 0)
	t.ok(sim.get_id()[0] > before,
		"id가 리셋을 넘어 단조 증가한다 (%d → %d)" % [before, sim.get_id()[0]])


# ══════════════════════════════════════════════════════════════════
#  Glyph pipeline
# ══════════════════════════════════════════════════════════════════

## **Hangs glyphs that exist only in the table and not in code on the wrapper's stderr check for free** —
##  `_run_glyph` barks at an unknown id, so simply running `ALL` once each catches it.
##
## **If `ALL` is empty this check runs nothing and goes green.** That is how this repo dies, so
##  the count is pinned into the label — 0 is normal at stage 3 (bolts fly carrying an empty list),
##  and it turns on by itself at stages 4 and 6.
func _every_glyph_runs(t) -> void:
	t.ok(Glyph.ALL.size() == Glyph.DEFS.size(),
		"실행해 볼 문양이 %d개다 (ALL과 DEFS가 같다)" % Glyph.ALL.size())
	for id: int in Glyph.ALL:
		var g := _wall_grid()
		var sim := SpellSim.new()
		var one: Array[int] = [id]
		var nm: StringName = Glyph.DEFS[id]["name"]
		t.ok(_fire(sim, 10, 70, 100, 0, Glyph.pack(one)), "문양 %s를 실은 탄이 나간다" % nm)
		if sim.active_count() == 0:
			continue
		# **Pairs by the original bolt's id** — with spread, 8 new bolts remain after impact,
		#  so measuring by `active_count() == 0` goes red the moment spread arrives.
		var origin: int = sim.get_id()[0]
		for _i in 16:
			sim.step(g)
		t.ok(not _has_id(sim, origin), "문양 %s가 착탄에서 실행되고 원본 탄이 사라진다" % nm)


# ══════════════════════════════════════════════════════════════════
#  Blast — what the spell leaves in the world
# ══════════════════════════════════════════════════════════════════

## **An integer disc.** Erase as a rectangle and both "the corner" and "the cell count" below catch it.
##  If it is not a circle, determinism is fine but **the hole is square and does not read as a "blast"** — a screen
##   problem, so no error shows.
func _blast_command(t) -> void:
	var rd := Tuning.blast_rd(0)
	var cx := 100
	var cy := 70
	var g := _solid_grid()
	var before := g.count_material(Mat.STONE)
	# Ignition is not measured here (that is `net_fire`'s share) — the grid is all stone so there is nothing to
	#  catch, and `ignite_r` 0 means `src` is never read either way.
	g.apply(CellGrid.cmd_blast(cx, cy, rd, 0, CellGrid.IGNITE_ANY))

	t.eq(g.mat_at(cx, cy), Mat.EMPTY, "폭발 한가운데가 비었다")
	t.eq(g.mat_at(cx + rd, cy), Mat.EMPTY, "반경 끝(정확히 rd)이 비었다")
	t.eq(g.mat_at(cx + rd + 1, cy), Mat.STONE, "반경 밖 한 칸은 남았다")
	t.eq(g.mat_at(cx + rd, cy + rd), Mat.STONE, "대각 모서리는 안 지워진다 (네모가 아니라 원이다)")

	# A rectangle would be (2rd+1)^2 = 625 cells, a circle pi*r^2 ~= 452 cells. The 10% margin is the integer grid's share.
	var gone := before - g.count_material(Mat.STONE)
	var area := int(PI * rd * rd)
	t.ok(absi(gone - area) * 10 <= area,
		"지운 칸 수가 원 넓이에 붙는다 (%d칸 · πr²≈%d)" % [gone, area])

	# Outside the grid is **clamped.** Without the range check, `_mat[i]` raises an engine error per cell,
	#  and that is a silent death the `SCRIPT ERROR` grep does not catch.
	var edge := _solid_grid()
	edge.apply(CellGrid.cmd_blast(0, 0, rd, 0, CellGrid.IGNITE_ANY))
	t.eq(edge.mat_at(0, 0), Mat.EMPTY, "격자 모서리에서 터져도 지워진다")
	t.eq(edge.mat_at(rd + 1, 0), Mat.STONE, "모서리 폭발이 반경만큼만 지운다")

	# Radius 0 silently does nothing — once a spread floor is added, 0 can actually come out.
	var zero := _solid_grid()
	zero.consume_changed()
	zero.apply(CellGrid.cmd_blast(50, 50, 0, 0, CellGrid.IGNITE_ANY))
	t.eq(zero.consume_changed(), 0, "반경 0 폭발은 한 칸도 안 건드린다")


## **The single source for "does the screen need re-uploading".** A blast does not go through the command queue,
##  so if the shell holds its own latch it silently misses that latch and **the hole never appears on screen.**
func _changed_counter(t) -> void:
	var g := CellGrid.new()
	t.eq(g.consume_changed(), 0, "아무것도 안 바꿨으면 0이다")
	g.apply(CellGrid.cmd_fill(0, 0, 3, 3, Mat.STONE))
	t.eq(g.consume_changed(), 16, "채운 칸 수를 센다")
	t.eq(g.consume_changed(), 0, "읽으면 0으로 돌아간다")
	g.apply(CellGrid.cmd_blast(100, 70, Tuning.blast_rd(0), 0, CellGrid.IGNITE_ANY))
	t.ok(g.consume_changed() > 0, "폭발도 센다 (커맨드 큐를 안 지나는 변경이다)")


## The net's proxy for design acceptance 1: **put a glyph in and a terrain mark appears.**
func _blast_glyph(t) -> void:
	var g := _wall_grid()
	var sim := SpellSim.new()
	var before := g.count_material(Mat.STONE)
	var one: Array[int] = [Glyph.GLYPH_BLAST]
	t.ok(_fire(sim, 10, 70, 100, 0, Glyph.pack(one)), "폭발 문양을 실은 탄이 나간다")
	t.eq(_run_ticks(sim, g, 12), 1, "착탄에서 폭발이 한 번 일어난다")
	var after := g.count_material(Mat.STONE)
	t.ok(after < before, "벽에 구멍이 남는다 (돌 %d → %d)" % [before, after])

	# Control — **firing with no glyph carves far less.** Without it, the green above cannot tell
	#  "the blast carved it" from "impact carves that much anyway".
	#
	# **It used to read "with no glyph the terrain is untouched".** Since every impact carves
	#  (`spell_sim._impact` step (1)) that sentence died => the split is not "carves or not" but **"how much".**
	# **And that contrast is acceptance 4 itself** — what the reversed decision (`_rune_trace`'s "does not break terrain")
	#  originally meant to prevent is "spread looking like it doubles as a blast", and what prevents it is **the size difference.**
	#  If the two values get close, blast and impact smear together on screen again — **this is the alarm for that.**
	var g2 := _wall_grid()
	var s2 := SpellSim.new()
	var kept := g2.count_material(Mat.STONE)
	t.ok(_fire(s2, 10, 70, 100, 0), "문양 없이 쏜다 (진 + 룬만)")
	t.eq(_run_ticks(s2, g2, 12), 0, "문양이 없으면 폭발이 없다")
	var carved := kept - g2.count_material(Mat.STONE)
	var blown := before - after
	t.ok(carved > 0, "문양이 없어도 착탄이 판다 (%d칸)" % carved)
	# The threshold 4 is **a hand-picked value** — a floor cut well down from the radius-squared ratio (8^2/2^2 = 16x)
	#  to leave room for the integer grid and the "half disc" share. Raise the radius until the two start smearing
	#  together on screen and this barks first.
	t.ok(blown > carved * 4,
		"폭발이 착탄보다 4배 넘게 판다 (%d칸 vs %d칸)" % [blown, carved])


## **TERMINAL makes no bolt, so the next glyph runs on at the same spot** (GDD glyph execution rules).
##  The holes are at the same spot, so on screen they **look like one** — only the count distinguishes them. That is why the net measures it.
func _blast_chain(t) -> void:
	var g := _wall_grid()
	var sim := SpellSim.new()
	var two: Array[int] = [Glyph.GLYPH_BLAST, Glyph.GLYPH_BLAST]
	t.ok(_fire(sim, 10, 70, 100, 0, Glyph.pack(two)), "폭발 두 층을 실은 탄이 나간다")

	var bx := PackedInt32Array()
	var by := PackedInt32Array()
	for _i in 12:
		sim.step(g)
		if sim.blast_count() > 0 and bx.is_empty():
			# Take a copy — the next `step()` clears the notice.
			bx = sim.get_blast_x().duplicate()
			by = sim.get_blast_y().duplicate()
	t.eq(bx.size(), 2, "폭발 → 폭발이 **같은 틱에** 두 번 터진다")
	if bx.size() == 2:
		t.ok(bx[0] == bx[1] and by[0] == by[1],
			"두 폭발이 같은 자리다 ((%d,%d) · (%d,%d))" % [bx[0], by[0], bx[1], by[1]])
	t.eq(sim.pending_count(), 0, "예산(%d) 안이라 밀리지 않는다" % Tuning.MAX_BLASTS_PER_TICK)


## **Overflowing blasts are not dropped but pushed to the next tick.** Dropping them becomes "fire a burst and a few
##  don't go off", and that reads as **a malfunction** — being the exact opposite of the projectile cap (bark and drop) is the point.
## With spread in play, 8 bolts land on the same tick, so this path **is actually hit.**
func _blast_budget(t) -> void:
	var g := _wall_grid()
	var sim := SpellSim.new()
	var n := Tuning.MAX_BLASTS_PER_TICK * 2
	t.eq(_volley(sim, n), n, "%d발이 같은 틱에 착탄하도록 같이 난다" % n)

	var per_tick: Array[int] = []
	var total := 0
	for _i in 12:
		sim.step(g)
		per_tick.append(sim.blast_count())
		total += sim.blast_count()

	var over := false
	for v: int in per_tick:
		if v > Tuning.MAX_BLASTS_PER_TICK:
			over = true
	t.ok(not over, "한 틱에 %d발을 안 넘는다 %s" % [Tuning.MAX_BLASTS_PER_TICK, per_tick])
	t.eq(total, n, "밀린 폭발이 하나도 안 버려진다 (%d발 전부 터졌다)" % n)
	t.eq(sim.pending_count(), 0, "다 갚고 나면 밀린 것이 0이다")


## A notice is valid **only within that tick.** Leave the clearing to the shell and the moment it forgets once,
##  the same flash **replays forever**, with no error.
func _blast_notice(t) -> void:
	var g := _wall_grid()
	var sim := SpellSim.new()
	var one: Array[int] = [Glyph.GLYPH_BLAST]
	var packed := Glyph.pack(one)
	_fire(sim, 10, 70, 100, 0, packed)

	var seen := false
	for _i in 12:
		sim.step(g)
		if sim.blast_count() > 0:
			seen = true
			t.eq(int(sim.get_blast_gen()[0]), 0, "통지에 세대가 실린다")
			t.eq(int(sim.get_blast_element()[0]), Tuning.ELEM_FIRE, "통지에 룬이 실린다")
			break
	t.ok(seen, "폭발이 통지된다")
	sim.step(g)
	t.eq(sim.blast_count(), 0, "다음 틱에 통지가 지워진다")

	# If reset does not clear the pending pipeline, **the previous experiment's blast** punches a hole in terrain
	#  freshly built with R — acceptance 1 and 2, which compare two combinations, die right there.
	var g2 := _wall_grid()
	var s2 := SpellSim.new()
	_volley(s2, Tuning.MAX_BLASTS_PER_TICK * 2)
	for _i in 6:
		s2.step(g2)
		if s2.pending_count() > 0:
			break
	t.ok(s2.pending_count() > 0, "예산을 넘겨 밀린 것이 있다 (%d개)" % s2.pending_count())
	s2.reset()
	t.eq(s2.pending_count(), 0, "리셋이 밀린 파이프라인을 지운다")
	var kept := g2.count_material(Mat.STONE)
	s2.step(g2)
	t.eq(g2.count_material(Mat.STONE), kept, "리셋 뒤에는 밀린 폭발이 안 터진다")


# ══════════════════════════════════════════════════════════════════
#  Spread — order changes the kind of result
# ══════════════════════════════════════════════════════════════════

## The 8 directions are `(+-1,0) (0,+-1) (+-1,+-1)` — they come out as plain integers with no `sin` or `cos`.
##
## **"All eight directions differ" is measured from the table, and "eight bolts are born" from the blast count.**
##  It must not be counted from survivors — the impact point is **necessarily attached to something** (it stopped by hitting it),
##  and bolts born toward it die against that wall **on the very tick they were born.** Against a flat surface, three do.
##  => The survivor count is decided by terrain, and **the birth count is proved by the 8 blasts in `_order_changes_the_spell`.**
func _spread_makes_eight(t) -> void:
	# ── table ──
	t.eq(SpellSim.SPREAD_DX.size(), Tuning.SPREAD_COUNT, "방향 표 길이가 SPREAD_COUNT")
	t.eq(SpellSim.SPREAD_DY.size(), SpellSim.SPREAD_DX.size(), "두 방향 표 길이가 같다")
	var seen: Dictionary = {}
	for k in Tuning.SPREAD_COUNT:
		var dx: int = SpellSim.SPREAD_DX[k]
		var dy: int = SpellSim.SPREAD_DY[k]
		t.ok(absi(dx) <= 1 and absi(dy) <= 1 and (dx != 0 or dy != 0),
			"방향 %d이 (±1,0)(0,±1)(±1,±1) 중 하나다 (%d,%d)" % [k, dx, dy])
		seen["%d,%d" % [dx, dy]] = true
	t.eq(seen.size(), Tuning.SPREAD_COUNT, "여덟 방향이 전부 다르다")

	# ── actual flight ──
	var g := _cave_grid()
	var sim := SpellSim.new()
	var one: Array[int] = [Glyph.GLYPH_SPREAD]
	t.ok(_fire(sim, 22, 70, 100, 0, Glyph.pack(one)), "확산만 실은 탄이 나간다")
	var origin: int = sim.get_id()[0]
	for _i in 12:
		sim.step(g)
		if not _has_id(sim, origin):
			break

	var alive := sim.active_count()
	# Enough have to survive that the check does not spin idle (against a flat surface three go into the wall and die).
	t.ok(alive >= Tuning.SPREAD_COUNT - 3, "확산으로 난 탄이 살아 있다 (%d발)" % alive)

	var vx := sim.get_vx()
	var vy := sim.get_vy()
	var gens := sim.get_gen()
	var all_gen1 := true
	for i in alive:
		if int(gens[i]) != 1:
			all_gen1 = false
	t.ok(all_gen1, "확산으로 난 탄이 전부 세대 1이다")

	# **Measure by position. Do not measure by velocity sign** — after a single tick, gravity pushes every vy positive
	#  and (-1,0) and (-1,-1) become the same sign pair. Bolts born at the same spot have to be **in different cells**
	#  for it to be radial. "The eight directions differ" itself was already seen by the table check above.
	var px := sim.get_px()
	var py := sim.get_py()
	var spots: Dictionary = {}
	for i in alive:
		spots["%d,%d" % [px[i] >> SpellSim.FP_SHIFT, py[i] >> SpellSim.FP_SHIFT]] = true
	t.eq(spots.size(), alive, "살아남은 탄이 서로 다른 칸으로 흩어졌다")

	# **The small ones are weak** — speed comes from the generation table (drag range splits right here).
	# A newborn bolt **advances once on the very tick it is born** (`_spread_advances_on_birth_tick` below),
	#  so the observed value has already taken one tick of drag **and** one tick of gravity.
	#
	# **The band is derived from those two constants, not from a percentage.** It used to be
	#  `got2 <= want2` above and `70%` of `want2` below, and **the upper half was exact by coincidence**:
	#  one tick costs `speed_fp x (1 - DRAG)` and gravity adds a flat `GRAVITY_FP`, and those two are **equal at
	#  exactly speed 8** (2048 x 1/16 = 128). At generation 1's old 8 the downward bolt landed on `want2` to the
	#  unit; the moment `speed` went to 6 the same bolt came out **faster than its own table value** and this
	#  check went red for a trajectory that was entirely correct — below terminal fall speed (8 cells/tick) a
	#  falling bolt is supposed to accelerate. The percentage below was nearly as tight for the opposite reason:
	#  gravity's contribution is **flat**, so its share grows as `speed` falls, and the upward bolt sat 14.6%
	#  under the table value against a floor of 16.3%.
	# => Both ends now say what the sim actually does, and they follow `speed` down on their own:
	#      fastest  the downward bolt = `speed_fp` damped once, plus one tick of gravity
	#      slowest  the upward bolt   = `speed_fp` damped once, minus one tick of gravity  (met **exactly**)
	var want := Tuning.speed_cells(1) << SpellSim.FP_SHIFT
	var damped := want * Tuning.DRAG_NUM / Tuning.DRAG_DEN
	var hi := damped + Tuning.GRAVITY_FP
	var lo := damped - Tuning.GRAVITY_FP
	var in_band := true
	for i in alive:
		var got2: int = vx[i] * vx[i] + vy[i] * vy[i]
		if got2 > hi * hi or got2 < lo * lo:
			in_band = false
	t.ok(in_band,
		"확산 탄의 속도가 세대 1 값(%d셀/틱)에서 나온다 (한 틱 감쇠 %d에 중력 ±%d, 즉 %d~%d)"
			% [Tuning.speed_cells(1), damped, Tuning.GRAVITY_FP, lo, hi])
	t.ok(Tuning.speed_cells(1) < Tuning.speed_cells(0),
		"세대 1이 세대 0보다 느리다 (%d < %d)" % [Tuning.speed_cells(1), Tuning.speed_cells(0)])


## **"A glyph that makes bolts hands the remaining list over to the new bolts"** (GDD).
##  Without the hand-over, spread->blast becomes plain spread, and **one spell disappears with no error.**
func _spread_hands_over_list(t) -> void:
	var g := _cave_grid()
	var sim := SpellSim.new()
	var two: Array[int] = [Glyph.GLYPH_SPREAD, Glyph.GLYPH_BLAST]
	t.ok(_fire(sim, 22, 70, 100, 0, Glyph.pack(two)), "확산 → 폭발을 실은 탄이 나간다")

	var origin: int = sim.get_id()[0]
	for _i in 12:
		sim.step(g)
		if not _has_id(sim, origin):
			break

	# **Every single** survivor has to be carrying the blast. How many survive is decided by
	# terrain, so this measures the **ratio**, not the count (comment above).
	var alive := sim.active_count()
	t.ok(alive > 0, "확산으로 난 탄이 살아 있다 (%d발)" % alive)
	var gl := sim.get_glyphs()
	var carried := 0
	for i in alive:
		if Glyph.first(gl[i]) == Glyph.GLYPH_BLAST:
			carried += 1
	t.eq(carried, alive, "살아남은 탄이 **전부** 남은 목록(폭발)을 들고 간다")


## **A newborn bolt advances once on the very tick it is born.**
##  Removal is swap-remove, so `_remove` **pulls the just-born bolt into the current slot** and the loop
##  carries on over it. Not an accident but deterministic, and on screen it reads as "it bursts radially at the moment of impact".
## Without measuring this, the next person refactors it into **a spread that stalls for one tick** and never knows.
func _spread_advances_on_birth_tick(t) -> void:
	var g := _cave_grid()
	var sim := SpellSim.new()
	var one: Array[int] = [Glyph.GLYPH_SPREAD]
	_fire(sim, 22, 70, 100, 0, Glyph.pack(one))
	var origin: int = sim.get_id()[0]
	for _i in 12:
		sim.step(g)
		if not _has_id(sim, origin):
			break
	t.ok(sim.active_count() > 0, "확산이 일어났다")
	# Standing still where it was born means `_prev` and the current position are equal.
	var moved := true
	var px := sim.get_px()
	var py := sim.get_py()
	var qx := sim.get_prev_px()
	var qy := sim.get_prev_py()
	for i in sim.active_count():
		if px[i] == qx[i] and py[i] == qy[i]:
			moved = false
	t.ok(moved, "갓 난 탄이 태어난 틱에 이미 움직였다")


## **Everything this stage measures.** The same two glyphs, only the order different, and **the kind of result** has to differ.
##  · spread -> blast = the scattered ones each detonate -> **eight blasts**
##  · blast -> spread = one big detonation first, then it spreads from that spot -> **one blast**
## The net can only produce this **proxy value.** "Does it look like a different spell" is what the eye measures,
##  and if this is green while the screen does not split, **that is the signal for this stage to stop** (design acceptance).
func _order_changes_the_spell(t) -> void:
	var spread_then_blast: Array[int] = [Glyph.GLYPH_SPREAD, Glyph.GLYPH_BLAST]
	var blast_then_spread: Array[int] = [Glyph.GLYPH_BLAST, Glyph.GLYPH_SPREAD]

	var a := _count_blasts(Glyph.pack(spread_then_blast))
	var b := _count_blasts(Glyph.pack(blast_then_spread))
	t.eq(a, Tuning.SPREAD_COUNT, "확산 → 폭발은 폭발이 %d번이다" % Tuning.SPREAD_COUNT)
	t.eq(b, 1, "폭발 → 확산은 폭발이 1번이다")
	t.ok(a != b, "순서를 바꾸면 결과의 **종류**가 바뀐다 (%d회 vs %d회)" % [a, b])

	# The one-blast side is **generation 0** so it detonates big, and the eight-blast side is generation 1 so it detonates small.
	#  That difference splits the shape of the terrain mark (one hole vs eight holes).
	t.ok(Tuning.blast_rd(1) < Tuning.blast_rd(0),
		"세대 1 폭발이 더 작다 (rd %d < %d)" % [Tuning.blast_rd(1), Tuning.blast_rd(0)])


## Total blast count. **Counted in a closed cave** — all 8 spread bolts have to hit something for 8 to come out
##  (the same reason the design doc's "stage" chose a box).
func _count_blasts(packed: int) -> int:
	var g := _cave_grid()
	var sim := SpellSim.new()
	if not _fire(sim, 22, 70, 100, 0, packed):
		return -1
	var total := 0
	# The budget is 4 per tick, so 8 splits over at least two ticks. Generous enough for falling bolts to reach the floor.
	for _i in 90:
		sim.step(g)
		total += sim.blast_count()
	return total


## **The first consumer of `max_per_circle`.** The GDD chose to stop the explosion with a **constraint** rather than a cap,
##  and with only one spread the 8 -> 64 explosion becomes **structurally impossible.**
## Once the assembly window (B) exists it reads the same table and blocks it beforehand — the command boundary still stays.
##  The network does not go through the assembly window.
func _spread_capped_per_circle(t) -> void:
	t.eq(int(Glyph.DEFS[Glyph.GLYPH_SPREAD]["max_per_circle"]), 1,
		"확산은 한 마법진에 하나까지다 (GDD)")

	var sim := SpellSim.new()
	var twice: Array[int] = [Glyph.GLYPH_SPREAD, Glyph.GLYPH_SPREAD]
	t.expect_error("per magic circle")
	t.ok(not _fire(sim, 10, 70, 100, 0, Glyph.pack(twice)),
		"확산 두 겹은 발사 시점에 짖고 버려진다")
	t.eq(sim.active_count(), 0, "버린 발사가 탄을 안 남긴다")

	# Blast is unlimited, so two layers have to pass — a constraint that catches **every glyph** is a different bug.
	var blast_twice: Array[int] = [Glyph.GLYPH_BLAST, Glyph.GLYPH_BLAST]
	t.ok(_fire(sim, 10, 70, 100, 0, Glyph.pack(blast_twice)), "폭발 두 겹은 통과한다 (무제한)")

	# **A size floor.** With only one spread, generation 2 is already impossible in principle, but this is
	#  a structural floor for the day that rule loosens.
	t.ok(Tuning.SPLIT_MAX >= 1, "확산이 최소 한 번은 걸린다")


## **`kind` chooses "carry on or end"** (GDD, "glyph execution rules").
##  With no consumer on this axis, changing `kind` in the table does nothing, and then the rule survives
##   only in a comment. The two below are the observation points for that axis.
func _kind_decides_continuation(t) -> void:
	t.eq(int(Glyph.DEFS[Glyph.GLYPH_BLAST]["kind"]), Glyph.KIND_TERMINAL, "폭발은 TERMINAL이다")
	t.eq(int(Glyph.DEFS[Glyph.GLYPH_SPREAD]["kind"]), Glyph.KIND_SPAWN, "확산은 SPAWN이다")

	# TERMINAL: no bolt is created, so it **carries on at the same spot** => two blast layers detonate twice.
	var chain: Array[int] = [Glyph.GLYPH_BLAST, Glyph.GLYPH_BLAST]
	t.eq(_count_blasts(Glyph.pack(chain)), 2, "TERMINAL은 같은 자리에서 이어 실행된다")

	# SPAWN: the new bolts took the list, so it **ends here** => spread -> blast is 8 times, not 9.
	# If 9 comes out, the `kind` branch is dead and the list ran **twice.**
	var hand_over: Array[int] = [Glyph.GLYPH_SPREAD, Glyph.GLYPH_BLAST]
	t.eq(_count_blasts(Glyph.pack(hand_over)), Tuning.SPREAD_COUNT,
		"SPAWN은 목록을 넘기고 그 자리에서 끝난다 (8번이지 9번이 아니다)")


# ══════════════════════════════════════════════════════════════════
#  Carving — every impact carves terrain
# ══════════════════════════════════════════════════════════════════

## **Even with no glyph, even with a no-element rune, impact carves** (`spell_sim._impact` step (1)).
##
## **The hole this net fills was exactly "carve radius 0", and it was green the whole time** —
##  nobody barked until the user played the game and reported "ordinary magic and fire magic don't shrink the wall
##  by a single cell; **you can't even tell whether you attacked**".
##
## **Ending at "it shrank" leaves it green for any radius** —
##  the same shape as `net_damage._enqueue_becomes_a_projectile` ending at "it advanced" and letting
##  **double speed pass straight through.** => **Pin the radius down by depth.**
##  **Why depth and not vertical width**: the impact point is the **empty cell** left of the wall, so only the right
##   half of the disc goes into the wall. The vertical width of the wall's first column is `2*sqrt(r^2-1)+1`, which
##   **makes the net copy `_disc`**, and when the two split the net takes the wrong side. Depth is the `dy = 0` row,
##   so it is **exactly equal to the radius.**
func _every_impact_carves(t) -> void:
	# ── (1) Stone wall + no element. Half of what the user pointed at is here — "**ordinary magic and** fire magic".
	var stone := _cave_grid()
	var s := SpellSim.new()
	t.ok(s.fire(SpellSim.cmd_fire(22, 70, 100, 0, Tuning.ELEM_NONE, Glyph.GLYPH_NONE)),
		"무속성 · 문양 없는 탄이 돌벽으로 나간다")
	var before := stone.count_material(Mat.STONE)
	_run_until_impact(s, stone, 12)
	var carved := before - stone.count_material(Mat.STONE)
	t.ok(carved > 0, "돌이 준다 (%d칸 · 돌 %d → %d)" % [
		carved, before, stone.count_material(Mat.STONE)])
	# Carving is not a blast — no flash, no shake. That direction is what helps acceptance 4.
	t.eq(s.blast_count(), 0, "파기는 폭발 통지를 안 낸다 (구멍은 나는데 화면이 안 번쩍한다)")
	t.eq(_eaten_depth(stone), Tuning.carve_r(0),
		"판 깊이가 세대 0의 파는 반경(%d셀)이다" % Tuning.carve_r(0))

	# ── (2) Wood wall + fire rune — **no longer "carve and set fire in that spot". Wood is not carved at all**
	#  (`indestructible: true` on `WOOD` in `cell_materials.gd`; decided by the user).
	#  **This used to be a "ring"** — the inner `carve_r` was carved out (= empty = fuel 0 = cannot catch) and
	#  only the band `carve_r < r <= rune_r` burned. The one condition for that picture was "`carve_r < rune_r`"
	#  (fail it and carving erases the fuel the fire would burn, so the fire silently disappears).
	# **That condition is now meaningless for wood.** Carving (step (1)) is `cell_grid._disc(...,true)` and that
	#  function filters wood out via `_indestructible` (around line 888, `continue`) — the inside cannot be carved
	#  in principle, so **the ordering of `carve_r` and `rune_r` does not change the result** (the whole disc catches).
	#  The inequality itself is still measured per generation by `net_tables` — a floor for the day
	#  **a material that both breaks and burns** appears, not a sentence describing wood's picture today.
	var wood := _wood_cave_grid()
	var s2 := SpellSim.new()
	t.ok(_fire(s2, 22, 70, 100, 0), "불 룬 · 문양 없는 탄이 나무벽으로 나간다")
	_run_until_impact(s2, wood, 12)

	t.eq(_eaten_depth(wood), 0, "나무벽은 안 파인다 (폭발이 못 파듯 파기도 못 판다)")
	# Control — **stone is still carved** (the same value as (1) above). Without it, "not carved" above cannot tell
	#  "it distinguishes materials" from "carving itself is gone".
	t.eq(_eaten_depth(stone), Tuning.carve_r(0), "대조군 — 돌은 그대로 판다 (재료를 가린다)")

	t.ok(wood.burning_count() > 0, "그리고 나무에 불이 붙는다 (%d칸)" % wood.burning_count())
	# **A full disc, not a ring.** Carving erases nothing, so inside the destruction radius is still wood and
	#  it catches just the same within the ignition radius (rune_r) — the old picture with a hollow center is gone.
	t.eq(wood.mat_at(CAVE_X1 + 1, 70), Mat.WOOD, "파괴 반경 안쪽도 나무 그대로다 (안 파였다)")
	t.eq(wood.flag_at(CAVE_X1 + 1, 70) & Mat.FLAG_BURNING, Mat.FLAG_BURNING,
		"그 칸도 탄다 (더는 고리가 아니라 원반 전체다)")
	t.eq(_burn_depth(wood, CAVE_X1 + 1, CAVE_X1 + 20, CAVE_Y0, CAVE_Y1, true), Tuning.rune_r(0),
		"불이 점화 반경(%d셀)까지 닿는다 (중심에서 잰 반경이지 고리 폭이 아니라 이 값은 안 바뀐다)" % Tuning.rune_r(0))

	# **The path to disappearing is alive — fire, not carving, removes the wood.**
	#  From here `grid.step()` has to be called directly — the `sim.step(grid)` run up to now only moves
	#  bolts and does not burn (the same trap as the `_burn_depth` comment, the reason this net does not call it).
	var burn_ticks := int(Mat.DEFS[Mat.WOOD]["fuel"]) / Tuning.FIRE_BURN_PER_TICK
	for _i in burn_ticks + 5:
		wood.step()
	t.eq(wood.mat_at(CAVE_X1 + 1, 70), Mat.EMPTY,
		"다 타면 그 나무 칸이 빈칸이 된다 (없앤 것은 불이지 파기가 아니다)")


## **Shoot the same spot repeatedly and it pierces** (acceptance 3). The doc was opened by the user saying
##  "it doesn't shrink by a single cell", so **whether it pierces is the answer for this stage.**
## **The assertion stops at "it pierced" and the shot count is a record** — pinning a target number makes two copies
##  of the value, and the feel is decided by the screen (design doc, "undecided").
## **A fresh `SpellSim` every time** — firing one bolt at a time into the same grid is what "the same spot repeatedly"
##  means; bursting them from one sim sends eight bolts on the same tick, which is **a different situation.**
func _repeated_shots_pierce_the_wall(t) -> void:
	var g := _wall_grid()
	t.ok(not _wall_pierced(g), "쏘기 전에는 벽이 안 뚫려 있다 (검사의 전제)")
	var shots := 0
	while shots < 20 and not _wall_pierced(g):
		var sim := SpellSim.new()
		if not _fire(sim, 10, 70, 100, 0):
			break
		shots += 1
		_run_until_impact(sim, g, 12)
	# **The label has to say "which wall" too.** This wall is 4 cells = **half a tile**, while the stage's real tile
	#  is 8 cells (`sim_tuning.TILE_CELLS`) — reading the shot count here as the game's shot count is wrong.
	#  Measured (verify-run): **an 8-cell wall takes 5 shots.** It does not advance straight by `carve_r` per shot —
	#   gravity wobbles the impact row, so some shots land on a neighboring row a previous shot carved only shallowly.
	t.ok(_wall_pierced(g),
		"같은 자리를 반복해 쏘면 벽 %d셀(타일 %s장)이 뚫린다 (**%d발** — 기록이다)" % [
			WALL_X1 - WALL_X0 + 1,
			"%.1f" % (float(WALL_X1 - WALL_X0 + 1) / float(Tuning.TILE_CELLS)), shots])
	# Control — **one shot does not pierce.** Without it, the green above cannot tell "many shots pierced it"
	#  from "one shot pierces it anyway". The split between those two is acceptance 4 (a blast is one shot).
	t.ok(shots > 1, "한 발로는 안 뚫린다 (%d발이 필요했다)" % shots)


# ══════════════════════════════════════════════════════════════════
#  The rune's trace — even with no glyph, impact does at least what the rune does
# ══════════════════════════════════════════════════════════════════

## **The body of the design change.** A bolt with no glyph at all still does what the fire rune does on impact.
##  Without it, the eight bolts made by "blast -> spread" fly carrying **an empty list** and leave zero trace —
##   measured, key 5 touched nothing but one smooth hole. **Half the combinations evaporate from the screen.**
func _rune_leaves_a_trace(t) -> void:
	# Hit wood and it catches fire.
	var wood := _wood_cave_grid()
	var sim := SpellSim.new()
	t.ok(_fire(sim, 22, 70, 100, 0), "문양 없는 탄을 나무에 쏜다")
	var before := wood.count_material(Mat.WOOD)
	_run_until_impact(sim, wood, 12)
	t.ok(wood.burning_count() > 0,
		"문양이 없어도 착탄점에 불이 붙는다 (%d칸)" % wood.burning_count())

	# **The trace itself does not break terrain** — what carves is the impact (`_impact` step (1)), not the rune.
	#  **This used to be measured as "does not break a single cell", and that observation died.** Now that every
	#   impact carves, the remaining question is "**does the rune change how much is carved**", and the answer is
	#   "it does not" — step (1) has no branch.
	#  **That is the only behavioral observation preventing "some bolts carve and some do not".**
	#   Move `_impact` step (1) into `_rune_trace` and only no-element stops carving, and this goes red then.
	#  It has to be measured before the fire spreads — once it burns out the wood does shrink (that is the fire's doing, not the trace's).
	t.eq(before - wood.count_material(Mat.WOOD), _carved_by(Tuning.ELEM_NONE, true),
		"파는 양이 룬과 무관하다 (불 룬과 무속성이 나무를 같은 칸 수 판다)")
	t.eq(sim.blast_count(), 0, "룬 흔적은 폭발이 아니다 (폭발 통지가 0이다)")

	# Stone does not catch — there is no fuel. "Only where there is something to burn" holds here too.
	var stone := _cave_grid()
	var s2 := SpellSim.new()
	t.ok(_fire(s2, 22, 70, 100, 0), "문양 없는 탄을 돌에 쏜다")
	var kept := stone.count_material(Mat.STONE)
	_run_until_impact(s2, stone, 12)
	t.eq(stone.burning_count(), 0, "돌에는 흔적이 안 남는다 (연료가 0이다)")
	t.eq(kept - stone.count_material(Mat.STONE), _carved_by(Tuning.ELEM_NONE, false),
		"돌도 룬과 무관하게 같은 만큼 파인다")


## Fires one bolt at the same spot with rune `element` and **no glyph**, and returns how many material cells were lost.
## For controls only — "does the rune change how much is carved" can only be measured with **the same layout and the
##  same trajectory**, and behavior (speed, trajectory) being independent of the rune is a property pinned by `sim_tuning.ELEM_NONE`.
## `grid.step()` is not called, so **the fire does not spread** — the only cause of material loss is carving.
func _carved_by(element: int, wood_walls: bool) -> int:
	var g := _wood_cave_grid() if wood_walls else _cave_grid()
	var mat := Mat.WOOD if wood_walls else Mat.STONE
	var sim := SpellSim.new()
	if not sim.fire(SpellSim.cmd_fire(22, 70, 100, 0, element, Glyph.GLYPH_NONE)):
		push_error("net_spell: 대조군 발사가 거부됐다 (룬 %d)" % element)
		return -1
	var before := g.count_material(mat)
	_run_until_impact(sim, g, 12)
	return before - g.count_material(mat)


## Hangs runes that exist only in the table and not in code on **the wrapper's stderr check for free**
##  (`_rune_trace` barks at an unknown trace). The same device as `_every_glyph_runs`.
##
## **The label has to equal what is measured.** The old label was "rune %d's trace **stays in the world**" while
##  what was actually measured was `burning_count() > 0` alone — **no-element is 0 by definition, so that label is simply false.**
##  Skipping no-element with `continue` is **widening the amnesty** (CLAUDE.md). The label is narrowed instead:
##  "**for each rune, the result `ELEM_DEFS`'s `trace` names actually happens**".
## **The `else` being `t.ok(false)` is the heart of this correction** — the day a third kind of trace appears,
##  **the net barks before the code does.**
##
## **And this is the net for acceptance 7** (design doc, "is a no-element rune different from a fire rune").
##  No-element "does nothing", so **on screen it is indistinguishable from the shot being rejected** =>
##  four things are asserted **together**: `fire()` is true, a bolt was really born, it impacted and the original vanished,
##  **and the grid really changed.** Without that, the bug "no-element gets the shot rejected" is green too.
##  The last item had **its sign flipped** ("not a single cell changes" -> "it changes") —
##   carving became independent of the rune, so no-element carves too. The reason is written inside the branch.
## No separate control is built — **the fire rune in the same loop is the control** (same spot, same combination).
##  That is why the two branches measure `burning_count` in opposite directions.
func _every_rune_traces(t) -> void:
	t.eq(Tuning.ELEM_ALL.size(), Tuning.ELEM_DEFS.size(),
		"착탄시켜 볼 룬이 %d개다" % Tuning.ELEM_ALL.size())
	for element: int in Tuning.ELEM_ALL:
		var g := _wood_cave_grid()
		var sim := SpellSim.new()
		t.ok(sim.fire(SpellSim.cmd_fire(22, 70, 100, 0, element, Glyph.GLYPH_NONE)),
			"룬 %d: fire()가 참을 준다" % element)
		# Do not trust `fire()`'s true alone — was a bolt **really** born?
		t.eq(sim.active_count(), 1, "룬 %d: 탄이 실제로 났다" % element)
		if sim.active_count() != 1:
			# Slipping past silently here does not make the check "fail" — it **disappears.**
			t.ok(false, "룬 %d: 탄이 없어서 흔적을 **하나도 못 쟀다**" % element)
			continue
		var origin: int = sim.get_id()[0]

		# **Zero the counter here.** Counting the cave dig too makes "it did not change" below meaningless.
		g.consume_changed()
		_run_until_impact(sim, g, 12)
		t.ok(not _has_id(sim, origin), "룬 %d: 탄이 착탄까지 살아서 사라졌다" % element)
		# Read it once only — `consume_changed()` **returns to 0 when read.**
		var changed := g.consume_changed()

		var def: Variant = Tuning.ELEM_DEFS.get(element, null)
		t.ok(def is Dictionary, "룬 %d이 ELEM_DEFS에 있다" % element)
		if not (def is Dictionary):
			continue
		var trace := int((def as Dictionary).get("trace", -1))
		if trace == Tuning.TRACE_IGNITE:
			t.ok(g.burning_count() > 0,
				"룬 %d(점화): 불이 붙는다 (%d칸)" % [element, g.burning_count()])
			t.ok(changed > 0, "룬 %d(점화): 격자가 실제로 변했다 (%d칸)" % [element, changed])
		elif trace == Tuning.TRACE_NONE:
			t.eq(g.burning_count(), 0, "룬 %d(흔적 없음): 불이 한 칸도 안 붙는다" % element)
			# **This used to read "not a single grid cell changes".** The meaning of no-element narrowed from
			#  "does nothing to the world" to **"leaves no trace"** — carving moved up into
			#  `_impact` step (1) and became independent of the rune, and the user pointed out that
			#  **ordinary magic too** has to carve the wall.
			# **"It is distinguishable from the shot being rejected" still has to hold**, so a **positive** number
			#  is required instead of 0. Without it, the bug "no-element gets the shot rejected" goes green again.
			t.ok(changed > 0,
				"룬 %d(흔적 없음): 그래도 격자를 판다 (%d칸)" % [element, changed])
		elif trace == Tuning.TRACE_WET:
			# **A mirror of the fire branch.** Fired at the same spot with the same combination; only **what is left** differs.
			#  => The fire rune in the same loop serves as the control (the wording of the comment above).
			t.ok(g.count_material(Mat.WATER) > 0,
				"룬 %d(적심): 물이 생긴다 (%d칸)" % [element, g.count_material(Mat.WATER)])
			# **The water rune does not ignite.** Without measuring the other side, "every rune does everything" passes.
			t.eq(g.burning_count(), 0, "룬 %d(적심): 불은 한 칸도 안 붙는다" % element)
			t.ok(changed > 0, "룬 %d(적심): 격자가 실제로 변했다 (%d칸)" % [element, changed])
		else:
			t.ok(false, "흔적 종류 %d에 이 그물이 단언을 안 갖고 있다 (룬 %d)" % [trace, element])


## **`_rune_trace`'s `TRACE_NONE` branch cannot be held by behavior.**
##  Delete those two lines and **every assertion above still passes** — "does nothing" and "barks and does nothing"
##  are indistinguishable on the grid (measured). The only thing that catches it is the wrapper's stderr.
##
## **But the reason that bark is not amnestied right now is "the wording happens to differ".** The day anyone
##  declares something like `expect_error("SpellSim: rune trace")` anywhere — **an amnesty applies to the whole run** —
##  this branch becomes **code nobody watches.** => Rather than lean on coincidence, one needle is hung here.
##
## **What the label measures**: only "`_rune_trace` **has** a `TRACE_NONE` branch".
##  **It is not "no-element does nothing"** — that is behavior, and text only sees syntax.
##   The behavior side is measured by `_every_rune_traces` above.
func _rune_trace_has_the_none_branch(t) -> void:
	var raw := _read(SPELL_SIM_SCRIPT)
	t.ok(raw.length() > 0, "spell_sim.gd를 읽었다 (%d바이트)" % raw.length())
	t.ok(not raw.contains("\"\"\""), "spell_sim.gd에 삼중 따옴표가 없다 (스트리퍼가 못 다룬다)")
	var body := _func_body(NetDeterminism._strip(raw), "_rune_trace")
	# **If the function is not found this is an empty string and everything below becomes a free "absent".** The premise is asserted first.
	t.ok(body.length() > 0, "spell_sim.gd에서 `_rune_trace` 본문을 떠냈다 (%d자)" % body.length())
	t.ok(body.contains("TRACE_IGNITE"),
		"떠낸 것이 정말 `_rune_trace`다 (이미 아는 갈래가 들어 있다)")
	t.ok(body.contains("Tuning.TRACE_NONE"), "`_rune_trace`에 `TRACE_NONE` 갈래가 있다")


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("net_spell: %s 를 못 읽었다" % path)
		return ""
	return f.get_as_text()


## From `func <name>(` **up to just before the next `func`.** If the function is absent this is an empty string —
##  the caller has to assert that.
func _func_body(src: String, nm: String) -> String:
	var head := src.find("func %s(" % nm)
	if head < 0:
		return ""
	var tail := src.find("\nfunc ", head + 1)
	return src.substr(head, -1 if tail < 0 else tail - head)


## **This check is the reason for the design change itself.**
##  The eight bolts born from spread fly carrying **an empty list.** If they each leave no trace,
##  the **embers half of "1 blast + 8 branches of embers" is missing entirely.**
##
## "Did it catch fire" is not enough — it is true even if only the parent caught.
##  => It measures **how widely the burning cells scattered.** Spread flies in 8 directions and each hits a different
##   wall, so the box is wide; a single glyph-less shot has only one impact point, so it is narrow.
func _empty_list_bolts_leave_marks(t) -> void:
	var lone := _burning_spread(Glyph.GLYPH_NONE)
	var one: Array[int] = [Glyph.GLYPH_SPREAD]
	var spread := _burning_spread(Glyph.pack(one))
	t.ok(lone > 0, "문양 없는 한 발도 흔적을 남긴다 (폭 %d셀)" % lone)
	t.ok(spread > lone * 2,
		"확산 여덟 발의 흔적이 훨씬 넓게 흩어진다 (폭 %d셀 vs %d셀)" % [spread, lone])


## **A bolt carrying a glyph also leaves a trace.**
##  Measured: adding an "only when the list is empty" branch to `_impact` left all 574 checks green —
##   because every rune check fired **glyph-less bolts** only. The branch was left out to keep the rule from
##   splitting in two, but **nobody was holding that decision.**
##
## **It cannot be measured with blast** — `rune_r < rd` is the contract, so the trace is buried entirely inside the blast radius.
##  => It is measured with **spread.** Spread does no destruction, so the original's trace stays on the wall.
## **Depth splits it.** The original is generation 0 and digs 3 cells into the wall; a bolt born from spread is generation 1 and digs 1.
##  Both strike **the same wall**, so "did it catch fire" cannot tell them apart.
func _glyph_bolt_also_traces(t) -> void:
	var g := _wood_cave_grid()
	var sim := SpellSim.new()
	var one: Array[int] = [Glyph.GLYPH_SPREAD]
	t.ok(_fire(sim, 22, 70, 100, 0, Glyph.pack(one)), "확산을 실은 탄이 나간다")
	_run_until_impact(sim, g, 12)
	t.eq(_burn_depth(g, CAVE_X1 + 1, CAVE_X1 + 20, CAVE_Y0, CAVE_Y1, true), Tuning.rune_r(0),
		"문양을 든 탄도 흔적을 남긴다 (벽 %d셀 — 세대 1 흔적 %d셀로는 못 낸다)" % [
			Tuning.rune_r(0), Tuning.rune_r(1)])


## **A generation 1 trace has to be smaller than a generation 0 one.**
##  Measured: replacing `Tuning.rune_r(gen)` with `rune_r(0)` left all 574 checks green —
##   `net_tables` measures **only the table's monotonicity.** Nobody watched the derived path.
##   Then "the small ones are weak" fails to show on screen on this axis alone, and
##   **the "8 branches of embers" come up as thick as the original.**
##
## **Measured from the floor.** The original died at the right wall and its trace is 3 cells, so it cannot reach the floor 12 cells below.
##  => The marks left on the floor belong **only to the generation 1 bolts born from spread.**
func _rune_trace_follows_gen(t) -> void:
	var g := _wood_cave_grid()
	var sim := SpellSim.new()
	var one: Array[int] = [Glyph.GLYPH_SPREAD]
	_fire(sim, 22, 70, 100, 0, Glyph.pack(one))
	for _i in 20:
		sim.step(g)
	var depth := _burn_depth(g, CAVE_X0, CAVE_X1, CAVE_Y1 + 1, CAVE_Y1 + 20, false)
	t.ok(depth > 0, "확산으로 난 탄이 바닥에도 흔적을 남긴다")
	t.eq(depth, Tuning.rune_r(1),
		"그 흔적이 **세대 1** 크기다 (%d셀 · 세대 0이면 %d셀이다)" % [depth, Tuning.rune_r(0)])


## **If no slots are free and not one spread bolt is born, the remaining list runs at the impact point as generation 0** —
##  "spread -> blast" becomes **one big hole** instead of eight small ones. That is the difference the GDD pinned as a different spell.
##  => Rather than silently becoming a different spell it has to **bark and drop.**
##
## This is not an unreachable state — four quick clicks against a wall reach it.
func _spread_without_room(t) -> void:
	var g := _cave_grid()
	var sim := SpellSim.new()

	# Fires spread -> blast right in front of the wall. It lands on the first tick.
	var two: Array[int] = [Glyph.GLYPH_SPREAD, Glyph.GLYPH_BLAST]
	t.ok(_fire(sim, CAVE_X1 - 2, 70, 100, 0, Glyph.pack(two)), "확산 → 폭발을 실은 탄이 나간다")
	# Fills the remaining slots with **long-flying** bolts (they cross the room to the left).
	while sim.active_count() < Tuning.MAX_PROJECTILES:
		_fire(sim, CAVE_X1 - 2, 70, -100, -20)
	t.eq(sim.active_count(), Tuning.MAX_PROJECTILES, "슬롯이 꽉 찬 채로 확산이 착탄한다")

	# 8 `_launch` failures plus spread's own bark. Both are legitimate.
	t.expect_error("simultaneous projectile cap")
	t.expect_error("spread got not one slot")
	var total := 0
	for _i in 40:
		sim.step(g)
		total += sim.blast_count()
	t.eq(total, 0,
		"슬롯이 없으면 남은 폭발을 **버린다** (세대 0 폭발 한 방으로 안 바뀐다)")

	# Control — with room, the same list gives 8 blasts. Without it, the 0 above cannot tell
	#  "it dropped them" from "it never detonates anyway".
	t.eq(_count_blasts(Glyph.pack(two)), Tuning.SPREAD_COUNT,
		"자리가 있으면 같은 목록이 폭발 %d회다" % Tuning.SPREAD_COUNT)


## **Does the crater size come from the generation table?**
##  The notice does not carry the radius (presentation does not use it), so whether `_run_glyph` uses `blast_rd(gen)`
##  can only be measured **from the hole left in the grid.**
##
## **Measuring with generation 0 spins idle.** `blast_rd(0)` is 12, so hardcoding 12 in the code still gives 12 == 12 —
##  it was written that way at first, with a comment saying "a hardcoded constant would not be caught", and it
##  **passed exactly that case.** => **It has to be measured with generation 1 (6 cells) for "does it really read the table" to split.**
## How to make **exactly one** generation 1 blast: spread with only 1 free slot left. Then only the first direction
##  (+1,0) is born, lands on the side wall immediately, and exactly one crater remains.
func _crater_follows_gen(t) -> void:
	var one: Array[int] = [Glyph.GLYPH_BLAST]
	t.eq(_crater_depth(Glyph.pack(one), Tuning.MAX_PROJECTILES - 1), Tuning.blast_rd(0),
		"세대 0 구덩이가 %d셀이다" % Tuning.blast_rd(0))

	var two: Array[int] = [Glyph.GLYPH_SPREAD, Glyph.GLYPH_BLAST]
	t.expect_error("simultaneous projectile cap")
	# **The parent's carving pushes the wall back by `carve_r(0)`** — the child lands that much deeper,
	#  so the depth is **the sum of the two values.**
	#  It used to be `blast_rd(1)` alone. Once impact started carving, this arrangement shifted by one step.
	var want := Tuning.carve_r(0) + Tuning.blast_rd(1)
	t.eq(_crater_depth(Glyph.pack(two), 1), want,
		"세대 1 구덩이가 %d셀이다 (부모가 판 %d + 세대 1 폭발 %d · 표를 실제로 읽는다)" % [
			want, Tuning.carve_r(0), Tuning.blast_rd(1)])
	t.ok(Tuning.blast_rd(1) < Tuning.blast_rd(0), "두 값이 애초에 다르다 (검사가 헛돌지 않는다)")


## **Does the carve radius follow generation too** (the behavior axis of acceptance 7).
##  `net_tables` measures **only the table's monotonicity** — replace `Tuning.carve_r(gen)` with `carve_r(0)`
##   and the table axis stays entirely green. `_rune_trace_follows_gen` was already burned in the same place
##   with the rune trace (measured, all 574 green), and carving takes the same derived path.
##
## **Split by the sum of depths**: the parent (generation 0) pushes the wall back by `carve_r(0)`, and the
##  generation 1 bolt born from spread carves `carve_r(1)` more **from that spot** => ignore generation and it is `carve_r(0) x 2`.
func _carve_follows_gen(t) -> void:
	# No glyph at all — only impact carves, so the depth is the radius itself.
	t.eq(_crater_depth(Glyph.GLYPH_NONE, 0), Tuning.carve_r(0),
		"문양 없는 한 발이 벽을 세대 0 반경(%d셀)만큼 판다" % Tuning.carve_r(0))

	var one: Array[int] = [Glyph.GLYPH_SPREAD]
	t.expect_error("simultaneous projectile cap")
	var want := Tuning.carve_r(0) + Tuning.carve_r(1)
	t.eq(_crater_depth(Glyph.pack(one), 1), want,
		"확산 한 발이 그보다 세대 1 반경(%d셀)만큼 더 판다 (합 %d셀)" % [Tuning.carve_r(1), want])
	t.ok(Tuning.carve_r(1) < Tuning.carve_r(0),
		"두 값이 애초에 다르다 (%d < %d · 검사가 헛돌지 않는다)" % [
			Tuning.carve_r(1), Tuning.carve_r(0)])


## How many cells it dug into the right wall. Fires with only `free_slots` free slots left.
func _crater_depth(packed: int, free_slots: int) -> int:
	var g := _cave_grid()
	var sim := SpellSim.new()
	if not _fire(sim, CAVE_X1 - 2, 70, 100, 0, packed):
		return -1
	# The filler bolts fly **left** — they land on the opposite wall, so they do not mix into the right wall's measurement.
	#  The reasoning used to be "no glyph, so they do not break terrain", and **that became false**
	#   (every impact carves). The reasoning that actually still holds is **direction.**
	while sim.active_count() < Tuning.MAX_PROJECTILES - free_slots:
		if not _fire(sim, CAVE_X1 - 2, 70, -100, -20):
			break
	for _i in 30:
		sim.step(g)
	return _eaten_depth(g)


## How many cells of the right wall disappeared. The destruction counterpart of `_burn_depth`, and **it measures the same wall** —
##  put the two depths side by side and the ring "the inside is carved and the outer band burns" comes out as a value.
## Inside the room (x <= `CAVE_X1`) is empty to begin with and is not counted. What is counted is only **how deep the wall was eaten.**
func _eaten_depth(g: CellGrid) -> int:
	var reach := CAVE_X1
	for y in range(CAVE_Y0, CAVE_Y1 + 1):
		for x in range(CAVE_X1 + 1, CAVE_X1 + 40):
			if g.mat_at(x, y) == Mat.EMPTY:
				reach = maxi(reach, x)
	return reach - CAVE_X1


## **If only part of the spread is born, the spell proceeds with the radial pattern squashed to one side.**
##  The net was measuring only the 0-bolt case, so nobody looked at the middle states of 1-7 bolts.
## The contract measured here: **it detonates as many times as were born.** If even one is born the list is handed
##  to them and **it does not run at the impact point as generation 0** — that would give `free+1` times.
func _spread_partial(t) -> void:
	var two: Array[int] = [Glyph.GLYPH_SPREAD, Glyph.GLYPH_BLAST]
	var packed := Glyph.pack(two)
	t.expect_error("simultaneous projectile cap")
	for free_slots: int in [1, 4, 7]:
		var g := _cave_grid()
		var sim := SpellSim.new()
		_fire(sim, CAVE_X1 - 2, 70, 100, 0, packed)
		while sim.active_count() < Tuning.MAX_PROJECTILES - free_slots:
			if not _fire(sim, CAVE_X1 - 2, 70, -100, -20):
				break
		var total := 0
		for _i in 60:
			sim.step(g)
			total += sim.blast_count()
		t.eq(total, free_slots,
			"자유 슬롯 %d개면 폭발이 %d회다 (태어난 수만큼만)" % [free_slots, free_slots])


## How many cells the fire dug outside the room. With `horizontal` it is the right wall's depth, otherwise the floor's.
## This net does not call `grid.step()` => **the fire does not spread.**
##  What is measured is **the ignition mark**, not the fire — which is why the depth exactly equals the radius.
func _burn_depth(g: CellGrid, x0: int, x1: int, y0: int, y1: int, horizontal: bool) -> int:
	var far := -1
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if (g.flag_at(x, y) & Mat.FLAG_BURNING) == 0:
				continue
			far = maxi(far, x if horizontal else y)
	if far < 0:
		return 0
	return far - (CAVE_X1 if horizontal else CAVE_Y1)


## The horizontal width (cells) of the burning cells. The value that carries **whether the trace is in one place or eight.**
## Fire spreads, so the two combinations have to be measured over **the same tick count** for the comparison to hold.
func _burning_spread(packed: int) -> int:
	var g := _wood_cave_grid()
	var sim := SpellSim.new()
	if not _fire(sim, 22, 70, 100, 0, packed):
		return -1
	for _i in 16:
		sim.step(g)
	var lo := CellGrid.W
	var hi := -1
	for y in range(50, 92):
		for x in range(10, 70):
			if (g.flag_at(x, y) & Mat.FLAG_BURNING) != 0:
				lo = mini(lo, x)
				hi = maxi(hi, x)
	return 0 if hi < 0 else hi - lo + 1


# ══════════════════════════════════════════════════════════════════
#  levelup-and-three-picks Stage A — power_pct / MODIFY
# ══════════════════════════════════════════════════════════════════

## **Composition is a product.** `[DUMMY_U, DUMMY_R]` -> `100 * 200/100 * 150/100 = 300` — the plan's own
##  worked example. Read right after `fire()`, before any tick runs, so nothing but `_launch`'s own MODIFY
##  stripping could have produced this number.
func _power_composition_is_a_product(t) -> void:
	var sim := SpellSim.new()
	var list: Array[int] = [Glyph.DUMMY_U, Glyph.DUMMY_R]
	t.ok(_fire(sim, 100, 70, 1, 0, Glyph.pack(list)), "[더미(상), 더미(중)]을 실은 탄이 나간다")
	var want := Tuning.POWER_BASE * Glyph.power_pct_of(Glyph.DUMMY_U) / 100 \
		* Glyph.power_pct_of(Glyph.DUMMY_R) / 100
	t.eq(sim.get_power()[0], want,
		"위력 합성이 곱이다 (100 × %d%% × %d%% = %d)" % [
			Glyph.power_pct_of(Glyph.DUMMY_U), Glyph.power_pct_of(Glyph.DUMMY_R), want])
	t.eq(sim.get_glyphs()[0], Glyph.GLYPH_NONE, "더미 둘 다 발사 시점에 소모돼 남은 목록이 빈다")


## **The check that proves MODIFY is applied at launch and not at impact.** `[dummy, spread]` and
##  `[spread, dummy]` must differ: in the first, the flying **parent** is boosted and the 8 **children** are not
##  (the parent already flew; only what SPAWN makes can change); in the second, the parent is normal and each
##  child strips the dummy **at its own launch** when spread hands it the remaining list.
## Built as a `_run_glyph` branch instead, MODIFY could never raise the damage of the bolt carrying it — the
##  direct hit is tested per tick during flight and has already happened by the time impact runs. This is the
##  net that would catch exactly that regression: both combinations would collapse to "nobody is boosted".
func _modify_composes_at_launch_not_impact(t) -> void:
	var boost := Glyph.power_pct_of(Glyph.DUMMY_U)

	# [dummy, spread] — the parent hits harder, the 8 children do not.
	var g_a := _cave_grid()
	var sim_a := SpellSim.new()
	var list_a: Array[int] = [Glyph.DUMMY_U, Glyph.SPREAD_C]
	t.ok(_fire(sim_a, 22, 70, 100, 0, Glyph.pack(list_a)), "[더미, 확산]을 실은 탄이 나간다")
	t.eq(sim_a.get_power()[0], boost, "발사 즉시 부모 탄의 위력이 더미만큼 올랐다 (%d)" % boost)
	var origin_a: int = sim_a.get_id()[0]
	for _i in 12:
		sim_a.step(g_a)
		if not _has_id(sim_a, origin_a):
			break
	var alive_a := sim_a.active_count()
	t.ok(alive_a > 0, "확산 자식이 살아 있다 (%d발)" % alive_a)
	var pow_a := sim_a.get_power()
	var children_boosted := false
	for i in alive_a:
		if pow_a[i] != Tuning.POWER_BASE:
			children_boosted = true
	t.ok(not children_boosted, "확산 자식은 부모의 위력을 안 물려받는다 (전부 기본값 %d)" % Tuning.POWER_BASE)

	# [spread, dummy] — the parent is normal, each child strips the dummy at its own launch.
	var g_b := _cave_grid()
	var sim_b := SpellSim.new()
	var list_b: Array[int] = [Glyph.SPREAD_C, Glyph.DUMMY_U]
	t.ok(_fire(sim_b, 22, 70, 100, 0, Glyph.pack(list_b)), "[확산, 더미]를 실은 탄이 나간다")
	t.eq(sim_b.get_power()[0], Tuning.POWER_BASE, "발사 즉시 부모 탄의 위력이 그대로다 (%d)" % Tuning.POWER_BASE)
	var origin_b: int = sim_b.get_id()[0]
	for _i in 12:
		sim_b.step(g_b)
		if not _has_id(sim_b, origin_b):
			break
	var alive_b := sim_b.active_count()
	t.ok(alive_b > 0, "확산 자식이 살아 있다 (%d발)" % alive_b)
	var pow_b := sim_b.get_power()
	var all_children_boosted := true
	for i in alive_b:
		if pow_b[i] != boost:
			all_children_boosted = false
	t.ok(all_children_boosted, "이번엔 자식들이 **자기** 발사에서 더미를 벗겨 위력이 올랐다 (전부 %d)" % boost)


## **`count_family` is the actual `max_per_circle` consumer now, not `count_of`.** Common-spread and
##  rare-spread are two different ids in one family — `count_of` (counting exact ids) would let them into the
##  same circle together, and that is precisely the 8 -> 64 explosion the GDD's constraint exists to block.
##
## **Why this net does not assert 64**: `SPLIT_MAX` (generation floor) independently blocks a *second* spread
##  from ever spawning children at all — measured, even driving this exact packed list straight into `_launch`
##  (bypassing `fire()`'s gate entirely) produces only the first spread's 8 children, never 64, because the
##  children's own generation already exceeds `SPLIT_MAX` before they could spawn again. Asserting 64 here
##  would be measuring a number the running code cannot actually produce — the label would claim more than the
##  check measures (CLAUDE.md, "no fake nets"). What this net asserts instead is the two things
##  `count_family` is actually responsible for: the rejection at the gate, and that the counting itself really
##  spans different ids of one family (which `count_of` — kept below it, unrenamed — provably does not).
func _family_cap_blocks_mixed_rarity(t) -> void:
	var sim := SpellSim.new()
	var mixed: Array[int] = [Glyph.SPREAD_C, Glyph.SPREAD_R]
	t.eq(Glyph.family_of(Glyph.SPREAD_C), Glyph.family_of(Glyph.SPREAD_R),
		"커먼 확산과 레어 확산이 같은 계통이다 (검사의 전제)")
	t.ok(Glyph.SPREAD_C != Glyph.SPREAD_R, "그런데 id는 서로 다르다 (count_of라면 안 걸렸을 조합)")

	t.expect_error("per magic circle")
	t.ok(not _fire(sim, 10, 70, 100, 0, Glyph.pack(mixed)),
		"커먼 확산 + 레어 확산은 (한 계통이라) 발사 시점에 짖고 버려진다")
	t.eq(sim.active_count(), 0, "버린 발사가 탄을 안 남긴다")

	# The function itself, isolated from the sim — this is exactly what `_valid_glyphs` calls.
	t.eq(Glyph.count_family(Glyph.pack(mixed), Glyph.FAMILY_SPREAD), 2,
		"count_family가 서로 다른 id 둘을 한 계통으로 센다 (2)")
	# **Inversion, by contrast**: `count_of` (unrenamed, still a real function) counts only the exact id —
	#  this is the value the old cap check would have seen, and why it would have let the combination through.
	t.eq(Glyph.count_of(Glyph.pack(mixed), Glyph.SPREAD_C), 1,
		"대조 — count_of는 정확히 이 id만 센다 (그래서 id 기준이면 이 조합을 못 막는다)")


## **A behavior pin for `net_tables`'s `LAUNCH_KINDS` partition** — that table check can only say MODIFY is
##  *classified* as launch-only; it cannot see whether the running code actually honors that. Fire a list
##  starting with a dummy and confirm the launched bolt's own remaining list holds **no** MODIFY id (it was
##  fully consumed at `_launch`), asserted directly rather than by the absence of a bark.
func _modify_never_reaches_the_pipeline(t) -> void:
	var sim := SpellSim.new()
	var list: Array[int] = [Glyph.DUMMY_C, Glyph.BLAST_C]
	t.ok(_fire(sim, 100, 70, 1, 0, Glyph.pack(list)), "[더미, 폭발]을 실은 탄이 나간다")
	var g := sim.get_glyphs()[0]
	var cur := g
	var saw_modify := false
	while cur != Glyph.GLYPH_NONE:
		if int(Glyph.DEFS[Glyph.first(cur)]["kind"]) == Glyph.KIND_MODIFY:
			saw_modify = true
		cur = Glyph.rest(cur)
	t.ok(not saw_modify, "발사된 탄의 남은 목록에 MODIFY 문양이 하나도 없다 (발사 시점에 다 소모됐다)")
	t.eq(Glyph.first(g), Glyph.BLAST_C, "더미가 빠지고 폭발만 남았다")


## **`[DUMMY_U, BLAST_C]` blast power is 200, `[BLAST_C]` alone is 100.** Inversion: drop the `power *`
##  multiplication in `_run_glyph`'s TERMINAL branch and this goes red — a dummy in one of the game's only
##  two real glyph families (blast) would become a false knob that does nothing when it matters most, since
##  the terrain effect is what actually reaches a monster (a bolt detonates on terrain; the monster is hit by
##  the blast, not the segment).
func _terminal_compounds_carried_power(t) -> void:
	var plain_power := _first_blast_power(_wall_grid(), Glyph.pack([Glyph.BLAST_C]))
	t.eq(plain_power, Tuning.POWER_BASE, "혼자면 폭발 위력이 기본값이다 (%d)" % Tuning.POWER_BASE)

	var boosted_power := _first_blast_power(_wall_grid(), Glyph.pack([Glyph.DUMMY_U, Glyph.BLAST_C]))
	var want := Tuning.POWER_BASE * Glyph.power_pct_of(Glyph.DUMMY_U) / 100 * Glyph.power_pct_of(Glyph.BLAST_C) / 100
	t.eq(boosted_power, want,
		"더미를 앞세우면 폭발 위력이 그 값을 물려받아 곱해진다 (%d)" % want)
	t.ok(boosted_power != plain_power, "그리고 실제로 혼자일 때와 다르다 (%d ≠ %d)" % [boosted_power, plain_power])


## **`[DUMMY_U, SPREAD_C]` child power is 100, not 200.** Inversion: make SPAWN compound the carried power
##  instead of reseeding (mirror the TERMINAL branch's `power *` onto SPAWN) and this goes red — inheriting
##  the parent's power would multiply one dummy across all 8 children, the GDD's explosion runaway showing up
##  in the damage dimension instead of the bolt-count dimension.
## **A narrower, standalone pin of the same fact `_modify_composes_at_launch_not_impact` already establishes**
##  in the middle of a longer two-combination scenario — kept anyway, the same reasoning as
##  `_blast_power_does_not_leak_between_layers` below: pin it before someone "simplifies" it.
func _spawn_does_not_compound_carried_power(t) -> void:
	var g := _cave_grid()
	var sim := SpellSim.new()
	t.ok(_fire(sim, 22, 70, 100, 0, Glyph.pack([Glyph.DUMMY_U, Glyph.SPREAD_C])),
		"[더미(상), 확산]을 실은 탄이 나간다")
	var origin: int = sim.get_id()[0]
	for _i in 12:
		sim.step(g)
		if not _has_id(sim, origin):
			break
	var alive := sim.active_count()
	t.ok(alive > 0, "확산 자식이 살아 있다 (%d발)" % alive)
	var powv := sim.get_power()
	var all_base := true
	for i in alive:
		if powv[i] != Tuning.POWER_BASE:
			all_base = false
	t.ok(all_base, "자식 위력이 100이지 200이 아니다 (부모의 위력을 안 물려받는다)")


## **`[BLAST_R, BLAST_R]` gives 120 and 120, not 144.** TERMINAL continues at the same spot (`kind` says so),
##  so the second blast must read the **same** carried `power` the first one did — `blast_power` in
##  `_run_glyph` has to be a local, never written back into `power`, or the second blast in a chain would
##  compound onto the first's already-boosted result. **Already correct** — pinned so it stays that way.
func _blast_power_does_not_leak_between_layers(t) -> void:
	var g := _wall_grid()
	var sim := SpellSim.new()
	var two: Array[int] = [Glyph.BLAST_R, Glyph.BLAST_R]
	t.ok(_fire(sim, 10, 70, 100, 0, Glyph.pack(two)), "[폭발(레어), 폭발(레어)]을 실은 탄이 나간다")

	var want := Tuning.POWER_BASE * Glyph.power_pct_of(Glyph.BLAST_R) / 100
	var bp := PackedInt32Array()
	for _i in 12:
		sim.step(g)
		if sim.blast_count() > 0 and bp.is_empty():
			bp = sim.get_blast_power().duplicate()
	t.eq(bp.size(), 2, "TERMINAL이 같은 자리에서 두 번 이어 터진다 (검사의 전제)")
	if bp.size() == 2:
		t.eq(bp[0], want, "첫 폭발 위력이 %d다 (144가 아니다)" % want)
		t.eq(bp[1], want, "둘째 폭발도 **똑같이** %d다 — `blast_power`가 `power`에 다시 안 쓰인다" % want)


## Fires `packed` from a fixed origin into `grid` and returns the **first** blast's power percent, or -1 if
##  none went off within the window. Shared by the TERMINAL-compounding checks above so their own bodies stay
##  about the comparison, not the plumbing.
func _first_blast_power(grid: CellGrid, packed: int) -> int:
	var sim := SpellSim.new()
	if not _fire(sim, 10, 70, 100, 0, packed):
		return -1
	for _i in 12:
		sim.step(grid)
		if sim.blast_count() > 0:
			return sim.get_blast_power()[0]
	return -1


## **A deferred blast keeps the power it was carrying when it was pushed to the next tick.**
##  Inversion: forget `_pend_pow` (thread `Tuning.POWER_BASE` into the deferred `_resume` call instead of
##  `_pend_pow[k]`) and this goes red — visible only when the budget actually bites, which is why
##  `_blast_budget` above (unboosted) cannot catch it on its own.
## **The premise was false the first time — rebuilt.** Firing plain blasts then the boosted one does not
##  make the boosted one the one deferred: `_remove` is swap-remove, so the moment slot 0 is vacated, the
##  *last-fired* bolt is pulled into it and processed **early**, not late. Verified by mutation (dropping
##  `_pend_pow` entirely and even killing deferral outright both passed the old version green) and by hand
##  trace: with `MAX_BLASTS_PER_TICK + 1` bolts fired in slots `[0..n]`, `_remove`'s repeated swap visits them
##  in the order `B0, Bn, B(n-1), …, B2, B1` — the bolt fired **second** is the one the chain visits last, so
##  it is the one that actually exceeds the budget. Position the boosted bolt there instead of last.
func _deferred_blast_keeps_its_power(t) -> void:
	var g := _wall_grid()
	var sim := SpellSim.new()
	var gap := Tuning.blast_rd(0) + 4
	var plain_packed := Glyph.pack([Glyph.BLAST_C])
	var boosted_packed := Glyph.pack([Glyph.DUMMY_U, Glyph.BLAST_C])
	var want := Tuning.POWER_BASE * Glyph.power_pct_of(Glyph.DUMMY_U) / 100 \
		* Glyph.power_pct_of(Glyph.BLAST_C) / 100
	t.ok(want != Tuning.POWER_BASE, "위력이 오른 폭발이 기본값과 실제로 다르다 (%d ≠ %d — 검사의 전제)" % [
		want, Tuning.POWER_BASE])

	var n := Tuning.MAX_BLASTS_PER_TICK
	t.ok(_fire(sim, 10, 8, 100, 0, plain_packed), "평범한 폭발 1발째")
	t.ok(_fire(sim, 10, 8 + gap, 100, 0, boosted_packed), "위력이 오른 폭발을 **두 번째로** 쏜다 (밀릴 자리)")
	for k in range(2, n + 1):
		t.ok(_fire(sim, 10, 8 + k * gap, 100, 0, plain_packed), "예산을 채울 평범한 폭발 %d발째" % k)

	# **The wall is not one tick away** — origin x=10, wall x=40, and drag shaves the first tick's leap short of
	#  it (measured: it takes 2 ticks, not 1). Hardcoding "step once, read tick1" assumed the wrong tick and
	#  the check's own premises failed instead of its assertions — caught here by looping and catching the
	#  **first** non-empty tick, the same idiom `_blast_chain`/`_blast_budget` already use for this wall.
	var first: Array[int] = []
	var second: Array[int] = []
	var found_first := false
	for _i in 12:
		sim.step(g)
		if sim.blast_count() == 0:
			continue
		if not found_first:
			for p in sim.get_blast_power():
				first.append(p)
			found_first = true
			continue
		for p in sim.get_blast_power():
			second.append(p)
		break
	t.ok(found_first, "탄들이 벽에 닿아 폭발이 시작됐다 (검사의 전제)")
	t.eq(first.size(), n, "폭발이 시작된 틱에 예산만큼(%d발) 터진다" % n)
	var first_all_base := true
	for p in first:
		if p != Tuning.POWER_BASE:
			first_all_base = false
	t.ok(first_all_base, "그 틱에 터진 넷은 전부 기본 위력이다 (위력 오른 것은 아직 안 터졌다)")
	t.eq(second.size(), 1, "다음 틱에 밀렸던 한 발이 터진다")
	if second.size() == 1:
		t.eq(second[0], want, "밀렸다가 재개된 폭발이 위력 %d를 그대로 든다 (100으로 떨어지지 않는다)" % want)


## **Spread's own `power_pct` was a false knob.** Replacing `Glyph.power_pct_of(id)` with `Tuning.POWER_BASE`
##  in `_run_glyph`'s SPAWN branch passed the whole suite green — the only existing coverage
##  (`_spawn_does_not_compound_carried_power`) fires `SPREAD_C`, whose `power_pct` (100) is identical to
##  `POWER_BASE`, so that check is right for the wrong reason. `SPREAD_R`/`SPREAD_U` are the only values that
##  can tell "reads its own column" apart from "always 100".
func _spread_power_pct_reaches_the_children(t) -> void:
	for id: int in [Glyph.SPREAD_R, Glyph.SPREAD_U]:
		var want := Glyph.power_pct_of(id)
		t.ok(want != Tuning.POWER_BASE, "문양 %d의 power_pct(%d)가 기본값과 실제로 다르다 (검사의 전제)" % [id, want])

		var g := _cave_grid()
		var sim := SpellSim.new()
		t.ok(_fire(sim, 22, 70, 100, 0, Glyph.pack([id])), "확산(문양 %d)만 실은 탄이 나간다" % id)
		var origin: int = sim.get_id()[0]
		for _i in 12:
			sim.step(g)
			if not _has_id(sim, origin):
				break
		var alive := sim.active_count()
		t.ok(alive > 0, "확산 자식이 살아 있다 (%d발)" % alive)
		var powv := sim.get_power()
		var all_match := true
		for i in alive:
			if powv[i] != want:
				all_match = false
		t.ok(all_match, "자식 위력이 이 확산 고유의 power_pct(%d)를 따른다 (기본값 %d로 뭉개지지 않는다)" % [
			want, Tuning.POWER_BASE])


## **The new notice arrays have to clear in `_clear_notices`, the same one place as the rest.**
##  Dropping `_seg_pow.clear()` or `_fx_pow.clear()` passed the whole suite green — `seg_count()`/`blast_count()`
##  read `_seg_x0.size()`/`_fx_x.size()`, which reset every tick regardless, so a check that only reads those
##  counts cannot see a power array quietly growing unbounded beside them. Consequence if it drifts: the
##  *next* notice's `get_*_power()[i]` reads a value appended ticks ago, not this notice's own power —
##  silent wrong damage, invisible today only because the powers used in these checks don't happen to collide.
## **What actually catches the mutation**: comparing the power array's length against the count every tick.
##  If `.clear()` is dropped, the power array keeps growing while the count resets to 0 each quiet tick, and
##  the two diverge starting the very next tick — no need to read the stale value itself.
func _notice_power_arrays_clear_with_the_rest(t) -> void:
	var g := _wall_grid()
	var sim := SpellSim.new()
	t.ok(_fire(sim, 10, 70, 100, 0, Glyph.pack([Glyph.BLAST_C])), "폭발 하나를 쏜다")
	var fired := false
	for _i in 12:
		sim.step(g)
		t.eq(sim.get_blast_power().size(), sim.blast_count(), "위력 배열 길이가 매 틱 통지 수와 같다")
		if sim.blast_count() > 0:
			fired = true
	t.ok(fired, "폭발이 실제로 났다 (검사의 전제)")
	# Several more quiet ticks — nothing fires, so the length has to keep tracking 0, not accumulate.
	for _i in 6:
		sim.step(g)
		t.eq(sim.get_blast_power().size(), 0, "조용한 틱에는 위력 배열 길이가 0이다 (밀리지 않고 자란 값이 없다)")

	# The same property for the segment notice — a bolt that keeps flying (never impacts) within the window.
	var g2 := CellGrid.new()
	var sim2 := SpellSim.new()
	t.ok(_fire(sim2, 100, 70, 1, -2, Glyph.GLYPH_NONE), "허공으로 탄을 쏜다")
	for _i in 8:
		sim2.step(g2)
		t.eq(sim2.get_seg_power().size(), sim2.seg_count(),
			"날아가는 매 틱마다 구간 위력 배열 길이가 구간 수와 같다")


## **"Unreachable with today's table" is not the same claim as "tested".** Bypasses `fire()`'s gate — no
##  combination of today's 9 rows can compose past `POWER_MAX` — and drives `_launch` directly with a seed
##  already past the ceiling.
func _power_clamp_actually_fires(t) -> void:
	var sim := SpellSim.new()
	var origin_fp := (100 << SpellSim.FP_SHIFT) + SpellSim.FP_HALF
	t.expect_error("composed power")
	t.ok(sim._launch(origin_fp, origin_fp, 1, 0, Glyph.GLYPH_NONE, Tuning.ELEM_FIRE, 0, Tuning.POWER_MAX + 500000),
		"상한을 넘는 위력으로 직접 발사해도 탄은 여전히 난다 (짖고 죽이지 않는다)")
	t.eq(sim.get_power()[0], Tuning.POWER_MAX, "위력이 상한(%d)으로 눌린다" % Tuning.POWER_MAX)

	# Negative control — a normal composition well under the ceiling is not touched.
	var sim2 := SpellSim.new()
	t.ok(_fire(sim2, 100, 70, 1, 0, Glyph.pack([Glyph.DUMMY_U, Glyph.DUMMY_R])), "평범한 합성은 짖지 않는다 (전제)")
	t.ok(sim2.get_power()[0] < Tuning.POWER_MAX, "그 값이 상한보다 한참 작다 (%d) — 안 눌렸다" % sim2.get_power()[0])


## **Real Stage-A regression, fixed** (`glyph_defs.count_family`'s own comment has the trace). The cap check
##  for an early, valid id used to walk the **whole** list and dereference every id's `DEFS` entry, including
##  ones the outer loop had not validated yet — an unknown id positioned *after* a capped one crashed the
##  command boundary instead of being barked and dropped.
## **`expect_error` alone cannot separate "rejected cleanly" from "crashed underneath" — it is only an
##  amnesty for the wrapper, not an assertion** (this file's own `_null_world_refuses`-style device is the
##  fix, borrowed from `net_damage`: measure the bark's trace as a value, not its absence from the log).
## **Measured, not assumed**: with the guard removed, `fire()` still returns `false` and `active_count()`
##  still reads 0 — those two assertions alone stayed green under the mutation (312 passed, 0 failed) and only
##  the wrapper's blanket stderr rule caught it. What actually differs is `count_family`'s own return value —
##  the crashed `family_of(15)` call silently coerces into matching `FAMILY_SPREAD`, so the guardless version
##  counts **2**, not 1, for this exact list. That is the value this check pins.
func _unknown_id_after_a_capped_glyph_barks_not_crashes(t) -> void:
	var sim := SpellSim.new()
	t.ok(not Glyph.DEFS.has(Glyph.MASK), "MASK 자체는 정의되지 않은 id다 (검사의 전제)")
	var list: Array[int] = [Glyph.SPREAD_C, Glyph.MASK]
	var packed := Glyph.pack(list)
	t.eq(Glyph.count_family(packed, Glyph.FAMILY_SPREAD), 1,
		"모르는 id를 건너뛰고 정확히 1로 센다 (죽으면서 우연히 맞는 값이 나오는 게 아니다)")

	t.expect_error("unknown glyph id")
	t.ok(not _fire(sim, 100, 70, 1, 0, packed),
		"한도 있는 문양 뒤에 모르는 id가 와도 짖고 버릴 뿐, 죽지 않는다")
	t.eq(sim.active_count(), 0, "버린 발사가 탄을 안 남긴다")


# ══════════════════════════════════════════════════════════════════
#  burn-out-of-the-bull-room.md §0 — the runeless-blast fix
# ══════════════════════════════════════════════════════════════════

## **Driven through `SpellSim`, not through `CellGrid.ignite()`/`cmd_blast()` directly** — this is the check
## that proves `_run_glyph`'s TERMINAL branch actually derives `src` from the fired rune's own element, not
## only that the grid-level rule (`net_fire`'s own check) works in isolation. A none-element blast must leave
## a `rune_only` wall standing; a fire-element blast must ignite it.
func _blast_ignites_wood_only_from_the_fire_rune(t) -> void:
	var one: Array[int] = [Glyph.GLYPH_BLAST]
	var packed := Glyph.pack(one)

	var g_none := _wood_wall_grid()
	var sim_none := SpellSim.new()
	t.ok(sim_none.fire(SpellSim.cmd_fire(10, 70, 100, 0, Tuning.ELEM_NONE, packed)),
		"무속성 룬으로 폭발 문양을 쏜다")
	var fired_none := false
	for _i in 12:
		sim_none.step(g_none)
		if sim_none.blast_count() > 0:
			fired_none = true
	t.ok(fired_none, "폭발이 실제로 났다 (검사의 전제)")
	t.eq(g_none.burning_count(), 0, "무속성 폭발은 문(나무)에 불을 못 붙인다 (룬이 없다)")
	t.ok(g_none.count_material(Mat.WOOD) > 0, "나무는 그대로 서 있다 (부서지지도 않는다 — indestructible)")

	var g_fire := _wood_wall_grid()
	var sim_fire := SpellSim.new()
	t.ok(sim_fire.fire(SpellSim.cmd_fire(10, 70, 100, 0, Tuning.ELEM_FIRE, packed)),
		"불 룬으로 같은 폭발 문양을 쏜다")
	var fired_fire := false
	for _i in 12:
		sim_fire.step(g_fire)
		if sim_fire.blast_count() > 0:
			fired_fire = true
	t.ok(fired_fire, "폭발이 실제로 났다 (검사의 전제)")
	t.ok(g_fire.burning_count() > 0, "불 룬의 폭발은 문에 불을 붙인다")


# ══════════════════════════════════════════════════════════════════
#  glyph-condense §11.6 Step 2 — the pillar
# ══════════════════════════════════════════════════════════════════

## **A pillar notice exists where the bolt landed. Literal `w`/`h`** — never read back from `Tuning.pillar_w/
##  pillar_h`, or the check would only ever prove the table agrees with itself (`glyph-condense.md` §9's own
##  warning, "pin literal coordinates").
## Fired into `_wall_grid()` from the side (`WALL_X0` is 40) — the impact cell is one column short of it, and
##  that column is otherwise empty all the way up, so nothing but the table's own ceiling limits the climb.
func _condense_notice_is_literal(t) -> void:
	var g := _wall_grid()
	var sim := SpellSim.new()
	# **Fired from 5 cells out, not 30** — close enough that the wall is reached inside one tick, so gravity
	#  gets only one tick's worth of pull before impact and the row does not drift off the fired one.
	t.ok(_fire(sim, WALL_X0 - 5, 70, 100, 0, Glyph.pack([Glyph.CONDENSE_C])), "응축 문양을 실은 탄이 나간다")
	var seen := false
	for _i in 12:
		sim.step(g)
		if sim.pillar_count() > 0:
			seen = true
			t.eq(sim.pillar_count(), 1, "기둥이 한 번 통지된다")
			t.eq(sim.get_pillar_x()[0], WALL_X0 - 1, "기둥이 착탄 칸(벽 바로 앞, %d)에서 선다" % (WALL_X0 - 1))
			t.eq(sim.get_pillar_y()[0], 70, "기둥의 발판이 착탄 행(70)이다")
			t.eq(sim.get_pillar_w()[0], 8, "너비가 8칸이다")
			t.eq(sim.get_pillar_h()[0], 16, "위가 트여 있으면 높이가 16칸까지 닿는다")
			break
	t.ok(seen, "기둥이 실제로 섰다")


## **It goes up, not down or sideways, and it stops at the first solid cell above.** A ceiling 5 cells above
##  the impact row (in the *same* column the pillar climbs) caps the height at exactly 5 — not 16.
## A solid cell placed **below** the impact row (the opposite direction) is left untouched by this check on
##  purpose: if the climb ever went the wrong way, it would hit *that* cell first and read `h == 1`, so this
##  one scenario catches both "the sign was flipped" and "the `BEHAVIOR_STATIC` test was deleted".
func _condense_climbs_up_and_stops_at_the_first_solid(t) -> void:
	var g := _wall_grid()
	var impact_x := WALL_X0 - 1
	var impact_y := 70
	g.apply(CellGrid.cmd_fill(impact_x, impact_y - 5, impact_x, impact_y - 5, Mat.STONE))
	g.apply(CellGrid.cmd_fill(impact_x, impact_y + 1, impact_x, impact_y + 1, Mat.STONE))
	var sim := SpellSim.new()
	# **Fired from 5 cells out** — the same reason `_condense_notice_is_literal` above fires close: gravity
	#  gets only one tick to pull before impact, so the bolt lands on `impact_y`, the exact row the ceiling
	#  and the floor cell above were placed against.
	t.ok(_fire(sim, WALL_X0 - 5, impact_y, 100, 0, Glyph.pack([Glyph.CONDENSE_C])), "응축 탄이 나간다")
	var seen := false
	for _i in 12:
		sim.step(g)
		if sim.pillar_count() > 0:
			seen = true
			t.eq(sim.get_pillar_y()[0], impact_y, "발판 행이 착탄 행이다 (검사의 전제)")
			t.eq(sim.get_pillar_h()[0], 5, "5칸 위 천장에서 멈춘다 (표 상한 16까지 안 간다)")
			break
	t.ok(seen, "기둥이 실제로 섰다 (검사의 전제)")


## **"응축은 물질을 남기지 않는다" is a statement about the column, not the impact** (`glyph-condense.md`
##  §2.4). Compares the grid after `[응축]` against a bare impact with the same rune, **and** asserts the
##  pillar notice actually fired — grid equality alone is *"A/B catches diverged, never vanished"* (CLAUDE.md);
##  the notice assertion is the half that catches "the glyph silently did nothing at all".
func _condense_leaves_no_material(t) -> void:
	var g_bare := _wall_grid()
	var s_bare := SpellSim.new()
	t.ok(s_bare.fire(SpellSim.cmd_fire(10, 70, 100, 0, Tuning.ELEM_NONE, Glyph.GLYPH_NONE)),
		"문양 없이 쏜다 (대조군)")
	for _i in 12:
		s_bare.step(g_bare)

	var g_cond := _wall_grid()
	var s_cond := SpellSim.new()
	t.ok(s_cond.fire(SpellSim.cmd_fire(10, 70, 100, 0, Tuning.ELEM_NONE, Glyph.pack([Glyph.CONDENSE_C]))),
		"응축을 쏜다")
	var fired := false
	for _i in 12:
		s_cond.step(g_cond)
		if s_cond.pillar_count() > 0:
			fired = true
	t.ok(fired, "기둥 통지가 실제로 났다 (A/B만으론 못 잡는 절반)")

	var same := true
	for cx in range(0, 60):
		for cy in range(40, 100):
			if g_bare.mat_at(cx, cy) != g_cond.mat_at(cx, cy):
				same = false
	t.ok(same, "응축이 서 있어도 격자가 착탄 단독과 바이트 단위로 같다 (물질을 안 남긴다)")


## **TERMINAL means "the next glyph continues at the same spot"** — `[응축, 폭발]`과 `[폭발, 응축]` 둘 다
##  두 문양이 실제로 실행됐는지를 잰다 (기둥과 폭발 각각 정확히 1회).
##
## **The grid is not compared here, and that is not an oversight.** Condense writes no cell in either order
##  (§11.1 — it neither cuts nor ignites), so the *terrain* is identical whichever order the two run in; only
##  the blast's own hole differs from a bare blast, and that is already `_blast_glyph`'s check. What order
##  actually changes here is the **picture** (`glyph-condense.md` §3's own worked table: the pillar rises
##  before or after the hole exists) — a screen fact, not a grid fact, and outside what this net can measure.
func _condense_and_blast_both_run_in_either_order(t) -> void:
	var g_a := _wall_grid()
	var sim_a := SpellSim.new()
	t.ok(_fire(sim_a, 10, 70, 100, 0, Glyph.pack([Glyph.CONDENSE_C, Glyph.GLYPH_BLAST])),
		"[응축, 폭발]을 쏜다")
	var a_pillars := 0
	var a_blasts := 0
	for _i in 12:
		sim_a.step(g_a)
		a_pillars += sim_a.pillar_count()
		a_blasts += sim_a.blast_count()
	t.eq(a_pillars, 1, "[응축, 폭발]에서 기둥이 한 번 선다")
	t.eq(a_blasts, 1, "[응축, 폭발]에서 폭발도 한 번 난다")

	var g_b := _wall_grid()
	var sim_b := SpellSim.new()
	t.ok(_fire(sim_b, 10, 70, 100, 0, Glyph.pack([Glyph.GLYPH_BLAST, Glyph.CONDENSE_C])),
		"[폭발, 응축]을 쏜다")
	var b_pillars := 0
	var b_blasts := 0
	for _i in 12:
		sim_b.step(g_b)
		b_pillars += sim_b.pillar_count()
		b_blasts += sim_b.blast_count()
	t.eq(b_pillars, 1, "[폭발, 응축]에서도 기둥이 한 번 선다")
	t.eq(b_blasts, 1, "[폭발, 응축]에서도 폭발이 한 번 난다")


## **`[확산, 응축]`이 착탄점마다 기둥을 하나씩, 정확히 8개 세운다.** *"a loop whose condition is false from
##  the start never runs the check at all"* — count, not `> 0`.
## **Height is not asserted per child here.** Eight children scatter in eight directions and some fly steeply
##  upward before falling back — measured, one of them rose far enough that even a 65-cell-tall test room
##  could not give it 8 clear cells above its own landing point without the room becoming implausibly large.
##  "Does a gen-1 pillar actually read the gen-1 table row" is exactly `_condense_height_follows_gen` below,
##  fired once, in a straight line, with no ballistic arc to fight.
func _spread_condense_raises_eight_pillars(t) -> void:
	var g := _cave_grid()
	var sim := SpellSim.new()
	t.ok(_fire(sim, 22, 70, 100, 0, Glyph.pack([Glyph.GLYPH_SPREAD, Glyph.CONDENSE_C])),
		"[확산, 응축]을 쏜다")
	var total := 0
	for _i in 90:
		sim.step(g)
		total += sim.pillar_count()
	t.eq(total, Tuning.SPREAD_COUNT, "확산 → 응축이 기둥을 정확히 %d개 세운다" % Tuning.SPREAD_COUNT)


## **A gen-1 pillar reads the gen-1 table row (`SIM_SIZES[1].pillar_h` = 8), fired directly at that
##  generation rather than through spread's own ballistics** — the companion to the test above, which proves
##  the count but cannot pin the height without fighting an 8-way scatter's real trajectories.
func _condense_height_follows_gen(t) -> void:
	var g := _wall_grid()
	var sim := SpellSim.new()
	var ox_fp := ((WALL_X0 - 5) << SpellSim.FP_SHIFT) + SpellSim.FP_HALF
	var oy_fp := (70 << SpellSim.FP_SHIFT) + SpellSim.FP_HALF
	t.ok(sim._launch(ox_fp, oy_fp, 100, 0, Glyph.pack([Glyph.CONDENSE_C]), Tuning.ELEM_NONE, 1, Tuning.POWER_BASE),
		"세대 1 응축을 직접 발사한다")
	var seen := false
	for _i in 12:
		sim.step(g)
		if sim.pillar_count() > 0:
			seen = true
			t.eq(sim.get_pillar_w()[0], 4, "세대 1 너비가 표값(4)이다")
			t.eq(sim.get_pillar_h()[0], 8, "위가 트여 있으면 세대 1 높이가 표값(8)까지 닿는다")
			break
	t.ok(seen, "기둥이 실제로 섰다")


## **`[CONDENSE_R, CONDENSE_R]`이 120과 120을 준다 — 144가 아니다.** TERMINAL이 같은 자리에서 이어 실행되므로
##  둘째 기둥도 **같은** 실려 온 위력을 읽어야 한다 — `_blast_power_does_not_leak_between_layers`가 폭발에
##  대해 이미 고정한 것과 같은 모양.
##
## **`sim._launch(...)` directly, not `fire()`.** Condense's `max_per_circle` is 1 (`glyph_defs.gd`'s own
##  false-knob argument — two pillars at one cell are one pillar), so `fire()` itself would reject two
##  condense layers before this ever ran (`_family_cap_blocks_mixed_rarity`'s own note: only `fire()`
##  enforces the cap, not `_launch`/`_resume`). The pipeline contract under test here — a local, never
##  written back into `power` — has to hold regardless of whether the real UI can ever assemble this list.
func _condense_power_does_not_leak_between_layers(t) -> void:
	var g := _wall_grid()
	var sim := SpellSim.new()
	var packed := Glyph.pack([Glyph.CONDENSE_R, Glyph.CONDENSE_R])
	var ox_fp := (10 << SpellSim.FP_SHIFT) + SpellSim.FP_HALF
	var oy_fp := (70 << SpellSim.FP_SHIFT) + SpellSim.FP_HALF
	t.ok(sim._launch(ox_fp, oy_fp, 100, 0, packed, Tuning.ELEM_NONE, 0, Tuning.POWER_BASE),
		"[응축(레어), 응축(레어)]를 직접 발사한다 (fire()의 한도를 건너뛴다)")
	var want := Tuning.POWER_BASE * Glyph.power_pct_of(Glyph.CONDENSE_R) / 100
	var pp := PackedInt32Array()
	for _i in 12:
		sim.step(g)
		if sim.pillar_count() > 0 and pp.is_empty():
			pp = sim.get_pillar_power().duplicate()
	t.eq(pp.size(), 2, "TERMINAL이 같은 자리에서 두 번 이어 실행된다 (검사의 전제)")
	if pp.size() == 2:
		t.eq(pp[0], want, "첫 기둥 위력이 %d다 (144가 아니다)" % want)
		t.eq(pp[1], want, "둘째 기둥도 똑같이 %d다 — power에 다시 안 쓰인다" % want)


## **The wrapper's stderr check catches "a rune with no implementation" for free** — condense is rune-blind
##  (`glyph-condense.md` §2.3's ⚠ box), so every rune in `ELEM_ALL` must fire it with no `push_error`.
func _condense_runs_for_every_rune(t) -> void:
	for elem: int in Tuning.ELEM_ALL:
		var g := _wall_grid()
		var sim := SpellSim.new()
		t.ok(sim.fire(SpellSim.cmd_fire(10, 70, 100, 0, elem, Glyph.pack([Glyph.CONDENSE_C]))),
			"룬 %d로 응축을 쏜다" % elem)
		var seen := false
		for _i in 12:
			sim.step(g)
			if sim.pillar_count() > 0:
				seen = true
		t.ok(seen, "룬 %d에서도 기둥이 선다 (짖지 않는다)" % elem)


## **`tick_budget: 0` — the positive form of §6.3's overturned budget.** A pillar writes no cell, so there is
##  nothing to cap; eight of them landing on one tick must all fire on that tick, not defer.
##
## **Real regression, found by verify-run**: reading `pending_count()` only after the whole 12-tick loop
## caught nothing — set `CONDENSE_C`'s `tick_budget` to 1 and the whole suite stayed green, because a budget
## of 1 spreads the eight across eight ticks and by tick 12 every one of them has already drained. What a
## real budget actually does is defer **within the landing tick itself** (`_resume`'s own per-glyph counter),
## so `pending_count()` has to be read **every tick**, not once at the end.
func _condense_never_defers(t) -> void:
	var g := _wall_grid()
	var sim := SpellSim.new()
	var packed := Glyph.pack([Glyph.CONDENSE_C])
	var n := 8
	var gap := 4
	var fired := 0
	for k in n:
		if _fire(sim, 10, 8 + k * gap, 100, 0, packed):
			fired += 1
	t.eq(fired, n, "%d발이 같은 틱에 착탄하도록 같이 난다" % n)
	var total := 0
	var landing_tick_count := 0
	var max_pending := 0
	for _i in 12:
		sim.step(g)
		if sim.pillar_count() > 0:
			landing_tick_count = sim.pillar_count()
		total += sim.pillar_count()
		max_pending = maxi(max_pending, sim.pending_count())
	t.eq(total, n, "%d개 기둥이 전부 선다 (하나도 안 밀린다)" % n)
	t.eq(landing_tick_count, n, "%d개가 착탄한 그 틱에 전부 같이 선다 (일부만 서고 나머지가 다음 틱으로 밀리지 않는다)" % n)
	t.eq(max_pending, 0, "예산이 0(무제한)이라 어느 틱에도 밀린 적이 없다 (틱마다 잰다 — 끝나고 한 번만 재면 못 잡는다)")


# ══════════════════════════════════════════════════════════════════
#  Tools
# ══════════════════════════════════════════════════════════════════

func _fire(sim: SpellSim, ox: int, oy: int, adx: int, ady: int,
		glyphs: int = Glyph.GLYPH_NONE) -> bool:
	return sim.fire(SpellSim.cmd_fire(ox, oy, adx, ady, Tuning.ELEM_FIRE, glyphs))


func _unpack(g: int) -> Array[int]:
	var out: Array[int] = []
	var cur := g
	while cur != Glyph.GLYPH_NONE:
		out.append(Glyph.first(cur))
		cur = Glyph.rest(cur)
	return out


func _has_id(sim: SpellSim, id: int) -> bool:
	var ids := sim.get_id()
	for i in sim.active_count():
		if ids[i] == id:
			return true
	return false


## Fires `n` bolts carrying the blast glyph side by side **so they land on the same tick.** Returns how many actually launched.
##
## **The row spacing has to be wider than the blast radius.** Bursting them at the same spot lets the first blast erase
##  the wall so the rest **just fly through that hole** — the budget check passes green while in reality only one bolt
##  detonated (it was written that way at first and got caught). Spacing 16 cells > radius 12 cells, so they do not erase each other.
func _volley(sim: SpellSim, n: int) -> int:
	var one: Array[int] = [Glyph.GLYPH_BLAST]
	var packed := Glyph.pack(one)
	var gap := Tuning.blast_rd(0) + 4
	var fired := 0
	for k in n:
		if _fire(sim, 10, 8 + k * gap, 100, 0, packed):
			fired += 1
	return fired


## Runs `ticks` ticks and returns the **total blast count** over that span.
## Notices are cleared every tick, so they have to be collected each tick.
func _run_ticks(sim: SpellSim, grid: CellGrid, ticks: int) -> int:
	var n := 0
	for _i in ticks:
		sim.step(grid)
		n += sim.blast_count()
	return n


## A 4-cell-thick stone wall. Bolts land here.
func _wall_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(WALL_X0, 0, WALL_X1, CellGrid.H - 1, Mat.STONE))
	return g


## **The wood-side twin of `_wall_grid()`** — full-height, so the exact row the bolt happens to drift to
## (gravity) does not matter; the whole column is `WOOD` either way.
func _wood_wall_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(WALL_X0, 0, WALL_X1, CellGrid.H - 1, Mat.WOOD))
	return g


## Is there **any row fully pierced** through the wall? A different question from "the stone shrank" —
##  shrinking without piercing is the other side of the state the user reported.
func _wall_pierced(g: CellGrid) -> bool:
	for y in range(CellGrid.H):
		var open := true
		for x in range(WALL_X0, WALL_X1 + 1):
			if g.mat_at(x, y) != Mat.EMPTY:
				open = false
				break
		if open:
			return true
	return false


## Solid stone. The place where the cells a blast erased are counted.
## The `SOLID_EXTENT` box above — it fills one side length, not the whole grid.
## **`mat_at()`'s "outside the grid = STONE" auto-clamp only turns on at the real grid bounds (4096, 1008) —
##  outside `SOLID_EXTENT` (200) is still **inside the grid**, so it is not auto-filled and is simply empty (EMPTY).**
##  The real reason this is safe is only **that every coordinate this file uses (cave 20-85, direct checks cx=100, rd=8)
##  fits inside 200 with room to spare** — the day coordinates widen past 200, widen this value with them.
func _solid_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, SOLID_EXTENT - 1, SOLID_EXTENT - 1, Mat.STONE))
	return g


## **A room dug into stone.** All 8 spread bolts **hit something** — the same reason the design doc's "stage" chose a box.
##
## It must not be measured on a thin floor. A generation 1 blast (rd 6) punches through the floor and the rest leak
##  outside the grid, so "8 blasts" silently becomes 3. **Thick stone on every side** means that even as the crater widens, outside it is still stone.
##  (It was first written with a single-wall stage and got caught exactly that way — blasts came out as 1.)
func _cave_grid() -> CellGrid:
	var g := _solid_grid()
	g.apply(CellGrid.cmd_fill(CAVE_X0, CAVE_Y0, CAVE_X1, CAVE_Y1, Mat.EMPTY))
	return g


## The same room dug into **wood.** A rune trace needs fuel to be visible, so a stone cave cannot measure it.
## Fills only `SOLID_EXTENT` for the same reason as `_solid_grid()`.
func _wood_cave_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, SOLID_EXTENT - 1, SOLID_EXTENT - 1, Mat.WOOD))
	g.apply(CellGrid.cmd_fill(CAVE_X0, CAVE_Y0, CAVE_X1, CAVE_Y1, Mat.EMPTY))
	return g


## Runs until the original bolt lands (or until `ticks`).
func _run_until_impact(sim: SpellSim, grid: CellGrid, ticks: int) -> void:
	if sim.active_count() == 0:
		return
	var origin: int = sim.get_id()[0]
	for _i in ticks:
		sim.step(grid)
		if not _has_id(sim, origin):
			return


## A box. The same shape as the stage — a bolt fired upward does not vanish into the void.
func _box_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, CellGrid.W - 1, 3, Mat.STONE))
	g.apply(CellGrid.cmd_fill(0, CellGrid.H - 4, CellGrid.W - 1, CellGrid.H - 1, Mat.STONE))
	g.apply(CellGrid.cmd_fill(0, 0, 3, CellGrid.H - 1, Mat.STONE))
	g.apply(CellGrid.cmd_fill(CellGrid.W - 4, 0, CellGrid.W - 1, CellGrid.H - 1, Mat.STONE))
	return g
