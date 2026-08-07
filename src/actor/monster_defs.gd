extends RefCounted
## 몬스터 종류 표. 선례는 `src/sim/glyph_defs.gd` — id 상수 + `DEFS` 딕셔너리 +
##  `ALL` 명시 목록 + static 접근자. 🔴 **새 종류 하나 = 여기 한 줄이다.**
##
## ⚠ 표에 지금 넣지 않는 것 — 넣으면 「이 값이 돈다」로 읽히고 그건 거짓 손잡이다:
##  `invuln_ticks`(단계 3) · 「때리는 법」·「받는 피해」·「불 DPS」(단계 3·5·6).
##  🔴 「받는 피해 10」과 「불 DPS 10/초」는 표에 열을 안 만든다 —
##  `monsters-minimum` 「동작 ⑦」이 「플레이어 상수를 그대로 쓴다. 축을 안 늘린다」로 못 박았다.
##
## ⚠ 각 열을 처음 읽는 단계: `w_px`·`h_px`·`step_cells`·`max_hp` = 단계 1 · `speed_px` = 단계 2.
##  `speed_px`를 지금 넣는 이유는 상자와 걸음이 **같은 표**에서 나온다를 처음부터 세우기 위해서다.

## 🔴 예약값이다. 죽음 통지 배열(`_died_kind`)과 뷰가 종류를 정수로 나르는데,
##  **0이 유효한 종류면 지워진 슬롯이 조용히 돼지로 그려진다.**
##  선례 둘: `glyph_defs.GLYPH_NONE = 0`(「목록 끝이 곧 0」) ·
##  `spell_view._elem_id`가 죽은 슬롯에 -1을 주는 이유(「0으로 떨어지면 없는 투사체가 불로 그려질 뻔했다」).
const KIND_NONE := 0
const KIND_PIG := 1
const KIND_HEN := 2

## 🔴 순회는 **반드시 이 명시 리스트로만** 한다. 값이 연속이라고 가정하지 않는다.
const ALL: Array[int] = [KIND_PIG, KIND_HEN]

## 🔴 20마리는 사용자가 정한 값이다 — 재 보고 조정할 값이 아니다.
const MAX_MONSTERS := 20

const DEFS: Dictionary = {
	KIND_PIG: {
		"name": &"돼지", "w_px": 44, "h_px": 32, "step_cells": 1,
		"max_hp": 30, "speed_px": 160.0,
	},
	KIND_HEN: {
		"name": &"닭", "w_px": 24, "h_px": 28, "step_cells": 3,
		"max_hp": 10, "speed_px": 220.0,
	},
}


## 🔴 `DEFS[kind][…]`로 **직접 인덱싱한다.** `.get(…, 기본값)`을 쓰지 마라 —
##  표에 없는 종류가 조용히 돼지가 된다. `character_view._cell_rect`가 같은 규율을 적어 뒀다.
static func name_of(kind: int) -> StringName:
	return DEFS[kind]["name"]


static func w_px(kind: int) -> int:
	return DEFS[kind]["w_px"]


static func h_px(kind: int) -> int:
	return DEFS[kind]["h_px"]


static func step_cells(kind: int) -> int:
	return DEFS[kind]["step_cells"]


static func max_hp(kind: int) -> int:
	return DEFS[kind]["max_hp"]


static func speed_px(kind: int) -> float:
	return DEFS[kind]["speed_px"]
