class_name Body
extends RefCounted
## The host's own body. It lives on `World` as `var body := Body.new()`; a clone does NOT get one —
## a clone carries a single part index (plan 4's `Swarm.worn`), which is why this is not on `Swarm`.
##
## **`bound` and `bound_cd` are MOVED here from `Swarm`, not invented here.** Plan 2 put them there because
## no `Body` existed yet and said so in as many words; `src/sim/actives.gd` is deleted in the same edit and
## its three-value enum is replaced by the parts table.
##
## Nothing here touches the tree. A net drives all of it with `.new()`, `setup()` and a `Swarm`.

## The three keys, in the order the shell fires them: left click, right click, `space`.
const KEY_COUNT := 3
## `space`. The one key that refuses a part without `Parts.MOVEMENT` — see `can_bind()`.
const KEY_MOVEMENT := 2

## **Body reaches the world through the swarm and through nothing else.** `fire()`'s ARC branch has to eat
## a crumb and its SELF branch has to move the host, and both of those live on `Swarm`. Set by
## `World.setup()`; null until then, and every method that needs it checks rather than assuming, because a
## net that builds a bare `Body` to read `hp_max()` should not have to hand it a swarm.
##
## ⚠ **There is deliberately no `world` reference here.** `World` already holds `Body`, so a back-pointer
## is a RefCounted cycle that never frees, and `Run` builds a fresh `World` for every run. The one thing
## `wear()` would have needed it for — moving the host's CURRENT hp — is done by `World.take_card()` from
## the difference in `hp_max()`, which is a pure function of what is worn.
var swarm: Swarm = null

## Eleven entries, -1 for empty. Sized from `Parts.Slot`, never from a literal.
var slot_part := PackedInt32Array()
## Per slot: 0 when empty, 1.. when worn. **The part's level, not the run's.** A multi-slot part carries
## the same level in every square it holds.
var slot_level := PackedInt32Array()

## Three entries: which PART id fires on left click / right click / `space`. **-1 is empty, and the
## sentinel is negative on purpose.** `Parts.BITE` is 0, so the plan-2 sentinel (`Actives.NONE == 0`)
## carried across unchanged would read "holding 물기" as "holding nothing" — it compiles and it runs.
## ⚠ And `-1` is a LEGAL index in GDScript: `Parts.NAME[bound[k]]` on an empty key returns the LAST row
## (말 폐활량), silently. Every read of this array has to test `>= 0` first.
var bound := PackedInt32Array()
## Three entries, ticked down by `step()`. **This is the only cooldown in the game now.** Plan 2 kept a
## second one (`Swarm.dash_cd`) beside it and wrote a comment explaining that the two must never both
## exist, because two numbers for one act can disagree about whether the hand is free; the dash's cooldown
## is `COOLDOWN[DASH]` in the parts table and it is ticked here.
var bound_cd := PackedFloat32Array()

## Three entries, 0/1 — is that key down THIS frame. Written by the shell every frame from
## `Input.is_action_pressed`, not from the just-pressed edge that `fire()` runs on. A sustained active is
## "while held", and a poll left alone keeps its last value, so the shell zeroes this whenever a panel
## opens exactly as it drops the `F` wind-up.
var held := PackedInt32Array()

## Seconds of sustain left. Drains while a SUSTAINED active runs, regenerates while none does.
var breath := 0.0

## **Placeholder — nothing about traits is settled** (design doc says so in as many words). Ship one so a
## trait is reachable and testable: wear `Rules.HORSE_TRAIT_COUNT` horse parts and 갤럽 stops draining
## breath. Recomputed by `wear()`; never written from outside.
var trait_horse := false


func setup() -> void:
	slot_part = PackedInt32Array()
	slot_part.resize(Parts.Slot.size())
	slot_level = PackedInt32Array()
	slot_level.resize(Parts.Slot.size())
	for s in slot_part.size():
		slot_part[s] = -1
		slot_level[s] = 0
	# Left click opens holding 물기 and `space` opens holding 짧은 숨 — **both parts in NO slot, owned by
	# nobody**, exactly as plan 2 shipped them. The basic attack is just the active you are handed first
	# and its square can be overwritten like any other (user, 2026-08-14). Right click opens empty and is
	# the one square the player can see is empty, which is what makes the first part legible.
	bound = PackedInt32Array([Parts.BITE, -1, Parts.DASH])
	bound_cd = PackedFloat32Array()
	bound_cd.resize(KEY_COUNT)
	held = PackedInt32Array()
	held.resize(KEY_COUNT)
	breath = Rules.BREATH_MAX
	trait_horse = false


# -- what a part is worth right now ---------------------------------

## `Parts.SLOTS` is a plain const `Array` of plain `Array`s — see that file for the 4.7.1 measurement that
## forces it — so its rows arrive as untyped Variants. Converted once here rather than cast at each of the
## five loops that walk a part's squares, because a missed cast in one of them is an index type that
## happens to work until it doesn't.
func slots_of(part: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if part < 0 or part >= Parts.NAME.size():
		return out
	for s in Parts.SLOTS[part]:
		out.append(int(s))
	return out


## 1 for a part in no slot (물기 and 짧은 숨 are never worn, so they never level). Otherwise the level
## written in the first slot it holds.
func part_level(part: int) -> int:
	if part < 0 or part >= Parts.NAME.size():
		return 1
	var slots := slots_of(part)
	if slots.is_empty():
		return 1
	var lv := slot_level[slots[0]]
	return lv if lv > 0 else 1


## What this part is currently adding to the host's force. **Used only to work out what to SUBTRACT when
## the part is digested** — force itself is stored on `swarm.force[0]`, never derived from this. Reading
## it as the host's force is the double-count that `force-is-stored-not-derived` names.
func part_force(part: int) -> int:
	if part < 0 or part >= Parts.NAME.size():
		return 0
	return int(Parts.FORCE[part]) + (part_level(part) - 1) * Rules.PART_LEVEL_FORCE


## Ten percent off per level, compounding. **Measured by firing twice and timing**, never by reading this
## — a net that calls this function and compares it to the same arithmetic proves the arithmetic.
func part_cooldown(part: int) -> float:
	if part < 0 or part >= Parts.NAME.size():
		return 0.0
	return float(Parts.COOLDOWN[part]) * pow(Rules.PART_LEVEL_COOLDOWN, float(part_level(part) - 1))


## True when this exact part is sitting in its own slots. A part with no slots is never worn.
func is_worn(part: int) -> bool:
	if part < 0 or part >= Parts.NAME.size():
		return false
	var slots := slots_of(part)
	if slots.is_empty():
		return false
	return slot_part[slots[0]] == part


func hp_max(level: int) -> int:
	var sum := Rules.HOST_HP + level * Rules.HP_PER_LEVEL
	for s in slot_part.size():
		var p := slot_part[s]
		# Guarded on the FIRST slot so a multi-slot part is counted once. Summed over every square it
		# holds, a two-slot mane would be worth twice its `Parts.HP` and nothing in the table would say so.
		if p >= 0 and int(Parts.SLOTS[p][0]) == s:
			sum += int(Parts.HP[p])
	return sum


func breath_max() -> float:
	var sum := Rules.BREATH_MAX
	for s in slot_part.size():
		var p := slot_part[s]
		if p >= 0 and int(Parts.SLOTS[p][0]) == s:
			sum += float(Parts.BREATH[p])
	return sum


# -- wearing --------------------------------------------------------

## Put `part` on the body. Returns the part ids that were DIGESTED to make room — not stored, not listed,
## not recoverable. **This game has no bag, only a body**, and every rule below follows from refusing to
## build an inventory.
##
## ⚠ **Force is written here and never derived.** `swarm.force[0]` moves up by the new part and down by
## every victim IN THIS SAME CALL. A derived bonus is either double-counted or a pure function nobody
## calls, and **the missing subtraction is the version that ships**: every overwritten part leaves ghost
## force behind, and `F` then multiplies it, and a check that only asserts the slot changed stays green
## through all of it.
##
## ⚠ **Current HP is NOT moved here.** `World.take_card()` does it, from the difference in `hp_max()`
## across this call — see `swarm`'s doc above for why `Body` may not hold a `World`.
func wear(part: int) -> Array:
	if part < 0 or part >= Parts.NAME.size():
		return []
	# Same part again: a level, not a replacement. **A level has to DO something** — it is worth
	# `PART_LEVEL_FORCE` and `PART_LEVEL_COOLDOWN`, both asserted with literals, because without a stated
	# effect the only thing a net can see is a number going up and a no-op stays green.
	if is_worn(part):
		for s in slots_of(part):
			slot_level[s] += 1
		if swarm != null:
			swarm.force[0] += Rules.PART_LEVEL_FORCE
		return []

	# Every DISTINCT part occupying any square this one wants. Distinct, because a multi-slot victim
	# occupying two of the claimed squares must be digested once, not twice — twice subtracts its force
	# and its HP twice and the host quietly goes negative.
	var digested: Array = []
	for s in slots_of(part):
		var old := slot_part[s]
		if old >= 0 and not digested.has(old):
			digested.append(old)
	for old in digested:
		var old_force := part_force(old)
		# **Evicted WHOLE.** A multi-slot part loses every square it held, not only the one that was
		# claimed; leaving the others pointing at it is a dangling index that reads fine and fires nothing.
		for s in slots_of(old):
			if slot_part[s] == old:
				slot_part[s] = -1
				slot_level[s] = 0
		if swarm != null:
			# **`maxi(0, ...)` is load-bearing, and it is the same floor `World::_roll_part` carries for a
			# clone** — see that function for why a row can go under. `F` halves a body's force but not the
			# `Parts.FORCE` column of what it wears, so a host split down to 1 that then takes a card sharing
			# a slot with a bigger part subtracts more than it has. Negative force is not a small wrong
			# number: `_damage_critter`'s own `maxi(0, amount)` turns every attack the host makes into a
			# **zero**, `F` refuses to split below 2, and there is no way back — the card that did it could
			# not be declined.
			swarm.force[0] = maxi(0, swarm.force[0] - old_force)
		# A binding pointing at a part that is no longer worn is the same dangling index one key over: the
		# panel shows a name, the key fires nothing, and reading the array in a net never sees it.
		for k in bound.size():
			if bound[k] == old:
				bound[k] = -1
				bound_cd[k] = 0.0

	for s in slots_of(part):
		slot_part[s] = part
		slot_level[s] = 1
	if swarm != null:
		swarm.force[0] += int(Parts.FORCE[part])
	_recompute_traits()
	return digested


## Placeholder trait, recomputed from what is worn. Counts HORSE parts, not parts — counting parts means
## any three of anything buys it, which is a different rule that nobody chose.
func _recompute_traits() -> void:
	var horse := 0
	for s in slot_part.size():
		var p := slot_part[s]
		if p >= 0 and int(Parts.SLOTS[p][0]) == s and int(Parts.SPECIES[p]) == Parts.Species.HORSE:
			horse += 1
	trait_horse = horse >= Rules.HORSE_TRAIT_COUNT


# -- binding --------------------------------------------------------

## Two refusals, and they are different sentences: `space` will not take a part that does not move you,
## and no key will take a part the body is not wearing. The panel reports which — one message for two
## refusals tells the player the wrong reason.
func can_bind(part: int, key: int) -> bool:
	if part < 0 or part >= Parts.NAME.size():
		return false
	if key < 0 or key >= KEY_COUNT:
		return false
	if Parts.KIND[part] != Parts.Kind.ACTIVE:
		return false
	if key == KEY_MOVEMENT and Parts.MOVEMENT[part] == 0:
		return false
	# 물기 and 짧은 숨 are worn nowhere and still bindable, because they are already in `bound` when the run
	# opens. Once one is overwritten out of every key it is GONE — that is the trade the design wants, and
	# it is what makes binding 말 다리 over `space` cost you the burst.
	return is_worn(part) or bound.has(part)


## Binding COPIES: the source keeps what it had, so one part can sit on two keys. What it does NOT copy is
## the part it landed on — an active overwritten out of its last key and worn nowhere is unreachable.
func bind(part: int, key: int) -> bool:
	if not can_bind(part, key):
		return false
	bound[key] = part
	bound_cd[key] = 0.0
	return true


# -- firing ---------------------------------------------------------

## **The only entry point for the three keys.** False when the key is empty, on cooldown, or the active
## itself refused. A key that does its own thing instead of coming through here is a fourth code path the
## panel's input gate would have to know about separately.
##
## ⚠ **A SUSTAINED active is not fired, it is HELD.** `fire()` returns false for one and the sustain runs
## off `held` in `step()` — 갤럽 has no cooldown and no edge, it has breath. Wiring it to the just-pressed
## edge produces a one-frame gallop, which reads exactly like a dead key.
func fire(key: int, aim: Vector2) -> bool:
	if key < 0 or key >= bound.size():
		return false
	var part := bound[key]
	if part < 0:
		return false
	if bound_cd[key] > 0.0:
		return false
	if swarm == null:
		return false
	match Parts.SHAPE[part]:
		Parts.Shape.ARC:
			if not swarm.bite(float(Parts.RANGE[part]), float(Parts.ARC[part]), aim):
				return false
			bound_cd[key] = part_cooldown(part)
			return true
		Parts.Shape.SELF:
			if Parts.SUSTAINED[part] == 1:
				return false
			if not swarm.begin_dash(float(Parts.SELF_MUL[part]), float(Parts.SELF_TIME[part])):
				return false
			bound_cd[key] = part_cooldown(part)
			return true
	return false


## Cooldowns, then the sustain. **Called by `World.step()` BEFORE `swarm.step()`**, because the speed
## multiplier this writes is what `_move_host()` reads that same frame; called after, the host spends
## every frame moving at the previous frame's speed and the gallop starts one frame late and ends one
## frame late — invisible, and wrong in both directions.
func step(dt: float) -> void:
	for k in bound_cd.size():
		bound_cd[k] = maxf(0.0, bound_cd[k] - dt)

	# Exactly one sustain runs at a time, and it is the fastest one held. Two movement parts on two keys
	# with both held is a state the player can reach; summing or multiplying their multipliers is a stacking
	# rule nobody chose, and taking the first held key makes the answer depend on key order.
	var run_part := -1
	var run_mul := 0.0
	for k in bound.size():
		var p := bound[k]
		if p < 0 or k >= held.size() or held[k] == 0:
			continue
		if Parts.SHAPE[p] != Parts.Shape.SELF or Parts.SUSTAINED[p] != 1:
			continue
		if float(Parts.SELF_MUL[p]) > run_mul:
			run_mul = float(Parts.SELF_MUL[p])
			run_part = p

	if run_part >= 0 and breath > 0.0:
		if swarm != null:
			swarm.active_speed_mul = run_mul
		# 말 특성, the whole of it: the trait does not make you faster, it makes the gallop free.
		if not trait_horse:
			breath = maxf(0.0, breath - dt)
		return

	if swarm != null:
		swarm.active_speed_mul = 1.0
	if run_part >= 0:
		# **Held, and out of breath: nothing regenerates until the key comes up.** Regenerating here is the
		# obvious reading and it flutters: `breath` goes to 0, one frame of regen puts it back above 0, the
		# next frame the sustain runs again and drains it — so the host alternates between 1.8× and 1.0×
		# every frame forever, averaging well above base. "Held past breath_max drops back to base" is then
		# false for the rest of the hold, and a net timing per-frame travel sees a stutter rather than a
		# stop. Releasing the key is what buys the recovery.
		return
	breath = minf(breath_max(), breath + Rules.BREATH_REGEN * dt)
