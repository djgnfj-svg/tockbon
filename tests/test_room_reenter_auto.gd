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
##  [7] **지점 길**이 지점에서 파생한다 — 지점을 비우면 입구 발밑이 더는 흙길이 아니다(문 길은 남는다)
##  [8] 방 번호가 배치를 **가른다**(`_cell_hash` salt · 설계 §5 「공짜다」)
##  [9] 🔴 **보상 상자**가 방 한복판에 서고 **[E]가 실제로 뜬다** · 재입장하면 사라진다 (단계 4 · R5)
## [10] 🔴🔴 **R11** — 열면 가방이 늘고 **낱개 픽업은 안 는다**(둘을 같이 재야 이중 지급을 잡는다)
## [11] 🔴🔴 두루마리 해금이 **정확히 한 번**(값이 아니라 **횟수**를 센다)
## [12] 🔴🔴 방을 넘어도 **테두리 흙길이 안 쌓인다** — `_fill_tiles`의 `clear()`를 재는 유일한 자리 (단계 5)
## [13] 🔴🔴 **문이 판을 나른다** — [E]로 다음 방이 서고 **HP·마나가 안 찬다** · `_leaving` 무변 (단계 5)
## [14] 🔴🔴 **고른 문이 다음 방 상자 종류를 정한다** — `chest_id`가 거짓 손잡이가 아니라는 증명
##
## ⚠ 못 잡는 것: **엔진 `ERROR:`** — 스크립트가 못 읽는다. 러너(`tools/run_tests.gd`)가 자식 출력에서
##  세어 요약에 찍는다(세112 단계 4 뒤 신설 · **기준선 3건이고 셋 다 일부러 태우는 것**이다).
## ⚠ 지연/직접 스폰은 **못 가른다** — 물리 콜백에서 붙여도 노드는 붙고 Area도 감지한다(단계 4 실측).
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
	await _test_reward_chest_stands_and_works()
	await _test_reward_is_granted_straight_to_bag()
	await _test_unlock_fires_exactly_once()
	await _test_border_road_does_not_accumulate()
	await _test_doors_carry_the_run()
	await _test_door_choice_actually_routes()

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


## [7] 🔴 **지점 길은 지점에서 파생한다** — 지점을 비우면 그 길이 사라진다.
##
## 🔴🔴 **세112 단계 5에 이 항목의 전제가 낡아 실제로 빨개졌다 — 그게 옳은 실패였다.**
##  그전엔 흙길의 출처가 **지점 하나**여서 「비우면 0칸」이 맞았는데, 단계 5가 **문에 자기 길**을 줬다
##  ⇒ 지점을 비워도 **문 길이 남는다**(실측 18칸). 「0칸」으로 두면 그때부터 **거짓 빨강**이다.
## ⇒ 재는 것을 **「전부 사라졌나」에서 「지점 길이 사라졌나」로** 옮긴다: 입구(플레이어 스폰) 발밑이
##  더는 흙길이 아니다. 🔴 **문 길은 북쪽이라 입구 칸을 안 지난다** — 그래서 이 축이 둘을 가른다.
func _test_no_stale_road() -> void:
	print("[7] 🔴 지점을 비우면 **입구→지점 길**이 사라진다 (문 길은 남는다)")
	await _fresh(&"ch1")
	var road_before := _road_cells()
	_check(road_before > 0, "지점이 있는 방엔 흙길이 %d칸 있다 (0이면 자명 통과)" % road_before)
	_check(_entrance_is_road(), "입구 발밑이 흙길이다 (지점 길의 시작점 — 전제)")
	var ch = _db.get_chapter(&"ch1")
	var saved: Array = ch.landmarks.duplicate()
	ch.landmarks.clear()
	await _reenter(1)
	var road_after := _road_cells()
	var entrance_road := _entrance_is_road()
	ch.landmarks.assign(saved)   # 🔴 되돌리기가 먼저다 — 아래 _check이 무엇을 하든 새 나가지 않는다
	_check(not entrance_road,
		"🔴 지점이 없으면 입구 발밑이 흙길이 아니다 (남으면 `_fill_tiles`가 헌 타일을 안 지운 것이다)")
	_check(road_after < road_before,
		"🔴 흙길이 줄었다 %d → %d (문 길은 남으므로 0이 아니다)" % [road_before, road_after])


## [12] 🔴🔴 **`_fill_tiles`의 `clear()`가 드디어 재어진다** (세112 단계 5).
##
## 🔴 **단계 3엔 이 방어선을 재는 것이 0이었다**(뮤테이션으로 지워도 전부 그린 — 그때 보고서에
##  *"문 길이 방 밖으로 뻗으면 살아난다"*고 적어 뒀다). 단계 5가 문에 길을 주면서 그날이 왔다:
##  문 x가 **방마다 흔들리므로** 테두리 위에 그려지는 길 칸이 방마다 갈리고, `clear()`가 없으면
##  **헌 토막이 테두리에 눌어붙는다**(에러 0 · 화면만 거짓말).
##
## 🔴 **개수로 잰다** — 방마다 문이 `DOOR_COUNT`개로 같으니 테두리 길 칸 수도 같아야 한다.
##  쌓이면(합집합) 늘어난다. 🔴 **자명 통과 방지**로 「두 방의 테두리 길 자리가 실제로 다르다」를 먼저 잰다
##  — 안 다르면 쌓여도 개수가 같아서 이 검사가 아무것도 안 잰다.
func _test_border_road_does_not_accumulate() -> void:
	print("[12] 🔴🔴 방을 넘어도 테두리 흙길이 안 쌓인다 (`_fill_tiles`의 clear())")
	await _fresh(&"ch1")
	var b0 := _border_road_set()
	_check(b0.size() > 0,
		"방 0의 테두리에 문 길이 %d칸 그려졌다 (0이면 이 항목이 자명 통과다)" % b0.size())
	await _reenter(1)
	var b1 := _border_road_set()
	var same := 0
	for k in b0:
		if b1.has(k):
			same += 1
	_check(same < b0.size(),
		"🔴 방 0과 방 1의 테두리 길 자리가 다르다 (%d/%d 겹침 — 같으면 쌓여도 개수가 안 늘어 자명 통과다)"
			% [same, b0.size()])
	_check(b1.size() == b0.size(),
		"🔴🔴 테두리 길 칸이 %d개 그대로다 (실제 %d — 늘면 헌 방의 길이 안 지워지고 눌어붙은 것이다)"
			% [b0.size(), b1.size()])


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


## [9] 🔴🔴 **방을 깨면 보상 상자가 방 가운데에 서고, 그 상자가 실제로 작동한다** (세112 단계 4 · R5).
##
## 🔴 **「섰다」로 끝내면 안 된다** — 상자는 `Area2D`를 품은 씬이고, 붙이는 **문맥**에 따라 엔진이
##  *"Can't change this state while flushing queries"*를 찍는다. 그래서 **[E] 안내가 실제로 뜨는지**까지
##  잰다 = 「상자가 서 있는데 아무 일도 안 나는」 상태를 잡는 유일한 관측점이다.
##  ⚠ **단계 4 실측**: 물리 콜백에서 붙여도 노드는 붙고 Area도 감지한다(엔진 ERROR 한 줄만 난다)
##   — 즉 이 항목이 **지연/직접을 가르지는 못한다.** 한계는 `docs/_reports/room_step4.md`에 적었다.
## 🔴 자리는 **`Ground` rect의 한복판**과 대조한다(좌표를 안 박는다 — 방을 옮겨도 안 낡는다).
func _test_reward_chest_stands_and_works() -> void:
	print("[9] 🔴🔴 방을 깨면 보상 상자가 방 가운데에 서고 [E]가 실제로 뜬다")
	await _fresh(&"ch1")
	_check(_count(&"room_rewards") == 0, "깨기 전엔 보상 상자가 0개다 (실제 %d)" % _count(&"room_rewards"))
	await _clear_room()
	var chest = _reward_chest()
	_check(chest != null, "🔴 방을 깨자 보상 상자가 섰다 (없으면 R5가 통째로 죽은 것이다)")
	if chest == null:
		return
	var ground: ColorRect = _room.get_node("Ground")
	var center := ground.position + ground.size * 0.5
	_check(chest.position.is_equal_approx(center),
		"🔴 상자가 방 한복판 %s에 섰다 (실제 %s — 좌표를 박으면 방을 옮길 때 여기만 남는다)"
			% [center, chest.position])

	await _stand_in_front(chest)
	_check(chest.open_prompt_visible(),
		"🔴🔴 다가가니 [E] 안내가 실제로 뜬다 (안 뜨면 상자는 섰는데 열 방법이 없다)")

	await _reenter(1)
	_check(_count(&"room_rewards") == 0,
		"🔴 재입장하면 상자가 사라진다 (실제 %d개 — 남으면 방마다 쌓인다)" % _count(&"room_rewards"))


## [10] 🔴🔴 **R11 — 열면 낱개를 안 뿌리고 바로 가방에 들어온다** (설계 §4 R11).
##
## 🔴 **두 축을 같이 잰다**: ⓐ 가방이 실제로 늘었나 ⓑ **낱개 픽업이 0개인가.**
##  ⓑ가 없으면 「바로 가방 + 낱개도 뿌림」이라는 **이중 지급**을 못 잡는다(에러 0 · 두루마리는 이중 해금).
## 🔴 **실제 입력으로 연다**(`interacted`를 직접 emit하지 않는다 — `test_chest_open_auto`의 규율).
func _test_reward_is_granted_straight_to_bag() -> void:
	print("[10] 🔴🔴 R11 — 상자를 열면 낱개 없이 바로 가방에 들어온다")
	await _fresh(&"ch1")
	await _clear_room()
	var chest = _reward_chest()
	if chest == null:
		_check(false, "보상 상자가 없다 — [10]을 잴 수 없다")
		return
	_gs.bag.clear()
	var loose_before := _count(&"drop_pickups")
	await _stand_in_front(chest)
	await _press_open()
	_check(chest.is_broken(), "상자가 열렸다(부서짐 컷) — 전제")
	_check(_gs.bag.size() > 0,
		"🔴🔴 열자 가방에 %d줄이 들어왔다 (0이면 지급 경로가 통째로 죽은 것이다)" % _gs.bag.size())
	_check(_count(&"drop_pickups") == loose_before,
		"🔴🔴 낱개 픽업이 안 늘었다 (%d → %d — 늘면 「바로 가방」과 낱개가 **둘 다** 돌아 이중 지급이다)"
			% [loose_before, _count(&"drop_pickups")])
	_gs.bag.clear()


## [11] 🔴🔴 **해금 호출이 정확히 한 번** (설계 §6이 착수 전 실측을 시킨 그 자리).
##
## 🔴 **실측 결과**: 두루마리의 `unlock_id` 해금행을 지금까지 **`drop_pickup._grant_unlock`이
##  혼자** 지고 있었는데, R11은 그 노드를 **아예 안 지난다** ⇒ 그대로 두면 상자에서 나온 두루마리만
##  **조용히 해금이 안 걸린다.** 그래서 지급을 `drop_pickup.grant_one` static 하나로 올렸다.
## 🔴 **횟수를 센다 — 「해금됐나」가 아니다.** 값만 보면 두 벌 경로가 **둘 다 돌아도** 통과한다
##  (`takbon-verify` §4-4 「결과 값이 같다 ≠ 같은 길로 왔다」). 이중 해금은 해금음·UNLOCK 퀘스트가
##  두 번 반응하는 것으로만 드러나고 **에러가 0이다.**
## ⚠ `lm_nest`엔 해금행이 없어서(실측) **임시 `DropEntry`를 주입했다 되돌린다** — 그게 이 리포의 관행이다.
func _test_unlock_fires_exactly_once() -> void:
	print("[11] 🔴🔴 상자에서 나온 두루마리의 해금이 **정확히 한 번** 걸린다")
	var def = _db.get_landmark(&"lm_nest")
	if def == null:
		_check(false, "lm_nest를 Db에서 못 찾았다 (전제)")
		return
	var entry_script = load("res://src/core/schemas/drop_entry.gd")
	var probe = entry_script.new()
	probe.unlock_id = &"__probe_unlock_step4"
	probe.chance = 1.0
	probe.min_count = 1
	probe.max_count = 1
	var saved: Array = def.drops.duplicate()
	def.drops.append(probe)
	_gs.codex.erase(&"__probe_unlock_step4")

	var seen := {"n": 0}
	var on_unlock := func(id: StringName) -> void:
		if id == &"__probe_unlock_step4":
			seen["n"] = int(seen["n"]) + 1
	_bus.codex_unlocked.connect(on_unlock)

	await _fresh(&"ch1")
	await _clear_room()
	var chest = _reward_chest()
	if chest != null:
		await _stand_in_front(chest)
		await _press_open()

	_bus.codex_unlocked.disconnect(on_unlock)
	def.drops.assign(saved)              # 🔴 되돌리기가 먼저다 — 아래 _check이 무엇을 하든 새 나가지 않는다
	_gs.codex.erase(&"__probe_unlock_step4")

	_check(chest != null, "보상 상자가 섰다 (전제)")
	_check(int(seen["n"]) == 1,
		"🔴🔴 `codex_unlocked`가 **정확히 1번** 나갔다 (실제 %d — 0이면 R11이 해금 경로를 건너뛴 것이고, 2 이상이면 지급이 두 벌이다)"
			% int(seen["n"]))


## [13] 🔴🔴 **문이 판을 실제로 나른다** (세112 단계 5 · R4·R6) — 이 파일에서 제일 무거운 항목이다.
##
## 🔴 **네 축을 한 흐름으로 잰다** — 나누면 「문은 서는데 눌러도 안 간다」가 사이로 샌다:
##  ⓐ 방을 깨면 문이 `DOOR_COUNT`개 선다 · 미리보기 글자가 **데이터에서** 찬다
##  ⓑ [E]를 실제로 밀면 **다음 방이 선다**(적이 다시 차고 상자·문은 사라진다)
##  ⓒ 🔴🔴 **HP·마나가 안 회복된다** — 「방을 이어서 깬다」의 소모가 여기서 지켜지는지.
##     ⚠ 단계 3의 `[2]`는 `_enter_room`을 **직접** 불러 쟀다. 여기선 **문을 눌러** 같은 것을 다시 잰다
##     — 전환이 실제로 도는 경로에서 안 지켜지면 `[2]`가 그린이어도 게임은 깨진 것이다.
##  ⓓ `_leaving`은 **판 수명**이라 방을 넘어도 안 내려간다
## 🔴 **`interacted`를 직접 emit하지 않는다** — 실제 입력을 민다(`test_chest_open_auto`의 규율).
func _test_doors_carry_the_run() -> void:
	print("[13] 🔴🔴 문이 판을 나른다 — 눌러서 다음 방으로 · HP/마나는 안 찬다")
	await _fresh(&"ch1")
	await _clear_room()
	var doors := _doors()
	_check(doors.size() == 3,
		"🔴 방을 깨자 문이 3개 섰다 (실제 %d — `DOOR_COUNT`와 같아야 한다)" % doors.size())
	if doors.is_empty():
		return
	var label := (doors[0] as Node).get_node_or_null(^"Reward") as Label
	_check(label != null and label.text != "",
		"🔴🔴 문에 보상 미리보기 글자가 **찼다** (비면 문 고르기가 통째로 무의미해진다 — D4의 심장)")
	_check(label != null and label.visible,
		"🔴 그 글자는 **늘 보인다** (다가가야 보이면 고르는 근거가 안 된다)")

	# ⓒ 소모를 만들어 둔다 — 문을 지나도 안 돌아와야 한다.
	var hurt: float = _gs.hp_max() * 0.35
	_gs.hp = hurt
	_gs.mana = _gs.mana_max() * 0.25
	_room.set("_leaving", false)

	var before_enemies := _count(&"enemies")
	_check(before_enemies == 0, "문 앞에선 적이 0이다 (방을 깼으니 — 전제 · 실제 %d)" % before_enemies)
	await _walk_into(doors[0])
	await _press_open()
	for i in 4:
		await process_frame
	await physics_frame

	_check(_count(&"enemies") > 0,
		"🔴🔴 문으로 들어가자 **다음 방이 섰다** — 적이 %d마리 다시 찼다" % _count(&"enemies"))
	_check(_count(&"room_rewards") == 0 and _doors().size() == 0,
		"🔴 헌 방의 상자·문이 사라졌다 (상자 %d · 문 %d — 남으면 방마다 쌓인다)"
			% [_count(&"room_rewards"), _doors().size()])
	_check(is_equal_approx(_gs.hp, hurt),
		"🔴🔴 문을 지나도 HP가 %.0f 그대로다 (실제 %.0f — 차면 방마다 완전 회복이라 소모가 사라진다)"
			% [hurt, _gs.hp])
	_check(_gs.mana < _gs.mana_max() * 0.5,
		"🔴🔴 문을 지나도 마나가 안 찼다 %.2f / 만 %.0f (마나는 저절로 조금 차므로 정확 비교를 안 쓴다)"
			% [_gs.mana, _gs.mana_max()])
	_check(not bool(_room.get("_leaving")), "`_leaving`은 여전히 false다 (방 전환이 판 수명을 안 건드린다)")
	_gs.reset_player_hp()
	_gs.restore_mana_full()


## [14] 🔴🔴 **고른 문이 실제로 다음 방의 보상을 정한다** (세112 단계 5 — `tag` 인자의 존재 이유).
##
## 🔴🔴 **이 항목이 없으면 `chest_id`가 거짓 손잡이다.** 단계 3에 내가 `tag`를 **안 받은** 이유가
##  「소비자가 0곳」이었고, 단계 5는 문이 소비자가 됐다는 전제로 받았다 — 그 전제를 여기서 증명한다.
## 🔴 **지금 데이터로는 못 잰다**: 쓸 수 있는 상자 종류가 **`lm_nest` 하나뿐**이라(실측) 문 셋이 같은
##  보상을 가리키고, `chest_id`를 통째로 무시해도 결과가 같다. ⇒ **두 번째 종류를 주입했다 되돌린다**
##  (`test_landmark_road_auto`·`[11]`과 같은 관행).
## 🔴 **관측점 = 다음 방 상자를 열었을 때 가방에 들어온 물건**이다. 「내부 필드가 바뀌었나」를 보면
##  라우팅은 됐는데 상자가 그걸 안 읽는 경우를 놓친다(§4-4 「같은 길로 왔나」).
func _test_door_choice_actually_routes() -> void:
	print("[14] 🔴🔴 고른 문이 다음 방의 상자 종류를 실제로 정한다")
	var probe_id := &"__probe_chest_b"
	var probe_item := &"__probe_item_b"
	var def_script = load("res://src/core/schemas/landmark_def.gd")
	var entry_script = load("res://src/core/schemas/drop_entry.gd")
	var probe_def = def_script.new()
	probe_def.id = probe_id
	probe_def.title = "시험 상자"
	probe_def.scene_path = "res://src/props/chest.tscn"
	var e = entry_script.new()
	e.item_id = probe_item
	e.chance = 1.0
	e.min_count = 1
	e.max_count = 1
	# 🔴 `drops`는 `Array[DropEntry]`라 **일반 Array를 대입하면 런타임에 죽는다** — 붙여 넣는다.
	#  ⚠ 세112 단계 5 실측: 그 대입 하나로 이 함수가 중간에 끊겼는데 **`TEST_..._OK`가 그대로 찍혔다**
	#   (`failures`가 0인 채로 함수만 죽는다 = `takbon-verify` §3의 침묵 통과). 그래서 아래 `_check`들이
	#   **함수 끝에 모여 있는 것**이 이 항목의 방어 형태다 — 중간에 죽으면 하나도 안 찍혀 눈에 띈다.
	probe_def.drops.append(e)
	_db.landmarks[probe_id] = probe_def

	var titles := {}
	var routed := false
	await _fresh(&"ch1")
	await _clear_room()
	var doors := _doors()
	for d in doors:
		var l := (d as Node).get_node_or_null(^"Reward") as Label
		if l != null:
			titles[l.text] = true
	# 🔴 주입한 종류를 가리키는 문으로 들어간다 — 미리보기 글자로 고른다(사람이 고르는 것과 같은 근거).
	var target = null
	for d in doors:
		var l := (d as Node).get_node_or_null(^"Reward") as Label
		if l != null and l.text == "시험 상자":
			target = d
			break
	# 🔴🔴 **판정을 여기서 굳힌다 — 아래에서 그 문이 헐린다.** Godot 4는 free된 Object 참조를
	#  `== null`로 **참**으로 본다 ⇒ 방을 넘긴 뒤에 `target != null`을 읽으면 **찾았는데도 거짓 빨강**이다
	#  (세112 단계 5에 실제로 그렇게 났다 — 「찾았다」는 FAIL인데 「그 문으로 들어갔더니 나왔다」는 PASS).
	var found: bool = target != null
	if target != null:
		_gs.bag.clear()
		_room.set("_leaving", false)
		await _walk_into(target)
		await _press_open()
		for i in 4:
			await process_frame
		await _clear_room()
		var chest = _reward_chest()
		if chest != null:
			await _stand_in_front(chest)
			await _press_open()
			for row: Dictionary in _gs.bag:
				if StringName(row.get("id", &"")) == probe_item:
					routed = true

	var bag_snapshot: int = _gs.bag.size()
	_gs.bag.clear()
	_db.landmarks.erase(probe_id)   # 🔴 되돌리기가 먼저다 — 아래 _check이 무엇을 하든 새 나가지 않는다

	_check(titles.size() >= 2,
		"🔴 문들이 **서로 다른 보상**을 가리킨다 (서로 다른 글자 %d종 — 1이면 종류가 하나뿐이라 이 항목을 못 잰다)"
			% titles.size())
	_check(found, "주입한 종류를 가리키는 문을 찾았다 (미리보기 글자로 골랐다)")
	_check(routed,
		"🔴🔴 그 문으로 들어간 방의 상자에서 **주입한 물건**이 나왔다 (가방 %d줄 — 안 나오면 `chest_id`가 안 실린 것이고 문 고르기가 무의미해진다)"
			% bag_snapshot)


# ── 도구 ──────────────────────────────────────────────────────────────────────


## 지금 선 문들 — 🔴 **`zone_id`로 찾는다**(노드 이름으로 찾으면 개명하는 순간 눈을 감는다).
func _doors() -> Array:
	var out: Array = []
	for z in get_nodes_in_group("interact_zones"):
		if is_instance_valid(z) and not z.is_queued_for_deletion() and z.get("zone_id") == &"door":
			out.append(z)
	return out


## 문 **안**으로 들어간다 — 트리거 상자 한복판. ⚠ `body_entered`가 실제로 오려면 물리 프레임이 여러 번 필요하다.
func _walk_into(zone) -> void:
	var player: Node2D = _room.get_node("Player")
	player.global_position = (zone as Node2D).global_position
	for i in 6:
		await physics_frame
	await process_frame


## 방의 적을 **실제 경로로** 전부 죽이고 클리어가 돌 때까지 프레임을 흘린다.
## ⚠ 클리어 판정이 `call_deferred`라 프레임을 넉넉히 흘려야 상자가 선다.
func _clear_room() -> void:
	for node in get_nodes_in_group("enemies"):
		if is_instance_valid(node) and node.has_method("take_hit"):
			node.take_hit(99999.0, 0, 0, 0.0)
	for i in 4:
		await process_frame
	await physics_frame


func _reward_chest():
	for n in get_nodes_in_group("room_rewards"):
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			return n
	return null


## 상자 **앞(남쪽)**에 선다 — `test_chest_open_auto._stand_in_front` 계약 그대로
## (접지선 아래 · `body_entered`가 실제로 오려면 물리 프레임을 여러 번 흘려야 한다).
func _stand_in_front(chest) -> void:
	var player: Node2D = _room.get_node("Player")
	player.global_position = chest.global_position + Vector2(0, 30.0)
	for i in 6:
		await physics_frame
	await process_frame


## 🔴 **`interacted`를 직접 emit하지 않는다**(설계 §6 S11) — 실제 입력을 민다.
##  선례 = `test_chest_open_auto._press_interact`.
func _press_open() -> void:
	Input.action_press(&"interact")
	var ev := InputEventAction.new()
	ev.action = &"interact"
	ev.pressed = true
	root.push_input(ev)
	await process_frame
	Input.action_release(&"interact")
	await process_frame


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
	var n := 0
	for cell: Vector2i in _tiles().get_used_cells():
		if _is_road(cell):
			n += 1
	return n


func _tiles() -> TileMapLayer:
	return _room.get_node("TileGround") as TileMapLayer


func _is_road(cell: Vector2i) -> bool:
	var grass: Array[Vector2i] = [Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)]
	if _tiles().get_cell_source_id(cell) != 2:
		return false
	return not grass.has(_tiles().get_cell_atlas_coords(cell))


## 입구(플레이어 스폰) 발밑이 흙길인가 — 🔴 **지점 길의 시작점**이다(문 길은 북쪽이라 여길 안 지난다).
func _entrance_is_road() -> bool:
	var player: Node2D = _room.get_node("Player")
	var ts: Vector2i = _tiles().tile_set.tile_size
	return _is_road(Vector2i(floori(player.position.x / float(ts.x)),
		floori(player.position.y / float(ts.y))))


## 🔴🔴 **테두리 한 칸 링의 흙길 자리** — `_fill_tiles`의 **둘째 루프**가 그리는 자리다.
##  첫 루프는 안쪽 rect를 **전부** 덮어쓰므로 헌 타일이 못 남는다. 남을 수 있는 곳은 여기뿐이다.
## ⚠ 범위를 `boss_room._fill_tiles`와 **같은 방식으로** 파생한다(좌표를 베끼면 방을 바꿀 때만 낡는다).
func _border_road_set() -> Dictionary:
	var ground: ColorRect = _room.get_node("Ground")
	var ts: Vector2i = _tiles().tile_set.tile_size
	var inner := Rect2(ground.position, ground.size).grow(-float(ts.x))
	var i_from := Vector2i(floori(inner.position.x / ts.x), floori(inner.position.y / ts.y))
	var i_to := Vector2i(ceili(inner.end.x / ts.x), ceili(inner.end.y / ts.y))
	var out: Dictionary = {}
	for cell: Vector2i in _tiles().get_used_cells():
		if cell.x >= i_from.x and cell.x < i_to.x and cell.y >= i_from.y and cell.y < i_to.y:
			continue   # 안쪽 — 첫 루프가 매번 덮어쓴다
		if _is_road(cell):
			out["%d,%d" % [cell.x, cell.y]] = true
	return out


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
