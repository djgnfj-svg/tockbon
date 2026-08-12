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
const OVER_DIM := Color(0.04, 0.03, 0.03, 0.86)

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
	_bar_shown = lerpf(_bar_shown, _level_t(), 1.0 - pow(0.001, delta))
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

	var left := maxf(0.0, Rules.RUN_LENGTH - world.elapsed)
	_paint_text(c, Vector2(size.x - 128.0, 84.0), "%d:%02d" % [int(left) / 60, int(left) % 60], 32, TEXT)

	for i in maxi(world.host_hp, Rules.HOST_HP):
		c.draw_circle(Vector2(34.0 + i * 26.0, size.y - 34.0), 9.0,
				HP_COLOR if i < world.host_hp else HP_LOST)

	if world.elapsed < 12.0:
		_paint_text(c, Vector2(24.0, size.y - 68.0),
				"WASD 이동 · Space 대시 · 1 모이기(커서) · 2 흩어지기", 20, DIM_TEXT)

	if world.over:
		_paint_result(c)


## The hook. `draw_string` is a native call and Godot refuses to override it — a parse error — so every
## readout goes through this one method instead, and a net overrides it to capture what a player would
## actually read. Without it "the HUD drew something" is all that can be measured, and the last game's
## own lesson is that three of the four numbers this build reports would reach the screen through an
## entirely unmeasured file.
func _paint_text(c: CanvasItem, p: Vector2, text: String, font_size: int, col: Color) -> void:
	c.draw_string(get_theme_default_font(), p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


## The experiment's output. Two runs, these four numbers, and the comparison is the verdict — greedy must
## bank at least 1.4× cautious or the round trip is not a decision.
func _paint_result(c: CanvasItem) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, size), OVER_DIM)
	var x := size.x * 0.5 - 200.0
	var y := size.y * 0.5 - 120.0
	_paint_text(c, Vector2(x, y), "끝" if world.host_hp > 0 else "먹혔다", 40, TEXT)
	var rows := [
		"모은 것 %d" % int(world.swarm.banked),
		"잃은 분신 %d" % world.clones_lost,
		"같이 날아간 것 %d" % int(world.cargo_lost),
		"가장 컸을 때 %d" % world.peak_swarm,
	]
	for i in rows.size():
		_paint_text(c, Vector2(x, y + 62.0 + i * 40.0), str(rows[i]), 28, TEXT)
	_paint_text(c, Vector2(x, y + 62.0 + rows.size() * 40.0 + 24.0), "R 다시", 20, DIM_TEXT)


func _level_t() -> float:
	var into: float = world.swarm.banked - float(world.level) * Rules.SPLIT_PER_BANKED
	return clampf(into / Rules.SPLIT_PER_BANKED, 0.0, 1.0)
