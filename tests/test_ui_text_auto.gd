extends SceneTree
## UI 문구·표시 계약 자동 검증 (세84 감사 #12·#21·#35·#36) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ui_text_auto.gd
## 전 항목 통과 시 "TEST_UI_TEXT_OK" 출력 후 종료 코드 0.
##
## 🔴 **왜 이 그물이 필요한가**: 세84 감사가 잡은 넷은 전부 **표시부**인데, 이 프로젝트의 반복
## 실패가 정확히 여기다 — *"축이 1→N으로 늘 때마다 표시부가 뒤처지고, 헤드리스는 렌더를 못 봐
## F5까지 안 드러난다"*(감사 T8). 그래서 **렌더가 아니라 순수 함수·레이아웃 계약**만 잰다:
##   [1~4] #12 융합진 두 번째 룬 — 수식 씨앗·색·자리 좌표가 `runes_of`/`rune_slot_positions`를 거치나
##   [5]   #21 장비 효과 문구 단일 소스(`src/core/item_text.gd`) + **사본 재발 감지 스캔**
##   [6~7] #35 퀘스트 탭·소지품 격자 행 캡 (패널 아랫변을 안 넘나 · 안 그린 카드가 클릭 목록에 없나)
##   [8]   #36 `say()` 수명 (전엔 만료가 아예 없어 거짓 경고가 씬 끝까지 상주했다)
##
## 🔴 헤드리스가 **못 잡는 것**(사용자 F5): 룬 점 2개가 실제로 **보이나**·겹치지 않나 ·
##   색 띠 두 토막이 읽히나 · "… 외 N개/N종" 줄이 잘리지 않고 뜨나 · 안내문 페이드가 자연스러운가.
##   `_draw`는 렌더가 없으면 안 불린다 — 여기서 재는 건 **좌표·문자열·상태**뿐이다.
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

var failures: int = 0
var _tab_script = null
var _tab = null
var _hud = null
var _db = null
var _gs = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(20.0).timeout.connect(func() -> void:
		print("TEST_UI_TEXT_TIMEOUT — 20초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_db = root.get_node("/root/Db")
	_gs = root.get_node("/root/GameState")
	_tab_script = load("res://src/hud/tab_panel.gd")
	_tab = Control.new()
	_tab.set_script(_tab_script)
	_tab.size = Vector2(960.0, 540.0)
	root.add_child(_tab)
	_hud = Control.new()
	_hud.set_script(load("res://src/hud/hud.gd"))
	root.add_child(_hud)
	await process_frame  # _ready → EventBus 구독

	_test_rune_seed()
	_test_formula_carries_both_runes()
	_test_display_goes_through_runes_of()
	_test_rune_slot_positions_single_source()
	_test_item_text_single_source()
	_test_quest_row_cap()
	_test_grid_row_cap()
	await _test_say_expires()

	_hud.free()
	_tab.free()

	if failures == 0:
		print("TEST_UI_TEXT_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_UI_TEXT_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 🔴 수식 씨앗이 룬 목록을 잇는다 — 융합진(룬 2개)이 `물+번개`로 보여야 한다.
## 자리 1개면 이름 하나 = 옛 수식과 글자 하나까지 같다(무회귀).
func _test_rune_seed() -> void:
	print("[1] rune_seed — 융합진 씨앗이 두 룬을 잇는다")
	_check(_tab_script.rune_seed([2]) == "물", "룬 1개 = 이름 하나 (무회귀)")
	_check(_tab_script.rune_seed([2, 4]) == "물+번개",
		"룬 2개 = 물+번개 (실제 %s)" % _tab_script.rune_seed([2, 4]))
	_check(_tab_script.rune_seed([4, 2]) == "번개+물", "자리 순서를 지킨다")
	_check(_tab_script.rune_seed([]) == "룬", "빈 목록 폴백")
	_check(_tab_script.rune_seed([99]) == "룬", "Db 밖 값도 뭔가 읽힌다")


## [2] 🔴 씨앗이 수식에 실린다 — `발산(물+번개)`. 옛 코드는 `발산(물)`이라 두 번째 룬이 사라졌다.
func _test_formula_carries_both_runes() -> void:
	print("[2] spell_formula에 융합 씨앗이 실린다")
	var summary := [[{"code": 1, "count": 3}]]
	var f = _tab_script.spell_formula(summary, _tab_script.rune_seed([2, 4]))
	_check(f == "발산(물+번개)", "수식이 두 룬을 보여 준다 (실제 %s)" % f)


## [3] 🔴🔴 **심장 — 표시부가 `design.rune`(첫 룬)만 읽지 않는다.**
## `ring_design.gd`가 *"읽을 땐 `runes_of()`를 거쳐라"*라고 못 박았는데 표시부 셋이 우회했다
## → 발사는 두 룬을 쏘고 화면은 하나만 보여 주는 「쏘는 것 ≠ 보이는 것」(감사 #12).
## 옛 도안(룬 1개·`runes` 없음)이 색 하나로 그대로 도는지도 같이 잰다 = 픽셀 무회귀의 증명.
func _test_display_goes_through_runes_of() -> void:
	print("[3] 표시부가 runes_of를 거친다 (융합진 두 번째 룬)")
	var d = RingDesign.from_assembly({
		"rune": 2, "runes": [2, 4], "jin": &"jin_fuse",
		"rings": [[1, 1, 1, -1, -1, -1, -1, -1]],
		"open": [0, 1, 2, 3, 4, 5, 6, 7], "score": 0.8,
	})
	var runes = _tab.call(&"_design_runes", d)
	_check(runes == [2, 4], "도안에서 룬 2개를 읽는다 (실제 %s)" % str(runes))
	var cols = _tab.call(&"_rune_colors", d)
	_check(cols.size() == 2, "색도 자리마다 (실제 %d개)" % cols.size())
	_check(cols.size() == 2 and cols[0] != cols[1],
		"물·번개 색이 다르다 — 두 슬롯이 손끝에서 구분된다 (실제 %s)" % str(cols))

	var old_d = RingDesign.from_assembly({
		"rune": 0, "rings": [1, -1, -1, -1, -1, -1, -1, -1], "open": [0], "score": 0.7,
	})
	_check(_tab.call(&"_design_runes", old_d) == [0], "옛 도안은 [rune]로 승격 (무회귀)")
	_check(_tab.call(&"_rune_colors", old_d).size() == 1, "옛 도안은 색 하나 = 옛 그림 그대로")


## [4] 🔴 룬 자리 좌표는 `RingBoard.rune_slot_positions` **단일 소스**다 — HUD·Tab·판·책 셀이
## 같은 함수를 부른다. 각도를 베끼면 규약이 바뀔 때 넷이 조용히 어긋난다(세60·세81 규율).
## ⚠ HUD/Tab이 **실제로 그 함수를 부르는지**는 렌더라 헤드리스가 못 잰다 — 여기선 계약 값만 고정한다.
func _test_rune_slot_positions_single_source() -> void:
	print("[4] 룬 자리 좌표 계약 (rune_slot_positions)")
	var board = load("res://src/drawing/ring_board.gd")
	var pos = board.rune_slot_positions(2, Vector2(100.0, 50.0), 16.0)
	var dx: float = 16.0 * float(board.RUNE_SPLIT_FRAC)
	_check(pos.size() == 2, "자리 2개 (실제 %d개)" % pos.size())
	_check(pos.size() == 2 and is_equal_approx(pos[0].x, 100.0 - dx) \
		and is_equal_approx(pos[1].x, 100.0 + dx),
		"중심 ± ro*RUNE_SPLIT_FRAC 좌우 배치 (실제 %s)" % str(pos))
	_check(board.rune_slot_positions(1, Vector2(7.0, 9.0), 16.0)[0] == Vector2(7.0, 9.0),
		"자리 1개 = 중심 (룬 1개 무회귀의 보장 경로)")


## [5] 🔴 장비 효과 문구·발사 패턴 라벨 = `src/core/item_text.gd` 하나 (감사 #21).
## 옛 사본 셋(tab_panel ×3 · workshop_panel ×2)이 포맷 문자열까지 같아서, 값을 하나 더하면
## 고친 곳만 맞고 나머지는 빈 문자열/"단발"이 됐다.
## 🔴 **사본 재발 감지 스캔** — 두 패널에 옛 함수 정의가 다시 생기면 여기서 빨개진다
## (`test_progression_auto`의 불변식 스캔과 같은 수법. 문구는 갈라져도 에러가 안 나는 종류라 필요하다).
func _test_item_text_single_source() -> void:
	print("[5] 장비 효과 문구 단일 소스 (ItemText) + 사본 재발 감지")
	var it = load("res://src/core/item_text.gd")
	_check(it.effect_text(_db.get_item(&"pen_basic")) == "손그림 보정 +0.15",
		"펜 = 손그림 보정 (실제 %s)" % it.effect_text(_db.get_item(&"pen_basic")))
	_check(it.effect_text(_db.get_item(&"wand_fork")) == "산탄 (여러 발)",
		"지팡이 = 패턴 말 (실제 %s)" % it.effect_text(_db.get_item(&"wand_fork")))
	_check(it.effect_text(_db.get_item(&"robe_basic")).begins_with("HP +"),
		"로브 = HP/마나 (실제 %s)" % it.effect_text(_db.get_item(&"robe_basic")))
	_check(it.effect_text(null) == "", "null = 빈 문자열 (호출부가 줄을 건너뛴다)")
	_check(it.effect_text(_db.get_item(&"ink_basic")) == "", "장비가 아니면 빈 문자열")
	_check(it.pattern_label(0) == "단발" and it.pattern_label(1) == "산탄 (여러 발)" \
		and it.pattern_label(2) == "전방위" and it.pattern_label(5) == "단발",
		"패턴 라벨 4갈래 (미구현 값은 단발 폴백)")

	for path in ["res://src/hud/tab_panel.gd", "res://src/base/workshop_panel.gd"]:
		var f = FileAccess.open(path, FileAccess.READ)
		var src = f.get_as_text() if f != null else ""
		_check(src != "", "%s 를 읽었다" % path)
		_check(not src.contains("func _effect_text") and not src.contains("func _wand_pattern_text") \
			and not src.contains("func _pattern_label"),
			"🔴 %s 에 문구 사본이 다시 안 생겼다" % path.get_file())


## [6] 🔴 퀘스트 탭 행 캡 (감사 #35) — q00~q05 여섯이 길잡이 대화 한 번에 연쇄 완료되면 6행이
## 되고, 캡이 없으면 6번째 행이 패널 아랫변을 뚫고 진행 바가 화면(540) 밖으로 나간다(스크롤 없음).
## 값이 아니라 **관계**로 잰다 — PANEL_SIZE·ROW_H를 조이면 기대치가 따라와야 한다.
func _test_quest_row_cap() -> void:
	print("[6] 퀘스트 탭 행 캡 — 6행이 화면 밖으로 안 나간다")
	var row := float(_tab_script.ROW_H) + float(_tab_script.ROW_GAP)
	var avail := float(_tab_script.PANEL_SIZE.y) - float(_tab_script.CONTENT_TOP) \
		- float(_tab_script.PAD)
	var cap: int = _tab_script.quest_rows_shown(99, avail)
	_check(cap >= 1, "적어도 한 행은 그린다 (실제 %d행)" % cap)
	_check(float(cap) * row + float(_tab_script.QUEST_FOLD_H) <= avail,
		"캡 행 + 접힘 줄이 내용 높이 안이다 (%.0f <= %.0f)" % [float(cap) * row \
			+ float(_tab_script.QUEST_FOLD_H), avail])
	_check(float(cap + 1) * row - float(_tab_script.ROW_GAP) > avail,
		"🔴 캡이 실제 한계다 — 한 행 더 그리면 넘친다 (검출력: 캡을 늘리면 여기가 빨개진다)")
	_check(_tab_script.quest_rows_shown(cap + 1, avail) == cap,
		"넘치는 만큼은 접는다 (실제 %d행)" % int(_tab_script.quest_rows_shown(cap + 1, avail)))
	_check(_tab_script.quest_rows_shown(cap, avail) == cap, "안 넘치면 전부 그린다 (무회귀)")
	_check(_tab_script.quest_rows_shown(1, avail) == 1, "한 개면 한 개")


## [7] 🔴 소지품 격자 행 캡 (감사 #35) — 이 함수가 **클릭 rect의 단일 소스**라, 안 그린 카드를
## 목록에 남기면 화면 밖 카드가 클릭으로 착용되는 유령 판정이 생긴다(그린 곳 = 누른 곳 규율).
## 🔴 구역째 버리지 않는지도 잰다 — 통째로 버리면 아이템이 많을 때 "… 외 N종" 한 줄만 남고
## 화면이 텅 빈다(실측했다. 잘림보다 나쁘다).
func _test_grid_row_cap() -> void:
	print("[7] 소지품 격자 행 캡 — 패널 밖 카드를 안 만든다")
	var ids := []
	for i in 60:
		var id := StringName("uitext_probe_%d" % i)
		ids.append(id)
		_gs.add_item(id, 1)
	var layout = _tab.call(&"_grid_sections")
	_check(layout.has("hidden") and layout.has("fold_y"), "hidden·fold_y를 돌려준다")
	var o: Vector2 = ((Vector2(960.0, 540.0) - _tab_script.PANEL_SIZE) * 0.5).round()
	var bottom: float = o.y + float(_tab_script.PANEL_SIZE.y) - float(_tab_script.PAD)
	var worst := 0.0
	var cards := 0
	for sec in layout["sections"]:
		worst = maxf(worst, float(sec["next_y"]))
		cards += sec["cards"].size()
	_check(worst <= bottom,
		"그린 구역이 패널 아랫변을 안 넘는다 (%.0f <= %.0f)" % [worst, bottom])
	_check(int(layout["hidden"]) > 0,
		"60종을 넣으면 접힌다 (hidden=%d)" % int(layout["hidden"]))
	_check(cards > 0, "🔴 구역째 버리지 않는다 — 들어가는 줄까지는 그린다 (cards=%d)" % cards)
	_check(cards + int(layout["hidden"]) >= 60,
		"센 종 수 = 그린 것 + 접힌 것 (cards=%d hidden=%d)" % [cards, int(layout["hidden"])])
	_check(float(layout["fold_y"]) + 12.0 < o.y + float(_tab_script.PANEL_SIZE.y),
		"접힘 줄도 패널 안이다 (%.0f)" % (float(layout["fold_y"]) + 12.0))

	for id in ids:
		_gs.remove_item(id, 1)
	var after = _tab.call(&"_grid_sections")
	_check(int(after["hidden"]) == 0, "뒷정리: 프로브를 걷으면 접힘이 없다")


## [8] 🔴 안내문 수명 (감사 #36) — 옛 `say()`는 대입만 하고 타이머·비우기 호출자가 하나도 없어
## "마나가 부족하다" 한 번이 보스방 목표 줄을 덮고 **씬이 끝날 때까지 상주했다**.
## 같은 파일 토스트는 `TOAST_LIFE`+감쇠를 갖고 있었다 = 두 채널 규약이 갈라져 있었다.
## sticky는 남는다 — 보스방 목표·클리어 안내처럼 상주가 필요한 문구용 명시 분기다.
func _test_say_expires() -> void:
	print("[8] say() 수명 — 순간 경고는 만료되고 sticky는 남는다")
	_hud.say("마나가 부족하다", true)
	_check(_hud.say_line() == "마나가 부족하다", "안내문이 떴다")
	_hud._process(float(_hud.SAY_LIFE) + 0.1)
	_check(_hud.say_line() == "", "🔴 수명 뒤엔 사라진다 (실제 '%s')" % _hud.say_line())

	_hud.say("보스를 쓰러뜨려라", false, true)
	_hud._process(float(_hud.SAY_LIFE) * 3.0)
	_check(_hud.say_line() == "보스를 쓰러뜨려라", "sticky는 안 사라진다 (목표 줄)")
	_hud.say("")
	_check(_hud.say_line() == "", "빈 문자열은 즉시 지운다")
	await process_frame


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
