extends SceneTree
## The net runner. Runs headless. There is no display — but frames DO turn now (harness-manager, see below).
##
## Running the runner alone is only half of it. Engine errors cannot be intercepted from inside the runner
## (Godot has no logger hook). The stderr check is done by run_nets.ps1. Always run it through the wrapper.
##
## Nets live in tests/nets/net_*.gd. The runner sweeps the directory and registers them automatically.
## Keeping the list by hand means the moment a net is added and registration is forgotten, it quietly does not run.
##
## Usage: Godot.exe --headless --path <project> --script res://tests/run_nets.gd -- [filter]
##
## **`_draw()` was declared impossible to measure headless in three places (`net_render`, `net_pick`,
##  `net_settlement`) — "it needs a live draw context", citing `get_theme_default_font()` returning null
##  untreed. Measured (harness-manager): both halves of that diagnosis were wrong.** Probed directly (a bare
##  `Control` and the real `CircleWindow`, both untreed): `get_theme_default_font()` is **never** null —
##  Godot 4.7.1 falls back to the engine's global default theme with no tree involved at all, so the font
##  was never the blocker. The real reason `_draw()` never ran is exactly the one this file owns:
##  **this runner's own `_initialize()` called `quit()` before a single engine frame ever turned** —
##  `_initialize()` ran fully synchronously, so the SceneTree's main loop, and with it every frame-gated
##  callback (`_draw`, `_process`, timers), never got a chance to run even once.
##  **The engine was never the wall — this file's control flow was.**
##
## **Fixed by letting `_run_net` (and `_initialize`'s call into it) `await`.** A plain `run(t)` with no
##  `await` inside still resolves the instant it's called — GDScript only suspends a coroutine at an actual
##  `await` point, so every net that doesn't ask for a frame keeps running exactly as before, in the same
##  process, at the same speed. A net that DOES need one calls `await t.pump_frames(n)` (below): the tree's
##  own `process_frame` signal is real here now, because `quit()` no longer fires until the whole net list is
##  done. `tests/nets/net_frame_runner.gd` is the proof — and the regression guard. **Measured, not assumed:
##  reverting `_run_net`'s `await net.run(self)` back to the old `net.call("run", self)` does not turn that
##  net red — it makes it vanish** (`[net] 0 passed`, exit code 0; `.call()` doesn't carry the suspension
##  back to its caller, so `pump_frames`'s `await process_frame` abandons everything after it, silently).
##  The pass **count** dropping (5 -> 0) is the only thing that catches it — see that net's own header.
##
## **This does not retroactively treed `net_render`/`net_pick`/`net_settlement`'s own checks** — those three
##  files' "can't measure `_draw()` headless" comments are now half wrong (the "in principle" part), but
##  fixing their wording is those files' owners' call, not this one's (they were mid-edit when this was found).

const NETS_DIR := "res://tests/nets"

var _pass := 0
var _fail := 0
var _failures: Array[String] = []
var _current := ""


func _initialize() -> void:
	var filter := _arg_filter()
	var files := _collect_nets()
	if files.is_empty():
		printerr("[net] not one net_*.gd in %s" % NETS_DIR)
		quit(1)
		return

	var total := Time.get_ticks_msec()
	for path: String in files:
		var nm := path.get_file().trim_suffix(".gd")
		if not _filter_matches(nm, filter):
			continue
		await _run_net(path, nm)

	var ms := Time.get_ticks_msec() - total
	print("")
	if _fail == 0:
		print("[net] %d passed · %dms" % [_pass, ms])
	else:
		print("[net] %d failed / %d · %dms" % [_fail, _pass + _fail, ms])
		for f: String in _failures:
			print("   x " + f)
	quit(1 if _fail > 0 else 0)


## It keeps running the next net even after a failure. Stopping at the first failure means learning about
## only one thing at a time.
##
## **`net` is typed `Variant`, not `Object` — that is what lets `await net.run(self)` work.** `Object` does
## not declare a `run` member, so a direct call needs the dynamic dispatch `Variant` gives it at runtime
## (the old code sidestepped this with reflection, `net.call("run", self)`, but `.call()` does not carry
## an `await` through to its caller the way a direct call does — a net's own internal `await` would detach
## and the rest of it would run out of order with everything after it here).
func _run_net(path: String, nm: String) -> void:
	var script: GDScript = load(path)
	if script == null:
		_note_fail(nm, "스크립트를 못 읽었다")
		return
	var net: Variant = script.new()
	if not net.has_method("run"):
		_note_fail(nm, "run(t) 메서드가 없다")
		return
	_current = nm
	# **The general form of the hole `net_frame_runner.gd`'s own inversion found.** That inversion happened
	# to be a severed `await`, but the same "0 passed, exit code 0" shape follows from an early `return`, an
	# uncaught runtime error mid-`run()`, or a loop whose condition is false from the first check — CLAUDE.md
	# already names all three as separate traps; this one line catches every one of them at once, because
	# none of them leave a trace anywhere except "nothing got asserted". Snapshotting the counters instead of
	# a hand-kept "expected checks per net" table is the point: a real per-net registry needs updating every
	# time a check is added or removed, and CLAUDE.md already rejects that shape for the net list itself
	# (folders are scanned, never hand-registered) — this does the equivalent for check counts, for free.
	var checks_before := _pass + _fail
	var t0 := Time.get_ticks_msec()
	print("\n- %s" % nm)
	await net.run(self)
	if _pass + _fail == checks_before:
		_note_fail(nm, "검사를 0개 돌렸다 (run()이 끝까지 갔는지부터 의심하라)")
	print("  (%dms)" % (Time.get_ticks_msec() - t0))


## **Pumps `n` real engine frames so `_draw()`/`_process()`/timers actually fire.** Only a net that adds a
## node under `root` and calls this pays anything — the `await process_frame` below is a genuine suspend,
## unlike an `await` on a plain function call (see the header comment). Every other net never calls this
## and is unaffected: same process, same synchronous run, same speed as before this file changed.
##
## The node must be a child of `root` (`t.root.add_child(...)`) *before* calling this — a node outside the
## tree has no viewport to draw into and `queue_redraw()` on it is a no-op. Clean up afterward
## (`remove_child` + `queue_free`) so a later check in the same net does not inherit a stray drawn node —
## checks in one file share this one process (CLAUDE.md: nets run one process per file, not per check).
func pump_frames(n: int = 1) -> void:
	for _i in n:
		await process_frame


# -- assertions ----------------------------------------------------
# Do not use assert(). It disappears in release, and the process dies at the first failure so the rest does not run.

## Write what is being measured into the label. It has to be "water did not go left", not "the values differ",
## for the failure log alone to narrow down the candidate causes.
func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  o %s" % label)
	else:
		_note_fail(_current, label)


func eq(got: Variant, want: Variant, label: String) -> void:
	if got == want:
		_pass += 1
		print("  o %s" % label)
	else:
		_note_fail(_current, "%s — 얻은 값 %s · 기대 %s" % [label, str(got), str(want)])


func _note_fail(net: String, label: String) -> void:
	_fail += 1
	_failures.append("%s: %s" % [net, label])
	printerr("  x %s: %s" % [net, label])


## The door that keeps a net which barks on purpose from being caught by its own bark.
## The wrapper treats every error on stderr as a failure. But a net like "does it discard an out-of-range value"
## raises an error precisely when it passes. Left undeclared the wrapper goes red, and a person soon turns the
## wrapper off. Write the substr narrowly. Written wide, a real silent death is amnestied along with it while
## that net runs.
func expect_error(substr: String) -> void:
	print("[EXPECT] %s" % substr)


# ------------------------------------------------------------------

## **The `^` prefix is an exact match — not a substring match** (harness-manager, measured).
##  **Why**: the parallel runner spawns one process per net and gives a short name as the filter to bind that
##  process **to that one net only** (`run_nets.ps1`). But with a substring match, names that contain each other
##  (`net_sprite` in `net_monster_sprite`, `net_water` in `net_water_rain`) mean **one process secretly runs
##  several nets** — the isolation breaks, and the time becomes the sum of the two nets, so there is no reason
##  left for the parallelism.
##  Measured: the process for `net_water` bit `net_water_rain` too with the filter "water" and came out at 57 seconds
##  (the process running only `net_water_rain` was 45 seconds — the overlapping time was pure waste).
##  => **Only the parallel spawn uses `^`.** `-Serial` and manual runs, typed into the CLI by a person, stay
##  substring matches (the convenience of typing something short to run several nets at once must not be lost).
func _arg_filter() -> String:
	var user := OS.get_cmdline_user_args()
	return user[0] if user.size() > 0 else ""


## Does `filter` match the net name `nm` ("net_xxx"). Exactly if it has the `^` prefix, otherwise as a substring.
func _filter_matches(nm: String, filter: String) -> bool:
	if filter == "":
		return true
	if filter.begins_with("^"):
		return nm == "net_" + filter.substr(1)
	return nm.contains(filter)


func _collect_nets() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(NETS_DIR)
	if d == null:
		return out
	for f: String in d.get_files():
		if f.begins_with("net_") and f.ends_with(".gd"):
			out.append(NETS_DIR.path_join(f))
	out.sort()  # fixes the execution order. A shifting order makes failures unreproducible
	return out
