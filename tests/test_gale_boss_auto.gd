extends SceneTree
## gale 보스 자동 검증 (세션56) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_gale_boss_auto.gd
## 전 항목 통과 시 "TEST_GALE_BOSS_OK" 출력 후 종료 코드 0.
##
## 🔴 여기서 헤드리스가 **실제로 잡는** 것:
##   • gale.tres가 Db를 거쳐 실제 로드된다 + boss_gale이 읽는 params 키 전부 존재 (세50 그물)
##   • hp 절반 페이즈 전이(공개 `phase()` — 보스 공용 리더)
##   • 돌풍: 쿨+윈드업 뒤 GameState hp 감소 + 플레이어가 반대쪽으로 밀린다(apply_push 채널)
##   • 연사: volley_period 뒤 그룹 "enemy_projectiles"가 정확히 volley_count개
##   • 적 투사체: 플레이어에 닿으면 hp 감소·탄 free · 수명 만료 free (mask 2 침묵 함정 그물)
##   • 반응 룬 청산: 감전 연쇄 = enemy_hit rune BOLT · 증기 = rune WATER (FIRE 하드코딩 그물)
## ⚠ 못 잡는 것: 텔레그래프 링·투사체 스프라이트가 **보이는지**(z·렌더)·밀림 손맛·hover "느낌" —
##   실게임 MCP·사용자 F5.
##
## 공개 API로만 검증한다 (takbon-verify §3): hp()·phase()·apply_status()·take_hit()·
## take_reaction_damage()·apply_push()·그룹·시그널. 내부 필드는 계약이 아니다.
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

var failures: int = 0
var _bus = null
var _db = null
var _gs = null
var _enemy_scene = null
var _player_scene = null
var _proj_scene = null
var _container = null   # get_tree().current_scene 역할 — 연사 탄이 여기 심긴다 (test_chest 선례)


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(45.0).timeout.connect(func() -> void:
		print("TEST_GALE_BOSS_TIMEOUT — 45초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_bus = root.get_node("/root/EventBus")
	_db = root.get_node("/root/Db")
	_gs = root.get_node("/root/GameState")
	_enemy_scene = load("res://src/field/forest_enemy.tscn") as PackedScene
	_player_scene = load("res://src/actors/player.tscn") as PackedScene
	_proj_scene = load("res://src/field/enemy_projectile.tscn") as PackedScene

	# 🔴 연사가 get_tree().current_scene에 탄을 심는다 — 헤드리스엔 메인 씬이 없어 null이라
	# 컨테이너를 세운다(실게임에선 숲 씬이 그 자리. test_chest_auto 선례).
	_container = Node2D.new()
	root.add_child(_container)
	current_scene = _container
	_gs.ui_modal_open = false
	_gs.reset_player_hp()

	await _test_def_loads()
	await _test_phase_transition()
	await _test_gust()
	await _test_apply_push_alone()
	await _test_volley()
	await _test_projectile_hit_and_lifetime()
	await _test_reaction_rune()
	await _test_gust_ring_not_dimmed()

	# 뒷정리 — 오토로드에 남긴 hp 흠집을 되돌린다(파일 저장은 안 건드렸으니 wipe_save 불필요).
	_gs.reset_player_hp()

	if failures == 0:
		print("TEST_GALE_BOSS_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_GALE_BOSS_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 🔴 gale.tres가 Db를 거쳐 로드된다 + boss_gale이 읽는 params 키 전부 존재 (세50 그물 —
## "파일 만들었다"≠완료. 한 글자 오타면 리소스 전체가 조용히 사라진다).
func _test_def_loads() -> void:
	print("[1] gale.tres 로드 (Db 경유) · params 키 전수")
	var def = _db.get_enemy(&"gale")
	_check(def != null, "Db.get_enemy(&\"gale\")가 null이 아니다 (파서가 거부하면 조용히 스킵)")
	if def == null:
		return
	_check(is_equal_approx(def.hp, 150.0), "hp = 150 (세58-B 챕터 하향, 실제 %.0f)" % def.hp)
	_check(str(def.params.get("ai", "")) == "boss_gale", "params.ai == boss_gale")
	# boss_gale 분기·투사체가 읽는 키 전부 — 하나라도 빠지면 폴백으로 조용히 돈다.
	var keys := ["gust_damage", "gust_period", "gust_push_dist", "gust_radius", "gust_windup",
		"volley_count", "volley_interval", "volley_period",
		"proj_damage", "proj_speed", "proj_lifetime",
		"phase2_rate_mult", "phase2_speed_mult",
		"hover_min", "hover_max", "move_speed", "sight_range"]
	for k in keys:
		_check(def.params.has(k), "params에 %s가 있다" % k)
	var ok := true
	for d in def.drops:
		if _db.get_item(d.item_id) == null:
			ok = false
	_check(ok, "drops의 아이템 id가 전부 Db에 실재한다")


## [2] 🔴 hp 절반 페이즈 전이 — 판정이 boss 틱 안에 있으므로 플레이어를 둬 틱하게 한다
## (snake 테스트 [4]와 동일 패턴 — `_phase2`는 보스 공용 플래그).
func _test_phase_transition() -> void:
	print("[2] hp 절반 페이즈 전이")
	var boss = _make_gale(Vector2.ZERO)
	var dummy = _make_dummy_player(Vector2(140, 0))  # hover 밴드 안 → 틱만 돈다
	await physics_frame
	_check(boss.phase() == 1, "전이 전 페이즈 == 1")
	# 비약점 WATER(2) 80 → hp 150→70 (< 임계 75, 하지만 살아 있음. 세58-B hp 하향에 맞춘 수치).
	# ⚠ FIRE(0)를 쓰지 마라 — gale은 counter_rune=FIRE·weakness_mult 1.6이라 128이 박혀 의도가 흐려진다.
	boss.take_hit(80.0, Enums.RuneType.WATER, 0, 0.0)
	for i in 5:
		await physics_frame
	_check(boss.hp() > 0.0, "아직 살아 있다 (%.0f)" % boss.hp())
	_check(boss.phase() == 2, "hp 절반 아래 → 페이즈 2로 전이했다 (실제 %d)" % boss.phase())
	_free(dummy)
	_free(boss)
	await physics_frame


## [3] 🔴 돌풍 — 진짜 플레이어를 반경 안에 붙여 두면(매 프레임 보스를 옆에 핀) gust_period+windup
## (3.0+0.8 ≈ 3.8s) 뒤 hp가 깎이고 플레이어가 보스 반대쪽으로 밀린다.
## 보스를 핀하는 이유: hover_min(110) > gust_radius(90)라 자유 이동이면 보스가 물러나 돌풍을 안 쓴다
## (실게임에선 플레이어가 쫓아 붙는 상황 — 여기선 핀이 그 역할).
func _test_gust() -> void:
	print("[3] 돌풍 — hp 감소 + 밀림")
	var boss = _make_gale(Vector2(50, 0))
	var player = _player_scene.instantiate()
	root.add_child(player)
	player.global_position = Vector2.ZERO
	await physics_frame
	var hp0: float = _gs.hp
	var landed := false
	for i in 300:  # 3.8s ≈ 230프레임 + 여유
		boss.global_position = player.global_position + Vector2(50, 0)
		await physics_frame
		if _gs.hp < hp0:
			landed = true
			break
	_check(landed, "돌풍이 hp를 깎았다 (%.0f → %.0f)" % [hp0, _gs.hp])
	# 밀림 — 보스가 +x 쪽이므로 플레이어는 -x로 밀린다. 감쇠(900)면 ~0.4s에 끝난다.
	var p0: Vector2 = player.global_position
	for i in 45:
		await physics_frame
	var moved: float = p0.x - player.global_position.x
	_check(moved > 20.0, "플레이어가 보스 반대쪽(-x)으로 밀렸다 (이동 %.0f px)" % moved)
	# 뒷정리 — 이 사이 볼리 쿨이 돌아 탄이 나왔을 수 있다(지금 타이밍으론 안 나오지만 여유 0.75s짜리
	# 우연 — 사용자가 gust_windup·volley_period를 조이면 유령 탄이 [4]의 카운트를 오염시킨다).
	for node in get_nodes_in_group("enemy_projectiles"):
		node.free()
	_free(player)
	_free(boss)
	await physics_frame


## [3b] 🔴 apply_push 단독 — 감쇠 적분 이동거리 ≈ dist (±30%). 채널 자체의 계약 그물.
func _test_apply_push_alone() -> void:
	print("[3b] apply_push 단독 — 이동거리 ≈ dist")
	var player = _player_scene.instantiate()
	root.add_child(player)
	player.global_position = Vector2.ZERO
	await physics_frame
	player.apply_push(Vector2.RIGHT, 70.0)
	for i in 45:  # 감쇠 종료(~0.4s) + 여유
		await physics_frame
	var moved: float = player.global_position.x
	_check(moved > 70.0 * 0.7 and moved < 70.0 * 1.3,
		"이동거리 %.0f px ≈ gust_push_dist 70 (±30%%)" % moved)
	_free(player)
	await physics_frame


## [4] 🔴 연사 — hover 밴드 거리(돌풍 반경 밖)에서 volley_period 뒤 정확히 volley_count발.
## 대상은 물리 몸 없는 더미(Node2D) — 탄이 안 맞고 남아 발수를 셀 수 있다.
## 발수 고정 뮤테이션(volley_count 무시 → 1발)이면 여기가 빨개진다.
func _test_volley() -> void:
	print("[4] 연사 — 발수 == volley_count")
	var boss = _make_gale(Vector2.ZERO)
	var dummy = _make_dummy_player(Vector2(140, 0))  # 90 < 140 < aggro 260 → 돌풍 없이 연사만
	await physics_frame
	var first_seen := false
	for i in 350:  # volley_period 4.5s ≈ 270프레임 + 여유
		await physics_frame
		if get_nodes_in_group("enemy_projectiles").size() > 0:
			first_seen = true
			break
	_check(first_seen, "연사가 시작됐다 (첫 탄 스폰)")
	for i in 40:  # 남은 발(0.25s 간격 ×2) + 여유
		await physics_frame
	var count: int = get_nodes_in_group("enemy_projectiles").size()
	# 기대 발수는 .tres에서 읽는다 — 3을 리터럴로 박으면 사용자 F5 튜닝(발수 변경)에 테스트가 깨진다.
	var expected: int = int(_db.get_enemy(&"gale").params.get("volley_count", 3.0))
	_check(count == expected, "탄 수 == volley_count %d (실제 %d)" % [expected, count])
	# 뒷정리 — 남은 탄이 다음 테스트의 카운트·물리에 섞이지 않게.
	for node in get_nodes_in_group("enemy_projectiles"):
		node.free()
	_free(dummy)
	_free(boss)
	await physics_frame


## [5] 🔴 적 투사체 — 플레이어에 닿으면 hp 감소 + 탄 free (mask에 2가 빠지면 "맞았는데 안 아픈"
## 침묵 — 여기가 그물이다). 수명 만료면 그냥 free.
func _test_projectile_hit_and_lifetime() -> void:
	print("[5] 적 투사체 — 히트·수명")
	var player = _player_scene.instantiate()
	root.add_child(player)
	player.global_position = Vector2.ZERO
	await physics_frame
	var hp0: float = _gs.hp
	var proj = _proj_scene.instantiate()
	_container.add_child(proj)
	proj.global_position = Vector2(60, 0)
	proj.setup(Vector2.LEFT, 6.0, 170.0, 2.0)  # 60px / 170px·s ≈ 0.35s 뒤 히트
	var hit := false
	for i in 60:
		await physics_frame
		if _gs.hp < hp0:
			hit = true
			break
	_check(hit, "탄이 플레이어를 때렸다 (hp %.0f → %.0f)" % [hp0, _gs.hp])
	await physics_frame
	_check(not is_instance_valid(proj), "히트한 탄은 free됐다")
	# 수명 만료 — 플레이어 반대쪽으로 쏘고 짧은 수명을 준다.
	var proj2 = _proj_scene.instantiate()
	_container.add_child(proj2)
	proj2.global_position = Vector2(300, 300)
	proj2.setup(Vector2.RIGHT, 6.0, 170.0, 0.3)
	for i in 30:  # 0.3s = 18프레임 + 여유
		await physics_frame
	_check(not is_instance_valid(proj2), "수명 만료 탄은 free됐다")
	_free(player)
	await physics_frame


## [6] 🔴 반응 룬 청산 — 감전 연쇄의 enemy_hit rune == BOLT(연쇄 대상), 증기 == WATER(자신).
## 증기가 더 센 그물이다: 들어온 룬(FIRE)과 버스트 룬(WATER)이 달라, incoming 폴백만 있어도
## 빨개진다(REACTIONS "rune" 키 → on_burst 5인자 → take_reaction_damage까지 전 배관을 잰다).
## take_reaction_damage를 도로 FIRE 고정으로 되돌리는 뮤테이션이면 둘 다 빨개진다.
func _test_reaction_rune() -> void:
	print("[6] 반응 피해의 enemy_hit rune — 감전=BOLT · 증기=WATER")
	# 감전 연쇄: A(WET)에 BOLT → 반경 안 B가 take_reaction_damage → B의 enemy_hit rune == BOLT(4).
	var a = _make_slime(Vector2.ZERO)
	var b = _make_slime(Vector2(40, 0))  # 연쇄 반경(balance status_shock_chain_px) 안
	await physics_frame
	var b_runes := []
	var cb := func(who, _dmg, rune) -> void:
		if who == b:
			b_runes.append(rune)
	_bus.enemy_hit.connect(cb)
	a.apply_status(Enums.Status.WET, 1.0)
	a.take_hit(0.0, Enums.RuneType.BOLT, Enums.Status.SHOCK, 1.0)
	await process_frame
	_check(b_runes.size() >= 1, "연쇄가 B를 때렸다 (enemy_hit %d회)" % b_runes.size())
	_check(b_runes.has(Enums.RuneType.BOLT), "연쇄 피해의 rune == BOLT (실제 %s)" % str(b_runes))
	_check(not b_runes.has(Enums.RuneType.FIRE), "연쇄 피해에 FIRE가 없다 (하드코딩 청산)")
	_bus.enemy_hit.disconnect(cb)
	_free(a)
	_free(b)
	await physics_frame

	# 증기: C(WET)에 FIRE → include_self 버스트 → C 자신의 enemy_hit에 rune == WATER(2)가 섞인다.
	var c = _make_slime(Vector2(500, 500))
	await physics_frame
	var c_runes := []
	var cb2 := func(who, _dmg, rune) -> void:
		if who == c:
			c_runes.append(rune)
	_bus.enemy_hit.connect(cb2)
	c.apply_status(Enums.Status.WET, 1.0)
	c.take_hit(0.0, Enums.RuneType.FIRE, Enums.Status.BURN, 1.0)
	await process_frame
	_check(c_runes.has(Enums.RuneType.WATER),
		"증기 피해의 rune == WATER — 들어온 FIRE가 아니다 (실제 %s)" % str(c_runes))
	_bus.enemy_hit.disconnect(cb2)
	_free(c)
	await physics_frame


## [7] 🔴🔴 **돌풍 예고 링이 알파 축에 안 물린다** — 세112에 `test_vision_auto [6]`에서 **이전**해 왔다.
##
## 🔴 **왜 시야가 죽었는데도 살아남는 그물인가**: 재는 대상이 시야가 아니라 **`_refresh_alpha`의
##  소유권 계약**이다 — *"알파를 거는 노드는 `_visual`과 그림자 둘이다. 루트에 걸지 마라."*
##  그 계약은 **코드에 그대로 살아 있고**, 어기는 손도 그대로다: *"루트에 걸면 그림자도 자식이니 공짜"*.
##  그 한 줄이 들어가면 **돌풍 링이 같이 죽는데(에러 0)** 링은 `_visual`의 **형제**(적의 자식)라
##  다른 그물이 아무도 안 본다. 🔴 `_charge_band`로는 못 잰다 — 그건 **씬 자식**이라 루트에 걸어도 안 죽는다.
##
## 🔴🔴 **옛 판을 그대로 못 옮긴 이유 — 관측 조건이 사라졌다.** 세111까지는 *"시야 밖이라 몸은
##  알파 0인데 링은 1.0"*으로 **런타임에 갈랐다.** 세112에 시야가 죽어 알파 축이 **분산 하나**로
##  줄었는데 `boss_gale`은 분산을 안 한다(`_ai_hover` 전용) ⇒ **공개 API로 둘을 가르는 판을 못 만든다.**
##  ⇒ 실패 형태 **둘을 직접** 잰다:
##    ⓑ **구조** — 링이 적의 **직계 자식**이고 `Visual`의 자식이 아니다(`_visual.add_child`로 옮기면 빨강)
##    ⓒ **소스** — `_refresh_alpha`가 **루트 `modulate`에 대입하지 않는다**(`modulate.a = a`로 바꾸면 빨강)
##  ⓒ가 소스 스캔인 이유는 `test_audio_auto` ⑤와 같다: **실패 형태가 늘 「그 줄이 바뀐다」**인데
##  지금은 알파 축이 상수 1.0이라 런타임 값으로는 **자명 통과**가 된다(세86 *"결과가 같다 ≠ 같은 길"*).
## ✅ ⓐ(누적 알파 1.0)는 지금 자명 통과지만 남긴다 — **알파 축이 다시 생기는 날 저절로 검출자가 된다.**
##
## 🔴 **누적 알파로 잰다** — Godot의 `modulate`는 렌더 때 부모 것과 곱해지지 자식의 프로퍼티를
##  바꾸지 않는다. 링 자신의 값만 읽으면 루트에 걸어도 1.0이라 **그린이다.**
##
## ⚠ 보스를 매 프레임 핀한다 — `hover_min`(110) > `gust_radius`(90)라 자유 이동이면 물러나 돌풍을 안 쓴다([3] 선례).
func _test_gust_ring_not_dimmed() -> void:
	print("[7] 🔴🔴 돌풍 링이 알파 축에 안 물린다 (test_vision_auto [6] 이전 — 계약은 `_refresh_alpha`)")
	var boss = _make_gale(Vector2(50, 0))
	var dummy = _make_dummy_player(Vector2.ZERO)
	await physics_frame
	# 윈드업이 열릴 때까지 핀한 채로 돈다 — gust_period(3.0s) ≈ 180프레임 + 여유.
	var ring: Line2D = null
	for i in 300:
		boss.global_position = dummy.global_position + Vector2(50, 0)
		await physics_frame
		var found := _find_line2d(boss)
		if found != null and found.visible:
			ring = found
			break
	# 🔴 **재귀로 찾는다** — 직계 자식만 보면 링을 `Visual` 밑으로 옮기는 뮤테이션이
	#  「링이 안 떴다」로 빨개져서 **어디가 깨졌는지 그물이 거짓말한다**(ⓑ가 아예 안 돈다).
	_check(ring != null, "🔴 돌풍 예고 링이 떴다 (없으면 아래가 전부 자명 통과다 — 윈드업 조건을 다시 봐라)")
	if ring != null:
		# ⓑ 구조 — 링은 `_visual`의 **형제**여야 한다.
		_check(ring.get_parent() == boss,
			"🔴🔴 ⓑ 링이 적의 **직계 자식**이다 (실제 부모 %s — `Visual` 밑으로 옮기면 몸 알파에 물린다)"
				% (ring.get_parent().name if ring.get_parent() != null else "(없음)"))
		var vis: Node = boss.get_node_or_null(^"Visual")
		var under_visual: bool = vis != null and _line2d_child_of(vis) != null
		_check(not under_visual, "🔴 `Visual` 밑엔 Line2D가 없다 (있으면 예고가 몸과 함께 흐려진다)")
		# ⓐ 누적 알파 — 지금은 상수 1.0이라 자명 통과지만, 알파 축이 다시 생기면 여기가 검출자가 된다.
		_check(is_equal_approx(_effective_alpha(ring, boss), 1.0),
			"⓪ 링의 **누적** 알파가 1.0이다 (실제 %.3f — 1보다 작으면 예고가 몸과 함께 눌린 것)"
				% _effective_alpha(ring, boss))
	# ⓒ 소스 — `_refresh_alpha`가 루트 `modulate`를 만지지 않는다.
	_check_refresh_alpha_source()
	_free(dummy)
	_free(boss)
	await physics_frame


## ⓒ 소스 스캔 — `_refresh_alpha` **본문**에 루트 `modulate` 대입이 있나.
## 🔴 **본문만 훑는다** — 머리말 주석엔 *"루트에 걸지 마라"*가 그대로 적혀 있어서 파일 전체를
##  훑으면 **그 경고문 자체에 걸려 늘 빨갛다**(검사가 자기 발을 밟는 자리다).
## ⚠ 허용 = `_visual.modulate...` · `_shadow.modulate...` / 금지 = 줄 첫 토큰이 `modulate`인 대입.
func _check_refresh_alpha_source() -> void:
	var f := FileAccess.open("res://src/field/forest_enemy.gd", FileAccess.READ)
	if f == null:
		_check(false, "forest_enemy.gd를 읽었다 (소스 스캔의 전제)")
		return
	var lines := f.get_as_text().split("\n")
	f.close()
	var inside := false
	var body := 0
	var bad := ""
	for line: String in lines:
		if line.begins_with("func _refresh_alpha("):
			inside = true
			continue
		if inside:
			if line.begins_with("func ") or line.begins_with("## "):
				break
			var t := line.strip_edges()
			if t == "" or t.begins_with("#"):
				continue
			body += 1
			if t.begins_with("modulate"):
				bad = t
	_check(body > 0, "ⓒ `_refresh_alpha` 본문을 찾았다 (0줄이면 스캔이 아무것도 안 잰다)")
	_check(bad == "",
		"🔴🔴 ⓒ `_refresh_alpha`가 **루트 `modulate`에 대입하지 않는다** (위반 줄: %s — 걸면 돌풍 링·그 밖 형제 노드가 같이 죽는데 에러가 0이다)"
			% ("없음" if bad == "" else bad))


# ── 헬퍼 ──

## 돌풍 링을 **트리 아래 어디서든** 찾는다(`_show_gust_ring`이 만드는 유일한 Line2D).
## 🔴 직계만 보면 안 된다 — 링이 `Visual` 밑으로 옮겨진 판에서 ⓑ가 **안 돌고** 「안 떴다」로만 빨개진다.
func _find_line2d(node: Node) -> Line2D:
	for c in node.get_children():
		if c is Line2D:
			return c as Line2D
		var deep := _find_line2d(c)
		if deep != null:
			return deep
	return null


## 직계 자식 중 Line2D — ⓑ의 「`Visual` 밑엔 없다」 전용.
func _line2d_child_of(node: Node) -> Line2D:
	for c in node.get_children():
		if c is Line2D:
			return c as Line2D
	return null


## 🔴 **누적** 알파 — `stop`까지 부모 체인의 `modulate.a`를 곱한다.
## Godot은 렌더 때 곱하지 자식 프로퍼티를 안 바꾼다 ⇒ 노드 자신의 값만 읽으면 검출력이 0이다.
func _effective_alpha(node: CanvasItem, stop: Node) -> float:
	var a := 1.0
	var n: Node = node
	while n != null and n is CanvasItem:
		a *= (n as CanvasItem).modulate.a
		if n == stop:
			break
		n = n.get_parent()
	return a


func _make_gale(pos: Vector2):
	var boss = _enemy_scene.instantiate()
	boss.enemy_id = &"gale"   # add_child 전에 — _ready가 이 id로 .tres를 문다
	root.add_child(boss)
	boss.global_position = pos
	return boss


func _make_slime(pos: Vector2):
	var e = _enemy_scene.instantiate()  # enemy_id 기본 slime
	root.add_child(e)
	e.global_position = pos
	return e


## 물리 몸 없는 조준 표적 — 그룹 "player"만 필요할 때 (snake 테스트 선례).
func _make_dummy_player(pos: Vector2) -> Node2D:
	var p := Node2D.new()
	p.add_to_group("player")
	root.add_child(p)
	p.global_position = pos
	return p


func _free(node) -> void:
	if node != null and is_instance_valid(node):
		node.free()


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
