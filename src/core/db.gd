extends Node
## data/ 리소스 레지스트리 — 룬·적·아이템 정의 조회 (TECH_SPEC §3).
## .tres 인스턴스 작성: 룬=모듈 B / 적=모듈 C / 아이템=모듈 D.

## {Enums.RuneType: RuneDef}
var runes: Dictionary = {}
## {StringName: EnemyDef}
var enemies: Dictionary = {}
## {StringName: ItemDef}
var items: Dictionary = {}

func _ready() -> void:
	reload()

func reload() -> void:
	runes.clear()
	enemies.clear()
	items.clear()
	for res in _load_dir("res://data/runes"):
		var rune := res as RuneDef
		if rune:
			runes[rune.type] = rune
	for res in _load_dir("res://data/enemies"):
		var enemy := res as EnemyDef
		if enemy:
			enemies[enemy.id] = enemy
	for res in _load_dir("res://data/items"):
		var item := res as ItemDef
		if item:
			items[item.id] = item

func get_rune(type: Enums.RuneType) -> RuneDef:
	return runes.get(type) as RuneDef

func get_enemy(id: StringName) -> EnemyDef:
	return enemies.get(id) as EnemyDef

func get_item(id: StringName) -> ItemDef:
	return items.get(id) as ItemDef

func _load_dir(path: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	for file in dir.get_files():
		# 익스포트 빌드에서는 .tres가 .tres.remap으로 바뀌므로 양쪽 처리
		var clean := file.trim_suffix(".remap")
		if clean.ends_with(".tres") or clean.ends_with(".res"):
			var res := load(path.path_join(clean)) as Resource
			if res:
				out.append(res)
	return out
