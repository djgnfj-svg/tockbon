extends Node2D
## 모듈 C 자동 검증 (DoD) — 헤드리스 실행 시 PASS/FAIL 로그 출력 후 자체 종료.
## 실행: Godot --headless --path . res://tests/test_field.tscn --quit-after 600
## take_hit 직접 호출(더미 대미지)로 약점 배율·상태이상·밤 강화·탁본·드롭 루프를 검증한다.

const Spawner := preload("res://src/field/enemy_spawner.gd")
const PlayerScript := preload("res://src/field/player.gd")
const ExitGateScript := preload("res://src/field/exit_gate.gd")
const GatherNodeScript := preload("res://src/field/gather_node.gd")

const EPS := 0.05
## 뷰포트 가로 (project.godot) — 밀림 거리가 화면을 넘으면 적이 사라진 것과 같다
const SCREEN_W := 640

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

# ── 룬 농도 축 실측 도구 (v1.7) ──────────────────────────────────────────
# 실제로 적에게 들어오는 status_power를 원장에서 되짚는다 —
# 모듈 B(spell_system.compute_status_power)와 같은 공식: status_power × 농도 × 순도.
func _power(rune: Enums.RuneType, fill: float, accuracy: float) -> float:
	var bal: BalanceData = GameState.balance
	var r: RuneDef = Db.get_rune(rune)
	if r == null:
		return 0.0
	return r.status_power \
		* lerpf(bal.rune_density_min, bal.rune_density_max, clampf(fill, 0.0, 1.0)) \
		* maxf(accuracy, bal.accuracy_floor)

## 추적 중 실측 이동속도 — 갑충(물의 지정 카운터)을 플레이어(원점) 추적 사거리 안에 세우고 1틱 굴린다
func _chase_speed(wet_power: float) -> float:
	var e: Variant = _spawn_enemy(&"beetle", Vector2(0, 100))
	if e == null:
		return -1.0
	if wet_power > 0.0:
		e.take_hit(0.0, -1, Enums.Status.WET, wet_power)
	e.simulate(0.1, false)
	var speed: float = (e.velocity as Vector2).length()
	e.queue_free()
	return speed

## 화상 2초 총딜 — 재생이 없는 갑충으로 (덩굴은 재생이 섞여 측정이 흐려진다)
func _burn_total(power: float) -> float:
	var e: Variant = _spawn_enemy(&"beetle", Vector2(0, 3000))   # 어그로 밖 → AI 이동 0
	if e == null:
		return -1.0
	e.take_hit(0.0, -1, Enums.Status.BURN, power)
	var hp0: float = e.hp
	e.simulate(1.0, false)
	e.simulate(1.0, false)
	var loss: float = hp0 - e.hp
	e.queue_free()
	return loss

## 넉백·흐름 실측 밀림 거리 — move_and_slide는 물리 틱 델타를 쓰므로 결정론적 측정이 안 된다.
## 대신 어그로 밖(AI 속도 0)에 세우고 velocity를 직접 적분한다 (= 실제로 이동할 거리).
func _push_distance(status: int, power: float) -> float:
	var e: Variant = _spawn_enemy(&"beetle", Vector2(0, 3000))
	if e == null:
		return -1.0
	e.take_hit(0.0, -1, status, power)
	var dt := 0.02
	var dist := 0.0
	for i in range(250):   # 5초 — 넉백 감쇠·흐름 지속 모두 소진
		e.simulate(dt, false)
		dist += (e.velocity as Vector2).length() * dt
	e.queue_free()
	return dist

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

	# ── 9b. 룬 농도 축 (v1.7) — status_power가 상태이상 세기를 정한다 (TECH_SPEC §4.0)
	#     원장(data/runes + balance)에서 실제로 들어올 power를 되짚어 넣는다. 매직넘버 금지.
	print("--- 룬 농도 축: 실효 power = RuneDef.status_power × 농도(0.5~1.8) × 순도(0.6~1.0)")

	# WET — 둔화가 농도에 비례 (갑충으로 검증: 물이 지정 카운터)
	var wet_weak := _power(Enums.RuneType.WATER, 0.0, 0.6)     # 가장 옅게
	var wet_mid := _power(Enums.RuneType.WATER, 0.5, 1.0)      # 기준 (1.0배)
	var wet_strong := _power(Enums.RuneType.WATER, 1.0, 1.0)   # 가장 진하게
	var sp_dry := _chase_speed(0.0)
	var sp_weak := _chase_speed(wet_weak)
	var sp_mid := _chase_speed(wet_mid)
	var sp_strong := _chase_speed(wet_strong)
	var sp_absurd := _chase_speed(wet_strong * 100.0)   # 말도 안 되는 농도
	print("WET power %.3f/%.3f/%.3f → 이동속도 %.1f / %.1f / %.1f (안 젖음 %.1f)"
		% [wet_weak, wet_mid, wet_strong, sp_weak, sp_mid, sp_strong, sp_dry])
	_check(sp_weak < sp_dry - EPS, "젖음: 옅어도 안 젖음보다는 느리다 (%.1f < %.1f)" % [sp_weak, sp_dry])
	_check(sp_mid < sp_weak - EPS, "젖음 농도↑ → 더 느려진다: 옅음 %.1f > 기준 %.1f" % [sp_weak, sp_mid])
	_check(sp_strong < sp_mid - EPS, "젖음 농도↑ → 더 느려진다: 기준 %.1f > 진함 %.1f" % [sp_mid, sp_strong])
	_check(sp_absurd > 1.0, "둔화 바닥: 극단 농도(x100)에도 완전 정지 없음 (실측 %.1f)" % sp_absurd)
	_check(sp_absurd >= sp_strong - EPS, "둔화 바닥: 진함 이상은 더 느려지지 않는다")

	# 젖음 여부(bool) 판정은 농도와 무관 — 갑충 갑주 무력화가 안 깨진다
	var b_weak: Variant = _spawn_enemy(&"beetle", Vector2(1200, 200))
	b_weak.take_hit(0.0, -1, Enums.Status.WET, wet_weak)
	_check(b_weak.has_status(Enums.Status.WET), "옅은 젖음도 has_status(WET) == true")
	var bhp0: float = b_weak.hp
	b_weak.take_hit(10.0, -1, Enums.Status.NONE, 0.0)
	_check(absf((bhp0 - b_weak.hp) - 10.0) < EPS,
		"옅은 젖음도 갑주 무력화: 10 피해 온전 (실측 %.2f)" % (bhp0 - b_weak.hp))
	_check(b_weak.wet_slow() > 0.6, "옅은 젖음: 갑주는 열리되 둔화는 약하다 (배율 %.2f)" % b_weak.wet_slow())

	# BURN — 초당 화상 피해가 농도에 비례
	var burn_mid := _power(Enums.RuneType.FIRE, 0.5, 1.0)
	var burn_strong := _power(Enums.RuneType.FIRE, 1.0, 1.0)
	var burn_a := _burn_total(burn_mid)
	var burn_b := _burn_total(burn_strong)
	print("BURN power %.2f/%.2f → 2초 총딜 %.2f / %.2f" % [burn_mid, burn_strong, burn_a, burn_b])
	_check(absf(burn_a - burn_mid * 2.0) < EPS, "화상 2초 총딜 == power×2 (실측 %.2f)" % burn_a)
	_check(burn_b > burn_a + EPS, "화상 농도↑ → 총딜↑ (%.2f > %.2f)" % [burn_b, burn_a])

	# KNOCKBACK — 밀림 속도(power)에 비례 (v2.2: 룬은 넉백을 안 준다 — 화살표 충격파가 줄 자리.
	# 여기선 적 밀림 메커니즘 자체를 리터럴 power로 검증한다)
	var kb_mid := 90.0
	var kb_strong := 180.0
	var kb_a := _push_distance(Enums.Status.KNOCKBACK, kb_mid)
	var kb_b := _push_distance(Enums.Status.KNOCKBACK, kb_strong)
	print("KNOCKBACK power %.1f/%.1f → 넉백 거리 %.1fpx / %.1fpx" % [kb_mid, kb_strong, kb_a, kb_b])
	_check(kb_a > 1.0, "넉백 거리 > 0 (실측 %.1fpx)" % kb_a)
	_check(kb_b > kb_a + EPS, "넉백 농도↑ → 거리↑ (%.1f > %.1f)" % [kb_b, kb_a])
	# 단위 오류 재발 방지 — power는 밀림 속도(px/s)다. 배율로 착각해 곱하면 적이 맵 밖으로 날아간다
	_check(kb_b < SCREEN_W, "넉백 거리는 한 화면(%dpx) 안 (실측 %.1fpx)" % [SCREEN_W, kb_b])

	# FLOW — 밀림 거리가 농도에 비례
	var fl_mid := _power(Enums.RuneType.WIND, 0.5, 1.0)
	var fl_strong := _power(Enums.RuneType.WIND, 1.0, 1.0)
	var fl_a := _push_distance(Enums.Status.FLOW, fl_mid)
	var fl_b := _push_distance(Enums.Status.FLOW, fl_strong)
	print("FLOW power %.1f/%.1f → 밀림 거리 %.1fpx / %.1fpx" % [fl_mid, fl_strong, fl_a, fl_b])
	_check(fl_a > 1.0, "흐름 밀림 거리 > 0 (실측 %.1fpx)" % fl_a)
	_check(fl_b > fl_a + EPS, "흐름 농도↑ → 거리↑ (%.1f > %.1f)" % [fl_b, fl_a])
	_check(fl_b < SCREEN_W, "흐름 밀림 거리는 한 화면(%dpx) 안 (실측 %.1fpx)" % [SCREEN_W, fl_b])

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

	# ── 17. 중간보스(gale) — def·계약·약점 불 배율 (v2.2: 충격 룬 폐지 → 불로 이동)
	var gale_def: EnemyDef = Db.get_enemy(&"gale")
	_check(gale_def != null, "EnemyDef 로드: gale")
	if gale_def != null:
		_check(gale_def.is_elite, "gale.is_elite == true (탁본 경로 재사용)")
		_check(gale_def.has_counter and gale_def.counter_rune == Enums.RuneType.FIRE,
			"gale 약점 = 불△ (바람 룬 보스는 자기 룬이 약점일 수 없음)")
		_check(absf(gale_def.night_buff - 1.2) < EPS, "gale.night_buff == 1.2")
	var gale: Variant = _spawn_enemy(&"gale", Vector2(-1200, 800))
	if gale == null:
		_check(false, "보스 스폰 (EnemyDef 누락 — 이후 보스 검증 불가)")
	else:
		_check(gale.is_in_group("enemies"), "보스 그룹 'enemies'")
		_check(gale.collision_layer == 1 << 2, "보스 충돌 레이어 3")
		_check(gale.has_method("take_hit"), "보스 take_hit 메서드")
		_check(absf(gale.max_hp - 250.0) < EPS, "보스 HP 250")
		var g_hp0: float = gale.hp
		gale.take_hit(10.0, -1, Enums.Status.NONE, 0.0)
		var g_neutral: float = g_hp0 - gale.hp
		g_hp0 = gale.hp
		gale.take_hit(10.0, Enums.RuneType.FIRE, Enums.Status.NONE, 0.0)
		var g_fire: float = g_hp0 - gale.hp
		_check(absf(g_neutral - 10.0) < EPS, "보스 무속성 피해 10")
		_check(absf(g_fire - 10.0 * gale.weakness_mult) < EPS,
			"보스 불 약점 배율 x%.2f" % gale.weakness_mult)

		# ── 17b. 돌풍 밀치기 — 예열 후 반경 내 플레이어 밀어냄 + 피해, 이어서 회오리 3연발
		player.global_position = Vector2(-1200, 860)   # 보스에서 60px (돌풍 반경 90 안)
		player._invuln_left = 0.0
		GameState.reset_player_hp()
		var pos_before: Vector2 = player.global_position
		var php0: float = GameState.hp
		for i in range(60):
			gale.simulate(0.1, false)   # 6초 — 돌풍(예열 0.8s 포함) + 회오리 1회씩 발동
		var pushed: float = player.global_position.distance_to(pos_before)
		_check(pushed >= 50.0, "돌풍 밀치기: 플레이어 밀려남 (실측 %.0fpx)" % pushed)
		_check(absf((php0 - GameState.hp) - gale.gust_damage) < EPS,
			"돌풍 밀치기: 피해 %.0f 적용" % gale.gust_damage)
		var winds := get_tree().get_nodes_in_group("enemy_projectiles")
		_check(winds.size() >= 3, "회오리 투사체 3연발 스폰 (실측 %d)" % winds.size())
		if winds.size() > 0:
			_check(winds[0].collision_layer == 1 << 4, "회오리 레이어 5 (enemy_projectile)")
			_check(winds[0].collision_mask == 1 << 1, "회오리 마스크 2 (player)")
		for w: Node in winds:
			w.queue_free()

		# ── 17c. 2페이즈 전환 (체력 50% 이하 — 속도·주기 격화)
		var ms0: float = gale.move_speed
		var gp0: float = gale.gust_period
		_check(not gale.phase2_active, "50%% 초과 시 1페이즈 유지")
		gale.take_hit(100.0, -1, Enums.Status.NONE, 0.0)   # 224 → 124 (< 125)
		_check(gale.phase2_active, "체력 50%% 이하 → 2페이즈 전환")
		_check(absf(gale.move_speed - ms0 * gale.phase2_speed_mult) < EPS,
			"2페이즈: 이동 속도 x%.2f" % gale.phase2_speed_mult)
		_check(absf(gale.gust_period - gp0 * gale.phase2_rate_mult) < EPS,
			"2페이즈: 돌풍 주기 x%.2f" % gale.phase2_rate_mult)

		# ── 17d. 보스 사망 → fragment_wind 잔류물 + codex_unlocked + 드롭
		gale.take_hit(9999.0, -1, Enums.Status.NONE, 0.0)
		await get_tree().process_frame
		await get_tree().process_frame
		_check(_died_ids.has(&"gale"), "enemy_died 발신: gale")
		_check(_unlocked_ids.has(&"enemy_gale"), "첫 처치 → codex_unlocked(enemy_gale)")
		_check(GameState.is_unlocked(&"enemy_gale"), "GameState 도감 등록: enemy_gale")
		var wind_spot: Variant = null
		for s: Node in get_tree().get_nodes_in_group("rubbing_spots"):
			if s.get("fragment_id") == &"fragment_wind":
				wind_spot = s
		_check(wind_spot != null, "보스 사망 → fragment_wind 잔류물 스폰")
		var essence_count := 0
		var wind_direct_drop := false
		for pk: Node in get_tree().get_nodes_in_group("pickups"):
			if pk.get("item_id") == &"mat_mist_essence":
				essence_count += 1
			if pk.get("item_id") == &"fragment_wind":
				wind_direct_drop = true
		_check(essence_count >= 2 and essence_count <= 3,
			"보스 드롭: mat_mist_essence 2~3 (실측 %d)" % essence_count)
		_check(not wind_direct_drop, "fragment_wind는 픽업으로 직접 드롭되지 않음")
		if wind_spot != null:
			wind_spot._complete()
			_check(_rubbing_completed_id == &"fragment_wind", "rubbing_completed(fragment_wind) 발신")
			_check(_bag_count(&"fragment_wind") == 1, "가방에 fragment_wind 1개")

	# ── 18. 플레이어 피격·사망 → player_died + bag_lost → 가방 손실
	player.take_damage(5.0)
	_check(_player_damaged_seen, "player_damaged 발신")
	GameState.add_to_bag(&"mat_vine")
	player._invuln_left = 0.0
	player.take_damage(9999.0)
	_check(player.is_dead == true, "플레이어 사망 상태")
	_check(_player_died_seen, "player_died 발신")
	_check(_bag_lost_seen, "bag_lost 발신")
	_check(GameState.bag.is_empty(), "사망 시 가방 손실")

	# ── 19. field.tscn 스모크 (프로토 맵 로드·스폰·보스 존)
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
	var boss_in_field := false
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		var edef: EnemyDef = e.get("def")
		if edef != null and edef.id == &"gale" and (e as Node2D).global_position.y < 0.0:
			boss_in_field = true
	_check(boss_in_field, "필드 맵: 북쪽 보스 존(y<0)에 gale 스폰")

	# ── 19b. 지형 — 타일셋 임포트 시 TileMapLayer 4장, 아니면 폴백 Polygon2D
	if ResourceLoader.exists("res://assets/sprites/field/tileset_field.png"):
		for lname: String in ["Ground", "Walls", "Trunks", "Canopy"]:
			_check(field.find_children(lname, "TileMapLayer", true, false).size() == 1,
				"타일 지형: %s TileMapLayer 존재" % lname)
		var grounds := field.find_children("Ground", "TileMapLayer", true, false)
		if grounds.size() == 1:
			var used: int = (grounds[0] as TileMapLayer).get_used_cells().size()
			_check(used > 4000, "타일 지형: Ground used_cells > 4000 (실측 %d)" % used)
	else:
		_check(field.find_children("*", "Polygon2D", true, false).size() > 0,
			"폴백 지형: Polygon2D 존재")

	field.queue_free()

	_finish()

func _finish() -> void:
	print("=== test_field 완료: FAIL %d건 ===" % _fails)
	if _fails == 0:
		print("TEST_FIELD_OK")
	get_tree().quit(mini(_fails, 100))
