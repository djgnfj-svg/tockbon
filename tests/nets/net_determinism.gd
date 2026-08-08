extends RefCounted
## Checks the sim core's determinism contract against the source text.
##
## Why a text scan: two instances in the same process give the same answers even for float.
## So a net that "runs it twice and compares" cannot catch a violation of this contract in principle.
## It only surfaces when platforms diverge, and by then the two clients' worlds are different worlds forever.
##
## It scans a **folder**, not a list. v1 hardcoded a file list (`SIM_FILES`), and creating one more file
## and forgetting to register it meant it quietly did not run.
## When the folder is the contract, a new file is caught automatically.
##
## **The way this net dies is not "there is no banned word" but "it cannot see the banned word".**
## In that state everything is green and nobody knows. Measured: `randi_range` · `OS.` · float literals
## were all passing through. => `_self_test` below measures **whether each pattern actually bites** first.
## When fixing a detector, always add one more sample line to `MUST_CATCH`.
##
## src/actor/ is not a target. The GDD multiplayer table pins the player to host authority, so float is allowed.
## The boundary is the single return in src/actor/aim.gd.

const SIM_DIR := "res://src/sim"

## The ban list. **What is banned is not "all float" but "whatever gives different answers per platform"** —
## `+ - *` and integer division are bit-identical under IEEE-754 / C semantics and are safe.
##
## Thanks to `\b`, the integer variants are not caught: `_isqrt` · `absi` · `mini` · `floori` · `clampi` · `snappedi`.
##  Whether that property actually holds is measured by `MUST_PASS` below — do not trust this comment alone.
const BANNED: Array = [
	# - floating point itself -
	["\\bfloat\\b", "float"],
	["\\bPackedFloat\\d*Array\\b", "PackedFloatArray"],
	# **Not looking at float literals makes blocking everything else pointless** — one `var t := 0.5` line
	#  makes the state floating point, and from then this folder's contract is entirely false.
	["\\d\\.\\d", "실수 리터럴"],
	["[^\\w.]\\.\\d", "실수 리터럴(.5 꼴)"],
	["\\bINF\\b", "INF"],
	["\\bNAN\\b", "NAN"],
	["\\bPI\\b", "PI"],
	["\\bTAU\\b", "TAU"],
	# - types that carry floating point around -
	# `Vector2i` is integer and is not caught (`\b` does not break before the `i` of `Vector2i`).
	["\\bVector[234]\\b", "Vector2/3/4"],
	["\\bColor\\b", "Color"],
	# - libm — different answers per platform -
	["\\b(sqrt|sin|cos|tan|asin|acos|atan|atan2|pow|exp|log|fmod)\\s*\\(", "libm 함수"],
	# - global functions returning float. Integer variants exist (absi · mini · maxi · clampi · roundi ...) -
	["\\b(abs|min|max|clamp|round|floor|ceil|sign|snapped|lerp|ease|smoothstep|move_toward|wrapf?)f?\\s*\\(",
		"float 전역 함수"],
	# - randomness — it is a stream, so one differing call count diverges forever -
	# The old list looked only at `randi(` · `randf(`, so **`randi_range` went straight through.**
	["\\brand[a-z_]*\\s*\\(", "난수 함수"],
	["\\bRandomNumberGenerator\\b", "RandomNumberGenerator"],
	# - clocks — the tick number is state. The moment a wall clock is read, clients diverge -
	# The old list looked only at `Time.`, so **`OS.get_ticks_usec()` went straight through.**
	["\\bTime\\.", "Time."],
	["\\bOS\\.", "OS."],
	["\\bEngine\\.", "Engine."],
	["\\bdelta\\b", "delta"],
]

## **Samples that measure the detector itself.** Each line must be caught by **at least one** entry of `BANNED`.
## This list is exactly "what this net claims to see". When the claim and reality diverge, it goes red.
const MUST_CATCH: Array[String] = [
	"var t := 0.5",
	"var z := .5",
	"var q := a / 2.0",
	"var f: float = 1",
	"var arr := PackedFloat32Array()",
	"var v := Vector2(1, 2)",
	"var c := Color(1, 0, 1)",
	"randi()",
	"randi_range(0, 5)",
	"randf_range(0, 1)",
	"randomize()",
	"var rng := RandomNumberGenerator.new()",
	"OS.get_ticks_usec()",
	"Time.get_ticks_msec()",
	"Engine.get_frames_per_second()",
	"func step(delta):",
	"sqrt(2)",
	"atan2(y, x)",
	"pow(a, 2)",
	"fmod(a, b)",
	"lerpf(a, b, 1)",
	"snappedf(x, 1)",
	"var x := PI",
	"var y := TAU",
	"var w := INF",
	"abs(a)",
	"var m := max(a, b)",
]

## The other side. If a line here is caught, the pattern is **too wide**, and then sim code cannot use the
## integer functions it legitimately needs — that pressure ends in the net being turned off.
const MUST_PASS: Array[String] = [
	"var r := _isqrt(n)",
	"var i := absi(-1)",
	"var m := maxi(0, mini(a, b))",
	"var c := clampi(v, 0, 255)",
	"var k := floori(x)",
	"var j := roundi(x)",
	"var s := signi(x)",
	"var p := snappedi(v, 4)",
	"var g := v >> 4",
	"var a: Array[int] = []",
	"const P := preload(\"res://src/sim/cell_grid.gd\")",
	"_fill_rect(int(cmd[\"x0\"]), int(cmd[\"y0\"]))",
	"# 주석에 float 과 randi() 와 0.5 를 적어도 안 걸린다",
	"var n := 8",
]


func run(t) -> void:
	# **The detector is measured first.** The file scan below only means anything while the detector has its eyes open.
	_self_test(t)

	var files := _scan_dir(SIM_DIR)
	# Why this has to be the first line: scanning an empty folder runs none of the checks below
	# and the net passes green. That is exactly how this repo dies.
	t.ok(files.size() > 0, "%s 에서 스캔한 파일이 0개가 아니다 (%d개)" % [SIM_DIR, files.size()])
	for path: String in files:
		_scan(t, path)


func _self_test(t) -> void:
	var res: Array[RegEx] = []
	for entry: Array in BANNED:
		var re := RegEx.new()
		# If compilation fails quietly, that pattern **bites nothing** (search_all always returns an empty array).
		t.eq(re.compile(entry[0]), OK, "패턴 [%s] 가 컴파일된다" % entry[1])
		res.append(re)

	for sample: String in MUST_CATCH:
		t.ok(_any_hit(res, _strip(sample)), "감지기가 문다: %s" % sample)
	for sample: String in MUST_PASS:
		t.ok(not _any_hit(res, _strip(sample)), "감지기가 안 문다: %s" % sample)


func _any_hit(res: Array[RegEx], line: String) -> bool:
	for re: RegEx in res:
		if re.search(line) != null:
			return true
	return false


## Recursive. The contract follows even if subfolders are created.
func _scan_dir(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f: String in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub: String in d.get_directories():
		out.append_array(_scan_dir(dir.path_join(sub)))
	out.sort()
	return out


func _scan(t, path: String) -> void:
	var raw := _read(path)
	var nm := path.get_file()
	# `_strip` cannot handle triple quotes — it counts the three quotes one at a time and leaves the string open.
	#  In that state the rest of the file drops out of the scan entirely and it goes **quietly green**.
	#  The assumption is measured here.
	t.ok(not raw.contains("\"\"\""), "%s 에 삼중 따옴표가 없다 (스트리퍼가 못 다룬다)" % nm)
	var src := _strip(raw)
	for entry: Array in BANNED:
		var re := RegEx.new()
		re.compile(entry[0])
		t.ok(re.search(src) == null, "%s 에 %s 가 없다" % [nm, entry[1]])


## Strips the **contents** of comments and strings. This repo deliberately writes banned words in comments,
## so without this the net would catch its own documentation.
##
## **`net_circle` uses this too** (there are two nets that sweep source text). That is why it is `static` —
##  delete it or rename it and that one breaks. **Do not copy it.** Two copies of the stripper means the day
##  comes when only one is fixed, and then the two nets see different text.
##
## **It does not cut the line, it carves out only the string.** The old version threw away everything after the
##  first `"`, so lines like this **dropped out of the scan entirely**:
##    `_fill_rect(int(cmd["x0"]), int(cmd["y0"]), ...)`
##  Lines with real code after a quote are common in this repo, and nothing put there was ever caught.
static func _strip(src: String) -> String:
	var out := ""
	for raw: String in src.split("\n"):
		var line := ""
		var quote := ""
		var i := 0
		while i < raw.length():
			var c := raw[i]
			if quote != "":
				# An escape skips the next character whole — `\"` does not close the string.
				if c == "\\":
					i += 2
					continue
				if c == quote:
					quote = ""
				i += 1
				continue
			if c == "\"" or c == "'":
				quote = c
				i += 1
				continue
			if c == "#":
				break  # from here to end of line is a comment
			line += c
			i += 1
		out += line + "\n"
	return out


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("net_determinism: %s 를 못 읽었다" % path)
		return ""
	return f.get_as_text()
