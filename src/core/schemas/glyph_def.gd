class_name GlyphDef
extends Resource
## 문양 정의 — 룬과 진 **사이** 고리 칸을 채우는 조각. data/glyphs/*.tres. (세션 13 구조화)
##
## 문양 어휘가 늘 때 코드가 아니라 .tres를 늘린다.
## ⚠ 문양엔 **해금 게이트가 없다**(unlock_id 필드가 없고 책이 `Db.all_glyphs()`를 무필터로 띄운다) —
## 파밍 단위는 문양이 아니라 **문양-고리**(`GlyphRingDef`)다.
##
## 🔴 code = **발사 계약의 정수 코드** — ring_spell_system이 이 값으로 전개를 가른다.
## 정본 목록은 `Enums.GlyphCode` **9값**이다(0 응집 … 8 응축). **값을 바꾸면 저장된 도안이 깨진다.**

@export var id: StringName = &"radiate"
@export var display_name: String = "발산→"
## 발사 계약 코드 — 정본은 `Enums.GlyphCode`(9값). `RingBoard.G_GATHER`/`G_RADIATE`는 그 별칭이다.
@export var code: int = 1
## ⚠ **폐기 — 미사용** (세션 25). 문양은 오른쪽 셀을 **클릭해서** 고른다: 고르기 키가 없으니
## 힌트도 없다 (사용자: "q w 이런게 아니라 똑같이 마우스로 선택하는걸로해줘").
## 기존 .tres 호환을 위해 필드만 남긴다 — **새 코드에서 읽지 말 것**.
@export var key_hint: String = ""
## 화살표 방향: true=안쪽(룬)으로(응집) · false=바깥(진)으로(발산).
@export var inward: bool = false
## 조립 보드·책에서 문양을 그리는 색.
@export var ui_color: Color = Color(0.72, 0.28, 0.12)
## 짧은 설명 (책 셀 아래).
@export var desc: String = "바깥(진)으로"

## 🔴 이 문양이 쓰는 **알고리즘** — `GlyphRules.BEHAVIORS`의 키 중 하나 (세82 데이터화).
## `bolt`(칸 방향 탄) · `pillar`(착탄점 기둥) · `spread`(복제 산개) · `blast`(융합 광역).
## **계열(전개형/변형형)도 이 값이 답한다** — 별도 상수를 두지 않는다(옛 `Enums.MODIFIER_GLYPHS` 은퇴).
##
## ⚠ 기본값이 **빈 값**인 건 의도다: 갱신을 빠뜨린 `.tres`가 "직진탄으로 잘못 동작"하는 대신
## 미등록으로 걸려 **시끄럽게** 죽는다 (세50 「파일을 만들었다 ≠ 완료」와 같은 결).
@export var behavior: StringName = &""

## 알고리즘에 넘길 **수치**. 키는 알고리즘마다 다르고, 없는 키는 알고리즘 기본값을 쓴다.
##   spread: fan_deg · branch_mult · offset_px · min_branches
##   blast : base_radius_px · radius_per_branch · radius_per_count · min_radius_px
##           · merge_mult · merge_mult_per_count
##   bolt  : effect(&"" / &"pierce" / &"homing" / &"bounce" / &"thrust") · reach
##   pillar: 없음 (굵기는 연출 상수 PILLAR_SCALE_PER_GATHER — balance가 아니다)
##
## 🔴 **같은 알고리즘 + 다른 수치 = 다른 문양**이 이 축의 요점이다. 「확산 46°」 옆에
## 「돌풍 120°」를 `.tres` 한 장으로 세울 수 있다 — 응축이 폭발과 `blast`를 공유하는 게 그 첫 사례.
## ⚠ 키는 **String**으로 적는다(`.tres` 사전 리터럴이 받는 표기). `GlyphRules.param`이 정규화한다.
@export var params: Dictionary = {}
