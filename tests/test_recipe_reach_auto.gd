extends SceneTree
## 레시피 도달성 자동 검증 — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_recipe_reach_auto.gd
## 재는 것 = 「레시피가 요구하는 재료」 ↔ 「챕터에 실제로 배치된 적·지점이 떨구는 재료」(+ 제작 사슬 폐포).
## 🔴 오른쪽을 「폴더의 적 전부」 스캔으로 바꾸면 그물이 죽는다 — 그 적이 어느 챕터에 서는지를 안 보게 된다
##  (오늘은 폴더 == 무대라 결과가 같아 이 차이가 안 보인다 — 「결과가 같으니」로 되돌리지 마라).
## 🔴 KNOWN_GAPS는 양방향이다 — 없던 구멍이 생겨도, 있던 줄이 도달 가능해져도 빨개진다(한쪽만이면 목록이 영영 안 준다).
## ⚠ 안 재는 것: 속도(병목)·챕터 국소성·확률/수량 · 지점이 실제로 서나(test_landmark_road_auto·test_nest_open_auto)
##  · 굴림 기계(test_mob_roll_auto) · 퀘스트 보상(일회성이라 공급원으로 안 센다). 이 그물은 Db만 읽는다(저장 트리거 없음).
## 주의: -s 모드는 오토로드보다 먼저 컴파일된다 — 오토로드 식별자를 컴파일타임에 참조하지 않는다.


## 지금 일부러 막혀 있는 재료 — {재료 id: 왜 막혔나}. 없는 구멍이 생기면 [3]이, 목록이 낡으면 [4]가 빨개진다.
const KNOWN_GAPS := {
	# 🔴 유일 공급원이던 잡몹 vine이 지워졌다 — 버그가 아니라 「뺀 것」이다(병목을 의도적으로 유지한다).
	#  답은 지점 산출로 때우는 게 아니라 ch2·ch3에 덩굴 몹을 세우는 것이고, 그때 [4]가 이 줄을 지우라고 빨개진다.
	&"mat_vine": "세99 840a7d1이 vine.tres 삭제 · D15로 의도적 유지 · ch2·ch3 몹이 채울 자리",
	# 🔴 유일 공급원이던 네임드 hound_alpha가 무대에서 빠졌다(named_pool이 비었다) — 이것도 「뺀 것」이다.
	#  .tres는 안 지웠으므로 test_progression_auto(레지스트리 전수)는 여전히 생산자를 본다 — 두 그물이 보는 게 다르다.
	&"mat_night_bloom": "세112 R8이 named_pool을 비웠다 · 유일 공급원이 네임드 hound_alpha · 위상 재정의 때 되살아난다",
}

var failures: int = 0
var _db = null

## 진단 캐시 — 항목끼리 나눠 쓴다(같은 수집을 두 번 하지 않는다 = 사본 금지).
var _required: Dictionary = {}        ## {재료 id: [그걸 요구하는 레시피 id, …]}
var _supply: Dictionary = {}          ## {아이템 id: [출처 문자열, …]}  — 무대 드롭 전부
var _supply_permanent: Dictionary = {}## {아이템 id: [출처, …]}         — `until_unlock`이 안 걸린 줄만
var _supply_landmark: Dictionary = {} ## {아이템 id: [출처, …]}         — 지점이 준 것만
var _reach: Dictionary = {}           ## {아이템 id: [출처, …]}         — 무대 드롭 ∪ 제작 사슬 폐포


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(20.0).timeout.connect(func() -> void:
		print("TEST_RECIPE_REACH_TIMEOUT — 20초 초과 (테스트가 중간에 죽었을 수 있다)")
		quit(1))
	await process_frame  # 오토로드 준비 대기
	_db = root.get_node("/root/Db")

	_test_left_side()
	_test_right_side()
	_test_gaps_forward()
	_test_gaps_reverse()
	_test_landmark_contributes()
	_test_supply_is_permanent()

	if failures == 0:
		print("TEST_RECIPE_REACH_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_RECIPE_REACH_FAIL — %d건 실패" % failures)
		quit(1)


# ── [1] 왼쪽 — 레시피가 무엇을 요구하나 ──────────────────────────────────────

## 🔴 개수를 먼저 찍는다 — 레시피가 0장이면 아래가 전부 자명 통과다.
func _test_left_side() -> void:
	print("[1] 왼쪽 = 레시피 inputs 전수")
	var recipes: Array = _db.all_recipes()
	_check(recipes.size() >= 2, "레시피가 %d장 — 0~1이면 아래가 전부 자명 통과다" % recipes.size())

	_required.clear()
	for r: RecipeDef in recipes:
		if r == null:
			continue
		for key: StringName in r.inputs.keys():
			_note(_required, key, String(r.id))
	_check(_required.size() >= 2,
		"요구 재료가 %d종 — 0~1이면 대조가 성립하지 않는다" % _required.size())
	print("    요구 재료: " + _fmt_ids(_required.keys()))


# ── [2] 오른쪽 — 무대에 실제로 서는 것이 무엇을 떨구나 ────────────────────────

## 🔴 「챕터가 부르는 것」만 모은다 — 폴더 스캔으로 바꾸면 아무 챕터도 안 부르는 적이 공급원으로 세어져 그물이 죽는다.
func _test_right_side() -> void:
	print("[2] 오른쪽 = 무대에 선 적·지점의 드롭")
	var chapters: Array = _db.chapters_sorted()
	_check(chapters.size() >= 1, "챕터가 %d장 — 0이면 오른쪽이 통째로 비어 자명 통과다" % chapters.size())

	var enemies: Dictionary = _staged_enemies(chapters)
	var landmarks: Dictionary = _staged_landmarks(chapters)
	_check(enemies.size() >= 1, "무대에 선 적이 %d종 — 0이면 오른쪽이 비어 있다" % enemies.size())
	print("    무대 적: " + _fmt_ids(enemies.keys()))
	print("    무대 지점: " + _fmt_ids(landmarks.keys()))

	# 🔴 챕터가 부르는 id가 Db에 없으면 boss_room이 push_error만 내고 그 자리가 빈 채로 선다(로그에만 남는다).
	for id: StringName in _sorted(enemies.keys()):
		_check(_db.get_enemy(id) != null,
			"무대 적 %s가 Db.enemies에 실재한다 (%s)" % [id, _joined(enemies[id])])
	for id: StringName in _sorted(landmarks.keys()):
		var def := _db.get_landmark(id) as LandmarkDef
		_check(def != null, "무대 지점 %s가 Db.landmarks에 실재한다 (%s)" % [id, _joined(landmarks[id])])
		if def == null:
			continue
		# ⚠ `scene_path`가 비면 `_spawn_landmarks`가 그 슬롯을 건너뛴다 = **산출이 통째로 안 나온다**.
		#  「실제로 서나」 자체는 `test_landmark_road_auto` 몫이라 여기선 데이터 사슬까지만 본다.
		_check(def.scene_path != "" and ResourceLoader.exists(def.scene_path),
			"무대 지점 %s의 scene_path가 실재한다 (비면 그 자리가 안 서서 산출 0)" % id)

	# 드롭 수집 — 적과 지점을 **같은 함수**로 걷는다(굴림 계약이 `DropRoll.roll` 하나인 것과 같은 결).
	_supply.clear()
	_supply_permanent.clear()
	_supply_landmark.clear()
	for id: StringName in _sorted(enemies.keys()):
		var edef := _db.get_enemy(id) as EnemyDef
		if edef != null:
			_collect_drops(edef.drops, "적:" + String(id), false)
	for id: StringName in _sorted(landmarks.keys()):
		var ldef := _db.get_landmark(id) as LandmarkDef
		if ldef != null:
			_collect_drops(ldef.drops, "지점:" + String(id), true)

	_check(_supply.size() >= 1, "무대 드롭이 %d종 — 0이면 아래 대조가 자명하게 빨개진다" % _supply.size())
	print("    무대 드롭: " + _fmt_ids(_supply.keys()))

	# 제작 사슬 폐포 — 데이터 주도(손으로 적는 예외 목록이 아니다). 레시피가 레시피의 결과물을
	# 먹기 시작하면 저절로 돈다. **휴면 여부는 아래 `chained_used`가 찍는다** — 0이면 휴면이다.
	_reach = _closure(_supply)
	var chained: Array = []
	var chained_used: Array = []
	for k: StringName in _reach.keys():
		if _supply.has(k):
			continue
		chained.append(k)
		if _required.has(k):
			chained_used.append(k)   # 🔴 이게 0이 아니어야 사슬이 **실제로** 대조에 영향을 준다
	print("    제작 사슬로 추가된 것: %d종 %s" % [chained.size(), _fmt_ids(chained)])
	print("    그중 실제로 레시피가 요구하는 것: %d종 %s%s"
		% [chained_used.size(), _fmt_ids(chained_used),
			("  ← 0이면 폐포는 휴면이다(완제품을 재료로 먹는 레시피가 없다)"
				if chained_used.is_empty() else "")])

	# 진단 — 퀘스트 보상은 **공급원으로 안 세지만** 다음 사람이 판단할 수 있게 찍어 둔다(머리말 참조).
	var quest_rewards: Dictionary = {}
	for q: QuestDef in _db.all_quests():
		if q == null:
			continue
		for key: StringName in q.reward_items.keys():
			_note(quest_rewards, key, String(q.id))
	print("    (참고) 퀘스트 일회성 보상: " + _fmt_ids(quest_rewards.keys()))


# ── [3] 정방향 — 목록에 없는 새 구멍이 생겼나 ─────────────────────────────────

func _test_gaps_forward() -> void:
	print("[3] 정방향 — 도달 불가가 KNOWN_GAPS 안에 있나")
	var unexpected: Array = []
	for id: StringName in _sorted(_required.keys()):
		if _reach.has(id):
			continue
		if KNOWN_GAPS.has(id):
			continue
		unexpected.append(id)
		# 🔴 진단을 두 갈래로 갈라 준다 — **오타**와 **공급원 소실**은 처방이 다르다.
		var why := ("id가 data/items에 아예 없다 = 오타일 수 있다"
			if _db.get_item(id) == null else "아이템은 실재하는데 무대에 공급원이 없다")
		print("    ↳ %s — %s / 막히는 레시피: %s" % [id, why, _joined(_required[id])])
	_check(unexpected.is_empty(),
		"KNOWN_GAPS에 없는 도달 불가 재료가 0종 (있으면: %s)" % _fmt_ids(unexpected))

	# 막힌 것이 실제로 몇 장을 막고 있나 — 사람이 크기를 가늠하는 줄(검사가 아니라 진단).
	for id: StringName in _sorted(KNOWN_GAPS.keys()):
		if _required.has(id):
			print("    (알려진 구멍) %s → 레시피 %d장 막힘: %s"
				% [id, _required[id].size(), _joined(_required[id])])


# ── [4] 🔴 역방향 — 목록이 낡았나 (「거짓 손잡이」 방지) ─────────────────────

## 이게 없으면 `KNOWN_GAPS`는 **영원히 안 줄어든다**. 두 가지로 낡는다:
##   ⓐ 공급원이 생겼다 → 이제 도달 가능하다
##   ⓑ 그 재료를 요구하는 레시피가 하나도 없다 → 막을 것이 없다
func _test_gaps_reverse() -> void:
	print("[4] 역방향 — KNOWN_GAPS 줄이 아직 유효한가")
	for id: StringName in _sorted(KNOWN_GAPS.keys()):
		var reachable: bool = _reach.has(id)
		if reachable:
			print("    ↳ %s 공급원이 생겼다: %s" % [id, _joined(_reach[id])])
		_check(not reachable,
			"KNOWN_GAPS의 %s가 아직 도달 불가다 (도달 가능해졌으면 이 줄을 지워라)" % id)
		_check(_required.has(id),
			"KNOWN_GAPS의 %s를 요구하는 레시피가 아직 있다 (없으면 이 줄은 죽은 줄이다)" % id)


# ── [5] 지점이 오른쪽에 실제로 기여하나 ──────────────────────────────────────

## 🔴 **자명 통과 방지**: 지점 수집이 통째로 빠져도 적 드롭만으로 [3]이 초록일 수 있다.
##  그래서 「지점이 실제로 무언가를 공급한다」를 따로 못 박는다 — 지점 수집을 지우면 여기가 먼저 빨개진다.
## ⚠ **「지점 전용 재료가 ≥1종」으로 재지 않는다** — 나중에 갑충 몹이 서면 겹쳐서 **거짓 빨강**이 된다.
##  전용 재료는 검사가 아니라 **진단으로만** 찍는다(오늘 무엇이 지점에만 달렸나를 사람이 보라고).
func _test_landmark_contributes() -> void:
	print("[5] 지점 드롭이 오른쪽에 들어왔나")
	_check(not _supply_landmark.is_empty(),
		"무대 지점이 공급하는 아이템이 %d종 (0이면 지점 수집이 빠진 것이다)" % _supply_landmark.size())

	var only_landmark: Array = []
	for id: StringName in _sorted(_supply_landmark.keys()):
		var from_enemy := false
		for src: String in _supply[id]:
			if src.begins_with("적:"):
				from_enemy = true
				break
		if not from_enemy:
			only_landmark.append(id)
	print("    지점에만 달린 재료: %s%s"
		% [_fmt_ids(only_landmark),
			("  ← 이게 비면 [3]이 지점 유무를 구분 못 한다(진단만)" if only_landmark.is_empty() else "")])


# ── [6] 공급이 마르지 않나 (`until_unlock` 단독 공급 금지) ────────────────────

## 🔴 `until_unlock`이 걸린 줄은 **그 codex가 해금되는 순간 드롭이 멈춘다**(`DropRoll.roll`).
##  그런 줄이 어떤 재료의 **유일한** 공급원이면 「한동안 나오다 영영 마르는」 구멍이 되는데,
##  진행 초반엔 정상으로 보여서 아무도 못 찾는다.
## ⚠ 지금 무대에 until_unlock 줄이 0개라 자명 통과다 — 그 수를 같이 찍어 둔다.
func _test_supply_is_permanent() -> void:
	print("[6] 관문(until_unlock) 단독 공급원이 없나")
	var gated := 0
	for id: StringName in _sorted(_supply.keys()):
		if not _supply_permanent.has(id):
			gated += 1
			_check(false, "%s의 공급원이 전부 until_unlock 줄이다 — 해금되면 마른다 (%s)"
				% [id, _joined(_supply[id])])
	print("    무대의 관문 줄 수: %d — 0이면 이 항목은 자명 통과다"
		% (_supply.size() - _supply_permanent.size()))
	_check(gated == 0, "영구 공급원이 없는 재료가 0종")


# ── 수집 헬퍼 ────────────────────────────────────────────────────────────────

## 🔴 boss_room의 스폰 경로를 그대로 따라간다(_spawn_boss·_spawn_mobs·_roll_pool_id·_spawn_named).
## ⚠ _spawn_enemy_at의 보스 id 제외 가드는 흉내내지 않는다 — 흉내내면 그 규칙의 사본이 생기고
##  결과도 안 바뀐다(보스는 boss_spawn으로 어차피 무대에 선다).
func _staged_enemies(chapters: Array) -> Dictionary:
	var out: Dictionary = {}
	for ch: ChapterDef in chapters:
		if ch == null:
			continue
		if ch.boss_enemy_id != &"":
			_note(out, ch.boss_enemy_id, "%s 보스" % ch.id)
		for spawn: MobSpawn in ch.mob_spawns:
			if spawn == null:
				continue
			if spawn.enemy_id != &"":
				_note(out, spawn.enemy_id, "%s 배치" % ch.id)
				continue
			if spawn.pool_tag == &"":
				continue
			for mw: MobWeight in ch.mob_pool:
				# 🔴 `weight <= 0` = 「지금은 빼 둔다」 (`_roll_pool_id`가 지키는 손잡이).
				if mw == null or mw.pool_tag != spawn.pool_tag or mw.enemy_id == &"" or mw.weight <= 0:
					continue
				_note(out, mw.enemy_id, "%s 풀[%s]" % [ch.id, spawn.pool_tag])
		for named: NamedSpawn in ch.named_pool:
			# 🔴 `chance <= 0`이면 `randf() >= chance`가 항상 참이라 **절대 안 뜬다**(기본값이 0.0이다).
			if named == null or named.enemy_id == &"" or named.chance <= 0.0:
				continue
			_note(out, named.enemy_id, "%s 네임드" % ch.id)
	return out


func _staged_landmarks(chapters: Array) -> Dictionary:
	var out: Dictionary = {}
	for ch: ChapterDef in chapters:
		if ch == null:
			continue
		for slot: LandmarkSlot in ch.landmarks:
			if slot == null or slot.landmark_id == &"":
				continue
			_note(out, slot.landmark_id, "%s 지점" % ch.id)
	return out


## 🔴 `DropRoll.roll`이 내는 것과 같은 판정을 쓴다: **`item_id`가 빈 줄은 아이템이 아니다**
##  (그건 두루마리 = `unlock_id` 축이라 재료 공급이 아니다).
func _collect_drops(drops: Array, where: String, is_landmark: bool) -> void:
	for d: DropEntry in drops:
		if d == null or d.item_id == &"":
			continue
		_note(_supply, d.item_id, where)
		if d.until_unlock == &"":
			_note(_supply_permanent, d.item_id, where)
		if is_landmark:
			_note(_supply_landmark, d.item_id, where)


## 제작 사슬 폐포 — inputs가 전부 도달 가능한 레시피의 output도 도달 가능. 고정점까지 반복한다.
func _closure(base: Dictionary) -> Dictionary:
	var reach: Dictionary = base.duplicate(true)
	var grew := true
	while grew:
		grew = false
		for r: RecipeDef in _db.all_recipes():
			if r == null or r.output_id == &"" or r.output_count <= 0 or reach.has(r.output_id):
				continue
			var ok := true
			for key: StringName in r.inputs.keys():
				if not reach.has(key):
					ok = false
					break
			if ok:
				reach[r.output_id] = ["제작:" + String(r.id)]
				grew = true
	return reach


# ── 잡동사니 ─────────────────────────────────────────────────────────────────

func _note(into: Dictionary, key: StringName, src: String) -> void:
	if not into.has(key):
		into[key] = []
	var arr: Array = into[key]
	if not arr.has(src):
		arr.append(src)


## 🔴 StringName 배열의 sort()는 사전순이 아니라 인터닝 순이고 실행마다 흔들린다.
func _sorted(keys: Array) -> Array:
	var out: Array = keys.duplicate()
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


func _fmt_ids(ids: Array) -> String:
	if ids.is_empty():
		return "(없음)"
	var out: Array = []
	for id: StringName in _sorted(ids):
		out.append(String(id))
	return ", ".join(out)


func _joined(arr: Array) -> String:
	var out: Array = []
	for v in arr:
		out.append(String(v))
	out.sort()
	return ", ".join(out)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
