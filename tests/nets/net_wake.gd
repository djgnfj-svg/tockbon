extends RefCounted
## **What the water does about a hull** — the trail behind it and the mark round it, and they are one
## array, one loop and one net.
##
## The claim under test is one sentence: **every live hull writes its own block of the water's history,
## slot 0 at its transom on the SCREEN's clock, one remembered point every `Look.wake_every_sec`, and
## the whole array lands on the material the sea is actually drawn with.**
##
## ⚠⚠ **THE PICTURE IS NOT HERE AND CANNOT BE.** The wake is drawn by `water.gdshader` out of this
## array; what a pixel comes out as is `verify-look`'s. **What this file measures is the three things
## a shader-drawn mark can lie about**: the numbers handed in, the names they are handed in under, and
## whether the hand-over happened at all. ⚠ **The last of those is what a surface count is elsewhere** —
## a history built into `_wake` and never handed to the material is a buffer with no commit, and every
## row about `_wake` alone stays green when `set_shader_parameter` is deleted.
##
## ⚠⚠ **THE LAB SAILED ITS BOAT AT 4.0 조각/s AND THE GAME SAILS AT 1.2.** `.prototypes/wake/common.gd`
## copied `Rules.BOAT_SPEED_TILES` by hand and the copy went stale, so the trail the user chose was
## about 16 조각 long and the same `WAKE_LIFE_SEC` draws 4.8 조각 here. **Nothing in this file holds
## that down**, deliberately: it is a value for the screen to judge again, and a check written round
## it would go red on the day somebody fixed it.
##
## Fixtures are ARENA-small. `setup()` rebuilds a whole terrain mesh, and a real island per row is what
## made an old net spin for 24 s unnoticed.


const ARENA_W := 24
const ARENA_H := 12

const SHADER_PATH := "res://src/view/water.gdshader"

## **Every dial section 7 of the shader declares, written out by hand.**
##
## ⚠⚠ **A HAND LIST AND NOT A SCAN, AND THAT IS THE WHOLE VALUE OF IT.** `set_shader_parameter` on a
## name no uniform has is **silently ignored** — no error, no warning, and the mark simply never
## appears. A list generated from the same file the view is checked against would agree with itself
## whatever either side said. **This is a third opinion, and renaming a uniform on one side reddens.**
const DIALS := [
	"wake_hull", "wake_t", "wake_life", "wake_stern", "wake_w", "wake_hard", "wake_alpha",
	"wake_side_close", "wake_froth_scale", "wake_froth_amt",
	"hull_half", "hull_beam", "hull_shadow_w", "hull_shadow_bow", "hull_shadow_col",
	"hull_break_w", "hull_break_amt", "hull_break_bow",
	"hull_halo_tiles", "hull_halo_amt", "hull_halo_aft",
]

## Every `FieldView` built here, freed at the end — a `Node2D` left unfreed is a leaked RID on stderr,
## which the wrapper reads as failure.
var _created: Array = []


func run(t) -> void:
	_the_numbers_are_the_ones_that_were_chosen(t)
	_the_two_lengths_are_the_same_in_both_languages(t)
	_the_shader_declares_every_dial_by_that_name(t)
	_the_shader_itself_compiles_and_sees_them(t)
	_the_material_carries_every_one_of_them(t)
	_no_boat_leaves_the_water_unmarked(t)
	_one_boat_writes_its_own_block_and_nobody_elses(t)
	_slot_zero_is_the_transom_and_not_the_middle(t)
	_the_heading_is_the_boards_and_not_the_models(t)
	_the_sides_leave_at_the_hulls_beam_and_close_behind_it(t)
	_the_shader_builds_two_sides_out_of_that(t)
	_the_bright_lip_touches_the_planking(t)
	_the_two_sides_straddle_the_boats_own_track(t)
	_a_point_is_remembered_on_a_clock_and_not_every_frame(t)
	_the_oldest_point_is_older_than_the_trail_lives(t)
	_the_block_stays_in_order_and_never_grows(t)
	_the_remembered_points_lie_on_the_boats_own_track(t)
	_the_clock_is_the_screens_and_the_sim_stands_still(t)
	_a_hull_that_has_stopped_stops_marking_the_water(t)
	_a_hull_that_leaves_the_board_takes_its_block_with_it(t)
	_a_gone_hull_takes_its_marks_with_it(t)
	_a_new_island_opens_with_no_trails_on_it(t)
	_every_hull_is_marked_the_same_way(t)
	_boats_past_the_ceiling_are_dropped_and_the_rest_are_not(t)
	_the_shadow_is_the_sea_darker_and_cooler(t)
	for raw in _created:
		var fv: FieldView = raw
		fv.free()
	_created = []
	# **The sentinel.** See `run_nets.done` — without it a `run()` that dies
	# half way still reports every check it managed first, in a shape a healthy net cannot be told from.
	t.done()


# == the numbers ======================================================================================

## **The one place a chosen value is written as a literal.** Everything below reads `Look`, so this is
## what goes red when somebody retunes the trail — and a trail that measures the same at any width
## measures nothing.
func _the_numbers_are_the_ones_that_were_chosen(t) -> void:
	t.eq(Look.WAKE_LIFE_SEC, 4.0, "자국은 4초를 산다 — 고른 후보가 그 값이다")
	t.eq(Look.WAKE_W_TILES, 0.16, "선 반너비가 0.16조각이다")
	t.eq(Look.WAKE_HARD, 0.35, "가장자리는 너비의 0.35 지점부터 무르다")
	t.eq(Look.WAKE_ALPHA, 0.85, "진하기가 0.85다")
	t.eq(Look.WAKE_HULLS, 12, "물이 한 번에 표시할 수 있는 선체는 열둘이다")
	t.eq(Look.WAKE_SLOTS, 8, "선체 하나가 여덟 칸을 갖는다 — 0번이 지금, 나머지 일곱이 지나온 자리")

	# ⚠⚠ **THE INSET IS NOT THE LENGTH.** `Rules` owns how long the boat is and this owns how far
	# inside the transom the trail starts; written as one number it would be right until the next
	# export of `boat.glb`.
	t.eq(Look.WAKE_STERN_INSET_TILES, 0.15, "고물에서 0.15조각 안쪽에서 자국이 난다")
	t.eq(Look.wake_stern_tiles(), -(Rules.BOAT_HULL_HALF_TILES - Look.WAKE_STERN_INSET_TILES),
		"그래서 자국이 나는 자리가 선체 반길이에서 그만큼 뺀 뒤쪽이다 — 따로 적은 숫자가 아니다")
	t.ok(Look.wake_stern_tiles() < 0.0, "자가 점검 — 그 자리는 뱃머리 쪽이 아니라 뒤쪽이다")

	# ⚠⚠ **`WAKE_SLOTS - 2` AND NOT `- 1`.** Slot 0 is now, so `WAKE_SLOTS - 1` remembered points span
	# `WAKE_SLOTS - 2` gaps — and the oldest of them has to be at least a whole life old or the trail
	# runs out of slots while it is still visible. `_the_oldest_point_is_older_than_the_trail_lives`
	# is the same claim measured on a running view; this is the arithmetic on its own.
	t.eq(Look.wake_every_sec(), Look.WAKE_LIFE_SEC / float(Look.WAKE_SLOTS - 2),
		"점 사이 간격이 수명을 칸 수 빼기 둘로 나눈 값이다")
	t.ok(float(Look.WAKE_SLOTS - 2) * Look.wake_every_sec() >= Look.WAKE_LIFE_SEC,
		"그래서 제일 오래된 점이 수명보다 오래 살아 있다 — 꼬리가 끊기지 않고 사라진다")


# == the two languages ================================================================================

## **The array's length is written in GDScript and in GLSL and cannot be derived from one place.**
##
## ⚠⚠ **A GLSL ARRAY'S LENGTH IS A COMPILE-TIME NUMBER.** It cannot arrive as a uniform, so the ceiling
## is genuinely written twice and this row is the whole of what keeps the two together. **Moving
## `Look.WAKE_HULLS` without moving the shader's own `const int` reddens here** — and out on the screen
## it would read as the thirteenth boat's marks landing on the first boat's water.
##
## ⚠ **The reader is inverted on a string of its own**, because one that always answered the same
## number would agree with anything.
func _the_two_lengths_are_the_same_in_both_languages(t) -> void:
	var src := _shader_text()
	t.ok(src.length() > 500, "물 셰이더 원문을 읽었다 (자가 점검 — 못 읽으면 아래가 전부 공허하다)")

	t.eq(_glsl_int(src, "WAKE_HULLS"), Look.WAKE_HULLS,
		"셰이더가 적어 둔 선체 수가 look.gd 의 것과 같다")
	t.eq(_glsl_int(src, "WAKE_SLOTS"), Look.WAKE_SLOTS,
		"셰이더가 적어 둔 칸 수도 같다")
	t.eq(_glsl_int(src, "WAKE_MAX"), Look.WAKE_HULLS * Look.WAKE_SLOTS,
		"그리고 배열 길이가 그 둘의 곱이다 — 남거나 모자란 칸이 없다")

	# **The reader, inverted.** One that hands back a constant passes every row above.
	t.eq(_glsl_int("const int WAKE_HULLS = 999;", "WAKE_HULLS"), 999,
		"자가 점검 — 읽는 쪽이 실제로 숫자를 읽는다: 다른 값을 주면 다른 값이 나온다")
	t.eq(_glsl_int("nothing here", "WAKE_HULLS"), -1,
		"자가 점검 — 없는 이름에는 -1 을 준다: 못 찾은 것이 조용히 0 이 되지 않는다")


## **Every dial the view hands over is declared under that name in the shader.**
##
## ⚠⚠ **`set_shader_parameter` ON A NAME NO UNIFORM HAS IS SILENTLY IGNORED** — no error, no warning,
## and the mark simply never appears. **This is the row that turns a typo into a red**, and it reads
## the shader's own text rather than the view's, so the two are genuinely two opinions.
func _the_shader_declares_every_dial_by_that_name(t) -> void:
	var src := _shader_text()
	var missing := []
	for raw in DIALS:
		var nm := str(raw)
		if not _declares_uniform(src, nm):
			missing.append(nm)
	t.eq(missing, [], "셰이더가 손으로 적은 다이얼 %d 개를 전부 uniform 으로 선언한다" % DIALS.size())

	# **The reader, inverted**: one that says yes to everything passes the row above.
	t.ok(not _declares_uniform(src, "wake_nonesuch"),
		"자가 점검 — 없는 이름에는 아니라고 한다")
	t.ok(_declares_uniform(src, "sea"),
		"자가 점검 — 있는 이름에는 맞다고 한다 (바다 색은 원래부터 있던 uniform 이다)")


## **The shader actually compiles, and the engine can see every dial standing on it.**
##
## ⚠⚠ **A GLSL SYNTAX ERROR IS NOT A GDScript PARSE ERROR, AND NOTHING ELSE IN THIS REPO CATCHES
## ONE.** The row above reads the file as text and would pass a shader that does not compile at all —
## it is measuring the NAMES. **This one asks the engine**, which is the only opinion that draws.
## ⚠ **It works headless, and that was measured rather than assumed**: the uniform list comes back
## full under the dummy renderer, so 「셀이더는 헤드리스로 못 재다」 is not true here.
func _the_shader_itself_compiles_and_sees_them(t) -> void:
	var sh := load(SHADER_PATH) as Shader
	t.ok(sh != null, "물 셀이더가 리소스로 실렸다 (자가 점검)")
	var seen := {}
	for row in sh.get_shader_uniform_list():
		seen[str((row as Dictionary)["name"])] = true
	t.ok(seen.size() > 40,
		"엔진이 uniform 을 %d 개 본다 — 셀이더가 실제로 컴파일됐다" % seen.size())
	var missing := []
	for raw in DIALS:
		if not seen.has(str(raw)):
			missing.append(str(raw))
	t.eq(missing, [], "그중에 손으로 적은 다이얼 %d 개가 전부 있다" % DIALS.size())


## **And every one of them is actually ON the material the sea is drawn with.**
##
## ⚠⚠ **THIS IS THE COMMIT HALF AND WITHOUT IT EVERY OTHER ROW IN THIS FILE STAYS GREEN WHEN THE
## HAND-OVER IS DELETED.** `_wake` can be built perfectly, frame after frame, and never reach the
## water; the buffer proves the numbers were worked out and only the material proves they were given
## to the thing that draws.
func _the_material_carries_every_one_of_them(t) -> void:
	var fv: FieldView = _boat_view()["fv"]
	var mat := _sea_material(fv)
	t.ok(mat != null, "바다에 셰이더 재질이 붙어 있다 (자가 점검)")
	var blank := []
	for raw in DIALS:
		var nm := str(raw)
		if mat.get_shader_parameter(nm) == null:
			blank.append(nm)
	t.eq(blank, [], "그 재질이 다이얼 %d 개를 전부 값으로 들고 있다" % DIALS.size())

	# The two that MOVE, against the view's own fields — a stale hand-over is a live failure mode.
	t.eq(mat.get_shader_parameter("wake_hull"), fv._wake,
		"재질이 든 이력이 뷰가 만든 그 이력이다")
	t.eq(mat.get_shader_parameter("wake_t"), fv._sea_clock,
		"그리고 재질이 든 시각이 뷰의 시계다")
	# The constants, spot-checked where they are DERIVED rather than copied.
	t.eq(mat.get_shader_parameter("hull_half"), Rules.BOAT_HULL_HALF_TILES,
		"선체 반길이는 Rules 것이 그대로 간다 — look.gd 에 사본이 없다")
	t.eq(mat.get_shader_parameter("hull_beam"), Rules.BOAT_HULL_BEAM_TILES * 0.5,
		"폭은 Rules 의 전폭을 반으로 나눈 것이다")
	t.eq(mat.get_shader_parameter("wake_stern"), Look.wake_stern_tiles(),
		"자국이 나는 자리도 파생값 그대로다")


# == the history ======================================================================================

## Before the first boat there is nothing on the water, and the array says so in the only way it can.
func _no_boat_leaves_the_water_unmarked(t) -> void:
	var pack := _boat_view(0.0)
	var fv: FieldView = pack["fv"]
	t.eq((pack["b"] as Battle).boat_pos.size(), 0, "첫 배 시각 전에는 배가 없다 (자가 점검)")
	t.eq(fv._wake.size(), Look.WAKE_HULLS * Look.WAKE_SLOTS,
		"이력은 선체 수 곱하기 칸 수 만큼 잡혀 있다")
	t.eq(_live_slots(fv), 0, "그리고 살아 있는 칸이 하나도 없다")
	# ⚠ **Not `Vector4.ZERO`.** A packed array grows filled with zeros, and a zero z reads as 「written
	# at time zero」 — twelve hulls standing on the origin, with no error anywhere.
	t.ok(fv._wake[0].z < 0.0, "빈 칸은 시각이 음수다 — 0 이 아니다")


## One boat writes one block, and the other eleven are untouched.
func _one_boat_writes_its_own_block_and_nobody_elses(t) -> void:
	var pack := _boat_view()
	var fv: FieldView = pack["fv"]
	t.eq((pack["b"] as Battle).boat_pos.size(), 1, "판에 배가 한 척 떴다 (자가 점검)")
	t.eq(_live_hulls(fv), 1, "블록 하나만 살아 있다")
	t.ok(fv._wake[0].z >= 0.0, "그 블록이 0번이다")
	t.eq(_live_slots_of(fv, 1), 0, "1번 블록은 한 칸도 안 쓰였다 — 배마다 제 블록이다")
	t.eq(_live_slots_of(fv, Look.WAKE_HULLS - 1), 0, "마지막 블록도 마찬가지다")


## **Slot 0 is the transom and not the hull's middle, and the difference is most of the picture.**
##
## ⚠⚠ **ANCHORED AMIDSHIPS, THE FIRST 2.6 조각 OF THE TRAIL LIE UNDER AN OPAQUE HULL** and only about
## 2.2 조각 of it ever reach open water — against 4.65 anchored here. **A position check cannot see
## this**: both anchors put the mark on the boat, and one of them puts most of it under the boat.
func _slot_zero_is_the_transom_and_not_the_middle(t) -> void:
	var pack := _boat_view()
	var fv: FieldView = pack["fv"]
	var b: Battle = pack["b"]
	var mid := Look.tile_point_px(b.boat_pos[0]) / Look.TILE_PX
	var slot: Vector4 = fv._wake[0]
	var here := Vector2(slot.x, slot.y)
	var head := fv._boat_heading(0)

	var want := Rules.BOAT_HULL_HALF_TILES - Look.WAKE_STERN_INSET_TILES
	t.ok(absf(here.distance_to(mid) - want) < 1e-3,
		"0번 칸이 선체 가운데에서 %.2f조각 떨어져 있다 (%.3f)" % [want, here.distance_to(mid)])
	t.ok((here - mid).dot(head) < 0.0,
		"그리고 그 방향이 가는 쪽의 반대다 — 뱃머리가 아니라 고물이다")
	# ⚠⚠ **THE SELF-CHECK THAT STOOD HERE DEMANDED `want > 2.0` AND IS DELETED** (02-08). It guarded
	# the first row above from going vacuous — a `want` of 0 makes 「the mark sits `want` away from the
	# hull's middle」 true of an implementation that stamps the middle. **It was already false of the
	# 2.1 hull it was written for** (2.1 − 0.15 = 1.95), and the small boat took the half-length to
	# 1.5. **Nothing replaces it: the gap between the stern anchor and the hull's middle is unmeasured
	# from here on**, and the row above can be satisfied by a middle-anchored mark the day `want` is 0.


## **The heading a slot carries is the BOARD's and not the model's.**
##
## ⚠⚠ **`_boat_yaw` AND `_wake_head_rad` DISAGREE ON EVERY HEADING BUT DUE EAST AND DUE WEST**, because
## a model whose bow is +X turns under Godot's own −Z convention and carries a sign flip the water does
## not. **Handing the shader a model yaw draws every mark on the wrong side of the boat with every
## position check still green** — the shape `_boat_yaw`'s own comment was written about.
##
## ⚠⚠ **THE BOAT IS RE-AIMED, AND THE FIRST VERSION OF THIS ROW WAS VACUOUS WITHOUT IT —
## MEASURED.** The arena's first boat sails due EAST, and due east is one of the two headings where the
## two conventions agree exactly: **storing `_boat_yaw` instead passed every line here.** Re-aiming is
## a view-side read — nothing in `sim` decides an angle — so moving the boat and painting again asks
## the question the fixture could not.
func _the_heading_is_the_boards_and_not_the_models(t) -> void:
	var head := Vector2(0.6, 0.8)
	var w := FieldView._wake_head_rad(head)
	t.ok(absf(cos(w) - head.x) < 1e-4 and absf(sin(w) - head.y) < 1e-4,
		"저장된 각을 코사인·사인으로 풀면 판 위의 그 방향이 나온다")

	var pack := _boat_view()
	var fv: FieldView = pack["fv"]
	var b: Battle = pack["b"]
	t.ok(absf(fv._boat_yaw(head) - w) > 0.1,
		"자가 점검 — 선체의 yaw 는 이것과 다른 값이다: 둘이 같으면 아래가 공허하다")

	var beach := int(b.boat_beach[0])
	var target := Vector2(beach % b.grid.w, beach / b.grid.w)
	b.boat_pos[0] = target + Vector2(-3.0, -4.0)
	fv._process(0.0)
	var live := fv._boat_heading(0)
	t.ok(absf(live.y) > 0.1,
		"자가 점검 — 다시 겨눈 배가 정동·정서가 아니다: 그 둘에서는 두 규약이 같은 값을 준다")

	var painted: Vector4 = fv._wake[0]
	t.ok(absf(cos(painted.w) - live.x) < 1e-3 and absf(sin(painted.w) - live.y) < 1e-3,
		"그리고 실제로 그려진 배도 판 위의 각을 들고 있다 (%.3f, %.3f)" % [live.x, live.y])


## **The one dial the two sides have, and the two things it may not be.**
##
## ⚠⚠ **NO WIDTH LIVES HERE AND THAT IS THE POINT.** Where a side starts is the hull's own half-beam
## at the transom, worked out in the shader from `hull_beam` and `wake_stern`; **this is a fraction of
## that and nothing else**, and a second width constant is what this row exists to keep out.
## ⚠⚠ **AT 1.0 THE TWO NEVER MEET AND THE TRAIL READS AS A ROAD** — two rails running off astern
## rather than water pushed aside.
##
## ⚠⚠ **HOW FAR APART THE PAIR ACTUALLY STANDS IS NOT MEASURED HERE ANY MORE, AND THE ROW THAT DID IT
## WAS WRONG THE MOMENT THE START MOVED** (2026-08-30). It read the full beam 2.01 조각 as the opening
## width; the opening width is now the transom's own 0.67, so the row's arithmetic went on agreeing
## with itself about a number the shader had stopped using. **The taper is GLSL and mirroring it here
## is how that happens again** — the source row below is what is left, and it measures structure.
func _the_sides_leave_at_the_hulls_beam_and_close_behind_it(t) -> void:
	t.eq(Look.WAKE_SIDE_CLOSE, 0.15,
		"수명 끝에서 옆선이 처음 벌어진 폭의 0.15 만큼만 남는다 — 비율로 잡은 첫 값이다")
	t.ok(Look.WAKE_SIDE_CLOSE < 1.0, "1.0 이 아니다 — 두 선이 영영 나란히 가면 물이 아니라 길이다")
	t.ok(Look.WAKE_SIDE_CLOSE >= 0.0, "그리고 음수가 아니다 — 두 선이 서로를 넘어가지 않는다")

	var fv: FieldView = _boat_view()["fv"]
	t.eq(_sea_material(fv).get_shader_parameter("wake_side_close"), Look.WAKE_SIDE_CLOSE,
		"물이 그 값을 그대로 받는다")


## **And the shader builds the two out of exactly those, in its own text.**
##
## ⚠⚠ **THE OFFSET ITSELF IS GLSL AND NOTHING IN THIS REPO RUNS GLSL.** Where a stroke lands is
## worked out per fragment; headless there is no fragment. **So this row is a third opinion on the
## file's own source**, the same technique `_the_two_lengths_are_the_same_in_both_languages` uses and
## for the same reason — it reddens when one side changes and the other does not. ⚠ **It measures
## structure and not picture**: what a pixel comes out as is `verify-look`'s.
## ⚠ **Every reader below is inverted on a string of its own**, because one that always answers the
## same thing agrees with anything.
func _the_shader_builds_two_sides_out_of_that(t) -> void:
	var src := _shader_text()
	var arm := _glsl_func(src, "float wake_arm(")
	t.ok(arm.length() > 20, "셰이더에 옆선의 거리를 내는 함수가 있다 (자가 점검)")
	t.ok(arm.contains("hull_beam"),
		"옆선이 선체 자신의 반폭에서 출발한다 — 웨이크가 따로 든 너비가 아니다")
	# ⚠⚠ **THE TRANSOM IS NOT THE WIDEST PART OF THE BOAT.** At the full half-beam each line starts
	# about 0.67 조각 out in open water with nothing joining it to the planking — **the floating part
	# the user photographed.** `hull_taper` asked at `wake_stern` is where the trail actually leaves.
	t.ok(arm.contains("hull_taper(") and arm.contains("wake_stern"),
		"그 반폭을 고물 자리에서 묻는다 — 배 한가운데의 폭이 아니다")
	t.ok(arm.contains("wake_side_close"), "그 안에서 다이얼이 실제로 읽힌다")
	t.ok(arm.contains("wake_life"),
		"닫히는 정도가 나이로 정해진다 — 점은 고물에서 얼마나 뒤인지를 모르고 언제 남았는지만 안다")

	# **And the taper has one owner.** The contact shadow thins by the same curve; written out twice,
	# the day the outline stops being an ellipse one of the two goes on tapering the old way.
	var taper := _glsl_func(src, "float hull_taper(")
	t.ok(taper.contains("hull_half"), "그 폭 곡선이 선체 반길이에서 나온다")
	t.eq(_count_in(_glsl_func(src, "vec3 hulls("), "hull_taper("), 1,
		"접촉 그림자도 같은 곡선을 부른다 — 폭이 어떻게 좁아지는지를 아는 자리가 하나다")

	var body := _glsl_func(src, "vec3 hulls(")
	t.ok(body.length() > 200, "선체를 그리는 함수도 읽었다 (자가 점검)")
	t.eq(_count_in(body, "wake_line("), 2, "꼬리가 한 줄이 아니라 두 줄이다 — 한 줄을 지우면 붉어진다")
	t.ok(body.contains("wake_arm("), "그 두 줄이 옆으로 밀린 자리에서 그려진다")
	t.ok(body.contains("s.w"),
		"그리고 점마다 제 각을 읽는다 — 0번 칸의 각 하나로 전부 밀면 돈 배의 자국이 지금 뱃머리 쪽으로 각진다")

	# **The readers, inverted.**
	t.eq(_glsl_func(src, "float wake_nonesuch("), "",
		"자가 점검 — 없는 함수에는 빈 문자열을 준다: 못 찾은 것이 조용히 통과하지 않는다")
	t.ok(not _glsl_func(src, "float wake_arm(").contains("hulls"),
		"자가 점검 — 함수 하나만 잘라 온다: 파일 전체를 주면 위의 이름 검사가 전부 공허하다")
	t.eq(_count_in("a( b a( c", "a("), 2, "자가 점검 — 세는 쪽이 실제로 센다")
	t.eq(_count_in("nothing", "a("), 0, "자가 점검 — 없으면 0 이다")


## **The bright lip stands ON the planking, with no sea between it and the boat.**
##
## ⚠⚠ **THE GAP WAS THE THING THE USER PHOTOGRAPHED** (2026-08-30: 「이렇게 띄워져 있는부분 없이
## 왔으면 좋겠음」). The white used to be a stroke centred a standoff outside the contact shadow's own
## edge, which left its inner edge 0.35–0.47 조각 off the hull with **plain sea in between** — twelve
## to fifteen pixels at the zoom an island opens at. **The shore's two-whites-with-dark-between is
## right for rock and wrong for a hull**: the island is large enough that the band reads as water.
## ⚠ **The shadow has to survive the fix.** A lip that reaches as far as the shadow does swallows it,
## and the shadow is the one mark saying「in the water」 rather than「on it」.
## ⚠ **Structure and numbers, not picture** — where a pixel lands is `verify-look`'s.
func _the_bright_lip_touches_the_planking(t) -> void:
	t.eq(Look.HULL_BREAK_W_TILES, 0.07,
		"윤곽에서 0.07조각 나가며 스러진다 — 옛 획의 전체 폭 그대로고 새로 잡은 무게가 아니다")
	t.ok(Look.HULL_BREAK_W_TILES < Look.HULL_SHADOW_W_TILES,
		"그 흰 입술이 접촉 그림자보다 좁다 — 그림자가 바깥으로 남는다 (%.3f < %.3f)"
			% [Look.HULL_BREAK_W_TILES, Look.HULL_SHADOW_W_TILES])

	var src := _shader_text()
	var body := _glsl_func(src, "vec3 hulls(")
	t.ok(body.length() > 200, "선체를 그리는 함수를 읽었다 (자가 점검)")
	t.ok(not body.contains("abs(out_d"),
		"흰 선이 윤곽에서의 거리를 그대로 잰다 — 어딘가를 중심으로 한 획이 아니라 붙어 있는 입술이다")
	t.ok(not src.contains("hull_break_at"),
		"그리고 띄우던 다이얼이 셰이더 어디에도 안 남아 있다")
	# ⚠ **The DECLARATION and not the name.** The name stays in `look.gd` on purpose — a deleted dial
	# leaves a line saying it was deleted and why, which is how the next round is stopped from putting
	# the gap back. What must be gone is anything still holding a value.
	t.ok(not _look_text().contains("const HULL_BREAK_AT_TILES"),
		"look.gd 도 그 상수를 안 들고 있다 — 아무도 안 읽는 값이 아니라 지운 값이다")

	# **The readers, inverted.** Ones that answer no to everything pass all four rows above.
	t.ok(src.contains("hull_break_w"), "자가 점검 — 있는 이름에는 있다고 한다")
	t.ok(_look_text().contains("const HULL_BREAK_W_TILES"), "자가 점검 — look.gd 도 실제로 읽혔다")


## **The angle a slot carries resolves to a normal ACROSS the boat's course, which is what a side is.**
##
## ⚠⚠ **ONE CLAIM AND ONE ONLY, BECAUSE THE REST OF THE STRADDLE CANNOT FAIL.** The shader steps off
## `vec2(-sin w, cos w)` by the beam, both ways; **that the two come out symmetric about the track and
## the hull's beam apart is arithmetic, not a measurement** — a net doing the same sum would agree with
## itself whatever the code said. What genuinely has two answers is **which way the angle turns**, and
## the wrong one puts both sides along the course instead of across it.
## ⚠ **Whether the SHADER does it is the row above, on the source.** A pixel is `verify-look`'s.
##
## ⚠⚠ **THE BOAT IS RE-AIMED OFF THE AXES AND WITHOUT THAT THIS IS VACUOUS — THE SAME TRAP THAT
## EMPTIED A ROW IN THIS FILE ONCE.** The arena's first boat sails due EAST, and there a normal taken
## from the model's yaw comes out perpendicular to the course as well: **the wrong convention passes
## every line below.** Off the axes the two part company, which is what the last row measures.
func _the_two_sides_straddle_the_boats_own_track(t) -> void:
	var pack := _boat_view()
	var fv: FieldView = pack["fv"]
	var b: Battle = pack["b"]
	var beach := int(b.boat_beach[0])
	var target := Vector2(beach % b.grid.w, beach / b.grid.w)
	b.boat_pos[0] = target + Vector2(-3.0, -4.0)
	fv._process(0.0)
	var head := fv._boat_heading(0)
	t.ok(absf(head.x) > 0.1 and absf(head.y) > 0.1,
		"자가 점검 — 배가 축에 안 붙어 있다 (%.3f, %.3f)" % [head.x, head.y])

	var slot: Vector4 = fv._wake[0]
	var n := Vector2(-sin(slot.w), cos(slot.w))
	t.ok(absf(n.dot(head)) < 1e-3,
		"저장된 각에서 나온 법선이 배가 가는 쪽과 직각이다 — 옆선이 뒤가 아니라 옆으로 난다")

	# **The inversion, and it is the live one.** A model yaw carries a sign flip the board's angle does
	# not, so the normal taken from it leans along the course instead of across it — everywhere but the
	# two headings the fixture was moved off.
	var yaw := fv._boat_yaw(head)
	var wrong := Vector2(-sin(yaw), cos(yaw))
	t.ok(absf(wrong.dot(head)) > 0.1,
		"자가 점검 — 모델 yaw 로 잡은 법선은 직각이 아니다 (%.3f): 위 두 줄이 규약을 실제로 잰다"
			% wrong.dot(head))


## **A point is remembered on a clock, not once a frame.**
##
## ⚠ Eight frames at a sixtieth of a second is an eighth of one interval. **A commit per frame fills
## the whole block inside that window**, which is exactly what the second half below refuses.
func _a_point_is_remembered_on_a_clock_and_not_every_frame(t) -> void:
	var fv: FieldView = _boat_view()["fv"]
	t.eq(_live_slots_of(fv, 0), 2, "첫 프레임에 0번 칸과 1번 칸이 선다 — 지금 자리가 곧 첫 기억이다")

	for _k in 8:
		fv._process(1.0 / 60.0)
	t.eq(_live_slots_of(fv, 0), 2,
		"%.3f초가 지나도 여전히 둘이다 — 프레임마다 기억하는 게 아니다" % (8.0 / 60.0))

	fv._process(Look.wake_every_sec())
	t.eq(_live_slots_of(fv, 0), 3, "간격을 넘기면 셋이 된다")


## **Once the block is full its oldest point is older than the trail lives.**
##
## ⚠⚠ **THIS IS WHAT `WAKE_SLOTS - 2` BUYS AND THE ONLY PLACE IT IS MEASURED ON A RUNNING VIEW.** At
## `- 1` the oldest point is `(SLOTS-2)/(SLOTS-1)` of a life old at worst — the trail runs out of slots
## while it is still at about a seventh of its opacity, **and it stops on a step instead of fading
## out.** Nothing on screen says which of the two it is; this row does.
func _the_oldest_point_is_older_than_the_trail_lives(t) -> void:
	var fv: FieldView = _boat_view()["fv"]
	# Long enough to fill every slot and then some, in steps under one interval so the clock is what
	# decides and not the step size.
	for _k in 200:
		fv._process(Look.wake_every_sec() * 0.25)
	t.eq(_live_slots_of(fv, 0), Look.WAKE_SLOTS, "블록이 꽉 찼다 (자가 점검)")
	var oldest: Vector4 = fv._wake[Look.WAKE_SLOTS - 1]
	var age := fv._sea_clock - oldest.z
	t.ok(age >= Look.WAKE_LIFE_SEC,
		"제일 오래된 점이 %.2f초 됐다 — 수명 %.2f초보다 오래다" % [age, Look.WAKE_LIFE_SEC])


## The block is newest-first, strictly ordered, and never grows past its own slots.
func _the_block_stays_in_order_and_never_grows(t) -> void:
	var fv: FieldView = _boat_view()["fv"]
	for _k in 200:
		fv._process(Look.wake_every_sec() * 0.25)
	t.eq(fv._wake.size(), Look.WAKE_HULLS * Look.WAKE_SLOTS,
		"이력의 크기는 그대로다 — 배열이 자라지 않는다")

	var out_of_order := 0
	for k in Look.WAKE_SLOTS - 1:
		var a: Vector4 = fv._wake[k]
		var b: Vector4 = fv._wake[k + 1]
		if a.z < b.z:
			out_of_order += 1
	t.eq(out_of_order, 0, "칸이 새것부터 헌것 순으로 서 있다")
	t.eq(_live_slots_of(fv, 0), Look.WAKE_SLOTS, "그리고 중간에 빈 칸이 없다")


## **The remembered points are the boat's own track, walked backwards.**
##
## ⚠ The one row that runs the whole chain — `Battle.step` moves the boat, `_process` remembers where
## it was, and the spacing that comes out is the boat's own speed times the interval. **A view that
## remembered its own last frame's position instead of the sim's would pass every row above.**
func _the_remembered_points_lie_on_the_boats_own_track(t) -> void:
	var pack := _boat_view()
	var fv: FieldView = pack["fv"]
	var b: Battle = pack["b"]
	# ⚠ **A twentieth of an interval per frame, and the fineness is load-bearing.** A point is
	# remembered on **the first frame past** the interval, so a coarse frame overshoots it and the
	# spacing below comes out one frame long — at a quarter of an interval that is a 25% error and the
	# tolerance would have to be wide enough to accept a wrong answer.
	var frame := Look.wake_every_sec() * 0.05
	for _k in 200:
		b.step(frame)
		fv._process(frame)
	t.eq(int(b.boat_state[0]), Battle.BoatState.SAILING,
		"이 동안 배는 계속 항해 중이다 (자가 점검 — 도착했으면 아래가 점 하나를 잰다)")
	t.eq(_live_slots_of(fv, 0), Look.WAKE_SLOTS, "블록이 꽉 찼다 (자가 점검)")

	var head := fv._boat_heading(0)
	var want := Rules.BOAT_SPEED_TILES * Look.wake_every_sec()
	# ⚠ **The remembered points only, from slot 1.** Slot 0 is where the hull is NOW and it coincides
	# with slot 1 on exactly the frame a point was remembered — a real state, not a defect.
	var forward := 0
	var off := 0
	for k in range(1, Look.WAKE_SLOTS - 1):
		var a: Vector4 = fv._wake[k]
		var c: Vector4 = fv._wake[k + 1]
		var step := Vector2(a.x - c.x, a.y - c.y)
		if step.dot(head) <= 0.0:
			forward += 1
		# One frame of travel is `want * 0.05`; the band is twice that and nothing like a wrong answer.
		if absf(step.length() - want) > want * 0.10:
			off += 1
	t.eq(forward, 0, "헌 점일수록 뒤에 있다 — 배가 지나온 자리다")
	t.eq(off, 0, "그리고 점 사이가 배 속도 곱하기 간격(%.3f조각)이다" % want)


## **The clock the water is aged by is the SCREEN's, and the sim standing still does not stop it.**
##
## ⚠⚠ **THE SIM IS NOT STEPPED IN THIS ROW AND THAT IS THE WHOLE MEASUREMENT.** A history aged off
## `battle.elapsed` would put a second clock under the game — the seam every defect worth the name here
## has come out of — and marks that froze whenever the sim was not stepped would read as the picture
## having stopped.
## ⚠ **The hull's own STAMP is not what advances**, and that is `_wake_stamp`: a boat that has not
## moved is not leaving a new mark. The row below is about the clock those marks are aged against.
func _the_clock_is_the_screens_and_the_sim_stands_still(t) -> void:
	var pack := _boat_view()
	var fv: FieldView = pack["fv"]
	var b: Battle = pack["b"]
	var froze: Vector2 = b.boat_pos[0]
	var elapsed := b.elapsed
	var mat := _sea_material(fv)
	var was: float = mat.get_shader_parameter("wake_t")

	for _k in 4:
		fv._process(Look.wake_every_sec())
	t.ok(float(mat.get_shader_parameter("wake_t")) > was + 1.0,
		"sim 을 안 밀어도 물이 읽는 시각이 앞으로 간다")
	t.eq(mat.get_shader_parameter("wake_t"), fv._sea_clock, "그 시각이 화면의 시계 그 값이다")
	t.eq(b.elapsed, elapsed, "자가 점검 — 그동안 sim 의 시계는 한 번도 안 움직였다")
	t.ok((b.boat_pos[0] as Vector2).distance_to(froze) <= 0.0,
		"자가 점검 — 배도 한 조각 안 움직였다")

	# **And a hull that DID move is stamped with that same screen clock.** Moving the boat by hand is a
	# view-side read — nothing in `sim` decides when a mark is left.
	b.boat_pos[0] = froze + Vector2(1.0, 1.0)
	fv._process(0.0)
	t.ok(absf(fv._wake[0].z - fv._sea_clock) < 1e-4,
		"움직인 선체는 그 화면 시계로 도장이 찍힌다")


## **A hull that has stopped does not re-stamp its transom.**
##
## ⚠⚠ **THE FAILURE THIS CATCHES IS A BRIGHT DOT THAT NEVER GOES OUT.** Slot 0 is re-written every
## frame; stamped with the screen clock every time, a stopped hull's newest point is forever nought
## seconds old and the trail collapses to **a full-strength blob the width of the stroke, welded to its
## transom**. `_wake_stamp`'s stillness band is what stops it, and this row is what measures that band.
##
## ⚠⚠ **THIS ROW USED TO DRIVE PAST `GONE` AND ASSERT THE BLOCK SURVIVED IT** — 「flipping to `GONE`
## after `Rules.BOAT_LINGER_SEC` does not free it, nothing is erased there」. **That was the defect the
## user saw on the running screen on 2026-09-01** (「사라진 배가 물 위에 자국을 남긴다」): three black
## ellipses on open water with no hull under any of them. **The claim is reversed and the drive is now
## held inside the linger**, where a stopped hull genuinely is still on the board.
## ⚠ **The old row also could not run any more**: the trail needs `WAKE_LIFE_SEC` (4.0) of stillness to
## age out and a hull only stands for `BOAT_LINGER_SEC` (3.0). **A state the game no longer has is not
## a thing to measure.** `_a_gone_hull_takes_its_marks_with_it` below carries the other half.
func _a_hull_that_has_stopped_stops_marking_the_water(t) -> void:
	var pack := _boat_view()
	var fv: FieldView = pack["fv"]
	var b: Battle = pack["b"]
	var frame := Look.wake_every_sec() * 0.25
	# Sail it all the way in and stop the moment it lands — **inside the linger**, before it leaves.
	for _k in 400:
		if int(b.boat_state[0]) != Battle.BoatState.SAILING:
			break
		b.step(frame)
		fv._process(frame)
	t.eq(int(b.boat_state[0]), Battle.BoatState.ARRIVED,
		"배가 닿아서 서 있다 (자가 점검 — 아직 항해 중이면 아래가 공허하다)")

	var landed: float = fv._wake[0].z
	t.ok(landed >= 0.0, "그 선체의 블록이 살아 있다 — 접촉 자국을 그려야 한다 (자가 점검)")

	# ⚠ **Well inside `BOAT_LINGER_SEC`**, so the hull is still standing when the rows below are read.
	var held := 0.0
	while held < Rules.BOAT_LINGER_SEC * 0.5:
		b.step(frame)
		fv._process(frame)
		held += frame
	t.eq(int(b.boat_state[0]), Battle.BoatState.ARRIVED,
		"아직 안 사라졌다 (자가 점검 — 사라졌으면 아래는 GONE 을 재는 것이지 멈춤을 재는 게 아니다)")

	t.ok(absf(fv._wake[0].z - landed) < 1e-4,
		"안 움직인 고물은 다시 도장이 안 찍힌다 — 그 점이 %.2f초 째 나이를 먹고 있다"
			% (fv._sea_clock - fv._wake[0].z))
	t.ok(fv._sea_clock - fv._wake[0].z >= held - 1e-3,
		"그리고 그 나이가 서 있던 시간만큼 된다")


## **A hull that leaves the board takes its block with it.**
##
## ⚠ Without this the water keeps drawing a shadow round nothing — and the blocks are indexed by boat
## number, so the mark does not even drift: it sits exactly where the last boat was.
##
## ⚠ **This is the ARRAYS being emptied, which is the shape `setup` makes.** Nothing in play does it —
## a hull that leaves in play flips to `GONE` and its row stays. That half is the row below.
func _a_hull_that_leaves_the_board_takes_its_block_with_it(t) -> void:
	var pack := _boat_view()
	var fv: FieldView = pack["fv"]
	var b: Battle = pack["b"]
	t.eq(_live_hulls(fv), 1, "배가 한 척 있고 블록도 하나다 (자가 점검)")

	b.boat_pos = []
	b.boat_beach = PackedInt32Array()
	b.boat_riders = PackedInt32Array()
	fv._process(0.0)
	t.eq(_live_slots(fv), 0, "배가 사라지면 물 위의 자국도 통째로 사라진다")
	t.eq(fv._wake_last[0], -1.0, "그리고 그 블록의 마지막 기억 시각도 지워진다")


## **A hull that has flipped to `GONE` takes its marks with it.**
##
## ⚠⚠ **SEEN ON SCREEN, NOT DERIVED** (2026-09-01, the eyes on the running game: 「사라진 배가 물 위에
## 자국을 남긴다」). Three black ellipses were floating on open water at 178 초 with no hull under any of
## them. **`boat_pos` never shrinks** — 02-04 flips a row to `GONE` and erases nothing — so the count
## alone still called a vanished hull live and `_paint_wake` kept stamping its transom.
##
## ⚠ **The row above is NOT this row.** That one empties the arrays, which is the shape a `setup` makes;
## nothing in play ever does it. **This is the shape play actually makes**, and it was green throughout.
func _a_gone_hull_takes_its_marks_with_it(t) -> void:
	var pack := _boat_view()
	var fv: FieldView = pack["fv"]
	var b: Battle = pack["b"]
	t.eq(_live_hulls(fv), 1, "배가 한 척 있고 블록도 하나다 (자가 점검)")
	t.ok(_live_slots_of(fv, 0) > 0, "그 배가 물에 자국을 남기고 있다 (자가 점검)")

	# ⚠ **The state alone is flipped and the arrays are left whole**, which is exactly what
	# `_phase_boats` does. Emptying them instead would measure the row above and not this one.
	b.boat_state[0] = Battle.BoatState.GONE
	fv._process(0.0)

	t.eq(b.boat_pos.size(), 1, "선체 줄은 그대로 남아 있다 — 아무것도 안 지워진다 (자가 점검)")
	t.eq(_live_slots_of(fv, 0), 0, "사라진 배는 항적도 접촉 그림자도 안 남긴다")
	t.eq(fv._wake_last[0], -1.0, "그리고 그 블록의 마지막 기억 시각도 지워진다")


## **A new island opens with no trails on it.**
##
## ⚠ The same fact from the other side: `setup` is where an island opens, and a block that survived it
## would put island 1's first boat's trail under island 2's first boat.
func _a_new_island_opens_with_no_trails_on_it(t) -> void:
	var pack := _boat_view()
	var fv: FieldView = pack["fv"]
	t.ok(_live_slots(fv) > 0, "지금은 자국이 있다 (자가 점검)")

	var rows := _open(ARENA_W, ARENA_H)
	var fresh := _battle_of(rows, _army_of([]), [])
	fv.setup(fresh, fresh.army, rows)
	t.eq(_live_slots(fv), 0, "다음 섬이 열리면 이력이 비어 있다")
	t.eq(fv._wake_last[0], -1.0, "마지막 기억 시각도 비어 있다")


## **One wake, and every boat gets it.**
##
## ⚠⚠ **THE PLAYER'S OWN BOAT WAS GOING TO GET A DIFFERENT ONE AND THAT IS DEFERRED** (2026-08-30,
## the user: 「내배를 다르게 하는건 추후로 미루자」). **There is no boat kind, no wake style and no
## branch**, and this row is what says so at runtime rather than by reading the source: **two hulls,
## driven together, must fill at the same rate and remember at the same instant.** A branch on the hull
## number — the shape a per-boat-kind field would arrive as — separates the two and nothing else here
## would notice, because every other row in this file drives hull 0 alone.
func _every_hull_is_marked_the_same_way(t) -> void:
	var pack := _boat_view()
	var fv: FieldView = pack["fv"]
	var b: Battle = pack["b"]
	# A second hull, elsewhere on the water. **Injected**, because the second boat of an island is a
	# whole wave away — 「웨이브 하나는 배 한 척」 — and this row is not about when one is born.
	b.boat_pos.append(Vector2(4.0, 8.0))
	b.boat_beach.append(b.boat_beach[0])
	b.boat_stop.append(b.boat_stop[0])
	b.boat_state.append(b.boat_state[0])
	b.boat_riders.append(0)
	fv._process(0.0)
	t.eq(_live_hulls(fv), 2, "두 선체 다 물에 자국을 남긴다 (자가 점검)")
	t.eq(_live_slots_of(fv, 0), _live_slots_of(fv, 1),
		"첫 프레임에 두 블록이 같은 칸 수로 선다")

	# ⚠ **Both are moved by hand every frame**, so neither is 「still」 — a hull that has stopped stops
	# leaving marks, and two stopped hulls would agree for the wrong reason.
	var frame := Look.wake_every_sec() * 0.25
	for _k in 40:
		b.boat_pos[0] = (b.boat_pos[0] as Vector2) + Vector2(0.05, 0.0)
		b.boat_pos[1] = (b.boat_pos[1] as Vector2) + Vector2(0.0, 0.05)
		fv._process(frame)
	t.eq(_live_slots_of(fv, 0), Look.WAKE_SLOTS, "첫 블록이 꿉 찼다 (자가 점검)")
	t.eq(_live_slots_of(fv, 1), _live_slots_of(fv, 0),
		"둘째 블록도 같은 속도로 찼다 — 배마다 다른 자국이 아니다")
	t.eq(fv._wake_last[0], fv._wake_last[1], "그리고 같은 순간에 기억한다")
	t.ok(absf(fv._wake[0].z - fv._wake[Look.WAKE_SLOTS].z) < 1e-4,
		"두 선체의 0번 칸이 같은 시각을 든다 — 한 쪽만 멈춰 있지 않다")


## **Boats pile up and nothing ever removes one, so the thirteenth landing has no block.**
##
## ⚠⚠ **THIS IS A CEILING AND NOT A BUG, AND THE ROW EXISTS SO THAT IT IS A MEASURED ONE.** A hull
## stays where it landed, so an island that runs past twelve landings draws its thirteenth with dry
## water round it. ⚠ **The wave table reaches twelve at 40 분** where the deleted drip reached it at
## 5.6 분 — later, and still reached. **What must NOT happen is the loop running off the end
## of the array**, which is what a loop over the boats rather than over the slots would do.
func _boats_past_the_ceiling_are_dropped_and_the_rest_are_not(t) -> void:
	var pack := _boat_view()
	var fv: FieldView = pack["fv"]
	var b: Battle = pack["b"]
	var extra := Look.WAKE_HULLS + 2
	for k in range(1, extra):
		b.boat_pos.append(Vector2(2.0 + float(k), 3.0))
		b.boat_beach.append(b.boat_beach[0])
		b.boat_stop.append(b.boat_stop[0])
		b.boat_state.append(b.boat_state[0])
		b.boat_riders.append(0)
	t.eq(b.boat_pos.size(), extra, "판에 배가 %d 척 있다 (자가 점검)" % extra)

	fv._process(0.0)
	t.eq(fv._wake.size(), Look.WAKE_HULLS * Look.WAKE_SLOTS,
		"이력이 커지지 않았다 — 배열 밖으로 안 나간다")
	t.eq(_live_hulls(fv), Look.WAKE_HULLS,
		"열두 블록이 전부 찼고 그 이상은 없다 — 열셋째 배는 물이 모른다")


# == the colour =======================================================================================

## **The hull's shadow is the sea's own colour, darker and a little cooler.**
##
## ⚠ **A function and not a `Color` literal**, so moving `COL_WATER` carries it. ⚠⚠ **「Cooler」 is the
## half a darkness check cannot see**: dimming all three channels equally gives a grey shadow that
## passes every 「darker」 row, and what says water-in-shadow is the blue surviving best.
func _the_shadow_is_the_sea_darker_and_cooler(t) -> void:
	var sea := Look.COL_WATER
	var sh := Look.hull_shadow_colour()
	t.ok(sh.r < sea.r and sh.g < sea.g and sh.b < sea.b,
		"그림자가 세 채널 다 바다보다 어둡다")
	t.ok(sh.b / sea.b > sh.r / sea.r,
		"그리고 파랑이 빨강보다 덜 어두워졌다 — 회색이 아니라 차가운 쪽이다 (%.3f > %.3f)"
			% [sh.b / sea.b, sh.r / sea.r])
	# ⚠ A `Color` channel is a 32-bit float and the constant is a 64-bit one; the band is the format's.
	t.ok(absf(sh.a - Look.HULL_SHADOW_ALPHA) < 1e-6, "알파는 적어 둔 값 그대로다")
	t.ok(sh.b <= 1.0, "파랑이 1.0 을 안 넘는다 — 밝게 만들다 잘리지 않는다")


# == readers ==========================================================================================

## The shader's own text. **Read as a file and not through `Shader`**, so a compile that never happens
## headless cannot turn this into a permanent red.
func _shader_text() -> String:
	var f := FileAccess.open(SHADER_PATH, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


## `const int NAME = <n>;` out of GLSL text, or -1 when it is not there.
func _glsl_int(src: String, name: String) -> int:
	var key := "const int %s = " % name
	var at := src.find(key)
	if at < 0:
		return -1
	var tail := src.substr(at + key.length(), 16)
	var end := tail.find(";")
	if end < 0:
		return -1
	return int(tail.substr(0, end).strip_edges())


## `look.gd`'s own text. ⚠ **Read as a file**, so「the constant is deleted」 is measured on the source
## rather than on a `Look.` reference that would not compile if it were wrong.
func _look_text() -> String:
	var f := FileAccess.open("res://src/look.gd", FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


## **One GLSL function's body**, given the start of its signature — `"float wake_arm("` — or `""`.
##
## ⚠ **The signature and not the bare name**, because a call site is the name and a bracket too and
## the definition has to be told from the calls. ⚠ **Braces are counted**, so a body with an `if` in
## it comes back whole rather than ending at the first `}`.
func _glsl_func(src: String, sig: String) -> String:
	var at := src.find(sig)
	if at < 0:
		return ""
	var open := src.find("{", at)
	if open < 0:
		return ""
	var depth := 0
	for k in range(open, src.length()):
		var ch := src[k]
		if ch == "{":
			depth += 1
		elif ch == "}":
			depth -= 1
			if depth == 0:
				return src.substr(open + 1, k - open - 1)
	return ""


## How many times a piece of text stands in another.
func _count_in(hay: String, needle: String) -> int:
	var n := 0
	var at := hay.find(needle)
	while at >= 0:
		n += 1
		at = hay.find(needle, at + needle.length())
	return n


## Does the shader declare a uniform by exactly this name. ⚠ **`;`, `:` and `[` all count as an end**,
## because a `source_color` hint and an array length both sit between the name and the semicolon.
func _declares_uniform(src: String, name: String) -> bool:
	for line in src.split("\n"):
		var s := line.strip_edges()
		if not s.begins_with("uniform "):
			continue
		var body := s.substr(8).strip_edges()
		var sp := body.find(" ")
		if sp < 0:
			continue
		var rest := body.substr(sp + 1).strip_edges()
		for stop in [";", ":", "["]:
			var at := rest.find(str(stop))
			if at >= 0:
				rest = rest.substr(0, at)
		if rest.strip_edges() == name:
			return true
	return false


func _sea_material(fv: FieldView) -> ShaderMaterial:
	return fv._sea.material_override as ShaderMaterial


## How many slots in the whole history were ever written.
func _live_slots(fv: FieldView) -> int:
	var n := 0
	for k in fv._wake.size():
		if fv._wake[k].z >= 0.0:
			n += 1
	return n


## How many of one hull's own slots were written.
func _live_slots_of(fv: FieldView, hull: int) -> int:
	var n := 0
	for k in Look.WAKE_SLOTS:
		if fv._wake[hull * Look.WAKE_SLOTS + k].z >= 0.0:
			n += 1
	return n


## How many hulls have anything at all.
func _live_hulls(fv: FieldView) -> int:
	var n := 0
	for h in Look.WAKE_HULLS:
		if fv._wake[h * Look.WAKE_SLOTS].z >= 0.0:
			n += 1
	return n


# == fixtures =========================================================================================

func _open(w: int, h: int) -> Array:
	var rows := []
	for y in h:
		if y == 0 or y == h - 1:
			rows.append("~".repeat(w))
		else:
			rows.append("~" + ".".repeat(w - 2) + "~")
	return rows


func _army_of(types: Array) -> Army:
	var a := Army.new()
	for raw in types:
		var ty := int(raw)
		var slot := a.slot_of_type(ty)
		if slot < 0:
			slot = a.register_species(ty)
		a.recruit(slot)
	return a


func _battle_of(rows: Array, army: Army, spawns: Array) -> Battle:
	var g := Grid.new()
	g.load_rows(rows, [])
	var b := Battle.new()
	b.setup(g, army, spawns)
	return b


func _view_of(b: Battle, rows: Array) -> FieldView:
	var fv := FieldView.new()
	_created.append(fv)
	fv.setup(b, b.army, rows)
	return fv


## An arena with one boat on it, and the view that has painted it once.
func _boat_view(secs: float = -1.0) -> Dictionary:
	var rows := _open(ARENA_W, ARENA_H)
	var b := _battle_of(rows, _army_of([]), [])
	b.step(_first_hull_sec() if secs < 0.0 else secs)
	var fv := _view_of(b, rows)
	fv._process(0.0)
	return {"fv": fv, "b": b}


## **When the first hull of a run is born**, in seconds: one crossing before the first wave lands.
## ⚠⚠ **IT WAS FIVE SECONDS UNTIL 2026-09-03 AND IT IS NOW 461.75** — the wave table replaced the drip.
## `net_boats` holds the wave clock; this is a caller and not a second copy of it.
func _first_hull_sec() -> float:
	return Rules.WAVE_FIRST_SEC - Rules.BOAT_CROSSING_SEC
