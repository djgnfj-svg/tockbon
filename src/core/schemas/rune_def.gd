class_name RuneDef
extends Resource
## 룬 정의 — data/runes/*.tres (인스턴스 작성은 모듈 B 소유).

@export var type: Enums.RuneType = Enums.RuneType.FIRE
@export var display_name: String = ""
@export var base_damage: float = 10.0
@export var status: Enums.Status = Enums.Status.NONE
@export var status_power: float = 0.0
@export var projectile_scene: PackedScene
