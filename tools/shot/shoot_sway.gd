# **A throwaway probe: the wind, one PNG per step, so the sway can be looked at as motion.**
#
# ⚠ **Not a net.** It asserts nothing. It exists because a still picture cannot answer 「does the map
# stop looking monotonous」 — the frames it writes are assembled into one animation outside Godot.
#
# ⚠⚠ **The clock is advanced by CALLING `_process` with a fixed delta**, never by waiting. A probe
# that slept would sample the wind at whatever moment the machine happened to be at, and two runs
# would not be comparable. This one is deterministic: frame `n` is always the same picture.
#
# Run (a window has to open — a headless run has no renderer to read a frame back from):
#   Godot_v4.7.1-stable_win64.exe --path . -s tools/shot/shoot_sway.gd
extends SceneTree

const SHOT := "res://tools/shot/out/field/sway_%02d.png"
## One full lean cycle is `1 / Look.PROP_SWAY_HZ` seconds. Twenty steps across it is smooth enough
## to read as motion and few enough to assemble by hand.
const STEPS := 20
## Where to look and how wide, in 조각 — the bush row, which is what the question was about.
const AT := Vector2(11.0, 15.6)
const WIDE := 16.0

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


func _aim() -> void:
	var fv := _game.field_view
	fv.zoom = Look.VIEWPORT_W_PX / (WIDE * Look.TILE_PX)
	var half := fv._visible_ground_px() * 0.5
	fv.cam_px = Vector2(AT.x * Look.TILE_PX, AT.y * Look.TILE_PX) - half


func _process(_delta: float) -> bool:
	_wait += 1
	if _wait < 4:
		return false
	_wait = 0
	if _step == 0:
		_game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
		_step += 1
		return false
	var i := (_step - 1) / 2
	if i >= STEPS:
		return true
	if (_step - 1) % 2 == 0:
		# ⚠ **Aim every step** — the shell keeps running between them and would drift the camera.
		_aim()
		# ⚠⚠ **The wind's clock is SET, not advanced.** The engine is ticking this scene too, so
		# adding a delta here would sample the wind wherever the machine happened to be and two runs
		# would not match. Setting it makes frame `i` the same picture every run.
		var fv := _game.field_view
		fv._sway_clock = (1.0 / Look.PROP_SWAY_HZ) * float(i) / float(STEPS)
		fv._paint_sway(0.0)
	else:
		# ⚠ **A frame late, always.** `get_texture()` hands back the last frame the renderer DREW,
		# so reading on the same tick the camera moved saves the picture from before the move.
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(SHOT % i))
		print("[sway] %02d" % i)
	_step += 1
	return false
