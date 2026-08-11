extends RefCounted
## The gate (ending) — `src/actor/stage_gate.gd`, `src/view/gate_view.gd`, and `stage.gd`'s wall latch and
## ending term (`gate-ending-to-game.md`, Stages A-D).

const StageGate := preload("res://src/actor/stage_gate.gd")
const Stage := preload("res://src/stage/stage.gd")
const TownMap := preload("res://src/stage/town_map.gd")
const Fixtures := preload("res://src/actor/fixtures.gd")
const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Character := preload("res://src/actor/character.gd")
const MonsterDefs := preload("res://src/actor/monster_defs.gd")
const Fx := preload("res://src/view/fx_tuning.gd")
const GateView := preload("res://src/view/gate_view.gd")
const Progress := preload("res://src/actor/progress.gd")

const STAGE_SCENE := "res://src/stage/stage.tscn"

## Room ③'s interior column range (`gate-ending-to-game.md`'s own "Confirmed" table:
## "Room ③ interior x347-366", then x247-266, **now x164-183**). Only used here, to place a character for
## the camera-window check below — `stage_gate.gd` itself knows nothing about the room's own bounds, only
## the seat and the wall.
##
## **Every literal tile number in this file moved -83, +7 rows** (`burn-out-of-the-bull-room.md` §1/§3) —
##  room ③ moved down 7 rows and left 83 columns onto room ①'s own floor line. **They stay literals on
##  purpose** (verify-read, H5, below): a number read back out of `stage_gate.gd` shrinks with whatever it
##  is supposed to be catching.
const ROOM3_INTERIOR_X0 := 164
const ROOM3_INTERIOR_X1 := 183

## A `GateView` that counts its own `_draw()` calls — `net_frame_runner.gd`'s own `_CountingBox` technique,
## applied to the real production class instead of a stand-in, by subclassing and calling `super()`.
##
## **This alone proves only "the engine calls `_draw()`" — not "`_draw()` draws the arch"** (verify-read,
## H2: swapping the real `draw_texture_rect(...)` call for `pass` left this counter, and every check built
## on it, green — `super()` still ran and the counter still climbed with nothing painted). `_CapturingGateView`
## below is the check that closes that gap, by intercepting the actual draw call instead of counting `_draw`.
class _CountingGateView extends GateView:
	var draw_count := 0
	func _draw() -> void:
		super()
		draw_count += 1


## **Overrides `_paint_arch`, not the native `draw_texture_rect`** — GDScript refuses to let a script override
## a method from a native class (`draw_texture_rect()` overrides a method from native class "CanvasItem" is a
## hard parse error here, measured directly, not a warning) — that path is closed. `gate_view._paint_arch` is
## a small ordinary script method `_draw()` calls instead, added for exactly this seam, so this subclass can
## catch the texture, rect **and modulate** `_draw()` decided to hand it without touching the engine at all.
## This is what answers "does `_draw()` draw the arch, at the right spot, with the right picture" —
## `_CountingGateView` above only answers "does the engine call `_draw()` at all", which stayed true in
## verify-read's own inversion (H2) even with the real draw call deleted.
##
## **The override's name is load-bearing, not cosmetic.** `stage-clear-sequence.md`'s step 6 says the hand
## called `_draw()` below is safe "because `_paint_arch` is `_draw()`'s only drawing call" — that holds *only
## while this subclass overrides the current name.* Renamed in `gate_view.gd` and not here, the override goes
## orphan, `_draw()` reaches the real `draw_texture_rect` on an untreed node, and the engine barks
## "Drawing is only allowed inside this node's `_draw()`" — 9 undeclared stderr lines, which the wrapper's
## silence check turns into a failed round for **every** net, not just this one. Measured, not predicted.
class _CapturingGateView extends GateView:
	var calls := 0
	var last_texture: Texture2D = null
	var last_rect := Rect2()
	var last_tint := Color()
	func _paint_arch(tex: Texture2D, r: Rect2, arch_tint: Color) -> void:
		last_tint = arch_tint
		calls += 1
		last_texture = tex
		last_rect = r


func run(t) -> void:
	# -- Stage A — stage_gate.gd, pure geometry over the real baked terrain --
	_the_seat_is_standing_ground_on_the_real_map(t)
	_the_east_wall_is_stone_not_bedrock(t)
	_the_wall_tiles_are_stone_by_literal_tile_number(t)
	_the_walk_from_the_room_to_the_seat_has_no_drop(t)
	_at_fires_only_at_the_seat_and_nowhere_else(t)
	_the_band_covers_the_drawn_arch(t)
	# -- Stage B — the wall comes down through a real rooster death --
	_the_wall_is_solid_before_anything_dies(t)
	_a_real_rooster_death_opens_the_wall(t)
	_the_wall_tiles_are_open_by_literal_tile_number_after_the_kill(t)
	_the_walk_out_is_flat_after_the_drop(t)
	_r_restores_the_wall_and_the_latch(t)
	_the_wall_does_not_refill_every_tick(t)
	# -- Stage C — the arch on screen --
	_the_arch_is_invisible_before_the_kill_and_visible_after(t)
	_the_drawn_rect_is_where_the_arch_belongs(t)
	_the_arch_is_invisible_in_town(t)
	await _draw_actually_runs_once_treed_and_pumped(t)
	_the_draw_call_actually_paints_the_arch_texture_at_its_rect(t)
	_the_arch_is_inside_the_camera_window_only_from_the_rooms_east_half(t)
	# -- The clear sequence — the beats (`stage-clear-sequence.md`) --
	_the_wall_falling_kicks_the_camera_and_it_settles_back(t)
	_the_tint_curve_walks_from_transparent_to_opaque_to_the_flare(t)
	_the_drawn_tint_is_the_one_the_counters_decided(t)
	_the_shell_actually_turns_the_take_clock(t)
	_the_panel_opens_on_exactly_the_take_frames_th_frame(t)
	_one_frame_on_the_seat_is_enough_the_take_latches(t)
	# -- Stage D — the ending --
	_standing_on_the_seat_before_the_kill_does_nothing(t)
	_standing_on_the_seat_after_the_kill_ends_the_run(t)
	_it_opens_exactly_once_over_two_hundred_frames(t)
	_above_the_seat_does_not_end_the_run(t)
	_a_death_still_opens_it_and_reads_as_a_death(t)
	_a_downed_body_on_the_seat_reads_as_a_death_not_a_clear(t)
	_the_button_closes_the_gate_panel_and_returns_to_town(t)
	# **The town opens nothing — not duplicated here.** `at_gate` cannot be true there anyway (`want`'s own
	# `not _in_town` term short-circuits it), and `net_settlement.gd`'s own
	# `_blowing_yourself_down_in_the_town_does_not_open_it` already drives the town case end to end.


# ══════════════════════════════════════════════════════════════════
#  Stage A — the seat, the band, the wall's shape
# ══════════════════════════════════════════════════════════════════

## **The accident this guards against is on the record**: `stage.SPAWN_TILE`'s own comment describes a map
## repaint leaving a constant behind, sealing the character inside rock with nothing barking. This is that
## same check, copied in shape (not in value) from `net_town._you_land_inside_the_room_and_on_its_floor`, run against the seat instead of
## the town's spawn tile.
##
## **Measured inversion — this check alone does not pin the seat's *column*.** `SEAT_TILE_X` mutated to
## a nearby column still inside the same flat, open floor leaves this check green: that column is standing
## ground too, so "is it standing ground" cannot tell "the right tile" from "a tile on the same floor", and
## `_the_walk_from_the_room_to_the_seat_has_no_drop` below does not catch it either (its tile numbers are
## hardcoded, not read from `SEAT_TILE_X`). **What does catch it, measured**:
## `_the_arch_is_inside_the_camera_window_only_from_the_rooms_east_half` (Stage C, below) — the original
## measurement (pre-`burn-out-of-the-bull-room.md`, seat at the old x270) found a seat 14 tiles east sitting
## 308px outside the camera's own window while the real seat sat inside it. **Not re-measured at the new
## coordinates** (seat now x187) — the relationship this pins (a seat 14 tiles off is outside the window
## while the real one is inside it) is a camera-geometry fact, unaffected by where room ③ itself sits, but
## the exact 308px figure was taken on the old map and is not re-asserted here as still exact. Pinning the
## exact column was verify-look's job before that check existed; now it is a value this suite measures too.
func _the_seat_is_standing_ground_on_the_real_map(t) -> void:
	var g := CellGrid.new()
	Stage.build_terrain_into(g)
	var px := int(StageGate.seat_px() - float(Character.W_PX) * 0.5)
	var py := int(StageGate.floor_y_px()) - Character.H_PX
	var blocked := 0
	for cy in range(floori(py / float(Tuning.CELL_PX)),
			floori((py + Character.H_PX - 1) / float(Tuning.CELL_PX)) + 1):
		for cx in range(floori(px / float(Tuning.CELL_PX)),
				floori((px + Character.W_PX - 1) / float(Tuning.CELL_PX)) + 1):
			if g.is_solid(cx, cy):
				blocked += 1
	t.eq(blocked, 0, "게이트 자리에 캐릭터 상자가 통째로 들어간다 (막힌 칸 %d개)" % blocked)
	t.ok(g.is_solid(floori(px / float(Tuning.CELL_PX)),
			floori((py + Character.H_PX) / float(Tuning.CELL_PX))),
		"그 바로 아래는 바닥이다")


## **Bedrock is asserted against, not merely solidity** — the same reason `net_town`'s own wall check does
## this by material: the lock on the arch is "the flag, not the wall" being true, which only holds if the
## wall is ordinary stone and not something a blast could never touch in the first place.
func _the_east_wall_is_stone_not_bedrock(t) -> void:
	var g := CellGrid.new()
	Stage.build_terrain_into(g)
	var r := StageGate.wall_cells()
	var not_stone := 0
	for cy in range(r.position.y, r.end.y + 1):
		for cx in range(r.position.x, r.end.x + 1):
			if g.mat_at(cx, cy) != Mat.STONE:
				not_stone += 1
	t.eq(not_stone, 0,
		"동벽 전체(%d칸)가 돌이다 — 기반암이면 벽이 안 뚫려도 무너지고, 다른 재질이면 정산이 어긋난다" % [
			(r.end.x - r.position.x + 1) * (r.end.y - r.position.y + 1)])


## **Literal tile numbers, not `wall_cells()`** (verify-read, H5) — the check above and `wall_cells()` share
## one source, so shrinking `WALL_TILE_Y0`/`Y1` shrinks what gets checked along with what gets carved, and
## the rows that fall outside the new (wrong) rect are never looked at. Measured: `WALL_TILE_Y0` mutated 13
## -> 21 left eight full rows (13-20) of stone floating over the doorway with nothing red anywhere, because
## both the check above and Stage B's own drop-check read the same shrunken rect. This one hardcodes the
## design doc's own confirmed numbers (now 184/185, rows 20-31) so a shrunk rect has nothing left to hide behind.
func _the_wall_tiles_are_stone_by_literal_tile_number(t) -> void:
	var g := CellGrid.new()
	Stage.build_terrain_into(g)
	var tc := Tuning.TILE_CELLS
	var not_stone := 0
	for ty in range(20, 32):  # rows 20..31 inclusive
		for tx in [184, 185]:
			for dy in tc:
				for dx in tc:
					if g.mat_at(tx * tc + dx, ty * tc + dy) != Mat.STONE:
						not_stone += 1
	t.eq(not_stone, 0,
		"동벽 타일 184·185의 20~31번 줄 전체가 돌이다 (리터럴 타일 번호로 잰다 — 어긋난 칸 %d개)" % not_stone)


## The ground either side of the (still-standing) wall has no drop — row 32 solid, row 31 clear — so that
## once Stage B takes the wall down, the walk from the room out to the seat is flat with nothing else to fix.
##
## **x184/185 (the wall's own columns) are deliberately not in this range.** They are solid stone through row
## 31 right now (check 2, above) — asserting "row 31 clear" there as well would contradict check 2, not
## extend it. That fact belongs to Stage B's own check (`_the_walk_out_is_flat_after_the_drop`, x183..x187,
## measured *after* a real death opens the wall) — this check is the premise that everything **outside** the
## wall was already flat before that.
func _the_walk_from_the_room_to_the_seat_has_no_drop(t) -> void:
	var g := CellGrid.new()
	Stage.build_terrain_into(g)
	var tc := Tuning.TILE_CELLS
	var drop := 0
	for tx: int in [183, 186, 187]:
		var cx := tx * tc + tc / 2
		if not g.is_solid(cx, 32 * tc + tc / 2):
			drop += 1
		if g.is_solid(cx, 31 * tc + tc / 2):
			drop += 1
	t.eq(drop, 0,
		"방 안쪽 끝(183)과 벽 너머 땅(186-187)에 턱이 없다 (32번 줄 바닥·31번 줄 빈칸, 어긋난 타일 %d개)" % drop)


## `at()` must fire exactly at the seat and refuse everywhere else that matters: past the reach band, above
## the y band (the roof case an x-only test would miss), and at the town's own unrelated gate seat.
func _at_fires_only_at_the_seat_and_nowhere_else(t) -> void:
	var seat := Vector2(StageGate.seat_px(), StageGate.floor_y_px())
	t.ok(StageGate.at(seat), "자리에 서면 게이트다")
	t.ok(StageGate.at(seat + Vector2(StageGate.REACH_PX, 0.0)), "닿는 거리 끝까지는 게이트다")
	t.ok(not StageGate.at(seat + Vector2(StageGate.REACH_PX + 1.0, 0.0)), "한 걸음 더 가면 아니다")
	t.ok(not StageGate.at(seat - Vector2(StageGate.REACH_PX + 1.0, 0.0)), "반대쪽으로 한 걸음 더 가도 아니다")
	t.ok(StageGate.at(Vector2(StageGate.seat_px(), StageGate.floor_y_px() - StageGate.BAND_UP_PX)),
		"위 밴드 끝까지는 게이트다")
	t.ok(not StageGate.at(Vector2(StageGate.seat_px(), StageGate.floor_y_px() - StageGate.BAND_UP_PX - 1.0)),
		"위 밴드를 한 칸 넘으면 아니다")
	# **The roof case.** x187(아치 칸)은 0~31번 줄이 통째로 뚫려 있으므로, y밴드가 없으면 지붕 위에 떠 있어도 참이 된다.
	t.ok(not StageGate.at(Vector2(StageGate.seat_px(), 5.0 * StageGate.TILE_PX)),
		"같은 x라도 지붕 위(5번 줄)에서는 게이트가 아니다 (y밴드가 하는 일)")
	# The town's own departure-gate seat — a wholly different x, on the same predicate.
	var town_seats := TownMap.fixture_seats()
	t.ok(town_seats.has(Fixtures.KIND_GATE), "마을 출발문 자리를 읽었다 (전제)")
	if town_seats.has(Fixtures.KIND_GATE):
		t.ok(not StageGate.at(Vector2(float(town_seats[Fixtures.KIND_GATE]), StageGate.floor_y_px())),
			"마을 출발문 자리는 무대 게이트가 아니다")


## **The band is a feel value, not derived from the art** (`fixtures.REACH_PX`'s own box, copied) —
## so what is measured is the *relation*: the band must cover the drawn arch and then some, read from the
## town's own fixture table (`stage_gate.gd` itself may not read `Fx` — only the net may).
func _the_band_covers_the_drawn_arch(t) -> void:
	var row: Dictionary = Fx.TOWN_FIXTURES[Fixtures.KIND_GATE]
	var half_w: float = float(row["w"]) * Fx.TOWN_FIXTURE_ZOOM * 0.5
	var h: float = float(row["h"]) * Fx.TOWN_FIXTURE_ZOOM
	t.ok(float(StageGate.REACH_PX) >= half_w,
		"닿는 폭이 아치 그림의 반폭보다 넓다 (%d >= %.0f)" % [StageGate.REACH_PX, half_w])
	t.ok(float(StageGate.BAND_UP_PX) >= h,
		"y밴드가 아치 그림의 높이보다 넓다 (%d >= %.0f)" % [StageGate.BAND_UP_PX, h])


# ══════════════════════════════════════════════════════════════════
#  Stage B — the east wall comes down on a real rooster's death
# ══════════════════════════════════════════════════════════════════

## The premise, driven rather than assumed: before anything dies, the wall really is there.
func _the_wall_is_solid_before_anything_dies(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var g: Variant = root.get("_grid")
	var r := StageGate.wall_cells()
	t.ok(g.is_solid(r.position.x, r.position.y) and g.is_solid(r.end.x, r.end.y),
		"무엇도 죽기 전엔 동벽이 막혀 있다 (전제)")
	root.free()


## **The path that proves it, not a hand-set flag**: a real rooster is spawned, brought to 0 hp, and the
## world is pumped until the death loop's own tick actually runs (`world_step.gd`'s dead-monster pass).
func _a_real_rooster_death_opens_the_wall(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var world: Variant = root.get("_world")
	world.spawn_monster(MonsterDefs.KIND_ROOSTER, 400, 600)
	t.ok(world.monster_count() > 0, "수탉을 세웠다 (전제)")
	world.monster_at(0).hp = 0
	# TICK_DIVIDER(3) ticks per frame boundary — pump well past one to be sure a tick actually ran.
	for _i in 10:
		root.call("_physics_process", 1.0 / 60.0)
	var pr: Variant = world.call("progress")
	t.ok(bool(pr.boss_died(MonsterDefs.KIND_ROOSTER)), "수탉이 실제로 죽었다 (Progress가 안다)")
	var g: Variant = root.get("_grid")
	var r := StageGate.wall_cells()
	var still_solid := 0
	for cy in range(r.position.y, r.end.y + 1, 8):
		for cx in range(r.position.x, r.end.x + 1, 8):
			if g.is_solid(cx, cy):
				still_solid += 1
	t.eq(still_solid, 0, "수탉이 죽자 동벽이 뚫렸다 (여전히 막힌 칸 %d개)" % still_solid)
	root.free()


## **Literal tile numbers, not `wall_cells()`** (verify-read, H5 — the companion to the pre-drop literal
## check above). The production drop code (`stage.gd`'s `_on_ticked()`) also reads `wall_cells()`, so a
## shrunk `WALL_TILE_Y0`/`Y1` shrinks the carved rectangle *and* every check built on the same rect together —
## rows left outside a wrong rect stay solid and nothing sees it. This hardcodes 184/185, rows 20-31 instead.
func _the_wall_tiles_are_open_by_literal_tile_number_after_the_kill(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var world: Variant = root.get("_world")
	world.spawn_monster(MonsterDefs.KIND_ROOSTER, 400, 600)
	world.monster_at(0).hp = 0
	for _i in 10:
		root.call("_physics_process", 1.0 / 60.0)
	var g: Variant = root.get("_grid")
	var tc := Tuning.TILE_CELLS
	var still_solid := 0
	for ty in range(20, 32):
		for tx in [184, 185]:
			if g.is_solid(tx * tc + tc / 2, ty * tc + tc / 2):
				still_solid += 1
	t.eq(still_solid, 0,
		"동벽 타일 184·185의 20~31번 줄 전체가 뚫렸다 (리터럴 타일 번호로 잰다 — 여전히 막힌 타일 %d개)" % still_solid)
	root.free()


## After the drop, the walk from the room to the seat is flat — the same shape as Stage A's own check 3,
## driven through the wired scene instead of a bare grid.
func _the_walk_out_is_flat_after_the_drop(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var world: Variant = root.get("_world")
	world.spawn_monster(MonsterDefs.KIND_ROOSTER, 400, 600)
	world.monster_at(0).hp = 0
	for _i in 10:
		root.call("_physics_process", 1.0 / 60.0)
	var g: Variant = root.get("_grid")
	var tc := Tuning.TILE_CELLS
	var drop := 0
	for tx in range(183, 188):
		var cx := tx * tc + tc / 2
		if not g.is_solid(cx, 32 * tc + tc / 2):
			drop += 1
		if g.is_solid(cx, 31 * tc + tc / 2):
			drop += 1
	t.eq(drop, 0, "벽이 뚫린 뒤 room3에서 자리까지 걸어 나가는 길이 평평하다 (어긋난 타일 %d개)" % drop)
	root.free()


## **R restores both** — the wall's own material and the latch. Only `reset_stage()` writes the latch, and
## it always rebuilds the terrain in the same call, so the two cannot disagree.
func _r_restores_the_wall_and_the_latch(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var world: Variant = root.get("_world")
	world.spawn_monster(MonsterDefs.KIND_ROOSTER, 400, 600)
	world.monster_at(0).hp = 0
	for _i in 10:
		root.call("_physics_process", 1.0 / 60.0)
	var g: Variant = root.get("_grid")
	var r := StageGate.wall_cells()
	t.ok(not g.is_solid(r.position.x, r.position.y), "벽이 뚫린 상태다 (전제)")

	root.call("reset_stage")
	t.ok(not bool(root.get("_room3_gate_open")), "R을 누르면 걸쇠가 풀린다")
	g = root.get("_grid")
	var not_stone := 0
	for cy in range(r.position.y, r.end.y + 1, 8):
		for cx in range(r.position.x, r.end.x + 1, 8):
			if g.mat_at(cx, cy) != Mat.STONE:
				not_stone += 1
	t.eq(not_stone, 0, "R을 누르면 동벽이 다시 돌로 막힌다 (어긋난 칸 %d개)" % not_stone)
	root.free()


## **A process measurement, not a final-state one** — CLAUDE.md's own warning that a settle loop or a
## per-tick refill cannot be seen by looking only at the end. One wall cell is put back by hand after the
## drop, and 60 more frames (20 ticks) are pumped: a block without the `_room3_gate_open` guard would erase
## it again on the very next tick, and only watching the process catches that.
func _the_wall_does_not_refill_every_tick(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var world: Variant = root.get("_world")
	world.spawn_monster(MonsterDefs.KIND_ROOSTER, 400, 600)
	world.monster_at(0).hp = 0
	for _i in 10:
		root.call("_physics_process", 1.0 / 60.0)

	var g: Variant = root.get("_grid")
	var r := StageGate.wall_cells()
	t.ok(not g.is_solid(r.position.x, r.position.y), "벽이 뚫린 상태다 (전제)")
	g.apply(CellGrid.cmd_fill(r.position.x, r.position.y, r.position.x, r.position.y, Mat.STONE))
	t.eq(g.mat_at(r.position.x, r.position.y), Mat.STONE, "한 칸을 손으로 돌려놨다 (전제)")

	for _i in 60:
		root.call("_physics_process", 1.0 / 60.0)
	t.eq(g.mat_at(r.position.x, r.position.y), Mat.STONE,
		"걸쇠 없이 매 틱 다시 부수는 블록이었다면 이 칸이 다시 빈칸이 됐을 것이다 — 여전히 돌이다")
	root.free()


# ══════════════════════════════════════════════════════════════════
#  Stage C — the arch on screen
# ══════════════════════════════════════════════════════════════════

## **`visible` itself, not a helper** — the exact trap the settlement panel fell into: `is_showing()` true,
## `visible` never set, 5,576 green checks and nothing on screen. `_process` is called by hand (untreed nodes
## never tick on their own), the same idiom every other window here uses.
func _the_arch_is_invisible_before_the_kill_and_visible_after(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var gate_view: Variant = root.get("_gate_view")
	gate_view.call("_process", 0.0)
	t.ok(not bool(gate_view.visible), "수탉이 죽기 전엔 아치가 안 보인다")

	var pr: Variant = (root.get("_world") as Object).call("progress")
	pr.set_boss_reward_pending(MonsterDefs.KIND_ROOSTER)
	gate_view.call("_process", 0.0)
	t.ok(bool(gate_view.visible), "수탉이 죽으면(boss_died) 아치가 보인다")
	root.free()


## `GateView.rect()` pinned to the exact number the design doc derives by hand (`seat_px() - w/2`,
## `floor_y_px() - h`, `w/h` from the town's own fixture table x2 zoom) — 72x88 at (5964, 936).
## **Moved with the seat and the floor** (`burn-out-of-the-bull-room.md` §1/§3): seat tile 270 -> 187 puts
## `seat_px()` at 6000, minus half the 72px width = 5964; floor tile 25 -> 32 puts `floor_y_px()` at 1024,
## minus the 88px height = 936.
func _the_drawn_rect_is_where_the_arch_belongs(t) -> void:
	var r := GateView.rect()
	t.eq(r, Rect2(5964.0, 936.0, 72.0, 88.0), "아치 사각형이 정확히 그 자리다 (72x88 at 5964,936)")
	t.eq(r.end.y, StageGate.floor_y_px(), "아치의 밑변이 바닥선과 정확히 같다 (뜨지도 파묻히지도 않는다)")


## `reset_stage()` leaves the room in town by default (`_in_town` starts `true`), where `boss_died` is false
## by construction (`Progress.reset()` -> `_reward_pending.clear()`) — this is that fact driven as a value,
## not assumed from reading the reset chain.
func _the_arch_is_invisible_in_town(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	var gate_view: Variant = root.get("_gate_view")
	gate_view.call("_process", 0.0)
	t.ok(bool(root.get("_in_town")), "마을에서 시작한다 (전제)")
	t.ok(not bool(gate_view.visible), "마을에서는 아치가 안 보인다")
	root.free()


## **`_draw()` actually runs, measured — not `t.ok(true, ...)`.** `net_frame_runner.gd`'s own technique
## (a counting subclass, treed, frames pumped) applied to the real `GateView` class via `super()`, rather
## than a stand-in — a decoy counter could stay green while the production `_draw()` silently did nothing.
func _draw_actually_runs_once_treed_and_pumped(t) -> void:
	# **A real `Progress` with the flag already set** — not a manual `visible = true`. `GateView`'s own
	#  `_process()` runs every frame once treed, unconditionally, and would otherwise flip a hand-set
	#  `visible` straight back to `false` the moment the engine ticks (measured: it did, on the first attempt
	#  at this check — draw_count froze at 1 forever). Driving `boss_died` for real exercises the same path
	#  `_process()` uses in the game, which is the more faithful measurement anyway.
	var pr := Progress.new()
	pr.set_boss_reward_pending(MonsterDefs.KIND_ROOSTER)
	var view := _CountingGateView.new()
	view.setup(pr)
	t.root.add_child(view)
	await t.pump_frames(3)
	var first := view.draw_count
	t.ok(first > 0, "트리에 넣고 프레임을 돌리면 아치의 _draw()가 실제로 돈다 (%d회)" % first)

	await t.pump_frames(3)
	t.ok(view.draw_count > first,
		"프레임을 더 돌리면 다시 돈다 (%d -> %d, 최초 1회 우연이 아니다)" % [first, view.draw_count])

	t.root.remove_child(view)
	view.queue_free()


## **What `_CountingGateView` above cannot see (verify-read, H2)**: whether `_draw()`, once it runs, actually
## paints the arch — not merely that the engine invoked it. `_CapturingGateView` shadows `draw_texture_rect`
## itself, so the exact texture and rect `GateView._draw()` hands the engine is caught here instead of lost
## inside the native call. No tree, no pumping needed — `_draw()` is called directly, the same way this
## file's other pure-function checks call static methods with no scene.
func _the_draw_call_actually_paints_the_arch_texture_at_its_rect(t) -> void:
	var view := _CapturingGateView.new()
	view.call("_draw")
	t.eq(view.calls, 1, "_draw()가 draw_texture_rect를 정확히 한 번 부른다")
	t.ok(view.last_texture != null, "그리고 실제 텍스처를 넘긴다 (null이 아니다)")
	t.eq(view.last_rect, GateView.rect(), "그리고 정확히 아치의 자리(rect())에 그린다")
	# **The modulate comes from the counters, not from a literal white** — a fresh view has both at 0, so the
	#  arch starts fully transparent. Hardcode `Color.WHITE` in `_draw()` and this is the line that goes red.
	t.eq(view.last_tint, GateView.tint(0, 0), "그리고 색조를 두 시계에서 뽑아 넘긴다 (흰색 상수가 아니다)")
	t.eq(view.last_tint.a, 0.0, "아직 한 프레임도 안 흘렀으니 완전 투명이다 (튀어나오지 않는다)")
	view.free()


## **Beats 2 and 3 as a pure curve, walked by value** — no scene, no tree. The three points that carry the
## whole shape: nothing at the start, fully opaque once the fade is done, and exactly the flare colour once
## the take is done.
func _the_tint_curve_walks_from_transparent_to_opaque_to_the_flare(t) -> void:
	t.eq(GateView.tint(0, 0).a, 0.0, "죽은 직후 0프레임째엔 아치가 완전 투명이다 (튀어나오지 않는다)")
	t.eq(GateView.tint(Fx.GATE_ARCH_FADE_FRAMES, 0).a, 1.0,
		"%d프레임이면 완전히 떠오른다" % Fx.GATE_ARCH_FADE_FRAMES)
	t.ok(GateView.tint(Fx.GATE_ARCH_FADE_FRAMES / 2, 0).a > 0.0
			and GateView.tint(Fx.GATE_ARCH_FADE_FRAMES / 2, 0).a < 1.0,
		"중간엔 중간값이다 (0에서 1로 한 프레임에 건너뛰지 않는다)")
	t.eq(GateView.tint(Fx.GATE_ARCH_FADE_FRAMES, Fx.GATE_TAKE_FRAMES), Fx.GATE_TAKE_TINT,
		"데려가기가 끝나면 정확히 GATE_TAKE_TINT다 (아치가 밝아진다)")
	# **Clamped past the end** — `_take` keeps climbing while the panel is open (nothing stops it until
	#  `reset_gate()`), so the curve must not run past the flare into nonsense.
	t.eq(GateView.tint(Fx.GATE_ARCH_FADE_FRAMES * 4, Fx.GATE_TAKE_FRAMES * 4), Fx.GATE_TAKE_TINT,
		"한참 더 흘려도 그 색에 머문다 (넘어가지 않는다)")


## **The curve through a real node, not only the pure function** (`stage-clear-sequence.md`, step 6).
## Without this, `_paint_arch(_tex, rect(), Color.WHITE)` hardcoded in `_draw()` leaves the pure-function
## check above entirely green — the value would be measured and the wiring would not.
##
## The hand-called `_draw()` is safe here **only because `_paint_arch` is `_draw()`'s one drawing call** and
## this subclass overrides it, so nothing native runs (this file's own `_CapturingGateView` header records
## what happens when that stops being true).
func _the_drawn_tint_is_the_one_the_counters_decided(t) -> void:
	var pr := Progress.new()
	pr.set_boss_reward_pending(MonsterDefs.KIND_ROOSTER)
	var view := _CapturingGateView.new()
	view.setup(pr)

	# **Half the fade, so neither end of the curve can be mistaken for the answer** — at a full
	#  `GATE_ARCH_FADE_FRAMES` the alpha is 1.0, which is also what a hardcoded white would give.
	var n := Fx.GATE_ARCH_FADE_FRAMES / 2
	for _i in n:
		view.call("tick_gate", true)
	t.eq(view.call("lit_frames"), n, "tick_gate()를 %d번 부르면 밝기 시계가 %d이다 (전제)" % [n, n])
	t.eq(view.call("take_frames"), n, "데려가기 시계도 같이 %d이다 (전제)" % n)

	view.call("_draw")
	t.eq(view.calls, 1, "_draw()가 아치를 한 번 그린다 (전제)")
	t.eq(view.last_tint, GateView.tint(n, n),
		"그리고 실제로 넘기는 색조가 두 시계가 정한 그 값이다 (흰색을 박아넣으면 여기가 빨개진다)")
	t.eq(view.last_rect, GateView.rect(), "자리는 그대로다 (색조만 움직인다)")
	view.free()


## **A real value, not "the band covers it"** — the same camera formula the game itself uses
## (`Stage.camera_center`/`Fx.CAM_LEAD_PX`), read rather than reproduced as a new constant. Viewport size is
## read from `ProjectSettings`, the same source `stage.gd._process` itself reads at runtime — a resized
## window is what this avoids silently going stale against.
##
## **Measured, not assumed: this is what makes `SEAT_TILE_X` actually matter.** Mutating it to a column 14
## tiles east (still inside the plan's own "check 1 alone is not enough" example) was tried by hand against
## this exact check, on the map as it stood then (`burn-out-of-the-bull-room.md` has since moved room ③) —
## the arch there sat 308px outside the window computed below while the real seat sat inside it, confirming
## the camera table (not the standing-ground check) is what would catch a seat moved elsewhere on the same floor.
##
## **Not "visible from anywhere in the room" — that claim is false and is not made here.** Room ③'s interior
## (640px) is wider than the half-screen (480px), so the arch only enters the window from the room's own east
## half while the camera leads toward it; retreating (lead the other way) pushes it back out. Both are
## ordinary camera behaviour, and the check below is written to exactly that, not to a stronger claim.
func _the_arch_is_inside_the_camera_window_only_from_the_rooms_east_half(t) -> void:
	var view_size := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height"))) / Stage.ZOOM_STEPS[0]
	var world := Stage.world_size()
	var arch := GateView.rect()
	var lead := Fx.CAM_LEAD_PX
	# **The character's own standing height, not y=0** — a camera check at the world's top edge measures
	#  nothing about this room. Room ③'s floor is `StageGate.floor_y_px()`; a standing character's centre
	#  sits half its own height above that, the same box `character.gd` itself stands on the ground with.
	var stand_y := StageGate.floor_y_px() - float(Character.H_PX) * 0.5

	# Room ③'s own centre tile, leaning into the gate (lead settled at +CAM_LEAD_PX): the arch is on screen.
	var room_mid_x := (float(ROOM3_INTERIOR_X0) + float(ROOM3_INTERIOR_X1)) * 0.5 * StageGate.TILE_PX
	var window_in := Rect2(
		Stage.camera_center(Vector2(room_mid_x + lead, stand_y), view_size, world) - view_size * 0.5, view_size)
	t.ok(window_in.encloses(arch),
		"③방 한가운데서 문 쪽으로 리드가 붙으면(+%.0fpx) 아치(%s)가 화면(%s) 안이다" % [lead, arch, window_in])

	# The same spot, leading away (retreating): the window slides off the gate.
	var window_out := Rect2(
		Stage.camera_center(Vector2(room_mid_x - lead, stand_y), view_size, world) - view_size * 0.5, view_size)
	# **This used to assert the arch left the screen entirely, and that was a claim about `CAM_LEAD_PX`'s
	#  *size*, not about the lead working.** At 72 it happened to be true; the user cut the lead to 32
	#  (「방향에 따라 카메라 이동하는 거 좀 줄여줘」) and it stopped being true, with nothing about the gate
	#  having changed. ⇒ **The direction is what this measures now**: retreating pushes the arch further from
	#  the middle of the screen than approaching does. That holds at any lead above zero and goes red the
	#  moment the lead is applied with the wrong sign — which is the actual defect worth catching.
	var to_arch_in := absf(window_in.get_center().x - arch.get_center().x)
	var to_arch_out := absf(window_out.get_center().x - arch.get_center().x)
	t.ok(to_arch_out > to_arch_in,
		"같은 자리에서 반대로 리드가 붙으면(도망) 아치가 화면 중앙에서 더 멀어진다 (%.0f > %.0f)"
			% [to_arch_out, to_arch_in])

	# The room's own west half, even leaning toward the gate, still does not reach — the room (640px) is
	#  wider than the half-screen (480px).
	var room_west_x := float(ROOM3_INTERIOR_X0 + 3) * StageGate.TILE_PX
	var window_west := Rect2(
		Stage.camera_center(Vector2(room_west_x + lead, stand_y), view_size, world) - view_size * 0.5, view_size)
	t.ok(not window_west.intersects(arch), "방 서쪽 절반에서는 문 쪽으로 리드가 붙어도 아치가 아직 화면 밖이다")


# ══════════════════════════════════════════════════════════════════
#  Stage D — the ending
# ══════════════════════════════════════════════════════════════════

## **Also acceptance "tunnelling east early"**: nothing here cares whether a real wall stands between the
## room and the seat — the character is placed directly on it, the same generalized case as blasting a hole
## through the still-standing wall and walking around. No flag, no ending, wall or no wall.
func _standing_on_the_seat_before_the_kill_does_nothing(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var ch: Variant = root.get("_char")
	ch.place(int(StageGate.seat_px() - float(Character.W_PX) * 0.5), int(StageGate.floor_y_px()) - Character.H_PX)
	root.call("_physics_process", 1.0 / 60.0)
	var settlement: Variant = root.get("_settlement")
	t.ok(not bool(settlement.call("is_showing")),
		"수탉이 죽기 전엔 자리에 서 있어도 정산 화면이 안 열린다 (깃발이 없다)")
	root.free()


func _standing_on_the_seat_after_the_kill_ends_the_run(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var world: Variant = root.get("_world")
	world.spawn_monster(MonsterDefs.KIND_ROOSTER, 400, 600)
	world.monster_at(0).hp = 0
	for _i in 10:
		root.call("_physics_process", 1.0 / 60.0)
	var ch: Variant = root.get("_char")
	ch.place(int(StageGate.seat_px() - float(Character.W_PX) * 0.5), int(StageGate.floor_y_px()) - Character.H_PX)
	# **`GATE_TAKE_FRAMES` frames, derived — never a literal** (`stage-clear-sequence.md`, Beat 3). The arch
	#  now takes ~0.4s instead of opening the panel on the first frame of contact. Which frame exactly is
	#  `_the_panel_opens_on_exactly_the_take_frames_th_frame` below; this one only needs it to have opened.
	for _i in Fx.GATE_TAKE_FRAMES:
		root.call("_physics_process", 1.0 / 60.0)
	var settlement: Variant = root.get("_settlement")
	t.ok(bool(settlement.call("is_showing")), "수탉이 죽은 뒤 자리에 서면 정산 화면이 연다")
	t.ok(bool(settlement.visible), "그리고 실제 Control.visible도 켜진다")
	t.ok(bool(settlement.get("_cleared")), "그리고 클리어로 기록된다")
	root.free()


## **A process measurement, not a final-state one** — the window's own `_frames` (its count-up clock, reset
## only by `open()`) is what a re-open would show moving backward. Final state alone cannot see "it opened a
## second time and reset the clock"; 200 frames stood still on the seat is what forces the process to show it.
func _it_opens_exactly_once_over_two_hundred_frames(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var world: Variant = root.get("_world")
	world.spawn_monster(MonsterDefs.KIND_ROOSTER, 400, 600)
	world.monster_at(0).hp = 0
	for _i in 10:
		root.call("_physics_process", 1.0 / 60.0)
	var ch: Variant = root.get("_char")
	ch.place(int(StageGate.seat_px() - float(Character.W_PX) * 0.5), int(StageGate.floor_y_px()) - Character.H_PX)
	# **The drive changes; the 200 does not.** The take delay means the panel no longer opens on the frame the
	#  character is placed — it opens on the **last** of these `GATE_TAKE_FRAMES` frames, and `_frames` becomes
	#  1 inside that one exactly as it used to, so the 199-frame loop below still lands on 200.
	# **Deliberately not a new expected value.** An earlier draft of the plan predicted `176`, which is unsound:
	#  increment-then-test gives 177 and test-then-increment 176, and hardcoding either is the same brittle
	#  equality this check already broke on once.
	for _i in Fx.GATE_TAKE_FRAMES:
		root.call("_physics_process", 1.0 / 60.0)
	var settlement: Variant = root.get("_settlement")
	t.ok(bool(settlement.call("is_showing")), "정산 화면이 열렸다 (전제)")
	for _i in 199:
		root.call("_physics_process", 1.0 / 60.0)
	t.eq(int(settlement.get("_frames")), 200,
		"200프레임을 자리에 서서 흘려도 한 번만 연다 (다시 열렸다면 _frames가 200이 아니다)")
	root.free()


## The roof case, through the real wired scene and real physics — the same x column the arch sits in has no
## ceiling from row 0 to row 24, so an x-only test would end the run here. The y band is what refuses it.
func _above_the_seat_does_not_end_the_run(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var world: Variant = root.get("_world")
	world.spawn_monster(MonsterDefs.KIND_ROOSTER, 400, 600)
	world.monster_at(0).hp = 0
	for _i in 10:
		root.call("_physics_process", 1.0 / 60.0)
	var ch: Variant = root.get("_char")
	ch.place(int(StageGate.seat_px() - float(Character.W_PX) * 0.5), 5 * Tuning.TILE_CELLS * Tuning.CELL_PX)
	root.call("_physics_process", 1.0 / 60.0)
	var settlement: Variant = root.get("_settlement")
	t.ok(not bool(settlement.call("is_showing")),
		"같은 x라도 지붕 위(5번 줄)에 있으면 정산 화면이 안 열린다 (y밴드가 하는 일)")
	root.free()


## The existing death path must still read as a death — `net_settlement`'s own checks stay green untouched,
## and this only pins the new `_cleared` term on that same path.
func _a_death_still_opens_it_and_reads_as_a_death(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var ch: Variant = root.get("_char")
	ch.take_hit(Character.MAX_HP, false)
	root.call("_physics_process", 1.0 / 60.0)
	var settlement: Variant = root.get("_settlement")
	t.ok(bool(settlement.call("is_showing")), "쓰러지면 정산 화면이 연다 (전제)")
	t.ok(not bool(settlement.get("_cleared")), "그리고 죽음으로 기록된다 (클리어가 아니다)")
	root.free()


## **The tie rule, decided by the user: a death wins.** Downed *and* on the seat in the same frame — the
## fourth argument to `open()` (`at_gate and not _char.downed`) must read false.
func _a_downed_body_on_the_seat_reads_as_a_death_not_a_clear(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var world: Variant = root.get("_world")
	world.spawn_monster(MonsterDefs.KIND_ROOSTER, 400, 600)
	world.monster_at(0).hp = 0
	for _i in 10:
		root.call("_physics_process", 1.0 / 60.0)
	var ch: Variant = root.get("_char")
	ch.place(int(StageGate.seat_px() - float(Character.W_PX) * 0.5), int(StageGate.floor_y_px()) - Character.H_PX)
	ch.take_hit(Character.MAX_HP, false)
	t.ok(bool(ch.downed), "자리에 선 채로 쓰러졌다 (전제)")
	root.call("_physics_process", 1.0 / 60.0)
	var settlement: Variant = root.get("_settlement")
	t.ok(bool(settlement.call("is_showing")), "정산 화면이 연다 (전제)")
	t.ok(not bool(settlement.get("_cleared")), "쓰러진 채 자리에 있으면 죽음이 이긴다 (클리어가 아니다)")
	root.free()


## **The anti-strand check.** Both new terms must collapse on their own the instant the button runs
## `enter_town()` — the flag (`Progress.reset()`) and the character's own position (`_char.place()` moves it
## 11,760px off the seat), so nothing here has to notice which one closed the panel.
func _the_button_closes_the_gate_panel_and_returns_to_town(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var world: Variant = root.get("_world")
	world.spawn_monster(MonsterDefs.KIND_ROOSTER, 400, 600)
	world.monster_at(0).hp = 0
	for _i in 10:
		root.call("_physics_process", 1.0 / 60.0)
	var ch: Variant = root.get("_char")
	ch.place(int(StageGate.seat_px() - float(Character.W_PX) * 0.5), int(StageGate.floor_y_px()) - Character.H_PX)
	for _i in Fx.GATE_TAKE_FRAMES:
		root.call("_physics_process", 1.0 / 60.0)
	var settlement: Variant = root.get("_settlement")
	t.ok(bool(settlement.call("is_showing")), "정산 화면이 열렸다 (전제)")

	var gate_view: Variant = root.get("_gate_view")
	t.ok(int(gate_view.call("take_frames")) > 0, "돌아가기 전엔 데려가기 시계가 돌아 있었다 (전제)")
	t.ok(int(gate_view.call("lit_frames")) > 0, "밝기 시계도 돌아 있었다 (전제)")

	root.call("enter_town")
	t.ok(not bool(settlement.call("is_showing")), "버튼(enter_town)을 실행하면 정산 화면이 닫힌다")
	t.ok(bool(root.get("_in_town")), "그리고 마을로 돌아온다")
	var pr: Variant = world.call("progress")
	t.ok(not bool(pr.boss_died(MonsterDefs.KIND_ROOSTER)), "그리고 깃발도 지워진다 (다음 런이 갇히지 않는다)")
	# **두 시계가 다 지워진다** (`stage-clear-sequence.md`, acceptance 8). `_lit`이 살아남는 건 꾸밈이 아니다 —
	#  다음 런에서 아치가 한 프레임에 완전 불투명으로 튀어나오고, 다른 검사는 전부 초록으로 남는다.
	t.eq(gate_view.call("take_frames"), 0, "그리고 데려가기 시계가 0으로 지워진다")
	t.eq(gate_view.call("lit_frames"), 0, "밝기 시계도 같이 0으로 지워진다 (다음 런에서 아치가 안 튀어나온다)")
	gate_view.call("_process", 0.0)
	t.ok(not bool(gate_view.visible), "그리고 아치도 화면에서 사라진다")
	root.free()


## **Beat 1 — the wall coming down kicks the camera, and it settles back on its own.**
## Two different claims, and a single non-zero reading would only make the first: "it shook" and "it stops
## shaking" are measured separately, the same split `blast_fx`'s own shake checks already hold.
##
## `advance()` is driven by hand because `_wired_root` never trees the root, so `blast_fx._process` — the only
## thing that would otherwise pass time — never runs. That is what leaves the kick sitting untouched here.
func _the_wall_falling_kicks_the_camera_and_it_settles_back(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var blast_fx: Variant = root.get("_blast_fx")
	t.eq(blast_fx.call("shake_offset"), Vector2i.ZERO, "수탉이 죽기 전엔 화면이 안 흔들린다 (전제)")

	var world: Variant = root.get("_world")
	world.spawn_monster(MonsterDefs.KIND_ROOSTER, 400, 600)
	world.monster_at(0).hp = 0
	for _i in 10:
		root.call("_physics_process", 1.0 / 60.0)
	t.ok(bool(world.call("progress").boss_died(MonsterDefs.KIND_ROOSTER)), "수탉이 죽었다 (전제)")

	blast_fx.call("advance", 0.01)
	t.ok(blast_fx.call("shake_offset") != Vector2i.ZERO,
		"동벽이 무너지자 화면이 실제로 흔들린다 (얻은 값 %s)" % blast_fx.call("shake_offset"))

	blast_fx.call("advance", Fx.GATE_WALL_SHAKE_SECS + 0.1)
	t.eq(blast_fx.call("shake_offset"), Vector2i.ZERO, "그리고 제 시간이 지나면 스스로 멎는다 (계속 안 떤다)")

	# **And it stays stopped — the kick fires once, measured instead of argued** (verify-read).
	#  The plan's Bounds says "the shake fires once, off `_room3_gate_open`'s existing latch — a per-tick
	#  re-kick is structurally impossible here." True today, and **nothing measured it**: moving `kick()`
	#  out of that `if` block so it fires every physics frame leaves the camera shaking for the rest of the
	#  run and **all 433 checks green.** The two asserts above cannot see it — they only ever `advance()`,
	#  and `_wired_root` never trees the root, so no `_physics_process` runs between them. That is
	#  CLAUDE.md's "a check that reads only final state cannot measure a repetition contract".
	#  **`TICK_DIVIDER * 2` frames, not one — and the one-frame version of this check did not bite.**
	#  `_on_ticked()` runs only when `_world.frame()` returns true, which is once every `TICK_DIVIDER`(3)
	#  physics frames, so a single `_physics_process` crosses a tick boundary at most one time in three —
	#  and in this check's phase, none. The re-kick mutation ran with **437 green** against the one-frame
	#  version. This file's own `TICK_DIVIDER` comment already wrote the rule ("pump well past one to be sure a tick
	#  actually ran"); it was not followed here the first time.
	for _i in Tuning.TICK_DIVIDER * 2:
		root.call("_physics_process", 1.0 / 60.0)
	blast_fx.call("advance", 0.01)
	t.eq(blast_fx.call("shake_offset"), Vector2i.ZERO,
		"틱을 여러 번 더 돌려도 다시 안 흔들린다 (빗장 안이라 딱 한 번만 찬다 — 매 틱 다시 차면 영영 안 멎는다)")

	# **The strength is held to its own stated reason, not just to "non-zero"** (verify-read).
	#  `GATE_WALL_SHAKE_PX = 1` was fully green: the asserts above only ask whether it moved at all.
	#  The constant's own comment is "larger than any blast in `FX_SIZES` — a twelve-tile stone wall, once",
	#  so that is what is asked here, against the table it names rather than against a second literal.
	var biggest_blast := 0
	for row: Dictionary in Fx.FX_SIZES:
		biggest_blast = maxi(biggest_blast, int(row["shake_px"]))
	t.ok(biggest_blast > 0, "폭발 흔들림 표를 읽었다 (전제 — %d)" % biggest_blast)
	t.ok(Fx.GATE_WALL_SHAKE_PX > biggest_blast,
		"동벽이 무너지는 흔들림(%d)이 어떤 폭발(%d)보다도 크다 — 열두 타일짜리 돌벽은 볼트가 아니다"
			% [Fx.GATE_WALL_SHAKE_PX, biggest_blast])
	root.free()


## **The shell actually turns the take clock** (`stage-clear-sequence.md`, step 7). Every other take check
## could pass with `tick_gate()`'s call site deleted from `_sync_settlement()`, because the view checks above
## drive `tick_gate()` by hand. This is the one that reads the shell's own line.
func _the_shell_actually_turns_the_take_clock(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var world: Variant = root.get("_world")
	world.spawn_monster(MonsterDefs.KIND_ROOSTER, 400, 600)
	world.monster_at(0).hp = 0
	for _i in 10:
		root.call("_physics_process", 1.0 / 60.0)
	var gate_view: Variant = root.get("_gate_view")
	t.eq(gate_view.call("take_frames"), 0, "자리에 서기 전엔 데려가기 시계가 0이다 (전제)")
	t.ok(int(gate_view.call("lit_frames")) > 0, "그런데 밝기 시계는 죽은 순간부터 이미 돌고 있다")

	var ch: Variant = root.get("_char")
	ch.place(int(StageGate.seat_px() - float(Character.W_PX) * 0.5), int(StageGate.floor_y_px()) - Character.H_PX)
	root.call("_physics_process", 1.0 / 60.0)
	t.eq(gate_view.call("take_frames"), 1,
		"자리에 서서 물리 프레임 하나를 돌리면 무대가 실제로 시계를 1로 올린다 (_sync_settlement()의 tick_gate() 호출)")
	root.free()


## **The exact opening frame, counted — not "it eventually opens"** (`stage-clear-sequence.md`, step 8).
##
## **Derived from the constant, plus a literal floor.** The equality pins that the code obeys the tuning
## value; the floor pins the tuning value itself, so shrinking `GATE_TAKE_FRAMES` to 1 or 2 — which would
## delete beat 3 outright while leaving every other check here green — goes red.
func _the_panel_opens_on_exactly_the_take_frames_th_frame(t) -> void:
	t.ok(Fx.GATE_TAKE_FRAMES >= 12,
		"데려가기가 최소 12프레임(0.2초)은 된다 — 상수 자체가 1~2로 줄면 여기가 빨개진다 (얻은 값 %d)"
			% Fx.GATE_TAKE_FRAMES)
	# **The same floor for the fade, and it was missing** (verify-read, an adversarial pass by an agent that
	#  did not build this feature). `GATE_ARCH_FADE_FRAMES = 2` was **fully green — 433 passed** — and beat 2
	#  is then a 2-frame pop (0.033s), which is exactly the "pops from nothing to fully opaque in one frame"
	#  the beat exists to remove.
	#  **`= 1` does bite, but only by accident**, and the accident is worth naming so nobody reads it as
	#  coverage: the curve check below probes `GATE_ARCH_FADE_FRAMES / 2`, which integer-divides to 0 at 1,
	#  so its "the middle is a middle value" assert reads `tint(0, 0)` and fails. **The real hole was 2–11.**
	t.ok(Fx.GATE_ARCH_FADE_FRAMES >= 12,
		"떠오르기도 최소 12프레임은 된다 — 2~11이면 팝이고, 그 구간은 전부 초록이었다 (얻은 값 %d)"
			% Fx.GATE_ARCH_FADE_FRAMES)

	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var world: Variant = root.get("_world")
	world.spawn_monster(MonsterDefs.KIND_ROOSTER, 400, 600)
	world.monster_at(0).hp = 0
	for _i in 10:
		root.call("_physics_process", 1.0 / 60.0)
	var ch: Variant = root.get("_char")
	ch.place(int(StageGate.seat_px() - float(Character.W_PX) * 0.5), int(StageGate.floor_y_px()) - Character.H_PX)
	var settlement: Variant = root.get("_settlement")
	t.ok(not bool(settlement.call("is_showing")), "자리에 막 섰을 뿐, 아직 안 열렸다 (전제)")

	# 1-based: the first frame inside the band is frame 1, which is what "increment first, then test" means.
	var opened_on := -1
	var stepped := 0
	for i in range(Fx.GATE_TAKE_FRAMES * 2):
		root.call("_physics_process", 1.0 / 60.0)
		stepped += 1
		if opened_on < 0 and bool(settlement.call("is_showing")):
			opened_on = i + 1
	t.eq(stepped, Fx.GATE_TAKE_FRAMES * 2, "루프가 실제로 %d프레임을 돌았다 (전제)" % (Fx.GATE_TAKE_FRAMES * 2))
	t.eq(opened_on, Fx.GATE_TAKE_FRAMES,
		"정확히 %d번째 프레임에 정산 화면이 열린다 (첫 프레임에 삼키지 않는다)" % Fx.GATE_TAKE_FRAMES)
	root.free()


## **The latch — measured as what survives the player leaving** (`stage-clear-sequence.md`, step 9).
## At `MOVE_SPEED_PX` 260 a running player crosses the 96px band in ~22 frames, so a resettable hold near
## `GATE_TAKE_FRAMES` would simply never complete and the ending would never fire. One frame of contact must
## be enough.
##
## **Moved to `Stage.SPAWN_TILE`, not "the seat plus 400px"** — the one tile the shell itself guarantees is
## standing ground (`_build_room()` stands the character there). A guessed offset east of a seat whose column
## has already moved once is a fall waiting to happen, and a fall would fail this check for a reason that has
## nothing to do with the latch — which is why `not downed` is asserted as an explicit premise below.
func _one_frame_on_the_seat_is_enough_the_take_latches(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var world: Variant = root.get("_world")
	world.spawn_monster(MonsterDefs.KIND_ROOSTER, 400, 600)
	world.monster_at(0).hp = 0
	for _i in 10:
		root.call("_physics_process", 1.0 / 60.0)
	var ch: Variant = root.get("_char")
	ch.place(int(StageGate.seat_px() - float(Character.W_PX) * 0.5), int(StageGate.floor_y_px()) - Character.H_PX)
	root.call("_physics_process", 1.0 / 60.0)

	var settlement: Variant = root.get("_settlement")
	t.ok(not bool(settlement.call("is_showing")), "한 프레임만으로는 아직 안 열린다 (전제)")

	# Off the seat entirely, onto the stage's own spawn tile — the run is now outrunning the take.
	ch.place(Stage.SPAWN_TILE.x * Tuning.TILE_CELLS * Tuning.CELL_PX,
		Stage.SPAWN_TILE.y * Tuning.TILE_CELLS * Tuning.CELL_PX)
	t.ok(not StageGate.at(ch.center()), "이제 자리에서 완전히 벗어났다 (전제)")

	for _i in Fx.GATE_TAKE_FRAMES:
		root.call("_physics_process", 1.0 / 60.0)
	t.ok(not bool(ch.downed), "가는 동안 쓰러지지 않았다 (전제 — 쓰러졌다면 아래가 빗장이 아니라 낙사로 빨개진다)")
	t.ok(bool(settlement.call("is_showing")),
		"자리에 한 프레임만 닿아도 끝까지 간다 (빗장 — 안 그러면 뛰어가는 플레이어는 엔딩을 영영 못 본다)")
	t.ok(bool(settlement.get("_cleared")), "그리고 클리어로 기록된다 (자리를 떠났어도 죽음이 아니다)")
	root.free()


## **The same wiring `net_town._wired_root` does, copied rather than shared** — each net runs in its own
## process, so there is no shared base class (`net_town.gd`'s own header states the policy).
##
## **`if root == null: return` in every caller is a structural "checks disappear, not fail" shape**
## (verify-read). Measured directly: removing `settlement_window.open()`'s fourth argument from a call site
## turns that one line into a parse error, and every check in the file that runs *after* the failed
## `_wired_root()` call in source order is skipped — the run reported "267 passed, 0 failed" for a file that
## should have run 305. The `[래퍼]`'s stderr rule caught it that time (a parse error prints to stderr), so it
## did not slip through — but `run_nets.gd`'s own "0 checks ran" guard only catches a net that runs
## *nothing at all*, not one that quietly runs fewer checks than it should. This is not a bug to fix here —
## it is the reason every `_wired_root(t)` call in this file is followed by `if root == null: return`
## immediately, and the reason a check count dropping between runs (not just going red) is itself a signal.
func _wired_root(t) -> Node:
	var scene: PackedScene = load(STAGE_SCENE)
	t.ok(scene != null and scene.can_instantiate(), "무대 씬을 세웠다 (전제)")
	if scene == null or not scene.can_instantiate():
		return null
	var root := scene.instantiate()
	for pair: Array in [["_hud", "HUD/Stats"], ["_hp_view", "HUD/HpBar"],
			["_levelup_label", "HUD/LevelUp"],
			["_spell_view", "SpellView"], ["_blast_fx", "BlastFx"],
			["_circle_window", "HUD/CircleWindow"], ["_pick_window", "HUD/ThreePickWindow"],
			["_camera", "Camera2D"], ["_monster_view", "MonsterView"],
			["_renderer", "CellRenderer"], ["_town_view", "TownView"], ["_input", "StageInput"],
			["_sky", "SkyBackground"],
			["_research_window", "HUD/ResearchWindow"],
			# **`_gate_view`** (`gate-ending-to-game.md`, Stage C). Left out, every Stage C/D check below dies
			#  on a null mid-call and disappears rather than fails — the exact risk `net_settlement.gd`'s own
			#  `_wired_root` now names for the same node.
			["_gate_view", "GateView"],
			# **`_boss_bar`** (`boss-entrance-and-hp-bar.md` Stage C) — `_rebuild()` and `_physics_process()`
			#  both call it unconditionally now (`clear_boss()`/`set_entrance_frames()`). Left out, every
			#  check in this file that calls `reset_stage()`/`_leave_town()`/`_physics_process` on this root
			#  crashes on a null mid-call — measured directly (`Invalid call. Nonexistent function
			#  'clear_boss' in base 'Nil'`), the exact risk this file's own header already names for
			#  `_gate_view` one line up.
			["_boss_bar", "HUD/BossBar"],
			["_settlement", "HUD/SettlementWindow"],
			["_settlement", "HUD/SettlementWindow"],
			# **`_onboard_view`** (`onboarding-and-palette-tabs.md` Stage 7) — `_physics_process()` reaches
			#  `_tick_onboard()` unconditionally, which writes `_onboard_view.visible` every frame. Every
			#  `_physics_process` call in this file dies on a null without this.
			["_onboard_view", "HUD/OnboardView"],
			# **`_char_view`** (the hit-flash/shake feature) — `_rebuild()` now calls `_char_view.clear()`
			#  unconditionally and `_on_ticked()` calls `_char_view.on_tick()` unconditionally. Left out,
			#  every check in this file that drives either one crashes on a null mid-call — the exact risk
			#  `_boss_bar`'s own box above already names for a different node.
			["_char_view", "CharacterView"]]:
		var n := root.get_node_or_null(NodePath(pair[1]))
		t.ok(n != null, "씬에 %s 가 있다 (전제)" % pair[1])
		if n == null:
			root.free()
			return null
		root.set(pair[0], n)
	root.get_node("CellRenderer").call("setup", root.get("_grid"))
	root.get_node("TownView").call("setup", root.get("_char"))
	root.get_node("SkyBackground").call("setup", root.get_node("Camera2D"))
	var pr0: Variant = (root.get("_world") as Object).call("progress")
	root.get_node("HUD/ResearchWindow").call("setup", pr0)
	root.get_node("GateView").call("setup", pr0)
	root.call("reset_stage")
	return root
