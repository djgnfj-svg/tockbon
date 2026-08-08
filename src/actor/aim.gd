extends RefCounted
## **The integer boundary. This function is the only arrow pointing into the integer side.**
##
## ```
## fire_cmd(tip_px, mouse_px, element, glyphs) -> Dictionary
##    ^ two float px come in          v this return is the boundary line
## { spell_kind, ox, oy, adx, ady, element, glyphs }   <- all integers
## ```
##
## **px -> cell quantization happens only inside this function.** That is why **one function emits both**
##  the origin (`ox,oy`) and the aim (`adx,ady`) — split them and px->cell conversion lives in two places,
##  and once those two diverge it only ever looks like "aim is subtly off".
##
## **The point is that the boundary function lives on the float side (`src/actor/`).** It takes floats so it
##  cannot go into `src/sim/`, and it emits integers so `src/sim/` can take it.
##  **Do not normalize the direction here** — the moment `atan2` or `normalized()` comes in, the contract breaks.
##   Normalization is done by `SpellSim._launch` with an **integer square root**.

const Tuning := preload("res://src/sim/sim_tuning.gd")
const SpellSim := preload("res://src/sim/spell_sim.gd")
const CellGrid := preload("res://src/sim/cell_grid.gd")


## **Clamps the origin into the grid.** If a boundary function **can emit an unusable command,
##  it is not a boundary.**
##
## **This is not an unreachable state** — the design's "extreme values" settled that "shoot at your own feet
##  and the terrain disappears and the character falls · we do not block it", so **the character really does
##  leave the grid.** Without the clamp, a left click there dies in `spell_sim` with a `push_error`, and on
##  screen it only looks like **"I left-clicked and nothing happened"**. On top of that the wrapper counts
##  stderr as failure, so every net and probe passing through that state goes red wholesale.
## The range check in `spell_sim.fire()` **stays anyway** — that one is the door the network opens, and
##  this function only sees local input. The two checks guard different things.
static func fire_cmd(tip_px: Vector2, mouse_px: Vector2, element: int, glyphs: int) -> Dictionary:
	var ox := clampi(_to_cell(tip_px.x), 0, CellGrid.W - 1)
	var oy := clampi(_to_cell(tip_px.y), 0, CellGrid.H - 1)
	# The aim is the difference **relative to the clamped origin**. Move only the origin and subtract the
	#  raw mouse cell and the direction silently skews when firing from outside the grid.
	return SpellSim.cmd_fire(
		ox, oy, _to_cell(mouse_px.x) - ox, _to_cell(mouse_px.y) - oy, element, glyphs)


## **It is `floori`.** `int()` truncates toward 0, so the cell coordinate jumps one cell outside the grid's
##  left and top edges — it only skews when aiming at the far left of the screen, so **the eye almost never catches it.**
static func _to_cell(px: float) -> int:
	return floori(px / Tuning.CELL_PX)
