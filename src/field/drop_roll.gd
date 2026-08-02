extends RefCounted
## 드롭 굴림 · 낱개 스폰의 단일 소스 — **적과 지점(랜드마크)이 같은 함수를 부르게 하는 것**이 전부다.
## `forest_enemy._roll_drops`/`_spawn_loose`는 이 static을 부르는 얇은 껍데기다.
## 🔴 껍데기에 로직을 되돌려 적으면 `DropEntry` 배타 짝 규칙이 두 벌이 되고, **에러가 0이다.**
## 🔴 static에서 오토로드(`GameState`)를 컴파일타임 참조하지 마라 — `-s` 테스트가 컴파일 단계에서
##  죽는다(오토로드는 스크립트 컴파일 **뒤에** 등록된다). 그래서 `roll()`이 `gs`를 인자로 받는다.
## ⚠ 여기 각도 굴림은 전역 랜덤 스트림을 소비한다 — 테스트가 `seed()`를 잡으면 다른 굴림이 흔들린다.

## 픽업은 field/actors를 안 물어 순환 preload가 없다(방향도 field → props 단방향 유지).
const DropPickup := preload("res://src/props/drop_pickup.tscn")


## 반환 = `[{"id": StringName, "count": int, "unlock": StringName}]`
## 🔴 **반환 키가 계약이다** — `spawn_loose`와 `DropPickup.setup`이 양쪽에서 이 키를 본다. 바꾸면 조용히 갈라진다.
## 🔴 `gs`(= GameState, 없으면 null)가 null이면 관문을 못 재 순수 확률로 폴백한다 —
##  고립 테스트가 쓰는 경로다. 이 폴백을 없애지 마라.
static func roll(drops: Array[DropEntry], gs: Node) -> Array[Dictionary]:
	var rolled: Array[Dictionary] = []
	for drop: DropEntry in drops:
		# 🔴 이 가드는 **확률 굴림보다 앞**이고 **별도 줄**인 것이 계약이다 — 아래 until_unlock 분기에
		# 섞으면 `elif`가 `chance`를 건너뛰어 보너스 드롭이 모든 잡몹 확정 드롭이 된다.
		if drop.unlock_id != &"" and gs != null and gs.is_unlocked(drop.unlock_id):
			continue
		# 관문 드롭: until_unlock가 있으면 확률이 아니라 해금 상태가 정한다(미해금 = 확정).
		if drop.until_unlock != &"" and gs != null:
			if gs.is_unlocked(drop.until_unlock):
				continue
		elif randf() > drop.chance:
			continue
		var n := drop.min_count
		if drop.max_count > drop.min_count:
			n += randi() % (drop.max_count - drop.min_count + 1)
		if n > 0:
			# "unlock" 키 = 해금 드롭 — `id`가 비고 이쪽이 찬 항목이 두루마리다.
			rolled.append({"id": drop.item_id, "count": n, "unlock": drop.unlock_id})
	return rolled


## `origin`에 드롭마다 하나씩 심고 **균등 각도**로 흩뿌린다.
## 🔴 균등 각도는 의도다 — 랜덤이면 겹쳐 하나로 보여 「여러 개 나왔다」가 안 읽힌다. ⚠ 반경이 상수라
##  1~2개를 상정한 배치다(개수가 늘면 등급 후광이 겹친다 — 연출값이라 F5·스샷 몫).
## 🔴 **`add_child` → `global_position` → `setup` 순서가 계약이다** — 씬에 붙기 전엔 좌표계가 없고,
##  `setup`이 먼저면 scatter가 엉뚱한 자리에서 시작한다.
static func spawn_loose(scene: Node, origin: Vector2, rolled: Array[Dictionary]) -> void:
	var base_angle := randf() * TAU
	for i in rolled.size():
		var pickup := DropPickup.instantiate()
		scene.add_child(pickup)
		pickup.global_position = origin + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
		# base_angle + i·TAU/n → 2개면 정반대, 3개면 삼각형으로 흩어진다.
		pickup.setup(rolled[i]["id"], int(rolled[i]["count"]), base_angle + float(i) * TAU / float(rolled.size()),
			rolled[i].get("unlock", &""))
