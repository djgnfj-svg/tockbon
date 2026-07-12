extends RefCounted
## 적 팩토리 — EnemyDef.id → 스크립트 매핑. field.gd와 테스트가 공용 (모듈 C).

const SCRIPTS := {
	&"vine": preload("res://src/field/enemy_vine.gd"),
	&"hound": preload("res://src/field/enemy_hound.gd"),
	&"slime": preload("res://src/field/enemy_slime.gd"),
	&"slime_elite": preload("res://src/field/enemy_slime.gd"),
	&"mist": preload("res://src/field/enemy_mist.gd"),
	&"beetle": preload("res://src/field/enemy_beetle.gd"),
}

static func spawn(def: EnemyDef) -> CharacterBody2D:
	if def == null:
		push_warning("enemy_spawner: def가 null")
		return null
	var script: GDScript = SCRIPTS.get(def.id)
	if script == null:
		push_warning("enemy_spawner: 알 수 없는 적 id: %s" % def.id)
		return null
	var enemy: Variant = script.new()
	enemy.def = def
	return enemy as CharacterBody2D
