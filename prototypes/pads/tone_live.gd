# **The 판's tone, switched live in the real game.**
#
# ⚠ Judging six tones off a contact sheet is slow; this puts them on one key each.
#   Godot_v4.7.1-stable_win64.exe --path . -s prototypes/pads/tone_live.gd
# **1..6 pick a tone · TAB is the game's own reveal · wheel zooms · ESC quits.**
extends SceneTree

const TONES := [
	["1 light3  +0.45", 0.45], ["2 light2  +0.25", 0.25], ["3 light1  +0.12", 0.12],
	["4 dark1   -0.12", -0.12], ["5 dark2   -0.25", -0.25], ["6 dark3   -0.45", -0.45],
]

var _g: Game = null
var _label: Label = null
var _i := 1
var _boot := 0
var _wait := 0
var _ready := false
var _held := {}


func _initialize() -> void:
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	_g = Game.new()
	root.add_child(_g)


func _process(_d: float) -> bool:
	if _ready:
		return _watch()
	_wait += 1
	if _wait < 4:
		return false
	_wait = 0
	match _boot:
		0:
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.pressed = true
			e.position = Look.title_slot_hit_rect_px(0).get_center()
			_g._unhandled_input(e)
		1:
			for _n in 90:
				_g._process(1.0 / 60.0)
		2:
			_g.field_view.set_pads_revealed(true)
			_label = Label.new()
			_label.position = Vector2(14, 10)
			_label.add_theme_font_size_override("font_size", 24)
			_label.add_theme_color_override("font_color", Color(1, 1, 1))
			_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
			_label.add_theme_constant_override("outline_size", 6)
			root.add_child(_label)
			_ready = true
			_show(_i)
	_boot += 1
	return false


func _show(k: int) -> void:
	_i = posmod(k, TONES.size())
	_g.field_view._pads_mat.set_shader_parameter("all_lighten", float(TONES[_i][1]))
	_label.text = "%s\n1..6 tone · TAB reveal · wheel zoom · ESC quit" % str(TONES[_i][0])


func _tap(code: Key) -> bool:
	var down := Input.is_key_pressed(code)
	var was: bool = _held.get(code, false)
	_held[code] = down
	return down and not was


func _watch() -> bool:
	if Input.is_key_pressed(KEY_ESCAPE):
		return true
	for n in TONES.size():
		if _tap((KEY_1 + n) as Key):
			_show(n)
	# ⚠ **The reveal is forced back on every frame.** TAB is the game's own key and letting go of it
	# would leave the board blank while a tone is being judged.
	_g.field_view.set_pads_revealed(true)
	return false
