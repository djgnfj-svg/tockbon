extends RefCounted
## `field_view`'s 3D camera: pure functions, driven with `.new()` and field writes — no tree, no
## frames. The old file measured the flat board's `_compose_position` / `_visible_world_rect`, which
## are gone; every row here is re-derived against the laid-back camera (`ticket 09`, step 1).
##
## **The three questions the old net asked survive**: the whole island is visible when an island
## opens · the ground point under the cursor does not slide when the wheel turns · the camera cannot
## be pushed off the world. **Two are new with the turn**: at every yaw in the sweep the cursor stays
## pinned and the clamp holds, and `turn_by` / `tilt_by` hold the ground point at the middle of the
## screen — which is the number behind 「싸우는 도중에 돌려도 판이 안 흔들리나」.
##
## ⚠ **「어느 각도로 돌려도 섬 전체가 보이나」 is deliberately NOT a row.** Measured before writing:
## at the survey zoom the visible ground is 2208 x 1621 px against a 1920 x 1280 map, and at yaw 45
## the map corner's projection onto the screen axes is 1131 px against a half-span of 811 — the
## corners leave the screen, in the real game too, and the user approved that screen. Whole-island
## is a yaw-0 fact about `setup()`, and it is measured there; the rotated sweep carries the
## acceptance's own three (커서 고정 · 클램프 · 중심 붙잡기).
##
## ⚠ **The clamp bounds the ground point at the MIDDLE of the screen**, not the corners of a
## screen-shaped rectangle — the addendum on ticket 09 says the new net must measure this rule and
## not the old one. The rows below read the centre back through `_ground_centre_px()` and pin the
## stop positions as hand literals.


## Every `FieldView` this net constructs, so `run` can free them all at the end. `FieldView` is a
## `Node2D` (a real `CanvasItem` RID) — left unfreed, the engine reports leaked RIDs at exit, which
## the wrapper's stderr-is-failure rule catches.
var _created: Array = []


func run(t) -> void:
	_setup_opens_at_the_survey_zoom(t)
	_setup_on_the_long_map(t)
	_visible_ground_divides_by_the_pitch(t)
	_screen_to_world_at_the_corners(t)
	_world_to_tile_floors_at_the_boundary(t)
	_pan_by_moves_at_the_right_rate(t)
	_pan_follows_the_turned_axes(t)
	_zoom_holds_the_cursor_at_every_yaw(t)
	_zoom_stops_at_both_ends(t)
	_the_clamp_holds_at_every_yaw(t)
	_the_clamp_stops_at_hand_literals(t)
	_turn_and_tilt_hold_the_centre(t)
	_the_real_camera_obeys_the_pure_functions(t)
	_the_shake_rides_the_screen_axes(t)
	_both_ends_of_the_three_constants(t)
	for raw in _created:
		var fv: FieldView = raw
		fv.free()
	_created = []


func _fv() -> FieldView:
	var fv := FieldView.new()
	_created.append(fv)
	return fv


## An island opens at the SURVEY zoom — `Look.survey_zoom_of`, a question about the grid in front of
## it — and never at the `ZOOM_MIN` constant. On 48 x 32 the survey is 1280 / (48 * 40 * 1.15) =
## **0.57971**, hand arithmetic and not a read-back of the function.
func _setup_opens_at_the_survey_zoom(t) -> void:
	var fv := _fv()
	fv.zoom = Look.ZOOM_MAX          # a stale value from a previous island, on purpose
	fv.cam_px = Vector2(500.0, 400.0)
	fv.cam_yaw_deg = 45.0            # a stale turn too — setup must reset the view, not inherit it
	fv.setup(Battle.new(), Army.new(), [])
	t.ok(absf(fv.zoom - 0.57971) < 0.001,
		"setup 이 줌을 서베이 값 0.57971 로 놓는다 (1280 / 2208, 손 산수) — 얻은 값 %.5f" % fv.zoom)
	t.ok(fv.zoom > Look.ZOOM_MIN + 0.05,
		"자가 점검 — 그 값은 ZOOM_MIN 상수(%.2f)가 아니다: setup 을 상수로 되돌리면 위가 문다" % Look.ZOOM_MIN)
	t.eq(fv.cam_yaw_deg, Look.CAM_YAW_DEG, "setup 이 회전을 여는 각도로 되돌린다")
	t.eq(fv.cam_pitch_deg, Look.CAM_PITCH_DEG, "기울기도 여는 값이다")
	# ⚠ Literals, hand-derived: visible ground = (2208, 1242 / cos 40° = 1621.32) px; the 48 x 32 map
	# (1920 x 1280) is narrower than the view on BOTH axes, so the clamp centres both:
	# cam = (960 - 1104, 640 - 810.66) = (-144.00, -170.66).
	t.ok(fv.cam_px.distance_to(Vector2(-144.0, -170.66)) < 0.1,
		"setup 뒤 cam_px 가 정확히 (-144.00, -170.66) 이다 (%.2f, %.2f)" % [fv.cam_px.x, fv.cam_px.y])
	# The whole island is on screen — the survey's own promise, measured at the yaw it opens at.
	var visible := Rect2(fv.cam_px, fv._visible_ground_px())
	t.ok(visible.encloses(Rect2(0.0, 0.0, 1920.0, 1280.0)),
		"여는 프레임에 섬 전체가 보이는 땅 사각형 안에 든다")
	fv.battle = null

	# The inversion: at zoom 0.8 the visible ground is 1600 px wide against a 1920 px map, so the
	# same rectangle CANNOT enclose the island — the row above is measuring the zoom, not itself.
	var tight := _fv()
	tight.zoom = 0.8
	tight.cam_px = Vector2(9999.0, 9999.0)
	tight._clamp_cam()
	t.ok(not Rect2(tight.cam_px, tight._visible_ground_px()).encloses(Rect2(0.0, 0.0, 1920.0, 1280.0)),
		"자가 점검 — 줌 0.8 에서는 섬 전체가 한 번에 안 보인다는 뜻이다")


## ⚠⚠ **THE CAPABILITY ROW: the camera asks the GRID how big the map is.** The long map is 144 x 32;
## its survey (1280 / 6624 = 0.193) is under the wheel's own floor, so it opens clamped at
## `ZOOM_MIN` 0.50 — visible ground (2560, 1879.79). x is WIDER than the view: the clamp holds the
## centre in [1280, 4480] and setup's `cam_px = ZERO` survives at **0.00** where the 48-map centres
## to -144. y is centred at 640 - 939.89 = **-299.89**. Hand literals, both.
func _setup_on_the_long_map(t) -> void:
	var army := Army.new()
	var long_rows := Islands.rows_of(Islands.LONG_ISLAND_INDEX)
	var g := Grid.new()
	g.load_rows(long_rows)
	t.eq(g.w, 144, "긴 지도가 144칸 폭으로 실렸다 (자가 점검)")
	t.eq(g.h, 32, "높이는 그대로 32칸이다 (자가 점검)")
	var b := Battle.new()
	b.setup(g, army, [], 999.0)

	var fv := _fv()
	fv.setup(b, army, long_rows)
	t.eq(fv._map_tiles(), Vector2i(144, 32), "field_view 가 격자에게 크기를 묻는다")
	t.eq(fv.zoom, Look.ZOOM_MIN, "긴 지도의 서베이는 휠 바닥(0.50)에 걸려 멈춘다 — 다 보일 수 없는 지도다")
	t.ok(fv.cam_px.distance_to(Vector2(0.0, -299.89)) < 0.1,
		"긴 지도에서 setup 뒤 cam_px 가 (0.00, -299.89) 이다 — x 는 가운데 맞춤이 아니라 물려서 잡힌다 (%.2f, %.2f)"
			% [fv.cam_px.x, fv.cam_px.y])

	# The self-check that makes the number a claim: the 48-column fixture above landed x at -144, and
	# `Look.GRID_W` is still 48 — so this is not two names for one answer.
	t.eq(Look.GRID_W, 48, "Look.GRID_W 는 여전히 48이다 (격자 없는 뷰의 기본값으로만 남았다)")
	t.ok(absf(fv.cam_px.x - (-144.0)) > 100.0,
		"긴 지도의 x 는 48칸짜리의 -144 와 전혀 다르다 — 상수를 읽었다면 둘이 같았다")

	# And the pan really reaches the far end: centre max = 5760 - 1280 = 4480, so cam_px stops at
	# 4480 - 1280 = **3200.0** — the middle-ground-point rule's own stop, as a hand literal.
	fv.pan_by(Vector2(-50000.0, 0.0))
	t.ok(absf(fv.cam_px.x - 3200.0) < 0.1,
		"동쪽 끝까지 밀면 cam_px.x 가 3200.00 에서 멈춘다 (얻은 값 %.2f)" % fv.cam_px.x)
	fv.battle = null


## The one thing tilting cost: a screen px DOWN covers `1 / cos(pitch)` ground px. At zoom 1.0 and
## the opening pitch 40° the visible ground is (1280, 720 / 0.766044 = **939.89**) — hand literals.
func _visible_ground_divides_by_the_pitch(t) -> void:
	var fv := _fv()
	fv.zoom = 1.0
	var v := fv._visible_ground_px()
	t.ok(absf(v.x - 1280.0) < 0.01, "가로는 나눗셈이 없다 — 1280 그대로다 (%.2f)" % v.x)
	t.ok(absf(v.y - 939.89) < 0.01, "세로는 cos(40°) 로 나뉜다 — 939.89 다 (%.2f)" % v.y)
	# ⚠ The named mutation: delete the `/cos(pitch)` and the answer is 720 — 219.89 px apart, which
	# the literal above cannot miss.
	t.ok(absf(939.89 - 720.0) > 1.0, "자가 점검 — 나눗셈을 지우면 실제로 다른 값(720)이 나온다는 뜻이다")
	# And it reads the RUNTIME pitch, not the constant: tilted to 60° the same call answers
	# 720 / cos(60°) = 1440.
	fv.cam_pitch_deg = 60.0
	t.ok(absf(fv._visible_ground_px().y - 1440.0) < 0.01,
		"기울기를 60°로 바꾸면 세로가 1440 이 된다 — 상수가 아니라 지금 기울기를 읽는다")


## The conversion's own corners, as hand literals. At yaw 0 screen (0,0) is exactly `cam_px` —
## centre minus half the span IS the corner — and (1280,720) is `cam_px + visible`. At yaw 90 the
## screen axes lie along world (+y, -x), so the top-left corner lands at
## centre + (vis.y/2, -vis.x/2) = **(1209.95, -120.05)** for this fixture.
func _screen_to_world_at_the_corners(t) -> void:
	var fv := _fv()
	fv.zoom = 1.0
	fv.cam_px = Vector2(100.0, 50.0)
	t.ok(fv.screen_to_world_px(Vector2(0.0, 0.0)).distance_to(Vector2(100.0, 50.0)) < 0.01,
		"화면 (0,0) 은 정확히 cam_px 다 — 코너 계약이 그대로다")
	t.ok(fv.screen_to_world_px(Vector2(1280.0, 720.0)).distance_to(Vector2(1380.0, 989.89)) < 0.01,
		"화면 (1280,720) 은 cam_px + 보이는 땅이다 (1380.00, 989.89)")
	t.ok(fv.screen_to_world_px(Vector2(640.0, 360.0)).distance_to(Vector2(740.0, 519.95)) < 0.01,
		"화면 한가운데는 땅의 한가운데다 (740.00, 519.95)")
	fv.cam_yaw_deg = 90.0
	t.ok(fv.screen_to_world_px(Vector2(0.0, 0.0)).distance_to(Vector2(1209.95, -120.05)) < 0.1,
		"yaw 90 에서 화면 (0,0) 은 (1209.95, -120.05) 다 — 축이 실제로 돌았다 (손 산수)")
	t.ok(fv.screen_to_world_px(Vector2(640.0, 360.0)).distance_to(Vector2(740.0, 519.95)) < 0.01,
		"그래도 화면 한가운데는 같은 땅점이다 — 돌리는 것은 축이지 중심이 아니다")


func _world_to_tile_floors_at_the_boundary(t) -> void:
	var fv := _fv()
	t.eq(fv.world_to_tile(Vector2(0.0, 0.0)), Vector2i(0, 0), "원점은 (0,0) 타일이다")
	t.eq(fv.world_to_tile(Vector2(39.9, 0.0)), Vector2i(0, 0),
		"타일 경계 바로 앞(39.9px)은 아직 0번 타일이다 — round 였다면 1번이 나왔을 것이다 (자가 점검)")
	t.eq(fv.world_to_tile(Vector2(40.0, 0.0)), Vector2i(1, 0), "정확히 경계(40.0px)부터 1번 타일이다")
	t.eq(fv.world_to_tile(Vector2(79.9, 12.0)), Vector2i(1, 0), "79.9px 도 아직 1번 타일이다")
	t.eq(fv.world_to_tile(Vector2(0.0, 80.0)), Vector2i(0, 2), "세로도 같은 규칙이다 — 80.0px 는 2번 행이다")


## A small drag, comfortably inside the clamp band, moves the ground by exactly `-delta / zoom` on x
## and `-delta / zoom / cos(pitch)` on y — the ground under the cursor keeps up with the cursor, and
## the vertical is longer because the ground is leaning away. 16/0.8 = 20.0, 8/0.8/0.766044 = 13.05.
func _pan_by_moves_at_the_right_rate(t) -> void:
	var fv := _fv()
	fv.zoom = 0.8
	# In-band: at zoom 0.8 cam_px ranges are x [0, 320] and y [0, 105.13]; both the start and the
	# panned end sit inside, so the rate is read and not the clamp.
	fv.cam_px = Vector2(150.0, 40.0)
	var before: Vector2 = fv.cam_px
	fv.pan_by(Vector2(16.0, 8.0))
	var want := before - Vector2(20.0, 13.054)
	t.ok(fv.cam_px.distance_to(want) < 0.01,
		"작게 끌면 x 는 -delta/zoom, y 는 -delta/zoom/cos(pitch) 만큼 움직인다 (%.3f px 차)"
			% fv.cam_px.distance_to(want))
	# ⚠ Named mutations, both axes: drop the `/zoom` and x moves 16 not 20; drop the `/cos` and y
	# moves 10 not 13.05 — either is over a pixel off the literal above.
	t.ok(absf(20.0 - 16.0) > 1.0 and absf(13.054 - 10.0) > 1.0,
		"자가 점검 — 나눗셈 어느 쪽을 지워도 리터럴과 1px 넘게 갈린다")


## At yaw 90 a horizontal drag moves the camera along WORLD y: screen-right lies on world +y there,
## so the same promise (the ground under the cursor follows the cursor) turns with the board.
func _pan_follows_the_turned_axes(t) -> void:
	var fv := _fv()
	fv.zoom = 0.8
	fv.cam_yaw_deg = 90.0
	fv.cam_px = Vector2(160.0, 52.0)
	fv.pan_by(Vector2(16.0, 0.0))
	t.ok(fv.cam_px.distance_to(Vector2(160.0, 32.0)) < 0.01,
		"yaw 90 에서 가로 끌기는 세계 y 축으로 20px 움직인다 (%.2f, %.2f)" % [fv.cam_px.x, fv.cam_px.y])


## Zooming about `at` keeps the ground point under it fixed — **at every yaw in the sweep**, which is
## the half the addendum added. The fixture parks the centre mid-map at zoom 0.8 so the clamp has
## slack on both axes before and after the notch (checked by hand: centre (960,640) against ranges
## x [800,1120] · y [587.4,692.6], and after the notch x [695.7,1224.3] · y [510.8,769.2]).
func _zoom_holds_the_cursor_at_every_yaw(t) -> void:
	var at := Vector2(500.0, 300.0)
	var bad := 0
	for yaw: float in [0.0, 15.0, 45.0, 90.0, 165.0]:
		var fv := _fv()
		fv.zoom = 0.8
		fv.cam_yaw_deg = yaw
		fv.cam_px = Vector2(960.0, 640.0) - fv._visible_ground_px() * 0.5
		var world_before := fv.screen_to_world_px(at)
		fv.zoom_at(at, 1.15)
		if fv.zoom <= 0.8:
			bad += 1
		if world_before.distance_to(fv.screen_to_world_px(at)) > 0.01:
			bad += 1
	t.eq(bad, 0, "다섯 yaw 전부에서 줌 노치를 건너도 커서 밑의 땅점이 그대로다")

	# ⚠ The named mutation, simulated at a TURNED yaw: change the zoom and leave `cam_px` alone (the
	# whole re-centring line deleted) — the point under the cursor must actually move.
	var broken := _fv()
	broken.zoom = 0.8
	broken.cam_yaw_deg = 45.0
	broken.cam_px = Vector2(960.0, 640.0) - broken._visible_ground_px() * 0.5
	var wb := broken.screen_to_world_px(at)
	broken.zoom = 0.8 * 1.15
	t.ok(wb.distance_to(broken.screen_to_world_px(at)) > 1.0,
		"자가 점검 — cam_px 를 안 옮기면 yaw 45 에서도 커서 밑의 점이 실제로 밀린다는 뜻이다")


func _zoom_stops_at_both_ends(t) -> void:
	var fv := _fv()
	fv.zoom = Look.ZOOM_MAX
	fv.cam_px = Vector2(300.0, 100.0)
	fv.zoom_at(Vector2(640.0, 360.0), 1.15)
	t.eq(fv.zoom, Look.ZOOM_MAX, "ZOOM_MAX 에서 더 확대되지 않는다")
	fv.zoom = Look.ZOOM_MIN
	fv.zoom_at(Vector2(640.0, 360.0), 0.8)
	t.eq(fv.zoom, Look.ZOOM_MIN, "ZOOM_MIN 에서 더 축소되지 않는다")


## Pushed from far outside at a TURNED yaw, the clamp brings the ground point at the middle of the
## screen back INSIDE the map — the addendum's rule, read straight off `_ground_centre_px()`.
## ⚠ ONE turned yaw and not a sweep, deliberately (verify-read D): `_clamp_cam` never reads the yaw,
## so five yaws were five copies of the same measurement wearing five counts.
func _the_clamp_holds_at_every_yaw(t) -> void:
	var map := Rect2(0.0, 0.0, 1920.0, 1280.0)
	var fv := _fv()
	fv.zoom = 0.9
	fv.cam_yaw_deg = 45.0
	fv.cam_px = Vector2(9999.0, 9999.0)
	fv._clamp_cam()
	t.ok(fv.cam_px != Vector2(9999.0, 9999.0),
		"돌린 yaw 에서도 클램프가 실제로 카메라를 옮겼다 (바닥 — 안 움직이는 클램프는 여기서 문다)")
	t.ok(map.has_point(fv._ground_centre_px()),
		"그리고 화면 한가운데 땅점이 지도 안으로 돌아온다 — 모서리가 아니라 중심을 묶는다")

	# ⚠ The named mutation: delete the clamp. `pan_by` always calls it, so its absence is simulated
	# by writing `cam_px` directly — the centre then really is outside the map.
	var wild := _fv()
	wild.zoom = 0.9
	wild.cam_px = Vector2(-50000.0, -50000.0)
	t.ok(not map.has_point(wild._ground_centre_px()),
		"자가 점검 — 클램프를 안 걸면 중심이 실제로 지도 밖이다")


## The stops, as hand literals at zoom 1.0 on 48 x 32: visible (1280, 939.89), so the centre may
## reach x 1920 - 640 = 1280 and y 1280 - 469.95 = 810.05 — cam_px stops at **640.00** east and
## **340.11** south. 340.11 is `1280 - 720/cos(40°)`, the pitch division reaching the clamp.
func _the_clamp_stops_at_hand_literals(t) -> void:
	var fv := _fv()
	fv.zoom = 1.0
	fv.cam_px = Vector2(300.0, 100.0)
	fv.pan_by(Vector2(-50000.0, 0.0))
	t.ok(absf(fv.cam_px.x - 640.0) < 0.1, "동쪽 끝에서 cam_px.x 가 640.00 이다 (%.2f)" % fv.cam_px.x)
	fv.pan_by(Vector2(0.0, -50000.0))
	t.ok(absf(fv.cam_px.y - 340.11) < 0.1, "남쪽 끝에서 cam_px.y 가 340.11 이다 (%.2f)" % fv.cam_px.y)
	# ⚠ Without the pitch division the south stop would be 1280 - 720 = 560 — 220 px off the literal.
	t.ok(absf(340.11 - 560.0) > 1.0, "자가 점검 — cos 나눗셈이 빠지면 남쪽 끝이 560 으로 밀린다는 뜻이다")
	fv.pan_by(Vector2(50000.0, 50000.0))
	t.ok(absf(fv.cam_px.x - 0.0) < 0.1 and absf(fv.cam_px.y - 0.0) < 0.1,
		"반대쪽 끝은 (0, 0) 이다 — 양끝이 다 잰 값이다")


## 「돌려도 판이 안 흔들리나」, in numbers: Q/E and R/F hold the ground point at the middle of the
## screen, and the real camera keeps orbiting the SAME world point. The target is recovered off the
## engine node itself — `position - basis.z * CAM_DIST_TILES` — never re-derived from the formula.
func _turn_and_tilt_hold_the_centre(t) -> void:
	var fv := _fv()
	fv._build_world()
	fv.zoom = 0.9
	fv.cam_px = Vector2(300.0, 100.0)
	fv._place_camera()
	var centre0 := fv._ground_centre_px()
	var zoom0 := fv.zoom
	var target0: Vector3 = fv._cam.position - fv._cam.transform.basis.z * Look.CAM_DIST_TILES
	t.ok(target0.distance_to(Vector3(centre0.x / 40.0, 0.0, centre0.y / 40.0)) < 0.01,
		"카메라가 실제로 화면 한가운데 땅점을 보고 있다 (자가 점검)")

	var drift := 0
	for step: float in [15.0, 30.0, 45.0, 75.0, 135.0]:
		fv.turn_by(step)
		fv._place_camera()
		if fv._ground_centre_px().distance_to(centre0) > 0.01:
			drift += 1
		if fv.zoom != zoom0:
			drift += 1
		var target: Vector3 = fv._cam.position - fv._cam.transform.basis.z * Look.CAM_DIST_TILES
		if target.distance_to(target0) > 0.01:
			drift += 1
	t.eq(drift, 0, "yaw 15·45·90·165·300 을 지나도록 중심·줌·시선 목표가 한 번도 안 움직였다 — 판이 제자리에서 돈다")
	t.ok(absf(fv.cam_yaw_deg - 300.0) < 0.01, "각도 자체는 실제로 쌓였다 (자가 점검, %.1f°)" % fv.cam_yaw_deg)
	fv.turn_by(60.0)
	t.ok(absf(fv.cam_yaw_deg - 0.0) < 0.01, "한 바퀴를 채우면 0 으로 감긴다 (fmod 360)")

	# The tilt holds the same point while the vertical span changes under it — the half of the
	# re-centre that is NOT a no-op (the turn leaves the span alone; the tilt does not).
	fv.tilt_by(5.0)
	t.ok(fv._ground_centre_px().distance_to(centre0) < 0.01, "기울여도(45°) 중심이 그대로다")
	fv.tilt_by(-10.0)
	t.ok(fv._ground_centre_px().distance_to(centre0) < 0.01, "반대로 기울여도(35°) 그대로다")
	# ⚠ The named mutation: write the pitch WITHOUT the re-centre — the centre really moves, by
	# half the span change (about 43 px at 0.9 from 35° to 45°).
	var raw := _fv()
	raw.zoom = 0.9
	raw.cam_px = Vector2(300.0, 100.0)
	var raw_centre := raw._ground_centre_px()
	raw.cam_pitch_deg = raw.cam_pitch_deg + 15.0
	t.ok(raw._ground_centre_px().distance_to(raw_centre) > 1.0,
		"자가 점검 — 재중심을 지우면 기울일 때 중심이 실제로 밀린다는 뜻이다")

	# Both ends of the tilt clamp. ⚠ At 80° the vertical span (4607 px) swallows the map, so the
	# clamp centres y and the held centre legitimately moves — only the ANGLE is pinned there.
	fv.tilt_by(-1000.0)
	t.eq(fv.cam_pitch_deg, Look.CAM_PITCH_MIN_DEG, "아래로는 20° 에서 멈춘다")
	fv.tilt_by(1000.0)
	t.eq(fv.cam_pitch_deg, Look.CAM_PITCH_MAX_DEG, "위로는 80° 에서 멈춘다")


## ⚠⚠ **The pin that makes the pure rows whole**: measuring a pure function is not measuring that
## anything calls it. `_place_camera` is the one place `cam_px` / `zoom` / the two angles reach the
## engine, so the REAL `Camera3D` is read back against hand literals — position, orientation, size.
## Fixture: zoom 1.0, cam (200,100), yaw 0, pitch 40 ⇒ centre (840, 569.95), target (21, 0, 14.249),
## back (0, sin40, -cos40), position = target + back * 90 = **(21.00, 57.85, -54.70)**, size 32.0.
func _the_real_camera_obeys_the_pure_functions(t) -> void:
	var fv := _fv()
	fv._build_world()
	fv.zoom = 1.0
	fv.cam_px = Vector2(200.0, 100.0)
	fv._place_camera()
	t.ok(absf(fv._cam.size - 32.0) < 0.001, "직교 카메라의 size 가 보이는 폭 32 타일이다 (%.3f)" % fv._cam.size)
	t.ok(fv._cam.position.distance_to(Vector3(21.0, 57.851, -54.695)) < 0.01,
		"카메라 자리가 손 산수 그대로다 (21.00, 57.85, -54.70)")
	t.ok(fv._cam.transform.basis.z.distance_to(Vector3(0.0, 0.642788, -0.766044)) < 0.001,
		"뒤쪽 축이 (0, sin40°, -cos40°) 다 — 시선이 40° 로 내려다본다")
	fv.zoom = 0.8
	fv._place_camera()
	t.ok(absf(fv._cam.size - 40.0) < 0.001, "줌 0.8 이면 size 가 40 타일이다 — size 가 줌을 실어 나른다")

	# ⚠ The named mutation: `_place_camera` reading `Look.CAM_PITCH_DEG` instead of the runtime
	# field. Tilted to 60° the same fixture must land at (21, 77.94, -24.50) — pitch-40 numbers
	# (57.85, -54.70) are over 20 tiles away, so the literal cannot be satisfied by the constant.
	fv.zoom = 1.0
	fv.cam_pitch_deg = 60.0
	fv._place_camera()
	t.ok(fv._cam.position.distance_to(Vector3(21.0, 77.942, -24.5)) < 0.01,
		"기울기 60° 에서 자리가 (21.00, 77.94, -24.50) 이다 — 상수가 아니라 지금 기울기를 읽는다")
	t.ok(fv._cam.transform.basis.z.distance_to(Vector3(0.0, 0.866025, -0.5)) < 0.001,
		"뒤쪽 축도 (0, sin60°, -cos60°) 다")
	t.ok(Vector3(21.0, 77.942, -24.5).distance_to(Vector3(21.0, 57.851, -54.695)) > 1.0,
		"자가 점검 — 40° 의 답과 60° 의 답이 실제로 다르다 (그래서 위 리터럴이 뭔가를 잰다)")


## The shake is an offset on the GROUND, in the screen's own two axes — the screen jerks, the island
## does not slide. Read as the delta between the real camera's shaken and unshaken positions, and
## re-read at yaw 90 where the same screen offset must land on turned world axes.
func _the_shake_rides_the_screen_axes(t) -> void:
	var fv := _fv()
	fv._build_world()
	fv.zoom = 1.0
	fv.cam_px = Vector2(200.0, 100.0)
	fv._place_camera()
	var still: Vector3 = fv._cam.position
	var still_basis: Basis = fv._cam.transform.basis

	fv._shake_amp = Look.SHAKE_MAX_PX
	fv._shake_left = Look.SHAKE_SEC * 0.5
	var shake := fv._shake_offset()
	t.ok(shake.length() > 0.5, "흔들리는 중이다 (자가 점검, %.2f px)" % shake.length())
	fv._place_camera()
	var delta: Vector3 = fv._cam.position - still
	t.ok(delta.distance_to(Vector3(shake.x / 40.0, 0.0, shake.y / 40.0)) < 0.001,
		"yaw 0 에서 카메라가 정확히 (shake.x, shake.y)/타일 만큼 밀린다")
	t.ok(fv._cam.transform.basis.z.distance_to(still_basis.z) < 0.0001,
		"그리고 시선 방향은 안 돈다 — 흔들림은 평행이동이다")
	t.ok(delta.length() > 0.001, "자가 점검 — 흔들림 항을 지우면 델타가 0 이 된다 (%.4f 타일)" % delta.length())

	# At yaw 90 screen-right is world +y and screen-down is world -x, so the SAME screen shake lands
	# as (-shake.y, shake.x) on the ground — the island jerks with the screen, not with the world.
	fv._shake_left = 0.0
	fv.cam_yaw_deg = 90.0
	fv._place_camera()
	var still90: Vector3 = fv._cam.position
	fv._shake_amp = Look.SHAKE_MAX_PX
	fv._shake_left = Look.SHAKE_SEC * 0.5
	fv._place_camera()
	var delta90: Vector3 = fv._cam.position - still90
	t.ok(delta90.distance_to(Vector3(-shake.y / 40.0, 0.0, shake.x / 40.0)) < 0.001,
		"yaw 90 에서 같은 흔들림이 돌아간 축으로 밀린다 — 화면이 흔들리지 섬이 미끄러지지 않는다")


## Both ends of `ZOOM_MIN`, `ZOOM_MAX` and `ZOOM_STEP` — six labels, each a direction that must not
## be crossed. ⚠ `ZOOM_MIN` sits ON its own measured ceiling now (0.50, raised from 0.45): above it
## the 48 x 32 island loses its vertical margin at the wheel's floor.
func _both_ends_of_the_three_constants(t) -> void:
	t.ok(Look.ZOOM_MIN <= 0.50 + 1e-6, "ZOOM_MIN 은 0.50 이하다 — 넘으면 섬 위아래 여백이 사라진다")
	t.ok(Look.ZOOM_MIN >= 0.4 - 1e-6, "ZOOM_MIN 은 0.4 이상이다 — 못 미치면 작은 몸이 읽히지 않는 크기로 준다")
	t.ok(Look.ZOOM_MAX >= 1.0 - 1e-6, "ZOOM_MAX 는 1.0 이상이다 — 오늘의 스케일을 잃으면 안 된다")
	t.ok(Look.ZOOM_MAX <= 1.5 + 1e-6, "ZOOM_MAX 는 1.5 이하다")
	t.ok(Look.ZOOM_STEP > 1.05, "ZOOM_STEP 은 1.05 보다 커야 한 노치가 뭔가 바뀐다")
	t.ok(Look.ZOOM_STEP < 1.4, "ZOOM_STEP 은 1.4 보다 작아야 두 노치가 범위를 못 건너뛴다")
	# The tilt's own pair, because `tilt_by` clamps into them and the clamp rows above read them.
	t.ok(Look.CAM_PITCH_MIN_DEG >= 15.0 and Look.CAM_PITCH_MIN_DEG <= 30.0,
		"기울기 바닥이 15~30° 안이다 — 밑이면 땅이 옆모습이 되고 지도가 아니게 된다")
	t.ok(Look.CAM_PITCH_MAX_DEG >= 70.0 and Look.CAM_PITCH_MAX_DEG <= 85.0,
		"기울기 천장이 70~85° 안이다 — 넘으면 높이가 다시 안 읽힌다 (3D 로 온 이유가 사라진다)")
