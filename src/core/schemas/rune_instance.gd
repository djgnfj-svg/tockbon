class_name RuneInstance
extends Resource
## 진 하나에 든 룬 한 개 (복합, 2026-07-15 — TRUTH §4). 한 진에 서로 다른 종류의 룬을 여럿 담아
## **하나의 탄에 속성을 합친다**: 위력은 fill 가중평균, 상태이상은 룬마다 각각 실린다.
## 같은 종류는 하나뿐(불△ 두 번 = 농도 뻥튀기 금지). SpellDesign.runes가 이 배열을 쥔다.

## Enums.RuneType.FIRE/IMPACT/WATER/WIND
@export var type: int = Enums.RuneType.FIRE
## 0..1 — 룬이 진을 얼마나 채우는가 (rune_fill과 같은 의미). 상태이상 세기 + 위력 가중치.
@export var fill: float = 0.5
## 0..1 인식 정확도 = 속성 순도 (rune_accuracy와 같은 의미).
@export var accuracy: float = 1.0


static func make(p_type: int, p_fill: float, p_accuracy: float) -> RuneInstance:
	var r := RuneInstance.new()
	r.type = p_type
	r.fill = clampf(p_fill, 0.0, 1.0)
	r.accuracy = clampf(p_accuracy, 0.0, 1.0)
	return r
