extends RefCounted
## The two places overlap is manufactured in BULK, and the one place it is manufactured on purpose.
##
## Separation itself lives in `net_grid` (body↔body) and `net_hunt`'s S-block (body↔creature). What is left
## over is the state those passes are handed:
##
## - **the arena summon** teleports up to forty clones onto whatever is under them, in one frame, AFTER
##   `Swarm.step()` has already separated — so the pile it makes is the one thing no pass sees the frame it
##   is born. How long it survives has to be a number, and the number has to be asserted.
## - **the wall** — `World._enters_a_body()`. Its predecessor was a flag over the whole swarm plus a blanket
##   exemption, and `_separate_from_critters()` rests every body just INSIDE the touching sum by design, so
##   the exemption went from rare to permanent. A creature nothing could stop is not herded.
## - **knockback** drives a body into whatever is behind it, on a frame where the separation pass has not
##   run yet — `_contact()` is upstream of it inside the same `World.step()`.
##
## ⚠ **Two of these read like they are about the same thing and are not.** `_h3b` in `net_hunt` says an
## overlapped creature can LEAVE; `_o4` here says the same creature still cannot ENTER a body it is outside
## of. The blanket exemption satisfied the first and failed the second, which is why both have to exist.
##
## ⇒ **And two more were added when a mutation pass found the round could not see them.** `_o5` walks the
## SPECIES table instead of naming species — every separation check in the round drove 까마귀 · 말 · 사자,
## so 다람쥐 · 코끼리 · 치타 · **보스** could each be exempted from the pass, or shoved the full overlap by
## forty bodies, with 2705 checks green. `_o6` runs a fight to the corpse, because `_s4` proves a separated
## clone keeps LANDING against an invincible target and that is not the same claim as the target still dying.

const DT := 1.0 / 60.0
const CROW := int(Parts.Species.CROW)
const HORSE := int(Parts.Species.HORSE)

## Every literal these fixtures stand on, written out rather than read back off the code under test.
##
## A force-10 crow is `SPECIES_RADIUS[CROW] 12 × (1 + 0.5 × (10−8)/(12−8))` = **15.0**; a force-12 crow sits
## at its species maximum, so the ramp is 1 and it is **18.0**. A force-30 horse sits at its minimum and is
## **22.0** exactly.
const CROW12_R := 18.0
const HORSE30_R := 22.0
## The touching sums — `critter_radius + body radius`, the distance `_enters_a_body()` calls inside.
const HORSE30_CLONE_SUM := 30.0    ## 22 + 8
const CROW10_HOST_SUM := 29.0      ## 15 + 14
const CROW10_CLONE_SUM := 23.0     ## 15 + 8
## And where a body comes to rest against one: the same sum less `SEPARATION_CONTACT_MARGIN` 1.0.
const CROW10_HOST_REST := 28.0
const CROW10_CLONE_REST := 22.0
## `critter_reach + BODY_RADIUS`, the band a creature reaches the host in. A crow carries no reach bonus.
const CROW12_HOST_BAND := 32.0     ## 18 + 14
## A force-12 crow's knockback: `force × KNOCKBACK_PER_FORCE` = 12 × 0.8.
const CROW12_KNOCKBACK := 9.6

## **How long the summon's pile is allowed to last, in frames, and it is the point of `_o1`.** Measured on
## this fixture rather than derived: separation is one best-effort iteration per frame over at most
## `NEIGHBOUR_CAP` neighbours, so twenty coincident bodies cannot all see each other on the first pass and a
## closed form would be a guess dressed up as arithmetic.
##
## **Five, and the number is tight in both directions**: at four the closest pair of a summoned forty is
## 4.30px and at three it is 3.03, so this reddens the moment resolution takes one frame longer than it
## takes today. ⚠ It is also deliberately far shorter than the walk home — the arrivals are still
## `ARENA_SUMMON_RING` away at frame five — because the pile has to be gone from having been separated, not
## from having dispersed on the way in.
const SUMMON_SETTLE := 5
## And then it has to STAY resolved — a pass that scatters the pile and lets it re-pile is not a resolution.
const SUMMON_HOLD := 600

## The two radii and the margin, written out rather than read off `Rules`, for the same reason every other
## literal in this file is: a check whose bounds come from the thing it checks proves nothing.
const CLONE_R := 8.0
const HOST_R := 14.0
const MARGIN := 1.0

## **One row per species, in enum order, and both arrays are walked against `Rules`' own length** — see
## `_o5`. Written out, not read back: taking the radius from `Rules.SPECIES_RADIUS` while ALSO handing
## `_write_critter` that species' minimum force moves both sides of the comparison together, and the check
## would pass at every radius in the table.
##
## Each fixture uses `Rules.SPECIES_FORCE_MIN[s]`, so the force ramp in `World._radius_of()` is exactly 0 and
## the drawn radius is the species' own number — 까마귀 12 · 말 22 · 보스 48 · 다람쥐 7 · 코끼리 40 ·
## 치타 15 · 사자 26 · 들쥐 5 · 토끼 8 · 들개 10 · 멧돼지 18.
const SPECIES_R := [12.0, 22.0, 48.0, 7.0, 40.0, 15.0, 26.0, 5.0, 8.0, 10.0, 18.0]
## And how far each one walks in a second: `HOST_SPEED 200 × SPECIES_SPEED_MUL`, by hand. A frame's step is
## this over sixty, and it is the whole of "it moved its own walk and was not shoved".
const SPECIES_SPEED := [110.0, 230.0, 150.0, 170.0, 70.0, 440.0, 190.0, 90.0, 210.0, 180.0, 160.0]
## How many bodies `_o5` buries each creature under — the host plus this many clones.
const BURIED_CLONES := 12
## And how long its real-frame half runs.
const WALK_FRAMES := 60

## `_o6` half B's clone. **Six, and the size is a measurement rather than taste**: a force-10 crow has
## `10 × Rules.HP_PER_FORCE` = 30 hp, so six is five hits, and five hits at `Rules.CLONE_ATTACK_PERIOD`
## (1.2s = 72 frames) is four cooldowns after the first — an absolute floor of frame 289.
##
## ⚠ **The kill has to land inside the window where the fixture is still a fight**, and that window was
## measured: a crow re-arms `CROW_COUNTER_TIME` on every hit and walks at the body that hit it, so it
## presses a STRIKE-anchored clone across the ground and the pair comes apart around frame 460. A force-4
## clone needs eight hits and its eighth would fall past that — it never lands, and the check would have
## been measuring the crow's counter-chase while claiming to measure separation.
const KILL_CLONE_FORCE := 6
## Where that fifth hit actually lands — **293, measured, and the floor above says 289.** The four frames
## are not slack to be trimmed: `atk_cd` is decremented by `1.0/60.0` in float and crosses zero a frame late
## each period, so a closed form is off by one per hit while reading as exact. Both ends are pinned — a
## constant with a floor on one end and none on the other is half-measured.
const KILL_FRAME_MIN := 291
const KILL_FRAME_MAX := 295
## How long the search runs before giving up — well past the window, so a kill that never comes reads as
## `died_at == -1` rather than as the loop running out.
const KILL_SEARCH := 440


func run(t) -> void:
	_o1_the_summon_resolves_within_a_bounded_number_of_frames(t)
	_o2_no_creature_is_frozen_by_an_overlap(t)
	_o3_a_knocked_back_body_ends_outside_what_it_was_knocked_into(t)
	_o4_a_settled_clone_is_still_a_wall(t)
	_o5_every_species_pushes_bodies_out_and_not_one_of_them_moves(t)
	_o6_a_swarm_still_kills_what_it_was_separated_from(t)


# -- O1: the summon's pile, and how many frames it lasts ---------------------------------------------------
## ⚠ **The pile is real and it is exactly coincident.** `_step_arena()` uses `limit_length`, which only ever
## SHORTENS an offset — every clone standing at one distant point shares one offset and therefore one
## landing coordinate, and a clone already inside the ring is not moved at all. The fixture asserts the pile
## before it asserts the recovery, or the loop below could pass on a swarm that was never stacked.
##
## ⚠ **The floor is `CLONE_BODY_RADIUS`, not `SEPARATION_MIN`, and the difference is a measurement rather
## than a softening.** A rallied swarm in this build never reaches `SEPARATION_MIN` at all — separation is
## one best-effort iteration against steering that pulls inward, and `rally_radius()` is an annulus barely
## wider than the bodies in it. Driven through the real frame, eight rallied clones hold 12.50 and forty
## hold 11.87; asserting 16 here would be asserting something the build has never done, summon or no summon.
## What the floor says instead is the rule: **no body's centre stands inside another body**, which is the
## same claim `net_grid` pins at `BODY_RADIUS` for the host and the same shape it is written in.
##
## Two sizes, eight and the cap of forty, because a rendezvous that holds at one may not at the other and a
## single size would not say which.
func _o1_the_summon_resolves_within_a_bounded_number_of_frames(t) -> void:
	_summon_settles(t, 8, "여덟")
	_summon_settles(t, 40, "마흔")


## Both floors are `Rules` constants read as RULES — `CLONE_BODY_RADIUS` is "no clone's centre stands inside
## another clone", `BODY_RADIUS` is the same sentence about the host — and neither is a spacing read back off
## the swarm that produced it.
func _summon_settles(t, clones: int, who: String) -> void:
	var pair_floor := Rules.CLONE_BODY_RADIUS
	var host_floor := Rules.BODY_RADIUS
	var w := World.new()
	w.setup(1200 + clones)
	_silence_food(w)
	_clear_terrain(w)
	# Every creature but the boss removed, and then the boss too once the arena has closed: this check is
	# about the teleport, and a boss standing in the middle of it eats the swarm it is supposed to summon.
	for k in range(w.critter_count - 1, -1, -1):
		if k != w.boss_index:
			w._remove_critter(k)
	var host: Vector2 = w.swarm.pos[0]
	w.critter_pos[w.boss_index] = host + Vector2(500.0, 0.0)
	w.elapsed = Rules.BOSS_HUNT_AT
	# ⚠ **Two piles, because the summon makes two and a fixture with one leaves half the check vacuous.**
	# The far half shares one point well outside the ring, so `limit_length` hands every one of them the same
	# shortened offset and they land on one coordinate. The near half is written exactly ON the host, where
	# `limit_length` shortens nothing at all — that is the clone↔host pile, and without it the host floor
	# below passes with the whole of separation deleted, because `rally_radius()` stops an arriving clone
	# well outside `BODY_RADIUS` on its own.
	var away := host + Vector2(1200.0, 0.0)
	var far_first := -1
	for i in clones:
		var c := w.swarm.add_clone(0, 5)
		if c < 0:
			break
		if i < clones / 2:
			w.swarm.pos[c] = away
			if far_first < 0:
				far_first = c
		else:
			w.swarm.pos[c] = host
	t.eq(w.swarm.count, clones + 1, "설정: %s 중 절반은 1200px 밖 한 점에, 절반은 호스트 위에 서 있다" % who)

	w._step_arena()
	t.ok(w.terrain.arena_closed, "설정: 아레나가 닫혔다 — 소환이 실제로 일어났다")
	var landed: Vector2 = w.swarm.pos[far_first]
	var spread := 0.0
	var on_host := 0.0
	for i in range(1, w.swarm.count):
		if i < far_first + clones / 2:
			spread = maxf(spread, w.swarm.pos[i].distance_to(landed))
		else:
			on_host = maxf(on_host, w.swarm.pos[i].distance_to(host))
	t.ok(spread < 0.001,
			"설정: 멀리 있던 절반은 정확히 한 좌표에 쌓인다 — 겹침이 진짜로 만들어졌다 (%.4f)" % spread)
	t.ok(absf(landed.distance_to(host) - Rules.ARENA_SUMMON_RING) < 0.001,
			"설정: 그 좌표는 호스트에게서 소환 반지름만큼 떨어져 있다 (%.2f)" % landed.distance_to(host))
	t.ok(on_host < 0.001,
			"설정: 호스트 위에 있던 절반은 소환이 한 픽셀도 안 옮긴다 — limit_length는 줄이기만 한다 (%.4f)"
					% on_host)

	# The boss goes, and so does the spawn clock: a crow arriving in the middle of the recovery would make
	# the frame count measure the ecosystem instead of the separation.
	w._remove_critter(w.boss_index)
	w._next_critter = 100000.0
	t.eq(w.critter_count, 0, "설정: 그리고 필드에는 아무도 남지 않았다")

	for _s in SUMMON_SETTLE:
		w.step(DT)
	var pair := _closest_pair(w.swarm)
	var host_gap := _closest_to_host(w.swarm)
	t.ok(pair >= pair_floor,
			"소환된 %s은 %d프레임 안에 서로 제 반지름 8px 밖으로 풀린다 (%.2f)"
					% [who, SUMMON_SETTLE, pair])
	t.ok(host_gap >= host_floor,
			"그리고 어느 것도 호스트 몸 14px 안에 서 있지 않다 (%.2f)" % host_gap)

	# ⚠ **A pile that scatters and re-piles is not resolved**, so the floors are read again ten seconds on.
	# The HOST floor is taken as a minimum over every one of those frames; the clone pair is read as a sample
	# at the end, and that difference is a measurement, not laziness. Forty rallied bodies dip to **4.92px**
	# between two clones at some frame of the window — measured here, through the real frame — and that is
	# the rendezvous's own packing, present with or without a summon. It belongs to `net_grid`'s subject and
	# this check would be quietly claiming to have fixed it.
	var worst_host := host_gap
	for _s in SUMMON_HOLD:
		w.step(DT)
		worst_host = minf(worst_host, _closest_to_host(w.swarm))
	t.ok(_closest_pair(w.swarm) >= pair_floor,
			"이후 %d프레임을 더 돌려도 다시 쌓이지 않는다 (%.2f)"
					% [SUMMON_HOLD, _closest_pair(w.swarm)])
	t.ok(worst_host >= host_floor,
			"그 %d프레임 어느 지점에서도 호스트 안에 선 것이 없다 (%.2f)"
					% [SUMMON_HOLD, worst_host])


# -- O2: a buried creature is not frozen -------------------------------------------------------------------
## **The claim the old blanket exemption was written to protect, re-earned by a rule that does not need it.**
## `_enters_a_body()` refuses one thing only — a step into a body the creature is currently OUTSIDE of — so
## every body it is already inside constrains nothing at all and its escape direction is always open.
##
## The first half drives `_step_critters()` alone, with no separation running anywhere, so the escape is the
## walk rule's doing and nothing else. The second half pays that back on the real frame and pins the travel
## to the horse's own literal speed: a creature that got out because thirteen bodies shoved it would show up
## here as a step bigger than one walk.
##
## ⚠ **The second half puts the host on ONE SIDE, and that is a limitation being written down rather than
## hidden.** A creature RINGED — separation having pushed a rallied swarm out to the rest distance all the
## way around it — barely travels: 10.1px per second, measured. That is not this rule's doing, it is the
## flee steering's: `_step_critters` aims away from the single NEAREST body, and in a ring the nearest body
## flips side every frame. Taking the wall out entirely only lifts it to 63.1px, also measured, so a
## check written on a ring would be measuring the steering heuristic and calling it separation.
func _o2_no_creature_is_frozen_by_an_overlap(t) -> void:
	var at := Vector2(1500.0, 1500.0)
	var w := World.new()
	w.setup(1210)
	_silence_food(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(HORSE, at, 30)
	w.critter_hp[0] = 1000000
	# Muted: this is about walking, and a horse that kills the swarm it is buried in changes the fixture
	# every frame.
	w.critter_atk_cd[0] = 1000000.0
	t.ok(absf(w.critter_radius(0) - HORSE30_R) < 0.001,
			"설정: 힘 30짜리 말의 반지름은 22다 (%.3f)" % w.critter_radius(0))
	w.swarm.pos[0] = at
	for _i in 12:
		var c := w.swarm.add_clone(0, 5)
		w.swarm.pos[c] = at
		w.swarm.atk_cd[c] = 1000000.0
		w.swarm.hp[c] = 1000000
	t.eq(w.swarm.count, 13, "설정: 호스트와 분신 열둘이 전부 말 한가운데 서 있다")
	t.ok(at.distance_to(w.swarm.pos[0]) < HORSE30_CLONE_SUM,
			"설정: 말은 열세 몸 전부의 안쪽에 있다 — 예전 면제가 필드 전체를 열어 주던 바로 그 상태다")

	for _s in 60:
		w._step_critters(DT)
	var out: float = w.critter_pos[0].distance_to(at)
	# 230px/s × 1s = 230px, and 100 is a third of it: the claim is "it is not stuck", not "it ran flat out".
	t.ok(out > 100.0,
			"파묻힌 말은 1초면 걸어 나온다 — 이미 들어가 있는 몸은 아무것도 막지 않는다 (%.1f)" % out)

	# -- the real frame: the swarm has just walked OVER the horse and is rallying on past it --
	var w2 := World.new()
	w2.setup(1211)
	_silence_food(w2)
	_clear_terrain(w2)
	w2.critter_count = 0
	w2.boss_index = -1
	w2._write_critter(HORSE, at, 30)
	w2.critter_hp[0] = 1000000
	w2.critter_atk_cd[0] = 1000000.0
	# The rendezvous is 600px to the right, so the twelve arrivals steer off the horse rather than closing a
	# ring around it, and `critter_dir` is a UNIT vector left — the horse's first frame has every body at
	# distance zero, where the flee branch has no direction to compute and keeps the one it was born with.
	w2.swarm.pos[0] = at + Vector2(600.0, 0.0)
	w2.critter_dir[0] = Vector2.LEFT
	for _i in 12:
		var c2 := w2.swarm.add_clone(0, 5)
		w2.swarm.pos[c2] = at
		w2.swarm.atk_cd[c2] = 1000000.0
		w2.swarm.hp[c2] = 1000000
	t.ok(w2.swarm.pos[1].distance_to(w2.critter_pos[0]) < HORSE30_CLONE_SUM,
			"설정: 열둘은 말 한가운데에서 출발한다 (%.2f)"
					% w2.swarm.pos[1].distance_to(w2.critter_pos[0]))
	var biggest := 0.0
	var previous: Vector2 = w2.critter_pos[0]
	for _s in 60:
		w2.step(DT)
		biggest = maxf(biggest, w2.critter_pos[0].distance_to(previous))
		previous = w2.critter_pos[0]
	t.ok(w2.critter_pos[0].distance_to(at) > 100.0,
			"프레임을 통째로 돌려도 마찬가지다 (%.1f)" % w2.critter_pos[0].distance_to(at))
	# 3.833px is `HOST_SPEED 200 × SPECIES_SPEED_MUL[HORSE] 1.15 ÷ 60`, written out by hand.
	t.ok(biggest <= 3.834,
			"그리고 어느 프레임에도 제 걸음 3.83px를 넘어 움직인 적이 없다 — 밀려 나온 것이 아니다 (%.3f)"
					% biggest)


# -- O3: knockback drives a body into something, and the same frame takes it back out ----------------------
## ⚠ **`_contact()` is upstream of `_separate_from_critters()` inside one `World.step()`**, so this is a
## same-frame repair and not a next-frame one. That ordering is the whole reason the pass is the last
## statement of the frame; a check that stepped twice would not be able to tell the two apart.
##
## The attacker and the thing behind it are two different creatures on purpose. One crow knocks the body
## back; the second is muted and does nothing but stand in the landing spot, so the only thing that can move
## the body out of it is separation.
func _o3_a_knocked_back_body_ends_outside_what_it_was_knocked_into(t) -> void:
	var start := Vector2(1500.0, 1500.0)
	# 31px to the left: inside the force-12 crow's host band of 32, and the knockback therefore points
	# straight right.
	var hitter := Vector2(1469.0, 1500.0)
	# Dead in the landing spot, 20px above it — so the push back out is mostly sideways and cannot be
	# mistaken for the knockback being undone.
	var behind := Vector2(1509.6, 1480.0)
	var w := World.new()
	w.setup(1220)
	_silence_food(w)
	_clear_terrain(w)
	w.swarm.pos[0] = start
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(CROW, hitter, 12)
	w._write_critter(CROW, behind, 10)
	w.critter_hp[0] = 1000000
	w.critter_hp[1] = 1000000
	# The second crow never attacks: separation has to be the only thing that moves the host off it.
	w.critter_atk_cd[1] = 1000000.0
	t.ok(absf(w.critter_radius(0) - CROW12_R) < 0.001,
			"설정: 때리는 까마귀는 힘 12, 반지름 18이다 (%.3f)" % w.critter_radius(0))
	t.ok(absf(start.distance_to(hitter) - 31.0) < 0.001 and start.distance_to(hitter) < CROW12_HOST_BAND,
			"설정: 그 까마귀는 31px 앞, 호스트 판정 띠 32px 안에 서 있다 (%.2f)" % start.distance_to(hitter))
	var landing := start + Vector2(CROW12_KNOCKBACK, 0.0)
	t.ok(landing.distance_to(behind) < CROW10_HOST_SUM,
			"설정: 9.6px 밀려난 자리는 두 번째 까마귀 안이다 (%.2f < 29)" % landing.distance_to(behind))

	var hp_before := w.host_hp
	w.step(DT)
	t.eq(hp_before - w.host_hp, 12, "설정: 그 프레임에 실제로 맞았다 — 때린 놈의 힘 12만큼")
	t.ok(w.swarm.pos[0].x > start.x + 9.0,
			"밀림은 그대로 남는다 — 호스트는 오른쪽으로 9px 넘게 갔다 (%.2f)" % (w.swarm.pos[0].x - start.x))
	var gap: float = w.swarm.pos[0].distance_to(behind)
	t.ok(gap >= CROW10_HOST_REST - 0.001,
			"그리고 같은 프레임 안에 밀려 들어간 놈 밖으로 나와 있다 — 28px (%.3f)" % gap)
	t.eq(w.critter_pos[1], behind, "밀려 들어온 몸에 치인 까마귀는 한 픽셀도 안 밀린다")
	t.ok(w.swarm.pos[0].distance_to(hitter) > start.distance_to(hitter),
			"밀어내기가 밀림과 싸우지 않는다 — 때린 놈에게서 더 멀어졌다 (%.2f → %.2f)"
					% [start.distance_to(hitter), w.swarm.pos[0].distance_to(hitter)])

	# -- and the clone half, where the knockback comes out of `_damage_clone()` instead --
	var w2 := World.new()
	w2.setup(1221)
	_silence_food(w2)
	_clear_terrain(w2)
	w2.swarm.pos[0] = Vector2(3000.0, 300.0)
	var c := w2.swarm.add_clone(0, 10)
	w2.swarm.pos[c] = start
	w2.swarm.command_strike(start)
	# The clone neither swings nor dies: this check is about where it ENDS UP.
	w2.swarm.atk_cd[c] = 1000000.0
	w2.swarm.hp[c] = 1000000
	w2.critter_count = 0
	w2.boss_index = -1
	# 25px away: inside the force-12 crow's clone band of 26, which is 18 + 8.
	var hitter2 := Vector2(1475.0, 1500.0)
	var behind2 := Vector2(1509.6, 1486.0)
	w2._write_critter(CROW, hitter2, 12)
	w2._write_critter(CROW, behind2, 10)
	w2.critter_hp[0] = 1000000
	w2.critter_hp[1] = 1000000
	w2.critter_atk_cd[1] = 1000000.0
	t.ok((start + Vector2(CROW12_KNOCKBACK, 0.0)).distance_to(behind2) < CROW10_CLONE_SUM,
			"설정: 밀려난 분신의 착지점도 두 번째 까마귀 안이다 (%.2f < 23)"
					% (start + Vector2(CROW12_KNOCKBACK, 0.0)).distance_to(behind2))
	w2.step(DT)
	t.ok(w2.swarm.pos[c].x > start.x + 9.0,
			"분신도 밀린 만큼 그대로 갔다 (%.2f)" % (w2.swarm.pos[c].x - start.x))
	var gap2: float = w2.swarm.pos[c].distance_to(behind2)
	t.ok(gap2 >= CROW10_CLONE_REST - 0.001,
			"그리고 같은 프레임에 22px 밖으로 나와 있다 (%.3f)" % gap2)
	t.eq(w2.critter_pos[1], behind2, "두 번째 까마귀는 여기서도 제자리다")


# -- O4: a body resting against a creature does not switch the wall off --------------------------------
## **The defect the old shape had and the new one does not.** `_blocked(next) and not _blocked(p)` asked its
## question over the WHOLE swarm: one body inside the creature's touching sum exempted it from the wall
## entirely, for every other body on the field. `_separate_from_critters()` parks a body exactly
## `SEPARATION_CONTACT_MARGIN` inside that sum and leaves it there — so a horse with one clone against its
## flank could walk through the other thirty-nine, and herding, which the design calls this stage's hand,
## quietly had no mechanism left.
##
## ⚠ **Half B is what makes half A a wall rather than a frozen fixture.** The same horse with the wall taken
## away walks, so "it never entered" is a refusal and not a creature that had nothing to do.
func _o4_a_settled_clone_is_still_a_wall(t) -> void:
	var at := Vector2(1570.0, 1500.0)
	var wall := Vector2(1600.0, 1500.0)
	# 29px behind: the rest distance a body settles at against a force-30 horse (30 − 1), which is inside
	# the touching sum and is exactly what used to arm the blanket exemption.
	var behind := Vector2(1541.0, 1500.0)

	var w := _wall_fixture(1230, at, behind, wall)
	t.ok(w.critter_pos[0].distance_to(behind) < HORSE30_CLONE_SUM,
			"설정: 뒤쪽 분신은 말의 접촉 합 30px 안에 서 있다 (%.2f)" % w.critter_pos[0].distance_to(behind))
	t.ok(absf(w.critter_pos[0].distance_to(wall) - HORSE30_CLONE_SUM) < 0.001,
			"설정: 앞쪽 분신과는 정확히 30px — 아직 안 겹쳤다 (%.2f)" % w.critter_pos[0].distance_to(wall))
	var deepest := INF
	var furthest := 0.0
	for _s in 120:
		w._step_critters(DT)
		deepest = minf(deepest, w.critter_pos[0].distance_to(wall))
		furthest = maxf(furthest, w.critter_pos[0].x)
	t.ok(deepest >= HORSE30_CLONE_SUM - 0.001,
			"뒤에 몸이 붙어 있어도 말은 앞쪽 분신 안으로 못 들어간다 (가장 깊었던 순간 %.3f)" % deepest)
	t.ok(furthest < wall.x - HORSE30_CLONE_SUM + 0.001,
			"통과는 더더욱 없다 — 벽을 넘어선 프레임이 없다 (%.2f)" % furthest)

	var open := _wall_fixture(1231, at, behind, wall)
	# The wall alone is removed. Everything else — the clone against its flank, the seed, the coordinates —
	# is the same fixture, so the only difference between the two halves is the thing being measured.
	open.swarm.remove_at(2)
	t.eq(open.swarm.count, 2, "설정: 앞쪽 분신만 치웠다")
	for _s in 120:
		open._step_critters(DT)
	t.ok(open.critter_pos[0].x > wall.x + 100.0,
			"벽을 치우면 같은 말이 그대로 걸어 나간다 — 얼어붙은 것이 아니었다 (%.1f)" % open.critter_pos[0].x)


## The horse, the clone resting against its back, and the clone standing in front of it. Built twice so the
## second half can delete exactly one of them.
func _wall_fixture(seed_value: int, at: Vector2, behind: Vector2, wall: Vector2) -> World:
	var w := World.new()
	w.setup(seed_value)
	_silence_food(w)
	_clear_terrain(w)
	# Far away and out of `CRITTER_SENSE`: the body the horse runs from has to be one of the two clones.
	w.swarm.pos[0] = Vector2(3400.0, 200.0)
	var c1 := w.swarm.add_clone(0, 5)
	w.swarm.pos[c1] = behind
	var c2 := w.swarm.add_clone(0, 5)
	w.swarm.pos[c2] = wall
	w.swarm.atk_cd[c1] = 1000000.0
	w.swarm.atk_cd[c2] = 1000000.0
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(HORSE, at, 30)
	w.critter_hp[0] = 1000000
	w.critter_atk_cd[0] = 1000000.0
	w.critter_dir[0] = Vector2.ZERO
	return w


# -- O5: the rule holds for EVERY species, not for the three the fixtures happen to name ------------------
## **This walks `Rules`' own species table and reddens on a row it has no literal for.** The direction is the
## one a list of names cannot see: `net_hunt`'s S-block drives 까마귀 · 말 · 사자 and `_o1`—`_o4` drive
## 까마귀 · 말, so 다람쥐 · 코끼리 · 치타 · **보스** were outside every separation check in the round.
## Measured, on a green round of 2705: exempting all four from `World._separate_from_critters()` changed
## nothing, and so did letting forty bodies shove the boss the full overlap. **A species added tomorrow is
## red here until it has a row**, which is the same shape `net_draw_leaf` closes its function table with.
##
## ⚠ **The boss is the row that matters most and it is the one nothing reached.** It is the biggest body on
## the field (radius 48, four times a clone's sum), the run ends on it, and it is the one creature the design
## says cannot be escaped — see 「사냥과 보스」. `net_hunt`'s `_h4` does drive forty clones at it, but through
## `_step_critters()` alone, so the separation pass is not in that call at all and its ±10px tolerance is
## written to FORGIVE drift. A check that forgives displacement cannot be the check that forbids it.
##
## Both halves are needed for the same reason `_s2` needs both: the pass alone gives an exact "it did not
## move", and the real frame then pays that back with the creature's own walk pinned to a literal.
func _o5_every_species_pushes_bodies_out_and_not_one_of_them_moves(t) -> void:
	# The loop's own bound, asserted — a table walk that ran zero rows would pass in silence, and the two
	# literal arrays must stay the same length as the thing they stand in for.
	t.eq(SPECIES_R.size(), Rules.SPECIES_RADIUS.size(),
			"설정: 종마다 한 줄씩 — 표에 새 종이 생기면 이 그물이 빨강이다")
	t.eq(SPECIES_SPEED.size(), Rules.SPECIES_RADIUS.size(),
			"설정: 걸음 표도 같은 길이다")
	for s in SPECIES_R.size():
		_species_is_pushed_out_of_but_never_pushed(t, s)


func _species_is_pushed_out_of_but_never_pushed(t, s: int) -> void:
	var at := Vector2(1500.0, 1500.0)
	var r: float = SPECIES_R[s]
	var clone_rest := r + CLONE_R - MARGIN
	var host_rest := r + HOST_R - MARGIN
	var w := _buried_fixture(1240 + s, s, at)
	t.ok(absf(w.critter_radius(0) - r) < 0.001,
			"설정: %d번 종은 제 최소 힘에서 반지름이 %.0f다 (%.3f)" % [s, r, w.critter_radius(0)])
	t.eq(w.swarm.count, BURIED_CLONES + 1,
			"설정: 호스트와 분신 열둘이 %d번 종 한가운데에 정확히 겹쳐 서 있다" % s)

	# The pass alone, so nothing else in the frame can be what moved anything.
	w._separate_from_critters()
	t.eq(w.critter_pos[0], at,
			"%d번 종은 열세 몸이 안에서 밀어내도 한 픽셀도 안 움직인다 — 몰이는 미는 것이 아니다" % s)
	var nearest := INF
	var furthest := 0.0
	for i in range(1, w.swarm.count):
		var d: float = w.swarm.pos[i].distance_to(at)
		nearest = minf(nearest, d)
		furthest = maxf(furthest, d)
	t.ok(nearest >= clone_rest - 0.001,
			"분신 열둘이 전부 %.0fpx 밖으로 나온다 (가장 안쪽 %.3f)" % [clone_rest, nearest])
	# ⚠ **The other end, and it is the half that fails silently.** Rest a body ON or PAST
	# `critter_radius + CLONE_BODY_RADIUS` and `World._contact()`'s bare-clone band can never be closed
	# again — nothing in `Swarm._move_clone()` steers a clone toward a creature — so melee stops with every
	# distance check in this file still green. See `Rules.SEPARATION_CONTACT_MARGIN`.
	t.ok(furthest <= clone_rest + 0.001,
			"그리고 한 마리도 때리는 띠 %.0fpx 밖으로는 안 나간다 (가장 바깥 %.3f)"
					% [r + CLONE_R, furthest])
	var host_gap: float = w.swarm.pos[0].distance_to(at)
	t.ok(absf(host_gap - host_rest) < 0.001,
			"호스트는 제 반지름만큼 더 멀리, %.0fpx에 선다 (%.3f)" % [host_rest, host_gap])

	# -- the real frame: the creature moves its own walk and nothing else moves it --
	var w2 := _buried_fixture(1260 + s, s, at)
	var biggest := 0.0
	var previous: Vector2 = w2.critter_pos[0]
	for _f in WALK_FRAMES:
		w2.step(DT)
		biggest = maxf(biggest, w2.critter_pos[0].distance_to(previous))
		previous = w2.critter_pos[0]
	var step_px: float = float(SPECIES_SPEED[s]) / 60.0
	t.ok(biggest <= step_px + 0.001,
			"프레임을 통째로 %d번 돌려도 %d번 종이 한 프레임에 움직인 것은 제 걸음 %.3fpx뿐이다 (%.3f)"
					% [WALK_FRAMES, s, step_px, biggest])


## A creature of species `s` at its own minimum force, buried under the host and twelve clones, with every
## attack clock wound forward. **Damage carries knockback and knockback moves creatures** — a fixture that
## let a single hit fire could not tell a separation push from a landed blow, which is the same reason
## `_s2`'s second half mutes both sides.
##
## ⚠ **Half the clones are EXACTLY coincident and half are only partly inside, and an all-coincident fixture
## was measured to miss things.** `push_out_of` has two branches — the deterministic angle at `l == 0` and
## the ordinary `d / l` — and a displacement bug written with a `l > 0.0001` guard, which is how anyone would
## write one, never fires on a pile. Driven with coincident bodies alone the exact "the creature did not
## move" assertion stayed green while forty bodies threw the boss 61px in a frame.
func _buried_fixture(seed_value: int, s: int, at: Vector2) -> World:
	var w := World.new()
	w.setup(seed_value)
	_silence_food(w)
	_clear_terrain(w)
	w.critter_count = 0
	# -1 for the boss row too: `_step_arena()` refuses on it, so the arena stays out of a check about pushing.
	w.boss_index = -1
	# An arrival mid-walk would put a second creature in the measurement and the frame count would stop
	# meaning what it says.
	w._next_critter = 100000.0
	w._write_critter(s, at, int(Rules.SPECIES_FORCE_MIN[s]))
	w.critter_hp[0] = 1000000
	w.critter_atk_cd[0] = 1000000.0
	# The host stands dead centre — that is the arena summon's own state, and it is the coincident branch.
	w.swarm.pos[0] = at
	for i in BURIED_CLONES:
		var c := w.swarm.add_clone(0, 5)
		if i % 2 == 0:
			w.swarm.pos[c] = at
		else:
			# Half a radius in, on a distinct bearing so the odd ones do not stack on one coordinate.
			var a := float(i) * 1.1
			w.swarm.pos[c] = at + Vector2(cos(a), sin(a)) * float(SPECIES_R[s]) * 0.5
		w.swarm.atk_cd[c] = 1000000.0
		w.swarm.hp[c] = 1000000
	return w


# -- O6: the separated swarm still finishes the kill, on the clock it had before -------------------------
## **`_s4` proves a separated clone keeps LANDING; this proves the target still DIES, and when.** They are
## not the same claim: `_s4`'s crow is invincible, so a rest distance that drifted outward over a long fight
## — rather than on the first frame — would leave it green. This one runs the fight to the corpse.
##
## ⚠ **The frame the kill lands on is measured on this fixture, not derived.** A force-4 clone against a
## force-10 crow is 8 hits at `CLONE_ATTACK_PERIOD`, and the arithmetic for where those land depends on
## float accumulation in the cooldown, which is exactly the thing a closed form gets wrong by one frame.
func _o6_a_swarm_still_kills_what_it_was_separated_from(t) -> void:
	var at := Vector2(1500.0, 1500.0)

	# -- half A: three coincident clones, and the crow is dead the frame separation first runs --
	var w := _kill_fixture(1280, at, 3, 10)
	t.eq(w.critter_count, 1, "설정: 힘 10짜리 까마귀 하나, 체력 30")
	t.eq(w.swarm.count, 4, "설정: 힘 10짜리 분신 셋이 그 한가운데에 겹쳐 서 있다")
	w.step(DT)
	t.eq(w.critter_count, 0, "겹쳐 있던 분신 셋은 첫 프레임에 30을 넣고 까마귀를 죽인다")
	t.eq(w.corpse_count, 1, "그리고 시체가 하나 남는다 — 밀어내기가 죽음을 못 막는다")

	# -- half B: one weak clone, and the kill has to arrive on the schedule the cooldown sets --
	var w2 := _kill_fixture(1281, at, 1, KILL_CLONE_FORCE)
	var died_at := -1
	for f in KILL_SEARCH:
		w2.step(DT)
		if w2.critter_count == 0:
			died_at = f + 1
			break
	t.ok(died_at > 0,
			"힘 %d짜리 분신 하나로도 까마귀는 끝내 죽는다 (%d프레임, 남은 체력 %d)"
					% [KILL_CLONE_FORCE, died_at,
							(int(w2.critter_hp[0]) if w2.critter_count > 0 else 0)])
	# ⚠ **The floor is the half that catches a fake.** Five hits cannot arrive faster than four cooldowns,
	# so a kill that came EARLY would mean the band was being sampled more often than the clock allows —
	# which is what a separation pass that ran twice, or a cooldown it reset, would look like.
	t.ok(died_at >= KILL_FRAME_MIN,
			"다섯 대가 네 주기보다 빨리 들어오지는 않는다 — %d프레임 이상 (%d)" % [KILL_FRAME_MIN, died_at])
	t.ok(died_at > 0 and died_at <= KILL_FRAME_MAX,
			"늦지도 않는다 — 밀어내기가 한 대도 빼먹지 않으면 %d프레임 안이다 (%d)"
					% [KILL_FRAME_MAX, died_at])


## A crow at `at` with `clones` bodies of `clone_force` standing exactly on it. The crow's own attack clock is
## wound forward: this is about the swarm's damage arriving, and a crow that kills the clones measuring it
## changes the fixture every period.
func _kill_fixture(seed_value: int, at: Vector2, clones: int, clone_force: int) -> World:
	var w := World.new()
	w.setup(seed_value)
	_silence_food(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	w._next_critter = 100000.0
	w.swarm.pos[0] = Vector2(3400.0, 200.0)
	for _i in clones:
		var c := w.swarm.add_clone(0, clone_force)
		w.swarm.pos[c] = at
		w.swarm.hp[c] = 1000000
	# STRIKE, so the swarm stays on the creature instead of walking back to a host parked out of the way.
	w.swarm.command_strike(at)
	w._write_critter(CROW, at, 10)
	w.critter_atk_cd[0] = 1000000.0
	return w


func _closest_pair(sw: Swarm) -> float:
	var closest := INF
	for i in range(1, sw.count):
		for j in range(i + 1, sw.count):
			closest = minf(closest, sw.pos[i].distance_to(sw.pos[j]))
	return closest


func _closest_to_host(sw: Swarm) -> float:
	var closest := INF
	for i in range(1, sw.count):
		closest = minf(closest, sw.pos[i].distance_to(sw.pos[0]))
	return closest


func _silence_food(w: World) -> void:
	for i in w.food.alive.size():
		w.food.alive[i] = 0
	w.food.alive_count = 0


## Forty rocks sit wherever a fixture writes a coordinate, and `push_out` moves a hand-placed body off one by
## up to a rock's radius. A check that is not about the ground removes the ground first.
func _clear_terrain(w: World) -> void:
	w.terrain.rock_pos.clear()
	w.terrain.rock_radius.clear()
	w.terrain.water_pos.clear()
	w.terrain.water_radius.clear()
