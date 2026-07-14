extends SceneTree
## Phase 2 통합 스모크 — 부팅(거점) → 필드 전환·캐스팅 → 귀환 → 드로잉룸 왕복.
## 실행: Godot --headless --path . -s res://tests/test_integration_auto.gd
## 주의: 오토로드는 런타임 get_node로만 접근 (-s 컴파일 시점 미등록 — TEAM_PLAN 공유 함정).

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

func _run() -> void:
	await process_frame
	var bus: Node = root.get_node("EventBus")
	var gs: Node = root.get_node("GameState")
	var sm: Node = root.get_node("SaveManager")
	sm.wipe_save()  # 실제 플레이 세이브 오염 방지 — 테스트는 항상 새 게임에서

	var main: Node = (load("res://src/core/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var holder: Node = main.get_node("CurrentScene")

	_check("부팅: 거점 로드", holder.get_node_or_null("Base") != null)
	# 새 게임은 도안 0장으로 시작한다 — 첫 도안은 튜토리얼에서 직접 그린다 (TECH_SPEC §5.1)
	_check("시드: 도안 0장", gs.equipped[0] == null and gs.designs.is_empty())
	_check("시드: 시작 물자 (잉크·종이)", gs.get_count(&"ink_basic") > 0 and gs.get_count(&"paper_1") > 0)
	_check("시드: 시작 장비 3부위 착용", gs.equipment.size() == 3)
	_check("시작 해금: 불·충격", gs.is_unlocked(&"rune_fire") and gs.is_unlocked(&"rune_impact"))

	# 거점 시험장 — 그린 도안을 숲에 나가기 전에 쏴 볼 수 있어야 한다 (TECH_SPEC §5.2)
	var base: Node = holder.get_node_or_null("Base")
	_check("거점: 허수아비 배치", base != null and base.get_node_or_null("TrainingDummy") != null)
	_check("거점: SpellSystem 배치", base != null and base.get_node_or_null("SpellSystem") != null)

	# 튜토리얼에서 첫 도안을 그린 것과 같은 경로 — design_created → 빈 슬롯 자동 장착 (TECH_SPEC §4.3)
	var first: SpellDesign = SampleDesigns.nova_fire()
	bus.emit_signal(&"design_created", first)
	_check("첫 도안이 슬롯 1에 자동 장착", gs.equipped[0] == first)

	# 출격 → 필드
	bus.emit_signal(&"scene_change_requested", &"field")
	await process_frame
	await process_frame
	var field: Node = holder.get_node_or_null("Field")
	_check("필드 전환", field != null)
	_check("SpellSystem 배치", field != null and field.get_node_or_null("SpellSystem") != null)

	# 캐스팅 — spell_system이 수신해 투사체 스폰.
	# 🔴 **v2.0: 발수는 지팡이가 정한다** (기본 지팡이 = 단발). 문양 개수가 아니다.
	# 이 도안은 문양이 8개지만 **8발이 아니라 1발**이고, 그 8개는 **효과로 합쳐진다**
	# (TECH_SPEC §4.0-a). 방향이 지팡이로 간 순간 "문양 1개 = 1발"은 성립할 수 없다 —
	# 8발이 전부 에임 방향으로 **같은 자리에 겹쳐** 나가기 때문이다.
	# ⚠ 그래서 **전방위(노바)는 지팡이가 돌려줘야 한다** — 아직 단발뿐이다
	var mana_before: float = gs.mana
	bus.emit_signal(&"cast_requested", gs.equipped[0], Vector2(400, 300), Vector2.RIGHT)
	await process_frame
	var shots := get_nodes_in_group(&"player_projectiles").size()
	_check("캐스팅: 단발 지팡이 → 투사체 1개 (문양 %d개여도 — 실제 %d)"
		% [gs.equipped[0].arrows.size(), shots], shots == 1)
	_check("캐스팅: 마나 차감", gs.mana < mana_before)
	_check("캐스팅: 내구 차감", gs.equipped[0].durability < gs.equipped[0].durability_max)

	# 귀환 → 거점
	bus.emit_signal(&"extraction_success")
	await process_frame
	await process_frame
	_check("귀환: 거점 복귀", holder.get_node_or_null("Base") != null)

	# 이젤 → 드로잉룸 → 거점
	bus.emit_signal(&"scene_change_requested", &"drawing")
	await process_frame
	await process_frame
	_check("드로잉룸 진입", holder.get_node_or_null("DrawingRoom") != null)
	bus.emit_signal(&"scene_change_requested", &"base")
	await process_frame
	await process_frame
	_check("드로잉룸 → 거점 복귀", holder.get_node_or_null("Base") != null)

	sm.wipe_save()  # 테스트 중 자동 저장(귀환 등)된 상태 제거
	print("RESULT pass=%d fail=%d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
