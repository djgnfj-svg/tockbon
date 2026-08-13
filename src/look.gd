class_name Look
extends RefCounted
## Every presentation constant, in exactly one file.
##
## This is the one folder rule from the deleted game that survived on its own merit, and it survived
## because the failure was measured: a value was doubled and **nothing changed on screen**, since the
## number that would have shown it lived in six places and only one of them moved.
##
## Nothing here changes what happens. Sizes and colours only — if a constant would alter the simulation,
## it belongs in `rules.gd`.

## The field's floor colour. **Read nowhere in `src/`** — it is mirrored by hand into `project.godot`'s
## `[rendering] environment/defaults/default_clear_color`, the engine's own clear colour, rather than
## painted per frame. That key sat as `rendering/environment/...` while already inside the `[rendering]`
## section — the section itself supplies the first path segment, so the real key Godot reads is
## `environment/defaults/...`, and the doubled prefix meant nothing was ever applied; the play field showed
## the engine's default grey. Fixed in `project.godot`, 2026-08-14. If this value is ever retuned, it has
## to move in both files — there is no automatic link between them.
const BG := Color(0.09, 0.06, 0.05)

const HOST_COLOR := Color(0.96, 0.88, 0.52)
const HOST_HURT_COLOR := Color(1.0, 0.45, 0.35)
const HOST_RADIUS := 14.0

## **The clone is the same creature as the host, smaller.** It was drawn green against a yellow host and
## the user's read was that the swarm was a different animal — which is exactly wrong for a game about
## one cell dividing. Same hue, one step darker, and the loaded tint stays as the readability signal.
const CLONE_COLOR := Color(0.82, 0.74, 0.42)
const CLONE_LOADED_COLOR := Color(1.0, 0.95, 0.42)
const CLONE_RADIUS := 8.0
## A loaded clone is visibly bigger. **The only readability requirement in this build**: telling a loaded
## clone from an empty one across the screen is what makes an abandoned harvest legible as a loss.
const CLONE_LOAD_GROWTH := 1.6
const CLONE_LOAD_FULL := 8.0

const FOOD_COLOR := Color(0.45, 0.65, 0.85)
const FOOD_RADIUS := 3.0

## Red while it can eat you, cold blue once the swarm has outgrown it and it is running. **The flip has to
## be visible from across the screen** — it is the moment the game is about.
const CRITTER_COLOR := Color(0.78, 0.28, 0.3)
const CRITTER_PREY_COLOR := Color(0.42, 0.62, 0.86)

## The body is a square with the corners knocked off, not a circle. `CORNER` is how much of the half-width
## each cut takes.
const CORNER := 0.34

const RALLY_COLOR := Color(1.0, 1.0, 1.0, 0.35)
const RALLY_RADIUS := 22.0

# -- the camera pulls back as the swarm grows -----------------------
## `Camera2D.zoom`: larger is closer in. Measured against `swarm.count` (bodies, host included), not
## clones — see `main.gd`'s `_apply_zoom()` (stage 3).
const ZOOM_NEAR := 1.6
const ZOOM_FAR := 0.8
const ZOOM_FULL_AT := 30.0
## Per second, as `1.0 - exp(-ZOOM_LERP * delta)` — frame-rate independent, see stage 3.
const ZOOM_LERP := 2.0

# -- title and ending screens -----------------------------------------
## Placeholder. Art is generated locally and pointed at, never discussed — see CLAUDE.md.
const TITLE_BG := Color(0.07, 0.05, 0.05)

## Only one text colour is used on these two screens today — the ending's rows and the title's enabled
## labels both read this. No secondary/dim row exists in the design; add SCREEN_DIM_TEXT back the day one
## does, rather than carry a constant nothing draws.
const SCREEN_TEXT := Color(0.95, 0.92, 0.86)

const BUTTON_SIZE := Vector2(280.0, 62.0)
const BUTTON_GAP := 18.0
const BUTTON_BG := Color(0.16, 0.14, 0.13)
const BUTTON_BG_OFF := Color(0.11, 0.10, 0.10)
## Chrome under every button and all eleven slots on both screens — not the same idea as `ENDING_CLEARED`
## below, which merely happens to share this value today. **Do not alias them.** They are a pair with
## `ENDING_DIED` (same layout, different colour by outcome); `BUTTON_EDGE` is unrelated chrome. Aliased
## once and reverted: tuning the victory headline would have dragged every button edge and slot border
## with it, and nothing would have caught that.
const BUTTON_EDGE := Color(0.95, 0.85, 0.45)
const BUTTON_EDGE_WIDTH := 2.0
## The greyed pair is what makes 도감/설정 read as coming, not broken.
const BUTTON_TEXT_OFF := Color(0.42, 0.40, 0.38)
## Where a button's label sits, inset from its rect's top-left corner and vertically centred against
## `BUTTON_SIZE.y` (62 * 0.5 + 8).
const BUTTON_LABEL_INSET := Vector2(24.0, 39.0)

## Inherited from `hud.gd`'s `OVER_DIM`, which stage 3 deletes once the ending screen replaces it.
const ENDING_DIM := Color(0.04, 0.03, 0.03, 0.86)
const ENDING_CLEARED := Color(0.95, 0.85, 0.45)
const ENDING_DIED := Color(0.85, 0.35, 0.32)
## The headline's left edge (half-width reserved left of screen-centre) and its distance from the top.
const HEADLINE_X_OFFSET := 220.0
const HEADLINE_Y := 90.0
## The six rows below the headline: where the first one starts relative to the headline, and their gap.
const ROW_START_Y := 56.0
const ROW_GAP := 34.0
## The ending's two buttons, measured up from the screen's bottom edge.
const BUTTON_BOTTOM_MARGIN := 120.0

## The eleven body slots. Drawn empty this plan — plan 3 fills `RunResult.body_slots`.
const SLOT_SIZE := Vector2(38.0, 38.0)
const SLOT_GAP := 8.0
const SLOT_EMPTY := Color(0.2, 0.18, 0.17)
const SLOT_EDGE_WIDTH := 1.0
## A filled slot's label, inset from its rect's top-left corner.
const SLOT_LABEL_INSET := Vector2(4.0, 30.0)
## The eleven slots, measured up from the screen's bottom edge.
const SLOT_BOTTOM_MARGIN := 220.0

const FONT_HEADLINE := 40
const FONT_BUTTON := 28
const FONT_ROW := 24
const FONT_SLOT := 12
