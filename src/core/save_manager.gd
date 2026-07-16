extends Node
## 저장/로드 (TECH_SPEC §9) — 영구부(창고·도감·도안·연구)와 시간·마나.
## 자동 저장: 귀환·사망 확정(세이브스컴 방지)·하루 시작(취침 포함). 로드: 부팅 시 Main이 1회 호출.
## 도안은 user://save/designs/*.tres (strokes 포함 — 재편집·수리 렌더에 필요).

# core→base 참조는 원칙 위반이지만 연구 상태(static 2개)가 아직 GameState 밖에 있어 실용적 예외.
# 연구 상태가 GameState로 이관되면 이 preload를 제거한다.
const ResearchService := preload("res://src/base/research_service.gd")

const SAVE_PATH := "user://save/save.json"
const DESIGN_DIR := "user://save/designs"
## 🔴 #17 2단계 — 고리 도안(RingDesign) .tres 저장 위치. 옛 designs와 평행(병행 은퇴).
const RING_DIR := "user://save/rings"

## 로드(또는 새 게임 확정) 이전의 자동 저장 방지
var _ready_to_save := false

func _ready() -> void:
	EventBus.extraction_success.connect(save_game)
	EventBus.bag_lost.connect(save_game)
	EventBus.day_started.connect(func(_day: int) -> void:
		if _ready_to_save:
			save_game())

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	if not _ready_to_save:
		return
	DirAccess.make_dir_recursive_absolute(DESIGN_DIR)
	var design_files: Array = []
	for i in range(GameState.designs.size()):
		var path := "%s/design_%d.tres" % [DESIGN_DIR, i]
		ResourceSaver.save(GameState.designs[i], path)
		design_files.append(path)
	_prune_design_files(GameState.designs.size())

	var equipped_idx: Array = []
	for design: SpellDesign in GameState.equipped:
		equipped_idx.append(GameState.designs.find(design))

	# 🔴 #17 2단계 — 고리 도안 저장 (옛 designs와 같은 방식: 파일 목록 + 장착 인덱스)
	DirAccess.make_dir_recursive_absolute(RING_DIR)
	var ring_files: Array = []
	for i in range(GameState.ring_designs.size()):
		var rpath := "%s/ring_%d.tres" % [RING_DIR, i]
		ResourceSaver.save(GameState.ring_designs[i], rpath)
		ring_files.append(rpath)
	_prune_ring_files(GameState.ring_designs.size())
	var ring_equipped_idx: Array = []
	for rdesign: RingDesign in GameState.ring_equipped:
		ring_equipped_idx.append(GameState.ring_designs.find(rdesign))

	var inventory: Dictionary = {}
	for item_id: StringName in GameState.inventory:
		inventory[String(item_id)] = int(GameState.inventory[item_id])
	var equipment: Dictionary = {}
	for kind: int in GameState.equipment:
		equipment[str(kind)] = String(GameState.equipment[kind])
	var codex: Array = []
	for unlock_id: StringName in GameState.codex:
		if GameState.codex[unlock_id]:
			codex.append(String(unlock_id))

	var data := {
		"version": 1,
		"day": Clock.day,
		"time_sec": Clock.time_sec,
		"mana": GameState.mana,
		"inventory": inventory,
		"equipment": equipment,
		"codex": codex,
		"designs": design_files,
		"equipped": equipped_idx,
		"ring_designs": ring_files,
		"ring_equipped": ring_equipped_idx,
		"research_id": String(ResearchService.current_id),
		"research_started": ResearchService.started_at_sec,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("저장 실패: %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

## 성공 시 true. 세이브가 없거나 손상이면 false (새 게임 — 호출측이 시드).
func load_game() -> bool:
	if not has_save():
		_ready_to_save = true
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("세이브 파일 손상 — 새 게임으로 시작: %s" % SAVE_PATH)
		_ready_to_save = true
		return false

	Clock.day = int(data.get("day", 1))
	Clock.time_sec = float(data.get("time_sec", 0.0))

	GameState.inventory.clear()
	var inventory: Dictionary = data.get("inventory", {})
	for key: String in inventory:
		GameState.inventory[StringName(key)] = int(inventory[key])
	GameState.equipment.clear()
	var equipment: Dictionary = data.get("equipment", {})
	for key: String in equipment:
		GameState.equipment[int(key)] = StringName(equipment[key])
	# 마나는 장비(로브 상한) 복원 후에 — 상한 getter 기준으로 클램프
	GameState.mana = minf(float(data.get("mana", GameState.mana_max())), GameState.mana_max())
	for key: String in data.get("codex", []):
		GameState.codex[StringName(key)] = true

	GameState.designs.clear()
	for path: String in data.get("designs", []):
		# 캐시 우회 — 같은 세션에서 저장→로드 시 인스턴스 재사용으로 복원이 무효화되는 것 방지
		var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		var design := res as SpellDesign
		if design != null:
			design.migrate_legacy_runes()  # v2.2: 옛 충격(=1) 룬 → FIRE
			GameState.designs.append(design)

	var equipped_idx: Array = data.get("equipped", [])
	for slot in range(GameState.EQUIP_SLOTS):
		var idx: int = int(equipped_idx[slot]) if slot < equipped_idx.size() else -1
		GameState.equipped[slot] = GameState.designs[idx] if idx >= 0 and idx < GameState.designs.size() else null

	# 🔴 #17 2단계 — 고리 도안 복원 (옛 designs와 같은 방식)
	GameState.ring_designs.clear()
	for path: String in data.get("ring_designs", []):
		var rres := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		var rdesign := rres as RingDesign
		if rdesign != null:
			GameState.ring_designs.append(rdesign)
	var ring_equipped_idx: Array = data.get("ring_equipped", [])
	for slot in range(GameState.EQUIP_SLOTS):
		var ridx: int = int(ring_equipped_idx[slot]) if slot < ring_equipped_idx.size() else -1
		GameState.ring_equipped[slot] = GameState.ring_designs[ridx] if ridx >= 0 and ridx < GameState.ring_designs.size() else null

	ResearchService.current_id = StringName(String(data.get("research_id", "")))
	ResearchService.started_at_sec = float(data.get("research_started", -1.0))

	EventBus.resources_changed.emit()
	_ready_to_save = true
	return true

## 테스트·디버그용 — 세이브 전체 삭제
func wipe_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_prune_design_files(0)
	_prune_ring_files(0)

func _prune_design_files(keep_count: int) -> void:
	_prune_indexed_files(DESIGN_DIR, "design_", keep_count)

func _prune_ring_files(keep_count: int) -> void:
	_prune_indexed_files(RING_DIR, "ring_", keep_count)

## <prefix>N.tres 중 인덱스가 keep_count 이상인 것을 지운다 (도안·고리 공용)
func _prune_indexed_files(dir_path: String, prefix: String, keep_count: int) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name in dir.get_files():
		if file_name.begins_with(prefix) and file_name.ends_with(".tres"):
			var idx := int(file_name.trim_prefix(prefix).trim_suffix(".tres"))
			if idx >= keep_count:
				dir.remove(file_name)
