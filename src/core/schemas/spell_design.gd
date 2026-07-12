class_name SpellDesign
extends Resource
## 도안 — 게임의 중심 데이터. A(드로잉)가 생성, B(스펠)가 발사, D(거점)가 수리, E(UI)가 표시.
## 스키마 변경은 리드만 (TECH_SPEC §4).

@export var id: StringName
@export var display_name: String = ""
@export var circle_type: Enums.CircleType = Enums.CircleType.FIXED
## 정규화 0..1 (캔버스 대비 원 크기)
@export var circle_radius: float = 0.5
## 조준진 꼬리 방향(rad). FIXED면 무시
@export var aim_axis: float = 0.0
@export var rune_type: Enums.RuneType = Enums.RuneType.FIRE
## 0..1 인식 정확도 → 위력 보정. 스탬프 사용 시 저장 시점 값 보존 (GDD v1.3)
@export var rune_accuracy: float = 1.0
@export var arrows: Array[ArrowData] = []
## 원본 획 전체 — 샘플 도안은 비어 있을 수 있음 (파라미터 기반 대체 렌더 필요)
@export var strokes: Array[StrokeData] = []
@export var paper_grade: int = 1
## {ink_id: amount} — 제작 소모량이자 수리비 산정 기준
@export var ink_cost: Dictionary = {}
@export var mana_cost: float = 10.0
@export var durability_max: int = 20
@export var durability: int = 20

func is_broken() -> bool:
	return durability <= 0
