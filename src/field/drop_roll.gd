extends RefCounted
## 🔴🔴 **드롭 굴림 · 낱개 스폰의 단일 소스** (세101 추출 · 정본 설계
## `docs/takbon-design/dungeon_structure_design.md` §10-4 **S17**).
## `class_name` 없음 — 쓰는 쪽이 `const DropRoll := preload("res://src/field/drop_roll.gd")`.
##
## 🔴 **왜 옮겼나**: 굴림·낱개 스폰이 `forest_enemy`의 **private 둘**(`_roll_drops`/`_spawn_loose`)뿐이라,
##  곧 붙는 **지점(랜드마크)**이 자기 로직을 새로 쓰면 `DropEntry`의 **배타 짝 규칙 셋이 두 벌**이 된다
##  (takbon-rules §5-1이 「조용히 깨진다」로 못 박은 자리 · 설계 §3 소유권 ⓑ).
##  → **적과 지점이 같은 함수를 부르게 하는 것**이 이 파일의 전부다.
##
## 🔴🔴 **순수 이동이다 — 로직을 한 톨도 안 바꿨다**(세101). `forest_enemy._roll_drops`/`_spawn_loose`는
##  이제 이 static을 부르는 **얇은 껍데기**다. 고칠 일이 생기면 **여기만** 고쳐라 —
##  껍데기에 로직을 되돌려 적는 순간 그게 S17의 재발이고, **에러가 0이다.**
##
## 🔴 **오토로드 식별자를 이 파일에서 쓰지 마라.** static에서 `GameState`를 컴파일타임 참조하면
##  `-s` 테스트가 컴파일 단계에서 죽는다(오토로드는 스크립트 컴파일 **뒤에** 등록된다 —
##  takbon-verify §8). 그래서 `roll()`이 **`gs`를 인자로 받는다**(찾는 건 호출자 몫).
##
## 랜덤 = Godot 전역 `randf()`/`randi()` — 부팅 시 자동 시드. 세이브에 안 들어간다(굴린 결과만 남는다).
## ⚠ 테스트가 전역 `seed()`를 잡으면 여기 각도 굴림이 **같은 스트림을 소비**해 다른 그물이 흔들린다
##  (`boss_room._roll_pool_id` 머리말 — 굴림 그물은 **확률의 양끝을 주입해** 잰다).

## 🔴 바닥 픽업 프롭 — `forest_enemy`에서 **같이 옮겨 왔다**. preload가 안전한 이유도 그대로다:
## 픽업은 field/actors를 안 물어 **순환 preload가 없고**(base⇄forest 함정 무관),
## 방향도 **field → props 단방향**이 유지된다(`LandmarkDef` 머리말이 못 박은 그 방향).
const DropPickup := preload("res://src/props/drop_pickup.tscn")


## 🔴 드롭 테이블을 굴린다 (세51에 `_die` 안에 있던 로직 → 세55 추출 → 세101 field 공용으로 승격).
## 반환 = `[{"id": StringName, "count": int, "unlock": StringName}]`
## 🔴 **반환 키가 계약이다** — `spawn_loose`와 `DropPickup.setup`이 **양쪽에서** 이 키를 본다.
##  이름을 바꾸면 **조용히 갈라진다**(반환 계약이 적힌 자리는 여기 한 곳뿐이다).
##
## 🔴 `gs` = `GameState`(없으면 null). **순수 함수가 아니다** — codex를 읽어 관문(`until_unlock`)과
##  「이미 해금된 고리는 안 떨군다」를 판정한다. **null이면 관문을 못 재므로 순수 확률로 폴백한다**
##  (고립 테스트가 쓰는 경로다 — 이 폴백을 없애지 마라).
##
## 세58: `until_unlock`(관문 드롭)만 확률 대신 해금 상태로 갈린다 — 나머지 확률·수량 로직은 그대로.
static func roll(drops: Array[DropEntry], gs: Node) -> Array[Dictionary]:
	var rolled: Array[Dictionary] = []
	for drop: DropEntry in drops:
		# 🔴🔴 해금 드롭 가드 (세88 문양-고리 두루마리) — 이미 해금된 고리는 안 떨군다.
		# **확률 굴림보다 앞**이고 **별도 줄**인 것이 계약이다: 아래 until_unlock 분기에 섞으면
		# `elif`가 `chance`를 통째로 건너뛰어 **0.02 보너스가 모든 잡몹 확정 드롭**이 된다
		# (두 필드는 병용 금지 — 축이 반대다, `DropEntry.unlock_id` 주석).
		if drop.unlock_id != &"" and gs != null and gs.is_unlocked(drop.unlock_id):
			continue
		# 🔴 관문 드롭 (세58, 정본 docs/PROGRESSION.md): until_unlock가 있으면 확률이 아니라
		# 해금 상태가 정한다 — 미해금 = 확정, 해금됨 = 스킵. GameState가 없으면(고립 테스트)
		# 관문을 못 재므로 순수 확률로 폴백한다.
		if drop.until_unlock != &"" and gs != null:
			if gs.is_unlocked(drop.until_unlock):
				continue
		elif randf() > drop.chance:
			continue
		var n := drop.min_count
		if drop.max_count > drop.min_count:
			n += randi() % (drop.max_count - drop.min_count + 1)
		if n > 0:
			# 🔴 "unlock" 키 = 해금 드롭(세88). `id`가 비고 이쪽이 찬 항목이 두루마리다 —
			# `DropPickup.setup`의 4번째 옵션 인자로 넘어간다(`spawn_loose`).
			rolled.append({"id": drop.item_id, "count": n, "unlock": drop.unlock_id})
	return rolled


## 낱개 바닥 픽업 (세46·51 계약 그대로) — `origin`에 드롭마다 하나씩 심고 **균등 각도**로 흩뿌린다.
## 🔴 `origin`·`scene`을 인자로 받는 이유 = 이 함수의 유일한 몸이던 `_spawn_loose`가 적의
##  `global_position`과 「지금 씬」에 붙어 있어서다. 적은 자기 자리를, 지점은 자기 자리를 넘긴다.
##
## 🔴🔴 **균등 각도는 의도적 장치다** — 랜덤이면 겹쳐 하나로 보여 「여러 개 나왔다」가 눈에 안 읽힌다.
##  **그게 보상 체감의 절반**이다(세51). ⚠ 이 배치는 **1~2개를 상정**하고 짜였다 — 지점 뭉치가 그
##  상정을 처음으로 넘기면 반경이 상수라 **간격이 좁아져 등급 후광이 겹친다**(설계 S23).
##  🔴 그건 연출값이라 **F5·스샷 몫**이다(헤드리스는 개수만 세고 겹침을 못 본다) — 여기서 손대지 마라.
##
## 🔴 **`add_child` → `global_position` → `setup` 순서가 계약이다**:
##  씬에 붙기 전에 위치를 잡으면 좌표계가 아직 없고, `setup`이 먼저면 scatter가 **엉뚱한 자리에서**
##  시작한다(픽업이 `setup` 안에서 자기 자리를 기준으로 튄다).
static func spawn_loose(scene: Node, origin: Vector2, rolled: Array[Dictionary]) -> void:
	var base_angle := randf() * TAU
	for i in rolled.size():
		var pickup := DropPickup.instantiate()
		scene.add_child(pickup)
		# 여러 드롭이 겹치지 않게 살짝 흩뿌린 지점에서 심는다(픽업이 여기서 또 scatter).
		pickup.global_position = origin + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
		# i번째 드롭 = base_angle + i·TAU/n → 2개면 정반대, 3개면 삼각형으로 흩어진다.
		# 4번째 인자 = 해금 드롭(세88 두루마리). 옵션 인자라 기존 아이템 드롭 경로는 무변경이다.
		pickup.setup(rolled[i]["id"], int(rolled[i]["count"]), base_angle + float(i) * TAU / float(rolled.size()),
			rolled[i].get("unlock", &""))
