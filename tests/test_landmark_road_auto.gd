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
##      + 🔴🔴 **길의 「모양」**(세100 N25ⓐ) — 꺾이는 자리가 (입구 x, 지점 y)인가.
##      **연결만 재던 동안 `_road_between`의 인자를 뒤집어도 전 항목 그린이었다**(리드 md5 실측)
##  [4] **바닥에 안 뜬다의 값 축** — 프롭의 원점이 **접지점**이다(`centered=false` + `offset`).
##      🔴 이 둘 중 하나만 바뀌어도 그림이 95/140px 튀는데 **에러가 0**이다
##  [5] 프롭 계약 — **물리 몸이 없다** · Area **둘**의 레이어 계약(세101에 여는 지점이 붙어 갈렸다):
##      공통 = world·enemy 비트 0(캐리어가 터진다) · 겹침 감지 = layer 0 + 아래 변이 접지선 위 ·
##      여는 지점 = zone_id ≠ `&"exit"` + `hold_sec == 0`(D10 즉시)
##  [6] 🐺 늑대 무리가 **둥지를 둘러싸고** 있고, **들어가는 줄기에서는 aggro 밖**이다
##      (= 설계 §3의 *"✅ 지나가도 된다"*가 좌표로 성립하나)
##  [7] 🔴 회귀 — `landmarks`를 비우면 지점도 **그 길도** 사라진다(길이 지점에서 파생한다는 증명)
##  [8] 스프라이트 2컷이 실재하고 **실제로 물린다** · 갈아 끼우면 다른 컷이 온다
##  [9] 🔴🔴 **앞뒤 겹침** — 뒤에 서면 z가 올라오고 비친다 · 앞으로 나오면 되돌아온다
##      (보스방엔 y-sort가 없어 **둘을 같이** 해야 하는데 한쪽만 해도 **에러가 0**이다)
##      🔴 z 기대치·앞 프로브를 **살아 있는 노드·접지선에서 파생**시킨다(세100 N25ⓑⓒ)
## [10] 🔴 **루트가 Node2D가 아닌 지점 씬** — 방이 안 죽고 그 자리만 빈다(세100 N25 잔가지)
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
## 🔴 세112 1c: 씬이 `nest.tscn` → **`chest.tscn`**으로 개명됐다(`chest.gd` 머리말이 해소표).
##  ⚠ 텍스처 상수 둘은 **안 바뀌었다** — PNG 개명은 `--import`가 필요해 리드 몫으로 남았다.
const NEST_SCENE := "res://src/props/chest.tscn"
const NEST_ANCHOR_OFFSET := Vector2(-95, -140)
const NEST_TEX_INTACT := "res://assets/sprites/props/nest_wolf.png"
const NEST_TEX_BROKEN := "res://assets/sprites/props/nest_wolf_broken.png"
const NEST_FRAME := Vector2i(192, 152)

## 🔴🔴 「둥지 **앞**에 선다」의 프로브 거리 (세100 N25ⓑ) — **접지선(프롭 원점)에서 이만큼 아래**.
## 🔴 **작아야 그물이다.** 세99엔 260px이라 감지 상자를 아래로 250px 늘려도 프로브가 여전히 밖이라
##  전 항목 그린이었다 — *"둥지 앞에 섰는데 둥지가 앞으로 튀어나온다"*가 **무증상**으로 지나갔다.
## ⚠ **그림 크기와 무관한 값이다** — 기준이 스프라이트 치수가 아니라 **원점(=접지선)**이라
##  둥지를 두 배로 다시 그려도 안 낡는다. 플레이어 몸 반경(10px)만큼은 띄워야 겹치지 않는다.
const FRONT_PROBE_PAD := 20.0

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
	await _test_non_node2d_landmark_is_skipped()

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
## 🔴🔴 **세100(N25ⓐ): 연결만으로는 모자랐다** — `_road_between(지점, 입구)`의 **인자를 뒤집어도
##  이 항목이 전부 그린이었다**(리드가 md5 대조로 확증). 뒤집힌 길도 「이어져는 있기」 때문이다.
##  그 함수 머리말이 *"뒤집으면 방 아래쪽이 통째로 흙 밭"*이라고 스스로 적어 둔 계약이 **무증상**이었다.
##  → `_check_road_shape`가 그 자리를 잰다(아래 머리말 참조).
## ⚠ **「길이 예뻐 보이나」는 여전히 안 잰다** — 그건 스샷·F5 몫이다. 여기서 재는 건 **꺾이는 자리**뿐이다.
func _test_road_reaches_landmark() -> void:
	print("[3] 입구 → 지점 흙길이 끊김 없이 이어진다 + 꺾이는 자리(모양)")
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
		_check_road_shape(entrance, cell, g)


## 🔴🔴 **길의 모양 = 「어느 열로 들어가나」** (세100 N25ⓐ — 이 파일의 새 심장).
##
## 계약(`boss_room._landmark_road_cells` 머리말): 길은 **입구 열로 곧게 들어가다가** 지점 행에서 꺾인다.
## 즉 ㄱ자의 꺾이는 자리가 **(입구 x, 지점 y)**다. 인자를 뒤집으면 꺾이는 자리가 **(지점 x, 입구 y)**가 돼
## 방 아래쪽을 가로로 훑고 나가는 길과 겹친다(= *"방 아래쪽이 통째로 흙 밭"*).
##
## 🔴 **좌표를 한 톨도 안 박는다 — 두 노드에서 파생한 관계식 둘**이다(지점을 옮겨도 안 낡는다):
##  ⓐ **입구 열의 줄기가 지점 행까지 끊김 없이 닿는다** (= 세로 다리가 입구 쪽에 있다)
##  ⓑ **지점 열에는 그런 줄기가 없다** — 지점에서 입구 쪽으로 내려가는 흙길 run이 ⓐ보다 **짧다**
## 🔴 ⓑ가 **대소 비교**인 이유: 「몇 칸 이하」로 박으면 방·길 폭을 조일 때 거짓 빨강이 난다
##  (`test_jin_layers_auto [4]`가 수치 대신 대소로만 재는 것과 같은 판단).
## ⚠ 지점이 입구와 **같은 열**에 서면 두 순서가 같은 그림을 낸다 — 그땐 ⓑ가 자명 통과라 SKIP으로 뺀다
##  (자명한 줄을 PASS로 찍으면 「재고 있다」는 착각이 남는다).
func _check_road_shape(entrance: Vector2i, cell: Vector2i, g: Dictionary) -> void:
	var span: int = absi(entrance.y - cell.y)
	var toward: int = signi(cell.y - entrance.y)
	if toward == 0:
		toward = -1   # 같은 행 — 세로 다리가 없다. 아래 기대치가 1칸이라 자명 통과가 된다.
	var stem := _run_length(entrance, Vector2i(0, toward), g)
	_check(stem >= span + 1,
		"🔴🔴 입구 열(x=%d)의 줄기가 지점 행(y=%d)까지 닿는다 (실제 %d칸 / 필요 %d칸 — 모자라면 길이 입구가 아니라 **지점 열**로 들어간 것이다)"
			% [entrance.x, cell.y, stem, span + 1])
	if cell.x == entrance.x:
		skips += 1
		print("  SKIP: 지점이 입구와 같은 열(x=%d)이라 두 인자 순서가 같은 그림을 낸다 — 모양 대조 자명 통과"
			% cell.x)
		return
	var side := _run_length(cell, Vector2i(0, -toward), g)
	_check(side < stem,
		"🔴🔴 지점 열(x=%d)에는 입구까지 내려가는 줄기가 **없다** (지점 열 %d칸 < 입구 열 %d칸 — 뒤집히면 여기가 통째로 흙 밭이다)"
			% [cell.x, side, stem])


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
## 지점마다 터진다(나무가 장식인 이유와 같다 — `boss_room.gd` 머리말).
## ⚠ **재귀로 훑는다** — 자식 하나에 몰래 붙어도 잡힌다.
##
## 🔴🔴 **세101 N26: Area가 둘이 됐다 — 「전부 layer 0」을 「전부 world·enemy 아님」으로 넓혔다.**
##  ⓐ `BehindSense`(스크립트 없음) = 겹침 감지. **세99 계약 그대로** layer 0 · monitorable false ·
##     아래 변이 접지선 위. 🔴 여기 넷은 한 톨도 안 무르게 뒀다.
##  ⓑ `OpenZone`(`interact_zone.gd`) = 여는 지점(D10). **layer 64(interaction)**가 그 스크립트의
##     선언된 계약이라 「전부 0」을 그대로 두면 **거짓 빨강**이 된다.
##  🔴 **진짜 불변식은 「캐리어가 안 터진다」이고 그건 `layer & 5 == 0`이다**(마스크 5 = world 1 +
##   enemy 4). 64는 그 밖이라 안전하다 — 그래서 넓히면서 검출력이 안 준다: layer 1이나 4를 켜는
##   순간 **여전히** 빨개진다.
##  🔴 mask는 **둘 다 2(player)**다 — `OpenZone`에 4(enemy)를 더하면 둘레 늑대가 스칠 때마다
##   프롬프트가 제멋대로 뜨고 사라진다(설계 §10-4 **S26**). 화면은 「그냥 좀 이상한」 정도다.
##  ⚠ **아래 변 검사는 `BehindSense`에만 건다** — 그 계약의 근거가 「위/아래가 곧 원근」이라
##   상호작용 거리와는 축이 다르다(`OpenZone`은 남쪽에서 걸어오는 몸을 잡아야 해서 접지선 아래로 내려온다).
func _test_prop_has_no_physics_body() -> void:
	print("[5] 둥지에 물리 몸이 없다 · 겹침 Area와 여는 Area의 계약이 각각 산다")
	var packed := load(NEST_SCENE) as PackedScene
	if packed == null:
		return
	var node = packed.instantiate()
	var bodies: Array = []
	var areas: Array = []
	_collect(node, bodies, areas)
	_check(bodies.is_empty(), "🔴 PhysicsBody2D가 0개다 (실제 %s)" % str(bodies))
	_check(areas.size() >= 2,
		"Area2D가 둘이다 — 겹침 감지 + 여는 지점 (실제 %d — 밑돌면 아래가 자명 통과다)" % areas.size())

	var sense = null
	var open_zone = null
	for a in areas:
		# 🔴 스크립트가 갈라 준다 — 노드 **이름**으로 가르면 이름을 바꾸는 순간 그물이 눈을 감는다.
		if a.has_method("player_in_range"):
			open_zone = a
		else:
			sense = a
		# 🔴🔴 **공통 불변식** — world(1)·enemy(4) 비트가 하나도 안 켜져 있다(캐리어 마스크 = 5).
		_check(a.collision_layer & 5 == 0,
			"🔴🔴 %s의 collision_layer에 world·enemy 비트가 없다 (실제 %d — 켜면 캐리어가 둥지마다 터진다)"
				% [a.name, a.collision_layer])
		# 🔴 S26 — 둘 다 **플레이어만** 본다. 적까지 넓히면 늑대가 스칠 때마다 판정이 돈다.
		_check(a.collision_mask == 2,
			"%s: mask = 2(player) (실제 %d — 4(enemy)를 더하면 늑대가 스칠 때마다 반응한다)"
				% [a.name, a.collision_mask])

	# ── ⓐ 겹침 감지 — 세99 계약 그대로
	_check(sense != null, "🔴 겹침 감지 Area가 있다 (없으면 앞뒤 겹침 처리가 통째로 죽는다)")
	if sense != null:
		_check(sense.collision_layer == 0,
			"🔴🔴 겹침 감지 Area의 collision_layer == 0 (실제 %d)" % sense.collision_layer)
		_check(not sense.monitorable,
			"monitorable = false (다른 Area가 이걸 주우면 드롭·피격 판정에 섞인다)")
		# 🔴🔴 세100 N25ⓑ의 **정적 짝** — 감지 상자가 접지선(원점) 아래로 안 내려간다.
		#  이게 「위/아래가 곧 원근」의 값 축이다: 아래로 새면 둥지 **앞**에 선 플레이어까지 뒤로 잡혀
		#  「앞에 섰는데 둥지가 앞으로 튀어나온다」가 된다(에러 0). [9]ⓑ가 같은 계약을 실제로 걸어 본다.
		var bottom := _sense_bottom(sense)
		_check(bottom > -INF, "겹침 감지 Area(%s)에 형상이 실제로 물려 있다" % sense.name)
		_check(bottom <= 0.5,
			"🔴🔴 감지 상자 아래 변이 접지선 위다 (원점 기준 y %.1f — 0을 넘으면 둥지 앞이 뒤로 잡힌다)"
				% bottom)

	# ── ⓑ 여는 지점 (세101 N26 · D10) — 자세한 동작은 `test_nest_open_auto`가 잰다.
	_check(open_zone != null,
		"🔴 여는 지점(InteractZone)이 있다 (없으면 둥지가 **밟을 방법 없는 이정표**로 돌아간다)")
	if open_zone != null:
		# 🔴 `&"exit"`이면 `test_chapter_auto`가 출구로 세어 「_extract에 이어진 수」와 어긋난다.
		_check(open_zone.zone_id != &"exit",
			"🔴🔴 여는 지점의 zone_id가 &\"exit\"이 아니다 (실제 '%s')" % open_zone.zone_id)
		# 🪦 `hold_sec == 0` 검사는 세112 R1에 지웠다 — 홀드(D7)가 폐기돼 그 프로퍼티가 **없다**
		#  (읽으면 런타임 에러다). 재던 계약(**[E] 한 번에 즉시**)은 이제 **모든 지점의 유일한 동작**이라
		#  잴 대상 자체가 사라졌고, 「그 프레임에 열리나」는 `test_chest_open_auto` ⓐ가 행동으로 잰다.
		_check(open_zone.get_node_or_null(^"Prompt") != null,
			"🔴 `Prompt` Label이 있다 (이름이 계약이다 — 없으면 안내가 통째로 죽는다)")
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
	# 🔴 세105 **이름 승계** — 정본 키는 `sight_range`, 옛 이름은 폴백이다(설계 §8-1).
	var aggro: float = float(hound.params.get("sight_range", hound.params.get("aggro_range", 0.0)))
	_check(aggro > 0.0, "%s가 sight_range(옛 aggro_range)를 들고 있다 (실제 %.0f)" % [WOLF_ID, aggro])
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
## 🔴🔴 **세100(N25ⓑ): 그 ⓑ 프로브가 접지선에서 260px이나 떨어져 있었다** — 감지 상자를 아래로
##  **250px 늘려도 전 항목 그린**이었다(= *"둥지 앞에 섰는데 둥지가 앞으로 튀어나온다"*가 무증상).
##  → 프로브를 **접지선 바로 아래**(`FRONT_PROBE_PAD`)로 당겼다. 정적인 짝은 [5]가 형상에서 잰다.
## 🔴🔴 **세100(N25ⓒ): z 기대치를 리터럴로 안 든다** — 플레이어 스프라이트(2)·떠있는 지팡이(3)를
##  **살아 있는 노드에서 읽는다**. 리터럴이면 플레이어 z를 올리는 날 프롭이 조용히 몸 뒤로 숨는데
##  **그물도 같이 눈을 감는다**(감사 T5 — 그 숫자가 네 곳에 흩어져 있다).
##  ⚠ 고치는 건 **그물**이지 구조가 아니다 — `tree.gd`/`nest.gd`의 공용 부모를 만들지 마라
##   (`nest.gd` 머리말이 *"소비자 둘짜리 추상"*이라 거절한 판단이 옳다).
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
	# 🔴 기대치를 **살아 있는 플레이어에서 읽는다** — 씬 값이든 스크립트 대입이든 같은 답이 나온다.
	var sprite_z := _live_z(player, ^"Sprite")
	var wand_z := _live_z(player, ^"FloatingWand")
	_check(sprite_z > 0 and wand_z > 0,
		"플레이어 몸 z를 실제 노드에서 읽었다 (스프라이트 %d · 지팡이 %d — 0이면 이 검사가 자명 통과다)"
			% [sprite_z, wand_z])
	var body_z: int = maxi(sprite_z, wand_z)
	var base_z: int = nest.z_index
	_check(base_z < sprite_z,
		"평상시 z(%d)가 플레이어 스프라이트(%d)보다 아래다 = 앞을 지나면 몸이 위에 그려진다"
			% [base_z, sprite_z])

	# ── ⓐ 뒤(북쪽 = 접지선 위)에 선다
	player.global_position = nest.global_position + Vector2(0, -40)
	for i in 6:
		await physics_frame
	_check(nest.z_index > body_z,
		"🔴🔴 뒤에 서면 z가 플레이어 몸(스프라이트·지팡이 중 위 = %d)보다 올라온다 (실제 %d — 안 올리면 흐려지기만 하고 화면이 그대로다)"
			% [body_z, nest.z_index])
	await _wait(0.25)   # 페이드 트윈이 다 돌 때까지
	_check(nest.modulate.a < 0.95,
		"🔴🔴 뒤에 서면 비친다 (알파 %.2f — 안 내리면 둥지가 몸을 통째로 먹는다)" % nest.modulate.a)

	# ── ⓑ 앞(남쪽 = 접지선 **바로** 아래)으로 나온다 → 원래대로
	# 🔴 여기가 이 항목의 급소다: 「접지선 아래는 앞」이 계약이라 **접지선에 붙여** 서야
	#  감지 상자가 조금이라도 아래로 새는 순간 빨개진다. 멀리 세우면 상자를 늘려도 안 짖는다(N25ⓑ).
	player.global_position = nest.global_position + Vector2(0, FRONT_PROBE_PAD)
	for i in 6:
		await physics_frame
	await _wait(0.25)
	_check(nest.z_index == base_z,
		"🔴🔴 접지선 아래 %.0fpx에 서면 z가 되돌아온다 (실제 %d — 안 내리면 둥지 앞인데 둥지가 앞에 남는다)"
			% [FRONT_PROBE_PAD, nest.z_index])
	_check(is_equal_approx(nest.modulate.a, 1.0),
		"🔴 앞으로 나오면 다시 불투명하다 (실제 %.2f)" % nest.modulate.a)


## [10] 🔴 **루트가 Node2D가 아닌 지점 씬 — 방은 계속 서고 그 자리만 빈다** (세100 N25 잔가지).
##
## 🔴🔴 왜 재나: `_spawn_landmarks`의 가드 넷(**def 없음·scene_path 빔·로드 실패**) 뒤에
##  `node.position` 한 줄이 **무방비**였다. `packed.instantiate() as Node2D`는 루트가 Control이면
##  **null을 내고**, 바로 다음 줄이 그 null에 쓴다 → **SCRIPT ERROR로 판이 통째로 안 선다**
##  (보스도 잡몹도 길도 없다). 「새 지점 = 프롭 씬 한 장」이 그 함수의 **선언된 계약**이라 남이 밟는다.
##
## 🔴 **이 항목의 진짜 검출자는 `SCRIPT ERROR` grep이다**(세59 `test_spell_vfx_auto`의 null 가드와
##  같은 결) — 그래서 **나쁜 슬롯을 앞에 꽂는다**: 가드가 없으면 거기서 루프가 죽어 **뒤의 진짜 둥지가
##  안 서고 길도 안 깔린다**. 그 결과를 값으로도 잡는다.
## ⚠ Control 루트 씬은 **살아 있는 것을 빌린다**(`damage_number.tscn` = Label) — 이 테스트용으로
##  씬을 새로 만들면 그 파일이 「누가 쓰나」 없이 리포에 남는다.
const BAD_ROOT_SCENE := "res://src/hud/damage_number.tscn"
const BAD_LANDMARK := &"lm_bad_root_probe"

func _test_non_node2d_landmark_is_skipped() -> void:
	print("[10] 루트가 Node2D가 아닌 지점 씬 — 방이 안 죽고 그 자리만 빈다")
	var ch = _db.get_chapter(&"ch1")
	var before: Array = ch.landmarks.duplicate()
	var def = (load("res://src/core/schemas/landmark_def.gd") as GDScript).new()
	def.id = BAD_LANDMARK
	def.scene_path = BAD_ROOT_SCENE
	_db.landmarks[BAD_LANDMARK] = def
	var slot = (load("res://src/core/schemas/landmark_slot.gd") as GDScript).new()
	slot.landmark_id = BAD_LANDMARK
	slot.position = Vector2(-400, -700)
	# 🔴 **앞에** 꽂는다 — 가드가 없으면 뒤의 진짜 둥지가 아예 안 선다(= 값으로 잡힌다).
	var mixed: Array = [slot]
	mixed.append_array(before)
	ch.landmarks.assign(mixed)

	await _fresh(&"ch1")
	print("  (위에 USER ERROR 한 줄이 나오는 게 정상이다 — 침묵 금지 계약. SCRIPT ERROR와 다르다)")
	var nodes := get_nodes_in_group("landmarks")
	_check(nodes.size() == before.size(),
		"🔴 나쁜 슬롯은 건너뛰고 나머지 %d개는 그대로 선다 (실제 %d — 적으면 거기서 루프가 죽은 것이다)"
			% [before.size(), nodes.size()])
	_check(_room.get_node_or_null("Player") != null,
		"🔴🔴 방이 계속 서 있다 (플레이어가 살아 있다 — 죽으면 판이 통째로 안 선 것이다)")
	# 길까지 확인 — 지점이 안 서면 그 길도 안 깔린다([7]의 파생 증명과 짝이다).
	var g := _grid()
	var entrance := _entrance_cell(g)
	for n in nodes:
		_check(_road_connected(entrance, _cell_of(n.position, g)),
			"🔴 살아남은 지점 %s로 가는 흙길도 그대로 깔렸다" % n.position)

	ch.landmarks.assign(before)
	_db.landmarks.erase(BAD_LANDMARK)   # 🔴 주입 제거 — 남기면 뒤 테스트의 지점 수가 는다


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


## 🔴 한 칸에서 한 방향으로 **끊김 없이 이어지는 흙길이 몇 칸인가** (세100 N25ⓐ — 모양의 측정자).
## ⚠ 상한은 격자에서 파생한다 — 무한 루프 방지용이지 계약이 아니다(길이 방 밖 한 칸까지 그려져
##  `_grid()` 범위를 살짝 넘는 게 정상이라, 범위로 자르지 않고 **타일이 있나**로만 걷는다).
func _run_length(start: Vector2i, step: Vector2i, g: Dictionary) -> int:
	var from: Vector2i = g["from"]
	var to: Vector2i = g["to"]
	var limit: int = (to.x - from.x) + (to.y - from.y) + 4
	var n := 0
	var c := start
	while n < limit and _is_road(c):
		n += 1
		c += step
	return n


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


## 🔴 자식 노드의 살아 있는 `z_index` — **리터럴 기대치를 안 든다**(세100 N25ⓒ).
## 없으면 -1을 돌려줘 호출부의 「0이면 자명 통과」 가드에 걸린다(조용히 0으로 비교하지 않게).
func _live_z(parent: Node, path: NodePath) -> int:
	var n := parent.get_node_or_null(path) as CanvasItem
	return n.z_index if n != null else -1


## 🔴🔴 감지 상자의 **가장 아래 변**(프롭 원점 기준 y). 원점이 접지선이라 이 값이 0을 넘으면
## 「둥지 **앞**(남쪽)에 선 플레이어」까지 뒤로 잡혀 앞뒤가 뒤집힌다.
## ⚠ **씬의 형상에서 잰다 — 치수를 리터럴로 안 든다.** 둥지를 크게 다시 그려 상자를 위로 키워도
##  이 계약은 그대로 성립한다(움직이지 않는 건 「원점 = 접지선」 하나뿐이다).
func _sense_bottom(area: Area2D) -> float:
	var bottom := -INF
	for c in area.get_children():
		var cs := c as CollisionShape2D
		if cs == null or cs.shape == null:
			continue
		var half := 0.0
		if cs.shape is RectangleShape2D:
			half = (cs.shape as RectangleShape2D).size.y * 0.5
		elif cs.shape is CircleShape2D:
			half = (cs.shape as CircleShape2D).radius
		else:
			continue
		bottom = maxf(bottom, area.position.y + cs.position.y + half)
	return bottom


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
