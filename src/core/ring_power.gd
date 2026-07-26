extends RefCounted
## 🔴 **종합 점수 → 안정성·위력** 규칙 (2026-07-17 세션 23). 순수 수학 · 오토로드 아님.
##
## 왜 core에 있나: **조립 리포트가 보여 주는 위력과 실제로 적을 때리는 위력이 같아야 한다.**
## 규칙이 `ring_forge_panel`(UI)과 `ring_spell_system`(발사) 양쪽에 복사되면 한쪽만 고쳐도
## 아무도 못 알아채고 갈라진다 — 리포트는 "위력 140"이라 적어 놓고 130으로 때리는 식으로.
## 그래서 두 모듈이 **같은 함수**를 부른다. (모듈 간 직접 참조 금지 규칙의 정당한 통로 = core.)
##
## 규칙 (사용자 확정 2026-07-17):
##   • 종합 점수가 `ring_stability_min` **이하면 펑** — 마법진이 안 맺히고 도안이 날아간다
##   • 위력은 **지수 곡선** = `ring_power_max × 점수^ring_power_curve` (`power_of` 참조).
##     0점→0·만점→max로 이어져 평평한 구간이 없다 — 1점 차이가 의미를 갖는다.
## ⚠ 세86 정정: 옛 주석의 *"기준선~만점을 `ring_power_min`~`ring_power_max`로 선형 보간"*은
##   **거짓이었다** — `ring_power_min`은 balance에 없는 이름이고(src·tests 참조 0), 선형+clamp는
##   미달 구간이 평평해 「주입 전 안내」가 돼서 곡선으로 바뀌었다(balance `ring_power_curve` 주석).
##
## 수치는 전부 data/balance.tres (코드에 수치 금지).
##
## 🔴 **경계 (세79 M1 — 여기까지가 이 파일의 관할이다)**: `power_of`/`power_display`가 정하는 건
## **한 갈래의 기준 위력**이다. 변형형 문양(확산·폭발)이 그 위력을 **여러 갈래로 배분·융합**하는 건
## `ring_spell_system._spread`/`_explode`가 하고, 수치는 **그 문양 `.tres`의 `params`**
## (`branch_mult`·`merge_mult` — 세82에 balance에서 이사했다)다.
## 규칙이 **복사된 게 아니라 축이 다른 것**이다 — 여긴 "한 발이 얼마나 센가",
## 저긴 "그 한 발이 몇 개로 갈라지나".
## ⚠ 그래서 확산을 낀 도안은 **리포트의 위력 ≠ 갈래 하나의 피해**다(리포트가 "갈래당"이라 적는다).
## 🔴 **진 규칙(②·M2)이 위력에 개입하게 되면 그건 이쪽으로 와야 한다** — 그때는 축이 같아진다
## (설계 문서 「못박을 계약」: *"진 규칙이 위력에 개입하면 반드시 ring_power 단일 소스"*).
## ✅ **세81 M2 결론(융합진)**: `multi_rune_share`(다중 룬 세기 배분)는 **이쪽이 아니라
## `ring_spell_system._fire_hit`에 산다** — `_spread`/`_explode` 배분과 **같은 축**(한 발이 몇
## 갈래/몇 룬으로 나뉘나)이지, `power_of`가 정하는 "한 갈래가 얼마나 센가"(점수·잉크·크기)와
## 다른 축이기 때문이다. 그래서 **단일 소스 위반이 아니다**: 리포트의 `power_display`는 룬 수와
## 무관하게 **한 룬 히트의 점수 배율**을 그대로 보여주고, 발사도 각 룬 히트에 같은 배율을 쓴다
## (세23 「리포트가 140인데 130으로 때린다」식 불일치가 **없다**). ⚠ 다만 융합진은 총합이 1.4배라
## 리포트가 "더 세다"를 **안 알려준다** — 그건 표시하는 쪽이 "룬 N개(융합)"로 annotate한다(변형형
## "갈래당 위력" 라벨과 같은 선례). 그 판별은 `RingDesign.runes`/`has_modifier_glyph`가 쥔다.
##
## 사용: const RingPower := preload("res://src/core/ring_power.gd")

const BAL: BalanceData = preload("res://data/balance.tres")


## 🔴 이 점수로 마력을 주입하면 견디나? false면 **펑**.
## 경계는 "이하면 터진다" — 정확히 기준선인 마법진은 **터진다** (사용자: "65퍼 이하면 터지고").
static func is_stable(score: float) -> bool:
	return score > BAL.ring_stability_min


## 🔴 손 긋기를 건너뛰나 (세83 실험 스위치 — `balance.skip_drawing`).
## **이 술어를 통해서만 묻는다** — `BAL.skip_drawing`을 여기저기서 직접 읽으면 한 곳을 되돌릴 때
## 다른 곳이 조용히 남는다(세24 「등급 경계를 베끼면 갈라진다」와 같은 이유).
static func skip_drawing() -> bool:
	return BAL.skip_drawing


## 🔴 **조립 점수** — 그리기를 폐지하면 점수의 출처가 손이 아니라 **부품**이 된다 (세83).
## *"좋은 부품을 모으면 세진다"* = 원정 보상이 곧 위력으로 이어지는 축.
## 반환은 손그림 점수와 **같은 0~1 척도**라 아래 위력·등급 함수가 전부 그대로 돈다(새 축 아님).
## ⚠ 하한을 기준선 위로 **클램프하지 않는다** — 대신 `assemble_score_base`가 기준선보다 크다는
## 규율을 balance 주석에 박았다. 여기서 clamp하면 base를 잘못 내려도 아무도 못 알아챈다.
static func assembled_score(glyph_count: int, layer_count: int) -> float:
	return clampf(BAL.assemble_score_base
		+ BAL.assemble_score_per_glyph * float(maxi(glyph_count, 0))
		+ BAL.assemble_score_per_layer * float(maxi(layer_count - 1, 0)), 0.0, 1.0)


## 종합 점수 → 위력 배율 = `ring_power_max × 점수^curve × ink_mult × size_mult(size)`.
## 발사 피해에 곱해지고, 리포트가 **같은 값**을 표시한다.
##
## 🔴 데미지 레버 셋이 어떻게 **합쳐지는지(전부 곱)**는 여기 한 곳에서만 정한다 (세션29):
##   • 손그림 점수 → 곡선 (잘 그릴수록↑)
##   • `ink_mult` = 잉크 등급 배수 (사용자: "등급=데미지"). 리졸버 = `Db.ink_mult`.
##   • `size` = 진 크기(jin_scale, 종이=규모). size_mult = `size ^ paper_size_power_exp`
##     → 큰 진일수록 세다. 종이 등급이 size 상한을 올린다. 기본 크기 size=1.0 → 배수 1.0.
## ⚠ 잉크·크기 둘 다 데미지라 곱하면 겹쳐서 세진다 — balance로 조율(사용자와 확인).
##
## 🔴 이 함수는 "터졌나"를 **모른다** (is_stable의 일). 그래서 기준선 아래에서도 값이 이어진다 —
## 리포트가 주입 **전에** 위력을 보여 주는데, 미달 구간이 평평하면 그 평평함 자체가
## "너 지금 미달"이라는 **안내**가 된다 (사용자 확정: 평가는 주입하는 순간에 한다).
## 곡선이라 0점→0, 만점→max로 끊김 없이 이어지고 어디에도 평평한 구간이 없다.
static func power_of(score: float, ink_mult: float = 1.0, size: float = 1.0) -> float:
	return BAL.ring_power_max * pow(clampf(score, 0.0, 1.0), BAL.ring_power_curve) \
		* ink_mult * size_mult(size)


## 진 크기(jin_scale) → 데미지 배수 (세션29, 종이=규모). size 1.0 = 1.0배(제동 없음).
## 지수는 balance(paper_size_power_exp) — 손맛 조율 지점. 음수 크기 방어로 max(size, 0).
static func size_mult(size: float) -> float:
	return pow(maxf(size, 0.0), BAL.paper_size_power_exp)


## 리포트 표시용 정수 (예: "위력 128"). 100 = 기준 위력(≈79점, 잉크·종이 없음).
static func power_display(score: float, ink_mult: float = 1.0, size: float = 1.0) -> int:
	return int(round(power_of(score, ink_mult, size) * 100.0))


## 🔴 발사 1회당 마나 소모 (세션 35). 위력(power_of)과 **다른 축**이다 — 잘 그렸다고 싸지지
## 않는다. 지금은 도안과 무관한 고정값이지만, 발사는 반드시 이 함수를 거친다(수치를 fire()에
## 박지 않게 — 나중에 도안별 비용을 붙일 때 여기 한 곳만 고치면 된다). balance = cast_mana_cost.
static func cast_mana_cost() -> float:
	return BAL.cast_mana_cost


## 🔴 종합 점수 → **화면에 찍는 정수** (예: 89점). 조립 리포트·베이스캠프 HUD가 같이 쓴다.
##
## 왜 core냐: 이 반올림이 **「퍼펙트」의 정의**다 (`ring_grade_perfect = 0.995` = 이 함수가 100을
## 돌려주기 시작하는 점). 세션 24에 둘을 묶어 놓고 반올림만 여기저기 베껴 두면, 언젠가 한 곳이
## floor로 바뀌어 **"100점인데 「완벽」"**이 조용히 생긴다 — 등급과 기준선이 갈라졌던 그 방식 그대로.
static func score_display(score: float) -> int:
	return int(round(clampf(score, 0.0, 1.0) * 100.0))


## 기준선(펑/안 펑 경계).
## ⚠ 주입 **전에** 이 숫자를 대놓고 띄우진 마라 ("65점 넘겨야 함"). 등급이 경계를 알려 주는
## 것과 숫자를 알려 주는 건 다르다 — 전자는 사용자가 고른 것이고, 후자는 목표치를 박아
## 그리기를 **숫자 맞추기**로 만든다. 터진 뒤 이유를 설명할 때 쓴다.
static func threshold() -> float:
	return BAL.ring_stability_min


## 🔴 종합 점수 → **등급 이름** (2026-07-17 세션 24, 사용자 확정).
##
## 왜 여기 있나 (원래 trace_scorer._grade였다): **최하단 경계 = 펑 기준선**이기 때문이다.
## 세션 23의 등급은 채점기가 따로 쥔 숫자(55/75)라 기준선 0.65와 어긋났고 — 「무난」(55~75)이
## 경계를 걸쳐 **같은 "무난"이 터지기도 견디기도 했다**(61점=무난인데 펑). 그래서 등급이
## 65를 자기 상수로 베껴 적는 대신 `is_stable()`을 **그대로 부른다**: 기준선을 balance에서
## 0.70으로 올리면 「사용 불가」 칸도 저절로 따라 올라간다. 두 경계는 한 값이지 두 값이 아니다.
##
## ⚠ 이 등급은 주입 **전에** 보인다 = 펑 여부를 알려 준다. 그래도 되는지 사용자에게 물어
## 확정받았다("등급이 알려 줘도 됨"). 세션 23의 「주입 전 안내 금지」는 이제 **명시 문구**
## ("주입하면 터진다")와 **위력 곡선의 평평한 구간**에만 적용된다 — 등급은 예외다.
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
