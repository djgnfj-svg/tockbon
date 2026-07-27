extends SceneTree
## 낮 보스방 + 나무 투명화 자동 검증 (세99) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_daylight_tree_auto.gd
## 전 항목 통과 시 "TEST_DAYLIGHT_TREE_OK" 출력 후 종료 코드 0.
##
## 🔴🔴 **이 그물은 「예쁜가」를 재지 않는다 — 재는 건 「밤으로 되돌아갔나」다.** 낮/투명화는 겉보기
##  작업이고 판정은 F5·스샷 몫이다. 여기 있는 건 **조용한 회귀**를 막는 값들이다: 앰비언트를 다시
##  누르거나 · 횃불을 되살리거나 · 바닥 곱을 빠뜨리거나 · 나무 Area에 레이어를 채우는 것.
##
## 🔴 여기서 헤드리스가 **실제로 잡는** 것:
##  [1] 앰비언트(CanvasModulate)가 화면을 안 누른다 — 옛 `Dusk`(0.85,0.84,0.93)로 되돌리면 빨강
##  [2] 방 조명이 **볕뉘**지 등불이 아니다 — 횃불(energy 0.9)을 되살리면 빨강
##  [3] 🔴🔴 **바닥이 안 탄다** — 챕터 색이 1.0 언저리의 **옅은 틴트**인가(포화 0 · 액자 0 · D8 유지).
##      옛 `_apply_floor_daylight`의 2~3배 곱을 되살리면 빨강. PNG를 **직접 읽어** 바탕색을 구하므로
##      `boss_room.GRASS_TILE_BASE` 사본이 낡아도(그림을 다시 그려도) 여기서 드러난다
##  [4] 챕터 3장이 **다 밝고 서로 다르다** — 낮으로 옮기며 셋을 같은 색으로 뭉개면 D8이 죽는다
##  [5] 🔴 나무엔 **물리 몸이 없고** 감지 Area는 `collision_layer = 0`이다
##      (레이어를 채우면 캐리어가 나무마다 터진다 — boss_room.gd 머리말의 그 함정)
##  [6] 🔴🔴 나무 뒤로 가면 **비치고**(alpha↓) **앞으로 나온다**(z↑) · 벗어나면 **둘 다 돌아온다**
##
## ⚠ 못 잡는 것: 낮이 **낮처럼 보이나** · 볕뉘가 **얼룩으로 읽히나** · 반투명 나무 너머로 몸이
##  **실제로 보이나** — 전부 F5·스샷 몫이다(헤드리스는 렌더를 안 한다).
##
## ⚠ **[3]은 엔진 WARNING을 한 줄 낸다 — 정상이다**: `Image.load_from_file`이
##  *"Loaded resource as image file, this will not work on export"*라고 짖는다. 그물이 **import된
##  텍스처가 아니라 원본 PNG**를 봐야 사본 감시가 성립해서 일부러 그 경로를 쓴다(게임 코드가 아니라
##  테스트라 export 경고는 해당이 없다). 이 줄을 보고 회귀를 쫓지 마라.
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

## 🔴 「낮」의 하한 — 앰비언트가 화면을 이보다 더 누르면 낮이 아니다. 옛 Dusk는 최소 채널 0.84였다.
const DAY_AMBIENT_MIN := 0.90
## 🔴 방 조명 한 개의 상한 — **볕뉘**(0.22~0.30)는 통과하고 **횃불**(0.9)은 못 넘는다.
## 밝은 바닥 위의 센 additive 광원이 세99에 사용자가 *"어색하다"*고 한 바로 그 얼룩이다.
const ROOM_LIGHT_MAX_ENERGY := 0.35
## 🔴 낮 바닥의 밝기 하한(HSV의 V) — 세98 바닥은 셋 다 0.19 이하였다(거의 검정).
const DAY_FLOOR_V_MIN := 0.26
## 챕터끼리 이만큼은 달라야 한다 — 「챕터마다 다른 무대」(D8)가 색으로도 남는지.
const CHAPTER_COLOR_MIN_GAP := 0.04
## 🔴🔴 바닥 곱의 허용 구간 — **「형광색」의 방어선**이다(세99 타일 교체분).
##  옛 `_apply_floor_daylight`는 거의 검은 타일을 밝히려고 **2~3배**를 곱했다. 이미 낮 밝기로 그려진
##  새 시트에 그 곱을 물리면 흙 `#ad7757` → `#ffff6d`(형광 노랑)가 되는데 **에러가 0이다.**
## ⚠ 값을 박는 게 아니라 **구간**이다 — 사용자가 F5로 조일 여지를 남기되 탈 수는 없게.
const TINT_MIN := 0.70
const TINT_MAX := 1.20
## 챕터 셋의 **틴트**가 이만큼은 갈려야 한다 — 옅게 옮기며 셋을 하나로 뭉개면 D8이 죽는다.
const TINT_MIN_GAP := 0.05
## 바닥 시트 그림 — 바탕색을 **여기서 직접 읽어** boss_room의 상수와 대조한다(사본 감시).
const GROUND_SHEET_PNG := "res://assets/sprites/field/tileset_ground.png"
## 시트에서 바탕색을 뽑을 칸(아틀라스 좌표 · 64px) — 풀 A와 길 중앙 A.
const GROUND_TILE_PX := 64
const GRASS_TILE_CELL := Vector2i(1, 4)
const DIRT_TILE_CELL := Vector2i(5, 0)

var failures: int = 0
var _gs = null
var _db = null
var _scene = null
var _room = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		print("TEST_DAYLIGHT_TREE_TIMEOUT — 60초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_gs = root.get_node("/root/GameState")
	_db = root.get_node("/root/Db")
	_scene = load("res://src/field/boss_room.tscn") as PackedScene

	await _test_ambient_is_day()
	await _test_room_lights_are_sun_patches()
	await _test_floor_becomes_chapter_color()
	_test_chapters_are_bright_and_distinct()
	await _test_tree_has_no_body()
	await _test_tree_is_seen_through_from_behind()

	_free_room()
	if failures == 0:
		print("TEST_DAYLIGHT_TREE_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_DAYLIGHT_TREE_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 앰비언트가 낮이다 — 🔴 **이름으로 안 찾는다**(세99에 `Dusk`→`Daylight`로 개명했다).
## 타입으로 집으면 다음에 또 개명해도 이 그물이 안 낡는다.
func _test_ambient_is_day() -> void:
	print("[1] 🔴 앰비언트(CanvasModulate)가 화면을 안 누른다 = 낮")
	await _fresh(&"ch1")
	var mods := _find_all(_room, "CanvasModulate")
	_check(mods.size() == 1, "방에 CanvasModulate가 하나 있다 (실제 %d — 0이면 시간대 손잡이가 사라진 것)"
		% mods.size())
	if mods.is_empty():
		return
	var c: Color = mods[0].color
	var lo: float = minf(minf(c.r, c.g), c.b)
	_check(lo >= DAY_AMBIENT_MIN,
		"🔴 최소 채널 %.2f ≥ %.2f (옛 Dusk 0.84로 되돌리면 빨강 · 실제 %s)" % [lo, DAY_AMBIENT_MIN, c])


## [2] 방 조명 = 볕뉘. 🔴 **`Lights` 아래만 본다** — 플레이어 아우라(player.tscn · energy 0.55)는
## 방이 건 조명이 아니라 몸에 붙은 것이라 이 계약의 대상이 아니다(그걸 같이 세면 늘 빨강이 된다).
func _test_room_lights_are_sun_patches() -> void:
	print("[2] 🔴 방 조명은 볕뉘다 — 등불(횃불 energy 0.9)이 없다")
	var lights_root = _room.get_node_or_null("Lights")
	if lights_root == null:
		_check(false, "방에 Lights 노드가 없다 — 빛 웅덩이 축이 통째로 사라졌다")
		return
	var lights := _find_all(lights_root, "PointLight2D")
	# 🔴 자명 통과 방지: 0개면 아래 루프가 아무것도 안 재고 조용히 통과한다.
	_check(lights.size() >= 1, "방 조명을 %d개 쟀다 (0이면 이 항목은 자명 통과다)" % lights.size())
	var worst := 0.0
	for l in lights:
		worst = maxf(worst, l.energy)
	_check(worst <= ROOM_LIGHT_MAX_ENERGY,
		"🔴 가장 센 방 조명 energy %.2f ≤ %.2f (횃불 0.9를 되살리면 빨강)"
			% [worst, ROOM_LIGHT_MAX_ENERGY])


## [3] 🔴🔴 **바닥이 안 탄다** — 챕터 색은 1.0 언저리의 **옅은 틴트**여야 한다 (세99 타일 교체분).
##
## 🔴 **채널을 옮긴 항목이다.** 세99 전반엔 여기가 「`modulate × 타일 바탕색 == room_ground_color`」
##  였다 — 거의 검은 `tile_boss_floor.png`를 **2~3배로 밝히는 우회로**(`_apply_floor_daylight`)가
##  실제로 걸렸나를 재는 그물이었다. 그 뒤 바닥이 **이미 낮 밝기로 그려진 시트**로 갈렸고, 같은 곱을
##  물리면 **곱을 두 번 먹어 흙이 `#ffff6d` 형광 노랑이 된다**(`docs/_reports/tile_dirt.md` §0).
##  → 재는 것을 **「곱이 정확한가」에서 「곱이 안 타는가」로** 옮겼다. 옛 곱을 되살리면 여기가 빨개진다.
##
## 🔴 타일 바탕색을 **PNG에서 직접 읽는다** — `boss_room.GRASS_TILE_BASE`는 그림에서 베낀 사본이라
##  그림을 다시 그리면 조용히 낡는다. 두 출처를 대조하는 게 이 항목의 핵심이다
##  (대조는 `Ground.color == 바탕색 × modulate`로 한다 — 코드가 그 상수로 테두리를 칠하기 때문이다).
func _test_floor_becomes_chapter_color() -> void:
	print("[3] 🔴🔴 바닥 틴트가 1.0 언저리다 — 안 탄다 · 액자가 없다 · 챕터마다 다르다")
	var grass = _tile_base(GRASS_TILE_CELL)
	var dirt = _tile_base(DIRT_TILE_CELL)
	if grass == null or dirt == null:
		_check(false, "바닥 시트 PNG(%s)를 못 읽었다 — 그물이 대조를 못 한다" % GROUND_SHEET_PNG)
		return
	var grass_c: Color = grass
	var dirt_c: Color = dirt
	_check(grass_c.v > 0.0 and dirt_c.v > 0.0,
		"시트에서 풀·흙 바탕색을 읽었다 (풀 %s · 흙 %s)" % [grass_c, dirt_c])
	var tints: Array = []
	for id in [&"ch1", &"ch2", &"ch3"]:
		await _fresh(id)
		var tiles = _room.get_node_or_null("TileGround")
		var ground = _room.get_node_or_null("Ground")
		if tiles == null or ground == null:
			_check(false, "%s: TileGround·Ground가 없다" % id)
			continue
		var m: Color = tiles.modulate
		tints.append(m)
		var lo: float = minf(minf(m.r, m.g), m.b)
		var hi: float = maxf(maxf(m.r, m.g), m.b)
		# 🔴🔴 **이 줄이 「형광색」의 방어선이다** — 옛 `_apply_floor_daylight`의 곱은 ch1에서 2.63배였다.
		_check(lo >= TINT_MIN and hi <= TINT_MAX,
			"🔴🔴 %s: 바닥 곱이 옅은 틴트다 %s (%.2f~%.2f — 밝은 시트에 2~3배를 물리면 화면이 탄다)"
				% [id, m, TINT_MIN, TINT_MAX])
		# 🔴 실제로 화면에 나갈 색이 채널 상한을 안 넘나 — **흙(길)이 먼저 탄다**(바탕이 더 밝다).
		for pair: Array in [[grass_c, "풀"], [dirt_c, "흙길"]]:
			var b: Color = pair[0]
			var out := Color(b.r * m.r, b.g * m.g, b.b * m.b, 1.0)
			var top: float = maxf(maxf(out.r, out.g), out.b)
			_check(top <= 1.0,
				"🔴 %s: %s 바탕이 곱해도 포화되지 않는다 (최대 채널 %.3f ≤ 1.0 · 실제 %s)"
					% [id, pair[1], top, out])
			if pair[1] == "풀":
				_check(out.v >= DAY_FLOOR_V_MIN,
					"%s: 곱한 풀 바닥이 여전히 낮이다 (V %.2f ≥ %.2f)" % [id, out.v, DAY_FLOOR_V_MIN])
		# 🔴 액자가 없다 — 타일이 못 덮는 테두리 한 칸이 **같은 색**이어야 한다.
		#  이 대조가 곧 `boss_room.GRASS_TILE_BASE` 사본 감시다(PNG ↔ 코드 상수).
		var rim: Color = ground.color
		var want := Color(grass_c.r * m.r, grass_c.g * m.g, grass_c.b * m.b, 1.0)
		var gap: float = maxf(maxf(absf(rim.r - want.r), absf(rim.g - want.g)), absf(rim.b - want.b))
		_check(gap <= 0.02,
			"🔴 %s: 테두리(Ground)가 바닥과 같은 색이다 = 액자가 없다 (오차 %.3f · 실제 %s / 기대 %s)"
				% [id, gap, rim, want])
	# 🔴 D8 — 틴트가 세 챕터를 **실제로 가른다**(색을 옅게 옮기며 셋을 하나로 뭉개면 여기가 빨강).
	for i in tints.size():
		for j in range(i + 1, tints.size()):
			var a: Color = tints[i]
			var b: Color = tints[j]
			var d: float = absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			_check(d >= TINT_MIN_GAP,
				"챕터 %d↔%d 바닥 틴트가 다르다 (합차 %.3f ≥ %.2f)" % [i + 1, j + 1, d, TINT_MIN_GAP])


## [4] 세 챕터가 다 밝고 서로 다르다 — 「낮」과 「챕터마다 다른 무대」(D8)를 같이 잰다.
## ⚠ 값을 박지 않는다(사용자가 F5로 조인다) — **하한과 간격**만 본다.
func _test_chapters_are_bright_and_distinct() -> void:
	print("[4] 챕터 3장의 바닥이 다 밝고(낮) 서로 다르다(D8)")
	var seen: Array = []
	for id in [&"ch1", &"ch2", &"ch3"]:
		var ch = _db.get_chapter(id)
		if ch == null:
			_check(false, "%s를 Db에서 못 찾았다" % id)
			continue
		var c: Color = ch.room_ground_color
		_check(c.v >= DAY_FLOOR_V_MIN,
			"%s 바닥 밝기 V %.2f ≥ %.2f (세98 값 0.19 이하로 되돌리면 빨강)" % [id, c.v, DAY_FLOOR_V_MIN])
		seen.append(c)
	for i in seen.size():
		for j in range(i + 1, seen.size()):
			var a: Color = seen[i]
			var b: Color = seen[j]
			var gap: float = absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			_check(gap >= CHAPTER_COLOR_MIN_GAP,
				"챕터 %d↔%d 바닥색이 다르다 (합차 %.3f ≥ %.2f)" % [i + 1, j + 1, gap, CHAPTER_COLOR_MIN_GAP])


## [5] 🔴 나무엔 물리 몸이 없다 + 감지 Area가 **아무에게도 안 잡힌다**.
## StaticBody2D(world 레이어)로 만들면 캐리어(마스크 5)가 나무마다 터진다 — boss_room.gd 머리말.
## 세99에 Area2D가 붙었으므로 **그 Area가 그 함정을 다시 열지 않았나**를 값으로 잰다.
func _test_tree_has_no_body() -> void:
	print("[5] 🔴 나무 = 물리 몸 0 · 감지 Area는 collision_layer 0")
	await _fresh(&"ch1")
	var trees := _trees()
	_check(trees.size() >= 1, "방에 나무가 %d그루 있다 (0이면 아래가 자명 통과다)" % trees.size())
	var bodies := 0
	var areas := 0
	var bad_layer := 0
	var monitorable := 0
	for t in trees:
		bodies += _find_all(t, "PhysicsBody2D").size()
		for a in _find_all(t, "Area2D"):
			areas += 1
			if a.collision_layer != 0:
				bad_layer += 1
			if a.monitorable:
				monitorable += 1
	_check(bodies == 0, "🔴 나무에 물리 몸이 0개다 (실제 %d — 캐리어가 나무마다 터진다)" % bodies)
	_check(areas >= 1, "나무마다 감지 Area가 있다 (실제 %d개)" % areas)
	_check(bad_layer == 0, "🔴 감지 Area의 collision_layer가 전부 0이다 (실제 %d개가 채워져 있다)" % bad_layer)
	_check(monitorable == 0, "감지 Area가 전부 monitorable = false다 (실제 %d개가 켜져 있다)" % monitorable)


## [6] 🔴🔴 나무 뒤로 가면 비치고 앞으로 나온다 — **두 축을 같이 잰다**(tree.gd 머리말 ⓐⓑ).
## alpha만 재면 「흐려지는데 여전히 몸 뒤라 화면이 그대로」인 회귀를 못 잡고,
## z만 재면 「몸을 통째로 먹는」 회귀를 못 잡는다.
## 🔴 밑동 **아래**(= 나무 앞)에서는 둘 다 원래대로여야 한다 — 그게 「위/아래가 원근」이라는 계약이다.
func _test_tree_is_seen_through_from_behind() -> void:
	print("[6] 🔴🔴 플레이어가 나무 뒤 → 비친다(alpha↓) + 앞으로 나온다(z↑)")
	await _fresh(&"ch1")
	var trees := _trees()
	if trees.is_empty():
		_check(false, "나무가 없다 — 이 항목을 잴 수 없다")
		return
	var tree = trees[0]
	var player = _room.get_node_or_null("Player")
	if player == null:
		_check(false, "Player를 못 찾았다")
		return
	var away: Vector2 = player.global_position

	# ⓐ 뒤(밑동 위쪽)로 옮긴다
	player.global_position = tree.global_position + Vector2(0, -24)
	await _settle()
	_check(tree.modulate.a < 0.95,
		"🔴 나무가 비친다 — alpha %.2f < 0.95" % tree.modulate.a)
	_check(tree.z_index > 2,
		"🔴 나무가 플레이어 스프라이트(z 2)보다 앞으로 나왔다 — z %d" % tree.z_index)

	# ⓑ 멀리 (원래 스폰 자리) — 둘 다 돌아온다
	player.global_position = away
	await _settle()
	_check(is_equal_approx(tree.modulate.a, 1.0),
		"벗어나면 alpha가 1로 돌아온다 (실제 %.2f)" % tree.modulate.a)
	_check(tree.z_index == 0, "벗어나면 z가 0으로 돌아온다 (실제 %d)" % tree.z_index)

	# ⓒ 🔴 밑동 **아래** = 나무 「앞」 — 겹쳐 보여도 안 비친다(위/아래가 원근이라는 계약).
	player.global_position = tree.global_position + Vector2(0, 40)
	await _settle()
	_check(is_equal_approx(tree.modulate.a, 1.0),
		"🔴 밑동 아래(나무 앞)에서는 안 비친다 (실제 %.2f)" % tree.modulate.a)
	_check(tree.z_index == 0, "🔴 밑동 아래에서는 나무가 뒤에 남는다 (실제 z %d)" % tree.z_index)


## ── 도구 ───────────────────────────────────────────────────────────────────

## 페이드(트윈)가 끝날 때까지 — 물리 프레임 두 번(Area 신호) + 넉넉한 여유.
## ⚠ `tree.gd`의 FADE_SEC를 늘리면 여기도 같이 늘려라(값을 파생시키면 상수가 밀려도 통과한다).
func _settle() -> void:
	await physics_frame
	await physics_frame
	await create_timer(0.35).timeout


func _trees() -> Array:
	var holder = _room.get_node_or_null("Trees")
	if holder == null:
		return []
	return holder.get_children()


## 바닥 타일 PNG의 바탕색(가장 많이 쓰인 색 대신 **한복판 한 점**) — 이 그림은 4096칸 중 3976칸이
## 한 색이라 가운데를 찍으면 바탕이다. 🔴 `Image.load_from_file`은 GPU를 안 타서 헤드리스에서 돈다
## (`Texture2D.get_image()`는 렌더 서버 왕복이라 헤드리스에서 빈 값이 나온다).
## 시트의 한 칸에서 **바탕색**을 뽑는다 — 칸 한복판이 아니라 **최빈색**이다.
## 🔴 한복판을 찍으면 얼룩 하나에 값이 통째로 흔들린다(옛 그림은 97%가 단색이라 안 드러났는데,
##  새 시트는 풀 A도 95%라 여전히 되지만 **길 중앙 칸은 잔풀·자갈이 섞여** 찍는 자리로 갈린다).
func _tile_base(cell: Vector2i):
	var img := Image.load_from_file(GROUND_SHEET_PNG)
	if img == null:
		return null
	var counts: Dictionary = {}
	var best: Color = Color.BLACK
	var best_n := 0
	for y in range(cell.y * GROUND_TILE_PX, (cell.y + 1) * GROUND_TILE_PX):
		for x in range(cell.x * GROUND_TILE_PX, (cell.x + 1) * GROUND_TILE_PX):
			if x >= img.get_width() or y >= img.get_height():
				return null
			var c := img.get_pixel(x, y)
			var n: int = int(counts.get(c, 0)) + 1
			counts[c] = n
			if n > best_n:
				best_n = n
				best = c
	return best


## 타입 이름으로 하위 전부를 모은다 — 노드 **이름**에 안 묶이려고(개명해도 안 낡는다).
func _find_all(n: Node, type_name: String) -> Array:
	var out: Array = []
	if n.is_class(type_name):
		out.append(n)
	for c in n.get_children():
		out.append_array(_find_all(c, type_name))
	return out


## 방 하나를 새로 띄운다 (`test_chapter_auto._fresh` 계약 그대로 — 방을 남기면 플레이어가 둘이 된다).
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


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
