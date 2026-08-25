# Drives the real shell and saves screenshots **of the effects**, one per thing that has to be visible.
# **Not a net** — it asserts nothing; it is how a human sees that an effect came back. Nets live in
# `tests/nets/` and this stays out of there because nothing here can go red.
#
# ⚠⚠ **The fight shots are TAKEN OFF THE EFFECT LIST, not off a frame count.** A tracer lives 0.10 s
# and a shard fan 0.12 s; stepping a fixed number of frames and hoping catches nothing, and a shot
# that catches nothing looks exactly like an effect that was never painted.
#
# ⚠⚠ **THIS SHOOTER IS STALE AND IT HANGS** (found 2026-08-25). 티켓 15 put a BEAST CARD ROUND between
# the title and the map, and the step that clicks a map node still runs straight after the title — so
# no island opens, and because the fight shots wait on the EFFECT LIST rather than on a frame count,
# the wait never ends. **It has to be killed by hand.** ⇒ Take a card (`Look.card_hit_rect_px(0)`)
# between the title click and the map click. `shoot_field.gd` carries the same staleness (it finishes,
# and writes eight PNGs of the wrong screen).
#
# Run (a window has to open — a headless run has no renderer to read a frame back from):
#   Godot_v4.7.1-stable_win64.exe --path . -s tools/shot/shoot_fx.gd
extends SceneTree

const SHOT := "res://tools/shot/fx_%s.png"

var _game: Game = null
var _step := 0
var _wait := 0
var _good_t := -1
var _bad_t := -1
var _good := Vector2.ZERO
var _bad := Vector2.ZERO


func _initialize() -> void:
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	_game = Game.new()
	root.add_child(_game)


func _click(at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	return ev


func _release(at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = at
	return ev


func _move(at: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	return ev


func _key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = code
	return ev


## A 320 x 180 window on the frame, blown up four times with NEAREST, centred on the thing the shot is
## OF. **Saved beside the whole frame and not instead of it**: an effect 8 px across is invisible in a
## 1280-wide capture, and a capture that shows nothing looks exactly like an effect that was never
## painted — which is the failure this whole instrument exists to tell apart.
func _save_near(name: String, world: Vector2) -> void:
	var img := root.get_texture().get_image()
	var at := _world_to_screen_px(world)
	var w := int(Look.VIEWPORT_W_PX / 4.0)
	var h := int(Look.VIEWPORT_H_PX / 4.0)
	var x := clampi(int(at.x) - w / 2, 0, int(Look.VIEWPORT_W_PX) - w)
	var y := clampi(int(at.y) - h / 2, 0, int(Look.VIEWPORT_H_PX) - h)
	var cut := img.get_region(Rect2i(x, y, w, h))
	cut.resize(w * 4, h * 4, Image.INTERPOLATE_NEAREST)
	cut.save_png(ProjectSettings.globalize_path(SHOT % (name + "_near")))
	print("[fx] %s_near" % name)


## Where a live effect of `kind` actually is, in world px. **The crop is centred on the EFFECT and not
## on the fight**: after the last enemy in a knot dies, "where the fight is" walks off to some other
## corner of the island and the close-up of the death shows an empty field.
func _fx_at(kind: int) -> Vector2:
	for raw_fx in _game.field_view._fx:
		var fx: Dictionary = raw_fx
		if int(fx["kind"]) != kind:
			continue
		if fx.has("at"):
			return fx["at"]
		if fx.has("from"):
			return fx["from"]
	return _where_the_fight_is()


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(SHOT % name))
	var fv := _game.field_view
	var kinds := ""
	for raw_fx in fv._fx:
		var f: Dictionary = raw_fx
		kinds += "%d(age%.3f/%.3f+%.3f) " % [int(f["kind"]), float(f["age"]), float(f["life"]), float(f["delay"])]
	print("[fx] %s  live=%d  air_v=%d  ground_v=%d  proc=%s  %s" % [name, fv._fx.size(),
		fv._a_v.size(), fv._g_v.size(), str(fv.is_processing()), kinds])


## The tile the plan is authored on, and a tile the sim refuses.
##
## ⚠ **The refused one is the GOOD one's own landing**, which is land by construction. Picking "some
## impassable tile" put the refusal mark half an island away from the camera and the shot showed an
## empty sea — the mark was painted and nothing was wrong except where it was.
func _pick_tiles() -> void:
	var g := _game.battle.grid
	# The summonable tile nearest the water SOUTH of the island: the camera looks from the south, so
	# this is the one a player would actually press, and it is on screen without panning.
	var want := g.summon_centre() + Vector2(0.0, g.summon_radius() * 0.8)
	var best := INF
	for t in g.w * g.h:
		if not g.can_summon_at(t):
			continue
		var d := g.tile_point(t).distance_to(want)
		if d < best:
			best = d
			_good_t = t
	if _good_t >= 0:
		_bad_t = g.summon_landing_of(_good_t)
	_measure()


## Screen positions of the two chosen tiles. Split from the choosing so a zoom or a pan re-measures
## without re-choosing — re-choosing would silently make the shot be of a different tile.
func _measure() -> void:
	var g := _game.battle.grid
	if _good_t >= 0:
		_good = _click_px_of(Look.tile_point_px(g.tile_point(_good_t)))
	if _bad_t >= 0:
		_bad = _click_px_of(Look.tile_point_px(g.tile_point(_bad_t)))


## ✅ **Where to CLICK — and it is the same place the thing IS on screen now** (2026-08-25). This
## carried its own copy of the flat board's inverse and its header said, correctly, that the copy and
## the camera disagreed and that the defect was in `screen_to_world_px` rather than here. **That
## defect is fixed**: the shell resolves a press against the LANDSCAPE, and `world_to_screen_px` is
## its forward, written once in the view. So there is one map of the screen again and this asks the
## view for it.
func _click_px_of(world: Vector2) -> Vector2:
	var fv := _game.field_view
	var tx := int(floor(world.x / Look.TILE_PX))
	var ty := int(floor(world.y / Look.TILE_PX))
	return fv.world_to_screen_px(world, fv._ground_h(tx, ty))


## ⚠⚠ **The camera does this, not a formula.** The first version of this instrument carried a copy of
## the flat board's inverse, and on a camera that is pitched AND turned it was wrong by tens of pixels
## — every click landed on a tile next to the one it meant and every close-up was cropped somewhere
## else. `Camera3D.unproject_position` is the projection's own inverse and cannot drift from it.
func _world_to_screen_px(world: Vector2) -> Vector2:
	var fv := _game.field_view
	var tx := int(floor(world.x / Look.TILE_PX))
	var ty := int(floor(world.y / Look.TILE_PX))
	return fv._cam.unproject_position(
		Vector3(world.x / Look.TILE_PX, fv._ground_h(tx, ty), world.y / Look.TILE_PX))


## Puts a world point in the middle of the screen. Iterated because `_clamp_cam` can refuse part of
## the move at the edge of the island, and one pass would then leave the subject off centre.
func _centre_on(world: Vector2) -> void:
	var fv := _game.field_view
	for _i in 4:
		fv.pan_by(Look.viewport_size_px() * 0.5 - _world_to_screen_px(world))
	_measure()
	_paint()


func _zoom(steps: int, at: Vector2) -> void:
	for _i in steps:
		_game.field_view.zoom_at(at, Look.ZOOM_STEP)
	_measure()


## Wherever the fighting is: the first ashore body that has picked a target, else any ashore body,
## else the first live enemy. **Found through the sim's own state**, so the camera cannot be pointed
## at a fight that is not happening.
func _where_the_fight_is() -> Vector2:
	var b := _game.battle
	for raw_id in b.ashore_ids():
		var i := int(raw_id)
		if int(b.soldier_target[i]) >= 0:
			return Look.tile_point_px(b.soldier_pos[i])
	for raw_id in b.ashore_ids():
		return Look.tile_point_px(b.soldier_pos[int(raw_id)])
	for e in b.enemy_alive.size():
		if b.enemy_alive[e] != 0:
			return Look.tile_point_px(b.enemy_pos[e])
	return Look.tile_point_px(b.grid.summon_centre())


## ⚠⚠ **The view is driven BY HAND here, and that is the whole reason the first version of this
## instrument photographed nothing.** Stepping the sim 3000 times inside one engine frame advances
## the fight 50 seconds while `field_view._process` runs ONCE — every event but the last frame's is
## drained into nothing, so every tracer and every shard was born and died unseen. `set_process(false)`
## in step 3 hands the clock to `_run`, and sim and view then move together.
## Repaints WITHOUT advancing anything, for the frames where the last thing that happened was an
## input rather than a tick. **`battle.events` is emptied first**: `_drain_events` would otherwise turn
## the last sim frame's facts into a SECOND set of effects and the shot would be a lie about how many.
func _paint() -> void:
	_game.battle.events.clear()
	_game.field_view._process(0.0)


func _run(frames: int) -> void:
	for _i in frames:
		_game._process(1.0 / 60.0)
		_game.field_view._process(1.0 / 60.0)


## Steps ONE frame at a time until an effect of one of `kinds` is alive and past its delay, then
## stops. Returns false if it never happened inside `limit` frames — the caller prints that rather
## than pretending the shot is of something.
func _run_until(kinds: Array, limit: int) -> bool:
	var fv := _game.field_view
	for _i in limit:
		_game._process(1.0 / 60.0)
		fv._process(1.0 / 60.0)
		for raw_fx in fv._fx:
			var fx: Dictionary = raw_fx
			if not kinds.has(int(fx["kind"])):
				continue
			if float(fx["age"]) >= float(fx["delay"]):
				return true
	return false


func _process(_delta: float) -> bool:
	_wait += 1
	if _wait < 6:
		return false
	_wait = 0
	match _step:
		0:
			_game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
		1:
			_game._unhandled_input(_click(Look.map_node_pos_px(0)))
		2:
			_game._process(Look.MAP_TRAVEL_SEC)
		3:
			_game.field_view.set_process(false)
			if OS.get_environment("FXOFF") == "1":
				_game.field_view._decal.visible = false
				_game.field_view._air.visible = false
			_pick_tiles()
			_centre_on(Look.tile_point_px(_game.battle.grid.tile_point(_good_t)))
			_zoom(4, Look.viewport_size_px() * 0.5)
		4:
			# **The plan's own picture**: armed, cursor over water the sim accepts. Ring, route, ghosts.
			_game._unhandled_input(_key(KEY_1))
			_game._unhandled_input(_move(_good))
			_run(2)
			_paint()
		5:
			_save("1_aim")
			_save_near("1_aim", Look.tile_point_px(_game.battle.grid.tile_point(_good_t)))
		6:
			# The refusal mark: press on the landing, which is land, which `Battle.send` answers -1 to.
			_game._unhandled_input(_move(_bad))
			_run(2)
			_game._unhandled_input(_click(_bad))
			_game._unhandled_input(_release(_bad))
			_paint()
		7:
			_save("2_refuse")
			_save_near("2_refuse", _fx_at(FieldView.FxKind.REFUSE))
		8:
			_game._unhandled_input(_move(_good))
			_run(2)
			_game._unhandled_input(_click(_good))
			_game._unhandled_input(_release(_good))
			_game._unhandled_input(_click(Look.start_rect_px().get_center()))
		9:
			# The landing ring, caught on the frame a body actually comes ashore.
			if not _run_until([FieldView.FxKind.LAND], 900):
				print("[fx] no landing inside 900 frames")
			_centre_on(_fx_at(FieldView.FxKind.LAND))
			_zoom(3, Look.viewport_size_px() * 0.5)
			_paint()
		10:
			_save("3_landing")
			_save_near("3_landing", _fx_at(FieldView.FxKind.LAND))
		11:
			# A blow: the tracer for a ranged one, the shard fan for a melee one.
			if not _run_until([FieldView.FxKind.SHOT, FieldView.FxKind.SPARK], 3000):
				print("[fx] no blow inside 3000 frames")
			_centre_on(_fx_at(FieldView.FxKind.SPARK))
		12:
			_save("4_blow")
			_save_near("4_blow", _fx_at(FieldView.FxKind.SPARK))
		13:
			if not _run_until([FieldView.FxKind.SPARK], 3000):
				print("[fx] no melee shards inside 3000 frames")
			_centre_on(_fx_at(FieldView.FxKind.SPARK))
		14:
			_save("5_shards")
			_save_near("5_shards", _fx_at(FieldView.FxKind.SPARK))
		15:
			# A death: the burst.
			if not _run_until([FieldView.FxKind.BURST], 6000):
				print("[fx] no death inside 6000 frames")
			_centre_on(_fx_at(FieldView.FxKind.BURST))
		16:
			_save("6_death")
			_save_near("6_death", _fx_at(FieldView.FxKind.BURST))
		_:
			return true
	_step += 1
	return false
