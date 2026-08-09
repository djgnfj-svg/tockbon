extends Node2D
## Monsters, chicken bolts, and death sites. It touches the screen only — the world is **read** from `WorldStep`.
##
## Having no interpolation is correct — monsters run at 60Hz (the same clock as rendering), so there is nothing
##  between ticks (the same reason as `character_view.gd`'s first line).
##
## **Death notifications (`world.died_*`) are valid only within that tick** (the next tick clears them — the same
##  contract as blast notifications, `world_step.gd` header). => **Corpses are caught in `on_tick()`, not in
##  `_process()`** (the same door as `blast_fx.on_blasts()` — `stage.gd`'s `_on_ticked()` calls it).
##  Otherwise it is read only after the next tick has cleared the notification, so corpses cannot exist in principle.
##
## **Flashes and damage numbers do not add a new notification to the actor — the view observes hp every frame
##  and makes them.** hp is already a public field, and **ids are never reused**
##  (`world_step._next_monster_id` comment), so **keying by id makes the diff safe** — the same idiom as
##  `character_view._prev_x` (comparing against the previous frame). **It is different from diffing an id list to
##  find "who died"** — that is a problem `world_step` already solved with notification arrays (the trap under
##  "behavior (10)" above), and what is diffed here is only "did a living monster of the same id lose hp",
##  so the reuse and teleport traps do not bite.
## **One seat it cannot catch**: the last damage on the very tick a monster dies is not seen by this diff,
##  because the monster is already out of the array — on that frame the corpse appears with no flash and no
##  number. A place of no certainty (reported below).

const WorldStep := preload("res://src/actor/world_step.gd")
const Monster := preload("res://src/actor/monster.gd")
const Defs := preload("res://src/actor/monster_defs.gd")
const Fx := preload("res://src/view/fx_tuning.gd")
## `stage1-bosses.md` Stage B's screen share - the wind-up/stun indicator reads `m.pattern`, whose values
## live here (`BossAi.Pattern`). Same allowance as `MonsterDefs`/`SpellCircle` in `fx_tuning.gd`'s header.
const BossAi := preload("res://src/actor/boss_ai.gd")
## Stage D - only `KIND_FIRE` is read here, to pick the fire bolt's color.
const MonsterBolts := preload("res://src/actor/monster_bolts.gd")
## **It is held for `CELL_PX` alone** — fire attached to a body has to snap to the cell grid for its vocabulary
##  to match the ground fire (the `_draw_body_flames` box). This is the only place the view reads a sim constant.
const Tuning := preload("res://src/sim/sim_tuning.gd")
## The attack prediction (`docs/design/attack-prediction.md`) needs the live player position (to track until
## the windup lock, `_draw_attack_prediction`'s own header) and the grid (to find the wall a charge lane would
## actually stop at). Neither was needed before this feature — `character.gd`'s `H_PX`/`W_PX`/`GRAVITY_PX` are
## also read here now, for the same reason `cell_renderer.gd` reads one sim constant and no more.
const Character := preload("res://src/actor/character.gd")
const CellGrid := preload("res://src/sim/cell_grid.gd")

## **Which kinds attack by touching, rather than by a pattern or a projectile.** Read by `_is_attacking`;
##  its own header says why this is a list.
const CONTACT_ATTACKERS: Array[int] = [Defs.KIND_PIG, Defs.KIND_WOLF]

## The name the shader receives. **Kept as a constant** — pin the string and one wrong letter means
##  **nothing happens at all and there is no error** (`net_render`'s "false knob" section is that story).
const FLASH_COLOR_PARAM := "flash_color"

## **Layer names — the nets find them by these. Do not find them by child index.**
##  **Measured**: a net was grabbing the flash layer with `get_child(0)`, and putting the outline layer in
##   front of it made it **quietly start measuring the wrong node.**
##   => Order is a drawing contract, **not a name tag.** A net must not break every time a layer is added.
const LAYER_OUTLINE := "Outline"
const LAYER_FLASH := "Flash"
const LAYER_NUMBER := "Number"

var _world: WorldStep = null
## **The live player and grid — `_draw_attack_prediction`'s own reason.** Both are null-tolerant at the call
## site: the only door that reaches a drawing function with either unset is a net driving `_draw_pattern_
## indicator`/`_draw_attack_prediction` directly with no `setup()` (`net_monster_charge.gd`'s dispatch test
## does exactly this) — real play always calls `setup()` first, the same discipline `_world` above already holds.
var _char: Character = null
var _grid: CellGrid = null

## id -> previous frame's hp. `_scan_hp_changes()` fills and clears it (the header above).
var _prev_hp: Dictionary = {}
## id -> remaining flash frames.
var _flash_left: Dictionary = {}

## Damage numbers and corpses — **independent entities** (they stay on screen for a while after the monster is gone).
##  The same idiom as `blast_fx._flashes`: `Array[Dictionary]` plus an age in frames.
var _dmg_numbers: Array[Dictionary] = []
var _corpses: Array[Dictionary] = []
## The ring that pops at the moment of death. **It is born from the same notification as the corpse but has a
##  different lifetime** (shorter) — so the two cannot share one array (`_prune` takes a lifetime per array).
var _death_pops: Array[Dictionary] = []

## Kind -> body sprite. Built from `Defs.ALL` — growing the kinds (one line in `monster_defs.gd` plus one line
## in `fx_tuning.MONSTER_SHEETS`) needs no edit here.
## **No `null` check is attached — instead the reading side substitutes with `.get()`** (`_draw_monster_body`).
##  A different discipline from `character_view._body_tex`: there is only one character, so barking when it
##  breaks is fine, but monsters always have several kinds and the rest must still show when one breaks
##  (the `MONSTER_FILL` box above).
var _sheets: Dictionary = _load_sheets()

## kind -> state -> the sheet for that state. Built from `Fx.MONSTER_ANIM` — the same "no registry here"
##  discipline as `_sheets` above, and the same substitute-do-not-bark rule (a missing row falls back through
##  `anim_row`, a failed `load` falls back to `_sheets`).
var _anim_sheets: Dictionary = _load_anim_sheets()

## id -> {"state": int, "t": int}. **The single source of "which frame is this monster on".**
##  Body, flash and outline are drawn onto three different canvases and must land on the **same** cell of the
##  same sheet — computed once per frame here, read three times when drawing. Recompute it inside each
##  drawing function and the day the three disagree, a hit pig's white silhouette is one frame behind its own
##  body, which is visible on screen only (the exact shape of the bug `_draw_flipped` was gathered to prevent).
var _anim: Dictionary = {}
## id -> previous frame's x. "Is it walking" is asked of the previous frame, not of the monster —
##  `monster.gd` has no such field and adding one would edit `src/actor/` from a file whose whole contract is
##  "it touches the screen only" (the same reasoning, verbatim, as `character_view._prev_x`).
var _prev_x: Dictionary = {}
## id -> previous frame's `reload_left`. **The hen's shot has no notification** — the only trace it leaves is
##  that field jumping back up to its reload value (`monster.consume_fire()`), so the view diffs it, exactly
##  as it already diffs hp to find a hit. Rising means "it just fired".
var _prev_reload: Dictionary = {}
## id -> frames left of a latched one-shot. **A latch, not a live condition**: the hen fires on one tick and
##  the spit sheet runs 8 frames, so asking "is it firing right now" would show a single frame of it.
var _attack_left: Dictionary = {}
## id -> the previous frame's `asleep`. **The stir has no notification** — `world_step` writes
## `Monster.asleep` straight onto the monster once a tick, so the only trace a stir leaves is this field
## going true -> false, exactly the way `_prev_reload` catches the hen's shot.
## **A monster seen for the first time never fires a mark**: the lookup defaults to *its own current*
##  value, so a debug-key spawn (which never sleeps at all) does not pop a ring the frame it appears.
##  That is `character_view.setup()`'s `_prev_x` alignment, applied to a bool.
var _prev_asleep: Dictionary = {}
## The wake marks — **independent entities**, the same idiom and the same reason as `_death_pops`: the
## monster walks away immediately, and the mark belongs to the spot where it stirred.
## **`age` starts negative** — that is the stagger (`Fx.MONSTER_WAKE_STAGGER_FRAMES`). `_prune` counts it
##  up like any other age, and the drawing side skips anything still below zero.
var _wake_marks: Array[Dictionary] = []
## id -> frames left of the hurt animation. **Separate from `_flash_left`, deliberately.** The flash is 6
##  frames (matched to invulnerability, `MONSTER_FLASH_FRAMES`'s own comment) and the hurt sheet is 12; driven
##  off the flash, the animation would be cut at frame 2 of 4 and never once reach its last cell.
var _hurt_left: Dictionary = {}

## Frame counter — the clock for the wobble of fire attached to a body.
## **`Time.` is not used.** This is `src/view/` so it is outside the determinism contract, but as a frame counter
##  a net can call `advance()` N times and **reproduce the same picture** (a wall clock cannot).
var _frame: int = 0

## **A child node dedicated to the flash.** The shader material is **per node**, so everything drawn here
##  becomes a white silhouette => **it cannot sit on the same node as the body.**
##  Being a child, it is drawn **after** the parent = laid on top of the body. That is the order needed.
var _flash_layer: Node2D = null
## Damage numbers go above even the flash — otherwise the flash covers the numbers (both being whitish is
## the worst case).
var _number_layer: Node2D = null
## **The outline goes "below" the body — it is a child pushed behind with `show_behind_parent`.**
##  A child is above the parent by default, and an outline covering the body makes **the whole silhouette cream.**
##  It hangs **the same shader with a different color** as the flash — the color is a per-node uniform, so the
##   nodes have to be split.
var _outline_layer: Node2D = null


## A shell delegating drawing to child nodes. **The point is to avoid making a script file per child** —
##  more files scatter "what does this node do" across three places.
##
## **It is `fn.call(self)` — it passes itself. That is half this class's reason to exist.**
##  **A real bug happened when it was called with no argument**: the delegated function drew onto
##   **the implicit `self` (= the parent MonsterView)**, and the parent was not drawing, so
##   **that command was silently discarded.** Damage numbers disappeared from the screen wholesale with
##   **no error and every net green** (nets read arrays, not the canvas).
##  => Forcing the canvas as an argument makes **the receiving side not using it visible.**
class _Layer extends Node2D:
	var fn: Callable

	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)


## static — so a net can verify the values even before `_init` runs (`net_monster_sprite`).
static func _load_sheets() -> Dictionary:
	var out: Dictionary = {}
	for kind: int in Defs.ALL:
		out[kind] = load(Fx.MONSTER_SHEETS[kind]) as Texture2D
	return out


## static — same reason as `_load_sheets`: `net_monster_sprite` measures the table before any node exists.
## **Every path in `Fx.MONSTER_ANIM` is loaded once, at construction.** Loading per frame would re-open a
##  sheet 60 times a second for every monster on screen; `load()` is cached by the engine, but relying on that
##  cache is relying on something no net can see.
static func _load_anim_sheets() -> Dictionary:
	var out: Dictionary = {}
	for kind: int in Defs.ALL:
		var rows: Dictionary = Fx.MONSTER_ANIM.get(kind, {})
		var per_state: Dictionary = {}
		for state: int in rows:
			per_state[state] = load(rows[state]["path"]) as Texture2D
		out[kind] = per_state
	return out


## **The layers are created here — not put in the scene file.**
##  A net sometimes stands this node up with `new()` and no scene and only pushes `advance()` through
##   (the reason those are public functions), and then `_ready` does not run and the layers **live as null.**
##   => **The drawing side must tolerate null.**
##  Pin them in the scene file and those two worlds diverge, and the divergent symptom shows up **on screen only.**
func _ready() -> void:
	var sh := load(Fx.MONSTER_FLASH_SHADER) as Shader
	# **The outline is created first** — child order is drawing order, and this is the only one with
	# `show_behind_parent`.
	_outline_layer = _make_layer(_draw_outlines, LAYER_OUTLINE)
	_outline_layer.show_behind_parent = true
	_paint(_outline_layer, sh, Fx.MONSTER_OUTLINE_COLOR)
	_flash_layer = _make_layer(_draw_flashes, LAYER_FLASH)
	_paint(_flash_layer, sh, Fx.MONSTER_FLASH_COLOR)
	# **With no shader it goes without a material** — then the flash becomes its old shape (a white rectangle)
	#  and the outline is **the body sprite itself laid down eight times**, smeared. **It still does not bark**:
	#  this file's discipline is "on the monster side, substitute and do not bark" (`_load_sheets`).
	_number_layer = _make_layer(_draw_numbers, LAYER_NUMBER)


## Hangs the silhouette shader on a layer and puts the color in.
## **The color is a per-node uniform, so putting it in once here is enough** — every monster is the same color.
##  **The strength cannot go in** (it differs per monster) — the drawing side passes it as modulate alpha.
func _paint(layer: Node2D, sh: Shader, color: Color) -> void:
	if sh == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter(FLASH_COLOR_PARAM, color)
	layer.material = mat


func _make_layer(fn: Callable, nm: String) -> Node2D:
	var n := _Layer.new()
	n.fn = fn
	n.name = nm   # the nets find it by this name (the box above) — indices drift as layers are added
	add_child(n)
	return n


## **`char`/`grid` are new, and optional** (`docs/design/attack-prediction.md`) — the same door
## `char_view.setup(_char, _circle, _grid)` already opened for a different reason (`stage.gd`'s own precedent
## for handing a view more than one actor reference directly, rather than reaching through `world`, which
## exposes neither). **Defaulting to `null` rather than becoming required** keeps every existing call site
## that has no reason to care about the attack prediction (damage numbers, corpses, flashes) unchanged —
## `_draw_attack_prediction`'s own header names this the same null-tolerant discipline `_world` already holds.
func setup(world: WorldStep, char: Character = null, grid: CellGrid = null) -> void:
	_world = world
	_char = char
	_grid = grid
	queue_redraw()


func _process(_dt: float) -> void:
	advance()
	queue_redraw()
	# Children **do not receive** the parent's `queue_redraw()`. Without calling it, the flash and the numbers
	#  freeze on the first frame, and the only symptom is "it does not flash when hit".
	for layer: Node2D in [_outline_layer, _flash_layer, _number_layer]:
		if layer != null:
			layer.queue_redraw()


## One frame's update — reads hp changes to make flashes and damage numbers, and ages the living presentations.
## **The same function `_process` calls** (the same idiom as `blast_fx.advance()`) — public so a net can push
## frames through with no scene.
##
## **Aging comes first and reading hp comes second.** Reverse the order and a flash or damage number created
##  this frame **loses one frame's worth inside the same call** — it was caught by measurement as a
##  `MONSTER_FLASH_FRAMES` (6) flash already going out after 5 frames (net failure).
func advance() -> void:
	_frame += 1
	_decay_flashes()
	_prune(_dmg_numbers, Fx.MONSTER_DMG_NUM_LIFE_FRAMES)
	_prune(_corpses, Fx.MONSTER_CORPSE_LIFE_FRAMES)
	_prune(_death_pops, Fx.MONSTER_DEATH_POP_FRAMES)
	_prune(_wake_marks, Fx.MONSTER_WAKE_MARK_FRAMES)
	_decay(_attack_left)
	_decay(_hurt_left)
	if _world != null:
		_scan_hp_changes()
		# **After the hp scan, never before.** `_scan_hp_changes` is what sets `_hurt_left`, so running this
		#  first would show the hurt pose one frame late — the same one-frame ordering bug the "aging comes
		#  first" note above records, found the same way (by measurement).
		_scan_anim()
		_scan_wake()


## **Death notifications are read only here.** `stage.gd`'s `_on_ticked()` calls it — call it every frame and
##  the notification is still alive by the next `frame()`'s tick branch, so corpses get created several times
##  (the same seat as the "one hit becomes three" trap in `world_step.frame()`).
func on_tick() -> void:
	if _world == null:
		return
	for i in _world.died_count():
		var d := {
			"x": _world.died_x(i), "y": _world.died_y(i), "kind": _world.died_kind(i), "age": 0,
		}
		_corpses.append(d)
		# **It pops at the moment of death — this is the chicken's only hit feedback**
		#  (`fx_tuning.MONSTER_DEATH_POP_FRAMES`).
		#  A chicken dies in one hit, so what `_scan_hp_changes`'s hp diff would look at is **already out of
		#   the array.** => Neither flash nor number shows for even one frame. **Only the death notification
		#   knows that moment.**
		#  **It is created from the same notification as the corpse** — hang it separately and a combination of
		#   "there is a corpse but no pop" can appear, which means the two paths diverged and it is visible
		#   on screen only.
		_death_pops.append(d.duplicate())


## Puts up a flash and a damage number for each monster whose hp dropped. Diffed by id (the header above).
func _scan_hp_changes() -> void:
	var seen: Dictionary = {}
	for i in _world.monster_count():
		var m: Monster = _world.monster_at(i)
		seen[m.id] = true
		if _prev_hp.has(m.id):
			var prev: int = _prev_hp[m.id]
			if m.hp < prev:
				_flash_left[m.id] = Fx.MONSTER_FLASH_FRAMES
				_hurt_left[m.id] = oneshot_frames(m.kind, Fx.MON_HURT)
				_add_dmg_number(m, prev - m.hp)
		_prev_hp[m.id] = m.hp
	# ids that no longer live are cleaned up — without erasing them, dead ids pile up in the dictionary forever
	#  (the cap of 20 applies only to living monsters, and this dictionary is outside that cap).
	for id in _prev_hp.keys().duplicate():
		if not seen.has(id):
			_prev_hp.erase(id)
			_flash_left.erase(id)


## One frame of every living monster's animation state. **Three questions and one clock.**
##
## **The state is re-decided every frame; only the clock is remembered.** `_anim[id]["t"]` restarts at 0 the
##  frame the state changes and counts up otherwise — that is the whole machine, and it is what makes
##  `loop: false` mean "play once and hold" without a second field saying whether it has finished.
##
## **Walking is diffed against the previous frame's x** (`_prev_x`), the same idiom and the same reason as
##  `character_view._prev_x`. **The first frame a monster is seen counts as not moving** — `_prev_x` has no
##  entry yet, and reading a missing entry as 0 would make every spawn walk for one frame from x=0 to its
##  spawn seat, which is exactly the bug `character_view.setup()` aligns `_prev_x` to avoid.
func _scan_anim() -> void:
	var seen: Dictionary = {}
	for i in _world.monster_count():
		var m: Monster = _world.monster_at(i)
		seen[m.id] = true
		var moving := _prev_x.has(m.id) and int(_prev_x[m.id]) != m.x
		_prev_x[m.id] = m.x
		# **The hen's shot leaves no notification — only `reload_left` jumping up** (the field's own box above).
		var prev_reload := int(_prev_reload.get(m.id, 0))
		if m.reload_left > prev_reload:
			_attack_left[m.id] = oneshot_frames(m.kind, Fx.MON_ATTACK)
		_prev_reload[m.id] = m.reload_left
		var state := resolve_state(m.kind, m.pattern, m.on_ground, _hurt_left.has(m.id), _is_attacking(m), moving)
		var cur: Dictionary = _anim.get(m.id, {})
		if int(cur.get("state", -1)) != state:
			_anim[m.id] = {"state": state, "t": 0}
		else:
			cur["t"] = int(cur["t"]) + 1
	# Dead ids are dropped — the same cleanup, and the same reason, as `_prev_hp` above (ids are never reused,
	#  so nothing here can be resurrected by a later monster; without erasing, these grow without bound).
	for id in _anim.keys().duplicate():
		if not seen.has(id):
			_anim.erase(id)
			_prev_x.erase(id)
			_prev_reload.erase(id)
			_attack_left.erase(id)
			_hurt_left.erase(id)


## One frame of "who just stirred". **`asleep` true -> false, per id** (the `_prev_asleep` box above).
##
## **The delay is assigned in world-array order within this one frame**, which is spawn order, which is
##  row order in `stage1_monsters.ROWS` — the doc's "staggered by row index" with no new field on
##  `Monster` and no reach into `MonsterPlacement` from a file whose whole contract is the screen.
##  **A whole clump stirring on one tick is the ordinary case**, not the rare one: `world_step`'s sleep
##  pass walks every monster inside a single tick.
func _scan_wake() -> void:
	var seen: Dictionary = {}
	var wave := 0
	for i in _world.monster_count():
		var m: Monster = _world.monster_at(i)
		seen[m.id] = true
		# Defaulting to the monster's own value is what makes the first sighting silent (the field's box).
		var was := bool(_prev_asleep.get(m.id, m.asleep))
		if was and not m.asleep:
			_wake_marks.append({
				"id": m.id, "kind": m.kind, "x": m.x, "y": m.y,
				"age": -wave * Fx.MONSTER_WAKE_STAGGER_FRAMES,
			})
			wave += 1
		_prev_asleep[m.id] = m.asleep
	# Dead ids are dropped — the same cleanup, and the same reason, as `_prev_hp`/`_anim` above.
	for id in _prev_asleep.keys().duplicate():
		if not seen.has(id):
			_prev_asleep.erase(id)


## **Is this monster hitting the player right now.**
##
## **Two different answers, because the two mobs leave two different traces.** The hen fires on one tick and
##  the view latched it above (`_attack_left`). **The pig has nothing at all** — it damages by body contact
##  (`world_step`'s own `_boxes_overlap` on every tick), so there is no event, only a condition, and the view
##  asks the same question `MONSTER_SHOVE_REACH_PX` early.
##
## **`_char == null` means no shove, never a crash** — a net driving this node with no `setup()` is the only
##  door that reaches here without a player, the same null-tolerant discipline `_world` holds.
## **Bosses are excluded** — a bull's attacks are patterns, resolved before this is ever consulted
##  (`resolve_state`'s own order), and a bull standing on top of the player is not goring it.
## **The wolf is in the list with the pig** — it damages by contact the same way and has no lunge in the
##  sim (`monster_defs.KIND_WOLF`'s own box). It is a **list and not `!= KIND_HEN`**, so the day a kind
##  arrives that neither has patterns nor touches for damage, it does not silently start playing an
##  attack it cannot make.
func _is_attacking(m: Monster) -> bool:
	if _attack_left.has(m.id):
		return true
	if not CONTACT_ATTACKERS.has(m.kind) or _char == null:
		return false
	var g := Fx.MONSTER_SHOVE_REACH_PX
	return WorldStep._boxes_overlap(m.x - g, m.y - g, Defs.w_px(m.kind) + g * 2, Defs.h_px(m.kind) + g * 2,
		_char.x, _char.y, Character.W_PX, Character.H_PX)


## **If there is a recent number for the same monster, add to it — do not make a new one** (decided by the user).
##
## **On screen three `-10`s overlapped and looked like `-1000`, covering the hp bar too.** The problem was not
##  that there were three numbers but **that the three overlapped in the same spot** — the seat is `m.center()`,
##  so on rapid hits the coordinates are nearly identical.
##
## **The age is rewound to 0 and the seat is refreshed.** Without rewinding, the merged number **disappears
##  soon after**, making it look as if the last hit landed with no display. The seat is refreshed because the
##  monster may have moved in the meantime (pigs push their way in).
## **The rewind is itself the risk of "it never ages"** — which is why the `MONSTER_DMG_NUM_MERGE_FRAMES`
##  comment pinned down "it must be shorter than the lifetime". **The number not disappearing while it keeps
##  getting hit is intended.**
##
## **It searches by id.** Search by coordinates and, when two monsters stand overlapping, someone else's damage
##  gets merged in.
func _add_dmg_number(m: Monster, amount: int) -> void:
	for n: Dictionary in _dmg_numbers:
		if n["id"] == m.id and int(n["age"]) < Fx.MONSTER_DMG_NUM_MERGE_FRAMES:
			n["amount"] = int(n["amount"]) + amount
			n["age"] = 0
			n["x"] = m.center().x
			n["y"] = float(m.y)
			return
	_dmg_numbers.append({
		"id": m.id, "x": m.center().x, "y": float(m.y), "amount": amount, "age": 0,
	})


func _decay_flashes() -> void:
	_decay(_flash_left)


## Counts every value in an id -> frames-left dictionary down by one and drops the ones that reach zero.
## **`_decay_flashes` was this, written out.** The hurt and attack latches count exactly the same way, and
##  three copies of a four-line countdown is three places for "it never expires" to hide.
func _decay(left_by_id: Dictionary) -> void:
	for id in left_by_id.keys().duplicate():
		var left := int(left_by_id[id]) - 1
		if left <= 0:
			left_by_id.erase(id)
		else:
			left_by_id[id] = left


func _prune(list: Array[Dictionary], max_age: int) -> void:
	var i := list.size() - 1
	while i >= 0:
		var age := int(list[i]["age"]) + 1
		if age >= max_age:
			list.remove_at(i)
		else:
			list[i]["age"] = age
		i -= 1


## The stage reset (R) calls this. The same door as `spell_view.clear()` and `blast_fx.clear()` —
##  without emptying, dead ids from the old session remain in the dictionary after R, and instead of the new
##  session's corpses and numbers mixing in, old traces can briefly sit on screen (it is emptied for safety).
func clear() -> void:
	_prev_hp.clear()
	_flash_left.clear()
	_anim.clear()
	_prev_x.clear()
	_prev_reload.clear()
	_attack_left.clear()
	_hurt_left.clear()
	_dmg_numbers.clear()
	_corpses.clear()
	_death_pops.clear()
	_wake_marks.clear()
	_prev_asleep.clear()
	queue_redraw()


# ══════════════════════════════════════════════════════════════════
#  Queries — the nets read only here (the same idiom as `blast_fx`'s "queries" section)
# ══════════════════════════════════════════════════════════════════

func corpse_count() -> int:
	return _corpses.size()


func corpse_kind(i: int) -> int:
	return _corpses[i]["kind"]


## **Which cell of the death sheet this corpse is showing — read back out of the rect that gets drawn.**
##  **It goes through `_corpse_art`, deliberately.** A query that recomputed `frame_index` itself would be a
##  second calculation, and inversion proved that exact hole: freezing `_corpse_art` on cell 0 left every
##  check green because the net was driving the arithmetic and not the drawing.
## -1 means there is no texture at all (the flat-rectangle fallback).
func corpse_frame(i: int) -> int:
	var c: Dictionary = _corpses[i]
	var art := _corpse_art(c["kind"], int(c["age"]))
	if art[0] == null:
		return -1
	return int((art[1] as Rect2).position.x) / Defs.w_px(c["kind"])


func is_flashing(id: int) -> bool:
	return _flash_left.has(id)


## **Which animation state this monster is on, or -1 if it has none yet** (nothing has driven `advance()`).
##  The nets read the state through here rather than reaching into `_anim` — the same "queries only" door
##  `corpse_kind`/`is_flashing` already are.
func anim_state(id: int) -> int:
	return int(_anim.get(id, {}).get("state", -1))


## **Which cell of that state's sheet is on screen this frame.** Goes through the same `frame_index` the
##  drawing does, so a net measuring this is measuring what is drawn and not a parallel calculation.
func anim_frame(id: int, kind: int) -> int:
	var a: Dictionary = _anim.get(id, {})
	if a.is_empty():
		return 0
	var state := int(a["state"])
	return frame_index(state, anim_row(kind, state), int(a["t"]), _anim_x(id))


func death_pop_count() -> int:
	return _death_pops.size()


## How many wake marks are alive — **including the ones still inside their stagger delay** (age < 0),
## which is why a net that wants "how many are actually on screen" must drive `_paint_wake_mark` instead
## of reading this. This counts the entities; the hook counts the picture.
func wake_mark_count() -> int:
	return _wake_marks.size()


func dmg_number_count() -> int:
	return _dmg_numbers.size()


func dmg_number_amount(i: int) -> int:
	return _dmg_numbers[i]["amount"]


# ══════════════════════════════════════════════════════════════════
#  Drawing
# ══════════════════════════════════════════════════════════════════

func _draw() -> void:
	if _world == null:
		return
	# Corpses are drawn before living monsters — a living monster (newly standing in the same spot) must cover
	#  the corpse for "it is gone" to feel natural. Overlap is rare (when the next spawn is in the same spot),
	#  but the order follows the same rule as scene child order (above terrain, below the character) —
	#  what is drawn first is below.
	for c: Dictionary in _corpses:
		_draw_corpse(c)
	for i in _world.monster_count():
		_draw_monster(_world.monster_at(i))
	# Monster bolts (chicken peck · Stage D's bull fire breath). `MonsterBolts` does not pass a direction (its
	# public API is only `x(i)`/`y(i)`/`kind(i)`), so they are drawn as dots — acceptance 13's requirement
	# ("a small dot / short line") is met with a dot.
	# **It is two layers — the same grammar as a magic bolt (glow + core), a different color per kind.**
	#  Changing only the color did not split the original two apart: the old pink and the hen purple were
	#  85 degrees apart and still got confused (the `fx_tuning.MONSTER_BOLT_COLOR` box) — fire uses `FIRE_LO`/
	#  `FIRE_HI` instead, already far from both on the wheel (that file's own comment on why it reuses them).
	for i in _world.bolt_count():
		var p := Vector2(_world.bolt_x(i), _world.bolt_y(i))
		var k := _world.bolt_kind(i)
		draw_circle(p, Fx.MONSTER_BOLT_R_PX, bolt_glow(k))
		draw_circle(p, Fx.MONSTER_BOLT_R_PX * Fx.MONSTER_BOLT_CORE_FRAC, bolt_core(k))
	# The pop at the moment of death — **above corpses and monsters, below the flash.**
	for p: Dictionary in _death_pops:
		_draw_death_pop(p)
	# The wake mark, at the same height in the stack and for the same reason.
	# **The seat and the age are computed here; the paint is a separate overridable hook** — see
	#  `_paint_wake_mark` below for why that split exists at all.
	for w: Dictionary in _wake_marks:
		var w_age := int(w["age"])
		if w_age < 0:
			continue   # still inside its stagger delay
		var w_c := box_rect(w["kind"], w["x"], w["y"]).get_center()
		_paint_wake_mark(Vector2(w_c.x, w_c.y - Fx.MONSTER_WAKE_MARK_LIFT_PX),
			float(w_age) / float(Fx.MONSTER_WAKE_MARK_FRAMES))
	# If the layers are missing (a net stood this up with no scene), they are drawn here instead — otherwise
	#  two worlds appear, "visible in the scene but absent in the net".
	if _flash_layer == null:
		_draw_flashes(self)
	if _number_layer == null:
		_draw_numbers(self)
	# The outline is not drawn here — with no layer it would be laid **on top of the body** and cover the
	#  silhouette wholesale.
	#  This is the case where a net stands it up with no scene, so there is no screen, and "absent is better
	#  than wrong".


## The flash layer calls this (`_flash_layer`). **The same coordinate system as this node** — a child inherits
## the parent's transform.
##
## **It takes `canvas` as an argument. Without this one line, damage numbers disappeared from the screen wholesale.**
##  verify-look caught it — the array had `-40`, the font was there, the layer was visible, and yet
##   **nothing was on screen.** The cause was the **asymmetry** between this function and `_draw_numbers`:
##   the flash took `canvas` properly while the numbers drew onto **the implicit `self` (= MonsterView)**,
##   and that function is called **inside a child layer's `_draw()`**, so MonsterView is not drawing
##   => **that draw command is silently discarded.**
##  **The nets could not catch it in principle** — nets read arrays, not the canvas.
##  => **Now `_Layer` passes the canvas as an argument** (that class's box) — the seat for the mistake was
##   removed at the syntax level.
func _draw_flashes(canvas: CanvasItem) -> void:
	if _world == null:
		return
	for i in _world.monster_count():
		var m: Monster = _world.monster_at(i)
		if not _flash_left.has(m.id):
			continue
		var r := box_rect(m.kind, m.x, m.y)
		var frac := float(_flash_left[m.id]) / float(Fx.MONSTER_FLASH_FRAMES)
		var a := Fx.MONSTER_FLASH_COLOR.a * frac
		var art := _art_of(m.id, m.kind)
		var tex: Texture2D = art[0]
		if tex == null:
			# Fallback — even with the shader hung, `TEXTURE` is a white 1x1 so the result is
			#  "white rectangle x strength" (the head of `monster_silhouette.gdshader`). That is
			#  **the old behavior exactly.**
			var c := Fx.MONSTER_FLASH_COLOR
			canvas.draw_rect(r, Color(c.r, c.g, c.b, a))
			continue
		_draw_flipped(canvas, tex, art[1], r, m.facing < 0, Color(1.0, 1.0, 1.0, a))


## **The outline — the body sprite laid down in eight directions, with the body covering it on top.**
##
## **Why it exists**: verify-look stood a pig against **a black sky** and **its legs and belly melted away**
##  (the `fx_tuning.MONSTER_OUTLINE_COLOR` box holds that story).
##
## **The shader paints in a flat color, so the eight offset copies become the border directly** — only alpha
##  survives and the color is a uniform, so dark pixels of the body sprite never get laid down dark.
##  **`modulate` multiplication cannot do this** — multiplying only darkens the original, it **never brightens.**
##   So this presentation is **impossible in principle without a shader** (the user chose that axis).
##
## **It is drawn around corpses too** — a corpse melting into the background makes "where it died" invisible.
##  The same problem as a living body.
func _draw_outlines(canvas: CanvasItem) -> void:
	if _world == null:
		return
	for c: Dictionary in _corpses:
		var age: int = c["age"]
		var alpha := 1.0 - float(age) / float(Fx.MONSTER_CORPSE_LIFE_FRAMES)
		# A corpse fades, so its outline has to fade with it — otherwise, after the body is gone,
		#  **only a cream outline is left floating.**
		_outline_one(canvas, _corpse_art(c["kind"], int(c["age"])), c["kind"], c["x"], c["y"], false, alpha)
	for i in _world.monster_count():
		var m: Monster = _world.monster_at(i)
		# **The outline dims with the body, not separately.** A full-strength outline around a dimmed body
		#  reads as a cream cut-out, which is the same "the two diverged" shape `_draw_flipped` was
		#  gathered to prevent.
		_outline_one(canvas, _art_of(m.id, m.kind), m.kind, m.x, m.y, m.facing < 0,
			Fx.MONSTER_ASLEEP_ALPHA if m.asleep else 1.0)


## **`art` is passed in, not looked up here.** The outline is the body sprite laid down eight times, so it has
##  to be **the same cell** the body is on — look it up again in this function and the day the two disagree,
##  the outline traces the previous frame's pose and the beast wears a ghost of where it just was.
func _outline_one(canvas: CanvasItem, art: Array, kind: int, x: int, y: int, flip: bool,
		alpha: float) -> void:
	var tex: Texture2D = art[0]
	if tex == null:
		return   # the fallback is a flat rectangle, so an outline would carry no meaning
	var r := box_rect(kind, x, y)
	var col := Color(1.0, 1.0, 1.0, alpha)
	for d: Vector2 in Fx.MONSTER_OUTLINE_DIRS:
		_draw_flipped(canvas, tex, art[1], Rect2(r.position + d * Fx.MONSTER_OUTLINE_PX, r.size), flip, col)


## **`canvas` must be passed down** — the `_draw_flashes` box above holds that story.
func _draw_numbers(canvas: CanvasItem) -> void:
	for n: Dictionary in _dmg_numbers:
		_draw_dmg_number(canvas, n)


func _draw_monster(m: Monster) -> void:
	var r := box_rect(m.kind, m.x, m.y)
	_draw_monster_body(m, r)
	# **The flash is not here** — the shader being per node sent it out to `_flash_layer` (the box above).
	if m.burning:
		_draw_body_flames(self, r, m.id)
	_draw_hp_bar(m.kind, m.x, m.y, m.hp)
	_draw_pattern_indicator(m, r)
	_draw_phase2_tell(m, r)


## **Fire attached to a body — in several places.** It was originally one box outline and read on screen as
##  **"an orange selection box"** (acceptance 13). The ground fire on the same screen is real pixel fire, so
##  the contrast was brutal — the `fx_tuning.MONSTER_BURN_FLAMES` box holds that story.
##
## **The seats are fixed by monster id** — draw them again each frame and the flames **teleport every frame**,
##  and that is noise, not fire. What moves is **size only**, with the phases offset so they do not all jump together.
## **The flames spill a little outside the box** — the body outline is unknown (alpha is not read), so keeping
##  them strictly inside makes the fire look cut off at the silhouette's edge. Spilling reads as "it wraps the body".
##
## **They are square pixels snapped to the cell grid, not circles** (verify-look caught it on screen).
##  **It was two layers of `draw_circle` and, being "a red rim with a yellow inside", it read as "five targets".**
##   The ground fire right next to it is an irregular pixel clump that anyone reads as fire => **the contrast
##   was unchanged.** "An orange selection box" had merely become "five orange targets" — **still a shape.**
##
## **The fix went at the vocabulary, not the color — it is drawn with the same grammar as the ground fire.**
##  Ground fire is pixels painted on the `CELL_PX` (4px) grid => body fire is drawn as **4px-aligned square
##  pixel clumps** too.
##  **A perfect circle is a shape that does not exist on this game's screen** — terrain, fire and water are all cells.
##   So a circle reads as "UI" no matter how well the color is matched. The same mistake was made with the bolt glow.
##
## **The clump shapes are fixed by id and i too** — draw them again each frame and it becomes sizzling noise.
##  What moves is **the height (the tongue licking upward)** only.
func _draw_body_flames(canvas: CanvasItem, r: Rect2, id: int) -> void:
	var cell := float(Tuning.CELL_PX)
	for i in Fx.MONSTER_BURN_FLAMES:
		var p := flame_pos(r, id, i)
		# The phase is offset per flame — otherwise the five jump as one body.
		var phase := float(i) * TAU / float(Fx.MONSTER_BURN_FLAMES)
		var wob := sin(float(_frame) / Fx.MONSTER_BURN_PERIOD_FRAMES * TAU + phase)
		# **Snapped to the cell.** Drop the snap and the fire is misaligned with the cell grid, becoming
		#  "something floating on top".
		var bx := floorf(p.x / cell) * cell
		var by := floorf(p.y / cell) * cell
		# Tongue height — 1 to 3 cells. `wob` shakes the **height**, not the size (fire grows upward).
		var tall := 1 + int(roundf((wob * 0.5 + 0.5) * (Fx.MONSTER_BURN_TALL_CELLS - 1)))
		for k in tall:
			# Narrower and brighter toward the top — that is the whole of "a flame tongue".
			var w := cell * float(tall - k)
			var col: Color = Fx.FIRE_LO if k < tall - 1 else Fx.FIRE_HI
			canvas.draw_rect(Rect2(bx - w * 0.5, by - cell * float(k + 1), w, cell), col)


## The ring that pops at the moment of death — **the chicken's only hit feedback**
##  (`fx_tuning.MONSTER_DEATH_POP_FRAMES`).
##  It fades as it opens. Opening alone reads as "a ring was left behind", fading alone reads as "it blinked".
func _draw_death_pop(p: Dictionary) -> void:
	var r := box_rect(p["kind"], p["x"], p["y"])
	var t := float(p["age"]) / float(Fx.MONSTER_DEATH_POP_FRAMES)
	var radius := maxf(r.size.x, r.size.y) * 0.5 * lerpf(1.0, Fx.MONSTER_DEATH_POP_SCALE, t)
	var c := Fx.MONSTER_DEATH_POP_COLOR
	draw_arc(r.get_center(), radius, 0.0, TAU, 24, Color(c.r, c.g, c.b, c.a * (1.0 - t)),
		Fx.MONSTER_DEATH_POP_PX)


## **Cut out of `_draw()` so a net can measure that the mark is actually painted, not merely that `_draw()`
## ran** — the exact remedy `gate_view._paint` records, for the exact reason: GDScript refuses to let a
## script override a *native* `CanvasItem` call like `draw_arc` (a hard parse error, not a warning), so a
## test subclass cannot intercept the native call. This is an ordinary script method instead, freely
## overridable, and it receives **the two things `_draw()` decided**: where the mark goes and how far
## through its life it is. A subclass asserting those arguments is asserting the picture.
##
## **It is not called `_paint`** — `monster_view._paint` above is already taken by an unrelated
##  shader-uniform setter, and one overloaded name is how a hook ends up hung on the wrong thing.
##
## `age` is 0.0 at birth and 1.0 at expiry. The ring opens and fades together (`fx_tuning`'s own note).
func _paint_wake_mark(center: Vector2, age: float) -> void:
	var radius := Fx.MONSTER_WAKE_MARK_R_PX * lerpf(1.0, Fx.MONSTER_WAKE_MARK_SCALE, age)
	var c := Fx.MONSTER_WAKE_MARK_COLOR
	draw_arc(center, radius, 0.0, TAU, 20, Color(c.r, c.g, c.b, c.a * (1.0 - age)),
		Fx.MONSTER_WAKE_MARK_PX)


## **The sprite is drawn to fit `r` (= the box coming from `Defs`) — the texture's own pixel size is not trusted.**
##  `draw_texture_rect` stretches or shrinks to the destination size, so even if the art diverges from the box,
##  **the screen is still box-sized** (`net_monster_sprite` measures "they are the same today" as a value —
##  if they diverge, that goes red first).
##
## **If the texture is missing (load failure) it substitutes a `MONSTER_FILL` rectangle.** The
##  `fx_tuning.MONSTER_FILL` box above wrote the reason — monsters always have several kinds, so the rest
##  must still show when one breaks.
##
## **Monster art faces right — it is flipped when going left** (the same idiom as `character_view._draw`,
##  flipping the horizontal scale with `draw_set_transform`). **Do not forget to restore it** —
##  without restoring, everything drawn afterwards (flash, burn outline, hp bar) is drawn in a flipped
##  coordinate system.
## **A dormant body draws dimmed** (`fx_tuning.MONSTER_ASLEEP_ALPHA`, presentation A of
## `left-run-clumps-and-platforms.md`'s Screen section). Before this, a sleeping mob and a walking one
## were the same picture, so a clump standing there dormant was indistinguishable from a clump already
## coming for you. **The fallback rectangle dims too** — dim only the sprite path and the day a sheet
## fails to load the fallback silently claims every mob is awake.
func _draw_monster_body(m: Monster, r: Rect2) -> void:
	var art := _art_of(m.id, m.kind)
	var a := Fx.MONSTER_ASLEEP_ALPHA if m.asleep else 1.0
	var tex: Texture2D = art[0]
	if tex == null:
		var f := Fx.MONSTER_FILL
		draw_rect(r, Color(f.r, f.g, f.b, f.a * a))
		return
	_draw_flipped(self, tex, art[1], r, m.facing < 0, Color(1.0, 1.0, 1.0, a))


## Draws the body sprite to fit the box. Flipped when facing left.
##  **Do not forget to restore it** — without restoring, everything drawn afterwards goes into a flipped
##  coordinate system.
##  **That is why it was gathered into this one function.** Write the same flip separately for the body and
##   the flash and **the day the two diverge**, a hit pig's white silhouette alone stands the wrong way,
##   and that is visible on screen only.
## Why it takes `canvas`: the flash is drawn onto **a child node** (the shader is per node).
## **`src` is which cell of the sheet** — every sprite here is a strip of frames now, so there is no longer
##  such a thing as "draw the whole texture". A single-frame fallback passes its own full rect (`_art_of`).
func _draw_flipped(canvas: CanvasItem, tex: Texture2D, src: Rect2, r: Rect2, flip: bool,
		modulate: Color) -> void:
	canvas.draw_set_transform(Vector2(r.position.x + (r.size.x if flip else 0.0), r.position.y),
		0.0, Vector2(-1.0 if flip else 1.0, 1.0))
	canvas.draw_texture_rect_region(tex, Rect2(Vector2.ZERO, r.size), src, modulate)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## **The texture and the cell this monster is on this frame — the one door body, flash and outline all use.**
##  Returns `[Texture2D, Rect2]`, or `[null, …]` when nothing can be drawn (each caller substitutes its own
##  fallback shape, the discipline this file holds for monsters).
##
## **The animation state is read, never computed** — `_scan_anim()` decided it once this frame
##  (`_anim`'s own box). A monster with no entry (drawn before `advance()` ever ran, which is how the nets
##  stand this node up) falls straight through to the single body sprite rather than inventing a state.
func _art_of(id: int, kind: int) -> Array:
	var a: Dictionary = _anim.get(id, {})
	if not a.is_empty():
		var state := int(a["state"])
		var row := anim_row(kind, state)
		var tex: Texture2D = _anim_sheets.get(kind, {}).get(state)
		if tex != null and not row.is_empty():
			return [tex, frame_src(kind, frame_index(state, row, int(a["t"]), _anim_x(id)))]
	return _body_art(kind)


## The walk clock's reading for this id. **It is the monster's own x**, kept by `_scan_anim` — the drawing
##  side has no `Monster` in hand (a corpse has no id at all), so the value is looked up rather than passed.
func _anim_x(id: int) -> int:
	return int(_prev_x.get(id, 0))


## The single body sprite, as a `[tex, src]` pair. **The fallback for everything** — a kind with no animation
##  table, a sheet that failed to load, or a draw that happens before any state exists.
func _body_art(kind: int) -> Array:
	var tex: Texture2D = _sheets.get(kind)
	if tex == null:
		return [null, Rect2()]
	return [tex, Rect2(0.0, 0.0, float(tex.get_width()), float(tex.get_height()))]


func _draw_hp_bar(kind: int, x: int, y: int, hp: int) -> void:
	var bar := hp_bar_rect(kind, x, y)
	draw_rect(bar, Fx.MONSTER_HP_BAR_BG)
	var frac := hp_bar_fill_frac(hp, Defs.max_hp(kind))
	if frac <= 0.0:
		return
	var fill := Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y))
	draw_rect(fill, Fx.MONSTER_HP_BAR_FULL.lerp(Fx.MONSTER_HP_BAR_EMPTY, 1.0 - frac))


## The wind-up/stun indicator (`stage1-bosses.md` Stage B, acceptance 3). **Reads `m.pattern` only** — a
## trash mob's `pattern` never leaves `BossAi.Pattern.IDLE` (`boss_ai.gd`'s own header: `monster_defs`
## carries no notion of patterns at all), so this draws nothing for a pig or a hen.
## **Drawn directly on `self`, not through a child `_Layer`** — the same door `_draw_monster_body`/
## `_draw_hp_bar` already use; no shader is hung on this, so there is no reason to split it onto its own node.
func _draw_pattern_indicator(m: Monster, r: Rect2) -> void:
	if m.pattern == BossAi.Pattern.WINDUP:
		_draw_attack_prediction(m, r)
	elif m.pattern == BossAi.Pattern.STUN:
		_draw_stun_ring(r)


# ══════════════════════════════════════════════════════════════════
#  The attack prediction (`docs/design/attack-prediction.md`) — replaces the "!" text tell.
#  The user's own words: the monster's attack should show **in red, as a prediction** — a mark on the ground
#  saying where it lands, not a symbol saying only that something is coming. The stun ring above is the model
#  for how strong this should read; nothing about the ring changed.
# ══════════════════════════════════════════════════════════════════

## The pattern clock's own rate — `boss_ai.gd`'s tick machine runs at 20Hz (60Hz physics / `Tuning.TICK_
## DIVIDER`=3). Derived rather than a bare `0.05` literal, so the day the divisor or the physics rate changes,
## the distance/time math below does not silently drift from the clock it is timing.
const PATTERN_TICK_SEC := float(Tuning.TICK_DIVIDER) / 60.0

## **Dispatches on the resolved move, then delegates to one shape per move** — `_draw_charge_predict` (also
## covers gore, a substitution decided inside this function), `_draw_fire_predict`, `_draw_landing_predict`
## (shared by the bull's slam and the rooster's leap, both `Pattern.LEAP` physics — `boss_ai.gd`'s own header:
## "the physics is the rooster's own `Pattern.LEAP`, not a new state").
##
## **Tracks the player live, not the stale `pattern_dir`** — `boss_ai.gd`'s own header: direction (and, for
## the bull's charge, whether gore substitutes for it) is only decided at the WINDUP -> active transition and
## held from there; `pattern_dir`/`move_choice` read *during* WINDUP still carry the **previous** move's
## values. A prediction drawn from those would be lying for however long WINDUP has left — at phase 2 that is
## 0.4s of a wrong-side or wrong-shape mark, worse than no mark at all (the plan's own words). Recomputed
## every frame from the live player position instead, using the exact same two rules `boss_ai.advance()`
## itself applies at the lock instant (`signi` on the horizontal difference; `BossAi.gore_range_px` plus a
## vertical-overlap check, mirrored in `_would_gore` below) — so the live guess and the eventual lock **agree
## by construction** on the tick they meet, not by coincidence.
##
## **`_char == null` degrades to the stored `pattern_dir`/`move_choice`, never to gore** — the only door that
## reaches this with no live player is a net driving `_draw_pattern_indicator` directly with no `setup()`
## (`net_monster_charge.gd`'s own dispatch test); real play always calls `setup()` first, the same discipline
## `_world` already holds elsewhere in this file.
func _draw_attack_prediction(m: Monster, r: Rect2) -> void:
	var dir := m.pattern_dir
	var gore := false
	if _char != null:
		var tx := _char.center().x
		var mx := m.center().x
		if tx != mx:
			dir = signi(int(tx - mx))
		if m.kind == Defs.KIND_BULL and m.move_choice == BossAi.MoveChoice.CHARGE:
			gore = _would_gore(m, tx, _char.center().y)

	if m.kind == Defs.KIND_ROOSTER:
		_draw_landing_predict(m, r, dir, false)
		return
	if m.move_choice == BossAi.MoveChoice.FIRE:
		_draw_fire_predict(m, r, dir)
		return
	if m.move_choice == BossAi.MoveChoice.SLAM:
		_draw_landing_predict(m, r, dir, true)
		return
	if gore:
		_draw_gore_predict(m, r)
	else:
		_draw_charge_predict(m, r, dir)


## **Mirrors `Monster._vertically_overlaps_target`/`BossAi.advance`'s own gore-substitution condition** —
## that method is private to `Monster` and the sim only ever evaluates it once, at the lock instant, but this
## has to re-evaluate the same question **every frame during WINDUP** so the live guess can track it. Kept to
## exactly the same two conditions (`BossAi.gore_range_px` distance, then the vertical box overlap) rather
## than reached for through a new public accessor on `Monster`, so there is one obvious place to check if the
## two ever need to be compared side by side.
func _would_gore(m: Monster, target_x: float, target_y: float) -> bool:
	if absf(target_x - m.center().x) > BossAi.gore_range_px(m.kind):
		return false
	var half_h := Character.H_PX * 0.5
	return float(m.y) < target_y + half_h and float(m.y + Defs.h_px(m.kind)) > target_y - half_h


## CHARGE — the lane it will run down. A red band the monster's own height, from its leading edge to the
## first wall it would actually hit or the safety-cap distance, whichever is shorter — **never longer than
## the real charge could ever reach**, so this can undersell a charge (a steppable single-cell bump the real
## collision would climb over, `Body.move_x`'s own `allow_step` — charges pass `false` for that, so this
## approximation is closer than it sounds) but never oversell one.
func _draw_charge_predict(m: Monster, r: Rect2, dir: int) -> void:
	var max_px := _charge_max_px(m)
	var stop := _wall_stop_x(m, dir, max_px)
	var lead := r.position.x if dir < 0 else r.end.x
	_draw_predict_rect(Rect2(minf(lead, stop), r.position.y, absf(stop - lead), r.size.y))


## The farthest a charge could possibly travel — `BossAi.MOVE_CHARGE`'s own safety cap, scaled by phase 2 the
## same way `boss_ai.advance()` itself scales it (`BossAi._phase_ticks`, not a second copy of the divide-by-2
## rule), times the same speed `BossAi.speed_mult` gives `Monster.step`. **`+1` tick** — `boss_ai.gd`'s own
## comment: the tick that sets a duration counter is itself already spent in that state, so `charge_max_ticks`
## (60) actually holds `CHARGE` for 61 ticks, the exact number the plan's own message quoted.
func _charge_max_px(m: Monster) -> float:
	var phase2 := m.is_phase2()
	var ticks := BossAi._phase_ticks(int(BossAi.MOVE_CHARGE["charge_max_ticks"]), phase2)
	var speed := Defs.speed_px(m.kind) * BossAi.speed_mult(m.kind, BossAi.Pattern.CHARGE, phase2)
	return float(ticks + 1) * PATTERN_TICK_SEC * speed


## Where the charge actually stops — the first wall in its path, stepped in `Tuning.CELL_PX` increments (the
## grid's own resolution, not a per-pixel scan) and checked with the same box-vs-cell rule `Body.box_free`
## uses for the real collision (that function is private to `Body`; `_grid.is_solid` is public, so this reads
## the same handful of cells through the door that exists rather than adding an accessor for one caller).
## **`_grid == null` falls back to the capped straight line** — the same null-tolerant discipline
## `_draw_attack_prediction`'s own header names.
func _wall_stop_x(m: Monster, dir: int, max_px: float) -> float:
	var w := Defs.w_px(m.kind)
	var lead0 := m.x if dir < 0 else m.x + w
	if _grid == null or dir == 0:
		return float(lead0) + float(dir) * max_px
	var h := Defs.h_px(m.kind)
	var cell := Tuning.CELL_PX
	var max_i := int(max_px)
	var traveled := 0
	while traveled < max_i:
		var step := mini(cell, max_i - traveled)
		if not _box_free(m.x + dir * (traveled + step), m.y, w, h):
			break
		traveled += step
	return float(lead0) + float(dir) * float(traveled)


## The same box-vs-cell check `Body.box_free` performs for real collision, re-read here because that method
## is private to `Body` and `_grid.is_solid` (the door it is built on) is public.
func _box_free(px: int, py: int, w: int, h: int) -> bool:
	var cell := float(Tuning.CELL_PX)
	var cx0 := floori(px / cell)
	var cx1 := floori((px + w - 1) / cell)
	var cy0 := floori(py / cell)
	var cy1 := floori((py + h - 1) / cell)
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			if _grid.is_solid(cx, cy):
				return false
	return true


## GORE — what it can actually reach, not the gate. `BossAi.gore_range_px` (120px) only decides *whether*
## gore is chosen over a charge at the windup lock; the real hit is a plain box overlap
## (`WorldStep._boxes_overlap`), which lands at `(this kind's own w_px + the player's W_PX) / 2` centre to
## centre — 54px for the bull, not 120. **Symmetric, not directional** — box overlap does not care which side
## the player is standing on, so this does not read `dir` at all.
func _draw_gore_predict(m: Monster, r: Rect2) -> void:
	var reach := (float(Defs.w_px(m.kind)) + Character.W_PX) * 0.5
	_draw_predict_rect(Rect2(r.get_center().x - reach, r.position.y, reach * 2.0, r.size.y))


## FIRE — the stream it will sweep. A horizontal line from the exact point a real bolt spawns from
## (`WorldStep.frame()`: `_bolts.spawn(m.center().x, m.center().y, Vector2(pattern_dir, 0.0), ...)` for any
## non-hen kind), `MonsterBolts.BOLT_RANGE_PX` long, no vertical component — the same `Vector2(dir, 0.0)` the
## real bolt is given, not a re-aimed line.
func _draw_fire_predict(m: Monster, r: Rect2, dir: int) -> void:
	var c := m.center()
	var x0 := c.x if dir >= 0 else c.x - MonsterBolts.BOLT_RANGE_PX
	_draw_predict_rect(Rect2(x0, c.y - Fx.ATTACK_PREDICT_LINE_PX * 0.5,
		MonsterBolts.BOLT_RANGE_PX, Fx.ATTACK_PREDICT_LINE_PX))


## SLAM/LEAP — where it comes down. **Not exact** — the real landing is 60Hz discrete integration against
## whatever terrain happens to be underneath, unmeasurable from this view without actually running the frame
## (verify-run's seat, not this one). What this draws instead is the same **continuous** analytic estimate
## `boss_ai.gd`'s own comments already compute and already name as an overshoot — `2*|vy_px|/GRAVITY_PX` for
## the time aloft (symmetric flight: time up equals time down), times the horizontal speed the move actually
## uses. `boss_ai.gd`'s own measured number for the rooster's leap (153px real vs. this formula's 167px) is
## the only ground truth on record for how far off that overshoot runs for a *horizontal* distance — closer
## than the ~30% the same comment records for the *apex* height, but still an estimate, not the real number.
##
## For the slam, the ignite ring (`BossAi.slam_ignite_r`/`_spread_cells`/`_points`) is drawn too — the fire
## the landing actually throws, at the same radius `MOVE_SLAM`'s own comment derives (outer pair at
## `spread_cells * (points / 2) + ignite_r` cells, ±56px for the bull's current numbers).
func _draw_landing_predict(m: Monster, r: Rect2, dir: int, is_slam: bool) -> void:
	var vy := absf(BossAi.leap_jump_vy_px(m.kind))
	if vy <= 0.0:
		return
	var air_time := 2.0 * vy / Character.GRAVITY_PX
	var move: Dictionary = BossAi.MOVE_SLAM if is_slam else BossAi.MOVE_LEAP
	var h_speed := Defs.speed_px(m.kind) * float(move["leap_speed_mult"])
	var landing_x := m.center().x + float(dir) * h_speed * air_time
	var ground_y := r.end.y

	_draw_predict_ring(Vector2(landing_x, ground_y), maxf(r.size.x, r.size.y) * 0.5)
	if is_slam:
		var outer_cells := BossAi.slam_ignite_spread_cells(m.kind) * (BossAi.slam_ignite_points(m.kind) / 2) \
			+ BossAi.slam_ignite_r(m.kind)
		_draw_predict_ring(Vector2(landing_x, ground_y), float(outer_cells * Tuning.CELL_PX))


## The shared low-level draw calls — a filled band (charge/gore/fire) or a ring (the landing marker), both
## pulsing the same `sin()` shape `_draw_stun_ring` already uses (that function's own comment: "reads as
## active feedback, not a fixed decal"), copied rather than reinvented so the two families of tell read as
## one visual language.
func _draw_predict_rect(rect: Rect2) -> void:
	var a := _predict_alpha()
	var fill := Fx.ATTACK_PREDICT_COLOR
	draw_rect(rect, Color(fill.r, fill.g, fill.b, fill.a * a), true)
	var edge := Fx.ATTACK_PREDICT_EDGE_COLOR
	draw_rect(rect, Color(edge.r, edge.g, edge.b, edge.a * a), false, Fx.ATTACK_PREDICT_EDGE_PX)


func _draw_predict_ring(center: Vector2, radius: float) -> void:
	var edge := Fx.ATTACK_PREDICT_EDGE_COLOR
	var a := _predict_alpha()
	draw_arc(center, radius, 0.0, TAU, 24, Color(edge.r, edge.g, edge.b, edge.a * a), Fx.ATTACK_PREDICT_EDGE_PX)


func _predict_alpha() -> float:
	var t := float(_frame % Fx.ATTACK_PREDICT_PULSE_FRAMES) / float(Fx.ATTACK_PREDICT_PULSE_FRAMES)
	return lerpf(Fx.ATTACK_PREDICT_MIN_ALPHA_FRAC, Fx.ATTACK_PREDICT_MAX_ALPHA_FRAC, sin(t * TAU) * 0.5 + 0.5)


## **Pulses** — the same `sin(_frame / period)` shape `_draw_body_flames`'s wobble already uses, so the ring
## reads as "alive" rather than a fixed decal painted at the moment the stun began.
func _draw_stun_ring(r: Rect2) -> void:
	var t := float(_frame % Fx.MONSTER_STUN_RING_PERIOD_FRAMES) / float(Fx.MONSTER_STUN_RING_PERIOD_FRAMES)
	var frac := lerpf(Fx.MONSTER_STUN_RING_MIN_FRAC, Fx.MONSTER_STUN_RING_MAX_FRAC, sin(t * TAU) * 0.5 + 0.5)
	var radius := maxf(r.size.x, r.size.y) * 0.5 * frac
	draw_arc(r.get_center(), radius, 0.0, TAU, 24, Fx.MONSTER_STUN_RING_COLOR, Fx.MONSTER_STUN_RING_PX)


## **Stage H — "speeds up at half health," the screen half.** `stage1-bosses.md`'s own open TBD ("phase
## transition presentation — what is visible at half health") is picked here, not decided by the user yet.
## **Persistent, not pattern-gated** — composes with `_draw_pattern_indicator` rather than replacing it (a
## boss can be mid-`WINDUP` and below half hp at the same instant; both tells must show at once, so this is
## its own function called separately from `_draw_monster`, not folded into the `if`/`elif` above).
## **Unblinking and thick, on purpose** — verify-look measured the windup "!" as a small orange dot at 1.0
## zoom while the stun ring read well; the difference this function bets on is size and constancy, not a
## cleverer shape, so there is no blink here the way `_draw_telegraph` has one.
## **Calls `m.is_phase2()` rather than re-deriving the threshold** — the same rule already lives once, in
## `Monster` (read by `BossAi.advance`/`BossAi.speed_mult` for behavior); reimplementing `hp * 2 <= max_hp`
## here would make two copies of one rule, and the day the threshold changes only one of them would follow.
## Called every frame, not cached — the same "re-decided every frame" discipline `is_phase2()` itself holds.
## **The threshold check and the drawing are two functions, not one** — the same split
## `_draw_pattern_indicator`/`_draw_telegraph`/`_draw_stun_ring` already holds. A net can drive this dispatch
## for real (an untreed node tolerates the `if`, no canvas needed) while overriding only the leaf
## (`_draw_phase2_ring`, below) to record instead of calling `draw_rect` on a node with nothing to draw onto —
## folding the threshold into one function with the draw call would put the guard behind the same wall the
## drawing itself sits behind, the trap `_draw_pattern_indicator`'s own split already avoids.
func _draw_phase2_tell(m: Monster, r: Rect2) -> void:
	if not m.is_phase2():
		return
	_draw_phase2_ring(r)


## **Grown outward, not flush with the box** — flush would sit on top of the outline shader
## (`Fx.MONSTER_OUTLINE_COLOR`) that already hugs every monster's silhouette, and the two would blur into one
## line instead of reading as two separate things.
##
## **Four corner brackets, not a rectangle** — verify-look's own finding, and this repo's second time making
## this exact mistake: a full outline around a sprite reads as an editor's selection box (`_draw_body_flames`'s
## own comment above records the first time, "an orange selection box", acceptance 13). Each corner gets an
## "L" of two short lines running along the box's own edges from that corner — the middle of every edge stays
## empty on purpose, which a selection rectangle never does, and the shape is neither the stun ring's circle
## nor the outline shader's own silhouette-hugging line, so none of the three can be mistaken for each other.
func _draw_phase2_ring(r: Rect2) -> void:
	var g := r.grow(Fx.MONSTER_PHASE2_MARGIN_PX)
	var arm := Fx.MONSTER_PHASE2_BRACKET_ARM_PX
	# Corners in order: top-left, top-right, bottom-right, bottom-left. Each entry's sign says which way its
	# own two arms point (into the box's own edges, not out into open space) — top-left's arms run right and
	# down, top-right's run left and down, and so on around the box.
	var corners: Array[Vector2] = [g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)]
	var x_sign: Array[float] = [1.0, -1.0, -1.0, 1.0]
	var y_sign: Array[float] = [1.0, 1.0, -1.0, -1.0]
	for i in 4:
		var c := corners[i]
		draw_line(c, c + Vector2(arm * x_sign[i], 0.0), Fx.MONSTER_PHASE2_COLOR, Fx.MONSTER_PHASE2_OUTLINE_PX)
		draw_line(c, c + Vector2(0.0, arm * y_sign[i]), Fx.MONSTER_PHASE2_COLOR, Fx.MONSTER_PHASE2_OUTLINE_PX)


## **A corpse is a body sprite too — laid down dark and faded** (acceptance 13 failed right here).
##  **It was originally a purple rectangle and read on screen as "is that a leftover UI fragment"** — bodies on
##   the same screen are sprites while only corpses were shapes, so **the value of having attached sprites was
##   cut in half.**
## **Darkening is `modulate` multiplication** — the alpha channel survives intact so the silhouette is exact.
##  Being multiplication it **cannot brighten.** That matches the direction of "it darkens when it dies",
##  so it is right here.
##
## **The direction is unknown — it always faces right.** The death notification (`world.died_*`) does not pass
##  `facing`.
##  **Die while walking left and the corpse snaps around.** Adding one field to the notification fixes it,
##   but that touches the `src/actor/` contract so it is **outside this scope.** Do it when it becomes noticeable.
func _draw_corpse(c: Dictionary) -> void:
	var kind: int = c["kind"]
	var r := box_rect(kind, c["x"], c["y"])
	var age: int = c["age"]
	var alpha := 1.0 - float(age) / float(Fx.MONSTER_CORPSE_LIFE_FRAMES)
	var art := _corpse_art(kind, age)
	var tex: Texture2D = art[0]
	if tex == null:
		# Fallback — the same discipline as `_draw_monster_body` (substitute, do not bark).
		var col := Fx.MONSTER_CORPSE_COLOR
		draw_rect(r, Color(col.r, col.g, col.b, col.a * alpha))
		return
	var d := Fx.MONSTER_CORPSE_DIM
	draw_texture_rect_region(tex, r, art[1], Color(d, d, d, alpha))


## **The corpse is the death animation played by its own age** — the clock is the `age` the corpse already
##  carries, so there is no second timer to fall out of step with the fade.
##
## **`MON_DEATH` never loops** (`Fx.MONSTER_ANIM`), so this clamps on the last cell and holds it while the
##  fade finishes. That pause is why `MONSTER_CORPSE_LIFE_FRAMES` is longer than the animation.
##
## **`x` is 0, not the corpse's own x** — `frame_index` only reads x for `MON_WALK`, and a corpse is never
##  walking. Passing the seat in would make it look like the clock, which is exactly the confusion the
##  separate walk clock exists to avoid.
func _corpse_art(kind: int, age: int) -> Array:
	var row := anim_row(kind, Fx.MON_DEATH)
	var tex: Texture2D = _anim_sheets.get(kind, {}).get(Fx.MON_DEATH)
	if tex == null or row.is_empty():
		return _body_art(kind)
	return [tex, frame_src(kind, frame_index(Fx.MON_DEATH, row, age, 0))]


## **It is `canvas.draw_string` — not a bare `draw_string`.**
##  **This is that seat** (the `_draw_flashes` box above). A bare `draw_string` hangs it on MonsterView itself,
##   and this function is called **while a child layer is drawing**, so **that command is silently discarded.
##   No error is raised either.**
##  `net_monster` measures this rule **in the source** — headless cannot catch it by behavior.
func _draw_dmg_number(canvas: CanvasItem, n: Dictionary) -> void:
	# If there is no font it does not draw — passing `null` barks every frame, and since the wrapper counts
	#  stderr as failure, an ordinary screen turns the nets red (the same discipline as `circle_window._draw`).
	# **It is not `get_theme_default_font()`** — this node is a `Node2D`, not a `Control`, so that function
	#  does not exist (`circle_window` is a `Control` so it could use it). The only way to get the default font
	#  from a `Node2D` is `ThemeDB`.
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var age: int = n["age"]
	var t := float(age) / float(Fx.MONSTER_DMG_NUM_LIFE_FRAMES)
	var alpha := 1.0 - t
	# **It starts above the hp bar** — put it up straight from `m.y` and it covers the hp bar
	#  (verify-look saw it on screen. The `MONSTER_DMG_NUM_LIFT_PX` box).
	var y := float(n["y"]) - Fx.MONSTER_DMG_NUM_LIFT_PX - Fx.MONSTER_DMG_NUM_RISE_PX * t
	var col := Fx.MONSTER_DMG_NUM_COLOR
	var text := "-%d" % int(n["amount"])
	# Centered — everything in the `circle_window` family is LEFT, so the width is measured directly and it is
	# shifted left by half.
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.MONSTER_DMG_NUM_SIZE).x
	canvas.draw_string(font, Vector2(float(n["x"]) - w * 0.5, y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.MONSTER_DMG_NUM_SIZE,
		Color(col.r, col.g, col.b, col.a * alpha))


# ══════════════════════════════════════════════════════════════════
#  Pure static — the nets call these directly (the same idiom as `character_view.pick_state`)
# ══════════════════════════════════════════════════════════════════

## **Which animation state is on screen. Pure static, so the nets call it directly** — the same seat, and the
##  same reason, as `character_view.pick_state`: a combination goes in and a state comes back with no scene,
##  no world and no monster.
##
## **What a net can measure stops at "the code picks a different state".** Point every row of
##  `Fx.MONSTER_ANIM` at one png and the nets stay green — "the sheet in that slot really is a different
##  animation" is the eye's, in principle (`character_view.pick_state`'s own note, verbatim).
##
## The priority is a contract:
##  (1) **A boss's pattern outranks everything.** `Pattern` is the sim's own state machine — a bull that
##    flinched out of its charge because a bolt landed would be **the screen contradicting the sim**, which is
##    this repo's signature fake. A boss has no hurt sheet for the same reason (`Fx.MONSTER_ANIM`'s box)
##  (2) **Hurt outranks everything below it** — being interrupted is the more urgent sentence, and a hen that
##    keeps spitting (or jumping) while dying reads as "my hit did nothing"
##  (3) **Airborne outranks attacking** (`monster-ai-jump-and-separation.md`, Stage B, team-lead's own
##    recommendation) — `_is_attacking()`'s pig/wolf branch is a *proximity condition*, not an event
##    (`_is_attacking`'s own header), so a pig jumping near the player would otherwise never show a jump
##    frame at all — exactly the "it is trying to get out and cannot" picture the jump exists to draw
##  (4) Attacking, then walking, then standing
## **`Pattern.IDLE` is not `MON_IDLE`** — a boss walks toward the player during `IDLE` (`Monster._boss_axis`),
##  so it falls through to the same airborne/walk/stand question a trash mob answers.
##
## **Correction, measured (Stage B's own named risk): no boss has a `MON_AIRBORNE` row, and this function does
## not special-case that** — an idle boss with `on_ground == false` still resolves to `Fx.MON_AIRBORNE` here
## (the pattern guard above only intercepts `pattern != IDLE`); `anim_row`'s own fallback then substitutes
## `MON_IDLE`'s row for the missing state. **Left as-is, not fixed**: an idle boss falling off a ledge stops
## playing its walk animation and plays its idle pose instead of a walk or a jump — small, real, and no boss
## jump sheet exists or is planned (the plan's own Out of scope). `net_monster_sprite` drives and records this.
static func resolve_state(kind: int, pattern: int, on_ground: bool, hurt: bool, attacking: bool,
		moving: bool) -> int:
	if BossAi.has_pattern(kind) and pattern != BossAi.Pattern.IDLE:
		if pattern == BossAi.Pattern.WINDUP:
			return Fx.MON_WINDUP
		if pattern == BossAi.Pattern.CHARGE:
			return Fx.MON_CHARGE
		if pattern == BossAi.Pattern.GORE:
			return Fx.MON_ATTACK
		if pattern == BossAi.Pattern.FIRE:
			return Fx.MON_FIRE
		if pattern == BossAi.Pattern.LEAP:
			return Fx.MON_LEAP
		return Fx.MON_STUN
	if hurt:
		return Fx.MON_HURT
	if not on_ground:
		return Fx.MON_AIRBORNE
	if attacking:
		return Fx.MON_ATTACK
	return Fx.MON_WALK if moving else Fx.MON_IDLE


## The row for a state, **falling back to `MON_IDLE` when that kind has no such sheet** (`Fx.MONSTER_ANIM`'s
##  own box — the bosses have no hurt sheet on purpose). Returns an empty dictionary when even idle is
##  missing, and every caller reads that as "use the single body sprite" — the substitute-do-not-bark rule
##  this file holds for monsters (`_load_sheets`'s box).
static func anim_row(kind: int, state: int) -> Dictionary:
	var rows: Dictionary = Fx.MONSTER_ANIM.get(kind, {})
	if rows.has(state):
		return rows[state]
	return rows.get(Fx.MON_IDLE, {})


## **How long a one-shot state runs, in view frames** — `frames * hold`, read off the same row that draws it.
##  Written as a function rather than a second column so a latch (`_hurt_left`, `_attack_left`) can never
##  disagree with the animation it is holding open. **0 when the kind has no such sheet**, which reads at the
##  call site as "do not latch anything" — correct for a boss, which has no hurt pose to hold.
static func oneshot_frames(kind: int, state: int) -> int:
	var rows: Dictionary = Fx.MONSTER_ANIM.get(kind, {})
	if not rows.has(state):
		return 0
	var row: Dictionary = rows[state]
	return int(row["frames"]) * int(row["hold"])


## **Which cell of the sheet. Pure static, so the nets call it directly.**
##
## **Walking has its own clock and it is the monster's `x`** — `Fx.MONSTER_WALK_PX_PER_FRAME`, exactly as the
##  character's walk reads `character.x`. `t` (the view's frame counter) drives every other state.
##  **Two clocks for one gait is the bug this splits to avoid**: count frames while walking and a monster
##  stopped dead against a wall keeps moving its legs, which `character_view` records having been burned by.
## **`absi` for the same reason that file gives** — walking left decreases x, and negative division truncating
##  toward zero makes left and right run at different cadences.
##
## **`loop: false` clamps to the last cell instead of wrapping.** That is what makes a death animation stay
##  dead. Wrapping would restart it, and on a corpse (which lives longer than its own animation) that reads as
##  the beast twitching back to life.
static func frame_index(state: int, row: Dictionary, t: int, x: int) -> int:
	if row.is_empty():
		return 0
	var n := int(row["frames"])
	if n <= 1:
		return 0
	var i := absi(x) / Fx.MONSTER_WALK_PX_PER_FRAME if state == Fx.MON_WALK else t / int(row["hold"])
	if bool(row["loop"]):
		return i % n
	return mini(i, n - 1)


## The cell to cut out of the sheet. **The frame width is the box width** (`Defs.w_px`) — sheets are laid out
##  that way by `tools/pixel/anim_sheet.py` and `net_monster_sprite` measures it, so this never reads the
##  texture's own pixel size (the same distrust `_draw_monster_body` already documents).
static func frame_src(kind: int, idx: int) -> Rect2:
	return Rect2(float(idx * Defs.w_px(kind)), 0.0, float(Defs.w_px(kind)), float(Defs.h_px(kind)))


## **Pure static, so the nets call it directly.** `_draw()` uses only this function, so the value the nets
## measure = the value actually drawn (`character_view.pick_state` and `spell_view`'s "queries" section).
## The size comes from `monster_defs` (actor). Put the size in `fx_tuning` and the box table lives in two places,
## and the only symptom is "the pig floats 12px off the wall" (the design doc's "screen" box).
static func box_rect(kind: int, x: int, y: int) -> Rect2:
	return Rect2(x, y, Defs.w_px(kind), Defs.h_px(kind))


## The hp bar's seat — it comes from the box width (for the same reason as the box above, the width is not
## rebuilt here).
static func hp_bar_rect(kind: int, x: int, y: int) -> Rect2:
	return Rect2(float(x), float(y) - Fx.MONSTER_HP_BAR_GAP_PX - Fx.MONSTER_HP_BAR_H_PX,
		float(Defs.w_px(kind)), Fx.MONSTER_HP_BAR_H_PX)


## **The bolt color decision (`stage1-bosses.md` Stage D), extracted so a net can call it directly** — the
## same fix Stage B's own review already applied to the pattern indicator (`_pattern_indicator_draws_the_
## right_thing_for_the_right_state`'s box), needed here for the same reason: a whole-file source grep for
## `FIRE_LO`/`MonsterBolts.KIND_FIRE` stays green through a branch swap (fire drawn hen-purple, the hen drawn
## fire-colored) — the strings are all still *somewhere* in the file. Pulling the decision into its own pure
## function makes it callable with a bare kind int, no world, no tree.
static func bolt_glow(kind: int) -> Color:
	return Fx.FIRE_LO if kind == MonsterBolts.KIND_FIRE else Fx.MONSTER_BOLT_COLOR


static func bolt_core(kind: int) -> Color:
	return Fx.FIRE_HI if kind == MonsterBolts.KIND_FIRE else Fx.MONSTER_BOLT_CORE


## **The seat of one flame attached to a body. Pure static, so the nets call it directly.**
##
## **It is decided by id and index alone — the frame does not go in.** Change the seat per frame and the flames
##  **teleport every frame**, and that is noise, not fire (what moves is size only).
## **It is a hash, not `randi`.** Use `randi` and the same monster's fire stands somewhere different each frame,
##  and the nets cannot reproduce it either. This is `src/view/` so it is outside the determinism contract,
##  but **reproducibility is still needed.**
##
## **It is biased downward** (`MONSTER_BURN_LOW_BIAS`) — scattered evenly it reads as "glitter attached"
##  rather than "burning". Fire rises from below.
static func flame_pos(r: Rect2, id: int, i: int) -> Vector2:
	# Two large odd numbers are mixed — all it does is keep adjacent ids and is from landing in adjacent seats.
	var h := (id * 2654435761 + i * 40503) & 0xFFFFFF
	var fx := float(h & 0xFF) / 255.0
	var fy := float((h >> 8) & 0xFF) / 255.0
	fy = Fx.MONSTER_BURN_LOW_BIAS + (1.0 - Fx.MONSTER_BURN_LOW_BIAS) * fy
	return r.position + Vector2(r.size.x * fx, r.size.y * fy)


## The filled fraction of the hp bar. Clamped to 0-1 — negative hp is already blocked by `Monster.on_tick`'s
## `maxi(0, …)` (the doc's "there is one door that cuts hp"), but clamping once more on the screen side keeps
## the hp bar inside the box even if the table is misread.
static func hp_bar_fill_frac(hp: int, max_hp: int) -> float:
	if max_hp <= 0:
		return 0.0
	return clampf(float(hp) / float(max_hp), 0.0, 1.0)
