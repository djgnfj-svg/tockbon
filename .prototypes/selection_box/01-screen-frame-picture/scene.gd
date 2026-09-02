# **01-screen-frame-picture — the pulled `frame_01` picture, cut into four corners and four edges,
# laid along the drag rect on a `CanvasLayer`.**
#
# Screen space: the box sits on `drag.rect` in screen px and does not turn with the board. The
# picture is the 64 px downsample of `selbox_frame_01` — a thin mint outline on white — read through
# `common.load_ink`, which keys the white to alpha. Its ink bounding box is found from the alpha, then:
#
#   - each **corner** is a `CORNER_PX` square cut from the picture's corner and drawn 1:1, unscaled
#   - each **edge** is the strip between two corners, stretched along its side only — the stroke's
#     thickness is never scaled, so it stays the picture's own 1–2 px whatever the rect size
#
# One `TextureRect` per piece, an `AtlasTexture` for the region, nearest sampling from `common.nearest`.
# ⚠ Nothing here is a `NinePatchRect` — its centre patch would stretch the (transparent) inside too,
# and its default axis stretch samples the corners through the filter.
extends RefCounted

const NAME := "01-screen-frame-picture"

const PICTURE := "res://.candidates/selection_box/selbox_frame_01_seed2137183347_64px.png"
## Side of the corner square cut from the picture, in picture px. Drawn 1:1 on screen.
const CORNER_PX := 4
## Alpha above which a picture pixel counts as ink when the frame's bounding box is found.
const INK_ALPHA := 0.3
## The `CanvasLayer` the pieces are hung on — above the shell's `Node2D` views, below nothing.
const LAYER := 1

var _layer: CanvasLayer = null
var _pieces: Array = []


func mount(game: Node, _fv: Node, drag: Dictionary) -> void:
	var common: GDScript = load("res://.prototypes/selection_box/common.gd")
	var tex: ImageTexture = common.load_ink(PICTURE)
	if tex == null:
		push_error("%s: no picture" % NAME)
		return
	var box := _ink_box(tex.get_image())
	if box.size.x < 2.0 * CORNER_PX or box.size.y < 2.0 * CORNER_PX:
		push_error("%s: ink box %s is too small to cut corners of %d px from" % [NAME, str(box), CORNER_PX])
		return
	var rect: Rect2 = drag["rect"]

	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	game.add_child(_layer)

	var c := float(CORNER_PX)
	# Picture px: the near corner squares start at the box origin, the far ones end at its end.
	var px0 := box.position.x
	var py0 := box.position.y
	var px1 := box.end.x - c
	var py1 := box.end.y - c
	var mid_w := box.size.x - 2.0 * c
	var mid_h := box.size.y - 2.0 * c
	# Screen px: the same four anchors on the drag rect.
	var sx0 := rect.position.x
	var sy0 := rect.position.y
	var sx1 := rect.end.x - c
	var sy1 := rect.end.y - c
	var span_w := maxf(rect.size.x - 2.0 * c, 0.0)
	var span_h := maxf(rect.size.y - 2.0 * c, 0.0)

	# Four corners, unscaled.
	_piece(common, tex, Rect2(px0, py0, c, c), Rect2(sx0, sy0, c, c))
	_piece(common, tex, Rect2(px1, py0, c, c), Rect2(sx1, sy0, c, c))
	_piece(common, tex, Rect2(px0, py1, c, c), Rect2(sx0, sy1, c, c))
	_piece(common, tex, Rect2(px1, py1, c, c), Rect2(sx1, sy1, c, c))
	# Four edges, each stretched along its own side only.
	_piece(common, tex, Rect2(px0 + c, py0, mid_w, c), Rect2(sx0 + c, sy0, span_w, c))
	_piece(common, tex, Rect2(px0 + c, py1, mid_w, c), Rect2(sx0 + c, sy1, span_w, c))
	_piece(common, tex, Rect2(px0, py0 + c, c, mid_h), Rect2(sx0, sy0 + c, c, span_h))
	_piece(common, tex, Rect2(px1, py0 + c, c, mid_h), Rect2(sx1, sy0 + c, c, span_h))
	print("[%s] ink box %s in the picture → rect %s on screen, %d pieces" % [
		NAME, str(box), str(rect), _pieces.size()])


func unmount() -> void:
	for p in _pieces:
		if is_instance_valid(p):
			p.queue_free()
	_pieces.clear()
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null


func lines() -> PackedStringArray:
	return PackedStringArray([
		"buys — the pulled stroke itself, mint and 1–2 px at any rect size; corners unscaled; never moves when the board turns",
		"costs — eight TextureRects laid out per drag; the 64 px ink peaks at alpha 0.72 so the line is a quarter see-through",
		"cannot — change stroke weight with zoom or rect size; follow the ground or turn with the board; hold a corner motif wider than 4 px",
	])


## One `TextureRect` showing the picture region `src` (picture px) at `dst` (screen px), nearest-sampled.
func _piece(common: GDScript, tex: Texture2D, src: Rect2, dst: Rect2) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = src
	var tr := TextureRect.new()
	tr.texture = atlas
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	common.nearest(tr)
	_layer.add_child(tr)
	tr.position = dst.position
	tr.size = dst.size
	_pieces.append(tr)


## The bounding box of every pixel whose alpha is above `INK_ALPHA`, end exclusive, in picture px.
func _ink_box(img: Image) -> Rect2:
	var x_min := img.get_width()
	var y_min := img.get_height()
	var x_max := -1
	var y_max := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > INK_ALPHA:
				x_min = mini(x_min, x)
				y_min = mini(y_min, y)
				x_max = maxi(x_max, x)
				y_max = maxi(y_max, y)
	if x_max < 0:
		return Rect2()
	return Rect2(x_min, y_min, x_max - x_min + 1, y_max - y_min + 1)
