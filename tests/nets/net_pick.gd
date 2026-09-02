extends RefCounted
## **The press finds what the player is pointing at — a body by where it is DRAWN, the ground by where
## the engine's own ray meets it — at every turn of the board.** Ticket 03-16.
##
## Two rows, both driving the real `Game` in the tree with `_ready()` wiring and the real press path
## (`_unhandled_input` press and release), anchored on `Camera3D.unproject_position` and the engine's
## `project_ray_*` and **never on the view's own round trip** — `how-nets-lie` (2026-08-25) records that a
## round trip cancels a defect present in both halves, and that a press at screen centre measures no
## coordinate transform at all. Every press here is at a drawn sprite or a jittered point off centre.
##
## ⚠⚠ **THE FIXTURE PAIRING THE THREE PROBES OF 2026-09-02 NEEDED**: `game.set_process(false)` so the
## sim does not walk the hand-placed bodies between the press and the read, **and** the field's own
## `_process` kept on so the yaw sweep settles and the sprite pool fills. A `SceneTree` script that reads
## `game.field_view` on the frame it adds the node reads `null` — two frames are pumped first.
##
## ⚠ **Bodies are placed by writing `soldier_pos`**, four 검사 two 조각 apart on open 1층 ground, so a
## pressed body has a neighbour close enough to be picked by mistake and far enough not to overlap it.
##
## **Row 1** was red before the code went in: chest and head presses picked nobody at yaw 90 and 180
## at pitch 40, and everything but the foot missed at pitch 20 — the half-조각 origin error the ticket
## measured, and the pitch the fix on the ground could never reach. **Its edge presses were red a
## second time** (2026-09-02, the bounce): the rectangle was the sprite's CANVAS, 2.2 times the ink.
## **Row 2** was red at a 2층 bias of 0.071 조각 up the screen — the stepped ray answering at a rung
## instead of at the surface. **Its cliff-face row** is what measures the face branch and the sign of
## `FACE_HIT_INSET`, which the lattice forgives as an edge.

const YAWS := [0.0, 90.0, 180.0, 270.0]
const PITCHES := [20.0, 40.0, 80.0]
## The jittered lattice over the glass for the terrain row, and the seed that pins it. **A pinned seed is
## what lets two rounds disagree about the code rather than about the dice.**
const LATTICE_W := 64
const LATTICE_H := 36
const LATTICE_SEED := 316
## How far along the engine ray the oracle steps, in 조각. 0.01 puts its hit within 0.008 조각 of the
## true surface point, which is why disagreements inside `EDGE_TOL` of a 조각 edge are not counted.
const RAY_STEP := 0.01
const EDGE_TOL := 0.02


func run(t) -> void:
	var game := await _open_the_island(t)
	if game == null:
		t.done()
		return
	await _a_press_on_a_drawn_body_picks_it_at_every_yaw_and_pitch(t, game)
	await _the_terrain_pick_answers_the_engine_ray_at_every_yaw(t, game)
	t.root.remove_child(game)
	game.queue_free()
	t.done()


## The real `Game`, on the tree, on the island, with the sim frozen and the field still painting.
func _open_the_island(t) -> Game:
	var game := Game.new()
	t.root.add_child(game)
	await t.pump_frames(2)
	t.ok(game.field_view != null, "자가 점검 — 두 프레임 뒤에 field_view 가 있다 (첫 프레임엔 null 이다)")
	if game.field_view == null:
		return null
	game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
	await t.pump_frames(1)
	t.ok(game.battle != null, "자가 점검 — 시작하기를 누르면 섬이 선다")
	if game.battle == null:
		return null
	game.set_process(false)
	game.field_view.set_process(true)
	await t.pump_frames(2)
	return game


# --- row 1: the body ------------------------------------------------------------------------------

## Four 검사 on open 1층 ground, pressed at their drawn foot, chest and head at four yaws and three
## pitches, through the real press path. **Every press must pick that body and no other**; a press on
## the open ground in front of them must pick nobody.
func _a_press_on_a_drawn_body_picks_it_at_every_yaw_and_pitch(t, game: Game) -> void:
	var fv: FieldView = game.field_view
	var b: Battle = game.battle
	var g: Grid = b.grid
	var ids: Array = b.ashore_ids()
	t.eq(ids.size(), Rules.SWORDSMAN_START_COUNT, "자가 점검 — 섬에 검사 넷이 서 있다")
	if ids.size() < 2:
		return
	var base := _open_square(g)
	t.ok(base.x >= 0, "자가 점검 — 눈금 1 이상이 ±3 안에 없는 1층 땅에 2x2 자리가 있다")
	if base.x < 0:
		return
	var spots := [base, base + Vector2i(2, 0), base + Vector2i(0, 2), base + Vector2i(2, 2)]
	for k in ids.size():
		var spot: Vector2i = spots[k % spots.size()]
		b.soldier_pos[int(ids[k])] = Vector2(float(spot.x), float(spot.y))
	await t.pump_frames(2)

	for yaw: float in YAWS:
		await _turn_to(t, game, fv, yaw)
		for pitch: float in PITCHES:
			await _tilt_to(t, game, fv, pitch)
			_press_every_drawn_body(t, game, fv, b, "요 %d° 피치 %d°" % [int(yaw), int(pitch)])
		await _tilt_to(t, game, fv, Look.CAM_PITCH_DEG)


## The 2x2 corner of four 조각 (0,0)·(2,0)·(0,2)·(2,2) that are all passable 1층 with no 눈금 ≥ 1
## within ±3 of any of them, nearest the middle of the board so the bodies stay on the glass when the
## pitch is steep. `(-1, -1)` when the island has no such place.
func _open_square(g: Grid) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	var mid := Vector2(float(g.w) * 0.5, float(g.h) * 0.5)
	for ty in g.h:
		for tx in g.w:
			var ok := true
			for off: Vector2i in [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2)]:
				if not _open_ground(g, tx + off.x, ty + off.y):
					ok = false
					break
			if not ok:
				continue
			var d := Vector2(float(tx) + 1.0, float(ty) + 1.0).distance_to(mid)
			if d < best_d:
				best_d = d
				best = Vector2i(tx, ty)
	return best


func _open_ground(g: Grid, tx: int, ty: int) -> bool:
	if tx < 0 or ty < 0 or tx >= g.w or ty >= g.h:
		return false
	var t := g.tile_index(tx, ty)
	if g.passable[t] != 1 or g.level_of(t) != 0:
		return false
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var nx := tx + dx
			var ny := ty + dy
			if nx < 0 or ny < 0 or nx >= g.w or ny >= g.h:
				continue
			if g.level_of(g.tile_index(nx, ny)) >= 1:
				return false
	return true


## Every drawn 검사 sprite is matched to the body standing under it (nearest foot within 0.6 조각 —
## the matching is the net's own and reads nothing the pick reads), then pressed three times.
func _press_every_drawn_body(t, game: Game, fv: FieldView, b: Battle, label: String) -> void:
	var pressed := 0
	# The drawn foot nearest the camera, so the 「nobody」 press below is in front of the whole group and
	# not in front of one body and on top of the next — at yaw 0 two 조각 in front of the back row IS the
	# front row.
	var down := fv._ground_down()
	var front_foot := Vector2.INF
	for k in fv._sprites_used:
		var s: Sprite3D = fv._sprites[k]
		if not s.visible or s.texture == null or s.texture == fv._tex_flat:
			continue
		var foot_xz := Vector2(s.position.x, s.position.z)
		var who := -1
		var best := 0.6
		for raw in b.ashore_ids():
			var i := int(raw)
			var d := ((b.soldier_pos[i] as Vector2) + Vector2(0.5, 0.5)).distance_to(foot_xz)
			if d < best:
				best = d
				who = i
		if who < 0:
			continue
		pressed += 1
		var tall := float(s.texture.get_height()) * s.scale.y * s.pixel_size
		# ⚠ Inside the picture by a hair at both ends: a press on the very edge row of a sprite is a
		# rounding question, not a picking one.
		var points := {
			"발": s.position - Vector3(0.0, tall * 0.5 - 0.02, 0.0),
			"가슴": s.position,
			"머리": s.position + Vector3(0.0, tall * 0.5 - 0.05, 0.0),
		}
		if not front_foot.is_finite() or foot_xz.dot(down) > front_foot.dot(down):
			front_foot = foot_xz
		for where: String in points:
			var scr: Vector2 = fv._cam.unproject_position(points[where])
			var on_glass := _on_glass(scr)
			t.ok(on_glass, "%s — 몸 %d 의 %s 이 화면 안에 그려진다 %s" % [label, who, where, scr.round()])
			if not on_glass:
				continue
			game._let_go()
			_press_release(game, scr)
			var got := int(game.hand.ids[0]) if game.hand.ids.size() == 1 else -1
			t.ok(got == who and game.hand.ids.size() == 1,
				"%s — 몸 %d 의 %s 을 누르면 그 몸이 잡힌다 (잡힌 것 %s)" % [label, who, where,
				("몸 %d" % got) if got >= 0 else "없음"])
		# ⚠⚠ **THE WIDTH, WHICH THE THREE PRESSES ABOVE NEVER MEASURE** — they all sit on the picture's
		# vertical centre line, and `verify` multiplied the rectangle's width by 12 with every one of
		# them still green. **The drawn edges are the INK's**, the opaque columns of the texture the
		# sprite wears, read off the PNG here and never asked of the view: a body's canvas is 72
		# texels with 33 of ink, and a rectangle on the canvas picked a press 8 px beside the man
		# (`verify-look`, 2026-09-02). The edge world points are the sprite's centre pushed along the
		# CAMERA's right axis — a billboard's own x — and unprojected by the engine.
		var cols := _ink_cols_of(s.texture)
		var texel := s.scale.x * s.pixel_size
		var half_w := float(s.texture.get_width()) * 0.5
		var cam_x: Vector3 = fv._cam.global_transform.basis.x
		var left: Vector2 = fv._cam.unproject_position(s.position + cam_x * ((float(cols.x) - half_w) * texel))
		var right: Vector2 = fv._cam.unproject_position(s.position + cam_x * ((float(cols.y) + 1.0 - half_w) * texel))
		var edges := {
			"왼 가장자리 1px 안": [left + Vector2(1.0, 0.0), who],
			"오른 가장자리 1px 안": [right - Vector2(1.0, 0.0), who],
			"왼 가장자리 3px 밖": [left - Vector2(3.0, 0.0), -1],
			"오른 가장자리 3px 밖": [right + Vector2(3.0, 0.0), -1],
		}
		for name: String in edges:
			var scr: Vector2 = edges[name][0]
			var want := int(edges[name][1])
			if not _on_glass(scr):
				t.ok(false, "%s — 몸 %d 의 %s 이 화면 안이다 %s" % [label, who, name, scr.round()])
				continue
			game._let_go()
			_press_release(game, scr)
			var got := int(game.hand.ids[0]) if game.hand.ids.size() == 1 else -1
			if want >= 0:
				t.ok(got == want and game.hand.ids.size() == 1,
					"%s — 몸 %d 의 %s 을 누르면 그 몸이 잡힌다 (잡힌 것 %s)" % [label, who, name,
					("몸 %d" % got) if got >= 0 else "없음"])
			else:
				# ⚠ Nobody — and not the neighbour two 조각 over either, which the same empty hand says.
				t.ok(game.hand.is_empty(),
					"%s — 몸 %d 의 %s 을 누르면 아무도 안 잡힌다 — 옆 몸도 아니다 (잡힌 것 %s)" % [label, who, name,
					("몸 %d" % got) if got >= 0 else "없음"])
	t.eq(pressed, b.ashore_ids().size(), "%s — 자가 점검: 검사 넷이 다 그려져 있고 넷 다 눌렀다" % label)

	# The inversion: open ground two 조각 in FRONT of a body (toward the camera) is below every drawn
	# foot on the glass and inside no rectangle, so it must pick nobody.
	if front_foot.is_finite():
		var ground_tiles := front_foot + down * 2.0
		var h: float = fv._ground_h(int(floor(ground_tiles.x)), int(floor(ground_tiles.y)))
		var scr: Vector2 = fv._cam.unproject_position(Vector3(ground_tiles.x, h, ground_tiles.y))
		if _on_glass(scr):
			game._let_go()
			_press_release(game, scr)
			t.ok(game.hand.is_empty(), "%s — 몸 앞 두 조각의 맨땅을 누르면 아무도 안 잡힌다" % label)
	game._let_go()


## The first and last texel column of `pic` holding any opaque pixel, `(lo, hi)` inclusive — the ink's
## own extent, scanned off the PNG here so the assertion above is against the picture and not against
## whatever the view remembers about it. The whole canvas when the picture has no ink at all.
func _ink_cols_of(pic: Texture2D) -> Vector2i:
	var img := pic.get_image()
	var w := img.get_width()
	var lo := w
	var hi := -1
	for x in w:
		for y in img.get_height():
			if img.get_pixel(x, y).a > 0.0:
				lo = mini(lo, x)
				hi = maxi(hi, x)
				break
	if hi < lo:
		return Vector2i(0, w - 1)
	return Vector2i(lo, hi)


# --- row 2: the ground ----------------------------------------------------------------------------

## The engine's ray marched `RAY_STEP` down over the same flat-topped 조각 heights, against
## `screen_to_terrain_px` → `world_to_tile`, over a jittered lattice on the whole glass, at four yaws and
## two zooms. **Zero disagreements whose pick lands more than `EDGE_TOL` from a 조각 edge**, and the mean
## offset of a 2층 조각's own centre through the pick is 0.00 ± 0.01 조각.
func _the_terrain_pick_answers_the_engine_ray_at_every_yaw(t, game: Game) -> void:
	var fv: FieldView = game.field_view
	var g: Grid = game.battle.grid
	var heights := PackedFloat32Array()
	heights.resize(g.w * g.h)
	var h_top := -INF
	for ty in g.h:
		for tx in g.w:
			var h: float = fv._ground_h(tx, ty)
			heights[g.tile_index(tx, ty)] = h
			h_top = maxf(h_top, h)
	var rng := RandomNumberGenerator.new()
	for zoom_name: String in ["측량 줌", "ZOOM_MAX"]:
		for yaw: float in YAWS:
			await _turn_to(t, game, fv, yaw)
			fv.zoom = Look.ZOOM_MAX if zoom_name == "ZOOM_MAX" else Look.survey_zoom_of(g.w, g.h)
			var map_px := Vector2(float(g.w), float(g.h)) * Look.TILE_PX
			fv.cam_px = map_px * 0.5 - fv._visible_ground_px() * 0.5
			fv._clamp_cam()
			await t.pump_frames(2)
			var label := "%s 요 %d°" % [zoom_name, int(yaw)]
			rng.seed = LATTICE_SEED
			_lattice_against_the_engine(t, game, fv, g, heights, h_top, rng, label)
			_centre_bias_by_level(t, fv, g, label)
			_the_face_of_a_cliff_names_the_tall_tile(t, fv, g, heights, h_top, label)


func _lattice_against_the_engine(t, game: Game, fv: FieldView, g: Grid, heights: PackedFloat32Array,
		h_top: float, rng: RandomNumberGenerator, label: String) -> void:
	var land := 0
	var miss := 0
	var off_edge := 0
	var worst := 0.0
	var sample := ""
	for j in LATTICE_H:
		for i in LATTICE_W:
			var at := Vector2((float(i) + rng.randf()) * Look.VIEWPORT_W_PX / float(LATTICE_W),
				(float(j) + rng.randf()) * Look.VIEWPORT_H_PX / float(LATTICE_H))
			var eng := _engine_terrain_tile(fv, g, heights, h_top, at)
			if eng.x < 0 or eng.y < 0 or eng.x >= g.w or eng.y >= g.h:
				continue
			var eng_t := g.tile_index(eng.x, eng.y)
			if g.water[eng_t] != 0:
				continue
			land += 1
			var got: int = game._tile_at(at)
			if got == eng_t:
				continue
			miss += 1
			var w := fv.screen_to_terrain_px(at) / Look.TILE_PX
			var fx: float = w.x - floor(w.x)
			var fy: float = w.y - floor(w.y)
			var edge := minf(minf(fx, 1.0 - fx), minf(fy, 1.0 - fy))
			if edge > EDGE_TOL:
				off_edge += 1
				worst = maxf(worst, edge)
				if sample == "":
					sample = " 예: 화면 %s 엔진 (%d,%d) 픽 %s" % [at.round(), eng.x, eng.y,
						Vector2i(int(floor(w.x)), int(floor(w.y)))]
	t.ok(land >= 200, "%s — 자가 점검: 격자 %d 점 중 %d 점이 땅에 떨어졌다" % [label, LATTICE_W * LATTICE_H, land])
	t.eq(off_edge, 0, "%s — 엔진 광선과 다른 조각을 대는 점이 가장자리 %.2f 조각 밖에서 0개다 (다른 점 %d, 가장 깊은 %.3f)%s"
		% [label, EDGE_TOL, miss, worst, sample])


## The ENGINE's answer: its ray from the camera, marched `RAY_STEP` 조각 at a time from just above the
## tallest surface down to the water, first 조각 whose top is at or above the ray wins. Off-grid answers
## an off-grid 조각 and the caller drops it.
func _engine_terrain_tile(fv: FieldView, g: Grid, heights: PackedFloat32Array, h_top: float,
		at: Vector2) -> Vector2i:
	var o: Vector3 = fv._cam.project_ray_origin(at)
	var d: Vector3 = fv._cam.project_ray_normal(at)
	# Nothing stands above the tallest surface, so the march starts a little above it.
	var p := o + d * ((h_top + 0.05 - o.y) / d.y)
	var floor_h := Look.TERRAIN_H_WATER - 0.01
	var guard := 0
	while p.y > floor_h and guard < 100000:
		var tx := int(floor(p.x))
		var ty := int(floor(p.z))
		var gh := 0.0
		if tx >= 0 and ty >= 0 and tx < g.w and ty < g.h:
			gh = heights[ty * g.w + tx]
		if p.y <= gh:
			return Vector2i(tx, ty)
		p += d * RAY_STEP
		guard += 1
	var s := o + d * ((Look.TERRAIN_H_WATER - o.y) / d.y)
	return Vector2i(int(floor(s.x)), int(floor(s.z)))


## **The visible FACE of every 2층 cliff, sampled directly.** For each 2층 조각 whose camera-side
## neighbour is 1층 land, screen points down the shared edge between the tall 조각's top and the low
## neighbour's ground — three places along the edge, seven heights — through the pick and through the
## engine march, compared 조각 for 조각 **with no edge tolerance at all**.
##
## ⚠⚠ **THE LATTICE ROW CANNOT SEE THIS** (`verify`, 2026-09-02): a face hit is answered ON the shared
## edge pushed `FACE_HIT_INSET` inside, and a nudge of 0.0005 조각 the wrong way — into the 조각 in
## FRONT of the cliff — is a disagreement 0.0005 조각 from an edge, which `EDGE_TOL` forgives. The sign
## of that nudge, and the face branch existing at all, are measured here and nowhere else: with the
## sign flipped or the branch gone the pick names the low 조각 in front, and the engine does not.
func _the_face_of_a_cliff_names_the_tall_tile(t, fv: FieldView, g: Grid, heights: PackedFloat32Array,
		h_top: float, label: String) -> void:
	var down := fv._ground_down()
	var toward_cam := Vector2i(int(round(down.x)), int(round(down.y)))
	var samples := 0
	var engine_tall := 0
	var wrong := 0
	var example := ""
	for ty in g.h:
		for tx in g.w:
			var tall := g.tile_index(tx, ty)
			if g.water[tall] != 0 or g.level_of(tall) != 2:
				continue
			var nx := tx + toward_cam.x
			var ny := ty + toward_cam.y
			if nx < 0 or ny < 0 or nx >= g.w or ny >= g.h:
				continue
			var low := g.tile_index(nx, ny)
			if g.water[low] != 0 or g.level_of(low) != 0:
				continue
			var top: float = heights[tall]
			var ground: float = heights[low]
			# The shared edge, in 조각 units: the tall 조각's centre pushed half a 조각 toward the camera,
			# then along the edge itself.
			var edge_mid := Vector2(float(tx) + 0.5, float(ty) + 0.5) + Vector2(toward_cam) * 0.5
			var along := Vector2(float(-toward_cam.y), float(toward_cam.x))
			for u: float in [-0.3, 0.0, 0.3]:
				var e := edge_mid + along * u
				for k in 7:
					var h := lerpf(ground + 0.05, top - 0.05, float(k) / 6.0)
					var scr: Vector2 = fv._cam.unproject_position(Vector3(e.x, h, e.y))
					if not _on_glass(scr):
						continue
					samples += 1
					var eng := _engine_terrain_tile(fv, g, heights, h_top, scr)
					var eng_t := g.tile_index(eng.x, eng.y) if eng.x >= 0 and eng.y >= 0 and eng.x < g.w and eng.y < g.h else -1
					if eng_t == tall:
						engine_tall += 1
					var got := fv.world_to_tile(fv.screen_to_terrain_px(scr))
					var got_t := g.tile_index(got.x, got.y) if got.x >= 0 and got.y >= 0 and got.x < g.w and got.y < g.h else -1
					if got_t != eng_t:
						wrong += 1
						if example == "":
							example = " 예: 절벽 (%d,%d) 높이 %.2f 화면 %s 엔진 %s 픽 %s" % [tx, ty, h, scr.round(), eng, got]
	t.ok(samples >= 20 and engine_tall * 2 >= samples,
		"%s — 자가 점검: 절벽 면 위의 점 %d 개 중 엔진이 %d 개를 그 2층 조각으로 댄다" % [label, samples, engine_tall])
	t.eq(wrong, 0, "%s — 절벽 면을 누르면 픽과 엔진이 같은 조각을 댄다 — 가장자리 봐주기 없이%s" % [label, example])


## Every land 조각's own centre, unprojected by the engine at its own height, put through the pick:
## the offset along screen-down between what comes back and the true centre, averaged per 눈금.
## **The 2층 mean was -0.071 조각 (up the screen) before the fix; the 1층 mean 0.001.**
func _centre_bias_by_level(t, fv: FieldView, g: Grid, label: String) -> void:
	var sum := {}
	var n := {}
	for ty in g.h:
		for tx in g.w:
			var tile := g.tile_index(tx, ty)
			if g.water[tile] != 0:
				continue
			var lv := g.level_of(tile)
			if Grid.is_stair_level(lv):
				continue
			var centre := Look.tile_point_px(Vector2(float(tx), float(ty)))
			var h: float = fv._ground_h(tx, ty)
			var scr: Vector2 = fv._cam.unproject_position(Vector3(centre.x / Look.TILE_PX, h, centre.y / Look.TILE_PX))
			if not _on_glass(scr):
				continue
			var w := fv.screen_to_terrain_px(scr)
			if fv.world_to_tile(w) != Vector2i(tx, ty):
				continue   # hidden behind a storey — the visible face answers, and that is not bias
			var d := (w - centre).dot(fv._ground_down()) / Look.TILE_PX
			sum[lv] = float(sum.get(lv, 0.0)) + d
			n[lv] = int(n.get(lv, 0)) + 1
	for lv: int in [0, 2]:
		var count := int(n.get(lv, 0))
		t.ok(count > 0, "%s — 자가 점검: 눈금 %d 의 조각 %d 개가 화면에 있다" % [label, lv, count])
		if count == 0:
			continue
		var mean := float(sum[lv]) / float(count)
		t.ok(absf(mean) <= 0.01, "%s — 눈금 %d 조각 가운데의 픽 치우침이 0.00±0.01 조각이다 (평균 %.4f)" % [label, lv, mean])


# --- driving the shell ----------------------------------------------------------------------------

## Presses E through the shell until the board sits at `yaw`, letting each quarter's sweep run out on
## real frames. ⚠ Bounded — a sweep that never settles is a red, not a hang.
func _turn_to(t, game: Game, fv: FieldView, yaw: float) -> void:
	var guard := 0
	while absf(_yaw_off(fv, yaw)) > 0.001 and guard < 4:
		game._unhandled_input(_key_edge(KEY_E, true))
		game._unhandled_input(_key_edge(KEY_E, false))
		var n := 0
		while (fv._yaw_remaining != 0.0 or n == 0) and n < 240:
			await t.pump_frames(1)
			n += 1
		guard += 1
	await t.pump_frames(2)
	t.ok(absf(_yaw_off(fv, yaw)) <= 0.001,
		"자가 점검 — E 로 판이 %d° 에 멎었다 (지금 %.4f°)" % [int(yaw), fv.cam_yaw_deg])


## The signed shortest turn from where the board sits to `yaw`, in (-180, 180]. ⚠ **Wrapped both ways**:
## the sweep lands a hair either side of the notch (179.9999 is a real reading), and a one-sided
## `fmod(a - b + 720, 360)` reads 179.9999 wanting 180 as a whole turn short.
func _yaw_off(fv: FieldView, yaw: float) -> float:
	return fmod(fv.cam_yaw_deg - yaw + 540.0, 360.0) - 180.0


## Presses R or F through the shell until the pitch is `pitch`. The tilt is instant; two frames are
## pumped so the camera and the sprite pool are placed for it.
func _tilt_to(t, game: Game, fv: FieldView, pitch: float) -> void:
	var guard := 0
	while absf(fv.cam_pitch_deg - pitch) > 0.001 and guard < 20:
		game._unhandled_input(_key_edge(KEY_R if pitch > fv.cam_pitch_deg else KEY_F, true))
		guard += 1
	await t.pump_frames(2)
	t.ok(absf(fv.cam_pitch_deg - pitch) <= 0.001,
		"자가 점검 — R/F 로 피치가 %d° 다 (지금 %.1f°)" % [int(pitch), fv.cam_pitch_deg])


func _press_release(game: Game, at: Vector2) -> void:
	game._unhandled_input(_click(at))
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = at
	game._unhandled_input(up)


func _click(at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	return ev


func _key_edge(code: int, pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.pressed = pressed
	ev.keycode = code
	return ev


func _on_glass(scr: Vector2) -> bool:
	return scr.x >= 0.0 and scr.y >= 0.0 and scr.x < Look.VIEWPORT_W_PX and scr.y < Look.VIEWPORT_H_PX
