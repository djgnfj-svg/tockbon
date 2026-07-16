class_name JinDef
extends Resource
## 진 정의 — 마법진의 **바깥 그릇**(투사체 몸). data/jin/*.tres. (세션 13 구조화)
##
## 🔴 축 분담(TRUTH): 진이 **모양**을 정한다 — 몸(비행·히트박스·규모) + 고리 칸 구조.
## 지금은 일반진 하나뿐이지만, 옛 int const `_has_jin`(bool)에서 데이터로 빼 **"진 모양 추가 = .tres 한 장"**
## 이 되게 한다. 층·칸·규모가 늘어날 자리를 연다.

@export var id: StringName = &"plain"
@export var display_name: String = "일반진"
## 1차 고리가 주는 칸 수 (지금 8). 진마다 다른 칸 구조를 줄 자리.
@export var slot_count: int = 8
## 투사체 몸 규모 배수 (비행 히트박스·연출). 지금 1.0.
@export var body_scale: float = 1.0
## 조립 보드에서 그릇 원을 그리는 색.
@export var ui_color: Color = Color(0.42, 0.30, 0.12, 0.55)
