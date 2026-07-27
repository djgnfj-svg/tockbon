extends SceneTree
## 지점(랜드마크) + **입구→지점 흙길** 자동 검증 — 세99 단계 3. 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_landmark_road_auto.gd
## 전 항목 통과 시 "TEST_LANDMARK_ROAD_OK" 출력 후 종료 코드 0.
## 정본 = `docs/takbon-design/dungeon_structure_design.md` §3(지점) · D3·D4.
##
## 🔴🔴 **왜 새 파일인가 — 이 축은 「비어 있다」만 재던 자리다.**
## `test_dungeon_schema_auto [5]`가 *"landmarks 비어 있다"*로 재고 있었는데 **소비자가 생겼다**
## (`boss_room._spawn_landmarks`·`_landmark_road_cells`). 켜진 축은 「안 켜졌나」가 아니라
## **「제대로 도나」**를 재야 한다 — `extract_points`가 단계 1b에 밟은 절차 그대로 여기로 옮겼다.
##
## 🔴 여기서 헤드리스가 **실제로 잡는** 것:
##  [1] 데이터 세 걸음이 다 이어진다 — `ChapterDef.landmarks` → `Db.landmarks` → `scene_path` 실재.
##      🔴 어느 걸음이 끊겨도 **화면엔 아무 일도 안 난다**(설계 §7 F1의 침묵 자리)
##  [2] 지점이 **데이터 좌표에 실제로 선다** — 그룹 `landmarks` · 슬롯 수 일치 · 좌표 일치 · 쓴 씬 일치
##  [3] 🔴🔴 **입구에서 지점까지 흙길이 끊김 없이 이어진다** — 플레이어 스폰 칸에서 **흙길만 밟고**
##      번져 지점 칸에 닿는다. 세99 전반의 길은 가장자리에서 튀어나온 **토막**이었다(목적지가 없었다)
##  [4] **바닥에 안 뜬다의 값 축** — 프롭의 원점이 **접지점**이다(`centered=false` + `offset`).
##      🔴 이 둘 중 하나만 바뀌어도 그림이 95/140px 튀는데 **에러가 0**이다
##  [5] 프롭 계약 — **물리 몸이 없다** · 감지 Area는 `collision_layer = 0`(world면 캐리어가 터진다)
##  [6] 🐺 늑대 무리가 **둥지를 둘러싸고** 있고, **들어가는 줄기에서는 aggro 밖**이다
##      (= 설계 §3의 *"✅ 지나가도 된다"*가 좌표로 성립하나)
##  [7] 🔴 회귀 — `landmarks`를 비우면 지점도 **그 길도** 사라진다(길이 지점에서 파생한다는 증명)
##  [8] 스프라이트 2컷이 실재하고 **실제로 물린다** · 갈아 끼우면 다른 컷이 온다
##  [9] 🔴🔴 **앞뒤 겹침** — 뒤에 서면 z가 올라오고 비친다 · 앞으로 나오면 되돌아온다
##      (보스방엔 y-sort가 없어 **둘을 같이** 해야 하는데 한쪽만 해도 **에러가 0**이다)
##
## ⚠ 못 잡는 것: **겉보기 판단 전부** — 둥지가 떠 보이나 · 길이 「길」로 읽히나 · 늑대가 무리로
##  보이나 · 비침 알파 0.5가 적당한가. 전부 스샷·F5 몫이다(§보고서 참조).
## ⚠ [8]은 `.import` 사이드카가 없으면 **SKIP**으로 빠진다(PNG 파일 실재는 그래도 잰다) —
##  리드가 `--import`를 돌리면 같은 줄이 자동으로 **측정으로 바뀐다**(딱지가 아니라 스위치다).
##  ✅ 세99에 리드가 이미 돌렸다 — 지금은 SKIP 0이다.
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

## 🔴 타일 소스 id·벌판 좌표는 **명시 상수로 박는다** — `boss_room`의 const에서 파생하면 둘 다 밀려도
##  통과한다. ⚠ `test_extract_hold_auto`가 같은 값을 든다 — **사본이 아니라 「손으로 든 기대치」다**
##  (그 파일 §35~44 머리말이 같은 이유를 적어 뒀다). 시트를 바꾸면 두 곳이 같이 빨개지는 게 맞다.
const TILE_SRC_GROUND := 2
const GRASS_ATLAS: Array[Vector2i] = [Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)]

## 🔴 둥지 스프라이트의 **접지 계약** (art 리포트 `docs/_reports/nest_art.md` §「dev에게」).
##  텍스처 (95,140) = 굴 입구의 x 중심이자 흙더미가 바닥에 닿는 줄. `centered=false`면 offset이 그 음수.
const NEST_SCENE := "res://src/props/nest.tscn"
const NEST_ANCHOR_OFFSET := Vector2(-95, -140)
const NEST_TEX_INTACT := "res://assets/sprites/props/nest_wolf.png"
const NEST_TEX_BROKEN := "res://assets/sprites/props/nest_wolf_broken.png"
const NEST_FRAME := Vector2i(192, 152)

## 🐺 무리의 기대치 — **손으로 든다**(데이터에서 파생하면 무리를 지워도 통과한다).
## ⚠ 사용자가 F5로 수를 조이면 이 값도 같이 고쳐라 — 그게 이 상수의 목적이다(조용히 비지 않게).
const WOLF_ID := &"hound"
const WOLF_MIN := 4
## 둥지에서 이만큼 안에 서 있어야 「둘러싸고 있다」 — 밖이면 그냥 방에 흩어진 잡몹이다.
const WOLF_RING_MIN := 140.0
const WOLF_RING_MAX := 400.0

var failures: int = 0
var skips: int = 0
var _gs = null
var _db = null
var _scene = null
var _room = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		print("TEST_LANDMARK_ROAD_TIMEOUT — 60초 초과")
		quit(1))
	await process_frame

	_gs = root.get_node("/root/GameState")
	_db = root.get_node("/root/Db")
	_scene = load("res://src/field/boss_room.tscn") as PackedScene

	_test_data_chain()
	await _test_stands_where_data_says()
	await _test_road_reaches_landmark()
	_test_ground_anchor_contract()
	_test_prop_has_no_physics_body()
	await _test_wolf_pack()
	await _test_regression_when_empty()
	_test_textures()
	await _test_seen_through_when_behind()

	await _cleanup()

	if failures == 0:
		print("TEST_LANDMARK_ROAD_OK — 전 항목 통과 (SKIP %d)" % skips)
		quit(0)
	else:
		print("TEST_LANDMARK_ROAD_FAIL — %d건 실패 (SKIP %d)" % [failures, skips])
		quit(1)


## 🔴 뒷정리 = 계약이다 — 방을 남기면 뒤 테스트에서 플레이어가 둘이 된다(`test_chapter_auto` 선례).
func _cleanup() -> void:
	_gs.pending_chapter = &""
	_gs.ui_modal_open = false
	_free_room()
	await process_frame
	root.get_node("/root/SaveManager").wipe_save()


## [1] 🔴 데이터 세 걸음 — 어느 하나가 끊겨도 **화면엔 아무 일도 안 난다.**
func _test_data_chain() -> void:
	print("[1] ChapterDef.landmarks → Db.landmarks → scene_path")
	var ch = _db.get_chapter(&"ch1")
	_check(ch != null, "ch1이 로드된다 (전제)")
	if ch == null:
		return
	# 🔴 **「비어 있지 않다」가 이 항목의 심장이다** — 단계 3을 켜 놓고 데이터를 안 채우면
	#  코드는 멀쩡한데 방엔 지점이 0개고 **전 스위트가 그린**이다(세97 「기능이 돈다 ≠ 거기 갈 수 있다」).
	_check(not ch.landmarks.is_empty(),
		"🔴🔴 ch1이 지점을 싣고 있다 (실제 %d개 — 0이면 실게임은 세98 그대로 빈 숲이다)"
			% ch.landmarks.size())
	for slot in ch.landmarks:
		_check(slot != null, "ch1: 지점 슬롯이 살아 있다 (SubResource 하나가 죽으면 null이 섞인다)")
		if slot == null:
			continue
		var def = _db.get_landmark(slot.landmark_id)
		_check(def != null, "ch1: 슬롯의 landmark_id(%s)가 Db.landmarks에 실재한다" % slot.landmark_id)
		if def == null:
			continue
		_check(def.scene_path != "",
			"%s: scene_path가 비어 있지 않다 (비면 자리만 잡고 겉모습이 없다)" % def.id)
		_check(def.scene_path != "" and ResourceLoader.exists(def.scene_path),
			"%s: scene_path '%s'가 실재한다" % [def.id, def.scene_path])
		# 🔴 자리를 안 정하고 켜면 지점이 **원점(0,0)** = 남쪽 입구 한복판에 선다(에러 0).
		_check(slot.position != Vector2.ZERO,
			"%s: 자리가 원점이 아니다 (실제 %s — 원점은 「안 정했다」의 값이다)" % [def.id, slot.position])


## [2] 지점이 **데이터 좌표에 실제로 선다** — 방을 띄워 노드를 센다.
## 🔴 그룹 `landmarks`로 찾는다(경로 하드코딩 금지) — 방이 붙이므로 새 지점이 빠뜨릴 수 없다.
func _test_stands_where_data_says() -> void:
	print("[2] 지점이 데이터 좌표에 실제로 선다")
	await _fresh(&"ch1")
	var ch = _db.get_chapter(&"ch1")
	var nodes := get_nodes_in_group("landmarks")
	_check(nodes.size() == ch.landmarks.size(),
		"🔴 슬롯 %d개 → 지점 노드 %d개 (실제 %d — 적으면 어느 걸음이 조용히 끊긴 것이다)"
			% [ch.landmarks.size(), ch.landmarks.size(), nodes.size()])
	for slot in ch.landmarks:
		if slot == null:
			continue
		var def = _db.get_landmark(slot.landmark_id)
		var found = null
		for n in nodes:
			if n.position.distance_to(slot.position) < 1.0:
				found = n
		_check(found != null, "🔴 %s가 슬롯 좌표 %s에 섰다" % [slot.landmark_id, slot.position])
		if found == null or def == null:
			continue
		# 🔴 **쓴 씬이 그 지점의 씬인가** — 다른 프롭이 서 있어도 좌표만 맞으면 위 검사는 통과한다.
		_check(found.scene_file_path == def.scene_path,
			"%s: 실제로 선 씬이 scene_path와 같다 (실제 '%s')" % [slot.landmark_id, found.scene_file_path])


## [3] 🔴🔴 **이번 세션의 목표 — 입구에서 지점까지 흙길이 끊김 없이 이어진다.**
##
## 🔴 **연결을 값으로 잰다**: 플레이어 스폰 칸에서 시작해 **흙길 칸만 밟고** 4방향으로 번져
##  지점 칸에 닿는가. 「길 칸이 몇 개 있다」로 재면 방 어딘가에 흙 얼룩이 있기만 해도 통과한다.
## ⚠ **길의 「모양」(어디서 꺾이나)은 안 잰다** — 그건 연출 판단이라 스샷·F5가 정한다.
##  여기서 못 박는 건 **「입구와 지점이 흙으로 이어져 있다」** 하나다.
func _test_road_reaches_landmark() -> void:
	print("[3] 입구 → 지점 흙길이 끊김 없이 이어진다")
	await _fresh(&"ch1")
	var g := _grid()
	var entrance := _entrance_cell(g)
	_check(_is_road(entrance),
		"🔴 입구(플레이어 스폰) 발밑이 흙길이다 (칸 %s — 아니면 길이 입구에서 시작하지 않는다)" % entrance)
	for n in get_nodes_in_group("landmarks"):
		var cell := _cell_of(n.position, g)
		_check(_is_road(cell),
			"🔴 지점 %s 발밑이 흙길이다 (칸 %s — 아니면 길이 지점 앞에서 안 끝난다)" % [n.position, cell])
		_check(_road_connected(entrance, cell),
			"🔴🔴 입구 %s → 지점 %s 가 **흙길만 밟고** 이어진다 (끊기면 「저쪽에 뭔가 있다」를 알 방법이 없다)"
				% [entrance, cell])


## [4] 🔴 **「바닥에 안 뜬다」의 값 축** — 프롭의 원점이 접지점이라는 계약.
## `LandmarkSlot.position`이 곧 「둥지가 서 있는 땅」이고 흙길·겹침 판정이 전부 거기서 파생하므로,
## 이 둘 중 하나만 바뀌면 그림이 95/140px 튀어 **떠 보이거나 파묻힌다 — 에러는 0이다.**
## ⚠ 실제로 「떠 보이나」는 스샷이 정한다. 여기서 재는 건 **그 값이 계약대로인가** 하나다
##  (`test_scene_contract_auto`가 mouse_filter를 값으로 재는 것과 같은 결).
func _test_ground_anchor_contract() -> void:
	print("[4] 둥지 원점 = 접지점 (centered=false + offset)")
	var packed := load(NEST_SCENE) as PackedScene
	_check(packed != null, "%s가 로드된다 (전제)" % NEST_SCENE)
	if packed == null:
		return
	var node = packed.instantiate()
	_check(node is Sprite2D, "둥지 루트가 Sprite2D다 (텍스처 2장 교체 계약 — 실제 %s)" % node.get_class())
	if node is Sprite2D:
		_check(not node.centered,
			"🔴 centered = false (true면 그림이 접지점에서 통째로 어긋난다)")
		_check(node.offset == NEST_ANCHOR_OFFSET,
			"🔴 offset == %s (art 리포트의 접지점 (95,140) — 실제 %s)" % [NEST_ANCHOR_OFFSET, node.offset])
	# 🔴 「비워짐」으로 넘기는 문이 실재하나 — 나중에 「핵을 깼다」가 이어 붙을 자리다.
	_check(node.has_method("set_broken") and node.has_method("is_broken"),
		"🔴 상태 전환 문(set_broken/is_broken)이 있다")
	if node.has_method("set_broken"):
		_check(not node.is_broken(), "기본 상태 = 온전함")
		node.set_broken(true)
		_check(node.is_broken(), "set_broken(true)가 상태를 바꾼다")
		node.set_broken(false)
		_check(not node.is_broken(), "되돌아온다")
	node.free()


## [5] 🔴 프롭 계약 — **물리 몸이 없다.** StaticBody2D로 만들면 world 레이어라 마법 캐리어(마스크 5)가
## 지점마다 터진다(나무가 장식인 이유와 같다 — `boss_room.gd` 머리말). 감지 Area도 layer 0이어야 한다.
## ⚠ **재귀로 훑는다** — 자식 하나에 몰래 붙어도 잡힌다.
func _test_prop_has_no_physics_body() -> void:
	print("[5] 둥지에 물리 몸이 없다 (world 레이어면 캐리어가 터진다)")
	var packed := load(NEST_SCENE) as PackedScene
	if packed == null:
		return
	var node = packed.instantiate()
	var bodies: Array = []
	var areas: Array = []
	_collect(node, bodies, areas)
	_check(bodies.is_empty(), "🔴 PhysicsBody2D가 0개다 (실제 %s)" % str(bodies))
	_check(not areas.is_empty(), "감지 Area2D가 있다 (0이면 앞뒤 겹침 처리가 통째로 죽는다)")
	for a in areas:
		_check(a.collision_layer == 0,
			"🔴🔴 감지 Area의 collision_layer == 0 (실제 %d — 채우면 캐리어가 둥지마다 터진다)"
				% a.collision_layer)
		_check(not a.monitorable,
			"monitorable = false (다른 Area가 이걸 주우면 드롭·피격 판정에 섞인다)")
		_check(a.collision_mask == 2,
			"mask = 2(player) (실제 %d — 적까지 넓히려면 4를 더한다)" % a.collision_mask)
	node.free()


## [6] 🐺 늑대 무리 — **둥지를 둘러싸고** 있고, **들어가는 줄기에서는 aggro 밖**이다.
##
## 🔴 「둘러싸고 퍼져 있다」를 값으로 잰다: 반지름 대역 안 + **동서남북 네 방향에 다 있다.**
##  개수만 재면 한 줄로 세워 놔도 통과한다(사용자 원문은 *"확산된 늑대"*다).
## 🔴🔴 **설계 §3의 *"✅ 지나가도 된다"*가 좌표로 성립하나** — 입구에서 곧게 뻗는 **줄기**(= 입구 칸과
##  x가 같은 길 칸들)에서 늑대가 `aggro_range` 밖에 있어야, 지점을 **고르는** 것이 되지 통행세가 안 된다.
##  ⚠ 줄기의 정의도 **파생한다**(좌표를 안 박는다) — 길을 옮겨도 안 낡는다.
func _test_wolf_pack() -> void:
	print("[6] 늑대 무리 — 둥지를 둘러싸고 · 들어가는 줄기에선 aggro 밖")
	await _fresh(&"ch1")
	var ch = _db.get_chapter(&"ch1")
	var nest_at := Vector2.ZERO
	for n in get_nodes_in_group("landmarks"):
		nest_at = n.position
	var wolves: Array[Vector2] = []
	for ms in ch.mob_spawns:
		if ms != null and ms.enemy_id == WOLF_ID:
			wolves.append(ms.position)
	_check(wolves.size() >= WOLF_MIN,
		"🔴 둥지 무리로 %s가 %d마리 이상 배치됐다 (실제 %d)" % [WOLF_ID, WOLF_MIN, wolves.size()])

	var quad := {"e": 0, "w": 0, "n": 0, "s": 0}
	for at: Vector2 in wolves:
		var d := at.distance_to(nest_at)
		_check(d >= WOLF_RING_MIN and d <= WOLF_RING_MAX,
			"늑대 %s가 둥지 둘레 %.0f~%.0f에 있다 (실제 %.0f — 멀면 그냥 흩어진 잡몹이다)"
				% [at, WOLF_RING_MIN, WOLF_RING_MAX, d])
		if at.x > nest_at.x:
			quad["e"] += 1
		else:
			quad["w"] += 1
		if at.y < nest_at.y:
			quad["n"] += 1
		else:
			quad["s"] += 1
	_check(quad["e"] > 0 and quad["w"] > 0 and quad["n"] > 0 and quad["s"] > 0,
		"🔴 늑대가 **사방으로** 퍼졌다 (동%d 서%d 북%d 남%d — 한쪽만이면 「둘러싼」 게 아니다)"
			% [quad["e"], quad["w"], quad["n"], quad["s"]])

	# 🔴🔴 들어가는 줄기에서 aggro 밖인가 — `hound.params.aggro_range`를 **데이터에서 읽는다**.
	var hound = _db.get_enemy(WOLF_ID)
	_check(hound != null, "%s가 Db.enemies에 실재한다 (전제)" % WOLF_ID)
	if hound == null:
		return
	var aggro: float = float(hound.params.get("aggro_range", 0.0))
	_check(aggro > 0.0, "%s가 aggro_range를 들고 있다 (실제 %.0f)" % [WOLF_ID, aggro])
	var g := _grid()
	var entrance := _entrance_cell(g)
	var spine := _spine_points(entrance, g)
	_check(spine.size() >= 4,
		"입구 줄기 칸이 실제로 있다 (%d칸 — 0~1이면 이 검사가 자명 통과다)" % spine.size())
	for at: Vector2 in wolves:
		var best := INF
		for p: Vector2 in spine:
			best = minf(best, at.distance_to(p))
		_check(best > aggro,
			"🔴🔴 늑대 %s가 들어가는 줄기에서 aggro(%.0f) 밖이다 (실제 %.0f — 안이면 길을 걷기만 해도 깨어나 「지나가도 된다」가 죽는다)"
				% [at, aggro, best])


## [7] 🔴 회귀 — `landmarks`를 비우면 **지점도 그 길도** 사라진다.
## 🔴🔴 이게 「길이 지점에서 파생한다」의 증명이다 — 길을 좌표로 박아 두면 지점을 지워도 남는다(에러 0).
func _test_regression_when_empty() -> void:
	print("[7] landmarks를 비우면 지점도 길도 사라진다 (파생의 증명)")
	var ch = _db.get_chapter(&"ch1")
	var before: Array = ch.landmarks.duplicate()
	var lm_at := Vector2.ZERO
	for slot in ch.landmarks:
		if slot != null:
			lm_at = slot.position
	ch.landmarks.clear()
	await _fresh(&"ch1")
	_check(get_nodes_in_group("landmarks").is_empty(),
		"지점 노드가 0개다 (실제 %d)" % get_nodes_in_group("landmarks").size())
	var g := _grid()
	var entrance := _entrance_cell(g)
	var cell := _cell_of(lm_at, g)
	_check(not _road_connected(entrance, cell),
		"🔴🔴 옛 지점 자리 %s로 가는 흙길이 사라졌다 (남아 있으면 길이 좌표로 박힌 것이다)" % cell)
	ch.landmarks.assign(before)


## [8] 텍스처 — PNG 실재는 **늘** 재고, 실제로 물리는지는 `.import`가 있을 때만 잰다.
## 🔴🔴 **딱지가 아니라 스위치다**(감사 T7 경계): 리드가 `--import`를 돌리는 순간 같은 줄이
##  자동으로 측정으로 바뀐다. PNG **파일 자체**가 없으면 그건 지금도 실패다.
func _test_textures() -> void:
	print("[8] 둥지 스프라이트 2컷")
	for p: String in [NEST_TEX_INTACT, NEST_TEX_BROKEN]:
		_check(FileAccess.file_exists(p), "PNG가 디스크에 있다: %s" % p)
	if not ResourceLoader.exists(NEST_TEX_INTACT):
		skips += 1
		print("  SKIP: 🔴 `.import` 사이드카가 없어 텍스처를 못 읽는다 — **리드의 `--headless --import` 필요**.")
		print("        그때까지 방에 둥지가 **안 보이고** `nest.gd`가 USER ERROR로 짖는다(의도된 신호).")
		return
	var tex := load(NEST_TEX_INTACT) as Texture2D
	_check(tex != null, "온전함 컷이 Texture2D로 로드된다")
	_check(tex != null and tex.get_size() == Vector2(NEST_FRAME),
		"프레임이 %s다 (실제 %s — art 리포트 값)" % [NEST_FRAME, tex.get_size() if tex != null else Vector2.ZERO])
	var broken := load(NEST_TEX_BROKEN) as Texture2D
	_check(broken != null and broken.get_size() == Vector2(NEST_FRAME),
		"비워짐 컷도 같은 프레임이다 (접지선이 같아야 갈아 끼울 때 안 튄다)")
	# 🔴 실제로 물렸나 — 경로만 맞고 대입을 빠뜨리면 [4]는 그린인데 화면이 빈다.
	var packed := load(NEST_SCENE) as PackedScene
	var node = packed.instantiate()
	root.add_child(node)
	_check(node.texture != null, "🔴 씬을 세우면 텍스처가 실제로 물린다")
	if node.has_method("set_broken"):
		node.set_broken(true)
		_check(node.texture != null and node.texture != tex,
			"🔴 set_broken(true)가 **다른 컷**으로 갈아 끼운다")
	node.free()


## [9] 🔴🔴 **앞뒤 겹침 — 뒤에 서면 앞으로 끌려 나오고 비친다.**
##
## 보스방엔 y-sort가 없어서 **둘을 같이** 해야 한다(나무가 이미 푼 문제 — `tree.gd` 머리말):
##  ⓐ `z_index`를 플레이어(2)·지팡이(3) 위로 올리고 ⓑ `modulate:a`를 내린다.
## 🔴 **하나만 하면 「아무 일도 안 난다」(z만 빠짐)거나 「몸이 통째로 사라진다」(알파만 빠짐)가 되고
##  에러는 0이다.** 그래서 **둘을 같이** 잰다 — 한쪽만 재는 그물은 반쪽 고장을 그대로 통과시킨다.
## 🔴 **접지선 아래(남쪽)는 안 건드린다**도 같이 잰다: 그게 「위/아래가 곧 원근」이라는 계약이고,
##  이게 없으면 감지 상자를 아래로 늘려도 그물이 안 짖는다(플레이어가 둥지 앞인데 둥지가 앞에 온다).
## ⚠ **「보기 좋은가」(알파 0.5가 적당한가)는 못 잰다** — F5 몫이다. 여기서 재는 건 방향뿐이다.
func _test_seen_through_when_behind() -> void:
	print("[9] 뒤에 서면 앞으로 끌려 나오고 비친다 (y-sort 없는 방의 겹침 계약)")
	await _fresh(&"ch1")
	var nest = null
	for n in get_nodes_in_group("landmarks"):
		nest = n
	_check(nest != null, "지점이 섰다 (전제)")
	if nest == null:
		return
	var player: Node2D = _room.get_node("Player")
	var base_z: int = nest.z_index
	_check(base_z < 2,
		"평상시 z(%d)가 플레이어(2)보다 아래다 = 앞을 지나면 몸이 위에 그려진다" % base_z)

	# ── ⓐ 뒤(북쪽 = 접지선 위)에 선다
	player.global_position = nest.global_position + Vector2(0, -40)
	for i in 6:
		await physics_frame
	_check(nest.z_index > 3,
		"🔴🔴 뒤에 서면 z가 플레이어·지팡이(3) 위로 올라온다 (실제 %d — 안 올리면 흐려지기만 하고 화면이 그대로다)"
			% nest.z_index)
	await _wait(0.25)   # 페이드 트윈이 다 돌 때까지
	_check(nest.modulate.a < 0.95,
		"🔴🔴 뒤에 서면 비친다 (알파 %.2f — 안 내리면 둥지가 몸을 통째로 먹는다)" % nest.modulate.a)

	# ── ⓑ 앞(남쪽 = 접지선 아래)으로 나온다 → 원래대로
	player.global_position = nest.global_position + Vector2(0, 260)
	for i in 6:
		await physics_frame
	await _wait(0.25)
	_check(nest.z_index == base_z,
		"🔴 앞으로 나오면 z가 되돌아온다 (실제 %d — 안 내리면 둥지 앞인데 둥지가 앞에 남는다)" % nest.z_index)
	_check(is_equal_approx(nest.modulate.a, 1.0),
		"🔴 앞으로 나오면 다시 불투명하다 (실제 %.2f)" % nest.modulate.a)


# ── 도구 ──────────────────────────────────────────────────────────────────────


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


## 방 하나를 새로 띄운다 (`test_extract_hold_auto._fresh` 계약 그대로 — 방을 남기면 플레이어가 둘이 된다).
func _fresh(chapter_id: StringName) -> void:
	_free_room()
	_gs.pending_chapter = chapter_id
	_room = _scene.instantiate()
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


func _tiles() -> TileMapLayer:
	return _room.get_node("TileGround") as TileMapLayer


## `boss_room._fill_tiles`와 **같은 방식으로** 셀 범위를 파생한다 — 좌표를 베끼면 방을 키울 때
## 이 그물만 낡아 거짓 빨강이 난다.
func _grid() -> Dictionary:
	var ground: ColorRect = _room.get_node("Ground")
	var ts: Vector2i = _tiles().tile_set.tile_size
	var rect := Rect2(ground.position, ground.size).grow(-float(ts.x))
	return {
		"ts": ts,
		"from": Vector2i(floori(rect.position.x / ts.x), floori(rect.position.y / ts.y)),
		"to": Vector2i(ceili(rect.end.x / ts.x), ceili(rect.end.y / ts.y)),
	}


## 🔴 **입구 = 플레이어 스폰 노드**다 — 좌표를 박지 않는다(구현과 같은 정의를 쓴다).
func _entrance_cell(g: Dictionary) -> Vector2i:
	var player: Node2D = _room.get_node("Player")
	return _cell_of(player.position, g)


func _cell_of(at: Vector2, g: Dictionary) -> Vector2i:
	var ts: Vector2i = g["ts"]
	return Vector2i(floori(at.x / float(ts.x)), floori(at.y / float(ts.y)))


## 🔴 「이 칸이 흙길인가」 — **아틀라스 좌표로 가른다**(source id로는 못 가른다: 벌판과 길이 같은 시트다).
## 벌판 좌표 셋을 손으로 들고 **그 밖이면 길**로 본다 — 길 쪽을 열거하면 오토타일이 새 칸을 쓰는 날
## 그물이 조용히 눈을 감는다(`test_extract_hold_auto._is_road`와 같은 판단).
func _is_road(cell: Vector2i) -> bool:
	if _tiles().get_cell_source_id(cell) != TILE_SRC_GROUND:
		return false
	return not GRASS_ATLAS.has(_tiles().get_cell_atlas_coords(cell))


## 🔴🔴 **흙길만 밟고 a에서 b까지 갈 수 있나** — 이번 세션 목표의 측정자.
## 4방향 번짐(대각 금지: 대각으로만 스치는 두 길은 걸어서 못 잇는다).
func _road_connected(a: Vector2i, b: Vector2i) -> bool:
	if not _is_road(a) or not _is_road(b):
		return false
	var g := _grid()
	var from: Vector2i = g["from"]
	var to: Vector2i = g["to"]
	var seen := {a: true}
	var queue: Array[Vector2i] = [a]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		if c == b:
			return true
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + step
			if n.x < from.x or n.x >= to.x or n.y < from.y or n.y >= to.y or seen.has(n):
				continue
			if not _is_road(n):
				continue
			seen[n] = true
			queue.append(n)
	return false


## 🔴 **입구에서 곧게 뻗는 줄기**의 칸 중심점들 — 「길을 걷기만 해도 깨어나나」의 기준선.
## 정의를 **파생시킨다**: 입구 칸과 x가 통로 반폭 안인 길 칸(= 꺾이기 전의 줄기). 길을 옮겨도 안 낡는다.
func _spine_points(entrance: Vector2i, g: Dictionary) -> Array[Vector2]:
	var ts: Vector2i = g["ts"]
	var from: Vector2i = g["from"]
	var to: Vector2i = g["to"]
	var out: Array[Vector2] = []
	for y in range(from.y, to.y):
		for x in range(entrance.x - 1, entrance.x + 2):
			if x < from.x or x >= to.x:
				continue
			var cell := Vector2i(x, y)
			if _is_road(cell):
				out.append(Vector2((float(x) + 0.5) * ts.x, (float(y) + 0.5) * ts.y))
	return out


func _collect(node: Node, bodies: Array, areas: Array) -> void:
	if node is PhysicsBody2D:
		bodies.append(node.name)
	elif node is Area2D:
		areas.append(node)
	for c in node.get_children():
		_collect(c, bodies, areas)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
