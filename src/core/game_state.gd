extends Node
## 전역 상태 원장 — 자원·장착 3장·가방·도감.
## 모듈은 이 API로만 자원을 만진다. inventory에 직접 접근하지 말 것.

## ⚠ 줄이면 옛 저장의 넘치는 장착이 로드에서 조용히 해제된다(보관에는 남는다) —
## save_manager가 이 개수만큼만 복원한다.
const EQUIP_SLOTS := 3

## 🔴 발사 마나 기본값의 단일 소스 — 여기선 장비 보정만 얹는다(`cast_mana_cost()`).
const RingPower := preload("res://src/core/ring_power.gd")

var balance: BalanceData = preload("res://data/balance.tres")

var mana: float
## 플레이어 HP — 출격 시 reset, 표시·판정의 단일 원장.
var hp: float
## 원정 중인가. ⚠ 지금 **읽는 곳이 0이다**(쓰기 전용) — 원정 전용 기능이 붙으면 이걸 읽는다.
var in_expedition: bool = false
## 어느 챕터로 들어가나 — `change_scene_to_file`이 인자를 못 실어 오토로드가 나른다.
## **저장 안 함**(일시 상태). ⚠ boss_room은 이게 비었거나 미등록이면 빈 방을 띄우지 않고
## 베이스로 되돌린다.
var pending_chapter: StringName = &""
## {item_id: count} — 창고 (영구, 사망에도 유지)
var inventory: Dictionary = {}
## 출격 중 획득 [{ "id": StringName, "count": int }] — 사망 시 손실
var bag: Array[Dictionary] = []
## 착용 장비 {Enums.ItemKind: item_id} — 가방 아님, 사망에도 보존.
## 부위 목록의 정본은 `equip_gear`의 허용 목록이다.
var equipment: Dictionary = {}
## 고리 도안 — **유일한 마법진 모델**. ring_designs = 보관 전체 · ring_equipped = 장착분.
var ring_designs: Array[RingDesign] = []
## 🔴 크기는 **항상 `EQUIP_SLOTS`에서 파생**한다 — `_reset_equipped()`만 이 배열의 크기를 정한다.
## `[null, null, null]` 같은 리터럴을 두면 상수를 늘렸을 때 크기가 안 따라와 로드가 없는 슬롯을
## 짚고, **부팅 즉시 죽으면서 `_ready_to_save`가 false로 남아 이후 저장이 조용한 no-op**이 된다.
var ring_equipped: Array[RingDesign] = []
## {unlock_id: true} — 도감 영구 해금 (룬·제법·적 정보)
var codex: Dictionary = {}
## 퀘스트 진행 — 둘 다 영구 저장.
##   quest_progress = {quest_id: 현재 카운트} · quest_done = {quest_id: true}.
## 퀘스트는 순수 오버레이다 — EventBus 이벤트를 관찰해 카운트를 올릴 뿐 해금 사슬을 안 건드린다.
var quest_progress: Dictionary = {}
var quest_done: Dictionary = {}
## [!] 접수(읽음) 표시 — 시트를 열어 "읽은" active 퀘스트 id들(정산용 [?]와 별개 축).
## 영구 저장이라 껐다 켜도 이미 읽은 퀘스트에 [!]가 다시 뜨지 않는다.
var quest_seen: Dictionary = {}
## UI 모달(조립 책·Tab 시트·상자 등) 열림 — 패널이 설정, 플레이어 이동·발사 계열이 폴링한다.
var ui_modal_open: bool = false
## 🔴 테스트 편의: 발사 마나 무소모. 에디터 실행에서만 켜진다(익스포트 빌드엔 "editor" 피처가 없다).
## ⚠ **에디터에서는 마나 트레이드오프를 검증할 수 없다** — 켜져 있으면 HUD 마나 막대가
## "∞ 테스트"를 적는 게 그 신호다. 소비자는 `player_caster.fire()` 한 곳이고
## `spend_mana` 자체는 안 건드린다(테스트가 직접 재는 API라).
var debug_free_cast: bool = OS.has_feature("editor")

## 장착 배열을 `EQUIP_SLOTS` 크기의 빈 슬롯으로 세운다 — **크기의 단일 소스.**
## 타입 배열의 `resize`는 빈 자리를 null로 채운다.
func _reset_equipped() -> void:
	ring_equipped.clear()
	ring_equipped.resize(EQUIP_SLOTS)


## 🔴 `_ready`가 아니라 `_init`에서 세운다 — 오토로드는 **생성 즉시** 남이 읽을 수 있어야 하고,
## 크기가 0인 순간이 존재하면 그게 곧 out of bounds다.
func _init() -> void:
	_reset_equipped()

func _ready() -> void:
	mana = mana_max()
	hp = hp_max()
	_seed_starting_unlocks()
	EventBus.extraction_success.connect(_on_extraction_success)
	EventBus.bag_lost.connect(func() -> void: bag.clear())
	# 해금은 codex에 심고 **UNLOCK 퀘스트도 진행**한다.
	EventBus.codex_unlocked.connect(_on_codex_unlocked)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.ring_design_committed.connect(_on_ring_design_committed)

## 시작 해금 재시드 — codex 시드 + 시작 도안. ⚠ 장수를 여기 베끼지 말고 아래 함수를 읽어라.
## 🔴 `_ready`(첫 부팅)와 `new_game`(새로하기)이 **둘 다** 이걸 부른다 — 새로하기는 `_ready`를
## 다시 안 타므로, 두 경로가 갈라지면 **아무것도 못 그리는 새 게임**이 조용히 나온다.
## 🔴 시작엔 룬·진·고리만 심는다 — **장비도 스테이션도 없다**(빈 시작이 설계다).
func _seed_starting_unlocks() -> void:
	seed_codex_unlocks()
	_seed_starting_rings()


## **시작 해금(codex)만** — 도안 시드와 갈라 뒀다.
## 🔴 `save_manager.load_game`이 codex를 `clear()`한 뒤 이걸 **다시 부른다**: 시드는 「빌드가 주는
## 것」이라 세이브에 실려 있든 없든 늘 있어야 한다. 안 부르면 **빌드가 새 시작 해금을 추가해도
## 기존 세이브에선 조용히 사라진다**(룬 하나가 책에서 없어지는 식). 세이브 해금은 이 위에 얹힌다.
## ⚠ 도안 시드(`_seed_starting_rings`)는 여기 없다 — 그건 로드가 덮어야 하는 「진행」이다.
func seed_codex_unlocks() -> void:
	# 🔴 **시작은 룬 1 · 진 1 · 고리 1뿐이다 — 여기에 시드를 더하지 마라.** 시드가 있으면 그
	# 해금을 주기로 한 보상·제작·드롭이 전부 **소급 완료로 덮여 조용히 죽는다**(관문을 붙였는데
	# 이미 해금돼 있어 아무 일도 안 일어난다).
	# ⚠ 이 회수는 **새로하기로만 검증된다** — 기존 세이브엔 codex가 이미 실려 있어 전부 그대로
	#   보인다(= 아무것도 회수되지 않은 것처럼 보이는 거짓 초록불).
	codex[&"rune_fire"] = true      # 시작 룬 = 불 하나
	codex[&"jin_single"] = true     # 시작 진 = 단발진(1겹·룬 1자리)
	# 시작부터 고리 하나는 있어야 「밴드에 끼운다」를 배울 대상이 존재한다(온보딩이 이걸 가르친다).
	codex[&"gr_radiate5"] = true
	# ⚠ 문양(GlyphDef)은 시드가 아니다 — **해금 게이트 자체가 없다**: unlock_id 필드가 없고
	# 책도 `Db.all_glyphs()`를 무필터로 띄운다. 문양에 해금 축을 세우면 그때 시드·판정을 같이 만든다.


## 시작 퀵슬롯 미리 장착 — **슬롯 1에 불 마법진 한 장뿐이다.**
## 조립을 거치지 않고 완성된 도안을 심는다(단발진 + 빈 고리 + 불 룬, 점수 1.0이라 펑 안 남).
## 빈 고리도 캐리어 몸이 착탄 피해를 주므로 볼만 날리는 데 충분하다.
##
## 🔴 **여기에 도안을 더 꽂지 마라 — codex만 걷는 회수는 아무 효과가 없다.**
## 발사는 `to_assembly()`가 도안을 그대로 읽고 **codex를 안 보므로**, 물 룬 도안을 꽂아 두면
## 「책에서 물 룬을 못 고른다」일 뿐 슬롯 키로는 물볼이 그대로 나간다 — 그 룬을 보상으로 준
## 챕터의 보상 지도가 통째로 무너진다.
## ⚠ 빈 슬롯 발사는 거부 + 안내 + 마나 무소모라 이미 안전하다(소프트락 없다).
##
## ⚠ Db 미준비 시점이라(GameState가 Db보다 먼저 `_ready`한다) 정적 값만 쓴다 — **Db 조회 금지.**
## 기존 세이브는 load_game이 이 시드를 덮으므로 이 한 장은 새 게임에서만 뜬다.
func _seed_starting_rings() -> void:
	ring_designs.clear()
	_reset_equipped()
	var d_fire := _make_seed_ring(Enums.RuneType.FIRE, "불 마법진")
	ring_designs.append(d_fire)
	ring_equipped[0] = d_fire   # 🔴 슬롯 2·3은 비운다(위 주석 참조)


## 완성된 시작 도안 한 장 (단발진 + 빈 고리 + 룬). Db 없이 정적 값으로만 조립한다.
func _make_seed_ring(rune_type: int, name: String) -> RingDesign:
	var d := RingDesign.new()
	d.rune = rune_type
	d.jin = &"jin_single"
	d.rings = [[-1, -1, -1, -1, -1, -1, -1, -1]]   # 빈 고리 8칸 (문양 없음 = 몸으로 때리는 원소 볼)
	d.open = [0, 1, 2, 3, 4, 5, 6, 7]              # 층 합집합 규약의 정적 스냅샷 (Db 미조회)
	d.total_score = 1.0                            # 안정 — 펑 안 남, 기준 위력
	d.size = 1.0
	return d

## **진짜 새로하기** — `save_game()`이 쓰는 것 전부 + `bag`·`hp` + 시작 해금 재시드를 한 곳에서
## 처리한다(씬마다 손으로 비우면 필드가 늘 때 조용히 갈라진다). `wipe_save`(파일 삭제)와 짝이다.
## ⚠ GameState·Clock은 오토로드라 메모리에 살아 있다 — 파일만 지우면 옛 진행이 도로 써진다.
## 그래서 **메모리를 여기서 비운다.**
func new_game() -> void:
	Clock.day = 1
	Clock.time_sec = 0.0
	inventory.clear()
	bag.clear()
	equipment.clear()          # 장비 벗김 — 맨손 시작
	ring_designs.clear()
	_reset_equipped()
	codex.clear()
	quest_progress.clear()
	quest_done.clear()
	quest_seen.clear()         # [!] 접수 초기화 — 새 게임은 첫 퀘스트에 [!]가 떠야 한다
	in_expedition = false
	_seed_starting_unlocks()   # 🔴 `_ready`와 **같은 함수** — 갈라지면 시드가 조용히 어긋난다
	hp = hp_max()
	mana = mana_max()
	# 구독 UI(HUD·창고·퀘스트 패널)를 새 빈 상태로 깨운다 — 로드 경로(save_manager)와 같은 3종.
	EventBus.player_hp_changed.emit(hp, hp_max())
	EventBus.equipment_changed.emit()
	EventBus.resources_changed.emit()

func _process(delta: float) -> void:
	mana = minf(mana + balance.mana_regen_per_sec * delta, mana_max())

func spend_mana(amount: float) -> bool:
	if mana < amount:
		return false
	mana -= amount
	return true

func restore_mana_full() -> void:
	mana = mana_max()

# ── 파생 스탯 — balance 기본값 + 장비 보정. balance 직접 참조 금지, 전부 이 getter를 거친다

func mana_max() -> float:
	return balance.mana_max + gear_param(Enums.ItemKind.ROBE, "mana_max_add", 0.0)

## 이동 속도 = balance 기본 × (1 + 모자(HAT) 배수). 새 모자 = `.tres` 한 장.
## ⚠ 구르기(dash_speed)는 이 배수를 안 탄다 — 모자는 평상 이동만 빠르게 한다.
func move_speed() -> float:
	return balance.player_move_speed * (1.0 + gear_param(Enums.ItemKind.HAT, "move_speed_mult", 0.0))

## 달리기 속도 — **`move_speed()`의 파생**이라 모자(HAT) 배수가 자동으로 실린다.
## 🔴 여기서 `balance.player_move_speed`를 직접 읽지 마라 — 달리는 동안만 모자 효과가 사라지는,
## 에러 없는 갈라짐이 생긴다.
func run_speed() -> float:
	return move_speed() * balance.player_run_mult

## 구르기 쿨다운 = balance 기본 × 부적(CHARM) 배수. 미착용이면 배수 1.0.
## ⚠ player가 balance를 직접 읽으면 부적 효과를 **아무도 안 보게 된다** — 이 getter를 거쳐라.
func roll_cooldown() -> float:
	return balance.dash_cooldown_sec * gear_param(Enums.ItemKind.CHARM, "dash_cooldown_mult", 1.0)

func hp_max() -> float:
	return balance.player_hp_max + gear_param(Enums.ItemKind.ROBE, "hp_max_add", 0.0)

## 🔴 **지팡이 = 세기·속도 스칼라 축이다 — 발사 「형태」를 여기로 되돌리지 마라.**
## 형태는 진이 답하는 질문이고, 두 축이 같은 자리를 다투면 진을 늘릴 때마다 지팡이 폴백이
## 조용히 끼어든다(실제로 폴백은 도달 불가라 산탄 지팡이를 껴도 아무 일도 안 일어났다).
##
## 진(캐리어) 비행 속도 배수 — 미착용 1.0(맨손도 쏜다).
## ⚠ **위력(피해)에는 안 곱한다** — 리포트·HUD가 `RingPower.power_display`로 같은 숫자를 보여 주는데
## 발사만 배수를 얹으면 「리포트는 140인데 130으로 때린다」가 된다.
func wand_speed_mult() -> float:
	return maxf(gear_param(Enums.ItemKind.WAND, "wand_speed_mult", 1.0), 0.0)


## 발사 1회당 마나 = **balance 기본 × 지팡이 배수** — 기본값은 `RingPower.cast_mana_cost()`가
## 쥐고 장비 보정만 여기서 얹는다(`move_speed`·`roll_cooldown`과 같은 결).
## 🔴 발사·HUD가 둘 다 이 함수를 불러야 한다 — `RingPower.cast_mana_cost()`를 직접 부르면
## 마나 막대의 「부족」 경계와 실제 소모가 갈라진다(빨간 막대인데 쏴지거나 그 반대).
func cast_mana_cost() -> float:
	return RingPower.cast_mana_cost() * maxf(gear_param(Enums.ItemKind.WAND, "wand_mana_mult", 1.0), 0.0)

## 획 보정 강도 (0..1) — 그은 획을 가이드 쪽으로 얼마나 끌어당기는가(0=안 당김, 1=정답선).
## 보정은 펜 아이템으로 산다 — 새 펜 = `.tres` 한 장이다.
## 🔴 **기본값은 0이다** — 펜을 안 끼면 손이 그린 궤적이 그대로 남는다(자기만의 마법진).
## 펜은 그 개성을 덜어내고 정확도를 사는 **교환**이다. balance에 바닥값을 깔면 맨손에도 보정이
## 붙어 그 정체성과 어긋난다.
func stroke_correction() -> float:
	return clampf(gear_param(Enums.ItemKind.PEN, "correction", 0.0), 0.0, 1.0)

# ── 장비 착용 — 창고에 있는 장비만, 착용품은 사망에도 보존

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
	# 로브 교체로 상한이 줄면 현재값 클램프
	hp = minf(hp, hp_max())
	mana = minf(mana, mana_max())
	EventBus.player_hp_changed.emit(hp, hp_max())
	EventBus.equipment_changed.emit()

# ── 플레이어 HP

## source_pos = 가해자 월드 좌표(방향성 카메라 킥이 쓴다). INF 센티널 = "방향 모름".
## `player_hurt`는 **여기서만** 발신한다(heal/reset은 안 쏜다) — 피격 연출이 회복에 오발하지 않는 근거.
## 🔴 죽은 뒤(hp 0)엔 발신하지 않는다 — 사망 연출 동안 접촉 피해가 계속 들어와 아픔음·트라우마가
## 스팸된다. 죽는 마지막 일격까지는 발신한다(그 한 방은 아파야 맞다).
func damage_player(amount: float, source_pos: Vector2 = Vector2(INF, INF)) -> void:
	var was_alive := hp > 0.0
	hp = maxf(0.0, hp - amount)
	EventBus.player_hp_changed.emit(hp, hp_max())
	if was_alive:
		EventBus.player_hurt.emit(amount, source_pos)

func heal_player(amount: float) -> void:
	hp = minf(hp + amount, hp_max())
	EventBus.player_hp_changed.emit(hp, hp_max())

func reset_player_hp() -> void:
	hp = hp_max()
	EventBus.player_hp_changed.emit(hp, hp_max())

# ── 창고 (영구)

## 🔴 **창고 증감은 `inventory_changed`도 쏜다** — 그게 자동 저장 트리거다
## (`resources_changed`는 가방 획득도 실어 와 트리거로 못 쓴다).
## 창고를 바꾸는 통로가 아래 둘뿐이라 두 신호를 나란히 쏘는 자리도 여기가 유일하다.
func add_item(item_id: StringName, count: int = 1) -> void:
	inventory[item_id] = int(inventory.get(item_id, 0)) + count
	EventBus.resources_changed.emit()
	EventBus.inventory_changed.emit()

func remove_item(item_id: StringName, count: int = 1) -> bool:
	if get_count(item_id) < count:
		return false
	inventory[item_id] = int(inventory[item_id]) - count
	EventBus.resources_changed.emit()
	EventBus.inventory_changed.emit()
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
	# 창고(add_item)와 대칭 — 안 쏘면 열어 둔 가방 구역이 안 는다.
	# ⚠ 여기선 `inventory_changed`를 쏘지 않는다 — 가방은 저장 대상이 아니다.
	EventBus.resources_changed.emit()

func _on_extraction_success() -> void:
	for entry: Dictionary in bag:
		add_item(entry["id"], entry["count"])
	bag.clear()
	# 보상 지급 **후에** EXTRACT 퀘스트를 센다 — 살아 돌아온 것 자체가 목표다.
	advance_quests(Enums.QuestGoal.EXTRACT, &"")

# ── 장착·도감

## 고리 도안이 맺혔다 — 보관고에 넣고 빈 슬롯이 있으면 즉시 장착한다(맺은 직후 바로 쏴볼 수
## 있어야 흐름이 안 끊긴다). 슬롯이 꽉 찼으면 보관만 하고, 교체는 아래 `equip_design()`이 한다.
func _on_ring_design_committed(design: RingDesign) -> void:
	if design == null:
		return
	ring_designs.append(design)
	for slot in range(EQUIP_SLOTS):
		if ring_equipped[slot] == null:
			ring_equipped[slot] = design
			return

## **보관 도안을 슬롯에 올린다** — 슬롯 교체 UI가 부르는 **유일한 진입점**이다.
## 이게 없으면 슬롯이 한 번 다 찬 뒤에 맺은 도안을 영원히 못 쓴다.
##
## design = null이면 그 슬롯을 **비운다**(해제).
## 🔴 같은 도안이 다른 슬롯에 있으면 **그 자리를 비운다** — 한 도안이 두 슬롯을 차지하면
##   해제 목록(`has` 판정)과 저장(경로 참조)이 조용히 어긋난다.
## 🔴 보관(`ring_designs`)에 없는 도안은 거부한다 — 저장이 도안을 **파일 경로**로 참조하므로
##   보관 밖 인스턴스를 꽂으면 다음 로드에 빈 슬롯이 된다(에러 없이).
## 저장은 `equipment_changed`가 끈다(save_manager가 자동 저장 트리거로 걸어 뒀다).
func equip_design(slot: int, design: RingDesign) -> bool:
	if slot < 0 or slot >= EQUIP_SLOTS:
		return false
	if design != null and not ring_designs.has(design):
		return false
	if design != null:
		var prev := ring_equipped.find(design)
		if prev != -1 and prev != slot:
			ring_equipped[prev] = null
	ring_equipped[slot] = design
	EventBus.equipment_changed.emit()
	return true

func is_unlocked(unlock_id: StringName) -> bool:
	return bool(codex.get(unlock_id, false))

# ── 퀘스트 ────────────────────────────────────────────────────────────
# 순수 오버레이: EventBus 이벤트를 관찰해 카운트를 올리고, 목표에 닿으면 보상을 주고
#    다음 퀘스트를 연다(requires 사슬 = 스파인). 해금 사슬은 전혀 안 건드린다.
#    새 퀘스트 = data/quests/*.tres 한 장 — 여기 하드코딩된 퀘스트는 없다.

## 해금 → codex에 심고 UNLOCK 퀘스트 진행.
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

## goal·target에 맞는 **열린** 퀘스트의 카운트를 1씩 올린다.
##  🔴 목표에 닿아도 여기서 완료하지 않는다 — 문에서 `claim_ready_quests()`로 정산해야 완료된다.
##  이미 달성한(정산 대기) 퀘스트는 더 세지 않는다. 방금 달성하면 `quest_ready`를 쏜다.
##  target 규칙: 비었으면 아무 대상이나, 지정됐으면 일치할 때만.
func advance_quests(goal: int, target: StringName) -> void:
	for q: QuestDef in Db.all_quests():
		if q.goal != goal or not is_quest_active(q):
			continue
		if q.target != &"" and q.target != target:
			continue
		if is_quest_satisfied(q):
			continue   # 이미 달성 — 문에서 정산만 남았다. 더 세지 않는다.
		quest_progress[q.id] = quest_count(q.id) + 1
		EventBus.quest_advanced.emit(q.id)
		if is_quest_satisfied(q):
			EventBus.quest_ready.emit(q.id)   # 방금 목표 달성 — 문으로 돌아가 정산하라

## 목표를 채웠나 (완료와 별개 — 완료는 문에서의 정산에서만 일어난다).
##  🔴 UNLOCK은 codex 상태로, DRAW는 도안 수로 판정한다 — **카운트가 아니라 상태라야** 이벤트를
##   놓친 세이브·나중에 사슬에 끼운 퀘스트가 자동 충족돼 사슬이 안 막힌다.
##  나머지(KILL/EXTRACT)는 카운트다.
func is_quest_satisfied(q: QuestDef) -> bool:
	if q == null:
		return false
	if q.goal == Enums.QuestGoal.UNLOCK:
		return is_unlocked(q.target)
	if q.goal == Enums.QuestGoal.DRAW:
		return ring_designs.size() >= q.need()
	return quest_count(q.id) >= q.need()

## 문에서 정산할 수 있나 — 열려 있고(선행 완료) 목표를 채웠고 아직 미수령.
func is_quest_claimable(q: QuestDef) -> bool:
	return is_quest_active(q) and is_quest_satisfied(q)

## 문 위 물음표용 — 정산할 퀘스트가 하나라도 있나.
func has_claimable_quest() -> bool:
	for q: QuestDef in Db.all_quests():
		if is_quest_claimable(q):
			return true
	return false

## 느낌표 마크용 — 아직 "받지 않은" active 퀘스트가 있나.
##  ⚠ 달성한(claimable) 퀘스트는 [?]로 따로 뜨므로 여기선 **미달성만** 센다(같은 퀘가 [!]와 [?]로
##  동시에 뜨지 않게).
func has_new_quest() -> bool:
	for q: QuestDef in Db.all_quests():
		if is_quest_active(q) and not is_quest_satisfied(q) and not quest_seen.has(q.id):
			return true
	return false

## 새 목표를 읽었다 — 지금 active인 퀘스트를 전부 "읽은(접수)" 것으로 표시해 [!]를 끈다.
##  🔴 **접수 = 시트를 여는 순간**이지 정산(턴인)이 아니다 — 그래야 정산으로 새 목표가 열려도
##   시트로 읽기 전까진 [!]가 남아 중간 게임에서도 유도가 산다.
##  실제로 뭔가 새로 접수됐을 때만 `quests_seen`을 쏜다(불필요한 재계산 방지).
func mark_quests_seen() -> void:
	var changed := false
	for q: QuestDef in Db.all_quests():
		if is_quest_active(q) and not quest_seen.has(q.id):
			quest_seen[q.id] = true
			changed = true
	if changed:
		EventBus.quests_seen.emit()

## 문에서의 정산 — 달성한(claimable) 퀘스트를 실제로 완료(보상·다음 개방)한다. **정산은 여기서만.**
##  고정점까지 반복한다: 하나를 정산하면 다음 퀘스트가 열리고, 그게 이미 달성돼 있으면 같은
##  방문에 연쇄 정산된다(무한은 quest_done이 막는다).
##  🔴 EXTRACT("살아 돌아와라")는 **진짜 귀환만** 채운다 — 여기서 크레딧하면 원정 없이 말만 걸어도
##  귀환 목표가 채워져 공짜 보상이 나간다.
##  반환: 이번에 완료된 퀘스트 id들(HUD 알림용).
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

## 완료 처리 — 표시하고 보상을 창고에 넣고 알린다. 이미 완료면 아무 일도 안 한다(이중 안전).
##  `claim_ready_quests()`에서만 불린다 — `advance_quests`는 부르지 않는다.
func _complete_quest(q: QuestDef) -> void:
	if quest_done.has(q.id):
		return
	quest_done[q.id] = true
	for item_id: StringName in q.reward_items:
		add_item(item_id, int(q.reward_items[item_id]))
	# 룬/진 해금 보상 — `codex_unlocked` 한 발로 codex 심기 + UNLOCK 사슬 진행 + 해금음 +
	#  예식이 전부 따라온다. ⚠ 이미 해금이면 재발신하지 마라 — 재정산에 예식이 두 번 뜬다.
	if q.reward_unlock != &"" and not is_unlocked(q.reward_unlock):
		EventBus.codex_unlocked.emit(q.reward_unlock)
	EventBus.quest_completed.emit(q.id)

## 부팅 로드 후 SaveManager가 부른다 — **의도적 no-op이다.** 소급 자동완료를 하지 않는다:
##  이미 조건이 충족된 채 열린 퀘스트는 claimable로 파생돼 물음표로 뜨고 문에서 정산된다
##  (파생 상태라 복원 뒤 재계산이 필요 없다). 호출부 안정을 위해 함수만 남긴다.
func reevaluate_quests() -> void:
	pass
