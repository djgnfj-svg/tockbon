class_name SpellDesign
extends Resource
## 도안 — 게임의 중심 데이터. A(드로잉)가 생성, B(스펠)가 발사, D(거점)가 수리, E(UI)가 표시.
## 스키마 변경은 리드만 (TECH_SPEC §4).

@export var id: StringName
@export var display_name: String = ""
## v1.5: 진은 한 종류다 (꼬리·고정진 폐지, GDD §4.1) — 새 도안은 전부 AIMED.
## FIXED는 **구세이브 호환용으로만** 남아 있다 (그 도안은 그린 절대각 그대로 발사된다)
@export var circle_type: Enums.CircleType = Enums.CircleType.AIMED
## 정규화 0..1 (캔버스 대비 원 크기). **v1.6: 마법의 규모 축** —
## 위력 배율·투사체 크기·사거리를 전부 이 값이 정한다 (TECH_SPEC §4.0).
## 크게 그린 진에서 크고 아프고 멀리 가는 마법이 나간다. 대가는 잉크(제작)와 마나(시전)
@export var circle_radius: float = 0.5
## 도안의 기준축(rad) — 발사 시 이 축이 에임 방향과 일치하도록 도안 전체가 회전한다.
## v1.5: **항상 -PI/2 (캔버스 위쪽 = 앞)**. 종이 위쪽을 향해 그린 화살표가 마우스 방향으로 나간다
@export var aim_axis: float = -PI / 2.0
@export var rune_type: Enums.RuneType = Enums.RuneType.FIRE
## 0..1 — 룬이 진을 얼마나 채우는가 (룬 획 bbox 반경 ÷ 진 반지름).
## **v1.7: 속성의 농도 축** — 상태이상 세기(화상 딜·젖음 둔화·넉백 거리·흐름)를 이 값이 정한다
## (TECH_SPEC §4.0). 진을 꽉 채운 룬 = 깊이 물든다 / 구석에 작게 그린 룬 = 옅게 스친다.
## 위력은 건드리지 않는다 — 그건 진의 축이다. 구세이브 도안은 기본값(중간 농도)으로 로드된다
@export var rune_fill: float = 0.5
## 0..1 인식 정확도 → **속성 순도** (v1.7: 위력 보정에서 분리됨 — 위력은 진의 축).
## 스탬프 사용 시 저장 시점 값 보존 (GDD v1.3)
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
