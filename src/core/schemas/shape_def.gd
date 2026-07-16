class_name ShapeDef
extends Resource
## 마법 "모양" 하나 = 데이터 한 장. 진·룬·문양의 그 모양을 코드가 아니라 이 .tres가 쥔다.
## 목적: 모양이 이상하면 그 파일 하나만 열어 고친다 (사용자 요청 2026-07-17).
##
## 🔴 단일 진실원: 책자·종이 트레이스는 `points`를 그리고, 인식기는 `variants`를 $1 매칭에 쓴다.
## 둘 다 이 한 파일에서 나오므로 **보이는 모양 ≠ 인식 기준** mismatch가 구조적으로 불가능하다.
##
## 좌표계 = 중심 (0,0) · 최장변 1 정규화 (RuneTemplates.canonical()과 같은 규약).

## 파일 식별자 (data/shapes/<id>.tres 와 일치)
@export var id: StringName = &""
## 분류 — Enums.DrawStage: CIRCLE(진)=0 · RUNE(룬)=1 · ARROW(문양)=2
@export var category: int = Enums.DrawStage.CIRCLE
## 게임 정체성 — 룬이면 Enums.RuneType, 문양이면 Enums.GlyphType 값. 진은 -1.
@export var type_value: int = -1
## 책자 셀 이름
@export var display_name: String = ""
## 책자 셀 아래 한 줄 설명
@export var description: String = ""
## 대표 모양 — 책자·종이 트레이스가 그리는 점열 (중심 0·최장변 1).
@export var points: PackedVector2Array = PackedVector2Array()
## 인식기 매칭용 변형들(회전·찌그러짐·뒤집기 등). 비어 있으면 인식기가 `points` 하나만 쓴다.
## ⚠ 진(원)은 기하 판정(detect_circle)이라 인식에 안 쓰이므로 비운다.
@export var variants: Array[PackedVector2Array] = []
