extends Node
## 전역 상태 원장 — 자원·장착 4장·가방·도감 (TECH_SPEC §3).
## 모듈은 이 API로만 자원을 만진다. inventory에 직접 접근하지 말 것.

const EQUIP_SLOTS := 4

var balance: BalanceData = preload("res://data/balance.tres")

var mana: float
## 플레이어 HP — 출격 시 reset, 표시·판정의 단일 원장 (v1.1: C 로컬에서 이관)
var hp: float
## 포만 게이지 (세션 35) — **숲에 있는 동안만** 준다. 0이면 굶어 HP가 깎인다. 베이스=늘 만복.
var hunger: float
## 숲에 있나 — 허기는 이때만 준다. forest/base `_ready`가 설정 (오토로드라 씬 전환에도 남음).
var in_expedition: bool = false
var _starve_accum: float = 0.0
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
## 🔴 퀘스트 진행 (세션36, "진행 목표 = 깊이 스파인"). 둘 다 영구 저장.
##   quest_progress = {quest_id: 현재 카운트} · quest_done = {quest_id: true}.
## 퀘스트는 순수 오버레이다 — EventBus 이벤트(처치·귀환·해금)를 여기서 관찰해 카운트를 올릴 뿐,
## 룬 해금 사슬을 전혀 안 건드린다. 진행 상태·완료 판정·보상 지급이 전부 이 원장에서 닫힌다.
var quest_progress: Dictionary = {}
var quest_done: Dictionary = {}
## UI 모달(게시판·장착·도감) 열림 — ui_root가 설정, 플레이어 이동 계열이 폴링 (TECH_SPEC §4.2)
var ui_modal_open: bool = false

func _ready() -> void:
	mana = mana_max()
	hp = hp_max()
	hunger = hunger_max()
	_seed_starting_unlocks()
	EventBus.extraction_success.connect(_on_extraction_success)
	EventBus.bag_lost.connect(func() -> void: bag.clear())
	# 🔴 해금은 codex에 심고 **UNLOCK 퀘스트도 진행**한다 (세션36). 세션21~35엔 codex만 심었다.
	EventBus.codex_unlocked.connect(_on_codex_unlocked)
	# 🔴 적 처치 → KILL 퀘스트 진행 (세션36). forest_enemy._die가 발신.
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.ring_design_committed.connect(_on_ring_design_committed)

## 🔴 시작 해금 재시드 — 튜토가 가르치는 불 룬 + 추진 문양 (v2.2, TRUTH §4 세션 14: 충격 룬 폐지).
## _ready(첫 부팅)와 new_game(새로하기)이 **둘 다** 이걸 부른다. 여기 한 곳에만 두는 이유:
## save_manager 노트가 경고한 "새로하기는 _ready를 다시 안 타므로 여기 시드를 안 심으면
## **아무것도 못 그리는 새 게임**이 된다" — 두 경로가 갈라지면 조용히 그 버그가 난다.
## 🔴 시작엔 룬·문양만 심는다. **장비도 스테이션(station_*)도 없다** — 빈 시작(세션37, 사용자
## 확정: "시작했을 때 아무것도 없는 상태가 중요"). 거점은 재료로 직접 지어 채운다.
func _seed_starting_unlocks() -> void:
	codex[&"rune_fire"] = true
	codex[&"glyph_thrust"] = true

## 🔴 **진짜 새로하기** (세션37, F8). save_manager 노트가 적어 둔 계약: `save_game()`이 쓰는 것
## 전부 + `bag`·`hp` + **시작 해금 재시드**를 한 곳에서 처리한다. 씬마다 손으로 비우면 필드가
## 늘 때 조용히 갈라지므로 core에 하나 둔다. wipe_save(파일 삭제)와 짝 — SaveManager가 부른다.
## ⚠ GameState·Clock은 오토로드라 메모리에 살아 있다 — 파일만 지우면 옛 진행이 도로 써진다
## (실측 확인, 세션26). 그래서 **메모리를 여기서 비운다**.
func new_game() -> void:
	Clock.day = 1
	Clock.time_sec = 0.0
	inventory.clear()
	bag.clear()
	equipment.clear()          # 🔴 장비 벗김 — 맨손 시작 (사용자 확정 세션37)
	ring_designs.clear()
	ring_equipped = [null, null, null, null]
	codex.clear()
	quest_progress.clear()
	quest_done.clear()
	in_expedition = false
	_starve_accum = 0.0
	_seed_starting_unlocks()   # 룬·문양만 — _ready와 동일 (분기 방지)
	hp = hp_max()
	mana = mana_max()
	hunger = hunger_max()
	# 구독 UI(HUD·창고·퀘스트 패널)를 새 빈 상태로 깨운다 — 로드 경로(save_manager)와 같은 3종.
	EventBus.player_hp_changed.emit(hp, hp_max())
	EventBus.equipment_changed.emit()
	EventBus.resources_changed.emit()

func _process(delta: float) -> void:
	mana = minf(mana + balance.mana_regen_per_sec * delta, mana_max())
	if in_expedition:
		_tick_hunger(delta)

## 숲에 있는 동안만 불린다 (in_expedition). 포만이 남았으면 줄이고, 0이면 1초 간격으로 굶어 HP↓.
## 🔴 굶주림 피해는 **tick**이다 — damage_player를 매 프레임 부르면 아픔음(player_hp_changed 훅)이
## 도배된다. accum으로 1초에 한 번만 때린다.
func _tick_hunger(delta: float) -> void:
	if hunger > 0.0:
		hunger = maxf(0.0, hunger - balance.hunger_drain_per_sec * delta)
		_starve_accum = 0.0
		return
	_starve_accum += delta
	if _starve_accum >= 1.0:
		_starve_accum -= 1.0
		damage_player(balance.starve_damage_per_tick)

func hunger_max() -> float:
	return balance.hunger_max

## 만복으로 되돌린다 — 출격(만복으로 시작)·귀환(집에서 배를 채움) 양쪽이 부른다.
func restore_hunger_full() -> void:
	hunger = hunger_max()
	_starve_accum = 0.0

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
	if def == null or def.kind not in [Enums.ItemKind.WAND, Enums.ItemKind.ROBE, Enums.ItemKind.CHARM, Enums.ItemKind.PEN]:
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
	# 🔴 창고(add_item)와 대칭 — 인벤 UI가 이 시그널로 갱신한다. 안 쏘면 열어 둔 가방 구역이 안 는다.
	EventBus.resources_changed.emit()

func _on_extraction_success() -> void:
	for entry: Dictionary in bag:
		add_item(entry["id"], entry["count"])
	bag.clear()
	# 🔴 보상 지급 후에 EXTRACT 퀘스트를 센다 (세션36) — 살아 돌아온 것 자체가 목표다.
	advance_quests(Enums.QuestGoal.EXTRACT, &"")

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

# ── 퀘스트 (진행 목표 = 깊이 스파인, 세션36) ─────────────────────────────
# 🔴 순수 오버레이: EventBus 이벤트를 관찰해 카운트를 올리고, 목표에 닿으면 보상을 주고
#    다음 퀘스트를 연다(requires 사슬 = 스파인). 룬 해금 사슬은 전혀 안 건드린다.
#    새 퀘스트 = data/quests/*.tres 한 장. 여기 하드코딩된 퀘스트는 없다.

## 해금 → codex에 심고 UNLOCK 퀘스트 진행 (옛 codex-only 람다를 대체).
func _on_codex_unlocked(unlock_id: StringName) -> void:
	codex[unlock_id] = true
	advance_quests(Enums.QuestGoal.UNLOCK, unlock_id)

func _on_enemy_died(enemy_id: StringName) -> void:
	advance_quests(Enums.QuestGoal.KILL, enemy_id)

## 이 퀘스트가 **열려 있나** — 완료 안 됐고, 선행(requires)이 완료됐으면 열림.
func is_quest_active(q: QuestDef) -> bool:
	if q == null or quest_done.has(q.id):
		return false
	return q.requires == &"" or quest_done.has(q.requires)

func is_quest_done(quest_id: StringName) -> bool:
	return quest_done.has(quest_id)

func quest_count(quest_id: StringName) -> int:
	return int(quest_progress.get(quest_id, 0))

## 🔴 goal·target에 맞는 **열린** 퀘스트들의 카운트를 1씩 올린다. 목표에 닿으면 완료 처리.
##  target 규칙: 퀘스트의 target이 비었으면 아무 대상이나(예: KILL "" = 아무 적), 지정됐으면 일치할 때만.
func advance_quests(goal: int, target: StringName) -> void:
	for q: QuestDef in Db.all_quests():
		if q.goal != goal or not is_quest_active(q):
			continue
		if q.target != &"" and q.target != target:
			continue
		quest_progress[q.id] = quest_count(q.id) + 1
		EventBus.quest_advanced.emit(q.id)
		if quest_count(q.id) >= q.need():
			_complete_quest(q)
	# 방금 완료로 새로 열린 UNLOCK 퀘스트가 이미 해금된 룬을 노릴 수 있다 — 소급 완료.
	_auto_complete_satisfied()

## 🔴 완료 — 표시하고 보상을 창고에 넣고 알린다. 이미 완료면 아무 일도 안 한다(이중 안전).
func _complete_quest(q: QuestDef) -> void:
	if quest_done.has(q.id):
		return
	quest_done[q.id] = true
	for item_id: StringName in q.reward_items:
		add_item(item_id, int(q.reward_items[item_id]))
	EventBus.quest_completed.emit(q.id)

## 🔴 이미 조건이 충족된 채로 열린 퀘스트를 소급 완료한다 (세션36).
##  왜 필요한가: 스파인이 "물의 룬 배우기"에 닿았을 때 플레이어가 **이미** 물 룬을 해독했을 수 있다.
##  그러면 UNLOCK 이벤트는 지나갔으므로, 열리는 순간 codex를 보고 바로 완료해야 사슬이 안 막힌다.
##  부팅 로드 직후에도 한 번 부른다(SaveManager) — 저장된 완료 상태로 열린 UNLOCK 퀘스트 정리.
func _auto_complete_satisfied() -> void:
	var changed := true
	while changed:   # 한 번 완료가 다음 UNLOCK을 열 수 있어 고정점까지 반복 (quest_done가 무한을 막는다)
		changed = false
		for q: QuestDef in Db.all_quests():
			if q.goal == Enums.QuestGoal.UNLOCK and is_quest_active(q) and is_unlocked(q.target):
				_complete_quest(q)
				changed = true

## 부팅 로드 후 SaveManager가 부른다 — 복원된 완료 상태 기준으로 소급 완료를 한 번 돌린다.
func reevaluate_quests() -> void:
	_auto_complete_satisfied()
