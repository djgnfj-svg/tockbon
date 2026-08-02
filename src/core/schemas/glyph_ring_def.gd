class_name GlyphRingDef
extends Resource
## 문양-고리 정의 — data/glyph_rings/*.tres.
## 파밍 단위는 낱개 문양이 아니라 「미리 그려진 장식 고리 한 장」이다 — 진의 빈 밴드에 끼워 조립하면
## 그 조립본이 통째로 탁본 밑그림이 된다.
## 새 문양 어휘는 만들지 않는다 — `motif`가 기존 `GlyphDef.code`를 가리키고 가이드 점열은
## `RingBoard.glyph_guide_pts(motif,...)`를 count번 불러 절차적으로 만든다(= 새 고리 = .tres 한 장).

@export var id: StringName = &"gr_radiate5"
@export var display_name: String = "발산 고리 ×5"
## 모티프 = 착탄 특성. 🔴 `Enums.GlyphCode`와 같은 값 공간이다 — 발사 계약이 이 code로 슬롯을 전개한다.
@export var motif: int = 1
## 밴드 둘레에 몇 번 반복하나 (발산 ×5의 5). 조립본을 8칸으로 플래튼할 때 이 개수만큼 칸을 채운다.
@export var count: int = 5
## 조립 소켓 셀·가이드선을 그리는 색.
@export var ui_color: Color = Color(0.72, 0.28, 0.12, 1.0)
## 해금 id (codex). 빈 값 = 항상 보유. 패널이 해금된 고리만 보여준다.
@export var unlock_id: StringName = &""
## UI 열거 순서 (작을수록 앞). all_glyph_rings가 id가 아니라 이 값으로 정렬한다.
@export var sort: int = 0
