extends RefCounted
## 화면 쪽이 **설 수 있나.** 🔴 그물이 원리적으로 못 재는 「그려진 그림」이 아니라,
## **그리기도 전에 죽는 것**을 잰다.
##
## 🔴🔴 **왜 생겼나 — 실측이다.**
##  단계 5에서 `flag_tex` uniform을 추가하며 sampler를 함수 인자로 넘겼더니
##  (`l8_to_int(TEXTURE, …)`와 `l8_to_int(flag_tex, …)`) Godot 셰이더 컴파일러가
##  「같은 sampler 인자를 내장과 uniform 양쪽으로 부를 수 없다」며 **컴파일에 실패했다.**
##  그런데 **게임은 안 멈췄다** — 격자가 L8 원본 바이트값(돌 1 · 나무 2 · 빈칸 0)으로 그려져
##  거의 검은 화면이 됐고, `_draw()`로 그리는 캐릭터만 제 색으로 떠 있었다.
##  **그 상태에서 그물 534개가 전부 초록이었다.**
##
## ⇒ 이 리포의 대표 침묵사(「그물은 초록인데 화면이 안 뜬다」)가 정확히 그 모양이다.
##  셰이더는 **엔진이 조용히 포기하는 유일한 자산**이라 따로 잴 값어치가 있다.

const VIEW_DIR := "res://src/view"
const STAGE_SCENE := "res://src/stage/stage.tscn"
const STAGE_SCRIPT := "res://src/stage/stage.gd"
const CellRenderer := preload("res://src/view/cell_renderer.gd")
const Mat := preload("res://src/sim/cell_materials.gd")


func run(t) -> void:
	var shaders := _scan_shaders(VIEW_DIR)
	# 🔴 폴더 스캔 그물의 첫 줄. 빈 목록을 훑으면 아래가 하나도 안 돌고 초록으로 통과한다.
	t.ok(shaders.size() > 0, "%s 에서 셰이더를 찾았다 (%d개)" % [VIEW_DIR, shaders.size()])
	for path: String in shaders:
		_compiles(t, path)
	_injection_matches_shader(t)
	_palette_size_matches(t)
	_onready_paths_resolve(t)


## 🔴🔴 **셰이더의 `palette[N]` 과 `Mat.SLOT_COUNT` 는 짝이다.**
##  ⚠ 실측: `palette[16]` 을 `palette[8]` 로 바꿔도 **580개가 전부 초록이고 stderr까지 깨끗하다.**
##   셰이더는 **정상 컴파일되고** `palette[mat_id]` 가 배열 밖을 읽는다 — GLSL에서 정의되지 않은
##   동작이라 **기계마다 다르게** 틀어진다. 짖는 사람이 아무도 없다.
##  🔴 `cell_materials.gd` 가 스스로 「셰이더의 `palette[16]` 과 같은 값이어야 한다」고 적어 뒀는데
##   그 문장을 지키는 코드가 없었다 — 주석이 계약을 대신할 수 없다는 표본이다.
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


## 🔴🔴 **`@onready var _x = $Path` 의 경로가 씬에 실재하나.**
##  ⚠ 노드 이름을 하나 바꾸면 게임은 `null` 참조로 죽는데 그물은 **파싱만 보므로 초록이다.**
##   씬은 지금까지 v1 경로 문자열 검사만 받고 있었다.
## ⚠ **여전히 못 잡는 것**: 함수 시그니처 불일치(예: `on_blasts` 인자 수)는 런타임 에러라
##  여기 안 걸린다. 씬을 세우기만 하고 **돌리지는 않는다.**
func _onready_paths_resolve(t) -> void:
	var scene: PackedScene = load(STAGE_SCENE)
	t.ok(scene != null and scene.can_instantiate(), "무대 씬을 세울 수 있다")
	if scene == null or not scene.can_instantiate():
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
	# ⚠ 트리 밖이라 `queue_free`가 아니라 `free`다.
	root.free()


## 🔴🔴 **`get_shader_uniform_list()`가 비면 컴파일 실패다.** 헤드리스에서 이 한 줄로 잡힌다.
##
## ⚠ 「비었나」가 아니라 **「선언한 수와 같나」**로 잰다. 「비었나」만 보면 uniform이 하나도 없는
##  셰이더가 늘 통과하고, 그때부터 이 검사는 그 파일에 대해 **영영 아무것도 안 재는 상태**가 된다.
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


## 🔴🔴 **셰이더가 안 받는 이름으로 주입하면 아무 일도 안 일어난다 — 에러도 없다.**
##  팔레트를 넣었는데 이름이 한 글자 틀리면 화면이 마젠타도 아니고 그냥 검다.
## 🔴 반대쪽도 잰다: 선언만 하고 **아무도 안 넣는 uniform은 거짓 손잡이다**(CLAUDE.md).
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


## 셰이더 코드에서 uniform 선언 수. ⚠ 줄 **첫머리**만 본다 — 주석에 「uniform」이라고 쓴 줄이
##  세지면 그 순간 이 검사가 조용히 헛돈다.
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
