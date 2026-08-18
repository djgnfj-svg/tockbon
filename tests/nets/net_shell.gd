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


## ⚠ **`_paint_berth` / `_paint_load` / `_paint_key` are GONE**, deleted with the berths and the 1/2
## keys (`plan-then-watch`, 결정 14R). What is left is one shape — a filled box with one word in it —
## used by the start button and by all five speed chips, so **one array captures both** and the checks
## below separate them by rect. Two arrays would be two names for one hook.
class HudSpy extends HudView:
	var draws := 0
	var seq := 0
	var timers := []
	var buttons := []
	var enemies := []

	func _draw() -> void:
		timers.clear()
		buttons.clear()
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

	func _paint_button(face: Font, rect: Rect2, bg: Color, text: String, at: Vector2, fsize: int,
			col: Color) -> void:
		buttons.append({"seq": _bump(), "face": face, "rect": rect, "bg": bg, "text": text, "at": at,
			"fsize": fsize, "col": col})

	func _paint_enemies_left(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		enemies.append({"seq": _bump(), "face": face, "at": at, "text": text, "fsize": fsize,
			"col": col})


## ⚠ **The whole net drives this subclass and not a bare `Game`, for ONE line.** 종료 calls
## `get_tree().quit()`, and a net cannot drive that and live to report anything: `SceneTree.quit()`
## stops the loop, every pending `await process_frame` in the runner is abandoned, and the round
## vanishes with exit code 0 instead of going red. There is no un-quit call in 4.x, and `get_tree()`
## cannot be shadowed in GDScript (measured on 4.7.1: *"overrides a method from native class Node"*,
## a parse error). So `game.gd` cuts the call out into `_quit_the_game()` — the same seam every
## `_paint_*` hook in `src/view/` is — and this counts it.
##
## ⚠ **What that buys is that the 종료 branch REACHES the seam, and nothing else.** The
## `get_tree().quit()` inside it is one statement and is not measured by anything here.
##
## Nothing else is overridden: `_ready`, `_unhandled_input`, `_process` and every handler below are
## the real ones, so what is measured is the shell rather than a fixture.
class QuitGame extends Game:
	var quits := 0

	func _quit_the_game() -> void:
		quits += 1


## The one button whose rect is `Look.start_rect_px()`, shaken or not — matched by SIZE, because the
## shake moves the position and an exact rect compare would stop finding it on the frame of a refusal,
## which is the one frame this net cares most about. `{}` when it is not on screen at all, which is
## what a committed island has to produce.
static func _start_button(hs: HudSpy) -> Dictionary:
	var want := Look.start_rect_px()
	for raw: Dictionary in hs.buttons:
		if (raw["rect"] as Rect2).size == want.size:
			return raw
	return {}


## The speed chips, in ladder order, matched by their own rects. Size alone would not do — every chip
## is the same size — so this one compares positions, which no shake ever moves.
static func _speed_chips(hs: HudSpy) -> Array:
	var out := []
	for slot in Rules.speed_slot_count():
		var want := Look.speed_rect_px(slot)
		for raw: Dictionary in hs.buttons:
			if (raw["rect"] as Rect2).position == want.position:
				out.append(raw)
				break
	return out


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
	var game := QuitGame.new()

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
	t.eq(game.get_child_count(), 5, "_ready 가 자식 다섯을 만들었다")
	t.ok(game.field_view != null and game.hud_view != null and game.map_view != null
		and game.title_view != null and game.panel_view != null, "다섯 뷰가 전부 생겼다")
	t.ok(game.get_child(0) == game.field_view and game.get_child(1) == game.hud_view
		and game.get_child(2) == game.map_view and game.get_child(3) == game.title_view
		and game.get_child(4) == game.panel_view,
		"자식 순서가 field -> hud -> map -> title -> panel 이다 (Node2D 형제의 그리기 순서가 곧 이 순서다)")
	# Named by hand, because `get_class()` on all five is "Node2D" and five identical labels do not
	# say which one went missing — a failure log that cannot narrow the cause is half a failure log.
	var built := {"field_view": game.field_view, "hud_view": game.hud_view,
		"map_view": game.map_view, "title_view": game.title_view, "panel_view": game.panel_view}
	for label: String in built:
		var v: Node2D = built[label]
		t.ok(v.is_inside_tree(), "%s 가 트리에 붙어 있다" % label)
		t.ok(v.get_parent() == game, "%s 의 부모가 Game 이다" % label)
		t.ok(v.visible, "%s 가 visible 이다" % label)

	# ⚠⚠ 「`_ready` 는 런을 안 만든다 — 켜면 타이틀이다」. The two lines that used to be here are exactly
	# what 「켜면 섬이 떵하니 나온다」 named. Mutation: put `Run.new()` back into `_ready`.
	t.ok(game.run == null, "_ready 는 런을 안 만든다 — 켜면 타이틀이다")
	t.ok(game.battle == null, "그리고 섬도 안 연다")
	t.ok(game.field_view.battle == null and game.hud_view.battle == null,
		"타이틀에서는 섬이 안 그려진다 — 두 뷰 다 볼 전투가 없다")
	t.ok(game.map_view.run == null, "지도도 아직 아무 런도 안 물었다")
	t.ok(not game.panel_view.panel_active(), "타이틀에서는 패널도 안 뜬다 (run == null)")
	t.ok(game.title_view.visible, "그리고 타이틀이 실제로 켜져 있다")

	# -- the title's three slots, through the door the OS uses -------------------------------------
	# ⚠⚠ Every press here is an `InputEventMouseButton` handed to `game._unhandled_input(ev)`, never
	# `root.push_input` (the 64x64 headless window's 0.05 stretch sends a click thousands of px away,
	# silently) and never a title-specific helper (which measures a path the player never takes).
	game._unhandled_input(_motion(Look.title_slot_hit_rect_px(0).get_center(), Vector2.ZERO))
	t.eq(game.title_view._hover_slot, 0, "커서를 시작하기 위에 올리면 셸이 그 칸을 뷰에 알린다")
	game._unhandled_input(_motion(Look.title_slot_hit_rect_px(1).get_center(), Vector2.ZERO))
	t.eq(game.title_view._hover_slot, -1, "설정하기 위에서는 호버가 -1 로 꺼진다 — 안 눌리는 칸은 안 켜진다")

	# 「설정하기 칸은 아무것도 안 한다」 — floor: `run` is still null; ceiling: no quit either.
	game._unhandled_input(_click(Look.title_slot_hit_rect_px(1).get_center()))
	t.ok(game.run == null, "설정하기를 눌러도 런이 안 생긴다")
	t.eq(game.quits, 0, "그리고 게임이 닫히지도 않는다")
	t.eq(game.title_view._press_slot, -1,
		"눌린 그림조차 안 나온다 — 아무 일도 안 일어났는데 화면만 반응하지 않는다")

	# 「종료 칸은 트리를 닫으라고 부른다」 — floor: exactly 1; ceiling: not more than 1, and no run.
	game._unhandled_input(_click(Look.title_slot_hit_rect_px(2).get_center()))
	t.eq(game.quits, 1, "종료 칸을 누르면 게임을 닫으라고 정확히 한 번 부른다")
	t.ok(game.run == null, "그러면서 런을 만들지도 않는다")
	# ⚠⚠ **The POSITIVE twin of the 설정하기 row above, and it was the missing half.** Only the negative
	# claim was asserted here, so `title_view.note_press(slot)` in `_title_input` could be deleted whole
	# — the title's only press feedback gone on both live slots — with 1816 checks green. `net_title`
	# drives `note_press` on a bare view, which never crosses the shell boundary at all.
	t.eq(game.title_view._press_slot, TitleView.SLOT_QUIT,
		"그리고 눌린 그림이 종료 칸에 실제로 들어갔다 — 셸이 뷰에 안 알리면 누른 티가 안 난다")
	t.ok(game.title_view._press_of(TitleView.SLOT_QUIT) > 0.0, "그 칸의 눌림이 0보다 크다")
	game._unhandled_input(_click(Vector2(40.0, 700.0)))
	t.eq(game.quits, 1, "빈 데를 눌러도 더 안 부른다")
	t.ok(game.run == null, "빈 데를 눌러도 런이 안 생긴다")

	# ⚠⚠ 「`run == null` 일 때 `_unhandled_input` 이 시작하기 클릭을 받는다」 — **THE mutation this net
	# exists for**: put `if run == null: return` back at the top of `_unhandled_input` and 시작하기
	# becomes unpressable, because with no run there is no way to make one.
	# 「시작하기는 섬이 아니라 지도를 연다」 — floor: `state() == MAP`; ceiling: `battle == null`.
	game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
	t.ok(game.run != null, "시작하기를 누르면 런이 생긴다")
	t.eq(game.run.state(), Run.State.MAP, "그리고 섬이 아니라 지도가 열린다")
	t.ok(game.battle == null, "섬은 아직 없다")
	t.eq(game.run.map.path.size(), 0, "밟은 칸도 아직 없다")
	t.eq(game.quits, 1, "시작하기가 종료를 부르지도 않았다")
	t.eq(game.title_view._press_slot, TitleView.SLOT_START,
		"시작하기도 눌린 그림이 들어갔다 — 두 살아 있는 칸 다 확인한다")
	t.ok(game.title_view._press_of(TitleView.SLOT_START) > 0.0, "그 칸의 눌림도 0보다 크다")
	t.ok(game.map_view.run == game.run, "지도가 그 런을 물었다")
	t.ok(not game.title_view.visible, "타이틀은 내려갔다")
	t.ok(not game.panel_view.panel_active(), "지도에서는 패널이 안 뜬다")

	# 「지도에서 칸을 누르면 섬이 열린다」 — and the ring walks first. `_process(dt)` is called by hand
	# because a headless frame is 6.9 ms and 0.45 s would be 66 frames of guessing.
	t.ok(not game._panning, "지도를 누르기 전에는 카메라를 안 끌고 있다 (자가 점검)")

	# ⚠⚠ 「커서를 얹은 칸이 켜진다」, through the door the OS uses. `net_map` drives `set_hover` on a bare
	# view; this is the line in `_map_input` that hands it the cursor, and nothing drove it — so the map
	# could stop answering the cursor entirely while the round stayed green. That is the one thing this
	# round exists to fix: what is pressable has to LOOK pressable.
	game._unhandled_input(_motion(Look.map_node_pos_px(0), Vector2.ZERO))
	t.eq(game.map_view._hover_node, 0, "커서를 0번 칸에 올리면 셸이 그 칸을 지도 뷰에 알린다")
	game._unhandled_input(_motion(Look.map_node_pos_px(6), Vector2.ZERO))
	t.eq(game.map_view._hover_node, -1, "못 가는 보스 칸 위에서는 -1 이다 — 안 눌리는 칸은 안 켜진다")
	t.ok(not game._panning, "그리고 지도 위의 커서 움직임은 카메라를 안 끈다")

	# ⚠⚠ 「닿을 수 없는 칸을 눌러도 아무 일도 안 일어난다」 — the guard is `run.map.is_reachable(n)` and
	# **the two lines under it run unconditionally**, so with the reachability test gone a press on any
	# dim node arms a 0.45 s hold that swallows every input (`_unhandled_input` returns during a hold)
	# and then quietly does nothing when `enter_node` refuses. Nothing anywhere pressed a node the run
	# may not enter — every other press in this file asserts `is_reachable` as a self-check first.
	game._unhandled_input(_press(Look.map_node_pos_px(6)))
	t.eq(game._pending_node, -1, "보스 칸을 눌러도 셸이 아무 칸도 안 든다")
	t.eq(game._hold_sec, 0.0, "그리고 붙들지도 않는다 — 0.45초 얼었다가 아무 일도 안 나는 것이 이 줄이 막는 것이다")
	t.eq(game.map_view._travel_to, -1, "고리도 출발 안 한다")
	t.ok(game.battle == null, "섬도 안 열린다")

	game._unhandled_input(_press(Look.map_node_pos_px(0)))
	t.eq(game._pending_node, 0, "0번 칸을 누르면 셸이 그 칸을 들고만 있다")
	t.eq(game._hold_sec, Look.MAP_TRAVEL_SEC, "그리고 고리가 걸을 만큼 붙들었다")
	# ⚠⚠ **The shell telling the VIEW, which nothing measured.** `map_view.note_press(n)` is the only
	# thing that arms the ring's walk, and deleting it left 1816 checks green — `_pending_node` and
	# `_hold_sec` on the two lines below it are set unconditionally, so the press produced 0.45 s of a
	# completely frozen screen and then the island. That is the exact "cut straight to the island"
	# failure `MAP_TRAVEL_SEC` exists to prevent, plus a wait.
	t.eq(game.map_view._travel_to, 0, "셸이 뷰에도 알렸다 — 고리가 0번 칸을 향해 출발했다")
	t.eq(game.map_view._press_node, 0, "그리고 그 칸이 눌린 그림으로도 들어갔다")
	# 「지도에서 누른 클릭이 카메라를 안 움직인다」 — mutation: move the map branch below the
	# `battle != null` block, and `_on_left_press`'s fall-through pans the island behind the map.
	t.ok(not game._panning, "지도에서 누른 클릭은 카메라를 안 끈다")
	t.ok(game.battle == null, "고리가 걷는 동안 섬은 아직 안 열렸다 — 잘라 붙이면 지도가 한 일이 안 보인다")
	game._process(Look.MAP_TRAVEL_SEC)
	t.eq(game._pending_node, -1, "고리가 도착하자 셸이 손을 놓았다")
	t.ok(game.battle != null, "그제서야 섬이 열렸다")
	t.eq(game.run.state(), Run.State.BATTLE, "런도 전투 상태다")
	t.eq(game.run.map.at(), 0, "서 있는 칸이 0번이다")
	t.eq(game.run.island_index, Rules.map_island_of(0), "그 칸이 가리키는 섬이 열렸다")
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

	# The shell really drives the clock — **and it takes a committed island to prove it now.** An
	# uncommitted `Battle` is inert to every driver (`plan-then-watch`, 4.3), so a bare
	# `pump_frames` here would leave `elapsed` at 0 for a reason that has nothing to do with the shell.
	# Both halves are measured: frozen before the start button, moving after it.
	await t.pump_frames(3)
	t.eq(game.battle.elapsed, 0.0,
		"확정 전에는 셸이 프레임을 돌려도 시계가 정확히 0이다 — 계획하는 동안은 공짜다")
	var probe_tile := -1
	for pt in game.battle.grid.passable.size():
		if game.battle.grid.home_harbour_for(pt) >= 0:
			probe_tile = pt
			break
	t.ok(probe_tile >= 0 and game.battle.send(0, probe_tile) >= 0 and game.battle.commit(),
		"한 척을 보내고 확정했다 (자가 점검)")
	# ⚠ **Enough frames to cross ONE sub-step.** `step` consumes whole `Rules.SIM_SUBSTEP_SEC` chunks
	# and carries the leftover, so three headless frames can accumulate less than 1/60 s and leave
	# `elapsed` at exactly 0 for a reason that says nothing about the shell.
	var pumped := 0
	while pumped < 60 and game.battle.elapsed <= 0.0:
		await t.pump_frames(1)
		pumped += 1
	t.ok(pumped > 0 and pumped < 60, "%d 프레임 만에 시계가 움직였다 (자가 점검)" % pumped)
	t.ok(game.battle.elapsed > 0.0, "셸의 _process 가 battle.step 을 진짜 돌렸다 (elapsed %.4f)"
		% game.battle.elapsed)
	t.ok(fs.draws >= 1, "field_view 의 _draw 가 트리 위에서 진짜 돌았다 (%d프레임)" % fs.draws)
	t.ok(hs.draws >= 1, "hud_view 의 _draw 가 진짜 돌았다 (%d프레임)" % hs.draws)
	t.ok(ps.draws >= 1, "panel_view 의 _draw 가 진짜 돌았다 (%d프레임)" % ps.draws)

	# A FRESH island for everything below: `run.begin_island()` builds a new `Battle` every call, so
	# re-opening puts the shell back in the planning state the rest of this file measures. The commit
	# above was a probe, not the state under test.
	game._open_island()
	await t.pump_frames(2)
	t.ok(not game.battle.committed(), "다시 연 섬은 계획 상태다 (자가 점검)")
	t.eq(game.battle.boats.size(), 0, "그리고 계획이 비어 있다 (자가 점검)")

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
	# ⚠ **4032 and 1536 are written out as literals**, not as `wt * ht`. A check whose bounds come
	# from the thing it checks proves nothing: with the count derived from `Look.WATER_MARGIN_TILES`,
	# setting that constant to 0 would move the expectation and the reality together and the margin
	# could vanish with the round green.
	t.eq(wt * ht, 4032, "물 여백까지 세면 4032칸이다 (72 x 56) — 여백 상수가 0이 되면 여기가 문다")
	t.eq(Look.GRID_W * Look.GRID_H, 1536, "격자 자체는 1536칸이다")
	t.eq(fs.tiles.size(), 4032, "지형을 물 여백까지 4032칸 그렸다")
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
	t.eq(tile_bad, 0, "4032칸이 전부 자기 자리의 사각형을 받았다 (행 우선, 여백 포함)")
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

	# ⚠⚠ **The idle-hull rows are DELETED with the fleet they measured** (`plan-then-watch`, 결정 14R).
	# Before the start button there are no boats at all — a boat is created BY a drop — so what stands
	# at the harbour is the ARMY, one body per RESERVE soldier at `idle_soldier_rect(i)`. That is the
	# thing the player drags, and it is what replaces them.
	t.eq(fs.hulls.size(), 0, "커밋 전에는 선체가 하나도 없다 — 배는 놓아야 생긴다")
	var start_anchor := Look.tile_point_px(b.grid.tile_point(int(b.grid.harbour_tiles[b.grid.start_harbour])))
	var reserve_ids := []
	for si in b.soldier_state.size():
		if b.soldier_state[si] == Battle.SoldierState.RESERVE:
			reserve_ids.append(si)
	t.eq(reserve_ids.size(), Rules.START_MELEE + Rules.START_RANGED,
		"열 명 전부 예비다 (자가 점검)")
	var idle_bad := 0
	var idle_rects: Array[Rect2] = []
	for si2 in reserve_ids:
		var want_rect: Rect2 = fs.idle_soldier_rect(int(si2))
		if want_rect.size == Vector2.ZERO:
			idle_bad += 1
			continue
		idle_rects.append(want_rect)
		var found := false
		for braw: Dictionary in fs.bodies:
			if (braw["centre"] as Vector2).distance_to(want_rect.get_center()) < 0.01:
				found = true
				# ⚠⚠ **The picture and the hit target have to be ONE fact, and they are computed
				# twice from the same source.** `idle_soldier_rect` derives its size from
				# `Look.body_radius_of` and `field_view._draw` hands the same call to `_paint_body`
				# independently, so a zero radius at the draw call leaves `game._soldier_hit_at`
				# answering over a full ~28 px box while only the 3 px dot reaches the screen — the
				# player drags soldiers that are not visibly there. **Measured: `0.0` at that one
				# argument passed the whole round before this line.** Both ends: it is above zero,
				# and doubled it IS the rect the hit test uses.
				if float(braw["radius"]) <= 0.0:
					idle_bad += 1
				elif absf(2.0 * float(braw["radius"]) - want_rect.size.x) > 0.001:
					idle_bad += 1
				break
		if not found:
			idle_bad += 1
	t.eq(idle_bad, 0,
		"예비 병사마다 몸 하나가 idle_soldier_rect 자리에 그 사각형 크기로 그려졌다 — 그린 것과 누를 것이 한 사실이다")
	t.eq(idle_rects.size(), reserve_ids.size(), "빈 사각형을 돌려준 자리가 없다 (자가 점검)")
	# ⚠⚠ **`look.gd`'s own stated ceiling for the stack, read back as a number.** Its comment on
	# `IDLE_SOLDIER_ORIGIN_PX` writes the bound as three tiles on each axis — the stack has to read as
	# *at* the harbour rather than somewhere else on the map. It is checked for all THIRTEEN slots and
	# not only the ten standing here, because islands 2 and 3 field thirteen and the slot is the
	# soldier ID rather than a position in a list.
	# **Measured: `IDLE_SOLDIER_COLS := 2` puts slot 12 six rows up (252 px) and this is the row that
	# catches it.** A bound against the painted map does NOT — the stack grows UPWARD and the water
	# margin is twelve tiles deep, so it never leaves the picture at all, and the plan's predicted
	# 「the stack walks off the bottom edge」 is the wrong direction.
	var too_far := 0
	for slot in 13:
		var off := Look.idle_soldier_offset_px(slot)
		if absf(off.x) > Look.TILE_PX * 3.0 or absf(off.y) > Look.TILE_PX * 3.0:
			too_far += 1
	t.eq(too_far, 0, "열세 칸 전부가 항구에서 3타일 안에 있다 — 무더기가 항구에 선 것으로 읽힌다")
	t.ok(Look.idle_soldier_offset_px(1) != Look.idle_soldier_offset_px(0),
		"그리고 칸마다 자리가 다르다 (바닥 — 전부 같으면 열 몸이 한 덩어리다)")
	var far := 0
	for r: Rect2 in idle_rects:
		if r.get_center().distance_to(start_anchor) > Look.TILE_PX * 6.0:
			far += 1
	t.eq(far, 0, "그리고 그려진 무더기도 시작 항구 근처다 — 지도 딴 곳이 아니다")
	# ⚠⚠ **This is 6.3's own row**: the thing you drag must never be under the chrome you press. At
	# `ZOOM_MIN` the island band and the HUD's two corners both exist, so the two rectangles are
	# compared for real — `HUD_START_ORIGIN_PX` moved to the bottom CENTRE is the mutation.
	t.eq(fs.zoom, Look.ZOOM_MIN, "섬이 ZOOM_MIN 으로 열려 있다 (자가 점검 — 이 절의 좌표 변환이 그 값을 쓴다)")
	var chrome: Array[Rect2] = [Look.start_rect_px()]
	for ci in Rules.speed_slot_count():
		chrome.append(Look.speed_rect_px(ci))
	var overlap := 0
	for r2: Rect2 in idle_rects:
		var screen_rect := Rect2(r2.position * fs.zoom + fs.position, r2.size * fs.zoom)
		for c: Rect2 in chrome:
			if screen_rect.intersects(c):
				overlap += 1
	t.eq(overlap, 0, "항구에 선 병사는 시작 버튼과 배속 칩 밑에 안 깔린다 (ZOOM_MIN 에서)")

	# P10: `_paint_cliff_face` is called every frame regardless (so the seq-order check above always
	# has something to compare against), but that alone proves nothing was thrown away INSIDE it —
	# island 1's row 2 is solid `^` over open water, so the geometry itself has to be non-empty too.
	t.eq(fs.cliff_faces.size(), 1, "절벽 단면 훅을 한 번 불렀다")
	var cliff_pts: PackedVector2Array = fs.cliff_faces[0]["points"]
	t.eq(cliff_pts.size() % 2, 0, "점이 짝수 개다 — 선분마다 두 점 (자가 점검)")
	var seg_count := cliff_pts.size() / 2
	t.ok(seg_count >= 40, "그 안에 실제 절벽 단면 선분이 들어 있다 (%d개, 최소 40)" % seg_count)
	t.eq(fs.cliff_faces[0]["colour"], Look.COL_CLIFF_FACE, "절벽 단면 색이 look.gd 값이다")
	t.eq(float(fs.cliff_faces[0]["width"]), 5.0, "절벽 단면 굵기가 5.0px 리터럴과 같다")
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
	# ⚠ **The idle army is on this layer too now.** The enemies are drawn AFTER it (layer 7 against
	# layer 6b), so the enemy bodies are the LAST `reserve_ids.size()` entries — the offset is written
	# out rather than assumed, and the row above already pinned how many idle bodies there are.
	t.eq(fs.bodies.size(), live_enemies.size() + reserve_ids.size(),
		"몸통 수 = 살아 있는 적 수 + 항구에 선 예비 병사 수")
	var enemy_base := reserve_ids.size()
	var body_bad := 0
	for k in live_enemies.size():
		var e: int = live_enemies[k]
		var et := int(b.enemy_type[e])
		var got: Dictionary = fs.bodies[enemy_base + k]
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
	# ⚠ **There are no hulls on this frame at all** — nothing has been dropped, so `fs.hulls` is empty
	# and the old 「항구 -> 선체 -> 몸」 pair would be comparing sentinels. The hull's own layer is
	# re-pinned after the commit, further down, where a hull actually exists.
	t.ok(_seq_max(fs.docks) < _seq_min(fs.bodies), "층 2 항구가 층 6b/7 몸보다 먼저 그려졌다")
	t.ok(_seq_max(fs.bodies) < _seq_max(fs.hps) or fs.hps.is_empty(),
		"몸과 HP 막대가 같은 층에서 함께 나온다 (자가 점검)")

	# -- the HUD, and the number on it coming from the sim -----------------------------------------
	t.eq(hs.timers.size(), 1, "타이머를 한 번 그렸다")
	# 「시간 %.1f」 and not 「남은 시간 %.1f」 — the user asked for fewer words and bigger type, and this
	# is the half a net can hold: one word instead of two.
	t.eq(str(hs.timers[0]["text"]), "시간 %.1f" % b.time_left(), "타이머 글자가 sim 의 남은 시간이다")
	t.eq(hs.timers[0]["at"], Look.HUD_TIMER_POS_PX, "타이머 위치가 look.gd 값이다")

	# ⚠⚠ **The berth boxes, the per-boat load labels and the two key slots are all DELETED**, with the
	# fleet and the keyboard they belonged to. What is on this layer now is one start button and five
	# speed chips — six calls to ONE hook — plus the timer and the enemy count.
	t.eq(hs.buttons.size(), 1 + Rules.speed_slot_count(),
		"HUD 단추는 시작 하나 + 배속 칩 다섯, 여섯 번이다")
	var start_btn := _start_button(hs)
	t.ok(not start_btn.is_empty(), "시작 버튼이 화면에 있다")
	t.eq(str(start_btn["text"]), "시작", "시작 버튼에 「시작」이라고 쓰여 있다")
	t.eq(start_btn["rect"], Look.start_rect_px(), "그리고 안 흔들린 자리에 있다")
	t.eq(start_btn["bg"], Look.COL_START, "아직 아무것도 안 눌러서 시작 버튼이 기본색이다 (바닥)")
	t.eq(start_btn["fsize"], Look.HUD_START_FONT_SIZE_PX, "글자 크기가 look.gd 값이다")
	# The label has to be PLACED inside the box, not dropped at its origin — a glyph at the rect's own
	# corner is a glyph nobody positioned, and it is the floor proving the label exists at all.
	var start_at: Vector2 = start_btn["at"]
	t.ok(start_at.distance_to((start_btn["rect"] as Rect2).position) > 1.0,
		"그리고 글자가 상자 모서리가 아니라 상자 안쪽에 놓였다")
	t.ok((start_btn["rect"] as Rect2).has_point(start_at), "그 자리가 상자 안이다 (천장)")

	var chips := _speed_chips(hs)
	t.eq(chips.size(), Rules.speed_slot_count(), "배속 칩을 사다리 칸 수만큼 그렸다")
	var lit := 0
	var chip_text_bad := 0
	for ci2 in chips.size():
		var chip: Dictionary = chips[ci2]
		if chip["bg"] == Look.COL_SPEED_ON:
			lit += 1
		if str(chip["text"]) != str(HudView.SPEED_LABELS[ci2]):
			chip_text_bad += 1
	t.eq(lit, 1, "칩 하나만 켜져 있다 — 지금 보고 있는 배속이다")
	t.eq(chip_text_bad, 0, "칩마다 자기 배속 숫자가 쓰여 있다 (동사 없는 숫자 다섯)")
	t.eq(chips[Rules.SPEED_SLOT_DEFAULT]["bg"], Look.COL_SPEED_ON,
		"켜진 칸이 SPEED_SLOT_DEFAULT 다 — 섬은 1배속으로 열린다")
	t.eq(chips[0]["bg"], Look.COL_BUTTON, "안 켜진 칩은 COL_BUTTON 이다")

	t.eq(hs.enemies.size(), 1, "남은 적 수를 한 번 그렸다")
	t.eq(str(hs.enemies[0]["text"]), "적 %d" % b.enemies_left(), "남은 적 글자가 sim 의 수다")
	t.eq(ps.panels.size(), 0, "전투 중에는 패널이 한 번도 안 그려졌다")
	# ⚠ **The counted glyph budget**, written down because 6.1 predicted it: 1 timer + 1 start label
	# + 5 chip labels + 1 enemy count = **8 text items on the planning screen**, against the shipped
	# build's 6. The prediction was right and this is where it is recorded so it cannot drift.
	t.eq(hs.timers.size() + hs.buttons.size() + hs.enemies.size(), 8,
		"계획 화면의 글자 항목은 여덟이다 (타이머 1 + 시작 1 + 칩 5 + 적 1)")
	t.ok(hs.timers[0]["seq"] < start_btn["seq"] and start_btn["seq"] < _seq_min(chips)
		and _seq_max(chips) < hs.enemies[0]["seq"],
		"HUD 는 타이머 -> 시작 버튼 -> 배속 칩 -> 남은 적 순서로 그린다")

	# **The resting look of the start button**, captured before any press. Item 8's whole content is
	# the DIFFERENCE from this, so it has to be read once while nothing has happened yet.
	var rest_key_rect: Rect2 = start_btn["rect"]
	var rest_key_at: Vector2 = start_btn["at"]

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
	# ⚠ **The idle stack is in here on purpose.** It is laid out from `Look.IDLE_SOLDIER_*` and nothing
	# else bounds it: `IDLE_SOLDIER_COLS := 2` puts thirteen bodies in seven rows and the stack walks
	# off the bottom of the painted map, with every other check about it green.
	for r3: Rect2 in idle_rects:
		field_rects.append(r3)
	_rects_land_in_world(t, "전투 화면 — 필드", field_rects)

	var hud_rects: Array[Rect2] = []
	for it: Dictionary in hs.buttons:
		hud_rects.append(it["rect"])
	_rects_land_on_screen(t, "전투 화면 — HUD", hud_rects)

	# -- the plan, authored with the mouse (plan-then-watch, section 7) -------------------------------
	# ⚠⚠ **`_on_key` is deleted whole and the `InputEventKey` branch of `_unhandled_input` went with
	# it.** Everything below goes through press / motion / release, which is the only way a landing can
	# be authored now, and through the start button, which is the only way the clock can be started.
	#
	# The camera is parked at a KNOWN state — zoom 1.0, cam_px ZERO, no shake — so canvas (world) px
	# and screen px coincide and a tile's press position is just `Look.tile_point_px(...)`.
	fs.zoom = 1.0
	fs.cam_px = Vector2.ZERO
	await t.pump_frames(1)
	t.eq(fs.position, Vector2.ZERO, "카메라를 원점에 세웠다 — 화면 좌표와 세계 좌표가 같다 (자가 점검)")

	var start_hb := b.grid.start_harbour
	var send: PackedByteArray = b.grid.sendable[start_hb]
	var droppable_tiles := []
	for tt in b.grid.passable.size():
		if b.grid.home_harbour_for(tt) >= 0:
			droppable_tiles.append(tt)
	t.ok(droppable_tiles.size() > 0, "이 섬에 배를 보낼 수 있는 칸이 있다 (자가 점검)")
	var sendable_tile: int = int(droppable_tiles[0])
	var second_tile: int = int(droppable_tiles[droppable_tiles.size() - 1])
	t.ok(sendable_tile != second_tile, "서로 다른 상륙지 둘을 골랐다 (자가 점검)")
	var sendable_px := Look.tile_point_px(b.grid.tile_point(sendable_tile))
	var second_px := Look.tile_point_px(b.grid.tile_point(second_tile))
	var refuse_tile := int(b.grid.harbour_tiles[start_hb])   # water — never landable
	var refuse_px := Look.tile_point_px(b.grid.tile_point(refuse_tile))

	# ⚠ **The droppable coast is on screen from the moment the island opens**, not only while a drag is
	# in flight — the user's 「바다위에 초록색 지역」 is a standing invitation. And it is painted from the
	# UNION over every harbour, which is the same predicate `battle.send` refuses on, so the screen can
	# never promise a tile the sim then refuses.
	t.eq(fs.overlays.size(), 1, "아무것도 안 끌고 있어도 상륙 가능 구역이 그려진다")
	t.eq((fs.overlays[0]["rects"] as Array).size(), droppable_tiles.size(),
		"그 칸 수가 home_harbour_for 가 받아주는 칸 수와 같다 — 항구 하나가 아니라 셋의 합집합이다")
	t.ok(droppable_tiles.size() > _count_set(send),
		"그리고 시작 항구 혼자 닿는 칸(%d)보다 넓다 — 합집합이라는 증거다" % _count_set(send))
	t.ok(absf((fs.overlays[0]["colour"] as Color).a - Look.DROP_TINT_ALPHA) < 0.001,
		"타일 알파가 DROP_TINT_ALPHA 와 같다")

	# -- item 8: a refused START shakes the button, and an accepted one does not ---------------------
	# ⚠ **This runs FIRST, while `boats` is still empty**, because an empty plan is the only thing that
	# makes `commit()` refuse. Both ends of the amplitude are pinned — `REFUSE_SHAKE_PX`'s only reader
	# is this shake now (`_berth_offset` died with the berths), so deleting the shake deletes the
	# constant's last reader and a floor alone would not notice.
	t.eq(b.boats.size(), 0, "아직 아무 배도 안 놓았다 (자가 점검)")
	t.root.push_input(_press(Look.start_rect_px().get_center()), true)
	await t.pump_frames(1)
	t.root.push_input(_release(Look.start_rect_px().get_center()), true)
	t.ok(not b.committed(), "배를 안 띄우고 누른 시작은 거절된다 — 판이 확정되지 않았다")
	var refused_btn := _start_button(hs)
	t.ok(not refused_btn.is_empty(), "거절당한 뒤에도 시작 버튼은 화면에 있다 (자가 점검)")
	t.ok(refused_btn["bg"] != Look.COL_START, "거절된 시작 버튼 색이 기본색에서 벗어났다 (바닥)")
	var key_shift: Vector2 = (refused_btn["rect"] as Rect2).position - rest_key_rect.position
	t.ok(key_shift.length() > 0.0, "거절된 시작 버튼이 흔들렸다 (%.2f px)" % key_shift.length())
	t.ok(key_shift.length() <= Look.REFUSE_SHAKE_PX + 0.01,
		"그리고 REFUSE_SHAKE_PX 를 안 넘는다 (천장 — 바닥만 재면 진폭이 폭주해도 초록이다)")
	t.ok(absf(key_shift.y) <= 0.0, "흔들림은 좌우뿐이다")
	# ⚠ A tolerance and not `==`: both sides are differences of sums of the same floats. 0.01 px is two
	# orders below the shake's own amplitude, so it cannot absorb the bug it exists to catch — shaking
	# the box alone leaves the label at exactly 0.
	var label_shift: Vector2 = (refused_btn["at"] as Vector2) - rest_key_at
	t.ok(label_shift.distance_to(key_shift) < 0.01,
		"글자도 상자와 같은 오프셋만큼 움직였다 (상자 %.3f · 글자 %.3f)" % [key_shift.x, label_shift.x])

	# -- the drag: press a body standing at the harbour, release on a coast -------------------------
	var idle0 := fs.idle_soldier_rect(0)
	var idle1 := fs.idle_soldier_rect(1)
	t.ok(idle0.size != Vector2.ZERO and idle1.size != Vector2.ZERO,
		"0번과 1번 병사가 항구에 서 있다 (자가 점검)")
	t.ok(not idle0.intersects(idle1), "그 둘의 사각형이 겹치지 않는다 — 눌러서 구별할 수 있다 (자가 점검)")

	# A refusal first: released over water, nothing at all is created.
	t.root.push_input(_press(idle0.get_center()), true)
	await t.pump_frames(1)
	t.eq(game._drag_soldier, 0, "항구에 선 병사를 누르면 그 병사를 붙잡는다")
	t.ok(not game._panning, "그리고 카메라는 안 끌린다 — 병사를 눌렀지 필드를 누른 게 아니다")
	t.root.push_input(_motion(refuse_px, Vector2.ZERO), true)
	await t.pump_frames(1)
	t.eq(fs.rings.size(), 1, "후보 링이 정확히 하나 떴다")
	t.eq(Vector2(fs.rings[0]["centre"]), refuse_px, "커서를 따라 그 칸에 링이 떴다")
	t.eq(fs.rings[0]["colour"], Look.COL_LOSE, "거절되는 칸이면 링이 거절(COL_LOSE) 색이다")
	t.root.push_input(_motion(sendable_px, Vector2.ZERO), true)
	await t.pump_frames(1)
	t.eq(Vector2(fs.rings[0]["centre"]), sendable_px, "커서를 옮기면 링도 따라온다")
	t.eq(fs.rings[0]["colour"], Look.COL_WIN, "받아주는 칸이면 링이 수락(COL_WIN) 색이다")
	t.eq(fs.routes.size(), 1, "항로 선도 하나 그렸다")
	t.eq(Vector2(fs.routes[0]["to"]), sendable_px, "그 선이 커서 쪽에서 끝난다")
	t.ok(Vector2(fs.routes[0]["from"]).distance_to(sendable_px) > 1.0,
		"그리고 실제 길이가 있다 — 두 끝점이 겹치지 않는다")
	t.root.push_input(_motion(refuse_px, Vector2.ZERO), true)
	await t.pump_frames(1)
	t.root.push_input(_release(refuse_px), true)
	await t.pump_frames(1)
	t.eq(b.boats.size(), 0, "물 위에 놓으면 아무 배도 안 생긴다")
	t.eq(b.soldier_state[0], Battle.SoldierState.RESERVE, "그 병사는 항구에 그대로 남는다")
	t.eq(game._drag_soldier, -1, "드래그가 끝났다 (자가 점검)")

	# The accepted drop: one boat, carrying THAT soldier, and the clock still exactly stopped.
	t.root.push_input(_press(idle0.get_center()), true)
	await t.pump_frames(1)
	t.root.push_input(_motion(sendable_px, Vector2.ZERO), true)
	await t.pump_frames(1)
	t.root.push_input(_release(sendable_px), true)
	await t.pump_frames(1)
	t.eq(b.boats.size(), 1, "받아주는 칸에 놓자 배가 하나 생겼다")
	var aboard0: Array = (b.boats[0] as Dictionary)["soldiers"]
	t.eq(aboard0.size(), 1, "그 배에 한 명이 탔다")
	t.eq(int(aboard0[0]), 0, "끌어 놓은 그 병사가 탄다 — 항상 0번을 태우는 게 아니다")
	t.eq(int((b.boats[0] as Dictionary)["target"]), sendable_tile, "놓은 바로 그 칸으로 간다")
	t.eq(b.soldier_state[0], Battle.SoldierState.TRANSIT, "그 병사는 이제 배 위다")
	# ⚠⚠ **결정 1 as a check**: dropping is planning, not starting.
	t.eq(b.elapsed, 0.0, "놓기는 계획일 뿐 시작이 아니다 — 시계가 여전히 정확히 0이다")
	t.eq(float((b.boats[0] as Dictionary)["t"]), 0.0, "그 배의 항해 시간도 여전히 정확히 0이다")
	t.ok(not b.committed(), "그리고 판은 아직 확정되지 않았다")

	# The soldier that was sent is no longer standing at the harbour to be grabbed again.
	t.eq(fs.idle_soldier_rect(0), Rect2(), "보낸 병사는 항구에서 사라진다 — 다시 못 잡는다")
	t.eq(game._soldier_hit_at(idle0.get_center()), -1, "그 자리를 눌러도 아무도 안 잡힌다")

	# -- the ring undoes the drop, and it beats the body in the hit test ----------------------------
	var uid0 := int((b.boats[0] as Dictionary)["uid"])
	t.root.push_input(_press(sendable_px), true)
	await t.pump_frames(1)
	t.root.push_input(_release(sendable_px), true)
	await t.pump_frames(1)
	t.eq(b.boats.size(), 0, "고리를 누르면 무른다")
	t.eq(b.soldier_state[0], Battle.SoldierState.RESERVE, "무른 병사가 항구로 돌아온다")
	t.ok(fs.idle_soldier_rect(0).size != Vector2.ZERO, "그리고 다시 항구에 그려진다")
	t.eq(game._ring_hit_at(sendable_px), -1, "그 번호는 이제 화면에 없다 (uid %d)" % uid0)

	# ⚠⚠ **The precedence itself, and it has to be BUILT.** A landing ring can sit on top of a body
	# standing at the harbour when a player drops a boat onto the beach beside it — but on all three
	# shipped islands every harbour is on the bottom row and every landable tile is far north, so the
	# overlap never happens by itself and a check that waited for it would measure nothing. **Measured:
	# swapping the two hit tests in `_on_left_press` left this net entirely green until this fixture
	# existed.** ⇒ the boat's `target` is poked onto the tile the idle stack is drawn over, the same
	# technique `net_fx_view` uses to force a RETURNING boat, and then a real press is driven at it.
	t.root.push_input(_press(idle0.get_center()), true)
	await t.pump_frames(1)
	t.root.push_input(_motion(sendable_px, Vector2.ZERO), true)
	await t.pump_frames(1)
	t.root.push_input(_release(sendable_px), true)
	await t.pump_frames(1)
	t.eq(b.boats.size(), 1, "겹침 시험용으로 한 척을 놓았다 (자가 점검)")
	var over_world := idle1.get_center()
	var over_tv := fs.world_to_tile(over_world)
	var over_tile := b.grid.tile_index(over_tv.x, over_tv.y)
	var forced: Dictionary = b.boats[0]
	forced["target"] = over_tile
	b.boats[0] = forced
	await t.pump_frames(1)
	var over_px := Look.tile_point_px(b.grid.tile_point(over_tile))
	t.ok(over_px.distance_to(over_world) <= Look.TARGET_RING_R_PX,
		"그 고리의 중심이 병사 몸 안에 든다 (자가 점검 — 두 판정이 실제로 겹친다)")
	t.ok(idle1.has_point(over_px), "그리고 그 점은 병사 사각형 안이기도 하다 (자가 점검)")
	t.eq(game._soldier_hit_at(over_px), 1, "몸 판정만 물으면 그 병사를 잡는다 (자가 점검)")
	t.ok(game._ring_hit_at(over_px) >= 0, "고리 판정만 물어도 그 배를 잡는다 (자가 점검)")
	t.root.push_input(_press(over_px), true)
	await t.pump_frames(1)
	t.eq(b.boats.size(), 0, "고리가 병사보다 먼저 잡힌다 — 그 자리는 무르기다")
	t.eq(game._drag_soldier, -1, "그리고 드래그가 시작되지 않았다")
	t.root.push_input(_release(over_px), true)
	await t.pump_frames(1)

	# -- ghosts stand in DROP ORDER, and there is no cap on how many boats ---------------------------
	# ⚠⚠ **Two of the three go to ONE beach and the third to a DIFFERENT one, and that is the whole
	# point of the fixture.** The fan rank has to be counted among the boats sharing a landing, not
	# among all boats: fanning by the `boats` index puts the third ghost 25.5 px from a ring of radius
	# 18 even in this three-boat plan, and 3.8 tiles away in a thirteen-boat one — a ghost standing
	# over other terrain, which is the plan lying. **Measured: with every drop aimed at one tile the
	# two indices coincide and this row cannot tell them apart.**
	var order := [3, 1, 2]
	var order_px := [second_px, second_px, sendable_px]
	var order_tile := [second_tile, second_tile, sendable_tile]
	for oi in order.size():
		var sid := int(order[oi])
		var irect2 := fs.idle_soldier_rect(sid)
		t.ok(irect2.size != Vector2.ZERO, "%d번 병사가 항구에 서 있다 (자가 점검)" % sid)
		t.root.push_input(_press(irect2.get_center()), true)
		await t.pump_frames(1)
		t.root.push_input(_motion(order_px[oi], Vector2.ZERO), true)
		await t.pump_frames(1)
		t.root.push_input(_release(order_px[oi]), true)
		await t.pump_frames(1)
	t.eq(b.boats.size(), order.size(), "셋을 순서대로 놓았다 — 둘은 같은 해변, 하나는 다른 해변")
	var order_bad := 0
	var target_bad := 0
	for oi2 in order.size():
		var carried: Array = (b.boats[oi2] as Dictionary)["soldiers"]
		if int(carried[0]) != int(order[oi2]):
			order_bad += 1
		if int((b.boats[oi2] as Dictionary)["target"]) != int(order_tile[oi2]):
			target_bad += 1
	t.eq(order_bad, 0, "boats 의 순서가 놓은 순서 그대로다 — 이것이 앞자리를 정한다")
	t.eq(target_bad, 0, "그리고 배마다 제가 노린 칸을 들고 있다 (자가 점검 — 해변이 실제로 둘이다)")

	# The ghost fan. The rank is how many EARLIER boats aim at the SAME tile, so the offsets have to
	# be strictly increasing within a beach — a constant fan (`rank * 0`) is the fake this row exists
	# to make impossible — and every ghost has to land inside its own landing ring.
	var ghosts := []
	for braw2: Dictionary in fs.bodies:
		if braw2["colour"] == Look.ghost_tint():
			ghosts.append(braw2)
	t.eq(ghosts.size(), b.boats.size(), "놓은 배마다 유령이 하나씩 서 있다")
	# ⚠⚠ **The floor is `plan-then-watch` 6.4's own number, not a bare `> 0`.** At alpha 0.02 the fan
	# is invisible on screen and the only picture carrying drop order stops existing — which deletes
	# this design's stated survival condition — while a `> 0.0` floor stays green. **Measured: with
	# the floor at 0.0, `GHOST_ALPHA := 0.02` passed the whole round.**
	t.ok((Look.ghost_tint() as Color).a >= 0.35 - 1e-6,
		"유령이 계획을 읽을 만큼 진하다 (바닥 0.35 — 더 옅으면 계획이 화면에 없는 것과 같다)")
	t.ok((Look.ghost_tint() as Color).a < 1.0, "그리고 상륙한 몸과 구별된다 (천장)")
	var fan_bad := 0
	var ring_bad := 0
	var ghost_size_bad := 0
	var rank_seen := {}
	for gi in ghosts.size():
		var gboat: Dictionary = b.boats[gi]
		var gtile := int(gboat["target"])
		var grank := int(rank_seen.get(gtile, 0))
		rank_seen[gtile] = grank + 1
		var gtarget_px := Look.tile_point_px(b.grid.tile_point(gtile))
		var want_c := gtarget_px + Look.GHOST_FAN_PX * float(grank)
		var got_c := ghosts[gi]["centre"] as Vector2
		if got_c.distance_to(want_c) > 0.01:
			fan_bad += 1
		# The ceiling that catches a fan ranked by the wrong index: a ghost that is not on its own
		# landing is not a picture of that landing.
		if got_c.distance_to(gtarget_px) > Look.TARGET_RING_R_PX:
			ring_bad += 1
		# ⚠⚠ **The radius, read off the captured argument.** `_paint_body` handed 0.0 collapses the
		# rounded square to the 3 px `BODY_DOT_RADIUS_PX` dot: thirteen identical dots, melee and
		# ranged indistinguishable, with the fan offsets above still perfect. **Measured: it passed
		# the whole round before this line.** Both ends — it is not zero, and it is the size the type
		# says.
		var gsid := int((gboat["soldiers"] as Array)[0])
		var gwant_r := Look.body_radius_of(int(b.army.type_id[gsid]))
		if float(ghosts[gi]["radius"]) <= 0.0 or absf(float(ghosts[gi]["radius"]) - gwant_r) > 0.001:
			ghost_size_bad += 1
	t.eq(fan_bad, 0, "유령이 놓은 순서대로 늘어선다 — 같은 해변의 k번째가 상륙지 + k × GHOST_FAN_PX 다")
	t.eq(ring_bad, 0, "그리고 유령마다 제 상륙 고리 안에 선다 — 부채가 다른 해변까지 흘러나가지 않는다")
	t.eq(ghost_size_bad, 0,
		"유령마다 반지름이 그 병종의 몸 크기다 (바닥 0 초과 — 0이면 점 하나만 남고 근접·원거리가 같아진다)")
	t.ok((ghosts[1]["centre"] as Vector2).distance_to(ghosts[0]["centre"] as Vector2) > 0.0,
		"그리고 부채가 실제로 벌어져 있다 (바닥 — 고정 오프셋이면 여기가 문다)")

	# One route and one ring per boat, all of them at once: this is 「the whole plan on one page」.
	t.eq(fs.routes.size(), b.boats.size(), "계획한 항로가 배마다 하나씩, 전부 그려진다")
	var route_bad := 0
	for ri in b.boats.size():
		var want_to := Look.tile_point_px(b.grid.tile_point(int((b.boats[ri] as Dictionary)["target"])))
		if Vector2(fs.routes[ri]["to"]).distance_to(want_to) > 0.01:
			route_bad += 1
	t.eq(route_bad, 0, "항로마다 끝점이 그 배가 노리는 칸이다")

	# ⚠⚠ **OPEN 0 as a shell check.** The brake is deliberately absent (the user: 「일단 빼고 만든 이후에
	# 추가하자는 거임」), so every remaining soldier has to be sendable. A cap appearing here is not a
	# fix — it is a decision nobody made.
	var still_reserve := []
	for si3 in b.soldier_state.size():
		if b.soldier_state[si3] == Battle.SoldierState.RESERVE:
			still_reserve.append(si3)
	t.ok(still_reserve.size() > 0, "아직 항구에 남은 병사가 있다 (자가 점검)")
	for si4 in still_reserve:
		var irect3 := fs.idle_soldier_rect(int(si4))
		t.root.push_input(_press(irect3.get_center()), true)
		await t.pump_frames(1)
		t.root.push_input(_motion(sendable_px, Vector2.ZERO), true)
		await t.pump_frames(1)
		t.root.push_input(_release(sendable_px), true)
		await t.pump_frames(1)
	t.eq(b.boats.size(), Rules.START_MELEE + Rules.START_RANGED,
		"명단 전부를 보낼 수 있다 — 배 수에 상한이 없다")
	var all_transit := 0
	for si5 in b.soldier_state.size():
		if b.soldier_state[si5] == Battle.SoldierState.TRANSIT:
			all_transit += 1
	t.eq(all_transit, Rules.START_MELEE + Rules.START_RANGED, "열 명 전부 배에 탔다")
	t.eq(b.elapsed, 0.0, "열 척을 놓는 동안에도 시계는 정확히 0이다")

	# ⚠ **One is pulled back out again, and the island is committed with nine.** That spare soldier is
	# what the post-commit rows below are driven against: with every soldier already at sea, 「a press
	# on a body does nothing」 and 「a release with a soldier in hand does nothing」 would both be
	# satisfied by there being no body and no soldier to send — a check passing for the wrong reason.
	# **Measured: deleting the gate on `_on_left_release` left this whole net green until this line
	# existed.**
	var spare := int(((b.boats[b.boats.size() - 1]) as Dictionary)["soldiers"][0])
	t.ok(b.recall(int(((b.boats[b.boats.size() - 1]) as Dictionary)["uid"])),
		"마지막 한 척을 무른다 (자가 점검)")
	await t.pump_frames(1)
	t.eq(b.boats.size(), Rules.START_MELEE + Rules.START_RANGED - 1, "아홉 척이 남았다")
	t.eq(b.soldier_state[spare], Battle.SoldierState.RESERVE, "그 병사는 항구에 남는다 (자가 점검)")
	t.ok(fs.idle_soldier_rect(spare).size != Vector2.ZERO, "그리고 다시 그려진다 (자가 점검)")

	# -- the speed chips do nothing before the commit -------------------------------------------------
	t.eq(game._speed_slot, Rules.SPEED_SLOT_DEFAULT, "섬은 기본 배속으로 열렸다 (자가 점검)")
	t.root.push_input(_press(Look.speed_rect_px(4).get_center()), true)
	await t.pump_frames(1)
	t.root.push_input(_release(Look.speed_rect_px(4).get_center()), true)
	t.eq(game._speed_slot, Rules.SPEED_SLOT_DEFAULT,
		"커밋 전에는 배속 칩이 아무것도 안 한다 — 빠르게 할 것이 아직 없다")
	t.eq(float(Rules.SPEED_STEPS[Rules.SPEED_SLOT_DEFAULT]), 1.0,
		"SPEED_SLOT_DEFAULT 가 1배속 칸을 가리킨다 — 0번(정지) 칸이면 시작하자마자 얼어붙는다")

	# -- the start button commits, and the screen changes with it --------------------------------------
	t.root.push_input(_press(Look.start_rect_px().get_center()), true)
	await t.pump_frames(1)
	t.root.push_input(_release(Look.start_rect_px().get_center()), true)
	await t.pump_frames(1)
	t.ok(b.committed(), "시작 버튼이 계획을 확정한다")
	t.eq(_start_button(hs), {}, "확정한 순간 시작 버튼이 화면에서 사라진다 — 못 누르는 단추는 안 그린다")
	var ghosts_after := 0
	for braw3: Dictionary in fs.bodies:
		if braw3["colour"] == Look.ghost_tint():
			ghosts_after += 1
	t.eq(ghosts_after, 0, "유령이 사라진다")
	t.eq(fs.hulls.size(), b.boats.size(), "대신 배마다 선체가 하나씩 그려진다")
	t.eq(fs.overlays.size(), 0, "상륙 가능 구역 색칠도 사라진다 — 더 놓을 수 없다")
	t.eq(fs.routes.size(), b.boats.size(), "아직 안 간 배의 항로는 남아 있다")
	t.eq(hs.buttons.size(), Rules.speed_slot_count(),
		"HUD 에 남은 단추는 배속 칩 다섯뿐이다 (실행 화면의 글자 항목은 일곱)")

	# ⚠⚠ **결정 1 as a check.** All three plan branches are gated, and the three of them are pressed.
	var boats_snapshot := b.boats.size()
	var idle_after := fs.idle_soldier_rect(spare)
	t.ok(idle_after.size != Vector2.ZERO,
		"확정 뒤에도 안 보낸 병사 하나는 항구에 그대로 서 있다 — 진짜 누를 몸이 있다 (자가 점검)")
	t.root.push_input(_press(idle_after.get_center()), true)
	await t.pump_frames(1)
	t.eq(game._drag_soldier, -1, "확정 뒤에는 몸을 눌러도 안 잡힌다")
	t.root.push_input(_motion(sendable_px, Vector2.ZERO), true)
	await t.pump_frames(1)
	t.root.push_input(_release(sendable_px), true)
	await t.pump_frames(1)
	t.eq(b.boats.size(), boats_snapshot, "확정 뒤에는 놓아도 배가 안 생긴다")
	t.eq(b.soldier_state[spare], Battle.SoldierState.RESERVE, "그 병사는 여전히 예비다 — 안 보내졌다")
	# ⚠ **The gate is on the BRANCH, not on the hit test.** `_ring_hit_at` still answers — it is a pure
	# geometry lookup — so the row that matters is that pressing there changes nothing.
	t.ok(game._ring_hit_at(second_px) >= 0, "고리 자체는 여전히 그 자리에 있다 (자가 점검)")
	t.root.push_input(_press(second_px), true)
	await t.pump_frames(1)
	t.root.push_input(_release(second_px), true)
	await t.pump_frames(1)
	t.eq(b.boats.size(), boats_snapshot, "확정 뒤에는 고리를 눌러도 안 무른다")
	# ⚠⚠ **The RELEASE branch's own gate, reached by hand** — and it is honestly labelled: **this row
	# cannot redden on that gate alone, and it was measured trying.** With the press branch gated,
	# `_drag_soldier` can never be set after the commit through the input path, so the handler is
	# called directly; and even then, deleting `not battle.committed()` from `_on_left_release` leaves
	# this net entirely green, because **`Battle.send` refuses a committed island on its own** (that
	# rule is `net_plan`'s 「커밋 뒤에는 계획을 못 바꾼다」). ⇒ the shell's third gate is defence in
	# depth with no observable consequence while the sim's rule holds. What this row DOES measure is
	# the consequence itself — nothing is created and the hand is emptied — which is the claim
	# 결정 1 actually makes, and it reddens the moment either layer stops refusing.
	game._drag_soldier = spare
	game._on_left_release(sendable_px)
	await t.pump_frames(1)
	t.eq(b.boats.size(), boats_snapshot, "확정 뒤에는 손에 든 병사를 놓아도 배가 안 생긴다")
	t.eq(game._drag_soldier, -1, "그리고 손은 비워진다")

	# -- the default speed is not the pause: no chip pressed, and the clock moves ----------------------
	var elapsed_before := b.elapsed
	for _n in 4:
		game._process(0.016)
	t.ok(b.elapsed > elapsed_before,
		"시작하면 아무것도 안 눌러도 시계가 간다 (%.4f초) — 기본 칸이 0배속이면 여기가 문다" % b.elapsed)

	# -- the speed chips answer AFTER the commit -------------------------------------------------------
	t.root.push_input(_press(Look.speed_rect_px(4).get_center()), true)
	await t.pump_frames(1)
	t.root.push_input(_release(Look.speed_rect_px(4).get_center()), true)
	t.eq(game._speed_slot, 4, "확정 뒤에는 배속 칩이 배속을 바꾼다")
	# ⚠ **The field's scale is nulled back out before `_process` runs.** Reading it straight after the
	# press would pass on a value left over from an earlier frame — and pre-setting a field is exactly
	# how the line that wires it gets deleted with the round green.
	fs._time_scale = -1.0
	game._process(0.016)
	t.eq(fs._time_scale, float(Rules.SPEED_STEPS[4]),
		"그리고 셸이 그 배속을 뷰에 넘긴다 — 뷰가 사다리를 직접 읽지 않는다")
	t.eq(hs._speed_scale, float(Rules.SPEED_STEPS[4]), "HUD 도 같은 한 숫자를 받는다")
	t.eq(hs._speed_slot, 4, "그리고 어느 칩이 켜졌는지도 같이 받는다")
	t.root.push_input(_press(Look.speed_rect_px(0).get_center()), true)
	await t.pump_frames(1)
	t.root.push_input(_release(Look.speed_rect_px(0).get_center()), true)
	t.eq(game._speed_slot, 0, "0배속 칩도 눌린다 — 멈춤은 같은 사다리의 한 칸이다")
	var paused_at := b.elapsed
	for _n2 in 6:
		game._process(0.016)
	t.eq(b.elapsed, paused_at, "0배속이면 프레임을 밀어도 시계가 정확히 그대로다")
	t.root.push_input(_press(Look.speed_rect_px(Rules.SPEED_SLOT_DEFAULT).get_center()), true)
	await t.pump_frames(1)
	t.root.push_input(_release(Look.speed_rect_px(Rules.SPEED_SLOT_DEFAULT).get_center()), true)
	t.eq(game._speed_slot, Rules.SPEED_SLOT_DEFAULT, "다시 1배속으로 돌려놨다 (자가 점검)")

	# ⚠⚠ **Without this row the three above are satisfied by a screen that does nothing at all.**
	# `_on_wheel` and the `_panning` fall-through are NOT gated on the commit — three plan branches
	# are, not four — and this is what says so.
	# ⚠ The wheel is driven DOWNWARD: `Look.ZOOM_MAX` is 1.0 and the camera is parked there, so zooming
	# in has nowhere to go and 「it did nothing」 would be the clamp, not the gate.
	var zoom_before := fs.zoom
	for _n3 in 2:
		game._unhandled_input(_wheel(Vector2(640.0, 360.0), false))
	t.ok(fs.zoom < zoom_before, "전투 중에도 휠은 화면을 움직인다 (%.3f -> %.3f)" % [zoom_before, fs.zoom])
	# ⚠ And the camera is parked mid-map first. At `ZOOM_MIN` the map is narrower than the visible
	# world on BOTH axes and `_clamp_cam` centres both, so a pan there cannot move anything — that is
	# the framing the user asked for, not a defect, and a row that ignored it would measure the clamp.
	fs.zoom = 1.0
	fs.cam_px = Vector2(300.0, 300.0)
	await t.pump_frames(1)
	var cam_before: Vector2 = fs.cam_px
	game._unhandled_input(_press(Vector2(640.0, 360.0)))
	game._unhandled_input(_motion(Vector2(640.0, 360.0), Vector2(200.0, 120.0)))
	game._unhandled_input(_release(Vector2(840.0, 480.0)))
	t.ok(fs.cam_px != cam_before, "전투 중에도 화면은 끌린다 — 손이 멈춘 것이지 화면이 죽은 게 아니다")

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
	# The one line in `_unhandled_input`. Without it a press would keep reaching the plan on an island
	# that is already won, and the camera would keep panning under a frame that has latched its outcome.
	#
	# ⚠⚠ **This used to be driven with `KEY_2` and asserted `pending` was unchanged.** Both of those are
	# deleted, and a check written that way would now pass while measuring nothing at all: there is no
	# key branch to refuse, so an unrefused press would sail through it. ⇒ **The press is the START
	# button — a real gesture that still exists — and the assertion is `committed()`, a state the SIM
	# owns.** The island is already WON here so a stray commit would be visible nowhere else.
	var boats_at_hold := isle0.boats.size()
	var committed_at_hold := isle0.committed()
	game._unhandled_input(_press(Look.start_rect_px().get_center()))
	game._unhandled_input(_release(Look.start_rect_px().get_center()))
	t.eq(isle0.committed(), committed_at_hold, "hold 중에는 시작 버튼이 안 먹는다 — 확정 상태가 그대로다")
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
	# ⚠⚠ 「지도로 돌아가면 `battle` 이 null 이 된다」 — floor: the shell's own field; ceiling: **and the
	# view's**. `field_view` holds its OWN reference and would keep drawing the last island's terrain
	# if only the shell's were cleared. Mutation: delete the `battle = null` line in
	# `_enter_map_screen`, and the last island keeps drawing, panning, and its clock and start button
	# come with it.
	t.ok(game.battle == null, "그제서야 지도로 돌아갔다 (바닥 — 영영 안 돌아오면 여기가 문다)")
	t.ok(fs.battle == null, "field_view 도 섬을 놓았다 — 안 그러면 지난 섬 지형이 지도 밑에 계속 그려진다")
	t.ok(hs.battle == null, "hud_view 도 놓았다 — 시계와 시작 단추가 지도 위에 남지 않는다")
	t.eq(game.run.state(), Run.State.MAP, "런은 지도 상태다")
	t.eq(game.run.island_index, 0, "그리고 섬 번호는 혼자 안 움직였다 — 어느 칸으로 갈지는 손이 정한다")
	t.eq(game.run.map.at(), 0, "서 있는 칸은 아직 0번이다")
	t.eq(game.run.army.type_id.size(), 13, "0번 칸의 수 보상이 그 자리에서 붙었다 (10 + 3)")
	t.ok(not game.panel_view.panel_active(), "지도에서는 패널이 안 뜬다")
	await t.pump_frames(2)
	t.eq(fs.tiles.size(), 0, "지도 밑에 지형이 한 칸도 안 그려진다 — 지난 섬이 안 남는다")
	t.eq(hs.timers.size(), 0, "시계도 안 그려진다")
	t.eq(ps.panels.size(), 0, "패널도 없다")

	# 「지도에서 칸을 누르면 섬이 열린다」, on the floor-2 node that pays the BEAK — which is what puts
	# the reward panel on screen below. Its sibling pays cells; that fork is `net_map`'s.
	t.eq(Rules.map_reward_of(2), Rules.Reward.BEAK, "2번 칸은 부리 칸이다 (자가 점검)")
	var cam_before_node: Vector2 = fs.cam_px
	game._unhandled_input(_press(Look.map_node_pos_px(2)))
	t.eq(game._pending_node, 2, "2번 칸을 누르면 셸이 그 칸을 들고만 있다")
	# The same wiring one node further in, and this time the walk has two real ends: the run is standing
	# on 0, so `_travel_from` is a node rather than the -1 a first landing hands over — which is what
	# makes the ring's position mid-hold measurable at all.
	t.eq(game.map_view._travel_to, 2, "고리가 2번 칸을 향해 출발했다")
	t.eq(game.map_view._travel_from, 0, "출발점은 서 있던 0번 칸이다")
	game.map_view._fx_step(Look.MAP_TRAVEL_SEC * 0.5)
	var ring_mid := game.map_view._here_centre()
	t.ok(ring_mid != Look.map_node_pos_px(0) and ring_mid != Look.map_node_pos_px(2),
		"붙들고 있는 절반 시점에 고리가 두 칸 사이 어딘가에 있다 — 셸이 뷰에 안 알리면 0.45초 동안 화면이 그냥 얼어 있다")
	t.ok(not game._panning, "그리고 카메라를 안 끈다")
	t.eq(fs.cam_px, cam_before_node, "카메라가 실제로 한 픽셀도 안 움직였다")
	game._process(Look.MAP_TRAVEL_SEC)
	t.ok(game.battle != null, "고리가 도착하자 섬이 열렸다 (바닥 — 영원히 안 열리면 여기가 문다)")
	t.ok(game.battle != isle0, "그리고 방금 이긴 그 섬이 아니다")
	t.eq(game.run.map.at(), 2, "서 있는 칸이 2번이 됐다")
	t.eq(game.run.island_index, Rules.map_island_of(2), "그 칸이 가리키는 섬이다")
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

	# H: the release-time panel guard. `_on_left_release` refuses to call `battle.send` while the panel
	# is up. Reaching that guard through the NORMAL flow is narrow: `_open_island` (the only caller of
	# `panel_view.bind`, which is what actually flips `panel_active()`) clears `_drag_soldier` as the
	# very first thing it does, unconditionally — a defence this file's own earlier round already
	# added — so a drag genuinely cannot survive INTO the moment the panel opens through that path.
	# This checks the guard line itself rather than that narrow path: `_drag_soldier` is set BY HAND
	# after the panel is already up, the same "call the handler, not the input path" technique
	# `_click_panel`'s own hold guard already uses, for the same reason its own comment gives.
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
	t.eq(game.run.state(), Run.State.REWARD, "부리 칸을 이기자 고르기가 열렸다")
	game._open_island()
	await t.pump_frames(2)
	t.eq(ps.panels.size(), 1, "보상 화면에서 패널이 그려졌다")

	# The panel is now up. `_drag_soldier` is set BY HAND here, after the fact — see the note above
	# this block for why the normal path cannot produce this state on its own.
	t.ok(game.panel_view.panel_active(), "패널이 실제로 떠 있다 (자가 점검)")
	game._drag_soldier = 0
	game._on_left_release(Vector2(700.0, 300.0))
	await t.pump_frames(1)
	t.eq(b.boats.size(), boats_before_isle1, "패널이 뜬 뒤 놓아도 배가 안 생긴다 — 조용히 취소된다")
	t.eq(game._drag_soldier, -1, "드래그 상태는 정리됐다")

	var cam_before_motion: Vector2 = fs.cam_px
	game._unhandled_input(_motion(Vector2(700.0, 300.0), Vector2(-80.0, -80.0)))
	t.eq(fs.cam_px, cam_before_motion,
		"패널이 뜨기 전에 시작된 드래그라도, 뜬 뒤에 온 motion 은 카메라를 안 끈다 — 손을 뗀 적이 없는데도")

	t.eq(ps.panels[0]["rect"], Look.panel_rect_px(), "패널 사각형이 look.gd 가 계산한 자리다")
	t.eq(ps.messages.size(), 1, "안내 문구를 한 번 그렸다")
	t.eq(str(ps.messages[0]["text"]), PanelView.MSG_REWARD, "부리를 고르라고 쓰여 있다")
	# ⚠ **`Look.COL_BUTTON` lost its only literal comparison when the key boxes died.** It is still
	# handed to `_paint_message` and `_paint_button` by `panel_view`, and nothing was comparing those
	# arguments — so the constant could be changed to anything at all with the round green. Re-pinned
	# here, on captures this file already collects.
	# ⚠⚠ **The literal first, then the reach.** `ps.messages[0]["bg"] == Look.COL_BUTTON` alone reads the
	# constant on BOTH sides, so changing the constant moves the expectation with it — measured: it
	# stayed green with `COL_BUTTON` set to red. The literal is what pins the value; the comparison
	# below is what pins that the value actually reaches the panel.
	t.eq(Look.COL_BUTTON, Color(0.239, 0.341, 0.459), "COL_BUTTON 이 리터럴 그 색이다")
	t.eq(ps.messages[0]["bg"], Look.COL_BUTTON, "안내 문구 상자 색이 COL_BUTTON 이다")
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
	# 「부리를 달고 나면 섬이 아니라 지도로 간다」 — mutation: leave `_open_island()` in `_release_hold`.
	# `apply_beak` ends in `_advance`, which now lands in `MAP`, so asking `begin_island` for a fight
	# the run is not in returns null and leaves the previous island drawing under the map.
	t.eq(game.run.state(), Run.State.MAP, "고르고 나자 섬이 아니라 지도로 갔다")
	t.ok(game.battle == null, "그래서 섬이 닫혔다")
	t.eq(game.run.map.at(), 2, "서 있는 칸은 부리 칸 그대로다")
	await t.pump_frames(2)
	t.eq(ps.panels.size(), 0, "패널이 사라졌다")
	t.eq(fs.tiles.size(), 0, "그리고 지형이 한 칸도 안 그려진다 — 지도 밑에 지난 섬이 안 남는다")

	# -- on to the chest and the boss, one node press at a time ------------------------------------
	_press_node(t, game, 4, "3층 오른쪽")
	t.ok(game.battle != null, "3층 칸이 섬을 열었다")
	t.eq(game.run.island_index, Rules.map_island_of(4), "그 칸이 가리키는 섬이다")
	_win_the_open_island(t, game, "3층")
	t.eq(game.run.state(), Run.State.MAP, "이기고 다시 지도로 돌아왔다")
	t.ok(game.battle == null, "그리고 섬이 닫혔다")

	# ⚠ **The chest is the only node in this round that changes state with no fight**, so what it must
	# NOT do is open an island — and what it must do is land its heal before the map comes back.
	t.eq(Rules.map_island_of(5), -1, "5번은 상자 칸이라 격자가 없다 (자가 점검)")
	var hurt := game.run.army.hp
	for i in hurt.size():
		hurt[i] = 1.0
	game.run.army.hp = hurt
	_press_node(t, game, 5, "상자")
	t.ok(game.battle == null, "상자 칸은 섬을 안 연다")
	t.eq(game.run.state(), Run.State.MAP, "그리고 지도에 그대로 머문다")
	t.eq(game.run.army.hp[0], Rules.hp_of(int(game.run.army.type_id[0])),
		"밟은 그 자리에서 회복이 붙었다 — 셸이 따로 부르는 곳은 없다")
	await t.pump_frames(2)
	t.eq(fs.tiles.size(), 0, "상자를 밟아도 지형은 여전히 안 그려진다")

	_press_node(t, game, 6, "보스")
	t.ok(game.battle != null, "보스 칸이 섬을 열었다")
	t.eq(game.run.island_index, Rules.map_island_of(6), "그 칸이 가리키는 섬이다")
	t.ok(game.run.map.is_finished(), "그리고 지도는 이제 마지막 칸 위에 서 있다")

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
	t.eq(ps.buttons[0]["bg"], Look.COL_BUTTON, "다시 하기 단추 색도 COL_BUTTON 이다 — 상수의 두 번째 못")
	# ⚠ **And it is NOT `Look.start_rect_px()`.** One rect answering to two verbs is how a restart gets
	# pressed by someone aiming at start; `panel_view.button_hit` owns this one.
	t.ok(not Look.button_rect_px().intersects(Look.start_rect_px()),
		"다시 하기 단추와 시작 버튼은 서로 다른 자리다 — 한 사각형이 두 동사를 받지 않는다")
	var button_rects: Array[Rect2] = []
	for it: Dictionary in ps.buttons:
		button_rects.append(it["rect"])
	_rects_land_on_screen(t, "패배 패널", button_rects)

	# 「보스를 이기고(혹은 지고) 다시 하기를 누르면 타이틀이다」 — floor: `run == null`; ceiling:
	# `battle == null` too. Mutation: call `run.restart()` instead, and the button drops the player
	# straight back onto island 1 with no frame around it, which is the whole thing this round undoes.
	game._unhandled_input(_click(Look.button_rect_px().get_center()))
	t.ok(game.run == null, "단추를 누르자 타이틀로 돌아갔다 — 새 섬이 아니다")
	t.ok(game.battle == null, "그리고 섬도 닫혔다")
	t.ok(game.title_view.visible, "타이틀이 다시 켜졌다")
	t.ok(game.map_view.run == null, "지도도 풀렸다 — 끝난 지도가 메뉴 밑에 안 남는다")
	# 「타이틀에서는 섬이 안 그려진다」 — mutation: drop `battle = null` from the restart branch.
	t.ok(fs.battle == null and hs.battle == null, "타이틀에서는 두 뷰 다 볼 전투가 없다")
	t.ok(not game.panel_view.panel_active(), "그리고 패널도 안 뜬다")
	await t.pump_frames(2)
	t.eq(ps.panels.size(), 0, "다시 하기 뒤에는 패널이 없다")
	t.eq(fs.tiles.size(), 0, "지형도 한 칸도 안 그려진다 — 보스 섬이 타이틀 밑에 안 남는다")
	t.eq(hs.timers.size(), 0, "시계도 안 그려진다")

	# And the title works from there: a whole second run, from the same three slots.
	game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
	t.ok(game.run != null, "타이틀에서 다시 시작할 수 있다")
	t.eq(game.run.state(), Run.State.MAP, "새 런도 지도에서 시작한다")
	t.eq(game.run.map.path.size(), 0, "새 런은 밟은 자취가 비어 있다")
	t.ok(game.battle == null, "그리고 섬은 아직 없다")
	t.ok(game.run.army != old_army, "명부가 통째로 새것이다 — 부리도 상처도 안 따라온다")
	t.eq(game.run.army.living_count(), Rules.START_MELEE + Rules.START_RANGED, "다시 10명이다")
	t.eq(int(game.run.army.has_beak[3]), 0, "지난 런의 부리도 안 따라왔다")

	t.root.remove_child(game)
	game.queue_free()

	_panel_active_answers_all_five_screens(t)
	await _two_presses_reach_the_first_island(t)
	_the_plan_constants_have_both_ends(t)
	_the_readers_themselves(t)


## Presses a map node the way a hand does — through `_unhandled_input`, then the ring's walk run out
## by hand. `game.set_process(false)` is in force by the time this is called, so the hold would never
## expire on its own; a headless frame is 6.9 ms and `MAP_TRAVEL_SEC` would be 66 frames of guessing
## even if it did.
func _press_node(t, game: Game, n: int, label: String) -> void:
	t.ok(game.run.map.is_reachable(n), "%s 칸이 지금 갈 수 있는 칸이다 (자가 점검)" % label)
	game._unhandled_input(_press(Look.map_node_pos_px(n)))
	t.eq(game._pending_node, n, "%s 칸을 누르면 셸이 그 칸을 들고만 있다" % label)
	game._process(Look.MAP_TRAVEL_SEC)
	t.eq(game.run.map.at(), n, "고리가 도착하자 %s 칸에 섰다" % label)


## Wins whatever island is open, through the shell's own frames rather than by poking `Run`.
##
## ⚠ **The island has to be COMMITTED first.** An uncommitted `Battle` is inert to every driver
## (`plan-then-watch`, 4.3) — `step` returns before `_phase_clock`, so an emptied `enemy_alive` would
## never be latched at all and the hold below would wait forever on a verdict that never comes.
func _win_the_open_island(t, game: Game, label: String) -> void:
	var tile := -1
	for pt in game.battle.grid.passable.size():
		if game.battle.grid.home_harbour_for(pt) >= 0:
			tile = pt
			break
	t.ok(tile >= 0 and game.battle.send(0, tile) >= 0 and game.battle.commit(),
		"%s 섬에 한 명 보내고 시작을 눌렀다 (자가 점검)" % label)
	game.battle.enemy_alive.fill(0)
	# ⚠ **Two whole sub-steps, never 0.016.** `step` consumes whole `Rules.SIM_SUBSTEP_SEC` chunks and
	# carries the leftover, and 0.016 is a hair UNDER 1/60 — on a fresh island with no leftover banked
	# it runs zero sub-steps, latches nothing, and the hold below waits forever on a verdict that never
	# comes. Measured: this row read RUNNING with the enemies already emptied.
	game._process(Rules.SIM_SUBSTEP_SEC * 2.0)
	t.eq(game.battle.outcome(), Battle.Outcome.WON, "%s 섬을 이겼다" % label)
	t.eq(game._hold_sec, Look.HOLD_OUTCOME_SEC, "그리고 셸이 마지막 파열 링만큼 붙들었다")
	game._process(Look.HOLD_OUTCOME_SEC)


## ⚠⚠ **`panel_active()` is an ALLOWLIST and adding `MAP` to it "for symmetry" is the mutation this
## measures.** Its header records that the denylist form (`state() != BATTLE`) broke five ways on one
## added state; what the map round owes it is not an edit but this table — **both directions**, or an
## allowlist that always returned false would pass the first three rows on its own.
func _panel_active_answers_all_five_screens(t) -> void:
	var game := QuitGame.new()
	t.root.add_child(game)
	var pv := game.panel_view
	t.ok(pv != null, "패널 뷰가 생겼다 (자가 점검)")

	# Title: `run` is null and the first clause answers.
	pv.bind(null, null)
	t.ok(not pv.panel_active(), "타이틀에서는 패널이 안 뜬다 (run == null)")

	var r := Run.new()
	pv.bind(r, null)
	t.eq(r.state(), Run.State.MAP, "새 런은 지도 상태다 (자가 점검)")
	t.ok(not pv.panel_active(), "지도에서도 패널이 안 뜬다 — MAP 은 어느 가지에도 없다")

	r.enter_node(0)
	t.eq(r.state(), Run.State.BATTLE, "칸을 밟으면 전투다 (자가 점검)")
	t.ok(not pv.panel_active(), "섬 위에서도 패널이 안 뜬다")

	# ⚠ **The other direction, and it is what stops "always false" from passing.**
	r.finish_island(true)
	r.enter_node(2)
	r.finish_island(true)
	t.eq(r.state(), Run.State.REWARD, "부리 칸을 이기면 REWARD 다 (자가 점검)")
	t.ok(pv.panel_active(), "부리 고르기에서는 패널이 뜬다")

	r.apply_beak(0)
	r.enter_node(3)
	r.finish_island(false)
	t.eq(r.state(), Run.State.LOST, "지면 LOST 다 (자가 점검)")
	t.ok(pv.panel_active(), "진 화면에서도 패널이 뜬다")

	var won := Run.new()
	for n in [0, 1, 4, 5, 6]:
		won.enter_node(int(n))
		if won.state() == Run.State.BATTLE:
			won.finish_island(true)
	t.eq(won.state(), Run.State.WON, "보스를 이기면 WON 이다 (자가 점검)")
	pv.bind(won, null)
	t.ok(pv.panel_active(), "이긴 화면에서도 패널이 뜬다")

	t.root.remove_child(game)
	game.queue_free()


## **The acceptance row 「타이틀은 마찰이 아니다」, as a count.** From launch to the first island the
## design says two presses — 시작하기, then one node — and **more than three is a failure.** Counted by
## driving a fresh shell and incrementing on every event actually handed to `_unhandled_input`, so a
## screen that grew a confirmation step reddens here rather than in somebody's memory of it.
func _two_presses_reach_the_first_island(t) -> void:
	var game := QuitGame.new()
	t.root.add_child(game)
	await t.pump_frames(2)
	game.set_process(false)
	await t.pump_frames(1)
	game.set_process(false)

	var presses := 0
	game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
	presses += 1
	game._unhandled_input(_press(Look.map_node_pos_px(0)))
	presses += 1
	game._process(Look.MAP_TRAVEL_SEC)

	t.ok(game.battle != null, "누름 %d번 만에 첫 섬이 열렸다" % presses)
	t.eq(presses, 2, "그 수가 정확히 둘이다 — 시작하기, 그리고 칸 하나")
	t.ok(presses <= 3, "셋을 넘으면 타이틀이 마찰이다")
	t.ok(presses >= 1, "그리고 0이면 켜자마자 섬이 나온다는 뜻이다 — 이 라운드가 없앤 바로 그것이다")

	t.root.remove_child(game)
	game.queue_free()


## ⚠⚠ **Every constant `plan-then-watch` 6.4 introduced, with the floor AND the ceiling its own row
## wrote down, read back as numbers.** They were derived in a plan and then written into `look.gd` as
## comments, and a comment cannot redden: `GHOST_ALPHA := 0.02` — invisible on screen, which deletes
## the only picture carrying drop order — passed 1262 checks. **A correction pass only checks the row
## someone is arguing about**, so the whole table is here and not the one value that was caught.
##
## ⚠ These are the ROW's bounds, not a restatement of the value. A row asserting `== 0.55` would be
## one fact written twice and would redden on every honest re-tune; a row asserting only the floor
## passes an amplitude that runs away. `ZOOM_MIN`, `WATER_MARGIN_TILES` and `CLIFF_FACE_WIDTH_PX` are
## `net_camera`'s, and `net_camera` already bounds the first two at both ends — the cliff line is
## bounded here because no file bounded it at all.
func _the_plan_constants_have_both_ends(t) -> void:
	t.ok(Look.HUD_START_ORIGIN_PX.y >= 560.0,
		"시작 버튼이 화면 아래쪽에 있다 (바닥 y>=560 — 위로 오면 섬 한가운데에 뜬다)")
	t.ok(Look.HUD_START_ORIGIN_PX.y + Look.HUD_START_SIZE_PX.y <= 720.0,
		"그리고 화면 아래로 안 넘친다 (천장 720)")
	t.ok(Look.HUD_START_SIZE_PX.x > 150.0 and Look.HUD_START_SIZE_PX.y > 26.0,
		"시작 버튼이 옛 키 상자(150x26)보다 두 축 다 크다 (바닥 — 판을 끝내는 단 한 번의 누름이다)")
	t.ok(Look.HUD_START_SIZE_PX.x <= 320.0 and Look.HUD_START_SIZE_PX.y <= 96.0,
		"그리고 (320, 96) 을 안 넘는다 (천장 — 넘으면 배속 줄에 닿는다)")
	t.ok(Look.HUD_START_TEXT_OFFSET_PX.x > 0.0
			and Look.HUD_START_TEXT_OFFSET_PX.y > float(Look.HUD_START_FONT_SIZE_PX),
		"시작 글자가 상자 원점에 안 붙어 있다 (바닥 — 원점에 놓인 글자는 놓인 적이 없는 글자다)")
	t.ok(Look.HUD_START_TEXT_OFFSET_PX.x <= Look.HUD_START_SIZE_PX.x
			and Look.HUD_START_TEXT_OFFSET_PX.y <= Look.HUD_START_SIZE_PX.y,
		"그리고 상자 안에 있다 (천장)")
	t.ok(Look.HUD_START_FONT_SIZE_PX > Look.HUD_FONT_SIZE_PX,
		"시작 글자가 보통 HUD 글자보다 크다 (바닥)")
	t.ok(Look.HUD_START_FONT_SIZE_PX <= Look.HUD_TIMER_FONT_SIZE_PX + 8,
		"그리고 시계 글자 + 8 을 안 넘는다 (천장)")
	t.ok(Look.HUD_SPEED_ORIGIN_PX.x >= 1000.0,
		"배속 줄이 오른쪽 끝에 있다 (바닥 x>=1000 — 시작 버튼과 섬을 사이에 두고 떨어진다)")
	t.ok(Look.HUD_SPEED_ORIGIN_PX.x + Rules.speed_slot_count() * Look.HUD_SPEED_SIZE_PX.x
			+ (Rules.speed_slot_count() - 1) * Look.HUD_SPEED_GAP_PX <= 1280.0,
		"그리고 칩 다섯이 화면 오른쪽으로 안 넘친다 (천장 1280)")
	t.ok(Look.HUD_SPEED_SIZE_PX.x >= 30.0 and Look.HUD_SPEED_SIZE_PX.y >= 30.0,
		"배속 칩이 누를 만큼 크다 (바닥 30x30)")
	t.ok(Look.HUD_SPEED_SIZE_PX.x <= 48.0 and Look.HUD_SPEED_SIZE_PX.y <= 48.0,
		"그리고 (48, 48) 을 안 넘는다 (천장)")
	t.ok(Look.HUD_SPEED_GAP_PX >= 3.0, "칩 사이가 벌어져 있다 (바닥 3 — 붙으면 한 막대로 읽힌다)")
	t.ok(Look.HUD_SPEED_GAP_PX <= 10.0, "그리고 10 을 안 넘는다 (천장)")
	# A melee body is `BODY_RADIUS_RATIO_MELEE * TILE_PX * 2` across; the pitch has to clear it or two
	# soldiers standing side by side are one blob and the thing you drag has no edges.
	var melee_across := Look.body_radius_of(Rules.CELL_MELEE) * 2.0
	t.ok(Look.IDLE_SOLDIER_PITCH_PX >= melee_across,
		"항구 무더기의 간격이 근접 몸 폭(%.1fpx)보다 넓다 (바닥 — 좁으면 이웃과 겹친다)" % melee_across)
	t.ok(Look.IDLE_SOLDIER_PITCH_PX <= 48.0,
		"그리고 48 을 안 넘는다 (천장 — 일곱이 늘어서면 항구 앞을 다 덮는다)")
	t.ok(Look.IDLE_SOLDIER_COLS >= 5,
		"한 줄에 다섯 이상 선다 (바닥 — 열셋이 다섯 미만이면 세 줄이 되고 무더기가 항구를 벗어난다)")
	t.ok(Look.IDLE_SOLDIER_COLS <= 9, "그리고 아홉을 안 넘는다 (천장 — 8타일보다 넓어진다)")
	# The stack sits ABOVE the harbour tile, because every harbour on all three islands is on the
	# bottom row and below it is off the map. The ceiling (three tiles on each axis) is the
	# `too_far` row up in the field section; this is the floor it was missing.
	t.ok(Look.IDLE_SOLDIER_ORIGIN_PX.y <= -40.0,
		"무더기가 항구 위쪽에 선다 (바닥 y<=-40 — 항구는 맨 아랫줄이고 그 아래는 지도 밖이다)")
	t.ok(Look.GHOST_FAN_PX.x >= 6.0 and Look.GHOST_FAN_PX.y >= 6.0,
		"유령 부채가 벌어진다 (바닥 6 — 못 미치면 두 유령이 한 덩어리이고 놓은 순서에 그림이 없다)")
	t.ok(Look.GHOST_FAN_PX.x <= 14.0 and Look.GHOST_FAN_PX.y <= 14.0,
		"그리고 14 를 안 넘는다 (천장 — 넘으면 열셋이 4타일에 퍼져 한 상륙으로 안 읽힌다)")
	t.ok(Look.GHOST_FAN_PX.length() * float(Rules.START_MELEE + Rules.START_RANGED
			+ Rules.REWARD_MELEE + Rules.REWARD_RANGED - 1) > Look.TARGET_RING_R_PX,
		"자가 점검 — 열셋을 한 칸에 놓으면 부채가 고리 밖까지 나간다 (그래서 순위는 해변마다 센다)")
	t.ok(Look.CHIP_FX_SEC >= 0.1,
		"누름 반응이 한 프레임보다 길다 (바닥 0.1s — 짧으면 팝이 되고 반응 자체가 안 보인다)")
	t.ok(Look.CHIP_FX_SEC <= 0.4, "그리고 0.4s 를 안 넘는다 (천장 — 넘으면 다음 누름까지 남는다)")
	t.ok(Look.REFUSE_SHAKE_PX >= 2.0, "거절 흔들림이 한 픽셀보다 크다 (바닥 2px)")
	t.ok(Look.REFUSE_SHAKE_PX <= 12.0, "그리고 12px 를 안 넘는다 (천장 — 넘으면 단추가 자리를 뜬다)")
	t.ok(Look.CLIFF_FACE_WIDTH_PX >= 5.0,
		"절벽 선이 ZOOM_MIN 에서 2.25px 로 남는다 (바닥 5 — 못 미치면 2px 스냅 바닥 밑으로 준다)")
	t.ok(Look.CLIFF_FACE_WIDTH_PX <= 8.0, "그리고 8 을 안 넘는다 (천장)")


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


## How many bytes of a `PackedByteArray` are non-zero. Used for "the droppable union is wider than one
## harbour's own reach", which is what makes the union a claim rather than a rename.
func _count_set(arr: PackedByteArray) -> int:
	var n := 0
	for v in arr:
		if v != 0:
			n += 1
	return n


# -- the readers themselves, inverted -----------------------------------------------------------------

## ⚠⚠ **Cases that fail the READERS above rather than the tree.** `_start_button` is what says 「the
## start button disappeared at the commit」 and `_speed_chips` is what says 「exactly one chip is lit」 —
## written loosely (return the first button, return every button) they answer both of those questions
## about a screen that never drew any of it. This repo has twice shipped a check carrying the defect it
## was written to catch, and neither was found by mutating the code.
func _the_readers_themselves(t) -> void:
	var fake := HudSpy.new()
	t.eq(_start_button(fake), {}, "빈 화면에서 시작 버튼을 찾으면 빈 사전이다 — 첫 단추를 아무거나 주지 않는다")
	t.eq(_speed_chips(fake).size(), 0, "빈 화면에서 배속 칩도 하나도 안 찾는다")

	# Only the chips, no start button: the reader must still not hand one back.
	for slot in Rules.speed_slot_count():
		fake.buttons.append({"seq": slot, "rect": Look.speed_rect_px(slot), "bg": Look.COL_BUTTON,
			"text": "x", "at": Vector2.ZERO, "fsize": 1, "col": Look.COL_HUD_TEXT})
	t.eq(_start_button(fake), {},
		"칩만 다섯 있는 화면에서도 시작 버튼은 못 찾는다 — 크기로 가려낸다")
	t.eq(_speed_chips(fake).size(), Rules.speed_slot_count(), "그 다섯은 다 찾는다")
	var order_ok := true
	var chips_found := _speed_chips(fake)
	for slot2 in chips_found.size():
		if (chips_found[slot2]["rect"] as Rect2).position != Look.speed_rect_px(slot2).position:
			order_ok = false
	t.ok(order_ok, "그리고 사다리 순서대로 돌려준다 — 어느 칸이 켜졌는지가 그 순서에 달려 있다")

	# A start button shifted by a refusal shake must still be found: the reader matches on SIZE, and a
	# reader that matched on the whole rect would stop finding it on the one frame that matters.
	var shaken := Look.start_rect_px()
	shaken.position += Vector2(Look.REFUSE_SHAKE_PX, 0.0)
	fake.buttons.append({"seq": 9, "rect": shaken, "bg": Look.COL_START, "text": "시작",
		"at": Vector2.ZERO, "fsize": 1, "col": Look.COL_HUD_TEXT})
	t.ok(not _start_button(fake).is_empty(), "흔들린 시작 버튼도 찾는다 — 거절 프레임이 바로 그 프레임이다")

	t.eq(_count_set(PackedByteArray([0, 0, 0])), 0, "_count_set — 전부 0이면 0이다")
	t.eq(_count_set(PackedByteArray([1, 0, 2])), 2, "_count_set — 0 아닌 것만 센다")

	# A `HudView` is a `Node2D`, not a `RefCounted` — built outside the tree it still has to be freed by
	# hand, or the round ends with a leaked `CanvasItem` RID and the wrapper reddens on stderr. Measured
	# the first time this block ran.
	fake.free()
