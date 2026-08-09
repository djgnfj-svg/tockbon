extends Sprite2D
## Puts the grid on screen. **It only reads — it never writes to the grid.**
##
## **There is no cell -> pixel conversion pass at all.** The `_mat` byte array is L8 texture data as-is.
##  2 GDScript calls per tick (`set_data` + `update`), **4,128,768 bytes uploaded x 2 textures**.
##  **= 7.88MB per tick, 157.5MB/s at 20Hz** (measured. Until recently this line said 147,456, and when the map
##   grew it became **28x larger while the comment did not follow**).
##  Do not turn it into an `Image.set_pixel` loop — that is 4,128,768 VM calls per tick. For reference,
##   **merely reading** the same grid in GDScript takes 62,676us (`cell_grid.CELL_COUNT` comment), so a write
##   loop is more than that.
## **The upload cost has not been measured yet.** Headless uses the dummy renderer with no GPU, so `update()`
##  reads as 0us — that is not "cheap" but **"could not measure"**. It is an item that went 4x in the 32px
##  switch, and the answer only comes out as FPS.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Fx := preload("res://src/view/fx_tuning.gd")
const SHADER_PATH := "res://src/view/cell_grid.gdshader"

var _grid: CellGrid = null
var _mat_img: Image = null
var _mat_tex: ImageTexture = null
## **The second texture.** What changes state while the material stays the same (= burning) reaches the screen
##  only through here.
##  There was also a path of making a separate "burning wood" material in `_mat`, but then the original material
##   has to be restored when the fire goes out, and if that restore slips, **the material stays changed with no error.**
var _flag_img: Image = null
var _flag_tex: ImageTexture = null


## **This is the single source for `centered`, `scale` and `texture_filter`** — do not write the same values
##  again in the `.tscn`. At runtime this side wins, so nobody notices when they diverge. And `.tscn` comments
##  are wiped when the editor saves, so the reason cannot be recorded over there either.
func setup(grid: CellGrid) -> void:
	_grid = grid

	_mat_img = Image.create_from_data(
		CellGrid.W, CellGrid.H, false, Image.FORMAT_L8, grid.get_mat())
	_mat_tex = ImageTexture.create_from_image(_mat_img)
	_flag_img = Image.create_from_data(
		CellGrid.W, CellGrid.H, false, Image.FORMAT_L8, grid.get_flag())
	_flag_tex = ImageTexture.create_from_image(_flag_img)

	texture = _mat_tex
	centered = false
	position = Vector2.ZERO
	scale = Vector2(Tuning.CELL_PX, Tuning.CELL_PX)
	# The project default is Nearest but it is stated **explicitly** — if it smears, a 4px cell dies wholesale,
	# and that only shows up in a screenshot and raises no error.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var sm := ShaderMaterial.new()
	sm.shader = load(SHADER_PATH)
	# The palette is **generated** from the material table and injected — pin colors in the shader and the
	# single source breaks.
	sm.set_shader_parameter("palette", bake_palette())
	# Bit positions have `cell_materials.gd` as their single source — pin a `2` in the shader and
	#  the day the bit moves, **fire quietly draws the wrong state.**
	sm.set_shader_parameter("flag_tex", _flag_tex)
	sm.set_shader_parameter("flag_burning", Mat.FLAG_BURNING)
	sm.set_shader_parameter("fire_lo", Fx.FIRE_LO)
	sm.set_shader_parameter("fire_hi", Fx.FIRE_HI)
	sm.set_shader_parameter("fire_hz", Fx.FIRE_FLICKER_HZ)
	# Water runs on the same two axes — bit position from `cell_materials`, color from `fx_tuning`.
	#  **The deep water color is not given here** — that is a material and already goes in via `palette`.
	#   Give it again here and the water color lives in two places, and the day comes when only one is fixed.
	sm.set_shader_parameter("flag_shallow", Mat.FLAG_SHALLOW)
	sm.set_shader_parameter("water_shallow", Fx.WATER_SHALLOW)
	# Depth dim (`docs/design/underground-depth.md`) — both derived from the map's real floor, not
	#  `CellGrid.H` (`Fx.CELL_DEPTH_SPAN`'s own comment).
	sm.set_shader_parameter("depth_span", Fx.CELL_DEPTH_SPAN)
	sm.set_shader_parameter("deep_dim", Fx.CELL_DEEP_DIM)

	# **Empty cells are pulled out as transparent — the only path by which the background reaches the screen.**
	#  The grid sprite covers the whole world, so without this **whatever is put behind is 100% hidden.**
	#  **Derive it from `Mat.EMPTY`. Do not pin 0** — it goes silently stale the day material ids change.
	sm.set_shader_parameter("empty_id", Mat.EMPTY)
	material = sm


## The shader's `palette[16]` uniform. **Generated** from `Mat.DEFS`'s `rgb` — do not pin it by hand.
##
## **Why this function lives here and not in `src/sim/`**: `Color` is floating point, so it violates the
##  sim folder's "integers only" contract. The material table is still the single source (the `rgb` column),
##  and **only the integer -> Color conversion** moved to the screen side.
##  There was also a path of amnestying `Color` via an exception list, but then **the folder contract and what
##   the net measures stay diverged** — an exception always goes stale.
static func bake_palette() -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(Mat.SLOT_COUNT)
	for i: int in Mat.SLOT_COUNT:
		out[i] = _rgb_to_color(Mat.rgb_of(i))
	return out


## 0xRRGGBB -> Color. `Color8` takes integer channels directly (so the divide-by-255 is not written twice).
static func _rgb_to_color(rgb: int) -> Color:
	return Color8((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF)


## Called once, after the tick. The grid does not change between ticks, so there is no reason to call it more.
## **Both textures are uploaded together.** Upload only one and you get "the fire caught but is invisible",
##  or the reverse, and neither raises an error.
func refresh() -> void:
	if _grid == null:
		return
	_mat_img.set_data(CellGrid.W, CellGrid.H, false, Image.FORMAT_L8, _grid.get_mat())
	_mat_tex.update(_mat_img)
	_flag_img.set_data(CellGrid.W, CellGrid.H, false, Image.FORMAT_L8, _grid.get_flag())
	_flag_tex.update(_flag_img)
