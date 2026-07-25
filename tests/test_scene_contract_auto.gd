extends SceneTree
## 🔴🔴 **씬 계약 자동 검증 — 화면 덮는 Control의 `mouse_filter`** (세84 감사 #14) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_scene_contract_auto.gd
## 전 항목 통과 시 "TEST_SCENE_CONTRACT_OK".
##
## 🔴 **이 프로젝트가 두 번 밟은 최다 재발 버그**다(세25 base·세26 forest): 화면을 덮는 Control의
## `mouse_filter`가 기본값 **STOP**이면 바닥이 좌클릭을 전부 먹어 **발사가 에러도 경고도 없이 죽는다**.
## 세26 실측: 숲 Ground의 `mouse_filter = 2`를 빼자 실게임 발사 0회였는데 **헤드리스 전 스위트가
## 그린이었다**(신규 test_forest_auto 포함).
##
## 🔴🔴 **그럼 왜 이 파일은 헤드리스로 잴 수 있나** — 재는 대상이 다르다.
##   • **못 재는 것** = 「클릭이 실제로 닿는가」(Control 히트 테스트). 렌더가 없어 실제와 다르고
##     `push_input`을 써도 GUI 계층을 제대로 안 탄다 → 그건 여전히 사용자 F5의 몫이다.
##   • **잴 수 있는 것** = 「그 값이 IGNORE인가」. 실패 형태가 늘 **「씬에서 그 줄이 빠진다」**이므로
##     노드 프로퍼티를 읽는 것으로 잡힌다 — 렌더가 필요 없다. 그물이 싼데 없었다(감사 #14).
##   → 즉 **1차 방어선(값)은 여기, 2차 방어선(도달)은 F5**다. `test_base_auto [7]`의 검출력 0 경고는
##     그 파일에 문서로 남겨 뒀고, 근거는 이 파일이다.
##
## 계약: **게임플레이 씬을 붙여 놓고(모달을 하나도 안 연 상태에서), 보이는 채로 화면을 덮는 Control은
## 전부 `MOUSE_FILTER_IGNORE`여야 한다.** = "쉬는 상태의 마우스와 게임 월드 사이엔 아무것도 없다".
##   • 씬의 `.tscn`이 값을 쥔 것(base·boss_room의 `Ground`)과 코드가 `_ready`에서 세우는 것
##     (`hud.gd:152` = IGNORE)이 **둘 다** 한 그물에 걸린다 — 그래서 인스턴스만 하지 않고 붙인다.
##   • 모달(tab_panel·chapter_panel…)은 **닫혀 있을 때 `visible = false`**라 여기 안 걸린다.
##     열린 모달이 클릭을 먹는 건 **의도**다(패널을 보며 실수로 안 쏜다) — 그래서 가시성으로 가른다.
##
## 🔴 **씬 목록을 하드코딩하지 않는다** — 하면 새 씬이 그물에서 빠지고, 이 버그는 정확히
## **새 씬을 만들 때마다 되살아난다**(세26이 그랬다). 대신 `src/`를 훑어 **플레이어를 인스턴스하는
## 씬**(= 좌클릭 발사가 있는 씬)을 게임플레이 씬으로 잡는다. 새 필드·보스방을 만들면 자동으로 편입된다.
##
## ⚠ -s 모드는 오토로드보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지. 첫 프레임 후 load().

## 게임플레이 씬 판별 = 이 씬을 인스턴스하는가 (좌클릭 조준·발사가 사는 자리).
const PLAYER_SCENE := "src/actors/player.tscn"

var failures: int = 0
## 씬별로 **실제로 검사한** 「화면 덮는 Control」 수 — 0이면 그물이 아무것도 안 잰 것이다(자명 통과 감지).
var _covering: Dictionary = {}


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		print("TEST_SCENE_CONTRACT_TIMEOUT — 60초 초과")
		quit(1))
	await process_frame

	# 🔴 보스방은 `pending_chapter`가 비면 **베이스로 되돌아간다**(의도된 침묵 금지 가드) — 그러면
	# 씬을 붙여도 자기 노드를 안 세운다. 실제로 플레이하는 상태를 만들어 놓고 잰다.
	var gs = root.get_node("/root/GameState")
	gs.pending_chapter = &"ch1"

	var scenes := _gameplay_scenes()
	print("[1] 게임플레이 씬 스캔 (플레이어를 인스턴스하는 씬)")
	for p in scenes:
		print("    · %s" % p)
	_check(scenes.size() >= 2,
		"게임플레이 씬을 2장 이상 찾았다 (실제 %d — base·boss_room. 0~1이면 스캔이 깨졌다)"
			% scenes.size())

	print("[2] 🔴 보이는 채로 화면을 덮는 Control은 전부 mouse_filter = IGNORE")
	for p in scenes:
		await _audit_scene(p)

	# 🔴🔴 **자명 통과 방지 앵커** (세61·감사 #41의 「0행은 PASS가 아니다」). 위 루프는 검사 대상이
	# 하나도 없어도 조용히 통과한다 — 진입 씬에서 최소 하나는 반드시 봤어야 한다(`Ground` + HUD 루트).
	print("[3] 🔴 그물이 실제로 무언가를 쟀다 (0이면 [2]는 아무것도 안 잰 것)")
	var base_seen := int(_covering.get("res://src/base/base.tscn", 0))
	_check(base_seen >= 1,
		"진입 씬에서 화면 덮는 Control을 %d개 검사했다 (0이면 스캔·판정이 깨져 [2]가 자명 통과다)"
			% base_seen)

	if failures == 0:
		print("TEST_SCENE_CONTRACT_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_SCENE_CONTRACT_FAIL — %d개 실패" % failures)
		quit(1)


## 씬 하나를 **붙여서** 검사한다 — 인스턴스만 하면 `_ready`가 안 돌아 코드가 세우는 값
## (`hud.gd`의 IGNORE)을 못 본다. 붙이는 대가로 씬의 `_ready` 부작용을 감수한다(세이브 뿌리는
## `-s`에서 `user://save_test`로 격리돼 있다 — 세59).
func _audit_scene(path: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		_check(false, "%s를 PackedScene으로 못 읽었다" % path)
		return
	var inst = packed.instantiate()
	if inst == null:
		_check(false, "%s 인스턴스 실패" % path)
		return
	root.add_child(inst)
	await process_frame
	await process_frame            # 레이아웃(앵커→size)이 자리를 잡을 한 프레임 더

	var vp: Vector2 = root.get_visible_rect().size
	var seen := 0
	for c in _controls_of(inst):
		if not c.is_visible_in_tree():
			continue               # 닫힌 모달 — 열렸을 때 클릭을 먹는 건 의도다
		if not _covers_screen(c, vp):
			continue               # 화면을 안 덮는다 = 조준선을 가로막지 않는다
		seen += 1
		_check(c.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"🔴 %s의 %s(%s, %.0f×%.0f)가 화면을 덮는데 mouse_filter=%d — IGNORE(2)가 아니면 좌클릭을 먹어 발사가 조용히 죽는다"
				% [path.get_file(), c.name, c.get_class(), c.size.x, c.size.y, int(c.mouse_filter)])
	_covering[path] = seen
	print("    · %s — 화면 덮는 Control %d개 (뷰포트 %.0f×%.0f)" % [path.get_file(), seen, vp.x, vp.y])
	inst.queue_free()
	# ⚠ 프레임을 넉넉히 흘린다 — 씬의 `_ready`가 `call_deferred`로 깐 것(보스·잡몹 스폰)이
	# 한 프레임 뒤에 붙어, 바로 다음 씬으로 넘어가면 종료 시 leak 경고가 남는다(무해하지만 노이즈다).
	for i in 4:
		await process_frame


## 이 Control이 화면을 덮나 — **두 갈래를 OR로 본다**:
##   ① 실측 크기가 뷰포트보다 크다 (월드 공간 배경 = base·boss_room의 `Ground`)
##   ② **full-rect 앵커** (0,0)~(1,1) = 화면 크기를 따라간다 (HUD 루트·모달 루트)
## ⚠ ②가 필요한 이유: 헤드리스 뷰포트 크기가 실게임과 다르게 잡힐 수 있어(실측 960×960) ①만 쓰면
##   960×540짜리 전면 Control이 조용히 **검사에서 빠진다** — 그 순간 이 그물이 반쯤 죽는다.
func _covers_screen(c: Control, vp: Vector2) -> bool:
	if c.size.x + 0.5 >= vp.x and c.size.y + 0.5 >= vp.y:
		return true
	return is_equal_approx(c.anchor_left, 0.0) and is_equal_approx(c.anchor_top, 0.0) \
		and is_equal_approx(c.anchor_right, 1.0) and is_equal_approx(c.anchor_bottom, 1.0)


## 자손 Control 전부 (인스턴스된 하위 씬 포함 — 그 안의 배경 ColorRect도 같은 함정을 밟는다).
func _controls_of(node: Node) -> Array:
	var out: Array = []
	if node is Control:
		out.append(node)
	for c in node.get_children():
		out.append_array(_controls_of(c))
	return out


## `res://src/`의 `.tscn`을 훑어 **플레이어를 인스턴스하는 씬**만 고른다 (파일 텍스트로 판별 —
## 로드해서 자원 목록을 뒤지는 것보다 싸고, 로드 실패에 안 걸린다). 정렬해 순서를 결정적으로 둔다.
func _gameplay_scenes() -> Array:
	var out: Array = []
	for p in _scan_dir("res://src"):
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			continue
		if f.get_as_text().contains(PLAYER_SCENE):
			out.append(p)
	out.sort()
	return out


func _scan_dir(dir_path: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if d.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_scan_dir(dir_path.path_join(name)))
		elif name.ends_with(".tscn"):
			out.append(dir_path.path_join(name))
		name = d.get_next()
	d.list_dir_end()
	return out


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
