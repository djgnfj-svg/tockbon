extends Node
## 저장/로드 (TECH_SPEC §9) — 영구부(창고·도감·고리 도안)와 시간·마나.
## 자동 저장: 귀환·사망 확정(세이브스컴 방지)·하루 시작(취침 포함) · 🔴 **창닫기(종료 훅)** ·
## 🔴 **영구부를 바꾼 순간**(도안 맺기·해금·장비 — 같은 프레임은 한 번으로 합침).
## 로드: 부팅 시 1회.
##
## 🔴🔴 뒤의 두 줄이 세84 감사 #1의 수정이다. 그전엔 트리거가 앞의 셋뿐이었고 종료 훅이 **0건**이라,
## `day_length_sec` 실시간 12분 경계 전에 창을 닫으면 **마을에서 한 일이 통째로 롤백됐다** —
## 에러도 경고도 없이. 트리거를 늘릴 땐 「영구 상태를 바꾸는 자리」와 짝이 맞는지 같이 훑어라.
##
## 🔴 세션 22: 옛 SpellDesign 도안(user://save/designs)·연구 저장을 매장했다. 세이브 호환은 안전하다 —
## 로드가 전부 `data.get(키, 기본값)`이라 옛 세이브의 남은 키는 그냥 무시된다.

## 🔴 테스트 격리 (세션59): `-s`(헤드리스 테스트 스크립트) 부팅이면 세이브 뿌리가 user://save_test로
## 갈라진다. 전엔 스위트가 실제 플레이 세이브를 자동 저장으로 덮고 wipe_save()로 지워 —
## **스위트 한 번 돌 때마다 타이틀 「이어하기」가 사라졌다**(사용자가 실제로 밟음, *"자꾸 없어지네"*).
## 격리 후 테스트의 wipe_save()는 테스트 세이브만 지우는 뒷정리다. 실게임(F5·에디터 run·익스포트)은
## -s가 없어 예전 경로 그대로 — 세이브 호환 무변경.
var _save_root: String = "user://save_test" if _is_test_boot() else "user://save"
var _save_path: String = _save_root + "/save.json"
## 고리 도안(RingDesign) .tres 저장 위치.
var _ring_dir: String = _save_root + "/rings"

static func _is_test_boot() -> bool:
	var args := OS.get_cmdline_args()
	return args.has("-s") or args.has("--script")

## 테스트가 격리를 검증하는 공개 훅 (test_save_auto [0]) — 경로 문자열 자체는 내부 사정이다.
func save_root() -> String:
	return _save_root

## 로드(또는 새 게임 확정) 이전의 자동 저장 방지
var _ready_to_save := false

## 세이브 스키마 버전. 🔴 전엔 **저장만 하고 읽는 곳이 없었다**(세84 감사 #4) — 지금 쓰임은
## 「이 빌드가 모르는 미래 세이브를 만나면 시끄럽게 알린다」 하나다. 마이그레이션이 필요해지면
## 여기서 갈린다(옛 세이브 호환은 지금도 `data.get(키, 기본값)`이 맡는다).
const SAVE_VERSION := 1

## 🔴 로드가 고리 도안을 **하나라도 잃었나**(세84 #4). 잃은 채로 프룬하면 남아 있는 원본 .tres가
## 영구 삭제된다 — 「배열이 줄었다」와 「도안이 줄었다」는 다른 사건인데 프룬이 그걸 구분 못 했다.
var _load_lost_designs := false

## 🔴 같은 프레임 다중 저장 예약을 한 번으로 합친다 — #1의 트리거는 연달아 온다(챕터 클리어가
## `codex_unlocked`를 여러 번 쏘고, 도안을 맺으면 `ring_design_committed` + 자동 장착
## `equipment_changed`가 같이 온다).
## ⚠ **디바운스가 종료 저장을 삼키면 #1이 그대로 재발한다** — 그래서 `save_game()`이 첫 줄에서
## 이 예약을 걷는다(직접 호출은 예약을 기다리지 않는다).
var _save_queued := false

## 🔴 지금 로드 중인가 — **로드는 「변경」이 아니다.** `load_game`이 끝에서 `equipment_changed`·
## `resources_changed`를 쏘는데(구독 UI 깨우기), 그걸 저장 트리거로 받으면 **방금 읽은 것을 곧바로
## 되쓴다**. 첫 부팅은 `_ready_to_save`가 아직 false라 우연히 막히지만 두 번째 로드부터는 안 막힌다
## — 우연에 기대지 않고 명시로 막는다.
var _loading := false

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
	# 🔴🔴 **영구 상태를 바꾸는 자리를 저장 트리거로** (세84 감사 #1 — 방어선 ②).
	# 위 셋만으로는 트리거가 「귀환·사망·하루경계(실시간 12분)」뿐이라, **마을에서 도안을 맺고
	# 장비를 바꾸고 창을 닫으면 전부 롤백됐다.** 영구부를 바꾸는 신호를 여기에 건다:
	#   ring_design_committed = 도안 보관·자동 장착 · codex_unlocked = 해금(룬·챕터 클리어·스테이션)
	#   equipment_changed = 착·탈용
	# ⚠ `equipment_changed`는 `load_game`·`new_game`도 쏘는데, 그때는 `_ready_to_save`가 아직
	#   false거나(로드) 직후 `save_game()`이 예약을 걷는다(새로하기) — 방금 읽은 것을 되쓰지 않는다.
	# ✅ 세86 ⑫: **`inventory_changed`를 건다** — 세84엔 `resources_changed`밖에 없어 각하했었다
	#   (그 신호는 `GameState.add_to_bag`도 쏘는데 **가방은 애초에 저장 대상이 아니라**(사망 시
	#   소실이 설계) 드롭 하나마다 세이브 + 도안 .tres 전량을 다시 쓰는 순수 낭비였다).
	#   이제 신호를 갈랐다: `inventory_changed`는 **창고(영구) 증감만** 쏜다 = 제작·상점·퀘스트
	#   보상·귀환 정산이 저장으로 이어지고, 원정 중 드롭은 조용하다.
	# ⚠ 정산(`_on_extraction_success`)은 `add_item`을 아이템 수만큼 부르지만 `_queue_save`가
	#   같은 프레임을 하나로 합친다(디바운스). `extraction_success` 자체도 직접 저장한다 — 이중이
	#   아니라 순서상 예약이 걷힌다(`save_game` 첫 줄).
	EventBus.inventory_changed.connect(_queue_save)
	EventBus.ring_design_committed.connect(func(_design: RingDesign) -> void: _queue_save())
	EventBus.codex_unlocked.connect(func(_unlock_id: StringName) -> void: _queue_save())
	EventBus.equipment_changed.connect(_queue_save)
	# 🔴 창닫기를 우리가 받는다 — 아래 `_notification` 주석 참조. 이 줄이 없으면 엔진이
	# 알림만 보내고 **곧바로** 종료해 저장이 끝나기 전에 프로세스가 사라질 수 있다.
	get_tree().auto_accept_quit = false
	load_game()


## 🔴🔴 **창을 닫아도 저장한다** (세84 감사 #1 — 사용자가 실제로 데이터를 잃고 있던 자리).
## 세26의 「껐다 켜면 그린 마법진이 사라졌다」와 사용자 체감이 같다(원인만 다르다 — 그때는
## `load_game()` 호출자가 없어 저장이 no-op이었고, 이번엔 저장할 **계기**가 없었다).
##
## 🔴 `auto_accept_quit = false`면 엔진은 창닫기를 종료로 바꾸지 않고 이 알림만 보낸다 —
## **종료는 우리가 직접 해야 한다.** 그래서 `quit`을 **먼저 예약**하고 저장한다: 예약(deferred)은
## 이 함수가 반환한 뒤 처리되니 저장이 먼저 끝나고, **저장이 런타임 에러로 중단돼도 창은 닫힌다.**
## 순서를 뒤집으면(저장 → quit) 저장 중 에러 한 번에 **닫히지 않는 창**이 된다 — 없는 문제를 막다
## 진짜 함정을 심는 자리다(세50 `_exit_tree` 교훈).
##
## ⚠ **이 훅이 못 잡는 종료**: 에디터 [정지] 버튼·강제 종료(프로세스 kill)는 알림 없이 죽는다.
## 그건 방어선 ②(위 `_ready`의 신호 트리거)가 덮는다 — 그래서 둘을 다 깐 것이다.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit.call_deferred()
		# 🔴 **예약을 기다리지 않고 직접 쓴다.** `save_game()`이 첫 줄에서 예약을 걷으므로
		# 디바운스가 종료 저장을 삼키는 일이 없다(그러면 #1이 그대로 재발한다).
		save_game()


## 🔴 저장 **예약** — 같은 프레임에 몇 번 불려도 파일은 한 번만 쓴다.
## ⚠ 예약은 **연기**일 뿐이다 — 종료 훅·귀환·사망은 `save_game()`을 직접 부르고, 그게 예약을
## 걷어 이중 저장도 막는다.
func _queue_save() -> void:
	if _loading or not _ready_to_save or _save_queued:
		return
	_save_queued = true
	_flush_save.call_deferred()


func _flush_save() -> void:
	# 사이에 누가 `save_game()`을 직접 불렀으면 예약이 이미 걷혔다 = 여기선 할 일이 없다.
	if not _save_queued:
		return
	# 🔴 **트리를 떠난 뒤엔 쓰지 않는다.** 예약은 다음 프레임에 깨어나므로 그 사이에 종료가
	# 시작될 수 있고, 그러면 이미 해체 중인 오토로드(GameState·Clock)를 만진다.
	# 종료 저장은 `_notification`이 **동기로** 이미 했다 — 여기서 다시 쓸 일이 없다.
	if not is_inside_tree():
		_save_queued = false
		return
	save_game()

func has_save() -> bool:
	return FileAccess.file_exists(_save_path)

func save_game() -> void:
	# 🔴 예약을 걷는다 — 직접 호출이 예약보다 앞서면 예약은 할 일이 없다(_flush_save 참조).
	_save_queued = false
	if not _ready_to_save:
		return
	# 고리 도안 저장 — 파일 목록 + 🔴 장착은 **파일 경로**(안정 키)
	DirAccess.make_dir_recursive_absolute(_ring_dir)
	var ring_files: Array = []
	## 보관 **인덱스** → 그 도안이 실제로 쓰인 경로. 장착 참조가 이걸로 나간다.
	## ⚠ 사전 키를 `RingDesign`(객체)으로 두지 마라 — 그러면 사전이 도안들을 강참조해 붙들고,
	##   종료 중 해체 순서에 얽힌다(세84에 실측: 종료 시 간헐 segfault). 정수 키면 그 결합이 없다.
	var path_by_index: Dictionary = {}
	var lost := 0
	for i in range(GameState.ring_designs.size()):
		var rpath := "%s/ring_%d.tres" % [_ring_dir, i]
		# 🔴 전엔 반환값을 **아무도 안 봤다**(세84 감사 #4). 쓰기가 실패했는데 경로를 목록에
		# 실으면, 다음 부팅이 그 경로 로드에 실패해 배열이 줄고 → 인덱스로 저장된 장착이
		# 한 칸씩 밀려 **슬롯이 남의 마법을 쏜다** → 그 다음 자동 저장의 프룬이 원본을 지운다.
		var err := ResourceSaver.save(GameState.ring_designs[i], rpath)
		if err != OK:
			lost += 1
			push_warning("고리 도안 저장 실패 — 이 도안은 세이브 목록에서 빠진다: %s (err %d)"
				% [rpath, err])
			continue
		ring_files.append(rpath)
		path_by_index[i] = rpath
	# 🔴 프룬 = 「도안이 줄었으면 남은 ring_N.tres를 지운다」. 그런데 **줄어든 이유가 저장·로드
	# 실패**라면 그 삭제가 살아 있는 원본을 영구히 없앤다(#4의 진짜 피해). 실패를 알고 있으면
	# 건너뛴다 — 남는 파일은 세이브 목록에 없는 고아라 무해하고, 지운 도안은 되돌릴 수 없다.
	if lost == 0 and not _load_lost_designs:
		_prune_ring_files(GameState.ring_designs.size())
	else:
		push_warning("고리 도안 유실을 알고 있어 ring_*.tres 프룬을 건너뛴다 (원본 보호)")
	# 🔴 장착 참조 = **파일 경로**(세84 #4). 전엔 `ring_designs`의 **목록 인덱스**였는데, 도안
	# 한 장이 로드에 실패해 배열이 줄면 뒤 슬롯이 전부 한 칸씩 밀렸다. 경로는 그 도안에 붙어
	# 있어 밀리지 않는다. 빈 슬롯·저장 실패한 도안은 "".
	# ⚠ 인덱스도 **계속 같이 쓴다** — 이 변경을 되돌려도(옛 코드가 읽어도) 세이브가 그대로 열린다.
	var ring_equipped_paths: Array = []
	var ring_equipped_idx: Array = []
	for rdesign: RingDesign in GameState.ring_equipped:
		# 빈 슬롯이면 find가 -1 → 경로도 "" (path_by_index에 -1 키가 없다).
		var di := GameState.ring_designs.find(rdesign)
		ring_equipped_idx.append(di)
		ring_equipped_paths.append(String(path_by_index.get(di, "")))

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
	# 퀘스트 진행·완료 (세션36) — 진행 목표 스파인. 키(quest_id)는 StringName이라 String으로 직렬화.
	var quest_progress: Dictionary = {}
	for qid: StringName in GameState.quest_progress:
		quest_progress[String(qid)] = int(GameState.quest_progress[qid])
	var quest_done: Array = []
	for qid: StringName in GameState.quest_done:
		if GameState.quest_done[qid]:
			quest_done.append(String(qid))
	# [!] 접수 표시 (세션43) — 이미 받은 퀘스트. 없으면(옛 세이브) 로드 시 빈 채라 active 퀘가 [!]로 뜬다(무해).
	var quest_seen: Array = []
	for qid: StringName in GameState.quest_seen:
		if GameState.quest_seen[qid]:
			quest_seen.append(String(qid))

	var data := {
		"version": SAVE_VERSION,
		"day": Clock.day,
		"time_sec": Clock.time_sec,
		"mana": GameState.mana,
		"inventory": inventory,
		"equipment": equipment,
		"codex": codex,
		"ring_designs": ring_files,
		"ring_equipped": ring_equipped_idx,
		"ring_equipped_paths": ring_equipped_paths,
		"quest_progress": quest_progress,
		"quest_done": quest_done,
		"quest_seen": quest_seen,
	}
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		push_warning("저장 실패: %s" % _save_path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

## 성공 시 true. 세이브가 없거나 손상이면 false (새 게임 — 호출측이 시드).
func load_game() -> bool:
	if not has_save():
		_ready_to_save = true
		return false
	var file := FileAccess.open(_save_path, FileAccess.READ)
	# 🔴 **저장 경로엔 있던 null 가드가 로드엔 없었다**(세84 감사 #4 — 「저장/로드 비대칭을
	# 의심해라」). 없으면 다음 줄 `file.get_as_text()`가 null 참조로 터지고, 그러면
	# `_ready_to_save`가 false로 남아 **이후 모든 자동 저장이 조용한 no-op**이 된다(세26 상태).
	# 그런데 `-s`는 그래도 OK를 찍는다. 이번 판의 진행은 잃어도 다음 저장은 살린다.
	if file == null:
		push_warning("세이브 열기 실패 — 새 게임으로 시작: %s (err %d)"
			% [_save_path, FileAccess.get_open_error()])
		_ready_to_save = true
		return false
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("세이브 파일 손상 — 새 게임으로 시작: %s" % _save_path)
		_ready_to_save = true
		return false

	# 🔴 저장만 하고 **읽는 곳이 없던** 필드(세84 #4). 모르는 미래 세이브는 조용히 반쯤
	# 읽히는 게 가장 나쁘다 — 시끄럽게 알리고, 아는 키만 읽는다(옛 세이브는 get 기본값이 덮는다).
	var version := int(data.get("version", SAVE_VERSION))
	if version > SAVE_VERSION:
		push_warning("세이브 버전 %d은 이 빌드(%d)보다 새롭다 — 모르는 키는 무시된다: %s"
			% [version, SAVE_VERSION, _save_path])

	# 🔴 여기서부터 복원 = **「변경」이 아니다.** 아래 `equipment_changed`·`resources_changed`와
	# `reevaluate_quests`(소급 완료 보상)가 저장 트리거를 때리면 방금 읽은 것을 곧바로 되쓴다.
	# (위 early return들은 이 플래그를 켜기 전이라 새는 자리가 없다.)
	_loading = true
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
	# 🔴 세86 ⑥: **codex도 clear한다** — 위 6개 사전과 대칭이다(전엔 여기만 얹기만 해서
	# "로드하면 옛 해금이 남는다"는 조용한 예외였다). 🔴 **그다음 시드를 다시 심는다**:
	# 시드는 「빌드가 주는 것」이라 세이브에 없어도 있어야 한다(안 그러면 빌드가 시작 해금을
	# 늘렸을 때 기존 세이브에서만 그게 사라진다 — 에러 없이). 세이브 해금은 그 위에 얹힌다.
	GameState.codex.clear()
	GameState.seed_codex_unlocks()
	for key: String in data.get("codex", []):
		GameState.codex[StringName(key)] = true
	# 퀘스트 진행·완료 복원 (세션36). 옛 세이브엔 없어 get 기본값으로 빈 진행(첫 퀘스트가 열린다).
	GameState.quest_progress.clear()
	var qprog: Dictionary = data.get("quest_progress", {})
	for key: String in qprog:
		GameState.quest_progress[StringName(key)] = int(qprog[key])
	GameState.quest_done.clear()
	for key: String in data.get("quest_done", []):
		GameState.quest_done[StringName(key)] = true
	# [!] 접수 표시 복원 (세션43). 옛 세이브엔 없어 빈 채 — active 퀘가 [!]로 떠도 무해(다시 받으면 됨).
	GameState.quest_seen.clear()
	for key: String in data.get("quest_seen", []):
		GameState.quest_seen[StringName(key)] = true

	# 고리 도안 복원
	GameState.ring_designs.clear()
	## 경로 → 복원된 도안. 장착 참조(안정 키)가 이걸로 풀린다 — 인덱스가 아니라서 **한 장이
	## 빠져도 나머지 슬롯이 밀리지 않는다**.
	var design_by_path: Dictionary = {}
	_load_lost_designs = false
	for path: String in data.get("ring_designs", []):
		# 캐시 우회 — 같은 세션에서 저장→로드 시 인스턴스 재사용으로 복원이 무효화되는 것 방지
		var rres := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		var rdesign := rres as RingDesign
		# 🔴 전엔 `if rdesign != null: append`로 실패를 **조용히 버렸다**(세84 감사 #4).
		# 배열이 줄면 인덱스로 저장된 장착이 밀리고, 다음 자동 저장의 프룬이 남은 원본을
		# **영구 삭제**했다. 이제 시끄럽게 알리고 프룬을 멈춘다(save_game의 `_load_lost_designs`).
		if rdesign == null:
			_load_lost_designs = true
			push_warning("고리 도안 로드 실패 — 빠진 채 계속하고 프룬을 멈춘다: %s" % path)
			continue
		GameState.ring_designs.append(rdesign)
		design_by_path[path] = rdesign
	# 🔴 장착 복원 — 새 세이브는 **경로**(안정 키), 옛 세이브는 목록 인덱스.
	# ⚠ 형식을 슬롯마다 섞지 않고 **파일 단위로** 고른다 — 섞으면 한쪽이 조용히 엉뚱한 도안을 집는다.
	var eq_by_path: bool = (data as Dictionary).has("ring_equipped_paths")
	var eq_paths: Array = data.get("ring_equipped_paths", [])
	var eq_idx: Array = data.get("ring_equipped", [])
	for slot in range(GameState.EQUIP_SLOTS):
		var equipped: RingDesign = null
		if eq_by_path:
			if slot < eq_paths.size():
				equipped = design_by_path.get(String(eq_paths[slot])) as RingDesign
		elif slot < eq_idx.size():
			var ridx := int(eq_idx[slot])
			if ridx >= 0 and ridx < GameState.ring_designs.size():
				equipped = GameState.ring_designs[ridx]
		GameState.ring_equipped[slot] = equipped

	# 🔴 장비를 복원했으니 상한을 반영한다 — hp는 저장하지 않으므로(출격이 만HP로 덮는다) 부팅은
	# 복원된 로브 상한 기준 만HP로 맞춘다. equipment_changed는 부팅 시 장비 구독 UI를 깨운다.
	GameState.hp = GameState.hp_max()
	EventBus.player_hp_changed.emit(GameState.hp, GameState.hp_max())
	EventBus.equipment_changed.emit()
	EventBus.resources_changed.emit()
	# 🔴 복원된 완료 상태 기준으로 소급 완료를 한 번 — 이미 해금된 룬을 노리는 UNLOCK 퀘스트가
	# 열린 채 막히지 않게 (game_state._auto_complete_satisfied 주석). Db는 오토로드라 이 시점 준비됨.
	GameState.reevaluate_quests()
	_loading = false
	_ready_to_save = true
	return true

## 테스트·디버그용 — 세이브 **파일**만 삭제.
##
## 🔴🔴 **이건 「새로하기」가 아니다. 새로하기로 쓰지 마라** (세션 26에 실제로 돌려 확인했다):
##   ① 진행을 만들고 저장 → 보관 1 · 잉크 9 · Day 7
##   ② wipe_save()      → 파일은 지워지는데 **메모리엔 보관 1 · 잉크 9 · Day 7 그대로**
##   ③ 귀환 한 번        → **옛 진행이 도로 써진다.** 에러도 경고도 없다
## `GameState`·`Clock`은 **오토로드라 메모리에 살아 있다** — 파일을 지워도 다음 자동 저장이
## 그대로 다시 쓴다. 새로하기를 눌렀는데 조용히 안 된 것처럼 보인다.
##
## 진짜 새로하기가 지워야 할 것 = **`save_game()`이 쓰는 것 전부** + `bag`·`hp` +
## 🔴 **시작 해금 재시드**(`GameState._ready`의 `rune_fire`·`jin_single` — 새로하기는 `_ready`를
## 다시 안 탄다. 안 심으면 **아무것도 못 그리는 새 게임**이 된다).
## → 설계·미결은 `docs/BACKLOG.md` 「F8 — 새로하기」가 정본. **`GameState.new_game()`을 core에
## 하나 두는 쪽**이 맞다 (씬마다 손으로 비우면 필드가 늘 때 조용히 갈라진다).
func wipe_save() -> void:
	# 🔴 **예약된 저장을 걷는다** (세84 #1의 디바운스가 만든 새 함정 — 실측으로 밟았다):
	# 지우기 직전에 누가 `_queue_save()`를 했으면 그 예약이 **다음 프레임에 파일을 되살린다.**
	# 실측: test_save_auto가 `new_game()`(→`equipment_changed`) 뒤 `wipe_save()`로 끝나는데,
	# 이 줄이 없으면 뒷정리 검사를 통과한 뒤 `ring_*.tres` 3장이 **다시 생겨 남았다.**
	# ⚠ 이 파일이 위에서 경고하는 「wipe 뒤 자동 저장 한 번에 옛 진행이 도로 써진다」의 새 판이다.
	_save_queued = false
	if FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(_save_path)
	_prune_ring_files(0)

## 🔴 **진짜 새로하기** (세션37, F8). 위 wipe_save 노트의 계약을 실제로 실행한다:
##   ① wipe_save()        — 파일(save.json·고리 .tres)을 지운다
##   ② GameState.new_game() — 메모리(오토로드라 파일 삭제로 안 지워진다)를 비우고 시작 해금 재시드
##   ③ save_game()         — 빈 새 상태를 파일에도 즉시 굳힌다 (다음 부팅이 이 빈 상태를 이어받게)
## 타이틀 메뉴의 [새로하기]가 부른다. 부팅 흐름(_ready→load_game)은 안 건드린다 — F3 가드 유지.
func start_new_game() -> void:
	wipe_save()
	GameState.new_game()
	# 🔴 새 판은 잃은 도안이 없다 — 이 플래그를 안 걷으면 옛 실패가 남아 프룬이 영구히 멈춘다.
	_load_lost_designs = false
	_ready_to_save = true
	save_game()

## ring_N.tres 중 인덱스가 keep_count 이상인 것을 지운다 (도안이 줄면 남은 파일이 되살아나는 것 방지)
func _prune_ring_files(keep_count: int) -> void:
	var dir := DirAccess.open(_ring_dir)
	if dir == null:
		return
	for file_name in dir.get_files():
		if file_name.begins_with("ring_") and file_name.ends_with(".tres"):
			var idx := int(file_name.trim_prefix("ring_").trim_suffix(".tres"))
			if idx >= keep_count:
				dir.remove(file_name)
