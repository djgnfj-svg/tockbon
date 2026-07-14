class_name SpellDesign
extends Resource
## 도안 — 게임의 중심 데이터. A(드로잉)가 생성, B(스펠)가 발사, D(거점)가 수리, E(UI)가 표시.
## 스키마 변경은 리드만 (TECH_SPEC §4).

@export var id: StringName
@export var display_name: String = ""
## v1.5: 진은 한 종류다 (꼬리·고정진 폐지, GDD §4.1) — 새 도안은 전부 AIMED.
## FIXED는 **구세이브 호환용으로만** 남아 있다 (그 도안은 그린 절대각 그대로 발사된다)
@export var circle_type: Enums.CircleType = Enums.CircleType.AIMED
## 정규화 0..1 (캔버스 대비 원 크기)
@export var circle_radius: float = 0.5
## 도안의 기준축(rad) — 발사 시 이 축이 에임 방향과 일치하도록 도안 전체가 회전한다.
## v1.5: **항상 -PI/2 (캔버스 위쪽 = 앞)**. 종이 위쪽을 향해 그린 화살표가 마우스 방향으로 나간다
@export var aim_axis: float = -PI / 2.0
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
