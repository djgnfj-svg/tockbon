class_name RuneDef
extends Resource
## 룬 정의 — data/runes/*.tres (인스턴스 작성은 모듈 B 소유).

@export var type: Enums.RuneType = Enums.RuneType.FIRE
@export var display_name: String = ""
@export var base_damage: float = 10.0
@export var status: Enums.Status = Enums.Status.NONE
@export var status_power: float = 0.0
@export var projectile_scene: PackedScene
## 조립 보드에서 중심 룬을 그리는 색 (세션 13 구조화 — UI가 하드코딩 대신 이걸 읽는다).
@export var ui_color: Color = Color(0.62, 0.22, 0.12)
