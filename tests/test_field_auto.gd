extends Node2D
## 모듈 C 자동 검증 (DoD) — 헤드리스 실행 시 PASS/FAIL 로그 출력 후 자체 종료.
## 실행: Godot --headless --path . res://tests/test_field.tscn --quit-after 600
## take_hit 직접 호출(더미 대미지)로 약점 배율·상태이상·밤 강화·탁본·드롭 루프를 검증한다.

const Spawner := preload("res://src/field/enemy_spawner.gd")
const PlayerScript := preload("res://src/field/player.gd")
const ExitGateScript := preload("res://src/field/exit_gate.gd")
const GatherNodeScript := preload("res://src/field/gather_node.gd")

const EPS := 0.05

var _fails: int = 0
var _died_ids: Array = []
var _cast_seen: SpellDesign = null
var _cast_count: int = 0
var _rubbing_completed_id: StringName = &""
var _extraction_seen: bool = false
var _player_damaged_seen: bool = false
var _player_died_seen: bool = false
var _bag_lost_seen: bool = false
var _unlocked_ids: Array = []

func _ready() -> void:
	EventBus.codex_unlocked.connect(func(unlock_id: StringName) -> void:
		_unlocked_ids.append(unlock_id))
	EventBus.enemy_died.connect(func(def: EnemyDef, _pos: Vector2) -> void:
		_died_ids.append(def.id if def != null else &"<null>"))
	EventBus.cast_requested.connect(func(design: SpellDesign, _origin: Vector2, _aim: Vector2) -> void:
		_cast_seen = design
		_cast_count += 1)
	EventBus.rubbing_completed.connect(func(fragment_id: StringName) -> void:
		_rubbing_completed_id = fragment_id)
	EventBus.extraction_success.connect(func() -> void: _extraction_seen = true)
	EventBus.player_damaged.connect(func(_amount: float) -> void: _player_damaged_seen = true)
	EventBus.player_died.connect(func() -> void: _player_died_seen = true)
	EventBus.bag_lost.connect(func() -> void: _bag_lost_seen = true)
	_run.call_deferred()

func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		_fails += 1
		print("FAIL: ", label)

func _bag_count(item_id: StringName) -> int:
	var total := 0
	for entry: Dictionary in GameState.bag:
		if entry["id"] == item_id:
			total += int(entry["count"])
	return total

func _mini_count() -> int:
	var n := 0
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if e.get("is_mini") == true:
			n += 1
	return n

func _spawn_enemy(id: StringName, pos: Vector2) -> Variant:
	var def: EnemyDef = Db.get_enemy(id)
	if def == null:
		return null
	var e: Variant = Spawner.spawn(def)
	e.ai_enabled = false
	e.position = pos
	add_child(e)
	return e

func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	print("=== test_field: 모듈 C 자동 검증 시작 ===")

	# ── 1. EnemyDef .tres 6종 로드 (Db 레지스트리)
	for id: StringName in [&"vine", &"hound", &"slime", &"slime_elite", &"mist", &"beetle"]:
		_check(Db.get_enemy(id) != null, "EnemyDef 로드: %s" % id)
	var elite_def: EnemyDef = Db.get_enemy(&"slime_elite")
	if elite_def != null:
		_check(elite_def.is_elite, "slime_elite.is_elite == true")
	var slime_def: EnemyDef = Db.get_enemy(&"slime")
	if slime_def != null:
		_check(not slime_def.has_counter, "slime.has_counter == false (약점 없음 표기)")
	var vine_def_pre: EnemyDef = Db.get_enemy(&"vine")
	if vine_def_pre != null:
		_check(vine_def_pre.has_counter, "vine.has_counter == true")
		_check(not vine_def_pre.params.is_empty(), "EnemyDef.params 전투 수치 원장 존재")

	# ── 2. 플레이어 계약 (그룹 player, 레이어 2)
	var player: Variant = PlayerScript.new()
	player.position = Vector2.ZERO
	add_child(player)
	_check(player.is_in_group("player"), "플레이어 그룹 'player'")
	_check(player.collision_layer == 1 << 1, "플레이어 충돌 레이어 2")
	_check(GameState.hp == GameState.balance.player_hp_max, "플레이어 HP = balance.player_hp_max (원장 GameState.hp)")

	# ── 3. 적 스폰 + 노드 계약 (그룹 enemies, 레이어 3, take_hit)
	var vine: Variant = _spawn_enemy(&"vine", Vector2(600, 0))
	var hound: Variant = _spawn_enemy(&"hound", Vector2(600, 200))
	var slime: Variant = _spawn_enemy(&"slime", Vector2(600, 400))
	var mist: Variant = _spawn_enemy(&"mist", Vector2(600, 600))
	var beetle: Variant = _spawn_enemy(&"beetle", Vector2(600, 800))
	var elite: Variant = _spawn_enemy(&"slime_elite", Vector2(600, 1000))
	if vine == null or hound == null or slime == null or mist == null or beetle == null or elite == null:
		_check(false, "적 6종 스폰 (EnemyDef 누락 — 이후 검증 불가)")
		_finish()
		return
	_check(vine.is_in_group("enemies"), "적 그룹 'enemies'")
	_check(vine.collision_layer == 1 << 2, "적 충돌 레이어 3")
	_check(vine.has_method("take_hit"), "적 take_hit 메서드")
	_check(absf(vine.regen_per_sec - float(Db.get_enemy(&"vine").params["regen_per_sec"])) < EPS,
		"params → 스크립트 반영: vine.regen_per_sec")
	_check(absf(beetle.contact_damage - float(Db.get_enemy(&"beetle").params["contact_damage"])) < EPS,
		"params → 스크립트 반영: beetle.contact_damage")

	# ── 4. 약점 배율 — 재생 덩굴(불△ x1.75)
	var hp0: float = vine.hp
	vine.take_hit(10.0, -1, Enums.Status.NONE, 0.0)
	var neutral_loss: float = hp0 - vine.hp
	hp0 = vine.hp
	vine.take_hit(10.0, Enums.RuneType.FIRE, Enums.Status.NONE, 0.0)
	var fire_loss: float = hp0 - vine.hp
	_check(absf(neutral_loss - 10.0) < EPS, "덩굴 무속성 피해 10")
	_check(absf(fire_loss - 10.0 * vine.weakness_mult) < EPS, "덩굴 불 약점 배율 x%.2f" % vine.weakness_mult)

	# ── 5. 화상 지속딜 + 재생 정지 (불이 덩굴의 카운터인 이유)
	hp0 = vine.hp
	vine.take_hit(0.0, -1, Enums.Status.BURN, 2.0)   # 초당 2 화상
	vine.simulate(1.0, false)
	var burn_loss: float = hp0 - vine.hp
	_check(vine.is_burning(), "덩굴 화상 상태 적용")
	_check(absf(burn_loss - 2.0) < EPS, "화상 틱 피해(재생 정지 포함): -2.0 (실측 %.2f)" % burn_loss)
	vine.simulate(4.0, false)   # 남은 화상 소진
	hp0 = vine.hp
	vine.simulate(2.0, false)   # 화상 종료 후 재생 재개
	var regen_gain: float = vine.hp - hp0
	_check(absf(regen_gain - vine.regen_per_sec * 2.0) < EPS, "화상 종료 후 재생 재개: +%.1f" % regen_gain)

	# ── 6. 넉백 — 숲 사냥개 (충격>이 돌진을 끊는 카운터)
	hound.take_hit(0.0, -1, Enums.Status.KNOCKBACK, 3.0)
	_check((hound.knock_velocity as Vector2).length() > 0.0, "사냥개 넉백 속도 부여")

	# ── 7. 슬라임 — 약점 룬 없음 (배율 1.0, 다발 도안이 답)
	hp0 = slime.hp
	slime.take_hit(3.0, -1, Enums.Status.NONE, 0.0)
	var s_neutral: float = hp0 - slime.hp
	hp0 = slime.hp
	slime.take_hit(3.0, Enums.RuneType.FIRE, Enums.Status.NONE, 0.0)
	var s_fire: float = hp0 - slime.hp
	_check(absf(s_neutral - s_fire) < EPS, "슬라임 약점 배율 없음 (무속성==불)")

	# ── 8. 안개 정령 — 산개 저항 + 바람 관통
	mist.dispersed = false
	hp0 = mist.hp
	mist.take_hit(4.0, -1, Enums.Status.NONE, 0.0)
	_check(absf((hp0 - mist.hp) - 4.0) < EPS, "정령 응집 상태 무속성 피해 온전")
	hp0 = mist.hp
	mist.take_hit(4.0, Enums.RuneType.WIND, Enums.Status.NONE, 0.0)
	_check(absf((hp0 - mist.hp) - 4.0 * mist.weakness_mult) < EPS, "정령 바람 약점 배율 x%.1f" % mist.weakness_mult)
	mist.dispersed = true
	hp0 = mist.hp
	mist.take_hit(4.0, -1, Enums.Status.NONE, 0.0)
	_check(absf((hp0 - mist.hp) - 4.0 * 0.35) < EPS, "정령 산개 중 무속성 피해 65%% 감소")
	hp0 = mist.hp
	mist.take_hit(2.0, Enums.RuneType.WIND, Enums.Status.NONE, 0.0)
	_check(absf((hp0 - mist.hp) - 2.0 * mist.weakness_mult) < EPS, "정령 산개 중에도 바람은 온전+약점")
	mist.take_hit(0.0, -1, Enums.Status.FLOW, 5.0)
	_check(mist.has_status(Enums.Status.FLOW), "정령 흐름(FLOW) 밀림 상태 적용")

	# ── 9. 갑주 갑충 — 장갑 70% 감소, WET가 갑주 무력화, 약점 물~
	hp0 = beetle.hp
	beetle.take_hit(10.0, -1, Enums.Status.NONE, 0.0)
	var armored_loss: float = hp0 - beetle.hp
	_check(absf(armored_loss - 3.0) < EPS, "갑충 장갑: 10 피해 → 3.0 (실측 %.2f)" % armored_loss)
	beetle.take_hit(0.0, -1, Enums.Status.WET, 1.0)
	_check(beetle.has_status(Enums.Status.WET), "갑충 젖음(WET) 상태 적용")
	hp0 = beetle.hp
	beetle.take_hit(10.0, -1, Enums.Status.NONE, 0.0)
	var wet_loss: float = hp0 - beetle.hp
	_check(absf(wet_loss - 10.0) < EPS, "젖음 중 장갑 무력화: 10 피해 온전 (실측 %.2f)" % wet_loss)
	hp0 = beetle.hp
	beetle.take_hit(10.0, Enums.RuneType.WATER, Enums.Status.NONE, 0.0)
	_check(absf((hp0 - beetle.hp) - 10.0 * beetle.weakness_mult) < EPS, "갑충 물 약점 배율 x%.2f" % beetle.weakness_mult)

	# ── 10. 밤 강화 (phase_changed를 코드로 발신) + 밤 전용 채집 노드
	var night_gather: Variant = GatherNodeScript.new()
	night_gather.item_id = &"mat_night_bloom"
	night_gather.night_only = true
	night_gather.position = Vector2(-300, 0)
	add_child(night_gather)
	_check(not night_gather._is_active(), "밤 전용 채집 노드: 낮에는 비활성")
	var base_max: float = vine._base_max_hp
	EventBus.phase_changed.emit(Enums.Phase.NIGHT)
	var vine_def: EnemyDef = Db.get_enemy(&"vine")
	_check(absf(vine.max_hp - base_max * vine_def.night_buff) < EPS,
		"밤 강화: 덩굴 max_hp x%.1f (%.1f → %.1f)" % [vine_def.night_buff, base_max, vine.max_hp])
	_check(absf(vine.night_mult - vine_def.night_buff) < EPS, "밤 강화: 공격 배율 동기화")
	_check(night_gather._is_active(), "밤 전용 채집 노드: 밤에 활성")
	_check(night_gather._collect(), "밤 채집 수확 → 가방")
	_check(_bag_count(&"mat_night_bloom") == 1, "가방에 mat_night_bloom 1개")
	EventBus.phase_changed.emit(Enums.Phase.DAY)
	_check(absf(vine.max_hp - base_max) < EPS, "낮 복귀 시 강화 해제")

	# ── 11. 슬라임 분열 (사망 → 미니 2)
	slime.take_hit(999.0, -1, Enums.Status.NONE, 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_died_ids.has(&"slime"), "enemy_died 발신: slime")
	_check(_mini_count() == 2, "슬라임 분열: 미니 2마리 (실측 %d)" % _mini_count())
	_check(_unlocked_ids.count(&"enemy_slime") == 1, "첫 처치 → codex_unlocked(enemy_slime)")
	_check(GameState.is_unlocked(&"enemy_slime"), "GameState 도감 등록: enemy_slime")
	# 같은 종(미니) 재처치 → 중복 발신 없음
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if e.get("is_mini") == true:
			e.call("take_hit", 999.0, -1, Enums.Status.NONE, 0.0)
			break
	_check(_unlocked_ids.count(&"enemy_slime") == 1, "재처치 시 codex_unlocked 중복 발신 없음")

	# ── 12. 엘리트 사망 → 무늬 잔류물 + 드롭 (조각은 직접 드롭 금지)
	elite.take_hit(999.0, -1, Enums.Status.NONE, 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_died_ids.has(&"slime_elite"), "enemy_died 발신: slime_elite")
	_check(_unlocked_ids.has(&"enemy_slime_elite"), "첫 처치 → codex_unlocked(enemy_slime_elite)")
	var spots := get_tree().get_nodes_in_group("rubbing_spots")
	_check(spots.size() == 1, "엘리트 사망 → 무늬 잔류물 1개 스폰")
	var pickups := get_tree().get_nodes_in_group("pickups")
	_check(pickups.size() >= 2, "엘리트 드롭 픽업 스폰 (실측 %d)" % pickups.size())
	var fragment_dropped := false
	for p: Node in pickups:
		if String(p.get("item_id")).begins_with("fragment_"):
			fragment_dropped = true
	_check(not fragment_dropped, "탁본 조각은 픽업으로 직접 드롭되지 않음")

	# ── 13. 픽업 → 가방
	if pickups.size() > 0:
		var pk: Variant = pickups[0]
		var pk_id: StringName = pk.item_id
		pk._on_body_entered(player)
		_check(_bag_count(pk_id) >= 1, "픽업 접촉 → 가방: %s" % pk_id)

	# ── 14. 탁본 완료 경로 (rubbing_completed + 가방)
	if spots.size() == 1:
		var spot: Variant = spots[0]
		_check(spot.fragment_id == &"fragment_water", "잔류물 조각 id == fragment_water")
		spot._complete()
		_check(_rubbing_completed_id == &"fragment_water", "rubbing_completed(fragment_water) 발신")
		_check(_bag_count(&"fragment_water") == 1, "가방에 fragment_water 1개")

	# ── 15. 캐스트 슬롯 → cast_requested (null·손상 슬롯은 무시)
	var design := SampleDesigns.nova_fire()
	GameState.equip(0, design)
	var broken := SampleDesigns.aimed_lance_water()
	broken.durability = 0
	GameState.equip(1, broken)
	GameState.equip(2, null)
	var casts_before: int = _cast_count
	_check(player.try_cast(0), "슬롯 1 캐스트 요청 성공")
	_check(_cast_seen == design and _cast_count == casts_before + 1, "cast_requested(장착 도안) 수신")
	_check(not player.try_cast(1), "손상 도안 슬롯: 조용히 무시")
	_check(not player.try_cast(2), "빈 슬롯: 조용히 무시")
	_check(_cast_count == casts_before + 1, "무시된 슬롯은 cast_requested 미발신")

	# ── 16. 출구 게이트 → extraction_success → 가방이 창고로
	var gate: Variant = ExitGateScript.new()
	gate.position = Vector2(-600, 0)
	add_child(gate)
	gate._on_body_entered(player)
	_check(_extraction_seen, "게이트 진입 → extraction_success 발신")
	_check(GameState.get_count(&"fragment_water") >= 1, "귀환 확정: 창고에 fragment_water")
	_check(GameState.bag.is_empty(), "귀환 후 가방 비움")

	# ── 17. 플레이어 피격·사망 → player_died + bag_lost → 가방 손실
	player.take_damage(5.0)
	_check(_player_damaged_seen, "player_damaged 발신")
	GameState.add_to_bag(&"mat_vine")
	player._invuln_left = 0.0
	player.take_damage(9999.0)
	_check(player.is_dead == true, "플레이어 사망 상태")
	_check(_player_died_seen, "player_died 발신")
	_check(_bag_lost_seen, "bag_lost 발신")
	_check(GameState.bag.is_empty(), "사망 시 가방 손실")

	# ── 18. field.tscn 스모크 (프로토 맵 로드·스폰)
	player.queue_free()
	await get_tree().process_frame
	var enemies_before := get_tree().get_nodes_in_group("enemies").size()
	var field_scene: PackedScene = load("res://src/field/field.tscn")
	var field: Node2D = field_scene.instantiate()
	add_child(field)
	await get_tree().process_frame
	await get_tree().process_frame
	var enemies_after := get_tree().get_nodes_in_group("enemies").size()
	_check(enemies_after - enemies_before >= 12, "필드 맵: 적 12+ 스폰 (실측 +%d)" % (enemies_after - enemies_before))
	_check(get_tree().get_nodes_in_group("exit_gates").size() >= 1, "필드 맵: 출구 게이트 존재")
	_check(get_tree().get_nodes_in_group("gather_nodes").size() >= 5, "필드 맵: 채집 노드 5+")
	field.queue_free()

	_finish()

func _finish() -> void:
	print("=== test_field 완료: FAIL %d건 ===" % _fails)
	if _fails == 0:
		print("TEST_FIELD_OK")
	get_tree().quit(mini(_fails, 100))
