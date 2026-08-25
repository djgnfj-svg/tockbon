# Stages the situations 티켓 15's 「눈으로」 list names and photographs them. **Not a net** — it asserts
# nothing; it puts a designed moment on screen so a human can judge it.
#
# Four things the whole-loop shooter cannot reach on its own:
#   1. all five summon boxes at once (a real run needs four card rounds to get there)
#   2. all nine `Rules.UNITS` rows standing in one frame, so a row wearing another row's picture shows
#   3. a bleeding body BESIDE a body of the same species that is not bleeding, in one frame
#   4. every island's opening survey, to see that nothing on the enemy side is a beast
#
# ⚠ **Never `--headless`** — there is no swapchain to read a frame back from and every PNG comes out
# black with no error anywhere. The refusal is enforced below rather than written down.
#
# Run:
#   Godot_v4.7.1-stable_win64.exe --path . -s tools/shot/shoot_species.gd
extends SceneTree

const SHOT := "res://tools/shot/species_%s.png"
const FRAME_SEC := 1.0 / 60.0

var _game: Game = null
var _step := 0
var _wait := 0
## The lineup's own battle and army. Held so the bleed stage can keep stepping the one it built rather
## than the shell's.
var _stage: Battle = null
var _stage_army: Army = null


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("shoot_species: --headless has no renderer; every frame reads back black")
		quit(1)
		return
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	_game = Game.new()
	root.add_child(_game)


func _click(at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	_game._unhandled_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = at
	_game._unhandled_input(up)


func _save(what: String) -> void:
	# ⚠ The frame is read AFTER the renderer has finished this one, or the previous frame is what
	# lands on disk — which is how a staged camera reads as "the change had no effect".
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(SHOT % what))
	print("[species] %s" % what)


## The forward of `field_view.screen_to_world_px`. ⚠ **It lives in the view now** (2026-08-25): this
## file kept a private copy, it was the flat board's and it ignored the yaw, and it framed every
## staged shot somewhere other than where it meant.
func _world_to_screen_px(world: Vector2) -> Vector2:
	var fv := _game.field_view
	var tx := int(floor(world.x / Look.TILE_PX))
	var ty := int(floor(world.y / Look.TILE_PX))
	return fv.world_to_screen_px(world, fv._ground_h(tx, ty))


## Frames `world` at the middle of the screen at `zoom_steps` steps in from the survey.
## ⚠ **Through `zoom_at` and `pan_by` only.** Writing `cam_px` past the clamp is how a staged camera
## silently un-stages itself between the write and the shutter.
func _frame_on(world: Vector2, zoom_steps: int) -> void:
	var fv := _game.field_view
	for _i in zoom_steps:
		fv.zoom_at(_world_to_screen_px(world), Look.ZOOM_STEP)
	fv.pan_by(Look.viewport_size_px() * 0.5 - _world_to_screen_px(world))


## A row of the map with at least `want` passable tiles in an unbroken run, as `[y, x0]`, or `[]`.
func _long_run_on(g: Grid, want: int) -> Array:
	for y in g.h:
		var run := 0
		for x in g.w:
			run = run + 1 if g.is_passable(x, y) else 0
			if run >= want:
				return [y, x - want + 1]
	return []


## Puts the nine `Rules.UNITS` rows on one row of ground, players first, and hands the field view the
## battle that holds them. Returns the world px at the middle of the line.
##
## ⚠ **The sim is never stepped for this shot.** Nine bodies of two sides a tile apart would be a
## brawl by the second frame, and the question here is only which picture each row wears.
func _stage_lineup(island: int, pitch: int) -> Vector2:
	var g := Grid.new()
	Islands.load_into(g, island)
	var players: Array = []
	var enemies: Array = []
	for ty in Rules.UNITS.size():
		if Rules.side_of(ty) == Rules.Side.PLAYER:
			players.append(ty)
		else:
			enemies.append(ty)
	var slot := _long_run_on(g, (players.size() + enemies.size()) * pitch)
	if slot.is_empty():
		push_error("shoot_species: island %d has no run of ground long enough" % island)
		return Vector2.ZERO
	var y := int(slot[0])
	var x0 := int(slot[1])

	_stage_army = Army.new()
	for ty in players:
		var s := _stage_army.register_species(int(ty))
		_stage_army.recruit(s)

	var spawns: Array = []
	for k in enemies.size():
		spawns.append({"type_id": int(enemies[k]),
			"tile": y * g.w + x0 + (players.size() + k) * pitch})

	_stage = Battle.new()
	_stage.setup(g, _stage_army, spawns, Islands.time_limit_of(island))
	for i in _stage_army.type_id.size():
		_stage.soldier_state[i] = Battle.SoldierState.ASHORE
		_stage.soldier_pos[i] = Vector2(float(x0 + i * pitch) + 0.5, float(y) + 0.5)

	_game.field_view.setup(_stage, _stage_army, Islands.rows_of(island))
	var span := float((players.size() + enemies.size() - 1) * pitch) * 0.5
	return Look.tile_point_px(Vector2(float(x0) + span + 0.5, float(y) + 0.5))


## One crow and two shieldbearers: one inside the crow's reach, one far outside every detect radius so
## it never walks in and never gets bitten. **The control and the subject are the same species in the
## same frame** — a bleeding body judged against a memory of an unbled one is not a comparison.
func _stage_bleed(island: int, gap: int) -> Vector2:
	var g := Grid.new()
	Islands.load_into(g, island)
	var slot := _long_run_on(g, gap + 4)
	if slot.is_empty():
		push_error("shoot_species: no ground run for the bleed stage")
		return Vector2.ZERO
	var y := int(slot[0])
	var x0 := int(slot[1])

	_stage_army = Army.new()
	var s := _stage_army.register_species(Rules.CROW)
	_stage_army.recruit(s)

	var spawns: Array = [
		{"type_id": Rules.SHIELDBEARER, "tile": y * g.w + x0 + 2},
		{"type_id": Rules.SHIELDBEARER, "tile": y * g.w + x0 + 2 + gap},
	]
	_stage = Battle.new()
	_stage.setup(g, _stage_army, spawns, Islands.time_limit_of(island))
	_stage.soldier_state[0] = Battle.SoldierState.ASHORE
	_stage.soldier_pos[0] = Vector2(float(x0) + 0.5, float(y) + 0.5)
	# ⚠ **`commit()` refuses an empty fleet**, and this stage has no fleet: the crow was put ashore
	# directly so it stands where the shot needs it rather than where a boat happened to unload. The
	# latch is set by hand, and it is the ONLY thing this instrument reaches around — the bite, the
	# bleed and the tint all still come from the real `step`.
	_stage._committed = true
	_game.field_view.setup(_stage, _stage_army, Islands.rows_of(island))
	return Look.tile_point_px(Vector2(float(x0 + 2 + gap / 2) + 0.5, float(y) + 0.5))


func _process(_delta: float) -> bool:
	_wait += 1
	if _wait < 4:
		return false
	_wait = 0
	match _step:
		0:
			_click(Look.title_slot_hit_rect_px(0).get_center())
		1:
			# The opening card round. Taking one is the only way past it.
			_click(Look.card_hit_rect_px(0).get_center())
		2:
			# Every remaining species straight onto the run's own army — the shell would need four more
			# won islands to get here, and the question is what five boxes look like, not how they arrive.
			for ty in [Rules.SQUIRREL, Rules.WOLF, Rules.COW, Rules.BEAR, Rules.CROW]:
				var slot := _game.run.army.register_species(int(ty))
				if slot >= 0:
					for _i in 4:
						_game.run.army.recruit(slot)
			print("[species] slots now %d" % _game.run.army.slot_count())
			var open_nodes := _game.run.map.reachable_nodes()
			_click(Look.map_node_pos_px(int(open_nodes[0])))
			_game._process(Look.MAP_TRAVEL_SEC)
		3:
			for _i in 30:
				_game._process(FRAME_SEC)
				_game.field_view._process(FRAME_SEC)
			_save("1_five_slots")
		4:
			# A known-answer frame BEFORE anything is staged: the whole island at survey zoom. If this
			# one is wrong the instrument is wrong, and every staged shot after it is unreadable.
			var mid := _stage_lineup(Islands.LONG_ISLAND_INDEX, 3)
			_game.field_view._process(FRAME_SEC)
			_save("2_lineup_survey")
			_frame_on(mid, 8)
		5:
			_game.field_view._process(FRAME_SEC)
			_save("3_nine_species")
		6:
			var mid := _stage_bleed(Islands.LONG_ISLAND_INDEX, 8)
			_frame_on(mid, 14)
			# Stepped until the crow's bite has actually landed, then a quarter second more so the white
			# hit flash has drained off the body and what is left on it is the bleed and nothing else.
			var bit := false
			for _i in 3000:
				_stage.begin_frame()
				_stage.step(FRAME_SEC)
				_game.field_view._process(FRAME_SEC)
				if _stage.status_left(Rules.Status.BLEED, 0) > 0.0:
					bit = true
					break
			print("[species] bleed after bite: %.2f s, control: %.2f s"
				% [_stage.status_left(Rules.Status.BLEED, 0),
					_stage.status_left(Rules.Status.BLEED, 1)])
			if not bit:
				push_error("shoot_species: the crow never drew blood")
			for _i in 15:
				_stage.begin_frame()
				_stage.step(FRAME_SEC)
				_game.field_view._process(FRAME_SEC)
		7:
			print("[species] at the shutter: bleeding %.2f s, control %.2f s"
				% [_stage.status_left(Rules.Status.BLEED, 0),
					_stage.status_left(Rules.Status.BLEED, 1)])
			_save("4_bleed")
		_:
			var isle := _step - 8
			if isle >= Islands.count():
				return true
			var g := Grid.new()
			Islands.load_into(g, isle)
			var a := Army.new()
			a.add_starting_force()
			var b := Battle.new()
			b.setup(g, a, Islands.spawns_of(isle), Islands.time_limit_of(isle))
			_game.field_view.setup(b, a, Islands.rows_of(isle))
			_game.field_view._process(FRAME_SEC)
			var kinds := {}
			for e in b.enemy_type.size():
				kinds[Rules.label_of(int(b.enemy_type[e]))] = 1
			print("[species] island %d holds %s" % [isle, ", ".join(kinds.keys())])
			_save("5_island_%d" % isle)
	_step += 1
	return false
