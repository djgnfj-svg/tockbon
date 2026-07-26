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
	# 🔴 세84 #44: 워치독 — `_run`이 중간에 죽으면(런타임 에러로 함수 중단) `quit()`에 못 닿아
	# 프로세스가 **영구 hang**했다(다른 22종엔 이 안전망이 있었다).
	create_timer(30.0).timeout.connect(func() -> void:
		print("TEST_WORKSHOP_TIMEOUT — 30초 초과 (테스트가 중간에 죽었을 수 있다)")
		quit(1))
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
	# 🔴🔴 **세88에 이 계약이 또 낡았다**: 공방이 이제 **조립 부품(고리·룬·진)도 만든다.** 그건
	# 아이템이 아니라 **codex 해금**이라 `output_id`가 비어 있고 `get_item`이 null이다 —
	# 옛 형태 그대로면 신규 8장이 전부 빨개진다. **아이템 레시피에만** 장비 계약을 적용한다.
	# ⚠ 그렇다고 검사를 지우지 마라 — 「공방에 잉크·종이가 새어들지 않는다」를 아직 이게 잰다.
	var all_craft_are_equip := true
	var unlock_recipes := 0
	for r in craft:
		if r.reward_unlock != &"":
			unlock_recipes += 1
			# 🔴 해금 레시피는 output_id가 **비어 있어야** 한다. 채우면 창고에 유령 아이템이
			# 쌓이고 세이브에 영구화된다(`_craft`가 조건 없이 add_item을 부르던 자리).
			_check("해금 레시피 %s는 output_id가 비어 있다" % r.id, r.output_id == &"" and r.output_count == 0)
			continue
		var out_item: ItemDef = db.get_item(r.output_id)
		if out_item == null or out_item.category() != &"equip":
			all_craft_are_equip = false
	_check("공방의 **아이템** 레시피 결과물은 전부 장비(equip)다", all_craft_are_equip)
	# 🔴 명시 숫자 — 스캔만 하면 「레시피가 통째로 사라져도 0/0 통과」가 된다(세88 신규 8장).
	_check("공방에 해금 레시피 8장이 있다 (실제 %d)" % unlock_recipes, unlock_recipes == 8)

	# 🔴🔴 목록 순서가 **결정적**인가 (세88 실측 버그): `Db.all_recipes`가 `keys.sort()`를 쓰면
	# 키가 `StringName`이라 **사전순이 아니라 인터닝 순**이고 **실행마다 순서가 바뀐다**.
	# 레시피 3장일 땐 안 드러났지만 공방이 17줄이 되며 목록이 튀었다. 주석은 「id 오름차순」이라고
	# 선언만 하고 있었다(감사 T4). 뮤테이션: `sort_custom` → `sort`로 되돌리면 여기가 빨개진다.
	var sorted_ids: Array = craft_ids.duplicate()
	sorted_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	_check("🔴 공방 레시피가 id 사전순으로 온다 (StringName sort()는 인터닝 순이라 실행마다 흔들린다)",
		craft_ids == sorted_ids)

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
	# 🔴 이 넷은 착용만 되고 효과가 죽어 있었다(지팡이=도달 불가 wand_pattern, 부적=dash_cooldown_mult
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

	# 🔴 세85: 지팡이 축이 **발사 패턴 → 세기·속도 스칼라**로 갈렸다 (감사 #5). 옛 검사
	# (`wand_pattern() == MULTI`)는 게터가 옳은 값을 줘도 **발사가 그 값을 못 받는** 상태를 못 잡았다 —
	# 실제로 두 지팡이는 게임에서 `wand_basic`과 성능이 완전히 같았다. 여기선 두 축이 **맨손과 다른가**만
	# 재고(장착 라운드트립), 「발사에 도달하나」는 `test_ring_spell_auto[12]`가 실제 발사로 잰다.
	# ⚠ 배수 값을 박지 않는다 — 튜닝 한 번에 거짓 빨강이 되지 않게 **대소·원복 관계**로만 잰다.
	var base_wspeed: float = gs.wand_speed_mult()
	var base_cost: float = gs.cast_mana_cost()
	gs.add_item(&"wand_fork")
	_check("지팡이 장착 성공", gs.equip_gear(&"wand_fork"))
	_check("🔴 지팡이가 진 속도를 올린다 (맨손보다 빠르다)", gs.wand_speed_mult() > base_wspeed)
	gs.unequip_gear(int(Enums.ItemKind.WAND))
	_check("지팡이 해제하면 진 속도 원복", is_equal_approx(gs.wand_speed_mult(), base_wspeed))

	gs.add_item(&"wand_ring")
	_check("둘레 지팡이 장착 성공", gs.equip_gear(&"wand_ring"))
	_check("🔴 지팡이가 발사 마나를 줄인다 (맨손보다 싸다)", gs.cast_mana_cost() < base_cost)
	gs.unequip_gear(int(Enums.ItemKind.WAND))
	_check("지팡이 해제하면 발사 마나 원복", is_equal_approx(gs.cast_mana_cost(), base_cost))

	# 🔴 **세 지팡이가 서로 다르다** — 재료를 태운 제작이 순수 손실이 아니라는 계약(감사 #5의 심장).
	# 하나라도 파라미터가 빠지면(= 옛 `wand_fork`처럼 cooldown·damage가 0) 여기가 빨개진다.
	var seen := {}
	for wid: StringName in [&"wand_basic", &"wand_fork", &"wand_ring"]:
		gs.add_item(wid)
		gs.equip_gear(wid)
		seen[wid] = "%.4f/%.4f" % [gs.wand_speed_mult(), gs.cast_mana_cost()]
		gs.unequip_gear(int(Enums.ItemKind.WAND))
	_check("🔴 지팡이 3종이 서로 다른 성능이다 (%s)" % [seen],
		seen[&"wand_basic"] != seen[&"wand_fork"] and seen[&"wand_basic"] != seen[&"wand_ring"] \
		and seen[&"wand_fork"] != seen[&"wand_ring"])

	# ── ⑤ 🔴🔴 세88 해금 레시피 — 재료를 태워 **아이템이 아니라 codex**를 받는다 ──
	#
	# 이게 이번 설계의 본줄이다: 사냥의 종착지가 돈·장비가 아니라 **「새로 조립할 것」**이다.
	# 🔴 **라이브 패널 경로로 잰다**(`_recipe_title`·`_inputs_text`·`_craft`). 순수 함수만 직접 부르면
	#   「패널이 실제로 그 함수를 쓰는지」는 무측정이다 — ui 갈래가 정렬 그물에서 정확히 그걸 밟았다
	#   (검사가 정렬 함수를 직접 불러서, 패널이 정렬을 안 해도 그린이었다).
	var ru: RecipeDef = db.get_recipe(&"craft_gr_spread3")
	_check("해금 레시피가 Db에 로드된다 (.tres 값 문법이 틀리면 여기서 통째로 사라진다)",
		ru != null and ru.reward_unlock == &"gr_spread3")
	var panel: Control = (load("res://src/base/workshop_panel.tscn") as PackedScene).instantiate() as Control
	root.add_child(panel)
	await process_frame
	# 🔴 행 제목이 `RecipeDef.display_name`에서 나온다 — 세87까지 이 필드를 읽는 코드가 프로젝트에
	# **한 곳도 없었다**(세 패널 전부 `output_id` 아이템 이름만 썼다). 해금 레시피는 output_id가
	# 비어서, 폴백에 걸리면 제목이 정확히 **" ×0"**이 된다.
	_check("🔴 행 제목이 display_name에서 나온다 (실제 '%s')" % panel._recipe_title(ru),
		panel._recipe_title(ru) == "확산 고리 제작")
	# 🔴 기대치를 **레시피에서 파생**하고 창고를 먼저 비운다 — 상수 "3/5"를 박으면 ⓐ 레시피 수량을
	# 조일 때 거짓 빨강이고 ⓑ **앞선 실행이 남긴 재료가 누적돼** "6/5"가 된다(리드가 실제로 밟았다:
	# 테스트 세이브가 실행 사이에 살아 있어 `add_item`이 쌓인다).
	var need_core: int = int(ru.inputs[&"mat_slime_core"])
	gs.inventory.erase(&"mat_slime_core")
	gs.add_item(&"mat_slime_core", need_core - 2)
	_check("🔴 재료 진행이 `보유/필요` 순이다 (실제 '%s')" % panel._inputs_text(ru),
		panel._inputs_text(ru).contains("%d/%d" % [need_core - 2, need_core]))

	# 🔴 시드가 gr_spread3를 미리 해금해 두면 제작 경로가 닫혀 있다 — 걷어서 첫 획득을 잰다.
	gs.codex.erase(&"gr_spread3")
	var bus = root.get_node("/root/EventBus")   # -s 컴파일 시점엔 오토로드가 없다 — 런타임 조회
	var unlocked: Array = []      # 🔴 참조 타입 — 람다는 로컬을 **값으로** 캡처한다(리드가 밟은 함정)
	var ucb := func(uid: StringName) -> void: unlocked.append(uid)
	bus.codex_unlocked.connect(ucb)
	for mid: StringName in ru.inputs:
		gs.add_item(mid, int(ru.inputs[mid]))
	panel._craft(&"craft_gr_spread3")
	_check("🔴 제작이 codex_unlocked를 정확히 1발 쏜다 (실제 %s)" % [unlocked],
		unlocked.size() == 1 and unlocked[0] == &"gr_spread3")
	_check("codex에 심겼다 (해금음·UNLOCK 퀘스트·자동 저장이 이 한 발에 딸려 온다)",
		gs.is_unlocked(&"gr_spread3"))
	# 🔴🔴 **키 존재로 재라.** `output_count = 0`이라 옛 코드는 `add_item(&"", 0)` →
	# `inventory[&""] = 0`이 된다: **수량은 0인데 키가 생겨 세이브에 영구화된다.**
	# `get_count(&"") == 0`으로 재면 뮤테이션에도 그린이다(ui 갈래가 실측으로 경고했다).
	_check("🔴 창고에 빈 id 키가 안 생긴다 (유령 아이템)",
		not gs.get_inventory_snapshot().has(&""))
	var coin_before: int = gs.get_count(&"coin")
	panel._craft(&"craft_gr_spread3")
	_check("🔴 이미 배운 것은 재료를 안 태운다 (버튼이 조용히 살아나도)",
		gs.get_count(&"coin") == coin_before and unlocked.size() == 1)
	bus.codex_unlocked.disconnect(ucb)
	panel.free()

	print("RESULT pass=%d fail=%d" % [_pass, _fail])
	if _fail == 0:
		print("TEST_WORKSHOP_OK — 전 항목 통과")
	# 🔴 세84 #44: 실패하면 종료코드 1 (전엔 인자 없는 quit() = 실패해도 0).
	quit(0 if _fail == 0 else 1)
