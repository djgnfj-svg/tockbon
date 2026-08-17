extends RefCounted
## `field_view`'s camera: one transform, in one place. Every check here drives the pure functions
## directly — `.new()` and nothing else, no tree, matching `boat-and-landing` section 7.1's own
## description of what they must do. Nothing here draws; `net_draw_leaf` and `net_shell` cover that
## half.
##
## `position = -cam_px * zoom + _shake_offset()` is composed in `_process()` in the real game; these
## checks set `cam_px` / `zoom` / the shake fields by hand and then call `fv.position =
## fv._compose_position()` themselves, the same one line `_process()` runs, so nothing here can drift
## from what the game actually does each frame.


## Every `FieldView` this net constructs, so `run` can free them all at the end. `FieldView` is a
## `Node2D` (a real `CanvasItem` RID), never `RefCounted` like `Grid` or `Battle` — left unfreed, the
## engine reports leaked RIDs and objects at exit, which the wrapper's stderr-is-failure rule catches.
var _created: Array = []


func run(t) -> void:
	_setup_opens_at_zoom_min(t)
	_process_writes_scale_from_zoom(t)
	_pan_by_moves_at_the_right_rate(t)
	_world_to_tile_floors_at_the_boundary(t)
	_round_trip_at_three_zooms_and_two_pans(t)
	_shake_is_inside_the_same_expression(t)
	_zoom_holds_the_cursor(t)
	_zoom_min_shows_the_whole_map(t)
	_painted_area_covers_the_viewport(t)
	_the_clamp_holds_and_the_camera_really_moves(t)
	_both_ends_of_the_three_constants(t)
	for raw in _created:
		var fv: FieldView = raw
		fv.free()
	_created = []


func _fv() -> FieldView:
	var fv := FieldView.new()
	_created.append(fv)
	return fv


## An island opens zoomed all the way out — section 9's "Survey" acceptance row, and the comment
## sitting directly above the line in `setup()`. Nothing else in this file drives `setup()` (every
## other check sets `zoom` / `cam_px` by hand), so without this the opening zoom is only pinned by
## accident wherever a `net_shell` wheel test happens to start from it.
func _setup_opens_at_zoom_min(t) -> void:
	var fv := _fv()
	fv.zoom = Look.ZOOM_MAX          # a stale value from a previous island, on purpose
	fv.cam_px = Vector2(500.0, 400.0)
	fv.setup(Battle.new(), Army.new(), [])
	t.eq(fv.zoom, Look.ZOOM_MIN, "setup 이 줌을 ZOOM_MIN 으로 되돌린다 — 섬은 항상 다 보이는 채로 열린다")
	# ⚠ **A literal, not `_clamp_cam()` called again here to check against.** `setup()` sets
	# `cam_px = Vector2.ZERO` and then calls `_clamp_cam()` once — deleting that call is a real,
	# measured mutation that stays green if this only re-derives the expected value the same way
	# `setup()` does, since it would reproduce the SAME bug. At ZOOM_MIN the visible world (2275.56 px
	# wide) is wider than the map (1920 px), so the clamp CENTRES the x axis: (1920 - 2275.56) / 2 =
	# -177.78. Without the clamp call, `cam_px` would still be sitting at the (0, 0) this function set
	# it to above (real bug window: an island opens with ~178 px of the right edge of the map cut off
	# on screen at zoom-out, correcting itself the instant the player first pans — section 9's Survey
	# acceptance row is exactly this frame).
	t.ok(fv.cam_px.distance_to(Vector2(-177.78, 0.0)) < 0.1,
		"setup 뒤 cam_px 가 정확히 (-177.78, 0.0) 이다 — 리터럴로 확인한다 (%.2f, %.2f)"
		% [fv.cam_px.x, fv.cam_px.y])
	# ⚠ Read directly off `fv` right after `setup()` — NOT after calling `_clamp_cam()` a second time
	# here, which would measure the function again instead of the state `setup()` actually left.
	var visible := fv._visible_world_rect()
	var margin_px := Look.WATER_MARGIN_TILES * Look.TILE_PX
	var painted := Rect2(Vector2(-margin_px, -margin_px),
		Vector2(Look.GRID_W, Look.GRID_H) * Look.TILE_PX + Vector2(margin_px, margin_px) * 2.0)
	t.ok(visible.position.x >= painted.position.x - 0.01 and visible.position.y >= painted.position.y - 0.01
			and visible.end.x <= painted.end.x + 0.01 and visible.end.y <= painted.end.y + 0.01,
		"setup 이 남긴 cam_px 그대로도 보이는 세계가 칠한 영역 안에 든다")


## `scale` is what actually carries the zoom to the screen — every draw call in `field_view.gd` runs
## in the node's own local space, and Godot applies `scale` to that space on its own. `_process` has
## to write it every frame, because `zoom_at` and `pan_by` change `zoom` / `cam_px` without touching
## `scale` themselves (see their own bodies) — nothing else in this file calls `_process` at all.
func _process_writes_scale_from_zoom(t) -> void:
	var fv := _fv()
	fv.zoom = 0.8
	fv.cam_px = Vector2.ZERO
	fv.scale = Vector2(1.0, 1.0)   # a stale value `_process` must overwrite
	fv._process(0.016)
	t.eq(fv.scale, Vector2(0.8, 0.8), "_process 가 scale 을 zoom 에서 다시 썼다")


## A pan by a SMALL screen delta, comfortably inside the clamp range (unlike the corner-drag check
## below, which only pins the ceiling), moves `cam_px` by exactly `-delta / zoom` — not `-delta`. This
## is what the clamp checks elsewhere cannot show: they push 4000-50000 px and read only the clamped
## endpoint, so the RATE never enters them at all.
func _pan_by_moves_at_the_right_rate(t) -> void:
	var fv := _fv()
	fv.zoom = 0.8
	fv.cam_px = Vector2(300.0, 300.0)
	var before: Vector2 = fv.cam_px
	fv.pan_by(Vector2(16.0, 8.0))
	var want := before - Vector2(16.0, 8.0) / 0.8
	t.ok(fv.cam_px.distance_to(want) < 0.01,
		"작게 끌면 cam_px 가 정확히 -delta / zoom 만큼 움직인다 (%.3f px 차)" % fv.cam_px.distance_to(want))

	# ⚠ Dropping the `/ zoom` is the plan's own named mutation for `pan_by` — confirmed to move the
	# value this check reads, at a zoom where the two answers actually differ.
	var without_zoom := before - Vector2(16.0, 8.0)
	t.ok(without_zoom.distance_to(want) > 1.0,
		"자가 점검 — '/ zoom' 을 빼면 줌 0.8에서 실제로 다른 값이 나온다는 뜻이다")


## `world_to_tile` has NO CALLER anywhere in `src/` this round (stage 4's drag is the planned one) and
## `net_draw_leaf._table()` lists it at 0 draws — true for "pure", but read as "verified" by anyone
## who does not know it has never actually been driven. This drives it directly: `Rules.TILE_PX` is
## 40.0, so tile 1 starts exactly at world x=40.0, and `floor` (not `round`) is what the boundary has
## to use — `round` would put 39.9 in tile 1 instead of tile 0.
func _world_to_tile_floors_at_the_boundary(t) -> void:
	var fv := _fv()
	t.eq(fv.world_to_tile(Vector2(0.0, 0.0)), Vector2i(0, 0), "원점은 (0,0) 타일이다")
	t.eq(fv.world_to_tile(Vector2(39.9, 0.0)), Vector2i(0, 0),
		"타일 경계 바로 앞(39.9px)은 아직 0번 타일이다 — round 였다면 1번이 나왔을 것이다 (자가 점검)")
	t.eq(fv.world_to_tile(Vector2(40.0, 0.0)), Vector2i(1, 0), "정확히 경계(40.0px)부터 1번 타일이다")
	t.eq(fv.world_to_tile(Vector2(79.9, 12.0)), Vector2i(1, 0), "79.9px 도 아직 1번 타일이다")
	t.eq(fv.world_to_tile(Vector2(0.0, 80.0)), Vector2i(0, 2), "세로도 같은 규칙이다 — 80.0px 는 2번 행이다")


## `at`, converted to world and back through the forward transform (`world * zoom + position`), must
## return `at` — the only round trip this file trusts, since there is no separate `world_to_screen_px`
## function to compare against (the plan deliberately keeps one conversion function, not two).
func _round_trips(fv: FieldView, at: Vector2) -> float:
	var world := fv.screen_to_world_px(at)
	var back := world * fv.zoom + fv.position
	return at.distance_to(back)


func _round_trip_at_three_zooms_and_two_pans(t) -> void:
	var zooms := [0.5625, 0.75, 1.0]
	var pans := [Vector2(0.0, 0.0), Vector2(400.0, 250.0)]
	var probes := [Vector2(0.0, 0.0), Vector2(640.0, 360.0), Vector2(1280.0, 720.0)]
	var bad := 0
	var checked := 0
	for z: float in zooms:
		for p: Vector2 in pans:
			var fv := _fv()
			fv.zoom = z
			fv.cam_px = p
			fv.position = fv._compose_position()
			for at: Vector2 in probes:
				checked += 1
				if _round_trips(fv, at) > 0.01:
					bad += 1
	t.ok(checked >= 6, "줌 셋 x 팬 둘, 적어도 여섯 조합을 쟀다 (%d개)" % checked)
	t.eq(bad, 0, "화면 좌표가 줌 0.5625 · 0.75 · 1.0 과 두 팬 위치 전부에서 월드로 되돌아온다")

	# Deliberately dropping `/ zoom` in `screen_to_world_px` is the plan's own named mutation —
	# confirmed here by measuring the SAME shape at a zoom where the two diverge.
	var broken := _fv()
	broken.zoom = 0.75
	broken.cam_px = Vector2.ZERO
	broken.position = broken._compose_position()
	var wrong_world := (Vector2(640.0, 360.0) - broken.position)   # no "/ zoom"
	var right_world := broken.screen_to_world_px(Vector2(640.0, 360.0))
	t.ok(wrong_world.distance_to(right_world) > 1.0,
		"자가 점검 — '/ zoom' 을 빼면 줌 0.75에서 실제로 다른 답이 나온다는 뜻이다")


## The shake has to be INSIDE `_compose_position`'s one expression, not a second offset applied
## somewhere else — and this pins the COMPOSED VALUE directly, never a round trip through
## `screen_to_world_px`. ⚠ A round trip is algebraically incapable of catching this: `world =
## (at - position) / zoom`, `back = world * zoom + position = at`, for ANY value `position` holds —
## measured, dropping the shake term from `_compose_position` (that row's own named mutation) left the
## earlier round-trip version of this check green at 21/21. Only the direct comparison below moves.
func _shake_is_inside_the_same_expression(t) -> void:
	var fv := _fv()
	fv.zoom = 0.75
	fv.cam_px = Vector2(120.0, 80.0)
	fv._shake_amp = Look.SHAKE_MAX_PX
	fv._shake_left = Look.SHAKE_SEC * 0.5
	var shake := fv._shake_offset()
	t.ok(shake.length() > 0.0, "흔들리는 중이다 (자가 점검)")
	fv.position = fv._compose_position()
	var expected := -fv.cam_px * fv.zoom + shake
	t.ok(fv.position.distance_to(expected) < 0.001,
		"position 이 정확히 -cam_px * zoom + shake_offset() 이다 — 흔들림이 그 식 안에 있다는 뜻이다")

	# ⚠ Deleting the shake term from `_compose_position` is the named mutation — confirmed here to
	# actually move the value this check reads, which the round trip above could never do.
	var without_shake := -fv.cam_px * fv.zoom
	t.ok(without_shake.distance_to(expected) > 0.5,
		"자가 점검 — 흔들림 항을 빼면 실제로 다른 값이 나온다 (%.2f px 차, 그래서 위 검사가 뭔가를 잰다)"
		% without_shake.distance_to(expected))


## Zooming about `at` keeps the WORLD point under it fixed, to well under a pixel.
func _zoom_holds_the_cursor(t) -> void:
	var fv := _fv()
	fv.zoom = 0.7
	fv.cam_px = Vector2(150.0, 90.0)
	fv.position = fv._compose_position()
	var at := Vector2(500.0, 300.0)
	var world_before := fv.screen_to_world_px(at)
	fv.zoom_at(at, 1.15)
	fv.position = fv._compose_position()
	var world_after := fv.screen_to_world_px(at)
	t.ok(fv.zoom > 0.7, "실제로 확대됐다 (자가 점검, %.4f)" % fv.zoom)
	t.ok(world_before.distance_to(world_after) < 0.01,
		"커서 밑의 월드 점이 줌 노치를 건너도 그대로다 (%.4f px 차)"
		% world_before.distance_to(world_after))

	# ⚠ Ignoring `at` in `zoom_at` is the plan's own named mutation for this row.
	var ignored := _fv()
	ignored.zoom = 0.7
	ignored.cam_px = Vector2(150.0, 90.0)
	ignored.position = ignored._compose_position()
	var wb := ignored.screen_to_world_px(at)
	# Simulate the mutation directly: zoom changes, cam_px is left untouched (as `zoom_at` would do
	# if it dropped the whole re-centring line).
	ignored.zoom = 0.7 * 1.15
	ignored.position = ignored._compose_position()
	var wa := ignored.screen_to_world_px(at)
	t.ok(wb.distance_to(wa) > 1.0,
		"자가 점검 — cam_px 를 안 옮기면 커서 밑의 점이 실제로 움직인다는 뜻이다")


func _zoom_min_shows_the_whole_map(t) -> void:
	var fv := _fv()
	fv.zoom = Look.ZOOM_MIN
	fv.cam_px = Vector2(9999.0, 9999.0)   # forced far outside, so the clamp has to do the work
	fv._clamp_cam()
	var visible := fv._visible_world_rect()
	var map := Rect2(Vector2.ZERO, Vector2(Look.GRID_W, Look.GRID_H) * Look.TILE_PX)
	t.ok(visible.position.x <= map.position.x + 0.01 and visible.position.y <= map.position.y + 0.01
			and visible.end.x >= map.end.x - 0.01 and visible.end.y >= map.end.y - 0.01,
		"ZOOM_MIN 에서 섬 전체가 보이는 세계 사각형 안에 든다")

	# ⚠ ZOOM_MIN too small (e.g. 0.7) is the plan's own named mutation — the map no longer fits.
	var too_tight := _fv()
	too_tight.zoom = 0.7
	too_tight.cam_px = Vector2(9999.0, 9999.0)
	too_tight._clamp_cam()
	var tight_visible := too_tight._visible_world_rect()
	t.ok(tight_visible.size.x < map.size.x or tight_visible.size.y < map.size.y,
		"자가 점검 — 줌 0.7에서는 섬 전체가 한 번에 안 보인다는 뜻이다")


## The painted area (map + `WATER_MARGIN_TILES` on every side) covers the visible world rect at
## every zoom in range — not only at the extremes.
func _painted_area_covers_the_viewport(t) -> void:
	var margin_px := Look.WATER_MARGIN_TILES * Look.TILE_PX
	var painted := Rect2(Vector2(-margin_px, -margin_px),
		Vector2(Look.GRID_W, Look.GRID_H) * Look.TILE_PX + Vector2(margin_px, margin_px) * 2.0)
	var zooms := [Look.ZOOM_MIN, 0.7, 0.85, Look.ZOOM_MAX]
	var bad := 0
	for z: float in zooms:
		var fv := _fv()
		fv.zoom = z
		fv.cam_px = Vector2(9999.0, 9999.0)
		fv._clamp_cam()
		var visible := fv._visible_world_rect()
		if visible.position.x < painted.position.x - 0.01 or visible.position.y < painted.position.y - 0.01 \
				or visible.end.x > painted.end.x + 0.01 or visible.end.y > painted.end.y + 0.01:
			bad += 1
	t.eq(bad, 0, "모든 줌에서 물 여백까지 칠한 영역이 보이는 세계를 덮는다 — 줌 아웃해도 맨바닥이 안 드러난다")

	# ⚠ WATER_MARGIN_TILES too small is the plan's own named mutation.
	var thin_margin_px := 1.0 * Look.TILE_PX
	var thin_painted := Rect2(Vector2(-thin_margin_px, -thin_margin_px),
		Vector2(Look.GRID_W, Look.GRID_H) * Look.TILE_PX + Vector2(thin_margin_px, thin_margin_px) * 2.0)
	var fv_min := _fv()
	fv_min.zoom = Look.ZOOM_MIN
	fv_min.cam_px = Vector2(9999.0, 9999.0)
	fv_min._clamp_cam()
	var visible_min := fv_min._visible_world_rect()
	t.ok(visible_min.position.x < thin_painted.position.x - 0.01
			or visible_min.end.x > thin_painted.end.x + 0.01,
		"자가 점검 — 여백을 1칸으로 좁히면 ZOOM_MIN 에서 맨바닥이 드러난다는 뜻이다")


## Pan hard in all four directions: the visible rect never leaves map+margin (the ceiling), AND the
## camera really moved at some point along the way (the floor — a clamp that never lets go passes
## the ceiling by doing nothing).
func _the_clamp_holds_and_the_camera_really_moves(t) -> void:
	var fv := _fv()
	fv.zoom = 1.0
	fv.cam_px = Vector2(500.0, 400.0)
	fv._clamp_cam()
	var start: Vector2 = fv.cam_px

	var margin_px := Look.WATER_MARGIN_TILES * Look.TILE_PX
	var painted := Rect2(Vector2(-margin_px, -margin_px),
		Vector2(Look.GRID_W, Look.GRID_H) * Look.TILE_PX + Vector2(margin_px, margin_px) * 2.0)

	var moved := false
	var bad := 0
	var pushes := [Vector2(50000.0, 0.0), Vector2(-50000.0, 0.0), Vector2(0.0, 50000.0), Vector2(0.0, -50000.0)]
	for push: Vector2 in pushes:
		fv.pan_by(push)
		if fv.cam_px != start:
			moved = true
		var visible := fv._visible_world_rect()
		if visible.position.x < painted.position.x - 0.01 or visible.position.y < painted.position.y - 0.01 \
				or visible.end.x > painted.end.x + 0.01 or visible.end.y > painted.end.y + 0.01:
			bad += 1
	t.ok(moved, "실제로 카메라가 움직인 적이 있다 (바닥 — 안 움직이는 클램프는 이 검사를 속인다)")
	t.eq(bad, 0, "아무리 밀어도 지도 + 여백 밖으로 못 나간다")

	# ⚠ Deleting the clamp is the plan's own named mutation. `pan_by` always calls `_clamp_cam`
	# itself, so simulating its absence means writing `cam_px` directly rather than going through it.
	var unclamped := _fv()
	unclamped.zoom = 1.0
	unclamped.cam_px = Vector2(500.0, 400.0) - Vector2(50000.0, 50000.0)
	var wild := unclamped._visible_world_rect()
	t.ok(wild.position.x < painted.position.x, "자가 점검 — 클램프를 안 걸면 세계 밖으로 실제로 나간다")


## Both ends of `ZOOM_MIN`, `ZOOM_MAX` and `ZOOM_STEP` — six labels, each a direction that must not
## be crossed, per `boat-and-landing` 7.1's own table.
func _both_ends_of_the_three_constants(t) -> void:
	t.ok(Look.ZOOM_MIN <= 0.5625 + 1e-6, "ZOOM_MIN 은 0.5625 이하다 — 넘으면 섬 전체가 안 보인다")
	t.ok(Look.ZOOM_MIN >= 0.4 - 1e-6, "ZOOM_MIN 은 0.4 이상이다 — 못 미치면 14px 몸이 6px 밑으로 준다")
	t.ok(Look.ZOOM_MAX >= 1.0 - 1e-6, "ZOOM_MAX 는 1.0 이상이다 — 오늘의 스케일을 잃으면 안 된다")
	t.ok(Look.ZOOM_MAX <= 1.5 + 1e-6, "ZOOM_MAX 는 1.5 이하다")
	t.ok(Look.ZOOM_STEP > 1.05, "ZOOM_STEP 은 1.05 보다 커야 한 노치가 뭔가 바뀐다")
	t.ok(Look.ZOOM_STEP < 1.4, "ZOOM_STEP 은 1.4 보다 작아야 두 노치가 범위를 못 건너뛴다")
