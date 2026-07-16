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
## 착용 장비 {Enums.ItemKind.WAND/ROBE/CHARM: item_id} — 가방 아님, 사망에도 보존 (GDD §5)
var equipment: Dictionary = {}
## 🔴 고리 도안 — **유일한 마법진 모델** (세션 22에 옛 designs/equipped를 매장했다).
##   ring_designs = 보관 전체 · ring_equipped = 장착 4장.
var ring_designs: Array[RingDesign] = []
var ring_equipped: Array[RingDesign] = [null, null, null, null]
## {unlock_id: true} — 도감 영구 해금 (룬·제법·적 정보)
var codex: Dictionary = {}
## UI 모달(게시판·장착·도감) 열림 — ui_root가 설정, 플레이어 이동 계열이 폴링 (TECH_SPEC §4.2)
var ui_modal_open: bool = false

func _ready() -> void:
	mana = mana_max()
	hp = hp_max()
	# 시작 해금 — 튜토가 가르치는 불 룬 + 추진 문양 (v2.2, TRUTH §4 세션 14: 충격 룬 폐지)
	codex[&"rune_fire"] = true
	codex[&"glyph_thrust"] = true
	EventBus.extraction_success.connect(_on_extraction_success)
	EventBus.bag_lost.connect(func() -> void: bag.clear())
	EventBus.codex_unlocked.connect(func(unlock_id: StringName) -> void: codex[unlock_id] = true)
	EventBus.ring_design_committed.connect(_on_ring_design_committed)

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

## 손에 든 지팡이의 **발사 패턴** — v2.0 지팡이 축 (TECH_SPEC §4.0-a).
## 사용자: *"지팡이에 따라 여러 발이 나가거나 내 주변에서 전체 방향으로 나가거나가 정해짐."*
##
## 🔴 **스키마를 안 늘렸다.** `ItemDef.params["wand_pattern"]`을 읽을 뿐이라 **새 지팡이는
## .tres 하나 추가하면 끝**이다 (선례: hp_max_add·stroke_correct_add). 미착용이면 단발.
func wand_pattern() -> int:
	return int(gear_param(Enums.ItemKind.WAND, "wand_pattern",
		float(Enums.WandPattern.SINGLE)))

## 🔴 획 보정 강도 (0..1) — 그은 획을 가이드 쪽으로 **얼마나 끌어당기는가** (0=안 당김, 1=정답선).
## **보정은 펜 아이템으로 산다** (사용자 확정 2026-07-17: *"펜등급마다 보정도가 오르는거임"*).
## data/items/pen_*.tres의 `params["correction"]` — 새 펜 = **.tres 한 장**이다 (선례: 잉크 3등급).
##
## 🔴 **기본값은 0이다** — 펜을 안 끼면 손이 그린 궤적이 **그대로** 남는다(자기만의 마법진,
## memory takbon-hand-trace-commit). 펜은 그 개성을 덜어내고 정확도를 사는 **교환**이다.
## ⚠ 세션 23 전엔 balance(0.55)를 바닥에 깔고 WAND 부위에서 읽었다 — 맨손에도 보정이 붙는
## 셈이라 정체성과 어긋났고, **호출자가 0이라 실제로 돌지도 않았다**(옛 자유드로잉 잔재).
func stroke_correction() -> float:
	return clampf(gear_param(Enums.ItemKind.PEN, "correction", 0.0), 0.0, 1.0)

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

## 🔴 고리 도안이 맺혔다 — 보관고에 넣고 빈 슬롯이 있으면 즉시 장착한다.
## 맺은 직후 바로 쏴볼 수 있어야 흐름이 안 끊긴다 (첫 진 = 슬롯 1).
## 슬롯이 꽉 찼으면 보관만 한다 (GDD §4.4 — 필드 교체 불가는 유지).
func _on_ring_design_committed(design: RingDesign) -> void:
	if design == null:
		return
	ring_designs.append(design)
	for slot in range(EQUIP_SLOTS):
		if ring_equipped[slot] == null:
			ring_equipped[slot] = design
			return

func is_unlocked(unlock_id: StringName) -> bool:
	return bool(codex.get(unlock_id, false))
