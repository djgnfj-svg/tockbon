extends SceneTree
## 챕터 보스방 자동 검증 (세58-B) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_chapter_auto.gd
## 전 항목 통과 시 "TEST_CHAPTER_OK" 출력 후 종료 코드 0.
##
## 검증 대상 = **챕터 루프**: 골라 들어가 · 보스를 잡고 · **살아서 출구로 나온다**. test_forest_auto(은퇴)의
## extraction/bag_lost/물리 레이어/출격 만HP 그물을 여기로 **이식**했다 — 삭제 전 이식이 순서다.
##
## 🔴🔴 **세99: 귀환 포탈이 은퇴했다**(사용자 확정 *"보스죽으면 포탈 x"*). 옛 `[4]`·`[5]`가 **원정 정산
##  채널을 포탈로 재고 있었으므로** 그 그물을 지우지 않고 **출구로 이식**했다 — 세58-B에 접촉 피해를
##  빠뜨려 「적→플레이어 피해 채널이 전 스위트 어디에도 없던」 그 함정의 재발 자리다. 이식 대응표:
##   • 「처치 전엔 포탈이 없다」        → **은퇴**. 계승자 = 「처치가 나가는 길을 새로 만들지 않는다」([4])
##   • 「재클리어여도 포탈이 뜬다」      → **은퇴**. 계승자 = 「출구는 조건이 없어 재방문 소프트락이 불가능」([5])
##   • 「포탈 자리가 보스 옆이다」(지름길) → 계승자 = 「보스에서 가장 가까운 출구가 남쪽보다 가깝다」([5])
##   • 「포탈 [E] → extraction 1회 + 가방→창고」 → **보스 근처 출구로 그대로 이식**([5])
##
## 🔴 여기서 헤드리스가 **실제로 잡는** 것:
##   • data/chapters/*.tres 3장이 Db를 거쳐 실제 로드된다 (세50 침묵 데이터 죽음 그물)
##   • 보스 스폰 **두 경로 각각** — ch1=forest_enemy 범용(enemy_id 대입)·ch3=전용 씬(snake_boss)
##     (세56 교훈: 두 몸 계약은 그물도 두 개 — 한쪽만 재면 다른 쪽이 조용히 갈라진다)
##   • 처치 → chapter_clear codex 심김(파생 키) · **나가는 길은 처치 전후로 안 변한다**
##   • 🔴 세71 보상 해금 — ch1 클리어 시 ChapterDef.reward_unlock(gr_radiate5)이 codex에 심긴다
##     (chapter_clear와 별도 축 — 조립→탁본 루프의 이음매. 발신 줄 뮤테이션으로 검출력 확인)
##   • 🔴 세71 잡몹 길 — ch1은 이제 보스 1 + mob_spawns N. "enemies"에 섞이므로 보스는 enemy_id로 특정
##   • 🔴 세99 D5·D6 **데이터 쪽** — 풀·네임드가 실재하는 적을 가리키고 **보스 id를 안 문다**([1c])
##
## 🔴🔴 **세99 단계 1.5 — 「방 안의 적 수」만 범위가 됐다**(`_check_enemy_count`). 네임드가 매 판
##  굴러 개수가 흔들리기 때문이다. **하한이 옛 정확 기대치 그대로**라 세88이 상수를 박은 이유는
##  하나도 안 풀렸다(자세한 근거 = 그 함수 머리말). ⚠ 굴림·네임드가 **실제로 도는가**는 여기가
##  안 잰다 — `tests/test_mob_roll_auto.gd`가 확률 0.0/1.0 주입으로 양끝을 잰다(설계 §6 S3).
##   • 출구 [E] → extraction_success 1회(가방→창고 정산) — **보스 전([4b])·보스 후([5]) 둘 다** · 사망 → bag_lost
##   • 잠금 판정식 — chapter_panel의 공개 is_chapter_open()이 단일 소스 (ch2는 ch1 클리어 전 잠김)
##   • 🔴 물리 레이어 계약 — 적 4=enemy가 아니면 부딪히기만 하고 take_hit이 안 불린다 (forest [1][5] 이식)
## ⚠ 못 잡는 것: Ground.mouse_filter(클릭 도달)·패널 카드 클릭·상자 렌더 — 실게임 MCP.
## ⚠ **[E] 홀드(D7)는 여기가 안 잰다** — 이 파일은 `interacted`를 직접 emit해 **정산 채널**만 잰다.
##  실제 눌림·홀드·취소·걸어가 나가기는 `tests/test_extract_hold_auto.gd`가 진다(설계 §6 S11).
## ⚠ [8]은 pending_chapter 오염 가드를 재느라 push_error 한 줄(USER ERROR)을 **의도적으로** 낸다.
##
## 공개 계약으로만 검증한다: EventBus 시그널 · 그룹 · zone_id · take_hit · 패널 공개 API.
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

const GLYPH_NONE := -1

## 🔴🔴 챕터별 잡몹 **자리 수**를 명시 상수로 박는다 (세88 사냥 흐름 §10).
## 옛 기대치는 `1 + ch1.mob_spawns.size()`로 **데이터에서 파생**했다 — 그래서 **표를 비워도 통과했고**,
## ch2·ch3가 `mob_spawns` 0마리(= 잡몹 없는 빈 방)인 채로 전 스위트가 그린이었다. 기대치를 손으로
## 박아야 「배치를 채웠다」가 실제로 측정된다(세84 T7 「임시 시드가 그물을 안 세우는 면허」의 사촌).
## ⚠ 사용자가 F5로 수량을 조이면 이 표도 같이 고쳐라 — **그게 이 상수의 목적이다**(조용히 비지 않게).
##
## 🔴🔴 **세99 단계 1.5: 이 표는 여전히 정확 일치다 — 굴리는 건 「몇 자리인가」가 아니라 「거기 뭐가
##  서 있나」이기 때문이다**(사용자 확정 *"지형은 동일하고 나오는 몬스터들이 랜덤"*). `MobSpawn`의
##  자리 수·좌표는 사람이 놓으므로 D5를 켜도 **한 톨도 안 흔들린다.**
##  범위가 된 것은 **방 안에 실제로 선 적의 수**뿐이다(네임드가 0~N 얹힌다 — 아래 `_want_enemy_range`).
##
## ⚠ **세99 단계 3: ch1이 9 → 14로 늘었다** — 늑대 둥지(`lm_nest`) 둘레에 `hound` 다섯을 놓았다
##  (사용자 원문 *"확산된 늑대하면서 많은 늑대들이 있을듯"*). 지점 옆의 무리는 **지점의 위험도**라
##  자리 수가 늘어난 것이지 굴림이 아니다 — 그래서 이 표는 여전히 정확 일치다.
##
## 🔴🔴 **세99 몹 정리: 잡몹이 늑대 하나가 되면서 자리 수를 줄였다** (14·11·13 → 9·7·9).
##  임의로 만든 플레이스홀더 4종을 지웠고(`data/enemies/README.md`), **자리를 그대로 두면 늑대가
##  13마리 몰린다**: 늑대는 지금까지 여기 서던 것들보다 세다(HP 26 vs 슬라임 14 · 접촉 8 vs 4 ·
##  돌진 330 · aggro 220). 🔴 **좌표는 한 톨도 안 옮겼다** — 자리는 지형이 정한 것이고(D5),
##  자리를 **접었을** 뿐이다.
##  ⚠ ch1의 9 중 **다섯은 둥지 둘레 무리**라 길 위는 넷이다 — 그래서 ch1(9) > ch2(7)이어도
##   난도가 뒤집힌 게 아니다(둥지는 **일부러 들르는** 곳이다).
##  ⚠ 값은 잠정이고 **F5가 정한다** — 사용자가 조이면 이 표도 같이 고쳐라(그게 이 상수의 목적이다).
const MOB_COUNT: Dictionary = {&"ch1": 9, &"ch2": 7, &"ch3": 9}

## 🔴 챕터 확정 보상 실값 표 (세88) — **보스를 잡으면 그 보스의 속성 룬을 얻는다**(읽히기 쉬운 매핑).
## 룬 = 게임에서 가장 큰 사건(새 속성 = 새 반응 = 전투가 종류로 달라진다). 세87까지 ch1만
## `gr_radiate5`였고 ch2·ch3는 **빈 문자열**이라 클리어해도 아무것도 안 줬다.
const REWARD: Dictionary = {&"ch1": &"rune_water", &"ch2": &"rune_wind", &"ch3": &"rune_grass"}

## 🔴 **나가는 길의 zone_id — 종류가 이것 하나다**(세99에 `&"portal"`이 은퇴했다).
## 씬 인라인 남쪽 `$Exit`와 `ChapterDef.extract_points`가 세우는 `exit_zone.tscn`이 **같은 값**을 쥔다.
const EXIT_ZONE := &"exit"

## 🔴 포탈이 지던 **「지름길」 계약의 계승자**(세99). 포탈은 없앴지만 **보스 자리(y=−1350)에서 남쪽
## 입구(y=+600)까지 편도 1950px을 되돌아가는 노동**은 그대로 남는다 — `extract_points`에 보스 근처
## 좌표를 안 적으면 한 판이 왕복 노동이 되는데 **에러가 0이고 전 스위트가 그린이다.**
## 🔴 **좌표가 아니라 관계로 잰다** — 「보스에서 가장 가까운 출구」가 「남쪽 출구」보다 이 비율만큼은
##  가까워야 한다. F5로 자리를 옮겨도 안 낡고, 자리를 **비우면** 빨개진다.
## ⚠ 사용자가 *"되돌아가는 게 맞다"*로 정하면 `extract_points`를 비우고 **이 검사도 같이 지워라** —
##  그게 이 상수의 목적이다(MOB_COUNT와 같은 결: 조용히 비지 않게).
const BOSS_EXIT_MAX_RATIO := 0.5

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
	await _test_chapter_tables()
	await _test_boss_spawn_both_paths()
	await _test_contact_damage()
	await _test_my_spell_can_hit_boss()
	await _test_kill_plants_clear_and_exits_unchanged()
	await _test_exit_extracts_without_boss()
	await _test_reward_label_on_screen()
	await _test_exit_banks_the_run_after_clear()
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


## [1b] 🔴🔴 챕터 3장의 **배치·보상 실값 표** (세88 사냥 흐름) — 기대치를 손으로 박아 잰다.
##
## 왜 별도 항목인가: 배치 수를 데이터에서 파생하면 표를 비워도 통과한다(MOB_COUNT 주석 참조).
## 보상도 같은 결이다 — ch2·ch3의 `reward_unlock`이 **빈 문자열**이던 걸 아무 그물도 안 잡았다.
## 🔴 보상 id가 **실제로 존재하는 룬**인지도 잰다: 오타(`rune_watre`)면 클리어해도 아무것도
## 안 열리는데 `codex_unlocked`는 그대로 발신돼 **에러 없이 조용히 사라진다**.
func _test_chapter_tables() -> void:
	print("[1b] 챕터 3장 배치·보상 실값 표 (명시 상수 대조)")
	var CT: GDScript = load("res://src/core/codex_text.gd")
	for cid: StringName in MOB_COUNT:
		var ch = _db.get_chapter(cid)
		if ch == null:
			_check(false, "%s가 로드됐다" % cid)
			continue
		_check(ch.mob_spawns.size() == int(MOB_COUNT[cid]),
			"%s: 잡몹 %d마리 (실제 %d — 0이면 빈 방이다)" % [cid, int(MOB_COUNT[cid]), ch.mob_spawns.size()])
		_check(ch.reward_unlock == REWARD[cid],
			"%s: 보상 == %s (실제 %s)" % [cid, REWARD[cid], ch.reward_unlock])
		# 🔴 보상 id가 실재하는 룬인가 — 리졸버가 종류를 못 찾으면 오타이거나 데이터가 죽은 것이다.
		_check(CT.kind_of(ch.reward_unlock) == CT.KIND_RUNE,
			"%s: 보상 %s가 실재하는 룬이다 (리졸버 판정 '%s')" % [cid, ch.reward_unlock, CT.kind_of(ch.reward_unlock)])
		# 배치 항목이 전부 살아 있나 — SubResource 하나가 죽으면 null이 섞여 스폰이 조용히 준다.
		# 🔴🔴 세99 단계 1.5: 「죽은 항목」의 정의가 넓어졌다. `pool_tag`로 굴리는 자리는 **`enemy_id`가
		#  비어 있는 게 정상**이라(설계 §2-1) 옛 정의(`enemy_id == &""` = 죽음)를 그대로 두면 D5를
		#  켜는 순간 전부 빨개진다. 대신 **「이 자리가 실제로 뭔가를 세우나」**를 잰다:
		#  ⓐ `enemy_id`가 실재하거나 ⓑ `pool_tag`가 그 챕터 `mob_pool`에 **살아 있는 후보를 갖거나**.
		#  🔴 검출력은 안 떨어진다 — 둘 다 아니면(빈 항목·오타 태그·후보 전멸) 여전히 죽은 항목이고,
		#  그게 설계 §6 S1(「아무 적도 안 서는데 에러 0」)이 잡으라는 바로 그 상태다.
		var dead := 0
		for ms in ch.mob_spawns:
			if ms == null:
				dead += 1
			elif ms.pool_tag != &"":
				if _live_pool_ids(ch, ms.pool_tag).is_empty():
					dead += 1
			elif ms.enemy_id == &"" or _db.get_enemy(ms.enemy_id) == null:
				dead += 1
		_check(dead == 0, "%s: 배치 항목이 전부 뭔가를 세운다 (죽은 항목 %d — id도 태그도 없는 자리)"
			% [cid, dead])
		_check_pools(ch)
	# 🔴 세88에 처음 무대에 오르는 셋 — 그전엔 스폰되는 곳이 **0곳**이었다(유령 콘텐츠).
	# ⚠ 세99: 풀로 옮긴 적은 `mob_spawns`에 이름이 없다 — **풀도 같이 훑어야** 이 그물이 안 죽는다.
	# 🔴🔴 세99 몹 정리: 목록이 `hound`·`hound_alpha`가 됐다(플레이스홀더 4종 삭제). 재는 계약은
	#  그대로 **「만든 적이 무대에 오르나」**다 — 네임드는 `named_pool`에만 있으므로 **그것도 훑는다**
	#  (안 훑으면 `hound_alpha`가 유령 콘텐츠로 되돌아가도 그린이다).
	var seen := {}
	for cid2: StringName in MOB_COUNT:
		var c2 = _db.get_chapter(cid2)
		if c2 == null:
			continue
		for ms2 in c2.mob_spawns:
			if ms2 != null and ms2.enemy_id != &"":
				seen[ms2.enemy_id] = true
		for mw in c2.mob_pool:
			if mw != null and mw.enemy_id != &"" and mw.weight > 0:
				seen[mw.enemy_id] = true
		for ns2 in c2.named_pool:
			if ns2 != null and ns2.enemy_id != &"" and ns2.chance > 0.0:
				seen[ns2.enemy_id] = true
	for id: StringName in [&"hound", &"hound_alpha"]:
		_check(seen.has(id), "%s가 어느 챕터엔가 실제로 배치됐다 (세87까지 스폰 0곳)" % id)


## [1c] 🔴🔴 풀·네임드 **데이터 쪽** 검사 (세99 D5·D6). 굴림 자체는 `test_mob_roll_auto`가 잰다 —
## 여기는 **「.tres가 켜 놓은 값이 성립하나」**만 본다(그 파일은 in-memory 주입으로 기계를 재므로
## 실데이터가 조용히 비거나 어긋난 걸 못 잡는다 — 두 축이 짝이다).
##
## 🔴🔴 **가장 중요한 줄 = 보스 id 제외**(설계 §6 S9). 풀·네임드에 `boss_enemy_id`가 섞이면
##  잡몹 한 마리를 잡았을 뿐인데 `chapter_clear_*` + 보상 룬이 **전부 조용히 나간다(에러 0)**.
##  🔴 코드 쪽 가드는 `boss_room._is_boss_id`가 지고 `test_mob_roll_auto`가 잰다 — 여기 줄은
##  **데이터가 애초에 그 상태로 들어오지 않게** 하는 짝이다(둘 다 있어야 한다: 코드 가드만 있으면
##  데이터의 의도가 안 보이고, 데이터 검사만 있으면 가드를 지워도 그린이다).
func _check_pools(ch) -> void:
	var cid: StringName = ch.id
	for mw in ch.mob_pool:
		if mw == null:
			_check(false, "%s: mob_pool에 null 항목이 있다" % cid)
			continue
		_check(_db.get_enemy(mw.enemy_id) != null,
			"%s: 풀 항목 %s가 실재하는 적이다 (오타면 그 자리가 조용히 빈다)" % [cid, mw.enemy_id])
		_check(mw.enemy_id != ch.boss_enemy_id,
			"🔴🔴 %s: 풀에 보스 id(%s)가 없다 — 있으면 잡몹 한 마리가 챕터를 클리어한다" % [cid, ch.boss_enemy_id])
		_check(mw.weight > 0,
			"%s: 풀 항목 %s의 weight > 0 (0 이하는 안 뽑히니 데이터에 남길 이유가 없다)" % [cid, mw.enemy_id])
	for ns in ch.named_pool:
		if ns == null:
			_check(false, "%s: named_pool에 null 항목이 있다" % cid)
			continue
		_check(_db.get_enemy(ns.enemy_id) != null,
			"%s: 네임드 %s가 실재하는 적이다" % [cid, ns.enemy_id])
		_check(ns.enemy_id != ch.boss_enemy_id,
			"🔴🔴 %s: 네임드에 보스 id(%s)가 없다 (풀과 같은 이유)" % [cid, ch.boss_enemy_id])
		# 🔴 설계 §6 S3 — 확률이 0이나 1로 굳어도 **에러가 없다**. 데이터가 양끝이면 「가끔 뜬다」가
		#  통째로 죽은 것이다(0 = 영영 안 뜸 = 만든 값어치 0 · 1 = 매 판 뜸 = 「오늘 뭔가 있다」가 아님).
		_check(ns.chance > 0.0 and ns.chance < 1.0,
			"🔴 %s: 네임드 %s의 확률이 양끝이 아니다 (실제 %.2f — 0이면 영영 안 뜨고 1이면 늘 뜬다)"
				% [cid, ns.enemy_id, ns.chance])
		# ⚠ 지점(`at_landmark`) 해석은 **단계 3 몫**이다 — 지금 채우면 좌표가 무시된 채 원점에 선다.
		_check(ns.at_landmark == &"",
			"%s: 네임드 %s의 at_landmark가 비어 있다 (지점 해석은 단계 3 — 지금 채우면 원점에 선다)"
				% [cid, ns.enemy_id])


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
	_check_enemy_count(&"ch1")
	# 🔴🔴 카메라가 **방 안에 묶였나** (세88 — 리드가 MCP 스샷으로 잡았다).
	# 방을 2400×2200으로 키우자 **입장 순간 화면 아래 절반이 방 밖(회색)으로 비었다**: 스폰(0,600)이
	# 남쪽 경계(700)에서 100px인데 뷰포트 반높이가 270px이다. `player.tscn`의 Camera2D엔 `limit_*`이
	# 없어서(마을에선 경계까지 잘 안 가 안 드러났다) 보스방이 `_ready`에서 Ground rect로 채운다.
	# ⚠ **값을 박지 않고 Ground rect와 대조**한다 — 방 크기를 또 바꿔도 거짓 빨강이 안 나고,
	#   「좌표를 베끼지 않고 파생한다」는 계약 자체를 잰다. 뮤테이션(호출 제거) → 여기가 빨개진다.
	var ground: ColorRect = _room.get_node_or_null("Ground")
	var cam: Camera2D = _room.get_node_or_null("Player/Camera2D")
	if ground != null and cam != null:
		var tl: Vector2 = ground.global_position
		_check(cam.limit_left == int(tl.x) and cam.limit_top == int(tl.y)
			and cam.limit_right == int(tl.x + ground.size.x) and cam.limit_bottom == int(tl.y + ground.size.y),
			"카메라 limit == Ground rect (실제 L%d T%d R%d B%d / 방 %s~%s)"
			% [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom, tl, tl + ground.size])
	else:
		_check(false, "Ground·Camera2D를 찾았다 (구조가 바뀌면 이 그물이 죽는다)")

	var boss = _boss(&"ch1")
	_check(boss != null, "ch1 보스(slime_elite)가 잡몹 사이에 스폰됐다")
	if boss != null:
		var want: Vector2 = ch1.boss_spawn
		_check(boss.global_position.distance_to(want) < SPAWN_TOL,
			"ch1 보스가 boss_spawn(%s) 근처에서 시작했다 (실제 %s)" % [want, boss.global_position])

	await _fresh(&"ch3")
	var ch3 = _db.get_chapter(&"ch3")
	_check_enemy_count(&"ch3")
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


## [4] 🔴 처치 → chapter_clear codex + 보상 룬. 클리어 판정 = 처치 순간(루팅·귀환 무관).
##
## 🔴🔴 **세99: 「처치 전엔 포탈이 없다」가 은퇴하고 정반대 계약이 그 자리를 받았다** —
##  **처치는 나가는 길을 하나도 안 바꾼다.** 옛 계약은 「처치가 새 길을 연다」였고 지금은 「길은
##  처음부터 전부 서 있다」다(D2: 탈출이 목표 · 보스는 선택). 🔴 **개수를 처치 전후로 대조**하는
##  이유: 포탈 스폰이 어떤 이름으로든 되살아나면 **여기가 빨개진다**(zone_id를 바꿔 되살려도 잡힌다).
## 🔴 클리어 안내가 **없는 물건을 가리키지 않는지**도 같이 잰다 — 옛 줄이 *"포탈에서 E로 귀환하라"*라
##  씬의 **유일한 sticky 지시**가 그대로 거짓 지시가 될 자리다(감사 T4 · sticky = 「유효한 지시만」).
func _test_kill_plants_clear_and_exits_unchanged() -> void:
	print("[4] 처치 → 클리어 codex + 보상 룬 해금 (+ 나가는 길은 처치 전후로 안 변한다)")
	var reward: StringName = REWARD[&"ch1"]
	_gs.codex.erase(&"chapter_clear_ch1")   # 앞 테스트·저장 잔재 제거 — 첫 클리어 경로를 잰다
	_gs.codex.erase(reward)                 # 🔴 보상 첫 획득 경로를 잰다 (맨몸 시작 = 시드 아님)
	await _fresh(&"ch1")
	# 🔴🔴 세88 상시 귀환 — 출구는 **처음부터 있다.** 반복 사냥터가 되려면 언제든 나갈 수 있어야 한다.
	# 잡몹만 잡고 나가는 건 **재료만 얻고 확정 보상은 못 얻는** 것이라 공짜가 아니다.
	_check(_zone(EXIT_ZONE) != null,
		"처치 전에도 출구(zone_id=%s)가 있다 = 언제든 나갈 수 있다" % EXIT_ZONE)
	var exits_before: int = _exits().size()
	_check(exits_before >= 1, "처치 전 나가는 길이 %d개 (0이면 방이 통째로 소프트락이다)" % exits_before)
	_check(not _gs.is_unlocked(&"chapter_clear_ch1"), "처치 전엔 클리어 codex가 없다")
	_check(not _gs.is_unlocked(reward), "처치 전엔 보상 룬(%s)이 없다 (맨몸 시작)" % reward)

	# 🔴 보스를 특정해 잡는다 — 잡몹을 잡으면 클리어가 안 된다 (mob_spawns 섞임)
	_boss(&"ch1").take_hit(99999.0, 0, 0, 0.0)
	await process_frame
	await physics_frame
	_check(_gs.is_unlocked(&"chapter_clear_ch1"),
		"보스를 잡으면 chapter_clear_ch1이 심긴다 (codex_unlocked 경유)")
	# 🔴 보상 해금 — ChapterDef.reward_unlock가 처치 순간 codex에 심긴다. chapter_clear와 **별도 축**.
	# 뮤테이션: boss_room._on_enemy_died의 reward_unlock 발신 줄을 지우면 이 검사가 빨개진다(검출력).
	# 🔴 세88에 보상이 **룬**으로 바뀌었다 — 새 속성 = 새 원소 반응 = 전투가 종류로 달라진다.
	# ch1의 물 룬이 곧 **첫 반응(불+물=증기)이 열리는 자리**다.
	_check(_gs.is_unlocked(reward),
		"보스를 잡으면 보상 룬 %s가 해금된다 (ChapterDef.reward_unlock)" % reward)
	# 🔴🔴 계승 계약 — 처치가 **새 길을 열지 않는다**(포탈 은퇴, 사용자 확정 "보스죽으면 포탈 x").
	_check(_exits().size() == exits_before,
		"🔴 처치해도 나가는 길 수가 그대로다 %d (실제 %d — 늘면 포탈이 되살아난 것)"
			% [exits_before, _exits().size()])
	# 🔴🔴 **zone_id를 안 보고 「_extract에 이어진 지점 수」로 잰다** — 위 줄은 `&"exit"`으로만 세므로
	#  **다른 zone_id로 되살린 포탈을 못 잡는다**(세99 뮤테이션 실측: `&"warpgate"`로 부활시키니
	#  위 줄은 그린이고 이 줄만 빨개졌다). ⚠ **「지점 수 == 출구 수」로 재지 마라** — 단계 3의 지점
	#  (폐허·둥지·제단)이 자기 InteractZone을 들고 오면 **거짓 빨강**이 된다. 재려는 건 지점 수가
	#  아니라 **「나가는 길이 늘었나」**다.
	_check(_extract_wired_count() == exits_before,
		"🔴 `_extract`에 이어진 지점이 출구 %d개뿐이다 (실제 %d — 이름만 바꾼 포탈도 여기 걸린다)"
			% [exits_before, _extract_wired_count()])
	var clear_line: String = _room.get_node("Hud/Hud").say_line()
	_check(not clear_line.contains("포탈"),
		"🔴 클리어 안내가 없는 물건(포탈)을 가리키지 않는다: '%s'" % clear_line)
	_check(clear_line.contains("출구"),
		"클리어 안내가 **출구**로 나가라고 말한다 (sticky = 유효한 지시만): '%s'" % clear_line)


## [4b] 🔴🔴 **보스를 안 잡고** 남쪽 출구로 나간다 — 상시 귀환 (세88 §2-A-3).
##
## 이게 「반복 사냥터」의 실체다: 잡몹만 잡고 재료를 챙겨 나갈 수 있어야 한다. 세87까지 나가는 길은
## **보스 처치 후 포탈 하나뿐**이라, 재료를 모으려면 매번 보스를 잡아야 했다.
## ⚠ 「공짜가 되지 않나」의 답: 잡몹만 잡고 나가면 **재료만 얻고 확정 보상(룬)은 못 얻는다.**
## 🔴 정산 경로가 `_extract`에 실제로 이어졌는지 잰다 — 새 길을 뚫고 연결을 잊으면 가방이 조용히
##   증발한다(에러 없이). 연타 1회는 `_leaving` 가드가 길이 몇 개든 하나로 묶는다는 증거다.
func _test_exit_extracts_without_boss() -> void:
	print("[4b] 보스를 안 잡고 출구 E → extraction 1회 + 가방→창고")
	await _fresh(&"ch1")
	var ex = _zone(EXIT_ZONE)
	if ex == null:
		_check(false, "출구(zone_id=%s)가 없어 검사 불가" % EXIT_ZONE)
		return
	# 🔴 전제 — 보스가 아직 살아 있다. (세98까지 이 자리는 「포탈이 없다」로 잤는데, 포탈이 은퇴해
	#  그 표현이 못 쓰게 됐다. 재려는 것은 그때나 지금이나 **「안 잡았는데도 나갈 수 있나」**다.)
	_check(_boss(&"ch1") != null, "보스가 아직 살아 있다 = 안 잡고 나가는 경로를 잰다 (전제)")
	_gs.bag.clear()
	var before: int = _gs.get_count(&"mat_slime_core")
	_gs.add_to_bag(&"mat_slime_core", 3)
	var got := []
	var cb := func() -> void: got.append(1)
	_bus.extraction_success.connect(cb)
	# 🔴 두 emit을 await 전에 — 씬 전환은 프레임 끝이라 이 시점엔 방이 살아 있고 가드만 재게 된다.
	ex.interacted.emit()
	ex.interacted.emit()
	await process_frame
	_bus.extraction_success.disconnect(cb)
	_check(got.size() == 1, "출구 연타에도 extraction_success 1회 (실제 %d)" % got.size())
	_check(_gs.get_count(&"mat_slime_core") == before + 3,
		"보스를 안 잡아도 가방이 창고로 회수된다 (%d → %d)" % [before, _gs.get_count(&"mat_slime_core")])
	_check(_gs.bag.is_empty(), "회수 후 가방이 빈다")


## [4c] 🔴🔴 클리어 보상 문구 — **실제로 화면에 나가는 줄**을 읽는다 (세88 §5-D-b).
##
## 🔴 **리졸버를 직접 부르지 마라.** `CodexText`를 테스트가 직접 호출하면 `boss_room`이 옛
## `Db.get_glyph_ring` 두 줄을 그대로 쓰고 있어도 **그린이다**(구현 갈래가 뮤테이션으로 실측:
## 검출 0). 세86 교훈 그대로 — **「결과 값이 같다」는 「같은 길로 왔다」가 아니다.**
## 그래서 보스를 잡고 `hud.say_line()`을 읽는다.
##
## 잡는 것 둘: ① 원시 id 노출("보상: rune_water") ② **거짓 지시** — 옛 코드는 안내가
## *"책상에서 밴드에 끼워라"* 고정이라 **밴드는 고리 자리인데 룬을 거기 끼우라**고 가르쳤다.
## ⚠ 「표시명이 나온다」는 ch2에서 **검출력이 없다** — 챕터 제목 "바람 드는 곳"에 이미 "바람"이
##   들어 있어 뮤테이션에도 통과한다. 진짜 검출자는 **원시 id 부재**와 **「진 중심」**이다.
func _test_reward_label_on_screen() -> void:
	print("[4c] 클리어 보상 문구 — 보스를 잡고 HUD 줄을 읽는다 (원시 id·거짓 안내 금지)")
	var CT: GDScript = load("res://src/core/codex_text.gd")
	for cid: StringName in [&"ch1", &"ch2", &"ch3"]:
		var ch = _db.get_chapter(cid)
		if ch == null:
			continue
		var rid: StringName = ch.reward_unlock
		_gs.codex.erase(rid)                        # 보상 줄은 **첫 처치에만** 붙는다
		_gs.codex.erase(_db.chapter_clear_id(ch))
		await _fresh(cid)
		var boss = _boss(cid)
		if boss == null:
			_check(false, "%s 보스를 못 찾았다" % cid)
			continue
		boss.take_hit(99999.0, 0, 0, 0.0)
		await process_frame
		await physics_frame
		var hud = _room.get_node("Hud/Hud")
		var line: String = hud.say_line()
		_check(not line.contains(String(rid)), "%s: HUD에 원시 id '%s'가 안 나온다" % [cid, rid])
		_check(line.contains(CT.name_of(rid)), "%s: HUD에 표시명 '%s'가 나온다" % [cid, CT.name_of(rid)])
		_check(line.contains("진 중심"),
			"%s: 룬 보상 안내가 「진 중심」이다 (「밴드에 끼워라」면 거짓 지시다)" % cid)


## [5] 🔴🔴 **보스를 잡은 뒤의 정산 채널** — 옛 「포탈 [E] → extraction_success」를 **출구로 이식**했다.
##
## 🔴 **왜 [4b]와 따로 두나 — 재는 게 다르다.** [4b]는 *보스를 안 잡고* 남쪽으로 나가는 길이고,
##  여기는 ⓐ **재클리어**(codex가 이미 있는 파밍 재방문) ⓑ **보스 근처 출구**로 나가는 길이다.
##  옛 포탈 그물이 지던 게 정확히 그 둘이라, 합치면 **원정 정산의 절반이 그물 밖으로 빠진다**
##  (세58-B에 접촉 피해를 빠뜨려 밟은 그 함정 — 「이식은 채널 커버리지로 검산한다」).
## 🔴 「재방문 소프트락」 걱정은 **구조적으로 사라졌다** — 출구엔 조건이 없어 codex 상태와 무관하다.
##  그래도 재클리어 경로로 **한 바퀴 돌려** 확인한다(가드가 codex를 보게 되는 회귀를 잡는다).
func _test_exit_banks_the_run_after_clear() -> void:
	print("[5] 보스 처치 후 **보스 근처 출구** E → extraction_success 1회 · 가방이 창고로 (재클리어)")
	await _fresh(&"ch1")   # [4]에서 chapter_clear_ch1이 이미 있다 = 재클리어 경로
	var ch1 = _db.get_chapter(&"ch1")
	_boss(&"ch1").take_hit(99999.0, 0, 0, 0.0)   # 🔴 보스를 특정 (잡몹 섞임)
	await process_frame
	await physics_frame
	_check(not _exits().is_empty(), "재클리어여도 나가는 길이 있다 (출구엔 조건이 없다)")

	# 🔴 「지름길」 계약의 계승자 — 보스에서 가장 가까운 출구 vs 남쪽 출구. 관계로만 잰다.
	var near = _exit_nearest_to(ch1.boss_spawn)
	var south = _zone(EXIT_ZONE)
	if near == null or south == null:
		_check(false, "출구를 못 찾았다 (검사 불가)")
		return
	var d_near: float = near.global_position.distance_to(ch1.boss_spawn)
	var d_south: float = 1950.0   # 씬의 남쪽 $Exit(0,660) ↔ ch1 boss_spawn(0,−1350) 실측 편도
	_check(d_near <= d_south * BOSS_EXIT_MAX_RATIO,
		"🔴🔴 보스에서 가장 가까운 출구가 %.0fpx (남쪽까지 %.0fpx의 %.0f%% 이하여야 한다 — 포탈이 지던 지름길)"
			% [d_near, d_south, BOSS_EXIT_MAX_RATIO * 100.0])

	_gs.bag.clear()
	var before: int = _gs.get_count(&"mat_slime_core")
	_gs.add_to_bag(&"mat_slime_core", 3)
	var got := []
	var cb := func() -> void: got.append(1)
	_bus.extraction_success.connect(cb)
	# 🔴 두 emit을 await 전에 — 씬 전환은 프레임 끝이라 두 emit 시점엔 방이 살아 있고 가드만 재게 된다
	# (test_forest [6] 선례). ⚠ 홀드를 건너뛰고 시그널을 직접 쏜다 — 여기서 재는 건 **정산 채널**이고
	#  실제 [E] 홀드는 `test_extract_hold_auto [7]`이 진다(설계 §6 S11).
	near.interacted.emit()
	near.interacted.emit()
	await process_frame
	_check(got.size() == 1, "귀환은 연타해도 extraction_success가 한 번뿐 (실제 %d)" % got.size())
	_check(_gs.get_count(&"mat_slime_core") == before + 3,
		"보스 근처 출구로 나가도 가방이 창고로 회수된다 (%d → %d)"
			% [before, _gs.get_count(&"mat_slime_core")])
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


## 🔴🔴 방 안에 실제로 선 적의 수 — **세99 단계 1.5에 정확 일치에서 범위로 바꾼 유일한 자리**.
##
## 왜 범위인가: 네임드(D6)는 **매 판 독립으로 굴린다**. 「하나도 안 뜸」이 정상 결과라 개수가
## 판마다 0~N만큼 달라진다 — 정확 일치로 두면 **네임드가 뜬 판마다 빨개진다**. 이 파일은
## **세84에 이미 flake로 데인 자리**라(SPAWN_TOL 주석) 재발하면 「빨간 게 정상」이 되어 그물이 죽는다.
##
## 🔴 **검출력을 어떻게 지키나 — 하한이 옛 상수 그대로다.**
##  하한 = `1(보스) + MOB_COUNT[cid]` = 세98까지의 **정확 기대치**다. 그래서 세88이 이 상수를
##  박은 이유(*"표를 비워도 통과했고 ch2·ch3가 0마리인 채 그린이었다"*)가 한 톨도 안 풀린다:
##  표를 비우면·풀 굴림이 조용히 실패하면(설계 §6 S1) **여전히 하한에서 빨개진다.**
## 🔴 상한도 논다 — `named_pool.size()`가 천장이라 「한 항목이 두 마리를 세운다」·「굴림이 자리를
##  늘린다」가 잡힌다. **상한을 데이터에서 파생**시켜 F5로 네임드를 늘려도 안 낡는다.
func _check_enemy_count(cid: StringName) -> void:
	var ch = _db.get_chapter(cid)
	var floor_n: int = 1 + int(MOB_COUNT[cid])
	var named_max: int = ch.named_pool.size() if ch != null else 0
	var got: int = _enemies().size()
	_check(got >= floor_n,
		"%s: 보스 1 + 잡몹 %d = 최소 %d마리가 섰다 (실제 %d — 밑돌면 자리가 조용히 비었다)"
			% [cid, int(MOB_COUNT[cid]), floor_n, got])
	_check(got <= floor_n + named_max,
		"%s: 최대 %d마리 (보스1+잡몹%d+네임드%d, 실제 %d — 넘으면 굴림이 자리를 늘린 것)"
			% [cid, floor_n + named_max, int(MOB_COUNT[cid]), named_max, got])


## 어떤 `pool_tag`가 **실제로 세울 수 있는** 적 id들 — 「살아 있는 후보」의 정의를 한 곳에 둔다.
## ⚠ 이건 `boss_room`의 굴림 구현이 아니라 **데이터 유효성**이다(굴림 자체는 `test_mob_roll_auto`).
##  후보가 0이면 그 자리는 아무것도 안 세우고 **에러가 0**이다(설계 §6 S1) — 그래서 [1b]가 죽은 항목으로 센다.
func _live_pool_ids(ch, tag: StringName) -> Array:
	var out := []
	for mw in ch.mob_pool:
		if mw == null or mw.pool_tag != tag or mw.weight <= 0:
			continue
		if mw.enemy_id == &"" or mw.enemy_id == ch.boss_enemy_id or _db.get_enemy(mw.enemy_id) == null:
			continue
		out.append(mw.enemy_id)
	return out


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


func _interact_zones() -> Array:
	var out := []
	for z in get_nodes_in_group("interact_zones"):
		if not z.is_queued_for_deletion():
			out.append(z)
	return out


## 나가는 길 전량 (`zone_id == &"exit"`) — 세99에 이게 방의 탈출구 전부다.
func _exits() -> Array:
	var out := []
	for z in _interact_zones():
		if z.zone_id == EXIT_ZONE:
			out.append(z)
	return out


## 🔴 방 안에서 **`_extract`에 이어진** 지점 수 — 「나가는 길이 몇 개인가」의 **zone_id 무관** 정의다.
## `_zone(&"portal")`처럼 값을 박아 재면 **그 값만 피해 되살려도 통과한다**(세99 뮤테이션 실측).
func _extract_wired_count() -> int:
	var n := 0
	for z in _interact_zones():
		for c in z.interacted.get_connections():
			var cal: Callable = c["callable"]
			if cal.get_object() == _room and cal.get_method() == "_extract":
				n += 1
				break
	return n


func _exit_nearest_to(point: Vector2):
	var best = null
	var best_d := INF
	for z in _exits():
		var d: float = z.global_position.distance_to(point)
		if d < best_d:
			best_d = d
			best = z
	return best


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
