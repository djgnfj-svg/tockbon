extends SceneTree
## 몹 풀 굴림 · 네임드 자동 검증 — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_mob_roll_auto.gd
## 전 항목 통과 시 "TEST_MOB_ROLL_OK" 출력 후 종료 코드 0.
## 검증 대상 = **굴림 기계가 실제로 도나.** 짝그물 = `tests/test_chapter_auto [1c]`(실데이터가 성립하나) —
##  기계만 재면 데이터가 비어도 그린이고, 데이터만 재면 코드가 굴림을 안 해도 그린이다.
## 🔴🔴 **시드를 고정하지 않는다 — 확률·가중치의 양끝을 주입해 잰다.**
##  전역 랜덤 스트림이 하나뿐이라 seed()를 잡으면 딴 굴림이 같은 스트림을 소비해 flake가 된다:
##   • chance 0.0 = 절대 안 뜬다 · 1.0 = 반드시 뜬다 · weight 0 = 절대 안 뽑힌다 (양끝은 결정적이다)
##   • 기본 확률 → **여러 번 돌려 0 < 개수 < N** (「굳지 않았다」만 잰다 — 비율은 F5가 정한다)
## ⚠ 못 잡는 것: 네임드가 화면에서 커 보이나(scale은 렌더다) · 굴림 비율의 손맛 — F5 몫이다.
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.

## 굴림을 몇 판 돌려 보나 (통계가 아니라 **「굳지 않았다」**를 재는 표본 수).
const ROLL_ROUNDS := 24

var failures: int = 0
var _gs = null
var _db = null
var _scene = null
var _room = null
## 주입 전 원본 — 항목마다 저장하고 끝에 되돌린다.
var _saved: Dictionary = {}


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		print("TEST_MOB_ROLL_TIMEOUT — 60초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_gs = root.get_node("/root/GameState")
	_db = root.get_node("/root/Db")
	_scene = load("res://src/field/boss_room.tscn") as PackedScene

	await _test_no_tag_is_unchanged()
	await _test_tag_rolls_within_pool()
	await _test_weight_zero_never_appears()
	await _test_weight_proportional()
	await _test_boss_id_excluded()
	await _test_named_chance_extremes()
	await _test_named_items_independent()
	await _test_named_sometimes()
	await _test_named_looks_different()

	_restore_all()
	# 🔴 뒷정리 — `_fresh`가 방을 세우며 자동 저장이 돌 수 있어 세이브를 지운다.
	root.get_node("/root/SaveManager").wipe_save()

	if failures == 0:
		print("TEST_MOB_ROLL_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_MOB_ROLL_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 🔴 `pool_tag`가 비면 손으로 박은 자리가 그대로 선다 = 회귀 0.
## 굴림을 켜면서 가장 먼저 깨질 수 있는 게 이것이다(「전부 굴린다」로 짜면 손으로 박은 자리가 사라진다).
func _test_no_tag_is_unchanged() -> void:
	print("[1] pool_tag가 빈 자리 = enemy_id 그대로 (회귀 0)")
	var ch = _db.get_chapter(&"ch1")
	_save(ch)
	# 자리 셋을 전부 손으로 박고 풀은 비운다.
	ch.mob_pool = _typed_pool([])
	ch.named_pool = _typed_named([])
	# ⚠ 자리는 셋을 유지한다 — 재는 건 「몇 종인가」가 아니라 **「박은 자리가 박은 대로 서나」**다.
	ch.mob_spawns = _typed_spawns([
		_spawn(&"hound", Vector2(-200, 300), &""),
		_spawn(&"hound_alpha", Vector2(200, 300), &""),
		_spawn(&"hound", Vector2(0, -400), &""),
	])
	await _fresh(&"ch1")
	# 🔴 정렬은 `_mob_ids()`의 `String()` 비교로만 한다 — `StringName` 배열의 `sort()`는 사전순이
	#  아니라 인터닝 순이라 실행마다 결과가 달라져 그물이 거짓 빨강이 된다.
	var got := _mob_ids()
	_check(got == [&"hound", &"hound", &"hound_alpha"],
		"손으로 박은 셋이 그대로 섰다 (실제 %s)" % str(got))
	_restore_all()


## [2] 🔴 `pool_tag`가 있으면 **그 풀 안의 적만** 선다. 자리는 그대로다 (좌표는 안 굴린다).
func _test_tag_rolls_within_pool() -> void:
	print("[2] pool_tag 자리 = 풀 안의 적만 · 좌표는 그대로")
	var ch = _db.get_chapter(&"ch1")
	_save(ch)
	ch.named_pool = _typed_named([])
	ch.mob_pool = _typed_pool([
		_weight(&"hound", 1, &"t"),
		_weight(&"hound_alpha", 1, &"t"),
	])
	var at := Vector2(-333, 222)
	ch.mob_spawns = _typed_spawns([_spawn(&"", at, &"t")])

	var seen := {}
	for i in ROLL_ROUNDS:
		await _fresh(&"ch1")
		var mobs := _mobs()
		if mobs.size() != 1:
			_check(false, "자리 하나에 한 마리가 선다 (실제 %d)" % mobs.size())
			break
		seen[mobs[0].enemy_id] = true
		# 🔴 좌표는 **굴리지 않는다** — 지형은 그대로고 나오는 적만 랜덤이다.
		if not _at_spot(mobs[0], at):
			_check(false, "🔴 좌표가 MobSpawn.position 그대로다 (기대 %s / 실제 %s · 배회 여유 밖)" % [at, mobs[0].position])
			break
	var ids: Array = seen.keys()
	ids.sort_custom(func(a, b) -> bool: return String(a) < String(b))
	_check(ids.size() > 0, "풀 자리가 실제로 뭔가를 세웠다 (0이면 설계 §6 S1 — 에러 0의 빈 방)")
	for id in ids:
		_check(id == &"hound" or id == &"hound_alpha",
			"🔴 풀 밖의 적(%s)이 안 섰다 (풀 = hound·hound_alpha)" % id)
	_check(ids.size() == 2,
		"%d판 안에 풀의 둘이 다 나왔다 = 굴림이 굳지 않았다 (실제 %s)" % [ROLL_ROUNDS, str(ids)])
	_restore_all()


## [3] 🔴🔴 **`weight <= 0`은 절대 안 뽑힌다** — 「빼려면 지우지 말고 0으로」가 거짓 손잡이가 되면 안 된다.
## 🔴🔴 **ⓑ가 검출력의 심장이다**: ⓐ만 두고 `weight <= 0` 필터를 뮤테이션으로 지워도 **그린이다**
##  (누적 뽑기가 0짜리를 폭 0의 구간으로 만들어 우연히 안 뽑는다). 진짜 고장은 **음수가 합계를 깎아**
##  `total <= 0`을 만드는 것이고, 그러면 **그 자리들이 통째로 빈 채 서며 에러가 0**이다.
## 🔴 **ⓐ를 지우지는 마라** — 균등 뽑기 등으로 구현이 바뀌는 날 ⓐ가 계약을 다시 잡는다(지금은 자명 통과다).
func _test_weight_zero_never_appears() -> void:
	print("[3] weight <= 0 — ⓐ 안 뽑힌다 · ⓑ 🔴 음수가 풀을 통째로 죽이지 않는다")
	var ch = _db.get_chapter(&"ch1")
	_save(ch)
	ch.named_pool = _typed_named([])
	# ⓐ 0·음수는 안 나온다 (⚠ 위 머리말 — 지금 구현에선 자명 통과다)
	# ⚠ `gale`은 ch2의 보스지만 ch1에선 그냥 「다른 적 id」다 — 여기서 재는 건 가중치이지
	#  보스 제외가 아니다(그건 [5]가 ch1의 `boss_enemy_id`로 잰다).
	ch.mob_pool = _typed_pool([
		_weight(&"hound", 5, &"t"),
		_weight(&"hound_alpha", 0, &"t"),   # 빼 둔 것
		_weight(&"gale", -3, &"t"),         # 음수도 같다
	])
	ch.mob_spawns = _typed_spawns([
		_spawn(&"", Vector2(-200, 300), &"t"),
		_spawn(&"", Vector2(200, 300), &"t"),
		_spawn(&"", Vector2(0, -400), &"t"),
	])
	var bad := 0
	var total := 0
	for i in ROLL_ROUNDS:
		await _fresh(&"ch1")
		for m in _mobs():
			total += 1
			if m.enemy_id == &"hound_alpha" or m.enemy_id == &"gale":
				bad += 1
	_check(total >= ROLL_ROUNDS, "굴림이 실제로 돌았다 (%d마리 표본 — 0이면 아래가 자명 통과다)" % total)
	_check(bad == 0, "🔴 weight 0·음수인 적이 %d/%d번 나왔다 (0이어야 한다)" % [bad, total])

	# ⓑ 🔴🔴 음수가 **합계를 깎아** 풀을 죽이지 않는다 — 필터를 지우면 여기가 빨개진다.
	ch.mob_pool = _typed_pool([
		_weight(&"hound", 2, &"t"),
		_weight(&"gale", -3, &"t"),   # 필터가 없으면 total = −1 → 자리가 통째로 빈다
	])
	ch.mob_spawns = _typed_spawns([_spawn(&"", Vector2(0, 300), &"t")])
	var stood := 0
	for i in 6:
		await _fresh(&"ch1")
		var mobs := _mobs()
		if mobs.size() == 1 and mobs[0].enemy_id == &"hound":
			stood += 1
	_check(stood == 6,
		"🔴🔴 음수 항목이 섞여도 살아 있는 항목이 매 판 선다 (6판 중 %d — 밑돌면 음수가 합계를 깎아 자리가 빈 것)"
			% stood)
	_restore_all()


## [4] 🔴🔴 가중치가 **비례로** 먹는다 — 굴림이 가중치를 아예 안 보는 구현(균등 뽑기)을 잡는다.
## 🔴 1:49로 주고 여러 판을 본다 — 비례면 큰 쪽이 압도하고(약 98%), **균등이면 반반**이라
##  「큰 쪽이 작은 쪽의 5배 이상」에서 갈린다. ⚠ 비율 자체(6:3이 맞나)는 **안 잰다** — F5 몫이다.
## ⚠ 확률 검사지만 실질 결정적이다: 비례일 때 이 문턱을 밑돌 확률이 천문학적으로 작다.
func _test_weight_proportional() -> void:
	print("[4] 가중치 비례 — 1:49면 큰 쪽이 압도한다 (균등 뽑기면 반반이라 빨개진다)")
	var ch = _db.get_chapter(&"ch1")
	_save(ch)
	ch.named_pool = _typed_named([])
	ch.mob_pool = _typed_pool([
		_weight(&"hound_alpha", 1, &"t"),
		_weight(&"hound", 49, &"t"),
	])
	ch.mob_spawns = _typed_spawns([
		_spawn(&"", Vector2(-200, 300), &"t"),
		_spawn(&"", Vector2(200, 300), &"t"),
		_spawn(&"", Vector2(0, -400), &"t"),
	])
	var few := 0
	var many := 0
	for i in ROLL_ROUNDS:
		await _fresh(&"ch1")
		for m in _mobs():
			if m.enemy_id == &"hound_alpha":
				few += 1
			elif m.enemy_id == &"hound":
				many += 1
	_check(few + many >= ROLL_ROUNDS, "표본이 모였다 (%d마리)" % (few + many))
	_check(many > few * 5,
		"🔴🔴 weight 49가 weight 1을 압도한다 (49→%d마리 · 1→%d마리 — 반반이면 가중치를 안 보는 것)"
			% [many, few])
	_restore_all()


## [5] 🔴🔴 **보스 id 제외 가드** — `boss_room._on_enemy_died`의 클리어 판정이 **`enemy_id` 일치 한 줄**이라,
##  풀·네임드에 `boss_enemy_id`가 섞이면 **잡몹 한 마리에 `chapter_clear_*` + 보상 룬이 조용히 나간다(에러 0)**.
## 🔴 두 문(잡몹·네임드)을 **같이** 잰다 — 가드가 `_spawn_enemy_at` 한 곳이라 지우면 둘 다 빨개진다.
func _test_boss_id_excluded() -> void:
	print("[5] 🔴🔴 풀·네임드에 보스 id를 넣어도 잡몹으로 안 선다 (§6 S9)")
	var ch = _db.get_chapter(&"ch1")
	_save(ch)
	var boss_id: StringName = ch.boss_enemy_id
	# 풀은 **보스 id 하나뿐** — 가드가 없으면 그 자리에 보스가 한 마리 더 선다.
	ch.mob_pool = _typed_pool([_weight(boss_id, 5, &"t")])
	ch.named_pool = _typed_named([_named(boss_id, 1.0, Vector2(400, 100))])
	ch.mob_spawns = _typed_spawns([
		_spawn(&"", Vector2(-200, 300), &"t"),
		_spawn(boss_id, Vector2(200, 300), &""),   # 손으로 박아도 막힌다
	])
	await _fresh(&"ch1")
	var bosses := 0
	for e in _enemies():
		if e.enemy_id == boss_id:
			bosses += 1
	_check(bosses == 1,
		"🔴🔴 방에 보스 id(%s)가 **정확히 하나**다 = 스폰이 보스를 세우지 않는다 (실제 %d마리)"
			% [boss_id, bosses])
	_check(_mobs().is_empty(),
		"보스 id뿐인 풀·네임드·직접배치는 잡몹을 하나도 안 세운다 (실제 %d)" % _mobs().size())
	_restore_all()


## [6] 🔴 네임드 확률 **양끝** — 0.0이면 절대 안 뜨고 1.0이면 반드시 뜬다.
## 확률이 어느 쪽으로든 굳어도 **에러가 없다**. 자유 위치(`position`) 해석도 여기서 같이 잰다.
## 🔴🔴 ⓒ = **`at_landmark` 해석**. 자리가 여럿일 때의 계약과 미등록 id는
##  `tests/test_chest_open_auto.gd`가 잰다 — 여기는 **「해석이 켜져 있나」** 하나만 본다.
func _test_named_chance_extremes() -> void:
	print("[6] 네임드 확률 양끝 (0.0 = 절대 · 1.0 = 반드시) + 자유 위치 + at_landmark = 지점 좌표")
	var ch = _db.get_chapter(&"ch1")
	_save(ch)
	ch.mob_pool = _typed_pool([])
	ch.mob_spawns = _typed_spawns([])

	# ⓐ 0.0 — 여러 판을 돌려도 한 번도 안 뜬다
	ch.named_pool = _typed_named([_named(&"hound_alpha", 0.0, Vector2(300, 200))])
	var seen0 := 0
	for i in ROLL_ROUNDS:
		await _fresh(&"ch1")
		seen0 += _mobs().size()
	_check(seen0 == 0, "🔴 chance 0.0은 %d판 내내 안 뜬다 (실제 %d마리)" % [ROLL_ROUNDS, seen0])

	# ⓑ 1.0 — 매 판 뜬다 + 지정한 자유 위치에 선다
	var at := Vector2(-480, -640)
	ch.named_pool = _typed_named([_named(&"hound_alpha", 1.0, at)])
	var rounds := 5
	var stood := 0
	var placed := 0
	for i in rounds:
		await _fresh(&"ch1")
		var mobs := _mobs()
		if mobs.size() == 1 and mobs[0].enemy_id == &"hound_alpha":
			stood += 1
			if _at_spot(mobs[0], at):
				placed += 1
	_check(stood == rounds, "🔴 chance 1.0은 %d판 전부 뜬다 (실제 %d판)" % [rounds, stood])
	_check(placed == rounds,
		"🔴 네임드가 NamedSpawn.position(%s)에 선다 (%d/%d판 — 어긋나면 원점에 서는 것)"
			% [at, placed, rounds])

	# ── ⓒ 🔴🔴 **at_landmark = 그 지점 자리에 선다**
	# 🔴 **`NamedSpawn.position`이 아니라 지점 좌표에 선다** — 둘을 **일부러 다르게** 준다.
	#  같은 값을 주면 해석이 통째로 죽어도(옛 자유 위치 경로로 새도) 그린이라 검출력이 0이 된다.
	var lm_at := Vector2.ZERO
	for slot in ch.landmarks:
		if slot != null and slot.landmark_id == &"lm_nest":
			lm_at = slot.position
	_check(lm_at != Vector2.ZERO and lm_at != at,
		"ch1이 lm_nest를 %s에 세우고 그게 자유 위치 %s와 다르다 (같으면 아래가 자명 통과다)" % [lm_at, at])
	var ns = _named(&"hound_alpha", 1.0, at)
	ns.at_landmark = &"lm_nest"
	ch.named_pool = _typed_named([ns])
	await _fresh(&"ch1")
	var at_lm := _mobs()
	_check(at_lm.size() == 1,
		"🔴 at_landmark 네임드가 정확히 하나 선다 (실제 %d — 0이면 해석이 안 켜진 것이다)" % at_lm.size())
	if at_lm.size() == 1:
		_check(_at_spot(at_lm[0], lm_at),
			"🔴🔴 네임드가 **지점 좌표** %s에 선다 (실제 %s — 자유 위치 %s면 해석이 안 걸린 것이고 원점이면 자리를 못 찾은 것이다)"
				% [lm_at, at_lm[0].position, at])
	_restore_all()


## [7] 🔴 네임드는 **항목마다 독립**이다 — 「하나도 안 뜸」이 정상 결과이려면
## 항목들이 한 번의 굴림을 공유하면 안 된다. 확정 하나 + 절대 하나 → **정확히 하나만** 선다.
func _test_named_items_independent() -> void:
	print("[7] 네임드 항목마다 독립 굴림 (확정 1 + 절대 1 → 정확히 하나)")
	var ch = _db.get_chapter(&"ch1")
	_save(ch)
	ch.mob_pool = _typed_pool([])
	ch.mob_spawns = _typed_spawns([])
	# ⚠ 확정 쪽은 `hound`로 세운다 — `NamedSpawn`은 아무 적 id나 세울 수 있고,
	#  여기서 재는 건 「굴림이 항목마다 따로인가」다.
	ch.named_pool = _typed_named([
		_named(&"hound", 1.0, Vector2(-300, 100)),
		_named(&"hound_alpha", 0.0, Vector2(300, 100)),
	])
	await _fresh(&"ch1")
	var ids := _mob_ids()
	_check(ids == [&"hound"],
		"확정 항목만 서고 0.0 항목은 안 선다 = 굴림이 항목마다 따로다 (실제 %s)" % str(ids))
	_restore_all()


## [8] 🔴 기본 확률(양끝이 아닌 값)로 여러 판 — **0도 N도 아니다**.
## 「항상 뜸 / 절대 안 뜸」으로 굳는 고장을 잡는다. ⚠ 비율은 **안 잰다**(F5 몫).
## ⚠ 확률 검사라 이론상 흔들린다 — 0.5로 24판이면 양끝이 나올 확률이 각각 2^-24라 실질 0이다.
func _test_named_sometimes() -> void:
	print("[8] 기본 확률 — %d판에 0도 %d도 아니다 (「가끔 뜬다」가 살아 있다)" % [ROLL_ROUNDS, ROLL_ROUNDS])
	var ch = _db.get_chapter(&"ch1")
	_save(ch)
	ch.mob_pool = _typed_pool([])
	ch.mob_spawns = _typed_spawns([])
	ch.named_pool = _typed_named([_named(&"hound_alpha", 0.5, Vector2(-300, 100))])
	var hits := 0
	for i in ROLL_ROUNDS:
		await _fresh(&"ch1")
		hits += _mobs().size()
	_check(hits > 0, "🔴 %d판 중 %d판에 떴다 (0이면 확률이 0으로 굳은 것)" % [ROLL_ROUNDS, hits])
	_check(hits < ROLL_ROUNDS,
		"🔴 %d판 중 %d판에만 떴다 (전판이면 확률이 1로 굳은 것)" % [ROLL_ROUNDS, hits])
	_restore_all()


## [9] 🔴🔴 **네임드는 「생김새」로 구별된다** — 덩치(`params.size` = 루트 scale)와 몸 색조(`params.tint`).
## 🔴 **바탕 잡몹과 같은 프레임에서 비교한다** — 절대값을 박으면 튜닝할 때마다 거짓 빨강이 나고,
##  계약이 「크다」가 아니라 **「바탕보다 크다」**이기 때문이다.
## 🔴 실데이터의 `tint` 소비자가 0곳이라 **주입해서** 기계를 잰다 — 안 재면 곧장 거짓 손잡이가 된다.
##  ⚠ **수단과 계약이 갈렸다**: 「바탕과 다르게 보인다」(계약)는 **실데이터로 따로** 잰다 —
##  수단(tint)으로만 재면 **더 나은 수단(전용 스프라이트)으로 고쳤는데 여기만 빨개진다**.
## ⚠ `params.color`와 헷갈리지 마라 — `color`는 **죽음 퍼프 색**이라 몸을 안 물들인다.
## 🔴 상태이상 틴트와의 **곱셈 합성**도 여기가 유일한 측정자다 — 대입으로 되돌리면 몸 색조가
##  첫 상태이상 한 번에 영영 지워지는데 **에러가 0**이다(`forest_enemy._refresh_tint` 머리말).
## ⚠ **「화면에서 커 보이나」는 못 잰다** — scale은 렌더라 F5·MCP 스샷 몫이다.
func _test_named_looks_different() -> void:
	print("[9] 네임드 생김새 — 바탕 잡몹보다 크고 몸 색조가 다르다 (빛이 아니라 생김새)")
	var ch = _db.get_chapter(&"ch1")
	_save(ch)
	ch.mob_pool = _typed_pool([])
	ch.named_pool = _typed_named([_named(&"hound_alpha", 1.0, Vector2(-300, 100))])
	ch.mob_spawns = _typed_spawns([_spawn(&"hound", Vector2(300, 100), &"")])
	# 🔴 tint 기계는 **주입으로 잰다** — 실데이터 소비자가 0곳이어도 손잡이 생존을 증명한다.
	#  ⚠ `_fresh` **전에** 넣어야 스폰이 읽는다 · 끝에서 원본대로 되돌린다.
	var alpha_def = _db.get_enemy(&"hound_alpha")
	var tint_had: bool = alpha_def.params.has("tint")
	var tint_old = alpha_def.params.get("tint", null)
	alpha_def.params["tint"] = Color(0.85, 0.7, 0.95, 1.0)
	await _fresh(&"ch1")

	var base_node = null
	var named_node = null
	for m in _mobs():
		if m.enemy_id == &"hound":
			base_node = m
		elif m.enemy_id == &"hound_alpha":
			named_node = m
	if base_node == null or named_node == null:
		_check(false, "바탕 잡몹(hound)과 네임드(hound_alpha)가 둘 다 섰다")
		_restore_all()
		return

	_check(named_node.scale.x > base_node.scale.x,
		"🔴 네임드가 바탕보다 크다 (바탕 ×%.2f / 네임드 ×%.2f — params.size가 곧 히트박스·그림자다)"
			% [base_node.scale.x, named_node.scale.x])

	var base_vis := base_node.get_node_or_null(^"Visual") as CanvasItem
	var named_vis := named_node.get_node_or_null(^"Visual") as CanvasItem
	if base_vis == null or named_vis == null:
		_check(false, "Visual 노드를 찾았다 (구조가 바뀌면 이 그물이 죽는다)")
		_restore_all()
		return
	# 🔴 바탕은 **한 톨도 안 달라져야 한다** — `params.tint`가 없는 적들의 회귀 0 실증.
	_check(_rgb(base_vis.modulate).is_equal_approx(Color.WHITE),
		"🔴 `tint`가 없는 잡몹의 몸 색조는 흰색 그대로다 = 기존 적 회귀 0 (실제 %s)" % base_vis.modulate)
	_check(not _rgb(named_vis.modulate).is_equal_approx(Color.WHITE),
		"🔴 주입한 `tint`가 화면까지 닿는다 = 손잡이가 살아 있다 (실제 %s)" % named_vis.modulate)

	# 🔴🔴 계약은 **「네임드가 바탕과 다르게 보인다」**이지 「tint가 걸렸다」가 아니다 —
	#  수단으로만 재면 더 나은 수단(전용 스프라이트)으로 고쳤는데 여기가 빨개진다.
	#  🔴 **실데이터로 잰다** — 위 주입값을 쓰면 자명 통과가 된다(그래서 `tint_had`가 원본 기준이다).
	var base_par: Dictionary = _db.get_enemy(&"hound").params
	var sprite_differs: bool = alpha_def.params.get("sprite", "") != base_par.get("sprite", "")
	var size_differs: bool = alpha_def.params.get("size", 1.0) != base_par.get("size", 1.0)
	_check(sprite_differs or size_differs or tint_had,
		"🔴 네임드가 바탕과 **데이터에서** 갈린다 (그림 %s · 크기 %.2f vs %.2f · 원본 tint %s — 셋 다 같으면 「같은 적」이다)"
			% ["다름" if sprite_differs else "같음",
				alpha_def.params.get("size", 1.0), base_par.get("size", 1.0), tint_had])

	# 🔴🔴 상태이상이 들어와도 **몸 색조가 안 지워진다**(곱셈 합성). 대입으로 되돌리면 여기가 빨개진다.
	#  ⚠ 상태를 실제로 얹어 `_refresh_tint`를 태운다 — 값을 직접 읽으면 합성 경로를 안 지난다.
	var before: Color = named_vis.modulate
	named_node.take_hit(1.0, 0, Enums.Status.BURN, 3.0)
	await process_frame
	var after: Color = named_vis.modulate
	_check(not _rgb(after).is_equal_approx(Color.WHITE),
		"🔴🔴 상태이상 틴트가 들어와도 몸 색조가 안 지워진다 (%s → %s — 흰색이면 대입으로 덮인 것)"
			% [before, after])
	# 🔴 주입 원상복구 — 안 되돌리면 뒤 항목·뒤 테스트가 오염된다(`_save`/`_restore_all`과 같은 이유).
	#  ⚠ **키를 지우는 쪽까지 해야 한다** — 대입만 되돌리면 원래 없던 `tint` 키가 남는다.
	if tint_had:
		alpha_def.params["tint"] = tint_old
	else:
		alpha_def.params.erase("tint")
	_restore_all()


# ── 헬퍼 ──

## 🔴🔴 **알파를 뺀 rgb만 본다 — 통째 비교로 되돌리지 마라.** 알파엔 딴 주인(분산 `_alpha_now`)이 있어
##  `not ...is_equal_approx(WHITE)` 형태 둘이 **알파가 1이 아니기만 해도 참**이 되고,
##  `tint`가 화면에 안 닿아도(= 손잡이가 죽어도) 초록이 된다.
## 🔴 **셋을 다 좁혀야 한다 — 첫 줄만 고치면 나머지 둘이 자명 통과가 된다.**
## ⚠ 알파 축은 `test_enemy_ai_auto [3b]`가 잰다 — 여기서 알파를 다시 재려 하지 마라.
func _rgb(c: Color) -> Color:
	return Color(c.r, c.g, c.b)


## 🔴 주입 전 원본을 통째로 저장한다 — `Db.get_chapter`는 **공유 리소스**를 돌려주므로
##  안 되돌리면 뒤 항목·뒤 테스트가 오염된다(test_dungeon_schema [2] 선례).
func _save(ch) -> void:
	if _saved.has(ch.id):
		return
	_saved[ch.id] = {
		"spawns": ch.mob_spawns.duplicate(),
		"pool": ch.mob_pool.duplicate(),
		"named": ch.named_pool.duplicate(),
	}


func _restore_all() -> void:
	for cid in _saved:
		var ch = _db.get_chapter(cid)
		if ch == null:
			continue
		ch.mob_spawns = _saved[cid]["spawns"]
		ch.mob_pool = _saved[cid]["pool"]
		ch.named_pool = _saved[cid]["named"]
	_saved.clear()


func _spawn(id: StringName, at: Vector2, tag: StringName):
	var s = MobSpawn.new()
	s.enemy_id = id
	s.position = at
	s.pool_tag = tag
	return s


func _weight(id: StringName, w: int, tag: StringName):
	var mw = MobWeight.new()
	mw.enemy_id = id
	mw.weight = w
	mw.pool_tag = tag
	return mw


func _named(id: StringName, chance: float, at: Vector2):
	var ns = NamedSpawn.new()
	ns.enemy_id = id
	ns.chance = chance
	ns.position = at
	return ns


## 🔴 `@export var x: Array[T]`에 대입하려면 **같은 타입**이어야 한다 — 느슨한 Array를 넣으면
##  런타임에 거부되고(에러 한 줄) 값이 조용히 안 바뀐다. 그래서 타입 배열로 감싸 넘긴다.
func _typed_spawns(items: Array) -> Array[MobSpawn]:
	var out: Array[MobSpawn] = []
	for it in items:
		out.append(it)
	return out


func _typed_pool(items: Array) -> Array[MobWeight]:
	var out: Array[MobWeight] = []
	for it in items:
		out.append(it)
	return out


func _typed_named(items: Array) -> Array[NamedSpawn]:
	var out: Array[NamedSpawn] = []
	for it in items:
		out.append(it)
	return out


## 매번 **새 방**에서 시작한다 (test_chapter_auto._fresh 이관 — 앞 방을 남기면 플레이어가 둘이 되고
## EventBus 수신자도 둘이 된다).
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
	current_scene = _room
	await process_frame


func _enemies() -> Array:
	var out := []
	for n in get_nodes_in_group("enemies"):
		if not n.is_queued_for_deletion():
			out.append(n)
	return out


## 🔴 보스를 뺀 것 = 잡몹 + 네임드. 보스는 `_spawn_boss`가 세우므로 굴림 검사에서 빼야 한다.
func _mobs() -> Array:
	var ch = _db.get_chapter(_gs.pending_chapter)
	var boss_id: StringName = ch.boss_enemy_id if ch != null else &""
	var out := []
	for n in _enemies():
		if n.enemy_id != boss_id:
			out.append(n)
	return out


func _mob_ids() -> Array:
	var out := []
	for n in _mobs():
		out.append(n.enemy_id)
	out.sort_custom(func(a, b) -> bool: return String(a) < String(b))
	return out


## 🔴 적이 **배회해서** 좌표 완전 일치로는 「데이터가 말한 자리에 섰나」를 못 잰다
##  (스폰 다음 물리 틱부터 `patrol_speed`만큼 흘러간다).
## 🔴 **여유를 상수로 박지 마라 — 그 몸의 `patrol_radius`에서 파생시킨다.** 그러면
##  ⓐ 사용자가 배회를 조여도 **거짓 빨강**이 안 나고 ⓑ **검출력은 그대로**다: 이 그물이 잡으려는
##  오답(원점 · 자유 위치 · 다른 슬롯)은 전부 **수백 px** 떨어져 있다.
## ⚠ 배회를 안 하는 몸(`patrol_radius` 없음)은 여유가 `SPOT_EPS`뿐이라 **사실상 완전 일치**다.
const SPOT_EPS := 1.0

func _at_spot(mob, want: Vector2) -> bool:
	var def = _db.get_enemy(mob.enemy_id)
	var r: float = float(def.params.get("patrol_radius", 0.0)) if def != null else 0.0
	return mob.position.distance_to(want) <= r + SPOT_EPS


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
