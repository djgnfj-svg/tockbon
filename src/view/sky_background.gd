extends Node2D
## Background — the night sky behind the grid. The concept is governed by `docs/design/background.md`.
##
## **This node alone shows not one pixel.** The grid sprite (`CellRenderer`) covers the whole world opaquely,
##  so it only becomes visible once `cell_grid.gdshader`'s `empty_id` **pulls empty cells out as transparent.**
##  The two are a pair — revert the shader side and this dies quietly (no error).
##
## **It must sit before (above) `CellRenderer` in `stage.tscn`.** Scene order is drawing order.
##
## **Why code and not art**: the world is 16,384 x 4,032px, so one image cannot cover it
##  (`background.md`, "size — a single sheet cannot draw it"). Even before an art candidate is settled,
##  **the path by which the background reaches the screen has to stand first** — otherwise no matter how well
##  the art comes out it will not show, and this repo already went through that accident once with water
##  (CLAUDE.md, "is there a path for what you want to see to reach the screen").
##
## **Right now it is a flat gradient plus stars.** Once art is settled, this file becomes the place that lays it down.

const Fx := preload("res://src/view/fx_tuning.gd")

## Instead of following the camera, it is **a fixed layer covering the whole screen.**
##  Adding parallax means splitting into layers, and that comes after the art is settled (`background.md`).
var _cam: Camera2D = null
var _view: Vector2 = Vector2.ZERO


func setup(cam: Camera2D) -> void:
	_cam = cam
	_view = Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height")))
	z_index = Fx.BG_Z_INDEX


func _process(_dt: float) -> void:
	# Redraw when the camera moves. The drawing coordinates are tied to the camera.
	queue_redraw()


func _draw() -> void:
	if _cam == null:
		return

	# Screen-sized, from the camera center. **It does not cover the whole world** —
	#  drawing 16,384 x 4,032px every frame wastes the 99% that is off screen.
	var half := _view * 0.5
	var origin := _cam.global_position - half
	var rect := Rect2(origin, _view)

	# A night sky, dark at the top and slightly brighter toward the bottom. A vertical gradient.
	# **Why the night palette is enforced**: the stage's empty cells are nearly black, so a bright background
	# kills every character and monster silhouette (`background.md`, "the night palette is enforced").
	var steps := Fx.BG_GRADIENT_STEPS
	var band := _view.y / float(steps)
	for i in steps:
		var t := float(i) / float(steps - 1)
		var c := Fx.BG_TOP.lerp(Fx.BG_BOTTOM, t)
		draw_rect(Rect2(origin.x, origin.y + band * float(i), _view.x, band + 1.0), c)

	_draw_stars(rect)


## Stars. **Drawn from a grid pinned to world coordinates** — draw from screen coordinates and the stars follow
## along when the camera moves, which reads as "dots stuck to the window".
## It uses a `sin` hash. **This is `src/view/`, so the float contract does not apply** (only `src/sim/` is integers).
func _draw_stars(rect: Rect2) -> void:
	var cell := Fx.BG_STAR_CELL_PX
	var x0 := floorf(rect.position.x / cell) * cell
	var y0 := floorf(rect.position.y / cell) * cell
	var nx := int(rect.size.x / cell) + 2
	var ny := int(rect.size.y / cell) + 2

	for iy in ny:
		for ix in nx:
			var gx := x0 + float(ix) * cell
			var gy := y0 + float(iy) * cell
			# Three fixed random draws per grid cell — is there one, where, and how bright
			var h := _hash2(gx, gy)
			if h > Fx.BG_STAR_DENSITY:
				continue
			var ox := _hash2(gx + 17.0, gy) * cell
			var oy := _hash2(gx, gy + 31.0) * cell
			var a := Fx.BG_STAR_ALPHA_MIN + _hash2(gx + 7.0, gy + 7.0) * (
				Fx.BG_STAR_ALPHA_MAX - Fx.BG_STAR_ALPHA_MIN)
			var c := Fx.BG_STAR_COLOR
			c.a = a
			draw_rect(Rect2(gx + ox, gy + oy, Fx.BG_STAR_PX, Fx.BG_STAR_PX), c)


func _hash2(x: float, y: float) -> float:
	return fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)
