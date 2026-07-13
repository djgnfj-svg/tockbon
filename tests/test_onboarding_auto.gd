extends SceneTree
## 온보딩 자동 검증 — 시작 물자·자동 장착·거점 시험장·튜토리얼 시나리오 (TECH_SPEC §4.3·§5.2).
## 실행: Godot --headless --path . -s res://tests/test_onboarding_auto.gd
## 주의: -s 스크립트는 오토로드 전역 등록 전에 컴파일되므로,
## 오토로드는 root.get_node()로, 모듈 스크립트는 첫 프레임에 load()로 얻는다.

var _fails: int = 0

# 오토로드 (첫 프레임에 바인딩)
var gs: Node      # GameState
var eb: Node      # EventBus

# 지연 로드
var TrainingDummy: GDScript
var BasePlayer: GDScript
var Tutorial: GDScript

func _init() -> void:
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
	TrainingDummy = load("res://src/base/training_dummy.gd")
	BasePlayer = load("res://src/base/base_player.gd")
	Tutorial = load("res://src/tutorial/tutorial.gd")
	_test_start_state()
	_test_auto_equip()
	await _test_training_dummy()
	await _test_base_cast()
	await _test_base_scene()
	await _test_bulletin_gate()
	await _test_tutorial_flow()
	if _fails == 0:
		print("TEST_ONBOARDING_OK")
	else:
		print("TEST_ONBOARDING_FAILED: ", _fails)
	quit(mini(_fails, 125))


# ── 시작 상태: 도안 0장으로 시작한다 (첫 도안은 튜토리얼에서 직접 그린다)

func _test_start_state() -> void:
	var src := FileAccess.get_file_as_string("res://src/core/main.gd")
	_check(not src.contains("SampleDesigns"),
		"main.gd가 샘플 도안을 지급하지 않음 (도안 0장 시작)")
	_check(src.contains("_seed_new_game"), "새 게임 시드 함수 존재")
	_check(gs.is_unlocked(&"rune_fire") and gs.is_unlocked(&"rune_impact"),
		"시작 해금: 불·충격 룬 (물·바람은 미해금)")
	_check(not gs.is_unlocked(&"rune_water"), "물 룬은 해독 보상 — 시작에 없음")


# ── 도안 자동 장착 (TECH_SPEC §4.3): 그린 즉시 슬롯 1에 꽂혀야 바로 쏴볼 수 있다

func _test_auto_equip() -> void:
	gs.designs.clear()
	for i in range(gs.EQUIP_SLOTS):
		gs.equipped[i] = null

	var first := _make_design(&"tut_fireball")
	eb.design_created.emit(first)
	_check(gs.equipped[0] == first, "첫 도안이 슬롯 1에 자동 장착됨")
	_check(gs.designs.size() == 1, "보관고에도 등록됨")

	# 빈 슬롯을 순서대로 채운다
	for i in range(1, gs.EQUIP_SLOTS):
		eb.design_created.emit(_make_design(StringName("d%d" % i)))
	_check(gs.equipped[gs.EQUIP_SLOTS - 1] != null, "빈 슬롯을 순서대로 채움")

	# 4장이 차면 자동 장착하지 않는다 (교체는 아침 게시판 — GDD §4.4)
	var overflow := _make_design(&"overflow")
	eb.design_created.emit(overflow)
	var equipped_overflow := false
	for i in range(gs.EQUIP_SLOTS):
		if gs.equipped[i] == overflow:
			equipped_overflow = true
	_check(not equipped_overflow, "슬롯이 꽉 차면 자동 장착 안 함")
	_check(gs.designs.has(overflow), "그래도 보관고에는 들어감")


# ── 거점 허수아비: 맞으면 training_hit만 발신. enemy_hit/enemy_died는 절대 발신 금지
#    (도감 첫 처치 해금·퀘스트 단계가 거점에서 오작동하면 안 된다 — TECH_SPEC §5.2)

func _test_training_dummy() -> void:
	var dummy: StaticBody2D = TrainingDummy.new()
	root.add_child(dummy)
	await process_frame

	var training_hits: Array = []
	var enemy_hits: Array = []
	var enemy_deaths: Array = []
	var on_training := func(rune_type: int, damage: float) -> void:
		training_hits.append({"rune": rune_type, "dmg": damage})
	var on_enemy_hit := func(_n: Node2D, _d: float, _r: int) -> void: enemy_hits.append(1)
	var on_enemy_died := func(_def: EnemyDef, _p: Vector2) -> void: enemy_deaths.append(1)
	eb.training_hit.connect(on_training)
	eb.enemy_hit.connect(on_enemy_hit)
	eb.enemy_died.connect(on_enemy_died)

	_check(dummy.is_in_group("enemies"), "허수아비가 적 노드 계약(그룹 enemies)을 만족")
	_check(dummy.has_method("take_hit"), "take_hit 구현")

	dummy.take_hit(12.5, Enums.RuneType.FIRE, Enums.Status.BURN, 1.0)
	await process_frame
	_check(training_hits.size() == 1, "명중 → training_hit 발신")
	_check(training_hits.size() > 0 and int(training_hits[0].rune) == Enums.RuneType.FIRE,
		"룬 종류 전달 (불)")
	_check(training_hits.size() > 0 and is_equal_approx(float(training_hits[0].dmg), 12.5),
		"피해량 전달")
	_check(enemy_hits.is_empty(), "enemy_hit은 발신하지 않음 (필드 적과 혼동 금지)")
	_check(enemy_deaths.is_empty(), "enemy_died도 발신하지 않음 (허수아비는 죽지 않는다)")

	# 여러 번 맞아도 죽지 않는다
	for i in range(5):
		dummy.take_hit(99.0, Enums.RuneType.IMPACT, Enums.Status.NONE, 0.0)
	await process_frame
	_check(is_instance_valid(dummy), "여러 번 맞아도 소멸하지 않음")
	_check(training_hits.size() == 6, "맞을 때마다 발신")

	eb.training_hit.disconnect(on_training)
	eb.enemy_hit.disconnect(on_enemy_hit)
	eb.enemy_died.disconnect(on_enemy_died)
	dummy.queue_free()


# ── 거점 플레이어 캐스팅: 필드와 동일한 cast_requested 계약 + 패널 열림 중 잠금

func _test_base_cast() -> void:
	var player: CharacterBody2D = BasePlayer.new()
	root.add_child(player)
	await process_frame

	var casts: Array = []
	var on_cast := func(design: SpellDesign, _o: Vector2, _a: Vector2) -> void: casts.append(design)
	eb.cast_requested.connect(on_cast)

	var design := _make_design(&"cast_test")
	gs.equipped[0] = design

	_check(player.try_cast(0), "슬롯 1 캐스트 요청 발신")
	_check(casts.size() == 1 and casts[0] == design, "cast_requested가 그 도안으로 발신됨")

	gs.equipped[1] = null
	_check(not player.try_cast(1), "빈 슬롯은 조용히 무시")
	_check(not player.try_cast(9), "범위 밖 슬롯은 무시")

	# 시설 패널이 열려 있으면 캐스팅 금지 (오조작 방지)
	player.locked = true
	_check(not player.try_cast(0), "패널 열림(locked) 중 캐스트 차단")
	player.locked = false

	gs.ui_modal_open = true
	_check(not player.try_cast(0), "UI 모달 열림 중 캐스트 차단")
	gs.ui_modal_open = false

	eb.cast_requested.disconnect(on_cast)
	player.queue_free()


# ── 거점 씬: 시험장 + 스펠 시스템이 실제로 배선돼 있는가 + 유도 마커

func _test_base_scene() -> void:
	var packed: PackedScene = load("res://src/base/base.tscn")
	_check(packed != null, "base.tscn 로드")
	var base: Node2D = packed.instantiate()
	root.add_child(base)
	await process_frame
	await process_frame

	var dummy := base.get_node_or_null(^"TrainingDummy")
	_check(dummy != null, "거점에 허수아비가 있음")
	_check(base.get_node_or_null(^"SpellSystem") != null,
		"거점에 SpellSystem이 있음 (실제 투사체가 날아간다)")

	# 유도 마커: 튜토리얼은 시그널로만 거점을 유도한다 (모듈 경계 — TECH_SPEC §5.2)
	eb.tutorial_focus.emit(&"easel")
	await process_frame
	var easel := base.get_node_or_null(^"Interactables/Easel")
	_check(easel != null and _has_marker(easel), "tutorial_focus(easel) → 이젤에 마커")

	eb.tutorial_focus.emit(&"dummy")
	await process_frame
	_check(dummy != null and _has_marker(dummy), "tutorial_focus(dummy) → 허수아비로 마커 이동")
	_check(easel != null and not _has_marker(easel), "이전 대상의 마커는 제거됨 (중복 표시 없음)")

	eb.tutorial_focus.emit(&"door")
	await process_frame
	var door := base.get_node_or_null(^"Interactables/Door")
	_check(door != null and _has_marker(door), "tutorial_focus(door) → 문에 마커")

	eb.tutorial_focus.emit(&"")
	await process_frame
	_check(door != null and not _has_marker(door), "tutorial_focus(\"\") → 마커 해제")

	eb.tutorial_focus.emit(&"nonexistent_facility")
	await process_frame
	_check(true, "없는 대상을 지목해도 크래시하지 않음")

	base.queue_free()
	await process_frame


## 마커는 base.gd가 대상 노드의 자식 Label로 단다 — 이름이 아니라 존재로 판정
func _has_marker(target: Node) -> bool:
	for child in target.get_children():
		var label := child as Label
		if label != null and label.text == "▼":
			return true
	return false


# ── 첫날 아침 게시판 억제: 도안 0장인데 장착 화면이 강제로 열리면 빈 슬롯 4칸 앞에서 막힌다.
#    첫날을 이끄는 건 스승의 메모다 — 게시판은 첫 출격(tutorial_done) 이후부터.

func _test_bulletin_gate() -> void:
	var ui: Control = (load("res://src/ui/ui_root.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	await process_frame

	var bulletin: Control = ui.get_node(^"Screens/Bulletin")
	var loadout: Control = ui.get_node(^"Screens/Loadout")

	gs.codex.erase(&"tutorial_done")
	eb.day_started.emit(1)
	await process_frame
	_check(not bulletin.visible, "튜토 전 1일차 아침: 게시판이 뜨지 않음")
	_check(not loadout.visible, "튜토 전: 빈 장착 화면이 강제로 열리지 않음")
	_check(not gs.ui_modal_open, "튜토 전: 모달 잠금 없음 (바로 움직일 수 있다)")

	# 첫 출격을 마친 다음 날부터는 평소대로 게시판이 열린다
	gs.codex[&"tutorial_done"] = true
	eb.day_started.emit(2)
	await process_frame
	_check(bulletin.visible, "튜토 후 아침: 게시판 정상 표시")

	ui.queue_free()
	await process_frame
	gs.ui_modal_open = false


# ── 튜토리얼 시나리오: 오두막 → 이젤 → 원·룬·화살표·완성 → 시험 발사 → 출격

func _test_tutorial_flow() -> void:
	# 이미 완료된 상태면 튜토리얼은 아무 것도 하지 않아야 한다 (재시작 방지)
	gs.codex[&"tutorial_done"] = true
	var skipper: CanvasLayer = Tutorial.new()
	root.add_child(skipper)
	await process_frame
	_check(not skipper.visible, "이미 수업을 마쳤으면 튜토리얼이 뜨지 않음")
	skipper.queue_free()
	await process_frame

	# 새 필경사 — 처음부터
	gs.codex.erase(&"tutorial_done")
	var focus_log: Array[StringName] = []
	var on_focus := func(target_id: StringName) -> void: focus_log.append(target_id)
	eb.tutorial_focus.connect(on_focus)

	var tut: CanvasLayer = Tutorial.new()
	root.add_child(tut)
	await process_frame

	# [0] 오두막 — 이젤로 유도
	eb.scene_changed.emit(&"base")
	await process_frame
	_check(tut.visible, "거점 진입 시 스승의 메모가 뜬다 (이젤을 찾아 헤매지 않게)")
	_check(focus_log.has(&"easel"), "이젤로 유도 마커")

	# [1~4] 드로잉룸 — 원 → 불 → 화살표 → 완성
	eb.scene_changed.emit(&"drawing")
	await process_frame
	eb.recognition_result.emit(Enums.StrokeRole.CIRCLE, true, 0.9)
	eb.recognition_result.emit(Enums.StrokeRole.RUNE, true, 0.85)
	eb.recognition_result.emit(Enums.StrokeRole.ARROW, true, 1.0)
	await process_frame
	_check(not gs.is_unlocked(&"tutorial_done"), "도안을 완성하기 전에는 수업이 끝나지 않음")
	eb.design_created.emit(_make_design(&"tut_fireball"))
	await process_frame

	# [5] 시험 발사 — 허수아비로 유도. 아직 완료 아님
	eb.scene_changed.emit(&"base")
	await process_frame
	_check(focus_log.has(&"dummy"), "도안 완성 후 허수아비로 유도")
	_check(not gs.is_unlocked(&"tutorial_done"), "쏴 보기 전에는 아직 수업 중")

	eb.training_hit.emit(Enums.RuneType.FIRE, 14.0)
	await process_frame
	_check(focus_log.has(&"door"), "명중 후 문으로 유도 (출격)")

	# [6] 출격 — 필드 진입 순간 수업 완료
	eb.scene_changed.emit(&"field")
	await process_frame
	_check(gs.is_unlocked(&"tutorial_done"), "숲에 나가는 순간 수업 완료 (tutorial_done)")

	eb.tutorial_focus.disconnect(on_focus)
	tut.queue_free()
	await process_frame


# ── 헬퍼

func _make_design(id: StringName) -> SpellDesign:
	var d := SpellDesign.new()
	d.id = id
	d.display_name = String(id)
	d.circle_type = Enums.CircleType.AIMED
	d.circle_radius = 0.5
	d.rune_type = Enums.RuneType.FIRE
	d.rune_accuracy = 0.9
	var a := ArrowData.new()
	a.direction = 0.0
	a.magnitude = 0.5
	d.arrows.append(a)
	d.mana_cost = 10.0
	d.ink_cost = {&"ink_basic": 6}
	d.durability_max = 20
	d.durability = 20
	return d
