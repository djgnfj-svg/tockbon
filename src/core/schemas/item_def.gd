class_name ItemDef
extends Resource
## 잉크·종이·장비·재료·탁본 조각 공통 정의 — data/items/*.tres (인스턴스 작성은 모듈 D 소유).

@export var id: StringName
@export var kind: Enums.ItemKind = Enums.ItemKind.MATERIAL
@export var grade: int = 1
@export var display_name: String = ""
## kind별 자유 파라미터 — 스키마 확장 대신 이 Dictionary를 쓴다 (TEAM_PLAN 규칙 3)
@export var params: Dictionary = {}
