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
	# ⚠⚠ **The two verbs take different KINDS of tile**: `send` took a beach, `summon` takes WATER
	# inside the band and answers -1 to anything else. Handing it a beach reddens this row for a reason
	# that has nothing to do with the shell — it cost one red round once, and the helper's name is what
	# stops it a second time.
	var probe_tile := _summonable_water_on(game.battle)
	t.ok(probe_tile >= 0, "소환 띠 안의 물 칸을 찾았다 (자가 점검 — 못 찾으면 아래가 전부 공허하다)")
	t.ok(game.battle.summon(0, probe_tile) >= 0 and game.battle.commit(),
		"한 명을 불러내고 확정했다 (자가 점검)")
	t.eq(game.battle.boats.size(), 1, "그리고 배가 실제로 한 척 떠 있다 (바닥 — 빈 판이면 시계가 안 간다)")
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
	t.eq(game.battle.boats.size(), 0, "그리고 계획이 비어 있다 (자가 점검)")

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

	# -- the HUD, and the number on it coming from the sim -----------------------------------------
	# ⚠ **The timer rows are DELETED with the countdown** — nothing loses by the clock any more, so
	# `HudView` stopped drawing it and `_paint_timer` is gone. The planning HUD is the start button,
	# the slot row and the enemy count.

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
	# ⚠ **The counted glyph budget, re-counted when the countdown died**: it was 3 (timer + start +
	# enemy) and the timer went with the rule it counted to — **2 text items on the planning
	# screen**. Recorded here so it cannot drift back up without somebody editing this number.
	t.eq(hs.buttons.size() + hs.enemies.size(), 2,
		"계획 화면의 글자 항목은 둘이다 (시작 1 + 적 1) — 시계는 지는 규칙과 함께 죽었다")
	t.ok(int(start_btn["seq"]) < int(hs.enemies[0]["seq"]),
		"HUD 는 시작 버튼 -> 남은 적 순서로 그린다")

	# **The resting look of the start button**, captured before any press. Item 8's whole content is
	# the DIFFERENCE from this, so it has to be read once while nothing has happened yet.
	var rest_key_rect: Rect2 = start_btn["rect"]
	var rest_key_at: Vector2 = start_btn["at"]

	# -- every rectangle that reached a hook has area, and lands where its own space says it should ---
	# ⚠ **The field half of this check is DELETED with its rects** — the field hands the engine 3D
	# node fields, not rectangles, and the world-bound it was held to died with the canvas. The HUD
	# half survives: `hud_view` is still a 2D layer in viewport coordinates.
	var hud_rects: Array[Rect2] = []
	for it: Dictionary in hs.buttons:
		hud_rects.append(it["rect"])
	_rects_land_on_screen(t, "전투 화면 — HUD", hud_rects)

	# ⚠ The drag's own tile picks (`sendable_tile` / `second_tile` / `refuse_tile`) went with the drag.
	# What the rows below still need is picked from the SUMMON band, further down.
	# ⚠ The inland-refusal fixture went with the drag's release, which is what marked a refusal there.

	# ⚠⚠ **초록색 해안이 사라졌다.** The wash used to be drawn from the moment the island opened and
	# the user asked for its inverse (「못내림만 표시하면 됨 ㅇㅇ」). The hook is gone; the tile-pass
	# overpaint rows that used to follow are gone WITH the tile pass itself — the terrain is one mesh
	# built once, so "a second coat per frame" has no per-frame pass left to hide in.
	t.ok(not fs.has_method("_paint_overlay"),
		"타일 덧칠 훅 자체가 없다 — 초록 해안을 그릴 방법이 남아 있지 않다")
	# ⚠ The row comparing `send`'s whole domain with one harbour's reach went with the drag.
	# ⚠⚠ **And `send` itself is now DELETED from the sim** (2026-08-27), with `can_land_at`, `sendable`,
	# `water_route`, `home_harbour_for` and the rest of the harbour tables — it had zero callers in
	# `src/` once the drag went, so the domain that row compared no longer exists to be compared.
	# **What outlives it**: the claim was 「the droppable union is WIDER than any one harbour's reach」,
	# a floor that made the union a claim rather than a rename. A summon has no harbour to be wider
	# than, so the claim has no successor here — the band's own two numbers are what `net_summon`
	# holds to instead, floor and ceiling both.

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
	for slot_i in b.army.slot_count():
		var guard := 0
		while not b.slot_reserve_ids(slot_i).is_empty() and guard < 40:
			t.ok(b.summon(slot_i, tile_a if guard % 2 == 0 else tile_b) >= 0,
				"%d번 슬롯에서 한 명 더 내보냈다 (자가 점검)" % slot_i)
			guard += 1
	await t.pump_frames(1)
	# ⚠⚠ **THE EXPECTATION READ `roster_start_count() + SPECIES_CARD_BODIES` — 10 + 4 = 14 — AND THE
	# `+ 4` IS DELETED WITH THE BEAST CARD** (2026-08-27). Those four bodies arrived on the opening card
	# back when a card could hand a summon slot a species; **an equipment card recruits nobody**, so what
	# stands on the beach is the opening table alone. `START_SLOTS` is one row of ten ⇒ **10 boats**.
	# ⚠ **The ten is not written on the assertion's own side** (it is in the label, where a wrong number
	# reads as a wrong number rather than as a green): `roster_start_count()` sums the table, so an
	# opening table that is re-tuned moves this expectation with it instead of reddening a hand copy.
	t.eq(b.boats.size(), Rules.roster_start_count(),
		"명단 전부(시작 병력 열 명)를 내보낼 수 있다 — 배 수에 상한이 없다")
	t.ok(b.boats.size() > before_fill, "그리고 실제로 늘었다 (자가 점검)")
	var all_transit := 0
	for si5 in b.soldier_state.size():
		if b.soldier_state[si5] == Battle.SoldierState.TRANSIT:
			all_transit += 1
	# ⚠ The same arithmetic as the row above, read off the SOLDIERS instead of the boats. **14 became 10
	# because the four bodies the beast card used to bring with it are gone**, not because anything
	# refused to sail — the boat count one row up is what would catch that.
	t.eq(all_transit, Rules.roster_start_count(), "열 명 전부 배에 탔다")
	t.eq(b.elapsed, 0.0, "열 척을 내보내는 동안에도 시계는 정확히 0이다")

	# -- the start button commits, and the screen changes with it --------------------------------------
	t.root.push_input(_press(Look.start_rect_px().get_center()), true)
	await t.pump_frames(1)
	t.root.push_input(_release(Look.start_rect_px().get_center()), true)
	await t.pump_frames(1)
	t.ok(b.committed(), "시작 버튼이 계획을 확정한다")
	t.eq(_start_button(hs), {}, "확정한 순간 시작 버튼이 화면에서 사라진다 — 못 누르는 단추는 안 그린다")
	var ghost_mod := Look.beast_tint(Look.ghost_tint())
	var ghosts_after := 0
	for sg: Sprite3D in _used_sprites(fs):
		if sg.modulate == ghost_mod:
			ghosts_after += 1
	t.eq(ghosts_after, 0, "유령 색을 입은 몸이 하나도 없다 — 유령은 계획의 것이다")
	t.eq(fs._hulls_used, b.boats.size(), "대신 배마다 선체가 하나씩 그려진다")
	t.ok(fs._hulls[0].visible, "그 선체가 실제로 켜져 있다 (자가 점검)")
	t.eq((fs._hulls[0].material_override as StandardMaterial3D).albedo_color, Look.COL_BOAT,
		"선체 색이 look.gd 값이다 — 기다림 깜박임 전의 쉬는 색")
	# ⚠⚠ **확정 뒤 HUD 에 상자가 하나도 없다.** The start button goes at the commit and the five speed
	# chips no longer exist, so this layer answers no press at all — that is 결정 1 without the escape
	# hatch the chips used to be. The floor for this zero is the `== 1` one section above, measured on
	# the same HUD a few frames earlier.
	t.eq(hs.buttons.size(), 0, "확정 뒤 HUD 에 상자가 하나도 안 남는다")
	t.eq(hs.buttons.size() + hs.enemies.size(), 1,
		"실행 화면의 글자 항목은 하나다 (적 1) — 시계는 지는 규칙과 함께 죽었다")

	# -- ⚠⚠ 항해 중인 배의 「남은 길」 선은 아직 3D 로 안 돌아왔다 — 행도 그와 함께 내린다 -------------
	# The rows that stood here read the drawn polyline against `path.slice(leg + 1)` every 0.05 s of
	# a real crossing. **The picture itself is unported**: `_route_ahead` still computes the
	# remaining route and NOTHING calls it — the aim's route came back with the twelve, the sailing
	# boat's did not. A vanished check is worse than a red one, so the absence is stated here AND on
	# ticket 09 (step 4's fx round owns the revival) instead of the rows being quietly dropped.
	# The sim's own crossing is still advanced so the rows below start from the same state they did.
	for _cn2 in 160:
		game._process(0.05)
		if b.boats.is_empty():
			break
		if int((b.boats[0] as Dictionary)["phase"]) != Battle.Phase.OUTBOUND:
			break
	await t.pump_frames(1)

	# ⚠⚠ **결정 1 as a check.** All three plan branches are gated, and the three of them are pressed.
	var boats_snapshot := b.boats.size()
	# ⚠ The two branches that pressed a BODY and released a held soldier are deleted with the drag.
	# What is left after the commit is the ring undo and the summon, and both are pressed below.
	# ⚠⚠ **The summon's own post-commit gate is `net_slots`' `_after_the_commit`**, which presses a
	# band tile with a slot still armed and reads the boat count AND the refusal count.
	# ⚠ **The gate is on the BRANCH, not on the hit test.** `_ring_hit_at` still answers — it is a pure
	# geometry lookup — so the row that matters is that pressing there changes nothing.
	# ⚠ `second_px` is a WORLD point; the press has to arrive in SCREEN px, and the flat board's
	# "park at zoom 1 and the two coincide" is gone — the pitch stretches the vertical. `_screen_of`
	# is the one inverse this file writes, and `net_camera` is what pins the conversion it inverts.
	# ⚠ The landing ring lies on LAND, so the aim carries that tile's own height — the flat inverse
	# points a tile and a half short of it and the self-check below reddens on the aim rather than on
	# the gate (2026-08-25).
	var second_screen := _screen_of(fs, second_px,
		fs._ground_h(int(second_px.x / Look.TILE_PX), int(second_px.y / Look.TILE_PX)))
	t.ok(game._ring_hit_at(second_screen) >= 0, "고리 자체는 여전히 그 자리에 있다 (자가 점검)")
	t.root.push_input(_press(second_screen), true)
	await t.pump_frames(1)
	t.root.push_input(_release(second_screen), true)
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
	# ⚠⚠ **THE WINDOW IS 30 FRAMES AND IT WAS 6** (2026-08-25). The first island stopped being a
	# rectangle and grew a plateau reached through **one stair tile**, so fourteen bodies queue at that
	# door — measured at up to 9.35 s motionless for a single body. 6 frames is 0.096 s, and a queue
	# that is inching forward moves less than `Rules.EPS` in that time: **the floor row below went red
	# on a sim that was working exactly as designed.** 0.48 s is still far under any queue and still
	# reddens on a genuinely frozen screen.
	# ⚠ **The queue itself is a real complaint and is not fixed here** — 티켓 26 carries it (「줄서기」),
	# and widening this window does not make it smaller. This row was never the one measuring it.
	const MOTION_FRAMES := 30
	# The control arm: the same number of `_process` calls with NO presses at all. Run first, off a
	# snapshot, so the comparison is against a number rather than against a hope.
	var control_elapsed := b.elapsed
	var control_substeps := b.substeps
	for _cn in MOTION_FRAMES:
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
	for _pn in MOTION_FRAMES:
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
	# ⚠ **And it is NOT `Look.start_rect_px()`.** One rect answering to two verbs is how a restart gets
	# pressed by someone aiming at start; `panel_view.button_hit` owns this one.
	t.ok(not Look.button_rect_px().intersects(Look.start_rect_px()),
		"다시 하기 단추와 시작 버튼은 서로 다른 자리다 — 한 사각형이 두 동사를 받지 않는다")
	var button_rects: Array[Rect2] = []
	for it: Dictionary in ps.buttons:
		button_rects.append(it["rect"])
	_rects_land_on_screen(t, "패배 패널", button_rects)

	t.root.remove_child(game)
	game.queue_free()

	_panel_active_answers_all_five_screens(t)
	await _one_press_reaches_the_first_island(t)
	_the_plan_constants_have_both_ends(t)
	_the_readers_themselves(t)
	_the_speed_ladder_is_gone(t)
	_speed_steps_survives_read_by_nobody(t)
	_every_lose_reason_reads_differently(t)


## The first tile on this island's grid that a summon press is allowed on — **WATER inside the band,
## and the name says so on purpose.**
##
## ⚠⚠ **THE TWO VERBS TOOK DIFFERENT KINDS OF TILE AND IT COST A RED ROUND.** The deleted `Battle.send`
## took a BEACH — a passable land tile a boat could unload onto — and every probe in this file used to
## find one by walking `passable` for a tile `grid.home_harbour_for` answered on. `summon` takes water
## and returns -1 for a beach, silently, so a fixture that hands it one reddens a row about the SHELL
## for a reason that is entirely about tiles.
##
## ⚠ **Found on the grid in front of it, never typed.** A tile a net hard-codes is a tile that describes
## one map, and every subject in this file has always been the shell rather than which map is open.
##
## ⚠ Deliberately the SAME shape and the same name as `net_run`'s own helper rather than a clever twin —
## two spellings of one search is how the beach/water confusion comes back.
func _summonable_water_on(b: Battle) -> int:
	var g := b.grid
	for tile in g.w * g.h:
		if g.can_summon_at(tile):
			return tile
	return -1


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
	# ⚠⚠ **RE-AIMED FROM `send` ONTO `summon`, SAME SUBJECT.** This walked `passable` for a tile
	# `grid.home_harbour_for` answered on and sent a boat to it; the harbour half is deleted and
	# `summon` takes WATER inside the band, never a beach (a beach is a silent -1). What this helper
	# is for has not moved: the island only needs to be COMMITTED so the hold below has a verdict to
	# wait on, and one body on one boat is the cheapest legal plan there is.
	var tile := _summonable_water_on(game.battle)
	t.ok(tile >= 0, "%s 섬에서 소환 띠 안의 물 칸을 찾았다 (자가 점검)" % label)
	t.ok(game.battle.summon(0, tile) >= 0 and game.battle.commit(),
		"%s 섬에 한 명 불러내고 시작을 눌렀다 (자가 점검)" % label)
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


## ⚠⚠ **Every constant `plan-then-watch` 6.4 introduced, with the floor AND the ceiling its own row
## wrote down, read back as numbers.** They were derived in a plan and then written into `look.gd` as
## comments, and a comment cannot redden: `GHOST_ALPHA := 0.02` — invisible on screen, which deletes
## the only picture carrying drop order — passed 1262 checks. **A correction pass only checks the row
## someone is arguing about**, so the whole table is here and not the one value that was caught.
##
## ⚠ These are the ROW's bounds, not a restatement of the value. A row asserting `== 0.55` would be
## one fact written twice and would redden on every honest re-tune; a row asserting only the floor
## passes an amplitude that runs away. `ZOOM_MIN` and `WATER_MARGIN_TILES` are `net_camera`'s, which
## bounds both at both ends. (`CLIFF_FACE_WIDTH_PX`'s two rows lived here until the cliff became mesh
## geometry and the constant was deleted with the line it measured.)
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
	# ⚠ **The two labels below said 열셋 and they say 아홉 now** (2026-08-27). The expression never
	# changed — it has always been `roster_start_count() - 1` — but the 열셋 was written when the beast
	# card added four bodies to the ten and the landing force was fourteen. **The card is deleted, the
	# force is the opening table alone, and the fan's worst case is nine ghosts behind the first.**
	t.ok(Look.GHOST_FAN_PX.x <= 14.0 and Look.GHOST_FAN_PX.y <= 14.0,
		"그리고 14 를 안 넘는다 (천장 — 넘으면 아홉이 3타일 넘게 퍼져 한 상륙으로 안 읽힌다)")
	t.ok(Look.GHOST_FAN_PX.length() * float(Rules.roster_start_count()
			- 1) > Look.TARGET_RING_R_PX,
		"자가 점검 — 아홉을 한 칸에 놓으면 부채가 고리 밖까지 나간다 (그래서 순위는 해변마다 센다)")
	t.ok(Look.CHIP_FX_SEC >= 0.1,
		"누름 반응이 한 프레임보다 길다 (바닥 0.1s — 짧으면 팝이 되고 반응 자체가 안 보인다)")
	t.ok(Look.CHIP_FX_SEC <= 0.4, "그리고 0.4s 를 안 넘는다 (천장 — 넘으면 다음 누름까지 남는다)")
	t.ok(Look.REFUSE_SHAKE_PX >= 2.0, "거절 흔들림이 한 픽셀보다 크다 (바닥 2px)")
	t.ok(Look.REFUSE_SHAKE_PX <= 12.0, "그리고 12px 를 안 넘는다 (천장 — 넘으면 단추가 자리를 뜬다)")
	# ⚠ The two `CLIFF_FACE_WIDTH_PX` rows are DELETED with the constant (verify-read B): nothing has
	# drawn a cliff line since the wall became mesh geometry, and a label bounding the legibility of a
	# line that does not exist is a guarantee about nothing.


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

	# ⚠ The two `_count_set` reader-rows are deleted with the helper itself — see its record above.
	# They measured a counting loop whose only caller had already gone with the drag.

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
	# ⚠ **TYPE_LABELS 도 없다** — 짐승 이름이 `Rules.UNITS` 의 칸이 되면서 두 번째 표가 통째로 사라졌다.
	t.ok(not hud_consts.has("TYPE_LABELS"), "hud_view 에 TYPE_LABELS 도 없다 — 이름은 표의 칸이다")
	t.ok(hud_consts.has("CHIP_SLOT_BASE"), "CHIP_SLOT_BASE 는 그대로 있다 (자가 점검)")

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


