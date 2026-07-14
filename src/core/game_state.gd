extends Node
## 전역 상태 원장 — 자원·장착 4장·가방·도감 (TECH_SPEC §3).
## 모듈은 이 API로만 자원을 만진다. inventory에 직접 접근하지 말 것.

const EQUIP_SLOTS := 4

var balance: BalanceData = preload("res://data/balance.tres")

var mana: float
## 플레이어 HP — 출격 시 reset, 표시·판정의 단일 원장 (v1.1: C 로컬에서 이관)
var hp: float
## {item_id: count} — 창고 (영구, 사망에도 유지)
var inventory: Dictionary = {}
## 출격 중 획득 [{ "id": StringName, "count": int }] — 사망 시 손실
var bag: Array[Dictionary] = []
## 장착 도안 4장 — 아침에 확정, 필드 교체 불가 (GDD §4.4)
var equipped: Array[SpellDesign] = [null, null, null, null]
## 착용 장비 {Enums.ItemKind.WAND/ROBE/CHARM: item_id} — 가방 아님, 사망에도 보존 (GDD §5)
var equipment: Dictionary = {}
## 보유 도안 전체 (거점 보관)
var designs: Array[SpellDesign] = []
## {unlock_id: true} — 도감 영구 해금 (룬·제법·적 정보)
var codex: Dictionary = {}
## UI 모달(게시판·장착·도감) 열림 — ui_root가 설정, 플레이어 이동 계열이 폴링 (TECH_SPEC §4.2)
var ui_modal_open: bool = false

func _ready() -> void:
	mana = mana_max()
	hp = hp_max()
	# 시작 해금 — 튜토리얼 지급 룬 (TECH_SPEC §5.1)
	codex[&"rune_fire"] = true
	codex[&"rune_impact"] = true
	EventBus.extraction_success.connect(_on_extraction_success)
	EventBus.bag_lost.connect(func() -> void: bag.clear())
	EventBus.research_completed.connect(func(unlock_id: StringName) -> void: codex[unlock_id] = true)
	EventBus.codex_unlocked.connect(func(unlock_id: StringName) -> void: codex[unlock_id] = true)
	EventBus.design_created.connect(_on_design_created)

func _process(delta: float) -> void:
	mana = minf(mana + balance.mana_regen_per_sec * delta, mana_max())

func spend_mana(amount: float) -> bool:
	if mana < amount:
		return false
	mana -= amount
	return true

func restore_mana_full() -> void:
	mana = mana_max()

# ── 파생 스탯 — balance 기본값 + 장비 보정 (TECH_SPEC §4.2). balance 직접 참조 금지, 전부 이 getter

func mana_max() -> float:
	return balance.mana_max + gear_param(Enums.ItemKind.ROBE, "mana_max_add", 0.0)

func hp_max() -> float:
	return balance.player_hp_max + gear_param(Enums.ItemKind.ROBE, "hp_max_add", 0.0)

## 획 자동보정 강도 (0..1) — 획을 뗄 때 본보기 쪽으로 얼마나 끌어당기는가.
## **보정은 아이템으로 산다** (사용자 확정): 좋은 붓이 형을 잡아 준다. 지금은 붓 = 완드 부위에
## 걸어 두었다 — 별도 '붓' 부위가 생기면 **이 함수 한 줄만** 바꾸면 된다 (그래서 getter다).
## 아직 stroke_correct_add를 가진 아이템은 없다 — 자리만 열어 둔 상태다
func stroke_correction() -> float:
	return clampf(balance.stroke_correct_strength
		+ gear_param(Enums.ItemKind.WAND, "stroke_correct_add", 0.0), 0.0, 1.0)

# ── 장비 착용 (TECH_SPEC §4.2) — 창고에 있는 장비만, 착용품은 사망에도 보존

## 착용 장비의 params 값 조회 — 해당 부위 미착용이면 default
func gear_param(kind: int, key: String, default: float) -> float:
	if not equipment.has(kind):
		return default
	var def: ItemDef = Db.get_item(equipment[kind])
	if def == null:
		return default
	return float(def.params.get(key, default))

## 창고의 장비를 착용 — 창고에서 1개 차감, 기존 착용품은 창고 반환. 성공 시 true
func equip_gear(item_id: StringName) -> bool:
	var def: ItemDef = Db.get_item(item_id)
	if def == null or def.kind not in [Enums.ItemKind.WAND, Enums.ItemKind.ROBE, Enums.ItemKind.CHARM]:
		return false
	if get_count(item_id) < 1:
		return false
	remove_item(item_id)
	if equipment.has(def.kind):
		add_item(equipment[def.kind])
	equipment[def.kind] = item_id
	_after_equipment_changed()
	return true

func unequip_gear(kind: int) -> void:
	if not equipment.has(kind):
		return
	add_item(equipment[kind])
	equipment.erase(kind)
	_after_equipment_changed()

func _after_equipment_changed() -> void:
	# 로브 교체로 상한이 줄면 현재값 클램프 (TECH_SPEC §4.2)
	hp = minf(hp, hp_max())
	mana = minf(mana, mana_max())
	EventBus.player_hp_changed.emit(hp, hp_max())
	EventBus.equipment_changed.emit()

# ── 플레이어 HP

func damage_player(amount: float) -> void:
	hp = maxf(0.0, hp - amount)
	EventBus.player_hp_changed.emit(hp, hp_max())

func heal_player(amount: float) -> void:
	hp = minf(hp + amount, hp_max())
	EventBus.player_hp_changed.emit(hp, hp_max())

func reset_player_hp() -> void:
	hp = hp_max()
	EventBus.player_hp_changed.emit(hp, hp_max())

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

## 새 도안은 보관고에 들어가고, 빈 슬롯이 있으면 즉시 장착된다.
## 그린 직후 바로 쏴볼 수 있어야 온보딩이 끊기지 않는다 (첫 도안 = 슬롯 1).
## 슬롯이 꽉 찼으면 장착은 아침 게시판에서 (GDD §4.4 — 필드 교체 불가는 유지).
func _on_design_created(design: SpellDesign) -> void:
	designs.append(design)
	for slot in range(EQUIP_SLOTS):
		if equipped[slot] == null:
			equipped[slot] = design
			return

func is_unlocked(unlock_id: StringName) -> bool:
	return bool(codex.get(unlock_id, false))
