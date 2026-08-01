extends SceneTree
## 전 스위트 러너 — 한 명령으로 `tests/*_auto.gd`를 전부 돌리고 집계한다.
##
## 쓰는 법:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tools/run_tests.gd
##   ... -s res://tools/run_tests.gd -- realtime      # 전부 실시간(가장 보수적 · 옛 동작과 동일)
##   ... -s res://tools/run_tests.gd -- ring          # 이름에 "ring"이 든 것만
##
## ─────────────────────────────────────────────────────────────────────────────
## 🔴🔴 왜 「한 프로세스에 여러 테스트」가 아닌가 (세104 실측 — 다시 시도하지 마라)
##
## 이 러너는 테스트마다 **자식 프로세스를 따로 띄운다.** 부팅을 1회로 줄이는 설계를
## 먼저 시도했고 **엔진 수준에서 불가능**하다는 것을 실측으로 확인했다:
##
##   ① 테스트는 전부 `extends SceneTree`이고 **프로세스당 메인 루프는 하나**다.
##   ② `TestScript.new()`로 두 번째 SceneTree를 만들면 **자기만의 빈 root Window**가 생긴다
##      (실측: 자식 0개 · `GameState` 없음). 오토로드가 없어 `root.get_node("GameState")`가 죽고,
##      그 tree는 iterate되지 않아 `await process_frame`이 **영영 안 깨어난다.**
##   ③ 실 tree에 `set_script(테스트)`를 걸면 `_init`이 다시 돌고 테스트가 **실제로 통과한다**
##      (실측: `TEST_RING_ASSEMBLY_OK`). 그러나 테스트가 끝에서 부르는 `quit()`이
##      **프로세스를 죽여** 두 번째 테스트로 못 넘어간다.
##   ④ `quit()`을 가로채려고 테스트를 상속한 래퍼에 `func quit()`을 얹어 봤다. 컴파일은 되지만
##      (`@warning_ignore("native_method_override")`) **호출이 안 걸린다** — GDScript가 테스트 안의
##      `quit()`을 **네이티브 직접 호출로 컴파일**해서 서브클래스 오버라이드를 지나치지 않는다.
##
## → 즉 「부팅 1회」는 `tests/`를 고쳐야만 가능하고, 고치지 않는 한 **프로세스당 테스트 1개가 상한**이다.
##
## 🔴 그리고 실측상 그 방향은 애초에 값이 작았다: 부팅은 1회 ≈ 0.70s라 41회를 다 합쳐도
##    **28.7s / 199.6s = 14%**다. 시간을 먹는 건 부팅이 아니라 **`await physics_frame`이
##    벽시계 60Hz에 묶여 있는 것**이었다(느린 9개가 115s = 58%).
##
## ─────────────────────────────────────────────────────────────────────────────
## 🔴 그래서 실제 지렛대 = `--fixed-fps`
##
## 헤드리스에서도 델타는 **실제 경과 시간**에서 나온다. 그래서 `await physics_frame`은
## 초당 60번밖에 안 깨어나고, 3초를 기다리는 테스트는 **벽시계로 3초**를 쓴다.
## `--fixed-fps 60`은 델타를 1/60로 **고정**해 프레임을 CPU 속도로 돌린다 — 게임 시간은 같고
## 벽시계만 줄어든다(실측: `test_enemy_ai_auto` 25.0s → 1.35s, 결과 동일).
##
## 🔴🔴 단, **벽시계를 읽는 테스트는 여기서 거짓 빨강이 난다.** 게임은 가상 시간으로 흐르는데
##    테스트가 `Time.get_ticks_msec()`로 실시간을 재면 둘이 갈린다
##    (실측: `test_mana_burst_auto`의 「자연 재생 상한」이 0.03s 경과로 계산돼 실제 재생 0.93을 못 덮는다).
## 🔴 그 목록을 **손으로 적지 않는다** — 소스를 스캔해서 파생시킨다(아래 `_reads_wall_clock`).
##    takbon-verify §1의 규율 그대로다: 목록을 박으면 낡고, **새 벽시계 테스트가 조용히 샌다.**

const TESTS_DIR := "res://tests"
const REALTIME_MARKERS: Array[String] = ["Time.get_ticks_", "Time.get_unix_"]

## 🔴🔴 엔진 `ERROR:`는 `SCRIPT ERROR:`가 **아니다** — 그래서 이 러너를 그냥 통과했다(세112 실측).
## 세112 단계 2·3·4가 **연달아** 이 사각에 걸렸다: 물리 flush 중 `add_child`, 씬 노드가 사라진 뒤의
## `push_error`, 방 밖 스폰. 전부 **엔진이 짖는데 전 스위트가 그린**이었다.
##
## 🔴 그런데 판정에는 안 넣는다 — **세되 보고만 한다.** 종료 잡음이 거의 모든 테스트에 뜨는 자리라
##    바로 판정에 넣으면 매번 무더기가 빨개지고, 그러면 사람이 빨강을 무시하기 시작한다
##    (그게 그물 전체를 죽이는 병 — `_score`의 종료 코드 주석이 같은 이유로 코드를 버렸다).
##    실제로 몇 개가 나오는지 보고 나서 판정에 넣을지 정한다.
## ⚠ **`push_error`도 여기 걸린다**(실측 — `USER ERROR:`가 아니라 `ERROR:`로 찍힌다).
##    그래서 **테스트가 일부러 태우는 것까지 잡힌다.**
##
## 🔴 **기준선 = 3건이고 셋 다 의도된 것이다**(세112 실측 — `test_chapter_auto`의 없는 챕터 ·
##    `test_chest_open_auto`의 없는 지점 · `test_landmark_road_auto`의 Node2D 아닌 루트).
##    ⚠ **그 셋을 잡음 목록에 넣지 마라** — 문구가 바뀌면 필터가 낡고, 그 필터가 **진짜 에러를 가린다.**
##    **4건이 되면 그게 새로 생긴 것**이라는 게 이 기준선의 쓸모다.
##
## ✅ 같은 실측이 하나를 증명했다: **물리 콜백 `add_child` 에러가 0건**이다
##    (단계 4의 상자 스폰이 `call_deferred`를 지난다는 독립 증거 — 그물이 못 가르던 것을 여기서 본다).
const ENGINE_ERROR_NOISE: Array[String] = [
	"resources still in use at exit",  # 거의 모든 테스트에 뜬다 — boss_room을 안 여는 것에도 뜬다
]

var _rows: Array[Dictionary] = []


func _init() -> void:
	_run.call_deferred()


## 벽시계를 읽는 테스트인가 — 읽으면 `--fixed-fps`를 **주지 않는다**.
## 🔴 목록이 아니라 스캔이라 새 테스트가 자동으로 든다(안 낡는다).
func _reads_wall_clock(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return true  # 못 읽으면 보수적으로 실시간
	var src := f.get_as_text()
	f.close()
	for marker: String in REALTIME_MARKERS:
		if src.contains(marker):
			return true
	return false


## `tests/*_auto.gd`를 파일시스템에서 파생시킨다 — 하드코딩 목록 금지(takbon-verify §1).
func _collect_tests() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(TESTS_DIR)
	if d == null:
		push_error("tests/ 를 열 수 없다: %s" % TESTS_DIR)
		return out
	for name: String in d.get_files():
		if name.begins_with("test_") and name.ends_with("_auto.gd"):
			out.append(name)
	out.sort()
	return out


func _run() -> void:
	var argv := OS.get_cmdline_user_args()
	var force_realtime := argv.has("realtime")
	var filter := ""
	for a: String in argv:
		if a != "realtime":
			filter = a

	var names := _collect_tests()
	if filter != "":
		var kept: Array[String] = []
		for n: String in names:
			if n.contains(filter):
				kept.append(n)
		names = kept

	if names.is_empty():
		print("러너: 돌릴 테스트가 없다 (filter=%s)" % filter)
		quit(1)
		return

	var exe := OS.get_executable_path()
	print("=== 탁본 전 스위트 러너 — %d개 ===" % names.size())
	print("엔진: %s" % exe)
	if force_realtime:
		print("모드: realtime (전부 실시간 — 가장 보수적)")
	else:
		print("모드: 기본 (벽시계를 안 읽는 테스트만 --fixed-fps 60)")
	print("")

	var t_all := Time.get_ticks_msec()
	for name: String in names:
		var path := "%s/%s" % [TESTS_DIR, name]
		var realtime := force_realtime or _reads_wall_clock(path)
		var args: PackedStringArray = ["--headless", "--path", "."]
		if not realtime:
			args.append_array(["--fixed-fps", "60"])
		args.append_array(["-s", path])

		var out: Array = []
		var t0 := Time.get_ticks_msec()
		# read_stderr = true — 엔진 에러가 stderr로 나가서 안 켜면 SCRIPT ERROR를 놓친다.
		var code := OS.execute(exe, args, out, true, false)
		var ms := Time.get_ticks_msec() - t0
		_rows.append(_score(name, realtime, ms, code, "\n".join(out)))

	var total := Time.get_ticks_msec() - t_all
	_report(total)


## `TEST_FOO_OK — 전 항목 통과`에서 **ASCII 토큰만** 뽑는다.
## ⚠ 자식 프로세스 출력은 콘솔 코드페이지를 거치며 한글이 깨진다(`??6嫄??ㅽ뙣`).
##   판정에 필요한 건 토큰뿐이라 뒤의 한글은 버린다 — 자세한 이유는 그 테스트를 낱개로 다시 돌려 읽어라.
func _marker_token(line: String) -> String:
	var cut := line.find(" ")
	return line.substr(0, cut) if cut > 0 else line


## 한 테스트의 출력에서 판정을 뽑는다.
## 🔴 집계 형식은 이 프로젝트 것 — `TEST_*_OK` / `TEST_*_FAIL`이지 `fail=N`이 아니다(takbon-verify §4-3).
func _score(name: String, realtime: bool, ms: int, code: int, text: String) -> Dictionary:
	var ok := false
	var failed := false
	var timeout := false
	var marker := ""
	var detail := ""
	var errs: Array[String] = []
	var engine_errs: Array[String] = []

	for line: String in text.split("\n"):
		var t := line.strip_edges()
		# 🔴 콜론까지 맞춘다 — 엔진 형식은 `SCRIPT ERROR:`다. 콜론을 빼면
		#    `test_landmark_road_auto`가 자기 주석에 적은 "SCRIPT ERROR와 다르다"를
		#    잡아 **매번 거짓 양성**이 난다(세104 실측).
		if t.begins_with("SCRIPT ERROR:"):
			errs.append(t)
		elif t.begins_with("ERROR:") and not _is_engine_noise(t):
			engine_errs.append(t)
		elif t.begins_with("TEST_") and t.contains("_OK"):
			ok = true
			marker = _marker_token(t)
		elif t.begins_with("TEST_") and t.contains("_FAIL"):
			failed = true
			marker = _marker_token(t)
		elif t.begins_with("TEST_") and t.contains("_TIMEOUT"):
			timeout = true
			marker = _marker_token(t)
		elif t.begins_with("RESULT pass="):
			detail = t
		elif t.begins_with("FAIL:"):
			errs.append(t)

	# 🔴🔴 **판정은 마커 + `SCRIPT ERROR:`로 한다 — 종료 코드로 하지 마라**(세104 실측).
	#
	# 처음엔 `code == 0`을 OK의 필요조건에 넣었는데, 전 스위트를 **세 번 돌려 세 번 다
	# 「서로 다른」 테스트가 하나씩 FAIL**로 찍혔다(`ring_assembly` → `feel` → `audio`).
	# 셋 다 단독 실행에선 **종료 코드 0 · 마커 `_OK` · `SCRIPT ERROR` 0**이었다.
	# 즉 종료 코드가 간헐적으로 흔들린다(엔진이 종료 시 *"resources still in use"*를 뱉는
	# 자리와 맞물린 것으로 보인다 — 이 경고는 거의 모든 테스트에 뜬다).
	# ⚠ 그 상태로 두면 **매번 무작위 한 개가 빨개져 「전 스위트 그린」이 영영 안 나온다** —
	#   그러면 사람이 빨강을 무시하기 시작하고, 그게 그물 전체를 죽인다.
	#
	# 이 프로젝트의 계약은 `TEST_*_OK` / `TEST_*_FAIL` 마커다(takbon-verify §4-3).
	# 🔴 **진짜 크래시는 여전히 잡힌다** — 크래시하면 마커를 못 찍으므로 `ok == false`가 되어 FAIL이다.
	#    종료 코드는 **버리지 않고 표시만** 한다(`OK(코드N)`).
	var verdict := "FAIL"
	if timeout:
		verdict = "TIMEOUT"
	elif ok and not failed and errs.is_empty():
		verdict = "OK" if code == 0 else "OK(코드%d)" % code
	elif ok and not failed and not errs.is_empty():
		verdict = "OK(에러있음)"

	var tag := "실시간" if realtime else "fixed60"
	print("%-34s %7dms  %-6s  %-12s %s" % [name, ms, tag, verdict, marker])
	for e: String in errs:
		print("        ! %s" % e)

	return {
		"name": name, "ms": ms, "verdict": verdict, "realtime": realtime,
		"detail": detail, "errs": errs, "code": code, "engine_errs": engine_errs,
	}


## 알려진 종료 잡음인가 — 판정에도 집계에도 안 넣는다.
func _is_engine_noise(line: String) -> bool:
	for n: String in ENGINE_ERROR_NOISE:
		if line.contains(n):
			return true
	return false


func _report(total_ms: int) -> void:
	var okc := 0
	var bad: Array[String] = []
	# ⚠ `OK(코드N)`도 통과로 센다 — 마커가 `_OK`이고 `SCRIPT ERROR`가 0인 경우다(위 `_score` 주석).
	#   `OK(에러있음)`은 **통과가 아니다**(에러를 쏟으면서 OK를 찍는 게 이 리포의 대표 함정이다).
	for r: Dictionary in _rows:
		var v := String(r["verdict"])
		if v == "OK" or v.begins_with("OK(코드"):
			okc += 1
		else:
			bad.append("%s [%s]" % [r["name"], v])

	print("")
	print("=== 요약 ===")
	print("총 %d개 · 통과 %d · 문제 %d · %.1fs" % [_rows.size(), okc, bad.size(), total_ms / 1000.0])

	# 🔴 엔진 `ERROR:` — 판정에 안 넣고 보고만 한다(위 `ENGINE_ERROR_NOISE` 주석의 이유).
	#    ⚠ 여기 뜨는 줄은 「그린인데 엔진이 짖고 있다」는 뜻이다. 무시하지 말고 원인을 캐라.
	var eng_total := 0
	var eng_rows: Array[String] = []
	for r: Dictionary in _rows:
		var ee: Array = r["engine_errs"]
		if ee.is_empty():
			continue
		eng_total += ee.size()
		eng_rows.append("  ⚠ %s — %d건: %s" % [r["name"], ee.size(), ee[0]])
	if eng_total > 0:
		print("")
		print("엔진 ERROR: %d건 (판정과 무관 — SCRIPT ERROR가 아니라 이 러너가 원래 못 보던 것)" % eng_total)
		for line: String in eng_rows:
			print(line)
	if bad.is_empty():
		print("SUITE_OK — 전 항목 통과")
		quit(0)
	else:
		for b: String in bad:
			print("  🔴 %s" % b)
		print("SUITE_FAIL — %d개 문제" % bad.size())
		quit(1)
