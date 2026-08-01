extends SceneTree
## 던전 구조 스키마 자동 검증 (세99 0단계) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_dungeon_schema_auto.gd
## 전 항목 통과 시 "TEST_DUNGEON_SCHEMA_OK" 출력 후 종료 코드 0.
##
## 검증 대상 = **던전 구조 core 신설분이 실제로 도나**(설계 `docs/takbon-design/dungeon_structure_design.md` §2).
## 신설 = `MobWeight`·`NamedSpawn`·`LandmarkSlot`·`LandmarkDef` 4장 + `ChapterDef` 5필드 +
##        `MobSpawn.pool_tag` + `Db.landmarks` 레지스트리.
## ⚠ **`balance.extract_hold_sec`는 세112 R1에 이 목록에서 빠졌다**(D7 폐기 — [6] 머리말의 묘비).
##
## 🔴🔴 **이 그물의 심장 = [4] 「비면 지금 동작」이 실제로 참인가.**
##  설계가 회귀 0을 그 전제 하나에 걸었다 — 전제가 깨지면 **기존 챕터 3장이 조용히 다르게 돈다**.
##  ⚠ 그 주장은 **데이터 축에만 참**이다(architect 리뷰). 필드를 실제로 채울 때 깨지는 자리는
##  단계 1~2에서 각각 그물을 세운다(설계 §6 S9~S12) — 여기서는 **기본값 계약**만 잰다.
##
## 🔴 여기서 헤드리스가 **실제로 잡는** 것:
##   • `data/landmarks` 폴더가 실재한다 — 없으면 `Db._load_dir`이 **경고만 하고 빈 배열**을 돌려줘
##     「지점 0개인데 에러 0」이 된다(설계 §7 F1이 지목한 자리). 폴더 부재는 정적으로 잴 수 있다.
##   • `Db.landmarks` 레지스트리 + `get_landmark`/`all_landmarks`가 in-memory 주입으로 돈다
##     (세61 콘텐츠 리셋 이후 관행 — 실데이터 0장이라 주입으로 기계를 잰다)
##   • `all_landmarks()`가 **id 사전순** — `StringName.sort()`는 인터닝 순이라 실행마다 흔들린다(세88)
##   • 신설 4장이 인스턴스되고 **기본값이 「지금 동작」**이다 (특히 `NamedSpawn.chance == 0.0`)
##   • 🔴 **기존 챕터 3장이 새 필드를 전부 빈 값으로 들고 있다** = 회귀 0의 실증
## ⚠ 못 잡는 것: 지점(`landmarks`)이 **실제로 도는가**(아직 소비자가 없다 — 단계 3에서 그물이 붙는다).
##  🔴 **굴림·네임드는 세99 단계 2에 켜졌다** — 여기는 기본값만 재고 실제 굴림은
##  `tests/test_mob_roll_auto.gd`(기계) + `tests/test_chapter_auto [1c]`(실데이터)가 진다([5] 머리말 참조).
##
## 공개 계약으로만 검증한다. 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 —
## 오토로드 식별자·모듈 preload 금지. 첫 프레임 후 /root 접근.

var failures: int = 0
var _db = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(20.0).timeout.connect(func() -> void:
		print("TEST_DUNGEON_SCHEMA_TIMEOUT — 20초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기
	_db = root.get_node("/root/Db")

	_test_landmark_dir_exists()
	_test_registry_and_accessors()
	_test_all_landmarks_sorted()
	_test_new_schema_defaults()
	_test_existing_chapters_unchanged()
	_test_balance_and_enum()

	if failures == 0:
		print("TEST_DUNGEON_SCHEMA_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_DUNGEON_SCHEMA_FAIL — %d건 실패" % failures)
		quit(1)


## [1] 🔴 `data/landmarks` 폴더가 실재하나 — 이게 없으면 「지점 0개인데 에러 0」이다.
## `Db.reload()`가 폴더를 **손으로 나열**하므로 폴더와 루프가 **짝**이어야 한다.
func _test_landmark_dir_exists() -> void:
	print("[1] data/landmarks 폴더 + Db 레지스트리")
	var dir := DirAccess.open("res://data/landmarks")
	_check(dir != null, "data/landmarks 폴더가 열린다 (없으면 Db가 짖는다)")
	# ⚠ `landmarks is Dictionary`는 **재지 않는다** — 선언이 `var landmarks: Dictionary = {}`라
	#   거짓이 될 수가 없다(타입을 바꾸면 컴파일 에러). 검출력 0인 PASS는 개수만 부풀린다.

	# 🔴🔴 **여기가 「Db가 그 폴더를 실제로 읽는가」의 유일한 측정자다.**
	# ⚠ 세99 실측 — 이 검사가 없을 때 `reload()`의 landmarks 루프를 **통째로 죽여도 전 항목 그린이었다**
	#   (in-memory 주입은 로드 경로를 안 지난다). 세50 「데이터가 조용히 안 맞는다」의 정확한 재발 자리다.
	#   그래서 실데이터 3장을 넣어 배선을 **측정 가능하게** 만들었다.
	# 🔴 **개수 합계로 재지 마라** — 하나 죽고 하나 살아도 3이다(세50 룬 그물의 교훈). 3종을 개별로 확인한다.
	for id in [&"lm_ruin", &"lm_nest", &"lm_altar"]:
		_check(_db.get_landmark(id) != null, "실데이터 %s가 Db를 거쳐 로드된다" % id)
	var nest = _db.get_landmark(&"lm_nest")
	_check(nest != null and nest.kind == Enums.LandmarkKind.NEST,
		"kind가 .tres에서 파싱된다 (정수 → enum)")


## [2] 접근자 — in-memory 주입으로 기계를 잰다 (실데이터 0장, 세61 관행).
## 🔴 주입한 것은 **반드시 되돌린다** — 안 되돌리면 뒤 항목·뒤 테스트가 오염된다(세83에 실제로 룬을 지웠다).
func _test_registry_and_accessors() -> void:
	print("[2] get_landmark / all_landmarks (주입)")
	var before: Dictionary = _db.landmarks.duplicate()

	var lm := LandmarkDef.new()
	lm.id = &"_t_nest"
	lm.kind = Enums.LandmarkKind.NEST
	lm.title = "시험 둥지"
	_db.landmarks[lm.id] = lm

	var got = _db.get_landmark(&"_t_nest")
	_check(got != null, "주입한 지점을 get_landmark로 찾는다")
	_check(got != null and got.kind == Enums.LandmarkKind.NEST, "kind가 보존된다")
	_check(_db.get_landmark(&"_t_없는것") == null, "미등록 id는 null (기본표 폴백 금지)")

	# 🔴 보상은 DropEntry를 그대로 쓴다 — 새 드롭 기계를 만들면 배타 짝 규칙이 두 벌이 된다.
	var d := DropEntry.new()
	d.item_id = &"coin"
	lm.drops.append(d)
	_check(lm.drops.size() == 1 and lm.drops[0].item_id == &"coin",
		"LandmarkDef.drops가 DropEntry를 담는다 (드롭 기계 재사용)")

	_db.landmarks = before  # 원상복구
	_check(_db.get_landmark(&"_t_nest") == null, "주입을 되돌렸다 (뒤 항목 오염 없음)")


## [3] 🔴 `all_landmarks()`가 **id 사전순**.
## `keys.sort()`를 쓰면 안 된다 — 키가 StringName이라 그 정렬은 사전순이 아니라 **인터닝 순**이고
## 같은 데이터로 두 번 돌려도 순서가 달랐다(세88 실측 — 공방 목록이 실제로 튀었다).
## ⚠ 주입 순서를 **사전순과 일부러 갈리게** 넣는다 — 삽입 순 그대로 돌려줘도 통과하면 검출력이 0이다.
func _test_all_landmarks_sorted() -> void:
	print("[3] all_landmarks id 사전순")
	var before: Dictionary = _db.landmarks.duplicate()

	for id in [&"_t_zz", &"_t_aa", &"_t_mm"]:
		var lm := LandmarkDef.new()
		lm.id = id
		_db.landmarks[id] = lm

	var ids: Array = []
	for l in _db.all_landmarks():
		ids.append(String(l.id))
	var want := ids.duplicate()
	want.sort()   # String 배열이라 이건 **진짜 사전순**이다 (StringName이었다면 인터닝 순)
	_check(ids == want, "삽입 순(zz·aa·mm)과 무관하게 사전순 — 실제: %s" % str(ids))
	_check(ids.size() >= 6, "주입 3 + 실데이터 3이 함께 나온다 (%d개)" % ids.size())

	_db.landmarks = before
	_check(_db.all_landmarks().size() == before.size(), "주입을 되돌렸다 (실데이터 보존)")


## [4] 🔴🔴 **심장 — 신설 필드의 기본값이 「지금 동작」인가.**
## 설계가 회귀 0을 이 전제 하나에 걸었다. 기본값이 밀리면 **아무 데이터도 안 고쳤는데 게임이 달라진다.**
func _test_new_schema_defaults() -> void:
	print("[4] 신설 스키마 기본값 = 「비면 지금 동작」")

	var ms := MobSpawn.new()
	_check(ms.pool_tag == &"", "MobSpawn.pool_tag 기본 = 빈 값 (굴리지 않는다)")
	_check(ms.enemy_id == &"", "MobSpawn.enemy_id 기본은 그대로 빈 값")

	# 🔴 네임드는 **명시적으로 켜야 뜬다**. 기본이 1.0이면 데이터를 안 고쳤는데 매 판 네임드가 선다.
	var ns := NamedSpawn.new()
	_check(is_equal_approx(ns.chance, 0.0), "NamedSpawn.chance 기본 = 0.0 (안 뜬다)")
	_check(ns.at_landmark == &"", "NamedSpawn.at_landmark 기본 = 빈 값 (자유 위치)")

	var mw := MobWeight.new()
	_check(mw.weight == 1, "MobWeight.weight 기본 = 1")
	_check(mw.pool_tag == &"", "MobWeight.pool_tag 기본 = 기본 풀")

	var ls := LandmarkSlot.new()
	_check(ls.position == Vector2.ZERO, "LandmarkSlot.position 기본 = 원점")

	var ld := LandmarkDef.new()
	_check(ld.kind == Enums.LandmarkKind.RUIN, "LandmarkDef.kind 기본 = RUIN")
	_check(ld.scene_path == "", "LandmarkDef.scene_path 기본 = 빈 값")
	_check(ld.drops.is_empty(), "LandmarkDef.drops 기본 = 빈 배열")

	var cd := ChapterDef.new()
	_check(cd.room_scene_path == "", "ChapterDef.room_scene_path 기본 = 빈 값 (공용 씬)")
	_check(cd.mob_pool.is_empty(), "ChapterDef.mob_pool 기본 = 빈 배열 (굴림 없음)")
	_check(cd.named_pool.is_empty(), "ChapterDef.named_pool 기본 = 빈 배열 (네임드 없음)")
	_check(cd.landmarks.is_empty(), "ChapterDef.landmarks 기본 = 빈 배열 (지점 없음)")
	# 💀 `extract_points` 기본값 검사를 세112 R1에 지웠다 — 필드 자체가 core에서 사라졌다.
	# 🔴 이 줄은 **[5]가 「다시 넣지 마라」고 경고해 둔 바로 그 줄인데 [4]에 남아 있었다.**
	#    필드 삭제 뒤 `SCRIPT ERROR: Invalid access to property 'extract_points'`가 나는데도
	#    **`TEST_DUNGEON_SCHEMA_OK`가 찍혔다**(`takbon-verify` §3 침묵 통과) —
	#    잡은 것은 러너의 `OK(에러있음)`이고, **낱개 `_OK` grep이었으면 초록으로 지나갔다.**


## [5] 🔴🔴 **회귀 0의 실증 — 기존 챕터 3장이 「아직 안 켠」 필드를 전부 빈 값으로 들고 있다.**
## [4]가 「새로 만든 인스턴스」를 재는 것과 달리 여기는 **실제 `.tres`가 파싱된 결과**를 잰다.
## ⚠ `.tres`에 새 필드를 쓰지도 않았는데 값이 들어 있으면 스키마 기본값이 잘못 박힌 것이다.
##
## ⚠ **`extract_points`는 세99 단계 1b에 켜졌다가 세112 R1에 죽었다** — 여기 검사는 계속 없다.
##  🔴 **다시 넣지 마라.** 「비어 있다」로 되돌리고 싶어지겠지만(지금 실제로 비었으니 통과한다)
##  그건 **소비자가 0인 필드를 그물이 지키는 것**이라 T3 거짓 손잡이를 굳힌다 — `ChapterDef`에서
##  **필드 자체가 곧 지워진다**(core라 리드 몫). 그때 이 줄이 있으면 리드의 삭제가 빨간불에 막힌다.
##  ⚠ 짝이던 `tests/test_extract_hold_auto`는 **파일째 지워졌다**(R1 — 홀드가 폐기됐다).
##
## 🔴🔴 **`mob_pool`·`named_pool`·`MobSpawn.pool_tag`는 세99 단계 2에 켜졌다 — 같은 절차로 뺐다.**
##  소비자가 생겼다: `boss_room._roll_pool_id`(풀 굴림) · `boss_room._spawn_named`(네임드 굴림).
##  🔴 **살아 있는 그물이 간 곳 둘**(여기 사본을 만들지 마라 — T5):
##   ⓐ `tests/test_mob_roll_auto.gd` — 굴림 **기계**를 잰다(가중치 비례 · `weight<=0` 제외 ·
##      확률 0.0/1.0 양끝 · 🔴 보스 id 제외 가드). in-memory 주입이라 실데이터를 안 본다.
##   ⓑ `tests/test_chapter_auto [1c]` — **실데이터 `.tres`**가 실재하는 적을 가리키고 보스 id를
##      안 물고 확률이 양끝이 아닌지 잰다. ⓐ와 짝이다(기계만 재면 데이터가 비어도 그린이다).
##  ⚠ **`MobSpawn.enemy_id`가 빈 항목이 이제 정상이다** — 그 자리는 `pool_tag`로 굴린다.
##
## 🔴🔴 **`landmarks`는 세99 단계 3에 켜졌다 — 같은 절차로 뺐다**(`extract_points` 선례 그대로).
##  소비자가 생겼다: `boss_room._spawn_landmarks`(지점 세우기) · `boss_room._landmark_road_cells`
##  (입구→지점 흙길). ch1이 `lm_nest` 한 자리를 싣는다.
##  🔴 **살아 있는 그물이 간 곳** — `tests/test_landmark_road_auto.gd`가 **같은 `.tres` 파싱 결과**를
##   「비어 있지 않다 + 지점이 데이터 좌표에 실제로 선다 + 입구에서 거기까지 흙길이 끊김 없이
##   이어진다」로 훨씬 세게 잰다. **여기 사본을 만들지 마라**(T5) — 켜진 축은 그쪽 한 곳이 정본이다.
##  ⚠ 남은 하나(`room_scene_path`)는 **아직 소비자가 없다** — 단계 4에서 켜질 때 같은 절차로
##  여기서 빼고 그쪽에 그물을 세워라.
func _test_existing_chapters_unchanged() -> void:
	print("[5] 기존 챕터 3장 = 아직 안 켠 필드 전부 빈 값 (회귀 0 실증)")
	var chapters = _db.chapters_sorted()
	_check(chapters.size() == 3, "챕터 3장이 로드된다 (파싱 침묵사 그물, 세50)")
	for c in chapters:
		var who := String(c.id)
		_check(c.room_scene_path == "", "%s: room_scene_path 비어 있다 (공용 씬 그대로)" % who)
		# 🔴 기존 배치가 살아 있나 — 새 필드를 더하며 옛 필드를 밀지 않았다는 증명.
		_check(not c.mob_spawns.is_empty(), "%s: mob_spawns가 여전히 차 있다" % who)
		# 🔴 자리 자체는 **여전히 사람이 놓는다**(D5: *"지형은 동일하고 나오는 몬스터들이 랜덤"*).
		#  굴리는 자리든 아니든 좌표는 데이터가 쥐어야 한다 — 전부 원점이면 배치가 죽은 것이다.
		var at_origin := 0
		for m in c.mob_spawns:
			if m.position == Vector2.ZERO:
				at_origin += 1
		_check(at_origin < c.mob_spawns.size(),
			"%s: MobSpawn 좌표가 전부 원점은 아니다 (자리는 굴리지 않는다 — 실제 원점 %d/%d)"
				% [who, at_origin, c.mob_spawns.size()])


## [6] balance 신설 값 + enum.
##
## 🪦 **`extract_hold_sec` 검사 둘은 세112 R1에 지웠다**(「필드가 있다」 + 「> 0이면 D7이 켜져 있다」).
##  D7(3초 꾹 탈출)이 폐기돼 **「홀드가 켜져 있나」가 잴 값어치를 잃었다** — 오히려 이 검사를 남기면
##  🔴 **소비자가 0인 필드를 「살아 있어야 한다」고 강제해 T3 거짓 손잡이를 그물이 지킨다.**
##  ⚠ `balance_data.gd`는 **core라 리드가 지운다** — 여기서 검사를 걷는 것이 그 선행 작업이다
##  (그물이 먼저 놓아 줘야 리드의 삭제가 빨간불 없이 지나간다).
func _test_balance_and_enum() -> void:
	print("[6] Enums.LandmarkKind")
	var bal = load("res://data/balance.tres")
	_check(bal != null, "balance.tres가 로드된다")

	# 🔴 값을 **셋 다 명시**한다 — `.tres`가 정수로 저장하므로 재배열하면 데이터가 조용히 다른 종류가 된다.
	#   ⚠ NEST·ALTAR를 안 적으면 `lm_nest.tres`(kind=1)를 통해 **우연히** 걸릴 뿐이라 의도가 코드에 안 남는다.
	_check(Enums.LandmarkKind.size() == 3, "LandmarkKind가 3종 (RUIN·NEST·ALTAR)")
	_check(int(Enums.LandmarkKind.RUIN) == 0, "RUIN = 0 (끝에만 덧붙여라)")
	_check(int(Enums.LandmarkKind.NEST) == 1, "NEST = 1")
	_check(int(Enums.LandmarkKind.ALTAR) == 2, "ALTAR = 2")
	var altar = _db.get_landmark(&"lm_altar")
	_check(altar != null and altar.kind == Enums.LandmarkKind.ALTAR, "lm_altar.tres의 kind가 ALTAR로 파싱된다")


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
