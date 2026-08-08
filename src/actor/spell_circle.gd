extends RefCounted
## One assembled magic circle — **the single source of the equipped state.**
##
## The debug keys and (in future) the assembly window both touch **this one object.** If each held its own
## state you get "I pressed the key but the muzzle did not change" and **not one error is raised.**
##
## ```
##    debug keys 1-5 --> set_from_packed()
##                           SpellCircle --> muzzle drawing (`character_view` **reads** it)
##    assembly click --> set_circle()      |-> HUD
##                       set_rune()        \-> fire command (can_fire · element · packed_glyphs)
##                       place_glyph()
## ```
##
## **It holds no coordinates.** Coordinates are the screen's job — `src/actor/` allows floats, so a `Vector2`
##  coming in **would not make the nets bark**, and from then on the assembly rules and the drawing become one lump.
##
## **Why not `src/sim/`**: the assembly state is not deterministic state running every tick. The grid and the
##  projectiles are lockstep, but **the player's loadout is host-authoritative** (GDD multiplayer table).
##
## **The constraints are not written here.** It only **reads** `glyph_defs.DEFS` — write them separately and
##  the rule has two copies, and the assembly window lets through a placement that `spell_sim.fire()` blocks.
##  That state only ever looks like "I press it and nothing happens".
##
## **The functions were not merged because the placement rule differs per kind** — a circle is always placed
##  (it clears the layers), a rune is always placed, and only a glyph looks at `max_per_circle`. Merge them
##  with one `slot_kind` switch and that switch grows every time rune slots and circles grow, and the three
##  axes get stuck back together inside it.

const CircleDefs := preload("res://src/sim/circle_defs.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")

## **The empty rune slot. This is the single source** — the view reads this constant too.
##
## **Why not 0**: `sim_tuning.ELEM_FIRE` is already 0. Use 0 as the empty value and **an empty rune slot reads
##  as the fire rune**, so the assembly window draws a blank while firing sends fire.
##  **Not one error is raised.** Only circles (`CIRCLE_NONE`) and glyphs (`GLYPH_NONE`) can use the 0 discipline.
##
## **Why not `src/sim/`**: the sim does **not know** about an empty rune. With an empty rune no command is made
##  at all. A constant with no consumer in sim would itself be a false knob.
## A net measures that **this value is not inside `ELEM_ALL`** — that one line pins the trap above as a contract.
const RUNE_EMPTY := -1

## **The default issue** (GDD, "default issued circle: round, 2 layers").
##  **The starting state and the presets come only from these two** — write them in two places and they diverge,
##  and then something like "a fresh launch is fire but pressing key 1 gives a different rune" appears
##  **with no error.**
const DEFAULT_CIRCLE := CircleDefs.CIRCLE_ROUND
const DEFAULT_RUNE := Tuning.ELEM_FIRE

var _circle_id := CircleDefs.CIRCLE_NONE
## The innermost is index 0 (= layer 1). `GLYPH_NONE` = an empty layer.
var _layers: Array[int] = []
## `RUNE_EMPTY` = an empty slot.
var _runes: Array[int] = []


func _init(circle_id: int = DEFAULT_CIRCLE) -> void:
	set_circle(circle_id)
	# **The starting state has the circle and the rune filled in.** Boot with an empty rune and the game
	#  starts in a "cannot fire" state, and that reads as a malfunction.
	for slot in _runes.size():
		set_rune(slot, DEFAULT_RUNE)


func circle_id() -> int:
	return _circle_id


func layer_count() -> int:
	return _layers.size()


func rune_count() -> int:
	return _runes.size()


func glyph_at(layer: int) -> int:
	if layer < 0 or layer >= _layers.size():
		return Glyph.GLYPH_NONE
	return _layers[layer]


func rune_at(slot: int) -> int:
	if slot < 0 or slot >= _runes.size():
		return RUNE_EMPTY
	return _runes[slot]


# ══════════════════════════════════════════════════════════════════
#  Placing — **the rule differs per kind**
# ══════════════════════════════════════════════════════════════════

## Places a circle. **It is always placed** — circles have no constraint, so there is no `can_place_circle`
##  (that would be a false knob).
##
## Layer counts differ per circle, so `_layers` and `_runes` **change length at runtime.** With only one kind
##  of circle it does not show today, but write a model that cannot express it and you rebuild the model the
##  day there are two circles.
##
## **Changing the circle clears all layers and rune slots.** Keep the front ones and drop only the overflow and
##  **the last glyph silently disappears.** Clearing wholesale changes the drawing wholesale, so **it is visible.**
func set_circle(id: int) -> void:
	# **Placing the same circle again does nothing** — otherwise one accidental extra click wipes the whole assembly.
	if id == _circle_id:
		return
	_circle_id = id
	_layers.resize(CircleDefs.layers(id))
	_layers.fill(Glyph.GLYPH_NONE)
	_runes.resize(CircleDefs.rune_slots(id))
	_runes.fill(RUNE_EMPTY)


## Places a rune (`RUNE_EMPTY` removes it). **It is always placed** — runes have no constraint either.
##
## **An unknown rune is not accepted.** Accept it and `can_fire()` lets it through and `spell_sim.fire()`
##  barks at the command boundary, and by then the screen already shows "I left-clicked and nothing happened".
func set_rune(slot: int, rune_id: int) -> bool:
	if slot < 0 or slot >= _runes.size():
		return false
	if rune_id != RUNE_EMPTY and not Tuning.ELEM_ALL.has(rune_id):
		push_error("SpellCircle: unknown rune %d - not placing it" % rune_id)
		return false
	_runes[slot] = rune_id
	return true


## Can this glyph go on this layer. **The reason `can_place_*` exists only for glyphs** is that the constraint
##  exists only for glyphs — make check functions for circles and runes and they become false knobs that always
##  return true.
##
## **Failing after you fire reads as a malfunction** (design: "extreme values"). So the constraint has to show
##  at **assembly time**, not at firing time. The validation in `spell_sim.fire()` still stays —
##  the network does not go through the assembly window. The two checks guard different things and **read the
##  same table.**
func can_place_glyph(layer: int, glyph_id: int) -> bool:
	if layer < 0 or layer >= _layers.size():
		return false
	# Removing is always allowed. Make removal a different path and you get "placing is blocked but removing breaks the state".
	if glyph_id == Glyph.GLYPH_NONE:
		return true
	return _list_ok(_with(layer, glyph_id))


## Places a glyph (`GLYPH_NONE` removes it). false if it cannot be placed — **silently.**
## It must not bark here. Not being able to place is **normal operation** (showing the palette greyed out is
##  stage 4's job), and barking makes one click turn the wrapper's stderr check red.
func place_glyph(layer: int, glyph_id: int) -> bool:
	if not can_place_glyph(layer, glyph_id):
		return false
	_layers[layer] = glyph_id
	return true


## **It builds the post-placement list in advance and measures that.** Count only "how many of this glyph are
##  there now" and an overwrite (that layer already has spread and you place spread on the same layer again)
##  gets counted once too many, **blocking something that is placeable.**
func _with(layer: int, glyph_id: int) -> Array[int]:
	var out: Array[int] = []
	for i in _layers.size():
		var id: int = glyph_id if i == layer else _layers[i]
		if id != Glyph.GLYPH_NONE:
			out.append(id)
	return out


## **The point where the rule has one copy.** `can_place_glyph` and `set_from_packed` call **this same
##  function** — measure separately and you get placements that "go in via a preset but cannot be placed by clicking".
## The point is that not one rule is written here. Everything is read from `glyph_defs.DEFS`.
static func _list_ok(list: Array[int]) -> bool:
	if list.size() > Tuning.GLYPH_MAX_LAYERS:
		return false
	for id: int in list:
		if not Glyph.DEFS.has(id):
			return false
		var cap := int(Glyph.DEFS[id]["max_per_circle"])
		# **Counted by family, not by exact id** — the same reading as `spell_sim._valid_glyphs`, and it has to
		#  read the table the **same** way: common-spread and rare-spread are two ids in one family, and letting
		#  the assembly window place both while `fire()` blocks them is exactly "a buildable-looking circle that
		#  cannot actually fire" (`_both_ways_agree`'s whole reason to exist).
		#  **0 = unlimited.** It is not even counted.
		if cap > 0 and _count_family(list, Glyph.family_of(id)) > cap:
			return false
	return true


## `Glyph.count_family` walks a packed integer; this is the same count over a plain `Array[int]` — the shape
##  `_list_ok` already holds its working list in, before it is ever packed.
##
## **Skips ids not in `DEFS` instead of dereferencing them — the same guard as `Glyph.count_family`, for the
## same reason.** `_list_ok`'s own loop only validates ids **before** the one it is currently checking; the cap
## check for an early, valid id calls this over the **whole** list, including ids further along that have not
## been validated yet. `[SPREAD_C, an unknown id]` reaches `Glyph.family_of` on that unknown id with no guard
## here — measured: it does not raise a catchable error, it silently coerces the crashed comparison into
## matching `FAMILY_SPREAD`, so an unguarded count comes back **2**, not 1, for exactly that list. An id this
## function skips is still caught — `_list_ok`'s own loop reaches it next and its `not Glyph.DEFS.has(id)`
## check rejects the placement.
static func _count_family(list: Array[int], family: int) -> int:
	var n := 0
	for id: int in list:
		if Glyph.DEFS.has(id) and Glyph.family_of(id) == family:
			n += 1
	return n


# ══════════════════════════════════════════════════════════════════
#  Can I fire — one empty rune slot and you cannot
# ══════════════════════════════════════════════════════════════════

## ```
## can_fire()  =  there is a circle  &&  there is not one empty rune slot
## ```
##
## **Glyphs are optional and a rune is required.** It is already contained in the sentence the design's
##  "extreme values" wrote: "empty both layers and fire and it must fire — **a circle plus a rune alone**
##  makes a spell".
##
## **Because there is only one rune slot, "all must be filled" and "any one filled is enough" currently give
##  the same answer.** They diverge the day there are several rune slots (with a parallel circle, filling 2 of
##  3 firing 2 bolts is natural).
##  **That gets settled then.** What was chosen now is "all must be filled", and writing it down is the point.
func can_fire() -> bool:
	if _circle_id == CircleDefs.CIRCLE_NONE:
		return false
	for rune_id: int in _runes:
		if rune_id == RUNE_EMPTY:
			return false
	return true


## The rune the fire command uses.
## **It only has meaning when `can_fire()` is true** — with an empty slot the command is never made at all.
## **The assumption that there is one rune slot lives only in this one place.** Grow the circles without
##  settling how several runes combine (fusion, parallel, sequential) and you get caught for free by the
##  wrapper's stderr check — the circle table does not even have a column for it yet.
func element() -> int:
	if _runes.size() != 1:
		push_error("SpellCircle: there are %d rune slots - firing still knows only one" % _runes.size())
		return Tuning.ELEM_FIRE
	return _runes[0]


# ══════════════════════════════════════════════════════════════════
#  list <-> integer
# ══════════════════════════════════════════════════════════════════

## **Empty layers are skipped.** Pack them as is and glyphs **vanish with no error**:
##
## ```
## layer 1 empty · layer 2 blast  ->  packing as is gives g = GLYPH_NONE | (BLAST << 4)
##                                    but GLYPH_NONE = 0 means "end of list"
##                                    first(g) = 0  ->  the bolt flies carrying an **empty list**
## ```
##
## => It only looks like "putting something on layer 2 alone does nothing". An empty layer does nothing, so
## skipping is the rule, and "empty both layers and fire and it must fire" (design: "extreme values") falls
## straight through the **path that already exists**, `g == 0`.
func glyph_list() -> Array[int]:
	var out: Array[int] = []
	for id: int in _layers:
		if id != Glyph.GLYPH_NONE:
			out.append(id)
	return out


## **The shifting is not done here** — the three functions in `glyph_defs` are the only place that shifts
##  (that file's comment: shift in two places and they will diverge).
## The muzzle calls this on every `_draw()`, so the cost of building one array is **paid on purpose.**
##  Save it by shifting directly and at that moment the rule has two copies.
func packed_glyphs() -> int:
	return Glyph.pack(glyph_list())


## **The preset — it places the circle, the rune and the glyphs at once. The order is trapped inside this function.**
##
## ```
## circle -> rune -> glyph      <- it must be this order
## ```
##
## **Reverse it and the circle clears the glyphs after they were filled in** (`set_circle` clears every layer).
##  **Not one error is raised** — you press the key and get a magic circle with no glyphs.
## So instead of the call sites knowing the order, it is **trapped here in one place.** Let each call site write
##  the three lines and one of them will certainly be wrong.
##
## **Why the debug keys also place the circle and the rune**: so that a user who removed the circle **is not
##  trapped.** If the preset only placed glyphs, all five keys would be dead with no circle and the only way out
##  would be the assembly window. => Placing the circle too makes **key 1 an assembly reset.**
## The rune is filled into **every slot with the same value** — with one kind of rune that has a single meaning
##  today. **The day there are several kinds of rune, the preset has to take a rune list.**
func apply_preset(circle_id: int, rune_id: int, packed: int) -> bool:
	set_circle(circle_id)
	for slot in _runes.size():
		set_rune(slot, rune_id)
	return set_from_packed(packed)


## **The door the debug keys come in through.** It fills densely from the front layer —
##  key 3 (one blast) gives layer 1 blast, layer 2 empty. The round trip is a contract:
##  after `set_from_packed(g)`, `packed_glyphs() == g`.
##
## **It changes only the glyphs** — the circle and the rune are not touched. A preset is "which glyph
##  combination", not the whole loadout.
##
## **An unplaceable arrangement barks and is not accepted.** Accept it and you get a state that
##  "cannot be placed by clicking but goes in via the preset", and `fire()` rejects that state's
##  `packed_glyphs()`, so on screen it only looks like **"I press it and nothing happens"**.
func set_from_packed(g: int) -> bool:
	# A negative number **loops forever.** `rest` is an arithmetic shift so `-1 >> 4 == -1`, and the while
	#  below never ends, freezing the whole frame (with no error). `Glyph.pack` never emits a negative, but
	#  this function is the door that takes an integer as is.
	if g < 0:
		push_error("SpellCircle: negative list %d - not accepting it" % g)
		return false

	var list: Array[int] = []
	var cur := g
	while cur != Glyph.GLYPH_NONE:
		list.append(Glyph.first(cur))
		cur = Glyph.rest(cur)

	if list.size() > _layers.size():
		push_error("SpellCircle: cannot put %d glyphs into a %d-layer circle" % [
			list.size(), _layers.size()])
		return false
	if not _list_ok(list):
		push_error("SpellCircle: list %s hits a glyph constraint" % [list])
		return false

	# **Clear everything first.** Without clearing, pressing key 3 (one layer) after key 4 (two layers) leaves
	#  the previous glyph on layer 2, giving "I took it out but it did not come out".
	_layers.fill(Glyph.GLYPH_NONE)
	for i in list.size():
		_layers[i] = list[i]
	return true
