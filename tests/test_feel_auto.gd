extends SceneTree
## 손맛 개편 자동 검증 (세63 — 히트 플래시 셰이더·피격 프레임·그림자·먼지·카메라) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_feel_auto.gd
## 전 항목 통과 시 "TEST_FEEL_OK" 출력 후 종료 코드 0.
##
## [1] damage_player → player_hurt 정확히 1회·인자 일치 / heal_player → 0회 (발신 단일 소스 계약)
##     + 🔴 사망 가드: 죽는 일격까지 발신·hp 0 뒤 무발신·reset 무발신 (사망 연출 스팸 방지, 세63 리뷰)
## [2] 적 2마리 중 한 마리만 take_hit → material이 **다른 인스턴스** + 안 맞은 쪽 flash_amount 0
##     (🔴 Material 리소스 공유 = 한 마리 플래시가 전원 플래시 함정)
## [3] 텔레그래프(snake_boss 러시 윈드업) → telegraph_amount > 0 **그리고** modulate 불가침
##     (세63 소유권 계약: modulate = rgb 상태 틴트 · a 분산 2축만)
## [4] params.hurt_sprite 있는 적(in-memory EnemyDef 주입 — 세61 Db 주입 선례) → "hurt" 애니·
##     loop=false / 없는 적(slime) → "hurt" 없음(기존 무변경 하위호환 계약)
## [5] snake_boss·gale params에 hurt_sprite 키 존재 + 경로 load 성공 (🔴 세50 .tres 침묵사 그물)
##     ⚠ 아트(takbon-art) 도착 + 리드 --import 전엔 load 항목이 빨갛다 — 예상된 빨강.
## [6] 적 _ready 후 그림자 1개·z_index ≥ 0·그룹 무가입·첫 자식(트리 순서 = 몸 아래) /
##     뱀 마디 그림자 수 == segment_count() (🔴 음수 z = Ground 뒤로 숨는 세54 함정 그물)
## [7] dust: 구르기 상승 엣지 → 버스트 정확히 ROLL_BURST_COUNT발(1회만) · 퍼프 그룹 무가입 ·
##     걷기 첫 프레임 즉시 1발
## [8] juice: ring_cast_requested(aim=+x) → offset.x < 0(조준 반대 반동) · 킥 소진 후 ZERO 복귀 ·
##     player_hurt(가해자 +x) → offset.x < 0(맞은 방향 반대 킥)
## [9] player 피격 애니: player_hurt → sprite.animation이 hurt_*로 유지(🔴 _face_mouse가 매 프레임
##     덮는 걸 가드가 막는다) · HURT_ANIM_SEC 소진 뒤 프레임에서 걷기/idle 계열로 자연 복귀
## [10] 허수아비 플래시 파리티 — 연습장 dummy도 셰이더 플래시·per-instance·modulate 불가침
##      (🔴 세56 「두 몸은 그물도 두 개」 — 적 쪽 그물[2]는 이 몸의 회귀를 못 잡는다)
##
## 🔴 렌더(플래시가 실제로 하얗게 보이나·그림자/먼지 겉보기·마디 z 동률·hurt 프레임 홀드 길이)는
## 헤드리스가 못 본다 — 실게임 MCP 스샷 + 사용자 F5가 별도 확인(설계 §G 하단 표).
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일되므로 오토로드 식별자·모듈 preload 금지 —
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

var failures: int = 0
var _bus = null
var _gs = null
var _db = null
var _shadow_script = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		print("TEST_FEEL_TIMEOUT — 30초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_bus = root.get_node("/root/EventBus")
	_gs = root.get_node("/root/GameState")
	_db = root.get_node("/root/Db")
	_shadow_script = load("res://src/actors/shadow.gd")

	await _test_player_hurt_signal()
	await _test_per_instance_material()
	await _test_telegraph_shader()
	await _test_hurt_anim_baking()
	await _test_boss_hurt_sprite_params()
	await _test_shadows()
	await _test_dust()
	await _test_camera_kick()
	await _test_player_hurt_anim()
	await _test_dummy_parity()
	await _test_roll_and_run()

	if failures == 0:
		print("TEST_FEEL_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_FEEL_FAIL — %d개 실패" % failures)
		quit(1)


func _test_player_hurt_signal() -> void:
	print("[1] damage_player → player_hurt 1회·인자 일치 / heal_player → 0회")
	var got: Array = []
	var cb := func(amount: float, source_pos: Vector2) -> void:
		got.append({"amount": amount, "src": source_pos})
	_bus.player_hurt.connect(cb)
	var hp_before: float = _gs.hp
	_gs.damage_player(10.0, Vector2(3.0, 4.0))
	_check(got.size() == 1, "damage_player → player_hurt 1회 (실제 %d)" % got.size())
	if got.size() == 1:
		_check(is_equal_approx(float(got[0]["amount"]), 10.0), "amount 일치")
		_check(got[0]["src"] == Vector2(3.0, 4.0), "source_pos 일치")
	_gs.heal_player(hp_before - _gs.hp)  # 원상복구 겸 회복 무발신 확인
	_check(got.size() == 1, "heal_player → player_hurt 0회 (누적 %d)" % got.size())
	# 🔴 사망 가드 (세63 리뷰) — 죽는 마지막 일격까지는 발신, 그 뒤 시체 때리기는 무발신
	# (사망 연출 0.9초 동안 접촉 피해가 아픔음·트라우마를 스팸하지 않게).
	_gs.damage_player(_gs.hp + 999.0, Vector2.ZERO)
	_check(got.size() == 2, "죽는 일격까지는 발신 (누적 %d)" % got.size())
	_gs.damage_player(5.0, Vector2.ZERO)
	_check(got.size() == 2, "hp 0 뒤 추가 피해 → 무발신 (누적 %d)" % got.size())
	_gs.reset_player_hp()  # 원상복구 (reset은 player_hurt 무발신 계약 — 카운터 불변으로 겸사 확인)
	_check(got.size() == 2, "reset_player_hp → 무발신 (누적 %d)" % got.size())
	_bus.player_hurt.disconnect(cb)


func _test_per_instance_material() -> void:
	print("[2] 히트 플래시 material — per-instance (한 마리 플래시 ≠ 전원 플래시)")
	var a = _spawn_enemy(&"slime", Vector2(0, 0))
	var b = _spawn_enemy(&"slime", Vector2(500, 0))
	await process_frame
	var mat_a = a.get_node("Visual").material
	var mat_b = b.get_node("Visual").material
	_check(mat_a is ShaderMaterial and mat_b is ShaderMaterial, "둘 다 ShaderMaterial이 붙어 있다")
	_check(mat_a != mat_b, "🔴 material이 서로 다른 인스턴스다 (리소스 공유 금지)")
	a.take_hit(5.0, 0, 0, 0.0)  # rune=FIRE(0)·status=NONE(0)
	var fa := _flash_of(mat_a)
	var fb := _flash_of(mat_b)
	_check(fa > 0.5, "맞은 쪽 flash_amount가 켜진다 (실제 %.2f)" % fa)
	_check(is_zero_approx(fb), "안 맞은 쪽 flash_amount == 0 (실제 %.2f)" % fb)
	a.queue_free()
	b.queue_free()
	await process_frame


func _test_telegraph_shader() -> void:
	print("[3] 텔레그래프 — 셰이더 telegraph_amount + modulate 불가침")
	var player := Node2D.new()
	player.add_to_group("player")
	root.add_child(player)
	player.global_position = Vector2(100, 0)
	var enemy = _spawn_enemy(&"snake_boss", Vector2.ZERO)
	await process_frame
	var mat = enemy.get_node("Visual").material
	# 러시 쿨 초기 0 + 사거리 240 안 → 첫 물리 틱에 윈드업(텔레그래프 on) 진입.
	var frames := 0
	while _param_of(mat, &"telegraph_amount") <= 0.0 and frames < 60:
		await physics_frame
		frames += 1
	_check(_param_of(mat, &"telegraph_amount") > 0.0,
		"윈드업 진입 → telegraph_amount > 0 (%d 물리 프레임)" % frames)
	var m: Color = enemy.get_node("Visual").modulate
	_check(m == Color(1, 1, 1, 1), "🔴 modulate 불가침 — 텔레그래프가 modulate를 안 만진다 (실제 %s)" % m)
	enemy.queue_free()
	player.queue_free()
	await process_frame


func _test_hurt_anim_baking() -> void:
	print("[4] _setup_frames hurt 확장 — hurt_sprite 있으면 비루프 hurt / 없으면 무변경")
	# in-memory EnemyDef 주입 (세61 Db 주입 선례 — 레지스트리가 평범한 Dictionary).
	# hurt 시트는 기존 snake_head.png를 빌려 쓴다 — 같은 규약(정사각 가로 스트립)이라 굽기 계약을
	# 아트 도착 전에 잰다 (실아트 경로 자체는 [5]가 잰다).
	var def = (load("res://src/core/schemas/enemy_def.gd") as GDScript).new()
	def.id = &"feel_hurt_test"
	def.hp = 30.0
	def.params = {
		"sprite": "res://assets/sprites/enemies/snake_head.png",
		"hurt_sprite": "res://assets/sprites/enemies/snake_head.png",
	}
	_db.enemies[def.id] = def
	var enemy = _spawn_enemy(&"feel_hurt_test", Vector2.ZERO)
	await process_frame
	var frames = enemy.get_node("Visual").sprite_frames
	_check(frames.has_animation(&"hurt"), "hurt_sprite 있는 적 → hurt 애니가 구워진다")
	if frames.has_animation(&"hurt"):
		_check(not frames.get_animation_loop(&"hurt"), "hurt는 loop=false (비루프)")
		_check(frames.has_animation(&"idle"), "idle도 그대로 산다")
	enemy.queue_free()
	_db.enemies.erase(&"feel_hurt_test")  # 🔴 주입 제거 — 잔류하면 다른 테스트의 적 수가 는다
	# 없는 적 = 기존 무변경 하위호환 계약.
	var slime = _spawn_enemy(&"slime", Vector2.ZERO)
	await process_frame
	var sframes = slime.get_node("Visual").sprite_frames
	_check(not sframes.has_animation(&"hurt"), "hurt_sprite 없는 적 → hurt 애니 없음 (기존 무변경)")
	slime.queue_free()
	await process_frame


func _test_boss_hurt_sprite_params() -> void:
	print("[5] snake_boss·gale params.hurt_sprite 키 + 로드 (세50 .tres 침묵사 그물)")
	for id in [&"snake_boss", &"gale"]:
		var def = _db.get_enemy(id)
		_check(def != null, "%s Db 로드" % id)
		if def == null:
			continue
		var p := str(def.params.get("hurt_sprite", ""))
		_check(p != "", "%s params.hurt_sprite 키 존재" % id)
		# ⚠ 아트 도착 + 리드 --import 전엔 이 항목이 빨갛다 — 예상된 빨강(scratch 보고 참조).
		var ok := p != "" and ResourceLoader.exists(p) and (load(p) is Texture2D)
		_check(ok, "%s hurt_sprite 로드 성공 (%s)" % [id, p])


func _test_shadows() -> void:
	print("[6] 그림자 — 적 자동 부착·z≥0·그룹 무가입·첫 자식 / 뱀 마디 수 일치")
	var enemy = _spawn_enemy(&"slime", Vector2.ZERO)
	await process_frame
	var shadows := _shadows_of(enemy)
	_check(shadows.size() == 1, "적 그림자 정확히 1개 (실제 %d)" % shadows.size())
	if shadows.size() == 1:
		_check(shadows[0].z_index >= 0, "🔴 z_index ≥ 0 (음수 = Ground 뒤로 숨는 세54 함정, 실제 %d)" % shadows[0].z_index)
		_check((shadows[0] as Node).get_groups().is_empty(), "그림자 그룹 무가입")
		_check(enemy.get_child(0) == shadows[0], "그림자가 첫 자식 (트리 순서 = 몸 아래)")
	enemy.queue_free()
	# 뱀 마디 그림자 — 마디마다 1개, 절대 z 0.
	var host := Node2D.new()
	root.add_child(host)
	var body = (load("res://src/field/snake_body.gd") as GDScript).new()
	host.add_child(body)
	await process_frame
	var seg_shadows := _shadows_of(body)
	_check(seg_shadows.size() == body.segment_count(),
		"마디 그림자 수 == segment_count() (%d/%d)" % [seg_shadows.size(), body.segment_count()])
	var z_ok := true
	for s in seg_shadows:
		if s.z_index != 0 or s.z_as_relative:
			z_ok = false
	_check(z_ok, "마디 그림자 = 절대 z 0 (z_as_relative=false)")
	host.queue_free()
	await process_frame


func _test_dust() -> void:
	print("[7] dust — 구르기 상승 엣지 버스트·1회만·그룹 무가입·걷기 첫 퍼프")
	# is_rolling()·velocity 공개 API만 폴링하는 계약이라, 그 둘만 가진 가짜 부모로 잰다.
	var sc := GDScript.new()
	sc.source_code = "extends CharacterBody2D\nvar rolling := false\nfunc is_rolling() -> bool:\n\treturn rolling\n"
	sc.reload()
	var host = sc.new()
	root.add_child(host)
	# 퍼프가 실제 노드로 심기게 current_scene을 세운다 (-s 부팅은 current_scene이 없다).
	# ⚠ host는 끝에 free하지 않는다 — current_scene이 해제 노드를 가리키게 두지 않기 위해서다.
	current_scene = host
	var dust = (load("res://src/actors/dust.gd") as GDScript).new()
	host.add_child(dust)
	await process_frame
	_check(dust.puff_count() == 0, "가만히 있으면 퍼프 0")
	host.rolling = true
	host.velocity = Vector2(200, 0)
	await process_frame
	var burst: int = dust.ROLL_BURST_COUNT
	_check(dust.puff_count() == burst, "구르기 상승 엣지 → 버스트 %d발 (실제 %d)" % [burst, dust.puff_count()])
	await process_frame
	_check(dust.puff_count() == burst, "구르는 동안 추가 버스트 없음 (엣지 1회만)")
	# 구르기 끝 → 걷기: 첫 프레임 즉시 1발 (타이머 리셋 계약).
	host.rolling = false
	host.velocity = Vector2(100, 0)
	await process_frame
	_check(dust.puff_count() == burst + 1, "걷기 첫 프레임 퍼프 1발 (누적 %d)" % dust.puff_count())
	host.velocity = Vector2.ZERO
	var polys: Array = []
	var polluted := false
	for c in host.get_children():
		if c is Polygon2D:
			polys.append(c)
			if not (c as Node).get_groups().is_empty():
				polluted = true
	_check(polys.size() == burst + 1, "퍼프가 실제 노드로 심겼다 (%d/%d)" % [polys.size(), burst + 1])
	_check(not polluted, "🔴 퍼프 그룹 무가입 (그룹 세는 테스트 오염 방지)")
	dust.queue_free()
	await process_frame


func _test_camera_kick() -> void:
	print("[8] juice 카메라 — 발사 반동(조준 반대)·ZERO 복귀·피격 방향성 킥")
	var host := Node2D.new()
	root.add_child(host)
	host.global_position = Vector2.ZERO
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	host.add_child(cam)
	var juice = (load("res://src/actors/juice.gd") as GDScript).new()
	host.add_child(juice)
	await process_frame
	_bus.ring_cast_requested.emit({}, Vector2.ZERO, Vector2(1, 0))
	await process_frame
	_check(cam.offset.x < 0.0, "🔴 발사 반동 — aim(+x) 반대로 offset.x < 0 (실제 %.2f)" % cam.offset.x)
	for i in 30:
		await process_frame
	_check(cam.offset == Vector2.ZERO, "킥 소진 → offset ZERO 복귀 (실제 %s)" % cam.offset)
	# 가해자가 오른쪽(+x) → 맞은 방향 반대(-x)로 킥. 트라우마 지터(|x|≤1.8)가 얹혀도 부호는 못 뒤집는다.
	_bus.player_hurt.emit(4.0, Vector2(100, 0))
	await process_frame
	_check(cam.offset.x < 0.0, "🔴 피격 킥 — 가해자(+x) 반대로 offset.x < 0 (실제 %.2f)" % cam.offset.x)
	host.queue_free()
	await process_frame


## 🔴🔴 **세90: 애니 이름이 방향별에서 `idle`·`run`·`hurt` 셋으로 바뀌었다.**
##  옛 `left`/`right`는 **픽셀이 동일한 그림**이었다(실측) — penzilla 원본이 정면뿐이라 방향 분기가
##  그림엔 처음부터 없었다. 그래서 이 그물의 `hurt_*` prefix·복귀 후보 목록도 같이 갈렸다.
##  🔴 **세 가지를 잰다**: ⓐ피격 → hurt 유지 ⓑ소진 → 자연 복귀 ⓒ**복귀한 게 실제로 존재하는 애니**인가.
##  ⓒ가 없으면 SpriteFrames에서 애니를 지워도(또는 이름을 오타 내도) `animation` 문자열은 그대로
##  들어가 있어 **전부 그린이 된다** — 씬을 통째로 인스턴스하는 이유가 이것이다.
func _test_player_hurt_anim() -> void:
	print("[9] player 피격 애니 — hurt 유지 · HURT_ANIM_SEC 소진 뒤 idle/run 복귀 (세90 이름 개편)")
	var player = (load("res://src/actors/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	player.global_position = Vector2(200, 0)
	await physics_frame
	var frames = player.get_node("Sprite").sprite_frames
	# 🔴 세90: 세 애니가 실제로 시트에 있나 (bake 스크립트 배율을 바꿔 region이 어긋나면 여기가 잡는다)
	for a in ["idle", "run", "hurt"]:
		_check(frames.has_animation(a), "🔴 SpriteFrames에 %s 애니가 있다" % a)
	_check(frames.get_frame_count(&"run") == 8,
		"🔴 run이 8프레임이다 (원본 row3 전량 — 실제 %d. 2프레임이면 옛 「idle을 걷기로」 회귀다)"
			% frames.get_frame_count(&"run"))
	_bus.player_hurt.emit(5.0, Vector2(300, 0))
	await physics_frame
	var anim := String(player.get_node("Sprite").animation)
	_check(anim == "hurt", "🔴 피격 직후 hurt 애니 유지 — _apply_anim 우선순위 (실제 %s)" % anim)
	# HURT_ANIM_SEC(연출 const) 소진 대기 — 물리 60tps 기준 프레임 수 + 여유.
	var frames_needed: int = int(ceil(player.HURT_ANIM_SEC * 60.0)) + 5
	for i in frames_needed:
		await physics_frame
	anim = String(player.get_node("Sprite").animation)
	_check(anim != "hurt", "타이머 소진 → 자연 복귀 (실제 %s)" % anim)
	_check(anim in ["idle", "run"], "🔴 복귀 애니가 존재하는 것이다 (실제 %s)" % anim)
	player.queue_free()
	await process_frame


func _test_dummy_parity() -> void:
	print("[10] 허수아비 플래시 파리티 — 두 몸은 그물도 두 개 (세56 교훈)")
	# 연습장 허수아비가 옛 modulate 곱셈으로 되돌아가면 연습장⇔숲 손맛이 조용히 갈라진다 —
	# forest_enemy 쪽 그물([2])만으로는 이 몸의 회귀를 못 잡는다(세56에 실증된 그 자리).
	var a = (load("res://src/spell/dummy_target.tscn") as PackedScene).instantiate()
	var b = (load("res://src/spell/dummy_target.tscn") as PackedScene).instantiate()
	root.add_child(a)
	root.add_child(b)
	await process_frame
	var mat_a = a.get_node("Visual").material
	var mat_b = b.get_node("Visual").material
	_check(mat_a is ShaderMaterial and mat_b is ShaderMaterial, "허수아비 둘 다 ShaderMaterial")
	_check(mat_a != mat_b, "🔴 per-instance — 하나 맞을 때 다섯이 같이 안 번쩍인다")
	a.take_hit(5.0, 0, 0, 0.0)
	_check(_flash_of(mat_a) > 0.5, "맞은 허수아비 flash_amount 켜짐 (실제 %.2f)" % _flash_of(mat_a))
	_check(is_zero_approx(_flash_of(mat_b)), "안 맞은 허수아비 flash 0")
	var m: Color = a.get_node("Visual").modulate
	_check(m == Color(1, 1, 1, 1), "🔴 modulate 불가침 — 팝이 modulate를 안 만진다 (실제 %s)" % m)
	a.queue_free()
	b.queue_free()
	await process_frame


# ── 헬퍼 ──────────────────────────────────────────────────────────────────────

func _spawn_enemy(id: StringName, pos: Vector2):
	var enemy = (load("res://src/field/forest_enemy.tscn") as PackedScene).instantiate()
	enemy.enemy_id = id
	root.add_child(enemy)
	enemy.global_position = pos
	return enemy


func _shadows_of(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if c.get_script() == _shadow_script:
			out.append(c)
	return out


## 셰이더 uniform 리더 — set된 적 없으면 null이 오므로 0으로 정규화.
func _param_of(mat, key: StringName) -> float:
	if not (mat is ShaderMaterial):
		return 0.0
	var v = (mat as ShaderMaterial).get_shader_parameter(key)
	return 0.0 if v == null else float(v)


func _flash_of(mat) -> float:
	return _param_of(mat, &"flash_amount")


## [11] 🔴 **스페이스 = 구르기(탭) + 달리기(홀드)** (세97 · 사용자 확정 「즉발 구르기 → 홀드면 달리기」).
## 🔴 **`Input.action_press`로 실제 액션 채널을 탄다** — `_physics_process`를 직접 부르거나 내부
##   플래그를 세우면 **입력 맵이 통째로 어긋나도 그린**이다(세97에 `dash`가 주석과 달리 Ctrl에
##   잡혀 있던 걸 실측으로 발견했다 — 코드는 멀쩡한데 사용자가 누르는 키가 달랐다).
## ⚠ 여기서 재는 건 **관계**(달리기 > 걷기 · 구르기가 즉발 · 무적)지 **값**이 아니다 — 손맛은 F5가 정한다.
func _test_roll_and_run() -> void:
	print("[11] 스페이스 — 탭=구르기(즉발·무적) · 홀드=달리기 · 커서 쪽으로 반전")
	var gs = root.get_node("/root/GameState")

	# ── ⓐ 달리기 속도가 걷기의 **파생**이다 (모자 배수가 달리기에도 실린다) ──
	# 🔴 `run_speed`가 balance를 직접 읽으면 달리는 동안만 장비 효과가 사라진다(세42 선례).
	var walk: float = gs.move_speed()
	var run: float = gs.run_speed()
	_check(run > walk, "🔴 달리기가 걷기보다 빠르다 (걷기 %.0f < 달리기 %.0f)" % [walk, run])
	gs.equipment[Enums.ItemKind.HAT] = &"hat_basic"
	var walk_hat: float = gs.move_speed()
	var run_hat: float = gs.run_speed()
	gs.equipment.erase(Enums.ItemKind.HAT)
	if walk_hat > walk:   # 모자가 속도를 올리는 종류일 때만 의미가 있다
		_check(is_equal_approx(run_hat / walk_hat, run / walk),
			"🔴 모자 배수가 달리기에도 그대로 실린다 (걷기·달리기 비율이 같다)")

	# ── ⓑ 🔴 **사용자가 누르는 키가 실제로 스페이스인가** ──
	# 세97 실측: 코드 주석은 내내 *"Shift"*라고 했는데 `dash`는 **Ctrl**에 잡혀 있었다.
	# 로직 그물은 액션 이름만 보므로 **키가 뭐든 전부 그린**이다 — 맵을 직접 재는 자리가 여기다.
	var on_space := false
	for ev in InputMap.action_get_events(&"dash"):
		if ev is InputEventKey and (ev.physical_keycode == KEY_SPACE or ev.keycode == KEY_SPACE):
			on_space = true
	_check(on_space, "🔴 dash(구르기·달리기)가 스페이스에 걸려 있다 (사용자 지정 키)")

	var player = (load("res://src/actors/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	player.global_position = Vector2(600, 600)
	await physics_frame

	# ── ⓒ 🔴 구르기가 **누른 그 프레임에** 나간다 (홀드 판정 지연이 없다) ──
	_check(player.ROLL_ENABLED, "🔴 구르기가 켜져 있다 (세71f에 꺼 뒀던 것을 세97에 되살렸다)")
	# ⚠ **틱을 2개까지만 준다.** `Input.action_press`는 아이들 컨텍스트에서 주입되므로 플레이어의
	#   `_physics_process`가 그 입력을 보는 건 다음 물리 틱이다(실측). 그래서 1틱은 너무 빡빡하고,
	#   넉넉히 주면 **홀드 판정(0.15초 ≈ 9틱)을 넣어도 통과해 「즉발」 검출력이 죽는다.**
	Input.action_press("dash")
	var rolled := false
	for i in 2:
		await physics_frame
		if bool(player.is_rolling()):
			rolled = true
			break
	_check(rolled,
		"🔴 스페이스를 누른 즉시 구른다 = 무적 (지연되면 피하려는 순간에 몸이 안 움직인다)")

	# ── ⓒ 구르기가 끝나도 **손을 안 떼면** 그대로 달리기로 이어진다 ──
	var waited := 0
	while bool(player.is_rolling()) and waited < 120:
		await physics_frame
		waited += 1
	_check(waited < 120, "구르기가 스스로 끝난다 (무한 무적이 아니다)")
	Input.action_press("move_right")
	for i in 30:                      # 램프가 목표 속도에 붙을 시간
		await physics_frame
	var run_vel: float = player.velocity.length()
	Input.action_release("dash")
	for i in 30:
		await physics_frame
	var walk_vel: float = player.velocity.length()
	Input.action_release("move_right")
	_check(run_vel > walk_vel + 10.0,
		"🔴 누르고 있는 동안 실제로 더 빨리 움직인다 (홀드 %.0f > 뗌 %.0f)" % [run_vel, walk_vel])

	# ── ⓓ 커서 쪽으로 좌우 반전 — 방향의 단일 소스는 `caster.aim()`이다 ──
	var sprite = player.get_node("Sprite")
	player.caster._aim = Vector2.LEFT
	await physics_frame
	_check(bool(sprite.flip_h), "🔴 커서가 왼쪽이면 스프라이트가 뒤집힌다")
	player.caster._aim = Vector2.RIGHT
	await physics_frame
	_check(not bool(sprite.flip_h), "커서가 오른쪽이면 원래대로")
	# ⚠ 커서가 바로 위/아래면 x가 0 근처라 떨린다 — 데드존이 그걸 막는다(반전을 유지한다).
	player.caster._aim = Vector2.LEFT
	await physics_frame
	player.caster._aim = Vector2.UP
	await physics_frame
	_check(bool(sprite.flip_h),
		"🔴 커서가 바로 위면 반전을 **유지**한다 (데드존 — 없으면 스프라이트가 파르르 떨린다)")

	player.queue_free()
	await process_frame


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
