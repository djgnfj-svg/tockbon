extends RefCounted
## Monster stages 0 and 1 — extracting `Body`, and one monster standing up.
##
## Acceptance 1 (stage 0) adds zero new checks. `Character.W_PX` and its kind are already measured by
##  `net_character`, and the layer contract (no reference to `src/view/` or `src/stage/`) is measured by `net_layers`, which scans the folders recursively.
## What is measured here is `monster_defs` · `body` · `monster` · `world_step`'s monster share · `monster_view`.
##
## **Six of the checks below were fixed after the first pass (verify-read) ran 12 mutations on an isolated
##  copy and found the ones that did not actually bite** — put a new check through an inversion (CLAUDE.md).
##  | what used to get through | what bites now |
##  |---|---|
##  | `Monster` not passing `w_px` to `Body` (fixed 20px) isn't caught if you only look at the landing y | the vertical
##    chimney with no horizontal movement (`_monster_collision_width_gates_the_chimney`) — a hen fits the 32px gap, a pig catches |
##  | lowering `MAX_MONSTERS` from 20 to 3 isn't caught, because check 10 is a tautology | the absolute value
##    (`MAX_MONSTERS = 20` in `_defs_accessors`) |
##  | deleting `monster_requested.connect(` from `stage.gd` (= the M key dies) leaves all 66 green | check 13
##    bites that string too |
##  | `on_ground` being false forever (= the monster can't climb a ledge) leaves everything green | it measures
##    directly whether `on_ground` is true after landing (old check 7) |
##  | `spawn_monster()` sitting outside the `_broken` door leaves everything green | it was moved onto
##    `net_damage._null_world_refuses` (that one is the single source for the `_broken` contract) |
##  | old checks 6 and 7 called `Monster.step()` directly, so check 8 was the only witness that "a monster
##    lives inside the world loop" | 6 and 7 were rewritten to go through `world.frame()` |

## The comment/string stripper is **borrowed** — several nets sweep source text and there must be only
##  one stripper (the same reason as `net_damage` and `net_render`). **It got burned when written without it** —
##  an inversion deleting `monster_requested.connect(` left the same string in the comment recording that fact,
##  and `.contains()` found that string in the comment, so **not one mutation bit** (measured).
## **The helpers and constants below are intentional duplication across the four net_monster*.gd files**
##  (harness-manager, stage1-bosses.md Stage E-I round) -- same idiom as net_water_rain.gd's own split into
##  net_water_rain_cap.gd / net_water_rain_speed.gd. **If you fix one copy, fix the other three too.**
##  Full split rationale: header comment of net_monster_charge.gd.

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
## The firing origin sits this far to the left of the box. The same value and the same reason as
##  `net_damage.HIT_LEAD_PX` — generation 0's first-tick leap (`Tuning.speed_cells(0) * Tuning.CELL_PX`) is
##  far larger than the box, so firing from this far ahead gives a "leaping placement" with **both ends of the segment outside the box**.
## **36 -> 24 when the hen's box grew to 48px.** The condition this value has to satisfy is asserted right
##  where it is used (`_monster_hit_by_a_leaping_segment`): `lead + w_px < one tick's leap (80px)`, or the
##  segment's far end lands *inside* the box and the placement stops being a leaping one — at 36 + 48 = 84 it
##  did, and that assertion is what went red. 24 + 48 = 72 clears it with room.
## **It is no longer the same number as `net_damage.HIT_LEAD_PX`**, and that is correct: that file leads a
##  shot past the *player's* 20px box, this one past the widest monster box it fires at. The two were equal by
##  coincidence, not by contract.
const HIT_LEAD_PX := 24

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
##  => **The width is engaged by falling alone**: a pig (44px) fits the 48px gap, a bull (88px) catches on top.
const HOLE_CX := 50
## **48px — wider than a pig (44), narrower than a bull (88).**
## **It was 32px and the pair was hen/pig**, until the hen's art grew and its box went 24 -> 48
##  (`monster_defs.KIND_HEN`'s own box). **Nothing in the table is narrower than the pig any more**, so the
##  pair moved up a size rather than the check being weakened: what is measured is unchanged — that the width
##  a monster hands `Body` is the width that decides whether it fits a gap.
const HOLE_W_CELLS := 12
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


## Fires repeated direct hits (`ELEM_NONE`, so no fire/blast side effects mix in) at a freshly spawned
##  monster of `kind` until it dies. Returns the number of shots that connected.
## **The origin is recomputed every shot from the monster's current position** — `_still_ch` keeps the target
##  stationary so the pig has no reason to walk, but re-aiming costs nothing and removes the assumption entirely.
## Spacing between shots is `invuln_ticks + 1` — one tick beyond invulnerability, the same margin
##  `net_damage._invuln_lasts_four_ticks` uses for "the gap that guarantees a second hit lands".
func _hits_to_kill(kind: int, glyphs: int) -> int:
	var stand_x := 600
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var g := _bare_grid()
	var spell := SpellSim.new()
	var ch := _still_ch(stand_x, kind)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	# **No `t` in scope here** — the caller asserts the premise. Returning -1 makes a spawn failure show up as
	#  a comparison mismatch in the caller rather than disappearing silently.
	if mid <= 0:
		return -1
	var m: Monster = world.monster_at(0)

	var hits := 0
	var safety := 0
	while world.monster_count() > 0 and safety < 50:
		var row_cy := floori((m.y + Defs.h_px(kind) * 0.5) / float(Tuning.CELL_PX))
		var origin_cx := floori((m.x - HIT_LEAD_PX) / float(Tuning.CELL_PX))
		world.enqueue(SpellSim.cmd_fire(origin_cx, row_cy, 10, 0, Tuning.ELEM_NONE, glyphs))
		for _i in Tuning.TICK_DIVIDER * (Defs.invuln_ticks(kind) + 1):
			world.frame(DT, 0.0, false, false)
		hits += 1
		safety += 1
	return hits


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
	_defs_preconditions(t)
	_defs_accessors(t)
	_body_width_is_a_ctor_arg(t)
	_body_height_is_a_ctor_arg(t)
	_body_step_is_a_ctor_arg(t)
	_monster_collision_width_gates_the_chimney(t)
	_monster_lands_exactly(t)
	_monster_falls_through_the_air(t)
	_frame_is_required_to_move(t)
	_world_holds_monsters(t)
	_spawn_cap(t)
	_spawn_rejects_off_grid(t)
	_ids_are_distinct_and_not_reused(t)
	_view_box_comes_from_the_table(t)
	_shell_hands_the_world_to_the_view(t)
	# -- stage 2 -- it walks ----------------------------------------
	_walks_toward_the_player(t)
	_walking_monster_blocked_by_wall(t)
	# -- stage 3 -- it gets hurt ------------------------------------
	_monster_takes_blast_damage(t)
	_monster_hit_by_a_leaping_segment(t)
	_monster_burns_regardless_of_invuln(t)
	_dead_monsters_leave_the_list_correctly(t)
	# -- stage 4 -- there are two of them ---------------------------
	_pig_and_hen_cross_the_ledge_differently(t)
	# -- stage 5 -- the pig hits ------------------------------------
	_pig_contact_damages_the_player(t)
	_pig_contact_respects_invulnerability(t)
	# -- stage 6 -- the hen shoots ----------------------------------
	_hen_stops_at_bolt_range(t)
	_hen_bolt_hits_only_the_player(t)
	_hen_bolt_lifetime_axis(t)
	_hen_bolt_blocked_by_terrain_and_does_not_carve(t)
	_hen_bolt_step_stays_inside_the_player_box(t)
	# -- stage 7 -- four screen things + the corpse -----------------
	_hp_bar_values_come_from_the_table(t)
	_monster_bolt_color_differs_from_magic_bolts(t)
	_hit_triggers_flash_and_a_damage_number_that_ages_out(t)
	_death_notification_spawns_a_corpse_that_ages_out(t)
	# -- stage 9 -- effects from shapes to pictures (acceptance 13, second try) --
	_close_damage_numbers_merge_into_one(t)
	_death_also_makes_a_pop_that_outlives_nothing(t)
	_body_flames_stay_put_and_stay_inside(t)
	_flash_layer_gets_its_shader_in_a_real_tree(t)
	_layer_draws_go_through_the_canvas_argument(t)
	# -- levelup-and-three-picks Stage A -- acceptance 8, measured by value --
	_dummy_raises_hits_to_kill_a_pig(t)
	# -- animation (`monsters.md`, "animation is entirely a code gap") --
	_a_walking_monster_reaches_the_walk_state(t)
	_a_hit_puts_the_hurt_pose_up_for_its_whole_length(t)
	_a_corpse_plays_its_death_sheet_through(t)


# -- 1. premises --------------------------------------------------
func _defs_preconditions(t) -> void:
	t.ok(Defs.ALL.size() >= 2, "종류가 둘 이상이다 (%d개)" % Defs.ALL.size())
	t.ok(not Defs.ALL.has(Defs.KIND_NONE), "KIND_NONE(예약값)이 ALL에 없다")
	for kind: int in Defs.ALL:
		t.eq(Defs.w_px(kind) % Tuning.CELL_PX, 0,
			"%s의 w_px가 셀(%dpx)의 배수다 (%dpx)" % [
				Defs.name_of(kind), Tuning.CELL_PX, Defs.w_px(kind)])
		t.eq(Defs.h_px(kind) % Tuning.CELL_PX, 0,
			"%s의 h_px가 셀(%dpx)의 배수다 (%dpx)" % [
				Defs.name_of(kind), Tuning.CELL_PX, Defs.h_px(kind)])


# -- 2. table accessors — both the absolute value and "they differ" --
## Measuring only the absolute value goes green even with the table killed and a constant baked in; measuring only "they differ" goes green with the values wrong.
func _defs_accessors(t) -> void:
	t.eq(Defs.w_px(Defs.KIND_PIG), 44, "돼지 w_px = 44")
	t.eq(Defs.h_px(Defs.KIND_PIG), 32, "돼지 h_px = 32")
	t.eq(Defs.step_cells(Defs.KIND_PIG), 1, "돼지 step_cells = 1")
	t.eq(Defs.max_hp(Defs.KIND_PIG), 30, "돼지 max_hp = 30")
	# **24x28 -> 48x64 when the enlarged art landed** (`monster_defs.KIND_HEN`'s own box). These two literals
	#  are the point of this function — the box follows the png, so the day one moves without the other, the
	#  size contract (`net_monster_sprite`) and this line disagree and one of them says so.
	t.eq(Defs.w_px(Defs.KIND_HEN), 48, "닭 w_px = 48")
	t.eq(Defs.h_px(Defs.KIND_HEN), 64, "닭 h_px = 64")
	t.eq(Defs.step_cells(Defs.KIND_HEN), 3, "닭 step_cells = 3")
	t.eq(Defs.max_hp(Defs.KIND_HEN), 10, "닭 max_hp = 10")
	t.ok(Defs.w_px(Defs.KIND_PIG) != Defs.w_px(Defs.KIND_HEN), "돼지 ≠ 닭 (w_px)")
	t.ok(Defs.h_px(Defs.KIND_PIG) != Defs.h_px(Defs.KIND_HEN), "돼지 ≠ 닭 (h_px)")
	t.ok(Defs.step_cells(Defs.KIND_PIG) != Defs.step_cells(Defs.KIND_HEN), "돼지 ≠ 닭 (step_cells)")
	t.ok(Defs.max_hp(Defs.KIND_PIG) != Defs.max_hp(Defs.KIND_HEN), "돼지 ≠ 닭 (max_hp)")
	# Without it, lowering `MAX_MONSTERS` to 3 makes check 10 (the cap) read both values and turn into a
	#  tautology, and only the pass count quietly drops (measured: 66 -> 49, 0 failures). 20 is a value the user
	#  decided, so it is "not a value to measure and adjust" — this one value is baked in directly instead of derived from the table.
	t.eq(Defs.MAX_MONSTERS, 20, "MAX_MONSTERS = 20 (사용자가 정한 값이다)")
	# **stage1-bosses.md Stage A — the two boss rows had no pin at all.** Measured: dropping 황소's max_hp
	#  300 -> 1 (or invuln_ticks, xp, money, name) left the full round green. Same idiom as pig/hen above —
	#  every column, both the absolute value and "they differ" (checked against each other, not against the
	#  trash mobs — a boss reading identical to a pig is the failure worth catching here).
	t.eq(Defs.name_of(Defs.KIND_BULL), &"황소", "황소 name")
	t.eq(Defs.w_px(Defs.KIND_BULL), 88, "황소 w_px = 88 (그림 86 + 좌우 패딩 1+1)")
	t.eq(Defs.h_px(Defs.KIND_BULL), 56, "황소 h_px = 56 (그림 54 + 위 패딩 2)")
	t.eq(Defs.step_cells(Defs.KIND_BULL), 3, "황소 step_cells = 3")
	t.eq(Defs.max_hp(Defs.KIND_BULL), 300, "황소 max_hp = 300")
	t.eq(Defs.speed_px(Defs.KIND_BULL), 140.0, "황소 speed_px = 140")
	t.eq(Defs.invuln_ticks(Defs.KIND_BULL), 2, "황소 invuln_ticks = 2")
	t.eq(Defs.xp_of(Defs.KIND_BULL), 200, "황소 xp = 200")
	t.eq(Defs.money_of(Defs.KIND_BULL), 100, "황소 money = 100")
	t.eq(Defs.name_of(Defs.KIND_ROOSTER), &"거대 수탉", "거대 수탉 name")
	t.eq(Defs.w_px(Defs.KIND_WOLF), 48, "늑대 w_px = 48")
	t.eq(Defs.h_px(Defs.KIND_WOLF), 28, "늑대 h_px = 28")
	t.eq(Defs.max_hp(Defs.KIND_WOLF), 24, "늑대 max_hp = 24")
	t.eq(Defs.speed_px(Defs.KIND_WOLF), 240.0, "늑대 speed_px = 240 (돼지보다 빠르다)")
	# **The wolf is the same width as the hen and must not be the same beast.** Height is what separates them
	#  (28 vs 64) — the user's own rule that species split by brightness first has a shape counterpart here.
	t.ok(Defs.h_px(Defs.KIND_WOLF) != Defs.h_px(Defs.KIND_HEN), "늑대 ≠ 닭 (h_px — 폭은 같다)")
	t.ok(Defs.speed_px(Defs.KIND_WOLF) > Defs.speed_px(Defs.KIND_PIG), "늑대가 돼지보다 빠르다")

	t.eq(Defs.w_px(Defs.KIND_ROOSTER), 72, "거대 수탉 w_px = 72")
	t.eq(Defs.h_px(Defs.KIND_ROOSTER), 80, "거대 수탉 h_px = 80")
	t.eq(Defs.step_cells(Defs.KIND_ROOSTER), 3, "거대 수탉 step_cells = 3")
	t.eq(Defs.max_hp(Defs.KIND_ROOSTER), 250, "거대 수탉 max_hp = 250")
	t.eq(Defs.speed_px(Defs.KIND_ROOSTER), 200.0, "거대 수탉 speed_px = 200")
	t.eq(Defs.invuln_ticks(Defs.KIND_ROOSTER), 2, "거대 수탉 invuln_ticks = 2")
	t.eq(Defs.xp_of(Defs.KIND_ROOSTER), 250, "거대 수탉 xp = 250")
	t.eq(Defs.money_of(Defs.KIND_ROOSTER), 120, "거대 수탉 money = 120")
	t.ok(Defs.w_px(Defs.KIND_BULL) != Defs.w_px(Defs.KIND_ROOSTER), "황소 ≠ 거대 수탉 (w_px)")
	t.ok(Defs.h_px(Defs.KIND_BULL) != Defs.h_px(Defs.KIND_ROOSTER), "황소 ≠ 거대 수탉 (h_px)")
	t.ok(Defs.max_hp(Defs.KIND_BULL) != Defs.max_hp(Defs.KIND_ROOSTER), "황소 ≠ 거대 수탉 (max_hp)")
	t.ok(Defs.speed_px(Defs.KIND_BULL) != Defs.speed_px(Defs.KIND_ROOSTER), "황소 ≠ 거대 수탉 (speed_px)")
	t.ok(Defs.xp_of(Defs.KIND_BULL) != Defs.xp_of(Defs.KIND_ROOSTER), "황소 ≠ 거대 수탉 (xp)")
	t.ok(Defs.money_of(Defs.KIND_BULL) != Defs.money_of(Defs.KIND_ROOSTER), "황소 ≠ 거대 수탉 (money)")


# -- 3. Body's width is a constructor argument --------------------
## Without this, `Body` ignoring the argument and baking in 20x32 leaves `net_character` all green.
##  Height is not measured here (4 measures it).
func _body_width_is_a_ctor_arg(t) -> void:
	var g := _wall_grid()
	var wall_px := 30 * Tuning.CELL_PX
	var narrow := Body.new(20, 32, 1)
	narrow.place(40, FLOOR_TOP - 32)
	for _i in 200:
		narrow.move_x(g, 1.0)
	var wide := Body.new(44, 32, 1)
	wide.place(40, FLOOR_TOP - 32)
	for _i in 200:
		wide.move_x(g, 1.0)
	t.eq(narrow.x, wall_px - 20, "폭 20 Body가 벽 앞에서 멈춘다 (x=%d)" % narrow.x)
	t.eq(wide.x, wall_px - 44, "폭 44 Body가 벽 앞에서 멈춘다 (x=%d)" % wide.x)
	t.eq(narrow.x - wide.x, 24, "멈추는 x 차이가 폭 차이(44-20=24)와 같다")


# -- 4. Body's height is a constructor argument -------------------
## A failure that swaps the argument order (w <-> h) is caught by 3.
func _body_height_is_a_ctor_arg(t) -> void:
	var g := _floor_grid()
	var short := Body.new(20, 28, 1)
	short.place(160, FLOOR_TOP - 200)
	short.move_y(g, 300.0)
	var tall := Body.new(20, 32, 1)
	tall.place(160, FLOOR_TOP - 200)
	tall.move_y(g, 300.0)
	t.eq(short.y, FLOOR_TOP - 28, "높이 28 Body가 바닥 − 28에 정확히 착지한다")
	t.eq(tall.y, FLOOR_TOP - 32, "높이 32 Body가 바닥 − 32에 정확히 착지한다")
	t.ok(short.y != tall.y, "높이가 다르면 착지 y도 다르다")


# -- 5. Body's step is a constructor argument ---------------------
## Whether the monster uses that Body is not measured here (stage 2 measures it). Without it, "not passing it
##  reopens the extraction in stage 4" stays quiet all the way to stage 4.
func _body_step_is_a_ctor_arg(t) -> void:
	var g := _ledge_grid(2)
	var ledge_px := LEDGE_CX * Tuning.CELL_PX
	# `_try_step_up` only works while `on_ground` is true (the airborne guard) — the real use (`monster.step`)
	#  refreshes it every frame with `grounded()`, and that is imitated here too. Without it both Bodies simply
	#  "get blocked" and this check's point (that step actually produces a different result) doesn't bite.
	var short_step := Body.new(20, 32, 1)
	short_step.place(40, FLOOR_TOP - 32)
	short_step.on_ground = short_step.grounded(g)
	for _i in 200:
		short_step.move_x(g, 1.0)
	t.eq(short_step.x, ledge_px - 20, "step=1은 2셀 턱에 딱 붙어 막힌다")
	# The `step_cells` field itself is read by no logic (`step_px` comes straight out of the constructor) —
	#  without measuring it directly as a value, a mutation in that field cannot be caught in principle (verifier measured).
	t.eq(short_step.step_cells, 1, "step_cells 필드가 생성 인자(1)를 그대로 든다")

	var tall_step := Body.new(20, 32, 3)
	tall_step.place(40, FLOOR_TOP - 32)
	tall_step.on_ground = tall_step.grounded(g)
	for _i in 200:
		tall_step.move_x(g, 1.0)
	t.ok(tall_step.x > ledge_px, "step=3은 2셀 턱을 넘는다 (x=%d)" % tall_step.x)
	t.eq(tall_step.step_cells, 3, "step_cells 필드가 생성 인자(3)를 그대로 든다")


## **The left edge is aligned with the chimney's left edge — the centre is not taken from a table value.**
##  Taking the centre (= `hole_center - Defs.w_px(kind)/2`) makes the offset calculation itself read `Defs.w_px`
##  again, so even when `Monster` secretly passes a **different** width to `Body`, the left margin blocks the
##  spot instead and "it catches" comes out right by accident (measured — secretly changing the pig's width to 20 did not make this check bite).
##  **Fixing the left edge makes only the width actually used decide "does it fit the chimney".**
func _monster_collision_width_gates_the_chimney(t) -> void:
	var g := _chimney_grid()
	var hole_left := HOLE_CX * Tuning.CELL_PX

	# From stage 2 on, `_next_axis` actually reads the target — the target is set equal to the centre of the
	#  spawn position so axis is always 0 (pure falling only. Walking is another check's job).
	var hole_w := HOLE_W_CELLS * Tuning.CELL_PX
	# **The premise is asserted, not assumed.** Both boxes moved once already; if the table shifts again so
	#  that neither fits or both do, this line says so instead of the two checks below quietly agreeing.
	t.ok(Defs.w_px(Defs.KIND_PIG) <= hole_w and Defs.w_px(Defs.KIND_BULL) > hole_w,
		"돼지(%dpx)는 틈(%dpx)에 들어가고 황소(%dpx)는 못 들어간다 (전제)" % [
			Defs.w_px(Defs.KIND_PIG), hole_w, Defs.w_px(Defs.KIND_BULL)])

	var narrow := Monster.new(1, Defs.KIND_PIG, hole_left, FLOOR_TOP - 200)
	var narrow_target_x := int(narrow.center().x)
	for _i in 600:
		narrow.step(g, DT, narrow_target_x, 0)
	t.ok(narrow.y > FLOOR_TOP, "돼지(%dpx < %dpx 틈)가 굴뚝을 통과해 바닥 아래로 더 떨어진다 (y=%d)" % [
		Defs.w_px(Defs.KIND_PIG), hole_w, narrow.y])

	var wide := Monster.new(2, Defs.KIND_BULL, hole_left, FLOOR_TOP - 200)
	var wide_target_x := int(wide.center().x)
	for _i in 600:
		wide.step(g, DT, wide_target_x, 0)
	t.eq(wide.y, FLOOR_TOP - Defs.h_px(Defs.KIND_BULL),
		"황소(%dpx > %dpx 틈)는 굴뚝에 안 들어가고 바닥 위에 걸린다 (y=%d)" % [
			Defs.w_px(Defs.KIND_BULL), hole_w, wide.y])


# -- 6. the monster falls and stands exactly on the surface -------
## "You can see it" cannot be measured headless in principle — verify-look sees that.
## **It is written to go through `world.frame()` rather than calling `Monster.step()` directly** — otherwise
##  check 8 would be the only witness that "a monster lives inside the world loop", and that witness is thin:
##  it measures only "did it move at least 1px in one frame" (the verifier pointed it out).
## **The loop cap was 300, unmeasured.** harness-manager measured the actual landing tick for all four
##  kinds (a 200px fall) — 18-22. Cap 80 keeps 3.6x headroom over the slowest (황소, 20) while dropping
##  ~93% of the dead frames after landing (this check alone: ~1,070ms -> well under half, `run_nets.ps1 monster`).
func _monster_lands_exactly(t) -> void:
	var cap := 80
	for kind: int in Defs.ALL:
		var world := _new_world()
		var id := world.spawn_monster(kind, 160, FLOOR_TOP - 200)
		t.ok(id > 0, "%s 스폰됐다 (검사의 전제)" % Defs.name_of(kind))
		var m: Monster = world.monster_at(0)
		var landed_at := -1
		for i in cap:
			world.frame(DT, 0.0, false, false)
			if landed_at < 0 and m.y == FLOOR_TOP - Defs.h_px(kind):
				landed_at = i
		# **Assert the iteration count too** (CLAUDE.md) — without this, cutting the cap too close to the
		#  real landing tick would silently start reading "still falling" as "landed exactly", the moment
		#  headroom actually runs out. `< cap - 1` means it settled with at least one spare frame, not on the last one.
		t.ok(landed_at >= 0 and landed_at < cap - 1,
			"%s가 상한(%d틱) 안에 여유를 두고 착지했다 (%d틱)" % [Defs.name_of(kind), cap, landed_at])
		t.eq(m.y, FLOOR_TOP - Defs.h_px(kind),
			"%s 몬스터가 바닥 − h_px(%d)에 정확히 선다 (y=%d)" % [Defs.name_of(kind), Defs.h_px(kind), m.y])


# -- 7. the falling itself ----------------------------------------
## Without it, an implementation that spawns flush with the floor passes 6 for free.
func _monster_falls_through_the_air(t) -> void:
	var world := _new_world()
	var id := world.spawn_monster(Defs.KIND_PIG, 160, FLOOR_TOP - 200)
	t.ok(id > 0, "스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	var y0 := m.y
	var saw_airborne := false
	for _i in 300:
		world.frame(DT, 0.0, false, false)
		if not m.on_ground:
			saw_airborne = true
	t.ok(m.y != y0, "떨어지며 y가 실제로 바뀐다 (시작 %d → 끝 %d)" % [y0, m.y])
	t.ok(saw_airborne, "떨어지는 동안 on_ground가 거짓인 프레임이 있었다")
	# Without it, `on_ground` being false forever (= `_try_step_up`'s airborne guard always blocking, so the
	#  monster can't climb a single cell) leaves all 66 green (verifier measured). In stage 1 `_next_axis` is 0 so
	#  the symptom is invisible, and when "the hen can't cross the ledge" hits in stage 2 the cause gets hunted in the wrong place.
	t.ok(m.on_ground, "착지한 뒤 on_ground가 참이다")


func _frame_is_required_to_move(t) -> void:
	var world := _new_world()
	var spawn_y := FLOOR_TOP - 200
	var id := world.spawn_monster(Defs.KIND_PIG, 400, spawn_y)
	t.ok(id > 0, "스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	# It measures that the spawn itself doesn't step the monster — if the spawn quietly burns a frame,
	#  this catches it.
	t.eq(m.y, spawn_y, "frame()을 부르기 전에는 스폰한 y 그대로다")
	world.frame(DT, 0.0, false, false)
	t.ok(m.y != spawn_y, "frame()을 한 번 부르면 몬스터가 움직인다 (y=%d → %d)" % [spawn_y, m.y])


# -- 9. the world holds them --------------------------------------
## All three have to be hooked together — in the water net a loop never ran once and "it fell asleep" passed for free.
func _world_holds_monsters(t) -> void:
	var world := _new_world()
	world.spawn_monster(Defs.KIND_PIG, 400, FLOOR_TOP - 200)
	t.eq(world.monster_count(), 1, "스폰 뒤 monster_count()가 1이다")

	var loops := 0
	for _i in 30:
		world.frame(DT, 0.0, false, false)
		loops += 1
	t.ok(loops > 1, "프레임을 실제로 여러 바퀴 돌았다 (%d바퀴)" % loops)
	t.eq(world.monster_count(), 1, "그동안 몬스터가 그대로 하나다 (단계 1엔 죽음이 없다)")

	world.reset()
	t.eq(world.monster_count(), 0, "reset() 뒤 monster_count()가 0이다")


# -- 10. the cap --------------------------------------------------
## Without a positive control, an implementation that creates nothing passes.
func _spawn_cap(t) -> void:
	var world := _new_world()
	for i in Defs.MAX_MONSTERS:
		var id := world.spawn_monster(Defs.KIND_PIG, 100 + i * 4, FLOOR_TOP - 200)
		t.ok(id > 0, "%d번째 스폰이 성공한다 (상한 %d 이내)" % [i + 1, Defs.MAX_MONSTERS])
	t.eq(world.monster_count(), Defs.MAX_MONSTERS, "상한까지 채웠다 (%d마리)" % Defs.MAX_MONSTERS)
	var over := world.spawn_monster(Defs.KIND_PIG, 900, FLOOR_TOP - 200)
	t.eq(over, 0, "상한을 넘으면 id 0(실패)을 돌려준다")
	t.eq(world.monster_count(), Defs.MAX_MONSTERS, "상한을 넘어도 마릿수가 그대로다")


# -- 14. off-grid coordinates are refused -------------------------
## verify-look measured it — the M key uses `get_viewport().get_mouse_position()`, and that is
##  **the OS cursor's real position**, so with the cursor outside the game window the world x arrives as
##  something like -983. A monster off the grid never appears on screen, yet **a ghost eats one of the 20 cap slots.**
## The reason it lives at this door (`world_step.spawn_monster`) is written in that function's head comment —
##  **this is the only door that makes monsters, so putting it beside `_broken` and the cap gathers the conditions in one place.**
##  In `stage.gd` the net couldn't measure it without a scene (it wouldn't run headless), and future other
##  callers (server-side spawning and so on) would each have to write it again.
func _spawn_rejects_off_grid(t) -> void:
	var world := _new_world()
	var grid_w_px := CellGrid.W * Tuning.CELL_PX
	var grid_h_px := CellGrid.H * Tuning.CELL_PX

	t.eq(world.spawn_monster(Defs.KIND_PIG, -983, 100), 0, "왼쪽 밖 좌표는 거절한다 (x=-983)")
	t.eq(world.spawn_monster(Defs.KIND_PIG, 100, -500), 0, "위쪽 밖 좌표는 거절한다 (y=-500)")
	t.eq(world.spawn_monster(Defs.KIND_PIG, grid_w_px + 100, 100), 0, "오른쪽 밖 좌표는 거절한다")
	t.eq(world.spawn_monster(Defs.KIND_PIG, 100, grid_h_px + 100), 0, "아래쪽 밖 좌표는 거절한다")
	# Looking only at the top-left corner can't catch this — the case where the box's right edge just crosses the boundary is measured too.
	t.eq(world.spawn_monster(Defs.KIND_PIG, grid_w_px - 1, 100), 0,
		"좌상단은 안이어도 상자 오른쪽 끝이 밖이면 거절한다")
	t.eq(world.monster_count(), 0, "전부 거절됐으니 마릿수가 0이다 (양성 대조가 없으면 무의미하다)")

	# Positive control — inside the grid it still works.
	t.ok(world.spawn_monster(Defs.KIND_PIG, 400, 400) > 0, "격자 안 좌표는 그대로 스폰된다 (양성 대조)")
	t.eq(world.monster_count(), 1, "그 하나만 세워졌다")


# -- 11. ids differ from each other · not reused after reset() ----
func _ids_are_distinct_and_not_reused(t) -> void:
	var world := _new_world()
	var a := world.spawn_monster(Defs.KIND_PIG, 100, FLOOR_TOP - 200)
	var b := world.spawn_monster(Defs.KIND_PIG, 200, FLOOR_TOP - 200)
	var c := world.spawn_monster(Defs.KIND_HEN, 300, FLOOR_TOP - 200)
	t.ok(a != b and b != c and a != c, "세 id가 서로 다르다 (%d, %d, %d)" % [a, b, c])

	world.reset()
	var d := world.spawn_monster(Defs.KIND_PIG, 100, FLOOR_TOP - 200)
	t.ok(d > c, "reset() 뒤 새 id가 이전 id를 재사용하지 않는다 (%d > %d)" % [d, c])


# -- 12. the box the view draws comes from the table --------------
## "Is the colour right" and "does it show on screen" are for the eye. Nobody measures whether `_draw()` uses only `box_rect()` — that is discipline.
func _view_box_comes_from_the_table(t) -> void:
	for kind: int in Defs.ALL:
		var r := MonsterView.box_rect(kind, 40, 60)
		t.eq(r, Rect2(40, 60, Defs.w_px(kind), Defs.h_px(kind)),
			"%s의 box_rect가 표(w=%d,h=%d)에서 나온다" % [Defs.name_of(kind), Defs.w_px(kind), Defs.h_px(kind)])


# -- 13. the shell hands the world to the view · the M key reaches the spawn --
## It is text, so it goes as far as "does it call" and not "does it run" — whether the node is in the scene is measured by `net_render`.
## **It bites `monster_requested.connect(` and `_world.spawn_monster(` together** — without it, the M key's
##  connection could be deleted whole (= pressing M in the game does nothing) and all 66 stayed
##  green (verifier measured). It is more dangerous because the HUD still looks normal with "monsters 0/20 (M to place)".
func _shell_hands_the_world_to_the_view(t) -> void:
	var f := FileAccess.open(STAGE_SCRIPT, FileAccess.READ)
	t.ok(f != null, "stage.gd를 읽었다")
	if f == null:
		return
	# **The comments and strings are stripped before searching.** Using `.contains()` straight on the raw source
	#  fools the check, because the very comment saying "this string was deleted" holds that string again (the box above).
	var src := NetDeterminism._strip(f.get_as_text())
	t.ok(src.contains("_monster_view.setup("), "껍데기가 `_monster_view.setup(` 을 부른다")
	t.ok(src.contains("monster_requested.connect("),
		"껍데기가 `monster_requested.connect(` 를 부른다 (M키 → 스폰 신호가 이어져 있다)")
	t.ok(src.contains("_world.spawn_monster("),
		"껍데기가 `_world.spawn_monster(` 를 부른다 (스폰 핸들러가 실제로 세상에 만든다)")


## **What cannot be measured — looking only at the final position kills this acceptance** (CLAUDE.md, "a check
##  that looks only at the final state"). => The process is measured: the **accumulation** (`movement over N
##  frames == round(v x N x dt)` +-1px) and the **per-step ceiling** (`ceil(v x dt)` exceeded by no frame — that catches teleporting). The numbers are read from the table.
func _walks_toward_the_player(t) -> void:
	var speed := Defs.speed_px(Defs.KIND_PIG)
	var n := 30
	var step_cap := ceili(speed * DT)

	# Spawned on the right -> walks toward the player (left) and x drops.
	var g1 := _bare_grid()
	var spell1 := SpellSim.new()
	var ch1 := Character.new()
	ch1.place(160, FLOOR_TOP - Character.H_PX)
	var w1 := WorldStep.new(g1, spell1, ch1)
	var y := FLOOR_TOP - Defs.h_px(Defs.KIND_PIG)
	var right_id := w1.spawn_monster(Defs.KIND_PIG, 800, y)
	t.ok(right_id > 0, "오른쪽 스폰이 됐다 (검사의 전제)")
	var right: Monster = w1.monster_at(0)
	var x0 := right.x
	var over_cap_right := false
	for _i in n:
		var prev := right.x
		w1.frame(DT, 0.0, false, false)
		if absi(right.x - prev) > step_cap:
			over_cap_right = true
	var moved_left := x0 - right.x
	t.ok(moved_left > 0, "오른쪽에 스폰하면 왼쪽(플레이어 쪽)으로 걷는다 (x %d → %d)" % [x0, right.x])
	var want := roundi(speed * n * DT)
	t.ok(absi(moved_left - want) <= 1,
		"%d프레임 누적 이동이 v×N×dt에 ±1px로 붙는다 (%d ≈ %d)" % [n, moved_left, want])
	t.ok(not over_cap_right, "어느 프레임도 ceil(v×dt)(%dpx)를 안 넘는다 — 순간이동이 아니다" % step_cap)

	# Spawned on the left -> walks toward the player (right) and x rises. With only the left-side check, a
	# mutation like `return 1.0` (always right) isn't caught — it has to walk the other way for that branch to be engaged.
	var g2 := _bare_grid()
	var spell2 := SpellSim.new()
	var ch2 := Character.new()
	ch2.place(900, FLOOR_TOP - Character.H_PX)
	var w2 := WorldStep.new(g2, spell2, ch2)
	var left_id := w2.spawn_monster(Defs.KIND_PIG, 100, y)
	t.ok(left_id > 0, "왼쪽 스폰이 됐다 (검사의 전제)")
	var left: Monster = w2.monster_at(0)
	var x1 := left.x
	var over_cap_left := false
	for _i in n:
		var prev := left.x
		w2.frame(DT, 0.0, false, false)
		if absi(left.x - prev) > step_cap:
			over_cap_left = true
	var moved_right := left.x - x1
	t.ok(moved_right > 0, "왼쪽에 스폰하면 오른쪽(플레이어 쪽)으로 걷는다 (x %d → %d)" % [x1, left.x])
	t.ok(absi(moved_right - want) <= 1,
		"%d프레임 누적 이동이 v×N×dt에 ±1px로 붙는다 (%d ≈ %d)" % [n, moved_right, want])
	t.ok(not over_cap_left, "어느 프레임도 ceil(v×dt)(%dpx)를 안 넘는다 — 순간이동이 아니다" % step_cap)


## **Inverting it — it must not be made to ignore `is_solid` entirely.** That falls through the floor and
##  drops forever, going red regardless of "is horizontal blocked" (the shape acceptance 5 forbids by itself).
##  => The only thing to invert is `Body.move_x`'s horizontal branch, and the **control** (the landing check)
##  has to stay green for it to be a real inversion.
func _walking_monster_blocked_by_wall(t) -> void:
	var wall_cx := 60
	var wall_w_cells := 4
	var g := _bare_grid()
	g.apply(CellGrid.cmd_fill(wall_cx, FLOOR_CY - 8, wall_cx + wall_w_cells - 1, FLOOR_CY - 1, Mat.STONE))
	var spell := SpellSim.new()
	var ch := Character.new()
	# The player is placed left of the wall — the monster spawns right of the wall, walks left (toward the
	# player) and is blocked at the wall's **right face** (its box's left edge meets the wall's right edge).
	var wall_right_px := (wall_cx + wall_w_cells) * Tuning.CELL_PX
	ch.place(160, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var kind := Defs.KIND_PIG
	var y := FLOOR_TOP - Defs.h_px(kind)
	var mid := world.spawn_monster(kind, wall_right_px + 200, y)
	t.ok(mid > 0, "스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	for _i in 300:
		world.frame(DT, 0.0, false, false)
	t.eq(m.x, wall_right_px, "벽을 사이에 두면 벽 앞(오른쪽 면)에서 멈추고 더 안 온다")
	t.eq(m.y, y, "가로만 막힌다 — 세로(착지)는 그대로다 (대조군)")


# ==================================================================
#  stage 3 — it gets hurt
# ==================================================================

## The values are read from the table — **the pig is 30, not 100 (the player's MAX_HP).**
## **A negative control (outside the radius) is mandatory** — without it, "close by, it hurts" also passes.
func _monster_takes_blast_damage(t) -> void:
	var kind := Defs.KIND_PIG
	var stand_x := 600
	var y := FLOOR_TOP - Defs.h_px(kind)
	var g := _bare_grid()
	var spell := SpellSim.new()
	var ch := _still_ch(stand_x, kind)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, y)
	t.ok(mid > 0, "스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	t.eq(m.hp, Defs.max_hp(kind), "시작 hp가 표값이다 (%d — 100이 아니다, 검사의 전제)" % Defs.max_hp(kind))

	var center_cx := floori((stand_x + Defs.w_px(kind) * 0.5) / float(Tuning.CELL_PX))
	world.enqueue(_blast_cmd(center_cx))
	for _i in 36:
		world.frame(DT, 0.0, false, false)
	t.eq(m.hp, Defs.max_hp(kind) - Character.DAMAGE_HIT,
		"폭발 반경 안이면 hp가 %d 준다" % Character.DAMAGE_HIT)

	# Negative control — a monster stood far away is not hit by the same blast.
	var far_x := stand_x + 3000
	var g2 := _bare_grid()
	var spell2 := SpellSim.new()
	var ch2 := _still_ch(far_x, kind)
	var world2 := WorldStep.new(g2, spell2, ch2)
	var mid2 := world2.spawn_monster(kind, far_x, y)
	t.ok(mid2 > 0, "먼 자리에도 스폰됐다 (검사의 전제)")
	var m2: Monster = world2.monster_at(0)
	world2.enqueue(_blast_cmd(center_cx))
	for _i in 36:
		world2.frame(DT, 0.0, false, false)
	t.eq(m2.hp, Defs.max_hp(kind), "폭발 반경 밖이면 hp가 그대로다 (음성 대조)")


## **Disproving tunnelling — measured with the hen (24px, the narrowest box).** Generation 0's first-tick leap
##  is **read** from `Tuning.speed_cells(0) * Tuning.CELL_PX` (baking in 40px makes the disproof spin idle —
##  the same discipline as acceptance 12). The hen's hp (10) == `DAMAGE_HIT` (10) so **it dies in one hit**, and
##  what is observed is not "hp drops" but "it dies". It is not worked around by switching to the pig.
func _monster_hit_by_a_leaping_segment(t) -> void:
	var kind := Defs.KIND_HEN
	var stand_x := 600
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var g := _bare_grid()
	var spell := SpellSim.new()
	var ch := _still_ch(stand_x, kind)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	t.eq(m.hp, Defs.max_hp(kind), "닭 시작 hp가 %d다 (DAMAGE_HIT과 같아 한 방에 죽는다)" % Defs.max_hp(kind))

	var leap_px := Tuning.speed_cells(0) * Tuning.CELL_PX
	t.ok(leap_px > Defs.w_px(kind) + HIT_LEAD_PX,
		"한 틱 도약(%dpx)이 리드(%dpx)+상자(%dpx)보다 커서 도약 배치가 실제로 선다"
			% [leap_px, HIT_LEAD_PX, Defs.w_px(kind)])

	var row_cy := floori((stand_y + Defs.h_px(kind) * 0.5) / float(Tuning.CELL_PX))
	var origin_cx := floori((stand_x - HIT_LEAD_PX) / float(Tuning.CELL_PX))
	world.enqueue(SpellSim.cmd_fire(origin_cx, row_cy, 10, 0, Tuning.ELEM_NONE, Glyph.GLYPH_NONE))
	for _i in Tuning.TICK_DIVIDER:
		world.frame(DT, 0.0, false, false)

	# Is the placement really a leaping placement — both ends of the segment must be outside the box.
	t.eq(spell.seg_count(), 1, "이 틱에 구간이 하나다 (배치를 읽을 수 있다)")
	if spell.seg_count() == 1:
		var ax := Body._fp_px(spell.get_seg_x0()[0])
		var bx := Body._fp_px(spell.get_seg_x1()[0])
		var box_lo := float(stand_x)
		var box_hi := float(stand_x + Defs.w_px(kind))
		t.ok(ax < box_lo or ax > box_hi, "구간 시작(%.1f)이 상자[%d,%d] 밖이다" % [ax, stand_x, stand_x + Defs.w_px(kind)])
		t.ok(bx < box_lo or bx > box_hi,
			"구간 끝(%.1f)도 상자 밖이다 (도약 배치다 — 점 검사면 여기서 못 잡는다)" % bx)

	t.eq(world.monster_count(), 0, "닭이 한 틱 만에 죽어 목록에서 빠진다 (터널링 없이 맞았다)")
	t.eq(world.died_count(), 1, "죽음 통지가 하나 났다")
	if world.died_count() == 1:
		t.eq(world.died_kind(0), kind, "죽음 통지의 종류가 닭이다")


## Measured with the pig — the hen (hp 10) dies in one second at fire's 10 dps, giving only two or three points for "proportional".
## **The only way to measure "regardless of invulnerability" — hit it with a bolt first and measure with invulnerability on.**
##  It is measured by the **fire accumulator** (`_burn_acc`), not hp — the arithmetic of 2 ticks of invulnerability
##  (6 frames) and 10dps x 1/60 overlaps exactly (0.1s = exactly 1 point), so the integer hp subtraction and the
##  invulnerability expiring can land on the same frame. The accumulator builds up by value every frame, so it can already be measured while invulnerability clearly remains.
func _monster_burns_regardless_of_invuln(t) -> void:
	var kind := Defs.KIND_PIG
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
	t.ok(mid > 0, "스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)

	var row_cy := floori((stand_y + Defs.h_px(kind) * 0.5) / float(Tuning.CELL_PX))
	var origin_cx := floori((stand_x - HIT_LEAD_PX) / float(Tuning.CELL_PX))
	world.enqueue(SpellSim.cmd_fire(origin_cx, row_cy, 10, 0, Tuning.ELEM_NONE, Glyph.GLYPH_NONE))
	for _i in Tuning.TICK_DIVIDER:
		world.frame(DT, 0.0, false, false)
	t.ok(m.invuln_left > 0, "탄에 먼저 맞아 무적이 켜졌다 (검사의 전제)")
	t.eq(m.hp, Defs.max_hp(kind) - Character.DAMAGE_HIT, "탄에 맞아 hp가 준다 (검사의 전제)")

	var lit := 0
	for cx in range(cx0, cx1 + 1):
		if g.ignite(cx, FLOOR_CY):
			lit += 1
	t.ok(lit > 0, "발밑 나무 %d칸에 불이 붙었다 (검사의 전제)" % lit)

	world.frame(DT, 0.0, false, false)
	world.frame(DT, 0.0, false, false)
	t.ok(m.invuln_left > 0, "아직 무적이 남았다 (검사의 전제 — 무적과 무관함을 재려면 이게 참이어야 한다)")
	t.ok(m.burning, "불 위에 서 있다고 표시된다 (매 프레임 다시 잰다 — 무적을 안 본다)")
	t.ok(m._burn_acc > 0.0, "무적이 남은 채로도 불 피해 누산기가 쌓인다 (무적을 안 보는 갈래다)")

	# Whether it is shaved proportionally to time is measured by hp. It is looked at through **two short windows**
	#  (20 frames = 1/3 second each, 2/3 second together) — the wood's fuel is exactly 2 seconds, so two 60-frame
	#  windows (= 2 seconds) bring back the coincidence of "the observation window ending just as the fuel runs out" (got burned by it, measured).
	var before := m.hp
	for _i in 20:
		world.frame(DT, 0.0, false, false)
	var after_a := m.hp
	t.ok(after_a < before, "1/3초 뒤 불로 더 깎였다 (시간에 비례한다)")
	for _i in 20:
		world.frame(DT, 0.0, false, false)
	var after_b := m.hp
	t.ok(after_b < after_a, "다음 1/3초에도 계속 깎인다")

	# Inverting it — out of the fire (extinguished) the shaving stops. Instead of natural fuel exhaustion the
	#  wood is laid again to clear the flag (the same trick as `net_damage._burn_acc_survives_tapping` —
	#  re-applying wood is exactly "it left the fire"). Waiting for natural exhaustion can kill the pig first.
	g.apply(CellGrid.cmd_fill(cx0 - 2, FLOOR_CY, cx1 + 2, FLOOR_CY, Mat.WOOD))
	world.frame(DT, 0.0, false, false)
	world.frame(DT, 0.0, false, false)
	t.ok(not m.burning, "불에서 나왔다 (전제)")
	var after_out := m.hp
	for _i in 30:
		world.frame(DT, 0.0, false, false)
	t.eq(m.hp, after_out, "불이 꺼진 뒤에는 더 안 깎인다")


func _dead_monsters_leave_the_list_correctly(t) -> void:
	var frames_to_run := 40
	var kind := Defs.KIND_HEN

	# Control — the same arrangement with nobody dying. a and c's "normal one step" baseline comes from here.
	var control: Dictionary = _three_hens_world()
	var cw: WorldStep = control["world"]
	for _i in frames_to_run:
		cw.frame(DT, 0.0, false, false)
	var expect_a_x: int = cw.monster_at(0).x
	var expect_c_x: int = cw.monster_at(2).x

	# The main check — only the middle one (b) is killed.
	var setup: Dictionary = _three_hens_world()
	var world: WorldStep = setup["world"]
	var ids: Array = setup["ids"]
	var xs: Array = setup["xs"]
	var id_a: int = ids[0]
	var id_b: int = ids[1]
	var id_c: int = ids[2]
	t.ok(id_a > 0 and id_b > 0 and id_c > 0, "셋 다 스폰됐다 (검사의 전제)")
	t.eq(world.monster_count(), 3, "① 시작 시점에 monster_count()가 3이다")

	var b_x0: int = xs[1]
	var b_cx := floori((b_x0 + Defs.w_px(kind) * 0.5) / float(Tuning.CELL_PX))
	world.enqueue(_blast_cmd(b_cx))

	# **A death notification is valid only within that tick** (the same as the blast notification — the next tick
	#  clears it). Read after all 40 frames have run, several more ticks have passed and the notification is empty
	#  (got burned by it, measured). => The notification is caught **on the very tick it dies**.
	var loops := 0
	var died_snapshot_count := -1
	var died_snapshot_kind := -1
	for _i in frames_to_run:
		world.frame(DT, 0.0, false, false)
		loops += 1
		if world.died_count() > 0 and died_snapshot_count == -1:
			died_snapshot_count = world.died_count()
			died_snapshot_kind = world.died_kind(0)
	t.ok(loops > 1, "② 프레임을 실제로 여러 바퀴 돌았다 (%d바퀴)" % loops)
	t.eq(world.monster_count(), 2, "③ b가 죽어 monster_count()가 2다")
	t.eq(died_snapshot_count, 1, "죽는 그 틱에 죽음 통지가 정확히 하나 났다")
	t.eq(died_snapshot_kind, kind, "그 통지의 종류가 닭이다")

	# Measured by id — is only the dead one removed with the rest of the set unchanged.
	var live_ids: Array[int] = []
	for i in world.monster_count():
		live_ids.append(world.monster_at(i).id)
	live_ids.sort()
	var expect_ids: Array[int] = [id_a, id_c]
	expect_ids.sort()
	t.eq(live_ids, expect_ids,
		"죽은 id(%d) 하나만 사라지고 나머지 id 집합(%s)이 그대로다" % [id_b, expect_ids])

	# Measured by position — are a and c in exactly the same place as the control (nobody missed a step).
	var a: Monster = null
	var c: Monster = null
	for i in world.monster_count():
		var mm: Monster = world.monster_at(i)
		if mm.id == id_a:
			a = mm
		elif mm.id == id_c:
			c = mm
	t.ok(a != null and c != null, "살아남은 둘을 id로 찾았다 (검사의 전제)")
	if a != null:
		t.eq(a.x, expect_a_x, "a가 대조군과 정확히 같은 자리다 (「순회 중 제거」였다면 한 걸음을 놓쳤을 것이다)")
	if c != null:
		t.eq(c.x, expect_c_x, "c가 대조군과 정확히 같은 자리다")

	# The death notification itself was already confirmed **on that tick** inside the loop above (died_snapshot_*) —
	#  reading it again here is always empty, because the ticks that have passed since have cleared it.


# ==================================================================
#  stage 4 — there are two of them
# ==================================================================

## **The ledge is stood at 2 or 3 cells** — at 1 cell both cross it, at 4 cells both are blocked.
##  3 was chosen: the pig (`step_cells`=1) is blocked and the hen (`step_cells`=3) crosses.
func _pig_and_hen_cross_the_ledge_differently(t) -> void:
	var ledge_cells := 3
	var ledge_cx := 80
	var g := _bare_grid()
	g.apply(CellGrid.cmd_fill(
		ledge_cx, FLOOR_CY - ledge_cells, FLOOR_W_CX - 1, FLOOR_CY + FLOOR_DEPTH_CY - 1, Mat.STONE))
	var ledge_left_px := ledge_cx * Tuning.CELL_PX

	var measured := 0
	for kind in Defs.ALL:
		# **Bosses are excluded, not silently mis-measured** (`stage1-bosses.md` Stage B) — a charging boss's
		#  stepping is pattern-gated (`Body.move_x`'s `allow_step`), so "does this kind cross a 3-cell ledge"
		#  stops being a pure `step_cells` property for them and depends on *when* it reaches the ledge
		#  relative to its own windup/charge clock. That interaction is measured on its own, deterministically,
		#  by `_charging_bull_does_not_step_a_3cell_ledge` below. This test stays about `step_cells` alone.
		if BossAi.has_pattern(kind):
			continue
		measured += 1
		var spell := SpellSim.new()
		var ch := Character.new()
		# The player is placed well to the right of the ledge — the monster walks from the left toward the ledge (right).
		ch.place(ledge_left_px + 400, FLOOR_TOP - Character.H_PX)
		var world := WorldStep.new(g, spell, ch)
		var stand_x := ledge_left_px - 150
		var mid := world.spawn_monster(kind, stand_x, FLOOR_TOP - Defs.h_px(kind))
		t.ok(mid > 0, "%s 스폰됐다 (검사의 전제)" % Defs.name_of(kind))
		var m: Monster = world.monster_at(0)
		# **The cap was 300, unmeasured.** harness-manager measured all three kinds that reach this loop
		#  (bull is excluded above): the blocked pig stops moving by tick 39, the crossing hen and rooster
		#  both clear `ledge_left_px` by tick 45 (the hen's x keeps drifting after that — toward the far
		#  player, not toward the ledge — up to tick 83). 150 keeps 1.8x headroom over the slowest of those
		#  while cutting the loop in half.
		for _i in 150:
			world.frame(DT, 0.0, false, false)
		if kind == Defs.KIND_PIG:
			t.eq(m.x, ledge_left_px - Defs.w_px(kind),
				"돼지(step=%d)는 %d셀 턱에 막혀 x가 안 는다 (x=%d)"
					% [Defs.step_cells(kind), ledge_cells, m.x])
		else:
			# **Not hardcoded to "닭"** — this branch is every non-pig, non-boss kind in `Defs.ALL` (today
			#  only the hen, but a hardcoded label would print a correct-looking hen line if a third trash
			#  mob's failure landed here, sending the reader to the wrong row).
			t.ok(m.x > ledge_left_px,
				"%s(step=%d)은 %d셀 턱을 넘는다 (x=%d)"
					% [Defs.name_of(kind), Defs.step_cells(kind), ledge_cells, m.x])

	# **The `continue` above has no bark of its own** — a kind later getting a `MOVES` row would silently
	#  drop out of this loop with nothing to notice. Pinning the count closes it (the same medicine
	#  `net_tables._monster_defs_columns_are_complete`'s header already names for a sibling trap).
	#  **The number's history is the point, so all three are recorded**: 3 when only the bull had a `PATTERNS`
	#  row, **2** when Stage F gave the rooster one (this comment predicted that drop and the assertion caught
	#  it), and **3 again** now that the wolf joined `ALL` with no pattern row of its own. Each move was a real
	#  change to what this loop covers, and each was made here by hand rather than by deriving the count —
	#  derived, it would follow any change silently, which is the whole thing this line exists to prevent.
	t.eq(measured, 3, "이 검사가 실제로 잰 종류 수 (패턴 없는 종류들 — 돼지·닭·늑대) (%d개)" % measured)


# ==================================================================
#  stage 5 — the pig hits
# ==================================================================

## Values (1) and (2) — the absolute value (`WorldStep.PIG_CONTACT_DAMAGE`) and the negative control (no overlap,
##  no damage) are measured together. **Measuring only "it deals damage" passes 1 and 100 alike** — the absolute value is this acceptance's real body.
func _pig_contact_damages_the_player(t) -> void:
	var kind := Defs.KIND_PIG
	var stand_x := 400
	var g := _bare_grid()
	var spell := SpellSim.new()
	var ch := _still_ch(stand_x, kind)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, FLOOR_TOP - Defs.h_px(kind))
	t.ok(mid > 0, "스폰됐다 (검사의 전제)")
	for _i in Tuning.TICK_DIVIDER:
		world.frame(DT, 0.0, false, false)
	t.eq(ch.hp, Character.MAX_HP - WorldStep.PIG_CONTACT_DAMAGE,
		"겹치면 정확히 %d 깎인다" % WorldStep.PIG_CONTACT_DAMAGE)
	t.ok(ch.invuln_left > 0, "무적이 켜졌다 (돼지 접촉도 기존 무적을 탄다)")

	# Negative control — stood far enough apart not to overlap. `_still_ch` is not used — that helper lines the
	#  character's centre up with the monster's centre to make them "overlap", which is the exact opposite here.
	#  Only 1 tick is measured so the walking drift (160px/s x 1 tick = 8px) can't touch the 500px gap.
	var far_x := stand_x + 500
	var g2 := _bare_grid()
	var spell2 := SpellSim.new()
	var ch2 := Character.new()
	ch2.place(stand_x, FLOOR_TOP - Character.H_PX)
	var world2 := WorldStep.new(g2, spell2, ch2)
	var mid2 := world2.spawn_monster(kind, far_x, FLOOR_TOP - Defs.h_px(kind))
	t.ok(mid2 > 0, "음성 대조도 스폰됐다 (검사의 전제)")
	for _i in Tuning.TICK_DIVIDER:
		world2.frame(DT, 0.0, false, false)
	t.eq(ch2.hp, Character.MAX_HP, "안 겹치면 안 준다 (음성 대조)")


## Value (3) — it rides invulnerability. **Left overlapping continuously it is not shaved every tick but only
##  once per 5-tick interval** (it uses the same clock `character.on_tick` already wrote down as "5-tick interval
##  = two hits" — `invuln_left` only drops inside `_char.on_tick()`. Written as "4 ticks", this check goes red).
func _pig_contact_respects_invulnerability(t) -> void:
	var kind := Defs.KIND_PIG
	var stand_x := 400
	var g := _bare_grid()
	var spell := SpellSim.new()
	var ch := _still_ch(stand_x, kind)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, FLOOR_TOP - Defs.h_px(kind))
	t.ok(mid > 0, "스폰됐다 (검사의 전제)")

	for _i in Tuning.TICK_DIVIDER:
		world.frame(DT, 0.0, false, false)
	var after_first := ch.hp
	t.eq(after_first, Character.MAX_HP - WorldStep.PIG_CONTACT_DAMAGE, "첫 접촉에 깎인다 (검사의 전제)")

	# 3 more ticks (the 4th cumulative) — still overlapping, but inside invulnerability, so nothing more is shaved.
	for _i in Tuning.TICK_DIVIDER * 3:
		world.frame(DT, 0.0, false, false)
	t.eq(ch.hp, after_first, "무적이 도는 동안은 계속 붙어 있어도 더 안 깎인다")

	# 1 more tick (the 5th cumulative) — invulnerability lifts and it is shaved again.
	for _i in Tuning.TICK_DIVIDER:
		world.frame(DT, 0.0, false, false)
	t.eq(ch.hp, after_first - WorldStep.PIG_CONTACT_DAMAGE,
		"5틱째에 다시 깎인다 (계속 붙어 있어도 초당 4회가 상한이다)")


# ==================================================================
#  stage 6 — the hen shoots
# ==================================================================

## Value — **it has to be measured in open space** (so it isn't confused with being blocked). The distance
##  between the stopping spot and the player must be `BOLT_STOP_PX` +- one step. "Distance" is **centre to centre** (doc acceptance 10).
func _hen_stops_at_bolt_range(t) -> void:
	var kind := Defs.KIND_HEN
	var g := _bare_grid()
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(2000, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, 100, FLOOR_TOP - Defs.h_px(kind))
	t.ok(mid > 0, "스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)
	for _i in 600:
		world.frame(DT, 0.0, false, false)
	var char_center_x := float(ch.x) + Character.W_PX * 0.5
	var dist := absf(char_center_x - m.center().x)
	var step_cap := ceili(Defs.speed_px(kind) * DT)
	t.ok(absf(dist - MonsterBolts.BOLT_STOP_PX) <= step_cap,
		"멈춘 자리와 플레이어의 거리(%.1f)가 BOLT_STOP_PX(%.0f) ± 한 걸음(%d) 안이다"
			% [dist, MonsterBolts.BOLT_STOP_PX, step_cap])
	# **The assertion above is not enough on its own** — the expected value is read straight from
	#  `MonsterBolts.BOLT_STOP_PX`, so even if that constant broke to 0 (the hen sticking like a pig) `0 ~ 0` is green
	#  (measured — the same trap as CLAUDE.md's "the table's value happens to be 2, so baking the accessor to return 2 still gives 2==2").
	#  => "It doesn't stick" is measured separately with a **fixed threshold** independent of the constant — the
	#  distance at which the boxes touch works out geometrically to about 22px (`(20+24)/2`), so a 60px threshold splits it comfortably.
	t.ok(dist > 60.0, "닭이 플레이어에 바짝 안 붙는다 (거리 %.1f — 돼지처럼 들러붙지 않는다)" % dist)

	# **Stopped means stopped — down to the pixel.** `Body.move_x` carries the sub-pixel leftover as a signed
	#  value, so a body that stops with `_rem_x` near 0.5 rounds it to +1, subtracts to -0.5, rounds that to
	#  -1, and **shivers one pixel forever with `dx` exactly 0.** The distance check above cannot see it: the
	#  oscillation averages out and the final position is right either way.
	#  Measured before the fix: **87px of movement across a run that never left the "stopped" state.**
	var jitter := 0
	for _i in 120:
		var before := m.x
		world.frame(DT, 0.0, false, false)
		jitter += absi(m.x - before)
	t.eq(jitter, 0, "멈춘 뒤로는 1픽셀도 안 떤다 (120프레임 누적 %dpx)" % jitter)


## Values (1) and (2) (three negative controls) — it hits a standing player (and rides invulnerability), and
##  **(1) the shooting hen itself (2) another hen on the path (3) a pig on the path are not hit** (the bolt doesn't know monsters at all — `monster_bolts.gd`).
## The bolt is made directly (`world._bolts.spawn`) — waiting for the natural firing cycle lets another hen on
##  the path shoot on its own and mixes the observation. Natural firing and stopping are measured separately by acceptance 10.
func _hen_bolt_hits_only_the_player(t) -> void:
	var hen_kind := Defs.KIND_HEN
	var g := _bare_grid()
	var spell := SpellSim.new()
	var ch := Character.new()
	var row_y := FLOOR_TOP - Defs.h_px(hen_kind) + Defs.h_px(hen_kind) * 0.5
	# The positions are packed near the origin — so the pig and the other hen are "on the path" while having no
	#  time to walk to the player on their own and pollute the observation with contact or natural firing.
	var player_x := 420
	ch.place(player_x, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)

	var shooter := world.spawn_monster(hen_kind, 80, FLOOR_TOP - Defs.h_px(hen_kind))
	var other_hen := world.spawn_monster(hen_kind, 120, FLOOR_TOP - Defs.h_px(hen_kind))
	var pig := world.spawn_monster(Defs.KIND_PIG, 160, FLOOR_TOP - Defs.h_px(Defs.KIND_PIG))
	t.ok(shooter > 0 and other_hen > 0 and pig > 0, "셋 다 스폰됐다 (검사의 전제)")
	var shooter_hp0 := world.monster_at(0).hp
	var other_hen_hp0 := world.monster_at(1).hp
	var pig_hp0 := world.monster_at(2).hp
	# The other hen's **natural firing** is blocked (this check measures only "a bolt fired directly" — natural
	#  firing and stopping are measured separately by acceptance 10). A huge reload is baked in so it never shoots again while this check runs.
	world.monster_at(1).reload_left = 999999

	var bolts: MonsterBolts = world.get("_bolts")
	t.ok(bolts.spawn(80.0, row_y, Vector2(1.0, 0.0)), "탄을 직접 쐈다 (검사의 전제)")

	for _i in 90:
		world.frame(DT, 0.0, false, false)
		if ch.hp < Character.MAX_HP:
			break

	t.eq(ch.hp, Character.MAX_HP - MonsterBolts.BOLT_DAMAGE, "플레이어는 정확히 %d 맞는다" % MonsterBolts.BOLT_DAMAGE)
	t.ok(ch.invuln_left > 0, "플레이어 무적을 탄다")
	t.eq(world.monster_at(0).hp, shooter_hp0, "① 쏜 닭 자신은 안 맞는다")
	t.eq(world.monster_at(1).hp, other_hen_hp0, "② 경로 위 다른 닭도 안 맞는다")
	t.eq(world.monster_at(2).hp, pig_hp0, "③ 경로 위 돼지도 안 맞는다")


## Value (3) — the lifetime axis. **All three have to be measured together to know this axis really split**
##  (measuring only one goes green even with `BOLT_RANGE_PX` reverted to `BOLT_STOP_PX`). Standing still it
##  hits, approaching it hits sooner, and **retreating at 260px/s it cannot in principle hit** (that is the
##  intended result — do not read it as a "fault" and raise the value. The arithmetic is in `monster_bolts.gd`'s box).
func _hen_bolt_lifetime_axis(t) -> void:
	var hit := {}
	for the_case: String in ["stand", "approach", "retreat"]:
		var g := _bare_grid()
		var spell := SpellSim.new()
		var ch := Character.new()
		var start_x := 400
		ch.place(start_x, FLOOR_TOP - Character.H_PX)
		var world := WorldStep.new(g, spell, ch)
		var row_y := float(ch.y) + Character.H_PX * 0.5
		var bolts: MonsterBolts = world.get("_bolts")
		bolts.spawn(100.0, row_y, Vector2(1.0, 0.0))
		var axis := 0.0
		if the_case == "approach":
			axis = -1.0  # approaches the bolt's side (left)
		elif the_case == "retreat":
			axis = 1.0   # retreats to the side away from the bolt (right)
		var got_hit := false
		for _i in 200:
			world.frame(DT, axis, false, false)
			if ch.hp < Character.MAX_HP:
				got_hit = true
				break
		hit[the_case] = got_hit
	t.ok(hit["stand"], "멈춰 있으면 맞는다 (양성 대조 — 없으면 수명 0인 탄도 통과한다)")
	t.ok(hit["approach"], "다가오면 더 빨리 맞는다 (상대 속도가 %.0fpx/s)"
		% (MonsterBolts.BOLT_SPEED_PX + Character.MOVE_SPEED_PX))
	t.ok(not hit["retreat"],
		"%.0fpx/s로 물러나면 안 맞는다 (의도된 결과다 — 「고장」으로 읽고 값을 올리지 마라)"
			% Character.MOVE_SPEED_PX)


## Values (1) and (2) — a player behind a wall is not hit and the bolt disappears. **Not one grid cell changes**
##  (measured with `consume_changed()` — narrower than eyeballing "there is no hole". Without it, an implementation
##  where the bolt calls `carve_r` passes, and that is an easy thing to copy over from the magic bolts).
func _hen_bolt_blocked_by_terrain_and_does_not_carve(t) -> void:
	var wall_cx := 60
	var g := _bare_grid()
	g.apply(CellGrid.cmd_fill(wall_cx, FLOOR_CY - 8, wall_cx + 3, FLOOR_CY - 1, Mat.STONE))
	g.consume_changed()  # sets the baseline to 0
	var spell := SpellSim.new()
	var ch := Character.new()
	var wall_right_px := (wall_cx + 4) * Tuning.CELL_PX
	# The player has to be **within the bolt's range (`BOLT_RANGE_PX`)** — it must be a spot that would actually
	#  be hit if the wall weren't there, so "blocked" and "the range simply ran out" don't get mixed up.
	ch.place(wall_right_px + 90, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var row_y := float(ch.y) + Character.H_PX * 0.5
	var bolt_origin_x := wall_right_px - 200
	t.ok(float(wall_right_px + 90 - bolt_origin_x) < MonsterBolts.BOLT_RANGE_PX,
		"플레이어가 사거리 안이다 (벽이 없으면 맞았을 배치다 — 검사의 전제)")
	var bolts: MonsterBolts = world.get("_bolts")
	bolts.spawn(float(bolt_origin_x), row_y, Vector2(1.0, 0.0))

	for _i in 90:
		world.frame(DT, 0.0, false, false)

	t.eq(ch.hp, Character.MAX_HP, "벽 뒤 플레이어는 안 맞는다")
	t.eq(world.bolt_count(), 0, "탄이 벽에서 사라졌다")
	t.eq(g.consume_changed(), 0, "탄이 지나도 격자가 한 칸도 안 바뀐다 (지형을 안 판다)")


## Value (3) — the tunnelling inequality measured as a number. **It has to be measured with the relative speed
##  to be a real limit** — using the bolt speed alone makes this check lie (the same reason the magic bolts became segment-vs-box).
##  The constants are read and computed with — baking in a number makes this check meaningless the day the bolt speed goes up.
func _hen_bolt_step_stays_inside_the_player_box(t) -> void:
	var relative_step := (MonsterBolts.BOLT_SPEED_PX + Character.MOVE_SPEED_PX) * DT
	t.ok(relative_step < Character.W_PX,
		"(탄 속도 + 플레이어 최대 속도) × 1/60 (%.1fpx)이 상자 짧은 변(%dpx)보다 작다 — 프레임 검사로 충분하다"
			% [relative_step, Character.W_PX])


# ==================================================================
#  stage 7 — four screen things + the corpse
# ==================================================================
#
# The hp bar, the flash, the damage number and the corpse afterimage are measured here. **"It shows up · the colour is right" is for the eye**
#  (acceptance 13 — not measurable headless in principle) — what is measured here is only **whether the values come from the table and the real hp**.
#  Where the hen's bolt actually gets drawn (`_draw()`'s `world.bolt_x/y`) is only reading back the values
#  acceptances 10-12 already measured on the `WorldStep` side, so it is not measured again here — unlike `box_rect()`
#  being `_draw()`'s only source of size, that discipline is kept in code alone (nobody measures it, the box above).
# The **decay curves** of the flash, the damage number and the corpse (how many % the alpha drops by) are not measured —
#  `blast_fx`'s flash curve (`_ease`, `flash_alpha`) isn't measured by a net in this repo either. What is measured
#  here goes as far as **"it showed up · it matches the table value · it disappears on schedule"**.


# -- the hp bar — the values come from the table ------------------
func _hp_bar_values_come_from_the_table(t) -> void:
	for kind: int in Defs.ALL:
		var x := 40
		var y := 60
		var r := MonsterView.hp_bar_rect(kind, x, y)
		t.eq(r.size.x, float(Defs.w_px(kind)),
			"%s 체력바 폭이 상자 폭(%d)과 같다" % [Defs.name_of(kind), Defs.w_px(kind)])
		t.eq(r.position.y, float(y) - Fx.MONSTER_HP_BAR_GAP_PX - Fx.MONSTER_HP_BAR_H_PX,
			"%s 체력바가 상자 위 %.0fpx에 뜬다" % [
				Defs.name_of(kind), Fx.MONSTER_HP_BAR_GAP_PX + Fx.MONSTER_HP_BAR_H_PX])
	t.eq(MonsterView.hp_bar_fill_frac(30, 30), 1.0, "가득 차면 비율 1.0")
	t.eq(MonsterView.hp_bar_fill_frac(0, 30), 0.0, "0이면 비율 0.0")
	t.eq(MonsterView.hp_bar_fill_frac(15, 30), 0.5, "절반이면 비율 0.5")
	t.eq(MonsterView.hp_bar_fill_frac(-5, 30), 0.0, "음수 hp도 0 밑으로 안 내려간다 (죈다)")
	t.eq(MonsterView.hp_bar_fill_frac(999, 30), 1.0, "표보다 큰 hp도 1 위로 안 올라간다 (죈다)")


# -- the hen's bolt colour — it splits from the magic bolts -------
## It is measured as a **distance**, not an absolute value — baking in an exact RGB makes this check go red for
##  no reason the day someone nudges it by feel. What is measured is "far enough apart".
func _monster_bolt_color_differs_from_magic_bolts(t) -> void:
	for elem: int in [Tuning.ELEM_FIRE, Tuning.ELEM_NONE, Tuning.ELEM_WATER]:
		var glow: Color = Fx.ELEM_FX[elem]["glow"]
		t.ok(_rgb_dist(Fx.MONSTER_BOLT_COLOR, glow) > 0.3,
			"닭 탄 색이 마법 탄(원소 %d) 색과 충분히 갈린다" % elem)


# -- the flash · the damage number — only as much as hp dropped, gone on schedule --
## **Disproving hardcoding** — baking the damage number in as a constant could still pass this value itself
##  (it happens to equal `Character.DAMAGE_HIT` right now), but **whether it reads the real hp change** cannot
##  be told apart by one absolute value. => Here "it equals the amount hp dropped" is measured with a constant
##  derived from the table (`Character.DAMAGE_HIT`) to show at least that it is not a coincidence — measuring a second, different damage amount (fire) is outside this check.
func _hit_triggers_flash_and_a_damage_number_that_ages_out(t) -> void:
	var kind := Defs.KIND_PIG
	var stand_x := 600
	var y := FLOOR_TOP - Defs.h_px(kind)
	var g := _bare_grid()
	var spell := SpellSim.new()
	var ch := _still_ch(stand_x, kind)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, y)
	t.ok(mid > 0, "스폰됐다 (검사의 전제)")
	var m: Monster = world.monster_at(0)

	var view := MonsterView.new()
	view.setup(world)
	view.advance()  # snapshots against the pre-hit hp (the table value)
	t.ok(not view.is_flashing(m.id), "맞기 전엔 번쩍이지 않는다 (전제)")
	t.eq(view.dmg_number_count(), 0, "맞기 전엔 피해 숫자가 없다 (전제)")

	var center_cx := floori((stand_x + Defs.w_px(kind) * 0.5) / float(Tuning.CELL_PX))
	world.enqueue(_blast_cmd(center_cx))
	for _i in Tuning.TICK_DIVIDER:
		world.frame(DT, 0.0, false, false)
	t.eq(m.hp, Defs.max_hp(kind) - Character.DAMAGE_HIT, "폭발에 맞아 hp가 준다 (검사의 전제)")

	view.advance()
	t.ok(view.is_flashing(m.id), "hp가 줄면 그 프레임에 번쩍인다")
	t.eq(view.dmg_number_count(), 1, "피해 숫자가 하나 뜬다")
	t.eq(view.dmg_number_amount(0), Character.DAMAGE_HIT,
		"피해 숫자가 실제로 줄어든 양(%d)과 같다 — 하드코딩이면 표를 바꿔도 안 따라온다"
			% Character.DAMAGE_HIT)

	# The flash and the damage number **share the same `advance()` clock** — the damage number keeps ageing while
	#  the flash burns out. => The frames already passed are counted, and the rest is filled in to just **before**
	#  the damage number's lifetime ends (so it isn't tied to the constant's value).
	var elapsed := 0  # the creating call itself doesn't age it (the order in `advance()` above — prune comes first)
	for _i in Fx.MONSTER_FLASH_FRAMES - 1:
		view.advance()
		elapsed += 1
	t.ok(view.is_flashing(m.id), "번쩍 프레임이 아직 안 다했다 (전제)")
	view.advance()
	elapsed += 1
	t.ok(not view.is_flashing(m.id), "%d프레임 뒤 번쩍이 꺼진다" % Fx.MONSTER_FLASH_FRAMES)

	while elapsed < Fx.MONSTER_DMG_NUM_LIFE_FRAMES - 1:
		view.advance()
		elapsed += 1
	t.eq(view.dmg_number_count(), 1, "피해 숫자 수명이 아직 안 다했다 (전제)")
	view.advance()
	t.eq(view.dmg_number_count(), 0, "%d프레임 뒤 피해 숫자가 사라진다" % Fx.MONSTER_DMG_NUM_LIFE_FRAMES)
	# `MonsterView` is a `Node2D`, so it is not `RefCounted` — not freeing it leaks the CanvasItem RID and the
	#  wrapper sees red stderr (the same spot as the last box of CLAUDE.md's "no fake nets" —
	#  measured: leaving out `.free()` made this net fail with "2 RIDs leaked").
	view.free()


# -- the corpse — the death notification is caught on that tick, becomes a corpse, and goes on schedule --
## **It is the first consumer of the death notification `world_step` raises** (team-lead memo). Whether
##  `on_tick()` actually reads the notification, and whether missing that tick makes a corpse impossible in principle, are measured together.
func _death_notification_spawns_a_corpse_that_ages_out(t) -> void:
	var kind := Defs.KIND_HEN
	var stand_x := 600
	var stand_y := FLOOR_TOP - Defs.h_px(kind)
	var g := _bare_grid()
	var spell := SpellSim.new()
	var ch := _still_ch(stand_x, kind)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "스폰됐다 (검사의 전제)")

	var view := MonsterView.new()
	view.setup(world)
	t.eq(view.corpse_count(), 0, "스폰만으로는 시체가 없다 (전제)")

	var center_cx := floori((stand_x + Defs.w_px(kind) * 0.5) / float(Tuning.CELL_PX))
	world.enqueue(_blast_cmd(center_cx))
	var got_death := false
	for _i in Tuning.TICK_DIVIDER * 3:
		var ticked := world.frame(DT, 0.0, false, false)
		if ticked and world.died_count() > 0:
			# It is caught within the tick it dies — the next `frame()`'s tick branch clears the notification
			#  (`world_step.gd` header). Missing it makes this check itself prove the "impossible in principle" side.
			view.on_tick()
			got_death = true
			break
	t.ok(got_death, "닭이 죽어 죽음 통지가 났다 (검사의 전제)")
	t.eq(world.monster_count(), 0, "몬스터 목록에서 빠졌다 (검사의 전제)")
	t.eq(view.corpse_count(), 1, "죽음 통지를 시체 하나로 옮겼다")
	t.eq(view.corpse_kind(0), kind, "시체 종류가 죽은 몬스터와 같다 (닭)")

	for _i in Fx.MONSTER_CORPSE_LIFE_FRAMES - 1:
		view.advance()
	t.eq(view.corpse_count(), 1, "시체 수명이 아직 안 다했다 (전제)")
	view.advance()
	t.eq(view.corpse_count(), 0, "%d프레임 뒤 시체가 사라진다" % Fx.MONSTER_CORPSE_LIFE_FRAMES)
	view.free()  # a `Node2D`, so not RefCounted — freed directly for the same reason as the check above.


# ==================================================================
#  stage 9 — effects from shapes to pictures (acceptance 13, second try)
#
#  **What is here is only the half that can be measured as a value.**
#   The reason acceptance 13 failed was **"the net runs but doesn't measure"** —
#   "the flash lives 6 frames" and "the corpse lives 30 frames" were all green while
#   on screen all three were rectangles. **There is no way to catch shape but the eye.**
#  => What is measured here is **behaviour** (does it merge · does it appear on death · does its position stay put),
#   and **"is it a picture rather than a shape" is left to verify-look.**
# ==================================================================

## **Hit again within a short interval and the numbers merge** (decided by the user).
##
## **On screen three `-10`s overlapped into what looked like `-1000` and covered the hp bar too.**
##  The problem was not that there were three numbers but **that the three overlapped in the same place**.
##
## **Both sides are measured as a pair.** Measuring only "they merge" is green even if **only one number is ever
##  made**, and measuring only "they show separately" is green even with **the merging deleted**.
##  => **The same two hits with only the interval differing** must merge in one case and not in the other.
func _close_damage_numbers_merge_into_one(t) -> void:
	t.ok(Fx.MONSTER_DMG_NUM_MERGE_FRAMES < Fx.MONSTER_DMG_NUM_LIFE_FRAMES,
		"합치는 창이 숫자 수명보다 짧다 — 같으면 숫자가 영영 안 늙는다")

	# -- hit back to back => they merge into one -------------------
	var near := _dmg_number_probe(t, 1)
	t.eq(near[0], 1, "붙여 두 방 맞으면 숫자가 **하나**다 (%d개)" % near[0])
	t.eq(near[1], Character.DAMAGE_HIT * 2,
		"그 하나가 **두 방의 합**이다 (%d) — 표를 바꿔도 따라온다" % near[1])

	# -- hit spaced outside the window => they show separately -----
	# **Without this, "always make just one" passes.**
	var far := _dmg_number_probe(t, Fx.MONSTER_DMG_NUM_MERGE_FRAMES + 1)
	t.eq(far[0], 2, "창 밖으로 띄워 맞으면 숫자가 **둘**이다 (%d개)" % far[0])
	t.eq(far[1], Character.DAMAGE_HIT,
		"그 각각은 **한 방분**이다 (%d) — 합쳐진 게 아니다" % far[1])


## **It pops on death — that is the hen's only hit feedback** (decided by the user).
##
## **A hen dies in one hit, so what the hp diff would look at is already out of the array** => neither the
##  flash nor the number **shows for a single frame.** This check **asserts that first** — otherwise
##  "there is a pop" reads as "there's a flash too, so why bother", and this effect's reason to exist disappears.
##
## **That the pop lives shorter than the corpse** is measured too. Longer and it becomes "it popped and never
##  cleared", which on screen reads as "a ring is left behind".
func _death_also_makes_a_pop_that_outlives_nothing(t) -> void:
	t.ok(Fx.MONSTER_DEATH_POP_FRAMES < Fx.MONSTER_CORPSE_LIFE_FRAMES,
		"터짐이 시체보다 짧게 산다 (%d < %d)"
			% [Fx.MONSTER_DEATH_POP_FRAMES, Fx.MONSTER_CORPSE_LIFE_FRAMES])

	var kind := Defs.KIND_HEN
	var stand_x := 600
	var y := FLOOR_TOP - Defs.h_px(kind)
	var world := WorldStep.new(_bare_grid(), SpellSim.new(), _still_ch(stand_x, kind))
	t.ok(world.spawn_monster(kind, stand_x, y) > 0, "스폰됐다 (전제)")

	var view := MonsterView.new()
	view.setup(world)
	view.advance()
	t.eq(view.death_pop_count(), 0, "스폰만으로는 터짐이 없다 (전제)")

	var cx := floori((stand_x + Defs.w_px(kind) * 0.5) / float(Tuning.CELL_PX))
	world.enqueue(_blast_cmd(cx))
	var got := false
	for _i in Tuning.TICK_DIVIDER * 3:
		var ticked := world.frame(DT, 0.0, false, false)
		if ticked and world.died_count() > 0:
			view.on_tick()   # caught within that tick (the next tick clears the notification)
			got = true
			break
	t.ok(got, "닭이 죽어 죽음 통지가 났다 (전제)")

	# **Why this effect is needed is left behind as a value.**
	view.advance()
	t.eq(view.dmg_number_count(), 0,
		"닭은 한 방에 죽어 **피해 숫자가 한 개도 안 뜬다** — 이 터짐의 존재 이유다")

	t.eq(view.death_pop_count(), 1, "죽음 통지가 터짐 하나를 만들었다")
	t.eq(view.corpse_count(), 1, "시체도 같이 생겼다 (둘이 같은 통지에서 나온다)")

	# One `advance()` was already spent above — only the remaining lifetime is filled in.
	for _i in Fx.MONSTER_DEATH_POP_FRAMES - 2:
		view.advance()
	t.eq(view.death_pop_count(), 1, "터짐 수명이 아직 안 다했다 (전제)")
	view.advance()
	t.eq(view.death_pop_count(), 0, "%d프레임 뒤 터짐이 걷힌다" % Fx.MONSTER_DEATH_POP_FRAMES)
	t.eq(view.corpse_count(), 1, "그런데 **시체는 아직 남아 있다** (둘의 수명이 다르다)")
	view.free()


## **Flames on the body — the positions don't jitter frame to frame and don't stray far outside the box.**
##
## **It was originally one box outline and read as an "orange selection box"** (acceptance 13).
##  Moving to several spots, **picking the positions afresh every frame makes the flames teleport every frame,
##  and that is noise, not fire.** That mistake is **visible on screen only**, so it is pinned as a value here.
##
## **`flame_pos` is pure static, so the net calls it directly** — `_draw` uses only this function, so the value
##  measured here = the position actually drawn (the same idiom as `box_rect`).
func _body_flames_stay_put_and_stay_inside(t) -> void:
	t.ok(Fx.MONSTER_BURN_FLAMES > 1,
		"불꽃이 둘 이상이다 (%d개) — 하나면 옛 「테두리 하나」와 같은 자리다"
			% Fx.MONSTER_BURN_FLAMES)

	var kind := Defs.KIND_PIG
	var r := MonsterView.box_rect(kind, 240, 120)
	var seen: Dictionary = {}
	for i in Fx.MONSTER_BURN_FLAMES:
		var p := MonsterView.flame_pos(r, 7, i)
		# **Calling it once can't measure "it doesn't move"** — it is called twice and checked for equality.
		t.eq(MonsterView.flame_pos(r, 7, i), p, "불꽃 %d 의 자리가 다시 불러도 같다" % i)
		# **A different id must give a different position** — otherwise every monster's fire stands identically.
		t.ok(MonsterView.flame_pos(r, 8, i) != p, "불꽃 %d 는 몬스터가 다르면 자리도 다르다" % i)
		t.ok(r.has_point(p), "불꽃 %d 가 상자 안에 있다 (%s ∈ %s)" % [i, p, r])
		seen[p] = true
		# **It is biased low** — spread evenly it looks like "glitter got stuck on".
		t.ok(p.y >= r.position.y + r.size.y * Fx.MONSTER_BURN_LOW_BIAS - 0.001,
			"불꽃 %d 가 상자 위쪽 %d%% 안에는 안 선다"
				% [i, int(Fx.MONSTER_BURN_LOW_BIAS * 100.0)])

	# **If they all overlap, "several spots" is false** — with the hash dead and returning a constant, every assertion above still passes.
	t.eq(seen.size(), Fx.MONSTER_BURN_FLAMES,
		"불꽃 %d개가 **서로 다른 자리**에 선다 (%d자리)" % [Fx.MONSTER_BURN_FLAMES, seen.size()])


## **Does the flash layer actually get its shader in a real tree.**
##
## **Every other view check in this net stands a `MonsterView.new()` and never puts it in the tree** =>
##  **`_ready()` never runs once.** That is, building the layers, attaching the shader and injecting the colour
##  could **die whole and the rest of this file would be all green.** That hole is plugged here.
## **It was confirmed by measurement before being added**: standing the stage scene headless gave two children,
##  with `monster_silhouette.gdshader` on the first and `flash_color` filled in.
##
## **Whether the injected name really exists in the shader is measured too.** One wrong letter and
##  **nothing happens and there is no error** — `get_shader_parameter` just returns `null`
##  (the same spot as `net_render`'s "false knob" section).
func _flash_layer_gets_its_shader_in_a_real_tree(t) -> void:
	var view := MonsterView.new()
	# **`_ready()` is called directly — it cannot be put in the tree.**
	#  The runner is inside `SceneTree._initialize`, so **`root` has not stood up yet** (measured: trying to add it died).
	#  **So there is one thing this check cannot measure**: "does the engine actually call `_ready`".
	#   That is the engine's guarantee, and what is measured here is **what happens inside it**.
	#   That it runs in a real tree was confirmed separately headless (stage scene · two children · shader attached).
	view._ready()

	t.ok(view.get_child_count() >= 3,
		"`_ready()` 가 레이어를 세웠다 (자식 %d개 — 외곽선 + 번쩍 + 숫자)" % view.get_child_count())

	# **It is found by name. Do not find it by index.**
	#  **Measured**: this used to be `get_child(0)`, and putting the outline layer in front made it
	#   **quietly start measuring the wrong node.** Order is a drawing contract, not a name tag.
	var flash: CanvasItem = view.get_node_or_null(MonsterView.LAYER_FLASH)
	t.ok(flash != null, "번쩍 레이어를 이름(`%s`)으로 찾는다" % MonsterView.LAYER_FLASH)
	if flash == null:
		view.free()
		return
	t.ok(flash.material != null, "번쩍 레이어에 머티리얼이 붙었다")
	if flash.material != null:
		var mat := flash.material as ShaderMaterial
		t.ok(mat != null, "그것이 `ShaderMaterial` 이다")
		t.ok(mat != null and mat.shader != null, "셰이더가 실려 있다")
		if mat != null and mat.shader != null:
			t.eq(mat.shader.resource_path, Fx.MONSTER_FLASH_SHADER,
				"`fx_tuning.MONSTER_FLASH_SHADER` 가 가리키는 바로 그 셰이더다")
			# **It is butted against the names the shader declares — `get_shader_parameter` cannot measure it.**
			#  **It was caught by measurement**: at first this was written as `get_shader_parameter(name) == colour`, but
			#   `ShaderMaterial` **stores and hands back names the shader doesn't even have** => misspelling the name
			#   as `flash_colour` was **still green.** It was a tautology reading back the value it had just written
			#   (CLAUDE.md, "butting catches divergence only and cannot catch disappearance").
			var declared: Dictionary = {}
			for u: Dictionary in mat.shader.get_shader_uniform_list():
				declared[String(u["name"])] = true
			t.ok(declared.size() > 0, "셰이더가 uniform 을 선언한다 (%d개 — 컴파일됐다)" % declared.size())
			t.ok(declared.has(MonsterView.FLASH_COLOR_PARAM),
				"셰이더가 `%s` 를 **실제로 선언한다** (오타면 아무 일도 안 일어난다)"
					% MonsterView.FLASH_COLOR_PARAM)
			t.eq(mat.get_shader_parameter(MonsterView.FLASH_COLOR_PARAM),
				Fx.MONSTER_FLASH_COLOR,
				"그 자리에 `MONSTER_FLASH_COLOR` 가 들어가 있다 (거짓 손잡이가 아니다)")

	# The number layer must have **no** shader — with one, the damage numbers turn into white silhouettes.
	var num: CanvasItem = view.get_node_or_null(MonsterView.LAYER_NUMBER)
	t.ok(num != null, "숫자 레이어를 이름(`%s`)으로 찾는다" % MonsterView.LAYER_NUMBER)
	t.ok(num != null and num.material == null,
		"숫자 레이어에는 머티리얼이 없다 (번쩍 셰이더가 숫자에 새지 않는다)")

	# **The outline layer — the same shader as the flash with a different colour, and **below** the body.**
	#  If `show_behind_parent` goes off, **the outline covers the body and the silhouette turns cream all over.**
	#   That is visible on screen only, so it is pinned as a value here.
	var out: Node2D = view.get_node_or_null(MonsterView.LAYER_OUTLINE)
	t.ok(out != null, "외곽선 레이어를 이름(`%s`)으로 찾는다" % MonsterView.LAYER_OUTLINE)
	if out != null:
		t.ok(out.show_behind_parent,
			"외곽선이 몸 **아래**에 그려진다 (꺼지면 실루엣을 통째로 덮는다)")
		var om := out.material as ShaderMaterial
		t.ok(om != null and om.shader != null, "외곽선 레이어에도 실루엣 셰이더가 실려 있다")
		if om != null and om.shader != null:
			t.eq(om.shader.resource_path, Fx.MONSTER_FLASH_SHADER,
				"번쩍과 **같은 셰이더**다 (둘 다 「실루엣을 단색으로」다)")
			t.eq(om.get_shader_parameter(MonsterView.FLASH_COLOR_PARAM),
				Fx.MONSTER_OUTLINE_COLOR,
				"그런데 **색은 다르다** — 외곽선은 `MONSTER_OUTLINE_COLOR` 다")
			# **If the two share a colour the outline is indistinguishable from the flash** — the reason for splitting the two constants dies.
			t.ok(Fx.MONSTER_OUTLINE_COLOR != Fx.MONSTER_FLASH_COLOR,
				"외곽선 색과 번쩍 색이 서로 다르다")

	view.free()   # even inside the tree `free()` detaches it. Not freeing leaks an RID (the same reason as the checks above).


## **Drawing delegated to a layer is drawn with `canvas.` — a bare `draw_*` is silently discarded.**
##
## **It actually happened. This net was green at the time.**
##  `_draw_dmg_number` hung `draw_string(font, ...)` on the **implicit `self` (= MonsterView)**, but that
##  function is called **inside a child layer's `_draw()`** => MonsterView is not the one drawing, so
##  **the command is silently discarded. No error is raised either.**
##  The only symptom was **"the damage numbers are missing from the screen entirely"**, and the cause was
##   only found once verify-look ran the game and tried setting `_number_layer` to null.
##
## **Behaviour cannot catch it — so the source is read.**
##  The net reads arrays, not the canvas, and headless the renderer is dummy so there are no pixels.
##   Calling `_draw()` directly barks "not drawing" **either way**, so the two can't be told apart.
##  => **This is the spot where CLAUDE.md says "a text check can't prevent it", but this mistake is a syntax
##   problem and text catches it exactly.** What is measured equals the label: "do these functions draw with canvas".
func _layer_draws_go_through_the_canvas_argument(t) -> void:
	var f := FileAccess.open("res://src/view/monster_view.gd", FileAccess.READ)
	t.ok(f != null, "`monster_view.gd` 를 읽는다 (검사의 전제)")
	if f == null:
		return
	var src := f.get_as_text()
	f.close()

	# **The functions a layer calls by delegation.** Only what is listed here falls under this rule —
	#  `_draw_monster` and its kind are drawn by MonsterView itself, so a bare `draw_*` is **correct** there.
	var delegated: Array[String] = ["_draw_flashes", "_draw_numbers", "_draw_dmg_number"]
	# **No regex is used.** A lookbehind would need doubled backslashes in a GDScript string, and that broke
	#  quietly once (a parse error kept the whole net from running).
	#  **The side a reader can verify the rule with their own eyes** is the better one here.
	for name: String in delegated:
		var body := _func_body(src, name)
		t.ok(body != "", "`%s` 를 소스에서 찾았다 (검사의 전제 — 이름이 바뀌면 여기가 먼저 빨개진다)" % name)
		if body == "":
			continue
		var bare := _bare_draw_calls(body)
		t.eq(bare.size(), 0,
			"`%s` 에 수신자 없는 `draw_*` 가 없다 (있으면 화면에서 통째로 사라진다): %s"
				% [name, ", ".join(bare)])
		# **The other side** — drawing nothing at all lets the assertion above pass for free.
		t.ok(body.contains("canvas.") or body.contains("_draw_"),
			"`%s` 가 실제로 무언가를 그린다 (`canvas.` 또는 다른 그리기 함수를 부른다)" % name)

	# **Does `_Layer` hand the canvas over** — without it the functions above cannot receive the argument.
	t.ok(src.contains("fn.call(self)"),
		"`_Layer._draw()` 가 자기 자신을 넘긴다 (`fn.call(self)`)")


# ══════════════════════════════════════════════════════════════════
#  levelup-and-three-picks Stage A — acceptance 8, measured by value
# ══════════════════════════════════════════════════════════════════

## **Damage by value, absolute — not only relative** (the plan's own warning: an A/B comparison alone catches
##  "diverged", never "vanished"). How many hits it actually takes to kill a pig at base power vs at
##  `DUMMY_U` — both counts are checked against the table's own numbers, not only against each other, so a
##  mutation that breaks *both* sides identically (e.g. `power_pct` read but never applied) cannot pass by
##  keeping the two equal.
func _dummy_raises_hits_to_kill_a_pig(t) -> void:
	var kind := Defs.KIND_PIG
	var boost := Glyph.power_pct_of(Glyph.DUMMY_U)
	t.ok(boost > 100, "더미(상)이 실제로 100%%보다 세다 (%d%% — 검사의 전제)" % boost)

	var common := _hits_to_kill(kind, Glyph.GLYPH_NONE)
	var boosted := _hits_to_kill(kind, Glyph.pack([Glyph.DUMMY_U]))

	var want_common := ceili(float(Defs.max_hp(kind)) / float(Character.DAMAGE_HIT))
	var dmg_boosted := Character.DAMAGE_HIT * boost / 100
	var want_boosted := ceili(float(Defs.max_hp(kind)) / float(dmg_boosted))

	t.eq(common, want_common,
		"기본 위력이면 돼지(hp %d)가 %d대에 죽는다 (한 대 %d)" % [Defs.max_hp(kind), want_common, Character.DAMAGE_HIT])
	t.eq(boosted, want_boosted,
		"더미(상)을 실으면 %d대에 죽는다 (한 대 %d — %d%%)" % [want_boosted, dmg_boosted, boost])
	t.ok(boosted < common, "그리고 실제로 더 적은 대수로 죽는다 (%d < %d) — 이것이 「소켓한 문양이 주문을 바꾼다」다" % [
		boosted, common])




# ══════════════════════════════════════════════════════════════════
#  Animation — `docs/design/monsters.md`, "animation is entirely a code gap now"
#
#  **`net_monster_sprite` measures the table and the pure functions; this measures the wiring.**
#   The two together are what stops "the table is right and nothing on screen reads it", which is exactly the
#   state this repo was in before this feature (nine sheets on disk, one of them drawn).
#  **What no net here can see is whether the sheet in a slot really is that animation** — the eye's, in
#   principle (`character_view.pick_state`'s own note).
# ══════════════════════════════════════════════════════════════════

## Walking is diffed against the previous frame's x, inside the view. Measured by **letting the monster
##  actually walk** — a pig with the player far to its right — rather than by poking `_prev_x`, because what
##  can break here is the wiring between `advance()` and the world, not the arithmetic.
##
## **The standing half is measured first and from the same node**, so "it always returns WALK" cannot pass.
func _a_walking_monster_reaches_the_walk_state(t) -> void:
	var kind := Defs.KIND_PIG
	var stand_x := 200
	var g := _bare_grid()
	var spell := SpellSim.new()
	# The player is far to the right, so the pig walks toward it and never reaches contact (no shove pose).
	var ch := Character.new()
	ch.place(stand_x + 900, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, FLOOR_TOP - Defs.h_px(kind))
	t.ok(mid > 0, "돼지가 섰다 (검사의 전제)")

	var view := MonsterView.new()
	view.setup(world, ch, g)
	# The very first `advance()` has no previous x yet — that is the "a spawn must not walk for one frame"
	#  discipline `character_view.setup()` records, and it is measured, not assumed.
	view.advance()
	t.eq(view.anim_state(mid), Fx.MON_IDLE, "본 첫 프레임은 서기다 (스폰이 한 프레임 걷지 않는다)")

	var walked := false
	var moved_px := 0
	for _i in 30:
		world.frame(DT, 0.0, false, false)
		view.advance()
		if view.anim_state(mid) == Fx.MON_WALK:
			walked = true
	moved_px = absi(world.monster_at(0).x - stand_x)
	t.ok(moved_px > Fx.MONSTER_WALK_PX_PER_FRAME,
		"돼지가 걸음 시계 한 칸(%dpx)보다 멀리 갔다 (%dpx — 검사의 전제)" % [Fx.MONSTER_WALK_PX_PER_FRAME, moved_px])
	t.ok(walked, "움직이는 동안 걷기 상태에 들어갔다")
	# **The cell actually advanced too** — the state alone would stay green with a frozen clock.
	t.ok(MonsterView.frame_index(Fx.MON_WALK, MonsterView.anim_row(kind, Fx.MON_WALK), 0, moved_px) > 0,
		"그만큼 걸었으면 걷기 칸도 0번을 지났다 (다리가 얼지 않는다)")
	view.free()


## **A hit puts the hurt pose up, and it stays up longer than the flash.** That gap is the whole reason
##  `_hurt_left` exists as its own latch — driven off `_flash_left` (6 frames) the 12-frame hurt sheet would
##  be cut at its second cell and never reach its last (`monster_view._hurt_left`'s own box).
func _a_hit_puts_the_hurt_pose_up_for_its_whole_length(t) -> void:
	var kind := Defs.KIND_PIG
	var stand_x := 600
	var g := _bare_grid()
	var spell := SpellSim.new()
	var ch := _still_ch(stand_x, kind)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, FLOOR_TOP - Defs.h_px(kind))
	var view := MonsterView.new()
	view.setup(world)
	view.advance()

	var hurt_len := MonsterView.oneshot_frames(kind, Fx.MON_HURT)
	t.ok(hurt_len > Fx.MONSTER_FLASH_FRAMES,
		"맞기 애니메이션(%d프레임)이 번쩍임(%d프레임)보다 길다 (전제 — 같으면 아래가 공회전한다)" % [
			hurt_len, Fx.MONSTER_FLASH_FRAMES])

	var center_cx := floori((stand_x + Defs.w_px(kind) * 0.5) / float(Tuning.CELL_PX))
	world.enqueue(_blast_cmd(center_cx))
	var hit := false
	for _i in Tuning.TICK_DIVIDER * 3:
		world.frame(DT, 0.0, false, false)
		view.advance()
		if view.anim_state(mid) == Fx.MON_HURT:
			hit = true
			break
	t.ok(hit, "맞은 프레임에 맞기 자세가 올라왔다")
	t.ok(world.monster_count() == 1, "아직 살아 있다 (검사의 전제 — 죽으면 상태가 사라진다)")

	# It survives past the flash going out — the point of the separate latch.
	for _i in Fx.MONSTER_FLASH_FRAMES:
		view.advance()
	t.ok(not view.is_flashing(mid), "번쩍임은 이미 꺼졌다 (전제)")
	t.eq(view.anim_state(mid), Fx.MON_HURT, "번쩍임이 꺼진 뒤에도 맞기 자세가 남아 있다")
	# And it does end — a latch that never expires would freeze the pose.
	for _i in hurt_len:
		view.advance()
	t.ok(view.anim_state(mid) != Fx.MON_HURT, "%d프레임 뒤에는 맞기 자세가 끝난다" % hurt_len)
	view.free()


## **The corpse is the death sheet played by its own age.** Measured as "the cell advances and then stops" —
##  a corpse that wrapped back to cell 0 would be the beast twitching back to life mid-fade.
##
## **It reads `view.corpse_frame()`, not `frame_index()`.** Found by inversion: an earlier version of this
##  check drove the arithmetic directly, and freezing `_corpse_art` on cell 0 — which is the whole bug this
##  exists to catch — left it green. The query goes through the same function that produces the drawn rect
##  (that query's own box).
func _a_corpse_plays_its_death_sheet_through(t) -> void:
	var kind := Defs.KIND_HEN
	var last := int((MonsterView.anim_row(kind, Fx.MON_DEATH) as Dictionary)["frames"]) - 1
	t.ok(last > 0, "닭 죽기 시트가 두 칸 이상이다 (전제)")

	var stand_x := 600
	var g := _bare_grid()
	var spell := SpellSim.new()
	var world := WorldStep.new(g, spell, _still_ch(stand_x, kind))
	world.spawn_monster(kind, stand_x, FLOOR_TOP - Defs.h_px(kind))
	var view := MonsterView.new()
	view.setup(world)

	var center_cx := floori((stand_x + Defs.w_px(kind) * 0.5) / float(Tuning.CELL_PX))
	world.enqueue(_blast_cmd(center_cx))
	for _i in Tuning.TICK_DIVIDER * 3:
		if world.frame(DT, 0.0, false, false) and world.died_count() > 0:
			view.on_tick()
			break
	t.eq(view.corpse_count(), 1, "시체가 하나 생겼다 (검사의 전제)")
	t.eq(view.corpse_frame(0), 0, "시체는 0번 칸에서 시작한다")

	var seen: Array[int] = [0]
	while view.corpse_count() > 0:
		view.advance()
		if view.corpse_count() == 0:
			break
		var i := view.corpse_frame(0)
		if seen[-1] != i:
			seen.append(i)
	t.eq(seen[-1], last, "시체 수명이 다하기 전에 마지막 칸(%d번)까지 간다" % last)
	t.eq(seen.size(), last + 1, "칸이 한 번씩 순서대로 지나간다 (되감기지 않는다 · %s)" % [seen])
	view.free()
