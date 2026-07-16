class_name GlyphDef
extends Resource
## 문양 정의 — 룬과 진 **사이** 고리 칸을 채우는 조각. data/glyphs/*.tres. (세션 13 구조화)
##
## 옛 int const(RingBoard.G_GATHER/G_RADIATE)를 데이터로 뺀다 — 문양 어휘가 늘 때 코드가 아니라
## .tres를 늘린다. 낮 탁본으로 얻는 어휘가 이 목록으로 들어온다.
##
## 🔴 code = **발사 계약의 정수 코드** — ring_spell_system이 이 값으로 전개를 가른다.
##   0 = 응집(gather, 착탄점에 기둥) · 1 = 발산(radiate, 그 방향 탄환). **값을 바꾸면 발사가 깨진다.**

@export var id: StringName = &"radiate"
@export var display_name: String = "발산→"
## 발사 계약 코드 (RingBoard.G_* 와 같은 값). 0=응집, 1=발산.
@export var code: int = 1
## 키 힌트 (책 셀·안내). 예: "Q"/"W".
@export var key_hint: String = "W"
## 화살표 방향: true=안쪽(룬)으로(응집) · false=바깥(진)으로(발산).
@export var inward: bool = false
## 조립 보드·책에서 문양을 그리는 색.
@export var ui_color: Color = Color(0.72, 0.28, 0.12)
## 짧은 설명 (책 셀 아래).
@export var desc: String = "바깥(진)으로"
