extends RefCounted
## Self-consistency of the tables and constants. It does not run the sim for a single tick.
##
## A cheap net is not a low-value net. What is caught here is all of the
## "quietly diverges with no error" kind.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const CircleDefs := preload("res://src/sim/circle_defs.gd")
const Stage := preload("res://src/stage/stage.gd")
const CellRenderer := preload("res://src/view/cell_renderer.gd")
const Fx := preload("res://src/view/fx_tuning.gd")
## Measuring whether the camera shows "my surroundings" needs **how big I am**.
const Character := preload("res://src/actor/character.gd")
const Palette := preload("res://tools/stage/terrain_palette.gd")
const Baker := preload("res://tools/stage/terrain_baker.gd")


## 4-neighbourhood. Fire and ignition are both 4-neighbour, so connected components must be counted with the same neighbourhood.
const NB_DX: Array[int] = [1, -1, 0, 0]
const NB_DY: Array[int] = [0, 0, 1, -1]


## Color -> 0xRRGGBB. The **inverse** of `bake_palette` — reusing the same formula makes the check test itself.
static func _to_rgb(c: Color) -> int:
	return (c.r8 << 16) | (c.g8 << 8) | c.b8


func run(t) -> void:
	_grid_constants(t)
	_materials(t)
	_glyphs(t)
	_defs_and_all_agree(t)
	_view_follows_the_rune_axis(t)
	_gen_tables(t)
	_stage_map(t)
	_wood_clumps(t)
	_terrain_brush_follows_the_material_table(t)


## **Put it in `DEFS` and not in `ALL` and it drops out of iteration.**
##  It does not appear in the palette · it is not caught by the nets' `ALL` iteration · **and no error is raised at all.**
##  The reverse (in `ALL` but not in `DEFS`) kills whatever reads the table.
##
## This repo holds "iterate only over an explicit list" in three places — the **price** of that discipline is
##  exactly this hole. **Measuring the count alone cannot catch it** (remove one and add one and the size matches) —
##  => **compare as sets.** This is not a "check that only looks at whether it is called": it **splits behavior directly.**
##
## Growing the table grows this automatically — it works today even with only one kind of circle.
func _defs_and_all_agree(t) -> void:
	# [name, DEFS, ALL]
	var pairs: Array[Array] = [
		["glyph_defs", Glyph.DEFS, Glyph.ALL],
		["circle_defs", CircleDefs.DEFS, CircleDefs.ALL],
		["sim_tuning(룬)", Tuning.ELEM_DEFS, Tuning.ELEM_ALL],
	]
	# If the list is empty the code below never runs and **it goes green.**
	t.ok(pairs.size() > 0, "표와 목록 짝이 %d개다" % pairs.size())
	for p: Array in pairs:
		var nm: String = p[0]
		var defs: Dictionary = p[1]
		var all: Array = p[2]
		t.ok(all.size() > 0, "%s 의 ALL이 비어 있지 않다 (%d개)" % [nm, all.size()])
		# **It is a set comparison.** Sorting and comparing gives false positives on ordering, and measuring
		#  the size alone cannot catch it.
		for id: int in all:
			t.ok(defs.has(id), "%s: ALL의 %d가 DEFS에 있다" % [nm, id])
		for id: int in defs.keys():
			t.ok(all.has(id), "%s: DEFS의 %d가 ALL에 있다 (순회에서 안 빠진다)" % [nm, id])


## **If the sim axis (`ELEM_ALL`) grows and the screen axis (`ELEM_FX`) does not follow, every net stays green.**
##  Measured (the day the none rune went in): putting the rune in `ELEM_ALL` and **leaving only the color out of
##   `ELEM_FX` gave 1127 passes with clean stderr.** Nobody barks.
##
## This is what CLAUDE.md records as **this repo's representative fake** — "the screen changes and the sim does
##  not (or the reverse)" — and it is **how v1 died**: power doubled while the screen did not follow, so nobody
##  felt the increase.
##  In `sim_tuning`'s **generation table** that pairing (the length of `FX_SIZES`) exists in `_gen_tables` below,
##   but **it did not exist for the rune axis.** This function is that empty spot.
##
## **It does not replace `ELEM_FX_MISSING` (the magenta scream).** That is the screen side's last line of defense
##  and needs **a person to look**; this is automatic. Both are needed.
func _view_follows_the_rune_axis(t) -> void:
	# If the list is empty the code below never runs and it goes green.
	t.ok(Tuning.ELEM_ALL.size() > 0, "룬이 하나라도 있다 (%d개)" % Tuning.ELEM_ALL.size())
	for element: int in Tuning.ELEM_ALL:
		# **Do not dig in by index (`ELEM_FX[element]`)** — if it is missing, the assertion does not go red,
		#  the function aborts and **the check vanishes entirely.** Receive it as a `Variant` and measure the type first.
		var fx: Variant = Fx.ELEM_FX.get(element, null)
		t.ok(fx is Dictionary, "룬 %d의 색이 ELEM_FX에 있다" % element)
		if not (fx is Dictionary):
			continue
		for key: String in ["core", "glow"]:
			t.ok((fx as Dictionary).get(key, null) is Color,
				"룬 %d의 ELEM_FX에 `%s` 색이 있다" % [element, key])
		# **Is it in the table** and **does the consumer receive it** are different questions — it is looked at
		#  once more through the accessor the consumer goes through.
		var got: Variant = Fx.elem_fx(element).get("glow", null)
		t.ok(got is Color and got != Fx.ELEM_FX_MISSING.get("glow", null),
			"룬 %d이 접근자에서 비명 색으로 안 떨어진다" % element)

	# The other side. A rune that exists only on screen and not in the sim is **a color nobody can fire** — a false handle.
	for element: int in Fx.ELEM_FX.keys():
		t.ok(Tuning.ELEM_ALL.has(element),
			"ELEM_FX의 룬 %d이 ELEM_ALL에 있다 (아무도 못 쏘는 색이 아니다)" % element)


## **If the wood is one lump, wherever the fire is lit it all burns in the end.**
## Measured: the final wood for key 1 (no glyph) · key 4 · key 5 all converged to 48 —
## the "after it settles" axis stops distinguishing combinations. Broken up, how many lumps burn varies per combination.
##
## **The terrain that actually runs is stood up.** Re-reading the map string here would go stale with the terrain.
func _wood_clumps(t) -> void:
	var g := CellGrid.new()
	Stage.build_terrain_into(g)

	var label := PackedInt32Array()
	label.resize(CellGrid.CELL_COUNT)
	label.fill(-1)
	var clumps := 0
	for y in CellGrid.H:
		for x in CellGrid.W:
			if g.mat_at(x, y) != Mat.WOOD:
				continue
			if label[(y << CellGrid.X_SHIFT) | x] != -1:
				continue
			_flood(g, label, x, y, clumps)
			clumps += 1
	t.ok(clumps >= 4, "무대의 나무가 여러 덩어리로 끊겨 있다 (%d덩어리)" % clumps)

	# The gap criterion is not "a thickness a blast cannot punch through" — even if a blast punches through,
	#  that spot is empty and fire cannot cross empty either. The real criterion is **a width at which a small
	#  ignition source cannot light two lumps at once.**
	#  The generation 0 blast's ignition radius is deliberately excluded — crossing over is that combination's character.
	var need := maxi(Tuning.rune_r(0), Tuning.blast_ignite_r(Tuning.SPLIT_MAX))
	var closest := _closest_gap(g, label)
	t.ok(closest > need,
		"덩어리 사이가 작은 점화원(%d셀)보다 넓다 (제일 좁은 곳 %d셀)" % [need, closest])


## **The old contract moved here. It was not deleted; its meaning changed.**
##
## Before: "**the whole stage fits on one screen**" — a static-camera premise.
##  The reason was "if the stage spills into the margins, **several of the 8 spread bolts detonate off-screen**
##  and the user reads it as 'it did not go off' — v1 got burned by exactly that with the floor slab".
##
## **Camera follow made that assertion impossible in principle** — the stage (2048x1152) is bigger than the
##  screen (960x540). => **The reason is kept and the assertion is narrowed: "at least my surroundings are always visible".**
##
## **What was N chosen as — the generation 0 flash radius (`flash_px(0)`). Three grounds:**
##  (1) **A blast at my feet is the main way I get hit in practice** (design: "shoot your feet and the blast at
##    the floor hits you"). If that flash is clipped off screen, **"it went off" is not read off the screen** —
##    the same as the old reason
##  (2) The flash is **the biggest presentation on screen.** Bigger than the hole (radius 24 cells = 96px)
##    at 216px, and it lingers longer than the shake
##  (3) **It is derived from a constant.** Hardcode a tile count and the day the flash grows only this check goes stale
##
## **It does not demand outside the world** — the required range is intersected with the world. A clamped camera
##  **correctly** does not show outside the world, so without the cut it would be red forever in a corner of the stage.
## **What is measured here goes as far as "the camera shows that much".** A spread bolt landing 30 tiles away is
##  **still invisible**, and that is written as "what was lost" in the `MAP` comment in `stage.gd`.
func _camera_always_shows_my_surroundings(t) -> void:
	var view := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height")))
	var world := Stage.world_size()
	t.ok(view.x > 0.0 and view.y > 0.0, "뷰포트 크기를 읽었다 (%dx%d)" % [int(view.x), int(view.y)])
	t.ok(world.x > 0.0 and world.y > 0.0, "세상 크기가 격자에서 나온다 (%dx%d)" % [
		int(world.x), int(world.y)])

	var need := Fx.flash_px(0)
	# If the requirement is bigger than the screen, **it cannot be held anywhere** — then everything below goes
	#  red while the cause is this value, not the camera. Measuring it first splits the diagnosis.
	t.ok(need * 2.0 + float(Character.W_PX) <= view.x
			and need * 2.0 + float(Character.H_PX) <= view.y,
		"요구 반경(섬광 %dpx)이 화면에 애초에 들어간다" % int(need))

	# **The corners are looked at.** Measuring only the center never passes through the spot where the clamp runs —
	#  the clamp only bites **at the edges**, so that is the whole of this check.
	var w := float(Character.W_PX)
	var h := float(Character.H_PX)
	var spots: Array[Vector2] = [
		Vector2(0.0, 0.0), Vector2(world.x - w, 0.0),
		Vector2(0.0, world.y - h), Vector2(world.x - w, world.y - h),
		Vector2(world.x * 0.5, world.y * 0.5),
		Vector2(float(Stage.SPAWN_TILE.x), float(Stage.SPAWN_TILE.y))
			* float(Tuning.CELL_PX * Tuning.TILE_CELLS),
	]
	t.ok(spots.size() > 0, "재 볼 자리가 %d곳이다" % spots.size())

	var world_rect := Rect2(Vector2.ZERO, world)
	for at: Vector2 in spots:
		var box := Rect2(at, Vector2(w, h))
		var center := Stage.camera_center(box.position + box.size * 0.5, view, world)
		var seen := Rect2(center - view * 0.5, view)
		# Required range = the box grown by `need`, **intersected with the world**.
		var want := box.grow(need).intersection(world_rect)
		t.ok(seen.encloses(want),
			"캐릭터가 %s 에 있을 때 주변 %dpx 가 보인다 (화면 %s~%s ⊇ %s~%s)" % [
				at, int(need), seen.position, seen.end, want.position, want.end])
		# **Does the clamp actually run.** The line above alone **stays green even with the clamp deleted
		#  entirely** — without the clamp the visible range only gets wider, so "the surroundings are visible"
		#  holds even better.
		#  => **"It does not show outside the world"** is measured separately. Outside the grid nothing is drawn,
		#   so it looks like "the world got cut off".
		t.ok(world_rect.encloses(seen),
			"캐릭터가 %s 에 있어도 화면이 세상 밖을 안 보여 준다 (%s~%s)" % [
				at, seen.position, seen.end])

	# **The branch that does not run is measured directly.** The world is currently bigger than the screen so the
	#  "narrow world" branch never runs, and **a branch that does not run can be wrong with nobody barking.**
	#  The day the stage shrinks, this speaks first.
	var tiny := view * 0.5
	t.eq(Stage.camera_center(Vector2.ZERO, view, tiny), tiny * 0.5,
		"세상이 화면보다 좁으면 세상 한가운데에 둔다 (한쪽 끝에 안 붙는다)")


## Paints one 4-neighbour connected component. It is a stack, not recursion — GDScript recursion hits the
## depth limit on a 656-cell lump.
func _flood(g: CellGrid, label: PackedInt32Array, sx: int, sy: int, id: int) -> void:
	var stack: Array[int] = [(sy << CellGrid.X_SHIFT) | sx]
	label[stack[0]] = id
	while not stack.is_empty():
		var i: int = stack.pop_back()
		var x := i & CellGrid.X_MASK
		var y := i >> CellGrid.X_SHIFT
		for k in 4:
			var nx: int = x + NB_DX[k]
			var ny: int = y + NB_DY[k]
			if nx < 0 or nx >= CellGrid.W or ny < 0 or ny >= CellGrid.H:
				continue
			var ni: int = (ny << CellGrid.X_SHIFT) | nx
			if label[ni] != -1 or g.mat_at(nx, ny) != Mat.WOOD:
				continue
			label[ni] = id
			stack.append(ni)


## The narrowest gap (cells) between two different lumps. It sweeps rows and columns —
## fire and ignition are both 4-neighbour, so the axis-aligned gap is the distance that can be crossed.
func _closest_gap(g: CellGrid, label: PackedInt32Array) -> int:
	var best := CellGrid.W
	for y in CellGrid.H:
		best = mini(best, _gap_along(label, y, true))
	for x in CellGrid.W:
		best = mini(best, _gap_along(label, x, false))
	return best


func _gap_along(label: PackedInt32Array, line: int, horizontal: bool) -> int:
	var best := CellGrid.W
	var last_id := -1
	var last_at := -1
	var n := CellGrid.W if horizontal else CellGrid.H
	for k in n:
		var i := (line << CellGrid.X_SHIFT) | k if horizontal else (k << CellGrid.X_SHIFT) | line
		var id := label[i]
		if id < 0:
			continue
		if last_id >= 0 and id != last_id:
			best = mini(best, k - last_at - 1)
		last_id = id
		last_at = k
	return best


## **The sim axis growing while the screen does not follow is how v1 died.**
## The lengths and the monotonicity of the two tables are measured **together** — grow one only and this goes red.
## The direction of monotonicity is the opposite of v1's: deeper generation means **smaller.**
func _gen_tables(t) -> void:
	var sim: Array[Dictionary] = Tuning.SIM_SIZES
	var fx: Array[Dictionary] = Fx.FX_SIZES
	t.ok(sim.size() > 0, "세대 표가 비어 있지 않다 (%d줄)" % sim.size())
	t.eq(fx.size(), sim.size(), "SIM_SIZES와 FX_SIZES의 길이가 같다")
	# The generation really does climb to SPLIT_MAX. A shorter table hides the row the clamp lands on.
	t.ok(sim.size() >= Tuning.SPLIT_MAX + 1,
		"표가 SPLIT_MAX(%d)까지 덮는다 (%d줄)" % [Tuning.SPLIT_MAX, sim.size()])

	# **Adding a column means adding its name to this list too.** Skip that and nobody measures it while the
	#  pass count stays green — this file measured it with the `damage` column and wrote it down that way.
	#  `water_r` was added when the water rune stood up.
	_strictly_decreasing(t, sim, "SIM_SIZES",
		["speed", "rd", "ignite_r", "rune_r", "carve_r", "water_r"])
	_strictly_decreasing(t, fx, "FX_SIZES", ["bolt_px", "trail_ticks", "flash_px", "shake_px"])

	# The ignition radius must exceed the destruction radius for fire to catch — it must hold **per generation.**
	for gen in sim.size():
		t.ok(Tuning.blast_ignite_r(gen) > Tuning.blast_rd(gen),
			"세대 %d의 점화 반경이 파괴 반경보다 크다" % gen)
		# A rune trace of 0 cannot reach a neighbour from the impact point (an empty cell), so **nothing happens.**
		#  Then the embers of "blast -> spread" evaporate again, and not one error is raised.
		t.ok(Tuning.rune_r(gen) > 0, "세대 %d의 룬 흔적 반경이 0이 아니다" % gen)
		# The trace must be **smaller than the blast.** Larger and spread looks like it doubles as blast,
		#  mushing the two combinations together.
		t.ok(Tuning.rune_r(gen) < Tuning.blast_rd(gen),
			"세대 %d의 룬 흔적이 폭발 반경보다 작다 (%d < %d)" % [
				gen, Tuning.rune_r(gen), Tuning.blast_rd(gen)])
		# A carve radius of 0 removes "magic digs walls" (GDD) entirely **with no error** —
		#  that was exactly the state before, and the nets were green the whole time.
		t.ok(Tuning.carve_r(gen) > 0, "세대 %d가 실제로 판다 (반경 %d)" % [
			gen, Tuning.carve_r(gen)])
		# The carve must be **much** smaller than the blast for the two to be told apart on screen. The inequality is that lower bound.
		t.ok(Tuning.carve_r(gen) < Tuning.blast_rd(gen),
			"세대 %d의 파는 반경이 폭발보다 작다 (%d < %d)" % [
				gen, Tuning.carve_r(gen), Tuning.blast_rd(gen)])
		# **Carving (1) comes before the rune trace (2)** => equal or larger means **the carve erases the fuel
		#  the fire rune would burn.** Exactly the same trap as `ignite_r > rd` above in miniature, and in
		#  "carve, then set fire there" **only the fire quietly disappears with no error.**
		#  Generation 1 has **1 cell of margin** (1 < 2).
		t.ok(Tuning.carve_r(gen) < Tuning.rune_r(gen),
			"세대 %d의 파는 반경이 룬 흔적보다 작다 (%d < %d)" % [
				gen, Tuning.carve_r(gen), Tuning.rune_r(gen)])
		# **The water trace bears the same contract.** Carving comes first, so equal or larger means **the carve
		#  erases the place water would go** — the water version of the fire trap, and just as quiet.
		t.ok(Tuning.water_r(gen) > 0, "세대 %d의 물 흔적 반경이 0이 아니다" % gen)
		t.ok(Tuning.carve_r(gen) < Tuning.water_r(gen),
			"세대 %d의 파는 반경이 물 흔적보다 작다 (%d < %d)" % [
				gen, Tuning.carve_r(gen), Tuning.water_r(gen)])

	# Does the clamp actually run. If it dies on a generation past the table, that spot blows up when the spread cap is raised.
	var last := sim.size() - 1
	t.eq(Tuning.blast_rd(last + 5), Tuning.blast_rd(last), "표 밖 세대는 마지막 줄로 떨어진다")
	t.eq(Fx.bolt_px(last + 5), Fx.bolt_px(last), "연출도 같은 규칙으로 떨어진다")


## **Equal values are a failure.** Left equal, the net cannot distinguish "deliberately not decreased" from
## "forgot to decrease" — to turn an axis off, multiply by a constant on the consumer side.
func _strictly_decreasing(t, rows: Array[Dictionary], nm: String, keys: Array) -> void:
	for key: String in keys:
		var ok := true
		var seen: Array = []
		for gen in rows.size():
			t.ok(rows[gen].has(key), "%s[%d]에 %s가 있다" % [nm, gen, key])
			var v: float = float(rows[gen].get(key, 0))
			seen.append(v)
			if gen > 0 and v >= float(rows[gen - 1].get(key, 0)):
				ok = false
		t.ok(ok, "%s의 %s가 세대마다 반드시 줄어든다 %s" % [nm, key, seen])


## If the indexing is wrong end to end, the symptom only shows up as "the grid looks odd".
func _grid_constants(t) -> void:
	t.eq(1 << CellGrid.X_SHIFT, CellGrid.W, "X_SHIFT가 W와 맞는다")
	t.eq(CellGrid.X_MASK, CellGrid.W - 1, "X_MASK가 W와 맞는다")
	t.eq(CellGrid.CELL_COUNT, CellGrid.W * CellGrid.H, "CELL_COUNT가 W×H와 맞는다")
	# GDD grid: cell 4px · terrain tile 32px = 8x8 cells · character 32px.
	# The character and the tile having the same thickness is the device that makes
	# "break through that wall and you can pass" visible.
	# In the 32px switch only the tile got thicker — **the 4px cell was not touched** (GDD: enlarging the cell mushes the power tiers).
	t.eq(Tuning.CELL_PX, 4, "셀이 4px이다 (GDD 확정)")
	t.eq(Tuning.TILE_CELLS * Tuning.CELL_PX, 32, "지형 타일이 32px이다 (GDD 확정)")
	t.eq(60 % Tuning.TICK_DIVIDER, 0, "분주기가 60을 딱 나눈다")


func _materials(t) -> void:
	# Baking the palette is src/view/'s job — Color is floating point and would violate the sim folder contract.
	#  The table is still the single source (the one `rgb` entry in `DEFS`) and here only the derivation is checked.
	var pal := CellRenderer.bake_palette()
	t.eq(pal.size(), Mat.SLOT_COUNT, "팔레트 길이가 SLOT_COUNT")
	t.ok(Mat.ALL.size() > 0, "재료가 하나라도 있다 (%d개)" % Mat.ALL.size())
	for id: int in Mat.ALL:
		# The baking formula is not copied here, it is **inverted** — copied, both could be wrong together and still green.
		t.eq(_to_rgb(pal[id]), int(Mat.DEFS[id]["rgb"]),
			"%s 색이 DEFS의 rgb에서 나온다" % Mat.material_name(id))
	# An undefined slot must be magenta. A well-behaved black would make an added material quietly invisible.
	t.eq(_to_rgb(pal[Mat.SLOT_COUNT - 1]), Mat.MISSING_RGB, "빈 슬롯은 마젠타 센티넬")
	t.eq(Mat.rgb_of(Mat.SLOT_COUNT - 1), Mat.MISSING_RGB, "정의 없는 id는 마젠타를 돌려준다")

	var beh := Mat.bake_behavior()
	t.eq(beh.size(), Mat.SLOT_COUNT, "거동 테이블 길이가 SLOT_COUNT")
	for id: int in Mat.ALL:
		t.eq(beh[id], int(Mat.DEFS[id]["behavior"]),
			"%s 거동이 DEFS에서 나온다" % Mat.material_name(id))

	# Fuel goes into _aux (a PackedByteArray). Above 255 it is silently truncated to the low 8 bits.
	var fuel := Mat.bake_fuel()
	t.eq(fuel.size(), Mat.SLOT_COUNT, "연료 테이블 길이가 SLOT_COUNT")
	for id: int in Mat.ALL:
		var f := int(Mat.DEFS[id]["fuel"])
		t.ok(f >= 0 and f <= 255, "%s 연료가 바이트에 들어간다" % Mat.material_name(id))
		t.eq(fuel[id], f, "%s 연료가 DEFS에서 나온다" % Mat.material_name(id))
	# Stone does not burn. If this breaks, "does fire stop at stone" (acceptance 5) becomes meaningless entirely.
	t.eq(int(Mat.DEFS[Mat.STONE]["fuel"]), 0, "돌은 연료가 0이다")
	t.ok(int(Mat.DEFS[Mat.WOOD]["fuel"]) > 0, "나무는 연료가 있다")


## Adding one glyph = one row in DEFS + one row in ALL. If those diverge, that glyph becomes a ghost that is
## in the firing validation but not in the iteration (or the reverse).
## Actually running it is net_spell's job — here it is only whether the table agrees with itself.
func _glyphs(t) -> void:
	# 0 is reserved as "end of list". If this breaks, an empty list and a single glyph become indistinguishable.
	t.eq(Glyph.GLYPH_NONE, 0, "GLYPH_NONE이 0이다")
	t.eq(Glyph.MASK, (1 << Tuning.GLYPH_BITS) - 1, "니블 마스크가 GLYPH_BITS와 맞는다")
	# 4 bits x 7 layers = 28 bits. An 8th layer sits in the top nibble and goes negative, and since `>> 4` is an
	# arithmetic shift, sign extension corrupts it with no error — it becomes an infinite loop.
	t.ok(Tuning.GLYPH_BITS * Tuning.GLYPH_MAX_LAYERS <= 31,
		"문양 목록이 부호 비트를 안 건드린다 (%d비트)" % (Tuning.GLYPH_BITS * Tuning.GLYPH_MAX_LAYERS))

	t.eq(Glyph.ALL.size(), Glyph.DEFS.size(), "ALL과 DEFS의 문양 수가 같다 (%d개)" % Glyph.ALL.size())
	for id: int in Glyph.ALL:
		t.ok(Glyph.DEFS.has(id), "ALL의 문양 %d가 DEFS에 있다" % id)
		t.ok(id > Glyph.GLYPH_NONE and id <= Glyph.MASK, "문양 %d가 니블 범위 안이다" % id)
		var d: Dictionary = Glyph.DEFS[id]
		t.ok(d.has("name") and d.has("kind") and d.has("max_per_circle") and d.has("tick_budget"),
			"문양 %d 정의에 네 칸이 다 있다" % id)
		var kind := int(d["kind"])
		t.ok(kind == Glyph.KIND_SPAWN or kind == Glyph.KIND_TERMINAL,
			"문양 %s의 종류가 SPAWN/TERMINAL 중 하나다" % d["name"])
		# 0 = unlimited. A negative has no meaning and is quietly read as "no limit".
		t.ok(int(d["max_per_circle"]) >= 0, "문양 %s의 max_per_circle이 음수가 아니다" % d["name"])
		t.ok(int(d["tick_budget"]) >= 0, "문양 %s의 tick_budget이 음수가 아니다" % d["name"])

	# The rune table follows the same discipline. `spell_sim._rune_trace` indexes `ELEM_DEFS[element]` directly
	#  while validation goes through `ELEM_ALL` — diverge and firing passes but impact dies.
	t.eq(Tuning.ELEM_ALL.size(), Tuning.ELEM_DEFS.size(),
		"ELEM_ALL과 ELEM_DEFS의 룬 수가 같다 (%d개)" % Tuning.ELEM_ALL.size())
	for id: int in Tuning.ELEM_ALL:
		t.ok(Tuning.ELEM_DEFS.has(id), "ALL의 룬 %d가 DEFS에 있다" % id)
		t.ok(Tuning.ELEM_DEFS[id].has("trace"), "룬 %d 정의에 trace가 있다" % id)

	# Does the baked table come from DEFS. Hardcoded, only one side grows when glyphs are added.
	var budget := Glyph.bake_tick_budget()
	t.eq(budget.size(), Glyph.MASK + 1, "예산 표 길이가 니블 범위와 같다")
	for id: int in Glyph.ALL:
		t.eq(budget[id], int(Glyph.DEFS[id]["tick_budget"]),
			"문양 %s 예산이 DEFS에서 나온다" % Glyph.DEFS[id]["name"])


## Does the map fit inside the grid and are the row widths even.
func _stage_map(t) -> void:
	t.eq(Stage.MAP.size(), Stage.MAP_H, "맵 행 수가 MAP_H")
	t.ok(Stage.MAP_W * Tuning.TILE_CELLS <= CellGrid.W, "맵 폭이 격자 안에 들어간다")
	t.ok(Stage.MAP_H * Tuning.TILE_CELLS <= CellGrid.H, "맵 높이가 격자 안에 들어간다")

	for ty in Stage.MAP.size():
		t.eq(String(Stage.MAP[ty]).length(), Stage.MAP_W, "맵 %d행 폭이 MAP_W" % ty)

	_camera_always_shows_my_surroundings(t)

	# Do the map characters point at materials that exist. One typo and that terrain quietly is not built.
	for ch: String in Stage.MAP_CHARS.keys():
		t.ok(Mat.ALL.has(int(Stage.MAP_CHARS[ch])), "맵 문자 '%s'가 실재 재료다" % ch)


## **Does the editor brush follow the material table — the only net for "it goes stale quietly".**
##
## `docs/design/terrain-baking.md` wrote this risk down by name: the brush image and the tileset table can
## diverge from `DEFS` and **the game screen is still not wrong** (the screen is drawn by the cell grid)
## => **nobody notices.** It is only confusing when picking a brush, and by then a wrongly drawn map already exists.
##
## **Three of the "four places to fix" when adding a material are measured here.** The fourth (`DEFS` itself)
## is the source, so there is nothing to measure.
const TILESET_PATH := "res://src/stage/terrain_tileset.tres"
const ATLAS_PATH := "res://assets/stage/terrain_tiles.png"

func _terrain_brush_follows_the_material_table(t) -> void:
	var ids := Palette.paintable()
	# Same reason as the first line of a folder-scanning net — an empty list runs none of the below and goes green.
	t.ok(ids.size() > 0, "붓이 되는 재료가 있다 (%d개)" % ids.size())
	# **Empty is not a brush** — not placing a tile is what empty is.
	t.ok(not ids.has(Mat.EMPTY), "빈칸은 붓 목록에 없다")
	t.eq(ids.size(), Mat.ALL.size() - 1, "빈칸 말고 전부 붓이 된다")

	# -- (1) the brush image ---------------------------------------
	var tex: Texture2D = load(ATLAS_PATH)
	t.ok(tex != null, "붓 그림을 읽는다")
	if tex == null:
		return
	var px := Palette.tile_px()
	t.eq(tex.get_width(), px * ids.size(), "붓 그림의 폭이 붓 수와 맞는다")
	t.eq(tex.get_height(), px, "붓 그림의 높이가 타일 한 변이다")

	var img := tex.get_image()
	t.ok(img != null, "붓 그림의 픽셀을 읽는다")
	if img != null:
		var wrong := 0
		for i in ids.size():
			var at := Palette.atlas_of(i)
			# Sample the center of the cell — the edges can be shaken by the import filter.
			var got := img.get_pixel(at.x * px + px / 2, at.y * px + px / 2)
			var rgb := Mat.rgb_of(ids[i])
			var want := Color8((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF)
			if not got.is_equal_approx(want):
				wrong += 1
				t.ok(false, "%s 붓 색이 DEFS와 다르다 (그림 %s · 표 #%06X)" % [
					Mat.material_name(ids[i]), got.to_html(false), rgb])
		t.eq(wrong, 0, "붓 %d개의 색이 전부 DEFS의 rgb와 같다" % ids.size())

	# -- (2) the tileset -------------------------------------------
	var tileset: TileSet = load(TILESET_PATH)
	t.ok(tileset != null, "타일셋을 읽는다")
	if tileset == null:
		return
	var src := tileset.get_source(0) as TileSetAtlasSource
	t.ok(src != null, "타일셋에 atlas 소스가 있다")
	if src == null:
		return
	t.eq(src.get_tiles_count(), ids.size(), "타일 수가 붓 수와 같다 (남는 타일도 모자란 타일도 없다)")
	for i in ids.size():
		var at := Palette.atlas_of(i)
		var data := src.get_tile_data(at, 0)
		t.ok(data != null, "%s 자리(%d,%d)에 타일이 있다" % [Mat.material_name(ids[i]), at.x, at.y])
		if data != null:
			t.eq(int(data.get_custom_data("material")), ids[i],
				"%s 타일에 붙은 재질이 맞다" % Mat.material_name(ids[i]))

	# **Is the uid alive.** `stage.tscn` references this resource **by uid** —
	#  `ResourceSaver.save` was actually seen erasing the uid.
	#  Today the `path` is written too so the game does not break, but the editor issues a new uid and **the scene diffs.**
	var head := FileAccess.get_file_as_string(TILESET_PATH).split("
")[0]
	t.ok(head.contains("uid://"), "타일셋 .tres 가 uid 를 들고 있다 (씬이 그걸로 참조한다)")

	# -- (3) the character table -----------------------------------
	# Missing, **the bake barks and stops** — the only one of the four that dies loudly, but the net catching it first is better.
	var seen := {}
	for id: int in ids:
		var has: bool = Baker.CHAR_BY_MAT.has(id)
		t.ok(has, "%s 에 맵 글자가 있다" % Mat.material_name(id))
		if not has:
			continue
		var ch: String = Baker.CHAR_BY_MAT[id]
		t.eq(ch.length(), 1, "%s 의 맵 글자가 한 글자다 (한 칸이 한 글자다)" % Mat.material_name(id))
		# Overlapping means **two materials merge into one** when the baked map is replanted.
		t.ok(not seen.has(ch), "맵 글자 `%s` 가 %s 에만 쓰인다" % [ch, Mat.material_name(id)])
		seen[ch] = id
	t.eq(seen.size(), ids.size(), "붓마다 서로 다른 글자가 하나씩이다")

	# -- (4) did the baked artifact follow the character table ------
	# **Deriving in code fixes only "the moment of baking" and not "the checked-in artifact".**
	#  It was actually committed in a diverged state — `~` was put into `CHAR_BY_MAT` and **the map was not re-baked.**
	#   Then the baked map has a new character the game does not know, and since `MAP_CHARS.has(ch)` is false,
	#   **that cell becomes empty with no error.**
	#  That means the very fault the doc said was "fixed by derivation" was present **in the present tense** —
	#   derivation fixed the tool, and the artifact only follows once it is **re-baked.**
	# => **They are compared both ways.** Looking one way misses either "a leftover character" or "a missing one".
	var baked: Dictionary = Stage.MAP_CHARS
	for id: int in ids:
		if not Baker.CHAR_BY_MAT.has(id):
			continue
		var ch: String = Baker.CHAR_BY_MAT[id]
		t.ok(baked.has(ch),
			"구운 맵이 `%s`(%s) 를 안다 — 아니면 그 칸이 빈칸이 된다. **다시 구워라**" % [
				ch, Mat.material_name(id)])
		if baked.has(ch):
			t.eq(int(baked[ch]), id, "구운 맵의 `%s` 가 %s 를 가리킨다" % [ch, Mat.material_name(id)])
	# The other side — a character only in the artifact is the trace of **a deleted material**.
	for ch2: String in baked:
		t.ok(seen.has(ch2), "구운 맵의 글자 `%s` 가 지금도 붓에 있다 (은퇴한 재료가 안 남았다)" % ch2)
	t.eq(baked.size(), Baker.CHAR_BY_MAT.size(), "구운 맵의 글자 수가 글자표와 같다")

	# **A hidden fifth table.** It was a local variable inside `bake()`, invisible to the nets, and was raised to a constant.
	#  Missing, **the brush appears and the tile is placed but the bake dies** — that actually happened when
	#   water was added (only `CHAR_BY_MAT` was grown and not this one: "I do not know the constant name for material id 4").
	#  And that only surfaces **once that material is actually drawn on the map** — undrawn, it is never caught.
	for id2: int in ids:
		t.ok(Baker.NAME_BY_MAT.has(id2),
			"%s 에 GDScript 상수 이름이 있다 (굽기가 `Mat.<이름>` 으로 뱉는다)" % Mat.material_name(id2))
	# And that name has to be a real constant — a typo makes the generated file a parse error.
	var consts := (Mat as GDScript).get_script_constant_map()
	for id2: int in ids:
		if not Baker.NAME_BY_MAT.has(id2):
			continue
		var nm: String = Baker.NAME_BY_MAT[id2]
		t.ok(consts.has(nm) and int(consts[nm]) == id2,
			"`Mat.%s` 가 실재하고 값이 %d다 (오타면 생성 파일이 파스 에러다)" % [nm, id2])
