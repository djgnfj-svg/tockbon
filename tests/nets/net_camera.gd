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
	await _the_engine_agrees_with_the_forward(t)
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
## it — and never at the `ZOOM_MIN` constant.
##
## ⚠⚠ **RE-DERIVED 2026-08-25 when `SURVEY_MARGIN` went 1.15 -> 1.40** (the user: 「좀더 뒤에서
## 시작」). On 48 x 32 the formula now wants `1280 / (48 * 40 * 1.40)` = 0.47619 and the floor takes it,
## so the opening zoom on this grid is **`ZOOM_MIN` exactly** — hand arithmetic, not a read-back.
##
## ⚠⚠ **AND THAT COST THIS ROW ITS SECOND HALF, WHICH IS WHY THE SECOND HALF MOVED INSTEAD OF DYING.**
## It used to prove the opening zoom is not the constant by checking it stood 0.05 above the floor —
## a claim that is simply false once this grid clamps, and one that would have been "fixed" by deleting
## it. **A survey that is only ever the floor cannot be told from a constant**, so the claim is made on
## a grid that does NOT clamp: 26 x 20, the size the first map node opens, where the survey answers
## `1280 / (26 * 40 * 1.40)` = **0.87912**, strictly inside both bounds. Revert `setup` to the constant
## and that row reddens.
func _setup_opens_at_the_survey_zoom(t) -> void:
	var fv := _fv()
	fv.zoom = Look.ZOOM_MAX          # a stale value from a previous island, on purpose
	fv.cam_px = Vector2(500.0, 400.0)
	fv.cam_yaw_deg = 45.0            # a stale turn too — setup must reset the view, not inherit it
	fv.setup(Battle.new(), Army.new(), [])
	t.ok(absf(fv.zoom - Look.ZOOM_MIN) < 0.001,
		"setup 이 줌을 서베이 값으로 놓는다 — 48x32 에서는 바닥에 걸려 %.5f 다 (얻은 값 %.5f)"
			% [Look.ZOOM_MIN, fv.zoom])

	# The half that cannot be made on a clamping grid: a real 26 x 20 island, where the survey is a
	# number of its own.
	var small := _fv()
	var g := Grid.new()
	var rows := []
	for y in 20:
		rows.append("~".repeat(26))
	g.load_rows(rows)
	var b := Battle.new()
	b.setup(g, Army.new(), [], 999.0)
	small.zoom = Look.ZOOM_MAX
	small.setup(b, Army.new(), rows)
	t.ok(absf(small.zoom - 0.87912) < 0.001,
		"26x20 섬은 0.87912 로 열린다 (1280 / 1456, 손 산수) — 얻은 값 %.5f" % small.zoom)
	t.ok(small.zoom > Look.ZOOM_MIN + 0.05 and small.zoom < Look.ZOOM_MAX - 0.05,
		"자가 점검 — 그 값은 ZOOM_MIN 도 ZOOM_MAX 도 아니다: setup 을 어느 상수로 되돌려도 위가 문다")
	small.battle = null
	t.eq(fv.cam_yaw_deg, Look.CAM_YAW_DEG, "setup 이 회전을 여는 각도로 되돌린다")
	t.eq(fv.cam_pitch_deg, Look.CAM_PITCH_DEG, "기울기도 여는 값이다")
	# ⚠ Literals, hand-derived at the opening zoom: visible ground = (1280 / 0.50, 720 / 0.50 / sin 40°)
	# = (2560.00, 2240.24) px; the 48 x 32 map (1920 x 1280) is narrower than the view on BOTH axes, so
	# the clamp centres both: cam = (960 - 1280, 640 - 1120.12) = (-320.00, -480.12).
	# ⚠⚠ **It read (-144.00, -170.66) until 2026-08-25 and that literal WAS the defect, written down.**
	# The vertical divided by `cos(pitch)` where the ground's foreshortening is its SINE, so this row
	# stayed green on a camera that answered a press with a tile up to two rows above the cursor.
	# ⚠ **Re-derived again the same day** when `SURVEY_MARGIN` went 1.15 -> 1.40 and this grid's opening
	# zoom fell onto the floor: every number on the line is a function of that zoom.
	t.ok(fv.cam_px.distance_to(Vector2(-320.0, -480.12)) < 0.1,
		"setup 뒤 cam_px 가 정확히 (-320.00, -480.12) 이다 (%.2f, %.2f)" % [fv.cam_px.x, fv.cam_px.y])
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
## `ZOOM_MIN` 0.50 — visible ground (2560, 2240.24). x is WIDER than the view: the clamp holds the
## centre in [1280, 4480] and setup's `cam_px = ZERO` survives at **0.00** where the 48-map centres
## to -144. y is centred at 640 - 1120.12 = **-480.12**. Hand literals, both.
func _setup_on_the_long_map(t) -> void:
	var army := Army.new()
	var long_rows := Islands.rows()
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
	t.ok(fv.cam_px.distance_to(Vector2(0.0, -480.12)) < 0.1,
		"긴 지도에서 setup 뒤 cam_px 가 (0.00, -480.12) 이다 — x 는 가운데 맞춤이 아니라 물려서 잡힌다 (%.2f, %.2f)"
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


## The one thing tilting cost: a screen px DOWN covers `1 / sin(pitch)` ground px. At zoom 1.0 and
## the opening pitch 40° the visible ground is (1280, 720 / 0.642788 = **1120.12**) — hand literals.
##
## ⚠⚠ **THE DIVISOR IS THE SINE AND THIS ROW SAID `cos` UNTIL 2026-08-25.** `cam_pitch_deg` is measured
## OFF THE HORIZON: at 90° the camera stands overhead and a tile of ground is unsquashed, at 0° it is
## edge on and covers nothing at all. Sine says both of those; cosine says both of them backwards.
## **The two ends at the bottom are what make this a claim rather than a number** — they are 20° and
## 80°, where the two functions are furthest apart and in the opposite ORDER, so no cosine can pass
## them however the middle is written.
func _visible_ground_divides_by_the_pitch(t) -> void:
	var fv := _fv()
	fv.zoom = 1.0
	var v := fv._visible_ground_px()
	t.ok(absf(v.x - 1280.0) < 0.01, "가로는 나눗셈이 없다 — 1280 그대로다 (%.2f)" % v.x)
	t.ok(absf(v.y - 1120.12) < 0.01, "세로는 sin(40°) 로 나뉜다 — 1120.12 다 (%.2f)" % v.y)
	# ⚠ The named mutation: delete the `/sin(pitch)` and the answer is 720 — 400.12 px apart, which
	# the literal above cannot miss.
	t.ok(absf(1120.12 - 720.0) > 1.0, "자가 점검 — 나눗셈을 지우면 실제로 다른 값(720)이 나온다는 뜻이다")
	# ⚠⚠ And it cannot be the COSINE, which is the shape that actually shipped: cos 40° answers 939.89.
	t.ok(absf(1120.12 - 939.89) > 1.0, "자가 점검 — cos 로 나누면 939.89 가 나온다 (실제로 그랬다)")
	# And it reads the RUNTIME pitch, not the constant: tilted to 60° the same call answers
	# 720 / sin(60°) = 831.38.
	fv.cam_pitch_deg = 60.0
	t.ok(absf(fv._visible_ground_px().y - 831.38) < 0.01,
		"기울기를 60°로 바꾸면 세로가 831.38 이 된다 — 상수가 아니라 지금 기울기를 읽는다")
	# ⚠⚠ **Both ends of the tilt, and they are the whole of why it is the sine.** A camera lying nearly
	# flat sees a LOT of ground down the screen (2105.14 px at 20°); one standing nearly overhead sees
	# little (731.11 px at 80°). Cosine orders those two the other way round.
	fv.cam_pitch_deg = Look.CAM_PITCH_MIN_DEG
	var flat_span := fv._visible_ground_px().y
	t.ok(absf(flat_span - 2105.14) < 0.01,
		"거의 눕힌 20° 에서는 세로로 2105.14px 의 땅이 보인다 — 눕힐수록 멀리 본다 (%.2f)" % flat_span)
	fv.cam_pitch_deg = Look.CAM_PITCH_MAX_DEG
	var steep_span := fv._visible_ground_px().y
	t.ok(absf(steep_span - 731.11) < 0.01,
		"거의 내려다보는 80° 에서는 731.11px 뿐이다 — 위에서 보면 안 눕는다 (%.2f)" % steep_span)
	t.ok(flat_span > steep_span, "눕힐수록 커진다 — cos 였다면 이 부등호가 뒤집힌다")


## The conversion's own corners, as hand literals. At yaw 0 screen (0,0) is exactly `cam_px` —
## centre minus half the span IS the corner — and (1280,720) is `cam_px + visible`. At yaw 90 the
## screen axes lie along world (+y, -x), so the top-left corner lands at
## centre + (vis.y/2, -vis.x/2) = **(1300.06, -29.94)** for this fixture.
##
## ⚠ **Every literal below moved on 2026-08-25** with the pitch divisor. `cam_px` itself did not: the
## corner contract is the one promise that never depended on it, which is why it is the first row.
func _screen_to_world_at_the_corners(t) -> void:
	var fv := _fv()
	fv.zoom = 1.0
	fv.cam_px = Vector2(100.0, 50.0)
	t.ok(fv.screen_to_world_px(Vector2(0.0, 0.0)).distance_to(Vector2(100.0, 50.0)) < 0.01,
		"화면 (0,0) 은 정확히 cam_px 다 — 코너 계약이 그대로다")
	t.ok(fv.screen_to_world_px(Vector2(1280.0, 720.0)).distance_to(Vector2(1380.0, 1170.12)) < 0.01,
		"화면 (1280,720) 은 cam_px + 보이는 땅이다 (1380.00, 1170.12)")
	t.ok(fv.screen_to_world_px(Vector2(640.0, 360.0)).distance_to(Vector2(740.0, 610.06)) < 0.01,
		"화면 한가운데는 땅의 한가운데다 (740.00, 610.06)")
	fv.cam_yaw_deg = 90.0
	t.ok(fv.screen_to_world_px(Vector2(0.0, 0.0)).distance_to(Vector2(1300.06, -29.94)) < 0.1,
		"yaw 90 에서 화면 (0,0) 은 (1300.06, -29.94) 다 — 축이 실제로 돌았다 (손 산수)")
	t.ok(fv.screen_to_world_px(Vector2(640.0, 360.0)).distance_to(Vector2(740.0, 610.06)) < 0.01,
		"그래도 화면 한가운데는 같은 땅점이다 — 돌리는 것은 축이지 중심이 아니다")

	# ⚠⚠ **The HEIGHT argument, which is the half a plane cannot answer.** A thing standing one tile up
	# draws `1 / tan(40°) = 1.1918` tiles UP the screen from where the plane at zero puts it, so the
	# same screen point on a one-tile hill is 47.67 world px FURTHER down the board.
	fv.cam_yaw_deg = 0.0
	var flat := fv.screen_to_world_px(Vector2(640.0, 360.0))
	var hill := fv.screen_to_world_px(Vector2(640.0, 360.0), 1.0)
	t.ok(hill.distance_to(Vector2(740.0, 657.73)) < 0.01,
		"1 타일 높이의 면 위에서 같은 화면점은 47.67px 아래 땅을 가리킨다 (%.2f, %.2f)" % [hill.x, hill.y])
	t.ok(flat.distance_to(hill) > 1.0, "자가 점검 — 높이 인자를 무시하면 둘이 같은 점이 된다")
	# And that shift rides the TURNED axis and not world y: at yaw 90 screen-down lies on world -x.
	fv.cam_yaw_deg = 90.0
	t.ok(fv.screen_to_world_px(Vector2(640.0, 360.0), 1.0).distance_to(Vector2(692.33, 610.06)) < 0.01,
		"yaw 90 에서는 그 밀림이 세계 x 축으로 간다 — 높이도 화면 축을 탄다")


func _world_to_tile_floors_at_the_boundary(t) -> void:
	var fv := _fv()
	t.eq(fv.world_to_tile(Vector2(0.0, 0.0)), Vector2i(0, 0), "원점은 (0,0) 타일이다")
	t.eq(fv.world_to_tile(Vector2(39.9, 0.0)), Vector2i(0, 0),
		"타일 경계 바로 앞(39.9px)은 아직 0번 타일이다 — round 였다면 1번이 나왔을 것이다 (자가 점검)")
	t.eq(fv.world_to_tile(Vector2(40.0, 0.0)), Vector2i(1, 0), "정확히 경계(40.0px)부터 1번 타일이다")
	t.eq(fv.world_to_tile(Vector2(79.9, 12.0)), Vector2i(1, 0), "79.9px 도 아직 1번 타일이다")
	t.eq(fv.world_to_tile(Vector2(0.0, 80.0)), Vector2i(0, 2), "세로도 같은 규칙이다 — 80.0px 는 2번 행이다")


## A small drag, comfortably inside the clamp band, moves the ground by exactly `-delta / zoom` on x
## and `-delta / zoom / sin(pitch)` on y — the ground under the cursor keeps up with the cursor, and
## the vertical is longer because the ground is leaning away. 16/0.9 = 17.778,
## 8/0.9/0.642788 = 13.829.
##
## ⚠ **The fixture moved from zoom 0.8 to 0.9 with the divisor, and it had to.** At 0.8 the corrected
## visible ground is 1400 px tall against a 1280 px map, so `_clamp_cam` CENTRES the vertical and
## there is no rate left to read — the row would have measured the clamp. At 0.9 the span is 1244.58
## and the band is y [0, 35.42].
func _pan_by_moves_at_the_right_rate(t) -> void:
	var fv := _fv()
	fv.zoom = 0.9
	# In-band: at zoom 0.9 cam_px ranges are x [0, 497.78] and y [0, 35.42]; both the start and the
	# panned end sit inside, so the rate is read and not the clamp.
	fv.cam_px = Vector2(150.0, 20.0)
	var before: Vector2 = fv.cam_px
	fv.pan_by(Vector2(16.0, 8.0))
	var want := before - Vector2(17.778, 13.829)
	t.ok(fv.cam_px.distance_to(want) < 0.01,
		"작게 끌면 x 는 -delta/zoom, y 는 -delta/zoom/sin(pitch) 만큼 움직인다 (%.3f px 차)"
			% fv.cam_px.distance_to(want))
	# ⚠ Named mutations, both axes: drop the `/zoom` and x moves 16 not 17.78; drop the `/sin` and y
	# moves 8.89 not 13.83 — either is over a pixel off the literal above.
	t.ok(absf(17.778 - 16.0) > 1.0 and absf(13.829 - 8.889) > 1.0,
		"자가 점검 — 나눗셈 어느 쪽을 지워도 리터럴과 1px 넘게 갈린다")
	# ⚠⚠ And `cos` in the sine's place moves it 11.60 — the defect this row was green through.
	t.ok(absf(13.829 - 11.604) > 1.0, "자가 점검 — cos 로 나누면 11.60 이 된다 (실제로 그랬다)")


## At yaw 90 a horizontal drag moves the camera along WORLD y: screen-right lies on world +y there,
## so the same promise (the ground under the cursor follows the cursor) turns with the board.
func _pan_follows_the_turned_axes(t) -> void:
	var fv := _fv()
	# Zoom 0.9 for the reason the row above carries: at 0.8 the clamp centres the vertical and the
	# answer belongs to the clamp rather than to the pan.
	fv.zoom = 0.9
	fv.cam_yaw_deg = 90.0
	fv.cam_px = Vector2(160.0, 30.0)
	fv.pan_by(Vector2(16.0, 0.0))
	t.ok(fv.cam_px.distance_to(Vector2(160.0, 12.222)) < 0.01,
		"yaw 90 에서 가로 끌기는 세계 y 축으로 17.78px 움직인다 (%.2f, %.2f)" % [fv.cam_px.x, fv.cam_px.y])


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


## The stops, as hand literals at zoom 1.0 on 48 x 32: visible (1280, 1120.12), so the centre may
## reach x 1920 - 640 = 1280 and y 1280 - 560.06 = 719.94 — cam_px stops at **640.00** east and
## **159.88** south. 159.88 is `1280 - 720/sin(40°)`, the pitch division reaching the clamp.
func _the_clamp_stops_at_hand_literals(t) -> void:
	var fv := _fv()
	fv.zoom = 1.0
	fv.cam_px = Vector2(300.0, 100.0)
	fv.pan_by(Vector2(-50000.0, 0.0))
	t.ok(absf(fv.cam_px.x - 640.0) < 0.1, "동쪽 끝에서 cam_px.x 가 640.00 이다 (%.2f)" % fv.cam_px.x)
	fv.pan_by(Vector2(0.0, -50000.0))
	t.ok(absf(fv.cam_px.y - 159.88) < 0.1, "남쪽 끝에서 cam_px.y 가 159.88 이다 (%.2f)" % fv.cam_px.y)
	# ⚠ Without the pitch division the south stop would be 1280 - 720 = 560 — 400 px off the literal;
	# with `cos` in the sine's place, 340.11, which is where this row sat while the defect shipped.
	t.ok(absf(159.88 - 560.0) > 1.0, "자가 점검 — 나눗셈이 빠지면 남쪽 끝이 560 으로 밀린다는 뜻이다")
	t.ok(absf(159.88 - 340.11) > 1.0, "자가 점검 — cos 로 나누면 340.11 이 된다 (실제로 그랬다)")
	fv.pan_by(Vector2(50000.0, 50000.0))
	t.ok(absf(fv.cam_px.x - 0.0) < 0.1 and absf(fv.cam_px.y - 0.0) < 0.1,
		"반대쪽 끝은 (0, 0) 이다 — 양끝이 다 잰 값이다")


## 「돌려도 판이 안 흔들리나」, in numbers: Q/E and R/F hold the ground point at the middle of the
## screen, and the real camera keeps orbiting the SAME world point. The target is recovered off the
## engine node itself — `position - basis.z * CAM_DIST_TILES` — never re-derived from the formula.
## ⚠ **The fixture parks the screen centre at world y 640 — the exact middle of the 1280-tall map —
## and that number is load-bearing.** The vertical span changes with the pitch (1255.28 px at 35°,
## 1120.12 at 40°, 1018.23 at 45°) and `_clamp_cam` bounds the centre into what is left of 1280; the
## middle is the one y that is legal at all three. Parked anywhere else, the clamp moves the centre on
## the first turn and the row reddens on the clamp instead of on the turn — which is exactly what it
## did on 2026-08-25 the moment the span was corrected. cam_px.y = 640 - 560.06 = **79.94**.
func _turn_and_tilt_hold_the_centre(t) -> void:
	var fv := _fv()
	fv._build_world()
	fv.zoom = 1.0
	fv.cam_px = Vector2(300.0, 79.94)
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
	raw.zoom = 1.0
	raw.cam_px = Vector2(300.0, 79.94)
	var raw_centre := raw._ground_centre_px()
	raw.cam_pitch_deg = raw.cam_pitch_deg + 15.0
	t.ok(raw._ground_centre_px().distance_to(raw_centre) > 1.0,
		"자가 점검 — 재중심을 지우면 기울일 때 중심이 실제로 밀린다는 뜻이다")

	# Both ends of the tilt clamp. ⚠ At 20° the vertical span (2105 px) swallows the map, so the clamp
	# centres y and the held centre legitimately moves — only the ANGLE is pinned there.
	fv.tilt_by(-1000.0)
	t.eq(fv.cam_pitch_deg, Look.CAM_PITCH_MIN_DEG, "아래로는 20° 에서 멈춘다")
	fv.tilt_by(1000.0)
	t.eq(fv.cam_pitch_deg, Look.CAM_PITCH_MAX_DEG, "위로는 80° 에서 멈춘다")


## ⚠⚠ **The pin that makes the pure rows whole**: measuring a pure function is not measuring that
## anything calls it. `_place_camera` is the one place `cam_px` / `zoom` / the two angles reach the
## engine, so the REAL `Camera3D` is read back against hand literals — position, orientation, size.
## Fixture: zoom 1.0, cam (200,100), yaw 0, pitch 40 ⇒ centre (840, 660.06), target (21, 0, 16.502),
## back (0, sin40, cos40), position = target + back * 90 = **(21.00, 57.85, 85.45)**, size 32.0.
##
## ⚠⚠⚠ **THE `back.z` SIGN IS THE ONE THIS ROW GOT WRONG, AND IT COST THE WHOLE PICTURE**
## (2026-08-25). It read `(0, sin40°, -cos40°)` — a camera standing on the -z side of what it is
## looking at, therefore looking along +z, therefore with its own +x pointing at world **-x**. The
## island drew half a turn around from the board `_ground_right` / `_ground_down` and every press
## describe, and a press aimed at the tile under the cursor landed a mean of 18.6 tiles away.
## ⇒ **The `basis.x` / `basis.y` rows below are the new pins and the sign row is not.** An axis
## literal restates the formula; **what the picture actually promises is that world +x is to the
## RIGHT of the screen and world +z is DOWN it**, which is what those two rows say and what no sign
## error can satisfy.
func _the_real_camera_obeys_the_pure_functions(t) -> void:
	var fv := _fv()
	fv._build_world()
	fv.zoom = 1.0
	fv.cam_px = Vector2(200.0, 100.0)
	fv._place_camera()
	t.ok(absf(fv._cam.size - 32.0) < 0.001, "직교 카메라의 size 가 보이는 폭 32 타일이다 (%.3f)" % fv._cam.size)
	t.ok(fv._cam.position.distance_to(Vector3(21.0, 57.851, 85.446)) < 0.01,
		"카메라 자리가 손 산수 그대로다 (21.00, 57.85, 85.45) — 얻은 값 (%.2f, %.2f, %.2f)"
			% [fv._cam.position.x, fv._cam.position.y, fv._cam.position.z])
	# ⚠⚠ **The picture's own two promises**, and they are what the shell reads a press against.
	# `basis.x` is the world direction of screen-RIGHT and it must be `_ground_right`; `-basis.y` is
	# screen-DOWN and its ground part must lie on `_ground_down`. A camera parked on the wrong side of
	# its target answers `(-1, 0, 0)` to the first of these, which is the defect that shipped.
	var right: Vector3 = fv._cam.transform.basis.x
	t.ok(right.distance_to(Vector3(1.0, 0.0, 0.0)) < 0.001,
		"화면 오른쪽이 세계 +x 다 — 판이 뒤집혀 있지 않다 (%.3f, %.3f, %.3f)" % [right.x, right.y, right.z])
	var down: Vector3 = -fv._cam.transform.basis.y
	t.ok(down.z > 0.001 and absf(down.x) < 0.001,
		"화면 아래쪽의 땅 성분이 세계 +z 다 — 위 행과 짝을 이뤄 180° 회전을 잡는다 (%.3f, %.3f)" % [down.x, down.z])
	t.ok(down.y < -0.001, "그리고 높이는 화면 위로 간다 — 언덕이 위로 솟는다 (%.3f)" % down.y)
	# The same two, at a TURNED yaw: screen-right follows `_ground_right(90°)`, which is world +z.
	fv.cam_yaw_deg = 90.0
	fv._place_camera()
	t.ok(fv._cam.transform.basis.x.distance_to(Vector3(0.0, 0.0, 1.0)) < 0.001,
		"yaw 90 에서는 화면 오른쪽이 세계 +z 다 — 오른쪽이 실제로 yaw 를 따라 돈다")
	fv.cam_yaw_deg = 0.0
	fv.zoom = 0.8
	fv._place_camera()
	t.ok(absf(fv._cam.size - 40.0) < 0.001, "줌 0.8 이면 size 가 40 타일이다 — size 가 줌을 실어 나른다")

	# ⚠ The named mutation: `_place_camera` reading `Look.CAM_PITCH_DEG` instead of the runtime
	# field. Tilted to 60° the same fixture must land at (21, 77.94, 57.89) — the pitch-40 numbers
	# (57.85, 85.45) are over 20 tiles away, so the literal cannot be satisfied by the constant.
	fv.zoom = 1.0
	fv.cam_pitch_deg = 60.0
	fv._place_camera()
	t.ok(fv._cam.position.distance_to(Vector3(21.0, 77.942, 57.892)) < 0.01,
		"기울기 60° 에서 자리가 (21.00, 77.94, 57.89) 이다 — 상수가 아니라 지금 기울기를 읽는다")
	t.ok(fv._cam.transform.basis.z.distance_to(Vector3(0.0, 0.866025, 0.5)) < 0.001,
		"뒤쪽 축이 (0, sin60°, cos60°) 다 — 시선이 60° 로 내려다본다")
	t.ok(Vector3(21.0, 77.942, 57.892).distance_to(Vector3(21.0, 57.851, 85.446)) > 1.0,
		"자가 점검 — 40° 의 답과 60° 의 답이 실제로 다르다 (그래서 위 리터럴이 뭔가를 잰다)")


## ⚠⚠⚠ **THE ROW THAT MEASURES THE TWO DESCRIPTIONS AGAINST EACH OTHER.**
##
## Every other row in this file measures ONE of them against hand arithmetic. **The pure functions and
## `_place_camera` are two separate descriptions of one projection**, so a whole file of literals can
## be green while the two describe different pictures — and on 2026-08-25 they did: the camera stood
## on the -z side of its target, the island drew half a turn around from the board the pure functions
## describe, and **not one row in this file moved.** The user found it by playing:
## 「놓는 위치랑 배의 위치가 다른데?」. Put the sign back and this row reads **2507 px** of
## disagreement; the two `basis` rows above, added the same day, bite as well and are the cheap half.
##
## ⇒ **`Camera3D.unproject_position` is the projection's own inverse and cannot drift from it.** This
## row asks the ENGINE where a world point lands and asks `world_to_screen_px` the same question, over
## a real island with real hills, at two yaws and two zooms. Agreement is the whole claim.
##
## ⚠ **A 1280 x 720 `SubViewport`, because the headless window is 64 x 64.** `unproject_position`
## divides by its own viewport's size, and every literal in this file is measured against 1280 x 720;
## in a square window the vertical would be off by the aspect and this row would redden on the
## harness instead of on the camera.
func _the_engine_agrees_with_the_forward(t) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	t.root.add_child(vp)
	var fv := FieldView.new()
	vp.add_child(fv)
	var rows := Islands.rows()
	var g := Grid.new()
	g.load_rows(rows)
	var army := Army.new()
	var b := Battle.new()
	b.setup(g, army, [], 999.0)
	fv.setup(b, army, rows)
	await t.pump_frames(1)

	var worst := 0.0
	var seen := 0
	for zoom: float in [Look.ZOOM_MIN, Look.ZOOM_MAX]:
		for yaw: float in [0.0, 45.0]:
			fv.zoom = zoom
			fv.cam_yaw_deg = yaw
			fv._clamp_cam()
			fv._place_camera()
			for ty in range(0, g.h, 3):
				for tx in range(0, g.w, 3):
					var world := Look.tile_point_px(Vector2(tx, ty))
					var h: float = fv._ground_h(tx, ty)
					var engine: Vector2 = fv._cam.unproject_position(
						Vector3(world.x / Look.TILE_PX, h, world.y / Look.TILE_PX))
					worst = maxf(worst, engine.distance_to(fv.tile_to_screen_px(tx, ty)))
					seen += 1
	t.ok(seen > 200, "섬 하나를 두 줌 두 각도로 훑었다 — 표본 %d개 (자가 점검, 0개면 아무것도 안 쟀다)" % seen)
	t.ok(worst < 0.05,
		"엔진의 투영과 뷰의 정투영이 화면 어디서나 같은 답을 낸다 — 최악 %.4f px" % worst)

	# ⚠ **The self-check, and it is the exact shape of the defect**: turn the PURE side and leave the
	# camera where it was. The two descriptions now disagree, and this row has to see it — a row that
	# stayed green here would be comparing something with itself.
	fv.cam_yaw_deg = 30.0
	var drifted := 0.0
	for ty in range(0, g.h, 3):
		for tx in range(0, g.w, 3):
			var world := Look.tile_point_px(Vector2(tx, ty))
			var h: float = fv._ground_h(tx, ty)
			var engine: Vector2 = fv._cam.unproject_position(
				Vector3(world.x / Look.TILE_PX, h, world.y / Look.TILE_PX))
			drifted = maxf(drifted, engine.distance_to(fv.tile_to_screen_px(tx, ty)))
	t.ok(drifted > 10.0,
		"자가 점검 — 순수 쪽만 돌리고 카메라를 안 옮기면 둘이 실제로 갈린다 (%.1f px)" % drifted)

	fv.battle = null
	vp.queue_free()


## ⚠⚠ **THE SCREEN SHAKE IS DELETED AND THIS IS THE CHECK THAT IT IS GONE** (2026-08-25, the user:
## 「이게 화면이 흔들릴 필요는 없을듯?」). Every deletion needs one, or a half-alive constant comes back
## — `net_coast._deleted_names_are_really_gone` is the same row for the straight-line sailer.
##
## ⚠ **It was first switched off at the gain and left wired, and that was not enough.** A dead effect
## still wired keeps every check about it green while describing something the game no longer does.
##
## ⚠⚠ **WHAT WENT WITH IT, SAID RATHER THAN QUIETLY DROPPED.** Two real claims died here: **「the shake
## is a translation and never a rotation」** and **「at yaw 90 the same screen offset lands on turned
## world axes」**. They had no subject left. What replaced them is the stronger half of what they were
## protecting — **the camera's resting place is composed from ONE term now**, so there is nothing that
## can corrupt it.
func _the_shake_rides_the_screen_axes(t) -> void:
	var fv := _fv()
	t.ok(not fv.has_method("_shake_offset"),
		"field_view 에 _shake_offset 이 없다 — 화면 흔들림은 지워졌다")
	var props: Array = []
	for raw in fv.get_property_list():
		props.append(str((raw as Dictionary)["name"]))
	t.ok(not props.has("_shake_amp"), "_shake_amp 필드도 없다")
	t.ok(not props.has("_shake_left"), "_shake_left 필드도 없다")
	t.ok(props.has("cam_yaw_deg"), "대신 cam_yaw_deg 는 있다 (자가 점검 — 속성 목록을 실제로 읽고 있다)")

	var lconst: Dictionary = Look.new().get_script().get_script_constant_map()
	var left_over := []
	for name: String in ["SHAKE_SEC", "SHAKE_MAX_PX", "SHAKE_PER_DAMAGE_PX",
			"SHAKE_A_FREQ", "SHAKE_B_FREQ"]:
		if lconst.has(name):
			left_over.append(name)
	t.eq(left_over, [], "Look 에 화면 흔들림 상수가 하나도 안 남았다 %s" % str(left_over))
	t.ok(lconst.has("REFUSE_SHAKE_PX"),
		"REFUSE_SHAKE_PX 는 그대로 있다 — HUD 칩의 거절 떨림이지 카메라가 아니다 (자가 점검)")

	# And the resting place is one term. Placing twice from the same state lands in the same spot,
	# which is the guarantee the deleted rows existed to protect.
	fv._build_world()
	fv.zoom = 1.0
	fv.cam_px = Vector2(200.0, 100.0)
	fv._place_camera()
	var once: Vector3 = fv._cam.position
	fv.cam_yaw_deg = 90.0
	fv._place_camera()
	fv.cam_yaw_deg = 0.0
	fv._place_camera()
	t.ok(fv._cam.position.distance_to(once) < 0.0001,
		"돌렸다 되돌려도 카메라가 같은 자리에 선다 — 쉬는 자리를 흔드는 항이 없다")

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
