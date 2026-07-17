extends Node
## 저장/로드 (TECH_SPEC §9) — 영구부(창고·도감·고리 도안)와 시간·마나.
## 자동 저장: 귀환·사망 확정(세이브스컴 방지)·하루 시작(취침 포함). 로드: 부팅 시 1회.
##
## 🔴 세션 22: 옛 SpellDesign 도안(user://save/designs)·연구 저장을 매장했다. 세이브 호환은 안전하다 —
## 로드가 전부 `data.get(키, 기본값)`이라 옛 세이브의 남은 키는 그냥 무시된다.

const SAVE_PATH := "user://save/save.json"
## 고리 도안(RingDesign) .tres 저장 위치.
const RING_DIR := "user://save/rings"

## 로드(또는 새 게임 확정) 이전의 자동 저장 방지
var _ready_to_save := false

## 🔴 **부팅 시 1회 로드** (세션 26 — 사용자 확정: *"켜면 이어서 한다"*).
##
## 세션 21 대청소가 **부팅 흐름을 지우면서 `load_game()`을 부르는 사람이 아무도 안 남았다.**
## 그래서 `_ready_to_save`가 영원히 false였고 → `save_game()`이 **전부 조용히 return**했다:
## 귀환·사망·하루시작 자동 저장이 셋 다 no-op이었고, **게임을 껐다 켜면 그린 마법진이
## 통째로 사라졌다.** 에러도 경고도 없다 — 세이브가 아예 안 만들어지니 로드가 실패할 일도 없다.
## 세션 26에 숲 귀환을 붙이면서 드러났다 (`extraction_success`를 쏴도 아무 일도 안 났다).
##
## 🔴 **여기가 부를 자리인 이유**: SaveManager는 오토로드 **마지막**이라(project.godot) GameState·
## Clock·Db가 이미 서 있고, 오토로드는 **부팅에 딱 한 번** _ready한다. 씬에서 부르면 안 된다 —
## `base.tscn`은 숲에서 돌아올 때마다 다시 _ready하므로 **귀환할 때마다 세이브를 덮어 로드해**
## 그 판의 진행을 날린다.
##
## 세이브가 없으면 `load_game()`이 false를 돌려주고 `_ready_to_save`만 켠다 = 새 게임.
func _ready() -> void:
	EventBus.extraction_success.connect(save_game)
	EventBus.bag_lost.connect(save_game)
	EventBus.day_started.connect(func(_day: int) -> void:
		if _ready_to_save:
			save_game())
	load_game()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	if not _ready_to_save:
		return
	# 고리 도안 저장 — 파일 목록 + 장착 인덱스
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
		"ring_designs": ring_files,
		"ring_equipped": ring_equipped_idx,
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

	# 고리 도안 복원
	GameState.ring_designs.clear()
	for path: String in data.get("ring_designs", []):
		# 캐시 우회 — 같은 세션에서 저장→로드 시 인스턴스 재사용으로 복원이 무효화되는 것 방지
		var rres := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		var rdesign := rres as RingDesign
		if rdesign != null:
			GameState.ring_designs.append(rdesign)
	var ring_equipped_idx: Array = data.get("ring_equipped", [])
	for slot in range(GameState.EQUIP_SLOTS):
		var ridx: int = int(ring_equipped_idx[slot]) if slot < ring_equipped_idx.size() else -1
		GameState.ring_equipped[slot] = GameState.ring_designs[ridx] if ridx >= 0 and ridx < GameState.ring_designs.size() else null

	EventBus.resources_changed.emit()
	_ready_to_save = true
	return true

## 테스트·디버그용 — 세이브 전체 삭제
func wipe_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_prune_ring_files(0)

## ring_N.tres 중 인덱스가 keep_count 이상인 것을 지운다 (도안이 줄면 남은 파일이 되살아나는 것 방지)
func _prune_ring_files(keep_count: int) -> void:
	var dir := DirAccess.open(RING_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		if file_name.begins_with("ring_") and file_name.ends_with(".tres"):
			var idx := int(file_name.trim_prefix("ring_").trim_suffix(".tres"))
			if idx >= keep_count:
				dir.remove(file_name)
