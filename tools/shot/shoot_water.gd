# **Six seas, one island, one camera.** Saves `tools/shot/out/water/water_N_<name>.png`, one per candidate.
#
# WARNING **This exists because the sea cannot be decided in words** (2026-08-26, the user: "흠 아직은
# 좀 애매하네 어딜 어떻게 수정해야 할지도 애매하고"). The dials that matter -- ripple strength, swell
# size, contrast, colour -- do not describe themselves. Rendering the candidates and putting them side
# by side is the only thing that has ever settled a look in this repo.
#
# WARNING **It overrides the shader's uniforms and writes NOTHING back.** The values that ship live in
# `src/look.gd`; when a candidate wins, its numbers are copied there by hand. Nothing here is a source.
#
# Run (a window has to open -- a headless run has no renderer to read a frame back from):
#   Godot_v4.7.1-stable_win64.exe --path . -s tools/shot/shoot_water.gd
extends SceneTree

const SHOT := "res://tools/shot/out/water/water_%d_%s.png"

# Each row is a whole LOOK, not one dial: a sea reads as a sea or does not, and moving one number at a
# time produces six pictures nobody can tell apart.
const LOOKS := [
	{
		"name": "1_unbroken",
		"ripple_chop": 0.0,
	},
	{
		"name": "2_dashes",
		"ripple_chop": 1.4,
	},
	{
		"name": "3_shorter",
		"ripple_chop": 2.6,
	},
	{
		"name": "4_shorter_wider",
		"ripple_chop": 2.6,
		"ripple_stretch": 0.55,
	},
]

var _game: Game = null
var _step := 0
var _wait := 0
var _shot := 0


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


func _sea_material() -> ShaderMaterial:
	return _game.field_view._sea.material_override as ShaderMaterial


func _apply(look: Dictionary) -> void:
	# Every candidate starts from the shipped values, so an omitted key means "unchanged" rather than
	# "whatever the previous candidate left behind".
	var mat := _sea_material()
	mat.set_shader_parameter("trough", Look.COL_WATER)
	mat.set_shader_parameter("crest", Look.COL_WATER_CREST)
	mat.set_shader_parameter("wave_scale", Look.WATER_WAVE_SCALE)
	mat.set_shader_parameter("wave_speed", Look.WATER_WAVE_SPEED)
	mat.set_shader_parameter("contrast", Look.WATER_CONTRAST)
	mat.set_shader_parameter("ripple_scale", Look.WATER_RIPPLE_SCALE)
	mat.set_shader_parameter("ripple_speed", Look.WATER_RIPPLE_SPEED)
	mat.set_shader_parameter("ripple_strength", 4.2)
	mat.set_shader_parameter("foam", Look.COL_WATER_FOAM)
	mat.set_shader_parameter("foam_tiles", Look.WATER_FOAM_TILES)
	mat.set_shader_parameter("foam_speed", Look.WATER_FOAM_SPEED)
	mat.set_shader_parameter("foam_bands", Look.WATER_FOAM_BANDS)
	mat.set_shader_parameter("foam_sharp", Look.WATER_FOAM_SHARP)
	mat.set_shader_parameter("foam_break", Look.WATER_FOAM_BREAK)
	mat.set_shader_parameter("foam_break_scale", Look.WATER_FOAM_BREAK_SCALE)
	mat.set_shader_parameter("foam_lip_tiles", Look.WATER_FOAM_LIP_TILES)
	mat.set_shader_parameter("foam_lee", Look.WATER_FOAM_LEE)
	mat.set_shader_parameter("foam_sharp", Look.WATER_FOAM_SHARP)
	mat.set_shader_parameter("ripple_fade_tiles", Look.WATER_RIPPLE_FADE)
	mat.set_shader_parameter("ripple_wind_deg", Look.WATER_RIPPLE_WIND_DEG)
	mat.set_shader_parameter("ripple_stretch", Look.WATER_RIPPLE_STRETCH)
	mat.set_shader_parameter("ripple_chop", Look.WATER_RIPPLE_CHOP)
	mat.set_shader_parameter("shallow", Look.COL_WATER_SHALLOW)
	mat.set_shader_parameter("shallow_tiles", Look.WATER_SHALLOW_TILES)
	for key in look.keys():
		if key == "name":
			continue
		mat.set_shader_parameter(str(key), look[key])


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(
		ProjectSettings.globalize_path(SHOT % [_shot, name]))
	print("[water] %d %s" % [_shot, name])
	_shot += 1


func _process(_delta: float) -> bool:
	_wait += 1
	if _wait < 6:
		return false
	_wait = 0
	match _step:
		0:
			_game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
		1:
			_game._unhandled_input(_click(Look.card_rect_px(0).get_center()))
		2:
			_game._unhandled_input(_click(_game.refit_view.done_hit_rect().get_center()))
		3:
			# Close enough that the ripple is above a pixel, far enough that a whole stretch of open
			# sea is in frame -- the two things being judged have to be in the same picture.
			# ⚠ A few steps in: the ripple fades with distance from the camera, so a sheet shot from the
			# opening zoom shows a flat sea in every candidate and settles nothing.
			for _i in 3:
				_game._unhandled_input(_wheel_up())
			# WARNING **Do not zoom ALL the way in.** The first sheet was shot close and the island filled it:
			# six pictures of a house with a sliver of sea, and nobody could tell four of them apart.
			# The thing being judged has to be most of the frame.
			# The clock is advanced ONCE, before the set, and never between shots: every candidate is
			# then the same instant of the same sea and the only difference is the dials.
			for _i in 120:
				_game._process(1.0 / 60.0)
		_:
			# WARNING **Set on one step, SHOOT ON THE NEXT.** `get_texture()` hands back the frame that
			# was already drawn, so applying and saving in the same step saved every candidate one look
			# behind -- the first sheet had `deep_green`'s colours filed under `sharp` and the last look
			# missing entirely. A picture of the wrong thing does not announce itself.
			var i := (_step - 4) / 2
			if i >= LOOKS.size():
				return true
			var look: Dictionary = LOOKS[i]
			if (_step - 4) % 2 == 0:
				_apply(look)
			else:
				_save(str(look["name"]))
	_step += 1
	return false
