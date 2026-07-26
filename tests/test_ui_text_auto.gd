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
	_test_codex_text_resolver()
	_test_material_progress_single_source()
	_test_quest_row_cap()
	_test_grid_row_cap()
	await _test_say_expires()
	await _test_forge_button_names_from_mode()
	_test_report_summary_fits()
	_test_jin_cell_spec_from_data()

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


## [5] 🔴 장비 효과 문구 = `src/core/item_text.gd` 하나 (감사 #21).
## 옛 사본 셋(tab_panel ×3 · workshop_panel ×2)이 포맷 문자열까지 같아서, 값을 하나 더하면
## 고친 곳만 맞고 나머지는 빈 문자열/"단발"이 됐다.
## 🔴 **사본 재발 감지 스캔** — 두 패널에 옛 함수 정의가 다시 생기면 여기서 빨개진다
## (`test_progression_auto`의 불변식 스캔과 같은 수법. 문구는 갈라져도 에러가 안 나는 종류라 필요하다).
func _test_item_text_single_source() -> void:
	print("[5] 장비 효과 문구 단일 소스 (ItemText) + 사본 재발 감지")
	var it = load("res://src/core/item_text.gd")
	_check(it.effect_text(_db.get_item(&"pen_basic")) == "손그림 보정 +0.15",
		"펜 = 손그림 보정 (실제 %s)" % it.effect_text(_db.get_item(&"pen_basic")))
	# 🔴 세85: 지팡이 문구가 **패턴 말 → 세기·속도 스칼라**로 바뀌었다 (감사 #5 은퇴).
	# ⚠ 배수 값을 박지 않는다 — .tres를 조이면 문구가 따라오되 그게 거짓 빨강이 되진 않게
	# **어떤 축을 적는가**만 잰다. 지팡이 3종 전부 최소 한 축은 적어야 한다(전부 1.0이면 빈 줄 = 그 자체가 버그).
	for wid: StringName in [&"wand_basic", &"wand_fork", &"wand_ring"]:
		var wt: String = it.effect_text(_db.get_item(wid))
		_check(wt != "" and (wt.contains("진 속도") or wt.contains("발사 마나")),
			"%s = 세기·속도 축을 적는다 (실제 %s)" % [wid, wt])
	_check(not it.effect_text(_db.get_item(&"wand_fork")).contains("산탄"),
		"🔴 지팡이가 더는 발사 형태를 말하지 않는다 (형태는 진이 정한다)")
	_check(it.effect_text(_db.get_item(&"robe_basic")).begins_with("HP +"),
		"로브 = HP/마나 (실제 %s)" % it.effect_text(_db.get_item(&"robe_basic")))
	_check(it.effect_text(null) == "", "null = 빈 문자열 (호출부가 줄을 건너뛴다)")
	_check(it.effect_text(_db.get_item(&"ink_basic")) == "", "장비가 아니면 빈 문자열")
	# 🔴 세85: `pattern_label`·`wand_pattern_text`는 **은퇴했다** — 지팡이가 발사 형태를 안 정하면서
	# 라벨의 소비자가 0이 됐다(소비자 0 함수를 남기면 「있는 기능」 행세를 한다 — 감사 T3).
	# 되살아나면 지팡이가 다시 형태를 말한다는 뜻이라 여기서 잡는다.
	var itf = FileAccess.open("res://src/core/item_text.gd", FileAccess.READ)
	var itsrc = itf.get_as_text() if itf != null else ""
	_check(itsrc != "", "item_text.gd 를 읽었다")
	_check(not itsrc.contains("func pattern_label") and not itsrc.contains("func wand_pattern_text"),
		"🔴 은퇴한 패턴 라벨이 안 되살아났다")

	for path in ["res://src/hud/tab_panel.gd", "res://src/base/workshop_panel.gd"]:
		var f = FileAccess.open(path, FileAccess.READ)
		var src = f.get_as_text() if f != null else ""
		_check(src != "", "%s 를 읽었다" % path)
		_check(not src.contains("func _effect_text") and not src.contains("func _wand_pattern_text") \
			and not src.contains("func _pattern_label"),
			"🔴 %s 에 문구 사본이 다시 안 생겼다" % path.get_file())


## [5b] 🔴🔴 codex 해금물 문구 단일 소스 (`CodexText` — 세88 사냥 흐름 S4).
##
## 왜 생겼나: `boss_room`이 **`Db.get_glyph_ring()` 하나만** 불렀다. 챕터 보상이 고리뿐일 때는
## 맞았지만 세88에 보상이 **룬**으로 바뀌자 두 겹으로 틀린 문구가 됐다 —
##   ① `glyph_rings.get()`이 null이라 폴백이 걸려 **원시 id가 화면에 노출**("보상: rune_water")
##   ② 안내가 *"책상에서 밴드에 끼워라"* 고정 → **밴드는 고리 자리인데 룬을 거기 끼우라**는 거짓 지시
## 발신처가 셋(보스 클리어·공방 제작·두루마리 픽업)이라 각자 조회를 복제하면 감사 T5 재발이다.
##
## 🔴 **종류마다 안내가 실제로 갈리는지**가 이 그물의 핵심이다 — 셋이 같은 문구면 리졸버가
## 있으나 마나다(룬=중심 · 진=바탕 · 고리=밴드).
func _test_codex_text_resolver() -> void:
	print("[5b] codex 해금물 이름·안내 단일 소스 (CodexText)")
	var CT = load("res://src/core/codex_text.gd")
	# 세 종류가 각자 자기 카탈로그에서 나온다. ⚠ 룬은 `Db.get_rune(type)`이 **타입 키**라
	# 조회 방향이 다르다 — `Enums.RUNE_TYPES` 순회로 찾는다(값이 연속이 아니라 range 금지).
	var cases := [[&"rune_fire", CT.KIND_RUNE], [&"jin_single", CT.KIND_JIN], [&"gr_radiate5", CT.KIND_RING]]
	for c: Array in cases:
		var uid: StringName = c[0]
		_check(CT.kind_of(uid) == c[1], "%s 종류 == %s (실제 %s)" % [uid, c[1], CT.kind_of(uid)])
		var nm: String = CT.name_of(uid)
		_check(nm != "" and nm != String(uid), "%s 이름이 원시 id 폴백이 아니다 (실제 %s)" % [uid, nm])
		var lbl: String = CT.label_of(uid)
		_check(lbl.contains(nm) and lbl.contains(CT.hint_of(uid)), "%s label = 이름(안내) (실제 %s)" % [uid, lbl])
	# 🔴 안내가 종류마다 **다르다** — 여기가 「거짓 지시」를 막는 자리다.
	var hints := {}
	for k: StringName in [CT.KIND_RUNE, CT.KIND_JIN, CT.KIND_RING]:
		var h: String = CT.hint_for_kind(k)
		_check(h != "", "%s 안내가 있다" % k)
		hints[h] = true
	_check(hints.size() == 3, "종류 셋의 안내가 서로 다르다 (서로 다른 문구 %d개)" % hints.size())
	_check(CT.hint_for_kind(CT.KIND_RUNE).contains("중심"), "룬은 **중심** 자리를 가르친다 (밴드가 아니다)")
	_check(CT.hint_for_kind(CT.KIND_RING).contains("밴드"), "고리는 **밴드** 자리를 가르친다")
	# 🔴 세88 챕터 보상 3종이 전부 리졸버에 걸리나 — 하나라도 새면 그 챕터 클리어 문구가 거짓이 된다.
	for rid: StringName in [&"rune_water", &"rune_wind", &"rune_grass"]:
		_check(CT.kind_of(rid) == CT.KIND_RUNE, "보상 %s를 리졸버가 룬으로 찾는다" % rid)
	# 🔴 **획득물이 아닌 codex 키**도 `codex_unlocked`로 온다 — 문장을 만들면 화면에
	# "chapter_clear_ch1 획득!"이 뜬다. 빈 문자열이 정답이고 호출부가 "" 검사로 넘긴다.
	_check(CT.kind_of(&"chapter_clear_ch1") == &"", "챕터 클리어 키는 획득물이 아니다")
	_check(CT.acquired_line(&"chapter_clear_ch1") == "",
		"획득물 아닌 키엔 획득 문장을 안 만든다 (실제 '%s')" % CT.acquired_line(&"chapter_clear_ch1"))
	_check(CT.acquired_line(&"gr_radiate5") != "", "획득물엔 문장을 만든다")


## [5c] 🔴 재료 진행 표시 `보유/필요` 단일 소스 (`ItemText.count_text` — 세88 §7-F-b).
##
## 공방·정제대가 **글자까지 같은 사본**을 각자 들고 있었고 **둘 다 인자가 거꾸로**였다:
## 주석은 *"재료(보유/필요)"*라고 선언하는데 코드는 `[name, need, have]`라, 5개 필요한데 3개
## 가졌으면 **「슬라임 핵 5/3」**으로 찍혔다(진행 막대 관례와 반대). 공방만 고치면 정제대가
## 계속 거꾸로 남는다 = 감사 T5의 정확한 재현이라 core로 뽑았다.
## 🔴 **스캔형**이라 네 번째 사본이 생기면 그때 빨개진다.
func _test_material_progress_single_source() -> void:
	print("[5c] 재료 진행 `보유/필요` 단일 소스 (ItemText.count_text)")
	var it = load("res://src/core/item_text.gd")
	_check(it.count_text("핵", 3, 5) == "핵 3/5",
		"보유가 먼저다 (실제 %s — '핵 5/3'이면 인자가 거꾸로다)" % it.count_text("핵", 3, 5))
	for path in ["res://src/base/workshop_panel.gd", "res://src/base/refine_panel.gd"]:
		var f = FileAccess.open(path, FileAccess.READ)
		var src = f.get_as_text() if f != null else ""
		_check(src != "", "%s 를 읽었다" % path)
		_check(src.contains("count_text"),
			"🔴 %s 가 ItemText.count_text를 부른다 (자기 포맷을 다시 쓰지 않는다)" % path.get_file())
		_check(not src.contains("%s %d/%d"),
			"🔴 %s 에 진행 표시 사본이 다시 안 생겼다" % path.get_file())


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


## [9] 🔴 세86 B① — **제작대 버튼 이름은 씬이 아니라 모드가 판다.**
## 세85 F5가 화면에서 잡았다: 리포트 [다시] 버튼이 폐지 모드인데 **"다시 그리기"**라고 적혀 있었다
## (씬 `ring_forge_panel.tscn`에 박힌 문구. 코드의 `_redraw_btn`("◀ 다시 조립")과는 **다른 버튼**이라
## 아무도 못 알아챘다). 있지도 않은 조작을 적는 건 그 자체가 버그다(CLAUDE.md).
## 🔴 **두 겹으로 잰다**: ⓐ 라이브 버튼이 지금 모드에 맞는 이름을 달고 있나 ⓑ **씬에 문구 사본이
## 다시 생기지 않았나**(스캔 — [5]의 사본 재발 감지와 같은 수법. 문구는 갈라져도 에러가 안 난다).
func _test_forge_button_names_from_mode() -> void:
	print("[9] 제작대 버튼 이름이 모드에서 파생된다 (씬에 박힌 사본 없음)")
	var RP = load("res://src/core/ring_power.gd")
	var panel = (load("res://src/drawing/ring_forge_panel.tscn") as PackedScene).instantiate()
	root.add_child(panel)
	await process_frame   # _ready → 버튼 이름 주입

	var redo = panel.get_node("Stage/Spread/Report/RedoBtn")
	var shoot = panel.get_node("Stage/Spread/Report/ShootBtn")
	var nxt = panel.get_node("Stage/Spread/NextBtn")
	_check(String(redo.text) != "", "리포트 [다시] 버튼에 이름이 있다 (씬에서 문구를 걷었으니 코드가 채워야 한다)")
	_check(String(shoot.text) != "" and String(nxt.text) != "",
		"[마력 주입]·시작 버튼도 코드가 채운다 (실제 '%s' / '%s')" % [shoot.text, nxt.text])
	# 🔴 심장 — **모드에 없는 조작을 광고하지 않는다.** 이름 문자열을 여기 베끼지 않는다(그러면
	# 테스트가 세 번째 사본이 된다) — 「그리기」라는 말이 있냐 없냐로 잰다.
	if RP.skip_drawing():
		_check(not String(redo.text).contains("그리기"),
			"🔴 폐지 모드 = [다시] 버튼이 '그리기'를 말하지 않는다 (실제 '%s')" % redo.text)
		_check(not String(nxt.text).contains("그리기 시작"),
			"🔴 폐지 모드 = 시작 버튼도 '그리기 시작'이 아니다 (실제 '%s')" % nxt.text)
	else:
		_check(String(redo.text).contains("그리기"),
			"그리기 모드 = [다시 그리기]다 (실제 '%s')" % redo.text)

	var f = FileAccess.open("res://src/drawing/ring_forge_panel.tscn", FileAccess.READ)
	var src = f.get_as_text() if f != null else ""
	_check(src != "", "ring_forge_panel.tscn 을 읽었다")
	for stale in ["다시 그리기", "쏘기 ▶", "맺기 (분석)", "여러 획"]:
		_check(not src.contains(stale),
			"🔴 씬에 문구 사본 '%s'가 다시 안 생겼다 (모드·단계가 파는 문구다)" % stale)
	panel.free()


## [10] 🔴 세86 B② — 리포트 「조립:」 줄이 **카드 폭 안에 든다**(세85 F5: `층 [확산 고리 ×3×3, 폭발 고…`로
## 잘려 뒷부분이 통째로 안 보였다). 층·문양이 늘수록 길어지는 줄이라 조이면 또 넘친다.
## 🔴 값이 아니라 **관계**로 잰다: 나눈 줄이 전부 폭 안이고, 줄 수가 상한 이하고, 넘친 줄은 …로 끝난다.
## 그리고 **2줄 자리가 막대와 안 겹친다**(레이아웃 상수 관계) — 상수를 조이면 여기가 따라온다.
func _test_report_summary_fits() -> void:
	print("[10] 리포트 「조립:」 줄이 카드 폭 안에 든다 (잘림 금지)")
	var fp = load("res://src/drawing/ring_forge_panel.gd")
	var font := ThemeDB.fallback_font
	var w := 292.0 - 28.0     # 리포트 카드 폭 − 좌우 여백 (씬 Report 292px)
	var fs := 10
	var long_text := "조립: 고리 마법진 · 룬 불+번개 · 층 [확산 고리 ×3, 폭발 고리 ×3, 응축 고리 ×5]"
	var lines: PackedStringArray = fp.fit_lines(long_text, font, fs, w, fp.REPORT_SUM_LINES)
	_check(lines.size() >= 2, "긴 줄은 나뉜다 (실제 %d줄)" % lines.size())
	_check(lines.size() <= int(fp.REPORT_SUM_LINES),
		"상한 %d줄을 안 넘는다 (실제 %d줄)" % [int(fp.REPORT_SUM_LINES), lines.size()])
	for ln in lines:
		var lw: float = font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_check(lw <= w, "줄이 폭 안이다 (%.0f <= %.0f) — '%s'" % [lw, w, ln])
	_check(String(lines[0]).begins_with("조립: "), "첫 줄은 머리말로 시작한다 (실제 '%s')" % lines[0])
	# 🔴 검출력: 폭을 아주 좁히면 반드시 …로 끝난다(안 그러면 「말없이 잘림」이 그대로 산다).
	var tight: PackedStringArray = fp.fit_lines(long_text, font, fs, 60.0, fp.REPORT_SUM_LINES)
	_check(String(tight[tight.size() - 1]).ends_with("…"),
		"🔴 다 못 담으면 …로 잘렸음을 알린다 (실제 '%s')" % tight[tight.size() - 1])
	# 짧은 줄은 손대지 않는다 = 무회귀
	var short_lines: PackedStringArray = fp.fit_lines("조립: 고리 마법진", font, fs, w, fp.REPORT_SUM_LINES)
	_check(short_lines.size() == 1 and String(short_lines[0]) == "조립: 고리 마법진",
		"짧은 줄은 한 줄 그대로 (무회귀)")
	# 레이아웃 관계 — 2줄 자리가 종합 막대를 침범하지 않는다.
	_check(float(fp.REPORT_SUM_Y) + float(fp.REPORT_SUM_LINES) * float(fp.REPORT_SUM_LINE_H)
			<= float(fp.REPORT_BAR_Y),
		"🔴 요약 %d줄 자리가 막대(y%.0f) 위에서 끝난다" % [int(fp.REPORT_SUM_LINES), float(fp.REPORT_BAR_Y)])
	_check(float(fp.REPORT_BOX_Y) < float(fp.REPORT_BOX_BOTTOM)
			and float(fp.REPORT_BOX_BOTTOM) <= 292.0,
		"🔴 아래 상자가 리포트 버튼 줄(y292) 위에서 끝난다")


## [11] 🔴 세86 B③ — 책 진 셀 설명이 **JinDef에서 파생**된다(`band_count`·`rune_slots`).
## 세85 ⑦에 `glyph_slots`(진이 문양 칸을 연다) 축이 은퇴하면서 그 축을 말하던 옛 문구가
## **거짓말**이 됐다(세85 F5가 진 탭에서 눈으로 잡았다 — 감사 T4 「주석·문구가 코드와 같이 안 늙는다」).
## ⚠ 아래 스캔 문자열을 이 주석에 그대로 적지 마라 — **이 파일이 자기 스캔에 걸린다**(실제로 밟았다).
## 새 문장을 또 베껴 적으면 다음 축 변경 때 같은 일이 난다 → **숫자를 데이터에서 뽑는지**를 잰다.
func _test_jin_cell_spec_from_data() -> void:
	print("[11] 진 셀 설명이 데이터에서 파생된다 (은퇴한 「열리는 칸」 재발 감지)")
	var book = load("res://src/drawing/ring_book.gd")
	_check(String(book.jin_spec_text(1, 1)) == "층 1겹",
		"자리 1개면 층 수만 (실제 '%s')" % book.jin_spec_text(1, 1))
	_check(String(book.jin_spec_text(2, 1)) == "층 2겹",
		"층 수가 그대로 따라온다 (실제 '%s')" % book.jin_spec_text(2, 1))
	var fuse: String = book.jin_spec_text(2, 2)
	_check(fuse.contains("2겹") and fuse.contains("룬 자리 2"),
		"🔴 융합진은 룬 자리도 적는다 (실제 '%s')" % fuse)
	_check(not String(book.jin_spec_text(1, 1)).contains("룬 자리"),
		"자리 1개엔 룬 자리를 안 적는다 (정보량 0인 노이즈 제거)")
	# 🔴 셀 아래 한 줄이 **스펙 + 설명**으로 조립되나 — 스펙이 빠지면 셀은 다시 "발사 형태가 있다"만
	# 말하고 진의 개성(층·룬 자리)은 화면 어디에도 안 남는다.
	var line1: String = book.jin_desc_line(&"jin_single", 1, 1)
	_check(line1.begins_with(String(book.jin_spec_text(1, 1))),
		"🔴 셀 설명이 파생 스펙으로 시작한다 (실제 '%s')" % line1)
	_check(line1.contains("—") and line1.length() > String(book.jin_spec_text(1, 1)).length() + 2,
		"스펙 뒤에 설명이 붙는다 (실제 '%s')" % line1)
	_check(book.jin_desc_line(&"jin_no_such_id", 3, 2).contains("층 3겹"),
		"모르는 진도 스펙은 나온다 (폴백이 크래시가 아니다)")
	# 🔴 실제 진 데이터로도 맞나 — Db의 진 하나를 그대로 넣어 본다(수치를 박지 않는다).
	var jins: Array = _db.all_jins()
	_check(not jins.is_empty(), "Db에 진이 있다 (%d종)" % jins.size())
	if not jins.is_empty():
		var jd = jins[0]
		var spec: String = book.jin_spec_text(int(jd.band_count), maxi(int(jd.rune_slots), 1))
		_check(spec.contains("%d겹" % int(jd.band_count)),
			"🔴 %s의 층 수(%d)가 그대로 나온다 (실제 '%s')" % [jd.id, int(jd.band_count), spec])
	var f = FileAccess.open("res://src/drawing/ring_book.gd", FileAccess.READ)
	var src = f.get_as_text() if f != null else ""
	_check(src != "", "ring_book.gd 를 읽었다")
	_check(not src.contains("열리는 칸이 진마다"),
		"🔴 은퇴한 「열리는 칸」 문구가 안 되살아났다 (glyph_slots 축은 세85 ⑦에 은퇴)")


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
