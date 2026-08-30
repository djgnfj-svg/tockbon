extends RefCounted
## **먼 바다 — what the open water outside the border is made of**, and it is one mechanism chosen out
## of five on 2026-08-30: a lattice with at most one pale object per cell, drifting as one current.
##
## The claim under test is one sentence: **every dial the candidate was judged with is written once in
## `look.gd`, declared under that name in the water shader, handed to the material the sea is actually
## drawn with, and the border is painted OVER the result instead of over the flat colour.**
##
## ⚠⚠ **THE PICTURE IS NOT HERE AND CANNOT BE.** The scatter is nine hash lookups per pixel in GLSL and
## **this repo does not run GLSL**. What comes out on a pixel is `verify-look`'s. **What this file
## measures is what a shader-drawn thing can lie about without any of it showing**: the numbers, the
## names they are handed over under, whether the hand-over happened, and whether the function they feed
## is wired into the picture at all. ⚠ **Everything about what a fleck LOOKS like is reasoned and not
## measured here**, and this file does not pretend otherwise.
##
## ⚠⚠ **THE ONE HOLE A NAME-ONLY NET WOULD LEAVE IS THE ONE THIS MECHANISM ARRIVED WITH.** The
## candidate drifts on the lab's own `lab_t`, a uniform nothing in the game writes. Carried across
## verbatim it compiles, declares every name, hands every number over, and **stands perfectly still for
## ever** with every other row in this file green. `_the_scatter_rides_the_screens_clock` is that row.
##
## Fixtures are ARENA-small. `setup()` rebuilds a whole terrain mesh, and a real island per row is what
## made an old net spin for 24 s unnoticed.


const ARENA_W := 24
const ARENA_H := 12

const SHADER_PATH := "res://src/view/water.gdshader"

## **The candidate's own strength, written here as a literal and nowhere else in the repo.**
##
## ⚠⚠ **THE POINT OF THIS BEING A LITERAL IS THAT `Look` CANNOT MOVE IT.** 「약하게」 is a claim about
## two numbers — the one the user looked at and the one that shipped — and a check that read the
## shipped one twice would call any value weaker than itself.
const JUDGED_AMT := 0.11

## **Every dial section 8 of the shader declares, written out by hand.**
##
## ⚠⚠ **A HAND LIST AND NOT A SCAN, AND THAT IS THE WHOLE VALUE OF IT.** `set_shader_parameter` on a
## name no uniform has is **silently ignored** — no error, no warning, and the flecks simply never
## appear. A list generated from the same file the view is checked against would agree with itself
## whatever either side said. **This is a third opinion, and renaming a uniform on one side reddens.**
const DIALS := [
	"fleck_col", "fleck_cell", "fleck_fill",
	"fleck_r_min", "fleck_r_max", "fleck_hard", "fleck_amt", "fleck_current",
]

## Every `FieldView` built here, freed at the end — a `Node2D` left unfreed is a leaked RID on stderr,
## which the wrapper reads as failure.
var _created: Array = []


func run(t) -> void:
	_the_numbers_are_the_ones_that_were_chosen(t)
	_it_is_weaker_than_the_one_the_user_looked_at(t)
	_the_shader_declares_every_dial_by_that_name(t)
	_the_shader_itself_compiles_and_sees_them(t)
	_the_material_carries_every_one_of_them(t)
	_the_open_water_is_what_the_border_is_drawn_onto(t)
	_the_scatter_rides_the_screens_clock_and_not_the_labs(t)
	_the_border_and_the_boats_read_none_of_it(t)
	_the_readers_are_readers(t)
	for raw in _created:
		var fv: FieldView = raw
		fv.free()
	_created = []
	# **The sentinel.** See `run_nets.done` — without it a `run()` that dies half way still reports
	# every check it managed first, in a shape a healthy net cannot be told from.
	t.done()


# == the numbers ======================================================================================

## **The one place a chosen value is written as a literal.** Everything below reads `Look`, so this is
## what goes red when somebody retunes the sea — and a scatter that measures the same at any density
## measures nothing.
func _the_numbers_are_the_ones_that_were_chosen(t) -> void:
	t.eq(Look.COL_WATER_FLECK, Color(0.855, 0.905, 0.930), "물 위의 것 하나가 이 색이다")
	t.eq(Look.WATER_FLECK_CELL, 7.0, "격자 한 칸이 7조각이다 — 화면에 열여섯 칸쯤 든다")
	t.eq(Look.WATER_FLECK_FILL, 0.55, "그 칸 중 0.55 만 하나를 든다")
	t.eq(Look.WATER_FLECK_R_MIN, 0.35, "제일 작은 것이 0.35조각이다")
	t.eq(Look.WATER_FLECK_R_MAX, 1.10, "제일 큰 것이 1.10조각이다")
	t.eq(Look.WATER_FLECK_HARD, 0.25, "가장자리가 반지름의 0.25 지점부터 무르다")
	t.eq(Look.WATER_FLECK_CURRENT, Vector2(-0.055, -0.030), "전체가 초당 이만큼 한 몸으로 흐른다")

	# ⚠ **The two that would break the mechanism rather than retune it**, written as the relation and
	# not as the value — the values are already pinned above and these say what they are FOR.
	t.ok(Look.WATER_FLECK_R_MIN < Look.WATER_FLECK_R_MAX,
		"제일 작은 것이 제일 큰 것보다 작다 — 크기가 실제로 하나하나 다르다")
	t.ok(Look.WATER_FLECK_FILL > 0.0 and Look.WATER_FLECK_FILL < 1.0,
		"빈 칸이 있고 든 칸도 있다 — 1.0 이면 격자 그 자체가 보인다")
	t.ok(Look.WATER_FLECK_CURRENT.length() > 0.0,
		"흐름이 0 이 아니다 — 멈춰 있으면 배가 지나가는 것을 잴 것이 없다")


## **「약하게」 is a claim about two numbers and this is the row that holds both.**
##
## ⚠⚠ **THE JUDGED VALUE IS A LITERAL IN THIS FILE.** The user approved the candidate at 0.11 and asked
## for it weaker; **a check that read `Look.WATER_FLECK_AMT` on both sides would pass at 0.11, at 0.4
## and at zero.** ⚠ And the floor matters as much as the ceiling: at 0 every name below is still
## declared, still handed over and still compiled, and the sea is the flat colour it was.
func _it_is_weaker_than_the_one_the_user_looked_at(t) -> void:
	t.eq(Look.WATER_FLECK_AMT, 0.09, "지금 나가는 세기가 0.09 다")
	t.ok(Look.WATER_FLECK_AMT < JUDGED_AMT,
		"사용자가 보고 고른 0.11 보다 약하다 — 「약하게 넣어주면될듯」")
	t.ok(Look.WATER_FLECK_AMT > 0.0, "그리고 0 이 아니다 — 0 이면 아래가 전부 공허하다")
	t.ok(Look.WATER_FLECK_AMT > JUDGED_AMT * 0.5,
		"반토막은 아니다 — 이미 바닥 가까운 것에서 한 걸음 내린 것이다")


# == the names ========================================================================================

## **Every dial the view hands over is declared under that name in the shader.**
##
## ⚠⚠ **`set_shader_parameter` ON A NAME NO UNIFORM HAS IS SILENTLY IGNORED** — no error, no warning,
## and the flecks simply never appear. **This is the row that turns a typo into a red**, and it reads
## the shader's own text rather than the view's, so the two are genuinely two opinions.
func _the_shader_declares_every_dial_by_that_name(t) -> void:
	var src := _shader_text()
	t.ok(src.length() > 500, "물 셰이더 원문을 읽었다 (자가 점검 — 못 읽으면 아래가 전부 공허하다)")
	var missing := []
	for raw in DIALS:
		var nm := str(raw)
		if not _declares_uniform(src, nm):
			missing.append(nm)
	t.eq(missing, [], "셰이더가 손으로 적은 다이얼 %d 개를 전부 uniform 으로 선언한다" % DIALS.size())


## **The shader actually compiles, and the engine can see every dial standing on it.**
##
## ⚠⚠ **A GLSL SYNTAX ERROR IS NOT A GDScript PARSE ERROR.** The row above reads the file as text and
## would pass a shader that does not compile at all — it is measuring the NAMES. **This one asks the
## engine**, which is the only opinion that draws.
func _the_shader_itself_compiles_and_sees_them(t) -> void:
	var sh := load(SHADER_PATH) as Shader
	t.ok(sh != null, "물 셰이더가 리소스로 실렸다 (자가 점검)")
	var seen := {}
	for row in sh.get_shader_uniform_list():
		seen[str((row as Dictionary)["name"])] = true
	t.ok(seen.size() > 40,
		"엔진이 uniform 을 %d 개 본다 — 셰이더가 실제로 컴파일됐다" % seen.size())
	var missing := []
	for raw in DIALS:
		if not seen.has(str(raw)):
			missing.append(str(raw))
	t.eq(missing, [], "그중에 손으로 적은 다이얼 %d 개가 전부 있다" % DIALS.size())

	# ⚠ **The lab's clock, and it must NOT be here.** See the head of this file.
	t.ok(not seen.has("lab_t"),
		"실험실의 시계는 안 넘어왔다 — 아무도 안 쓰는 uniform 은 0 에 얼어붙는다")


# == the hand-over ====================================================================================

## **And every one of them is actually ON the material the sea is drawn with.**
##
## ⚠⚠ **THIS IS THE COMMIT HALF AND WITHOUT IT EVERY OTHER ROW IN THIS FILE STAYS GREEN WHEN THE
## HAND-OVER IS DELETED.** The constants can be perfect and the shader can declare every one of them;
## only the material proves they were given to the thing that draws. **A uniform nobody sets is not an
## error in Godot — it is its type's zero**, which for the strength is an invisible sea.
func _the_material_carries_every_one_of_them(t) -> void:
	var fv := _sea_view()
	var mat := _sea_material(fv)
	t.ok(mat != null, "바다에 셰이더 재질이 붙어 있다 (자가 점검)")
	var blank := []
	for raw in DIALS:
		var nm := str(raw)
		if mat.get_shader_parameter(nm) == null:
			blank.append(nm)
	t.eq(blank, [], "그 재질이 다이얼 %d 개를 전부 값으로 들고 있다" % DIALS.size())

	# **And they are the chosen values and not somebody else's**, one row each — a hand-over that sets
	# every name to the same number passes the loop above.
	t.eq(mat.get_shader_parameter("fleck_col"), Look.COL_WATER_FLECK, "재질이 든 색이 고른 그 색이다")
	t.eq(mat.get_shader_parameter("fleck_cell"), Look.WATER_FLECK_CELL, "칸 크기도 그대로 간다")
	t.eq(mat.get_shader_parameter("fleck_fill"), Look.WATER_FLECK_FILL, "든 칸 비율도 그대로 간다")
	t.eq(mat.get_shader_parameter("fleck_r_min"), Look.WATER_FLECK_R_MIN, "최소 반지름도 그대로 간다")
	t.eq(mat.get_shader_parameter("fleck_r_max"), Look.WATER_FLECK_R_MAX, "최대 반지름도 그대로 간다")
	t.eq(mat.get_shader_parameter("fleck_hard"), Look.WATER_FLECK_HARD, "가장자리도 그대로 간다")
	t.eq(mat.get_shader_parameter("fleck_amt"), Look.WATER_FLECK_AMT, "세기도 그대로 간다")
	t.eq(mat.get_shader_parameter("fleck_current"), Look.WATER_FLECK_CURRENT, "흐름도 그대로 간다")

	# ⚠ **The strength is the one that reads as「nothing happened」rather than as「wrong」**, so it is
	# asked a second question the loop above cannot ask.
	# ⚠⚠ **`is float` AND NOT `float(...)`, AND THAT WAS MEASURED.** Deleting the hand-over leaves this
	# a null, and casting a null is not a red — **it is a script error that throws `run()` away and
	# takes the twenty-one checks below it with it**, reported as「불완전」rather than as this row.
	var amt = mat.get_shader_parameter("fleck_amt")
	t.ok(amt is float and amt > 0.0,
		"그리고 재질이 든 세기가 0 보다 크다 — 이름만 다 있고 안 보이는 상태가 아니다")


# == the wiring =======================================================================================

## **The open water is what the border is painted ONTO, and that is the whole of where it enters.**
##
## ⚠⚠ **THE FUNCTION CAN BE PERFECT AND NOTHING CAN CALL IT.** Every row above passes on a shader that
## declares the dials, compiles the scatter and then mixes the border onto the flat `sea` colour
## exactly as before — **the mechanism is in the file and not in the picture.** This is the only row
## that reads the call.
func _the_open_water_is_what_the_border_is_drawn_onto(t) -> void:
	var src := _no_comments(_shader_text())
	var frag := _glsl_func(src, "void fragment()")
	t.ok(frag.length() > 200, "fragment() 본문을 읽었다 (자가 점검)")

	t.eq(_count_in(src, "vec3 open_sea("), 1, "열린 바다를 정하는 함수가 딱 하나 있다")
	t.eq(_count_in(frag, "open_sea(p, t)"), 1, "fragment() 가 그것을 딱 한 번 부른다")
	t.eq(_count_in(frag, "mix(sea.rgb,"), 0,
		"그리고 평평한 바다색 위에 테두리를 얹던 자리가 남아 있지 않다 — 함수만 있고 안 부르는 상태가 아니다")
	t.eq(_count_in(frag, "mix(open_sea(p, t), foam.rgb,"), 1,
		"흰 선이 그 결과 위에 얹힌다 — 테두리가 여전히 위다")


## **The scatter drifts on the screen's clock, and the candidate's did not.**
##
## ⚠⚠ **THIS IS THE ROW THE MECHANISM ARRIVED NEEDING.** `.prototypes/sea` writes `lab_t` from outside so
## six photographs can be taken at one instant. Carried across verbatim that uniform is written by
## nobody, **sits at zero for the life of the process, and the whole scatter is nailed to the world** —
## compiling, declared, handed over, and still. `_the_shader_itself_compiles_and_sees_them` refuses the
## uniform; this refuses the arithmetic that would need it.
func _the_scatter_rides_the_screens_clock_and_not_the_labs(t) -> void:
	var src := _no_comments(_shader_text())
	var body := _glsl_func(src, "vec3 open_sea(")
	t.ok(body.length() > 100, "open_sea() 본문을 읽었다 (자가 점검)")

	t.eq(_count_in(body, "fleck_current * t"), 1,
		"흐름이 시간에 곱해진다 — 이 한 줄이 없으면 무늬가 세상에 못 박힌다")
	t.eq(_count_in(body, "lab_t"), 0, "실험실의 시계는 본문에도 없다")

	# **And the `t` it is handed is `TIME`** — the same clock the border rides. Without this row the
	# one above passes on a `t` that is anything at all, zero included.
	var frag := _glsl_func(src, "void fragment()")
	t.eq(_count_in(frag, "float t = TIME;"), 1,
		"그 t 가 TIME 이다 — 해안선이 타는 시계와 같은 것 하나다")


## **Nothing but `open_sea` reads a `fleck_` dial**, so the coast the user chose out of twenty-seven
## versions is the same coast and the hull marks are the same marks.
##
## ⚠⚠ **THE FAILURE THIS CATCHES IS 「THE SEA WAS TUNED AND THE SHORE MOVED WITH IT」**, which is the one
## thing the lab's whole splicing arrangement exists to make impossible and which nothing enforces once
## the mechanism is out of the lab. ⚠ Comments are stripped first — a note naming a dial is not a use.
func _the_border_and_the_boats_read_none_of_it(t) -> void:
	var src := _no_comments(_shader_text())
	var body := _glsl_func(src, "vec3 open_sea(")
	var frag := _glsl_func(src, "void fragment()")
	var hulls := _glsl_func(src, "vec3 hulls(")

	t.ok(_count_in(body, "fleck_") >= DIALS.size(),
		"다이얼 %d 개가 전부 open_sea() 안에서 쓰인다" % DIALS.size())
	t.eq(_count_in(frag, "fleck_"), 0, "fragment() 는 그중 하나도 안 읽는다 — 해안선이 안 움직였다")
	t.ok(hulls.length() > 200, "hulls() 본문을 읽었다 (자가 점검)")
	t.eq(_count_in(hulls, "fleck_"), 0, "hulls() 도 안 읽는다 — 배의 세 자국도 안 움직였다")


# == the instrument ===================================================================================

## **Every reader above, given something it should say no to and something it should say yes to.**
##
## ⚠⚠ **A READER THAT ALWAYS ANSWERS THE SAME THING PASSES EVERY ROW IN THIS FILE.** Twice in one night
## a check was written to catch a defect and shipped carrying that same defect; these are the cases that
## fail the instrument rather than the subject.
func _the_readers_are_readers(t) -> void:
	# `_declares_uniform`
	t.ok(not _declares_uniform(_shader_text(), "fleck_nonesuch"),
		"자가 점검 — 없는 이름에는 아니라고 한다")
	t.ok(_declares_uniform(_shader_text(), "sea"),
		"자가 점검 — 있는 이름에는 맞다고 한다 (바다 색은 원래부터 있던 uniform 이다)")

	# `_count_in`
	t.eq(_count_in("aXbXc", "X"), 2, "자가 점검 — 세는 쪽이 실제로 센다")
	t.eq(_count_in("aXbXc", "Z"), 0, "자가 점검 — 없는 것은 0 이다")

	# `_glsl_func`
	t.eq(_glsl_func("void f() { a; if (b) { c; } d; }", "void f()").strip_edges(),
		"a; if (b) { c; } d;",
		"자가 점검 — 함수 본문을 중괄호까지 세어서 통째로 가져온다: 첫 } 에서 안 끊긴다")
	t.eq(_glsl_func("void f() {}", "void g()"), "",
		"자가 점검 — 없는 함수에는 빈 문자열을 준다: 못 찾은 것이 조용히 통과하지 않는다")

	# `_no_comments` — the one whose failure would make `_the_border_and_the_boats_read_none_of_it`
	# red on a note rather than on a use.
	t.eq(_no_comments("keep // drop\nkeep2"), "keep \nkeep2",
		"자가 점검 — 주석만 지우고 코드는 남긴다")
	t.eq(_count_in(_no_comments("// fleck_amt\ncode;"), "fleck_"), 0,
		"자가 점검 — 주석에 적힌 다이얼 이름은 사용으로 안 센다")


# == readers ==========================================================================================

## The shader's own text. **Read as a file and not through `Shader`**, so a compile that never happens
## headless cannot turn this into a permanent red.
func _shader_text() -> String:
	var f := FileAccess.open(SHADER_PATH, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


## The same text with every `//` comment gone. ⚠ **There is no block comment and no string literal in
## this shader**, so line-wise is the whole of it — and a `//` inside either would need this rewritten.
func _no_comments(src: String) -> String:
	var out := ""
	for line in src.split("\n"):
		var s := str(line)
		var at := s.find("//")
		if at >= 0:
			s = s.substr(0, at)
		out += s + "\n"
	return out.substr(0, out.length() - 1)


## **One GLSL function's body**, given the start of its signature — `"vec3 open_sea("` — or `""`.
##
## ⚠ **The signature and not the bare name**, because a call site is the name and a bracket too and the
## definition has to be told from the calls. ⚠ **Braces are counted**, so a body with an `if` in it
## comes back whole rather than ending at the first `}`.
func _glsl_func(src: String, sig: String) -> String:
	var at := src.find(sig)
	if at < 0:
		return ""
	var open := src.find("{", at)
	if open < 0:
		return ""
	var depth := 0
	for k in range(open, src.length()):
		var ch := src[k]
		if ch == "{":
			depth += 1
		elif ch == "}":
			depth -= 1
			if depth == 0:
				return src.substr(open + 1, k - open - 1)
	return ""


## How many times a piece of text stands in another.
func _count_in(hay: String, needle: String) -> int:
	var n := 0
	var at := hay.find(needle)
	while at >= 0:
		n += 1
		at = hay.find(needle, at + needle.length())
	return n


## Does the shader declare a uniform by exactly this name. ⚠ **`;`, `:` and `[` all count as an end**,
## because a `source_color` hint and an array length both sit between the name and the semicolon.
func _declares_uniform(src: String, name: String) -> bool:
	for line in src.split("\n"):
		var s := line.strip_edges()
		if not s.begins_with("uniform "):
			continue
		var body := s.substr(8).strip_edges()
		var sp := body.find(" ")
		if sp < 0:
			continue
		var rest := body.substr(sp + 1).strip_edges()
		for stop in [";", ":", "["]:
			var at := rest.find(str(stop))
			if at >= 0:
				rest = rest.substr(0, at)
		if rest.strip_edges() == name:
			return true
	return false


func _sea_material(fv: FieldView) -> ShaderMaterial:
	return fv._sea.material_override as ShaderMaterial


# == fixtures =========================================================================================

func _open(w: int, h: int) -> Array:
	var rows := []
	for y in h:
		if y == 0 or y == h - 1:
			rows.append("~".repeat(w))
		else:
			rows.append("~" + ".".repeat(w - 2) + "~")
	return rows


## An arena with sea round it, and the view that has built the water once.
func _sea_view() -> FieldView:
	var rows := _open(ARENA_W, ARENA_H)
	var g := Grid.new()
	g.load_rows(rows, [])
	var b := Battle.new()
	b.setup(g, Army.new(), [])
	var fv := FieldView.new()
	_created.append(fv)
	fv.setup(b, b.army, rows)
	fv._process(0.0)
	return fv
