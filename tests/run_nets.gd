extends SceneTree
## 그물 러너. 헤드리스로 돈다. 씬도 화면도 없다.
##
## 러너 단독 실행은 반쪽이다. 엔진 에러는 러너 안에서 못 가로챈다(Godot에 로거 훅이 없다).
## stderr 검사는 run_nets.ps1이 한다. 반드시 래퍼로 돌려라.
##
## 그물은 tests/nets/net_*.gd 에 둔다. 러너가 디렉토리를 훑어 자동 등록한다.
## 목록을 손으로 들고 있으면 그물을 추가하고 등록을 깜빡하는 순간 조용히 안 돈다.
##
## 사용: Godot.exe --headless --path <프로젝트> --script res://tests/run_nets.gd -- [필터]

const NETS_DIR := "res://tests/nets"

var _pass := 0
var _fail := 0
var _failures: Array[String] = []
var _current := ""


func _initialize() -> void:
	var filter := _arg_filter()
	var files := _collect_nets()
	if files.is_empty():
		printerr("[그물] %s 에 net_*.gd 가 하나도 없다" % NETS_DIR)
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
		print("[그물] 통과 %d개 · %dms" % [_pass, ms])
	else:
		print("[그물] 실패 %d개 / %d개 중 · %dms" % [_fail, _pass + _fail, ms])
		for f: String in _failures:
			print("   x " + f)
	quit(1 if _fail > 0 else 0)


## 실패해도 다음 그물을 계속 돈다. 첫 실패에서 멈추면 한 번에 하나씩만 알게 된다.
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


# ── 단언 ──────────────────────────────────────────────────────────
# assert()를 쓰지 마라. 릴리스에서 사라지고, 첫 실패에서 프로세스가 죽어 나머지가 안 돈다.

## label에는 무엇을 재는지 적어라. "값이 다르다"가 아니라 "물이 왼쪽으로 안 갔다"여야
## 실패 로그만 보고 원인 후보를 좁힐 수 있다.
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


## 일부러 짖게 하는 그물이 자기 짖음에 안 걸리게 하는 문.
## 래퍼는 stderr에 뜬 에러를 전부 실패로 친다. 그런데 "범위 밖 값을 던지면 버리나" 같은
## 그물은 통과할 때 오히려 에러를 낸다. 선언 없이 두면 래퍼가 빨개지고, 사람은 곧 래퍼를 끈다.
## substr는 좁게 적어라. 넓게 적으면 그 그물이 도는 동안 진짜 침묵사도 같이 사면된다.
func expect_error(substr: String) -> void:
	print("[EXPECT] %s" % substr)


# ──────────────────────────────────────────────────────────────────

## 🔴🔴 **`^` 접두는 정확히 일치다 — 부분 일치가 아니다** (2026-08-08, harness-manager 실측).
##  ⚠ **이유**: 병렬 러너는 그물마다 프로세스를 하나씩 띄우고 그 프로세스를 **딱 그 그물에만**
##  묶으려고 짧은 이름을 필터로 준다(`run_nets.ps1`). 그런데 부분 일치라 이름이 서로를 포함하면
##  (`net_sprite` ⊂ `net_monster_sprite`, `net_water` ⊂ `net_water_rain`) **한 프로세스가 여러
##  그물을 몰래 같이 돌린다** — 격리가 깨지고, 시간은 두 그물의 합이 되어 병렬화의 이유가 없어진다.
##  실측: `net_water`용 프로세스가 필터 "water"로 `net_water_rain`까지 물어 57초가 나왔다
##  (`net_water_rain`만 도는 프로세스는 45초였다 — 겹쳐 돈 시간이 그대로 낭비였다).
##  ⇒ **병렬 스폰만 `^`를 쓴다.** 사람이 CLI에 직접 타이핑하는 `-Serial`·수동 실행은
##  그대로 부분 일치다(짧게 쳐서 여러 그물을 한 번에 돌리는 편의가 사라지면 안 된다).
func _arg_filter() -> String:
	var user := OS.get_cmdline_user_args()
	return user[0] if user.size() > 0 else ""


## `filter`가 그물 이름 `nm`("net_xxx")에 맞는가. `^` 접두면 정확히, 아니면 부분 일치.
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
	out.sort()  # 실행 순서를 고정한다. 순서가 흔들리면 실패 재현이 안 된다
	return out
