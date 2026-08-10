## Captures the screenshots `docs/submission/plan.md` prints into the judged PDF.
##
## **Do not run this directly. Run `python tools/submission/shots.py`** — it drives this
##  scene and then composes the paired figures. The parts written here are inputs to that.
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
const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const StageDefs := preload("res://src/stage/stage_defs.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const SpellCircle := preload("res://src/actor/spell_circle.gd")

const OUT := "res://docs/submission/img/"

## The arena, in cells. Wide enough that the camera never reaches an edge of it.
const ARENA_X0 := 0
const ARENA_X1 := 700
## **Stone, and no wood.** A wood band was laid here first so fire would have something to
##  catch, and the fire rune lit the whole band end to end in under a second — the floor
##  became one burning line and the crater, which is the entire subject, was invisible under
##  it. Stone does not burn, so what the picture shows is only what was dug.
const FLOOR_CY := 200
const FLOOR_BOTTOM_CY := 300

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
	await _wait(4)

	_stage._toggle_assembly()
	await _wait(30)
	await _save("part-circle-" + name)
	_stage._toggle_assembly()
	await _wait(10)

	# **Three shots into one spot, not one.** A single bolt leaves a scallop a few cells
	#  wide, and at the printed size of a PDF figure the two orders read as the same smudge —
	#  a caption claiming a difference the picture does not carry.
	for _i in 3:
		_stage._fire_at(AIM_PX)
		await _wait(26)
	await _wait(110)
	await _save("part-fx-" + name)


## The town's row carries no monster table, so entering it is how the arena gets a world with
## nothing walking around in it. The grid is then wiped and rebuilt from scratch.
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
	var stage1: Dictionary = StageDefs.row(StageDefs.STAGE_1)
	_stage._sky.set_backdrop(stage1["bg_far"], stage1["bg_near"])
	_seat_fire()
	_stage._char.place(STAND_PX.x, STAND_PX.y)
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
