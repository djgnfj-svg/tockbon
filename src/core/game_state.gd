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
## 🔴 [!] 접수(읽음) 표시 (세션43) — 시트(Tab 퀘스트 탭)를 열어 "읽은" active 퀘스트 id들. 안 읽은
##  active 퀘스트가 있으면 NPC 머리 위 [!]가 떠 "Tab으로 확인"을 당긴다(정산용 [?]와 별개 축). 영구
##  저장 — 껐다 켜도 이미 읽은 퀘스트에 [!]가 다시 뜨지 않게. 시트를 열면 mark_quests_seen()이 채운다.
var quest_seen: Dictionary = {}
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
	# 🔴 세션49 룬 6종 전부 시드 (사용자: *"룬도 여러개 그냥 미리 열어줘"*). 원소 반응(진흙·감전
	# 연쇄·산불·확산)은 **두 룬을 이어 써야** 보이는데, 물·바람은 해독으로만 열리고 번개·흙·풀은
	# 획득 경로가 아예 없어 **게임에서 반응을 시험할 방법이 없었다**(세48 진 5종과 같은 처지).
	# ⚠ 해독·보상 경로가 생기면 여기서 빼면 그대로 "얻는 것"이 된다.
	#
	# 🔴🔴 **세션50: 그 경로가 생겼는데도 시드를 유지했다** (사용자 확정). 조각 6종·vine/beetle/mist
	# 드롭·숲 심층 gale·퀘스트 q08~q10이 전부 배선됐지만, 여기서 미리 열어 주므로 **UNLOCK 퀘스트가
	# 소급 완료되고 조각은 해독해도 아무 일이 안 난다** = 지금은 **의도적으로 잠자는 콘텐츠**다.
	# ⚠ **"왜 안 뜨지"로 시간 태우지 마라 — 버그가 아니다.** 유지한 이유는 다음 순서가 "사용자가
	# 직접 쏴 보며 반응 손맛을 정하기"인데, 시드를 빼면 두 번째 룬을 얻기까지 그게 막히기 때문이다.
	# 🔴 **손맛 확인이 끝나면 아래 5줄을 지워라** — 그 순간 이번 세션의 획득 경로가 통째로 살아난다.
	codex[&"rune_water"] = true
	codex[&"rune_wind"] = true
	codex[&"rune_bolt"] = true
	codex[&"rune_earth"] = true
	codex[&"rune_grass"] = true
	codex[&"glyph_thrust"] = true
	# 🔴 시작 진 3종 (세션44, 진=형태). "처음부터 여러 진을 주고 골라 그리게"(사용자 확정) — 단발·
	# 산탄·둘레. 즉시 자유(①학파). 특이한 진은 크래프트/보상으로 늘린다. unlock_id = jin_*.tres와 짝.
	codex[&"jin_single"] = true
	codex[&"jin_fork"] = true
	codex[&"jin_ring"] = true
	# 🔴 세션48 새 진 5종 — 연발·분사·타겟·나선·새의진. 지금은 **손맛을 재려고 전부 시드한다**
	# (획득 경로가 아직 없어 안 심으면 아무도 못 쏴 본다 — 세션44 지팡이가 정확히 그렇게 죽었다).
	# ⚠ 크래프트·보상으로 옮길 때 여기서 빼면 그대로 "얻는 것"이 된다.
	codex[&"jin_burst"] = true
	codex[&"jin_spray"] = true
	codex[&"jin_seek"] = true
	codex[&"jin_spiral"] = true
	codex[&"jin_bird"] = true

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
	quest_seen.clear()         # 🔴 [!] 접수 초기화 (세션43) — 새 게임은 첫 퀘스트에 [!]가 떠야 한다
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

## 🔴 이동 속도 = balance 기본 × (1 + 모자(HAT) 배수) (세션 42). 새 모자 = .tres 하나
## (`params["move_speed_mult"]`, 0.15 = +15%) — player._physics_process가 이 getter를 읽는다.
## ⚠ 구르기(dash_speed)는 이 배수를 안 탄다 — 모자는 평상 이동만 빠르게 한다.
func move_speed() -> float:
	return balance.player_move_speed * (1.0 + gear_param(Enums.ItemKind.HAT, "move_speed_mult", 0.0))

## 🔴 구르기 쿨다운 = balance 기본 × 부적(CHARM) 배수 (세션 42). 부적의 원래 설계 축을 되살렸다 —
## `charm_basic.tres`에 `dash_cooldown_mult`(0.85 = 쿨 15%↓)가 있었는데 player가 balance를 직접
## 읽어 **아무도 안 봤다**. 이제 player._physics_process가 이 getter를 쓴다. 미착용이면 배수 1.0.
func roll_cooldown() -> float:
	return balance.dash_cooldown_sec * gear_param(Enums.ItemKind.CHARM, "dash_cooldown_mult", 1.0)

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
	if def == null or def.kind not in [Enums.ItemKind.WAND, Enums.ItemKind.ROBE, Enums.ItemKind.CHARM, Enums.ItemKind.PEN, Enums.ItemKind.HAT]:
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

## 🔴 goal·target에 맞는 **열린** 퀘스트의 카운트를 1씩 올린다 (세션40 턴인: 완료가 아니라 "정산 대기"까지만).
##  🔴 목표에 닿아도 여기서 완료하지 않는다 — 길잡이(NPC)에게 말 걸어 claim_ready_quests()로 정산해야 완료된다.
##  이미 달성한(정산 대기) 퀘스트는 더 세지 않는다(진행 막대가 need에서 멈춘다). 방금 달성하면 quest_ready 발신.
##  target 규칙: 퀘스트의 target이 비었으면 아무 대상이나(예: KILL "" = 아무 적), 지정됐으면 일치할 때만.
func advance_quests(goal: int, target: StringName) -> void:
	for q: QuestDef in Db.all_quests():
		if q.goal != goal or not is_quest_active(q):
			continue
		if q.target != &"" and q.target != target:
			continue
		if is_quest_satisfied(q):
			continue   # 이미 달성 — 길잡이 정산만 남았다. 더 세지 않는다.
		quest_progress[q.id] = quest_count(q.id) + 1
		EventBus.quest_advanced.emit(q.id)
		if is_quest_satisfied(q):
			EventBus.quest_ready.emit(q.id)   # 방금 목표 달성 — 길잡이에게 돌아가 정산하라

## 목표를 채웠나 (완료와 별개 — 완료는 길잡이 정산에서만 일어난다, 세션40).
##  UNLOCK/BUILD는 codex 상태·DRAW는 도안 수로 판정(이벤트를 놓쳐도·소급이어도 옳게 나온다), 나머지(KILL/EXTRACT)는 카운트로.
##  🔴 DRAW를 상태(ring_designs.size)로 판정하는 이유 = 온보딩 q00을 사슬에 끼워도 **이미 그린 세이브가 자동 충족**돼
##   사슬이 안 막힌다(선례: UNLOCK/BUILD가 codex 상태로 소급 안전한 것과 같은 결, 세션40).
func is_quest_satisfied(q: QuestDef) -> bool:
	if q == null:
		return false
	if q.goal == Enums.QuestGoal.UNLOCK:
		return is_unlocked(q.target)
	if q.goal == Enums.QuestGoal.DRAW:
		return ring_designs.size() >= q.need()
	return quest_count(q.id) >= q.need()

## 길잡이에게 정산할 수 있나 — 열려 있고(선행 완료) 목표를 채웠고 아직 미수령.
func is_quest_claimable(q: QuestDef) -> bool:
	return is_quest_active(q) and is_quest_satisfied(q)

## NPC(길잡이) 머리 위 물음표용 — 정산할 퀘스트가 하나라도 있나.
func has_claimable_quest() -> bool:
	for q: QuestDef in Db.all_quests():
		if is_quest_claimable(q):
			return true
	return false

## 🔴 NPC 머리 위 느낌표용 (세션43) — 아직 "받지 않은" active 퀘스트가 있나.
##  달성한(claimable) 퀘스트는 [?]로 따로 뜨므로 여기선 **미달성**만 센다 — 같은 퀘가
##  [!]와 [?]로 동시에 뜨지 않게(마크 우선순위: claimable→[?], 아니면 new→[!]).
func has_new_quest() -> bool:
	for q: QuestDef in Db.all_quests():
		if is_quest_active(q) and not is_quest_satisfied(q) and not quest_seen.has(q.id):
			return true
	return false

## 🔴 새 목표를 읽었다 (세션43) — 지금 active인 퀘스트를 전부 "읽은(접수)" 것으로 표시해 [!]를 끈다.
##  🔴 **접수 = 시트를 여는 순간**(tab_panel이 퀘스트 탭을 열 때 부른다), 정산(턴인)이 아니다. 그래야
##   정산으로 새 목표가 열려도 시트로 읽기 전까진 [!]가 남아 중간 게임에서도 유도가 산다(세션43 설계).
##  온보딩 q00만 예외로 base가 튜토 대사 끝에 직접 부른다(대사가 곧 "받기"라 [!]를 끄고 책상으로 보낸다).
##  실제로 뭔가 새로 접수됐을 때만 quests_seen를 쏜다(불필요한 [!] 재계산·리드로 방지).
func mark_quests_seen() -> void:
	var changed := false
	for q: QuestDef in Db.all_quests():
		if is_quest_active(q) and not quest_seen.has(q.id):
			quest_seen[q.id] = true
			changed = true
	if changed:
		EventBus.quests_seen.emit()

## 🔴 길잡이 정산 (세션40) — 달성한(claimable) 퀘스트를 실제로 완료(보상·다음 개방)한다. **정산은 여기서만.**
##  고정점까지 반복: 하나 정산이 다음 퀘스트를 열고, 그게 **이미 달성돼 있으면**(예: 앞서 지은 스테이션·
##  이미 해금된 룬 — 옛 소급 완료 자리) 같은 방문에 연쇄 정산한다. quest_done가 무한을 막는다.
##  🔴 EXTRACT("살아 돌아와라")는 **진짜 귀환(`_on_extraction_success`)만** 채운다 — 여기서 크레딧하지
##  않는다. 안 그러면 원정 없이 말만 걸어도 귀환 목표가 채워져 공짜 보상이 나간다(q02 선행 제거로 시작부터
##  active라 더 위험). q02는 ⓐ(선행 제거)로 원정 중 이미 active라 실제 extraction_success가 채운다.
##  반환: 이번에 완료된 퀘스트 id들(HUD 알림용). 각각 quest_completed도 발신된다.
func claim_ready_quests() -> Array[StringName]:
	var claimed: Array[StringName] = []
	var changed := true
	while changed:
		changed = false
		for q: QuestDef in Db.all_quests():
			if is_quest_claimable(q):
				_complete_quest(q)
				claimed.append(q.id)
				changed = true
	return claimed

## 🔴 완료 처리 — 표시하고 보상을 창고에 넣고 알린다. 이미 완료면 아무 일도 안 한다(이중 안전).
##  세션40: 이제 claim_ready_quests()(길잡이 정산)에서만 불린다 — advance_quests는 부르지 않는다.
func _complete_quest(q: QuestDef) -> void:
	if quest_done.has(q.id):
		return
	quest_done[q.id] = true
	for item_id: StringName in q.reward_items:
		add_item(item_id, int(q.reward_items[item_id]))
	EventBus.quest_completed.emit(q.id)

## 부팅 로드 후 SaveManager가 부른다 — 세션40 턴인부턴 소급 자동완료를 하지 않는다.
##  이미 조건이 충족된 채 열린 퀘스트는 claimable로 파생돼 물음표로 뜨고, 길잡이 정산에서 완료된다.
##  (파생 상태라 복원 뒤 재계산이 필요 없다 — 함수는 저장/로드 호출부 안정을 위해 남긴 의도적 no-op.)
func reevaluate_quests() -> void:
	pass
