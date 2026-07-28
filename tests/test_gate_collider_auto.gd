extends SceneTree
## 🔴🔴 문 기둥 콜라이더 = 「보이는 돌은 막고, 보이는 통로는 지나간다」 (세104 N6) — 헤드리스:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_gate_collider_auto.gd
## 전 항목 통과 시 "TEST_GATE_COLLIDER_OK" 출력 후 종료 코드 0.
##
## 왜 생겼나: 세89에 문 기둥 콜라이더를 **손으로** 맞췄다(∓62 → ∓40 · 폭 24 → 34). 맞긴 맞았는데
## **그림과 판정을 같이 재는 그물이 한 개도 없어서**, 문을 다시 그리면 또 어긋난 채 커밋된다.
## 어긋나는 형태는 둘 다 에러가 0이다: 콜라이더가 그림 밖이면 **허공에 막히고**, 그림 안쪽으로
## 파고들면 **통로가 좁아진다**(= 문이 안 열리는 것처럼 느껴진다).
##
## 🔴🔴 **이건 헤드리스가 온전히 잡을 수 있는 몇 안 되는 부류다** — 실패 형태가 「손맛」도 「렌더」도
## 아니라 **정적인 좌표**라서다. 그래서 값어치가 있다(세84 교훈: 실패 형태로 측정 축을 고른다).
##
## 🔴🔴 **기대치를 리터럴로 들지 않는다 — PNG에서 파생시킨다.**
##  선례 = `test_enemy_hitbox_auto`(스프라이트를 디스크에서 읽어 몸통 폭을 실측). N6의 발단이
##  정확히 *"문을 다시 그리면 또 어긋난다"*이므로, **그림이 바뀌면 기대치가 따라 움직이는** 형태가
##  이 항목의 정답이다. 리터럴 기대치는 세100 N25가 남긴 교훈대로 **우연히 큰 값이면 영영 안 빨개진다.**
##
##  기둥을 그림에서 뽑는 법: 이 스프라이트는 **돌기둥이 완전 불투명 · 포탈 수면이 반투명**이다.
##  그래서 열마다 「a >= 0.99인 픽셀의 최장 연속 세로 run」을 재면 기둥과 나머지가 갈린다
##  (실측: 기둥 119~131 · 아치 곡선 79 이하 · 포탈 26 이하). ⚠ **비율이 애매해지면 [1]이 빨개진다** —
##  분류가 흔들리는 그림으로 바뀌면 사람이 보게 만드는 게 맞지, 조용히 통과시키면 안 된다.
##
## 🔴 **양방향으로 잰다**(한쪽만 재면 조용히 통과하는 게 있다 — `test_enemy_hitbox_auto`·
##  `test_enemy_ai_auto [4]` leash와 같은 이유):
##   ⓐ「기둥으로 걸어가면 막힌다」만 재면 **문 전체가 벽**이어도 통과한다.
##   ⓑ「통로로는 지나간다」만 재면 **콜라이더가 통째로 없어도** 통과한다.
##  그래서 [4]가 둘 다 잰다. 게다가 [5]가 **통로 안쪽 모서리를 ±3px로 못 박는다**(콜라이더가
##  그림보다 안쪽으로 파고들면 옆으로 밀린다 = 좁아진 것).
##
## 🔴 **진짜 플레이어로 걷는다** — 형상 질의(`intersect_point`)로 재면 레이어·마스크 계약이 빠져
##  「형상은 맞는데 안 막힌다」를 놓친다(`test_enemy_hitbox_auto`가 진짜 탄을 쏘는 것과 같은 결).
##  이동도 `Input.action_press(&"move_up")`으로 **실경로**를 지난다(`test_extract_hold_auto` 선례).
##
## ⚠ **못 잡는 것**: 문이 「지나갈 만해 보이나」·기둥이 「단단해 보이나」·[E] 문구가 읽히나.
##  통로 46px이 체감상 넉넉한지는 **F5가 정한다** — 여기서 재는 건 **그림과 판정이 갈라지지
##  않았다**는 사실뿐이다(정확값을 안 박고 그림에서 파생시킨다).
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

const GATE_SCENE := "res://src/props/forest_gate.tscn"
const PLAYER_SCENE := "res://src/actors/player.tscn"

## 🔴 기둥 판별 문턱 — 「그 열의 최장 연속 불투명 run」이 **전체 최대 run의 이 비율** 이상이면 기둥.
## 값의 근거(실측): 기둥 열의 최소 run 119 · 기둥 아닌 열의 최대 run 79 → 79/119 = **0.66**.
## 즉 (0.66, 1.00) 사이 아무 값이나 맞는데 0.75는 그 대역의 아래쪽에 여유를 두고 앉았다.
## 🔴 **최대 run을 기준으로 삼는 이유** = 스프라이트 높이가 아니라 **그려진 기둥 자체**에서 파생돼야
##  아치를 낮게 다시 그려도 문턱이 같이 내려온다(높이로 나누면 그때 거짓 빨강이 난다).
const PILLAR_RUN_FRAC := 0.75
## 분류가 애매하지 않다고 볼 상한 — 「기둥 아닌 최대 run ÷ 기둥 최소 run」이 이보다 크면 [1]이 빨개진다.
## 문턱(0.75)보다 낮게 잡아 **문턱에 닿기 전에** 사람이 보게 만든다.
const CLUSTER_SEP_MAX := 0.70

## 정적 대조 허용 오차(px) — 콜라이더 중심·크기의 반올림 여유. 세89 실패는 17~27px이라 넉넉히 잡힌다.
const EDGE_TOL := 2.0

## [5] 통로 모서리 동적 프로브 — 그림의 통로 안쪽 모서리에서 플레이어 반지름만큼 떨어진 자리 기준.
##  ⓒ `+CLEAR_PAD` = 돌에서 확실히 벗어난 자리 → **옆으로 안 밀린다**
##  ⓓ `-BITE`     = 돌을 이만큼 물고 있는 자리 → **옆으로 밀린다**
## 🔴 둘의 간격(5px)이 이 프로브의 분해능이다 — 콜라이더 안쪽 모서리가 3px만 어긋나도 한쪽이 뒤집힌다.
const EDGE_CLEAR_PAD := 1.0
const EDGE_BITE := 4.0
## 「옆으로 밀렸다」로 볼 최소 가로 이동(px). 실측: 무는 자리 4.15px · 벗어난 자리 0.00px.
const NUDGE_MIN := 1.0

## 북진 프레임 수 — 140프레임(≈2.3초 · 140px/s)이면 시작점 y=+60에서 기둥 북쪽 끝을 한참 지난다.
const WALK_FRAMES := 140
## 걷기 시작 y — 기둥 남쪽 면보다 확실히 아래(남쪽). 그림 아래끝(local y 0)보다 더 남쪽이면 된다.
const WALK_START_Y := 60.0

var failures: int = 0
var _gs = null
var _gate_scene: PackedScene = null
var _player_scene: PackedScene = null
## 그림에서 실측한 것 — `_measure_art()`가 한 번만 채운다
var _art := {}
## 플레이어 몸 반지름(`player.tscn`에서 읽는다 — 리터럴 금지)
var _body_radius := 0.0


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		print("TEST_GATE_COLLIDER_TIMEOUT — 120초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기 (게이트 루트 스크립트가 GameState를 참조한다)

	_gs = root.get_node("/root/GameState")
	_gate_scene = load(GATE_SCENE) as PackedScene
	_player_scene = load(PLAYER_SCENE) as PackedScene
	_body_radius = _read_player_radius()

	await _test_art_gives_two_pillars()
	await _test_collider_matches_drawn_pillar()
	await _test_collider_vertical_span()
	await _test_walk_blocked_and_through()
	await _test_passage_edge_is_where_drawn()
	await _test_layer_contract()
	await _test_trigger_covers_whole_gate()
	await _test_village_does_not_resize_the_gate()

	if failures == 0:
		print("TEST_GATE_COLLIDER_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_GATE_COLLIDER_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 🔴 **그림에서 기둥 둘을 뽑는다 — 그리고 분류가 애매하지 않다.**
## 이 항목이 없으면 아래 전부가 **자명 통과**가 된다(기둥을 0개 찾아도 루프가 0회면 조용히 그린).
## `test_prop_layout_auto [1]`이 "개수를 먼저 찍는다"고 한 그 자리다.
##
## 🔴 같이 잰다: **임포트 캐시 신선도**(`test_enemy_hitbox_auto [6]` 선례) — 기대치는 **디스크 PNG**에서
##  나오는데 게임이 그리는 건 `.godot/imported/*.ctex`다. 둘이 다르면 이 파일 전체가 그린인데
##  화면에선 어긋난다. ⚠ 빨개지면 코드 버그가 아니다 — 리드가 `--headless --import`를 돌리면 된다.
## 🔴 그리고 **좌표계 전제**: 스프라이트와 기둥 몸이 같은 배율(1)이어야 px→local 변환이 성립한다.
##  누가 씬에서 scale로 문을 키우면 여기가 빨개지고, 그때 이 파일의 변환을 같이 고쳐야 한다.
func _test_art_gives_two_pillars() -> void:
	print("[1] 🔴 그림에서 기둥을 뽑는다 (돌 = 불투명 · 포탈 = 반투명)")
	var a := _measure_art()
	_check(not a.is_empty(), "🔴 스프라이트 PNG를 디스크에서 읽었다 (%s)" % GATE_SCENE)
	if a.is_empty():
		return

	_check(a["group_count"] == 2,
		"🔴 기둥 기둥이 **정확히 2개** 잡힌다 (실제 %d개 — 0이면 아래 항목이 전부 자명통과다)"
			% a["group_count"])
	if a["group_count"] != 2:
		return

	_check(a["sep_ratio"] <= CLUSTER_SEP_MAX,
		"🔴 분류가 애매하지 않다 — 기둥 아닌 최대 run ÷ 기둥 최소 run = %.2f (≤ %.2f · 문턱 %.2f)"
			% [a["sep_ratio"], CLUSTER_SEP_MAX, PILLAR_RUN_FRAC])
	_check(a["gap_hi"] - a["gap_lo"] > 0.0,
		"🔴 두 기둥 사이에 통로가 있다 (%.0fpx — 0이면 그림이 문이 아니다)"
			% (a["gap_hi"] - a["gap_lo"]))
	# 그림은 좌우 대칭이다 — 한쪽만 다시 그리면 여기서 걸린다(콜라이더가 아니라 **그림**의 자기 검사).
	var lw: float = a["left_hi"] - a["left_lo"]
	var rw: float = a["right_hi"] - a["right_lo"]
	_check(absf(lw - rw) <= EDGE_TOL,
		"그린 기둥 폭이 좌우 같다 (왼 %.0f / 오른 %.0f)" % [lw, rw])
	_check(absf((a["left_lo"] + a["right_hi"])) <= EDGE_TOL * 2.0,
		"그린 문이 노드 원점 기준 좌우 대칭이다 (바깥 끝 %.1f / %.1f)" % [a["left_lo"], a["right_hi"]])

	# 🔴 임포트 신선도 + 좌표계 전제
	var gate = _gate_scene.instantiate()
	var spr := gate.get_node(^"Sprite") as Sprite2D
	_check(spr.texture.get_width() == int(a["tex_w"]) and spr.texture.get_height() == int(a["tex_h"]),
		"🔴 런타임 텍스처 %dx%d == 디스크 PNG %dx%d (다르면 임포트 캐시가 낡았다 → 리드가 `--headless --import`)"
			% [spr.texture.get_width(), spr.texture.get_height(), int(a["tex_w"]), int(a["tex_h"])])
	_check(spr.scale.is_equal_approx(Vector2.ONE),
		"Sprite 배율이 1이다 (아니면 이 파일의 px→local 변환을 같이 고쳐야 한다 · 실제 %s)" % spr.scale)
	var body := _pillar_body(gate)
	_check(body != null and body.scale.is_equal_approx(Vector2.ONE),
		"기둥 몸 배율이 1이다 = 그림과 같은 좌표계다")
	gate.free()

	print("    ↳ 그린 기둥 local x [%.0f..%.0f] · [%.0f..%.0f] · 통로 %.0fpx · 세로 [%.0f..%.0f]"
		% [a["left_lo"], a["left_hi"], a["right_lo"], a["right_hi"],
			a["gap_hi"] - a["gap_lo"], a["run_top"], a["run_bot"]])


## [2] 🔴🔴 **이 파일의 정적 심장 — 콜라이더 = 그려진 기둥.**
## 세89가 손으로 맞춘 그 값을 **그림에서 다시 계산해** 대조한다. 양쪽으로 잰다:
##  ⓐ **덮는다**(collider ⊇ 그린 돌) — 안 덮으면 **보이는 돌 안으로 걸어 들어간다**
##  ⓑ **삐져나오지 않는다**(collider ⊆ 그린 돌) — 삐져나오면 **허공에 막힌다**
## 🔴 ⓐ만 재면 「폭 9999」가 통과하고 ⓑ만 재면 「폭 0」이 통과한다.
## ⚠ 세89 이전 값(∓62 · 폭 24)이면 왼쪽 바깥 끝이 17px, 안쪽 끝이 27px 어긋나 둘 다 빨개진다.
func _test_collider_matches_drawn_pillar() -> void:
	print("[2] 🔴🔴 콜라이더 x 범위 == 그려진 기둥 x 범위 (허용 %.0fpx)" % EDGE_TOL)
	var a := _measure_art()
	if a.is_empty() or a["group_count"] != 2:
		_check(false, "그림 실측이 성립하지 않아 대조를 못 한다")
		return
	var gate = _gate_scene.instantiate()
	var boxes := _pillar_boxes(gate)
	_check(boxes.size() == 2,
		"🔴 기둥 콜라이더가 **정확히 2개**다 (실제 %d개 — 0이면 문이 통째로 안 막는다)" % boxes.size())
	if boxes.size() == 2:
		var want := [[a["left_lo"], a["left_hi"]], [a["right_lo"], a["right_hi"]]]
		var side := ["왼", "오른"]
		for i in 2:
			var got: Rect2 = boxes[i]
			_check(absf(got.position.x - want[i][0]) <= EDGE_TOL,
				"🔴 %s 기둥 **바깥** 끝: 콜라이더 %.1f == 그림 %.1f (어긋나면 허공에 막히거나 돌을 통과한다)"
					% [side[i], got.position.x, want[i][0]])
			_check(absf(got.end.x - want[i][1]) <= EDGE_TOL,
				"🔴 %s 기둥 **안쪽** 끝: 콜라이더 %.1f == 그림 %.1f (안쪽으로 파고들면 통로가 좁아진다)"
					% [side[i], got.end.x, want[i][1]])
	gate.free()


## [3] 세로 — 콜라이더가 **그려진 기둥을 덮되 그림 밖 허공은 안 막는다**.
## 🔴 위아래도 그림에서 파생시킨다: 아래끝은 「그림 전체의 알파가 끝나는 곳」(접지선)이고
##  위끝은 「기둥 열의 불투명 run이 시작하는 곳」이다. 아치를 높이거나 낮추면 둘 다 따라 움직인다.
## ⚠ 세로는 탑다운에서 「깊이」로 읽히는 축이라 수치가 손맛에 가깝다 — 그래서 **정확값을 안 박고**
##  「그림을 넘지 않는다 + 기둥을 덮는다」는 **대역**으로만 잰다(`test_enemy_hitbox_auto`의 RATIO 대역과 같은 결).
func _test_collider_vertical_span() -> void:
	print("[3] 콜라이더 y 범위가 그림 안에 있고 기둥을 덮는다")
	var a := _measure_art()
	if a.is_empty() or a["group_count"] != 2:
		return
	var gate = _gate_scene.instantiate()
	for box: Rect2 in _pillar_boxes(gate):
		_check(box.position.y >= a["art_top"] - EDGE_TOL,
			"🔴 콜라이더 위끝(%.1f)이 그림 위끝(%.1f) 아래다 = 허공을 안 막는다"
				% [box.position.y, a["art_top"]])
		_check(box.end.y <= a["art_bot"] + EDGE_TOL,
			"콜라이더 아래끝(%.1f)이 그림 아래끝(%.1f) 위다" % [box.end.y, a["art_bot"]])
		_check(box.position.y <= a["run_top"] + EDGE_TOL and box.end.y >= a["run_bot"] - EDGE_TOL,
			"🔴 콜라이더가 그려진 기둥 세로(%.0f..%.0f)를 덮는다 (실제 %.1f..%.1f)"
				% [a["run_top"], a["run_bot"], box.position.y, box.end.y])
	gate.free()


## [4] 🔴🔴 **동적 심장 — 진짜 플레이어로 걸어 본다. 양방향이다.**
##  ⓐ 기둥 한가운데로 북진 → **막힌다**(레이어·마스크·형상이 전부 살아 있어야 성립)
##  ⓑ 통로 한가운데로 북진 → **지나간다**(문이 통째로 벽이 아니다)
## 🔴 ⓐ만 재면 「문 전체가 벽」이, ⓑ만 재면 「콜라이더가 통째로 없다」가 조용히 통과한다.
## 🔴 기대치는 [1]이 그림에서 뽑은 좌표다 — 걸어갈 x도, 막혔다고 볼 y도 리터럴이 아니다.
func _test_walk_blocked_and_through() -> void:
	print("[4] 🔴🔴 진짜로 걸어 본다 — 돌은 막히고 통로는 지나간다")
	var a := _measure_art()
	if a.is_empty() or a["group_count"] != 2:
		return
	var stop_line: float = a["run_bot"]     # 기둥 남쪽 면 — 여기를 못 넘으면 막힌 것이다
	var clear_line: float = a["run_top"]    # 기둥 북쪽 끝 — 여기를 넘으면 통째로 지나간 것이다

	# 🔴🔴 **걷기 예산이 실제로 충분한가** — 이 항목이 없으면 「너무 느려서 못 갔다」가 조용히
	#  **「막혔다」로 읽힌다**(ⓐ는 통과하고 ⓑ만 빨개져서 원인을 엉뚱한 데서 찾게 된다).
	#  플레이어를 느리게 조이거나 방을 키우면 여기가 먼저 빨개져 **WALK_FRAMES를 올리라고** 말해 준다.
	var budget: float = _gs.move_speed() * float(WALK_FRAMES) / 60.0
	var need: float = WALK_START_Y - clear_line
	_check(budget > need * 1.3,
		"🔴 걷기 예산이 넉넉하다 = 이 프로브가 성립한다 (%.0fpx 걸을 수 있고 %.0fpx면 된다 · 모자라면 WALK_FRAMES를 올려라)"
			% [budget, need])

	for pair in [["왼", (a["left_lo"] + a["left_hi"]) * 0.5],
			["오른", (a["right_lo"] + a["right_hi"]) * 0.5]]:
		var r := await _walk_north(float(pair[1]))
		_check(r.y > stop_line - _body_radius - EDGE_TOL,
			"🔴 ⓐ %s 기둥 한가운데(x=%.0f)로 걸으면 **막힌다** (멈춘 y=%.1f · 기둥 남쪽 면 %.1f)"
				% [pair[0], float(pair[1]), r.y, stop_line])

	var mid: float = (a["gap_lo"] + a["gap_hi"]) * 0.5
	var t := await _walk_north(mid)
	_check(t.y < clear_line,
		"🔴 ⓑ 통로 한가운데(x=%.0f)로 걸으면 **지나간다** (도착 y=%.1f < 기둥 북쪽 끝 %.1f)"
			% [mid, t.y, clear_line])


## [5] 🔴🔴 **통로 안쪽 모서리가 그림대로다 — ±3px로 못 박는다.**
## [2]가 「선언형」이라면 여기는 **몸으로 재는** 짝이다. 통로 가장자리를 따라 북진할 때
##  ⓒ 돌에서 `EDGE_CLEAR_PAD`만큼 **벗어난** 자리 → 옆으로 **안 밀린다**
##  ⓓ 돌을 `EDGE_BITE`만큼 **물고 있는** 자리 → 옆으로 **밀린다**
## 🔴 왜 「막힌다/안 막힌다」가 아니라 「밀린다」인가 = 기둥 안쪽 면은 **세로 벽**이라 북진과
##  나란하다. 나란한 벽은 막지 않고 미끄러뜨린다 — 그래서 관측 가능한 신호가 **가로 밀림**이다
##  (실측: 무는 자리 4.15px · 벗어난 자리 0.00px).
## 🔴 이 짝이 **양방향**이다: ⓒ만 재면 기둥이 얇아져도(통로가 넓어져도) 통과하고,
##  ⓓ만 재면 기둥이 두꺼워져도(통로가 좁아져도) 통과한다.
func _test_passage_edge_is_where_drawn() -> void:
	print("[5] 🔴 통로 모서리 실측 — 돌을 물면 밀리고, 벗어나면 안 밀린다")
	var a := _measure_art()
	if a.is_empty() or a["group_count"] != 2:
		return
	_check(_body_radius > 0.0, "플레이어 몸 반지름을 `player.tscn`에서 읽었다 (%.1f)" % _body_radius)
	if _body_radius <= 0.0:
		return
	_check(a["gap_hi"] - a["gap_lo"] > (_body_radius + EDGE_BITE) * 2.0,
		"🔴 통로가 플레이어 몸보다 넉넉하다 = 이 프로브가 성립한다 (통로 %.0f / 몸 지름 %.0f)"
			% [a["gap_hi"] - a["gap_lo"], _body_radius * 2.0])

	# 왼쪽 모서리는 통로의 lo, 오른쪽 모서리는 hi — 부호만 뒤집어 같은 프로브를 돌린다.
	for pair in [["왼", a["gap_lo"], 1.0], ["오른", a["gap_hi"], -1.0]]:
		var edge: float = float(pair[1])
		var sgn: float = float(pair[2])
		var clear_x: float = edge + sgn * (_body_radius + EDGE_CLEAR_PAD)
		var bite_x: float = edge + sgn * (_body_radius - EDGE_BITE)

		var c := await _walk_north(clear_x)
		_check(absf(c.x - clear_x) < NUDGE_MIN,
			"🔴 ⓒ %s 모서리에서 %.0fpx 벗어난 자리(x=%.1f)로 걸으면 **안 밀린다** (밀림 %.2fpx)"
				% [pair[0], EDGE_CLEAR_PAD, clear_x, absf(c.x - clear_x)])

		var b := await _walk_north(bite_x)
		_check(absf(b.x - bite_x) >= NUDGE_MIN,
			"🔴 ⓓ %s 모서리를 %.0fpx 문 자리(x=%.1f)로 걸으면 **밀린다** (밀림 %.2fpx — 0이면 기둥이 그림보다 얇다)"
				% [pair[0], EDGE_BITE, bite_x, absf(b.x - bite_x)])


## [6] 🔴 **레이어 계약** — 형상이 맞아도 레이어가 어긋나면 **에러 없이** 통과해 버린다(세24 선례:
## 물리 레이어가 틀리면 진이 총구에서 조용히 죽는다).
##  ⓐ 기둥 레이어 ∩ 플레이어 마스크 ≠ 0 — **둘 다 씬에서 읽는다**(리터럴 1·2를 안 박는다)
##  ⓑ 기둥은 상호작용 레이어(트리거 Area2D의 레이어)와 **겹치지 않는다** — 겹치면 캐리어·감지가 꼬인다
##  ⓒ 기둥 마스크 == 0 — StaticBody가 남을 감지할 이유가 없다(켜면 물리 잡음만 는다)
func _test_layer_contract() -> void:
	print("[6] 🔴 물리 레이어 — 기둥이 플레이어를 실제로 막을 수 있는 레이어에 있다")
	var gate = _gate_scene.instantiate()
	var body := _pillar_body(gate)
	if body == null:
		_check(false, "문에 기둥 몸(StaticBody2D)이 있다")
		gate.free()
		return
	var player = _player_scene.instantiate()
	_check((body.collision_layer & player.collision_mask) != 0,
		"🔴 기둥 레이어(%d) ∩ 플레이어 마스크(%d) ≠ 0 = 실제로 막을 수 있다"
			% [body.collision_layer, player.collision_mask])
	_check((body.collision_layer & gate.collision_layer) == 0,
		"🔴 기둥 레이어(%d)가 트리거 Area 레이어(%d)와 겹치지 않는다 (겹치면 [E] 감지·캐리어가 꼬인다)"
			% [body.collision_layer, gate.collision_layer])
	_check(body.collision_mask == 0,
		"기둥 마스크가 0이다 = 남을 감지하지 않는다 (실제 %d)" % body.collision_mask)
	player.free()
	gate.free()


## [7] 🔴 **[E] 트리거가 문 앞 전체를 덮는다** — 기둥에 막혀 선 자리에서 문구가 안 뜨면
## 「문이 있는데 못 연다」가 된다(세97 교훈: 기능이 돈다 ≠ 거기 갈 수 있다).
## 🔴 기대치는 그림에서 파생: **트리거 가로가 그린 문의 바깥 끝을 덮는다** + **기둥 남쪽 면에
##  막혀 선 플레이어가 트리거 안에 있다**. 문을 넓게 다시 그리면 트리거도 같이 넓혀야 하고,
##  안 넓히면 여기가 빨개진다.
func _test_trigger_covers_whole_gate() -> void:
	print("[7] [E] 트리거가 문 앞 전체를 덮는다")
	var a := _measure_art()
	if a.is_empty() or a["group_count"] != 2:
		return
	var gate = _gate_scene.instantiate()
	var shape := gate.get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if shape == null or not (shape.shape is RectangleShape2D):
		_check(false, "문 트리거에 사각 형상이 있다")
		gate.free()
		return
	var r := (shape.shape as RectangleShape2D).size
	var box := Rect2(shape.position - r * 0.5, r)
	_check(box.position.x <= a["left_lo"] and box.end.x >= a["right_hi"],
		"🔴 트리거 가로(%.0f..%.0f)가 그린 문 폭(%.0f..%.0f)을 덮는다 = 문 앞 어디서 서도 [E]가 뜬다"
			% [box.position.x, box.end.x, a["left_lo"], a["right_hi"]])
	# 기둥 남쪽 면에 막혀 선 몸의 중심 — 이 자리가 트리거 안이어야 한다
	var stand_y: float = a["run_bot"] + _body_radius
	_check(box.position.y <= stand_y and box.end.y >= stand_y,
		"🔴 기둥에 막혀 선 자리(y=%.1f)가 트리거 세로(%.0f..%.0f) 안이다"
			% [stand_y, box.position.y, box.end.y])
	gate.free()


## [8] 🔴🔴 **마을이 문을 키우지 않았다** — [1]~[7]은 전부 **프롭 하나를 따로 세워** 재기 때문에,
## 무대가 그 인스턴스를 `scale`로 늘리면 **여기 전부가 그린인데 화면에선 어긋난다**
## (세97 교훈의 이 항목판: 「프롭이 맞다」 ≠ 「게임에 선 그 문이 맞다」).
## 🔴 씬을 **띄우지 않고** `SceneState`로 오버라이드 목록만 읽는다 — 마을을 인스턴스화하면
##  온보딩 대사·모달이 끼어들어 이 검사와 무관한 이유로 흔들린다.
## ⚠ 무대 목록을 하드코딩하지 않았다 — **문을 무는 모든 씬**을 훑으므로 새 무대가 자동으로 든다
##  (`test_scene_contract_auto`가 씬 목록을 안 박은 것과 같은 이유).
const RESIZE_PROPS := [&"scale", &"transform", &"rotation", &"skew"]

func _test_village_does_not_resize_the_gate() -> void:
	print("[8] 🔴 문을 무는 무대가 문을 늘리거나 돌리지 않는다")
	var stages := _scenes_using_gate()
	_check(not stages.is_empty(),
		"🔴 문을 무는 씬을 %d장 찾았다 (0이면 이 항목이 자명통과다)" % stages.size())
	for path: String in stages:
		var st := (load(path) as PackedScene).get_state()
		for i in st.get_node_count():
			if st.get_node_instance(i) == null \
					or not str(st.get_node_instance(i).resource_path).ends_with("forest_gate.tscn"):
				continue
			var bad := []
			for j in st.get_node_property_count(i):
				var pn: StringName = st.get_node_property_name(i, j)
				if RESIZE_PROPS.has(pn):
					bad.append("%s = %s" % [pn, st.get_node_property_value(i, j)])
			# ⚠ `position` 오버라이드는 정상이다 — 무대가 문을 **어디에 둘지** 정하는 게 프롭 계약이다
			#   (세44: 부모가 인스턴스 이름·위치를 오버라이드한다). 막는 건 **크기·각도**뿐이다.
			_check(bad.is_empty(),
				"🔴 %s의 `%s`가 문의 크기·각도를 안 덮는다 (덮으면 이 파일의 실측이 통째로 헛것이 된다%s)"
					% [path.get_file(), st.get_node_name(i),
						"" if bad.is_empty() else " — 실제 " + ", ".join(bad)])


## 문 프롭을 무는 씬 전량 — 무대 목록을 안 박는다(새 무대가 자동으로 든다).
func _scenes_using_gate() -> Array:
	var out := []
	for path in _all_scenes("res://src"):
		var st := (load(path) as PackedScene).get_state()
		for i in st.get_node_count():
			var inst := st.get_node_instance(i)
			if inst != null and str(inst.resource_path).ends_with("forest_gate.tscn"):
				out.append(path)
				break
	return out


func _all_scenes(dir_path: String) -> Array:
	var out := []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		var p := dir_path.path_join(n)
		if d.current_is_dir():
			if not n.begins_with("."):
				out.append_array(_all_scenes(p))
		elif n.ends_with(".tscn"):
			out.append(p)
		n = d.get_next()
	d.list_dir_end()
	return out


# ── 헬퍼 ──

## 🔴🔴 **그림 실측** — 문 스프라이트의 PNG를 **디스크에서** 읽어 기둥·통로를 뽑는다.
## 경로도 리터럴이 아니라 **씬의 Sprite2D가 문 텍스처**라서 나온다(아트가 파일을 갈아도 따라간다).
## `load()`(임포트 캐시)가 아니라 `Image.load_from_file`인 이유 = 기준은 **아트**여야 하고, 캐시가
## 낡았다는 사실 자체는 [1]이 따로 잡는다(`test_enemy_hitbox_auto` 선례).
##
## 판별: 열마다 **a >= 0.99인 픽셀의 최장 연속 세로 run**. 돌기둥은 완전 불투명이고 포탈 수면·
## 아치 곡선은 반투명이라 갈린다. 문턱은 최대 run × PILLAR_RUN_FRAC.
## 반환 좌표는 전부 **문 노드 기준 local px**(Sprite의 centered/offset/scale을 반영한다).
func _measure_art() -> Dictionary:
	if not _art.is_empty():
		return _art
	var gate = _gate_scene.instantiate()
	var spr := gate.get_node_or_null(^"Sprite") as Sprite2D
	if spr == null or spr.texture == null:
		gate.free()
		return {}
	var img := Image.load_from_file(spr.texture.resource_path)
	if img == null:
		gate.free()
		return {}
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()

	var runs := PackedInt32Array()
	var tops := PackedInt32Array()
	var bots := PackedInt32Array()
	var art_top := h
	var art_bot := -1
	for x in w:
		var best := 0
		var bt := -1
		var bb := -1
		var cur := 0
		var ct := -1
		for y in h:
			var al := img.get_pixel(x, y).a
			if al > 0.0:
				art_top = mini(art_top, y)
				art_bot = maxi(art_bot, y)
			if al >= 0.99:
				if cur == 0:
					ct = y
				cur += 1
				if cur > best:
					best = cur
					bt = ct
					bb = y
			else:
				cur = 0
		runs.append(best)
		tops.append(bt)
		bots.append(bb)

	var maxrun := 0
	for r in runs:
		maxrun = maxi(maxrun, r)
	var thr := int(ceil(float(maxrun) * PILLAR_RUN_FRAC))

	# 인접한 기둥 열을 그룹으로 묶는다
	var groups := []
	var lo := -1
	for x in w:
		if runs[x] >= thr:
			if lo < 0:
				lo = x
		elif lo >= 0:
			groups.append([lo, x - 1])
			lo = -1
	if lo >= 0:
		groups.append([lo, w - 1])

	# 클러스터 분리 여유 — 「기둥 아닌 최대 run ÷ 기둥 최소 run」
	var in_min := maxrun
	var out_max := 0
	for x in w:
		if runs[x] >= thr:
			in_min = mini(in_min, runs[x])
		else:
			out_max = maxi(out_max, runs[x])

	var out := {
		"group_count": groups.size(),
		"sep_ratio": (float(out_max) / float(in_min)) if in_min > 0 else 9.0,
		"tex_w": float(w),
		"tex_h": float(h),
		"art_top": _local_y(float(art_top), spr, h),
		"art_bot": _local_y(float(art_bot + 1), spr, h),
	}
	if groups.size() == 2:
		var run_top := h
		var run_bot := -1
		for g in groups:
			for x in range(int(g[0]), int(g[1]) + 1):
				run_top = mini(run_top, tops[x])
				run_bot = maxi(run_bot, bots[x])
		out["left_lo"] = _local_x(float(groups[0][0]), spr, w)
		out["left_hi"] = _local_x(float(int(groups[0][1]) + 1), spr, w)
		out["right_lo"] = _local_x(float(groups[1][0]), spr, w)
		out["right_hi"] = _local_x(float(int(groups[1][1]) + 1), spr, w)
		out["gap_lo"] = out["left_hi"]
		out["gap_hi"] = out["right_lo"]
		out["run_top"] = _local_y(float(run_top), spr, h)
		out["run_bot"] = _local_y(float(run_bot + 1), spr, h)
	gate.free()
	_art = out
	return out


## 텍스처 픽셀 경계 → 노드 기준 local 좌표. `centered`/`offset`/`scale`을 전부 반영한다.
func _local_x(px: float, spr: Sprite2D, w: int) -> float:
	var base := px - (float(w) * 0.5 if spr.centered else 0.0)
	return base * spr.scale.x + spr.offset.x


func _local_y(py: float, spr: Sprite2D, h: int) -> float:
	var base := py - (float(h) * 0.5 if spr.centered else 0.0)
	return base * spr.scale.y + spr.offset.y


## 문 안의 기둥 몸(StaticBody2D) — 이름으로 안 찾는다(개명해도 그물이 안 죽게).
func _pillar_body(gate) -> StaticBody2D:
	for c in gate.get_children():
		if c is StaticBody2D:
			return c
	return null


## 기둥 콜라이더들의 문 기준 사각 — **중심 x 오름차순**(왼쪽 먼저)으로 돌려준다.
func _pillar_boxes(gate) -> Array:
	var body := _pillar_body(gate)
	if body == null:
		return []
	var out := []
	for c in body.get_children():
		if not (c is CollisionShape2D):
			continue
		var sh = (c as CollisionShape2D).shape
		if not (sh is RectangleShape2D):
			continue
		var sz: Vector2 = (sh as RectangleShape2D).size
		var mid: Vector2 = body.position + (c as CollisionShape2D).position
		out.append(Rect2(mid - sz * 0.5, sz))
	out.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.get_center().x < b.get_center().x)
	return out


## 🔴 플레이어 몸 반지름을 `player.tscn`에서 읽는다 — 리터럴 10을 박으면 몸을 키울 때 [5]가 조용히 어긋난다.
func _read_player_radius() -> float:
	var p = _player_scene.instantiate()
	var out := 0.0
	for c in p.get_children():
		if c is CollisionShape2D and (c as CollisionShape2D).shape is CircleShape2D:
			out = ((c as CollisionShape2D).shape as CircleShape2D).radius
			break
	p.free()
	return out


## 🔴 **진짜 플레이어를 세워 북쪽으로 걷게 한다** — `Input.action_press`로 실경로를 지난다
## (`player.gd`가 `Input.get_vector`를 폴링하므로 이벤트 주입 없이 액션 상태만으로 충분하다).
## 문·플레이어를 매번 새로 세우고 끝에 통째로 free한다 — 남기면 다음 프로브에 플레이어가 둘이 된다.
## 반환 = 도착한 문 기준 좌표.
func _walk_north(x: float) -> Vector2:
	var holder := Node2D.new()
	root.add_child(holder)
	var gate = _gate_scene.instantiate()
	holder.add_child(gate)
	gate.global_position = Vector2.ZERO
	var player = _player_scene.instantiate()
	holder.add_child(player)
	player.global_position = Vector2(x, WALK_START_Y)
	await process_frame
	await physics_frame

	Input.action_press(&"move_up")
	for i in WALK_FRAMES:
		await physics_frame
	Input.action_release(&"move_up")
	var end: Vector2 = player.global_position
	holder.free()
	await process_frame
	return end


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
