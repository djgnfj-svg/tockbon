# **What the selection-box candidates share: the pulled ink, made transparent.**
#
# The candidate pictures in `.candidates/selection_box/` are mint ink on an OPAQUE WHITE ground,
# RGB with no alpha — the generator draws on paper, not on glass. A box drawn from one of them has to
# show the island through it, so the white has to become alpha before the picture is any use.
#
# ⚠⚠ **`.candidates/` is not imported by Godot** (`.prototypes/README.md`, trap 2): `load()` and
# `preload()` on a PNG there fail with no sidecar. The picture is read off disk with
# `Image.load(ProjectSettings.globalize_path(path))`, the way `bush/common.gd` does.
#
# Called as a static script: `var common: GDScript = load("res://.prototypes/selection_box/common.gd")`
# then `common.load_ink(path)`.
extends RefCounted

## The ink the generator was asked for — mint (158, 245, 212). **Every opaque pixel of the returned
## texture is this colour**; the shape lives in the alpha alone.
const INK := Color(158.0 / 255.0, 245.0 / 255.0, 212.0 / 255.0, 1.0)


## Loads a PNG from `.candidates/selection_box/` and turns its white ground into transparency.
##
## **Alpha = 1 − whiteness.** A pixel's whiteness is its smallest channel, scaled so that pure white
## reads 1 and the ink's own smallest channel (158/255) reads 0 — so a full-ink pixel comes back at
## alpha 1, white at alpha 0, and the soft edge the generator anti-aliased in between. ⚠ The 64 px
## downsamples never reach the full ink (their darkest pixel is about (185, 250, 224)), so their peak
## alpha is about 0.7 — the lab prints the measured coverage at boot.
##
## ⚠ **Filtering is not a property of `ImageTexture` in Godot 4.** It is set on the node that draws
## the texture; call `nearest(node)` below on a `CanvasItem` or a `SpriteBase3D`.
static func load_ink(path: String) -> ImageTexture:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		push_error("common.load_ink: cannot read %s" % path)
		return null
	img.convert(Image.FORMAT_RGBA8)
	var ink_min := minf(minf(INK.r, INK.g), INK.b)
	var span := 1.0 - ink_min
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			var whiteness := (minf(minf(p.r, p.g), p.b) - ink_min) / span
			var a := clampf(1.0 - whiteness, 0.0, 1.0)
			img.set_pixel(x, y, Color(INK.r, INK.g, INK.b, a))
	return ImageTexture.create_from_image(img)


## The ink colour as a `Color`, for a candidate that draws its own lines and wants them to match the
## pulled pictures exactly.
static func ink_colour() -> Color:
	return INK


## Sets nearest-neighbour sampling on whatever draws the texture, so a 64 px picture stays pixel art
## when it is stretched across the screen. A `CanvasItem` (a `TextureRect`, a `Sprite2D`, a
## `NinePatchRect`) and a `SpriteBase3D` name the property differently, which is why this exists.
static func nearest(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	elif node is SpriteBase3D:
		(node as SpriteBase3D).texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
