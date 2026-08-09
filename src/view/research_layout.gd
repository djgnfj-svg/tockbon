extends RefCounted
## Research-window coordinates — the panel's nine slices, the four unlock rows, the material line.
##
## **Static, so the nets read the same rects the drawing uses** — `circle_window.gd`'s own header pins the
## reason and `pick_layout.gd` is the shape this file copies: `Control._draw()` cannot be measured headless,
## so the judgment is pushed into a file the nets *can* call directly.
##
## **There is no hit test here.** The research window has no buttons — nothing is buyable
## (`docs/design/town.md`'s own TBD), so `pick_layout.card_at`'s counterpart would be a function with no
## caller. **Add it the day a price exists, not before.**

const Fx := preload("res://src/view/fx_tuning.gd")

## Padding inside the panel's stone frame, before any content.
const PAD_PX := 18.0
## The title band, then the material line, then the rows.
const TITLE_BAND_PX := 40.0
const MATERIAL_BAND_PX := 34.0
const ROW_GAP_PX := 8.0
## How far the state line's baseline sits above the row's bottom edge — room for a descender.
const BASELINE_DROP_PX := 3.0
## **34, not 26 — the footer was overlapping the last row's own second line on screen.** Every row draws two
##  lines (name, then state) and the second sits below the row's centre, so the band under the rows has to
##  clear a descender's worth more than the footer text's own height.
const FOOTER_BAND_PX := 34.0


## **The nine slices of a 9-slice panel**, as `[source Rect2, destination Rect2]` pairs in draw order.
##
## **Written out rather than reached for through `NinePatchRect`**: that node would need to exist in the
##  scene file, and this window is drawn (`town_view`'s own header has the reason — a node whose position
##  lives in two places drifts silently). Nine `draw_texture_rect_region` calls is the whole of it.
##
## **The corners are drawn 1:1 and never scaled.** That is the entire point of a 9-slice: stretch a carved
##  stone corner and it smears. The edges stretch along one axis only, the middle along both — parchment and
##  a straight stone course both survive that.
##
## **A window smaller than two borders would make the middle negative.** `maxf(0, ...)` collapses it instead
##  of drawing a mirrored rect, which is what a negative size does silently.
static func nine(window: Rect2, tex_size: Vector2, border: float) -> Array:
	var b := minf(border, minf(tex_size.x, tex_size.y) * 0.5)
	var sx0 := 0.0
	var sx1 := b
	var sx2 := tex_size.x - b
	var sw_mid := maxf(tex_size.x - b * 2.0, 0.0)
	var sy0 := 0.0
	var sy1 := b
	var sy2 := tex_size.y - b
	var sh_mid := maxf(tex_size.y - b * 2.0, 0.0)

	var dx0 := window.position.x
	var dx1 := window.position.x + b
	var dx2 := window.end.x - b
	var dw_mid := maxf(window.size.x - b * 2.0, 0.0)
	var dy0 := window.position.y
	var dy1 := window.position.y + b
	var dy2 := window.end.y - b
	var dh_mid := maxf(window.size.y - b * 2.0, 0.0)

	return [
		[Rect2(sx0, sy0, b, b), Rect2(dx0, dy0, b, b)],
		[Rect2(sx1, sy0, sw_mid, b), Rect2(dx1, dy0, dw_mid, b)],
		[Rect2(sx2, sy0, b, b), Rect2(dx2, dy0, b, b)],
		[Rect2(sx0, sy1, b, sh_mid), Rect2(dx0, dy1, b, dh_mid)],
		[Rect2(sx1, sy1, sw_mid, sh_mid), Rect2(dx1, dy1, dw_mid, dh_mid)],
		[Rect2(sx2, sy1, b, sh_mid), Rect2(dx2, dy1, b, dh_mid)],
		[Rect2(sx0, sy2, b, b), Rect2(dx0, dy2, b, b)],
		[Rect2(sx1, sy2, sw_mid, b), Rect2(dx1, dy2, dw_mid, b)],
		[Rect2(sx2, sy2, b, b), Rect2(dx2, dy2, b, b)],
	]


## The area inside the stone frame and the padding — everything else here is measured from it.
static func inner(window_size: Vector2) -> Rect2:
	var m := Fx.RESEARCH_PANEL_BORDER_PX + PAD_PX
	return Rect2(m, m, maxf(window_size.x - m * 2.0, 0.0), maxf(window_size.y - m * 2.0, 0.0))


## One row per unlock axis, stacked. **Evenly divided over whatever is left** after the title, the material
##  line and the footer — so the window can be resized without the last row falling off the bottom, the same
##  reason `pick_layout.cards` divides its area instead of using a fixed card height.
static func rows(window_size: Vector2) -> Array[Rect2]:
	var area := inner(window_size)
	var top := area.position.y + TITLE_BAND_PX + MATERIAL_BAND_PX
	var avail := maxf(area.end.y - FOOTER_BAND_PX - top, 0.0)
	var n := Fx.RESEARCH_ROWS.size()
	var out: Array[Rect2] = []
	if n <= 0:
		return out
	var h := maxf((avail - ROW_GAP_PX * float(n - 1)) / float(n), 0.0)
	for i in n:
		out.append(Rect2(area.position.x, top + float(i) * (h + ROW_GAP_PX), area.size.x, h))
	return out


## The slot frame at the left of a row — square, vertically centred in the row.
## **It is clamped to the row height**, so a squeezed window shrinks the frame instead of letting it spill
##  into the row above.
static func slot(row: Rect2) -> Rect2:
	var s := minf(Fx.RESEARCH_SLOT_PX, row.size.y)
	return Rect2(row.position.x, row.position.y + (row.size.y - s) * 0.5, s, s)


## Where a row's text starts — past the slot frame, with the same padding used everywhere else.
static func text_x(row: Rect2) -> float:
	return slot(row).end.x + PAD_PX


## **The two text baselines in a row, anchored to the row's own edges and not to its centre.**
##
## **Centred was wrong on screen**: the state line was placed at `centre + size + 2`, which for a 35px row
##  puts its descender past the row's bottom, and the last row's state ran straight into the footer. Anchoring
##  the name under the top and the state above the bottom makes "the text is inside its row" true by
##  construction rather than by two constants happening to add up.
##
## **Returned as a pair so the window cannot use one and forget the other** — and so a net can assert both
##  sit inside the row, which is the whole thing that broke.
static func text_baselines(row: Rect2) -> Array:
	return [
		row.position.y + Fx.RESEARCH_TEXT_SIZE,
		row.end.y - BASELINE_DROP_PX,
	]


## The material line, between the title and the first row.
static func material_line(window_size: Vector2) -> Rect2:
	var area := inner(window_size)
	return Rect2(area.position.x, area.position.y + TITLE_BAND_PX, area.size.x, MATERIAL_BAND_PX)


static func footer_line(window_size: Vector2) -> Rect2:
	var area := inner(window_size)
	return Rect2(area.position.x, area.end.y - FOOTER_BAND_PX, area.size.x, FOOTER_BAND_PX)
