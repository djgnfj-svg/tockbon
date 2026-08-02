extends SceneTree
## 돌진 예고 범위 자동 검증 — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_charge_telegraph_auto.gd
## 🔴 헤드리스가 못 재는 것 = 「빨간가 · 눈에 띄나 · 피할 만한가」(tools/vfx_shot.gd -- charge와 F5 몫).
##  재는 것 = 「언제 뜨고 꺼지나」 · 「얼마나 크게 그려지나」 · 🔴 「그린 것 = 맞는 것인가」.
## 🔴 이 파일의 탐침은 인지 키를 하나도 안 준다 — 그게 계약이다(키가 없으면 정확히 옛 동작).
##  ⚠ 탐침에 인지 키를 넣지 마라 — 넣는 순간 하위호환을 재는 유일한 자리를 잃는다.
## 🔴 예고가 실제보다 크면 "빨간 데 안인데 안 맞았다", 작으면 "빨간 데 밖인데 맞았다" — 둘 다 예고가
##  없는 것보다 나쁘다. 그래서 [6]은 수치를 비교하지 않고 그려진 범위에서 좌표를 뽑아 실제로 맞아 본다.
## 🔴 공개 API로만 검증한다 — 내부 필드(_charge_state·_charge_band)는 리팩터 때 옮겨 다녀 계약이 아니다.
## 주의: -s 모드는 오토로드보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지. 첫 프레임 후 load()·/root 접근.

## ⚠ 시트는 살아 있는 PNG를 빌려 쓴다 — 재는 건 **행동**이지 그림이 아니다
##  (`test_enemy_ai_auto.PROBE_SPRITE`와 같은 관행).
const PROBE_SPRITE := "res://assets/sprites/enemies/hound.png"

var failures: int = 0
var _db = null
var _gs = null
var _enemy_scene = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		print("TEST_CHARGE_TELEGRAPH_TIMEOUT — 60초 초과")
		quit(1))
	await process_frame

	_db = root.get_node("/root/Db")
	_gs = root.get_node("/root/GameState")
	_enemy_scene = load("res://src/field/forest_enemy.tscn") as PackedScene

	# 🔴 `current_scene`을 세운다 — 여기선 적을 안 죽이지만, 죽는 경로가 그걸 본다(드롭·퍼프).
	#   세워 두지 않으면 뒤에 항목을 얹을 때 조용히 no-op이 되는 자리다.
	var container := Node2D.new()
	root.add_child(container)
	current_scene = container

	await _test_no_band_before_windup()
	await _test_band_matches_dash_numbers()
	await _test_band_clears_when_dash_starts()
	await _test_band_follows_data()
	await _test_band_ignores_body_size()
	await _test_drawn_is_hit()
	await _test_floor_layer_and_lifetime()

	if failures == 0:
		print("TEST_CHARGE_TELEGRAPH_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_CHARGE_TELEGRAPH_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 🔴 예고는 **윈드업에만** 있다 — 접근 중엔 없고, charge가 아닌 적은 **노드 자체가 없다**.
## 왜 둘을 같이 재나: 「늘 켜 두고 알파만 0으로」 같은 구현으로 물러나면 ⓐ만으로는 안 걸린다.
## ⓑ가 지연 생성 계약(`_gale_ring` 선례 — charge가 아닌 적은 만들지 않는다)을 잡는다.
func _test_no_band_before_windup() -> void:
	print("[1] 예고는 윈드업에만 — 접근 중 없음 · charge 아닌 적은 노드도 없음")
	var p: Dictionary = _charge_params()
	# aggro(400) 안 · charge_trigger(300) 밖 → 접근만 한다.
	var stub := _stub(Vector2(350.0, 0.0))
	var e = await _spawn(&"tel_probe")
	for i in 10:
		await physics_frame
	_check(not e.charge_band_visible(), "ⓐ 접근 중엔 예고가 안 뜬다")
	_check(e.charge_band_reach() == Vector2.ZERO, "ⓐ' 아직 범위 노드가 없다(지연 생성)")
	e.free()

	_inject(&"tel_chase", {"ai": "chase", "aggro_range": 400.0, "move_speed": 0.0})
	var c = await _spawn(&"tel_chase")
	for i in 10:
		await physics_frame
	_check(not c.charge_band_visible(), "ⓑ charge가 아닌 적은 예고가 없다")
	_check(c.charge_band_reach() == Vector2.ZERO, "ⓑ' charge가 아닌 적은 범위 노드를 안 만든다")
	c.free()
	_drop(&"tel_chase")
	stub.free()
	# p는 아래 항목들이 이어 쓴다 — 여기선 안 걷는다.
	_check(p.has("charge_speed"), "탐침 몸이 돌진 수치를 쥐고 있다")


## [2] 🔴🔴 그려진 범위 = **돌진의 실제 값에서 나온다**.
## 기하: 돌진 중 판정은 `_contact`가 **중심 거리 ≤ attack_range**로 재고 몸은 락 방향으로
## `charge_speed × dash_sec`를 미끄러진다 ⇒ **닿는 자리 = 그 선분을 반경 attack_range로 부풀린 캡슐**.
## ⚠ 기대값을 여기 **상수로 안 적는다** — `.tres`(주입한 params)에서 읽어 곱한다. 상수로 박으면
##  사용자가 돌진을 조일 때 그물이 **거짓 빨강**이 되고, 무엇보다 「파생」 계약을 안 재게 된다.
func _test_band_matches_dash_numbers() -> void:
	print("[2] 그려진 범위 = charge_speed×dash_sec 길이 · attack_range 반경")
	var p: Dictionary = _charge_params()
	var stub := _stub(Vector2(250.0, 0.0))
	var e = await _spawn(&"tel_probe")
	var ok := await _await_band(e, 30)
	_check(ok, "윈드업에 들어가면 예고가 뜬다")
	var reach: Vector2 = e.charge_band_reach()
	var want_len: float = float(p["charge_speed"]) * float(p["dash_sec"])
	var want_rad: float = float(p["attack_range"])
	_check(absf(reach.x - want_len) < 0.01,
		"길이가 charge_speed×dash_sec 그대로다 (데이터 %.1f / 화면 %.1f)" % [want_len, reach.x])
	_check(absf(reach.y - want_rad) < 0.01,
		"반경이 attack_range 그대로다 (데이터 %.1f / 화면 %.1f)" % [want_rad, reach.y])
	e.free()
	stub.free()


## [3] 🔴 돌진이 시작되면 **꺼진다** — 그리고 꺼진 그 순간 몸이 실제로 튀어나간다.
## ⚠ 「꺼졌다」만 재면 **아예 안 뜨는 버그도 통과**한다 → 뜬 것을 먼저 확인하고([2]와 같은 대기),
##  「꺼짐」과 「돌진」이 **같은 사건**임을 이동 거리로 묶는다(엉뚱한 이유로 꺼진 것과 구분).
## ⚠ 프레임 수를 안 박는다 — `windup_sec`을 조이면 상수는 즉시 거짓 빨강이 된다.
func _test_band_clears_when_dash_starts() -> void:
	print("[3] 돌진 시작 = 예고가 꺼진다 (그리고 몸이 튀어나간다)")
	var stub := _stub(Vector2(250.0, 0.0))
	var e = await _spawn(&"tel_probe")
	_check(await _await_band(e, 30), "먼저 예고가 떴다")
	var held: Vector2 = e.global_position
	var cleared := false
	for i in 180:
		await physics_frame
		if not e.charge_band_visible():
			cleared = true
			break
	_check(cleared, "윈드업이 끝나면 예고가 사라진다")
	for i in 8:
		await physics_frame
	_check(e.global_position.distance_to(held) > 20.0,
		"예고가 꺼진 그 순간이 돌진이다 (실제 %.1fpx 이동)" % e.global_position.distance_to(held))
	e.free()
	stub.free()


## [4] 🔴 **파생 검출** — 돌진 수치를 다르게 준 몸에서는 그려진 범위도 그만큼 달라진다.
## 이게 「값을 베끼지 마라」의 실제 검출자다: 그리는 쪽이 hound의 값을 상수로 들고 있으면
## 여기서 빨개진다(탐침 수치는 hound와 **일부러 하나도 안 겹친다**).
func _test_band_follows_data() -> void:
	print("[4] 파생 — 돌진 수치를 바꾸면 그려진 범위가 따라온다")
	var alt := _charge_params().duplicate(true)
	alt["charge_speed"] = 260.0
	alt["dash_sec"] = 0.35
	alt["attack_range"] = 33.0
	_inject(&"tel_probe_alt", alt)
	var stub := _stub(Vector2(250.0, 0.0))
	var e = await _spawn(&"tel_probe_alt")
	_check(await _await_band(e, 30), "탐침도 예고가 뜬다")
	var reach: Vector2 = e.charge_band_reach()
	_check(absf(reach.x - 260.0 * 0.35) < 0.01,
		"길이가 새 수치를 따라간다 (기대 %.1f / 화면 %.1f)" % [260.0 * 0.35, reach.x])
	_check(absf(reach.y - 33.0) < 0.01,
		"반경이 새 수치를 따라간다 (기대 33.0 / 화면 %.1f)" % reach.y)
	e.free()
	stub.free()
	_drop(&"tel_probe_alt")


## [5] 🔴 덩치가 예고를 안 부풀린다 — params.size(루트 scale) 계약.
## 예고는 적의 자식이라 그냥 두면 루트 scale을 그대로 타는데, 돌진 거리도 attack_range도 월드 px라
## 덩치와 무관하다 ⇒ 확대된 몸에서 범위만 같은 배로 그려진다(에러 0 · 화면만 거짓말). top_level로
## 막으면 그리기 순서까지 바뀌어 예고가 몸 위로 올라온다 — 그래서 역스케일을 직접 곱한다.
## 🔴 실데이터로 잰다 — hound_alpha가 지금 라이브에서 확대된 몸이다.
func _test_band_ignores_body_size() -> void:
	print("[5] 덩치(params.size)가 예고를 안 부풀린다 — hound_alpha 실측")
	var def = _db.get_enemy(&"hound_alpha")
	if def == null:
		_check(false, "hound_alpha를 Db가 로드했다")
		return
	var size := float(def.params.get("size", 1.0))
	_check(size > 1.01, "hound_alpha가 실제로 확대된 몸이다 (size %.2f — 1.0이면 아래가 자명 통과)" % size)
	var trig := float(def.params.get("charge_trigger_range", 160.0))
	var stub := _stub(Vector2(trig - 20.0, 0.0))
	var e = await _spawn(&"hound_alpha")
	# 🔴 실데이터 몸이라 예고 전에 PATROL→ALERT(alert_sec)→CHASE를 밟는다. 그래서 프레임 예산을
	#  데이터에서 파생시킨다 — 40으로 박아 두면 alert_sec을 그 위로 올리는 순간 거짓 빨강이 난다.
	# ⚠ 스텁이 +X에 있는 것이 전제다(태어날 때 보는 쪽이 오른쪽이라 turn_rate를 안 기다린다).
	#  스텁을 옮기거든 회전 시간도 예산에 더해라.
	var budget := 40 + int(ceil(float(def.params.get("alert_sec", 0.0))
		* float(Engine.physics_ticks_per_second)))
	_check(await _await_band(e, budget), "hound_alpha도 예고가 뜬다 (예산 %d프레임)" % budget)
	var reach: Vector2 = e.charge_band_reach()
	var want_len: float = float(def.params.get("charge_speed", 0.0)) * float(def.params.get("dash_sec", 0.0))
	var want_rad: float = float(def.params.get("attack_range", 0.0))
	_check(absf(reach.x - want_len) < 0.01,
		"🔴 길이가 size에 안 곱해진다 (데이터 %.1f / 화면 %.1f — %.1f이면 scale이 샜다)"
			% [want_len, reach.x, want_len * size])
	_check(absf(reach.y - want_rad) < 0.01,
		"🔴 반경이 size에 안 곱해진다 (데이터 %.1f / 화면 %.1f — %.1f이면 scale이 샜다)"
			% [want_rad, reach.y, want_rad * size])
	e.free()
	stub.free()


## [6] 🔴 그린 것 = 맞는 것 — 이 그물의 심장. 수치 대조 대신 그려진 범위에서 좌표를 뽑아 맞아 본다:
##   ⓐ 그린 폭 안 → 맞는다(예고가 실제보다 크면 빨강) ⓑ 폭 밖 → 안 맞는다(작으면 빨강) ⓒ 앞끝 밖 → 안 맞는다
## 🔴 방향 락은 윈드업 시작에 걸리므로 스텁을 락 뒤에 옮기면 「예고를 보고 걸어 피한다」와 같은 상황이 된다.
## ⚠ ⓒ의 여유(+24px)는 한 물리 프레임분 초과 주행을 덮는다 — 돌진은 그린 길이보다 최대 한 틱 더 간다.
##  여유를 그보다 좁히면 그물이 프레임률에 따라 흔들린다(값이 아니라 이유로 정한 여유다).
func _test_drawn_is_hit() -> void:
	print("[6] 🔴 그린 것 = 맞는 것 — 폭 안/밖 · 앞끝 밖")
	var reach := Vector2.ZERO
	for case in [&"in", &"out", &"far"]:
		var stub := _stub(Vector2(250.0, 0.0))   # 락 방향 = +X
		var e = await _spawn(&"tel_probe")
		if not await _await_band(e, 30):
			_check(false, "%s: 예고가 떴다" % case)
			e.free()
			stub.free()
			continue
		reach = e.charge_band_reach()
		# 🔴 좌표를 **그려진 범위에서** 뽑는다 — 여기서 params를 다시 읽으면 [2]의 사본이 된다.
		var mid := reach.x * 0.5
		match case:
			&"in":
				stub.global_position = Vector2(mid, reach.y - 6.0)
			&"out":
				stub.global_position = Vector2(mid, reach.y + 6.0)
			&"far":
				stub.global_position = Vector2(reach.x + reach.y + 24.0, 0.0)
		_gs.hp = 100.0
		# 돌진이 끝날 때까지 (윈드업 잔여 + dash). 프레임 수를 안 박고 「꺼진 뒤 넉넉히」로 센다.
		for i in 180:
			await physics_frame
			if not e.charge_band_visible():
				break
		for i in 45:
			await physics_frame
		var hurt: float = 100.0 - _gs.hp
		match case:
			&"in":
				_check(hurt > 0.0,
					"ⓐ 그린 폭 **안**(중심에서 %.1fpx)에 서 있으면 맞는다 (실제 피해 %.1f — 0이면 예고가 실제보다 크다)"
						% [reach.y - 6.0, hurt])
			&"out":
				_check(hurt == 0.0,
					"ⓑ 그린 폭 **밖**(중심에서 %.1fpx)으로 비키면 안 맞는다 (실제 피해 %.1f — >0이면 예고가 실제보다 작다)"
						% [reach.y + 6.0, hurt])
			&"far":
				_check(hurt == 0.0,
					"ⓒ 그린 앞끝 **밖**(%.1fpx)이면 안 맞는다 (실제 피해 %.1f)"
						% [reach.x + reach.y + 24.0, hurt])
		e.free()
		stub.free()
	_gs.hp = 100.0
	_drop(&"tel_probe")


## [7] 🔴 「바닥에」와 그 대가 — 그리기 순서 · 예고가 몸보다 오래 살지 않는다.
## ⓐ 바닥에 깔린다는 건 z가 아니라 트리 순서다 — Ground·적·플레이어가 전부 z 0이라 「Ground 위 ·
##   플레이어 아래」라는 z 값이 존재하지 않는다. 헤드리스가 픽셀은 못 봐도 이 순서는 잰다.
##   적은 런타임 add_child라 씬 자식인 Player보다 나중에 그려진다 → 안 옮기면 예고가 플레이어 위에 얹힌다.
## ⓑ 씬 소유로 옮긴 대가가 수명이다 — 안 지우면 주인 없는 붉은 띠가 바닥에 영영 남는다(가리는 것보다 나쁘다).
func _test_floor_layer_and_lifetime() -> void:
	print("[7] 🔴 바닥층 그리기 순서 · 예고가 몸보다 오래 안 산다")
	_charge_params()
	var scene: Node = current_scene
	# ⚠ 앞 항목들이 free한 예고는 `queue_free`라 **프레임 끝에야** 사라진다 — 가라앉히고 세지 않으면
	#  기준선이 1 어긋나 이 항목이 **틀린 이유로** 빨개진다(실제로 밟았다).
	await process_frame
	await process_frame
	var before: int = scene.get_child_count()
	# 🔴 스텁을 **씬 아래** 둔다 — 실무대의 `Player`와 같은 자리라야 순서 계약이 실제로 돈다.
	var stub := _stub(Vector2(250.0, 0.0), scene)
	var e = await _spawn(&"tel_probe")
	_check(await _await_band(e, 30), "예고가 떴다")
	_check(e.charge_band_order() >= 0, "예고가 트리에 있다 (인덱스 %d)" % e.charge_band_order())
	_check(e.charge_band_order() < stub.get_index(),
		"🔴 예고가 플레이어보다 **먼저** 그려진다 = 바닥에 깔린다 (예고 %d < 플레이어 %d)"
			% [e.charge_band_order(), stub.get_index()])
	_check(scene.get_child_count() == before + 2,
		"예고가 씬에 붙었다 (스텁+예고 — 씬 자식 %d, 기대 %d)" % [scene.get_child_count(), before + 2])
	# 윈드업 **도중에** 몸을 없앤다 — 예고가 떠 있는 그 순간이 남는 자리다.
	e.queue_free()
	await process_frame
	await process_frame
	_check(scene.get_child_count() == before + 1,
		"🔴 몸이 사라지면 예고도 같이 사라진다 (씬 자식 %d, 기대 %d — 많으면 붉은 띠가 남았다)"
			% [scene.get_child_count(), before + 1])
	stub.free()
	_drop(&"tel_probe")


# ── 헬퍼 ──

## 🔴 돌진 탐침 몸 — **hound의 수치를 하나도 안 베낀다**(그래야 [4]가 하드코딩을 잡는다).
##  • `move_speed 0` = 접근 중 안 움직인다 → [3]의 「튀어나갔다」가 돌진 때문임이 확실해진다
##  • `windup_sec 0.30` = 스텁을 옮길 여유는 있고 테스트는 짧게
##  • `attack_cooldown 5.0` = 돌진 한 번에 피해가 딱 한 번 (누적으로 [6]이 흐려지지 않게)
##  • `contact_damage 9.0` = 맞았나만 보면 되므로 값 자체는 뜻이 없다
func _charge_params() -> Dictionary:
	var p := {
		"ai": "charge",
		"aggro_range": 400.0,
		"attack_cooldown": 5.0,
		"attack_range": 40.0,
		"charge_speed": 200.0,
		"charge_trigger_range": 300.0,
		"contact_damage": 9.0,
		"dash_sec": 0.5,
		"move_speed": 0.0,
		"recover_sec": 0.2,
		"windup_sec": 0.30,
	}
	_inject(&"tel_probe", p)
	return p


## in-memory EnemyDef 주입 — 레지스트리가 평범한 Dictionary라 가능하다.
## ⚠ 같은 id로 두 번 부르면 덮어쓴다(멱등) — 항목들이 `tel_probe`를 이어 쓰는 자리.
func _inject(id: StringName, params: Dictionary) -> void:
	var def = (load("res://src/core/schemas/enemy_def.gd") as GDScript).new()
	def.id = id
	def.hp = 500.0          # 이 그물은 적을 안 죽인다 — 죽으면 예고를 못 잰다
	def.has_counter = false
	var p := {"sprite": PROBE_SPRITE}
	p.merge(params, true)
	def.params = p
	_db.enemies[id] = def


## 🔴 주입 제거 — 안 걷으면 뒤 테스트의 적 수가 는다(`Db.enemies`는 공유 레지스트리다).
func _drop(id: StringName) -> void:
	_db.enemies.erase(id)


## 「플레이어」 스텁 — 그룹 `"player"`가 적의 유일한 조준 경로다(`forest_enemy._player`).
## 🔴 Node2D 맨몸이라 `is_rolling`이 없다 = 늘 안 구른다 → 접촉 피해가 그대로 든다([6]의 전제).
## ⚠ `parent`는 [7]만 쓴다 — **그리기 순서**를 재려면 스텁이 실무대처럼 **씬 아래** 있어야 한다.
##  나머지 항목은 순서를 안 재므로 `root`에 둔다(예고가 어디에 붙든 크기·시점 판정은 같다).
func _stub(pos: Vector2, parent: Node = null) -> Node2D:
	var s := Node2D.new()
	s.add_to_group("player")
	(parent if parent != null else root).add_child(s)
	s.global_position = pos
	return s


## 적 하나를 원점에 스폰한다 — `enemy_id`는 **_ready 전에** 세워야 `_def`가 그 몸으로 잡힌다.
func _spawn(id):
	var e = _enemy_scene.instantiate()
	e.enemy_id = id
	root.add_child(e)
	e.global_position = Vector2.ZERO
	await process_frame
	await physics_frame
	return e


## 예고가 뜰 때까지 기다린다 (최대 `budget` 물리 프레임). 프레임 수를 계약으로 삼지 않으려는 형태다.
func _await_band(e, budget: int) -> bool:
	for i in budget:
		if e.charge_band_visible():
			return true
		await physics_frame
	return e.charge_band_visible()


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
