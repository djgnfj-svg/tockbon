# **The same 판, at six tones: three lighter than the ground and three darker.**
#
# ⚠⚠ **This is a CANDIDATE SHEET, not a prototype set.** Every shot below is one implementation with
# one dial moved — which is exactly what `prototype`'s own first rule says a set must NOT be. It is
# here because the mechanism is already settled (a baked 판 per 조각) and the only open question is
# the number (2026-08-29, the user: 「밝게해보자 어둡게도 해서 프로토 타입으로 보는게 목적」).
#
# Run it on whatever `island.glb` is baked right now:
#   Godot_v4.7.1-stable_win64.exe --path . -s prototypes/pads/look_sheet.gd -- <tag>
# `<tag>` names the bake in the filenames — `narrow` and `wide` are the two gaps being compared.
#
# ⚠ **Never `--headless`**: there is no swapchain to read a frame back from and every PNG comes out
# black with no error anywhere.
extends SceneTree

const OUT := "res://prototypes/pads/out/look_%s_%s_%s.png"
## **Signed**: positive pulls the 판 toward white, negative toward black. The resting value the game
## ships is +0.25, and it sits in the middle of the light half on purpose.
const TONES := [
	["light3", 0.45],
	["light2", 0.25],
	["light1", 0.12],
	["dark1", -0.12],
	["dark2", -0.25],
	["dark3", -0.45],
]
const NEAR_NOTCHES := 5

var _game: Game = null
var _tag := "bake"
var _i := 0
var _wait := 0
var _boot := 0
var _booted := false


func _initialize() -> void:
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	_game = Game.new()
	root.add_child(_game)
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if not a.begins_with("-") and not a.ends_with(".gd") and a != "--path" and a != ".":
			_tag = a


func _process(_d: float) -> bool:
	_wait += 1
	if _wait < 4:
		return false
	_wait = 0
	if not _booted:
		return _boot_step()
	return _shoot_step()


func _boot_step() -> bool:
	match _boot:
		0:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = Look.title_slot_hit_rect_px(0).get_center()
			_game._unhandled_input(ev)
		1:
			for _n in 120:
				_game._process(1.0 / 60.0)
		2:
			var f: FieldView = _game.field_view
			f.set_pads_revealed(true)
			# ⚠ **A photographed run has no cursor**, so one 조각 is hovered by hand — two east of the
			# body, in frame and clear of the body's own picture.
			var b: Vector2i = _body_tile()
			f.set_hover_tile(_game.battle.grid.tile_index(b.x + 2, b.y))
			_booted = true
	_boot += 1
	return false


func _body_tile() -> Vector2i:
	var b := _game.battle
	for uid in b.ashore_ids():
		var p: Vector2 = b.soldier_pos[uid]
		return Vector2i(int(p.x), int(p.y))
	return Vector2i(b.grid.w / 2, b.grid.h / 2)


func _shoot_step() -> bool:
	var per := 4
	var k: int = _i / per
	if k >= TONES.size():
		return true
	var name: String = str(TONES[k][0])
	match _i % per:
		0:
			_game.field_view._pads_mat.set_shader_parameter("all_lighten", float(TONES[k][1]))
		1:
			_save(name, "far")
		2:
			_zoom(NEAR_NOTCHES)
		3:
			_save(name, "near")
			_zoom(-NEAR_NOTCHES)
	_i += 1
	return false


func _zoom(notches: int) -> void:
	var at := Look.viewport_size_px() * 0.5
	var f := Look.ZOOM_STEP if notches > 0 else 1.0 / Look.ZOOM_STEP
	for _n in absi(notches):
		_game.field_view.zoom_at(at, f)


func _save(name: String, which: String) -> void:
	root.get_texture().get_image().save_png(
		ProjectSettings.globalize_path(OUT % [_tag, name, which]))
	print("[look] %s %s %s" % [_tag, name, which])
