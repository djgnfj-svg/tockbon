# **Drives the move by hand and prints what happened.** A probe, not a picture.
#
#   Godot_v4.7.1-stable_win64.exe --path . --headless -s .prototypes/nine/move_probe.gd
#
# ⚠⚠ **IT ANSWERS THE ONE THING A WINDOW CANNOT BE TRUSTED ON: did all nine actually arrive?** Nine
# bodies walking to one 블록 is the first time both ceilings are load-bearing at once — three to a 조각
# and nine to a 블록 — and a body that is quietly refused just stands still, which from the chair looks
# exactly like a body that has not set off yet.
#
# ⚠ **`--headless` is fine HERE** — nothing is rendered, so nothing comes out black.
extends SceneTree

## How long the nine are given to cross. At `Rules.speed_of(SWORDSMAN)` this is far more than the walk
## needs; the point is to catch a body that never arrives, not to time one.
const SECONDS := 14.0
const DT := 1.0 / 60.0

var game: Game = null
var bat: Battle = null
var grid: Grid = null
var _boot := 0


func _initialize() -> void:
	game = Game.new()
	root.add_child(game)


func _process(_delta: float) -> bool:
	match _boot:
		0:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = Look.title_slot_hit_rect_px(0).get_center()
			game._unhandled_input(ev)
		1:
			for _i in 90:
				game._process(DT)
		2:
			_run()
			return true
	_boot += 1
	return false


func _run() -> void:
	bat = game.battle
	grid = bat.grid
	var army := game.run.army
	var slot := army.slot_of_type(Rules.SWORDSMAN)
	while army.type_id.size() < 9:
		army.recruit(slot)
	bat.setup(grid, army, [], bat.keep_tiles, bat.muster_tile)
	# ⚠ **The shell must not step it too.** `game.battle` is nulled for the same reason the lab nulls
	# it: two steppers would advance the clock twice per frame and the walk would read as double speed.
	game.battle = null

	var from := _flat_block(Vector2i(6, 6))
	var to := _flat_block(Vector2i(20, 16))
	if from.x < 0 or to.x < 0 or from == to:
		print("[probe] 평평한 블록 둘을 못 찾았다 — from=%s to=%s" % [str(from), str(to)])
		return
	var src := _tiles_of(from)
	var dst := _tiles_of(to)
	# ⚠⚠ **`place_ashore` AND NOT A HAND-WRITTEN STATE + POSITION.** Its own header says the four writes
	# are one unit — state, position, **GOAL**, and the reservation — and **leaving the goal at OFFMAP
	# makes the body walk back toward (-1, -1) at full speed.** Measured here 2026-08-31: nine bodies
	# stood correctly, took their orders, and were all at (-1, -1) fourteen seconds later.
	for k in 9:
		var i := k
		var t := int(src[k % src.size()])
		grid.release_all(i)
		bat.soldier_state[i] = Battle.SoldierState.RESERVE
		bat.place_ashore(i, t)
	print("[probe] 출발 블록 %s 에 아홉을 세웠다 — 블록이 든 몸 %d"
			% [str(from), grid.block_hold_count(grid.block_of(int(src[0])))])

	var taken := 0
	for k in 9:
		if bat.order_walk(k, int(dst[k % dst.size()])):
			taken += 1
	print("[probe] 명령을 받은 몸 %d / 9" % taken)
	var steps := int(SECONDS / DT)
	var goal := grid.block_of(int(dst[0]))
	var retries := 0
	for _s in steps:
		bat.step(DT)
		retries += _nudge(goal, dst)
	print("[probe] 몸 0 의 자리 %s · 남은 명령 %d"
			% [str(bat.soldier_pos[0]), int(bat.soldier_order[0])])
	print("[probe] 몸 0 의 상태 %d (ASHORE=%d)"
			% [int(bat.soldier_state[0]), Battle.SoldierState.ASHORE])

	var blk := grid.block_of(int(dst[0]))
	var arrived := 0
	var per := {}
	for i in 9:
		var p: Vector2 = bat.soldier_pos[i]
		var t := int(round(p.y)) * grid.w + int(round(p.x))
		if grid.block_of(t) == blk:
			arrived += 1
			per[t] = int(per.get(t, 0)) + 1
	print("[probe] %.0f 초 뒤 도착 블록 %s 에 %d / 9 (다시 보낸 횟수 %d)"
			% [SECONDS, str(to), arrived, retries])
	print("[probe] 블록이 셈한 몸 %d (천장 %d)" % [grid.block_hold_count(blk), Rules.BLOCK_CAPACITY])
	var over := []
	for t in per:
		if int(per[t]) > Rules.TILE_CAPACITY:
			over.append(t)
	print("[probe] 조각별 인원 %s · 조각 천장(%d) 넘긴 조각 %s"
			% [str(per), Rules.TILE_CAPACITY, str(over)])


## **Re-aims anybody who stopped short.** Returns how many orders were re-issued this step.
##
## ⚠⚠ **WITHOUT THIS, SIX OF NINE ARRIVE** (measured 2026-08-31). `Battle.order_walk` aims at ONE 조각;
## a body that reaches it while three others are already standing there is refused, stops, and its
## order is cleared as「stuck」. **Nine bodies aimed at four fixed 조각 therefore land as six** — the
## other three give up beside the 블록. ⇒ **A squad order is not nine walk orders**; something has to
## re-seat the ones that lost the race, and this is the smallest thing that does.
func _nudge(goal: int, dst: Array) -> int:
	var n := 0
	for i in 9:
		if int(bat.soldier_state[i]) != Battle.SoldierState.ASHORE:
			continue
		if int(bat.soldier_order[i]) >= 0:
			continue
		var p: Vector2 = bat.soldier_pos[i]
		var t := int(round(p.y)) * grid.w + int(round(p.x))
		if grid.block_of(t) == goal:
			continue
		for raw in dst:
			var want := int(raw)
			if grid.can_hold(want, i):
				if bat.order_walk(i, want):
					n += 1
				break
	return n


## The nearest flat, walkable, land-ringed 블록 to `near`, or (-1, -1).
func _flat_block(near: Vector2i) -> Vector2i:
	var b := Rules.BLOCK_TILES
	var best := Vector2i(-1, -1)
	var score := 1.0e9
	for by in range(0, grid.h - b + 1, b):
		for bx in range(0, grid.w - b + 1, b):
			var ok := true
			var lvl := -999
			for dy in range(-1, b + 1):
				for dx in range(-1, b + 1):
					var tx := bx + dx
					var ty := by + dy
					if tx < 0 or ty < 0 or tx >= grid.w or ty >= grid.h or not grid.is_passable(tx, ty):
						ok = false
						continue
					var l := grid.level_at(tx, ty)
					if lvl == -999:
						lvl = l
					elif l != lvl:
						ok = false
			if not ok:
				continue
			var d := Vector2(bx, by).distance_to(Vector2(near))
			if d < score:
				score = d
				best = Vector2i(bx, by)
	return best


func _tiles_of(low: Vector2i) -> Array:
	var out: Array = []
	for dy in Rules.BLOCK_TILES:
		for dx in Rules.BLOCK_TILES:
			var tx := low.x + dx
			var ty := low.y + dy
			if tx < grid.w and ty < grid.h and grid.is_passable(tx, ty):
				out.append(ty * grid.w + tx)
	return out
