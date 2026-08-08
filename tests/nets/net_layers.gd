extends RefCounted
## Holds the rule that the folder is a contract. **References go one way.**
##
##   src/sim/    Integer determinism. Knows nothing of the scene tree
##   src/actor/  float allowed (the player is host-authoritative). Still knows nothing of the scene tree
##   src/view/   Screen only. Reads the sim, never writes it
##   src/stage/  The shell. Will not survive into the real game
##
## The moment sim or actor references view or stage, "the sim knows the scene tree" becomes true,
## and the server cannot run headless. The nets running without a scene die with it.
##
## And **nobody writes down the dead paths (src/world/ · src/sandbox/).**
##
## **What this check measures changed when v1 was deleted. The label must not stay the old one.**
##  The old contract "new code does not preload v1" is now **impossible in principle** —
##  preloading a file that does not exist is a parse error, so `_parses` below bites first.
##  => What remains and actually catches things is the **dead path strings** (in comments, constants,
##   and scenes: `res://src/world/...`).
##   It looks weak but it is real: another doc in this repo was actually pointing at a vanished
##   `spell_tuning.gd` today. Inside `src/`, this check blocks that.
## **Do not delete it saying "v1 is gone, so this is no longer needed".** The moment it goes,
##  dead paths quietly pile up.

## Paths each folder must not reference.
## When adding a key, look at the value too — an empty array means that folder measures nothing and goes green.
const RULES: Dictionary = {
	"res://src/sim": ["res://src/view", "res://src/stage", "res://src/actor"],
	"res://src/actor": ["res://src/view", "res://src/stage"],
	"res://src/view": [],
	"res://src/stage": [],
}

## Banned across all new code regardless of folder. v1 is code to be thrown away.
const V1_DIRS: Array[String] = ["res://src/world", "res://src/sandbox"]


func run(t) -> void:
	var total := 0
	for dir: String in RULES.keys():
		var files := _scan_dir(dir)
		# **The first line of any folder-scanning net.** Scanning an empty folder runs no check at all
		# and the net passes green — that is exactly how this repo dies.
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


## **Does it even load — that is as far as this goes: "the file is missing / cannot be read".**
##  Files the nets do not preload (`blast_fx.gd` · `character_view.gd` · `spell_view.gd`, scenes, shaders)
##  only surface when the game is launched, so at least a dead name gets bitten here.
##
## **Do not read this as "broken syntax gets caught here" — that is false.**
##  Measured (stage 0 verification): a syntax error was put into `world_step.gd` and the full nets ran —
##  **this line was green and there were 0 failures**; only the pass count dropped 1056 -> 1054.
##  That is, the check **did not fail, it disappeared** (the shape that is indistinguishable from a pass in the log).
##  => CLAUDE.md is right: **`load()` is not null even when parsing fails.** Shaders are the same
##   (not null even when compilation fails) and `net_render` filled that hole with `get_shader_uniform_list()`.
## **The only thing that actually catches broken syntax is the wrapper's stderr line.** Do not stand this up in its place.
## **It cannot measure whether things run.** A call with a diverged signature is a runtime error and is not caught here.
##  `@onready` paths in scenes are looked at separately by `net_render`.
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
		# .gdshader is looked at too — a shader holding a v1 path just quietly does not run, with no error.
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
