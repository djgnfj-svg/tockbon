extends SceneTree
## 챕터 보스방 자동 검증 (세58-B) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_chapter_auto.gd
## 전 항목 통과 시 "TEST_CHAPTER_OK" 출력 후 종료 코드 0.
##
## 검증 대상 = **챕터 루프**: 골라 들어가 · 보스를 잡고 · 포탈로 돌아온다. test_forest_auto(은퇴)의
## extraction/bag_lost/물리 레이어/출격 만HP 그물을 여기로 **이식**했다 — 삭제 전 이식이 순서다.
##
## 🔴 여기서 헤드리스가 **실제로 잡는** 것:
##   • data/chapters/*.tres 3장이 Db를 거쳐 실제 로드된다 (세50 침묵 데이터 죽음 그물)
##   • 보스 스폰 **두 경로 각각** — ch1=forest_enemy 범용(enemy_id 대입)·ch3=전용 씬(snake_boss)
##     (세56 교훈: 두 몸 계약은 그물도 두 개 — 한쪽만 재면 다른 쪽이 조용히 갈라진다)
##   • 처치 → chapter_clear codex 심김(파생 키) · 귀환 포탈 스폰
##   • 🔴 세71 보상 해금 — ch1 클리어 시 ChapterDef.reward_unlock(gr_radiate5)이 codex에 심긴다
##     (chapter_clear와 별도 축 — 조립→탁본 루프의 이음매. 발신 줄 뮤테이션으로 검출력 확인)
##   • 🔴 세71 잡몹 길 — ch1은 이제 보스 1 + mob_spawns N. "enemies"에 섞이므로 보스는 enemy_id로 특정
##   • 포탈 [E] → extraction_success 1회(가방→창고 정산) · 사망 → bag_lost
##   • 잠금 판정식 — chapter_panel의 공개 is_chapter_open()이 단일 소스 (ch2는 ch1 클리어 전 잠김)
##   • 🔴 물리 레이어 계약 — 적 4=enemy가 아니면 부딪히기만 하고 take_hit이 안 불린다 (forest [1][5] 이식)
## ⚠ 못 잡는 것: Ground.mouse_filter(클릭 도달)·패널 카드 클릭·포탈/상자 렌더 — 실게임 MCP.
## ⚠ [8]은 pending_chapter 오염 가드를 재느라 push_error 한 줄(USER ERROR)을 **의도적으로** 낸다.
##
## 공개 계약으로만 검증한다: EventBus 시그널 · 그룹 · zone_id · take_hit · 패널 공개 API.
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

const GLYPH_NONE := -1

var failures: int = 0
var _bus = null
var _gs = null
var _db = null
var _scene = null
var _room = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(40.0).timeout.connect(func() -> void:
		print("TEST_CHAPTER_TIMEOUT — 40초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_bus = root.get_node("/root/EventBus")
	_gs = root.get_node("/root/GameState")
	_db = root.get_node("/root/Db")
	_scene = load("res://src/field/boss_room.tscn") as PackedScene

	await _test_chapters_load()
	await _test_boss_spawn_both_paths()
	await _test_contact_damage()
	await _test_my_spell_can_hit_boss()
	await _test_kill_plants_clear_and_portal()
	await _test_portal_banks_the_run()
	await _test_death_loses_the_bag()
	await _test_lock_judgment()
	await _test_missing_chapter_falls_back()

	# 🔴 뒷정리 — extraction_success·bag_lost에 SaveManager가 물려 있어 **진짜 세이브를 쓴다**
	# (test_forest_auto가 같은 이유로 했다). 안 지우면 플레이 세이브가 테스트 찌꺼기로 덮인다.
	root.get_node("/root/SaveManager").wipe_save()

	if failures == 0:
		print("TEST_CHAPTER_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_CHAPTER_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 🔴 챕터 3장이 Db를 거쳐 로드된다 (세50 그물 — Color 3인자 한 글자면 리소스 전체가 조용히
## 사라지고 전 스위트가 그린이다). order·보스 id 실재·클리어 키 파생까지 한 번에 잰다.
func _test_chapters_load() -> void:
	print("[1] 챕터 3장 로드 (Db 경유) · order · 파생 클리어 키")
	var expected := {&"ch1": 1, &"ch2": 2, &"ch3": 3}
	for id: StringName in expected:
		var ch = _db.get_chapter(id)
		_check(ch != null, "Db.get_chapter(%s)가 null이 아니다 (파서가 거부하면 조용히 스킵)" % id)
		if ch == null:
			continue
		_check(ch.order == expected[id], "%s order == %d (실제 %d)" % [id, expected[id], ch.order])
		_check(_db.get_enemy(ch.boss_enemy_id) != null,
			"%s 보스 id(%s)가 Db.enemies에 실재한다" % [id, ch.boss_enemy_id])
	var sorted = _db.chapters_sorted()
	_check(sorted.size() == 3, "chapters_sorted가 3장 (실제 %d)" % sorted.size())
	var ch3 = _db.get_chapter(&"ch3")
	if ch3 != null:
		_check(ch3.boss_scene_path != "" and ResourceLoader.exists(ch3.boss_scene_path),
			"ch3 전용 씬 경로(%s)가 실재한다" % ch3.boss_scene_path)
	var ch1 = _db.get_chapter(&"ch1")
	if ch1 != null:
		_check(_db.chapter_clear_id(ch1) == &"chapter_clear_ch1",
			"클리어 키 파생 == chapter_clear_ch1 (실제 %s)" % _db.chapter_clear_id(ch1))


## [2] 🔴 보스 스폰 **두 경로 각각** + 출격 만HP (forest [2] 이식).
## ch1 = forest_enemy 범용(add_child 전 enemy_id 대입 — 순서가 계약) · ch3 = snake_boss 전용 씬.
## 🔴 스폰 위치 허용 반경 — **등가가 아니라 반경으로 재는 이유**(세84에 flake를 실측해 고쳤다):
## 보스는 살아 움직인다. 검사가 도는 프레임까지 추격 AI가 전진하므로 **부하가 걸리면**(다른 에이전트가
## 동시에 테스트를 돌 때 등) 몇 px 어긋나 `< 2.0`이 3~4회 중 1회 빨개졌다 — 계약이 깨진 게 아니라
## **계약을 잘못 표현한 것**이었다(재는 것은 「지금 어디 있나」가 아니라 「거기서 **시작했나**」다).
## 값 근거 = 관측된 정상 드리프트 **8.5px**의 7배 여유. 이 검사가 실제로 잡는 것은
## 「위치를 **아예 대입하지 않는다**」(보스가 원점 = `boss_spawn`이 `(0,-260)`이라 260px 어긋남)다.
##
## 🔴🔴 **이 검사는 위쪽 주석이 말하는 「대입이 `add_child` 앞」 계약을 재지 않는다 — 세84에 실측했다.**
## 뮤테이션(`boss_room.gd`의 대입을 `add_child` 뒤로) → **3회 전부 그린**. 대입이 같은 프레임에
## 일어나므로 검사 시점엔 보스가 제자리다. 그 계약이 진짜로 망가뜨리는 것은 **보스 위치가 아니라
## `snake_body`의 자취 프리시드**다(`snake_body.gd:70`이 `_ready`에서 **부모의 그 시점** 위치를 읽어
## 마디 12개를 깐다 → 뒤에 옮기면 마디가 원점 기준으로 깔린다 = 세54 「정지 뭉침」).
## ⚠ 그런데 이후 프레임에 자취가 따라잡아 **검사 시점엔 복구돼 있다** → 지금 **어느 그물도 안 잰다.**
## → 다음 세션 몫: 프레임 타이밍에 의존하지 않는 형태로 재라(추천 = `snake_body`를 **단위로** 세워
##   부모 위치를 정해 놓고 자식을 붙인 뒤 「마디가 부모 근처에 깔린다」를 재는 순수 계약 검사.
##   씬을 통과시키면 다시 부하-의존 flake가 된다 — 이 파일이 방금 그걸로 데였다).
const SPAWN_TOL := 60.0

func _test_boss_spawn_both_paths() -> void:
	print("[2] 보스 스폰 두 경로 (ch1 범용 · ch3 전용 씬) + 출격 만HP")
	_gs.hp = 7.0
	await _fresh(&"ch1")
	_check(is_equal_approx(_gs.hp, _gs.hp_max()),
		"출격하면 HP가 찬다 %.0f/%.0f (안 그러면 죽는 게 이득)" % [_gs.hp, _gs.hp_max()])
	# 🔴 세71: ch1은 이제 잡몹 길(mob_spawns)이 깔린다 — "enemies"에 보스 1 + 잡몹 N. 보스는 enemy_id로 특정.
	var ch1 = _db.get_chapter(&"ch1")
	var want_count = 1 + ch1.mob_spawns.size()
	_check(_enemies().size() == want_count,
		"ch1: 보스 1 + 잡몹 %d = %d (실제 %d)" % [ch1.mob_spawns.size(), want_count, _enemies().size()])
	var boss = _boss(&"ch1")
	_check(boss != null, "ch1 보스(slime_elite)가 잡몹 사이에 스폰됐다")
	if boss != null:
		var want: Vector2 = ch1.boss_spawn
		_check(boss.global_position.distance_to(want) < SPAWN_TOL,
			"ch1 보스가 boss_spawn(%s) 근처에서 시작했다 (실제 %s)" % [want, boss.global_position])

	await _fresh(&"ch3")
	var ch3 = _db.get_chapter(&"ch3")
	_check(_enemies().size() == 1 + ch3.mob_spawns.size(),
		"ch3: 보스 1 + 잡몹 %d (실제 %d)" % [ch3.mob_spawns.size(), _enemies().size()])
	var boss3 = _boss(&"ch3")
	_check(boss3 != null, "ch3 보스(snake_boss)가 스폰됐다")
	if boss3 != null:
		_check(boss3.get_node_or_null("SnakeBody") != null,
			"ch3 보스에 SnakeBody가 있다 = 전용 씬이 진짜 로드됐다 (범용 스폰이면 없다)")
		# 🔴 전용 씬도 boss_spawn에 서야 한다 — 위치 대입이 add_child **앞**이어야 snake_body가
		# 그 자리 기준으로 자취를 프리시드한다(뒤면 첫 프레임에 마디가 원점→스폰으로 끌려간다,
		# 세54 「정지 뭉침」 재림 — 세58-B 리뷰가 잡았다).
		var want3: Vector2 = _db.get_chapter(&"ch3").boss_spawn
		_check(boss3.global_position.distance_to(want3) < SPAWN_TOL,
			"ch3 보스가 boss_spawn(%s) 근처에서 시작했다 (실제 %s)" % [want3, boss3.global_position])


## [2b] 접촉 피해 — 붙으면 HP가 깎인다 (옛 forest [4] 이식 — 세58-B 리뷰 지적: 이걸 빼먹으면
## **적→플레이어 피해 채널이 전 스위트 어디에도 없다**. ch1 보스는 접촉이 유일한 공격 수단이라
## 조용히 죽어도 전부 그린이 된다). GameState.hp가 원장이다.
func _test_contact_damage() -> void:
	print("[2b] 보스에 닿으면 아프다 (적→플레이어 피해 채널)")
	await _fresh(&"ch1")
	var enemy = _boss(&"ch1")   # 🔴 보스에 붙는다 (잡몹이 아니라 — 보스 접촉 채널을 잰다)
	var player = get_first_node_in_group("player")
	player.global_position = enemy.global_position   # attack_range 안
	var before: float = _gs.hp
	var frames := 0
	while is_equal_approx(_gs.hp, before) and frames < 90:
		await physics_frame
		frames += 1
	_check(_gs.hp < before, "HP %.0f → %.0f (90프레임 안에 접촉 피해)" % [before, _gs.hp])


## [3] 🔴 내 마법이 보스에게 닿는다 (forest [1][5] 물리 레이어 그물 이식).
## 적이 레이어 4(enemy)가 아니면 캐리어(마스크 5)가 부딪히기만 하고 take_hit이 안 불린다 —
## 에러도 경고도 없이 "안 죽는 보스"가 된다. 발사 시스템의 존재도 행동으로 함께 확인한다.
func _test_my_spell_can_hit_boss() -> void:
	print("[3] 내 마법이 보스를 때린다 (레이어 계약 · RingSpellSystem 존재)")
	await _fresh(&"ch1")
	# 발사 시스템 존재 — "쏘면 진이 생기나" (노드 이름이 아니라 행동으로).
	_bus.ring_cast_requested.emit(_assembly(1.0), Vector2(9000, 9000), Vector2(1, 0))
	await physics_frame
	_check(_carriers().size() == 1,
		"쏘니 진(캐리어)이 생긴다 = RingSpellSystem이 방에 있다 (실제 %d)" % _carriers().size())
	_clear()

	var boss = _boss(&"ch1")   # 🔴 보스를 특정 (잡몹 섞임)
	var hits := []
	var on_hit := func(who, dmg, _rune) -> void:
		if who == boss:
			hits.append(dmg)
	_bus.enemy_hit.connect(on_hit)
	_bus.ring_cast_requested.emit(_assembly(1.0), boss.global_position + Vector2(-120, 0), Vector2(1, 0))
	var frames := 0
	while hits.is_empty() and frames < 180:
		await physics_frame
		frames += 1
	_check(not hits.is_empty(),
		"쏜 진이 보스를 때렸다 (%d 물리 프레임) — 0이면 레이어 계약이 깨졌다" % frames)
	_bus.enemy_hit.disconnect(on_hit)
	_clear()


## [4] 🔴 처치 → chapter_clear codex + 귀환 포탈 스폰. 클리어 판정 = 처치 순간(루팅·귀환 무관).
## 포탈은 처치 전엔 **없어야** 한다 — 미리 있으면 "안 잡고 나가기"가 공짜가 된다.
func _test_kill_plants_clear_and_portal() -> void:
	print("[4] 처치 → 클리어 codex + 보상 문양 링 해금 + 포탈 스폰")
	_gs.codex.erase(&"chapter_clear_ch1")   # 앞 테스트·저장 잔재 제거 — 첫 클리어 경로를 잰다
	_gs.codex.erase(&"gr_radiate5")         # 🔴 세71 보상 첫 획득 경로를 잰다 (맨몸 시작 = 시드 아님)
	await _fresh(&"ch1")
	_check(_zone(&"portal") == null, "처치 전엔 포탈이 없다 (미리 있으면 안 잡고 나가기가 공짜)")
	_check(not _gs.is_unlocked(&"chapter_clear_ch1"), "처치 전엔 클리어 codex가 없다")
	_check(not _gs.is_unlocked(&"gr_radiate5"), "처치 전엔 보상 문양 링(gr_radiate5)이 없다 (맨몸 시작)")

	# 🔴 보스를 특정해 잡는다 — 잡몹을 잡으면 클리어가 안 된다 (mob_spawns 섞임)
	_boss(&"ch1").take_hit(99999.0, 0, 0, 0.0)
	await process_frame
	await physics_frame
	_check(_gs.is_unlocked(&"chapter_clear_ch1"),
		"보스를 잡으면 chapter_clear_ch1이 심긴다 (codex_unlocked 경유)")
	# 🔴 보상 해금 (세71) — ChapterDef.reward_unlock가 처치 순간 codex에 심긴다. chapter_clear와 **별도 축**.
	# 뮤테이션: boss_room._on_enemy_died의 reward_unlock 발신 줄을 지우면 이 검사가 빨개진다(검출력).
	# 이게 조립→탁본 루프의 이음매다 — ch1 클리어 → gr_radiate5 → 조립대에서 파이어볼 5갈래 진화.
	_check(_gs.is_unlocked(&"gr_radiate5"),
		"보스를 잡으면 보상 문양 링 gr_radiate5가 해금된다 (ChapterDef.reward_unlock)")
	var portal = _zone(&"portal")
	_check(portal != null, "보스를 잡으면 귀환 포탈이 뜬다 (zone_id=portal)")


## [5] 🔴 포탈 [E] = extraction_success — 가방(루팅분)→창고 + 자동 저장. 연타해도 1회(_leaving 가드).
## 재클리어(codex 이미 있음)여도 포탈은 떠야 한다 — 안 뜨면 파밍 재방문이 소프트락이 된다.
func _test_portal_banks_the_run() -> void:
	print("[5] 포탈 E → extraction_success 1회 · 가방이 창고로 간다 (재클리어 포함)")
	await _fresh(&"ch1")   # [4]에서 chapter_clear_ch1이 이미 있다 = 재클리어 경로
	_boss(&"ch1").take_hit(99999.0, 0, 0, 0.0)   # 🔴 보스를 특정 (잡몹 섞임)
	await process_frame
	await physics_frame
	var portal = _zone(&"portal")
	_check(portal != null, "재클리어여도 포탈이 뜬다 (안 뜨면 재방문 소프트락)")
	if portal == null:
		return
	_gs.bag.clear()
	var before: int = _gs.get_count(&"mat_slime_core")
	_gs.add_to_bag(&"mat_slime_core", 3)
	var got := []
	var cb := func() -> void: got.append(1)
	_bus.extraction_success.connect(cb)
	# 🔴 두 emit을 await 전에 — 씬 전환은 프레임 끝이라 두 emit 시점엔 방이 살아 있고 가드만 재게 된다
	# (test_forest [6] 선례).
	portal.interacted.emit()
	portal.interacted.emit()
	await process_frame
	_check(got.size() == 1, "귀환은 연타해도 extraction_success가 한 번뿐 (실제 %d)" % got.size())
	_check(_gs.get_count(&"mat_slime_core") == before + 3,
		"귀환하면 가방이 창고로 회수된다 (%d → %d)" % [before, _gs.get_count(&"mat_slime_core")])
	_check(_gs.bag.is_empty(), "회수 후 가방은 빈다")
	_bus.extraction_success.disconnect(cb)


## [6] 🔴 쓰러지면 bag_lost — 가방 증발 + 자동 저장(세이브스컴 방지). 창고(이미 회수한 것)는 그대로.
func _test_death_loses_the_bag() -> void:
	print("[6] 쓰러지면 bag_lost · 창고는 그대로")
	await _fresh(&"ch1")
	var banked: int = _gs.get_count(&"mat_slime_core")
	_gs.bag.clear()
	_gs.add_to_bag(&"mat_slime_core", 5)
	var got := []
	var cb := func() -> void: got.append(1)
	_bus.bag_lost.connect(cb)
	_gs.damage_player(99999.0)
	await process_frame
	_check(got.size() == 1, "HP 0 → bag_lost가 한 번 온다 (실제 %d)" % got.size())
	_check(_gs.bag.is_empty(), "죽으면 가방이 비워진다")
	_check(_gs.get_count(&"mat_slime_core") == banked,
		"죽어도 창고(이미 회수한 것)는 그대로다 (%d)" % banked)
	_bus.bag_lost.disconnect(cb)


## [7] 🔴 잠금 판정식 — 단일 소스는 chapter_panel의 공개 is_chapter_open() (해금 판정은 패널이).
## ch2는 ch1 클리어 codex가 없으면 잠기고, 심기면 열린다. ch1(order 1)은 늘 열려 있다.
func _test_lock_judgment() -> void:
	print("[7] 잠금 판정 — ch2는 ch1 클리어 전 잠김 / 후 열림")
	var panel_scene = load("res://src/hud/chapter_panel.tscn") as PackedScene
	var layer = panel_scene.instantiate()
	root.add_child(layer)
	var panel = layer.get_node("Panel")
	var ch1 = _db.get_chapter(&"ch1")
	var ch2 = _db.get_chapter(&"ch2")
	var ch3 = _db.get_chapter(&"ch3")

	_gs.codex.erase(&"chapter_clear_ch1")
	_gs.codex.erase(&"chapter_clear_ch2")
	_check(panel.is_chapter_open(ch1), "ch1(order 1)은 클리어 없이도 열려 있다")
	_check(not panel.is_chapter_open(ch2), "ch1 클리어 전 — ch2는 잠김")
	_check(not panel.is_chapter_open(ch3), "ch2 클리어 전 — ch3도 잠김")

	_bus.codex_unlocked.emit(&"chapter_clear_ch1")
	await process_frame
	_check(panel.is_chapter_open(ch2), "ch1 클리어 후 — ch2가 열린다")
	_check(not panel.is_chapter_open(ch3), "ch2는 아직 미클리어 — ch3은 여전히 잠김 (사슬)")
	_check(panel.is_chapter_cleared(ch1), "ch1은 클리어 표시(✓) 판정도 참이다")

	layer.free()
	await process_frame


## [8] 🔴 pending_chapter가 비거나 미등록이면 **조용히 빈 방을 띄우지 않는다** — push_error +
## 베이스 복귀 (설계 회귀 위험 #5). ⚠ 이 테스트는 push_error 한 줄(USER ERROR)을 의도적으로 낸다 —
## grep은 SCRIPT ERROR를 보라(그건 진짜 사고다).
func _test_missing_chapter_falls_back() -> void:
	print("[8] 미등록 챕터 → 빈 방 금지, 베이스로 되돌아간다 (아래 ERROR 한 줄은 의도된 것)")
	# ⚠ _fresh를 안 쓴다 — 복귀가 베이스를 로드하면 연습장 허수아비 5개가 그룹 "enemies"에 들어와
	# "보스 없음" 검사가 오염된다. add_child **직후**(await 전 = 복귀 전)에 재야 한다.
	if _room != null and is_instance_valid(_room):
		_room.free()
	if current_scene != null and is_instance_valid(current_scene):
		current_scene.free()
	_room = null
	_gs.pending_chapter = &"no_such_chapter"
	var room = _scene.instantiate()
	root.add_child(room)
	current_scene = room
	_check(_enemies().is_empty(), "보스가 스폰되지 않았다 (빈 방을 조용히 띄우지 않는다)")
	for i in 5:   # call_deferred + change_scene 처리 여유
		await process_frame
	_check(not is_instance_valid(room) or current_scene != room,
		"베이스로 되돌아갔다 (방이 current_scene에서 내려갔다)")
	_gs.pending_chapter = &""


# ── 헬퍼 (test_forest_auto 이관) ──

## 매번 **새 방**에서 시작한다. 앞 방을 남기면 플레이어가 둘이 되고(그룹 "player"가 엉킨다)
## EventBus 수신자도 둘이 돼 _die가 두 번 돈다. 귀환·사망·[8]은 change_scene으로 current_scene을
## base로 바꿔 놓는다 — 그것도 같이 치운다.
func _fresh(chapter_id: StringName) -> void:
	if _room != null and is_instance_valid(_room):
		_room.free()
	if current_scene != null and is_instance_valid(current_scene):
		current_scene.free()
	_room = null
	current_scene = null
	_gs.pending_chapter = chapter_id
	_room = _scene.instantiate()
	root.add_child(_room)
	# 🔴 current_scene을 실게임처럼 세운다 — 적 _die가 드롭/상자의 부모로 current_scene을 쓴다
	# (세46·55). 안 세우면 헤드리스에선 null이라 상자가 조용히 안 떨어진다.
	current_scene = _room
	await process_frame
	await physics_frame


func _assembly(score: float) -> Dictionary:
	var r := []
	for k in 8:
		r.append(GLYPH_NONE)
	return {"rings": [r], "score": score}


func _enemies() -> Array:
	var out := []
	for n in get_nodes_in_group("enemies"):
		if not n.is_queued_for_deletion():
			out.append(n)
	return out


## 🔴 보스만 집는다 (세71 — ch1에 잡몹 길이 깔려 "enemies"에 보스+잡몹이 섞인다). enemy_id로 가른다:
## 접촉·발사·클리어 검사가 `_enemies()[0]`을 쓰면 잡몹을 집어 보스를 못 잡는다(클리어 안 됨).
func _boss(chapter_id: StringName):
	var ch = _db.get_chapter(chapter_id)
	if ch == null:
		return null
	for n in _enemies():
		if n.enemy_id == ch.boss_enemy_id:
			return n
	return null


func _carriers() -> Array:
	var out := []
	for n in get_nodes_in_group("player_projectiles"):
		if not n.is_queued_for_deletion():
			out.append(n)
	return out


func _zone(id: StringName):
	for z in get_nodes_in_group("interact_zones"):
		if z.zone_id == id:
			return z
	return null


func _clear() -> void:
	for n in _carriers():
		n.queue_free()
	for n in get_nodes_in_group("pillars"):
		n.queue_free()


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
