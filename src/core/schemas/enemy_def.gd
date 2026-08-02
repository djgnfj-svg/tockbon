class_name EnemyDef
extends Resource
## 적 정의 — data/enemies/*.tres.

@export var id: StringName
@export var display_name: String = ""
@export var hp: float = 30.0
## 약점 룬 — 표기용이 아니라 전투에 실재한다: `forest_enemy.take_hit`이 이 룬에
## `params.weakness_mult`를 곱한다. 값을 바꾸면 보스 피해량이 조용히 달라진다.
@export var counter_rune: Enums.RuneType = Enums.RuneType.FIRE
## false = 약점 없음 (counter_rune 무시).
@export var has_counter: bool = true
## 전투 수치 자유 파라미터 (속도·접촉 피해·사거리 등) — 스키마 확장 대신 이것을 쓴다.
@export var params: Dictionary = {}
@export var drops: Array[DropEntry] = []
