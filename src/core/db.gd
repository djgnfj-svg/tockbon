extends Node
## data/ 리소스 레지스트리 — 룬·적·아이템 정의 조회 (TECH_SPEC §3).
## .tres 인스턴스 작성: 룬=모듈 B / 적=모듈 C / 아이템=모듈 D.

## {Enums.RuneType: RuneDef}
var runes: Dictionary = {}
## {StringName: EnemyDef}
var enemies: Dictionary = {}
## {StringName: ItemDef}
var items: Dictionary = {}
## {StringName: JinDef} — 고리 조립 진 (세션 13 구조화)
var jins: Dictionary = {}
## {StringName: GlyphDef} — 고리 조립 문양 (세션 13 구조화)
var glyphs: Dictionary = {}

func _ready() -> void:
	reload()

func reload() -> void:
	runes.clear()
	enemies.clear()
	items.clear()
	jins.clear()
	glyphs.clear()
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
	for res in _load_dir("res://data/jin"):
		var jin := res as JinDef
		if jin:
			jins[jin.id] = jin
	for res in _load_dir("res://data/glyphs"):
		var glyph := res as GlyphDef
		if glyph:
			glyphs[glyph.id] = glyph

func get_rune(type: Enums.RuneType) -> RuneDef:
	return runes.get(type) as RuneDef

func get_enemy(id: StringName) -> EnemyDef:
	return enemies.get(id) as EnemyDef

func get_item(id: StringName) -> ItemDef:
	return items.get(id) as ItemDef

func get_jin(id: StringName) -> JinDef:
	return jins.get(id) as JinDef

func get_glyph(id: StringName) -> GlyphDef:
	return glyphs.get(id) as GlyphDef

## 진 목록 — id 오름차순 (UI 열거용).
func all_jins() -> Array[JinDef]:
	var out: Array[JinDef] = []
	var keys := jins.keys()
	keys.sort()
	for k in keys:
		out.append(jins[k])
	return out

## 문양 목록 — **code 오름차순** (응집0·발산1). UI 셀 순서·Q/W 대응이 이 순서다.
func all_glyphs() -> Array[GlyphDef]:
	var out: Array[GlyphDef] = []
	for g in glyphs.values():
		out.append(g)
	out.sort_custom(func(a: GlyphDef, b: GlyphDef) -> bool: return a.code < b.code)
	return out

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
