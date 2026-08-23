# Answers one question with numbers instead of adjectives: **what in this field is actually 3D?**
# Asserts nothing and can never go red — it opens the real island through the real shell and prints
# what the engine is holding. Nets live in `tests/nets/`; this is an instrument.
#
# Run:  Godot_v4.7.1-stable_win64.exe --path . -s tools/shot/what_is_3d.gd
extends SceneTree

var _game: Game = null
var _step := 0
var _wait := 0


func _click(at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	return ev


func _initialize() -> void:
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	_game = Game.new()
	root.add_child(_game)


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
			_report()
			return true
	_step += 1
	return false


func _report() -> void:
	var fv := _game.field_view

	print("\n== the field ==")
	print("FieldView is a %s, and its child world is a %s"
		% [fv.get_class(), fv.get_child(0).get_class()])

	var lights := 0
	var shaded := 0
	var sprites := 0
	var meshes := 0
	for c in fv.get_child(0).get_children():
		if c is DirectionalLight3D:
			lights += 1
		if c is Sprite3D:
			sprites += 1
		if c is MeshInstance3D:
			meshes += 1
			if (c as MeshInstance3D).material_override is ShaderMaterial:
				shaded += 1
	print("lights=%d  meshes=%d (of them hand-written shader: %d)  billboards=%d  camera=%s"
		% [lights, meshes, shaded, sprites, fv._cam.get_class()])
	print("camera projection: %s (0=perspective 1=orthogonal)  size=%.1f tiles  yaw=%.0f pitch=%.0f"
		% [fv._cam.projection, fv._cam.size, fv.cam_yaw_deg, Look.CAM_PITCH_DEG])

	print("\n== the island, as geometry ==")
	var mesh: ArrayMesh = fv._terrain.mesh
	var verts := 0
	for s in mesh.get_surface_count():
		verts += mesh.surface_get_array_len(s)
	print("terrain triangles=%d  (vertices=%d)" % [verts / 3, verts])
	var lo := 999.0
	var hi := -999.0
	for ty in fv.battle.grid.h:
		for tx in fv.battle.grid.w:
			var g: float = fv._ground_h(tx, ty)
			lo = minf(lo, g)
			hi = maxf(hi, g)
	print("ground height across the island: %.2f .. %.2f tiles (%.0f .. %.0f px)"
		% [lo, hi, lo * Look.TILE_PX, hi * Look.TILE_PX])

	print("\n== a body on that ground ==")
	# The same call the drawing uses, asked at the lowest and the highest land tile on the island.
	var low_t := Vector2i.ZERO
	var high_t := Vector2i.ZERO
	for ty in fv.battle.grid.h:
		for tx in fv.battle.grid.w:
			var g: float = fv._ground_h(tx, ty)
			if fv._char_at(tx, ty) != ".":
				continue
			if g <= fv._ground_h(low_t.x, low_t.y) or fv._char_at(low_t.x, low_t.y) != ".":
				low_t = Vector2i(tx, ty)
			if g >= fv._ground_h(high_t.x, high_t.y):
				high_t = Vector2i(tx, ty)
	print("lowest land tile  %s stands at %.2f" % [low_t, fv._ground_h(low_t.x, low_t.y)])
	print("highest land tile %s stands at %.2f" % [high_t, fv._ground_h(high_t.x, high_t.y)])
	print("difference: %.2f tiles = %.0f px — that is how far a wolf is lifted walking between them"
		% [fv._ground_h(high_t.x, high_t.y) - fv._ground_h(low_t.x, low_t.y),
		(fv._ground_h(high_t.x, high_t.y) - fv._ground_h(low_t.x, low_t.y)) * Look.TILE_PX])

	print("\n== what the sim thinks ==")
	print("Grid has a height field: %s" % ("yes" if "height" in fv.battle.grid else "no"))
	print("soldier_pos is a %s" % ["Vector2 (x, y) — two numbers, no height"])
