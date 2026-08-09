extends RefCounted
## Monster boss stages B/C -- the bull's pattern machine (idle -> windup -> charge -> stun) and the charge's
##  wall-carving. Split out of net_monster.gd.
##
## **Why split (harness-manager, stage1-bosses.md Stage E-I round, measured)**: Stage E-I (gore, the rooster's
##  leap/slam, phases) landed on top of Stage B-D's own already-thinned floor and pushed net_monster.gd to 636
##  checks / 4053 lines / ~15.9s solo -- the single pacing item of the whole round (round 16.0s, monster alone
##  15.9s of it). Per-check profiling (Time.get_ticks_usec() around every run() call, temporary, reverted after)
##  found no single outlier the way the old un-thinned floor or the old tick caps were -- the cost is flat across
##  dozens of checks in the 100-600ms range. Splitting by stage is the only lever left; the previous round's own
##  rejection of this ("revisit when stages E-I land and add comparable check volume") no longer holds -- they did.
##
## **Grouped by profiled time, not by raw stage count**: this file (Stage B's pattern machine + Stage B's second
##  pass + Stage C's carve + Stage C's second pass) summed to ~2.77s of check-body time in the profile, the
##  lightest of the four post-split files -- kept as one file rather than split further.
##
## **The full story, the historical stage-by-stage design notes, and the six-mutation fix-list table live in
##  net_monster.gd's own header comment** -- not repeated here to avoid the two copies drifting apart
##  (CLAUDE.md: "if the same explanation appears in two files, move it to one").

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
## draw call ran without needing a real canvas (`_draw_telegraph`/`_draw_stun_ring` both draw onto `self`
## directly, so recording in an override is the whole trick — no shader, no child layer, no scene needed).
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
	# -- stage1-bosses.md Stage B -- the pattern machine + charge -> ram -> stun --
	_bull_pattern_sequence_is_idle_windup_charge_stun_idle(t)
	_charge_with_no_wall_ends_via_the_safety_cap(t)
	_bull_does_not_move_during_stun_with_no_wall_involved(t)
	_charging_bull_does_not_step_a_3cell_ledge(t)
	_pattern_indicator_is_wired_to_the_screen(t)
	_pattern_indicator_draws_the_right_thing_for_the_right_state(t)
	# -- stage1-bosses.md Stage B, second pass (verify-read's 5 holes) --
	_charge_blocked_resets_between_cycles(t)
	_charge_direction_follows_the_player_left_too(t)
	_charge_speed_mult_is_read(t)
	_charge_moves_at_the_charge_speed_not_walking_speed(t)
	# -- stage1-bosses.md Stage C -- the charge carves, only while charging --
	_charge_carve_r_is_read(t)
	_charge_impact_carves_the_wall(t)
	_idle_bull_blocked_by_a_wall_carves_nothing(t)
	_single_charge_does_not_breach_a_16cell_boundary(t)
	# -- stage1-bosses.md Stage C, second pass (verify-read's structural findings) --
	_charge_impact_eats_the_same_cells_either_direction(t)
	_charge_destruction_does_not_accumulate_across_cycles(t)


# ==================================================================
#  stage1-bosses.md Stage B — the pattern machine + charge -> ram -> stun
# ==================================================================

## **Risk 5 — a check that reads only final state cannot measure a pattern.** This drives `world.frame()`
## tick by tick and records `m.pattern` **at every tick**, then collapses consecutive repeats into the
## distinct sequence actually walked — proving *order* (idle -> windup -> charge -> stun -> idle), not just
## "it ended up idle again". The windup and stun run-lengths are asserted **exactly** (`+1`: the tick that
## *sets* the counter is itself the first sample, before any decrement happens) — the "assert the iteration
## count too" half of the same risk. A machine that never left `IDLE` would compress to length 1, not 5, and
## a machine whose counter never decremented would produce a run-length of 0 rather than `windup_ticks + 1`.
##
## **The wall sits 200px from the bull's spawn** — far enough that the ~5px the monster still walks toward
## the player during the couple of frames before its first tick (fires the `IDLE -> WINDUP` transition) does
## not already touch the wall (measured: a 4px gap did — the "charge moved" check read 504 -> 504, i.e. the
## gap had already been closed by ordinary walking before charging ever began), close enough to stay well
## inside `charge_max_ticks`' reach.
func _bull_pattern_sequence_is_idle_windup_charge_stun_idle(t) -> void:
	var kind := Defs.KIND_BULL
	var g := _bare_grid()
	var stand_x := 500
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var wall_left_px := stand_x + Defs.w_px(kind) + 200
	var wall_cx := wall_left_px / Tuning.CELL_PX
	g.apply(CellGrid.cmd_fill(wall_cx, FLOOR_CY - 30, wall_cx + 20, FLOOR_CY - 1, Mat.STONE))

	var spell := SpellSim.new()
	var ch := Character.new()
	# Beyond the wall - the charge direction is picked toward the player, i.e. +1, straight into it.
	ch.place(wall_left_px + 400, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	t.eq(m.pattern, BossAi.Pattern.IDLE, "스폰 직후엔 idle이다 (검사의 전제)")

	var seq: Array[int] = [m.pattern]
	var xs: Array[int] = [m.x]
	var ticks := 0
	var max_ticks := 200
	while ticks < max_ticks:
		var ticked := world.frame(DT, 0.0, false, false)
		if not ticked:
			continue
		ticks += 1
		seq.append(m.pattern)
		xs.append(m.x)
		if seq.size() >= 5 and m.pattern == BossAi.Pattern.IDLE \
				and seq[seq.size() - 2] == BossAi.Pattern.STUN:
			break  # the full cycle closed - running further only adds margin, not information

	var compressed: Array[int] = []
	var run_lengths: Array[int] = []
	for p: int in seq:
		if compressed.is_empty() or compressed[compressed.size() - 1] != p:
			compressed.append(p)
			run_lengths.append(1)
		else:
			run_lengths[run_lengths.size() - 1] += 1

	t.eq(compressed, [BossAi.Pattern.IDLE, BossAi.Pattern.WINDUP, BossAi.Pattern.CHARGE,
		BossAi.Pattern.STUN, BossAi.Pattern.IDLE],
		"패턴이 idle -> windup -> charge -> stun -> idle 순서로만 간다 (실제: %s)" % [compressed])

	if compressed.size() >= 5:
		var windup_ticks: int = BossAi.MOVE_CHARGE["windup_ticks"]
		var stun_ticks: int = BossAi.MOVE_CHARGE["stun_ticks"]
		t.eq(run_lengths[1], windup_ticks + 1,
			"windup이 정확히 windup_ticks+1 틱 지속된다 (%d틱, 0이면 카운터가 안 돈 것)" % run_lengths[1])
		# **Not pinned to an exact count** - how many ticks the 200px gap takes depends on sub-pixel rounding
		#  inside `Body.move_x` that this test does not re-derive by hand. `>= 1` still proves the loop did
		#  not skip the state (the CLAUDE.md failure this whole risk names), and the movement check below
		#  proves it was not a zero-distance charge either.
		t.ok(run_lengths[2] >= 1, "충전 상태가 최소 1틱은 지속된다 (%d틱)" % run_lengths[2])
		t.eq(run_lengths[3], stun_ticks + 1,
			"stun이 정확히 stun_ticks+1 틱 지속된다 (%d틱, 0이면 카운터가 안 돈 것)" % run_lengths[3])

	# **Not just labels — the process itself.** Frozen during windup; it actually moved during charge.
	# **The stun-freeze check does NOT live here** (Stage F fix list, found while writing the rooster's own
	#  version) — the bull ends this charge flush against the wall it just rammed, so `move_x` is blocked on
	#  every subsequent tick whether or not `_boss_axis`'s `STUN` freeze runs at all. That makes "0px during
	#  stun" a tautology of *this test's own setup*, not a measurement of the freeze. The real version, with
	#  no wall to make it trivially true, is `_bull_does_not_move_during_stun_with_no_wall_involved` below.
	var windup_start := seq.find(BossAi.Pattern.WINDUP)
	var charge_start := seq.find(BossAi.Pattern.CHARGE)
	var stun_start := seq.find(BossAi.Pattern.STUN)
	if windup_start > 0 and charge_start > windup_start:
		t.eq(xs[charge_start - 1], xs[windup_start],
			"windup 동안 한 픽셀도 움직이지 않는다 (%d -> %d)" % [xs[windup_start], xs[charge_start - 1]])
	if charge_start > 0 and stun_start > charge_start:
		t.ok(xs[stun_start] > xs[charge_start - 1],
			"charge 동안 실제로 움직였다 (%d -> %d)" % [xs[charge_start - 1], xs[stun_start]])


## The safety-cap branch (`boss_ai.advance`'s "no wall found" fallback) — otherwise it is dead code that no
## test ever actually runs, and a text search finding the branch is not the same as it firing.
## No wall anywhere near the charge's reach (`_bare_grid()` is floor-only, and the player stands 5,000px
## away so the bull never runs out of "toward the player" room either) — `CHARGE` can only end one way here.
func _charge_with_no_wall_ends_via_the_safety_cap(t) -> void:
	var kind := Defs.KIND_BULL
	var g := _bare_grid()
	var stand_x := 1000
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(stand_x + 5000, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)

	var charge_max_ticks: int = BossAi.MOVE_CHARGE["charge_max_ticks"]
	var saw_charge := false
	var reached_stun := false
	var ticks := 0
	var max_ticks := charge_max_ticks + 60  # windup + charge + margin
	while ticks < max_ticks and not reached_stun:
		if world.frame(DT, 0.0, false, false):
			ticks += 1
			if m.pattern == BossAi.Pattern.CHARGE:
				saw_charge = true
			if saw_charge and m.pattern == BossAi.Pattern.STUN:
				reached_stun = true
	t.ok(saw_charge, "충전에 들어갔다 (검사의 전제)")
	t.ok(reached_stun, "벽이 없어도 안전장치(charge_max_ticks)로 결국 stun까지 간다")


## **The real "does not move during stun" check — off the wall, per the Stage F fix list.**
## `_bull_pattern_sequence_is_idle_windup_charge_stun_idle`'s own version of this assertion was a tautology:
## the bull ends that test's charge flush against the wall it just rammed, so `move_x` is blocked on every
## later tick regardless of whether `_boss_axis`'s `STUN` freeze exists at all (measured: deleting the freeze
## left that assertion green). Here `STUN` is reached the safety-cap way, on an open floor with no wall
## anywhere near the bull and the player still 5,000px away — if the freeze were ever deleted, `_boss_axis`
## would fall through to `_toward_player_axis` and the bull would genuinely walk toward the player with
## nothing to stop it. This is what makes the assertion real.
func _bull_does_not_move_during_stun_with_no_wall_involved(t) -> void:
	var kind := Defs.KIND_BULL
	var g := _bare_grid()
	var stand_x := 1000
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(stand_x + 5000, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, FLOOR_TOP - Defs.h_px(kind))
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)

	var charge_max_ticks: int = BossAi.MOVE_CHARGE["charge_max_ticks"]
	var x_at_stun_start := -1
	var x_after_stun := -1
	var stayed_in_stun := true
	var ticks := 0
	var max_ticks := charge_max_ticks + 60
	while ticks < max_ticks and x_at_stun_start < 0:
		if world.frame(DT, 0.0, false, false):
			ticks += 1
			if m.pattern == BossAi.Pattern.STUN:
				x_at_stun_start = m.x
	t.ok(x_at_stun_start >= 0, "안전장치로 stun에 들어갔다 (검사의 전제 - 벽이 근처에 없다)")
	# **Sampled every tick, and every tick checked for still being `STUN`** — not a fixed frame count run
	#  blind, so a stun that ends early (or never starts) cannot silently pass this by comparing two points
	#  that both happen to sit inside `IDLE`.
	var sample_ticks := 10
	for _i in sample_ticks:
		while not world.frame(DT, 0.0, false, false):
			pass
		if m.pattern != BossAi.Pattern.STUN:
			stayed_in_stun = false
			break
		x_after_stun = m.x
	t.ok(stayed_in_stun, "%d틱 동안은 stun_ticks(%d) 안쪽이라 여전히 stun이다 (검사의 전제)" \
		% [sample_ticks, int(BossAi.MOVE_CHARGE["stun_ticks"])])
	t.eq(x_after_stun, x_at_stun_start,
		"벽 없이도 stun 동안 한 픽셀도 움직이지 않는다 (%d -> %d)" % [x_at_stun_start, x_after_stun])


## **The `step_cells`=3 mid-charge decision, driven by value.** A dedicated check, separate from
## `_pig_and_hen_cross_the_ledge_differently` above (which now excludes bosses on purpose) — this is exactly
## the interaction that test can no longer measure cleanly. `stage1-bosses.md` Risk 3 measured room ①'s own
## left boundary as a 2-tile step; letting a charge auto-climb a step this short would mean "ramming stuns
## it" never fires on that side, so `Body.move_x`'s `allow_step` is forced off during `CHARGE`. White-box:
## `pattern` is forced directly so this measures the step decision alone, not the windup timing already
## covered above.
func _charging_bull_does_not_step_a_3cell_ledge(t) -> void:
	var kind := Defs.KIND_BULL
	var ledge_cells := 3
	var ledge_cx := 80
	var g := _bare_grid()
	g.apply(CellGrid.cmd_fill(
		ledge_cx, FLOOR_CY - ledge_cells, FLOOR_W_CX - 1, FLOOR_CY + FLOOR_DEPTH_CY - 1, Mat.STONE))
	var ledge_left_px := ledge_cx * Tuning.CELL_PX

	var spell := SpellSim.new()
	var ch := Character.new()
	var stand_x := ledge_left_px - 150
	ch.place(ledge_left_px + 400, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, FLOOR_TOP - Defs.h_px(kind))
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	m.pattern = BossAi.Pattern.CHARGE
	m.pattern_dir = 1
	m.pattern_left = int(BossAi.MOVE_CHARGE["charge_max_ticks"])

	# **Not the pig test's 300 frames.** Run that long here and the cycle keeps going: charge blocks, stuns,
	#  and once `stun_ticks` runs out it returns to `IDLE`, which walks normally (step-up allowed again) and
	#  crosses the very ledge this test exists to prove it cannot cross while charging (measured: 300 frames
	#  landed it at x=832, well past the ledge, back in a *second* charge). 60 frames = 20 ticks is comfortably
	#  inside the first `STUN` window (`stun_ticks`=24, so `STUN` alone lasts to roughly tick 30) and well past
	#  the few ticks charging needs to reach the ledge (62px at charge speed).
	for _i in 60:
		world.frame(DT, 0.0, false, false)
	t.eq(m.x, ledge_left_px - Defs.w_px(kind),
		"충전 중엔 %d셀 턱도 못 넘고 벽처럼 막힌다 (x=%d)" % [ledge_cells, m.x])
	t.eq(m.pattern, BossAi.Pattern.STUN,
		"막혔으니 stun으로 넘어갔다 (충전이 계단을 넘는 게 아니라 멈추는 걸 증명한다)")


## Screen wiring (`stage1-bosses.md` Stage B's screen share, acceptance 3). Text, so it goes as far as "does
## it call" — the same idiom as `_shell_hands_the_world_to_the_view`. **Scoped to `_draw_monster`'s own body**
## (`_func_body`), not the whole file — `.contains()` on the raw source would stay green even if the call
## were deleted from `_draw_monster`, since the string still exists in the callee's own `func` line.
## Pixel-level verification belongs to verify-look.
func _pattern_indicator_is_wired_to_the_screen(t) -> void:
	var f := FileAccess.open("res://src/view/monster_view.gd", FileAccess.READ)
	t.ok(f != null, "monster_view.gd를 읽었다 (검사의 전제)")
	if f == null:
		return
	var src := NetDeterminism._strip(f.get_as_text())
	f.close()

	# **Only "is it called" stays a text scan** — this half was never the weak one (verify-read's mutations
	#  both lived *inside* `_draw_pattern_indicator`/`_draw_telegraph`/`_draw_stun_ring`, not in whether
	#  `_draw_monster` calls the entry point). The internal logic is measured by value below instead —
	#  `.contains("BossAi.Pattern.WINDUP")` used to sit here and stayed green through a branch swap that made
	#  the screen say the opposite of the truth, and through a condition that made it draw nothing at all.
	var draw_monster := _func_body(src, "_draw_monster")
	t.ok(draw_monster != "", "`_draw_monster`를 소스에서 찾았다 (검사의 전제)")
	t.ok(draw_monster.contains("_draw_pattern_indicator("),
		"`_draw_monster`가 `_draw_pattern_indicator(`를 부른다 (패턴이 화면에 닿는다)")


## **Driven, not grepped** (verify-read's finding — the box above). A subclass overrides the two leaf draw
## calls to record which one ran, then `_draw_pattern_indicator` is called directly on an **untreed**
## instance per pattern state. This catches a branch swap (WINDUP drawing the stun ring and vice versa) and
## a condition that silently draws nothing — neither moved a single assertion in the old text scan.
## **What this cannot catch**: the drawing functions' own insides being empty or wrong pixel-wise — that half
## stays verify-look's, honestly, not this net's (CLAUDE.md: "only `_draw()` truly resists").
func _pattern_indicator_draws_the_right_thing_for_the_right_state(t) -> void:
	var kind := Defs.KIND_BULL
	var r := Rect2(0, 0, Defs.w_px(kind), Defs.h_px(kind))
	var cases: Array[Array] = [
		[BossAi.Pattern.IDLE, []],
		[BossAi.Pattern.WINDUP, ["predict"]],
		[BossAi.Pattern.CHARGE, []],
		[BossAi.Pattern.STUN, ["ring"]],
	]
	for c: Array in cases:
		var v := _RecordingMonsterView.new()
		var m := Monster.new(1, kind, 0, 0)
		m.pattern = c[0]
		v._draw_pattern_indicator(m, r)
		t.eq(v.drawn, c[1], "패턴 값 %d일 때 그려지는 것 %s" % [c[0], c[1]])
		v.free()

	# The other side - a trash mob never draws either, whatever its (always-IDLE, unused) pattern is.
	var v2 := _RecordingMonsterView.new()
	var pig := Monster.new(2, Defs.KIND_PIG, 0, 0)
	v2._draw_pattern_indicator(pig, Rect2(0, 0, Defs.w_px(Defs.KIND_PIG), Defs.h_px(Defs.KIND_PIG)))
	t.eq(v2.drawn, [], "돼지는 패턴 표시를 아무것도 안 그린다")
	v2.free()


## **verify-read's hole ② — `_charge_blocked` never resetting is green today.** Every existing check watches
## only one cycle (the sequence check `break`s at the first close, the ledge check stops at 60 frames), so a
## deleted `_charge_blocked = false` (`monster.gd`, in `on_tick`) is invisible: the stale `true` would make
## *every later* charge collapse to one tick regardless of distance, the bull becoming (verify-run's words)
## "a twitching object". **A wall would only prove the first consumption** — after the first collision the
## bull sits flush against it, so a second charge in the same direction is legitimately short with or without
## the bug and cannot tell them apart. Seeded instead: `_charge_blocked` is set as if a first charge already
## collided (no wall needed for that part), consumed by the very next tick, and then a full second cycle runs
## on an **open** floor — nothing to legitimately block it — so a working reset reaches close to
## `charge_max_ticks` and a stuck one reaches exactly one tick, same shape as before.
func _charge_blocked_resets_between_cycles(t) -> void:
	var kind := Defs.KIND_BULL
	var g := _bare_grid()
	var stand_x := 1000
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(stand_x + 5000, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, FLOOR_TOP - Defs.h_px(kind))
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)

	m.pattern = BossAi.Pattern.CHARGE
	m.pattern_left = int(BossAi.MOVE_CHARGE["charge_max_ticks"])
	m._charge_blocked = true
	while not world.frame(DT, 0.0, false, false):
		pass
	t.eq(m.pattern, BossAi.Pattern.STUN, "심어둔 blocked가 다음 틱에 소비되어 stun으로 간다 (검사의 전제)")

	var seen_charge := false
	var charge_ticks := 0
	var ticks := 0
	var max_ticks := 200
	while ticks < max_ticks:
		if world.frame(DT, 0.0, false, false):
			ticks += 1
			if m.pattern == BossAi.Pattern.CHARGE:
				seen_charge = true
				charge_ticks += 1
			elif seen_charge:
				break
	t.ok(seen_charge, "두 번째 사이클도 charge에 들어간다 (검사의 전제)")
	var charge_max_ticks: int = BossAi.MOVE_CHARGE["charge_max_ticks"]
	t.ok(charge_ticks >= charge_max_ticks - 2,
		"벽 없는 두 번째 charge는 안전장치 근처까지 간다 (%d틱 — 1이면 blocked가 안 풀린 것)" % charge_ticks)


## **verify-read's hole ③ — the charge direction can be hardcoded to `+1` and both existing boss checks stay
## green**, because both park the player to the bull's right. "Runs straight at the player" (the design doc's
## own words) means direction must follow the player, not default to one side.
func _charge_direction_follows_the_player_left_too(t) -> void:
	var kind := Defs.KIND_BULL
	var g := _bare_grid()
	var stand_x := 5000
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(stand_x - 3000, FLOOR_TOP - Character.H_PX)  # to the LEFT this time
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, FLOOR_TOP - Defs.h_px(kind))
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)

	var x_at_charge_start := -1
	var ticks := 0
	var max_ticks := 100
	while ticks < max_ticks:
		if world.frame(DT, 0.0, false, false):
			ticks += 1
			if m.pattern == BossAi.Pattern.CHARGE:
				x_at_charge_start = m.x
				break
	t.eq(m.pattern, BossAi.Pattern.CHARGE, "왼쪽 플레이어를 향해서도 결국 charge에 들어간다 (검사의 전제)")
	t.eq(m.pattern_dir, -1,
		"플레이어가 왼쪽이면 방향도 왼쪽이다 (+1로 박아 놓으면 여기서 걸린다)")
	for _i in 6:
		world.frame(DT, 0.0, false, false)
	t.ok(m.x < x_at_charge_start,
		"실제로 왼쪽으로 움직였다 (%d -> %d)" % [x_at_charge_start, m.x])


## **verify-read's hole ④ — `speed_mult` always returning `1.0` is green today; nothing reads the value
## directly.** Provisional-and-unapproved (the design doc's own words for the 2x itself) is a different thing
## from unmeasured.
func _charge_speed_mult_is_read(t) -> void:
	t.eq(BossAi.speed_mult(Defs.KIND_BULL, BossAi.Pattern.CHARGE), 2.0,
		"charge 배속 = 2.0 (`MOVE_CHARGE.charge_speed_mult`에서 온다)")
	t.eq(BossAi.speed_mult(Defs.KIND_BULL, BossAi.Pattern.IDLE), 1.0,
		"idle 중엔 배속이 안 걸린다")
	t.eq(BossAi.speed_mult(Defs.KIND_HEN, BossAi.Pattern.CHARGE), 1.0,
		"패턴 없는 종류엔 배속 자체가 안 걸린다 (닭은 애초에 charge 상태가 될 일이 없다)")


## The behavioral half of ④ — confirms the multiplier reaches `Monster.step()`'s actual movement, not just
## the table function in isolation (a table that returns the right number wired to nothing would pass the
## check above and still fail this one).
func _charge_moves_at_the_charge_speed_not_walking_speed(t) -> void:
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
	# White-box straight into CHARGE - the windup/stun timing is covered elsewhere.
	m.pattern = BossAi.Pattern.CHARGE
	m.pattern_dir = 1
	m.pattern_left = int(BossAi.MOVE_CHARGE["charge_max_ticks"])

	var x0 := m.x
	world.frame(DT, 0.0, false, false)
	var moved := m.x - x0
	var walk_speed := Defs.speed_px(kind)
	var charge_speed := walk_speed * float(BossAi.MOVE_CHARGE["charge_speed_mult"])
	# One frame's worth, rounded the same way `Body.move_x` rounds (`roundi` on the accumulated `_rem_x`).
	t.eq(moved, roundi(charge_speed * DT),
		"charge 중 한 프레임 이동량이 2배속 값과 일치한다 (%dpx)" % moved)
	t.ok(moved > roundi(walk_speed * DT),
		"걷기 속도보다 빠르다 (걷기였다면 %dpx)" % roundi(walk_speed * DT))


# ==================================================================
#  stage1-bosses.md Stage C — the charge carves, only while charging
# ==================================================================

## The table value, by itself — the same "provisional is not the same as unmeasured" lesson Stage B's
## review pass left behind for `speed_mult`.
func _charge_carve_r_is_read(t) -> void:
	t.eq(BossAi.carve_r(Defs.KIND_BULL), 3, "황소 charge carve_r = 3")
	t.eq(BossAi.carve_r(Defs.KIND_HEN), 0, "패턴 없는 종류는 carve_r = 0 (호출자가 따로 has_pattern을 안 물어도 된다)")


## **Acceptance 2's positive half, and "fires once, not every tick" in the same test.** Reuses the same
## deterministic 200px-gap wall as the Stage B sequence test — that setup already proves the collision lands
## on a known tick, so this test only adds "and the grid changed there".
func _charge_impact_carves_the_wall(t) -> void:
	var kind := Defs.KIND_BULL
	var g := _bare_grid()
	var stand_x := 500
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var wall_left_px := stand_x + Defs.w_px(kind) + 200
	var wall_cx := wall_left_px / Tuning.CELL_PX
	g.apply(CellGrid.cmd_fill(wall_cx, FLOOR_CY - 30, wall_cx + 20, FLOOR_CY - 1, Mat.STONE))

	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(wall_left_px + 400, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)

	g.consume_changed()
	var ticks := 0
	var max_ticks := 100
	while ticks < max_ticks and m.pattern != BossAi.Pattern.STUN:
		if world.frame(DT, 0.0, false, false):
			ticks += 1
	t.eq(m.pattern, BossAi.Pattern.STUN, "충전이 벽에 막혀 stun으로 갔다 (검사의 전제)")

	var carved := g.consume_changed()
	t.ok(carved > 0, "충돌 지점이 실제로 파였다 (%d칸 바뀜)" % carved)
	var impact_cx := (m.x + Defs.w_px(kind)) / Tuning.CELL_PX
	var impact_cy := (m.y + Defs.h_px(kind) / 2) / Tuning.CELL_PX
	t.eq(g.mat_at(impact_cx, impact_cy), Mat.EMPTY,
		"충돌 지점 그 칸이 비었다 (%d,%d)" % [impact_cx, impact_cy])

	# **Fires once, not every tick while stunned** — the bull sits flush against the same wall for the whole
	#  `STUN` window; nothing should carve it again while it just stands there.
	g.consume_changed()
	var stun_ticks: int = BossAi.MOVE_CHARGE["stun_ticks"]
	for _i in (stun_ticks + 5) * Tuning.TICK_DIVIDER:
		world.frame(DT, 0.0, false, false)
	t.eq(g.consume_changed(), 0, "stun 동안 같은 자리를 또 파지 않는다")


## **Acceptance 2's negative half — "that second half is the whole of acceptance 2"** (the plan's own words).
## verify-run's own negative control, replicated here: an `IDLE` bull pinned against a wall stays blocked
## for 300 frames and `_charge_blocked` never goes true. **White-boxed to stay `IDLE`** (`pattern_left` set
## huge) — a naturally-spawned bull only stays `IDLE` for its first 1-2 frames before the first tick freezes
## it into `WINDUP` (`pattern_left` defaults to 0), too short a window to measure anything against.
func _idle_bull_blocked_by_a_wall_carves_nothing(t) -> void:
	var kind := Defs.KIND_BULL
	var g := _bare_grid()
	var wall_cx := 150
	g.apply(CellGrid.cmd_fill(wall_cx, FLOOR_CY - 30, wall_cx + 20, FLOOR_CY - 1, Mat.STONE))
	var wall_left_px := wall_cx * Tuning.CELL_PX

	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(wall_left_px + 400, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var stand_x := wall_left_px - 100
	var mid := world.spawn_monster(kind, stand_x, FLOOR_TOP - Defs.h_px(kind))
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	m.pattern_left = 100000

	g.consume_changed()
	for _i in 300:
		world.frame(DT, 0.0, false, false)
	t.ok(m.x >= wall_left_px - Defs.w_px(kind) - 4,
		"걸어서 벽까지 갔다 (검사의 전제, x=%d)" % m.x)
	t.eq(m.pattern, BossAi.Pattern.IDLE, "그동안 계속 idle이었다 (검사의 전제 - charge에 들어간 적이 없다)")
	t.ok(not m.charge_blocked_now(), "걷다가 막혀도 charge_blocked는 안 선다")
	t.eq(g.consume_changed(), 0, "충전이 아니면 막혀도 아무것도 안 판다")


## **Acceptance 8/5's shared measurement — "one measurement, not two"** (`stage1-bosses.md` Risk 3's own
## words). Room ①'s actual left boundary, measured by the plan: a 2-tile step = 16 cells thick
## (`Tuning.TILE_CELLS`=8), not a generic wall — a thin test wall would pass this trivially and prove
## nothing about the real risk. `carve_r`=3 must not reach the far face in one hit.
func _single_charge_does_not_breach_a_16cell_boundary(t) -> void:
	var kind := Defs.KIND_BULL
	var g := _bare_grid()
	var wall_cx := 150
	var wall_thickness := 16
	g.apply(CellGrid.cmd_fill(
		wall_cx, FLOOR_CY - 30, wall_cx + wall_thickness - 1, FLOOR_CY - 1, Mat.STONE))
	var wall_left_px := wall_cx * Tuning.CELL_PX

	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(wall_left_px + 3000, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var stand_x := wall_left_px - 300
	var mid := world.spawn_monster(kind, stand_x, FLOOR_TOP - Defs.h_px(kind))
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)

	var ticks := 0
	var max_ticks := 200
	while ticks < max_ticks and m.pattern != BossAi.Pattern.STUN:
		if world.frame(DT, 0.0, false, false):
			ticks += 1
	t.eq(m.pattern, BossAi.Pattern.STUN, "충전이 벽에 막혀 stun으로 갔다 (검사의 전제)")

	var impact_cy := (m.y + Defs.h_px(kind) / 2) / Tuning.CELL_PX
	var far_cx := wall_cx + wall_thickness - 1
	t.eq(g.mat_at(far_cx, impact_cy), Mat.STONE,
		"충돌 지점 같은 줄에서도 벽 반대편 끝(16칸 두께)은 안 뚫렸다 (%d,%d)" % [far_cx, impact_cy])
	# **verify-read's finding ⑤ — the far-face check alone passes for any `carve_r` in [1,6]**, not just 3.
	#  Pinned by the actual eaten count too, so raising the table value without also raising this number
	#  goes red here even while the far face is still untouched.
	var eaten := _count_stone_in_row(g, wall_cx, wall_cx + wall_thickness - 1, impact_cy)
	t.eq(wall_thickness - eaten, 4,
		"이번 충돌 한 번이 실제로 먹은 칸 수 (16칸 중 %d칸 남음)" % eaten)


## **verify-read's finding ② — the left/right off-by-one.** `_carve_charge_impact` used `m.x` (still inside
## the bull's own empty air) instead of `m.x - 1` (the wall's actual near face) for a leftward block —
## measured before the fix: right ate 4 cells, left only 3, same wall and radius. Fixed in `world_step.gd`;
## this measures both directions land on the same count, not just that each individually carves *something*
## (both existing carve tests parked the player to the bull's right, the same blind spot Stage B's own
## review already closed once, back in this same stage).
func _charge_impact_eats_the_same_cells_either_direction(t) -> void:
	var kind := Defs.KIND_BULL
	var wall_cx := 200
	var wall_thickness := 40
	var wall_cx1 := wall_cx + wall_thickness - 1
	var window := 10
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var impact_cy := floori(float(stand_y + Defs.h_px(kind) / 2) / float(Tuning.CELL_PX))
	var wall_left_px := wall_cx * Tuning.CELL_PX
	var wall_right_px := (wall_cx1 + 1) * Tuning.CELL_PX

	var g_r := _bare_grid()
	g_r.apply(CellGrid.cmd_fill(wall_cx, FLOOR_CY - 30, wall_cx1, FLOOR_CY - 1, Mat.STONE))
	var eaten_r := _charge_cycle_eaten_cells(kind, g_r, wall_left_px - 500, stand_y, wall_left_px + 5000,
		wall_cx - window, wall_cx + window, impact_cy, t)

	var g_l := _bare_grid()
	g_l.apply(CellGrid.cmd_fill(wall_cx, FLOOR_CY - 30, wall_cx1, FLOOR_CY - 1, Mat.STONE))
	var eaten_l := _charge_cycle_eaten_cells(kind, g_l, wall_right_px + 500, stand_y, wall_left_px - 5000,
		wall_cx1 - window, wall_cx1 + window, impact_cy, t)

	t.eq(eaten_r, 4, "오른쪽 충돌이 4칸 먹는다")
	t.eq(eaten_l, 4, "왼쪽 충돌도 4칸 먹는다 (오프바이원 고치기 전엔 3이었다)")
	t.eq(eaten_r, eaten_l, "좌우가 대칭이다")


## **verify-read's finding ① — accumulated destruction is structurally zero, and nothing said so.**
## Measured: `carve_r`=3 gives a disc 7 cells tall at its widest row, but the bull's own box (`h_px`=56 =
## 14 cells) needs all 14 rows clear to advance one more cell into the hole it just dug — 7 < 14, so it can
## never enter. Every cycle after the first re-carves the same already-empty disc. **This is the design's
## actual behaviour, decided (not re-opened here)**: `stage1-bosses.md`'s Risk/TBD section now states the
## `h_px`/`carve_r` relation and the measured `r`=6→no accumulation / `r`=7→breaches in ~9 charges cliff, in
## place of the doc's old "the room's shape changes as you fight" line, which this measurement disproves as
## written (it changes once, at the first ram, never again). This test is the check that would notice if
## that stopped being true — nobody currently would.
func _charge_destruction_does_not_accumulate_across_cycles(t) -> void:
	var kind := Defs.KIND_BULL
	var wall_cx := 200
	var wall_thickness := 40
	var window := 10
	var g := _bare_grid()
	g.apply(CellGrid.cmd_fill(wall_cx, FLOOR_CY - 30, wall_cx + wall_thickness - 1, FLOOR_CY - 1, Mat.STONE))
	var wall_left_px := wall_cx * Tuning.CELL_PX
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var impact_cy := floori(float(stand_y + Defs.h_px(kind) / 2) / float(Tuning.CELL_PX))

	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(wall_left_px + 5000, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, wall_left_px - 500, stand_y)
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)

	# First cycle - the only one expected to change anything.
	var before_first := _count_stone_in_row(g, wall_cx - window, wall_cx + window, impact_cy)
	var ticks := 0
	while ticks < 200 and m.pattern != BossAi.Pattern.STUN:
		if world.frame(DT, 0.0, false, false):
			ticks += 1
	t.eq(m.pattern, BossAi.Pattern.STUN, "첫 충돌로 stun에 들어갔다 (검사의 전제)")
	var eaten_first := before_first - _count_stone_in_row(g, wall_cx - window, wall_cx + window, impact_cy)
	t.eq(eaten_first, 4, "첫 충돌은 4칸을 먹는다 (검사의 전제)")

	# **A fixed, generous tick budget, not cycle-transition detection** — with the bull already sitting flush
	#  against the wall, every later charge travels ~0px, so a cycle is roughly idle(21)+windup(17)+charge(a
	#  handful)+stun(25) ticks ≈ 65. 300 ticks covers 3+ full cycles with margin either way.
	#  **Stage D's round-robin means not every one of those cycles is a charge** — every other one is a fire
	#  breath instead, which carves nothing at all, so this assertion holds for both reasons at once (a charge
	#  into an already-cleared spot still can't enter it; a breath was never going to carve in the first place).
	var before_more := _count_stone_in_row(g, wall_cx - window, wall_cx + window, impact_cy)
	for _i in 300:
		world.frame(DT, 0.0, false, false)
	t.eq(_count_stone_in_row(g, wall_cx - window, wall_cx + window, impact_cy), before_more,
		"그 뒤로는 한 칸도 더 못 먹는다 (누적 침식이 없다 - 7칸 구멍에 14칸 몸이 못 들어간다, m=%s)" % m.pattern)


