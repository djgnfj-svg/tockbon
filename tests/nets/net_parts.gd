extends RefCounted
## The item table (`rules.gd`) and the board it lands on (`loadout.gd`). See
## `parts-on-a-board-not-on-the-body`.
##
## ⚠⚠ **The board is keyed by BEAST TYPE, not by summon slot** (티켓 11). Slot and type are 1:1 on the
## two summoned types, so most rows below pass a slot-keyed implementation too — the row that actually
## tells the keys apart is `_a_species_with_no_summon_slot_takes_equipment`, where a BEAR board has to
## exist at all.
##
## ⚠⚠ Stage 2 grows this file with the `Army`/`Battle` rows — "two soldiers of one type can differ" is
## the row that proves a fitted part actually reaches combat, not merely a board that fills and empties.

const LOADOUT_PATH := "res://src/sim/loadout.gd"


func run(t) -> void:
	_the_table(t)
	_the_empty_board(t)
	_fitting_and_unfitting(t)
	_one_cell_one_part(t)
	_no_cell_argument_on_fit(t)
	# -- stage 2: parts reach combat --------------------------------------------------------------
	_the_board_survives_the_body(t)
	_every_row_carries_a_slot(t)
	_the_roster_table(t)
	_two_soldiers_of_one_type_can_differ(t)
	_battle_reads_the_army(t)
	_enemies_stay_type_keyed(t)
	_slot_reserves_are_filtered_by_slot(t)
	# -- ticket 11: the board hangs on the type, and tags combo across the whole horde -------------
	_a_fitted_type_reaches_every_body_of_it(t)
	_a_species_with_no_summon_slot_takes_equipment(t)
	_the_tag_column(t)
	_tag_tiers(t)
	_effect_text_carries_the_tag(t)
	# -- 티켓 15: the enemy rows joined the unit table and must own no board ------------------------
	_no_board_belongs_to_an_enemy(t)


## A fresh `Army` with the OPENING slots registered and no bodies in them.
##
## ⚠⚠ **티켓 15 moved the slots off `rules.gd` and onto the army**, so `recruit(0)` on a bare
## `Army.new()` names a slot that does not exist and recruits nobody. Every row below that recruits by
## slot number wants the slots present and the roster empty, which is what this builds.
func _army() -> Army:
	var a := Army.new()
	for s in Rules.START_SLOTS.size():
		a.register_species(Rules.start_type_of(s))
	return a


# -- stage 2: parts reach combat ----------------------------------------------------------------------

## 「판은 짐승 종류의 것이라 몸이 죽어도 안 사라진다」. Mutation: clear the board inside `kill`.
func _the_board_survives_the_body(t) -> void:
	var a := _army()
	var id := a.recruit(0)
	a.loadout.take_card(1)
	a.loadout.fit(Rules.WOLF, 0)
	var fitted_hp := a.loadout.stat_of(Rules.WOLF, Rules.ITEM_COL_HP)
	a.kill(id)
	t.eq(a.loadout.stat_of(Rules.WOLF, Rules.ITEM_COL_HP), fitted_hp,
		"근접 종의 병사가 죽어도 그 종 판의 숫자는 그대로다")
	var next_id := a.recruit(0)
	t.eq(a.max_hp_of(next_id), fitted_hp,
		"그리고 다음에 그 슬롯에서 나온 병사가 끼워진 숫자를 그대로 읽는다")
	# ⚠⚠ 「그 병사는 그 숫자에서 태어난다」 — `max_hp_of` 자체가 아니라 `recruit`가 실제로 WRITE 한
	# `hp[next_id]`. Mutation: `army.gd`의 `hp[id] = max_hp_of(id)` -> `hp[id] = Rules.hp_of(t)` —
	# 위 줄만으로는 못 잡는다: `max_hp_of`는 여전히 올바른 값을 답하고, `hp[next_id]`만 기본값에서
	# 태어나 영원히 「다쳤다」로 읽힌다.
	t.eq(a.hp[next_id], fitted_hp,
		"그리고 실제로 그 숫자로 태어났다 — recruit 가 WRITE 한 hp[next_id] 자체를 잰다")


## ⚠ 「모든 명부 줄에 슬롯이 적혀 있다」. Mutation: `slot_id.append(slot)` -> `slot_id.append(-1)`.
func _every_row_carries_a_slot(t) -> void:
	var a := _army()
	a.add_starting_force()
	var bad := 0
	for i in a.type_id.size():
		var s := int(a.slot_id[i])
		if s < 0 or s >= a.slot_count():
			bad += 1
	t.eq(bad, 0, "새 군대의 모든 명부 줄이 유효한 슬롯을 갖고 있다")


## 「시작 병력은 표의 열 명이고 슬롯별로 6과 4다」. Mutation: `[CROW, 4, 1]` -> `[CROW, 0, 1]`.
func _the_roster_table(t) -> void:
	t.eq(Rules.roster_start_count(), 10, "시작 병력은 표의 합인 열 명이다")
	var a := _army()
	a.add_starting_force()
	# ⚠ **One row, ten wolves** (티켓 15). It was six and four; the second species moved to the opening
	# card, and the ten did not move — only how it is split.
	t.eq(Rules.START_SLOTS.size(), 1, "개막 표는 한 줄이다 (리터럴)")
	t.eq(a.living_ids_of_slot(0).size(), 10, "그 칸이 열로 시작한다")
	t.eq(a.living_ids_of_slot(1).size(), 0, "둘째 칸은 아직 없다 — 카드로 온다")


## ⚠⚠ 「같은 종류 병사 둘이 서로 다를 수 있다」 — THE row of the round. Mutation:
## `damage_of` -> `Rules.damage_of(int(type_id[i]))`.
## ⚠⚠ **Fixture item ids, named once.** They used to be `Rules.Part.ARM` and friends, which said what
## they did in their own name. An item id says nothing, so the three the fight-side rows lean on are
## pinned here with what each is for — and each is ASSERTED to move its column below, so a table edit
## that moves an item elsewhere reddens rather than quietly measuring nothing.
const ITEM_DAMAGE := 1     # 돌 목걸이 — 공격력 +1
const ITEM_PERIOD := 2     # 나무 발톱 — 공격주기 -0.10
const ITEM_SPEED := 3      # 마른 가죽 — 이동속도 +0.6
const ITEM_HP := 0         # 가죽끈 — 체력 +3
const ITEM_RANGE := 10     # 뺏은 창끝 — 사거리 +1


func _two_soldiers_of_one_type_can_differ(t) -> void:
	var plain := _army()
	var plain_id := plain.recruit(0)
	var armed := _army()
	var armed_id := armed.recruit(0)
	armed.loadout.take_card(ITEM_DAMAGE)
	armed.loadout.fit(Rules.WOLF, 0)
	t.eq(int(plain.type_id[plain_id]), int(armed.type_id[armed_id]),
		"두 병사는 같은 종류(근접)다 (자가 점검)")
	t.ok(armed.damage_of(armed_id) > plain.damage_of(plain_id),
		"장비를 낀 쪽의 공격력이 더 높다 — 같은 종류 병사 둘이 서로 달라졌다 (%.1f > %.1f)"
			% [armed.damage_of(armed_id), plain.damage_of(plain_id)])


## ⚠⚠ 「전투가 병사 숫자를 Army 에서 읽는다」 — driven THROUGH `battle.step`, never by calling an
## `Army` accessor and comparing it against itself (`plain.army.damage_of(0) / plain.army.period_of(0)`
## asserts `Army.damage_of != Army.damage_of` and proves nothing about `battle.gd` — the shape this row
## used to be). A melee soldier stands one tile from a stationary bison; `Battle.setup` zeroes both
## cooldowns, and `REACH_BONUS` (1.5) clears the one-tile gap even at base range 0.0, so ONE sub-step
## lands exactly one blow each way — the same fixture shape `net_battle._no_friendly_fire` already
## drives for the identical reason. Three lookups, three rows, matching the plan's three named
## mutations inside `battle.gd`'s soldier attack branch.
func _battle_reads_the_army(t) -> void:
	# -- army.damage_of(i): a fitted 팔 moves the FIRST blow the sub-step actually threw ------------
	var plain := _adjacent_bison_battle(-1)
	var armed := _adjacent_bison_battle(ITEM_DAMAGE)
	var plain_hit := Rules.hp_of(Rules.WOLF) - plain.enemy_hp[0]
	var armed_hit := Rules.hp_of(Rules.WOLF) - armed.enemy_hp[0]
	t.eq(plain_hit, Rules.damage_of(Rules.WOLF), "빈 판 병사는 종류값 그대로 때린다 (자가 점검)")
	t.ok(armed_hit > plain_hit,
		"장비를 낀 병사가 첫 타격에서 더 큰 피해를 준다 (%.1f > %.1f) — battle.step 이 army.damage_of 를 읽는다"
			% [armed_hit, plain_hit])
	t.eq(armed_hit, plain_hit + Rules.item_bonus(ITEM_DAMAGE, Rules.ITEM_COL_DAMAGE),
		"차이가 정확히 그 장비의 공격력 보너스다")
	# The enemy's own hp/type never moved — a fitted board must not leak onto the other side.
	t.eq(plain.enemy_type[0], armed.enemy_type[0], "적 종류는 양쪽 다 같다 (자가 점검)")

	# -- army.period_of(i): a fitted 손 moves the cooldown `step` actually WROTE after that blow ----
	var handed := _adjacent_bison_battle(ITEM_PERIOD)
	t.ok(is_equal_approx(plain._soldier_cd[0], Rules.period_of(Rules.WOLF)),
		"빈 판 병사의 쿨타임은 종류값 그대로 다시 찬다 (자가 점검)")
	t.ok(handed._soldier_cd[0] < plain._soldier_cd[0],
		"주기 장비를 낀 병사는 더 짧은 쿨타임으로 다시 찬다 (%.3f < %.3f) — battle.step 이 army.period_of 를 읽는다"
			% [handed._soldier_cd[0], plain._soldier_cd[0]])
	t.ok(is_equal_approx(handed._soldier_cd[0], handed.army.period_of(0)),
		"그 쿨타임이 정확히 army.period_of(0) 이다")

	# -- army.speed_of(i): a fitted 다리 moves how far a soldier OUT of reach walks in one sub-step --
	var plain_walk := _walk_probe(-1)
	var leg_walk := _walk_probe(5)
	var plain_moved := _WALK_START.distance_to(plain_walk.soldier_pos[0])
	var leg_moved := _WALK_START.distance_to(leg_walk.soldier_pos[0])
	t.ok(plain_moved <= Rules.speed_of(Rules.WOLF) * Rules.SIM_SUBSTEP_SEC + Rules.EPS,
		"빈 판 병사는 종류값 그대로의 속도로, 딱 한 서브스텝만큼만 걸었다 (자가 점검)")
	t.ok(leg_moved > plain_moved,
		"다리를 낀 병사가 한 서브스텝에 더 멀리 걷는다 (%.4f > %.4f) — battle.step 이 army.speed_of 를 읽는다"
			% [leg_moved, plain_moved])
	t.ok(leg_moved <= leg_walk.army.speed_of(0) * Rules.SIM_SUBSTEP_SEC + Rules.EPS,
		"그리고 그 거리가 army.speed_of(0) 을 넘지 않는다 — 딱 한 서브스텝만큼만 걸었다")


## ⚠ 「적 숫자는 종류에서 그대로 읽는다」 — the opposite direction: a fitted PLAYER board must move
## NOTHING about what an enemy blow takes off a soldier. Driven through `battle.step`, comparing an
## unfitted army against one with 팔 fitted (which raises the PLAYER's own damage and nothing else) —
## if the enemy's damage read `army.loadout.bonus(0, PART_COL_DAMAGE)` by mistake, the armed soldier
## would take MORE from an identical enemy than the plain one does. **Two branches**, because the
## mutation this row guards against has two homes in `battle.gd`'s enemy attack code: the instant-hit
## path (any enemy without a wind-up — driven here with the bison) and the wind-up-complete path
## (driven here with the lion, the only type that carries one).
func _enemies_stay_type_keyed(t) -> void:
	var plain := _adjacent_bison_battle(-1)
	var armed := _adjacent_bison_battle(3)
	t.eq(plain.army.hp[0], Rules.hp_of(Rules.WOLF) - Rules.damage_of(Rules.WOLF),
		"안 낀 병사는 들소의 종류값 그대로 맞는다 (자가 점검 — 즉시 타격 갈래)")
	t.eq(armed.army.hp[0], plain.army.hp[0],
		"팔을 낀 판이어도 들소가 주는 피해는 그대로다 — 적은 플레이어 판을 안 읽는다 (즉시 타격 갈래)")

	var plain_lion := _adjacent_lion_battle(-1)
	var armed_lion := _adjacent_lion_battle(3)
	t.ok(plain_lion.army.hp[0] < Rules.hp_of(Rules.WOLF), "예고가 끝나자 사자가 실제로 때렸다 (자가 점검)")
	t.eq(plain_lion.army.hp[0], Rules.hp_of(Rules.WOLF) - Rules.damage_of(Rules.LION),
		"안 낀 병사는 사자의 종류값 그대로 맞는다 (자가 점검 — 예고 갈래)")
	t.eq(armed_lion.army.hp[0], plain_lion.army.hp[0],
		"팔을 낀 판이어도 사자가 주는 피해는 그대로다 — 적은 플레이어 판을 안 읽는다 (예고 갈래)")


## 「슬롯 예비 병력은 슬롯으로 걸러진다」. Mutation: `army.slot_id[i] == slot` -> `army.type_id[i] == want`.
## ⚠ Built with a body whose SLOT is relabelled to 1 while its TYPE stays WOLF (slot 1's own
## bound type is CROW) — a net-local stand-in for "a third slot bound to WOLF" that never
## touches `Army.slots`. Type-keyed filtering and slot-keyed filtering only disagree on exactly
## this body, which is why the row needs it rather than two ordinary recruits.
func _slot_reserves_are_filtered_by_slot(t) -> void:
	# ⚠ A second slot has to EXIST for the filter to have two answers, and the opening table has one
	# row since 티켓 15 — so this fixture registers the second species itself.
	var a := _army()
	a.register_species(Rules.CROW)
	var id0 := a.recruit(0)
	var id1 := a.recruit(0)
	a.slot_id[id1] = 1
	var grid := Grid.new()
	grid.load_rows(Islands.rows())
	var b := Battle.new()
	b.setup(grid, a, [])
	var slot0 := b.slot_reserve_ids(0)
	var slot1 := b.slot_reserve_ids(1)
	t.eq(slot0, [id0], "슬롯 0의 예비 명단이 근접 타입 전부가 아니라 슬롯 0의 몸만이다")
	t.eq(slot1, [id1], "슬롯 1의 예비 명단은 타입이 근접이어도 슬롯 1로 라벨된 몸을 담는다")


## A hand-built open arena — never the real islands, the same reasoning `net_battle`'s own header
## gives: a fixture that moves when someone edits an island measures the island, not the rule.
const _ARENA_W := 20
const _ARENA_H := 10

func _open_arena() -> Array:
	var rows := []
	for y in _ARENA_H:
		if y == 0 or y == _ARENA_H - 1:
			rows.append("~".repeat(_ARENA_W))
		else:
			rows.append("~" + ".".repeat(_ARENA_W - 2) + "~")
	return rows


## Puts a soldier on the island the way a landing would — state, position AND goal, plus the tile
## reservation `battle` writes on unload. `net_battle._ashore`'s own shape.
func _ashore_at(b: Battle, i: int, p: Vector2) -> void:
	b.soldier_state[i] = Battle.SoldierState.ASHORE
	b.soldier_pos[i] = p
	b._soldier_goal[i] = p
	var claimed := b.grid.reserved
	claimed[_tile_key(p, b.grid.w)] = i
	b.grid.reserved = claimed


func _tile_key(p: Vector2, w: int) -> int:
	return int(round(p.y)) * w + int(round(p.x))


## One melee soldier one tile from a stationary bison, `part` (a `Rules.Part`, or -1 for none) fitted
## into slot 0's board, driven exactly one sub-step through the real `battle.step`.
func _adjacent_bison_battle(part: int) -> Battle:
	var b := _adjacent_battle(part, Rules.WOLF)
	b.begin_frame()
	b.step(Rules.SIM_SUBSTEP_SEC)
	return b


## The same fixture with a lion — which announces before it strikes — driven until its wind-up ends
## and the blow actually lands. `net_battle`'s own "wait the wind-up out" shape: nobody here walks
## while it runs, so the 1-tile gap the fixture was built at is still the one the blow lands at.
func _adjacent_lion_battle(part: int) -> Battle:
	var b := _adjacent_battle(part, Rules.LION)
	var whole := Rules.hp_of(Rules.WOLF)
	for _f in 40:
		b.begin_frame()
		b.step(0.05)
		if b.army.hp[0] < whole:
			break
	return b


func _adjacent_battle(part: int, enemy_type: int) -> Battle:
	var a := _army()
	a.recruit(0)
	if part >= 0:
		a.loadout.take_card(part)
		a.loadout.fit(Rules.WOLF, 0)
	var grid := Grid.new()
	grid.load_rows(_open_arena())
	var b := Battle.new()
	b.setup(grid, a, [{"type_id": enemy_type, "tile": _tile_key(Vector2(10, 5), _ARENA_W)}])
	b._committed = true
	_ashore_at(b, 0, Vector2(9, 5))
	return b


## The soldier starts far enough from the (stationary, harmless-at-this-range) enemy that one
## sub-step is pure movement — no attack can land on either side yet.
const _WALK_START := Vector2(2.0, 5.0)

func _walk_probe(part: int) -> Battle:
	var a := _army()
	a.recruit(0)
	if part >= 0:
		a.loadout.take_card(part)
		a.loadout.fit(Rules.WOLF, 0)
	var grid := Grid.new()
	grid.load_rows(_open_arena())
	var b := Battle.new()
	b.setup(grid, a, [{"type_id": Rules.WOLF, "tile": _tile_key(Vector2(18, 5), _ARENA_W)}])
	b._committed = true
	_ashore_at(b, 0, _WALK_START)
	b.begin_frame()
	b.step(Rules.SIM_SUBSTEP_SEC)
	return b


# -- the table --------------------------------------------------------------------------------------

func _the_table(t) -> void:
	# 「칸은 여섯이고 장비는 그보다 많다」 — both halves. **The second half is the point of the rewrite**:
	# with named cells the table could only ever be as long as the body had parts.
	t.eq(Rules.ITEM_CELLS, 6, "한 판의 칸은 여섯이다")
	t.ok(Rules.item_count() > Rules.ITEM_CELLS,
		"장비 종류가 칸 수보다 많다 (%d > %d) — 판을 채우는 방법이 하나가 아니다" %
			[Rules.item_count(), Rules.ITEM_CELLS])

	# 「장비 표의 모든 줄이 이름 + 다섯 숫자 + 등급 + 딱지다」. Mutation: drop the last column of a row.
	var short_rows := 0
	for p in Rules.item_count():
		if Rules.ITEMS[p].size() != Rules.ITEM_COL_TOTAL + 3:
			short_rows += 1
	t.eq(short_rows, 0, "장비 표의 모든 줄이 이름 하나 · 숫자 다섯 · 등급 하나 · 딱지 하나다")

	# 「이름 없는 장비가 없고, 이름이 겹치는 장비도 없다」 — the card says the name and nothing else
	# identifies it on screen.
	var names := {}
	var nameless := 0
	for p in Rules.item_count():
		var nm := Rules.item_name_of(p)
		if nm == "":
			nameless += 1
		names[nm] = true
	t.eq(nameless, 0, "이름 없는 장비가 없다")
	t.eq(names.size(), Rules.item_count(), "이름이 겹치는 장비도 없다")

	# 「등급 넷이 전부 실제로 쓰인다」 — a rarity with no items is a draw that can never land.
	var empty_rarity := 0
	for r in Rules.RARITY_WEIGHT.size():
		if Rules.items_of_rarity(r).size() == 0:
			empty_rarity += 1
	t.eq(empty_rarity, 0, "등급 넷 전부에 장비가 하나 이상 있다")

	# ⚠ 「어떤 부위도 아무 숫자도 안 움직이지 않는다」 — a part that exists and does nothing would still
	# pass every other row here, which is why this one measures every row independently rather than the
	# table as a whole. Mutation: zero out the ARM row.
	var dead_parts := 0
	for p in Rules.item_count():
		var moves_something := false
		for c in Rules.ITEM_COL_TOTAL:
			if not is_equal_approx(Rules.item_bonus(p, c), 0.0):
				moves_something = true
		if not moves_something:
			dead_parts += 1
	t.eq(dead_parts, 0, "장비 전부가 적어도 하나의 숫자를 움직인다 — 있으나 마나 한 장비가 없다")

	# ⚠ 「여섯을 다 끼워도 공격주기가 0.2초 밑으로 안 간다」 — the bound is a LITERAL, not the table's own
	# sum, because a bound read out of the table it checks would move with the mutation it exists to
	# catch. Mutation: HAND's period bonus -0.15 -> -1.50.
	# ⚠ **The WORST board, not an arbitrary one**: six copies of the biggest period drop in the table.
	# A board of one mild item would clear 0.2 s while the mutation this row exists for was live.
	var worst := 0
	for p in Rules.item_count():
		if Rules.item_bonus(p, Rules.ITEM_COL_PERIOD) < Rules.item_bonus(worst, Rules.ITEM_COL_PERIOD):
			worst = p
	var full := Loadout.new()
	for p in Rules.ITEM_CELLS:
		full.board[0 * Rules.ITEM_CELLS + p] = worst
	var full_period := full.stat_of(0, Rules.ITEM_COL_PERIOD)
	t.ok(full_period >= 0.2,
		"여섯을 다 끼운 판의 공격주기가 0.2초 밑으로 안 간다 (%.2f)" % full_period)


# -- 티켓 15: no board belongs to an enemy ----------------------------------------------------------
## **The enemy rows are in `Rules.UNITS` now**, so every bound `Loadout` used to range-check against
## `TYPE_COUNT` is a place a spearman could be handed a helmet. The bound is `player_type_count()`,
## and this is the row that says so from the outside.
##
## ⚠ Mutation: `player_type_count()` back to `UNITS.size()` inside `loadout.gd`.
func _no_board_belongs_to_an_enemy(t) -> void:
	var lo := Loadout.new()
	lo.take_card(0)
	t.eq(lo.board.size(), Rules.player_type_count() * Rules.ITEM_CELLS,
		"판은 아군 종 수 곱하기 칸 수다 — 표 전체가 아니다")
	var enemy := Rules.player_type_count()
	t.ok(Rules.side_of(enemy) == Rules.Side.ENEMY, "%d 번이 적 줄이다 (자가 점검)" % enemy)
	t.eq(lo.fit(enemy, 0), false, "적 편 종에는 장비를 못 낀다")
	t.eq(lo.held.size(), 1, "그리고 거절이라 더미도 그대로다 — 아무것도 안 변했다")
	t.eq(lo.fitted_item(enemy, 0), -1, "적 편 종의 칸은 늘 비어 있다고 답한다")
	t.eq(lo.stat_of(enemy, Rules.ITEM_COL_HP), 0.0, "적 편 종의 판 숫자는 0이다 — 판이 없으므로")
	t.eq(lo.unfit(enemy, 0), false, "적 편 종의 칸은 뺄 수도 없다")
	# The floor under all five ceilings above: the LAST player row does everything the enemy row cannot.
	var last := Rules.player_type_count() - 1
	t.eq(lo.fit(last, 0), true, "그러나 마지막 아군 종에는 낀다 — 전부 거절하는 판이 아니다 (자가 점검)")


# -- the empty board ----------------------------------------------------------------------------------

func _the_empty_board(t) -> void:
	# 「빈 판의 숫자는 UNITS 그대로다」 — WOLF: 14 · 2 · 1.0 · 0 · 4, as literals.
	# Mutation: make `stat_of` return `bonus(...)` alone (drops the base entirely).
	var lo := Loadout.new()
	t.eq(lo.board.size(), Rules.player_type_count() * Rules.ITEM_CELLS,
		"판이 다섯 종 전부의 것이다 — 소환 슬롯 수가 아니라 종류 수 곱하기 칸 수다")
	t.eq(lo.stat_of(Rules.WOLF, Rules.ITEM_COL_HP), 14.0, "빈 판의 체력이 UNITS 그대로 14다")
	t.eq(lo.stat_of(Rules.WOLF, Rules.ITEM_COL_DAMAGE), 2.0, "빈 판의 공격력이 2다")
	t.eq(lo.stat_of(Rules.WOLF, Rules.ITEM_COL_PERIOD), 1.0, "빈 판의 공격주기가 1.0이다")
	t.eq(lo.stat_of(Rules.WOLF, Rules.ITEM_COL_RANGE), 0.0, "빈 판의 사거리가 0이다")
	t.eq(lo.stat_of(Rules.WOLF, Rules.ITEM_COL_SPEED), 4.0, "빈 판의 이동속도가 4다")
	t.eq(lo.fitted_item(Rules.WOLF, 0), -1, "빈 칸은 -1로 읽힌다")
	t.eq(lo.fitted_item(-1, 0), -1, "종류 범위 밖도 -1이다")
	t.eq(lo.fitted_item(Rules.player_type_count(), 0), -1, "종류 범위 위쪽 밖도 -1이다")
	t.eq(lo.fitted_item(Rules.WOLF, 999), -1, "칸 범위 밖도 -1이다")


# -- fit / unfit ---------------------------------------------------------------------------------------

func _fitting_and_unfitting(t) -> void:
	# 「장비를 끼우면 그 장비가 적힌 칸만 움직이고 나머지는 그대로다」. Mutation: make `bonus` return 0.0.
	# ⚠ **Every column is compared against the TABLE's own number for that item**, not against a literal.
	# The literal version said 「체력이 정확히 4 올랐다」 about a chest, and it could only ever be true of
	# one row of one table.
	var lo := Loadout.new()
	var before: Array[float] = []
	for col in Rules.ITEM_COL_TOTAL:
		before.append(lo.stat_of(Rules.WOLF, col))
	lo.take_card(ITEM_HP)
	t.ok(lo.fit(Rules.WOLF, 0), "장비 카드를 근접 종에 끼운다")
	var moved_bad := 0
	for col in Rules.ITEM_COL_TOTAL:
		if not is_equal_approx(lo.stat_of(Rules.WOLF, col), before[col] + Rules.item_bonus(ITEM_HP, col)):
			moved_bad += 1
	t.eq(moved_bad, 0, "다섯 칸이 전부 표가 말한 만큼만 움직였다")
	t.ok(not is_equal_approx(Rules.item_bonus(ITEM_HP, Rules.ITEM_COL_HP), 0.0),
		"그 장비가 실제로 체력을 움직인다 (자가 점검 — 0이면 위 줄은 아무것도 안 재고 있다)")
	# ⚠ **Cell 0, not cell 1.** Cells have no names, so a fit lands in the first EMPTY one and nothing
	# about the card decides where.
	t.eq(lo.fitted_item(Rules.WOLF, 0), ITEM_HP, "첫 빈 칸에 그 장비가 들어갔다")

	# ⚠ 「부위를 빼면 숫자가 정확히 원래대로 돌아온다」. Mutation: make `unfit` clear the cell without
	# appending to the pile (the number would still return, so the check is written against the PILE).
	var empty_val := Loadout.new().stat_of(Rules.WOLF, Rules.ITEM_COL_HP)
	var pile_before := lo.held.size()
	t.ok(lo.unfit(Rules.WOLF, 0), "장비를 뺀다")
	t.eq(lo.stat_of(Rules.WOLF, Rules.ITEM_COL_HP), empty_val, "체력이 정확히 빈 판 값으로 돌아왔다")
	t.eq(lo.held.size(), pile_before + 1, "그리고 더미가 하나 늘었다 — 뺀 장비가 사라지지 않았다")
	t.eq(int(lo.held[lo.held.size() - 1]), ITEM_HP, "더미에 돌아온 카드가 그 장비 그대로다")

	# 빈 칸을 빼려 하면 false다.
	t.ok(not lo.unfit(Rules.WOLF, 5), "빈 칸을 빼려 하면 거절한다")


func _one_cell_one_part(t) -> void:
	# ⚠⚠ **INVERTED BY THE REWRITE.** This used to be 「a second chest pushes the first one back to the
	# pile」 — with named cells a fit always had a target and a swap was the only sensible answer. With
	# unnamed cells **a full board REFUSES**: a swap would have to pick a victim, and a victim picked
	# inside a fit is a choice the player never made. Mutation: make `fit` overwrite cell 0 when full.
	var lo := Loadout.new()
	for _i in Rules.ITEM_CELLS + 1:
		lo.take_card(ITEM_HP)
	for cell in Rules.ITEM_CELLS:
		t.ok(lo.fit(Rules.WOLF, 0), "%d번 칸까지 채운다" % cell)
	t.eq(lo.first_empty(Rules.WOLF), -1, "판이 꽉 찼다 (자가 점검)")
	var pile_full := lo.held.size()
	var board_full := lo.board.duplicate()
	t.ok(not lo.fit(Rules.WOLF, 0), "꽉 찬 판에는 더 못 끼운다")
	t.eq(lo.held.size(), pile_full, "거절당한 카드는 더미에 그대로 남는다")
	t.eq(lo.board, board_full, "그리고 어느 칸도 안 바뀌었다 — 아무도 안 밀려났다")


func _no_cell_argument_on_fit(t) -> void:
	# 「머리 칸에 다리를 넣을 함수가 없다」 — a source scan, declared as one: the behaviour it stands for
	# (there is no arrangement that puts a leg in the head cell) is unbuildable, which is why a text
	# check is all there is to buy here. Mutation: add a `part` parameter to `fit`.
	var f := FileAccess.open(LOADOUT_PATH, FileAccess.READ)
	t.ok(f != null, "loadout.gd 를 읽었다")
	if f == null:
		return
	var text := f.get_as_text()
	var at := text.find("func fit(")
	t.ok(at >= 0, "fit 함수를 찾았다")
	if at < 0:
		return
	var close := text.find(")", at)
	var sig := text.substr(at, close - at + 1)
	t.eq(sig, "func fit(beast_type: int, held_index: int)",
		"fit 의 매개변수가 짐승 종류와 더미 인덱스뿐이다 — 칸을 고르는 인자가 없다 (%s)" % sig)


# -- ticket 11: the board hangs on the TYPE, and tags combo across the whole horde --------------------

## ⚠ Fixture item ids for the tag rows, pinned with what each is for — and each is asserted below to
## carry the tag it is picked for, so a table edit that moves an item elsewhere reddens rather than
## quietly measuring nothing.
const ITEM_TEMPO := 5      # 말린 힘줄 — 공격주기 -0.05 · 공속 딱지
const ITEM_STORM := 17     # 폭풍의 가죽 — 공격주기 -0.25 (표 최대 낙폭) · 공속 딱지
const ITEM_BLEED := 7      # 부싯돌 이빨 — 공격력 +2 · 출혈 딱지


## `n` copies of `item` onto `beast_type`'s board, through the real take/fit path.
func _fit_n(lo: Loadout, item: int, n: int, beast_type: int) -> void:
	for _i in n:
		lo.take_card(item)
		lo.fit(beast_type, 0)


## 「종류에 입힌 장비가 그 종류의 모든 병사에 닿는다」. Mutation: key `damage_of` back onto a per-body
## copy of the board.
func _a_fitted_type_reaches_every_body_of_it(t) -> void:
	var a := _army()
	var id0 := a.recruit(0)
	var id1 := a.recruit(0)
	var before := a.damage_of(id0)
	a.loadout.take_card(ITEM_DAMAGE)
	a.loadout.fit(Rules.WOLF, 0)
	t.ok(a.damage_of(id0) > before, "종류에 입힌 장비가 첫 병사에 닿았다 (%.1f > %.1f)"
			% [a.damage_of(id0), before])
	t.eq(a.damage_of(id0), a.damage_of(id1),
		"같은 종류의 두 병사가 같은 값을 읽는다 — 판은 종류의 것이다")


## ⚠⚠ 「소환 칸에 없는 종에게도 장비가 들어간다」 — THE row that tells the two keys apart: slot and
## type are 1:1 on the summoned pair, and only a species with no slot has a board under one key and
## none under the other. Mutation: key `board` back onto `army.slot_count()`.
func _a_species_with_no_summon_slot_takes_equipment(t) -> void:
	# ⚠ **곰이 그 종이다** — 들소가 이 자리를 맡던 시절 들소는 적이었고, 적에게는 이제 판이 아예 없다.
	# 판이 있으면서 소환 칸이 없는 종은 **아군 편이면서 아직 등록 안 된 종**뿐이다.
	var boxless := Rules.BEAR
	var opening := Army.new()
	opening.add_starting_force()
	var bound := opening.slot_of_type(boxless) >= 0
	t.ok(not bound, "곰은 소환 칸에 없다 (자가 점검 — 이 전제가 무너지면 이 줄은 키를 못 가른다)")
	t.eq(Rules.side_of(boxless), Rules.Side.PLAYER, "그리고 곰은 아군 편이다 (자가 점검)")
	var lo := Loadout.new()
	lo.take_card(ITEM_BLEED)
	t.ok(lo.fit(boxless, 0), "소환 칸에 없는 곰에게도 장비가 들어간다 — 버리는 카드가 없다")
	t.eq(lo.fitted_item(boxless, 0), ITEM_BLEED, "곰 판 첫 칸에 그 장비가 있다")
	t.eq(lo.tag_count(Rules.Tag.BLEED), 1, "곰 판의 딱지가 무리 전체 집계에 든다")
	t.eq(lo.stat_of(boxless, Rules.ITEM_COL_DAMAGE),
		Rules.damage_of(boxless) + Rules.item_bonus(ITEM_BLEED, Rules.ITEM_COL_DAMAGE),
		"그리고 곰의 숫자를 실제로 민다")


## ⚠ 딱지 열 전수 검사 — 열여덟 줄 전부, 계획의 배정표 그대로. **이름으로 핀한다**: 표가 재정렬돼도
## 재고, 리터럴은 Rules 에서 되읽지 않는다. Mutation: swap any one item's tag.
## ⚠ 개수 검사 다섯 줄이 이 검사 자체의 뒤집기다 — 전부 NONE 으로 읽는 스캐너는 배정표 비교를 그냥
## 통과할 수 없고(불일치 12), 통과하더라도 개수 줄 다섯에서 선다.
func _the_tag_column(t) -> void:
	var expected := {
		"나무 발톱": Rules.Tag.BLEED,
		"뼛조각": Rules.Tag.BLEED,
		"부싯돌 이빨": Rules.Tag.BLEED,
		"늑대 송곳니": Rules.Tag.BLEED,
		"말린 힘줄": Rules.Tag.ATK_SPEED,
		"사슴 힘줄": Rules.Tag.ATK_SPEED,
		"폭풍의 가죽": Rules.Tag.ATK_SPEED,
		"뺏은 창끝": Rules.Tag.RANGE,
		"사냥꾼의 눈": Rules.Tag.RANGE,
		"돌 목걸이": Rules.Tag.DEBUFF,
		"방패 조각": Rules.Tag.DEBUFF,
		"우두머리의 뿔": Rules.Tag.DEBUFF,
		"가죽끈": Rules.TAG_NONE,
		"마른 가죽": Rules.TAG_NONE,
		"무두질 가죽": Rules.TAG_NONE,
		"바람 갈기": Rules.TAG_NONE,
		"질주의 발": Rules.TAG_NONE,
		"청동 판": Rules.TAG_NONE,
	}
	t.eq(expected.size(), Rules.item_count(), "배정표가 장비 표의 줄 수 전부를 덮는다 (자가 점검)")
	var wrong := 0
	for i in Rules.item_count():
		var nm := Rules.item_name_of(i)
		if not expected.has(nm) or Rules.item_tag_of(i) != int(expected[nm]):
			wrong += 1
	t.eq(wrong, 0, "열여덟 장비의 딱지가 배정표와 전부 일치한다")
	var per := {}
	for i in Rules.item_count():
		var tg := Rules.item_tag_of(i)
		per[tg] = int(per.get(tg, 0)) + 1
	t.eq(int(per.get(Rules.Tag.BLEED, 0)), 4, "출혈 딱지는 넷이다")
	t.eq(int(per.get(Rules.Tag.ATK_SPEED, 0)), 3, "공속 딱지는 셋이다")
	t.eq(int(per.get(Rules.Tag.RANGE, 0)), 2, "범위 딱지는 둘이다")
	t.eq(int(per.get(Rules.Tag.DEBUFF, 0)), 3, "디버프 딱지는 셋이다")
	t.eq(int(per.get(Rules.TAG_NONE, 0)), 6, "딱지 없는 장비는 여섯이다")


## 숫자 딱지의 층 — 문턱 미달 0 · 문턱에서 그 층 값 · 높은 층이 낮은 층을 **대체**(합산 금지) · 무리
## 전체에서 세고 무리 전체에 평평하게 더해진다 · 딱지 효과 포함으로도 공격주기는 바닥에 선다.
## ⚠ 기대값은 전부 리터럴 산수다 — 문턱 표를 되읽으면 검사가 표와 같이 움직인다.
func _tag_tiers(t) -> void:
	t.eq(Rules.item_tag_of(ITEM_TEMPO), Rules.Tag.ATK_SPEED, "말린 힘줄은 공속 딱지다 (자가 점검)")
	t.eq(Rules.item_tag_of(ITEM_STORM), Rules.Tag.ATK_SPEED, "폭풍의 가죽도 공속 딱지다 (자가 점검)")
	t.eq(Rules.item_tag_of(ITEM_RANGE), Rules.Tag.RANGE, "뺏은 창끝은 범위 딱지다 (자가 점검)")

	# 공속 — 문턱 3/5, 효과 -0.10/-0.25. 말린 힘줄 자체가 -0.05 를 미니, 딱지 항은 그 위에 얹힌다.
	var two := Loadout.new()
	_fit_n(two, ITEM_TEMPO, 2, Rules.WOLF)
	t.ok(is_equal_approx(two.stat_of(Rules.WOLF, Rules.ITEM_COL_PERIOD), 1.0 - 2 * 0.05),
		"공속 2개 — 문턱 3 미달이라 딱지 항이 없다 (장비 자체 몫만 움직인다)")
	var three := Loadout.new()
	_fit_n(three, ITEM_TEMPO, 3, Rules.WOLF)
	t.ok(is_equal_approx(three.stat_of(Rules.WOLF, Rules.ITEM_COL_PERIOD), 1.0 - 3 * 0.05 - 0.10),
		"공속 3개 — 1층이 켜져 무리 공격주기에 -0.10 이 얹힌다")

	# 다섯 개를 **두 종의 판에 갈라** 끼워도 켜진다 — 개수는 무리 전체에서 센다. 그리고 5개 층은
	# -0.25 로 **대체**된다: 합산이면 -0.35 다.
	var five := Loadout.new()
	_fit_n(five, ITEM_TEMPO, 3, Rules.WOLF)
	_fit_n(five, ITEM_TEMPO, 2, Rules.BEAR)
	t.ok(is_equal_approx(five.stat_of(Rules.WOLF, Rules.ITEM_COL_PERIOD), 1.0 - 3 * 0.05 - 0.25),
		"공속 5개(두 판에 나눠) — 2층 -0.25 가 1층을 대체한다, 합산 -0.35 가 아니다")
	# 그리고 장비를 하나도 안 낀 종에도 같은 항이 평평하게 얹힌다 — 「전체 아티팩트」.
	t.ok(is_equal_approx(five.stat_of(Rules.CROW, Rules.ITEM_COL_PERIOD), 1.0 - 0.25),
		"장비 없는 까마귀의 공격주기에도 딱지 항 -0.25 가 얹힌다 — 효과는 무리 전체다")

	# 범위 — 문턱 2/4, 효과 +0.5/+1.0. 소 판에 끼워도 늑대의 사거리가 는다.
	var reach_one := Loadout.new()
	_fit_n(reach_one, ITEM_RANGE, 1, Rules.SWORDSMAN)
	t.ok(is_equal_approx(reach_one.stat_of(Rules.WOLF, Rules.ITEM_COL_RANGE), 0.0),
		"범위 1개 — 문턱 2 미달이라 딱지 항이 없다 (창끝의 +1 은 소 판의 것이다)")
	var reach_two := Loadout.new()
	_fit_n(reach_two, ITEM_RANGE, 2, Rules.SWORDSMAN)
	t.ok(is_equal_approx(reach_two.stat_of(Rules.WOLF, Rules.ITEM_COL_RANGE), 0.0 + 0.5),
		"범위 2개 — 1층이 켜져 늑대 사거리에 +0.5")
	var reach_four := Loadout.new()
	_fit_n(reach_four, ITEM_RANGE, 4, Rules.SWORDSMAN)
	t.ok(is_equal_approx(reach_four.stat_of(Rules.WOLF, Rules.ITEM_COL_RANGE), 0.0 + 1.0),
		"범위 4개 — 2층 +1.0 이 대체한다, 합산 +1.5 가 아니다")

	# ⚠ -0.5초 지뢰의 그 축: 폭풍의 가죽 여섯이면 장비 -1.5 에 공속 2층 -0.25 까지 얹혀도
	# `PERIOD_FLOOR_SEC` 에 선다. 바닥값은 리터럴이 아니라 상수 그대로 — 이 줄의 뜻은 「딱지 항도
	# clamp 안쪽에 있다」이고, 바닥 자체의 리터럴 핀은 `_the_table` 의 0.2 줄이 갖고 있다.
	var storm := Loadout.new()
	_fit_n(storm, ITEM_STORM, 6, Rules.WOLF)
	t.eq(storm.stat_of(Rules.WOLF, Rules.ITEM_COL_PERIOD), Rules.PERIOD_FLOOR_SEC,
		"공속 딱지 효과를 포함해도 공격주기는 바닥값에 선다")


## 카드와 정비 줄이 읽는 효과 문구 끝에 딱지 낱말 하나. Mutation: drop the tag append from
## `item_effect_text`.
func _effect_text_carries_the_tag(t) -> void:
	var tagged := Rules.item_effect_text(ITEM_TEMPO)
	t.ok(tagged.ends_with(Rules.tag_label_of(Rules.Tag.ATK_SPEED)),
		"딱지 있는 장비의 효과 줄 끝에 딱지 낱말이 실린다 (%s)" % tagged)
	var bare := Rules.item_effect_text(ITEM_HP)
	var leaked := 0
	for g in Rules.tag_kind_count():
		if bare.find(Rules.tag_label_of(g)) >= 0:
			leaked += 1
	t.eq(leaked, 0, "딱지 없는 장비의 효과 줄에는 딱지 낱말이 없다 (%s)" % bare)
