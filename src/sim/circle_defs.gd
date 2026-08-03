extends RefCounted
## 진 표 — **마법진의 틀.** 🔴 진 하나 = 여기 한 줄.
##
## 진이 정하는 것은 **떠나는 배치**다 — 몇 층인가 · 룬을 몇 자리 넣나.
## 🔴 **진은 날아가는 모양을 정하지 않는다.** 그건 룬이 가져갔다(`docs/design/진-룬-문양.md`).
##
## ⚠ **왜 `src/sim/` 인가**: 진은 게임 규칙이고 순수 정수다. 문양 표(`glyph_defs.gd`)가 이미
##  여기 있다. `src/view/`에 두면 `src/sim/`이 못 읽는다(`net_layers`) — 나중에 `fire()`가
##  「이 목록이 그 진에 맞나」를 검증할 날에 표를 옮겨야 한다.
##
## ⚠ 조립 **상태**는 여기가 아니라 `src/actor/spell_circle.gd`다. 여기는 표뿐이다.

## 🔴 **예약값이다. 「진이 없다」가 곧 0이다.** 그래서 진 id는 1부터 시작한다.
##  ⚠ `glyph_defs.GLYPH_NONE = 0`과 **같은 규율**이다 — 리포에 규칙이 하나만 있게 한다.
##  🔴 **룬은 이 규율을 못 쓴다** — `ELEM_FIRE`가 이미 0이다(`spell_circle.RUNE_EMPTY`).
const CIRCLE_NONE := 0

## 🔴 id는 int이고 **순회는 반드시 `ALL` 명시 리스트로만** 한다 — 값이 연속이라고 가정하지 않는다.
const CIRCLE_ROUND := 1

## 🔴🔴 **진 하나 추가 = 여기 한 줄 + `ALL` 한 줄.**
##
##   layers      문양을 놓을 층 수. 🔴 **안쪽이 1층이고 안쪽부터 실행된다**
##   rune_slots  룬을 넣을 자리 수
##
## ⚠ **칸이 둘뿐인 것은 일부러다.** design 문서는 진이 넷을 담는다고 적었는데
##  나머지 둘은 지금 **소비자가 0**이라 거짓 손잡이가 된다(CLAUDE.md):
##   · `combine`(융합·병렬·순차) — 룬 자리가 하나면 합칠 것이 없다
##   · `glyphs_per_rune`        — 룬이 하나면 「총 문양 칸」과 「탄 하나의 층」이 같다
##  룬 자리가 여럿인 진이 오는 날 같이 온다.
##
## 🔴 **소비자가 있는 두 칸만 남겼다** — 조립창이 층 고리 수와 룬 자리 수를 여기서 파생시킨다.
const DEFS: Dictionary = {
	# 기본 지급 진. 층 2 · 룬 1자리(GDD).
	CIRCLE_ROUND: {"name": &"동그라미", "layers": 2, "rune_slots": 1},
}

## 🔴 순회는 **반드시 이 명시 리스트로만** 한다. ⚠ `CIRCLE_NONE`은 진이 아니라 **빈 값**이라
##  여기 없다 — 팔레트가 이 리스트를 도는데 「없음」이 항목으로 뜨면 그게 거짓 손잡이다.
const ALL: Array[int] = [CIRCLE_ROUND]


## 🔴 「진이 없다」는 **정상 상태다** — 짖지 않고 0을 준다(층 0 = 문양을 못 놓는다).
## 🔴 반대로 **표에 없는 진에는 짖는다** — 진을 늘리면서 표에 안 넣으면 래퍼의 stderr 검사에
##  공짜로 걸린다(`spell_sim._run_glyph`와 같은 장치다).
static func layers(circle_id: int) -> int:
	if circle_id == CIRCLE_NONE:
		return 0
	if not DEFS.has(circle_id):
		push_error("Circle: 모르는 진 %d — 층 수를 0으로 본다" % circle_id)
		return 0
	return int(DEFS[circle_id]["layers"])


static func rune_slots(circle_id: int) -> int:
	if circle_id == CIRCLE_NONE:
		return 0
	if not DEFS.has(circle_id):
		push_error("Circle: 모르는 진 %d — 룬 자리를 0으로 본다" % circle_id)
		return 0
	return int(DEFS[circle_id]["rune_slots"])
