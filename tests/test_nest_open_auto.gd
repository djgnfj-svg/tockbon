extends SceneTree
## 지점 열기(D10·D11) + 우두머리 자리(D13) 자동 검증 — 세101 N26 3·4단계. 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_nest_open_auto.gd
## 전 항목 통과 시 "TEST_NEST_OPEN_OK" 출력 후 종료 코드 0.
## 정본 = `docs/takbon-design/dungeon_structure_design.md` §10 (D10·D10-b·D11·D12·D13 · S19·S22·S25·S26·S27).
##
## 🔴🔴 **왜 새 파일인가 — 이웃 셋이 전부 「밟기 전」을 잰다.**
##  `test_landmark_road_auto` = 지점이 **서 있나**(자리·길·겹침) · `test_chapter_auto [1d]` = 산출
##  **데이터**가 성립하나 · `test_mob_roll_auto` = 굴림 **기계**가 도나. **밟으면 무슨 일이 나나**는
##  아무도 안 잰다 — 세99에 둥지가 *"밟을 방법도, 주는 것도 없는 예쁜 이정표"*로 서 있던 자리다.
##
## 🔴🔴 **`interacted`를 직접 emit하지 않는다** — 기존 정산 그물(`test_chapter_auto [4b]·[5]`)이
##  그렇게 재서 **홀드가 아예 안 돌아도 그린**이었다(설계 §6 **S11**). 여기선 전부
##  **`Input.action_press` + 이벤트 주입 + 프레임 진행 + `action_release`**로 잰다
##  (선례 = `test_spell_cast_auto` · `test_extract_hold_auto`).
##
## 🔴 여기서 헤드리스가 **실제로 잡는** 것:
##  [1] ⓐ **[E] 한 번에 즉시 열린다**(D10 — 홀드가 아니다: `hold_sec == 0` · 누른 프레임에 끝난다)
##      ⓓ **비워진 겉모습으로 바뀐다**(S20 — 텍스처가 실제로 다른 컷이 된다)
##      🔴 **프롬프트가 같이 꺼진다**(S25 끝줄 — 안 끄면 *"눌렀는데 아무 일도 안 난다"*)
##      ⓒ **낱개가 둥지 자리에 쏟아진다**(D12) + 🔴 **굴림을 실제로 지난다**(chance 0 줄은 안 나온다)
##  [2] 🔴🔴 ⓑ **두 번째 [E]는 아무것도 안 준다**(**S25** — 재열기 가드의 직접 검출자).
##      가드가 없으면 **무한 파밍이 최적 전략**이 되어 GDD §6 *"살아서 나간다"*가 통째로 죽는다.
##      🔴 즉시 열기라 **연타로 재현되고 에러가 0**이다(홀드가 완충 노릇을 하지 않는다)
##  [3] 🔴 **S19 — 연 상태가 판을 넘지 않는다.** 방은 매 판 새로 서므로 노드가 들면 저절로 다시 찬다.
##      `GameState`·세이브에 넣는 순간 **영영 빈 둥지**가 되는데 화면은 정상이다
##  [4] ⓔ **우두머리가 지점 좌표에 선다**(D13) + 🔴 **잠금이 아니다**(D10-b — 살아 있어도 열린다)
##  [5] 🔴🔴 ⓕ **같은 `landmark_id` 슬롯이 둘이면 각각에 뜨고 각각 따로 열린다**(**S27**).
##      「첫 번째」로 정하면 **둘째 둥지엔 영영 우두머리가 안 뜨고 에러가 0**이다
##  [6] 🔴 **미등록 `at_landmark`는 조용히 안 넘어간다**(S22 — 안 서고 **에러로 승격**)
##
## ⚠ **못 잡는 것**: 프롬프트가 **읽히나** · 낱개가 **겹쳐 보이나**(S23 — 흩뿌림 반경이 상수라
##  개수가 늘면 등급 후광이 겹친다) · 「열렸다」가 **손맛으로 읽히나**. 전부 스샷·F5 몫이다.
##
## 🔴 **주입한 것은 반드시 되돌린다** — `Db.get_chapter`·`Db.get_landmark`는 **공유 리소스**를
##  돌려주므로 안 되돌리면 뒤 항목·뒤 테스트(같은 프로세스)가 오염된다(`test_mob_roll_auto._restore_all` 선례).
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

## 🔴 여는 지점의 `zone_id` — **손으로 든 기대치다**(씬에서 읽으면 값을 바꿔도 같이 눈을 감는다).
##  ⚠ `&"exit"`이면 `test_chapter_auto`가 출구로 세어 「_extract에 이어진 수」와 어긋난다(S5의 결).
const LANDMARK_ZONE := &"landmark"
const NEST_ID := &"lm_nest"
## 🔴 실재하는 재료여야 한다 — 없는 id면 픽업이 마름모 폴백으로 떨어진다(세54 도형 금지).
const DROP_ITEM := &"mat_hound_fang"
## 🔴 **절대 안 나와야 하는 줄** — chance 0.0. 이게 나오면 굴림을 안 지나고 통째로 뿌린 것이다.
const NEVER_ITEM := &"mat_beetle_shell"

## 둥지 앞(남쪽)에 서는 거리 — 🔴 **접지선 기준**이라 그림을 다시 그려도 안 낡는다.
## ⚠ 여기가 `OpenZone` 밖이면 **전 항목이 「범위 밖」으로 죽는다** — 그래서 [1]이 `player_in_range()`를
##  **전제로 먼저** 찍는다(자명 통과를 PASS로 안 찍는다).
const FRONT_STAND := 20.0

var failures: int = 0
var _gs = null
var _db = null
var _bus = null
var _scene = null
var _room = null
## 주입 전 원본 — 항목마다 저장하고 끝에 되돌린다.
var _saved_ch: Dictionary = {}
var _saved_drops = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		print("TEST_NEST_OPEN_TIMEOUT — 90초 초과")
		quit(1))
	await process_frame

	_gs = root.get_node("/root/GameState")
	_db = root.get_node("/root/Db")
	_bus = root.get_node("/root/EventBus")
	_scene = load("res://src/field/boss_room.tscn") as PackedScene

	await _test_open_is_instant()
	await _test_second_press_gives_nothing()
	await _test_open_state_does_not_survive_the_run()
	await _test_named_stands_at_landmark()
	await _test_named_at_every_slot_with_same_id()
	await _test_unknown_at_landmark_is_loud()

	await _cleanup()

	if failures == 0:
		print("TEST_NEST_OPEN_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_NEST_OPEN_FAIL — %d건 실패" % failures)
		quit(1)


## [1] 🔴🔴 **[E] 한 번에 즉시 열린다 — 그리고 열린 표시가 화면에 남는다.**
##
## 네 가지를 **한 판에서** 잰다(따로 재면 「열렸는데 겉모습만 그대로」 같은 반쪽 고장이 통과한다):
##  ⓐ 즉시(홀드 아님) · ⓓ 비워진 컷 · 프롬프트 꺼짐 · ⓒ 낱개가 둥지 자리에.
## 🔴 **굴림을 실제로 지나나**도 같이 잰다 — `chance = 0.0` 줄을 하나 섞어 **그게 안 나오는지** 본다.
##  안 그러면 「`drops`를 그대로 전부 뿌린다」는 구현이 그린이 되고, `DropEntry`의 확률 축이 죽는다.
func _test_open_is_instant() -> void:
	print("[1] [E] 한 번 = 즉시 열림 · 비워진 컷 · 프롬프트 꺼짐 · 낱개가 둥지 자리에")
	_inject_quiet_chapter()
	_inject_drops(2, 2)
	await _fresh(&"ch1")

	var nest = _one_nest()
	if nest == null:
		_check(false, "둥지가 섰다 (전제 — 안 서면 아래가 전부 자명 통과다)")
		return
	var zone = _open_zone_of(nest)
	_check(zone != null, "🔴 둥지에 여는 지점(zone_id=%s)이 있다" % LANDMARK_ZONE)
	if zone == null:
		return
	# 🔴 D10 — 「몇 초」가 아니라 **0이냐 아니냐**다. 0이 아니면 그 숫자가 아니라 탈출 시간으로 돈다.
	_check(is_equal_approx(zone.hold_sec, 0.0),
		"🔴 여는 지점은 홀드가 꺼져 있다 (실제 %.2f — 0이 아니면 `balance.extract_hold_sec`로 돈다)"
			% zone.hold_sec)

	await _stand_in_front(nest)
	_check(zone.player_in_range(),
		"🔴 둥지 앞 %.0fpx에서 범위 안이다 (전제 — 밖이면 아래가 전부 「안 열렸다」로 죽는다)" % FRONT_STAND)
	_check(not nest.is_broken(), "열기 전엔 온전하다 (전제)")
	_check(nest.open_prompt_visible(), "🔴 다가가면 [E] 안내가 뜬다 (전제)")
	var intact_tex = nest.texture
	_check(intact_tex != null, "온전함 컷이 실제로 물려 있다 (전제 — null이면 ⓓ가 자명 통과다)")

	# ── ⓐ 누른다 — **한 프레임 안에** 끝나야 한다(홀드면 여기서 아무 일도 안 난다)
	# 🔴 `push_input`은 **동기**라 이 줄이 돌아온 시점엔 `_unhandled_input`이 이미 끝나 있다.
	_press_interact()
	# 🔴🔴 **`await` 전에 먼저 본다 — 여기가 「문구를 직접 내리는 것」의 유일한 측정 창이다**(세101 실측).
	#  프레임을 한 번이라도 흘리면 `monitoring = false`의 deferred가 적용되며 `body_exited`가 와서
	#  `InteractZone`이 **스스로** 문구를 내린다 → 직접 내리는 줄을 지워도 검출이 **0**이 된다.
	#  🔴 그리고 이건 그물 사정이 아니라 **화면 사정**이다: 누른 그 프레임에 안 내리면 「비워진 둥지 +
	#  [E] 안내」가 한 프레임 같이 보인다(깜빡임).
	_check(not nest.open_prompt_visible(),
		"🔴🔴 **누른 그 프레임에** [E] 안내가 내려간다 (다음 프레임으로 밀리면 소진된 둥지에 안내가 한 프레임 남는다)")
	await process_frame
	_release_interact()
	_check(nest.is_broken(),
		"🔴🔴 ⓐ [E] **한 번**에 그 프레임에서 열린다 (안 열렸으면 홀드가 끼었거나 배선이 끊긴 것이다)")
	_check(not zone.is_holding(), "즉시 지점은 홀드 상태로 들어가지 않는다")

	# ── ⓓ 비워진 겉모습 (S20) — 「한 번만」이 **화면에 보이는** 규칙이어야 한다
	_check(nest.texture != null and nest.texture != intact_tex,
		"🔴🔴 ⓓ 열면 **다른 컷**으로 갈아 끼운다 (같으면 열었는지 아닌지 화면에서 구분이 안 간다 — S20)")

	# ── 프롬프트 (S25 끝줄) — 안 끄면 *"눌렀는데 아무 일도 안 난다"*
	_check(not nest.open_prompt_visible(),
		"🔴🔴 소진 뒤 [E] 안내가 꺼진다 (남으면 「눌러도 아무 일도 안 나는 문구」가 화면에 산다)")

	# ── ⓒ 낱개가 둥지 자리에 (D12) + 굴림을 지난다
	var drops := _pickups()
	_check(drops.size() == 1,
		"🔴 ⓒ 낱개가 **굴림대로** 나왔다 — 확정 줄 하나 (실제 %d개)" % drops.size())
	var got := {}
	for d in drops:
		got[d.item_id] = int(d.count)
	_check(got.has(DROP_ITEM), "🔴 확정 줄(chance 1.0)의 %s가 나왔다 (실제 %s)" % [DROP_ITEM, str(got.keys())])
	_check(int(got.get(DROP_ITEM, 0)) == 2,
		"수량이 min/max대로 2다 (실제 %d — 수량 굴림이 죽으면 여기가 갈린다)" % int(got.get(DROP_ITEM, 0)))
	_check(not got.has(NEVER_ITEM),
		"🔴🔴 chance 0.0 줄(%s)은 **안 나온다** = 굴림을 실제로 지난다 (나오면 drops를 통째로 뿌린 것이다)"
			% NEVER_ITEM)
	for d in drops:
		_check(d.global_position.distance_to(nest.global_position) < 96.0,
			"🔴 낱개가 **둥지 자리**에 쏟아진다 (실제 %.0fpx — 멀면 원점이나 플레이어 자리에 뿌린 것이다)"
				% d.global_position.distance_to(nest.global_position))
	_restore_all()


## [2] 🔴🔴 **한 판에 한 번뿐이다** (D11 · 설계 §10-4 **S25**) — 이 파일의 심장.
##
## 🔴 **왜 이게 가장 위험한가**: 그림만 바꾸고 게이트를 안 걸면 **계속 나온다.** 다 치운 뒤 안전한
##  자리에서 **무한 파밍이 최적 전략**이 되어 GDD §6 *"살아서 나간다"*가 통째로 죽는다.
##  🔴 즉시 열기(D10)로 바뀌며 **연타로 재현 가능**해졌고, **에러는 0**이다.
## 🔴🔴 **연타를 「프레임 경계 없이」 해야 한다 — 세101에 뮤테이션으로 실측했다.**
##  처음엔 *한 번 누르고 → `await process_frame` → 또 누르기*로 짰는데 **가드를 지워도 검출 0**이었다:
##  그 프레임 사이에 `monitoring = false`의 `set_deferred`가 적용되고 `body_exited`가 와서
##  `InteractZone._player_in_range`가 내려가 **두 번째 [E]가 애초에 안 들어온다.** 즉 그 형태는
##  **소진 처리가 가드를 가려** 「재열기 가드」를 하나도 안 재고 있었다.
## → 🔴 **한 판은 한 번, 다른 판은 `await` 없이 세 번**을 눌러 **같은 프레임 안**에서 비교한다.
##  그 프레임엔 아직 deferred가 안 돌아 `_player_in_range`가 참이라 **가드만이 유일한 방어선**이다.
## ⚠ 프레임을 나눈 연타·왕복은 **소진 처리(monitoring)**를 재는 다른 축이라 아래에 그대로 남긴다.
func _test_second_press_gives_nothing() -> void:
	print("[2] 🔴🔴 두 번째 [E]는 아무것도 안 준다 (재열기 가드 — S25)")
	_inject_quiet_chapter()
	_inject_drops(2, 2)   # 🔴 min == max = **한 판의 산출이 결정적**이다(아래 대조가 확률이면 안 된다)

	# ── ⓐ 기준: 한 번만 누른 판
	await _fresh(&"ch1")
	var nest = _one_nest()
	if nest == null:
		_check(false, "둥지가 섰다 (전제)")
		_restore_all()
		return
	await _stand_in_front(nest)
	_press_interact()
	await process_frame
	_release_interact()
	var single := _pickups().size()
	_check(single == 1, "한 번 누르면 낱개가 %d개 (기준 — 확정 줄 하나라 결정적이다)" % single)

	# ── ⓑ 🔴🔴 **같은 프레임에 세 번** — `await`가 하나도 없는 게 이 항목의 전부다.
	await _fresh(&"ch1")
	nest = _one_nest()
	if nest == null:
		_check(false, "둘째 판에도 둥지가 섰다 (전제)")
		_restore_all()
		return
	await _stand_in_front(nest)
	_press_interact()
	_press_interact()
	_press_interact()
	await process_frame
	_release_interact()
	var burst := _pickups().size()
	_check(burst == single,
		"🔴🔴 **같은 프레임에 세 번** 눌러도 산출이 한 번치다 (기준 %d → 실제 %d — 늘면 재열기 가드가 없는 것이고 무한 파밍이 최적 전략이 된다)"
			% [single, burst])

	# ── ⓒ 프레임을 나눈 연타 — 여기서부터는 **소진 처리(monitoring)**를 재는 축이다.
	var first := burst
	for i in 2:
		_press_interact()
		await process_frame
		_release_interact()
		await process_frame
	_check(_pickups().size() == first,
		"🔴 프레임을 나눠 두 번 더 눌러도 낱개가 안 는다 (%d → %d)" % [first, _pickups().size()])
	_check(nest.is_broken(), "비워진 상태가 유지된다")
	_check(not nest.open_prompt_visible(),
		"🔴 연타 뒤에도 안내가 꺼진 채다 (다시 켜지면 「눌러도 아무 일 없는 문구」가 돌아온다)")

	# 🔴🔴 **걸어 나갔다 다시 들어온다** — 여기가 「문구를 내리는 것」과 「구역을 닫는 것」을 가른다.
	#  문구만 내리면 `InteractZone`이 **재진입에서 스스로 다시 켠다**(그게 그 스크립트의 계약이다).
	#  → *"[E]가 떴는데 눌러도 아무 일도 안 난다"*가 되고 **에러가 0**이다. 프롬프트만 재면
	#  이 고장이 통째로 통과하므로(한 번 걸었다 풀리는 형태) **왕복을 실제로 걸어 본다.**
	var player: Node2D = _room.get_node("Player")
	player.global_position = nest.global_position + Vector2(0, 900.0)
	for i in 6:
		await physics_frame
	await _stand_in_front(nest)
	_check(not nest.open_prompt_visible(),
		"🔴🔴 나갔다 다시 들어와도 안내가 **안 켜진다** (켜지면 소진된 지점이 다시 부르는 것이다)")
	_press_interact()
	await process_frame
	_release_interact()
	_check(_pickups().size() == first,
		"🔴🔴 재진입 뒤 [E]도 아무것도 안 준다 (%d → %d)" % [first, _pickups().size()])
	_restore_all()


## [3] 🔴 **연 상태는 판을 넘지 않는다** (설계 §10-4 **S19**).
##
## 방은 매 판 **새로 서므로** 상태를 노드가 들면 다음 판에 저절로 다시 찬다. `GameState`나 세이브에
## 넣는 순간 **영영 빈 둥지**가 되는데 **화면은 정상**이라 아무도 못 알아챈다.
## 🔴 **재입장을 실제로 시뮬레이션한다** — 방을 다시 띄워 온전한지 본다(플래그를 읽지 않는다:
##  「어디에 저장하나」가 아니라 **「다음 판에 다시 차나」**가 계약이다).
func _test_open_state_does_not_survive_the_run() -> void:
	print("[3] 🔴 연 상태가 다음 판으로 안 샌다 (S19 — 방은 매 판 새로 선다)")
	_inject_quiet_chapter()
	_inject_drops(1, 1)
	await _fresh(&"ch1")
	var nest = _one_nest()
	if nest == null:
		_check(false, "둥지가 섰다 (전제)")
		_restore_all()
		return
	await _stand_in_front(nest)
	_press_interact()
	await process_frame
	_release_interact()
	_check(nest.is_broken(), "한 판에서 열었다 (전제)")

	# 🔴 다시 들어간다 — `_fresh`가 방을 통째로 새로 세운다(= 재입장).
	await _fresh(&"ch1")
	var again = _one_nest()
	_check(again != null, "다음 판에도 둥지가 선다")
	if again == null:
		_restore_all()
		return
	_check(not again.is_broken(),
		"🔴🔴 다음 판의 둥지는 **다시 차 있다** (비워진 채면 연 상태가 오토로드·세이브로 샌 것이다 — 영영 빈 둥지)")
	_check(again.open_prompt_visible() == false,
		"들어가기 전엔 안내가 꺼져 있다 (범위 밖 — 전제)")
	var zone = _open_zone_of(again)
	_check(zone != null and zone.monitoring,
		"🔴 다음 판의 여는 지점이 다시 살아 있다 (monitoring이 꺼진 채면 두 번째 판부터 못 연다)")
	_check(_pickups().is_empty(), "새 판엔 앞 판의 낱개가 안 남아 있다 (실제 %d개)" % _pickups().size())
	_restore_all()


## [4] ⓔ 🔴 **우두머리가 지점 좌표에 선다**(D13) — 그리고 **잠금이 아니다**(D10-b).
##
## 🔴 **둘을 같이 재는 게 핵심이다.** 「선다」만 재면 구현자가 *"먼저 잡아야 열린다"*를 얹어도 그린이고,
##  그건 사용자가 **각하한** 설계다(확률로 안 뜬 판에 지점이 무엇이 되나를 또 정해야 한다).
## 🔴 자유 위치(`NamedSpawn.position`)와 지점 좌표를 **일부러 다르게** 준다 — 같으면 해석이 통째로
##  죽어도(옛 자유 위치 경로로 새도) 그린이라 검출력이 0이 된다.
func _test_named_stands_at_landmark() -> void:
	print("[4] ⓔ 우두머리가 지점 자리에 선다 + 🔴 잠금이 아니다 (살아 있어도 열린다)")
	_inject_quiet_chapter()
	_inject_drops(1, 1)
	var ch = _db.get_chapter(&"ch1")
	var lm_at := _slot_position(ch, NEST_ID)
	var free_at := Vector2(-900.0, 500.0)
	_check(lm_at != Vector2.ZERO and lm_at != free_at,
		"ch1의 %s가 %s에 있고 자유 위치 %s와 다르다 (같으면 아래가 자명 통과다)" % [NEST_ID, lm_at, free_at])
	ch.named_pool = _typed_named([_named(&"hound_alpha", 1.0, free_at, NEST_ID)])
	await _fresh(&"ch1")

	var named := _mobs()
	_check(named.size() == 1, "🔴 확정 우두머리가 하나 선다 (실제 %d — 0이면 해석이 안 켜진 것이다)" % named.size())
	if named.size() == 1:
		_check(_at_spot(named[0], lm_at),
			"🔴🔴 ⓔ 우두머리가 **지점 좌표** %s에 선다 (실제 %s — 자유 위치면 해석이 안 걸렸고 원점이면 자리를 못 찾았다)"
				% [lm_at, named[0].position])

	# 🔴 D10-b — **잡든 말든 열린다.** 우두머리를 살려 둔 채로 연다.
	var nest = _one_nest()
	if nest != null:
		await _stand_in_front(nest)
		_press_interact()
		await process_frame
		_release_interact()
		_check(nest.is_broken(),
			"🔴🔴 우두머리가 **살아 있는데도** 열린다 (D10-b — 「잡아야 열린다」는 각하됐다)")
		_check(_mobs().size() == 1, "여는 것이 우두머리를 없애지도 않는다 (실제 %d)" % _mobs().size())
	_restore_all()


## [5] 🔴🔴 ⓕ **같은 `landmark_id` 슬롯이 둘이면 각각에 뜬다** (설계 §10-4 **S27**).
##
## 🔴 `LandmarkSlot`이 id + 좌표라 **둥지 2채가 문법상 가능**한데, 구현자가 「첫 번째」로 정하면
##  **둘째 둥지엔 영영 우두머리가 안 뜨고 에러가 0**이다.
## 🔴 **열기도 같이 잰다** — 둘째 둥지를 열어도 산출이 나와야 한다(노드↔id 짝이 첫 번째로 굳으면
##  둘째가 「열리긴 하는데 아무것도 안 나오는」 물건이 된다. 그것도 에러가 0이다).
func _test_named_at_every_slot_with_same_id() -> void:
	print("[5] 🔴🔴 ⓕ 같은 id 슬롯이 둘이면 **각각**에 뜬다 · 둘째도 산출을 준다 (S27)")
	_inject_quiet_chapter()
	_inject_drops(1, 1)
	var ch = _db.get_chapter(&"ch1")
	var first_at := _slot_position(ch, NEST_ID)
	var second_at := Vector2(-first_at.x, first_at.y)
	ch.landmarks = _typed_slots([_slot(NEST_ID, first_at), _slot(NEST_ID, second_at)])
	ch.named_pool = _typed_named([_named(&"hound_alpha", 1.0, Vector2(0, 300), NEST_ID)])
	await _fresh(&"ch1")

	var nests := get_nodes_in_group("landmarks")
	_check(nests.size() == 2, "둥지가 두 채 섰다 (실제 %d — 전제)" % nests.size())
	# ⚠ 좌표를 사전 키로 쓰면 배회 한 틱에 어긋난다(`_at_spot` 머리말) — 자리마다 훑는다.
	var stood := {first_at: false, second_at: false}
	for m in _mobs():
		for want: Vector2 in [first_at, second_at]:
			if _at_spot(m, want):
				stood[want] = true
	_check(bool(stood[first_at]) and bool(stood[second_at]),
		"🔴🔴 ⓕ 우두머리가 **두 자리 전부**에 섰다 (첫째 %s=%s · 둘째 %s=%s — 하나면 「첫 번째」로 굳은 것이다)"
			% [first_at, stood[first_at], second_at, stood[second_at]])

	# 🔴 둘째 둥지를 연다 — 노드↔id 짝이 첫 번째로 굳으면 여기서 아무것도 안 나온다.
	var second = null
	for n in nests:
		if n.position == second_at:
			second = n
	_check(second != null, "둘째 둥지 노드를 찾았다 (전제)")
	if second != null:
		await _stand_in_front(second)
		_press_interact()
		await process_frame
		_release_interact()
		_check(second.is_broken(), "🔴 둘째 둥지도 열린다")
		_check(_pickups().size() > 0,
			"🔴🔴 둘째 둥지도 **산출을 준다** (실제 %d개 — 0이면 노드↔id 짝이 첫 채로 굳은 것이다)"
				% _pickups().size())
		# 🔴 첫째는 **아직 안 열렸다** — 하나를 열었다고 둘 다 소진되면 D11이 지점이 아니라 판에 걸린 것이다.
		for n in nests:
			if n.position == first_at:
				_check(not n.is_broken(),
					"🔴 둘째를 열어도 첫째는 그대로다 (소진이 **지점마다**여야 한다)")
	_restore_all()


## [6] 🔴 **미등록 `at_landmark`는 조용히 안 넘어간다** (설계 §10-4 **S22**).
##
## 🔴 왜 조용한가: 해석기가 세울 자리를 못 찾으면 **원점에 서거나 통째로 안 서는데** 둘 다 화면에서
##  *"오늘은 우두머리가 안 떴네"*로 읽힌다. 데이터 쪽 짝은 `test_chapter_auto [1c]`(「비었거나 이 챕터의
##  지점이다」)이고, **코드 쪽은 에러로 승격**하는 것이 설계가 못 박은 계약이다.
## ⚠ 여기서 `push_error` 한 줄(USER ERROR)이 나오는 게 **정상**이다 — `SCRIPT ERROR`와 다르다.
func _test_unknown_at_landmark_is_loud() -> void:
	print("[6] 🔴 미등록 at_landmark — 원점에 조용히 서지 않는다 (S22)")
	_inject_quiet_chapter()
	var ch = _db.get_chapter(&"ch1")
	ch.named_pool = _typed_named([_named(&"hound_alpha", 1.0, Vector2(-700, 400), &"lm_nowhere")])
	await _fresh(&"ch1")
	print("  (위에 USER ERROR 한 줄이 나오는 게 정상이다 — 침묵 금지 계약)")
	var mobs := _mobs()
	_check(mobs.is_empty(),
		"🔴🔴 세울 자리가 없으면 **아무 데도 안 선다** (실제 %d마리 — 원점이나 자유 위치에 서면 조용한 고장이다)"
			% mobs.size())
	_restore_all()


# ── 주입·복원 ─────────────────────────────────────────────────────────────────


## 🔴 **몹을 비운 ch1** — 둘레 늑대 다섯이 붙으면 피격 → 히트스톱(`Engine.time_scale` 0.05)이 걸려
##  뒤 대기가 20배 느려지고, 죽으면 방이 통째로 씬 전환한다(= 그물이 flake가 된다).
##  ⚠ **지점·좌표는 그대로 둔다** — 재는 축이 「지점을 밟으면 무슨 일이 나나」라서다.
func _inject_quiet_chapter() -> void:
	var ch = _db.get_chapter(&"ch1")
	if not _saved_ch.has(ch.id):
		_saved_ch[ch.id] = {
			"spawns": ch.mob_spawns.duplicate(),
			"pool": ch.mob_pool.duplicate(),
			"named": ch.named_pool.duplicate(),
			"landmarks": ch.landmarks.duplicate(),
		}
	ch.mob_spawns = _typed_spawns([])
	ch.mob_pool = _typed_pool([])
	ch.named_pool = _typed_named([])


## 🔴 지점 산출을 **in-memory로** 심는다 — `lm_nest.tres`의 `drops`는 **비어 있고**(5단계 = 사용자 몫)
##  그건 `test_chapter_auto [1d]`가 재는 자리다. 여기서 채우면 그 그물의 뜻이 사라진다.
## 🔴 **세 층 중 바닥(chance 1.0)과 「안 나오는 줄」(chance 0.0)을 같이 심는다** — 굴림을 실제로
##  지나는지가 그 대비로만 잡힌다.
func _inject_drops(lo: int, hi: int) -> void:
	var lm = _db.get_landmark(NEST_ID)
	if lm == null:
		_check(false, "🔴 %s가 Db.landmarks에 실재한다 (전제)" % NEST_ID)
		return
	if _saved_drops == null:
		_saved_drops = lm.drops.duplicate()
	lm.drops = _typed_drops([
		_drop(DROP_ITEM, 1.0, lo, hi),
		_drop(NEVER_ITEM, 0.0, 1, 1),
	])


## 🔴 주입을 전부 되돌린다 — `Db`가 **공유 리소스**를 돌려주므로 안 되돌리면 뒤 테스트가 오염된다.
func _restore_all() -> void:
	for cid in _saved_ch:
		var ch = _db.get_chapter(cid)
		if ch == null:
			continue
		ch.mob_spawns = _saved_ch[cid]["spawns"]
		ch.mob_pool = _saved_ch[cid]["pool"]
		ch.named_pool = _saved_ch[cid]["named"]
		ch.landmarks = _saved_ch[cid]["landmarks"]
	_saved_ch.clear()
	if _saved_drops != null:
		var lm = _db.get_landmark(NEST_ID)
		if lm != null:
			lm.drops = _saved_drops
		_saved_drops = null


## 🔴 뒷정리 = 계약이다 — 방을 남기면 뒤 테스트에서 플레이어가 둘이 된다(`test_chapter_auto` 선례).
##  ⚠ 액션도 푼다: 눌린 채로 두면 다음 테스트의 홀드 그물이 조용히 어긋난다.
func _cleanup() -> void:
	_release_interact()
	_restore_all()
	_gs.pending_chapter = &""
	_gs.ui_modal_open = false
	_free_room()
	await process_frame
	root.get_node("/root/SaveManager").wipe_save()


# ── 도구 ──────────────────────────────────────────────────────────────────────


## 🔴 **`interacted`를 직접 emit하지 않는다**(설계 §6 S11) — `Input.action_press` + 이벤트 주입.
##  선례 = `test_extract_hold_auto._press_interact` · `test_spell_cast_auto`.
func _press_interact() -> void:
	Input.action_press(&"interact")
	var ev := InputEventAction.new()
	ev.action = &"interact"
	ev.pressed = true
	root.push_input(ev)


func _release_interact() -> void:
	Input.action_release(&"interact")


## 둥지 **앞(남쪽)**에 선다 — 🔴 접지선(프롭 원점)에서 `FRONT_STAND`px 아래.
## ⚠ 물리 프레임을 여러 번 흘려야 `body_entered`가 실제로 온다(한 프레임이면 감지가 안 끝난다).
func _stand_in_front(nest) -> void:
	var player: Node2D = _room.get_node("Player")
	player.global_position = nest.global_position + Vector2(0, FRONT_STAND)
	for i in 6:
		await physics_frame
	await process_frame


func _one_nest():
	for n in get_nodes_in_group("landmarks"):
		return n
	return null


## 🔴 여는 지점을 **`zone_id`로** 찾는다 — 노드 이름으로 찾으면 이름을 바꾸는 순간 눈을 감는다.
##  ⚠ 지점이 여럿일 수 있으므로 **부모로 좁힌다**.
func _open_zone_of(nest):
	for z in get_nodes_in_group("interact_zones"):
		if z.zone_id == LANDMARK_ZONE and z.get_parent() == nest:
			return z
	return null


func _pickups() -> Array:
	var out := []
	for n in get_nodes_in_group("drop_pickups"):
		if not n.is_queued_for_deletion():
			out.append(n)
	return out


func _enemies() -> Array:
	var out := []
	for n in get_nodes_in_group("enemies"):
		if not n.is_queued_for_deletion():
			out.append(n)
	return out


## 🔴 보스를 뺀 것 = 잡몹 + 우두머리. 보스는 `_spawn_boss`가 세우므로 해석 검사에서 빼야 한다.
func _mobs() -> Array:
	var ch = _db.get_chapter(_gs.pending_chapter)
	var boss_id: StringName = ch.boss_enemy_id if ch != null else &""
	var out := []
	for n in _enemies():
		if n.enemy_id != boss_id:
			out.append(n)
	return out


func _slot_position(ch, id: StringName) -> Vector2:
	for slot in ch.landmarks:
		if slot != null and slot.landmark_id == id:
			return slot.position
	return Vector2.ZERO


func _slot(id: StringName, at: Vector2):
	var s = (load("res://src/core/schemas/landmark_slot.gd") as GDScript).new()
	s.landmark_id = id
	s.position = at
	return s


func _named(id: StringName, chance: float, at: Vector2, at_landmark: StringName):
	var ns = NamedSpawn.new()
	ns.enemy_id = id
	ns.chance = chance
	ns.position = at
	ns.at_landmark = at_landmark
	return ns


func _drop(id: StringName, chance: float, lo: int, hi: int):
	var d = DropEntry.new()
	d.item_id = id
	d.chance = chance
	d.min_count = lo
	d.max_count = hi
	return d


## 🔴 `@export var x: Array[T]`에 대입하려면 **같은 타입**이어야 한다 — 느슨한 Array를 넣으면
##  런타임에 거부되고(에러 한 줄) 값이 **조용히 안 바뀐다**(`test_mob_roll_auto` 선례).
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


func _typed_slots(items: Array) -> Array[LandmarkSlot]:
	var out: Array[LandmarkSlot] = []
	for it in items:
		out.append(it)
	return out


func _typed_drops(items: Array) -> Array[DropEntry]:
	var out: Array[DropEntry] = []
	for it in items:
		out.append(it)
	return out


## 방 하나를 새로 띄운다 (`test_landmark_road_auto._fresh` 계약 그대로 — 방을 남기면 플레이어가 둘이 된다).
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


## 🔴🔴 **세105 인지 — 적이 배회한다**(설계 ⓑ). 그래서 「데이터가 말한 자리에 섰나」를 **좌표
##  완전 일치**로는 더 이상 못 잰다: 스폰 다음 물리 틱부터 `patrol_speed`만큼 흘러간다
##  (세105 실측 **0.47px** — 이 그물이 그날 빨개진 이유가 그것이다).
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
