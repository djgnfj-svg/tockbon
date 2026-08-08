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
const CellRenderer := preload("res://src/view/cell_renderer.gd")
const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Fx := preload("res://src/view/fx_tuning.gd")

## The HUD's `CanvasLayer`. **This is exactly the layer that decides whether left-click reaches firing.**
const HUD_PATH := "HUD"

## **Nodes that are allowed to eat clicks.** A `Control` not listed here that is `STOP` kills left-click quietly.
##  **Keeping the list by hand is itself the contract.** Attach a new window without listing it and the net
##   barks first; list it and "this one eats clicks on purpose" stays in the repo. Work it out automatically
##   and that declaration disappears.
const INTERACTIVE: Array[String] = ["HUD/CircleWindow"]

## **The old `WINDOW_SCREEN_FRAC` (90% on each axis) was deleted.** The contract was never about size —
##  "the character and its surroundings are visible" is the contract, and 90% was the value that **deferred** it.
##  The deferral ended once the character could be hurt (user's acceptance) =>
##   `_window_does_not_cover_*` below measures **whether it covers or not.**
const Character := preload("res://src/actor/character.gd")
const Stage := preload("res://src/stage/stage.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")


func run(t) -> void:
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
	root.free()


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
	#  The health side is alive: `HUD/Health` sits on a `CanvasLayer`, so it is in **the same screen coordinate
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
	var hp := root.get_node_or_null("HUD/Health") as Control
	t.ok(hp != null, "씬에 HUD/Health 가 있다")
	if hp == null:
		return
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
