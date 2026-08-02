class_name RuneDef
extends Resource
## 룬 정의 — data/runes/*.tres.

@export var type: Enums.RuneType = Enums.RuneType.FIRE
## 도감 해금 키 `rune_<명>` (fragment의 unlock_id와 짝).
## 🔴 비면 조립 책이 영영 안 띄운다 — 항상 잠긴 셈이 된다.
@export var unlock_id: StringName = &""
@export var display_name: String = ""
@export var base_damage: float = 10.0
@export var status: Enums.Status = Enums.Status.NONE
@export var status_power: float = 0.0
@export var projectile_scene: PackedScene
## 조립 보드가 중심 룬을 그리는 색 (UI 하드코딩 대신 이걸 읽는다).
@export var ui_color: Color = Color(0.62, 0.22, 0.12)
