extends Node
## 저장/로드 — 영구부(창고·도감·고리 도안)와 시간·마나. 로드는 부팅 시 1회.
## 자동 저장: 귀환·사망 확정(세이브스컴 방지) · 하루 시작 · **창닫기(종료 훅)** ·
## **영구부를 바꾼 순간**(도안 맺기·해금·장비 — 같은 프레임은 한 번으로 합침).
##
## 🔴 뒤의 두 트리거가 없으면 실시간 하루 경계 전에 창을 닫을 때 **마을에서 한 일이 통째로
## 롤백된다 — 에러도 경고도 없이.** 트리거를 늘릴 땐 「영구 상태를 바꾸는 자리」와 짝을 맞춰라.
##
## 옛 세이브 호환은 `data.get(키, 기본값)`이 맡는다 — 로드가 전부 그 형태라 안 쓰는 키는 무시된다.

## 🔴 테스트 격리: `-s`(헤드리스) 부팅이면 세이브 뿌리가 갈라진다 — 안 가르면 스위트가 실제 플레이
## 세이브를 덮고 `wipe_save()`로 지워 **스위트 한 번 돌 때마다 타이틀 「이어하기」가 사라진다.**
## 실게임(F5·에디터 run·익스포트)은 `-s`가 없어 예전 경로 그대로다.
var _save_root: String = "user://save_test" if _is_test_boot() else "user://save"
var _save_path: String = _save_root + "/save.json"
## 고리 도안(RingDesign) .tres 저장 위치.
var _ring_dir: String = _save_root + "/rings"

static func _is_test_boot() -> bool:
	var args := OS.get_cmdline_args()
	return args.has("-s") or args.has("--script")

## 테스트가 격리를 검증하는 공개 훅 — 경로 문자열 자체는 내부 사정이다.
func save_root() -> String:
	return _save_root

## 로드(또는 새 게임 확정) 이전의 자동 저장 방지
var _ready_to_save := false

## 세이브 스키마 버전. 지금 쓰임은 「이 빌드가 모르는 미래 세이브를 만나면 시끄럽게 알린다」
## 하나다 — 마이그레이션이 필요해지면 여기서 갈린다.
const SAVE_VERSION := 1

## 🔴 로드가 고리 도안을 **하나라도 잃었나.** 잃은 채로 프룬하면 남아 있는 원본 .tres가 영구
## 삭제된다 — 「배열이 줄었다」와 「도안이 줄었다」는 다른 사건이다.
var _load_lost_designs := false

## 같은 프레임 다중 저장 예약을 한 번으로 합친다 — 트리거는 연달아 온다(도안을 맺으면
## `ring_design_committed` + 자동 장착 `equipment_changed`가 같이 온다).
## ⚠ 디바운스가 **종료 저장을 삼키면 안 된다** — 그래서 `save_game()`이 첫 줄에서 예약을 걷는다.
var _save_queued := false

## 🔴 지금 로드 중인가 — **로드는 「변경」이 아니다.** `load_game`이 끝에서 구독 UI를 깨우려
## `equipment_changed`·`resources_changed`를 쏘는데, 그걸 저장 트리거로 받으면 방금 읽은 것을
## 곧바로 되쓴다. 첫 부팅은 `_ready_to_save`가 우연히 막지만 두 번째 로드부터는 안 막힌다.
var _loading := false

## **부팅 시 1회 로드.**
## 🔴 `load_game()` 호출자가 사라지면 전 저장이 조용히 죽는다 — `_ready_to_save`가 false로 남아
## `save_game()`이 전부 return하고, 껐다 켜면 진행이 통째로 사라지는데 **에러도 경고도 없다.**
## 🔴 여기가 부를 자리인 이유: SaveManager는 오토로드 마지막이라 GameState·Clock·Db가 이미 서 있고
## 오토로드는 부팅에 딱 한 번 `_ready`한다. **씬에서 부르면 안 된다** — 씬은 돌아올 때마다 다시
## `_ready`하므로 귀환할 때마다 세이브를 덮어 로드해 그 판을 날린다.
## 세이브가 없으면 false를 돌려주고 `_ready_to_save`만 켠다 = 새 게임.
func _ready() -> void:
	EventBus.extraction_success.connect(save_game)
	EventBus.bag_lost.connect(save_game)
	EventBus.day_started.connect(func(_day: int) -> void:
		if _ready_to_save:
			save_game())
	# 🔴 **방어선 ② — 영구 상태를 바꾸는 자리를 저장 트리거로.** 위 셋만으로는 트리거가
	# 「귀환·사망·하루경계」뿐이라 마을에서 도안을 맺고 장비를 바꾸고 창을 닫으면 전부 롤백된다.
	# ⚠ `equipment_changed`는 `load_game`·`new_game`도 쏘는데, 그때는 `_ready_to_save`가 아직
	#   false거나(로드) 직후 `save_game()`이 예약을 걷는다(새로하기) — 방금 읽은 것을 되쓰지 않는다.
	# 🔴 여기에 `resources_changed`를 걸지 마라 — 그 신호는 `add_to_bag`도 쏘는데 가방은 애초에
	#   저장 대상이 아니라, 드롭 하나마다 세이브 + 도안 .tres 전량을 다시 쓰는 순수 낭비가 된다.
	#   `inventory_changed`는 창고(영구) 증감만 쏜다.
	EventBus.inventory_changed.connect(_queue_save)
	EventBus.ring_design_committed.connect(func(_design: RingDesign) -> void: _queue_save())
	EventBus.codex_unlocked.connect(func(_unlock_id: StringName) -> void: _queue_save())
	EventBus.equipment_changed.connect(_queue_save)
	# 🔴 창닫기를 우리가 받는다 — 아래 `_notification` 주석 참조. 이 줄이 없으면 엔진이
	# 알림만 보내고 **곧바로** 종료해 저장이 끝나기 전에 프로세스가 사라질 수 있다.
	get_tree().auto_accept_quit = false
	load_game()


## **창을 닫아도 저장한다.**
## 🔴 `auto_accept_quit = false`면 엔진은 창닫기를 종료로 바꾸지 않고 이 알림만 보낸다 —
## **종료는 우리가 직접 해야 한다.** 그래서 `quit`을 **먼저 예약**하고 저장한다: 예약은 이 함수가
## 반환한 뒤 처리되니 저장이 먼저 끝나고, 저장이 런타임 에러로 중단돼도 창은 닫힌다.
## 순서를 뒤집으면(저장 → quit) 저장 중 에러 한 번에 **닫히지 않는 창**이 된다.
##
## ⚠ 이 훅이 못 잡는 종료: 에디터 [정지] 버튼·강제 종료는 알림 없이 죽는다 — 그건 방어선 ②
## (위 `_ready`의 신호 트리거)가 덮는다. 그래서 둘을 다 깐 것이다.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit.call_deferred()
		# 🔴 **예약을 기다리지 않고 직접 쓴다.** `save_game()`이 첫 줄에서 예약을 걷으므로
		# 디바운스가 종료 저장을 삼키는 일이 없다.
		save_game()


## 저장 **예약** — 같은 프레임에 몇 번 불려도 파일은 한 번만 쓴다.
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
	## ⚠ 사전 키를 `RingDesign`(객체)으로 두지 마라 — 사전이 도안들을 강참조해 붙들어서
	##   종료 중 해체 순서에 얽힌다(간헐 segfault). 정수 키면 그 결합이 없다.
	var path_by_index: Dictionary = {}
	var lost := 0
	for i in range(GameState.ring_designs.size()):
		var rpath := "%s/ring_%d.tres" % [_ring_dir, i]
		# 🔴 **반환값을 반드시 봐라.** 쓰기가 실패했는데 경로를 목록에 실으면, 다음 부팅이 그 경로
		# 로드에 실패해 배열이 줄고 → 장착이 한 칸씩 밀려 **슬롯이 남의 마법을 쏘고** → 그다음
		# 자동 저장의 프룬이 원본을 지운다.
		var err := ResourceSaver.save(GameState.ring_designs[i], rpath)
		if err != OK:
			lost += 1
			push_warning("고리 도안 저장 실패 — 이 도안은 세이브 목록에서 빠진다: %s (err %d)"
				% [rpath, err])
			continue
		ring_files.append(rpath)
		path_by_index[i] = rpath
	# 🔴 프룬 = 「도안이 줄었으면 남은 ring_N.tres를 지운다」. 그런데 **줄어든 이유가 저장·로드
	# 실패**라면 그 삭제가 살아 있는 원본을 영구히 없앤다. 실패를 알고 있으면 건너뛴다 —
	# 남는 파일은 세이브 목록에 없는 고아라 무해하고, 지운 도안은 되돌릴 수 없다.
	if lost == 0 and not _load_lost_designs:
		_prune_ring_files(GameState.ring_designs.size())
	else:
		push_warning("고리 도안 유실을 알고 있어 ring_*.tres 프룬을 건너뛴다 (원본 보호)")
	# 🔴 장착 참조 = **파일 경로**(안정 키). 목록 인덱스로 두면 도안 한 장이 로드에 실패해 배열이
	# 줄 때 뒤 슬롯이 전부 한 칸씩 밀린다. 빈 슬롯·저장 실패한 도안은 "".
	# ⚠ 인덱스도 계속 같이 쓴다 — 옛 코드가 읽어도 세이브가 그대로 열리게.
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
	# 퀘스트 진행·완료. 키(quest_id)는 StringName이라 String으로 직렬화한다.
	var quest_progress: Dictionary = {}
	for qid: StringName in GameState.quest_progress:
		quest_progress[String(qid)] = int(GameState.quest_progress[qid])
	var quest_done: Array = []
	for qid: StringName in GameState.quest_done:
		if GameState.quest_done[qid]:
			quest_done.append(String(qid))
	# [!] 접수 표시 — 이미 받은 퀘스트. 옛 세이브엔 없어 빈 채로 로드된다(무해).
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
	# 🔴 **null 가드를 걷지 마라.** 없으면 `file.get_as_text()`가 null 참조로 터지고,
	# `_ready_to_save`가 false로 남아 **이후 모든 자동 저장이 조용한 no-op**이 된다(그런데 `-s`는
	# OK를 찍는다). 이번 판의 진행은 잃어도 다음 저장은 살린다.
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

	# 모르는 미래 세이브는 조용히 반쯤 읽히는 게 가장 나쁘다 — 시끄럽게 알리고 아는 키만 읽는다.
	var version := int(data.get("version", SAVE_VERSION))
	if version > SAVE_VERSION:
		push_warning("세이브 버전 %d은 이 빌드(%d)보다 새롭다 — 모르는 키는 무시된다: %s"
			% [version, SAVE_VERSION, _save_path])

	# 🔴 여기서부터 복원 = **「변경」이 아니다.** 아래 `equipment_changed`·`resources_changed`가
	# 저장 트리거를 때리면 방금 읽은 것을 곧바로 되쓴다.
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
	# 🔴 codex도 clear한다 — 안 그러면 로드해도 옛 해금이 남는다(위 사전들과 대칭).
	# 🔴 그다음 **시드를 다시 심는다** — 시드는 「빌드가 주는 것」이라 세이브에 없어도 있어야 한다
	# (안 심으면 빌드가 시작 해금을 늘렸을 때 기존 세이브에서만 그게 사라진다 — 에러 없이).
	GameState.codex.clear()
	GameState.seed_codex_unlocks()
	for key: String in data.get("codex", []):
		GameState.codex[StringName(key)] = true
	# 퀘스트 진행·완료 복원. 옛 세이브엔 없어 빈 진행으로 떨어진다(첫 퀘스트가 열린다).
	GameState.quest_progress.clear()
	var qprog: Dictionary = data.get("quest_progress", {})
	for key: String in qprog:
		GameState.quest_progress[StringName(key)] = int(qprog[key])
	GameState.quest_done.clear()
	for key: String in data.get("quest_done", []):
		GameState.quest_done[StringName(key)] = true
	# [!] 접수 표시 복원. 옛 세이브엔 없어 빈 채로 남는다(무해 — 다시 받으면 된다).
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
		# 🔴 로드 실패를 조용히 버리지 마라 — 배열이 줄면 장착이 밀리고, 다음 자동 저장의 프룬이
		# 남은 원본을 **영구 삭제**한다. 시끄럽게 알리고 프룬을 멈춘다(`_load_lost_designs`).
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

	# 장비를 복원했으니 상한을 반영한다 — hp는 저장하지 않으므로 부팅은 복원된 로브 상한 기준
	# 만HP로 맞춘다. equipment_changed는 부팅 시 장비 구독 UI를 깨운다.
	GameState.hp = GameState.hp_max()
	EventBus.player_hp_changed.emit(GameState.hp, GameState.hp_max())
	EventBus.equipment_changed.emit()
	EventBus.resources_changed.emit()
	# 로드 후 퀘스트 재평가 훅. ⚠ `reevaluate_quests`는 지금 **의도적 no-op**이다 —
	# 여기서 소급 완료가 일어난다고 읽지 마라(호출부 안정을 위해 남긴 줄이다).
	GameState.reevaluate_quests()
	_loading = false
	_ready_to_save = true
	return true

## 테스트·디버그용 — 세이브 **파일**만 삭제.
##
## 🔴 **이건 「새로하기」가 아니다 — 새로하기로 쓰지 마라.** `GameState`·`Clock`은 오토로드라
## 메모리에 살아 있어서, 파일만 지우면 **다음 자동 저장 한 번에 옛 진행이 도로 써진다**
## (에러도 경고도 없다). 진짜 새로하기는 아래 `start_new_game()`이다.
func wipe_save() -> void:
	# 🔴 **예약된 저장을 걷는다** — 지우기 직전에 누가 `_queue_save()`를 했으면 그 예약이
	# **다음 프레임에 파일을 되살린다**(뒷정리 검사를 통과한 뒤 `ring_*.tres`가 다시 생긴다).
	_save_queued = false
	if FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(_save_path)
	_prune_ring_files(0)

## **진짜 새로하기** — 파일을 지우고(①) 메모리를 비운 뒤 시작 해금을 다시 심고(②)
## 빈 새 상태를 파일에 즉시 굳힌다(③ — 다음 부팅이 이 빈 상태를 이어받게).
## 🔴 ②가 빠지면 위 `wipe_save` 주석의 함정이 그대로 재발한다.
func start_new_game() -> void:
	wipe_save()
	GameState.new_game()
	# 새 판은 잃은 도안이 없다 — 이 플래그를 안 걷으면 옛 실패가 남아 프룬이 영구히 멈춘다.
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
