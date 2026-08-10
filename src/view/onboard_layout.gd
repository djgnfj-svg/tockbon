extends RefCounted
## Where the onboarding arrow and its "Tab" key cap sit, inside `onboard_view`'s own small box.
## **Pure and static, so a net can call it with no scene** — the same idiom `circle_layout`/`book_layout`
## already hold, for the same reason: drawing and any future hit-testing must read the one place the
## coordinates come from.
##
## **Every number here is a starting value — none of it has been judged by eye**
## (`onboarding-and-palette-tabs.md`, "Onboarding's shape" TBD: what the arrow looks like, where it anchors).

const Fx := preload("res://src/view/fx_tuning.gd")


## The backing panel — the whole box. **Drawn first**, so the arrow, key and text below all read against
## one fixed dark plate instead of whatever the world happens to show through at this screen position
## (sky one moment, dirt the next — `sky_background.gd`'s `_top_fill` is sampled from the art, not fixed).
static func panel_rect(box_size: Vector2) -> Rect2:
	return Rect2(Vector2.ZERO, box_size)


## The "Tab" key cap — bottom of the box, centered.
static func key_rect(box_size: Vector2) -> Rect2:
	var w := Fx.ONBOARD_KEY_W_PX
	var h := Fx.ONBOARD_KEY_H_PX
	return Rect2(box_size.x * 0.5 - w * 0.5, box_size.y - h, w, h)


## The arrow — directly above the key cap, pointing down at it.
static func arrow_rect(box_size: Vector2) -> Rect2:
	var key := key_rect(box_size)
	var w := Fx.ONBOARD_ARROW_W_PX
	var h := Fx.ONBOARD_ARROW_H_PX
	return Rect2(key.get_center().x - w * 0.5, key.position.y - Fx.ONBOARD_ARROW_GAP_PX - h, w, h)


## The instruction line's baseline y — directly above the arrow. **Not a rect**: the caller measures its
## own string width to center it horizontally, the same idiom `onboard_view._draw_onboard_key` already uses
## for the key label (a fixed-width rect cannot center a Korean sentence whose width the font alone knows).
static func text_baseline_y(box_size: Vector2) -> float:
	return arrow_rect(box_size).position.y - Fx.ONBOARD_TEXT_GAP_PX
