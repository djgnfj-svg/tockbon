extends Node
## 전역 상태 원장 — 자원·장착 4장·가방·도감 (TECH_SPEC §3).
## 모듈은 이 API로만 자원을 만진다. inventory에 직접 접근하지 말 것.

const EQUIP_SLOTS := 4

var balance: BalanceData = preload("res://data/balance.tres")

var mana: float
## {item_id: count} — 창고 (영구, 사망에도 유지)
var inventory: Dictionary = {}
## 출격 중 획득 [{ "id": StringName, "count": int }] — 사망 시 손실
var bag: Array[Dictionary] = []
## 장착 도안 4장 — 아침에 확정, 필드 교체 불가 (GDD §4.4)
var equipped: Array[SpellDesign] = [null, null, null, null]
## 보유 도안 전체 (거점 보관)
var designs: Array[SpellDesign] = []
## {unlock_id: true} — 도감 영구 해금 (룬·제법·적 정보)
var codex: Dictionary = {}

func _ready() -> void:
	mana = balance.mana_max
	EventBus.extraction_success.connect(_on_extraction_success)
	EventBus.bag_lost.connect(func() -> void: bag.clear())
	EventBus.research_completed.connect(func(unlock_id: StringName) -> void: codex[unlock_id] = true)
	EventBus.codex_unlocked.connect(func(unlock_id: StringName) -> void: codex[unlock_id] = true)

func _process(delta: float) -> void:
	mana = minf(mana + balance.mana_regen_per_sec * delta, balance.mana_max)

func spend_mana(amount: float) -> bool:
	if mana < amount:
		return false
	mana -= amount
	return true

func restore_mana_full() -> void:
	mana = balance.mana_max

# ── 창고 (영구)

func add_item(item_id: StringName, count: int = 1) -> void:
	inventory[item_id] = int(inventory.get(item_id, 0)) + count
	EventBus.resources_changed.emit()

func remove_item(item_id: StringName, count: int = 1) -> bool:
	if get_count(item_id) < count:
		return false
	inventory[item_id] = int(inventory[item_id]) - count
	EventBus.resources_changed.emit()
	return true

func get_count(item_id: StringName) -> int:
	return int(inventory.get(item_id, 0))

## 창고 열람용 사본 — UI 표시 등 읽기 전용 순회는 이것을 쓴다
func get_inventory_snapshot() -> Dictionary:
	return inventory.duplicate()

## cost = {item_id: amount}
func can_afford(cost: Dictionary) -> bool:
	for item_id: StringName in cost:
		if get_count(item_id) < int(cost[item_id]):
			return false
	return true

func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for item_id: StringName in cost:
		remove_item(item_id, int(cost[item_id]))
	return true

# ── 가방 (출격 중 — 사망 시 손실)

func add_to_bag(item_id: StringName, count: int = 1) -> void:
	bag.append({"id": item_id, "count": count})

func _on_extraction_success() -> void:
	for entry: Dictionary in bag:
		add_item(entry["id"], entry["count"])
	bag.clear()

# ── 장착·도감

func equip(slot: int, design: SpellDesign) -> void:
	equipped[slot] = design

func is_unlocked(unlock_id: StringName) -> bool:
	return bool(codex.get(unlock_id, false))
