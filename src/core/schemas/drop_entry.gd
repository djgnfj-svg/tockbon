class_name DropEntry
extends Resource
## 드롭 테이블 한 줄 — EnemyDef.drops 에서 사용.

@export var item_id: StringName
@export_range(0.0, 1.0) var chance: float = 1.0
@export var min_count: int = 1
@export var max_count: int = 1
