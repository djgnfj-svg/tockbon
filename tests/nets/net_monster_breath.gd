extends RefCounted
## Monster boss stages D/E/F -- the bull's fire breath, its gore/charge contact damage, and the rooster's leap.
##  Split out of net_monster.gd, same round and same reason as net_monster_charge.gd (its header carries the
##  full measured rationale -- not repeated here).
##
## **Grouped by profiled time**: Stage D + Stage E + Stage F summed to ~3.02s of check-body time.
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
## draw call ran without needing a real canvas (`_draw_telegraph`/`_draw_stun_ring` both draw onto `self`
## directly, so recording in an override is the whole trick — no shader, no child layer, no scene needed).
## `docs/design/attack-prediction.md` replaced the "!" telegraph — the override below records `"predict"`,
## not the retired `"telegraph"` string, so the two never drift apart.
class _RecordingMonsterView extends MonsterView:
	var drawn: Array[String] = []

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
	# -- stage1-bosses.md Stage D -- the fire breath --
	_fire_move_values_are_read(t)
	_fire_bolt_hits_wood_and_wood_burns(t)
	_fire_ignite_reaches_exactly_its_radius(t)
	_ignite_settles_after_this_ticks_grid_step(t)
	_fire_bolt_vanishes_at_its_range(t)
	_fire_bolt_passes_over_stone_and_leaves_nothing(t)
	_fire_bolt_hurts_the_player_with_its_own_damage(t)
	_bull_cannot_be_hit_by_its_own_bolts(t)
	_bull_burns_in_its_own_terrain_fire(t)
	# -- stage1-bosses.md Stage E -- gore, and charge contact damage --
	_gore_and_contact_values_are_read(t)
	_player_above_does_not_disable_the_bull(t)
	_close_player_gets_gored_not_charged(t)
	_far_player_still_gets_a_real_charge(t)
	_gore_hits_the_player_with_its_own_damage(t)
	_charge_contact_hurts_the_player(t)
	_gore_range_boundary_is_exactly_120px(t)
	_gore_does_not_consume_the_fire_turn(t)
	_touching_an_idle_bull_does_not_hurt(t)
	# -- stage1-bosses.md Stage F -- the rooster leaps, pounces, lands --
	_leap_values_are_read(t)
	_leap_moves_at_the_leap_speed_not_walking_speed(t)
	_rooster_pattern_sequence_is_idle_windup_leap_stun_idle(t)
	_leap_with_no_floor_ends_via_the_safety_cap(t)
	_leap_direction_follows_the_player_left_too(t)
	_second_cycle_is_fire_breath_and_it_fires_locked_bolts(t)
	_bolt_kind_is_wired_to_the_screen(t)
	_bolt_color_differs_by_kind(t)


# ==================================================================
#  stage1-bosses.md Stage D — the fire breath
# ==================================================================

## The table/bolt values, by themselves — the same "provisional is not the same as unmeasured" lesson
## Stage B/C's review passes left behind for `speed_mult`/`carve_r`.
func _fire_move_values_are_read(t) -> void:
	t.eq(BossAi.fire_reload_ticks(Defs.KIND_BULL), 6, "황소 fire reload_ticks = 6")
	t.eq(BossAi.fire_reload_ticks(Defs.KIND_HEN), 0, "패턴 없는 종류는 fire_reload_ticks = 0")
	t.eq(MonsterBolts.FIRE_DAMAGE, 8, "fire bolt 데미지 = 8")
	t.eq(MonsterBolts.FIRE_IGNITE_R, 2, "fire bolt 점화 반경 = 2")
	t.ok(MonsterBolts.FIRE_DAMAGE != MonsterBolts.BOLT_DAMAGE,
		"fire 데미지가 닭의 것과 다르다 (%d ≠ %d)" % [MonsterBolts.FIRE_DAMAGE, MonsterBolts.BOLT_DAMAGE])


## **Acceptance 4's positive half, and Risk 4's own escape hatch — measured on a wooded scene, not room ①**
## (`_ignite_cell` refuses at zero fuel, and room ① has none by design, Risk 4). The bolt is made directly
## (`world._bolts.spawn`, the same idiom `_hen_bolt_hits_only_the_player` already uses) — the pattern cycle
## that would naturally fire one is measured on its own, further down.
##
## `world_step`'s tick branch turns a fire bolt's terrain impact into `cmd_ignite` **one tick after** the
## impact frame (that file's own comment on why — the same door the charge's carve uses), so the loop below
## must run at least one full tick past the collision, not stop the instant the bolt disappears.
func _fire_bolt_hits_wood_and_wood_burns(t) -> void:
	var g := _bare_grid()
	var wood_cx := 100
	var wood_cy := FLOOR_CY - 10
	g.apply(CellGrid.cmd_fill(wood_cx, wood_cy - 2, wood_cx + 3, wood_cy + 2, Mat.WOOD))
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(5000, FLOOR_TOP - Character.H_PX)  # far away and uninvolved
	var world := WorldStep.new(g, spell, ch)
	var bolts: MonsterBolts = world.get("_bolts")
	var row_y := float(wood_cy * Tuning.CELL_PX + Tuning.CELL_PX / 2)
	var origin_x := float((wood_cx - 20) * Tuning.CELL_PX)
	t.ok(bolts.spawn(origin_x, row_y, Vector2(1.0, 0.0), MonsterBolts.KIND_FIRE),
		"fire 탄을 직접 쐈다 (검사의 전제)")

	for _i in 90:
		world.frame(DT, 0.0, false, false)

	t.ok(g.is_burning(wood_cx, wood_cy), "나무가 실제로 붙었다 (%d,%d)" % [wood_cx, wood_cy])


## **verify-read's finding ② — the ignite radius was never measured.** Leaving `FIRE_IGNITE_R` at 2 in the
## table while hardcoding the consumer to a different number was green (the `carve_r` hole from Stage C,
## verbatim). Wood is placed **only to the right** of the impact column, so the bolt (approaching from the
## left) hits the *first* solid cell it reaches and that cell's own x becomes the disc's known centre — cells
## further right than `FIRE_IGNITE_R` must stay unlit, not just "the far face of some wall" (Stage C's
## `_single_charge_does_not_breach_a_16cell_boundary` pattern, applied to the door `_disc` shares with carve).
func _fire_ignite_reaches_exactly_its_radius(t) -> void:
	var g := _bare_grid()
	var impact_cx := 100
	var wood_cy := FLOOR_CY - 10
	g.apply(CellGrid.cmd_fill(impact_cx, wood_cy, impact_cx + 10, wood_cy, Mat.WOOD))
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(5000, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var bolts: MonsterBolts = world.get("_bolts")
	var row_y := float(wood_cy * Tuning.CELL_PX + Tuning.CELL_PX / 2)
	var origin_x := float((impact_cx - 20) * Tuning.CELL_PX)
	t.ok(bolts.spawn(origin_x, row_y, Vector2(1.0, 0.0), MonsterBolts.KIND_FIRE),
		"fire 탄을 직접 쐈다 (검사의 전제)")

	# **Stop the instant ignition first shows, not one tick later** — contiguous wood lets fire *spread*
	#  (`cell_grid._burn`'s own spread pass, a completely different mechanism from the disc `_ignite_cell`
	#  reaches in one shot at ignition time) one more cell per tick it keeps running. Measured: running 90
	#  frames (30 ticks) here let spread alone carry it out to +5, well past `FIRE_IGNITE_R`=2, and read as
	#  "the radius is bigger than it is." The disc's own reach is what this test measures, so it must read
	#  the board before `_burn()` gets a second tick to touch it.
	var ticks := 0
	var max_ticks := 60
	while ticks < max_ticks and not g.is_burning(impact_cx, wood_cy):
		if world.frame(DT, 0.0, false, false):
			ticks += 1
	t.ok(g.is_burning(impact_cx, wood_cy), "충돌점이 실제로 붙었다 (검사의 전제)")

	var r := MonsterBolts.FIRE_IGNITE_R
	for d in range(0, r + 1):
		t.ok(g.is_burning(impact_cx + d, wood_cy), "충돌점에서 %d칸까지는 붙는다 (%d,%d)" % [d, impact_cx + d, wood_cy])
	for d in [r + 1, r + 2, r + 3]:
		t.ok(not g.is_burning(impact_cx + d, wood_cy),
			"충돌점에서 %d칸(반경 %d 밖)은 안 붙는다 (아직 퍼질 틱이 없었다, %d,%d)" % [d, r, impact_cx + d, wood_cy])


## **verify-read's finding ③ — the "settles one tick after `_grid.step()`" contract was a comment, not a
## check.** Measured through `aux_at` (remaining fuel, `cell_grid._ignite_cell` writes the material's full,
## untouched fuel there) rather than `is_burning` alone, because `is_burning` cannot tell "just lit, zero
## `_burn()` passes applied" from "lit one tick ago, one pass already applied" — both read `true`. Wood's
## fuel is 200 (`cell_materials.gd`) and `_burn()` shaves `Tuning.FIRE_BURN_PER_TICK`(5) per tick a cell was
## *already* burning when that tick's pass started. **If the ignite-drain moved to before `_grid.step()`**
## (the mutation this guards against), the same tick's own `_grid.step()` would already process the
## newly-lit cell once, and `aux_at` would read 195, not 200, on the very tick it first shows `is_burning`.
func _ignite_settles_after_this_ticks_grid_step(t) -> void:
	var g := _bare_grid()
	var wood_cx := 100
	var wood_cy := FLOOR_CY - 10
	g.apply(CellGrid.cmd_fill(wood_cx, wood_cy, wood_cx, wood_cy, Mat.WOOD))
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(5000, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var bolts: MonsterBolts = world.get("_bolts")
	var row_y := float(wood_cy * Tuning.CELL_PX + Tuning.CELL_PX / 2)
	var origin_x := float((wood_cx - 20) * Tuning.CELL_PX)
	t.ok(bolts.spawn(origin_x, row_y, Vector2(1.0, 0.0), MonsterBolts.KIND_FIRE),
		"fire 탄을 직접 쐈다 (검사의 전제)")

	var lit_tick := -1
	var ticks := 0
	var max_ticks := 60
	while ticks < max_ticks and lit_tick < 0:
		if world.frame(DT, 0.0, false, false):
			ticks += 1
			if g.is_burning(wood_cx, wood_cy):
				lit_tick = ticks
	t.ok(lit_tick > 0, "나무가 실제로 붙었다 (검사의 전제)")
	t.eq(g.aux_at(wood_cx, wood_cy), 200,
		"막 붙은 바로 그 틱엔 연료가 그대로 200이다 (이 틱의 grid.step()이 이미 지나간 뒤에 붙었다는 뜻)")

	world.frame(DT, 0.0, false, false)
	world.frame(DT, 0.0, false, false)
	world.frame(DT, 0.0, false, false)  # exactly one more tick (TICK_DIVIDER frames)
	t.eq(g.aux_at(wood_cx, wood_cy), 200 - Tuning.FIRE_BURN_PER_TICK,
		"한 틱 지나면 정확히 %d만큼 준다 (%d)" % [Tuning.FIRE_BURN_PER_TICK, 200 - Tuning.FIRE_BURN_PER_TICK])


## **verify-read's finding ② — fire's own range was never measured**, only inherited from `BOLT_STOP_PX`/
## `BOLT_RANGE_PX` (shared with the hen by `monster_bolts.gd`'s own comment on the reuse). A mutation that
## made fire bolts ignore `BOLT_RANGE_PX` entirely (fly forever) was green. Measured directly in open air —
## no terrain anywhere in its path, so only the lifetime axis can end it.
func _fire_bolt_vanishes_at_its_range(t) -> void:
	var g := _bare_grid()
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(20000, FLOOR_TOP - Character.H_PX)  # far away - never intercepts
	var world := WorldStep.new(g, spell, ch)
	var bolts: MonsterBolts = world.get("_bolts")
	var origin_x := 100.0
	var row_y := float(FLOOR_TOP - 200)  # well above the floor - nothing solid anywhere along its path
	t.ok(bolts.spawn(origin_x, row_y, Vector2(1.0, 0.0), MonsterBolts.KIND_FIRE),
		"fire 탄을 연 하늘에 쐈다 (검사의 전제)")

	var last_x := origin_x
	var frames := 0
	while bolts.count() > 0 and frames < 600:
		last_x = bolts.x(0)
		world.frame(DT, 0.0, false, false)
		frames += 1
	t.eq(bolts.count(), 0, "결국 사라진다 (검사의 전제 - 무한 비행이면 여기서 안 잡히고 600프레임을 다 돈다)")
	# One frame's slack either side - `last_x` is read *before* the frame that removes it, so the true
	#  vanish point is up to one step further than `last_x` already shows.
	var step_cap := ceili(MonsterBolts.BOLT_SPEED_PX * DT)
	t.ok(absf((last_x - origin_x) - MonsterBolts.BOLT_RANGE_PX) <= float(step_cap * 2),
		"BOLT_RANGE_PX(%dpx) 근처에서 사라진다 (사라지기 직전 이동 거리 %dpx)"
			% [int(MonsterBolts.BOLT_RANGE_PX), int(last_x - origin_x)])


## Acceptance 2's own wording, reused for fire: "bolts pass over stone and leave nothing". Stone has zero
## fuel (`_ignite_cell`'s own refusal), so the ignite notification still fires and `cmd_ignite` still gets
## applied — it is a genuine no-op there, not a bolt that is smart enough to skip stone. Measuring the
## no-op (not just "no error") is the point.
func _fire_bolt_passes_over_stone_and_leaves_nothing(t) -> void:
	var g := _bare_grid()
	var stone_cx := 100
	var stone_cy := FLOOR_CY - 10
	g.apply(CellGrid.cmd_fill(stone_cx, stone_cy - 2, stone_cx + 3, stone_cy + 2, Mat.STONE))
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(5000, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var bolts: MonsterBolts = world.get("_bolts")
	var row_y := float(stone_cy * Tuning.CELL_PX + Tuning.CELL_PX / 2)
	var origin_x := float((stone_cx - 20) * Tuning.CELL_PX)
	t.ok(bolts.spawn(origin_x, row_y, Vector2(1.0, 0.0), MonsterBolts.KIND_FIRE),
		"fire 탄을 직접 쐈다 (검사의 전제)")

	for _i in 90:
		world.frame(DT, 0.0, false, false)

	t.ok(not g.is_burning(stone_cx, stone_cy), "돌은 안 붙는다 (%d,%d)" % [stone_cx, stone_cy])
	t.eq(g.mat_at(stone_cx, stone_cy), Mat.STONE, "재질도 그대로 돌이다 (아무 흔적이 안 남는다)")


## **Risk 4's load-bearing consequence, measured by value** — "the fire bolt must hurt the player by itself",
## because room ①'s own fire has nothing to ignite (no wood there by design, rule 6) and would otherwise be
## a completely inert attack in the only room it is used in.
func _fire_bolt_hurts_the_player_with_its_own_damage(t) -> void:
	var g := _bare_grid()
	var spell := SpellSim.new()
	var ch := Character.new()
	var row_y := FLOOR_TOP - Character.H_PX * 0.5
	ch.place(400, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var bolts: MonsterBolts = world.get("_bolts")
	t.ok(bolts.spawn(80.0, row_y, Vector2(1.0, 0.0), MonsterBolts.KIND_FIRE),
		"fire 탄을 직접 쐈다 (검사의 전제)")

	for _i in 90:
		world.frame(DT, 0.0, false, false)
		if ch.hp < Character.MAX_HP:
			break

	t.eq(ch.hp, Character.MAX_HP - MonsterBolts.FIRE_DAMAGE,
		"플레이어는 정확히 %d 맞는다 (닭의 %d가 아니다)" % [MonsterBolts.FIRE_DAMAGE, MonsterBolts.BOLT_DAMAGE])


## **Acceptance 15 — "free, the bolts do not know monsters exist"** (the plan's own words), measured rather
## than taken on faith: a fire bolt is spawned flush through the bull's own box, and its hp is unchanged.
## `consume_hits` only ever tests against the player's box (`Character`), never `_monsters` — this is the
## same detour `monster_bolts.gd`'s own header names for the hen ("leave it as is and the hen's bolt hits
## the hen"), extended to the bull without reopening it.
## **Narrowed on purpose (verify-run's finding ④, decided) — this measures only "cannot be hit by its own
## bolts", not "never hit by its own fire".** The bull is *not* exempt from standing in its own breath's
## terrain fire (`_bull_burns_in_its_own_terrain_fire` below measures that half, kept as real, decided
## behaviour) — only the bolt-collision path is exempt, structurally, because `consume_hits(ch: Character)`
## never looks at `_monsters` at all (the same detour this file's own header names for the hen, extended
## without reopening it).
func _bull_cannot_be_hit_by_its_own_bolts(t) -> void:
	var kind := Defs.KIND_BULL
	var g := _bare_grid()
	var stand_x := 500
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(5000, FLOOR_TOP - Character.H_PX)  # far away - the player never gets hit here, only the bull
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	var hp0 := m.hp
	var bolts: MonsterBolts = world.get("_bolts")
	# Spawned centred on the bull's own box, travelling through it.
	var row_y := float(stand_y) + Defs.h_px(kind) * 0.5
	t.ok(bolts.spawn(float(stand_x) + Defs.w_px(kind) * 0.5, row_y, Vector2(1.0, 0.0), MonsterBolts.KIND_FIRE),
		"fire 탄을 황소 몸 한복판에서 쐈다 (검사의 전제)")

	for _i in 90:
		world.frame(DT, 0.0, false, false)

	t.eq(m.hp, hp0, "황소는 제가 쏜 탄에는 안 맞는다 (탄 충돌만 - 지형 불은 다른 이야기다)")


## **Kept, decided by the user (verify-run's finding) — the bull burns in its own terrain fire.** Only the
## bolt-collision path is exempt (the check above); `monster._burn`/`Body.standing_in_fire` apply to every
## kind identically (no per-kind damage axis, `stage1-bosses.md`'s own header), so nothing carves out an
## exception for the monster that lit the fire — "the world reacts" (the design's own thesis) does not stop
## at the bull. Unreachable in room ① (no fuel there by design), reachable anywhere wood exists — and since
## the bull's own default `IDLE` behaviour is walking toward the player, **walking into its own leftover
## fire is its default behaviour**, not a bug. Same idiom as `_monster_burns_regardless_of_invuln` (a pig).
func _bull_burns_in_its_own_terrain_fire(t) -> void:
	var kind := Defs.KIND_BULL
	var g := _bare_grid()
	var stand_x := 600
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var cx0 := floori(stand_x / float(Tuning.CELL_PX))
	var cx1 := floori((stand_x + Defs.w_px(kind) - 1) / float(Tuning.CELL_PX))
	g.apply(CellGrid.cmd_fill(cx0 - 2, FLOOR_CY, cx1 + 2, FLOOR_CY, Mat.WOOD))
	var spell := SpellSim.new()
	var ch := _still_ch(stand_x, kind)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	var hp0 := m.hp

	var lit := 0
	for cx in range(cx0, cx1 + 1):
		if g.ignite(cx, FLOOR_CY):
			lit += 1
	t.ok(lit > 0, "발밑 나무에 불이 붙었다 (검사의 전제, %d칸)" % lit)

	for _i in 60:
		world.frame(DT, 0.0, false, false)
	t.ok(m.hp < hp0, "황소도 제 발밑 불에는 깎인다 (%d -> %d, 자기 탄에만 안 맞을 뿐이다)" % [hp0, m.hp])


# ==================================================================
#  stage1-bosses.md Stage E — gore, and charge contact damage
# ==================================================================

## The table/damage values, by themselves — the same "provisional is not the same as unmeasured" lesson
## Stages B-D's review passes left behind.
func _gore_and_contact_values_are_read(t) -> void:
	t.eq(BossAi.gore_range_px(Defs.KIND_BULL), 120.0, "황소 gore 사거리 = 120px")
	t.eq(BossAi.gore_range_px(Defs.KIND_HEN), 0.0, "패턴 없는 종류는 gore 사거리 = 0")
	t.eq(WorldStep.BULL_GORE_DAMAGE, 15, "gore 데미지 = 15")
	t.eq(WorldStep.BULL_CHARGE_CONTACT_DAMAGE, 20, "돌진 접촉 데미지 = 20")
	t.ok(WorldStep.BULL_GORE_DAMAGE != WorldStep.BULL_CHARGE_CONTACT_DAMAGE, "gore와 돌진 접촉 데미지가 다르다")
	t.ok(WorldStep.BULL_GORE_DAMAGE != Defs.melee_damage(Defs.KIND_PIG),
		"gore 데미지가 돼지 근접과 다르다")


## **verify-read's finding ① — a player on a ledge above the bull used to disable it completely.**
## `_dist_to_target` is horizontal only, and the gore gate originally used only that: a player close
## horizontally but far vertically still won the gate every time; gore's boxes never actually overlapped so
## it dealt nothing; and because gore always won, the bull never charged, never rammed, never carved, and
## never opened a stun window — the entire "ram it, stun it, hit it in the gap" loop this boss *is*
## disappeared. Measured with the exact repro: close horizontally (60px), far vertically (400px) — the bull
## must still get a real `CHARGE`, not a gore that can never land.
func _player_above_does_not_disable_the_bull(t) -> void:
	var kind := Defs.KIND_BULL
	var g := _bare_grid()
	var stand_x := 5000
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var spell := SpellSim.new()
	var ch := Character.new()
	var bull_center_x := float(stand_x) + Defs.w_px(kind) * 0.5
	# 60px across (well inside the horizontal gore gate) but 400px up - nowhere near the bull's box vertically.
	ch.place(roundi(bull_center_x + 60.0 - Character.W_PX * 0.5), FLOOR_TOP - Character.H_PX - 400)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)

	var ticks := 0
	var max_ticks := 60
	while ticks < max_ticks and (m.pattern == BossAi.Pattern.IDLE or m.pattern == BossAi.Pattern.WINDUP):
		if world.frame(DT, 0.0, false, false):
			ticks += 1
	t.eq(m.pattern, BossAi.Pattern.CHARGE,
		"수평으로만 가까우면 gore가 아니라 진짜 charge로 들어간다 (세로로 안 닿으면 gore가 아니다)")


## **verify-read's own warning, applied before it had to be found the hard way**: "a contact hit and the
## damage that follows it are two mechanisms" — this test measures only the **selection** (does gore replace
## charge when close), not damage. `_gore_hits_the_player_with_its_own_damage` below measures the second
## mechanism separately. **Not moving during the active state is its own assertion** — gore freezes
## (`Monster._boss_axis`), a charge would not, so "it didn't move" is independent evidence it is really gore
## and not a charge that happened to start with zero distance to travel.
func _close_player_gets_gored_not_charged(t) -> void:
	var kind := Defs.KIND_BULL
	var g := _bare_grid()
	var stand_x := 5000
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var spell := SpellSim.new()
	var ch := Character.new()
	var bull_center_x := float(stand_x) + Defs.w_px(kind) * 0.5
	# 60px center-to-center - well inside `gore_range_px`(120), well outside actual box contact (so this is
	# measuring the *range gate*, not "it happens to already be touching").
	ch.place(roundi(bull_center_x + 60.0 - Character.W_PX * 0.5), FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)

	var ticks := 0
	var max_ticks := 60
	while ticks < max_ticks and (m.pattern == BossAi.Pattern.IDLE or m.pattern == BossAi.Pattern.WINDUP):
		if world.frame(DT, 0.0, false, false):
			ticks += 1
	t.eq(m.pattern, BossAi.Pattern.GORE,
		"가까이 있으면 charge 대신 gore로 들어간다 (charge는 gore 사거리 안에서 발동하지 않는다)")

	var x_at_gore_start := m.x
	for _i in 10:
		world.frame(DT, 0.0, false, false)
	t.eq(m.x, x_at_gore_start, "gore 동안 한 픽셀도 움직이지 않는다 (charge라면 움직였을 것이다)")


## The negative control for the test above — far enough away, the same bull picks the same move
## (`move_choice` round-robin is unaffected by range) and it resolves to a real `CHARGE`, not `GORE`.
## Without this, a mutation that always substitutes gore (deleting the range check) would not be caught by
## `_close_player_gets_gored_not_charged` alone — that test never proves gore is *conditional*.
func _far_player_still_gets_a_real_charge(t) -> void:
	var kind := Defs.KIND_BULL
	var g := _bare_grid()
	var stand_x := 5000
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var spell := SpellSim.new()
	var ch := Character.new()
	# **Not +3000** — verify-read measured `_bare_grid()`'s floor now ends at `FLOOR_W_CX`(2000 cells =
	#  8000px); stand_x(5000)+3000 = 8000 landed exactly past the edge and the player free-fell during the
	#  check (harmless there since only `m.pattern` is read, but the stated "far outside gore range" premise
	#  was false). +2000 stays safely on solid ground and still far outside `gore_range_px`(120).
	ch.place(stand_x + 2000, FLOOR_TOP - Character.H_PX)  # far outside gore range
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)

	var ticks := 0
	var max_ticks := 60
	while ticks < max_ticks and (m.pattern == BossAi.Pattern.IDLE or m.pattern == BossAi.Pattern.WINDUP):
		if world.frame(DT, 0.0, false, false):
			ticks += 1
	t.eq(m.pattern, BossAi.Pattern.CHARGE, "멀리 있으면 그대로 charge로 들어간다 (gore로 안 바뀐다)")


## The other mechanism — gore's own contact damage, measured on its own (the box above only proved the
## *pattern*, not that standing in gore range and getting gored actually hurts).
func _gore_hits_the_player_with_its_own_damage(t) -> void:
	var kind := Defs.KIND_BULL
	var g := _bare_grid()
	var stand_x := 5000
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var spell := SpellSim.new()
	var ch := Character.new()
	var bull_center_x := float(stand_x) + Defs.w_px(kind) * 0.5
	# Close enough to be gored *and* to actually overlap the box once the swing starts - the range gate
	# (60px) and the contact box are two different thresholds, and this test needs both satisfied.
	ch.place(roundi(bull_center_x - Character.W_PX * 0.5), FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	var hp0 := ch.hp

	var ticks := 0
	var max_ticks := 200
	while ticks < max_ticks and m.pattern != BossAi.Pattern.GORE:
		if world.frame(DT, 0.0, false, false):
			ticks += 1
	t.eq(m.pattern, BossAi.Pattern.GORE, "gore에 들어갔다 (검사의 전제)")

	for _i in 90:
		world.frame(DT, 0.0, false, false)
		if ch.hp < hp0:
			break
	t.eq(ch.hp, hp0 - WorldStep.BULL_GORE_DAMAGE, "정확히 gore 데미지만큼 맞는다 (%d)" % WorldStep.BULL_GORE_DAMAGE)


## **Stage B's own review scope hole, closed here** — a charging bull used to pass straight through the
## player untouched (no contact path existed for `CHARGE` at all). Open floor, player placed well outside
## gore range but directly in the charge's locked path, so the charge actually launches (not gore) and its
## box sweeps through the player's as it runs.
##
## **verify-read's finding — one pass costs 40, not 20.** The combined half-widths (bull 88px + player 20px
## = 108px) at 280px/s charge speed cross in ~7.7 ticks (`108/280*20`); `Character`'s invulnerability
## (4 ticks, effective 5-tick interval — the same arithmetic `PIG_CONTACT_DAMAGE`'s own comment already
## walks through) fits **two** hits inside that window, not one. **Kept as the real behaviour** — a charge
## costing more than a graze is right, and the number is provisional either way. What had to change is the
## check: it used to `break` at the *first* hit and assert `hp0 - 20`, so its own label claimed "exactly the
## charge contact damage" while the real cost of standing in the path was double. This measures the **whole
## pass** (every hp drop while the charge runs, not just the first) instead.
func _charge_contact_hurts_the_player(t) -> void:
	var kind := Defs.KIND_BULL
	var g := _bare_grid()
	var stand_x := 5000
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(stand_x + 300, FLOOR_TOP - Character.H_PX)  # outside gore range, inside the charge's path
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	var hp0 := ch.hp

	var hits := 0
	var prev_hp := ch.hp
	var ticks := 0
	var max_ticks := 200
	while ticks < max_ticks and m.pattern != BossAi.Pattern.STUN:
		if world.frame(DT, 0.0, false, false):
			ticks += 1
			if ch.hp < prev_hp:
				hits += 1
				prev_hp = ch.hp
	t.eq(m.pattern, BossAi.Pattern.STUN, "돌진 한 패스가 끝났다 (검사의 전제 - stun까지 갔다, gore가 아니었다)")
	t.eq(hits, 2, "한 패스 동안 정확히 두 번 맞는다 (겹침 구간 ~7.7틱에 무적 4틱짜리가 두 번 들어간다)")
	t.eq(hp0 - ch.hp, 2 * WorldStep.BULL_CHARGE_CONTACT_DAMAGE,
		"한 패스 총 피해는 접촉 데미지의 두 배다 (%d — 첫 타만 재면 %d로 착각한다)"
			% [2 * WorldStep.BULL_CHARGE_CONTACT_DAMAGE, WorldStep.BULL_CHARGE_CONTACT_DAMAGE])


## **verify-read's finding ③ — the range value itself was unmeasured, only that *some* gate exists.**
## Deleting the gate broke 18 checks, but hardcoding `range_px` to a different number than the table's 120
## was still green — the `carve_r`/`FIRE_IGNITE_R` hole (Risk 3/Stage D), a third time. Pinned at both sides
## of the boundary directly, not at the two arbitrary distances (60px, 300px) the other tests happen to use.
func _gore_range_boundary_is_exactly_120px(t) -> void:
	var r := BossAi.gore_range_px(Defs.KIND_BULL)
	t.eq(r, 120.0, "황소 gore 사거리 = 120px (검사의 전제)")
	var results := {}
	for the_case: String in ["just_inside", "just_outside"]:
		var kind := Defs.KIND_BULL
		var g := _bare_grid()
		var stand_x := 5000
		var stand_y := FLOOR_TOP - Defs.h_px(kind)
		var spell := SpellSim.new()
		var ch := Character.new()
		var bull_center_x := float(stand_x) + Defs.w_px(kind) * 0.5
		# **±10px margin, not ±1** — a fresh spawn's `pattern_left` starts at 0, so it walks toward the
		#  player (brainless-forward `IDLE`) for the 1-2 frames before its first tick freezes it into
		#  `WINDUP` (the same "idle-creep" `_bull_pattern_sequence_is_idle_windup_charge_stun_idle` already
		#  named in Stage B). That creep (~2-5px at `speed_px`=140) would erase a ±1px margin and put
		#  "just outside" back inside the gate by the time `WINDUP` reads the distance.
		var offset := r - 10.0 if the_case == "just_inside" else r + 10.0
		ch.place(roundi(bull_center_x + offset - Character.W_PX * 0.5), FLOOR_TOP - Character.H_PX)
		var world := WorldStep.new(g, spell, ch)
		var mid := world.spawn_monster(kind, stand_x, stand_y)
		t.ok(mid > 0, "황소 스폰됐다 (%s, 검사의 전제)" % the_case)
		var m: Monster = world.monster_at(0)
		var ticks := 0
		var max_ticks := 60
		while ticks < max_ticks and (m.pattern == BossAi.Pattern.IDLE or m.pattern == BossAi.Pattern.WINDUP):
			if world.frame(DT, 0.0, false, false):
				ticks += 1
		results[the_case] = m.pattern
	t.eq(results["just_inside"], BossAi.Pattern.GORE, "경계 안쪽(110px)은 gore다")
	t.eq(results["just_outside"], BossAi.Pattern.CHARGE, "경계 바깥쪽(130px)은 charge다")


## **verify-read's finding ④ — "substitution doesn't disturb the rotation" was argued in a comment
## (`boss_ai.gd`), never measured.** After a gore (which happened because the round-robin picked `CHARGE`
## and gore replaced it), the *next* pick must be `FIRE` — proving `move_choice` stayed `CHARGE` through the
## substitution rather than being consumed as if gore were its own turn in the rotation.
func _gore_does_not_consume_the_fire_turn(t) -> void:
	var kind := Defs.KIND_BULL
	var g := _bare_grid()
	var stand_x := 5000
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var spell := SpellSim.new()
	var ch := Character.new()
	var bull_center_x := float(stand_x) + Defs.w_px(kind) * 0.5
	ch.place(roundi(bull_center_x + 60.0 - Character.W_PX * 0.5), FLOOR_TOP - Character.H_PX)  # inside gore range
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "황소 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)

	var ticks := 0
	var max_ticks := 60
	while ticks < max_ticks and (m.pattern == BossAi.Pattern.IDLE or m.pattern == BossAi.Pattern.WINDUP):
		if world.frame(DT, 0.0, false, false):
			ticks += 1
	t.eq(m.pattern, BossAi.Pattern.GORE, "gore가 발동했다 (검사의 전제)")

	ticks = 0
	max_ticks = 200
	while ticks < max_ticks and (m.pattern == BossAi.Pattern.GORE or m.pattern == BossAi.Pattern.STUN
			or m.pattern == BossAi.Pattern.IDLE or m.pattern == BossAi.Pattern.WINDUP):
		if world.frame(DT, 0.0, false, false):
			ticks += 1
	t.eq(m.pattern, BossAi.Pattern.FIRE,
		"gore 다음 순번은 fire다 (gore가 회전판을 건너뛰게 하지 않는다 - charge 자리를 대신 썼을 뿐이다)")


## **The negative control damage needs, separate from the pig** — contact alone is not enough; `pattern` is
## the gate. White-boxed to stay `IDLE` (the same idiom Stage C's own negative control uses) so the bull
## never reaches `GORE`/`CHARGE` at all during the window, even standing flush against it, well inside gore
## range too.
func _touching_an_idle_bull_does_not_hurt(t) -> void:
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
	m.pattern_left = 100000
	var hp0 := ch.hp

	for _i in 90:
		world.frame(DT, 0.0, false, false)
	t.eq(m.pattern, BossAi.Pattern.IDLE, "그동안 계속 idle이었다 (검사의 전제)")
	t.eq(ch.hp, hp0, "idle인 황소 몸에 닿아만 있어도 안 맞는다 (닿음만으론 안 된다 - pattern이 gate다)")


# ==================================================================
#  stage1-bosses.md Stage F — the rooster leaps, pounces, lands
# ==================================================================

## The table values, by themselves — the same "provisional is not the same as unmeasured" lesson Stages
## B-E's review passes left behind for `speed_mult`/`carve_r`/`gore_range_px`.
func _leap_values_are_read(t) -> void:
	t.eq(BossAi.leap_jump_vy_px(Defs.KIND_ROOSTER), -500.0, "거대 수탉 leap 상승 속도 = -500px/s")
	t.eq(BossAi.leap_jump_vy_px(Defs.KIND_HEN), 0.0, "패턴 없는 종류는 leap 상승 속도 = 0")
	t.eq(BossAi.speed_mult(Defs.KIND_ROOSTER, BossAi.Pattern.LEAP), 2.0, "거대 수탉 leap 배속 = 2.0")
	t.eq(BossAi.speed_mult(Defs.KIND_ROOSTER, BossAi.Pattern.IDLE), 1.0, "idle 중엔 배속이 안 걸린다")
	# **Stage G — the bull's own leap (the slam) reads its own multiplier, not the rooster's.** This line used
	#  to assert 1.0 under the label "황소는 애초에 leap이 없다" ("the bull has no leap at all") — true until the
	#  slam gave the bull a second `MOVES` row that also enters `Pattern.LEAP`. Left as a comment, not deleted,
	#  because it is the exact shape of drift this file's own header warns about (a fact recorded as permanent
	#  that a later stage quietly made false).
	t.eq(BossAi.speed_mult(Defs.KIND_BULL, BossAi.Pattern.LEAP), 1.5, "황소 slam 배속 = 1.5 (MOVE_SLAM.leap_speed_mult)")


## **The behavioral half of `_leap_values_are_read`** — the same gap Stage B's review left for the charge
## (`_charge_moves_at_the_charge_speed_not_walking_speed`), copied for the leap. A table that returns the
## right multiplier wired to nothing would pass the check above and still fail this one. **Caught green before
## this test existed**: `speed_mult` ignoring `leap_speed_mult` entirely (returning 1.0 for `LEAP`) halves the
## horizontal distance covered (153px measured on screen -> 76px) with every sequence/table check above still
## passing, since none of them read `m.x` against the multiplier's actual value.
func _leap_moves_at_the_leap_speed_not_walking_speed(t) -> void:
	var kind := Defs.KIND_ROOSTER
	var g := _bare_grid()
	var stand_x := 5000
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(stand_x + 3000, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, FLOOR_TOP - Defs.h_px(kind))
	t.ok(mid > 0, "거대 수탉 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	# White-box straight into LEAP - the windup/landing timing is covered elsewhere.
	m.pattern = BossAi.Pattern.LEAP
	m.pattern_dir = 1
	m.pattern_left = int(BossAi.MOVE_LEAP["leap_max_ticks"])

	var x0 := m.x
	world.frame(DT, 0.0, false, false)
	var moved := m.x - x0
	var walk_speed := Defs.speed_px(kind)
	var leap_speed := walk_speed * float(BossAi.MOVE_LEAP["leap_speed_mult"])
	# One frame's worth, rounded the same way `Body.move_x` rounds (`roundi` on the accumulated `_rem_x`).
	t.eq(moved, roundi(leap_speed * DT),
		"leap 중 한 프레임 이동량이 leap 배속 값과 일치한다 (%dpx)" % moved)
	t.ok(moved > roundi(walk_speed * DT),
		"걷기 속도보다 빠르다 (걷기였다면 %dpx)" % roundi(walk_speed * DT))


## **Risk 5's exact medicine, applied to the third pattern family** — the whole sequence, not just the final
## state, and the iteration count with it (a machine stuck in `IDLE` would compress to length 1, not 5).
## **Acceptance 9's "it does not stay airborne"** is measured directly here too: every sample taken while
## `pattern == LEAP` records `m.on_ground`, and at least one of those samples must be `false` — a leap that
## never actually left the ground (a mutation, say, that skipped the jump velocity) would make this the only
## check in the file that notices, since the pattern label alone does not prove the body moved.
func _rooster_pattern_sequence_is_idle_windup_leap_stun_idle(t) -> void:
	var kind := Defs.KIND_ROOSTER
	var g := _bare_grid()
	var stand_x := 5000
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(stand_x + 3000, FLOOR_TOP - Character.H_PX)  # far to the right - direction is always +1
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "거대 수탉 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	t.eq(m.pattern, BossAi.Pattern.IDLE, "스폰 직후엔 idle이다 (검사의 전제)")

	var seq: Array[int] = [m.pattern]
	var xs: Array[int] = [m.x]
	var min_y_during_leap := stand_y
	var saw_airborne := false
	var ticks := 0
	var max_ticks := 100
	while ticks < max_ticks:
		if world.frame(DT, 0.0, false, false):
			ticks += 1
			seq.append(m.pattern)
			xs.append(m.x)
			if m.pattern == BossAi.Pattern.LEAP:
				min_y_during_leap = mini(min_y_during_leap, m.y)
				if not m.on_ground:
					saw_airborne = true
			if seq.size() >= 5 and m.pattern == BossAi.Pattern.IDLE \
					and seq[seq.size() - 2] == BossAi.Pattern.STUN:
				break  # the full cycle closed

	var compressed: Array[int] = []
	var run_lengths: Array[int] = []
	for p: int in seq:
		if compressed.is_empty() or compressed[compressed.size() - 1] != p:
			compressed.append(p)
			run_lengths.append(1)
		else:
			run_lengths[run_lengths.size() - 1] += 1
	t.eq(compressed, [BossAi.Pattern.IDLE, BossAi.Pattern.WINDUP, BossAi.Pattern.LEAP,
		BossAi.Pattern.STUN, BossAi.Pattern.IDLE],
		"idle -> windup -> leap -> stun -> idle 순서로만 간다 (실제: %s)" % [compressed])
	if compressed.size() >= 5:
		var windup_ticks: int = BossAi.MOVE_LEAP["windup_ticks"]
		var stun_ticks: int = BossAi.MOVE_LEAP["stun_ticks"]
		t.eq(run_lengths[1], windup_ticks + 1,
			"windup이 정확히 windup_ticks+1 틱 지속된다 (%d틱, 0이면 카운터가 안 돈 것)" % run_lengths[1])
		t.ok(run_lengths[2] >= 1, "leap 상태가 최소 1틱은 지속된다 (%d틱)" % run_lengths[2])
		# **Distinguishes "landed" from "gave up and used the safety cap" — pinned as an absolute tick count,
		#  not `leap_max_ticks / 2`.** The relative bound coupled two provisional values that have no business
		#  being coupled (measured, Stage F fix list): raising `|jump_vy_px|` toward ~1200 stretches a real
		#  landing to ~20 ticks and the ratio bound goes red with nothing broken; lowering `leap_max_ticks` to
		#  16 drops the bound to 8 and a normal ~8-tick landing fails `8 < 8`, also with nothing broken. **30
		#  is fixed independently of both tunables** — comfortably above the shipped landing (measured ~8
		#  ticks, 0.400s at 20Hz) and above the raised-`jump_vy_px` example above (~20 ticks), and comfortably
		#  below the safety cap's 41 ticks, so a genuine "never lands" regression still goes red.
		t.ok(run_lengths[2] < 30,
			"leap이 안전장치가 아니라 실제 착지로 끝난다 (%d틱, 절대 상한 30틱 - leap_max_ticks와 별개)" % run_lengths[2])
		t.eq(run_lengths[3], stun_ticks + 1,
			"stun이 정확히 stun_ticks+1 틱 지속된다 (%d틱, 0이면 카운터가 안 돈 것)" % run_lengths[3])
		# **Acceptance 9's other half, and not a tautology.** Unlike the bull's own stun (it sits flush against
		#  the wall it just rammed, so `move_x` is blocked whether or not the freeze code runs at all), the
		#  rooster lands on open floor with the player still 3,000px away - nothing else would stop it from
		#  walking during `STUN` if `_boss_axis`'s freeze were ever deleted. This is a real assertion.
		# **The last *STUN* sample, not the last sample overall.** `seq[seq.size() - 2]` is the tick the break
		#  condition itself pins as still `STUN` (the one right before the cycle-closing `IDLE`) — the very
		#  last entry in `seq`/`xs` is already one tick into `IDLE`, which walks toward the player again, so
		#  comparing against it double-counts that one legitimate step and reads as "it moved during stun"
		#  when it did not (measured: exactly one frame's worth of walking speed, 3px).
		var stun_start := seq.find(BossAi.Pattern.STUN)
		var last_stun_idx := seq.size() - 2
		if stun_start > 0:
			t.eq(xs[last_stun_idx], xs[stun_start],
				"stun(착지) 동안 한 픽셀도 움직이지 않는다 (%d -> %d)" % [xs[stun_start], xs[last_stun_idx]])
		# **Stage G fix list — the apex alone stopped separating the two `Pattern.LEAP` owners** once the
		#  bull's slam apex was lowered (Stage G's own acceptance-8 fix): measured post-fix, the slam is
		#  32-39px (context-dependent — it varies with the terrain under it) and the rooster's own leap is
		#  40px, so the two apex windows (this one and the slam's) now overlap and a swapped `jump_vy_px`
		#  would not be caught by height alone. **Horizontal travel still separates them cleanly** — 153px
		#  here vs. the slam's ~80px, a 2x gap `leap_speed_mult`(2.0 vs 1.5) and the different `jump_vy_px`
		#  together produce, immune to the apex's own terrain-dependence.
		var leap_start := seq.find(BossAi.Pattern.LEAP)
		if leap_start > 0 and stun_start > leap_start:
			var travel_px := xs[stun_start] - xs[leap_start]
			t.ok(travel_px >= 130 and travel_px <= 170,
				"leap 도약 중 이동 거리가 고정된 픽셀 범위 안에 있다 (%dpx, 130..170 - 황소 slam의 ~80px과 겹치지 않는다)" \
					% travel_px)

	t.ok(saw_airborne, "leap 동안 실제로 공중에 뜬다 (검사의 전제 - 안 뜨면 절대 못 잡는다)")
	t.ok(min_y_during_leap < stand_y, "실제로 땅보다 위로 올라간다 (y=%d, 서 있을 때 y=%d)" % [min_y_during_leap, stand_y])
	# **Pins the apex against a fixed pixel window, not against `BossAi.MOVE_LEAP` re-read** — reading the
	#  expected value back out of the same dict a mutation would edit lets the mutation move the expectation
	#  with it (measured: this is exactly why `jump_vy_px` x0.4 stayed green before this check existed - the
	#  apex silently dropped from ~40px to ~8px and only `min_y_during_leap < stand_y` was watching, which
	#  1px of lift already satisfies). **The window is fixed at the shipped `-500.0`**: continuous formula
	#  gives 52px (`vy^2/(2*GRAVITY_PX)`), measured real behavior gives 40px (60Hz Euler + integer rounding,
	#  `boss_ai.gd`'s own comment on `MOVE_LEAP`). 25..55 sits comfortably around the measured value, well
	#  above what x0.4 on `jump_vy_px` produces (~8px, continuous formula alone already caps it under 9px),
	#  and comfortably under the continuous formula's own ceiling.
	var apex_px := stand_y - min_y_during_leap
	t.ok(apex_px >= 25 and apex_px <= 55,
		"leap 정점이 고정된 픽셀 범위 안에 있다 (%dpx, 25..55 - jump_vy_px가 바뀌면 여기서 걸린다)" % apex_px)


## **Acceptance 9's other half — it does NOT stay airborne, measured on a floor that does not exist.** No
## floor anywhere near the rooster means gravity never brings it back to `on_ground == true`, so the only way
## `LEAP` can ever end is the safety cap (`leap_max_ticks`) — the same defensive idiom the charge's own
## `charge_max_ticks` already proved matters (`_charge_with_no_wall_ends_via_the_safety_cap`).
func _leap_with_no_floor_ends_via_the_safety_cap(t) -> void:
	var kind := Defs.KIND_ROOSTER
	var g := CellGrid.new()  # no floor at all, unlike `_bare_grid()`
	var stand_x := 5000
	var stand_y := 500
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(stand_x + 3000, stand_y)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "거대 수탉 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)

	var saw_leap := false
	var reached_stun := false
	var ticks := 0
	var max_ticks: int = int(BossAi.MOVE_LEAP["leap_max_ticks"]) + 60
	while ticks < max_ticks and not reached_stun:
		if world.frame(DT, 0.0, false, false):
			ticks += 1
			if m.pattern == BossAi.Pattern.LEAP:
				saw_leap = true
			if saw_leap and m.pattern == BossAi.Pattern.STUN:
				reached_stun = true
	t.ok(saw_leap, "leap에 들어갔다 (검사의 전제)")
	t.ok(reached_stun, "바닥이 없어도 안전장치(leap_max_ticks)로 결국 stun까지 간다 (영원히 공중에 뜨지 않는다)")


## The horizontal half of "it does not home in" — locked at the instant the leap begins, same idiom as the
## charge's own direction lock (`_charge_direction_follows_the_player_left_too`).
func _leap_direction_follows_the_player_left_too(t) -> void:
	var kind := Defs.KIND_ROOSTER
	var g := _bare_grid()
	var stand_x := 5000
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(stand_x - 3000, FLOOR_TOP - Character.H_PX)  # to the LEFT this time
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "거대 수탉 스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)

	var ticks := 0
	var max_ticks := 100
	while ticks < max_ticks and m.pattern != BossAi.Pattern.LEAP:
		if world.frame(DT, 0.0, false, false):
			ticks += 1
	t.eq(m.pattern, BossAi.Pattern.LEAP, "왼쪽 플레이어를 향해서도 결국 leap에 들어간다 (검사의 전제)")
	t.eq(m.pattern_dir, -1, "플레이어가 왼쪽이면 방향도 왼쪽이다")


## **The pattern cycle actually reaches fire, not just the mechanics tested white-box above** — round-robin
## selection (`boss_ai.advance`'s own comment) means the first move is always charge (`move_choice` starts
## at -1, so `(-1+1) % 2 == 0` = `MoveChoice.CHARGE`), and the second is fire. An **open floor** is used —
## the charge cycle needs no wall (it ends via the safety cap, already measured by
## `_charge_with_no_wall_ends_via_the_safety_cap`), so nothing here risks colliding the two stages' setups.
func _second_cycle_is_fire_breath_and_it_fires_locked_bolts(t) -> void:
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

	var seq: Array[int] = [m.pattern]
	var ticks := 0
	var max_ticks := 300
	while ticks < max_ticks and m.pattern != BossAi.Pattern.FIRE:
		if world.frame(DT, 0.0, false, false):
			ticks += 1
			seq.append(m.pattern)
	t.eq(m.pattern, BossAi.Pattern.FIRE, "두 번째 사이클은 fire다 (round-robin이 실제로 번갈아 고른다, 검사의 전제)")

	var compressed: Array[int] = []
	for p: int in seq:
		if compressed.is_empty() or compressed[compressed.size() - 1] != p:
			compressed.append(p)
	t.eq(compressed, [BossAi.Pattern.IDLE, BossAi.Pattern.WINDUP, BossAi.Pattern.CHARGE,
		BossAi.Pattern.STUN, BossAi.Pattern.IDLE, BossAi.Pattern.WINDUP, BossAi.Pattern.FIRE],
		"idle -> windup -> charge -> stun -> idle -> windup -> fire 순서로 간다 (실제: %s)" % [compressed])

	t.eq(m.pattern_dir, 1, "플레이어가 오른쪽이니 fire 방향도 오른쪽으로 잠긴다")
	var x_at_fire_start := m.x
	t.ok(world.bolt_count() > 0,
		"fire에 들어가자마자 불덩이가 나간다 (검사의 전제 - reload_left가 이번 사이클엔 처음이라 0이다)")
	t.eq(world.bolt_kind(0), MonsterBolts.KIND_FIRE, "나간 탄이 fire kind다")

	var fire_ticks := 0
	while m.pattern == BossAi.Pattern.FIRE and fire_ticks < 30:
		if world.frame(DT, 0.0, false, false):
			fire_ticks += 1
	t.eq(m.x, x_at_fire_start, "fire breathing 동안 한 픽셀도 움직이지 않는다")


## Screen wiring (`stage1-bosses.md` Stage D's screen share) — text, so it goes as far as "does it read the
## kind", the same idiom as `_pattern_indicator_is_wired_to_the_screen`. Pixel-level color verification
## belongs to verify-look.
func _bolt_kind_is_wired_to_the_screen(t) -> void:
	var f := FileAccess.open("res://src/view/monster_view.gd", FileAccess.READ)
	t.ok(f != null, "monster_view.gd를 읽었다 (검사의 전제)")
	if f == null:
		return
	var src := NetDeterminism._strip(f.get_as_text())
	f.close()
	t.ok(src.contains("_world.bolt_kind(i)"),
		"화면이 실제로 `bolt_kind(i)`를 읽는다 (fire 탄과 평범한 탄을 갈라 그릴 근거)")


## **Driven, not grepped** (verify-read's finding — the box above, the same fix Stage B's own review already
## applied to `_pattern_indicator_draws_the_right_thing_for_the_right_state`). A whole-file grep for
## `FIRE_LO`/`KIND_FIRE` stays green through a branch swap (fire drawn hen-purple, the hen drawn
## fire-colored) — the strings are still *somewhere*. `MonsterView.bolt_glow`/`bolt_core` are pure static, so
## they are called directly with a bare kind int, no world, no tree, no canvas.
func _bolt_color_differs_by_kind(t) -> void:
	t.eq(MonsterView.bolt_glow(MonsterBolts.KIND_FIRE), Fx.FIRE_LO, "fire 탄 glow = FIRE_LO")
	t.eq(MonsterView.bolt_core(MonsterBolts.KIND_FIRE), Fx.FIRE_HI, "fire 탄 core = FIRE_HI")
	t.eq(MonsterView.bolt_glow(MonsterBolts.KIND_PLAIN), Fx.MONSTER_BOLT_COLOR, "평범한 탄 glow는 그대로다")
	t.eq(MonsterView.bolt_core(MonsterBolts.KIND_PLAIN), Fx.MONSTER_BOLT_CORE, "평범한 탄 core도 그대로다")
	t.ok(MonsterView.bolt_glow(MonsterBolts.KIND_FIRE) != MonsterView.bolt_glow(MonsterBolts.KIND_PLAIN),
		"두 종류가 실제로 다른 색이다 (glow)")
	t.ok(MonsterView.bolt_core(MonsterBolts.KIND_FIRE) != MonsterView.bolt_core(MonsterBolts.KIND_PLAIN),
		"두 종류가 실제로 다른 색이다 (core)")


