extends SceneTree
## 방 재입장(`_enter_room`) 자동 검증 (세112 단계 3) — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_room_reenter_auto.gd
## 전 항목 통과 시 "TEST_ROOM_REENTER_OK" 출력 후 종료 코드 0.
##
## 🔴🔴 **이 파일이 단계 3의 유일한 증거다.** 단계 3은 화면에 아무것도 안 바꾼다 — `_ready`를
##  「판 1회」와 「방마다」로 가르기만 한다. 그래서 **「두 번 불러도 안 깨지나」**를 여기서 재지 않으면
##  단계 5가 방을 잇는 날 **에러 0으로** 깨진 채 굴러간다.
##
## 🔴 여기서 헤드리스가 **실제로 잡는** 것:
##  [1] 전제 — 방이 서고 프롭·적이 실제로 있다(0이면 아래가 전부 자명 통과다)
##  [2] 🔴🔴 **HP·마나가 방마다 안 회복된다** — 이 파일의 심장. 옮기면 「방을 이어서 깬다」의
##      소모가 통째로 사라지는데 **에러가 0이다**(`takbon-rules` §2 「출격 = 만HP/만마나」)
##  [3] 🔴 `Props` 홀더가 **안 쌓인다** — `add_child`를 방마다 하면 둘이 되고 `get_node_or_null`은
##      **첫 번째만** 돌려줘서 그물이 헌 홀더를 본다(설계 §5-2 주의 2)
##  [4] 프롭·나무·지점·적이 **안 쌓인다** + EventBus 연결이 **안 겹친다**(연결은 판 1회다)
##  [5] 🔴🔴 **방 클리어 판정** — 적을 다 잡으면 열리고, 재입장하면 **닫힌다**(`_cleared`는 방마다)
##      🔴 죽은 몸이 `queue_free` 뒤에도 한 프레임 그룹에 남으므로 **그냥 세면 영영 안 열린다**
##  [6] 🔴 `_leaving`은 **판 수명**이다 — 재입장이 건드리면 귀환·사망 중에 방이 하나 더 선다
##  [7] 헌 흙길이 **타일에 안 남는다** — 지점을 비우고 재입장하면 흙길이 0칸
##  [8] 방 번호가 배치를 **가른다**(`_cell_hash` salt · 설계 §5 「공짜다」)
##
## ⚠ 못 잡는 것: **엔진 `ERROR:`** — 물리 콜백에서 트리를 만졌을 때 나는 그 줄은 스크립트가 못 읽는다.
##  🔴 **실행 출력을 `ERROR:`로 grep해라 — `SCRIPT ERROR:`가 아니다**(`tools/run_tests.gd`는 후자만 본다).
## ⚠ 겉보기(방 2가 방 1과 달라 보이나 · 헌 프롭이 한 프레임 깜빡이나)는 전부 F5·스샷 몫이다.
##
## 🔴 `_enter_room`·`_leaving`을 **이름으로** 부른다 — 보통은 공개 API만 쓰는 게 규율이지만
##  (`takbon-verify` §3), 이 둘은 **설계 §5-2가 이름째 못 박은 계약**이라 이름이 곧 계약이다
##  (`test_chapter_auto`가 `_extract` 연결 수를 세는 것과 같은 판단).
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

## 🔴 재입장으로 쌓이면 안 되는 그룹들 — `boss_room.ROOM_GROUPS`에서 **파생하지 않고 손으로 든다**
##  (거기서 읽으면 그 목록을 비워도 이 그물이 같이 눈을 감는다 — `test_prop_layout_auto`의 관행).
const COUNTED_GROUPS: Array[StringName] = [&"props", &"enemies", &"landmarks"]
## 두 번째 입장의 개수가 첫 번째의 이 배를 넘으면 「쌓였다」로 본다. 🔴 배치가 방마다 갈리므로
##  개수는 조금 달라진다(salt) — 2배는 **명백히 안 헐린 것**만 잡는 문턱이다.
const STACK_TOLERANCE := 1.8

var failures: int = 0
var _gs = null
var _db = null
var _bus = null
var _scene = null
var _room = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		print("TEST_ROOM_REENTER_TIMEOUT — 90초 초과")
		quit(1))
	await process_frame

	_gs = root.get_node("/root/GameState")
	_db = root.get_node("/root/Db")
	_bus = root.get_node("/root/EventBus")
	_scene = load("res://src/field/boss_room.tscn") as PackedScene

	await _test_baseline()
	await _test_hp_mana_not_refilled()
	await _test_holder_and_groups_do_not_stack()
	await _test_room_clear_opens_and_resets()
	await _test_leaving_survives_reenter()
	await _test_no_stale_road()
	await _test_room_index_varies_layout()

	await _cleanup()

	if failures == 0:
		print("TEST_ROOM_REENTER_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_ROOM_REENTER_FAIL — %d건 실패" % failures)
		quit(1)


## [1] 전제 — 0이면 아래가 전부 자명 통과다.
func _test_baseline() -> void:
	print("[1] 전제 — 방이 서고 프롭·적이 실제로 있다")
	await _fresh(&"ch1")
	_check(_room != null, "방이 섰다")
	_check(_count(&"props") > 0, "프롭이 %d개 있다 (0이면 [3][4]가 자명 통과)" % _count(&"props"))
	_check(_count(&"enemies") > 0, "적이 %d마리 있다 (0이면 [5]가 자명 통과)" % _count(&"enemies"))
	_check(_room.has_method("room_cleared"), "`room_cleared()` 공개 문이 있다 ([5]가 이걸 읽는다)")


## [2] 🔴🔴 **이 파일의 심장 — 방마다 만HP/만마나가 되면 안 된다.**
##
## 설계 §5-2가 이걸 첫 줄로 든 이유: `reset_player_hp`·`restore_mana_full`·`in_expedition`을
## `_enter_room` 쪽으로 흘리면 **방을 넘을 때마다 완전 회복**이라 「방을 이어서 깬다」의 소모가
## 통째로 사라지는데 **에러도 경고도 0이다.** 🔴 값을 깎아 두고 재입장해 **안 돌아오는지**를 잰다.
func _test_hp_mana_not_refilled() -> void:
	print("[2] 🔴🔴 HP·마나가 방마다 회복되지 않는다 (설계 §5-2 왼쪽 열)")
	await _fresh(&"ch1")
	_check(is_equal_approx(_gs.hp, _gs.hp_max()),
		"입장(판 1회)엔 만HP다 %.0f/%.0f — 이건 `_ready`가 진다" % [_gs.hp, _gs.hp_max()])
	var hurt: float = _gs.hp_max() * 0.4
	var spent: float = _gs.mana_max() * 0.3
	_gs.hp = hurt
	_gs.mana = spent
	await _reenter(1)
	# 🔴 HP는 **정확 비교**가 맞다 — 스스로 차는 축이 없다.
	_check(is_equal_approx(_gs.hp, hurt),
		"🔴🔴 재입장해도 HP가 %.0f 그대로다 (실제 %.0f — 만HP면 `reset_player_hp`가 `_enter_room`으로 샌 것이다)"
			% [hurt, _gs.hp])
	# 🔴🔴 **마나는 정확 비교를 쓰면 안 된다 — 저절로 찬다**(`balance.mana_regen_per_sec`).
	#  세112 단계 3에 실제로 밟았다: `is_equal_approx(mana, spent)`가 **거짓 빨강**을 냈고
	#  출력엔 `30 ↔ 30`으로 찍혀(`%.0f` 반올림) 원인이 안 보였다 — 실제로는 프레임 두 개만큼
	#  회복돼 있었다. **재는 것은 「그대로인가」가 아니라 「만마나로 안 찼나」**다(그게 계약이다).
	#  ⚠ 이건 `takbon-verify` §4-4의 짝 — **내가 만든 검사도 틀릴 수 있다.**
	_check(_gs.mana < _gs.mana_max() * 0.5,
		"🔴🔴 재입장해도 마나가 안 찼다 %.2f / 만 %.0f (만마나면 `restore_mana_full`이 `_enter_room`으로 샌 것이다)"
			% [_gs.mana, _gs.mana_max()])
	_check(_gs.in_expedition, "`in_expedition`은 여전히 true다 (판 수명)")


## [3][4] 🔴 홀더·그룹·연결이 **안 쌓인다**.
##
## 🔴 세 가지가 각각 다른 이유로 쌓인다:
##  ⓐ `Props` 홀더 — `_spawn_props`가 `add_child`를 한다(설계 §5-2 주의 2)
##  ⓑ 그룹 노드 — `queue_free`만 하면 **프레임 끝까지 그룹에 남아** 새 것과 겹쳐 보인다
##  ⓒ EventBus 연결 — 방마다 다시 이으면 시그널이 방 수만큼 겹친다(연결은 판 1회다)
func _test_holder_and_groups_do_not_stack() -> void:
	print("[3][4] 🔴 `Props` 홀더·그룹·EventBus 연결이 안 쌓인다")
	await _fresh(&"ch1")
	var before := {}
	for g: StringName in COUNTED_GROUPS:
		before[g] = _count(g)
	var links_before := _links_to_room()
	_check(links_before > 0, "방이 EventBus에 %d개 연결돼 있다 (0이면 ⓒ가 자명 통과)" % links_before)
	_check(_named_holders() == 1, "입장 직후 `Props` 홀더가 1개다 (실제 %d)" % _named_holders())
	var kids_before := _direct_children()

	await _reenter(1)
	await _reenter(2)

	# 🔴🔴 **이름이 아니라 개수로 잰다** — 이유는 `_direct_children` 머리말(이름 검사는 원리적으로 못 잡는다).
	_check(_direct_children() == kids_before,
		"🔴🔴 세 번 세워도 방의 직속 자식이 %d개 그대로다 (실제 %d — 늘어난 만큼이 안 헐리고 쌓인 것이다)"
			% [kids_before, _direct_children()])
	_check(_named_holders() == 1,
		"🔴 `Props`라는 이름의 홀더는 여전히 하나다 (실제 %d)" % _named_holders())
	for g: StringName in COUNTED_GROUPS:
		var now: int = _count(g)
		var was: int = int(before[g])
		_check(float(now) <= float(was) * STACK_TOLERANCE,
			"🔴 그룹 `%s`가 안 쌓였다 — 1회차 %d → 3회차 %d (%.1f배 이하)"
				% [String(g), was, now, STACK_TOLERANCE])
	_check(_links_to_room() == links_before,
		"🔴 EventBus 연결이 %d개 그대로다 (실제 %d — 늘면 방마다 다시 이은 것이고 안내·발사가 중복된다)"
			% [links_before, _links_to_room()])

	# 🔴🔴 **씬이 쥔 것은 안 헐린다** — 방을 헐 때 `interact_zones` 그룹을 도는데 **씬의 남쪽 `$Exit`가
	#  거기 든다**(`interact_zone.gd _ready`가 넣는다). `_teardown_room`의 `owner` 가드가 유일한 방어이고,
	#  빠지면 **방 하나 지나고 나가는 길이 사라지는데 에러가 0이다**(`_wire_exit`은 이미 돌아서 `_exits`엔
	#  죽은 참조만 남고 화면은 멀쩡하다).
	var exit_node = _room.get_node_or_null("Exit")
	_check(exit_node != null and is_instance_valid(exit_node)
			and not exit_node.is_queued_for_deletion(),
		"🔴🔴 세 번 세워도 씬의 `$Exit`가 살아 있다 (헐리면 나가는 길이 조용히 사라진다)")
	_check(exit_node != null and exit_node.is_in_group("interact_zones"),
		"…그리고 그 `$Exit`는 실제로 `interact_zones` 그룹에 있다 (= 헐릴 뻔한 자리가 맞다 · 자명 통과 방지)")


## [5] 🔴🔴 방 클리어 — 적을 다 잡으면 열리고 재입장하면 닫힌다.
##
## 🔴 **판정이 `enemy_id == boss_enemy_id`가 아니라 「살아 있는 적이 0」이다**(R9가 보스를 안 세운다).
## 🔴🔴 **죽은 몸이 한 프레임 그룹에 남는 것이 이 항목의 함정이다** — `forest_enemy._die`가
##  `EventBus.enemy_died`를 **`queue_free()` 앞에서** 쏘므로, 필터 없이 세면 마지막 한 마리를 잡아도
##  늘 1이라 **클리어가 영영 안 열린다**(에러 0). 여기서 그 필터가 실제로 도는지 잰다.
func _test_room_clear_opens_and_resets() -> void:
	print("[5] 🔴🔴 방 클리어 — 적이 0이 되면 열리고, 재입장하면 닫힌다")
	await _fresh(&"ch1")
	_check(not _room.room_cleared(), "입장 직후엔 안 깨진 상태다")
	var live := _count(&"enemies")
	_check(live > 0, "잡을 적이 %d마리 있다 (0이면 자명 통과)" % live)
	# 🔴 **실제 경로로 죽인다** — `take_hit`이 `_die`를 태우고 그게 `enemy_died`를 쏜다.
	#  직접 `queue_free`하면 시그널이 안 나가 판정 자체를 안 지난다.
	for node in get_nodes_in_group("enemies"):
		if is_instance_valid(node) and node.has_method("take_hit"):
			node.take_hit(99999.0, 0, 0, 0.0)
	await process_frame
	await process_frame
	_check(_room.room_cleared(),
		"🔴🔴 마지막 적이 죽자 방이 깨졌다 (열리지 않으면 죽은 몸을 그대로 세고 있는 것이다)")

	await _reenter(1)
	_check(not _room.room_cleared(),
		"🔴 재입장하면 다시 안 깨진 상태다 (`_cleared`는 방마다 리셋 — 설계 §5-2 주의 3)")
	_check(_count(&"enemies") > 0, "재입장하면 적이 다시 찬다 (실제 %d)" % _count(&"enemies"))


## [6] 🔴 `_leaving`은 **판 수명**이다 — 재입장이 건드리면 안 된다.
## 설계 §5-2 주의 3: 내리면 귀환·사망 도중에 방이 하나 더 서서 **씬을 두 번 갈아탄다.**
func _test_leaving_survives_reenter() -> void:
	print("[6] 🔴 `_leaving`은 판 수명이다 (재입장이 안 내린다)")
	await _fresh(&"ch1")
	_check(not bool(_room.get("_leaving")), "입장 직후엔 false다 (전제)")
	_room.set("_leaving", true)
	await _reenter(1)
	_check(bool(_room.get("_leaving")),
		"🔴 재입장해도 `_leaving`이 true 그대로다 (내려가면 귀환·사망 중에 방이 하나 더 선다)")
	_room.set("_leaving", false)


## [7] 🔴 헌 흙길이 타일에 안 남는다.
## 흙길은 **지점에서 파생**하므로 지점을 비우면 0칸이어야 한다. `_fill_tiles`가 먼저 `clear()`를
## 안 하면 **테두리 위에 그린 길 칸**이 덮어써지지 않아 헌 토막이 남는다(에러 0 · 화면만 거짓말).
func _test_no_stale_road() -> void:
	print("[7] 🔴 지점을 비우고 재입장하면 헌 흙길이 안 남는다")
	await _fresh(&"ch1")
	var road_before := _road_cells()
	_check(road_before > 0, "지점이 있는 방엔 흙길이 %d칸 있다 (0이면 자명 통과)" % road_before)
	var ch = _db.get_chapter(&"ch1")
	var saved: Array = ch.landmarks.duplicate()
	ch.landmarks.clear()
	await _reenter(1)
	var road_after := _road_cells()
	ch.landmarks.assign(saved)   # 🔴 되돌리기가 먼저다 — 아래 _check이 무엇을 하든 새 나가지 않는다
	_check(road_after == 0,
		"🔴 지점이 없으면 흙길이 0칸이다 (실제 %d칸 — 남으면 `_fill_tiles`가 헌 타일을 안 지운 것이다)"
			% road_after)


## [8] 🔴 방 번호가 배치를 가른다 — 설계 §5의 *"방마다 다른 배치는 공짜다"*.
## ⚠ **방 0은 단계 2와 한 톨도 안 달라야 한다**(회귀 0) — 그건 `test_prop_layout_auto [8]`이 잰다.
##  여기서 재는 건 **0과 1이 다르다**는 반대쪽이다.
func _test_room_index_varies_layout() -> void:
	print("[8] 🔴 방 번호가 배치를 가른다 (`_cell_hash` salt)")
	await _fresh(&"ch1")
	var room0 := _prop_key()
	await _reenter(1)
	var room1 := _prop_key()
	_check(room0.size() > 0 and room1.size() > 0,
		"두 방에 프롭이 있다 (%d ↔ %d — 0이면 자명 통과)" % [room0.size(), room1.size()])
	var same := 0
	for k in room0:
		if room1.has(k):
			same += 1
	_check(same < room0.size(),
		"🔴 방 0과 방 1의 배치가 다르다 (%d/%d 일치 — 전부 같으면 방 번호가 굴림에 안 들어간 것이다)"
			% [same, room0.size()])


# ── 도구 ──────────────────────────────────────────────────────────────────────


## 🔴 `_enter_room`을 **이름으로** 부른다 — 설계 §5-2가 이름째 못 박은 계약이다(머리말 참조).
func _reenter(index: int) -> void:
	_room.call("_enter_room", index)
	await process_frame
	await physics_frame


func _count(group: StringName) -> int:
	var n := 0
	for node in get_nodes_in_group(String(group)):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			n += 1
	return n


## 🔴🔴 **방의 직속 자식 수** — 「쌓였나」를 **이름과 무관하게** 재는 유일한 축이다.
##
## 🔴🔴 **이름으로 세려다 두 번 틀렸다(세112 단계 3 실측 · `takbon-verify` §4-4).**
##  ⓐ `name == "Props"` → 거짓 그린. ⓑ `begins_with("Props")` → **여전히 거짓 그린.**
##  실측한 이유: Godot 4는 형제 이름이 겹치면 요청한 이름을 **통째로 버리고** `@Node2D@94`처럼
##  내부 이름을 붙인다(`add_child`의 `force_readable_name`이 기본 false라서). 즉 홀더가 셋이어도
##  **`Props`라는 이름은 늘 하나뿐**이라 어떤 이름 검사도 원리적으로 못 잡는다.
##  ⇒ **개수로** 잰다: 같은 챕터를 다시 세우면 적·지점 수가 같으므로 **직속 자식 수도 같아야 한다.**
##   늘어난 만큼이 곧 「헐리지 않고 쌓인 것」이다(홀더든 무엇이든 잡는다).
func _direct_children() -> int:
	return _room.get_child_count()


## 🔴 `Props`라는 **읽을 수 있는 이름**이 하나인지 — 위 개수 검사의 짝이다(사람이 씬 트리를 볼 때
##  홀더가 어느 것인지 알아볼 수 있어야 한다). ⚠ **이것만으로는 쌓임을 못 잡는다**(위 머리말).
func _named_holders() -> int:
	var n := 0
	for c in _room.get_children():
		if String(c.name) == "Props":
			n += 1
	return n


## 방이 EventBus 시그널에 몇 개 이어져 있나 — 방마다 다시 이으면 늘어난다.
func _links_to_room() -> int:
	var n := 0
	for sig: String in ["player_hp_changed", "enemy_died", "quest_ready"]:
		for c: Dictionary in _bus.get_signal_connection_list(sig):
			var cb: Callable = c["callable"]
			if cb.get_object() == _room:
				n += 1
	return n


## 프롭 좌표 집합(문자열 키) — 부동소수 비교를 피하려고 0.1px로 반올림한다.
func _prop_key() -> Dictionary:
	var out: Dictionary = {}
	for p in get_nodes_in_group("props"):
		if not is_instance_valid(p) or p.is_queued_for_deletion():
			continue
		out["%s|%.1f,%.1f" % [p.scene_file_path, p.position.x, p.position.y]] = true
	return out


## 🔴 흙길 칸 수 — **아틀라스 좌표로 가른다**(source id로는 못 가른다: 벌판과 길이 같은 시트다).
## 벌판 좌표 셋을 손으로 들고 그 밖이면 길로 본다(`test_prop_layout_auto._is_road`와 같은 판단).
func _road_cells() -> int:
	var tiles: TileMapLayer = _room.get_node("TileGround")
	var grass: Array[Vector2i] = [Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)]
	var n := 0
	for cell: Vector2i in tiles.get_used_cells():
		if tiles.get_cell_source_id(cell) != 2:
			continue
		if not grass.has(tiles.get_cell_atlas_coords(cell)):
			n += 1
	return n


## 방 하나를 새로 띄운다 — 🔴 **`current_scene`을 실게임처럼 세운다**(적 `_die`가 드롭의 부모로 쓴다.
## `test_chapter_auto`가 같은 이유를 적어 뒀다). 방을 남기면 플레이어가 둘이 된다.
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


## 🔴 뒷정리 = 계약이다 — 장비·창고를 안 만졌어도 **오토로드 상태는 되돌린다**
##  (`takbon-verify` §1 「테스트끼리 세이브 파일을 공유한다」).
func _cleanup() -> void:
	_gs.pending_chapter = &""
	_gs.in_expedition = false
	_gs.ui_modal_open = false
	_gs.reset_player_hp()
	_gs.restore_mana_full()
	_free_room()
	await process_frame
	root.get_node("/root/SaveManager").wipe_save()


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
