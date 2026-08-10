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
const HpView := preload("res://src/view/hp_view.gd")
const MoneyView := preload("res://src/view/money_view.gd")
## `boss-entrance-and-hp-bar.md`, Stage C.
const BossBarView := preload("res://src/view/boss_bar_view.gd")
const Fx := preload("res://src/view/fx_tuning.gd")
const CharacterView := preload("res://src/view/character_view.gd")
const SpellView := preload("res://src/view/spell_view.gd")
const BlastFx := preload("res://src/view/blast_fx.gd")
const SfxBank := preload("res://src/view/sfx_bank.gd")
const CircleWindow := preload("res://src/view/circle_window.gd")
const ThreePickWindow := preload("res://src/view/three_pick_window.gd")
const Character := preload("res://src/actor/character.gd")
const WorldStep := preload("res://src/actor/world_step.gd")
const Aim := preload("res://src/actor/aim.gd")
const SpellCircle := preload("res://src/actor/spell_circle.gd")
const CircleDefs := preload("res://src/sim/circle_defs.gd")
const SpellSim := preload("res://src/sim/spell_sim.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const StageInput := preload("res://src/stage/stage_input.gd")
const MonsterView := preload("res://src/view/monster_view.gd")
const MonsterDefs := preload("res://src/actor/monster_defs.gd")
## `boss-entrance-and-hp-bar.md`, Stage C — `_boss` below is typed with this.
const Monster := preload("res://src/actor/monster.gd")
const Progress := preload("res://src/actor/progress.gd")
## The town (`docs/design/town.md`) — **its map and spawn are the room table's row 0 now**, so this file no
##  longer names `town_map.gd` at all. The door that asks where you are standing is still here (`_interact`).
const Fixtures := preload("res://src/actor/fixtures.gd")
const TownView := preload("res://src/view/town_view.gd")
const ResearchWindow := preload("res://src/view/research_window.gd")
const SettlementWindow := preload("res://src/view/settlement_window.gd")
## The gate (ending) — `gate-ending-to-game.md`.
const StageGate := preload("res://src/actor/stage_gate.gd")
const GateView := preload("res://src/view/gate_view.gd")
const OnboardView := preload("res://src/view/onboard_view.gd")

## No longer a constant but a re-export of `terrain_map_generated.gd` — it follows the painted region's size verbatim.
##  It pairs with the re-export at the `MAP` declaration below.

## **The room table — one row per room this shell can build** (`src/stage/stage_defs.gd`). Every `if _in_town`
##  that used to pick a map, a spawn, a monster table or a gate is a lookup in it now.
const StageDefs := preload("res://src/stage/stage_defs.gd")

## **A re-export of the room table's stage-1 row** — the value itself, and the account of the accident that
##  makes it dangerous, live in `stage_defs.STAGE1_SPAWN_TILE`. Kept under this name because `net_tables`
##  stands up *the real stage 1* through `Stage.SPAWN_TILE`, the same reason `MAP_W`/`MAP_H` below are
##  re-exports rather than moves.
const SPAWN_TILE: Vector2i = StageDefs.STAGE1_SPAWN_TILE

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
##  => **That reason has not gone away, and the arithmetic behind it has been replaced.** It used to read
##   "a spread bolt's range (40 tiles) is longer than the visible width (30 tiles), so firing horizontally makes
##   off-screen impacts happen in principle". **The 40 tiles was the drag ceiling of a `speed` 20 generation-0
##   bolt with gravity switched off**, and none of those three things is true any more.
##  **Driven today** (`sim_tuning.DRAG_NUM`'s table, flat ground, fired 4 cells up):
##   generation 0 reaches **4.3 tiles horizontally and 12.8 tiles at 45 degrees**; a spread bolt (generation 1)
##   reaches **2.0 and 4.8**. Half the visible width is 15 tiles. => **One bolt cannot leave the screen.**
##  **What can still leave it is the chain**: the 8 spread bolts are born **at generation 0's impact point**,
##   so 12.8 + 4.8 = **~17.6 tiles** from the player, past the 15-tile half-width — and **firing from a cliff
##   adds the whole fall.** So the price is real but it is now an **edge**, not the everyday case it was written as.
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

## `monster-placement-stage1.md` — the `(tx, kind)` table. **The room table names it now**;
## this file reads it out of the row and pushes it into `_world` (`_apply_room()` below). `src/actor/` still
## never preloads it (`net_layers`).

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
##
## **1-5 use the common-rarity names now** (`SPREAD_C`/`BLAST_C`, not the `GLYPH_SPREAD`/`GLYPH_BLAST` aliases)
##  — the levelup-and-three-picks plan's Stage A contract for this file. Common rows are `power_pct = 100`, so
##  this is not a behavior change; it only says on screen which specific id is firing.
## **6 is Stage A's own measuring instrument** — one dummy layer plus common blast, so acceptance 8 (does the
##  socketed glyph actually raise damage) is one keypress instead of a trip through the palette.
const LOADOUTS: Dictionary = {
	1: [],
	2: [Glyph.SPREAD_C],
	3: [Glyph.BLAST_C],
	4: [Glyph.SPREAD_C, Glyph.BLAST_C],
	5: [Glyph.BLAST_C, Glyph.SPREAD_C],
	6: [Glyph.DUMMY_U, Glyph.BLAST_C],
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
## **It is a drawn gauge now, not a `Label`** (`hp_view.gd`) — and that changes the shell's job here from
##  "write a string every frame" to "hand it the character once". The node reads `hp` itself, so the old
##  `_update_hud()` line that formatted `체력 %d / %d` is gone rather than moved.
@onready var _hp_view: HpView = $HUD/HpBar
## **Money, and it is all that is left of the old status line.** `HUD/Progress` used to read
##  `Lv.%d · XP %d/%d · 돈 %d` in one `Label`; the user split it — level off screen entirely
##  (「레벨은 안 보이게」), XP into `hp_view`'s hairline, money into the corner. A `Label` cannot put an icon
##  beside its text, so this is a drawn `Control` (`money_view.gd`) rather than the old label moved.
@onready var _money_view: MoneyView = $HUD/Money
## The boss bar and name (`boss-entrance-and-hp-bar.md`, Stage B/C). **Under `HUD`, like `_hp_view`** — a
## `CanvasLayer` child, so it does not ride the screen shake. Fed a live `Monster` reference through
## `show_boss()`/`clear_boss()`, never a copy — the same rule `_hp_view.setup()` already holds.
@onready var _boss_bar: BossBarView = $HUD/BossBar
## **Its own node, not a line appended to something else.** A `Label` cannot mix colors within one
##  string, and the indicator has to draw the eye in a way the status line must not (verify-look: appended in
##  the same color and weight, nobody looked). `Fx.LEVEL_UP_COLOR` is pushed in once, in `_ready()`, the same
##  place `HUD_FONT_SIZE` already is.
@onready var _levelup_label: Label = $HUD/LevelUp
## **The camera follows the character.** The old contract ("shake only · its position is the viewport center,
##  so the transform is the identity") is **dead** — the screen scale doubled, shrinking the visible world to
##  960x540, so the stage (2048x1152) does not fit in one screen. With a static camera the character is off screen.
##
## **Two axes ride on one node**: `position` = following (`camera_center` below) · `offset` = shake.
##  **Do not mix them** — add shake into `position` and the next frame's following overwrites it, and the shake vanishes.
## The viewport -> world coordinate conversion **must** undo the canvas transform (`stage_input._to_world`).
##  **That now applies to following, not just shake** — without undoing it, aim drifts by however far the camera moved.
@onready var _camera: Camera2D = $Camera2D
## **How far the camera is currently led ahead, in world px** (`camera_lead` below · `Fx.CAM_LEAD_*`).
## It is state, so it cannot live in the static function — **the function stays pure and the net measures it
##  directly**, the same split `camera_center` already uses.
var _cam_lead := 0.0

## **The boss entrance, `boss-entrance-and-hp-bar.md` Stage C. `-1` means "no entrance running"**, so `0` can
## be the first frame — the same `-1`/`0` idiom `_hud_count_tick` below already uses for the same reason.
## **One counter, two consumers** (`_process()`'s camera lines and `_boss_bar.set_entrance_frames()`) — a
## second counter is how the bar's own fade finishes while the camera is still on the boss, or the reverse.
var _entrance_frames := -1
## **A reference, not a copy** — the same rule `_char`/`_grid` are handed to views by. Stays alive after the
## boss dies (`RefCounted`) so `_boss_focus()` below never reads a null mid-entrance; `_rebuild()` is the only
## place that nulls it back out (`gate_view._lit` is the precedent this follows for "revert every counter").
var _boss: Monster = null
## The assembly window sits under `HUD` (a `CanvasLayer`) — put it under `Node2D` and it shakes along with the screen shake.
##  **The shell only tells it to open and close.** The window knows its own state and uses its own coordinates.
@onready var _circle_window: CircleWindow = $HUD/CircleWindow
## **`Progress` is the single source of "is it open"** — the same discipline `_circle_window` already holds
##  for the assembly window (`_toggle_assembly`'s own comment). `_toggle_pick()` only ever calls
##  `Progress.open_pick()`/`decline()`; this node reads that state itself, every frame, in its own `_process()`.
@onready var _pick_window: ThreePickWindow = $HUD/ThreePickWindow
@onready var _monster_view: MonsterView = $MonsterView
## **Hidden in the stage, shown in the town** — `_in_town` below is the single source, pushed to this
##  node in `_build_room()` and nowhere else.
@onready var _town_view: TownView = $TownView
## The gate's arch (`gate-ending-to-game.md`, Stage C). **Its own `visible` is derived
##  every frame from `Progress.boss_died()`** (`gate_view._process()`) — not pushed from here, the same
##  reason `_town_view.visible` is the one exception that *is* pushed (a latch `_in_town` already is).
@onready var _gate_view: GateView = $GateView
## The research bench's window. **Under `HUD`, like the other two** — that node is the `CanvasLayer`, so
##  it does not ride the screen shake.
@onready var _research_window: ResearchWindow = $HUD/ResearchWindow
## The run-end settlement screen (`run-end-settlement.md`). **Under `HUD`, like every
##  other window** — the same reason as `_research_window` above. Unlike the other three it is **derived
##  open**, never toggled by a key (`_sync_settlement()` below) — there is no debug key for "the run is over".
@onready var _settlement: SettlementWindow = $HUD/SettlementWindow
## The onboarding arrow + key cap (`onboarding-and-palette-tabs.md` Stage 7). **Under `HUD`, like every
## other window** — the same reason as `_research_window` above (it must not ride the screen shake).
## **Its own `visible` is pushed here, once a frame, from `_onboard_step`** — the same "derive, do not
## push a second latch" idiom `_town_view.visible = _in_town` already holds.
@onready var _onboard_view: OnboardView = $HUD/OnboardView
@onready var _char_view: CharacterView = $CharacterView
@onready var _spell_view: SpellView = $SpellView
@onready var _blast_fx: BlastFx = $BlastFx
## **Not a scene node — there is nothing to place in the editor.** Built and `add_child`ed in `_ready()`
##  (below), the same way `_world`/`_grid` are plain objects rather than nodes. It must be in the tree for
##  its `AudioStreamPlayer` children to actually process, which is why this is not left as a bare `RefCounted`.
var _sfx := SfxBank.new()
## **Sampled once per tick, inside `_on_ticked()` — never polled from `_physics_process` at 60Hz.** Polling
##  at 60Hz against a value that only changes on a tick (20Hz) is exactly the aliasing trap CLAUDE.md names
##  three times over (`_charge_blocked`/`_leaped_landed`/`_grounded_recently`); sampling from inside the one
##  place that only runs when a tick actually ran sidesteps it instead of reproducing it a fourth time.
var _prev_on_ground := false
## Same reasoning as `_prev_on_ground` above — `hp` only changes on a tick.
var _prev_hp := 0
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
## **Which room the shell is standing in — an index into `StageDefs.ROWS`, not a bool.**
##  **Everything else derives from it** — which map gets built, where the character lands, which monsters are
##  placed, where the gate sits, what the clear screen is titled, whether the fixture view draws, and what E
##  does. Hold a second copy of it anywhere (a view, the HUD) and the two diverge into "the town is drawn
##  over stage 1", which is visible on screen only.
## **A run ends by walking back to the town** (`town.md`, "die or clear and you come back here"). Only two
##  doors write this, both below: the departure gate and the settlement screen's button.
##
## **It replaced `var _in_town := true`.** A bool can only ever pick between two rooms, and picking a third
##  meant an `if` at every one of the six places above — which is exactly the surgery this index removes.
var _stage_id := StageDefs.ROOM_TOWN

## **Derived, never stored.** The town is a room like any other, but three things genuinely ask "is it *the
##  town*" rather than "which room" — the fixture view, `_interact()`, and the settlement screen's own
##  `not _in_town` term — and they read this. **A getter, not a second field**: written as a field it would
##  be one more thing every room switch has to remember, and the day one door forgets, the town's benches
##  float over stage 1 with nothing barking.
## `Object.get("_in_town")` runs this getter, which is what several nets read the room through.
var _in_town: bool:
	get:
		return _stage_id == StageDefs.ROOM_TOWN

## **The clear screen's title for the room currently standing** — read from the room table by `_apply_room()`
##  and handed to `_settlement.open()`. Not read from `Fx` at the open site: *which* stage's name the panel
##  shows is a property of the stage, and stage 2 must not have to edit the settlement window to be named.
var _stage_title := ""

## **Which room this one hands on to, or `NO_NEXT`** — read out of the room table by `_apply_room()`, the
##  same door `_stage_title` comes through, and for the same reason: a net can drive a synthetic row and see
##  the chain follow it.
## **`NO_NEXT` is not a missing value, it is the answer "the run ends here"** — and it is what makes stage 1's
##  clear behave exactly as it does today.
var _next_stage_id := StageDefs.NO_NEXT

## The last thing a fixture said, shown on the HUD until another one speaks. **A string and not a window** —
##  the town's screens ("how the research and assembly screens are actually drawn") are explicitly outside
##  `town.md`'s own boundary, and building one now would be deciding by default what the user has not decided.
var _town_message := ""

## **Onboarding's step machine** (`onboarding-and-palette-tabs.md` Stage 7). **Lives in the shell, dies on
## R** — `_rebuild()` resets it to `ONBOARD_OFF` unconditionally on every teardown (R, going home, and the
## chain), the same "one teardown list" `_rebuild`'s own header already describes. What makes the
## walkthrough run **once ever**, not once per reset, is `Progress._onboarding_seen` — a separate,
## persistent fact `_leave_town()` reads before deciding whether to start `ONBOARD_ARROW` again.
##
## ```
## ARROW   -- Tab pressed -->        CIRCLE
## CIRCLE  -- 일반진 placed -->       RUNE      (circle_window.onboard_inserted)
## RUNE    -- 무속성 룬 placed -->    GLYPH     (circle_window.onboard_inserted)
## GLYPH   -- 완성 pressed -->        DONE      (circle_window.onboard_confirmed)
## DONE    -- window closes -->      OFF       (marks Progress.mark_onboarding_seen())
## ```
## **Advanced by the window, not polled from it** — `circle_window` is the one object that sees the clicks;
## a poll here would need to re-derive "was that insert the onboarding-relevant one" from the same state
## the window already holds, which is the two-copies trap this repo keeps finding under `SpellCircle`.
const ONBOARD_ARROW := 0
const ONBOARD_CIRCLE := 1
const ONBOARD_RUNE := 2
const ONBOARD_GLYPH := 3
const ONBOARD_DONE := 4
const ONBOARD_OFF := 5
var _onboard_step := ONBOARD_OFF

var _blast_count := 0

## **Room ③'s east wall — comes down once, on the rooster's death, and only once**
##  (`gate-ending-to-game.md`, Stage B). `true` = already dropped this run.
## **Safe as a latch where the settlement panel's latch is forbidden**: its only writer is `reset_stage()`,
##  which *always* rebuilds the terrain in the same call (`_build_room()` below), so the flag and the wall
##  cannot disagree — unlike a `mouse_filter` latch, nothing here can strand the game.
var _room3_gate_open := false

## **Is the debug readout showing. Off at boot, F3 toggles it** (`stage_input.debug_hud_toggled`).
##
## **It is fifteen lines, not two.** `docs/submission/` has been describing it as two, which is wrong and is
##  worth correcting there separately. Fifteen lines of black text land on top of the research window's
##  bright parchment and cover the prices the player opened it to read — found on screen, not reasoned.
##
## **Not deleted, defaulted off.** Tick number, chunk counts, monster counts and the pick state have no other
##  view anywhere, and they are how most of this repo's headless findings get confirmed by eye. What was
##  wrong was booting into them.
##
## **The flag itself lives in `stage_input`, not here** — F3 now switches **developer mode**, which gates
##  every debug key as well as this readout (`stage_input._debug_on`'s own header). This file used to keep a
##  second `bool` that F3 flipped in parallel; two flags could drift into "the keys are live while the
##  readout explaining them is hidden", so the copy was deleted and `_update_hud()` reads the one flag.
## **`_update_hud()` derives `visible` from it every frame** — never written at the key itself. That is the
##  same rule the line below already follows for the four windows, and its own comment records why: a
##  visibility written at toggle time cannot see the paths that bypass the toggle.

## **Debug camera zoom (`-` / `=`).** 1.0 is the play scale; 0.075 shows 12,800px of world on the 960x540
##  screen. **The map is 300x48 = 9,600px wide since `left-run-clumps-and-platforms.md` cut 100 columns**,
##  so the last step now over-fits it rather than framing it exactly. Left as it is — that doc does not
##  touch zoom, and nothing measures this step.
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
	# **`_hp_view` is not in this list** — it draws its own text at its own size (`Fx.HP_NUMBER_SIZE`), and a
	#  theme override pushed onto a `Control` that never calls `get_theme_font_size` would be a false knob.
	for label: Label in [_hud, _levelup_label]:
		label.add_theme_font_size_override("font_size", Fx.HUD_FONT_SIZE)
	# **Pushed once, not every `_update_hud()` frame** — the same discipline as the font size above. Only the
	#  text changes per frame; the color is a standing property of this node.
	_levelup_label.add_theme_color_override("font_color", Fx.LEVEL_UP_COLOR)
	_terrain.visible = false
	# **Must be in the tree before anything calls `play_*()`** — an `AudioStreamPlayer` outside the tree does
	#  not process, so a sound triggered before this line would count (`play_count`) but never actually play.
	add_child(_sfx)
	_sky.setup(_camera)
	_renderer.setup(_grid)
	# The staff tip's color **reads** the assembly state. Push a copy in and, the moment one push is
	#  forgotten, it becomes "I changed the combination but the screen is unchanged" — that is how v1 died.
	# **The grid is handed over too — the staff is blocked by terrain and shortens.** Do not hand it over and
	#  the screen draws at the old spot while only firing goes to the new one, and **not one error is raised**
	#  (`character_view._grid`).
	# **`_blast_fx` too** — the hit flash's screen shake goes through the same `kick()` every other shake uses
	#  (`character_view.gd`'s own header). Optional/defaulted on that side, the same door `char`/`grid` opened
	#  on `monster_view.setup()`.
	_char_view.setup(_char, _circle, _grid, _blast_fx)
	# **The gauge takes the character and nothing else** — it reads `hp` every frame itself, the same
	#  reference-not-copy rule `_char_view` above already holds.
	_hp_view.setup(_char, _world.progress())
	_money_view.setup(_world.progress())
	# The assembly window reads **the same thing** — give it a copy and "keys 4 and 5 flip the picture"
	#  disappears, and that is the single source's (plan §1) only visible evidence.
	# **`Progress` too, since Stage A of `rune-lock-and-receiving.md`** — the window's palette asks it
	#  `owns_rune()` to gate the rune section; `_pick_window.setup()` below is the precedent, verbatim.
	_circle_window.setup(_world.progress(), _circle)
	# **`Progress` is owned by `_world`, not the shell** (`world_step.gd`'s own comment) — handed over as a
	#  reference, the same reason `_circle_window` is handed `_circle` rather than a copy. **`_circle` too** —
	#  Stage E's layer click calls `SpellCircle.place_glyph()` directly (the one door), so the pick window
	#  needs the same live reference `_circle_window` already holds, not a second copy of the loadout.
	_pick_window.setup(_world.progress(), _circle)
	_spell_view.setup(_spell)
	# **This one path is how the view gets hold of monsters.** Monsters live inside `world_step`, and if the
	#  shell holds a separate array there are two "worlds" (`monsters-minimum`, behavior (3)).
	# **`_char`/`_grid` too** (`docs/design/attack-prediction.md`) — the same precedent `_char_view.setup(_char,
	#  _circle, _grid)` already set for handing a view more than one actor reference directly, since `_world`
	#  exposes neither the character nor the grid to a caller outside `src/actor/`.
	_monster_view.setup(_world, _char, _grid)
	# The fixture prompt follows the player, so the view needs the character — the same one-reference door
	#  `_char_view.setup` uses. It needs nothing else: the room is a constant and the seats come from it.
	_town_view.setup(_char)
	# **The same `Progress` every other window here reads** — a copy would show the arch staying hidden (or
	#  shown) after the real flag moved, and nothing would bark (`_research_window.setup`'s own comment, same
	#  reason).
	_gate_view.setup(_world.progress())
	# **The same `Progress` the HUD and the other two windows read** — a copy would show a material count
	#  that stopped moving the moment a boss died, and nothing would bark.
	_research_window.setup(_world.progress())
	# **A signal, not a call into the shell** (`settlement_window.gd`'s own header — testability, not a
	#  `net_layers` rule). The button's click is what actually closes the run.
	_settlement.town_pressed.connect(enter_town)
	_input.fire_requested.connect(_fire_at)
	_input.reset_requested.connect(reset_stage)
	_input.wood_requested.connect(_paint_wood_at)
	_input.ignite_requested.connect(_ignite_at)
	_input.reward_taken_requested.connect(_take_boss_reward)
	_input.monster_requested.connect(_spawn_monster_at)
	_input.loadout_requested.connect(_set_loadout)
	_input.interact_requested.connect(_interact)
	# **The world is not stopped** — do not touch `get_tree().paused` here.
	#  Walking, firing and fire spreading with the window open is the whole of design acceptance 4.
	_input.assembly_toggled.connect(_toggle_assembly)
	_input.pick_toggled.connect(_toggle_pick)
	_input.debug_hud_toggled.connect(_toggle_debug_hud)
	_input.cancel_requested.connect(_handle_cancel)
	_input.zoom_requested.connect(_step_zoom)
	# **Onboarding is advanced by the window, not polled from it** (`_onboard_step`'s own header) —
	#  `circle_window` is the one object that sees the clicks that move the walkthrough forward.
	_circle_window.onboard_inserted.connect(_advance_onboard)
	_circle_window.onboard_confirmed.connect(_finish_onboard_confirm)
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
##
## **`_hud.visible` is not written here, or anywhere else that opens or closes a window.** It used to be —
##  and the pick window's own `취소` button is the counter-example that killed that approach: it calls
##  `Progress.decline()` **directly** (`three_pick_window._gui_input`'s own design — the window owns its own
##  click handling), which this function and `_toggle_pick()` below never see. A toggle-time write here would
##  restore `Stats` on Tab and P, but not on a decline that came from the button, and `Stats` would strand
##  hidden with nothing open — measured on screen. `_update_hud()` derives `_hud.visible` from `Progress` and
##  `_circle_window` **every frame** instead, which makes that whole class of "one path forgot to restore it"
##  bug impossible rather than patching the one path that got caught.
func _toggle_assembly() -> void:
	# **Opening one closes the other** (Stage C's own file-table line) — `HUD/Stats` is the only place either
	#  can show right now (the pick has no window yet), so the two cannot both claim it. Declining does not
	#  consume the pick (`Progress.decline()`'s own comment) — it only clears the room to show something else.
	_world.progress().decline()
	# **Stage E's confirmation afterglow does not derive from `Progress`** (`three_pick_window.is_showing()`'s
	#  own comment) — `decline()` above cannot touch it, so without this line Tab pressed during the
	#  afterglow would show both windows at once, the exact bug `_opening_one_window_closes_the_other`
	#  exists to prevent.
	_pick_window.cancel_confirm()
	_circle_window.toggle()
	# **Beat 1's own transition — the arrow is for Tab, and Tab just opened the window.** Onboarding-only:
	#  outside `ONBOARD_ARROW` this does nothing, the same "outside onboarding, nothing auto-advances" rule
	#  `circle_window.set_onboarding`'s own header holds for the tab.
	if _onboard_step == ONBOARD_ARROW and _circle_window.visible:
		_onboard_step = ONBOARD_CIRCLE


## **The window's own signal, driven by an actual insert** (`circle_window.onboard_inserted`) — only while
## `ONBOARD_CIRCLE` or `ONBOARD_RUNE` (진 then 룬) does this move the step; a stray emission at any other
## time (there should not be one, since the window itself only emits while `_onboarding` is true) does
## nothing rather than corrupting a later state.
func _advance_onboard() -> void:
	if _onboard_step == ONBOARD_CIRCLE or _onboard_step == ONBOARD_RUNE:
		_onboard_step += 1


## **완성 pressed while onboarding — the glow beat.** The window closes itself a few frames later
## (`circle_window._process`); `_physics_process` below is what notices that and finishes the walkthrough.
func _finish_onboard_confirm() -> void:
	if _onboard_step == ONBOARD_GLYPH:
		_onboard_step = ONBOARD_DONE


## P. **The three-pick's Stage-C door** — text only, no window yet (that is Stage D). Mirrors
## `_toggle_assembly()`'s own shape: **`Progress` is the single source of "is it open"**, read here, not held
## as a second latch — the same reason `_toggle_assembly` reads `_circle_window.visible` instead of a bool of
## its own. **`_hud.visible` is likewise not written here** — see the comment above `_toggle_assembly`.
func _toggle_pick() -> void:
	var pr := _world.progress()
	if pr.is_pick_open():
		pr.decline()
		return
	# **Check first, close second.** With nothing pending, `open_pick()` below would fail anyway — closing
	#  the assembly window *before* knowing that trades the player's open window for nothing. Measured:
	#  pressing P with 0 pending while the window was open used to close it regardless (`pending_picks <= 0`
	#  is exactly `open_pick()`'s own first guard, read here before touching the window at all).
	if pr.pending_picks <= 0:
		return
	# **Opening the pick closes the assembly window** — the same reason in reverse.
	if _circle_window.visible:
		_circle_window.toggle()
	# **`owned` comes from the circle, not from `Progress`** — `Progress` knows nothing about circles
	#  (that file's own comment), the same boundary it holds against monsters and glyphs elsewhere.
	pr.open_pick(_circle.glyph_list())


## ESC. **Closes whichever of the three key-opened windows is open, and only that one** (user request:
##  "E 해서 뜬 게 ESC로 꺼져야 함. 모든 UI들은"). At most one is ever open at a time (each toggle site above
##  already closes the other two), so the order here only matters in principle.
##
## **Reuses each window's own toggle/decline path rather than writing a second `visible = false`.**
##  `_toggle_assembly()`/`_toggle_research()` already carry the "opening one closes the others" bookkeeping;
##  a bare `_circle_window.visible = false` here would skip `_pick_window.cancel_confirm()` and `Progress.
##  decline()`, and reopen this exact bug with a second door.
##
## **The three-pick: closing it does not lose the pick.** `Progress.decline()` — what `_toggle_pick()` calls
##  when one is open — clears only `_drawn` (this draw's three cards); `pending_picks` is untouched (that
##  function's own comment: "declining does not consume the pick"). Pressing P again draws a fresh three.
##  ESC therefore reuses `_toggle_pick()` rather than being refused here — the button inside the window
##  already does the identical thing.
##
## **`_settlement` is deliberately not here.** It opens by derivation, not by a key
##  (`_sync_settlement()`'s own header) — closing it would just have `want` reopen it on the very next frame,
##  reading as "ESC did nothing". Its button is the panel's only door by design (`run-end-settlement.md`):
##  that screen states the run is over, it is not a window to dismiss.
func _handle_cancel() -> void:
	if _circle_window.visible:
		_toggle_assembly()
		return
	if _research_window.visible:
		_toggle_research()
		return
	if _world.progress().is_pick_open():
		_toggle_pick()


## `-` / `=`. **Clamped, not wrapped** — wrapping would send "one more step out" from the widest view
##  straight back to the play scale, and that reads as the key having done nothing.
func _step_zoom(dir: int) -> void:
	_zoom_step = clampi(_zoom_step - dir, 0, ZOOM_STEPS.size() - 1)
	print("[zoom] %.3fx" % ZOOM_STEPS[_zoom_step])


## Both the rune and the glyphs **come out of the assembly state.** If the shell nails `ELEM_FIRE` in
##  separately, the rune slot becomes a false knob, and the day runes become changeable only firing quietly
##  fails to follow.
##
## **Loops `_circle.shots()`, not a single `element()`/`packed_glyphs()` pair** (`triangle-circle-to-game.md`
##  step 5). A round circle's `shots()` still returns exactly one entry, so this is byte-identical to the old
##  single-command build for every circle that exists before the triangle. A triangle circle's three entries
##  each become their own command, aimed from the same tip and the same click — only `element`/`glyphs`/`delay`
##  differ per socket. **Three shots means three recoils** (`_char.recoil` already hangs off `fire()`
##  returning true inside `_drain_queue`, once per drained command) — that is a real, intended consequence of
##  three bolts leaving, not a bug to suppress here.
func _fire_at(world_px: Vector2) -> void:
	# **If it can't fire, no command is made at all.** Make one and an empty rune trips `fire()`'s rune check
	#  and barks, and since the wrapper counts stderr as failure **ordinary play turns the nets red.**
	#  Do not bark here either — clicking with an empty rune is **normal input.**
	#   "It can't fire" is said by the staff tip dying to gray (`character_view`).
	if not _circle.can_fire():
		return
	# **Once per click, not once per shot.** A triangle circle can queue three shots from one click
	#  (`_circle.shots()`'s own loop below) — three overlapping "pew"s on one click would read as a
	#  malfunction, not as three bolts, so this fires the same number of times the player pressed the mouse.
	_sfx.play_fire()
	var tip := _char_view.tip_px()
	for shot: Dictionary in _circle.shots():
		_world.enqueue(
			Aim.fire_cmd(tip, world_px, int(shot["element"]), int(shot["glyphs"])),
			int(shot["delay"]))


## **F — pours water at the mouse position. A shell-only debug door.**
##  What makes water inside the game is **stage 5's water rune**, and until then this is the only way to see
##  water on screen.
##
## **It calls `_grid.set_water` directly** — exactly the same place as `ignite()` (the grid's "door for nets and the stage").
##  Not going through a command, it **does not go to multiplayer.** That is right — the stage won't survive
##   into the real game, and the way water rides the network is stage 5's `CMD_WATER`. Make a command here
##   and **one more unused door stands up.**
##
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
## **Passes no explicit `src`** (`burn-out-of-the-bull-room.md` §0) — `CellGrid.ignite()`'s own default is
##  `IGNITE_RUNE_FIRE`, so this debug door stands in for the rune, and a `rune_only` wall (the future door) is
##  still lightable from here for testing.
func _ignite_at(world_px: Vector2) -> void:
	_grid.ignite(floori(world_px.x / Tuning.CELL_PX), floori(world_px.y / Tuning.CELL_PX))


## **Takes whichever boss reward(s) are pending — two callers now, one body.** `_on_ticked()`'s own auto-grant
## (session correction: the bull's reward used to have exactly one door, the debug key L, so a player who
## never opens the debug layer got nothing) and the debug key L (`stage1-bosses.md` Stage I) both call this
## same function; neither copies its body, or the day this logic changes only one of the two paths follows.
## **Only clears the gate** — it does not call `Progress.add_xp`/`add_money` (those already happen for every
## kind, unconditionally, in `WorldStep`'s own death loop).
##
## **Granting a rune was milestone step 3's gap** (`stage1-bosses.md`'s own TBD) — closed now
## (`rune-lock-and-receiving.md`, Stage C). The bull's reward *is* fire: `progress.grant_rune(Tuning.ELEM_FIRE)`
## below unveils it in the assembly palette (`circle_window._slot_accepts`) — placing it is still the
## player's own click, the same door every rune already goes through (no second placement path). **Provisional,
## and the user's to overturn** — the plan's own TBD names auto-equip and a corpse pickup as the other two live
## candidates; only this call site would move if either wins, nothing else in the lock.
##
## **Room ①'s water is gone** (`burn-out-of-the-bull-room.md` §4) — only the reward gate below survives.
## `grant_rune` fires the instant the bull is confirmed dead, on the same L press that clears the pending
## flag. **The `boss_died(KIND_BULL)` guard is what makes "before the bull, nothing grants fire" true** —
## `grant_rune` is idempotent on its own (`net_progress`'s own check), so nothing further needs to guard a
## second press.
##
## **`not progress.is_reward_pending(...)` is deliberately not part of this condition** — verify-read's own
## finding: `clear_pending_boss_rewards()` on the line above already makes that term true unconditionally by
## the time it would be read, so it used to be a coupling to the line above, not a real check (deleting it
## changed nothing; only reordering the two lines would have). `boss_died()` alone is the whole of what
## actually decides this.
func _take_boss_reward() -> void:
	var progress := _world.progress()
	progress.clear_pending_boss_rewards()
	if progress.boss_died(MonsterDefs.KIND_BULL):
		progress.grant_rune(Tuning.ELEM_FIRE)


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
	# The table (`LOADOUTS`) was not widened — the circle comes from **the one default-issue constant.**
	#
	# **The rune does not** (`rune-lock-and-receiving.md`, Stage D). Passing `SpellCircle.DEFAULT_RUNE`
	#  unconditionally used to silently wipe an earned rune the moment any preset key was pressed — earn
	#  fire, place it, press key 4, and it came back none with nothing barking. `apply_preset`'s own comment
	#  already named this day: "the day there are several kinds of rune, the preset has to take a rune list" —
	#  today there is exactly one slot, so **the rune to carry over** is read here instead.
	# **Read before `apply_preset` runs, not after** — `set_circle` inside it resizes and refills every rune
	#  slot the instant the circle id actually changes, so reading `rune_at(0)` afterward would already see
	#  the wiped value, not the one to preserve.
	# **That day arrived — `CircleDefs.ALL` is no longer `[CIRCLE_ROUND]` alone** (`triangle-circle-to-game.md`
	#  step 4). The line below used to say this read's ordering was insurance nothing today could falsify;
	#  verify-read found the falsifying case, and it was not this line but the one after it —
	#  **unconditionally passing `SpellCircle.DEFAULT_CIRCLE` into `apply_preset` below.** With a triangle
	#  circle equipped, every debug loadout key (1-5) silently swapped it back to round, destroying sockets 1
	#  and 2 and whatever runes/glyphs sat there, with nothing on screen explaining why. Fixed just below —
	#  **preserve whatever circle is already equipped**, and only fall back to `DEFAULT_CIRCLE` for the one
	#  case that actually needs unsticking (`CIRCLE_NONE`, this function's own "key 1 is an assembly reset"
	#  comment above). This read (`rune_at(0)`) is unaffected by that fix — it is read before either circle
	#  choice is applied, so its own ordering argument still holds unchanged.
	# **Falls back to `DEFAULT_RUNE`, never `RUNE_EMPTY`** — `rune_at(0)` returns `RUNE_EMPTY` when the circle
	#  was removed (0 rune slots to read), the one case with nothing earned left to carry over.
	#  `DEFAULT_RUNE` is the same "none, but still fires" state a fresh boot starts at — the same discipline
	#  `circle_window`'s own click-to-clear fix holds: the seat is never left truly empty.
	var current_rune := _circle.rune_at(0)
	if current_rune == SpellCircle.RUNE_EMPTY:
		current_rune = SpellCircle.DEFAULT_RUNE
	# **Preserve the equipped circle — the fix.** `apply_preset` still takes exactly one rune value and fills
	#  every socket with it (that function's own comment already names this as undone: "the day there are
	#  several kinds of rune, the preset has to take a rune list"). Preserving the circle across presets means
	#  that limitation is now reachable on a triangle circle too — pressing a loadout key **flattens sockets 1
	#  and 2's runes to socket 0's value**, same as it always flattened glyphs into whichever layers the
	#  2-glyph `LOADOUTS` table happens to fill. Not fixed here — writing a rune *list* through this door is a
	#  larger change than the bug this line exists to close (the circle silently reverting), and out of this
	#  plan's scope.
	var target_circle := _circle.circle_id()
	if target_circle == CircleDefs.CIRCLE_NONE:
		target_circle = SpellCircle.DEFAULT_CIRCLE
	_circle.apply_preset(target_circle, current_rune, Glyph.pack(list))


## **Do not push the world here.** The order is inside `world_step.frame()`, and the one thing this function
##  knows is **"did a tick run".** The moment it is copied, the order the nets measure and the game's order diverge.
##
## **The world is gated behind the settlement screen** (`run-end-settlement.md`, Stage D) — while it is
## showing, the run is over and there is nothing left to watch, so `_world.frame()` is not called at all rather
## than called and ignored. `net_settlement` measures this as a value (`_grid.get_tick()` does not move across
## N calls), not assumed from reading the branch.
func _physics_process(delta: float) -> void:
	# **The double-jump unlock, re-derived every frame** (`research-bench-unlocks.md`) — **immediate is the
	#  absence of a latch.** There is no purchase hook and no reset hook, so there is no hook to forget: buy it
	#  at the bench and the very next physics frame the character can use it, and `Progress.reset()` cannot
	#  strip it because nothing was ever pushed anywhere to go stale.
	#  This is the repo's own "derive, do not push" rule, the same one `gate_view._process` states for
	#  `visible` and `_build_room` states for `_town_view.visible`.
	# **It sits in the shell rather than in `world_step.gd` (which is where `_char.step()` is actually called,
	#  and which holds `Progress` too) only to avoid colliding with another track mid-edit.** The day
	#  `WorldStep` owns this wiring, **one line moves and nothing else changes** — it is a per-frame derivation
	#  either way. Flagged rather than hidden.
	# **Above the `_settlement.is_showing()` gate on purpose**: the settlement screen freezes the world, and a
	#  budget left stale across that freeze would be a latch by accident.
	_char.air_jump_budget = _world.progress().air_jump_budget()
	if not _settlement.is_showing():
		# **Captured once, read twice.** `Input.is_action_just_pressed` is safe to call again in the same
		#  frame (it does not consume), but sharing one value keeps `_world.frame()`'s argument and
		#  `_on_ticked()`'s jump-sound decision from being able to read two different presses in principle.
		var jump_press := _input.jump_pressed()
		if _world.frame(delta, _input.move_axis(), jump_press, _input.jump_held()):
			_on_ticked(jump_press)
		# **The boss entrance clock — `boss-entrance-and-hp-bar.md` Stage C.** Physics frames, not `_process()`
		#  — `gate_view`'s own header: `_process()` runs at the monitor refresh rate, so a 24-frame beat is
		#  0.4s on a 60Hz panel and 0.167s on a 144Hz one, with nothing barking.
		#  **Inside the `not is_showing()` guard, on purpose** — the settlement panel freezes the world, and
		#  an entrance that kept counting under it would be a latch by accident (Risk 7).
		if _entrance_frames >= 0 and _entrance_frames < Fx.boss_entrance_total_frames():
			_entrance_frames += 1
		_boss_bar.set_entrance_frames(_entrance_frames)
	# **Before `_update_hud()`, not after, and not left to the pick window's own `_process()`.**
	#  `three_pick_window.tick_confirm()`'s own header: ticking the confirmation countdown here, in the same
	#  synchronous call as `_update_hud()` (which reads `is_showing()`), closes the one-render-frame seam that
	#  existed when the countdown lived on the idle clock instead — a frame where the window had already
	#  gone invisible but the HUD had not yet been told.
	_pick_window.tick_confirm()
	_sync_settlement()
	# **Same reason as `_pick_window.tick_confirm()` above** — the count-up's clock is screen-only state
	#  (`settlement_window.gd`'s own header), ticked from here rather than the window's own idle-rate `_process()`.
	_settlement.tick_countup()
	_tick_onboard()
	_update_hud()


## **Notices the window closing and finishes (or abandons) the walkthrough.** `circle_window`'s own
## `_process()` calls `toggle()` itself the instant the 완성 glow ends — there is no signal for "the window
## just closed" the way there is one for an insert or a confirm-press, so this is read the same way
## `_toggle_assembly()` reads `_circle_window.visible` rather than holding a second latch: once a frame,
## here.
## **Only marked "seen" if it actually reached `ONBOARD_DONE` first.** Closing early (Tab, ESC) at
## `ONBOARD_CIRCLE`/`RUNE`/`GLYPH` turns onboarding off without marking it complete — the walkthrough is not
## skippable by a stray key today (an open TBD in the design doc), but it must not be able to check itself
## off by accident either.
## **The departure gate itself — blocked until the circle can actually fire, or the walkthrough has already
## run once.** Before this line nothing stopped E at `Fixtures.KIND_GATE` with an empty circle
## (`onboarding-and-palette-tabs.md` Stage 3 starts every run empty), which walked straight into stage 1
## unable to fire.
## **`can_fire()`, not "완성 was pressed"** — the state machine above only reaches `ONBOARD_DONE` after CIRCLE
## and RUNE are both placed, but that is an artifact of the walkthrough's own order, not a rule this should
## lean on: a player who opens the window outside onboarding and presses 완성 on an empty circle must not
## slip through. Reading `_circle.can_fire()` directly is the one door a click sequence cannot fool.
## **`or has_seen_onboarding()`, never `and`** — once the walkthrough has completed once, a returning player
## (after `R`, or a later run) must never be blocked again, even if the circle they currently hold cannot
## fire. Blocking a second time is exactly what "이미 온보딩을 본 플레이어는 그냥 지나가야 한다" rules out.
## **Town-only, and reads `_town_view.reachable()`** — the same single door `_interact()` already reads, so
## the message drawn and the door that actually opens can never disagree.
func _town_gate_locked() -> bool:
	return _in_town and _town_view.reachable() == Fixtures.KIND_GATE \
		and not _circle.can_fire() and not _world.progress().has_seen_onboarding()


func _tick_onboard() -> void:
	var locked := _town_gate_locked()
	_onboard_view.visible = _onboard_step == ONBOARD_ARROW or locked
	_onboard_view.show_tab_hint = _onboard_step == ONBOARD_ARROW
	_onboard_view.message = Fx.GATE_LOCKED_TEXT if locked else Fx.ONBOARD_TEXT
	if _onboard_step > ONBOARD_ARROW and _onboard_step < ONBOARD_OFF and not _circle_window.visible:
		if _onboard_step == ONBOARD_DONE:
			_world.progress().mark_onboarding_seen()
		_onboard_step = ONBOARD_OFF
		_circle_window.set_onboarding(false)


## **Derived, not pushed.** `want` is recomputed every physics frame straight from `_char.downed`/`at_gate`/
## `_in_town` — never latched — which is what makes "going down in the town must not open it" true **by
## construction** (`want` is false there because `not _in_town` is false) and "standing at a gate that has
## not opened does nothing" true the same way (`at_gate` reads `boss_died()` itself, no separate door).
##
## **Correction (verify-read, H4): "R closes it" is not this function's `elif` branch.** `reset_stage()`
## calls `_settlement.close()` **directly** (its own line, not through here) — that is the actual close. What
## `want` collapsing on the same reset actually buys is narrower: it keeps the very next `_sync_settlement()`
## call from immediately reopening the panel `reset_stage()` just closed. **The `elif not want and is_showing():
## close()` branch below is unreachable in today's build**, checked directly: `_world.frame()` is skipped
## entirely while `is_showing()` is true (this function's own caller, `_physics_process`), so `_char.downed`,
## `_char.center()` (hence `at_gate`) and `_in_town` are all frozen for as long as the panel is open — `want`
## cannot flip from true to false while `is_showing()` stays true, because nothing that feeds it can change.
## Left in rather than deleted: a future change that lets any of those three move while the panel is showing
## would make this branch load-bearing again, and deleting it now would be a second, silent decision.
##
## **`at_gate` — the gate (`gate-ending-to-game.md`, Stage D), never a second door.** One more read of
## `Progress.boss_died()` (`gate_view._process()` and `_on_ticked()`'s wall latch are the other two), not a
## flag this file holds — the same "three reads of one accessor" the plan's own structure section names.
##
## **The tie rule, decided: a death wins.** If the player is downed *and* on the seat in the same frame, the
## fourth argument below (`at_gate and not _char.downed`) is `false` and the death title shows — a downed
## body did not walk through the arch.
##
## **`_settlement.is_showing()` stands in for "was it open last frame"** — the same "read the window's own
## state instead of holding a second latch" idiom `_toggle_assembly()` already holds for `_circle_window.visible`.
func _sync_settlement() -> void:
	var at_gate := _world.progress().boss_died(MonsterDefs.KIND_ROOSTER) and StageGate.at(_char.center())
	# **The gate's two clocks, and the only place they are driven** (`stage-clear-sequence.md`, Beats 2 and 3).
	#  This function is physics, which is why they live here and not on `_gate_view._process()` — 24 frames is
	#  0.4s at 60Hz and 0.167s on a 144Hz panel, and one animation whose halves run at machine-dependent speeds
	#  is the seam `three_pick_window.tick_confirm()`'s own header records.
	# **Increment first, then test.** `take_done()` below reads the counter this call just raised, so the first
	#  frame inside the band counts as 1 and the panel opens on the `GATE_TAKE_FRAMES`-th frame of contact.
	_gate_view.tick_gate(at_gate)
	# **The chain — `town -> 1 -> 2 -> 3` (GDD's session loop), taken here and nowhere else.**
	#
	# **The settlement screen is the run's end, so a stage that hands on does not open it.** That window's own
	#  header says it in its own words: "the run is over, so there is nothing left to watch". Walking from
	#  stage 1 into stage 2 is not the run being over, so `_enter_stage()` runs instead and `want` below is
	#  never reached this frame.
	# **With `NO_NEXT` — every room in the table today — this branch is not taken and everything below is
	#  byte-for-byte what it always was.**
	#
	# **It cannot re-fire.** `_enter_stage()` -> `_rebuild()` -> `_gate_view.reset_gate()` zeroes the take
	#  clock in the same call, so `take_done()` is false again the moment the new stage stands up. The loop is
	#  closed structurally, not by a latch that a later door could forget to clear.
	# **`not _char.downed` is the same tie rule `want` below holds** — a downed body did not walk through the
	#  arch, and dying on the seat must open the death panel, not carry you into the next stage.
	if _next_stage_id != StageDefs.NO_NEXT and _gate_view.take_done() \
			and not _char.downed and not _in_town:
		# **A refusal falls through to the settlement screen deliberately** (`_enter_stage()`'s own comment):
		#  stranded on the seat with nothing happening is the one outcome worse than ending the run here.
		if _enter_stage(_next_stage_id):
			return
	# **`take_done()` *replaces* `at_gate` here — it is not `and`ed with it.** The take latches inside
	#  `tick_gate()` (its own header), so by the time it completes the player may well have walked out of the
	#  band; requiring `at_gate` again on the opening frame would undo the latch entirely and hand back exactly
	#  the outrunnable hold it exists to prevent. `at_gate` above is now read for one purpose only: starting
	#  the clock.
	# **`_char.downed` is still the other half and still wins the tie** — a death opens the panel on the frame
	#  it happens, take clock or not, and the fourth argument below is what makes it read as a death.
	var want := (_char.downed or _gate_view.take_done()) and not _in_town
	if want and not _settlement.is_showing():
		var pr := _world.progress()
		# **`take_done()` here too, for the same reason `want` uses it** — read `at_gate` on the opening frame
		#  and a player who walked out of the band during the take gets the death title on a run they cleared.
		# **The title comes from the room table, not from `Fx`** — `_stage_title` was set by `_apply_room()`
		#  when this room was built. Left to the window's own default, adding stage 2 would show it "스테이지 1
		#  클리어" with every check still green (`net_stages` drives a synthetic title for exactly that).
		_settlement.open(pr.run_seconds(), pr.damage_dealt, pr.gems_this_run(),
			_gate_view.take_done() and not _char.downed, _stage_title)
		# **The three-pick may be open when you go down** — the same reason `reset_stage()` already cancels
		#  the confirm afterglow and `_toggle_assembly()`/`_toggle_research()` already decline a pending pick
		#  before claiming the screen for themselves.
		_world.progress().decline()
		_pick_window.cancel_confirm()
	elif not want and _settlement.is_showing():
		_settlement.close()


## Hits the screen only on frames where a tick ran.
## **Notifications are cleared by the next tick's `spell.step()`** — read after the character has walked, they are still alive.
## **`jump_press` is the same value `_world.frame()` was just handed** (`_physics_process`'s own comment) —
##  not re-read here, so the sound and the sim can never disagree about which frame the key went down on.
func _on_ticked(jump_press: bool = false) -> void:
	# **Sound reads from `_char` directly, the same fields `character_view`/`hp_view` already read** —
	#  `on_ground`/`hp` only change on a tick, so sampling them here (once per tick) rather than from
	#  `_physics_process` (60Hz) is what keeps this off the aliasing trap CLAUDE.md names repeatedly.
	# **Jump before landing** — a character cannot do both in the same tick, but ordering it this way means a
	#  press that happens to coincide with a landing frame is heard as a jump, not swallowed by the `elif`
	#  shape a single combined branch would otherwise need.
	if jump_press and not _char.downed:
		_sfx.play_jump()
	if not _prev_on_ground and _char.on_ground:
		_sfx.play_land()
	if _char.hp < _prev_hp:
		_sfx.play_hit()
	_prev_on_ground = _char.on_ground
	_prev_hp = _char.hp

	# **The bull's reward, automatic — session correction.** `_take_boss_reward()` used to have exactly one
	#  caller, the debug key L (`_input.reward_taken_requested`), so a player who never opens the debug
	#  layer kills the bull and gets nothing: no fire rune, no water, no way to burn the wood wall, and the
	#  rooster/gate are unreachable — the game ends at the bull with nothing telling the player why.
	# **Gated on `is_reward_pending`, not called every tick once any boss has died.** `_take_boss_reward()`
	#  itself calls `Progress.clear_pending_boss_rewards()`, which flips *every* present boss's pending flag
	#  to false, not just the bull's (`progress.gd`'s own "presence as a key is the whole fact" idiom). Calling
	#  it unconditionally every tick once the bull is dead would, the tick the rooster later dies, silently
	#  clear the rooster's own still-unbuilt reward flag too — nothing granted for it, and nothing left
	#  pending to show on the HUD either. Reading `is_reward_pending(KIND_BULL)` first means this only ever
	#  fires the one tick the bull's own reward is actually waiting, and never touches the rooster's flag.
	# **The debug key L is untouched and calls the same function** — copying the body into a second place is
	#  exactly how "only one of the two paths gets fixed" happens the next time this logic changes.
	if _world.progress().is_reward_pending(MonsterDefs.KIND_BULL):
		_take_boss_reward()


	# **The boss entrance — `boss-entrance-and-hp-bar.md` Stage C.** `woke_boss_id()` lives exactly one tick
	#  (`MonsterPlacement._woke_boss_id`'s own comment), so this has to be read here, in `_on_ticked()`, and
	#  nowhere else — the same reason the death notifications a few lines below are read inside this same
	#  branch. `monster_by_id()` is a live reference, not a copy (`_boss`'s own comment).
	var woke_id := _world.woke_boss_id()
	if woke_id != 0:
		_boss = _world.monster_by_id(woke_id)
		_boss_bar.show_boss(_boss)
		_entrance_frames = 0

	# **The east wall comes down the instant the rooster dies — before `consume_changed()` below**, or the
	#  renderer would see the hole one tick late (`_grid.consume_changed()` is this function's own last line).
	# **One rectangle, not a run of carves.** `cmd_fill` goes through `_write_cell`, which is what counts
	#  `_changed` and wakes the neighbouring chunks — the same door the map builder uses. A loop of
	#  `cmd_carve` would be 24 discs to erase a rectangle and would leave rounded corners in stone.
	if not _room3_gate_open and _world.progress().boss_died(MonsterDefs.KIND_ROOSTER):
		_room3_gate_open = true
		var gate_wall := StageGate.wall_cells()
		_grid.apply(CellGrid.cmd_fill(
			gate_wall.position.x, gate_wall.position.y, gate_wall.end.x, gate_wall.end.y, Mat.EMPTY))
		# **The one thing that tells the player the wall fell** (`stage-clear-sequence.md`, Beat 1). The wall is
		#  off screen from most of room ③ — `net_gate`'s own camera check measures that — so a flash there is a
		#  picture nobody sees. **A shake is felt wherever you are standing.**
		# **Inside the latch, so it can only fire once**: a per-tick re-kick is structurally impossible here.
		_blast_fx.kick(Fx.GATE_WALL_SHAKE_PX, Fx.GATE_WALL_SHAKE_SECS)

	# The trail must come **after** the sim has run, or it is one tick stale.
	_spell_view.on_tick()

	# **A blast notification is valid only within this tick** — the next `step()` clears it.
	#  Do not read it here and only the hole is left, with no flash and no shake, and **no error is raised.**
	_blast_fx.on_blasts(_spell.get_blast_x(), _spell.get_blast_y(),
		_spell.get_blast_element(), _spell.get_blast_gen())
	# **Once per tick, not once per blast.** `blast_fx._kick`'s own rule ("the stronger one wins") exists
	#  because eight detonations on one tick must not be felt as eight shakes — the same reasoning applies to
	#  sound: eight overlapping copies of the same clip reads as a glitch, not as "a big chain went off".
	if _spell.blast_count() > 0:
		_sfx.play_blast()
	_blast_count += _spell.blast_count()

	# **A pillar notification is valid only within this tick too — the same place, the same reason.**
	#  Miss this and a condense glyph carves no cell, so with no pillar drawn either it is a pure signature
	#  fake: the model raised a pillar and the screen shows nothing (`glyph-condense.md` §11.6, Step 3).
	_blast_fx.on_pillars(_spell.get_pillar_x(), _spell.get_pillar_y(),
		_spell.get_pillar_w(), _spell.get_pillar_h(), _spell.get_pillar_element())

	# **A death notification is valid only within this tick** — the tick branch of the next `frame()` clears
	#  it (`world_step.gd`'s header). Do not read it here and the corpse afterimage cannot appear in principle —
	#  exactly the same place as `blast_fx.on_blasts()` (`monster_view.on_tick()`).
	_monster_view.on_tick()

	# **The hit flash/shake — the same tick-not-frame door as the two calls above** (`character_view.on_tick()`'s
	#  own header: watched at 60Hz, the same write could be read zero, one, two or three times depending on phase).
	_char_view.on_tick()

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
func _process(dt: float) -> void:
	_spell_view.set_render_alpha(float(_world.phase()) / float(Tuning.TICK_DIVIDER))
	# **Camera work — it runs ahead the way you move and comes back when you stop** (user request).
	#  **It rides on `position`, folded into the focus, not on `offset`** — `offset` is the shake's axis and
	#   the two would overwrite each other. And going through the focus means **the clamp still applies**:
	#   led toward the stage edge, the camera still refuses to show the void outside the map.
	# **The input axis, not `_char.facing`** — facing survives after you let go, so the camera would stay led
	#  out while standing still, which is the opposite of what was asked for.
	_cam_lead = camera_lead(_cam_lead, _input.move_axis(), dt)
	# **Following is `position`, shake is `offset`.** Put both on one axis and the next frame's following
	#  overwrites the shake, and **the shake quietly disappears.**
	# The visible size is read from `get_viewport_rect()` — read `ProjectSettings` here as well and the day
	#  the window mode changes the two places diverge.
	# **Zoom is applied to the clamp too.** `Camera2D.zoom` 0.5 makes the visible world **twice** as wide, and
	#  feeding the raw viewport size to `camera_center` keeps clamping at the play scale — the camera then
	#  stops at the old margin and **half the screen fills with the void outside the map**, with no error.
	# **The boss entrance folds into these same two lines** (`boss-entrance-and-hp-bar.md` Stage C) — anything
	#  written to `_camera.zoom`/`.position` from anywhere else is overwritten the very next frame, the same
	#  reason `_cam_lead` above already lives here instead of in its own `_process()`.
	# **`Fx.PLAY_ZOOM_MULT` is a third, independent factor** — it composes the same way the debug ladder
	#  (`ZOOM_STEPS[_zoom_step]`) already composes with `entrance_zoom()`, so the entrance zooms in from
	#  whatever this already set rather than doubling on top of it (`Fx.PLAY_ZOOM_MULT`'s own comment).
	var z: float = ZOOM_STEPS[_zoom_step] * Fx.PLAY_ZOOM_MULT * entrance_zoom(_entrance_frames)
	_camera.zoom = Vector2(z, z)
	# **Snapped to the screen's pixel grid** — see `snap_camera_px`. Without it the whole world shivers
	#  by a pixel every frame while walking, and it reads as the *character* stuttering, not the camera.
	var focus := entrance_focus(_char.center() + Vector2(_cam_lead, 0.0), _boss_focus(), _entrance_frames)
	_camera.position = snap_camera_px(camera_center(focus, get_viewport_rect().size / z, world_size()), z)
	# Shake is **the camera's offset**. `stage_input._to_world` undoes the canvas transform, so aim does not
	#  drift even while shaking — without undoing it, a click goes to the wrong cell with no error.
	# The order of this node's `_process` and `blast_fx`'s `_process` is not guaranteed, so it **can be one
	#  frame late** — unobservable on a 0.2-second shake.
	_camera.offset = Vector2(_blast_fx.shake_offset())


## R. **Not decoration** — terrain marks are this stage's main evidence, and with holes left over from the
##  previous experiment two combinations cannot be compared. Without a reset, acceptance 1 and 2 do not hold.
func reset_stage() -> void:
	_rebuild(true)


## **Into the next stage of the same run** — stage 1's gate walking you into stage 2, with the level, the
##  원석, the unlocks and the earned rune intact (GDD's session loop: `town -> 1 -> 2 -> 3 -> clear`).
##
## **Everything about the world is torn down exactly as `R` tears it down. The one thing that is not is the
##  run.** `_rebuild(false)` opens `WorldStep.next_stage()` instead of `WorldStep.reset()`, and that single
##  line is the whole difference — see `progress.next_stage()`'s own box for what would be lost otherwise.
##
## **Two refusals, both barking rather than doing something plausible**, because the alternative to each is a
##  thing that cannot be seen on screen:
##  · **a row chaining into itself** would rebuild the same stage forever, one rebuild per frame, and read as
##    the game freezing at the gate
##  · **a row chaining outside the table** would set an id whose every later room build barks instead
##
## Returns false when it refused, and **the caller must then fall through to the settlement screen** — a
##  refusal that silently did nothing would strand the player standing on a seat with no way on and no way out.
func _enter_stage(stage_id: int) -> bool:
	if stage_id == _stage_id:
		push_error("stage %d chains into itself - refusing to rebuild it forever" % stage_id)
		return false
	if stage_id < StageDefs.STAGE_1 or stage_id >= StageDefs.ROWS.size():
		push_error("stage %d chains into %d, which is not a stage in the table" % [_stage_id, stage_id])
		return false
	_stage_id = stage_id
	_rebuild(false)
	return true


## **The one teardown list, and which `Progress` door it opens is the only argument.**
##
## **A flag rather than two functions, deliberately.** Copied, the two lists drift: a counter added to one
##  path and not the other rides into the next stage as a live monster or a stale bolt, and nothing barks.
##  Every line below is identical for `R`, for going home, for the departure gate and for the chain — the
##  `if` is the entire difference between them.
func _rebuild(end_the_run: bool) -> void:
	_grid.apply(CellGrid.cmd_reset())
	_spell.reset()
	# The views are cleared with it. Without clearing, dead projectiles' trails and flashes pile up every time R is pressed.
	_spell_view.clear()
	_blast_fx.clear()
	# Without clearing, the dead session's hp dictionary, flashes, damage numbers and corpses briefly ride
	#  into the new session (the same door as `spell_view.clear()` and `blast_fx.clear()` — `monster_view.gd`'s header).
	_monster_view.clear()
	# Without clearing, a hit taken the instant before pressing R paints its flash over the newly spawned
	#  character for a few frames — the same door as `_spell_view.clear()`/`_blast_fx.clear()` above.
	_char_view.clear()
	_camera.offset = Vector2.ZERO
	# **Every counter is reset.** Leave one behind and the "fire > impact = it left the grid and vanished"
	#  diagnosis above becomes false forever after a single R — R is this stage's main measuring instrument,
	#  so that diagnosis is the eye.
	#  The queue and the fire count are held by `_world` — touch them here as well and there are two places to reset.
	# **The one line that separates a new run from the next stage of this one.** `next_stage()` clears the
	#  world identically and leaves `Progress` standing (that function's own comment).
	if end_the_run:
		_world.reset()
	else:
		_world.next_stage()
	# **Ownership is the truth; the seat is not** (`rune-lock-and-receiving.md` — verify-run's own finding: a
	#  reset revoked ownership but left possession, and the new run couldn't *pick* fire in the palette while
	#  still *firing* it at full effect, measured on the map, not inferred). `_world.reset()` above already
	#  reverted `Progress`'s owned set to the starting kit; this is the other half of the same invariant
	#  ("seat ⊆ owned") from the door that actually breaks it — nothing else in this codebase revokes a rune.
	# **On the chain it revokes nothing, and that is right**: `next_stage()` does not narrow the owned set, so
	#  the fire the bull granted in stage 1 is still owned and stays in the seat walking into stage 2.
	_revoke_unowned_rune()
	# **`cancel_confirm()` too** — `_world.reset()` clears `Progress` (so a lingering `pending_picks`/`_drawn`
	#  do not ride into the new run), but the confirmation afterglow does not live in `Progress` at all
	#  (`is_showing()`'s own comment) and nothing else would clear it. Left out, pressing R during the
	#  afterglow left it floating over a freshly reset world for up to 0.7s, `Stats` hidden the whole time.
	_pick_window.cancel_confirm()
	# **`_settlement.close()` too** (`run-end-settlement.md`, Stage D, acceptance 10) — the count-up clock does
	#  not live in `Progress` any more than the pick window's own confirmation afterglow does (comment above),
	#  so nothing else would clear it. Left out, pressing `R` while the panel is open would leave a settlement
	#  screen reporting a run that no longer exists standing over a fresh stage.
	_settlement.close()
	# **`reset_gate()` too, and it zeroes both counters** (`stage-clear-sequence.md`, Beat 3 / acceptance 8).
	#  Same reason `_settlement.close()` above exists: the gate's two clocks live in the view, not in
	#  `Progress`, so `_world.reset()` does not reach them. **`_lit` surviving is not cosmetic** — the arch
	#  would pop fully opaque on the second run instead of fading up, with every other check still green.
	_gate_view.reset_gate()
	# **The boss entrance clears with everything else** (`boss-entrance-and-hp-bar.md` Stage C) — the same
	#  "revert every counter" reasoning `_gate_view.reset_gate()` right above already states for `_lit`. Left
	#  out, the bar would ride a fresh run showing a boss from the last one, and the camera's own
	#  `_boss_focus()` would read a corpse from a stage that no longer exists.
	_entrance_frames = -1
	_boss = null
	_boss_bar.clear_boss()
	# **Onboarding dies on every rebuild** — R, going home and the chain all route through here, and this is
	#  the one call site all three share (`_onboard_step`'s own header). `_leave_town()` is the only place
	#  that restarts it, and it does so *after* calling `reset_stage()` (which reaches this function), so the
	#  order here does not race that decision.
	_onboard_step = ONBOARD_OFF
	_circle_window.set_onboarding(false)
	_blast_count = 0
	# **Room ③'s wall latch.** `_build_room()` below always rebuilds the terrain in this same call, so
	#  the flag and the wall never disagree — safe here for the reason `_settlement`'s own latch ban above it
	#  is not (that one strands a `mouse_filter` over the whole viewport; this one strands nothing).
	_room3_gate_open = false
	_build_room()
	# **Resynced after the spawn, not left at whatever the old character was doing.** Skip this and a
	#  character who was airborne the instant before `R` was pressed spawns grounded next tick, and
	#  `_on_ticked()` reads that as a landing that never happened — the same "false edge across a reset" shape
	#  every latch in this function (`_room3_gate_open` above, `_gate_view.reset_gate()`) already guards.
	_prev_on_ground = _char.on_ground
	_prev_hp = _char.hp


## **Builds whichever room `_in_town` says, and stands the character in it.** One function, two rooms —
##  split into `_build_town()`/`_build_stage()` and the day one of them forgets to move the spawn, the
##  character starts inside solid rock and the only symptom is "R does nothing".
##  That is not hypothetical: `SPAWN_TILE`'s own comment records exactly that accident on the stage side.
##
## **The grid is not reset here.** Every caller (`reset_stage`, `enter_town`, `_leave_town`) resets first —
##  resetting inside would mean the two doors that switch rooms could not also clear the views and counters
##  in the same breath, which is what `reset_stage` exists to do.
func _build_room() -> void:
	_apply_room(StageDefs.row(_stage_id))


## **Builds one row of the room table into the world. Every per-room value this shell knows is read here and
##  nowhere else** — that is the whole point of the split from `_build_room()` above.
##
## **Why it takes the row instead of reading `_stage_id` itself**: a net can hand it a **synthetic** row whose
##  every field differs from stage 1's and then check that every one of them actually reached the world
##  (`net_stages`). A field left reading a stage-1 constant does not follow the synthetic row and goes red —
##  which is the only way to catch "stage 2 was added to the table and silently kept stage 1's gate" **before**
##  stage 2 exists. Reading `_stage_id` inside would make that check impossible to write with one row.
func _apply_room(room: Dictionary) -> void:
	build_room_into(_grid, room)
	# `monster-placement-stage1.md` Stage C — the wiring line. **In the room build,
	#  not `_ready()`**: every room switch (`reset_stage()`/`enter_town()`/`_leave_town()`) routes through
	#  here, and `net_gate._wired_root()` never runs `_ready()` at all, so a line there would be invisible
	#  to every net in this repo and would strand the placement the moment R was first pressed (that
	#  plan's own "the wiring line" section). The town's row carries an empty table; it is not a branch here.
	# **`FLOOR_CY` is not a per-room field** — it derives from the map height, which is global at 48 tiles
	#  (`stage_defs.gd`'s own header, and `build_map_into`'s guard below enforces it).
	_world.set_placement(room["monsters"], StageDefs.FLOOR_CY)
	# **The gate's geometry is pushed into `src/actor/`, never preloaded from there** — the same door
	#  `set_placement()` above already is (`stage_gate.set_geometry()`'s own comment).
	# **A room with no gate pushes nothing and leaves the last stage's numbers standing.** That is inert, and
	#  the reason it is not cleared instead is measured, not assumed — see that function's own comment.
	var gate: Dictionary = room["gate"]
	if not gate.is_empty():
		StageGate.set_geometry(
			int(gate["seat_tx"]), int(gate["floor_ty"]),
			int(gate["wall_tx0"]), int(gate["wall_tx1"]),
			int(gate["wall_ty0"]), int(gate["wall_ty1"]))
	# **The clear screen's title comes with the room**, read once here rather than at the open site — see
	#  `_stage_title`'s own comment.
	_stage_title = String(room["title"])
	# **And so does what comes after it.** The chain is a field, not a branch — `_sync_settlement()` reads
	#  this one value and never asks "which stage am I on".
	_next_stage_id = int(room["next"])
	# **The fixtures show exactly when the town does.** Derived from the latch every time a room is built,
	#  never written at the two doors — that is the same "derive it, do not push it" rule `_update_hud`
	#  applies to `_hud.visible`, and for the same reason: a door that forgot would strand the benches
	#  floating over stage 1.
	_town_view.visible = _in_town
	# **The backdrop swaps with the room.** `sky_background.set_backdrop()` was written for exactly this and
	#  had never been called by anything — the town's two pictures sat in `assets/stage/` with constants
	#  pointing at them and no path to the screen, which is CLAUDE.md's own "is there a path for the thing you
	#  want to see to reach the screen" in its purest form: the art was in, the constants were in, and the
	#  town rendered as a black box.
	# **From the row, not from `_in_town`** — this was the last two-way ternary left in the room build, and
	#  it was left standing on a reason that has since been paid rather than on one that was wrong: a
	#  source-text scan for the literal `BG_TOWN_FAR_TEXTURE` in this file. That scan is gone, replaced by a
	#  driven read of the node's own textures. See the `bg_far` comment in `stage_defs.gd`.
	#  ⇒ **Stage 2 no longer needs a line here.** Nothing in this function asks which room it is building.
	_sky.set_backdrop(String(room["bg_far"]), String(room["bg_near"]))
	# **Cleared with the room.** A bench's line surviving a departure would be the town talking over stage 1.
	_town_message = ""
	# **The window closes with the room.** Leaving it open would put the town's parchment panel over stage 1,
	#  and there is no fixture there to close it at.
	if _research_window != null and _research_window.visible:
		_research_window.toggle()
	var spawn: Vector2i = room["spawn"]
	_char.place(
		spawn.x * Tuning.TILE_CELLS * Tuning.CELL_PX,
		spawn.y * Tuning.TILE_CELLS * Tuning.CELL_PX)


# ══════════════════════════════════════════════════════════════════
#  The town — `docs/design/town.md`
#
#  **What is here is the room and the door, not the benches' contents.** The research bench's four unlock
#   slots and the assembly bench's point budget are that doc's own TBDs and have no numbers yet; standing
#   them up as buttons that spend nothing would be this repo's "reporting a stub as finished".
#  ⇒ **Every fixture below does something real or says plainly that it does not.**
# ══════════════════════════════════════════════════════════════════

## E. **One key, and where you are standing decides what it does.**
##
## **The downed door moved.** It used to be E while downed in the stage; **the settlement screen is what tells
##  you the run is over now** (`run-end-settlement.md` — `_sync_settlement()` opens it on its own the instant
##  you go down, and its own button is the only way home). `_interact()` keeps only the `not _in_town` guard —
##  E while downed in the stage does nothing here, because there is a full-screen panel over it doing the
##  telling instead.
##
## **`_town_view.reachable()` is the single source of "which fixture".** The prompt on screen is drawn from
##  that same call, so the label and the action cannot disagree — a prompt reading `[E] 조립대` while E opens
##  the gate is exactly the screen/sim split this repo calls its signature fake.
func _interact() -> void:
	if not _in_town:
		return
	match _town_view.reachable():
		Fixtures.KIND_GATE:
			if not _town_gate_locked():
				_leave_town()
		Fixtures.KIND_ASSEMBLY:
			# **The same window Tab opens, deliberately** (`town.md`: "it is the same window"). What the town
			#  adds is *choosing what to equip within a budget*, and that needs the point table which does not
			#  exist yet — so today the bench opens the reordering window and nothing is pretended.
			_toggle_assembly()
		# **연구대's door is closed, not removed** (`onboarding-and-palette-tabs.md` Stage 7 — the plan's own
		#  "the door closes; nothing is deleted"). `_toggle_research()`, `Progress.buy()`, `UnlockDefs` and
		#  `research_window.gd` all stay reachable through code — only this call stops happening, so E at the
		#  bench does nothing and the player walks past it, matching the 「준비중」 prompt `town_view` now
		#  draws there. `net_research` must stay green with no edit — if it goes red, the door was not the
		#  only thing that moved.


## **The research bench's HUD line — the rune pool, unlocked and locked in one list, and what an unlock costs.**
##
## **It stopped saying `해금은 아직 없다`** (`research-bench-unlocks.md`): three unlocks are for sale now, and
##  the price is read from `Progress.GEMS_PER_UNLOCK` rather than typed here, so retuning it moves what the
##  player is charged and what the player reads in one edit.
##
## **That list is the design's own core requirement, not a placeholder** — "unlocked and locked sitting in one
##  list is the best possible demonstration that the pool widened" (`town.md`), and it reads `Progress`, the
##  same live ownership `circle_window`'s palette gates on. Nothing here is invented for display.
##
## **What it does not do is spend anything.** There is no material count in `Progress` and no price table
##  (both are that doc's open TBDs), so **there is no buy button and the text says so.** A button that took
##  nothing and gave nothing would be the fake; a list that is honestly only a list is not.
func _toggle_research() -> void:
	# **Opening one window closes the others** — the same rule `_toggle_assembly`/`_toggle_pick` already hold
	#  between themselves, extended to a third. `HUD/Stats` is not the contested resource here (this window
	#  has its own panel), but two open windows overlapping is its own kind of unreadable.
	if not _research_window.visible:
		if _circle_window.visible:
			_circle_window.toggle()
		_world.progress().decline()
		_pick_window.cancel_confirm()
	_research_window.toggle()
	# The HUD line still says it, for the same reason the window's own footer does — the window can be closed
	#  while the fact stays true, and `research_text` is what a net drives (its own header).
	_town_message = research_text(_world.progress())


## **Pure and static, so a net drives the list itself** — the same seat as `camera_center` and
##  `MonsterView.resolve_state`. What matters here is *which runes read as locked*, and that is a value, not
##  a screenshot: a bench that showed everything unlocked would be the pool looking already-widened on run one.
static func research_text(pr: Progress) -> String:
	var parts: Array[String] = []
	for rune: int in Tuning.ELEM_ALL:
		parts.append("%s%s" % [Fx.ELEM_NAMES.get(rune, "?"), "" if pr.owns_rune(rune) else " (잠김)"])
	return "[연구대] 룬 %s — 해금 하나에 원석 %d" % [" · ".join(parts), Progress.GEMS_PER_UNLOCK]


## **Into the town.** Called when the player takes E while downed — the run is over, so the whole world is
##  rebuilt, exactly as R does. **`reset_stage()` is reused rather than copied**: it is the one place that
##  knows every counter, view and pending window that has to be cleared, and a second copy of that list would
##  fall behind the first the next time something is added to it.
func enter_town() -> void:
	_stage_id = StageDefs.ROOM_TOWN
	reset_stage()


## **Out through the departure gate, into stage 1.** The other half of `enter_town()` and the same shape —
##  **the assembly you leave with is not reset**, because R never resets it either (`reset_stage`'s own
##  comment) and "you leave carrying the build you chose" is the gate's entire meaning.
## **Which stage the gate leads to is one constant, and it is here.** There is one stage, so it is `STAGE_1`;
##  the day there are several this becomes the town gate's own choice, not a second `bool`.
func _leave_town() -> void:
	_stage_id = StageDefs.STAGE_1
	reset_stage()
	# **The stage-1 entry moment — onboarding starts here, once.** `reset_stage()` above already zeroed
	#  `_onboard_step` back to `ONBOARD_OFF` (the same `_rebuild()` call `R` itself makes); this is the one
	#  place that restarts it, and only when `Progress._onboarding_seen` says it has never finished.
	if not _world.progress().has_seen_onboarding():
		_onboard_step = ONBOARD_ARROW
		_circle_window.set_onboarding(true)


## **The other half of the "seat ⊆ owned" invariant** — called only after something has just revoked
## ownership (today, only `_world.reset()` inside `reset_stage()` does). If the rune currently in the seat
## fell out of the owned set, it comes down to `Tuning.ELEM_NONE`, **never `RUNE_EMPTY`** — the same
## un-emptiable-seat rule `circle_window`'s click-to-clear fix already holds, for the same reason: the circle
## must keep firing.
##
## **Does not touch glyphs or the circle id.** R deliberately never resets the assembly at all
## (`reset_stage`'s own comment above) — a placed glyph survives R, and that stays true. Glyphs carry no
## ownership concept to enforce in the first place; this only narrows the one thing that does: *the seat may
## not hold a rune the player does not own.*
##
## **Every socket, not just seat 0** — verify-read found this hardcoded to the round circle's single seat
## (`element()`'s own "exactly one rune slot" comment, which this used to lean on the same way). With a
## triangle circle equipped, an unowned rune parked in socket 1 or 2 (reachable: earn a rune, place it there,
## press R) survived untouched, and `SpellCircle.shots()` fires it anyway — silently, since nothing else
## checks ownership per socket. **`rune_count()` covers "no circle" the same way `rune_at(0)`'s old
## single-slot check did** — 0 slots, loop runs zero times, nothing to revoke.
##
## **Driven directly, not only through `reset_stage()`** — `net_render._revoke_unowned_rune_only_touches_
## what_is_not_owned` calls this with the owned set at `{none, water}`, a state `Progress.reset()` itself can
## never leave behind (it always narrows to exactly `{none}`). Proving "checks ownership" rather than "always
## clears" needs that state — through `reset_stage()` alone the two are observationally identical.
func _revoke_unowned_rune() -> void:
	for i in _circle.rune_count():
		var rune := _circle.rune_at(i)
		if rune != SpellCircle.RUNE_EMPTY and not _world.progress().owns_rune(rune):
			_circle.set_rune(i, Tuning.ELEM_NONE)


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
## **The camera runs ahead the way you move, and comes back when you stop** (user request).
##  Returns the new lead in world px, given the current one and this frame's input axis.
##
## **`pow(rate, dt)` and not a fixed per-frame fraction.** Written as `lead += (target - lead) * 0.1`, the
##  same code gives **a different feel at a different frame rate** — and the one machine where that shows up
##  is not the one it was tuned on. `character.gd`'s `RECOIL_DECAY_PER_SEC` is the same shape for the same reason.
##
## **Standing still is not a special case.** Axis 0 makes the target 0, so returning home runs through the
##  identical line as leading out — one path, so the two cannot drift apart in feel.
##
## **Static and pure, like `camera_center`** — a lead can be fed in and the next one taken back with no scene,
##  no camera and no character, so the nets measure the curve itself rather than a screenshot of it.
static func camera_lead(lead: float, axis: float, dt: float) -> float:
	var target := Fx.CAM_LEAD_PX * signf(axis)
	return lead + (target - lead) * (1.0 - pow(Fx.CAM_LEAD_DECAY_PER_SEC, dt))


## **The camera lands on whole screen pixels. This is what stops the walk from looking like it stutters.**
##
## Everything that stands on the ground is drawn at an **integer** world position — `body.gd` keeps `x`/`y`
##  as ints with the fraction in `_rem_*`, so the character advances 4, 4, 5, 4 px on successive frames.
##  The camera does not: `camera_lead` is an exponential decay and `camera_center` a `clampf`, both float.
## ⇒ The character's position **on screen** is `int - float`, which lands on a different side of the pixel
##  boundary from one frame to the next. With `default_texture_filter=0` (Nearest) that is not a blur but a
##  **hard one-pixel jump, every frame, on every sprite at once** — and because the terrain jumps with it, the
##  eye reads it as the character stuttering rather than as the camera moving.
##  **Nothing barks and no net catches it**: every value involved is correct, and the defect exists only in
##  the difference between two of them.
##
## **Multiplied by zoom before rounding, and divided back after.** The grid to snap to is the *screen's*, and
##  at `zoom` 0.5 one screen pixel is two world px — rounding the world position alone would still leave the
##  canvas on a half-pixel there. `ZOOM_STEPS` are all powers of two, so this division is exact.
##
## **Static and pure, like `camera_center` and `camera_lead` beside it** — the nets feed a position and a zoom
##  and read the snapped value, with no scene and no camera.
static func snap_camera_px(pos: Vector2, zoom: float) -> Vector2:
	if zoom <= 0.0:
		return pos
	return (pos * zoom).round() / zoom


static func camera_center(focus: Vector2, view: Vector2, world: Vector2) -> Vector2:
	return Vector2(_axis_center(focus.x, view.x, world.x), _axis_center(focus.y, view.y, world.y))


static func _axis_center(f: float, v: float, w: float) -> float:
	if w <= v:
		return w * 0.5
	return clampf(f, v * 0.5, w - v * 0.5)


## **The boss entrance's zoom, pure and static** (`boss-entrance-and-hp-bar.md` Stage C) — the same seat
## `camera_lead`/`snap_camera_px` already hold: a net feeds a frame count and reads the value, with no scene
## and no camera. **This is the only reason any of it is measurable** — today's debug zoom (`ZOOM_STEPS`) is
## a key with nothing measuring it, that constant's own comment says so.
##
## A multiplier on `ZOOM_STEPS[_zoom_step]`, not a set value — the debug `-`/`=` keys keep working underneath
## it and this function never has to learn which step is selected. **Identity (`1.0`) outside the entrance
## and at its very last frame** — that identity, not "it looked back to normal", is what acceptance 6/7 turn
## into a value a net can assert.
static func entrance_zoom(frames: int) -> float:
	var zoom_in := Fx.BOSS_ENTRANCE_ZOOM_IN_FRAMES
	var hold := Fx.BOSS_ENTRANCE_HOLD_FRAMES
	var total := Fx.boss_entrance_total_frames()
	if frames < 0 or frames >= total:
		return 1.0
	if frames < zoom_in:
		return lerpf(1.0, Fx.BOSS_ENTRANCE_ZOOM_MULT, float(frames) / float(maxi(zoom_in, 1)))
	if frames < zoom_in + hold:
		return Fx.BOSS_ENTRANCE_ZOOM_MULT
	var out_t := float(frames - zoom_in - hold) / float(maxi(Fx.BOSS_ENTRANCE_OUT_FRAMES, 1))
	return lerpf(Fx.BOSS_ENTRANCE_ZOOM_MULT, 1.0, out_t)


## **The boss entrance's focus, pure and static, the same seat as `entrance_zoom` beside it.** Lerps from the
## player's own led focus to the boss and back — `player`/`boss` are both already-computed world points, not
## `Character`/`Monster` references, so a net drives it with two bare `Vector2`s and no scene at all.
## **Goes through `camera_center()` at the call site, not here** — so the clamp still applies and the camera
## still refuses to show the void outside the map while it is looking at the boss.
static func entrance_focus(player: Vector2, boss: Vector2, frames: int) -> Vector2:
	var zoom_in := Fx.BOSS_ENTRANCE_ZOOM_IN_FRAMES
	var hold := Fx.BOSS_ENTRANCE_HOLD_FRAMES
	var total := Fx.boss_entrance_total_frames()
	if frames < 0 or frames >= total:
		return player
	if frames < zoom_in:
		return player.lerp(boss, float(frames) / float(maxi(zoom_in, 1)))
	if frames < zoom_in + hold:
		return boss
	var out_t := float(frames - zoom_in - hold) / float(maxi(Fx.BOSS_ENTRANCE_OUT_FRAMES, 1))
	return boss.lerp(player, out_t)


## **A reference read, not a pure function** — `_boss` is instance state (`_process()`'s own doc on why),
## so this cannot live beside `entrance_zoom`/`entrance_focus` above. **Only guards against `null`** — a boss
## that died mid-entrance stays a valid (if now-corpsed) reference (`_boss`'s own comment: `RefCounted`, never
## freed by death), so this never has to fall back to the player mid-lerp; it only exists so a fresh run with
## no boss yet never dereferences a null.
func _boss_focus() -> Vector2:
	if _boss != null:
		return _boss.center()
	return _char.center() + Vector2(_cam_lead, 0.0)


## ASCII map -> commands. Terrain goes through `apply()` too — if an external event bypasses the command
##  door, side effects added later (waking, notifications) are skipped wholesale and **nothing happens, with no error.**
##
## **Why static**: the nets stand up **this code and this map, the ones that actually run**, and measure them.
##  If a net held a copy of the map, it would not age along when the terrain changes.
##
## **It takes which stage now, defaulting to stage 1.** Every existing call (`Stage.build_terrain_into(g)`,
##  in six nets) means exactly what it meant before; a second stage is a second argument, not a second door.
static func build_terrain_into(g: CellGrid, stage_id: int = StageDefs.STAGE_1) -> void:
	build_room_into(g, StageDefs.row(stage_id))


## **The room table's row -> the grid.** The one place a row's `map` and `chars` are read together, so the
##  game's own room build (`_apply_room()`) and the nets' stage-1 door above cannot drift apart into two
##  builders — the accident `terrain_baker.gd`'s header describes for a second bake under a new name.
static func build_room_into(g: CellGrid, room: Dictionary) -> void:
	build_map_into(g, StageDefs.map_rows(room), room["chars"])


## **The same builder, told which map.** Split out when the town arrived (`town_map.gd`) — it is a second
##  room made of the same tiles, and duplicating this loop would have made "runs are bundled into one command"
##  a rule that holds in one place and not the other.
##
## **`build_terrain_into` above is kept as the stage's own door**, not replaced: `net_tables` and
##  `net_water_rain` both call it by that name to stand up *the real stage 1*, and a net that had to pass the
##  map in would be a net that could be handed a different one by mistake.
##
## **The two `push_error`s stay here and are matched by `t.expect_error` on the net side** — CLAUDE.md's rule
##  that a bark and its forgiveness are one unit. Their text is not localized for that reason.
##
## **The height guard enforces a decision, not an accident** (recorded here because this is where a future
##  stage will run into it). **Map height is global at 48 tiles; width is what varies per stage.** It is
##  global because the town's own room, `fx_tuning.BG_UNDER_BOTTOM_Y`/`CELL_DEPTH_SPAN` and the placement
##  floor row (`stage_defs.FLOOR_CY`) all hang off `TerrainMap.MAP_H`, and 48 tiles is deep enough for a
##  water stage. ⇒ **A room whose map is a different height is refused here on purpose.** Widening it means
##  first answering what the background does below the ground line — `town_map.gd`'s `ROOM_Y0` comment
##  records the last time that question was skipped, and the town rendered as a black box with nothing barking.
## **The width is the map's own, not `MAP_W`.** It used to be compared against stage 1's re-export, which
##  would have refused a stage 2 of any other width. Now the first row sets it, every other row must agree,
##  and it must fit the grid — the same three questions `terrain_baker` already asks of a painted region.
##  For stage 1 and the town (both 300 wide) this is byte-identical to the old comparison.
static func build_map_into(g: CellGrid, map: Array[String], chars: Dictionary) -> void:
	if map.size() != MAP_H:
		push_error("MAP has %d rows - it must be %d" % [map.size(), MAP_H])
		return
	var map_w := map[0].length()
	# **A map wider than the grid was silently clipped before** — every tile past `CellGrid.W` fell out of
	#  `cmd_fill`'s own bounds with nothing said, which reads on screen as terrain full of holes. The baker
	#  refuses to write such a map; this refuses to build one, so the two ends agree.
	if map_w * Tuning.TILE_CELLS > CellGrid.W:
		push_error("MAP is %d tiles wide - the grid holds %d" % [map_w, CellGrid.W / Tuning.TILE_CELLS])
		return
	for ty in map.size():
		var row := map[ty]
		if row.length() != map_w:
			push_error("MAP row %d is %d wide - it must be %d" % [ty, row.length(), map_w])
			return
		var tx := 0
		while tx < map_w:
			var ch := row[tx]
			if not chars.has(ch):
				tx += 1
				continue
			# Runs of the same character are bundled into one command — calling per tile gives 2,304 commands.
			var run := tx
			while run + 1 < map_w and row[run + 1] == ch:
				run += 1
			var x0 := tx * Tuning.TILE_CELLS
			var y0 := ty * Tuning.TILE_CELLS
			var x1 := run * Tuning.TILE_CELLS + Tuning.TILE_CELLS - 1
			var y1 := ty * Tuning.TILE_CELLS + Tuning.TILE_CELLS - 1
			var mat := int(chars[ch])
			# **Water leaves through its own door.** `cmd_fill` refuses `Mat.WATER` at `_valid_mat` on
			#  purpose — it carries no amount, and a material fill zeroes `_aux`. Sent there, a `~` map
			#  baked **zero** water cells and barked once per run: a hole in the terrain drawn as a lake.
			#  **Driven, not read** — the survey that predicted "water with amount 0" was wrong about the
			#  mechanism, and the real failure is louder but the map lies either way.
			# **`WATER_MAX` is the same value the water rune pours** (`spell_sim` -> `cmd_water`), so the
			#  map and the rune cannot disagree, and a rune hit on an authored pool is a clean no-op
			#  through `maxi`. Anything at or below `WATER_WET` would be drawn as water and **could not be
			#  climbed** — which is the one mechanic stage 2 exists for (`stage2-water.md`).
			if mat == Mat.WATER:
				g.apply(CellGrid.cmd_fill_water(x0, y0, x1, y1, Tuning.WATER_MAX))
			else:
				g.apply(CellGrid.cmd_fill(x0, y0, x1, y1, mat))
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


## **F3.** `stage_input` already flipped its own flag before emitting; this only forces the derivation to
## run now rather than waiting for the next frame's `_update_hud()`.
func _toggle_debug_hud() -> void:
	_update_hud()


func _update_hud() -> void:
	_refresh_hud_counts()
	# **`Stats` hides while either window claims the screen — derived here, every frame, not written at the
	#  moment either window opens or closes.** The pick window's `취소` button calls `Progress.decline()`
	#  directly (`three_pick_window._gui_input`), bypassing `_toggle_pick()` entirely — a toggle-time write
	#  there cannot see that path, and `Stats` stranded hidden with nothing open (measured on screen). Reading
	#  the two windows' own state here instead makes that whole class of bug impossible rather than adding a
	#  second restore call for the one path that got caught.
	# **`_pick_window.is_showing()`, not `_world.progress().is_pick_open()` directly** — Stage E's
	#  confirmation afterglow can hold the pick window on screen a few frames after the pick itself already
	#  closed (`is_showing()`'s own comment), and `Progress` alone cannot see that. One expression still,
	#  widened at its one call site rather than duplicated at a second.
	# **`_settlement.is_showing()` too** (`run-end-settlement.md`, Stage D) — otherwise this debug readout
	#  prints straight over the settlement panel, and nothing barks.
	# **Developer mode first, and it is false at boot** — `stage_input._debug_on`. The window terms below are
	#  unchanged: even switched on, the readout still yields to anything that claims the screen.
	_hud.visible = _input.debug_on() and not _pick_window.is_showing() and not _circle_window.visible \
		and not _research_window.visible and not _settlement.is_showing()
	# **The single source of health is the character.** Count it separately in the shell and it becomes "it took damage but the number is unchanged".
	# **Downed no longer says anything here** — the settlement screen is what tells the player the run is over
	#  now (`run-end-settlement.md`, replacing this line and the old E-while-downed door in `_interact()`).
	#  Being alone there is nobody to pick you up, so the settlement screen's own button remains the only way
	#  out; **nothing is said in the town** either, since nothing there can hit you.
	# **The level line is gone from the screen** (「레벨은 안 보이게」) — money is drawn by `money_view` and
	#  XP by `hp_view`, both straight off `Progress`, so no statistic is formatted into a label here any more.
	# **The level-up prompt stays**, and it is not a statistic: it is the only thing that says a pick is
	#  waiting and which key opens it.
	var pr := _world.progress()
	_levelup_label.text = "⬆ 레벨업! P키로 뽑기 (%d개 대기)" % pr.pending_picks if pr.pending_picks > 0 else ""

	# **`Stats` is the plain debug readout, always.** Stage C borrowed this node to print the pick as text
	#  ("no window yet... it lets the rule be accepted before the picture is argued about" — that stage's own
	#  words). Stage D built the real picture (`HUD/ThreePickWindow`), so the borrow ends here — showing the
	#  same information in two places at once would just be confusing, not doubly correct.
	# **The town's own line goes first, so it is not lost under the debug counters.** The list is built and
	#  then joined — appending an empty string instead would make the readout jump a line the moment you
	#  walked into a bench.
	var lines: Array[String] = []
	if _in_town:
		lines.append("[마을] F로 설비를 쓴다" if _town_message.is_empty() else _town_message)
	_hud.text = "\n".join(lines + [
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
		# **The water cell count is not "the sum of amounts"** — the `WATER_HUD_TICKS` comment above.
		# **Room ①'s reward pour is gone** (`burn-out-of-the-bull-room.md` §4) — stage 1 pours nowhere now, so
		#  this line reads 0 for the whole run until room ③'s own pour exists. Kept for the `F` debug pour and
		#  for that future pour, not deleted with the reward water.
		"활성 청크 %d / %d · 물 %d칸" % [
			_grid.active_chunk_count(), CellGrid.CHUNK_COUNT, _water_cells,
		],
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
		# **이 두 줄은 F3를 켠 사람만 본다** — 개발자 모드 안내다(`stage_input._debug_on`).
		#  **없는 키를 적으면 그대로 거짓말이 된다**: 「F 물 · K 물비」가 그 키들이 사라진 뒤에도
		#  하루 남아 있었고, 배포된 화면을 열어보고서야 잡혔다. 키를 지우는 편집은 이 줄을 같이 고친다.
		"A/D 이동 · Space 점프 · 좌클릭 발사 · F 상호작용 · Tab 조립창 · P 세 장 뽑기 · R 리셋",
		"M/N/B/C/V 몬스터 · T 숲 · G 불  (마우스 자리에) · L 보상 · F3 이 창 · -/= 줌",
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
