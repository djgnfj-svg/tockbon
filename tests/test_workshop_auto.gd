extends SceneTree
## 공방(장비 제작·착용) 자동 검증 — 세션32.
## 실행: Godot --headless --path . -s res://tests/test_workshop_auto.gd
## 오토로드는 런타임 get_node로만 접근 (-s 컴파일 시점 미등록 함정).
##
## 🔴 이 테스트는 **데이터·로직 계약만** 지킨다 — 레시피 station 분리, 펜 제작(spend→add),
## 장착 라운드트립(equip→correction→소비, unequip→반환). **패널 클릭은 헤드리스가 못 잡는다**
## (Ground/모달 mouse_filter 함정) — 그건 세션32에 에디터 실게임 push_input으로 따로 검증했다.

var _pass := 0
var _fail := 0

func _init() -> void:
	_run.call_deferred()

func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("PASS: ", label)
	else:
		_fail += 1
		print("FAIL: ", label)

func _ids(recipes: Array) -> Array:
	var out: Array = []
	for r in recipes:
		out.append(r.id)
	return out

func _run() -> void:
	await process_frame
	var gs: Node = root.get_node("GameState")
	var db: Node = root.get_node("Db")

	var pen_kind: int = db.get_item(&"pen_mid").kind

	# ── ① 레시피 station 분리 — 공방(장비)과 정제대(잉크·종이)가 서로 안 섞인다 ──
	var craft: Array = db.recipes_for_station(&"craft")
	var refine: Array = db.recipes_for_station(&"refine")
	var craft_ids := _ids(craft)
	var refine_ids := _ids(refine)
	_check("공방 레시피가 있다", not craft.is_empty())
	_check("정제대 레시피가 있다", not refine.is_empty())
	_check("펜 3종이 공방에 있다",
		&"craft_pen_basic" in craft_ids and &"craft_pen_mid" in craft_ids and &"craft_pen_high" in craft_ids)

	var overlap := false
	for id in craft_ids:
		if id in refine_ids:
			overlap = true
	_check("🔴 두 작업대 레시피가 겹치지 않는다 (station 필터)", not overlap)

	# 🔴 세션42: 공방이 펜뿐 아니라 지팡이·로브·부적·모자도 만든다 — 계약은 "펜"이 아니라
	# "장비(equip 카테고리)"다. kind==pen 고정 단정이 새 장비 레시피에서 낡았다.
	var all_craft_are_equip := true
	for r in craft:
		var out_item: ItemDef = db.get_item(r.output_id)
		if out_item == null or out_item.category() != &"equip":
			all_craft_are_equip = false
	_check("공방 레시피 결과물은 전부 장비(equip)다", all_craft_are_equip)

	var no_pen_in_refine := true
	for r in refine:
		var out_item: ItemDef = db.get_item(r.output_id)
		if out_item != null and out_item.kind == pen_kind:
			no_pen_in_refine = false
	_check("정제대엔 펜 레시피가 새어들지 않는다", no_pen_in_refine)

	# ── ② 펜 제작 — 재료를 넣고 레시피대로 소비·지급 ──
	var r_mid: RecipeDef = db.get_recipe(&"craft_pen_mid")
	_check("craft_pen_mid 레시피 존재", r_mid != null)
	# 재료 부족이면 못 만든다
	_check("재료 없으면 제작 불가(can_afford=false)", not gs.can_afford(r_mid.inputs))
	for id: StringName in r_mid.inputs:
		gs.add_item(id, int(r_mid.inputs[id]))
	_check("재료 채우면 제작 가능(can_afford=true)", gs.can_afford(r_mid.inputs))
	var before: int = gs.get_count(&"pen_mid")
	if gs.spend(r_mid.inputs):
		gs.add_item(r_mid.output_id, r_mid.output_count)
	_check("제작 후 펜이 창고에 생긴다", gs.get_count(&"pen_mid") == before + 1)
	for id: StringName in r_mid.inputs:
		_check("제작이 재료 %s를 다 소비했다" % id, gs.get_count(id) == 0)

	# ── ③ 장착 라운드트립 — correction이 산다/죽는다 ──
	_check("장착 전 보정 0 (맨손)", is_equal_approx(gs.stroke_correction(), 0.0))
	var ok: bool = gs.equip_gear(&"pen_mid")
	_check("펜 장착 성공(equip_gear=true)", ok)
	_check("장착 부위에 펜이 앉는다", gs.equipment.get(pen_kind, &"") == &"pen_mid")
	_check("🔴 장착이 손그림 보정을 살린다 (0.35)", is_equal_approx(gs.stroke_correction(), 0.35))
	_check("장착이 창고에서 펜을 뺀다", gs.get_count(&"pen_mid") == 0)

	gs.unequip_gear(pen_kind)
	_check("해제하면 펜이 창고로 돌아온다", gs.get_count(&"pen_mid") == 1)
	_check("해제하면 보정이 0으로 돌아간다", is_equal_approx(gs.stroke_correction(), 0.0))
	_check("해제하면 부위가 빈다", not gs.equipment.has(pen_kind))

	# ── ④ 장착 거부 — 장비 아닌 것/보유 0 ──
	_check("장비 아닌 재료는 못 낀다", not gs.equip_gear(&"mat_hound_fang"))
	gs.remove_item(&"pen_mid", gs.get_count(&"pen_mid"))
	_check("창고에 없는 펜은 못 낀다", not gs.equip_gear(&"pen_mid"))

	# ── ⑤ 세션42 새 부위 효과 — 파생 getter가 실제로 바뀐다 (모자·부적·로브·지팡이) ──
	# 🔴 이 넷은 착용만 되고 효과가 죽어 있었다(지팡이=orphan wand_pattern, 부적=dash_cooldown_mult
	# 미배선, 모자=신설). 여기가 "껴도 아무 일 없다"의 회귀 가드다.
	var base_speed: float = gs.move_speed()
	gs.add_item(&"hat_basic")
	_check("모자 장착 성공", gs.equip_gear(&"hat_basic"))
	_check("🔴 모자가 이동 속도를 올린다 (+15%)", is_equal_approx(gs.move_speed(), base_speed * 1.15))
	gs.unequip_gear(int(Enums.ItemKind.HAT))
	_check("모자 해제하면 속도 원복", is_equal_approx(gs.move_speed(), base_speed))

	var base_cd: float = gs.roll_cooldown()
	gs.add_item(&"charm_basic")
	_check("부적 장착 성공", gs.equip_gear(&"charm_basic"))
	_check("🔴 부적이 구르기 쿨을 줄인다 (×0.85)", is_equal_approx(gs.roll_cooldown(), base_cd * 0.85))
	gs.unequip_gear(int(Enums.ItemKind.CHARM))
	_check("부적 해제하면 쿨 원복", is_equal_approx(gs.roll_cooldown(), base_cd))

	var base_hp: float = gs.hp_max()
	var base_mana: float = gs.mana_max()
	gs.add_item(&"robe_basic")
	_check("로브 장착 성공", gs.equip_gear(&"robe_basic"))
	_check("🔴 로브가 HP 상한을 올린다 (+10)", is_equal_approx(gs.hp_max(), base_hp + 10.0))
	_check("🔴 로브가 마나 상한을 올린다 (+10)", is_equal_approx(gs.mana_max(), base_mana + 10.0))
	gs.unequip_gear(int(Enums.ItemKind.ROBE))

	gs.add_item(&"wand_fork")
	_check("지팡이 장착 성공", gs.equip_gear(&"wand_fork"))
	_check("🔴 지팡이가 발사 패턴을 정한다 (산탄=MULTI)", gs.wand_pattern() == Enums.WandPattern.MULTI)
	gs.unequip_gear(int(Enums.ItemKind.WAND))
	_check("지팡이 해제하면 단발(SINGLE)", gs.wand_pattern() == Enums.WandPattern.SINGLE)

	print("RESULT pass=%d fail=%d" % [_pass, _fail])
	if _fail == 0:
		print("TEST_WORKSHOP_OK — 전 항목 통과")
	quit()
