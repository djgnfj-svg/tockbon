extends SceneTree
## 마나 폭발(죽음 연출) 자동 검증 (세100) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_mana_burst_auto.gd
## 전 항목 통과 시 "TEST_MANA_BURST_OK" 출력 후 종료 코드 0.
##
## 🔴🔴 **헤드리스가 못 재는 것과 재는 것을 갈라 놨다**(`test_charge_telegraph_auto`와 같은 규율).
##   못 잰다 = 「푸른가 · 터졌다로 읽히나 · 밀도가 맞나」
##            → `tools/vfx_shot.gd -- death`(격자 PNG)와 **F5**의 몫이다.
##   잰다   = ⓐ **적이 사라진 뒤에도 연출이 사나** ⓑ **덩치에 따라 커지나**
##            ⓒ 🔴 **파편이 플레이어에게 「안」 가나** ⓓ **실제로 흩어지나** ⓔ 스스로 죽나
##            ⓕ 🔴 **처치가 마나를 안 주나**.
##
## 🔴🔴 **ⓒ·ⓕ는 「일부러 안 하는 것」을 지키는 그물이다** — 사용자가 세100에 각하했다:
##   *"잠깐 빨려오는건 없음 … 마나가 들어오는건 없음"* · *"몬스터 잡아서 마나회복하는것도 없어"*.
##   **일부러 안 하는 것은 그물이 없으면 조용히 뒤집힌다** — 다음 사람이 *"연출이 있으니 수치도
##   주자"*로 되돌리는 게 자연스럽기 때문이다(선례 = `test_progression_auto`의 「관문 0줄」 자리).
##   그래서 이 둘은 **없음을 적극적으로 증명한다**: 수렴 궤적이 생기면 [4]가, 마나가 늘면 [8]이 빨개진다.
##
## 🔴 ⓓ도 같이 있어야 한다. ⓒ만 재면 **파편이 제자리에 굳어도 초록**이다(안 가면 통과니까) —
##   「안 온다」와 「흩어진다」는 **다른 문장**이고 둘 다 계약이다.
##
## 🔴 **공개 API로만** 검증한다 (takbon-verify §3 · `hitbox_radius()`·`charge_band_reach()` 선례):
##   `shard_count()` · `burst_radius()` · `shard_positions()` · `progress()` · `z_index`.
##   내부 필드(`_t`·`_angles`)는 리팩터 때 옮겨 다녀 계약이 아니다 — 안 더듬는다.
##
## ⚠ **시간은 물리 프레임으로 센다** — `mana_burst`가 `_physics_process`로 도는 이유가 이것이다
##   (거기 머리말). `_process`였다면 `-s`의 delta가 제멋대로라 「얼마나 흩어졌나」를 못 잰다.
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

## ⚠ 시트는 살아 있는 PNG를 빌려 쓴다 — 재는 건 **크기 파생**이지 그림이 아니다.
## 🔴 **높이가 다른 두 장인 것이 의도다**: 64 ↔ 32라 「프레임 한 변이 파생원인가」를 잴 수 있다.
const SHEET_64 := "res://assets/sprites/enemies/hound.png"        ## 512×64 → 한 변 64
const SHEET_32 := "res://assets/sprites/enemies/slime_elite.png"  ## 128×32 → 한 변 32

## `mana_burst`의 수명(`OUT_SEC + FADE_SEC`)보다 넉넉한 물리 프레임 예산. 🔴 **숫자를 계약으로 삼지 않는다** —
## 항목마다 「노드가 살아 있는 동안」으로 끊는다(상수를 조이면 그물이 거짓 빨강이 되지 않게).
const LIFE_BUDGET := 60

var failures: int = 0
var _db = null
var _enemy_scene = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		print("TEST_MANA_BURST_TIMEOUT — 90초 초과")
		quit(1))
	await process_frame

	_db = root.get_node("/root/Db")
	_enemy_scene = load("res://src/field/forest_enemy.tscn") as PackedScene

	# 🔴 `current_scene`이 곧 폭발의 집이다 — 안 세우면 `_spawn_death_burst`가 조용히 return하고
	#   **전 항목이 「폭발이 없다」로 빨개진다**(그때 원인은 연출이 아니라 이 두 줄이다).
	var container := Node2D.new()
	root.add_child(container)
	current_scene = container

	await _test_outlives_the_body()
	await _test_size_drives_burst()
	await _test_boss_is_bigger()
	await _test_shards_do_not_home()
	await _test_shards_scatter_and_rise()
	await _test_self_lifetime()
	await _test_multi_kill()
	await _test_kill_grants_no_mana()

	if failures == 0:
		print("TEST_MANA_BURST_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_MANA_BURST_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 🔴🔴 **적이 사라진 뒤에도 폭발이 산다** — 설계 §9가 지정한 계약 그대로다.
## 적은 `_die`에서 곧장 `queue_free`되므로 연출을 **적의 자식**으로 붙이면 같은 프레임에 증발한다
## (죽음 연출인데 죽는 순간 사라지는 자리 — 에러 0). 그래서 `current_scene` 소유가 계약이다.
##
## 🔴 **z == 50도 여기서 잰다** — `vfx.gd`의 `VFX_Z := 55`가 *"죽음 연출(50) 위로"*를 근거로 든다.
##  50을 올리면 반응 링·감전이 폭발 **아래**로 들어가 「박혔다 → 퍼졌다」 순서가 뒤집힌다(감사 T4).
func _test_outlives_the_body() -> void:
	print("[1] 적이 free된 뒤에도 폭발이 산다 — 씬 소유 · z == 50")
	_inject(&"mb_probe", SHEET_64)
	var e = await _spawn(&"mb_probe", Vector2.ZERO)
	var stub := _stub(Vector2(150.0, 0.0))
	_kill(e)
	await process_frame
	await process_frame
	_check(not is_instance_valid(e), "적의 몸은 사라졌다 (queue_free 반영)")
	var b = _find_burst()
	_check(b != null, "🔴 폭발이 씬에 남아 있다 (없으면 적 자식으로 붙어 같이 증발한 것)")
	if b == null:
		stub.free()
		return
	_check(b.get_parent() == current_scene,
		"폭발의 주인이 씬이다 (부모 %s)" % b.get_parent().name)
	_check(b.z_index == 50,
		"🔴 z_index == 50 (실제 %d — 바꾸면 vfx.gd의 VFX_Z 주석이 거짓이 된다)" % b.z_index)
	_check(b.shard_count() > 0, "파편이 실제로 있다 (%d개)" % b.shard_count())
	b.free()
	stub.free()


## [2] 🔴🔴 **덩치가 크기·파편 수를 판다 — 파생원은 「보이는 몸」 하나다.**
##
## 세 몸으로 **두 갈래를 각각** 잡는다(하나만 재면 반쪽이 조용히 죽는다):
##   A 시트 64 · size 1.0 → 몸 64      B 시트 32 · size 1.0 → 몸 32      C 시트 32 · size 2.0 → 몸 64
##   • A == 2×B  ⇒ **프레임 한 변**이 파생원이다 (한 변을 무시하면 빨개진다)
##   • C == A    ⇒ 🔴 **덩치(루트 scale)도 같이 탄다** (`× global_scale`을 빼면 C가 B가 돼 빨개진다)
## ⚠ **기대값을 상수로 안 적는다 — 비(比)로 잰다.** 값을 적으면 `RING_FRAC`을 조일 때마다
##  그물이 거짓 빨강이 되고, 무엇보다 「파생」이 아니라 「그 숫자」를 재게 된다(세99 예고 그물과 같은 규율).
func _test_size_drives_burst() -> void:
	print("[2] 덩치가 폭발 크기·파편 수를 판다 — 한 변 × 루트 배율")
	_inject(&"mb_a", SHEET_64)
	_inject(&"mb_b", SHEET_32)
	_inject(&"mb_c", SHEET_32, {"size": 2.0})
	var ra := await _burst_of(&"mb_a")
	var rb := await _burst_of(&"mb_b")
	var rc := await _burst_of(&"mb_c")
	_check(ra.x > 0.0 and rb.x > 0.0 and rc.x > 0.0, "셋 다 폭발이 났다")
	_check(absf(ra.x - rb.x * 2.0) < 0.01,
		"🔴 프레임 한 변이 파생원이다 (64몸 %.1f == 32몸 %.1f × 2)" % [ra.x, rb.x])
	_check(absf(rc.x - ra.x) < 0.01,
		"🔴🔴 덩치(size)도 같이 탄다 (32시트×2.0 = %.1f, 64시트×1.0 = %.1f — 다르면 global_scale이 빠졌다)"
			% [rc.x, ra.x])
	_check(ra.y > rb.y,
		"큰 몸이 파편도 많다 (64몸 %d개 > 32몸 %d개)" % [int(ra.y), int(rb.y)])
	_check(int(rc.y) == int(ra.y),
		"같은 「보이는 몸」이면 파편 수도 같다 (%d == %d)" % [int(rc.y), int(ra.y)])
	_drop(&"mb_a")
	_drop(&"mb_b")
	_drop(&"mb_c")


## [3] 🔴 **보스는 더 크고 파편도 많다**(설계 §3) — 판별은 `params.ai`의 `boss_` 접두사다.
##
## 🔴 **덩치만으로는 못 가른다**: `gale`(384×64)과 `hound`(512×64)는 **프레임 한 변이 똑같이 64**다.
##  그래서 실데이터 둘을 나란히 재는 것이 이 항목의 요점 — 합성 탐침만 쓰면 「라이브 보스가 실제로
##  보스로 읽히나」를 안 재게 된다(세97 「기능이 돈다 ≠ 거기 갈 수 있다」의 작은 판).
func _test_boss_is_bigger() -> void:
	print("[3] 보스는 더 크고 파편도 많다 — 같은 64px 한 변인 hound vs gale")
	var mob := await _burst_of(&"hound")
	var boss := await _burst_of(&"gale")
	_check(mob.x > 0.0 and boss.x > 0.0, "잡몹·보스 둘 다 폭발이 났다 (실데이터)")
	_check(boss.x > mob.x,
		"🔴 보스 폭발이 더 크다 (gale %.1f > hound %.1f — 같으면 boss 배수가 안 걸렸다)"
			% [boss.x, mob.x])
	_check(int(boss.y) > int(mob.y),
		"🔴 보스 파편이 더 많다 (gale %d > hound %d)" % [int(boss.y), int(mob.y)])
	# 합성 탐침 — 시트·size를 **완전히 같게** 두고 `ai`만 바꿔 「접두사가 판별자」임을 고립시킨다.
	_inject(&"mb_mob", SHEET_64, {"ai": "chase"})
	_inject(&"mb_boss", SHEET_64, {"ai": "boss_probe"})
	var p_mob := await _burst_of(&"mb_mob")
	var p_boss := await _burst_of(&"mb_boss")
	_check(p_boss.x > p_mob.x and int(p_boss.y) > int(p_mob.y),
		"🔴 `ai`가 `boss_`로 시작하는 것만으로 갈린다 (크기 %.1f>%.1f · 파편 %d>%d)"
			% [p_boss.x, p_mob.x, int(p_boss.y), int(p_mob.y)])
	_drop(&"mb_mob")
	_drop(&"mb_boss")


## [4] 🔴🔴🔴 **파편이 플레이어에게 「안」 간다** — 세100에 사용자가 각하한 궤적을 못 박는 그물.
##
## *"잠깐 빨려오는건 없음 폭발해서 마나로 돌아갔다는 연출이지 마나가 들어오는건 없음"*
## 「마나로 돌아간다」의 상대는 플레이어가 아니라 **세계**다(`world_and_visual_design.md` §3).
##
## 🔴 **없음을 적극적으로 증명한다** — 플레이어를 **옆에 세워 두고** 두 가지를 잰다:
##   ⓐ 파편까지의 **평균 거리가 안 준다**(수렴 궤적이 생기면 확 준다)
##   ⓑ 파편 **무게중심이 플레이어 쪽으로 안 쏠린다**(약한 끌림도 여기서 걸린다)
## ⚠ ⓑ가 없으면 「살짝만 당긴다」가 통과한다 — ⓐ는 평균 거리라 절반만 당겨도 임계를 안 넘길 수 있다.
func _test_shards_do_not_home() -> void:
	print("[4] 🔴 파편이 플레이어에게 **안** 간다 (각하된 궤적 — 되살아나면 여기서 빨개진다)")
	_inject(&"mb_home", SHEET_64)
	var stub := _stub(Vector2(180.0, 0.0))
	var e = await _spawn(&"mb_home", Vector2.ZERO)
	_kill(e)
	await process_frame
	var b = _find_burst()
	if b == null:
		_check(false, "폭발이 났다")
		stub.free()
		_drop(&"mb_home")
		return
	var d_start := _mean_dist(b.shard_positions(), stub.global_position)
	var d_end := d_start
	var cx_end := 0.0
	var seen := 0
	for i in LIFE_BUDGET:
		await physics_frame
		if not is_instance_valid(b):
			break
		seen += 1
		if b.progress() > 0.8:
			d_end = _mean_dist(b.shard_positions(), stub.global_position)
			cx_end = _mean_pos(b.shard_positions()).x
	_check(seen > 10, "폭발이 여러 프레임을 살았다 (%d프레임)" % seen)
	_check(d_end > d_start * 0.9,
		"ⓐ 🔴 플레이어까지의 거리가 **안 준다** (시작 %.1f → 끝 %.1f — 확 줄면 빨려오는 궤적이 되살아난 것)"
			% [d_start, d_end])
	_check(absf(cx_end) < 40.0,
		"ⓑ 🔴 무게중심이 플레이어(+180) 쪽으로 **안 쏠린다** (끝 평균 x %.1f — 양수로 크면 끌리고 있다)"
			% cx_end)
	if is_instance_valid(b):
		b.free()
	stub.free()
	_drop(&"mb_home")


## [5] 🔴🔴 **실제로 흩어진다 · 떠오른다** — [4]의 짝이다.
##
## 🔴 [4]만 있으면 **파편이 제자리에 굳어도 초록**이다(플레이어에게 안 갔으니까). 「안 온다」와
##  「흩어진다」는 다른 문장이고, 각하된 ③의 자리를 메우는 게 이쪽이다.
##
## 두 가지를 잰다 — 둘 다 **터진 힘이 다한 뒤**(`OUT_SEC` 이후)를 본다. 그전은 폭발 자체라
## 흩어짐을 안 재고, 거기만 보면 `SHARD_DRIFT_FRAC`을 0으로 만들어도 자명 통과한다:
##   ⓐ **가로로 계속 벌어진다**(평균 |x − 죽은자리.x|가 는다)
##   ⓑ 파편이 **떠오른다**(평균 y가 준다 = 위로) — 흩어짐에 방향이 하나 있어야 「돌아갔다」로 읽힌다
##
## 🔴🔴 **ⓐ를 「반경」으로 재면 안 된다 — 뮤테이션이 그걸 잡아냈다.**
##  처음엔 죽은 자리로부터의 **평균 거리**로 쟀는데, `SHARD_DRIFT_FRAC = 0`(흩어짐 제거)을 넣어도
##  **초록이었다**: 파편이 위로 떠오르기만 해도 죽은 자리와의 거리는 늘기 때문이다. 즉 그 검사는
##  ⓑ를 두 번 재고 ⓐ를 **한 번도 안 재고 있었다.** ⇒ **두 축을 갈라서** 가로는 가로로만 잰다.
##  (세85 「검증 도구가 거짓말한다」의 이 파일판 — 그물이 그린이어도 무엇을 재는지는 따로 물어야 한다.)
func _test_shards_scatter_and_rise() -> void:
	print("[5] 🔴 흩어진다 · 떠오른다 (터진 힘이 다한 뒤에도)")
	_inject(&"mb_scatter", SHEET_64)
	var origin := Vector2(30.0, -20.0)   # 원점이 아닌 자리 — 좌표를 0으로 가정한 구현을 걸러낸다
	var e = await _spawn(&"mb_scatter", origin)
	_kill(e)
	await process_frame
	var b = _find_burst()
	if b == null:
		_check(false, "폭발이 났다")
		_drop(&"mb_scatter")
		return
	var w_mid := -1.0
	var y_mid := 0.0
	var w_end := 0.0
	var y_end := 0.0
	for i in LIFE_BUDGET:
		await physics_frame
		if not is_instance_valid(b):
			break
		# 🔴 진행률로 표본을 고른다 — 프레임 수를 박으면 수명 상수를 조일 때 거짓 빨강이 된다.
		if w_mid < 0.0 and b.progress() > 0.40:
			w_mid = _mean_spread_x(b.shard_positions(), origin)
			y_mid = _mean_pos(b.shard_positions()).y
		if b.progress() > 0.85:
			w_end = _mean_spread_x(b.shard_positions(), origin)
			y_end = _mean_pos(b.shard_positions()).y
	_check(w_mid > 0.0 and w_end > 0.0, "터진 뒤·끝 두 표본을 잡았다")
	_check(w_end > w_mid * 1.10,
		"ⓐ 🔴 터진 힘이 다한 뒤에도 계속 흩어진다 (가로 폭 %.1f → %.1f — 같으면 제자리에서 꺼지는 것)"
			% [w_mid, w_end])
	_check(y_end < y_mid - 4.0,
		"ⓑ 🔴 떠오른다 (평균 y %.1f → %.1f — 안 줄면 방향 없이 옅어지기만 하는 것)" % [y_mid, y_end])
	if is_instance_valid(b):
		b.free()
	_drop(&"mb_scatter")


## [6] 🔴 **스스로 죽는다** — 씬 소유의 대가다(`_show_charge_band`가 같은 대가를 치른다).
## 안 지우면 파편이 바닥에 영영 남고, 잡몹을 백 마리 잡으면 노드 백 개가 쌓인다.
## ⚠ **플레이어가 없는 경우도 같이 잰다** — 돌아갈 데가 없다고 안 죽으면 그게 진짜 누수다
##  (검수 도구·테스트 무대가 그 경로다).
func _test_self_lifetime() -> void:
	print("[6] 폭발이 스스로 사라진다 — 플레이어가 있든 없든")
	_inject(&"mb_life", SHEET_64)
	for case in [&"with_player", &"no_player"]:
		var stub: Node2D = null
		if case == &"with_player":
			stub = _stub(Vector2(120.0, 0.0))
		var before := current_scene.get_child_count()
		var e = await _spawn(&"mb_life", Vector2.ZERO)
		_kill(e)
		await process_frame
		var b = _find_burst()
		_check(b != null, "%s: 폭발이 났다" % case)
		for i in LIFE_BUDGET:
			await physics_frame
			if b == null or not is_instance_valid(b):
				break
		await process_frame
		await process_frame
		_check(b == null or not is_instance_valid(b),
			"🔴 %s: 폭발이 스스로 사라진다 (안 사라지면 파편이 바닥에 영영 남는다)" % case)
		_check(current_scene.get_child_count() == before,
			"%s: 씬 자식 수가 제자리다 (%d, 기대 %d)"
				% [case, current_scene.get_child_count(), before])
		if stub != null:
			stub.free()
	_drop(&"mb_life")


## [7] 🔴 **광역 마법으로 여럿을 같은 프레임에 죽였을 때** (설계 §9 「다중 처치 과부하」).
## 늑대 다섯 무리가 실제 무대에 서 있고, 지금까지는 1:1이라 이 자리가 안 드러났다.
##
## 🔴 재는 건 **비용의 형태**다: 처치당 노드가 **정확히 하나**여야 한다(파편마다 `Polygon2D`를
##  심으면 5 + 5×7 = 40개가 한 프레임에 생긴다 — `mana_burst`가 `_draw` 하나로 그리는 이유).
##  그리고 **다섯 개가 서로를 안 지운다**(하나가 남의 수명을 끝내는 공유 상태가 없다).
## ⚠ 히트스톱 겹침(`juice._hitstop`의 `force=true`)은 **여기서 못 잰다** — 무대에 juice가 없고,
##  체감은 어차피 F5의 몫이다(설계 §9가 그렇게 남겨 뒀다).
func _test_multi_kill() -> void:
	print("[7] 같은 프레임에 다섯을 죽인다 — 처치당 노드 하나 · 서로를 안 지운다")
	_inject(&"mb_multi", SHEET_64)
	var stub := _stub(Vector2(0.0, 200.0))
	var before := current_scene.get_child_count()
	var mobs: Array = []
	for i in 5:
		mobs.append(await _spawn(&"mb_multi", Vector2(float(i) * 40.0 - 80.0, 0.0)))
	for m in mobs:
		_kill(m)   # 🔴 await 없이 연속 — 광역 한 방이 같은 프레임에 다 죽이는 그 모양이다
	await process_frame
	await process_frame
	var bursts := _count_bursts()
	_check(bursts == 5,
		"🔴 처치당 폭발 노드 하나 (다섯 죽여 %d개 — 많으면 파편마다 노드를 심은 것)" % bursts)
	_check(current_scene.get_child_count() == before + bursts,
		"씬에 폭발 말고 다른 게 안 쌓였다 (자식 %d, 기대 %d)"
			% [current_scene.get_child_count(), before + bursts])
	for i in LIFE_BUDGET:
		await physics_frame
		if _count_bursts() == 0:
			break
	await process_frame
	await process_frame
	_check(_count_bursts() == 0, "🔴 다섯이 전부 스스로 사라진다 (남으면 잡을수록 쌓인다)")
	_check(current_scene.get_child_count() == before,
		"씬 자식 수가 제자리다 (%d, 기대 %d)" % [current_scene.get_child_count(), before])
	stub.free()
	_drop(&"mb_multi")


## [8] 🔴🔴 **적을 죽여도 마나가 안 는다** — 사용자 확정(세100): *"몬스터 잡아서 마나회복하는것도 없어"*.
## 설계도 같은 것을 들고 있다(§1 「처치가 주 마나 회복원」 **철회** — 보스 처치 직후 포탈을 타면
## 날아오던 파편이 씬 전환으로 증발한다는 리뷰 지적에서 나왔다).
##
## 🔴🔴 **이건 「지금 코드가 안 준다」를 확인하는 검사가 아니다** — 지금은 당연히 안 준다.
##  이건 **나중에 누가 「연출이 있으니 수치도 주자」로 되돌리는 걸 막는 그물**이다. 일부러 안 하는
##  것은 그물이 없으면 조용히 뒤집히고, 뒤집혀도 **에러가 0**이라 아무도 못 본다.
##
## 두 시점을 잰다 — 늘려 주는 자리가 둘일 수 있기 때문이다:
##   ⓐ **죽는 그 순간**(프레임을 안 흘린다 — `_die`가 동기라 즉발 보너스는 여기서 잡힌다)
##   ⓑ **폭발이 끝날 때까지**(파편 도착에 얹는 옛 설계안이 되살아나면 여기서 잡힌다)
## 🔴 ⓑ는 **자연 재생을 빼고** 본다 — `GameState._process`가 초당 `mana_regen_per_sec`을 올리므로
##  「전혀 안 는다」로 재면 그물이 **틀린 이유로** 빨개진다. 상한을 **실제 경과 시간**에서 파생한다
##  (상수로 박으면 balance를 조일 때 거짓 빨강이 된다).
func _test_kill_grants_no_mana() -> void:
	print("[8] 🔴 처치가 마나를 안 준다 (사용자 확정 — 되돌리면 여기서 빨개진다)")
	var gs = root.get_node("/root/GameState")
	_inject(&"mb_mana", SHEET_64)
	var stub := _stub(Vector2(90.0, 0.0))   # 🔴 옛 설계는 「플레이어에게 도착하면」이었다 — 곁에 세운다
	var e = await _spawn(&"mb_mana", Vector2.ZERO)
	# 만땅이면 클램프가 보너스를 삼켜 **자명 통과**가 된다 — 넉넉히 비워 둔다.
	gs.mana = gs.mana_max() * 0.25
	var before: float = gs.mana
	var t0 := Time.get_ticks_msec()
	_kill(e)
	# ⓐ 프레임을 흘리지 않고 **즉시** — 자연 재생이 끼어들기 전이다(`test_ring_spell_auto` 규율).
	_check(is_equal_approx(gs.mana, before),
		"ⓐ 🔴 죽는 그 순간 마나가 안 는다 (%.2f → %.2f)" % [before, gs.mana])
	var b = _find_burst()
	_check(b != null, "폭발은 실제로 났다 (안 났으면 ⓑ가 자명 통과다)")
	for i in LIFE_BUDGET:
		await physics_frame
		if b == null or not is_instance_valid(b):
			break
	var elapsed := float(Time.get_ticks_msec() - t0) / 1000.0
	var regen_cap: float = gs.balance.mana_regen_per_sec * elapsed * 1.25 + 0.5
	var gained: float = gs.mana - before
	_check(gained <= regen_cap,
		"ⓑ 🔴 폭발이 끝날 때까지도 **자연 재생분을 안 넘는다** (늘어난 %.2f ≤ 재생 상한 %.2f · %.2fs 경과)"
			% [gained, regen_cap, elapsed])
	stub.free()
	_drop(&"mb_mana")


# ── 헬퍼 ──

## 몸 하나를 죽여 **(폭발 반지름, 파편 수)**를 뽑는다. 🔴 폭발은 곧바로 free해 다음 항목의
## `_find_burst`가 옛 폭발을 집지 않게 한다(항목이 이어 쓰는 무대라 청소가 계약이다).
func _burst_of(id) -> Vector2:
	var stub := _stub(Vector2(150.0, 0.0))
	var e = await _spawn(id, Vector2.ZERO)
	_kill(e)
	await process_frame
	var b = _find_burst()
	var out := Vector2.ZERO
	if b != null:
		out = Vector2(b.burst_radius(), float(b.shard_count()))
		b.free()
	stub.free()
	await process_frame
	return out


## 지금 씬에 떠 있는 폭발 노드 — 🔴 **공개 메서드로 찾는다**(`class_name`이 없어 타입으로 못 찾고,
## 노드 이름으로 찾으면 이름이 계약이 된다). 드롭 픽업·스텁은 이 메서드가 없어 저절로 걸러진다.
func _find_burst():
	for c in current_scene.get_children():
		if c.has_method(&"shard_count") and c.has_method(&"shard_positions"):
			return c
	return null


## 지금 씬에 떠 있는 폭발이 몇 개인가 — `_find_burst`와 **같은 판별식**을 쓴다(둘이 갈리면
## [7]이 「하나만 세는」 그물이 된다).
func _count_bursts() -> int:
	var n := 0
	for c in current_scene.get_children():
		if c.has_method(&"shard_count") and c.has_method(&"shard_positions"):
			n += 1
	return n


## 🔴 **가로 퍼짐만** — 죽은 자리에서 좌우로 얼마나 벌어졌나. 「반경」으로 재면 **떠오름이 섞여**
## 흩어짐을 안 재게 된다(위 [5] 머리말의 뮤테이션 실패). 세로는 `_mean_pos().y`가 따로 잰다.
func _mean_spread_x(pts: PackedVector2Array, origin: Vector2) -> float:
	if pts.is_empty():
		return 0.0
	var sum := 0.0
	for p in pts:
		sum += absf(p.x - origin.x)
	return sum / float(pts.size())


func _mean_pos(pts: PackedVector2Array) -> Vector2:
	if pts.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for p in pts:
		sum += p
	return sum / float(pts.size())


func _mean_dist(pts: PackedVector2Array, to: Vector2) -> float:
	if pts.is_empty():
		return 0.0
	var sum := 0.0
	for p in pts:
		sum += p.distance_to(to)
	return sum / float(pts.size())


## in-memory EnemyDef 주입 (세61 Db 주입 선례 — 레지스트리가 평범한 Dictionary다).
## 🔴 `drops`를 안 채운다 — 굴릴 게 없어야 무대에 픽업이 안 쌓이고 `_find_burst`가 깨끗하다.
func _inject(id: StringName, sheet: String, extra: Dictionary = {}) -> void:
	var def = (load("res://src/core/schemas/enemy_def.gd") as GDScript).new()
	def.id = id
	def.hp = 10.0
	def.has_counter = false
	# 🔴 aggro 0 = 가만히 선다. 이 그물이 재는 건 **죽는 순간**이라 추격이 좌표를 흔들면 안 된다.
	var p := {"sprite": sheet, "aggro_range": 0.0, "move_speed": 0.0}
	p.merge(extra, true)
	def.params = p
	_db.enemies[id] = def


## 🔴 주입 제거 — 안 걷으면 뒤 테스트의 적 수가 는다(`Db.enemies`는 공유 레지스트리다).
func _drop(id: StringName) -> void:
	_db.enemies.erase(id)


## 「플레이어」 스텁 — 그룹 `"player"`가 적의 유일한 조준 경로다(`forest_enemy._player`).
func _stub(pos: Vector2) -> Node2D:
	var s := Node2D.new()
	s.add_to_group("player")
	root.add_child(s)
	s.global_position = pos
	return s


## 적 하나 — `enemy_id`는 **_ready 전에** 세워야 `_def`가 그 몸으로 잡힌다.
## ⚠ 적은 `root` 밑에 둔다(씬이 아니라) — `_find_burst`가 씬 자식만 훑으므로 몸이 섞이지 않는다.
func _spawn(id, pos: Vector2):
	var e = _enemy_scene.instantiate()
	e.enemy_id = id
	root.add_child(e)
	e.global_position = pos
	await process_frame
	await physics_frame
	return e


## 🔴 **공개 계약으로 죽인다** — `take_hit`이 적 노드 계약의 진입로다(`forest_enemy` 머리말).
## `_die`를 직접 부르면 그물이 죽음 경로를 우회해 「실제로 죽으면 나나」를 안 재게 된다.
func _kill(e) -> void:
	e.take_hit(1.0e9, 0, 0, 0.0)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
