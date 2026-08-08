extends SceneTree
## The net runner. Runs headless. There is no scene and no screen.
##
## Running the runner alone is only half of it. Engine errors cannot be intercepted from inside the runner
## (Godot has no logger hook). The stderr check is done by run_nets.ps1. Always run it through the wrapper.
##
## Nets live in tests/nets/net_*.gd. The runner sweeps the directory and registers them automatically.
## Keeping the list by hand means the moment a net is added and registration is forgotten, it quietly does not run.
##
## Usage: Godot.exe --headless --path <project> --script res://tests/run_nets.gd -- [filter]

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
		_run_net(path, nm)

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
func _run_net(path: String, nm: String) -> void:
	var script: GDScript = load(path)
	if script == null:
		_note_fail(nm, "스크립트를 못 읽었다")
		return
	var net: Object = script.new()
	if not net.has_method("run"):
		_note_fail(nm, "run(t) 메서드가 없다")
		return
	_current = nm
	var t0 := Time.get_ticks_msec()
	print("\n- %s" % nm)
	net.call("run", self)
	print("  (%dms)" % (Time.get_ticks_msec() - t0))


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
