extends SceneTree
## **The beasts' boat, on the real screen.** Opens the title, presses 시작하기 through a real mouse
## event, and then either scans for a hull with the pan keys or centres one and zooms in on it.
##
## ```
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_boat.gd -- <out-dir> find
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_boat.gd -- <out-dir> close
## ```
##
## ⚠ **`00_title` is the known-answer frame** — a screen this repo has already looked at. If it comes
## back wrong nothing below it is readable.
## ⚠ **Every input is an `InputEvent` handed to the engine.** No Win32, no key injection.

var _dir := ""
var _mode := "find"
var _game: Game = null


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("capture_boat: 출력 폴더를 인자로 달라")
		quit(1)
		return
	_dir = args[0]
	if args.size() > 1:
		_mode = args[1]
	if DisplayServer.get_name() == "headless":
		push_error("capture_boat: --headless 로는 픽셀을 못 읽는다")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	_run()


func _run() -> void:
	_game = Game.new()
	root.add_child(_game)
	await process_frame
	await _settle(10)
	await _shot("00_title")

	_click(Look.title_slot_rect_px(TitleView.SLOT_START).get_center())
	await _settle(6)
	if _game.battle == null:
		push_error("capture_boat: 섬이 안 열렸다")
		quit(1)
		return
	var b: Battle = _game.battle
	print("capture_boat: 섬 %d x %d, zoom %.4f" % [b.grid.w, b.grid.h, _game.field_view.zoom])
	await _shot("01_open")

	if _mode == "find":
		await _find()
	elif _mode == "side":
		await _side()
	elif _mode == "still":
		await _still()
	elif _mode == "bow":
		await _bow()
	elif _mode == "arrivals":
		await _arrivals()
	elif _mode == "drag":
		await _drag()
	elif _mode == "worst":
		await _worst()
	elif _mode == "rank2":
		await _rank2()
	elif _mode == "farout":
		await _farout()
	elif _mode == "final":
		await _final()
	else:
		await _close()
	print("capture_boat: %s" % _dir)
	quit()


# --- mode: can a player find a hull by looking around ------------------------------------------------

## ⚠⚠ **THIS SCANNED WITH WASD UNTIL 2026-08-31**, when the user had the pan keys deleted from the
## shell along with the window's edge band. **The camera is panned directly now, at the keys' old
## 900 px a second and for the same durations**, so the frames this mode saves are the same frames.
## ⚠ **The signs are `pan_by`'s, which are the DRAG's**: north is a POSITIVE y here, exactly as W
## answered `(0, 1)` before.
const PAN_PX_PER_SEC := 900.0

func _find() -> void:
	await _until(6.2)
	await _shot("02_t6_no_pan")

	await _pan(Vector2(0.0, 1.0), 1.6)
	await _shot("03_north")
	await _pan(Vector2(0.0, -1.0), 3.2)
	await _shot("04_south")
	await _pan(Vector2(0.0, 1.0), 1.6)
	await _pan(Vector2(1.0, 0.0), 1.6)
	await _shot("05_west")
	await _pan(Vector2(-1.0, 0.0), 3.2)
	await _shot("06_east")
	await _pan(Vector2(1.0, 0.0), 1.6)

	await _until(14.0)
	await _shot("07_t14_centre")
	await _pan(Vector2(0.0, 1.0), 1.6)
	await _shot("08_t14_north")
	await _pan(Vector2(0.0, -1.0), 3.2)
	await _shot("09_t14_south")


# --- mode: what does the hull look like -------------------------------------------------------------

func _close() -> void:
	await _until(11.0)
	_centre_on_boat(0)
	await _settle(2)
	await _shot("10_mid_survey_centred")
	_zoom(6)
	await _settle(2)
	_centre_on_boat(0)
	await _settle(2)
	await _shot("11_mid_close")
	_zoom(4)
	await _settle(2)
	_centre_on_boat(0)
	await _settle(2)
	await _shot("12_mid_closer")

	# The crossing is 18.3 s from a 5.0 s launch, so it is standing off the shore well before 26.
	await _until(26.0)
	_centre_on_boat(0)
	await _settle(2)
	await _shot("13_arrived_close")
	while _game.field_view.zoom > Look.ZOOM_MIN + 0.001:
		_zoom_out(1)
	_centre_on_boat(0)
	await _settle(2)
	await _shot("14_arrived_wide")


# --- mode: how far past the shore the bow reaches, and what the grey wedge on the deck is -----------

## ⚠ **The hull is asked for its OWN bounds** rather than the 5.2 조각 the ticket quotes: the overlap
## is decided by where the mesh's origin sits inside the mesh, and only the node knows that.
func _bow() -> void:
	await _until(26.0)
	var fv := _game.field_view
	var hull: Node3D = fv._boats[0]
	print("--- hull children: %s" % str(hull.get_children().map(func(c): return c.name)))
	var box := _aabb_of(hull)
	print("--- hull local AABB pos=%s size=%s  (origin sits %.3f 조각 behind the bow, %.3f ahead of the stern)"
		% [str(box.position), str(box.size), box.position.x + box.size.x, -box.position.x])

	_overlap_report(0, box)

	# The sail goes dark and nothing else does. **If the wedge on the deck survives, it is not a
	# shadow** — that is the whole of the test.
	_centre_on_boat(0)
	await _settle(2)
	await _shot("40_sail_on")
	var hidden := _hide_matching(hull, ["sail"])
	print("--- hid: %s" % str(hidden))
	await _settle(2)
	await _shot("41_sail_hidden")
	var hidden2 := _hide_matching(hull, ["mast", "stem", "boom", "spar"])
	print("--- hid also: %s" % str(hidden2))
	await _settle(2)
	await _shot("42_rig_hidden")


## Every mesh under `hull`, expressed in `hull`'s OWN space — which is the space the bow and the
## stern are named in.
func _aabb_of(hull: Node3D) -> AABB:
	var into := hull.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for raw in _meshes(hull):
		var c := raw as MeshInstance3D
		var here: AABB = (into * c.global_transform) * c.get_aabb()
		box = here if first else box.merge(here)
		first = false
	return box


## **Walks the hull's own centre line landward** and reports where the water stops being water. Nothing
## is derived from a constant here — the 조각 the bow ends up over is the thing being asked about.
func _overlap_report(i: int, box: AABB) -> void:
	var b: Battle = _game.battle
	var stop: Vector2 = b.boat_pos[i]
	var beach := int(b.boat_beach[i])
	var bt := Vector2(beach % b.grid.w, beach / b.grid.w)
	var head: Vector2 = (bt - stop).normalized()
	var half := box.position.x + box.size.x
	var bow := stop + head * half
	var first_land := -1.0
	var s := 0.0
	while s <= half + 1.0:
		var p := stop + head * s
		var tx := int(floor(p.x))
		var ty := int(floor(p.y))
		if tx >= 0 and ty >= 0 and tx < b.grid.w and ty < b.grid.h \
			and b.grid.passable[ty * b.grid.w + tx] != 0:
			first_land = s
			break
		s += 0.02
	print("--- beach 조각 %s passable=%s | stop=(%.2f,%.2f) head=(%.2f,%.2f) half-length=%.2f 조각"
		% [str(bt), str(b.grid.passable[int(bt.y) * b.grid.w + int(bt.x)] != 0),
			stop.x, stop.y, head.x, head.y, half])
	var to_beach := (bt - stop).length()
	print("--- stop is %.2f 조각 from its own beach 조각 (a plain approach would be %.2f)"
		% [to_beach, Rules.BOAT_STANDOFF_TILES])
	var over := half - first_land
	var verdict := "bow is %.2f 조각 OVER LAND" % over if over > 0.0 else "GAP of %.2f 조각 bow to land" % -over
	print("--- bow at (%.2f,%.2f); water ends %.2f 조각 ahead of the stop point; **%s**"
		% [bow.x, bow.y, first_land, verdict])


func _meshes(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is MeshInstance3D:
			out.append(c)
		out.append_array(_meshes(c))
	return out


func _hide_matching(n: Node, words: Array) -> Array:
	var hit := []
	for c in n.get_children():
		var low := String(c.name).to_lower()
		var match_it := false
		for w in words:
			if low.contains(w):
				match_it = true
		if match_it and c is Node3D:
			(c as Node3D).visible = false
			hit.append(c.name)
		else:
			hit.append_array(_hide_matching(c, words))
	return hit


# --- mode: rank every beach against the DRAWN outline, then go and look at the worst ----------------
## ⚠⚠ **The convention is CALIBRATED, never assumed.** `Islands.coast()` is a polyline in some tile
## space and `grid.passable` is a table indexed by integer 조각; whether the two share an origin is
## exactly where an offset like this hides. So both hypotheses are scored against the grid first, and
## the ranking below is computed in whichever one actually agrees with the board.

var _coast: Array = []


func _worst() -> void:
	var b: Battle = _game.battle
	_coast = Islands.coast()
	print("--- coast: %d segments" % _coast.size())

	# 1. Which offset makes 「inside the outline」 mean 「passable」?
	var best_off := 0.0
	var best_hit := -1.0
	for off in [0.0, 0.5, -0.5]:
		var agree := 0
		var total := 0
		for t in b.grid.passable.size():
			var p := Vector2(t % b.grid.w, t / b.grid.w) + Vector2(off, off)
			total += 1
			var land := _inside(p)
			if land == (b.grid.passable[t] != 0):
				agree += 1
		var rate := float(agree) / float(total)
		print("--- offset %+.1f : outline and grid agree on %.1f%% of 조각" % [off, rate * 100.0])
		if rate > best_hit:
			best_hit = rate
			best_off = off
	print("--- taking offset %+.1f" % best_off)

	# 2. Every beach, ranked by how much water is left in front of the bow.
	var ring := b.grid.beach_ring(Rules.BOAT_START_DIST_TILES)
	var rows: Array = []
	for k in ring.size():
		var beach := int(ring[k])
		var out: Vector2 = b.grid.seaward_at(beach)
		var centre := Vector2(beach % b.grid.w, beach / b.grid.w)
		var lead: float = b.grid.land_reach_along(beach, out, Rules.BOAT_START_DIST_TILES)
		var stop := centre + out * (lead + Rules.BOAT_STANDOFF_TILES)
		var bow := stop - out * Rules.BOAT_HULL_HALF_TILES
		rows.append({"k": k, "t": beach, "clear": _signed_clear(bow + Vector2(best_off, best_off)),
			"lead": lead, "tile": centre})
	rows.sort_custom(func(a, c): return float(a["clear"]) < float(c["clear"]))
	print("--- %d beaches, worst first:" % rows.size())
	for n in mini(12, rows.size()):
		var r = rows[n]
		print("---   #%d beach %s  lead=%.2f  bow clearance %+.2f 조각" % [int(r["k"]), str(r["tile"]), float(r["lead"]), float(r["clear"])])
	var mid = rows[rows.size() / 2]
	var top = rows[rows.size() - 1]
	print("---   median %+.2f | best %+.2f" % [float(mid["clear"]), float(top["clear"])])

	# 3. Go and stand at the five worst, in the game, and photograph each.
	for n in 5:
		var r = rows[n]
		await _force_arrival(int(r["k"]), n, float(r["clear"]))


# --- mode: every beach re-ranked against the stop the game NOW chooses, then the named five ---------
## ⚠⚠ **The stop points are the GAME's, the clearance is MINE.** Asking the same function that placed
## the boat whether the boat is placed well would be one instrument marking its own work.
## ⚠ **And it is the hull's forward HALF that is swept, not the bow point** — an ellipse of
## `BOAT_HULL_HALF_TILES` by half `BOAT_HULL_BEAM_TILES`, sampled every few degrees, because on a
## diagonal against a straight coast the shoulder reaches land before the tip does.

func _rank2() -> void:
	var b: Battle = _game.battle
	_coast = Islands.coast()
	_calibrate(b)

	var ring := b.grid.beach_ring(Rules.BOAT_START_DIST_TILES)
	print("--- ring holds %d beaches" % ring.size())
	var rows: Array = []
	# Wind the clock past the first due time once; then each forced launch is immediate.
	while b.elapsed < Rules.BOAT_FIRST_SEC + 0.1:
		b.step(0.2)
		await process_frame
	for k in ring.size():
		var before := b.boat_pos.size()
		b._boats_launched = 0
		b._beach_cursor = k
		b._launch_if_due()
		if b.boat_pos.size() == before:
			print("---   ring #%d launched nothing" % k)
			continue
		var i := before
		var beach := int(b.boat_beach[i])
		var centre := Vector2(beach % b.grid.w, beach / b.grid.w)
		var stop: Vector2 = b.boat_stop[i]
		var head := (centre - stop).normalized()
		rows.append({"k": k, "tile": centre, "clear": _hull_clear(stop, head),
			"out": (stop - centre).length()})
	rows.sort_custom(func(a, c): return float(a["clear"]) < float(c["clear"]))
	print("--- worst first:")
	for n in mini(12, rows.size()):
		var r = rows[n]
		print("---   #%d beach %s  stop %.2f 조각 out  hull clearance %+.3f 조각"
			% [int(r["k"]), str(r["tile"]), float(r["out"]), float(r["clear"])])
	print("---   median %+.3f | widest %+.3f"
		% [float(rows[rows.size() / 2]["clear"]), float(rows[rows.size() - 1]["clear"])])
	var far := 0.0
	for r in rows:
		far = maxf(far, float(r["out"]))
	print("--- furthest any boat now stops from its beach 조각: %.2f 조각" % far)

	# Then the five this session has been photographing, by name.
	var want := [Vector2(8, 15), Vector2(9, 19), Vector2(8, 19), Vector2(6, 18), Vector2(4, 2)]
	var picks: Array = []
	for wish in want:
		var found := -1
		var clear := 0.0
		for r in rows:
			if (r["tile"] as Vector2) == wish:
				found = int(r["k"])
				clear = float(r["clear"])
				break
		if found < 0:
			print("--- %s is not in the ring any more" % str(wish))
			continue
		print("--- %s is ring #%d, my clearance %+.3f 조각" % [str(wish), found, clear])
		picks.append({"k": found, "clear": clear})

	# ⚠ **A FRESH ISLAND before the photographs.** The ranking above launched 67 hulls to read their
	# stop points; leaving them standing would put the whole ring in every frame.
	_game._start_run()
	await _settle(6)
	var n2 := 0
	for p in picks:
		await _force_arrival(int(p["k"]), n2, float(p["clear"]))
		n2 += 1


## **The boat that stops furthest from the 조각 it is aiming at**, photographed at the framing the game
## opens at — because「it stopped for a reason」 is only true if the reason is in the frame.
func _farout() -> void:
	var b: Battle = _game.battle
	var ring := b.grid.beach_ring(Rules.BOAT_START_DIST_TILES)
	while b.elapsed < Rules.BOAT_FIRST_SEC + 0.1:
		b.step(0.2)
		await process_frame
	var best_k := -1
	var best_d := -1.0
	for k in ring.size():
		var before := b.boat_pos.size()
		b._boats_launched = 0
		b._beach_cursor = k
		b._launch_if_due()
		if b.boat_pos.size() == before:
			continue
		var i := before
		var centre := Vector2(int(b.boat_beach[i]) % b.grid.w, int(b.boat_beach[i]) / b.grid.w)
		var d: float = (b.boat_stop[i] as Vector2).distance_to(centre)
		if d > best_d:
			best_d = d
			best_k = k
	print("--- furthest: ring #%d, %.2f 조각 out from its own beach" % [best_k, best_d])

	_game._start_run()
	await _settle(6)
	await _force_arrival(best_k, 0, best_d)
	var b2: Battle = _game.battle
	var fv := _game.field_view
	fv.zoom = Look.survey_zoom_of(b2.grid.w, b2.grid.h)
	var map_px := Vector2(float(b2.grid.w), float(b2.grid.h)) * Look.TILE_PX
	fv.cam_px = map_px * 0.5 - fv._visible_ground_px() * 0.5
	fv._clamp_cam()
	await _settle(4)
	await _shot("95_farout_opening_frame")


## The last three questions at once: **where the furthest hull stops**, **whether ordinary arrivals
## moved**, and **which coastline no boat comes to any more**.
func _final() -> void:
	var b: Battle = _game.battle
	_coast = Islands.coast()
	_calibrate(b)
	var ring := b.grid.beach_ring(Rules.BOAT_START_DIST_TILES)
	print("--- ring holds %d beaches" % ring.size())

	# Which shore 조각 the ring leaves out.
	var in_ring := {}
	for raw in ring:
		in_ring[int(raw)] = true
	var shore: Array = []
	var missing: Array = []
	for t in b.grid.passable.size():
		if b.grid.passable[t] == 0:
			continue
		var tx := t % b.grid.w
		var ty := t / b.grid.w
		var wet := false
		for raw_d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var d := raw_d as Vector2i
			var nx: int = tx + d.x
			var ny: int = ty + d.y
			if nx < 0 or ny < 0 or nx >= b.grid.w or ny >= b.grid.h:
				wet = true
			elif b.grid.passable[ny * b.grid.w + nx] == 0:
				wet = true
		if not wet:
			continue
		shore.append(Vector2(tx, ty))
		if not in_ring.has(t):
			missing.append(Vector2(tx, ty))
	print("--- %d shore 조각, %d of them in the ring, %d never visited:" % [shore.size(), ring.size(), missing.size()])
	print("---   %s" % str(missing))

	# Every beach's stop, from the game's own launch.
	while b.elapsed < Rules.BOAT_FIRST_SEC + 0.1:
		b.step(0.2)
		await process_frame
	var rows: Array = []
	for k in ring.size():
		var before := b.boat_pos.size()
		b._boats_launched = 0
		b._beach_cursor = k
		b._launch_if_due()
		if b.boat_pos.size() == before:
			continue
		var i := before
		var centre := Vector2(int(b.boat_beach[i]) % b.grid.w, int(b.boat_beach[i]) / b.grid.w)
		var stop: Vector2 = b.boat_stop[i]
		rows.append({"k": k, "tile": centre, "out": stop.distance_to(centre),
			"clear": _hull_clear(stop, (centre - stop).normalized())})
	rows.sort_custom(func(a, c): return float(a["out"]) > float(c["out"]))
	print("--- furthest five stops:")
	for n in mini(5, rows.size()):
		var r = rows[n]
		print("---   #%d beach %s  %.2f 조각 out  clearance %+.3f" % [int(r["k"]), str(r["tile"]), float(r["out"]), float(r["clear"])])
	var worst_clear := INF
	for r in rows:
		worst_clear = minf(worst_clear, float(r["clear"]))
	print("--- tightest hull clearance over all %d: %+.3f 조각" % [rows.size(), worst_clear])

	# The furthest, then four ordinary ones from four different sides.
	var picks := [int(rows[0]["k"])]
	var sides := [Vector2(0, 0), Vector2(0, 0), Vector2(0, 0), Vector2(0, 0)]
	var cen := Vector2(b.grid.w, b.grid.h) * 0.5
	for r in rows:
		if absf(float(r["out"]) - 3.8) > 0.2:
			continue
		var tile: Vector2 = r["tile"]
		var q := 0
		if absf(tile.x - cen.x) > absf(tile.y - cen.y):
			q = 0 if tile.x < cen.x else 1
		else:
			q = 2 if tile.y < cen.y else 3
		if sides[q] == Vector2.ZERO:
			sides[q] = tile
			picks.append(int(r["k"]))
	print("--- shooting ring indices %s" % str(picks))

	_game._start_run()
	await _settle(6)
	var n2 := 0
	for k in picks:
		await _force_arrival(k, n2, 0.0)
		n2 += 1
	# And the whole board, once, with all five standing off it.
	var b2: Battle = _game.battle
	var fv := _game.field_view
	fv.zoom = Look.survey_zoom_of(b2.grid.w, b2.grid.h)
	var map_px := Vector2(float(b2.grid.w), float(b2.grid.h)) * Look.TILE_PX
	fv.cam_px = map_px * 0.5 - fv._visible_ground_px() * 0.5
	fv._clamp_cam()
	await _settle(4)
	await _shot("99_board_with_all_five")


func _calibrate(b: Battle) -> void:
	var best_off := 0.0
	var best_hit := -1.0
	for off in [0.0, 0.5, -0.5]:
		var agree := 0
		for t in b.grid.passable.size():
			var p := Vector2(t % b.grid.w, t / b.grid.w) + Vector2(off, off)
			if _inside(p) == (b.grid.passable[t] != 0):
				agree += 1
		var rate := float(agree) / float(b.grid.passable.size())
		print("--- offset %+.1f : outline and grid agree on %.1f%%" % [off, rate * 100.0])
		if rate > best_hit:
			best_hit = rate
			best_off = off
	_off = best_off
	print("--- taking offset %+.1f" % _off)


var _off := 0.5


## The smallest clearance anywhere on the hull's FORWARD half, in the outline's own space.
func _hull_clear(stop: Vector2, head: Vector2) -> float:
	var side := Vector2(-head.y, head.x)
	var worst := INF
	for n in 41:
		var a := -PI * 0.5 + PI * float(n) / 40.0
		var local_fwd := cos(a) * Rules.BOAT_HULL_HALF_TILES
		var local_side := sin(a) * Rules.BOAT_HULL_BEAM_TILES * 0.5
		var p := stop + head * local_fwd + side * local_side + Vector2(_off, _off)
		worst = minf(worst, _signed_clear(p))
	return worst


## Drives the sim's own beach cursor to `k` and lets the game launch its own boat there.
func _force_arrival(k: int, n: int, predicted: float) -> void:
	var b: Battle = _game.battle
	var before := b.boat_pos.size()
	var due := Rules.BOAT_FIRST_SEC + float(b._boats_launched) * Rules.BOAT_INTERVAL_SEC
	while b.elapsed < due - 0.5:
		b.step(0.2)
		await process_frame
	b._beach_cursor = k
	while b.boat_pos.size() == before:
		b.step(0.05)
		await process_frame
	var i := before
	print("--- forced boat %d at beach %d (wanted ring #%d), predicted clearance %+.2f"
		% [i, int(b.boat_beach[i]), k, predicted])
	while int(b.boat_state[i]) != 1:
		b.step(0.2)
		await process_frame
	var fv := _game.field_view
	fv.zoom = 1.8
	_centre_on_boat(i)
	await _settle(4)
	await _shot("8%d_worst_%d_ring%d" % [n, n, k])
	# ⚠⚠ **AND THE SAME HULL FROM STRAIGHT ABOVE.** At the play pitch a hull floating in front of raised
	# land overlaps it on the glass whether or not it overlaps it on the ground — the tilt is exactly
	# where this question hides. At `CAM_PITCH_MAX_DEG` the picture is nearly a plan view, so what
	# overlaps there overlaps in fact.
	var was_pitch := fv.cam_pitch_deg
	while fv.cam_pitch_deg < Look.CAM_PITCH_MAX_DEG - 0.01:
		fv.tilt_by(5.0)
	_centre_on_boat(i)
	await _settle(4)
	await _shot("9%d_worst_%d_topdown" % [n, n])
	while fv.cam_pitch_deg > was_pitch + 0.01:
		fv.tilt_by(-5.0)


## Distance from `p` to the drawn outline, **negative when `p` is inside it** (on land).
func _signed_clear(p: Vector2) -> float:
	var d := INF
	for raw in _coast:
		var s = raw as Array
		d = minf(d, _seg_dist(p, Vector2(s[0], s[1]), Vector2(s[2], s[3])))
	return -d if _inside(p) else d


func _inside(p: Vector2) -> bool:
	var crossings := 0
	for raw in _coast:
		var s = raw as Array
		var ay := float(s[1])
		var by := float(s[3])
		if (ay > p.y) == (by > p.y):
			continue
		var ax := float(s[0])
		var bx := float(s[2])
		var x := ax + (p.y - ay) / (by - ay) * (bx - ax)
		if x > p.x:
			crossings += 1
	return crossings % 2 == 1


func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 <= 0.0:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


# --- mode: does a press-and-drag on the field move the camera? --------------------------------------
## ⚠ **A negative control is built in.** "The drag was eaten" and "the drag is dead everywhere" look
## identical from one measurement, so the same gesture is run over LAND and over WATER and the two are
## compared.

func _drag() -> void:
	var fv := _game.field_view
	var b: Battle = _game.battle
	# A point on the island, and a point out on the open sea. Both are asked of the shell's OWN hit
	# test rather than guessed, so what is dragged on is what the game thinks it is.
	var on_land := Vector2.ZERO
	var on_water := Vector2.ZERO
	for ty in b.grid.h:
		for tx in b.grid.w:
			if b.grid.passable[ty * b.grid.w + tx] != 0:
				var p := fv.tile_to_screen_px(tx, ty)
				if p.x > 200.0 and p.x < 1080.0 and p.y > 120.0 and p.y < 600.0:
					on_land = p
					break
		if on_land != Vector2.ZERO:
			break
	on_water = Vector2(1180.0, 660.0)
	print("--- land point %s -> tile %d | water point %s -> tile %d"
		% [str(on_land), _game._tile_at(on_land), str(on_water), _game._tile_at(on_water)])

	await _shot("70_drag_before")
	var was := fv.cam_px
	var goals_was := _goals(b)
	await _drag_from(on_land)
	print("--- drag from LAND: cam %s -> %s (moved %.1f px) | walk goals %s -> %s"
		% [str(was), str(fv.cam_px), (fv.cam_px - was).length(), str(goals_was), str(_goals(b))])
	await _shot("71_drag_from_land")

	was = fv.cam_px
	await _drag_from(on_water)
	print("--- drag from WATER: cam %s -> %s (moved %.1f px)" % [str(was), str(fv.cam_px), (fv.cam_px - was).length()])
	await _shot("72_drag_from_water")

	# **A press that never moves must still command**, and a press that wobbles by a pixel or two must
	# still command. Both are asked of the shell rather than assumed.
	# ⚠ **A DIFFERENT 조각 each time.** Clicking the same one twice cannot tell「it ordered again」from
	# 「nothing happened」 — the column already holds that number.
	var spots := [on_land, on_land + Vector2(0.0, 60.0), on_land + Vector2(60.0, 120.0)]
	var wobbles := [0.0, 3.0, 8.0]
	for k in 3:
		var b2: Battle = _game.battle
		var before_goal := _goals(b2)
		was = fv.cam_px
		await _click_wobble(spots[k], wobbles[k])
		print("--- click at %s with %.0f px of wobble (that 조각 is %d): cam moved %.1f px | walk goals %s -> %s"
			% [str(spots[k]), wobbles[k], _game._tile_at(spots[k]), (fv.cam_px - was).length(),
				str(before_goal), str(_goals(b2))])
	await _shot("73_after_clicks")


## The 조각 the player ordered each standing body to, which is the sim's own record of「he took it」.
func _goals(b: Battle) -> Array:
	var out := []
	for i in b.ashore_ids():
		out.append(int(b.soldier_order[int(i)]))
	return out


func _click_wobble(at: Vector2, px: float) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = at
	down.pressed = true
	root.push_input(down, true)
	await process_frame
	var here := at
	if px > 0.0:
		here = at + Vector2(px, 0.0)
		var mv := InputEventMouseMotion.new()
		mv.position = here
		mv.relative = Vector2(px, 0.0)
		root.push_input(mv, true)
		await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = here
	up.pressed = false
	root.push_input(up, true)
	await _settle(3)


func _drag_from(at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = at
	down.pressed = true
	root.push_input(down, true)
	await process_frame
	var here := at
	for _n in 10:
		var step := Vector2(-24.0, 0.0)
		here += step
		var mv := InputEventMouseMotion.new()
		mv.position = here
		mv.relative = step
		root.push_input(mv, true)
		await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = here
	up.pressed = false
	root.push_input(up, true)
	await _settle(3)


# --- mode: several arrivals, on the sides the ring hands out ----------------------------------------

func _arrivals() -> void:
	var b: Battle = _game.battle
	var shot := 0
	while shot < 8:
		var want := Rules.BOAT_FIRST_SEC + float(shot) * Rules.BOAT_INTERVAL_SEC + 20.0
		while b.elapsed < want:
			b.step(0.2)
			await process_frame
		if shot >= b.boat_pos.size() or int(b.boat_state[shot]) != 1:
			print("--- boat %d not arrived at t=%.1f" % [shot, b.elapsed])
			shot += 1
			continue
		var fv := _game.field_view
		_overlap_report(shot, _aabb_of(fv._boats[shot]))
		fv.zoom = 1.4
		_centre_on_boat(shot)
		await _settle(3)
		await _shot("5%d_arrival_%d" % [shot, shot])
		fv.zoom = Look.survey_zoom_of(b.grid.w, b.grid.h)
		_centre_on_boat(shot)
		await _settle(3)
		await _shot("6%d_arrival_%d_survey" % [shot, shot])
		shot += 1


# --- mode: nobody touches the camera. How much of a crossing does a still player see? ---------------

func _still() -> void:
	for t in [8.0, 14.0, 20.0, 23.0, 25.0, 28.0, 36.0]:
		await _until(t)
		await _shot("3%d_still_t%02d" % [[8.0, 14.0, 20.0, 23.0, 25.0, 28.0, 36.0].find(t), int(t)])


# --- mode: the deck seen from low down, where a height is readable ----------------------------------

func _side() -> void:
	await _until(11.0)
	var fv := _game.field_view
	while fv.cam_pitch_deg > Look.CAM_PITCH_MIN_DEG + 0.01:
		fv.tilt_by(-5.0)
	_zoom(10)
	_centre_on_boat(0)
	await _settle(2)
	await _shot("20_low_pitch")
	fv.turn_by(90.0)
	_centre_on_boat(0)
	await _settle(2)
	await _shot("21_low_pitch_turned")

	# The bow, from behind the boat's own course.
	while fv.cam_pitch_deg < Look.CAM_PITCH_DEG - 0.01:
		fv.tilt_by(5.0)
	fv.turn_by(-90.0)
	_centre_on_boat(0)
	await _settle(2)
	await _shot("22_back_to_play_pitch")

	# And the hull sitting over the shore, at the zoom the island opens at.
	await _until(26.0)
	while fv.zoom > 0.90:
		_zoom_out(1)
	_centre_on_boat(0)
	await _settle(2)
	await _shot("23_arrived_survey")


# --- the hand ---------------------------------------------------------------------------------------

func _click(at: Vector2) -> void:
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = at
		ev.pressed = down
		root.push_input(ev, true)


## **Pans the camera for `sec` seconds, a frame at a time**, so the sim keeps running underneath and
## every shot lands at the time its name says. ⚠ **Per frame and not one big `pan_by`** — the clamp
## sits inside `pan_by`, and a single jump would cross the roam bound where the travel used to stop.
func _pan(dir: Vector2, sec: float) -> void:
	var t := 0.0
	while t < sec:
		var dt := await _frame_delta()
		t += dt
		_game.field_view.pan_by(dir * PAN_PX_PER_SEC * dt)
	await process_frame


func _centre_on_boat(i: int) -> void:
	var b: Battle = _game.battle
	if i >= b.boat_pos.size():
		print("capture_boat: 배 %d 이 없다" % i)
		return
	var fv := _game.field_view
	var world := Look.tile_point_px(b.boat_pos[i] as Vector2)
	fv.cam_px = world - fv._visible_ground_px() * 0.5
	fv._clamp_cam()


func _zoom(times: int) -> void:
	for _n in times:
		_game.field_view.zoom_at(Vector2(640.0, 360.0), Look.ZOOM_STEP)


func _zoom_out(times: int) -> void:
	for _n in times:
		_game.field_view.zoom_at(Vector2(640.0, 360.0), 1.0 / Look.ZOOM_STEP)


# --- the clock --------------------------------------------------------------------------------------

func _frame_delta() -> float:
	await process_frame
	return root.get_process_delta_time()


func _until(sec: float) -> void:
	while _game.battle != null and _game.battle.elapsed < sec:
		await process_frame


func _settle(n: int) -> void:
	for _i in n:
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [_dir, name]
	if img.save_png(path) != OK:
		push_error("capture_boat: %s 를 못 썼다" % path)
	print("--- %s  %s" % [name, _where()])


## Where every hull is, on the ground and on the glass, at the moment of the shutter.
func _where() -> String:
	var b: Battle = _game.battle
	if b == null:
		return "battle null"
	var fv := _game.field_view
	var out := "t=%.2f zoom=%.3f cam=%s" % [b.elapsed, fv.zoom, str(fv.cam_px.round())]
	for i in b.boat_pos.size():
		var at: Vector2 = b.boat_pos[i]
		var scr := fv.world_to_screen_px(Look.tile_point_px(at))
		var on := scr.x >= 0.0 and scr.x <= 1280.0 and scr.y >= 0.0 and scr.y <= 720.0
		var land := "?"
		var tx := int(floor(at.x))
		var ty := int(floor(at.y))
		if tx >= 0 and ty >= 0 and tx < b.grid.w and ty < b.grid.h:
			land = "LAND" if b.grid.passable[ty * b.grid.w + tx] != 0 else "sea"
		else:
			land = "offmap"
		out += " | boat%d st=%d tile=(%.2f,%.2f) %s screen=(%.0f,%.0f) %s" % [
			i, int(b.boat_state[i]), at.x, at.y, land, scr.x, scr.y,
			"ON-SCREEN" if on else "off"]
	return out
