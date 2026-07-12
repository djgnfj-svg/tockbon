extends SceneTree
## 장비 착용·효과 자동 검증 — 착용/해제·창고 차감/반환·파생 스탯·gear_param·클램프 (NEXT_CYCLE §1 DoD).
## 실행: Godot --headless --path . -s res://tests/test_equip_auto.gd
## 주의: -s 스크립트는 오토로드 전역 등록 전에 컴파일되므로,
## 오토로드는 root.get_node()로, 모듈 스크립트는 첫 프레임에 load()로 얻는다.

var _fails: int = 0
var _equip_signals: int = 0

# 오토로드 (첫 프레임에 바인딩)
var gs: Node      # GameState
var eb: Node      # EventBus
var db: Node      # Db

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
	db = root.get_node(^"Db")
	eb.equipment_changed.connect(func() -> void: _equip_signals += 1)
	_test_equip_stats_and_storage()
	_test_swap_returns_previous()
	_test_invalid_equips()
	_test_gear_params()
	_test_unequip_clamp_and_death()
	await _test_storage_panel()
	if _fails == 0:
		print("TEST_EQUIP_OK")
	else:
		print("TEST_EQUIP_FAILED: ", _fails)
	quit(mini(_fails, 125))

# ── 착용 → 파생 스탯 증가·창고 차감 / 해제 → 반환·원복
# 기대 수치는 코드에 박지 않고 data/items/*.tres params에서 읽는다

func _test_equip_stats_and_storage() -> void:
	var robe: ItemDef = db.get_item(&"robe_basic")
	_check(robe != null and float(robe.params.get("mana_max_add", 0.0)) > 0.0,
			"robe_basic params.mana_max_add > 0")
	var mana_add := float(robe.params.get("mana_max_add", 0.0))
	var hp_add := float(robe.params.get("hp_max_add", 0.0))
	var base_mana: float = gs.mana_max()
	var base_hp: float = gs.hp_max()
	var signals_before := _equip_signals
	gs.add_item(&"robe_basic", 1)
	_check(gs.equip_gear(&"robe_basic"), "로브 착용 성공")
	_check(_equip_signals == signals_before + 1, "착용 시 equipment_changed 발신")
	_check(gs.get_count(&"robe_basic") == 0, "착용 시 창고 1개 차감")
	_check(is_equal_approx(gs.mana_max(), base_mana + mana_add), "착용 → mana_max 증가")
	_check(is_equal_approx(gs.hp_max(), base_hp + hp_add), "착용 → hp_max 증가")
	gs.unequip_gear(Enums.ItemKind.ROBE)
	_check(_equip_signals == signals_before + 2, "해제 시 equipment_changed 발신")
	_check(gs.get_count(&"robe_basic") == 1, "해제 시 창고 반환")
	_check(is_equal_approx(gs.mana_max(), base_mana), "해제 → mana_max 원복")
	_check(not gs.equipment.has(Enums.ItemKind.ROBE), "해제 후 부위 비움")

# ── 교체 시 기존 착용품 창고 반환 (동일 id 교체 — 차감 1 + 반환 1 = 수량 유지)

func _test_swap_returns_previous() -> void:
	gs.add_item(&"wand_basic", 1)
	_check(gs.equip_gear(&"wand_basic"), "완드 착용")
	_check(gs.get_count(&"wand_basic") == 0, "착용 후 창고 0")
	gs.add_item(&"wand_basic", 1)
	_check(gs.equip_gear(&"wand_basic"), "완드 교체 착용")
	_check(gs.get_count(&"wand_basic") == 1, "교체 시 기존 착용품 창고 반환")
	_check(gs.equipment.get(Enums.ItemKind.WAND) == &"wand_basic", "교체 후 착용 유지")

# ── 착용 실패 케이스

func _test_invalid_equips() -> void:
	_check(gs.get_count(&"charm_basic") == 0 and not gs.equip_gear(&"charm_basic"),
			"창고에 없는 장비 착용 실패")
	_check(not gs.equipment.has(Enums.ItemKind.CHARM), "실패 시 부위 변화 없음")
	gs.add_item(&"ink_basic", 1)
	_check(not gs.equip_gear(&"ink_basic"), "장비 아닌 kind(INK) 착용 실패")
	_check(gs.get_count(&"ink_basic") == 1, "실패 시 창고 차감 없음")
	_check(not gs.equip_gear(&"no_such_item"), "미등록 아이템 착용 실패")

# ── 완드·부적 params가 gear_param으로 읽힘 (기대값은 .tres에서)

func _test_gear_params() -> void:
	var wand: ItemDef = db.get_item(&"wand_basic")
	var acm := float(wand.params.get("attack_cooldown_mult", 1.0))
	var dmg_add := float(wand.params.get("wand_damage_add", 0.0))
	_check(acm < 1.0 and dmg_add > 0.0, "wand_basic params 유효 (연사·피해)")
	_check(is_equal_approx(gs.gear_param(Enums.ItemKind.WAND, "attack_cooldown_mult", 1.0), acm),
			"gear_param 완드 attack_cooldown_mult")
	_check(is_equal_approx(gs.gear_param(Enums.ItemKind.WAND, "wand_damage_add", 0.0), dmg_add),
			"gear_param 완드 wand_damage_add")
	_check(is_equal_approx(gs.gear_param(Enums.ItemKind.CHARM, "dash_cooldown_mult", 1.0), 1.0),
			"미착용 부위는 default 반환")
	var charm: ItemDef = db.get_item(&"charm_basic")
	var dcm := float(charm.params.get("dash_cooldown_mult", 1.0))
	gs.add_item(&"charm_basic", 1)
	_check(gs.equip_gear(&"charm_basic"), "부적 착용")
	_check(is_equal_approx(gs.gear_param(Enums.ItemKind.CHARM, "dash_cooldown_mult", 1.0), dcm),
			"gear_param 부적 dash_cooldown_mult")

# ── 로브 해제 시 hp·mana 새 상한으로 클램프 + 착용품은 사망(bag_lost)에도 보존

func _test_unequip_clamp_and_death() -> void:
	_check(gs.equip_gear(&"robe_basic"), "클램프 검증용 로브 재착용")
	gs.hp = gs.hp_max()
	gs.mana = gs.mana_max()
	var boosted_hp_max: float = gs.hp_max()
	gs.unequip_gear(Enums.ItemKind.ROBE)
	_check(gs.hp_max() < boosted_hp_max, "해제 → hp_max 감소")
	_check(is_equal_approx(gs.hp, gs.hp_max()), "해제 시 hp 새 상한 클램프")
	_check(is_equal_approx(gs.mana, gs.mana_max()), "해제 시 mana 새 상한 클램프")
	gs.add_to_bag(&"mat_vine", 1)
	eb.bag_lost.emit()
	_check(gs.bag.is_empty(), "bag_lost → 가방 손실")
	_check(gs.equipment.has(Enums.ItemKind.WAND) and gs.equipment.has(Enums.ItemKind.CHARM),
			"착용 장비는 사망에도 보존")

# ── 창고 패널 스모크 — 착용/해제 버튼 표시·동작 (진입 상태: WAND·CHARM 착용, 창고에 wand·robe)

func _test_storage_panel() -> void:
	var panel_script: GDScript = load("res://src/base/storage_panel.gd")
	var panel: PanelContainer = panel_script.new()
	root.add_child(panel)
	panel.refresh()
	await process_frame
	_check(is_instance_valid(panel), "storage_panel refresh 정상")
	_check(_find_buttons(panel, "해제").size() == 2, "착용 중 2부위 해제 버튼 표시")
	_check(_find_buttons(panel, "착용").size() == 2, "창고 장비 2종 착용 버튼 표시")
	var wand_before: int = gs.get_count(&"wand_basic")
	# GEAR_KINDS 순서상 첫 해제 버튼 = 완드
	_find_buttons(panel, "해제")[0].pressed.emit()
	_check(not gs.equipment.has(Enums.ItemKind.WAND), "해제 버튼 → 완드 해제")
	_check(gs.get_count(&"wand_basic") == wand_before + 1, "해제 버튼 → 창고 반환")
	await process_frame  # equipment_changed 지연 refresh — 버튼 재구성
	# 창고 정렬상 첫 착용 버튼 = 완드 (KIND_ORDER: WAND < ROBE)
	var equip_buttons := _find_buttons(panel, "착용")
	_check(equip_buttons.size() == 2, "해제 후 착용 버튼 갱신")
	equip_buttons[0].pressed.emit()
	_check(gs.equipment.get(Enums.ItemKind.WAND) == &"wand_basic", "착용 버튼 → 완드 착용")
	_check(gs.get_count(&"wand_basic") == wand_before, "착용 버튼 → 창고 차감")
	await process_frame
	panel.queue_free()

func _find_buttons(node: Node, text: String) -> Array[Button]:
	var found: Array[Button] = []
	_collect_buttons(node, text, found)
	return found

func _collect_buttons(node: Node, text: String, out: Array[Button]) -> void:
	for child in node.get_children():
		var button := child as Button
		if button != null and button.text == text:
			out.append(button)
		_collect_buttons(child, text, out)
