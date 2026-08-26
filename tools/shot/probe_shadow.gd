# **Takes the keep's shadow apart.** Not a net — it saves four pictures of the same frame with one
# thing switched off in each, so which of the two shadow systems is missing can be SEEN rather than
# argued about.
#
# There are two of them and they are unrelated:
#   · the SUN's real shadow map — every mesh with `cast_shadow` on throws one
#   · the drawn blob — a dark disc laid flat under each prop and building by `_blob`
#
# Run:
#   Godot_v4.7.1-stable_win64.exe --path . -s tools/shot/probe_shadow.gd
extends SceneTree

const SHOT := "res://tools/shot/shadow_%s.png"

var _game: Game = null
var _step := 0
var _wait := 0
var _blobs: Array[Node] = []


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


func _wheel_up() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	ev.position = Look.viewport_size_px() * 0.5
	return ev


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(SHOT % name))
	print("[shadow] %s" % name)


## Every blob under the buildings node: a `_blob` is the only child there that is not the building.
func _find_blobs() -> void:
	_blobs.clear()
	var fv := _game.field_view
	for holder in [fv.get("_builds"), fv.get("_props")]:
		if holder == null:
			continue
		for c in (holder as Node).get_children():
			var m := c as MeshInstance3D
			if m != null and m.mesh is QuadMesh:
				_blobs.append(m)


func _sun() -> DirectionalLight3D:
	return _game.field_view.get("_sun") as DirectionalLight3D


func _env() -> Environment:
	for c in (_game.field_view.get("_world") as Node).get_children():
		var w := c as WorldEnvironment
		if w != null:
			return w.environment
	return null


func _fill() -> DirectionalLight3D:
	var found: DirectionalLight3D = null
	for c in (_game.field_view.get("_world") as Node).get_children():
		var d := c as DirectionalLight3D
		if d != null and not d.shadow_enabled:
			found = d
	return found


func _process(_delta: float) -> bool:
	_wait += 1
	if _wait < 6:
		return false
	_wait = 0
	# **One sun, and a day that turns** (2026-08-26, the user: 「하나만 있으면 될듯 / 해도 시간이 지나면서
	# 지면 좋을듯」). Three things move together here: the drawn blob comes OFF (it has no direction, so a
	# turning sun would leave it pointing nowhere), the fill light comes OFF, and the ambient comes UP to
	# replace what the fill was doing. Then the sun is walked from noon to sunset.
	# columns: name, blob, fill, ambient, sun pitch, sun yaw, sun colour, ambient colour
	var probes := [
		["k1_now", true, true, -1.0, -52.0, -35.0, Color(1,1,1), Color(0,0,0)],
		["k2_one_sun", false, false, 0.92, -52.0, -35.0, Color(1.0,0.97,0.90), Color(0.62,0.72,0.85)],
		["k3_afternoon", false, false, 0.88, -30.0, -70.0, Color(1.0,0.93,0.80), Color(0.60,0.70,0.86)],
		["k4_sunset", false, false, 0.80, -13.0, -105.0, Color(1.0,0.72,0.48), Color(0.42,0.44,0.70)],
	]
	match _step:
		0:
			_game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
		1:
			_game._unhandled_input(_click(Look.card_rect_px(0).get_center()))
		2:
			_game._unhandled_input(_click(_game.refit_view.done_hit_rect().get_center()))
		3:
			for _i in 30:
				_game._process(1.0 / 60.0)
			for _i in 16:
				_game._unhandled_input(_wheel_up())
			_find_blobs()
		_:
			var i := _step - 4
			if i >= probes.size() * 2:
				return true
			if i % 2 == 0:
				var r := probes[i / 2] as Array
				for b in _blobs:
					(b as Node3D).visible = bool(r[1])
				var f := _fill()
				if f != null:
					f.visible = bool(r[2])
				if float(r[3]) > 0.0:
					var e := _env()
					if e != null:
						e.ambient_light_energy = float(r[3])
						e.ambient_light_color = r[7]
					_sun().rotation_degrees = Vector3(float(r[4]), float(r[5]), 0.0)
					_sun().light_color = r[6]
			else:
				var r2 := probes[i / 2] as Array
				print("[k] %s" % str(r2[0]))
				_save(str(r2[0]))
	_step += 1
	return false
