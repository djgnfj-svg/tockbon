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
## `stage1-bosses.md` Stage C - only `BossAi.carve_r` is read here (the charge impact's radius). The boss
## pattern machine itself stays owned by `monster.gd`/`boss_ai.gd`; this file only reacts to its outcome.
const BossAi := preload("res://src/actor/boss_ai.gd")

## **Pig contact damage** (`monsters-minimum`, "behavior (6)"). The arithmetic: invulnerability 4 ticks => the
##  real interval is 5 ticks (`character.on_tick` recorded "5-tick spacing = two hits") = 0.25s => 4 times per
##  second is the ceiling. 8 x 4 = 32/s => stay attached and you lose 100 HP in 3.1 seconds. **A proposed value
##  set by team-lead, and it has not had the user's acceptance.**
const PIG_CONTACT_DAMAGE := 8

## **The bull's contact-damage values** — all three live here, beside `PIG_CONTACT_DAMAGE`, because all go
## through the same one-lump contact check `_char_hit_by_monsters` already holds, not because they touch the
## grid (they do not). **Unaccepted, provisional, same status as every other tuning number in this plan.**
## Gore is a dedicated melee attack (higher than the pig's always-on contact) and being run over by a
## full-speed charge is chosen to hurt more than either.
const BULL_GORE_DAMAGE := 15
const BULL_CHARGE_CONTACT_DAMAGE := 20

## **Stage G fix list ③.** The slam shipped with no damage path at all — verify-run measured a squarely-landed
## slam dealing 0 damage across 26 overlapping ticks, and in room ① (no wood, so the fire ring never lands a
## single hit either — Risk 4's own finding) that made a full third of the bull's turns completely inert:
## time-to-death moved from 24.8s to 37.5s running laps and 20.4s to 26.1s retreating, a fight measurably
## *weaker* for a stage meant to add a threat. **"The fire ring stays what it is; the landing is what hurts"**
## (team-lead's own words) — this is the landing's own number, separate from `BULL_CHARGE_CONTACT_DAMAGE` and
## `BULL_GORE_DAMAGE` for the same reason those two are separate from each other.
const BULL_SLAM_CONTACT_DAMAGE := 18

var _grid: CellGrid
var _spell: SpellSim
var _char: Character

## The hen's peck and (`stage1-bosses.md` Stage D) the bull's fire breath. Not `spell_sim`
## (`monster_bolts.gd` header) — the bolt does not know about monsters.
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
		# **Stage D — fire bolts that hit terrain since the last tick become `cmd_ignite` here.** The same
		#  synchronous door the charge's carve already uses (`_carve_charge_impact`'s own comment on why),
		#  for the same reason: `_bolts.step()` (60Hz, below) already ran collision detection for every
		#  frame since the last tick, so there is no second clock to cross by applying it now, once, per
		#  tick. **This is also the "settles one tick after `_grid.step()`" contract the plan doc now states
		#  explicitly** — a bolt that hit wood on this tick's own frames lights on the *next* tick's `_grid.step()`.
		#  **This ordering is load-bearing, not decorative** — `net_monster._ignite_settles_after_this_ticks_
		#  grid_step` moves this block earlier and reads `aux_at` (remaining fuel) to catch it: applying
		#  ignition before `_grid.step()` lets that same tick's step already shave the freshly-lit cell once.
		for i in _bolts.ignite_count():
			_grid.apply(CellGrid.cmd_ignite(_bolts.ignite_cx(i), _bolts.ignite_cy(i), MonsterBolts.FIRE_IGNITE_R))
		_bolts.clear_ignitions()
		# (5) Monster on_tick — did magic hit a monster, and (`stage1-bosses.md` Stage B) advance any
		#  boss's pattern clock. **Being after `_char.on_tick` is a contract** (doc, "behavior (9)").
		#  Nothing is removed during iteration (CLAUDE.md's "removal during iteration" trap) — finish the
		#  walk, then remove from the highest index down.
		#
		# `boss_target_x` is a separate snapshot from the `target_x` the `step()` loop reads below — that one
		#  is read after `_char.step()` runs this frame (the comment there), and moving it here would make
		#  every kind's walk-toward-player one frame stale. A charge's locked direction does not need that
		#  freshness (`Monster.on_tick`'s own comment).
		var boss_target_x := roundi(_char.center().x)
		# **Stage E** — `boss_target_y` is the same "own snapshot" as `boss_target_x` above, for the same
		#  reason. Needed so the gore gate can check the boxes actually overlap vertically, not just
		#  horizontal closeness (verify-read's finding — a player on a ledge above the bull, only far
		#  *vertically*, used to win the gate every time and disable the boss completely).
		var boss_target_y := roundi(_char.center().y)
		var dead: Array[int] = []
		for i in _monsters.size():
			var m: Monster = _monsters[i]
			# **Read before `on_tick` — it consumes and clears the flag.** `stage1-bosses.md` Stage C: the
			#  carve must fire only for a real collision, not the safety-cap timeout that also ends a charge,
			#  and once `on_tick` runs there is no way left to tell the two apart.
			var was_charging_blocked := m.charge_blocked_now()
			# **Stage G — the same read-before-consume window, for the slam's landing.** `leap_landed_now()`
			#  is shared by the rooster's own leap (`m.kind` gates which kind's landing actually does anything —
			#  the rooster's landing terrain effect is `stage1-bosses.md`'s own open TBD, not built here).
			var was_leap_landed := m.leap_landed_now()
			m.on_tick(_spell, boss_target_x, boss_target_y)
			if was_charging_blocked:
				_carve_charge_impact(m)
			if was_leap_landed and m.kind == MonsterDefs.KIND_BULL:
				_ignite_slam_impact(m)
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
			# **Stage I — the reward gate.** `stage1-bosses.md` acceptance 8b: the reward is taken *first*, the
			#  wall collapse/water *second* — reversing the order is the named failure. Setting this here, in
			#  the same one place XP/money are awarded, is what makes "the reward is pending" true starting the
			#  exact tick death happens, not a tick later. **Only bosses** (`BossAi.has_pattern`) — a trash mob
			#  has no reward to gate anything on, and setting this for one would leave a dict entry nothing
			#  would ever clear (no debug key targets a kind that isn't a boss).
			# **This same gate fires for the rooster too** (`KIND_ROOSTER` also has a pattern) — but no water
			#  is wired to it anywhere yet. `stage.gd._room1_reward_status()` has the full account of that gap;
			#  a rooster kill correctly flips `boss_died`/`is_reward_pending`, and nothing downstream acts on it.
			if BossAi.has_pattern(dying.kind):
				_progress.set_boss_reward_pending(dying.kind)
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
			# **Aimed vs locked — a kind decision, not a pattern one** (`stage1-bosses.md` Stage D). The
			#  hen's peck aims at the player's live position (unchanged since `monsters-minimum`). The bull's
			#  breath uses `pattern_dir` instead, the same locked-direction idiom the charge already uses —
			#  re-aiming each bolt at the player's live position across one breath would read as the stream
			#  tracking the player even though no single bolt homes, and "no homing" is acceptance 15's word.
			var dir: Vector2
			var bolt_kind: int
			if m.kind == MonsterDefs.KIND_HEN:
				dir = (center - m.center()).normalized()
				bolt_kind = MonsterBolts.KIND_PLAIN
			else:
				dir = Vector2(float(m.pattern_dir), 0.0)
				bolt_kind = MonsterBolts.KIND_FIRE
			if _bolts.spawn(m.center().x, m.center().y, dir, bolt_kind):
				m.consume_fire()
	return ticked


## **(6) is one lump — do not put contact damage and bolt damage in two places.** `character.take_hit()`
##  already holds "fail if invulnerable", so calling several sources from separate places opens a path for
##  two hits on the same tick (the kind of accident that looks like the invulnerability check runs separately
##  per path). => Here, in one place, it tries **pig/bull contact -> bolt** in order. Once the first succeeds
##  (`take_hit` returns `true`), later attempts are blocked by `take_hit` itself via the invulnerability —
##  that is "one hit and that is the end of it".
##
## **The bolt is erased whether it hit or was blocked by invulnerability** (touch and it disappears —
##  `monster_bolts.consume_hits`). Whether the damage actually landed is told separately by `take_hit`'s return value.
##
## **The bull's contact damage (`stage1-bosses.md` Stage E, extended by Stage G's fix list) is gated on
## `pattern`, not on kind alone** — the pig is *always* a contact hazard ("the pig attaches with its body"),
## but the bull only deals contact damage while actively goring, charging or airborne in its slam; standing
## next to an idle, winding-up or stunned bull does nothing. This closes the scope hole Stage B's own review
## named: a charging bull used to pass straight through the player untouched (no contact path existed for
## `CHARGE` at all) — and the identical hole Stage G shipped for `LEAP`, closed here the same way.
## **`Pattern.LEAP and kind == KIND_BULL`, not `Pattern.LEAP` alone** — the rooster's own leap shares this
## exact pattern value and must not deal contact damage through this door (its own landing is the *player's*
## window to hit, not the reverse — acceptance 10). Since the bull only ever enters `LEAP` via its slam, this
## is the same discipline `leap_jump_vy_px`/`speed_mult`'s own bull branches already hold.
func _char_hit_by_monsters() -> void:
	for m: Monster in _monsters:
		var dmg := 0
		if m.kind == MonsterDefs.KIND_PIG:
			dmg = PIG_CONTACT_DAMAGE
		elif m.kind == MonsterDefs.KIND_BULL and m.pattern == BossAi.Pattern.GORE:
			dmg = BULL_GORE_DAMAGE
		elif m.kind == MonsterDefs.KIND_BULL and m.pattern == BossAi.Pattern.CHARGE:
			dmg = BULL_CHARGE_CONTACT_DAMAGE
		elif m.kind == MonsterDefs.KIND_BULL and m.pattern == BossAi.Pattern.LEAP:
			dmg = BULL_SLAM_CONTACT_DAMAGE
		if dmg <= 0:
			continue
		if _boxes_overlap(m.x, m.y, MonsterDefs.w_px(m.kind), MonsterDefs.h_px(m.kind),
				_char.x, _char.y, Character.W_PX, Character.H_PX):
			_char.take_hit(dmg, true)
	# **`consume_hits` now returns the damage, 0 meaning no hit** (`stage1-bosses.md` Stage D widened it from
	#  a bare `bool` so a fire bolt and a peck can carry different damage — that function's own comment).
	var bolt_dmg := _bolts.consume_hits(_char)
	if bolt_dmg > 0:
		_char.take_hit(bolt_dmg, true)


## Box versus box (integer px). A different place from `Body`'s circle and segment checks — this is contact
##  (rectangle versus rectangle), not a bolt trajectory, so the simpler check is the right one (the pig attaches
##  with its body, "behavior (6)").
static func _boxes_overlap(ax: int, ay: int, aw: int, ah: int, bx: int, by: int, bw: int, bh: int) -> bool:
	return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by


## **Stage C.** Same path as a blast's carve (`spell_sim._carve` -> `grid.apply(CellGrid.cmd_carve(...))`),
## called **synchronously** rather than through `enqueue()` — `enqueue()` exists for callers outside
## `world_step` (the shell's fire input), and collision detection already runs inside this same tick branch,
## so there is no second clock to cross.
##
## **The impact point is the box's leading edge, not its center** — `m.pattern_dir` says which side ran into
## the wall (+1 = right edge, -1 = left edge), and the vertical center of the box. Center it inside the box
## instead and half the carve lands on cells the bull's own body already stood clear of, nowhere near what
## actually stopped it.
func _carve_charge_impact(m: Monster) -> void:
	var r := BossAi.carve_r(m.kind)
	if r <= 0:
		return
	var w := MonsterDefs.w_px(m.kind)
	var h := MonsterDefs.h_px(m.kind)
	# **Not `m.x` for the leftward case.** Being blocked leftward means the wall's face sits one pixel
	#  *before* the box's own left edge (`m.x - 1`, the pixel `move_x` just failed to enter) — `m.x` itself
	#  is still inside the empty air the bull's own body already stood in. Using it centers the disc a full
	#  cell short of the wall (measured: right ate 4 cells, left only 3, on the same wall and radius).
	var edge_x := m.x + w if m.pattern_dir > 0 else m.x - 1
	var center_y := m.y + h / 2
	# **`floori`, not bare `/`** — the same reason `body.gd`'s `box_free` spends a paragraph on: bare integer
	#  division truncates toward 0, so a negative `edge_x` (a charge blocked one cell shy of the grid's left
	#  edge) would jump one cell *outward*. Harmless today only because `CellGrid.mat_at` returns `STONE`
	#  outside the grid — a fact that lives in a different file than this one.
	var cx := floori(float(edge_x) / float(Tuning.CELL_PX))
	var cy := floori(float(center_y) / float(Tuning.CELL_PX))
	_grid.apply(CellGrid.cmd_carve(cx, cy, r))


## **Stage G.** Called on the exact tick the bull's slam lands (`leap_landed_now()`, read before `on_tick`
## consumes it — the same reason `_carve_charge_impact` reads `charge_blocked_now()` first). **Reuses the
## ordinary fire door, `CellGrid.cmd_ignite`** — the same command Stage D's fire breath already applies, not a
## second ignition path, so "every constraint on the bull's fire applies unchanged" (the design doc's own
## words) needs no separate proof: a cell with no fuel still refuses (room ①'s own reason fire never marks it),
## and wood still spreads to its neighbors on its own.
##
## **The impact row is the floor the bull landed on, not its own box's rows** — `m.y + h` is the pixel just
## below the box's feet, the same convention `Body.standing_in_fire`'s own header explains ("the cells you are
## standing in are empty... fire is attached to the cells under your feet"). The points spread outward from
## the box's horizontal centre, not its landing edge — a slam has no directional "leading edge" the way a
## charge's impact does (`_carve_charge_impact`'s own `pattern_dir` branch), it slams straight down.
func _ignite_slam_impact(m: Monster) -> void:
	var r := BossAi.slam_ignite_r(m.kind)
	if r <= 0:
		return
	var spread_cells := BossAi.slam_ignite_spread_cells(m.kind)
	var points := BossAi.slam_ignite_points(m.kind)
	var w := MonsterDefs.w_px(m.kind)
	var h := MonsterDefs.h_px(m.kind)
	var center_cx := floori(float(m.x + w / 2) / float(Tuning.CELL_PX))
	var floor_cy := floori(float(m.y + h) / float(Tuning.CELL_PX))
	# **Symmetric outward, centred on the odd middle index** — `points`=5 gives offsets
	#  -2,-1,0,1,2 (in units of `spread_cells`), so one point always lands directly under the impact and the
	#  rest fan out evenly on both sides, matching "fire thrown outward" rather than "fire thrown one way".
	var half := (points - 1) / 2
	for i in points:
		var offset_cells := (i - half) * spread_cells
		_grid.apply(CellGrid.cmd_ignite(center_cx + offset_cells, floor_cy, r))


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


## Read-only queries — the view sees the hen's/bull's bolts only through these (stage 7, `bolt_kind`
## added Stage D so the screen can tell a fire bolt from a peck).
func bolt_count() -> int:
	return _bolts.count()


func bolt_x(i: int) -> float:
	return _bolts.x(i)


func bolt_y(i: int) -> float:
	return _bolts.y(i)


func bolt_kind(i: int) -> int:
	return _bolts.kind(i)


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
