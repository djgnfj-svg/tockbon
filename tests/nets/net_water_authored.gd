extends RefCounted
## **Authored water — a `~` on the map is full, and it is asleep.**
##
## `stage2-water.md` §6 names this "the cheapest net in this doc" and rests stage 2's
## whole cost argument on the two halves measured here. **Both halves were broken when this was written**,
## in a way the survey described wrongly, so the shapes are worth writing down:
##
##  · **Full**: `cmd_fill` refuses `Mat.WATER` at `_valid_mat` — **on purpose**, and with a net on the
##    refusal (`net_water._cmd_fill_refuses_water`). So a map with `~` in it baked **zero water cells** and
##    barked once per horizontal run. Not "water with amount 0" as the survey said — **a hole in the
##    terrain, drawn as a lake.** `cmd_fill_water` is the door that fixes it without loosening the refusal.
##  · **Asleep**: measured, not reasoned. `tools/stage/measure_water_rest.gd` — authored flat sleeps at
##    **tick 2** at every width tried (32 · 128 · 256), at the grid edge, and **over a stepped floor**;
##    the same bowl **poured** takes **1,032 ticks**. That gap is why this net exists.
##
## **Two is the floor, not one, and the survey's acceptance is wrong about it.** Placing water dirties its
## chunks (`_write_water` -> `_touch`) and `_chunk_flip` runs at tick *start*, so tick 1 is awake no matter
## what. "0 after one `step()`" is unachievable in principle. **The check is therefore two-sided** — awake on
## tick 1, asleep on tick 2 — because "asleep on tick 2" alone is also passed by water that never existed.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Stage := preload("res://src/stage/stage.gd")

## **The pool, in tile coordinates, written down as literals.** Deriving them from the grid the map builds
##  would make the check shrink whenever the pool shrinks — CLAUDE.md's "a check whose bounds come from the
##  thing it checks proves nothing". These are the numbers `_map()` paints, and the two must be read together.
const POOL_TX0 := 1
const POOL_TX1 := 20
## Tile rows, counted **up from the map's bottom** so the map's own height stays the single source.
const POOL_ROWS_FROM_BOTTOM := [4, 3]
const FLOOR_ROWS_FROM_BOTTOM := [2, 1]
## **This net's map is its own width, not stage 1's.** `build_map_into` takes the width from the map's first
##  row now (per-stage widths), so borrowing `Stage.MAP_W` here would only couple this net to stage 1's
##  re-export for nothing. The height is not free — that function refuses any map that is not `MAP_H` tall.
const MAP_TILES_W := 64


func run(t) -> void:
	_map_bakes_full_water(t)
	_map_water_is_asleep_on_the_second_tick(t)
	_authored_water_is_deep_enough_to_jump_in(t)
	_fill_water_writes_only_over_empty_and_water(t)
	_fill_water_clamps_like_fill(t)
	_fill_water_refuses_an_out_of_range_amount(t)
	_cmd_fill_still_refuses_water(t)
	_authored_flat_sleeps_over_a_stepped_floor(t)


# ====================================================================
#  the map path — the whole point of the net
# ====================================================================

## **A `~` tile holds `WATER_MAX`, in every cell of it.**
##
## **One probed cell is not enough and that is not pedantry** — a fix that wrote the first cell of each run
##  and nothing else would pass a single `aux_at`. So the cell **count**, the **sum** and the **minimum** are
##  all measured, and the count is compared against a figure computed from the tile rectangle above, not from
##  anything the grid reports.
func _map_bakes_full_water(t) -> void:
	var g := CellGrid.new()
	Stage.build_map_into(g, _map(), Stage.MAP_CHARS)

	var cells := _pool_cell_count()
	t.eq(g.count_material(Mat.WATER), cells, "`~` 타일이 물 셀 %d개를 굽는다" % cells)

	var r := _pool_rect()
	var sum := _aux_sum(g, r)
	t.eq(sum, cells * Tuning.WATER_MAX, "그 물의 총량이 전부 WATER_MAX 다 (%d)" % sum)
	t.eq(_aux_min(g, r), Tuning.WATER_MAX, "가장 얕은 칸도 WATER_MAX 다")

	# A cell in the middle of the pool, probed by hand — the value a level designer would look at.
	t.eq(g.aux_at((r[0] + r[2]) / 2, (r[1] + r[3]) / 2), Tuning.WATER_MAX, "웅덩이 한가운데가 가득이다")


## **Awake on tick 1, asleep on tick 2.**
##
## ⚠ **"Awake on tick 1" is nowhere near enough a guard, and this net proved it on itself.** Baking the
##  *terrain* wakes chunks too, and bare terrain also sleeps by tick 2 — so with the `~` bug still in place
##  (zero water baked) **this check passed**, on a map holding no water at all. It only went red by accident
##  on a 300-tile map, where the bake overflows `MAX_CHUNKS_PER_TICK` and takes a third tick.
##  ⇒ **The survey's proposed check — "`step()` once, assert `active_chunk_count() == 0`" — is passed by the
##  very bug it was written to catch.** Only its `aux_at` half ever bit.
##
## So the sleep is pinned by a **stated precondition**: the pool's full amount, re-measured here rather than
##  assumed from the check above. A check whose setup is silently empty measures nothing, and this is the
##  cheapest thing that cannot be satisfied by an empty map.
##
## **A sharper-looking guard was tried and thrown away, and it is worth recording why**: "the pool's own
##  water-only chunk must be awake on tick 1" **passed with zero water**. `_touch` wakes the chunk *above*
##  when a cell sits on a chunk's top row, so the bedrock floor one row below lights the pool's chunk on its
##  own. **It read as a discriminator and discriminated nothing** — exactly the decoy shape CLAUDE.md warns
##  about, found only by running it against the unfixed code.
##
## **And it must stay asleep.** One tick at 0 is not equilibrium; a surface trading no-op writes would show
##  up only from the third tick on. The total is re-measured after those ticks for the same reason.
func _map_water_is_asleep_on_the_second_tick(t) -> void:
	var g := CellGrid.new()
	Stage.build_map_into(g, _map(), Stage.MAP_CHARS)
	var r := _pool_rect()
	var before := _aux_sum(g, r)
	t.eq(before, _pool_cell_count() * Tuning.WATER_MAX, "전제 — 웅덩이가 실제로 가득 차 있다")

	g.step()
	t.ok(g.active_chunk_count() > 0, "구운 직후 첫 틱은 깨어 있다 (%d청크)" % g.active_chunk_count())

	g.step()
	t.eq(g.active_chunk_count(), 0, "둘째 틱에 활성 청크가 0이 된다")

	for _i in 50:
		g.step()
	t.eq(g.active_chunk_count(), 0, "그 뒤 50틱을 더 돌려도 0이다")
	t.eq(_aux_sum(g, r), before, "그동안 총량이 한 칸도 안 움직였다")
	t.eq(g.get_tick(), 52, "틱은 실제로 돌았다")


## **The one thing a shallow pool would break silently.** `character.gd` grants unlimited jumps at or above
##  `WATER_WET`, and `_write_water` marks anything at or below it shallow. An authored pool below that line
##  is drawn as water, swims as water and **cannot be climbed** — which is the single mechanic stage 2 exists
##  for. So the depth is asserted against `WATER_WET` itself, not against 255.
func _authored_water_is_deep_enough_to_jump_in(t) -> void:
	var g := CellGrid.new()
	Stage.build_map_into(g, _map(), Stage.MAP_CHARS)
	var r := _pool_rect()
	t.ok(_aux_min(g, r) > Tuning.WATER_WET,
		"그려진 물이 WATER_WET(%d)보다 깊다 — 안 그러면 못 올라간다 (가장 얕은 칸 %d)"
			% [Tuning.WATER_WET, _aux_min(g, r)])

	var cx := (r[0] + r[2]) / 2
	var cy := (r[1] + r[3]) / 2
	t.eq(g.flag_at(cx, cy) & Mat.FLAG_SHALLOW, 0, "얕음 비트가 안 서 있다")

	# **The map character and the rune must not disagree.** The water rune fills with `maxi`, so hitting an
	#  authored pool must be a clean no-op — neither raising nor lowering it. If the two amounts ever drift
	#  apart, this is where it shows.
	var before := _aux_sum(g, r)
	g.apply(CellGrid.cmd_water(cx, cy, 6, Tuning.WATER_MAX))
	t.eq(_aux_sum(g, r), before, "물 룬을 그려진 웅덩이에 쏴도 총량이 그대로다 (지도와 룬이 같은 값이다)")


# ====================================================================
#  the command itself
# ====================================================================

## `_write_water`'s contract is "only over EMPTY or WATER", and `_fill_water_rect` is its fifth guarantor.
##  Breach it and the burn front keeps a ghost claiming a cell that is now water (`_write_water`'s comment).
func _fill_water_writes_only_over_empty_and_water(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(100, 600, 109, 600, Mat.STONE))
	g.apply(CellGrid.cmd_fill(110, 600, 119, 600, Mat.BEDROCK))
	g.apply(CellGrid.cmd_fill_water(100, 600, 129, 600, Tuning.WATER_MAX))

	t.eq(g.mat_at(105, 600), Mat.STONE, "돌 위에는 안 써진다")
	t.eq(g.aux_at(105, 600), 0, "돌 칸의 수량도 0 그대로다")
	t.eq(g.mat_at(115, 600), Mat.BEDROCK, "기반암 위에도 안 써진다")
	t.eq(g.mat_at(125, 600), Mat.WATER, "빈 칸에는 써진다")
	t.eq(g.aux_at(125, 600), Tuning.WATER_MAX, "그 수량이 실제로 들어간다")
	t.eq(g.count_material(Mat.WATER), 10, "덮어쓴 게 아니라 빈 10칸에만 놓였다")
	t.eq(g.unburnable_in_front_count(), 0, "불의 앞줄에 유령이 안 생겼다")

	# **It overwrites rather than fills** — the opposite of the rune's `maxi`, because a map is the authority
	#  on its own pool. Lowering must work, or a repaint can never make a lake shallower.
	g.apply(CellGrid.cmd_fill_water(120, 600, 129, 600, 64))
	t.eq(g.aux_at(125, 600), 64, "다시 그리면 수량이 내려간다 (`maxi` 가 아니다)")


## The rectangle must mean exactly what `cmd_fill`'s means, or `~` and `#` cover different tiles of the
##  same map row. **Both the reversed corners and the out-of-grid clamp are measured** — `_fill_rect` handles
##  both and a copy that dropped either would still pass every check above.
func _fill_water_clamps_like_fill(t) -> void:
	var g := CellGrid.new()
	# Corners given backwards.
	g.apply(CellGrid.cmd_fill_water(209, 700, 200, 700, Tuning.WATER_MAX))
	t.eq(g.count_material(Mat.WATER), 10, "모서리를 거꾸로 줘도 같은 10칸이다")
	t.eq(g.aux_at(200, 700), Tuning.WATER_MAX, "왼쪽 끝 칸이 채워졌다")
	t.eq(g.aux_at(209, 700), Tuning.WATER_MAX, "오른쪽 끝 칸이 채워졌다")

	# Hanging off the left edge and off the bottom. Clamped, not discarded — `_fill_rect`'s rule.
	var g2 := CellGrid.new()
	g2.apply(CellGrid.cmd_fill_water(-5, 800, 4, 800, Tuning.WATER_MAX))
	t.eq(g2.count_material(Mat.WATER), 5, "격자 왼쪽 밖은 잘려서 5칸만 놓인다")
	t.eq(g2.aux_at(0, 800), Tuning.WATER_MAX, "0열은 채워졌다")

	var g3 := CellGrid.new()
	g3.apply(CellGrid.cmd_fill_water(300, CellGrid.H - 2, 300, CellGrid.H + 40, Tuning.WATER_MAX))
	t.eq(g3.count_material(Mat.WATER), 2, "격자 아래 밖도 잘려서 2칸만 놓인다")
	t.eq(g3.aux_at(300, CellGrid.H - 1), Tuning.WATER_MAX, "마지막 행이 채워졌다")


## Past 255 `_aux` truncates to the low 8 bits with no error, so 256 would bake an **empty** lake.
##  The bark and this declaration are one unit (CLAUDE.md).
func _fill_water_refuses_an_out_of_range_amount(t) -> void:
	var g := CellGrid.new()
	t.expect_error("CellGrid.cmd_fill_water: amount")
	g.apply(CellGrid.cmd_fill_water(400, 700, 409, 700, Tuning.WATER_MAX + 1))
	t.eq(g.count_material(Mat.WATER), 0, "범위 밖 수량은 한 칸도 안 놓는다")

	t.expect_error("CellGrid.cmd_fill_water: amount")
	g.apply(CellGrid.cmd_fill_water(400, 700, 409, 700, -1))
	t.eq(g.count_material(Mat.WATER), 0, "음수도 마찬가지다")


## **The refusal this whole command exists to preserve.** `net_water._cmd_fill_refuses_water` owns it, and
##  it is re-measured here because the tempting fix was to loosen exactly that line. If someone does, this
##  net — the one that would look like it no longer needs to care — goes red too.
func _cmd_fill_still_refuses_water(t) -> void:
	var g := CellGrid.new()
	t.expect_error("CellGrid: water cannot be placed with cmd_fill")
	g.apply(CellGrid.cmd_fill(500, 700, 509, 700, Mat.WATER))
	t.eq(g.count_material(Mat.WATER), 0, "cmd_fill 은 여전히 물을 거부한다")


## **The case §6 was most afraid of** — a level surface over a floor that steps. Measured at 2 ticks by
##  `tools/stage/measure_water_rest.gd`; pinned here because it is the shape every real cistern has.
func _authored_flat_sleeps_over_a_stepped_floor(t) -> void:
	var g := CellGrid.new()
	var deep := 900
	var surface := 880
	var width := 96
	g.apply(CellGrid.cmd_fill(199, surface - 10, 199, deep, Mat.BEDROCK))
	g.apply(CellGrid.cmd_fill(200 + width, surface - 10, 200 + width, deep, Mat.BEDROCK))
	for k in width:
		var floor_y := deep - (k / 16) * 3
		g.apply(CellGrid.cmd_fill(200 + k, floor_y, 200 + k, deep, Mat.BEDROCK))
		g.apply(CellGrid.cmd_fill_water(200 + k, surface, 200 + k, floor_y - 1, Tuning.WATER_MAX))

	var rect: Array[int] = [200, surface, 200 + width - 1, deep]
	var before := _aux_sum(g, rect)
	t.ok(before > 0, "계단 바닥 위에 물이 실제로 놓였다 (%d)" % before)
	# **The depths really do differ**, or "flat over a step" is just "flat" and this check measures nothing.
	t.ok(g.aux_at(200, deep - 1) > 0 and g.aux_at(200 + width - 1, deep - 1) == 0,
		"바닥이 진짜 계단이다 (왼쪽 깊은 칸은 물, 오른쪽 같은 행은 바닥)")

	g.step()
	t.ok(g.active_chunk_count() > 0, "첫 틱은 깨어 있다 (%d청크)" % g.active_chunk_count())
	g.step()
	t.eq(g.active_chunk_count(), 0, "계단 바닥 위 평면도 둘째 틱에 잠든다")
	for _i in 50:
		g.step()
	t.eq(g.active_chunk_count(), 0, "그 뒤 50틱도 0이다")
	t.eq(_aux_sum(g, rect), before, "총량도 그대로다")


# ====================================================================
#  the map, and the instruments
# ====================================================================

## A map holding one walled 20x2-tile pool of `~` on a bedrock floor.
##
## **The height comes from `Stage.MAP_H`** — `build_map_into` refuses any other, and a net carrying its own
##  48 would go red for the wrong reason the day the map deepens. **The width is this net's own** (see the
##  constant). **The pool's coordinates are literals.** All three splits are deliberate.
func _map() -> Array[String]:
	var w := MAP_TILES_W
	var h: int = Stage.MAP_H
	var rows: Array[String] = []
	for ty in h:
		var from_bottom := h - ty
		if from_bottom in FLOOR_ROWS_FROM_BOTTOM:
			rows.append("B".repeat(w))
		elif from_bottom in POOL_ROWS_FROM_BOTTOM:
			# Walls on both sides. An unwalled pool spreads and never sleeps — measured at 738 ticks.
			var body := "B" + "~".repeat(POOL_TX1 - POOL_TX0 + 1) + "B"
			rows.append(body + ".".repeat(w - body.length()))
		else:
			rows.append(".".repeat(w))
	return rows


## The pool in **cell** coordinates: `[x0, y0, x1, y1]`, inclusive.
func _pool_rect() -> Array[int]:
	var tc: int = Tuning.TILE_CELLS
	var h: int = Stage.MAP_H
	var ty0: int = h - int(POOL_ROWS_FROM_BOTTOM[0])
	var ty1: int = h - int(POOL_ROWS_FROM_BOTTOM[1])
	var r: Array[int] = [POOL_TX0 * tc, ty0 * tc, (POOL_TX1 + 1) * tc - 1, (ty1 + 1) * tc - 1]
	return r


## **Computed from the tile rectangle, never from the grid.** This is the number `count_material` is
##  compared against, so it must not come from anything under test.
func _pool_cell_count() -> int:
	var tc: int = Tuning.TILE_CELLS
	return (POOL_TX1 - POOL_TX0 + 1) * tc * POOL_ROWS_FROM_BOTTOM.size() * tc


func _aux_sum(g: CellGrid, rect: Array[int]) -> int:
	var n := 0
	for y in range(rect[1], rect[3] + 1):
		for x in range(rect[0], rect[2] + 1):
			n += g.aux_at(x, y)
	return n


func _aux_min(g: CellGrid, rect: Array[int]) -> int:
	var lo := 1 << 30
	for y in range(rect[1], rect[3] + 1):
		for x in range(rect[0], rect[2] + 1):
			lo = mini(lo, g.aux_at(x, y))
	return lo
