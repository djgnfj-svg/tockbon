extends Control
## The health readout — **a big red number with a thin gauge under it.** Screen only; it reads the character
## and never writes it.
##
## **It replaced a `Label` reading `체력 100 / 100`, parked in the bottom-right corner.** Two things were
##  wrong with that and only one of them was the look:
##  **(1)** the corner it sat in is where a 960x540 viewport puts nothing else, so on a browser window whose
##   aspect does not match, it was the first thing to land outside the picture — seen on screen
##  **(2)** `체력 100 / 100` is a sentence, not a gauge. The user asked for **숫자만 · 빨간색**, and a number
##   you have to read left-to-right is exactly what a health bar exists to replace
##
## **The number is the subject and the bar is the adverb** (the user's own division: "체력은 숫자만 있어도
##  될듯"). So the digits are large and carry the colour, and the gauge is a thin strip underneath that says
##  *how much of the way down* without needing to be read.
##
## **Colour is the warning, not a blink.** A flashing bar competes with the invulnerability blink the
##  character sprite already does (`character_view._draw`'s `invuln_left & 1`), and two blinking things at
##  once read as a rendering fault. The number simply goes from `HP_FULL` to `HP_LOW` as it drains.

const Fx := preload("res://src/view/fx_tuning.gd")
const Character := preload("res://src/actor/character.gd")

## **A reference, not a copy** — the same discipline `character_view._ch` holds. Copy the number and the day
##  one push is forgotten it becomes "I took damage and the readout did not move", with nothing barking.
var _ch: Character = null


func setup(ch: Character) -> void:
	_ch = ch
	queue_redraw()


func _ready() -> void:
	position = Fx.HP_RECT.position
	size = Fx.HP_RECT.size
	# **`mouse_filter` is set in the scene (`2` = IGNORE), never here.** `net_render` forbids writing it at
	#  runtime for the reason `stage.gd`'s own header gives: a value written in code makes the scene's value
	#  a false knob. It must be IGNORE — this sits in the corner the player fires toward, and a Control that
	#  swallows clicks there reads as the mouse being broken.


## Health changes on a tick, not on a frame, but there is no notification for it — the same situation
## `character_view` is in for position. Redrawing every frame is what keeps the two in step.
func _process(_dt: float) -> void:
	queue_redraw()


## **The filled fraction, clamped.** Negative hp is already blocked in `Character.take_hit`, but a gauge that
## can draw past its own box is how a bar ends up painting over the level line beside it.
static func fill_frac(hp: int) -> float:
	if Character.MAX_HP <= 0:
		return 0.0
	return clampf(float(hp) / float(Character.MAX_HP), 0.0, 1.0)


## The number's colour — full red at full health, warning red at empty. **Interpolated, not stepped**, so
## there is no threshold to tune and no moment where the colour "jumps" and reads as a state change.
static func number_color(hp: int) -> Color:
	return Fx.HP_LOW.lerp(Fx.HP_FULL, fill_frac(hp))


func _draw() -> void:
	if _ch == null:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var frac := fill_frac(_ch.hp)
	_paint_number(font, _ch.hp, number_color(_ch.hp))
	_paint_gauge(Fx.hp_gauge_rect(size), frac)


## **Cut out of `_draw()` so a net can override it and read what it was handed.** CLAUDE.md: counting
## `_draw()` calls measures the engine, and Godot refuses to let a script override `draw_string` itself.
func _paint_number(font: Font, hp: int, color: Color) -> void:
	draw_string(font, Vector2(0.0, Fx.HP_NUMBER_SIZE), str(hp),
		HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.HP_NUMBER_SIZE, color)


## The gauge. **Ground first, then the fill** — drawn the other way round the fill is covered and the bar
## is permanently empty, with every value still correct.
## **The fill keeps the ground's height and only loses width**, so an almost-dead bar is a thin line and not
## a short stub floating in the middle.
func _paint_gauge(r: Rect2, frac: float) -> void:
	draw_rect(r, Fx.HP_GAUGE_BG, true)
	if frac > 0.0:
		draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), Fx.HP_FULL, true)
	draw_rect(r, Fx.HP_GAUGE_EDGE, false, Fx.HP_GAUGE_EDGE_PX)
