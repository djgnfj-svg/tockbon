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
## ⚠ The camera is parked per row: `_park_on` puts the tile under test at the CENTRE of the screen
## (the one screen point whose ground point is exact at every zoom, yaw and pitch) and returns that
## screen point. It is the one place the conversion is touched in this file.
##
## ⚠⚠ **`FieldSpy` IS DELETED — the field has no `_paint_*` hooks left to override**, and the old
## spy's `super()` into a parent without `_draw` was the parse failure that made this whole net
## vanish (151 checks reported as nothing). What replaces the captures is the REAL `FieldView`, read
## on ticket 09's surfaces: the summon RING is its own pooled node (`_ring` — visible, position,
## mesh AABB, material), the aim marks are vertices in the ground fx buffer (`_g_v`/`_g_c`) with
## `_decal.mesh.get_surface_count()` beside them (buffers say "built", the surface says
## "committed" — deleting `_fx_flush` stays green on the buffers alone), and the refusal marks were
## always entries in `_fx`, which never depended on a hook.


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

	# ⚠⚠ **THE SHELL OPENS ON THE TITLE AND THIS FILE WALKED STRAIGHT PAST IT** (fixed 2026-08-27).
	# **Every row below opens with `game._open_island()`**, which reads `run.begin_island()` — and
	# `Game._ready()` sets `run = null` and opens no island for itself, so the very first row died on a
	# null `run` before it measured one thing. **The fix drives the shell and pokes no field**: 시작하기
	# and nothing else, through `_unhandled_input` — 티켓 12 took the card and 완료 presses off the
	# start path, so the walk that was three presses is one.
	# ⚠ Once the run is standing on its island, `begin_island()` hands back a FRESH `Battle` on every
	# call, so each row's own `_open_island()` is still the real reset it always was.
	_walk_from_the_title_to_the_island(t, game)

	# Swap in the spies and re-open, exactly as `net_shell` does: a spy starts with a null `battle`, so
	# a deleted wiring line would leave every capture below empty rather than merely different.
	for v: Node2D in [game.field_view, game.hud_view]:
		game.remove_child(v)
		v.queue_free()
	var fs := FieldView.new()
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

	await _the_ring_is_on_screen_from_frame_one(t, game, fs)
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
	await _a_press_away_from_the_centre(t, game, fs)

	# ⚠ **The swapped-in spies are NOT removed here.** `queue_free` on the parent takes its children
	# with it; pulling them out first leaves two orphaned `Node2D`s nothing owns, and the round reports
	# them on stderr as leaked RIDs — which this wrapper reads as a failure, correctly.
	t.root.remove_child(game)
	game.queue_free()


# -- V1 / V2 ---------------------------------------------------------------------------------------
## ⚠⚠ **The green band became a RING** (the user: 「초록색이 있을 필요는 없다? 내가 놓을 수 있는
## 위치는 그냥 원 기준에 눈에 보이면 될 거 같고」), and the rule itself became a circle
## (`Rules.SUMMON_RADIUS_TILES`) — so the row's subject moved from tile fills to the ring node.
## **The centre and the radius are read off the SIM** (`Grid.summon_centre` / `summon_radius`), the
## same two numbers `can_summon_at` tests, so the drawn circle cannot promise water the sim refuses.
## ⚠ Mutation: gate the ring on `_summon_aim >= 0` ⇒ the frame-one half goes red — the region has to
## be on screen the moment the island opens. 「뭐 어떻게 동작시키는지 전혀모르겠는데?」 was measured
## with everything green once already.
## ⚠ Mutation: `_rebuild_ring` with radius * 0.0 ⇒ the AABB extent row bites — a bounding box of
## zero extent still returns the right centre (`how-nets-lie`'s zero-extent entry).
func _the_ring_is_on_screen_from_frame_one(t, game: Game, fs: FieldView) -> void:
	var pumped := 0
	while fs._sprites_used < 1 and pumped < 20:
		await t.pump_frames(1)
		pumped += 1
	t.ok(fs._sprites_used >= 1,
		"%d 프레임 만에 field_view 의 _process 가 트리 위에서 진짜 돌았다 (자가 점검 — 몸이 그려졌다)" % pumped)
	t.eq(game._armed_slot, -1, "아직 아무 슬롯도 안 켰다 (자가 점검)")

	var g: Grid = game.battle.grid
	t.ok(fs._ring != null, "소환 링 노드가 있다 (자가 점검)")
	t.ok(fs._ring.visible, "섬이 열린 프레임부터, 키를 누르기 전에도, 링이 보인다 — 손이 갈 자리가 화면에 있다")
	t.eq(fs._ring.position, Vector3(g.summon_centre().x, 0.0, g.summon_centre().y),
		"링의 중심이 sim 의 summon_centre 그대로다")
	t.eq((fs._ring.material_override as StandardMaterial3D).albedo_color, Look.COL_SUMMON_RING,
		"링 색이 look.gd 값이다")
	var r := g.summon_radius()
	t.ok(r > 2.0, "이 섬의 소환 반지름이 실제로 몇 타일은 된다 (자가 점검, %.2f)" % r)
	var aabb: AABB = fs._ring.mesh.get_aabb()
	var half := Look.SUMMON_RING_W_TILES * 0.5
	t.ok(absf(aabb.size.x * 0.5 - (r + half)) < 0.05 and absf(aabb.size.z * 0.5 - (r + half)) < 0.05,
		"링의 바깥 반지름이 sim 의 summon_radius 다 (%.2f 타일) — 그린 원과 거절하는 규칙이 한 원이다" % r)
	t.ok(aabb.size.x > 1.0 and aabb.size.z > 1.0,
		"그리고 extent 가 0 이 아니다 — 반지름 0 으로 접힌 링은 중심만 맞고 여기서 문다")


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

	# ⚠⚠ **L3 INVERTED BY 티켓 15, and the reason is a picture.** It used to read 「비어 있는 3번은 안
	# 켜지지만 거절 표시는 들어간다」 — correct while the slot row came from a constant table and every
	# slot in range HAD a box. The row is as long as the RUN now, so slot 2 has no box at all, and a
	# refusal mark stamped there makes something shake that is not on screen. **「아무 일도 안
	# 일어났다」 is the right answer when there is nothing there to answer.**
	var slot_n := game.battle.army.slot_count()
	t.ok(slot_n <= 2, "회차가 등록한 칸이 3번에 못 미친다 (자가 점검 — 이 줄의 전제)")
	t.ok(not hs._chip_fx.has(HudView.CHIP_SLOT_BASE + 2), "3번 칸에 표시가 없다 (자가 점검)")
	game._unhandled_input(_key(KEY_3))
	t.eq(game._armed_slot, -1, "등록 안 된 3번 슬롯은 안 켜진다")
	t.ok(not hs._chip_fx.has(HudView.CHIP_SLOT_BASE + 2),
		"그리고 거절 표시도 안 찍힌다 — 상자가 없는 자리에 찍으면 화면에 없는 것이 흔들린다")
	# ⚠ The FLOOR under that ceiling — a slot that has a box and is dry still gets the mark — is
	# `_a_refused_key_flashes_as_well_as_shakes`, further down this file. Without it the line above
	# would be green with the refusal mark deleted outright.
	t.eq(HudView.CHIP_START, 0, "시작 버튼은 0번 칸이다 (자가 점검)")
	t.eq(HudView.CHIP_SLOT_BASE, 1, "그리고 소환 칸은 1번부터다 (자가 점검)")


# -- L4 / L5 ---------------------------------------------------------------------------------------
## ⚠ Mutation L4: move the first summon into `_process` ⇒ the press does nothing until a frame turns,
## which is a 200 ms hole in a budget Swink puts at 100.
## ⚠ Mutation L5: fire one per frame (drop the accumulator), or read the cadence as 0.0.
func _the_press_and_the_beat(t, game: Game, fs: FieldView) -> void:
	var g: Grid = game.battle.grid
	var tile := _a_band_water_tile(g, 0)
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
func _the_sweep(t, game: Game, fs: FieldView) -> void:
	game._open_island()
	var g: Grid = game.battle.grid
	var a_tile := _a_band_water_tile(g, 0)
	var b_tile := _a_band_water_tile(g, 40)
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
func _the_release(t, game: Game, fs: FieldView) -> void:
	game._open_island()
	var g: Grid = game.battle.grid
	var tile := _a_band_water_tile(g, 0)
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
func _a_dry_slot(t, game: Game, fs: FieldView) -> void:
	game._open_island()
	var g: Grid = game.battle.grid
	var tile := _a_band_water_tile(g, 0)
	var at := _park_on(fs, g, tile)
	game._unhandled_input(_key(KEY_1))
	game._unhandled_input(_press(at))
	# Beat until the slot is dry. The slot is armed and wet when the hold starts and runs dry under it —
	# which is the only way a slot can be armed AND dry, because the key refuses to arm a dry one.
	# ⚠ **The beat count is DERIVED, not the literal 5 it used to be**: slot 0 opens with
	# `Rules.start_bodies_of(0)` bodies and that number moved from six to ten (티켓 15).
	var beats := 0
	while not game.battle.slot_reserve_ids(0).is_empty() and beats < 40:
		game._process(0.20)
		beats += 1
	t.eq(game.battle.boats.size(), Rules.start_bodies_of(0), "1번 칸의 몸이 다 나갔다 (자가 점검)")
	t.eq(game.battle.slot_reserve_ids(0).size(), 0, "슬롯이 말랐다 (자가 점검)")

	var before := _refusals(fs)
	game._process(0.20)
	t.eq(_refusals(fs) - before, 1, "마른 슬롯은 한 박자에 거절 표시 하나를 낸다")
	game._process(0.20)
	game._process(0.20)
	t.eq(_refusals(fs) - before, 3, "세 박자면 셋이다 — 프레임마다가 아니다")
	t.eq(game.battle.boats.size(), Rules.start_bodies_of(0), "그리고 배는 안 늘었다")
	t.ok(game._summon_down, "꾹 누른 것은 안 끝난다 — 마른 것이 손을 놓게 하지는 않는다")


# -- L9 --------------------------------------------------------------------------------------------
## ⚠ Mutation: drop the `can_summon_at` test in `Battle.summon` ⇒ a press in open ocean places a boat
## the route cannot reach.
func _outside_the_band(t, game: Game, fs: FieldView) -> void:
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
func _after_the_commit(t, game: Game, fs: FieldView, hs: HudSpy) -> void:
	game._open_island()
	var g: Grid = game.battle.grid
	var tile := _a_band_water_tile(g, 0)
	var at := _park_on(fs, g, tile)
	game._unhandled_input(_key(KEY_1))
	game._unhandled_input(_press(at))
	t.eq(game.battle.boats.size(), 1, "확정할 배가 하나 있다 (자가 점검)")

	await t.pump_frames(2)
	# ⚠ Against the RUN's own slots, never against a number. A registration is one card.
	var slot_n := game.battle.army.slot_count()
	t.eq(hs.boxes.size(), slot_n,
		"슬롯 줄은 확정 전에 회차가 등록한 만큼 그려진다 (%d칸)" % slot_n)

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
func _the_camera_still_answers(t, game: Game, fs: FieldView) -> void:
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
	game._unhandled_input(_key(KEY_1))
	t.eq(game._armed_slot, -1, "같은 키로 껐다 (자가 점검)")
	var cam_before: Vector2 = fs.cam_px
	game._unhandled_input(_press(Vector2(640.0, 360.0)))
	game._unhandled_input(_motion(Vector2(640.0, 360.0), Vector2(120.0, 80.0)))
	game._unhandled_input(_release(Vector2(760.0, 440.0)))
	t.ok(fs.cam_px != cam_before, "끄면 화면 끌기가 돌아온다")


# -- V3 / V4 / V5 ----------------------------------------------------------------------------------
## The aim's picture, read off SURFACE 3 (the ground fx buffer) and SURFACE 2 (the ghost sprites).
## ⚠ Mutation V4: straighten the route into one chord. **`net_draw_leaf` lost its whole-array shape
## check with the leaf itself**, so this runtime row is now the ONLY thing that catches it: a bent
## route's interior waypoint sits well off the chord, and the waypoint-has-a-vertex row cannot be
## satisfied by a straight line.
## ⚠ Mutation V3 (the landing half): drop `_paint_ghosts`' landing derivation ⇒ the ghost fan stops
## standing on `summon_landing_of`. ⚠⚠ **The RING sits on the AIMED tile in the current code** — the
## old net had it on the derived landing, and the revival moved the landing's picture into the ghost
## fan instead. Both facts are measured as they ARE; whether the ring should move back to the
## landing is 티켓 09's fx round's question, written there rather than smuggled in here as a red.
## ⚠ Mutation V5, WHOLE again (the user closed the fork: 「추천대로」, 2026-08-24): a dry slot draws
## NOTHING — `_paint_plan`'s reserve gate kills the ring and the route, `_paint_ghosts`' kills the
## fan. Drop either gate and its half of the tail rows bites.
func _the_aim_marks(t, game: Game, fs: FieldView) -> void:
	game._open_island()
	var g: Grid = game.battle.grid
	# A BENT route, and the bend must be big enough to measure: an interior waypoint at least 16 px
	# off the endpoints' chord, so a straightened polyline leaves no vertex within 12 px of it.
	var bent := -1
	var bend_px := 0.0
	for tile in g.w * g.h:
		if not g.can_summon_at(tile):
			continue
		var route := g.summon_route(tile)
		if route.size() <= 2:
			continue
		var a := Look.tile_point_px(route[0])
		var c := Look.tile_point_px(route[route.size() - 1])
		var off := 0.0
		for k in range(1, route.size() - 1):
			off = maxf(off, _dist_to_segment(Look.tile_point_px(route[k]), a, c))
		if off > bend_px:
			bent = tile
			bend_px = off
	t.ok(bent >= 0 and bend_px > 16.0,
		"직선에서 16px 넘게 굽은 항로를 내는 바다 칸을 찾았다 (자가 점검, %.1fpx)" % bend_px)

	var at := _park_on(fs, g, bent)
	game._unhandled_input(_key(KEY_1))
	game._unhandled_input(_motion(at, Vector2(2.0, 2.0)))
	t.eq(game.field_view._summon_aim, bent, "누르기 전에 이미 조준이 잡혔다 (자가 점검)")
	await t.pump_frames(2)
	t.eq(game.battle.boats.size(), 0, "계획이 비어 있다 — 이 프레임의 표시는 조준의 것뿐이다 (자가 점검)")

	# The ground buffer holds geometry AND it was committed — the pair `how-nets-lie` demands.
	t.ok(fs._g_v.size() > 0, "조준 프레임의 바닥 버퍼에 기하가 있다 (%d 정점)" % fs._g_v.size())
	t.eq(fs._decal.mesh.get_surface_count(), 1,
		"그리고 바닥 메시로 커밋됐다 — _fx_flush 를 지우면 버퍼는 남고 여기가 문다")
	t.eq(fs._a_v.size(), 0, "공중 버퍼는 조용하다 — 조준은 바닥의 것이다")

	# The ring: every COL_WIN vertex, centred on the aimed tile at the aim ring's own radius.
	var ring_pts := _ground_verts_of(fs, Look.COL_WIN)
	t.ok(ring_pts.size() >= 24, "수락색(COL_WIN) 링 정점이 있다 (%d개)" % ring_pts.size())
	var ring_centre := _xz_centre(ring_pts)
	var aim_c := Look.tile_point_px(g.tile_point(bent)) / Look.TILE_PX
	t.ok(ring_centre.distance_to(aim_c) < 0.05,
		"링의 중심이 조준한 칸이다 (%.3f 타일 차)" % ring_centre.distance_to(aim_c))
	# Both ends of the extent: the zero-extent trap on the floor, the radius itself on the ceiling.
	var ring_max := _max_dist_xz(ring_pts, ring_centre)
	var want_r := (Look.TARGET_RING_R_PX + Look.ROUTE_WIDTH_PX * 0.5) / Look.TILE_PX
	t.ok(absf(ring_max - want_r) < 0.05,
		"링의 extent 가 조준 링 반지름 그대로다 (%.3f 타일, 기대 %.3f) — 접힌 링은 여기서 문다"
			% [ring_max, want_r])

	# The route: a vertex beside EVERY waypoint of the sim's own `summon_route`, bend included.
	var route_pts := _ground_verts_of(fs, Look.COL_ROUTE)
	t.ok(route_pts.size() >= 6, "항로 정점이 있다 (%d개)" % route_pts.size())
	var want := g.summon_route(bent)
	t.ok(want.size() > 2, "그 항로는 두 점보다 길다 (%d점 — 자가 점검)" % want.size())
	var missing := 0
	for wp in want:
		if _min_dist_xz(route_pts, Look.tile_point_px(wp) / Look.TILE_PX) > 0.3:
			missing += 1
	t.eq(missing, 0, "항로의 모든 경유점 곁에 정점이 있다 — 두 끝점을 직선으로 이으면 굽이 경유점이 빈다")

	# The landing's picture is the GHOST FAN — real pooled sprites wearing the ghost tint, standing
	# on the DERIVED landing rather than on the pressed water.
	var landing := g.summon_landing_of(bent)
	var land_c := Look.tile_point_px(g.tile_point(landing)) / Look.TILE_PX
	t.ok(land_c.distance_to(aim_c) > 0.5, "상륙지와 누른 칸은 실제로 다른 자리다 (자가 점검)")
	var ghosts := _ghost_sprites(fs)
	t.ok(ghosts.size() > 0, "유령 몸이 실제로 그려진다 (%d장)" % ghosts.size())
	var gc := Vector2.ZERO
	for gs: Sprite3D in ghosts:
		gc += Vector2(gs.position.x, gs.position.z)
	gc /= float(ghosts.size())
	t.ok(gc.distance_to(land_c) < 0.5,
		"유령 부채의 한가운데가 도출된 상륙지다 (%.2f 타일 차) — 내릴 자리가 누른 자리가 아니라 설 자리에 보인다"
			% gc.distance_to(land_c))
	t.ok(gc.distance_to(aim_c) > 0.5, "그리고 누른 칸이 아니다 — V3 의 절반이 유령 쪽에서 산다")

	# ⚠ V5's surviving half — the same aim on a DRY slot draws NO ghosts. Drained at a DIFFERENT
	# tile so the six uncommitted boats' own positions cannot stand where the fan stood.
	var drain := -1
	for tile in g.w * g.h:
		if g.can_summon_at(tile) and tile != bent:
			drain = tile
			break
	t.ok(drain >= 0 and drain != bent, "배를 뺄 다른 바다 칸을 찾았다 (자가 점검)")
	# ⚠ Derived, not a literal 6 — slot 0's opening body count moved to ten (티켓 15).
	for _k in Rules.start_bodies_of(0):
		game.battle.summon(0, drain)
	t.eq(game.battle.slot_reserve_ids(0).size(), 0, "슬롯을 비웠다 (자가 점검)")
	await t.pump_frames(2)
	t.eq(_ghost_sprites(fs).size(), 0, "마른 슬롯은 유령을 안 그린다 — 보낼 몸이 없으면 설 자리 그림도 없다")
	t.eq(_ground_verts_of(fs, Look.COL_WIN).size() + _ground_verts_of(fs, Look.COL_LOSE).size(), 0,
		"링도 안 그린다 — sim 이 거절할 약속을 화면이 하지 않는다 (복원된 옛 규칙)")
	t.eq(_ground_verts_of(fs, Look.COL_ROUTE).size(), 0, "항로도 안 그린다 — 없다는 게 대답이다")


# -- V6 / V7 / V8 ----------------------------------------------------------------------------------
## ⚠ Mutation V6: draw the fill at the back's full width ⇒ nothing on screen ever goes down, which is
## half of why the last game died.
## ⚠ Mutation V7: draw a bar for unbound slots ⇒ 「아직 아무것도 안 넣었다」 and 「다 내보냈다」 become
## one picture.
## ⚠ Mutation V8: pass the resting width in both branches ⇒ the armed box loses one of its two
## channels and the fill has to carry the read alone.
func _the_slot_row(t, game: Game, fs: FieldView, hs: HudSpy) -> void:
	game._open_island()
	var g: Grid = game.battle.grid
	var tile := _a_band_water_tile(g, 0)
	var at := _park_on(fs, g, tile)
	game._unhandled_input(_key(KEY_1))
	await t.pump_frames(2)

	# V8 — two channels, and the border difference clears the snap floor.
	var slot_n := game.battle.army.slot_count()
	t.eq(hs.boxes.size(), slot_n,
		"슬롯 상자가 회차가 등록한 수만큼 그려진다 (%d개)" % slot_n)
	# ⚠⚠ **The literal is on the OPENING TABLE, never on the count the row above reads.** Both sides
	# reading the run would move together and pass at any value — the shape this repo has measured.
	t.eq(Rules.START_SLOTS.size(), 1, "그리고 회차는 한 칸으로 연다 (리터럴) — 둘째는 개막 카드가 넣었다")
	var armed := _box_at(hs, 0, slot_n)
	var resting := _box_at(hs, 1, slot_n)
	t.eq(float(armed["width"]), Look.PRESS_HOVER_BORDER_WIDTH_PX, "켜진 상자의 테두리가 두꺼운 쪽이다")
	t.eq(float(resting["width"]), Look.PRESS_BORDER_WIDTH_PX, "안 켜진 상자는 쉬는 두께다")
	t.ok(float(armed["width"]) - float(resting["width"]) > 2.0,
		"둘의 차이가 스냅 바닥 2.0 보다 크다 — 안 그러면 켠 것이 화면에 안 닿는다")
	t.eq(Color(armed["bg"]), Look.COL_START, "그리고 채움 색도 다르다 — 두 갈래로 말한다")
	t.ok(Color(resting["bg"]) != Look.COL_START, "안 켜진 상자는 그 색이 아니다")
	t.eq(hs.digits.size(), slot_n, "숫자도 상자마다 하나씩 그려진다")
	t.eq(str(hs.digits[0]["text"]), "1", "첫 상자에 1 이 적혀 있다")
	t.eq(str(hs.digits[slot_n - 1]["text"]), str(slot_n), "마지막 상자에 그 번호가 적혀 있다")
	# The glyph rides the box: a rect origin plus a non-zero offset, never the rect's own corner.
	t.eq(Vector2(hs.digits[0]["at"]), Look.slot_rect_px(0, slot_n).position + Look.HUD_SLOT_TEXT_OFFSET_PX,
		"숫자가 상자 안에 놓였다 — 상자의 원점에 그린 글자는 놓인 적이 없는 글자다")

	# V7 — the bars. Every REGISTERED slot draws one; the slots the run has not registered draw none
	# at all, and there is no box for them either.
	t.eq(hs.bars.size(), slot_n, "등록 안 된 칸에는 막대가 아예 없다")

	# V6 — one body out, and the bar drops by exactly one body's worth.
	var back: Rect2 = _bar_at(hs, 0, slot_n)["back"]
	var full: Rect2 = _bar_at(hs, 0, slot_n)["fill"]
	t.eq(full.size.x, back.size.x, "내보내기 전에는 막대가 가득이다 (자가 점검)")
	var opens_with := Rules.start_bodies_of(0)
	t.eq(opens_with, 10, "개막 첫 칸의 병력이 열이다 (아래 분수가 재는 값 — 자가 점검)")
	game._unhandled_input(_press(at))
	game._unhandled_input(_release(at))
	t.eq(game.battle.boats.size(), 1, "한 척 내보냈다 (자가 점검)")
	await t.pump_frames(2)
	var after: Rect2 = _bar_at(hs, 0, slot_n)["fill"]
	t.ok(absf(after.size.x - back.size.x * float(opens_with - 1) / float(opens_with)) < 0.01,
		"한 척 내보내면 막대가 정확히 %d분의 %d 로 줄어든다 (%.2f / %.2f)"
			% [opens_with, opens_with - 1, after.size.x, back.size.x])

	# V7 again — an exhausted slot keeps an EMPTY RAIL, which is the only thing separating
	# 「다 내보냈다」 from 「아직 아무것도 안 넣었다」.
	for _k in opens_with - 1:
		game.battle.summon(0, tile)
	t.eq(game.battle.slot_reserve_ids(0).size(), 0, "슬롯을 다 비웠다 (자가 점검)")
	await t.pump_frames(2)
	t.eq(hs.bars.size(), slot_n, "다 내보낸 슬롯도 여전히 막대를 하나 그린다")
	t.eq(Rect2(_bar_at(hs, 0, slot_n)["fill"]).size.x, 0.0, "그 막대의 채움은 0 이다 — 빈 레일만 남는다")
	t.eq(Rect2(_bar_at(hs, 0, slot_n)["back"]), back, "레일 자체는 그대로 있다")


# -- L12 -------------------------------------------------------------------------------------------
## ⚠ Mutation: make `slot_row_origin_x_px` a constant again ⇒ the row stops touching the margin the
## moment the slot table changes length, which is the half of 「확장가능」 the layout owns.
func _the_boxes_clear_the_army(t, game: Game, fs: FieldView) -> void:
	game._open_island()
	# The camera state is irrelevant here on purpose: the slot boxes are HUD geometry read straight
	# off `look.gd`, and nothing on the field is compared against them any more (the harbour stack
	# they used to clear is deleted).
	t.ok(fs.battle == game.battle, "필드가 물려 있다 (자가 점검)")

	var boxes: Array[Rect2] = []
	var slot_n := game.battle.army.slot_count()
	for i in slot_n:
		boxes.append(Look.slot_rect_px(i, slot_n))
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
func _the_band_goes_with_the_boxes(t, game: Game, fs: FieldView, hs: HudSpy) -> void:
	game._open_island()
	var g: Grid = game.battle.grid

	await t.pump_frames(2)
	t.ok(fs._ring.visible, "확정 전에는 링이 실제로 보인다 (자가 점검)")
	t.eq(hs.boxes.size() > 0, true, "그리고 슬롯 상자도 그려진다 (자가 점검)")

	# ⚠⚠ **RE-AIMED FROM `send` ONTO `summon` (2026-08-27), AND THE TILE CHANGED KIND WITH IT.**
	# `Battle.send` took a BEACH — a passable land tile a boat unloaded onto — and it is deleted whole
	# with the harbour half. `Battle.summon` takes WATER inside the summon band, so a fixture that
	# handed it the old beach would get -1 and redden this row for a reason that has nothing to do with
	# the ring. **What the row measures is untouched**: it only ever needed ONE boat standing in the
	# plan, because `commit()` refuses an empty one.
	var water := _a_band_water_tile(g, 0)
	t.ok(water >= 0, "확정할 배를 띄울 바다 칸을 찾았다 (자가 점검)")
	t.ok(game.battle.summon(0, water) >= 0, "그 바다 칸에 배를 하나 불러냈다 (자가 점검)")
	t.ok(game.battle.commit(), "확정했다 (자가 점검)")
	hs.boxes.clear()
	await t.pump_frames(2)
	t.eq(hs.boxes.size(), 0, "확정 뒤 슬롯 상자가 사라진다 (자가 점검 — 비교 상대다)")
	t.ok(not fs._ring.visible,
		"그리고 링도 같이 사라진다 — 손이 갈 데가 없어진 뒤에도 바다에 표시가 남으면 그게 거짓말이다")
	# The floor: the sea and the island are still on screen, so the zero above is "the ring's own
	# flip" and not "the world went dark".
	t.ok(fs._sea.visible and fs._terrain.mesh.get_surface_count() > 0,
		"바다와 지형은 그대로다 — 꺼진 것은 링뿐이다")


## ⚠⚠ **THREE LINES CLAIMED TO BE LOAD-BEARING AND WERE GREEN WHEN DELETED.** A comment asserting a
## line matters when nothing measures it is the same class of lie as a fake net — and the control says
## this is not blanket blindness: deleting `_disarm()` from `_open_island` reddens 23 checks. So each
## of the three is driven here rather than argued about.
func _the_three_lines_that_claimed_to_be_load_bearing(t, game: Game, fs: FieldView, hs: HudSpy) -> void:
	# (1) `_summon_down = false` inside the `_hold_sec` gate in `game.gd::_unhandled_input`. Its own
	# comment says suppressing only the MOTION events leaves the flag alive, so the very next motion
	# after the hold ends resumes a gesture the plan says was cancelled. Driven: hold, deliver an
	# event, end the hold, and beat.
	game._open_island()
	var g: Grid = game.battle.grid
	var tile := _a_band_water_tile(g, 0)
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
	fs.setup(game.battle, game.battle.army, Islands.rows())
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
	var drain := _a_band_water_tile(g, 0)
	# Slot 1 (ranged) is drained rather than slot 0, so the accepted-press control at the bottom of this
	# row still has a wet slot to arm.
	var spent := 0
	while not game.battle.slot_reserve_ids(1).is_empty() and spent < 40:
		t.ok(game.battle.summon(1, drain) >= 0, "말리기 전에는 나간다 (자가 점검)")
		spent += 1
	t.ok(game.battle.slot_reserve_ids(1).is_empty(), "2번 슬롯이 말랐다 (자가 점검)")
	await t.pump_frames(2)
	var slot_n := game.battle.army.slot_count()
	t.eq(hs.boxes.size(), slot_n, "상자가 회차가 등록한 수만큼 그려진다 (자가 점검)")
	var rest_bg := Color(hs.boxes[1]["bg"])
	var rest_pos: Vector2 = (hs.boxes[1]["rect"] as Rect2).position
	t.eq(rest_bg, Look.COL_SLOT_OFF, "쉴 때 그 상자는 안 눌리는 색이다 (자가 점검)")
	t.eq(rest_pos, Look.slot_rect_px(1, slot_n).position, "그리고 제자리에 있다 (자가 점검)")

	game._unhandled_input(_key(KEY_2))
	t.eq(game._armed_slot, -1, "마른 슬롯은 안 켜진다 (자가 점검)")
	await t.pump_frames(1)
	t.eq(hs.boxes.size(), slot_n, "거절한 프레임에도 같은 수가 그려진다 (자가 점검)")
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
	t.eq((hs.boxes[0]["rect"] as Rect2).position, Look.slot_rect_px(0, slot_n).position,
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
func _an_armed_slot_that_has_run_dry_is_not_green(t, game: Game, fs: FieldView, hs: HudSpy) -> void:
	game._open_island()
	var g: Grid = game.battle.grid
	var tile := _a_band_water_tile(g, 0)
	var at := _park_on(fs, g, tile)
	game._unhandled_input(_key(KEY_1))
	await t.pump_frames(2)
	t.eq(Color(hs.boxes[0]["bg"]), Look.COL_START, "켜자마자 상자가 초록이다 (자가 점검)")

	game._unhandled_input(_press(at))
	# ⚠ Beat until dry rather than a literal count — see `_a_dry_slot`.
	var beats := 0
	while not game.battle.slot_reserve_ids(0).is_empty() and beats < 40:
		game._process(0.20)
		beats += 1
	t.eq(game.battle.slot_reserve_ids(0).size(), 0, "몸이 다 나가 슬롯이 말랐다 (자가 점검)")
	t.eq(game._armed_slot, 0, "그런데 슬롯은 여전히 켜져 있다 — 마른 채 켜진 그 상태다 (자가 점검)")
	game._unhandled_input(_release(at))
	await t.pump_frames(2)

	t.eq(Color(hs.boxes[0]["bg"]), Look.COL_SLOT_OFF,
		"마른 슬롯은 켜져 있어도 초록이 아니다 — 채움은 「무엇이 나오나」를 말한다")
	t.eq(float(hs.boxes[0]["width"]), Look.PRESS_HOVER_BORDER_WIDTH_PX,
		"그래도 테두리는 켜진 두께다 — 테두리는 「어느 키인가」를 말한다")
	# The floor: a slot that is neither armed nor dry still reads as the third tone, so the grey above
	# is not "every box is grey now".
	t.ok(game.battle.army.slot_type_of(1) >= 0 and not game.battle.slot_reserve_ids(1).is_empty(),
		"2번 슬롯은 물려 있고 몸도 남아 있다 (자가 점검)")
	t.eq(Color(hs.boxes[1]["bg"]), Look.COL_BUTTON, "그 상자는 세 번째 색 그대로다")
	t.eq(float(hs.boxes[1]["width"]), Look.PRESS_BORDER_WIDTH_PX, "테두리도 쉬는 두께다")
	game._unhandled_input(_key(KEY_1))


## Any tile a boat may be sent to, so a plan can be committed. The band rows need a committed fight
## and `commit()` refuses an empty plan.
## ⚠⚠⚠ **THE ROW THIS WHOLE FILE WAS MISSING, AND `_park_on` IS EXACTLY WHY** (2026-08-25).
##
## **Every other press in this file goes through `_park_on`, which puts its tile at the MIDDLE OF THE
## SCREEN — and the middle is the one screen point that is right however broken the conversion is.**
## `screen_to_world_px(640, 360)` IS `_ground_centre_px()` by construction, at every zoom, every yaw,
## every pitch and every height. `_park_on`'s own header says so, and says it as a virtue. It is a
## virtue for what those rows measure (which tile, which beat, which body) and it is a **blind spot**
## for whether a press lands where the player is pointing.
##
## **Three separate faults in that conversion lived under this file's green at once**: a camera parked
## on the wrong side of its target so the island drew half a turn around, a `cos(pitch)` where the
## ground's foreshortening is its sine, and a flat plane standing in for a landscape with real hills.
## The user found all three in one sentence, by pressing somewhere other than the middle:
## 「놓는 위치랑 배의 위치가 다른데? 내가 놓는데에 배가 놔지지 않는데」.
##
## ⇒ **This row presses AWAY from the centre.** **The floor that keeps it honest is the distance from
## the centre**: without it a sweep that happened to sample only the middle of the screen would read
## exactly the same as this one, which is how the blind spot got here in the first place.
##
## ⚠⚠ **WHAT THIS ROW CANNOT CATCH, SAID OUT LOUD.** It aims with `field_view.tile_to_screen_px` and
## reads back through the shell's `_tile_at`, and those two are the FORWARD and the INVERSE of one
## expression — **a fault in both cancels inside the round trip**, which is `how-nets-lie`'s "A/B
## comparison catches diverged, never vanished". Measured, not assumed: put the camera's 180° flip
## back, or the cosine, and this file stays green at 174 while `net_camera` reddens by 6 and by 18.
## ⇒ **The chain is two links and both are measured.** `net_camera` ties the forward to
## `Camera3D.unproject_position` (the engine's own projection, in a 1280 x 720 `SubViewport`); this
## row ties the press to that forward. What is pinned HERE, because it costs one line and cannot
## cancel, is that the engine's camera and the pure axes still name the same screen-right.
func _a_press_away_from_the_centre(t, game: Game, fs: FieldView) -> void:
	game._open_island()
	var g: Grid = game.battle.grid

	# The survey framing, written out rather than inherited from whatever the last row left: zoom 1.0,
	# the opening yaw and pitch, camera at the origin and then clamped, which is what the shell hands
	# the player on an island this size.
	fs.zoom = 1.0
	fs.cam_yaw_deg = Look.CAM_YAW_DEG
	fs.cam_pitch_deg = Look.CAM_PITCH_DEG
	fs.cam_px = Vector2.ZERO
	fs._clamp_cam()

	fs._process(1.0 / 60.0)
	# ⚠ **The one pin here that a round trip cannot cancel**: the engine's camera and the pure axes
	# have to name the same screen-right. A camera parked on the wrong side of its target answers
	# `(-1, 0, 0)` at yaw 0 — the island drawn half a turn from the board every press is read against.
	var cam_right: Vector3 = fs._cam.transform.basis.x
	t.ok(cam_right.distance_to(Vector3(fs._ground_right().x, 0.0, fs._ground_right().y)) < 0.001,
		"엔진 카메라의 화면 오른쪽이 _ground_right 와 같은 방향이다 (%.3f, %.3f, %.3f)"
			% [cam_right.x, cam_right.y, cam_right.z])
	var cam_down: Vector3 = -fs._cam.transform.basis.y
	t.ok(Vector2(cam_down.x, cam_down.z).normalized().distance_to(fs._ground_down()) < 0.001,
		"화면 아래쪽도 _ground_down 과 같다 — 둘이 짝을 이뤄 180° 회전을 잡는다")

	var centre := Look.viewport_size_px() * 0.5
	var wrong := 0
	var seen := 0
	var far := 0
	var furthest := -1
	var furthest_px := Vector2.ZERO
	var furthest_d := 0.0
	for tile in g.w * g.h:
		if not g.can_summon_at(tile):
			continue
		var tx := tile % g.w
		var ty := tile / g.w
		var px := fs.tile_to_screen_px(tx, ty)
		if px.x < 0.0 or px.y < 0.0 or px.x > Look.VIEWPORT_W_PX or px.y > Look.VIEWPORT_H_PX:
			continue
		seen += 1
		var d := px.distance_to(centre)
		if d > 150.0:
			far += 1
		if d > furthest_d:
			furthest_d = d
			furthest = tile
			furthest_px = px
		if game._tile_at(px) != tile:
			wrong += 1
	t.ok(seen >= 20, "화면에 뜬 소환 가능 칸이 %d개다 (자가 점검 — 0개면 아무것도 안 쟀다)" % seen)
	t.ok(far >= 10,
		"그중 %d개는 화면 한가운데에서 150px 넘게 떨어져 있다 — 가운데만 찍는 검사가 아니다" % far)
	t.eq(wrong, 0, "그 칸들이 그려진 화면점을 누르면 셸이 전부 그 칸으로 읽는다")

	# ⚠⚠ **THE SAME QUESTION ON LAND, AND IT IS NOT THE SAME ANSWER.** The band is water and the sea
	# stands a flat 0.15 tiles up, so its height is worth 0.18 of a tile and never crosses a boundary —
	# **on the band alone, the flat plane and the landscape agree.** Land is 1 to 3 tiles up and a
	# press there was off by up to 4 rows, which is the gesture on the other end of the same plan:
	# `game._ring_hit_at` takes a drop BACK by a press on its landing ring, and a landing is land.
	var land_wrong := 0
	var land_seen := 0
	var flat_wrong := 0
	for tile in g.w * g.h:
		var tx := tile % g.w
		var ty := tile / g.w
		if not g.is_passable(tx, ty):
			continue
		var px := fs.tile_to_screen_px(tx, ty)
		if px.x < 0.0 or px.y < 0.0 or px.x > Look.VIEWPORT_W_PX or px.y > Look.VIEWPORT_H_PX:
			continue
		land_seen += 1
		# The flat board's own answer, which is what the shell used until 2026-08-25.
		if fs.world_to_tile(fs.screen_to_world_px(px)) != Vector2i(tx, ty):
			flat_wrong += 1
		# ⚠ Not `== 0`: a tile standing BEHIND a taller one is genuinely not on screen at its own
		# centre, and the walk answering with the hill in front of it is the right answer. Measured on
		# this island: 19 of its 180 walkable tiles are hidden that way, so the bound is the one that
		# separates "occluded" from "the mapping is wrong" — 4 in 5 have to come back exactly.
		if game._tile_at(px) != tile:
			land_wrong += 1
	t.ok(land_seen >= 100, "화면에 뜬 걸을 수 있는 칸이 %d개다 (자가 점검)" % land_seen)
	t.ok(float(land_wrong) < float(land_seen) * 0.2,
		"언덕 위를 눌러도 커서 밑 칸이 잡힌다 — %d/%d 만 어긋난다 (가려진 칸들이다)" % [land_wrong, land_seen])
	t.ok(flat_wrong > land_seen / 2,
		"자가 점검 — 높이를 무시한 옛 셈은 %d/%d 칸에서 틀린다 (그래서 위 행이 뭔가를 잰다)"
			% [flat_wrong, land_seen])

	# -- and the boat has to be ON THE WATER the moment it is placed --------------------------------
	# ⚠⚠ **The second half of the same sentence**: 「그리고 배를 놨으면 그게 바다에 보여야할듯」.
	# `_paint_bodies` skipped every boat while `battle.committed()` was false, so a placed boat was in
	# the sim and nowhere on screen — no hull, no body on its deck, and no landing ring to take it
	# back with. The reason written in the code was the harbour drag's (thirteen hulls on one tile) and
	# the harbour drag is deleted.
	t.ok(furthest >= 0 and furthest_d > 150.0,
		"가장 먼 소환 칸이 화면 한가운데에서 %.0fpx 떨어져 있다 (자가 점검)" % furthest_d)
	game._unhandled_input(_key(KEY_1))
	game._unhandled_input(_press(furthest_px))
	t.eq(game.battle.boats.size(), 1, "화면 구석을 눌러도 배가 한 척 뜬다")
	var boat: Dictionary = game.battle.boats[0]
	t.eq(Vector2(boat["pos"]), g.tile_point(furthest), "그 배가 앉은 칸이 누른 그 칸이다")
	t.ok(not game.battle.committed(), "아직 확정 전이다 (자가 점검 — 이 아래가 재는 것이 계획 화면이다)")

	fs._process(1.0 / 60.0)
	t.eq(fs._hulls_used, 1, "확정 전에도 선체가 하나 그려진다 — 놓은 배는 바다에 보인다")
	t.ok(fs._hulls[0].visible, "그 선체가 실제로 켜져 있다")
	var hull_xz := Vector2(fs._hulls[0].position.x, fs._hulls[0].position.z) * Look.TILE_PX
	t.ok(hull_xz.distance_to(Look.tile_point_px(g.tile_point(furthest))) < 0.01,
		"그리고 선체가 누른 칸 위에 있다 — 다른 데 그려진 것이 아니다")
	# The body it carries is on the deck too: a hull with nobody on it says the slot spent nothing.
	# ⚠ In TILE units, and the deck's own point is `tile_point_px(pos) / TILE_PX` — half a tile past
	# `tile_point`, which names a corner. Compared against the corner it is 0.71 out, which is the
	# diagonal and not a body somewhere else.
	var deck := Look.tile_point_px(g.tile_point(furthest)) / Look.TILE_PX
	var on_deck := 0
	for k in fs._sprites_used:
		var s: Sprite3D = fs._sprites[k]
		if Vector2(s.position.x, s.position.z).distance_to(deck) < 0.4:
			on_deck += 1
	t.ok(on_deck > 0, "탄 몸도 그 갑판 위에 그려진다 (%d개)" % on_deck)
	# And the undo has a picture: `game._ring_hit_at` takes the drop back when a press lands inside
	# `TARGET_RING_R_PX` of the landing, and nothing drew that ring until 2026-08-25.
	t.ok(_ground_verts_of(fs, Look.COL_BOAT).size() > 0,
		"그 배의 상륙 고리가 바닥 버퍼에 그려져 있다 — 무르는 조작에 그림이 생겼다")


## ⚠⚠ **`_sendable_tile(g)` IS DELETED, SUBJECT AND ALL (2026-08-27).** It walked the grid for the
## first tile with a `home_harbour_for(tile) >= 0` — **a BEACH a harbour could unload a boat onto** —
## and its one caller handed the answer to `Battle.send`. **`Grid.home_harbour_for` and `Battle.send`
## are both deleted**: the drag that put a body on a boat at a harbour is gone, `send` had no caller
## left in `src/`, and the derived harbour machinery went with it. There is no such thing as a
## "sendable tile" any more, so this could not be re-aimed — it could only be replaced by its
## successor, and its successor already stood two functions below it.
##
## ⚠ **WHAT IT KNEW THAT OUTLIVES IT, and it is the trap that cost a red round**: `send` took a BEACH
## and `summon` takes WATER inside the band. They are not interchangeable and a fixture that swaps one
## for the other gets a silent -1. **That is why the helper below is named for the KIND of tile it
## returns** rather than for the verb it feeds — the same reason `net_run.gd`'s
## `_summonable_water_on` carries "water" in its name.


## The `n`-th tile of the summon band on this grid — **WATER, always**, in row-major order. A stable
## pick rather than a hand-typed index, so a fixture stays valid if the island is ever re-cut.
##
## ⚠ **This was `_a_band_tile` until 2026-08-27.** It always returned water; the name did not say so,
## and it sat one screen away from a helper that returned a beach.
func _a_band_water_tile(g: Grid, n: int) -> int:
	var seen := 0
	for tile in g.w * g.h:
		if not g.can_summon_at(tile):
			continue
		if seen == n:
			return tile
		seen += 1
	return -1


## Parks the camera so `tile` sits at the CENTRE of the screen, and returns that screen point. The
## centre is the one screen point whose ground point is exact at every zoom, yaw and pitch —
## `screen_to_world_px(640, 360)` IS `_ground_centre_px()` — so this file never re-derives the
## pitched, turnable conversion (`net_camera` owns it; a second copy here would be free to drift).
##
## ⚠ No `_clamp_cam` and none needed: nothing on these rows pans or zooms afterwards, and the
## conversion the shell's `_tile_at` runs does not clamp either.
func _park_on(fs: FieldView, g: Grid, tile: int) -> Vector2:
	var world := Look.tile_point_px(g.tile_point(tile))
	fs.zoom = 1.0
	fs.cam_yaw_deg = Look.CAM_YAW_DEG
	fs.cam_pitch_deg = Look.CAM_PITCH_DEG
	fs.cam_px = world - fs._visible_ground_px() * 0.5
	return Look.viewport_size_px() * 0.5


## How many refusal marks are sitting in the field's transient drawer. Read off `_fx` rather than off
## the drawn rings, because these rows turn no frames.
func _refusals(fs: FieldView) -> int:
	var n := 0
	for raw: Dictionary in fs._fx:
		if int(raw["kind"]) == FieldView.FxKind.REFUSE:
			n += 1
	return n


## The ground-buffer vertices wearing exactly `col`, on the ground plane (x, z), in TILE units.
## Colour is what tells the aim ring (`COL_WIN`/`COL_LOSE`) from the route (`COL_ROUTE`) from the
## intent lines — the buffers hold one frame's whole floor and the colour is each mark's name tag.
func _ground_verts_of(fs: FieldView, col: Color) -> Array:
	var out := []
	for k in fs._g_v.size():
		if fs._g_c[k] == col:
			out.append(Vector2(fs._g_v[k].x, fs._g_v[k].z))
	return out


func _xz_centre(pts: Array) -> Vector2:
	var sum := Vector2.ZERO
	for p: Vector2 in pts:
		sum += p
	return sum / float(maxi(1, pts.size()))


func _max_dist_xz(pts: Array, from: Vector2) -> float:
	var out := 0.0
	for p: Vector2 in pts:
		out = maxf(out, p.distance_to(from))
	return out


func _min_dist_xz(pts: Array, from: Vector2) -> float:
	var out := 1e9
	for p: Vector2 in pts:
		out = minf(out, p.distance_to(from))
	return out


## Distance from `p` to the segment `a`..`b`, for measuring how far a route's interior waypoint sits
## off its endpoints' chord — which is exactly what a straightened polyline erases.
func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	if ab.length_squared() <= 0.000001:
		return p.distance_to(a)
	var k := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * k)


## The pooled sprites wearing the ghost tint — the aim's landing fan, and nothing else wears it.
func _ghost_sprites(fs: FieldView) -> Array:
	var want := Look.beast_tint(Look.ghost_tint())
	var out := []
	for k in fs._sprites_used:
		var s: Sprite3D = fs._sprites[k]
		if s.modulate == want:
			out.append(s)
	return out


## The captured box whose resting rectangle is slot `i`'s. Matched by POSITION rather than by index in
## the capture array, so the row still names the right box if the draw order is ever changed.
func _box_at(hs: HudSpy, i: int, n: int) -> Dictionary:
	var want := Look.slot_rect_px(i, n)
	for raw: Dictionary in hs.boxes:
		if (raw["rect"] as Rect2).position.distance_to(want.position) < 0.01:
			return raw
	return {}


## The captured BAR whose rail is slot `i`'s, matched by rectangle for the reason `_box_at` is.
func _bar_at(hs: HudSpy, i: int, n: int) -> Dictionary:
	var want := Look.slot_bar_rect_px(i, n)
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


## Walks the shell from the TITLE down onto its first island, through the real input door and nothing
## else. **One press: 시작하기.**
##
## ⚠⚠ **IT WAS THREE PRESSES — 시작하기 · the opening card · 완료 — AND 티켓 12 DELETED TWO OF THEM**
## (2026-08-27, the user: ***"Starting means the game starts, right then."***). A run opens on the
## island now; there is no `PICK` and no `REFIT` between the title and the board, so pressing where
## the card used to be would land on the island itself.
##
## ⚠ **Nothing is poked.** Assigning `game.run` or reaching for `_start_run()` would leave every row
## below measuring the poke instead of the wiring — and the wiring is the whole reason `Game` builds
## its six children inside `_ready()`.
## ⚠ **The title's own visibility is asserted here on purpose.** It used to be taken down inside
## `_enter_pick_screen`, which the shell no longer walks through; left there, the island would open
## underneath a title nobody could see past, and every row below would still be green.
func _walk_from_the_title_to_the_island(t, game: Game) -> void:
	t.ok(game.run == null and game.battle == null,
		"켜자마자는 타이틀이다 — 판도 전투도 아직 없다 (자가 점검)")
	game._unhandled_input(_click(Look.title_slot_hit_rect_px(TitleView.SLOT_START).get_center()))
	t.eq(game.run.state(), Run.State.BATTLE, "시작하기를 누르자 곧장 섬이 열렸다 — 사이에 아무 화면도 없다")
	t.ok(not game.title_view.visible, "그리고 타이틀이 내려갔다 — 섬 위에 안 덮여 있다")
	t.ok(game.battle != null and game.battle.grid != null,
		"그래서 아래 모든 줄이 밟고 설 전투와 판이 생겼다 (자가 점검)")
