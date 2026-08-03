extends RefCounted
## 시뮬 코어의 결정론 계약을 소스 텍스트로 검사한다.
##
## 왜 텍스트 스캔인가: 같은 프로세스의 두 인스턴스는 float도 똑같은 답을 낸다.
## 그래서 "두 번 돌려 비교하는" 그물로는 이 계약 위반을 원리적으로 못 잡는다.
## 플랫폼이 갈릴 때만 드러나고, 그때는 이미 두 클라의 세상이 영영 다른 세상이 된 뒤다.
##
## 🔴🔴 목록이 아니라 **폴더**를 스캔한다. v1은 파일 목록을 하드코딩했고
## (`SIM_FILES`), 파일을 하나 더 만들고 등록을 깜빡하면 조용히 안 돌았다.
## 폴더가 계약이면 새 파일이 자동으로 걸린다.
##
## 🔴🔴 **이 그물이 죽는 방식은 「금지어가 없다」가 아니라 「금지어를 못 본다」다.**
## 그 상태에서는 전부 초록이라 아무도 모른다. 실측으로 `randi_range` · `OS.` · 실수 리터럴이
## 전부 통과하고 있었다. ⇒ 아래 `_self_test`가 **각 패턴이 실제로 무는지** 먼저 잰다.
## 감지기를 고칠 때는 반드시 `MUST_CATCH`에 표본을 한 줄 더 넣어라.
##
## 🔴 src/actor/ 는 대상이 아니다. GDD 멀티 표가 플레이어를 호스트 권위로 못 박아서
## float을 써도 된다. 경계는 src/actor/aim.gd 의 return 하나다.

const SIM_DIR := "res://src/sim"

## 금지 목록. 🔴 **금지 대상은 「float 전부」가 아니라 「플랫폼마다 답이 갈리는 것」이다** —
## `+ - *`와 정수 나눗셈은 IEEE-754/C 의미론이 비트까지 같아서 안전하다.
##
## ⚠ `\b` 덕분에 정수판은 안 걸린다: `_isqrt` · `absi` · `mini` · `floori` · `clampi` · `snappedi`.
##  그 성질이 실제로 성립하는지는 아래 `MUST_PASS`가 잰다 — 여기 주석만 믿지 마라.
const BANNED: Array = [
	# ─ 부동소수 그 자체 ─
	["\\bfloat\\b", "float"],
	["\\bPackedFloat\\d*Array\\b", "PackedFloatArray"],
	# 🔴 **실수 리터럴을 안 보면 나머지를 다 막아도 소용없다** — `var t := 0.5` 한 줄이면
	#  상태가 부동소수가 되고, 그때부터 이 폴더의 계약이 통째로 거짓이다.
	["\\d\\.\\d", "실수 리터럴"],
	["[^\\w.]\\.\\d", "실수 리터럴(.5 꼴)"],
	["\\bINF\\b", "INF"],
	["\\bNAN\\b", "NAN"],
	["\\bPI\\b", "PI"],
	["\\bTAU\\b", "TAU"],
	# ─ 부동소수를 들고 다니는 타입 ─
	# ⚠ `Vector2i`는 정수라 안 걸린다(`\b`가 `Vector2i`의 `i` 앞에서 안 끊긴다).
	["\\bVector[234]\\b", "Vector2/3/4"],
	["\\bColor\\b", "Color"],
	# ─ libm — 플랫폼마다 답이 다르다 ─
	["\\b(sqrt|sin|cos|tan|asin|acos|atan|atan2|pow|exp|log|fmod)\\s*\\(", "libm 함수"],
	# ─ float을 돌려주는 전역 함수. 정수판이 따로 있다(absi·mini·maxi·clampi·roundi…) ─
	["\\b(abs|min|max|clamp|round|floor|ceil|sign|snapped|lerp|ease|smoothstep|move_toward|wrapf?)f?\\s*\\(",
		"float 전역 함수"],
	# ─ 난수 — 🔴 스트림이라 호출 횟수 하나만 달라도 영원히 갈라진다 ─
	# ⚠ 옛 목록은 `randi(`·`randf(`만 봐서 **`randi_range`가 그냥 지나갔다.**
	["\\brand[a-z_]*\\s*\\(", "난수 함수"],
	["\\bRandomNumberGenerator\\b", "RandomNumberGenerator"],
	# ─ 시계 — 틱 번호가 상태다. 벽시계를 읽는 순간 클라마다 갈린다 ─
	# ⚠ 옛 목록은 `Time.`만 봐서 **`OS.get_ticks_usec()`가 그냥 지나갔다.**
	["\\bTime\\.", "Time."],
	["\\bOS\\.", "OS."],
	["\\bEngine\\.", "Engine."],
	["\\bdelta\\b", "delta"],
]

## 🔴🔴 **감지기 자신을 재는 표본.** 각 줄은 `BANNED` 중 **적어도 하나**에 걸려야 한다.
## ⚠ 여기 목록이 곧 「이 그물이 무엇을 본다고 주장하는가」다. 주장과 실제가 갈리면 빨개진다.
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

## 🔴 반대쪽. 여기 줄이 걸리면 패턴이 **너무 넓은** 것이고, 그러면 시뮬 코드가 정상적으로
## 쓰는 정수 함수를 못 쓰게 된다 — 그 압력은 결국 그물을 끄는 것으로 끝난다.
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
	# 🔴🔴 **감지기를 먼저 잰다.** 아래 파일 스캔은 감지기가 눈을 뜨고 있을 때만 뜻이 있다.
	_self_test(t)

	var files := _scan_dir(SIM_DIR)
	# 🔴🔴 이 줄이 첫 줄이어야 하는 이유: 빈 폴더를 스캔하면 아래 검사가 하나도 안 돌고
	# 그물이 초록으로 통과한다. 그게 정확히 이 리포가 죽는 방식이다.
	t.ok(files.size() > 0, "%s 에서 스캔한 파일이 0개가 아니다 (%d개)" % [SIM_DIR, files.size()])
	for path: String in files:
		_scan(t, path)


func _self_test(t) -> void:
	var res: Array[RegEx] = []
	for entry: Array in BANNED:
		var re := RegEx.new()
		# 컴파일이 조용히 실패하면 그 패턴은 **아무것도 안 문다**(search_all이 늘 빈 배열이다).
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


## 재귀. 하위 폴더를 만들어도 계약이 따라간다.
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
	# ⚠ `_strip`이 삼중 따옴표를 못 다룬다 — 따옴표 셋을 하나씩 세어 문자열이 열린 채로 남는다.
	#  그 상태면 파일 나머지가 통째로 스캔에서 빠지고 **조용히 초록**이 된다. 가정을 재 둔다.
	t.ok(not raw.contains("\"\"\""), "%s 에 삼중 따옴표가 없다 (스트리퍼가 못 다룬다)" % nm)
	var src := _strip(raw)
	for entry: Array in BANNED:
		var re := RegEx.new()
		re.compile(entry[0])
		t.ok(re.search(src) == null, "%s 에 %s 가 없다" % [nm, entry[1]])


## 주석과 문자열 **내용**을 걷어낸다. 이 리포는 주석에 금지어를 일부러 적어 두므로
## 이걸 안 하면 그물이 자기 설명서를 잡는다.
##
## 🔴 **`net_circle`도 이걸 쓴다**(소스 텍스트를 훑는 그물이 둘이다). 그래서 `static`이다 —
##  지우거나 이름을 바꾸면 거기가 깨진다. ⚠ **베껴 가지 마라.** 스트리퍼가 두 벌이 되면
##  한쪽만 고쳐지는 날이 오고, 그때 두 그물이 서로 다른 텍스트를 본다.
##
## 🔴🔴 **줄을 자르는 게 아니라 문자열만 도려낸다.** 옛 판은 첫 `"` 뒤를 통째로 버려서
##  이런 줄이 **스캔에서 통째로 빠졌다**:
##    `_fill_rect(int(cmd["x0"]), int(cmd["y0"]), …)`
##  따옴표 뒤에 실제 코드가 오는 줄이 이 리포에 흔하고, 거기 무엇을 넣어도 안 걸렸다.
static func _strip(src: String) -> String:
	var out := ""
	for raw: String in src.split("\n"):
		var line := ""
		var quote := ""
		var i := 0
		while i < raw.length():
			var c := raw[i]
			if quote != "":
				# 이스케이프는 다음 글자까지 통째로 건너뛴다 — `\"`가 문자열을 안 닫는다.
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
				break  # 여기부터 줄 끝까지 주석
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
