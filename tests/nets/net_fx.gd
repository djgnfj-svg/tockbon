extends RefCounted
## The SIM half of the twelve combat effects: what `Battle` puts in `events`, and the lion's wind-up.
##
## **Nothing here draws anything and nothing here is a view.** Every check builds a `Battle` with
## `.new()`, drives it with `begin_frame()` + `step(dt)` and reads `events` back — the whole point of
## `combat-juice`'s "How an event crosses from sim to view" is that the sim states FACTS and owns no
## duration, no colour and no pixel, so this file must be able to measure all of it with no tree at
## all. The view half lives in `net_fx_view`.
##
## Two step sizes, both deliberate, the same convention `net_battle` uses:
##  · `TICK_ONE` is ONE sub-step, the smallest amount of simulated time there is. A unit already inside
##    its reach does not walk, so an attack measured at that size happened at the distance the fixture
##    wrote.
##  · a real frame (0.02 ~ 0.1 s) wherever the thing being measured is time itself: the wind-up, the
##    blow-to-blow period, the per-frame ceiling on `events`.
##
## ⚠ **The accumulation check is the one that has to stay.** `events` is deliberately uncapped —
## combat-juice's refutation box argues a cap would not FIX a forgotten `begin_frame()`, it would make
## it quiet — so the only thing standing between that mistake and a silent leak is the pair of checks
## below: the per-frame ceiling with `begin_frame`, and the pile-up without it.


## ⚠ **`step` runs whole `Rules.SIM_SUBSTEP_SEC` sub-steps and carries the leftover**
## (`plan-then-watch`, 5.2), so there is no step too small to do anything any more: a `dt` under one
## sub-step runs ZERO phases and every column stays at its fixture value — which reads as 「the rule
## did not fire」 on every check at once. ⇒ **One sub-step is the smallest thing that happens**, and
## that is what `TICK_ONE` is. A unit already inside its reach still does not walk, so the fixtures
## that needed 「nobody moves」 keep the property they actually needed.
const TICK_ONE := Rules.SIM_SUBSTEP_SEC

const ARENA_W := 24
const ARENA_H := 12

## Enemies 6 + soldiers 13 — combat-juice's per-frame ceiling for `events`, from the biggest island.
const FRAME_CEILING := 19


func run(t) -> void:
	_attack_event_shape(t)
	_splash_carries_only_real_victims(t)
	_death_events_come_after_the_attacks_that_caused_them(t)
	_land_events(t)
	_begin_frame_clears(t)
	_frame_ceiling_and_the_pile_up_without_it(t)
	_lion_declares_before_it_lands(t)
	_windup_is_thrown_away_whole(t)
	_events_do_not_move_the_sim(t)


# -- the shape of one ATTACK -----------------------------------------------------------------------

## One melee soldier and one bison on adjacent tiles. Both swing on the same frame, so one frame
## carries both directions of the same event and `from_enemy` is the only thing telling them apart.
##
## ⚠ **Neither fighter is index 0, and that is the whole design of this fixture.** With the obvious
## one-soldier-one-enemy arena every id in sight is 0, so `"from": 0` hardcoded, `from_enemy` flipped
## and the attacker parameter dropped altogether are all indistinguishable from the truth. The idle
## pair are placed out of everyone's reach and detect, so they change nothing except the indices.
func _attack_event_shape(t) -> void:
	var army := _army_of([Rules.CROW, Rules.WOLF])
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [
		_spawn(ARENA_W, Rules.WOLF, 20, 9),   # idle: 8.9 tiles from the fight, outside detect 6
		_spawn(ARENA_W, Rules.WOLF, 13, 5),   # the one that swings
	])
	_ashore(b, 0, Vector2(3, 9))               # idle: 10.8 tiles away, outside its own 5.5 reach
	_ashore(b, 1, Vector2(12, 5))
	b.begin_frame()
	b.step(TICK_ONE)

	t.eq(b.events.size(), 2, "한 프레임에 병사 한 방과 적 한 방, 사건 둘이 나왔다")
	var mine: Dictionary = b.events[0]
	var theirs: Dictionary = b.events[1]
	# Soldiers are swung first inside `_phase_attacks`, so the order is not incidental: a view that
	# read `from` without `from_enemy` would draw the bison's blow as the soldier's.
	t.eq(int(mine["kind"]), Battle.Event.ATTACK, "첫 사건의 kind 가 ATTACK 이다 (문자열이 아니라 enum)")
	t.eq(bool(mine["from_enemy"]), false, "병사가 때린 것이다")
	t.eq(int(mine["from"]), 1, "공격자 id 가 그 병사의 army id 다 (0번이 아니라 1번이 때렸다)")
	t.eq(int(mine["to"]), 1, "표적이 1번 적이다")
	t.eq(float(mine["dmg"]), Rules.damage_of(Rules.WOLF), "피해가 근접 셀의 값이다")
	t.eq(float(mine["area"]), Rules.area_of(Rules.WOLF), "근접은 area 가 0.0 이다 — 뷰는 이걸로 찌르기를 고른다")
	t.eq(PackedInt32Array(mine["splash"]).size(), 0, "단일 표적이라 splash 가 비어 있다")

	t.eq(bool(theirs["from_enemy"]), true, "둘째 사건은 적이 때린 것이다")
	t.eq(int(theirs["from"]), 1, "공격자 id 가 그 적의 인덱스다 (1번 들소가 때렸다)")
	t.eq(int(theirs["to"]), 1, "표적이 1번 병사다")
	t.eq(float(theirs["dmg"]), Rules.damage_of(Rules.WOLF), "피해가 들소의 값이다")

	# The event is a fact ABOUT the damage, so the damage has to be in the columns too — an event
	# appended by a function that no longer subtracts anything would pass every check above.
	t.eq(b.enemy_hp[1], Rules.hp_of(Rules.WOLF) - Rules.damage_of(Rules.WOLF),
			"사건만 나온 게 아니라 적 HP 가 실제로 줄었다")
	t.eq(army.hp[1], Rules.hp_of(Rules.WOLF) - Rules.damage_of(Rules.WOLF),
			"병사 HP 도 실제로 줄었다")
	t.eq(b.enemy_hp[0], Rules.hp_of(Rules.WOLF), "구경만 한 적은 안 맞았다")
	t.eq(army.hp[0], Rules.hp_of(Rules.CROW), "구경만 한 병사도 안 맞았다")

	# A ranged blow is the same event with a non-zero range on the ATTACKER's type — that is the only
	# thing telling item 1 (tracer) from item 2 (lunge), so the view has to be able to reach it.
	var shooter := _army_of([Rules.CROW])
	var r := _battle_of(_open(ARENA_W, ARENA_H), shooter,
			[_spawn(ARENA_W, Rules.WOLF, 12, 5)])
	_ashore(r, 0, Vector2(8, 5))
	r.begin_frame()
	r.step(TICK_ONE)
	t.eq(r.events.size(), 1, "4칸 떨어진 원거리 병사만 쐈다 (들소는 사거리 밖)")
	var shot: Dictionary = r.events[0]
	t.ok(Rules.range_of(int(shooter.type_id[int(shot["from"])])) > 0.0,
			"공격자 타입의 사거리가 0보다 크다 — 뷰가 예광선을 고르는 기준")
	t.eq(float(shot["area"]), Rules.area_of(Rules.CROW), "원거리 셀은 area 가 1.0 이다")


# -- splash ----------------------------------------------------------------------------------------

## `splash` holds who ACTUALLY took the damage, never who stood in the radius. The difference is a
## corpse: an enemy already dead is skipped by the damage loop, and a view that flashed the radius
## instead would light it up.
func _splash_carries_only_real_victims(t) -> void:
	var army := _army_of([Rules.CROW])
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [
		_spawn(ARENA_W, Rules.WOLF, 12, 5),   # primary, 4.0 from the soldier
		_spawn(ARENA_W, Rules.WOLF, 13, 5),   # 1.0 from the primary — inside area 1.0
		_spawn(ARENA_W, Rules.WOLF, 13, 6),   # 1.41421 from the primary — outside it
	])
	_ashore(b, 0, Vector2(8, 5))
	b.begin_frame()
	b.step(TICK_ONE)
	var ev: Dictionary = b.events[0]
	var splash := PackedInt32Array(ev["splash"])
	t.eq(splash.size(), 1, "광역 하나가 2차 피해자 하나를 실었다")
	# Read through `has` and not `splash[0]`: an empty list is exactly what an emptied splash column
	# produces, and indexing it kills the rest of this net's checks instead of reddening one.
	t.ok(splash.has(1), "실린 것은 직교 1.0 칸의 형제다 (대각 1.41421 은 반경 밖)")
	t.ok(not splash.has(2), "대각 형제는 안 실렸다")
	# ⚠ **A `<=` and not an equality since 티켓 15**: the crow's own bleed lands on everyone the blow
	# hit and `_phase_status` takes its first sip in the SAME sub-step, so the exact figure carries one
	# tick of drip on top of the blow. What this row is about is that the splashed sibling took the
	# blow at all, and the row below (an untouched sibling at FULL hp) is the ceiling that keeps the
	# `<=` from being satisfied by anything.
	t.ok(b.enemy_hp[1] <= Rules.hp_of(Rules.WOLF) - Rules.damage_of(Rules.CROW) + Rules.EPS,
			"splash 에 실린 그 적이 실제로 맞았다")
	t.eq(b.enemy_hp[2], Rules.hp_of(Rules.WOLF), "안 실린 형제는 안 맞았다")

	# The same fixture with the sibling already dead. It is still inside the radius and must not be
	# in `splash` — the check that separates "who took it" from "who was standing there".
	var again := _army_of([Rules.CROW])
	var c := _battle_of(_open(ARENA_W, ARENA_H), again, [
		_spawn(ARENA_W, Rules.WOLF, 12, 5),
		_spawn(ARENA_W, Rules.WOLF, 13, 5),
	])
	_ashore(c, 0, Vector2(8, 5))
	c.enemy_alive[1] = 0
	c.enemy_hp[1] = 0.0
	c.begin_frame()
	c.step(TICK_ONE)
	var dead_ev: Dictionary = c.events[0]
	t.eq(PackedInt32Array(dead_ev["splash"]).size(), 0, "반경 안이어도 이미 죽은 놈은 splash 에 안 실린다")
	# ⚠ `<=` for the reason the row above carries: the crow's own bleed takes its first sip in the
	# same sub-step as the blow.
	t.ok(c.enemy_hp[0] <= Rules.hp_of(Rules.WOLF) - Rules.damage_of(Rules.CROW) + Rules.EPS,
			"그래도 주 표적은 맞았다 — 빈 splash 가 '아무 일도 없었다'가 아니다")


# -- deaths ----------------------------------------------------------------------------------------

## The attack that kills and the death it caused are in ONE frame's list, attacks first. `events` is
## oldest-first and the phase order is a contract, so a view can rely on seeing the blow before the
## burst — reversed, the burst would play a frame before the hit that caused it.
func _death_events_come_after_the_attacks_that_caused_them(t) -> void:
	var army := _army_of([Rules.WOLF])
	army.hp[0] = 1.0
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [
		_spawn(ARENA_W, Rules.WOLF, 13, 5),
		_spawn(ARENA_W, Rules.WOLF, 20, 9),
	])
	b.enemy_hp[0] = Rules.damage_of(Rules.WOLF)
	_ashore(b, 0, Vector2(12, 5))
	b.begin_frame()
	b.step(TICK_ONE)

	var attacks := []
	var deaths := []
	for k in b.events.size():
		var ev: Dictionary = b.events[k]
		if int(ev["kind"]) == Battle.Event.ATTACK:
			attacks.append(k)
		elif int(ev["kind"]) == Battle.Event.DEATH:
			deaths.append({"at": k, "id": int(ev["id"]), "is_enemy": bool(ev["is_enemy"])})
	t.eq(attacks.size(), 2, "둘이 서로 마지막 한 방을 쳤다 — ATTACK 이 둘이다")
	t.eq(deaths.size(), 2, "그리고 둘 다 죽었다 — DEATH 도 둘이다")
	t.ok(int(deaths[0]["at"]) > int(attacks[attacks.size() - 1]),
			"DEATH 는 그 프레임의 모든 ATTACK 뒤에 실린다 (공격이 사망보다 먼저 도는 계약)")
	t.eq(int(deaths[0]["id"]), 0, "먼저 실린 죽음이 0번 적이다")
	t.eq(bool(deaths[0]["is_enemy"]), true, "적의 죽음이다 — 뷰는 이걸로 파열 색을 고른다")
	t.eq(int(deaths[1]["id"]), 0, "그다음이 0번 병사다")
	t.eq(bool(deaths[1]["is_enemy"]), false, "병사의 죽음이다 (같은 id 0 이라도 진영이 다르다)")
	t.eq(b.enemy_alive[0], 0, "사건만 난 게 아니라 실제로 죽어 있다")
	t.eq(army.alive[0], 0, "병사도 실제로 죽어 있다")

	# ... and the death is announced exactly once. `alive` is already 0, so a check that only read the
	# columns could never tell "it died" from "it is still dying every frame".
	b.begin_frame()
	b.step(TICK_ONE)
	var again := 0
	for raw in b.events:
		var ev: Dictionary = raw
		if int(ev["kind"]) == Battle.Event.DEATH:
			again += 1
	t.eq(again, 0, "다음 프레임에는 같은 죽음이 다시 안 실린다")


# -- landings --------------------------------------------------------------------------------------

## One LAND per soldier put ashore, carrying the id and nothing else: `soldier_pos[id]` was written
## one line earlier and is the answer, so the ambiguous "which tile" (the dock the boat aimed at, or
## the spot this soldier actually stands on) never enters the event at all.
func _land_events(t) -> void:
	var army := _army_of([Rules.WOLF, Rules.WOLF])
	var b := _planning_battle_of(_port(), army, [_spawn(ARENA_W, Rules.LION, 20, 9)])
	# ⚠ **Two separate presses, never `a and b`.** A short-circuit would let a refused second summon
	# hide behind the first, and this row's whole subject is that TWO bodies land.
	var sea := _summonable_water_on(b)
	t.ok(sea >= 0, "띠 안에 소환할 물 칸이 있다 (자가 점검 — 없으면 아래가 전부 공허하다)")
	t.ok(b.summon(0, sea) >= 0, "병사 하나를 배에 실었다")
	t.ok(b.summon(0, sea) >= 0, "병사 둘을 배에 실었다 — 한 명에 한 척이다")
	t.eq(b.boats.size(), 2, "배가 정확히 두 척이다 — 둘째 소환이 거부되지 않았다")
	t.ok(b.commit(), "시작을 눌러 두 척을 다 띄웠다")

	var lands := []
	var frames := 0
	while frames < 80 and lands.is_empty():
		frames += 1
		b.begin_frame()
		b.step(0.1)
		for raw in b.events:
			var ev: Dictionary = raw
			if int(ev["kind"]) == Battle.Event.LAND:
				lands.append(int(ev["id"]))
	t.ok(frames < 80, "배가 %d 프레임 만에 도착했다 — 루프가 헛돌지 않았다" % frames)
	t.eq(lands.size(), 2, "내린 병사 수만큼 LAND 가 나왔다")
	t.ok(lands.has(0) and lands.has(1), "LAND 가 실은 것은 그 두 병사의 id 다")
	var ashore := b.ashore_ids()
	t.eq(ashore.size(), 2, "그 프레임에 둘 다 실제로 상륙해 있다")
	var off := 0
	for raw_id in lands:
		var i := int(raw_id)
		if b.soldier_pos[i] == Battle.OFFMAP:
			off += 1
	t.eq(off, 0, "LAND 가 난 병사의 자리는 이미 격자 위다 — 뷰가 soldier_pos 로 링을 놓는다")
	t.ok(b.soldier_pos[0].distance_to(b.soldier_pos[1]) <= 1.5,
			"둘이 붙어 내렸다 (상륙지에서 BFS) — 링 반지름 20 이 그래서 타일 반 칸이다")


# -- begin_frame -----------------------------------------------------------------------------------

func _begin_frame_clears(t) -> void:
	var army := _army_of([Rules.WOLF])
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [_spawn(ARENA_W, Rules.WOLF, 13, 5)])
	_ashore(b, 0, Vector2(12, 5))
	b.begin_frame()
	b.step(TICK_ONE)
	t.ok(b.events.size() > 0, "비우기 전에는 사건이 있다 (%d개)" % b.events.size())
	b.begin_frame()
	t.eq(b.events.size(), 0, "begin_frame 이 지난 프레임치를 비운다")
	# Clearing at `step`'s head instead is what the design refused: `step` returns early once the
	# island is over, so the last frame's events would survive from the moment a panel opened and the
	# view would replay them forever.
	# The step is long enough to clear BOTH cooldowns (melee 1.0 s, bison 2.0 s) — at a still tick
	# neither would swing again and the empty list would read as "begin_frame broke it".
	b.step(2.5)
	t.ok(b.events.size() > 0, "비운 뒤 다시 돌리면 그 프레임치가 새로 찬다")


## The pair the design's refutation box asks for: the ceiling WITH `begin_frame`, and the pile-up
## WITHOUT it. Both run the same fight, so the two numbers are comparable.
##
## ⚠ The floor is the half that matters. "never more than 19" is also true of a battle that emits
## nothing at all, which is exactly the state this net exists to catch.
func _frame_ceiling_and_the_pile_up_without_it(t) -> void:
	var kept := _melee(200, true)
	t.ok(int(kept["total"]) >= 50,
			"200 프레임 난전에서 사건이 %d개 났다 — 잴 것이 실제로 있다" % int(kept["total"]))
	t.ok(int(kept["peak"]) >= 1, "한 프레임에 최소 하나는 실렸다 (바닥)")
	t.ok(int(kept["peak"]) <= FRAME_CEILING,
			"begin_frame 을 부르면 한 프레임치 상한 %d 을 절대 안 넘는다 (최대 %d개)"
			% [FRAME_CEILING, int(kept["peak"])])

	var piled := _melee(200, false)
	t.eq(int(piled["peak"]), int(piled["total"]),
			"begin_frame 을 빼면 마지막 크기가 총 사건 수와 같다 — 한 번도 안 비워졌다")
	t.ok(int(piled["peak"]) > FRAME_CEILING,
			"그리고 상한 %d 을 한참 넘겨 쌓인다 (%d개) — 상한을 안 둔 것이 이 결함을 시끄럽게 둔다"
			% [FRAME_CEILING, int(piled["peak"])])


# -- the lion's wind-up ----------------------------------------------------------------------------

## **The first blow is announced like every one after it, and that is the whole point.**
## The old rule drained `_enemy_cd` before the target test, so it sat at 0 while nothing was in reach
## and the frame a soldier walked into range was an instant blow with nothing before it. A telegraph
## that is sometimes there is worse than none — combat-juice, item 5, and section 0 records the user
## choosing to build the real one knowing it costs the boss 29% of its damage.
func _lion_declares_before_it_lands(t) -> void:
	var army := _army_of([Rules.WOLF])
	# **A water wall between them, not just distance.** Out of reach alone is not enough: the soldier
	# would walk over and the fixture would measure a blow at whatever moment it arrived. With no path
	# `step_toward` hands back the tile it is on and the soldier stands, so the frame it enters reach
	# is a frame this file chooses.
	var b := _battle_of(_split(), army, [_spawn(ARENA_W, Rules.LION, 13, 5)])
	# Out of the lion's detect 2 to start with, so its cooldown drains to 0 and SITS there.
	_ashore(b, 0, Vector2(6, 5))
	for _f in 20:
		b.begin_frame()
		b.step(0.1)
	t.eq(b.soldier_pos[0], Vector2(6, 5), "물벽 너머의 병사는 20프레임 동안 제자리에 있었다")
	t.ok(b._enemy_cd[0] <= Rules.EPS,
			"표적이 없는 동안 사자의 재사용 대기가 0 에 앉아 있다 (%.4f) — 옛 룰이 즉발이던 이유"
			% b._enemy_cd[0])
	t.eq(b.enemy_windup[0], 0.0, "표적이 없으면 예고도 없다")
	t.eq(b.enemy_windup_at[0], -1, "겨눈 병사도 없다")

	# The soldier walks into reach. Under the old rule this frame WAS the blow.
	_place(b, 0, Vector2(12, 5))
	b.begin_frame()
	b.step(TICK_ONE)
	t.eq(army.hp[0], Rules.hp_of(Rules.WOLF),
			"사거리에 들어온 그 프레임에 피해가 0이다 — 첫 일격도 예고된다")
	# `enemy_windup` is a PackedFloat32Array, so the 64-bit constant does not survive the store
	# exactly — every comparison against it is a tolerance, never `eq`.
	t.ok(_is_full_windup(b, 0), "대신 그 프레임에 일격이 선언됐다 (%.4f초)" % b.enemy_windup[0])
	t.eq(b.enemy_windup_at[0], 0, "선언은 그 병사를 잠갔다 — 그린 링과 맞는 놈이 같아진다")
	var enemy_swings := 0
	for raw in b.events:
		var ev: Dictionary = raw
		if int(ev["kind"]) == Battle.Event.ATTACK and bool(ev["from_enemy"]):
			enemy_swings += 1
	t.eq(enemy_swings, 0, "선언 프레임에는 적의 ATTACK 사건이 하나도 없다 — 예고는 사건이 아니라 상태다")

	# ... and the blow really does land when the wind-up runs out.
	var waited := 0.0
	var landed := -1.0
	for _f in 40:
		b.begin_frame()
		b.step(0.05)
		waited += 0.05
		if army.hp[0] < Rules.hp_of(Rules.WOLF) and landed < 0.0:
			landed = waited
			break
	t.ok(landed > 0.0, "예고가 끝나자 일격이 실제로 떨어졌다")
	t.ok(absf(landed - Rules.LION_WINDUP_SEC) <= 0.06,
			"떨어진 시점이 LION_WINDUP_SEC 근처다 (%.2f초 / 선언 %.2f초)"
			% [landed, Rules.LION_WINDUP_SEC])
	t.eq(army.hp[0], Rules.hp_of(Rules.WOLF) - Rules.damage_of(Rules.LION),
			"떨어진 피해는 사자의 값이다")
	t.eq(b.enemy_windup[0], 0.0, "터진 뒤 예고는 지워졌다")
	t.eq(b.enemy_windup_at[0], -1, "잠근 표적도 풀렸다")

	# Blow to blow is `period + windup`, because the cooldown is refilled at the STRIKE and not at the
	# declaration — refilled at the declaration the wind-up would be free on every blow but the first.
	var gap := 0.0
	var before := army.hp[0]
	for _f in 80:
		b.begin_frame()
		b.step(0.05)
		gap += 0.05
		if army.hp[0] < before:
			break
	var want_gap := Rules.period_of(Rules.LION) + Rules.LION_WINDUP_SEC
	t.ok(absf(gap - want_gap) <= 0.1,
			"일격 간격이 주기 + 예고 = %.2f초다 (%.2f초) — 대기는 선언이 아니라 발동에서 다시 찬다"
			% [want_gap, gap])

	# The floor under all of it: a type with no wind-up hits on the very first frame. Without this the
	# lion's silence above could just as well be "the enemy never attacked at all".
	var bison_army := _army_of([Rules.WOLF])
	var bb := _battle_of(_open(ARENA_W, ARENA_H), bison_army,
			[_spawn(ARENA_W, Rules.WOLF, 13, 5)])
	_ashore(bb, 0, Vector2(12, 5))
	bb.begin_frame()
	bb.step(TICK_ONE)
	t.eq(bison_army.hp[0], Rules.hp_of(Rules.WOLF) - Rules.damage_of(Rules.WOLF),
			"예고가 없는 들소는 첫 프레임에 그냥 때린다")
	t.eq(bb.enemy_windup[0], 0.0, "들소는 예고를 안 건다")
	t.eq(bb._windup_of(Rules.WOLF), 0.0, "_windup_of 는 사자 말고 전부 0.0 이다")
	t.eq(bb._windup_of(Rules.LION), Rules.LION_WINDUP_SEC, "그리고 사자만 LION_WINDUP_SEC 이다")


## An interrupted wind-up is thrown away WHOLE and never resumed. Keeping the remainder would let the
## next blow be announced for a fraction of its time, which is the same defect as not announcing it.
func _windup_is_thrown_away_whole(t) -> void:
	# the target dies. **Two frames, and the second one is the check.** Damage lands before deaths, so
	# on the frame the HP hits 0 the soldier is still `alive` and still a legal aim — the wind-up is
	# dropped on the frame after, when `is_hittable` finally says no.
	var dead := _declared()
	var db: Battle = dead["battle"]
	var darmy: Army = dead["army"]
	darmy.hp[0] = 0.0
	db.begin_frame()
	db.step(TICK_ONE)
	t.eq(darmy.alive[0], 0, "겨눠진 병사가 죽었다")
	db.begin_frame()
	db.step(TICK_ONE)
	t.eq(db.enemy_windup[0], 0.0, "겨눈 병사가 죽으면 예고를 통째로 버린다")
	t.eq(db.enemy_windup_at[0], -1, "잠근 표적도 버린다")

	# the target walks out of reach
	var away := _declared()
	var ab: Battle = away["battle"]
	_place(ab, 0, Vector2(6, 5))
	ab.begin_frame()
	ab.step(TICK_ONE)
	t.eq(ab.enemy_windup[0], 0.0, "표적이 사거리 밖으로 나가도 예고를 버린다")

	# ... and it starts again from FULL, not from what was left
	_place(ab, 0, Vector2(12, 5))
	ab.begin_frame()
	ab.step(TICK_ONE)
	t.ok(_is_full_windup(ab, 0), "다시 들어오면 예고가 처음부터 다시 걸린다 — 잔량이 안 남는다 (%.4f초)"
			% ab.enemy_windup[0])

	# the lion itself dies
	var gone := _declared()
	var gb: Battle = gone["battle"]
	gb.enemy_hp[0] = 0.0
	gb.begin_frame()
	gb.step(TICK_ONE)
	t.eq(gb.enemy_alive[0], 0, "사자가 죽었다")
	t.eq(gb.enemy_windup[0], 0.0, "죽은 사자의 예고는 0으로 지워진다 — 시체 위에 링이 남지 않는다")
	t.eq(gb.enemy_windup_at[0], -1, "겨눈 표적도 지워진다")


# -- the effects must not be able to move anything --------------------------------------------------

## `events` is a list of facts and appending one may not touch a single column the rules read. The
## check compares WHOLE position arrays across a frame that really did produce an attack — a decoration
## written into `soldier_pos` would change who is inside whose reach, and then the effect has rewritten
## the rule it exists to decorate.
func _events_do_not_move_the_sim(t) -> void:
	var army := _army_of([Rules.WOLF, Rules.CROW])
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [
		_spawn(ARENA_W, Rules.WOLF, 13, 5),
		_spawn(ARENA_W, Rules.LION, 13, 7),
	])
	_ashore(b, 0, Vector2(12, 5))
	_ashore(b, 1, Vector2(12, 7))
	var before_s := b.soldier_pos.duplicate()
	var before_e := b.enemy_pos.duplicate()
	b.begin_frame()
	b.step(TICK_ONE)
	t.ok(b.events.size() >= 2, "이 프레임에 사건이 실제로 났다 (%d개) — 빈 프레임을 비교한 게 아니다"
			% b.events.size())
	var moved := 0
	for i in b.soldier_pos.size():
		if b.soldier_pos[i] != before_s[i]:
			moved += 1
	for e in b.enemy_pos.size():
		if b.enemy_pos[e] != before_e[e]:
			moved += 1
	t.eq(moved, 0, "사건이 난 프레임에 아무 몸도 안 옮겨졌다 — 연출용 값이 위치에 안 샌다")
	var carries_pos := 0
	for raw in b.events:
		var ev: Dictionary = raw
		if ev.has("pos") or ev.has("at") or ev.has("tile"):
			carries_pos += 1
	t.eq(carries_pos, 0, "어떤 사건도 좌표를 안 싣는다 — 뷰가 id 로 그 자리를 읽는다")


# -- fixtures ---------------------------------------------------------------------------------------

## `enemy_windup` is a PackedFloat32Array: `LION_WINDUP_SEC` is a 64-bit constant and comes back out
## as 0.60000002384186, so "a full wind-up is standing" is a tolerance and never an equality.
func _is_full_windup(b: Battle, e: int) -> bool:
	return absf(b.enemy_windup[e] - Rules.LION_WINDUP_SEC) <= 1e-4

## A lion with a blow already declared, one melee soldier adjacent. Returns both so the caller can
## interrupt it in whatever way it is measuring.
func _declared() -> Dictionary:
	# **Two soldiers, and the second one is not decoration.** The interruption being measured needs the
	# frame AFTER the target dies, and with a one-soldier army that death is a wipe: `step` returns at
	# its first line from then on and the wind-up is never touched again, so the stale value reads as
	# "it was kept". The spare stands outside the lion's detect 2 and every step here is still, so it
	# never joins the fight.
	var army := _army_of([Rules.WOLF, Rules.WOLF])
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [_spawn(ARENA_W, Rules.LION, 13, 5)])
	_ashore(b, 0, Vector2(12, 5))
	_ashore(b, 1, Vector2(6, 8))
	b.begin_frame()
	b.step(TICK_ONE)
	return {"battle": b, "army": army}


## 13 soldiers against 6 enemies for `frames` frames — the biggest island's body count, so the
## per-frame ceiling being measured is the real one. `clear_each_frame` false is the forgotten
## `begin_frame()`.
func _melee(frames: int, clear_each_frame: bool) -> Dictionary:
	var types := []
	for _i in 8:
		types.append(Rules.WOLF)
	for _i in 5:
		types.append(Rules.CROW)
	var army := _army_of(types)
	var spawns := []
	for k in 6:
		spawns.append(_spawn(ARENA_W, Rules.WOLF, 15 + k % 3, 4 + k / 3))
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, spawns)
	for i in 13:
		_ashore(b, i, Vector2(4 + i % 5, 3 + i / 5))

	var peak := 0
	var total := 0
	for _f in frames:
		if clear_each_frame:
			var was := b.events.size()
			total += was
			b.begin_frame()
		b.step(0.05)
		peak = maxi(peak, b.events.size())
	if clear_each_frame:
		total += b.events.size()
	else:
		total = b.events.size()
	return {"peak": peak, "total": total}


## Water border, land inside, no docks.
func _open(w: int, h: int) -> Array:
	var rows := []
	for y in h:
		if y == 0 or y == h - 1:
			rows.append("~".repeat(w))
		else:
			rows.append("~" + ".".repeat(w - 2) + "~")
	return rows


## The open arena cut in two by a water column at x = 10. Nothing can path across it, so a unit on
## the wrong side stands still instead of walking into the measurement.
func _split() -> Array:
	var rows := _open(ARENA_W, ARENA_H)
	for y in range(1, ARENA_H - 1):
		var row: String = rows[y]
		rows[y] = row.substr(0, 10) + "~" + row.substr(11)
	return rows


## A bay: rows 3-7 are water for the first six columns, land from column 6 on, one harbour at (2,5).
##
## ⚠⚠ **`_PORT_LANDING` (6,5) WAS DELETED 2026-08-27 WITH THE HARBOUR.** It named the coast tile the
## harbour could see straight across open water, and it was the argument `Battle.send` took. **A summon
## takes the other kind of tile**: WATER inside the band, never a beach. ⇒ Neither end of a crossing is
## a fixture constant any more — the origin is found on the grid by `_summonable_water_on`, and the
## beach is whatever `summon_landing_of` picks. **The `H` in the board below is kept** so this bay stays
## the same shape it was measured on; nothing derives anything from it now.
func _port() -> Array:
	var rows := _open(ARENA_W, ARENA_H)
	for y in range(3, 8):
		rows[y] = "~~~~~~" + ".".repeat(ARENA_W - 7) + "~"
	rows[5] = "~~H~~~" + ".".repeat(ARENA_W - 7) + "~"
	return rows


## The first tile inside the summon band. ⚠ **The name says WATER on purpose** — `send` took a BEACH and
## `summon` takes water, and handing one verb the other's tile is a silent `-1`. That confusion cost a
## red round once; the name is what stops it costing a second.
func _summonable_water_on(b: Battle) -> int:
	var g := b.grid
	for tile in g.w * g.h:
		if g.can_summon_at(tile):
			return tile
	return -1


func _grid_of(rows: Array) -> Grid:
	var g := Grid.new()
	g.load_rows(rows)
	return g


## `Army.add(type_id)` is gone — a body is `recruit`ed from a SLOT now. Every `type_id` this file passes
## is a PLAYER row, so it is registered into the army's own slots here rather than at every
## call site.
func _army_of(types: Array) -> Army:
	var a := Army.new()
	# ⚠ **The slots are the ARMY's now, so the resolution asks the army rather than a constant table.**
	# `register_species` is idempotent-by-refusal, so asking for the same species twice costs one slot.
	for raw in types:
		var ty := int(raw)
		var slot := a.slot_of_type(ty)
		if slot < 0:
			slot = a.register_species(ty)
		a.recruit(slot)
	return a


func _spawn(w: int, type_id: int, x: int, y: int) -> Dictionary:
	return {"type_id": type_id, "tile": y * w + x}


## An island already under way. ⚠ **The commit flag is set directly, and that matters more here than
## anywhere else**: `step` refuses everything until the island is committed (`plan-then-watch`, 4.3),
## and **an uncommitted battle produces no `events` at all** — which is precisely what this whole file
## reads. A fixture that forgot to commit would run every one of its checks against an empty list and
## the zero-check rule would not catch it, because the file still runs plenty of checks. The commit
## gate itself is `net_plan`'s to measure.
## **A fixture that has to author a plan uses `_planning_battle_of` and calls the real `commit()`.**
func _battle_of(rows: Array, army: Army, spawns: Array) -> Battle:
	var b := _planning_battle_of(rows, army, spawns)
	b._committed = true
	return b


## The same island, left in the planning state, so a check can drive `send` and `commit` for real.
func _planning_battle_of(rows: Array, army: Army, spawns: Array) -> Battle:
	var b := Battle.new()
	# load_rows first, always: setup writes a reservation per enemy and load_rows clears the table.
	b.setup(_grid_of(rows), army, spawns)
	return b


## Puts a soldier on the island the way a landing would — state, position, goal AND the tile
## reservation, because setting only the state teleports the unit back to its stale goal on the first
## frame it moves.
func _ashore(b: Battle, i: int, p: Vector2) -> void:
	b.soldier_state[i] = Battle.SoldierState.ASHORE
	_place(b, i, p)
	var claimed := b.grid.reserved
	claimed[int(round(p.y)) * b.grid.w + int(round(p.x))] = i
	b.grid.reserved = claimed


## Moves an already-landed soldier. **The goal moves with it.** Writing only `soldier_pos` leaves the
## stale goal behind, and the very next movement phase glides the soldier back toward it — which
## silently undoes whatever the fixture was setting up.
func _place(b: Battle, i: int, p: Vector2) -> void:
	b.soldier_pos[i] = p
	b._soldier_goal[i] = p
