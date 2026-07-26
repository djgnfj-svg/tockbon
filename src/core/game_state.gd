extends Node
## 전역 상태 원장 — 자원·장착 3장·가방·도감 (TECH_SPEC §3).
## 모듈은 이 API로만 자원을 만진다. inventory에 직접 접근하지 말 것.

## 세션64에 4→3 (사용자 확정 — HUD 정리). 옛 저장의 4번째 장착은 로드에서 조용히 해제되고
## 보관(ring_designs)에는 남는다 — save_manager가 EQUIP_SLOTS만큼만 복원한다.
const EQUIP_SLOTS := 3

## 🔴 발사 마나 기본값의 단일 소스 — 여기선 장비 보정만 얹는다(`cast_mana_cost()`).
const RingPower := preload("res://src/core/ring_power.gd")

var balance: BalanceData = preload("res://data/balance.tres")

var mana: float
## 플레이어 HP — 출격 시 reset, 표시·판정의 단일 원장 (v1.1: C 로컬에서 이관)
var hp: float
## 숲에 있나 — forest/base/intro `_ready`가 설정 (오토로드라 씬 전환에도 남음).
## ⚠ 세58 허기 은퇴(docs/PROGRESSION.md D1)로 읽는 곳이 0이다 — "원정 중" 상태 자체는 의미가
## 살아 있어 플래그만 남긴다 (원정 전용 기능이 다시 붙으면 이걸 읽는다).
var in_expedition: bool = false
## 🔴 어느 챕터로 들어가나 (세58-B) — `change_scene_to_file`이 인자를 못 실어 오토로드가 나른다
## (in_expedition과 같은 결). 챕터 패널이 쓰고 boss_room `_ready`가 읽는다. **저장 안 함**(일시 상태).
## boss_room은 이게 비었거나 미등록이면 조용히 빈 방을 띄우지 않고 베이스로 되돌린다.
var pending_chapter: StringName = &""
## {item_id: count} — 창고 (영구, 사망에도 유지)
var inventory: Dictionary = {}
## 출격 중 획득 [{ "id": StringName, "count": int }] — 사망 시 손실
var bag: Array[Dictionary] = []
## 착용 장비 {Enums.ItemKind.WAND/ROBE/CHARM: item_id} — 가방 아님, 사망에도 보존 (GDD §5)
var equipment: Dictionary = {}
## 🔴 고리 도안 — **유일한 마법진 모델** (세션 22에 옛 designs/equipped를 매장했다).
##   ring_designs = 보관 전체 · ring_equipped = 장착 EQUIP_SLOTS장.
var ring_designs: Array[RingDesign] = []
## 🔴 크기는 **항상 `EQUIP_SLOTS`에서 파생**한다 — `_reset_equipped()`만 이 배열의 크기를 정한다
## (세84 감사 #34). 전엔 `[null, null, null]` 리터럴이 세 곳에 있어 상수를 4로 고치면 크기는 3인
## 채로 `save_manager.load_game`이 슬롯 3을 짚어 **부팅 즉시 out of bounds**로 죽고,
## `_ready_to_save`가 false로 남아 이후 자동 저장이 조용한 no-op이 됐다(`-s`는 failures=0).
var ring_equipped: Array[RingDesign] = []
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
## 🔴 테스트 편의: 발사 마나 무소모 (사용자 요청 2026-07-23 — "테스트할 때 귀찮음").
## 에디터 실행(F5·MCP run·헤드리스)에서만 켜진다 — 익스포트 빌드엔 "editor" 피처가 없어 꺼진다.
## ⚠ 조용한 갈라짐 방지: 켜져 있으면 HUD 마나 막대가 "∞ 테스트"를 적는다(hud._draw_mana).
## 소비자는 player_caster.fire() 한 곳 — spend_mana 자체는 안 건드린다(테스트가 직접 재는 API라).
var debug_free_cast: bool = OS.has_feature("editor")

## 🔴 장착 배열을 `EQUIP_SLOTS` 크기의 빈 슬롯으로 세운다 — **크기의 단일 소스**(세84 #34).
## 타입 배열의 `resize`는 빈 자리를 null로 채운다(`Array[RingDesign]`의 기본값).
func _reset_equipped() -> void:
	ring_equipped.clear()
	ring_equipped.resize(EQUIP_SLOTS)


## 🔴 `_ready`가 아니라 `_init`에서 세운다 — 오토로드는 **생성 즉시** 남이 읽을 수 있어야 하고,
## 크기가 0인 순간이 존재하면 그게 곧 #34가 말하는 out of bounds다.
func _init() -> void:
	_reset_equipped()

func _ready() -> void:
	mana = mana_max()
	hp = hp_max()
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
	seed_codex_unlocks()
	_seed_starting_rings()


## 🔴 **시작 해금(codex)만** — 도안 시드와 갈라 뒀다 (세86 ⑥). `save_manager.load_game`이
## codex를 `clear()`한 뒤 이걸 **다시 부른다**: 시드는 「빌드가 주는 것」이라 세이브에 실려
## 있든 없든 늘 있어야 한다. 안 부르면 **빌드가 새 시작 해금을 추가해도 기존 세이브에선
## 조용히 사라진다**(에러 없이 — 룬 하나가 책에서 없어지는 식). 세이브의 해금은 이 위에 얹힌다.
## ⚠ 도안 시드(`_seed_starting_rings`)는 여기 없다 — 그건 로드가 덮어야 하는 「진행」이다.
func seed_codex_unlocks() -> void:
	# 🔴 세션61 콘텐츠 리셋 — 카탈로그를 진 1(jin_single)·룬 1(rune_fire)·문양 1(radiate)로 비웠다.
	# 앞으로 사용자가 큐레이션하며 하나씩 되살린다(진의 개성 = band_count·rune_slots·guide_shape —
	# 🔴 세85 ⑦에 칸 축 glyph_slots는 은퇴했다).
	# 시드 = 시작 지급뿐: 세49~58의 룬 6종·진 8종 전부 시드는 은퇴했다(그 시드가 관문·해독을
	# 소급 완료로 덮어 재우던 것도 같이 끝 — 룬을 되살리면 관문 드롭(until_unlock)이 바로 산다).
	# ⚠ 문양(발산)은 시드가 없다 — **문양엔 해금 게이트 자체가 없다**: GlyphDef에 unlock_id 필드가
	# 없고 책도 `Db.all_glyphs()`를 무필터로 띄운다(ring_forge_panel._inject_defs). 옛 `glyph_thrust`
	# 시드는 소비자 0인 유령이었다. 문양에 해금 축을 세우면 그때 시드·판정을 같이 만든다.
	# 🔴 세78 시작 룬 3개 지급 (사용자 확정: "시작할 때 룬 3개") — 불·물·바람.
	#   물(rune_water)=WET 감속·바람(rune_wind)=FLOW 밀림+확산. 각각 워터볼·윈드볼로 발사된다.
	codex[&"rune_fire"] = true
	codex[&"rune_water"] = true
	codex[&"rune_wind"] = true
	# 🔴🔴 **세83 룬 6종 복원** (사용자: *"룬을 일단 다 살려줘 6개로"*). 세61 리셋으로 잠들었던
	# 번개·흙·풀을 되살렸다 — `.tres`는 세49 원본을 git(`43937c8^`)에서 그대로 꺼냈다(값을 지어내지
	# 않았다). 🔴 **기계는 처음부터 전량 살아 있었다**: `rune_guide_verts` 6갈래(⚡□🍃)·`status_rules`
	# 반응표(감전 연쇄·진흙·속박·산불)·`RUNE_TYPES` 6종 — 빠진 건 데이터 3장뿐이었다.
	# ⚠ **이것도 임시 시드다**(위 M1 시드와 같은 처지) — 획득 경로는 미설계(D5·D6). 경로를 붙이는
	#   세션이 이 세 줄을 지운다. 🔴 룬이 살아나면 관문 드롭(`until_unlock`)이 **바로 산다**.
	codex[&"rune_bolt"] = true
	codex[&"rune_earth"] = true
	codex[&"rune_grass"] = true
	codex[&"jin_single"] = true
	# 🔴🔴 **세79 M1 임시 시드 — 획득 경로 미설계** (사용자 확정: *"일단 만들기만 하면 됨,
	# 얻는 곳은 추후에 설계"*). 「진별 해석」 M1의 실증 재료 3종을 시작부터 준다:
	#   jin_plain_g2(2등급 진 = 층 2겹 — 🔴 1등급은 1겹이라 **감쌀 순서 자체가 안 생긴다**)
	#   gr_spread3(확산×3) · gr_explode1(폭발×1) — 이 둘의 **층 순서**가 발사를 통째로 바꾼다.
	# ⚠ **경로를 붙이는 세션이 이 세 줄을 지운다**(ChapterDef.reward_unlock 등으로 이관).
	#   지금 ch1은 gr_radiate5로 이미 차 있고 codex 해금 경로는 챕터당 하나뿐이라 자리가 모자랐다.
	codex[&"jin_plain_g2"] = true
	codex[&"gr_spread3"] = true
	codex[&"gr_explode1"] = true
	# 🔴 세82 응축 — 문양 효과 데이터화의 첫 증명 문양(폭발과 같은 `blast` 알고리즘, 파라미터만
	# 뒤집었다). 🔴 고리 count가 **2인 이유**: `merge_mult_per_count` 훅이 count=1이면 경로에
	# 아예 안 걸려 그물이 자명 통과한다 — 콘텐츠가 그 훅을 밟게 둔다.
	# ⚠ 위 세 줄과 같은 임시 시드다 — **획득 경로를 붙이는 세션이 이 줄들을 함께 지운다.**
	codex[&"gr_condense2"] = true
	# 🔴🔴 **세81 M2 임시 시드 — 획득 경로 미설계** (사용자 확정: *"일단 만들기만 하면 됨"*).
	#   jin_fuse(융합진 2등급 = 룬 자리 2 · 층 2겹) — 룬 둘을 한 발에 실어 명중 시 두 상태를 걸어
	#   원소 반응(젖음+번개=감전…)을 낸다. ⚠ **경로 붙이는 세션이 이 한 줄도 M1 3줄과 함께 걷는다.**
	codex[&"jin_fuse"] = true
	# ⚠ 아래 문양 링 주석은 「시드가 아닌 것」의 설명이다 — 여기서 끝나는 게 codex 시드 전부다.
	# 🔴 세71 첫 스테이지 슬라이스 — 진은 일반진 1종으로 출발(진·문양은 여전히 하나).
	# 문양 링(gr_*)은 더는 시드가 아니다 — 스테이지 클리어 보상으로만 얻는다(ChapterDef.reward_unlock):
	#   ch1(숲 어귀) 클리어 → gr_radiate5(발산×5) 해금 → 조립대에서 밴드에 끼워 파이어볼을 5갈래로.
	# ⚠ gr_gather3는 당분간 획득 경로가 없다(후속 챕터 reward_unlock 대기) — .tres는 남겨 둔다.
	#   세68 시드 2줄(gr_radiate5·gr_gather3)은 이 결정으로 삭제됐다.


## 🔴 세78 시작 퀵슬롯 미리 장착 (사용자 확정: "1 파이어볼·2 워터볼·3 윈드볼로 넣은 걸로 시작").
## 시작하자마자 슬롯 1/2/3에 불·물·바람 마법진이 물려 있어 1·2·3 키로 바로 세 원소 볼을 쏜다.
## 조립을 거치지 않고 완성된 도안을 심는다 — 각각 단발진(jin_single)에 빈 고리(문양 없음)+해당 룬,
## 점수 1.0(안정, 펑 안 남). 빈 고리도 캐리어 몸이 착탄 피해를 주므로 볼만 날리는 데 충분하다.
## ⚠ Db 미준비 시점(GameState._ready가 Db._ready보다 먼저)이라 정적 값만 쓴다 — Db 조회 금지.
## 기존 세이브는 load_game이 이 시드를 덮으므로(옛 슬롯 유지), 세 볼은 **새 게임**에서만 뜬다(룬 시드와 동일).
func _seed_starting_rings() -> void:
	ring_designs.clear()
	_reset_equipped()
	var d_fire := _make_seed_ring(Enums.RuneType.FIRE, "불 마법진")
	var d_water := _make_seed_ring(Enums.RuneType.WATER, "물 마법진")
	var d_wind := _make_seed_ring(Enums.RuneType.WIND, "바람 마법진")
	ring_designs.append(d_fire)
	ring_designs.append(d_water)
	ring_designs.append(d_wind)
	ring_equipped[0] = d_fire   # 슬롯 1 = 파이어볼
	ring_equipped[1] = d_water  # 슬롯 2 = 워터볼
	ring_equipped[2] = d_wind   # 슬롯 3 = 윈드볼


## 완성된 시작 도안 한 장 (단발진 + 빈 고리 + 룬). Db 없이 정적 값으로만 조립한다.
func _make_seed_ring(rune_type: int, name: String) -> RingDesign:
	var d := RingDesign.new()
	d.rune = rune_type
	d.jin = &"jin_single"
	d.rings = [[-1, -1, -1, -1, -1, -1, -1, -1]]   # 빈 고리 8칸 (문양 없음 = 몸으로 때리는 원소 볼)
	d.open = [0, 1, 2, 3, 4, 5, 6, 7]              # 층 합집합 규약의 정적 스냅샷 (Db 미조회 — 세85 ⑦에 glyph_slots 은퇴)
	d.total_score = 1.0                            # 안정(>0.65) — 펑 안 남, 기준 위력
	d.size = 1.0
	return d

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
	_reset_equipped()
	codex.clear()
	quest_progress.clear()
	quest_done.clear()
	quest_seen.clear()         # 🔴 [!] 접수 초기화 (세션43) — 새 게임은 첫 퀘스트에 [!]가 떠야 한다
	in_expedition = false
	_seed_starting_unlocks()   # 룬·문양만 — _ready와 동일 (분기 방지)
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

## 🔴 **지팡이 = 세기·속도 스칼라 축** (세85, 사용자 확정 — 감사 #5).
## 옛 `wand_pattern()`(지팡이가 발사 **형태**를 정한다)은 **은퇴했다**. 이유:
##   ① 형태는 이미 **진**이 답하는 질문이다(세44에 진으로 옮겼다) — 두 축이 같은 자리를 다투면
##      진을 늘릴 때마다 지팡이 폴백이 조용히 끼어든다(세60에 문양본을 진에 흡수시킨 것과 같은 논리).
##   ② 실제로 **도달 불가**였다: 폴백이 `jin_def == null`일 때만 걸리는데 도안 생성 두 경로가
##      전부 진을 채웠다 → 산탄·전방위 지팡이를 껴도 **아무 일도 안 일어났다**.
## 🔴 그래서 지팡이는 이제 **관측 가능한 스칼라**를 준다. 되살리지 마라 — 소스가 둘이 된다.
##
## 진(캐리어) 비행 속도 배수 — 미착용 1.0(맨손도 쏜다). 소비자 = `ring_spell_system._spawn_carrier`.
## ⚠ **위력(피해)에는 안 곱한다**: 리포트·HUD가 `RingPower.power_display`로 같은 숫자를 보여 주는데
## 발사만 배수를 얹으면 세23의 「리포트는 140인데 130으로 때린다」가 그대로 재발한다.
func wand_speed_mult() -> float:
	return maxf(gear_param(Enums.ItemKind.WAND, "wand_speed_mult", 1.0), 0.0)


## 🔴 발사 1회당 마나 = **balance 기본 × 지팡이 배수** (세85). `move_speed`·`roll_cooldown`과 같은
## 결의 파생 스탯 getter다 — 기본값은 `RingPower.cast_mana_cost()`가 쥐고 장비 보정만 여기서 얹는다.
## 🔴 **발사·HUD가 둘 다 이 함수를 부른다** — `RingPower.cast_mana_cost()`를 직접 부르면
## 마나 막대의 「부족」 경계와 실제 소모가 갈라진다(빨간 막대인데 쏴지거나 그 반대).
func cast_mana_cost() -> float:
	return RingPower.cast_mana_cost() * maxf(gear_param(Enums.ItemKind.WAND, "wand_mana_mult", 1.0), 0.0)

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

## 🔴 source_pos(세션63) = 가해자 월드 좌표 — `player_hurt`에 실려 방향성 카메라 킥이 쓴다.
## 기본 인자 INF 센티널 = "방향 모름"(수신자가 is_finite()로 가드) — 기존 호출자 무수정 하위호환.
## `player_hurt`는 **여기서만** 발신한다(heal/reset은 안 쏜다) — 피격 연출이 회복에 오발하지 않는 근거.
## 🔴 죽은 뒤(hp 0)엔 발신하지 않는다 — 사망 연출 0.9초 동안 접촉 피해가 계속 들어와 아픔음·
## 트라우마가 스팸된다(세63 리뷰). 죽는 마지막 일격까지는 발신한다(그 한 방은 아파야 맞다).
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

## 🔴 세86 ⑫: **창고 증감은 `inventory_changed`도 쏜다** — 이게 자동 저장 트리거다
## (`resources_changed`는 가방 획득도 실어 와 트리거로 못 쓴다, event_bus 주석 참조).
## 두 신호를 **여기 두 함수에서 나란히** 쏜다 — 창고를 바꾸는 통로가 이 둘뿐이라 여기가 유일한 자리다.
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

## 🔴🔴 **보관 도안을 슬롯에 올린다** (세86 ① — 사용자 결정, 감사 #6).
## 세85까지 `ring_equipped`에 쓰는 자리는 시드·새로하기·로드·위 **빈 슬롯 자동 장착**뿐이었다 =
## **세 슬롯이 한 번 차면 그 뒤에 맺은 도안은 영원히 못 쓴다.** 세85 F5에서 보관 6장으로 실증됐다
## ("맺었는데 못 쓴다"). 슬롯 교체 UI(`tab_panel` 마법진 탭)가 부르는 **유일한 진입점**이다.
##
## design = null이면 그 슬롯을 **비운다**(해제).
## 🔴 같은 도안이 다른 슬롯에 있으면 **그 자리를 비운다** — 한 도안이 두 슬롯을 차지하면
##   `tab_panel._unequipped_designs`(`has` 판정)와 저장(경로 참조)이 조용히 어긋난다.
## 🔴 보관(`ring_designs`)에 없는 도안은 거부한다 — 저장은 도안을 **파일 경로**로 참조하므로
##   보관 밖 인스턴스를 꽂으면 다음 로드에 빈 슬롯이 된다(에러 없이).
## 저장은 `equipment_changed`가 끈다 — save_manager가 이미 자동 저장 트리거로 걸어 뒀다(세84 #1).
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
	# 🔴 룬/진 해금 보상 (세66 도파민 — 룬=퀘스트 턴인 통로). codex_unlocked 한 발로 codex 심기 +
	#  UNLOCK 사슬 진행 + Audio unlock음 + 예식(unlock_ceremony)이 전부 따라온다. 이미 해금이면
	#  재발신 안 함 — 재정산·소급에 예식이 두 번 안 뜨게 (station 시드·chapter_clear 가드와 같은 결).
	if q.reward_unlock != &"" and not is_unlocked(q.reward_unlock):
		EventBus.codex_unlocked.emit(q.reward_unlock)
	EventBus.quest_completed.emit(q.id)

## 부팅 로드 후 SaveManager가 부른다 — 세션40 턴인부턴 소급 자동완료를 하지 않는다.
##  이미 조건이 충족된 채 열린 퀘스트는 claimable로 파생돼 물음표로 뜨고, 길잡이 정산에서 완료된다.
##  (파생 상태라 복원 뒤 재계산이 필요 없다 — 함수는 저장/로드 호출부 안정을 위해 남긴 의도적 no-op.)
func reevaluate_quests() -> void:
	pass
