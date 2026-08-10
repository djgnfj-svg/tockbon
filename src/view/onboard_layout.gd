extends RefCounted
## Where the onboarding arrow and its "Tab" key cap sit, inside `onboard_view`'s own small box.
## **Pure and static, so a net can call it with no scene** — the same idiom `circle_layout`/`book_layout`
## already hold, for the same reason: drawing and any future hit-testing must read the one place the
## coordinates come from.
##
## **Every number here is a starting value — none of it has been judged by eye**
## (`onboarding-and-palette-tabs.md`, "Onboarding's shape" TBD: what the arrow looks like, where it anchors).

const Fx := preload("res://src/view/fx_tuning.gd")


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
