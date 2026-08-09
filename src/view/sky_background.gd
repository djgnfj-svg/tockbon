extends Node2D
## Background — the picture behind the grid. The concept is governed by `docs/design/background.md`.
##
## **This node alone shows not one pixel.** The grid sprite (`CellRenderer`) covers the whole world opaquely,
##  so it only becomes visible once `cell_grid.gdshader`'s `empty_id` **pulls empty cells out as transparent.**
##  The two are a pair — revert the shader side and this dies quietly (no error).
##
## **It must sit before (above) `CellRenderer` in `stage.tscn`.** Scene order is drawing order.
##
## **Two layers, both tiled horizontally**: far scenery and a near strip at the player's feet.
##  One picture cannot cover the world (16,384 x 4,032px against a 960x540 screen), so
##  **the far layer's own top row color fills the sky above it** — sampled, not hard-coded, so swapping
##  the art needs no constant edited. The near layer fills nothing: it is a strip standing on the ground
##  line with transparency everywhere else.
##
## **Below the far picture there is no more sky.** The picture is clamped so it stops following the
##  camera at the ground line (`_far_y()`), and everything under it is `_draw_depth_fill()` — banded
##  rects darkening toward bedrock. `docs/design/underground-depth.md`
##  measured why: at ratio 0.08 the far picture never left the screen, so a dug hole at the map's floor
##  still showed sky, and the old flat fill under it was sampled from the picture's own bottom row —
##  `#7EB356`, a bright grass green standing in for rock.
##
## **Each picture is a mirrored pair**: the right half is the left flipped, so its left and right edges are the
##  same column and the tiling shows no seam. Generative models will not match seams — mirroring is the fix.
##
## **It was a night gradient plus stars until the art landed.** The user rejected the night sky
##  (`background.md`, "the night palette is reversed"), so that code is gone rather than kept switched off.

const Fx := preload("res://src/view/fx_tuning.gd")

var _cam: Camera2D = null
var _view: Vector2 = Vector2.ZERO
var _far: Texture2D = null
var _near: Texture2D = null
## The far picture's own top row color. **It fills the sky above the picture** — the world is seven
##  screens tall and the picture is one, so without this the area above it is transparent and the black
##  `EMPTY` shows through as a hard band. There is no `_bottom_fill` counterpart any more — below the
##  picture is underground now, and `_draw_depth_fill()` owns that (`Fx.BG_UNDER_BANDS`), not a sampled color.
var _top_fill := Color.BLACK


func setup(cam: Camera2D) -> void:
	_cam = cam
	_view = Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height")))
	z_index = Fx.BG_Z_INDEX
	set_backdrop(Fx.BG_FAR_TEXTURE, Fx.BG_NEAR_TEXTURE)


## Swaps both pictures. **The town is a second backdrop on this same node** (`town.md`) — not a second scene.
func set_backdrop(far_path: String, near_path: String) -> void:
	_far = load(far_path) as Texture2D
	_near = load(near_path) as Texture2D
	if _far == null:
		push_error("배경 그림을 못 읽었다: %s" % far_path)
		return
	# **The near layer is allowed to be missing** (a stage may have no near strip) — the far one is not.
	var img := _far.get_image()
	_top_fill = img.get_pixel(0, 0)
	queue_redraw()


func _process(_dt: float) -> void:
	# Redraw when the camera moves. The drawing coordinates are tied to the camera.
	queue_redraw()


func _draw() -> void:
	if _cam == null or _far == null:
		return

	# Screen-sized, from the camera center. **It does not cover the whole world** —
	#  drawing 16,384 x 4,032px every frame wastes the 99% that is off screen.
	var half := _view * 0.5
	var origin := _cam.global_position - half
	var fh := float(_far.get_height())

	var far_y := _far_y(origin.y, fh)

	# Above the far picture. Drawn first so the picture lands on top of the seam.
	draw_rect(Rect2(origin.x, origin.y, _view.x, maxf(0.0, far_y - origin.y)), _top_fill)
	var below := far_y + fh
	_draw_depth_fill(origin, maxf(below, origin.y), origin.y + _view.y)

	_tile(_far, origin, far_y, Fx.BG_FAR_SCROLL_X)

	if _near != null:
		# **The strip's bottom sits on the ground line**, so its own height comes off the anchor.
		#  Written this way, a picture of a different height still stands on the ground instead of floating.
		var near_y := _layer_y(origin.y,
			Fx.BG_NEAR_GROUND_Y - float(_near.get_height()), Fx.BG_NEAR_SCROLL_Y)
		_tile(_near, origin, near_y, Fx.BG_NEAR_SCROLL_X)


## Where a layer lands vertically. **ratio 1 = the anchor exactly (nailed to the world),
## ratio 0 = the screen top (glued to the window).** Everything between is the parallax drift.
func _layer_y(screen_top: float, anchor_y: float, ratio: float) -> float:
	return anchor_y + (screen_top - anchor_y) * (1.0 - ratio)


## The far layer's vertical position, **clamped so it stops following the camera at the ground line**
##  (`Fx.BG_UNDER_TOP_Y`) instead of gluing to the window forever. Before this clamp, ratio 0.08 carried
##  it almost 1:1 with the camera the whole way down — measured (`docs/design/underground-depth.md`): at
##  the map's bedrock floor the unclamped picture still spanned world y 944..1488, so a dug hole there
##  showed sky. Past the clamp the picture scrolls off the top of the screen instead.
## **Pulled out of `_draw()`** so it can be driven directly at a deep camera position without needing
##  `_draw()`'s `NOTIFICATION_DRAW` context (`net_background._far_picture_stops_at_the_ground_line`).
func _far_y(screen_top: float, far_h: float) -> float:
	var y := _layer_y(screen_top, Fx.BG_FAR_ANCHOR_Y, Fx.BG_FAR_SCROLL_Y)
	return minf(y, Fx.BG_UNDER_TOP_Y - far_h)


## Splits `[y0, y1)` into contiguous, in-order `[start, end, band_index]` segments against
##  `Fx.BG_UNDER_BANDS` — pure geometry, no drawing, so it can be driven directly by a net
##  (`draw_rect` only works inside `_draw()`'s own `NOTIFICATION_DRAW` context).
## **A bounded `for i in n` loop, not a `while` walking forward by float-computed edges** — the earlier
##  version derived each band's edge by reversing `floor((y-top)/span*n)` back into world px, and those
##  two float computations can round to a hair apart. Iterating band index directly instead means the
##  loop always visits every band exactly once, in order — there is no edge left to round the wrong way.
func _band_segments(y0: float, y1: float) -> Array:
	var out: Array = []
	if y1 <= y0:
		return out
	var bands: Array = Fx.BG_UNDER_BANDS
	var n := bands.size()
	if n == 0:
		return out
	var top := Fx.BG_UNDER_TOP_Y
	# Guarded against 0/negative — a misconfigured span must not divide by zero.
	var span := maxf(Fx.BG_UNDER_BOTTOM_Y - top, 0.001)
	for i in n:
		var lo := top + span * float(i) / float(n)
		var hi := top + span * float(i + 1) / float(n)
		if i == n - 1:
			# **The last band floods everything past the map's own bedrock floor** — there is no next
			#  band to hand off to down there, so its color simply keeps going to the bottom of the screen.
			hi = maxf(hi, y1)
		var seg_lo := maxf(lo, y0)
		var seg_hi := minf(hi, y1)
		if seg_hi > seg_lo:
			out.append([seg_lo, seg_hi, i])
	return out


## Everything below the far picture — banded rects darkening toward bedrock, replacing the old single
##  `_bottom_fill` color (`Fx.BG_UNDER_BANDS`, top to bottom, from `_band_segments()`).
func _draw_depth_fill(origin: Vector2, y0: float, y1: float) -> void:
	var segs := _band_segments(y0, y1)
	if segs.is_empty():
		if y1 > y0:
			# No bands configured — still leaves *something* visible rather than the transparent black
			#  `EMPTY` showing through, the same reasoning `_top_fill` exists for.
			draw_rect(Rect2(origin.x, y0, _view.x, y1 - y0), Color.BLACK)
		return
	for seg: Array in segs:
		draw_rect(Rect2(origin.x, seg[0], _view.x, seg[1] - seg[0]), Fx.BG_UNDER_BANDS[seg[2]])


## Horizontal tiling across the screen. The same drift formula, with the world origin as the anchor.
func _tile(tex: Texture2D, origin: Vector2, y: float, ratio: float) -> void:
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var drift := origin.x * (1.0 - ratio)
	# **Start one tile left of the screen edge.** Round toward zero instead and the leftmost tile is missing
	#  for exactly the width of one scroll step, which reads as a flicker at the screen edge.
	var x := origin.x - fposmod(origin.x - drift, tw)
	while x < origin.x + _view.x:
		draw_texture_rect(tex, Rect2(x, y, tw, th), false)
		x += tw
