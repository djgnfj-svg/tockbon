extends RefCounted
## Where the rune-grant banner's icon and sentence sit inside `rune_grant_view`'s own box.
## **Pure and static, so a net can call it with no scene** — the same idiom `onboard_layout.gd` already
## holds, for the same reason: drawing must read the one place the coordinates come from.

const Fx := preload("res://src/view/fx_tuning.gd")


## The whole backing panel. **Drawn first**, same reason `onboard_layout.panel_rect` gives — this box sits
## over the live world, not a fixed background, so nothing under it can be assumed dark.
static func panel_rect(box_size: Vector2) -> Rect2:
	return Rect2(Vector2.ZERO, box_size)


## The rune's own picture — centered horizontally, near the top of the box.
static func icon_rect(box_size: Vector2) -> Rect2:
	var s := Fx.RUNE_GRANT_ICON_PX
	return Rect2(box_size.x * 0.5 - s * 0.5, 18.0, s, s)


## The sentence's baseline y — directly below the icon. **Not a rect**: the caller measures its own string
## width to center it horizontally, the same idiom `onboard_view._draw_onboard_key` already uses for a
## label a fixed-width rect cannot center a Korean sentence against.
static func text_baseline_y(box_size: Vector2) -> float:
	var icon := icon_rect(box_size)
	return icon.position.y + icon.size.y + Fx.RUNE_GRANT_TEXT_GAP_PX + Fx.RUNE_GRANT_TEXT_SIZE
