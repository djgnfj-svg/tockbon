extends SceneTree
## 몬스터 인지 자동 검증 (세105 N30 — 「나를 아직 못 본 짐승」) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_perception_auto.gd
## 전 항목 통과 시 "TEST_PERCEPTION_OK" 출력 후 종료 코드 0.
## 정본 = `docs/takbon-design/enemy_perception_design.md` (§10이 이 파일의 목차다).
##
## 🔴🔴 **왜 새 파일인가 — 이웃 그물은 전부 「이미 나를 본 적」을 잰다.**
##   `test_enemy_ai_auto [4]`(leash)·`test_charge_telegraph_auto`(예고)·`test_status_auto`가 재는 몸은
##   **인지 키가 0개**라 늘 CHASE다. **「아직 나를 못 본다」는 아무도 안 쟀다.**
##   짝 = `test_vision_auto`(내가 적을 못 본다 — 이 파일은 그 **거울**이다).
##
## 🔴🔴 **이 파일의 심장 둘**:
##   [1] **인지 키가 없는 몸은 정확히 옛 동작이다**(§7-b) — 설계가 *"하위호환은 이 파일이 세 번
##       명문화하고도 그물은 한 번도 안 세운 축"*이라 적었다. 인지 키 0개인 몸이 **그물 6파일에
##       주입**되므로, 폴백을 빠뜨리면 그것들이 **전부 굳거나 전부 걸어다닌다.**
##   [8] **`_contact`는 PATROL에서도 켠다**(§2-b C2) — 인지 상태가 **AI 갈래 호출을 안 끊는다**.
##       끊으면 잡몹 접촉 피해가 **무증상으로** 사라진다(그 채널을 재는 그물이 보스뿐이었다).
##
## 🔴 **공개 API로만** 검증한다 (takbon-verify §3): `percept_state()`·`look_dir()`·`patrol_home()`·
##   `hp()`·`GameState.hp`·`global_position`. 내부 필드(`_percept`·`_look_dir`)는 안 더듬는다.
##
## ⚠ **못 재는 것**(F5·사용자 손): 배회가 「살아있다」로 읽히나 · **큰읏과 짖음이 구별되나** ·
##   경계 한 박자가 「피할 수 있다」로 느껴지나 · 부채꼴 밖으로 도는 게 **가능하되 쉽지 않나** ·
##   늑대 다섯이 겹쳐 보이나. 인지 수치는 **전부 잠정**이라 값 자체를 안 박는다(관계식으로만 잰다).
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

## ⚠ 시트는 살아 있는 PNG를 빌려 쓴다 — 재는 건 **행동**이지 그림이 아니다
##  (`test_enemy_ai_auto.PROBE_SPRITE`와 같은 관행).
const PROBE_SPRITE := "res://assets/sprites/enemies/hound.png"

## 🔴 스토커(네임드) 목록 — **그물이 손으로 드는 기대치**다(`test_vision_auto.STALKERS`와 **같은 값**).
##  ⚠ `.tres`에 `stalks` 같은 플래그를 넣지 마라 — 코드가 안 읽는 데이터는 T3 거짓 손잡이가 된다.
const STALKERS: Array[StringName] = [&"hound_alpha"]

## 🔴 인지 키 전량 — [9]가 「보스에겐 하나도 없다」를 이 목록으로 스캔한다.
## ⚠ `sight_range`는 **일부러 빠져 있다**: 보스에게 그 값은 「시야」가 아니라 **leash 거리**다(§8-2).
const PERCEPT_KEYS: Array[String] = [
	"sight_angle", "sense_radius", "turn_rate", "patrol_radius", "patrol_speed",
	"alert_sec", "lose_sec", "search_sec", "ambush_mult", "alert_sfx", "chase_sfx",
]

## 🔴 배회 반경의 상한 = 프롭이 스폰 둘레를 비우는 거리(`boss_room.PROP_CLEAR_SPAWN`).
##  **리터럴을 박지 않고 그 파일에서 읽는다** — 방을 다시 깔면 기대치가 따라 움직인다(§8-5 ⓐ).
const ROOM_SCRIPT := "res://src/field/boss_room.gd"

## C4 검출자 — raw `score`를 쓰면 맨 진↔퍼펙트 반경비가 정확히 이 값이 된다(설계 §10 리뷰 3).
const RAW_SCORE_RATIO := 1.43

var failures: int = 0
var _db = null
var _gs = null
var _bus = null
var _enemy_scene = null
var _rp = null
var _P := {}          ## `Percept` enum (스크립트 상수 맵에서 읽는다 — 이름이 바뀌면 여기서 죽는다)
var _injected: Array[StringName] = []


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		print("TEST_PERCEPTION_TIMEOUT — 120초 초과")
		quit(1))
	await process_frame

	_db = root.get_node("/root/Db")
	_gs = root.get_node("/root/GameState")
	_bus = root.get_node("/root/EventBus")
	_enemy_scene = load("res://src/field/forest_enemy.tscn") as PackedScene
	_rp = load("res://src/core/ring_power.gd")
	# 🔴 enum을 **상수 맵에서** 읽는다 — 숫자를 베끼면 상태를 하나 끼워 넣는 날 그물이
	#  **엉뚱한 상태를 재면서 초록**이 된다(세85 「검증 도구가 거짓말한다」).
	var consts: Dictionary = (load("res://src/field/forest_enemy.gd") as GDScript).get_script_constant_map()
	_P = consts.get("Percept", {})

	var container := Node2D.new()
	root.add_child(container)
	current_scene = container

	_check(not _P.is_empty() and _P.has("PATROL") and _P.has("ALERT")
			and _P.has("CHASE") and _P.has("SEARCH"),
		"🔴 `Percept` 상태 넷을 스크립트에서 읽었다 (실제 %s — 비면 아래가 통째로 뜻을 잃는다)" % str(_P))

	await _test_legacy_body_is_unchanged()
	await _test_fan_splits_detection()
	await _test_near_circle_catches_behind()
	await _test_turn_rate_limits_head()
	await _test_sound_scales_with_power()
	await _test_ambush_multiplier()
	await _test_patrol_orbits_home()
	await _test_contact_runs_in_patrol()
	await _test_bosses_have_no_percept_keys()
	await _test_stalker_invariant()
	await _test_live_keys_are_not_inert()
	await _test_alert_beat()
	await _test_search_walks_to_last_seen()
	await _test_alert_sfx_wiring()

	_restore_all()
	if failures == 0:
		print("TEST_PERCEPTION_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_PERCEPTION_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 🔴🔴 **인지 키가 0개인 몸은 정확히 옛 동작이다** (설계 §7-b · C3 · 리뷰 1번).
##
## 왜 이게 심장인가: 인지 키를 안 주는 몸이 **그물 6파일에 주입**된다. 폴백을 빠뜨리면
##  ⓐ 부채꼴이 안 열려 **전부 굳거나**, ⓑ 배회가 켜져 **전부 걸어다닌다** — 어느 쪽이든
##  이 리포의 잡몹 그물이 통째로 흔들린다. 설계가 *"세 번 명문화하고도 그물은 한 번도 안 세웠다"*고
##  적은 그 자리다.
## 🔴 셋을 **같이** 잰다 — 하나만 재면 나머지 둘이 조용히 깨진다.
func _test_legacy_body_is_unchanged() -> void:
	print("[1] 🔴🔴 인지 키 0개 = 옛 동작 (등 뒤에서도 온다 · 배회 0 · 한 박자 0)")
	_inject(&"pc_legacy", {"aggro_range": 400.0, "move_speed": 60.0, "attack_range": 0.0})

	# ⓐ **등 뒤**(부채꼴 밖이 될 자리)에 둬도 온다 — 폴백 `sight_angle` 360°가 살아 있나.
	#  🔴 정확히 180°는 `Vector2.angle_to`(float32)와 `deg_to_rad(180)`(double)의 경계라
	#   구현이 실제로 밟은 자리다 — **일부러 그 자리에 둔다.**
	var stub := _stub(Vector2(-300.0, 0.0))
	var e = await _spawn(&"pc_legacy")
	await _frames(2)
	_check(e.percept_state() == _P["CHASE"],
		"ⓐ' 🔴 등 뒤(정확히 180°)에서도 **첫 두 틱 안에** 추격이다 = 한 박자 0 + 부채꼴 360° (실제 %d)"
			% e.percept_state())
	var p0: Vector2 = e.global_position
	await _frames(20)
	_check(e.global_position.distance_to(p0) > 10.0,
		"ⓐ 등 뒤에 서 있어도 다가온다 (실제 %.1fpx 이동 — 0이면 부채꼴 폴백이 죽었다)"
			% e.global_position.distance_to(p0))
	e.free()
	stub.free()

	# ⓑ **플레이어가 없으면 제자리다** — 배회 폴백 0. 켜져 있으면 주입 몸이 전부 걸어다닌다.
	var lone = await _spawn(&"pc_legacy")
	var q0: Vector2 = lone.global_position
	await _frames(60)
	_check(lone.global_position.distance_to(q0) < 0.01,
		"ⓑ 🔴 배회 키가 없으면 한 톨도 안 움직인다 (실제 %.3fpx — 움직이면 그물 6파일이 흔들린다)"
			% lone.global_position.distance_to(q0))
	_check(lone.percept_state() == _P["PATROL"],
		"ⓑ' 플레이어가 없으면 PATROL이다 (실제 %d)" % lone.percept_state())
	lone.free()
	_drop(&"pc_legacy")


## [2] 🔴🔴 **부채꼴** — 같은 거리·다른 각도에서 감지가 갈린다 (설계 §3).
## 🔴 거리를 **똑같이** 두는 것이 요점이다: 다르게 두면 사거리 게이트가 각도 대신 답을 내서
##  각도 판정을 통째로 `true`로 고정해도 초록이 된다.
## 🔴 뮤테이션 검출자: `sight_angle`을 360으로 → ⓑⓒ가 빨개진다.
func _test_fan_splits_detection() -> void:
	print("[2] 🔴 부채꼴 — 같은 거리 다른 각도로 감지가 갈린다")
	# `sense_radius 0` = 근접 원이 답을 대신 내지 않는다 · `move_speed 0` = 거리가 안 흔들린다
	# · `turn_rate 0`(무제한)이지만 PATROL에선 속도가 0이라 **보는 쪽이 안 돈다**(초기값 = 오른쪽).
	_inject(&"pc_fan", {
		"sight_range": 400.0, "sight_angle": 120.0, "sense_radius": 0.0,
		"move_speed": 0.0, "attack_range": 0.0,
	})
	var cases := {
		"ⓐ 정면": [Vector2(300.0, 0.0), true],
		"ⓑ 등 뒤": [Vector2(-300.0, 0.0), false],
		"ⓒ 옆 90°": [Vector2(0.0, 300.0), false],
	}
	for label: String in cases:
		var at: Vector2 = cases[label][0]
		var want: bool = cases[label][1]
		var stub := _stub(at)
		var e = await _spawn(&"pc_fan")
		await _frames(4)
		var chasing: bool = e.percept_state() == _P["CHASE"]
		_check(chasing == want,
			"%s(300px)에서 감지 %s (실제 %s — 셋이 다 같으면 각도 판정이 고정된 것이다)"
				% [label, "O" if want else "X", "O" if chasing else "X"])
		e.free()
		stub.free()
	_drop(&"pc_fan")


## [3] 🔴 **근접 원** — 등 뒤라도 코앞이면 들킨다 (냄새·기척).
## 없으면 **「등 뒤에 붙어 따라다니기」가 최적 전략**이 된다(설계 §3). [2]ⓑ와 같은 자리를 쓰되
## 반경만 켜서 **그 키 하나가 답을 뒤집는지**를 잰다.
func _test_near_circle_catches_behind() -> void:
	print("[3] 🔴 근접 원 — 등 뒤라도 반경 안이면 들킨다")
	_inject(&"pc_sense", {
		"sight_range": 400.0, "sight_angle": 120.0, "sense_radius": 150.0,
		"move_speed": 0.0, "attack_range": 0.0,
	})
	var stub := _stub(Vector2(-100.0, 0.0))   # 등 뒤 · 반경(150) 안
	var e = await _spawn(&"pc_sense")
	await _frames(4)
	_check(e.percept_state() == _P["CHASE"],
		"ⓐ 등 뒤 100px(반경 150 안)이면 들킨다 (실제 %d)" % e.percept_state())
	e.free()
	stub.free()

	var far_stub := _stub(Vector2(-300.0, 0.0))  # 등 뒤 · 반경 밖 · 부채꼴 밖
	var f = await _spawn(&"pc_sense")
	await _frames(4)
	_check(f.percept_state() == _P["PATROL"],
		"ⓑ 등 뒤 300px(반경 밖)이면 못 본다 (실제 %d — 여기가 CHASE면 반경이 무한이다)"
			% f.percept_state())
	f.free()
	far_stub.free()
	_drop(&"pc_sense")


## [4] 🔴🔴 **「보는 쪽」은 `turn_rate`만큼만 돈다** (설계 §4 — 안 ⓐ 전체가 이 한 값에 얹혀 있다).
##
## 이게 없으면 적이 **즉시 뒤를 돌아봐서** 「돌아가기」가 통째로 성립하지 않는다.
## 🔴 **각도 값 자체를 안 박는다** — 잰 회전량이 `turn_rate × 경과시간`을 **안 넘는가**와
##  「아직 목표에 못 닿았나」 둘만 본다(잠정값을 조여도 거짓 빨강이 안 난다).
## 🔴 뮤테이션 검출자: `turn_rate`를 0(무제한)으로 → ⓑ가 빨개진다.
func _test_turn_rate_limits_head() -> void:
	print("[4] 🔴 보는 쪽 — turn_rate만큼만 돈다")
	var rate := 60.0
	_inject(&"pc_turn", {
		"sight_range": 5000.0, "sight_angle": 360.0, "sense_radius": 0.0,
		"turn_rate": rate, "move_speed": 30.0, "attack_range": 0.0,
	})
	var stub := _stub(Vector2(400.0, 0.0))    # 처음엔 정면(초기 보는 쪽 = 오른쪽)
	var e = await _spawn(&"pc_turn")
	await _frames(10)
	var start: Vector2 = e.look_dir()
	_check(absf(start.angle()) < 0.2,
		"ⓐ 먼저 오른쪽을 보고 있다 (실제 %.2f rad — 전제)" % start.angle())

	# 🔴 정확히 180°를 피한다 — 부호가 어느 쪽으로 갈지 정해지지 않아 회전량이 흔들린다.
	stub.global_position = Vector2(-400.0, 60.0)
	var ticks := 20
	await _frames(ticks)
	var turned := absf(start.angle_to(e.look_dir()))
	var budget := deg_to_rad(rate) * float(ticks) / float(Engine.physics_ticks_per_second)
	_check(turned <= budget + 0.02,
		"ⓑ 🔴 %d틱 동안 turn_rate 예산(%.2f rad)을 안 넘겼다 (실제 %.2f — 넘으면 즉시 회전이다)"
			% [ticks, budget, turned])
	_check(turned > 0.05,
		"ⓑ' 그렇다고 안 돌지도 않았다 (실제 %.2f rad — 0이면 「보는 쪽」이 통째로 죽었다)" % turned)
	e.free()
	stub.free()
	_drop(&"pc_turn")


## [5] 🔴🔴 **마법 소리 = 위력** (설계 §5 · ⓔ) + **`quality_t`를 지난다**(리뷰 3 · C4).
##
## 🔴 반경 값을 박지 않는다 — **같은 자리의 적이 점수에 따라 반응이 갈리는가**로 잰다.
## 🔴🔴 **C4 검출자**: 맨 진(0.70)↔퍼펙트(1.0)의 반경비가 raw `score`면 정확히 **1.43배**다.
##  그래서 프로브를 `최소반경 × 1.43`보다 **살짝 밖**에 세운다 — raw로 되돌리면 퍼펙트로도
##  안 닿아 빨개진다. 지금(`quality_t`)은 240→700 = **2.92배**라 닿는다.
## 🔴 **빈 사전 가드**도 같이 잰다 — `test_audio_auto`가 `emit({}, …)`로 쏜다(설계 §5).
func _test_sound_scales_with_power() -> void:
	print("[5] 🔴 마법 소리 = 위력 (quality_t 경유 · 빈 사전 가드)")
	var bal = _gs.balance
	var lo_r: float = bal.percept_sound_radius_min_px
	var hi_r: float = bal.percept_sound_radius_max_px
	_check(hi_r > lo_r * RAW_SCORE_RATIO,
		"🔴 반경비가 raw score의 %.2f배보다 크다 (실제 %.2f배 — 아니면 「조용히 한 방」이 성립 안 한다)"
			% [RAW_SCORE_RATIO, hi_r / maxf(lo_r, 0.001)])

	# `sight_range 1` = 「인지가 있는 몸」이되 **눈으로는 아무것도 못 본다**(소리만 잰다).
	_inject(&"pc_ear", {
		"sight_range": 1.0, "sight_angle": 30.0, "sense_radius": 0.0,
		"alert_sec": 5.0, "search_sec": 5.0, "move_speed": 0.0, "attack_range": 0.0,
	})
	var plain: float = _rp.assembled_score(0, 1)
	# ⓐ 최소 반경 안 · ⓑ raw 1.43배 **밖**(= C4 검출자) · ⓒ 최대 반경 밖
	var spots := {
		"ⓐ 아주 가까이": lo_r * 0.5,
		"ⓑ raw 한계 밖": lo_r * (RAW_SCORE_RATIO + 0.1),
		"ⓒ 최대 반경 밖": hi_r + 200.0,
	}
	for label: String in spots:
		var d: float = spots[label]
		# 맨 진(quality_t = 0) → 최소 반경만
		var quiet = await _spawn(&"pc_ear", Vector2(d, 0.0))
		_bus.ring_cast_requested.emit({"score": plain}, Vector2.ZERO, Vector2.RIGHT)
		await _frames(2)
		var quiet_woke: bool = quiet.percept_state() != _P["PATROL"]
		quiet.free()
		# 퍼펙트(quality_t = 1) → 최대 반경
		var loud = await _spawn(&"pc_ear", Vector2(d, 0.0))
		_bus.ring_cast_requested.emit({"score": 1.0}, Vector2.ZERO, Vector2.RIGHT)
		await _frames(2)
		var loud_woke: bool = loud.percept_state() != _P["PATROL"]
		loud.free()
		match label:
			"ⓐ 아주 가까이":
				_check(quiet_woke and loud_woke,
					"%s(%.0fpx) — 맨 진에도 퍼펙트에도 깬다 (실제 %s/%s)" % [label, d, quiet_woke, loud_woke])
			"ⓑ raw 한계 밖":
				_check(not quiet_woke and loud_woke,
					"%s(%.0fpx) 🔴 맨 진엔 안 깨고 퍼펙트엔 깬다 (실제 %s/%s — 둘 다 X면 raw score로 되돌아간 것)"
						% [label, d, quiet_woke, loud_woke])
			_:
				_check(not quiet_woke and not loud_woke,
					"%s(%.0fpx) — 둘 다 안 깬다 (실제 %s/%s — 깨면 반경이 무한이다)"
						% [label, d, quiet_woke, loud_woke])

	# 🔴 빈 사전 — `test_audio_auto`가 실제로 쏘는 모양. 터지면 안 되고, 기준선(맨 진)으로 흘러야 한다.
	var bare = await _spawn(&"pc_ear", Vector2(lo_r * 0.5, 0.0))
	_bus.ring_cast_requested.emit({}, Vector2.ZERO, Vector2.RIGHT)
	await _frames(2)
	_check(bare.percept_state() != _P["PATROL"],
		"🔴 빈 사전(`emit({}, …)`)에도 기준선으로 흘러 깬다 (실제 %d — SCRIPT ERROR grep도 같이 봐라)"
			% bare.percept_state())
	bare.free()
	_drop(&"pc_ear")


## [6] 🔴 **기습 배수** — 못 본 적을 치면 더 아프다 (설계 §6 · ⓕ).
## 🔴 **같은 damage를 두 몸에 넣어 결과가 갈리는가**로 잰다 — 한 몸만 재면 배수 1.0으로 되돌려도
##  「hp가 줄었다」는 그대로라 검출력이 0이다.
## 🔴 뮤테이션 검출자: `ambush_mult`를 1.0으로 → **이 항목만** 빨개져야 한다(격리 확인).
func _test_ambush_multiplier() -> void:
	print("[6] 🔴 기습 — 못 본 적이 더 아프다")
	var mult := 2.0
	_inject(&"pc_ambush", {
		"sight_range": 300.0, "sight_angle": 120.0, "sense_radius": 0.0,
		"ambush_mult": mult, "move_speed": 0.0, "attack_range": 0.0,
	})
	var stub := _stub(Vector2(200.0, 0.0))
	var seen_e = await _spawn(&"pc_ambush", Vector2.ZERO)          # 정면 200px → 본다
	var blind_e = await _spawn(&"pc_ambush", Vector2(2000.0, 0.0)) # 사거리 밖 → 못 본다
	await _frames(4)
	_check(seen_e.percept_state() == _P["CHASE"] and blind_e.percept_state() == _P["PATROL"],
		"전제: 한쪽은 추격 · 한쪽은 순찰이다 (실제 %d / %d)"
			% [seen_e.percept_state(), blind_e.percept_state()])
	var hp0: float = seen_e.hp()
	seen_e.take_hit(10.0, 0, 0, 0.0)
	blind_e.take_hit(10.0, 0, 0, 0.0)
	var dealt_seen: float = hp0 - seen_e.hp()
	var dealt_blind: float = hp0 - blind_e.hp()
	_check(dealt_seen > 0.0 and is_equal_approx(dealt_blind, dealt_seen * mult),
		"🔴 못 본 적이 %.1f배로 맞는다 (본 적 %.1f / 못 본 적 %.1f — 같으면 배수가 안 걸렸다)"
			% [mult, dealt_seen, dealt_blind])
	seen_e.free()
	blind_e.free()
	stub.free()
	_drop(&"pc_ambush")


## [7] 🔴🔴 **배회** — 자기 자리(`_home`) 둘레를 돌고 그 반경 밖으로 안 나간다.
##
## ⓐ 🔴🔴 **`_home`은 스폰 자리다**(설계 §9-b · M6) — `_ready`에서 잡으면 조용히 **원점**이 된다.
##   라이브는 `add_child` **앞**에 좌표를 주지만 **그물 넷은 정반대로 뒤에 준다** ⇒ 여기서도
##   **뒤에 준다**(이 리포 그물 관용구가 그쪽이라 실전이 곧 재현이다).
## ⓑ 실제로 걷는다 · ⓒ `patrol_radius` 밖으로 안 나간다(§8-3 — 구역 배치가 흐트러지면
##   「깊이 들어간다」가 사라진다) · ⓓ 🔴 **자리마다 위상이 다르다**(§8-5 ⓑ — 같으면 늑대 다섯이
##   한 몸처럼 겹친다).
## ⓔ 🔴 데이터 계약: 모든 적의 `patrol_radius ≤ boss_room.PROP_CLEAR_SPAWN`(넘으면 나무를 뚫는다).
func _test_patrol_orbits_home() -> void:
	print("[7] 🔴 배회 — _home은 스폰 자리 · 반경 안 · 자리마다 위상이 다르다")
	var radius := 80.0
	_inject(&"pc_patrol", {
		"sight_range": 300.0, "sight_angle": 60.0, "sense_radius": 0.0,
		"patrol_radius": radius, "patrol_speed": 60.0, "move_speed": 0.0, "attack_range": 0.0,
	})
	var home_a := Vector2(500.0, -200.0)
	var home_b := Vector2(-350.0, 640.0)
	var a = await _spawn(&"pc_patrol", home_a)
	var b = await _spawn(&"pc_patrol", home_b)
	await _frames(2)
	_check(a.patrol_home().distance_to(home_a) < 0.01,
		"ⓐ 🔴🔴 _home이 스폰 자리다 (기대 %s / 실제 %s — 원점이면 `_ready`에서 잡은 것이고 적이 원점으로 끌려간다)"
			% [home_a, a.patrol_home()])

	var moved := 0.0
	var farthest := 0.0
	for i in 200:
		await physics_frame
		moved = maxf(moved, a.global_position.distance_to(home_a))
		farthest = maxf(farthest, a.global_position.distance_to(home_a))
	_check(moved > radius * 0.5,
		"ⓑ 실제로 배회한다 (자기 자리에서 최대 %.1fpx — 0이면 배회가 안 돈다)" % moved)
	_check(farthest <= radius + 2.0,
		"ⓒ 🔴 배회 반경(%.0f) 밖으로 안 나간다 (실제 최대 %.1fpx — 넘으면 구역 배치가 흐트러진다)"
			% [radius, farthest])
	_check(a.look_dir().distance_to(b.look_dir()) > 0.05,
		"ⓓ 🔴 자리가 다르면 배회 위상도 다르다 (a %s / b %s — 같으면 무리가 한 몸처럼 겹친다)"
			% [a.look_dir(), b.look_dir()])
	a.free()
	b.free()
	_drop(&"pc_patrol")

	# ⓔ 데이터 계약 — 상한을 **리터럴로 안 박고** 방 스크립트에서 읽는다.
	var clear: float = (load(ROOM_SCRIPT) as GDScript).get_script_constant_map().get("PROP_CLEAR_SPAWN", 0.0)
	_check(clear > 0.0, "boss_room.PROP_CLEAR_SPAWN을 읽었다 (실제 %.0f — 0이면 아래가 자명 통과다)" % clear)
	var judged := 0
	for id: StringName in _db.enemies.keys():
		var def = _db.enemies[id]
		if def == null:
			continue
		var r := float(def.params.get("patrol_radius", 0.0))
		if r <= 0.0:
			continue
		judged += 1
		_check(r <= clear,
			"ⓔ 🔴 %s의 patrol_radius %.0f ≤ 프롭 여백 %.0f (넘으면 배회 중에 나무를 뚫는다)"
				% [id, r, clear])
	_check(judged >= 1, "배회를 켠 적이 하나 이상이다 (실제 %d — 0이면 ⓔ가 자명 통과다)" % judged)


## [8] 🔴🔴 **`_contact`는 PATROL에서도 켠다** — 인지가 **AI 갈래 호출을 안 끊는다**(설계 §2-b C2).
##
## `takbon-rules` §5의 세88 계약(*"거리 게이트는 이동 대입만 감싼다 — `return` 금지"*)과 **같은 형태의
## 사고**다. 끊으면 잡몹 접촉 피해가 **무증상으로 사라진다**(그 채널을 재는 그물은 보스뿐이었다).
## 그리고 「늑대 몸에 부딪혔는데 안 아프다」는 세계관으로도 안 읽힌다.
## 🔴 뮤테이션 검출자: `_contact`를 CHASE 안으로 옮긴다 → 이 항목이 빨개져야 한다.
func _test_contact_runs_in_patrol() -> void:
	print("[8] 🔴🔴 _contact는 PATROL에서도 켠다 (인지가 갈래를 안 끊는다)")
	_inject(&"pc_contact", {
		"sight_range": 400.0, "sight_angle": 40.0, "sense_radius": 0.0,
		"attack_range": 60.0, "attack_cooldown": 5.0, "contact_damage": 7.0, "move_speed": 0.0,
	})
	var stub := _stub(Vector2(-30.0, 0.0))   # 🔴 **등 뒤 30px** — 부채꼴(40°) 밖 · 접촉 사거리(60) 안
	# ⚠ **기준 hp를 스폰 「앞」에 세운다** — `_spawn`이 이미 물리 프레임을 한 번 흘리므로 첫 접촉이
	#  그 안에서 터지고, 뒤에 세우면 `attack_cooldown`(5s) 때문에 **두 번째가 영영 안 와 거짓 빨강**이 난다.
	_gs.hp = 100.0
	var e = await _spawn(&"pc_contact")
	await _frames(6)
	_check(e.percept_state() == _P["PATROL"],
		"전제: 아직 나를 못 봤다 (실제 %d — CHASE면 이 항목이 아무것도 안 잰다)" % e.percept_state())
	_check(_gs.hp < 100.0,
		"🔴🔴 못 본 적도 부딪히면 아프다 (hp %.1f — 100이면 인지가 갈래 호출을 끊었다)" % _gs.hp)
	_gs.hp = 100.0
	e.free()
	stub.free()
	_drop(&"pc_contact")


## [9] 🔴 **보스 셋에 인지 키가 없다** (설계 §8-2) — 정적 스캔.
##
## 🔴 **코드가 못 가르는 계약이라 유일하게 실행 가능한 형태가 이것이다**: `forest_enemy`는 자기가
##  보스인지 모르고(`params.ai` 하나만 안다 · `slime_elite`엔 그 키조차 없다) `boss_enemy_id`로
##  런타임 분기를 만들 수 없다. ⇒ **「보스 `.tres`에 인지 키를 주지 않는다」가 계약**이고,
##  §7-b 덕분에 그게 자동으로 옛 동작이 된다.
## 🔴 **적 id를 손으로 나열하지 마라** — `data/chapters/*.tres`의 `boss_enemy_id`를 전부 모은다
##  (챕터4가 생기는 날 자동으로 걸린다 · `test_vision_auto [3]`과 같은 관행).
## ⚠ `sight_range`는 예외다 — 보스에게 그 값은 **leash 거리**다(`PERCEPT_KEYS` 주석).
func _test_bosses_have_no_percept_keys() -> void:
	print("[9] 🔴 보스는 인지 설계 밖 — .tres에 인지 키가 하나도 없다")
	var bosses := {}
	for ch in _db.chapters.values():
		if ch != null and ch.boss_enemy_id != &"":
			bosses[ch.boss_enemy_id] = true
	_check(bosses.size() >= 2,
		"챕터에서 보스 id를 모았다 (실제 %d종 — 0~1이면 아래가 자명 통과다)" % bosses.size())
	for id: StringName in bosses:
		var def = _db.get_enemy(id)
		if def == null:
			_check(false, "보스 %s가 Db에 실재한다" % id)
			continue
		for key: String in PERCEPT_KEYS:
			_check(not def.params.has(key),
				"🔴 보스 %s에 인지 키 '%s'가 없다 (주면 무대에 오른 적이 「등 뒤로 돌면 안 쫓는다」가 된다)"
					% [id, key])


## [10] 🔴🔴 **`sight_range > vision_near_radius`인 종은 `STALKERS`에 있어야 한다** (설계 §8-1-b).
##
## N27의 보장은 *"주변시 ≥ 감지거리 ⇒ 나를 쫓기 시작한 적은 반드시 보인다"*다. 부채꼴이 주변시를
## 넘으면 **늑대가 「나에게 안 보이는 채로」 CHASE에 들어간다** = 안 보이는 데서 맞는다.
## 사용자 확정 ⓖ(*"멀리서 알아채는 몬스터도 있을듯함"*)가 그걸 **금지가 아니라 등재 의무**로 갈랐다.
## 🔴 **리터럴 220을 박지 마라** — balance에서 읽는다. ⚠ 보스는 `always_visible`이라 건너뛴다.
func _test_stalker_invariant() -> void:
	print("[10] 🔴 멀리 보는 종은 STALKERS에 등재돼 있다 (§8-1-b 불변식)")
	var near: float = _gs.balance.vision_near_radius
	var judged := 0
	var ids: Array = _db.enemies.keys()
	ids.sort_custom(func(a, b) -> bool: return String(a) < String(b))
	for id: StringName in ids:
		var def = _db.enemies[id]
		if def == null or bool(def.params.get("always_visible", false)):
			continue
		var sight := float(def.params.get("sight_range", def.params.get("aggro_range", 0.0)))
		if sight <= 0.0:
			continue
		judged += 1
		if sight > near:
			_check(STALKERS.has(id),
				"🔴 %s는 sight_range %.0f > 주변시 %.0f라 STALKERS에 등재돼 있다 (미등재면 안 보이는 데서 물린다)"
					% [id, sight, near])
		else:
			_check(not STALKERS.has(id),
				"🔴 바탕 종 %s는 sight_range %.0f ≤ 주변시 %.0f = 「쫓으면 보인다」 보장 안이다 (STALKERS라면 그 값이 정체성을 잃은 것)"
					% [id, sight, near])
	_check(judged >= 2,
		"불변식을 실제로 잰 적이 둘 이상이다 (실제 %d — 0이면 위가 자명 통과다)" % judged)


## [11] 🔴 **한 박자(ALERT)** — 발견은 즉시 추격이 아니다 (설계 ⓒ).
## ⓐ 감지 직후엔 ALERT이고 `alert_sec` 뒤에 CHASE다 · ⓑ **그 사이 벗어나면 없던 일**이다
##  (= 「아슬아슬하게 피했다」가 성립하는 유일한 자리).
## 🔴 뮤테이션 검출자: `alert_sec`을 0으로 → ⓐ가 빨개진다.
func _test_alert_beat() -> void:
	print("[11] 🔴 경계 한 박자 — 즉시 추격이 아니다 · 벗어나면 없던 일")
	var beat := 0.5
	_inject(&"pc_beat", {
		"sight_range": 400.0, "sight_angle": 120.0, "sense_radius": 0.0,
		"alert_sec": beat, "move_speed": 0.0, "attack_range": 0.0,
	})
	var stub := _stub(Vector2(300.0, 0.0))
	var e = await _spawn(&"pc_beat")
	await _frames(3)
	_check(e.percept_state() == _P["ALERT"],
		"ⓐ 감지 직후는 **경계**다 (실제 %d — CHASE면 한 박자가 통째로 없다)" % e.percept_state())
	await _frames(int(ceil(beat * float(Engine.physics_ticks_per_second))) + 4)
	_check(e.percept_state() == _P["CHASE"],
		"ⓐ' 한 박자를 버티면 추격이다 (실제 %d)" % e.percept_state())
	e.free()

	# ⓑ 경계 도중에 벗어나면 없던 일 — 「아슬아슬하게 피했다」
	var f = await _spawn(&"pc_beat")
	await _frames(3)
	_check(f.percept_state() == _P["ALERT"], "ⓑ 전제: 다시 경계에 들었다 (실제 %d)" % f.percept_state())
	stub.global_position = Vector2(3000.0, 0.0)
	await _frames(3)
	_check(f.percept_state() == _P["PATROL"],
		"ⓑ' 🔴 한 박자 안에 벗어나면 **없던 일**이다 (실제 %d — CHASE면 벗어나기가 뜻을 잃는다)"
			% f.percept_state())
	f.free()
	stub.free()
	_drop(&"pc_beat")


## [12] 🔴 **SEARCH — 놓치면 마지막 본 자리로 가 본다** (설계 §2).
## SEARCH가 「따돌렸다」를 만든다: 즉시 복귀면 도망이 너무 쉽고, 안 놓치면 세88의 그 고장
## (*"전부 남쪽 입구로 모인다"*)이 돌아온다.
## 🔴 **플레이어를 통째로 없앤다** — `player == null` 경로에서도 인지가 돌아야 한다(설계 V12).
func _test_search_walks_to_last_seen() -> void:
	print("[12] 🔴 수색 — 놓치면 마지막 본 자리로 걸어간다")
	_inject(&"pc_search", {
		"sight_range": 600.0, "sight_angle": 120.0, "sense_radius": 0.0,
		"lose_sec": 0.1, "search_sec": 5.0, "move_speed": 80.0, "attack_range": 0.0,
	})
	var seen_at := Vector2(400.0, 0.0)
	var stub := _stub(seen_at)
	var e = await _spawn(&"pc_search")
	await _frames(4)
	_check(e.percept_state() == _P["CHASE"], "전제: 먼저 봤다 (실제 %d)" % e.percept_state())
	stub.free()                                   # 🔴 플레이어가 통째로 사라진다
	await _frames(12)
	_check(e.percept_state() == _P["SEARCH"],
		"ⓐ 놓치면 **수색**에 든다 (실제 %d — PATROL이면 즉시 복귀라 도망이 너무 쉽다)" % e.percept_state())
	var d0: float = e.global_position.distance_to(seen_at)
	await _frames(30)
	_check(e.global_position.distance_to(seen_at) < d0 - 10.0,
		"ⓑ 마지막 본 자리로 다가간다 (%.1f → %.1fpx — 안 줄면 수색이 서 있기만 하는 것)"
			% [d0, e.global_position.distance_to(seen_at)])
	e.free()
	_drop(&"pc_search")


## [13] 🔴 **경계·발견 소리 배선** (설계 §8-6 · 리드 판단 M8).
##
## 🔴🔴 **헤드리스는 「소리가 난다」를 못 잡는다**(오디오 드라이버가 없다) — 잴 수 있는 건 **배선**뿐이다:
##  ⓐ 짖으면 몸에 `AudioStreamPlayer2D`가 붙나(**비위치 풀이 아니라** 거리 감쇠를 얻는 그 노드인가) ·
##  ⓑ 🔴 **`bus == &"SFX"`인가**(`Audio.stream_of` 머리말의 「부르는 쪽 의무」 — 안 걸면 볼륨을
##    버스로 가르는 날 **늑대 소리만 안 따라온다**) · ⓒ 스트림이 실제로 `Audio` 캐시에서 왔나.
## 🔴 **소리 id도 `.tres`가 쥔다** — 키가 없는 몸(보스·주입 탐침)은 **노드 자체가 없어야** 한다.
##  안 그러면 뱀 보스가 늑대처럼 짖는다.
## ⚠ **「큰읏과 짖음이 구별되나」는 F5 몫이다** — 여기선 「둘이 서로 다른 스트림인가」까지만 잰다.
func _test_alert_sfx_wiring() -> void:
	print("[13] 🔴 경계·발견 소리 배선 (거리 감쇠 노드 · SFX 버스 · id는 .tres가 쥔다)")
	_inject(&"pc_sfx", {
		"sight_range": 400.0, "sight_angle": 120.0, "sense_radius": 0.0,
		"alert_sec": 0.3, "move_speed": 0.0, "attack_range": 0.0,
		"alert_sfx": "growl", "chase_sfx": "howl",
	})
	_inject(&"pc_mute", {
		"sight_range": 400.0, "sight_angle": 120.0, "sense_radius": 0.0,
		"alert_sec": 0.3, "move_speed": 0.0, "attack_range": 0.0,
	})
	var stub := _stub(Vector2(200.0, 0.0))
	var loud = await _spawn(&"pc_sfx")
	var mute = await _spawn(&"pc_mute")
	await _frames(3)
	var alert_stream: AudioStream = _sfx_stream(loud)
	_check(alert_stream != null, "ⓐ 경계에 들면 소리 노드가 붙는다 (없으면 ⓓ 「유일한 통보」가 사라진다)")
	_check(_sfx_stream(mute) == null,
		"ⓑ 🔴 소리 id가 없는 몸엔 노드 자체가 없다 (보스가 늑대처럼 짖지 않는 이유)")
	var player := loud.get_node_or_null(^"AudioStreamPlayer2D") as AudioStreamPlayer2D
	if player == null:
		for c in loud.get_children():
			if c is AudioStreamPlayer2D:
				player = c
	_check(player != null and player.bus == &"SFX",
		"ⓒ 🔴 버스가 SFX다 (실제 %s — Master면 볼륨을 가르는 날 늑대 소리만 안 따라온다)"
			% (player.bus if player != null else "노드 없음"))
	await _frames(int(ceil(0.3 * float(Engine.physics_ticks_per_second))) + 4)
	var chase_stream: AudioStream = _sfx_stream(loud)
	_check(loud.percept_state() == _P["CHASE"], "전제: 추격에 들었다 (실제 %d)" % loud.percept_state())
	_check(chase_stream != null and chase_stream != alert_stream,
		"ⓓ 🔴 경계와 발견이 **서로 다른 소리**다 (같으면 ⓒ·ⓓ가 만든 2단계 긴장이 무너진다)")
	loud.free()
	mute.free()
	stub.free()
	_drop(&"pc_sfx")
	_drop(&"pc_mute")


## 몸에 붙은 소리 노드의 스트림 — 없으면 null. ⚠ 노드 **이름**을 계약으로 삼지 않는다(타입으로 찾는다).
func _sfx_stream(e) -> AudioStream:
	for c in e.get_children():
		if c is AudioStreamPlayer2D:
			return (c as AudioStreamPlayer2D).stream
	return null


# ── 헬퍼 ──

## in-memory EnemyDef 주입 (세61 Db 주입 선례 — 레지스트리가 평범한 Dictionary다).
## 🔴 `hp 500` = 이 그물은 적을 안 죽인다(죽으면 상태를 못 잰다).
func _inject(id: StringName, params: Dictionary) -> void:
	var def = (load("res://src/core/schemas/enemy_def.gd") as GDScript).new()
	def.id = id
	def.hp = 500.0
	def.has_counter = false
	var p := {"sprite": PROBE_SPRITE}
	p.merge(params, true)
	def.params = p
	_db.enemies[id] = def
	if not _injected.has(id):
		_injected.append(id)


## 🔴 주입 제거 — 안 걷으면 뒤 테스트의 적 수가 는다(`Db.enemies`는 공유 레지스트리다).
func _drop(id: StringName) -> void:
	_db.enemies.erase(id)
	_injected.erase(id)


func _restore_all() -> void:
	for id: StringName in _injected.duplicate():
		_db.enemies.erase(id)
	_injected.clear()


## 「플레이어」 스텁 — 그룹 `"player"`가 적의 유일한 조준 경로다(`forest_enemy._player`).
## 🔴 Node2D 맨몸이라 `vision_dir()`이 없다 = 시야는 fail-open(적이 늘 보인다) — 이 파일은
##  **적의 인지**를 재지 내 시야를 안 잰다. 둘은 무관한 판정이다(설계 §8-7).
func _stub(pos: Vector2) -> Node2D:
	var s := Node2D.new()
	s.add_to_group("player")
	root.add_child(s)
	s.global_position = pos
	return s


## 적 하나를 스폰한다 — `enemy_id`는 **_ready 전에** 세워야 `_def`가 그 몸으로 잡힌다.
## 🔴🔴 **좌표는 `add_child` 「뒤」에 준다 — 일부러다**(설계 §9-b M6). 라이브는 앞에 주지만
##  이 리포의 그물 넷이 뒤에 주므로, `_home`을 `_ready`에서 잡는 구현이면 [7]ⓐ가 여기서 빨개진다.
func _spawn(id, at: Vector2 = Vector2.ZERO):
	var e = _enemy_scene.instantiate()
	e.enemy_id = id
	root.add_child(e)
	e.global_position = at
	await process_frame
	await physics_frame
	return e


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)


## [14] 🔴🔴 **실데이터 — 준 키가 「폴백과 같은 값」이면 안 준 것이다** (세105 리드 추가).
##
## 🔴 **왜 필요한가 — 리드가 뮤테이션으로 구멍을 실측했다.** 설계 §10이 지정한 뮤테이션
##  *"`ambush_mult` → 1.0 : 기습 검사만 빨개져야 한다"*를 **`data/enemies/hound.tres`에 걸었더니
##  전 스위트 48/48이 그대로 그린이었다**(검출 0). [6]이 `_inject`로 **기계**만 재기 때문이다 —
##  주입 몸의 값은 그물이 정하므로 **실데이터가 무엇을 들고 있든 상관이 없다.**
##
## 🔴 **이 리포가 반복해 밟은 병이다**: `test_mob_roll_auto` 머리말이 *"둘이 있어야 한다 —
##  기계만 재면 데이터가 비어도 그린이고, 데이터만 재면 코드가 굴림을 안 해도 그린이다"*라고
##  적어 뒀고, `test_chapter_auto`는 세88에 기대치를 **데이터에서 파생**시켜 *"표를 비워도 통과"*했다.
##  [6]~[8]이 「기계」쪽이고 이 항목이 그 **짝**이다.
##
## 🔴 **불변식 = §7-b 폴백표를 뒤집은 것.** 그 표는 *"키가 없으면 정확히 옛 동작"*을 규정한다
##  ⇒ **키가 있는데 값이 폴백과 같으면, 손잡이는 있고 효과는 없다 = T3 「거짓 손잡이」**다.
##  실제 사고 형태: F5로 조이다 `ambush_mult`를 1.0으로 되돌리면 **설계 ⓕ(「뒤로 돌기가 전술이 된다」)가
##  통째로 죽는데 에러도 빨간불도 없다.** `turn_rate`를 크게 키우면 「돌아가기」가 사라진다(§4의 심장).
##
## ⚠ **모든 종이 모든 키를 가질 필요는 없다** — 없으면 건너뛴다(§7-b가 부재를 정당한 상태로 뒀다).
##  재는 건 *"있으면 살아 있나"*뿐이다. 🔴 **값을 박지 않는다** — 폴백과의 **대소 관계**만 본다.
##  그래야 F5 튜닝에 거짓 빨강이 안 난다(세79 교훈).
func _test_live_keys_are_not_inert() -> void:
	print("[14] 🔴 실데이터 — 준 인지 키가 폴백값 그대로면 거짓 손잡이다")

	# {키: [폴백값, 비교, 왜 그 폴백이 「옛 동작」인가]} — 설계 §7-b 표 그대로다.
	var rules := {
		"sight_angle":   [360.0, "lt", "360°면 부채꼴이 무의미 = 늘 본다"],
		"turn_rate":     [0.0,   "gt", "0이면 고개가 안 돈다 · ∞(키 부재)면 즉시 회전"],
		"patrol_radius": [0.0,   "gt", "0이면 배회 안 함"],
		"patrol_speed":  [0.0,   "gt", "0이면 배회 안 함"],
		"alert_sec":     [0.0,   "gt", "0이면 한 박자 없음 = 즉시 CHASE"],
		"lose_sec":      [0.0,   "gt", "0이면 SEARCH 없음"],
		"search_sec":    [0.0,   "gt", "0이면 SEARCH 없음"],
		"sense_radius":  [0.0,   "gt", "0이면 등 뒤 코앞도 못 느낀다"],
		"ambush_mult":   [1.0,   "gt", "1.0은 곱셈 항등 = 기습이 없는 것과 같다"],
	}

	var ids: Array = _db.enemies.keys()
	ids.sort_custom(func(a, b) -> bool: return String(a) < String(b))

	var percept_species := 0
	var judged := 0
	for id: StringName in ids:
		var def = _db.enemies[id]
		if def == null:
			continue
		# 인지 종 = PERCEPT_KEYS를 하나라도 든 종. 🔴 id를 손으로 나열하지 않는다 —
		# 새 몹이 들어오면 자동으로 이 그물에 든다([9]·[10]과 같은 관행).
		var is_percept := false
		for key: String in PERCEPT_KEYS:
			if def.params.has(key):
				is_percept = true
				break
		if not is_percept:
			continue
		percept_species += 1

		for key: String in rules:
			if not def.params.has(key):
				continue          # 부재는 정당하다 (§7-b) — 재지 않는다
			var fallback: float = rules[key][0]
			var cmp: String = rules[key][1]
			var why: String = rules[key][2]
			var v := float(def.params[key])
			judged += 1
			var alive := v > fallback if cmp == "gt" else v < fallback
			_check(alive,
				"🔴 %s의 '%s' = %.2f 가 폴백(%.2f)보다 %s (%s)"
					% [id, key, v, fallback, "크다" if cmp == "gt" else "작다", why])

	# 🔴 자명 통과 방지 — 위 루프가 실제로 돌았나. 0이면 「인지 종이 하나도 없다」는 뜻이고
	#  그건 이 그물이 아니라 **데이터가 죽은 것**이다.
	_check(percept_species >= 2,
		"인지 키를 든 종이 둘 이상이다 (실제 %d종 — 0이면 위가 통째로 자명 통과다)" % percept_species)
	_check(judged >= 8,
		"실제로 잰 키가 여덟 이상이다 (실제 %d개 — 적으면 데이터가 거의 비어 있다)" % judged)
