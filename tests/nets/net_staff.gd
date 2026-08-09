extends RefCounted
## The staff tip — `staff-and-fire-origin.md`.
##
## **This net exists because of one placement decision.** Had the function that computes the tip lived in
##  `src/view/`, a scene would be needed and headless has no pixels => "where does it carve when you fire
##  hugging a wall" would stay **in the eye only.** Moving it to `src/actor/staff.gd` made it a **value.**
##
## **The control is half of this net.** Measuring only "the tip cell is empty" stays **green even with the
##  character standing far from the wall**, and then it passes without anyone knowing the placement is the gate.
##  => In the same arrangement, it also measures that **the unclamped value** (`pivot + dir x LEN_PX`) is
##  **actually a solid cell.**
##  (The same idiom as the control in `net_damage._run_gauntlet`.)
##
## **What this net cannot measure in principle — do not widen the label this far:**
##  · **Is the sprite tip the same as the firing spot** — the structure guarantees the code calls the same
##    function, but **the drawn pixels are the eye's**
##  · **The `draw_set_transform` restore** — measured at `character_view.gd:131`: deleting it left everything green
##  · **Does it read as the staff leaving the hand · are up and down awkward** — the eye's

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const Character := preload("res://src/actor/character.gd")
const Staff := preload("res://src/actor/staff.gd")
## Net 7b builds a circle and takes it back out — the assembly window's own path.
const SpellCircle := preload("res://src/actor/spell_circle.gd")
const CircleDefs := preload("res://src/sim/circle_defs.gd")
## Nets are **outside** the folder contract — they may look at `src/view/` (`net_layers.RULES` only sweeps `src/`).
##  The ring color (`staff_tint`) is a presentation constant so it lives there, and there is one check for it below.
const Fx := preload("res://src/view/fx_tuning.gd")

## The box is stood up **flush with the cells.** Otherwise "which cells the box covers" gets counted by hand,
##  and nobody barks when that count is wrong. The first assertion below confirms it is flush.
const BOX_CX := 80
const BOX_CY := 192
const BOX_X := BOX_CX * Tuning.CELL_PX
const BOX_Y := BOX_CY * Tuning.CELL_PX

## The stone pillar of the wall world (cells). **It has to be thick** — one cell and the unclamped value
##  (36px ahead) goes **past** the pillar and lands in an empty cell, and then the control cannot assert
##  "it is solid" and half this net dies.
const WALL_CX0 := 88
const WALL_CX1 := 95

## The eight directions. **Written as integers and normalized here** — an axis-parallel direction's component
##  must be **exactly 0** for the "this axis is not confined" branch of `_axis_exit` to actually be taken.
##  Built with `rotated()` it leaves 4e-8 behind.
const DIR_STEPS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]


func run(t) -> void:
	_box_sits_on_cell_edges(t)
	_pivot_stays_inside_the_box(t)
	_tip_is_never_inside_terrain(t)
	_tip_reaches_full_length_in_the_open(t)
	_tip_is_clamped_in_the_middle_by_a_wall(t)
	_staff_tint_carries_the_loadout(t)
	_staff_tint_uses_its_own_sockets_combo_not_a_splice(t)


## The premise of every arrangement below. The day `W_PX` · `H_PX` stop being multiples of the cell, this goes red first.
func _box_sits_on_cell_edges(t) -> void:
	t.eq(Character.W_PX % Tuning.CELL_PX, 0,
		"상자 폭 %d 가 셀 %d 의 배수다 (배치의 전제)" % [Character.W_PX, Tuning.CELL_PX])
	t.eq(Character.H_PX % Tuning.CELL_PX, 0,
		"상자 높이 %d 가 셀 %d 의 배수다 (배치의 전제)" % [Character.H_PX, Tuning.CELL_PX])
	t.eq(DIR_STEPS.size(), 8, "훑는 방향이 여덟이다")


## Net 6 — the pivot must be **inside** the box. Past it, the safety grounds for the lower bound
##  ("there is no terrain inside the box") die, and then a tip shortened to the lower bound sits **inside the wall.**
## A **range**, not a value, is measured — it is a feel value the eye will change (design "open questions").
func _pivot_stays_inside_the_box(t) -> void:
	t.ok(Staff.PIVOT_DY_PX >= 0.0 and Staff.PIVOT_DY_PX < Character.H_PX * 0.5,
		"손 높이 %.1f 가 상자 안이다 (0 ≤ dy < %d)" % [Staff.PIVOT_DY_PX, Character.H_PX / 2])
	var p := Staff.pivot_px(BOX_X, BOX_Y)
	t.ok(p.x >= float(BOX_X) and p.x <= float(BOX_X + Character.W_PX - 1)
			and p.y >= float(BOX_Y) and p.y <= float(BOX_Y + Character.H_PX - 1),
		"피벗 %s 가 상자[%d,%d]~[%d,%d] 안이다" % [
			p, BOX_X, BOX_Y, BOX_X + Character.W_PX - 1, BOX_Y + Character.H_PX - 1])


## Nets 1 · 2 — **eight directions in a world walled on all sides.**
##
## **If the lower bound were "the surface", this goes red.** The range `_box_free` protects is
##  `[px, px+W-1] x [py, py+H-1]`, so the surface (`box + size`) is **already the next cell** —
##  written as the surface, the tip sits inside the floor cell when looking down (risk 1).
## **The control**: in the same arrangement the unclamped values are all solid cells => "the placement is the gate".
func _tip_is_never_inside_terrain(t) -> void:
	var g := _boxed_world()
	t.ok(_box_is_free(g), "상자가 덮는 셀이 전부 빈칸이다 (배치의 전제)")
	t.ok(g.is_solid(BOX_CX - 1, BOX_CY), "상자 왼쪽 셀은 고체다 (사방이 막혔다)")
	t.ok(g.is_solid(BOX_CX, BOX_CY + Character.H_PX / Tuning.CELL_PX),
		"상자 아래 셀은 고체다 (바닥이다)")

	for step: Vector2i in DIR_STEPS:
		var dir := Vector2(step).normalized()
		var tip := Staff.tip_px(g, BOX_X, BOX_Y, dir)
		t.ok(not _solid_at(g, tip), "%s 로 조준하면 끝(%s)이 빈 셀이다" % [step, tip])
		# The control — where would it have been without the clamp.
		var raw := Staff.pivot_px(BOX_X, BOX_Y) + dir * Staff.LEN_PX
		t.ok(_solid_at(g, raw),
			"%s: 클램프 없는 값(%s)은 실제로 고체 셀이다 (배치가 관문이다)" % [step, raw])
		_tip_points_along_aim(t, dir, tip, step)


## Net 3 — with nothing blocking it, the length is exactly `LEN_PX`. **If the clamp always bites**, the staff
##  stays short forever, and that looks like "I guess it is just that length" — nearly impossible to catch by eye.
func _tip_reaches_full_length_in_the_open(t) -> void:
	var g := CellGrid.new()
	for step: Vector2i in DIR_STEPS:
		var dir := Vector2(step).normalized()
		var tip := Staff.tip_px(g, BOX_X, BOX_Y, dir)
		var len_px := (tip - Staff.pivot_px(BOX_X, BOX_Y)).length()
		t.ok(is_equal_approx(len_px, Staff.LEN_PX),
			"%s: 빈 하늘에서는 길이가 정확히 %.1f 다 (%.3f)" % [step, Staff.LEN_PX, len_px])
		_tip_points_along_aim(t, dir, tip, step)


## Nets 1 · 2 · 4 — **is it cut in the middle, neither at the lower nor the upper bound.** With only the two
##  checks above, writing it as "always the lower bound" or "always the upper bound" leaves one of them green each.
func _tip_is_clamped_in_the_middle_by_a_wall(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(WALL_CX0, 0, WALL_CX1, CellGrid.H - 1, Mat.STONE))
	t.ok(_box_is_free(g), "상자가 덮는 셀이 전부 빈칸이다 (배치의 전제)")

	var pivot := Staff.pivot_px(BOX_X, BOX_Y)
	var dir := Vector2.RIGHT
	var tip := Staff.tip_px(g, BOX_X, BOX_Y, dir)
	var len_px := (tip - pivot).length()
	t.ok(not _solid_at(g, tip), "벽 앞에서 끝(%s)이 빈 셀이다" % tip)
	t.ok(_solid_at(g, pivot + dir * Staff.LEN_PX),
		"클램프 없는 값(%s)은 벽 **안**이다 (배치가 관문이다)" % (pivot + dir * Staff.LEN_PX))
	# **It is in the middle.** Longer than the lower bound (the box's last inner pixel) and shorter than
	#  `LEN_PX` => on screen this is where "the staff gets pressed short as you approach a wall" happens
	#  (acceptance 2 — the seeing is the eye's).
	var floor_len := float(BOX_X + Character.W_PX - 1) - pivot.x
	t.ok(len_px > floor_len and len_px < Staff.LEN_PX,
		"길이 %.1f 가 하한(%.1f)과 전장(%.1f) **사이**다" % [len_px, floor_len, Staff.LEN_PX])
	_tip_points_along_aim(t, dir, tip, Vector2i(1, 0))


## Net 4 — the tip is always **on the aim direction** and never exceeds the full length.
## Without this, "the tip is an empty cell" could be passed by an implementation that **just returns the pivot.**
func _tip_points_along_aim(t, dir: Vector2, tip: Vector2, step: Vector2i) -> void:
	var v := tip - Staff.pivot_px(BOX_X, BOX_Y)
	t.ok(v.length() > 0.0 and v.normalized().dot(dir) > 0.9999,
		"%s: 끝이 조준 방향 위에 있다 (%s)" % [step, v])
	t.ok(v.length() <= Staff.LEN_PX + 0.001,
		"%s: 끝이 전장을 안 넘는다 (%.3f ≤ %.1f)" % [step, v.length(), Staff.LEN_PX])


## Net 7 — **the ring color at the tip carries the loadout.** With the muzzle bead gone, **the one remaining
##  axis is color**, so this function not diverging is the whole of "change the combination and the screen changes".
##  **What is measured is only "the colors differ".** Whether that color is actually painted on the ring on
##  screen is the eye's.
func _staff_tint_carries_the_loadout(t) -> void:
	var elem := Tuning.ELEM_FIRE
	var spread := Glyph.pack([Glyph.GLYPH_SPREAD])
	var blast := Glyph.pack([Glyph.GLYPH_BLAST])
	var c_spread := Fx.staff_tint(spread, elem, true)
	var c_blast := Fx.staff_tint(blast, elem, true)
	var c_none := Fx.staff_tint(Glyph.GLYPH_NONE, elem, true)
	t.ok(c_spread != c_blast, "문양이 다르면 색이 다르다 (확산 %s ≠ 폭발 %s)" % [c_spread, c_blast])
	t.ok(c_none != c_spread and c_none != c_blast,
		"문양이 비면 룬 색으로 떨어진다 (%s)" % c_none)

	# **Key 4 (spread->blast) and key 5 (blast->spread)** — the layer counts are equal, so **only color carries
	#  the order.** This is the spot where the GDD wrote "if the order is not visible on screen the player can
	#  never learn the rule".
	var k4 := Glyph.pack([Glyph.GLYPH_SPREAD, Glyph.GLYPH_BLAST])
	var k5 := Glyph.pack([Glyph.GLYPH_BLAST, Glyph.GLYPH_SPREAD])
	t.ok(k4 != k5, "키 4와 키 5가 서로 다른 목록이다 (검사의 전제)")
	t.ok(Fx.staff_tint(k4, elem, true) != Fx.staff_tint(k5, elem, true),
		"순서를 바꾸면 색이 바뀐다 (키 4 %s ≠ 키 5 %s)" % [
			Fx.staff_tint(k4, elem, true), Fx.staff_tint(k5, elem, true)])

	# **When you cannot fire, it dies grey.** The **same grey** as the empty rune slot in the assembly window,
	#  so the two screens say the same thing.
	#  It has nothing to do with the list — this color means "you cannot fire right now", not "the combination
	#  is intact and only the rune is missing".
	for g: int in [Glyph.GLYPH_NONE, spread, blast, k4]:
		t.eq(Fx.staff_tint(g, elem, false), Fx.DEAD_TINT,
			"못 쏘면 목록(%d)과 무관하게 회색으로 죽는다" % g)
	# The inversion — it blocks the path where writing it as "always grey" would pass the lines above.
	t.ok(Fx.staff_tint(k4, elem, true) != Fx.DEAD_TINT, "쏠 수 있으면 회색이 아니다")

	_ring_tint_never_barks_with_the_circle_removed(t)


## Net 7b — **the ring colour survives the circle being taken out.**
##
## **The bark this net was written for**: `element()` used to bark whenever `_runes.size() != 1`, and the
##  assembly window can write `CIRCLE_NONE`, which takes the slots to 0. The view asked it unconditionally
##  ⇒ **539 barks in one play session while every net stayed green** — the call lived in `_draw`, which
##  nothing can invoke. **That bark is gone now, not just guarded** (`triangle-circle-to-game.md` step 5) —
##  `element()` no longer barks on any rune count, it only ever returns a representative rune. So inverting
##  by restoring the unconditional call **no longer reaches stderr either way**; what this net still measures
##  and still catches a real regression on is `fx_tuning.staff_tint`'s own `can_fire` guard reading the right
##  colour in both states, which is unrelated to whether `element()` itself can bark.
## **So the assertions below are about the colour** — that half of the original reasoning still holds.
func _ring_tint_never_barks_with_the_circle_removed(t) -> void:
	var circle := SpellCircle.new()
	t.ok(circle.can_fire(), "갓 만든 서클은 쏠 수 있다 (전제 — 기본 지급이 채워져 있다)")

	# The assembly window's own path (`circle_window.gd` writes this value), not a state invented here.
	circle.set_circle(CircleDefs.CIRCLE_NONE)
	t.eq(circle.rune_count(), 0, "서클을 빼면 룬 자리가 0이 된다 (전제)")
	t.ok(not circle.can_fire(), "서클이 없으면 못 쏜다 (전제)")
	t.eq(Fx.staff_ring_tint(circle), Fx.DEAD_TINT, "서클을 빼도 지팡이 고리는 회색으로 죽는다")

	# **And it still carries the loadout when there is one** — otherwise "always grey" passes the line above.
	circle.set_circle(SpellCircle.DEFAULT_CIRCLE)
	circle.set_rune(0, SpellCircle.DEFAULT_RUNE)
	t.ok(Fx.staff_ring_tint(circle) != Fx.DEAD_TINT, "서클을 되돌리면 다시 색이 산다")


## **`staff_ring_tint` used to pair `element()` (socket 0's rune) with `packed_glyphs()` (the whole
## circle's glyph list, densely packed from whichever socket has one first) — a real bug (verify-read):
## on a triangle circle those can name two different sockets, so the tip showed the colour of a spell no
## bolt actually fires. Socket 0 carries fire with **no** glyph; socket 1 carries water **with** blast.
## The old pairing would show blast's colour (`packed_glyphs()` sees only socket 1's blast, `element()`
## sees only socket 0's fire) — a fire+blast combination `shots()` never assembles (bolt 0 leaves fire
## alone, bolt 1 leaves water+blast). The fix reads `shots()[0]` — socket 0's own, real combination.
func _staff_tint_uses_its_own_sockets_combo_not_a_splice(t) -> void:
	var circle := SpellCircle.new(CircleDefs.CIRCLE_TRIANGLE)
	t.ok(circle.set_rune(0, Tuning.ELEM_FIRE), "0번 소켓에 불을 놓는다 (전제)")
	t.ok(circle.set_rune(1, Tuning.ELEM_WATER), "1번 소켓에 물을 놓는다 (전제)")
	t.ok(circle.place_glyph(1, Glyph.GLYPH_BLAST), "1번 소켓에만 폭발을 놓는다 (전제 — 0번은 문양이 없다)")
	t.ok(circle.can_fire(), "삼각 진이 쏠 수 있다 (전제)")

	var shots := circle.shots()
	var want: Color = Fx.staff_tint(int(shots[0]["glyphs"]), int(shots[0]["element"]), true)
	t.eq(Fx.staff_ring_tint(circle), want, "지팡이 끝 색이 0번 소켓 자신의 조합(불 · 문양 없음)과 같다")

	# **The inversion — the exact splice the old code produced.** `GLYPH_TINT[BLAST]` is what
	# `staff_tint(packed_glyphs(), element(), true)` would have returned (glyphs != NONE, so the glyph
	# colour wins regardless of which socket the rune came from) — socket 1's colour leaking onto socket
	# 0's rune.
	t.ok(Fx.staff_ring_tint(circle) != Fx.GLYPH_TINT[Glyph.GLYPH_BLAST],
		"지팡이 끝이 다른 소켓(1번)의 문양 색으로 새지 않는다")

	# The round circle path must stay byte-identical — `shots()[0]` **is** `{element(), packed_glyphs()}`
	# there, so this is the same value the pre-fix code always computed for it.
	var round_c := SpellCircle.new()
	t.ok(round_c.place_glyph(0, Glyph.GLYPH_SPREAD), "동그라미 진 1층에 확산을 놓는다 (전제)")
	t.eq(Fx.staff_ring_tint(round_c),
		Fx.staff_tint(round_c.packed_glyphs(), round_c.element(), true),
		"동그라미 진은 element()·packed_glyphs() 조합과 여전히 같다 (안 바뀌었다)")


# -- building the world --------------------------------------------

## **A world walled on all sides — only the box cells are empty.** The one arrangement where the lower bound actually bites.
func _boxed_world() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, CellGrid.W - 1, CellGrid.H - 1, Mat.STONE))
	g.apply(CellGrid.cmd_fill(
		BOX_CX, BOX_CY,
		BOX_CX + Character.W_PX / Tuning.CELL_PX - 1,
		BOX_CY + Character.H_PX / Tuning.CELL_PX - 1, Mat.EMPTY))
	return g


## Looks at **the same range** as `character._box_free` — that range is the safety grounds for the lower bound,
## so setting a different range here would make the net measure something other than the game.
func _box_is_free(g: CellGrid) -> bool:
	for cy in range(BOX_CY, BOX_CY + Character.H_PX / Tuning.CELL_PX):
		for cx in range(BOX_CX, BOX_CX + Character.W_PX / Tuning.CELL_PX):
			if g.is_solid(cx, cy):
				return false
	return true


func _solid_at(g: CellGrid, p: Vector2) -> bool:
	return g.is_solid(
		floori(p.x / float(Tuning.CELL_PX)), floori(p.y / float(Tuning.CELL_PX)))
