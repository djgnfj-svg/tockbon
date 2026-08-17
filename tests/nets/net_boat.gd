extends RefCounted
## The one deployment: load with a key, launch with a click, and wait for a berth.
##
## Everything here is driven through `load_soldier` / `launch` / `step` — the same three calls the shell
## makes — and read back off the public columns. **The berth clock in particular is measured by whether
## `launch` is refused, not by reading `berth_free_in`**: a timer that runs while nothing consults it
## would look identical from the outside, and the click is the only thing the player ever sees.
##
## `net_battle` owns the combat rules and the phase order; this file owns only what a boat does.

const PORT_W := 24
const PORT_H := 12
## The cramped island: four land tiles, one of them held by the bison that stands on it, so exactly
## three are ever free. That is what makes "a boat with more cargo than shore waits" measurable at the
## boundary rather than by a landslide.
const COVE_W := 10
const COVE_H := 7


func run(t) -> void:
	_fleet_and_capacity(t)
	_launch_only_on_the_click(t)
	_berth_frees_at_two_crossings(t)
	_unload_placement(t)
	_boat_waits_for_shore(t)
	_cargo_rides_the_boat(t)


# -- how many boats, how many soldiers -------------------------------------------------------------

## **The 2 and the 5 are written out, never read back off `Rules.FLEET` / `Rules.CAP`.** A check whose
## bound comes from the constant it is checking shrinks with it: at `CAP = 4` a loop of `Rules.CAP` loads
## would board four, find `pending.size() == Rules.CAP`, and stay green about a capacity that moved.
func _fleet_and_capacity(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 12)
	var b := _battle_of(_port(), army, [_spawn(PORT_W, Rules.LION, 12, 9)], 999.0)
	t.eq(b.berth_free_in.size(), 2, "선석은 두 개다")
	t.eq(b.dock_count(), 2, "부두는 두 개다 (행 우선 순서가 곧 dock_index)")

	var boarded := 0
	for _i in 5:
		if b.load_soldier(Rules.CELL_MELEE):
			boarded += 1
	t.eq(boarded, 5, "다섯 명까지는 전부 태워진다")
	t.eq(b.pending.size(), 5, "한 배의 정원은 다섯이다")
	t.ok(not b.load_soldier(Rules.CELL_MELEE), "여섯 번째는 안 태워진다")
	t.ok(not b.load_soldier(Rules.CELL_RANGED), "명부에 없는 병종은 애초에 태울 사람이 없다")

	t.ok(b.launch(0), "첫 배가 나간다")
	for _i in 5:
		b.load_soldier(Rules.CELL_MELEE)
	t.ok(b.launch(1), "둘째 배가 나간다")
	# Loading while both boats are at sea is allowed — the load goes out on whichever berth frees first.
	t.ok(b.load_soldier(Rules.CELL_MELEE), "두 배가 바다에 있는 동안에도 태울 수 있다")
	t.eq(b.pending.size(), 1, "태운 병사는 다음 배에 남아 있다")
	t.ok(not b.launch(0), "선석이 둘뿐이라 셋째 배는 안 나간다")


# -- the click is the trigger ----------------------------------------------------------------------

func _launch_only_on_the_click(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 6)
	var b := _battle_of(_port(), army, [_spawn(PORT_W, Rules.LION, 12, 9)], 999.0)
	t.ok(not b.launch(0), "빈 배로 클릭하면 아무 일도 없다")

	b.load_soldier(Rules.CELL_MELEE)
	b.load_soldier(Rules.CELL_MELEE)
	t.ok(not b.launch(-1), "없는 부두 번호는 거절한다")
	t.ok(not b.launch(b.dock_count()), "부두 개수와 같은 번호도 거절한다")
	t.eq(b.pending.size(), 2, "거절당한 클릭은 화물을 건드리지 않는다")

	for _f in 100:
		b.begin_frame()
		b.step(0.1)
	t.eq(b.boats.size(), 0, "10초를 기다려도 배는 저절로 안 나간다")
	t.eq(b.soldier_state[0], Battle.SoldierState.LOADED, "탄 병사는 계속 탄 채로 있다")

	t.ok(b.launch(0), "클릭에 나간다")
	t.eq(b.boats.size(), 1, "배 한 척이 바다에 있다")
	t.ok(b.pending.is_empty(), "출항하면 대기 화물이 비워진다")
	t.eq(b.soldier_state[0], Battle.SoldierState.TRANSIT, "탄 병사는 이동 중이 된다")
	t.eq(int(b.boats[0]["dock_index"]), 0, "클릭한 부두로 간다")


# -- the berth clock -------------------------------------------------------------------------------

## `Rules.CROSSING` is one way, so a berth frees at twice that. Measured by the click being refused at
## 5.9 s and accepted at 6.0 s — one bite on each side, because a bound with a floor on one end and none
## on the other is half-measured.
func _berth_frees_at_two_crossings(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 12)
	var b := _battle_of(_port(), army, [_spawn(PORT_W, Rules.LION, 12, 9)], 999.0)
	for _i in 5:
		b.load_soldier(Rules.CELL_MELEE)
	b.launch(0)
	for _i in 5:
		b.load_soldier(Rules.CELL_MELEE)
	b.launch(1)
	b.load_soldier(Rules.CELL_MELEE)
	b.load_soldier(Rules.CELL_MELEE)

	for _f in 59:
		b.begin_frame()
		b.step(0.1)
	t.ok(not b.launch(0), "5.9초에는 아직 선석이 안 비었다")
	t.eq(b.pending.size(), 2, "거절당했으니 화물은 그대로다")

	b.begin_frame()
	b.step(0.1)
	t.ok(b.launch(0), "6.0초 — 왕복 %.1f초가 지나 선석이 비었다" % (2.0 * Rules.CROSSING))
	t.ok(b.pending.is_empty(), "이번엔 화물이 실려 나갔다")


# -- unloading -------------------------------------------------------------------------------------

## **This island has no enemies on purpose.** With one alive, the same frame that lands the boat also
## runs the movement phase and every soldier walks off its landing tile before it can be read — the
## positions asserted below would then be about the walk, not about the unload.
func _unload_placement(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 12)
	var b := _battle_of(_port(), army, [], 999.0)
	for _i in 5:
		b.load_soldier(Rules.CELL_MELEE)
	b.launch(0)
	b.begin_frame()
	b.step(Rules.CROSSING)

	var dock := b.dock_tile(0)
	var dock_at := Vector2(dock % PORT_W, dock / PORT_W)
	t.eq(b.soldier_pos[0], dock_at, "첫 병사가 부두 칸을 차지한다")

	var taken := {}
	var adjacent := 0
	var owned := 0
	var landed := 0
	for i in 5:
		if b.soldier_state[i] == Battle.SoldierState.ASHORE:
			landed += 1
		var p: Vector2 = b.soldier_pos[i]
		var tile := int(round(p.y)) * PORT_W + int(round(p.x))
		taken[tile] = true
		if maxf(absf(p.x - dock_at.x), absf(p.y - dock_at.y)) <= 1.0:
			adjacent += 1
		if b.grid.is_passable(int(round(p.x)), int(round(p.y))) and b.grid.reserved[tile] == i:
			owned += 1
	t.eq(landed, 5, "다섯 명 전부 상륙했다")
	t.eq(taken.size(), 5, "다섯이 서로 다른 칸에 섰다")
	t.eq(adjacent, 5, "나머지는 부두에서 가장 가까운 칸들에 섰다 (전부 이웃 칸)")
	t.eq(owned, 5, "다섯 칸 모두 땅이고 각자 자기 이름으로 예약됐다")
	t.ok(b.boats.is_empty(), "내려놓은 배는 사라진다")


## Three free tiles and a boat carrying four: the whole load waits rather than landing part of itself,
## because a partial landing silently reorders the deployment the player chose.
func _boat_waits_for_shore(t) -> void:
	var crowded := _army_of(Rules.CELL_MELEE, 4)
	var b := _battle_of(_cove(), crowded, [_spawn(COVE_W, Rules.BISON, 3, 2)], 999.0)
	for _i in 4:
		b.load_soldier(Rules.CELL_MELEE)
	b.launch(0)
	b.begin_frame()
	b.step(Rules.CROSSING)
	b.begin_frame()
	b.step(1.0)
	b.begin_frame()
	b.step(1.0)
	t.eq(b.boats.size(), 1, "빈 칸이 셋뿐이라 넷을 실은 배는 부두에서 기다린다")
	t.ok(float(b.boats[0]["t"]) > Rules.CROSSING, "건너기는 이미 끝났는데도 기다리는 중이다 (%.1f초)" % float(b.boats[0]["t"]))
	var waiting := 0
	for i in 4:
		if b.soldier_state[i] == Battle.SoldierState.TRANSIT:
			waiting += 1
	t.eq(waiting, 4, "넷 다 아직 배 위다 — 일부만 내리지 않는다")

	# Same shore, one soldier fewer: it fits, so it lands. The wait is about the count, not about a
	# broken unload.
	var fitting := _army_of(Rules.CELL_MELEE, 3)
	var c := _battle_of(_cove(), fitting, [_spawn(COVE_W, Rules.BISON, 3, 2)], 999.0)
	for _i in 3:
		c.load_soldier(Rules.CELL_MELEE)
	c.launch(0)
	c.begin_frame()
	c.step(Rules.CROSSING)
	t.ok(c.boats.is_empty(), "셋이면 딱 맞아서 내린다")
	t.eq(c.ashore_ids().size(), 3, "셋 다 상륙했다")


# -- what a soldier aboard can and cannot do -------------------------------------------------------

## The cargo's position IS the boat's, so a coastal enemy shoots where the boat actually is — and the
## soldier aboard does not shoot back even with the enemy well inside its range.
func _cargo_rides_the_boat(t) -> void:
	var army := _army_of(Rules.CELL_RANGED, 1)
	var b := _battle_of(_port(), army, [_spawn(PORT_W, Rules.CROW, 3, 4)], 999.0)
	b.load_soldier(Rules.CELL_RANGED)
	b.launch(0)
	b.begin_frame()
	b.step(0.1)
	t.eq(b.soldier_pos[0], Vector2(b.boats[0]["pos"]), "화물은 배 위치를 그대로 탄다")
	t.ok(b.soldier_pos[0].distance_to(b.enemy_pos[0]) < army.range_of(0) + Rules.REACH_BONUS,
			"까마귀는 그 병사의 사거리 안에 있다")
	b.begin_frame()
	b.step(0.1)
	b.begin_frame()
	b.step(0.1)
	t.eq(b.enemy_hp[0], Rules.hp_of(Rules.CROW), "그래도 배 위에서는 못 쏜다")
	t.ok(army.hp[0] < Rules.hp_of(Rules.CELL_RANGED), "맞기는 맞는다")


# -- fixtures --------------------------------------------------------------------------------------

## Water border, land inside, docks at (2,5) and (21,5). The boats sail from border water (0,5) and
## (23,5), so the two docks are symmetric.
func _port() -> Array:
	var rows := []
	for y in PORT_H:
		if y == 0 or y == PORT_H - 1:
			rows.append("~".repeat(PORT_W))
		elif y == 5:
			rows.append("~.D" + ".".repeat(PORT_W - 6) + "D.~")
		else:
			rows.append("~" + ".".repeat(PORT_W - 2) + "~")
	return rows


## Four land tiles and nothing else: a dock at (2,3), (3,3), (4,3) and (3,2).
func _cove() -> Array:
	var rows := []
	for y in COVE_H:
		if y == 2:
			rows.append("~~~.~~~~~~")
		elif y == 3:
			rows.append("~~D..~~~~~")
		else:
			rows.append("~".repeat(COVE_W))
	return rows


func _army_of(type_id: int, n: int) -> Army:
	var a := Army.new()
	for _i in n:
		a.add(type_id)
	return a


func _spawn(w: int, type_id: int, x: int, y: int) -> Dictionary:
	return {"type_id": type_id, "tile": y * w + x}


func _battle_of(rows: Array, army: Army, spawns: Array, limit: float) -> Battle:
	var g := Grid.new()
	# load_rows first, always: setup writes a reservation per enemy and load_rows clears the table.
	g.load_rows(rows)
	var b := Battle.new()
	b.setup(g, army, spawns, limit)
	return b
