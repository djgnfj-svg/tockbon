# **02-screen-corners — the drag box as FOUR CORNER BRACKETS on the glass, thin lines between them.**
#
# The pulled picture `selbox_plain_02` is one mint ㄴ bracket on white: a vertical bar down the left
# and a doubled horizontal bar along the bottom, elbow at the bottom-left. It is cropped tight to its
# ink (about 30 x 32 px inside the 64 px sheet), and one copy stands at each corner of `drag.rect`,
# turned 0 / 90 / 180 / 270 degrees so every elbow points OUT of the box, at 1:1 pixels with nearest
# sampling. Between the brackets, along the rect's outer edge, a 1 px mint line closes the rectangle.
#
# **Screen space.** Everything lives on a `CanvasLayer` under the shell, positioned in viewport px
# straight from `drag.rect`. It does not read the camera, so a Q notch leaves it exactly where it was.
extends RefCounted

const NAME := "02-screen-corners"
const PICTURE := "res://.candidates/selection_box/selbox_plain_02_seed210764308_64px.png"

## Alpha above which a pixel counts as ink for the crop. The 64 px downsample peaks near 0.7 and its
## anti-aliased fringe sits under 0.3, so this keeps the bar and drops the halo.
const INK_ALPHA := 0.35
## Pixels of the sheet's border ignored by the crop — the generator left specks in the outermost rows.
const CROP_MARGIN := 4

var _layer: CanvasLayer = null
var _lines_ctl: Control = null
var _corners: Array = []


## A `Control` that paints the 1 px runs between the brackets as filled 1-px rects, which are crisp
## where a `draw_line` of width 1 would smear across two texels.
class Lines extends Control:
	var runs: Array = []      # of Rect2, in viewport px
	var colour := Color.WHITE

	func _draw() -> void:
		for r in runs:
			draw_rect(r, colour, true)


func mount(game: Node, _fv: Node, drag: Dictionary) -> void:
	var common: GDScript = load("res://.prototypes/selection_box/common.gd")
	var sheet: ImageTexture = common.load_ink(PICTURE)
	if sheet == null:
		push_error("%s: no picture" % NAME)
		return
	var tex := _crop_to_ink(sheet.get_image())
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var rect: Rect2 = drag["rect"]
	rect = Rect2(rect.position.round(), rect.size.round())
	var tl := rect.position
	var tr := rect.position + Vector2(rect.size.x, 0.0)
	var br := rect.end
	var bl := rect.position + Vector2(0.0, rect.size.y)

	_layer = CanvasLayer.new()
	_layer.name = "SelboxCorners"
	_layer.layer = 5
	game.add_child(_layer)

	# The elbow of the un-rotated bracket is its bottom-left. Godot 2D rotates clockwise for positive
	# angles, so 90 carries bottom-left to top-left, 180 to top-right, 270 to bottom-right. Each sprite
	# is centred so that its elbow lands exactly on the rect corner; w and h swap on the odd quarters.
	var placements := [
		[tl, PI * 0.5, Vector2(h * 0.5, w * 0.5)],
		[tr, PI, Vector2(-w * 0.5, h * 0.5)],
		[br, PI * 1.5, Vector2(-h * 0.5, -w * 0.5)],
		[bl, 0.0, Vector2(w * 0.5, -h * 0.5)],
	]
	for p in placements:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = true
		s.rotation = p[1]
		s.position = (p[0] as Vector2) + (p[2] as Vector2)
		common.nearest(s)
		_layer.add_child(s)
		_corners.append(s)

	# The 1 px runs along the outer edge, only in the gaps the brackets leave. Along the top and
	# bottom the brackets are `h` wide after turning, along the sides they are `w` tall... except that
	# the un-rotated bracket is w wide and h tall, so: TL/BR turned a quarter occupy h x w, TR/BL
	# occupy w x h. Top edge: TL spans h, TR spans w. Right edge: TR spans h, BR spans w. Bottom
	# edge: BR spans h, BL spans w. Left edge: BL spans h, TL spans w.
	_lines_ctl = Lines.new()
	_lines_ctl.colour = common.ink_colour()
	_lines_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines_ctl.runs = [
		Rect2(tl.x + h, tl.y, maxf(rect.size.x - h - w, 0.0), 1.0),          # top
		Rect2(tr.x - 1.0, tr.y + h, 1.0, maxf(rect.size.y - h - w, 0.0)),     # right
		Rect2(bl.x + w, bl.y - 1.0, maxf(rect.size.x - w - h, 0.0), 1.0),    # bottom
		Rect2(tl.x, tl.y + w, 1.0, maxf(rect.size.y - w - h, 0.0)),          # left
	]
	_layer.add_child(_lines_ctl)
	print("[%s] bracket %dx%d px, rect=%s" % [NAME, int(w), int(h), str(rect)])


func unmount() -> void:
	if _layer != null and is_instance_valid(_layer):
		_layer.get_parent().remove_child(_layer)
		_layer.queue_free()
	_layer = null
	_lines_ctl = null
	_corners.clear()


func lines() -> PackedStringArray:
	return PackedStringArray([
		"buys — four drawn brackets from the pulled picture, pixel-crisp at 1:1, and the box stays put on the glass when the board turns",
		"costs — the bracket is a fixed 30 x 32 px, so the box's look depends on how big the drag is; the runs between are still code",
		"cannot — shrink or grow with the drag: under about 60 px the brackets overlap, on a huge drag they vanish into the corners and the 1 px runs carry the whole box",
	])


## Crops the loaded sheet to the bounding box of its ink, ignoring a border of `CROP_MARGIN` px where
## the generator left specks, and returns a new texture holding only the bracket.
func _crop_to_ink(img: Image) -> ImageTexture:
	var x0 := img.get_width()
	var y0 := img.get_height()
	var x1 := -1
	var y1 := -1
	for y in range(CROP_MARGIN, img.get_height() - CROP_MARGIN):
		for x in range(CROP_MARGIN, img.get_width() - CROP_MARGIN):
			if img.get_pixel(x, y).a >= INK_ALPHA:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	if x1 < 0:
		push_error("%s: no ink found in the picture" % NAME)
		return ImageTexture.create_from_image(img)
	var region := Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
	var cut := img.get_region(region)
	return ImageTexture.create_from_image(cut)
