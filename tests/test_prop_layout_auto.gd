extends SceneTree
## 프롭 배치 규칙 ⓐ~ⓔ 자동 검증 (세101) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_prop_layout_auto.gd
## 전 항목 통과 시 "TEST_PROP_LAYOUT_OK" 출력 후 종료 코드 0.
##
## 🔴🔴 **왜 새 파일인가 — 이 규칙들은 세100까지 「주석으로만」 있었다.**
## `boss_room.gd` 머리말이 *"나무 20그루는 세 규칙으로 놓았다"*고 적어 뒀지만 **재는 그물이 0개**였고,
## 자리는 씬에 손으로 박혀 있었다. 세101에 배치가 절차(`_spawn_props`)로 내려오면서 그 상태는
## **«규칙을 어겨도 아무도 모른다»**가 된다 — 규칙식을 코드에 옮긴 순간 그물이 없으면 더 나빠진다.
##
## 🔴 여기서 헤드리스가 **실제로 잡는** 것 (규칙 이름은 `boss_room.gd` 머리말과 같다):
##  [1] 프롭이 실제로 서고 **두 층이 다 있다**(나무·덤불) + 밀도(화면당 나무 수)
##      🔴 「바닥 층위(덤불)가 통째로 비어 기둥 밭」이 세101의 진단이었다 — 그 재발이 여기서 잡힌다
##      🔴 **세107: 바위 둘이 빠졌다** — 그 자리에 「바위가 0개다」를 넣어 재발을 잡는다(사용자 확정)
##  [2] ⓐ 잡몹·네임드·보스 스폰에서 떨어져 있다
##  [3] ⓑ 플레이어 스폰·**모든 탈출구**에서 떨어져 있다
##  [4] ⓒ 어귀·중간·깊은 대역에 고르다
##  [5] 🔴🔴 ⓓ **흙길을 안 밟는다** — 출구는 겉모습이 없어 **보이는 안내가 그 길뿐**이다(설계 §6 S12)
##  [6] ⓔ 지점(둥지) 둘레가 비었다
##  [7] 프롭 씬 계약 — 물리 몸 0 · 감지 Area 0(나무만 예외) · 원점 = 접지선
##  [8] 🔴 **결정적이다** — 같은 챕터를 두 번 띄우면 같은 자리다(프롭은 지형이다 · D5)
## [10] 🔴🔴 **씬이 손으로 든 좌표가 방 안에 있다**(세112 R2 신설 — 입구·출구·볕뉘)
##
## 🔴 **[2]~[6]은 챕터 3장 모두에서 잰다** — 회피 조건(몹 자리·지점·길)이 챕터마다 달라서
##  ch1만 재면 ch2·ch3에서만 깨지는 배치를 못 잡는다.
## 🔴 **손으로 놓은 나무 20그루도 같은 목록에 든다**(`props` 그룹은 방이 붙인다) — 규칙은
##  「누가 놓았나」를 안 본다. 손으로 놓은 것만 규칙 밖이면 그게 곧 구멍이다.
##
## ⚠ 못 잡는 것: **「숲으로 읽히나」 전부** — 밀도가 적당한가 · 덤불이 나무 사이를 메우나 ·
##  프롭이 적을 가리나 · 앞뒤가 어색하지 않나. 전부 F5·스샷 몫이다(헤드리스는 렌더를 안 한다).
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

## 🔴 프롭 씬 경로 = **분류 축**이다(`scene_file_path`로 종류를 가른다 — 손으로 놓은 나무도 같이 걸린다).
## ⚠ **세107: 바위 둘이 `boss_room.PROP_TABLE`에서 빠졌다**(사용자 *"맵에 바위도 없애줘볼래?"*).
##  🔴 **씬·PNG는 남겨 뒀다** — 그래서 아래 상수·`ROAD_CLEAR`·`ANCHOR_TABLE`의 바위 줄도 남긴다
##  (되살릴 때 씬 계약이 그대로 지켜져 있어야 한다). **놓이는지**는 [1]이 「0개」로 잰다.
const TREE_SCENE := "res://src/props/tree.tscn"
const ROCK_BIG_SCENE := "res://src/props/rock_big.tscn"
const BUSH_SCENE := "res://src/props/bush.tscn"
const ROCK_SCENE := "res://src/props/rock.tscn"

## 🔴🔴 **밑동 반폭 — 사본이 아니라 「손으로 든 기대치」다.**
## `boss_room.PROP_TABLE`의 `road`에서 파생시키면 **거기를 0으로 바꿔도 이 그물이 같이 눈을 감는다**
## (세100 `test_landmark_road_auto`의 타일 상수가 같은 이유로 손으로 들려 있다). 값을 조이면
## **두 곳이 같이 빨개지는 게 맞다** — 그게 「연출값이 조용히 흐르는 것」을 막는다.
## ⚠ 나무만 그림 반폭(64)보다 작다: 「길을 막는다」로 읽히는 건 기둥이지 가지가 아니다.
const ROAD_CLEAR := {
	TREE_SCENE: 40.0,
	ROCK_BIG_SCENE: 40.0,
	BUSH_SCENE: 28.0,
	ROCK_SCENE: 16.0,
}
## ⓓ 회피의 세로 두께 — 밑동이 걸치는지만 본다.
const ROAD_BAND := 16.0

## 🔴 ⓐⓑ는 **리드가 지시한 규칙 수치 그대로** 든다(100 · 150) — 이건 계약이라 여유를 안 준다.
const CLEAR_SPAWN := 100.0
const CLEAR_GATE := 150.0
## 🔴 보스 자리·지점은 **하한만** 든다(코드는 260·220으로 더 넉넉하다) — 사용자가 F5로 ±40쯤
##  조여도 거짓 빨강이 안 나면서, 0으로 꺼 버리는 뮤테이션은 그대로 잡힌다.
const CLEAR_BOSS_MIN := 200.0
const CLEAR_LANDMARK_MIN := 200.0
## 🔴🔴 보스 무대의 **상한** — 「가장 가까운 프롭까지의 거리 ≤ 방 짧은변 × 이 값」 (세112 R2 신설).
##  `CLEAR_BOSS_MIN`이 「무대가 비었나」의 하한이면 이건 **「무대가 방 안이긴 한가」**다.
##  🔴 값이 아니라 **비율**인 이유: 방 크기가 바뀌는 사이클이라 px를 박으면 거짓 빨강이 난다.
##  0.6 = 짧은변의 6할. 실측(R2 착지): ch1 0.29 · ch2 0.29 · ch3 0.30 → 두 배 여유가 있고,
##  옛 방 밖 보스(1063px = 1.06)는 그대로 잡힌다.
const BOSS_STAGE_REACH := 0.6

## 🔴 밀도 — 사용자 확정 *"화면당 3~4그루"*. **나무로 잰다**(그 수치가 나무에서 나왔다:
##  세100의 중앙 나무 8그루 / 화면 10.2장 = 0.8). 상한은 「기둥 밭을 두 배로 만든 것」의 방어선이다.
const TREES_PER_SCREEN_MIN := 3.0
const TREES_PER_SCREEN_MAX := 6.0
## 🔴🔴 **바닥 층위가 비면 이 작업이 통째로 무효다** — 세100까지 소비자가 **0곳**이던 층이다.
##  개수를 정확히 박지 않고 **하한만** 둔다(배치 격자를 조여도 거짓 빨강이 안 나게).
## 🔴🔴 **세112 R2: 절대 개수(`BUSH_MIN = 18`)를 「화면당」으로 바꿨다.**
##  방이 2400×2200(화면 10.2장) → 1600×1000(3.1장)으로 줄자 **같은 밀도인데도 18을 못 채웠다** —
##  절대 개수는 「층이 비었나」가 아니라 **「방이 크나」**를 재고 있었다(방 크기가 바뀌는 사이클에서
##  그건 곧 거짓 빨강이다). 옛 계약을 그대로 옮긴 값 = 18/10.19 ≈ **1.77/화면**이고, 여기서 조금
##  내려 잡는다(원래도 실측보다 낮은 하한이었다 — 재는 것은 **「층이 통째로 비었나」**뿐이다).
## ⚠ **세107에 `ROCK_BIG_MIN`(6)·`ROCK_MIN`(24)이 은퇴했다** — 바위가 표에서 빠졌다.
##  되살리면 그 둘도 같이 되살려라(안 그러면 「층이 비어도 아무도 모른다」로 돌아간다).
##  🔴 되살릴 땐 **개수가 아니라 화면당**으로 적어라 — 이번에 밟은 것이 정확히 그 함정이다.
const BUSHES_PER_SCREEN_MIN := 1.5

## 🔴 타일 소스 id·벌판 좌표는 **명시 상수로 박는다** — `boss_room`의 const에서 파생하면 둘 다 밀려도
##  통과한다. ⚠ `test_landmark_road_auto`·`test_extract_hold_auto`가 같은 값을 든다 —
##  **사본이 아니라 「손으로 든 기대치」다**(그 파일들 머리말이 같은 이유를 적어 뒀다).
const TILE_SRC_GROUND := 2
const GRASS_ATLAS: Array[Vector2i] = [Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)]

## 🔴 프롭 씬의 **접지 계약** — 원점이 접지선이다. `offset.y == -(접지선 − 프레임높이/2)`.
##  ⚠ 프레임을 같이 재는 게 핵심이다: 아트가 다시 그려 크기가 바뀌면 offset도 따라와야 하는데
##   그 둘이 갈리면 그림이 수십 px 뜨거나 파묻히고 **에러는 0이다**(`test_landmark_road_auto [4]` 선례).
const ANCHOR_TABLE := {
	ROCK_BIG_SCENE: {"frame": Vector2i(80, 64), "ground": 56},
	BUSH_SCENE: {"frame": Vector2i(56, 48), "ground": 41},
	ROCK_SCENE: {"frame": Vector2i(28, 22), "ground": 19},
}

var failures: int = 0
var _gs = null
var _db = null
var _scene = null
var _room = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		print("TEST_PROP_LAYOUT_TIMEOUT — 90초 초과")
		quit(1))
	await process_frame

	_gs = root.get_node("/root/GameState")
	_db = root.get_node("/root/Db")
	_scene = load("res://src/field/boss_room.tscn") as PackedScene

	# 🔴 검사는 **챕터 3장 모두** — 회피 조건(몹 자리·지점·길)이 챕터마다 달라 ch1만 재면
	#  ch2·ch3에서만 얇아지거나 깨지는 배치를 못 잡는다.
	for id in [&"ch1", &"ch2", &"ch3"]:
		await _fresh(id)
		print("── %s ─────────────────────────────" % id)
		_test_layers_and_density(id)
		_test_away_from_spawns(id)
		_test_away_from_gates(id)
		_test_bands_are_even(id)
		_test_not_on_road(id)
		_test_landmark_is_clear(id)
	_test_prop_scene_contract()
	await _test_deterministic()
	await _test_rules_actually_run()
	await _test_scene_coords_are_inside_room()

	await _cleanup()

	if failures == 0:
		print("TEST_PROP_LAYOUT_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_PROP_LAYOUT_FAIL — %d건 실패" % failures)
		quit(1)


## 🔴 뒷정리 = 계약이다 — 방을 남기면 뒤 테스트에서 플레이어가 둘이 된다(`test_chapter_auto` 선례).
func _cleanup() -> void:
	_gs.pending_chapter = &""
	_gs.ui_modal_open = false
	_free_room()
	await process_frame
	root.get_node("/root/SaveManager").wipe_save()


## [1] 🔴🔴 **두 층이 다 서 있고 밀도가 맞다** (세107에 바위 둘이 빠져 나무·덤불만 남았다) —
## 세101의 진단이 *"바닥 층위가 통째로 비어 기둥 밭"*이었다.
##
## 🔴 **개수를 먼저 찍는다**(`test_daylight_tree_auto`의 관행) — 프롭이 0개면 아래 [2]~[6]이
##  루프 0회로 **전부 자명 통과**하고, 「규칙을 지킨다」가 아니라 「잴 게 없다」가 초록으로 나온다.
## 🔴 밀도는 **방·뷰포트에서 파생**한다 — 화면 장수를 손으로 박으면 방을 또 키울 때 조용히 낡는다.
func _test_layers_and_density(id: StringName) -> void:
	print("[1] 🔴🔴 두 층(나무·덤불)이 다 서 있다 + 화면당 나무 수 + 🔴 바위 0개(세107)")
	var by_scene := _count_by_scene()
	var total := 0
	for k in by_scene:
		total += int(by_scene[k])
	_check(total > 0,
		"%s: 🔴 방에 프롭이 %d개 있다 (0이면 아래 규칙 검사가 **전부 자명 통과**다)" % [id, total])
	print("      나무 %d · 덤불 %d · (바위 %d/%d) 합 %d" % [
		int(by_scene.get(TREE_SCENE, 0)), int(by_scene.get(BUSH_SCENE, 0)),
		int(by_scene.get(ROCK_BIG_SCENE, 0)), int(by_scene.get(ROCK_SCENE, 0)), total])

	var screens := _screens()
	_check(screens > 0.1, "%s: 방이 화면 %.1f장 크기다 (전제)" % [id, screens])
	var trees: float = float(int(by_scene.get(TREE_SCENE, 0)))
	var per: float = trees / maxf(screens, 0.001)
	_check(per >= TREES_PER_SCREEN_MIN and per <= TREES_PER_SCREEN_MAX,
		"%s: 🔴 화면당 나무 %.2f그루 (%.1f~%.1f — 세100은 중앙 8그루로 0.8이었다 = 「들판」)"
			% [id, per, TREES_PER_SCREEN_MIN, TREES_PER_SCREEN_MAX])

	# 🔴 바닥 층위 — 세101의 진단(*"기둥 밭"*)이 여기서 잡힌다. `bush.png`는 그려만 두고
	#  게임 코드 소비자가 **0곳**이던 층이다.
	# 🔴 나무와 **같은 축(화면당)으로** 잰다 — 방 크기가 바뀌어도 「층이 비었나」만 남는다(세112 R2).
	var bushes: float = float(int(by_scene.get(BUSH_SCENE, 0)))
	var bush_per: float = bushes / maxf(screens, 0.001)
	_check(bush_per >= BUSHES_PER_SCREEN_MIN,
		"%s: 🔴 화면당 덤불 %.2f개 ≥ %.1f (실제 %d개 / 화면 %.1f장 — 42px 바닥 층)"
			% [id, bush_per, BUSHES_PER_SCREEN_MIN, int(bushes), screens])

	# 🔴🔴 **세107 재발 감지 — 바위가 한 개도 안 선다**(사용자 *"맵에 바위도 없애줘볼래?"*).
	#  씬·PNG를 남겨 뒀으므로 `PROP_TABLE`에 줄을 도로 넣기가 쉽다 ⇒ 그때 여기가 빨개진다
	#  (takbon-rules T2 — 은퇴를 선언 없이 두면 아무도 못 알아챈다).
	for gone: String in [ROCK_BIG_SCENE, ROCK_SCENE]:
		_check(int(by_scene.get(gone, 0)) == 0,
			"%s: 🔴 %s가 0개다 (실제 %d — 서 있으면 세107 결정이 되돌아온 것이다)"
				% [id, gone.get_file(), int(by_scene.get(gone, 0))])

	# 🔴 손으로 놓은 20그루가 **같은 목록에 들었나** — 안 들면 [2]~[6]이 그것들을 안 재고,
	#  「손으로 놓은 것만 규칙 밖」이라는 구멍이 그대로 남는다.
	var holder = _room.get_node_or_null("Trees")
	var in_group := 0
	if holder != null:
		for t in holder.get_children():
			if t.is_in_group("props"):
				in_group += 1
	_check(holder != null and in_group == holder.get_child_count(),
		"%s: 🔴 `Trees` 아래 나무 %d그루가 전부 props 그룹에 있다 (실제 %d — 빠지면 손으로 놓은 것만 규칙 밖이 된다)"
			% [id, holder.get_child_count() if holder != null else -1, in_group])

	# 🔴🔴 **「바닥에 깔린다」는 z가 아니라 트리 순서다** — Ground·프롭·적이 전부 z 0이라 z에 그 자리가
	#  없다(`test_charge_telegraph_auto [7]`이 같은 판단을 적어 뒀다). `Props` 홀더는 코드가 `add_child`로
	#  만드니 **가만 두면 맨 뒤**고, 그러면 잔돌·덤불이 **적과 플레이어 위에** 그려진다(에러 0 · 화면만 뒤집힌다).
	#  ⚠ 겉보기 판단(「덤불이 몸을 가리나」)은 F5 몫이다 — 여기서 재는 건 **꽂힌 자리**뿐이다.
	var props_holder = _room.get_node_or_null("Props")
	_check(props_holder != null, "%s: `Props` 홀더가 있다 (없으면 바닥 층위가 통째로 안 선 것이다)" % id)
	if props_holder != null:
		var tiles_idx: int = (_room.get_node("TileGround") as Node).get_index()
		var player_idx: int = (_room.get_node("Player") as Node).get_index()
		var props_idx: int = props_holder.get_index()
		_check(props_idx > tiles_idx and props_idx < player_idx,
			"%s: 🔴🔴 `Props`가 타일 뒤·플레이어 앞에 꽂혔다 (타일 %d < 프롭 %d < 플레이어 %d — 맨 뒤에 남으면 잔돌이 몸 위에 그려진다)"
				% [id, tiles_idx, props_idx, player_idx])


## [2] ⓐ 잡몹·네임드·보스 스폰에서 떨어져 있다 — 적이 프롭에 파묻히면 「보이는 몸에 쏜다」가 깨진다.
## 🔴 스폰 좌표는 **`ChapterDef`에서 읽는다**(구현과 같은 정본 — 좌표를 여기 베끼면 데이터를 옮길 때 낡는다).
func _test_away_from_spawns(id: StringName) -> void:
	print("[2] ⓐ 잡몹·네임드·보스 스폰에서 떨어져 있다")
	var ch = _db.get_chapter(id)
	if ch == null:
		_check(false, "%s를 Db에서 못 찾았다" % id)
		return
	var spots: Array[Vector2] = []
	for ms in ch.mob_spawns:
		if ms != null:
			spots.append(ms.position)
	for ns in ch.named_pool:
		if ns != null:
			spots.append(ns.position)
	_check(not spots.is_empty(), "%s: 스폰 자리를 %d곳 쟀다 (0이면 자명 통과다)" % [id, spots.size()])
	var worst := INF
	var worst_at := Vector2.ZERO
	for p in _props():
		for at: Vector2 in spots:
			var d: float = p.position.distance_to(at)
			if d < worst:
				worst = d
				worst_at = p.position
	_check(worst >= CLEAR_SPAWN,
		"%s: 🔴 프롭이 몹 자리에서 %.0fpx 이상 떨어져 있다 (가장 가까운 것 %.0fpx @ %s)"
			% [id, CLEAR_SPAWN, worst, worst_at])

	# 🔴 보스 자리만 더 넓다 — 여긴 **무대**다(뱀 보스는 마디 12개라 100px로는 몸이 프롭에 걸린다).
	var boss_worst := INF
	for p in _props():
		boss_worst = minf(boss_worst, p.position.distance_to(ch.boss_spawn))
	_check(boss_worst >= CLEAR_BOSS_MIN,
		"%s: 🔴 보스 자리 %s 둘레가 %.0fpx 비었다 (가장 가까운 프롭 %.0fpx)"
			% [id, ch.boss_spawn, CLEAR_BOSS_MIN, boss_worst])
	# 🔴🔴 **위 줄의 자명 통과 방지 — 세112 R2에 실제로 밟았다.**
	#  방을 2400×2200 → 1600×1000으로 줄이자 `boss_spawn (0,-1350)`이 **방 밖 850px**이 됐고,
	#  그러자 위 검사가 «가장 가까운 프롭 1063px»로 **늘 참**이 됐다 — 「무대가 비었다」를 재는 게
	#  아니라 「보스가 멀리 있다」를 재고 있었다. 🔴 **회피 규칙은 그때 이미 죽어 있었는데 그린이다.**
	#  ⇒ 무대가 **프롭 밭 안에** 있는지를 같이 잰다: 안에 있으면 어느 프롭이든 이만큼 안에는 있다.
	# 🔴 상한을 **방에서 파생**한다(px를 박으면 방을 또 바꿀 때 거짓 빨강이 난다). `CLEAR_BOSS_MIN`이
	#  하한이고 이게 상한이라, 둘 사이를 벗어나면 **어느 쪽이든** 빨개진다.
	var ground: ColorRect = _room.get_node("Ground")
	var stage_max: float = minf(ground.size.x, ground.size.y) * BOSS_STAGE_REACH
	_check(boss_worst <= stage_max,
		"%s: 🔴🔴 보스 무대가 프롭 밭 **안**이다 — 가장 가까운 프롭 %.0fpx ≤ %.0fpx (방 짧은변 %.0f × %.2f). 넘으면 무대가 방 밖이라 위 줄이 자명 통과다"
			% [id, boss_worst, stage_max, minf(ground.size.x, ground.size.y), BOSS_STAGE_REACH])


## [3] ⓑ 플레이어 스폰·**나가는 길**에서 떨어져 있다 — 시작 시야와 [E] 찾기.
## 🔴 출구를 **씬에서 찾는다**(`zone_id == "exit"`) — 좌표를 박으면 출구를 옮길 때 그물만 제자리에 남는다.
##
## ⚠ **세112 R1에 「여럿」이 죽었다 — 그런데 이 항목은 안 지웠다.** 탈출구 여럿(`extract_points`)이
##  걷혔지만 **씬 인라인 남쪽 `$Exit`는 그대로 서 있고**, 재려던 것(「프롭이 [E] 자리를 파묻나」)이
##  그 하나에 대해 **여전히 성립한다**. 🔴 **「지우지 말고 뒤집어라」가 아니라 그냥 계속 잰다** —
##  잴 대상이 남았기 때문이다(반대 사례 = `test_chapter_auto`의 「지름길」 검사. 그건 출구가 하나가
##  되자 **늘 같은 자리**를 비교하게 돼 재는 것이 0이 됐고, 그래서 지웠다).
## ✅ 자명 통과 방지는 아래 `gates.size() >= 2`가 이미 진다 — 출구를 하나도 못 찾으면 거기서 빨개진다.
func _test_away_from_gates(id: StringName) -> void:
	print("[3] ⓑ 입구(플레이어 스폰)·나가는 길에서 떨어져 있다")
	var gates: Array[Vector2] = [(_room.get_node("Player") as Node2D).position]
	for z in _exit_zones():
		gates.append((z as Node2D).position)
	_check(gates.size() >= 2,
		"%s: 입구+출구를 %d곳 쟀다 (1이면 출구를 하나도 못 찾은 것이다 = 자명 통과)" % [id, gates.size()])
	var worst := INF
	var worst_at := Vector2.ZERO
	var worst_gate := Vector2.ZERO
	for p in _props():
		for g: Vector2 in gates:
			var d: float = p.position.distance_to(g)
			if d < worst:
				worst = d
				worst_at = p.position
				worst_gate = g
	_check(worst >= CLEAR_GATE,
		"%s: 🔴 프롭이 입구·출구에서 %.0fpx 이상 떨어져 있다 (가장 가까운 것 %.0fpx — 프롭 %s / 문 %s)"
			% [id, CLEAR_GATE, worst, worst_at, worst_gate])


## [4] ⓒ 어귀·중간·깊은 대역에 고르다.
## 🔴 대역은 **방 높이를 셋으로** 나눠 파생한다(구역은 코드 개념이 아니라 y좌표 관례라 — `boss_room.gd`).
## 🔴 기대치는 **관계식**이다: 어느 대역도 「고른 몫(1/3)의 절반」 밑으로 안 떨어진다.
##  개수를 박으면 격자를 조일 때 거짓 빨강이 나고, 「0이 아니다」로만 재면 한쪽에 몰려도 통과한다.
func _test_bands_are_even(id: StringName) -> void:
	print("[4] ⓒ 어귀·중간·깊은 대역에 고르다")
	var ground: ColorRect = _room.get_node("Ground")
	var top: float = ground.position.y
	var third: float = ground.size.y / 3.0
	var band := [0, 0, 0]
	for p in _props():
		var k: int = clampi(int((p.position.y - top) / third), 0, 2)
		band[k] += 1
	var total: int = band[0] + band[1] + band[2]
	_check(total > 0, "%s: 프롭 %d개를 대역에 나눴다 (0이면 자명 통과)" % [id, total])
	var floor_n: int = int(float(total) / 6.0)   # 고른 몫(1/3)의 절반
	_check(band[0] >= floor_n and band[1] >= floor_n and band[2] >= floor_n,
		"%s: 🔴 깊은 %d · 중간 %d · 어귀 %d — 어느 대역도 %d개 밑으로 안 떨어진다 (합 %d)"
			% [id, band[0], band[1], band[2], floor_n, total])


## [5] 🔴🔴 ⓓ **흙길을 안 밟는다** — 이 파일의 심장 하나.
##
## 🔴 **왜 중요한가**: 길 위에 나무가 서면 「저리로 이어진다」가 막혀 보이는데 **에러는 0**이다.
## 🔴 **타일을 실제로 읽어 잰다** — `boss_room._road`를 들여다보지 않는다. 그래야 「길을 깔았는데
##  회피가 그 표를 안 읽는」 어긋남까지 잡힌다(둘이 갈리면 화면과 판정이 달라진다).
## ⚠ 밑동만 본다(가로 = 밑동 반폭 · 세로 = 얇은 띠) — 가지가 길가에 걸치는 건 숲답다.
##
## 🔴🔴 **세112 R1: 「길이 있다」가 조건부가 됐다.** 흙길 줄기가 둘이었는데(ⓐ 출구→가장자리 ·
##  ⓑ 입구→지점) **ⓐ가 R1에 죽어 ⓑ만 남았고, ⓑ의 손잡이는 `ChapterDef.landmarks`다.**
##  ⇒ 지점을 안 세운 챕터(ch2·ch3)는 **흙길이 0칸인 게 정상**이다 — 무조건 `> 0`으로 두면
##  **거짓 빨강**이 나서 그물 신뢰가 죽는다(`test_chapter_auto [1d]`가 지점 산출에 쓴 것과 같은 조건부).
## 🔴 **딱지가 아니라 스위치다** — 지점이 서는 챕터에선 자명 통과 방지가 그대로 돌고, R6의 문이
##  자기 길을 갖게 되면 그때 저절로 다시 측정이 된다. **`> 0`을 통째로 지우지 마라.**
## ⚠ **여기서 잃은 것**: ch2·ch3엔 이제 「나가는 길」의 시각 안내가 **하나도 없다**(출구는 겉모습이
##  0이다 — 설계 §6 S12). R6의 문 그림이 그 자리를 대신할 때까지 **F5로만 보인다.**
func _test_not_on_road(id: StringName) -> void:
	print("[5] 🔴🔴 ⓓ 프롭의 밑동이 흙길 칸을 안 밟는다")
	var g := _grid()
	# 자명 통과 방지 — 길이 0칸이면 무엇을 놓아도 통과한다. **지점이 선 챕터에서만** 잰다.
	var road_cells := _count_road_cells(g)
	var ch_def = _db.get_chapter(id)
	var has_landmark: bool = ch_def != null and not ch_def.landmarks.is_empty()
	if has_landmark:
		_check(road_cells > 0, "%s: 방에 흙길이 %d칸 깔렸다 (0이면 이 항목이 자명 통과다)" % [id, road_cells])
	else:
		print("    SKIP: %s는 지점이 없어 흙길이 0칸이다 (R1로 출구 줄기가 죽었다) — 아래는 자명 통과다"
			% id)
	var bad := 0
	var first := ""
	for p in _props():
		var clear: float = float(ROAD_CLEAR.get(p.scene_file_path, 0.0))
		if clear <= 0.0:
			_check(false, "%s: 밑동 반폭을 모르는 프롭이 섰다 (%s) — 표에 한 줄 더해라"
				% [id, p.scene_file_path])
			continue
		if not _footprint_hits_road(p.position, clear, g):
			continue
		bad += 1
		if first == "":
			first = "%s @ %s" % [p.scene_file_path.get_file(), p.position]
	_check(bad == 0,
		"%s: 🔴🔴 흙길을 밟은 프롭이 0개다 (실제 %d개 — 첫 번째 %s)" % [id, bad, first])


## [6] ⓔ 지점(둥지) 둘레가 비었다 — 랜드마크가 프롭에 파묻히면 「저건 다르다」가 죽는다.
## ⚠ 지점이 없는 챕터(ch2·ch3)에선 잴 게 없다 — **SKIP이 아니라 그 사실을 찍고 넘어간다**
##  (자명 통과를 PASS로 찍으면 「재고 있다」는 착각이 남는다).
func _test_landmark_is_clear(id: StringName) -> void:
	print("[6] ⓔ 지점(둥지) 둘레가 비었다")
	var marks := get_nodes_in_group("landmarks")
	if marks.is_empty():
		print("  (지점 없음 — %s는 잴 게 없다)" % id)
		return
	var worst := INF
	var worst_at := Vector2.ZERO
	for m in marks:
		for p in _props():
			var d: float = p.position.distance_to(m.position)
			if d < worst:
				worst = d
				worst_at = p.position
	_check(worst >= CLEAR_LANDMARK_MIN,
		"%s: 🔴 지점 둘레 %.0fpx가 비었다 (가장 가까운 프롭 %.0fpx @ %s)"
			% [id, CLEAR_LANDMARK_MIN, worst, worst_at])


## [7] 프롭 씬 계약 — **물리 몸 0 · 감지 Area 0 · 원점 = 접지선**.
##
## 🔴 물리 몸을 붙이면 world 레이어라 마법 캐리어(마스크 5)가 **프롭마다 터진다**(나무가 장식인
##  이유와 같다 — `boss_room.gd` 머리말). 세99에 둥지가, 세101에 바위·덤불이 같은 함정 앞에 섰다.
## 🔴🔴 **감지 Area(「뒤로 가면 비친다」)도 0이다** — 바위는 화면 키 64px이라 플레이어(56px)를 거의
##  안 가려서 **아무 일도 안 하는 손잡이**가 된다(감사 T3 「거짓 손잡이」). 그 기능은 **나무만** 가진다.
##  ⚠ 그래서 나무는 이 항목에서 뺀다 — 나무의 Area 계약은 `test_daylight_tree_auto [5]`가 잰다.
## ⚠ **세107: 바위 둘은 이제 방에 안 선다**(표에서 빠졌다) — 그런데 **씬은 남겨 뒀으므로** 여기서
##  계약을 계속 잰다. 되살리는 날 접지·프레임이 이미 맞아 있어야 한다(안 재면 조용히 낡는다).
func _test_prop_scene_contract() -> void:
	print("[7] 프롭 씬 계약 — 물리 몸 0 · 감지 Area 0 · 원점 = 접지선")
	for path in ANCHOR_TABLE:
		var packed := load(path) as PackedScene
		_check(packed != null, "%s가 로드된다 (전제)" % path)
		if packed == null:
			continue
		var node = packed.instantiate()
		var bodies: Array = []
		var areas: Array = []
		_collect(node, bodies, areas)
		_check(bodies.is_empty(),
			"🔴 %s: PhysicsBody2D가 0개다 (실제 %s — world 레이어면 캐리어가 프롭마다 터진다)"
				% [path.get_file(), str(bodies)])
		_check(areas.is_empty(),
			"🔴🔴 %s: 감지 Area2D가 0개다 (실제 %d — 64px 이하는 몸을 안 가려서 거짓 손잡이가 된다)"
				% [path.get_file(), areas.size()])
		_check(node is Sprite2D, "%s: 루트가 Sprite2D다 (실제 %s)" % [path.get_file(), node.get_class()])
		if node is Sprite2D:
			var want: Dictionary = ANCHOR_TABLE[path]
			var frame: Vector2i = want["frame"]
			var ground: int = int(want["ground"])
			_check(node.centered, "%s: centered = true (offset 산식의 전제다)" % path.get_file())
			_check(node.texture != null, "🔴 %s: 텍스처가 실제로 물렸다" % path.get_file())
			if node.texture != null:
				_check(node.texture.get_size() == Vector2(frame),
					"%s: 프레임이 %s다 (실제 %s — 아트가 다시 그리면 아래 offset도 같이 움직여야 한다)"
						% [path.get_file(), frame, node.texture.get_size()])
			var expect := Vector2(0.0, -(float(ground) - float(frame.y) * 0.5))
			_check(node.offset == expect,
				"🔴 %s: offset == %s = -(접지선 %d − 프레임높이/2 %d) (실제 %s — 어긋나면 그림이 뜨거나 파묻힌다)"
					% [path.get_file(), expect, ground, frame.y / 2, node.offset])
		node.free()


## [8] 🔴🔴 **결정적이다 — 프롭은 지형이다.**
##
## 세99 D5가 사용자 확정으로 *"지형은 동일하고 나오는 몬스터들이 랜덤"*이라고 못 박았다. 프롭 자리를
## `randf()`로 굴리면 **같은 챕터를 다시 들어갈 때마다 다른 숲**이 되고, 「저 바위 뒤」가 기억이 안 된다.
## 🔴 좌표 **집합**을 대조한다(순서는 안 본다 — 홀더가 둘이라 순서에 의미가 없다).
## ⚠ 나무 **컷**은 여전히 판마다 다르다(`tree.gd`가 `randi()`로 3종 중 고른다 — 세46부터의 계약이다).
##  여기서 재는 건 **자리**뿐이다.
func _test_deterministic() -> void:
	print("[8] 🔴🔴 같은 챕터를 두 번 띄우면 같은 자리다 (프롭 = 지형)")
	await _fresh(&"ch1")
	var a := _prop_key()
	await _fresh(&"ch1")
	var b := _prop_key()
	_check(a.size() > 0, "첫 판에서 프롭 %d개를 쟀다 (0이면 자명 통과다)" % a.size())
	_check(a.size() == b.size(),
		"🔴 두 판의 프롭 수가 같다 (%d ↔ %d)" % [a.size(), b.size()])
	var same := 0
	for k in a:
		if b.has(k):
			same += 1
	_check(same == a.size(),
		"🔴🔴 두 판의 프롭 자리가 **한 톨도 안 다르다** (%d/%d 일치 — 어긋나면 배치가 굴려진 것이다)"
			% [same, a.size()])


## [9] 🔴🔴 **ⓑ가 실제로 도나 — 프롭이 서 있는 자리로 입구를 옮겨 본다.**
##
## 🔴🔴 **왜 필요한가 (세101 뮤테이션 실측):** `PROP_CLEAR_GATE`를 **0으로 꺼도 [3]이 그린이었다.**
##  지금 격자에서 그 규칙이 실제로 쳐내는 후보가 **0개**라서다 — 다른 규칙(흙길 회피)이 이미 그 자리를
##  비우고 있다. 즉 [3]은 **결과를 볼 뿐 규칙이 살아 있는지는 안 잰다** = 「결과 값이 같다 ≠ 같은 길로
##  왔다」(세86). 그리고 이건 **문을 옮기는 날 진짜 문제가 된다**: 출구를 프롭 한복판으로 옮기면
##  규칙이 죽어 있어도 아무도 모르고, 문 앞에 나무가 선 채 커밋된다.
##
## 🔴🔴 **왜 「문을 심는」 게 아니라 「입구를 옮기는」가** — 세101에 둘 다 해 봤다. **탈출구를 심으면
##  그 자리에 흙길이 같이 깔려서** 프롭이 ⓓ에 걸려 사라진다 → ⓑ를 꺼도 그대로 비어 **여전히 그린**이다
##  (검사가 다른 규칙에 가려진다). 입구(플레이어 스폰)는 **`landmarks`를 비우면 자기 길이 없어져**
##  그 자리에서 ⓑ만 남는다. 그래서 ⓐ 지점을 비우고 ⓑ 입구를 옮긴다 — **두 조작이 한 세트다.**
## ⚠ 주입은 **원본을 보관했다 되돌린다**(`test_landmark_road_auto` [7]·[10] 관행).
##
## 🔴🔴 **ⓔ(지점 회피)는 이 파일이 「돈다」를 증명하지 못한다 — 알고 남긴다.**
##  같은 실측에서 `PROP_CLEAR_LANDMARK`를 0으로 꺼도 [6]이 그린이었다. 지점은 **언제나 자기 흙길의
##  끝**이라 둘레 96~128px이 길로 이미 비고, ch1에선 늑대 다섯이 ⓐ(100px)로 그 바깥을 또 비운다 —
##  ⓔ가 혼자 쳐낼 자리가 남지 않는다. **[6]은 결과 검사로만 유효하다**(누가 길 규칙을 바꾸거나
##  손으로 프롭을 지점 옆에 놓으면 그때 빨개진다). ⓔ를 지우지 않는 이유는 그 가림이 **데이터에 딸린
##  우연**이기 때문이다 — 늑대를 옮기거나 지점을 길 없는 곳에 두는 날 ⓔ만 남는다.
func _test_rules_actually_run() -> void:
	print("[9] 🔴🔴 ⓑ가 실제로 도나 — 프롭 자리로 입구를 옮겨 본다")
	var ch = _db.get_chapter(&"ch1")
	if ch == null:
		_check(false, "ch1을 Db에서 못 찾았다 (전제)")
		return

	await _fresh(&"ch1")
	var victim := _victim_prop()
	_check(victim != Vector2.INF,
		"옮겨 갈 자리를 골랐다 (절차로 놓인 프롭이 실제로 서 있고 기존 문·지점과 먼 칸 %s)" % victim)
	if victim == Vector2.INF:
		return

	# 🔴 지점을 비운다 — 안 비우면 입구에서 지점까지 흙길이 깔려 **그 길이 ⓑ를 가린다**(위 머리말).
	var lm_before: Array = ch.landmarks.duplicate()
	ch.landmarks.clear()
	await _fresh_with_entrance(&"ch1", victim)
	var near_gate := _nearest_prop_to(victim)
	# ⚠ 세107에 바위가 빠져 `Props` 홀더에 남은 건 **덤불뿐**이다(나무는 `Trees`로 간다) —
	#  `_victim_prop`이 그 홀더에서 고르므로 밑동 반폭도 덤불 것을 쓴다(옛 `ROCK_SCENE` 16.0 → 28.0).
	var road_free := not _footprint_hits_road(victim, float(ROAD_CLEAR[BUSH_SCENE]), _grid())
	ch.landmarks.assign(lm_before)   # 🔴 되돌리기가 먼저다 — 아래 _check이 무엇을 하든 새 나가지 않는다

	_check(road_free,
		"🔴 옮긴 입구 %s 발밑이 흙길이 아니다 (길이면 ⓓ가 ⓑ를 가려 이 검사가 자명 통과다)" % victim)
	_check(near_gate >= CLEAR_GATE,
		"🔴🔴 프롭 자리 %s로 입구를 옮기니 둘레가 비었다 (가장 가까운 프롭 %.0fpx ≥ %.0f — ⓑ를 끄면 0px다)"
			% [victim, near_gate, CLEAR_GATE])

	# 🔴 되돌아왔나 — 주입을 안 되돌리면 다음 판이 조용히 달라진다(그 자체가 검사할 값이다).
	await _fresh(&"ch1")
	_check(get_nodes_in_group("landmarks").size() == lm_before.size(),
		"주입을 되돌렸다 — 지점이 %d개로 돌아왔다 (실제 %d)"
			% [lm_before.size(), get_nodes_in_group("landmarks").size()])


## [10] 🔴🔴 **손으로 든 좌표가 전부 방 안에 있다 — 씬 + 챕터 데이터** (세112 R2 신설).
##
## 🔴 **왜 필요한가 (R2 뮤테이션 실측)**: 방 크기의 소유자는 씬의 `Ground` rect **하나**이고
##  `_fill_tiles`·`_clamp_camera_to_room`·`_spawn_props`가 거기서 파생한다 — 그런데 **방 안에 서는
##  것들의 좌표는 파생이 아니라 사람이 적은 값**이다. 두 군데에 흩어져 있다:
##   ⓐ **씬** — 입구 `Player` · 출구 `Exit` · 볕뉘 `Lights/*`
##   ⓑ **데이터** — `ChapterDef.boss_spawn`·`mob_spawns`·`named_pool`·`landmarks`
##  하나라도 안 옮기면 **카메라 클램프 밖에 서서 플레이어가 영영 못 가는데 에러가 0이다.**
##
## 🔴🔴 **둘 다 실측으로 확인한 침묵이다**:
##  ⓐ `Exit`를 옛 자리 `(0,660)`(= 새 남쪽 벽 160px 밖)로 되돌려도 **이 파일과 `test_chapter_auto`가
##    둘 다 그린이었다** — 재는 자리가 아예 없었다.
##  ⓑ `ch1.boss_spawn`이 옛 값 `(0,-1350)`(북쪽 벽 850px 밖)일 때 **`[2]`가 「가장 가까운 프롭
##    1063px」로 자명 통과**로 바뀌었다 — 지켜진 게 아니라 **검출력이 0이 된 것**이다(세86의
##    「결과 값이 같다 ≠ 같은 길로 왔다」와 같은 결).
##
## 🔴 **기대치를 박지 않는다 — `Ground` rect와 대조만 한다.** 방을 또 바꿔도 안 낡는다.
## 🔴 **챕터 3장 모두** 잰다 — 한 장만 재면 나머지 둘이 밖에 있어도 그린이다.
func _test_scene_coords_are_inside_room() -> void:
	print("[10] 🔴🔴 손으로 든 좌표(씬 + 챕터 데이터)가 전부 방 안에 있다")
	for id in [&"ch1", &"ch2", &"ch3"]:
		await _fresh(id)
		var ground: ColorRect = _room.get_node("Ground")
		var room := Rect2(ground.position, ground.size)
		var spots: Array = [["입구(Player)", (_room.get_node("Player") as Node2D).position]]
		for z in _exit_zones():
			spots.append(["출구(%s)" % (z as Node).name, (z as Node2D).position])
		var lights = _room.get_node_or_null("Lights")
		if lights != null:
			for l in lights.get_children():
				var pl := l as Node2D
				if pl != null:
					spots.append(["볕뉘(%s)" % pl.name, pl.position])
		var ch = _db.get_chapter(id)
		if ch != null:
			spots.append(["보스 자리", ch.boss_spawn])
			for ms in ch.mob_spawns:
				if ms != null:
					spots.append(["잡몹 자리", ms.position])
			for ns in ch.named_pool:
				if ns != null:
					spots.append(["네임드 자리", ns.position])
			for slot in ch.landmarks:
				if slot != null:
					spots.append(["지점(%s)" % slot.landmark_id, slot.position])
		# 자명 통과 방지 — 씬 셋 + 보스 + 잡몹이 다 잡혀야 이 항목이 무언가를 잰다.
		_check(spots.size() >= 8,
			"%s: 좌표를 %d곳 쟀다 (8 미만이면 노드·데이터를 못 읽은 것 = 자명 통과다)" % [id, spots.size()])
		var bad: Array = []
		for s: Array in spots:
			if not room.has_point(s[1] as Vector2):
				bad.append("%s %s" % [s[0], s[1]])
		_check(bad.is_empty(),
			"%s: 🔴🔴 방 %s~%s 밖에 선 좌표가 0개다 (실제 %d개: %s — 밖이면 카메라 클램프 때문에 영영 못 간다)"
				% [id, room.position, room.end, bad.size(), ", ".join(PackedStringArray(bad))])


## 문·지점을 심어 볼 **희생 프롭**의 좌표 — 두 조건이 있다:
##  ⓐ 기존 문·지점에서 충분히 멀 것(이미 비어 있던 자리에 심으면 규칙을 꺼도 그대로 비어 자명 통과다)
##  ⓑ 🔴🔴 **절차로 놓인 프롭일 것** — 씬에 손으로 박힌 나무 20그루는 규칙이 **안 옮긴다**(측정 대상일
##     뿐 배치 대상이 아니다). 세101 실측: 손으로 놓은 `Tree7`을 골랐더니 문을 심어도 거리가 0으로
##     남아 **이 검사가 「규칙이 죽었다」로 오독**했다 — 검사 자체가 틀린 경우다(세86의 짝).
##     ⚠ 손으로 놓은 나무가 문 앞에 서는 것 자체는 [3]이 잡는다(그건 사람이 씬에서 옮길 일이다).
## 🔴 결정적으로 고른다 — 조건을 만족하는 것 중 **기존 문·지점에서 가장 먼** 것.
func _victim_prop() -> Vector2:
	var holder = _room.get_node_or_null("Props")
	if holder == null or holder.get_child_count() == 0:
		return Vector2.INF
	var gates: Array[Vector2] = [(_room.get_node("Player") as Node2D).position]
	for z in _exit_zones():
		gates.append((z as Node2D).position)
	for m in get_nodes_in_group("landmarks"):
		gates.append((m as Node2D).position)
	var best := Vector2.INF
	var best_d := 0.0
	for c in holder.get_children():
		var p := c as Node2D
		if p == null:
			continue
		var d := INF
		for g: Vector2 in gates:
			d = minf(d, p.position.distance_to(g))
		if d > best_d:
			best_d = d
			best = p.position
	return best if best_d > CLEAR_GATE * 2.0 else Vector2.INF


func _nearest_prop_to(at: Vector2) -> float:
	var best := INF
	for p in _props():
		best = minf(best, p.position.distance_to(at))
	return best


# ── 도구 ──────────────────────────────────────────────────────────────────────


func _props() -> Array:
	return get_nodes_in_group("props")


## 종류별 개수 — `scene_file_path`로 가른다(손으로 놓은 나무도 인스턴스라 같은 경로가 찍힌다).
func _count_by_scene() -> Dictionary:
	var out: Dictionary = {}
	for p in _props():
		var k: String = p.scene_file_path
		out[k] = int(out.get(k, 0)) + 1
	return out


## 좌표 집합(문자열 키) — 부동소수 비교를 피하려고 0.1px로 반올림해 찍는다.
func _prop_key() -> Dictionary:
	var out: Dictionary = {}
	for p in _props():
		out["%s|%.1f,%.1f" % [p.scene_file_path, p.position.x, p.position.y]] = true
	return out


## 방이 화면 몇 장인가 — 🔴 **방·뷰포트에서 파생한다**(장수를 박으면 방을 또 키울 때 조용히 낡는다).
func _screens() -> float:
	var ground: ColorRect = _room.get_node("Ground")
	var vw := float(ProjectSettings.get_setting("display/window/size/viewport_width", 960))
	var vh := float(ProjectSettings.get_setting("display/window/size/viewport_height", 540))
	if vw <= 0.0 or vh <= 0.0:
		return 0.0
	return (ground.size.x * ground.size.y) / (vw * vh)


## 씬에 실제로 선 탈출구들 — `zone_id`로 찾는다(경로·좌표 하드코딩 금지).
func _exit_zones() -> Array:
	var out: Array = []
	for c in _room.get_children():
		if c is Area2D and c.get("zone_id") == &"exit":
			out.append(c)
	return out


func _tiles() -> TileMapLayer:
	return _room.get_node("TileGround") as TileMapLayer


## `boss_room._fill_tiles`와 **같은 방식으로** 셀 범위를 파생한다 — 좌표를 베끼면 방을 키울 때
## 이 그물만 낡아 거짓 빨강이 난다. (`test_landmark_road_auto._grid` 계약 그대로.)
func _grid() -> Dictionary:
	var ground: ColorRect = _room.get_node("Ground")
	var ts: Vector2i = _tiles().tile_set.tile_size
	var rect := Rect2(ground.position, ground.size).grow(-float(ts.x))
	return {
		"ts": ts,
		"from": Vector2i(floori(rect.position.x / ts.x), floori(rect.position.y / ts.y)),
		"to": Vector2i(ceili(rect.end.x / ts.x), ceili(rect.end.y / ts.y)),
	}


## 🔴 「이 칸이 흙길인가」 — **아틀라스 좌표로 가른다**(source id로는 못 가른다: 벌판과 길이 같은 시트다).
## 벌판 좌표 셋을 손으로 들고 **그 밖이면 길**로 본다 — 길 쪽을 열거하면 오토타일이 새 칸을 쓰는 날
## 그물이 조용히 눈을 감는다(`test_landmark_road_auto._is_road`와 같은 판단).
func _is_road(cell: Vector2i) -> bool:
	if _tiles().get_cell_source_id(cell) != TILE_SRC_GROUND:
		return false
	return not GRASS_ATLAS.has(_tiles().get_cell_atlas_coords(cell))


func _count_road_cells(g: Dictionary) -> int:
	var from: Vector2i = g["from"]
	var to: Vector2i = g["to"]
	var n := 0
	for y in range(from.y, to.y):
		for x in range(from.x, to.x):
			if _is_road(Vector2i(x, y)):
				n += 1
	return n


## 밑동 발자국이 흙길 칸과 겹치나 — 가로는 밑동 반폭, 세로는 얇은 띠.
func _footprint_hits_road(at: Vector2, clear: float, g: Dictionary) -> bool:
	var ts: Vector2i = g["ts"]
	var x0 := floori((at.x - clear) / float(ts.x))
	var x1 := floori((at.x + clear) / float(ts.x))
	var y0 := floori((at.y - ROAD_BAND) / float(ts.y))
	var y1 := floori((at.y + ROAD_BAND) / float(ts.y))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if _is_road(Vector2i(x, y)):
				return true
	return false


func _collect(node: Node, bodies: Array, areas: Array) -> void:
	if node is PhysicsBody2D:
		bodies.append(node.name)
	elif node is Area2D:
		areas.append(node)
	for c in node.get_children():
		_collect(c, bodies, areas)


## 방 하나를 새로 띄운다 (`test_landmark_road_auto._fresh` 계약 그대로 — 방을 남기면 플레이어가 둘이 된다).
func _fresh(chapter_id: StringName) -> void:
	_free_room()
	_gs.pending_chapter = chapter_id
	_room = _scene.instantiate()
	root.add_child(_room)
	current_scene = _room
	await process_frame
	await physics_frame


## 🔴 입구(플레이어 스폰)를 옮겨서 띄운다 — **`add_child` 전에** 옮겨야 한다(그때 `_ready`가 돌고
## 프롭 배치가 그 자리를 읽는다). 뒤에 옮기면 프롭은 옛 자리 기준으로 이미 서 있다.
func _fresh_with_entrance(chapter_id: StringName, at: Vector2) -> void:
	_free_room()
	_gs.pending_chapter = chapter_id
	_room = _scene.instantiate()
	(_room.get_node("Player") as Node2D).position = at
	root.add_child(_room)
	current_scene = _room
	await process_frame
	await physics_frame


func _free_room() -> void:
	if _room != null and is_instance_valid(_room):
		_room.free()
	if current_scene != null and is_instance_valid(current_scene):
		current_scene.free()
	_room = null
	current_scene = null


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
