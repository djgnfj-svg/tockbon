extends RefCounted
## 🔴 상태이상·원소 반응의 **규칙 단일 소스** (세션49 신설). class_name 없음 — `const SR := preload(...)`.
##
## 왜 core에 있나: `ring_power.gd`와 같은 이유다 — **적·플레이어·허수아비·UI가 같은 함수를 부른다.**
## 복사해 두면 한쪽만 고쳐도 아무도 못 알아채고 갈라진다("진흙인데 안 묶인다" 식).
## 여기는 **순수 규칙**만 둔다(시간·노드·씬을 모른다). 상태를 **보유하고 틱을 도는 건 각 배우**다.
##
## 🔴 설계 원칙 (사용자 확정 세션49):
##   **단독은 약한 바탕, 조합에서 폭발한다.**
##   단독 효과가 다 없으면 한 발이 밋밋하고, 단독이 다 세면 조합할 이유가 없다.
##   그래서 룬마다 약한 상태를 남기고, 그 위에 다른 룬이 오면 여기서 **반응**시킨다.
##   선례 = 원신 Swirl(바람=확산)/Crystallize(흙=굳힘) — **바람·흙은 자체 효과를 억지로 만들지 않는다.**
##
## 🔴 이 파일이 곧 기획서다. 반응을 늘리는 건 `REACTIONS`에 **줄 하나**다.

const BAL := preload("res://data/balance.tres")


## 룬이 남기는 **바탕 상태** — 단독으로는 약하다. RuneDef.status가 이미 데이터로 들고 있으므로
## 그 값을 그대로 쓴다(여기서 룬→상태를 다시 정의하지 않는다 — 두 소스가 되면 갈라진다).
## ⚠ 바람(WIND)은 **상태를 안 남긴다**(FLOW = 즉발 밀림). 대신 아래 `spreads()`가 참이다.


## 🔴 **반응 표** — {바탕 상태: {들어온 룬: 결과}}.
## 결과 = { "status": 새 상태(NONE이면 바탕이 사라지고 끝) , "kind": 연출·처리 갈래 ,
##          "rune": 버스트 피해가 실려 나가는 룬(소리·색의 정체 — burst 줄에만) }
##   kind: "convert"=바탕이 새 상태로 바뀐다 · "burst"=즉발 폭발(피해·연쇄) · "clear"=씻겨 사라진다
##   "rune"이 없으면 **들어온 룬**이 폴백이다 — FIRE 고정(세49~55의 하드코딩)보다 늘 진실에 가깝다.
##
## ⚠ **의미 있는 쌍만 적는다.** 안 적힌 조합은 그냥 새 상태가 덮어쓴다(기본 동작).
## 6룬이라 15쌍이지만 전부 채울 필요가 없다 — 사용자: *"쏴 보고 정한다."*
const REACTIONS := {
	Enums.Status.WET: {
		# 젖음 + 번개 = 강한 감전 + 주변 연쇄 (사용자가 제일 먼저 떠올린 조합) — 연쇄는 번개 사건
		Enums.RuneType.BOLT: {"status": Enums.Status.SHOCK, "kind": "burst", "rune": Enums.RuneType.BOLT},
		# 젖음 + 흙 = 진흙 (강한 속박) — 사용자 아이디어
		Enums.RuneType.EARTH: {"status": Enums.Status.MUD, "kind": "convert"},
		# 젖음 + 불 = 증기 (젖음이 날아간다 — 물로 불을 막는 게 아니라 서로 상쇄) — 끓는 물 사건
		Enums.RuneType.FIRE: {"status": Enums.Status.NONE, "kind": "burst", "rune": Enums.RuneType.WATER},
		# 젖음 + 풀 = 무성함 (덩굴이 크게 자라 오래 묶는다)
		Enums.RuneType.GRASS: {"status": Enums.Status.ROOT, "kind": "convert"},
	},
	Enums.Status.BURN: {
		# 화상 + 풀 = 산불 (더 세고 오래 타며 번진다)
		Enums.RuneType.GRASS: {"status": Enums.Status.BLAZE, "kind": "convert"},
		# 화상 + 물 = 꺼진다
		Enums.RuneType.WATER: {"status": Enums.Status.NONE, "kind": "clear"},
	},
	Enums.Status.ROOT: {
		# 덩굴 + 불 = 산불 (마른 덩굴이 잘 탄다)
		Enums.RuneType.FIRE: {"status": Enums.Status.BLAZE, "kind": "convert"},
	},
}


## 🔴 **바람 = 확산자** (원신 Swirl 모델). 자기 상태를 남기지 않고, 적에게 **이미 붙은 상태를
## 주변 적들에게 퍼뜨린다.** 혼자선 아무것도 아닌데 조합에선 최고가 되는 자리 —
## 둘레진·나선진처럼 여러 적을 스치는 진과 궁합이 폭발한다.
static func spreads(rune_type: int) -> bool:
	return rune_type == Enums.RuneType.WIND


## 🔴 **흙 = 취약(밑작업)** — 다음에 걸리는 상태를 더 세게 만든다. 물(감속)과 축이 안 겹치게
## "둔화"가 아니라 "취약"으로 뒀다(검색 선례: Earth = Vulnerability).
static func amplifies(rune_type: int) -> bool:
	return rune_type == Enums.RuneType.EARTH


## 상태가 지속되는 시간(초). 반응 산물(진흙·산불)은 더 오래 간다 — 조합의 보상이다.
static func duration_of(status: int) -> float:
	match status:
		Enums.Status.BURN:       return BAL.status_burn_sec
		Enums.Status.WET:        return BAL.status_wet_sec
		Enums.Status.SHOCK:      return BAL.status_shock_sec
		Enums.Status.VULNERABLE: return BAL.status_vulnerable_sec
		Enums.Status.ROOT:       return BAL.status_root_sec
		Enums.Status.MUD:        return BAL.status_mud_sec
		Enums.Status.BLAZE:      return BAL.status_blaze_sec
		_:                       return 0.0


## 이동 배율 — 1.0이면 안 느려진다. 젖음<진흙 순으로 세다. 묶임(덩굴·진흙)은 거의 정지.
## 🔴 **`_apply_move` 한 곳에만 곱해라** — AI 3종(추격·돌진·부유)이 전부 그 통로를 지난다.
##
## 🔴 세션50: `power`(세기 배율)를 **먹는다.** 그전엔 감속이 balance 고정이라
## **감전·덩굴·진흙엔 특별잉크가 아예 안 통했다** — 빚①의 절반이 여기 있었다.
## ⚠ 상한(`status_slow_cap`)으로 자른다: 완전정지를 허용하면 "느려졌다"와 "죽었다/어그로 풀림"이
## 구분되지 않아, 감속을 재는 검증이 엉뚱한 이유로 통과한다.
static func move_mult(status: int, power: float = 1.0) -> float:
	var slow := 0.0
	match status:
		Enums.Status.WET:   slow = BAL.status_wet_slow
		Enums.Status.MUD:   slow = BAL.status_mud_slow
		Enums.Status.ROOT:  slow = BAL.status_root_slow
		Enums.Status.SHOCK: slow = BAL.status_shock_slow
		_:                  return 1.0
	return 1.0 - clampf(slow * power, 0.0, BAL.status_slow_cap)


## 초당 지속 피해 — 화상 계열만. `power` = **세기 배율**(특별잉크 증폭이 이미 곱해져 있다).
## 🔴 산불은 화상보다 세다 — 반응의 보상이 **눈에 띄게** 커야 조합할 이유가 생긴다.
## ⚠ 세션50 전엔 `power`가 곧 초당피해(불의 3.0)였다 — 기준값이 balance로 나갔다.
static func dot_per_sec(status: int, power: float) -> float:
	match status:
		Enums.Status.BURN:  return BAL.status_burn_dot_base * power
		Enums.Status.BLAZE: return BAL.status_burn_dot_base * power * BAL.status_blaze_dot_mult
		_:                  return 0.0


## 🔴 반응 버스트(증기·감전연쇄)의 기준 피해 — 실제 피해 = 이 값 × 각 반응의 mult.
## ⚠ **버스트 피해를 `power`만으로 계산하지 마라** — 세션49엔 그랬고, 배율 통일 때 그대로 두면
## 피해가 조용히 1/3로 토막 난다(에러도 테스트 실패도 없다). 계산을 여기 한 곳에 모은 이유다.
static func burst_damage(power: float, mult: float) -> float:
	return BAL.status_burst_base * power * mult


## 🔴 반응 판정 — 바탕 상태에 새 룬이 들어왔을 때 무엇이 일어나는가.
## 반환 {"status": 결과 상태, "kind": 갈래} · 반응이 없으면 빈 사전(호출부가 기본 덮어쓰기).
static func react(base_status: int, incoming_rune: int) -> Dictionary:
	var by_rune: Dictionary = REACTIONS.get(base_status, {})
	return by_rune.get(incoming_rune, {})


## 🔴 바탕 상태에 이 룬이 들어오면 반응하나 (세81 M2 융합진 정렬용) — `react`의 bool 래퍼.
static func reacts(base_status: int, incoming_rune: int) -> bool:
	return not react(base_status, incoming_rune).is_empty()


## 🔴 **룬 뭉치를 반응이 나는 순서로 정렬한다** (세81 M2 융합진).
## `apply_incoming`은 **순차**라 얹는 순서가 반응 유무를 정하는데(REACTIONS 표가 비대칭 —
## base 키가 WET·BURN·ROOT뿐), 이 정렬이 없으면 **같은 두 룬이 자리 순서에 따라 반응하기도
## 안 하기도** 한다(물→번개=감전 / 번개→물=무반응). 이걸 두면 자리 순서와 무관하게 같은 반응이 난다.
##
## entries = `[{status:int, rune:int, …}, …]` (다른 키는 보존 — 호출부가 피해·세기를 함께 싣는다).
## 규칙: 앞의 상태에 뒤의 룬이 반응하는 순서가 되게 인접 스왑(안정 — 반응 안 나면 원래 순서).
## 🔴 2룬(M2) 기준으로 정확하다. 3룬+는 한 번 훑는 휴리스틱이라 모든 반응을 최적 배치하진 않는다
## (M2는 2룬이라 안 닿는다 — 필요해지면 그때 넓힌다, YAGNI). ⚠ 순수 int 판별뿐이라 `-s` 안전.
static func order_for_reaction(entries: Array) -> Array:
	var out := entries.duplicate()
	for i in range(out.size() - 1):
		var a: Dictionary = out[i]
		var b: Dictionary = out[i + 1]
		var ab := reacts(int(a.get("status", -1)), int(b.get("rune", -1)))
		var ba := reacts(int(b.get("status", -1)), int(a.get("rune", -1)))
		# 뒤(b)의 상태가 바탕이 돼야 반응하는데 앞(a)으론 안 되면 스왑 — b를 primary(앞)로.
		if ba and not ab:
			out[i] = b
			out[i + 1] = a
	return out


## 취약(흙)이 걸려 있을 때 다음 상태에 곱해지는 세기 배율.
##
## 🔴 세션50(사용자 확정): 취약의 세기축 = **증폭 배수**다(지속시간이 아니라). 취약은 이동도
## DoT도 없고 유일한 효과가 "다음 상태를 증폭"이라, 지속을 흔들면 조합의 보상이 세기가 아니라
## **타이밍 여유**로 미끄러진다.
## ⚠ **선형**이다 — `vuln_power`(취약이 걸릴 때의 세기, 0.0이면 안 걸림)만큼 배수가 자란다.
## 곱(`mult ** power`)으로 하면 취약 2배가 배수 2.25배로 튀어 특별잉크가 폭주한다.
static func power_mult(vuln_power: float) -> float:
	if vuln_power <= 0.0:
		return 1.0
	return 1.0 + (BAL.status_vulnerable_mult - 1.0) * vuln_power


## 상태 틴트 색 — **보여야 의미가 있다**(화상 중인 적이 평범해 보이면 룬을 바꿀 이유를 못 느낀다).
## 연출값이라 balance가 아니라 여기 둔다(선례: juice의 손맛 수치).
static func tint_of(status: int) -> Color:
	match status:
		Enums.Status.BURN:       return Color(1.35, 0.75, 0.55)
		Enums.Status.BLAZE:      return Color(1.60, 0.60, 0.35)
		Enums.Status.WET:        return Color(0.65, 0.85, 1.35)
		Enums.Status.MUD:        return Color(0.75, 0.62, 0.45)
		Enums.Status.SHOCK:      return Color(1.25, 1.20, 0.55)
		Enums.Status.ROOT:       return Color(0.70, 1.25, 0.70)
		Enums.Status.VULNERABLE: return Color(1.15, 0.95, 1.15)
		_:                       return Color.WHITE
