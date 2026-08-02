extends RefCounted
## 🔴 **종합 점수 → 안정성·위력** 규칙. 순수 수학 · 오토로드 아님.
## 사용: `const RingPower := preload("res://src/core/ring_power.gd")`
##
## 왜 core냐: **조립 리포트가 보여 주는 위력과 실제로 적을 때리는 위력이 같아야 한다.**
## 규칙이 UI(`ring_forge_panel`)와 발사(`ring_spell_system`) 양쪽에 복사되면 한쪽만 고쳐도
## 아무도 못 알아채고 갈라진다 — 리포트는 "위력 140"이라 적어 놓고 130으로 때리는 식으로.
##
## 규칙: 점수가 `ring_stability_min` **이하면 펑**(마법진이 안 맺히고 도안이 날아간다) ·
## 위력은 **지수 곡선** `ring_power_max × 점수^ring_power_curve`라 평평한 구간이 없다
## (선형+clamp면 미달 구간이 평평해져 「주입 전 안내」가 된다).
## 수치는 전부 `data/balance.tres`다 — 코드에 수치 금지.
##
## 🔴 **경계** — 여기가 정하는 건 「한 갈래의 기준 위력」이다. 변형형 문양(확산·폭발)이 그 위력을
## 여러 갈래로 배분·융합하는 건 `ring_spell_system._spread`/`_explode`가 하고, 수치는 그 문양
## `.tres`의 `params`다. 복사된 게 아니라 **축이 다르다** — 여긴 "한 발이 얼마나 센가",
## 저긴 "그 한 발이 몇 개로 갈라지나". 다중 룬 배분(`multi_rune_share`)도 저쪽 축이다.
## ⚠ 그래서 확산을 낀 도안은 **리포트의 위력 ≠ 갈래 하나의 피해**다(리포트가 "갈래당"이라 적는다).
## 🔴 **진 규칙이 위력에 개입하게 되면 그건 이쪽으로 와야 한다** — 그때는 축이 같아진다.

const BAL: BalanceData = preload("res://data/balance.tres")


## 이 점수로 마력을 주입하면 견디나? false면 **펑**.
## ⚠ 경계는 "이하면 터진다" — 정확히 기준선인 마법진은 터진다.
static func is_stable(score: float) -> bool:
	return score > BAL.ring_stability_min


## 손 긋기를 건너뛰나 (`balance.skip_drawing`).
## 🔴 이 술어를 통해서만 물어라 — `BAL.skip_drawing`을 여기저기서 직접 읽으면 한 곳을 되돌릴 때
## 다른 곳이 조용히 남는다.
static func skip_drawing() -> bool:
	return BAL.skip_drawing


## **조립 점수** — 그리기를 폐지하면 점수의 출처가 손이 아니라 부품이 된다
## (「좋은 부품을 모으면 세진다」 = 원정 보상이 곧 위력으로 이어지는 축).
## 반환은 손그림 점수와 같은 0~1 척도라 아래 위력·등급 함수가 전부 그대로 돈다.
## ⚠ 하한을 기준선 위로 클램프하지 않는다 — 여기서 clamp하면 `assemble_score_base`를 잘못
##  내려도 아무도 못 알아챈다.
static func assembled_score(glyph_count: int, layer_count: int) -> float:
	return clampf(BAL.assemble_score_base
		+ BAL.assemble_score_per_glyph * float(maxi(glyph_count, 0))
		+ BAL.assemble_score_per_layer * float(maxi(layer_count - 1, 0)), 0.0, 1.0)


## **품질 0~1 정규화** — 점수를 연출·시전 축의 보간 계수로 바꾼다.
##
## 🔴 `score`를 그대로 `lerp`에 넣지 마라 — 조립 점수의 실사용 범위는 `assemble_score_base` ~ 1.0이라
##  (맨 진이 이미 하한이다) 0~1로 보간하면 **무난한 진이 이미 중간값**이 돼 잘 조립해도 화면이
##  별로 안 달라진다.
## 🔴 하한을 상수로 베끼지 마라 — `assembled_score(0, 1)`(맨 진 = 문양 0·1층)에서 파생시켜야
##  balance를 조일 때 같이 움직인다.
## ⚠ 그리기 폐지 스위치를 되돌리면 하한이 달라진다(그땐 `trace_scorer`가 점수를 주고 실질 하한은
##  `ring_stability_min`이다) — 되살릴 땐 여기부터 봐라.
static func quality_t(score: float) -> float:
	var lo := assembled_score(0, 1)
	if score <= lo:
		return 0.0
	return clampf((score - lo) / maxf(1.0 - lo, 0.0001), 0.0, 1.0)


## 점수 → **시전 시간(초)**. 좌클릭에서 탄이 나가기까지 발밑 마법진이 열려 있는 길이다.
## 잘 조립할수록 **길다** — 강한 마법진은 DPS가 아니라 「한 방」이라는 계약의 실행부다.
## 🔴 여기가 단일 소스다 — 발사·연출·HUD가 같은 값을 봐야 원이 닫히는 순간과 탄이 나가는
## 순간이 안 갈린다.
static func cast_time_of(score: float) -> float:
	return lerpf(BAL.cast_time_plain_sec, BAL.cast_time_perfect_sec, quality_t(score))


## 점수 → **시전 중 이동 배수**(1.0 = 평소 속도). 잘 조립할수록 무겁다 = 그게 위험이다.
## ⚠ 곱하는 자리는 `move_speed()`의 **결과**여야 한다 — 모자·달리기 배수가 이미 실린 값에
## 얹혀야 장비 효과가 시전 중에만 조용히 사라지지 않는다.
static func cast_move_mult_of(score: float) -> float:
	return lerpf(BAL.cast_move_mult_plain, BAL.cast_move_mult_perfect, quality_t(score))


## 종합 점수 → 위력 배율 = `ring_power_max × 점수^curve × ink_mult × size_mult(size)`.
## 발사 피해에 곱해지고, 리포트가 **같은 값**을 표시한다.
##
## 🔴 데미지 레버 셋이 어떻게 합쳐지는지(**전부 곱**)는 여기 한 곳에서만 정한다:
##   • 점수 → 곡선 · `ink_mult` = 잉크 등급 배수(리졸버 = `Db.ink_mult`)
##   • `size` = 진 크기 → `size ^ paper_size_power_exp`(종이 등급이 상한을 올린다)
## ⚠ 잉크·크기 둘 다 데미지라 곱하면 겹쳐서 세진다 — balance로 조율한다.
##
## 🔴 이 함수는 "터졌나"를 모른다(`is_stable`의 일) — 그래서 기준선 아래에서도 값이 곡선으로
## 이어진다. 미달 구간이 평평하면 그 평평함 자체가 「주입 전 안내」가 되기 때문이다.
static func power_of(score: float, ink_mult: float = 1.0, size: float = 1.0) -> float:
	return BAL.ring_power_max * pow(clampf(score, 0.0, 1.0), BAL.ring_power_curve) \
		* ink_mult * size_mult(size)


## 진 크기(jin_scale) → 데미지 배수. size 1.0 = 1.0배. 음수 크기 방어로 max(size, 0).
static func size_mult(size: float) -> float:
	return pow(maxf(size, 0.0), BAL.paper_size_power_exp)


## 리포트 표시용 정수 (예: "위력 128"). 100 = 기준 위력(≈79점, 잉크·종이 없음).
static func power_display(score: float, ink_mult: float = 1.0, size: float = 1.0) -> int:
	return int(round(power_of(score, ink_mult, size) * 100.0))


## 발사 1회당 마나 소모 — 위력과 다른 축이다(잘 조립했다고 싸지지 않는다).
## 지금은 고정값이지만 발사는 반드시 이 함수를 거친다 — 도안별 비용을 붙일 때 여기만 고치면 된다.
static func cast_mana_cost() -> float:
	return BAL.cast_mana_cost


## 종합 점수 → **화면에 찍는 정수**. 조립 리포트·HUD가 같이 쓴다.
## 🔴 이 반올림이 곧 「퍼펙트」의 정의다(`ring_grade_perfect` = 이 함수가 100을 돌려주기 시작하는 점) —
## 베껴 두면 한 곳이 floor로 바뀌는 날 "100점인데 「완벽」"이 조용히 생긴다.
static func score_display(score: float) -> int:
	return int(round(clampf(score, 0.0, 1.0) * 100.0))


## 기준선(펑/안 펑 경계).
## ⚠ 주입 **전에** 이 숫자를 대놓고 띄우진 마라 — 목표치를 박으면 조립이 숫자 맞추기가 된다.
## 터진 뒤 이유를 설명할 때 쓴다(등급으로 경계를 알려 주는 것은 허용된 예외다).
static func threshold() -> float:
	return BAL.ring_stability_min


## 종합 점수 → **등급 이름**.
## 🔴 최하단 경계 = 펑 기준선이라 여기 있다 — 등급이 기준선 숫자를 자기 상수로 베끼면
## 두 경계가 갈라져 「같은 등급인데 터지기도 견디기도」 한다. 그래서 `is_stable()`을 그대로 부른다.
static func grade_of(score: float) -> String:
	if not is_stable(score):
		return "사용 불가"            # 🔴 기준선과 같은 술어 — 숫자를 베끼지 않는다
	if score >= BAL.ring_grade_perfect:
		return "퍼펙트"
	if score >= BAL.ring_grade_great:
		return "완벽"
	if score >= BAL.ring_grade_good:
		return "괜찮음"
	if score >= BAL.ring_grade_fair:
		return "평타"
	return "무난"


## 이 점수가 「퍼펙트」인가 — UI가 특별 대우(색·강조)를 할지 정할 때 쓴다.
## 이름 문자열을 UI가 == 로 비교하면 이름을 바꾸는 순간 조용히 깨진다.
static func is_perfect(score: float) -> bool:
	return score >= BAL.ring_grade_perfect
