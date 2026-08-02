extends SceneTree
## 🔴 **문양 효과·표현 데이터화 + 응축** 자동 검증 — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_glyph_data_auto.gd
##
## 무엇을 재나: 문양의 **효과 로직**(behavior+params)과 **표시 어휘**(이름·색)가 코드가 아니라
## `data/glyphs/*.tres`에서 온다는 계약. 그리고 그 위에 선 첫 문양 **응축**(폭발의 반대)이
## **새 알고리즘 없이** 도는지.
##
## ⚠ -s 모드는 오토로드보다 먼저 컴파일 — 오토로드 식별자·모듈 preload 금지. 첫 프레임 후 load().

var failures: int = 0
var _db = null
var _gs = null
var _GR = null
var _Sys = null
var _Board = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(20.0).timeout.connect(func() -> void:
		print("TEST_GLYPH_DATA_TIMEOUT — 20초 초과")
		quit(1))
	await process_frame

	_db = root.get_node("/root/Db")
	_gs = root.get_node("/root/GameState")
	_GR = load("res://src/core/glyph_rules.gd")
	_Sys = load("res://src/spell/ring_spell_system.gd")
	_Board = load("res://src/drawing/ring_board.gd")

	_t1_catalog_loads()
	_t2_modifier_codes()
	_t3_regression_params_moved()
	_t4_condense_is_the_opposite_of_explode()
	_t5_merge_mult_per_count_is_on_the_path()
	_t6_condense_needs_no_new_algorithm()
	_t7_unknown_code_skipped_empty_is_silent()
	_t8_duplicate_code_deterministic_winner()
	_t9_reindex_after_injection()
	_t10_placement_order_does_not_matter()
	_t11_radius_never_inverts()
	_t12_ui_reads_names_from_data()

	if failures == 0:
		print("TEST_GLYPH_DATA_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_GLYPH_DATA_FAIL — %d개 실패" % failures)
		quit(1)


# ── [1] 🔴 카탈로그 전량 로드 (.tres 파싱 침묵사 그물) ──
# `.tres` 문법이 한 글자만 틀려도 리소스 **전체가 조용히 사라지고** Db가 말없이 건너뛴다.
# 특히 `params` 사전 리터럴이 그 자리다 — 여기가 이 데이터화의 생명선이다.
func _t1_catalog_loads() -> void:
	print("[1] Enums.GlyphCode 전 값이 Db에 로드된다")
	var expect := {
		Enums.GlyphCode.GATHER: &"pillar", Enums.GlyphCode.RADIATE: &"bolt",
		Enums.GlyphCode.PIERCE: &"bolt", Enums.GlyphCode.HOMING: &"bolt",
		Enums.GlyphCode.BOUNCE: &"bolt", Enums.GlyphCode.THRUST: &"bolt",
		Enums.GlyphCode.SPREAD: &"spread", Enums.GlyphCode.EXPLODE: &"blast",
		Enums.GlyphCode.CONDENSE: &"blast",
	}
	# 🔴 **예외 목록이 없다** — 예외는 곧 자명 통과의 씨앗이다. 살아있는 코드는 전부 데이터가 있다.
	for code: int in expect.keys():
		var gd = _db.glyph_by_code(code)
		_check(gd != null, "code %d의 GlyphDef가 로드됐다 (없으면 그 칸이 발사에서 통째로 빠진다)" % code)
		if gd == null:
			continue
		_check(gd.behavior == expect[code],
			"code %d behavior = %s (실제 %s)" % [code, expect[code], gd.behavior])
		_check(_GR.is_known(gd.behavior), "code %d의 behavior가 BEHAVIORS에 있다" % code)
		_check(gd.display_name != "", "code %d에 표시 이름이 있다 (UI 정본)" % code)
	# params가 실제로 파싱됐나 — 사전 리터럴 문법이 틀리면 여기서 잡힌다
	var sp = _db.glyph_by_code(Enums.GlyphCode.SPREAD)
	_check(_GR.param_f(sp, &"fan_deg", -1.0) > 0.0,
		"확산 params.fan_deg가 파싱됐다 (실제 %.1f — -1이면 .tres 사전이 통째로 안 읽혔다)"
			% _GR.param_f(sp, &"fan_deg", -1.0))
	var cd = _db.glyph_by_code(Enums.GlyphCode.CONDENSE)
	_check(_GR.param_f(cd, &"radius_per_branch", 999.0) < 0.0,
		"응축 params.radius_per_branch가 **음수로** 파싱됐다 (이 부호가 곧 「좁게 모은다」다)")


# ── [2] 계열 판별 = 데이터가 답한다 ──
# 🔴 기대 집합을 **명시로** 박는다 (옛 `Enums.is_modifier_glyph`는 은퇴해 대조할 대상이 없다).
func _t2_modifier_codes() -> void:
	print("[2] 변형형 = 확산·폭발·응축 / 전개형 = 응집·발산·관통·유도·팅김·추진")
	var mods: Array = _db.modifier_codes()
	_check(mods == [Enums.GlyphCode.SPREAD, Enums.GlyphCode.EXPLODE, Enums.GlyphCode.CONDENSE],
		"modifier_codes == [6,7,8] (실제 %s)" % str(mods))
	for c in [Enums.GlyphCode.GATHER, Enums.GlyphCode.RADIATE, Enums.GlyphCode.PIERCE,
			Enums.GlyphCode.HOMING, Enums.GlyphCode.BOUNCE, Enums.GlyphCode.THRUST]:
		_check(not _GR.is_modifier_def(_db.glyph_by_code(c)), "code %d는 전개형" % c)


# ── [3] 🔴 회귀 — 수치가 balance에서 .tres로 이사했는데 **계산이 같다** ──
# ⚠ balance 수치를 박지 말고 **관계식으로** 잰다 — 손맛 튜닝 한 번에 거짓 빨강이 되면 안 된다.
func _t3_regression_params_moved() -> void:
	print("[3] 파라미터 이사 무회귀 — 관계식으로 잰다")
	var sys = _Sys.new()
	root.add_child(sys)
	var ex = _db.glyph_by_code(Enums.GlyphCode.EXPLODE)
	# 확산: 갈래 수 = count(≥2) · 합이 늘어난다(1/n로 나누지 않는다 = "그릴 이유가 있다")
	var inner: Array = [{"kind": &"bolt", "angle": 0.0, "offset": Vector2.ZERO, "mult": 1.0, "effects": {}}]
	var sp3: Array = sys._spread(inner, 3, _db.glyph_by_code(Enums.GlyphCode.SPREAD))
	_check(sp3.size() == 3, "확산 3칸 → 3갈래 (실제 %d)" % sp3.size())
	var total := 0.0
	for c: Dictionary in sp3:
		total += float(c["mult"])
	_check(total > 1.0, "확산 갈래 합이 1.0을 넘는다 (실제 %.2f — 안 넘으면 그릴 이유가 없다)" % total)
	var angles_differ: bool = not is_equal_approx(float(sp3[0]["angle"]), float(sp3[2]["angle"]))
	_check(angles_differ, "확산 갈래들의 각도가 벌어진다")
	# 폭발: 융합 = 명령 **하나** · 갈래가 많을수록 넓다 · 합에 손실(merge_mult<1)
	var ex1: Array = sys._explode(inner, 1, ex)
	var ex3: Array = sys._explode(sp3, 1, ex)
	_check(ex1.size() == 1 and ex3.size() == 1, "폭발은 안쪽이 몇이든 **하나로 융합**한다")
	_check(float(ex3[0]["radius"]) > float(ex1[0]["radius"]),
		"폭발 반경이 안쪽 갈래 수에 **비례**한다 (%.1f > %.1f — 이게 M1 순서 실증의 자리다)"
			% [float(ex3[0]["radius"]), float(ex1[0]["radius"])])
	sys.queue_free()


# ── [4] 🔴🔴 심장 — 응축은 폭발의 **반대**다. **단조성**으로, **라이브 경로**로 잰다 ──
# ⚠ 대소 비교만으로는 **부호 뒤집기 뮤테이션을 못 잡는다**: 폭발 계수(0.18)가 응축 계수(0.12)보다
# 커서, 응축 부호를 뒤집어도(54×1.24=66.96) 폭발(73.44)보다 여전히 작아 그린이 된다.
# 그래서 **값이 아니라 방향**을 잰다 — 튜닝에도 안 부서지고 부호가 뒤집히면 즉시 빨개진다.
#
# 🔴🔴 **층(8칸)만 넘긴다 — def를 손으로 넘기지 않는다.** 직접 넘기면 라이브 경로
# (`_apply_layer` → `_apply_modifier` → `Db.glyph_by_code(code)` 조회)가 def를 잃어도 전부 그린이다.
# 지금은 조회가 죽으면 params가 통째로 0이 되어 반경·세기 방향이 무너지고 여기가 빨개진다.
func _t4_condense_is_the_opposite_of_explode() -> void:
	print("[4] 🔴 응축 = 좁게 모아 세게 (폭발의 반대) — 단조성 · **라이브 경로**")
	var sys = _Sys.new()
	root.add_child(sys)
	var s: int = Enums.GlyphCode.SPREAD
	var e: int = Enums.GlyphCode.EXPLODE
	var c: int = Enums.GlyphCode.CONDENSE

	# 🔴 확산 3칸이 먼저 걸려 갈래 3개를 만들고(변형형 순서 = code 오름차순) 그 위를 폭발/응축이 감싼다.
	#   = 실게임에서 「확산 안쪽, 폭발 바깥쪽」 층을 그린 것과 같은 명령이 나온다.
	var cd1 := _blast_of(sys, [c, -1, -1, -1, -1, -1, -1, -1])
	var cd3 := _blast_of(sys, [s, s, s, c, -1, -1, -1, -1])
	var ex1 := _blast_of(sys, [e, -1, -1, -1, -1, -1, -1, -1])
	var ex3 := _blast_of(sys, [s, s, s, e, -1, -1, -1, -1])
	if cd1.is_empty() or cd3.is_empty() or ex1.is_empty() or ex3.is_empty():
		sys.queue_free()
		return
	_check(float(cd3["radius"]) < float(cd1["radius"]),
		"🔴 응축은 갈래가 늘수록 **좁아진다** (%.1f < %.1f)" % [float(cd3["radius"]), float(cd1["radius"])])
	_check(float(ex3["radius"]) > float(ex1["radius"]),
		"🔴 폭발은 갈래가 늘수록 **넓어진다** — 대조군 (%.1f > %.1f)"
			% [float(ex3["radius"]), float(ex1["radius"])])

	# 위력: 응축은 융합에 **이득**, 폭발은 **손실** (같은 안쪽을 감쌌을 때)
	_check(float(cd3["mult"]) > float(ex3["mult"]),
		"🔴 응축이 폭발보다 세다 (%.2f > %.2f — 좁게 모은 대가)"
			% [float(cd3["mult"]), float(ex3["mult"])])

	# 🔴 **확산의 `params`도 라이브 경로로 도착하나** — 부채각(fan_deg)과 갈래 세기(branch_mult)는
	# 명령 목록에서 바로 보인다. def 조회가 죽으면 각도가 전부 같아지고 세기 합이 0이 된다.
	var fan: Array = sys._apply_layer([], [s, s, s, -1, -1, -1, -1, -1], 0.0)
	_check(fan.size() == 3, "확산 3칸 → 갈래 3개 (실제 %d)" % fan.size())
	if fan.size() == 3:
		_check(not is_equal_approx(float(fan[0]["angle"]), float(fan[2]["angle"])),
			"🔴 갈래 각도가 벌어진다 (fan_deg가 라이브 경로로 도착했다)")
		var total := 0.0
		for cmd: Dictionary in fan:
			total += float(cmd["mult"])
		_check(total > 1.0,
			"🔴 갈래 세기 합이 1.0을 넘는다 (%.2f — branch_mult가 도착했다·안 넘으면 그릴 이유가 없다)" % total)
	sys.queue_free()


## 층 하나를 **라이브 경로**(`_apply_layer`)로 흘려 유일한 blast 명령을 꺼낸다.
## 🔴 def를 넘기지 않는 게 요점이다 — `_apply_modifier`가 스스로 `Db.glyph_by_code`로 찾아야 한다.
func _blast_of(sys, layer: Array) -> Dictionary:
	var plan: Array = sys._apply_layer([], layer, 0.0)
	if plan.size() != 1 or StringName((plan[0] as Dictionary).get("kind", &"")) != &"blast":
		_check(false, "층 %s → blast 명령 하나가 나와야 한다 (실제 %d개)" % [str(layer), plan.size()])
		return {}
	return plan[0] as Dictionary


# ── [5] `merge_mult_per_count` 훅이 실제 경로에 걸린다 ──
# ⚠ count=1이면 `per_count·(count-1)`이 0이라 훅이 **아예 안 쓰인다** — 그 케이스만 재면
# 훅을 통째로 무력화해도 그린이다. 그래서 응축 고리를 count=2로 냈다.
func _t5_merge_mult_per_count_is_on_the_path() -> void:
	print("[5] 많이 그릴수록 세진다 (count가 위력에 붙는다)")
	var sys = _Sys.new()
	root.add_child(sys)
	var cd = _db.glyph_by_code(Enums.GlyphCode.CONDENSE)
	var one: Array = [{"kind": &"bolt", "angle": 0.0, "offset": Vector2.ZERO, "mult": 1.0, "effects": {}}]
	var m1 := float((sys._explode(one, 1, cd)[0] as Dictionary)["mult"])
	var m2 := float((sys._explode(one, 2, cd)[0] as Dictionary)["mult"])
	_check(m2 > m1, "응축 2칸이 1칸보다 세다 (%.2f > %.2f)" % [m2, m1])
	# 콘텐츠가 실제로 그 훅을 밟는지 — 고리가 count=1이면 이 그물이 자명 통과가 된다
	var gr = _db.get_glyph_ring(&"gr_condense2")
	_check(gr != null and int(gr.count) >= 2,
		"gr_condense2의 count ≥ 2 (실제 %d — 1이면 훅이 게임에서 한 번도 안 밟힌다)"
			% (int(gr.count) if gr != null else -1))
	sys.queue_free()


# ── [6] 🔴 응축이 **새 알고리즘 없이** 돈다 = 데이터화가 실제로 작동한다는 증명 ──
func _t6_condense_needs_no_new_algorithm() -> void:
	print("[6] 🔴 응축 = 폭발과 같은 알고리즘, .tres 한 장")
	var cd = _db.glyph_by_code(Enums.GlyphCode.CONDENSE)
	var ex = _db.glyph_by_code(Enums.GlyphCode.EXPLODE)
	_check(cd != null and ex != null and cd.behavior == ex.behavior,
		"응축과 폭발이 **같은 behavior**(blast)를 쓴다 — 새 함수를 만들었으면 여기가 갈라진다")
	_check(_GR.BEHAVIORS.size() == 4,
		"알고리즘은 4종뿐 (실제 %d — 문양이 늘 때마다 늘면 데이터화가 실패한 것)" % _GR.BEHAVIORS.size())


# ── [7] 미등록 code = 경고+건너뜀 · 🔴 빈 칸(-1)은 **경고 대상이 아니다** ──
# ⚠ 경고 자체는 `-s`가 못 잰다 — 그래서 **관측 가능한 성질**(명령 목록)로 잰다.
func _t7_unknown_code_skipped_empty_is_silent() -> void:
	print("[7] 미등록 code는 건너뛴다 · 빈 칸은 조용하다")
	var sys = _Sys.new()
	root.add_child(sys)
	var radiate: int = Enums.GlyphCode.RADIATE
	# 발산 2칸 + 미등록(99) 1칸 + 나머지 빈 칸 → 탄은 **2발**만
	var layer: Array = [radiate, radiate, 99, -1, -1, -1, -1, -1]
	var plan: Array = sys._apply_layer([], layer, 0.0)
	_check(plan.size() == 2,
		"미등록 code가 든 칸만 빠진다 (명령 %d개 — 3이면 미등록이 탄이 됐고, 0이면 층이 통째로 죽었다)"
			% plan.size())
	# 빈 칸만 있는 층 = 명령 0, 에러 없음
	_check(sys._apply_layer([], [-1, -1, -1, -1, -1, -1, -1, -1], 0.0).is_empty(),
		"빈 층은 명령 0 (빈 칸을 경고 대상으로 만들면 발사마다 경고가 폭탄이 된다)")

	# 🔴🔴 **계열 분기가 실제로 `_apply_layer`를 지난다** — 이 항목이 없으면 `glyph_behavior`를
	# 통째로 `bolt`로 되돌려도 **그물이 전부 그린이다**(뮤테이션 실측).
	# 폭발 칸만 있는 층 → 씨앗을 감싼 **blast 하나**. 계열이 무너지면 **bolt 3발**이 된다.
	var e: int = Enums.GlyphCode.EXPLODE
	var blast_plan: Array = sys._apply_layer([], [e, e, e, -1, -1, -1, -1, -1], 0.0)
	_check(blast_plan.size() == 1 and (blast_plan[0] as Dictionary)["kind"] == &"blast",
		"🔴 폭발 칸만 있는 층 → blast 명령 **1개** (실제 %d개·kind=%s — bolt면 계열 판별이 죽었다)"
			% [blast_plan.size(), str((blast_plan[0] as Dictionary)["kind"]) if not blast_plan.is_empty() else "없음"])
	# 응집도 같은 자리 — pillar가 bolt로 무너지면 8발이 나간다
	var g: int = Enums.GlyphCode.GATHER
	var pil: Array = sys._apply_layer([], [g, g, -1, -1, -1, -1, -1, -1], 0.0)
	_check(pil.size() == 1 and (pil[0] as Dictionary)["kind"] == &"pillar",
		"응집 2칸 → pillar 명령 1개 (실제 %d개)" % pil.size())
	sys.queue_free()


# ── [8] code 중복 = **결정적 승자** (로드 순서에 기대지 않는다) ──
func _t8_duplicate_code_deterministic_winner() -> void:
	print("[8] code 중복 시 id 사전순으로 결정된다")
	var a := GlyphDef.new(); a.id = &"aaa_dup"; a.code = 6; a.behavior = &"bolt"
	var z := GlyphDef.new(); z.id = &"zzz_dup"; z.code = 6; z.behavior = &"pillar"
	# ⚠ 주입 순서가 곧 검출력이다 — **사전순 승자와 삽입순 승자가 갈리게** 넣어야 한다.
	# (aaa를 나중에 넣으면 덮어쓰기 버그에서도 aaa가 이겨 그물이 자명 통과한다. 실측으로 확인.)
	_db.glyphs[&"aaa_dup"] = a
	_db.glyphs[&"zzz_dup"] = z
	_db.reindex_glyphs()
	var win = _db.glyph_by_code(6)
	_check(win != null and win.id == &"aaa_dup",
		"id 사전순으로 앞선 쪽이 이긴다 (실제 %s — 덮어쓰기면 마지막 로드가 이겨 실행마다 흔들린다)"
			% (String(win.id) if win != null else "null"))
	_check(_db.glyphs.has(&"zzz_dup"), "진 쪽도 id 사전(glyphs)엔 그대로 남는다")
	_db.glyphs.erase(&"aaa_dup")
	_db.glyphs.erase(&"zzz_dup")
	_db.reindex_glyphs()
	_check(_db.glyph_by_code(6).id == &"spread", "뒷정리 후 원래 확산이 돌아온다")


# ── [9] 주입 후 `reindex_glyphs()`가 역인덱스를 갱신한다 ──
# 🔴 테스트 관행이 in-memory 주입(`db.glyphs[...] = ...`)인데 **아무도 reload()를 안 부른다.**
# 안 부른다.** 역인덱스를 reload()에서만 채우면 주입한 def가 안 보여 **그물이 자명 통과한다.**
func _t9_reindex_after_injection() -> void:
	print("[9] in-memory 주입 → reindex로 보인다")
	var inj := GlyphDef.new(); inj.id = &"zz_probe"; inj.code = 77; inj.behavior = &"spread"
	_db.glyphs[&"zz_probe"] = inj
	_check(_db.glyph_by_code(77) == null, "주입만으론 역인덱스에 안 들어간다 (명시 갱신이 계약)")
	_db.reindex_glyphs()
	_check(_db.glyph_by_code(77) != null, "reindex_glyphs() 후 보인다")
	_check(77 in _db.modifier_codes(), "주입한 변형형이 modifier_codes에도 반영된다")
	_db.glyphs.erase(&"zz_probe")
	_db.reindex_glyphs()
	_check(_db.glyph_by_code(77) == null, "뒷정리")


# ── [10] 🔴 같은 층 안에서 **배치 순서는 결과를 안 바꾼다** ──
# 층이 곧 순서라 층 **내부**는 "동시"로 봐야 한다. 변형형 적용 순서가 배치(칸 위치)에 좌우되면
# 같은 도안이 어디에 놓았느냐로 다르게 나간다.
func _t10_placement_order_does_not_matter() -> void:
	print("[10] 같은 층 내 배치 순서 무관")
	var sys = _Sys.new()
	root.add_child(sys)
	var s: int = Enums.GlyphCode.SPREAD
	var e: int = Enums.GlyphCode.EXPLODE
	var p1: Array = sys._apply_layer([], [s, e, -1, -1, -1, -1, -1, -1], 0.0)
	var p2: Array = sys._apply_layer([], [e, s, -1, -1, -1, -1, -1, -1], 0.0)
	_check(p1.size() == p2.size(), "명령 수가 같다 (%d vs %d)" % [p1.size(), p2.size()])
	var same := p1.size() == p2.size()
	if same:
		for i in p1.size():
			var a: Dictionary = p1[i]
			var b: Dictionary = p2[i]
			if a["kind"] != b["kind"] or not is_equal_approx(float(a["mult"]), float(b["mult"])):
				same = false
	_check(same, "🔴 확산·폭발을 어느 칸에 놓든 같은 결과 (다르면 도안이 자리로 흔들린다)")
	sys.queue_free()


# ── [11] 반경이 **거꾸로 커지지 않는다** (부호 함정) ──
# 응축은 두 계수가 둘 다 음수라, 인자별 클램프가 없으면 두 인자가 동시에 음수일 때 곱이
# **양수로 되살아나** 최종 하한을 통과한다. 지금 값에선 안 터지지만 F5 튜닝 한 번이면 뒤집힌다.
func _t11_radius_never_inverts() -> void:
	print("[11] 계수를 세게 음수로 줘도 반경이 거꾸로 안 커진다")
	var sys = _Sys.new()
	root.add_child(sys)
	var evil := GlyphDef.new()
	evil.id = &"zz_evil"; evil.code = 78; evil.behavior = &"blast"
	evil.params = {"radius_per_branch": -0.9, "radius_per_count": -0.9, "min_radius_px": 12.0}
	var one: Array = [{"kind": &"bolt", "angle": 0.0, "offset": Vector2.ZERO, "mult": 1.0, "effects": {}}]
	var many: Array = sys._spread(one, 4, _db.glyph_by_code(Enums.GlyphCode.SPREAD))
	var r_small := float((sys._explode(one, 1, evil)[0] as Dictionary)["radius"])
	var r_big := float((sys._explode(many, 8, evil)[0] as Dictionary)["radius"])
	_check(r_big <= r_small,
		"음수 계수에서도 갈래·칸이 늘면 반경이 안 커진다 (%.1f ≤ %.1f)" % [r_big, r_small])
	# 🔴 **두 인자가 동시에 음수**일 때 곱이 양수로 되살아나는 자리 — 인자별 클램프가 없으면
	# 여기서 반경이 폭발한다(음수 × 음수 = 양수라 최종 하한을 **통과해 버린다**).
	var both := float((sys._explode(many, 8, evil)[0] as Dictionary)["radius"])
	_check(both < 54.0,
		"두 인자가 동시에 음수여도 반경이 기본값을 안 넘는다 (%.1f — 넘으면 부호 구멍)" % both)
	_check(r_big >= 12.0, "반경 하한이 지켜진다 (실제 %.1f)" % r_big)
	sys.queue_free()


# ── [12] 🔴 UI 표현도 데이터에서 온다 ──
# 옛 `RingBoard.GLYPH_NAMES`/`GLYPH_COLORS` 배열은 **길이가 계약**이라, 어휘를 늘리며 배열을 안
# 늘리면 요약이 런타임 에러를 내고 `clampi`가 **응축을 골랐는데 폭발 밑그림을 띄웠다**(에러 없음).
# 재는 건 **색의 정본이 `.tres`인가** 하나 — **전 9값 전수**로 잰다(한 값만 보면 배열 폴백이
# 되살아나 8개가 어긋나도 그린이다).
func _t12_ui_reads_names_from_data() -> void:
	print("[12] 🔴 문양 색의 정본 = GlyphDef.ui_color (전 9값 전수)")
	var b = _Board.new()
	b.size = Vector2(268, 268)
	root.add_child(b)
	b.call(&"set_defs", null, [], _db.all_glyphs())
	var mismatched: Array = []
	for code in Enums.GlyphCode.values():
		var gd = _db.glyph_by_code(int(code))
		if gd == null:
			mismatched.append("code %d = Db 미등록" % int(code))
			continue
		if b.call(&"glyph_color_of", int(code)) != gd.ui_color:
			mismatched.append("code %d" % int(code))
	_check(mismatched.is_empty(),
		"문양 %d종 전부 색 = GlyphDef.ui_color (어긋난 것: %s)"
			% [Enums.GlyphCode.values().size(), str(mismatched)])
	# 🔴 검출력 대조 — defs를 안 주입하면 **중립 먹선으로 떨어진다**(옛 배열 폴백을 되살리지 않는다).
	# 이게 없으면 `glyph_color_of`가 늘 같은 색을 돌려줘도 위 검사가 그린일 수 있다.
	var bare = _Board.new()
	bare.size = Vector2(268, 268)
	root.add_child(bare)
	var cd = _db.glyph_by_code(Enums.GlyphCode.CONDENSE)
	_check(bare.call(&"glyph_color_of", Enums.GlyphCode.CONDENSE) != cd.ui_color,
		"defs 미주입 = 중립 폴백 (색이 .tres에서 온다는 증거)")
	bare.queue_free()
	b.queue_free()


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  OK: %s" % label)
	else:
		failures += 1
		print("  FAIL: %s" % label)
