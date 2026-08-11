## Captures the screenshots `plan.md` prints into the judged PDF.
##
## **Do not run this directly. Run `python docs/archive/nan2026/tools/shots.py`** — it drives this
##  scene and then composes the paired figures. The parts written here are inputs to that.
##
## ⚠ **`OUT` now points into a sealed folder.** The preliminary round is over and its images
##  are the record of what was submitted; running this overwrites them with today's game,
##  which is not the game that was judged. **Re-point `OUT` before running it for the final
##  round** — the capture logic below is round-agnostic and is why this file is kept.
##
## A real window opens: `--headless` draws no frame and captures nothing.
##
## **It stands up the real `stage.tscn` and drives it through the shell's own doors** —
##  `_set_loadout`, `_fire_at`, `_toggle_assembly`. Nothing here paints a picture of its own,
##  so a shot that looks wrong is the game looking wrong, which is the only reason to take it.
##
## **The arena is built, not found.** The two order shots have to differ in the loadout and
##  in nothing else, and stage 1's own ground carries a cliff, a pit and eighteen pigs that
##  wander between one capture and the next. So the grid is wiped and a flat slab is laid:
##  same floor, same stance, same three shots, one variable.
extends Node

const StagePack := preload("res://src/stage/stage.tscn")
const StageScript := preload("res://src/stage/stage.gd")
const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const StageDefs := preload("res://src/stage/stage_defs.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const SpellCircle := preload("res://src/actor/spell_circle.gd")
const Palette := preload("res://src/view/palette_layout.gd")

const OUT := "res://docs/archive/nan2026/img/"

## The arena, in cells. Wide enough that the camera never reaches an edge of it.
const ARENA_X0 := 0
const ARENA_X1 := 700
## **Stone, and no wood.** A wood band was laid here first so fire would have something to
##  catch, and the fire rune lit the whole band end to end in under a second — the floor
##  became one burning line and the crater, which is the entire subject, was invisible under
##  it. Stone does not burn, so what the picture shows is only what was dug.
const FLOOR_CY := 200
const FLOOR_BOTTOM_CY := 300

## The world shot's two halves, in cells: a wood floor to the left of the character, and a
## hole to the right that water pours into.
const WOOD_X0 := 120
const WOOD_X1 := 190
const HOLE_CX := 232

## Frames to wait after firing before the shutter opens. **Different per order, and that is
## the point** — `확산 → 폭발` has to fly, split into eight, and let those eight land, so its
## moment is later than `폭발 → 확산`, whose big detonation is at first contact.
## Tuned by eye against a sweep (`SWEEP` below), 30/45/60/75/90; there is no way to derive it.
##
## **Waiting for the eight to detonate does not give a picture** — measured. Each fragment flies its own
##  arc and lands at its own time, so by frame 90 the two that have gone off are at opposite edges of the
##  frame with the rest still in the air, and one of them has hit the character (90/100 on the gauge).
##  The moment that shows the order is the **fan itself**, at 45.
const IMPACT_FRAMES := {
	"spread-blast": 45,
	"blast-spread": 30,
}

## Temporary sweep: non-empty means every listed frame is saved instead of the tuned one. Empty in commits.
const SWEEP: Array[int] = []

const STAND_PX := Vector2i(200 * Tuning.CELL_PX, FLOOR_CY * Tuning.CELL_PX - 32)
## Aimed into the floor ahead of the character. The crater is the picture.
const AIM_PX := Vector2(STAND_PX.x + 150, FLOOR_CY * Tuning.CELL_PX + 16)

var _stage: Node


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_stage = StagePack.instantiate()
	add_child(_stage)
	await _wait(40)

	# The one shot taken on the real map, for the overview: the assembly window as a player
	# meets it. Everything after it runs in the arena.
	await _shoot_real_map_window()

	await _shoot_pair(4, "spread-blast")
	await _shoot_pair(5, "blast-spread")
	await _shoot_world()

	print("[shot] done")
	get_tree().quit()


func _shoot_real_map_window() -> void:
	_stage.reset_stage()
	_stage._leave_town()
	await _wait(30)
	_seat_fire()
	_stage._circle.apply_preset(
		SpellCircle.DEFAULT_CIRCLE, Tuning.ELEM_FIRE,
		Glyph.pack([Glyph.SPREAD_C, Glyph.BLAST_C]))
	await _wait(4)
	_stage._toggle_assembly()
	# **Opened on 문양, not on the 진 tab it resets to.** The overview figure's caption calls the right pane
	#  "the palette you pick 진·룬·문양 from", and the 진 tab holds a single ring on an otherwise empty page —
	#  the picture said "there is nothing to choose". This is the same state a click on that tab reaches
	#  (`_click_palette` writes `_open_tab`); nothing here is drawn that play cannot reach.
	_stage._circle_window._open_tab = Palette.KINDS.find(Palette.KIND_GLYPH)
	await _wait(30)
	await _save("circle-window")
	_stage._toggle_assembly()
	await _wait(10)


## One order, two pictures: the circle that was assembled, and what that circle did.
## **The same loadout drives both** — the window is opened on the arena, closed, and then
##  fired without touching the circle in between.
func _shoot_pair(loadout: int, name: String) -> void:
	await _build_arena()
	_stage._set_loadout(loadout)
	# **Seated again after the preset, not only in `_build_arena`.** The arena is entered through the town,
	#  and the town's own settling steps land during the 25 frames that follow the first seating — the two
	#  order figures came back with the **none** rune (a nail, not a flame) while `rune_at(0)` read fire in a
	#  headless probe of the same calls. Seating last is what the picture actually shows.
	_seat_fire()
	await _wait(4)

	_stage._toggle_assembly()
	await _wait(30)
	await _save("part-circle-" + name)
	_stage._toggle_assembly()
	await _wait(10)

	# **The impact, not the aftermath.** Three shots into one hole left two brown smudges that
	#  a caption had to explain — and the character fell into its own crater, so the two shots
	#  were not even framed alike. What actually separates the two orders is the *instant*:
	#  eight detonations spread across the floor, or one big one. So one shot, and the frame is
	#  taken while it is going off.
	_stage._fire_at(AIM_PX)
	if SWEEP.is_empty():
		await _wait(IMPACT_FRAMES[name])
		await _save("part-fx-" + name)
		return
	# Temporary: one firing, many shutters, so `IMPACT_FRAMES` can be picked by eye instead of guessed.
	var at := 0
	for f: int in SWEEP:
		await _wait(f - at)
		at = f
		await _save("sweep-%s-%d" % [name, f])


## The town's row carries no monster table, so entering it is how the arena gets a world with
## nothing walking around in it. The grid is then wiped and rebuilt from scratch.
## The three natural laws in one frame: wood burning, a dug hole, water pouring into it.
##
## **Every one of them is the real sim.** The wood is laid and the water is poured through the
##  same doors the shell's debug keys use; the hole is carved by actually firing at the floor.
func _shoot_world() -> void:
	await _build_arena()
	# A wood floor on the left half — fire needs fuel, and stone has none.
	_stage._grid.apply(CellGrid.cmd_fill(
		WOOD_X0, FLOOR_CY - 10, WOOD_X1, FLOOR_CY - 1, Mat.WOOD))
	await _wait(6)
	# Dig the hole on the right by firing into it, not by filling EMPTY — a hole the sim
	# carved is the claim the picture makes.
	_stage._set_loadout(3)
	await _wait(4)
	for _i in 4:
		_stage._fire_at(Vector2(HOLE_CX * Tuning.CELL_PX, FLOOR_CY * Tuning.CELL_PX + 20))
		await _wait(22)
	await _wait(40)
	for x in range(HOLE_CX - 6, HOLE_CX + 7):
		_stage._grid.set_water(x, FLOOR_CY - 14, 255)
	_stage._grid.ignite(WOOD_X0 + 34, FLOOR_CY - 2)
	_stage._grid.ignite(WOOD_X0 + 36, FLOOR_CY - 8)
	await _wait(90)
	await _save("world")


func _build_arena() -> void:
	_stage.enter_town()
	await _wait(20)
	_stage._grid.apply(CellGrid.cmd_reset())
	_stage._grid.apply(CellGrid.cmd_fill(
		ARENA_X0, FLOOR_CY, ARENA_X1, FLOOR_BOTTOM_CY, Mat.STONE))
	# The town's benches and its departure gate are still standing where the room left them,
	# and they have nothing to do with what this figure claims.
	_stage._town_view.visible = false
	# **The room is the town's; the sky should not be.** The figure sits beside the overview's
	#  farm screenshot, and the town's dusk ruins behind it read as a different game.
	# **One layer, one argument.** The near layer was deleted along with its constant, and this call kept
	#  passing two — the error was raised inside `_wait`'s await, so the run carried on and both order
	#  figures shipped with the **town's** dusk sky behind them. `--headless` would not have shown it either;
	#  the engine's exit code did, at 255, after the pictures were already on disk.
	_stage._sky.set_backdrop(StageDefs.row(StageDefs.STAGE_1)["bg_far"])
	_seat_fire()
	_stage._char.place(STAND_PX.x, STAND_PX.y)
	# **The onboarding hint is derived from the step every frame, so hiding the node does
	#  nothing** — it has to be stepped to the end. Left in, its panel sits across the middle
	#  of every figure.
	_stage._onboard_step = StageScript.ONBOARD_DONE
	await _wait(25)


## **Fire is seated for every shot.** The bull grants it in a real run; seating it here is the
##  only way both order pictures are taken with the rune their caption implies, and a none
##  rune digs the same crater in grey twice.
func _seat_fire() -> void:
	_stage._world.progress().grant_rune(Tuning.ELEM_FIRE)
	_stage._circle.set_rune(0, Tuning.ELEM_FIRE)


func _wait(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame


## **`frame_post_draw` first.** Read the texture without it and the image is the frame before
##  the one just set up — off by one, and silently plausible.
func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path := OUT + name + ".png"
	var err := img.save_png(path)
	if err != OK:
		push_error("[shot] could not write %s (%d)" % [path, err])
	else:
		print("[shot] %s  %dx%d" % [path, img.get_width(), img.get_height()])
