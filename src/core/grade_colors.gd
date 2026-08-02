extends RefCounted
## 아이템 등급 색 — **단일 소스**. class_name 없음:
## `const GradeColors := preload("res://src/core/grade_colors.gd")`로 참조한다.
##
## 창고·픽업·획득 토스트가 같은 아이템을 다른 색으로 보여 주면 등급이 정보가 아니게 된다 —
## 사본을 두면 한쪽만 고쳐도 아무도 못 알아채고 조용히 갈라져서 여기로 합쳤다.
## ⚠ 하드 계약이 아니라 표시 규약이다 — 저장에 안 들어가고 밀어도 데이터가 안 깨진다.

## 흔함(1) → 전설(5).
const COLORS: Array[Color] = [
	Color(0.72, 0.70, 0.66),  # 1 흔함 (회백)
	Color(0.55, 0.80, 0.50),  # 2 (녹)
	Color(0.42, 0.66, 0.95),  # 3 (청)
	Color(0.74, 0.52, 0.95),  # 4 (자)
	Color(0.98, 0.70, 0.32),  # 5 전설 (금)
]


## 등급 → 색. clamp를 여기서 한다 — 등급이 0이거나 6이 들어와도 안전하게 막힌다.
static func of(grade: int) -> Color:
	return COLORS[clampi(grade - 1, 0, COLORS.size() - 1)]
