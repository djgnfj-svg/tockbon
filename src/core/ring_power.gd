extends RefCounted
## 🔴 **종합 점수 → 안정성·위력** 규칙 (2026-07-17 세션 23). 순수 수학 · 오토로드 아님.
##
## 왜 core에 있나: **조립 리포트가 보여 주는 위력과 실제로 적을 때리는 위력이 같아야 한다.**
## 규칙이 `ring_forge_panel`(UI)과 `ring_spell_system`(발사) 양쪽에 복사되면 한쪽만 고쳐도
## 아무도 못 알아채고 갈라진다 — 리포트는 "위력 140"이라 적어 놓고 130으로 때리는 식으로.
## 그래서 두 모듈이 **같은 함수**를 부른다. (모듈 간 직접 참조 금지 규칙의 정당한 통로 = core.)
##
## 규칙 (사용자 확정 2026-07-17):
##   • 종합 점수가 `ring_stability_min`(0.65) **이하면 펑** — 마법진이 안 맺히고 도안이 날아간다
##   • 넘겼으면 기준선~만점을 `ring_power_min`~`ring_power_max`로 **선형 보간** —
##     "점수가 높을수록 성능이 좋아". 계단이 아니라 연속이라 1점 차이가 의미를 갖는다
##
## 수치는 전부 data/balance.tres (코드에 수치 금지).
##
## 사용: const RingPower := preload("res://src/core/ring_power.gd")

const BAL: BalanceData = preload("res://data/balance.tres")


## 🔴 이 점수로 마력을 주입하면 견디나? false면 **펑**.
## 경계는 "이하면 터진다" — 정확히 기준선인 마법진은 **터진다** (사용자: "65퍼 이하면 터지고").
static func is_stable(score: float) -> bool:
	return score > BAL.ring_stability_min


## 종합 점수 → 위력 배율 = `ring_power_max × 점수^ring_power_curve`.
## 발사 피해에 곱해지고, 리포트가 **같은 값**을 표시한다.
##
## 🔴 이 함수는 "터졌나"를 **모른다** (is_stable의 일). 그래서 기준선 아래에서도 값이 이어진다 —
## 리포트가 주입 **전에** 위력을 보여 주는데, 미달 구간이 평평하면 그 평평함 자체가
## "너 지금 미달"이라는 **안내**가 된다 (사용자 확정: 평가는 주입하는 순간에 한다).
## 곡선이라 0점→0, 만점→max로 끊김 없이 이어지고 어디에도 평평한 구간이 없다.
static func power_of(score: float) -> float:
	return BAL.ring_power_max * pow(clampf(score, 0.0, 1.0), BAL.ring_power_curve)


## 리포트 표시용 정수 (예: "위력 128"). 100 = 기준 위력(≈79점).
static func power_display(score: float) -> int:
	return int(round(power_of(score) * 100.0))


## 기준선(펑/안 펑 경계).
## ⚠ **주입 전에 이걸 UI로 흘리지 마라** — "65점 넘겨야 함"을 미리 알려 주면 주입이
## 결과를 확인하는 형식 절차가 된다. 터진 **뒤에** 왜 터졌는지 알려 줄 때만 쓴다.
static func threshold() -> float:
	return BAL.ring_stability_min
