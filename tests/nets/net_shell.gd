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

	# ⚠ `squash` is the seventh parameter and `tex` the eighth, and both were appended, not inserted.
	# An override that kept an older, shorter form does not bind at all.
	func _paint_body(centre: Vector2, radius: float, corner: float, colour: Color,
			outline_width: float, dot_radius: float, squash: Vector2, tex: Texture2D) -> void:
		bodies.append({"seq": _bump(), "centre": centre, "radius": radius, "corner": corner,
			"colour": colour, "width": outline_width, "dot": dot_radius, "squash": squash,
			"is_picture": tex != null})

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

	## ⚠ `_paint_overlay` is gone with the green coast wash (question C). `_paint_route` takes a
	## POLYLINE, and the WHOLE point list is kept: `net_draw_leaf` counts call SITES and cannot tell
	## `draw_polyline(points)` from `draw_line(points[0], points[-1])` — both are one call with every
	## argument used — so the point list captured HERE is the only thing that catches a corner cut.
	func _paint_route(points: PackedVector2Array, colour: Color, width: float) -> void:
		routes.append({"seq": _bump(), "points": points, "colour": colour, "width": width})


## ⚠ **`_paint_berth` / `_paint_load` / `_paint_key` are GONE**, deleted with the berths and the 1/2
## keys (`plan-then-watch`, 결정 14R). ⚠⚠ **And the five speed chips are gone too**
## (`speed-off-open-landing`, item 1), so `_paint_button` has exactly ONE call site left: the start
## button. The array stays an array because the hook is still a hook.
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


## ⚠ **`_speed_chips` is DELETED with the widget it read.** It matched five rects out of `buttons`;
## `Look.speed_rect_px` no longer exists, so the reader could not even be written now. What replaced
## it is `_the_speed_ladder_is_gone`, which asserts the chips are ABSENT rather than merely unread —
## a green round after deleting a widget proves nothing about the widget.


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


## ⚠⚠ Item 4's own spy — `net_cards`' `RewardSpy` shape copied rather than re-invented. Swapped in for
## `game.reward_view` right before a second win reaches `PICK`, so what this file can measure is not
## only `run.state()` (which the SIM writes on its own and no shell function can move) but whether the
## SCREEN was actually rebound fresh: `bind()` zeroes `_reveal_age` and clears `_taken_age`, and neither
## moves unless `reward_view.bind(run)` itself runs.
class RewardSpy extends RewardView:
	var draws := 0
	var cards := []
	var parts := []
	var species := []
	var marks := []
	var hints := []
	var fades := []

	func _draw() -> void:
		cards.clear()
		parts.clear()
		species.clear()
		marks.clear()
		hints.clear()
		fades.clear()
		super()
		draws += 1

	func _paint_card(rect: Rect2, bg: Color, edge_width: float) -> void:
		cards.append({"rect": rect, "bg": bg, "width": edge_width})

	func _paint_card_part(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		parts.append({"face": face, "at": at, "text": text, "fsize": fsize, "col": col})

	func _paint_card_species(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		species.append({"face": face, "at": at, "text": text, "fsize": fsize, "col": col})

	func _paint_taken_mark(centre: Vector2, radius: float, col: Color) -> void:
		marks.append({"centre": centre, "radius": radius, "col": col})

	func _paint_hint(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		hints.append({"face": face, "at": at, "text": text, "fsize": fsize, "col": col})

	func _paint_fade(rect: Rect2, col: Color) -> void:
		fades.append({"rect": rect, "col": col})


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
	t.eq(game.get_child_count(), 7, "_ready 가 자식 일곱을 만들었다")
	t.ok(game.field_view != null and game.hud_view != null and game.map_view != null
		and game.reward_view != null and game.refit_view != null and game.title_view != null
		and game.panel_view != null, "일곱 뷰가 전부 생겼다")
	t.ok(game.get_child(0) == game.field_view and game.get_child(1) == game.hud_view
		and game.get_child(2) == game.map_view and game.get_child(3) == game.reward_view
		and game.get_child(4) == game.refit_view and game.get_child(5) == game.title_view
		and game.get_child(6) == game.panel_view,
		"자식 순서가 field -> hud -> map -> reward -> refit -> title -> panel 이다 (Node2D 형제의 그리기 순서가 곧 이 순서다)")
	# Named by hand, because `get_class()` on all seven is "Node2D" and seven identical labels do not
	# say which one went missing — a failure log that cannot narrow the cause is half a failure log.
	var built := {"field_view": game.field_view, "hud_view": game.hud_view,
		"map_view": game.map_view, "reward_view": game.reward_view, "refit_view": game.refit_view,
		"title_view": game.title_view, "panel_view": game.panel_view}
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
	t.eq(game.run.army.living_count(), Rules.roster_start_count(),
		"시작 병력이 10명이다")

	# The wiring itself, by identity and not by shape: the field must hold the SAME `Battle` and the
	# SAME `Army` the shell is stepping, or HP carries on one side of the screen and not the other.
	t.ok(game.field_view.battle == game.battle, "field_view 가 셸과 같은 Battle 을 본다")
	t.ok(game.field_view.army == game.run.army, "field_view 가 run 의 Army 를 그대로 본다")
	t.eq(game.field_view.rows.size(), Look.GRID_H, "field_view 가 섬 32줄을 받았다")
	t.ok(game.hud_view.battle == game.battle, "hud_view 가 셸과 같은 Battle 을 본다")
	t.ok(game.panel_view.run == game.run, "panel_view 가 셸과 같은 Run 을 본다")

	# -- swap in the spies and re-open the island --------------------------------------------------
	# ⚠⚠ `reward_view` is swapped in HERE too, before island 0's own win ever reaches `PICK` — not
	# later, right before item 4's own check. A spy created fresh right there would start every field
	# at its own neutral default and could never tell "rebound" from "never bound in the first place".
	# Swapped in this early, it is the SAME spy that gets genuinely dirtied by island 0's own two-card
	# pick (real `_taken_age` entries, a real climbing `_reveal_age`) — which is what makes "did the
	# SECOND pick screen actually rebind" a question with a real answer instead of a coin flip.
	for v: Node2D in [game.field_view, game.hud_view, game.panel_view, game.reward_view]:
		game.remove_child(v)
		v.queue_free()
	var fs := FieldSpy.new()
	var hs := HudSpy.new()
	var ps := PanelSpy.new()
	var rs := RewardSpy.new()
	game.field_view = fs
	game.hud_view = hs
	game.panel_view = ps
	game.reward_view = rs
	game.add_child(fs)
	game.add_child(hs)
	game.add_child(ps)
	game.add_child(rs)
	t.ok(fs.battle == null and hs.battle == null and ps.run == null and rs.run == null,
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
	# ⚠⚠ **THE TERRAIN PASS IS CULLED NOW**, so the count is the VISIBLE span rather than the whole
	# margin ring. The island is sitting exactly where `field_view.setup()` left it — `ZOOM_MIN` 0.45,
	# `cam_px` (-462.22, -160.00) — and the arithmetic, done by hand and not read off the code:
	# ⚠⚠ **RE-DONE 2026-08-24 when the board was laid back 40 degrees.** A row is `TILE_H_PX` 30.64176
	# px tall now, so the map is 980.54 px from top to bottom instead of 1280 and the camera centres
	# the y axis lower. `WATER_MARGIN_TILES` went 12 -> 16 in the same edit.
	#   map                          x 48 * 40 = 1920      ·  y 32 * 30.64176 = 980.54
	#   both axes centred at ZOOM_MIN   cam_px (-462.22, -309.73)
	#   visible world  x -462.22 .. 2382.22  ·  y -309.73 .. 1290.27
	#   + CULL_PAD_TILES 2 (80 px)   x -542.22 .. 2462.22  ·  y -389.73 .. 1370.27
	#   floor/ceil to tiles          x -14 .. 62           ·  y -13 .. 45   (y divides by 30.64176)
	#   clamped to [-16, 48+16) x [-16, 32+16)   ⇒ **x -14 .. 62, y -13 .. 45 = 76 x 58 = 4408**
	# ⚠ **Neither axis is culled by the clamp any more** — the visible world is now wider AND taller
	# than the map, so both spans are the view's own and the margin is what stops them.
	# **The cull still bites**: 4408 against a full ring of 5120.
	#
	# ⚠ **3168, 4032 and 1536 are LITERALS.** Deriving any of them from `WATER_MARGIN_TILES` or
	# `CULL_PAD_TILES` would move the expectation and the reality together, and the margin could vanish
	# with the round green.
	const CULL_X0 := -14
	const CULL_Y0 := -13
	const CULL_W := 76
	const CULL_H := 58
	t.eq((Look.GRID_W + 2 * margin) * (Look.GRID_H + 2 * margin), 5120,
		"물 여백까지 다 세면 5120칸이다 (80 x 64) — 여백 상수가 0이 되면 여기가 문다")
	t.eq(Look.GRID_W * Look.GRID_H, 1536, "격자 자체는 1536칸이다")
	t.eq(fs.tiles.size(), 4408, "지형은 보이는 만큼만 4408칸 그린다 (76 x 58)")
	# The ceiling that makes the cull mean something: it has to be strictly less than painting the lot.
	t.ok(fs.tiles.size() < 5120,
		"그리고 그건 5120보다 적다 — 컬링이 실제로 문다 (%d칸을 안 그렸다)" % (5120 - fs.tiles.size()))
	var tile_bad := 0
	var inner_rects: Array[Rect2] = []
	var painted := Rect2()
	for i in fs.tiles.size():
		var tx: int = i % CULL_W + CULL_X0
		var ty: int = i / CULL_W + CULL_Y0
		var got: Rect2 = fs.tiles[i]["rect"]
		if got != Look.tile_rect_px(tx, ty):
			tile_bad += 1
		painted = got if i == 0 else painted.merge(got)
		if tx >= 0 and tx < Look.GRID_W and ty >= 0 and ty < Look.GRID_H:
			inner_rects.append(got)
	t.eq(tile_bad, 0, "4408칸이 전부 자기 자리의 사각형을 받았다 (행 우선, 잘라낸 구간 안에서)")
	t.eq(inner_rects.size(), 1536, "그중 격자 안쪽이 1536칸이다 — 섬 자체는 한 칸도 안 잘렸다")
	# ⚠⚠ **THE FLOOR UNDER THE CULL, and it is the only thing that makes the ceiling above safe.**
	# "Fewer tiles" is also what a cull that ate the screen would say. What must never happen is a
	# visible pixel with no tile under it, so the painted area has to CONTAIN the visible world.
	var seen := fs._visible_world_rect()
	t.ok(painted.encloses(seen),
		"칠한 영역이 보이는 세계를 전부 덮는다 — 잘라낸 칸은 전부 화면 밖이었다 (칠함 %s ⊇ 보임 %s)"
			% [str(painted), str(seen)])
	# ⚠ **The two axes no longer share a multiplier.** A tile is `TILE_PX` wide and `TILE_H_PX` tall,
	# and writing `Vector2(CULL_W, CULL_H) * TILE_PX` here would be the flat board asserted against a
	# laid-back one.
	t.eq(painted.size, Vector2(CULL_W * Look.TILE_PX, CULL_H * Look.TILE_H_PX),
		"칠한 영역이 3040 x 1777.22 px 다 (76 x 58 칸)")
	# ⚠ The margin is why the tiles below are filtered before the on-screen check: `tile_rect_px(-1,
	# -1)` really is at (-40, -40), so feeding all 680 in would break "everything lands inside
	# 1280x720" for the 104 that are supposed to be outside it — and widening the screen rectangle
	# instead would kill that check for the docks, the HP bars and the HUD at the same time.
	t.ok(Look.tile_rect_px(-margin, -margin).position.x < 0.0,
		"여백 타일은 화면 밖에서 시작한다 — 그래서 화면-안 검사에서 빼야 한다")
	t.eq(fs.tiles[0]["fill"], Look.COL_WATER,
		"여백 칸은 COL_WATER 를 직접 받는다 — 격자 밖에는 범례 문자가 없다")
	# Tile (0, 0)'s index inside the culled span: `(0 - CULL_Y0) * CULL_W + (0 - CULL_X0)` = 6*72+12.
	t.eq(fs.tiles[444]["fill"],
		Look.terrain_colour_of_char(str(game.field_view.rows[0])[0]),
		"격자 첫 칸의 색은 그 칸의 범례 문자에서 나왔다")
	t.eq(float(fs.tiles[0]["width"]), Look.GRID_LINE_WIDTH_PX, "격자선 굵기가 look.gd 값이다")

	# -- ⚠⚠ THE HARBOUR MARKERS AND THE RESERVE STACK ARE DELETED, AND SO ARE THEIR ROWS -----------
	# What stood here: `fs.docks.size() == b.harbour_count()` with a rect-per-harbour check, then the
	# whole idle-stack pass — one body per RESERVE soldier at `idle_soldier_rect(i)`, the radius read
	# back off the captured argument, the three-tile bound off `IDLE_SOLDIER_ORIGIN_PX`, the
	# distance-from-anchor row, and 6.3's 「the thing you drag is never under the chrome you press」.
	#
	# **Every one of those subjects is deleted** — the user, pointing at a screenshot of the yellow
	# harbour outlines and the stack: ***"ㅇㅇ 지워줘"***. `_paint_dock`, `idle_soldier_rect`,
	# `Look.IDLE_SOLDIER_*` and `idle_soldier_offset_px` are gone from the tree with them.
	#
	# ⚠ **Deleted rather than repaired.** A row rewritten to survive the deletion of its own subject is
	# how coverage drops with nobody noticing.
	# ⚠⚠ **AND ONE THING WENT WITH THEM THAT NOTHING REPLACES**: 6.3's row was the only check that the
	# HUD chrome never sits on top of what the hand reaches for. The five slot boxes are what the hand
	# reaches for now, and **nothing measures whether the start button overlaps them** — `net_slots`
	# only checks the boxes against each other and against the viewport. That is a real hole, not a
	# tidy deletion.
	t.eq(fs.hulls.size(), 0, "커밋 전에는 선체가 하나도 없다 — 배는 눌러야 생긴다")
	t.eq(fs.zoom, Look.ZOOM_MIN, "섬이 ZOOM_MIN 으로 열려 있다 (자가 점검)")


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
	var south_y := north_y + Look.TILE_H_PX
	var wrong_side := 0
	var zero_len := 0
	for si in seg_count:
		var p0: Vector2 = cliff_pts[si * 2]
		var p1: Vector2 = cliff_pts[si * 2 + 1]
		if absf(p0.y - south_y) < 0.01 and absf(p1.y - south_y) < 0.01:
			wrong_side += 1
		# ⚠ **A segment along the north edge is `TILE_PX` long; one running north-to-south is
		# `TILE_H_PX` long, because the board is laid back.** The old form asked every segment to be
		# at least a tile WIDE and the two end segments stopped being that the moment the rows
		# shortened. Checking the exact length per direction is stronger than what it replaced.
		var want_len := Look.TILE_PX if absf(p0.y - p1.y) < 0.01 else Look.TILE_H_PX
		if absf(p0.distance_to(p1) - want_len) > 0.01:
			zero_len += 1
	t.eq(wrong_side, 0, "어떤 단면도 육지 쪽(남쪽) 가장자리에 있지 않다")
	t.eq(zero_len, 0, "그리고 모든 단면이 자기 방향의 칸 길이만큼 길다 — 길이 0인 선이 없다")

	# The bodies are the enemies the sim says are alive, in the sim's own order, at the sim's own
	# positions. Nothing here is recomputed from a screen coordinate — the comparison runs the other
	# way, from what `battle` holds to what the hook was handed.
	var live_enemies := []
	for e in b.enemy_alive.size():
		if b.enemy_alive[e] != 0:
			live_enemies.append(e)
	t.ok(live_enemies.size() > 0, "섬 0에 살아 있는 적이 있다 (%d마리)" % live_enemies.size())
	t.eq(b.ashore_ids().size(), 0, "아직 상륙한 병사는 없다")
	# ⚠ **The idle army used to be on this layer too and is deleted**, so the bodies on screen before
	# the commit are the enemies and nothing else. The offset that skipped past the stack goes with it.
	t.eq(fs.bodies.size(), live_enemies.size(),
		"몸통 수 = 살아 있는 적 수 — 항구에 선 예비 병사 무더기가 사라졌다")
	var enemy_base := 0
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
	for arr: Array in [fs.tiles, fs.hulls, fs.cliff_faces, fs.bodies, fs.beaks, fs.hps,
			fs.shots, fs.halos, fs.rings, fs.target_lines, fs.sparks]:
		for it: Dictionary in arr:
			seen_seq[int(it["seq"])] = true
			call_total += 1
	t.eq(seen_seq.size(), call_total,
		"훅 호출 %d번이 전부 서로 다른 순번을 들고 있다 — 순번을 안 적은 훅이 없다" % call_total)
	t.ok(seen_seq.has(0) and seen_seq.has(call_total - 1),
		"순번이 0에서 시작해 빈칸 없이 끝까지 간다 — _draw 머리에서 되감긴다")
	t.ok(_seq_max(fs.tiles) < _seq_min(fs.cliff_faces), "층 1 지형이 층 1b 절벽 단면보다 먼저 그려졌다")
	# ⚠ **There are no hulls on this frame at all** — nothing has been dropped, so `fs.hulls` is empty
	# and the old 「항구 -> 선체 -> 몸」 pair would be comparing sentinels. The hull's own layer is
	# re-pinned after the commit, further down, where a hull actually exists.
	# ⚠ The two rows that ordered the HARBOUR MARKERS between the cliff faces and the bodies are
	# deleted with the markers themselves.
	t.ok(_seq_max(fs.cliff_faces) < _seq_min(fs.bodies), "절벽 단면이 층 6b/7 몸보다 먼저 그려졌다")
	t.ok(_seq_max(fs.bodies) < _seq_max(fs.hps) or fs.hps.is_empty(),
		"몸과 HP 막대가 같은 층에서 함께 나온다 (자가 점검)")

	# -- the HUD, and the number on it coming from the sim -----------------------------------------
	t.eq(hs.timers.size(), 1, "타이머를 한 번 그렸다")
	# 「시간 %.1f」 and not 「남은 시간 %.1f」 — the user asked for fewer words and bigger type, and this
	# is the half a net can hold: one word instead of two.
	t.eq(str(hs.timers[0]["text"]), "시간 %.1f" % b.time_left(), "타이머 글자가 sim 의 남은 시간이다")
	t.eq(hs.timers[0]["at"], Look.HUD_TIMER_POS_PX, "타이머 위치가 look.gd 값이다")

	# ⚠⚠ **The berth boxes, the per-boat load labels, the two key slots AND the five speed chips are
	# all DELETED.** What is on this layer during planning is ONE start button — one call to the hook —
	# plus the timer and the enemy count. Three text items, against the shipped build's six and the
	# eight this file counted one round ago.
	t.eq(hs.buttons.size(), 1, "HUD 단추는 시작 하나뿐이다 — 배속 칩 다섯이 사라졌다")
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

	# ⚠⚠ **배속 칩이 화면에서 사라졌다, and it is asserted as an ABSENCE with a floor under it.**
	# 「buttons has no chip」 is also true of a HUD that stopped drawing entirely, so the floor is the
	# start button one block up: exactly one button, and it is the start button at its own rect.
	var chip_shaped := 0
	for raw_btn: Dictionary in hs.buttons:
		if (raw_btn["rect"] as Rect2).size != Look.start_rect_px().size:
			chip_shaped += 1
	t.eq(chip_shaped, 0, "시작 버튼 말고는 HUD 에 상자가 하나도 없다 — 배속 칩이 그려지지 않는다")
	t.eq((start_btn["rect"] as Rect2).size, Look.start_rect_px().size,
		"그 하나가 시작 버튼의 크기다 (바닥 — HUD 가 통째로 죽어서 0개인 게 아니다)")

	t.eq(hs.enemies.size(), 1, "남은 적 수를 한 번 그렸다")
	t.eq(str(hs.enemies[0]["text"]), "적 %d" % b.enemies_left(), "남은 적 글자가 sim 의 수다")
	t.eq(ps.panels.size(), 0, "전투 중에는 패널이 한 번도 안 그려졌다")
	# ⚠ **The counted glyph budget.** It was 8 (timer 1 + start 1 + chip 5 + enemy 1) and
	# `speed-off-open-landing` took the five chips out: **3 text items on the planning screen**,
	# against the shipped build's 6 and the user's own 「글자가 너무 많고」. Recorded here so it cannot
	# drift back up without somebody editing this number on purpose.
	t.eq(hs.timers.size() + hs.buttons.size() + hs.enemies.size(), 3,
		"계획 화면의 글자 항목은 셋이다 (타이머 1 + 시작 1 + 적 1)")
	t.ok(hs.timers[0]["seq"] < start_btn["seq"] and int(start_btn["seq"]) < int(hs.enemies[0]["seq"]),
		"HUD 는 타이머 -> 시작 버튼 -> 남은 적 순서로 그린다")

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
	for it: Dictionary in fs.hps:
		field_rects.append(it["back"])
	# ⚠ The idle stack used to be added here too, for a bound nothing else gave it. It is deleted.
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

	# ⚠ The drag's own tile picks (`sendable_tile` / `second_tile` / `refuse_tile`) went with the drag.
	# What the rows below still need is picked from the SUMMON band, further down.
	# ⚠ The inland-refusal fixture went with the drag's release, which is what marked a refusal there.

	# ⚠⚠ **초록색 해안이 사라졌다.** The wash used to be drawn from the moment the island opened and
	# the user asked for its inverse (「못내림만 표시하면 됨 ㅇㅇ」). The hook it went through is gone,
	# so the spy cannot even capture it — what is asserted here is the CONSEQUENCE on the tile pass:
	# every `_paint_tile` call is the terrain loop and nothing repaints a tile on top of it. That count
	# is already pinned at 4032 higher up in this file, which is the floor under this ceiling.
	t.ok(not fs.has_method("_paint_overlay"),
		"타일 덧칠 훅 자체가 없다 — 초록 해안을 그릴 방법이 남아 있지 않다")
	# ⚠ **The claim is NO OVERPAINT, and after the cull a COUNT can no longer carry it** — the camera
	# has moved since the count higher up in this file, so any number written here would be a second
	# copy of the cull's arithmetic rather than a statement about the wash. What says it directly is
	# that no two `_paint_tile` calls in one frame share a rectangle: one coat of terrain, and nothing
	# painted on top of it.
	var tile_seen := {}
	var repainted := 0
	for entry in fs.tiles:
		var key := str((entry as Dictionary)["rect"])
		if tile_seen.has(key):
			repainted += 1
		tile_seen[key] = true
	t.ok(fs.tiles.size() > 0, "지형 칸을 실제로 그렸다 (%d칸 — 0이면 깨끗한 게 아니라 안 돈 것이다)"
		% fs.tiles.size())
	t.eq(repainted, 0, "타일은 지형 한 벌만 그린다 — 같은 칸을 두 번 칠하지 않는다 (상륙 구역 덧칠 없음)")
	# ⚠ The row comparing `send`'s whole domain with one harbour's reach went with the drag. `send` is
	# still in the sim — `tools/probe/run_run.gd` is its last reader — but nothing on screen answers to
	# it any more, so a SHELL net is the wrong place to keep measuring it.

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

	# -- ⚠⚠ THE ENTIRE DRAG SUITE IS DELETED — ~320 LINES, SUBJECT AND ALL --------------------------
	# What stood here: press a body at the harbour, watch the candidate ring follow the cursor and turn
	# `COL_WIN`/`COL_LOSE`, read the drag's route preview point-for-point against `grid.water_route`,
	# release over water and over inland and count the refusal marks, undo with the landing ring, prove
	# the ring beats the body in the hit test, and author the whole ten-boat plan by dragging.
	#
	# **The gesture is deleted.** The user pointed at the harbour markers and the reserve stack and said
	# ***"ㅇㅇ 지워줘"***, and the drag is what they had already called not fun (`idea-inbox` row 26).
	# `_soldier_hit_at`, `field_view.set_drag`, `_drag_soldier` and `idle_soldier_rect` are gone.
	#
	# ⚠ **Deleted rather than repaired**, and what replaced it is not nothing: `net_slots` drives the
	# summon through the INPUT path end to end — the band, the keys, the press, the beat, the sweep, the
	# release, a dry slot, outside the band, after the commit, the aim marks and the slot row. This file
	# needs a PLAN so the rows below it have boats on screen, so it calls the sim directly rather than
	# re-driving a gesture another net already owns.
	#
	# ⚠⚠ **THREE THINGS THE DRAG SUITE MEASURED HAVE NO REPLACEMENT ANYWHERE**, and they are named here
	# rather than quietly dropped:
	#   1. **the route preview compared point-for-point with the sim's own route** — the only runtime
	#      catch for `_paint_route` cutting a corner over the island (`net_draw_leaf` counts call sites
	#      and cannot tell a polyline from a straight line). The summon draws its own route line and
	#      `net_slots` reads it, but not against `grid.summon_route` point for point;
	#   2. **the refusal mark's whole life** — that it fires on a refused release, at the cursor, once,
	#      and NOT on an accepted one. `net_slots` counts refusals per beat; it does not check the mark
	#      is absent on success;
	#   3. **hit-test precedence** — a landing ring on top of a body. There is no body any more, so the
	#      precedence itself is gone, not merely unmeasured.
	#
	# The plan below is authored with `battle.summon`, aimed at two different derived landings so the
	# ghost-fan rows underneath still have two beaches to tell apart.
	var band_tiles := []
	for bt in b.grid.summon_hops.size():
		if b.grid.can_summon_at(bt):
			band_tiles.append(bt)
	t.ok(band_tiles.size() > 0, "이 섬에 소환할 수 있는 바다 칸이 있다 (%d칸 — 자가 점검)" % band_tiles.size())
	var tile_a := int(band_tiles[0])
	var tile_b := -1
	for raw_bt in band_tiles:
		if b.grid.summon_landing_of(int(raw_bt)) != b.grid.summon_landing_of(tile_a):
			tile_b = int(raw_bt)
			break
	t.ok(tile_b >= 0, "상륙지가 서로 다른 바다 칸 둘을 골랐다 (자가 점검)")
	var sendable_px := Look.tile_point_px(b.grid.tile_point(b.grid.summon_landing_of(tile_a)))
	var second_px := Look.tile_point_px(b.grid.tile_point(b.grid.summon_landing_of(tile_b)))

	# Two at one beach and one at the other — the fan rank has to be counted among the boats sharing a
	# LANDING, not among all boats, and one beach cannot tell those two indices apart.
	for press_tile in [tile_b, tile_b, tile_a]:
		t.ok(b.summon(0, press_tile) >= 0, "바다를 눌러 한 척 띄웠다 (자가 점검)")
	await t.pump_frames(1)
	t.eq(b.boats.size(), 3, "셋을 순서대로 띄웠다 — 둘은 같은 해변, 하나는 다른 해변")

	# ⚠⚠ **OPEN 0 as a shell check, and it is the same claim the drag version made.** The brake is
	# deliberately absent (the user: 「일단 빼고 만든 이후에 추가하자는 거임」), so every remaining body
	# has to be placeable. **This also makes the crossing rows below mean something**: three boats at
	# one distance cannot show a route shrinking or a fleet in motion, and ten at two distances can.
	var before_fill := b.boats.size()
	for slot_i in Rules.summon_slot_count():
		var guard := 0
		while not b.slot_reserve_ids(slot_i).is_empty() and guard < 40:
			t.ok(b.summon(slot_i, tile_a if guard % 2 == 0 else tile_b) >= 0,
				"%d번 슬롯에서 한 명 더 내보냈다 (자가 점검)" % slot_i)
			guard += 1
	await t.pump_frames(1)
	t.eq(b.boats.size(), Rules.roster_start_count(),
		"명단 전부를 내보낼 수 있다 — 배 수에 상한이 없다")
	t.ok(b.boats.size() > before_fill, "그리고 실제로 늘었다 (자가 점검)")
	var all_transit := 0
	for si5 in b.soldier_state.size():
		if b.soldier_state[si5] == Battle.SoldierState.TRANSIT:
			all_transit += 1
	t.eq(all_transit, Rules.roster_start_count(), "열 명 전부 배에 탔다")
	t.eq(b.elapsed, 0.0, "열 척을 내보내는 동안에도 시계는 정확히 0이다")

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
	t.eq(fs.routes.size(), b.boats.size(), "아직 안 간 배의 항로는 남아 있다")
	# ⚠⚠ **확정 뒤 HUD 에 상자가 하나도 없다.** The start button goes at the commit and the five speed
	# chips no longer exist, so this layer answers no press at all — that is 결정 1 without the escape
	# hatch the chips used to be. The floor for this zero is the `== 1` one section above, measured on
	# the same HUD a few frames earlier.
	t.eq(hs.buttons.size(), 0, "확정 뒤 HUD 에 상자가 하나도 안 남는다 (실행 화면의 글자 항목은 둘)")
	t.eq(hs.timers.size() + hs.buttons.size() + hs.enemies.size(), 2,
		"실행 화면의 글자 항목은 둘이다 (타이머 1 + 적 1)")

	# -- ⚠⚠ 항해 중인 배의 선은 남은 길만 그린다 --------------------------------------------------------
	# The view draws from the SIM's own `leg`; a route redrawn whole every frame would show the boat
	# sailing water it has already crossed. Compared against `path.slice(leg + 1)` and never against a
	# walk re-derived here — a second copy of the arc-length walk is the drift this split exists to
	# make impossible.
	var route_len_first := (fs.routes[0]["points"] as PackedVector2Array).size()
	var shrank := false
	var tail_bad := 0
	var head_bad := 0
	# ⚠ **80 steps of 0.05 s, and BOTH numbers have a reason.** The drawn line shrinks when the sim's
	# `leg` advances, and string-pulling leaves a crossing with one long first segment instead of a row
	# of one-tile hops — so the step has to be small enough that a frame is drawn BETWEEN the leg
	# advancing and the boat landing, and the loop long enough to reach the advance at all. At 0.15 s
	# the summon's crossing went from leg 0 to landed inside one step and this row could not see it.
	# The loop still breaks the moment the boat stops being OUTBOUND, so a short crossing costs nothing.
	for _cn2 in 160:
		game._process(0.05)
		await t.pump_frames(1)
		if b.boats.is_empty() or fs.routes.is_empty():
			break
		var boat0: Dictionary = b.boats[0]
		if int(boat0["phase"]) != Battle.Phase.OUTBOUND:
			break
		var live: PackedVector2Array = fs.routes[0]["points"]
		if live.size() < route_len_first:
			shrank = true
		if live[0].distance_to(Look.tile_point_px(Vector2(boat0["pos"]))) > 0.01:
			head_bad += 1
		var want_tail := PackedVector2Array()
		for wp2 in (boat0["path"] as PackedVector2Array).slice(int(boat0["leg"]) + 1):
			want_tail.append(Look.tile_point_px(wp2))
		if live.slice(1) != want_tail:
			tail_bad += 1
	t.eq(head_bad, 0, "항해 중 선의 첫 점은 언제나 선체 자신의 자리다")
	t.eq(tail_bad, 0, "그리고 나머지는 정확히 path.slice(leg + 1) 이다 — 뷰가 따로 걷지 않는다")
	t.ok(shrank, "가면서 점 수가 줄어든다 (%d점에서 시작) — 이미 지나온 물을 다시 안 그린다"
		% route_len_first)

	# ⚠⚠ **결정 1 as a check.** All three plan branches are gated, and the three of them are pressed.
	var boats_snapshot := b.boats.size()
	# ⚠ The two branches that pressed a BODY and released a held soldier are deleted with the drag.
	# What is left after the commit is the ring undo and the summon, and both are pressed below.
	# ⚠⚠ **The summon's own post-commit gate is `net_slots`' `_after_the_commit`**, which presses a
	# band tile with a slot still armed and reads the boat count AND the refusal count.
	# ⚠ **The gate is on the BRANCH, not on the hit test.** `_ring_hit_at` still answers — it is a pure
	# geometry lookup — so the row that matters is that pressing there changes nothing.
	t.ok(game._ring_hit_at(second_px) >= 0, "고리 자체는 여전히 그 자리에 있다 (자가 점검)")
	t.root.push_input(_press(second_px), true)
	await t.pump_frames(1)
	t.root.push_input(_release(second_px), true)
	await t.pump_frames(1)
	t.eq(b.boats.size(), boats_snapshot, "확정 뒤에는 고리를 눌러도 안 무른다")
	# ⚠⚠ **THE RELEASE BRANCH'S OWN GATE IS DELETED WITH THE DRAG, and so is the row that reached it
	# by hand.** That row was already labelled as unable to redden on its own — `Battle.send` refuses a
	# committed island by itself — and `_on_left_release` now holds nothing that could author anything.

	# -- the clock runs with nothing pressed at all ----------------------------------------------------
	var elapsed_before := b.elapsed
	for _n in 4:
		game._process(0.016)
	t.ok(b.elapsed > elapsed_before,
		"시작하면 아무것도 안 눌러도 시계가 간다 (%.4f초) — 셸이 delta 를 안 넘기면 여기가 문다" % b.elapsed)

	# -- ⚠⚠ 확정 뒤 화면 아무 데나 눌러도 시뮬레이션이 안 바뀐다 ----------------------------------------
	# The four corners of the row the chips USED to occupy, typed as literals because
	# `Look.speed_rect_px` no longer exists to ask. Pressed through `game._unhandled_input` directly —
	# mouse clicks pushed at the root arrive at (2000, 6520) in a 64px headless window and hit nothing
	# with no error at all, so half an input suite can be green while the other half is dead.
	var ghost_row := Rect2(Vector2(1060.0, 648.0), Vector2(220.0, 40.0))
	var corners: Array[Vector2] = [
		ghost_row.position + Vector2(2.0, 2.0),
		Vector2(ghost_row.end.x - 2.0, ghost_row.position.y + 2.0),
		Vector2(ghost_row.position.x + 2.0, ghost_row.end.y - 2.0),
		ghost_row.end - Vector2(2.0, 2.0),
	]
	# The control arm: the same number of `_process` calls with NO presses at all. Run first, off a
	# snapshot, so the comparison is against a number rather than against a hope.
	var control_elapsed := b.elapsed
	var control_substeps := b.substeps
	for _cn in 6:
		game._process(0.016)
	var control_after_elapsed := b.elapsed - control_elapsed
	var control_after_substeps := b.substeps - control_substeps

	var pressed_elapsed := b.elapsed
	var pressed_substeps := b.substeps
	var pressed_positions: Array = []
	for i5 in b.soldier_state.size():
		pressed_positions.append(Vector2(b.soldier_pos[i5]))
	for c5: Vector2 in corners:
		game._unhandled_input(_press(c5))
		game._unhandled_input(_release(c5))
	for _pn in 6:
		game._process(0.016)
	t.ok(absf((b.elapsed - pressed_elapsed) - control_after_elapsed) <= 1e-5,
		"옛 배속 줄 네 귀퉁이를 눌러도 시계가 아무것도 안 누른 판과 똑같이 간다")
	t.eq(b.substeps - pressed_substeps, control_after_substeps,
		"서브스텝 수도 똑같다 — 누름이 시뮬레이션을 한 번도 안 건드렸다")
	# ⚠ **AT LEAST ONE, and it used to be ALL.** Under the drag every boat left from one harbour and
	# every soldier was still at sea at this point, so "all of them moved" happened to hold. A summoned
	# boat lands sooner and a soldier ASHORE that is blocked or already in reach stands still — which
	# is correct behaviour, not a dead screen. The floor this row is (**the sim is not frozen**) is
	# carried by one body in motion; that the sim advanced at all is pinned two lines up on `substeps`.
	var moved := 0
	var counted := 0
	for i6 in b.soldier_state.size():
		if b.soldier_state[i6] == Battle.SoldierState.RESERVE:
			continue
		counted += 1
		if Vector2(pressed_positions[i6]).distance_to(Vector2(b.soldier_pos[i6])) > Rules.EPS:
			moved += 1
	t.ok(counted > 0, "셀 병사가 있다 (자가 점검 — 0명이면 아래가 공허하다)")
	t.ok(moved > 0,
		"그 사이 병사들은 실제로 움직이고 있었다 (%d/%d — 바닥, 죽은 화면이라 안 바뀐 게 아니다)"
			% [moved, counted])
	# And the camera still answers, which is what stops the row above being green because the screen
	# is dead. Driven downward: `ZOOM_MAX` is 1.0 and the camera can be parked there.
	var ghost_zoom := fs.zoom
	game._unhandled_input(_wheel(ghost_row.get_center(), false))
	t.ok(fs.zoom < ghost_zoom,
		"그래도 같은 자리에서 휠은 화면을 움직인다 (%.3f -> %.3f)" % [ghost_zoom, fs.zoom])
	fs.zoom = ghost_zoom
	await t.pump_frames(1)

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

	# Left at ZOOM_MIN, the state `setup()` actually produced, so the wheel test right after this
	# section still measures "zoomed IN from where the island opened" rather than from wherever this
	# section happened to leave the camera. (`fs.set_drag(-1, -1)` stood here and is deleted with the
	# gesture it cleared.)
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
	t.ok(game.battle == null, "그제서야 카드 화면으로 돌아갔다 (바닥 — 영영 안 돌아오면 여기가 문다)")
	t.ok(fs.battle == null, "field_view 도 섬을 놓았다 — 안 그러면 지난 섬 지형이 카드 화면 밑에 계속 그려진다")
	t.ok(hs.battle == null, "hud_view 도 놓았다 — 시계와 시작 단추가 카드 화면 위에 남지 않는다")
	# ⚠⚠ 「이기면 지도가 아니라 카드 고르기가 먼저 열린다」 — mutation: move `_advance`'s `PICK` arm
	# below its `MAP` arm, and the cards are drawn and never shown while every count-only check stays
	# green.
	t.eq(game.run.state(), Run.State.PICK, "이긴 뒤 카드 고르기가 먼저 열린다")
	t.eq(game.run.island_index, 0, "그리고 섬 번호는 혼자 안 움직였다 — 어느 칸으로 갈지는 손이 정한다")
	t.eq(game.run.map.at(), 0, "서 있는 칸은 아직 0번이다")
	t.eq(game.run.army.type_id.size(), 13, "0번 칸의 수 보상이 그 자리에서 붙었다 (10 + 3)")
	t.ok(not game.panel_view.panel_active(), "카드 화면에서도 패널이 안 뜬다")
	await t.pump_frames(2)
	t.eq(fs.tiles.size(), 0, "카드 화면 밑에 지형이 한 칸도 안 그려진다 — 지난 섬이 안 남는다")
	t.eq(hs.timers.size(), 0, "시계도 안 그려진다")
	t.eq(ps.panels.size(), 0, "패널도 없다")

	_walk_pick_and_refit_to_map(t, game, fs, "0번")
	t.eq(game.run.state(), Run.State.MAP, "카드를 고르고 정비를 닫으면 지도다")
	t.ok(not game.panel_view.panel_active(), "지도에서는 패널이 안 뜬다")

	# ⚠⚠ Item 4's own fixture — `rs` is `game.reward_view` and its clock (`_fx_step`) runs every real
	# frame regardless of screen, so a few pumped frames HERE, while `run.cards_taken` still carries
	# 0번's own two picks (nothing clears it until the NEXT `_draw_cards()`), grow real `_taken_age`
	# entries. Without this the staleness row far below would be proving nothing — a check that never
	# gets dirtied cannot tell "rebound" from "never bound at all".
	await t.pump_frames(3)
	t.ok(not rs._taken_age.is_empty(), "0번 칸에서 고른 두 카드가 화면에 실제로 자국을 남겼다 (자가 점검)")

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
	t.ok(not game.panel_view.panel_active(), "패널은 아직 안 떠 있다 (자가 점검)")

	# ⚠⚠ **H — the release-time panel guard — IS DELETED WITH THE DRAG.** `_on_left_release` used to
	# refuse `battle.send` while the panel was up, and the row that reached that guard had to set
	# `_drag_soldier` by hand because the normal flow could not produce the state. There is no
	# `battle.send` on any release path any more, so there is no guard and nothing to reach.
	# ⚠ **The PAN half of this block survives and is what the rows below still measure**: a press that
	# starts a pan, a panel that comes up, and motion that must no longer move the camera.
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

	t.ok(game.panel_view.panel_active(), "패널이 실제로 떠 있다 (자가 점검)")
	game._on_left_release(Vector2(700.0, 300.0))
	await t.pump_frames(1)
	t.eq(b.boats.size(), boats_before_isle1, "패널이 뜬 뒤 떼어도 배가 안 생긴다")
	t.ok(not game._panning, "그리고 끌기 상태가 정리된다")

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
	t.eq(roster.size(), Rules.roster_start_count() + Rules.roster_reward_count(),
		"명단이 13명이다 (10 + 보상 3)")
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

	# ⚠⚠ `rs` is the SAME spy that has been `game.reward_view` since before island 0's own win — it
	# was genuinely dirtied by that first pick (two real `_taken_age` entries, a `_reveal_age` well
	# past `SCENE_FADE_SEC`), so the staleness this row measures below is real staleness carried
	# forward, not a fresh spy's own neutral defaults answering by accident.
	t.ok(rs == game.reward_view, "reward_view 가 여전히 그 스파이다 (자가 점검)")

	game._process(Look.HOLD_BEAK_SEC)
	t.eq(game._pending_beak, -1, "hold 가 끝나면서 셸이 손을 놓았다")
	t.eq(int(game.run.army.has_beak[3]), 1, "그제서야 3번 병사에게 부리가 붙었다")
	# ⚠⚠ 「부리를 달고 나면 지도가 아니라 카드 화면이다」 — both halves. `run.state()` alone is NOT
	# enough: it is written by the SIM's own `_advance` inside `apply_beak`, so it reads `PICK` whether
	# or not the SHELL ever rebinds the screen — mutation: `_release_hold`'s beak branch calls
	# `_enter_map_screen()` directly instead of `_show_state()`. Under that mutation `run.state()` still
	# says `PICK` (the line right below stays green) while `reward_view.bind(run)` never runs at all:
	# the screen the player actually sees would still be carrying whatever island 0's card screen left
	# behind.
	t.eq(game.run.state(), Run.State.PICK, "부리를 달고 나면 지도가 아니라 카드 화면이다 (자가 점검 — 셸 함수는 이걸 못 움직인다)")
	t.ok(game.battle == null, "그래서 섬이 닫혔다")
	t.eq(game.run.map.at(), 2, "서 있는 칸은 부리 칸 그대로다")

	rs.queue_redraw()
	await t.pump_frames(1)
	t.ok(rs._reveal_age < Look.SCENE_FADE_SEC * 0.5,
		"그리고 화면이 실제로 다시 묶였다 — 나이가 0에 가깝다 (%.3f), 지난 카드 화면의 나이가 그대로 남지 않았다"
			% rs._reveal_age)
	t.ok(rs._taken_age.is_empty(),
		"묶인 화면에 가져간 표 자국이 하나도 없다 — 0번 칸에서 골랐던 두 장의 흔적이 새 카드 위에 안 남는다")
	t.eq(rs.cards.size(), Rules.CARDS_PER_WIN, "카드 여섯 장이 실제로 다시 그려졌다")
	t.eq(rs.marks.size(), 0, "그리고 어느 카드에도 가져간 표가 없다")

	await t.pump_frames(1)
	t.eq(ps.panels.size(), 0, "패널이 사라졌다")
	t.eq(fs.tiles.size(), 0, "그리고 지형이 한 칸도 안 그려진다 — 카드 화면 밑에 지난 섬이 안 남는다")

	_walk_pick_and_refit_to_map(t, game, fs, "부리 칸")
	t.eq(game.run.state(), Run.State.MAP, "카드를 고르고 정비를 닫아야 비로소 지도다")

	# -- on to the chest and the boss, one node press at a time ------------------------------------
	_press_node(t, game, 4, "3층 오른쪽")
	t.ok(game.battle != null, "3층 칸이 섬을 열었다")
	t.eq(game.run.island_index, Rules.map_island_of(4), "그 칸이 가리키는 섬이다")
	_win_the_open_island(t, game, "3층")
	_walk_pick_and_refit_to_map(t, game, fs, "3층")
	t.eq(game.run.state(), Run.State.MAP, "이기고 카드를 고른 뒤 다시 지도로 돌아왔다")
	t.ok(game.battle == null, "그리고 섬이 닫혔다")

	# ⚠⚠ **The chest is GONE — node 5 (floor 4, its old spot) is a fight now, exactly like every other
	# node.** Mutation: give node 5 back `island < 0`.
	t.ok(Rules.map_island_of(5) >= 0, "5번(4층, 옛 상자 자리)은 이제 격자를 가리킨다 (자가 점검)")
	var before_living := game.run.army.living_count()
	_press_node(t, game, 5, "4층")
	t.ok(game.battle != null, "4층 칸도 섬을 연다 — 상자처럼 지도에 머물지 않는다")
	t.eq(game.run.island_index, Rules.map_island_of(5), "그 칸이 가리키는 섬이다")
	_win_the_open_island(t, game, "4층")
	_walk_pick_and_refit_to_map(t, game, fs, "4층")
	t.eq(game.run.state(), Run.State.MAP, "COUNT 보상도 카드를 고르고 정비를 닫아야 지도로 돌아온다")
	t.ok(game.battle == null, "그리고 섬이 닫혔다")
	t.ok(game.run.army.living_count() > before_living, "COUNT 보상으로 병력이 늘었다")
	await t.pump_frames(2)
	t.eq(fs.tiles.size(), 0, "지도 화면으로 돌아오면 지형은 다시 안 그려진다")

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
	t.eq(game.run.army.living_count(), Rules.roster_start_count(), "다시 10명이다")
	t.eq(int(game.run.army.has_beak[3]), 0, "지난 런의 부리도 안 따라왔다")

	t.root.remove_child(game)
	game.queue_free()

	_panel_active_answers_all_five_screens(t)
	await _two_presses_reach_the_first_island(t)
	_the_plan_constants_have_both_ends(t)
	_the_readers_themselves(t)
	_the_speed_ladder_is_gone(t)
	_speed_steps_survives_read_by_nobody(t)
	_every_lose_reason_reads_differently(t)
	_the_panel_holds_every_soldier_a_run_can_field(t)
	await _the_roster_line_reads_max_hp_of(t)


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


## Every win now stops for the card pick before the map — six cards drawn, two taken, then 완료 closes
## the board. Walked through the real input door (`game._unhandled_input`), never by poking `Run`, for
## the same reason `_win_the_open_island` above drives the hold through `_process` rather than calling
## `finish_island` directly.
##
## ⚠⚠ **This is where §8.4's two new `net_shell` rows about the card screen actually get exercised**:
## a card screen draws no island underneath it (`battle == null` **and** `field_view.battle == null`,
## the same lever `_enter_map_screen` pulls) and a click on a card does not start a camera pan (the
## `PICK` branch has to sit ABOVE the `battle != null` fallback that ends in `_panning = true` —
## mutation: move it below).
func _walk_pick_and_refit_to_map(t, game: Game, fs: FieldSpy, label: String) -> void:
	t.eq(game.run.state(), Run.State.PICK, "%s — 이긴 뒤 카드 고르기가 열렸다" % label)
	t.ok(game.battle == null, "%s — 카드 화면 밑에는 섬이 없다" % label)
	t.ok(fs.battle == null, "%s — field_view 도 섬을 안 물었다 — 카드 화면에서는 섬이 안 그려진다" % label)
	t.ok(not game._panning, "%s — 카드를 고르기 전엔 드래그가 없다 (자가 점검)" % label)

	game._unhandled_input(_click(Look.card_rect_px(0).get_center()))
	t.ok(int(game.run.cards_taken[0]) != 0, "%s — 첫 카드를 골랐다" % label)
	t.ok(not game._panning, "%s — 카드 화면의 클릭이 카메라를 안 움직인다" % label)
	t.eq(game.run.state(), Run.State.PICK, "%s — 한 장으로는 아직 정비로 안 넘어간다" % label)

	game._unhandled_input(_click(Look.card_rect_px(1).get_center()))
	t.ok(int(game.run.cards_taken[1]) != 0, "%s — 둘째 카드도 골랐다" % label)
	t.eq(game.run.state(), Run.State.REFIT, "%s — 둘을 고르면 정비로 넘어간다" % label)

	game._unhandled_input(_click(Look.refit_done_rect_px(false).get_center()))
	t.eq(game.run.state(), Run.State.MAP, "%s — 완료를 누르면 정비에서 지도로 돌아온다" % label)


## The sim-only twin of the walk above, for fixtures that drive `Run` directly rather than through the
## shell. A no-op on any state that is not `PICK` — the boss pays no cards, and a `REWARD` win has not
## reached `PICK` yet — so a caller may call this after every `finish_island(true)` unconditionally.
func _take_two_and_close_refit(r: Run) -> void:
	if r.state() != Run.State.PICK:
		return
	r.take_card(0)
	r.take_card(1)
	r.close_refit()


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
	# 0번 칸의 승리도 여섯 장을 내므로, 2번 칸을 밟기 전에 카드를 고르고 정비를 닫아 지도로 돌아가야
	# `enter_node` 가 다시 먹는다 — `enter_node` 는 `MAP` 이 아니면 조용히 거절한다.
	r.finish_island(true)
	_take_two_and_close_refit(r)
	r.enter_node(2)
	r.finish_island(true)
	t.eq(r.state(), Run.State.REWARD, "부리 칸을 이기면 REWARD 다 (자가 점검)")
	t.ok(pv.panel_active(), "부리 고르기에서는 패널이 뜬다")

	r.apply_beak(0)
	_take_two_and_close_refit(r)
	r.enter_node(3)
	r.finish_island(false)
	t.eq(r.state(), Run.State.LOST, "지면 LOST 다 (자가 점검)")
	t.ok(pv.panel_active(), "진 화면에서도 패널이 뜬다")

	var won := Run.new()
	for n in [0, 1, 4, 5, 6]:
		won.enter_node(int(n))
		if won.state() == Run.State.BATTLE:
			won.finish_island(true)
			_take_two_and_close_refit(won)
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
		"그리고 (320, 96) 을 안 넘는다 (천장 — 화면 왼쪽 절반 안에 머문다)")
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
	# ⚠ **The five `HUD_SPEED_*` bounds are deleted with the chips they measured.** What replaced them
	# is `_the_speed_ladder_is_gone`, which asserts the constants themselves are absent — a bound on a
	# constant nobody draws is a bound that rots.
	#
	# **The refusal mark's own three, both ends each** (`speed-off-open-landing`, 2.5).
	t.ok(Look.REFUSE_MARK_SEC >= 0.25,
		"거절 표시가 최소 0.25초는 남는다 (바닥 — 60fps 다섯 프레임 0.084초 아래는 이 리포가 두 번 못 봤다)")
	t.ok(Look.REFUSE_MARK_SEC <= 0.6, "그리고 0.6초를 안 넘는다 (천장 — 다음 끌기까지 남아 있으면 안 된다)")
	t.ok(Look.REFUSE_MARK_R_PX >= Look.TARGET_RING_R_PX,
		"거절 표시가 후보 링(%.0f px)보다 크다 (바닥 — 같으면 「여기 놓을 수 있다」로 읽힌다)"
			% Look.TARGET_RING_R_PX)
	t.ok(Look.REFUSE_MARK_R_PX <= 40.0, "그리고 한 타일(40px)을 안 넘는다 (천장 — 이유가 될 지형을 덮는다)")
	t.ok(Look.REFUSE_MARK_WIDTH_PX >= 5.0,
		"굵기가 5 이상이다 (바닥 — ZOOM_MIN 0.45 에서 %.2f px, 이 파일의 2.0 px 스냅 바닥 위다)"
			% (Look.REFUSE_MARK_WIDTH_PX * Look.ZOOM_MIN))
	t.ok(Look.REFUSE_MARK_WIDTH_PX * Look.ZOOM_MIN >= 2.0,
		"그 산술이 실제로 성립한다 (자가 점검 — 바닥이 도출된 부등식 자체를 잰다)")
	t.ok(Look.REFUSE_MARK_WIDTH_PX <= 8.0, "그리고 8 을 안 넘는다 (천장 — 가리키는 칸을 삼킨다)")
	# ⚠⚠ **THE FIVE `IDLE_SOLDIER_*` ROWS ARE DELETED WITH THE CONSTANTS.** They bounded the reserve
	# stack's pitch, its column count and its origin, and the stack is gone (*"ㅇㅇ 지워줘"*).
	# ⚠ The ghost rows below SURVIVE, and that is not an oversight: a summoned boat is drawn as a ghost
	# at its derived landing before the commit exactly as a dropped one was, so `GHOST_FAN_PX` still
	# has a picture to bound.
	t.ok(Look.GHOST_FAN_PX.x >= 6.0 and Look.GHOST_FAN_PX.y >= 6.0,
		"유령 부채가 벌어진다 (바닥 6 — 못 미치면 두 유령이 한 덩어리이고 놓은 순서에 그림이 없다)")
	t.ok(Look.GHOST_FAN_PX.x <= 14.0 and Look.GHOST_FAN_PX.y <= 14.0,
		"그리고 14 를 안 넘는다 (천장 — 넘으면 열셋이 4타일에 퍼져 한 상륙으로 안 읽힌다)")
	t.ok(Look.GHOST_FAN_PX.length() * float(Rules.roster_start_count()
			+ Rules.roster_reward_count() - 1) > Look.TARGET_RING_R_PX,
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
## start button disappeared at the commit」 — written loosely (return the first button) it answers that
## question about a screen that never drew any of it. This repo has twice shipped a check carrying the
## defect it was written to catch, and neither was found by mutating the code.
func _the_readers_themselves(t) -> void:
	var fake := HudSpy.new()
	t.eq(_start_button(fake), {}, "빈 화면에서 시작 버튼을 찾으면 빈 사전이다 — 첫 단추를 아무거나 주지 않는다")

	# A box of some OTHER size: the reader must still not hand it back as the start button. This is
	# what the five speed-chip rects used to be, and the case survives them.
	fake.buttons.append({"seq": 0, "rect": Rect2(Vector2(1060.0, 648.0), Vector2(36.0, 40.0)),
		"bg": Look.COL_BUTTON, "text": "x", "at": Vector2.ZERO, "fsize": 1,
		"col": Look.COL_HUD_TEXT})
	t.eq(_start_button(fake), {},
		"다른 크기의 상자만 있는 화면에서도 시작 버튼은 못 찾는다 — 크기로 가려낸다")

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


## ⚠⚠ **배속 조작이 코드에서도 없어졌다.** Every deletion needs a check that the thing is GONE, not
## only that what is left still passes: a green round after deleting a widget proves nothing about the
## widget, because the checks that drove it were deleted in the same edit.
##
## ⚠ `get_script_constant_map()` is NOT static — calling it on the class name is a PARSE error that
## takes the whole net out with 「Nonexistent function 'new'」 rather than a red line. It is asked of an
## instance's own script here, which is also the script the game actually loaded.
func _the_speed_ladder_is_gone(t) -> void:
	var hv := HudView.new()
	var fv := FieldView.new()
	var lk := Look.new()
	var gm := Game.new()

	t.ok(not hv.has_method("set_speed"), "hud_view 에 set_speed 가 없다")
	t.ok(not fv.has_method("set_time_scale"), "field_view 에 set_time_scale 이 없다")
	t.ok(not fv.has_method("_paint_overlay"), "field_view 에 _paint_overlay 훅이 없다")
	t.ok(fv.has_method("note_refusal"), "대신 note_refusal 이 있다 (자가 점검 — 메서드 조회가 실제로 돈다)")
	t.ok(not gm.has_method("_speed_hit_at"), "game 에 _speed_hit_at 이 없다")

	var game_props: Array = []
	for raw in gm.get_property_list():
		game_props.append(str((raw as Dictionary)["name"]))
	t.ok(not game_props.has("_speed_slot"), "game 에 _speed_slot 필드도 없다")
	t.ok(not game_props.has("_drag_soldier"),
		"game 에 _drag_soldier 필드도 없다 — 드래그가 통째로 지워졌다")
	t.ok(game_props.has("_armed_slot"), "_armed_slot 은 그대로 있다 (자가 점검 — 속성 목록을 실제로 읽고 있다)")

	var fv_props: Array = []
	for raw2 in fv.get_property_list():
		fv_props.append(str((raw2 as Dictionary)["name"]))
	t.ok(not fv_props.has("_time_scale"), "field_view 에 _time_scale 필드도 없다")
	t.ok(not fv_props.has("_droppable_rects"), "그리고 _droppable_rects 도 없다 — 초록 해안이 통째로 빠졌다")

	var look_consts: Dictionary = lk.get_script().get_script_constant_map()
	for gone in ["COL_SPEED_ON", "HUD_SPEED_ORIGIN_PX", "HUD_SPEED_SIZE_PX", "HUD_SPEED_GAP_PX",
			"HUD_SPEED_TEXT_OFFSET_PX", "COL_SENDABLE", "DROP_TINT_ALPHA"]:
		t.ok(not look_consts.has(gone), "look.gd 에 %s 가 없다" % gone)
	t.ok(look_consts.has("COL_START"), "COL_START 는 그대로 있다 (자가 점검 — 상수 표를 실제로 읽고 있다)")
	for kept in ["REFUSE_MARK_SEC", "REFUSE_MARK_R_PX", "REFUSE_MARK_WIDTH_PX"]:
		t.ok(look_consts.has(kept), "그리고 %s 가 새로 있다" % kept)

	var look_methods: Array = []
	for raw3 in (lk.get_script() as Script).get_script_method_list():
		look_methods.append(str((raw3 as Dictionary)["name"]))
	t.ok(not look_methods.has("speed_rect_px"), "look.gd 에 speed_rect_px 가 없다")
	t.ok(not look_methods.has("sendable_tint"), "look.gd 에 sendable_tint 도 없다")
	t.ok(look_methods.has("start_rect_px"), "start_rect_px 는 그대로 있다 (자가 점검)")

	var hud_consts: Dictionary = hv.get_script().get_script_constant_map()
	t.ok(not hud_consts.has("SPEED_LABELS"), "hud_view 에 SPEED_LABELS 가 없다")
	t.ok(hud_consts.has("TYPE_LABELS"), "TYPE_LABELS 는 그대로 있다 (자가 점검)")

	hv.free()
	fv.free()
	gm.free()


## ⚠⚠ **`Rules.SPEED_STEPS` 는 살아 있고, src 안에서 아무도 안 읽는다.** The plan pins BOTH halves:
## the table is the only thing that has to come back the day the user says 「이제 필요해」, and a
## constant nobody reads is exactly the thing that rots unnoticed unless somebody says out loud that
## nobody reads it.
##
## The walk strips comments before matching, because `rules.gd`'s own paragraph NAMES these four and
## every doc comment in `src/` that explains the deletion would otherwise count as a reader.
## ⚠⚠ **A COUNT THAT GROWS IS NOT A MESSAGE THAT READS.** `panel_view` gained `MSG_LOST_LANDING` and
## **nothing in this suite would have noticed**: only three of its five message constants were ever
## named by a net, none of them by count, and `_message_text` was never driven for a loss reason at
## all. A fourth string could have been added, wired to nothing, and every round stayed green.
##
## So this drives `_message_text()` once per `Lose` member and demands the four come out DIFFERENT.
## Distinctness is the whole claim — 「패배」 four times over is exactly the screen this round exists to
## stop, and it is what a copy-paste branch produces.
##
## ⚠ **The walk is CLOSED against the enum, not against a list written here.** `Lose` is read out of
## `Battle`'s own constant map, so a fifth reason added tomorrow either gets its own line in
## `_message_text` or reddens this — it cannot arrive and fall through to the bare 「패배」 unnoticed.
## ⚠⚠ `Look.roster_capacity()` is pinned CONSERVATIVE — the largest roster a run can ever field, not
## the most a route happens to carry into a beak node — because node 5 (floor 4, the ex-chest) moved
## `map_max_count_nodes_on_a_route()` from 3 to 4 and the panel's old 20-slot capacity would have
## silently dropped the overflow again, the exact shape `roster_ids`'s own comment already warned about
## once. Three rows: the demand is pinned as a literal on the `Rules` side alone, the capacity is
## checked against that SAME literal (so a constant that quietly shrank cannot move the expectation
## with it), and the floor drives an actual 22-body roster through the real panel and reads back what
## it draws. Mutation: `panel_view.gd`'s `roster_ids` — `if ids.size() >= Look.roster_capacity():` ->
## `... - 2:`.
func _the_panel_holds_every_soldier_a_run_can_field(t) -> void:
	var demand := Rules.roster_start_count() \
		+ Rules.map_max_count_nodes_on_a_route() * Rules.roster_reward_count()
	t.eq(demand, 22, "이 판이 낼 수 있는 최대 명부가 스물둘이다 (10 + 짐승 넷 x 3)")
	t.ok(Look.roster_capacity() >= 22,
		"명부 판이 그 스물둘을 전부 담을 자리가 있다 (%d칸)" % Look.roster_capacity())

	# ⚠ Synthetic on purpose — no route today reaches a REWARD screen with 22 bodies aboard (the fewest
	# fights before the first beak node is two, per `Look.PANEL_SIZE_PX`'s own comment), so this drives
	# `run` directly rather than walking a route, and is a fixture rather than a real playthrough.
	var run := Run.new()
	t.ok(run.enter_node(0), "0번 칸을 밟는다 (자가 점검)")
	run.finish_island(true)
	# A win now stops for the card pick before the map — take both and close the board so the run can
	# step onto a second node at all.
	t.eq(run.state(), Run.State.PICK, "이긴 뒤 카드 고르기가 먼저 열린다 (자가 점검)")
	run.take_card(0)
	run.take_card(1)
	t.ok(run.close_refit(), "정비를 닫고 지도로 돌아온다 (자가 점검)")
	while run.army.living_count() < 22:
		run.army.recruit(0)
	t.ok(run.enter_node(2), "부리 칸을 밟는다 (자가 점검)")
	run.finish_island(true)
	t.eq(run.state(), Run.State.REWARD, "고르기가 열렸다 (자가 점검, 스물두 명째)")

	var pv := PanelView.new()
	pv.bind(run, null)
	var ids := pv.roster_ids()
	t.eq(ids.size(), 22, "패널이 스물두 명을 전부 담는다 — 캡이 빠뜨리지 않는다")
	var last_rect := pv.roster_rect_of(21)
	t.ok(Rect2(0.0, 0.0, 1280.0, 720.0).encloses(last_rect), "스물두 번째 자리도 화면 안이다")
	var hit := pv.soldier_id_at(last_rect.position + Vector2(4.0, 4.0))
	t.eq(hit, int(ids[21]), "그 자리를 누르면 스물두 번째 병사가 잡힌다")
	pv.free()


## ⚠⚠ item 4's panel half: the roster line reads `Army.max_hp_of`, never `Rules.hp_of(type)` — the
## exact mutation `panel_view.gd`'s own comment above `_entry_text` promises it does not make.
## MUTATION CONFIRMED GREEN by the plan's own audit before this row existed: `a.max_hp_of(i)` ->
## `Rules.hp_of(t)` left the whole suite green, because nothing anywhere compared the TEXT a roster
## line actually drew against the function combat itself reads. A 가슴 part fitted into slot 0 raises
## `max_hp_of` for every body that slot fields without moving the type's own base number — the one
## state where the two reads print different digits — so this drives the panel through exactly that.
func _the_roster_line_reads_max_hp_of(t) -> void:
	var r := Run.new()
	r.army.loadout.take_card(Rules.Part.CHEST, Rules.Species.MAMMAL)
	r.army.loadout.fit(0, 0)
	t.ok(r.enter_node(0), "0번 칸을 밟는다 (자가 점검)")
	r.finish_island(true)
	_take_two_and_close_refit(r)
	t.ok(r.enter_node(2), "부리 칸을 밟는다 (자가 점검)")
	r.finish_island(true)
	t.eq(r.state(), Run.State.REWARD, "보상 화면이 열렸다 (자가 점검)")

	var a := r.army
	t.ok(not is_equal_approx(a.max_hp_of(0), Rules.hp_of(int(a.type_id[0]))),
		"0번 슬롯 병사의 만피가 종류 기본값과 실제로 다르다 (자가 점검 — 가슴을 낀 판이 낀 슬롯이다)")

	var spy := PanelSpy.new()
	t.root.add_child(spy)
	spy.bind(r, null)
	spy.queue_redraw()
	await t.pump_frames(1)
	t.ok(spy.entries.size() > 0, "명단 항목을 그렸다 (자가 점검)")

	# ⚠⚠ Only slot 0's bodies can tell the two denominators apart — slot 1's board is untouched, so
	# `max_hp_of` and `Rules.hp_of` AGREE there and a text match on THAT row is neutral: it would read
	# the same whether `_entry_text` used `a.max_hp_of(i)` or the mutation's `Rules.hp_of(t)`.
	# Comparing every row against a "wrong" text and counting matches (the first draft of this check)
	# flags those neutral rows as false positives regardless of which function `panel_view.gd` calls —
	# it measures nothing on rows that cannot differ. This compares each DIVERGING row against the
	# CORRECT text instead, which only reads as green when `_entry_text` actually used `max_hp_of`.
	var checked := 0
	var bad := 0
	for e in spy.entries.size():
		# Nobody has died yet, so living-id order is 0..N-1 and the entry index IS the soldier id.
		var i := e
		var t_id := int(a.type_id[i])
		if is_equal_approx(a.max_hp_of(i), Rules.hp_of(t_id)):
			continue
		checked += 1
		var text := str(spy.entries[e]["text"])
		var want_text := "%d  %s  %.0f/%.0f" % [i, HudView.type_label(t_id), a.hp[i], a.max_hp_of(i)]
		if text != want_text:
			bad += 1
	t.ok(checked > 0, "실제로 갈리는 줄이 적어도 하나 있다 (자가 점검) — 0번 슬롯 병사들이다")
	t.eq(bad, 0,
		"그 줄들이 army.max_hp_of 가 내놓는 그 숫자를 그대로 찍는다 — 종류 기본값이 아니다")

	t.root.remove_child(spy)
	spy.queue_free()


func _every_lose_reason_reads_differently(t) -> void:
	var r := Run.new()
	r.enter_node(0)
	var b := r.begin_island()
	r.finish_island(false)
	t.eq(r.state(), Run.State.LOST, "진 런을 하나 만들었다 (자가 점검)")

	var pv := PanelView.new()
	pv.bind(r, b)
	t.ok(not pv.is_reward(), "보상 화면이 아니다 — 패배 문구 가지를 탄다 (자가 점검)")

	var lose_enum: Dictionary = Battle.new().get_script().get_script_constant_map()["Lose"]
	t.eq(lose_enum.size(), 4, "패인은 넷이다 (NONE · TIMEOUT · WIPED · LANDING_LOST)")
	var want := {
		"NONE": PanelView.MSG_LOST,
		"TIMEOUT": PanelView.MSG_LOST_TIMEOUT,
		"WIPED": PanelView.MSG_LOST_WIPED,
		"LANDING_LOST": PanelView.MSG_LOST_LANDING,
	}
	var seen := {}
	var missing: Array[String] = []
	for name: String in lose_enum:
		if not want.has(name):
			missing.append(name)
			continue
		b._lose = int(lose_enum[name])
		var got := pv._message_text()
		t.eq(got, str(want[name]), "패인 %s 는 「%s」로 읽힌다" % [name, str(want[name])])
		seen[got] = true
	t.eq(missing.size(), 0,
		"표에 없는 패인이 없다 — 새 패인은 자기 문구를 받거나 여기서 문다 %s" % str(missing))
	t.eq(seen.size(), 4, "그리고 넷이 서로 다른 문장이다 — 넷 다 「패배」면 이 줄이 문다")

	# The floor under the distinctness: the two that existed before really did differ, so `seen` is
	# not 4 because the four constants happen to be four copies of one edit.
	t.ok(PanelView.MSG_LOST_WIPED != PanelView.MSG_LOST_LANDING,
		"전멸과 상륙 실패는 다른 문장이다 — 이 라운드가 갈라놓은 그 둘이다")
	pv.free()


func _speed_steps_survives_read_by_nobody(t) -> void:
	t.eq(Rules.SPEED_STEPS.size(), 5, "사다리에 다섯 칸이 남아 있다")
	t.eq(Rules.SPEED_STEPS, [0.0, 1.0, 2.0, 3.0, 6.0], "그리고 값도 그대로다")
	t.eq(Rules.SPEED_SLOT_DEFAULT, 1, "기본 칸은 여전히 1이다 — 0번(정지)이 아니다")
	t.eq(float(Rules.SPEED_STEPS[Rules.SPEED_SLOT_DEFAULT]), 1.0, "그 칸의 값이 1.0 이다")
	t.eq(Rules.speed_slot_count(), 5, "접근자도 그대로 돈다")
	t.eq(Rules.speed_mul_of(4), 6.0, "꼭대기는 6배속이다")

	var files := _gd_files_under("res://src")
	# ⚠ The file-count floor. A walk that found nothing to read reads as clean, and this repo has
	# already shipped a scan that silently matched zero files.
	t.ok(files.size() >= 8, "src 아래 .gd 를 %d개 걸었다 (바닥 8 — 0개면 깨끗한 게 아니라 안 돈 것이다)"
		% files.size())
	var readers: Array = []
	var scanned := 0
	for raw in files:
		var path := str(raw)
		if path.ends_with("/rules.gd"):
			continue
		scanned += 1
		var text := FileAccess.get_file_as_string(path)
		var stripped := ""
		for line in text.split("\n"):
			var cut := String(line).find("#")
			stripped += (String(line) if cut < 0 else String(line).substr(0, cut)) + "\n"
		for name in ["SPEED_STEPS", "speed_mul_of", "speed_slot_count", "SPEED_SLOT_DEFAULT"]:
			if stripped.find(name) >= 0:
				readers.append("%s -> %s" % [path, name])
	t.ok(scanned >= 7, "그 중 rules.gd 를 뺀 %d개를 실제로 읽었다 (자가 점검)" % scanned)
	t.eq(readers.size(), 0,
		"src 안에서 아무도 사다리를 안 읽는다 — 읽는 곳: %s" % str(readers))


## Every `.gd` under `dir`, recursively. Written here rather than borrowed: `net_draw_leaf` has its own
## walker over a FIXED list of five files, and a fixed list is exactly what this check must not use —
## a new `src/` file that read the ladder would be invisible to it.
func _gd_files_under(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if d.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_gd_files_under(dir + "/" + name))
		elif name.ends_with(".gd"):
			out.append(dir + "/" + name)
		name = d.get_next()
	d.list_dir_end()
	return out


## The refusal marks in one captured frame: rings at `REFUSE_MARK_R_PX`, which is deliberately larger
## than `TARGET_RING_R_PX` so a drag candidate ring can never be mistaken for one.
##
## ⚠ **Matched on RADIUS and not on colour.** The drag candidate ring is `COL_LOSE` too whenever the
## tile under the cursor is refused, so a colour match would count it and this row would go green on a
## frame where no mark was ever pushed. The radii differ by 8 px and that gap is what the constant's
## own floor (`>= TARGET_RING_R_PX`) exists to keep.
static func _refusal_marks(fs: FieldSpy) -> Array:
	var out := []
	for raw: Dictionary in fs.rings:
		if absf(float(raw["radius"]) - Look.REFUSE_MARK_R_PX) <= 0.01:
			out.append(raw)
	return out
