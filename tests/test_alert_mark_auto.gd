extends SceneTree
## 🔴🔴 발견 느낌표(!) 자동 검증 (세104) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_alert_mark_auto.gd
## 전 항목 통과 시 "TEST_ALERT_MARK_OK" 출력 후 종료 코드 0.
##
## 한 줄: **내 시야 밖의 적이 나를 발견하는 그 순간, 그 자리에 느낌표가 잠깐 뜬다.**
## 사용자 요청 = *"지금 내 시야에 없을 때 나를 발견하면 느낌표가 뜨게"*.
##
## 🔴🔴 **이 기능이 「있으면 좋은 것」이 아닌 이유**(리드 실측): `vision_design`은 기척을 **이미 있는
##  것**(돌진 예고·돌풍 링)으로 때운다고 적어 뒀는데, 예고가 켜지는 거리(120·160)가 주변시(220)보다
##  **한참 안쪽**이라 「몸은 없고 예고만」이 **구조적으로 안 나온다.** ⇒ 지금 시야 밖 적은 **완전히
##  투명**하고 이 느낌표가 **유일한 기척**이다. 그래서 그물도 그만큼 촘촘해야 한다.
##
## 🔴 **[3]이 이 기능의 유일한 진짜 검출자다.** 느낌표를 `_visual`의 **자식**으로 달면
##  시야 알파(`_refresh_alpha`)에 물려 **몸이 안 보일 때 느낌표도 같이 사라지는데**,
##  나머지 항목은 전부 그린이다(뜨긴 뜬다 — 화면에만 안 보인다). `test_vision_auto [6]`이
##  돌풍 링에 대해 같은 자리를 지킨다.
##
## 🔴 **공개 API로만** 검증한다 (takbon-verify §3): `alert_mark_visible()` · `is_seen()` ·
##  씬 노드 `Visual`/`AlertMark`(= 구조 계약) · `modulate`(화면 그 자체). 내부 필드는 안 더듬는다.
##
## ⚠ **헤드리스가 못 재는 것**: 느낌표가 **눈에 띄나**(노랑이 낮 풀밭에서 읽히나) · 0.90초가
##  적당한가 · 도형 느낌표가 도트 게임에서 어색하지 않나. 전부 **F5·MCP 스샷·사용자 손**이다.
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.


## 🔴 **시야를 가진 플레이어 스텁** — `vision_dir()` 하나만 들고 조준을 **정확히** 지정한다.
##  맨몸 Node2D를 쓰면 시야가 fail-open(늘 보인다)이라 **느낌표가 한 번도 안 떠서 전 항목이
##  자명 통과**가 된다. (`test_vision_auto.VisionStub`과 같은 수법 — 파일 하나로 닫으려고 사본이다.)
class VisionStub extends Node2D:
	var aim_dir: Vector2 = Vector2.RIGHT
	func vision_dir() -> Vector2:
		return aim_dir


## ⚠ 시트는 살아 있는 PNG를 빌려 쓴다 — 재는 건 **신호**지 그림이 아니다.
const PROBE_SPRITE := "res://assets/sprites/enemies/hound.png"
const PROBE := &"alert_probe"

## 시야 페이드(0.18s ≈ 11 물리 프레임)가 닫힐 때까지 — 넉넉히.
const SETTLE_FRAMES := 25
## 느낌표 총 수명 0.90s ≈ 54 물리 프레임 — 확실히 넘긴다(값을 조여도 안 흔들리게 여유를 크게).
const MARK_GONE_FRAMES := 90

var failures: int = 0
var _gs = null
var _db = null
var _enemy_scene = null
var _room = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		print("TEST_ALERT_MARK_TIMEOUT — 90초 초과")
		quit(1))
	await process_frame

	_gs = root.get_node("/root/GameState")
	_db = root.get_node("/root/Db")
	_enemy_scene = load("res://src/field/forest_enemy.tscn") as PackedScene
	_room = Node2D.new()
	root.add_child(_room)
	current_scene = _room
	_inject_probe()

	await _test_only_when_unseen()
	await _test_edge_not_every_frame()
	await _test_not_bound_to_vision_alpha()
	await _test_dies_with_the_body()
	await _test_player_gone_resets_pursuit()

	if failures == 0:
		print("TEST_ALERT_MARK_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_ALERT_MARK_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 🔴🔴 **양방향 — 시야 밖이면 뜨고 시야 안이면 안 뜬다.**
##
## 🔴 ⓑ만 재면 「아예 안 뜨는 구현」이 통과하고, ⓐ만 재면 「늘 뜨는 구현」이 통과한다. 둘이 짝이다.
## 🔴🔴 **ⓒ가 ⓑ의 자명 통과를 막는다**: ⓑ에서 안 뜬 이유가 *"보였으니까"*인지 *"기계가 죽어서"*인지
##  ⓑ 혼자서는 못 가른다. **같은 몸**을 aggro 밖으로 뺐다가 **안 보이는 자리**로 다시 들이면
##  그때는 떠야 한다 — 그게 「보였기 때문」이었음의 증명이다.
func _test_only_when_unseen() -> void:
	print("[1] 🔴 양방향 — 시야 밖이면 뜨고 · 시야 안이면 안 뜬다")
	# ⓐ 안 보이는 자리에서 발견당한다.
	var stub := _stub(_blind_pos())
	var e = await _spawn()
	await _frames(3)
	_check(not e.is_seen(), "ⓐ' 적이 안 보이는 상태다 (전제)")
	_check(e.alert_mark_visible(),
		"ⓐ 🔴 시야 밖에서 나를 발견하면 느낌표가 뜬다 (안 뜨면 이 기능이 통째로 없는 것)")
	e.free()
	stub.free()

	# ⓑ 보이는 자리에서 발견당한다 — 안 떠야 한다.
	var stub2 := _stub(_seen_pos())
	var e2 = await _spawn()
	await _frames(3)
	_check(e2.is_seen(), "ⓑ' 적이 보이는 상태다 (전제)")
	_check(not e2.alert_mark_visible(),
		"ⓑ 🔴 보이는 적은 느낌표를 안 띄운다 (뜨면 화면이 시끄럽고 「안 보이는 것을 알린다」는 뜻이 사라진다)")

	# ⓒ 🔴 같은 몸을 aggro 밖으로 뺐다가 **안 보이는 자리**로 들인다 → 뜬다.
	stub2.global_position = _far_pos()
	await _frames(5)
	stub2.global_position = _blind_pos()
	await _frames(3)
	_check(e2.alert_mark_visible(),
		"ⓒ 🔴🔴 같은 몸이 안 보이는 자리에서는 뜬다 = ⓑ가 「기계가 죽어서」가 아니라 「보였기 때문」이다")
	e2.free()
	stub2.free()


## [2] 🔴 **전이(edge)에서 한 번만** — 추격이 유지되는 동안 다시 안 뜬다.
##
## 매 프레임 조건으로 띄우면 추격 내내 느낌표가 **계속 떠 있어** 통보가 아니라 장식이 된다.
## 🔴 ⓒ(추격이 풀렸다 다시 걸리면 또 뜬다)가 **「한 번 뜨고 영영 안 뜨는 구현」과 가른다** —
##  없으면 「최초 1회 플래그」로 짜도 ⓐⓑ가 그린이다.
func _test_edge_not_every_frame() -> void:
	print("[2] 🔴 전이에서 한 번만 — 추격이 유지되는 동안 재발 없음")
	var stub := _stub(_blind_pos())
	var e = await _spawn()
	await _frames(3)
	_check(e.alert_mark_visible(), "ⓐ 먼저 떴다 (전제)")

	# 수명이 다할 때까지 — 그동안 추격 조건은 **계속 참**이다(스텁이 안 움직인다).
	await _frames(MARK_GONE_FRAMES)
	_check(not e.alert_mark_visible(),
		"ⓑ 수명이 다하면 사라진다 (실제 %s — 안 사라지면 영구 장식이다)" % e.alert_mark_visible())
	await _frames(30)
	_check(not e.alert_mark_visible(),
		"ⓑ' 🔴 추격이 유지되는 동안 **다시 안 뜬다** (매 프레임 조건으로 짰으면 여기가 빨개진다)")

	# ⓒ 추격이 풀렸다 다시 걸리면 또 뜬다 — 「최초 1회」 구현과 가른다.
	stub.global_position = _far_pos()
	await _frames(5)
	stub.global_position = _blind_pos()
	await _frames(3)
	_check(e.alert_mark_visible(),
		"ⓒ 🔴 추격이 풀렸다 다시 걸리면 또 뜬다 (안 뜨면 「최초 1회」로 짠 것)")
	e.free()
	stub.free()


## [3] 🔴🔴🔴 **느낌표가 시야 알파에 안 물린다 — 이 기능의 유일한 진짜 검출자.**
##
## 느낌표를 `_visual`의 **자식**으로 다는 것이 가장 자연스러운 손이다(머리 위니까). 그 순간
## `_refresh_alpha`가 `_visual.modulate.a`에 0을 찍어 **느낌표도 같이 투명해진다** — 그런데
## `visible`은 true고 `modulate.a`도 1.0이라 **다른 항목이 전부 그린이다.** 화면에만 아무것도 없다.
##
## 🔴 **누적 알파를 계산한다** — Godot의 `modulate`는 렌더 때 부모 것과 곱해지지 자식의 프로퍼티를
##  바꾸지 않는다. 자기 값만 읽으면 이 사고를 **못 잡는다**(`test_vision_auto [6]`의 그 교훈).
## 🔴 ⓒ(부모가 적 루트다)는 **구조를 직접** 짚는다 — 누적 알파가 우연히 살아도 계약은 부모다.
## ⓓ는 **좌우 반전 작업과의 접점**: 루트를 거울질하는 구현으로 물러나면 여기가 빨개진다.
func _test_not_bound_to_vision_alpha() -> void:
	print("[3] 🔴🔴 느낌표가 시야 알파에 안 물린다 (Visual의 **형제**여야 한다)")
	var stub := _stub(_blind_pos())
	var e = await _spawn()
	await _frames(SETTLE_FRAMES)   # 시야 페이드가 닫힐 때까지 — 느낌표는 아직 만빛 구간이다

	var vis := e.get_node_or_null(^"Visual") as CanvasItem
	var mark := _mark_of(e) as CanvasItem
	_check(vis != null, "Visual 노드를 찾았다")
	_check(mark != null, "AlertMark 노드를 찾았다 (이름이 바뀌면 이 그물이 죽는다)")
	if vis == null or mark == null:
		e.free()
		stub.free()
		return

	_check(is_zero_approx(vis.modulate.a),
		"ⓐ 몸은 완전히 사라졌다 (실제 %.3f — 전제)" % vis.modulate.a)
	_check(e.alert_mark_visible(), "ⓑ' 그 순간 느낌표는 떠 있다 (전제)")
	var eff := _effective_alpha(mark, e)
	_check(eff > 0.5,
		"ⓑ 🔴🔴 느낌표의 **누적** 알파가 살아 있다 (실제 %.3f — 0이면 `_visual` 자식으로 달아 같이 죽은 것)"
			% eff)
	_check(mark.get_parent() == e,
		"ⓒ 🔴 느낌표의 부모가 **적 루트**다 = `Visual`의 형제 (실제 %s)"
			% (mark.get_parent().name if mark.get_parent() != null else "없음"))
	_check((mark as Node2D).global_scale.x > 0.0,
		"ⓓ 느낌표가 거울질되지 않았다 (global_scale.x %.3f — 반전을 루트 scale로 짜면 음수가 된다)"
			% (mark as Node2D).global_scale.x)
	e.free()
	stub.free()


## [4] 수명 — **몸이 죽으면 느낌표도 같이 죽는다.**
## 적의 **자식**이라 공짜로 성립한다. `_charge_band`는 씬 소유로 옮기며 이 공짜를 잃고
## *"안 지우면 주인 없는 붉은 띠가 바닥에 영영 남는다"*는 대가를 치렀다 — 느낌표를 그쪽으로
## 옮기려는 다음 사람에게 **이 줄이 대가를 상기시킨다.**
func _test_dies_with_the_body() -> void:
	print("[4] 수명 — 몸이 죽으면 느낌표도 같이 사라진다 (적의 자식이라 공짜)")
	var stub := _stub(_blind_pos())
	var e = await _spawn()
	await _frames(3)
	var mark: Node = _mark_of(e)
	_check(mark != null and e.alert_mark_visible(), "느낌표가 떠 있다 (전제)")
	# 🔴 **전제를 free 「전」에 잡아 둔다** — Godot 4에서 **free된 객체를 담은 변수는 `!= null`이
	#  거짓**이 된다(Variant가 죽은 포인터를 null로 푼다). `mark != null and not is_instance_valid(mark)`
	#  로 적으면 **성공했을 때 앞 절이 거짓**이라 그물이 자기를 무너뜨린다(실제로 밟았다).
	var was_valid := is_instance_valid(mark)
	e.free()
	_check(was_valid and not is_instance_valid(mark),
		"🔴 몸을 없애면 느낌표도 같이 사라진다 (남으면 주인 없는 기호가 화면에 뜬다)")
	stub.free()


## [5] 🔴 **플레이어가 사라지면 추격이 풀린다** — 판정이 조기 return **앞**에 있어야만 성립한다.
##
## `_physics_process`는 `player == null`이면 곧장 돌아간다. 발견 판정을 그 **뒤**에 두면
## 추격 플래그가 **참인 채로 굳어**, 다시 만났을 때 전이가 없어 **느낌표가 영영 안 뜬다**(에러 0).
## 시야(`_update_vision`)가 정확히 같은 이유로 같은 자리에 있다(설계 V12 · `test_vision_auto [11]`).
func _test_player_gone_resets_pursuit() -> void:
	print("[5] 🔴 플레이어가 사라지면 추격이 풀린다 (판정은 조기 return 앞이다)")
	var stub := _stub(_blind_pos())
	var e = await _spawn()
	await _frames(3)
	_check(e.alert_mark_visible(), "먼저 떴다 (전제)")
	await _frames(MARK_GONE_FRAMES)
	_check(not e.alert_mark_visible(), "수명이 다해 사라졌다 (전제)")

	stub.free()                    # 🔴 플레이어가 통째로 사라진다 = `_player()`가 null
	await _frames(5)
	var stub2 := _stub(_blind_pos())   # 다시 나타난다 = **새 발견**이어야 한다
	await _frames(3)
	_check(e.alert_mark_visible(),
		"🔴🔴 플레이어가 사라졌다 다시 나타나면 새 발견으로 다시 뜬다 (안 뜨면 판정이 조기 return 뒤에 있어 굳은 것)")
	e.free()
	stub2.free()


# ── 헬퍼 ──

## 🔴 탐침 몸 — `move_speed 0`이라 **거리가 안 흔들린다**(움직이면 시야 판정이 경계에서 튄다).
## 🔴🔴 **`aggro_range`를 balance에서 파생시킨다** — 「안 보이는 자리」가 주변시·부채꼴 사거리에서
##  나오므로, 리터럴을 박으면 사용자가 시야를 조이는 날 **탐침이 안 보이는 자리 밖**이 되어
##  추격 자체가 안 걸리고 전 항목이 **거짓 빨강**이 된다.
## ⚠ `attack_range 0` = 접촉 판정에 절대 안 든다 → `GameState.hp`를 안 건드린다(다른 그물과 격리).
func _inject_probe() -> void:
	var def = (load("res://src/core/schemas/enemy_def.gd") as GDScript).new()
	def.id = PROBE
	def.hp = 500.0
	def.has_counter = false
	def.params = {
		"sprite": PROBE_SPRITE,
		"aggro_range": _probe_aggro(),
		"attack_cooldown": 999.0,
		"attack_range": 0.0,
		"contact_damage": 0.0,
		"move_speed": 0.0,
	}
	_db.enemies[PROBE] = def


## 안 보이는 자리(390)보다 넉넉히 크게 — 그래야 「안 보이는데 쫓는다」 상황이 성립한다.
func _probe_aggro() -> float:
	return _blind_pos().y + 150.0


## 🔴🔴 **「안 보이는 자리」 — 주변시 밖이면서 부채꼴 사거리 「안」**(`test_vision_auto._blind_pos` 규약).
##  스텁을 등 뒤에 두므로 **각도 하나로만** 걸러진다 = 부채꼴을 넓히는 뮤테이션의 검출자다.
## ⚠ 아주 멀리 두면 사거리 밖이라 각도와 무관하게 안 보여 검출력이 0이 된다(세104 실측).
func _blind_pos() -> Vector2:
	return Vector2(0, (_gs.balance.vision_near_radius + _gs.balance.vision_fan_range) * 0.5)


## 🔴 **「보이는 자리」 — 주변시 안이지만 조준은 딴 데다** ⇒ 주변시만으로 보인다.
## ⚠ 부채꼴 **안**에 두지 마라 — 주변시를 0으로 만드는 뮤테이션에 눈이 없어진다.
func _seen_pos() -> Vector2:
	return Vector2(0, maxf(_gs.balance.vision_near_radius - 40.0, 20.0))


## 추격 밖 = aggro보다 멀다. ⚠ 부채꼴 사거리보다도 멀어 **여전히 안 보인다**(재진입 시 느낌표의 조건).
func _far_pos() -> Vector2:
	return Vector2(0, _probe_aggro() + 250.0)


## 🔴 조준을 적 반대쪽으로 150° 틀어 본다 — 반각(60°)보다 크고 180°보다 뚜렷이 작아,
##  부채꼴을 360으로 벌리는 뮤테이션에도 앞뒤를 뒤집는 뮤테이션에도 빨개진다
##  (`test_vision_auto.BLIND_AIM_DEG`의 근거를 그대로 따른다 — 180°에 정확히 앉으면 부동소수
##  반올림 한 톨로 검출력이 0이 된다).
const BLIND_AIM_DEG := 150.0

func _stub(pos: Vector2) -> Node2D:
	var s := VisionStub.new()
	s.aim_dir = Vector2.UP.rotated(deg_to_rad(BLIND_AIM_DEG))
	s.add_to_group("player")
	root.add_child(s)
	s.global_position = pos
	return s


## 적 하나를 원점에 스폰한다 — `enemy_id`는 **_ready 전에** 세워야 `_def`가 그 몸으로 잡힌다.
## 🔴 스텁을 **먼저** 세워 둔다 — 발견 전이는 **첫 물리 틱**에 일어난다.
func _spawn():
	var e = _enemy_scene.instantiate()
	e.enemy_id = PROBE
	_room.add_child(e)
	e.global_position = Vector2.ZERO
	await process_frame
	await physics_frame
	return e


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


## 🔴🔴 **느낌표를 「재귀로」 찾는다 — 직속 자식으로만 찾으면 그물의 심장이 안 돈다.**
##  직속 조회(`get_node_or_null`)로 적으면, 느낌표를 `_visual` 자식으로 옮기는 뮤테이션이
##  **「노드를 못 찾았다」로 먼저 걸려** [3]ⓑ의 **누적 알파 검사가 아예 실행되지 않는다**(실측).
##  빨갛긴 하지만 **재는 이유가 달라진다** — 진짜 계약(「알파에 안 물린다」)은 안 재고 이름만 잰 셈이다.
##  ⇒ 어디에 달렸든 찾아내서 **알파와 부모를 직접 짚는다.**
## ⚠ `owned = false`가 필수다 — 런타임 생성 노드는 `owner`가 없어 기본값(true)이면 못 찾는다.
func _mark_of(e) -> Node:
	return e.find_child("AlertMark", true, false)


## 🔴🔴 **누적 알파** — `modulate`는 렌더 때 부모 것과 곱해지지 자식의 프로퍼티를 안 바꾼다.
##  자기 값만 읽으면 **부모에 알파를 거는 사고를 못 잡는다**([3] 머리말 · `test_vision_auto` 사본).
func _effective_alpha(node: CanvasItem, stop: Node) -> float:
	var a := 1.0
	var n: Node = node
	while n != null and n is CanvasItem:
		a *= (n as CanvasItem).modulate.a
		if n == stop:
			break
		n = n.get_parent()
	return a


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
