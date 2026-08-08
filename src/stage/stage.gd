extends Node2D
## The stage — **the shell. It won't survive into the real game.**
##  Do not mix it with the sim (`src/sim/`), the character (`src/actor/`) or the screen (`src/view/`).
##  That boundary is the whole point of the folders.
##
## **Tick order, the command queue and the divider are not here** — `src/actor/world_step.gd` holds them.
##  If the shell copies that order again, the nets end up measuring something other than the game
##  (`net_damage` measures it).
##  => What is left here is only **hitting the screen on frames where a tick ran.**

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const CellRenderer := preload("res://src/view/cell_renderer.gd")
const SkyBackground := preload("res://src/view/sky_background.gd")
const Fx := preload("res://src/view/fx_tuning.gd")
const CharacterView := preload("res://src/view/character_view.gd")
const SpellView := preload("res://src/view/spell_view.gd")
const BlastFx := preload("res://src/view/blast_fx.gd")
const CircleWindow := preload("res://src/view/circle_window.gd")
const Character := preload("res://src/actor/character.gd")
const WorldStep := preload("res://src/actor/world_step.gd")
const Aim := preload("res://src/actor/aim.gd")
const SpellCircle := preload("res://src/actor/spell_circle.gd")
const SpellSim := preload("res://src/sim/spell_sim.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const StageInput := preload("res://src/stage/stage_input.gd")
const MonsterView := preload("res://src/view/monster_view.gd")
const MonsterDefs := preload("res://src/actor/monster_defs.gd")
const WaterSource := preload("res://src/sim/water_source.gd")

## No longer a constant but a re-export of `terrain_map_generated.gd` — it follows the painted region's size verbatim.
##  It pairs with the re-export at the `MAP` declaration below.

## The character's starting position (tiles). On the ground at the left end of the stage 1 map.
##
## **Redraw the map and this value must be fixed with it — nobody barks.**
## It actually happened: the map was redrawn 312x126 -> 400x48 while this constant stayed `(3, 30)`, so
##  **y30 fell below the ground surface (y20)** and the character started by **dropping onto the floor of a
##  sealed underground cave (y44).** The reachable range confirmed by BFS was **a single row of cave floor**,
##  and a 6-tile crust cannot be pierced with `carve_r` (2 cells).
##  => **Launch the game and the surface is never seen at all. Not one line of error is raised.**
## The nets can't catch it either — `net_tables._stage_map` measures only the map's **shape** and never looks
##  at **where inside it the spawn sits.**
const SPAWN_TILE := Vector2i(3, 19)

## Initial terrain. `#` stone · `=` wood · `.` empty. One tile = 8x8 cells = 32px.
##
## **This array is no longer edited by hand.** The real original is `stage.tscn`'s `Terrain` (TileMapLayer),
##  painted with the mouse in the Godot editor. `MAP` is only a verbatim re-export of
##  `terrain_map_generated.gd` (auto-generated) — Terrain must be edited and
##  `tools/stage/bake_terrain.gd` re-run for it to take effect.
##  **Why a re-export**: because `net_tables.gd`'s `_wood_clumps` and `_stage_map` measure `Stage.MAP` and
##  `Stage.build_terrain_into()` directly — rename them and that net becomes a fake net measuring a dead
##  branch. The measurement grounds below (partition thickness · terrain height) stay alive even when painted.
## **Not one character of this ASCII changed while tiles went 16px -> 32px** — because it is all written
##  **in tile units.**
##
## **The stage is bigger than one screen. That is why the camera follows** (`camera_center` below).
##  Grid = 512x288 cells = **64x36 tiles = 2048x1152 world px** · visible on screen = **960x540 = 30x16.9 tiles**.
##
## **Writing down exactly what was lost by abandoning the static camera — blasts can go off screen.**
##  The old contract was "the whole stage fits in one screen", and its reason was
##  "if the stage crosses into the margin, **some of the 8 spread bolts detonate where they can't be seen**
##  and the user reads it as 'it didn't go off' — v1 got burned exactly that way by its floor slab".
##  => **That reason has not gone away. It simply can no longer be prevented** — a spread bolt's range
##   (40 tiles) is longer than the visible width (30 tiles), so firing horizontally makes
##   **off-screen impacts happen in principle.**
##  What is left is **"at least my surroundings are always visible"**, and `net_tables._stage_map` measures that.
##  If something reads as "it didn't go off" again, **this is the cause.** Zoom the camera out, shrink the
##   stage, or shorten the range — all three are decisions outside this file.
##  If the stage crosses into the margin, **some of the 8 spread bolts detonate where they can't be seen**,
##   and the user reads it as "it didn't go off". v1 stood its floor slab in the margin and got burned exactly that way.
##  => **The stage must sit entirely within the visible edge.**
##
## It is a box — stone floor, ceiling and side walls. **All 8 spread bolts hit something.**
##  The ones that went upward do not vanish into thin air.
## Random terrain is not used — differ every time and two combinations cannot be compared (design, "the stage").
##
## **Wood is broken up with stone into several clumps. This is the most important line in this map.**
##  Left connected as one clump, **wherever fire catches everything burns in the end** — measured, the final
##  wood for key 1 (no glyph), key 4 and key 5 all converged on 48. The "after it settles" axis then fails
##  to distinguish the combinations at all.
##  => Broken up, **how many clumps caught fire** differs per combination (GDD, "where you put fuel is level design").
##
## **Partition thickness was not set as "a thickness blasts cannot pierce".** That criterion had a false
##  premise — even when a blast pierces the partition, that spot becomes **empty**, and **fire cannot cross
##  empty either** (`net_fire` measures it). That is, a blast cannot join clumps and **only widens the gap**,
##  so one cell of stone makes the isolation permanent.
## => The criterion that actually matters is **"a width a small ignition source cannot light both clumps across"**:
##    rune trace 6 cells · generation 1 blast's ignition 9 cells => a partition of **3 tiles = 24 cells** blocks both.
##  `net_tables` measures the clump count and this gap. Touch the map and that goes red first.
##
## **A blast's radius was halved (user judgment) and one axis of this design died —
##  the map was not fixed and the nets do not go red. So it is written here.**
##  The four values used to be `6 < 24 · 18 < 24 · 36 > 24`, and **the point was that the last inequality
##  was flipped** — "a generation 0 blast's ignition crosses the partition **deliberately.** A big blast
##  setting a wide area alight is that combination's character".
##  Now generation 0's ignition is 36 -> **18 cells**, so `18 < 24` => **even a big blast cannot light two clumps at once.**
##  **The nets cannot catch this** — `net_tables._wood_clumps`'s `need` **deliberately left generation 0 out**,
##   and a missing axis draws no bark even when its direction flips. Do not read it as "it's green, so the design lives".
##  => To bring back "a big blast carries fire to the next clump", **narrow the partition to 2 tiles (16 cells)** —
##   then `9 < 16 · 6 < 16 · 18 > 16` stands the three inequalities back up. **It was not done**: what the
##   user spoke about was the blast range only, and changing the map along with it makes it impossible to
##   tell what the screen difference came from.
##
## **Terrain height is split against the character's jump (108px = 3.4 tiles).** That is the whole of the stage design:
##   · pillars 3 tiles (96px) · wood 2 tiles (64px)  -> **crossed by walking/jumping.** The stage can be roamed
##   · the right stone wall 12 tiles                 -> **it must be pierced to pass.** This is where the GDD's
##     "pierce that wall and you can get through" becomes countable on screen
##  Pillars were first stood at 6 tiles and **the character got trapped in the left corner** — that makes
##   measurement 3 ("does moving the character while firing feel right in the hand") unmeasurable to begin with.
const TerrainMap := preload("res://src/stage/terrain_map_generated.gd")
const MAP_W: int = TerrainMap.MAP_W
const MAP_H: int = TerrainMap.MAP_H
const MAP: Array[String] = TerrainMap.MAP
const MAP_CHARS: Dictionary = TerrainMap.MAP_CHARS

## **Debug loadouts — this stage's measuring instrument.** Firing combinations alternately must be doable
##  within seconds for acceptance 1 and 2 (the difference of adding and removing a glyph · the difference
##  of changing the order) to be measurable.
##
## **4 and 5 are the whole of this stage.** The same two glyphs, only the order differs:
##   4 spread -> blast = it spreads in 8 directions and **each of the spread ones detonates** -> eight holes
##   5 blast -> spread = it detonates big first and **spreads into 8 branches from that spot** -> one big hole + eight embers
##  => If the terrain marks differ, acceptance 2 is true.
##
## A list holding spread twice is never built here in the first place (GDD, "one spread per magic circle").
##  Even so `spell_sim.fire()` looks once more at the command boundary — the network does not go through this table.
## Numbers that don't exist aren't in the table, and the HUD shows **only the numbers that exist** (`_loadout_help` below).
const LOADOUTS: Dictionary = {
	1: [],
	2: [Glyph.GLYPH_SPREAD],
	3: [Glyph.GLYPH_BLAST],
	4: [Glyph.GLYPH_SPREAD, Glyph.GLYPH_BLAST],
	5: [Glyph.GLYPH_BLAST, Glyph.GLYPH_SPREAD],
}

## **It must be drawn **before** the grid** — `stage.tscn`'s node order is the draw order.
##  And that alone is not enough to see it: `cell_grid.gdshader` must **cut empty cells out as transparent**
##   (`cell_renderer` injects `empty_id`). **The three are one set and missing just one hides it silently.**
@onready var _sky: SkyBackground = $SkyBackground
@onready var _renderer: CellRenderer = $CellRenderer
@onready var _input: StageInput = $StageInput
## **The number one way this shell dies is `mouse_filter`.** Firing is left click while the HUD is a `Control`.
##  The moment a `Panel`, `ColorRect` or container is laid over as a backing plate, the default STOP eats
##  left click wholesale, and **no error is raised while every net stays green.** => Every `Control` under
##  HUD is `mouse_filter = 2` (IGNORE).
##  Do not sweep them at runtime and force-fix them — that turns the values written in the `.tscn` into
##   **a meaningless false knob**, and later, when a modal must block what is behind it with STOP, it
##   silently overturns that (measured in v1).
@onready var _hud: Label = $HUD/Stats
## **Health is a different node from `HUD/Stats`.** Writing them together does not make two places — rather,
##  `Stats` **hides** when the assembly window opens (`_toggle_assembly`). With health in there, "am I on
##  fire" disappears from the screen entirely while assembling (design, "the screen").
@onready var _hp_label: Label = $HUD/Health
## **The camera follows the character.** The old contract ("shake only · its position is the viewport center,
##  so the transform is the identity") is **dead** — the screen scale doubled, shrinking the visible world to
##  960x540, so the stage (2048x1152) does not fit in one screen. With a static camera the character is off screen.
##
## **Two axes ride on one node**: `position` = following (`camera_center` below) · `offset` = shake.
##  **Do not mix them** — add shake into `position` and the next frame's following overwrites it, and the shake vanishes.
## The viewport -> world coordinate conversion **must** undo the canvas transform (`stage_input._to_world`).
##  **That now applies to following, not just shake** — without undoing it, aim drifts by however far the camera moved.
@onready var _camera: Camera2D = $Camera2D
## The assembly window sits under `HUD` (a `CanvasLayer`) — put it under `Node2D` and it shakes along with the screen shake.
##  **The shell only tells it to open and close.** The window knows its own state and uses its own coordinates.
@onready var _circle_window: CircleWindow = $HUD/CircleWindow
@onready var _monster_view: MonsterView = $MonsterView
@onready var _char_view: CharacterView = $CharacterView
@onready var _spell_view: SpellView = $SpellView
@onready var _blast_fx: BlastFx = $BlastFx
## **An editor-only original.** The terrain that actually runs is `MAP` (above, the re-export of
##  `terrain_map_generated.gd`) and the screen is drawn by `_renderer` (a `CellRenderer` reading the grid) —
##  leave this node visible and it paints over destroyed spots as if they were never pierced.
##  It is hidden immediately in `_ready()`.
@onready var _terrain: TileMapLayer = $Terrain

var _grid := CellGrid.new()
var _char := Character.new()
var _spell := SpellSim.new()

## **The single source of the equipped state.** Both the debug keys and (from now on) the assembly window
##  touch this one thing — if the shell holds a separate copy of the packed list it becomes "I pressed a key
##  but the muzzle is unchanged", and **not one error is raised** (plan §1).
var _circle := SpellCircle.new()

## **The preset number is not held.** The moment the assembly window touches a glyph, "the last number
##  pressed" and the actual equipment diverge (plan §1 · risk 9) — it was removed from the HUD, so there is
##  no longer a reason to hold it either.
##  **Erasing the number is the last piece of "the state is one".**

## **This one thing is what pushes the world.** It holds the three above (`_grid`, `_char`, `_spell`) by
##  **being handed** them — if the shell pushes separately there are two sets of order, and that is how this
##  file dies.
##  Declaration order is a contract. Declare it before those three and it is born holding `null`.
var _world := WorldStep.new(_grid, _spell, _char)

## The fire count and the impact count are printed **separately** — the two diverging is itself the diagnosis (HUD).
##  fire 0 = left click is not reaching (`mouse_filter`) · fire > impact = it left the grid and vanished.
##  The fire count is held by `_world` — that is where a command is actually accepted.
## **This number is the nets' proxy for acceptance 2** — spread->blast must be 8, blast->spread 1.
##  If they do not separate on screen while only this number is right, that is the signal this stage must stop.
var _blast_count := 0

## **The rain source toggled with K. `null` = off.** `water_source.gd` holds all of the state and counting —
##  here it knows only "is there one" and "call it every tick" (that file's header, "where to put it").
var _water_source: WaterSource = null

## **Debug camera zoom (`-` / `=`).** 1.0 is the play scale; 0.075 fits all 400x48 tiles on the 960x540 screen.
##  The steps are held as a list rather than a multiply so that "the whole map" is **exactly reachable** —
##  with `zoom *= 0.5` the map-wide value falls between two steps and can never be landed on.
## **This is a shell debug view, not a design axis.** Nothing in the sim reads it, and the stage does not
##  survive into the real game.
const ZOOM_STEPS: Array[float] = [1.0, 0.5, 0.25, 0.125, 0.075]
var _zoom_step := 0

## **Material cell counts are counted only every N ticks. Count them every frame and 5% of the CPU just vanishes.**
##
## **Measured** (implementation · headless · with the stage scene's actual functions):
##
##      count_material once                             **555us**  (4,128,768 cells)
##      before the fix — twice per frame (stone, wood)  **65,983us/s = 6.6% of CPU**
##      3 times if water had not been throttled too     **99,728us/s = 10.0% of CPU**
##      after the fix — 3 times every 20 ticks          **about 1,677us/s = 0.17%**  => **39x**
##
##  The last line is "the throttled path 12us/s" + "3 x 555us actually counted once per second".
##   **Do not read the 12us alone as "free"** — the counting work itself does not disappear, it only becomes rare.
## **Why the place to fix is the caller** is in the `cell_grid.count_material` comment — that function is the
##  door for the nets and the stage, so it stays. That comment used to say "~20us · 0.24%", and
##  **it quietly became false when the grid grew 28x.**
##
## **Why not incremental**: counting in `_write_cell` is always exact, but **`_reset` (`fill`) and
##  `_write_water` (only when it changes the material) must be passed through too**, and if one of the three
##  diverges it is **quietly wrong.**
##  This is **a debug display of the shell, which won't survive into the real game** — at the cost of delaying
##  accuracy by a second, a second counting rule is not created in the sim.
##  **If it becomes a value that must always be right, switch to incremental then.**
## **The screen goes up to 1 second stale.** The things that must be seen in real time (active chunks ·
##  burning cells · FPS) were not throttled — those are all O(1) queries.
##
## **The water cell count is not "the sum of amounts". Do not read acceptance 3 (total conservation) here.**
##  When water spreads, the same amount is held in **more cells**, so this number **grows.** That is normal.
##  There is no cheap way to produce the sum of amounts right now — sweeping `_aux` in GDScript is 62,676us.
##   => **Acceptance 3 is measured by value in the nets** (`net_water`'s `_water_total_is_conserved`).
##   The screen is not the place for it.
const HUD_COUNT_TICKS := 20
var _stone_cells := 0
var _wood_cells := 0
var _water_cells := 0
## **It starts negative so that it counts right on the first frame.** Left at 0, everything reads 0 until
##  tick 20, and a user who pressed F **reads the key as dead for a second.**
var _hud_count_tick := -HUD_COUNT_TICKS


func _ready() -> void:
	# **The font size is pushed in here.** `Label` uses the engine default (16), and the old screen scale of
	#  2.0 was implicitly making that 32px on screen — the scale became 1.0 and **only the size did not follow.**
	#  **Why here and not the scene** is in the `fx_tuning.HUD_FONT_SIZE` comment (presentation constants in one file).
	for label: Label in [_hud, _hp_label]:
		label.add_theme_font_size_override("font_size", Fx.HUD_FONT_SIZE)
	_terrain.visible = false
	_sky.setup(_camera)
	_renderer.setup(_grid)
	# The staff tip's color **reads** the assembly state. Push a copy in and, the moment one push is
	#  forgotten, it becomes "I changed the combination but the screen is unchanged" — that is how v1 died.
	# **The grid is handed over too — the staff is blocked by terrain and shortens.** Do not hand it over and
	#  the screen draws at the old spot while only firing goes to the new one, and **not one error is raised**
	#  (`character_view._grid`).
	_char_view.setup(_char, _circle, _grid)
	# The assembly window reads **the same thing** — give it a copy and "keys 4 and 5 flip the picture"
	#  disappears, and that is the single source's (plan §1) only visible evidence.
	_circle_window.setup(_circle)
	_spell_view.setup(_spell)
	# **This one path is how the view gets hold of monsters.** Monsters live inside `world_step`, and if the
	#  shell holds a separate array there are two "worlds" (`monsters-minimum`, behavior (3)).
	_monster_view.setup(_world)
	_input.fire_requested.connect(_fire_at)
	_input.reset_requested.connect(reset_stage)
	_input.water_requested.connect(_pour_water_at)
	_input.wood_requested.connect(_paint_wood_at)
	_input.ignite_requested.connect(_ignite_at)
	_input.rain_requested.connect(_toggle_rain_at)
	_input.monster_requested.connect(_spawn_monster_at)
	_input.loadout_requested.connect(_set_loadout)
	# **The world is not stopped** — do not touch `get_tree().paused` here.
	#  Walking, firing and fire spreading with the window open is the whole of design acceptance 4.
	_input.assembly_toggled.connect(_toggle_assembly)
	_input.zoom_requested.connect(_step_zoom)
	# The starting equipment is **the model's default** (`SpellCircle`'s constructor) — the line that pushed
	#  a preset in once here was deleted. Push it in and "the starting state" is in two places, and the day
	#  comes when only one of them gets fixed.
	reset_stage()


## **The only door through which float enters the sim, and `Aim.fire_cmd` closes it exactly once.**
##  Both the staff tip and the mouse are still float px here.
## Tab. **Opening the window hides the HUD** (decided by the user).
##  The window is 90% of the screen and covers `HUD/Stats`, but in the 96px strip on the left
##  **only the front of the letters was left, clipped**, and looked stuck to the window.
##  **The price was known when it was chosen** — the tick and fire counts cannot be seen while assembling.
##   This HUD is the shell's debug display and won't survive into the real game (this file's first line).
##
## **The window is the single source.** Hold a separate HUD latch and the two diverge into "I closed it but
##  the HUD did not come back", and that is a quiet way for the shell to die. => It is decided by **reading**
##  the window's state.
func _toggle_assembly() -> void:
	_circle_window.toggle()
	_hud.visible = not _circle_window.visible


## `-` / `=`. **Clamped, not wrapped** — wrapping would send "one more step out" from the widest view
##  straight back to the play scale, and that reads as the key having done nothing.
func _step_zoom(dir: int) -> void:
	_zoom_step = clampi(_zoom_step - dir, 0, ZOOM_STEPS.size() - 1)
	print("[zoom] %.3fx" % ZOOM_STEPS[_zoom_step])


## Both the rune and the glyphs **come out of the assembly state.** If the shell nails `ELEM_FIRE` in
##  separately, the rune slot becomes a false knob, and the day runes become changeable only firing quietly
##  fails to follow.
func _fire_at(world_px: Vector2) -> void:
	# **If it can't fire, no command is made at all.** Make one and an empty rune trips `fire()`'s rune check
	#  and barks, and since the wrapper counts stderr as failure **ordinary play turns the nets red.**
	#  Do not bark here either — clicking with an empty rune is **normal input.**
	#   "It can't fire" is said by the staff tip dying to gray (`character_view`).
	if not _circle.can_fire():
		return
	_world.enqueue(Aim.fire_cmd(
		_char_view.tip_px(), world_px, _circle.element(), _circle.packed_glyphs()))


## **F — pours water at the mouse position. A shell-only debug door.**
##  What makes water inside the game is **stage 5's water rune**, and until then this is the only way to see
##  water on screen.
##
## **It calls `_grid.set_water` directly** — exactly the same place as `ignite()` (the grid's "door for nets and the stage").
##  Not going through a command, it **does not go to multiplayer.** That is right — the stage won't survive
##   into the real game, and the way water rides the network is stage 5's `CMD_WATER`. Make a command here
##   and **one more unused door stands up.**
##
## **Amount and radius are values chosen by "is it noticeable".** Radius 16 cells = 128px across, and with a
##  1920x1080 screen one press is clearly visible. **Leave it at a single drop and the user reads it as "the
##  key doesn't work".**
## It is `floori` — the same reason as `aim._to_cell`, and `int()` jumps one cell outside the grid's left and top.
const WATER_BRUSH_R := 16

func _pour_water_at(world_px: Vector2) -> void:
	var cx := floori(world_px.x / Tuning.CELL_PX)
	var cy := floori(world_px.y / Tuning.CELL_PX)
	var r2 := WATER_BRUSH_R * WATER_BRUSH_R
	# **An integer disc** — the same shape as `_disc`. Draw it differently here and it becomes "the blast is
	#  round but the water is square", and that only shows on screen.
	for dy in range(-WATER_BRUSH_R, WATER_BRUSH_R + 1):
		for dx in range(-WATER_BRUSH_R, WATER_BRUSH_R + 1):
			if dx * dx + dy * dy > r2:
				continue
			# `set_water` silently refuses stone and burning cells — pour into a vessel and it does not eat the walls.
			_grid.set_water(cx + dx, cy + dy, Tuning.WATER_MAX)


## **T — lays a wooden floor at the mouse position. A shell-only debug door.**
##
## **Why it came about — there was no "path by which the thing to be seen reaches the screen"** (CLAUDE.md).
##  The water work put in **"shallow water cannot put out fire"**, and that difference **is only visible over
##  a forest**: deep water stops fire and a thinly spread sheet does not — **wood must be laid down widely
##  for that to be seen.**
##  **Measured: the whole map holds 91 cells of wood, and even those are shaped as vertical pillars**
##   => it cannot be seen on screen in principle.
##
## **Unlike `set_water` it is a horizontal band, not a disc.** The purpose is to make a forest floor, so
##  laying it as a circle makes a "hill" and water runs off both sides — then the picture being measured
##  never appears.
## **It is laid on empty cells only** — cover stone or water and it erases terrain, and that is destruction, not a brush.
const WOOD_BRUSH_W := 40
const WOOD_BRUSH_H := 2

func _paint_wood_at(world_px: Vector2) -> void:
	var cx := floori(world_px.x / Tuning.CELL_PX)
	var cy := floori(world_px.y / Tuning.CELL_PX)
	for dy in WOOD_BRUSH_H:
		for dx in range(-WOOD_BRUSH_W, WOOD_BRUSH_W + 1):
			if _grid.mat_at(cx + dx, cy + dy) != Mat.EMPTY:
				continue
			_grid.apply(CellGrid.cmd_fill(cx + dx, cy + dy, cx + dx, cy + dy, Mat.WOOD))


## **G — sets fire at the mouse position. A shell-only debug door.**
##  The magic fire rune lights it too, but **it has to go through aiming, flight and impact, so "I want it
##  lit right here" is impossible.**
##  It pairs with T above — lay a forest (T), pour water (F) and set it alight (G), and the three materials
##  gather on one screen.
func _ignite_at(world_px: Vector2) -> void:
	_grid.ignite(floori(world_px.x / Tuning.CELL_PX), floori(world_px.y / Tuning.CELL_PX))


## **K — toggles rain on the mouse row. A shell-only debug door.**
##  It differs from F (a single-point pour, above) — F pours once and is done, while K keeps pouring only
##  because `_on_ticked()` calls `tick()` **every tick.** That wiring is in `_on_ticked()` below.
##
## **It is a toggle.** If it is already on it turns off (without looking at the argument) — press again and
##  it stops. Otherwise the only way to turn rain off is resetting the whole stage with R.
## **The width is fixed at 176 cells (plus and minus 88)** — the `Tuning.WATER_RAIN_HALF_W` comment holds the
##  grounds for that value (the measured table). The 176 cells are taken with the pressed spot at **the
##  center.** `floori` is for the same reason as `WATER_BRUSH_R`.
func _toggle_rain_at(world_px: Vector2) -> void:
	if _water_source != null:
		_water_source = null
		return
	var cx := floori(world_px.x / Tuning.CELL_PX)
	var cy := floori(world_px.y / Tuning.CELL_PX)
	_water_source = WaterSource.new(
		cx - Tuning.WATER_RAIN_HALF_W, cx + Tuning.WATER_RAIN_HALF_W, cy,
		Tuning.WATER_RAIN_PER_TICK)


## **M/N — stands a monster at the mouse position. A shell-only debug door** (`monsters-minimum`).
##  Placement is the map doc's share (that doc's "Boundary"), so the stage does not lay monsters down
##  automatically — these keys are "the path by which the thing to be seen reaches the screen".
##
## **The spawn position puts the mouse position at the center of the box** — put it at the top left and the
##  bigger the box (44px) the farther it floats from the cursor.
## **Stage 1 stood only pigs, with M alone** (the hen was in the table only and the nets made it headless) —
##  **stage 4 added N so the hen can be seen on screen too** (`stage_input.MONSTER_KEYS`).
func _spawn_monster_at(world_px: Vector2, kind: int) -> void:
	# `roundi(w / 2.0)` — with integer division (`/`), odd widths silently lose 1px to rounding down.
	#  The current values (44, 32) are even so it does not show, but the day the table holds an odd width this
	#  line dies first.
	var px := int(world_px.x) - roundi(MonsterDefs.w_px(kind) / 2.0)
	var py := int(world_px.y) - roundi(MonsterDefs.h_px(kind) / 2.0)
	_world.spawn_monster(kind, px, py)


## A number not in the table is **silently ignored.** Nothing happening on a press is better than "switching
##  to an empty combination" — the latter cannot be told apart on screen from acceptance 1 (the difference of
##  adding and removing a glyph).
##  The HUD always shows the numbers that exist, so the user can see that fact.
##
## **A preset only overwrites the assembly state** — it holds no state of its own. So even once the assembly
##  window is attached, the two paths (key · click) touch the same thing and the muzzle and HUD follow
##  **on their own** (plan §1).
func _set_loadout(n: int) -> void:
	if not LOADOUTS.has(n):
		return
	var list: Array[int] = []
	list.assign(LOADOUTS[n])
	# **A preset places the circle and the rune too.** Place only the glyphs and a user who removed the
	#  circle is **trapped** — all five keys die and the only way out is the assembly window.
	#  => Since it places the circle too, **key 1 is an assembly reset.**
	# The order (circle -> rune -> glyphs) is locked **inside** `apply_preset`. Unfold it into three lines
	#  here and the day it gets flipped the glyphs quietly vanish.
	# The table (`LOADOUTS`) was not widened — the circle and rune come from **the two default-issue constants.**
	_circle.apply_preset(
		SpellCircle.DEFAULT_CIRCLE, SpellCircle.DEFAULT_RUNE, Glyph.pack(list))


## **Do not push the world here.** The order is inside `world_step.frame()`, and the one thing this function
##  knows is **"did a tick run".** The moment it is copied, the order the nets measure and the game's order diverge.
func _physics_process(delta: float) -> void:
	if _world.frame(delta, _input.move_axis(), _input.jump_pressed(), _input.jump_held()):
		_on_ticked()
	_update_hud()


## Hits the screen only on frames where a tick ran.
## **Notifications are cleared by the next tick's `spell.step()`** — read after the character has walked, they are still alive.
func _on_ticked() -> void:
	# **This is rain's only heartbeat.** Call it from `_physics_process` and it pours `TICK_DIVIDER` (3) times
	#  faster (`water_source.tick()`'s header) — only while on, exactly once per tick.
	if _water_source != null:
		_water_source.tick(_grid)

	# The trail must come **after** the sim has run, or it is one tick stale.
	_spell_view.on_tick()

	# **A blast notification is valid only within this tick** — the next `step()` clears it.
	#  Do not read it here and only the hole is left, with no flash and no shake, and **no error is raised.**
	_blast_fx.on_blasts(_spell.get_blast_x(), _spell.get_blast_y(),
		_spell.get_blast_element(), _spell.get_blast_gen())
	_blast_count += _spell.blast_count()

	# **A death notification is valid only within this tick** — the tick branch of the next `frame()` clears
	#  it (`world_step.gd`'s header). Do not read it here and the corpse afterimage cannot appear in principle —
	#  exactly the same place as `blast_fx.on_blasts()` (`monster_view.on_tick()`).
	_monster_view.on_tick()

	# **The judgment is made from one value the grid counted.** If the shell holds a separate latch, changes
	#  that **do not go through the command queue** — like a blast — quietly miss that latch and the hole
	#  never appears on screen.
	#  Reading it returns it to 0, so it **must be called exactly once per tick.**
	#  => On ticks where nothing changed the upload is skipped = the cost at rest is about 0.
	if _grid.consume_changed() > 0:
		_renderer.refresh()


## **The render clock is this one.** The sim is 20Hz while the screen is 60fps, so without interpolation a
##  projectile teleports 40px per tick.
##  **The point is that a second clock is not created.** `_world` already holds the divider and here it is
##   **only read** (`phase()`). The moment a view accumulates its own `delta` there are two clocks.
func _process(_dt: float) -> void:
	_spell_view.set_render_alpha(float(_world.phase()) / float(Tuning.TICK_DIVIDER))
	# **Following is `position`, shake is `offset`.** Put both on one axis and the next frame's following
	#  overwrites the shake, and **the shake quietly disappears.**
	# The visible size is read from `get_viewport_rect()` — read `ProjectSettings` here as well and the day
	#  the window mode changes the two places diverge.
	# **Zoom is applied to the clamp too.** `Camera2D.zoom` 0.5 makes the visible world **twice** as wide, and
	#  feeding the raw viewport size to `camera_center` keeps clamping at the play scale — the camera then
	#  stops at the old margin and **half the screen fills with the void outside the map**, with no error.
	var z: float = ZOOM_STEPS[_zoom_step]
	_camera.zoom = Vector2(z, z)
	_camera.position = camera_center(_char.center(), get_viewport_rect().size / z, world_size())
	# Shake is **the camera's offset**. `stage_input._to_world` undoes the canvas transform, so aim does not
	#  drift even while shaking — without undoing it, a click goes to the wrong cell with no error.
	# The order of this node's `_process` and `blast_fx`'s `_process` is not guaranteed, so it **can be one
	#  frame late** — unobservable on a 0.2-second shake.
	_camera.offset = Vector2(_blast_fx.shake_offset())


## R. **Not decoration** — terrain marks are this stage's main evidence, and with holes left over from the
##  previous experiment two combinations cannot be compared. Without a reset, acceptance 1 and 2 do not hold.
func reset_stage() -> void:
	_grid.apply(CellGrid.cmd_reset())
	_spell.reset()
	# The views are cleared with it. Without clearing, dead projectiles' trails and flashes pile up every time R is pressed.
	_spell_view.clear()
	_blast_fx.clear()
	# Without clearing, the dead session's hp dictionary, flashes, damage numbers and corpses briefly ride
	#  into the new session (the same door as `spell_view.clear()` and `blast_fx.clear()` — `monster_view.gd`'s header).
	_monster_view.clear()
	_camera.offset = Vector2.ZERO
	# **Every counter is reset.** Leave one behind and the "fire > impact = it left the grid and vanished"
	#  diagnosis above becomes false forever after a single R — R is this stage's main measuring instrument,
	#  so that diagnosis is the eye.
	#  The queue and the fire count are held by `_world` — touch them here as well and there are two places to reset.
	_world.reset()
	_blast_count = 0
	# Rain is a reset target too — leave it on and the old source keeps pouring from the moment terrain is rebuilt.
	_water_source = null
	build_terrain_into(_grid)
	_char.place(
		SPAWN_TILE.x * Tuning.TILE_CELLS * Tuning.CELL_PX,
		SPAWN_TILE.y * Tuning.TILE_CELLS * Tuning.CELL_PX)


## The world's size (world px). **It comes from the grid** — count it from `MAP` and the day the map shrinks only the camera fails to follow.
static func world_size() -> Vector2:
	return Vector2(CellGrid.W, CellGrid.H) * float(Tuning.CELL_PX)


## **The center the camera will look at. Being pure static, the nets measure it directly.**
##  A position can be fed in and a camera position taken back with no scene and no character — the same
##  idiom as `pick_state`.
##
## **It does not show outside the world (clamp).** Without blocking it, empty space enters the screen at the
##  stage's edge, and that empty space is **outside the grid so nothing is drawn**, reading as "the world is cut off".
## **If the world is narrower than the screen the clamp range inverts** (`lo > hi`) — pass that straight to
##  `clampf` and it silently sticks to one end. In that case putting it at **the world's center** is right.
##  The world today (2048x1152) is bigger than the screen (960x540), so this branch does not run, and
##   **being a branch that does not run, nobody barks when it is wrong** — the nets measure that branch separately.
static func camera_center(focus: Vector2, view: Vector2, world: Vector2) -> Vector2:
	return Vector2(_axis_center(focus.x, view.x, world.x), _axis_center(focus.y, view.y, world.y))


static func _axis_center(f: float, v: float, w: float) -> float:
	if w <= v:
		return w * 0.5
	return clampf(f, v * 0.5, w - v * 0.5)


## ASCII map -> commands. Terrain goes through `apply()` too — if an external event bypasses the command
##  door, side effects added later (waking, notifications) are skipped wholesale and **nothing happens, with no error.**
##
## **Why static**: the nets stand up **this code and this map, the ones that actually run**, and measure them.
##  If a net held a copy of the map, it would not age along when the terrain changes.
static func build_terrain_into(g: CellGrid) -> void:
	if MAP.size() != MAP_H:
		push_error("MAP has %d rows - it must be %d" % [MAP.size(), MAP_H])
		return
	for ty in MAP.size():
		var row := MAP[ty]
		if row.length() != MAP_W:
			push_error("MAP row %d is %d wide - it must be %d" % [ty, row.length(), MAP_W])
			return
		var tx := 0
		while tx < MAP_W:
			var ch := row[tx]
			if not MAP_CHARS.has(ch):
				tx += 1
				continue
			# Runs of the same character are bundled into one command — calling per tile gives 2,304 commands.
			var run := tx
			while run + 1 < MAP_W and row[run + 1] == ch:
				run += 1
			g.apply(CellGrid.cmd_fill(
				tx * Tuning.TILE_CELLS, ty * Tuning.TILE_CELLS,
				run * Tuning.TILE_CELLS + Tuning.TILE_CELLS - 1,
				ty * Tuning.TILE_CELLS + Tuning.TILE_CELLS - 1,
				int(MAP_CHARS[ch])))
			tx = run + 1


## **The place where only the expensive counting is gathered. There are two reasons it was split out of `_update_hud`.**
##  (1) **It can be called with no scene tree** — it touches not one `@onready` label. So **the nets run this
##   directly** and measure "was it throttled · does it catch up after N ticks" by value (`net_render`).
##   Without the split the nets would have had to **attach the stage to the tree**, and this repo does not do that.
##  (2) With "what is counted" and "how it is shown" in one function, the throttling rule scatters across every display line.
##
## **It is throttled by tick number. Do not throttle by frame count** — when the frame rate wobbles the
##  counting period wobbles with it, and that becomes **"it counts more often when it is slow".** The cost is
##  in the `HUD_COUNT_TICKS` comment above.
## The `tick < _hud_count_tick` branch is **R (reset)** — the tick returns to 0, so it counts again immediately.
##  Without it, **the old terrain's counts** stay on screen for 20 ticks after a reset.
func _refresh_hud_counts() -> void:
	var tick := _grid.get_tick()
	if tick - _hud_count_tick < HUD_COUNT_TICKS and tick >= _hud_count_tick:
		return
	_hud_count_tick = tick
	_stone_cells = _grid.count_material(Mat.STONE)
	_wood_cells = _grid.count_material(Mat.WOOD)
	_water_cells = _grid.count_material(Mat.WATER)


func _update_hud() -> void:
	_refresh_hud_counts()
	# **The single source of health is the character.** Count it separately in the shell and it becomes "it took damage but the number is unchanged".
	# Downed is **derived from the same value** — hold a separate latch and "it is 0 but not downed" stays on screen.
	#  The way to revive is written alongside. Being alone there is nobody to pick you up, so **R is the only
	#   way**, and without writing it the user reads it as "the game froze".
	_hp_label.text = "체력 %d / %d%s" % [
		_char.hp, Character.MAX_HP, "   쓰러짐 — R로 다시" if _char.downed else "",
	]
	_hud.text = "\n".join([
		"틱 %d · %d Hz (분주기 %d)" % [
			_grid.get_tick(), 60 / Tuning.TICK_DIVIDER, Tuning.TICK_DIVIDER,
		],
		# Wood decreasing and "burning cells" returning to 0 is acceptance 5's evidence on the number side.
		# Stone and wood are **values up to 1 second stale** (`HUD_COUNT_TICKS` above). "Burning cells" is O(1) and real time.
		"돌 %d · 나무 %d · 타는 셀 %d" % [
			_stone_cells, _wood_cells, _grid.burning_count(),
		],
		# **"Has the water stopped" is judged by this number alone** (design acceptance 1). "It looks stopped"
		#  is not a judgment — in v1 the water looked stopped while it was not, and lightning died there.
		# What the user should watch is **it dropping and then locking to one figure.** 0 comes only in a
		#  narrow vessel and the nets measure that headless — there is no reason to wait 140 seconds on screen.
		# **The water cell count is not "the sum of amounts"** — the `WATER_HUD_TICKS` comment above. Pour with F.
		"활성 청크 %d / %d · 물 %d칸 (F로 붓기)" % [
			_grid.active_chunk_count(), CellGrid.CHUNK_COUNT, _water_cells,
		],
		# **"Did K work" is judged only here.** Unlike F, K does not change the screen the moment it is
		#  pressed and the water level rises only a few ticks later — without on/off and the accumulated
		#  amount the user reads it as "it does not work".
		"물비 %s" % (
			"켜짐 · 누적 %d" % _water_source.poured() if _water_source != null else "꺼짐 (K로 토글)"),
		"FPS %d" % Engine.get_frames_per_second(),
		"캐릭터 (%d,%d) %s" % [_char.x, _char.y, "접지" if _char.on_ground else "공중"],
		"발사 %d · 비행중 %d · 자취 %d" % [
			_world.fire_count(), _spell.active_count(), _spell_view.trail_count(),
		],
		# The deferred count is printed alongside — this is where the user confirms with their eyes that
		#  **nothing was discarded.** When the 4-blasts-per-tick cap bites, this rises briefly and must return
		#  to 0 on the next tick.
		"폭발 %d · 섬광 %d · 밀림 %d" % [
			_blast_count, _blast_fx.active_count(), _spell.pending_count(),
		],
		# The equipped line comes from **what `_circle` actually holds.** Pull the name from the preset table
		#  and the day the assembly window is attached it becomes "the picture changed but the HUD did not" (risk 9).
		# **One of the three places that say "it can't fire"** (the staff tip · the assembly window · here).
		#  It stops **the user reading nothing happening on a left click as a malfunction.**
		# **The number was removed.** From the moment the assembly window touches a glyph, "equipped [4]"
		#  becomes a lie (plan §1).
		#  => The name is derived **from the current state only.** The help line below is "which keys exist",
		#   so numbers are right there.
		"장착 %s%s   (%s)" % [
			_glyph_names(_circle.glyph_list()),
			"" if _circle.can_fire() else "  ⚠ 룬 없음 — 쏠 수 없다", _loadout_help(),
		],
		# The head count must be shown for the user to see on screen that the cap (`MonsterDefs.MAX_MONSTERS`) is reached.
		"몬스터 %d / %d마리 (M으로 세우기)" % [_world.monster_count(), MonsterDefs.MAX_MONSTERS],
		# **Without writing Tab, the assembly window becomes "a feature nobody can open"** — verify-look wrote that.
		#  Without writing M, monsters become "a feature nobody can open" just the same.
		#  **T/F/G are written as one lump** — "lay a forest, pour water, set it alight" is one procedure,
		#   and written separately it does not read as the three being one set.
		"A/D 이동 · Space 점프 · 좌클릭 발사 · Tab 조립창 · R 리셋 · M/N 몬스터",
		"T 숲 · F 물 · G 불  (마우스 자리에) · K 물비 토글 (마우스 행에)",
	])


## The names are **derived** from the table — write them by hand and they go quietly stale when glyphs are added.
## **The equipped line (what is held now) and the help line (the preset table) go through this same function** —
##  build them separately and the day comes when one combination is called by two names.
static func _glyph_names(list: Array) -> String:
	if list.is_empty():
		return "없음 (진 + 룬만)"
	var parts: Array[String] = []
	for id: int in list:
		parts.append(String(Glyph.DEFS[id]["name"]))
	return " → ".join(parts)


static func _loadout_name(n: int) -> String:
	if not LOADOUTS.has(n):
		return "?"
	return _glyph_names(LOADOUTS[n])


## Shows only the loadout keys that exist. Advertise a number that does not exist and it becomes "I pressed it but it does not work".
static func _loadout_help() -> String:
	var keys: Array = LOADOUTS.keys()
	keys.sort()
	var parts: Array[String] = []
	for n: int in keys:
		parts.append("%d %s" % [n, _loadout_name(n)])
	return " · ".join(parts)
