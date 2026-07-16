class_name RingDesign
extends Resource
## 고리 조립 도안 — 새 마법진 모델의 저장·장착 단위 (#17 1단계, 세션 16).
## `ring_board.get_assembly()`가 내는 순수 Dictionary(assembly)를 감싸 리소스로 만든다.
## 🔴 세션 22: 옛 SpellDesign 도안 경로를 매장해 **이제 이게 유일한 마법진 모델**이다. 스키마 변경은 리드만.
##
## assembly 형태: {ring_count:1, rune:int, rings:[Array[int](8칸)], open:[열린칸]}.
## 각 칸 값 = 응집(0)/발산(1)/빈칸(-1) (RingBoard.G_GATHER/G_RADIATE/GLYPH_NONE).
##
## ⚠ 경제(마나·내구)는 아직 없다 — #17 3단계에서 정한다.

@export var id: StringName
@export var display_name: String = "고리 마법진"
## 룬 종류 (지금은 불만) — assembly.rune
@export var rune: int = 0
## 진의 고리들. 지금은 1줄(8칸). rings[0][k] = 문양 코드 or -1
@export var rings: Array = []
## 문양본이 연 칸 인덱스 (렌더·요약용)
@export var open: Array = []
## 🔴 분석 종합 점수(0~1) = **손으로 얼마나 잘 그렸나**. 세션 23부터 **위력을 정한다**
## (`src/core/ring_power.gd`). 세션 22까지는 계산·저장만 되고 아무도 안 읽어서
## 잘 그리든 막 그리든 마법이 똑같았다 — 손으로 그리게 한 이유가 없던 셈이다.
@export var total_score: float = 0.0


## ring_spell_system이 먹는 발사 계약(Dictionary)으로 되돌린다.
## 🔴 `score`를 실어야 **저장해 둔 도안을 다시 쏴도 그때 그린 위력이 그대로 난다.**
## 빼면 장착한 진이 조용히 기준 위력으로 발사된다 (tests/test_ring_design_auto가 못 박아 둔다).
func to_assembly() -> Dictionary:
	return {
		"ring_count": 1,
		"rune": rune,
		"rings": rings.duplicate(true),
		"open": open.duplicate(),
		"score": total_score,
	}


## assembly(get_assembly 결과)를 감싸 RingDesign을 만든다.
## 🔴 점수는 **assembly가 이미 실어 온다**(board.get_assembly가 넣는다) — 기본값이 그걸 쓴다.
## `score`를 명시로 주면 그게 이긴다 (테스트·특수 경로용). 음수 = "안 줬음" 표식.
static func from_assembly(a: Dictionary, name: String = "", score: float = -1.0) -> RingDesign:
	var d := RingDesign.new()
	d.rune = int(a.get("rune", 0))
	d.rings = (a.get("rings", []) as Array).duplicate(true)
	d.open = (a.get("open", []) as Array).duplicate()
	d.total_score = score if score >= 0.0 else float(a.get("score", 0.0))
	if name != "":
		d.display_name = name
	return d


## 채워진 칸 수 (열린 칸 중 문양이 놓인 것). 요약·표시용.
func filled_count() -> int:
	if rings.is_empty():
		return 0
	var ring: Array = rings[0]
	var n := 0
	for k in open:
		var idx := int(k)
		if idx >= 0 and idx < ring.size() and int(ring[idx]) != -1:
			n += 1
	return n
