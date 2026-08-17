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
	var hulls := []
	var shots := []
	var halos := []
	var rings := []
	var target_lines := []
	var sparks := []
	var overlays := []
	var routes := []
	var cliff_faces := []

	func _draw() -> void:
		tiles.clear()
		docks.clear()
		bodies.clear()
		beaks.clear()
		hps.clear()
		hulls.clear()
		shots.clear()
		halos.clear()
		rings.clear()
		target_lines.clear()
		sparks.clear()
		overlays.clear()
		routes.clear()
		cliff_faces.clear()
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

	func _paint_hull(rect: Rect2, colour: Color, outline_width: float) -> void:
		hulls.append({"seq": _bump(), "rect": rect, "colour": colour, "width": outline_width})

	func _paint_cliff_face(points: PackedVector2Array, colour: Color, width: float) -> void:
		cliff_faces.append({"seq": _bump(), "points": points, "colour": colour, "width": width})

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

	func _paint_overlay(rects: Array, colour: Color) -> void:
		overlays.append({"seq": _bump(), "rects": rects, "colour": colour})

	func _paint_route(from: Vector2, to: Vector2, colour: Color, width: float) -> void:
		routes.append({"seq": _bump(), "from": from, "to": to, "colour": colour, "width": width})


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
	t.eq(game.field_view.rows.size(), Look.GRID_H, "field_view 가 섬 32줄을 받았다")
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
	# The terrain pass is one margin ring wider than the grid — `boat-and-landing` made the grid
	# smaller than the zoomed-out camera's own visible world (48 x 32 tiles against up to 2275 px of
	# view at ZOOM_MIN), so the margin has to cover the whole zoomed-out edge now, not only a shake.
	var margin := Look.WATER_MARGIN_TILES
	var wt := Look.GRID_W + 2 * margin
	var ht := Look.GRID_H + 2 * margin
	# ⚠ **2436 and 1536 are written out as literals**, not as `wt * ht`. A check whose bounds come
	# from the thing it checks proves nothing: with the count derived from `Look.WATER_MARGIN_TILES`,
	# setting that constant to 0 would move the expectation and the reality together and the margin
	# could vanish with the round green.
	t.eq(wt * ht, 2436, "물 여백까지 세면 2436칸이다 (58 x 42) — 여백 상수가 0이 되면 여기가 문다")
	t.eq(Look.GRID_W * Look.GRID_H, 1536, "격자 자체는 1536칸이다")
	t.eq(fs.tiles.size(), 2436, "지형을 물 여백까지 2436칸 그렸다")
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
	t.eq(tile_bad, 0, "2436칸이 전부 자기 자리의 사각형을 받았다 (행 우선, 여백 포함)")
	t.eq(inner_rects.size(), 1536, "그중 격자 안쪽이 1536칸이다")
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

	t.eq(fs.docks.size(), b.harbour_count(), "항구를 sim 이 가진 수만큼 그렸다 (%d개)" % b.harbour_count())
	var dock_bad := 0
	for d in b.harbour_count():
		var tile := b.harbour_tile(d)
		var want := Look.tile_rect_px(tile % b.grid.w, tile / b.grid.w)
		if fs.docks[d]["rect"] != want:
			dock_bad += 1
	t.eq(dock_bad, 0, "항구 사각형이 sim 의 항구 타일과 같은 자리다")

	# `boat-and-landing` stage 5, P2: both boats start idle, sitting at the SAME start harbour, so
	# two hulls are drawn there before anything ever launches — the old "no boats yet, nothing drawn"
	# claim goes false the moment a hull exists whether or not one is at sea.
	#
	# ⚠ Widths are LITERALS (124.0, 72.0), never `cap_of(b) * Look.BOAT_SLOT_PX + 2.0 *
	# Look.BOAT_HULL_PAD_PX` — a check whose bound comes from the constants it is checking shrinks
	# with them. Measured: `BOAT_SLOT_PX` mutated to 1.0 stayed green under the derived form, because
	# the row comparing the two boats' widths collapsed to `20 > 20` instead of `124 > 72`.
	t.eq(fs.hulls.size(), Rules.boat_count(), "아직 아무것도 안 띄웠어도, 항구에 앉은 배 수만큼 선체를 그렸다")
	var start_anchor := Look.tile_point_px(b.grid.tile_point(int(b.grid.harbour_tiles[b.grid.start_harbour])))
	t.eq(fs.hulls[0]["rect"].size, Vector2(124.0, 56.0), "0번(큰) 배 선체가 124 x 56 px 리터럴과 같다")
	t.eq(fs.hulls[1]["rect"].size, Vector2(72.0, 56.0), "1번(빠른) 배 선체가 72 x 56 px 리터럴과 같다")
	t.ok(fs.hulls[0]["rect"].size.x > fs.hulls[1]["rect"].size.x,
		"큰 배(0번, 정원 4) 선체가 빠른 배(1번, 정원 2)보다 실제로 넓다 — 숫자를 안 읽어도 구별된다")
	t.ok(fs.hulls[0]["rect"].get_center().distance_to(start_anchor) <= Look.HULL_BERTH_OFFSET_PX + 0.01,
		"두 선체 다 시작 항구 근처에 있다")
	t.ok(fs.hulls[1]["rect"].get_center().distance_to(start_anchor) <= Look.HULL_BERTH_OFFSET_PX + 0.01,
		"(자가 점검 — 1번 배도 마찬가지)")
	# A1: `HULL_BERTH_OFFSET_PX` was 30 against a REQUIRED 98 ((124+72)/2), which overlapped 68 px —
	# 94% of the fast boat's own width — on the very first frame of every island. The rects
	# themselves must not intersect; the OLD check bounded only the distance between their centres
	# from above, which stayed green at a distance of 0.0.
	t.ok(not fs.hulls[0]["rect"].intersects(fs.hulls[1]["rect"]),
		"두 선체 사각형이 실제로 겹치지 않는다 — 중심 사이 거리가 아니라 사각형 자체를 잰다")

	# P10: `_paint_cliff_face` is called every frame regardless (so the seq-order check above always
	# has something to compare against), but that alone proves nothing was thrown away INSIDE it —
	# island 1's row 2 is solid `^` over open water, so the geometry itself has to be non-empty too.
	t.eq(fs.cliff_faces.size(), 1, "절벽 단면 훅을 한 번 불렀다")
	var cliff_pts: PackedVector2Array = fs.cliff_faces[0]["points"]
	t.eq(cliff_pts.size() % 2, 0, "점이 짝수 개다 — 선분마다 두 점 (자가 점검)")
	var seg_count := cliff_pts.size() / 2
	t.ok(seg_count >= 40, "그 안에 실제 절벽 단면 선분이 들어 있다 (%d개, 최소 40)" % seg_count)
	t.eq(fs.cliff_faces[0]["colour"], Look.COL_CLIFF_FACE, "절벽 단면 색이 look.gd 값이다")
	t.eq(float(fs.cliff_faces[0]["width"]), 4.0, "절벽 단면 굵기가 4.0px 리터럴과 같다")
	# D: island 1 row 2 (`^`) has water at row 1 (north) and land at row 3 (south), so no segment may
	# sit on the LANDWARD (south) edge — a mutation flipping the water test draws that edge instead,
	# and the segment COUNT alone does not move (same 44 tiles), so only checking the SIDE catches it.
	# Two of the 46 legitimate segments (the strip's own west and east ends) run north-to-south rather
	# than along the north edge, which is why this checks "not on the south edge" and not "on the
	# north edge" — a strictly-north requirement would misflag those two as wrong.
	var north_y := Look.tile_rect_px(2, 2).position.y
	var south_y := north_y + Look.TILE_PX
	var wrong_side := 0
	var zero_len := 0
	for si in seg_count:
		var p0: Vector2 = cliff_pts[si * 2]
		var p1: Vector2 = cliff_pts[si * 2 + 1]
		if absf(p0.y - south_y) < 0.01 and absf(p1.y - south_y) < 0.01:
			wrong_side += 1
		if p0.distance_to(p1) < Look.TILE_PX - 0.01:
			zero_len += 1
	t.eq(wrong_side, 0, "어떤 단면도 육지 쪽(남쪽) 가장자리에 있지 않다")
	t.eq(zero_len, 0, "그리고 모든 단면이 실제로 타일 폭만큼 길다 — 길이 0인 선이 없다")

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
	for arr: Array in [fs.tiles, fs.docks, fs.hulls, fs.cliff_faces, fs.bodies, fs.beaks, fs.hps,
			fs.shots, fs.halos, fs.rings, fs.target_lines, fs.sparks]:
		for it: Dictionary in arr:
			seen_seq[int(it["seq"])] = true
			call_total += 1
	t.eq(seen_seq.size(), call_total,
		"훅 호출 %d번이 전부 서로 다른 순번을 들고 있다 — 순번을 안 적은 훅이 없다" % call_total)
	t.ok(seen_seq.has(0) and seen_seq.has(call_total - 1),
		"순번이 0에서 시작해 빈칸 없이 끝까지 간다 — _draw 머리에서 되감긴다")
	t.ok(_seq_max(fs.tiles) < _seq_min(fs.cliff_faces), "층 1 지형이 층 1b 절벽 단면보다 먼저 그려졌다")
	t.ok(_seq_max(fs.cliff_faces) < _seq_min(fs.docks), "절벽 단면이 층 2 항구보다 먼저 그려졌다")
	t.ok(_seq_max(fs.docks) < _seq_min(fs.hulls), "층 2 항구가 층 2c 선체보다 먼저 그려졌다")
	t.ok(_seq_max(fs.hulls) < _seq_min(fs.bodies), "선체가 층 7 몸보다 먼저 그려졌다")

	# -- the HUD, and the number on it coming from the sim -----------------------------------------
	t.eq(hs.timers.size(), 1, "타이머를 한 번 그렸다")
	t.eq(str(hs.timers[0]["text"]), "남은 시간 %.1f" % b.time_left(), "타이머 글자가 sim 의 남은 시간이다")
	t.eq(hs.timers[0]["at"], Look.HUD_TIMER_POS_PX, "타이머 위치가 look.gd 값이다")
	t.eq(hs.berths.size(), Rules.boat_count(), "선착장을 함대 수만큼 그렸다")
	var berth_bad := 0
	for k in hs.berths.size():
		if hs.berths[k]["rect"] != Look.berth_rect_px(k):
			berth_bad += 1
	t.eq(berth_bad, 0, "선착장 사각형이 look.gd 가 계산한 자리다")
	# `boat-and-landing` stage 4, P9: one label PER BOAT, not a fleet-wide total — `net_shell`'s own
	# next stage-4 section drives the per-boat number up by loading through the keys, so the resting
	# text just has to name the right boat and start at 0.
	t.eq(hs.loads.size(), Rules.boat_count(), "탑승 수를 배마다 한 번씩 그렸다")
	var load_bad := 0
	for k in hs.loads.size():
		if str(hs.loads[k]["text"]) != "%s 0/%d" % [HudView.boat_label(k), Rules.cap_of(k)]:
			load_bad += 1
	t.eq(load_bad, 0, "아직 아무도 안 태웠다고, 배마다 자기 이름과 정원으로 쓰여 있다")
	t.eq(hs.keys.size(), HudView.key_slot_count(), "키 슬롯을 둘 그렸다")
	t.eq(str(hs.keys[0]["text"]), "1  %s  %d" % [HudView.type_label(Rules.CELL_MELEE), Rules.START_MELEE],
		"1번 칸이 근접 예비 인원을 sim 에서 읽어 썼다")
	t.eq(str(hs.keys[1]["text"]), "2  %s  %d" % [HudView.type_label(Rules.CELL_RANGED), Rules.START_RANGED],
		"2번 칸이 원거리 예비 인원을 sim 에서 읽어 썼다")
	t.eq(hs.enemies.size(), 1, "남은 적 수를 한 번 그렸다")
	t.eq(str(hs.enemies[0]["text"]), "적 %d" % b.enemies_left(), "남은 적 글자가 sim 의 수다")
	t.eq(ps.panels.size(), 0, "전투 중에는 패널이 한 번도 안 그려졌다")
	# `boat-and-landing` stage 4, P9: each boat's berth and its own load label are drawn as a PAIR
	# now, one boat at a time (berth0 -> load0 -> berth1 -> load1), not all the berths and then all
	# the loads — a total that named one fleet-wide number could sit after every berth; a label that
	# names ONE boat has to sit right after that boat's own box or a stray box could read as another
	# boat's number.
	t.ok(hs.timers[0]["seq"] < hs.berths[0]["seq"] and hs.berths[0]["seq"] < hs.loads[0]["seq"]
		and hs.loads[0]["seq"] < hs.berths[1]["seq"] and hs.berths[1]["seq"] < hs.loads[1]["seq"]
		and _seq_max(hs.loads) < hs.keys[0]["seq"] and _seq_max(hs.keys) < hs.enemies[0]["seq"],
		"HUD 도 타이머 -> (선착장 -> 탑승) 배마다 -> 키 -> 남은 적 순서로 그린다")

	# **The resting look of key slot 0**, captured before any press. Item 8's whole content is the
	# DIFFERENCE from this, so it has to be read once while nothing has happened yet.
	var rest_key_rect: Rect2 = hs.keys[0]["rect"]
	var rest_key_at: Vector2 = hs.keys[0]["at"]
	t.eq(hs.keys[0]["bg"], Look.COL_BUTTON, "아직 아무 키도 안 눌러서 키 상자가 기본색이다 (바닥)")
	t.eq(rest_key_rect, Look.key_rect_px(0), "그리고 안 흔들린 자리에 있다")

	# -- every rectangle that reached a hook has area, and lands where its own space says it should ---
	# ⚠ **Field rects are in WORLD (canvas) space now, HUD rects stay in SCREEN space** — `field_view`
	# composes the camera as a node transform, so `_paint_tile` / `_paint_dock` / `_paint_hp` are handed
	# raw canvas coordinates while `hud_view` (a sibling, not a child of the camera) still hands out
	# viewport coordinates directly. Mixing the two into one screen-bound check is exactly the failure
	# `boat-and-landing` warns about: at ZOOM_MIN most of the field's own rects sit outside 1280x720
	# on purpose, and widening the bound to admit them would stop it catching a HUD box that walked off
	# the real screen.
	var field_rects: Array[Rect2] = []
	for r: Rect2 in inner_rects:
		field_rects.append(r)
	for it: Dictionary in fs.docks:
		field_rects.append(it["rect"])
	for it: Dictionary in fs.hps:
		field_rects.append(it["back"])
	_rects_land_in_world(t, "전투 화면 — 필드", field_rects)

	var hud_rects: Array[Rect2] = []
	for it: Dictionary in hs.berths:
		hud_rects.append(it["rect"])
	for it: Dictionary in hs.keys:
		hud_rects.append(it["rect"])
	_rects_land_on_screen(t, "전투 화면 — HUD", hud_rects)

	# -- the keys, through the shell's own input path ------------------------------------------------
	t.eq(int((b.pending[0] as PackedInt32Array).size()), 0, "누르기 전에는 0번 배의 탑승 인원이 0이다")
	game._unhandled_input(_key(KEY_1))
	game._unhandled_input(_key(KEY_1))
	t.eq(int((b.pending[0] as PackedInt32Array).size()), 2,
		"1키 두 번에 병사 둘이 0번 배에 올랐다 (셸이 Input 을 읽는 유일한 곳이다)")
	await t.pump_frames(2)
	t.eq(str(hs.loads[0]["text"]), "%s 2/%d" % [HudView.boat_label(0), Rules.cap_of(0)],
		"sim 이 둘을 0번 배에 태우자 0번 배 글자도 둘이 됐다 (그 배 자신의 정원 대비)")

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
	var pending_full := 0
	for pb: PackedInt32Array in b.pending:
		pending_full += pb.size()
	game._unhandled_input(_key(KEY_1))
	var pending_after := 0
	for pb: PackedInt32Array in b.pending:
		pending_after += pb.size()
	t.eq(pending_after, pending_full, "그 1키는 sim 에서 실제로 거절됐다")
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

	# -- stage 4: the drag, driven through push_input for real (boat-and-landing, section 6) ----------
	# ⚠ `root.push_input(ev, true)` and NOT `game._unhandled_input(ev)` by hand — the plan's own
	# correction, measured with positive and negative controls: `in_local_coords = true` delivers a
	# click intact through Viewport's own hit test, strictly stronger than a hand call that bypasses
	# whatever the tree (the panel, in particular) would have swallowed first.
	t.eq(int(b.pending[0].size()), Rules.cap_of(0),
		"0번 배가 이미 가득 찼다 (자가 점검 — 앞 절 키 입력들이 다 태웠다)")
	t.eq(int(b.pending[1].size()), Rules.cap_of(1), "1번 배도 가득 찼다 (자가 점검)")
	t.ok(not b.boat_busy(0) and not b.boat_busy(1), "둘 다 아직 항구에 있다, 바다가 아니다 (자가 점검)")

	# The camera parked at a KNOWN state — zoom 1.0, cam_px ZERO, no shake — so canvas (world) px and
	# screen px coincide and a target tile's press position is just `Look.tile_point_px(...)`.
	fs.zoom = 1.0
	fs.cam_px = Vector2.ZERO
	await t.pump_frames(1)

	# A2 / A3: the hull is grabbable over its WHOLE drawn rect, not only the tile at its centre — and
	# a press inside boat 1's own (disjoint, since A1's fix) rect grabs boat 1, never boat 0.
	# `game._boat_hit_at` used to compare a tile index, so ~70% of a 124x56 hull answered to nothing
	# (only its centre tile was live) and pressing boat 1's visibly offset hull grabbed boat 0 — both
	# boats sat on the SAME tile, and the tile-based test could not tell them apart.
	t.eq(fs.hulls.size(), Rules.boat_count(), "선체 둘이 아직 항구에 있다 (자가 점검)")
	var hull0_edge: Vector2 = fs.hulls[0]["rect"].position + Vector2(4.0, Look.BOAT_HULL_H_PX * 0.5)
	var hull1_edge: Vector2 = fs.hulls[1]["rect"].position + Vector2(4.0, Look.BOAT_HULL_H_PX * 0.5)
	t.ok(not fs.hulls[0]["rect"].has_point(hull1_edge), "자가 점검 — 두 가장자리가 서로 다른 선체 안이다")
	t.eq(game._boat_hit_at(hull0_edge), 0, "0번 배 선체의 가장자리(중심 타일 밖)를 눌러도 0번 배가 잡힌다")
	t.eq(game._boat_hit_at(hull1_edge), 1, "1번 배 선체의 가장자리를 누르면 1번 배가 잡힌다 — 0번이 아니다")

	var start_hb := b.grid.start_harbour
	var send: PackedByteArray = b.grid.sendable[start_hb]
	var sendable_tile := -1
	for tt in send.size():
		if send[tt] != 0:
			sendable_tile = tt
			break
	t.ok(sendable_tile >= 0, "이 섬의 시작 항구가 보낼 수 있는 해안이 있다 (자가 점검)")
	var refuse_tile := int(b.grid.harbour_tiles[start_hb])   # water — never landable, guaranteed refused
	var hull_px := Look.tile_point_px(b.grid.tile_point(refuse_tile))
	var sendable_px := Look.tile_point_px(b.grid.tile_point(sendable_tile))

	# -- refusal: release on a non-sendable tile (here: the harbour's own water) launches nothing,
	# and the berth icon shakes exactly as a refused key does -----------------------------------------
	var rest_berth0_rect: Rect2 = hs.berths[0]["rect"]
	t.root.push_input(_press(hull_px), true)
	await t.pump_frames(1)
	t.eq(game._drag_boat, 0, "0번 배 선체를 누르면 그 배를 붙잡는다")
	t.ok(not game._panning, "그리고 카메라는 안 끌린다 — 배를 눌렀지 필드를 누른 게 아니다")
	t.ok(fs.overlays.size() > 0, "드래그 중엔 오버레이가 그려진다")
	t.eq((fs.overlays[0]["rects"] as Array).size(), (_rects_of(b.grid.w, send) as Array).size(),
		"오버레이 칸 수가 그 항구의 sendable 칸 수와 같다")
	t.ok(absf((fs.overlays[0]["colour"] as Color).a - 0.18) < 0.001,
		"타일 알파가 DROP_TINT_ALPHA 리터럴 0.18 과 같다 (%.6f)" % (fs.overlays[0]["colour"] as Color).a)
	var overlay_rgb: Color = fs.overlays[0]["colour"]
	t.ok(absf(overlay_rgb.r - Look.COL_SENDABLE.r) < 0.001 and absf(overlay_rgb.g - Look.COL_SENDABLE.g) < 0.001
			and absf(overlay_rgb.b - Look.COL_SENDABLE.b) < 0.001,
		"그리고 색조(RGB)는 COL_SENDABLE 이다")

	# B: the candidate ring and the route line — before this nothing read `fs.rings` / `fs.routes`
	# while a drag was in flight, so a vanished ring, a zero-length route, or a candidate frozen at
	# the press tile all shipped invisible. Move to a REAL sendable tile first (not the press tile),
	# so "the candidate follows the cursor" is actually exercised.
	t.root.push_input(_motion(sendable_px, Vector2.ZERO), true)
	await t.pump_frames(1)
	t.eq(fs.rings.size(), 1, "후보 링이 정확히 하나 떴다 (아직 전투 연출은 하나도 안 일어났다)")
	t.eq(Vector2(fs.rings[0]["centre"]), sendable_px, "그 칸에, 커서를 따라 링이 떴다")
	t.eq(fs.rings[0]["colour"], Look.COL_WIN, "받아주는 칸이면 링이 수락(COL_WIN) 색이다")
	t.eq(float(fs.rings[0]["radius"]), 18.0, "링 반지름이 리터럴 18.0px 다")
	t.eq(fs.routes.size(), 1, "항로 선도 하나 그렸다")
	t.eq(Vector2(fs.routes[0]["from"]), hull_px, "그 선이 항구에서 출발하고")
	t.eq(Vector2(fs.routes[0]["to"]), sendable_px, "커서를 따라 받아주는 칸에서 끝난다")
	t.eq(float(fs.routes[0]["width"]), 3.0, "항로 선 굵기가 리터럴 3.0px 다")
	t.ok(Vector2(fs.routes[0]["from"]).distance_to(Vector2(fs.routes[0]["to"])) > 1.0,
		"그리고 실제 길이가 있다 — 두 끝점이 겹치지 않는다")

	# Move the candidate OFF the sendable tile: the ring must flip to refuse colour, not stay accepted.
	t.root.push_input(_motion(hull_px, Vector2.ZERO), true)
	await t.pump_frames(1)
	t.eq(fs.rings.size(), 1, "커서를 거절되는 칸으로 옮겨도 링은 여전히 하나다")
	t.eq(Vector2(fs.rings[0]["centre"]), hull_px, "그 칸으로 링이 따라왔다")
	t.eq(fs.rings[0]["colour"], Look.COL_LOSE,
		"거절되는 칸이면 링이 거절(COL_LOSE) 색이다 — 항상 수락 색이면 막힌 해안이 열린 것처럼 보인다")

	var line_tests_before := b.grid.line_tests
	await t.pump_frames(3)
	t.eq(b.grid.line_tests, line_tests_before,
		"드래그 중 여러 프레임이 지나도 항로 검사가 다시 안 돈다 — 캐시된 sendable 만 읽는다")

	t.root.push_input(_release(hull_px), true)
	await t.pump_frames(1)
	t.eq(int(b.boats.size()), 0, "물 위(항구 칸)에 놓으면 아무 배도 안 뜬다")
	t.eq(int(b.pending[0].size()), Rules.cap_of(0), "0번 배의 화물도 그대로다 — 거절이 화물을 안 건드린다")
	t.eq(game._drag_boat, -1, "드래그가 끝났다 (자가 점검)")
	t.eq(fs.overlays.size(), 0, "놓은 뒤엔 오버레이가 안 그려진다")
	t.ok(hs.berths[0]["rect"].position != rest_berth0_rect.position,
		"거절당한 0번 배 선착장 상자가 흔들렸다 — 거절된 키와 같은 신호다")
	t.ok(hs.berths[0]["col"] != Look.COL_BOAT, "선착장 색도 기본색에서 벗어났다")

	# -- press on the hull again, release on a sendable tile: launches that boat there ---------------
	t.root.push_input(_press(hull_px), true)
	await t.pump_frames(1)
	t.eq(game._drag_boat, 0, "다시 0번 배 선체를 잡는다 (자가 점검)")
	t.root.push_input(_motion(hull_px, Vector2.ZERO), true)
	await t.pump_frames(1)
	t.root.push_input(_release(sendable_px), true)
	await t.pump_frames(2)
	t.eq(int(b.boats.size()), 1, "받아주는 칸에 놓자 배가 하나 떴다")
	t.eq(int(b.boats[0]["boat"]), 0, "뜬 것이 0번 배다")
	t.eq(int(b.boats[0]["target"]), sendable_tile, "놓은 바로 그 칸으로 간다")
	t.eq(int(b.pending[0].size()), 0, "0번 배 화물이 비었다 — 실제로 태워 보냈다")
	# `boat-and-landing` stage 5: TWO hulls are on screen now — 1번 배 still idle at its harbour, and
	# the just-launched 0번 배 at sea. `game.set_process(false)` upstream in this file means
	# `battle.step` never runs on its own, so 0번 배's `pos` is still exactly its OWN harbour's point
	# too — the two hulls' CENTRES coincide right after launch. Found by SIZE instead: cap 4 (124 px,
	# LITERAL — see the earlier note on this shape) is unique to boat 0.
	t.eq(fs.hulls.size(), Rules.boat_count(), "뜬 배 하나 + 항구에 남은 배 하나, 선체 둘을 그렸다")
	var launched_hull := _find_hull(fs, 124.0)
	t.ok(not launched_hull.is_empty(), "뜬 배(0번, 정원 4)의 선체를 화면에서 실제로 찾았다")
	t.eq(_hull_rect_of(launched_hull).size, Vector2(124.0, Look.BOAT_HULL_H_PX),
		"선체 크기가 0번 배(정원 %d) 자신에게서 나왔다" % Rules.cap_of(0))
	t.eq(_hull_colour_of(launched_hull), Look.COL_BOAT, "선체 색이 look.gd 기본값이다 (아직 도착 대기 중이 아니다)")

	# I: right after launch, `b.boats[0]["pos"]` still equals the harbour anchor too, so comparing
	# the hull's centre against it cannot tell "drawn where the sim says the boat is" from "drawn at
	# the harbour" — the same coincidence that made A2/A3's tile-based bug invisible here. `game`'s
	# own `_process` is off, so the sim is stepped BY HAND (`b.begin_frame` + `b.step`) to move the
	# boat for real before this comparison runs.
	var anchor_before: Vector2 = Look.tile_point_px(Vector2(b.boats[0]["pos"]))
	b.begin_frame()
	b.step(0.2)
	await t.pump_frames(2)
	var moved_px: Vector2 = Look.tile_point_px(Vector2(b.boats[0]["pos"]))
	t.ok(moved_px.distance_to(anchor_before) > 1.0,
		"자가 점검 — 0.2초 실제로 흘려보내자 배가 항구에서 실제로 떨어졌다 (%.1f px)"
		% moved_px.distance_to(anchor_before))
	launched_hull = _find_hull(fs, 124.0)
	t.ok(not launched_hull.is_empty(), "실제로 움직인 뒤에도 0번 배 선체를 찾았다 (자가 점검)")
	t.eq(_hull_rect_of(launched_hull).get_center(), moved_px,
		"그리고 항구가 아니라 sim 이 말한, 실제로 옮겨간 그 자리에 그려졌다")

	# P3: every passenger is on deck, in ITS OWN colour, inside that hull's own rectangle.
	var on_deck := 0
	for braw: Dictionary in fs.bodies:
		if braw["colour"] != Look.body_colour_of(false):
			continue
		if _hull_rect_of(launched_hull).has_point(braw["centre"]):
			on_deck += 1
	t.eq(on_deck, Rules.cap_of(0),
		"0번 배 정원만큼 병사가 자기 색 몸으로 그 선체 안에서 그려졌다 — 배가 곧 화물이 아니다")

	# -- the same gesture via the HUD icon, through a shaken, panned, zoomed frame --------------------
	# `screen_to_world_px` composes pan, zoom and shake in ONE expression (7.1), so proving a click
	# still lands on the right tile through all three at once is a stronger claim than proving it at
	# zoom 1 with no pan — this is the row that replaces the old dock-era "click corrected by the
	# shake". The HUD press position needs none of this: `hud_view` is a SIBLING, never scaled by the
	# field's camera, which is exactly why the berth box is also the fallback grab target.
	fs.zoom = 0.8
	fs.cam_px = Vector2(120.0, 60.0)
	fs._shake_amp = Look.SHAKE_MAX_PX
	fs._shake_left = Look.SHAKE_SEC * 0.5
	await t.pump_frames(1)   # field_view's own _process recomposes position/scale from the above

	var hud1_screen: Vector2 = Look.berth_rect_px(1).get_center()
	var release_world := Look.tile_point_px(b.grid.tile_point(sendable_tile))
	var release_screen := release_world * fs.zoom + fs.position

	t.root.push_input(_press(hud1_screen), true)
	await t.pump_frames(1)
	t.eq(game._drag_boat, 1, "HUD 아이콘을 눌러도 배를 붙잡는다 — 여긴 1번 배")
	t.ok(not game._panning, "그리고 카메라는 안 끌린다 (자가 점검)")
	t.root.push_input(_motion(release_screen, Vector2.ZERO), true)
	await t.pump_frames(1)
	t.root.push_input(_release(release_screen), true)
	await t.pump_frames(2)
	t.eq(int(b.boats.size()), 2, "1번 배도 흔들리고 밀리고 줌인된 화면에서 떴다")
	var launched1: Dictionary = b.boats[1] if int(b.boats[0]["boat"]) == 0 else b.boats[0]
	t.eq(int(launched1["boat"]), 1, "방금 뜬 것이 1번 배다 (자가 점검)")
	t.eq(int(launched1["target"]), sendable_tile,
		"흔들리고 밀리고 줌인된 화면에서도 놓은 칸이 정확했다")
	t.eq(int(b.pending[1].size()), 0, "1번 배 화물도 비었다")

	# -- the overlay reads `boat_at` live, not a value cached when the drag began ---------------------
	# `boat_at[0]` still names its LAST known harbour while boat 0 is at sea — `battle.gd`'s own
	# comment calls that meaningless as "where it is", but harmless to read, and poking it directly is
	# `net_boat`'s own technique for the sim side (`_leaves_from_boat_at`). This is the view's half:
	# does the drawn overlay track it, frame to frame, rather than the harbour the drag started from.
	var other_hb := -1
	for hb2 in b.grid.harbour_tiles.size():
		if hb2 != start_hb:
			other_hb = hb2
			break
	t.ok(other_hb >= 0, "이 섬에 항구가 둘 이상이다 (자가 점검)")
	var reach_a: PackedByteArray = b.grid.sendable[start_hb]
	var reach_b: PackedByteArray = b.grid.sendable[other_hb]
	t.ok(reach_a != reach_b, "두 항구가 서로 다른 해안을 본다 (자가 점검)")

	fs.zoom = 1.0
	fs.cam_px = Vector2.ZERO
	fs._shake_amp = 0.0
	fs._shake_left = 0.0
	b.boat_at[0] = start_hb
	fs.set_drag(0, -1)
	await t.pump_frames(1)
	t.eq(fs.overlays[0]["rects"], _rects_of(b.grid.w, reach_a),
		"boat_at 가 시작 항구일 때 오버레이가 그 항구의 sendable 과 같다")

	b.boat_at[0] = other_hb
	await t.pump_frames(1)
	t.eq(fs.overlays[0]["rects"], _rects_of(b.grid.w, reach_b),
		"boat_at 를 다른 항구로 옮기면 다음 프레임 오버레이가 그 새 항구의 sendable 로 바뀐다 — " +
		"드래그 시작 때 캐시된 값이 아니라 매 프레임 다시 읽는다는 뜻이다")

	fs.set_drag(-1, -1)
	# Left at ZOOM_MIN, the state `setup()` actually produced, so the wheel test right after this
	# section still measures "zoomed IN from where the island opened" rather than from wherever this
	# drag suite happened to leave the camera.
	fs.zoom = Look.ZOOM_MIN
	fs.cam_px = Vector2.ZERO
	await t.pump_frames(1)

	# -- the camera, through the shell's own input path -----------------------------------------------
	# The wheel zooms about the cursor; a left press on the FIELD (never the panel, which is not up
	# here) begins a pan, motion moves it, release ends it. Docks are gone, so this replaces the old
	# "dock click corrected by the shake" item 11 — the shake still folds into the SAME expression
	# (`field_view._compose_position`), and `net_camera` is what pins that directly.
	var before_zoom := fs.zoom
	for _n in 8:
		game._unhandled_input(_wheel(Vector2(640.0, 360.0), true))
	t.ok(fs.zoom > before_zoom, "휠을 올리면 확대된다")
	t.eq(fs.zoom, Look.ZOOM_MAX, "계속 올리면 ZOOM_MAX 에서 멈춘다 — 8번이면 이미 넘친다 (바닥)")

	# Dragged to one corner, then the opposite corner: at ZOOM_MAX the pannable range is not empty on
	# either axis (map 1920x1280 against a 1280x720 viewport), so the two corners must differ
	# regardless of where the camera started — a press-anywhere-else assertion would not survive a
	# camera that happened to start already parked at one of them.
	game._unhandled_input(_press(Vector2(640.0, 360.0)))
	game._unhandled_input(_motion(Vector2(640.0, 360.0), Vector2(4000.0, 4000.0)))
	game._unhandled_input(_release(Vector2(4640.0, 4360.0)))
	var corner_a: Vector2 = fs.cam_px

	game._unhandled_input(_press(Vector2(640.0, 360.0)))
	game._unhandled_input(_motion(Vector2(640.0, 360.0), Vector2(-4000.0, -4000.0)))
	var mid_cam: Vector2 = fs.cam_px
	game._unhandled_input(_release(Vector2(-3360.0, -3640.0)))
	var corner_b: Vector2 = fs.cam_px

	t.ok(corner_a != corner_b, "필드를 눌러 끌면 카메라가 실제로 움직인다 (양 끝 구석이 서로 다르다)")

	game._unhandled_input(_motion(Vector2(-3360.0, -3640.0), Vector2(500.0, 500.0)))
	t.eq(fs.cam_px, corner_b, "손을 뗀 뒤의 움직임은 카메라를 더 끌지 않는다")
	t.ok(mid_cam == corner_b, "떼기 직전과 뗀 직후가 같다 (자가 점검 — 뗀 순간 자체가 끊는 게 아니라 그 다음 motion 이 끊긴다는 뜻)")

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
	# and the camera would keep panning under a frame that has already latched its outcome.
	var pending_at_hold := 0
	for pb: PackedInt32Array in isle0.pending:
		pending_at_hold += pb.size()
	var boats_at_hold := isle0.boats.size()
	game._unhandled_input(_key(KEY_2))
	var pending_now := 0
	for pb: PackedInt32Array in isle0.pending:
		pending_now += pb.size()
	t.eq(pending_now, pending_at_hold, "hold 중에는 2키가 안 먹는다")
	var cam_at_hold: Vector2 = fs.cam_px
	game._unhandled_input(_press(Vector2(640.0, 360.0)))
	game._unhandled_input(_motion(Vector2(640.0, 360.0), Vector2(500.0, 500.0)))
	t.eq(fs.cam_px, cam_at_hold, "hold 중에는 카메라 드래그도 안 먹는다")
	t.eq(isle0.boats.size(), boats_at_hold, "hold 중에는 배도 그대로다 (자가 점검)")
	var elapsed_at_hold := isle0.elapsed
	game._process(0.1)
	t.eq(isle0.elapsed, elapsed_at_hold, "hold 중에는 step 도 안 돈다 — 제한 시간이 안 흐른다")
	t.ok(game.battle == isle0, "그리고 0.1초 뒤에도 아직 같은 섬이다")
	game._process(Look.HOLD_OUTCOME_SEC)
	t.eq(game._hold_sec, 0.0, "hold 가 끝났다")
	t.ok(game.battle != isle0, "그제서야 다음 섬이 열렸다 (바닥 — 영원히 안 열리면 여기가 문다)")
	t.eq(game.run.island_index, 1, "섬 0을 이기고 섬 1로 넘어갔다")
	t.ok(fs.battle == game.battle, "새 섬의 Battle 이 화면에 다시 물렸다")
	t.eq(_shake_component(fs), Vector2.ZERO, "setup 이 흔들림까지 0으로 지웠다 (카메라 자체 위치는 별개)")
	b = game.battle

	# -- the reward panel, reached through Run's own API --------------------------------------------
	# `finish_island(true)` and not a poke at a private field: island 1 pays the beak and opens the
	# REWARD state. Driving it any other way would measure the fixture.
	#
	# ⚠ **This is also the one spot in this file where the panel opens with NO hold in between** — a
	# direct `finish_island` call, not the outcome hold's multi-frame wait — which is exactly the gap
	# `_on_left_press` / `_hold_sec`'s own comment names and nothing here drove: a drag begun on the
	# field before the panel opened must not keep panning once it does. Begin one now, before the panel
	# exists, and leave it in flight (no release) across the panel opening below.
	t.ok(not game.panel_view.panel_active(), "드래그를 시작하기 전, 패널은 아직 안 떠 있다 (자가 점검)")

	# H: the release-time panel guard. `_on_left_release` refuses to call `battle.launch` while the
	# panel is up. Reaching that guard through the NORMAL flow is narrow: `_open_island` (the only
	# caller of `panel_view.bind`, which is what actually flips `panel_active()`) clears `_drag_boat`
	# as the very first thing it does, unconditionally — a defence this file's own earlier round
	# already added — so a drag genuinely cannot survive INTO the moment the panel opens through that
	# path. This checks the guard line itself rather than that narrow path: `_drag_boat` is set BY
	# HAND after the panel is already up, the same "call the handler, not the input path" technique
	# `_click_panel`'s own hold guard already uses, for the same reason its own comment gives.
	t.ok(b.load_soldier(Rules.CELL_MELEE) >= 0, "이 섬에서도 0번 배에 하나 태웠다 (자가 점검)")
	var rest_berth0_isle1: Rect2 = hs.berths[0]["rect"]
	var boats_before_isle1 := b.boats.size()
	# ⚠ The island transition just above (the verdict hold completing) opened a REAL new island, which
	# DID call `field_view.setup()` and reset the camera to ZOOM_MIN — where `_clamp_cam()` pins BOTH
	# axes (the map is narrower than the visible world at that zoom, so x is forced centred and y's
	# range is exactly `[0, 0]`). That means ANY call to `pan_by` snaps `cam_px` to the same
	# `(-177.78, 0.0)` regardless of the motion's own delta — which is fine: what this line has to
	# prove is only "did the guard stop `pan_by` from being called at all", and setting `cam_px` to
	# something else first is what makes "it changed" mean that, rather than nothing having run yet.
	fs.cam_px = Vector2(300.0, 300.0)
	game._unhandled_input(_press(Vector2(700.0, 300.0)))
	t.ok(game._panning, "필드를 누르면 드래그가 시작된다 (자가 점검)")

	game.run.finish_island(true)
	t.eq(game.run.state(), Run.State.REWARD, "섬 1을 이기자 부리 고르기가 열렸다")
	game._open_island()
	await t.pump_frames(2)
	t.eq(ps.panels.size(), 1, "보상 화면에서 패널이 그려졌다")

	# The panel is now up. `_drag_boat` is set BY HAND here, after the fact — see the note above this
	# block for why the normal path cannot produce this state on its own.
	t.ok(game.panel_view.panel_active(), "패널이 실제로 떠 있다 (자가 점검)")
	game._drag_boat = 0
	game._on_left_release(Vector2(700.0, 300.0))
	await t.pump_frames(1)
	t.eq(b.boats.size(), boats_before_isle1, "패널이 뜬 뒤 놓아도 배가 안 뜬다 — 조용히 취소된다")
	t.eq(game._drag_boat, -1, "드래그 상태는 정리됐다")
	t.eq(hs.berths[0]["rect"].position, rest_berth0_isle1.position,
		"선착장 상자는 안 흔들렸다 — 거절 신호조차 없는 조용한 취소다 (note_launch 가 안 불렸다)")

	var cam_before_motion: Vector2 = fs.cam_px
	game._unhandled_input(_motion(Vector2(700.0, 300.0), Vector2(-80.0, -80.0)))
	t.eq(fs.cam_px, cam_before_motion,
		"패널이 뜨기 전에 시작된 드래그라도, 뜬 뒤에 온 motion 은 카메라를 안 끈다 — 손을 뗀 적이 없는데도")

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
	t.eq(fs.tiles.size(), 2436, "새 섬의 지형이 2436칸 그려졌다")

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


## `position` composes `-cam_px * zoom + shake_offset()` now (`boat-and-landing`'s camera), so
## isolating the shake means subtracting the camera's own (non-shake) contribution back out.
func _shake_component(fv: FieldView) -> Vector2:
	return fv.position + fv.cam_px * fv.zoom


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


## The field-space counterpart: every rectangle has area AND lands inside the map plus its water
## margin (canvas px, `WATER_MARGIN_TILES` wide on every side) — the world the camera is allowed to
## show, not the viewport a screen-space check would wrongly hold it to.
func _rects_land_in_world(t, label: String, rects: Array[Rect2]) -> void:
	var margin_px := Look.WATER_MARGIN_TILES * Look.TILE_PX
	var world := Rect2(Vector2(-margin_px, -margin_px),
		Vector2(Look.GRID_W, Look.GRID_H) * Look.TILE_PX + Vector2(margin_px, margin_px) * 2.0)
	var no_area := 0
	var outside := 0
	for r: Rect2 in rects:
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			no_area += 1
		if r.position.x < world.position.x or r.position.y < world.position.y \
				or r.end.x > world.end.x or r.end.y > world.end.y:
			outside += 1
	t.ok(rects.size() > 0, "%s — 잴 사각형이 있다 (%d개)" % [label, rects.size()])
	t.eq(no_area, 0, "%s — 넓이 0인 사각형이 하나도 없다" % label)
	t.eq(outside, 0, "%s — 전부 지도 + 물 여백 안에 든다" % label)


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


## Alias kept for a single call site's readability — a press is exactly `_click`.
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


## The hull dict from `fs.hulls` whose width matches `want_w`, or `{}` on a miss — `.is_empty()` still
## reads correctly as "not found". Reached through `_hull_rect_of` / `_hull_colour_of` below rather
## than indexed directly: a miss indexed directly crashes the whole net on a missing key instead of
## reddening the one check that wanted it, which is exactly what happened here once (measured: a
## `BOAT_SLOT_PX`/`BOAT_HULL_PAD_PX` mutation that moved every hull's width off 124.0 crashed this
## file with "Invalid access to property or key 'rect'" instead of failing cleanly).
func _find_hull(fs: FieldSpy, want_w: float) -> Dictionary:
	for hraw: Dictionary in fs.hulls:
		if absf((hraw["rect"] as Rect2).size.x - want_w) < 0.01:
			return hraw
	return {}


## A sentinel far off-screen — no real hull could ever equal it — so a miss reddens the comparison
## that wanted the rect instead of crashing on the missing key.
func _hull_rect_of(h: Dictionary) -> Rect2:
	return h["rect"] if h.has("rect") else Rect2(Vector2(-99999.0, -99999.0), Vector2.ZERO)


func _hull_colour_of(h: Dictionary) -> Color:
	return h["colour"] if h.has("colour") else Look.COL_HOLE


## The rect list `_paint_overlay` should have been handed for harbour `reach`'s sendable tiles — the
## SAME construction `field_view._draw()` runs, so a captured `fs.overlays[...]["rects"]` can be
## compared against it directly rather than only against a count.
func _rects_of(w: int, reach: PackedByteArray) -> Array:
	var out: Array = []
	for t2 in reach.size():
		if reach[t2] != 0:
			out.append(Look.tile_rect_px(t2 % w, t2 / w))
	return out


func _wheel(at: Vector2, up: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	ev.position = at
	return ev
