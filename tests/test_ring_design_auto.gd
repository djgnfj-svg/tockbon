extends SceneTree
## 고리 도안(RingDesign) + 장착 배선 자동 검증 (#17 1단계, 세션 16) — 헤드리스:
##   ./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_ring_design_auto.gd
## 전 항목 통과 시 "TEST_RING_DESIGN_OK".
##
## 검증: (1) RingDesign.from_assembly↔to_assembly 라운드트립·filled_count,
##   (2) EventBus.ring_design_committed → GameState.ring_equipped 자동 장착(첫 진=슬롯 1),
##   (3) 빈 슬롯 소진(4장까지 장착, 5장째는 보관만).
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
	gs = root.get_node(^"GameState")
	eb = root.get_node(^"EventBus")
	RD = load("res://src/core/schemas/ring_design.gd")

	_test_roundtrip()
	_test_auto_equip()
	_test_slot_fill()
	_test_score_carries()
	_test_power_rule()
	_test_grade_bands()
	_test_grade_follows_threshold()

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


## 기본 2방 문양본에 발산 하나 채운 assembly (rune=불).
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


func _test_slot_fill() -> void:
	_reset_ring_state()
	var made: Array = []
	for i in 5:
		var d = RD.from_assembly(_sample_assembly(), "진%d" % i)
		made.append(d)
		eb.ring_design_committed.emit(d)
	_check(gs.ring_designs.size() == 5, "5장 모두 보관")
	for slot in 4:
		_check(gs.ring_equipped[slot] == made[slot], "슬롯 %d에 순서대로 장착" % slot)
	_check(not (made[4] in gs.ring_equipped), "5장째는 슬롯이 꽉 차 장착 안 됨(보관만)")
