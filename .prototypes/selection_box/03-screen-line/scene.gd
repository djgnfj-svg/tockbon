# **03-screen-line — the StarCraft CONTROL.** A screen-space rectangle drawn in code: a 1 px line in
# the ink colour from `common` (mint), no fill, no corners, on a `CanvasLayer` → `Control` that draws
# `drag.rect` with `draw_rect(rect, colour, false, 1.0)`.
#
# ⚠ **This deliberately breaks CLAUDE.md's rule** — 「anything the player looks at is MADE, never
# typed」. It is in the set only as the reference the four drawn candidates are judged against, and it
# cannot ship. `NOTES.md` says so.
#
# **The box does not move when the board turns.** It lives on the glass, so the yaw-90 shot shows the
# same rectangle over different ground — that is the whole difference between the screen family and
# the ground family, and this candidate is the purest instance of it.
#
# **Pixel snapping**: a 1 px stroke centred on an integer edge covers two half-pixels and comes out as
# a 2 px smear at half alpha. The rect is floored and pushed by (0.5, 0.5) so the stroke's centre sits
# on a pixel centre and the line is one crisp pixel.
extends RefCounted

const NAME := "03-screen-line"

const COMMON_PATH := "res://.prototypes/selection_box/common.gd"

var _layer: CanvasLayer = null
var _box: Control = null


## The `Control` that draws the rectangle. An inner class so the whole candidate is one file.
class LineBox:
	extends Control
	var rect := Rect2()
	var colour := Color.WHITE

	func _draw() -> void:
		var snapped := Rect2(rect.position.floor() + Vector2(0.5, 0.5), rect.size.floor())
		draw_rect(snapped, colour, false, 1.0)


func mount(game: Node, _fv: Node, drag: Dictionary) -> void:
	var common: GDScript = load(COMMON_PATH)
	_layer = CanvasLayer.new()
	_layer.layer = 1
	_box = LineBox.new()
	_box.rect = drag["rect"]
	_box.colour = common.ink_colour()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_box)
	game.add_child(_layer)
	_box.queue_redraw()


func unmount() -> void:
	if _layer != null:
		_layer.queue_free()
		_layer = null
		_box = null


func lines() -> PackedStringArray:
	return PackedStringArray([
		"buys — any size, any zoom, one line of code, exactly StarCraft: a 1 px mint line, no fill, no corners, crisp, fixed to the glass",
		"costs — nothing about it was chosen in a tool; it looks like every RTS since 1998 and says nothing about this island",
		"cannot — cannot ship under CLAUDE.md's rule as typed chrome; cannot carry any drawn character",
	])
