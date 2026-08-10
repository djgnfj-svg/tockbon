extends RefCounted
## Can the screen side **stand up.** Not "the drawn picture", which a net cannot measure in principle,
## but **the things that die before drawing.**
##
## **Why it exists — a measurement.**
##  At stage 5, adding the `flag_tex` uniform passed a sampler as a function argument
##  (`l8_to_int(TEXTURE, ...)` and `l8_to_int(flag_tex, ...)`) and the Godot shader compiler
##  **failed to compile**, saying the same sampler argument cannot be called with both a built-in and a uniform.
##  And yet **the game did not stop** — the grid was drawn with the raw L8 byte values (stone 1 · wood 2 ·
##  empty 0), giving a near-black screen, with only the character drawn by `_draw()` showing in its real colors.
##  **In that state 534 nets were all green.**
##
## => This repo's representative silent death ("the nets are green but the screen does not come up") has exactly
##  that shape. A shader is **the one asset the engine quietly gives up on**, so it is worth measuring separately.

const VIEW_DIR := "res://src/view"
const STAGE_SCENE := "res://src/stage/stage.tscn"
const STAGE_SCRIPT := "res://src/stage/stage.gd"
const STAGE_INPUT_SCRIPT := "res://src/stage/stage_input.gd"
const CIRCLE_WINDOW_SCRIPT := "res://src/view/circle_window.gd"
## The comment/string stripper is **borrowed** — three nets sweep source text, so there must be one stripper.
const NetDeterminism := preload("res://tests/nets/net_determinism.gd")
## **Borrowed, not copied** — `_scan_gd_files` is `net_progress.gd`'s own recursive `.gd`-file walker, reused
## here for the same reason `NetDeterminism._strip` is borrowed above: a second copy of a directory scanner
## is exactly the kind of thing that drifts the day only one of the two gets fixed.
const NetProgress := preload("res://tests/nets/net_progress.gd")
const CellRenderer := preload("res://src/view/cell_renderer.gd")
const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Fx := preload("res://src/view/fx_tuning.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const Layout := preload("res://src/view/pick_layout.gd")
const CircleLayout := preload("res://src/view/circle_layout.gd")
const ThreePickWindow := preload("res://src/view/three_pick_window.gd")

## The HUD's `CanvasLayer`. **This is exactly the layer that decides whether left-click reaches firing.**
const HUD_PATH := "HUD"

## **Nodes that are allowed to eat clicks.** A `Control` not listed here that is `STOP` kills left-click quietly.
##  **Keeping the list by hand is itself the contract.** Attach a new window without listing it and the net
##   barks first; list it and "this one eats clicks on purpose" stays in the repo. Work it out automatically
##   and that declaration disappears.
## **`HUD/ResearchWindow` added here** (`research-bench-unlocks.md`) — the bench sells
##  three unlocks now, so its chips have to be pressable and it has to be `STOP` like the other three.
##
## **This entry is written *before* the `mouse_filter` 2 -> 0 edit lands in `stage.tscn`, deliberately, and
##  the order matters.** Flip the scene first and this net goes red — and the cheapest-looking fix is to put
##  `mouse_filter` back to `IGNORE`, which turns every net in the suite green again **while making the entire
##  research feature unreachable**: the window would open, draw its chips, print its prices, and refuse to be
##  pressed, with nothing barking. That is precisely the failure CLAUDE.md is built around (the settlement
##  panel that shipped under 5,576 green checks with `visible` never set). ⇒ **If this line is here and the
##  scene still says `IGNORE`, the check below is what says so, out loud.**
const INTERACTIVE: Array[String] = [
	"HUD/CircleWindow", "HUD/ThreePickWindow", "HUD/SettlementWindow", "HUD/ResearchWindow",
]

## **The old `WINDOW_SCREEN_FRAC` (90% on each axis) was deleted.** The contract was never about size —
##  "the character and its surroundings are visible" is the contract, and 90% was the value that **deferred** it.
##  The deferral ended once the character could be hurt (user's acceptance) =>
##   `_window_does_not_cover_*` below measures **whether it covers or not.**
const Character := preload("res://src/actor/character.gd")
const Stage := preload("res://src/stage/stage.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
## Stage I (`stage1-bosses.md`) — the reward-taken debug key (L) and room ①'s own water pour.
const MonsterDefs := preload("res://src/actor/monster_defs.gd")
## Stage D (`rune-lock-and-receiving.md`) — the preset key must not wipe an earned rune.
const CircleDefs := preload("res://src/sim/circle_defs.gd")
const SpellCircle := preload("res://src/actor/spell_circle.gd")


func run(t) -> void:
	_the_debug_readout_is_off_at_boot_and_f3_turns_it_on(t)
	var shaders := _scan_shaders(VIEW_DIR)
	# The first line of a folder-scanning net. Sweeping an empty list runs none of the below and passes green.
	t.ok(shaders.size() > 0, "%s 에서 셰이더를 찾았다 (%d개)" % [VIEW_DIR, shaders.size()])
	for path: String in shaders:
		_compiles(t, path)
	_injection_matches_shader(t)
	_palette_size_matches(t)
	_onready_paths_resolve(t)
	_mouse_filter_contract(t)
	_window_uses_the_tuning_rect(t)
	_input_actions_exist(t)
	_hud_counts_are_throttled(t)
	_hud_controls_are_inside_the_viewport(t)
	_progress_text_survives_the_assembly_window(t)
	_opening_one_window_closes_the_other(t)
	_esc_closes_whichever_key_opened_window_is_open(t)
	_pick_toggle_closes_from_the_open_state(t)
	_pick_with_nothing_pending_does_not_touch_the_window(t)
	_declining_a_pick_leaves_the_circle_byte_identical(t)
	_pick_window_never_writes_its_own_mouse_filter(t)
	_tab_during_confirmation_afterglow_closes_it_first(t)
	_physics_process_actually_ticks_confirm_before_the_hud_reacts(t)
	_reset_stage_actually_cancels_the_confirmation_afterglow(t)
	_pressing_the_key_after_the_auto_grant_changes_nothing_further(t)
	_reward_key_before_any_death_does_nothing(t)
	_reward_key_is_wired(t)
	_the_bull_reward_grants_itself_with_no_key_pressed(t)
	_a_rooster_death_does_not_touch_the_bulls_reward_gate(t)
	_a_preset_key_does_not_wipe_an_earned_rune(t)
	_a_preset_key_still_works_with_the_circle_removed(t)
	_reset_revokes_a_rune_from_the_seat_it_no_longer_owns(t)
	_reset_does_not_touch_glyphs(t)
	_revoke_unowned_rune_only_touches_what_is_not_owned(t)
	_developer_keys_are_gated_behind_f3(t)
	_the_help_lines_only_name_keys_that_exist(t)
	await _the_camera_sits_on_whole_screen_pixels(t)


## **Calling an action that is not in the input map makes the engine bark, and on screen it only looks like
## "that one key does not work".**
##
## **`has_action` alone cannot rule out "Tab does not work"** — measured:
##  **emptying only the key bindings** of an action (`events: []`) leaves `has_action` true and the nets all green.
##  => **Is the name there** and **is a key attached** must **both** be measured to erase that one cause.
##
## The remaining cause (focus) is measured not here but by `_mouse_filter_contract` via `focus_mode`.
##  **Do not write "this check erases one cause" before both are measured** — a false guarantee is worse than none.
##   The next session reads that sentence and digs the diagnosis in the opposite direction.
##
## The names are not written by hand but **pulled from the source.** Written by hand they go stale quietly as actions grow.
## Writing `is_action_pressed("...")` inside a comment gets picked up as a requirement too —
##  a false positive, but it fails **red** so it does not leak quietly.
func _input_actions_exist(t) -> void:
	var src := _read(STAGE_INPUT_SCRIPT)
	var wanted: Dictionary = {}
	for pattern: String in [
		"is_action[a-z_]*\\(\\s*\"([A-Za-z0-9_]+)\"",
		"get_axis\\(\\s*\"([A-Za-z0-9_]+)\"\\s*,\\s*\"([A-Za-z0-9_]+)\"",
	]:
		var re := RegEx.new()
		t.eq(re.compile(pattern), OK, "액션 패턴이 컴파일된다")
		for m: RegExMatch in re.search_all(src):
			for g in range(1, m.get_group_count() + 1):
				var nm := m.get_string(g)
				if nm != "":
					wanted[nm] = true
	# Finding none runs nothing below and **goes green.**
	t.ok(wanted.size() > 0, "껍데기가 부르는 입력 액션을 찾았다 (%d개)" % wanted.size())
	for nm: String in wanted.keys():
		t.ok(InputMap.has_action(nm), "입력 맵에 액션 `%s` 가 있다" % nm)
		# An action with a name but no key attached is **never pressed, ever.** The `has_action` above is true.
		t.ok(InputMap.action_get_events(nm).size() > 0,
			"액션 `%s` 에 키가 붙어 있다 (이름만 있으면 영영 안 눌린다)" % nm)


## **This is failure mode 1 of this shell** (`stage.gd` wrote it down itself).
##  Firing is left-click and the HUD is a `Control` — the moment one backing panel is left at the default (`STOP`),
##  **left-click is eaten whole, no error is raised, and every net is green.**
##
## **Both sides are dangerous:**
##  · all `STOP`   -> firing dies. The screen looks fine
##  · all `IGNORE` -> **magic fires every time you click the window**
##
## So measuring one direction only is not enough — below measures **both**:
##  an undeclared `Control` must be `IGNORE`, and a declared one must be `STOP`.
##
## **Only the HUD's direct children are looked at. The grounds are written down exactly:**
##  · `CircleWindow`'s children are **already inside the interactive area**, so no value there reaches firing —
##    recursing would only add false alarms at stages 3-5 (layers · rune slots · palette)
##  · **There is not one child-of-a-child under any other HUD child yet.** => It is not a hole today
##
## **But "if the parent is IGNORE the children are too" is false.** `mouse_filter` is not inherited.
##  If a sized `STOP` child appears under `HUD/Stats` (8,8-900,210), **the entire top-left click dies** and
##  this check **does not see it.** => The day such a child is made, open this function up to recursion.
func _mouse_filter_contract(t) -> void:
	var scene: PackedScene = load(STAGE_SCENE)
	if scene == null or not scene.can_instantiate():
		# Same reason as above — slipping out quietly leaves **not one line** of the `mouse_filter` contract measured.
		t.ok(false, "무대 씬을 못 세워서 mouse_filter 계약을 **하나도 못 쟀다**")
		return
	var root := scene.instantiate()
	var hud := root.get_node_or_null(HUD_PATH)
	t.ok(hud != null, "씬에 %s 가 있다" % HUD_PATH)
	if hud == null:
		root.free()
		return

	# Same reason as the first line of a folder-scanning net — 0 children runs none of the below and goes green.
	var seen := 0
	for child in hud.get_children():
		if not (child is Control):
			continue
		seen += 1
		var ctl := child as Control
		var path := "%s/%s" % [HUD_PATH, ctl.name]
		if INTERACTIVE.has(path):
			t.eq(ctl.mouse_filter, Control.MOUSE_FILTER_STOP,
				"%s 는 클릭을 먹는다 (STOP — 여기 클릭은 발사가 아니다)" % path)
		else:
			t.eq(ctl.mouse_filter, Control.MOUSE_FILTER_IGNORE,
				"%s 는 클릭을 통과시킨다 (IGNORE — 좌클릭이 발사로 간다)" % path)
	t.ok(seen > 0, "%s 아래 Control이 있다 (%d개)" % [HUD_PATH, seen])
	# If the declaration is empty the loop above only measures "everything must be IGNORE", and then
	#  **it stays green even if the window disappears.**
	t.ok(INTERACTIVE.size() > 0, "클릭을 먹는 노드가 선언돼 있다 (%d개)" % INTERACTIVE.size())
	for path: String in INTERACTIVE:
		t.ok(root.get_node_or_null(path) != null, "선언된 %s 가 씬에 실재한다" % path)

	# The window starts **closed.** Starting open hides the first screen, and the user reads that state as
	#  "the window will not close".
	var win := root.get_node_or_null("HUD/CircleWindow") as Control
	t.ok(win != null and not win.visible, "조립창이 닫힌 채로 시작한다")

	# **The second cause of Tab not working is here.** If a `Control` inside the window takes focus,
	#  Tab is **consumed by the GUI** as `ui_focus_next` and never reaches `_unhandled_input`.
	#  The symptom is **identical** to "the input map was not fixed", so it is easy to dig the wrong way —
	#   which is why the input map side (`_input_actions_exist`) and this must **both** be measured for the
	#   diagnosis to split.
	#  Measured: switching `focus_mode` to ALL left all 50 nets green.
	if win != null:
		t.eq(win.focus_mode, Control.FOCUS_NONE,
			"조립창이 포커스를 못 잡는다 (Tab이 GUI에 안 먹힌다)")

	_window_leaves_the_stage_visible(t, root)

	# **The pick window's own copy of the same three guarantees** — `Fx.PICK_RECT` was not inheriting
	#  `Fx.WINDOW_RECT`'s coverage just because it is defined as an alias of it (`PICK_RECT := WINDOW_RECT`).
	#  Measured: moving `PICK_RECT` entirely off the 960x540 canvas passed the full suite, because nothing
	#  named `PICK_RECT` — the only reference outside `three_pick_window.gd` was a **comment** in `net_pick.gd`.
	var pick_win := root.get_node_or_null("HUD/ThreePickWindow") as Control
	t.ok(pick_win != null and not pick_win.visible, "뽑기 창이 닫힌 채로 시작한다")
	if pick_win != null:
		t.eq(pick_win.focus_mode, Control.FOCUS_NONE,
			"뽑기 창이 포커스를 못 잡는다 (P/Tab이 GUI에 안 먹힌다)")
	_pick_window_leaves_the_stage_visible(t, root)
	root.free()


## **`Fx.PICK_RECT`'s own copy of `_window_leaves_the_stage_visible`** — read by name, not inherited by being
## defined as `WINDOW_RECT`'s alias. An alias is a value equality today; it is not a proof that stays true if
## either constant is ever repointed, and until this function existed nothing measured `PICK_RECT` at all.
func _pick_window_leaves_the_stage_visible(t, root: Node) -> void:
	var r: Rect2 = Fx.PICK_RECT
	var vw := float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var vh := float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	t.ok(r.size.x > 0.0 and r.size.y > 0.0, "뽑기 창에 크기가 있다 (%dx%d)" % [
		int(r.size.x), int(r.size.y)])
	t.ok(r.position.x >= 0.0 and r.position.y >= 0.0 and r.end.x <= vw and r.end.y <= vh,
		"뽑기 창이 화면 안에 들어간다 (%s ~ %s)" % [r.position, r.end])

	var hp := root.get_node_or_null("HUD/HpBar") as Control
	t.ok(hp != null, "씬에 HUD/HpBar 가 있다 (전제)")
	if hp != null:
		# **`_ready()` is driven by hand, and that is the point** — the gauge takes its rectangle from
		#  `Fx.HP_RECT` there rather than from scene offsets (the same idiom `circle_window` uses for
		#  `WINDOW_RECT`), so an untreed node is 0x0 until it runs. Skipping this would make the size assert
		#  below measure the scene file, which no longer carries the number.
		hp.call("_ready")
		var box := Rect2(hp.position, hp.size)
		t.ok(box.size.x > 0.0 and box.size.y > 0.0,
			"체력 표시에 크기가 있다 (%dx%d — 0이면 아래 검사가 공짜로 통과한다)"
				% [int(box.size.x), int(box.size.y)])
		t.ok(not r.intersects(box),
			"뽑기 창이 체력 표시(%s~%s)를 안 덮는다" % [box.position, box.end])

	t.eq(Fx.PICK_BG.a, 1.0, "뽑기 창 배경이 불투명하다 (겹친 HUD 글씨가 안 섞인다)")

	# **The checks above measure only the constant `Fx.PICK_RECT` — they do not look at whether the window
	#  actually uses it.** A text-scan for `"PICK_RECT"` in the source was tried first and **evaded**: adding
	#  `Vector2(600.0, 500.0)` after the read still contains the substring, builds no numeric `Rect2` of its
	#  own, and left every check green while the real runtime rect moved to (648,512)-(1512,884), entirely off
	#  the 960x540 canvas. `_ready()` is an ordinary method — callable on an untreed `Control` the same way
	#  `net_pick._gui_input_drives_the_real_window_state` already calls `_gui_input` — so **the actual value is
	#  measured directly** instead: instantiate the window, run `_ready()`, and check the rect it ends up at.
	var probe := ThreePickWindow.new()
	probe.call("_ready")
	var actual := Rect2(probe.position, probe.size)
	t.eq(actual, Fx.PICK_RECT, "`_ready()`를 실제로 돌리면 창이 `Fx.PICK_RECT`가 말하는 자리·크기 그대로다")
	t.ok(Rect2(0.0, 0.0, vw, vh).encloses(actual),
		"`_ready()`가 만든 실제 사각형이 화면 안에 들어간다 (상수가 아니라 실행 결과로 잰다)")
	probe.free()


## **If the window covers the whole stage, "the world does not stop" cannot be confirmed by eye** (plan risk 11).
##  And overlapping `HUD/Stats` mixes the text together (risk 12) — both are screen problems, so **no error is raised.**
## The single source of the dimensions is `fx_tuning`, so **that value is measured.** Measuring the scene's
##  offsets would make two places.
func _window_leaves_the_stage_visible(t, root: Node) -> void:
	var r: Rect2 = Fx.WINDOW_RECT
	var vw := float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var vh := float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	t.ok(vw > 0.0 and vh > 0.0, "뷰포트 크기를 읽었다 (%dx%d)" % [int(vw), int(vh)])
	t.ok(r.size.x > 0.0 and r.size.y > 0.0, "조립창에 크기가 있다 (%dx%d)" % [
		int(r.size.x), int(r.size.y)])
	t.ok(r.position.x >= 0.0 and r.position.y >= 0.0 and r.end.x <= vw and r.end.y <= vh,
		"조립창이 화면 안에 들어간다 (%s ~ %s)" % [r.position, r.end])

	# **The "the window does not cover the character" check was scrapped** — see the deletion note below.
	#  The health side is alive: `HUD/HpBar` sits on a `CanvasLayer`, so it is in **the same screen coordinate
	#  space as the window**, and its position does not change however the camera moves.
	_window_does_not_cover_the_health(t, root, r)

	# **At 90% it does cover `HUD/Stats`. What makes that safe is that the window is opaque.**
	#  The old check was "they do not overlap" and its grounds were risk 12 ("overlapping mixes the text"),
	#   but that risk belongs to **a translucent window.** An opaque window does not mix, it **covers.**
	#  => Instead of forbidding overlap, **the condition under which overlap is fine** is measured.
	#   Revert to translucent and this goes red.
	var stats := root.get_node_or_null("HUD/Stats") as Control
	t.ok(stats != null, "씬에 HUD/Stats 가 있다")
	t.eq(Fx.WINDOW_BG.a, 1.0, "창 배경이 불투명하다 (겹친 HUD 글씨가 안 섞인다)")


# -- "the window does not cover the character" — **scrapped** ------
# **The contract died** (user's acceptance). With camera follow in, the character is **always at the center of
#  the screen** while the window is 90% of the screen and covers it. **The user chose "leave it as is" knowing the price.**
#  => A check measuring a contract that does not exist is a fake net, so it was deleted. The grounds are in the
#  `fx_tuning.WINDOW_RECT` comment.
#
# **It was confirmed by value before deleting.** Window (48,12)-(912,384) vs the character's screen position:
#   spawn (96,240)-(128,380) · world center (464,146)-(496,286) — **both inside the window.**
# **The check was not wrong; the contract died** — as a control, moving the window to `Rect2(48,400,864,130)`
#  went **green.** The check was fine.
#
# **And until it was deleted this check was a "false green". That is the asset to leave here.**
#  The old code compared the character's **world** position against `WINDOW_RECT` (which is on a `CanvasLayer`,
#  i.e. **screen** coordinates).
#  While the camera was the identity, world = screen so it matched **by accident**, and **the moment the camera
#  moved the two coordinate spaces diverged while all 1328 nets stayed green.**
#  => **A check that mixes coordinate spaces dies quietly the day the camera moves.** Read this line before
#   comparing a screen-side value against a world value.


## **The window does not cover the health readout.** `_toggle_assembly` hides only `HUD/Stats`; `Health` is
##  **not hidden, it is covered** => the window must step aside so health stays visible while assembling.
## **The reason for measuring size first is written down exactly** — it first said "if the size is 0,
##  `intersects` is always false and it passes quietly", and **that was false.** Measured:
##  **`Rect2.intersects` only filters by edges, so a degenerate rectangle inside gives `true`** —
##   a zero-size rectangle at the center of the window **comes out as overlapping.** And `Health` is a `Label`,
##   so its size is at least `(1,23)` — **0 was not even reachable.**
##  => What this line actually catches is the different defect **"`Health` lost its size"**, and that is still worth having.
## **Do not read this as "Rect2 does not overlap at size 0"** — write a check elsewhere on that premise and it spins idle.
func _window_does_not_cover_the_health(t, root: Node, r: Rect2) -> void:
	var hp := root.get_node_or_null("HUD/HpBar") as Control
	t.ok(hp != null, "씬에 HUD/HpBar 가 있다")
	if hp == null:
		return
	# `_ready()` is what gives it `Fx.HP_RECT` (the note at the other call site above).
	hp.call("_ready")
	t.ok(hp.visible, "체력 표시가 켜진 채로 시작한다")
	var box := Rect2(hp.position, hp.size)
	t.ok(box.size.x > 0.0 and box.size.y > 0.0,
		"체력 표시에 크기가 있다 (%dx%d — 0이면 아래 검사가 공짜로 통과한다)"
			% [int(box.size.x), int(box.size.y)])
	t.ok(not r.intersects(box),
		"조립창이 체력 표시(%s~%s)를 안 덮는다" % [box.position, box.end])


## **The checks above measure only the constant `Fx.WINDOW_RECT` — they do not look at whether the window uses it.**
##  Measured: making the window use `Rect2(0, 0, 10, 10)` left **everything green.**
##   Then the window becomes a 10-pixel dot and **the click area goes there too** — everything the position and
##   area checks above were measuring becomes false.
##
## => It cannot be measured by running (the window must be in a tree for `_ready` to run). **It is measured as text** —
##  same reason and same device as `net_circle._resize_is_table_driven`.
## The stripper is **borrowed** from `net_determinism`. Copy it and there are two, and they will diverge.
func _window_uses_the_tuning_rect(t) -> void:
	var raw := _read(CIRCLE_WINDOW_SCRIPT)
	t.ok(not raw.contains("\"\"\""), "circle_window에 삼중 따옴표가 없다 (스트리퍼가 못 다룬다)")
	var src := NetDeterminism._strip(raw)
	t.ok(src.contains("WINDOW_RECT"), "창이 `Fx.WINDOW_RECT` 를 읽는다 (치수가 두 곳이 아니다)")
	# The other side — a `Rect2` built from numbers is itself a second set of dimensions.
	#  Something like `Rect2(Vector2.ZERO, size)`, which **does not start with a number**, is not bitten.
	var re := RegEx.new()
	t.eq(re.compile("Rect2\\s*\\(\\s*[-.\\d]"), OK, "Rect2 숫자 패턴이 컴파일된다")
	t.ok(re.search(src) == null, "창이 숫자를 박은 Rect2를 안 만든다")


## **`mouse_filter` written at runtime is invisible to every check above.** `three_pick_window.gd`'s own header
## claims it "is written in `stage.tscn` and is not overwritten at runtime here" — the same contract
## `circle_window.gd` holds — but nothing had measured that claim. Setting `mouse_filter = MOUSE_FILTER_IGNORE`
## in `_ready()` passed the full suite: the scene value (`STOP`, checked by `_mouse_filter_contract` against the
## `.tscn`-authored property) would be silently overwritten the instant the node entered the tree, and clicks
## meant for the pick window would leak into firing with no error raised.
##
## **Scanning only `three_pick_window.gd` was not enough — this repo already learned this lesson once, one
## stage ago, and the first version of this check did not reuse it.** `net_progress._dice_left_is_zero_and_
## inert`'s own comment: a one-file scan misses a **different** file reaching in and writing the field from
## outside — `($HUD/ThreePickWindow as Control).mouse_filter = MOUSE_FILTER_IGNORE` written in `stage.gd`
## would have passed a scan of `three_pick_window.gd` alone. **This version scans every `.gd` under `src/`**,
## the exact widened form `dice_left`'s own check was corrected to, borrowing that file's own scanner
## (`net_progress._scan_gd_files`) rather than keeping a second copy of it.
##
## **Both the direct-assignment and `set()` forms** — the same two patterns for the same reason: `set(
## "mouse_filter", ...)` contains no literal `=` next to the field name and would slip past a scan that only
## looks for the first form.
func _pick_window_never_writes_its_own_mouse_filter(t) -> void:
	var re_assign := RegEx.new()
	t.eq(re_assign.compile("mouse_filter\\s*=(?!=)"), OK, "대입 패턴이 컴파일된다")
	var re_set := RegEx.new()
	t.eq(re_set.compile("set\\(\\s*[\"']mouse_filter[\"']"), OK, "set() 패턴이 컴파일된다")

	# Both patterns proven to actually bite first — an uninverted check proves "it runs", not "it measures".
	t.ok(re_assign.search("\tmouse_filter = MOUSE_FILTER_IGNORE") != null, "대입 패턴이 실제 대입을 문다 (전제)")
	t.ok(re_assign.search("\tif mouse_filter == MOUSE_FILTER_STOP:") == null,
		"대입 패턴이 비교(==)는 안 문다 (오탐이 아니다 — 전제)")
	t.ok(re_set.search("\tself.set(\"mouse_filter\", 2)") != null, "set() 패턴이 실제 set()을 문다 (전제)")
	t.ok(re_assign.search("\t($HUD/ThreePickWindow as Control).mouse_filter = MOUSE_FILTER_IGNORE") != null,
		"대입 패턴이 다른 파일에서 노드를 통해 쓰는 형태도 문다 (전제 — 이 검사가 막는 실제 회피)")

	var files := NetProgress.new()._scan_gd_files("res://src")
	t.ok(files.size() > 0, "src/ 아래에서 .gd 파일을 찾았다 (%d개 — 전제)" % files.size())

	var hits: Array[String] = []
	for path: String in files:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var raw := f.get_as_text()
		f.close()
		if raw.contains("\"\"\""):
			continue # can't strip safely — same guard `net_progress`'s own scanner would need if it hit one
		var src := NetDeterminism._strip(raw)
		for line: String in src.split("\n"):
			var code := line.strip_edges()
			if code.begins_with("#"):
				continue
			if re_assign.search(code) != null or re_set.search(code) != null:
				hits.append("%s: %s" % [path, code])
	t.eq(hits, [] as Array[String],
		"src/ 트리 전체 어디서도 런타임에 `mouse_filter`를 쓰지 않는다 (씬 값이 그대로 산다)")


## **The shader's `palette[N]` and `Mat.SLOT_COUNT` are a pair.**
##  Measured: changing `palette[16]` to `palette[8]` left **all 580 green with clean stderr.**
##   The shader **compiles fine** and `palette[mat_id]` reads out of bounds — undefined behavior in GLSL,
##   so it goes wrong **differently on every machine.** Nobody barks.
##  `cell_materials.gd` itself wrote "this must equal the shader's `palette[16]`", and there was no code
##   holding that sentence — a specimen of a comment not being able to stand in for a contract.
func _palette_size_matches(t) -> void:
	var sh: Shader = load(CellRenderer.SHADER_PATH)
	if sh == null:
		return
	var re := RegEx.new()
	re.compile("uniform\\s+vec4\\s+palette\\s*\\[\\s*(\\d+)\\s*\\]")
	var m := re.search(sh.code)
	t.ok(m != null, "셰이더가 `palette[N]` 을 선언한다")
	if m == null:
		return
	t.eq(m.get_string(1).to_int(), Mat.SLOT_COUNT,
		"셰이더 팔레트 길이가 Mat.SLOT_COUNT와 같다")


## **Does the path in `@onready var _x = $Path` actually exist in the scene.**
##  Rename one node and the game dies on a `null` reference while the net is **green, because it only looks at parsing.**
##   Until now the scene was only getting the v1 path-string check.
## **Still not caught**: a function signature mismatch (e.g. the argument count of `on_blasts`) is a runtime error
##  and is not caught here. The scene is only instantiated, **never run.**
func _onready_paths_resolve(t) -> void:
	var scene: PackedScene = load(STAGE_SCENE)
	t.ok(scene != null and scene.can_instantiate(), "무대 씬을 세울 수 있다")
	if scene == null or not scene.can_instantiate():
		# **A bare `return` here makes the check vanish entirely rather than "fail"** —
		#  only the pass count drops and **nobody barks.** A "vanished check" is indistinguishable from a passed one in the log.
		t.ok(false, "무대 씬을 못 세워서 @onready 경로를 **하나도 못 쟀다**")
		return
	var root := scene.instantiate()
	var re := RegEx.new()
	re.compile("@onready\\s+var\\s+\\w+\\s*:[^=]+=\\s*\\$([A-Za-z0-9_/]+)")
	var found := 0
	for m: RegExMatch in re.search_all(_read(STAGE_SCRIPT)):
		found += 1
		t.ok(root.get_node_or_null(m.get_string(1)) != null,
			"씬에 `$%s` 가 있다" % m.get_string(1))
	t.ok(found > 0, "@onready 경로를 실제로 찾았다 (%d개)" % found)
	# It is outside the tree, so `free` rather than `queue_free`.
	root.free()


## **An empty `get_shader_uniform_list()` means compilation failed.** This one line catches it headless.
##
## It measures **"does it equal the declared count"**, not "is it empty". Looking only at "is it empty" always
##  passes a shader with no uniforms at all, and from then this check is **in a state of measuring nothing
##  forever** for that file.
func _compiles(t, path: String) -> void:
	var nm := path.get_file()
	var sh: Shader = load(path)
	t.ok(sh != null, "%s 를 읽는다" % nm)
	if sh == null:
		return
	var declared := _declared_uniforms(sh.code)
	t.ok(declared > 0, "%s 가 uniform을 선언한다 (%d개)" % [nm, declared])
	t.eq(sh.get_shader_uniform_list().size(), declared,
		"%s 가 컴파일된다 (uniform 목록이 선언과 일치한다)" % nm)


## **Injecting under a name the shader does not accept does nothing at all — not even an error.**
##  Feed in the palette with one letter wrong and the screen is not even magenta, just black.
## The other side is measured too: **a uniform that is declared but nobody injects into is a false handle** (CLAUDE.md).
func _injection_matches_shader(t) -> void:
	var sh: Shader = load(CellRenderer.SHADER_PATH)
	t.ok(sh != null, "렌더러가 가리키는 셰이더가 실재한다 (%s)" % CellRenderer.SHADER_PATH)
	if sh == null:
		return

	var declared: Dictionary = {}
	for u: Dictionary in sh.get_shader_uniform_list():
		declared[String(u["name"])] = true

	var src := _read("res://src/view/cell_renderer.gd")
	var re := RegEx.new()
	re.compile("set_shader_parameter\\s*\\(\\s*\"([A-Za-z0-9_]+)\"")
	var injected: Dictionary = {}
	for m: RegExMatch in re.search_all(src):
		injected[m.get_string(1)] = true
	t.ok(injected.size() > 0, "렌더러가 주입하는 이름을 찾았다 (%d개)" % injected.size())

	for nm: String in injected.keys():
		t.ok(declared.has(nm), "셰이더가 uniform `%s` 를 선언한다" % nm)
	for nm: String in declared.keys():
		t.ok(injected.has(nm), "uniform `%s` 에 주입하는 사람이 있다 (거짓 손잡이가 아니다)" % nm)


## The number of uniform declarations in the shader code. Only the **start of the line** is looked at — the moment
##  a line with "uniform" written in a comment gets counted, this check quietly spins idle.
func _declared_uniforms(code: String) -> int:
	var n := 0
	for raw: String in code.split("\n"):
		if raw.strip_edges().begins_with("uniform "):
			n += 1
	return n


func _scan_shaders(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f: String in d.get_files():
		if f.ends_with(".gdshader"):
			out.append(dir.path_join(f))
	for sub: String in d.get_directories():
		out.append_array(_scan_shaders(dir.path_join(sub)))
	out.sort()
	return out


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("net_render: %s 를 못 읽었다" % path)
		return ""
	return f.get_as_text()


## **Is the HUD's material counting throttled — and does the throttled value catch up.**
##
## `count_material` is **552us** in one pass (4,128,768 cells) and the HUD counts three. Every frame that is
## 60Hz x 3 = **9.9% of the CPU.** **It is the kind that just disappears with no error and no visible glitch**,
## so nobody barks — hence it is measured by value.
##
## **The scene is not attached to the tree.** `_refresh_hud_counts()` is split out of `_update_hud()` so that it
##  touches none of the `@onready` labels, which means **an instance can be made and it can be called directly.**
##  That is what makes this check possible — unsplit, the stage would have to be attached to the tree, and this
##  repo does not do that.
##
## **Measuring only "is it throttled" also passes "never updated again".** => **Catching up is measured with it.**
func _hud_counts_are_throttled(t) -> void:
	var scene: PackedScene = load(STAGE_SCENE)
	if scene == null or not scene.can_instantiate():
		# A quiet `return` makes the check **vanish** — only the pass count drops and nobody barks.
		t.ok(false, "무대 씬을 못 세워서 HUD 세기를 **하나도 못 쟀다**")
		return
	var root := scene.instantiate()
	var g: Variant = root.get("_grid")
	var ticks: Variant = root.get("HUD_COUNT_TICKS")
	t.ok(g != null and ticks is int, "껍데기가 `_grid` 와 `HUD_COUNT_TICKS` 를 든다")
	if g == null or not (ticks is int):
		root.free()
		return
	var period: int = ticks
	t.ok(period > 1, "세기 주기가 1보다 크다 (%d틱 — 1이면 조인 게 아니다)" % period)

	# The first call counts immediately. Otherwise the user sees 0 for the first second and reads it as "it does not work".
	root.call("_refresh_hud_counts")
	t.eq(root.get("_stone_cells"), 0, "빈 격자에서 돌이 0이다 (기준선)")

	# Lay down terrain. **Calling again on the same tick must not change the value** — that is what "throttled" means.
	g.call("apply", CellGrid.cmd_fill(0, 0, 99, 99, Mat.STONE))
	var poured: int = g.call("count_material", Mat.STONE)
	t.ok(poured > 0, "돌을 실제로 깔았다 (%d칸 — 검사의 전제)" % poured)
	root.call("_refresh_hud_counts")
	t.eq(root.get("_stone_cells"), 0, "같은 틱에는 다시 안 센다 (조여져 있다)")

	# **Past the period it must catch up.** Unmeasured, it is indistinguishable from "never updated again".
	for _i in period:
		g.call("step")
	root.call("_refresh_hud_counts")
	t.eq(root.get("_stone_cells"), poured, "%d틱 뒤에 따라잡는다" % period)

	# **A reset (the tick going back to 0) must catch up too.** Otherwise the old terrain's counts stay on
	#  screen for 20 ticks after R.
	g.call("apply", CellGrid.cmd_reset())
	root.call("_refresh_hud_counts")
	t.eq(root.get("_stone_cells"), 0, "리셋 뒤 곧바로 다시 센다 (틱이 되돌아가는 갈래)")

	# **Are exactly three things throttled — the only place holding "active chunks are real-time".**
	#  Active chunks · burning cells · FPS are **O(1) queries and were not throttled.** But there was no check
	#   holding that fact — **anyone could move active chunks into this cache and nobody would bark**, and then
	#   acceptance 1 (has the water stopped) would read **a number up to a second stale.** It is an acceptance
	#   about watching "it drains and then settles", so that is a misreading outright.
	#  So **the very set of fields this function touches** is measured. A fourth one going in turns it red.
	#  **Sentinels are planted first.** Measuring by "fields whose value changed" **drops a field whose value
	#   happens to be the same** — measured: stone went 0 -> 0 and vanished from the list. What is being
	#   measured is not "did the value change" but **"how far does this function's writing reach".**
	for nm3 in ["_stone_cells", "_wood_cells", "_water_cells"]:
		root.set(nm3, -1)
	var before := {}
	for pd: Dictionary in root.get_property_list():
		if int(pd.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			before[pd["name"]] = root.get(pd["name"])
	#  **At the moment the count runs, active chunks must not be 0.** A newly added field cannot get a sentinel,
	#   so **if the value happens to match it is not caught** — the mutation moving active chunks into the cache
	#   actually escaped that way (0 -> 0). => Terrain is laid down on the last tick to make it count **while awake.**
	for _i in period - 1:
		g.call("step")
	g.call("apply", CellGrid.cmd_fill(0, 0, 199, 199, Mat.WOOD))
	g.call("step")
	t.ok(int(g.call("active_chunk_count")) > 0,
		"셈이 도는 순간 활성 청크가 0이 아니다 (이 검사의 전제)")
	root.call("_refresh_hud_counts")
	var touched: Array[String] = []
	for nm2: String in before:
		if root.get(nm2) != before[nm2]:
			touched.append(nm2)
	touched.sort()
	t.eq(touched, ["_hud_count_tick", "_stone_cells", "_water_cells", "_wood_cells"] as Array[String],
		"조이는 필드가 정확히 셋(+틱)이다 — 실시간 값이 여기 섞이면 빨개진다")

	root.free()


## **Nothing measured whether a `Control` is actually inside the canvas — `HUD/HpBar` shipped off-screen for
##  a full session because of exactly that hole** (the `fx_tuning.WINDOW_RECT` comment carries the story).
##  `_window_leaves_the_stage_visible` above checks `Fx.WINDOW_RECT` against the viewport; it never looked at
##  the `.tscn`-authored positions of the labels sitting beside it.
##
## **The canvas size is read from `project.godot`, not hardcoded** — the same device
## `_window_leaves_the_stage_visible` already uses, for the same reason: hardcode 960x540 here and a real
## resolution change makes this check compare against a number that is no longer true, silently.
## **Every direct `HUD` child is walked, not a hand-picked list** — hand-pick it and the day a new label is
##  added off-screen, this check has nothing to say about it (the same trap `INTERACTIVE`'s own comment names
##  for click-eating, applied to position instead).
## **`HUD/CircleWindow` sizes itself in `_ready()` from `Fx.WINDOW_RECT`** — outside the tree (this file's own
##  discipline; `_ready()` never runs), it sits at the engine's bare `Control` default, `Rect2(0,0,0,0)`.
##  **A zero-size rect at the origin is trivially `encloses`d** — the exact bug class this whole check exists
##  to catch, reintroduced by its own fix if the window were not named here. Its real, eventual rect is not
##  unmeasured: `_window_leaves_the_stage_visible` already checks `Fx.WINDOW_RECT` (the constant it is built
##  from) against this same viewport. **A named skip, not a silent one** — the same idiom as `INTERACTIVE` above.
##
## **`ThreePickWindow` is the same shape of skip, for the same reason** — it sizes itself from `Fx.PICK_RECT`
##  in `_ready()`, so untreed it is also `Rect2(0,0,0,0)` and would pass here for free without being named.
##  Before it was added here that was a **silent** free pass, not a declared one — the exact hole this
##  comment warns about, reintroduced by its own sibling. Its real rect is checked by
##  `_pick_window_leaves_the_stage_visible` (`_mouse_filter_contract`'s own block), against `Fx.PICK_RECT`
##  **by name** — `PICK_RECT := WINDOW_RECT` being an alias today does not mean either check can be skipped.
##
## **`SettlementWindow` (`run-end-settlement.md`, Stage D) is the same shape of skip** — it
## sizes itself from `Fx.SETTLEMENT_RECT` in `_ready()` too. **No separate "does it leave the stage visible"
## check exists for it, and none is needed**: `SETTLEMENT_RECT` is defined as the whole canvas `(0, 0, 960,
## 540)` (that constant's own header — the doc's declared exception to every other window here leaving the
## world visible), so there is no off-canvas position left to mistype in the first place. Its real rect is
## measured directly by `net_settlement._ready_seats_from_settlement_rect` instead.
const OUT_OF_TREE_SIZE_ZERO: Array[String] = ["CircleWindow", "ThreePickWindow", "SettlementWindow"]

func _hud_controls_are_inside_the_viewport(t) -> void:
	var vw := float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var vh := float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	t.ok(vw > 0.0 and vh > 0.0, "뷰포트 크기를 읽었다 (%dx%d)" % [int(vw), int(vh)])
	var canvas := Rect2(0.0, 0.0, vw, vh)

	var scene: PackedScene = load(STAGE_SCENE)
	t.ok(scene != null and scene.can_instantiate(), "무대 씬을 세웠다 (전제)")
	if scene == null or not scene.can_instantiate():
		return
	var root := scene.instantiate()
	var hud := root.get_node_or_null(HUD_PATH)
	t.ok(hud != null, "씬에 %s 가 있다" % HUD_PATH)
	if hud != null:
		var seen := 0
		for child in hud.get_children():
			if not (child is Control):
				continue
			seen += 1
			var ctl := child as Control
			if OUT_OF_TREE_SIZE_ZERO.has(String(ctl.name)):
				continue
			var box := Rect2(ctl.position, ctl.size)
			# **`encloses`, not `not intersects`** — a rect half off-screen still fails to intersect nothing,
			#  but `intersects` reads it as fine. `encloses` is the only form that reads "half off" as false.
			t.ok(canvas.encloses(box),
				"HUD/%s (%s~%s)가 뷰포트(%s) 안에 들어간다" % [ctl.name, box.position, box.end, canvas.size])
		# Same reason as the first line of a folder-scanning net — 0 children runs none of the above and passes green.
		t.ok(seen > 0, "%s 아래 Control이 있다 (%d개 — 전제)" % [HUD_PATH, seen])
		t.ok(seen > OUT_OF_TREE_SIZE_ZERO.size(),
			"건너뛴 것 말고도 실제로 잰 노드가 있다 (%d개 중 %d개 건너뜀)" % [seen, OUT_OF_TREE_SIZE_ZERO.size()])
	root.free()


## **The `HUD/Progress` counterpart to `_window_does_not_cover_the_health`.** That check reads a `.tscn`-set
##  position — a pure scene fact, measurable without `_ready()` ever running. This one is about **script**
##  behavior (`_update_hud()` writing to the wrong node, `_toggle_assembly()` hiding the wrong one), which a
##  position-only check cannot see in principle.
##
## **Measured**: repointing `stage.gd`'s `_progress_label` at `$HUD/Stats` passed the full suite (2833/3,
##  known-reds unchanged) — `_update_hud()` writes the level line into that node first and the very next
##  statement overwrites the same node with the `Stats` text, so the readout is blank at *every* frame.
##  Acceptance 1 and 2 both die and nothing barked.
##
## **The path driven here is read out of the source, not assumed** — the same technique
##  `_onready_paths_resolve` already uses for `@onready` lines. If `_progress_label` is repointed, this check
##  wires the *mutated* path and actually observes the collision instead of testing a path that no longer
##  matches what the script says.
## **The scene is never added to the tree** (this file's own discipline — `_ready()` does not run), so the
##  handful of `@onready` fields `_update_hud()` touches are wired by hand from the extracted paths, the same
##  device `_hud_counts_are_throttled` above uses for the fields it needs.
func _progress_text_survives_the_assembly_window(t) -> void:
	var src := _read(STAGE_SCRIPT)
	var re := RegEx.new()
	t.eq(re.compile(
			"@onready\\s+var\\s+(_levelup_label|_hud)\\s*:[^=]+=\\s*\\$([A-Za-z0-9_/]+)"),
		OK, "onready 패턴이 컴파일된다")
	var paths: Dictionary = {}
	for m: RegExMatch in re.search_all(src):
		paths[m.get_string(1)] = m.get_string(2)
	# **`_progress_label` is gone from this list because the node is gone** — the level line was cut
	#  from the screen (「레벨은 안 보이게」); money and XP are drawn by `money_view`/`hp_view` now.
	var names := ["_hud", "_levelup_label"]
	t.ok(paths.has("_hud") and paths.has("_levelup_label"),
		"`_hud`·`_levelup_label` 의 onready 선언을 소스에서 찾았다 (전제)")
	if not (paths.has("_hud") and paths.has("_levelup_label")):
		return
	# **All three pairwise, not just one pair** — the indicator is a third node precisely so it can carry its
	#  own color; repointing it at either of the other two collapses that.
	for i in names.size():
		for j in range(i + 1, names.size()):
			t.ok(paths[names[i]] != paths[names[j]],
				"`%s`와 `%s`가 서로 다른 노드를 가리킨다 (%s ≠ %s)" % [
					names[i], names[j], paths[names[i]], paths[names[j]]])

	# **The color override itself is measured as text, not by running** — it is set once in `_ready()`
	#  (`stage.gd`'s own comment: "pushed once, not every frame"), and this file's scenes never enter the
	#  tree, so `_ready()` never runs and there is nothing to read the override *off of*. The same limit
	#  `_window_uses_the_tuning_rect` already lives with, the same device it already uses.
	t.ok(src.contains("_levelup_label.add_theme_color_override(\"font_color\", Fx.LEVEL_UP_COLOR)"),
		"`_levelup_label`이 `Fx.LEVEL_UP_COLOR`를 받는다 (다른 노드가 그 색을 가로채지 않는다)")

	var scene: PackedScene = load(STAGE_SCENE)
	t.ok(scene != null and scene.can_instantiate(), "무대 씬을 세웠다 (전제)")
	if scene == null or not scene.can_instantiate():
		return
	var root := scene.instantiate()
	for path: String in [paths["_hud"], paths["_levelup_label"], "HUD/HpBar", "HUD/Money",
			"HUD/CircleWindow", "HUD/ThreePickWindow", "HUD/ResearchWindow", "HUD/SettlementWindow",
			"SpellView", "BlastFx"]:
		t.ok(root.get_node_or_null(path) != null, "씬에 %s 가 있다 (전제)" % path)

	# **`_input` is wired too, since `_update_hud()` reads developer mode off it** (`stage_input.debug_on()`).
	#  Left null it barks on every call — which is what happened the day the flag moved out of `stage.gd`.
	root.set("_input", root.get_node("StageInput"))
	root.set("_hud", root.get_node(paths["_hud"]))
	root.set("_levelup_label", root.get_node(paths["_levelup_label"]))
	root.set("_hp_view", root.get_node("HUD/HpBar"))
	root.set("_spell_view", root.get_node("SpellView"))
	root.set("_blast_fx", root.get_node("BlastFx"))
	root.set("_circle_window", root.get_node("HUD/CircleWindow"))
	# **`_update_hud()`/`_toggle_assembly()` both call `_pick_window` now** (`is_showing()`/`cancel_confirm()`)
	#  — wired here too, even though this function's own checks never touch the pick window's behavior,
	#  because leaving it null makes *any* call to either function crash outright.
	root.set("_pick_window", root.get_node("HUD/ThreePickWindow"))
	# **And `_research_window`, for exactly the same reason one line up** — `_update_hud()` reads its
	#  `visible` to decide whether `Stats` shows, so an unwired null crashes the call outright.
	root.set("_research_window", root.get_node("HUD/ResearchWindow"))
	# **And `_settlement`, same reason again** (`run-end-settlement.md`, Stage D) — `_update_hud()` now reads
	#  `_settlement.is_showing()` too, unconditionally, every call.
	root.set("_settlement", root.get_node("HUD/SettlementWindow"))
	# **And `_gate_view`, same reason a third time** (`stage-clear-sequence.md`) — `_sync_settlement()` calls
	#  `tick_gate()` on it every physics frame, and `reset_stage()` calls `reset_gate()`. Both unconditional.
	root.set("_gate_view", root.get_node("GateView"))

	# **Blanking the text first is what proves it fills back in**, not merely that the node happens to hold
	#  leftover text from before.
	var levelup_node := root.get_node(paths["_levelup_label"]) as Label
	levelup_node.text = ""
	root.call("_update_hud")
	t.eq(levelup_node.text, "",
		"대기 중인 뽑기가 없으면 레벨업 표시는 비어 있다 (조용한 상태에서 뜬 글씨가 없다)")

	# **A pending pick, driven directly** — `_world` is a plain `var` (not `@onready`), so it is already valid
	#  without `_ready()`. This is what proves the indicator node actually fills in, not only that it stays blank.
	var world: Variant = root.get("_world")
	t.ok(world != null, "`_world`를 들었다 (전제)")
	if world != null:
		world.progress().pending_picks = 2
		root.call("_update_hud")
		t.ok(levelup_node.text.contains("레벨업"),
			"대기 중인 뽑기가 있으면 레벨업 표시 노드에 실제로 글이 채워진다")
		t.ok(levelup_node.text != root.get_node("HUD/Stats").text,
			"레벨업 글이 디버그 readout에 뭉쳐 있지 않다 (서로 다른 노드, 서로 다른 내용)")

	# **The readout is off at boot now** (`stage_input._debug_on`), so a check about *window yielding* has to
	#  switch it on first. What it measures is unchanged: Stats hides for a window and comes back.
	root.get_node("StageInput").call("_unhandled_input", _key(KEY_F3))
	root.call("_update_hud")
	t.ok(root.get_node("HUD/Stats").visible, "조립창을 열기 전엔 Stats가 보인다 (전제)")
	root.call("_toggle_assembly")
	# **`_hud.visible` is derived inside `_update_hud()`, not written by `_toggle_assembly()` itself** — the
	#  same reason `_opening_one_window_closes_the_other` below drives it by hand after every toggle.
	root.call("_update_hud")
	t.ok(not root.get_node("HUD/Stats").visible, "조립창을 열면 Stats는 숨는다 (기존 계약)")
	t.ok(root.get_node(paths["_levelup_label"]).visible,
		"레벨업 표시 노드도 계속 보인다 (사라지지 않는다 — 인수 2)")

	root.free()


## **"Opening one window closes the other" — Stage C's own file-table line, driven for real.**
## A net that only proves `HUD/Stats` exists proves nothing about this rule — this calls the actual
## `_toggle_pick()` and `_toggle_assembly()` and reads the actual resulting state, in both directions.
func _opening_one_window_closes_the_other(t) -> void:
	var root := _wired_stage_root(t)
	if root == null:
		return
	var world: Variant = root.get("_world")
	if world == null:
		root.free()
		return
	world.progress().pending_picks = 1

	var stats := root.get_node("HUD/Stats") as Label
	var win := root.get_node("HUD/CircleWindow") as Control
	var pick_win := root.get_node("HUD/ThreePickWindow") as Control
	# Same reason as above — this check is about windows, not about the boot default.
	root.get_node("StageInput").call("_unhandled_input", _key(KEY_F3))
	root.call("_update_hud")
	t.ok(stats.visible, "시작할 때 Stats가 보인다 (전제)")

	# **`_hud.visible` is derived inside `_update_hud()`, not written by `_toggle_pick()`/`_toggle_assembly()`
	#  themselves** (`stage.gd`'s own comment above both functions) — a toggle-time write could not see the
	#  pick window's own `취소` button, which calls `Progress.decline()` directly and bypasses `_toggle_pick()`
	#  entirely (measured: `Stats` stranded hidden with nothing open). So every toggle below is followed by a
	#  driven `_update_hud()` call, the same discipline `_sync_pick_window` already holds for `_process()`.
	# -- pick open, then assembly opened -> the pick must have closed --
	root.call("_toggle_pick")
	root.call("_update_hud")
	t.ok(world.progress().is_pick_open(), "P를 누르면 뽑기가 열린다 (전제)")
	_sync_pick_window(root)
	t.ok(pick_win.visible, "뽑기가 열린 동안 뽑기 창의 `visible`도 실제로 켜진다")
	t.ok(not stats.visible, "뽑기 창이 열리면 Stats가 숨는다")

	root.call("_toggle_assembly")
	root.call("_update_hud")
	t.ok(not world.progress().is_pick_open(), "Tab을 누르면 열려 있던 뽑기가 닫힌다")
	_sync_pick_window(root)
	t.ok(not pick_win.visible, "그리고 뽑기 창도 꺼진다 (Progress를 따라간다)")
	t.ok(win.visible, "그리고 조립창이 열린다")
	t.ok(not stats.visible, "조립창이 열려 있으니 Stats는 여전히 숨어 있다")

	# -- assembly open, then pick opened -> the assembly window must have closed --
	root.call("_toggle_assembly")
	root.call("_update_hud")
	t.ok(not win.visible, "다시 Tab을 누르면 조립창이 닫힌다 (전제)")
	t.ok(stats.visible, "조립창을 닫으면 Stats가 돌아온다 (전제)")
	root.call("_toggle_assembly")
	root.call("_update_hud")
	t.ok(win.visible, "조립창을 다시 연다 (전제)")
	t.ok(not stats.visible, "조립창이 열려서 Stats가 다시 숨는다 (전제)")

	world.progress().pending_picks = 1
	root.call("_toggle_pick")
	root.call("_update_hud")
	t.ok(not win.visible, "조립창이 열린 채로 P를 누르면 조립창이 닫힌다")
	t.ok(world.progress().is_pick_open(), "그리고 뽑기가 열린다")
	_sync_pick_window(root)
	t.ok(pick_win.visible, "뽑기 창도 실제로 켜진다")
	t.ok(not stats.visible, "조립창을 뽑기로 바꿔 열어도 Stats는 숨어 있다 (되살아나지 않는다)")

	# -- declining via the key restores Stats, the same as closing the assembly window does --
	root.call("_toggle_pick")
	root.call("_update_hud")
	t.ok(not world.progress().is_pick_open(), "다시 P를 누르면 뽑기가 취소된다")
	t.ok(stats.visible, "취소하면 Stats가 돌아온다")

	# -- declining via the window's own button must restore Stats too — the defect this net exists to pin.
	#  `three_pick_window._gui_input`'s decline branch calls `Progress.decline()` directly, never
	#  `stage._toggle_pick()`, so a naive toggle-time restore could not see this path at all: it self-healed
	#  only on a later P->P, and `Stats` was gone in between with no reason for the player to press P (measured
	#  on screen). The state-derived `_update_hud()` line closes the whole class, not just this one path.
	world.progress().pending_picks = 1
	root.call("_toggle_pick")
	root.call("_update_hud")
	t.ok(world.progress().is_pick_open(), "뽑기를 다시 연다 (전제)")
	t.ok(not stats.visible, "뽑기가 열려 있으니 Stats가 숨어 있다 (전제)")
	# `_ready()` never ran (untreed) so `pick_win.size` is still the engine default — set it by hand to the
	#  real value, the same thing `_ready()` would have done, so the clicked point is the real button's.
	pick_win.size = Fx.PICK_RECT.size
	var decline_pos := Layout.decline_rect(pick_win.size).get_center()
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = decline_pos
	pick_win.call("_gui_input", mb)
	t.ok(not world.progress().is_pick_open(), "취소 버튼을 눌러도 뽑기가 실제로 닫힌다 (전제)")
	root.call("_update_hud")
	t.ok(stats.visible, "취소 '버튼'으로 닫아도 Stats가 돌아온다 (P가 아니라 버튼으로 — 이 검사의 핵심)")

	root.free()


## **ESC closes whichever of the three key-opened windows is open** (user request: "E 해서 뜬 게 ESC로 꺼져야
## 함. 모든 UI들은"). Driven by calling `_handle_cancel()` directly — the same idiom every check above uses
## for `_toggle_assembly()`/`_toggle_pick()` — since `stage_input.gd`'s own `ui_cancel` wiring is covered
## separately by `_input_actions_exist`'s auto-scan (it already sweeps every `is_action*(...)` call in that
## file, so `ui_cancel` needed no new entry there to be checked).
##
## **The three-pick: closing it must not lose the pick.** `Progress.decline()` (what `_toggle_pick()` calls)
## clears only the three drawn cards — `pending_picks` is untouched (`three_pick_window.gd`'s own comment:
## "declining does not consume the pick"). Verified here as a value, not assumed from reading the call chain:
## `pending_picks` is compared before and after.
##
## **`_settlement` is deliberately excluded and this drives that, not just states it.** It opens by
## derivation (`want`), so `_handle_cancel()` reaching for it and closing it would just have it reopen on the
## very next `_sync_settlement()` call — the check below confirms `_handle_cancel()` does not even try.
func _esc_closes_whichever_key_opened_window_is_open(t) -> void:
	var root := _wired_stage_root(t)
	if root == null:
		return
	var world: Variant = root.get("_world")
	if world == null:
		root.free()
		return
	var pr = world.progress()

	# -- nothing open: ESC does nothing --
	var win := root.get_node("HUD/CircleWindow") as Control
	var research := root.get_node("HUD/ResearchWindow") as Control
	t.ok(not win.visible and not research.visible and not pr.is_pick_open(),
		"시작할 때 세 창 다 닫혀 있다 (전제)")
	root.call("_handle_cancel")
	t.ok(not win.visible and not research.visible and not pr.is_pick_open(),
		"아무것도 안 열려 있으면 ESC는 아무 일도 안 한다")

	# -- assembly open -> ESC closes it --
	root.call("_toggle_assembly")
	t.ok(win.visible, "조립창을 열었다 (전제)")
	root.call("_handle_cancel")
	t.ok(not win.visible, "ESC를 누르면 조립창이 닫힌다")

	# -- research open -> ESC closes it --
	root.call("_toggle_research")
	t.ok(research.visible, "연구창을 열었다 (전제)")
	root.call("_handle_cancel")
	t.ok(not research.visible, "ESC를 누르면 연구창도 닫힌다")

	# -- pick open -> ESC closes it, and the pick itself is not lost --
	pr.pending_picks = 1
	root.call("_toggle_pick")
	t.ok(pr.is_pick_open(), "뽑기를 열었다 (전제)")
	var pending_before: int = pr.pending_picks
	root.call("_handle_cancel")
	t.ok(not pr.is_pick_open(), "ESC를 누르면 뽑기 창도 닫힌다")
	t.eq(pr.pending_picks, pending_before,
		"그런데 대기 중인 픽 자체는 잃지 않는다 (%d -> %d, 취소 버튼과 같은 효과)" % [pending_before, pr.pending_picks])

	# -- the settlement panel is untouched, even while showing --
	var ch: Variant = root.get("_char")
	root.call("_leave_town")
	ch.take_hit(Character.MAX_HP, false)
	root.call("_physics_process", 1.0 / 60.0)
	var settlement: Variant = root.get("_settlement")
	t.ok(bool(settlement.call("is_showing")), "정산 화면이 열렸다 (전제)")
	root.call("_handle_cancel")
	t.ok(bool(settlement.call("is_showing")), "ESC를 눌러도 정산 화면은 그대로 떠 있다 (버튼만이 문이다)")

	root.free()


## **Tab during the confirmation afterglow must not open a second window on top of the first.** The
## afterglow (`three_pick_window._confirm_ticks`) does not derive from `Progress` — `_toggle_assembly()`'s own
## `_pick_window.cancel_confirm()` call is the only thing that closes it, and without that call this is
## exactly the "both windows visible at once" class `_opening_one_window_closes_the_other` above exists to
## prevent, reopened by a state that check never drives.
func _tab_during_confirmation_afterglow_closes_it_first(t) -> void:
	var root := _wired_stage_root(t)
	if root == null:
		return
	var world: Variant = root.get("_world")
	var circle: Variant = root.get("_circle")
	if world == null or circle == null:
		root.free()
		return
	# **A round circle first** — the shell's own `_circle` boots `CIRCLE_NONE` now (Stage 3's empty start),
	#  which has 0 layers, and `layer_slots` below needs a real seat.
	circle.set_circle(CircleDefs.CIRCLE_ROUND)
	var pr = world.progress()
	pr.pending_picks = 1
	pr.set("_drawn", [Glyph.DUMMY_U, Glyph.BLAST_C, Glyph.SPREAD_C] as Array[int])
	t.ok(pr.is_pick_open(), "뽑기가 열렸다 (전제)")

	var pick_win := root.get_node("HUD/ThreePickWindow")
	pick_win.size = Fx.PICK_RECT.size
	var rects := Layout.cards(pick_win.size, pr.drawn().size())
	_click(pick_win, rects[0].get_center())
	var circle_rect := Layout.circle_rect(pick_win.size)
	var area := CircleLayout.circle_area(circle_rect.size)
	var slots := CircleLayout.layer_slots(circle.circle_id(), area)
	_click(pick_win, circle_rect.position + slots[0])

	t.ok(not pr.is_pick_open(), "놓고 나면 뽑기 자체는 닫힌다 (전제)")
	t.ok(pick_win.call("is_showing"), "확인 화면이 떴다 (전제)")

	var win := root.get_node("HUD/CircleWindow") as Control
	root.call("_toggle_assembly")
	t.ok(win.visible, "Tab을 누르면 조립창이 열린다")
	t.ok(not pick_win.call("is_showing"),
		"동시에 확인 화면도 닫힌다 (두 창이 한꺼번에 보이지 않는다 — 이 검사의 핵심)")

	root.free()


## **`_physics_process()` actually ticks `tick_confirm()` before `_update_hud()` reacts — driven for real,
## not read as text.** verify-read's own evasion: inserting an early return *between* the two calls (so
## `_update_hud()` stops running whenever a pick is open) left the source order untouched and passed the
## prior text-adjacency check — it protected an ordering it could see, not the execution it existed for.
## `_input`/`_camera` are now wired into `_wired_stage_root` for exactly this (their own comments there).
##
## **State is set directly rather than replayed through a full pick-and-place sequence** — the property under
## test is only "does one `_physics_process()` call tick the countdown *and* update the HUD together", not
## the placement flow itself (`net_pick.gd`'s own tests already cover that).
##
## **Two calls total, deliberately not `CONFIRM_FRAMES` of them.** `WorldStep._phase` starts at 0 and
## increments by 1 per call regardless of `dt` (`world_step.gd`'s own `frame()`) — at `Tuning.TICK_DIVIDER`
## (3) it would tick and run `_on_ticked()`, which touches `_renderer` (not wired here, by this file's own
## `_update_hud()`-only discipline elsewhere). Two calls leaves `_phase == 2`, still under that threshold, so
## this exercises the real function without needing the tick machinery at all.
func _physics_process_actually_ticks_confirm_before_the_hud_reacts(t) -> void:
	var root := _wired_stage_root(t)
	if root == null:
		return
	var world: Variant = root.get("_world")
	if world == null:
		root.free()
		return
	var pr = world.progress()
	var pick_win := root.get_node("HUD/ThreePickWindow")
	var stats := root.get_node("HUD/Stats") as Label

	# -- a genuinely open pick must still update the HUD through `_physics_process()` --
	#  **This is the half the actual evasion broke** — `if _world.progress().is_pick_open(): return` only
	#  bites while `Progress` itself reports a pick open, which the confirm-only phase below never does
	#  (it sets the window's afterglow fields directly, bypassing `Progress` entirely). Skip this phase and
	#  the mutation passes clean, as it first did.
	# The readout is off at boot; this check is about the tick driving , not the default.
	root.get_node("StageInput").call("_unhandled_input", _key(KEY_F3))
	pr.pending_picks = 1
	t.ok(pr.open_pick([] as Array[int]), "뽑기가 열렸다 (전제)")
	stats.visible = true
	root.call("_physics_process", 1.0 / 60.0)
	t.ok(not stats.visible,
		"뽑기가 열린 동안에도 `_physics_process()`가 실제로 `_update_hud()`를 돌려 Stats를 숨긴다")
	pr.decline()

	# -- the confirmation afterglow ticks and the HUD reacts, in the same call --
	pick_win.set("_confirm_ticks", 1)
	pick_win.set("_confirm_glyph", Glyph.DUMMY_U)
	pick_win.set("_confirm_layer", 0)
	t.ok(pick_win.call("is_showing"), "확인 화면이 떠 있다 (전제)")
	stats.visible = false  # the state `_update_hud()` would already have set while the pick was showing

	root.call("_physics_process", 1.0 / 60.0)

	t.ok(not pick_win.call("is_showing"), "한 번의 `_physics_process()` 호출로 확인 화면이 실제로 닫혔다")
	t.ok(stats.visible,
		"그리고 **같은 호출 안에서** Stats가 돌아온다 (틱과 갱신이 진짜로 한 호출에 함께 있다 — 이 검사의 핵심)")

	root.free()


## **`reset_stage()` actually cancels the confirmation afterglow — driven for real.** verify-read drove the
## real function after wiring three more nodes (`_input`/`_camera`, above) and confirmed `_confirm_ticks`
## reaches 0 through `cancel_confirm()` with clean stderr; this is that same drive, kept as a net.
func _reset_stage_actually_cancels_the_confirmation_afterglow(t) -> void:
	var root := _wired_stage_root(t)
	if root == null:
		return
	var pick_win := root.get_node("HUD/ThreePickWindow")

	pick_win.set("_confirm_ticks", 40)
	pick_win.set("_confirm_glyph", Glyph.DUMMY_U)
	pick_win.set("_confirm_layer", 0)
	t.ok(pick_win.call("is_showing"), "확인 화면이 떠 있다 (전제)")

	root.call("reset_stage")
	t.eq(pick_win.get("_confirm_ticks"), 0, "reset_stage()가 실제로 확인 화면의 카운트를 0으로 되돌린다")
	t.eq(pick_win.get("_confirm_glyph"), Glyph.GLYPH_NONE, "그리고 기억해 둔 문양도 지운다")
	t.ok(not pick_win.call("is_showing"), "그래서 더 이상 보이지 않는다")

	root.free()


## **Stage I (`stage1-bosses.md`) — room ①'s water, driven through the real `_physics_process()` loop, not a
## exercised for real — a bare `world.frame()` skips `_on_ticked()` entirely (that call only happens inside
## `stage.gd`'s own `_physics_process`), so a version of this test that drove the world directly would prove
## the gate but not that the water actually pours.
##
## **Session correction — the reward now grants itself the tick the bull dies** (`_on_ticked()`'s own new
## auto-grant), so "L gates it, and before L nothing has happened" is no longer true and is not asserted
## here any more (`_the_bull_reward_grants_itself_with_no_key_pressed`, above, is the check for the
## auto-grant transition itself). **What is still real and worth proving here**: the debug key L, pressed
## *after* the auto-grant already ran, must be idempotent — it must not create a second water source or
## disturb the rune already owned.
func _pressing_the_key_after_the_auto_grant_changes_nothing_further(t) -> void:
	var root := _wired_stage_root(t)
	if root == null:
		return
	var world: Variant = root.get("_world")
	if world == null:
		root.free()
		return

	var kind := MonsterDefs.KIND_BULL
	var mid: int = world.spawn_monster(kind, 700, 700 - MonsterDefs.h_px(kind))
	t.ok(mid > 0, "황소 스폰됐다 (전제)")
	world.monster_at(0).hp = 0
	# **`TICK_DIVIDER * 2`, never one** — the death and the auto-grant both happen on the tick.
	for _i in Tuning.TICK_DIVIDER * 2:
		root.call("_physics_process", 1.0 / 60.0)

	var pr: Variant = world.progress()
	t.ok(pr.owns_rune(Tuning.ELEM_FIRE), "전제 — 불 룬도 이미 자동으로 지급됐다")
	t.ok(not pr.is_reward_pending(MonsterDefs.KIND_BULL), "전제 — 대기 상태도 이미 스스로 풀렸다")

	for _i in Tuning.TICK_DIVIDER * 5:
		root.call("_physics_process", 1.0 / 60.0)

	root.call("_take_boss_reward")
	t.ok(pr.owns_rune(Tuning.ELEM_FIRE), "그리고 룬도 그대로다 (재지급으로 문제가 생기지 않는다)")

	root.free()


## **The negative control — pressing the key before any boss has died does nothing.** Without
## `boss_died(KIND_BULL)` gating `_take_boss_reward`, this would either error (no reward to clear, harmless)
## or — the actual risk — start room ①'s water regardless, which would make the wall/water order untestable
## in principle (acceptance 8b needs a "before" state that is genuinely water-free).
## **Fire stays ungranted too** (`rune-lock-and-receiving.md`, Stage C acceptance 6: "before the bull, nothing
## grants fire — the reward key does nothing on its own") — the same `boss_died()` guard covers both.
func _reward_key_before_any_death_does_nothing(t) -> void:
	var root := _wired_stage_root(t)
	if root == null:
		return
	var world: Variant = root.get("_world")
	if world == null:
		root.free()
		return

	t.ok(not world.progress().boss_died(MonsterDefs.KIND_BULL), "아직 아무도 안 죽었다 (검사의 전제)")
	root.call("_take_boss_reward")
	t.ok(not world.progress().owns_rune(Tuning.ELEM_FIRE), "죽기 전에 눌러도 불 룬은 지급되지 않는다")

	root.free()


## **Session correction — the reward used to have exactly one door, the debug key L, so a player who never
## opens the debug layer killed the bull and got nothing: no fire rune, no water, no way to burn the wood
## wall, and the rooster/gate past it unreachable — the game ended at the bull with nothing explaining why.**
## This drives the death and reads the grant with **no key press at all** — the whole point of the fix.
## *Inversion, measured directly*: replacing `_on_ticked()`'s own new call site
## (`if _world.progress().is_reward_pending(MonsterDefs.KIND_BULL): _take_boss_reward()`) with nothing turns
## every assert below red while `_reward_key_gates_room1_water` above (which presses the key by hand) stays
## green — proof this check measures the automatic door, not the debug one.
func _the_bull_reward_grants_itself_with_no_key_pressed(t) -> void:
	var root := _wired_stage_root(t)
	if root == null:
		return
	var world: Variant = root.get("_world")
	if world == null:
		root.free()
		return

	var kind := MonsterDefs.KIND_BULL
	var mid: int = world.spawn_monster(kind, 700, 700 - MonsterDefs.h_px(kind))
	t.ok(mid > 0, "황소 스폰됐다 (전제)")
	var pr: Variant = world.progress()
	t.ok(not pr.owns_rune(Tuning.ELEM_FIRE), "죽기 전엔 불 룬이 없다 (전제)")

	world.monster_at(0).hp = 0
	# **`TICK_DIVIDER * 2`, never one** — the death and the auto-grant both happen on the tick.
	for _i in Tuning.TICK_DIVIDER * 2:
		root.call("_physics_process", 1.0 / 60.0)

	t.ok(pr.owns_rune(Tuning.ELEM_FIRE),
		"L을 한 번도 안 눌렀는데도 황소가 죽으면 불 룬이 자동으로 들어온다")
	t.ok(not pr.is_reward_pending(MonsterDefs.KIND_BULL), "그리고 대기 상태도 스스로 풀린다")

	for _i in Tuning.TICK_DIVIDER * 5:
		root.call("_physics_process", 1.0 / 60.0)
	root.free()


## **The rooster's own reward flag must survive the bull's auto-grant untouched.** `_take_boss_reward()`
## calls `Progress.clear_pending_boss_rewards()`, which flips *every present* boss's pending flag to false,
## not just the bull's (`progress.gd`'s own "presence as a key is the whole fact" idiom) — gating the new
## call site on `is_reward_pending(KIND_BULL)` specifically, rather than "some boss has died", is what stops
## that from leaking into a boss with no reward door built yet.
## *Inversion*: calling `_take_boss_reward()` unconditionally every tick once *any* boss has died (the
## mutation this check exists to catch) clears the rooster's flag the tick after this test kills it, and the
## last assert below goes red.
func _a_rooster_death_does_not_touch_the_bulls_reward_gate(t) -> void:
	var root := _wired_stage_root(t)
	if root == null:
		return
	var world: Variant = root.get("_world")
	if world == null:
		root.free()
		return

	var kind := MonsterDefs.KIND_ROOSTER
	var mid: int = world.spawn_monster(kind, 700, 700 - MonsterDefs.h_px(kind))
	t.ok(mid > 0, "수탉 스폰됐다 (전제)")
	world.monster_at(0).hp = 0
	for _i in Tuning.TICK_DIVIDER * 2:
		root.call("_physics_process", 1.0 / 60.0)

	var pr: Variant = world.progress()
	t.ok(pr.boss_died(MonsterDefs.KIND_ROOSTER), "수탉이 죽었다 (전제)")
	t.ok(pr.is_reward_pending(MonsterDefs.KIND_ROOSTER),
		"황소가 죽은 적이 없어 자동 수령 분기가 불리지 않으므로, 수탉의 대기 플래그가 그대로 남아 있다")
	root.free()


## Screen wiring — text, the same idiom `_pattern_indicator_is_wired_to_the_screen` (`net_monster.gd`) already
## holds for a different indicator: proves only "the key reaches the function", not that the function does the
## right thing (the two driven tests above measure that by value).
func _reward_key_is_wired(t) -> void:
	var stage_src := _read(STAGE_SCRIPT)
	t.ok(stage_src.length() > 0, "stage.gd를 읽었다 (검사의 전제)")
	t.ok(stage_src.contains("_input.reward_taken_requested.connect(_take_boss_reward)"),
		"stage.gd가 reward_taken_requested를 _take_boss_reward에 연결한다")

	var input_src := _read(STAGE_INPUT_SCRIPT)
	t.ok(input_src.length() > 0, "stage_input.gd를 읽었다 (검사의 전제)")
	t.ok(input_src.contains("reward_taken_requested.emit()"),
		"stage_input.gd에 reward_taken_requested.emit()이 있다 (L 키가 신호를 낸다)")


## **Stage D (`rune-lock-and-receiving.md`) — a preset key must not wipe an earned rune.**
## `_set_loadout()` used to pass `SpellCircle.DEFAULT_RUNE` into `apply_preset()` unconditionally — earn
## fire, place it, press any preset key, and it silently came back none with nothing barking. **Driven
## through `_set_loadout` itself, not `SpellCircle.apply_preset` in isolation** — the wipe lived in *which
## rune `_set_loadout` passes*, and `net_circle.gd`'s own `_presets_still_work` only ever calls
## `apply_preset` directly with a rune it chooses itself, so it could not see this class of bug at all.
func _a_preset_key_does_not_wipe_an_earned_rune(t) -> void:
	var root := _wired_stage_root(t)
	if root == null:
		return
	var circle: Variant = root.get("_circle")
	if circle == null:
		root.free()
		return

	# **A round circle first** — the shell's own `_circle` boots `CIRCLE_NONE` now (Stage 3's empty start),
	#  which has 0 rune slots.
	circle.set_circle(CircleDefs.CIRCLE_ROUND)
	# Stand in for "the bull's reward was placed" without needing the click path — `grant_rune` +
	#  placement is `net_circle.gd`'s own job (`_owns_rune_gates_can_pick_on_an_untreed_window`); this test's
	#  only job is what a preset key does to a rune that is **already sitting in the seat**.
	t.ok(circle.set_rune(0, Tuning.ELEM_FIRE), "불 룬을 자리에 놓는다 (전제 — 이미 얻어서 놓았다고 가정한다)")
	t.eq(circle.rune_at(0), Tuning.ELEM_FIRE, "놓였다 (전제)")

	var keys: Array = Stage.LOADOUTS.keys()
	t.ok(keys.size() > 0, "프리셋 키가 있다 (검사의 전제)")
	for n: int in keys:
		circle.set_rune(0, Tuning.ELEM_FIRE)
		root.call("_set_loadout", n)
		t.eq(circle.rune_at(0), Tuning.ELEM_FIRE, "프리셋 키 %d를 눌러도 불 룬이 자리에 그대로 있다" % n)
		t.ok(circle.can_fire(), "그리고 여전히 쏠 수 있다 (키 %d)" % n)

	root.free()


## **The fallback half — with no circle to read a rune from, a preset must still leave a working circle,**
## not `RUNE_EMPTY` carried through by accident. This is the trap `circle_window.gd`'s own header names
## ("remove the circle and the rune stays bright and pickable ... pressing anywhere did nothing") arriving
## through a different door — `_set_loadout` reading `rune_at(0)` while there are 0 rune slots.
func _a_preset_key_still_works_with_the_circle_removed(t) -> void:
	var root := _wired_stage_root(t)
	if root == null:
		return
	var circle: Variant = root.get("_circle")
	if circle == null:
		root.free()
		return

	circle.set_circle(CircleDefs.CIRCLE_NONE)
	t.eq(circle.rune_count(), 0, "진을 빼면 룬 자리가 없다 (검사의 전제)")

	var keys: Array = Stage.LOADOUTS.keys()
	t.ok(keys.size() > 0, "프리셋 키가 있다 (검사의 전제)")
	root.call("_set_loadout", keys[0])
	t.ok(circle.can_fire(), "진이 없는 상태에서 프리셋을 눌러도 다시 쏠 수 있게 된다 (키 1이 조립 리셋이다)")
	t.ok(circle.rune_at(0) != SpellCircle.RUNE_EMPTY,
		"복구된 룬 자리가 RUNE_EMPTY로 남지 않는다 (자기 자신을 무장 해제하지 않는다)")

	root.free()


## **A reset revokes ownership but must not leave possession behind** — verify-run's own finding, driven
## through the real map: after R, `owns_rune(FIRE)` went back to false (the starting kit) while the seat
## still held `FIRE` and `element()` still read `FIRE`, so the new run could not even *pick* fire in the
## palette while still *firing* it at full effect.
## **The invariant itself is measured (seat's rune ⊆ owned set), not just "the seat is now none"** — a check
## that only asserted the seat's final value could not tell "correctly revoked" from "coincidentally none
## because `DEFAULT_RUNE` already is", so ownership is asserted in the same breath as the seat.
func _reset_revokes_a_rune_from_the_seat_it_no_longer_owns(t) -> void:
	var root := _wired_stage_root(t)
	if root == null:
		return
	var world: Variant = root.get("_world")
	var circle: Variant = root.get("_circle")
	if world == null or circle == null:
		root.free()
		return

	# **A round circle first** — the shell's own `_circle` boots `CIRCLE_NONE` now (Stage 3's empty start).
	circle.set_circle(CircleDefs.CIRCLE_ROUND)
	var pr = world.progress()
	pr.grant_rune(Tuning.ELEM_FIRE)
	t.ok(circle.set_rune(0, Tuning.ELEM_FIRE), "불 룬을 자리에 놓는다 (전제 — 얻어서 놓았다고 가정한다)")
	t.eq(circle.rune_at(0), Tuning.ELEM_FIRE, "놓였다 (전제)")

	root.call("reset_stage")
	t.ok(not pr.owns_rune(Tuning.ELEM_FIRE), "리셋 후엔 불 룬 소유가 사라진다 (전제 — 시작 키트로 되돌아간다)")
	t.eq(circle.rune_at(0), Tuning.ELEM_NONE,
		"그리고 자리도 무속성으로 내려온다 (소유하지 않은 룬이 자리에 남지 않는다)")
	t.ok(circle.can_fire(), "그래서 여전히 쏠 수 있다 (RUNE_EMPTY로 떨어지지 않는다)")

	root.free()


## **R still does not reset the assembly itself.** `reset_stage`'s own comment says a placed glyph survives
## R, and that stays true — glyphs carry no ownership concept to enforce, so this fix must not have widened
## into "R clears the circle".
func _reset_does_not_touch_glyphs(t) -> void:
	var root := _wired_stage_root(t)
	if root == null:
		return
	var circle: Variant = root.get("_circle")
	if circle == null:
		root.free()
		return

	# **A round circle first** — the shell's own `_circle` boots `CIRCLE_NONE` now (Stage 3's empty start),
	#  which has 0 layers.
	circle.set_circle(CircleDefs.CIRCLE_ROUND)
	t.ok(circle.place_glyph(0, Glyph.GLYPH_BLAST), "1층에 폭발을 놓는다 (전제)")

	root.call("reset_stage")
	t.eq(circle.glyph_at(0), Glyph.GLYPH_BLAST, "리셋 후에도 놓아 둔 문양이 그대로다 (R은 조립을 안 건드린다)")

	root.free()


## **`_revoke_unowned_rune()` genuinely checks ownership — it does not just force the seat to none.**
##
## **Why this cannot be proven through `reset_stage()` alone**: `Progress.reset()` always narrows the owned
## set to exactly `{none}`, so *every* rune the seat could hold right after a stage reset is either already
## none (no-op either way) or unowned (forced to none either way) — "check ownership, then clear" and
## "unconditionally clear" are **observationally identical** at that one call site (measured: hardcoding
## `_revoke_unowned_rune()` to always `set_rune(0, ELEM_NONE)` passed every `reset_stage`-driven check in this
## file). => The function is driven **directly**, in a state `reset_stage()` itself can never produce — water
## granted without touching the fire-vs-none question at all, so the owned set is `{none, water}`, not `{none}`.
func _revoke_unowned_rune_only_touches_what_is_not_owned(t) -> void:
	var root := _wired_stage_root(t)
	if root == null:
		return
	var world: Variant = root.get("_world")
	var circle: Variant = root.get("_circle")
	if world == null or circle == null:
		root.free()
		return

	# **A round circle first** — the shell's own `_circle` boots `CIRCLE_NONE` now (Stage 3's empty start).
	circle.set_circle(CircleDefs.CIRCLE_ROUND)
	var pr = world.progress()
	pr.grant_rune(Tuning.ELEM_WATER)
	t.ok(circle.set_rune(0, Tuning.ELEM_WATER), "물 룬을 자리에 놓는다 (전제 — 방금 얻었다)")

	root.call("_revoke_unowned_rune")
	t.eq(circle.rune_at(0), Tuning.ELEM_WATER,
		"소유한 룬(물)은 건드려지지 않는다 (그냥 무조건 무속성으로 미는 함수가 아니다)")

	t.ok(circle.set_rune(0, Tuning.ELEM_FIRE), "이번엔 소유하지 않은 불 룬을 자리에 놓는다 (전제)")
	t.ok(not pr.owns_rune(Tuning.ELEM_FIRE), "실제로 불은 소유하지 않았다 (전제)")
	root.call("_revoke_unowned_rune")
	t.eq(circle.rune_at(0), Tuning.ELEM_NONE, "소유하지 않은 룬(불)은 무속성으로 내려온다")

	root.free()


## Left click helper, mirroring `net_pick.gd`'s own `_click` — kept separate rather than importing a net
## file's private helper for a single call, the same boundary `NetProgress`/`NetMonster` (borrowed for real
## reusable logic elsewhere in this suite) are not stretched to cover trivial one-liners.
func _click(win: Control, pos: Vector2) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = pos
	win.call("_gui_input", mb)


## **P as a one-way door was green across every check** — neutering `_toggle_pick`'s decline branch (so P
## opens a pick and can never close it) passed the full suite, because `_opening_one_window_closes_the_other`
## above only ever presses P from the **closed** state (Tab is what closes the pick there, never P itself).
## This drives P a second time from the **open** state, which is the only thing that can catch that mutation.
func _pick_toggle_closes_from_the_open_state(t) -> void:
	var root := _wired_stage_root(t)
	if root == null:
		return
	var world: Variant = root.get("_world")
	if world == null:
		root.free()
		return
	world.progress().pending_picks = 1

	root.call("_toggle_pick")
	t.ok(world.progress().is_pick_open(), "P를 누르면 뽑기가 열린다 (전제)")
	root.call("_toggle_pick")
	t.ok(not world.progress().is_pick_open(),
		"열린 채로 P를 다시 누르면 닫힌다 (한쪽으로만 열리는 문이 아니다)")

	root.free()


## **P with nothing pending used to eat the assembly window.** `_toggle_pick` closed the window *before*
## knowing whether `open_pick()` would even succeed — with 0 pending it always fails, but the window was
## already gone. Measured: pressing Tab then P with nothing pending left `win.visible == false` and
## `stats.visible == true`, closing the window for nothing. **Check first, close second** is the fix.
func _pick_with_nothing_pending_does_not_touch_the_window(t) -> void:
	var root := _wired_stage_root(t)
	if root == null:
		return
	var world: Variant = root.get("_world")
	if world == null:
		root.free()
		return
	t.eq(world.progress().pending_picks, 0, "대기 중인 뽑기가 없다 (전제)")

	root.call("_toggle_assembly")
	var win := root.get_node("HUD/CircleWindow") as Control
	t.ok(win.visible, "조립창을 연다 (전제)")

	root.call("_toggle_pick")
	t.ok(win.visible, "대기가 없을 때 P를 눌러도 조립창은 그대로 열려 있다 (닫아 먹지 않는다)")
	t.ok(not world.progress().is_pick_open(), "그리고 뽑기도 안 열린다 (대기가 없으니 당연하다)")

	root.free()


## **Acceptance 8d — "you can decline and close, and nothing changes."** `_gui_input` itself is off-limits to
## nets by this repo's own rule (`circle_window.gd`'s header: "the nets cannot call the functions below" — a
## `Control` outside the tree never runs `_ready()`/`_gui_input`), so this does not click the decline button.
## It drives the **real** state-changing call instead: every path to decline — the window's own button, Tab
## (`_toggle_assembly`), P from the open state (`_toggle_pick`) — converges on the one function `Progress.decline()`
## (`three_pick_window.gd`'s own header: "`stage.gd`'s `_toggle_pick()` only ever calls `Progress.open_pick()`/
## `decline()` — never this node's `visible` directly"). Proving *that* function never reaches the circle proves
## every caller of it never does either.
##
## **The circle is pre-loaded, not left empty.** `packed_glyphs()` unchanged is trivially true if it was already
## `GLYPH_NONE` before and after — placing a real glyph first is what makes "byte-identical" a check against
## drift, not against zero staying zero.
func _declining_a_pick_leaves_the_circle_byte_identical(t) -> void:
	var root := _wired_stage_root(t)
	if root == null:
		return
	var world: Variant = root.get("_world")
	var circle: Variant = root.get("_circle")
	t.ok(world != null and circle != null, "`_world`와 `_circle`을 들었다 (전제)")
	if world == null or circle == null:
		root.free()
		return

	# **A round circle first** — the shell's own `_circle` boots `CIRCLE_NONE` now (Stage 3's empty start),
	#  which has 0 layers.
	circle.set_circle(CircleDefs.CIRCLE_ROUND)
	t.ok(circle.place_glyph(0, Glyph.SPREAD_C), "0층에 확산(일반)을 놓았다 (전제)")
	var before: int = circle.packed_glyphs()
	t.ok(before != 0, "놓은 뒤 packed_glyphs()가 빈 값이 아니다 (검사가 실제로 뭔가를 재는지 확인 — 전제)")

	world.progress().pending_picks = 1
	root.call("_toggle_pick")
	t.ok(world.progress().is_pick_open(), "P로 뽑기를 열었다 (전제)")
	t.eq(circle.packed_glyphs(), before, "뽑기를 여는 동안에도 진의 packed_glyphs()가 그대로다")

	root.call("_toggle_pick")
	t.ok(not world.progress().is_pick_open(), "다시 P를 눌러 뽑기를 취소했다 (Progress.decline())")
	t.eq(circle.packed_glyphs(), before,
		"취소한 뒤 packed_glyphs()가 정수 그대로다 (층이 그대로다 — 8d)")

	root.free()


## **Shared by every check that has to drive `_toggle_pick()`/`_toggle_assembly()`/`_update_hud()` for
## real** — the scene is never added to the tree (this file's own discipline), so the handful of `@onready`
## fields those functions touch have to be wired by hand, read out of the source rather than assumed
## (`_progress_text_survives_the_assembly_window`'s own reasoning — if `_progress_label` is repointed, this
## wires the *mutated* path too, instead of silently testing a path that no longer matches the script).
func _wired_stage_root(t) -> Node:
	var scene: PackedScene = load(STAGE_SCENE)
	t.ok(scene != null and scene.can_instantiate(), "무대 씬을 세웠다 (전제)")
	if scene == null or not scene.can_instantiate():
		return null
	var root := scene.instantiate()

	var src := _read(STAGE_SCRIPT)
	var re := RegEx.new()
	re.compile("@onready\\s+var\\s+(_levelup_label|_hud)\\s*:[^=]+=\\s*\\$([A-Za-z0-9_/]+)")
	var paths: Dictionary = {}
	for m: RegExMatch in re.search_all(src):
		paths[m.get_string(1)] = m.get_string(2)
	t.ok(paths.has("_hud") and paths.has("_levelup_label"),
		"onready 경로를 찾았다 (전제)")
	if not (paths.has("_hud") and paths.has("_levelup_label")):
		root.free()
		return null

	for path: String in [paths["_hud"], paths["_levelup_label"], "HUD/HpBar", "HUD/Money",
			"HUD/CircleWindow", "HUD/ThreePickWindow", "SpellView", "BlastFx", "StageInput", "Camera2D",
			"MonsterView", "CellRenderer", "TownView", "SkyBackground", "HUD/ResearchWindow",
			"HUD/SettlementWindow", "HUD/BossBar", "HUD/OnboardView", "CharacterView"]:
		t.ok(root.get_node_or_null(path) != null, "씬에 %s 가 있다 (전제)" % path)

	# **`_input` is wired too, since `_update_hud()` reads developer mode off it** (`stage_input.debug_on()`).
	#  Left null it barks on every call — which is what happened the day the flag moved out of `stage.gd`.
	root.set("_input", root.get_node("StageInput"))
	root.set("_hud", root.get_node(paths["_hud"]))
	root.set("_levelup_label", root.get_node(paths["_levelup_label"]))
	root.set("_hp_view", root.get_node("HUD/HpBar"))
	root.set("_spell_view", root.get_node("SpellView"))
	root.set("_blast_fx", root.get_node("BlastFx"))
	root.set("_circle_window", root.get_node("HUD/CircleWindow"))
	root.set("_pick_window", root.get_node("HUD/ThreePickWindow"))
	# **`_input`, so `_physics_process()` itself can be driven for real** — `move_axis()`/`jump_pressed()`/
	#  `jump_held()` only read the `Input` singleton directly (no `_ready()` dependency), so a bare node
	#  reference is enough; without wiring this, calling `_physics_process()` crashes on `_input` being null
	#  before it ever reaches `_update_hud()`, which is why the order/reset checks below used to be text
	#  scans instead of driving the real functions.
	root.set("_input", root.get_node("StageInput"))
	# **`_camera`/`_monster_view`, so `reset_stage()` itself can be driven for real** — it writes
	#  `_camera.offset` and calls `_monster_view.clear()` directly; without wiring both, calling
	#  `reset_stage()` crashes before reaching `_pick_window.cancel_confirm()`, which is why the reset check
	#  below used to be a text scan instead.
	root.set("_camera", root.get_node("Camera2D"))
	root.set("_monster_view", root.get_node("MonsterView"))
	# **`_town_view` for the same reason, one feature later** — `reset_stage()` reaches `_build_room()`, which
	#  writes `_town_view.visible`. Unwired, every reset check above dies on a null before it measures
	#  anything, which is exactly how this line came to be added (the whole net went red at once).
	root.set("_town_view", root.get_node("TownView"))
	root.get_node("TownView").call("setup", root.get("_char"))
	# **`_sky` for the same reason again** — `_build_room()` swaps the backdrop with the room, so `reset_stage()`
	#  now reaches it too. `setup(camera)` is what `_ready()` itself calls.
	root.set("_sky", root.get_node("SkyBackground"))
	root.get_node("SkyBackground").call("setup", root.get_node("Camera2D"))
	# **`_research_window` too** — `_update_hud()` reads its `visible` every frame to decide whether
	#  `Stats` shows, so an unwired null crashes every check that drives the HUD.
	root.set("_research_window", root.get_node("HUD/ResearchWindow"))
	# **`_settlement`** (`run-end-settlement.md`, Stage D — that plan's own Risk 1, "the
	#  highest-probability break in this whole plan"). `_physics_process()` reads `_settlement.is_showing()`
	#  before it will even call `_world.frame()`, and `_update_hud()`/`reset_stage()` both reach it too — an
	#  unwired null crashes every check in this file that drives any of the three before it measures anything.
	root.set("_settlement", root.get_node("HUD/SettlementWindow"))
	# **`_gate_view`, and the same sentence applies** (`stage-clear-sequence.md`) — `_sync_settlement()` calls
	#  `tick_gate()` on it every physics frame and `reset_stage()` calls `reset_gate()`, both unconditionally.
	root.set("_gate_view", root.get_node("GateView"))
	# **`_boss_bar`, the same sentence again** (`boss-entrance-and-hp-bar.md` Stage C) — `_rebuild()` calls
	#  `clear_boss()` and `_physics_process()` calls `set_entrance_frames()`, both unconditionally now.
	root.set("_boss_bar", root.get_node("HUD/BossBar"))
	# **`_onboard_view`** (`onboarding-and-palette-tabs.md` Stage 7) — `_physics_process()` reaches
	#  `_tick_onboard()` unconditionally, which writes `_onboard_view.visible` every frame. An unwired null
	#  here crashes every check in this file that drives a physics frame, the same shape every field above
	#  already had to be added for.
	root.set("_onboard_view", root.get_node("HUD/OnboardView"))
	# **`_rune_grant_view`** (the fire-rune-obtained banner) — `_take_boss_reward()` calls `.trigger()` on
	#  it unconditionally once the bull is confirmed dead. An unwired null here crashes the reward path the
	#  moment any check in this file drives it, the same shape every field above already had to be added for.
	root.set("_rune_grant_view", root.get_node("HUD/RuneGrantView"))
	# **`_char_view`** (the hit-flash/shake feature) — `_rebuild()` calls `_char_view.clear()` and
	#  `_on_ticked()` calls `_char_view.on_tick()`, both unconditionally now. An unwired null here crashes
	#  every check in this file that drives a reset or a tick, the same shape every field above already had
	#  to be added for.
	root.set("_char_view", root.get_node("CharacterView"))
	# **`_renderer`, so `_on_ticked()` can be driven for real too** — it calls `_renderer.refresh()` whenever
	#  `_grid.consume_changed() > 0`, and any test that drives `_physics_process()` far enough to change the
	#  grid (Stage I's own water pour is the first to do this through this helper) crashes on a null `_renderer`
	#  otherwise. `setup(_grid)` is exactly what `_ready()` itself calls.
	root.set("_renderer", root.get_node("CellRenderer"))
	root.get_node("CellRenderer").call("setup", root.get("_grid"))
	# **`setup()` is what `_ready()` would have called** — the pick window reads `_progress` itself in its own
	#  `_process()`, and outside the tree that never runs automatically, so `_sync_pick_window(root)` below
	#  drives it by hand wherever a check needs the window's own `visible` to actually reflect Progress.
	var world0: Variant = root.get("_world")
	if world0 != null:
		# **`_circle` too, the same reference `stage.gd`'s own `setup()` call hands over** — Stage E's layer
		#  click calls `SpellCircle.place_glyph()` directly, so tests driving that click need the *same*
		#  `_circle` the rest of this wired root reads, not a second one nothing else can see.
		root.get_node("HUD/ThreePickWindow").call("setup", world0.progress(), root.get("_circle"))
	return root


## **Drives the pick window's own `_process()` by hand.** Outside the tree it never runs automatically, and
## `visible` is the one property this window's whole contract hangs on (`_progress.is_pick_open()` mirrored
## into a real node property, not held as a second latch) — a check that only reads `Progress` state and
## never this node's own `visible` would not actually be measuring the window at all.
func _sync_pick_window(root: Node) -> void:
	root.get_node("HUD/ThreePickWindow").call("_process", 0.0)


## **The debug readout is off when the game boots, and F3 is what turns it on.**
##
## **Found on screen, not headless**: it is fifteen lines of black text — not the two `docs/submission/`
## records — and it lands straight on the research window's bright parchment, covering the prices the player
## opened it to read. **Every check above this one measures that Stats *yields to a window and comes back*,
## which stayed true the whole time.** None of them asked whether it should have been on to begin with.
##
## *Inversion: default `_debug_on` to `true` and the first assert goes red; delete the F3 branch and the
## second does.*
##
## **F3 is driven as a key event, not by calling the handler** — since developer mode moved into
## `stage_input`, the key branch *is* the flag's only writer, and calling `_toggle_debug_hud()` would skip it
## entirely and measure a derivation with nothing driving it.
func _the_debug_readout_is_off_at_boot_and_f3_turns_it_on(t) -> void:
	var root := _wired_stage_root(t)
	if root == null:
		return
	var stats: Label = root.get_node("HUD/Stats")
	var si: Node = root.get_node("StageInput")

	root.call("_update_hud")
	t.ok(not stats.visible,
		"게임을 켜면 디버그 readout이 안 보인다 (열다섯 줄이 연구창 위를 덮던 자리)")
	t.ok(not bool(si.call("debug_on")), "그리고 개발자 모드 자체가 꺼져 있다")

	si.call("_unhandled_input", _key(KEY_F3))
	root.call("_update_hud")
	t.ok(bool(si.call("debug_on")), "F3가 개발자 모드를 켠다")
	t.ok(stats.visible, "켜면 실제로 보인다 (플래그가 visible까지 이어진다)")
	si.call("_unhandled_input", _key(KEY_F3))
	root.call("_update_hud")
	t.ok(not stats.visible, "한 번 더 끄면 다시 사라진다")
	root.free()


## A pressed, non-echo key event. Physical keycode, because that is what the debug branches match on.
func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


## ══ **Developer keys are dead until F3, and player keys never are** ══
##
## **This is a submission check, not a feature check.** The build goes to a judge who has never seen the
## game, and every debug key was reachable from the first frame: a stray `M` stands a bull on top of them, a
## stray `1` swaps their assembly mid-fight, a stray `R` throws the run away. **None of those read as "I
## pressed a key" — they read as the game breaking.**
##
## **Driven through `_unhandled_input` with real key events**, because the gate is one `return` in that
## function and nothing else can observe it. Signals are counted rather than the flag, since the flag being
## false proves nothing about whether the branches consult it.
## *Inversion: delete the `if not _debug_on: return` line and the "off" half goes red.*
func _developer_keys_are_gated_behind_f3(t) -> void:
	var si: Node = load(STAGE_INPUT_SCRIPT).new()
	var fired: Array[String] = []
	for sig: String in ["monster_requested", "loadout_requested", "reset_requested",
			"wood_requested", "reward_taken_requested", "zoom_requested", "interact_requested"]:
		si.connect(sig, func(_a = null, _b = null): fired.append(sig))

	# **M, 1, R, T, L and `-` — one from each door**: the spawn dictionary, the preset dictionary and the
	#  `match`. All three are separate branches and a gate in front of only one would leave the others live.
	#  **T and M are not driven while ON** — those branches read `get_viewport()`, which is null on an
	#  untreed node; the off case is what this check is for and it never reaches that line.
	for code: int in [KEY_M, KEY_1, KEY_T, KEY_L, KEY_MINUS]:
		si.call("_unhandled_input", _key(code))
	t.ok(fired.is_empty(), "개발자 모드가 꺼져 있으면 디버그 키가 아무 신호도 내지 않는다 (%s)" % [fired])

	# **F and R are player keys and must work with the mode off.** F is the town's interaction (moved off E);
	#  **R is the only way out of a pit the player blew under themselves** — terrain is destructible and the
	#  jump clears 108px without the air-jump unlock, so gating it makes a trap a judge cannot escape.
	si.call("_unhandled_input", _key(KEY_F))
	t.ok(fired.has("interact_requested"), "F(상호작용)는 개발자 모드와 무관하게 먹는다")
	si.call("_unhandled_input", _key(KEY_R))
	t.ok(fired.has("reset_requested"), "R(리셋)도 먹는다 — 구덩이에 갇혔을 때 유일한 탈출구다")

	fired.clear()
	si.call("_unhandled_input", _key(KEY_F3))
	t.ok(bool(si.call("debug_on")), "F3는 게이트 앞에 있어서 언제나 먹는다 (전제 — 못 켜면 아래가 무의미)")
	for code: int in [KEY_1, KEY_L, KEY_MINUS]:
		si.call("_unhandled_input", _key(code))
	for want: String in ["loadout_requested", "reward_taken_requested", "zoom_requested"]:
		t.ok(fired.has(want), "켜면 %s 가 다시 산다" % want)
	si.free()


## ══ The camera lands on whole screen pixels ══
##
## **The defect this exists for is a difference, not a value.** Everything on the ground is drawn at integer
## world coordinates (`body.gd` keeps the fraction in `_rem_*`); the camera is float. Subtract one from the
## other and every sprite on screen jumps a pixel back and forth while walking, with Nearest filtering making
## it a hard step rather than a blur — the user's report was that the *character* stutters.
## **Nothing barks and no existing check can see it**: `camera_center` and `camera_lead` are both correct.
##
## The pure function first, then the shell — **measuring `snap_camera_px` is not measuring that `_process`
## calls it** (CLAUDE.md's `notice_rect` case, verbatim), so the second half drives the real scene treed and
## reads the camera the frame loop actually wrote.
func _the_camera_sits_on_whole_screen_pixels(t) -> void:
	# Half-open rounding is not the point; landing on the grid is. Both directions, and a value already on it.
	t.eq(Stage.snap_camera_px(Vector2(10.4, 20.6), 1.0), Vector2(10.0, 21.0), "줌 1에서 화면 픽셀로 붙는다")
	t.eq(Stage.snap_camera_px(Vector2(10.0, 20.0), 1.0), Vector2(10.0, 20.0), "이미 격자 위면 움직이지 않는다")
	# **At zoom 0.5 one screen pixel is two world px** — rounding the world position alone would leave the
	#  canvas on a half pixel, which is the whole defect back again at half strength.
	t.eq(Stage.snap_camera_px(Vector2(11.0, 20.0), 0.5), Vector2(12.0, 20.0), "줌 0.5에서는 2px 격자에 붙는다")
	# Zoom 0 would divide by zero and take the camera to infinity — a guard, not a feature.
	t.eq(Stage.snap_camera_px(Vector2(1.5, 2.5), 0.0), Vector2(1.5, 2.5), "줌 0이면 손대지 않는다")

	var scene: PackedScene = load(STAGE_SCENE)
	t.ok(scene != null and scene.can_instantiate(), "무대 씬을 세웠다 (전제)")
	if scene == null or not scene.can_instantiate():
		return
	var root := scene.instantiate()
	t.root.add_child(root)
	await t.pump_frames(2)

	# **Two things have to be arranged or this measures nothing, and the first attempt measured nothing.**
	#  (1) **The camera must be off its clamp.** At spawn `camera_center` pins to `view * 0.5` — a whole
	#    number whatever the focus is, so the snap changes nothing and *deleting it stayed green*. The
	#    character is moved to the middle of the map to get the camera into its free range.
	#  (2) **The lead must be fractional**, because `character.center()` is int + half a 20px box and so is
	#    already whole. A lead is the only thing in the focus that is not.
	# **`_process` is called directly with dt 0** rather than pumped: `camera_lead` decays toward its target,
	#  and at dt 0 the decay term vanishes, so the lead the camera was written from is still readable
	#  afterwards. Pumping instead leaves the field one frame ahead of the camera.
	var ch = root.get("_char")
	var cam: Camera2D = root.get_node_or_null("Camera2D")
	t.ok(ch != null and cam != null, "무대에 캐릭터와 Camera2D가 있다 (전제)")
	if ch != null and cam != null:
		var world: Vector2 = root.call("world_size")
		ch.place(int(world.x * 0.5), ch.y)
		root.set("_cam_lead", 0.37)
		root.call("_process", 0.0)

		var z: float = cam.zoom.x
		var view: Vector2 = root.get_viewport().get_visible_rect().size / z
		var raw: Vector2 = Stage.camera_center(
			ch.center() + Vector2(float(root.get("_cam_lead")), 0.0), view, world)
		# **The premise, and it is the whole check.** Without it the assert below passes on a camera that was
		#  already whole for reasons of its own — which is exactly how the first version of this passed with
		#  the snap deleted.
		t.ok(not (raw * z).is_equal_approx((raw * z).round()),
			"스냅 없는 원래 값은 격자 밖이다 (%s · 전제 — 격자 위면 아래가 아무것도 안 잰다)" % raw)
		t.ok((cam.position * z).is_equal_approx((cam.position * z).round()),
			"프레임 루프가 쓴 카메라 위치가 화면 픽셀 격자에 앉는다 (%s · 줌 %.3f)" % [cam.position, z])
	t.root.remove_child(root)
	root.queue_free()


## ══ **The help lines only name keys that exist** ══
##
## **「F 물 · K 물비」 stayed on screen for a day after both keys were deleted**, and it was found by opening
## the deployed page — not by any of the 8,400 checks. The two lines are the only place the game tells a
## developer what is bound, so a stale one is a straight lie: press F and you interact, press K and nothing
## happens at all.
##
## **This greps, and that is legitimate here** — the rule being enforced is itself about text (a help string
## naming a binding), not a proxy for behaviour.
##
## **What it measures, exactly: no help line names a key that is bound to nothing.** It does **not** check
## that the *description* is right — `F 물` would pass today, because F is bound (to the town interaction).
## Catching that would mean reading Korean labels against signal names, and this check does not claim to.
## What it does catch is the other half of the same bug: `K 물비` naming a key that no longer exists at all.
## *Inversion: put `K 물비 토글` back in the help string and this goes red.*
func _the_help_lines_only_name_keys_that_exist(t) -> void:
	var src := _read(STAGE_SCRIPT)
	var input_src := _read(STAGE_INPUT_SCRIPT)
	# **`project.godot` too, because a key can be bound two ways.** Debug keys are raw keycodes in
	#  `stage_input.gd`; player keys (D, P, Tab, Space) are input-map actions and appear only as
	#  `physical_keycode:<n>` in the project file. A check that knew only the first form called D and P
	#  missing — measured, on the first run.
	var proj := _read("res://project.godot")
	t.ok(src.length() > 0 and input_src.length() > 0 and proj.length() > 0, "세 파일을 읽었다 (전제)")

	# The help lines are the ones carrying `이동` and `몬스터` — found by content, not by line number.
	var lines: Array[String] = []
	for raw: String in src.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("\"") and (line.contains("A/D 이동") or line.contains("몬스터 ·")):
			lines.append(line)
	t.eq(lines.size(), 2, "안내 두 줄을 찾았다 (%d줄 — 0이면 아래가 아무것도 안 잰다)" % lines.size())

	# **`F3` before `F`**: scanning single characters alone would read F3's `F` and never see the `3`.
	var re := RegEx.new()
	t.eq(re.compile("(?<![A-Za-z0-9])(F3|[A-Z0-9])(?= )"), OK, "키 토큰 패턴이 컴파일된다")
	var checked := 0
	for line: String in lines:
		for m: RegExMatch in re.search_all(line):
			var tok := m.get_string(1)
			checked += 1
			# **A word boundary, and the inversion is what taught it.** Restoring the dead `K 물비` line
			#  stayed green because `contains("KEY_K")` matches **`KEY_KP_SUBTRACT`** — the check carried the
			#  very defect it was written to catch (CLAUDE.md: invert the instrument, not only the subject).
			var word := RegEx.new()
			word.compile("KEY_" + tok + "(?![A-Za-z0-9_])")
			var bound := word.search(input_src) != null 				or proj.contains("\"physical_keycode\":%d" % OS.find_keycode_from_string(tok))
			t.ok(bound, "안내가 말하는 %s 키가 실제로 묶여 있다 (raw 또는 입력 맵)" % tok)
	t.ok(checked >= 6, "실제로 검사한 키 토큰 수 (%d — 적으면 패턴이 안 물린 것)" % checked)
