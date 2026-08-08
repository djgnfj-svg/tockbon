extends RefCounted
## The world lives one frame — integer divider, command queue, **tick order**.
##
## **This file exists for one reason: "the order lives in only one place".**
##  If the order lived only inside the shell (`src/stage/`), the nets could not stand up a scene and would
##  **copy that order by hand.** At that moment **the nets start measuring something different from the game**,
##  and nothing barks when the two diverge.
##  => The shell and the nets **both call `frame()`.**
##
## **It does not know the screen** — `src/actor/` cannot reference `src/view/` or `src/stage/` (`net_layers`
##  measures it). => View notifications (trails, flashes, uploads) do not come in here. `frame()` returns
##  **"a tick ran this frame" as a bool**, and the shell looks at that and hits the screen.
##
## **It does not know the scene tree either** (`RefCounted`). That is why the nets can run the whole world headless.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const SpellSim := preload("res://src/sim/spell_sim.gd")
const Character := preload("res://src/actor/character.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Monster := preload("res://src/actor/monster.gd")
const MonsterDefs := preload("res://src/actor/monster_defs.gd")
const MonsterBolts := preload("res://src/actor/monster_bolts.gd")
const Progress := preload("res://src/actor/progress.gd")

## **Pig contact damage** (`monsters-minimum`, "behavior (6)"). The arithmetic: invulnerability 4 ticks => the
##  real interval is 5 ticks (`character.on_tick` recorded "5-tick spacing = two hits") = 0.25s => 4 times per
##  second is the ceiling. 8 x 4 = 32/s => stay attached and you lose 100 HP in 3.1 seconds. **A proposed value
##  set by team-lead, and it has not had the user's acceptance.**
const PIG_CONTACT_DAMAGE := 8

var _grid: CellGrid
var _spell: SpellSim
var _char: Character

## The hen's bolts. Not `spell_sim` (`monster_bolts.gd` header) — the bolt does not know about monsters.
var _bolts := MonsterBolts.new()

## **The monster array is held here — let the shell hold its own and "the world" lives in two places.**
##  The view sees it only through `monster_count()` and `monster_at()` below (read-only queries)
##  (`monsters-minimum` stage 1).
var _monsters: Array[Monster] = []
## `reset()` does not revert this value — reuse an id and "number 37 died" stops being unique within the
##  session and the diagnostics get blurry. There is no reason to revert it (the view does not hold ids).
var _next_monster_id := 1

## **The death notification — this is the view's only way to know "who died this time".** A dead monster is
##  removed from `_monsters` immediately (doc, "behavior (10)" — monsters disappear, they do not go down like
##  the player), so looking at the array alone cannot tell you. **Exactly the same idiom as the blast
##  notification** — cleared at the start of the tick.
var _died_x: Array[int] = []
var _died_y: Array[int] = []
var _died_kind: Array[int] = []

## **Owned here, not by the shell** — the same reason `_monsters` is owned here (`monsters-minimum` stage 1's
##  comment above): let the shell hold its own copy and "the world" lives in two places. `stage.gd` only reads
##  it through `progress()` below to draw the HUD.
var _progress := Progress.new()

## Commands sit in the queue **carrying "which tick do I apply to"**. Without it, later rescheduling is impossible.
##  In single player the local input fills it and in multiplayer the server does — the applying code is unchanged.
var _queue: Array[Dictionary] = []

## The tick is an **integer divider** (`Tuning.TICK_DIVIDER`), not a float accumulator. Use an accumulator and
##  the tick boundary wobbles with frame time and splits differently per client — in multiplayer the tick
##  number is state.
var _phase := 0

## The fire count is read by the shell's HUD diagnostics (fires 0 = the left click is not reaching · fires >
##  impacts = it vanished outside the grid).
##  The counting has to happen **right after** `fire()` returned true — count at queue time and rejected
##  commands get counted too.
var _fire_count := 0

## `_init` received a null. **Barking alone lets the nets measure nothing** — the runner cannot see stderr and
##  `expect_error` is only an amnesty declaration, so the check would not go red even if the bark disappeared.
##  => Leave a trace of the bark **as a value** so that "did it bark" can be measured.
## And thanks to this branch a broken world stops quietly **instead of spewing an engine error every frame** —
##  the line naming the cause came out once, above.
var _broken := false


## If any one of the three is missing there is no world.
## **What this check blocks is not "the person who writes null by hand" but "the person who moves a declaration".**
##  If the shell's `var _world := WorldStep.new(_grid, _spell, _char)` line moves **above** the `_grid`
##  declaration, all three are null while **not one character of text changes.**
##  Measured: in that state 1085 nets were **all green**, and only the game barked every frame and stopped.
##  => A text check cannot catch it in principle, so **the code holds the contract itself.**
##  On the normal path nothing happens — the behavior is unchanged.
func _init(grid: CellGrid, spell: SpellSim, ch: Character) -> void:
	if grid == null or spell == null or ch == null:
		push_error("WorldStep: one of the three worlds is null - check the shell's declaration order")
		_broken = true
	_grid = grid
	_spell = spell
	_char = ch


## One frame. Returns true **only on frames where a tick ran.**
##
## **The order below is a contract** — change it and the result changes, and in multiplayer that is desync.
##   1. `_drain_queue()`   external commands (firing)
##   2. `_grid.step()`     the grid lives one tick (fire)
##   3. `_spell.step()`    projectiles fly against **the grid after it moved**
##
## **The character is 60Hz and the sim is 20Hz.** Tie the character to ticks and the controls stutter.
##  It is host-authoritative, so there is no reason to tie it to ticks (GDD multiplayer table).
## Why it runs **after** the tick: this frame you walk over the terrain the blast just changed.
## **`jump` is "was it pressed this frame" and `jump_held` is "is it held now"** — the variable jump clips the
##  rise with the latter (`character.step`). No default is given: not passing it silently gives a short jump.
func frame(dt: float, axis: float, jump: bool, jump_held: bool) -> bool:
	if _broken:
		return false
	var ticked := false
	_phase += 1
	if _phase >= Tuning.TICK_DIVIDER:
		_phase = 0
		# The death notification is cleared at the start of the tick — the same place as the blast
		#  notification (the start of `spell.step()`).
		_died_x.clear()
		_died_y.clear()
		_died_kind.clear()
		_drain_queue()
		_grid.step()
		_spell.step(_grid)
		# **The notifications are read here — *inside* the tick branch.** Call it every frame and the
		#  notification arrays stay alive until the next `spell.step()`, so **one hit becomes three**
		#  (plan section 6, risk 1).
		#  The invulnerability eats two of them so it looks normal on screen, and the 3x only shows up in
		#  continuous damage.
		_char.on_tick(_spell)
		# (5) Monster on_tick — did magic hit a monster. **Being after `_char.on_tick` is a contract**
		#  (doc, "behavior (9)"). Nothing is removed during iteration (CLAUDE.md's "removal during iteration"
		#  trap) — finish the walk, then remove from the highest index down.
		var dead: Array[int] = []
		for i in _monsters.size():
			var m: Monster = _monsters[i]
			m.on_tick(_spell)
			if m.hp <= 0:
				dead.append(i)
		for j in range(dead.size() - 1, -1, -1):
			var idx := dead[j]
			var dying: Monster = _monsters[idx]
			_died_x.append(dying.x)
			_died_y.append(dying.y)
			_died_kind.append(dying.kind)
			# **Awarded in the same one place `_died_*` is built** — the plan's own instruction. `dead` holds
			#  exactly the monsters that crossed `hp <= 0` *this* tick, and each is removed from `_monsters`
			#  in this same pass, so this line runs **once per death, never once per tick a corpse sits at 0 hp.**
			_progress.add_xp(MonsterDefs.xp_of(dying.kind))
			_progress.add_money(MonsterDefs.money_of(dying.kind))
			_monsters.remove_at(idx)
		# (6) **Was the player hit by a monster or a bolt — it must be after **both** `_char.on_tick` and the
		#  monster on_tick** (doc, "behavior (9)"). Put it earlier and a monster dying on that tick gets one
		#  more hit in.
		#  **`invuln_left` is only ever set inside `_char.on_tick()`** — decrement it here too and the
		#  invulnerability becomes 3 ticks instead of 4. So this place only calls `take_hit` and never
		#  subtracts directly.
		_char_hit_by_monsters()
		ticked = true
	_char.step(_grid, dt, axis, jump, jump_held)
	_bolts.step(_grid, dt)
	# **Being after the character is a contract** (`monsters-minimum` stage 1). `_next_axis` takes the player's
	#  center as the target, so looking at **where the character went this frame** is the correct thing.
	#  The target is `_char.center()` rounded **per axis** with `roundi` into px (acceptance 10: center to center).
	#  The `Vector2i(Vector2)` constructor truncates toward 0 rather than rounding, so it is not used here.
	var center := _char.center()
	var target_x := roundi(center.x)
	var target_y := roundi(center.y)
	for m: Monster in _monsters:
		m.step(_grid, dt, target_x, target_y)
		if m.ready_to_fire(target_x):
			var dir := (center - m.center())
			if _bolts.spawn(m.center().x, m.center().y, dir.normalized()):
				m.consume_fire()
	return ticked


## **(6) is one lump — do not put pig contact and hen bolts in two places.** `character.take_hit()` already
##  holds "fail if invulnerable", so calling the two sources from separate places opens a path for two hits on
##  the same tick (the kind of accident that looks like the invulnerability check runs separately per path).
##  => Here, in one place, it tries **pig -> hen bolt** in order. Once the first succeeds (`take_hit` returns
##  `true`), later attempts are blocked by `take_hit` itself via the invulnerability — that is "one hit and that
##  is the end of it".
##
## **The bolt is erased whether it hit or was blocked by invulnerability** (touch and it disappears —
##  `monster_bolts.consume_hits`). Whether the damage actually landed is told separately by `take_hit`'s return value.
func _char_hit_by_monsters() -> void:
	for m: Monster in _monsters:
		if m.kind != MonsterDefs.KIND_PIG:
			continue
		if _boxes_overlap(m.x, m.y, MonsterDefs.w_px(m.kind), MonsterDefs.h_px(m.kind),
				_char.x, _char.y, Character.W_PX, Character.H_PX):
			_char.take_hit(PIG_CONTACT_DAMAGE, true)
	if _bolts.consume_hits(_char):
		_char.take_hit(MonsterBolts.BOLT_DAMAGE, true)


## Box versus box (integer px). A different place from `Body`'s circle and segment checks — this is contact
##  (rectangle versus rectangle), not a bolt trajectory, so the simpler check is the right one (the pig attaches
##  with its body, "behavior (6)").
static func _boxes_overlap(ax: int, ay: int, aw: int, ah: int, bx: int, by: int, bw: int, bh: int) -> bool:
	return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by


## Seats it as a command to be applied on the next tick. **The tick number comes from the grid** — let the
##  caller count and there are two clocks, and then commands appear that "went in and never come out".
##
## **It goes through the same door as `frame()`.** Leave only this one open and a broken world becomes "the
##  frame stops politely but only the left click explodes", and that is the rule having two copies.
func enqueue(cmd: Dictionary) -> void:
	if _broken:
		return
	_queue.append({"tick": _grid.get_tick() + 1, "cmd": cmd})


## **The `keep` branch has no consumer right now** — `enqueue` always attaches `tick + 1` and `target` is the
##  same, so everything drains on this tick. It is a seam for multiplayer (where the server sends future-tick
##  commands), and until then, read it knowing it is **a dead branch.**
func _drain_queue() -> void:
	if _queue.is_empty():
		return
	var target := _grid.get_tick() + 1
	var keep: Array[Dictionary] = []
	for e: Dictionary in _queue:
		if int(e["tick"]) > target:
			keep.append(e)
			continue
		var cmd: Dictionary = e["cmd"]
		# Commands split into two sims. **Not sharing the `kind` key is this branch's safety device** —
		#  use the same key and the two enums' numbers overlap so the wrong command runs, and if the value
		#  happens to be in a valid range, **with no error at all** a fire becomes a fill.
		if cmd.has("spell_kind"):
			# **Go down and you cannot fire.** Without blocking it, neither the staff nor the muzzle is drawn
			#  while **the magic still comes out and the recoil flies the corpse around** (measured: fires
			#  10 -> 11, 59px upward).
			# **Blocked here, not in the shell** — the shell only sees local input, but **every command passes
			#  through this door** (in multiplayer the server fills it). The same reason the rune check was put
			#  in `spell_sim.fire()`.
			if _char.downed:
				continue
			if _spell.fire(cmd):
				_fire_count += 1
				# **This is *after* `fire()` returned true.** Hook it at queue time and even rejected shots
				#  push you, giving "it did not fire but I got pushed" — and that reads as a malfunction.
				_char.recoil(int(cmd.get("adx", 0)), int(cmd.get("ady", 0)))
			continue
		_grid.apply(cmd)
	_queue = keep


## Called by the shell's debug spawn key (M). The id if it was made, 0 if not.
##  **Over the cap it does not make one — it does not discard an existing one.** The same idiom as the bolt cap
##  (stage 6): discard and "I spawn and some do not come out" reads as a malfunction.
##
## **Out-of-grid coordinates are blocked here — not in `stage.gd`.** verify-look found it by measurement:
##  `get_viewport().get_mouse_position()` is the OS cursor's real position, so **when the cursor is outside the
##  game window** the world x comes in as something like -983. Outside the grid, that monster makes a landing it
##  can never reach and never appears on screen while **eating one of the 20-monster cap.**
##  => **Why it lives here**: `spawn_monster` is the **only door** that makes a monster (the same door as the cap
##  check above), so putting it in the shell means the nets cannot measure it headless (`stage.gd` needs a scene
##  to run) and future callers (server spawning and so on) would each have to write it again. Placing it beside
##  `_broken` and the cap check gathers "the three conditions for making a monster" in one place.
func spawn_monster(kind: int, px: int, py: int) -> int:
	# The same door as `enqueue` (above) — if the array grew and the HUD number rose in a broken world, it
	#  would be "the frame stops politely but only M keeps growing", and that is the rule having two copies.
	if _broken:
		return 0
	if _monsters.size() >= MonsterDefs.MAX_MONSTERS:
		return 0
	# The whole box must be inside the grid's pixel range — look only at the top-left and the box survives
	#  sticking out past the right or bottom boundary. No error is raised (it is input a debug key can commonly pass).
	var w_px := MonsterDefs.w_px(kind)
	var h_px := MonsterDefs.h_px(kind)
	if px < 0 or py < 0 \
			or px + w_px > CellGrid.W * Tuning.CELL_PX \
			or py + h_px > CellGrid.H * Tuning.CELL_PX:
		return 0
	var id := _next_monster_id
	_next_monster_id += 1
	_monsters.append(Monster.new(id, kind, px, py))
	return id


## Read-only queries — the view sees it only through these. Let the shell hold its own array and "the world"
##  lives in two places.
func monster_count() -> int:
	return _monsters.size()


func monster_at(i: int) -> Monster:
	return _monsters[i]


## The monsters that died this tick. **The next `frame()`'s tick branch clears it** — the same as the blast notification.
func died_count() -> int:
	return _died_x.size()


func died_x(i: int) -> int:
	return _died_x[i]


func died_y(i: int) -> int:
	return _died_y[i]


func died_kind(i: int) -> int:
	return _died_kind[i]


## Read-only queries — the view sees the hen's bolts only through these (stage 7).
func bolt_count() -> int:
	return _bolts.count()


func bolt_x(i: int) -> float:
	return _bolts.x(i)


func bolt_y(i: int) -> float:
	return _bolts.y(i)


## Called by the stage reset (R). **It reverts only what this object holds** — the grid, the projectiles and
##  the character have their own resets, and touching them once more here makes two places doing the reverting.
##
## **`_phase` is not touched.** A stage reset is not an event that changes the tick phase —
##  set it to 0 and the next tick after the frame R was pressed is delayed by up to 2 frames.
## `_monsters.clear()` — the `monsters-minimum` doc's "screen" section pinned "the place that clears is
##  `world_step.reset()`". `_next_monster_id` is not reverted (its declaration above).
func reset() -> void:
	_queue.clear()
	_fire_count = 0
	_monsters.clear()
	_died_x.clear()
	_died_y.clear()
	_died_kind.clear()
	# The bolts are cleared too — without it, every press of R leaves bolts from the dead experiment and they
	#  contaminate the next acceptance (the same reason `monsters-minimum`'s "screen" pinned "revert every counter").
	_bolts = MonsterBolts.new()
	# **Progress reverts here too, in this same one place** — not a separate call from `stage.gd`, or the day
	#  comes when only one of the two reset paths gets touched and R quietly stops reverting it.
	_progress.reset()


## Read by the render interpolation. **The point is not making one more clock** — the moment the view
##  accumulates its own `delta` there are two clocks, and projectiles slip at the tick boundary.
func phase() -> int:
	return _phase


func fire_count() -> int:
	return _fire_count


## Read-only — the shell's HUD and the nets read `xp`/`level`/`money`/`pending_picks` straight off the
## returned object, the same idiom as `monster_at(i)` returning a `Monster` directly.
func progress() -> Progress:
	return _progress
