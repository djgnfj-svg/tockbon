class_name SpellDesign
extends Resource
## 도안 — 게임의 중심 데이터. A(드로잉)가 생성, B(스펠)가 발사, D(거점)가 수리, E(UI)가 표시.
## 스키마 변경은 리드만 (TECH_SPEC §4).

@export var id: StringName
@export var display_name: String = ""
## 🔴 **v2.0: 소비되지 않는다.** 발사 방향이 지팡이로 가면서 **도안 회전 자체가 없어졌다** —
## AIMED/FIXED를 가를 이유가 사라졌다. 구세이브 호환 필드로만 남는다 (TECH_SPEC §4.0-a)
@export var circle_type: Enums.CircleType = Enums.CircleType.AIMED
## 정규화 0..1 (캔버스 대비 원 크기). **진 = 규모 + 투사체의 모양 축** (v2.0, TECH_SPEC §4.0).
## 위력 배율·**탄 크기**·기준 사거리를 이 값이 정하고, **v2.0에서는 그린 진 자체가 탄이 된다** —
## 먹선도 히트박스도 이 반지름을 따른다. 대가는 잉크(제작)와 마나(시전)
@export var circle_radius: float = 0.5
## 도안의 기준축(rad) — v1.5~v1.9: 발사 시 이 축이 에임과 일치하도록 도안 전체가 회전했다.
##
## 🔴 **v2.0: 소비되지 않는다.** 방향이 지팡이로 갔으므로 **회전시킬 이유가 없다** —
## 마법진은 그린 자세 그대로 날아간다. 값은 기록·구세이브 호환용
@export var aim_axis: float = -PI / 2.0
## 🔴 **복합 — 한 진의 룬들 (N개, 2026-07-15 — TRUTH §4).** 서로 다른 종류를 여럿 담으면 하나의
## 탄에 속성이 합쳐진다(위력=fill 가중평균, 상태이상 각각). 비어 있으면(구세이브·단일 룬 도안)
## 아래 스칼라 하나짜리로 본다 — `rune_list()`가 그 폴백을 준다. **primary(스칼라)는 fill 최대 룬**
## (탄 색·먹선·약점 판정 기준). Resource 기본값이 곧 마이그레이션.
@export var runes: Array[RuneInstance] = []
## primary 룬 종류 — runes가 있으면 그중 fill 최대. 단일 룬이면 지금과 정확히 같다 (하위호환)
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
## 🔴 **중첩 진 (재귀, 2026-07-15 확정 — TRUTH §4).** 이 진이 **껍질**이고, children은 그 껍질이
## 착탄/수명 끝에 열릴 때 **그 자리에서 각자 전개되는 안쪽 진들**이다. 각 child도 완전히 같은
## SpellDesign — 자기 모양·룬·문양·(재귀적으로) 또 자식을 갖는다. *"내부 진도 똑같아야지, 진이
## 모양을 정함."* 비어 있으면(구세이브·평평한 도안) 지금과 정확히 같은 단일 마법 — Resource 기본값이
## 곧 마이그레이션이라 옛 .tres는 자동으로 children=[]로 로드된다.
## ⚠ circle_radius·rune_type 등 나머지 필드는 **이 진(껍질) 자신의 것**이다. 자식 진의 값은 자식
## SpellDesign 안에 있다. "진 1개"를 코드 곳곳에 하드코딩하면 이 트리가 무너진다 (TRUTH §3.6).
@export var children: Array[SpellDesign] = []
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


## 이 진의 룬들 — 항상 최소 하나. runes가 있으면 그대로, 비어 있으면(구세이브·단일 룬 도안)
## 스칼라(rune_type/fill/accuracy) 하나짜리 리스트로 폴백한다. 소비 측은 이것만 쓰면 복합·단일을
## 분기하지 않아도 된다 (spell_system·projectile).
func rune_list() -> Array[RuneInstance]:
	if not runes.is_empty():
		return runes
	return [RuneInstance.make(int(rune_type), rune_fill, rune_accuracy)]
