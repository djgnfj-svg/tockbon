extends RefCounted
## Pick-window-axis coordinates — up to three card rects, the decline button, the dice button.
##
## **Static, so the nets read the same rects the drawing uses** — `circle_window.gd`'s own header pins the
## reason: `Control` methods (`_gui_input`, `_draw`) cannot be measured headless, so judgment has to be
## pushed into a file the nets *can* call directly.
##
## **The pick window does not know pages** (Stage D has no book — `book_layout`'s split is the assembly
## window's own problem). Everything here is relative to the window's own inside, the same coordinate space
## `circle_window._draw()` already uses without a page transform.

const Fx := preload("res://src/view/fx_tuning.gd")


## Up to 3 card rects, side by side, padded, below the title band and above the button row.
## **`count` is not hardcoded to 3** — a drained pool (`ThreePick.draw`'s own "take what remains" branch) can
## hand back fewer, and laying out 2 cards with a gap where a third would be reads as "one is missing", not
## "there were only two to offer".
static func cards(window_size: Vector2, count: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if count <= 0:
		return out
	var pad := Fx.PICK_PAD_PX
	var top := Fx.PICK_TITLE_BAND_PX
	var area_pos := Vector2(pad, top)
	var area_size := Vector2(maxf(window_size.x - pad * 2.0, 0.0), _body_h(window_size))
	var gap := Fx.PICK_CARD_GAP_PX
	var card_w := maxf((area_size.x - gap * float(count - 1)) / float(count), 0.0)
	for i in count:
		out.append(Rect2(area_pos.x + float(i) * (card_w + gap), area_pos.y, card_w, area_size.y))
	return out


## Which card index is at `p` (window-local coordinates) — `-1` if none.
## **Walks the exact rects `cards()` produced** — measuring separately here is how a click lands on the wrong
## card with no error (the same trap `palette_layout.item_at`'s own header names for its own hit test).
static func card_at(window_size: Vector2, count: int, p: Vector2) -> int:
	var rects := cards(window_size, count)
	for i in rects.size():
		if rects[i].has_point(p):
			return i
	return -1


## The bottom row, split into decline (left) and dice (right).
static func decline_rect(window_size: Vector2) -> Rect2:
	return _button_row(window_size)[0]


static func dice_rect(window_size: Vector2) -> Rect2:
	return _button_row(window_size)[1]


static func _button_row(window_size: Vector2) -> Array[Rect2]:
	var pad := Fx.PICK_PAD_PX
	var h := maxf(Fx.PICK_BUTTON_BAND_PX - pad, 0.0)
	var y := window_size.y - Fx.PICK_BUTTON_BAND_PX
	var w := maxf((window_size.x - pad * 3.0) * 0.5, 0.0)
	var out: Array[Rect2] = [
		Rect2(pad, y, w, h),
		Rect2(pad * 2.0 + w, y, w, h),
	]
	return out


# --- step 2 — the layer choice ---------------------------------------
##
## **The same vertical band `cards()` uses** (below the title, above the button row) — the decline/dice row
## does not move between steps, so `decline_rect()`/`dice_rect()` need no step-2 counterpart.
##
## **Split horizontally, not stacked or swapped wholesale**: the picked card shrinks into the left edge
## instead of disappearing, so it stays both **visible** (a reminder of what is being placed — Stage D's own
## lesson: a card must say what it does, not only what it is, and that reading matters exactly as much here)
## and **clickable** (press it again to go back to step 1 — the same "press what is placed and it comes back
## out" idiom `three_pick_window._gui_input`'s card toggle already holds in step 1).


## The picked card's step-2 rect — narrower than a step-1 card, full body height.
static func picked_card_rect(window_size: Vector2) -> Rect2:
	return Rect2(Fx.PICK_PAD_PX, Fx.PICK_TITLE_BAND_PX, Fx.PICK_PICKED_CARD_W_PX, _body_h(window_size))


## The circle's seat — everything to the right of the picked card, same band.
static func circle_rect(window_size: Vector2) -> Rect2:
	var left := Fx.PICK_PAD_PX * 2.0 + Fx.PICK_PICKED_CARD_W_PX
	return Rect2(left, Fx.PICK_TITLE_BAND_PX,
		maxf(window_size.x - left - Fx.PICK_PAD_PX, 0.0), _body_h(window_size))


## **The same expression `cards()` computes for its own `area_size.y`** — pulled out so the two rects that
## share the body band (`picked_card_rect` · `circle_rect`) cannot drift from each other or from `cards()`.
static func _body_h(window_size: Vector2) -> float:
	return maxf(window_size.y - Fx.PICK_TITLE_BAND_PX - Fx.PICK_BUTTON_BAND_PX - Fx.PICK_PAD_PX, 0.0)
