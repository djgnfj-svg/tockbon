extends SceneTree
## 모듈 D 자동 검증 — 정제·종이·수리·응급 수리·연구 (TEAM_PLAN 모듈 D DoD).
## 실행: Godot --headless --path . -s res://tests/test_base_auto.gd
## 주의: -s 스크립트는 오토로드 전역 등록 전에 컴파일되므로,
## 오토로드는 root.get_node()로, 모듈 스크립트는 첫 프레임에 load()로 얻는다.

var _fails: int = 0

# 오토로드 (첫 프레임에 바인딩)
var gs: Node      # GameState
var eb: Node      # EventBus
var clk: Node     # Clock
var db: Node      # Db

# 모듈 D 스크립트 (지연 로드)
var WorkbenchService: GDScript
var ResearchService: GDScript

func _init() -> void:
	# 오토로드 _ready 이후에 실행되도록 첫 프레임까지 대기
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		_fails += 1
		print("FAIL: ", label)

func _run() -> void:
	gs = root.get_node(^"GameState")
	eb = root.get_node(^"EventBus")
	clk = root.get_node(^"Clock")
	db = root.get_node(^"Db")
	WorkbenchService = load("res://src/base/workbench_service.gd")
	ResearchService = load("res://src/base/research_service.gd")
	_test_items_loaded()
	_test_refine()
	_test_paper()
	_test_repair()
	_test_emergency_repair()
	_test_research()
	await _test_scene_loads()
	if _fails == 0:
		print("TEST_BASE_OK")
	else:
		print("TEST_BASE_FAILED: ", _fails)
	quit(mini(_fails, 125))

# ── data/items 로드 (Db 레지스트리 경유)

func _test_items_loaded() -> void:
	var ids: Array[StringName] = [
		&"ink_basic", &"ink_mid", &"ink_high",
		&"paper_1", &"paper_2", &"paper_3",
		&"fragment_water", &"fragment_wind",
		&"mat_vine", &"mat_hound_fang", &"mat_slime_core",
		&"mat_mist_essence", &"mat_beetle_shell", &"mat_night_bloom", &"mat_moon_sap",
		&"wand_basic", &"robe_basic", &"charm_basic",
	]
	var all_ok := true
	for item_id: StringName in ids:
		var def: ItemDef = db.get_item(item_id)
		if def == null or def.display_name.is_empty():
			all_ok = false
			print("  누락/불량 아이템: ", item_id)
	_check(all_ok, "아이템 .tres 18종 로드·한글 이름")
	_check(db.get_item(&"ink_basic") != null and db.get_item(&"ink_basic").kind == Enums.ItemKind.INK, "ink_basic kind=INK")
	_check(db.get_item(&"paper_2") != null and int(db.get_item(&"paper_2").params.get("ink_capacity", 0)) > 0, "paper_2 params.ink_capacity 존재")
	_check(db.get_item(&"fragment_water") != null and db.get_item(&"fragment_water").kind == Enums.ItemKind.FRAGMENT, "fragment_water kind=FRAGMENT")

# ── 정제: 재료 주입 → 레시피 실행 → 잉크 증가

func _test_refine() -> void:
	var wb: RefCounted = WorkbenchService.new()
	gs.add_item(&"mat_vine", 3)
	var ink_before: int = gs.get_count(&"ink_basic")
	_check(wb.refine(&"refine_ink_basic_vine"), "정제 실행 (mat_vine×3)")
	_check(gs.get_count(&"ink_basic") == ink_before + 2, "잉크 +2")
	_check(gs.get_count(&"mat_vine") == 0, "재료 전량 소모")
	_check(not wb.refine(&"refine_ink_basic_vine"), "재료 부족 시 정제 실패")

# ── 종이 제작: 해금 게이트 확인

func _test_paper() -> void:
	var wb: RefCounted = WorkbenchService.new()
	gs.add_item(&"mat_vine", 2)
	gs.add_item(&"mat_beetle_shell", 1)
	_check(wb.craft_paper(&"craft_paper_1"), "기본 종이 제작 (해금 불필요)")
	_check(gs.get_count(&"paper_1") >= 2, "paper_1 ×2 획득")
	gs.add_item(&"mat_beetle_shell", 2)
	gs.add_item(&"mat_night_bloom", 1)
	_check(not wb.craft_paper(&"craft_paper_2"), "미해금 recipe_paper_2 제작 차단")
	eb.research_completed.emit(&"recipe_paper_2")  # GameState가 codex에 등록하는 배선 검증
	_check(gs.is_unlocked(&"recipe_paper_2"), "research_completed → codex 등록")
	_check(wb.craft_paper(&"craft_paper_2"), "해금 후 중급 종이 제작")
	_check(gs.get_count(&"paper_2") == 1, "paper_2 ×1 획득")

# ── 수리: 손상 샘플 도안 → 내구 회복·잉크 차감

func _test_repair() -> void:
	var wb: RefCounted = WorkbenchService.new()
	var design := SampleDesigns.nova_fire()  # ink_cost {ink_basic: 12}
	design.durability = 5
	gs.add_item(&"ink_basic", 10)
	var expected_cost := ceili(12.0 * gs.balance.repair_cost_frac)
	var ink_before: int = gs.get_count(&"ink_basic")
	var repaired: Array[SpellDesign] = []
	eb.design_repaired.connect(func(d: SpellDesign) -> void: repaired.append(d))
	_check(wb.repair(design), "수리 실행")
	_check(design.durability == design.durability_max, "내구 완전 회복")
	_check(gs.get_count(&"ink_basic") == ink_before - expected_cost,
			"수리비 차감 (ink_basic ×%d)" % expected_cost)
	_check(repaired.size() == 1 and repaired[0] == design, "design_repaired 발신")
	_check(not wb.repair(design), "만내구 도안 수리 차단")

# ── 응급 수리: 비용 절반, 내구 30% 상한

func _test_emergency_repair() -> void:
	var wb: RefCounted = WorkbenchService.new()
	var design := SampleDesigns.nova_fire()
	design.durability = 0  # 파손 상태
	gs.add_item(&"ink_basic", 10)
	var cap := ceili(float(design.durability_max) * gs.balance.emergency_durability_frac)
	var expected_cost := ceili(12.0 * gs.balance.repair_cost_frac * gs.balance.emergency_repair_cost_mult)
	var ink_before: int = gs.get_count(&"ink_basic")
	_check(wb.emergency_repair(design), "응급 수리 실행")
	_check(design.durability == cap, "응급 수리 30%% 상한 (내구 %d)" % cap)
	_check(gs.get_count(&"ink_basic") == ink_before - expected_cost,
			"응급 수리비 절반 (ink_basic ×%d)" % expected_cost)
	_check(not wb.emergency_repair(design), "상한 도달 후 응급 수리 차단")
	_check(wb.can_repair(design), "응급 후 완전 수리는 여전히 가능")

# ── 연구: 창고 조각 소모 → 시간 스킵 → research_completed·codex

func _test_research() -> void:
	var rs: RefCounted = ResearchService.new()
	gs.add_item(&"fragment_water", 1)
	gs.add_item(&"fragment_wind", 1)
	var received: Array[StringName] = []
	eb.research_completed.connect(func(unlock_id: StringName) -> void: received.append(unlock_id))
	_check(rs.start(&"rune_water"), "연구 시작 (fragment_water)")
	_check(gs.get_count(&"fragment_water") == 0, "조각이 창고에서 소모됨")
	_check(not rs.start(&"rune_wind"), "동시 연구 1개 제한")
	_check(not rs.poll(), "시간 경과 전 미완료")
	clk.time_sec += gs.balance.research_time_sec + 1.0  # 게임 시간 스킵
	_check(rs.poll(), "시간 스킵 후 완료")
	_check(received.has(&"rune_water"), "research_completed(rune_water) 수신")
	_check(gs.is_unlocked(&"rune_water"), "GameState.codex 등록")
	_check(not rs.can_start(&"rune_water"), "이미 해금된 연구 재시작 차단")
	_check(not rs.is_researching(), "완료 후 연구 슬롯 비움")

# ── 거점 씬 스모크: 인스턴스 생성·1프레임 진행

func _test_scene_loads() -> void:
	var packed := load("res://src/base/base.tscn") as PackedScene
	_check(packed != null, "base.tscn 로드")
	if packed == null:
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	_check(is_instance_valid(scene), "base.tscn 인스턴스 정상 (_ready·_process 1프레임)")
	# 패널 열기 = refresh() 실행 — 행 구성·Db 조회·정렬 경로 검증
	var design := SampleDesigns.aimed_shotgun_impact()
	design.durability = 2
	gs.designs.append(design)
	for facility_id: StringName in [&"workbench", &"storage", &"lab"]:
		scene._open(facility_id)
		await process_frame
		_check(scene._any_panel_open(), "패널 열림·refresh 정상: %s" % facility_id)
	scene._close_all()
	gs.designs.erase(design)
	scene.queue_free()
