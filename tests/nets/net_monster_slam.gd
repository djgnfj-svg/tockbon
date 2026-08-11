extends RefCounted
## Monster boss stages G/H -- the bull's jump slam (reuses D's fire, F's leap) and phase 2 ("it speeds up at
##  half health"). Split out of net_monster.gd, same round and same reason as net_monster_charge.gd (its header
##  carries the full measured rationale -- not repeated here).
##
## **Grouped by profiled time**: Stage G + Stage H summed to ~3.62s of check-body time, the heaviest of the
##  four post-split files -- carried mostly by one check, not evenly. `_bull_slam_does_not_leave_room1_on_the_
##  real_map` alone profiled at ~1.9s (it builds the real baked map via Stage.build_terrain_into and runs 600
##  real ticks) -- that cost is deliberate and already justified in its own comment, not a splitting target.
##
## **The full story lives in net_monster.gd's own header comment.**

const NetDeterminism := preload("res://tests/nets/net_determinism.gd")

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Character := preload("res://src/actor/character.gd")
const SpellSim := preload("res://src/sim/spell_sim.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const Body := preload("res://src/actor/body.gd")
const Monster := preload("res://src/actor/monster.gd")
const Defs := preload("res://src/actor/monster_defs.gd")
const WorldStep := preload("res://src/actor/world_step.gd")
const MonsterView := preload("res://src/view/monster_view.gd")
const MonsterBolts := preload("res://src/actor/monster_bolts.gd")
const Fx := preload("res://src/view/fx_tuning.gd")
const BossAi := preload("res://src/actor/boss_ai.gd")
## Stage G fix list ② — the real map, the same static door `net_water_rain.gd`/`net_tables.gd` already use
## (`Stage.build_terrain_into`, no scene tree needed).
const Stage := preload("res://src/stage/stage.gd")

const DT := 1.0 / 60.0
const FLOOR_CY := 100
const FLOOR_TOP := FLOOR_CY * Tuning.CELL_PX
const LEDGE_CX := 30
const STAGE_SCRIPT := "res://src/stage/stage.gd"

# --- stage 3 — bolt and blast placement constants -------------------
## **`_hits_to_kill` and `HIT_LEAD_PX` lived here and were deleted — they had no caller in this file.**
##  This file is one of four copies split off `net_monster.gd` for parallel speed, and the split left the helper
##  behind on every copy while only `net_monster` kept the check that calls it
##  (`_dummy_raises_hits_to_kill_a_pig`). Proof it was dead rather than merely quiet: verify-read set this
##  file's `HIT_LEAD_PX` to 300 (a guaranteed miss) and the net stayed **green**, and a `push_error` canary on
##  the function's first line **never reached stderr**. A helper nobody calls carries a comment nobody can
##  falsify, which is how it came to claim a property no check here measured.
##  **If a check that needs it comes back, copy it from `net_monster.gd`** — that is where the live one is.

## The firing origin (in cells) to slam a blast down from — well above the floor. The same idiom as `net_damage.BLAST_FROM_CY`.
const BLAST_FROM_CY := FLOOR_CY - 20

## **The floor is laid thin** (CLAUDE.md, "if the net is slow..."). The old floor (down to `CellGrid.H-1`) was
##  4096x908 = 3,719,168 cells, 2,719ms at a time — that is why this file ate 43 seconds.
##  Why it is safe: `cell_grid.mat_at()` returns `STONE` outside the grid, so there was never any reason for it
##  to be thick. Monsters only play within a few px of the surface. 32 cells (128px) is 4x the headroom of `carve_r` (8 cells).
const FLOOR_DEPTH_CY := 32

## **The floor is also laid narrow** (harness-manager, stage1-bosses.md Stage D round, measured). The width was
##  `CellGrid.W` (4096 cells) unconditionally — every one of the ~104 grid-building calls in this file (`_floor_grid`,
##  `_bare_grid`, `_new_world`, and everything that calls them) paid for a **full-width** fill even though almost
##  every check plays within a few hundred px of `x=0`. Measured directly (`CellGrid.new()` + one fill, 20 reps,
##  averaged): full-width×32-deep = **98.75ms**; 512-wide×32-deep = **15.33ms** — width alone is most of this
##  file's cost, the same shape as the depth fix above.
## **Why 2000 cells is still safe, not just faster — bisected, not guessed** (harness-manager, temporarily
##  shrinking this same constant and re-running `run_nets.ps1 monster`, reverted after each step):
##  150 cells -> **8 failures** (`_dummy_raises_hits_to_kill_a_pig`'s stand_x=600 spawns off the fill entirely,
##  the carve-symmetry checks lose their wall). 300 cells -> **2 failures** (only the left/right carve-symmetry
##  check, whose wall sits at cell 200-240 and spawns just past it). 600 cells -> **all 426 pass, 0 failures**,
##  same as full width. So the real minimum sits in (300, 600] cells — **2000 is more than 3x that band, not a
##  guess frozen on day one** (the same trap the tick-cap section above already names). It was tempting to reason
##  this from `stand_x := 5000` (the two round-robin/direction boss checks, 1250 cells) plus the charge safety-cap
##  distance (~214 cells) and land on ~1464 — **that estimate was wrong**: both checks stayed green even at width
##  300, because neither one's assertions ever read whether the monster stayed grounded (only `m.pattern`/`m.x`,
##  which keep moving whether or not the monster is airborne) — reasoning about what a check *should* need is not
##  a substitute for the bisection above. **Positions past 600 cells** (`ch.place(5000/8000/20000, ...)`) are all
##  the "bystander" idiom — a player parked far away only so a monster's own direction-toward-the-player picks a
##  side; never read for x/y, never needs solid ground. If this narrowing is ever wrong for a future check, the
##  thing that needed the missing floor falls through it and that check goes red, loudly — not a silent pass.
const FLOOR_W_CX := 2000
# -- 6-helper. monster collision width — measured with a vertical chimney, no horizontal movement --
## **Looking only at the landing y (old check 6) leaves all 66 green even when `Monster` doesn't pass
##  `w_px` to `Body` (fixed 20px)** (verifier measured) — with no horizontal movement the width is never once engaged.
##  => **The width is engaged by falling alone**: a hen (24px) fits the 32px gap, a pig (44px) catches on top.
const HOLE_CX := 50
const HOLE_W_CELLS := 8   # 32px — wider than a hen, narrower than a pig
## It is deeper than the thin floor (`FLOOR_DEPTH_CY`, 32 cells) — **left that way on purpose.** Below the
##  chimney is outside the thin floor anyway and therefore open, so the hen keeps falling until it reaches
##  outside the grid (automatically solid). The check below measures not an exact depth but only `y > FLOOR_TOP` (did it fall further), so it doesn't matter.
const HOLE_DEPTH_CELLS := 40
## **Not part of the file's own class hierarchy** — a subclass local to this net, only to observe which leaf
## draw call ran without needing a real canvas (`_draw_attack_prediction`/`_draw_stun_ring` both draw onto
## `self` directly, so recording in an override is the whole trick — no shader, no child layer, no scene needed).
class _RecordingMonsterView extends MonsterView:
	var drawn: Array[String] = []

	## `docs/design/attack-prediction.md` replaced the "!" telegraph this override used to record as
	## `"telegraph"` — renamed with it so an old string here does not outlive the function it named.
	func _draw_attack_prediction(_m: Monster, _r: Rect2) -> void:
		drawn.append("predict")

	func _draw_stun_ring(_r: Rect2) -> void:
		drawn.append("ring")

	## Stage H — the phase-2 tell's own leaf. `_draw_phase2_tell`'s hp threshold is left un-overridden on
	## purpose (see that test's own comment) so it runs for real; only the actual `draw_rect` call is replaced.
	func _draw_phase2_ring(_r: Rect2) -> void:
		drawn.append("phase2")




func _blast_cmd(cx: int) -> Dictionary:
	var one: Array[int] = [Glyph.GLYPH_BLAST]
	return SpellSim.cmd_fire(cx, BLAST_FROM_CY, 0, 10, Tuning.ELEM_NONE, Glyph.pack(one))

func _floor_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, FLOOR_CY, FLOOR_W_CX - 1, FLOOR_CY + FLOOR_DEPTH_CY - 1, Mat.STONE))
	return g


func _wall_grid() -> CellGrid:
	var g := _floor_grid()
	var wall_cx := 30
	g.apply(CellGrid.cmd_fill(wall_cx, FLOOR_CY - 8, wall_cx + 3, FLOOR_CY - 1, Mat.STONE))
	return g


func _ledge_grid(cells: int) -> CellGrid:
	var g := _floor_grid()
	g.apply(CellGrid.cmd_fill(
		LEDGE_CX, FLOOR_CY - cells, FLOOR_W_CX - 1, FLOOR_CY + FLOOR_DEPTH_CY - 1, Mat.STONE))
	return g




func _chimney_grid() -> CellGrid:
	var g := _floor_grid()
	g.apply(CellGrid.cmd_fill(
		HOLE_CX, FLOOR_CY, HOLE_CX + HOLE_W_CELLS - 1, FLOOR_CY + HOLE_DEPTH_CELLS, Mat.EMPTY))
	return g


# -- 8. it moves only by going through frame() --------------------
func _new_world() -> WorldStep:
	var g := CellGrid.new()
	# This is laid thin too — the same reason as `_floor_grid()` (the `FLOOR_DEPTH_CY` box above).
	#  This is the spot that got missed: this function is called repeatedly by checks 6, 7, 8, 9, 10 and 11 while
	#  the old fill was still sitting here, so `net_monster` only dropped 43s -> 25s and stayed the slowest net.
	g.apply(CellGrid.cmd_fill(0, FLOOR_CY, FLOOR_W_CX - 1, FLOOR_CY + FLOOR_DEPTH_CY - 1, Mat.STONE))
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(160, FLOOR_TOP - Character.H_PX)
	return WorldStep.new(g, spell, ch)


# ==================================================================
#  stage 2 — it walks
# ==================================================================

func _bare_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, FLOOR_CY, FLOOR_W_CX - 1, FLOOR_CY + FLOOR_DEPTH_CY - 1, Mat.STONE))
	return g


## **The trap the stage 3 damage checks fell into** — from stage 2 on the monster actually walks toward the
##  player. If a damage or fire check puts the character far from the monster (e.g. x=160), the monster walks
##  that way while the acceptance is being measured and **leaves the target spot (the fire, the blast)** — it
##  showed up as "it was standing on fire and burning went false in 16 frames" (the monster had walked out
##  of the fire). => **The character is placed at the same spot as the monster's spawn centre so that axis is
##  pinned to 0** — used when walking is not what these checks care about.
func _still_ch(stand_x: int, kind: int) -> Character:
	var ch := Character.new()
	var monster_center_x := float(stand_x) + Defs.w_px(kind) * 0.5
	ch.place(roundi(monster_center_x - Character.W_PX * 0.5), FLOOR_TOP - Character.H_PX)
	return ch


## Stands three of them in a row. The three things that cannot be measured (count only / set only / position)
##  are named by the doc and all measured together — **position** in particular is the only place that catches
##  "removal during traversal" (an adjacent live one skipping that tick), which neither the count nor the id set catches.
func _three_hens_world() -> Dictionary:
	var g := _bare_grid()
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(160, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var kind := Defs.KIND_HEN
	var gap := 200
	var base_x := 500
	var y := FLOOR_TOP - Defs.h_px(kind)
	var xs: Array[int] = [base_x, base_x + gap, base_x + gap * 2]
	var ids: Array[int] = []
	for px in xs:
		ids.append(world.spawn_monster(kind, px, y))
	return {"world": world, "ids": ids, "xs": xs}


## One charge, into a wall thick enough that the far side is never involved. Returns how many previously-
## solid cells at `cy` (within `[cx0, cx1]`) turned non-stone. Shared by the left/right symmetry check and
## the no-accumulation check below, so both read the wall through the same door.
func _charge_cycle_eaten_cells(kind: int, g: CellGrid, stand_x: int, stand_y: int, player_x: int,
		cx0: int, cx1: int, cy: int, t) -> int:
	var before := _count_stone_in_row(g, cx0, cx1, cy)
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(player_x, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	var ticks := 0
	var max_ticks := 200
	while ticks < max_ticks and m.pattern != BossAi.Pattern.STUN:
		if world.frame(DT, 0.0, false, false):
			ticks += 1
	t.eq(m.pattern, BossAi.Pattern.STUN, "충전이 벽에 막혀 stun으로 갔다 (검사의 전제)")
	return before - _count_stone_in_row(g, cx0, cx1, cy)


func _count_stone_in_row(g: CellGrid, cx0: int, cx1: int, cy: int) -> int:
	var n := 0
	for cx in range(cx0, cx1 + 1):
		if g.mat_at(cx, cy) == Mat.STONE:
			n += 1
	return n


## `Color` has no `distance_to()` (measured on Godot 4 GDScript) — the RGB Euclidean distance is computed directly.
func _rgb_dist(a: Color, b: Color) -> float:
	return Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b))


## Hits twice with `gap` frames between and returns `[number count, the first number's value]`.
## **The only difference between the two runs must be `gap`** — differing terrain, position or damage makes the control void.
func _dmg_number_probe(t, gap: int) -> Array:
	var kind := Defs.KIND_PIG   # the pig — a hen dies in one hit and can't take two
	var stand_x := 600
	var y := FLOOR_TOP - Defs.h_px(kind)
	var world := WorldStep.new(_bare_grid(), SpellSim.new(), _still_ch(stand_x, kind))
	t.ok(world.spawn_monster(kind, stand_x, y) > 0, "gap=%d — 스폰됐다 (전제)" % gap)

	var view := MonsterView.new()
	view.setup(world)
	view.advance()   # snapshots the pre-hit hp

	var cx := floori((stand_x + Defs.w_px(kind) * 0.5) / float(Tuning.CELL_PX))
	var hp0: int = world.monster_at(0).hp
	_blast_and_observe(world, view, cx)
	t.ok(world.monster_at(0).hp < hp0, "gap=%d — 첫 방이 실제로 맞았다 (전제)" % gap)

	for _i in gap:
		view.advance()

	# **It waits out the invulnerability** — without waiting, the second hit is swallowed and "they merged" passes for free.
	var hp1: int = world.monster_at(0).hp
	var tries := 0
	while world.monster_at(0).hp == hp1 and tries < 20:
		_blast_and_observe(world, view, cx)
		tries += 1
	t.ok(world.monster_at(0).hp < hp1, "gap=%d — 둘째 방도 실제로 맞았다 (전제)" % gap)

	var out := [view.dmg_number_count(), view.dmg_number_amount(0)]
	view.free()   # a `Node2D`, so not RefCounted (the same reason as the checks above)
	return out


## Feeds one blast and lets the view's frames flow along with it.
## **Without flowing the view there is nobody to see the hp diff** — no number gets made at all.
func _blast_and_observe(world: WorldStep, view: MonsterView, cx: int) -> void:
	world.enqueue(_blast_cmd(cx))
	for _i in Tuning.TICK_DIVIDER:
		world.frame(DT, 0.0, false, false)
	view.advance()


## Extracts one function's body from the source (up to the next `func `).
## Not found gives an empty string — **the caller asserts that.** Passing silently makes the check
##  "disappear" the day the name changes (CLAUDE.md, "the check doesn't fail, it disappears").
## Finds **receiverless** `draw_*(` calls in the body => the names it found.
##
## "Receiverless" = the character right before is neither a `.` nor a word character. So `canvas.draw_rect`
##  passes and a bare `draw_rect` is caught. **A call to an own function like `_draw_flipped` doesn't start
##  with `draw_`, so it isn't caught at all** — the leading underscore falls under the word-character rule.
## **Comment lines are skipped** — going red because someone wrote `draw_rect` in a comment would mean nobody could write comments.
func _bare_draw_calls(body: String) -> Array:
	var out: Array = []
	for line: String in body.split("\n"):
		var code := line.strip_edges()
		if code.begins_with("#"):
			continue
		var at := code.find("draw_")
		while at >= 0:
			var before := "" if at == 0 else code[at - 1]
			var is_receiver := before == "." or before == "_" or _is_word(before)
			# Checks it is a call — a word starting with `draw_` must be followed by an opening parenthesis.
			var close := code.find("(", at)
			if not is_receiver and close > at and not code.substr(at, close - at).contains(" "):
				out.append(code.substr(at, close - at))
			at = code.find("draw_", at + 1)
	return out


func _is_word(c: String) -> bool:
	if c == "":
		return false
	var b := c.unicode_at(0)
	return (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or (b >= 48 and b <= 57)


func _func_body(src: String, name: String) -> String:
	var at := src.find("func " + name + "(")
	if at < 0:
		return ""
	var end := src.find("\nfunc ", at + 1)
	return src.substr(at, (end - at) if end > 0 else -1)


## **The same ratio, driven end to end through `Monster.on_tick`/`world.frame()`, not just the pure
## `advance()` function above.** Two fresh monsters (not one reused across phases — reusing one would let
## `move_choice`'s round-robin drift onto a different move with a different `windup_ticks` between the two
## measurements, corrupting the ratio with a second variable). Run-length carries the usual `+1` fencepost
## (the tick that *sets* the counter is itself the first tick spent in that state) — subtracted out before the
## ratio comparison, the same discipline every earlier stage's own sequence tests already hold.
func _measure_windup_run_length_at_hp(kind: int, hp: int) -> int:
	var g := _bare_grid()
	var stand_x := 5000
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(stand_x + 3000, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	world.spawn_monster(kind, stand_x, FLOOR_TOP - Defs.h_px(kind))
	var m: Monster = world.monster_at(0)
	m.hp = hp
	var run_length := 0
	var in_windup := false
	var ticks := 0
	var max_ticks := 100
	while ticks < max_ticks:
		if world.frame(DT, 0.0, false, false):
			ticks += 1
			if m.pattern == BossAi.Pattern.WINDUP:
				run_length += 1
				in_windup = true
			elif in_windup:
				break
	return run_length



func run(t) -> void:
	# -- stage1-bosses.md Stage G -- the jump slam (reuses D's fire, F's leap) --
	_slam_values_are_read(t)
	_slam_moves_at_the_slam_speed_not_walking_speed(t)
	_third_cycle_is_slam_and_it_leaps(t)
	_slam_landing_hurts_the_player(t)
	_touching_a_bull_mid_windup_before_a_slam_does_not_hurt(t)
	_rooster_leaping_onto_the_player_does_not_hurt_them(t)
	_slam_does_not_ignite_wood_at_any_ring_point(t)
	_slam_over_stone_ignites_nothing(t)
	_slam_safety_cap_timeout_ignites_nothing(t)
	_bull_slam_does_not_leave_room1_on_the_real_map(t)
	# -- stage1-bosses.md Stage H -- phases ("it speeds up at half health") --
	_phase2_values_are_read(t)
	_phase2_duration_guard_never_hits_zero(t)
	_is_phase2_boundary(t)
	_trash_mobs_never_enter_phase2(t)
	_phase2_scales_pattern_durations(t)
	_phase2_speeds_up_the_real_windup_by_the_ratio(t)
	_phase2_charge_moves_twice_as_fast(t)
	_phase2_tell_is_wired_to_the_screen(t)
	_phase2_tell_draws_for_low_hp_only(t)


# ==================================================================
#  stage1-bosses.md Stage G — the jump slam (reuses D's fire, F's leap)
# ==================================================================

## The table values, by themselves. **Learned from Stage F's own postmortem** (a table-read-only check
## cannot catch a wrong value landing in the table it re-reads) — this function exists only to prove the
## accessors are wired to `MOVE_SLAM` at all; every number that actually matters for gameplay is pinned
## independently, against fixed expectations, further down (`_slam_does_not_ignite_wood_at_any_ring_point`).
func _slam_values_are_read(t) -> void:
	t.eq(BossAi.leap_jump_vy_px(Defs.KIND_BULL), -450.0, "황소 slam 상승 속도 = -450px/s (acceptance 8 수정 후)")
	t.eq(BossAi.slam_ignite_r(Defs.KIND_BULL), 2, "황소 slam 점화 반경 = 2")
	t.eq(BossAi.slam_ignite_r(Defs.KIND_HEN), 0, "패턴 없는 종류는 slam 점화 반경 = 0")
	t.eq(BossAi.slam_ignite_r(Defs.KIND_ROOSTER), 0, "거대 수탉은 slam이 없다 (점화 반경 = 0)")
	t.eq(BossAi.slam_ignite_spread_cells(Defs.KIND_BULL), 6, "황소 slam 점화점 간격 = 6칸 (verify-look: 3칸이면 몸 밑에 숨었다)")
	t.eq(BossAi.slam_ignite_points(Defs.KIND_BULL), 5, "황소 slam 점화점 개수 = 5")


## **The behavioral half** — the same gap Stage B/F's own review left for `speed_mult`, copied for the slam.
func _slam_moves_at_the_slam_speed_not_walking_speed(t) -> void:
	var kind := Defs.KIND_BULL
	var g := _bare_grid()
	var stand_x := 5000
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(stand_x + 3000, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, FLOOR_TOP - Defs.h_px(kind))
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	# White-box straight into LEAP with move_choice=SLAM - the windup/landing timing is covered elsewhere.
	m.pattern = BossAi.Pattern.LEAP
	m.pattern_dir = 1
	m.move_choice = BossAi.MoveChoice.SLAM
	m.pattern_left = int(BossAi.MOVE_SLAM["leap_max_ticks"])

	var x0 := m.x
	world.frame(DT, 0.0, false, false)
	var moved := m.x - x0
	var walk_speed := Defs.speed_px(kind)
	var slam_speed := walk_speed * float(BossAi.MOVE_SLAM["leap_speed_mult"])
	t.eq(moved, roundi(slam_speed * DT),
		"slam 중 한 프레임 이동량이 slam 배속 값과 일치한다 (%dpx)" % moved)
	t.ok(moved > roundi(walk_speed * DT),
		"걷기 속도보다 빠르다 (걷기였다면 %dpx)" % roundi(walk_speed * DT))


## **The pattern cycle actually reaches the slam, not just the mechanics tested white-box above** — round-robin
## now cycles three moves (`MoveChoice.CHARGE` -> `FIRE` -> `SLAM`), so the slam is the *third* cycle, one more
## than Stage D's own `_second_cycle_is_fire_breath_and_it_fires_locked_bolts`. An open floor is used, same
## reasoning as that test — no wall needed, both earlier cycles end on their own safety caps or timers.
##
## **The apex is pinned to a fixed pixel window, not re-read from `MOVE_SLAM`** — the exact lesson Stage F's
## own fix list left behind (a check that re-derives its expectation from the same table a mutation would edit
## measures nothing). Continuous formula for `jump_vy_px`=-600 gives 75px (`vy²/(2·GRAVITY_PX)`); real
## measured behavior is **69px** (verify-run-b, real map). **The window is `55..75`, narrower than the
## rooster's own `25..55`** (Stage F) — the two windows must not overlap. A first version left this at
## `25..75`, wide enough that swapping in the rooster's own `jump_vy_px`(-500, apex 48px) still passed, so the
## one number Stage G actually claims ("a bigger hop than the rooster's") was unmeasured in that direction.
## **The landing bound is a fixed absolute tick count, not `leap_max_ticks / 2`** — same fix, same reason.
func _third_cycle_is_slam_and_it_leaps(t) -> void:
	var kind := Defs.KIND_BULL
	var g := _bare_grid()
	var stand_x := 5000
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(stand_x + 3000, FLOOR_TOP - Character.H_PX)  # far to the right - direction is always +1
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)

	# **Drive past the first two cycles (charge, fire) without measuring them again — already covered.**
	#  `move_choice` only updates at the `IDLE -> WINDUP` transition, one `IDLE_TICKS`-long wait *after* the
	#  cycle that closed it — so watching for "back at IDLE twice" and asserting `move_choice == SLAM` right
	#  then is premature (measured: it still reads `FIRE`, the cycle that just closed). Driving straight until
	#  `move_choice` itself becomes `SLAM` sidesteps that off-by-one entirely.
	var ticks := 0
	var max_ticks := 400
	var min_y_during_slam := stand_y
	var saw_airborne := false
	var slam_run_length := 0
	var in_slam := false
	while ticks < max_ticks and m.move_choice != BossAi.MoveChoice.SLAM:
		if world.frame(DT, 0.0, false, false):
			ticks += 1
	t.eq(m.move_choice, BossAi.MoveChoice.SLAM, "세 번째 사이클은 slam이다 (검사의 전제 - round-robin)")

	var seq: Array[int] = [m.pattern]
	var stun_run_length := 0
	var in_stun := false
	var leap_start_x := m.x
	var stun_start_x := m.x
	ticks = 0
	max_ticks = 200
	while ticks < max_ticks:
		if world.frame(DT, 0.0, false, false):
			ticks += 1
			seq.append(m.pattern)
			if m.pattern == BossAi.Pattern.LEAP:
				min_y_during_slam = mini(min_y_during_slam, m.y)
				if not m.on_ground:
					saw_airborne = true
				if not in_slam:
					leap_start_x = m.x
				slam_run_length += 1
				in_slam = true
			elif m.pattern == BossAi.Pattern.STUN:
				if not in_stun:
					stun_start_x = m.x
				stun_run_length += 1
				in_stun = true
			elif in_stun:
				break  # left STUN - the run length is complete

	t.ok(saw_airborne, "slam 도약 동안 실제로 공중에 뜬다 (검사의 전제)")
	t.ok(min_y_during_slam < stand_y, "실제로 땅보다 위로 올라간다 (y=%d, 서 있을 때 y=%d)" % [min_y_during_slam, stand_y])
	t.ok(slam_run_length >= 1, "leap 상태가 최소 1틱은 지속된다 (%d틱)" % slam_run_length)
	t.ok(slam_run_length < 30,
		"slam이 안전장치가 아니라 실제 착지로 끝난다 (%d틱, 절대 상한 30틱 - leap_max_ticks와 별개)" % slam_run_length)
	var apex_px := stand_y - min_y_during_slam
	# **30..44, not the rooster's own 25..55 — re-derived after acceptance 8's own fix, not the original
	#  55..75.** `jump_vy_px` moved from -600 to -450 (verify-run: -600 cleared room ①'s 64px left step,
	#  89 slams later the bull was 236px outside it). Measured real apex at -450 is 38px, comfortably inside
	#  30..44 with margin either side, and the window sits **below** the rooster's own 48px real apex (not
	#  overlapping 25..55's own upper half) so a constant swapped between the two moves still gets caught —
	#  a mutation swapping in the rooster's own -500 (48px) now fails on the *high* side instead of the low
	#  side, the mirror of Stage G's first version.
	# **Corrected — the apex alone no longer separates the two `LEAP` owners, and this window says so rather
	#  than pretending otherwise.** Measured after the fix: the slam's real apex is **32px on a flat floor,
	#  39px in room ①** (context-dependent — a shorter jump is more sensitive to the exact terrain under it
	#  than the old higher one was), and the rooster's own leap is 40px. This window (30..44) contains **both**
	#  real values, so a `jump_vy_px` swapped between the two moves would not be caught here any more — the
	#  window is kept (it still measures the real apex correctly) but the cross-mutation guard has moved to
	#  horizontal travel, below, which still separates cleanly.
	t.ok(apex_px >= 30 and apex_px <= 44,
		"slam 정점이 고정된 픽셀 범위 안에 있다 (%dpx, 30..44 - 64px 턱 밑으로 여유, 단 이 범위만으론 거대 수탉과 안 갈린다)" % apex_px)
	# **The cross-mutation guard, moved here from the apex above.** `leap_speed_mult` (1.5 vs the rooster's
	#  2.0) and the shorter `jump_vy_px` together give the slam a much shorter hang time, so it travels far
	#  less horizontally even though the two moves share the exact same physics code
	#  (`Monster.step`/`BossAi.speed_mult`). **130px of separation, not 1-8px like the apex** — swap the two
	#  moves' `jump_vy_px` or `leap_speed_mult` and this is what catches it now.
	var travel_px := stun_start_x - leap_start_x
	t.ok(travel_px >= 60 and travel_px <= 100,
		"slam 도약 중 이동 거리가 고정된 픽셀 범위 안에 있다 (%dpx, 60..100 - 거대 수탉의 130..170과 겹치지 않는다)" % travel_px)
	# **Pins `_leap_stun_ticks`'s bull/slam branch, not just the rooster's own `MOVE_LEAP.stun_ticks`** — the
	#  two moves share `Pattern.LEAP` but not a stun length; a mutation that always read `MOVE_LEAP["stun_ticks"]`
	#  (20) instead of `MOVE_SLAM["stun_ticks"]` (24) would still pass every check above (both reach `STUN`,
	#  both eventually return to `IDLE`) and only the exact run length tells them apart.
	var slam_stun_ticks: int = BossAi.MOVE_SLAM["stun_ticks"]
	t.eq(stun_run_length, slam_stun_ticks + 1,
		"stun이 정확히 MOVE_SLAM.stun_ticks+1 틱 지속된다 (%d틱, MOVE_LEAP 값이 아니라 MOVE_SLAM 값이다)" % stun_run_length)
	# **The latch resets, same precedent as `_charge_blocked_resets_between_cycles`** (Stage B's own review).
	#  `_leaped_landed` is only ever assigned while `pattern == LEAP`, and `on_tick` clears it every tick that
	#  branch runs — by the tick this test is reading (already `STUN`, at least one tick past the landing),
	#  it must read false. This is the grid-independent half of "ignites once, not every tick" — the half that
	#  *can* be measured (the grid-based half cannot, see the comment further below on why that one was dropped).
	t.ok(not m.leap_landed_now(), "착지 다음 틱엔 leap_landed_now()가 이미 false다 (매 틱 소비되고 남지 않는다)")


## **Stage G fix list ③.** The slam shipped with no contact damage path at all — verify-run measured 26
## overlapping ticks during `LEAP` with 0 hp lost, while `GORE`/`CHARGE` in the same run dealt 780/440. Fixed:
## `_char_hit_by_monsters` (`world_step.gd`) now gates `Pattern.LEAP and kind == KIND_BULL` the same shape as
## its `GORE`/`CHARGE` branches. **Enters through `WINDUP`, not straight into `LEAP`** — a first version
## white-boxed `m.pattern = LEAP` directly the way the speed-check test does, and it measured 0 damage every
## time, for a reason that only shows up once you drive real ticks through it: skipping `WINDUP` skips the
## `on_tick` transition that actually launches the jump (`_body.vy = leap_jump_vy_px(...)`, only assigned on
## the tick `was_leap` was false and the new pattern is `LEAP`). With `m.pattern` set to `LEAP` from the very
## first tick, `was_leap` reads true immediately, `vy` never leaves 0, the body never leaves the ground, and
## `on_ground` (already true) is read as "just landed" on the very same tick — `LEAP` collapses to zero real
## duration before `_char_hit_by_monsters` (which runs after `on_tick` in the same frame) ever observes it.
## Going through `WINDUP` with `pattern_left = 0` (the same idiom `_slam_does_not_ignite_wood_at_any_ring_point`
## already uses) launches the jump for real.
func _slam_landing_hurts_the_player(t) -> void:
	var kind := Defs.KIND_BULL
	var g := _bare_grid()
	var stand_x := 5000
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var spell := SpellSim.new()
	var ch := Character.new()
	var bull_center_x := float(stand_x) + Defs.w_px(kind) * 0.5
	ch.place(roundi(bull_center_x - Character.W_PX * 0.5), FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	m.pattern = BossAi.Pattern.WINDUP
	m.pattern_left = 0
	m.move_choice = BossAi.MoveChoice.SLAM
	m.pattern_dir = 1
	var hp0 := ch.hp

	var ticks := 0
	var max_ticks := 150
	while ticks < max_ticks and m.pattern != BossAi.Pattern.STUN:
		if world.frame(DT, 0.0, false, false):
			ticks += 1
	t.eq(m.pattern, BossAi.Pattern.STUN, "슬램이 착지해서 stun으로 갔다 (검사의 전제)")
	t.ok(ch.hp < hp0, "슬램 도약 중 플레이어와 겹쳐서 실제로 맞는다 (%d -> %d)" % [hp0, ch.hp])
	var lost := hp0 - ch.hp
	t.eq(lost % WorldStep.BULL_SLAM_CONTACT_DAMAGE, 0,
		"맞은 만큼이 slam 접촉 데미지의 배수다 (%d, 단위 %d)" % [lost, WorldStep.BULL_SLAM_CONTACT_DAMAGE])
	t.ok(WorldStep.BULL_SLAM_CONTACT_DAMAGE != WorldStep.BULL_CHARGE_CONTACT_DAMAGE,
		"slam 접촉 데미지가 charge 접촉 데미지와 다르다")
	t.ok(WorldStep.BULL_SLAM_CONTACT_DAMAGE != WorldStep.BULL_GORE_DAMAGE,
		"slam 접촉 데미지가 gore 데미지와 다르다")


## **The negative control — an idle/winding-up/stunned bull's own `LEAP`-shaped move never fires this
## damage path outside `LEAP` itself.** Mirrors `_touching_an_idle_bull_does_not_hurt`'s own white-boxed-IDLE
## idiom — without this, a mutation that widened the gate to "any pattern for the bull" would still pass the
## test above (it only ever samples `LEAP`).
func _touching_a_bull_mid_windup_before_a_slam_does_not_hurt(t) -> void:
	var kind := Defs.KIND_BULL
	var g := _bare_grid()
	var stand_x := 5000
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var spell := SpellSim.new()
	var ch := Character.new()
	var bull_center_x := float(stand_x) + Defs.w_px(kind) * 0.5
	ch.place(roundi(bull_center_x - Character.W_PX * 0.5), FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	m.pattern = BossAi.Pattern.WINDUP
	m.move_choice = BossAi.MoveChoice.SLAM
	m.pattern_left = 100000
	var hp0 := ch.hp

	for _i in 90:
		world.frame(DT, 0.0, false, false)
	t.eq(m.pattern, BossAi.Pattern.WINDUP, "그동안 계속 windup이었다 (검사의 전제)")
	t.eq(ch.hp, hp0, "slam 예고(windup) 중엔 닿아 있어도 안 맞는다 (LEAP이 시작되기 전이다)")


## **The kind half of the same gate — found by inverting, not assumed.** `Pattern.LEAP` is shared by the
## rooster's own leap; dropping `m.kind == KIND_BULL` from the gate (leaving `Pattern.LEAP` alone) passed
## every check in this file, including `_slam_landing_hurts_the_player` above (it only ever spawns a bull).
## The design's own acceptance 10 ("it can be hit at the moment of landing") makes the rooster's leap the
## *player's* window to hit, not a source of contact damage itself — a rooster that hurt the player just by
## landing on them would be a real, silent regression this file had no witness for until now.
func _rooster_leaping_onto_the_player_does_not_hurt_them(t) -> void:
	var kind := Defs.KIND_ROOSTER
	var g := _bare_grid()
	var stand_x := 5000
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var spell := SpellSim.new()
	var ch := Character.new()
	var rooster_center_x := float(stand_x) + Defs.w_px(kind) * 0.5
	ch.place(roundi(rooster_center_x - Character.W_PX * 0.5), FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "거대 수탉 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	m.pattern = BossAi.Pattern.WINDUP
	m.pattern_left = 0
	m.pattern_dir = 1
	var hp0 := ch.hp

	var ticks := 0
	var max_ticks := 100
	while ticks < max_ticks and m.pattern != BossAi.Pattern.STUN:
		if world.frame(DT, 0.0, false, false):
			ticks += 1
	t.eq(m.pattern, BossAi.Pattern.STUN, "거대 수탉이 착지해서 stun으로 갔다 (검사의 전제)")
	t.eq(ch.hp, hp0, "거대 수탉이 플레이어 위에 착지해도 플레이어는 안 맞는다 (착지는 반대로 맞는 쪽의 기회다)")


## **Acceptance-shaped: the slam's fire actually reaches the ground, on wood, and it is thrown outward, not
## clustered under the bull's feet.** Mirrors Stage D's `_fire_ignite_reaches_exactly_its_radius` idiom exactly
## — read the board on the landing tick itself, before a second `_grid.step()` lets natural fire spread blur
## the boundary this test exists to measure.
##
## **The expected columns are fixed literals (5 points, 6 cells apart, radius 2 -> outer edge at ±14 cells),
## not re-derived from `BossAi.slam_ignite_*`** — the same fix Stage F's own postmortem forced onto the leap's
## apex check, for the identical reason: reading the expectation back out of the same table a mutation would
## edit lets the mutation move the expectation with it. **±14, not the original ±8** — verify-look saw the
## first version on screen: the outer pair (±8 cells = ±32px) sat inside the bull's own 44px half-width, so
## the ring read as a small fire under the body, not fire thrown outward past it. `ignite_spread_cells` moved
## 3 -> 6 to fix it (`boss_ai.gd`'s own comment on `MOVE_SLAM` has the exact arithmetic).
## **Reversed by `burn-out-of-the-bull-room.md` §0/§6** (decided by the user, recorded in
## `stage1-bosses.md`'s own acceptance-4 row). `WOOD` is now `rune_only` and the slam's own ground fire is
## `IGNITE_ANY` (`world_step._ignite_slam_impact`) — the wrong source, on purpose. **This used to be named
## `_slam_lands_and_ignites_a_symmetric_ring` and asserted the reverse**; the geometry (five points, ±14 cells
## outermost) is unchanged and still exercised — only the outcome at each point flips.
func _slam_does_not_ignite_wood_at_any_ring_point(t) -> void:
	var kind := Defs.KIND_BULL
	var g := _bare_grid()
	var wood_cx0 := 50
	var wood_cx1 := 250
	# Overwrite the bare floor's top row with wood across a wide strip - generous enough that landing drift
	#  (windup is frozen; the slam's own short horizontal lunge is a few tiles at most) cannot miss it.
	g.apply(CellGrid.cmd_fill(wood_cx0, FLOOR_CY, wood_cx1, FLOOR_CY, Mat.WOOD))
	var stand_x := 100 * Tuning.CELL_PX
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(stand_x + 3000, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	# White-box straight to the WINDUP -> LEAP boundary - reaching it via the real round-robin is already
	#  covered by `_third_cycle_is_slam_and_it_leaps`; this test only needs the landing itself.
	m.pattern = BossAi.Pattern.WINDUP
	m.pattern_left = 0
	m.move_choice = BossAi.MoveChoice.SLAM
	m.pattern_dir = 1

	var ticks := 0
	var max_ticks := 150
	while ticks < max_ticks and m.pattern != BossAi.Pattern.STUN:
		if world.frame(DT, 0.0, false, false):
			ticks += 1
	t.eq(m.pattern, BossAi.Pattern.STUN, "착지해서 stun에 들어갔다 (검사의 전제)")

	var center_cx := floori(float(m.x + Defs.w_px(kind) / 2) / float(Tuning.CELL_PX))
	for d in [0, 14, -14, 15, -15]:
		t.ok(not g.is_burning(center_cx + d, FLOOR_CY),
			"착지 지점(중심에서 %d칸)에 나무가 있어도 안 붙는다 (rune_only, %d,%d)" % [d, center_cx + d, FLOOR_CY])
	t.eq(g.mat_at(center_cx, FLOOR_CY), Mat.WOOD, "나무 그대로 남는다")


## **The negative control — no wood, no fire.** Mirrors Stage D's own
## `_fire_bolt_passes_over_stone_and_leaves_nothing`: `_ignite_cell` refuses at zero fuel, and `_bare_grid()`'s
## floor is bare stone. Without this, a mutation that ignites *something* regardless of what's underneath
## reads as identical to the correct behavior on the wooded test above.
func _slam_over_stone_ignites_nothing(t) -> void:
	var kind := Defs.KIND_BULL
	var g := _bare_grid()  # stone floor only, no wood anywhere
	var stand_x := 5000
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(stand_x + 3000, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	m.pattern = BossAi.Pattern.WINDUP
	m.pattern_left = 0
	m.move_choice = BossAi.MoveChoice.SLAM
	m.pattern_dir = 1

	var ticks := 0
	var max_ticks := 150
	while ticks < max_ticks and m.pattern != BossAi.Pattern.STUN:
		if world.frame(DT, 0.0, false, false):
			ticks += 1
	t.eq(m.pattern, BossAi.Pattern.STUN, "착지해서 stun에 들어갔다 (검사의 전제)")
	t.eq(g.burning_count(), 0, "돌바닥에 착지하면 한 칸도 안 붙는다 (연료가 없다)")


## **No grid-based "fires once, not every tick" test exists here — the grid channel genuinely cannot see it,
## and that half of the finding stands.** `CellGrid._ignite_cell` guards
## `if _burn_slot[i] >= 0: return false` **before it ever reaches a write** — re-igniting an already-burning
## cell is rejected at that early return, so `_changed`/`aux_at` never move. A mutation that called
## `_ignite_slam_impact` every tick during `STUN` instead of once is unobservable by any grid measurement.
##
## **Corrected**: Stage C's own analogous check (`_charge_impact_carves_the_wall`'s tail, "stun 동안 같은 자리를
## 또 파지 않는다") is **not** blind the same way — verified, not assumed. `CellGrid._write_cell` raises
## `_changed` even when the value written is unchanged, and a carve **writes** to already-empty cells (it does
## not early-return the way `_ignite_cell` does), so a repeat carve during `STUN` would still register there.
## The two operations only *look* symmetric; they are gated at different points, and only one of them is a
## true no-op. This file's own first guess ("Stage C's check may share the blind spot") was wrong.
##
## **The reachable half is measured instead, by the latch, not the grid** — `_leap_landed_now_resets_after_
## being_consumed`-shaped assertion inside `_third_cycle_is_slam_and_it_leaps` (`t.ok(not m.leap_landed_now(),
## ...)`, right after landing is observed): `_leaped_landed` is only ever assigned while `pattern == LEAP`, and
## `on_tick` clears it unconditionally every tick that branch runs, so a tick already inside `STUN` reading it
## true would mean the clear itself broke — the same precedent as `_charge_blocked_resets_between_cycles`
## (Stage B's own review). **This is not a substitute for the grid-based check** — it proves the *signal*
## `WorldStep` reads is single-shot, not that a caller ignoring the signal and calling
## `_ignite_slam_impact` unconditionally would be caught (it would not, per the paragraph above). Recorded as
## the honest boundary of what is measured here.


## **The safety-cap negative control — a slam that never lands ignites nothing.** Mirrors Stage C's own
## `_idle_bull_blocked_by_a_wall_carves_nothing` and Stage F's `_leap_with_no_floor_ends_via_the_safety_cap`.
## `leap_landed_now()` must read false on a safety-cap timeout (only a real landing sets it), so nothing should
## reach `_ignite_slam_impact` at all here.
func _slam_safety_cap_timeout_ignites_nothing(t) -> void:
	var kind := Defs.KIND_BULL
	# **No floor, and no wood anywhere** — same grid `_leap_with_no_floor_ends_via_the_safety_cap` uses.
	#  A first version of this test placed wood far below "as a decoy, never reached" — measured wrong: at
	#  `MAX_FALL_PX` terminal velocity, `leap_max_ticks + 60` ticks of falling covers thousands of pixels,
	#  comfortably far enough to actually land on it, turning this into a real landing (burning_count 37, not
	#  0) instead of the safety-cap timeout the test exists to isolate. There is nothing to land on at all now.
	var g := CellGrid.new()
	var stand_x := 5000
	var stand_y := 100
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(stand_x + 3000, stand_y)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	m.pattern = BossAi.Pattern.WINDUP
	m.pattern_left = 0
	m.move_choice = BossAi.MoveChoice.SLAM
	m.pattern_dir = 1

	var saw_leap := false
	var reached_stun := false
	var ticks := 0
	var max_ticks: int = int(BossAi.MOVE_SLAM["leap_max_ticks"]) + 60
	while ticks < max_ticks and not reached_stun:
		if world.frame(DT, 0.0, false, false):
			ticks += 1
			if m.pattern == BossAi.Pattern.LEAP:
				saw_leap = true
			if saw_leap and m.pattern == BossAi.Pattern.STUN:
				reached_stun = true
	t.ok(saw_leap, "leap에 들어갔다 (검사의 전제)")
	t.ok(reached_stun, "바닥이 없어도 안전장치로 결국 stun까지 간다 (검사의 전제)")
	t.eq(g.burning_count(), 0, "착지가 아니라 안전장치로 끝났으니 아무것도 안 붙는다")


## **Stage G fix list ② — the hole that let a structural guarantee quietly go false.** Stage C's confinement
## was structural (`carve_r`'s hole is 7 cells tall against the bull's 14-cell body — Risk 3-addendum's own
## "the bull can never step into what it just carved"), and nothing checked it *as a fact about the room*, only
## as a fact about `carve_r`'s own arithmetic — so nothing existed to notice a second, unrelated door (a
## slam's jump arc, no destruction involved at all) opening straight over the same wall. verify-run grepped
## `net_monster` for any check on "does the bull stay in room ①" at any stage before this one and found none.
##
## **Reproduced and fixed**: at `jump_vy_px`=-600 (69px apex), verify-run measured the bull 236px outside
## room ①'s real left boundary after 89 slams over 11 real seconds, with the player parked on the room's own
## first step (`stage1-map-layout`'s "walk-in stone shelf" — a spot a player can simply walk to). At -450
## (38px apex, this stage's own fix ①) the same setup is re-run here, headless, on the real baked map.
##
## **On the real map, not a synthetic wall** (`Stage.build_terrain_into` — the same static door
## `net_water_rain.gd`/`net_tables.gd` already use, no scene tree needed). **The boundary is a fixed literal
## measured once from the baked map** (cx=1040, tile 130 — `stage1-bosses.md` Risk 3's own "x230-259",
## **now x130-159** after `left-run-clumps-and-platforms.md` §1 cut 100 columns off the left run,
## reading almost exactly, and confirmed independently here by scanning `is_solid` down the actual left wall:
## cy192->848, cy208->912, cy224->976, cy240->1040, cy256 (the floor itself) fully solid — a clean
## 4-step, 16-cell-tall/64-cell-wide staircase, the first tread of which is exactly the "2-tile step" Risk 3
## names), **not re-derived inside this test** — a mutation that broke confinement would not also move the map.
func _bull_slam_does_not_leave_room1_on_the_real_map(t) -> void:
	var kind := Defs.KIND_BULL
	var g := CellGrid.new()
	Stage.build_terrain_into(g)
	# Room ①'s left boundary at floor height, in px — the fixed literal the scan above found.
	var room1_left_boundary_px := 1040 * Tuning.CELL_PX
	var floor_top_cy := 256
	var stand_x := 1100 * Tuning.CELL_PX
	var stand_y := floor_top_cy * Tuning.CELL_PX - Defs.h_px(kind)
	var spell := SpellSim.new()
	var ch := Character.new()
	# **On the room's own first step** (cy224..239 open, solid at cy240 below it, open range cx976..1039) —
	#  "a spot a player can simply walk to" (verify-run's own repro setup), which lures the bull's ordinary
	#  `IDLE` walk-toward-player flush against the exact wall a slam would need to clear.
	var player_x := 1000 * Tuning.CELL_PX
	var player_y := 240 * Tuning.CELL_PX - Character.H_PX
	ch.place(player_x, player_y)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	# **Stage H fix list ② — this test spawned at full hp and never took damage, so it never entered phase 2.**
	#  Phase 2 halves every pattern duration (`_phase_ticks`), which raises the slam cadence near the wall —
	#  confinement had only ever been measured in phase 1. `jump_vy_px` itself is *not* phase-scaled (Stage H's
	#  own scope: only "pattern durations and charge speed", not the leap-shaped moves' own physics), so the
	#  apex margin under the step is unchanged — but a faster-cycling bull gets more attempts at the wall in
	#  the same wall-clock window, and nothing had confirmed that more attempts still can't add up to a breach.
	#  One line turns the confinement check into a real phase-2 regression test instead of an unstated phase-1
	#  assumption.
	m.hp = Defs.max_hp(kind) / 2
	t.ok(m.is_phase2(), "2페이즈로 싸운다 (검사의 전제 - slam이 더 자주 나온다)")

	var min_x_seen := m.x
	var approached_the_wall := false
	var ticks := 0
	# **600, not the first version's 4000** — the real-map repro that found this bug breached at 220 ticks
	#  (89 slams, 11 real seconds at 20Hz); 600 is 2.7x that window, comfortable margin without paying for
	#  6.7x more simulation than the finding needed (measured: 4000 ticks pushed this file from ~11s to ~23s
	#  and the full round with it, past CLAUDE.md's 10s line - harness-manager's territory, not a free cost).
	#  **Phase 2 makes ticks cheaper per slam, not more expensive overall** — the same 600-tick budget now
	#  covers proportionally more slam cycles than it did at phase 1, which is exactly the scenario this fix
	#  needs covered, not a reason to raise the budget.
	var max_ticks := 600
	while ticks < max_ticks:
		if world.frame(DT, 0.0, false, false):
			ticks += 1
			min_x_seen = mini(min_x_seen, m.x)
			if m.x <= room1_left_boundary_px + 20:
				approached_the_wall = true
	t.ok(approached_the_wall,
		"싸우는 동안 실제로 왼쪽 벽 근처까지 갔다 (검사의 전제 - 안 갔으면 이 검사는 아무것도 증명 못 한다)")
	t.ok(min_x_seen >= room1_left_boundary_px,
		"황소가 room ①의 왼쪽 경계(%dpx)를 절대 안 넘는다 (최소 x=%d)" % [room1_left_boundary_px, min_x_seen])


# ==================================================================
#  stage1-bosses.md Stage H — phases ("it speeds up at half health")
# ==================================================================

## The table values, by themselves — the same "provisional is not the same as unmeasured" lesson every
## earlier stage's review pass left behind. **Fixed literals, not `PHASE2_SPEED_MULT` re-read** — 4.0, not
## `MOVE_CHARGE["charge_speed_mult"] * BossAi.PHASE2_SPEED_MULT`, so a mutation to either constant is still
## caught here independently of the other.
func _phase2_values_are_read(t) -> void:
	t.eq(BossAi.speed_mult(Defs.KIND_BULL, BossAi.Pattern.CHARGE, false), 2.0, "1페이즈 charge 배속 = 2.0")
	t.eq(BossAi.speed_mult(Defs.KIND_BULL, BossAi.Pattern.CHARGE, true), 4.0,
		"2페이즈 charge 배속 = 4.0 (고정값)")
	# **Only "charge speed" is named in the plan's own words** — the leap-shaped moves' own multipliers are
	#  untouched by phase2 (`PHASE2_SPEED_MULT`'s own comment in `boss_ai.gd`), so both stay exactly what
	#  they were at phase 1.
	t.eq(BossAi.speed_mult(Defs.KIND_ROOSTER, BossAi.Pattern.LEAP, true), 2.0,
		"거대 수탉 leap 배속은 2페이즈에도 그대로다 (설계 문서가 charge speed만 명시한다)")
	t.eq(BossAi.speed_mult(Defs.KIND_BULL, BossAi.Pattern.LEAP, true), 1.5,
		"황소 slam 배속도 2페이즈 영향이 없다")


## **`_phase_ticks`'s own guard, driven directly.** The smallest duration in the table today
## (`MOVE_GORE.active_ticks`=12) never gets close to 0, so nothing in a normal fight would ever expose a
## missing guard — this drives the boundary value (1) directly, the same idiom
## `_gore_range_boundary_is_exactly_120px` already uses for a different boundary.
func _phase2_duration_guard_never_hits_zero(t) -> void:
	t.eq(BossAi._phase_ticks(12, true), 6, "12 -> 6 (일반적인 케이스)")
	t.eq(BossAi._phase_ticks(1, true), 1, "1 -> 1 (0으로 안 내려간다 - 가드가 없으면 상태 기계가 멈춘다)")
	t.eq(BossAi._phase_ticks(1, false), 1, "1페이즈(phase2=false)면 원래 값 그대로다")
	t.eq(BossAi._phase_ticks(16, false), 16, "phase2=false면 어떤 값도 스케일하지 않는다")


## **Half health, driven by value, not derived from `Defs.max_hp`.** 300/150/151/1 are fixed literals
## (`Defs.max_hp(KIND_BULL)`=300 is asserted as the test's own premise, not read into the boundary math), so a
## mutation to `Defs.max_hp` itself cannot silently move this test's expectations along with it.
func _is_phase2_boundary(t) -> void:
	t.eq(Defs.max_hp(Defs.KIND_BULL), 300, "황소 max_hp = 300 (검사의 전제)")
	var m := Monster.new(1, Defs.KIND_BULL, 0, 0)
	m.hp = 300
	t.ok(not m.is_phase2(), "풀피(300)면 1페이즈다")
	m.hp = 151
	t.ok(not m.is_phase2(), "절반보다 1 많으면(151) 아직 1페이즈다")
	m.hp = 150
	t.ok(m.is_phase2(), "정확히 절반(150)이면 2페이즈다")
	m.hp = 1
	t.ok(m.is_phase2(), "1이어도 2페이즈다")


## **Trash mobs never enter phase 2, at any hp — the kind gate, driven directly, not assumed from
## `BossAi.has_pattern` being tested elsewhere.** Team-lead's own finding: a low-hp pig wearing the same
## "this got more dangerous" outline a boss does is wrong on the face of it (the pig got weaker, not
## stronger). `Defs.max_hp(KIND_PIG)`=30 is small enough that `hp * 2 <= max_hp` alone would trigger well
## before death (1hp: 1*2=2 <= 30) — this is the exact case that would slip through if the kind gate in
## `is_phase2()` were ever deleted, so it is pinned at hp=1, not just at some comfortable mid-range value.
func _trash_mobs_never_enter_phase2(t) -> void:
	var pig := Monster.new(1, Defs.KIND_PIG, 0, 0)
	pig.hp = 1
	t.ok(not pig.is_phase2(), "돼지는 hp=1이어도 2페이즈가 아니다 (has_pattern이 없다)")
	var hen := Monster.new(2, Defs.KIND_HEN, 0, 0)
	hen.hp = 1
	t.ok(not hen.is_phase2(), "닭도 hp=1이어도 2페이즈가 아니다")


## **The behavioral half — `BossAi.advance` driven directly, both phases, same transition.** Mirrors the
## "provisional is not the same as unmeasured" split every earlier stage's own table-value test carries: a
## table function returning the right multiplier wired to nothing would pass `_phase2_values_are_read` above
## and still fail this one. Calling `advance` directly (not through `world.frame()`) isolates the transition
## itself from simulation noise — the same white-boxed idiom `_charging_bull_does_not_step_a_3cell_ledge`
## already uses for a different function.
## **Stage H fix list ① (verify-read).** The first version of this test drove 3 of `advance()`'s 13
## `_phase_ticks(...)` call sites. Bypassing the scaling at exactly one of the other 10
## (`MOVE_FIRE["breathe_ticks"]`, the `WINDUP`->`FIRE` transition) stayed green — nothing forced every
## transition to actually be visited, so a missed line was silent. **This drives all 13 by construction**, one
## row per call site, not added one at a time as bugs are found. **Each phase-1 value is pinned as a fixed
## literal**, not derived by halving phase-2's own result — an A/B comparison alone cannot catch "both sides
## silently vanished together" (CLAUDE.md's own named failure shape), only a comparison against a value fixed
## independently of both.
func _phase2_scales_pattern_durations(t) -> void:
	# [description, kind, pattern, pattern_left, pattern_dir, move_choice, blocked, axis, in_gore_range,
	#  landed, expected next pattern, expected phase-1 ticks (fixed literal)]
	var B := Defs.KIND_BULL
	var R := Defs.KIND_ROOSTER
	var P := BossAi.Pattern
	var MC := BossAi.MoveChoice
	var cases: Array[Array] = [
		# 1. CHARGE blocked -> STUN (MOVE_CHARGE.stun_ticks) — the collision path.
		["CHARGE 막힘 -> STUN", B, P.CHARGE, 5, 1, MC.CHARGE, true, 0.0, false, false, P.STUN, 24],
		# 2. LEAP landed (rooster) -> STUN (MOVE_LEAP.stun_ticks) — the collision path.
		["LEAP 착지(수탉) -> STUN", R, P.LEAP, 5, 1, 0, false, 0.0, false, true, P.STUN, 20],
		# 2b. LEAP landed (bull's slam) -> STUN (MOVE_SLAM.stun_ticks) — same call site as #2, other kind.
		["LEAP 착지(황소 slam) -> STUN", B, P.LEAP, 5, 1, MC.SLAM, false, 0.0, false, true, P.STUN, 24],
		# 3. IDLE -> WINDUP, round-robin picks CHARGE (MOVE_CHARGE.windup_ticks).
		["IDLE -> WINDUP(charge)", B, P.IDLE, 0, 1, -1, false, 1.0, false, false, P.WINDUP, 16],
		# 3b. same call site, round-robin picks FIRE (MOVE_FIRE.windup_ticks).
		["IDLE -> WINDUP(fire)", B, P.IDLE, 0, 1, MC.CHARGE, false, 1.0, false, false, P.WINDUP, 12],
		# 3c. same call site, round-robin picks SLAM (MOVE_SLAM.windup_ticks).
		["IDLE -> WINDUP(slam)", B, P.IDLE, 0, 1, MC.FIRE, false, 1.0, false, false, P.WINDUP, 18],
		# 3d. same call site, the rooster's one-element table (MOVE_LEAP.windup_ticks).
		["IDLE -> WINDUP(수탉 leap)", R, P.IDLE, 0, 1, -1, false, 1.0, false, false, P.WINDUP, 14],
		# 4. WINDUP(rooster) -> LEAP (MOVE_LEAP.leap_max_ticks).
		["WINDUP(수탉) -> LEAP", R, P.WINDUP, 0, 1, 0, false, 1.0, false, false, P.LEAP, 40],
		# 5. WINDUP(slam) -> LEAP (MOVE_SLAM.leap_max_ticks) — same shared pattern, a different call site.
		["WINDUP(slam) -> LEAP", B, P.WINDUP, 0, 1, MC.SLAM, false, 1.0, false, false, P.LEAP, 40],
		# 6. WINDUP(fire) -> FIRE (MOVE_FIRE.breathe_ticks) — the exact line verify-read's mutation bypassed.
		["WINDUP(fire) -> FIRE", B, P.WINDUP, 0, 1, MC.FIRE, false, 1.0, false, false, P.FIRE, 20],
		# 7. WINDUP(charge, in gore range) -> GORE (MOVE_GORE.active_ticks).
		["WINDUP(gore 사거리) -> GORE", B, P.WINDUP, 0, 1, MC.CHARGE, false, 1.0, true, false, P.GORE, 12],
		# 8. WINDUP(charge, out of gore range) -> CHARGE (MOVE_CHARGE.charge_max_ticks) — the fall-through.
		["WINDUP(charge) -> CHARGE", B, P.WINDUP, 0, 1, MC.CHARGE, false, 1.0, false, false, P.CHARGE, 60],
		# 9. CHARGE safety cap -> STUN (MOVE_CHARGE.stun_ticks) — same value as #1, a different call site
		#    (the timeout path, not the collision path — verify-read's own distinction).
		["CHARGE 안전장치 -> STUN", B, P.CHARGE, 0, 1, MC.CHARGE, false, 0.0, false, false, P.STUN, 24],
		# 10. FIRE ends -> STUN (MOVE_FIRE.stun_ticks).
		["FIRE 종료 -> STUN", B, P.FIRE, 0, 1, MC.FIRE, false, 0.0, false, false, P.STUN, 20],
		# 11. GORE ends -> STUN (MOVE_GORE.stun_ticks).
		["GORE 종료 -> STUN", B, P.GORE, 0, 1, MC.CHARGE, false, 0.0, false, false, P.STUN, 20],
		# 12. LEAP safety cap (rooster) -> STUN (MOVE_LEAP.stun_ticks) — the timeout path, not #2's landed path.
		["LEAP 안전장치(수탉) -> STUN", R, P.LEAP, 0, 1, 0, false, 0.0, false, false, P.STUN, 20],
		# 12b. LEAP safety cap (bull's slam) -> STUN (MOVE_SLAM.stun_ticks).
		["LEAP 안전장치(황소 slam) -> STUN", B, P.LEAP, 0, 1, MC.SLAM, false, 0.0, false, false, P.STUN, 24],
		# 13. STUN -> IDLE (IDLE_TICKS) — the boss-level constant, not any one move's own dict.
		["STUN -> IDLE", B, P.STUN, 0, 1, MC.CHARGE, false, 0.0, false, false, P.IDLE, 20],
	]
	for c: Array in cases:
		var desc: String = c[0]
		var r1 := BossAi.advance(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], false)
		var r2 := BossAi.advance(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], true)
		var expected_pattern: int = c[10]
		var expected_phase1: int = c[11]
		t.eq(r1[0], expected_pattern, "%s - 1페이즈 다음 패턴 (검사의 전제)" % desc)
		t.eq(r2[0], expected_pattern, "%s - 2페이즈도 같은 다음 패턴 (검사의 전제)" % desc)
		t.eq(int(r1[1]), expected_phase1, "%s - 1페이즈 값 = %d (고정값)" % [desc, expected_phase1])
		t.eq(int(r2[1]), maxi(1, expected_phase1 / 2),
			"%s - 2페이즈 값 = %d (절반, 고정값 - r1에서 나눠 계산하지 않는다)" % [desc, maxi(1, expected_phase1 / 2)])


func _phase2_speeds_up_the_real_windup_by_the_ratio(t) -> void:
	var kind := Defs.KIND_BULL
	var run1 := _measure_windup_run_length_at_hp(kind, 300)
	var run2 := _measure_windup_run_length_at_hp(kind, 150)
	t.eq(run1, 17, "1페이즈(hp=300) windup 실측 = 17틱 (windup_ticks(16)+1, 검사의 전제)")
	t.eq(run2, 9, "2페이즈(hp=150) windup 실측 = 9틱 (8+1, 고정값)")
	t.eq(run1 - 1, (run2 - 1) * 2,
		"펜스포스트(+1)를 뺀 실제 지속시간이 정확히 2배 비율이다 (%d vs %d)" % [run1 - 1, run2 - 1])


## **The speed half, driven through actual movement, not just `speed_mult`'s own return value.** Mirrors
## `_charge_moves_at_the_charge_speed_not_walking_speed`'s one-frame-displacement idiom exactly. **The
## expected speed is `phase1_charge_speed * 2.0`, a fixed literal multiplier, not
## `BossAi.PHASE2_SPEED_MULT` re-read** — the same fixed-literal discipline every apex/window fix in this file
## now follows.
func _phase2_charge_moves_twice_as_fast(t) -> void:
	var kind := Defs.KIND_BULL
	var g := _bare_grid()
	var stand_x := 5000
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(stand_x + 3000, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	world.spawn_monster(kind, stand_x, FLOOR_TOP - Defs.h_px(kind))
	var m: Monster = world.monster_at(0)
	m.pattern = BossAi.Pattern.CHARGE
	m.pattern_dir = 1
	m.pattern_left = int(BossAi.MOVE_CHARGE["charge_max_ticks"])
	m.hp = 150
	t.ok(m.is_phase2(), "2페이즈다 (검사의 전제)")

	var x0 := m.x
	world.frame(DT, 0.0, false, false)
	var moved := m.x - x0
	var walk_speed := Defs.speed_px(kind)
	var phase1_charge_speed := walk_speed * float(BossAi.MOVE_CHARGE["charge_speed_mult"])
	var phase2_charge_speed := phase1_charge_speed * 2.0
	t.eq(moved, roundi(phase2_charge_speed * DT),
		"2페이즈 charge 이동량이 1페이즈의 2배 속도와 일치한다 (%dpx)" % moved)
	t.ok(moved > roundi(phase1_charge_speed * DT),
		"1페이즈 charge 속도보다 빠르다 (1페이즈였다면 %dpx)" % roundi(phase1_charge_speed * DT))


## Screen wiring — the same idiom as `_pattern_indicator_is_wired_to_the_screen`. Text, so it goes only as
## far as "does `_draw_monster` call it" — the internal hp threshold is measured by value below instead.
func _phase2_tell_is_wired_to_the_screen(t) -> void:
	var f := FileAccess.open("res://src/view/monster_view.gd", FileAccess.READ)
	t.ok(f != null, "monster_view.gd를 읽었다 (검사의 전제)")
	if f == null:
		return
	var src := NetDeterminism._strip(f.get_as_text())
	f.close()
	var draw_monster := _func_body(src, "_draw_monster")
	t.ok(draw_monster != "", "`_draw_monster`를 소스에서 찾았다 (검사의 전제)")
	t.ok(draw_monster.contains("_draw_phase2_tell("),
		"`_draw_monster`가 `_draw_phase2_tell(`를 부른다 (2페이즈 표시가 화면에 닿는다)")


## **Driven, not grepped** — the same fix Stage B's own review already applied to the pattern indicator.
## `_draw_phase2_tell`'s own threshold logic is exercised for real (it is not overridden); only its leaf,
## `_draw_phase2_ring`, is overridden to record instead of calling `draw_rect` on a node with nothing to draw
## onto. **Composes with the pattern indicator rather than replacing it** — the mid-windup-and-low-hp case
## checks both fire in the same call, since `_draw_monster` calls both functions independently, not
## exclusively (a boss can be mid-telegraph and below half hp at the same instant).
func _phase2_tell_draws_for_low_hp_only(t) -> void:
	var kind := Defs.KIND_BULL
	var r := Rect2(0, 0, Defs.w_px(kind), Defs.h_px(kind))
	var cases: Array[Array] = [
		[300, []],
		[151, []],
		[150, ["phase2"]],
		[1, ["phase2"]],
	]
	for c: Array in cases:
		var v := _RecordingMonsterView.new()
		var m := Monster.new(1, kind, 0, 0)
		m.hp = c[0]
		v._draw_phase2_tell(m, r)
		t.eq(v.drawn, c[1], "hp=%d일 때 그려지는 것 %s" % [c[0], c[1]])
		v.free()

	# Composes with the pattern indicator - both tells fire in the same call when both conditions hold.
	var v2 := _RecordingMonsterView.new()
	var m2 := Monster.new(1, kind, 0, 0)
	m2.hp = 150
	m2.pattern = BossAi.Pattern.WINDUP
	v2._draw_pattern_indicator(m2, r)
	v2._draw_phase2_tell(m2, r)
	t.eq(v2.drawn, ["predict", "phase2"],
		"windup 중이면서 2페이즈면 두 표시가 같이 그려진다 (하나가 하나를 덮지 않는다)")
	v2.free()

	# **Trash mobs are exempted, decided rather than left as the arithmetic's own accident.** A first version
	#  of this test found the opposite: `Defs.max_hp(KIND_PIG)` is small (30), so a pig at 1 hp genuinely
	#  satisfies `hp * 2 <= max_hp` numerically (1*2=2 <= 30), and `Monster.is_phase2()` carried no kind guard
	#  at the time — the tell drew on a pig too. Team-lead's call: wrong on the face of it, the outline's whole
	#  job is "this thing just got more dangerous" and a weakened pig is the opposite. Fixed in `is_phase2()`
	#  itself (`BossAi.has_pattern(kind) and ...`), not here — one gate, not a guard copied at every caller.
	var v3 := _RecordingMonsterView.new()
	var pig := Monster.new(2, Defs.KIND_PIG, 0, 0)
	pig.hp = 1
	t.ok(not pig.is_phase2(), "돼지는 체력이 얼마든 2페이즈가 아니다 (검사의 전제)")
	v3._draw_phase2_tell(pig, Rect2(0, 0, Defs.w_px(Defs.KIND_PIG), Defs.h_px(Defs.KIND_PIG)))
	t.eq(v3.drawn, [], "패턴 없는 종류는 체력이 아무리 낮아도 2페이즈 표시가 안 뜬다")
	v3.free()
