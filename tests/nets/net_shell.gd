extends RefCounted
## The shell, driven for real: `Game` is added to the live tree, `_ready()` builds its three children,
## frames are pumped so `_draw()` actually turns, and the arguments the hooks receive are read back and
## compared against what the sim is holding at that instant.
##
## **Nothing here is pre-set before `_ready()`.** The first assertions are that every field is null on a
## freshly constructed `Game` — pre-setting a field lets the line that does the wiring be deleted with
## the round still green and the game showing nothing, and this repo has paid for that shape before.
##
## **The three real views are then replaced by spies and `_open_island()` is called again.** That is
## deliberate and it is what closes the wiring: a spy starts with a null `battle`, so if the
## `field_view.setup(...)` / `hud_view.bind(...)` / `panel_view.bind(...)` lines were deleted the spy
## would draw nothing and every capture below would go red. Swapping AFTER `_ready()` keeps the "never
## pre-set a field" rule intact — `_ready` built the real three, on its own, and that was measured
## first.
##
## ⚠ **The sim's own clock is stopped for the comparisons** (`game.set_process(false)`), because a
## captured frame and a value read afterwards are not the same instant otherwise, and a tolerance wide
## enough to absorb that is wide enough to absorb the bug. That the shell DOES drive the clock is
## measured separately, one assertion earlier, by watching `battle.elapsed` move. From that point the
## shell is advanced by calling `game._process(dt)` with the exact delta a check needs — which is what
## makes the two holds (`combat-juice`, items "승패 전환" and "부리 부착") measurable at all: at a
## headless 6.9 ms a frame, waiting 0.8 s out through the tree would be 116 frames of guessing.
##
## Two mutations must redden this net: deleting one `add_child` in `_ready`, and making a `look.gd`
## layout function return a bare `Rect2()`. The second is why every captured rectangle is checked for
## AREA as well as for landing inside the viewport — an empty rect sits at the origin and is "inside"
## a 1280x720 screen quite happily.


## Spies. Each one clears at the top of its own `_draw` and then calls `super()`, so what is read back
## afterwards is exactly ONE frame's worth of hook calls rather than however many frames were pumped.
##
## **Every one of the twenty leaves is overridden here, and that is not bookkeeping.** An override
## whose signature does not match the parent does not bind — Godot barks a parse error for a mismatch,
## but a hook simply left out binds to nothing at all and the REAL `draw_*` runs headless while the
## capture array stays empty and the checks about it read as "nothing was drawn".
##
## **`_seq` is the layer contract.** The arrays are per hook, so the order BETWEEN hooks cannot be
## recovered from them at all — and the order is a contract: a filled halo at 1.35x radius drawn after
## `_paint_body` covers a 2 px outline and a 3 px dot completely, and the body disappears with the
## round green. A check that reads only final state can never measure a traversal order.
class FieldSpy extends FieldView:
	var draws := 0
	var seq := 0
	var tiles := []
	var docks := []
	var bodies := []
	var beaks := []
	var hps := []
	var boats_seen := []
	var shots := []
	var halos := []
	var rings := []
	var target_lines := []
	var sparks := []

	func _draw() -> void:
		tiles.clear()
		docks.clear()
		bodies.clear()
		beaks.clear()
		hps.clear()
		boats_seen.clear()
		shots.clear()
		halos.clear()
		rings.clear()
		target_lines.clear()
		sparks.clear()
		seq = 0
		super()
		draws += 1

	func _bump() -> int:
		seq += 1
		return seq - 1

	func _paint_tile(rect: Rect2, fill: Color, line_colour: Color, line_width: float) -> void:
		tiles.append({"seq": _bump(), "rect": rect, "fill": fill, "line": line_colour,
			"width": line_width})

	func _paint_dock(rect: Rect2, colour: Color, outline_width: float) -> void:
		docks.append({"seq": _bump(), "rect": rect, "colour": colour, "width": outline_width})

	# ⚠ `squash` is the seventh parameter and it was appended, not inserted. An override that kept the
	# old six-arg form does not bind at all.
	func _paint_body(centre: Vector2, radius: float, corner: float, colour: Color,
			outline_width: float, dot_radius: float, squash: Vector2) -> void:
		bodies.append({"seq": _bump(), "centre": centre, "radius": radius, "corner": corner,
			"colour": colour, "width": outline_width, "dot": dot_radius, "squash": squash})

	func _paint_beak(tip: Vector2, left: Vector2, right: Vector2, colour: Color) -> void:
		beaks.append({"seq": _bump(), "tip": tip, "left": left, "right": right, "colour": colour})

	func _paint_hp(back: Rect2, back_colour: Color, fill: Rect2, fill_colour: Color) -> void:
		hps.append({"seq": _bump(), "back": back, "back_colour": back_colour, "fill": fill,
			"fill_colour": fill_colour})

	func _paint_boat(rect: Rect2, colour: Color) -> void:
		boats_seen.append({"seq": _bump(), "rect": rect, "colour": colour})

	func _paint_shot(from: Vector2, to: Vector2, colour: Color, width: float) -> void:
		shots.append({"seq": _bump(), "from": from, "to": to, "colour": colour, "width": width})

	func _paint_halo(centre: Vector2, radius: float, colour: Color) -> void:
		halos.append({"seq": _bump(), "centre": centre, "radius": radius, "colour": colour})

	func _paint_ring(centre: Vector2, radius: float, colour: Color, width: float) -> void:
		rings.append({"seq": _bump(), "centre": centre, "radius": radius, "colour": colour,
			"width": width})

	func _paint_target_line(from: Vector2, to: Vector2, colour: Color, width: float) -> void:
		target_lines.append({"seq": _bump(), "from": from, "to": to, "colour": colour,
			"width": width})

	func _paint_spark(points: PackedVector2Array, colour: Color, width: float) -> void:
		sparks.append({"seq": _bump(), "points": points, "colour": colour, "width": width})


class HudSpy extends HudView:
	var draws := 0
	var seq := 0
	var timers := []
	var berths := []
	var loads := []
	var keys := []
	var enemies := []

	func _draw() -> void:
		timers.clear()
		berths.clear()
		loads.clear()
		keys.clear()
		enemies.clear()
		seq = 0
		super()
		draws += 1

	func _bump() -> int:
		seq += 1
		return seq - 1

	func _paint_timer(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		timers.append({"seq": _bump(), "face": face, "at": at, "text": text, "fsize": fsize,
			"col": col})

	func _paint_berth(rect: Rect2, col: Color) -> void:
		berths.append({"seq": _bump(), "rect": rect, "col": col})

	func _paint_load(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		loads.append({"seq": _bump(), "face": face, "at": at, "text": text, "fsize": fsize,
			"col": col})

	func _paint_key(face: Font, rect: Rect2, bg: Color, text: String, at: Vector2, fsize: int,
			col: Color) -> void:
		keys.append({"seq": _bump(), "face": face, "rect": rect, "bg": bg, "text": text, "at": at,
			"fsize": fsize, "col": col})

	func _paint_enemies_left(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		enemies.append({"seq": _bump(), "face": face, "at": at, "text": text, "fsize": fsize,
			"col": col})


class PanelSpy extends PanelView:
	var draws := 0
	var seq := 0
	var panels := []
	var messages := []
	var entries := []
	var buttons := []

	func _draw() -> void:
		panels.clear()
		messages.clear()
		entries.clear()
		buttons.clear()
		seq = 0
		super()
		draws += 1

	func _bump() -> int:
		seq += 1
		return seq - 1

	func _paint_panel(rect: Rect2, col: Color) -> void:
		panels.append({"seq": _bump(), "rect": rect, "col": col})

	func _paint_message(face: Font, rect: Rect2, bg: Color, text: String, at: Vector2, fsize: int,
			col: Color) -> void:
		messages.append({"seq": _bump(), "face": face, "rect": rect, "bg": bg, "text": text,
			"at": at, "fsize": fsize, "col": col})

	func _paint_roster_entry(face: Font, rect: Rect2, bg: Color, text: String, at: Vector2,
			fsize: int, col: Color) -> void:
		entries.append({"seq": _bump(), "face": face, "rect": rect, "bg": bg, "text": text,
			"at": at, "fsize": fsize, "col": col})

	func _paint_button(face: Font, rect: Rect2, bg: Color, text: String, at: Vector2, fsize: int,
			col: Color) -> void:
		buttons.append({"seq": _bump(), "face": face, "rect": rect, "bg": bg, "text": text,
			"at": at, "fsize": fsize, "col": col})


func run(t) -> void:
	var game := Game.new()

	# -- before the tree: every field is null ------------------------------------------------------
	# Nothing in `game.gd` is `@onready` or `@export`, and this is the assertion that keeps it that
	# way. A field filled in from outside — or by the engine — before `_ready` means the wiring line
	# can be deleted and nothing anywhere goes red while the screen stays empty.
	t.ok(game.field_view == null and game.hud_view == null and game.panel_view == null,
		"_ready 전에는 뷰 셋이 전부 null 이다 — 미리 채우면 배선 줄을 지워도 초록이다")
	t.ok(game.run == null and game.battle == null, "_ready 전에는 run 도 battle 도 null 이다")
	t.eq(game._hold_sec, 0.0, "_ready 전에는 붙들고 있는 것이 없다")
	t.eq(game._pending_beak, -1, "_ready 전에는 붙일 부리도 없다")

	t.root.add_child(game)
	await t.pump_frames(2)

	# -- _ready built the children, in code --------------------------------------------------------
	t.eq(game.get_child_count(), 3, "_ready 가 자식 셋을 만들었다")
	t.ok(game.field_view != null and game.hud_view != null and game.panel_view != null,
		"세 뷰가 전부 생겼다")
	t.ok(game.get_child(0) == game.field_view and game.get_child(1) == game.hud_view
		and game.get_child(2) == game.panel_view,
		"자식 순서가 field -> hud -> panel 이다 (Node2D 형제의 그리기 순서가 곧 이 순서다)")
	# Named by hand, because `get_class()` on all three is "Node2D" and three identical labels do not
	# say which one went missing — a failure log that cannot narrow the cause is half a failure log.
	var built := {"field_view": game.field_view, "hud_view": game.hud_view, "panel_view": game.panel_view}
	for label: String in built:
		var v: Node2D = built[label]
		t.ok(v.is_inside_tree(), "%s 가 트리에 붙어 있다" % label)
		t.ok(v.get_parent() == game, "%s 의 부모가 Game 이다" % label)
		t.ok(v.visible, "%s 가 visible 이다" % label)

	t.ok(game.run != null, "_ready 가 Run 을 만들었다")
	t.ok(game.battle != null, "_ready 가 첫 섬을 열었다")
	t.eq(game.run.island_index, 0, "첫 섬은 0번이다")
	t.eq(game.run.army.living_count(), Rules.START_MELEE + Rules.START_RANGED,
		"시작 병력이 10명이다")

	# The wiring itself, by identity and not by shape: the field must hold the SAME `Battle` and the
	# SAME `Army` the shell is stepping, or HP carries on one side of the screen and not the other.
	t.ok(game.field_view.battle == game.battle, "field_view 가 셸과 같은 Battle 을 본다")
	t.ok(game.field_view.army == game.run.army, "field_view 가 run 의 Army 를 그대로 본다")
	t.eq(game.field_view.rows.size(), Look.GRID_H, "field_view 가 섬 18줄을 받았다")
	t.ok(game.hud_view.battle == game.battle, "hud_view 가 셸과 같은 Battle 을 본다")
	t.ok(game.panel_view.run == game.run, "panel_view 가 셸과 같은 Run 을 본다")

	# -- swap in the spies and re-open the island --------------------------------------------------
	for v: Node2D in [game.field_view, game.hud_view, game.panel_view]:
		game.remove_child(v)
		v.queue_free()
	var fs := FieldSpy.new()
	var hs := HudSpy.new()
	var ps := PanelSpy.new()
	game.field_view = fs
	game.hud_view = hs
	game.panel_view = ps
	game.add_child(fs)
	game.add_child(hs)
	game.add_child(ps)
	t.ok(fs.battle == null and hs.battle == null and ps.run == null,
		"바꿔 끼운 스파이는 아직 아무것도 모른다 — 배선은 _open_island 가 한다")
	game._open_island()
	t.ok(fs.battle == game.battle and fs.army == game.run.army,
		"_open_island 가 field_view.setup 을 실제로 불렀다")
	t.ok(hs.battle == game.battle, "_open_island 가 hud_view.bind 를 실제로 불렀다")
	t.ok(ps.run == game.run, "_open_island 가 panel_view.bind 를 실제로 불렀다")

	# The shell really drives the clock. Measured with `_process` still on, before it is turned off
	# for the frame-exact comparisons below.
	await t.pump_frames(3)
	t.ok(game.battle.elapsed > 0.0, "셸의 _process 가 battle.step 을 진짜 돌렸다 (elapsed %.4f)"
		% game.battle.elapsed)
	t.ok(fs.draws >= 1, "field_view 의 _draw 가 트리 위에서 진짜 돌았다 (%d프레임)" % fs.draws)
	t.ok(hs.draws >= 1, "hud_view 의 _draw 가 진짜 돌았다 (%d프레임)" % hs.draws)
	t.ok(ps.draws >= 1, "panel_view 의 _draw 가 진짜 돌았다 (%d프레임)" % ps.draws)

	# From here the sim is frozen, so a captured frame and a value read after it are the same instant.
	game.set_process(false)
	await t.pump_frames(2)
	var b: Battle = game.battle
	# The three views keep processing — only the SHELL stopped — so they drain `battle.events` every
	# frame from here on. That is only safe because the list is empty: a leftover event would be
	# re-drained on every pumped frame and the same blow would flash, shake and lunge forever.
	t.eq(b.events.size(), 0, "얼린 시점에 사건 목록이 비어 있다 — 뷰가 같은 사건을 매 프레임 다시 퍼가고 있지 않다")

	# -- the field, argument by argument -----------------------------------------------------------
	# The terrain pass is one margin ring wider than the grid, because the grid fills the viewport
	# exactly and any shake would otherwise expose bare ground along the edges.
	var margin := Look.WATER_MARGIN_TILES
	var wt := Look.GRID_W + 2 * margin
	var ht := Look.GRID_H + 2 * margin
	# ⚠ **680 and 576 are written out as literals**, not as `wt * ht`. A check whose bounds come from
	# the thing it checks proves nothing: with the count derived from `Look.WATER_MARGIN_TILES`,
	# setting that constant to 0 would move the expectation and the reality together and the margin
	# could vanish with the round green.
	t.eq(wt * ht, 680, "물 여백까지 세면 680칸이다 (34 x 20) — 여백 상수가 0이 되면 여기가 문다")
	t.eq(Look.GRID_W * Look.GRID_H, 576, "격자 자체는 576칸이다")
	t.eq(fs.tiles.size(), 680, "지형을 물 여백까지 680칸 그렸다")
	var tile_bad := 0
	var inner_rects: Array[Rect2] = []
	for i in fs.tiles.size():
		var tx: int = i % wt - margin
		var ty: int = i / wt - margin
		var got: Rect2 = fs.tiles[i]["rect"]
		if got != Look.tile_rect_px(tx, ty):
			tile_bad += 1
		if tx >= 0 and tx < Look.GRID_W and ty >= 0 and ty < Look.GRID_H:
			inner_rects.append(got)
	t.eq(tile_bad, 0, "680칸이 전부 자기 자리의 사각형을 받았다 (행 우선, 여백 한 칸 포함)")
	t.eq(inner_rects.size(), 576, "그중 격자 안쪽이 576칸이다")
	# ⚠ The margin is why the tiles below are filtered before the on-screen check: `tile_rect_px(-1,
	# -1)` really is at (-40, -40), so feeding all 680 in would break "everything lands inside
	# 1280x720" for the 104 that are supposed to be outside it — and widening the screen rectangle
	# instead would kill that check for the docks, the HP bars and the HUD at the same time.
	t.ok(Look.tile_rect_px(-margin, -margin).position.x < 0.0,
		"여백 타일은 화면 밖에서 시작한다 — 그래서 화면-안 검사에서 빼야 한다")
	t.eq(fs.tiles[0]["fill"], Look.COL_WATER,
		"여백 칸은 COL_WATER 를 직접 받는다 — 격자 밖에는 범례 문자가 없다")
	t.eq(fs.tiles[margin * wt + margin]["fill"],
		Look.terrain_colour_of_char(str(game.field_view.rows[0])[0]),
		"격자 첫 칸의 색은 그 칸의 범례 문자에서 나왔다")
	t.eq(float(fs.tiles[0]["width"]), Look.GRID_LINE_WIDTH_PX, "격자선 굵기가 look.gd 값이다")

	t.eq(fs.docks.size(), b.dock_count(), "부두를 sim 이 가진 수만큼 그렸다 (%d개)" % b.dock_count())
	var dock_bad := 0
	for d in b.dock_count():
		var tile := b.dock_tile(d)
		var want := Look.tile_rect_px(tile % b.grid.w, tile / b.grid.w)
		if fs.docks[d]["rect"] != want:
			dock_bad += 1
	t.eq(dock_bad, 0, "부두 사각형이 sim 의 부두 타일과 같은 자리다")

	# The bodies are the enemies the sim says are alive, in the sim's own order, at the sim's own
	# positions. Nothing here is recomputed from a screen coordinate — the comparison runs the other
	# way, from what `battle` holds to what the hook was handed.
	var live_enemies := []
	for e in b.enemy_alive.size():
		if b.enemy_alive[e] != 0:
			live_enemies.append(e)
	t.ok(live_enemies.size() > 0, "섬 0에 살아 있는 적이 있다 (%d마리)" % live_enemies.size())
	t.eq(b.ashore_ids().size(), 0, "아직 상륙한 병사는 없다")
	t.eq(fs.bodies.size(), live_enemies.size(), "몸통 수 = 살아 있는 적 수 + 상륙 병사 수")
	var body_bad := 0
	for k in live_enemies.size():
		var e: int = live_enemies[k]
		var et := int(b.enemy_type[e])
		var got: Dictionary = fs.bodies[k]
		if got["centre"] != Look.tile_point_px(b.enemy_pos[e]):
			body_bad += 1
		elif float(got["radius"]) != Look.body_radius_of(et):
			body_bad += 1
		elif float(got["corner"]) != Look.body_corner_radius_of(et):
			body_bad += 1
		elif got["colour"] != Look.body_colour_of(true):
			body_bad += 1
		elif got["squash"] != Vector2.ONE:
			body_bad += 1
	t.eq(body_bad, 0, "몸통마다 중심·반지름·모서리·색·스쿼시가 sim 의 그 적에게서 나왔다")
	t.eq(fs.hps.size(), fs.bodies.size(), "몸통마다 HP 막대가 하나씩 붙었다")
	t.eq(fs.beaks.size(), 0, "부리 단 병사가 없으니 부리도 안 그렸다")
	t.eq(fs.boats_seen.size(), 0, "아직 배가 없으니 배도 안 그렸다")
	# Nothing has been hit, nothing has died and no soldier is ashore, so every effect leaf is silent.
	# This is the floor under every "it drew one" a later net makes: a leaf that fired unconditionally
	# would be indistinguishable from a leaf that fired for the right reason.
	t.eq(fs.shots.size() + fs.halos.size() + fs.sparks.size() + fs.rings.size(), 0,
		"아무 일도 안 일어난 프레임에는 예광선·헤일로·파편·링이 하나도 없다")
	t.eq(fs.target_lines.size(), 0, "표적이 상륙 전이라 타겟 선도 없다")

	# -- the layer order, through the spies' shared counter ----------------------------------------
	# The per-hook arrays cannot say which hook ran first, and the layering IS a contract. `_seq` is
	# the only thing here that measures the PROCESS rather than the final state.
	var seen_seq := {}
	var call_total := 0
	for arr: Array in [fs.tiles, fs.docks, fs.bodies, fs.beaks, fs.hps, fs.boats_seen, fs.shots,
			fs.halos, fs.rings, fs.target_lines, fs.sparks]:
		for it: Dictionary in arr:
			seen_seq[int(it["seq"])] = true
			call_total += 1
	t.eq(seen_seq.size(), call_total,
		"훅 호출 %d번이 전부 서로 다른 순번을 들고 있다 — 순번을 안 적은 훅이 없다" % call_total)
	t.ok(seen_seq.has(0) and seen_seq.has(call_total - 1),
		"순번이 0에서 시작해 빈칸 없이 끝까지 간다 — _draw 머리에서 되감긴다")
	t.ok(_seq_max(fs.tiles) < _seq_min(fs.docks), "층 1 지형이 층 2 부두보다 먼저 그려졌다")
	t.ok(_seq_max(fs.docks) < _seq_min(fs.bodies), "층 2 부두가 층 7 몸보다 먼저 그려졌다")

	# -- the HUD, and the number on it coming from the sim -----------------------------------------
	t.eq(hs.timers.size(), 1, "타이머를 한 번 그렸다")
	t.eq(str(hs.timers[0]["text"]), "남은 시간 %.1f" % b.time_left(), "타이머 글자가 sim 의 남은 시간이다")
	t.eq(hs.timers[0]["at"], Look.HUD_TIMER_POS_PX, "타이머 위치가 look.gd 값이다")
	t.eq(hs.berths.size(), Rules.FLEET, "선착장을 함대 수만큼 그렸다")
	var berth_bad := 0
	for k in hs.berths.size():
		if hs.berths[k]["rect"] != Look.berth_rect_px(k):
			berth_bad += 1
	t.eq(berth_bad, 0, "선착장 사각형이 look.gd 가 계산한 자리다")
	t.eq(hs.loads.size(), 1, "탑승 수를 한 번 그렸다")
	t.eq(str(hs.loads[0]["text"]), "탑승 0/%d" % Rules.CAP, "아직 아무도 안 태웠다고 쓰여 있다")
	t.eq(hs.keys.size(), HudView.key_slot_count(), "키 슬롯을 둘 그렸다")
	t.eq(str(hs.keys[0]["text"]), "1  %s  %d" % [HudView.type_label(Rules.CELL_MELEE), Rules.START_MELEE],
		"1번 칸이 근접 예비 인원을 sim 에서 읽어 썼다")
	t.eq(str(hs.keys[1]["text"]), "2  %s  %d" % [HudView.type_label(Rules.CELL_RANGED), Rules.START_RANGED],
		"2번 칸이 원거리 예비 인원을 sim 에서 읽어 썼다")
	t.eq(hs.enemies.size(), 1, "남은 적 수를 한 번 그렸다")
	t.eq(str(hs.enemies[0]["text"]), "적 %d" % b.enemies_left(), "남은 적 글자가 sim 의 수다")
	t.eq(ps.panels.size(), 0, "전투 중에는 패널이 한 번도 안 그려졌다")
	t.ok(hs.timers[0]["seq"] < hs.berths[0]["seq"] and _seq_max(hs.berths) < hs.loads[0]["seq"]
		and hs.loads[0]["seq"] < hs.keys[0]["seq"] and _seq_max(hs.keys) < hs.enemies[0]["seq"],
		"HUD 도 타이머 -> 선착장 -> 탑승 -> 키 -> 남은 적 순서로 그린다")

	# **The resting look of key slot 0**, captured before any press. Item 8's whole content is the
	# DIFFERENCE from this, so it has to be read once while nothing has happened yet.
	var rest_key_rect: Rect2 = hs.keys[0]["rect"]
	var rest_key_at: Vector2 = hs.keys[0]["at"]
	t.eq(hs.keys[0]["bg"], Look.COL_BUTTON, "아직 아무 키도 안 눌러서 키 상자가 기본색이다 (바닥)")
	t.eq(rest_key_rect, Look.key_rect_px(0), "그리고 안 흔들린 자리에 있다")

	# -- every rectangle that reached a hook lands inside the viewport, with area -------------------
	# ⚠ AREA as well as containment. `Rect2()` sits at the origin with zero size and is perfectly
	# "inside" a 1280x720 screen, so a layout function that collapsed to a bare `Rect2()` would pass a
	# containment-only check while nothing at all appeared on screen.
	var rects: Array[Rect2] = []
	for r: Rect2 in inner_rects:
		rects.append(r)
	for it: Dictionary in fs.docks:
		rects.append(it["rect"])
	for it: Dictionary in fs.hps:
		rects.append(it["back"])
	for it: Dictionary in hs.berths:
		rects.append(it["rect"])
	for it: Dictionary in hs.keys:
		rects.append(it["rect"])
	_rects_land_on_screen(t, "전투 화면", rects)

	# -- the keys and the dock click, through the shell's own input path ----------------------------
	t.eq(b.pending.size(), 0, "누르기 전에는 탑승 인원이 0이다")
	game._unhandled_input(_key(KEY_1))
	game._unhandled_input(_key(KEY_1))
	t.eq(b.pending.size(), 2, "1키 두 번에 병사 둘이 배에 올랐다 (셸이 Input 을 읽는 유일한 곳이다)")
	await t.pump_frames(2)
	t.eq(str(hs.loads[0]["text"]), "탑승 2/%d" % Rules.CAP,
		"sim 이 둘을 태우자 화면의 글자도 둘이 됐다")

	var dock0 := b.dock_tile(0)
	var dock_rect := Look.tile_rect_px(dock0 % b.grid.w, dock0 / b.grid.w)
	var dock_centre := dock_rect.get_center()
	game._unhandled_input(_click(dock_centre))
	t.eq(b.boats.size(), 1, "부두를 누르자 배가 떴다")
	await t.pump_frames(2)
	t.eq(fs.boats_seen.size(), 1, "뜬 배가 화면에도 하나 그려졌다")
	var boat: Dictionary = b.boats[0]
	var boat_rect: Rect2 = fs.boats_seen[0]["rect"]
	t.eq(boat_rect.size, Vector2(Look.BOAT_W_PX, Look.BOAT_H_PX), "배 사각형 크기가 look.gd 값이다")
	t.eq(boat_rect.get_center(), Look.tile_point_px(boat["pos"]), "배가 sim 이 말한 자리에 그려졌다")
	t.eq(b.pending.size(), 0, "떠난 배가 탑승 인원을 데려갔다")

	# -- item 8: the shell hands the bool back, and the two answers look different ------------------
	# `load_soldier` and `launch` already return a bool and `game.gd` used to throw both away. That
	# bool is the ONLY thing separating "the boat is full" from "the game is not listening".
	game._unhandled_input(_key(KEY_1))
	await t.pump_frames(1)
	var ok_bg: Color = hs.keys[0]["bg"]
	t.ok(ok_bg != Look.COL_BUTTON, "먹힌 키가 기본색에서 벗어났다 (바닥)")
	t.eq(hs.keys[0]["rect"], rest_key_rect, "먹힌 키는 안 흔들린다 — 두 답이 같은 말을 하면 안 된다")
	# Drain the melee reserve so the next press is refused for a reason the sim owns.
	for _n in 3:
		game._unhandled_input(_key(KEY_1))
	t.eq(hs.reserve_count(Rules.CELL_MELEE), 0, "근접 예비가 바닥났다 — 다음 1키는 거절된다")
	var pending_full := b.pending.size()
	game._unhandled_input(_key(KEY_1))
	t.eq(b.pending.size(), pending_full, "그 1키는 sim 에서 실제로 거절됐다")
	await t.pump_frames(1)
	var no_bg: Color = hs.keys[0]["bg"]
	t.ok(no_bg != ok_bg, "거절된 키의 색이 먹힌 키와 다르다")
	t.ok(no_bg != Look.COL_BUTTON, "그리고 기본색도 아니다 — 아무 일도 안 일어난 것처럼 보이지 않는다 (바닥)")
	var key_shift: Vector2 = Vector2(hs.keys[0]["rect"].position) - rest_key_rect.position
	t.ok(key_shift.length() > 0.0, "거절된 키 상자가 흔들렸다 (%.2f px)" % key_shift.length())
	t.ok(absf(key_shift.y) <= 0.0, "흔들림은 좌우뿐이다")
	# ⚠ A tolerance and not `==`. Both sides are differences of sums of the same floats and they
	# disagreed by one ULP on one frame delta and agreed on the next — an exact compare here is a
	# check that reddens at random. 0.01 px is two orders below the 2.0 px snap floor this document
	# set, so it cannot absorb the bug it exists to catch: shaking the box alone leaves the label at
	# exactly 0.
	var label_shift: Vector2 = Vector2(hs.keys[0]["at"]) - rest_key_at
	t.ok(label_shift.distance_to(key_shift) < 0.01,
		"글자도 상자와 같은 오프셋만큼 움직였다 (상자 %.3f · 글자 %.3f) — 상자만 흔들면 글자가 밖으로 나간다"
		% [key_shift.x, label_shift.x])

	# -- item 11: the dock click is corrected by the shake, and the correction really bites ---------
	# `field_view.position` IS the assigned shake offset. The probe below is a point inside the DRAWN
	# dock rectangle and outside the resting one, so a shell that forgot the one-line correction
	# cannot pass it by accident.
	fs._shake_amp = Look.SHAKE_MAX_PX
	fs._shake_left = Look.SHAKE_SEC * 0.5
	fs._process(0.0)
	t.ok(fs.position.length() > 0.0, "화면이 실제로 흔들리고 있다 (%.2f, %.2f)"
		% [fs.position.x, fs.position.y])
	var probe := dock_centre + fs.position + Vector2(0.0, 19.0)
	t.ok(not dock_rect.has_point(probe),
		"그 점은 보정 없이는 부두 사각형 밖이다 — 이 검사가 실제로 문다 (바닥)")
	t.ok(dock_rect.has_point(probe - fs.position), "보정하면 부두 안이다")
	var boats_before := b.boats.size()
	game._unhandled_input(_click(probe))
	t.eq(b.boats.size(), boats_before + 1,
		"흔든 프레임에 그려진 부두를 누르면 배가 뜬다 — 보이는데 안 눌리는 띠가 없다")

	# -- item 10 · item 4: the verdict hold ---------------------------------------------------------
	# A synthetic kill, because reaching a real win here would take a whole island of stepping and the
	# thing under test is the SHELL, not the fight. The last enemy dying is the only state that
	# matters to `_phase_clock`.
	t.ok(Look.HOLD_OUTCOME_SEC > 0.0 and Look.HOLD_BEAK_SEC > 0.0,
		"두 hold 가 0초가 아니다 — 0이면 이 절 전체가 아무것도 안 재게 된다 (바닥)")
	var isle0: Battle = game.battle
	isle0.enemy_alive.fill(0)
	game._process(0.016)
	t.eq(isle0.outcome(), Battle.Outcome.WON, "마지막 적이 죽어 승리가 확정됐다")
	t.ok(game.battle == isle0,
		"이긴 프레임에 셸이 다음 섬을 안 열었다 — 그래서 마지막 파열 링에 재생될 시간이 생긴다")
	t.eq(game._hold_sec, Look.HOLD_OUTCOME_SEC, "대신 HOLD_OUTCOME_SEC 만큼 붙들었다")
	t.eq(game.run.state(), Run.State.BATTLE,
		"hold 동안 run 은 아직 BATTLE 이다 — 그래서 입구를 한 줄로 막아야 한다")
	# The one line in `_unhandled_input`. Without it 1/2 keeps boarding an island that is already won,
	# and a boat launched into a sim that is not stepping is thrown away by `_close_island`.
	var pending_at_hold := isle0.pending.size()
	var boats_at_hold := isle0.boats.size()
	game._unhandled_input(_key(KEY_2))
	t.eq(isle0.pending.size(), pending_at_hold, "hold 중에는 2키가 안 먹는다")
	game._unhandled_input(_click(dock_centre))
	t.eq(isle0.boats.size(), boats_at_hold, "hold 중에는 부두 클릭도 안 먹는다")
	var elapsed_at_hold := isle0.elapsed
	game._process(0.1)
	t.eq(isle0.elapsed, elapsed_at_hold, "hold 중에는 step 도 안 돈다 — 제한 시간이 안 흐른다")
	t.ok(game.battle == isle0, "그리고 0.1초 뒤에도 아직 같은 섬이다")
	game._process(Look.HOLD_OUTCOME_SEC)
	t.eq(game._hold_sec, 0.0, "hold 가 끝났다")
	t.ok(game.battle != isle0, "그제서야 다음 섬이 열렸다 (바닥 — 영원히 안 열리면 여기가 문다)")
	t.eq(game.run.island_index, 1, "섬 0을 이기고 섬 1로 넘어갔다")
	t.ok(fs.battle == game.battle, "새 섬의 Battle 이 화면에 다시 물렸다")
	t.eq(fs.position, Vector2.ZERO, "setup 이 흔들림까지 0으로 지웠다")
	b = game.battle

	# -- the reward panel, reached through Run's own API --------------------------------------------
	# `finish_island(true)` and not a poke at a private field: island 1 pays the beak and opens the
	# REWARD state. Driving it any other way would measure the fixture.
	game.run.finish_island(true)
	t.eq(game.run.state(), Run.State.REWARD, "섬 1을 이기자 부리 고르기가 열렸다")
	game._open_island()
	await t.pump_frames(2)
	t.eq(ps.panels.size(), 1, "보상 화면에서 패널이 그려졌다")
	t.eq(ps.panels[0]["rect"], Look.panel_rect_px(), "패널 사각형이 look.gd 가 계산한 자리다")
	t.eq(ps.messages.size(), 1, "안내 문구를 한 번 그렸다")
	t.eq(str(ps.messages[0]["text"]), PanelView.MSG_REWARD, "부리를 고르라고 쓰여 있다")
	var roster: Array = game.panel_view.roster_ids()
	t.eq(roster.size(), Rules.START_MELEE + Rules.START_RANGED + Rules.REWARD_MELEE
		+ Rules.REWARD_RANGED, "명단이 13명이다 (10 + 보상 3)")
	t.eq(ps.entries.size(), roster.size(), "명단에 있는 만큼 항목을 그렸다")
	var entry_bad := 0
	for e in ps.entries.size():
		if ps.entries[e]["rect"] != Look.roster_entry_rect_px(e):
			entry_bad += 1
	t.eq(entry_bad, 0, "명단 항목이 look.gd 가 계산한 자리에 하나씩 놓였다")
	t.eq(ps.buttons.size(), 0, "보상 화면에는 다시 하기 단추가 없다")
	t.ok(ps.panels[0]["seq"] < ps.messages[0]["seq"]
		and ps.messages[0]["seq"] < _seq_min(ps.entries),
		"패널 -> 문구 -> 명단 순서로 그린다 — 배경이 뒤에 오면 전부 덮인다")
	var panel_rects: Array[Rect2] = []
	for it: Dictionary in ps.panels:
		panel_rects.append(it["rect"])
	for it: Dictionary in ps.messages:
		panel_rects.append(it["rect"])
	for it: Dictionary in ps.entries:
		panel_rects.append(it["rect"])
	_rects_land_on_screen(t, "보상 패널", panel_rects)

	# -- item 9: the beak is bolted on AFTER the hold, not on the click ----------------------------
	# `run.apply_beak` ends in `_advance()`, which puts the run back into BATTLE — and the panel stops
	# drawing the instant it does. Delaying the CALL is what buys the stain a frame to play in, and it
	# is also what makes the check honest: `has_beak` stays 0 for the whole hold, so nothing but
	# `note_beak` can colour that row differently.
	t.eq(int(game.run.army.has_beak[3]), 0, "3번 병사는 아직 부리가 없다")
	game._unhandled_input(_click(Look.roster_entry_rect_px(3).get_center()))
	t.eq(game._pending_beak, 3, "셸이 고른 병사를 들고만 있다")
	t.eq(game._hold_sec, Look.HOLD_BEAK_SEC, "그리고 HOLD_BEAK_SEC 만큼 붙들었다")
	t.eq(int(game.run.army.has_beak[3]), 0,
		"hold 동안 army.has_beak 는 여전히 0이다 — apply_beak 가 hold 뒤로 밀렸다")
	t.eq(game.run.state(), Run.State.REWARD, "hold 동안 run 도 여전히 REWARD 다")
	await t.pump_frames(2)
	t.eq(ps.panels.size(), 1, "그래서 판넬이 hold 동안 실제로 계속 그려졌다 (바닥)")
	# A second pick during the hold would overwrite the first while it is still being stained.
	game._unhandled_input(_click(Look.roster_entry_rect_px(5).get_center()))
	t.eq(game._pending_beak, 3, "hold 중에는 판넬 클릭이 안 먹는다 — 고른 병사가 안 바뀐다")
	game._process(Look.HOLD_BEAK_SEC)
	t.eq(game._pending_beak, -1, "hold 가 끝나면서 셸이 손을 놓았다")
	t.eq(int(game.run.army.has_beak[3]), 1, "그제서야 3번 병사에게 부리가 붙었다")
	t.eq(game.run.state(), Run.State.BATTLE, "고르고 나자 다시 전투다")
	t.eq(game.run.island_index, 2, "그리고 보스 섬으로 넘어갔다")
	await t.pump_frames(2)
	t.eq(ps.panels.size(), 0, "패널이 사라졌다")
	t.eq(fs.tiles.size(), 680, "새 섬의 지형이 680칸 그려졌다")

	# -- the lose panel and the restart button ------------------------------------------------------
	var old_army := game.run.army
	game.run.finish_island(false)
	t.eq(game.run.state(), Run.State.LOST, "지면 run 이 LOST 로 간다")
	game._open_island()
	await t.pump_frames(2)
	t.ok(game.battle != null, "져도 battle 은 안 지운다 — 패배 화면이 남은 적 수를 계속 읽어야 한다")
	t.eq(hs.enemies.size(), 1, "패배 화면 밑에서도 남은 적 수가 계속 그려진다")
	t.eq(ps.messages.size(), 1, "패배 문구를 그렸다")
	t.eq(str(ps.messages[0]["text"]), PanelView.MSG_LOST, "패배라고 쓰여 있다")
	t.eq(ps.buttons.size(), 1, "다시 하기 단추를 그렸다")
	t.eq(ps.buttons[0]["rect"], Look.button_rect_px(), "단추가 look.gd 가 계산한 자리다")
	t.eq(str(ps.buttons[0]["text"]), PanelView.BUTTON_LABEL, "단추에 다시 하기라고 쓰여 있다")
	var button_rects: Array[Rect2] = []
	for it: Dictionary in ps.buttons:
		button_rects.append(it["rect"])
	_rects_land_on_screen(t, "패배 패널", button_rects)

	game._unhandled_input(_click(Look.button_rect_px().get_center()))
	t.eq(game.run.state(), Run.State.BATTLE, "단추를 누르자 새 판이 시작됐다")
	t.eq(game.run.island_index, 0, "다시 0번 섬이다")
	t.ok(game.run.army != old_army, "명부가 통째로 새것이다 — 부리도 상처도 안 따라온다")
	t.eq(game.run.army.living_count(), Rules.START_MELEE + Rules.START_RANGED, "다시 10명이다")
	await t.pump_frames(2)
	t.eq(ps.panels.size(), 0, "다시 하기 뒤에는 패널이 없다")
	t.ok(fs.battle == game.battle, "새 판의 Battle 이 화면에 다시 물렸다")

	t.root.remove_child(game)
	game.queue_free()


## The lowest and highest `seq` in a capture array. -1 for an empty one, which never compares as a
## valid layer — an empty array must not make a layer assertion pass by default.
func _seq_min(rows: Array) -> int:
	var out := -1
	for it: Dictionary in rows:
		var s := int(it["seq"])
		if out < 0 or s < out:
			out = s
	return out


func _seq_max(rows: Array) -> int:
	var out := -1
	for it: Dictionary in rows:
		var s := int(it["seq"])
		if s > out:
			out = s
	return out


## Every rectangle a hook was handed has area AND lies inside the viewport. The two halves catch
## different mutations: containment catches a layout that walked off the screen, area catches one that
## collapsed — and a bare `Rect2()` passes containment on its own.
##
## ⚠ **The water-margin tiles are deliberately not fed in.** They are supposed to be outside the
## screen; widening the screen rectangle to admit them would stop this catching a dock, an HP bar or a
## HUD box that walked off it.
func _rects_land_on_screen(t, label: String, rects: Array[Rect2]) -> void:
	var screen := Rect2(Vector2.ZERO, Look.viewport_size_px())
	var no_area := 0
	var outside := 0
	for r: Rect2 in rects:
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			no_area += 1
		if r.position.x < screen.position.x or r.position.y < screen.position.y \
				or r.end.x > screen.end.x or r.end.y > screen.end.y:
			outside += 1
	t.ok(rects.size() > 0, "%s — 잴 사각형이 있다 (%d개)" % [label, rects.size()])
	t.eq(no_area, 0, "%s — 넓이 0인 사각형이 하나도 없다" % label)
	t.eq(outside, 0, "%s — 전부 1280x720 안에 든다" % label)


## Built by hand and handed straight to `_unhandled_input`. **Not `push_input`**: `Viewport.push_input`
## divides the position by the stretch transform first, and headless the window is 64x64 — a click
## pushed at the dock's own pixel arrives thousands of pixels away and hits nothing, with no error
## anywhere. game.gd's own comment records the measurement. Keys carry no position and pass through
## `push_input` untouched, which is exactly how half of an input check stays green while the other
## half is dead.
func _key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = code
	return ev


func _click(at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	return ev
