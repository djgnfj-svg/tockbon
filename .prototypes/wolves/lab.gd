# Stands every wolf candidate in the REAL game and photographs them.
#
# ⚠⚠ **ONE INSTANT, ONE CAMERA, SIX PICTURES.** The sim is frozen (`set_process(false)` on the game and
# on the field, so nothing advances unless this file says so), the candidate's picture is dropped into
# the field's own `_tex_facing` row, the field is repainted with a ZERO delta, and the frame is saved.
# Nothing else in the world moves between the six, so the only difference in the pictures is the wolf.
#
# ⚠ **`.prototypes/` is NOT imported by Godot**, so the candidates are read with `Image.load` at an
# absolute path. `load("res://.prototypes/...")` returns null here and always will.
#
# ⚠ **Never `--headless`** — there is no swapchain to read the frame back from and every PNG comes out
# black with no error.
#
# Run:
#   Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/wolves/lab.gd
extends SceneTree

const OUT := "res://.prototypes/wolves/out/%s.png"
## ⚠⚠ **THE CANDIDATES LIVE IN `.candidates/`, NOT HERE.** Nothing in that folder is ever deleted, so
## a sheet can be re-photographed months later. ⚠ `.candidates/` is dot-prefixed for the same reason
## this folder is — Godot imports everything else — so these are read with `Image.load`, never `load()`.
const PICS := "res://.candidates/wolf/2026-08-31-%s.png"
const WHERE := "res://.prototypes/wolves/out/where.json"

## The 64 px round, and the wolf standing in the game today as the control. ⚠ **`now` is a FILE here
## too**, not the shipped row: the frame is 64 px now, so the control is the shipped picture padded
## onto a canvas that makes it draw the 30 px it actually draws in the game. Reading the shipped row
## instead would silently enlarge the thing everything else is being measured against.
## ⚠ **g1 IS NOT HERE AND THAT IS THE POINT** — `ground.py` measured a patch of ground stuck under its
## paws, and a billboard drags that patch over the grass with it.
const NAMES := ["installed", "g5_two_greys"]

var _game: Game = null
var _step := 0
var _wait := 0
var _tex := {}
var _now_pics: Array = []
var _where := {}
var _sweep: Array = []
var _tag := ""
var _spun := 0


func _initialize() -> void:
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	_game = Game.new()
	root.add_child(_game)
	for n in NAMES:
		if n == "installed":
			continue
		var img := Image.new()
		var path := ProjectSettings.globalize_path(PICS % n)
		if img.load(path) != OK:
			push_error("could not load %s" % path)
			continue
		_tex[n] = ImageTexture.create_from_image(img)
	print("[lab] loaded %d candidates" % _tex.size())


func _click(at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	return ev


func _advance(n: int) -> void:
	for _i in n:
		_game._process(1.0 / 60.0)
		_game.field_view._process(1.0 / 60.0)


func _apply(name: String) -> void:
	var fv := _game.field_view
	# ⚠ **`installed` overrides NOTHING.** It photographs the pictures the game itself loaded, which is
	# the only shot that can say the chosen wolf actually reached `assets/`.
	if name != "installed":
		var t: Texture2D = _tex[name]
		fv._tex_facing[Rules.WOLF] = [t, t, t, t]
	# Zero delta: repaint with the new picture without letting one tick of time pass.
	fv._process(0.0)


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT % name))
	print("[lab] %s" % name)


## A boat still crossing with beasts aboard, or -1.
func _boat_index() -> int:
	var b := _game.battle
	for i in b.boat_riders.size():
		if b.boat_riders[i] > 0 and b.boat_state[i] == Battle.BoatState.SAILING:
			return i
	return -1


## A beast that has stepped off and is still alive, or -1.
func _enemy_index() -> int:
	var b := _game.battle
	for i in b.enemy_alive.size():
		if b.enemy_alive[i] != 0:
			return i
	return -1


func _mark(tag: String, at_tiles: Vector2) -> void:
	var p := _game.field_view.world_to_screen_px(Look.tile_point_px(at_tiles))
	_where[tag] = [p.x, p.y]
	print("[lab] %s at %.0f, %.0f" % [tag, p.x, p.y])


func _sweep_tick() -> bool:
	_wait += 1
	if _wait == 1:
		_apply(_sweep[0])
		return false
	if _wait < 4:
		return false
	_wait = 0
	_save("%s_%s" % [_tag, _sweep[0]])
	_sweep.pop_front()
	return false


func _process(_delta: float) -> bool:
	if _sweep.size() > 0:
		return _sweep_tick()

	_wait += 1
	if _wait < 6:
		return false
	_wait = 0

	match _step:
		0:
			_game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
		1:
			# From here time only moves when this file says so.
			_game.set_process(false)
			_game.field_view.set_process(false)
			_now_pics = _game.field_view._tex_facing[Rules.WOLF]
			print("[lab] frozen; control row has %d pictures" % _now_pics.size())
		2:
			# Wait for a boat that is still crossing with beasts on it, then bring the camera to it —
			# ⚠ **the first such boat is routinely off the left of the glass**, and a crop of an empty
			# stretch of sea is what the first run of this file produced.
			var bi := _boat_index()
			if bi < 0:
				_advance(60)
				_spun += 1
				if _spun < 60:
					return false
				print("[lab] no boat after %d seconds — shooting anyway" % _spun)
			else:
				var fv := _game.field_view
				var at := Look.tile_point_px(_game.battle.boat_pos[bi])
				fv.pan_by(Look.viewport_size_px() * 0.5 - fv.world_to_screen_px(at))
				fv._process(0.0)
				_mark("boat", _game.battle.boat_pos[bi])
			_tag = "boat"
			_sweep = NAMES.duplicate()
			_spun = 0
		3:
			# Then wait for one of them to be ashore.
			var ei := _enemy_index()
			if ei < 0:
				_advance(60)
				_spun += 1
				if _spun < 90:
					return false
				print("[lab] nothing ashore after %d seconds — shooting anyway" % _spun)
			else:
				var fv2 := _game.field_view
				var at2 := Look.tile_point_px(_game.battle.enemy_pos[ei])
				fv2.pan_by(Look.viewport_size_px() * 0.5 - fv2.world_to_screen_px(at2))
				fv2._process(0.0)
				_mark("land", _game.battle.enemy_pos[ei])
			_tag = "land"
			_sweep = NAMES.duplicate()
		4:
			# ⚠ **One wolf, alone.** Everything else is put down so the frame carries the animal and
			# nothing else — the user asked to see one on the map with no crowd around it. The sim is
			# frozen, so killing the rest changes no state that anything downstream reads.
			var keep := _enemy_index()
			if keep >= 0:
				var b := _game.battle
				for i in b.enemy_alive.size():
					if i != keep:
						b.enemy_alive[i] = 0
				var fv3 := _game.field_view
				var at3 := Look.tile_point_px(b.enemy_pos[keep])
				fv3.pan_by(Look.viewport_size_px() * 0.5 - fv3.world_to_screen_px(at3))
				fv3._process(0.0)
				_mark("one", b.enemy_pos[keep])
			_tag = "one"
			_sweep = NAMES.duplicate()
		5:
			var f := FileAccess.open(ProjectSettings.globalize_path(WHERE), FileAccess.WRITE)
			f.store_string(JSON.stringify(_where))
			f.close()
			print("[lab] done")
			return true
	_step += 1
	return false
