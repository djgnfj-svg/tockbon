class_name Hud
extends Control
## Four numbers and a bar. Nothing else.
##
## **The last game drowned in debug overlays** — the user's own report is that the screen became unreadable
## because every session added one more readout. So this file has no debug mode and no toggle: what is here
## is what a player needs, and anything a developer wants goes to stdout instead.
##
## The bar is not decoration either. The GDD's core sensation is a dozen clones being swallowed in a row
## and the gauge lurching forward; if that does not read on screen, the harvest is invisible and the round
## trip cannot feel like anything.

const TEXT := Color(0.95, 0.92, 0.86)
const DIM_TEXT := Color(0.66, 0.62, 0.58)
const BAR_BG := Color(0.18, 0.16, 0.15, 0.85)
const BAR_FILL := Color(0.95, 0.85, 0.45)
const CARRY_COLOR := Color(0.98, 0.92, 0.35)
const HP_COLOR := Color(0.85, 0.35, 0.32)
const HP_LOST := Color(0.3, 0.22, 0.2)

var world: World = null
var _bar_shown := 0.0


func _ready() -> void:
	# Offsets, not just anchors — see the same note in `card_panel.gd`. Every readout here is placed from
	# `size`, so a zero-sized Control puts the clock and the hearts on top of the bank.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if world == null:
		return
	# The bar chases the real value instead of snapping to it, so a dozen absorptions in a row read as one
	# surge rather than as twelve invisible increments.
	#
	# The fraction comes from `World::level_progress()` and is not computed here. This file used to restate
	# the formula, which agreed with the sim only while the level cost was flat; the day the cost started
	# rising the bar would have divided by a base the sim no longer charged — parsing fine, every net green,
	# and the only readout of progress in the game quietly wrong.
	_bar_shown = lerpf(_bar_shown, world.level_progress(), 1.0 - pow(0.001, delta))
	queue_redraw()


func _draw() -> void:
	_paint(self)


func _paint(c: CanvasItem) -> void:
	if world == null:
		return
	var sw := world.swarm

	c.draw_rect(Rect2(Vector2(24.0, 22.0), Vector2(size.x - 48.0, 14.0)), BAR_BG)
	c.draw_rect(Rect2(Vector2(24.0, 22.0), Vector2((size.x - 48.0) * _bar_shown, 14.0)), BAR_FILL)

	_paint_text(c, Vector2(24.0, 84.0), "%d" % int(sw.banked), 44, TEXT)
	_paint_text(c, Vector2(24.0, 112.0),
			"무리 %d · 지고 있는 것 %d" % [sw.count - 1, int(sw.total_carried())], 20, CARRY_COLOR)

	for i in maxi(world.host_hp, Rules.HOST_HP):
		c.draw_circle(Vector2(34.0 + i * 26.0, size.y - 34.0), 9.0,
				HP_COLOR if i < world.host_hp else HP_LOST)

	# **The only instruction the player ever gets.** Every clause of the old line became false in one plan —
	# the dash moved off its own key into an active slot, rally stopped taking a cursor point, and three
	# keys appeared. It goes through `_paint_text` so a net reads what a player would read; grepping this
	# file for the string would measure its text and not what reached the screen.
	if world.elapsed < 12.0:
		_paint_text(c, Vector2(24.0, size.y - 68.0),
				"WASD 이동 · F 나누기 · V 모으기 · 1 집결 · 2 흩어지기 · 3 보내기 · Tab 몸", 20, DIM_TEXT)


## The hook. `draw_string` is a native call and Godot refuses to override it — a parse error — so every
## readout goes through this one method instead, and a net overrides it to capture what a player would
## actually read. Without it "the HUD drew something" is all that can be measured, and the last game's
## own lesson is that three of the four numbers this build reports would reach the screen through an
## entirely unmeasured file.
func _paint_text(c: CanvasItem, p: Vector2, text: String, font_size: int, col: Color) -> void:
	c.draw_string(get_theme_default_font(), p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
