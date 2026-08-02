extends SceneTree
## 🔴 고리 **조립 계약** 검증 — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_assembly_auto.gd
## 전 항목 통과 시 "TEST_RING_ASSEMBLY_OK" 출력 후 종료 코드 0.
##
## 🔴 **남은 것 = 지금도 살아 있는 계약뿐**:
##   • assembly 스냅샷의 **모양**(발사·저장이 읽는 dict — 바뀌면 둘 다 조용히 깨진다)
##   • `clear_all`이 판을 처음으로 돌린다
##   • 🔴 **진 .tres Db 로드**(파싱 침묵사 그물 — 진 하나가 증발해도 다른 데선 안 빨개진다)
##   • 🔴 **`jin_slot_dots` 기하**(「칸 0=위, 시계방향」 — HUD·Tab 미니 다이어그램의 **라이브** 소비자)
##
## 여기 있는 건 전부 **public API 계약**이다. 내부 필드(_slots 등)를 더듬지 않는다:
## 그건 리팩터 때 옮겨 다니는 물건이라 계약이 아니다.
##
## 주의: -s 모드는 오토로드보다 먼저 컴파일 — 오토로드 식별자·모듈 preload 금지. 첫 프레임 후 load().

const GLYPH_NONE := -1
const SLOTS := 8

var failures: int = 0
var _BoardScript = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(15.0).timeout.connect(func() -> void:
		print("TEST_RING_ASSEMBLY_TIMEOUT — 15초 초과")
		quit(1))
	await process_frame

	_BoardScript = load("res://src/drawing/ring_board.gd")

	_test_initial_state()
	_test_assembly_shape()
	_test_clear_all_resets()
	_test_jin_db_loaded()
	_test_jin_schema_defaults()
	_test_jin_slot_dots()
	_test_retired_api_stays_retired()

	if failures == 0:
		print("TEST_RING_ASSEMBLY_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_RING_ASSEMBLY_FAIL — %d개 실패" % failures)
		quit(1)


func _make_board():
	var b = _BoardScript.new()
	b.size = Vector2(268, 268)
	root.add_child(b)
	b.call(&"clear_all")
	return b


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("  ✗ ", msg)


# ── ① 빈 판의 초기 계약 ──
## 🔴 `is_tracing()`이 **거짓**인 게 계약이다 — 합성 밑그림의 소유자가 패널이라 판은 비운 채
## 기다린다 (라이브는 `clear_all()` 직후 `recompose()`가 COMBINED를 넣는다 —
## `test_base_auto`가 그 경로를 잰다).
func _test_initial_state() -> void:
	var b = _make_board()
	_check(not bool(b.call(&"has_jin")), "초기: 진 없음")
	_check(not bool(b.call(&"has_rune")), "초기: 룬 없음")
	_check(not bool(b.call(&"can_commit")), "초기: 맺기 불가")
	_check(not bool(b.call(&"is_tracing")),
		"🔴 빈 판은 그릴 것이 없다 (참이면 판이 제멋대로 가이드를 세운 것 — 패널 소유 계약 위반)")
	_check(int(b.call(&"filled_count")) == 0, "초기: 채운 칸 0")
	b.queue_free()


# ── ② 🔴 assembly = 발사·저장 계약. 모양이 바뀌면 둘 다 조용히 깨진다 ──
func _test_assembly_shape() -> void:
	var b = _make_board()
	var a: Dictionary = b.call(&"get_assembly")
	_check(int(a.get("ring_count", -1)) == 1, "assembly.ring_count = 1 (진 하나)")
	_check(a.has("rune") and a.has("runes"), "assembly에 rune(primary)·runes(목록)")
	_check(a.has("rings") and (a.rings as Array).size() == 1, "assembly.rings = 1줄")
	_check((a.rings[0] as Array).size() == SLOTS, "고리 한 줄 = 8칸 고정")
	_check(a.has("open"), "assembly에 open(열린 칸)")
	for k in SLOTS:
		_check(int(a.rings[0][k]) == GLYPH_NONE, "빈 판의 모든 칸 = 빈칸(-1)")
	# 🔴 판의 assembly에도 score·잉크가 실린다(안 실으면 조용히 기준 위력).
	# ⚠ 라이브 발사 계약은 `ring_forge_panel.build_assembly()`가 만든다(`test_jin_layers_auto[7]`).
	#   판의 이 dict는 **특별잉크 집계 창구**로 그쪽이 부른다 — 키가 빠지면 그 경로가 죽는다.
	_check(a.has("score") and a.has("ink") and a.has("special_ink") and a.has("special_ratio"),
		"판 assembly에 score·ink·special_ink·special_ratio (패널이 특별잉크를 여기서 뽑는다)")
	b.queue_free()


# ── ③ clear_all은 판을 처음으로 되돌린다 ──
func _test_clear_all_resets() -> void:
	var b = _make_board()
	# 합성 가이드를 넣고 좀 그은 뒤 비운다 (라이브가 하는 그대로)
	var ctr: Vector2 = b.size * 0.5
	var guide := PackedVector2Array()
	for i in 40:
		guide.append(ctr + Vector2.from_angle(TAU * float(i) / 40.0) * 60.0)
	b.call(&"enter_combined_trace", guide)
	b.call(&"begin_stroke")
	for p in guide:
		b.call(&"trace_stroke", p)
	_check(float(b.call(&"coverage")) > 0.0, "그었으니 완성도 > 0 (대조군)")
	b.call(&"clear_all")
	_check(not bool(b.call(&"has_jin")) and not bool(b.call(&"has_rune")), "clear_all → 진·룬 없음")
	_check(not bool(b.call(&"can_commit")), "clear_all → 맺기 불가")
	_check(int(b.call(&"filled_count")) == 0, "clear_all → 채운 칸 0")
	_check(is_zero_approx(float(b.call(&"coverage"))), "clear_all → 먹선·점수도 비운다")
	_check(not bool(b.call(&"is_tracing")), "clear_all → 그릴 것 없음 (패널이 recompose로 다시 넣는다)")
	var a: Dictionary = b.call(&"get_assembly")
	for k in SLOTS:
		_check(int(a.rings[0][k]) == GLYPH_NONE, "clear_all → assembly 전 칸 비움")
	b.queue_free()


# ── ④ 🔴 Db 로드 그물 — .tres 파싱 침묵사 방지 (한 글자 오타 = 리소스 전체 증발) ──
# test_rune_unlock_auto의 「룬 6종 로드」와 같은 역할. Db는 못 읽은 리소스를 조용히 건너뛰므로
# 개수를 세지 않으면 진 하나가 게임에서 통째로 사라져도 전 스위트가 그린이다.
func _test_jin_db_loaded() -> void:
	var db: Node = root.get_node("/root/Db")
	var jins: Array = db.call(&"all_jins")
	# 🔴 진을 하나 되살릴 때마다 이 기대치를 +1 (지금 3종: jin_single·jin_plain_g2·jin_fuse).
	_check(jins.size() == 3, "🔴 진 3종(jin_single·jin_plain_g2·jin_fuse)이 Db에 로드된다 (지금 %d종 — 줄었으면 .tres 침묵사 의심, 새 진을 추가했으면 기대치를 갱신)" % jins.size())
	# 🔴 **진의 개성을 실제로 쥐는 두 값**을 잰다.
	# 값이 파싱에 실패하면 필드가 조용히 기본값(1)로 떨어지므로 **실값을 명시로 확인**한다 —
	# 합계나 "비어 있지 않다"로 재면 한 진이 1층으로 주저앉아도 그린이다.
	var want := {&"jin_single": [1, 1], &"jin_plain_g2": [2, 1], &"jin_fuse": [2, 2]}
	for jd in jins:
		var jid := StringName(jd.get(&"id"))
		var band := int(jd.get(&"band_count"))
		var rslots := int(jd.get(&"rune_slots"))
		if want.has(jid):
			var w: Array = want[jid]
			_check(band == int(w[0]) and rslots == int(w[1]),
				"%s: band_count %d·rune_slots %d (기대 %d·%d — 어긋나면 .tres 필드가 조용히 기본값으로 떨어진 것)"
					% [jid, band, rslots, int(w[0]), int(w[1])])
		else:
			_check(false, "예상 밖의 진 %s — 새 진을 넣었으면 위 기대표에 한 줄 더해라" % jid)
		_check(band >= 1 and rslots >= 1, "%s: band_count·rune_slots는 1 이상" % jid)


# ── ⑤ JinDef 기본값 계약 — 필드 누락 .tres도 조용히 안 깨진다 ──
## 🔴 **`glyph_slots`가 정말 사라졌는지도 여기서 잰다** — 필드만 남기고 소비자를 지우면 그게
##   딱 「거짓 손잡이」다. .tres에 다시 적히면 이 검사가 빨개진다.
func _test_jin_schema_defaults() -> void:
	var jd: Resource = (load("res://src/core/schemas/jin_def.gd") as GDScript).new()
	_check(int(jd.get(&"band_count")) == 1, "JinDef.new().band_count 기본 = 1 (옛 .tres도 1층으로 산다)")
	_check(int(jd.get(&"rune_slots")) == 1, "JinDef.new().rune_slots 기본 = 1 (일반진)")
	_check(int(jd.get(&"slot_count")) == SLOTS, "JinDef.new().slot_count 기본 = 8 (고리 기하 계약)")
	var props: Array = []
	for pd in jd.get_property_list():
		props.append(String(pd.get("name", "")))
	_check(not ("glyph_slots" in props),
		"🔴 `glyph_slots` 필드가 스키마에서 사라졌다 (세85 ⑦ — 남아 있으면 소비자 0인 거짓 손잡이)")


# ── ⑥ 진 셀 다이어그램 관측점 — 「칸 0=위, 시계방향」 기하 규약 ──
# jin_slot_dots는 순수 static 관측점이고 **라이브 소비자가 둘**이다(hud.gd·tab_panel.gd의
# 슬롯 미니 다이어그램). 각도(-PI/2 탈락)·open 반전 회귀를 렌더로는 못 잡는다 —
# MCP 스샷은 커밋 시점 1회 스냅샷이다. 여기가 상시 그물.
func _test_jin_slot_dots() -> void:
	var b = _make_board()
	var dots: Array = b.call(&"jin_slot_dots", [1, 5], Vector2.ZERO, 10.0)
	_check(dots.size() == SLOTS, "다이어그램 점 = 8개 (칸 전수)")
	var p0: Vector2 = dots[0]["pos"]
	var p2: Vector2 = dots[2]["pos"]
	_check(p0.distance_to(Vector2(0, -10)) < 0.01, "칸 0 = 위 (지금 %s — -PI/2 규약)" % str(p0))
	_check(p2.distance_to(Vector2(10, 0)) < 0.01, "칸 2 = 오른쪽 (시계방향 규약)")
	var opens: Array = []
	for k in SLOTS:
		if bool(dots[k]["open"]):
			opens.append(k)
	_check(opens == [1, 5], "열린 표시 = 정확히 [1,5] (지금 %s)" % str(opens))
		# 🔴 각도의 정본이 static `slot_angle`인지 — 식을 베끼면 판·책·HUD가 조용히 어긋난다.
	for k in SLOTS:
		var want: Vector2 = Vector2.from_angle(float(b.call(&"slot_angle", k))) * 10.0
		_check((dots[k]["pos"] as Vector2).distance_to(want) < 0.001,
			"칸 %d 좌표 = slot_angle(%d) 그대로 (베낀 식이면 여기가 빨개진다)" % [k, k])
	b.queue_free()


# ── ⑦ 🔴 은퇴한 per-piece API가 **되살아나지 않았나** (재발 감지) ──
## 이 프로젝트의 실패 방식은 「지웠는데 다음이 되살린다」다. 판이 다시 per-piece를 갖는 순간
## **라이브(COMBINED)와 두 몸이 되고**, 그물이 다시 죽은 몸을 재기 시작한다.
## 이름이 돌아오면 여기가 빨개진다.
## ⚠ `get_analysis`는 목록에 없다 — 라이브 `build_assembly()`가 부르는 산 코드다.
func _test_retired_api_stays_retired() -> void:
	var b = _make_board()
	var retired := ["advance", "finish", "select_slot", "set_active_glyph", "active_glyph",
		"ring_summary", "choose_jin", "choose_rune", "jin_idx", "rune_idx",
		"set_open_slots", "trace_slot", "locked_count"]
	var alive: Array = []
	for m in retired:
		if b.has_method(m):
			alive.append(m)
	_check(alive.is_empty(),
		"🔴 per-piece API가 은퇴 상태다 (되살아난 것: %s — 되살리려면 COMBINED와의 두 몸 문제를 먼저 풀어라)"
			% str(alive))
	# 판이 실제로 쓰는 진입점은 살아 있어야 한다 (반대 방향 대조 — 위 목록이 자명 통과가 아니게)
	for m in ["enter_combined_trace", "combined_total", "coverage", "accuracy",
			"begin_stroke", "trace_stroke", "clear_stroke", "get_assembly", "get_analysis"]:
		_check(b.has_method(m), "라이브 진입점 `%s`는 살아 있다" % m)
	b.queue_free()
