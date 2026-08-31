# **Nine bodies in ONE 블록 (칸), placed six different ways, facing two directions.**
#
# ⚠⚠ **THE SIM IS FROZEN WHILE THIS RUNS** — see `_freeze`. The nine are real bodies in a real fight
# and the fight kept nudging them off the seats the lab had just written, once per frame, which read
# as every 검사 vibrating in place. **Nothing here is a moving picture; it is nine men standing still.**
#
# ⚠⚠ **This lab drives the REAL game**, the way `.prototypes/pads/lab.gd` does: the nine stand on the
# ground the game ships, under its own camera, sun and sea, and **they are drawn by `FieldView`'s own
# body path** — same texture, same billboard, same ground disc. A body drawn by the lab itself would
# be a picture of the lab.
#
# **Two ways to run it, and the default is the one you WATCH.**
#
#   Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/nine/lab.gd
#       opens a window and stays. **1..5 pick a version · LEFT/RIGHT step · SPACE swaps body size.**
#       The game's own keys still work — Q/E turn, R/F tilt, wheel zooms. ESC quits.
#
#   Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/nine/lab.gd -- shoot
#       photographs every version at every size and quits.
#
# ⚠ **Never `--headless`**: there is no swapchain to read a frame back from and every PNG comes out
# black with no error anywhere.
#
# **A version is a folder with a `scene.gd` carrying two statics**:
#   `static func title() -> String`
#   `static func seats(c: Vector2, face: Vector2) -> PackedVector2Array`   # nine, in 조각 position units
extends SceneTree

const DIR := "res://.prototypes/nine"
const OUT := "res://.prototypes/nine/out/%s_%s.png"
## How many bodies stand in the 블록.
const NINE := 9
## The body sizes SPACE steps through in the watched run. **1.0 is exactly what the game ships.**
## ⚠ **The shoot no longer sweeps these** — see `FACES`.
const SCALES := [1.0, 1.25]
## ⚠⚠ **THE SHOOT SWEEPS FACINGS, AND IT SWEPT BODY SIZES UNTIL 2026-08-31.** The size question was
## answered by the first sheet; **the live one is 「what does 「it turns」 mean」** (the user, on seeing
## it: 「What is this turning? Tell me about the turning first」), and a facing is the only thing that
## can answer it in a still picture. ⚠ **A version that ignores the facing is photographed twice
## identically, and that identity is itself the result** — it is what「doesn't turn」looks like.
const FACES := [Vector2(0, 1), Vector2(1, 0)]
## What each facing is called in a file name. Same length as `FACES`.
const FACE_NAMES := ["south", "east"]
## ⚠⚠ **`-- still` PHOTOGRAPHS ONE VERSION TWICE, FOUR FRAMES APART, AND CHANGES NOTHING BETWEEN.**
## It exists to answer 「do they stand still?」 with a number instead of with a claim: **two frames of a
## frozen board must differ only by the idle sway.** It was written the day the nine vibrated.
const STILL_GAP := 4
## Wheel notches for the shot. The nine have to fill the frame or the sheet is a picture of an island.
const NEAR_NOTCHES := 9

## --- move mode: `06-ranks-wide`, walked ----------------------------------------------------------
## ⚠⚠ **WHICH OF THE NINE LATTICE SEATS BELONGS TO WHICH 조각 OF THE 블록** — the table the 3x3 lattice
## needs and does not have on its own. Nine seats over four 조각 is 2.25, so the split is 3 · 2 · 2 · 2
## and **the middle seats do not sit in the 조각 nearest them**: assigning by nearest gives one 조각
## four seats, which is over `Rules.TILE_CAPACITY`.
##
## ⚠ **Indexed `local.y * 2 + local.x`**, the 조각's own place inside the 블록. Values are in 조각,
## relative to the middle of the 블록.
## ⚠⚠ **THE CENTRE SEAT (0, 0) BELONGS TO THE FAR 조각**, so the body holding it is DRAWN two thirds
## of a 조각 from the 조각 the sim has it standing in. **That is the whole cost of a per-블록 lattice
## and it is why this is a lab and not a patch to `look.gd`**: shipping it means the seat index moves
## up a unit, out of `Grid.slot_of`.
const SEATS := [
	[Vector2(-2.0 / 3.0, -2.0 / 3.0), Vector2(0.0, -2.0 / 3.0), Vector2(-2.0 / 3.0, 0.0)],
	[Vector2(2.0 / 3.0, -2.0 / 3.0), Vector2(2.0 / 3.0, 0.0)],
	[Vector2(-2.0 / 3.0, 2.0 / 3.0), Vector2(0.0, 2.0 / 3.0)],
	[Vector2(0.0, 0.0), Vector2(2.0 / 3.0, 2.0 / 3.0)],
]
## How fast a body slides between「where the sim has it」and「its seat in the lattice」, per second.
## ⚠ **Eased rather than snapped**: a body that popped onto its seat the instant it stopped walking
# would read as a teleport, and the whole question being looked at here is how the move FEELS.
const SEAT_EASE := 6.0

var game: Game = null
var field: FieldView = null
## ⚠⚠ **THE LAB'S OWN HANDLE ON THE FIGHT, BECAUSE `game.battle` IS NULLED ON PURPOSE.** See
## `_freeze`: `Game._process` returns early on a null battle, which is how the sim is stopped without
## stopping the drawing — `FieldView` keeps its own reference and keeps painting.
var bat: Battle = null
var grid: Grid = null
## The 블록 the nine stand in, as its low corner in 조각.
var block_low := Vector2i.ZERO
## Which way the ranks face. **Fixed and not derived**: a facing that came out of the sim would differ
## between versions and the sheet would be comparing two things at once.
var face := Vector2(0, 1)

var _names: Array = []
var _seats := PackedVector2Array()
var _scale := 1.0
var _i := 0
var _booted := false
var _shooting := false
var _still := false
var _wait := 0
var _boot := 0
var _shot := 0
var _label: Label = null
var _held := {}
## **Move mode: the sim runs and the nine walk where they are told.** Off by default, because every
## still picture in this folder depends on the board not moving.
var _moving := false
## The 블록 the nine were last sent to, and its walkable 조각. **Kept, because an order is not spent
## when it is given** — see `_nudge`.
var _goal_block := -1
var _goal_tiles: Array = []
## Where each body is drawn relative to where the sim has it, in 조각. Eased, so it survives a body
## starting to walk again mid-slide.
var _draw_off := {}


func _initialize() -> void:
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	game = Game.new()
	root.add_child(game)
	var argv := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	_still = argv.has("still")
	_shooting = argv.has("shoot") or _still


func _process(_delta: float) -> bool:
	if _booted and _moving:
		# ⚠⚠ **THE LAB STEPS THE FIGHT, AND `game.battle` STAYS NULL EVEN HERE.** Handing it back would
		# also hand the shell its own click handler, and that one orders **the single nearest body** —
		# the nine would answer a press one man at a time and the thing being looked at is all nine.
		bat.step(_delta)
		_nudge()
		_seat_settled(_delta)
		return _watch()
	if _booted:
		# ⚠⚠ **THE NINE ARE RE-STOOD EVERY FRAME, AND THAT IS NOT A FIXUP.** They are real bodies in a
		# real fight: left alone the sim musters them, walks them and re-seats them, and the picture
		# being judged would drift out from under the camera between the shot and the sheet.
		_restand()
	if _booted and not _shooting:
		return _watch()
	_wait += 1
	if _wait < 4:
		return false
	_wait = 0
	if not _booted:
		return _boot_step()
	return _shoot_step()


# --- getting to the island ---------------------------------------------------------------------

func _boot_step() -> bool:
	match _boot:
		0:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = Look.title_slot_hit_rect_px(0).get_center()
			game._unhandled_input(ev)
		1:
			for _i2 in 90:
				game._process(1.0 / 60.0)
		2:
			field = game.field_view
			grid = game.battle.grid if game.battle != null else null
			if field == null or grid == null:
				push_error("lab: 시작하기 did not open an island")
				return true
			_names = _find_versions()
			if _names.is_empty():
				push_error("lab: .prototypes/nine holds no version folder with a scene.gd")
				return true
			block_low = _pick_block()
			_make_nine()
			_frame_camera()
			_booted = true
			# ⚠ **`bat` and not `game.battle`** — `_make_nine` has already frozen the sim by nulling the
			# shell's handle, and this line dereferenced it for one edit.
			print("[lab] block_low=%s centre=%s ashore=%d roster=%d frozen=%s cam=%s zoom=%f" % [
				str(block_low), str(_block_centre()), bat.ashore_ids().size(),
				game.run.army.type_id.size(), str(game.battle == null),
				str(field.cam_px), field.zoom])
			if not _shooting:
				_label = Label.new()
				_label.position = Vector2(14, 10)
				_label.add_theme_font_size_override("font_size", 20)
				_label.add_theme_color_override("font_color", Color(1, 1, 1))
				_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
				_label.add_theme_constant_override("outline_size", 6)
				root.add_child(_label)
				_show(0)
			else:
				_apply(0, 0)
	_boot += 1
	return false


func _find_versions() -> Array:
	var out: Array = []
	var d := DirAccess.open(DIR)
	if d == null:
		return out
	for name in d.get_directories():
		if ResourceLoader.exists("%s/%s/scene.gd" % [DIR, name]):
			out.append(name)
	out.sort()
	return out


## **A flat 블록 with a whole 조각 of walkable land in every direction round it.**
##
## ⚠ **All four 조각, not one**: nine bodies spill over the whole 블록, and a 블록 with one 조각 of
## plateau in it would stand three of them inside a cliff.
## ⚠⚠ **THE RING OF LAND ROUND IT IS THE HALF THAT WAS MISSING** (measured 2026-08-31 by looking at
## the first sheet): the first pick was the flat 블록 furthest from the 성채, which is the one on the
## shore — **five of the nine stood against open water and the sheet was half sea.** A crowd is judged
## against the ground it stands on, so the ground has to be in frame all the way round it.
func _pick_block() -> Vector2i:
	var b := Rules.BLOCK_TILES
	var mid := Vector2(grid.w, grid.h) * 0.5
	var best := Vector2i(-1, -1)
	var best_score := 1.0e9
	for by in range(0, grid.h - b + 1, b):
		for bx in range(0, grid.w - b + 1, b):
			if not _clear_block(bx, by):
				continue
			var score := Vector2(bx, by).distance_to(mid)
			if score < best_score:
				best_score = score
				best = Vector2i(bx, by)
	return best if best.x >= 0 else Vector2i(grid.w / 2, grid.h / 2)


## Whether the 블록 at `(bx, by)` is flat, walkable, and ringed by one more 조각 of walkable land on
## every side — sixteen 조각 in all, at one single level.
func _clear_block(bx: int, by: int) -> bool:
	var b := Rules.BLOCK_TILES
	var lvl := -999
	for dy in range(-1, b + 1):
		for dx in range(-1, b + 1):
			var tx := bx + dx
			var ty := by + dy
			if tx < 0 or ty < 0 or tx >= grid.w or ty >= grid.h:
				return false
			if not grid.is_passable(tx, ty):
				return false
			var l := grid.level_at(tx, ty)
			if lvl == -999:
				lvl = l
			elif l != lvl:
				return false
	return true


## **Rebuilds the fight with a roster of exactly nine 검사 and nothing else on the board.**
##
## ⚠⚠ **`battle.setup` AND NOT AN APPEND TO THE COLUMNS.** A `Battle` sizes every per-body column off
## the roster at setup; recruiting after it leaves nine rows in `Army` and four in `soldier_pos`, and
## the first `step` walks off the end of six arrays at once.
## ⚠ **Spawns are handed in EMPTY** — a 늑대 in frame is one more thing the eye lands on, and this
## sheet is about nine men standing.
func _make_nine() -> void:
	var b := game.battle
	var army := game.run.army
	var slot := army.slot_of_type(Rules.SWORDSMAN)
	while army.type_id.size() < NINE:
		army.recruit(slot)
	b.setup(grid, army, [], b.keep_tiles, b.muster_tile)
	# ⚠⚠ **THE HP LINE IS NOT BOOKKEEPING — WITHOUT IT ALL NINE DIE ON THE FIRST SUB-STEP.** `setup`
	# leaves `soldier_hp` at 0 and `place_ashore` is what fills it, so a body stood on the board by
	# hand is ASHORE with no health, and the death phase kills every 검사 the frame after it is placed.
	# **Measured 2026-08-31**: the first ten shots came back with an empty island and no error anywhere.
	for i in NINE:
		b.soldier_state[i] = Battle.SoldierState.ASHORE
		b.soldier_hp[i] = game.run.army.max_hp_of(i)
	# ⚠⚠ **NOT ONE OF THEM RESERVES A 조각, AND THAT IS DELIBERATE.** `FieldView` reads the reservation
	# slot to spread a crowd; an unreserved body answers slot 0, whose offset is zero, so **the seat
	# this lab computes is exactly where the body is drawn.** Reserve them and every version would be
	# photographed wearing `01-now`'s ring on top of its own arrangement.
	for i in NINE:
		grid.release_all(i)
	_freeze()


## **Stops the fight without stopping the picture.**
##
## ⚠⚠ **THE NINE VIBRATED ON SCREEN UNTIL THIS WENT IN** (2026-08-31, the user, watching the lab:
## 「the character's frames keep jittering back and forth — it's horrible」). The lab wrote the seats
## at the top of the frame, `Battle.step` then nudged every body off them, and the view drew the
## nudged position — **so each body was pulled back and pushed off again once per frame**, and the
## facing flipped with it because a body faces the way it last moved.
##
## ⚠ **`game.battle = null` and not a flag**: `Game._process` returns early on a null battle, which is
## the whole of the sim's clock, while `FieldView` holds its own reference and keeps painting. **There
## is no other way to stop the step from outside** — nothing else gates it.
func _freeze() -> void:
	bat = game.battle
	game.battle = null


## Points the camera at the middle of the 블록 and zooms in until the nine fill the frame.
func _frame_camera() -> void:
	for _n in NEAR_NOTCHES:
		field.zoom_at(Look.viewport_size_px() * 0.5, Look.ZOOM_STEP)
	var c := Look.tile_point_px(_block_centre())
	field.cam_px = c - field._visible_ground_px() * 0.5
	field._clamp_cam()


## The middle of the 블록 in 조각 POSITION units — the space `Look.tile_point_px` takes, where a body
## standing on 조각 (x, y) has position (x, y). ⚠ **Not the 조각 index and not world px.**
func _block_centre() -> Vector2:
	return Vector2(block_low) + Vector2.ONE * (float(Rules.BLOCK_TILES) - 1.0) * 0.5


# --- putting one version on the board ------------------------------------------------------------

func _apply(k: int, scale_i: int) -> void:
	var scr: GDScript = load("%s/%s/scene.gd" % [DIR, str(_names[k])])
	_seats = scr.seats(_block_centre(), face)
	_scale = float(SCALES[scale_i % SCALES.size()])
	_i = k
	_restand()


## Writes the nine bodies onto their seats, and stretches the drawn pictures by `_scale`.
##
## ⚠⚠ **THE SIZE IS APPLIED TO THE SPRITES AND NOT TO `Look`.** Every body size in the game is a
## `const` in `look.gd` and a const cannot be moved at runtime, so a lab that wanted two sizes in one
## round had to reach the nodes. ⚠ **The ground disc is NOT scaled with them** — it is drawn into the
## fx buffer from the body's radius, and at 1.25 it sits a quarter narrow. **The disc is not what this
## sheet is about; say it out loud rather than let it be read as a result.**
func _restand() -> void:
	var b := bat
	if b == null or _seats.is_empty():
		return
	for i in mini(NINE, b.soldier_pos.size()):
		b.soldier_pos[i] = _seats[i]
		b.soldier_order[i] = -1
	if _scale == 1.0 or field == null:
		return
	for k in field._sprites_used:
		var s: Sprite3D = field._sprites[k]
		if s.texture == null or not s.visible:
			continue
		# Grown about the FEET and not about the middle, or a bigger body floats off the ground.
		var tall := float(s.texture.get_height()) * s.scale.y / Look.TILE_PX
		var foot := s.position.y - tall * 0.5
		s.scale = Vector3(s.scale.x * _scale, s.scale.y * _scale, 1.0)
		var tall2 := float(s.texture.get_height()) * s.scale.y / Look.TILE_PX
		s.position.y = foot + tall2 * 0.5


## --- move mode ------------------------------------------------------------------------------------

## **Puts the nine back on real 조각 and reserves them**, which is what the still modes deliberately
## do not do.
##
## ⚠⚠ **WITHOUT THE RESERVATION THE WALK HAS NO COLLISION AT ALL.** A body that holds no 조각 answers
## slot -1, every 조각 looks empty to everybody, and the nine walk straight through each other into one
## point. **The seat plan's zero-crowd trick and a real walk cannot both be had** — see `_make_nine`.
## ⚠ **Round-robin over the 블록's four 조각**, so the nine sit 3 · 2 · 2 · 2 and both ceilings are
## exercised on the way in rather than only on the way out.
func _enter_move() -> void:
	var tiles := _tiles_of_block(block_low)
	if tiles.is_empty():
		return
	var ids := bat.ashore_ids()
	for k in ids.size():
		var i := int(ids[k])
		# ⚠⚠ **`place_ashore` AND NOT A HAND-WRITTEN STATE + POSITION.** Its header says the four writes
		# are one unit — state, position, **GOAL**, and the reservation — and **a body whose goal is
		# left at `OFFMAP` walks back toward (-1, -1) at full speed.** Measured 2026-08-31: all nine
		# took their orders and were at (-1, -1) fourteen seconds later.
		grid.release_all(i)
		bat.soldier_state[i] = Battle.SoldierState.RESERVE
		bat.place_ashore(i, int(tiles[k % tiles.size()]))
	_draw_off = {}
	_goal_block = -1
	_goal_tiles = []


## Back to the still board: the nine let go of their 조각 and stand on the current seat plan again.
func _leave_move() -> void:
	for i in NINE:
		grid.release_all(i)
	_draw_off = {}
	block_low = _block_low_of(grid.block_of(_tile_of_body(0)))
	_frame_camera()
	_apply(_i, maxi(SCALES.find(_scale), 0))


## Every walkable 조각 of the 블록 whose low corner is `low`.
func _tiles_of_block(low: Vector2i) -> Array:
	var out: Array = []
	for dy in Rules.BLOCK_TILES:
		for dx in Rules.BLOCK_TILES:
			var tx := low.x + dx
			var ty := low.y + dy
			if tx < grid.w and ty < grid.h and grid.is_passable(tx, ty):
				out.append(ty * grid.w + tx)
	return out

## **Slides every settled body onto its seat in the lattice, and lets a walking one go free.**
##
## ⚠⚠ **THE SIM'S POSITIONS ARE NOT TOUCHED — the SPRITES are.** A lattice seat is up to two thirds of
## a 조각 from the 조각 the body stands in, and writing that back would put the body in a 조각 it does
## not hold: the next walk would start from the wrong 조각 and the collision would disagree with the
## picture. **The sim owns where a body IS; this owns where it is DRAWN**, which is exactly the split
## `Look.crowd_offset_px` already lives on.
## ⚠ **The ground disc does not follow.** It is painted into the fx buffer from the sim's position, so
# a settled body stands beside its own shadow. That is the lab, not the arrangement.
func _seat_settled(dt: float) -> void:
	var ids := bat.ashore_ids()
	for k in ids.size():
		var i := int(ids[k])
		# **Walking bodies are drawn where they really are.** Sliding a body toward a seat while it is
		# crossing the board would put the picture and the collision in different places for seconds.
		var want := Vector2.ZERO if int(bat.soldier_order[i]) >= 0 else _lattice_offset(i)
		var have: Vector2 = _draw_off.get(i, Vector2.ZERO)
		_draw_off[i] = have.lerp(want, clampf(SEAT_EASE * dt, 0.0, 1.0))
	if field == null:
		return
	for k in mini(field._sprites_used, ids.size()):
		# ⚠ **Sprite `k` is body `ids[k]`** because `_paint_bodies` lays beasts down first and then the
		# ashore 검사 in this order. **With a beast on the board this mapping is wrong** — move mode
		# opens with no spawns, and that is what keeps it true.
		var off: Vector2 = _draw_off.get(int(ids[k]), Vector2.ZERO)
		var s: Sprite3D = field._sprites[k]
		s.position = Vector3(s.position.x + off.x, s.position.y, s.position.z + off.y)


## Where body `i` should be DRAWN relative to its own 조각 centre, in 조각.
func _lattice_offset(i: int) -> Vector2:
	var p: Vector2 = bat.soldier_pos[i]
	var tx := clampi(int(round(p.x)), 0, grid.w - 1)
	var ty := clampi(int(round(p.y)), 0, grid.h - 1)
	var tile := ty * grid.w + tx
	var blk := grid.block_of(tile)
	if blk < 0:
		return Vector2.ZERO
	var low := _block_low_of(blk)
	var local := Vector2i(tx - low.x, ty - low.y)
	var list: Array = SEATS[local.y * Rules.BLOCK_TILES + local.x]
	var slot := grid.slot_of(tile, i)
	if slot < 0 or slot >= list.size():
		return Vector2.ZERO
	# The seat is measured from the middle of the 블록; the body is standing on `local`. Half a 조각
	# is where the middle of a 2x2 lump sits relative to its low corner.
	return Vector2(0.5, 0.5) + (list[slot] as Vector2) - Vector2(local)


func _block_low_of(blk: int) -> Vector2i:
	var b := Rules.BLOCK_TILES
	var per_row := (grid.w + b - 1) / b
	return Vector2i((blk % per_row) * b, int(blk / per_row) * b)


## **Sends all nine to the 블록 the press landed in**, one 조각 each, round-robin.
##
## ⚠ **Ordered to 조각 and not to the 블록**: `Battle.order_walk` takes a 조각, and spreading the nine
## over the four is what makes them arrive as a crowd instead of queueing into one doorway. The 블록
## ceiling then does the rest — nine is exactly what it admits.
func _order_all(tile: int) -> void:
	if tile < 0:
		return
	var blk := grid.block_of(tile)
	if blk < 0:
		return
	var tiles := _tiles_of_block(_block_low_of(blk))
	if tiles.is_empty():
		return
	_goal_block = blk
	_goal_tiles = tiles
	var ids := bat.ashore_ids()
	for k in ids.size():
		bat.order_walk(int(ids[k]), int(tiles[k % tiles.size()]))


## **Re-aims anybody who stopped short of the 블록 they were sent to.**
##
## ⚠⚠ **WITHOUT THIS, SIX OF NINE ARRIVE** (measured 2026-08-31 by `move_probe.gd`). `order_walk` aims
## at ONE 조각; a body that reaches it while three others already stand there is refused, stops, and
## its order is cleared as「stuck」. **Nine aimed at four fixed 조각 land as six** — the other three
## give up beside the 블록.
##
## ⚠⚠ **⇒ A SQUAD ORDER IS NOT NINE WALK ORDERS.** Something has to re-seat whoever lost the race for
## a place, and this loop is the smallest thing that does it. **That is the ticket week 3 is really
## about**, and it is written down here rather than discovered again.
func _nudge() -> void:
	if _goal_block < 0 or _goal_tiles.is_empty():
		return
	for raw_id in bat.ashore_ids():
		var i := int(raw_id)
		if int(bat.soldier_order[i]) >= 0:
			continue
		if grid.block_of(_tile_of_body(i)) == _goal_block:
			continue
		for raw in _goal_tiles:
			var want := int(raw)
			if grid.can_hold(want, i):
				bat.order_walk(i, want)
				break


func _show(k: int) -> void:
	_apply(posmod(k, _names.size()), maxi(SCALES.find(_scale), 0))
	if _label != null:
		var scr: GDScript = load("%s/%s/scene.gd" % [DIR, str(_names[_i])])
		var fi := maxi(FACES.find(face), 0)
		if _moving:
			_label.text = "이동 모드 — 06-ranks-wide 의 자리로 걷는다\n판을 누르면 아홉이 그 블록으로 간다 · M 이동 모드 끄기 · Q/E 화면 돌리기 · ESC"
			return
		_label.text = "%d/%d  %s — %s\n몸 크기 x%.2f · 부대가 보는 쪽 %s\n1..%d 고르기 · ←→ 넘기기 · SPACE 크기 · T 보는 쪽 · M 이동 · Q/E 화면 돌리기 · ESC" % [
			_i + 1, _names.size(), str(_names[_i]), scr.title(), _scale,
			str(FACE_NAMES[fi]), _names.size()]


# --- the shots -----------------------------------------------------------------------------------

func _shoot_step() -> bool:
	if _still:
		return _still_step()
	var per := 2
	var n: int = _shot / per
	var total: int = _names.size() * FACES.size()
	if n >= total:
		return true
	var k: int = n / FACES.size()
	var fi: int = n % FACES.size()
	match _shot % per:
		0:
			face = FACES[fi]
			_apply(k, 0)
		1:
			# ⚠ **Apply on one step, SHOOT on the next.** `get_texture()` hands back the frame already
			# drawn, so doing both in one step files every picture under the previous seat plan.
			_save(str(_names[k]), str(FACE_NAMES[fi]))
	_shot += 1
	return false


## How much of the frame one picture keeps, in screen px. **The zoom is capped by `Look.ZOOM_MAX`**, so
## the nine can only be made to fill the picture by cutting the picture down to them — a full 1280 x 720
## frame of which the crowd is one twentieth is a sheet about an island.
const CROP := Vector2i(500, 440)
## How far above the ground point the crop is centred. Bodies stand UP from their feet, so a box
## centred on the ground puts every head against its top edge.
const CROP_RISE := 90


## One version, photographed twice `STILL_GAP` shoot-steps apart with nothing changed in between.
## **The pair is the instrument** — a still board differs only by the sway, a vibrating one does not.
func _still_step() -> bool:
	match _shot:
		0:
			_apply(1, 0)      # 02-grid, the version being taken forward
		1:
			_save(str(_names[1]), "still-a")
		STILL_GAP:
			_save(str(_names[1]), "still-b")
		STILL_GAP + 1:
			return true
	_shot += 1
	return false


func _save(name: String, which: String) -> void:
	var img := root.get_texture().get_image()
	var p := (field.tile_to_screen_px(block_low.x, block_low.y)
			+ field.tile_to_screen_px(block_low.x + 1, block_low.y + 1)) * 0.5
	var x := clampi(int(p.x) - CROP.x / 2, 0, maxi(img.get_width() - CROP.x, 0))
	var y := clampi(int(p.y) - CROP_RISE - CROP.y / 2, 0, maxi(img.get_height() - CROP.y, 0))
	img.get_region(Rect2i(x, y, CROP.x, CROP.y)).save_png(
		ProjectSettings.globalize_path(OUT % [name, which]))
	print("[lab] %s %s  sprites=%d ashore=%d" % [name, which,
		field._sprites_used, bat.ashore_ids().size()])


# --- the watched run -----------------------------------------------------------------------------

func _tap(code: Key) -> bool:
	var down := Input.is_key_pressed(code)
	var was: bool = _held.get(code, false)
	_held[code] = down
	return down and not was


func _watch() -> bool:
	if Input.is_key_pressed(KEY_ESCAPE):
		return true
	for n in _names.size():
		if _tap((KEY_1 + n) as Key):
			_show(n)
	if _tap(KEY_RIGHT):
		_show(_i + 1)
	if _tap(KEY_LEFT):
		_show(_i - 1)
	if _tap(KEY_SPACE):
		_scale = float(SCALES[(maxi(SCALES.find(_scale), 0) + 1) % SCALES.size()])
		_show(_i)
	# ⚠ **T turns what the NINE are looking at, and Q/E turn the CAMERA.** They are two different
	# turnings and the whole subject of this round is telling them apart, so they are on separate keys.
	if _tap(KEY_T):
		var at := FACES.find(face)
		face = FACES[(maxi(at, 0) + 1) % FACES.size()]
		_show(_i)
	if _tap(KEY_M):
		_moving = not _moving
		if _moving:
			_enter_move()
		else:
			_leave_move()
		_show(_i)
	if _moving and _tap_mouse():
		_order_all(game._tile_at(root.get_mouse_position()))
	return false


## The 조각 body `i` is standing in.
func _tile_of_body(i: int) -> int:
	var p: Vector2 = bat.soldier_pos[i]
	var tx := clampi(int(round(p.x)), 0, grid.w - 1)
	var ty := clampi(int(round(p.y)), 0, grid.h - 1)
	return ty * grid.w + tx


## A left press, edge-detected the way `_tap` does it for keys.
func _tap_mouse() -> bool:
	var down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var was: bool = _held.get("mouse", false)
	_held["mouse"] = down
	return down and not was
