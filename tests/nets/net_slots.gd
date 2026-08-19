extends RefCounted
## The summon slots, driven through the shell for real, with the two views spied on. `Game` goes into
## the live tree, `_ready()` builds its five children, frames are pumped so `_draw()` turns, and the
## arguments the hooks receive are read back against what the sim is holding at that instant.
##
## ⚠⚠ **EVERY INPUT ROW CALLS `game._unhandled_input(ev)` DIRECTLY — KEYS INCLUDED — AND NEVER
## `root.push_input()`.** Headless the window is 64x64, so the stretch transform is 0.05 and a click
## aimed at a widget arrives at roughly (2000, 6520), hits nothing, and raises no error at all. Keys
## carry no position and pass through `push_input` untouched, **which is exactly how half of an input
## suite stays green while the other half is dead** — so both halves go through one mechanism here.
##
## ⚠ **The beat rows drive `game._process(dt)` by hand with explicit dt literals.** A headless frame is
## ~6.9 ms and `pump_frames` cannot pin a 0.20 s cadence; and because no frame turns while they run,
## `field_view._fx` never ages under them, which is what makes "one refusal PER BEAT" countable.
##
## ⚠ The camera is parked per row: `zoom = 1.0` and `cam_px` set so the tile under test sits at a known
## screen point, so world px and screen px differ by exactly one translation. `_park_on` is the one
## place that conversion is written.


## Captures the three hooks this round reads. The rest are left as the REAL leaves on purpose — they
## draw for real headless, so the frame under test is the frame the game draws.
##
## ⚠ Each array is cleared at the top of `_draw` and then `super()` runs, so what is read back is
## exactly ONE frame's worth of calls rather than however many frames were pumped.
class FieldSpy extends FieldView:
	var draws := 0
	var tiles := []
	var rings := []
	var routes := []

	func _draw() -> void:
		tiles.clear()
		rings.clear()
		routes.clear()
		super()
		draws += 1

	func _paint_tile(rect: Rect2, fill: Color, line_colour: Color, line_width: float) -> void:
		tiles.append({"rect": rect, "fill": fill, "line": line_colour, "width": line_width})

	func _paint_ring(centre: Vector2, radius: float, colour: Color, width: float) -> void:
		rings.append({"centre": centre, "radius": radius, "colour": colour, "width": width})

	func _paint_route(points: PackedVector2Array, colour: Color, width: float) -> void:
		routes.append({"points": points, "colour": colour, "width": width})


class HudSpy extends HudView:
	var draws := 0
	var boxes := []
	var digits := []
	var bars := []

	func _draw() -> void:
		boxes.clear()
		digits.clear()
		bars.clear()
		super()
		draws += 1

	func _paint_slot_box(rect: Rect2, bg: Color, border_col: Color, border_w: float) -> void:
		boxes.append({"rect": rect, "bg": bg, "border": border_col, "width": border_w})

	func _paint_slot_digit(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		digits.append({"face": face, "at": at, "text": text, "fsize": fsize, "col": col})

	func _paint_slot_bar(back: Rect2, back_col: Color, fill: Rect2, fill_col: Color) -> void:
		bars.append({"back": back, "back_col": back_col, "fill": fill, "fill_col": fill_col})


func run(t) -> void:
	var game := Game.new()
	t.root.add_child(game)
	await t.pump_frames(2)

	# Title -> map -> island, through the door the OS uses. `net_shell` owns the assertions about that
	# path; here it is only how the shell reaches a planning screen.
	game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
	game._unhandled_input(_press(Look.map_node_pos_px(0)))
	game._process(Look.MAP_TRAVEL_SEC)
	t.ok(game.battle != null, "섬이 열렸다 (자가 점검)")

	# Swap in the spies and re-open, exactly as `net_shell` does: a spy starts with a null `battle`, so
	# a deleted wiring line would leave every capture below empty rather than merely different.
	for v: Node2D in [game.field_view, game.hud_view]:
		game.remove_child(v)
		v.queue_free()
	var fs := FieldSpy.new()
	var hs := HudSpy.new()
	game.field_view = fs
	game.hud_view = hs
	game.add_child(fs)
	game.add_child(hs)
	t.ok(fs.battle == null and hs.battle == null, "바꿔 끼운 스파이는 아직 아무것도 모른다 (자가 점검)")
	game._open_island()
	t.ok(fs.battle == game.battle and hs.battle == game.battle, "_open_island 가 둘 다 물렸다")

	# ⚠ The sim's own clock is stopped from here, so a captured frame and a value read after it are the
	# same instant. Every beat below is `game._process(dt)` called by hand.
	game.set_process(false)

	await _the_band_is_on_screen_from_frame_one(t, game, fs)
	_the_number_keys(t, game, hs)
	_the_press_and_the_beat(t, game, fs)
	_the_sweep(t, game, fs)
	_the_release(t, game, fs)
	_a_dry_slot(t, game, fs)
	_outside_the_band(t, game, fs)
	await _after_the_commit(t, game, fs, hs)
	_the_camera_still_answers(t, game, fs)
	await _the_aim_marks(t, game, fs)
	await _the_slot_row(t, game, fs, hs)
	_the_boxes_clear_the_army(t, game, fs)
	await _the_band_goes_with_the_boxes(t, game, fs, hs)
	await _the_three_lines_that_claimed_to_be_load_bearing(t, game, fs, hs)
	await _a_refused_key_flashes_as_well_as_shakes(t, game, hs)
	await _an_armed_slot_that_has_run_dry_is_not_green(t, game, fs, hs)

	# ⚠ **The swapped-in spies are NOT removed here.** `queue_free` on the parent takes its children
	# with it; pulling them out first leaves two orphaned `Node2D`s nothing owns, and the round reports
	# them on stderr as leaked RIDs — which this wrapper reads as a failure, correctly.
	t.root.remove_child(game)
	game.queue_free()


# -- V1 / V2 ---------------------------------------------------------------------------------------
## ⚠⚠ Mutation: delete the blend in `field_view`'s terrain pass ⇒ the two fills become **EQUAL**. That
## is the strongest shape a check can have: the behaviour VANISHES rather than diverging, so there is
## no value left that could accidentally still pass.
## ⚠ Mutation: gate the blend on `_summon_aim >= 0` ⇒ the second half of this row goes red, because the
## band has to be on screen the moment the island opens. **The region at frame one is what says a press
## belongs there** — the last round failed on 「뭐 어떻게 동작시키는지 전혀모르겠는데?」 with everything
## green.
func _the_band_is_on_screen_from_frame_one(t, game: Game, fs: FieldSpy) -> void:
	var pumped := 0
	while fs.draws < 1 and pumped < 20:
		await t.pump_frames(1)
		pumped += 1
	t.ok(fs.draws >= 1, "%d 프레임 만에 field_view 의 _draw 가 트리 위에서 진짜 돌았다 (자가 점검)" % pumped)
	t.eq(game._armed_slot, -1, "아직 아무 슬롯도 안 켰다 (자가 점검)")

	# The island opens at ZOOM_MIN with the whole map on screen, which is the frame this row is about.
	var g: Grid = game.battle.grid
	var wet := []
	var dry := []
	for raw: Dictionary in fs.tiles:
		var rect: Rect2 = raw["rect"]
		var tx := int(round(rect.position.x / Look.TILE_PX))
		var ty := int(round(rect.position.y / Look.TILE_PX))
		if tx < 0 or ty < 0 or tx >= g.w or ty >= g.h:
			continue
		var tile := g.tile_index(tx, ty)
		if g.water[tile] == 0:
			continue
		if g.can_summon_at(tile):
			wet.append(raw)
		else:
			dry.append(raw)
	# ⚠ The self-check FIRST: a frame holding only one kind would pass the comparison below vacuously.
	t.ok(wet.size() > 0, "이 프레임에 소환 가능한 물칸이 실제로 있다 (%d칸 — 자가 점검)" % wet.size())
	t.ok(dry.size() > 0, "그리고 소환 못 하는 물칸도 있다 (%d칸 — 자가 점검)" % dry.size())

	var wet_fill: Color = wet[0]["fill"]
	var dry_fill: Color = dry[0]["fill"]
	t.ok(wet_fill != dry_fill,
		"소환할 수 있는 물칸에 넘어간 색이 그렇지 않은 물칸과 다르다 (%s vs %s)"
			% [str(wet_fill), str(dry_fill)])
	t.eq(dry_fill, Look.COL_WATER, "그리고 띠 밖의 물은 그냥 바다색 그대로다")
	t.ok(wet_fill.g > Look.COL_WATER.g,
		"띠의 초록이 실제로 초록 쪽으로 갔다 (g %.3f > %.3f)" % [wet_fill.g, Look.COL_WATER.g])
	# The alpha the design bet on, pinned once and separately — the bound must not come from the thing
	# it measures.
	# ⚠ Compared with a tolerance and not with `eq`: a `Color` channel is a 32-bit float, so 0.35 comes
	# back as 0.34999999403954 and an exact compare would redden on the storage rather than on the value.
	t.ok(absf(Look.COL_SUMMON_BAND.a - 0.35) < 0.001,
		"띠의 알파는 0.35 다 — look.gd 가 재어 둔 실패값 0.18 의 두 배다 (자가 점검)")
	# Every band tile in the frame carries it, not just the one that was sampled.
	var missed := 0
	for raw: Dictionary in wet:
		if Color(raw["fill"]) == Look.COL_WATER:
			missed += 1
	t.eq(missed, 0, "띠 안의 모든 물칸이 넘어간 색을 받았다 — 한 칸만 칠해진 게 아니다")


# -- L1 / L2 / L3 ----------------------------------------------------------------------------------
## ⚠ Mutation L1: delete the `KEY_1`..`KEY_5` branch, or drop the `slot == _armed_slot` disarm.
## ⚠⚠ Mutation L2: delete the `echo` guard. OS auto-repeat on a held number key delivers
## `pressed = true, echo = true` many times a second and would toggle the arm silently.
## ⚠ Mutation L3: drop the unbound test, or pass `ok = true` to `note_chip`.
func _the_number_keys(t, game: Game, hs: HudSpy) -> void:
	t.eq(game._armed_slot, -1, "시작할 때는 아무것도 안 켜져 있다")
	game._unhandled_input(_key(KEY_1))
	t.eq(game._armed_slot, 0, "1번 키가 첫 슬롯을 켠다")
	t.eq(hs._armed, 0, "그리고 HUD 도 같은 슬롯을 안다 — 셸이 뷰에 안 알리면 켠 티가 안 난다")
	t.eq(game.field_view._summon_slot, 0, "필드도 같은 슬롯을 안다")

	# ⚠ L2 — the echo, on an ARMED slot, which is the state auto-repeat actually arrives in.
	game._unhandled_input(_key_echo(KEY_1))
	t.eq(game._armed_slot, 0, "눌린 채 반복되는 키(echo)는 슬롯을 뒤집지 않는다")

	game._unhandled_input(_key(KEY_2))
	t.eq(game._armed_slot, 1, "2번 키가 켜진 슬롯을 옮긴다")
	game._unhandled_input(_key(KEY_2))
	t.eq(game._armed_slot, -1, "같은 키를 다시 누르면 꺼진다")
	t.eq(hs._armed, -1, "HUD 도 꺼졌다")

	# ⚠ L3 — an unbound slot arms nothing AND says so. 「아무 일도 안 일어났다」 and 「게임이 안 듣는다」
	# are two different sentences and the shake is the only thing separating them.
	t.ok(not hs._chip_fx.has(HudView.CHIP_SLOT_BASE + 2), "3번 칸에 아직 표시가 없다 (자가 점검)")
	game._unhandled_input(_key(KEY_3))
	t.eq(game._armed_slot, -1, "비어 있는 3번 슬롯은 안 켜진다")
	t.ok(hs._chip_fx.has(HudView.CHIP_SLOT_BASE + 2), "그래도 그 칸에 거절 표시가 들어간다")
	t.ok(not bool((hs._chip_fx[HudView.CHIP_SLOT_BASE + 2] as Dictionary)["ok"]),
		"그 표시는 거절이다 — 수락이 아니다")
	t.eq(HudView.CHIP_START, 0, "시작 버튼은 0번 칸이다 (자가 점검)")
	t.eq(HudView.CHIP_SLOT_BASE, 1, "그리고 소환 칸은 1번부터다 (자가 점검)")


# -- L4 / L5 ---------------------------------------------------------------------------------------
## ⚠ Mutation L4: move the first summon into `_process` ⇒ the press does nothing until a frame turns,
## which is a 200 ms hole in a budget Swink puts at 100.
## ⚠ Mutation L5: fire one per frame (drop the accumulator), or read the cadence as 0.0.
func _the_press_and_the_beat(t, game: Game, fs: FieldSpy) -> void:
	var g: Grid = game.battle.grid
	var tile := _a_band_tile(g, 0)
	var at := _park_on(fs, g, tile)
	game._unhandled_input(_key(KEY_1))
	t.eq(game.battle.boats.size(), 0, "누르기 전에는 배가 없다 (자가 점검)")

	game._unhandled_input(_press(at))
	t.eq(game._summon_at, tile, "셸이 누른 칸을 그 바다 칸으로 읽었다 (자가 점검)")
	t.eq(game.battle.boats.size(), 1, "누른 그 프레임에 한 척이 나온다 — _process 가 돌기 전에")
	t.ok(game._summon_down, "그리고 누름이 이어지고 있다")

	# ⚠ The cadence is pinned ONCE, separately, as a self-check. The dt and the counts below are
	# literals — the bound must not come from the thing it measures.
	t.eq(Look.SLOT_HOLD_SEC, 0.20, "박자는 0.20초다 (아래 리터럴이 재는 값 — 자가 점검)")
	game._process(0.05)
	game._process(0.05)
	game._process(0.05)
	t.eq(game.battle.boats.size(), 1, "0.05초 세 번(0.15초)으로는 아직 한 척이다 — 프레임마다가 아니다")
	game._process(0.05)
	t.eq(game.battle.boats.size(), 2, "네 번째에 0.20초를 채우고 두 척이 된다")

	# A long frame does not swallow beats: `+=` and not `=`.
	game._process(0.60)
	t.eq(game.battle.boats.size(), 5, "0.60초 한 프레임은 세 박자다 — 긴 프레임이 박자를 삼키지 않는다")


# -- L6 --------------------------------------------------------------------------------------------
## ⚠ Mutation: use the press tile for every beat instead of the tile under the cursor ⇒ a swept hold
## stacks every body on one beach, which is exactly the picture the sweep exists to spread.
func _the_sweep(t, game: Game, fs: FieldSpy) -> void:
	game._open_island()
	var g: Grid = game.battle.grid
	var a_tile := _a_band_tile(g, 0)
	var b_tile := _a_band_tile(g, 40)
	t.ok(a_tile != b_tile, "두 바다 칸이 서로 다르다 (자가 점검)")

	game._unhandled_input(_key(KEY_1))
	var a_at := _park_on(fs, g, a_tile)
	game._unhandled_input(_press(a_at))
	t.eq(game.battle.boats.size(), 1, "첫 배가 A 칸에서 떴다 (자가 점검)")

	var b_at := _park_on(fs, g, b_tile)
	game._unhandled_input(_motion(b_at, Vector2(4.0, 4.0)))
	t.eq(game._summon_at, b_tile, "커서를 옮기자 셸이 B 칸을 읽었다 (자가 점검)")
	game._process(0.20)
	t.eq(game.battle.boats.size(), 2, "박자가 한 척 더 냈다")
	var second: Dictionary = game.battle.boats[1]
	var path: PackedVector2Array = second["path"]
	t.eq(path[0], g.tile_point(b_tile), "꾹 누른 채 커서를 옮기면 다음 배는 옮긴 자리에서 뜬다")
	t.ok(path[0] != g.tile_point(a_tile), "누른 자리가 아니다 — 쓸면 퍼지고 가만히 있으면 쌓인다")


# -- L7 --------------------------------------------------------------------------------------------
## ⚠ Mutation: never clear `_summon_down` on release, or disarm on release.
func _the_release(t, game: Game, fs: FieldSpy) -> void:
	game._open_island()
	var g: Grid = game.battle.grid
	var tile := _a_band_tile(g, 0)
	var at := _park_on(fs, g, tile)
	game._unhandled_input(_key(KEY_1))
	game._unhandled_input(_press(at))
	t.eq(game.battle.boats.size(), 1, "한 척 나왔다 (자가 점검)")

	game._unhandled_input(_release(at))
	t.ok(not game._summon_down, "떼면 누름이 끝난다")
	for _k in 5:
		game._process(0.20)
	t.eq(game.battle.boats.size(), 1, "떼고 나서 다섯 박자가 지나도 더 안 나온다")
	t.eq(game._armed_slot, 0, "그런데 슬롯은 켜진 채로 남는다 — 다음 누름은 키 없이 바로 시작한다")
	t.eq(game.field_view._summon_aim, -1, "조준하던 칸만 지워졌다")


# -- L8 --------------------------------------------------------------------------------------------
## ⚠ Mutation: fire the refusal every frame instead of every beat ⇒ a solid red disc at the cursor,
## which reads as an error rather than as 「더 없다」. ⚠ **Only `game._process` is pumped here, so no
## frame turns and `field_view._fx` never ages** — that is what makes the count exact.
func _a_dry_slot(t, game: Game, fs: FieldSpy) -> void:
	game._open_island()
	var g: Grid = game.battle.grid
	var tile := _a_band_tile(g, 0)
	var at := _park_on(fs, g, tile)
	game._unhandled_input(_key(KEY_1))
	game._unhandled_input(_press(at))
	# Five more beats empties the six melee. The slot is armed and wet when the hold starts and runs
	# dry under it — which is the only way a slot can be armed AND dry, because the key refuses to arm
	# a dry one.
	for _k in 5:
		game._process(0.20)
	t.eq(game.battle.boats.size(), 6, "여섯이 다 나갔다 (자가 점검)")
	t.eq(game.battle.slot_reserve_ids(0).size(), 0, "슬롯이 말랐다 (자가 점검)")

	var before := _refusals(fs)
	game._process(0.20)
	t.eq(_refusals(fs) - before, 1, "마른 슬롯은 한 박자에 거절 표시 하나를 낸다")
	game._process(0.20)
	game._process(0.20)
	t.eq(_refusals(fs) - before, 3, "세 박자면 셋이다 — 프레임마다가 아니다")
	t.eq(game.battle.boats.size(), 6, "그리고 배는 안 늘었다")
	t.ok(game._summon_down, "꾹 누른 것은 안 끝난다 — 마른 것이 손을 놓게 하지는 않는다")


# -- L9 --------------------------------------------------------------------------------------------
## ⚠ Mutation: drop the `can_summon_at` test in `Battle.summon` ⇒ a press in open ocean places a boat
## the route cannot reach.
func _outside_the_band(t, game: Game, fs: FieldSpy) -> void:
	game._open_island()
	var g: Grid = game.battle.grid
	var far := -1
	for tile in g.w * g.h:
		if g.water[tile] != 0 and not g.can_summon_at(tile):
			far = tile
			break
	t.ok(far >= 0, "띠 밖의 물칸을 찾았다 (자가 점검)")
	var at := _park_on(fs, g, far)
	game._unhandled_input(_key(KEY_1))
	var before := _refusals(fs)
	game._unhandled_input(_press(at))
	t.eq(game.battle.boats.size(), 0, "띠 밖을 누르면 배가 안 생긴다")
	t.eq(_refusals(fs) - before, 1, "그리고 누른 그 프레임에 거절 표시가 하나 뜬다")


# -- L10 / V9 --------------------------------------------------------------------------------------
## ⚠ Mutation: remove any one of the three commit gates (`Battle.summon`'s `_committed`, the key
## branch's, the beat's) or `hud_view._draw`'s. **These are seams 1–4 of `sea-summon`'s OPEN question
## 1** — a live-fire version deletes them deliberately, and this row is what says they are all still
## here today.
func _after_the_commit(t, game: Game, fs: FieldSpy, hs: HudSpy) -> void:
	game._open_island()
	var g: Grid = game.battle.grid
	var tile := _a_band_tile(g, 0)
	var at := _park_on(fs, g, tile)
	game._unhandled_input(_key(KEY_1))
	game._unhandled_input(_press(at))
	t.eq(game.battle.boats.size(), 1, "확정할 배가 하나 있다 (자가 점검)")

	await t.pump_frames(2)
	# ⚠ Against the TABLE, never against a number. A third binding is one line in `rules.gd`.
	t.eq(hs.boxes.size(), Rules.summon_slot_count(),
		"슬롯 줄은 확정 전에 표가 정한 만큼 그려진다 (%d칸)" % Rules.summon_slot_count())

	# ⚠⚠ **The press is deliberately NOT released before the commit.** Released first, `_summon_down`
	# is already false and the beat's own commit gate is never reached at all — measured: with the
	# release in, deleting `not battle.committed()` from the beat left this whole row green.
	t.ok(game.battle.commit(), "확정했다 (자가 점검)")
	t.ok(game._summon_down, "그리고 손은 아직 누른 채다 — 박자의 문이 실제로 시험된다 (자가 점검)")
	game._unhandled_input(_key(KEY_2))
	t.eq(game._armed_slot, 0, "확정한 뒤에는 키가 슬롯을 못 옮긴다")
	var before := game.battle.boats.size()
	game._unhandled_input(_press(at))
	t.eq(game.battle.boats.size(), before, "누름도 아무것도 안 만든다")
	# ⚠⚠ **The refusal count is read as well as the boat count, and that is what makes the beat's own
	# gate measurable.** `Battle.summon` refuses after the commit anyway (seam #1), so a beat that kept
	# running would create no boat — it would blink a refusal mark at the cursor every 0.20 s for the
	# whole fight instead. Measured: without this line, deleting `not battle.committed()` from the beat
	# was green.
	var marks := _refusals(fs)
	game._process(0.20)
	game._process(0.20)
	t.eq(game.battle.boats.size(), before, "박자도 아무것도 안 만든다")
	t.eq(_refusals(fs), marks, "거절 표시조차 안 뜬다 — 박자 자체가 안 돈다")
	await t.pump_frames(2)
	t.eq(hs.boxes.size(), 0, "그리고 확정 뒤에는 슬롯 줄이 한 번도 안 그려진다 — 싸울 때 글자는 둘뿐이다")


# -- L11 -------------------------------------------------------------------------------------------
## ⚠ Mutation: gate `_on_wheel` on `_armed_slot < 0`. **This is the row that stops every "after the
## commit nothing answers" and "armed slots consume the press" row above from being satisfied by a
## screen that does nothing at all.**
func _the_camera_still_answers(t, game: Game, fs: FieldSpy) -> void:
	game._open_island()
	fs.zoom = Look.ZOOM_MIN
	fs.cam_px = Vector2.ZERO
	game._unhandled_input(_key(KEY_1))
	t.eq(game._armed_slot, 0, "슬롯을 켰다 (자가 점검)")
	var before := fs.zoom
	game._unhandled_input(_wheel(Vector2(640.0, 360.0), true))
	t.ok(fs.zoom > before, "슬롯이 켜져 있어도 휠은 여전히 돌아간다")

	# And the pan comes back the moment the slot is disarmed — the mitigation for question 8, measured
	# rather than promised.
	fs.zoom = 1.0
	fs.cam_px = Vector2(300.0, 300.0)
	fs.position = -fs.cam_px
	game._unhandled_input(_key(KEY_1))
	t.eq(game._armed_slot, -1, "같은 키로 껐다 (자가 점검)")
	var cam_before: Vector2 = fs.cam_px
	game._unhandled_input(_press(Vector2(640.0, 360.0)))
	game._unhandled_input(_motion(Vector2(640.0, 360.0), Vector2(120.0, 80.0)))
	game._unhandled_input(_release(Vector2(760.0, 440.0)))
	t.ok(fs.cam_px != cam_before, "끄면 화면 끌기가 돌아온다")


# -- V3 / V4 / V5 ----------------------------------------------------------------------------------
## ⚠ Mutation V3: draw the ring at the pressed tile instead of at the derived landing.
## ⚠ Mutation V4: draw a two-point straight line. **`net_draw_leaf`'s whole-array shape check cannot
## see a straightened polyline** — that is measured, and it is why this is a runtime row.
## ⚠ Mutation V5: drop the dry test ⇒ a ring and a route appear for a slot that can place nothing.
func _the_aim_marks(t, game: Game, fs: FieldSpy) -> void:
	game._open_island()
	var g: Grid = game.battle.grid
	# A BENT route: two hops out, so the polyline is the pressed tile, the beaching tile and the
	# landing — three points. A straight-line mutation collapses it to two.
	var bent := -1
	for tile in g.w * g.h:
		if g.can_summon_at(tile) and g.summon_route(tile).size() > 2:
			bent = tile
			break
	t.ok(bent >= 0, "두 점보다 긴 항로를 내는 바다 칸을 찾았다 (자가 점검)")

	var at := _park_on(fs, g, bent)
	game._unhandled_input(_key(KEY_1))
	game._unhandled_input(_motion(at, Vector2(2.0, 2.0)))
	t.eq(game.field_view._summon_aim, bent, "누르기 전에 이미 조준이 잡혔다 (자가 점검)")
	await t.pump_frames(2)
	t.eq(game.battle.boats.size(), 0, "계획이 비어 있다 — 이 프레임의 링과 항로는 조준의 것뿐이다 (자가 점검)")

	var marks := _aim_rings(fs)
	t.eq(marks.size(), 1, "조준 링이 정확히 하나 그려진다")
	var landing := g.summon_landing_of(bent)
	t.eq(Vector2(marks[0]["centre"]), Look.tile_point_px(g.tile_point(landing)),
		"조준 링은 누른 칸이 아니라 도출된 상륙지 위에 있다")
	t.ok(Vector2(marks[0]["centre"]) != Look.tile_point_px(g.tile_point(bent)),
		"그리고 그 둘은 실제로 다른 자리다 (자가 점검)")
	t.eq(Color(marks[0]["colour"]), Look.COL_WIN, "띠 안이므로 수락 색이다")

	var want := PackedVector2Array()
	for wp in g.summon_route(bent):
		want.append(Look.tile_point_px(wp))
	var drawn := _routes_from(fs, Look.tile_point_px(g.tile_point(bent)))
	t.eq(drawn.size(), 1, "그 칸에서 출발하는 항로가 하나 그려진다")
	t.eq(PackedVector2Array(drawn[0]["points"]), want,
		"그려지는 항로가 배가 실제로 갈 항로와 점 하나까지 같다")
	t.ok(want.size() > 2, "그 항로는 두 점보다 길다 (%d점 — 자가 점검)" % want.size())

	# ⚠ V5 — the same aim on a DRY slot draws neither. The absence is the answer, and it arrives
	# before the press instead of after it.
	# ⚠ **Drained at a DIFFERENT tile than the one being aimed at**, and that is not tidiness: an
	# uncommitted boat sits at its own summon tile, so six boats born at `bent` would each draw a
	# remaining route starting exactly where the aim's route starts — and the row would count six.
	var drain := -1
	for tile in g.w * g.h:
		if g.can_summon_at(tile) and tile != bent:
			drain = tile
			break
	t.ok(drain >= 0 and drain != bent, "배를 뺄 다른 바다 칸을 찾았다 (자가 점검)")
	for _k in 6:
		game.battle.summon(0, drain)
	t.eq(game.battle.slot_reserve_ids(0).size(), 0, "슬롯을 비웠다 (자가 점검)")
	await t.pump_frames(2)
	t.eq(_aim_rings(fs).size(), 0, "마른 슬롯은 조준 링을 안 그린다")
	t.eq(_routes_from(fs, Look.tile_point_px(g.tile_point(bent))).size(), 0,
		"항로도 안 그린다 — 없다는 게 대답이다")


# -- V6 / V7 / V8 ----------------------------------------------------------------------------------
## ⚠ Mutation V6: draw the fill at the back's full width ⇒ nothing on screen ever goes down, which is
## half of why the last game died.
## ⚠ Mutation V7: draw a bar for unbound slots ⇒ 「아직 아무것도 안 넣었다」 and 「다 내보냈다」 become
## one picture.
## ⚠ Mutation V8: pass the resting width in both branches ⇒ the armed box loses one of its two
## channels and the fill has to carry the read alone.
func _the_slot_row(t, game: Game, fs: FieldSpy, hs: HudSpy) -> void:
	game._open_island()
	var g: Grid = game.battle.grid
	var tile := _a_band_tile(g, 0)
	var at := _park_on(fs, g, tile)
	game._unhandled_input(_key(KEY_1))
	await t.pump_frames(2)

	# V8 — two channels, and the border difference clears the snap floor.
	t.eq(hs.boxes.size(), Rules.summon_slot_count(),
		"슬롯 상자가 표가 정한 수만큼 그려진다 (%d개)" % Rules.summon_slot_count())
	# The literal, once and on the TABLE itself, so the row above cannot move both sides together.
	t.eq(Rules.SUMMON_SLOTS.size(), 2, "그리고 표에는 두 줄이 있다 (리터럴 — 사용자의 「슬럿 2개로 시작」)")
	var armed := _box_at(hs, 0)
	var resting := _box_at(hs, 1)
	t.eq(float(armed["width"]), Look.PRESS_HOVER_BORDER_WIDTH_PX, "켜진 상자의 테두리가 두꺼운 쪽이다")
	t.eq(float(resting["width"]), Look.PRESS_BORDER_WIDTH_PX, "안 켜진 상자는 쉬는 두께다")
	t.ok(float(armed["width"]) - float(resting["width"]) > 2.0,
		"둘의 차이가 스냅 바닥 2.0 보다 크다 — 안 그러면 켠 것이 화면에 안 닿는다")
	t.eq(Color(armed["bg"]), Look.COL_START, "그리고 채움 색도 다르다 — 두 갈래로 말한다")
	t.ok(Color(resting["bg"]) != Look.COL_START, "안 켜진 상자는 그 색이 아니다")
	t.eq(hs.digits.size(), Rules.summon_slot_count(), "숫자도 상자마다 하나씩 그려진다")
	t.eq(str(hs.digits[0]["text"]), "1", "첫 상자에 1 이 적혀 있다")
	t.eq(str(hs.digits[Rules.summon_slot_count() - 1]["text"]),
		str(Rules.summon_slot_count()), "마지막 상자에 그 번호가 적혀 있다")
	# The glyph rides the box: a rect origin plus a non-zero offset, never the rect's own corner.
	t.eq(Vector2(hs.digits[0]["at"]), Look.slot_rect_px(0).position + Look.HUD_SLOT_TEXT_OFFSET_PX,
		"숫자가 상자 안에 놓였다 — 상자의 원점에 그린 글자는 놓인 적이 없는 글자다")

	# V7 — the bars. Two bound slots draw one each; three unbound slots draw none at all.
	t.eq(hs.bars.size(), 2, "빈 슬롯 3·4·5 에는 막대가 아예 없다")

	# V6 — one body out, and the bar drops exactly one sixth.
	var back: Rect2 = _bar_at(hs, 0)["back"]
	var full: Rect2 = _bar_at(hs, 0)["fill"]
	t.eq(full.size.x, back.size.x, "내보내기 전에는 막대가 가득이다 (자가 점검)")
	t.eq(Rules.START_MELEE, 6, "시작 근접 병력이 여섯이다 (아래 6분의 5 가 재는 값 — 자가 점검)")
	game._unhandled_input(_press(at))
	game._unhandled_input(_release(at))
	t.eq(game.battle.boats.size(), 1, "한 척 내보냈다 (자가 점검)")
	await t.pump_frames(2)
	var after: Rect2 = _bar_at(hs, 0)["fill"]
	t.ok(absf(after.size.x - back.size.x * 5.0 / 6.0) < 0.01,
		"한 척 내보내면 막대가 정확히 6분의 5 로 줄어든다 (%.2f / %.2f)" % [after.size.x, back.size.x])

	# V7 again — an exhausted slot keeps an EMPTY RAIL, which is the only thing separating
	# 「다 내보냈다」 from 「아직 아무것도 안 넣었다」.
	for _k in 5:
		game.battle.summon(0, tile)
	t.eq(game.battle.slot_reserve_ids(0).size(), 0, "슬롯을 다 비웠다 (자가 점검)")
	await t.pump_frames(2)
	t.eq(hs.bars.size(), 2, "다 내보낸 슬롯도 여전히 막대를 하나 그린다")
	t.eq(Rect2(_bar_at(hs, 0)["fill"]).size.x, 0.0, "그 막대의 채움은 0 이다 — 빈 레일만 남는다")
	t.eq(Rect2(_bar_at(hs, 0)["back"]), back, "레일 자체는 그대로 있다")


# -- L12 -------------------------------------------------------------------------------------------
## ⚠ Mutation: make `slot_row_origin_x_px` a constant again ⇒ the row stops touching the margin the
## moment the slot table changes length, which is the half of 「확장가능」 the layout owns.
func _the_boxes_clear_the_army(t, game: Game, fs: FieldSpy) -> void:
	game._open_island()
	fs.zoom = Look.ZOOM_MIN
	fs.cam_px = Vector2.ZERO
	# `_clamp_cam` centres both axes at ZOOM_MIN — the state `setup()` actually produces, which is the
	# framing the stack's screen position has to be measured in.
	fs._clamp_cam()
	fs.position = Vector2(-fs.cam_px.x * fs.zoom, -fs.cam_px.y * fs.zoom)

	var boxes: Array[Rect2] = []
	for i in Rules.summon_slot_count():
		boxes.append(Look.slot_rect_px(i))
	var screen := Rect2(Vector2.ZERO, Look.viewport_size_px())
	for i in boxes.size():
		t.ok(boxes[i].size.x > 0.0 and boxes[i].size.y > 0.0, "%d번 상자에 넓이가 있다" % i)
		t.ok(screen.encloses(boxes[i]), "%d번 상자가 화면 안에 든다" % i)
		for j in range(i + 1, boxes.size()):
			t.ok(not boxes[i].intersects(boxes[j]), "%d번과 %d번 상자가 안 겹친다" % [i, j])
	# ⚠ `boxes[4]` was written when the row was five long. Derived from the table's own size now, so a
	# third binding does not turn this into an index error.
	t.eq(boxes[boxes.size() - 1].end.x, Look.VIEWPORT_W_PX - Look.HUD_MARGIN_PX,
		"마지막 상자의 오른쪽 끝이 HUD 여백에 정확히 닿는다 (1268)")
	# ⚠⚠ **THE 「확장가능」 HALF THE LAYOUT OWNS, and it needs a cross-check rather than a tautology.**
	# `slot_row_origin_x_px()` is right-anchored, so "the last box touches the margin" is true by
	# construction and proves nothing on its own. What DOES prove the formula is that the same
	# arithmetic at FIVE slots reproduces **956.0** — the number that was measured by hand and stored as
	# a constant back when the row was five long. A formula that could not re-derive the old layout
	# would be a different layout wearing the same claim.
	t.eq(Look.VIEWPORT_W_PX - Look.HUD_MARGIN_PX
			- (5.0 * Look.HUD_SLOT_SIZE_PX.x + 4.0 * Look.HUD_SLOT_GAP_PX), 956.0,
		"같은 식이 다섯 칸에서는 옛 상수 956 을 그대로 내놓는다 — 식이 옛 배치를 재현한다")
	t.eq(boxes[0].position.x, 1148.0,
		"두 칸에서는 1148 에서 시작한다 (1280 - 12 - (2*56 + 8) — 손으로 센 리터럴)")
	t.ok(boxes[0].position.x != 956.0,
		"그리고 옛 상수 자리가 아니다 — 표가 줄자 줄이 실제로 움직였다 (자가 점검)")

	# ⚠⚠ **THE HALF THAT COMPARED THE BOXES WITH THE HARBOUR STACK IS DELETED, SUBJECT AND ALL.**
	# It read `fs.idle_soldier_rect(i)` for every reserve body and asserted no slot box overlapped the
	# stack — the reason the row sits in the bottom-RIGHT corner at all. **The stack is
	# deleted** (*"ㅇㅇ 지워줘"*) and `idle_soldier_rect` with it, so there is nothing left to overlap.
	# ⚠ **The corner choice is now unforced and nothing measures it.** Bottom-right was picked to clear
	# a thing that no longer exists; the boxes stay there because moving them is a decision nobody has
	# made, not because a check still holds them.


# -- helpers ---------------------------------------------------------------------------------------

## The `n`-th summonable tile on this grid, in row-major order. A stable pick rather than a hand-typed
## index, so a fixture stays valid if the rows are ever edited.
# -- the bounce -------------------------------------------------------------------------------------

## ⚠⚠ **`_arming_mid_drag_cancels_the_drag` IS DELETED, SUBJECT AND ALL.** It measured the collision
## between arming a slot and a soldier drag in flight — the signature fake round 2 fixed, where the
## ring froze on one tile (1461) while `battle.send` was handed another (146). **The drag is deleted**
## (the user, pointing at the harbour markers and the reserve stack: *"ㅇㅇ 지워줘"*), so there is no
## gesture left to collide with and no `_drag_soldier` to cancel. `game.gd::_arm` lost those two lines
## in the same edit and says so on the spot.
##
## ⚠ **It is deleted rather than repaired.** A check rewritten to survive the deletion of its own
## subject is how coverage drops without anybody noticing — the row would have gone on passing while
## measuring nothing at all.


## ⚠⚠ **THE BAND SURVIVED THE COMMIT UNDER A COMMENT SAYING IT COULD NOT.** `field_view`'s blend is
## gated on `can_summon_at` and had no `battle.committed()` test, directly under a paragraph reading
## *"the green cannot promise a tile the sim then denies"*. After the commit `Battle.summon` refuses
## everything and `hud_view` stops drawing the five boxes — and the sea went on wearing **the only mark
## on the field that says 「your hand goes here」** for the rest of the fight.
##
## ⚠⚠ **The damning half: adding the test ran the whole round GREEN at 17 nets / 2508 checks.** Not one
## check could tell the two behaviours apart. **The band goes with the boxes** — the same rule the
## deleted coast wash was trusted for, applied on the other side of the commit — and this is the row
## that makes the choice a fact instead of a preference.
func _the_band_goes_with_the_boxes(t, game: Game, fs: FieldSpy, hs: HudSpy) -> void:
	game._open_island()
	var g: Grid = game.battle.grid
	fs.zoom = Look.ZOOM_MIN
	fs.cam_px = Vector2.ZERO
	fs._clamp_cam()
	fs.position = fs._compose_position()
	fs.scale = Vector2(fs.zoom, fs.zoom)

	await t.pump_frames(2)
	var before := _band_fills(fs, g)
	t.ok(before > 0, "확정 전에는 띠가 실제로 칠해져 있다 (%d칸 — 자가 점검)" % before)
	t.eq(hs.boxes.size() > 0, true, "그리고 슬롯 상자도 그려진다 (자가 점검)")

	t.ok(game.battle.send(0, int(_sendable_tile(g))) >= 0, "확정할 배를 하나 놓았다 (자가 점검)")
	t.ok(game.battle.commit(), "확정했다 (자가 점검)")
	hs.boxes.clear()
	await t.pump_frames(2)
	t.eq(hs.boxes.size(), 0, "확정 뒤 슬롯 상자가 사라진다 (자가 점검 — 비교 상대다)")
	t.eq(_band_fills(fs, g), 0,
		"그리고 띠도 같이 사라진다 — 손이 갈 데가 없어진 뒤에도 바다에 표시가 남으면 그게 거짓말이다")
	# The floor: the water is still being drawn, so the zero above is "the blend went" and not "the
	# terrain pass stopped".
	var water := 0
	for raw: Dictionary in fs.tiles:
		if Color(raw["fill"]) == Look.COL_WATER:
			water += 1
	t.ok(water > 0, "물칸 자체는 여전히 그려진다 (%d칸) — 사라진 것은 덧칠뿐이다" % water)


## ⚠⚠ **THREE LINES CLAIMED TO BE LOAD-BEARING AND WERE GREEN WHEN DELETED.** A comment asserting a
## line matters when nothing measures it is the same class of lie as a fake net — and the control says
## this is not blanket blindness: deleting `_disarm()` from `_open_island` reddens 23 checks. So each
## of the three is driven here rather than argued about.
func _the_three_lines_that_claimed_to_be_load_bearing(t, game: Game, fs: FieldSpy, hs: HudSpy) -> void:
	# (1) `_summon_down = false` inside the `_hold_sec` gate in `game.gd::_unhandled_input`. Its own
	# comment says suppressing only the MOTION events leaves the flag alive, so the very next motion
	# after the hold ends resumes a gesture the plan says was cancelled. Driven: hold, deliver an
	# event, end the hold, and beat.
	game._open_island()
	var g: Grid = game.battle.grid
	var tile := _a_band_tile(g, 0)
	var at := _park_on(fs, g, tile)
	game._unhandled_input(_key(KEY_1))
	game._unhandled_input(_press(at))
	t.ok(game._summon_down, "누른 채다 (자가 점검)")
	var made := game.battle.boats.size()

	game._hold_sec = 1.0
	game._unhandled_input(_motion(at, Vector2(2.0, 2.0)))
	t.ok(not game._summon_down, "붙들려 있는 동안 도착한 사건 하나가 누름을 취소한다")
	game._hold_sec = 0.0
	for _k in 5:
		game._process(0.20)
	t.eq(game.battle.boats.size(), made,
		"그래서 붙듦이 끝난 뒤 다섯 박자가 지나도 더 안 나온다 — 억누른 게 아니라 취소한 것이다")
	t.eq(game._armed_slot, 0, "슬롯은 켜진 채로 남는다 — 켜는 건 모드고 누름이 몸짓이다")

	# (2) `_summon_slot` / `_summon_aim = -1` in `field_view.setup`. Without it the island that just
	# closed leaves its aim behind, and the slot id names a body in a roster that has moved on.
	game._unhandled_input(_press(at))
	t.ok(fs._summon_slot >= 0 and fs._summon_aim >= 0,
		"화면이 슬롯 %d 로 칸 %d 를 조준하고 있다 (자가 점검)" % [fs._summon_slot, fs._summon_aim])
	fs.setup(game.battle, game.battle.army, Islands.rows_of(0))
	t.eq(fs._summon_slot, -1, "setup 이 조준한 슬롯을 지운다 — 섬이 바뀌면 조준도 같이 간다")
	t.eq(fs._summon_aim, -1, "조준하던 칸도 지운다")

	# (3) `_armed = -1` in `hud_view.bind`. Same shape one view over: a box left green on the new
	# island would say a key is armed that the shell has already forgotten.
	hs.set_armed(2)
	t.eq(hs._armed, 2, "HUD 가 2번을 켠 채다 (자가 점검)")
	hs.bind(game.battle)
	t.eq(hs._armed, -1, "bind 가 켜진 슬롯을 지운다 — 새 섬은 아무것도 안 켜진 채로 열린다")
	# The floor under all three: the shell itself is still armed, so none of the three zeroes above is
	# 「everything is -1 anyway」.
	t.eq(game._armed_slot, 0, "그동안 셸의 팔은 여전히 켜져 있다 — 위의 세 -1 이 전부 같은 사실이 아니다")
	game._unhandled_input(_key(KEY_1))


## ⚠⚠ **A REFUSED KEY SHOOK AND NEVER FLASHED — one channel where the design asked for two.**
## `_chip_offset` served the start button AND the slot boxes from the day the slots shipped, while the
## TINT was written inline in `_chip_colour` and reached the start button alone. So the box that barked
## looked exactly like the box that did not, and only its position said otherwise.
##
## ⚠ **Both channels are read in the same frame**, because that is the pair `combat-juice` item 8 is: a
## box that only moves reads as a wobble and a box that only changes colour reads as a state.
##
## ⚠⚠ **THE FIXTURE CHANGED WITH THE TABLE.** It used to press `KEY_3` on slot 2, which was
## `SUMMON_UNBOUND` — and the user cut the three unbound slots (*"슬럿 2개로 시작 확장가능"*), so every
## slot in the table is bound now. `_on_summon_key` refuses on **「unbound OR dry」**, which is one
## sentence to the player and one call (`slot_reserve_ids(slot).is_empty()`), so the DRY arm is what
## the refusal is driven through: slot 1 is drained first and then its key is pressed.
func _a_refused_key_flashes_as_well_as_shakes(t, game: Game, hs: HudSpy) -> void:
	game._open_island()
	var g: Grid = game.battle.grid
	var drain := _a_band_tile(g, 0)
	# Slot 1 (ranged) is drained rather than slot 0, so the accepted-press control at the bottom of this
	# row still has a wet slot to arm.
	var spent := 0
	while not game.battle.slot_reserve_ids(1).is_empty() and spent < 40:
		t.ok(game.battle.summon(1, drain) >= 0, "말리기 전에는 나간다 (자가 점검)")
		spent += 1
	t.ok(game.battle.slot_reserve_ids(1).is_empty(), "2번 슬롯이 말랐다 (자가 점검)")
	await t.pump_frames(2)
	t.eq(hs.boxes.size(), Rules.summon_slot_count(), "상자가 표가 정한 수만큼 그려진다 (자가 점검)")
	var rest_bg := Color(hs.boxes[1]["bg"])
	var rest_pos: Vector2 = (hs.boxes[1]["rect"] as Rect2).position
	t.eq(rest_bg, Look.COL_SLOT_OFF, "쉴 때 그 상자는 안 눌리는 색이다 (자가 점검)")
	t.eq(rest_pos, Look.slot_rect_px(1).position, "그리고 제자리에 있다 (자가 점검)")

	game._unhandled_input(_key(KEY_2))
	t.eq(game._armed_slot, -1, "마른 슬롯은 안 켜진다 (자가 점검)")
	await t.pump_frames(1)
	t.eq(hs.boxes.size(), Rules.summon_slot_count(), "거절한 프레임에도 같은 수가 그려진다 (자가 점검)")
	var hit_bg := Color(hs.boxes[1]["bg"])
	var hit_pos: Vector2 = (hs.boxes[1]["rect"] as Rect2).position

	# Channel 1 — it moved, and by no more than the constant that owns the amplitude.
	var shift := hit_pos.distance_to(rest_pos)
	t.ok(shift > 0.0, "거절한 상자가 흔들렸다 (%.3f px)" % shift)
	t.ok(shift <= Look.REFUSE_SHAKE_PX + 0.01,
		"그리고 REFUSE_SHAKE_PX 를 안 넘는다 (%.3f <= %.1f)" % [shift, Look.REFUSE_SHAKE_PX])

	# Channel 2 — it also changed colour, toward COL_LOSE and away from where it was resting.
	t.ok(hit_bg != rest_bg, "그리고 색도 바뀌었다 — 흔들리기만 하면 채널이 하나뿐이다 (%s -> %s)"
		% [str(rest_bg), str(hit_bg)])
	t.ok(hit_bg.r > rest_bg.r,
		"거절 색(COL_LOSE) 쪽으로 갔다 (r %.3f > %.3f)" % [hit_bg.r, rest_bg.r])
	# The floor: an ACCEPTED press must NOT do this, or "it flashed" would be true of everything.
	game._unhandled_input(_key(KEY_1))
	await t.pump_frames(1)
	t.eq(game._armed_slot, 0, "1번은 받아들여졌다 (자가 점검)")
	t.eq((hs.boxes[0]["rect"] as Rect2).position, Look.slot_rect_px(0).position,
		"받아들여진 상자는 안 흔들린다 — 두 답이 같은 말을 하지 않는다")
	game._unhandled_input(_key(KEY_1))


## ⚠⚠ **AN ARMED SLOT THAT HAS RUN DRY STAYED GREEN.** `_slot_colour` tested `armed` before `empty`,
## so a slot armed with one body left kept `COL_START` the moment that body went out — **the box read
## 「ready」 for a key that will now bark.** It is the only way a slot can be armed AND dry, because the
## key refuses to arm a dry one, and it is exactly the state a player reaches by holding the button.
##
## ⚠ **The BORDER still says armed, and that is the point of the reorder rather than a consolation.**
## `hud_view`'s own paragraph says neither channel carries the read alone: the fill says what will come
## out, the border says which slot the key is on. Both are asserted here.
func _an_armed_slot_that_has_run_dry_is_not_green(t, game: Game, fs: FieldSpy, hs: HudSpy) -> void:
	game._open_island()
	var g: Grid = game.battle.grid
	var tile := _a_band_tile(g, 0)
	var at := _park_on(fs, g, tile)
	game._unhandled_input(_key(KEY_1))
	await t.pump_frames(2)
	t.eq(Color(hs.boxes[0]["bg"]), Look.COL_START, "켜자마자 상자가 초록이다 (자가 점검)")

	game._unhandled_input(_press(at))
	for _k in 5:
		game._process(0.20)
	t.eq(game.battle.slot_reserve_ids(0).size(), 0, "여섯이 다 나가 슬롯이 말랐다 (자가 점검)")
	t.eq(game._armed_slot, 0, "그런데 슬롯은 여전히 켜져 있다 — 마른 채 켜진 그 상태다 (자가 점검)")
	game._unhandled_input(_release(at))
	await t.pump_frames(2)

	t.eq(Color(hs.boxes[0]["bg"]), Look.COL_SLOT_OFF,
		"마른 슬롯은 켜져 있어도 초록이 아니다 — 채움은 「무엇이 나오나」를 말한다")
	t.eq(float(hs.boxes[0]["width"]), Look.PRESS_HOVER_BORDER_WIDTH_PX,
		"그래도 테두리는 켜진 두께다 — 테두리는 「어느 키인가」를 말한다")
	# The floor: a slot that is neither armed nor dry still reads as the third tone, so the grey above
	# is not "every box is grey now".
	t.ok(Rules.summon_type_of(1) >= 0 and not game.battle.slot_reserve_ids(1).is_empty(),
		"2번 슬롯은 물려 있고 몸도 남아 있다 (자가 점검)")
	t.eq(Color(hs.boxes[1]["bg"]), Look.COL_BUTTON, "그 상자는 세 번째 색 그대로다")
	t.eq(float(hs.boxes[1]["width"]), Look.PRESS_BORDER_WIDTH_PX, "테두리도 쉬는 두께다")
	game._unhandled_input(_key(KEY_1))


## How many tiles in the last captured frame wear the band's blend. Read off the FILL rather than off
## `can_summon_at`, because what is under test is whether the blend reached the leaf at all.
func _band_fills(fs: FieldSpy, g: Grid) -> int:
	var n := 0
	for raw: Dictionary in fs.tiles:
		var rect: Rect2 = raw["rect"]
		var tx := int(round(rect.position.x / Look.TILE_PX))
		var ty := int(round(rect.position.y / Look.TILE_PX))
		if tx < 0 or ty < 0 or tx >= g.w or ty >= g.h:
			continue
		if g.water[g.tile_index(tx, ty)] == 0:
			continue
		if Color(raw["fill"]) != Look.COL_WATER:
			n += 1
	return n


## Any tile a boat may be sent to, so a plan can be committed. The band rows need a committed fight
## and `commit()` refuses an empty plan.
func _sendable_tile(g: Grid) -> int:
	for tile in g.w * g.h:
		if g.home_harbour_for(tile) >= 0:
			return tile
	return -1


func _a_band_tile(g: Grid, n: int) -> int:
	var seen := 0
	for tile in g.w * g.h:
		if not g.can_summon_at(tile):
			continue
		if seen == n:
			return tile
		seen += 1
	return -1


## Parks the camera at `zoom = 1.0` with `tile` as near the middle of the screen as the map allows,
## and returns the SCREEN point that tile now sits at. **The one place screen<->world is written in
## this file** — a second conversion would be the same arithmetic free to drift.
##
## ⚠ `position` is composed in `field_view._process`, so it is written here directly rather than waited
## for: these rows call `game._process(dt)` by hand and turn no frames at all.
func _park_on(fs: FieldSpy, g: Grid, tile: int) -> Vector2:
	var world := Look.tile_point_px(g.tile_point(tile))
	var cam := world - Look.viewport_size_px() * 0.5
	cam.x = clampf(cam.x, 0.0, maxf(0.0, float(g.w) * Look.TILE_PX - Look.VIEWPORT_W_PX))
	cam.y = clampf(cam.y, 0.0, maxf(0.0, float(g.h) * Look.TILE_PX - Look.VIEWPORT_H_PX))
	fs.zoom = 1.0
	fs.cam_px = cam
	fs.position = -cam
	fs.scale = Vector2.ONE
	return world - cam


## How many refusal marks are sitting in the field's transient drawer. Read off `_fx` rather than off
## the drawn rings, because these rows turn no frames.
func _refusals(fs: FieldSpy) -> int:
	var n := 0
	for raw: Dictionary in fs._fx:
		if int(raw["kind"]) == FieldView.FxKind.REFUSE:
			n += 1
	return n


## The AIM's rings in one captured frame, told apart from every boat's landing ring by COLOUR: a boat's
## ring is `COL_ROUTE` and the aim's is the accept/refuse pair. ⚠ The radius is checked too, so a
## refusal mark (a `COL_LOSE` ring at `REFUSE_MARK_R_PX`) can never be counted as one.
func _aim_rings(fs: FieldSpy) -> Array:
	var out := []
	for raw: Dictionary in fs.rings:
		if absf(float(raw["radius"]) - Look.TARGET_RING_R_PX) > 0.01:
			continue
		var col := Color(raw["colour"])
		if col == Look.COL_WIN or col == Look.COL_LOSE:
			out.append(raw)
	return out


## The drawn routes that START at `from_px`. A boat's own remaining route starts at that boat's `pos`,
## so this names the aim's route without needing a second colour.
func _routes_from(fs: FieldSpy, from_px: Vector2) -> Array:
	var out := []
	for raw: Dictionary in fs.routes:
		var pts := PackedVector2Array(raw["points"])
		if pts.size() > 0 and pts[0] == from_px:
			out.append(raw)
	return out


## The captured box whose resting rectangle is slot `i`'s. Matched by POSITION rather than by index in
## the capture array, so the row still names the right box if the draw order is ever changed.
func _box_at(hs: HudSpy, i: int) -> Dictionary:
	var want := Look.slot_rect_px(i)
	for raw: Dictionary in hs.boxes:
		if (raw["rect"] as Rect2).position.distance_to(want.position) < 0.01:
			return raw
	return {}


## The captured BAR whose rail is slot `i`'s, matched by rectangle for the reason `_box_at` is.
func _bar_at(hs: HudSpy, i: int) -> Dictionary:
	var want := Look.slot_bar_rect_px(i)
	for raw: Dictionary in hs.bars:
		if (raw["back"] as Rect2).position.distance_to(want.position) < 0.01:
			return raw
	return {}


## ⚠ **Keys go through `game._unhandled_input` exactly as the clicks do.** They would survive
## `root.push_input` — they carry no position — and that is precisely the trap: half an input suite
## green while the other half is silently dead.
func _key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = code
	return ev


## The OS auto-repeat shape: still `pressed`, but `echo`.
func _key_echo(code: int) -> InputEventKey:
	var ev := _key(code)
	ev.echo = true
	return ev


func _click(at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	return ev


func _press(at: Vector2) -> InputEventMouseButton:
	return _click(at)


func _release(at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = at
	return ev


func _motion(at: Vector2, relative: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.relative = relative
	return ev


func _wheel(at: Vector2, up: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	ev.position = at
	return ev
