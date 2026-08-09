extends RefCounted
## Stage 1 monster placement, Stages A+B — `docs/plans/3.done/monster-placement-stage1.md`.
## Two jobs in one file (the plan's own file count): **resolve** a `(tx, kind)` row to a ground position,
## and **run** the table — wake rows into real monsters, mark them spent on death, re-arm on `reset()`.
## Pure `RefCounted`, no scene tree, **no reference to `src/stage/`** (`net_layers` — the same isolation
## `boss_ai.gd` already holds). The table itself (`stage1_monsters.gd`) lives in `src/stage/` and is
## handed down by the shell through `set_rows()`; this file never learns its name.
##
## **`spawn_monster` stays the only door that makes a monster.** `wake_scan()` below only ever decides
## *when* to call it (passed in as a `Callable`, since `world_step.gd` already preloads this file and a
## `preload` the other way would be a cycle) — never bypasses its cap check or its box-inside-the-grid
## check, which is that function's own recorded reason for being the only door.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Body := preload("res://src/actor/body.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const MonsterDefs := preload("res://src/actor/monster_defs.gd")

## Wake/sleep hysteresis (px, centre to centre — the same standard `monster._dist_to_target` already
## sets). A band, not a single threshold, or a row sitting exactly on it flips state every tick this scan
## runs (§4's own words). **Neither `sim_tuning` (does not touch the grid) nor `fx_tuning` (not
## presentation)** — the precedent is `MonsterBolts.BOLT_STOP_PX`, a behavior constant living beside the
## code that reads it.
##
## **Two consumers, same band, two different audiences** — `stays_active()` below is the one hysteresis
## step both use:
##  · **`wake_scan()`'s own `_primed` bit** — the cadence of wake attempts for a still-dormant row. Once
##    a row goes live it is never re-evaluated (`_monster_id[i] != 0` short-circuits `wake_scan` forever),
##    so this half cannot change *whether* a row eventually wakes, only how often a dormant row in the
##    [720, 840) dead band re-knocks on `spawn_monster`.
##  · **`Monster.asleep`** (`docs/plans/3.done/monster-placement-stage1.md` Stage D) — a *live* monster's
##    own behavioral sleep, updated by `world_step`'s tick branch from the monster's actual current
##    position (not the row's rest `tx` — it may have walked). This is the half that used to have no
##    consumer; leaving it that way would make `SLEEP_PX` a dead constant, and a dead constant is a false
##    knob (this repo's own `element()` removal, the same day, is the precedent for not leaving one lying
##    around instead of wiring or deleting it).
const WAKE_PX := 720.0
const SLEEP_PX := 840.0


## **The one hysteresis step**, shared by both consumers above — `was_active` is the previous tick's
## state (primed, or awake), `dist` is centre-to-centre px to the player right now. Enter at `WAKE_PX`,
## exit at `SLEEP_PX`; a single threshold would flip a row or a monster sitting exactly on it every tick
## (the header's own words). **Pure** — no `Monster`, no row index, so a net drives it directly.
static func stays_active(was_active: bool, dist: float) -> bool:
	if was_active:
		return dist <= SLEEP_PX
	return dist <= WAKE_PX

## Row bookkeeping — parallel arrays keyed by row index, never a mutated copy of the caller's table
## (`stage1_monsters.ROWS` stays `const` and is never written to).
##
## **`net_pick`'s no-inventory scan is why these are declared with this comment, not silently missed** —
## it anchors on column-0 `var Array/Dictionary` and would otherwise read this as a stash a glyph could
## hide in. This is placement bookkeeping keyed by row index (which row is spent, which row's monster
## died) — the exact shape `world_step.gd`'s own `_monsters`/`_died_kind` entries already are, already
## allowed there for the same reason. Allowlisted in `net_pick.gd`, not exempted by widening its regex.
var _tx: Array[int] = []
var _kind: Array[int] = []
## 0 = not yet spawned (dormant, or spent without ever having lived — a groundless column).
var _monster_id: Array[int] = []
## Killed, or barked once for a groundless/headroom-less column — never retried either way.
var _spent: Array[bool] = []
## The hysteresis bit for a still-dormant row — see `WAKE_PX`/`SLEEP_PX` above. Meaningless once
## `_monster_id[i] != 0` (the row is live and this scan skips it forever).
var _primed: Array[bool] = []
## Monster id -> row index, so the death loop (which only knows the dying id) can find its row without
## a linear search every death. Not a stash of anything that left a spell layer — the same bookkeeping
## shape `world_step.gd`'s own `_monsters`/`_died_kind` (keyed by id or by tick, not by a glyph) already are.
var _id_to_row: Dictionary = {}

var _floor_cy := 0


## **Pure and static** — a net can drive it with a synthetic grid and no `MonsterPlacement` instance at
## all, the same reason `pick_layout.gd`'s coordinate functions are static.
##
## Ground search, precisely (`docs/plans/3.done/monster-placement-stage1.md` Stage A):
## 1. Start at `floor_cy` in the column `tx` covers. Not solid there => the column has no ground at all
##    => `push_error` (English, one text — the wrapper's silence check needs the bark and its
##    `t.expect_error` to move together, CLAUDE.md) and return "not ok".
## 2. Walk **up** while the cell above is still solid. This is the corrected direction — a downward scan
##    from the top is wrong twice on this exact map (a floating bedrock block at `tx149-150`, and room
##    ③'s own roof at `tx345-368`); scanning up from the map's bottom row lands on the real ground under
##    a floating platform because the climb stops at the **first air cell**, never reaching whatever sits
##    higher up across that air gap. This map has no caves anywhere, so the climb is exact for all 400 columns.
## 3. The cell just above where the climb stopped is the surface. Standing y (box top) =
##    `surface_top_px - h_px(kind)`; x = `tx * TILE_CELLS * CELL_PX` — the table's `tx` is the box's
##    **left edge**, not its centre, so the 3-tile authoring gap reads straight off the table.
## 4. **Full-width footing** — verify-read's own finding: the reference column alone is not enough for a
##    box wider than one tile. `tx312`'s hen originally resolved with 4 of its 12 footprint cells hanging
##    over a 3-tile drop at the `312/313` seam — `box_free` (step 5) never caught it, because that check
##    only asks "is the box's own interior clear", never "is there floor under every column of it". Every
##    cell of the footprint must be solid at the exact row the reference column resolved to, or the row
##    is reported the same way as no ground at all.
## 5. `Body.box_free` at that position — a low ceiling (not enough headroom for the kind's own height)
##    is the same kind of error as no ground at all, and is reported the same way.
##
## **The reference column is the tile's leftmost cell** (`tx * TILE_CELLS`) — step 4 above widens the
## check to the box's full footprint anyway, so the reference column only ever decides *which row*, never
## stands in for the whole box's support on its own.
static func resolve(grid: CellGrid, tx: int, kind: int, floor_cy: int) -> Dictionary:
	var cx := tx * Tuning.TILE_CELLS
	var cy := floor_cy
	if not grid.is_solid(cx, cy):
		push_error("MonsterPlacement: tx %d has no ground to stand on (kind %d)" % [tx, kind])
		return {"ok": false}
	while cy > 0 and grid.is_solid(cx, cy - 1):
		cy -= 1
	var surface_top_px := cy * Tuning.CELL_PX
	var w := MonsterDefs.w_px(kind)
	var h := MonsterDefs.h_px(kind)
	var px := tx * Tuning.TILE_CELLS * Tuning.CELL_PX
	var py := surface_top_px - h
	# Full-width footing (step 4) — every column of the box's own footprint must be solid at `cy`,
	#  the exact row the reference column resolved to. A partial drop-off inside the box's own width
	#  (the ground getting *lower* partway across it) leaves `box_free` below untouched — it only ever
	#  sees the box's own interior, never the floor — so it is checked here, separately.
	var fx0 := floori(float(px) / float(Tuning.CELL_PX))
	var fx1 := floori(float(px + w - 1) / float(Tuning.CELL_PX))
	for fx in range(fx0, fx1 + 1):
		if not grid.is_solid(fx, cy):
			push_error("MonsterPlacement: tx %d overhangs its own footing at cell %d (kind %d)" %
				[tx, fx, kind])
			return {"ok": false}
	if not Body.new(w, h, MonsterDefs.step_cells(kind)).box_free(grid, px, py):
		push_error("MonsterPlacement: tx %d has no headroom to stand a kind %d" % [tx, kind])
		return {"ok": false}
	return {"ok": true, "px": px, "py": py}


## Hands the shell's table down. **`floor_cy` is not re-derived here** — `stage1_monsters.gd` already
## derives it from `TerrainMap.MAP_H`, and re-deriving it a second time in a file that cannot even
## `preload` that constant (`src/actor/` cannot reference `src/stage/`) would need it passed in anyway.
func set_rows(rows: Array[Dictionary], floor_cy: int) -> void:
	_tx.clear()
	_kind.clear()
	_monster_id.clear()
	_spent.clear()
	_primed.clear()
	_id_to_row.clear()
	_floor_cy = floor_cy
	for row: Dictionary in rows:
		_tx.append(int(row["tx"]))
		_kind.append(int(row["kind"]))
		_monster_id.append(0)
		_spent.append(false)
		_primed.append(false)


## Re-arms every row **without discarding which table is set** — `set_rows()` only ever answers "which
## room", the same split `world_step.reset()` already holds between "which world" (constructor) and
## "revert its state" (`reset()`). Called by `world_step.reset()`, so both its callers
## (`reset_stage()`'s bare `_world.reset()`, and `reset_stage()` itself) leave a run where every row is
## unspent again (the doc's own acceptance, "a run starts with every row unspent").
func reset() -> void:
	for i in _monster_id.size():
		_monster_id[i] = 0
		_spent[i] = false
		_primed[i] = false
	_id_to_row.clear()


func row_count() -> int:
	return _tx.size()


func tx_at(i: int) -> int:
	return _tx[i]


func kind_at(i: int) -> int:
	return _kind[i]


func is_spent(i: int) -> bool:
	return _spent[i]


func is_live(i: int) -> bool:
	return _monster_id[i] != 0


func monster_id_at(i: int) -> int:
	return _monster_id[i]


## **Called once per 20Hz tick** (`world_step.frame()`'s tick branch), never once per 60Hz frame — 3x
## cheaper, and the granularity (13px of player travel at `MOVE_SPEED_PX` 260) is far finer than the
## 720px threshold, so nothing is lost by not checking every frame. Putting it on the same clock as
## `on_tick` also means a row that wakes this tick gets its first `step()` the same frame (the 60Hz loop
## runs after the tick branch, `world_step.frame()`'s own order).
##
## `spawn_fn` is `WorldStep.spawn_monster`, passed in rather than this file calling it by name — this
## file cannot `preload("res://src/actor/world_step.gd")` (that file already preloads this one; a cycle).
func wake_scan(grid: CellGrid, target_x: int, spawn_fn: Callable) -> void:
	for i in _tx.size():
		if _spent[i] or _monster_id[i] != 0:
			continue
		var half_w := float(MonsterDefs.w_px(_kind[i])) * 0.5
		var center_x := float(_tx[i] * Tuning.TILE_CELLS * Tuning.CELL_PX) + half_w
		var dist := absf(float(target_x) - center_x)
		_primed[i] = stays_active(_primed[i], dist)
		if not _primed[i]:
			continue
		# Primed and still inside the band — knock on the one door every tick until it opens.
		var res := resolve(grid, _tx[i], _kind[i], _floor_cy)
		if not res.get("ok", false):
			# `resolve()` already barked. A groundless (or headroom-less) column is a map defect, not a
			# transient refusal — spend it so it barks once, not every tick forever.
			_spent[i] = true
			continue
		var id: int = spawn_fn.call(_kind[i], int(res["px"]), int(res["py"]))
		if id <= 0:
			# Refused — the cap, or (impossible here since `resolve` already checked headroom and the
			# table is authored inside the map) an out-of-grid box. **Never spend on refusal** — a full
			# cap must not permanently lose a row (the plan's own "user decision 1": a refused wake
			# leaves the row dormant and it retries).
			continue
		_monster_id[i] = id
		_id_to_row[id] = i


## **Sleep's own eligibility gate** (`docs/plans/3.done/monster-placement-stage1.md` Stage D) —
## `world_step`'s per-tick sleep update calls this before ever touching `Monster.asleep`. **Only a
## monster this table actually placed may sleep.** Measured, not assumed: making sleep a bare function
## of "distance from the player" for *every* monster broke every unrelated net that stations a character
## far from a debug-/test-spawned monster for its own reasons (`net_monster`'s own jump checks, every
## boss pattern net) — none of those monsters have a "36 rows under a cap of 20" problem to begin with,
## which is the only reason sleep exists (§4). A debug-key mob (M/N/B/C/V) or a directly `spawn_monster()`-ed
## one is simply never a candidate.
func has_row_for(id: int) -> bool:
	return _id_to_row.has(id)


## Called from `world_step`'s death loop, which already knows the dying id. **Not every dead monster
## came from this table** — the debug-key spawns (M/N/B/C/V) have no row here, so a miss is expected and
## silent (`Dictionary.has()` guards it; nothing barks for a monster this file never placed).
func on_monster_died(id: int) -> void:
	if not _id_to_row.has(id):
		return
	var i: int = _id_to_row[id]
	_spent[i] = true
	_monster_id[i] = 0
	_id_to_row.erase(id)
