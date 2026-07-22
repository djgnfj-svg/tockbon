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
## 🔴 진 id (세션44, 진=형태). 이 마법진을 **어느 진에 그렸나** — 발사 형태(단발/산탄/둘레)를 정한다.
## 빈 값(&"") = 옛 도안/매직볼 = 발사가 폴백(지팡이 장비 또는 단발). id→패턴은 `Db.get_jin(jin).pattern`.
## ⚠ ink처럼 여기에 Db를 두지 마라(class_name → -s 컴파일 함정). 패턴 해석은 발사부(ring_spell_system)가 한다.
@export var jin: StringName = &""
## 진의 고리들. 지금은 1줄(8칸). rings[0][k] = 문양 코드 or -1
@export var rings: Array = []
## 진이 연 칸 인덱스 (렌더·요약용 — 세션60부터 출처 = JinDef.glyph_slots. 도안은 그때의 스냅샷)
@export var open: Array = []
## 🔴 분석 종합 점수(0~1) = **손으로 얼마나 잘 그렸나**. 세션 23부터 **위력을 정한다**
## (`src/core/ring_power.gd`). 세션 22까지는 계산·저장만 되고 아무도 안 읽어서
## 잘 그리든 막 그리든 마법이 똑같았다 — 손으로 그리게 한 이유가 없던 셈이다.
@export var total_score: float = 0.0
## 🔴 이 진을 그린 잉크 id (세션29, 사용자: "등급=데미지"). 등급 배수가 발사 위력에 곱해진다.
## 빈 값(&"") = 맨손/옛 도안 = 배수 1.0. id→배수 해석은 `Db.ink_mult(ink)`가 한다.
## ⚠ 여기에 `ink_mult()`를 두지 마라 — 이 스키마는 class_name이라 Db를 참조하면 `-s` 테스트가
## 오토로드 등록 전에 컴파일하다 터진다(item_def.gd·db.gd 주석 참조). 배수는 **호출부**가 Db로 뽑는다.
@export var ink: StringName = &""
## 🔴 특별잉크 (세션29, 사용자: "화상 증폭"). 이 진을 그리며 쓴 특별잉크 id + **얼마나 썼나**(0..1).
## 발사가 `Db.status_mult_of(special_ink, special_ratio)`로 화상 세기를 증폭한다. 빈 값 = 증폭 없음.
@export var special_ink: StringName = &""
@export var special_ratio: float = 0.0
## 🔴 진 크기 (세션29, 종이=규모). 그릴 때의 jin_scale (1.0=기본). 종이 등급이 상한을 올려 크게
## 그릴 수 있고, 큰 진일수록 발사 데미지가 세다 (`ring_power.power_of`의 size). 옛 도안 = 1.0.
@export var size: float = 1.0


## ring_spell_system이 먹는 발사 계약(Dictionary)으로 되돌린다.
## 🔴 `score`를 실어야 **저장해 둔 도안을 다시 쏴도 그때 그린 위력이 그대로 난다.**
## 빼면 장착한 진이 조용히 기준 위력으로 발사된다 (tests/test_ring_design_auto가 못 박아 둔다).
func to_assembly() -> Dictionary:
	return {
		"ring_count": 1,
		"rune": rune,
		"jin": jin,
		"rings": rings.duplicate(true),
		"open": open.duplicate(),
		"score": total_score,
		"ink": ink,
		"special_ink": special_ink,
		"special_ratio": special_ratio,
		"size": size,
	}


## assembly(get_assembly 결과)를 감싸 RingDesign을 만든다.
## 🔴 점수는 **assembly가 이미 실어 온다**(board.get_assembly가 넣는다) — 기본값이 그걸 쓴다.
## `score`를 명시로 주면 그게 이긴다 (테스트·특수 경로용). 음수 = "안 줬음" 표식.
static func from_assembly(a: Dictionary, name: String = "", score: float = -1.0) -> RingDesign:
	var d := RingDesign.new()
	d.rune = int(a.get("rune", 0))
	d.jin = StringName(a.get("jin", &""))
	d.rings = (a.get("rings", []) as Array).duplicate(true)
	d.open = (a.get("open", []) as Array).duplicate()
	d.total_score = score if score >= 0.0 else float(a.get("score", 0.0))
	d.ink = StringName(a.get("ink", &""))
	d.special_ink = StringName(a.get("special_ink", &""))
	d.special_ratio = float(a.get("special_ratio", 0.0))
	d.size = float(a.get("size", 1.0))
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
