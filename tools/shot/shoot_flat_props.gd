# **A throwaway probe: the 2D 시안 rows photographed at the size the game draws them.**
#
# ⚠ **Not a net and not a keeper.** It exists for one round — the trees and bushes stand on the island
# as one prop kind each so the choice is made on screen (2026-08-31, the user: 「the tree might have to
# be seen applied in the game」). **Delete it with the losing 시안.**
#
# ⚠ **It drives the real shell** — title, then the island — and then puts the camera where it wants
# rather than clicking there, because a drag in screen px is a different distance at every zoom and
# this has to land on the same 조각 every run.
#
# Run (a window has to open — a headless run has no renderer to read a frame back from):
#   Godot_v4.7.1-stable_win64.exe --path . -s tools/shot/shoot_flat_props.gd
extends SceneTree

const SHOT := "res://tools/shot/out/field/flat_%s.png"

## Where each row was placed by `island.json`, in 조각. **Read off the placement, not guessed** — the
## trees sit on row 3 from x 4 and the bushes on row 14, both two 조각 apart.
## ⚠ **The widths hold all of a row.** Eight trees sit on x 4..18 and nine bushes on x 4..20, both two
## 조각 apart, so a 13-조각 view clips the ends — the first cut did and lost two of the eight.
const AIMS := [
	["trees", 11.0, 3.4, 17.0, 0.0],
	["bushes", 11.0, 15.6, 16.0, 0.0],
	["trees_near", 7.0, 3.4, 8.0, 0.0],
	["bushes_near", 8.0, 14.4, 8.0, 0.0],
	["trees_with_man", 11.0, 8.0, 17.0, 0.0],
	# ⚠⚠ **The same trees at three yaws, and this is a MEASUREMENT, not a picture.** 개발지식 01
	# 기법 14 says a billboard's real shadow swings as the board turns, and the baked trees cast one
	# (`ALPHA_CUT_DISCARD` lets a `Sprite3D` into the shadow pass). **If the shadow swings, that is
	# the cost of drawing a tree flat**, and it is the only thing 3D buys that is not taste.
	["yaw_00", 11.0, 3.4, 10.0, 0.0],
	["yaw_45", 11.0, 3.4, 10.0, 45.0],
	["yaw_90", 11.0, 3.4, 10.0, 90.0],
]

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


func _process(_delta: float) -> bool:
	_wait += 1
	if _wait < 6:
		return false
	_wait = 0
	if _step == 0:
		_game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
		_step += 1
		return false
	# ⚠⚠ **AIMING AND SAVING ARE DIFFERENT STEPS, AND THE FIRST CUT OF THIS FILE HAD THEM AS ONE.**
	# `get_texture()` hands back the LAST FRAME THE RENDERER DREW, so moving the camera and reading
	# the viewport in the same step saves the picture from before the move — four shots of the survey
	# view came out that way and nothing failed. **This is the same trap `shoot_field.gd`'s own header
	# warns about**: nothing here can go red, so a wrong picture is saved silently.
	var i := (_step - 1) / 2
	if i >= AIMS.size():
		return true
	var aim: Array = AIMS[i]
	if (_step - 1) % 2 == 1:
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(SHOT % aim[0]))
		print("[shot] %s" % aim[0])
		_step += 1
		return false
	var fv := _game.field_view
	# `zoom` is a plain multiplier, so how many 조각 fit across is `VIEWPORT_W_PX / zoom / TILE_PX`.
	# ⚠ **Set BEFORE the aim** — the visible ground the aim subtracts from is a function of it.
	fv.zoom = Look.VIEWPORT_W_PX / (float(aim[3]) * Look.TILE_PX)
	# ⚠⚠ **`cam_px` IS THE TOP-LEFT CORNER OF THE VISIBLE GROUND, NOT ITS CENTRE.** Assigning the
	# target 조각 straight into it put the aim half a screen out and the first four shots looked at
	# the middle of the island instead of the row. The file's own header says so at the top.
	fv.cam_yaw_deg = Look.CAM_YAW_DEG + float(aim[4])
	# ⚠ **After the yaw** — the visible ground is read in the camera's own axes.
	var half := fv._visible_ground_px() * 0.5
	fv.cam_px = Vector2(float(aim[1]) * Look.TILE_PX, float(aim[2]) * Look.TILE_PX) - half
	fv._process(1.0 / 60.0)
	_step += 1
	return false
