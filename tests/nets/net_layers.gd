extends RefCounted
## 폴더가 계약이라는 걸 지킨다. **참조 방향은 한 방향이다.**
##
##   src/sim/    정수 결정론. 씬 트리를 모른다
##   src/actor/  float 허용(플레이어는 호스트 권위). 씬 트리는 여전히 모른다
##   src/view/   화면만. 시뮬을 읽기만 한다
##   src/stage/  껍데기. 본편에 안 남는다
##
## 🔴 sim·actor 가 view·stage 를 참조하는 순간 "시뮬이 씬 트리를 안다"가 되고,
## 서버가 헤드리스로 못 돌린다. 그물이 씬 없이 도는 것도 같이 죽는다.
##
## 🔴 그리고 **아무도 죽은 경로(src/world/ · src/sandbox/)를 안 적는다.**
##
## ⚠ **이 검사가 재는 것이 v1 삭제로 바뀌었다. 라벨을 옛것으로 두면 안 된다.**
##  옛 계약이던 「새 코드가 v1을 preload 안 한다」는 이제 **원리적으로 불가능**하다 —
##  없는 파일을 preload 하면 파스 에러라 아래 `_parses`가 먼저 문다.
##  ⇒ 지금 남아서 실제로 잡는 것은 **죽은 경로 문자열**(주석·상수·씬 안의 `res://src/world/...`)이다.
##   약해 보이지만 진짜다: 실제로 오늘 리포의 다른 문서가 사라진 `spell_tuning.gd`를 가리키고 있었다.
##   `src/` 안에서는 이 검사가 그걸 막는다.
## 🔴 **「v1 지웠으니 이제 필요 없다」며 지우지 마라.** 지우는 순간 죽은 경로가 조용히 쌓인다.

## 각 폴더가 참조하면 안 되는 경로들.
## ⚠ 키를 늘릴 때 값도 같이 봐라 — 빈 배열을 넣으면 그 폴더는 아무것도 안 재고 초록이 된다.
const RULES: Dictionary = {
	"res://src/sim": ["res://src/view", "res://src/stage", "res://src/actor"],
	"res://src/actor": ["res://src/view", "res://src/stage"],
	"res://src/view": [],
	"res://src/stage": [],
}

## 폴더와 무관하게 새 코드 전체에 걸리는 금지. v1은 버릴 코드다.
const V1_DIRS: Array[String] = ["res://src/world", "res://src/sandbox"]


func run(t) -> void:
	var total := 0
	for dir: String in RULES.keys():
		var files := _scan_dir(dir)
		# 🔴🔴 폴더 스캔 그물의 첫 줄. 빈 폴더를 스캔하면 검사가 하나도 안 돌고
		# 초록으로 통과한다 — 그게 정확히 이 리포가 죽는 방식이다.
		t.ok(files.size() > 0, "%s 에 파일이 있다 (%d개)" % [dir, files.size()])
		total += files.size()
		for path: String in files:
			var src := _read(path)
			var nm := path.get_file()
			for banned: String in RULES[dir]:
				t.ok(not src.contains(banned), "%s 가 %s 를 참조하지 않는다" % [nm, banned])
			for v1: String in V1_DIRS:
				t.ok(not src.contains(v1), "%s 가 v1(%s)을 참조하지 않는다" % [nm, v1])
			_parses(t, path, nm)
	t.ok(total > 0, "새 코드가 하나라도 있다 (%d개)" % total)


## 🔴🔴 **읽히기라도 하나 — 「파일이 없다·못 읽는다」까지다.**
##  그물이 preload 하지 않는 파일(`blast_fx.gd`·`character_view.gd`·`spell_view.gd`·씬·셰이더)은
##  게임을 띄워야만 드러나는 자리라, 이름이 죽은 것만이라도 여기서 문다.
##
## 🔴🔴 **⚠ 「문법이 깨지면 여기서 잡힌다」로 읽지 마라 — 거짓이다.**
##  실측(2026-08-04, 단계 0 검증): `world_step.gd`에 문법 오류를 넣고 전체 그물을 돌렸더니
##  **이 줄이 초록이었고 실패는 0개**였다 — 통과 수만 1056 → 1054로 줄었다.
##  즉 검사가 **실패한 게 아니라 없어졌다**(로그에서 통과와 구별이 안 되는 그 모양이다).
##  ⇒ CLAUDE.md 쪽이 맞다: **`load()`는 파스 실패해도 null이 아니다.** 셰이더도 같고
##   (컴파일 실패해도 null이 아니다) 그 구멍은 `net_render`가 `get_shader_uniform_list()`로 메웠다.
## 🔴 **깨진 문법을 실제로 잡는 것은 래퍼의 stderr 한 줄뿐이다.** 여기를 그 대신으로 세우지 마라.
## ⚠ **도는 것까지 재지는 못한다.** 시그니처가 갈린 호출은 런타임 에러라 여기 안 걸린다.
##  씬의 `@onready` 경로는 `net_render`가 따로 본다.
func _parses(t, path: String, nm: String) -> void:
	if not (path.ends_with(".gd") or path.ends_with(".gdshader") or path.ends_with(".tscn")):
		return
	t.ok(load(path) != null, "%s 가 읽힌다" % nm)


func _scan_dir(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f: String in d.get_files():
		# .gdshader 도 본다 — 셰이더가 v1 경로를 물고 있어도 조용히 안 돌 뿐 에러가 안 난다.
		if f.ends_with(".gd") or f.ends_with(".gdshader") or f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for sub: String in d.get_directories():
		out.append_array(_scan_dir(dir.path_join(sub)))
	out.sort()
	return out


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("net_layers: %s 를 못 읽었다" % path)
		return ""
	return f.get_as_text()
