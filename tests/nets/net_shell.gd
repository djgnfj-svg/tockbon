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
## makes the outcome hold (`combat-juice`, item "승패 전환") measurable at all: at a
## headless 6.9 ms a frame, waiting 0.8 s out through the tree would be 116 frames of guessing.
##
## Two mutations must redden this net: deleting one `add_child` in `_ready`, and making a `look.gd`
## layout function return a bare `Rect2()`. The second is why every captured rectangle is checked for
## AREA as well as for landing inside the viewport — an empty rect sits at the origin and is "inside"
## a 1280x720 screen quite happily.


## ⚠⚠ **`FieldSpy` IS DELETED WHOLE — the field has no `_paint_*` hooks to override any more.** The
## thirteen leaves it captured died with the flat board (the 3D move), and a spy class whose `_draw`
## called `super()` into a parent with no `_draw` was the parse failure that made this net VANISH
## for a whole round — 490 checks reported as nothing at all.
##
## What replaces the captures is the REAL `FieldView`, read on the two surfaces the plan on ticket
## 09 names:
##   surface 2 — the pooled nodes: `_sprites` / `_hulls` up to `_sprites_used` / `_hulls_used`,
##               with position · scale · modulate · texture · visible. The engine draws exactly
##               these fields, so they are the 3D leaf the way a `draw_*` argument was the 2D one.
##   surface 3 — the effect buffers `_g_v`/`_g_c` (ground) and `_a_v`/`_a_c` (air) after `_process`,
##               plus `_decal`/`_air`'s `mesh.get_surface_count()` — the buffers say "geometry was
##               built", the surface count says "it was committed", and only the pair closes the
##               hole where deleting `_fx_flush` stays green.
##
## ⚠ **The `_seq` layer contract died with the hooks and is NOT re-invented**: between 3D objects
## the depth buffer decides what covers what, so there is no traversal order left to measure. The
## HUD / panel / reward spies below are 2D views and keep their hooks and their `_seq`.
##
## ⚠ **Fresh `FieldView` instances are still swapped in before `_open_island()`** — a fresh view
## starts with a null `battle`, so a deleted `field_view.setup(...)` wiring line still leaves every
## surface-2 read below empty rather than merely different.


## ⚠ **`_paint_berth` / `_paint_load` / `_paint_key` are GONE**, deleted with the berths and the 1/2
## keys (`plan-then-watch`, 결정 14R). ⚠⚠ **And the five speed chips are gone too**
## (`speed-off-open-landing`, item 1), so `_paint_button` has exactly ONE call site left: the start
## button. The array stays an array because the hook is still a hook.
## ⚠ `_paint_timer` is GONE from `HudView` with the countdown it drew — nothing loses by the clock
## any more — so the spy stops overriding it: an override of a hook that no longer exists is a dead
## method that reads as coverage.
class HudSpy extends HudView:
	var draws := 0
	var seq := 0
	var buttons := []
	var enemies := []

	func _draw() -> void:
		buttons.clear()
		enemies.clear()
		seq = 0
		super()
		draws += 1

	func _bump() -> int:
		seq += 1
		return seq - 1

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


## ⚠ **`_start_button` stood here and it is deleted** (2026-08-29) with the start button. It matched
## by SIZE rather than by an exact rect, because the refusal shake moves the position and an exact
## compare stops finding the button on the one frame this net cared most about.


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

	func _paint_button(face: Font, rect: Rect2, bg: Color, text: String, at: Vector2, fsize: int,
			col: Color) -> void:
		buttons.append({"seq": _bump(), "face": face, "rect": rect, "bg": bg, "text": text,
			"at": at, "fsize": fsize, "col": col})


## ⚠⚠ **`RewardSpy` STOOD HERE AND IS DELETED** (2026-08-28) with the card screen it watched. What
## it measured was whether the SCREEN was genuinely rebound on a second win — `bind()` zeroing
## `_reveal_age` and clearing `_taken_age` — and there is no second screen to rebind.


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

	t.root.add_child(game)
	await t.pump_frames(2)

	# -- _ready built the children, in code --------------------------------------------------------
	# ⚠⚠ **IT WAS SIX AND IT IS FOUR** (2026-08-28, the user: 「고르는 창도 이제 필요 없는데 왜있지?
	# 이것도 제거」 · 「둘 다 지우면 돼」). The card screen and the refit board were deleted with the
	# whole growth loop; the map view went before them (2026-08-26).
	t.eq(game.get_child_count(), 4, "_ready 가 자식 넷을 만들었다 — 카드 화면과 정비 화면이 삭제됐다")
	t.ok(game.field_view != null and game.hud_view != null and game.title_view != null
		and game.panel_view != null, "네 뷰가 전부 생겼다")
	t.ok(game.get_child(0) == game.field_view and game.get_child(1) == game.hud_view
		and game.get_child(2) == game.title_view and game.get_child(3) == game.panel_view,
		"자식 순서가 field -> hud -> title -> panel 이다 (Node2D 형제의 그리기 순서가 곧 이 순서다)")
	# Named by hand, because `get_class()` on all four is "Node2D" and four identical labels do not
	# say which one went missing — a failure log that cannot narrow the cause is half a failure log.
	var built := {"field_view": game.field_view, "hud_view": game.hud_view,
		"title_view": game.title_view, "panel_view": game.panel_view}
	for label: String in built:
		var v: Node2D = built[label]
		t.ok(v.is_inside_tree(), "%s 가 트리에 붙어 있다" % label)
		t.ok(v.get_parent() == game, "%s 의 부모가 Game 이다" % label)
		t.ok(v.visible, "%s 가 visible 이다" % label)

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
	# ⚠⚠ 「시작하기는 곧장 섬을 연다」 (티켓 12, 2026-08-27, the user: ***"Starting means the game starts,
	# right then."***) — floor: `state() == BATTLE`; ceiling: `battle != null`. **It opened the three
	# cards until that ticket and the map before that**, and on 2026-08-28 the cards were deleted
	# outright (the user: 「둘 다 지우면 돼」) — so there is nothing left between the press and the island
	# at either end of the run.
	game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
	t.ok(game.run != null, "시작하기를 누르면 런이 생긴다")
	t.eq(game.run.state(), Run.State.BATTLE, "그리고 곧장 섬이 열린다 — 사이에 카드도 정비도 없다")
	t.ok(game.battle != null, "섬이 실제로 서 있다")
	# ⚠⚠ **The SCREEN, not only the state.** The title used to come down inside `_enter_pick_screen`,
	# a screen the start path no longer walks through — left there, the island would open UNDER a drawn
	# title and a state check alone would have been green with nothing readable on the glass.
	t.ok(not game.title_view.visible, "그리고 타이틀이 섬 위에 안 남는다")
	# ⚠⚠ **THE 「REGISTER EVERY REMAINING SPECIES」 FIXTURE IS DELETED** (2026-08-27). It filled every
	# summon slot up front so that no LATER card in this whole walk could be a beast, because a beast
	# pick would both skip the refit screen the walks below assert and add `SPECIES_CARD_BODIES` bodies
	# to counts that are naming reward amounts. **There is no beast card left to guard against.**
	# ⚠ **Deleting it moves no number, which is why it is a deletion and not a rewrite**: the player
	# side is one row (검사), `add_starting_force` has already registered it, and `register_species`
	# refused every call in that loop as a duplicate — the slot count was 1 with it and is 1 without it.
	t.eq(game.quits, 1, "시작하기가 종료를 부르지도 않았다")
	t.eq(game.title_view._press_slot, TitleView.SLOT_START,
		"시작하기도 눌린 그림이 들어갔다 — 두 살아 있는 칸 다 확인한다")
	t.ok(game.title_view._press_of(TitleView.SLOT_START) > 0.0, "그 칸의 눌림도 0보다 크다")
	t.ok(not game.title_view.visible, "타이틀은 내려갔다")
	t.ok(not game.panel_view.panel_active(), "섬에서는 패널이 안 뜬다")

	# 「지도에서 칸을 누르면 섬이 열린다」 — and the ring walks first. `_process(dt)` is called by hand
	# because a headless frame is 6.9 ms and 0.45 s would be 66 frames of guessing.
	t.ok(not game._panning, "지도를 누르기 전에는 카메라를 안 끌고 있다 (자가 점검)")

	# -- swap in the spies and re-open the island --------------------------------------------------
	# ⚠ **`reward_view` used to be swapped in here too**, early, so item 4 could tell 「rebound」 from
	# 「never bound」 on the second card screen. Both the screen and that row are deleted (2026-08-28).
	for v: Node2D in [game.field_view, game.hud_view, game.panel_view]:
		game.remove_child(v)
		v.queue_free()
	# ⚠ The field is a FRESH REAL `FieldView`, not a spy — there are no hooks left to spy on, and a
	# fresh instance still proves the wiring: its `battle` is null until `_open_island` runs setup.
	var fs := FieldView.new()
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
	# ⚠⚠ **THIS PROBE ASKED FOR A BEACH AND IT ASKS FOR WATER NOW.** It walked `passable` for a tile
	# `grid.home_harbour_for` answered on and then `Battle.send` a boat there; **the drag, `send` and
	# the whole harbour system behind them are deleted** (2026-08-27). ⚠ **The SUBJECT was never the
	# harbour** — it is the shell driving the clock, and a boat on the board is only how a `commit()`
	# becomes legal at all, so this is re-aimed rather than dropped.
	# ⚠ **This summoned one body onto a boat and pressed 시작; the boats went 2026-08-29.** The island
	# is committed directly now — the commit is what the clock is behind, and it is what this row is
	# actually about.
	t.ok(game.battle.commit(), "섬을 확정했다 (자가 점검)")
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
	# The field has no `_draw` — its frame work is `_process` filling the sprite pool, so a populated
	# pool is what "it really ran on the tree" reads as now.
	t.ok(fs._sprites_used > 0, "field_view 의 _process 가 트리 위에서 진짜 돌았다 (스프라이트 %d장)" % fs._sprites_used)
	t.ok(hs.draws >= 1, "hud_view 의 _draw 가 진짜 돌았다 (%d프레임)" % hs.draws)
	t.ok(ps.draws >= 1, "panel_view 의 _draw 가 진짜 돌았다 (%d프레임)" % ps.draws)

	# A FRESH island for everything below: `run.begin_island()` builds a new `Battle` every call, so
	# re-opening puts the shell back in the planning state the rest of this file measures. The commit
	# above was a probe, not the state under test.
	game._open_island()
	await t.pump_frames(2)
	t.ok(not game.battle.committed(), "다시 연 섬은 계획 상태다 (자가 점검)")

	# From here the sim is frozen, so a captured frame and a value read after it are the same instant.
	game.set_process(false)
	await t.pump_frames(2)
	var b: Battle = game.battle
	# The three views keep processing — only the SHELL stopped — so they drain `battle.events` every
	# frame from here on. That is only safe because the list is empty: a leftover event would be
	# re-drained on every pumped frame and the same blow would flash, shake and lunge forever.
	t.eq(b.events.size(), 0, "얼린 시점에 사건 목록이 비어 있다 — 뷰가 같은 사건을 매 프레임 다시 퍼가고 있지 않다")

	# -- ⚠⚠ THE 2D TERRAIN PASS IS DELETED, ROWS AND ALL ------------------------------------------
	# What stood here: the per-tile capture — the 4408-tile culled span against the 5120-tile margin
	# ring, row-major rect positions, the margin painted COL_WATER, the legend colour of tile (0,0),
	# the grid-line width, and the painted-area-covers-the-visible-world floor. **Every one of those
	# subjects is gone**: the island is ONE mesh built once per island (`_rebuild_terrain`), the open
	# sea is one shaded quad, there are no per-tile rects, no cull, and no grid lines at all.
	# Deleted rather than rewritten onto the mesh, because a vertex census of the terrain would be a
	# second copy of the mesh builder — what survives as a floor is that the mesh EXISTS and holds
	# real faces, and `verify-look` is what judges the picture (it already did: the user called the
	# 3D screen done).
	t.ok(fs._terrain != null and fs._terrain.mesh != null, "지형 메시 노드가 있다 (자가 점검)")
	t.ok(fs._terrain.mesh.get_surface_count() >= 1, "지형 메시가 실제로 커밋돼 있다")
	t.ok(fs._terrain.mesh.get_faces().size() >= 1000,
		"그리고 면이 실제로 들어 있다 (%d 정점) — 빈 섬이 아니다" % fs._terrain.mesh.get_faces().size())
	t.ok(fs._sea != null and fs._sea.visible, "열린 바다 판이 그 밑에 있다")

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
	t.eq(fs._hulls_used, 0, "커밋 전에는 선체가 하나도 없다 — 배는 눌러야 생긴다")
	# The island opens at the SURVEY zoom: on 26 x 20 that is `1280 / (26 * 40 * 1.40)` = **0.87912**.
	# Hand arithmetic; `net_camera` owns the rest.
	# ⚠⚠ **THIS ROW USED TO ASSERT `ZOOM_MAX` AND THAT WAS THE COMPLAINT, WRITTEN DOWN AS A CHECK**
	# (2026-08-25, the user: 「처음 시작할떄 가메라 좀더 뒤에서 시작할 수 있게해줘」). At the old margin
	# the survey wanted 1.07 on this island and the wheel's ceiling took it — **so the opening view was
	# not the survey's answer, it was a clamp**, and no margin could move it. Raising `SURVEY_MARGIN`
	# past `1280 / (26 * 40)` = 1.231 is what gave the derivation its say back.
	t.ok(absf(fs.zoom - 0.87912) < 0.001,
		"소형 첫 섬은 서베이 값 0.87912 로 열린다 — 천장에 안 걸린다 (얻은 값 %.5f)" % fs.zoom)
	t.ok(fs.zoom < Look.ZOOM_MAX - 0.01,
		"자가 점검 — 그 값이 ZOOM_MAX 가 아니다: 걸리면 여백 상수가 아무 일도 못 한다")

	# ⚠ **The cliff-face rows are DELETED, subject and all.** `_paint_cliff_face` drew a line along
	# every seaward cliff edge because a flat canvas had no other way to say "tall"; the cliff is a
	# real 2.4-tile wall in the terrain mesh now, told from land by its own lit faces and its shadow.
	# A rewritten row would census the mesh builder against itself; the wall's look is verify-look's.

	# -- the bodies, read off SURFACE 2: the pooled nodes the engine draws --------------------------
	# The comparison still runs from what `battle` holds to what reaches the engine — position,
	# picture, tint and size are node FIELDS now instead of hook arguments, and the engine consumes
	# exactly those fields.
	var live_enemies := []
	for e in b.enemy_alive.size():
		if b.enemy_alive[e] != 0:
			live_enemies.append(e)
	t.ok(live_enemies.size() > 0, "섬 0에 살아 있는 적이 있다 (%d마리)" % live_enemies.size())
	t.eq(b.ashore_ids().size(), 0, "아직 상륙한 병사는 없다")
	var bodies := _body_sprites(fs)
	t.eq(bodies.size(), live_enemies.size(),
		"몸 스프라이트 수 = 살아 있는 적 수 — 상륙 전에는 적 말고 아무 몸도 없다")
	var body_bad := 0
	for k in live_enemies.size():
		var e: int = live_enemies[k]
		var et := int(b.enemy_type[e])
		var s := _sprite_at_xz(bodies, Look.tile_point_px(b.enemy_pos[e]))
		if s == null:
			body_bad += 1
			continue
		# A textured body wears `beast_tint(side colour)`; the bare rounded square wears the colour
		# raw — the same fork `_put_body` takes, read back off the one modulate the engine applies.
		var textured := s.texture != fs._tex_body
		var want_mod := Look.beast_tint(Look.body_colour_of(true)) if textured \
			else Look.body_colour_of(true)
		if s.modulate != want_mod:
			body_bad += 1
			continue
		# The size really is the type's own radius through the sprite-width ratio.
		var want_sx := Look.body_radius_of(et) * Look.BEAST_SPRITE_W_RATIO / float(s.texture.get_width()) \
			if textured else Look.body_radius_of(et) * 2.0 / float(s.texture.get_width())
		if absf(s.scale.x - want_sx) > 0.001:
			body_bad += 1
	t.eq(body_bad, 0, "몸마다 자리·색·크기가 sim 의 그 적에게서 나왔다")
	# ⚠⚠ **THE HP BAR ROWS ARE DELETED** (2026-08-28, the user: 「체력바 없이」). They read the two flat
	# sprites per body — rail and fill — and their two colours. **`_put_hp`, `_hp_rects` and
	# `Look.hp_bar_*` are all gone**; the sim still tracks HP and nothing on screen says so.
	t.eq(_flat_sprites(fs).size(), 0, "몸 위에 막대가 한 장도 안 붙는다 — 체력바가 삭제됐다")
	# ⚠⚠ **THE GROUND BUFFER IS NO LONGER SILENT AND THAT IS THE SHADOW** (2026-08-28, the user:
	# 「그림자도 단순하게 아래 동그라미정도해줘」). Every body lays one disc down, so the floor here is a
	# COUNT rather than a zero: nothing has been hit and nothing has died, so the only ground geometry
	# in the frame is one disc per body. The AIR buffer is still silent, and that half is unchanged.
	t.eq(fs._a_v.size(), 0, "아무 일도 안 일어난 프레임에는 공중 연출 정점이 하나도 없다")
	t.ok(fs._g_v.size() > 0, "바닥에는 정점이 있다 — 몸마다 그림자 원 하나 (%d 정점)" % fs._g_v.size())
	var shadow_verts := 0
	for c: Color in fs._g_c:
		if c == Look.COL_BODY_SHADOW:
			shadow_verts += 1
	t.eq(shadow_verts, fs._g_c.size(),
		"그리고 그 정점이 전부 그림자 색이다 — 조준도 의도선도 없는 프레임이다")
	t.ok(fs._decal.mesh.get_surface_count() > 0, "바닥 연출 메시가 실제로 커밋됐다 — 버퍼만 찬 게 아니다")
	t.eq(fs._air.mesh.get_surface_count(), 0, "공중 연출 메시는 비어 있다")

	# ⚠ **The `_seq` layer-order rows are DELETED, subject and all.** Between 3D objects the depth
	# buffer decides what covers what — there is no traversal order left to measure, and re-inventing
	# one would measure the fixture. (`field_view._paint_bodies`' own comment records where the old
	# enemies-then-allies rule went.)

	# -- ⚠⚠ THE WHOLE PLANNING PATH IS DELETED — ~360 LINES, SUBJECT AND ALL ------------------------
	# What stood here (2026-08-29): the HUD's one start button read off the paint hook, every HUD
	# rectangle held to the viewport it is laid out in, item 8's refusal shake with both ends of its
	# amplitude pinned, ten summons filling the roster onto two beaches, the commit that made them all
	# depart on one frame, the remaining route line under a crossing hull, the clock proving the shell
	# hands `Battle.step` a real delta, and every press refused after the commit.
	#
	# **All of it measured a screen and a gesture that no longer exist.** The HUD draws nothing, the
	# summon gesture went 2026-08-28, and the boats went with `grid`'s water half. **What the rows
	# knew that outlives them:**
	#
	#  · **The shake's amplitude was pinned at BOTH ends.** A floor alone stays green while the
	#    amplitude runs away, and this net was the constant's only reader.
	#  · **The label moved with the box, to a 0.01 px tolerance.** Shaking the box alone leaves the
	#    glyph at exactly 0 — an exact `==` on two sums of the same floats is the wrong instrument.
	#  · **Every press went in as an `InputEventMouseButton` handed to `_unhandled_input`**, never
	#    `root.push_input` — the 64x64 headless window's 0.05 stretch sends a click thousands of px
	#    away, silently.
	#  · **The clock row is the one to rebuild first.** It caught the shell not handing `step` a delta,
	#    and nothing measures that today.

	# -- the camera, through the shell's own input path -----------------------------------------------
	# The wheel zooms about the cursor; a left press on the FIELD (never the panel, which is not up
	# here) begins a pan, motion moves it, release ends it. Docks are gone, so this replaces the old
	# "dock click corrected by the shake" item 11 — the shake still folds into the SAME expression
	# (`field_view._place_camera`), and `net_camera` is what pins that directly.
	var before_zoom := fs.zoom
	for _n in 8:
		game._unhandled_input(_wheel(Vector2(640.0, 360.0), true))
	t.ok(fs.zoom > before_zoom, "휠을 올리면 확대된다")
	t.eq(fs.zoom, Look.ZOOM_MAX, "계속 올리면 ZOOM_MAX 에서 멈춘다 — 8번이면 이미 넘친다 (바닥)")

	# ⚠ **A drag can never MOVE the camera on this island, and that is the framing, not a defect**:
	# 26 x 20 is 1040 x 800 px against a 1280 x 1120.12 px view at the wheel's own ceiling, so
	# `_clamp_cam` centres both axes at every reachable zoom. What a drag still proves is that the
	# input path runs — `pan_by` ends in the clamp, so a camera parked OFF the centred point snaps
	# back to it the moment a drag delivers one motion. The centred literal, by hand:
	# ((1040 - 1280) / 2, (800 - 1120.12) / 2) = **(-120.00, -160.06)**.
	# ⚠ The y half moved on 2026-08-25 when the pitch divisor was corrected from cosine to sine; it
	# read -69.95, which was the wrong span reaching the clamp.
	fs.cam_px = Vector2(300.0, 300.0)
	game._unhandled_input(_press(Vector2(640.0, 360.0)))
	game._unhandled_input(_motion(Vector2(640.0, 360.0), Vector2(40.0, 40.0)))
	t.ok(fs.cam_px.distance_to(Vector2(-120.0, -160.06)) < 0.1,
		"필드를 눌러 끌면 pan_by 가 실제로 돈다 — 소형 섬이라 클램프가 가운데 (-120.00, -160.06) 로 붙든다 (%.2f, %.2f)"
			% [fs.cam_px.x, fs.cam_px.y])
	game._unhandled_input(_release(Vector2(680.0, 400.0)))

	fs.cam_px = Vector2(300.0, 300.0)
	game._unhandled_input(_motion(Vector2(680.0, 400.0), Vector2(40.0, 40.0)))
	t.eq(fs.cam_px, Vector2(300.0, 300.0),
		"손을 뗀 뒤의 움직임은 카메라를 안 끈다 — pan_by 가 불렸다면 클램프가 자리를 옮겼을 것이다")

	# ⚠⚠ **ITEM 4'S WHOLE FIXTURE AND ITS FOUR ROWS ARE DELETED** (2026-08-28) with the card screen.
	# They measured that a SECOND win rebound the screen fresh — `_reveal_age` back near zero, no
	# `_taken_age` marks left from the first round, three cards drawn again. **There is no card screen
	# and a win goes straight to `WON`.**

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
	# ⚠ **The row that held this rect apart from `Look.start_rect_px()` is deleted with that rect**
	# (2026-08-29). The rule it enforced stands: **one rectangle answering to two verbs is how a restart
	# gets pressed by someone aiming at start**, and `panel_view.button_hit` owns this one alone.
	var button_rects: Array[Rect2] = []
	for it: Dictionary in ps.buttons:
		button_rects.append(it["rect"])
	_rects_land_on_screen(t, "패배 패널", button_rects)

	t.root.remove_child(game)
	game.queue_free()

	_panel_active_answers_all_five_screens(t)
	await _one_press_reaches_the_first_island(t)
	_the_speed_ladder_is_gone(t)
	_speed_steps_survives_read_by_nobody(t)
	_every_lose_reason_reads_differently(t)




## Presses a map node the way a hand does — through `_unhandled_input`, then the ring's walk run out
## by hand. `game.set_process(false)` is in force by the time this is called, so the hold would never
## expire on its own; a headless frame is 6.9 ms and `MAP_TRAVEL_SEC` would be 66 frames of guessing
## even if it did.
## Wins whatever island is open, through the shell's own frames rather than by poking `Run`.
##
## ⚠ **The island has to be COMMITTED first.** An uncommitted `Battle` is inert to every driver
## (`plan-then-watch`, 4.3) — `step` returns before `_phase_clock`, so an emptied `enemy_alive` would
## never be latched at all and the hold below would wait forever on a verdict that never comes.
func _win_the_open_island(t, game: Game, label: String) -> void:
	# ⚠⚠ **RE-AIMED TWICE, SAME SUBJECT.** It walked `passable` for a tile `home_harbour_for` answered
	# on and sent a boat there; then it summoned one onto the water inside the band. **Both gestures are
	# deleted.** What this helper is for has not moved: the island only needs to be COMMITTED so the
	# hold below has a verdict to wait on.
	t.ok(game.battle.commit(), "%s 섬을 확정했다 (자가 점검)" % label)
	game.battle.enemy_alive.fill(0)
	# ⚠ **Two whole sub-steps, never 0.016.** `step` consumes whole `Rules.SIM_SUBSTEP_SEC` chunks and
	# carries the leftover, and 0.016 is a hair UNDER 1/60 — on a fresh island with no leftover banked
	# it runs zero sub-steps, latches nothing, and the hold below waits forever on a verdict that never
	# comes. Measured: this row read RUNNING with the enemies already emptied.
	game._process(Rules.SIM_SUBSTEP_SEC * 2.0)
	t.eq(game.battle.outcome(), Battle.Outcome.WON, "%s 섬을 이겼다" % label)
	t.eq(game._hold_sec, Look.HOLD_OUTCOME_SEC, "그리고 셸이 마지막 파열 링만큼 붙들었다")
	game._process(Look.HOLD_OUTCOME_SEC)


## ⚠⚠ **`_take_one_and_close_refit` STOOD HERE AND IS DELETED** (2026-08-28) with the card round it
## drove. It took one item card and closed the refit board so a fixture could reach `WON`; a win
## goes straight there now.
func _panel_active_answers_all_five_screens(t) -> void:
	var game := QuitGame.new()
	t.root.add_child(game)
	var pv := game.panel_view
	t.ok(pv != null, "패널 뷰가 생겼다 (자가 점검)")

	# Title: `run` is null and the first clause answers.
	pv.bind(null, null)
	t.ok(not pv.panel_active(), "타이틀에서는 패널이 안 뜬다 (run == null)")

	# ⚠ **A win goes straight to `WON` now** (2026-08-28) — it used to stop for a card round and a
	# refit board on the way, and both are deleted.
	var won := Run.new()
	won.begin_island()
	won.finish_island(true)
	t.eq(won.state(), Run.State.WON, "섬을 지켜내면 WON 이다 (자가 점검)")
	pv.bind(won, null)
	t.ok(pv.panel_active(), "이긴 화면에서도 패널이 뜬다")

	t.root.remove_child(game)
	game.queue_free()


## **The acceptance row 「타이틀은 마찰이 아니다」, as a count.** From launch to the island the design
## says **one press — 시작하기 — and more than one is a failure** (티켓 12). Counted by driving a fresh
## shell and incrementing on every event actually handed to `_unhandled_input`, so a screen that grows
## a confirmation step reddens here rather than in somebody's memory of it.
##
## ⚠⚠ **THE COUNT HAS FALLEN THREE TIMES AND THE CEILING FELL WITH IT.** Three presses while the map
## node was the last step (deleted 2026-08-26), two while the opening card round was (taken off the
## start path 2026-08-27), one now. ⚠ **The ceiling is the whole point of the row**: leaving it at
## three would let both deleted screens be put back with this fixture still green.
func _one_press_reaches_the_first_island(t) -> void:
	var game := QuitGame.new()
	t.root.add_child(game)
	await t.pump_frames(2)
	game.set_process(false)
	await t.pump_frames(1)
	game.set_process(false)

	var presses := 0
	game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
	presses += 1

	t.ok(game.battle != null, "누름 %d번 만에 첫 섬이 열렸다" % presses)
	t.eq(presses, 1, "그 수가 정확히 하나다 — 시작하기, 그것뿐이다")
	t.ok(presses >= 1, "그리고 0이면 켜자마자 섬이 나온다는 뜻이다 — 타이틀 자체가 없어진 것이다")

	t.root.remove_child(game)
	game.queue_free()




## -- surface-2 readers: the pooled nodes the engine draws --------------------------------------------

## The first `_sprites_used` pooled sprites — exactly what this frame put on screen. Reading past
## that index would count hidden leftovers from a busier frame as live bodies.
func _used_sprites(fv: FieldView) -> Array:
	var out := []
	for k in fv._sprites_used:
		out.append(fv._sprites[k])
	return out


## The BODY sprites: everything that is not wearing the one-texel bar texture.
func _body_sprites(fv: FieldView) -> Array:
	var out := []
	for s: Sprite3D in _used_sprites(fv):
		if s.texture != fv._tex_flat:
			out.append(s)
	return out


## The HP-bar sprites — the flat one-texel texture, scaled into rails and fills.
func _flat_sprites(fv: FieldView) -> Array:
	var out := []
	for s: Sprite3D in _used_sprites(fv):
		if s.texture == fv._tex_flat:
			out.append(s)
	return out


## The sprite standing at a world-px point, matched on the ground plane (x, z) — a body's height is
## its own business (it depends on the picture's aspect), the tile it stands on is the sim's.
func _sprite_at_xz(list: Array, world_px: Vector2) -> Sprite3D:
	for s: Sprite3D in list:
		if absf(s.position.x - world_px.x / Look.TILE_PX) < 0.001 \
				and absf(s.position.z - world_px.y / Look.TILE_PX) < 0.001:
			return s
	return null


## The inverse of `screen_to_world_px`, for aiming a press at a world point — the flat board's "park
## at zoom 1 and screen == world" died with the pitch. Written once here; `net_camera` is what pins
## the forward conversion this inverts, so the pair cannot both be wrong the same way.
## ⚠ **`ground_h` is not optional in practice and the default is a trap kept deliberately at 0**: a
## world point on LAND stands a tile or more up, and a press aimed with the flat inverse lands a tile
## or two behind the thing it meant (2026-08-25). The one caller passes the tile's own ground height,
## which is what `field_view.screen_to_terrain_px` will answer with.
func _screen_of(fv: FieldView, world: Vector2, ground_h: float = 0.0) -> Vector2:
	var span: Vector2 = fv._visible_ground_px()
	var rel := world - fv._ground_centre_px()
	rel -= fv._ground_down() * (ground_h * Look.TILE_PX / tan(deg_to_rad(fv.cam_pitch_deg)))
	var u := rel.dot(fv._ground_right()) / span.x
	var v := rel.dot(fv._ground_down()) / span.y
	return Vector2((u + 0.5) * Look.VIEWPORT_W_PX, (v + 0.5) * Look.VIEWPORT_H_PX)


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


func _wheel(at: Vector2, up: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	ev.position = at
	return ev


## ⚠⚠ **`_count_set` IS DELETED AND THIS BLOCK IS ITS RECORD.** It counted the non-zero bytes of a
## `PackedByteArray`, and it existed for exactly one claim: 「the droppable union is WIDER than any one
## harbour's own reach」 — the row that kept `Grid.sendable`'s union from being a rename of one
## harbour's field. **`sendable` and every harbour table are deleted** (2026-08-27) and that row went
## with the drag, which left this helper with no caller but its own two reader-checks below.
##
## ⚠ **A helper whose only reader is its own self-test is a fake green of the exact shape this repo
## has just found twice** — it reports two more passing rows and measures nothing that ships. Deleted
## rather than kept "in case", because the thing it counted has no successor: a summon has no harbour
## to be wider than, and the band is held to its own floor AND ceiling in `net_summon` instead.


# -- the readers themselves, inverted -----------------------------------------------------------------



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
	# ⚠ **This was the self-check arm, and it FLIPPED on 2026-08-29** — `start_rect_px` went with the
	# HUD. The self-check moved to a method that is still there, so the row still proves it is reading
	# a real method list rather than an empty one.
	t.ok(not look_methods.has("start_rect_px"), "look.gd 에 start_rect_px 도 없다 — HUD 와 같이 나갔다")
	t.ok(look_methods.has("button_rect_px"), "button_rect_px 는 그대로 있다 (자가 점검)")

	var hud_consts: Dictionary = hv.get_script().get_script_constant_map()
	t.ok(not hud_consts.has("SPEED_LABELS"), "hud_view 에 SPEED_LABELS 가 없다")
	# ⚠ **TYPE_LABELS 도 없다** — 짐승 이름이 `Rules.UNITS` 의 칸이 되면서 두 번째 표가 통째로 사라졌다.
	t.ok(not hud_consts.has("TYPE_LABELS"), "hud_view 에 TYPE_LABELS 도 없다 — 이름은 표의 칸이다")
	# ⚠ **`CHIP_SLOT_BASE` was the self-check here and it is gone too** (2026-08-29) — `hud_view` holds
	# no constants at all now, so the arm that proved this row reads a real map has nothing to name.

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
func _every_lose_reason_reads_differently(t) -> void:
	var r := Run.new()
	var b := r.begin_island()
	r.finish_island(false)
	t.eq(r.state(), Run.State.LOST, "진 런을 하나 만들었다 (자가 점검)")

	var pv := PanelView.new()
	pv.bind(r, b)
	t.ok(pv.is_finished(), "끝난 화면이다 — 패배 문구 가지를 탄다 (자가 점검)")
	# ⚠ **`Look.COL_BUTTON`'s literal moved here** (2026-08-25) from the deleted reward-panel block:
	# a panel really is on screen in this test, and the constant otherwise loses its only comparison.
	# **The literal first, then the reach** — comparing the capture against the constant alone reads it
	# on both sides and stays green with the constant set to red.
	t.eq(Look.COL_BUTTON, Color(0.239, 0.341, 0.459), "COL_BUTTON 이 리터럴 그 색이다")

	var lose_enum: Dictionary = Battle.new().get_script().get_script_constant_map()["Lose"]
	# ⚠ **Four became three on 2026-08-27**: `TIMEOUT` and its 「패배 — 시간 초과」 were deleted together,
	# because nothing had been able to produce that defeat since 2026-08-24.
	t.eq(lose_enum.size(), 3, "패인은 셋이다 (NONE · WIPED · LANDING_LOST)")
	var want := {
		"NONE": PanelView.MSG_LOST,
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


## ⚠ `_refusal_marks` is deleted with the ring capture it filtered — `net_slots` counts refusals off
## `field_view._fx` directly, which never depended on a hook.


