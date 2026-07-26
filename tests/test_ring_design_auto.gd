extends SceneTree
## 고리 도안(RingDesign) + 장착 배선 자동 검증 (#17 1단계, 세션 16) — 헤드리스:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_design_auto.gd
## 전 항목 통과 시 "TEST_RING_DESIGN_OK".
##
## 검증: (1) RingDesign.from_assembly↔to_assembly 라운드트립·filled_count,
##   (2) EventBus.ring_design_committed → GameState.ring_equipped 자동 장착(첫 진=슬롯 1),
##   (3) 빈 슬롯 소진(4장까지 장착, 5장째는 보관만),
##   (4) 🔴 **슬롯 교체**(세86 ① — `GameState.equip_design` + `tab_panel` 마법진 탭 판정):
##       보관 도안을 슬롯에 올리기·중복 장착 없음·보관 밖 거부·null 해제·저장 라운드트립,
##       그리고 좌표→행 판정과 「클릭 한 번」이 core로 이어지는가.
##       ⚠ **클릭이 실제로 닿는지·강조가 보이는지는 여기서 못 잰다** — 실게임 push_input·MCP 몫.
##
## 주의: -s 스크립트는 오토로드 전역 등록 전에 컴파일 — 오토로드는 root.get_node(), RingDesign은 load().

var _fails: int = 0
var gs: Node      # GameState
var eb: Node      # EventBus
var RD: GDScript  # ring_design.gd


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		_fails += 1
		print("FAIL: ", label)


func _run() -> void:
	# 🔴 워치독 (세84 감사 #44) — `_run`이 중간에 죽으면 `-s` 프로세스가 **영구 hang**한다
	# (다른 22종엔 있었고 이 파일에만 없었다). 여기서 죽는 건 곧 계약 위반이므로 종료 코드 1.
	create_timer(30.0).timeout.connect(func() -> void:
		print("TEST_RING_DESIGN_TIMEOUT — 30초 초과")
		quit(1))
	gs = root.get_node(^"GameState")
	eb = root.get_node(^"EventBus")
	RD = load("res://src/core/schemas/ring_design.gd")

	_test_roundtrip()
	_test_auto_equip()
	_test_slot_fill()
	_test_score_carries()
	_test_ink_carries()
	_test_paper_size()
	_test_special_ink()
	_test_recipes()
	_test_power_rule()
	_test_assembled_score_axis()
	_test_grade_bands()
	_test_grade_follows_threshold()
	_test_slot_swap()
	_test_slot_swap_ui()
	_test_hud_follows_equipment()
	_test_slot_swap_persists()

	if _fails == 0:
		print("TEST_RING_DESIGN_OK")
	else:
		print("TEST_RING_DESIGN_FAILED: ", _fails)
	quit(mini(_fails, 125))


## 타입 배열(Array[RingDesign])은 무형 리터럴로 재대입할 수 없다 — clear()·원소 대입으로 비운다.
func _reset_ring_state() -> void:
	gs.ring_designs.clear()
	for i in gs.ring_equipped.size():
		gs.ring_equipped[i] = null


## 🔴 손그림 점수가 assembly ↔ RingDesign 사이를 **양방향으로** 건넌다 (세션 23).
## 끊기면 조립대에서 잘 그린 진이 장착·재발사 때 조용히 기준 위력이 된다.
func _test_score_carries() -> void:
	var a := _sample_assembly()
	a["score"] = 0.9
	# 점수를 명시 안 하면 assembly가 실어 온 값을 쓴다 (base.gd가 이 형태로 부른다)
	var d = RD.from_assembly(a, "잘 그린 진")
	_check(is_equal_approx(float(d.total_score), 0.9), "assembly.score → total_score 자동 승계")
	# 되돌릴 때도 실린다 — 저장해 둔 도안을 다시 쏴도 그때 그 위력이 나온다
	_check(is_equal_approx(float(d.to_assembly().get("score", -1.0)), 0.9),
		"to_assembly가 score를 다시 싣는다")
	# 명시 인자가 이긴다 (테스트·특수 경로)
	var d2 = RD.from_assembly(a, "덮어쓴 진", 0.5)
	_check(is_equal_approx(float(d2.total_score), 0.5), "명시 score가 assembly.score를 이긴다")
	# 점수 없는 옛 assembly → 0.0 (터지지도 0 피해도 아닌, 그냥 없음)
	var d3 = RD.from_assembly(_sample_assembly(), "옛 진")
	_check(is_equal_approx(float(d3.total_score), 0.0), "score 없는 assembly는 0.0")


## 🔴 잉크 등급(세션29, 사용자: "등급=데미지") = 데미지 배수.
## 도안↔assembly 라운드트립 + **위력에 곱해진다**. 끊기면 골라도 위력이 안 바뀐다(세션28 상태로 회귀).
func _test_ink_carries() -> void:
	var RP: GDScript = load("res://src/core/ring_power.gd")
	# 🔴 오토로드는 **런타임 조회**로 잡는다 (컴파일 타임 `Db` 참조 = -s 함정, CLAUDE.md).
	var db: Node = root.get_node(^"Db")

	# 리졸버는 한 곳뿐(Db.ink_mult) — 발사·리포트·HUD가 전부 이걸 부른다. 잉크 없음/미등록 = 1.0.
	_check(is_equal_approx(db.ink_mult(&""), 1.0), "잉크 없음 = 배수 1.0 (맨손)")
	_check(is_equal_approx(db.ink_mult(&"없는잉크"), 1.0), "미등록 잉크 = 배수 1.0")
	_check(db.ink_mult(&"ink_high") > db.ink_mult(&"ink_basic"),
		"상급 잉크 배수 > 기본 잉크 배수 (.tres가 정한다)")

	# assembly에 실린 잉크가 도안을 왕복한다 — 저장한 도안이 잉크를 기억해야 그때 그 위력이 난다
	var a := _sample_assembly()
	a["ink"] = &"ink_high"
	var d = RD.from_assembly(a, "붉은 진")
	_check(StringName(d.ink) == &"ink_high", "assembly.ink → RingDesign.ink")
	_check(StringName(d.to_assembly().get("ink", &"")) == &"ink_high",
		"to_assembly가 ink를 다시 싣는다")

	# 잉크 없는 옛 assembly → 빈 잉크 → 배수 1.0 (하위 호환)
	var old = RD.from_assembly(_sample_assembly(), "옛 진")
	_check(StringName(old.ink) == &"", "잉크 없는 옛 assembly = 빈 잉크")
	_check(is_equal_approx(db.ink_mult(old.ink), 1.0), "빈 잉크 도안 = 배수 1.0")

	# 🔴 위력에 실제로 곱해진다 — 같은 점수라도 상급 잉크가 더 세다
	var s := 0.9
	_check(RP.power_of(s, db.ink_mult(&"ink_high")) > RP.power_of(s, 1.0),
		"같은 점수라도 상급 잉크가 위력이 세다 (등급=데미지)")
	_check(RP.power_display(s, db.ink_mult(&"ink_high")) > RP.power_display(s),
		"표시 위력도 잉크에 따라 오른다")
	# 조합 규칙 = core 한 곳(곱셈)
	_check(is_equal_approx(RP.power_of(s, 2.0), RP.power_of(s) * 2.0),
		"위력 = 손그림 위력 × 잉크 배수 (곱셈)")


## 🔴 종이 = 규모 (세션29, 사용자 확정). 종이 등급이 확대 상한을 올리고, 큰 진일수록 위력이 세다.
func _test_paper_size() -> void:
	var RP: GDScript = load("res://src/core/ring_power.gd")
	var db: Node = root.get_node(^"Db")
	# 종이 등급 → 확대 상한
	_check(db.paper_zoom_max(&"paper_high", 1.16) > db.paper_zoom_max(&"paper_basic", 1.16),
		"고급 종이 확대 상한 > 기본 종이")
	_check(is_equal_approx(db.paper_zoom_max(&"", 1.16), 1.16), "종이 없음 = 폴백 상한")
	_check(is_equal_approx(db.paper_zoom_max(&"없는종이", 9.0), 9.0), "미등록 종이 = 폴백")
	# 크기 → 데미지
	_check(is_equal_approx(RP.size_mult(1.0), 1.0), "기본 크기 = 배수 1.0 (제동 없음)")
	_check(RP.size_mult(2.0) > RP.size_mult(1.0), "큰 진일수록 배수 크다")
	_check(RP.power_of(0.9, 1.0, 2.0) > RP.power_of(0.9, 1.0, 1.0),
		"같은 점수·잉크라도 큰 진이 위력 세다 (종이=규모)")
	# 라운드트립
	var a := _sample_assembly()
	a["size"] = 1.6
	var d = RD.from_assembly(a, "큰 진")
	_check(is_equal_approx(float(d.size), 1.6), "assembly.size → RingDesign.size")
	_check(is_equal_approx(float(d.to_assembly().get("size", -1.0)), 1.6), "to_assembly size 라운드트립")


## 🔴 특별잉크 = 화상 증폭 (세션29, 사용자 확정). 잉크 등급(=데미지)과 다른 축.
func _test_special_ink() -> void:
	var db: Node = root.get_node(^"Db")
	_check(db.ink_is_special(&"ink_fire_red"), "붉은 잉크 = 특별잉크 (소모·효과)")
	_check(not db.ink_is_special(&"ink_basic"), "기본 잉크 = 특별잉크 아님 (무한)")
	# 화상 증폭 = **얼마나 특별잉크로 그렸나**(ratio)에 비례 — 전부>절반>안 씀(1.0)
	var full: float = db.status_mult_of(&"ink_fire_red", 1.0)
	var half: float = db.status_mult_of(&"ink_fire_red", 0.5)
	_check(full > half and half > 1.0, "화상 증폭이 비율에 비례 (전부>절반>1.0)")
	_check(is_equal_approx(db.status_mult_of(&"", 1.0), 1.0), "특별잉크 없음 = 증폭 1.0")
	_check(is_equal_approx(db.status_mult_of(&"ink_fire_red", 0.0), 1.0), "비율 0 = 증폭 1.0 (맨손 화상)")
	# 라운드트립
	var a := _sample_assembly()
	a["special_ink"] = &"ink_fire_red"
	a["special_ratio"] = 0.75
	var d = RD.from_assembly(a, "화상 진")
	_check(StringName(d.special_ink) == &"ink_fire_red", "assembly.special_ink → 도안")
	_check(is_equal_approx(float(d.special_ratio), 0.75), "special_ratio 라운드트립")
	_check(StringName(d.to_assembly().get("special_ink", &"")) == &"ink_fire_red",
		"to_assembly가 special_ink를 다시 싣는다")


## 🔴 정제 레시피 = 데이터 (세션29). 정제대가 GameState.spend+add_item으로 재료→결과.
func _test_recipes() -> void:
	var db: Node = root.get_node(^"Db")
	var r = db.get_recipe(&"refine_red_ink")
	_check(r != null, "정제 레시피가 로드된다 (Db.recipes)")
	if r == null:
		return
	_check(StringName(r.output_id) == &"ink_fire_red", "붉은잉크 정제 결과 = ink_fire_red")
	_check(int(r.inputs.get(&"mat_slime_core", 0)) == 3, "재료 = 슬라임핵 3")
	_check(db.all_recipes().size() >= 3, "레시피 3종 이상 (잉크 정제 + 종이 제작)")
	# 제작 흐름 = 재료 소비 + 결과 지급 (정제대 _craft가 쓰는 GameState 경로)
	gs.inventory.clear()
	gs.add_item(&"mat_slime_core", 3)
	_check(gs.can_afford(r.inputs), "재료 3개면 만들 수 있다")
	_check(gs.spend(r.inputs), "spend 성공 (재료 차감)")
	gs.add_item(r.output_id, r.output_count)
	_check(gs.get_count(&"ink_fire_red") == 1, "제작 결과 = 붉은잉크 1")
	_check(gs.get_count(&"mat_slime_core") == 0, "재료 소진")
	_check(not gs.can_afford(r.inputs), "재료 없으면 다시 못 만든다")
	gs.inventory.clear()


## 🔴 펑/위력 규칙 — 조립 리포트와 발사가 **같은 함수**를 본다. 경계는 "이하면 터진다".
func _test_power_rule() -> void:
	var RP: GDScript = load("res://src/core/ring_power.gd")
	var t: float = RP.threshold()
	_check(not RP.is_stable(t), "기준선 정확히 = 터진다 (사용자: 65퍼 '이하'면 터지고)")
	_check(not RP.is_stable(t - 0.01), "기준선 아래 = 터진다")
	_check(RP.is_stable(t + 0.01), "기준선 위 = 견딘다")
	_check(RP.is_stable(1.0), "만점 = 견딘다")
	# 위력은 점수에 대해 단조 증가 — "높을수록 성능이 좋아"(사용자)
	_check(RP.power_of(1.0) > RP.power_of(0.8), "만점이 80점보다 세다")
	_check(RP.power_of(0.8) > RP.power_of(t + 0.01), "80점이 기준선 언저리보다 세다")
	_check(RP.power_display(1.0) > 100, "만점 표시 위력 > 기준 100")

	# 🔴 **미달 구간에 평평한 곳이 없다** (세션 23 사용자 확정: 주입 전에 안내 금지).
	# 리포트가 주입 전에 위력을 보여 주므로, 미달 구간이 한 값에 붙어 버리면 그 평평함이
	# "너 지금 미달"이라는 안내가 된다. 예전 선형+clamp 곡선이 정확히 이랬다(20점·64점 둘 다 "위력 70").
	_check(RP.power_of(0.20) < RP.power_of(0.40), "20점 < 40점 (미달 구간도 이어진다)")
	_check(RP.power_of(0.40) < RP.power_of(0.64), "40점 < 64점 (미달 구간도 이어진다)")
	_check(RP.power_display(0.20) != RP.power_display(0.64),
		"20점과 64점의 표시 위력이 다르다 — 평평하면 그게 곧 안내다")
	# 기준선을 걸쳐도 값이 튀지 않는다 — 경계가 숫자로 드러나면 그것도 안내다
	_check(RP.power_of(t + 0.01) - RP.power_of(t - 0.01) < 0.1,
		"기준선 앞뒤로 위력이 매끄럽다 (경계가 숫자로 안 보인다)")
	# 음수 피해 방지 — 점수는 0..1이지만 계약이 밀릴 수 있다
	_check(RP.power_of(0.0) >= 0.0 and RP.power_of(-1.0) >= 0.0, "위력은 음수가 되지 않는다")


## 🔴🔴 **조립 점수 = 폐지 이후 유일한 성장 축** (세84 감사 #3 — `RingPower.assembled_score`).
## 그전엔 `grep assembled_score tests/`가 **0건**이었다: `assemble_score_per_glyph`/`per_layer`를
## 0.0으로 내려도 **전 스위트가 그린**이라, 문양-고리를 몇 개 끼우고 2등급 진을 써도 점수·위력이
## 0.70에 굳는데 아무도 못 알아챈다 = **원정 보상이 전투에 영향을 안 준다**(그리기를 폐지한 뒤
## 위력이 오르는 길은 이 함수 하나뿐이다).
##
## ⚠ **수치를 박지 않는다** — 손맛 튜닝 한 번에 거짓 빨강이 되면 안 된다(세79 [4]·세82 [3] 관행).
##   대신 ①두 입력 각각에 대한 **단조성** ②`assemble_score_base > 기준선` 불변식(지금까진
##   `balance_data.gd` 주석에만 있었다) ③클램프·음수 방어로 잰다.
## ⚠ **단조성이어야 하는 이유**(세82 응축 교훈): 한 점 대소 비교는 **부호 뒤집기를 못 잡는다** —
##   계수를 음수로 내려도 다른 항이 커서 비교가 여전히 참이 되는 자리가 생긴다.
func _test_assembled_score_axis() -> void:
	var RP: GDScript = load("res://src/core/ring_power.gd")

	# ① 🔴 두 입력이 **각각 독립으로** 점수를 올린다 (한쪽만 살아 있어도 반쪽 죽음이다)
	_check(RP.assembled_score(0, 1) < RP.assembled_score(5, 1),
		"🔴 문양을 끼우면 점수가 오른다 (%.3f → %.3f — 같으면 per_glyph가 죽었다)"
			% [RP.assembled_score(0, 1), RP.assembled_score(5, 1)])
	_check(RP.assembled_score(0, 1) < RP.assembled_score(0, 2),
		"🔴 층이 깊어지면 점수가 오른다 (%.3f → %.3f — 같으면 per_layer가 죽었다)"
			% [RP.assembled_score(0, 1), RP.assembled_score(0, 2)])

	# 단조 — 클램프(1.0)에 닿기 전까지 **한 번도 안 꺾인다**. 문양 8칸 × 층 9겹이 현행 상한.
	var glyph_mono := true
	for k in 8:
		var lo: float = RP.assembled_score(k, 1)
		var hi: float = RP.assembled_score(k + 1, 1)
		if hi < lo or (lo < 1.0 and is_equal_approx(hi, lo)):
			glyph_mono = false
			_check(false, "문양 %d→%d에서 점수가 안 올랐다 (%.4f → %.4f)" % [k, k + 1, lo, hi])
			break
	if glyph_mono:
		_check(true, "문양 0~8칸 전 구간에서 점수가 단조 증가한다")
	var layer_mono := true
	for n in range(1, 9):
		var lo: float = RP.assembled_score(0, n)
		var hi: float = RP.assembled_score(0, n + 1)
		if hi < lo or (lo < 1.0 and is_equal_approx(hi, lo)):
			layer_mono = false
			_check(false, "층 %d→%d에서 점수가 안 올랐다 (%.4f → %.4f)" % [n, n + 1, lo, hi])
			break
	if layer_mono:
		_check(true, "층 1~9겹 전 구간에서 점수가 단조 증가한다 (진 등급 = 층 수, 상한 9)")

	# ② 🔴🔴 **불변식: 가장 초라한 조립본도 펑이 안 난다.** `assemble_score_base > ring_stability_min`은
	#   지금까지 `balance_data.gd` 주석에만 있던 규율이다 — 어기면 멀쩡히 조립하고도 「펑」이 나는데
	#   폐지 모드엔 그 펑을 만회할 수단(더 잘 긋기)이 **아예 없다**. 술어를 그대로 부른다(65를 안 베낀다).
	_check(RP.is_stable(RP.assembled_score(0, 1)),
		"🔴 진만 고른 최소 조립본도 기준선 위다 (%.3f > %.3f) — assemble_score_base > ring_stability_min"
			% [RP.assembled_score(0, 1), RP.threshold()])
	_check(RP.grade_of(RP.assembled_score(0, 1)) != "사용 불가",
		"최소 조립본의 등급이 「사용 불가」가 아니다 (등급·기준선은 한 술어다)")
	var all_stable := true
	for g in 9:
		for n in range(1, 10):
			if not RP.is_stable(RP.assembled_score(g, n)):
				all_stable = false
				_check(false, "문양 %d·층 %d 조립본이 펑 난다 (%.3f)" % [g, n, RP.assembled_score(g, n)])
				break
		if not all_stable:
			break
	if all_stable:
		_check(true, "🔴 어떤 조립본도 펑이 안 난다 (폐지 모드엔 펑이 없다 — 세83 심장 계약)")

	# ③ 척도·방어 — 손그림 점수와 **같은 0~1 척도**여야 위력·등급 함수가 그대로 돈다
	_check(RP.assembled_score(999, 999) <= 1.0,
		"점수가 1.0을 안 넘는다 (%.3f — 넘으면 위력·등급이 척도 밖으로 나간다)"
			% RP.assembled_score(999, 999))
	_check(is_equal_approx(RP.assembled_score(-3, -3), RP.assembled_score(0, 1)),
		"음수 입력은 0·1로 접힌다 (계약이 밀려도 점수가 내려가지 않는다)")
	# 위력 축까지 이어진다 — 점수만 오르고 위력이 안 오르면 「부품이 세게 만든다」가 거짓이 된다
	_check(RP.power_of(RP.assembled_score(5, 2)) > RP.power_of(RP.assembled_score(0, 1)),
		"🔴 좋은 부품이 실제로 **위력**을 올린다 (점수 축이 위력 축까지 이어진다)")


## 🔴 등급 구간 (세션 24, 사용자 확정: 65~75 무난 / 75~85 평타 / 85~95 괜찮음 /
## 95~100 완벽 / 100 퍼펙트 · 65 이하 = 사용 불가).
func _test_grade_bands() -> void:
	var RP: GDScript = load("res://src/core/ring_power.gd")
	_check(RP.grade_of(0.50) == "사용 불가", "50점 = 사용 불가")
	_check(RP.grade_of(0.65) == "사용 불가", "기준선 정확히 = 사용 불가 ('이하면 터진다'와 같은 경계)")
	_check(RP.grade_of(0.70) == "무난", "70점 = 무난")
	_check(RP.grade_of(0.80) == "평타", "80점 = 평타")
	_check(RP.grade_of(0.90) == "괜찮음", "90점 = 괜찮음")
	_check(RP.grade_of(0.97) == "완벽", "97점 = 완벽")
	_check(RP.grade_of(1.0) == "퍼펙트", "만점 = 퍼펙트")

	# 구간 경계는 "이상"이다 — 딱 걸친 점수가 위 칸으로 간다
	_check(RP.grade_of(0.75) == "평타", "75점은 평타(위 칸)")
	_check(RP.grade_of(0.85) == "괜찮음", "85점은 괜찮음(위 칸)")
	_check(RP.grade_of(0.95) == "완벽", "95점은 완벽(위 칸)")

	# 🔴 **퍼펙트 = 화면에 100으로 뜨는 순간** (사용자 확정).
	# ⚠ 반올림을 **여기서 다시 구현하지 않는다** — 그러면 UI가 쓰는 함수가 아니라 테스트가 베낀
	# 사본을 검증하게 돼, 정작 화면과 갈라지는 순간을 못 잡는다. UI와 같은 score_display를 부른다.
	for i in 60:
		var s := 0.98 + float(i) * 0.0005          # 98.0% ~ 100.95%
		var shown: int = RP.score_display(s)
		if RP.is_perfect(s) != (shown >= 100):
			_check(false, "퍼펙트와 화면 100이 어긋난다 (%.4f → %d점, perfect=%s)"
				% [s, shown, RP.is_perfect(s)])
			return
	_check(true, "퍼펙트 ⇔ 화면에 100으로 뜬다 (표시 반올림과 묶여 있다)")


## 🔴🔴 **「사용 불가」와 「펑」이 정확히 같은 경계다** — 세션 23 어긋남의 회귀 테스트.
## 그땐 등급이 자기 상수(55/75)를 들고 있어 「무난」(55~75)이 기준선 0.65를 걸쳤다 —
## **같은 "무난"이 터지기도 견디기도 했다**(61점=무난인데 펑). 등급이 기준선을 베껴 적는 순간
## 두 경계가 갈라지는데, 0~1 전 구간을 훑어 두 술어가 **한 번도 어긋나지 않음**을 못 박는다.
##
## ⚠ **balance를 런타임에 흔드는 방식으론 검증 못 한다** (세션 24에 시도했다가 알아냈다):
## GDScript는 static func 안의 `const BAL.프로퍼티`를 **컴파일 타임에 굳힌다** — `RP.BAL.x`를
## 0.8로 바꿔도 `RP.threshold()`는 옛 값을 돌려준다. 게임엔 무해하지만(수치를 런타임에 안 바꾼다)
## 테스트는 조용히 거짓 통과한다.
func _test_grade_follows_threshold() -> void:
	var RP: GDScript = load("res://src/core/ring_power.gd")
	for i in 201:
		var s := float(i) / 200.0                       # 0.000 ~ 1.000, 0.5점 간격
		var unusable: bool = RP.grade_of(s) == "사용 불가"
		if unusable != (not RP.is_stable(s)):
			_check(false, "%.1f점에서 등급과 펑 판정이 갈라졌다 (등급=%s, 견딤=%s)"
				% [s * 100.0, RP.grade_of(s), RP.is_stable(s)])
			return
	_check(true, "「사용 불가」 ⇔ 펑 — 0~100점 전 구간에서 경계가 한 번도 안 갈라진다")

	# 등급은 점수에 대해 단조다 — 더 잘 그렸는데 등급이 내려가면 안 된다
	var order := ["사용 불가", "무난", "평타", "괜찮음", "완벽", "퍼펙트"]
	var last := -1
	for i in 101:
		var idx: int = order.find(RP.grade_of(float(i) / 100.0))
		if idx < last:
			_check(false, "%d점에서 등급이 거꾸로 갔다 (%s)" % [i, RP.grade_of(float(i) / 100.0)])
			return
		last = idx
	_check(last == order.size() - 1, "0→100점을 훑으면 등급이 순서대로 올라 퍼펙트로 끝난다")


## 폴백 2방 [0,2]에 발산 하나 채운 assembly (rune=불 — 세션60: 열린 칸의 출처는 진, 이 딕셔너리는 스냅샷).
func _sample_assembly() -> Dictionary:
	# 8칸: 칸0=발산(1), 칸2=응집(0), 나머지 빈칸(-1). 열린 칸 = [0, 2]
	var ring := [1, -1, 0, -1, -1, -1, -1, -1]
	return {"ring_count": 1, "rune": 0, "rings": [ring], "open": [0, 2]}


func _test_roundtrip() -> void:
	var a := _sample_assembly()
	var d = RD.from_assembly(a, "시험진", 0.82)
	_check(d != null, "from_assembly가 RingDesign을 만든다")
	_check(String(d.display_name) == "시험진", "이름 전달")
	_check(is_equal_approx(float(d.total_score), 0.82), "종합 점수 저장")
	_check(int(d.filled_count()) == 2, "채운 칸 수 = 2 (발산·응집)")
	var back: Dictionary = d.to_assembly()
	_check(int(back.get("ring_count", 0)) == 1, "to_assembly ring_count=1")
	_check(int(back.get("rune", -1)) == 0, "룬 보존(불)")
	_check((back.get("rings", []) as Array)[0] == a.rings[0], "rings 라운드트립 일치")
	_check((back.get("open", []) as Array) == [0, 2], "open 라운드트립 일치")
	# 깊은 복사 확인 — 원본을 바꿔도 도안이 안 흔들린다
	a.rings[0][0] = -1
	_check(int(d.to_assembly().rings[0][0]) == 1, "from_assembly는 깊은 복사(원본 변경 무관)")


func _test_auto_equip() -> void:
	_reset_ring_state()
	var d = RD.from_assembly(_sample_assembly(), "첫 진")
	eb.ring_design_committed.emit(d)
	_check(gs.ring_designs.size() == 1, "보관고에 들어간다")
	_check(gs.ring_equipped[0] == d, "빈 슬롯 없으면 슬롯 1(index 0)에 자동 장착")
	_check(gs.ring_equipped[1] == null, "나머지 슬롯은 빈 채")


## 🔴🔴 **슬롯 교체** (세86 ① — `GameState.equip_design`).
## 세85까지 `ring_equipped`에 쓰는 자리는 시드·새로하기·로드·**빈 슬롯 자동 장착** 넷뿐이었다 =
## **슬롯이 한 번 차면 그 뒤에 맺은 도안은 영원히 못 쓴다**(세85 F5에서 보관 6장으로 실증 —
## "맺었는데 못 쓴다"). `_test_slot_fill`이 그 마지막 상태(꽉 참 → 보관만)를 이미 재고 있으므로
## 여기선 **그 다음 한 수**(꽂힌 걸 뽑고 보관 걸 올린다)를 잰다.
##
## ⚠ 도안 4장의 `total_score`를 서로 다르게 만든다 — 전부 `_sample_assembly()` 사본이라
## **내용이 같으면 「슬롯이 실제로 바뀌었나」를 구분할 수단이 없다**(둘 다 통과하는 자명 검사가 된다).
func _test_slot_swap() -> void:
	_reset_ring_state()
	var n: int = gs.EQUIP_SLOTS
	var made: Array = []
	for i in n + 1:
		var d = RD.from_assembly(_sample_assembly(), "교체진%d" % i, 0.70 + float(i) * 0.05)
		made.append(d)
		eb.ring_design_committed.emit(d)
	_check(not (made[n] in gs.ring_equipped),
		"사전: 슬롯이 꽉 차 %d장째는 보관만 (= 세85 F5가 실증한 그 상태)" % (n + 1))

	# ① 🔴 보관 도안을 슬롯에 올린다 — **발사가 실제로 바뀐다**가 계약이다.
	#    caster는 `GameState.ring_equipped[slot].to_assembly()`로 쏘므로, 그 결과가 새 도안이어야
	#    "바꿨는데 옛날 게 나간다"가 안 된다(score로 구분 — 네 도안의 점수가 서로 다르다).
	_check(gs.equip_design(0, made[n]), "보관 도안을 슬롯 1에 올린다 (true)")
	_check(gs.ring_equipped[0] == made[n], "슬롯 1 = 올린 그 도안")
	_check(is_equal_approx(float(gs.ring_equipped[0].to_assembly().get("score", -1.0)),
			float(made[n].total_score)),
		"🔴 to_assembly가 **바꾼 도안**을 내놓는다 (발사가 실제로 바뀐다)")
	_check(not (made[0] in gs.ring_equipped), "밀려난 옛 도안은 장착에서 빠진다")
	_check(gs.ring_designs.has(made[0]), "밀려난 도안은 보관에는 남는다 (잃지 않는다)")

	# ② 🔴 한 도안이 두 슬롯을 차지하지 않는다 — 앞 자리가 자동으로 빈다.
	#    안 그러면 `_unequipped_designs`(has 판정)와 저장(경로 참조)이 조용히 어긋난다.
	_check(gs.equip_design(n - 1, made[n]), "같은 도안을 슬롯 %d로 옮긴다" % n)
	_check(gs.ring_equipped[n - 1] == made[n], "슬롯 %d = 그 도안" % n)
	_check(gs.ring_equipped[0] == null, "🔴 앞 자리(슬롯 1)가 빈다 — 중복 장착 없음")
	var dupes := 0
	for d2 in gs.ring_equipped:
		if d2 == made[n]:
			dupes += 1
	_check(dupes == 1, "장착 배열에 그 도안이 정확히 하나 (%d개)" % dupes)

	# ③ 🔴 보관 밖 인스턴스는 거부 — 저장이 도안을 **파일 경로**로 참조하므로 꽂아도 다음 로드에
	#    빈 슬롯이 된다(에러 없이). 거부는 배열을 건드리지 않는다.
	var outsider = RD.from_assembly(_sample_assembly(), "보관 밖 진", 0.99)
	var before: Array = gs.ring_equipped.duplicate()
	_check(not gs.equip_design(1, outsider), "🔴 보관(ring_designs)에 없는 도안은 거부 (false)")
	_check(gs.ring_equipped.duplicate() == before, "거부 시 장착 배열 무변경")
	_check(not gs.equip_design(-1, made[1]), "슬롯 범위 밖(-1) 거부")
	_check(not gs.equip_design(n, made[1]), "슬롯 범위 밖(%d) 거부" % n)
	_check(gs.ring_equipped.duplicate() == before, "범위 밖 거부도 배열 무변경")

	# ④ null = 해제. 해제한 도안은 **보관 목록으로 돌아온다**(tab_panel `_unequipped_designs` 관점 =
	#    `ring_designs`에 있고 `ring_equipped`에 없다).
	_check(gs.equip_design(n - 1, null), "null로 해제 (true)")
	_check(gs.ring_equipped[n - 1] == null, "슬롯 %d가 빈다" % n)
	_check(gs.ring_designs.has(made[n]) and not gs.ring_equipped.has(made[n]),
		"🔴 해제한 도안이 보관 목록으로 돌아온다")


## 🔴 슬롯 교체 **UI 판정**(`tab_panel` 마법진 탭) — 좌표 → 어느 행인가 + 클릭 한 번의 결과.
## ⚠⚠ **헤드리스는 「클릭이 저기까지 닿는가」도 「그게 보이는가」도 못 잡는다**(세25 `mouse_filter`).
##   여기서 재는 것은 **판정 로직뿐**이다: rect를 어디에 두었고, 그 좌표를 누르면 core의 어느
##   함수가 불리는가. 실제 마우스가 그 rect까지 도달하는지·강조가 눈에 보이는지는 **리드가 실게임
##   `push_input`과 MCP 스샷으로** 따로 확인한다. (그래서 판정을 `magic_hit_test`/`magic_click`
##   공개 함수로 뽑았다 — 안 뽑으면 이 절이 통째로 못 재는 자리가 된다.)
func _test_slot_swap_ui() -> void:
	_reset_ring_state()
	var n: int = gs.EQUIP_SLOTS
	var made: Array = []
	for i in n + 2:
		var d = RD.from_assembly(_sample_assembly(), "UI진%d" % i, 0.70 + float(i) * 0.04)
		made.append(d)
		eb.ring_design_committed.emit(d)

	var TP: GDScript = load("res://src/hud/tab_panel.gd")
	var panel: Control = Control.new()
	panel.set_script(TP)
	panel.size = Vector2(960.0, 540.0)   # 뷰포트 = 패널이 스스로 가운데를 잡는 기준
	panel.current_tab = 2

	var layout: Dictionary = panel.magic_row_layout()
	var slots: Array = layout["slots"]
	var store: Array = layout["store"]
	var rest: Array = layout["store_designs"]
	_check(slots.size() == n, "레이아웃: 슬롯 행이 EQUIP_SLOTS개 (%d)" % slots.size())
	_check(rest.size() == 2, "레이아웃: 보관 도안 2장 (%d)" % rest.size())
	_check(store.size() == rest.size(), "보관 2장은 다 들어간다 (접힘 없음)")

	# 🔴 좌표 → 행 (그린 곳 = 누른 곳). 패널 밖 좌표는 아무 행도 아니다.
	var h0: Dictionary = panel.magic_hit_test((slots[0] as Rect2).get_center())
	_check(StringName(h0["kind"]) == &"slot" and int(h0["index"]) == 0, "슬롯 1 행 중앙 → slot 0")
	var h1: Dictionary = panel.magic_hit_test((store[1] as Rect2).get_center())
	_check(StringName(h1["kind"]) == &"store" and int(h1["index"]) == 1, "보관 둘째 행 중앙 → store 1")
	var hn: Dictionary = panel.magic_hit_test(Vector2(4.0, 4.0))
	_check(StringName(hn["kind"]) == &"none", "패널 밖 좌표 → none (유령 판정 없음)")
	# 🔴 행끼리 안 겹친다 — 겹치면 위 행을 누른 게 아래 행으로 새어 「엉뚱한 슬롯에 장착」이 된다
	var overlap := false
	for i in slots.size():
		for j in store.size():
			if (slots[i] as Rect2).intersects(store[j] as Rect2):
				overlap = true
	_check(not overlap, "🔴 슬롯 행과 보관 행이 안 겹친다")

	# ── 조작 한 바퀴: 보관 행 고르기 → 슬롯 행에 지정 ──
	# 🔴🔴 **UI가 `equip_design`을 거치는지까지 잰다.** 슬롯 값만 보면 `ring_equipped[slot]`에
	# **직접 대입**해도 똑같아 보여 계약 위반이 안 잡힌다(실측: 직접 대입 뮤테이션이 전 항목을
	# 통과했다). 갈라지는 자리는 **`equipment_changed` 발신**이다 — 저장 트리거(save_manager
	# `_queue_save`)와 중복 장착 정리가 거기 매달려 있어, 안 쏘면 **바꾼 슬롯이 저장 없이 사라진다.**
	var beats: Array = [0]
	var counter := func() -> void: beats[0] += 1
	eb.equipment_changed.connect(counter)
	var target = rest[0]
	_check(panel.magic_click((store[0] as Rect2).get_center()), "보관 행 클릭이 처리된다")
	_check(panel._picked == target, "보관 행 클릭 = 그 도안을 고른다 (선택 상태)")
	_check(beats[0] == 0, "고르기만 해서는 아무것도 안 바뀐다 (equipment_changed 무발신)")
	_check(panel.magic_click((slots[1] as Rect2).get_center()), "슬롯 행 클릭이 처리된다")
	_check(gs.ring_equipped[1] == target,
		"🔴 고른 도안이 슬롯 2에 올라간다 (UI 클릭 → GameState.equip_design 경로가 이어져 있다)")
	_check(beats[0] == 1,
		"🔴 UI 클릭이 equipment_changed를 정확히 1회 쏜다 (= 자동 저장 트리거 · 배열 직접 대입이면 0회)")
	_check(panel._picked == null, "지정하면 고르기가 풀린다")

	# 고른 게 없을 때 찬 슬롯 클릭 = 해제 (소지품 탭 「착용 슬롯 클릭 = 해제」와 같은 규약)
	var l2: Dictionary = panel.magic_row_layout()
	panel.magic_click(((l2["slots"] as Array)[1] as Rect2).get_center())
	_check(gs.ring_equipped[1] == null, "고른 게 없을 때 슬롯 클릭 = 해제")
	_check(beats[0] == 2, "해제도 equipment_changed를 쏜다 (%d회) — 해제만 저장에서 새면 다음 부팅에 되살아난다" % beats[0])
	eb.equipment_changed.disconnect(counter)

	# 같은 보관 행을 두 번 누르면 고르기 취소 (잘못 골랐을 때 빠져나갈 길)
	var l3: Dictionary = panel.magic_row_layout()
	var s3: Array = l3["store"]
	panel.magic_click((s3[0] as Rect2).get_center())
	_check(panel._picked != null, "보관 행 클릭 = 고름")
	panel.magic_click((s3[0] as Rect2).get_center())
	_check(panel._picked == null, "같은 행을 다시 누르면 고르기 취소")

	# 1·2·3 키가 클릭과 **같은 함수**로 들어간다(키 경로가 따로 굴러 갈라지지 않게)
	panel.magic_click((s3[0] as Rect2).get_center())
	panel.magic_assign(0)
	_check(gs.ring_equipped[0] == (l3["store_designs"] as Array)[0],
		"🔴 [1] 키 경로(magic_assign)도 같은 결과를 낸다")

	# 🔴🔴 **넘치면 rect를 아예 안 만든다** — 접힌 행에 판정을 남기면 **화면 밖 도안이 클릭으로
	# 장착되는** 유령 판정이 된다(소지품 격자의 세84 #35와 같은 병). 보관을 일부러 넘치게 만들어 잰다.
	_reset_ring_state()
	for i in 40:
		eb.ring_design_committed.emit(RD.from_assembly(_sample_assembly(), "넘침진%d" % i, 0.80))
	var big: Dictionary = panel.magic_row_layout()
	var brects: Array = big["store"]
	var bdesigns: Array = big["store_designs"]
	_check(brects.size() > 0 and brects.size() < bdesigns.size(),
		"보관이 넘치면 들어가는 만큼만 rect를 만든다 (%d/%d)" % [brects.size(), bdesigns.size()])
	var inside := true
	for r in brects:
		if (r as Rect2).end.y > float(big["bottom"]) + 0.01:
			inside = false
	_check(inside, "🔴 판정이 있는 보관 행은 전부 패널 아랫변 안이다 (화면 밖 유령 클릭 없음)")
	panel.free()


## 🔴 **슬롯을 갈아 끼우면 HUD가 따라오는가** — 세86 ①이 만든 새 필요.
## 세85까지 `ring_equipped`는 **맺을 때만** 바뀌었고 HUD는 `ring_design_committed`로 그걸 잡았다.
## 이제 Tab에서 언제든 갈아 끼우는데, `hud._process`의 redraw 조건은 마나 변화·토스트·안내문·돈뿐
## → **마나가 만땅이면 아무도 redraw를 안 걸어** 슬롯 미니 다이어그램이 바꾸기 전 진을 계속
## 보여 준다(= 세84 감사 T8 「쏘는 것 ≠ 보이는 것」). 실제로 그렇게 될 뻔했고, 이 그물이 그 자리다.
## ⚠ **「보인다」는 여기서 못 잰다** — 재는 것은 **다시 그릴 계기가 연결돼 있는가** 하나다
##   (`test_spell_vfx_auto`의 「배선 침묵사 그물」과 같은 규약). 눈 확인은 리드의 MCP 몫.
func _test_hud_follows_equipment() -> void:
	var hud: Control = Control.new()
	hud.set_script(load("res://src/hud/hud.gd"))
	root.add_child(hud)   # _ready가 EventBus에 붙는다
	var wired := false
	for c in eb.equipment_changed.get_connections():
		if (c["callable"] as Callable).get_object() == hud:
			wired = true
	_check(wired,
		"🔴 HUD가 equipment_changed에 연결돼 있다 (슬롯 교체가 화면에 반영될 계기 — 끊기면 T8 재발)")
	root.remove_child(hud)
	hud.free()


## 🔴 **저장 라운드트립** — 바꾼 슬롯 배치가 재부팅을 건넌다.
## 이게 없으면 "게임 안에선 바뀌는데 다시 켜면 원래대로"가 조용히 지나간다. `equip_design`이
## `equipment_changed`를 쏴 자동 저장이 걸리지만, 여기선 흐름을 확정하려고 직접 저장·로드한다.
## ⚠ 헤드리스는 세이브 뿌리가 `save_test`로 격리돼 있다(세59) — 실세이브를 안 건드린다. 끝에 뒷정리.
## ⚠ 로드는 도안을 **파일에서 새 인스턴스로** 되살린다 — 참조가 아니라 **이름으로** 대조해야 한다.
func _test_slot_swap_persists() -> void:
	var sm: Node = root.get_node(^"SaveManager")
	_reset_ring_state()
	var n: int = gs.EQUIP_SLOTS
	var made: Array = []
	for i in n + 1:
		var d = RD.from_assembly(_sample_assembly(), "저장진%d" % i, 0.70 + float(i) * 0.05)
		made.append(d)
		eb.ring_design_committed.emit(d)
	_check(gs.equip_design(0, made[n]), "교체: 보관 도안을 슬롯 1로")
	_check(gs.equip_design(1, null), "교체: 슬롯 2를 비운다")
	var want := _equipped_names()

	sm.save_game()
	_check(sm.has_save(), "저장 파일 생성")
	_reset_ring_state()
	_check(sm.load_game(), "로드 true")
	var got := _equipped_names()
	_check(got == want, "🔴 교체·해제한 슬롯 배치가 저장·로드를 건넌다 (%s → %s)" % [want, got])
	# 보관은 통째로 살아 있다 — 슬롯만 저장되고 나머지 도안이 증발하면 다음 교체가 불가능해진다
	_check(gs.ring_designs.size() == n + 1, "보관 %d장 전부 복원 (%d)" % [n + 1, gs.ring_designs.size()])
	sm.wipe_save()
	# 뒷정리 — 안 비우면 종료 시 "ObjectDB 누수" 줄이 늘어난다(도안이 오토로드에 매달린 채 끝난다).
	# 실패가 아니라 잡음이지만, 잡음이 늘면 진짜 누수를 눈으로 못 가른다.
	_reset_ring_state()


## 장착 슬롯의 도안 이름 배열 — 로드 후엔 인스턴스가 새로 만들어지므로 참조 대신 이름으로 본다.
func _equipped_names() -> Array:
	var out: Array = []
	for d in gs.ring_equipped:
		out.append(String(d.display_name) if d != null else "")
	return out


func _test_slot_fill() -> void:
	_reset_ring_state()
	# 슬롯 수를 하드코딩하지 않는다 — 세션64에 4→3이 됐고, 다시 바뀌어도 이 테스트는 계약만 잰다.
	var n: int = gs.EQUIP_SLOTS
	var made: Array = []
	for i in n + 1:
		var d = RD.from_assembly(_sample_assembly(), "진%d" % i)
		made.append(d)
		eb.ring_design_committed.emit(d)
	_check(gs.ring_designs.size() == n + 1, "%d장 모두 보관" % (n + 1))
	for slot in n:
		_check(gs.ring_equipped[slot] == made[slot], "슬롯 %d에 순서대로 장착" % slot)
	_check(not (made[n] in gs.ring_equipped), "%d장째는 슬롯이 꽉 차 장착 안 됨(보관만)" % (n + 1))
