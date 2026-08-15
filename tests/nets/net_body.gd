extends RefCounted
## The body: wearing, digesting, binding, firing, breath and the trait.
##
## **Force is written, never derived, and the missing subtraction is the version that ships.** Every check
## about `wear()` below pins `swarm.force[0]` to a LITERAL rather than to `Parts.FORCE[...]` read back —
## `force[0] += Parts.FORCE[p]` compared against `Parts.FORCE[p]` passes at every value, zero included, and
## a check that only asserts the slot changed stays green while every overwritten part leaves ghost force
## behind for `F` to multiply.
##
## ⚠ **Two parts now share one square, and no part takes two.** `말 다리` and `까마귀 발` are both
## hindlimbs, so eviction — the plan's own acceptance question, "did you ever refuse a good part because of
## what it would push out" — is reachable in play at last, and it needed no new sim code. **What is still
## unreachable is the MULTI-slot part**: that fork was closed deliberately (user), so checks 3 and the
## guards it exercises have nothing in the shipped table to drive them. `RigBody` below supplies that
## layout and everything else runs unchanged. It is reported, not hidden.
##
## Nothing here reads a `COOLDOWN` to check a cooldown. Check 6 times three bodies at three levels against
## the same frame counts — 0.5 / 0.45 / 0.405 — which is the only shape that tells compounding apart from
## a flat ten percent.

const DT := 1.0 / 60.0

## A body at gallop travels this far in one frame: `HOST_SPEED 200 × SELF_MUL[HORSE_LEGS] 1.1 / 60`. A
## literal, because read through the two constants it passes at every value including 1.0. It was 6.0 while
## the multiplier was 1.8, which put a galloping host above the horse and deleted the herding the stage is
## built on — the gap to `WALK_STEP` is smaller now and every tolerance below is 0.01, well inside it.
const GALLOP_STEP := 3.6666667
## And at a plain walk: `HOST_SPEED 200 / 60`.
const WALK_STEP := 3.3333333


## A `Body` whose slot layout and part level come from the NET rather than from `Parts`.
##
## ⚠ **Only ever used to give a part a DIFFERENT real slot, never a slot for a slotless part.**
## `Body.hp_max()`, `breath_max()` and `_recompute_traits()` each index `Parts.SLOTS[p][0]` directly
## instead of going through `slots_of()`, so putting `물기` (whose row is `[]`) into a square would index
## out of bounds inside `wear()` itself. That is a real latent index error in `body.gd` and it is reported;
## this
## class stays away from it by remapping only among the three horse parts, whose rows are non-empty.
class RigBody extends Body:
	## part id -> Array of `Parts.Slot` ids.
	var slot_map := {}
	## part id -> the level `part_level()` should report, so `part_cooldown()` can be timed at Lv2 and Lv3
	## without a table that has any levellable ARC part in it.
	var level_of := {}

	func slots_of(part: int) -> PackedInt32Array:
		if slot_map.has(part):
			return PackedInt32Array(slot_map[part])
		return super.slots_of(part)

	func part_level(part: int) -> int:
		if level_of.has(part):
			return int(level_of[part])
		return super.part_level(part)


## The HP readout, captured off the one leaf it goes through. ⚠ **This replaced a `HeartSpy` over a
## `_paint_heart` hook that no longer exists**: the row of circles was deleted (user: 하트 개념 말고 숫자로
## 바로 표시), so there is nothing native left to override and `_paint_text` is the whole readout. Check
## 12's HUD half lives here rather than in `net_hud` because what it measures is `Body.hp_max()`, not the
## HUD's own numbers. The position and the colour are captured too — a string is not a readout if it lands
## outside the Control, and `Look.HUD_HP_COLOR` would otherwise be a constant nothing reads.
class HpSpy extends Hud:
	var lines: Array = []

	func _paint_text(c: CanvasItem, p: Vector2, text: String, font_size: int, col: Color) -> void:
		lines.append({"p": p, "text": text, "col": col})
		super._paint_text(c, p, text, font_size, col)


	func _find(needle: String) -> Dictionary:
		for e: Dictionary in lines:
			if str(e["text"]) == needle:
				return e
		return {}


func run(t) -> void:
	_c_setup(t)
	_c_world_wiring(t)
	_c1_wear_into_empty(t)
	_c2_wear_over_occupied(t)
	_c3_multi_slot_evicted_whole(t)
	_c4_digest_clears_the_binding(t)
	_c5_level_or_replacement(t)
	_c6_level_pays(t)
	_c7_space_gate(t)
	_c11_trait(t)
	await _c12_hp(t)
	_c15_breath(t)
	_c15b_lungs_raise_the_ceiling(t)
	_c_multi_slot_counted_once(t)
	_c16_snapshot(t)


# -- how a body opens -----------------------------------------------------------------------------------
## ⚠ **The empty sentinel is `-1` and it must not be 0.** `Parts.BITE` is 0, so plan 2's `Actives.NONE == 0`
## carried across unchanged reads "holding 물기" as "holding nothing" — it compiles, it runs, and the panel
## and every `bound` reader agree with each other about the wrong thing.
func _c_setup(t) -> void:
	var b := Body.new()
	b.setup()
	t.eq(b.slot_part.size(), 11, "칸은 열하나로 열린다")
	t.eq(b.slot_level.size(), 11, "레벨 줄도 열하나다")
	var empty := 0
	for s in b.slot_part.size():
		if b.slot_part[s] == -1 and b.slot_level[s] == 0:
			empty += 1
	t.eq(empty, 11, "열한 칸이 전부 비어서 열린다")

	t.eq(b.bound, PackedInt32Array([Parts.BITE, -1, Parts.DASH]),
			"좌클릭은 물기, 우클릭은 빈 칸, 스페이스는 짧은 숨으로 열린다")
	t.eq(b.bound[1], -1, "빈 키는 -1이다 — 0은 물기라서 빈 칸일 수 없다")
	t.eq(b.bound_cd.size(), Body.KEY_COUNT, "쿨다운도 키 수만큼 있다")
	t.eq(b.held.size(), Body.KEY_COUNT, "누르고 있는지도 키 수만큼 있다")
	t.eq(b.breath, 2.0, "숨은 2.0초로 열린다 (리터럴)")
	t.ok(not b.trait_horse, "말 특성은 꺼진 채로 열린다")

	t.ok(not b.fire(1, Vector2.RIGHT), "빈 키는 아무것도 내지 않는다")
	t.ok(not b.fire(0, Vector2.RIGHT), "무리에 닿지 못한 몸은 물지 못한다 — true를 돌려주고 마는 것이 아니다")
	t.ok(not b.fire(-1, Vector2.RIGHT) and not b.fire(9, Vector2.RIGHT), "없는 키는 거부된다")
	t.ok(not b.can_bind(-1, 0), "빈 칸(-1)은 어느 키에도 묶이지 않는다")

	t.eq(b.hp_max(0), 30, "아무것도 없는 몸의 최대 체력은 30이다 (리터럴)")
	t.eq(b.hp_max(3), 39, "레벨 셋이면 39다 — 레벨당 3")
	t.eq(b.breath_max(), 2.0, "허파가 없으면 숨의 최대는 2.0이다")


## ⚠ **`Body` reaches the world through `swarm` and nothing else, and `World.setup()` is the one line that
## hands it over.** Every rig below wires it by hand; without this check that hand-wiring would hide a
## missing line in the shell — `Body`'s own methods all null-check, so there is no error to see and wearing
## a part would simply move no force.
##
## The ordering is measured as a PROCESS, not as final state: a gallop's first frame is the only frame that
## can tell "speed written before the host moved" from "after".
func _c_world_wiring(t) -> void:
	var w := World.new()
	w.setup(101)
	t.ok(w.body.swarm == w.swarm, "World.setup()이 몸을 무리에 실제로 이어 붙인다 (같은 인스턴스)")
	t.eq(w.body.slot_part.size(), 11, "World가 만든 몸도 칸 열하나로 열린다")
	var force_before: int = w.swarm.force[0]
	w.take_card(Parts.HORSE_LEGS)   ## not offered — must be refused, so force may not move
	t.eq(w.swarm.force[0], force_before, "제시되지 않은 카드로는 힘이 움직이지 않는다")

	_silence(w)
	w.body.wear(Parts.HORSE_LEGS)
	w.body.bind(Parts.HORSE_LEGS, Body.KEY_MOVEMENT)
	w.body.held[Body.KEY_MOVEMENT] = 1
	w.swarm.pos[0] = Vector2(1000.0, 1000.0)
	w.swarm.host_input = Vector2.RIGHT
	var from: Vector2 = w.swarm.pos[0]
	w.step(DT)
	var travel := w.swarm.pos[0].distance_to(from)
	# `GALLOP_STEP`, not `WALK_STEP`: `Body.step()` writes `swarm.active_speed_mul` and `_move_host()` reads
	# it the SAME frame. Called after the swarm instead, the very first frame of every gallop runs at a walk
	# — and the final position after a long hold is identical either way, so only this one frame can see it.
	# The two differ by 0.333px against a 0.01 tolerance.
	t.ok(absf(travel - GALLOP_STEP) < 0.01,
			"첫 프레임부터 갤럽 속도다 — Body.step이 Swarm.step보다 먼저 돈다 (%.3f)" % travel)


# -- 1: wearing into an empty slot ----------------------------------------------------------------------
## *Mutation: drop the `swarm.force[0] += Parts.FORCE[part]` line.*
func _c1_wear_into_empty(t) -> void:
	var rig := _rig(1)
	var sw: Swarm = rig[0]
	var b: Body = rig[1]
	t.eq(sw.force[0], 10, "설정: 호스트는 힘 10으로 연다 (리터럴)")

	var digested: Array = b.wear(Parts.HORSE_LEGS)
	t.eq(digested.size(), 0, "빈 칸에 입으면 소화되는 것이 없다")
	t.eq(b.slot_part[Parts.Slot.HINDLIMBS], Parts.HORSE_LEGS, "뒷다리 칸이 말 다리를 든다")
	t.eq(b.slot_level[Parts.Slot.HINDLIMBS], 1, "그 칸의 레벨은 1이다")
	t.ok(b.is_worn(Parts.HORSE_LEGS), "몸이 그것을 입고 있다고 답한다")
	t.eq(sw.force[0], 15, "힘이 정확히 5 올라 15가 된다 (리터럴)")

	b.wear(Parts.HORSE_MANE)
	t.eq(b.slot_part[Parts.Slot.TORSO], Parts.HORSE_MANE, "몸통 칸이 말 갈기를 든다")
	t.eq(sw.force[0], 20, "갈기로 다시 5가 올라 20이 된다")
	t.eq(b.hp_max(0), 35, "갈기가 최대 체력을 5 올린다 (30 → 35)")

	b.wear(Parts.HORSE_LUNG)
	t.eq(b.slot_part[Parts.Slot.LUNG], Parts.HORSE_LUNG, "허파 칸이 말 폐활량을 든다")
	t.eq(sw.force[0], 20, "힘 0짜리 부품은 힘을 움직이지 않는다 — 아무 값이나 더하고 있지 않다")
	t.ok(absf(b.breath_max() - 4.5) < 0.001, "허파가 숨의 최대를 2.0 → 4.5로 올린다 (%.3f)" % b.breath_max())

	# Per index, never as a count: three parts in three named squares, and the other eight untouched.
	var filled := 0
	for s in b.slot_part.size():
		if b.slot_part[s] >= 0:
			filled += 1
	t.eq(filled, 3, "채워진 칸은 셋뿐이다 — 나머지 여덟은 그대로 비어 있다")
	t.eq(b.slot_part[Parts.Slot.HEAD], -1, "머리 칸은 여전히 비어 있다")
	t.eq(b.slot_part[Parts.Slot.BONE], -1, "뼈 칸은 여전히 비어 있다")


# -- 2: wearing over an occupied slot ------------------------------------------------------------------
## *Mutation: drop the `swarm.force[0] -= part_force(victim)` half — the ghost-force bug, which `F` then
## multiplies.* A check that only asserts the slot changed stays green through all of it.
##
## ⚠ Synthetic layout — see the file header. `말 갈기` is put in the hindlimb square so that the eviction
## can be driven at a known force (5 in, 5 out) rather than at 까마귀 발's, which shares that square for
## real. The real pair is what makes the mechanic reachable in play; this rig is what keeps the arithmetic
## a literal.
func _c2_wear_over_occupied(t) -> void:
	var rig := _rig(2)
	var sw: Swarm = rig[0]
	var b: RigBody = rig[1]
	b.slot_map = {Parts.HORSE_MANE: [Parts.Slot.HINDLIMBS]}

	b.wear(Parts.HORSE_LEGS)
	t.eq(sw.force[0], 15, "설정: 말 다리를 입어 힘이 15다")
	var digested: Array = b.wear(Parts.HORSE_MANE)
	t.eq(digested.size(), 1, "덮어쓰면 먹힌 부품 하나가 돌아온다")
	t.eq(int(digested[0]), Parts.HORSE_LEGS, "그리고 그것은 원래 있던 말 다리다")

	t.ok(not b.is_worn(Parts.HORSE_LEGS), "먹힌 부품은 더 이상 입고 있는 것이 아니다")
	var still_there := -1
	for s in b.slot_part.size():
		if b.slot_part[s] == Parts.HORSE_LEGS:
			still_there = s
	t.eq(still_there, -1, "먹힌 부품이 열한 칸 어디에도 남아 있지 않다")
	t.eq(sw.force[0], 15, "힘은 바탕 10 + 새 부품 5뿐이다 — 먹힌 5가 유령으로 남지 않는다 (리터럴)")
	t.eq(sw.total_force(), 15, "무리 전체의 힘도 15다")

	# **The victim was Lv2, and it is worth Lv2 on the way out.** Subtracting the table's base 5 instead of
	# `part_force()`'s 10 leaves 5 of ghost force behind, and the round-trip check above cannot see it.
	var rig2 := _rig(22)
	var sw2: Swarm = rig2[0]
	var b2: RigBody = rig2[1]
	b2.slot_map = {Parts.HORSE_MANE: [Parts.Slot.HINDLIMBS]}
	b2.wear(Parts.HORSE_LEGS)
	b2.wear(Parts.HORSE_LEGS)
	t.eq(sw2.force[0], 20, "설정: 말 다리 Lv2까지 올려 힘이 20이다")
	b2.wear(Parts.HORSE_MANE)
	t.eq(sw2.force[0], 15, "Lv2였던 부품은 Lv2의 값(10)만큼 빠진다 — 바탕값 5만 빼면 여기서 걸린다")


# -- 3: a multi-slot part is evicted WHOLE --------------------------------------------------------------
## *Mutation: clear only the square that was claimed.* The other square then still points at a part that is
## not worn — a dangling index that reads fine, draws a name, and fires nothing.
##
## ⚠ Synthetic layout — no row in the August table takes two squares at all.
func _c3_multi_slot_evicted_whole(t) -> void:
	var rig := _rig(3)
	var sw: Swarm = rig[0]
	var b: RigBody = rig[1]
	b.slot_map = {Parts.HORSE_MANE: [Parts.Slot.HINDLIMBS, Parts.Slot.TAIL]}

	b.wear(Parts.HORSE_MANE)
	t.eq(b.slot_part[Parts.Slot.HINDLIMBS], Parts.HORSE_MANE, "설정: 두 칸짜리 부품이 뒷다리 칸을 든다")
	t.eq(b.slot_part[Parts.Slot.TAIL], Parts.HORSE_MANE, "설정: 꼬리 칸도 같은 부품이 든다")
	t.eq(b.slot_level[Parts.Slot.TAIL], 1, "설정: 두 칸 모두 같은 레벨을 든다")
	t.eq(sw.force[0], 15, "설정: 두 칸짜리 부품도 힘은 한 번만 준다")

	b.wear(Parts.HORSE_LEGS)   ## claims HINDLIMBS only
	t.eq(b.slot_part[Parts.Slot.HINDLIMBS], Parts.HORSE_LEGS, "차지한 칸은 새 부품이 든다")
	t.eq(b.slot_part[Parts.Slot.TAIL], -1, "차지하지 않은 다른 칸도 함께 비워진다")
	t.eq(b.slot_level[Parts.Slot.TAIL], 0, "그 칸의 레벨도 0으로 돌아간다")
	t.eq(sw.force[0], 15, "두 칸짜리 부품의 힘도 한 번만 빠진다 — 두 번 빼면 힘이 조용히 내려간다")


# -- 4: a digested part's binding clears, and the key fires NOTHING -------------------------------------
## *Mutation: skip the `bound` scan in the digest path.* Read off the array this is invisible; the key is
## DRIVEN instead — with the stale id still in `bound[2]`, `Body.step()` would keep galloping on a part the
## body is not wearing.
func _c4_digest_clears_the_binding(t) -> void:
	var rig := _rig(4)
	var sw: Swarm = rig[0]
	var b: RigBody = rig[1]
	b.slot_map = {Parts.HORSE_MANE: [Parts.Slot.HINDLIMBS]}

	b.wear(Parts.HORSE_LEGS)
	t.ok(b.bind(Parts.HORSE_LEGS, Body.KEY_MOVEMENT), "설정: 말 다리를 스페이스에 묶었다")
	b.held[Body.KEY_MOVEMENT] = 1
	b.step(DT)
	t.ok(absf(sw.active_speed_mul - 1.1) < 0.001,
			"설정: 그 키가 실제로 갤럽을 돌린다 (%.3f)" % sw.active_speed_mul)

	b.wear(Parts.HORSE_MANE)   ## digests 말 다리
	var breath_before := b.breath
	b.held[Body.KEY_MOVEMENT] = 1
	b.step(DT)
	t.eq(sw.active_speed_mul, 1.0, "먹힌 부품이 묶여 있던 키는 아무것도 내지 않는다")
	t.ok(b.breath > breath_before, "그리고 숨도 닳지 않는다 — 없는 것이 계속 돌고 있지 않다")
	t.eq(b.bound[Body.KEY_MOVEMENT], -1, "그 키는 빈 칸으로 돌아간다")
	t.eq(b.bound_cd[Body.KEY_MOVEMENT], 0.0, "그 키의 쿨다운도 지워진다")


# -- 5: the same part again is a LEVEL; a different part in the same square is a REPLACEMENT ------------
func _c5_level_or_replacement(t) -> void:
	var rig := _rig(5)
	var sw: Swarm = rig[0]
	var b: Body = rig[1]
	b.wear(Parts.HORSE_LEGS)
	var again: Array = b.wear(Parts.HORSE_LEGS)
	t.eq(again.size(), 0, "같은 부품을 또 입어도 소화되는 것은 없다 — 교체가 아니다")
	t.eq(b.slot_level[Parts.Slot.HINDLIMBS], 2, "같은 부품은 Lv2가 된다")
	t.eq(b.part_level(Parts.HORSE_LEGS), 2, "부품의 레벨도 2라고 답한다")
	var filled := 0
	for s in b.slot_part.size():
		if b.slot_part[s] >= 0:
			filled += 1
	t.eq(filled, 1, "레벨이 올랐을 뿐 입은 부품은 여전히 하나다")
	t.eq(sw.force[0], 20, "레벨 하나가 힘 5를 준다 (15 → 20, 리터럴)")

	# The replacement half — synthetic layout, see the file header.
	var rig2 := _rig(55)
	var b2: RigBody = rig2[1]
	b2.slot_map = {Parts.HORSE_MANE: [Parts.Slot.HINDLIMBS]}
	b2.wear(Parts.HORSE_LEGS)
	b2.wear(Parts.HORSE_LEGS)
	t.eq(b2.slot_level[Parts.Slot.HINDLIMBS], 2, "설정: 같은 칸의 부품이 Lv2다")
	var digested: Array = b2.wear(Parts.HORSE_MANE)
	t.eq(digested.size(), 1, "다른 부품은 레벨업이 아니라 교체다")
	t.eq(b2.slot_level[Parts.Slot.HINDLIMBS], 1, "교체된 칸의 레벨은 1로 돌아간다 — 이어받지 않는다")


# -- 6: a level has to DO something ---------------------------------------------------------------------
## *Mutation: make the level a no-op.* The force half is literals; the cooldown half is TIMED, never read
## out of `Parts.COOLDOWN`.
##
## ⚠ **Three levels, not two.** `pow(0.9, lv-1)` and a flat `× 0.9` are the same number at Lv2, so a single
## level cannot tell compounding from one-off. 0.5 / 0.45 / 0.405 against 25, 28 and 32 frames separates
## all three, and every frame count is a literal.
func _c6_level_pays(t) -> void:
	var rig := _rig(6)
	var sw: Swarm = rig[0]
	var b: Body = rig[1]
	b.wear(Parts.HORSE_LEGS)
	t.eq(sw.force[0], 15, "Lv1: 힘 15")
	b.wear(Parts.HORSE_LEGS)
	t.eq(sw.force[0], 20, "Lv2: 힘이 정확히 5 더 올라 20 (리터럴)")
	b.wear(Parts.HORSE_LEGS)
	t.eq(sw.force[0], 25, "Lv3: 또 5가 올라 25 — 레벨이 값을 갖는다")
	t.eq(b.slot_level[Parts.Slot.HINDLIMBS], 3, "그 칸은 Lv3이다")

	# 25 frames = 0.4167s. Lv1 (0.5) and Lv2 (0.45) must both still refuse; Lv3 (0.405) must fire.
	var a25 := _refire_after(1, 25)
	var b25 := _refire_after(2, 25)
	var c25 := _refire_after(3, 25)
	t.ok(a25[0] and b25[0] and c25[0], "설정: 세 몸 모두 첫 물기는 실제로 들어갔다")
	t.ok(not a25[1], "0.417초로는 Lv1(0.5초)의 두 번째 물기가 아직 안 나간다")
	t.ok(not b25[1], "Lv2(0.45초)도 아직 안 나간다")
	t.ok(c25[1], "Lv3(0.405초)은 나간다 — 10%가 겹쳐 붙는다 (한 번만 깎으면 여기서 걸린다)")

	# 28 frames = 0.4667s. Lv2 crosses, Lv1 still does not.
	var a28 := _refire_after(1, 28)
	var b28 := _refire_after(2, 28)
	t.ok(a28[0] and b28[0], "설정: 첫 물기는 둘 다 들어갔다")
	t.ok(not a28[1], "0.467초로는 Lv1이 아직 안 나간다 — 레벨을 무시하면 여기가 초록이 된다")
	t.ok(b28[1], "Lv2는 나간다 — 쿨다운이 실제로 짧아졌다")

	# 32 frames = 0.5333s. The base cooldown itself expires, so "nothing ever fires twice" cannot pass.
	var a32 := _refire_after(1, 32)
	t.ok(a32[0] and a32[1], "대조: 0.533초가 지나면 Lv1도 다시 문다 — 두 번째 물기가 원래 되긴 한다")


# -- 7: `space` takes movement parts only, and binding over `DASH` loses it -----------------------------
## *Mutation: gate `space` on `Kind.ACTIVE` instead of `Parts.MOVEMENT`.* 말 갈기 is PASSIVE, so the wrong
## gate refuses it too and a check built only on 갈기 passes. **물기 is the part that tells them apart**:
## ACTIVE, and `MOVEMENT` 0.
func _c7_space_gate(t) -> void:
	var rig := _rig(7)
	var b: Body = rig[1]
	t.ok(b.can_bind(Parts.DASH, Body.KEY_MOVEMENT), "스페이스는 짧은 숨을 받는다")
	t.ok(not b.can_bind(Parts.HORSE_LEGS, Body.KEY_MOVEMENT),
			"설정: 아직 입지 않은 말 다리는 어느 키도 받지 않는다")
	b.wear(Parts.HORSE_LEGS)
	t.ok(b.can_bind(Parts.HORSE_LEGS, Body.KEY_MOVEMENT), "입은 말 다리는 스페이스가 받는다")

	t.ok(b.can_bind(Parts.BITE, 0), "설정: 물기는 좌클릭에 들어간다")
	t.ok(not b.can_bind(Parts.BITE, Body.KEY_MOVEMENT),
			"물기는 스페이스가 거부한다 — 문지기는 '액티브냐'가 아니라 '움직이느냐'다")

	b.wear(Parts.HORSE_MANE)
	t.ok(not b.can_bind(Parts.HORSE_MANE, Body.KEY_MOVEMENT), "말 갈기는 스페이스가 거부한다")
	t.ok(not b.can_bind(Parts.HORSE_MANE, 0), "입은 말 갈기도 좌클릭에 들어가지 않는다 — 패시브는 키의 것이 아니다")

	# The trade the design wants, driven: a burst you can spam, or a run you have to breathe for.
	var rig2 := _rig(77)
	var sw2: Swarm = rig2[0]
	var b2: Body = rig2[1]
	t.ok(b2.fire(Body.KEY_MOVEMENT, Vector2(1400.0, 1000.0)), "설정: 스페이스가 짧은 숨을 낸다")
	t.ok(sw2.dash_left > 0.0, "설정: 실제로 대시 상태가 됐다")

	var rig3 := _rig(78)
	var sw3: Swarm = rig3[0]
	var b3: Body = rig3[1]
	b3.wear(Parts.HORSE_LEGS)
	t.ok(b3.bind(Parts.HORSE_LEGS, Body.KEY_MOVEMENT), "말 다리를 스페이스에 넣는다")
	t.ok(not b3.fire(Body.KEY_MOVEMENT, Vector2(1400.0, 1000.0)),
			"스페이스에서 터지는 것이 없어졌다 — 짧은 숨은 사라졌다")
	t.eq(sw3.dash_left, 0.0, "그리고 실제로 대시 상태가 되지 않는다")
	t.ok(not b3.can_bind(Parts.DASH, Body.KEY_MOVEMENT),
			"짧은 숨은 어디에도 남지 않아 다시 넣을 수도 없다")
	t.ok(not b3.can_bind(Parts.DASH, 0), "좌클릭에도 못 넣는다")
	# But the key is not dead — it holds a different KIND of movement now.
	b3.held[Body.KEY_MOVEMENT] = 1
	b3.step(DT)
	t.ok(absf(sw3.active_speed_mul - 1.1) < 0.001,
			"대신 그 키는 누르고 있는 갤럽이 된다 (%.3f)" % sw3.active_speed_mul)


# -- 11: the trait fires, not merely sets -----------------------------------------------------------------
## *Mutation: set the flag and never read it in the drain.* So the gallop is HELD for three seconds and
## `breath` is asserted not to have moved at all — and the control, two horse parts, drains on the clock.
func _c11_trait(t) -> void:
	var rig := _rig(11)
	var b: RigBody = rig[1]
	b.wear(Parts.HORSE_LEGS)
	b.wear(Parts.HORSE_LUNG)
	t.ok(not b.trait_horse, "말 부품 둘로는 특성이 붙지 않는다")
	b.wear(Parts.HORSE_MANE)
	t.ok(b.trait_horse, "셋을 다 입으면 말 특성이 붙는다")

	var rig_t := _rig(111)
	var sw_t: Swarm = rig_t[0]
	var b_t: Body = rig_t[1]
	b_t.wear(Parts.HORSE_LEGS)
	b_t.wear(Parts.HORSE_LUNG)
	b_t.wear(Parts.HORSE_MANE)
	b_t.bind(Parts.HORSE_LEGS, Body.KEY_MOVEMENT)
	b_t.held[Body.KEY_MOVEMENT] = 1
	sw_t.pos[0] = Vector2(500.0, 1000.0)
	sw_t.host_input = Vector2.RIGHT
	var breath0 := b_t.breath
	var from: Vector2 = sw_t.pos[0]
	for _s in 180:
		b_t.step(DT)
		sw_t.step(DT, null)
	t.eq(b_t.breath, breath0, "특성이 붙으면 3초를 눌러도 숨이 한 방울도 닳지 않는다")
	# **Not just the flag: the gallop has to still be running at the end of those three seconds.**
	var travelled := sw_t.pos[0].distance_to(from)
	t.ok(absf(travelled - 180.0 * GALLOP_STEP) < 1.0,
			"그리고 3초 내내 갤럽 속도로 달렸다 (%.1f / 660)" % travelled)

	# The control: the same hold without the trait drains on the clock, so "숨이 안 닳는다" cannot be the
	# state of a body that was never galloping in the first place.
	var rig_c := _rig(112)
	var sw_c: Swarm = rig_c[0]
	var b_c: Body = rig_c[1]
	b_c.wear(Parts.HORSE_LEGS)
	b_c.wear(Parts.HORSE_LUNG)
	b_c.bind(Parts.HORSE_LEGS, Body.KEY_MOVEMENT)
	b_c.held[Body.KEY_MOVEMENT] = 1
	sw_c.pos[0] = Vector2(500.0, 1000.0)
	sw_c.host_input = Vector2.RIGHT
	for _s in 60:
		b_c.step(DT)
		sw_c.step(DT, null)
	t.ok(absf(b_c.breath - 1.0) < 0.02,
			"대조: 특성이 없으면 1초에 숨 1.0이 닳는다 (2.0 → %.3f)" % b_c.breath)


# -- 12: HP grows with levels and parts, and the HUD prints the ceiling ---------------------------------
## *Mutation: `hp_max` returns `HOST_HP + level` and ignores `Parts.HP`; or `hud.gd` prints `host_hp`
## alone; or it prints `Rules.HOST_HP` in place of `hp_max(level)`.* The last is the quiet one — the
## ceiling then never moves and a levelled, maned host reads as being over full health.
##
## ⚠ **No check here may assert the readout's WIDTH or its PITCH.** The row's length was the heart row's
## claim and it is exactly what the user deleted; re-deriving it from the string puts the same defect back
## wearing a different hook.
func _c12_hp(t) -> void:
	var w := World.new()
	w.setup(12)
	_silence(w)
	t.eq(w.body.hp_max(3), 39, "설정: 갈기 없이 레벨 셋이면 39다")
	w.body.wear(Parts.HORSE_MANE)
	t.eq(w.body.hp_max(3), 44, "레벨 셋에 말 갈기 하나면 최대 체력은 44다 (리터럴)")

	w.level = 3
	w.host_hp = 25

	var spy := HpSpy.new()
	spy.world = w
	t.root.add_child(spy)
	await t.pump_frames(2)
	spy.lines.clear()
	await t.pump_frames(1)

	# **One string, both numbers.** "25" alone says nothing without the 44 beside it.
	var hp_line: Dictionary = spy._find("25/44")
	t.ok(not hp_line.is_empty(), "HUD가 체력을 25/44로 적는다 — 현재와 최대가 한 줄이다 %s" % str(spy.lines))

	# **`visible` is not "on screen", and neither is being wired.** `set_anchors_preset` leaves offsets
	# alone, so a Control on a bare layer keeps `size == (0, 0)` and lays every readout out from zero. The
	# bound comes from the viewport, never from the Control being checked.
	var screen: Vector2 = spy.get_viewport_rect().size
	t.eq(spy.size, screen, "HUD가 화면 전체 크기를 갖는다 — 0×0에서 좌상단에 쌓이지 않는다 (%s)" % str(spy.size))
	if not hp_line.is_empty():
		var p: Vector2 = hp_line["p"]
		t.ok(p.x >= 0.0 and p.x < screen.x, "그 줄이 화면의 가로 안에 떨어진다 (%.1f)" % p.x)
		t.ok(p.y >= 0.0 and p.y < screen.y, "세로도 화면 안이다 (%.1f)" % p.y)
		# *Mutation: draw it in `TEXT` like every other line.* Without this the one HP constant that
		# survived the heart row's deletion is read by nothing.
		t.eq(hp_line["col"], Look.HUD_HP_COLOR, "그리고 체력만의 색으로 적힌다 — 다른 줄과 같은 흰색이 아니다")

	# ⚠ **The ceiling half needs its own case or the operand swap survives.** A check that only ever sees a
	# damaged host cannot tell `%d/%d` from its reverse, and that is the same shape as the
	# `maxi(world.host_hp, Rules.HOST_HP)` bug this function was written for.
	w.host_hp = 44
	spy.lines.clear()
	spy.queue_redraw()
	await t.pump_frames(1)
	t.ok(not spy._find("44/44").is_empty(),
			"가득 찬 몸은 44/44로 적힌다 — 두 숫자의 자리가 바뀌어 있지 않다 %s" % str(spy.lines))

	t.root.remove_child(spy)
	spy.queue_free()


# -- 15: breath runs out, and holding past empty does not stutter --------------------------------------
## *Mutation: never drain `breath`.* And the other half — a loop whose condition is false from the start
## never runs the check — so the number of RAISED frames is asserted, not just that the last frames are at
## base speed.
func _c15_breath(t) -> void:
	var rig := _rig(15)
	var sw: Swarm = rig[0]
	var b: Body = rig[1]
	b.wear(Parts.HORSE_LEGS)   ## no lungs: breath_max stays 2.0
	t.eq(b.breath_max(), 2.0, "설정: 허파가 없으니 숨의 최대는 2.0이다")
	b.bind(Parts.HORSE_LEGS, Body.KEY_MOVEMENT)
	b.held[Body.KEY_MOVEMENT] = 1
	sw.pos[0] = Vector2(500.0, 1000.0)
	sw.host_input = Vector2.RIGHT

	var raised := 0
	var walked := 0
	var last_steps: Array[float] = []
	for s in 240:
		var from: Vector2 = sw.pos[0]
		b.step(DT)
		sw.step(DT, null)
		var step := sw.pos[0].distance_to(from)
		if step > (GALLOP_STEP + WALK_STEP) * 0.5:
			raised += 1
		elif absf(step - WALK_STEP) < 0.01:
			walked += 1
		if s >= 210:
			last_steps.append(step)

	# ~120 frames of gallop at 2.0s of breath. The band is wide enough for one frame of float slop and
	# narrow enough that "never drains" (240) and "never engaged" (0) both fall outside it.
	t.ok(raised >= 110 and raised <= 130,
			"숨 2.0초 동안만 빨라진다 — 빨라진 프레임이 %d개다 (110~130)" % raised)
	t.ok(raised > 0, "그리고 그 구간이 실제로 한 번은 돌았다 — 조건이 처음부터 거짓인 반복이 아니다")
	t.ok(walked >= 100, "숨이 떨어진 뒤로는 걷기 속도로 돌아간다 (%d 프레임)" % walked)
	t.eq(b.breath, 0.0, "숨은 정확히 0에서 멈춘다")

	# **Held past empty must not flutter.** Regenerating while the key is still down puts breath back above
	# zero for one frame, the sustain runs again, and the host alternates 1.8×/1.0× forever — "dropped back
	# to base" would then be false for the rest of the hold, and the last thirty frames are what sees it.
	var steady := true
	for v: float in last_steps:
		if absf(v - WALK_STEP) > 0.01:
			steady = false
	t.ok(steady, "마지막 서른 프레임이 전부 걷기 속도다 — 한 프레임씩 되살아나 덜컹거리지 않는다 %s"
			% str(last_steps.slice(0, 5)))

	# And releasing IS what buys the recovery.
	b.held[Body.KEY_MOVEMENT] = 0
	for _s in 60:
		b.step(DT)
		sw.step(DT, null)
	t.ok(absf(b.breath - 1.0) < 0.02, "손을 떼면 초당 1.0씩 돌아온다 (%.3f)" % b.breath)


# -- 15b: the lung's +2.5s reaches BEHAVIOUR, and there is exactly one place it can ---------------------
## ⚠ **`breath_max()` has one behavioural consumer and it was unmeasured.** `setup()` opens `breath` at
## `Rules.BREATH_MAX`, not at `breath_max()`, so the regen cap in `step()` is the ONLY line through which
## 말 폐활량 — one of the three August parts and a whole card face — reaches the game. Check 1 pins
## `breath_max() == 4.5` as a PURE FUNCTION and check 15 is run with no lungs on purpose; measured,
## `minf(breath_max(), ...)` folded back to `minf(Rules.BREATH_MAX, ...)` left the round green at 811 and
## the part a no-op card. *Measuring a pure function is not measuring that anything calls it.*
func _c15b_lungs_raise_the_ceiling(t) -> void:
	var rig := _rig(150)
	var b: Body = rig[1]
	b.wear(Parts.HORSE_LUNG)
	t.ok(absf(b.breath_max() - 4.5) < 0.001, "설정: 허파를 입어 숨의 최대가 4.5다 (%.3f)" % b.breath_max())
	b.breath = 0.0
	for _s in 180:
		b.step(DT)
	# 3 seconds at BREATH_REGEN 1.0/s. Past 2.0, which is the whole point: with the ceiling read off the
	# constant instead of the body this stops at 2.0 and the lung has bought nothing.
	t.ok(absf(b.breath - 3.0) < 0.02,
			"3초를 쉬면 숨이 3.0까지 찬다 — 2.0에서 막히지 않는다 (%.3f)" % b.breath)
	for _s in 180:
		b.step(DT)
	t.ok(absf(b.breath - 4.5) < 0.001,
			"더 쉬면 4.5에서 멈춘다 — 천장이 허파를 세고 있다 (%.3f)" % b.breath)

	# The control: without the lung the identical rest stops at 2.0, so "숨이 더 찬다" cannot be a body that
	# simply never had a ceiling.
	var rig2 := _rig(151)
	var b2: Body = rig2[1]
	b2.breath = 0.0
	for _s in 360:
		b2.step(DT)
	t.ok(absf(b2.breath - 2.0) < 0.001,
			"대조: 허파가 없으면 6초를 쉬어도 2.0에서 멈춘다 (%.3f)" % b2.breath)


# -- a part that holds two squares is counted ONCE ------------------------------------------------------
## ⚠ **Written by hand, and it has to be.** `hp_max()`, `breath_max()` and `_recompute_traits()` each index
## `Parts.SLOTS[p][0]` directly instead of going through the overridable `slots_of()` that `wear()` uses —
## so `RigBody`, the only multi-slot layout that exists anywhere, cannot reach any of the three. The rule
## is stated in a comment above each of them and was measured by nothing: dropping the guard from
## `hp_max()` left 811 checks green. No row in the August table takes two squares — the multi-slot fork was
## closed deliberately (user), so this stays synthetic coverage and is NOT answered. It goes wrong
## silently, and in the player's favour, the first time any plan lands one; `net_parts`'s
## `이번 빌드에 두 칸짜리 부품은 없다` is what reddens on the day that happens.
func _c_multi_slot_counted_once(t) -> void:
	var b := Body.new()
	b.setup()
	b.slot_part[Parts.Slot.TORSO] = Parts.HORSE_MANE     ## its own first square
	b.slot_level[Parts.Slot.TORSO] = 1
	b.slot_part[Parts.Slot.TAIL] = Parts.HORSE_MANE      ## a second square the same part holds
	b.slot_level[Parts.Slot.TAIL] = 1
	t.eq(b.hp_max(0), 35, "두 칸에 걸친 부품의 체력은 한 번만 센다 — 40이 아니라 35다 (리터럴)")
	t.eq(b.hp_max(3), 44, "레벨이 붙어도 마찬가지다 — 49가 아니라 44다 (리터럴)")

	var b2 := Body.new()
	b2.setup()
	b2.slot_part[Parts.Slot.LUNG] = Parts.HORSE_LUNG
	b2.slot_level[Parts.Slot.LUNG] = 1
	b2.slot_part[Parts.Slot.HEAD] = Parts.HORSE_LUNG
	b2.slot_level[Parts.Slot.HEAD] = 1
	t.ok(absf(b2.breath_max() - 4.5) < 0.001,
			"숨도 한 번만 센다 — 7.0이 아니라 4.5다 (%.3f)" % b2.breath_max())

	# And the trait counts PARTS, not squares: one horse part spread over three squares is one part.
	var b3 := Body.new()
	b3.setup()
	for s: int in [Parts.Slot.HINDLIMBS, Parts.Slot.TAIL, Parts.Slot.HEAD]:
		b3.slot_part[s] = Parts.HORSE_LEGS
		b3.slot_level[s] = 1
	b3._recompute_traits()
	t.ok(not b3.trait_horse, "특성도 칸이 아니라 부품을 센다 — 한 부품이 세 칸을 차지해도 붙지 않는다")


# -- 16: the ending's eleven squares, on BOTH paths out of a run ----------------------------------------
## *Mutation: leave `Run._snapshot()` alone.* `ending_screen.gd`'s `k < size` guard then paints eleven
## blanks with every check green.
##
## ⚠ **`_snapshot()` has two callers** — `_end()` on death and `_begin_clear()` on the clear. Filling only
## the death path leaves the WON run, the one the player actually looks at, showing eleven blanks.
func _c16_snapshot(t) -> void:
	var r := Run.new()
	r.start(16)
	_silence(r.world)
	r.world.body.wear(Parts.HORSE_LEGS)
	r.world.host_hp = 0
	r.step(DT)
	t.eq(r.phase, Run.Phase.ENDING, "설정: 죽어서 ENDING에 들어갔다")
	t.eq(r.result.body_slots.size(), 11, "몸의 칸이 열한 개 그대로 넘어간다")
	t.eq(r.result.body_slots[Parts.Slot.HINDLIMBS], "말 다리", "입은 부품의 이름이 제 칸 자리에 들어 있다")
	var blanks := 0
	for k in r.result.body_slots.size():
		if r.result.body_slots[k] == "":
			blanks += 1
	t.eq(blanks, 10, "나머지 열 칸은 빈 문자열이다 — -1이 마지막 행을 읽어 말 폐활량이 되지 않는다")

	var r2 := Run.new()
	r2.start(162)
	_silence(r2.world)
	r2.world.body.wear(Parts.HORSE_MANE)
	r2.world.stage_cleared = true
	r2.step(DT)
	t.eq(r2.outcome, Run.Outcome.CLEARED, "설정: 클리어가 잡혔다")
	t.eq(r2.result.body_slots.size(), 11, "이긴 런의 결과에도 칸이 열한 개 있다")
	t.eq(r2.result.body_slots[Parts.Slot.TORSO], "말 갈기", "이긴 런에서도 이름이 채워진다")


# -- helpers ---------------------------------------------------------------------------------------------

## A host wired exactly the way `World.setup()` wires it — `body.setup()` then `body.swarm = swarm`, in that
## order. Building a whole `World` for a check about one square would drag five hundred food spots and six
## critters in with it; `_c_world_wiring` is what stops this helper from hiding the shell's own line.
func _rig(seed_value: int, at: Vector2 = Vector2(1000.0, 1000.0)) -> Array:
	var sw := Swarm.new()
	sw.setup(seed_value, at)
	var b := RigBody.new()
	b.setup()
	b.swarm = sw
	return [sw, b]


## Fires 물기, steps `steps` frames, fires again. Returns `[first, second]` so a fixture whose FIRST shot
## silently missed cannot read as "the cooldown held" — that would make every cooldown check pass by
## accident.
##
## The level is forced through `part_level()` rather than worn, because no ARC part in the August table
## occupies a square and therefore none can be levelled at all. What is measured is that `fire()` uses
## `part_cooldown(part)` and not the table's raw `COOLDOWN`.
func _refire_after(level: int, steps: int) -> Array:
	var sw := Swarm.new()
	sw.setup(600 + level * 100 + steps, Vector2(1000.0, 1000.0))
	var b := RigBody.new()
	b.setup()
	b.swarm = sw
	b.level_of = {Parts.BITE: level}
	# Two crumbs, both dead ahead and both past EAT_RADIUS_HOST (26) so ordinary eating cannot be what
	# killed them, and both inside RANGE (70) so the second shot has something to reach.
	var f := _food_at([Vector2(1050.0, 1000.0), Vector2(1056.0, 1000.0)])
	sw.step(DT, f)
	var first := b.fire(0, Vector2(1400.0, 1000.0))
	for _s in steps:
		b.step(DT)
		sw.step(DT, f)
	return [first, b.fire(0, Vector2(1400.0, 1000.0))]


func _food_at(points: Array) -> Food:
	var f := Food.new()
	f.pos = PackedVector2Array(points)
	f.alive = PackedInt32Array()
	f.timer = PackedFloat32Array()
	f.alive.resize(points.size())
	f.timer.resize(points.size())
	for i in points.size():
		f.alive[i] = 1
		f.timer[i] = 0.0
	f.alive_count = points.size()
	return f


func _silence(w: World) -> void:
	w.critter_count = 0
	for i in w.food.alive.size():
		w.food.alive[i] = 0
	w.food.alive_count = 0
