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

## **Both body radii live in `rules.gd` (`BODY_RADIUS`, `CLONE_BODY_RADIUS`) and NOT here.** They decide
## who `V` absorbs and what reaches what, so they change what happens; this file may only hold constants
## that do not. Drawing reads them from there — a copy here is exactly the divergence this file exists to
## prevent, and the day the two disagree the picture stops being the simulation.

## **The clone is the same creature as the host, smaller.** It was drawn green against a yellow host and
## the user's read was that the swarm was a different animal — which is exactly wrong for a game about
## one cell dividing. Same hue, one step darker, and the loaded tint stays as the readability signal.
const CLONE_COLOR := Color(0.82, 0.74, 0.42)
const CLONE_LOADED_COLOR := Color(1.0, 0.95, 0.42)
## A loaded clone is visibly bigger. **The only readability requirement in this build**: telling a loaded
## clone from an empty one across the screen is what makes an abandoned harvest legible as a loss.
const CLONE_LOAD_GROWTH := 1.6
const CLONE_LOAD_FULL := 8.0

const FOOD_COLOR := Color(0.45, 0.65, 0.85)
const FOOD_RADIUS := 3.0

# -- the three species -------------------------------------------------
## Flat placeholders, one per `Parts.Species`. ⚠ **Colour is the user's call, not the builder's** — art in
## this repo is decided by generating candidates and pointing at one, never by discussion. These are picked
## only to clear the legibility floor, which is the one thing a placeholder still has to do.
##
## Measured against `BG` (relative luminance 0.0056, WCAG): every colour in this block and the ground block
## below was computed against it. **The floor is `CROW_COLOR` itself at 3.99:1** — the red carried over
## unchanged from the one critter colour this build had before there were species, which is the dimmest
## thing already accepted on screen. ⚠ **This paragraph said "none sits under 4.0:1" for a plan and the crow
## is 0.005 under it**; the claim went unmeasured until `net_numbers` computed every ratio in the file, and
## the floor written there is 3.9 so the check and this sentence agree. They must also separate from the
## host's and the clones' yellow (mine vs theirs) and from food's blue.
const CROW_COLOR := Color(0.78, 0.28, 0.30)
const HORSE_COLOR := Color(0.45, 0.78, 0.42)
const BOSS_COLOR := Color(0.85, 0.35, 0.85)
## The four species added after the first three. Ratios against `BG` computed the same way, and each one
## clears the 3.9 floor the block above states: 다람쥐 7.1:1 · 코끼리 7.9:1 · 치타 9.8:1 · 사자 6.5:1.
##
## ⚠ **다람쥐 and 사자 are the pair at risk here, not any of them against the background** — both are warm
## oranges, and the thing that separates them on screen is that the squirrel is the smallest body in the
## game (7px) and the lion is the second largest (26px). They are deliberately far apart in lightness too.
const SQUIRREL_COLOR := Color(0.80, 0.58, 0.35)
const ELEPHANT_COLOR := Color(0.62, 0.66, 0.72)
const CHEETAH_COLOR := Color(0.35, 0.80, 0.78)
const LION_COLOR := Color(0.92, 0.48, 0.12)

# -- the ground: rock, water, and what a kill leaves -------------------
## **A wall you walk into, so it must read before you touch it** — 4.22:1. Warm grey rather than any
## species' hue. Forty rocks of radius 40–90 on a dark floor at 1.4:1 is the "dark placeholder on a dark
## floor" defect verify-look already caught once on this build.
const ROCK_COLOR := Color(0.50, 0.46, 0.43)
## 4.17:1. Separated from food's blue by being darker and very much larger.
const WATER_COLOR := Color(0.28, 0.48, 0.66)
## 4.51:1 (re-measured here rather than inherited). **A corpse is the ground, not a creature** —
## desaturated, so it must not read as something that can still hurt you, while staying findable.
const CORPSE_COLOR := Color(0.55, 0.47, 0.42)
## The host's own yellow: the arc is **the swarm eating**, not the corpse doing something.
const CORPSE_PROGRESS_COLOR := Color(0.96, 0.88, 0.52, 0.9)
const CORPSE_PROGRESS_WIDTH := 3.0
## × the corpse's own radius, the same shape `SPLIT_CHARGE_RING` has. Left unstated, the arc's radius
## becomes a literal inside `field_view.gd` and this file stops being the one place a size lives.
const CORPSE_PROGRESS_RING := 1.5

# -- the force and hp numbers on the field ------------------------------
## Bodies within this of a cluster's centroid draw one summed number. **A readout rule, not a rule about
## what happens** — nothing in `src/sim/` may read it.
const FORCE_CLUSTER_RADIUS := 48.0
const FORCE_LABEL_SIZE := 14
## Below the body, so the body stays the thing being read.
const FORCE_LABEL_OFFSET := 18.0
## 16.0:1, and deliberately **not any body's colour** — a number that matches a body reads as part of it.
const FORCE_LABEL_COLOR := Color(0.93, 0.93, 0.88)

# -- the HUD ------------------------------------------------------------
## **These nine colours and thirteen numbers lived in `hud.gd` and that broke the one-file rule.** Every
## other presentation constant this build added was routed here; `HP_COLOR` was the one exception, and
## `net_body`'s hp check then asserted against `Hud.HP_COLOR` — reading the constant out of the very file it
## was supposed to be guarding. Moving them is a pure relocation: `net_hud` hand-writes every one of these
## numbers independently, so a mistake in the move is red rather than silent.
const HUD_TEXT := Color(0.95, 0.92, 0.86)
const HUD_DIM_TEXT := Color(0.66, 0.62, 0.58)
const HUD_BAR_BG := Color(0.18, 0.16, 0.15, 0.85)
const HUD_BAR_FILL := Color(0.95, 0.85, 0.45)
const HUD_CARRY_COLOR := Color(0.98, 0.92, 0.35)
## The HP readout's colour. **There is no second HP colour** — the row of empty circles that needed one is
## gone (user: 하트 개념 말고 숫자로 바로 표시), and a number has nothing to draw dim.
const HUD_HP_COLOR := Color(0.85, 0.35, 0.32)

## The level bar: its top-left corner, its height, and the pair of side insets subtracted from the
## `Control`'s own width. Laid out from `size`, so a zero-sized Control piles it into the corner — see
## `hud.gd::_ready`.
const HUD_BAR_AT := Vector2(24.0, 22.0)
const HUD_BAR_HEIGHT := 14.0
const HUD_BAR_INSETS := 48.0
## The four readouts. The last two are measured UP from the bottom edge, which is why their `y` is
## subtracted rather than added — a positive number here that reads as a drop would put both on the top row.
const HUD_BANK_AT := Vector2(24.0, 84.0)
const HUD_CARRY_AT := Vector2(24.0, 112.0)
const HUD_HP_AT_UP := Vector2(34.0, 28.0)
const HUD_LEGEND_AT_UP := Vector2(24.0, 68.0)
const FONT_HUD_BANK := 44
const FONT_HUD_ROW := 20
const FONT_HUD_HP := 26
## How long the one instruction in the game stays on screen.
const HUD_LEGEND_TIME := 12.0
## How fast the level bar chases the real value: the fraction of the gap still left after one second, so
## **lower is faster** and 0.0 would snap. It is the whole of "a dozen clones swallowed in a row reads as
## one surge rather than twelve invisible increments" — a presentation number if there ever was one, and
## it sat inline in `hud.gd::_process` while that file's header claimed it held no constant of its own.
const HUD_BAR_CHASE := 0.001

# -- the minimap --------------------------------------------------------
## 16:9 like the field, so the map never distorts. Bottom-right, laid out from the `Control`'s own `size`.
const MINIMAP_SIZE := Vector2(240.0, 135.0)
const MINIMAP_MARGIN := 16.0
const MINIMAP_BG := Color(0.0, 0.0, 0.0, 0.45)
const MINIMAP_FRAME := Color(0.75, 0.72, 0.62, 0.7)
const MINIMAP_CAMERA_COLOR := Color(0.96, 0.88, 0.52, 0.5)
const MINIMAP_HOST_R := 3.0
const MINIMAP_CLONE_R := 1.5
const MINIMAP_CREATURE_R := 2.0
## Other creatures appear only within this of the host; the boss always. **The map is orientation, not
## intelligence.** It decides what is DRAWN and nothing else, which is why it is here and not in `rules.gd`.
const MINIMAP_SHOW_DIST := 1600.0
## Water on the map, and it is the one thing there that is NOT gated by `MINIMAP_SHOW_DIST`. A pond is
## terrain — it does not move, it is why you took a route, and hiding it until you are 1600px away makes
## the map answer "what is near me" when what it is for is "where am I going". Twelve ponds of radius
## 90–180 land at 5.6–11.3px on a 240px map, so they read without a scale of their own.
##
## Dimmer than the field's `WATER_COLOR` and drawn under every mark: the map's own background is 45% black,
## so a pond at full strength competes with the host dot for the eye.
const MINIMAP_WATER_COLOR := Color(0.28, 0.48, 0.66, 0.75)

## The body is a square with the corners knocked off, not a circle. `CORNER` is how much of the half-width
## each cut takes.
const CORNER := 0.34

## Under every body, and it is a colour rather than tessellation — `field_view.gd` keeps `RING_SEGMENTS`
## and its siblings because those are how finely a shape is cut, not what it looks like.
const CELL_SHADOW := Color(0.0, 0.0, 0.0, 0.22)

# -- the level-up cards -------------------------------------------------
## Six colours that lived in `card_panel.gd`. Its own pixel literals are still there and are named in the
## scan's note — moving those is a bigger job than the one-file rule's colour half, which is what
## `net_draw_leaf` now enforces.
const CARD_DIM := Color(0.04, 0.03, 0.03, 0.72)
const CARD_BG := Color(0.16, 0.14, 0.13)
const CARD_EDGE := Color(0.95, 0.85, 0.45)
const CARD_HOVER := Color(0.24, 0.22, 0.18)
const CARD_TITLE_COLOR := Color(0.98, 0.93, 0.72)
const CARD_KEY_COLOR := Color(0.62, 0.58, 0.52)

# -- the body's parts, drawn on the host -------------------------------
## **A part is worn in the host's OWN colour.** That is what escaped the "texture comes from the preset"
## constraint that binds every generated asset: with one tone on the whole body there is nothing to match,
## which is what bought back the cap on how many species a habitat can hold — see the decision
## `the-body-is-a-line-drawn-by-code`. So a part is a SHAPE and a lift, never a picture.
##
## ⚠ **Every anchor and length here is a MULTIPLE of `Rules.BODY_RADIUS`, never an absolute pixel count.**
## The body's size is a rule (it decides who `V` absorbs); a part pinned in pixels sits right at radius 14
## and slides off the body the day that number is retuned, with nothing red. Same discipline as
## `SPLIT_CHARGE_RING`. Line WIDTHS are the exception and are absolute — a limb that thins with the body
## disappears rather than scaling.
##
## Limb pairs mirror across the facing, so only one side's offset is written: the sign is derived.
const PART_COLOR_LIFT := 0.22
const PART_HEAD_ANCHOR := 0.95
const PART_HEAD_SIZE := 0.42
const PART_TORSO_ANCHOR := 0.12
const PART_TORSO_BULGE := 0.74
const PART_BACK_ANCHOR := -0.95
const PART_BACK_SIZE := 0.38
## `x` is along the facing, `y` out to one side. The pair is drawn at ±y.
const PART_FORELIMB_ANCHOR := Vector2(0.4, 0.8)
const PART_HINDLIMB_ANCHOR := Vector2(-0.4, 0.8)
const PART_LIMB_LENGTH := 0.8
const PART_LIMB_WIDTH := 3.0
const PART_TAIL_ANCHOR := -1.0
const PART_TAIL_LENGTH := 1.25
const PART_TAIL_WIDTH := 3.0

## **Internal slots change drawing VALUES; they never add a shape.** That is the whole reason eleven slots
## cost no art. Each of the three below is passed to `FieldView._paint_body()` as its own argument so a net
## can pin the number per configuration — "the arguments differ" is the A/B comparison that lets five
## internal slots change nothing on screen and stay green, which is how a doubled power once moved zero
## pixels.
##
## ⚠ **Two of the five internal slots have no value here: `GUT` and `LUNG`.** The plan names four drawing
## values (corner, outline, colour depth, dot size) for five slots and claims all eleven read on screen;
## nine do. 말 폐활량 is one of the three August parts and wearing it changes nothing visible. Inventing a
## fifth value here would be building outside the plan, so it is reported instead of guessed.
##
## Bone SHARPENS: it takes off the corner cut, so the number goes DOWN with level, floored so the body
## never becomes a plain square.
const CORNER_PER_BONE := 0.06
const CORNER_MIN := 0.06
## Hide/fur: an outline in px, and how much darker the whole body reads. Both rise per level.
const HIDE_OUTLINE_WIDTH := 2.0
const HIDE_OUTLINE_DARKEN := 0.45
const HIDE_COLOR_DEPTH := 0.1
## Eyes: two dots, in body radii like every other anchor here. Radius 0 means no eyes and nothing is drawn
## — a bare body has no dots, which is exactly today's picture.
const EYE_DOT_RADIUS := 0.17
const EYE_DOT_PER_LEVEL := 0.05
const EYE_DOT_OFFSET := Vector2(0.38, 0.36)
const EYE_DOT_COLOR := Color(0.16, 0.12, 0.1)

## The marker on the point `3` was pressed. It was the rally ring until rally became "at the host", at
## which point its own draw guard (`rally != pos[0]`) would have been false forever and the feature would
## have vanished with every net still green.
const STRIKE_COLOR := Color(1.0, 1.0, 1.0, 0.35)
const STRIKE_RADIUS := 22.0

## The `F` charge, drawn as a ring arc on the host at `split_charge / Rules.SPLIT_HOLD_TIME`. Without it
## the 0.45s hold has no feedback at all and reads as a broken key.
const SPLIT_CHARGE_WIDTH := 3.0
const SPLIT_CHARGE_COLOR := Color(1.0, 0.96, 0.72, 0.9)
## A multiple of `Rules.BODY_RADIUS`, not an absolute radius: the arc has to sit just outside whatever the
## body is, and the body's size is a rule. Written as a scale, the two cannot drift apart.
const SPLIT_CHARGE_RING := 1.6

## How long the bite cone stays on screen after a bite lands. Long enough to read at 60fps, short enough
## not to lie about the cooldown. **The sim owns the clock** (`Swarm.bite_show` counts up from the bite)
## and this file owns only how long it is shown — `src/sim/` may not read this file, and the view may not
## hold state the sim does not know about, so the split falls exactly here.
const BITE_SHOW_TIME := 0.12
## The cone's fill. Its shape is `Swarm.bite_range` and `Swarm.bite_arc` — the two numbers the sim actually
## tested with on the last bite, never a second pair tuned to look right, or the picture stops being the
## hit. **They are read off the swarm rather than off a constant on purpose**: they used to be
## `Rules.BITE_RANGE`/`BITE_ARC`, and since the parts table landed the range and arc belong to whichever
## part fired — three keys can hold three different ARC parts at three different levels, and a constant
## here would draw one part's cone over another part's hit.
const BITE_COLOR := Color(1.0, 0.86, 0.55, 0.28)

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

## The eleven body slots **on the ending screen** — a summary strip, one row, a name and nothing else.
## The `Tab` panel's slots are a different size (`BODY_SLOT_SIZE` below) because they are clickable and
## carry a level as well as a name; sharing one size would have meant either an unreadable summary or an
## unclickable panel. Filled from `RunResult.body_slots`.
const SLOT_SIZE := Vector2(38.0, 38.0)
const SLOT_GAP := 8.0
const SLOT_EMPTY := Color(0.2, 0.18, 0.17)
const SLOT_EDGE_WIDTH := 1.0
## A filled slot's label, inset from its rect's top-left corner.
const SLOT_LABEL_INSET := Vector2(4.0, 30.0)
## The eleven slots, measured up from the screen's bottom edge.
const SLOT_BOTTOM_MARGIN := 220.0

# -- the body panel (Tab) ---------------------------------------------
## Two halves, laid out from `size`: the body's slots on the left, the three keys on the right. Kept as
## two independent columns because the user flagged that one key may be carrying too much — splitting it
## onto a second key later has to be a re-parent, not a rewrite.
const BODY_DIM := Color(0.04, 0.03, 0.03, 0.82)

## The panel's own slot squares. **Wider and shorter than the ending screen's**: 말 폐활량 is five glyphs
## and every `_paint_text` in this repo passes `-1` as the wrap width, so a name that does not fit does not
## clip — it runs out over the next square. Measured against the widest name in the August table, at
## `FONT_SLOT_NAME`, with the level on a second line.
const BODY_SLOT_SIZE := Vector2(84.0, 52.0)
const BODY_SLOT_GAP := 8.0
## The six external slots sit above the five internal ones. **Two groups, because they are two different
## kinds of thing** — externals put a shape on the body, internals change a drawing value — and one row of
## eleven says they are the same. The count of each comes from `Parts.Slot`'s order (`EYES` is the first
## internal), never from a literal here.
##
## The gap has to hold the second group's heading: at `FONT_GROUP` lifted by `BODY_GROUP_LIFT` the label's
## top sits ~18px above its baseline, so a gap of 18 put 속 straight through the bottom of the external
## row's squares. Nothing errors when two strings overlap — it just becomes unreadable.
const BODY_SLOT_ROW_GAP := 40.0
## Where a slot's part name sits, and its level below that, both inset from the square's top-left.
const BODY_SLOT_NAME_INSET := Vector2(8.0, 22.0)
const BODY_SLOT_LEVEL_INSET := Vector2(8.0, 42.0)
## A worn square reads differently from an empty one before the name is even read.
const BODY_SLOT_FILLED := Color(0.26, 0.23, 0.17)
## The heading over each of the two slot groups, lifted off the group's first square.
const BODY_GROUP_LIFT := 16.0

const BODY_ROW_SIZE := Vector2(300.0, 52.0)
const BODY_ROW_GAP := 14.0
const BODY_ROW_BG := Color(0.16, 0.14, 0.13)
## The row whose active has been picked up and is waiting for a destination. Without it the two-click bind
## has no state on screen and the first click reads as having done nothing.
const BODY_ROW_PICKED := Color(0.30, 0.27, 0.18)
## Where a row's key name sits inside its rect, and how far right of that the bound active's title starts.
const BODY_ROW_INSET := Vector2(18.0, 34.0)
const BODY_ROW_TITLE_X := 128.0
## Distance from a column's first rectangle up to that column's heading.
const BODY_HEAD_LIFT := 34.0
## The host's numbers, measured down from the bottom of the slot row. This is the only place force reaches
## the screen — without it a level's whole payout and every `F` are invisible.
const BODY_NUMBERS_DROP := 42.0
## The refusal line, measured down from the bottom of the last key row.
const BODY_REFUSAL_DROP := 38.0
const BODY_REFUSAL_COLOR := Color(1.0, 0.55, 0.45)

const FONT_HEADLINE := 40
const FONT_BUTTON := 28
const FONT_ROW := 24
## The ending screen's summary strip.
const FONT_SLOT := 12
## The `Tab` panel's squares — a name on one line, `Lv2` under it. Two sizes because the two screens hold
## different amounts in a square; see `BODY_SLOT_SIZE`.
const FONT_SLOT_NAME := 16
const FONT_SLOT_LEVEL := 14
## The group headings over the panel's two slot rows (겉 / 속).
const FONT_GROUP := 18
