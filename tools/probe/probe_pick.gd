# Measures the disagreement between WHERE A TILE IS ON SCREEN and WHICH TILE A PRESS THERE LANDS ON.
#
# **Not a net** — it asserts nothing and prints numbers. It exists because the user reported
# 「놓는 위치랑 배의 위치가 다른데」 (2026-08-25) and that sentence needed a number before anything was
# changed.
#
# The instrument is `Camera3D.unproject_position`, which is the projection's own inverse and cannot
# drift from it. For every tile: unproject the tile's real surface point to a screen px, hand that
# screen px to the SHELL's own `_tile_at`, and compare.
#
# **What it measured, and it took three separate faults to explain one sentence:**
#
# | | band (water) | walkable land |
# |---|---:|---:|
# | as reported | 18.6 tiles off, 51/51 wrong | 11.6 tiles off, 180/180 wrong |
# | camera's `back.z` sign fixed | 1.63 | 2.82 |
# | `_visible_ground_px` cos -> sin | **0.00, 0/51** | 2.82 |
# | press resolved against the landscape | 0.00 | **0.11, 19/180** |
#
# ⚠ **The 19 that remain are tiles standing BEHIND a taller one** — their centres are not on screen at
# all, and the walk answering with the hill in front of them is the right answer. Checked one by one
# with the `[occl?]` lines below: every one has a neighbour 0.5 to 0.7 tiles taller between it and the
# eye.
#
# Run:
#   Godot_v4.7.1-stable_win64.exe --headless --path . -s tools/probe/probe_pick.gd
extends SceneTree

var _game: Game = null
var _step := 0
var _wait := 0


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


func _key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = code
	return ev


## Where the tile's own surface really is on the glass, asked of the camera.
func _true_screen_px(tx: int, ty: int) -> Vector2:
	var fv := _game.field_view
	var world := Look.tile_point_px(Vector2(tx, ty))
	var p := Vector3(world.x / Look.TILE_PX, fv._ground_h(tx, ty), world.y / Look.TILE_PX)
	return fv._cam.unproject_position(p)


func _survey(label: String) -> void:
	var fv := _game.field_view
	var g := _game.battle.grid
	var worst := 0.0
	var worst_line := ""
	var n := 0
	var sum := 0.0
	var wrong := 0
	for t in g.w * g.h:
		if not g.can_summon_at(t):
			continue
		var tx := t % g.w
		var ty := t / g.w
		var at := _true_screen_px(tx, ty)
		if at.x < 0.0 or at.y < 0.0 or at.x > Look.VIEWPORT_W_PX or at.y > Look.VIEWPORT_H_PX:
			continue
		var got := _game._tile_at(at)
		var gx := -1
		var gy := -1
		if got >= 0:
			gx = got % g.w
			gy = got / g.w
		var d := Vector2(float(gx - tx), float(gy - ty)).length()
		n += 1
		sum += d
		if got != t:
			wrong += 1
		if d > worst:
			worst = d
			worst_line = "  tile (%d,%d) h=%.2f  press at (%.1f,%.1f) -> tile (%d,%d)" % [
				tx, ty, fv._ground_h(tx, ty), at.x, at.y, gx, gy]
	print("[pick] %s  zoom=%.3f yaw=%.1f pitch=%.1f  tiles=%d  wrong=%d  mean_off=%.3f  worst_off=%.3f" % [
		label, fv.zoom, fv.cam_yaw_deg, fv.cam_pitch_deg, n, wrong, sum / maxf(float(n), 1.0), worst])
	if worst_line != "":
		print(worst_line)


## The same question asked of LAND, where the height is 1.0 tile instead of the water's 0.15.
func _survey_land(label: String) -> void:
	var fv := _game.field_view
	var g := _game.battle.grid
	var worst := 0.0
	var worst_line := ""
	var n := 0
	var sum := 0.0
	var wrong := 0
	for t in g.w * g.h:
		var tx := t % g.w
		var ty := t / g.w
		if not g.is_passable(tx, ty):
			continue
		var at := _true_screen_px(tx, ty)
		if at.x < 0.0 or at.y < 0.0 or at.x > Look.VIEWPORT_W_PX or at.y > Look.VIEWPORT_H_PX:
			continue
		var got := _game._tile_at(at)
		var gx := -1
		var gy := -1
		if got >= 0:
			gx = got % g.w
			gy = got / g.w
		var d := Vector2(float(gx - tx), float(gy - ty)).length()
		n += 1
		sum += d
		if got != t:
			wrong += 1
		if got != t and wrong <= 6:
			# Is the answer HIDING the tile that was aimed at? If the tile the ray met is taller and
			# nearer the eye, the aimed tile's centre is not on screen at all and the answer is right.
			print("  [occl?] aimed (%d,%d) h=%.2f -> got (%d,%d) h=%.2f ; got draws at %s vs %s" % [
				tx, ty, fv._ground_h(tx, ty), gx, gy, fv._ground_h(gx, gy),
				str(_true_screen_px(gx, gy)), str(at)])
		if d > worst:
			worst = d
			worst_line = "  tile (%d,%d) h=%.2f  press at (%.1f,%.1f) -> tile (%d,%d)" % [
				tx, ty, fv._ground_h(tx, ty), at.x, at.y, gx, gy]
	print("[land] %s  zoom=%.3f yaw=%.1f pitch=%.1f  tiles=%d  wrong=%d  mean_off=%.3f  worst_off=%.3f" % [
		label, fv.zoom, fv.cam_yaw_deg, fv.cam_pitch_deg, n, wrong, sum / maxf(float(n), 1.0), worst])
	if worst_line != "":
		print(worst_line)


## What the summon actually placed, versus the tile the press was aimed at.
func _place_one() -> void:
	var fv := _game.field_view
	var g := _game.battle.grid
	for t in g.w * g.h:
		if not g.can_summon_at(t):
			continue
		var tx := t % g.w
		var ty := t / g.w
		var at := _true_screen_px(tx, ty)
		if at.x < 0.0 or at.y < 0.0 or at.x > Look.VIEWPORT_W_PX or at.y > Look.VIEWPORT_H_PX:
			continue
		_game._unhandled_input(_key(KEY_1))
		_game._unhandled_input(_click(at))
		print("[place] aimed at tile (%d,%d) screen (%.1f,%.1f); boats=%d" % [
			tx, ty, at.x, at.y, _game.battle.boats.size()])
		if _game.battle.boats.size() > 0:
			var boat: Dictionary = _game.battle.boats[0]
			var pos := Vector2(boat["pos"])
			print("        boat sits at world tile (%.2f,%.2f), back on screen (%.1f,%.1f)" % [
				pos.x, pos.y, _true_screen_px(int(pos.x), int(pos.y)).x,
				_true_screen_px(int(pos.x), int(pos.y)).y])
		# Is anything visible for it? Count the hull boxes the view left on. ⚠ `field_view._process` by
		# hand — `game._process` is the SHELL's and never reaches the view's own painting pass.
		_game._process(1.0 / 60.0)
		fv._process(1.0 / 60.0)
		var hulls := 0
		for m in fv._hulls:
			if m.visible:
				hulls += 1
		var sprites := 0
		for s in fv._sprites:
			if s.visible:
				sprites += 1
		print("        after a frame: visible hulls=%d, visible sprites=%d, committed=%s" % [
			hulls, sprites, str(_game.battle.committed())])
		return


func _process(_delta: float) -> bool:
	_wait += 1
	if _wait < 6:
		return false
	_wait = 0
	match _step:
		0:
			_game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
		1:
			_game._unhandled_input(_click(Look.card_hit_rect_px(0).get_center()))
		2:
			var open_nodes := _game.run.map.reachable_nodes()
			_game._unhandled_input(_click(Look.map_node_pos_px(int(open_nodes[0]))))
			_game._process(Look.MAP_TRAVEL_SEC)
			_game._process(1.0 / 60.0)
			print("[pick] battle is %s" % ("null" if _game.battle == null else "open"))
		3:
			var fv := _game.field_view
			fv._process(1.0 / 60.0)
			print("[diag] root.size=%s  cam vp rect=%s  cam.size=%.3f  cam.keep=%d" % [
				str(root.size), str(fv._cam.get_viewport().get_visible_rect()), fv._cam.size,
				fv._cam.keep_aspect])
			print("[diag] cam global pos=%s  cam_px=%s  zoom=%.3f" % [
				str(fv._cam.global_position), str(fv.cam_px), fv.zoom])
			var mid := fv._ground_centre_px()
			print("[diag] ground centre world=%s ; unproject at y=0 -> %s (expect 640,360)" % [
				str(mid), str(fv._cam.unproject_position(
					Vector3(mid.x / Look.TILE_PX, 0.0, mid.y / Look.TILE_PX)))])
			# How many SCREEN px one tile of ground covers on each axis, and one tile of HEIGHT.
			var o := Vector3(mid.x / Look.TILE_PX, 0.0, mid.y / Look.TILE_PX)
			var base := fv._cam.unproject_position(o)
			var dx := fv._cam.unproject_position(o + Vector3(1.0, 0.0, 0.0)) - base
			var dz := fv._cam.unproject_position(o + Vector3(0.0, 0.0, 1.0)) - base
			var dy := fv._cam.unproject_position(o + Vector3(0.0, 1.0, 0.0)) - base
			var p := deg_to_rad(fv.cam_pitch_deg)
			print("[diag] one tile +x -> %s ; +z -> %s ; +y(height) -> %s" % [str(dx), str(dz), str(dy)])
			print("[diag] tile px = %.3f ; sin(pitch)=%.4f cos(pitch)=%.4f ; dz.y/dx.x=%.4f dy.y/dx.x=%.4f" % [
				Look.TILE_PX, sin(p), cos(p), dz.y / dx.x, dy.y / dx.x])
			# The view's OWN forward against the camera's. If these two ever part, everything below is
			# measuring the instrument rather than the game.
			var worst_fwd := 0.0
			for t in _game.battle.grid.w * _game.battle.grid.h:
				var tx := t % _game.battle.grid.w
				var ty := t / _game.battle.grid.w
				worst_fwd = maxf(worst_fwd,
					fv.tile_to_screen_px(tx, ty).distance_to(_true_screen_px(tx, ty)))
			print("[diag] view forward vs camera forward: worst %.4f px over the whole grid" % worst_fwd)
		4:
			_survey("opening survey")
			_survey_land("opening survey")
		5:
			for _i in 4:
				_game.field_view.zoom_at(Look.viewport_size_px() * 0.5, 1.0 / Look.ZOOM_STEP)
			_game.field_view._process(1.0 / 60.0)
			_survey("zoomed out")
			_survey_land("zoomed out")
		6:
			for _i in 4:
				_game.field_view.zoom_at(Look.viewport_size_px() * 0.5, Look.ZOOM_STEP)
			for _i in 3:
				_game._unhandled_input(_key(KEY_E))
			_game.field_view._process(1.0 / 60.0)
			_survey("turned")
			_survey_land("turned")
		7:
			_game.field_view.turn_by(-3.0 * Look.CAM_YAW_STEP_DEG)
			_game.field_view._process(1.0 / 60.0)
			_place_one()
		_:
			return true
	_step += 1
	return false
