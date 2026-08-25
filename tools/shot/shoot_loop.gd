# Plays **one whole loop** through the real shell and photographs every screen it passes: title, map,
# island, verdict, cards, refit, back to the map. **Not a net** — it asserts nothing.
#
# ⚠⚠ **It is driven off `run.state()`, not off a step list.** A scripted list of clicks says what the
# loop was believed to be; reading the state each frame says what it IS, and a loop that stalls shows
# up as the same screen twice instead of as a script that ran to the end regardless.
#
# Run (a window has to open — a headless run has no renderer to read a frame back from):
#   Godot_v4.7.1-stable_win64.exe --path . -s tools/shot/shoot_loop.gd
extends SceneTree

const SHOT := "res://tools/shot/loop_%02d_%s.png"
const FRAME_SEC := 1.0 / 60.0
## How many engine frames the whole thing gets before it is called stuck. A 60 s island stepped one
## sim frame per engine frame is 3600, and a loop is at most three islands.
const GIVE_UP := 20000

var _game: Game = null
var _shots := 0
var _frames := 0
var _last := ""
var _at_title := true
## Which card the next press goes to. **It walks**: a taken card stops being pressable, so pressing
## the same one twice is a screen that never advances — which is exactly how this first stalled.
var _card_k := 0
## Frames to let a screen SETTLE before it is photographed. The card screen fades in from black, and
## caught on the frame it appears it photographs as an empty dark rectangle — a shot that reads as
## "the cards do not draw" when what happened is that they had not started.
var _settle := 0


func _initialize() -> void:
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	_game = Game.new()
	root.add_child(_game)


func _click(at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	_game._unhandled_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = at
	_game._unhandled_input(up)


func _move(at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	_game._unhandled_input(ev)


func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = code
	_game._unhandled_input(ev)


func _save(what: String) -> void:
	_shots += 1
	root.get_texture().get_image().save_png(
		ProjectSettings.globalize_path(SHOT % [_shots, what]))
	print("[loop] %02d %s" % [_shots, what])


## Where the loop is, as one word. **The name of the shot and the thing that decides an action are the
## same string**, so a screen that is photographed is a screen that was recognised.
func _where() -> String:
	if _at_title:
		return "title"
	match _game.run.state():
		Run.State.MAP:
			return "map"
		Run.State.BATTLE:
			if _game.battle == null:
				return "opening"
			return "plan" if not _game.battle.committed() else "fight"
		Run.State.PICK:
			return "cards"
		Run.State.REFIT:
			return "refit"
		Run.State.WON:
			return "won"
		Run.State.LOST:
			return "lost"
	return "unknown"


## The `n`-th summonable tile in scan order, as the screen point that lands on it.
##
## ⚠ **Aimed with the SHELL'S map of the screen** (`field_view.screen_to_world_px`'s own inverse) and
## not with the camera's projection: those two disagree, because the shell still reads a press against
## a flat plane while the terrain has height. Aiming with the camera's makes every press miss.
func _summon_px(n: int) -> Vector2:
	var fv := _game.field_view
	var g := _game.battle.grid
	var seen := 0
	for t in g.w * g.h:
		if not g.can_summon_at(t):
			continue
		if seen < n:
			seen += 1
			continue
		# The VIEW's own forward, and not a copy of it. Three probes and three shooters each carried a
		# private one; all six were the flat board's, all six ignored the yaw, and every click they
		# aimed landed on a tile next to the one it meant (2026-08-25).
		var tx := t % g.w
		var ty := t / g.w
		return fv.tile_to_screen_px(tx, ty)
	return Vector2.ZERO


func _summon_count() -> int:
	var g := _game.battle.grid
	var n := 0
	for t in g.w * g.h:
		if g.can_summon_at(t):
			n += 1
	return n


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > GIVE_UP:
		print("[loop] gave up at %s after %d frames" % [_where(), _frames])
		return true
	var here := _where()
	# A screen is photographed the first frame it is reached, before it is acted on: the shot is of
	# what the loop actually put on screen, not of what one click later made of it.
	if here != _last:
		_last = here
		_settle = Look.FX_SETTLE_FRAMES
		return false
	if _settle > 0:
		_settle -= 1
		_game._process(FRAME_SEC)
		_game.field_view._process(FRAME_SEC)
		if _settle == 0:
			_save(here)
		return false
	match here:
		"title":
			_click(Look.title_slot_hit_rect_px(0).get_center())
			_at_title = false
		"map":
			var open_nodes := _game.run.map.reachable_nodes()
			if open_nodes.size() > 0:
				_click(Look.map_node_pos_px(int(open_nodes[0])))
			_game._process(Look.MAP_TRAVEL_SEC)
		"opening":
			_game._process(FRAME_SEC)
		"plan":
			# Everything the two slots hold, onto the two cheapest beaches, then start. The probe
			# already measured that this is the dominant plan; it is here because it is also the
			# simplest thing that produces a fight to photograph.
			var spots := _summon_count()
			for slot in 2:
				_key(KEY_1 + slot)
				# **Pressed until the slot stops sending.** One press sends one boat with what the slot
				# holds; pressing once left two wolves against eight cavemen and the run was lost on the
				# first island. Spread over four points of the ring so the landings are not one beach.
				# ⚠ **All four boats at ONE point.** Spread over four beaches the landing force arrives in
				# four pieces and is beaten in four pieces; this is what a player who has seen one fight
				# would do, and the difference between the two is the measurement.
				for k in 4:
					var at := _summon_px(int(float(spots) * 0.5))
					_move(at)
					_click(at)
			print("[loop] sent %d, ashore-to-be %d" % [_game.battle.boats.size(),
				_game.battle.transit_ids().size()])
			_click(Look.start_rect_px().get_center())
		"fight":
			_game._process(FRAME_SEC)
			_game.field_view._process(FRAME_SEC)
		"cards":
			_click(Look.card_hit_rect_px(_card_k).get_center())
			_card_k += 1
		"refit":
			_click(Rect2(Look.REFIT_DONE_ORIGIN_PX, Look.REFIT_BUTTON_SIZE_PX).get_center())
		"won", "lost":
			print("[loop] finished at %s after %d frames" % [here, _frames])
			return true
	return false
