extends RefCounted
## The character takes damage — `character-damage-minimum.md`.
##
## **All six stages are in here** — tick order (0), health / direct hit / blast / invulnerability (2), fire over time (3),
##  recoil (5), knockdown (6). **Acceptance 4 (does a hit push me) was deleted along with the feature** — there is a marker in its place below.
##
## **The point of this net is "the net calls `frame()` too".**
##  If only the shell calls `frame()`, the net cannot stand up a scene and **copies the order by hand**, and at that moment
##  **the net starts measuring something different from the game.** => The behavior checks below are that second caller.
##
## **Every check below came out of "a mutation that actually got through".** What each one blocks:
##
## | what got through | what bites now |
## |---|---|
## | deleting the whole body of `frame()` | four behavior checks at once (tick, fuel, bolt, fire count) |
## | the shell taking the order back via a local alias | the `.step(` needle (**the call shape**, not the name) |
## | `_world` being born holding three nulls | `_null_world_refuses` plus `world_step._init`'s bark |
## | reversing **only the declaration order** (text unchanged) | the same — **text cannot catch it in principle** |
## | the bolt flying at double speed | the first tick's displacement, **derived from the generation table** and compared |
## | swapping `grid.step()` and `spell.step()` | `_tick_order_is_grid_then_spell` (the disappearing-cell gauntlet) |
## | pushing `_drain_queue()` later | the ignite command's fuel, and the first tick's displacement |
## | renaming `_broken` | `raw is bool` (**it goes red instead of disappearing**) |
## | `enqueue()` outside the guard | a command is pushed into a broken world — "it does not blow up" is caught by **the wrapper** |
## | `spawn_monster()` outside the guard | a monster is created in a broken world (it actually got through during
##  `monsters-minimum` verification — a newly added public mutator was not going through this door) |
##
## **It is coupled to three private names in the shell and the world**: `_world`, `_broken`, `_queue`.
##  Rename one and this net goes red, and **the label says in one line what to fix.** An accepted coupling.
##
## **What a text check cannot see in principle**: a call not written as `.step(` (`callv("step")` and the like).
##  That is the limit of this shape check; do not widen the label that far.
## **What this net cannot measure in principle**: the shell **holding** `frame()` while not calling it
##  (short-circuit evaluation and so on). `_physics_process` is scene tree, so it is outside headless — screen verification fills that in.

## **Borrows** the comment/string stripper — several nets sweep source text and there must be exactly one stripper.
const NetDeterminism := preload("res://tests/nets/net_determinism.gd")

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const SpellSim := preload("res://src/sim/spell_sim.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const Character := preload("res://src/actor/character.gd")
## `_fp_px` and `_cell_px` moved to `Body` in `monsters-minimum` stage 3 (the second extraction).
const Body := preload("res://src/actor/body.gd")
const Staff := preload("res://src/actor/staff.gd")
const WorldStep := preload("res://src/actor/world_step.gd")
const MonsterDefs := preload("res://src/actor/monster_defs.gd")

const STAGE_SCRIPT := "res://src/stage/stage.gd"
const STAGE_SCENE := "res://src/stage/stage.tscn"
const WORLD_STEP_PATH := "res://src/actor/world_step.gd"

## The call that must not appear in the shell. **It is `.step(`, not `_grid.step(`** —
##  pin the name narrowly and two lines of `var g := _grid; g.step()` detour around it, and then the grid can run
##  **twice per tick** while this check stays green (measured).
const ORDER_CALLS: Array[String] = [".step("]

## **Samples that measure the detector itself.** Get one character of the needle wrong and the check below **passes forever** —
##  it looks for something that does not exist, so it is always "absent". That is the only way this shape check dies, so it is measured first.
## The last two are the **local alias detour.** Their presence here is the reason the needle was made broad.
const MUST_CATCH: Array[String] = [
	"\t_grid.step()",
	"\t_spell.step(_grid)",
	"\t_char.step(_grid, delta, 0.0, false)",
	"\tg.step()",
	"\ts.step(g)",
]

## The other side. Too broad a needle bites the shell's normal work too, and that pressure ends in
##  the check being switched off. The last line also measures **whether the stripper is wired in.**
const MUST_PASS: Array[String] = [
	"\t_grid.apply(CellGrid.cmd_reset())",
	"\tif _world.frame(delta, 0.0, false):",
	"\t_spell_view.on_tick()",
	"\t# _grid.step() 을 주석에 적는 것은 안 걸린다",
]

## The shape in which the shell constructs `WorldStep`. **Pass three nulls and the whole screen stops while
##  the net stays entirely green** (measured) — there is only one construction site in the repo, so it is measured here.
##  What is measured is **the names written as arguments**, not "they are not null at runtime".
const NEW_CALL_RE := "WorldStep\\.new\\(\\s*_grid\\s*,\\s*_spell\\s*,\\s*_char\\s*\\)"

const DT := 1.0 / 60.0

## **The position constants below were all doubled at the 32px switch. The reason is subtle, so it is written here once.**
##  The cell is **still 4px** while every length in the game doubled — the box (16 -> 32px), launch speed (10 -> 20 cells/tick),
##  blast radius (12 -> 24 cells). => **Leave the layout in cells as it was and the relative distances halve**, so what this
##  net measured changes entirely. It actually happened:
##   · a position said to be **outside** the blast radius ended up **inside** it
##   · the two blasts started breaking each other's footing, so the premise "two on the same tick" broke
##  => **Positions doubled; frames, ticks and counts unchanged.** Direction (`AIM_DX`) is not a distance, so it is unchanged too.

## The floor's top cell. The same place as in `net_character` — the standing height is obtained the same way.
const FLOOR_CY := 200
const FLOOR_TOP := FLOOR_CY * Tuning.CELL_PX
const STAND_X := 320

## **The floor is laid thin** (CLAUDE.md, "when the net is slow..."). The old floor (down to `CellGrid.H-1`) was
##  4096x808 = 3,309,568 cells, several seconds each time — a large part of the 99 seconds this file ate of the whole net run.
##  Why it is safe: `cell_grid.mat_at()` returns `STONE` outside the grid, so there was never a reason for it to be thick.
##  **`PIT_BOTTOM_CY` (220) has to fit inside this** — at 32 cells the range is 200-231, so it fits (11 cells to spare).
##  The blast-carves-terrain checks live here too, so it is also 4 times the margin of `carve_r` (8 cells).
const FLOOR_DEPTH_CY := 32

## Launch origin (cells). It has to be far from any wall — on impact the bolt disappears and "did it advance" cannot be measured.
const FIRE_CX := 80
const FIRE_CY := 100
## **Axis-aligned aim.** Diagonally, `_launch`'s integer square root truncation gets in the way and the one-tick
##  displacement cannot be derived from the generation table alone — then the expected value gets hardcoded, and that is the road to two copies of a value.
const AIM_DX := 10
## Where the bolt is born (fixed point). `_launch` births it at the **center** of the cell.
const FIRE_ORIGIN_FP := (FIRE_CX << SpellSim.FP_SHIFT) + SpellSim.FP_HALF

## How many cells right of the launch origin the gauntlet cell sits. It has to be **within the first tick's leap**
##  (generation 0 speed times drag). **The margin shrank when speed went 20 -> 12** — the leap was about 18 cells
##  and is now **11.25** (12 cells x 240/256 = 45px), so the bolt born in cell `FIRE_CX` ends the first tick in
##  cell `FIRE_CX + 11`.
## **10 was left with 1 cell to spare and that is too thin** — one more nudge to `speed` and the gauntlet stops
##  being crossed, at which point `_run_gauntlet`'s main branch measures nothing. **8 leaves 3 cells.**
##  Moving it nearer costs nothing: the control ("fire one tick early and it is blocked") does not read the
##  distance, and `end_cx > wx` holds by a wider margin, not a narrower one.
##  Put it **outside** the leap and the gauntlet is never crossed and the check spins idle.
const GAUNTLET_DCX := 8

# ─── The stage for acceptance 1 and 3 ──────────────────────────────
# **Everything is measured with "no element plus no glyph"** (design doc). With a fire rune the impact burns the footing,
#  and with a blast glyph the terrain changes => "it hit" and "the terrain changed and that is why" get mixed.
#  The blast acceptance is the one exception (a blast needs a blast glyph).

## A launch origin **at the same height, to the character's left.** This far left of the box.
## It has to be a position that crosses the box **on the first tick** — take two ticks and gravity gets involved,
##  "on which tick does it hit" wobbles, and acceptance 3-2's tick-interval control collapses entirely.
##
## **36 -> 12 when `speed` went 20 -> 12.** The first-tick leap is `speed * CELL_PX * DRAG_NUM / DRAG_DEN`
##  = 12 x 4 x 240/256 = **45px** (it was 75px at speed 20), and the character's box is `Character.W_PX` = 20px.
##  => The born point has to land in the window **`(ch.x - 25, ch.x)`** — nearer than 25px or the far end stops
##  short of the box's right side, and past `ch.x` the near end starts *inside* the box. At 36 the far end landed
##  at `ch.x + 11`, **inside**, and that is the assertion in `_direct_hit_costs_hp` that went red.
## The value is a lead in px but the origin is quantized to a **cell** (`floori(.../4)`), so what matters is the
##  born point: at 12 it is `ch.x - 10`, leaving **10px** to the near end of the window and **15px** to the far
##  end. Cell quantization moves it by at most 3px, so neither margin drops below 10px.
## **Derived from the character's x. Do not hardcode it** — if a shot after the character has moved silently misses,
##  the invulnerability check becomes meaningless because "the second bolt missed".
##  The occasion for this discipline (the character had been pushed sideways by knockback) **disappeared along with knockback.**
##   The discipline stays — recoil, gravity and input still move the character.
const HIT_LEAD_PX := 12
const HIT_ORIGIN_CY := 194

## The launch origin for measuring recoil alone (**outside the box to the right**). Firing right from here, the bolt does not cross the box.
##  The reason this position was chosen ("if it crosses, the direct hit's push adds to the recoil and flips the sign") **disappeared
##   along with knockback.** The position stays — with the bolt not crossing the box **only the recoil is left**, so the layout is still the cleanest.
const RECOIL_CX := 88

## The blast acceptance — driven straight down into the floor **beside** the character.
## The bolt **must not cross** the box. If it does, direct hit and blast mix and "what did it get hit by" cannot be split.
const BLAST_FROM_CY := 180

## **The blast position is derived from the radius. Hardcode a cell number and it is guaranteed to go stale.**
##  `BLAST_CX 104`, `BLAST_L_CX 62` and `FAR_STAND_X 192` used to be hardcoded here, and the day `rd` dropped
##   24 -> 12 the two positions said to be "standing inside the radius" **fell outside** and three blast checks went red.
##  **Going red was the lucky direction.** Grow the radius instead and a position said to be "standing outside"
##   quietly comes inside, and then inversion 1 **becomes meaningless with nobody barking.**
##   At the 32px switch `FAR_STAND_X` was breached in exactly that direction — it went red and got caught then,
##    but that was because the position happened to be near the boundary, not because the structure blocked it.
##
## The near position is **60%** of the radius out from the box's side, and "far" is **1.5 times** the radius from the blast center.
##  · at 0% the bolt crosses the box and **direct hit and blast mix**
##  · around 100% a single cell's rounding flips "inside/outside" and the check becomes precarious
const BLAST_NEAR_RATIO := 0.6
const BLAST_FAR_RATIO := 1.5

## A stone column **between** the launch origin and the box. It has to be a position that does not touch the box —
##  if it touches, "blocked by the wall" and "hit the box" get mixed.
##
## **76 -> 78 when `HIT_LEAD_PX` went 36 -> 12.** The origin moved right with the lead (born point `ch.x - 10`,
##  cell 77), so cell 76 ended up **behind the muzzle** — the bolt was born past the wall, flew the whole tick and
##  hit the character. Two of the three assertions in `_wall_stops_the_segment` went red together, which is the
##  shape that check was built to have. The origin cell (77) is not checked by `_walk` (it is the muzzle), so the
##  wall has to sit strictly between 77 and the box's left edge (cell 80): **78 leaves a 4px gap to the box.**
## **One cell, and that is measured, not assumed.** This comment briefly said two cells were needed, copying
##  `_run_gauntlet`'s reasoning ("gravity drops the bolt a row inside the first tick, so a one-cell wall is
##  missed underneath"). **That sentence is true there and false here**, and verify-read caught it by driving
##  the path out:
##
##      this check   `[(78,196),(79,196),(80,196),(81,196),(82,196),(83,197),...]`
##      _run_gauntlet   the y step lands on cell 86 and the gauntlet at 88 is crossed on row 101
##
##  The single y step Bresenham takes for `dx` 11 / `dy` 1 falls near the **middle** of the leap. The wall sits
##  one cell past the muzzle, so it is met on the **first** step, always on the launch row; the gauntlet sits
##  ten cells out, past the step, which is why **it** genuinely needs two. Reducing this one to one cell leaves
##  every assertion green (measured). **Do not copy a rationale between the two — the distance decides it.**
const WALL_CX := 78

## Vertical direct hit — straight down from **right above** the box. The only layout that goes through `_slab`'s axis-parallel branch.
const VERT_CX := 80
const VERT_FROM_CY := 170

## **The `FEET_CY` constant was deleted. The under-foot origin now comes from `Staff.tip_px()`**
##  (inside `_firing_down_does_not_lift_me`). The old value was `FLOOR_CY + 5` and depended on "36px below the
##  center = inside the floor", and that premise became false once the staff got shortened by terrain.
##  The comment there said of itself "**+4 was green too — the net cannot tell these apart**" =>
##   deriving it by hand again would be **putting a new value into the same trap.** It was never an assertion but **a layout**,
##   and a layout has to come from the real code to stay fresh (`_blast_r_px` and `_aim_row` already speak that way).

## The wood under the feet. The cells where the character stands are **empty, so fuel is 0**, and the fire catches here.
##  Stone is laid underneath — when the wood burns out it **becomes empty and the floor disappears**, so
##   without the stone "no damage because the fire went out" and "no damage because it fell" get mixed (plan inversion).
const WOOD_CY := FLOOR_CY
const WOOD_CX0 := 78
const WOOD_CX1 := 90

## The window (frames) for measuring "is it proportional to time". **Both windows plus the search before them have to fit inside the wood's lifetime (2 seconds).**
const BURN_WINDOW := 50

## The length of one step (frames). It has to be **shorter than the 6 frames that accumulate 1 point** for it to be "tapping".
const TAP_FRAMES := 5

## The window (frames) for measuring recoil = 0.5 seconds. **Input comes in forever while recoil decays**, so a long
##  window necessarily returns to the start — what is measured is "while the recoil runs, does it beat the input".
const RECOIL_WINDOW := 30

## A glyph list `fire()` rejects. The id is not in the table, so `_valid_glyphs` barks and drops it.
const BAD_GLYPHS := 15

## The bottom of the pit the downed character falls into. Left and right are **derived from the character's position** —
##  hardcode them and the pit appears in the wrong place the moment the character moves a little.
##  The occasion for this discipline (knockback pushed it far away over ten hits) **disappeared along with knockback.**
const PIT_BOTTOM_CY := 220

## Frames spent waiting for the residual recoil to die down. It is exponential decay, so **it never reaches exactly 0** —
##  at 30 frames 6px drifted and the incapacitation check went red (measured, from when knockback existed).
const SETTLE_FRAMES := 120


func run(t) -> void:
	_stage_does_not_own_the_order(t)
	_null_world_refuses(t)
	_stage_world_actually_runs(t)
	_divider_and_phase(t)
	_grid_lives_one_tick_per_tick(t)
	_enqueue_becomes_a_projectile(t)
	_queue_lands_before_the_grid_lives(t)
	_tick_order_is_grid_then_spell(t)
	_character_moves_every_frame(t)
	_reset_clears_the_queue(t)
	_direct_hit_costs_hp(t)
	_direct_hit_scales_with_power(t)
	_direct_hit_takes_the_max_power(t)
	_vertical_hit_costs_hp(t)
	_wall_stops_the_segment(t)
	_place_revives(t)
	_blast_hit_costs_hp(t)
	_same_tick_two_blasts_cost_one(t)
	# -- glyph-condense §11.6 Step 2 — the pillar is a rectangle, not a circle --
	_pillar_hit_is_rectangular(t)
	_pillar_does_not_hit_above_its_own_top(t)
	_invuln_ticks_down_once_per_tick(t)
	_invuln_lasts_four_ticks(t)
	_spread_hit_count_is_recorded(t)
	_fire_burns_through_invuln(t)
	_burnout_stops_the_damage(t)
	_burn_acc_survives_tapping(t)
	_firing_pushes_me_back(t)
	_recoil_decays(t)
	_firing_down_does_not_lift_me(t)
	_rejected_fire_has_no_recoil(t)
	_zero_hp_downs_me(t)
	_downed_cannot_fire(t)
	_ten_hp_still_walks(t)


# ── The shell does not own the order (text) ────────────────────────

func _stage_does_not_own_the_order(t) -> void:
	_detector_self_test(t)

	var raw := _read(STAGE_SCRIPT)
	# **If the read fails, `src` is an empty string and every "absent" below passes for free.**
	#  The same device as the first line of the folder-scanning nets.
	t.ok(raw.length() > 0, "stage.gd 를 읽었다 (%d바이트)" % raw.length())
	t.ok(not raw.contains("\"\"\""), "stage.gd 에 삼중 따옴표가 없다 (스트리퍼가 못 다룬다)")
	var src := NetDeterminism._strip(raw)
	# If the stripper eats the whole file, everything below still passes. Whether code is left is checked first.
	t.ok(src.contains("func _physics_process("),
		"스트립 뒤에도 stage.gd 에 코드가 남아 있다 (아래 검사의 전제)")

	for needle: String in ORDER_CALLS:
		t.ok(not src.contains(needle), "stage.gd 에 `%s` 호출이 하나도 없다" % needle)

	# **It is a string, so it disappears after stripping** — preload paths are measured in the raw source.
	t.ok(raw.contains(WORLD_STEP_PATH), "stage.gd 가 `%s` 를 preload 한다" % WORLD_STEP_PATH)
	# Measuring only "it does not own it" leaves **a shell that pushes nothing** green too. The pushing side is measured alongside.
	t.ok(src.contains("_world.frame("), "stage.gd 가 `_world.frame(` 으로 세상을 민다")

	var re := RegEx.new()
	t.eq(re.compile(NEW_CALL_RE), OK, "생성 패턴이 컴파일된다")
	t.ok(re.search("var _world := WorldStep.new(_grid, _spell, _char)") != null,
		"감지기가 정상 생성을 통과시킨다")
	t.ok(re.search("var _world := WorldStep.new(null, null, null)") == null,
		"감지기가 null 셋을 안 통과시킨다")
	t.ok(re.search(src) != null,
		"stage.gd 가 `WorldStep.new()` 에 `_grid`·`_spell`·`_char` 를 넘긴다")


## The samples are measured **after passing through the stripper.** It only means something if the text is the same text the real check sees.
func _detector_self_test(t) -> void:
	for sample: String in MUST_CATCH:
		t.ok(_hits(NetDeterminism._strip(sample)), "감지기가 문다: %s" % sample.strip_edges())
	for sample: String in MUST_PASS:
		t.ok(not _hits(NetDeterminism._strip(sample)), "감지기가 안 문다: %s" % sample.strip_edges())


func _hits(line: String) -> bool:
	for needle: String in ORDER_CALLS:
		if line.contains(needle):
			return true
	return false


# ── Does the world actually run (behavior) ─────────────────────────
# **A text check cannot stand in for this** (CLAUDE.md, "looks at whether it is called but not whether it is used").
#  What follows is the only automatic check of `frame()`, `enqueue()`, `reset()`, `phase()` and `fire_count()`.

## Does the tick rise per the divider, and does the phase rise every frame.
func _divider_and_phase(t) -> void:
	var g := _floor_grid()
	var w := _world(g)

	var early := 0
	for _i in Tuning.TICK_DIVIDER - 1:
		if w.frame(DT, 0.0, false, false):
			early += 1
	t.eq(early, 0, "분주기 직전 %d프레임은 틱이 아니다" % (Tuning.TICK_DIVIDER - 1))
	t.eq(g.get_tick(), 0, "그동안 격자 틱이 0 그대로다")
	t.eq(w.phase(), Tuning.TICK_DIVIDER - 1, "위상이 프레임마다 하나씩 오른다")

	t.ok(w.frame(DT, 0.0, false, false), "%d번째 프레임에 frame()이 참을 준다" % Tuning.TICK_DIVIDER)
	t.eq(g.get_tick(), 1, "그 프레임에 격자 틱이 1 올랐다")
	t.eq(w.phase(), 0, "틱 프레임에 위상이 0으로 돌아온다")

	# Once could be luck — ten more periods are run to measure the **ratio.**
	var more := 0
	for _i in Tuning.TICK_DIVIDER * 10:
		if w.frame(DT, 0.0, false, false):
			more += 1
	t.eq(more, 10, "%d프레임에 틱이 정확히 10번이다" % (Tuning.TICK_DIVIDER * 10))
	t.eq(g.get_tick(), 11, "격자 틱이 11이다 (프레임을 세는 게 아니다)")


## **Measured by fuel, not by the tick counter.** Looking only at the counter measures "who incremented a number",
##  not "did the grid live", and the two are different.
func _grid_lives_one_tick_per_tick(t) -> void:
	var g := _floor_grid()
	var wx := 10
	var wy := FLOOR_CY - 1
	g.apply(CellGrid.cmd_fill(wx, wy, wx, wy, Mat.WOOD))
	t.ok(g.ignite(wx, wy), "나무 한 칸에 불이 붙었다 (검사의 전제)")
	var fuel0 := g.fuel_at(wx, wy)
	t.ok(fuel0 > Tuning.FIRE_BURN_PER_TICK,
		"연료가 한 틱치보다 많다 (%d > %d — 검사의 전제)" % [fuel0, Tuning.FIRE_BURN_PER_TICK])

	var w := _world(g)
	for _i in Tuning.TICK_DIVIDER - 1:
		w.frame(DT, 0.0, false, false)
	t.eq(g.fuel_at(wx, wy), fuel0, "틱이 아닌 프레임에는 불이 한 톨도 안 탄다")
	w.frame(DT, 0.0, false, false)
	t.eq(g.fuel_at(wx, wy), fuel0 - Tuning.FIRE_BURN_PER_TICK,
		"틱 프레임에 연료가 딱 한 틱만큼 준다 (두 번 돌지 않는다)")


## A queued command becomes a bolt on the next tick, and **how far** that bolt moves.
##
## **Ending at "it advanced" leaves it green even when the bolt flies at double speed** (measured: a mutation calling
##  `spell.step()` twice passed straight through). The grid axis measures **quantity** by fuel, so having only the projectile
##  axis measure direction is asymmetric within one file. => It is **compared** against a value derived from the generation table.
## And this displacement is also **"the command drained before `spell.step()`"** —
##  push it later and the newborn bolt does not move on that tick, so the displacement is 0.
func _enqueue_becomes_a_projectile(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var w := WorldStep.new(g, spell, _stander())
	w.enqueue(_fire_cmd())
	t.eq(spell.active_count(), 0, "큐에 넣은 것만으로는 탄이 안 난다")
	t.eq(w.fire_count(), 0, "큐에 넣은 것만으로는 발사 수가 안 오른다")

	_frames(w, Tuning.TICK_DIVIDER)
	t.eq(spell.active_count(), 1, "다음 틱에 탄이 실제로 났다")
	t.eq(w.fire_count(), 1, "발사 수가 1 올랐다")

	# With no bolt, the `[0]` below blows up and **the check disappears instead of going red.** The premise is asserted first.
	if spell.active_count() != 1:
		t.ok(false, "탄이 없어서 변위를 **하나도 못 쟀다**")
		return
	var vx1 := _drag(_speed_fp())
	t.eq(spell.get_px()[0] - FIRE_ORIGIN_FP, vx1,
		"첫 틱 변위가 세대 0 속도에 항력을 한 번 먹인 값이다 (%d)" % vx1)

	var x1 := spell.get_px()[0]
	var vx2 := _drag(vx1)
	_frames(w, Tuning.TICK_DIVIDER)
	if spell.active_count() != 1:
		t.ok(false, "탄이 사라져서 다음 틱 변위를 **못 쟀다**")
		return
	t.eq(spell.get_px()[0] - x1, vx2, "다음 틱 변위는 항력을 한 번 더 먹은 값이다 (%d)" % vx2)


## **Commands come before the grid.** An ignition drained this tick **already burns once this tick.**
##  Push it later and the fire catches while **the fuel stays put**, so looking only at "did it catch" misses it.
## This is also the only place that measures `_drain_queue`'s **grid branch** (the fire branch is measured above).
func _queue_lands_before_the_grid_lives(t) -> void:
	var g := _floor_grid()
	var wx := 20
	var wy := FLOOR_CY - 1
	g.apply(CellGrid.cmd_fill(wx, wy, wx, wy, Mat.WOOD))
	var w := _world(g)

	w.enqueue(CellGrid.cmd_ignite(wx, wy, 1, CellGrid.IGNITE_RUNE_FIRE))
	t.eq(g.burning_count(), 0, "큐에 넣은 것만으로는 불이 안 붙는다")

	_frames(w, Tuning.TICK_DIVIDER)
	t.eq(g.burning_count(), 1, "다음 틱에 점화 커맨드가 실제로 걸렸다")
	# Digging straight into a missing key makes **the check disappear.** It is read with a default and the premise asserted.
	var fuel := int(Mat.DEFS[Mat.WOOD].get("fuel", -1))
	t.ok(fuel > 0, "나무 표에 연료가 있다 (%d — 전제)" % fuel)
	t.eq(g.fuel_at(wx, wy), fuel - Tuning.FIRE_BURN_PER_TICK,
		"붙은 그 틱에 이미 한 틱치가 탔다 (커맨드가 격자보다 먼저다)")


## **Projectiles fly against "the grid after it moved"** — the order `world_step.gd` writes down as the contract.
##  Move it and not measure it and **half the value of the move has not arrived yet** (measured: swapping the two stayed green).
##
## Layout: on the bolt's first-tick path sits **one wood cell whose fuel runs out this tick.**
##   with the right order  `grid.step()` erases that cell => the bolt passes through
##   reversed              it hits a cell that is still solid => the bolt dies
## **Without a control it goes green without anyone knowing whether this layout is even a gauntlet.** Fire one tick earlier and it has to be blocked.
func _tick_order_is_grid_then_spell(t) -> void:
	t.eq(_run_gauntlet(t, "대조군", true), 0, "아직 안 사라진 칸은 탄을 막는다 (관문이 관문이다)")
	t.eq(_run_gauntlet(t, "본검사", false), 1, "사라지는 틱에 쏜 탄은 그 자리를 지나간다")


## Sets up the gauntlet and fires one shot. Returns the number of surviving bolts.
## With `early`, it fires **one tick before the cell disappears** (the control).
func _run_gauntlet(t, tag: String, early: bool) -> int:
	var g := _floor_grid()
	var wx := FIRE_CX + GAUNTLET_DCX
	var wy := FIRE_CY
	# **The gauntlet is two cells. At the 32px switch one cell no longer blocked** (measured).
	#  `GRAVITY_FP` doubled, so the bolt **drops one row within the first tick** (0.5 cells/tick^2) => the Bresenham path
	#  crosses below the launch row, and a one-cell gauntlet **is missed underneath.**
	#  Then the control becomes "it passed" instead of "it was blocked" and **the gauntlet stops being a gauntlet.**
	#  The two cells have the same fuel, so **they go out together on the same tick** — "the tick it disappears" is still one.
	g.apply(CellGrid.cmd_fill(wx, wy, wx, wy + 1, Mat.WOOD))
	t.ok(g.ignite(wx, wy) and g.ignite(wx, wy + 1), "%s: 관문 두 칸에 불이 붙었다 (전제)" % tag)

	# The tick count is not hardcoded — **it comes from the fuel and the per-tick burn.** It is alive up to tick `last`,
	#  and on the next tick the fuel hits 0 and the cell disappears.
	var last := (g.fuel_at(wx, wy) - 1) / Tuning.FIRE_BURN_PER_TICK
	var spell := SpellSim.new()
	var w := WorldStep.new(g, spell, _stander())
	_frames(w, Tuning.TICK_DIVIDER * (last - 1 if early else last))
	t.ok(g.is_solid(wx, wy), "%s: 쏘기 직전까지 관문이 고체다 (전제)" % tag)

	w.enqueue(_fire_cmd())
	_frames(w, Tuning.TICK_DIVIDER)
	# Pins down **why the bolt lived or died.** Without this line, the control's 0 could be
	#  "blocked by the gauntlet" or "died somewhere else".
	# **This used to be measured as "the gauntlet is still solid after the firing tick", and that observation died** —
	#  every impact carves a radius of `carve_r` (`spell_sim._impact` step (1)) => **a blocked bolt erases the gauntlet
	#  right where it stopped.** The gauntlet blocked it as laid out, but the after-state cannot tell them apart.
	#  => It is measured by **where it stopped.** The segment's end point is the impact cell (`spell_sim._advance`), and that is not carved.
	t.eq(spell.seg_count(), 1, "%s: 이 틱에 구간이 하나다 (배치를 읽을 수 있다)" % tag)
	if spell.seg_count() == 1:
		var end_cx: int = spell.get_seg_x1()[0] >> SpellSim.FP_SHIFT
		if early:
			t.eq(end_cx, wx - 1, "%s: 탄이 관문 **직전 칸**에서 멈췄다 (관문이 관문이다)" % tag)
		else:
			t.ok(end_cx > wx,
				"%s: 탄이 관문 자리를 지나 더 갔다 (셀 %d > 관문 %d)" % [tag, end_cx, wx])
	return spell.active_count()


## The character moves **on non-tick frames too** (60Hz). Move it inside the tick branch and this goes red.
func _character_moves_every_frame(t) -> void:
	var g := _floor_grid()
	var ch := _stander()
	var w := WorldStep.new(g, SpellSim.new(), ch)
	var x0 := ch.x

	t.ok(not w.frame(DT, 1.0, false, false), "첫 프레임은 틱이 아니다 (검사의 전제)")
	t.ok(ch.x > x0, "그 프레임에도 캐릭터가 오른쪽으로 갔다 (%d → %d)" % [x0, ch.x])

	# Inversion — it is not "it always pushes".
	var x1 := ch.x
	_frames(w, 10)
	t.eq(ch.x, x1, "입력이 0이면 안 움직인다")


## Does `reset()` roll back the queue and the fire count.
func _reset_clears_the_queue(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var w := WorldStep.new(g, spell, _stander())
	var cmd := _fire_cmd()

	w.enqueue(cmd)
	_frames(w, Tuning.TICK_DIVIDER)
	t.eq(w.fire_count(), 1, "먼저 한 발이 나갔다 (검사의 전제)")
	var live := spell.active_count()

	w.enqueue(cmd)
	w.reset()
	_frames(w, Tuning.TICK_DIVIDER)
	t.eq(w.fire_count(), 0, "reset() 이 발사 수를 0으로 되돌린다")
	t.eq(spell.active_count(), live, "reset() 뒤에는 큐에 있던 발사가 안 나간다 (탄이 안 는다)")


## Does `_init` bark and stop when it receives three nulls.
##
## **`expect_error` alone makes this a check that measures nothing** — the runner cannot see stderr and the
##  declaration is only an amnesty, so nothing goes red if the bark disappears.
##  => The bark's **trace** is measured as a value.
## What this check blocks is the accident of **the declaration order being reversed** in the shell. Text cannot catch it —
##  `WorldStep.new(_grid, _spell, _char)` does not change by one character; only the member initialization order does.
##
## **`frame()` is not called first.** Without the guard that call spews an engine error, and then the runner
##  **passes every assertion** (an aborted call reads as null -> false) while only the wrapper goes red.
##  That shape actually happened, measured — "57 passed" plus "8 lines of silent death". => **The flag is measured as a value first.**
## **Do not assign `get()` straight into a typed variable.** If the name changes, `get()` returns null and
##  **the assignment blows up and aborts the function** — and then the assertions below **disappear instead of going red**
##  (measured: `_broken` -> `_brkn` gave 1101 -> 1099 with 0 failures). => Receive it as a `Variant` and **measure the type first.**
func _null_world_refuses(t) -> void:
	t.expect_error("WorldStep: one of the three worlds is null")
	var w := WorldStep.new(null, null, null)
	var raw: Variant = w.get("_broken")
	t.ok(raw is bool, "world_step 이 `_broken` 표시를 든다")
	t.ok(raw == true, "null 세상이 스스로 「부서졌다」로 표시한다")
	if raw != true:
		return
	t.ok(not w.frame(DT, 1.0, false, false), "그리고 프레임을 안 돈다")

	# Does `enqueue()` go through **the same door.** Leave only this one open and a broken world blows up on left click.
	# **The "it does not blow up" side cannot be measured by an assertion** — without the guard, an engine error occurs
	#  inside `enqueue()`, only the call aborts, and the queue **ends up empty anyway.** The only thing that catches that
	#  branch is **the wrapper's stderr**, confirmed by measurement. What the assertion below measures is only "the command does not land".
	w.enqueue(_fire_cmd())
	var q: Variant = w.get("_queue")
	t.ok(q is Array, "world_step 이 `_queue` 를 든다")
	if q is Array:
		t.eq((q as Array).size(), 0, "부서진 세상은 커맨드를 안 받는다")

	# Does `spawn_monster()` go through the same door (it actually got through during `monsters-minimum` verification) —
	#  if a newly added public mutator does not go through `_broken`, the array grows even in a broken world and
	#  the HUD number rises. "Frames stop politely but M alone keeps incrementing" is the symptom.
	var mid := w.spawn_monster(MonsterDefs.KIND_PIG, 0, 0)
	t.eq(mid, 0, "부서진 세상은 몬스터를 안 만든다 (id 0)")
	var mv: Variant = w.get("_monsters")
	t.ok(mv is Array, "world_step 이 `_monsters` 를 든다")
	if mv is Array:
		t.eq((mv as Array).size(), 0, "부서진 세상의 몬스터 배열이 비어 있다")


## **Does the world the shell built actually run.** The check above only looks at the world the net built.
##
## **A bark cannot catch it** — an `expect_error` amnesty stays valid **for the whole run**, so the same bark raised
##  when `net_render` stands up a scene gets amnestied along with it. Measured: reversing the declaration order left
##  **all 1098 checks green** (the bark happened, it was amnestied, and nobody looked at the value).
## => **That object the shell built is driven directly.** With the declaration order reversed, the tick here is 0.
## Only the scene is stood up (`_ready` does not run) — an empty world with no terrain and no spawns, but
##  that is enough to measure "does it run per the divider".
func _stage_world_actually_runs(t) -> void:
	var scene: PackedScene = load(STAGE_SCENE)
	if scene == null or not scene.can_instantiate():
		# Just `return`ing here makes the check **disappear** rather than "fail" — only the pass count drops
		#  and nobody barks. In the log, "a check that disappeared" is indistinguishable from "a check that passed".
		t.ok(false, "무대 씬을 못 세워서 껍데기의 세상을 **하나도 못 쟀다**")
		return
	var root := scene.instantiate()
	# Received as a `Variant` so **the type is measured first** — a renamed member has to go red, not disappear.
	var w: Variant = root.get("_world")
	t.ok(w is WorldStep, "껍데기가 `_world` 로 WorldStep 을 든다")
	if w is WorldStep:
		var ticked := 0
		for _i in Tuning.TICK_DIVIDER:
			if w.call("frame", DT, 0.0, false, false):
				ticked += 1
		t.eq(ticked, 1, "껍데기가 만든 세상이 분주기대로 틱을 돈다")
	# Outside the tree, so it is `free`, not `queue_free`.
	root.free()


# ── Acceptance 1 — do I get hit by my own spell ────────────────────

## Direct hit. **Disproving tunneling is half of this check** — a layout where a 40px leap clears a 16px box
##  is built deliberately, and **the net asserts for itself that the layout really is a leap layout.**
##  Without that, this check only measures "is the function called" (exactly what design acceptance 1 warned about).
func _direct_hit_costs_hp(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	t.eq(ch.hp, Character.MAX_HP, "시작 체력이 가득이다 (%d)" % Character.MAX_HP)
	# The zero-contamination baseline. Zeroing the counter here keeps "terrain that got carved" out of the mix.
	g.consume_changed()

	# It has to hold **the box as of when the hit test ran** — if the character has already moved by the end of the frame,
	#  the leap assertion measured against the current position goes red falsely.
	#  The occasion for it ("a hit pushes you") **disappeared along with knockback.** The discipline stays.
	var box_x := ch.x
	w.enqueue(_hit_cmd_at(ch))
	_frames(w, Tuning.TICK_DIVIDER)

	# **Is the layout a leap layout** — **both ends of the segment** have to be outside the box.
	#  Without this line, a layout that happens to straddle the box is still green, and then writing it as
	#   a point test rather than a segment test also passes.
	t.eq(spell.seg_count(), 1, "이 틱에 구간이 하나다 (배치를 읽을 수 있다)")
	if spell.seg_count() == 1:
		var ax := Body._fp_px(spell.get_seg_x0()[0])
		var bx := Body._fp_px(spell.get_seg_x1()[0])
		t.ok(_outside_box(box_x, ax) and _outside_box(box_x, bx),
			"구간 양 끝(%.1f → %.1f)이 둘 다 상자[%d,%d] 밖이다 (도약 배치다)"
				% [ax, bx, box_x, box_x + Character.W_PX])

	t.eq(ch.hp, Character.MAX_HP - Character.DAMAGE_HIT,
		"그 도약 구간에 맞아 체력이 %d 깎였다" % Character.DAMAGE_HIT)
	# **Do not write the label as "N ticks"** — both sides are the same constant, so changing `INVULN_TICKS = 0`
	#  still passes as `0 == 0` while the label alone becomes "0 ticks turn on" (CLAUDE.md, "a value assertion that happens to match").
	#  What this line measures is only **"does it turn invulnerability on at all"**, and **the length is bounded above and below by the 3-tick/5-tick pair further down.**
	t.ok(ch.invuln_left == Character.INVULN_TICKS, "맞은 틱에 무적이 켜진다")
	# **The net proves for itself that contamination is 0.** **The reasoning sentence changed** —
	#  it used to be "no element plus no glyph, so the grid does not change", and now **every impact carves**
	#  (`spell_sim._impact` step (1)) => the reasoning still alive is the single **"there is no impact yet on this tick".**
	#  **Measured (verify-read)**: with the same layout, tick 1 is 0 and **tick 4 impacts for 13 cells.**
	#   => Not a tautology. If the layout shifts and the impact comes earlier, this barks.
	# **It was not changed to `burning_count() == 0` — here that would be a tautology.** Two reasons:
	#  (1) the stage is all stone so fuel is 0, and (2) **there is no impact at all within this window**, so any rune gives 0.
	#  (`_spread_hit_count_is_recorded` runs 20 ticks and lays wood, which is why that wording holds there.)
	t.eq(g.consume_changed(), 0, "이 틱에 아직 착탄이 없다 (직격만 잰 것이다)")


## **Stage A's own regression — the player side of "the socketed glyph changes the spell" was unmeasured.**
##  Reverting `character.gd`'s `take_hit(DAMAGE_HIT * pw / 100, true)` back to the flat `take_hit(DAMAGE_HIT,
##  true)` passed the whole suite green — `net_monster` covers the monster side, nothing covered the player.
func _direct_hit_scales_with_power(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	var boost := Glyph.power_pct_of(Glyph.DUMMY_U)
	t.ok(boost != Tuning.POWER_BASE, "더미(상)의 power_pct(%d)가 기본값(%d)과 다르다 (검사의 전제)" % [
		boost, Tuning.POWER_BASE])

	w.enqueue(_hit_cmd_at_with(ch, Glyph.pack([Glyph.DUMMY_U])))
	_frames(w, Tuning.TICK_DIVIDER)

	var want := Character.DAMAGE_HIT * boost / 100
	t.ok(want != Character.DAMAGE_HIT, "기대 피해(%d)가 기본 피해(%d)와 실제로 다르다 (전제)" % [
		want, Character.DAMAGE_HIT])
	t.eq(ch.hp, Character.MAX_HP - want,
		"더미(상)을 실은 직격이 플레이어의 체력도 %d 깎는다 (%d%%)" % [want, boost])


## **"Max, not first-found" was unmeasured.** Reverting `body.hit_by_segment`'s `best = maxi(best, powv[i])`
##  back to "return on the first match" passed the whole suite green — nothing fired two segments of
##  different power at the character on the same tick before this.
## The **weaker** bolt is queued first (so it lands first in the segment array, at index 0) and the
##  **boosted** one second — a first-found implementation would report the weaker one; only `max` reports
##  the true damage.
func _direct_hit_takes_the_max_power(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	var boost := Glyph.power_pct_of(Glyph.DUMMY_U)

	w.enqueue(_hit_cmd_at(ch))
	w.enqueue(_hit_cmd_at_with(ch, Glyph.pack([Glyph.DUMMY_U])))
	_frames(w, Tuning.TICK_DIVIDER)

	t.eq(spell.seg_count(), 2, "이번 틱에 구간이 둘이다 (검사의 전제)")
	if spell.seg_count() == 2:
		t.eq(int(spell.get_seg_power()[0]), Tuning.POWER_BASE, "먼저 넣은 약한 탄이 배열의 앞이다 (전제)")
		t.eq(int(spell.get_seg_power()[1]), boost, "나중에 넣은 위력 오른 탄이 배열의 뒤다 (전제)")

	var want := Character.DAMAGE_HIT * boost / 100
	t.eq(ch.hp, Character.MAX_HP - want,
		"약한 탄이 배열 앞인데도 **더 센 쪽**으로 깎인다 (%d — 최댓값이지 처음 찾은 값이 아니다)" % want)


## **A bolt falling straight down from overhead hits too.**
##  Measured: changing `_slab`'s axis-parallel branch (`d ~= 0`) to **"always miss" left all 1170 checks green** —
##   "it misses when it should miss" was measured while **nobody was measuring "it hits when it should hit".**
##  It is a reachable situation — the design doc settled on "**shoot at your feet and the bolt passes through me**".
##   Break that branch and **it quietly stops hurting.**
func _vertical_hit_costs_hp(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	# Straight down from **right above** the box. `adx = 0`, so the x axis goes through the axis-parallel branch.
	w.enqueue(SpellSim.cmd_fire(
		VERT_CX, VERT_FROM_CY, 0, 10, Tuning.ELEM_NONE, Glyph.GLYPH_NONE))
	var cx := Body._cell_px(VERT_CX)
	t.ok(cx >= float(ch.x) and cx <= float(ch.x + Character.W_PX),
		"발사선(x=%.1f)이 상자[%d,%d] 안이다 (배치의 전제)" % [cx, ch.x, ch.x + Character.W_PX])

	_frames(w, Tuning.TICK_DIVIDER)
	t.eq(ch.hp, Character.MAX_HP, "첫 틱은 아직 머리 위다 (안 맞는다)")
	_frames(w, Tuning.TICK_DIVIDER)
	t.eq(ch.hp, Character.MAX_HP - Character.DAMAGE_HIT, "둘째 틱에 수직 직격으로 깎인다")


## **A character behind a wall does not get hit.** Set the segment's end point to `x1` (the unclipped reach) and a bolt
##  that has impacted draws its line **past the wall** and strikes the character behind it (plan section 6, risk 2).
##  Measured: that mutation left **all 1163 checks green** — nobody was measuring it.
## Measuring only "it was not hit" stays **green even if no bolt was fired at all** => the bolt dying at the wall
##  and the segment being clipped at the impact point are asserted **together.**
func _wall_stops_the_segment(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	var row := _aim_row(ch)
	# One row — see the `WALL_CX` comment for the driven path that says one is enough here.
	g.apply(CellGrid.cmd_fill(WALL_CX, row, WALL_CX, row, Mat.STONE))
	w.enqueue(_hit_cmd_at(ch))
	_frames(w, Tuning.TICK_DIVIDER)

	t.eq(spell.active_count(), 0, "탄이 벽에서 죽었다 (배치의 전제)")
	t.eq(spell.seg_count(), 1, "죽은 탄도 이번 틱 구간을 하나 남긴다")
	if spell.seg_count() == 1:
		var bx := Body._fp_px(spell.get_seg_x1()[0])
		t.ok(bx < float(ch.x),
			"구간 끝(%.1f)이 상자 왼쪽(%d)에 못 미친다 (착탄점에서 잘렸다)" % [bx, ch.x])
	t.eq(ch.hp, Character.MAX_HP, "벽 뒤의 캐릭터는 안 맞는다")


## **R (stage reset) is the only revival** — you are alone, so nobody can pick you up (plan section 4).
##  If `place()` does not roll back health and invulnerability, you stay downed forever (plan section 6, risk 11).
func _place_revives(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	w.enqueue(_hit_cmd_at(ch))
	_frames(w, Tuning.TICK_DIVIDER)
	t.ok(ch.hp < Character.MAX_HP and ch.invuln_left > 0, "먼저 맞았다 (검사의 전제)")

	ch.place(STAND_X, FLOOR_TOP - Character.H_PX)
	t.eq(ch.hp, Character.MAX_HP, "place()가 체력을 되돌린다 (R로 부활한다)")
	t.eq(ch.invuln_left, 0, "place()가 무적도 되돌린다")


## Blast. The bolt does not cross the box; only **the blast that went off on the floor** reaches it.
## **Inversion 1**: take the same blast from **outside** the radius and health is unchanged.
func _blast_hit_costs_hp(t) -> void:
	var right_cx := _blast_cx_beside(STAND_X, 1)
	var near := _blast_shot(t, STAND_X, right_cx, "오른쪽")
	t.eq(near, Character.MAX_HP - Character.DAMAGE_HIT,
		"폭발 반경 안에 서 있으면 체력이 %d 깎인다" % Character.DAMAGE_HIT)
	var far := _blast_shot(t, _far_stand_x(right_cx), right_cx, "멀리")
	t.eq(far, Character.MAX_HP, "폭발 반경 밖에 서 있으면 체력이 그대로다")
	# The premise of acceptance 3-1 — **the left position hits on its own too.** Without measuring it, "two blasts = one hit"
	#  is indistinguishable from "actually only one landed", and then that check measures nothing.
	var left := _blast_shot(t, STAND_X, _blast_cx_beside(STAND_X, -1), "왼쪽")
	t.eq(left, Character.MAX_HP - Character.DAMAGE_HIT,
		"왼쪽 자리의 폭발도 혼자서 %d 깎는다 (3-①의 전제)" % Character.DAMAGE_HIT)


## One blast into the floor beside the character. Returns the remaining health.
func _blast_shot(t, stand_x: int, cx: int, tag: String) -> int:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander_at(stand_x)
	var w := WorldStep.new(g, spell, ch)
	w.enqueue(_blast_cmd(cx))

	var blasts := 0
	for _i in 12:
		_frames(w, Tuning.TICK_DIVIDER)
		blasts += spell.blast_count()
	# **Did a blast really happen** — without this, "nothing happened so health is unchanged" becomes inversion 1's
	#  green. This line is what establishes that both branches use **the same blast.**
	t.eq(blasts, 1, "%s: 폭발이 정확히 한 번 났다" % tag)
	return ch.hp


# ── Acceptance 3 — invulnerability ─────────────────────────────────

## 3-1: two blasts on the same tick -> **one hit.**
## **"There really were two blasts on that tick" is asserted alongside** — without it, "one hit" also comes out
##  when only one blast happened, and the check spins idle.
##
## **What this check measures is not invulnerability but `on_tick`'s "stop at the first hit" structure.**
##  The design doc's inversion ("set invulnerability to 0 and it takes damage twice") was **false, measured** —
##   even at 0, within the same tick still only 10 is lost. **What invulnerability blocks is between ticks.**
##   => Do not read this label as "invulnerability blocks the same tick".
func _same_tick_two_blasts_cost_one(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	# **One shot on each side of the box.** Fire two at the same spot and **the first blast breaks the second bolt's
	#  footing**, so that bolt falls into the crater and goes off **on the next tick** (measured) — and then
	#  the premise "two on the same tick" does not hold at all.
	#  Being on opposite sides, **the left blast's destruction disc cannot reach the right bolt's footing**: they are
	#   60% of the radius out on each side, so the gap between the two positions is 1.2 times the radius plus the box width.
	w.enqueue(_blast_cmd(_blast_cx_beside(STAND_X, -1)))
	w.enqueue(_blast_cmd(_blast_cx_beside(STAND_X, 1)))

	var twin_tick := false
	for _i in 12:
		_frames(w, Tuning.TICK_DIVIDER)
		if spell.blast_count() == 2:
			twin_tick = true
	t.ok(twin_tick, "한 틱에 폭발이 둘 난 틱이 실제로 있었다 (배치의 전제)")
	t.eq(ch.hp, Character.MAX_HP - Character.DAMAGE_HIT,
		"같은 틱에 폭발 둘을 맞아도 한 대만 깎인다")


## **The check that would have caught reusing the circular blast test for a rectangular pillar**
##  (`glyph-condense.md` §9's acceptance 9) — **and, measured, the check that did not.**
##
## **Real regression, found by verify-run**: the first version fired straight down onto the character's own
## column. The bolt's own segment then crossed the box a tick before the pillar existed, landed at the
## bolt's *base* 100% (a `TERMINAL` never touches it — `spell_sim._launch`'s own header), and since that
## version used `CONDENSE_C` (also 100%), the two values were indistinguishable — `body.hit_by_pillar`
## returning a flat `0`, or dropping the `maxi` term in `character.gd` entirely, still left this check green
## (`net_monster._blast_hits_to_kill`'s own header already named this exact trap; it had only been fixed on
## the monster side).
##
## **`CONDENSE_U` (150%), fired beside the box, not through it** — the same offset idiom
## `net_monster._pillar_hits_to_kill` uses, so the segment never crosses the box and the only power that can
## possibly land is the pillar's own. Positions are **measured, not derived**: one cell past the box's own
## right edge connects at exactly `DAMAGE_HIT * 150 / 100`; four cells past it does not connect at all.
func _pillar_hit_is_rectangular(t) -> void:
	var drop_cy := FLOOR_CY - 10
	var edge_cx := floori(float(STAND_X + Character.W_PX) / float(Tuning.CELL_PX))
	var packed := Glyph.pack([Glyph.CONDENSE_U])

	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	w.enqueue(SpellSim.cmd_fire(edge_cx + 1, drop_cy, 0, 10, Tuning.ELEM_NONE, packed))
	var pillars := 0
	for _i in 12:
		_frames(w, Tuning.TICK_DIVIDER)
		pillars += spell.pillar_count()
	t.eq(pillars, 1, "기둥이 한 번 선다 (검사의 전제)")
	var want := Character.DAMAGE_HIT * Glyph.power_pct_of(Glyph.CONDENSE_U) / 100
	t.eq(ch.hp, Character.MAX_HP - want,
		"몸 오른쪽 끝 바로 한 칸 밖에서도 응축(유니크)의 위력(%d%%, 한 대 %d)이 그대로 맞는다 — 세그먼트의 기본 100%%가 아니다" % [
			Glyph.power_pct_of(Glyph.CONDENSE_U), want])

	# **Four cells past the edge — measured, not a circle-radius argument.** Still within what a same-radius
	#  circle (`Tuning.blast_rd(0)` == `Tuning.pillar_w(0)`, both 8 at generation 0) would have caught.
	var g2 := _floor_grid()
	var spell2 := SpellSim.new()
	var ch2 := _stander()
	var w2 := WorldStep.new(g2, spell2, ch2)
	w2.enqueue(SpellSim.cmd_fire(edge_cx + 4, drop_cy, 0, 10, Tuning.ELEM_NONE, packed))
	var pillars2 := 0
	for _i in 12:
		_frames(w2, Tuning.TICK_DIVIDER)
		pillars2 += spell2.pillar_count()
	t.eq(pillars2, 1, "그 자리에서도 기둥이 한 번 선다 (검사의 전제)")
	t.eq(ch2.hp, Character.MAX_HP, "네 칸 밖은 기둥 폭 바깥이라 안 맞는다 (원이었다면 맞았을 거리)")


## **The height must bound the rect, not just the drawing** (`glyph-condense.md` §9's acceptance list). A body
##  whose whole box sits above the pillar's own measured top (read back from the notice itself, not assumed
##  from the table — an open ceiling might not reach `pillar_h(0)`) is not hit.
func _pillar_does_not_hit_above_its_own_top(t) -> void:
	var drop_cy := FLOOR_CY - 10
	var cx := floori((STAND_X + Character.W_PX * 0.5) / float(Tuning.CELL_PX))

	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	w.enqueue(SpellSim.cmd_fire(cx, drop_cy, 0, 10, Tuning.ELEM_NONE, Glyph.pack([Glyph.CONDENSE_C])))
	var h := 0
	for _i in 6:
		_frames(w, Tuning.TICK_DIVIDER)
		if spell.pillar_count() > 0:
			h = spell.get_pillar_h()[0]
	t.ok(h > 0, "기둥 높이를 읽었다 (검사의 전제)")

	# A fresh body placed one whole cell above the pillar's own measured top, watched for only a few ticks —
	#  long enough for the (already-airborne) bolt to land, short enough that this body's own fall from a
	#  standing start cannot have dropped it into the rectangle yet.
	var g2 := _floor_grid()
	var spell2 := SpellSim.new()
	var ch2 := Character.new()
	var above_y := FLOOR_TOP - h * Tuning.CELL_PX - Character.H_PX - Tuning.CELL_PX
	ch2.place(STAND_X, above_y)
	var w2 := WorldStep.new(g2, spell2, ch2)
	w2.enqueue(SpellSim.cmd_fire(cx, drop_cy, 0, 10, Tuning.ELEM_NONE, Glyph.pack([Glyph.CONDENSE_C])))
	var pillars2 := 0
	for _i in 4:
		_frames(w2, Tuning.TICK_DIVIDER)
		pillars2 += spell2.pillar_count()
	t.eq(pillars2, 1, "그 자리에서도 기둥이 한 번 선다 (검사의 전제)")
	t.eq(ch2.hp, Character.MAX_HP, "기둥 꼭대기보다 위에 있으면 안 맞는다")


## **Invulnerability ticks down "one per tick"** — the check that **directly bites** plan section 6, risk 1
##  (reading notices at 60Hz turns one hit into three).
##  Risk 1 **does not show up as "one hit became three"** — invulnerability eats the other two so the damage stays one hit,
##   and it shows **only as invulnerability draining 3 times faster.** That is what is counted here.
##  The 3-tick/5-tick pair below bites the same mutation, but if someone touches that check's interval constants
##   both risks become invisible **at the same time** => the detector is split in two.
func _invuln_ticks_down_once_per_tick(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	w.enqueue(_hit_cmd_at(ch))
	_frames(w, Tuning.TICK_DIVIDER)
	t.ok(ch.invuln_left > 0, "먼저 맞아 무적이 켜졌다 (검사의 전제)")

	var want := ch.invuln_left
	while want > 0:
		want -= 1
		_frames(w, Tuning.TICK_DIVIDER)
		t.eq(ch.invuln_left, want, "한 틱 지나 무적이 %d 남는다 (틱마다 하나씩)" % want)


## 3-2: is invulnerability **4 ticks.** Measured with direct hits — a queued command goes out **on the next tick**
##  and crosses the box on that tick, so the tick interval can be controlled exactly.
func _invuln_lasts_four_ticks(t) -> void:
	t.eq(_two_shots_hp(3), Character.MAX_HP - Character.DAMAGE_HIT,
		"3틱 간격 두 발은 **한 대**다 (무적 안이다)")
	t.eq(_two_shots_hp(5), Character.MAX_HP - Character.DAMAGE_HIT * 2,
		"5틱 간격 두 발은 **두 대**다 (무적이 풀렸다)")


## Makes the second shot cross the box `gap` ticks after the tick the first shot landed. Returns the remaining health.
func _two_shots_hp(gap: int) -> int:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	w.enqueue(_hit_cmd_at(ch))
	_frames(w, Tuning.TICK_DIVIDER)          # the first shot goes out on this tick and crosses the box right away
	_frames(w, Tuning.TICK_DIVIDER * (gap - 1))
	w.enqueue(_hit_cmd_at(ch))
	_frames(w, Tuning.TICK_DIVIDER)          # the gap-th tick from the first shot
	return ch.hp


## 3-3: **how many hits** from 8 spread bolts — **this is a record. Do not assert a target number.**
##  One situation is fixed, counted, and the number stamped into the label. That value decides whether to tighten the 0.2 seconds.
func _spread_hit_count_is_recorded(t) -> void:
	# **The floor has to be wood for "no fire caught" below to measure anything.**
	#  On the stone-only `_floor_grid()`, `STONE.fuel = EMPTY.fuel = 0`, so `burning_count()` is
	#   **always 0 in principle** and that line becomes a **tautology** (verify-run measured it: mutating no-element
	#   to ignite still did not bark). Contamination control **sinking from the observation into the stage layout**
	#   is exactly CLAUDE.md's "the label is wider than what is measured".
	#  The position has to line up — the spread impact column is `_spread_cx(STAND_X)` = **87** and
	#   the wood row is `WOOD_CX0..CX1` = **78-90**, so **there is fuel underneath it.**
	#   For generation 1, `carve_r(1)=1 < rune_r(1)=2`, so a ring survives outside the carve => there is somewhere to catch.
	var g := _wood_floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	g.consume_changed()
	var one: Array[int] = [Glyph.GLYPH_SPREAD]
	# Driven into the floor immediately right of the character so the eight scatter from that spot.
	# It used to be `BLAST_CX - 12` (12 cells left of the blast position) — **tied to the blast radius.**
	#  Halve the radius and that expression moves inside the box and direct hits mix in. => It is derived from the box.
	w.enqueue(SpellSim.cmd_fire(
		_spread_cx(STAND_X), BLAST_FROM_CY, 0, 10, Tuning.ELEM_NONE, Glyph.pack(one)))
	_frames(w, Tuning.TICK_DIVIDER * 20)

	var hits := (Character.MAX_HP - ch.hp) / Character.DAMAGE_HIT
	# The assertion stops at "it was counted". The number is **a record in the label**, not a target.
	t.ok(hits >= 0, "확산 8발 상황에서 **%d대** 맞았다 (기록 — 목표 숫자가 아니다)" % hits)
	# **This used to read "not a single grid cell changed".** Since every impact carves
	#  (`spell_sim._impact` step (1)), that sentence cannot be used.
	# **The substance of contamination control is not "it did not change" but "there is no fire"** — the damage paths
	#  are three: direct hit, blast and fire (`character.on_tick`, `_standing_in_fire`), and here it is no element plus spread,
	#  so the latter two are absent. **Carving is none of those paths.**
	var carved := g.consume_changed()
	t.eq(g.burning_count(), 0, "그 동안 불이 한 칸도 안 붙었다 (피해가 직격뿐이다)")
	# The other side — was the grid **actually** carved. Without it, "no bolt arrived at all" also produces the green above.
	t.ok(carved > 0, "그런데 격자는 실제로 파였다 (착탄이 정말 일어났다 · %d칸)" % carved)


# ── Acceptance 2 — does standing in fire cost health ───────────────

## **The only way to measure "regardless of invulnerability"**: hit with a bolt first and stand the character
##  in fire **with invulnerability on.** Measure without turning invulnerability on and you measure "just fire damage", and **a wrong implementation passes too.**
## And it also checks whether it is **proportional to time** — at "it costs health once", a hardcoded constant passes.
func _fire_burns_through_invuln(t) -> void:
	var g := _wood_floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)

	# **Invulnerability is turned on with a vertical direct hit.** The reason this layout was chosen ("hit horizontally
	#  and it gets pushed off the wood under its feet") **disappeared along with knockback.** The layout stays — the character
	#  staying put is still the cleanest way to measure "only the row under the feet burns".
	# **It does not go through the queue.** Queued, `world_step` applies **recoil** (fired downward, so upward)
	#  and the character rises and settles back 20 frames later, and invulnerability drains away in between (measured).
	#  What is measured here is **whether fire is independent of invulnerability**, not the command path — recoil is measured by acceptance 5.
	#
	# **This is the first case in this repo of "the net going down a different path from the game". The cost is written down exactly:**
	#  This layout builds **a state the game cannot produce** (self-hit without recoil) => in exchange,
	#  **"shooting at your feet while standing in fire lifts you out of the fire on the recoil" became behavior nobody measures.**
	#  Whether that is a bug or a spec **is not in the design doc either.** The properties of invulnerability and fire are
	#   path-independent, so this trade was accepted, but **read this line first before taking the same detour again.**
	t.ok(spell.fire(SpellSim.cmd_fire(
		VERT_CX, VERT_FROM_CY, 0, 10, Tuning.ELEM_NONE, Glyph.GLYPH_NONE)),
		"맞힐 탄을 시뮬에 직접 넣었다 (반동을 안 만든다)")
	_frames(w, Tuning.TICK_DIVIDER * 2)
	t.eq(ch.hp, Character.MAX_HP - Character.DAMAGE_HIT, "탄으로 먼저 맞았다 (검사의 전제)")
	t.ok(ch.invuln_left > 0, "그래서 무적이 켜져 있다 (검사의 전제)")
	_ignite_under(t, g, ch)

	# Looks at **the invulnerability left at the moment the first fire damage lands.** That is all of "independent of invulnerability".
	var invuln_at_first := -1
	var before := ch.hp
	for _i in 30:
		w.frame(DT, 0.0, false, false)
		if ch.hp < before:
			invuln_at_first = ch.invuln_left
			break
	t.ok(invuln_at_first > 0,
		"**무적이 %d틱 남은 채로** 첫 불 피해가 들어왔다 (무적에 안 걸린다)" % invuln_at_first)
	t.ok(ch.burning, "그 동안 캐릭터가 「불붙음」으로 표시된다 (화면이 읽는 값)")

	# Is it proportional to time — two windows of the same length are compared.
	# **Both windows have to finish within the wood's lifetime (fuel 200 / 5 per tick = 40 ticks = 2 seconds)** —
	#  go over and "less damage because the fire went out" reads as "proportionality broke" (it happened once, measured).
	var a := ch.hp
	_frames(w, BURN_WINDOW)
	var d1 := a - ch.hp
	var b := ch.hp
	_frames(w, BURN_WINDOW)
	var d2 := b - ch.hp
	t.ok(g.burning_count() > 0, "두 창 내내 불이 살아 있었다 (검사의 전제)")
	# The expected value is not hardcoded — it comes from the damage per second and the window length. Truncation allows +1.
	var want := int(Character.BURN_DPS * BURN_WINDOW / 60.0)
	t.ok(d1 >= want and d1 <= want + 1,
		"%d프레임에 %d 깎인다 (초당 %d에서 나온 %d~%d)"
			% [BURN_WINDOW, d1, int(Character.BURN_DPS), want, want + 1])
	t.ok(absi(d2 - d1) <= 1, "다음 창도 같은 만큼 깎인다 (%d vs %d — 시간에 비례한다)" % [d1, d2])


## **Inversion**: when the fuel runs out and the fire goes out, the damage stops.
## Measuring only "no damage" is **indistinguishable from it never having caught** => the earlier damage and
##  the fire actually going out are asserted **together.**
func _burnout_stops_the_damage(t) -> void:
	var g := _wood_floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	_ignite_under(t, g, ch)

	var start := ch.hp
	# Wood fuel 200 / 5 per tick = 40 ticks to burn out. Run generously past that.
	_frames(w, Tuning.TICK_DIVIDER * 60)
	t.ok(ch.hp < start, "불이 도는 동안 깎였다 (%d → %d)" % [start, ch.hp])
	t.eq(g.burning_count(), 0, "연료가 다해 불이 꺼졌다 (배치의 전제)")
	t.ok(not ch.burning, "캐릭터의 「불붙음」 표시도 꺼진다")

	var after := ch.hp
	_frames(w, 120)
	t.eq(ch.hp, after, "불이 꺼진 뒤에는 한 톨도 안 깎인다")


## **Tapping across fire is not free.**
##  At `10dps x 1/60` it takes **6 frames** to accumulate 1 point => clear the accumulator on leaving the fire and
##  **any contact under 0.1 seconds is free forever**, and that can be repeated indefinitely.
##  It is a decision the plan does not record, so **if someone clears it while "tidying up", nobody barks** —
##   measured: clearing or not, the net stayed at 1193. That is why this check exists.
## "Stepped on and off" is produced by turning the fire off and on — moving the character would make `place()` restore health.
func _burn_acc_survives_tapping(t) -> void:
	var g := _wood_floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	var cx0 := floori(ch.x / float(Tuning.CELL_PX))
	var cx1 := floori((ch.x + Character.W_PX - 1) / float(Tuning.CELL_PX))

	var contacts := 4
	for _i in contacts:
		for cx in range(cx0, cx1 + 1):
			g.ignite(cx, WOOD_CY)
		t.ok(g.burning_count() > 0, "발밑에 불이 붙었다 (전제)")
		_frames(w, TAP_FRAMES)
		# Re-laying the wood clears the flag (`_write_cell` removes it from the burn slot too) = the same as leaving the fire.
		g.apply(CellGrid.cmd_fill(WOOD_CX0, WOOD_CY, WOOD_CX1, WOOD_CY, Mat.WOOD))
		t.eq(g.burning_count(), 0, "불에서 나왔다 (전제)")
		_frames(w, 2)

	# At this many frames per contact, **a single contact can never accumulate 1 point** (6 frames are needed).
	t.ok(TAP_FRAMES * Character.BURN_DPS / 60.0 < 1.0,
		"한 번 접촉(%d프레임)만으로는 1점이 안 쌓인다 (배치의 전제)" % TAP_FRAMES)
	t.ok(ch.hp < Character.MAX_HP,
		"그래도 %d번 밟으면 결국 깎인다 (%d) — 누산기가 접촉 사이를 넘어 산다"
			% [contacts, ch.hp])


## Sets fire to the wood under the feet. It is **one row below the box**, so no burning cell is inside the box —
##  that is the layout for measuring the plan's pinned "miss the row under the feet and nothing happens in the game alone".
func _ignite_under(t, g: CellGrid, ch: Character) -> void:
	var cx0 := floori(ch.x / float(Tuning.CELL_PX))
	var cx1 := floori((ch.x + Character.W_PX - 1) / float(Tuning.CELL_PX))
	var lit := 0
	for cx in range(cx0, cx1 + 1):
		if g.ignite(cx, WOOD_CY):
			lit += 1
	t.ok(lit > 0, "발밑 나무 %d칸에 불이 붙었다 (검사의 전제)" % lit)
	# Asserts that **there is no fire inside the box.** Only if this is true is "the row under the feet" what is being measured.
	var top := floori(ch.y / float(Tuning.CELL_PX))
	var bottom := floori((ch.y + Character.H_PX - 1) / float(Tuning.CELL_PX))
	var inside := 0
	for cy in range(top, bottom + 1):
		for cx in range(cx0, cx1 + 1):
			if g.is_burning(cx, cy):
				inside += 1
	t.eq(inside, 0, "상자가 덮는 셀에는 타는 칸이 하나도 없다 (발밑 한 줄만 탄다)")


# ── Acceptance 4 — **deleted** ─────────────────────────────────────
# **"Does a hit push me" (knockback) is gone** (decided by the user) => the six checks that measured it and
#  their layout constants were deleted with it. **A check measuring a feature that does not exist is a fake net.**
#  To bring it back, start from the comment beside `recoil_vx` in `character.gd` — it says what has to come back with it.

# ── Acceptance 5 — does firing push me back on the recoil ──────────

## **Where it is applied is the trap** — firing goes through the queue, so applying it at enqueue time
##  **pushes even on a rejected shot.** The inversion below holds that spot.
func _firing_pushes_me_back(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	var x0 := ch.x
	# Fires right => it has to be pushed left.
	w.enqueue(SpellSim.cmd_fire(
		RECOIL_CX, HIT_ORIGIN_CY, AIM_DX, 0, Tuning.ELEM_NONE, Glyph.GLYPH_NONE))
	_frames(w, Tuning.TICK_DIVIDER)
	t.eq(w.fire_count(), 1, "발사가 받아들여졌다 (검사의 전제)")
	t.ok(ch.recoil_vx < 0.0, "쏜 반대쪽(-x)으로 반동이 걸렸다 (%.0f px/s)" % ch.recoil_vx)
	_frames(w, RECOIL_WINDOW)
	t.ok(ch.x < x0, "%d프레임 뒤 왼쪽으로 밀려 있다 (%d → %d)" % [RECOIL_WINDOW, x0, ch.x])


## **Does the recoil die down over time.**
##  **Measured: erasing the decay to `*= 1.0` left all 1280 net checks green** —
##   the character who fired **slid forever** and nobody looked (on screen it is a failure visible within a second).
##  That hole appeared because **`_knockback_decays` disappeared along with knockback when it was deleted.**
##   **The decay stayed on the recoil side, so the check stays too** — it is not measuring a feature that does not exist.
##
## **Measured by velocity, not displacement.** Measured by displacement, erasing the decay pins the character against
##  the grid's left edge so the second window shortens by itself, and then **the inversion passes** (confirmed by calculation: 200px -> 120px).
## "So does it actually move" is measured in x by `_firing_pushes_me_back` above. The two are a pair.
func _recoil_decays(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	w.enqueue(SpellSim.cmd_fire(
		RECOIL_CX, HIT_ORIGIN_CY, AIM_DX, 0, Tuning.ELEM_NONE, Glyph.GLYPH_NONE))
	_frames(w, Tuning.TICK_DIVIDER)
	var v1 := absf(ch.recoil_vx)
	t.ok(v1 > 0.0, "쏘아서 반동이 걸렸다 (%.0f px/s — 검사의 전제)" % v1)

	_frames(w, RECOIL_WINDOW)
	var v2 := absf(ch.recoil_vx)
	# The expected value is not hardcoded — it comes from the decay constant and the window length. At 0.5 seconds it is `0.02^0.5` = 0.14x.
	#  Loosening it to a half is to keep it **from wobbling when the frame count changes slightly**, not
	#   to widen what is measured — with no decay the ratio is **1.0**, far above it.
	t.ok(v2 < v1 * 0.5,
		"%d프레임 뒤 반동이 절반 아래로 잦아든다 (%.0f → %.0f px/s)" % [RECOIL_WINDOW, v1, v2])


## **Rocket jumping was deleted** (decided by the user). The recoil is 1D, so firing downward does not lift you.
##  This function used to assert **the exact opposite** (`top < y0`, "firing down lifts you").
##
## **Measuring only "it does not lift" measures nothing** — a rejected shot, `recoil()` never being called at all,
##  or a recoil constant of 0 would **all be green.** A check measuring something that is not there is a fake net.
##  => **It fires diagonally and measures "horizontal is applied while only vertical is 0" in one layout.**
##   Only with that pair does the label ("the vertical was erased") equal what is measured.
##  Fired vertically (0,10), `d.x` is 0 so **the horizontal is 0 too**, and then no control can be built.
func _firing_down_does_not_lift_me(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	var y0 := ch.y
	var x0 := ch.x
	# **Fired from the staff's tip. The position is not hardcoded but taken from `Staff.tip_px()`** —
	#  by definition that is where the bolt is really born when aiming downward in the game.
	#  **The layout's reasoning changed.** The origin used to be **below** the box (inside the floor), so
	#   "the bolt does not cross the box"; once the staff got shortened by terrain the origin became **the box's last row**
	#   => **the bolt is born inside the box and hits its owner.** That is the correct behavior (design doc, "shoot at your feet and you hit yourself").
	#  **What this check measures is unchanged even so**: hp is not looked at, with no knockback a hit does not push, and
	#   `ELEM_NONE + GLYPH_NONE` means there is no rune trace either. What is measured is the two: **vertical 0, horizontal recoil alive.**
	#  It is a **down**-right diagonal, so the vertical component is alive — had rocket jumping existed, this layout would have lifted too.
	var tip := Staff.tip_px(g, ch.x, ch.y, Vector2.DOWN)
	var feet_cx := floori(tip.x / float(Tuning.CELL_PX))
	var feet_cy := floori(tip.y / float(Tuning.CELL_PX))
	# **The net asserts the layout's premise for itself** — if the under-foot origin is a solid cell the bolt is born inside a wall
	#  (`spell_sim._walk` does not look at the starting cell), and at that moment what this layout meant to measure changes entirely.
	t.ok(not g.is_solid(feet_cx, feet_cy),
		"발밑 원점(%d,%d)이 빈 셀이다 (배치의 전제)" % [feet_cx, feet_cy])
	w.enqueue(SpellSim.cmd_fire(
		feet_cx, feet_cy, 10, 10, Tuning.ELEM_NONE, Glyph.GLYPH_NONE))
	var top := y0
	for _i in RECOIL_WINDOW:
		w.frame(DT, 0.0, false, false)
		top = mini(top, ch.y)
	t.eq(w.fire_count(), 1, "발사가 받아들여졌다 (검사의 전제)")
	t.eq(top, y0, "아래로 쏴도 한 픽셀도 안 뜬다 (로켓점프 삭제 · y %d)" % y0)
	# **The control.** In the same shot the horizontal is applied => the path where the line above goes green
	#  because "the recoil died entirely" is blocked.
	t.ok(ch.x < x0,
		"같은 발사의 가로 반동은 살아 있다 (%d → %d) — 세로만 지운 것이다" % [x0, ch.x])


## **A rejected shot produces no recoil.**
##  Do not write the label as "an empty rune" — that path lives in the shell (`can_fire()` in `_fire_at`) and
##   the net cannot call it. What is measured here is **a command `fire()` rejects.**
func _rejected_fire_has_no_recoil(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	var x0 := ch.x
	t.expect_error("SpellSim: unknown glyph id")
	w.enqueue(SpellSim.cmd_fire(
		RECOIL_CX, HIT_ORIGIN_CY, AIM_DX, 0, Tuning.ELEM_NONE, BAD_GLYPHS))
	_frames(w, Tuning.TICK_DIVIDER)
	t.eq(w.fire_count(), 0, "그 발사는 거부됐다 (검사의 전제)")
	t.eq(spell.active_count(), 0, "탄도 안 났다 (검사의 전제)")
	t.eq(ch.recoil_vx, 0.0, "거부된 발사는 반동을 안 만든다")
	_frames(w, RECOIL_WINDOW)
	t.eq(ch.x, x0, "그래서 한 픽셀도 안 밀린다")


# ── Acceptance 6 — does 100 -> 0 knock me down ─────────────────────

## **It is not instant death** — measured by still being subject to gravity (downed in mid-air, it falls and settles on the surface).
## **Incapacitation is measured alongside.** Without it, **an implementation that only sets a flag and does nothing else passes.**
##  **With residual velocity left, x changes** => it is knocked down, **left to settle**, and then measured.
func _zero_hp_downs_me(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	t.ok(not ch.downed, "시작은 안 쓰러진 상태다 (검사의 전제)")
	_beat_down(t, w, spell, ch, Character.MAX_HP / Character.DAMAGE_HIT)
	t.eq(ch.hp, 0, "열 대를 맞고 체력이 0이다")
	t.ok(ch.downed, "그래서 쓰러졌다")

	# Incapacitation is measured **after the residual velocity has settled** — leftover velocity changes x and reads as "the input worked".
	#  30 frames was **not enough, measured** (6px drifted — a value from when knockback existed). Exponential decay
	#   never reaches exactly 0, so it waits generously: at x0.02 per second, after 2 seconds it is 0.16px/s.
	_frames(w, SETTLE_FRAMES)
	var x0 := ch.x
	_frames(w, 60, 1.0)
	t.eq(ch.x, x0, "입력을 계속 넣어도 x가 안 변한다 (행동불능)")
	# Jumping is blocked too — otherwise it becomes "jumping while lying down".
	var y0 := ch.y
	for _i in 60:
		w.frame(DT, 1.0, true, true)
	t.eq(ch.y, y0, "점프 입력도 안 먹는다")

	# **Not instant death = still subject to gravity.** The ground under the feet is dug away to make it fall.
	# **"Dug by its own blast" is false now** — you cannot fire while downed (`world_step._drain_queue`).
	#  There are three ways into this state in the game: (1) a hole dug **before** going down, (2) the footing burning
	#  away while dying to fire, (3) someone else shooting in multiplayer. => **This layout only reproduces the outcome**,
	#  and that trade is written in the `_beat_down` comment above.
	# The pit is dug **from the character's current position** too — hardcoded, it appears in the wrong place the day the character moves.
	var pit0 := floori(ch.x / float(Tuning.CELL_PX)) - 2
	var pit1 := floori((ch.x + Character.W_PX - 1) / float(Tuning.CELL_PX)) + 2
	g.apply(CellGrid.cmd_fill(pit0, FLOOR_CY, pit1, PIT_BOTTOM_CY, Mat.EMPTY))
	_frames(w, 120)
	t.ok(ch.y > y0, "쓰러진 채로 떨어진다 (y %d → %d — 중력을 계속 받는다)" % [y0, ch.y])
	t.ok(ch.on_ground, "그리고 구덩이 바닥에 닿는다")
	t.eq(ch.y, (PIT_BOTTOM_CY + 1) * Tuning.CELL_PX - Character.H_PX,
		"지표면에 정확히 붙는다 (튀거나 파묻히지 않는다)")


## Lands `n` hits. Invulnerability is 4 ticks, so the interval has to be **5 ticks** for every one to land.
## It does not go through the queue — mixing in recoil lifts the character and the next shot misses (the same reason as the fire check above).
##
## **What is lost — the third case of a detour, and the biggest one.** In the game what knocks you down is
##  **your own bolt with recoil on it**, and that path is never measured => **acceptance 6 rests entirely on a
##  detour path.**
## **Once there are three detours the next person reads that as the default.** Stop before making a fourth and
##  first answer "is this property really path-independent".
##
## **And this detour has already hidden a result once — the first case in this repo.**
##  The reachability reasoning for "does it stay subject to gravity while downed" below was first written as
##  **"it digs under its own feet with its own blast"**, and **that path closed the same day "you cannot fire while downed" was added.**
##  A probe measuring through the real game path went red there at `y 308 -> 308` while **the net passed all 1288 checks** —
##  because it calls `spell.fire()` directly and **does not go through the new door.**
## **There are only three ways to fall while downed in the game today:**
##  (1) a hole dug **before** going down, (2) the footing burning away while dying to fire, (3) **someone else shooting in multiplayer.**
##  => "Dig under the feet after going down", which the check below sets up, is **a net-only situation.** The property
##   (does it stay subject to gravity) is path-independent so it stays, but **do not write "its own blast" as the reachability reasoning again.**
func _beat_down(t, w: WorldStep, spell: SpellSim, ch: Character, n: int) -> void:
	for _i in n:
		t.ok(spell.fire(_hit_cmd_at(ch)), "때릴 탄이 났다 (검사의 전제)")
		_frames(w, Tuning.TICK_DIVIDER * 5)


## **You cannot fire while downed.** Without the block, neither staff nor muzzle is drawn while **the spell goes out
##  and the corpse flies around on the recoil** (measured: fire count 10 -> 11, 59px upward).
## **Measured along the path where the command goes through the queue** — that is also where the block lives, and
##  that is the path the server uses in multiplayer.
func _downed_cannot_fire(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	# Knock it down first. The queue is not used here (mixing in recoil collapses the layout — see `_beat_down` above).
	_beat_down(t, w, spell, ch, Character.MAX_HP / Character.DAMAGE_HIT)
	t.ok(ch.downed, "쓰러졌다 (검사의 전제)")
	_frames(w, SETTLE_FRAMES)

	var fired := w.fire_count()
	var kb := ch.recoil_vx
	var vy := ch.vy
	w.enqueue(SpellSim.cmd_fire(
		RECOIL_CX, _aim_row(ch), AIM_DX, 0, Tuning.ELEM_NONE, Glyph.GLYPH_NONE))
	_frames(w, Tuning.TICK_DIVIDER)
	t.eq(w.fire_count(), fired, "쓰러진 채로는 발사 수가 안 오른다")
	t.eq(spell.active_count(), 0, "탄도 안 난다")
	# **Do not expect the same value** — the decay runs during those three frames too. Had recoil been applied it would have **grown.**
	t.ok(absf(ch.recoil_vx) <= absf(kb), "그러니 가로 반동도 안 붙는다 (잔량이 줄기만 했다)")
	# **The label was narrowed. The old label ("the vertical gets nothing but gravity either") was wider than what is measured.**
	#  This command is **horizontal** (ady = 0), so `recoil()`'s vertical component was **0 to begin with** —
	#   vy does not change even without the downed guard. => **This axis cannot be bitten in principle.**
	#  **And the vertical recoil itself was deleted (`character.recoil()`), so no command can bite it now.**
	#   It used to say "just rewrite it with a downward-firing command", and **that path is gone** —
	#   the behavior to be measured disappeared; the check did not get lazy.
	#  The old expected expression (`vy + GRAVITY_PX*DT`) was **a value that happened to match the rounding phase**:
	#   with the old (larger) gravity, 1px was consumed every single frame so `_move_y` blocked and zeroed vy
	#   every time. **This exact equality is itself the same trap, just one gravity value away from biting again** —
	#   the player's own gravity (split into `PLAYER_GRAVITY_PX`, 2400 -> 1536, `docs/design/game-feel.md` "11b")
	#   already moved it: one frame's worth of gravity (`PLAYER_GRAVITY_PX * DT` = 25.6px/s) now rounds `move_y`'s
	#   sub-pixel remainder to 0 on some frames, so `vy` is not
	#   reset on every single frame anymore — only whenever the accumulated remainder finally rounds to 1px and
	#   the ground blocks it. **Bounding it instead of pinning an exact value is what survives the next gravity
	#   retune too.**
	t.ok(ch.on_ground and ch.vy <= Character.PLAYER_GRAVITY_PX * DT + 0.01,
		"접지 상태의 세로 속도가 중력 한 프레임치를 넘지 않는다 (위로 안 떴다 — vy=%.1f)" % ch.vy)

	# **Inversion — if it is not downed, the same command goes out.** Without it, this is indistinguishable
	#  from "the command was wrong to begin with".
	var g2 := _floor_grid()
	var spell2 := SpellSim.new()
	var ch2 := _stander()
	var w2 := WorldStep.new(g2, spell2, ch2)
	w2.enqueue(SpellSim.cmd_fire(
		RECOIL_CX, _aim_row(ch2), AIM_DX, 0, Tuning.ELEM_NONE, Glyph.GLYPH_NONE))
	_frames(w2, Tuning.TICK_DIVIDER)
	t.eq(w2.fire_count(), 1, "안 쓰러졌으면 같은 커맨드가 나간다 (대조군)")


## **Inversion**: at a health that is not yet down, **the same input changes x.**
## The design doc wrote "health 1", but with a base damage of 10 that value never occurs — the real value is **10.**
func _ten_hp_still_walks(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	_beat_down(t, w, spell, ch, Character.MAX_HP / Character.DAMAGE_HIT - 1)
	t.eq(ch.hp, Character.DAMAGE_HIT, "체력이 %d 남았다 (한 대 남은 상태)" % Character.DAMAGE_HIT)
	t.ok(not ch.downed, "아직 안 쓰러졌다")

	_frames(w, SETTLE_FRAMES)
	var x0 := ch.x
	_frames(w, 60, 1.0)
	t.ok(ch.x > x0, "체력 %d에서는 같은 입력에 x가 변한다 (%d → %d)"
		% [Character.DAMAGE_HIT, x0, ch.x])


# ── Building the world ─────────────────────────────────────────────

## Only the row the character stands on is **wood**; below it is stone.
func _wood_floor_grid() -> CellGrid:
	var g := _floor_grid()
	g.apply(CellGrid.cmd_fill(WOOD_CX0, WOOD_CY, WOOD_CX1, WOOD_CY, Mat.WOOD))
	return g


## One horizontal shot that crosses the character's box **on the first tick.** No element plus no glyph.
## The origin is produced **from the character's current position** — see the `HIT_LEAD_PX` comment above.
func _hit_cmd_at(ch: Character) -> Dictionary:
	return _hit_cmd_at_with(ch, Glyph.GLYPH_NONE)


## Same leaping placement as `_hit_cmd_at`, carrying `glyphs` instead of an empty list — the Stage-A power
##  checks below need a direct hit that also carries a MODIFY glyph.
func _hit_cmd_at_with(ch: Character, glyphs: int) -> Dictionary:
	var cx := floori((ch.x - HIT_LEAD_PX) / float(Tuning.CELL_PX))
	return SpellSim.cmd_fire(cx, _aim_row(ch), AIM_DX, 0, Tuning.ELEM_NONE, glyphs)


## The row through the **middle** of the box. For the same reason as x it is **derived from the character** —
##  hardcode it and a shot after the character has moved vertically silently misses.
func _aim_row(ch: Character) -> int:
	return floori((ch.y + Character.H_PX * 0.5) / float(Tuning.CELL_PX))


## The radius (px) of a generation 0 blast. **Taken from the table** — hardcode it and the value exists in two copies,
##  and the diverged one keeps the label "inside/outside the radius" while measuring nothing at all.
static func _blast_r_px() -> float:
	return float(Tuning.blast_rd(0) * Tuning.CELL_PX)


## The cell for placing a blast outside the box on `side` (+1 right, -1 left) but **inside** the radius.
## `_circle_hits_box` decides by the **shortest distance** from the box to the circle's center, so the reference point
##  is the box's **side**, not its center. Measure from the center and it drifts silently by half the box width.
static func _blast_cx_beside(stand_x: int, side: int) -> int:
	var edge := stand_x + Character.W_PX if side > 0 else stand_x
	return floori((float(edge) + side * _blast_r_px() * BLAST_NEAR_RATIO) / float(Tuning.CELL_PX))


## The top-left x for standing the box **outside** the blast radius (inversion 1).
## The box's **right edge** has to be outside the radius, so the box width is subtracted and the top-left returned —
##  without subtracting it, the box's right corner catches inside the circle while you believe "it was stood outside".
static func _far_stand_x(blast_cx: int) -> int:
	return int(Body._cell_px(blast_cx) - _blast_r_px() * BLAST_FAR_RATIO) - Character.W_PX


## The spread layout — **the floor immediately right of the character** (half a box width out from the box's side).
## **It is not derived from the blast radius.** What is measured here is "how many hits when eight spread bolts scatter
##  from that spot", so the reference for the position is the box — tie it to the radius and the day the radius shrinks
##  this position moves **inside the box**, direct hits mix in, and what is being counted quietly changes.
static func _spread_cx(stand_x: int) -> int:
	return floori(float(stand_x + Character.W_PX + Character.W_PX / 2) / float(Tuning.CELL_PX))


## One blast driven into the floor at cell `cx`. It is no-element, so **nothing catches fire** — only the blast is measured.
func _blast_cmd(cx: int) -> Dictionary:
	var one: Array[int] = [Glyph.GLYPH_BLAST]
	return SpellSim.cmd_fire(cx, BLAST_FROM_CY, 0, 10, Tuning.ELEM_NONE, Glyph.pack(one))


## **The conversion is the real code's** (`Body._fp_px`). If the net keeps its own conversion there are
##  two copies, and then this check measures **a different box** from the game.
func _outside_box(box_x: int, px: float) -> bool:
	return px < float(box_x) or px > float(box_x + Character.W_PX)


func _fire_cmd() -> Dictionary:
	return SpellSim.cmd_fire(FIRE_CX, FIRE_CY, AIM_DX, 0, Tuning.ELEM_FIRE, Glyph.GLYPH_NONE)


## Generation 0's launch speed (fixed point). **Taken from the table** — hardcode it and the value exists in two copies.
func _speed_fp() -> int:
	return Tuning.speed_cells(0) << SpellSim.FP_SHIFT


## One application of drag. It has to be in **the same order** as `spell_sim._advance` — there drag is multiplied first
##  and then the position added, so one tick's displacement is "the speed after drag has been applied".
func _drag(v: int) -> int:
	return v * Tuning.DRAG_NUM / Tuning.DRAG_DEN


func _floor_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, FLOOR_CY, CellGrid.W - 1, FLOOR_CY + FLOOR_DEPTH_CY - 1, Mat.STONE))
	return g


func _stander() -> Character:
	return _stander_at(STAND_X)


func _stander_at(px: int) -> Character:
	var ch := Character.new()
	ch.place(px, FLOOR_TOP - Character.H_PX)
	return ch


func _world(g: CellGrid) -> WorldStep:
	return WorldStep.new(g, SpellSim.new(), _stander())


func _frames(w: WorldStep, n: int, axis := 0.0) -> void:
	for _i in n:
		w.frame(DT, axis, false, false)


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("net_damage: %s 를 못 읽었다" % path)
		return ""
	return f.get_as_text()
