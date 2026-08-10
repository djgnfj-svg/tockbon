extends RefCounted
## Does the character walk over the terrain it broke (design acceptance 4).
##
## This net running at all is thanks to `src/actor/character.gd` being RefCounted.
## Were it a Node, a scene would have to be stood up, and then this acceptance would be measured "by eye only".
##
## The character is pushed in 1px steps while per-frame movement is 4.33px, so **the last piece is fractional**.
## That is why it is measured as "within 1px" rather than "exactly this much". The vertical is different —
## landing is descending 1px at a time until blocked, so it must be **exactly** the ground surface.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Character := preload("res://src/actor/character.gd")
## The C series (water flow) measures the force function (`water_flow`) directly, without a character — like
##  `standing_in_fire`, `Body` does not carry its own constants so it has to be stood up as `Body.new(w, h, step)`
##  (there is no reference in this file's header; the `body.gd` header gives the reason).
const Body := preload("res://src/actor/body.gd")

const DT := 1.0 / 60.0
const FLOOR_CY := 100      # top cell of the floor
const FLOOR_TOP := FLOOR_CY * Tuning.CELL_PX     # 400px
const REST_Y := FLOOR_TOP - Character.H_PX       # 368px — y of a character standing on the floor

## **The floor is laid thin — CLAUDE.md: "a slow net is not a performance problem but the path by which the
##  harness gets abandoned".** Measured: the old floor laid down to `CellGrid.H - 1` was 4096x908=3,719,168 cells
##  and took 2,719ms per pass (this file took 46 seconds of the whole net run — the time was set not by the number
##  of checks but by how many times the floor was laid). **Why it is safe**: `cell_grid.mat_at()` returns `STONE`
##  outside the grid, so there was never a reason for the floor to be thick — the character only plays within a
##  few px of the surface.
## 32 cells (128px) was chosen — this file has no check where a blast carves terrain, so there is no need to
##  allow for `carve_r` (8 cells) headroom, but the value is kept aligned with the future carving checks that
##  will live in this same file.
const FLOOR_DEPTH_CY := 32

## **The shortest key press a human can produce (frames). The variable jump is measured with this.**
##  A finger takes about **0.05 seconds** to press and release a key — 1-2 frames (0.017-0.033s) is
##  **an input a human cannot produce**, and measuring with it passes things that do not work in the game
##  (which actually happened).
const HUMAN_TAP_FRAMES := 3


func run(t) -> void:
	# **It was not raised in the 32px switch.** What makes a ledge is a blast and a blast is in **cells**, and
	# the cell did not change — "at 1 cell even a slight dig catches you" still stands (`character.gd`).
	# The opposing grounds ("stepping up a whole tile mushes the sense of power") got **looser** as the tile
	# became 8 cells. The two grounds point different ways, and the narrower one wins.
	t.eq(Character.STEP_CELLS, 2, "스텝 오프셋이 2셀이다")
	# **The width is no longer equal to the tile — only the collision box was narrowed to 20**
	#  (user's acceptance: "a hit registered before touching the wall"). The GDD's "character thickness = tile"
	#  is a contract about the **visible** size and that is held by the sprite cell (`Fx.CHAR_CELL_PX` 32) —
	#  `net_sprite` measures that side.
	#  **Do not assert 32 again here.** That would undo the split between the sprite and the box entirely.
	t.eq(Character.W_PX, 20, "캐릭터 충돌 폭이 20px이다 (그림 칸 32px보다 좁다)")
	t.ok(Character.W_PX < Character.H_PX,
		"충돌 상자가 세로로 길다 (%dx%d — 세로는 안 건드렸다)" % [Character.W_PX, Character.H_PX])
	# **Nobody was measuring `H_PX`.** The checks below build expected values as `FLOOR_TOP - H_PX` while the
	#  actual value goes through the same constant, so **if both go wrong together they cancel out** — the box
	#  could become 32x16 and everything would still be green.
	#  And that would only show as "the head is stuck in the wall but it passes through" (GDD grid).
	t.eq(Character.H_PX, 32, "캐릭터 높이가 32px = 지형 타일과 같다")

	_fall_and_land(t)
	_jump_height(t)
	_short_press_jumps_lower(t)
	# -- F. the two forgiveness windows (game-feel.md, the user's report) --
	_coyote_jump_after_the_ground_is_gone(t)
	_coyote_expires(t)
	_coyote_is_spent_by_the_jump_it_paid_for(t)
	_buffered_press_fires_on_landing(t)
	_buffer_expires(t)
	_ledge(t, 2, true)
	_ledge(t, 3, false)
	_broken_ground(t)
	_wall(t)
	_airborne_never_climbs(t)
	# -- A. infinite jump underwater (water-jump-and-escape.md stage 1) --
	_submerged_jump_fires_repeatedly(t)
	_submerged_jump_boundary(t)
	_leaving_water_blocks_the_very_next_frame(t)
	_submerged_jump_includes_the_foot_row(t)
	# -- C. the water flow pushes the character (water-jump-and-escape.md stage 4) --
	_water_push_zero_when_symmetric(t)
	_water_push_sign_both_ways(t)
	_water_push_scales_with_diff(t)
	_water_push_zero_at_equilibrium(t)
	_water_push_pair_moves_and_stops(t)
	_water_push_does_not_move_water(t)
	_water_push_ignores_fire(t)
	_water_push_stops_the_frame_water_leaves(t)


func _floor_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, FLOOR_CY, CellGrid.W - 1, FLOOR_CY + FLOOR_DEPTH_CY - 1, Mat.STONE))
	return g


## It is walking, so both jump arguments are false — **it was neither pressed nor is being held.**
func _walk(g: CellGrid, ch: Character, frames: int, axis: float) -> void:
	for _i in frames:
		ch.step(g, DT, axis, false, false)


## It falls and lands. If the landing position is off by even 1px the character is buried in terrain or floating.
func _fall_and_land(t) -> void:
	var g := _floor_grid()
	var ch := Character.new()
	ch.place(160, 200)
	_walk(g, ch, 120, 0.0)
	t.ok(ch.on_ground, "떨어진 뒤 착지한다")
	t.eq(ch.y, REST_Y, "착지 높이가 지표면에 정확히 붙는다")


## **Jump apex height — this is where plan risk 1 is closed.**
##  Doubling **only one** of `PLAYER_GRAVITY_PX` and `JUMP_VY_PX` makes the apex 4x or half, and
##  **not one error is raised.** Measured: with `JUMP_VY` alone not raised, **all 1288 nets were green.**
##  => The two below are the only automatic detectors that bite that.
##
## **Behavior and the constant are measured separately. The two numbers differ, so do not mix them into one line:**
##  · behavior **103px** — the value from actually jumping. Movement pushed 1px at a time means
##    **integer truncation shaves it.**
##    Putting the analytic 108 here makes it **red forever.** Truncation is not a bug but a property of this
##    movement scheme
##  · constant **3.375 tiles** — the analytic `v^2/2g` = 108px / tile 32px. **Read in tiles** so this line does
##    not go stale with it the day the scale changes again
##
## **`103`, not the old `102` — `character.gd`'s `PLAYER_GRAVITY_PX`/`JUMP_VY_PX` moved (2400/-720 -> 1536/-576,
##  "game feels sped up") while the analytic 108/3.375 was deliberately held fixed** (the pair was chosen from
##  the `v0=36k, g=6k^2` family, which keeps `v0^2/2g` exactly 108 for every `k`). The truncated value still
##  shifts because *which* frame the discrete rise crosses zero velocity changed (old: exactly frame 18, landing
##  on an integer cumulative sum by luck; new: frame 23, landing mid-remainder) — this is the same "truncation
##  is a property, not a bug" the box above already names, just recomputed for the new pair.
const JUMP_PEAK_PX := 103
const JUMP_PEAK_TILES := 3.375

const LEDGE_CX := 30
const LEDGE_PX := LEDGE_CX * Tuning.CELL_PX      # 120px — the ledge's left face


## Measures the apex by actually jumping. **The jump input (`jump`) is one frame only** —
##  fed continuously it jumps again on every landing and stops being "the height of one jump".
##  **`jump_held` stays true.** Since the variable jump came in these are different axes, and
##   the "apex 102px" measured here is the value for **a jump held to the end.**
func _jump_height(t) -> void:
	var g := _floor_grid()
	var ch := Character.new()
	ch.place(160, REST_Y)
	_walk(g, ch, 5, 0.0)
	t.ok(ch.on_ground, "뛰기 전에 접지 상태다 (검사의 전제)")
	var y0 := ch.y

	ch.step(g, DT, 0.0, true, true)
	var top := ch.y
	for _i in 120:
		ch.step(g, DT, 0.0, false, true)
		top = mini(top, ch.y)

	t.eq(y0 - top, JUMP_PEAK_PX, "끝까지 누른 점프의 도달 높이가 %dpx다" % JUMP_PEAK_PX)
	# **It also watches the coming back down.** Without that, an implementation that floats up and never
	#  comes down would pass too.
	t.ok(ch.on_ground and ch.y == y0, "떨어져서 원래 높이로 돌아온다 (y=%d · 시작 %d)" % [ch.y, y0])

	# **The constant side — how many tiles the analytic value is.** Measuring behavior only would miss the case
	#  where both constants are changed wrongly **by the same ratio** (both x3, say), leaving the apex unchanged.
	#  This line bites that branch.
	var peak := Character.JUMP_VY_PX * Character.JUMP_VY_PX / (2.0 * Character.PLAYER_GRAVITY_PX)
	var tile := float(Tuning.TILE_CELLS * Tuning.CELL_PX)
	t.eq(snappedf(peak / tile, 0.001), JUMP_PEAK_TILES,
		"해석식 도달 높이가 %s타일이다 (v²/2g = %.0fpx ÷ 타일 %.0fpx)" % [
			JUMP_PEAK_TILES, peak, tile])


## **Variable jump — how long you hold sets the height** (user request).
##
## **Measuring only "a short press is lower" is not enough** — even with the jump killed entirely
##  (deleting `vy = JUMP_VY_PX`), "lower" is true. => Three things are measured **together**:
##   (1) a short press **actually lifts** (not 0)   (2) it is **lower** than a press held to the end
##   (3) a mid-length press lands **in between** — that is "it is modulated by duration", and
##      (1) and (2) alone cannot distinguish it from **a two-position switch** (pressed / released)
##
## It is a height comparison, so **exact px are not hardcoded.** Touching the cut ratio changes every value, and
##  forcing the expected values to be fixed each time makes it "the net copies the constant", which measures nothing.
func _short_press_jumps_lower(t) -> void:
	# **It is measured with `HUMAN_TAP_FRAMES`. Do not measure with 1 frame — that is how it was missed once.**
	#  At first a 1-frame (0.017s) press was used as "short" and **the nets were green while it did not work
	#  in the game** (user: "seems like it did not work"). At a cut ratio of 0.55, 1 frame was 46% and split
	#  cleanly, but **the shortest tap a human can produce (0.05s) was 67%** — by hand it almost always came out
	#  at maximum.
	#  **Measuring with an input a human cannot produce yields "it works" while the game does not.**
	#
	# The stretch where the cut bites is `18 x (1 - ratio)` frames. If "mid" falls outside it, the same value as
	#  `full` comes out and **the check sits on the boundary measuring nothing quietly** — 8 was chosen once and
	#  that actually happened (102 vs 102).
	var full := _jump_peak(999)                  # held to the end
	var half := _jump_peak(HUMAN_TAP_FRAMES * 2) # held twice that long
	var tap := _jump_peak(HUMAN_TAP_FRAMES)      # the shortest tap a human can produce

	t.ok(tap > 0, "사람이 낼 수 있는 최단 탭으로도 뜬다 (%dpx — 점프가 죽은 게 아니다)" % tap)
	t.ok(tap < full, "짧게 누르면 끝까지 누른 것보다 낮다 (%d < %d)" % [tap, full])
	# **This is the line that separates "modulation" from "a switch".**
	t.ok(tap < half and half < full,
		"중간까지 누르면 그 사이 높이다 (%d < %d < %d — 누른 시간에 비례한다)" % [tap, half, full])
	# **"They do differ" is not enough — to be felt in the hand they must differ clearly.**
	#  This line is what bites the failure of this round (cut 0.55): back then the shortest tap was **67%** and now it is 37%.
	#  The half threshold itself is a feel value. But **without it, "anything even slightly lower passes"**,
	#   and that turns differences nobody can feel on screen into green.
	t.ok(tap * 2 < full,
		"최단 탭이 최대의 절반 아래다 (%d / %d = %d%% — 손으로 조절이 느껴진다)" % [
			tap, full, int(100.0 * float(tap) / float(full))])
	# The constant side is looked at too. Measuring behavior alone, leaving the cut at 1.0 and reducing
	#  `JUMP_VY_PX` also makes "lower" hold, so "there is a variable jump" and "the jump is just weak" are indistinguishable.
	t.ok(Character.JUMP_CUT_RATIO > 0.0 and Character.JUMP_CUT_RATIO < 1.0,
		"컷 비율이 0과 1 사이다 (%.2f — 1이면 안 잘리고 0이면 즉시 멈춘다)" % Character.JUMP_CUT_RATIO)


## The apex reached by jumping (px). Holds the key for `hold_frames` and then releases.
## `jump` (the press moment) is the first frame only and only `jump_held` continues — the same shape as the game.
func _jump_peak(hold_frames: int) -> int:
	var g := _floor_grid()
	var ch := Character.new()
	ch.place(160, REST_Y)
	_walk(g, ch, 5, 0.0)
	var y0 := ch.y
	var top := y0
	for i in 120:
		ch.step(g, DT, 0.0, i == 0, i < hold_frames)
		top = mini(top, ch.y)
	return y0 - top


#  F. coyote time and the jump buffer (`docs/design/game-feel.md`)
#
# **The window is measured in frames derived from the constant, never as a literal 6.** Write 6 here and the
#  day `COYOTE_SEC` is tuned the check either goes red for no reason or silently stops covering the window.
#
# **Why the boundary frame itself is not pinned** (A-2 pins its boundary; this cannot). At exactly
#  `COYOTE_SEC / DT` frames the remaining time is `0.1 - 6*(1/60)`, which in floats is **1.4e-17, not 0** —
#  the branch there is decided by rounding, not by design. So the pair measured is **one frame inside** and
#  **two frames past** the window, and the frame on the line is deliberately left unmeasured.
const COYOTE_IN_FRAMES := int(Character.COYOTE_SEC / DT) - 1
const COYOTE_OUT_FRAMES := int(Character.COYOTE_SEC / DT) + 2


## Stands the character on the floor, then **erases the floor** — the same vessel idiom as A-3's vanishing water.
## **Walking off a real ledge would measure the ledge too**; this isolates "the ground stopped being there".
func _standing_then_cut_loose() -> Array:
	var g := _floor_grid()
	var ch := Character.new()
	ch.place(160, REST_Y)
	_walk(g, ch, 5, 0.0)
	g.apply(CellGrid.cmd_fill(0, FLOOR_CY, CellGrid.W - 1, FLOOR_CY + FLOOR_DEPTH_CY - 1, Mat.EMPTY))
	return [g, ch]


## `vy` for a frame in which the jump fired, one frame of gravity already added — A-1's reasoning, and the
## reason this file measures that sum rather than `JUMP_VY_PX` itself.
func _fired_vy() -> float:
	return Character.JUMP_VY_PX + Character.PLAYER_GRAVITY_PX * DT


## **F-1 — pressed after the ground is gone, and it still jumps.**
##
## **What goes red when inverted**: drop `or _coyote_left > 0.0` from the jump condition — the character is
##  airborne with no water, so it never jumps and just falls.
func _coyote_jump_after_the_ground_is_gone(t) -> void:
	var made := _standing_then_cut_loose()
	var g: CellGrid = made[0]
	var ch: Character = made[1]

	for _i in COYOTE_IN_FRAMES:
		ch.step(g, DT, 0.0, false, false)
	t.ok(not ch.on_ground, "발판이 사라져 공중이다 (전제)")

	ch.step(g, DT, 0.0, true, true)
	t.eq(ch.vy, _fired_vy(),
		"땅을 떠난 뒤 %d프레임까지는 점프가 살아 있다 (코요테, vy=%.1f)" % [COYOTE_IN_FRAMES, ch.vy])


## **F-2 — and it does expire. The pair with F-1.**
##
## **What goes red when inverted**: refill `_coyote_left` every frame instead of only while grounded (or never
##  age it) — then the window never closes and this jump fires too, which is **flying**, not coyote time.
## **F-1 alone would pass with an infinite window**, which is exactly the shape A-2 was written to refuse.
func _coyote_expires(t) -> void:
	var made := _standing_then_cut_loose()
	var g: CellGrid = made[0]
	var ch: Character = made[1]

	for _i in COYOTE_OUT_FRAMES:
		ch.step(g, DT, 0.0, false, false)
	var vy_before := ch.vy
	ch.step(g, DT, 0.0, true, true)
	t.eq(ch.vy, vy_before + Character.PLAYER_GRAVITY_PX * DT,
		"%d프레임이 지나면 코요테가 닫힌다 (중력만 더해진 vy=%.1f)" % [COYOTE_OUT_FRAMES, ch.vy])


## **F-3 — the jump it paid for spends it. This is the double-jump guard.**
##
## **What goes red when inverted**: delete `_coyote_left = 0.0` inside the jump branch. The frame you jump from
##  the ground refilled the window to full, so a second press a few frames later **jumps again** — and a double
##  jump is a town research unlock (GDD), not something a feel fix may hand out.
## **This is the check that would have caught it silently**: on screen a double jump looks like a feature.
func _coyote_is_spent_by_the_jump_it_paid_for(t) -> void:
	var g := _floor_grid()
	var ch := Character.new()
	ch.place(160, REST_Y)
	_walk(g, ch, 5, 0.0)

	ch.step(g, DT, 0.0, true, true)
	t.eq(ch.vy, _fired_vy(), "땅에서 한 번 뛴다 (전제)")

	for _i in COYOTE_IN_FRAMES - 1:
		ch.step(g, DT, 0.0, false, true)
	var vy_before := ch.vy
	ch.step(g, DT, 0.0, true, true)
	t.eq(ch.vy, vy_before + Character.PLAYER_GRAVITY_PX * DT,
		"뛴 직후 다시 눌러도 두 번은 안 뛴다 (중력만 더해진 vy=%.1f)" % ch.vy)


## The apex reached **after first touching the ground**, when the only press happens `press_at` frames in.
## **Measuring the apex, not `vy`** — a buffered jump fires on the landing frame, and reading `vy` there means
##  guessing which frame that is. The height is the same answer with no frame counting.
func _buffer_peak(press_at: int) -> int:
	var g := _floor_grid()
	var ch := Character.new()
	# **Dropped from a height, so it is never grounded before the press** — that keeps the coyote window empty
	#  and makes this a measurement of the buffer alone. 100px is **22** frames of falling
	#  (was 17 — `GRAVITY_PX` 2400 -> 1536, `docs/design/game-feel.md` "11b": weaker gravity falls slower too).
	ch.place(160, REST_Y - 100)
	var landed := false
	var top := REST_Y
	for i in 60:
		ch.step(g, DT, 0.0, i == press_at, i >= press_at)
		if ch.on_ground:
			landed = true
		if landed:
			top = mini(top, ch.y)
	return REST_Y - top


## **F-4 — pressed just before landing, and it fires on the landing frame.**
##
## **What goes red when inverted**: judge the raw `jump` argument instead of `_jump_buffer_left` — the press
##  happened in the air with nothing to jump from, so it is eaten and the character just lands (peak 0).
func _buffered_press_fires_on_landing(t) -> void:
	var peak := _buffer_peak(19)   # 22 frames of falling, so this is 3 frames before touching down
	t.ok(peak > 50, "착지 3프레임 전에 누른 점프가 착지 순간 발사된다 (%dpx 떴다)" % peak)


## **F-5 — and the buffer expires too. The pair with F-4.**
##
## **What goes red when inverted**: never age `_jump_buffer_left` — a press from the very start of the fall
##  survives 17 frames and still jumps, which means **any press ever made** is queued forever.
func _buffer_expires(t) -> void:
	var peak := _buffer_peak(0)    # 17 frames before landing — far outside the window
	t.eq(peak, 0, "너무 일찍 누른 점프는 착지해도 안 나간다 (%dpx)" % peak)


func _ledge_grid(cells: int) -> CellGrid:
	var g := _floor_grid()
	# Laid thin for the same reason as the `FLOOR_DEPTH_CY` box above — above the ledge only a few px of surface are needed.
	g.apply(CellGrid.cmd_fill(
		LEDGE_CX, FLOOR_CY - cells, CellGrid.W - 1, FLOOR_CY + FLOOR_DEPTH_CY - 1, Mat.STONE))
	return g


## A ledge of `cells` cells. 2 cells can be walked up, 3 cannot.
func _ledge(t, cells: int, expect_climb: bool) -> void:
	var ledge_cx := LEDGE_CX
	var ledge_top_cy := FLOOR_CY - cells
	var g := _ledge_grid(cells)

	var ch := Character.new()
	ch.place(40, REST_Y)
	_walk(g, ch, 120, 1.0)

	var ledge_px := ledge_cx * Tuning.CELL_PX
	var top_y := ledge_top_cy * Tuning.CELL_PX - Character.H_PX
	if expect_climb:
		t.ok(ch.x > ledge_px, "%d셀 턱을 걸어서 올라선다 (x=%d)" % [cells, ch.x])
		t.eq(ch.y, top_y, "%d셀 턱 위에 선다" % cells)
	else:
		# It stops against the wall. The box's right edge is the ledge's left face, so x is **exactly** ledge_px - 32.
		t.eq(ch.x, ledge_px - Character.W_PX, "%d셀 턱에 딱 붙어 막힌다" % cells)
		t.eq(ch.y, REST_Y, "%d셀 턱을 못 올라간다" % cells)


## **This is the body of acceptance 4.** Where a blast passed is not a smooth floor but a surface strewn with
## 1-cell ledges, and in this game that is not the exception but the default state.
func _broken_ground(t) -> void:
	var g := _floor_grid()
	var last_top := FLOOR_CY
	for k in range(1, 7):
		var sx := 30 + (k - 1) * 4
		# The last step runs to the right edge — otherwise the character climbs all the stairs and falls back
		# off, and the net cannot separate "it could not climb" from "it climbed and came back down".
		var ex := 33 + (k - 1) * 4 if k < 6 else CellGrid.W - 1
		last_top = FLOOR_CY - k
		# The last step (k=6) is where it widens across the whole width (4096 cells), so laid thick this
		#  becomes another 3.7M cells — same reason as the `FLOOR_DEPTH_CY` box.
		g.apply(CellGrid.cmd_fill(sx, last_top, ex, FLOOR_CY + FLOOR_DEPTH_CY - 1, Mat.STONE))

	var ch := Character.new()
	ch.place(40, REST_Y)
	_walk(g, ch, 180, 1.0)
	t.eq(ch.y, last_top * Tuning.CELL_PX - Character.H_PX, "1셀 턱 여섯 개를 걸어서 넘는다")
	t.ok(ch.on_ground, "계단을 다 오르고 접지 상태다")


## A wall higher than 3 cells cannot be climbed — if the step offset were universal, terrain would lose its meaning.
func _wall(t) -> void:
	var g := _floor_grid()
	var wall_cx := 30
	var wall_x := wall_cx * Tuning.CELL_PX - Character.W_PX
	g.apply(CellGrid.cmd_fill(wall_cx, FLOOR_CY - 8, wall_cx + 3, FLOOR_CY - 1, Mat.STONE))
	var ch := Character.new()
	ch.place(40, REST_Y)
	_walk(g, ch, 120, 1.0)
	t.eq(ch.x, wall_x, "8셀 벽에 막힌다")


## **The step offset does not apply in mid-air.** If it did, while pressed against a wall the character would
## **climb the wall** rather than a ledge — jump height is an axis of terrain design and that would become meaningless.
##
## **Walking in from a distance cannot measure this.** Falling from 344px it always lands before touching the
##  wall (a 40px fall ~= 15 frames = 26px of forward travel), and then deleting the `on_ground` guard is still green.
##  Measured: in 20 frames it only reached x=83 while the wall was at x=104 — **it never even touched it.**
##  **That measurement is from the 16px world** (before the 32px switch). The conclusion (walking in from a
##   distance cannot measure it) still stands but **the numbers do not match — it was not re-measured.** The
##   starting position below is derived from constants so it follows along by itself.
##  => **It starts pressed against the ledge's left face and in mid-air from the beginning.**
##
## The ledge is 2 cells — `_ledge(2, true)` already measured that **the same terrain can be walked up.**
##  So failing to climb here is established to be down to **the one guard**, not to the terrain.
func _airborne_never_climbs(t) -> void:
	var g := _ledge_grid(2)
	var ledge_top_y := (FLOOR_CY - 2) * Tuning.CELL_PX - Character.H_PX  # 360
	var ch := Character.new()
	# Between the ledge top (360) and the floor top (368). A height where the feet catch the ledge's side while still airborne.
	var start_y := ledge_top_y + 4
	var start_x := LEDGE_PX - Character.W_PX
	ch.place(start_x, start_y)

	# These two lines are the premise. Broken, the checks below are not measuring "mid-air" and become meaningless.
	ch.step(g, DT, 0.0, false, false)
	t.ok(not ch.on_ground, "시작이 공중이다 (y=%d · 바닥 %d)" % [ch.y, REST_Y])
	t.eq(ch.x, start_x, "턱 왼쪽 면에 붙어 있다")

	# **One frame splits it.** Without the guard, on this frame it is lifted 4px and x moves forward.
	ch.step(g, DT, 1.0, false, false)
	t.eq(ch.x, start_x, "공중에서 턱을 밀어도 앞으로 안 나간다")
	t.ok(ch.y >= start_y, "공중에서 들리지 않는다 (y=%d · 시작 %d)" % [ch.y, start_y])

	# After landing it climbs the same ledge — measuring that the guard means "only in mid-air", not "never again".
	_walk(g, ch, 90, 1.0)
	t.eq(ch.y, ledge_top_y, "착지한 뒤에는 같은 턱을 올라선다")


# ══════════════════════════════════════════════════════════════════
#  A. infinite jump underwater (`water-jump-and-escape.md` stage 1)
# ══════════════════════════════════════════════════════════════════
#
# Not `net_water` — what is measured is **the character's behavior**, not the water's (per the plan).
# **No new floor is laid** — the vessels below are an empty grid with **no floor** plus a water column.
#  The reason `_floor_grid()` (above, 32 cells deep of STONE) is not reused is exactly the opposite: for the A
#  series, `on_ground` must be **false throughout** for "the jump works on water alone" to be captured as a value —
#  with a floor the character lands and `on_ground` cuts in, and then it is unclear what these checks measure.

## `set_water` cannot go through `cmd_fill` (same reason as `net_water._cmd_fill_refuses_water`) —
## it is called per cell. The box is small (the constants below) so the cost is negligible.
func _water_box(g: CellGrid, x0: int, x1: int, y0: int, y1: int, amount: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			g.set_water(x, y, amount)


## The position of the water column shared by the A series (cells). The width is the character box (5 cells) plus
## one row of clearance under the feet, and the height is far more generous than the jump apex (102px = 25.5 cells) —
## three jumps in a row leave neither the top nor the bottom edge.
const WATER_CX0 := 300
const WATER_CX1 := 314
const WATER_CY0 := 150
const WATER_CY1 := 230
const WATER_START_Y := (WATER_CY0 + 20) * Tuning.CELL_PX


## A floorless vessel plus a character placed in the middle of that water column. `amount` is the water depth —
## A-2 (the boundary pair) uses this argument to split 32 from 33.
func _submerged(amount: int) -> Array:
	var g := CellGrid.new()
	_water_box(g, WATER_CX0, WATER_CX1, WATER_CY0, WATER_CY1, amount)
	var ch := Character.new()
	ch.place(WATER_CX0 * Tuning.CELL_PX, WATER_START_Y)
	return [g, ch]


## **A-1 — an air jump works in deep water. Three times in a row.**
##
## **What goes red when inverted**: revert the jump condition to `on_ground` alone — this vessel has no floor so
##  `on_ground` is false throughout, and it **never jumps once and just falls.**
##
## **"vy == JUMP_VY_PX" is not measured literally — it is written differently from the plan's wording.**
##  `character.step()` adds gravity **within the very frame** the jump is assigned
##  (`_body.apply_gravity`: `vy = minf(vy + PLAYER_GRAVITY_PX*dt, ...)`, the line right after the jump assignment).
##  A ground jump goes through the same thing, so this is not a problem water created — which is why `vy` right
##  after each jump is exactly `JUMP_VY_PX + PLAYER_GRAVITY_PX*DT` (one frame of gravity). **That deterministic value**
##  is what measures "the jump actually fired". It is the same reason the other checks in `net_character` measure
##  `y` rather than `vy` directly.
func _submerged_jump_fires_repeatedly(t) -> void:
	var made := _submerged(Tuning.WATER_MAX)
	var g: CellGrid = made[0]
	var ch: Character = made[1]

	ch.step(g, DT, 0.0, false, false)
	t.ok(not ch.on_ground, "물기둥엔 바닥이 없어 시작이 공중이다 (전제)")

	var expected := Character.JUMP_VY_PX + Character.PLAYER_GRAVITY_PX * DT
	for i in 3:
		ch.step(g, DT, 0.0, true, true)
		t.eq(ch.vy, expected, "%d번째 공중 점프가 물속에서 발사된다 (vy=%.1f)" % [i + 1, ch.vy])


## **A-2 — the boundary pair. At 32 (the threshold itself, shallow) it does not work; at 33 (one grain deeper) it does.**
##
## **What goes red when inverted**: swap `>` and `>=` and one of the two comes out reversed.
## **Measuring only at 0 would pass even with the threshold changed to 200** (the trap the plan named —
##  "the value matches by accident"). So the values just above and below the threshold are measured **together**.
func _submerged_jump_boundary(t) -> void:
	var expected := Character.JUMP_VY_PX + Character.PLAYER_GRAVITY_PX * DT

	var shallow := _submerged(Tuning.WATER_WET)
	var g0: CellGrid = shallow[0]
	var ch0: Character = shallow[1]
	ch0.step(g0, DT, 0.0, false, false)
	ch0.step(g0, DT, 0.0, true, true)
	t.ok(ch0.vy != expected,
		"물 %d(임계, 얕음)에서는 공중 점프가 안 먹는다 (vy=%.1f)" % [Tuning.WATER_WET, ch0.vy])

	var deep := _submerged(Tuning.WATER_WET + 1)
	var g1: CellGrid = deep[0]
	var ch1: Character = deep[1]
	ch1.step(g1, DT, 0.0, false, false)
	ch1.step(g1, DT, 0.0, true, true)
	t.eq(ch1.vy, expected,
		"물 %d(한 톨 더 깊다)에서는 공중 점프가 먹는다 (vy=%.1f)" % [Tuning.WATER_WET + 1, ch1.vy])


## **A-3 — leave the water and it is blocked that very frame.**
##
## **What goes red when inverted**: update `in_water` only in `on_tick()`, or cache it once — then the jump still
##  works on the frame right after the water is erased (judged on an answer up to `TICK_DIVIDER` (3) frames stale).
##  **This is where "is it read every frame" is captured as a value.** It only splits within a single frame, so
##  **the eye can never see it** — only the net catches it (per the plan).
func _leaving_water_blocks_the_very_next_frame(t) -> void:
	var made := _submerged(Tuning.WATER_MAX)
	var g: CellGrid = made[0]
	var ch: Character = made[1]

	ch.step(g, DT, 0.0, false, false)
	var expected := Character.JUMP_VY_PX + Character.PLAYER_GRAVITY_PX * DT
	ch.step(g, DT, 0.0, true, true)
	t.eq(ch.vy, expected, "물속에서 점프가 먹는다 (전제)")

	# Erase the water entirely — the box the character is in plus one row under the feet all disappear.
	_water_box(g, WATER_CX0, WATER_CX1, WATER_CY0, WATER_CY1, 0)
	t.ok(not ch.on_ground, "여전히 공중이다 (전제 — 바닥이 없어서 물이 없어도 안 선다)")

	# This is the very frame after the water vanished. Jump is pressed again but must not work now —
	#  so this frame's `vy` is the value with only gravity added, not one reset to `JUMP_VY_PX`.
	var vy_before := ch.vy
	ch.step(g, DT, 0.0, true, true)
	t.eq(ch.vy, vy_before + Character.PLAYER_GRAVITY_PX * DT,
		"물 밖으로 나온 바로 다음 프레임에 점프가 안 먹는다 (중력만 더해진 vy=%.1f)" % ch.vy)


## **A-4 — the range includes the one row under the feet.**
##
## **What goes red when inverted**: compute `standing_in_water`'s `cy1` without the `+1` (as `(x+h_px-1)`) and
##  the inside of the box is completely empty, so the jump does not work.
## **It is not written by comparing answers with `standing_in_fire`** — folding the two into one helper makes it
##  the tautology `scan == scan` (CLAUDE.md: "comparing catches divergence but not disappearance").
##  Instead **the cell layout is built directly and the absolute answer is asserted**: the inside of the box is
##  left EMPTY and deep water is placed only on the one row under the feet.
## **No confirmation step is taken — that is the core of this check.**
## `standing_in_water` is read at the **very start** of `step()` (before gravity moves the character).
## **At first a confirming `step()` was called once beforehand, and that was a fake net** — verify-read captured
##  by value that changing `+h_px` to `+h_px-1` in `body.gd` (deleting the foot row) still gave 38/38 green:
##  the confirmation step's gravity dropped the character 1px (`py=800->801`) so **the box's own bottom edge
##  overlapped the foot row (208)** — it passed because the water was already inside the box even without the foot row.
##  => **Make the `step()` that attempts the jump the first and only call** — then `in_water` is read exactly
##  where `place()` put it (with gravity not having moved it one grain).
func _submerged_jump_includes_the_foot_row(t) -> void:
	var g := CellGrid.new()
	var ch := Character.new()
	var px := 400 * Tuning.CELL_PX
	var py := 200 * Tuning.CELL_PX
	ch.place(px, py)

	var cx0 := floori(px / float(Tuning.CELL_PX))
	var cx1 := floori((px + Character.W_PX - 1) / float(Tuning.CELL_PX))
	var cy1 := floori((py + Character.H_PX) / float(Tuning.CELL_PX))
	# **That the box's last row (cy1-1) is empty is measured by value first** — unmeasured, it cannot be told
	#  apart from accidentally believing "only the foot row has water" while the water is in fact inside the box.
	t.eq(g.mat_at(cx0, cy1 - 1), Mat.EMPTY, "상자의 마지막 줄엔 물이 없다 (전제)")
	# The rows the box covers (cy0..cy1-1) stay EMPTY — deep water is placed only on the one foot row (cy1).
	for x in range(cx0, cx1 + 1):
		g.set_water(x, cy1, Tuning.WATER_MAX)

	var expected := Character.JUMP_VY_PX + Character.PLAYER_GRAVITY_PX * DT
	ch.step(g, DT, 0.0, true, true)
	t.ok(not ch.on_ground, "공중이다 (전제 — 바닥이 없다)")
	t.eq(ch.vy, expected,
		"발밑 한 줄에만 깊은 물이 있어도 점프가 먹는다 (vy=%.1f)" % ch.vy)


# ══════════════════════════════════════════════════════════════════
#  C. the water flow pushes the character (`water-jump-and-escape.md` stage 4)
# ══════════════════════════════════════════════════════════════════
#
# **C-1 to C-4 measure `Body.water_flow()` directly** — the spot the plan pinned down as "measure the force
#  function separately". **C-5 and C-6 measure as a pair whether that force actually reaches the movement in
#  `Character.step()`** (the force function separately · whether that force reaches the movement separately —
#  the spot in CLAUDE.md's "write them as a pair; using only the latter is a tautology").

## Stands up one `Body` and returns the coordinates — the same range `standing_in_water` · `water_flow` see
## (the box plus one row under the feet) is derived here to decide **where to place the water**.
## `[body, cx0, cx1, cy0, cy1]`.
func _water_push_body(px: int, py: int) -> Array:
	var body := Body.new(Character.W_PX, Character.H_PX, Character.STEP_CELLS)
	body.place(px, py)
	var cx0 := floori(px / float(Tuning.CELL_PX))
	var cx1 := floori((px + Character.W_PX - 1) / float(Tuning.CELL_PX))
	var cy0 := floori(py / float(Tuning.CELL_PX))
	var cy1 := floori((py + Character.H_PX) / float(Tuning.CELL_PX))
	return [body, cx0, cx1, cy0, cy1]


## **C-1 — with equal water on both sides the flow is 0.**
## **What goes red when inverted**: counting only one side or dropping the sign (e.g. returning `left` without
##  subtracting `right`) yields a non-zero value despite the symmetry.
func _water_push_zero_when_symmetric(t) -> void:
	var g := CellGrid.new()
	var made := _water_push_body(500 * Tuning.CELL_PX, 200 * Tuning.CELL_PX)
	var body: Body = made[0]
	var cx0: int = made[1]
	var cx1: int = made[2]
	var cy0: int = made[3]
	var cy1: int = made[4]
	for cy in range(cy0, cy1 + 1):
		t.ok(g.set_water(cx0 - 1, cy, Tuning.WATER_MAX), "왼쪽 기둥에 물을 놓는다 (전제)")
		t.ok(g.set_water(cx1 + 1, cy, Tuning.WATER_MAX), "오른쪽 기둥에도 같은 양을 놓는다 (전제)")
	t.eq(body.water_flow(g), 0, "좌우가 같으면 물살이 0이다")


## **C-2 — the sign. Water on the left only => positive (to the right), on the right only => negative. Both are measured.**
## **What goes red when inverted**: flip `diff` to `right - left` and both come out reversed.
##  **Measuring only one side lets a sign flip pass half the time** — which is why both are measured.
func _water_push_sign_both_ways(t) -> void:
	var g_left := CellGrid.new()
	var made_left := _water_push_body(500 * Tuning.CELL_PX, 200 * Tuning.CELL_PX)
	var body_left: Body = made_left[0]
	for cy in range(made_left[3], made_left[4] + 1):
		g_left.set_water(made_left[1] - 1, cy, Tuning.WATER_MAX)
	var push_left := body_left.water_flow(g_left)
	t.ok(push_left > 0, "왼쪽에만 물 — 오른쪽으로 민다 (양수, %d)" % push_left)

	var g_right := CellGrid.new()
	var made_right := _water_push_body(500 * Tuning.CELL_PX, 200 * Tuning.CELL_PX)
	var body_right: Body = made_right[0]
	for cy in range(made_right[3], made_right[4] + 1):
		g_right.set_water(made_right[2] + 1, cy, Tuning.WATER_MAX)
	var push_right := body_right.water_flow(g_right)
	t.ok(push_right < 0, "오른쪽에만 물 — 왼쪽으로 민다 (음수, %d)" % push_right)


## **C-3 — the strength is proportional to the difference. Increase the difference and the force strictly grows.**
## **What goes red when inverted**: returning a constant ("a plausible value without computing") makes all three values equal.
## **Exact proportionality is not pinned down** — the `WATER_MIN_DIFF` threshold shaves low differences so it is
##  not exactly linear (the plan warned so). Only **whether it strictly grows** is measured.
func _water_push_scales_with_diff(t) -> void:
	var amounts := [80, 160, Tuning.WATER_MAX]
	var pushes: Array[int] = []
	for amount in amounts:
		var g := CellGrid.new()
		var made := _water_push_body(500 * Tuning.CELL_PX, 200 * Tuning.CELL_PX)
		var body: Body = made[0]
		for cy in range(made[3], made[4] + 1):
			g.set_water(made[1] - 1, cy, amount)
		pushes.append(body.water_flow(g))
	t.ok(pushes[0] < pushes[1] and pushes[1] < pushes[2],
		"차이가 늘수록 힘이 엄격히 커진다 (%d < %d < %d)" % [pushes[0], pushes[1], pushes[2]])


## **C-4 — in still water (equilibrium) it is 0.**
##
## **The first version was a tautology** (verify-read) — the pool settled **below** the character's feet so there
##  was not one cell of water inside the scan range (box + foot row). Erasing the threshold to 0 still gave 0
##  "because there was no water to look at", and it was 69/69 green — **the threshold was not what held it.**
##  => **It is rewritten with a pool the character is actually submerged in** (the width-12 scene verify-read confirmed).
##
## **What goes red when inverted**: remove the `WATER_MIN_DIFF` threshold (set it to 0) and rounding residuals
##  keep producing non-zero values even after settling.
## **The pool is dug narrow, 12 cells wide** — a wide pool runs into what `docs/design/water.md` records as
##  "a resting surface is not uniform" (distant cells can disagree). verify-read's measurement
##  (width 12 -> settles in 69 ticks, residual |left-right| 23, threshold 36) already established that at this
##  width it stays within the threshold.
## **It is poured into the left half only** — to measure "it flowed until it became 0" rather than "it was
##  symmetric from the start so it is 0", the start must be asymmetric.
## **The margin is not large** (residual 23 vs threshold 36 — 1.6x). At this width and this layout it passes, but
##  a layout where the character box straddles the surface and is only half submerged could exceed it —
##  **that was not measured.**
func _water_push_zero_at_equilibrium(t) -> void:
	var g := CellGrid.new()
	var pool_w := 12
	var bx0 := 500                     # the first cell inside the pool's left wall
	var cx0 := bx0 + 3                 # the character is put inside the pool (with clearance on both sides)
	var cy1 := 300                     # the pool floor = the foot row of the character box
	var cy0 := cy1 - (Character.H_PX / Tuning.CELL_PX)  # the box's top row
	# **The depth is half the point.** At first it was poured 30 rows deep, and then the pool became far thicker
	#  than the box height so **both neighbouring columns were completely full at 255 within the box range (8 rows)** —
	#  the real residual (which only remains on the top row of the surface, `water.md`'s "a resting surface is not
	#  uniform") was **above** the box range and invisible. Back then, erasing the threshold to 0 **still gave 0**
	#  (measured; verify-read pointed at the same spot by another route) — inside the box range left and right
	#  were already exactly equal, so the threshold had nothing to do.
	#  => **Pour shallow, matched to the box height (8 rows), so the surface lands inside the box range.**
	var cy_pour_top := cy1 - 16

	var made := _water_push_body(cx0 * Tuning.CELL_PX, cy0 * Tuning.CELL_PX)
	var body: Body = made[0]

	# Two walls plus a floor — the character's two neighbouring columns (cx0-1 · cx1+1) are both inside this pool.
	g.apply(CellGrid.cmd_fill(bx0 - 1, cy_pour_top, bx0 - 1, cy1, Mat.STONE))
	g.apply(CellGrid.cmd_fill(bx0 + pool_w, cy_pour_top, bx0 + pool_w, cy1, Mat.STONE))
	g.apply(CellGrid.cmd_fill(bx0 - 1, cy1, bx0 + pool_w, cy1, Mat.STONE))
	# Poured into the left half only, down to the floor — even after spreading over 12 cells it amply covers the box height (8 cells).
	for cx in range(bx0, bx0 + pool_w / 2):
		for cy in range(cy_pour_top + 1, cy1):
			g.set_water(cx, cy, Tuning.WATER_MAX)

	g.step()
	var settle := 1
	while g.active_chunk_count() > 0 and settle < 2000:
		g.step()
		settle += 1
	t.ok(settle > 1 and settle < 2000, "웅덩이가 상한 안에 평형에 든다 (%d틱 — 루프가 헛돌지 않았다)"
		% settle)
	t.eq(g.active_chunk_count(), 0, "정말 평형이다 (전제)")

	# **Whether the character is actually submerged is measured first** — without it, as before, "0 because
	#  there is no water to look at" and "0 because it is in equilibrium" cannot be told apart.
	t.eq(g.mat_at(cx0, cy0), Mat.WATER, "캐릭터 상자 맨 위 줄이 실제로 물에 잠겼다 (전제)")
	t.eq(g.mat_at(cx0, cy1 - 1), Mat.WATER, "캐릭터 상자 맨 아래 줄도 잠겼다 (전제)")
	t.eq(body.water_flow(g), 0, "실제로 잠긴 채로도 평형에 든 웅덩이에서는 물살이 0이다")


## **C-5 — the paired check. Whether the force actually reaches the movement, and confirming the control (when it does not).**
## **What goes red when inverted**: not adding `water_push` into the sum for `move_x` leaves (1) unmoved and red.
## **(2) alone is a tautology** — of course it does not move when there is no water. **(1) is what makes**
##  "that water flow actually reached the movement" stand as a value.
func _water_push_pair_moves_and_stops(t) -> void:
	var px := 500 * Tuning.CELL_PX
	var cx0 := floori(px / float(Tuning.CELL_PX))
	var cy0 := floori(REST_Y / float(Tuning.CELL_PX))
	var cy1 := floori((REST_Y + Character.H_PX) / float(Tuning.CELL_PX))

	# (1) Water on the left only — input 0 · on the ground. Pushed, it goes right (+x).
	var g_water := _floor_grid()
	var ch_water := Character.new()
	ch_water.place(px, REST_Y)
	for cy in range(cy0, cy1 + 1):
		g_water.set_water(cx0 - 1, cy, Tuning.WATER_MAX)
	for _i in 30:
		ch_water.step(g_water, DT, 0.0, false, false)
	t.ok(ch_water.x > px, "① 왼쪽에만 물이 있으면(입력 0·땅 위) x가 오른쪽으로 움직인다 (%d → %d)"
		% [px, ch_water.x])

	# (2) The same layout with only the water removed — the pair of (1).
	var g_dry := _floor_grid()
	var ch_dry := Character.new()
	ch_dry.place(px, REST_Y)
	for _i in 30:
		ch_dry.step(g_dry, DT, 0.0, false, false)
	t.eq(ch_dry.x, px, "② 같은 배치에서 물만 지우면 안 움직인다 (①과 짝이다)")


## **C-6 — the character does not push the water. It holds the folder contract by value**
##  (`src/actor/` float -> `src/sim/` integer determinism, read-only).
## **What goes red when inverted**: writing to the grid by mistake (e.g. erasing the water where it passed) is red.
func _water_push_does_not_move_water(t) -> void:
	var px := 500 * Tuning.CELL_PX
	var g := _floor_grid()
	var ch := Character.new()
	ch.place(px, REST_Y)
	var cx0 := floori(px / float(Tuning.CELL_PX))
	var cy0 := floori(REST_Y / float(Tuning.CELL_PX))
	var cy1 := floori((REST_Y + Character.H_PX) / float(Tuning.CELL_PX))
	for cy in range(cy0, cy1 + 1):
		g.set_water(cx0 - 1, cy, Tuning.WATER_MAX)
	var before := g.count_material(Mat.WATER)
	t.ok(before > 0, "물이 실제로 놓였다 (전제)")

	for _i in 30:
		ch.step(g, DT, 0.0, false, false)

	t.eq(g.count_material(Mat.WATER), before, "캐릭터가 여러 프레임 움직여도 물 칸 수가 그대로다")
	var total := 0
	for cy in range(cy0 - 5, cy1 + 6):
		for cx in range(cx0 - 10, cx0 + 20):
			if g.mat_at(cx, cy) == Mat.WATER:
				total += g.aux_at(cx, cy)
	t.eq(total, before * Tuning.WATER_MAX, "물의 총량도 그대로다 (캐릭터가 시뮬을 안 건드린다)")


## **C-7 — fire next to it does not contaminate the water flow.**
##
## **verify-read confirmed this by value without the guard**: filling the left column with wood and setting it
##  alight gives an `_aux` (remaining fuel) sum of 590 — added up without the `mat_at()==WATER` check,
##  `diff = 590` (an average of ~65 over 9 rows) exceeds the threshold (36) and **fire pushes the character like water.**
##  **What goes red when inverted**: delete (or bypass) the two `mat_at(...) == Mat.WATER` lines in `water_flow`
##  in `body.gd` and this check sees a non-zero value and goes red.
func _water_push_ignores_fire(t) -> void:
	var g := CellGrid.new()
	var made := _water_push_body(500 * Tuning.CELL_PX, 200 * Tuning.CELL_PX)
	var body: Body = made[0]
	var cx0: int = made[1]
	var cy0: int = made[3]
	var cy1: int = made[4]
	# Fill the left column with wood and set it alight — the right side stays empty.
	for cy in range(cy0, cy1 + 1):
		g.apply(CellGrid.cmd_fill(cx0 - 1, cy, cx0 - 1, cy, Mat.WOOD))
	for cy in range(cy0, cy1 + 1):
		g.ignite(cx0 - 1, cy)
	t.ok(g.burning_count() > 0, "나무가 실제로 탄다 (전제)")

	var fuel_sum := 0
	for cy in range(cy0, cy1 + 1):
		fuel_sum += g.aux_at(cx0 - 1, cy)
	t.ok(fuel_sum > 0, "타는 기둥에 남은 연료(`_aux`)가 실제로 있다 (전제, 합 %d)" % fuel_sum)

	t.eq(body.water_flow(g), 0, "물이 아닌(타는) 이웃은 물살에 안 섞인다 — 0이다")


## **C-8 — leave the water and it stops that frame.** The same spot as the jump's A-3 (a pair).
##
## **The code was right but it was not caught because this check did not exist** (verify-read): turning
##  `water_push` into a member like `recoil_vx` that decays and lingers after the water is gone gave **69/69 green** —
##  because there was not one check measuring "leave the water and it stops".
## **What goes red when inverted**: make `water_push` an accumulating member rather than a local variable and,
##  on the frame after the water is erased, it keeps being pushed (while decaying) so `x2 != x1`.
## **It is pushed for one frame only** — pushed over several frames the character leaves its original column
##  (1 cell = 4px) and "outside the water" gets mixed with "the flow left the cell boundary". What is measured
##  here is **erasing the water itself.**
func _water_push_stops_the_frame_water_leaves(t) -> void:
	var px := 500 * Tuning.CELL_PX
	var cx0 := floori(px / float(Tuning.CELL_PX))
	var cy0 := floori(REST_Y / float(Tuning.CELL_PX))
	var cy1 := floori((REST_Y + Character.H_PX) / float(Tuning.CELL_PX))

	var g := _floor_grid()
	var ch := Character.new()
	ch.place(px, REST_Y)
	for cy in range(cy0, cy1 + 1):
		g.set_water(cx0 - 1, cy, Tuning.WATER_MAX)

	# Pushed for one frame only — it is still beside the same column (moved less than 4px, no cell boundary crossed).
	ch.step(g, DT, 0.0, false, false)
	var x1 := ch.x
	t.ok(x1 > px, "한 프레임 만에 물살로 밀렸다 (전제, %d → %d)" % [px, x1])

	# Erase the water — the same column (cx0-1). That the character has not moved over yet is the premise above.
	for cy in range(cy0, cy1 + 1):
		g.set_water(cx0 - 1, cy, 0)
	ch.step(g, DT, 0.0, false, false)
	var x2 := ch.x
	t.eq(x2, x1, "물이 사라진 바로 다음 프레임에 더 안 밀린다 (감쇠하며 남지 않는다)")
