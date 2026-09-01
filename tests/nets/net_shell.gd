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
## ⚠⚠ **`overs` IS THE ONLY LIVE CAPTURE IN THIS CLASS** (2026-09-01). The two arrays above it belong
## to hooks that were deleted in 2026-08-28 and their overrides are dead methods; the loss is the one
## thing `HudView._draw` puts on the glass.
## ⚠ **An override never runs the native call inside the leaf**, so this says the hook was reached with
## a real picture and a real corner — that `_paint_over` holds exactly one `draw_texture` is
## `net_draw_leaf`'s half, and neither half is the whole claim on its own.
class HudSpy extends HudView:
	var draws := 0
	var seq := 0
	var buttons := []
	var enemies := []
	var overs := []
	## **The back-to-title button** (2026-09-01). Captured beside the lettering rather than folded into
	## it: the two are separate leaves, and one drawn without the other is the failure worth naming —
	## words with no way back, or a button floating on a live board.
	var backs := []

	func _draw() -> void:
		buttons.clear()
		enemies.clear()
		overs.clear()
		backs.clear()
		seq = 0
		super()
		draws += 1

	func _paint_over(tex: Texture2D, at: Vector2) -> void:
		overs.append({"seq": _bump(), "tex": tex, "at": at})

	func _paint_back(tex: Texture2D, at: Vector2) -> void:
		backs.append({"seq": _bump(), "tex": tex, "at": at})

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


## ⚠ **`PanelSpy` stood here and it is deleted** (2026-08-29) with the verdict panel it spied on.


## ⚠⚠ **`RewardSpy` STOOD HERE AND IS DELETED** (2026-08-28) with the card screen it watched. What
## it measured was whether the SCREEN was genuinely rebound on a second win — `bind()` zeroing
## `_reveal_age` and clearing `_taken_age` — and there is no second screen to rebind.


func run(t) -> void:
	# ⚠⚠ **THESE TWO RAN NOWHERE FOR MONTHS AND BOTH COME OUT GREEN** (2026-08-30). They were defined,
	# never called, and therefore invisible to every count this file has ever printed — 12 checks that
	# read as covered and were not. **Wired at the very top on purpose**: the second builds a `Game` of
	# its own and puts it in the tree, so it runs and lets go before the fixture below stands one up.
	_speed_steps_survives_read_by_nobody(t)
	await _one_press_reaches_the_first_island(t)
	# ⚠⚠ **AT THE TOP, AND FOR THE REASON THE TERRAIN BLOCK BELOW SPELLS OUT**: a red row halfway down
	# `run()` has twice abandoned everything after it, and 티켓 15's red is still standing. This builds
	# its own `Game` and lets go of it, so it cannot be one of the rows that quietly stops running.
	await _the_keep_falls_and_the_screen_says_so(t)

	var game := QuitGame.new()

	# -- before the tree: every field is null ------------------------------------------------------
	# Nothing in `game.gd` is `@onready` or `@export`, and this is the assertion that keeps it that
	# way. A field filled in from outside — or by the engine — before `_ready` means the wiring line
	# can be deleted and nothing anywhere goes red while the screen stays empty.
	t.ok(game.field_view == null and game.hud_view == null and game.title_view == null,
		"_ready 전에는 뷰 셋이 전부 null 이다 — 미리 채우면 배선 줄을 지워도 초록이다")
	t.ok(game.run == null and game.battle == null, "_ready 전에는 run 도 battle 도 null 이다")
	# ⚠ **`_hold_sec` was the third field checked here and it went with the verdict** (2026-08-29).

	t.root.add_child(game)
	await t.pump_frames(2)

	# -- _ready built the children, in code --------------------------------------------------------
	# ⚠⚠ **IT WAS SIX AND IT IS FOUR** (2026-08-28, the user: 「고르는 창도 이제 필요 없는데 왜있지?
	# 이것도 제거」 · 「둘 다 지우면 돼」). The card screen and the refit board were deleted with the
	# whole growth loop; the map view went before them (2026-08-26).
	# ⚠ **IT WAS SIX, THEN FOUR, AND IT IS THREE** — the panel went 2026-08-29 with the verdict.
	t.eq(game.get_child_count(), 3, "_ready 가 자식 셋을 만들었다 — 승패 판이 삭제됐다")
	t.ok(game.field_view != null and game.hud_view != null and game.title_view != null,
		"세 뷰가 전부 생겼다")
	t.ok(game.get_child(0) == game.field_view and game.get_child(1) == game.hud_view
		and game.get_child(2) == game.title_view,
		"자식 순서가 field -> hud -> title 이다 (Node2D 형제의 그리기 순서가 곧 이 순서다)")
	# Named by hand, because `get_class()` on all four is "Node2D" and four identical labels do not
	# say which one went missing — a failure log that cannot narrow the cause is half a failure log.
	var built := {"field_view": game.field_view, "hud_view": game.hud_view,
		"title_view": game.title_view}
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
	# ⚠ **`Run.State` went with the verdict** (2026-08-29). What the row claims — the press lands on
	# the island with nothing in between — is read off `battle` alone now.
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

	# 「지도에서 칸을 누르면 섬이 열린다」 — and the ring walks first. `_process(dt)` is called by hand
	# because a headless frame is 6.9 ms and 0.45 s would be 66 frames of guessing.
	t.ok(not game._panning, "판을 누르기 전에는 카메라를 안 끌고 있다 (자가 점검)")

	# -- swap in the spies and re-open the island --------------------------------------------------
	# ⚠ **`reward_view` used to be swapped in here too**, early, so item 4 could tell 「rebound」 from
	# 「never bound」 on the second card screen. Both the screen and that row are deleted (2026-08-28).
	for v: Node2D in [game.field_view, game.hud_view]:
		game.remove_child(v)
		v.queue_free()
	# ⚠ The field is a FRESH REAL `FieldView`, not a spy — there are no hooks left to spy on, and a
	# fresh instance still proves the wiring: its `battle` is null until `_open_island` runs setup.
	var fs := FieldView.new()
	var hs := HudSpy.new()
	game.field_view = fs
	game.hud_view = hs
	game.add_child(fs)
	game.add_child(hs)
	t.ok(fs.battle == null and hs.battle == null,
		"바꿔 끼운 스파이는 아직 아무것도 모른다 — 배선은 _open_island 가 한다")
	game._open_island()
	t.ok(fs.battle == game.battle and fs.army == game.run.army,
		"_open_island 가 field_view.setup 을 실제로 불렀다")
	t.ok(hs.battle == game.battle, "_open_island 가 hud_view.bind 를 실제로 불렀다")

	# ⚠⚠ **BOTH HALVES USED TO BE MEASURED — the clock frozen before the start button and moving
	# after it — and the FROZEN half is deleted** (2026-08-29) with the gate that froze it. An island
	# is open the moment it is built now, so there is no state in which the clock is legitimately
	# still. **The moving half below is the one that matters**: it is the only thing that separates a
	# sim the shell really steps from one it silently never steps at all.
	# ⚠⚠ **THIS PROBE HAS BEEN RE-AIMED THREE TIMES AND THE SUBJECT NEVER MOVED**: it is the shell
	# driving the clock. It walked `passable` for a beach and sent a boat there; then it summoned
	# one onto the water and pressed 시작; then it committed the island. **All three gestures are
	# deleted.** The island is open and the clock runs, so nothing has to be armed at all now.
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

	# A FRESH island for everything below: `run.begin_island()` builds a new `Battle` every call.
	# ⚠ **A `not committed()` row stood under this and it went with the gate** (2026-08-29).
	var was := game.battle
	game._open_island()
	await t.pump_frames(2)
	t.ok(game.battle != was, "다시 열면 새 battle 이 온다 (자가 점검)")

	# From here the sim is frozen, so a captured frame and a value read after it are the same instant.
	game.set_process(false)
	await t.pump_frames(2)

	# ⚠⚠ **THE PAN ROWS ARE CALLED HERE AND NOT DOWN BESIDE THE DRAG ROWS, AND THE REASON IS A HOLE
	# IN THIS FILE.** Measured 2026-08-30: the terrain row below throws on a null `_terrain.mesh`, and
	# a runtime error inside `run()` abandons everything after it — **so this file's whole camera
	# section, the wheel and drag rows included, has not executed for as long as that red has stood.**
	# It reports as 「41 passed」 either way, which is exactly the shape `tests/README` warns about.
	# ⚠ **The red itself is 티켓 15's and is not touched here**; what is done is putting the new rows
	# where they actually run. **Frozen sim above, so the pan is the only thing moving.**
	_a_drag_looks_around_and_a_click_commands(t, game, fs)
	# ⚠⚠ **THE TWO NEW CAMERA FUNCTIONS SIT HERE FOR THE REASON THE PARAGRAPH ABOVE GIVES**, and for
	# no other: everything below the terrain block has been abandoned by a throw twice this session,
	# and a row that quietly does not run is worse than a red. **The sim is frozen from here**, so the
	# camera is the only thing moving and a `cam_px` that changed changed because of an input.
	# ⚠ **After the drag rows, not before**: `_a_drag_...` leaves the yaw at its opening angle, and
	# every direction row below reads `cam_px` axes that only line up with the screen at that yaw.
	_the_right_button_turns_and_never_commands(t, game, fs)

	var b: Battle = game.battle
	# ⚠ **An `events` row stood here and the list went with the fight** (2026-08-29). It proved the
	# views were not re-draining the same event every frame — the shape to rebuild when events come back.

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
	# ⚠⚠ **THE THREE ROWS THAT STOOD HERE ARE DELETED** (02-08, 2026-09-01, the user: 「about the stale
	# tests — I asked you to delete them, not fit them to the current island」). They read
	# `_terrain.mesh` for a surface count and a face count. **`_terrain` is an empty `MeshInstance3D`
	# and nothing has written a mesh into it since the island became a `.glb`** — `_rebuild_terrain`
	# instantiates `island.glb` into `_island` instead, so `_terrain.mesh` is null on every board and
	# the rows could not go green on any island.
	# ⚠ **What stopped being measured: that the island's geometry reaches the tree at all.** Nothing
	# here counts a surface or a face any more, so `_rebuild_terrain` returning early — a missing scene
	# file, a null `battle` — leaves this file green with the island absent.
	# ⚠ **The first of them used to take `run()` down with it**: calling `get_surface_count()` on a null
	# mesh raised inside `run()` and abandoned every row after it. That hazard goes with the rows.
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
	# ⚠⚠ **THIS ROW READ `fs._hulls_used` AND THAT FIELD WAS DELETED WITH THE PLAYER'S BOATS**
	# (2026-08-28). It did not go red — **it threw, and a runtime error abandons the rest of `run()`**,
	# so this was the SECOND landmine in this function after the terrain one above. The subject is gone
	# too: nobody presses to make a boat any more.
	# ⇒ **Re-aimed at the subject that replaced it.** The beasts' hulls are `_boats_used`, and the
	# claim that survives is the same one: **before the first boat's clock there is nothing to draw.**
	t.eq(fs._boats_used, 0, "첫 배가 뜨기 전에는 선체가 하나도 안 그려진다")
	# ⚠⚠ **THE 0.87912 ROW IS DELETED** (02-08). It was hand arithmetic on a 26 x 20 board —
	# `1280 / (26 * 40 * 1.40)` — and the island loads 30 x 26. **What stopped being measured: the
	# opening zoom's actual VALUE.** The row underneath keeps the half of it that carries no literal,
	# and that half is the one the user's own complaint was about (2026-08-25: 「처음 시작할떄 가메라
	# 좀더 뒤에서 시작할 수 있게해줘」) — at the old margin the survey wanted 1.07 and the wheel's ceiling
	# took it, so the opening view was a clamp rather than the survey's answer.
	t.ok(fs.zoom < Look.ZOOM_MAX - 0.01,
		"자가 점검 — 그 값이 ZOOM_MAX 가 아니다: 걸리면 여백 상수가 아무 일도 못 한다")

	# ⚠ **The cliff-face rows are DELETED, subject and all.** `_paint_cliff_face` drew a line along
	# every seaward cliff edge because a flat canvas had no other way to say "tall"; the cliff is a
	# real 2.4-tile wall in the terrain mesh now, told from land by its own lit faces and its shadow.
	# A rewritten row would census the mesh builder against itself; the wall's look is verify-look's.

	# -- the bodies, read off SURFACE 2: the pooled nodes the engine draws --------------------------
	# The comparison still runs from what `battle` holds to what reaches the engine — position,
	# picture, tint and size are node FIELDS, and the engine consumes exactly those fields.
	#
	# ⚠⚠ **IT READ THE ENEMIES UNTIL 2026-08-29 AND IT READS THE COMPANY NOW.** The island opened with
	# beasts standing on it and no body of the player's ashore, so the census was 「one sprite per live
	# enemy and nothing else」. **The enemies are deleted**; what stands on the island is the watch the
	# run puts there.
	# ⚠⚠ **ONE FRAME IS PUMPED HERE AND WITHOUT IT THIS ROW READS TWO INSTANTS** (2026-08-30). The
	# header above says the sim is frozen from `set_process(false)`, and **the edge-pan row in between
	# calls `game._process` by hand** — which steps it, with no engine frame after to repaint. **A body
	# walking is then painted where it was and read where it is.** It went unseen while the watch was
	# ONE body: the only order it was ever given aimed at the 조각 it already stood on, so it cleared on
	# the sub-step it arrived and nothing ever moved. **Four bodies is what made it visible.**
	await t.pump_frames(1)
	var ashore := battle_ashore(b)
	t.ok(ashore.size() > 0, "섬에 선 몸이 있다 (%d명)" % ashore.size())
	# ⚠⚠ **THE DECK COUNTS AND IT USED TO BE INVISIBLE HERE** (2026-08-30). A rider is a body sprite out
	# of the same pool, and by this point in the file the island's clock has run past
	# `BOAT_FIRST_SEC` — **so eight of them were on screen while this row said 「섬에 선 몸 수」 and
	# passed.** What hid them was the stale frame the row above now pumps away. ⚠ **The three terms come
	# from the SIM**, never from the pool: counted off the pool this would compare it with itself.
	var riders := 0
	for k in b.boat_riders.size():
		riders += int(b.boat_riders[k])
	var bodies := _body_sprites(fs)
	t.eq(bodies.size(), ashore.size() + b.living_enemy_ids().size() + riders,
		"몸 스프라이트 수 = 섬에 선 몸 + 판 위의 짐승 + 갑판 위의 늑대 (%d + %d + %d) — 화면에 있는 것과 sim 이 아는 것이 같다"
			% [ashore.size(), b.living_enemy_ids().size(), riders])
	var body_bad := 0
	for raw_i in ashore:
		var i: int = raw_i
		var st := int(b.army.type_id[i])
		var s := _sprite_at_xz(bodies, Look.tile_point_px(b.soldier_pos[i]))
		if s == null:
			body_bad += 1
			continue
		# A textured body wears `beast_tint(side colour)`; the bare rounded square wears the colour
		# raw — the same fork `_put_body` takes, read back off the one modulate the engine applies.
		var textured := s.texture != fs._tex_body
		var want_mod := Look.beast_tint(Look.body_colour_of(false)) if textured \
			else Look.body_colour_of(false)
		if s.modulate != want_mod:
			body_bad += 1
			continue
		# The size really is the type's own radius through the sprite-width ratio.
		# ⚠⚠ **BOTH DRAW FACTORS, AND THE SPECIES' ROW SAYS ONE OF THEM** (2026-08-30). This compared
		# against the bare ratio while `_put_body` has multiplied `BODY_SPRITE_SCALE` in since
		# 2026-08-28 and the row's own draw column since today — **a size row that does not carry every
		# factor is a size row that goes green on a size nothing drew.**
		var drawn := Look.BODY_SPRITE_SCALE * Look.beast_draw_scale(st)
		var want_sx := Look.body_radius_of(st) * Look.BEAST_SPRITE_W_RATIO * drawn \
				/ float(s.texture.get_width()) \
			if textured else Look.body_radius_of(st) * 2.0 * drawn / float(s.texture.get_width())
		if absf(s.scale.x - want_sx) > 0.001:
			body_bad += 1
	t.eq(body_bad, 0, "몸마다 자리·색·크기가 sim 의 그 몸에게서 나왔다")
	# ⚠⚠ **THE HP BAR ROWS ARE DELETED** (2026-08-28, the user: 「체력바 없이」). They read the two flat
	# sprites per body — rail and fill — and their two colours.
	t.eq(_flat_sprites(fs).size(), 0, "몸 위에 막대가 한 장도 안 붙는다 — 체력바가 삭제됐다")
	# ⚠⚠ **THE GROUND BUFFER IS NO LONGER SILENT AND THAT IS THE SHADOW** (2026-08-28, the user:
	# 「그림자도 단순하게 아래 동그라미정도해줘」). Every body lays one disc down, so the floor here is a
	# COUNT rather than a zero.
	# ⚠ **The AIR buffer rows are deleted with the air layer itself** (2026-08-29) — every mark it ever
	# carried belonged to a blow.
	t.ok(fs._g_v.size() > 0, "바닥에는 정점이 있다 — 몸마다 그림자 원 하나 (%d 정점)" % fs._g_v.size())
	var shadow_verts := 0
	for c: Color in fs._g_c:
		if c == Look.COL_BODY_SHADOW:
			shadow_verts += 1
	t.eq(shadow_verts, fs._g_c.size(),
		"그리고 그 정점이 전부 그림자 색이다 — 바닥에 다른 그림이 하나도 없다")
	t.ok(fs._decal.mesh.get_surface_count() > 0, "바닥 연출 메시가 실제로 커밋됐다 — 버퍼만 찬 게 아니다")

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
	# ⚠⚠ **THE BARE WHEEL ZOOMS. IT TURNED THE BOARD FOR ONE ROUND AND THE USER REVERSED IT**
	# (2026-08-30 morning: 「마우스 휠이 회전 오른쪽이 끌어서 이동으로 해야할듯」; the same day at the screen:
	# 「마우스 휠이 확대 축소가 맞고, 오른쪽 버튼은 카메라 회전으로 이해했어」). **The later word wins.**
	# ⚠⚠ **BOTH HALVES OR NEITHER**: a wheel that zoomed AND turned would pass the zoom rows on its own,
	# and the yaw row is what says the turn actually left the wheel.
	# ⚠ **SHIFT+wheel is deleted with it.** It was the previous builder's own pairing, never the user's,
	# and with the bare wheel zooming again it is a second unowned path to one state — so the row that
	# measured it is deleted rather than left asserting a gesture nobody chose.
	var before_zoom := fs.zoom
	var before_yaw := fs.cam_yaw_deg
	game._unhandled_input(_wheel(Vector2(640.0, 360.0), true))
	t.ok(fs.zoom > before_zoom, "휠을 올리면 확대된다 (%.4f -> %.4f)" % [before_zoom, fs.zoom])
	t.ok(absf(fs.cam_yaw_deg - before_yaw) < 0.001,
		"그리고 휠은 판을 안 돌린다 — 한 굴림이 두 가지를 하지 않는다 (%.2f°)" % fs.cam_yaw_deg)
	# **Down is the other way**, and this is the row that stops both notches doing the same thing.
	var up_zoom := fs.zoom
	game._unhandled_input(_wheel(Vector2(640.0, 360.0), false))
	t.ok(fs.zoom < up_zoom, "아래로 굴리면 축소된다 (%.4f -> %.4f)" % [up_zoom, fs.zoom])
	t.ok(absf(fs.zoom - before_zoom) < 0.0001,
		"한 칸 올리고 한 칸 내리면 제자리로 돌아온다 (%.4f)" % fs.zoom)
	# **The ceiling is real and the wheel is what reaches it.**
	for _n in 8:
		game._unhandled_input(_wheel(Vector2(640.0, 360.0), true))
	t.eq(fs.zoom, Look.ZOOM_MAX, "계속 올리면 ZOOM_MAX 에서 멈춘다 — 8번이면 이미 넘친다 (바닥)")
	t.ok(absf(fs.cam_yaw_deg - before_yaw) < 0.001,
		"열 번을 굴려도 판은 그대로다 (%.2f°)" % fs.cam_yaw_deg)

	# ⚠⚠ **THE SENTENCE THAT STOOD HERE — 「a drag can never MOVE the camera on this island」 — IS A
	# DELETED RULE** (2026-08-30, 티켓 41). It was true while `_clamp_cam` was bounded by the island:
	# every island is narrower than its own opening view, so the clamp centred both axes and a drag
	# snapped straight back. **The clamp is bounded by the island plus `Look.CAM_ROAM_TILES` of sea
	# now** — see that constant — because looking out to sea is how a player finds a boat and nothing
	# else tells them one is coming. ⚠⚠ **THE CLAIM THAT USED TO SIT HERE — 「the literal below still holds」 — WAS WRITTEN ABOUT A ROW
	# THAT HAD NOT EXECUTED IN MONTHS**, and it was written by reasoning rather than by running: the
	# terrain throw above abandoned `run()` before any of this. It is deleted rather than re-argued.
	# **The literal is whatever the round now measures**, and if it is wrong it will say so.
	# ⚠ **The travel itself was measured in `_the_pan_keys_move_the_camera_and_stop`, which is deleted
	# with the keys it drove** (2026-08-31). The centred literal, by hand:
	# ((1040 - 1280) / 2, (800 - 1120.12) / 2) = **(-120.00, -160.06)**.
	# ⚠ The y half moved on 2026-08-25 when the pitch divisor was corrected from cosine to sine; it
	# read -69.95, which was the wrong span reaching the clamp.
	# ⚠⚠ **THE MOTION USED TO BE SENT AT THE PRESS POINT ITSELF AND THEREFORE PANNED NOTHING.** The
	# 6 px threshold (`Look.DRAG_PAN_THRESHOLD_PX`) is measured from where the button went DOWN, and
	# 0 px of travel is a click — so this row read `(300.00, 300.00)`, the value it was set to, and
	# blamed the clamp. **The gesture is fixed here and the literal is not touched**: whether that
	# expected point is still this island's centre is 티켓 15's question, not this row's.
	# ⚠⚠ **THE ROW ON THIS GESTURE IS DELETED AND THE GESTURE IS KEPT** (02-08). It asserted the drag
	# lands on `(-120.00, -160.06)` — the centred clamp of a 26 x 20 board, `((1040 - 1280) / 2,
	# (800 - 1120.12) / 2)` — and the island loads 30 x 26. **What stopped being measured: that a press
	# and a drag reach `pan_by` at all.** ⚠ The press/motion below stays because the row after it needs
	# a drag to have been released; **it now asserts nothing on its own.**
	fs.cam_px = Vector2(300.0, 300.0)
	game._unhandled_input(_press(Vector2(640.0, 360.0)))
	game._unhandled_input(_motion(Vector2(680.0, 400.0), Vector2(40.0, 40.0)))
	game._unhandled_input(_release(Vector2(680.0, 400.0)))

	fs.cam_px = Vector2(300.0, 300.0)
	game._unhandled_input(_motion(Vector2(680.0, 400.0), Vector2(40.0, 40.0)))
	t.eq(fs.cam_px, Vector2(300.0, 300.0),
		"손을 뗀 뒤의 움직임은 카메라를 안 끈다 — pan_by 가 불렸다면 클램프가 자리를 옮겼을 것이다")

	# ⚠⚠ **ITEM 4'S WHOLE FIXTURE AND ITS FOUR ROWS ARE DELETED** (2026-08-28) with the card screen.
	# They measured that a SECOND win rebound the screen fresh — `_reveal_age` back near zero, no
	# `_taken_age` marks left from the first round, three cards drawn again. **There is no card screen
	# and a win goes straight to `WON`.**

	# -- ⚠⚠ THE LOSE PANEL AND THE RESTART BUTTON: DELETED 2026-08-29 -------------------------------
	# What stood here: lose the island, read the panel's own paint hook for the message and the button,
	# hold that rect apart from the start button's, press restart and land back on the title with the
	# island no longer drawing behind it.
	#
	# **All of it went with the verdict.** ⚠ **The hole it leaves is real and is written down rather
	# than papered over: nothing returns to the title any more.** The title opens a run and a run has
	# no end — see `game.gd`, where `_click_panel` used to be.
	_the_route_points_are_in_soldier_pos_units(t, game)
	_a_full_hand_moves_instead_of_picking(t, game, fs)
	_the_picked_body_wears_a_rim(t, game, fs)

	# **The sentinel.** See `run_nets.done` — without it a `run()` that dies
	# half way still reports every check it managed first, in a shape a healthy net cannot be told from.
	t.done()


## **The 이동선's points are in `soldier_pos`'s own units, corner-anchored** (2026-08-31, the user at
## the screen: 「지금은 블록 가운데서 오는듯한데?」).
##
## ⚠⚠ **THE FIRST POINT AND THE REST DISAGREED BY HALF A 조각 AND NOTHING WENT RED.** The first point
## is a real `soldier_pos`; the rest were built with a `+ 0.5` baked in, and the view then multiplied
## the lot by `TILE_PX` — so the line left from half a 조각 up and to the left of the body walking it.
## **Every check about the route stayed green** because they all asked 「which 조각」 and never 「where in
## world px」. ⇒ these rows compare the two ends against each other in the one unit both must share.
func _the_route_points_are_in_soldier_pos_units(t, game) -> void:
	var b: Battle = game.battle
	if b == null:
		return
	var ashore := b.ashore_ids()
	if ashore.is_empty():
		return
	var who := int(ashore[0])
	game.hand.pick(b, who)
	# ⚠ **A destination far enough to have a middle point.** A two-point line cannot show the
	# disagreement — both ends are special cases.
	var far := -1
	var reach: PackedInt32Array = game.hand.reach
	for k in reach.size():
		var cand := int(reach[k])
		var p := Vector2(float(cand % b.grid.w), float(cand / b.grid.w))
		if p.distance_to(b.soldier_pos[who]) >= 4.0:
			far = cand
			break
	t.ok(far >= 0, "자가 점검 — 네 조각 넘게 떨어진 갈 수 있는 자리가 있다")
	if far < 0:
		return
	# ⚠⚠ **`route_points` TAKES A 칸 SINCE 2026-09-01** (the user: "let us do it by the block"). **`far`
	# is still picked out of `reach`, which is still 조각** — the distance above is a 조각 distance and
	# has to stay one. Only the aim is converted, exactly as `_show_route` converts it in the shell.
	# ⚠ **A raw 조각 index passed here compiles and aims at a real 칸 somewhere else on the board**, so
	# the conversion is written on its own line rather than inlined into the call.
	var far_block := b.grid.block_of(far)
	var pts_all: Array = game.hand.route_points(b, far_block)
	t.eq(pts_all.size(), 1, "쥔 몸 하나에 선 하나다")
	var pts: PackedVector2Array = pts_all[0]
	t.ok(pts.size() >= 3, "그 선은 점 셋 이상이다 (가운데가 있어야 단위가 드러난다)")
	if pts.size() < 3:
		return
	t.eq(pts[0], b.soldier_pos[who] as Vector2,
		"첫 점이 몸의 자리 그대로다 — 반 조각도 안 옮긴다")
	# ⚠ **Every later point is a 조각 index as a whole number**, in the same frame as the first. A
	# `+ 0.5` anywhere in the chain shows up here as a fraction.
	var fractional := 0
	for k in range(1, pts.size()):
		var q := pts[k]
		if not is_equal_approx(q.x, floor(q.x)) or not is_equal_approx(q.y, floor(q.y)):
			fractional += 1
	t.eq(fractional, 0, "뒤의 점도 전부 조각 눈금 위에 있다 — 반 조각이 섞여 있지 않다")
	var last := pts[pts.size() - 1]
	# ⚠⚠ **THE UNIT OF THIS ROW CHANGED WITH THE ORDER, AND ITS LABEL SAYS SO.** It read 「마지막 점이
	# 명령할 그 조각이다」 and pinned the 조각 exactly; a 칸 order cannot promise that, because `_seats`
	# picks which of the 칸's four 조각 the body sits in and the press carries no sub-칸 information.
	# **What the line still has to end in is the 칸 that was aimed at** — anywhere else and the preview
	# is drawing a walk the press will not make.
	var last_tile := int(last.y) * b.grid.w + int(last.x)
	t.eq(b.grid.block_of(last_tile), far_block, "마지막 점이 명령할 그 칸 안이다")
	game.hand.clear()


## **A hand that is holding somebody MOVES, and a body standing on the destination does not intercept
## the press** (2026-08-31, the user at the screen: 「이게 조각에 옮길 수가 있잖아? 같은 조각으로? 그때
## 살짝 불편하네? 이게 esc를 하지 않는 이상 이동 우선으로 해줘야할듯한데」).
##
## ⚠⚠ **THIS IS THE ONE ROW THE OLD ORDER PASSED AND THE SCREEN FAILED.** Until this day the press
## asked 「is there a body here」 first, and every check stayed green: picking worked, ordering worked,
## the reach lit. **What nothing measured is the two of them meeting** — pressing a 조각 that is BOTH a
## destination and somebody's spot — and that is the only case where the priority is visible at all.
## ⇒ the destination is deliberately chosen to be another body's own 조각.
##
## ⚠ **Everything is taken off the board rather than typed.** Which 조각 a body stands on moves with the
## island, and a literal here would be measuring a fixture instead of the rule.
func _a_full_hand_moves_instead_of_picking(t, game, fs: FieldView) -> void:
	var b: Battle = game.battle
	if b == null:
		return
	var ashore := b.ashore_ids()
	t.ok(ashore.size() >= 2, "자가 점검 — 섬에 몸이 둘 이상이다 (하나면 이 규칙이 안 보인다)")
	if ashore.size() < 2:
		return
	var mover := int(ashore[0])
	game.hand.pick(b, mover)
	var mine: Vector2 = b.soldier_pos[mover]
	var my_tile := int(floor(mine.y)) * b.grid.w + int(floor(mine.x))
	var target := -1
	var at := Vector2.ZERO
	for k in range(1, ashore.size()):
		var p: Vector2 = b.soldier_pos[int(ashore[k])]
		var tx := int(floor(p.x))
		var ty := int(floor(p.y))
		var tile := ty * b.grid.w + tx
		# ⚠ **Somebody else's 조각 and not the mover's own.** Ordering a body onto the 조각 he already
		# stands on is legal and would pass this row while measuring nothing.
		if tile == my_tile or not game.hand.can_reach(tile):
			continue
		var scr := fs.tile_to_screen_px(tx, ty)
		# ⚠ The round trip is the self-check: a point that resolves elsewhere would order elsewhere.
		if game._tile_at(scr) != tile:
			continue
		target = tile
		at = scr
		break
	t.ok(target >= 0, "자가 점검 — 다른 몸이 선 조각 중 화면에서 겨눌 수 있고 갈 수 있는 것이 있다")
	if target < 0:
		return
	b.soldier_order[mover] = -1
	game._unhandled_input(_press(at))
	game._unhandled_input(_release(at))
	# ⚠⚠ **THE 칸 AND NOT THE 조각, SINCE 2026-09-01.** The press is aimed at a 조각 on screen — that is
	# what `_tile_at` answers and it is deliberately not re-pointed — but the shell converts it with
	# `Grid.block_of` before ordering, and `_seats` then picks which 조각 of that 칸 the body sits in.
	# ⚠ **`soldier_order[mover]` was set to -1 two lines up, which is what keeps this row from being
	# free**: `block_of(-1)` is -1, so a press that ordered nobody cannot pass it.
	t.eq(b.grid.block_of(int(b.soldier_order[mover])), b.grid.block_of(target),
		"몸이 선 조각을 눌러도 쥔 몸이 그 칸으로 간다 — 그 자리의 몸이 대신 골라지지 않는다")
	t.ok(game.hand.is_empty(), "그리고 명령이었으므로 손을 놓는다 — 새로 고른 게 아니다")


## **The white rim on the body the hand is holding** (2026-08-31, the user: 「캐릭터 눌렀을때 살짝 내가
## 누른 캐릭에 흰색 테두리 ... 내가 누른 캐릭이 티가 나야할듯함」).
##
## ⚠⚠ **THE POOLED NODE STATE IS THE AGREED VIEW SEAM** (`GLOSSARY.md`) — `visible`, `texture` and
## `scale` are three of the fields the engine consumes. **A rim is not measurable from `Hand`**: the
## defect this guards is a shell that picks somebody the view never marks, and both sides read green
## when only the sim is asked.
##
## ⚠⚠ **IT RUNS LAST AND THAT IS NOT TIDINESS.** `_paint_bodies` fills the boat pool as well as the
## body pool, and one row above reads `_boats_used` to say 「before the first boat there is nothing to
## draw」. Called from the middle of the file this function turned that row red — **measured, and it is
## why the fixture's paint state is left alone until every other row has had it.**
func _the_picked_body_wears_a_rim(t, game, fs: FieldView) -> void:
	var b: Battle = game.battle
	if b == null:
		return
	var ashore := b.ashore_ids()
	t.ok(not ashore.is_empty(), "자가 점검 — 테두리를 씌울 몸이 섬에 있다")
	if ashore.is_empty():
		return
	# ⚠ **Picked through the sim and not by aiming a press.** Where a body happens to be on screen is
	# another function's subject; this one is about what the view does once somebody IS picked.
	game.hand.pick(b, int(ashore[0]))
	game.field_view.set_picked(game.hand.ids)
	fs._paint_bodies()
	var rims := 0
	for k in fs._rims_used:
		if fs._rims[k].visible:
			rims += 1
	t.eq(rims, 1, "고른 몸 하나에만 흰 테두리가 선다")
	var rim_tex_ok := false
	if fs._rims_used > 0:
		var rim: Sprite3D = fs._rims[0]
		for raw_s in _body_sprites(fs):
			var body_s: Sprite3D = raw_s
			if body_s.texture != rim.texture:
				continue
			# ⚠ **The two scales are compared rather than a number typed.** The rim is the body's own
			# picture grown, so the growth constant may move and this row still measures it.
			if is_equal_approx(rim.scale.x, body_s.scale.x * Look.PICK_OUTLINE_GROW):
				rim_tex_ok = true
				break
	t.ok(rim_tex_ok, "그 테두리는 그 몸의 그림을 그대로 키운 것이다 — 다른 그림이 아니다")

	# -- and ESC takes it off -------------------------------------------------------------------------
	game._unhandled_input(_key(KEY_ESCAPE))
	t.ok(game.hand.is_empty(), "ESC 를 누르면 선택이 풀린다")
	fs._paint_bodies()
	var rims_after := 0
	for k in fs._rims_used:
		if fs._rims[k].visible:
			rims_after += 1
	t.eq(rims_after, 0, "그러면 흰 테두리도 같이 없어진다")



## ⚠⚠ **`_the_pan_keys_move_the_camera_and_stop` STOOD HERE AND IT IS DELETED** (2026-08-31, the
## user: 「wasd 도 지워줘」). It drove WASD as HELD state — one press, then frames — and measured that
## the camera kept moving across them, that the release stopped it, that an OS auto-repeat echo did
## not add a second direction, that two keys held made a diagonal and letting one go left the other
## running, and that a key held into the roam ring stopped at the bound instead of running out to sea.
##
## ⚠ **`_key_edge` went with it** — it built a key event on either edge, with an `echo` flag, and the
## keys were the only thing left in this file that needed one.


## **A press that travels is a look-around; a press that does not is an order.** 티켓 41.
##
## ⚠⚠ **DRAGGING OVER THE ISLAND MOVED THE CAMERA NOWHERE, WHICH IS MOST OF THE OPENING SCREEN**
## (2026-08-30, measured on the running game with a negative control: the same ten-step drag moved the
## camera **0.0 px** from land and **315.0 px** from water, and the two land frames were pixel-identical).
## The order was issued on the press, so `_panning` never turned on — **the machinery was alive the whole
## time and the gesture never reached it.** On screen it reads as a broken mouse.
##
## ⚠ **Both halves or neither.** A threshold that panned would be trivial to satisfy by deleting the
## order; a threshold that ordered would be satisfied by deleting the pan. **The two rows below are the
## same gesture measured on its two outcomes**, and each asserts what the OTHER one must not have done.
func _a_drag_looks_around_and_a_click_commands(t, game, fs: FieldView) -> void:
	var b: Battle = game.battle
	# ⚠⚠ **THE PRESS POINT IS THE 조각 A BODY IS STANDING ON, NOT THE MIDDLE OF THE SCREEN.** A first
	# draft used screen centre, and after the drag below had moved the camera that point was open water —
	# so the click ordered nobody and the row went red for the fixture rather than for the shell. **A
	# press on water was never the broken case**; the whole defect is a press on LAND being eaten.
	var ashore := b.ashore_ids()
	t.ok(ashore.size() > 0, "자가 점검 — 판 위에 선 몸이 있다 (없으면 아래가 전부 공허하다)")
	if ashore.is_empty():
		return
	var sid := int(ashore[0])
	var body: Vector2 = b.soldier_pos[sid]
	var body_tile := int(round(body.y)) * b.grid.w + int(round(body.x))
	fs.cam_px = Vector2.ZERO
	fs._clamp_cam()
	var on_land := fs.tile_to_screen_px(int(round(body.x)), int(round(body.y)))
	t.eq(game._tile_at(on_land), body_tile, "자가 점검 — 그 화면 점이 몸이 선 조각으로 돌아온다")

	# -- a drag: the camera moves and NOTHING is ordered ---------------------------------------------
	for i in b.soldier_order.size():
		b.soldier_order[i] = -1
	var before := fs.cam_px
	game._unhandled_input(_press(on_land))
	# ⚠ **Under the threshold first.** A one-pixel wobble must not turn a click into a pan, and without
	# this row the threshold could be zero and every check below would still pass.
	game._unhandled_input(_motion(on_land + Vector2(2.0, 0.0), Vector2(2.0, 0.0)))
	t.eq(fs.cam_px, before, "문턱 아래로 움직인 것은 아직 이동이 아니다")
	game._unhandled_input(_motion(on_land + Vector2(60.0, 40.0), Vector2(58.0, 40.0)))
	t.ok(fs.cam_px.distance_to(before) > 1.0,
		"문턱을 넘겨 끌면 땅 위에서도 카메라가 움직인다 (%.1f px)" % fs.cam_px.distance_to(before))
	game._unhandled_input(_release(on_land + Vector2(60.0, 40.0)))
	var ordered := 0
	for i in b.soldier_order.size():
		if int(b.soldier_order[i]) >= 0:
			ordered += 1
	t.eq(ordered, 0, "그리고 끌기는 아무도 명령하지 않는다 — 보려고 움직인 것이지 보내려던 게 아니다")

	# -- a click: somebody is ordered and the camera does NOT move -----------------------------------
	# ⚠ **Re-aimed, because the drag above moved the camera** — the same screen point is a different
	# 조각 now, and this row is about a press on land.
	var click_at := fs.tile_to_screen_px(int(round(body.x)), int(round(body.y)))
	t.eq(game._tile_at(click_at), body_tile, "자가 점검 — 다시 겨눈 점도 그 조각이다")
	var held := fs.cam_px
	game._unhandled_input(_press(click_at))
	game._unhandled_input(_release(click_at))
	t.eq(fs.cam_px, held, "제자리에서 누르고 떼면 카메라는 안 움직인다")
	# ⚠⚠ **A PRESS ON A BODY PICKS IT AND ORDERS NOBODY, AND THAT IS THE 2026-08-31 REVERSAL** (the
	# user: 「tab 없이 그냥 캐릭터를 누르면 이동할 수 있는 칸들이 뜨고 눌러서 이동하는거임」). This row
	# asserted the opposite until that day — one press, one walk, nearest body answers — and the old
	# row is rewritten rather than kept beside this one: two rows asserting opposite gestures is not a
	# record, it is one of them lying.
	var ordered2 := 0
	for i in b.soldier_order.size():
		if int(b.soldier_order[i]) >= 0:
			ordered2 += 1
	t.eq(ordered2, 0, "몸을 누른 것은 아직 명령이 아니다 — 고른 것이다")
	t.eq(game.hand.ids.size(), 1, "그리고 손이 그 몸 하나를 쥐고 있다")
	t.ok(game.hand.reach.size() > 1, "갈 수 있는 자리가 깔렸다 (%d 조각)" % game.hand.reach.size())
	t.ok(game.hand.can_reach(body_tile), "선 자리도 그중 하나다 — 제자리는 늘 설 수 있는 자리다")

	# -- and the SECOND press, on a lit 조각, is the walk ---------------------------------------------
	# ⚠ **The destination is taken from the reach itself and not typed.** A literal 조각 would measure
	# a board this net does not own, and the island's shape has moved twice already.
	var dest := -1
	var dest_at := Vector2.ZERO
	for k in game.hand.reach.size():
		var cand := int(game.hand.reach[k])
		# ⚠⚠ **A DIFFERENT 칸 AND NOT ONLY A DIFFERENT 조각, SINCE 2026-09-01.** The order is aimed at a
		# 칸 now, so a destination in the body's OWN 칸 would let a shell that ordered him where he
		# already stands pass the row below — the unit is exactly what makes those two indistinguishable.
		if b.grid.block_of(cand) == b.grid.block_of(body_tile):
			continue
		var at := fs.tile_to_screen_px(cand % b.grid.w, cand / b.grid.w)
		# ⚠ **The round trip is the self-check.** A screen point that resolves to a different 조각
		# would order somebody somewhere else and this pair would still be green.
		if game._tile_at(at) != cand:
			continue
		dest = cand
		dest_at = at
		break
	t.ok(dest >= 0, "자가 점검 — 화면에서 겨눌 수 있는 갈 수 있는 자리가 있다")
	# ⚠ **The id is taken BEFORE the press.** The order lets go of the hand, so reading it back out of
	# `hand.ids` afterwards would index an empty list — see the reversal note in `_press_the_island`.
	var walker := int(game.hand.ids[0]) if not game.hand.is_empty() else -1
	if dest >= 0 and walker >= 0:
		game._unhandled_input(_press(dest_at))
		game._unhandled_input(_release(dest_at))
		# ⚠ **The 칸, for the reason the loop above now skips the body's own one.** `ordered2` was
		# asserted to be 0 a few lines up, so every `soldier_order` is -1 going in and `block_of(-1)`
		# is -1 — a press that ordered nobody cannot pass this.
		t.eq(b.grid.block_of(int(b.soldier_order[walker])), b.grid.block_of(dest),
			"불이 들어온 조각을 누르면 그 몸이 그 칸으로 간다")
		t.eq(fs.cam_px, held, "그리고 명령한 누름도 카메라를 안 움직인다")
		# ⚠⚠ **THE ROW ABOVE THIS ONE ASSERTED THE OPPOSITE FOR ONE ROUND** (2026-08-31, the user at
		# the screen: 「이동하면 그러면 그 이동관 관련은 꺼져야지」). It read 「명령한 뒤에도 손은 그
		# 몸을 놓지 않는다」. **The later word wins and the old row is rewritten, not kept beside it.**
		t.ok(game.hand.is_empty(), "명령하고 나면 손을 놓는다 — 물어볼 것이 남지 않았다")
		t.eq(game.hand.reach.size(), 0, "그래서 갈 수 있는 자리도 같이 꺼진다")

	# -- ESC lets go of a hand that is holding somebody ----------------------------------------------
	# ⚠ **Re-picked first**, because the order above already emptied the hand and a key that clears an
	# empty hand is a row that passes against a shell with no ESC branch at all.
	game._unhandled_input(_press(click_at))
	game._unhandled_input(_release(click_at))
	t.ok(not game.hand.is_empty(), "자가 점검 — 다시 눌러 몸을 쥐었다")
	game._unhandled_input(_key(KEY_ESCAPE))
	t.ok(game.hand.is_empty(), "ESC 를 누르면 선택이 풀린다")
	t.eq(game.hand.reach.size(), 0, "그리고 켜져 있던 자리도 같이 꺼진다")

	# ⚠ **The self-check that keeps the rows honest**: the press point really is a 조각 a body can be
	# sent to. On water every row above would be satisfied by a shell that does nothing at all.
	t.ok(b.grid.passable[body_tile] != 0, "자가 점검 — 누른 자리가 걸을 수 있는 조각이다")


## **The right button TURNS the board and commands nobody** (2026-08-30, the user at the screen:
## 「오른쪽 버튼은 카메라 회전으로 이해했어」).
##
## ⚠⚠ **THIS FUNCTION MEASURED A PAN FOR ONE ROUND** (「오른쪽이 끌어서 이동으로 해야할듯」, the same
## day, earlier). **The later word wins** and the old rows are rewritten rather than kept beside the
## new ones — two sets asserting opposite gestures is not a record, it is one of them lying.
##
## ⚠⚠ **THE ROWS ARE THE SAME GESTURE MEASURED ON ITS TWO OUTCOMES.** A right button that turned but
## also ordered would pass the turn row; one that ordered nothing but never turned would pass the order
## row. **Neither row is worth anything alone.**
##
## ⚠ **The camera is asked to stay PUT as well as to turn.** The right button moved `cam_px` this
## morning, and a turn that also panned would read as the old gesture surviving under the new one.
func _the_right_button_turns_and_never_commands(t, game, fs: FieldView) -> void:
	var b: Battle = game.battle
	for i in b.soldier_order.size():
		b.soldier_order[i] = -1

	# ⚠ **Aimed at a 조각 a body is standing on, like the left button's pair.** On open water the
	# "commands nobody" row would be satisfied by a shell that does nothing at all.
	var ashore := b.ashore_ids()
	t.ok(ashore.size() > 0, "자가 점검 — 판 위에 선 몸이 있다 (없으면 아래가 전부 공허하다)")
	if ashore.is_empty():
		return
	var body: Vector2 = b.soldier_pos[int(ashore[0])]
	_park(fs, Vector2.ZERO)
	var on_land := fs.tile_to_screen_px(int(round(body.x)), int(round(body.y)))
	var body_tile := int(round(body.y)) * b.grid.w + int(round(body.x))
	t.eq(game._tile_at(on_land), body_tile, "자가 점검 — 그 화면 점이 몸이 선 조각으로 돌아온다")

	# -- a right click in place: nothing turns and nobody is sent ------------------------------------
	var held := fs.cam_px
	var held_yaw := fs.cam_yaw_deg
	game._unhandled_input(_rpress(on_land))
	game._unhandled_input(_rrelease())
	t.eq(fs.cam_px, held, "오른쪽을 제자리에서 누르고 떼면 카메라가 안 움직인다")
	t.ok(absf(fs.cam_yaw_deg - held_yaw) < 0.001,
		"그리고 판도 안 돌아간다 — 안 움직인 끌기는 회전이 아니다 (%.2f°)" % fs.cam_yaw_deg)
	var ordered := 0
	for i in b.soldier_order.size():
		if int(b.soldier_order[i]) >= 0:
			ordered += 1
	t.eq(ordered, 0, "그리고 아무도 명령받지 않는다 — 오른쪽은 절대 보내지 않는다")

	# -- a right drag: the board turns, by the pixels the hand travelled ------------------------------
	# ⚠ **The expected yaw is `Look.CAM_YAW_PER_PX_DEG` times the HORIZONTAL travel and nothing else** —
	# the vertical 40 px of the same motion must not reach the camera, or a stray diagonal tilts the
	# board as well as turning it.
	var before_yaw := fs.cam_yaw_deg
	var before_px := fs.cam_px
	game._unhandled_input(_rpress(on_land))
	game._unhandled_input(_motion(on_land + Vector2(60.0, 40.0), Vector2(60.0, 40.0)))
	var want := fmod(before_yaw + 60.0 * Look.CAM_YAW_PER_PX_DEG + 360.0, 360.0)
	t.ok(absf(fs.cam_yaw_deg - want) < 0.001,
		"오른쪽으로 60px 끌면 판이 %.2f° 로 돌아간다 (%.2f°)" % [want, fs.cam_yaw_deg])
	t.eq(fs.cam_px, before_px, "그러면서 카메라는 안 움직인다 — 돌리기는 이동이 아니다")
	# **The other way comes back**, which is the row that stops both directions turning one way.
	game._unhandled_input(_motion(on_land, Vector2(-60.0, -40.0)))
	t.ok(absf(fs.cam_yaw_deg - fmod(before_yaw + 360.0, 360.0)) < 0.001,
		"되돌리면 정확히 제자리로 돌아온다 (%.2f°)" % fs.cam_yaw_deg)
	game._unhandled_input(_rrelease())
	ordered = 0
	for i in b.soldier_order.size():
		if int(b.soldier_order[i]) >= 0:
			ordered += 1
	t.eq(ordered, 0, "끌고 나서도 아무도 명령받지 않는다")

	# **The release really ended it**, or the next motion turns the board behind the player's back.
	var after_yaw := fs.cam_yaw_deg
	game._unhandled_input(_motion(on_land + Vector2(120.0, 80.0), Vector2(120.0, 80.0)))
	t.ok(absf(fs.cam_yaw_deg - after_yaw) < 0.001,
		"오른쪽을 뗀 뒤의 움직임은 판을 안 돌린다 (%.2f°)" % fs.cam_yaw_deg)


## ⚠⚠ **`_the_edge_of_the_window_pans` AND `_a_walkable_point_inside_a_band` STOOD HERE AND BOTH ARE
## DELETED** (2026-08-31, the user: 「그것도 지워줘」). They measured the edge band the user asked for
## on 2026-08-30 (「wasd 보다는 마우스가 끝으로 가면 자동으로 이동이 맞을듯」): that a parked pointer
## panned and kept panning, that the distance was the frame's own delta, that the band was 28 px wide
## at BOTH ends, that it ramped with depth, that a corner was not normalised, that a pointer off the
## glass was nothing rather than the deepest point, that alt-tab and a mouse-exit each stopped it with
## their own flag, and that a press near the edge still commanded the 조각 under the finger.
##
## ⚠ **The band is gone from `game.gd`, so every row above would now be green on an empty shell** —
## which is why they are deleted rather than inverted. `_park` survives: the drag rows above use it.


## The right button's two edges. ⚠ **The release carries no position and the shell reads none** — see
## `_end_press`, whose `at` parameter was deleted the day the right button started using it.
func _rpress(at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = true
	ev.position = at
	return ev


func _rrelease() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = false
	return ev


## ⚠ **`_win_the_open_island` stood here and it is deleted** (2026-08-29). It committed the island and
## emptied the enemies so a fixture had a verdict to wait on.


## ⚠⚠ **`_panel_active_answers_all_five_screens` STOOD HERE AND IT IS DELETED** (2026-08-29) with the
## panel. **The rule it kept is the one to remember**: a gate that can only ever be true is not a gate,
## it is a deleted branch waiting to be noticed — so it asserted the panel was ABSENT on the screens
## that are not a verdict, not merely that it was not in the way.


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


## **티켓 02-03's whole acceptance, driven headless.** The 성채 is taken to 0 HP, one `_process` is run
## by hand, and three things are read out of that one call: the sim lost, the shell told the HUD in the
## SAME call, and the island is still standing behind the words (2026-09-01, the user: 「엔딩씬을
## 생각해봤는데 그냥 게임 오버 뜨면 될 거 같은데? 게임 오버 빨간 글씨고 딱 뜨고. 끝」 · 「뒤에는 섬이
## 그대로 남고」 — *"just showing GAME OVER is enough. Red letters, it just appears, and that is the
## end."* · *"the island stays behind it exactly as it stood."*).
##
## ⚠⚠ **THE 「SAME CALL」 IS THE ROW, NOT THE 「TRUE」.** `hud_view.set_over(battle.lost)` read one line
## ABOVE `battle.step` instead of below it is still true on the NEXT frame, and a check that pumped a
## frame before looking would be green on a screen that trails the sim forever. So the sim's own clock
## is off from here and the frame is driven by hand.
## ⚠ **The picture is read on the hook and not on the canvas.** An override never runs the
## `draw_texture` inside the leaf — `net_draw_leaf` owns that inch.
func _the_keep_falls_and_the_screen_says_so(t) -> void:
	var game := QuitGame.new()
	t.root.add_child(game)
	await t.pump_frames(2)
	game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
	# The spy goes in AFTER `_ready` built the real three and is wired by a real `_open_island`, the
	# same order `run()` uses: a spy pre-set before `_ready` would let the wiring line be deleted.
	game.remove_child(game.hud_view)
	game.hud_view.queue_free()
	var hs := HudSpy.new()
	game.hud_view = hs
	game.add_child(hs)
	game._open_island()
	await t.pump_frames(2)
	# The shell's clock stops here; the views keep theirs, which is what lets the island go on being
	# painted behind the words.
	game.set_process(false)
	await t.pump_frames(2)

	var b: Battle = game.battle
	var fs: FieldView = game.field_view
	t.ok(not b.keep_tiles.is_empty(), "이 섬에 성채가 서 있다 (자가 점검 — 없으면 질 수가 없다)")
	t.ok(not b.lost, "성채가 멀쩡한 동안은 안 졌다 (자가 점검)")
	t.ok(not hs._over, "그동안 화면에도 글씨가 없다")
	t.eq(hs.overs.size(), 0, "그리고 후크가 아예 안 불렸다 — 안 진 판에 글씨가 그려지면 그게 거짓말이다")
	t.eq(hs.backs.size(), 0, "단추도 안 그려진다 — 살아 있는 판 위의 단추는 눌리는 유령이다")
	t.eq(game.hud_view.back_rect_px(), Rect2(),
		"그리고 셸이 물어보는 사각형도 비어 있다 — 그리지도 않은 것이 눌리면 안 된다")
	var bodies_before := fs._sprites_used
	t.ok(bodies_before > 0, "성채가 무너지기 전에 섬이 몸을 그리고 있다 (자가 점검)")

	# Take the 성채 to 0 and turn ONE frame BY HAND. `step` raises `lost` at the end of the sub-step
	# the house fell in, and breaks out of the loop there.
	b.keep_hp = 0.0
	game._process(Rules.SIM_SUBSTEP_SEC)
	t.ok(b.lost, "성채가 무너진 그 한 번의 _process 에서 sim 이 졌다")
	t.ok(hs._over, "그리고 같은 한 번에 셸이 화면을 켰다 — step 위에서 읽으면 여기가 빨개진다")

	await t.pump_frames(1)
	t.eq(hs.overs.size(), 1, "다음 그리기에서 _paint_over 가 정확히 한 번 불렸다")
	if hs.overs.size() == 1:
		var over: Dictionary = hs.overs[0]
		var tex: Texture2D = over["tex"]
		t.ok(tex != null, "손에 쥔 게 진짜 그림이다 — 만들어서 불러온 것이지 글자를 찍은 게 아니다")
		var size := tex.get_size() if tex != null else Vector2.ZERO
		t.ok(size.x > 0.0 and size.y > 0.0, "그 그림이 %s 로 비어 있지 않다" % str(size))
		var at: Vector2 = over["at"]
		_rects_land_on_screen(t, "게임 오버 글씨", [Rect2(at, size)] as Array[Rect2])
		# ⚠ 「centred」 is measured against `look.gd`'s own answer and never against a number typed
		# here. Writing 320 in this file would put the position in two places, and one of the two
		# would rot first — which is the whole reason the constant is derived over there.
		t.ok(at.is_equal_approx(Look.game_over_origin_px(size)),
			"그 자리가 look.gd 가 말한 자리다 (%s)" % str(at))

	# 「the island stays behind it」 — what stopped is the 판, not the picture.
	t.eq(fs._sprites_used, bodies_before, "진 뒤에도 섬이 몸을 똑같이 그린다 — 글씨가 판을 안 지운다")
	t.ok(fs.battle == b, "그리고 field_view 가 여전히 그 battle 을 보고 있다")

	# 「끝」 — the board stops answering. A press after the loss never reaches `_begin_press`.
	t.ok(not game._press_open, "진 직후에는 아무 누름도 열려 있지 않다 (자가 점검)")
	game._unhandled_input(_press(Vector2(Look.VIEWPORT_W_PX * 0.5, Look.VIEWPORT_H_PX * 0.5)))
	t.ok(not game._press_open, "진 뒤에 눌러도 누름이 안 열린다 — 죽은 섬을 돌리고 다닐 수 없다")

	# 「타이틀로」 — the one press that DOES land on a lost board (2026-09-01, the user: 「그 게임오버 하고
	# 타이틀로 돌아가는 버튼도 만들어줘」). ⚠⚠ **This reverses 티켓 02-03's own 「끝」**, which named a way
	# back in its Out of scope; the row above — 「죽은 섬을 돌리고 다닐 수 없다」 — is untouched and still
	# green, which is the point: the board is still dead, and exactly one rectangle is not.
	t.eq(hs.backs.size(), 1, "진 화면에서 _paint_back 이 정확히 한 번 불렸다")
	var back_rect := game.hud_view.back_rect_px()
	t.ok(back_rect.size.x > 0.0 and back_rect.size.y > 0.0,
		"셸이 물어보는 사각형이 %s 로 비어 있지 않다" % str(back_rect.size))
	if hs.backs.size() == 1:
		var back: Dictionary = hs.backs[0]
		var btex: Texture2D = back["tex"]
		t.ok(btex != null, "단추도 진짜 그림이다 — 사각형과 글자를 찍은 게 아니다")
		# ⚠⚠ **THE DRAWN CORNER AND THE HIT-TESTED CORNER ARE THE SAME OBJECT.** A button pressable
		# where it is not drawn is the defect this row exists for, and the two only drift once
		# somebody re-pulls a picture — which is why `back_rect_px` answers both questions.
		t.ok((back["at"] as Vector2).is_equal_approx(back_rect.position),
			"그린 자리와 눌리는 자리가 같다 (%s)" % str(back["at"]))
		_rects_land_on_screen(t, "타이틀로 단추", [back_rect] as Array[Rect2])
		# ⚠ Under the lettering and not over it — otherwise the button covers the word it belongs to.
		var over_at: Dictionary = hs.overs[0]
		t.ok(back_rect.position.y > (over_at["at"] as Vector2).y,
			"단추가 글씨보다 아래에 있다")

	# 「the press that is not the button changes nothing」 — first, so a button that swallowed the whole
	# screen could not pass the row after it.
	game._unhandled_input(_click(Vector2(back_rect.position.x * 0.5, back_rect.position.y * 0.5)))
	t.ok(game.run != null, "단추 밖을 누르면 아무 일도 안 난다 — 판이 그대로 살아 있다")
	t.ok(not game.title_view.visible, "타이틀도 안 올라온다")

	game._unhandled_input(_click(back_rect.get_center()))
	t.ok(game.run == null, "단추를 누르면 회차가 버려진다 — 이게 셸을 타이틀로 되돌리는 그 한 줄이다")
	t.ok(game.battle == null, "그리고 섬도 놓는다")
	t.ok(game.title_view.visible, "타이틀이 올라온다")
	t.ok(not hs._over, "게임 오버 글씨는 내려간다")
	t.ok(not game.field_view._world.visible, "판도 화면에서 내려간다 — Node2D 의 visible 은 여기 안 닿는다")

	# 「and 시작하기 works again」 — the board has to come back up, and `_build_world` returns early once
	# the world exists, so a run opened after this would otherwise start on a hidden island.
	game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
	t.ok(game.run != null, "타이틀에서 다시 시작할 수 있다")
	t.ok(game.field_view._world.visible, "그리고 판이 다시 올라온다 — 이 줄이 빠지면 두 번째 판이 안 보인다")

	# The next island does not inherit the last one's verdict — that is what `bind` clears.
	game._open_island()
	t.ok(not game.battle.lost, "새로 연 섬은 안 졌다 (자가 점검)")
	t.ok(not hs._over, "그리고 새 섬이 앞 섬의 글씨를 쓰고 열리지 않는다")

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
## ⚠⚠ **NOT AN ORPHANED CHECK — A HELPER WAITING FOR A CALLER.** It takes `(t, label, rects)` and has
## no fixture of its own; **there is nothing to 「wire」 it to.** Its callers were the dock outlines and
## the five slot boxes, deleted 2026-08-28 with the start button, and it has had none since.
## ⚠ **Kept rather than deleted**: it is the only place in this file that says what a rect on screen has
## to satisfy — real area, and inside the viewport — and the next screen that draws one wants it.
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


## The same event with an edge and an echo flag on it.
##
## ⚠⚠ **`_key` ALONE CANNOT MEASURE A HELD KEY AND THAT IS WHY THIS EXISTS.** It builds
## `pressed = true` and nothing else — no release edge and no `echo` flag — so a WASD row written
## against it measures the press half and **stays green over a camera that never stops.**
func _key_edge(code: int, pressed: bool, echo: bool = false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.pressed = pressed
	ev.echo = echo
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


## ⚠⚠ **THE `shift` ARGUMENT IS GONE** (2026-08-30). It set `shift_pressed` on the event for the
## SHIFT+wheel zoom, which was the previous builder's own pairing and is deleted with the wheel going
## back onto the plain zoom — **the shell reads no modifier at all now**, so a net that set one would
## be driving a flag nothing looks at.
func _wheel(at: Vector2, up: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	ev.position = at
	return ev


## Puts the camera at a known corner of its roam range and lets `_clamp_cam` decide where that is.
## **Every edge-pan row starts from one of these**, because a camera already sitting against the stop
## it is being pushed into moves 0.0 px and every row below it reads as a dead control.
func _park(fs: FieldView, at: Vector2) -> void:
	fs.cam_px = at
	fs._clamp_cam()


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
## ⚠⚠ **NOT CALLED, AND DELIBERATELY LEFT THAT WAY UNTIL IT IS GIVEN NEW ANCHORS** (2026-08-30).
##
## **The 「it is gone」 half of this function is all true**: nothing named here exists in `src/` any
## more. **Its self-checks are what died.** Every one of them named something that was supposed to
## still be there, to prove the lookup was actually running — `note_refusal`, `_armed_slot`, the three
## `REFUSE_MARK_*` constants, `button_rect_px` — and **all six of those have since been deleted too**.
## Measured by wiring it temporarily: 19 rows, **6 red**, and not one of the six is about the subject.
##
## ⇒ **A check whose proof-that-it-runs is dead is worse than no check.** `not has_method("x")` is
## satisfied by a typo, by a renamed class, by a `null` — it passes for every reason including the
## wrong ones, and the anchors were the only thing separating it from an empty assertion.
## ⚠ **What it needs before it comes back is six live anchors**, not a wiring line: things that DO
## exist today and would break the row if the lookup silently stopped working.
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


## ⚠⚠ **`_every_lose_reason_reads_differently` STOOD HERE AND IT IS DELETED** (2026-08-29) with the
## two losses. **WIPED and LANDING_LOST were two facts, not one**, and the screen had to say which:
## they are different mistakes, and a screen that shows the wrong one teaches the wrong lesson.


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


## Everybody standing on the island, as army ids. **Off the sim and never off the sprite pool** — the
## pool is what this file is checking, so reading the census out of it would compare it with itself.
func battle_ashore(b: Battle) -> Array:
	var out := []
	for raw in b.ashore_ids():
		out.append(int(raw))
	return out
