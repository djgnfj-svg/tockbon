class_name Look
extends RefCounted

## Every presentation constant in the game, and nothing outside this file has one.
##
## Scattering these was measured once: a power doubled and nothing changed on screen, because the
## numbers that would have shown it lived in six places and only one of them moved.
##
## Two rules this file exists to keep true, both enforced by net_draw_leaf:
##   - no `Color(` and no `Color.` anywhere outside this file
##   - no literal assigned to a name ending in a presentation suffix outside this file.
##     **The suffix list is not repeated here.** `net_draw_leaf`'s `_literal_hits` owns it, and it
##     grows: writing it out twice means the day it widens one copy starts lying quietly.
##
## EVERY RATIO CARRIES ITS PIXEL VALUE IN THE COMMENT BESIDE IT. A radius of 8 was quoted as "8px"
## in the last game and reached the screen at 38px — a camera and a window stretch in between — and
## the same shape bit four separate times. See lessons-from-two-dead-games, "a constant is not what
## reaches the screen".
##
## Nothing here is `const X := PackedInt32Array([...])`: that form is a parse error on 4.7.1
## ("Assigned value for constant isn't a constant expression"). Plain `const` Arrays are used and
## every read casts, because a `const` Array keeps read-only but loses element typing.


# ---------------------------------------------------------------------------------------------
# Screen and grid — pinned together on purpose
# ---------------------------------------------------------------------------------------------

## EVERY PX IN THIS FILE IS A CANVAS PIXEL, AND THE GLASS IS NOT THE CANVAS.
## An earlier version of this comment said "no camera zoom, no window stretch". **Both halves are now
## false, and on purpose.** `boat-and-landing` grew the grid to 48 x 32 = 1536 tiles (1920 x 1280
## canvas px), deliberately larger than the 1280 x 720 viewport, and gave `field_view` a real zoom —
## see `ZOOM_MIN` / `ZOOM_MAX` / `ZOOM_STEP` below. The stretch half was already false before that:
## project.godot carries `window/stretch/mode="canvas_items"`, so a canvas pixel reaches the screen
## multiplied by `window width / 1280` (1.5x in a 1920 window), and the shell measured that transform
## at 0.05 in a 64px headless window. What survives either multiplier is everything relative —
## ratios, overlaps, and the 2.0 px snap floor, since snapping happens in canvas space BEFORE both.
## What does not survive is any absolute claim about size on the glass — every px comment in this
## file describes canvas space, "at zoom 1.0", unless it says otherwise.
const VIEWPORT_W_PX := 1280.0
const VIEWPORT_H_PX := 720.0
const TILE_PX := 40.0

## ⚠⚠ **THESE ARE A DEFAULT NOW AND NOT THE MAP SIZE.** They were `const 48` / `32` read directly by
## `field_view._draw` and `_clamp_cam`, which made **two maps of different sizes unrepresentable** —
## the blocker `idea-inbox` row 52 names. Both of those now go through `field_view._map_tiles()`, which
## asks `battle.grid`; these two are what that answers with when there is no grid yet (a `FieldView`
## between `_ready` and the first island, and every net that builds one with a bare `Battle`).
## ⚠ **Nothing that draws may read them**, and `islands.gd`'s long map is 144 wide precisely to keep
## that true. They stay at the shipped islands' own size so every camera literal measured against
## 48 x 32 still describes the state `setup()` leaves.
const GRID_W := 48
const GRID_H := 32

## `field_view`'s own `zoom` is a runtime float, not a constant — the wheel changes it. These are its
## bounds. Both ends measured against the 48 x 32 grid:
##   ZOOM_MIN — **0.45, lowered from 0.5625 by `plan-then-watch`** on the user's own sentence
##     「조금 더 카메라를 뒤로 빼야 될」. RE-MEASURED, not adjusted: at 0.5625 the visible world was
##     2275.6 x 1280.0 px against a 1920 x 1280 map, so the island filled the FULL screen height with
##     **zero** vertical margin and `_clamp_cam` had a zero-length range to clamp y into. At 0.45 the
##     visible world is 2844.4 x 1600.0, the island lands on x 208..1072 and y 72..648, and
##     `_clamp_cam` centres BOTH axes. One tile is 18.0 px and the smallest body (ranged, 20 px
##     across) is 9.0 px. Floor 0.40 — below it that body drops under 8 px, which is the row
##     `net_camera` already carries. Ceiling 0.50 — above it the vertical margin disappears again,
##     which is the framing the user asked to move back from.
##     ⚠ Two other constants are derived from this number and BOTH moved with it —
##     `WATER_MARGIN_TILES` and `CLIFF_FACE_WIDTH_PX`. Re-measure the whole set, never the one row
##     being argued about.
##   ZOOM_MAX — at 1.0 one tile is 40 px, today's scale (never zoom IN past that — nothing is gained
##     and it breaks the "island fits on screen" survey read). Ceiling 1.5.
##   ZOOM_STEP — per wheel notch. Above 1.05 or a notch does nothing perceptible; below 1.4 or two
##     notches cross the whole range. ⚠ It is also the mitigation for an 18 px tile being a small drop
##     target: the camera is unrestricted before the commit, so one notch puts a tile at 20.7 px and
##     four at 31.5 px.
const ZOOM_MIN := 0.45
const ZOOM_MAX := 1.0
const ZOOM_STEP := 1.15

## ⚠⚠ **THE WORLD-WIDTH TABLE. Every stroke `field_view` draws is multiplied by `zoom` before it
## reaches the canvas, and an island OPENS at `ZOOM_MIN`** — `field_view.setup` sets it and the whole
## plan is authored there, so `ZOOM_MIN` is the zoom a mark has to be legible at, not an edge case.
##
## The arithmetic: this file's snap floor is **2.0 canvas px** (see the combat-juice banner for why),
## so a WORLD-space width must be **>= 2.0 / 0.45 = 4.45**, and the two constants that already did
## this sum chose **5.0** (= 2.25 px). Every world width in this file is now on one of two sides:
##
##   ABOVE THE FLOOR (5.0 or more)   BODY_OUTLINE · SHOT · BURST · AREA_RING · LAND_RING · ROUTE ·
##                                   CLIFF_FACE · REFUSE_MARK   (BEAK_WIDTH_PX clears it at 8.0)
##   DELIBERATELY BELOW              GRID_LINE · TARGET_LINE · SPARK — each carries its own reason
##                                   on its own line, and the reason is the whole licence
##
## ⚠ **This was a table with one row measured and eleven not.** `REFUSE_MARK_WIDTH_PX` did this sum
## out loud and `CLIFF_FACE_WIDTH_PX` was re-measured 4.0 -> 5.0 when `ZOOM_MIN` fell; `ROUTE_WIDTH_PX`
## was the third row and nobody looked, so the water route the round existed to draw reached the glass
## at **1.35 px**. Re-measure the WHOLE set when `ZOOM_MIN` moves, never the row being argued about.
## `net_draw_leaf` walks the set in one loop and reddens on a `Look.*_WIDTH_PX` name `field_view`
## draws with that this table does not hold — a width added tomorrow lands on one side or reddens.
##
## ⚠ **There is deliberately no `WIDTH_FLOOR` constant here.** 4.45 is one division of two numbers this
## file already holds, and a constant nothing in `src/` reads rots — while a net that read it would be
## deriving its bound from the thing it checks, which is this repo's own named false green. The floor
## is written out as a literal in `net_draw_leaf`, once.

## A faint grid, because in a game where position is the decision an invisible grid means the
## player cannot pick a position. It is drawn low-alpha, not thin-and-bright.
## ⚠ **DELIBERATELY BELOW the world-width floor** (0.45 px at `ZOOM_MIN`) and it stays there. Nothing
## is ever READ off a grid line — every mark the player aims with (the drag candidate ring, the
## refusal mark, the cliff face) is its own mark and all three clear the floor. This is texture, and
## `COL_GRID_LINE` is alpha 0.07 across every tile on the map: at 2.25 px that lattice is louder than
## the terrain under it, which is the opposite of what the sentence above asks for.
const GRID_LINE_WIDTH_PX := 1.0


# ---------------------------------------------------------------------------------------------
# Colours — the only `Color(` literals in the tree
# ---------------------------------------------------------------------------------------------

# Terrain. Three tones plus the harbour marker, and the hole has to read as "cannot walk here" at a
# glance. `boat-and-landing` renamed the dock to a harbour (water a boat sails from, not a fixed
# port) and deleted the `D` legend character; the colour is the same value under its new name.
const COL_WATER := Color(0.086, 0.145, 0.255)
const COL_LAND := Color(0.203, 0.259, 0.184)
const COL_HOLE := Color(0.055, 0.067, 0.078)
const COL_HARBOUR := Color(0.553, 0.443, 0.243)
const COL_GRID_LINE := Color(1.0, 1.0, 1.0, 0.07)

# Cliff and ramp (`boat-and-landing` stage 5, P10). `^` gets its OWN fill now instead of reusing
# COL_HOLE — 3.2 still holds (a cliff is exactly as impassable as a hole), only the picture stops
# saying the two are the same terrain. `COL_CLIFF_FACE` is the seaward-edge line, one tone darker so
# it reads as a drop rather than a second outline. `/` (ramp) is passable land with its own tint so
# the one doorway through a cliff wall does not read as ordinary ground.
const COL_CLIFF := Color(0.098, 0.098, 0.114)
const COL_CLIFF_FACE := Color(0.020, 0.020, 0.027)
const COL_RAMP := Color(0.361, 0.310, 0.235)

# Bodies. Friend and foe are told apart by COLOUR; the unit type is told apart by SIZE and by how
# round its corners are — see BODY_RADIUS_RATIO and BODY_CORNER_RATIO.
const COL_ALLY := Color(0.451, 0.847, 1.0)
const COL_ENEMY := Color(1.0, 0.420, 0.361)
const COL_BEAK := Color(1.0, 0.863, 0.451)

# HP. The old game died partly because nothing on screen ever went down; the empty half is drawn
# so the bar has a length before it is hurt.
const COL_HP_FULL := Color(0.400, 0.898, 0.451)
const COL_HP_EMPTY := Color(0.118, 0.141, 0.141, 0.851)

# Boats. One tone for every hull, because after `plan-then-watch`'s 결정 14R nothing distinguishes
# two boats: a boat exists between one drag and one round trip, and there is no fleet to tell apart.
# ⚠ `COL_BERTH_EMPTY` died with the berths — there is no resource meter to empty, because the boat
# stopped being a resource. The thing that visibly goes down is now the stack of soldiers standing at
# the harbour: every one you drag away leaves its slot empty (`idle_soldier_offset_px`).
const COL_BOAT := Color(0.851, 0.780, 0.600)

# P7 — a boat that has arrived and cannot unload is drawn waiting, blended toward this on a blink
# rather than a flat tint, so a stalled boat never reads as merely "differently coloured."
const COL_HULL_WAIT := Color(1.0, 0.780, 0.302)

# The route line — the harbour-to-landing polyline while a drag is in flight, and the remaining
# water route under a boat that is crossing.
# ⚠ **`COL_SENDABLE` and its `DROP_TINT_ALPHA` are DELETED** (`speed-off-open-landing`, question C:
# 「못내림만 표시하면 됨 ㅇㅇ」). They tinted every sendable tile green from the moment the island
# opened; the screen now marks what is BLOCKED (the cliff faces, and the refusal mark below) and
# nothing else, so a tone with nothing to paint would be a colour that rots.
# ⚠ `COL_DROP_OK` / `COL_DROP_NO` deliberately reuse `COL_WIN` / `COL_LOSE` below — the same
# accept/refuse pair the key boxes already use. One concept, one value.
const COL_ROUTE := Color(0.851, 0.780, 0.600, 0.55)

## **The summonable band** — the ribbon of water a number key makes pressable (`sea-summon`). It is
## BLENDED into the terrain tone inside the existing tile pass rather than painted as a second layer,
## so it costs no extra draw call and "the band was drawn" is measurable as two fills DIFFERING.
##
## ⚠⚠ **The alpha is the load-bearing number and it is a bet.** `PRESS_ALPHA_OFF`'s own paragraph below
## names **0.18** as the measured failure — the drop tint the user read as terrain rather than as a
## mark. 0.35 is that failure doubled. Floor 0.25; ceiling 0.50, over which the sea reads as land and
## the island stops having a shape. Only a look at the real frame settles it.
## Blended into `COL_WATER` (green 0.145) it reaches **green 0.363**, which is what a check reads.
##
## ⚠ **Deliberately NOT `COL_START` / `COL_WIN` / `COL_NODE_CHEST` re-typed.** Those are a press, a
## verdict and a map node; a value shared by two concepts diverges the first time one of them is tuned.
##
## ⚠ **It is an ALLOWLIST and the land's rule is a DENYLIST, and that is not an inconsistency to be
## "fixed".** Measured on all three islands (`sea-summon`, 2.1): water a boat cannot reach the shore
## from is **0 / 0 / 0**, so a sea DENYLIST would draw nothing and refuse nothing. The two answer
## different questions — 「어디에 상륙하나」 stays a denylist, 「어디에 손을 대나」 is a place.
const COL_SUMMON_BAND := Color(0.353, 0.769, 0.475, 0.35)

# HUD and panel.
const COL_HUD_TEXT := Color(0.918, 0.937, 0.961)
const COL_PANEL_BG := Color(0.071, 0.090, 0.122, 0.941)
const COL_BUTTON := Color(0.239, 0.341, 0.459)
const COL_WIN := Color(0.549, 0.949, 0.600)
const COL_LOSE := Color(1.0, 0.451, 0.420)

## `plan-then-watch`'s one surviving new HUD colour. `COL_START` is the one press that ends the
## planning phase, so it is deliberately NOT `COL_BUTTON` — the restart button in the panel is
## `COL_BUTTON`, and one tone answering to two verbs is how a restart gets pressed by someone aiming
## at start.
## ⚠ `COL_SPEED_ON` died with the speed chips (`speed-off-open-landing`, item 1). It marked which
## rung the ladder was sitting on, and with no ladder there is no rung.
const COL_START := Color(0.302, 0.541, 0.404)

## `title-and-map`'s four new colours, and there are only four because the title's own two boxes
## already have tones that mean the right thing.
##
## ⚠ **시작하기 reuses `COL_START` and 종료 reuses `COL_BUTTON`, on purpose.** The rule this file
## already carries — *one rectangle must not answer to two verbs* — has a second half: **the same verb
## keeps the same tone.** 시작하기 and the fight's 시작 button are literally the same verb, so a third
## green would be the same concept under two names.
##
## `COL_SLOT_OFF` is the one tone the title needs that nothing else can stand in for: a slot that does
## not press. It is drawn at `PRESS_ALPHA_OFF` with no border and no hover, and it is deliberately a
## NEUTRAL grey rather than a dimmed `COL_BUTTON` — a dark blue box reads as "a button in shadow".
## ⚠ **It has a SECOND reader now** (`sea-summon`): a summon slot that is unbound, or whose bodies are
## all out, wears the same tone. It is the same claim — *there is a place here and nothing is in it* —
## so it is the same value rather than a second grey.
##
## The three node tones differ in HUE as well as in shape and size, which is the whole point: Slay the
## Spire's map is criticised for symbols that differ in neither, and that is the same failure shape the
## user hit on the plan screen. See `title-and-map`, the map table.
## ⚠ **None of the three is an existing constant re-typed.** They are near-neighbours of `COL_ALLY`,
## `COL_WIN` and `COL_LOSE` in hue and deliberately not equal to them: a node is not a body and not a
## verdict, and a value shared by two concepts diverges the first time one of them is tuned. What is
## pinned is that the three differ from EACH OTHER — 210 deg, 105 deg and 5 deg apart.
const COL_SLOT_OFF := Color(0.420, 0.420, 0.440)
const COL_NODE_FIGHT := Color(0.373, 0.678, 0.941)
const COL_NODE_CHEST := Color(0.545, 0.878, 0.471)
const COL_NODE_BOSS := Color(0.933, 0.322, 0.290)

# Combat juice. Seven, and every one of them is a colour no existing name can stand in for.
# Items 8, 9, 4 and the shake margin deliberately REUSE what is already above — COL_WIN / COL_LOSE,
# COL_BEAK / COL_BUTTON, COL_ALLY / COL_ENEMY, COL_WATER — because the same value under two names
# diverges the first time one of them is tuned.
const COL_FLASH := Color(1.0, 1.0, 1.0)
const COL_SHOT := Color(1.0, 0.925, 0.667)
const COL_AREA_RING := Color(1.0, 0.600, 0.350, 0.55)
const COL_LAND_RING := Color(0.451, 0.847, 1.0, 0.60)
const COL_TARGET_LINE := Color(1.0, 0.420, 0.361, 0.12)

## The hit spark. ONE colour, tied to neither side: a hit is an event, not a faction, and a contact
## point is by definition where two factions meet — there is no side whose colour is the right one.
const COL_SPARK := Color(1.0, 0.855, 0.600)

## The filled halo under a body that was just hit. **This is not COL_FLASH reused, and the difference
## is the alpha.** COL_FLASH is mixed INTO an opaque body colour; mixing a 0.35-alpha white would
## quietly turn HIT_FLASH_STRENGTH 0.70 into 0.245. Two concepts, so two constants.
## The alpha is also load-bearing for the spark: 0.35 white composited over COL_LAND (luma 0.242)
## gives luma 0.507, and COL_SPARK's luma is 0.867, so the shards read against the halo with a
## contrast of 0.36 (Rec.709 0.2126R + 0.7152G + 0.0722B). Raise this alpha and the spark — whose
## entire case for existing is that it is legible on top of this circle — stops being legible.
const COL_HIT_HALO := Color(1.0, 1.0, 1.0, 0.35)


# ---------------------------------------------------------------------------------------------
# Bodies — an outline, a centre dot, nothing between
# ---------------------------------------------------------------------------------------------

## Indexed by the unit type id in rules.gd: 0 CELL_MELEE, 1 CELL_RANGED, 2 BISON, 3 CROW, 4 LION.
## Radius as a fraction of one tile. AT TILE_PX = 40 THESE ARE, IN ORDER:
##   0 CELL_MELEE  0.35 -> 14.0 px
##   1 CELL_RANGED 0.28 -> 11.2 px
##   2 BISON       0.40 -> 16.0 px
##   3 CROW        0.25 -> 10.0 px
##   4 LION        0.55 -> 22.0 px
## Nothing here changes what happens, which is why body size is in this file and not in rules.gd.
const BODY_RADIUS_RATIO := [0.35, 0.28, 0.40, 0.25, 0.55]

## Corner rounding as a fraction of that body's own radius — this is the "shape" half of telling
## types apart. Melee and the lion are boxy, ranged and the crow are nearly circles.
## AT THE RADII ABOVE: 3.50 px, 9.52 px, 4.80 px, 9.00 px, 4.40 px.
const BODY_CORNER_RATIO := [0.25, 0.85, 0.30, 0.90, 0.20]

## ⚠ **RAISED 2.0 -> 5.0 by the world-width table above, and this is the row that moves the most
## picture.** A body IS its outline here — `_paint_body` draws a rounded-square polyline plus a 3 px
## dot and nothing else — and the whole fight is WATCHED at `ZOOM_MIN`, where 2.0 reached the glass at
## **0.90 px**. That is the same finding `COL_HIT_HALO`'s comment already carries one step short of
## the conclusion ("a body here is a 2 px outline plus a 3 px dot, so a tint has no AREA to paint").
## Ceiling 5.0, and it is arithmetic rather than taste: the smallest body is the crow at
## `0.25 * 40 = 10.0 px` radius, and a stroke wider than half that radius closes the shape into a
## solid blob at zoom 1.0 as well as at `ZOOM_MIN`.
## ⚠ It is also the hull outline (`_paint_hull`) and the harbour marker (`_paint_dock`), both of which
## are drawn on rectangles 40 px and wider — neither of them is what bounds this number.
const BODY_OUTLINE_WIDTH_PX := 5.0
const BODY_DOT_RADIUS_PX := 3.0

## The beak is a triangle poking OUT past the outline, so it reads at a glance which soldier is
## carrying it. Length is measured from the body edge outward, not from the centre.
const BEAK_LENGTH_PX := 9.0
const BEAK_WIDTH_PX := 8.0

## A thin bar under the body. GAP is from the bottom of the body to the top of the bar.
const HP_BAR_W_PX := 24.0
const HP_BAR_H_PX := 3.0
const HP_BAR_GAP_PX := 4.0

## The hull. **Every hull is the same size now**, because `plan-then-watch`'s 결정 14R deleted the
## capacity column: one drag makes one boat and it carries the one soldier that was dragged onto it.
## `_hull_rect` (field_view.gd) computes `BOAT_SLOT_PX + 2 * BOAT_HULL_PAD_PX` = **46 px** wide.
## ⚠ **The old 124 / 72 px arithmetic is gone with the axis it measured**, and so is
## `HULL_BERTH_OFFSET_PX`: two hulls never share a harbour ANCHOR any more, because a boat is only
## drawn once the plan is committed and it is moving from the first sub-step.
const BOAT_SLOT_PX := 26.0            # >= 24 (a 14 px melee body plus air); <= 40 (or one hull is
                                      # wider than 1.5 tiles and reads as terrain)
const BOAT_HULL_PAD_PX := 10.0        # >= 4 (a visible gunwale); <= 20
const BOAT_HULL_H_PX := 56.0          # > 40, taller than a tile (decided #8); <= 80


# ---------------------------------------------------------------------------------------------
# HUD — laid out in absolute viewport pixels
# ---------------------------------------------------------------------------------------------

## ⚠ **Both sizes were raised by `plan-then-watch` and the reason is the user's own sentence**:
## 「글자가 너무 많고 조금 더 단순하게 해줄래? 아니면 좀 UI를 크게 해서」. The answer was BOTH halves —
## the screen dropped from six text items to three during a fight, and what is left is drawn bigger.
const HUD_FONT_SIZE_PX := 22          # > 16 (unreadable against terrain at this contrast); <= 26 or
                                      # 「적 %d」 runs off the right margin at 1060
const HUD_TIMER_FONT_SIZE_PX := 30    # > HUD_FONT_SIZE_PX, or the clock stops being the loudest
                                      # thing on screen; <= 36 or it collides with the enemy count
const HUD_MARGIN_PX := 12.0

## Remaining time, top centre. The label is 「시간 %.1f」 and NOT 「남은 시간 %.1f」 — one word instead
## of two, same meaning, and the word count is what the user asked to cut.
const HUD_TIMER_POS_PX := Vector2(600.0, 38.0)

## ⚠ **The berth boxes and the 1/2 key boxes are DELETED, not moved.** Thirteen constants went with
## them (`HUD_BERTH_*`, `berth_rect_px`, `HUD_KEY_*`, `key_rect_px`, `HULL_BERTH_OFFSET_PX`,
## `COL_BERTH_EMPTY`, `BERTH_FX_SEC`) because `plan-then-watch` deleted the two things they drew: the
## fleet as a resource, and the keyboard as the way soldiers reach the island.
## ⚠⚠ **THE SECOND HALF OF THAT IS NO LONGER TRUE, and the user is the one who corrected it**
## (*"정확히는 배 속이 별로여서 뺀거임 1~5번키"* — the keys came out because of what was IN the boat, not
## because a key is the wrong door). `sea-summon` brings 1~5 back as an ARM, not as a spawn: the key
## picks which slot, and the press on the water is what places. The berths stay dead — there is still
## no fleet to meter. `HUD_SLOT_*` below is what the keys draw now, and it is a new block rather than
## `HUD_KEY_*` restored, because a box that arms and a box that spawns are not the same widget.

## **The start button** — one large press, bottom LEFT, and the whole of the planning phase ends on
## it. It is drawn only while `battle.committed()` is false: a button that cannot be pressed and is
## still on screen is the 「well, while we're stopped…」 door the design closes on purpose.
## ⚠ **Bottom-left is not taste, and its old argument is now HALF FALSE.** It read: at `ZOOM_MIN` the
## island occupies x 208..1072 and the speed chips take the bottom RIGHT, so the bottom-centre band —
## where all three islands put `start_harbour`, and therefore where the army you drag is standing — is
## left clear by layout. **`speed-off-open-landing` deleted the chips, so nothing holds the bottom
## right any more.** What survives is the half that was load-bearing: the button must not sit over the
## bottom-centre band where the draggable army stands, and bottom-LEFT is the corner that clears it.
## The bottom right is now empty on purpose — the whole HUD during a fight is the clock, the enemy
## count and this one button, and a widget added to fill the gap would be one more thing to explain.
const HUD_START_ORIGIN_PX := Vector2(24.0, 632.0)   # y >= 560 (or it floats in the middle of the
                                      # island); y + HUD_START_SIZE_PX.y <= 720
const HUD_START_SIZE_PX := Vector2(220.0, 64.0)     # strictly larger on BOTH axes than the key box
                                      # it replaces (150 x 26); <= (320, 96), which keeps it inside
                                      # the left half and clear of the bottom-centre army stack
const HUD_START_TEXT_OFFSET_PX := Vector2(70.0, 42.0)   # > (0, HUD_START_FONT_SIZE_PX) — a glyph at
                                      # the rect's own origin is a glyph that was never placed, and
                                      # that floor is the half proving the label exists at all;
                                      # x + label width <= 220 and y <= 64
const HUD_START_FONT_SIZE_PX := 28    # > HUD_FONT_SIZE_PX; <= HUD_TIMER_FONT_SIZE_PX + 8

## **The five summon slots, bottom right** (`sea-summon`). A number key arms one and a press on the
## green band puts a body of that slot's type on a boat there. They are drawn only while
## `battle.committed()` is false, exactly like the start button above.
##
## ⚠ **The bottom right stopped being empty.** `HUD_START_ORIGIN_PX`'s paragraph says it went empty
## when the speed chips died and that a widget added to fill it would be one more thing to explain —
## **that is still the standing objection and this row is the exception the user asked for by number**
## (「이 삼 사 오에 내가 만든 세포 끼워 놓고 일 번 누르고」). What the old argument was actually
## protecting is untouched: the bottom-CENTRE band, where all three islands put `start_harbour` and
## therefore where the draggable army stands. Measured clear — the stack reaches screen x ≈ 597..701
## at `ZOOM_MIN` and these boxes start at 956.
##
## ⚠ **The slot boxes are NOT clickable**: no hover, no press dip, no hit rect. This file's rule
## 「one rectangle must not answer to two verbs」 does not bite an armed box being green, because that
## rule is about a press landing on the wrong thing. 설정하기 set the precedent — *a slot drawn as
## unpressable behaves as unpressable, and those two are the same claim.*
const HUD_SLOT_ORIGIN_PX := Vector2(956.0, 632.0)   # **Measured, not chosen.** 956 + 5*56 + 4*8 =
                                      # 1268 = 1280 - HUD_MARGIN_PX, so the row ends on the same right
                                      # margin every other HUD item does; y shares HUD_START_ORIGIN_PX's
                                      # own 632 so the two bottom widgets sit on one baseline, and
                                      # 632 + 64 = 696 <= 720
const HUD_SLOT_SIZE_PX := Vector2(56.0, 64.0)       # y equals HUD_START_SIZE_PX.y — no new press
                                      # height enters the game. x >= 44 or a 34 px digit plus the bar's
                                      # two 6 px insets does not fit; x <= 72 or five boxes run past 1268
const HUD_SLOT_GAP_PX := 8.0          # >= 6 or two boxes read as one bar; <= 14, from the width sum
const HUD_SLOT_FONT_SIZE_PX := 34     # ⚠ **> HUD_TIMER_FONT_SIZE_PX 30 is REFUSED** — the clock must
                                      # stay the loudest thing on this screen. >= 28
                                      # (HUD_START_FONT_SIZE_PX, the smallest glyph that has ever read
                                      # on this HUD); <= 40 or a digit fills its box
const HUD_SLOT_TEXT_OFFSET_PX := Vector2(20.0, 44.0)  # > (0, 0) — a glyph at the rect's own origin is
                                      # a glyph that was never placed, and that floor is the half
                                      # proving the label exists. 20 + ~20 <= 56 across;
                                      # 44 <= 64 - 8 - 6 = 50 down, so the digit clears the bar
const HUD_SLOT_BAR_INSET_PX := 6.0    # >= 4 (a visible margin); <= 16, or the bar is under 24 px and
                                      # one notch of a twelve-body roster drops under the 2.0 px floor
const HUD_SLOT_BAR_H_PX := 8.0        # >= 2.0 (snap floor — this is HUD space with no zoom under it);
                                      # <= 14 or the bar competes with the digit
const HUD_SLOT_BAR_BOTTOM_PX := 6.0   # >= 4; <= 20, from the text offset sum above

## **How often a held summon puts out one more body.** `sea-summon`, 2.4.
##
## ⚠⚠ **It is a LOOK constant because this build presses BEFORE the start button** — it is the repeat
## rate of an input, and a player holding at 0.50 s reaches the same committed plan as one holding at
## 0.05 s. **`sea-summon`'s OPEN question 1 is unanswered**, and on the other answer (the press happens
## DURING the fight) this moves to `rules.gd`: reinforcement spacing changes what happens. That is
## seam #3 of the four the design names, and it is left visible on purpose.
##
## The roster is 10 at the start of a run and at most 19, so a full hold is **2.0 s** and **3.8 s**.
## Floor 0.084 — five rendered frames at 60 fps, the beat this repo has measured going entirely unseen.
## Ceiling 0.50 — the probe's figure for the drag this replaces is 0.6–1.0 s a drag, so at 0.50 the
## hold is no faster than the gesture it exists to delete.
const SLOT_HOLD_SEC := 0.20

## ⚠ **The five speed chips are DELETED** (`speed-off-open-landing`, item 1, on the user's own
## 「일단 배속 개념은 지워주고」 and 「일시정지 지워주고」). Five constants went with them —
## `HUD_SPEED_ORIGIN_PX`, `HUD_SPEED_SIZE_PX`, `HUD_SPEED_GAP_PX`, `HUD_SPEED_TEXT_OFFSET_PX` and
## `speed_rect_px()` — plus `COL_SPEED_ON` up in the colours block. `Rules.SPEED_STEPS` survives, read
## by nothing, and its own comment says why.

## Enemies left, top right. It has to survive onto the lose screen — the player must be able to
## see WHY they lost, and "the timer ran out with four alive" is a different loss to a wipe.
const HUD_ENEMIES_LEFT_POS_PX := Vector2(1060.0, 38.0)

## **The army standing at the harbour, before anything is sent** (`plan-then-watch`, P4) — this is
## what the player drags, and it is drawn ON THE MAP rather than in a HUD strip because the user's
## sentence is 「내가 내릴 수 있는 곳 위치에 딱 나서 … 끌어서 탁 놓으면」. Drawing it in a strip as well
## would be the same fact under two names, which this file's own header forbids.
##
## The offsets are from the START HARBOUR's tile centre and they go UP, because a harbour sits on the
## bottom row of all three islands and below it is off-map. Slot index is the SOLDIER ID, so a
## soldier you drag away leaves its slot empty and the stack visibly shortens as the plan fills —
## that is the "something on screen goes down" the last game died for the want of.
## Geometry check with 13 soldiers: 7 columns spanning 6 * 34 = 204 px, centred by an origin.x of
## -102, two rows at y -48 and -82. Against a start harbour at (24, 31) that is world x 878..1082,
## y 1178..1212 — inside the 1920 x 1280 map with a body radius to spare.
const IDLE_SOLDIER_PITCH_PX := 34.0   # >= 30 (a melee body is 0.35 * 40 * 2 = 28 px across, so
                                      # anything smaller overlaps its neighbour); <= 48 or seven
                                      # across is seven tiles wide and covers the harbour approach
const IDLE_SOLDIER_COLS := 7          # >= 5 — thirteen soldiers in fewer than five columns is three
                                      # rows and the stack walks off the bottom edge; <= 9 or the row
                                      # is wider than eight tiles and reaches the neighbouring coast
const IDLE_SOLDIER_ORIGIN_PX := Vector2(-102.0, -48.0)  # y <= -40, the stack sits ABOVE the harbour;
                                      # abs(x) and abs(y) <= 3 * TILE_PX or it stops reading as *at*
                                      # the harbour at all

## **The ghost of a soldier that has been sent but has not left yet** (P7), drawn at its LANDING and
## fanned by its index in `battle.boats` — which is the drop order. That fan is the only picture the
## order gets, and it is the only claim the order can carry: with unlimited boats every one of them
## departs on the commit frame, so 「어느 순서로」 decides FORMATION and nothing else.
## ⚠ A ghost gets no colour of its own. It is `COL_ALLY` at `GHOST_ALPHA`, through `ghost_tint()`.
const GHOST_FAN_PX := Vector2(9.0, 9.0)  # >= (6, 6) or two ghosts are one blob and the drop order
                                      # has no picture at all; <= (14, 14) or thirteen ghosts span
                                      # 168 px = 4 tiles and stop reading as ONE landing
const GHOST_ALPHA := 0.55             # >= 0.35 — dimmer than that and the plan is invisible, which
                                      # deletes this design's stated survival condition; <= 0.75 or
                                      # a ghost is indistinguishable from a soldier already ashore


# ---------------------------------------------------------------------------------------------
# Panel — reward pick, win, lose, restart
# ---------------------------------------------------------------------------------------------

## Centred: (1280 - 560) / 2 = 360, (720 - 480) / 2 = 120.
##
## ⚠ **The panel grew 400 -> 480 px tall with the node map, and it is not taste.** A route through
## `Rules.MAP_NODES` can step on `map_max_count_nodes_on_a_route()` = 3 count nodes, so the roster
## reaches `10 + 3 * 3 = 19` soldiers against a capacity that used to be 14. `panel_view.roster_ids`
## caps at `roster_capacity()` and drops the rest **silently**, so the overflow would have been five
## soldiers the player can see nowhere and can never give the beak to.
## Height check: `72 + 10 * (28 + 6) = 412 <= 480` and `420 + 48 = 468 <= 480`.
const PANEL_ORIGIN_PX := Vector2(360.0, 120.0)
const PANEL_SIZE_PX := Vector2(560.0, 480.0)

const PANEL_TITLE_OFFSET_PX := Vector2(40.0, 44.0)
const PANEL_TITLE_FONT_SIZE_PX := 28
const PANEL_BODY_FONT_SIZE_PX := 18

## The roster the player clicks to bolt the beak on. Two columns of **ten** = 20 slots, against a run
## that can now field 19 soldiers (see PANEL_SIZE_PX above), so no entry is ever off the panel.
## Width check: 40 + 240 + 24 + 240 = 544 <= 560. Height check: 72 + 10 * (28 + 6) = 412 <= 480.
const ROSTER_ORIGIN_OFFSET_PX := Vector2(40.0, 72.0)
const ROSTER_ENTRY_SIZE_PX := Vector2(240.0, 28.0)
const ROSTER_ENTRY_GAP_PX := 6.0
const ROSTER_COLUMN_GAP_PX := 24.0
const ROSTER_COLUMNS := 2
const ROSTER_ROWS := 10
const ROSTER_TEXT_OFFSET_PX := Vector2(8.0, 20.0)

## The restart / continue button. 420 + 48 = 468 <= 480, so it clears the roster block above it.
const BUTTON_OFFSET_PX := Vector2(180.0, 420.0)
const BUTTON_SIZE_PX := Vector2(200.0, 48.0)
const BUTTON_TEXT_OFFSET_PX := Vector2(24.0, 32.0)


# ---------------------------------------------------------------------------------------------
# Pressable things — the set BOTH new screens share
# ---------------------------------------------------------------------------------------------

## ⚠ **This block exists because the last round failed on contact with a human.** The plan screen
## shipped with a 10 px drag source and a drop zone at alpha 0.18, and the user could not work out how
## to operate it at all (「뭐 어떻게 동작시키는지 전혀모르겠는데?」). So what is pressable now says so
## with a SET of signals rather than one: size, a border, a hover that answers, and a press that dips.
##
## The numbers are shared by the title and the map on purpose. Two screens with two different "this
## presses" vocabularies is two things to learn, and neither of them is the game.

## How far outside its drawn edge a press still lands. Floor 4 — a slightly-off aim must still count;
## ceiling 11 — the title's slot pitch is `88 + 24 = 112`, so a hit height of `88 + 2p` has to stay
## under 112 and `p < 12`.
const PRESS_HIT_PAD_PX := 8.0

## The alpha pair, and **the RATIO is the rule rather than either absolute**: 1.0 / 0.30 = 3.3x.
## `PRESS_ALPHA_OFF` floor 0.20 — under it a disabled thing is invisible rather than disabled, which
## is a different sentence; ceiling 0.45 — over it, it stops reading as disabled at all. The failure
## this pair is measured against is the drop tint at **0.18**, which the user read as terrain.
const PRESS_ALPHA_ON := 1.0
const PRESS_ALPHA_OFF := 0.30

## The border is the "it presses" mark, and the pair is **a RESTING border and a LIVE one** — the
## hover is one instance of live and the armed summon slot is the other. (It read "the hover is the
## border getting thicker" until `sea-summon` gave the pair a second reader; the pair is unchanged and
## only the sentence widened, in the file that makes the claim.)
## ⚠ `PRESS_HOVER_BORDER_WIDTH_PX` must exceed `PRESS_BORDER_WIDTH_PX` by more than 2.0 — this file's
## snap floor — or the live state changes nothing that reaches the screen. 3 -> 6 is a delta of 3.
const PRESS_BORDER_WIDTH_PX := 3.0        # >= 2.0 (snap floor); <= 5
const PRESS_HOVER_BORDER_WIDTH_PX := 6.0  # > PRESS_BORDER_WIDTH_PX + 2; <= 10
const PRESS_HOVER_BRIGHTEN := 0.12        # >= 0.08; <= 0.25, over which the hover reads as a
                                          # different colour rather than the same thing lit

## ⚠ **0.10 and not 0.08.** The design's first draft wrote 0.08 and, in the same file, wrote that every
## duration exceeds the five-frame floor of 0.084 s. Two sentences that kill each other; the number was
## RAISED rather than the sentence deleted. Ceiling 0.20, over which the hover lags the cursor.
const PRESS_HOVER_SEC := 0.10

## The press dip. Swink's Game Feel puts input-to-response under 100 ms, which is why it is this short.
## `PRESS_DOWN_SCALE` ceiling 0.98 — at a 360 px slot 0.98 is a 7.2 px inset and 0.99 is 3.6 px, which
## reads as a wobble rather than a press; floor 0.92 or the slot visibly shrinks.
const PRESS_DOWN_SEC := 0.10              # >= 0.084 (five frames); <= 0.15
const PRESS_DOWN_SCALE := 0.96
const PRESS_DOWN_DIM := 0.15              # >= 0.10; <= 0.30

## The scene change into the map: it arrives out of the background colour instead of cutting.
## Floor 0.20 — under it the fade reads as the hard cut it exists to remove; ceiling 0.60 or leaving
## the title feels slow.
const SCENE_FADE_SEC := 0.35


# ---------------------------------------------------------------------------------------------
# The title screen
# ---------------------------------------------------------------------------------------------

## The name, top left of centre. y floor 120 — a 72 px glyph needs its own height above the baseline;
## y ceiling 280 or it collides with the slot block starting at 340.
const TITLE_TEXT_POS_PX := Vector2(400.0, 200.0)

## ⚠ **Larger than `TITLE_SLOT_FONT_SIZE_PX` by more than 16**, or the title stops being the loudest
## thing on its own screen. Ceiling 96.
const TITLE_FONT_SIZE_PX := 72

## The three slots, stacked. x is `(1280 - 360) / 2 = 460` exactly; y ceiling 408, from
## `y + 3 * 88 + 2 * 24 <= 720`. At 340 the block ends at 652 and the padded hit box at 660.
const TITLE_SLOT_ORIGIN_PX := Vector2(460.0, 340.0)

## ⚠ **Floor (220, 64) — the largest press in the game today (`HUD_START_SIZE_PX`), and no new press
## is allowed to be smaller than the biggest one that already exists.** Ceiling (480, 120).
const TITLE_SLOT_SIZE_PX := Vector2(360.0, 88.0)
const TITLE_SLOT_GAP_PX := 24.0           # >= 12 or two slots read as one bar; <= 44 (from the origin
                                          # arithmetic above)

## ⚠ **> `HUD_TIMER_FONT_SIZE_PX` 30, which is today's largest glyph** — the design's first draft said
## the largest was the start button's 28 and was simply wrong. Ceiling 56, or 「시작하기」 at roughly
## 0.6 em a glyph overruns 360 px.
const TITLE_SLOT_FONT_SIZE_PX := 40

## ⚠ **Floor `> (0, TITLE_SLOT_FONT_SIZE_PX)`**: a glyph drawn at the rect's own origin is a glyph that
## was never placed, and that floor is the half of the check proving the label exists at all.
## `96 + ~200 = 296 <= 360` across, `58 <= 88` down.
const TITLE_SLOT_TEXT_OFFSET_PX := Vector2(96.0, 58.0)

## The background: cells drifting behind the menu, drawn by code. **No image file** — see the decision
## "the body is a line drawn by code", which forbids a sprite here as much as in the fight.
## ⚠ **The drift is `sin`/`cos` of the index and the age, with NO RNG**, the same reason `SHAKE_A_FREQ`
## is a constant: a random drift cannot be measured, and this repo has already paid for that once.
## The two frequencies are coprime-ish so nine cells do not march in step.
const TITLE_CELL_COUNT := 9               # >= 5, under which the background is three dots rather than
                                          # a drift; <= 16 or it competes with the slots
const TITLE_CELL_RADIUS_PX := 14.0        # >= 8; <= 24
const TITLE_CELL_SPEED_PX := 8.0          # px/s. >= 3 — under it nothing visibly moves over a title's
                                          # dwell; <= 20 or it reads as gameplay
const TITLE_CELL_ALPHA := 0.14            # >= 0.06 or there is no background at all; <= 0.30 or it
                                          # ties `PRESS_ALPHA_OFF` and a drifting cell reads as a
                                          # disabled button
const TITLE_CELL_A_FREQ := 0.13
const TITLE_CELL_B_FREQ := 0.19


# ---------------------------------------------------------------------------------------------
# The node map — EVERY KNOB THIS SCREEN HAS IS BETWEEN HERE AND THE NEXT BANNER
# ---------------------------------------------------------------------------------------------
#
# Written to be changed by hand, one number at a time, without reading any other file. Six groups,
# in the order you would tune them:
#
#   1. WHERE THE SEVEN CIRCLES SIT   MAP_NODE_POS_PX
#   2. HOW BIG THEY ARE              MAP_NODE_R_PX · MAP_BOSS_R_PX
#   3. WHICH OF THE FOUR STATES      MAP_NODE_PAST_SCALE · MAP_NODE_LOCKED_SCALE
#      A CIRCLE IS IN                MAP_NODE_PAST_ALPHA   (+ PRESS_ALPHA_ON / _OFF, shared with
#                                    the title screen, in the "Pressable things" block above)
#   4. THE LINES BETWEEN THEM        MAP_LINE_*
#   5. THE MARKS ON TOP              MAP_HERE_RING_* · MAP_BOSS_RING_* · MAP_GLYPH_* · MAP_PULSE_*
#   6. THE BEATS (how long each      MAP_NODE_FADE_SEC · MAP_REVEAL_STEP_SEC · MAP_TRAVEL_SEC ·
#      little animation takes)       MAP_CLEAR_FILL_SEC · MAP_HEAL_SEC
#
# ⚠ **The three node COLOURS are not here** — `COL_NODE_FIGHT` / `COL_NODE_CHEST` / `COL_NODE_BOSS`
# live in the colours block near the top of this file, with every other colour in the game. One
# concept, one place: a colour written in two blocks is a colour that diverges.
#
# ⚠ **A node is drawn in one of FOUR states, and every number in group 3 belongs to exactly one of
# them.** The state machine itself is `map_view._look_of` and there is no second copy of it:
#
#   HERE    the node the army is standing on — full radius, full colour, wrapped by the here ring
#   OPEN    a node the army may step onto next — full radius, full colour, white border, pulsing
#   PAST    walked and finished with — MAP_NODE_PAST_SCALE radius, MAP_NODE_PAST_ALPHA
#   LOCKED  not reachable from where the army stands — MAP_NODE_LOCKED_SCALE radius, no colour at
#           all (`dimmed`), PRESS_ALPHA_OFF
#
# The four are told apart by SIZE, by BRIGHTNESS and by what is drawn on top — three channels, so
# no one of them is carrying the read alone and a colour-blind player loses none of it. That is the
# whole of the fix the user asked for with 「현재 위치 제대로 표현해야 되고」.

## One centre per node, indexed by the node id in `Rules.MAP_NODES`. **Absolute viewport pixels.**
##
## ⚠ **The vertical arithmetic is what killed the previous draft's "160 px apart" rule**: five floors
## at 160 px is 640 px of gaps, plus the boss's 56 and the bottom ring's 52 = 748 px against a 720 px
## screen. The real minimum is **120 px**, because two hit circles are `48 + 48 = 96` across.
## Margins, against the literals 1280 x 720: bottom `620 + 52 = 672`; top `110 - 64 = 46`;
## sides `470 - 48 = 422` and `810 + 48 = 858`.
##
## A `const` Array of `Vector2` literals — **measured on 4.7.1 before it was written**, because the
## packed form is a parse error and this repo has been bitten by the const-expression rules twice.
## It is read-only with no element typing, so `map_node_pos_px` casts.
const MAP_NODE_POS_PX := [
	Vector2(640.0, 620.0), Vector2(470.0, 500.0), Vector2(810.0, 500.0),
	Vector2(470.0, 380.0), Vector2(810.0, 380.0), Vector2(640.0, 250.0),
	Vector2(640.0, 110.0),
]

## Drawn radii, and they are the radius of a node in its BIGGEST state (HERE or OPEN). The two
## scales below shrink it for the other two. The boss is the biggest thing on the map by construction.
const MAP_NODE_R_PX := 40.0               # >= 28, under which a glyph inside the node draws at under
                                          # 2 px strokes; <= 52, since 2 * 52 = 104 against a 120 px
                                          # vertical gap leaves 16 px and two nodes touch
const MAP_BOSS_R_PX := 56.0               # > MAP_NODE_R_PX; <= 70, from 56 + 48 = 104 < 140

## **Size is the second channel that says which of the four states a node is in**, and it is a
## channel on purpose: brightness alone is one signal, and one signal is what the user could not
## read at rest. Both are FRACTIONS of the radius above — HERE and OPEN have no entry here because
## they are drawn at the full radius, which is what keeps `map_node_hit_radius_px` a single number.
##
## AT MAP_NODE_R_PX = 40 THESE ARE 34.4 px AND 30.0 px, against 40.0 px for a node on offer.
## At MAP_BOSS_R_PX = 56 they are 48.2 px and 42.0 px.
##
##   MAP_NODE_PAST_SCALE   raise it toward 1.0 and a node you have already walked stops being
##                         distinguishable from one you may walk next; drop it toward the locked
##                         scale and "walked" and "cannot reach" become one picture.
##   MAP_NODE_LOCKED_SCALE raise it and the map flattens into seven identical circles — the defect
##                         this pair exists to remove; drop it and a locked node is a dot whose
##                         glyph no longer fits inside it (the glyph does NOT shrink with the node,
##                         deliberately: a reward you cannot reach yet is still a reward you have to
##                         be able to read, because reading it is how you choose the route).
const MAP_NODE_PAST_SCALE := 0.86         # > MAP_NODE_LOCKED_SCALE + 0.08; <= 0.94
const MAP_NODE_LOCKED_SCALE := 0.75       # >= 0.62 — under it the widest glyph (1.08 x
                                          # MAP_GLYPH_R_PX = 22.7 px) no longer fits inside
                                          # 40 x scale; <= 0.86, or the size channel says nothing

## **Brightness is the third channel.** A walked node keeps its HUE — you must be able to see what
## the place you came through was — and sits between a node on offer (`PRESS_ALPHA_ON`, 1.0) and one
## out of reach (`PRESS_ALPHA_OFF`, 0.30, and with its colour taken away entirely by `dimmed`).
const MAP_NODE_PAST_ALPHA := 0.62         # >= 0.45, or a walked node is confused with a locked one;
                                          # <= 0.85, or it is confused with a node on offer

## **The you-are-here ring — this is the mark that answers 「지금 내가 어디 있나」.** It has to sit
## OUTSIDE the node it marks or it hides inside it, and it is the only closed ring on the screen that
## is not part of the boss, which is what makes it unambiguous rather than merely visible.
## ⚠ Before the first node is entered there is no ring at all, and that is correct: the army has not
## landed anywhere yet, and a ring drawn then would say "you are here" about a place you are not.
const MAP_HERE_RING_R_PX := 52.0          # > MAP_NODE_R_PX; <= 68, from 68 + 48 = 116 < 120
const MAP_HERE_RING_WIDTH_PX := 6.0       # >= 4 — at 2 px this ring is a hairline and the one thing
                                          # on screen saying where you are stops carrying; <= 8, over
                                          # which it swallows the node it is meant to point at

## The boss's nested inner rings. ⚠ **Its own constant and NOT `MAP_HERE_RING_WIDTH_PX` reused.**
## They were one number until this round, so thickening the you-are-here ring silently thickened the
## boss as well — two concepts sharing a knob is exactly what stops a person tuning either.
const MAP_BOSS_RING_WIDTH_PX := 5.0       # >= 2.0 (snap floor); <= MAP_BOSS_RING_STEP_PX - 4, or two
                                          # neighbouring rings' strokes touch and read as one band

## How many straight segments a drawn circle is built from. One number for the ring, the node outlines
## and the boss's nested rings, so a circle cannot be smooth in one place and faceted in another.
const MAP_RING_SEGMENTS := 32             # >= 16, under which a 56 px circle visibly has corners;
                                          # <= 64, over which the outlines cost more than they show

## The three line weights, and they are three because a line says one of three things: walked,
## choosable, neither. **Travelled must be thicker than choosable and choosable than dim**, each by
## more than the 2.0 px snap floor, or two of the three are the same picture.
##
## ⚠ **PAST WAS 8.0 AND THE SENTENCE ABOVE WAS FALSE OF IT.** `8 - 6 = 2` is the snap floor exactly,
## not more than it, and its own inline comment said only `> MAP_LINE_OPEN_WIDTH_PX` while its
## sibling one line down said `+ 2` — the fix applied to one value and not to the other, which is
## this repo's own named shape. Measured on the shipped frame before it moved: three pale lines and
## no way to say which was the road taken. At 9.0 both steps are 3.0 px.
const MAP_LINE_PAST_WIDTH_PX := 9.0       # > MAP_LINE_OPEN_WIDTH_PX + 2; <= 12
const MAP_LINE_OPEN_WIDTH_PX := 6.0       # > MAP_LINE_DIM_WIDTH_PX + 2; <= 8
const MAP_LINE_DIM_WIDTH_PX := 3.0        # >= 2.0; <= 4

## The same three, on the brightness channel. Ordered the same way and for the same reason: the
## width ladder carries most of the read, and these must never invert it.
const MAP_LINE_PAST_ALPHA := 1.0          # >= MAP_LINE_OPEN_ALPHA; <= 1.0
const MAP_LINE_OPEN_ALPHA := 0.9          # > MAP_LINE_DIM_ALPHA + 0.3; <= MAP_LINE_PAST_ALPHA
const MAP_LINE_DIM_ALPHA := 0.25          # >= 0.15, under which the unwalked map is invisible and
                                          # "the whole map is always visible" dies; <= 0.45

## The pulse on a node you may step onto. On an otherwise still screen it is the ONLY motion saying
## "here", which is why it is pinned at both ends: it is never zero, and it never exceeds its radius.
## ⚠ Xbox Accessibility Guideline 118 forbids flashing above roughly 3 per second; this is 1.1/s.
const MAP_PULSE_SEC := 0.9                # >= 0.5 or it flickers; <= 1.4 or it is not read as motion
const MAP_PULSE_R_PX := 4.0               # >= 2.0 (snap floor), and +-4 on a 40 px radius is 10%, the
                                          # smallest change that reads; <= 8 or a pulsing node reaches
                                          # its neighbour's hit circle

## The reveal, floor by floor from the bottom. **This is what teaches the map's direction**, and it is
## what the design uses INSTEAD of a sentence on screen.
## ⚠⚠ `MAP_REVEAL_STEP_SEC` is deliberately BELOW the five-frame floor and it is not an oversight: it
## is the offset BETWEEN beats, not a beat. The beat is `MAP_NODE_FADE_SEC`, and that one is above the
## floor. Total `0.06 * 4 + 0.18 = 0.42 s`.
const MAP_NODE_FADE_SEC := 0.18           # >= 0.084 (five frames); <= 0.40
const MAP_REVEAL_STEP_SEC := 0.06         # >= 0.03, under which seven nodes appear in 0.21 s and the
                                          # direction is not taught; <= 0.12 or the reveal is a wait

## The ring walking the edge to the node just chosen, before the island opens.
## ⚠ **Cut straight to the island and the map's work is invisible** — the travel IS the progress
## readout, and the shell holds for exactly this long so that it plays.
const MAP_TRAVEL_SEC := 0.45              # >= 0.25 or the ring teleports; <= 0.70 or it is a wait

## The node just won filling in, and the army's 「힘」 number climbing after a chest.
## ⚠ `MAP_HEAL_SEC`'s floor is 0.30 because the number has to be WATCHED climbing: a chest is the only
## node in this round that changes state without a fight, so without the climb, pressing it and not
## pressing it look identical on screen.
const MAP_CLEAR_FILL_SEC := 0.25          # >= 0.084; <= 0.50
const MAP_HEAL_SEC := 0.60                # >= 0.30; <= 1.00

## The glyph inside a node — what that node PAYS. Without it the two nodes on a floor are identical
## to the pixel, and the fork has nothing to choose between.
##
## ⚠ **RAISED 13 -> 21 because 13 did not work**, and the failure was not subtle: the reward was
##「a few pixels of line art inside a 40 px circle」 and could not be told apart at all. The three
## shapes at 21 px, measured rather than estimated (`map_view._glyph_points` builds them):
##   COUNT (cells)  three squares 11.8 px on a side, 16.8 px apart, spanning 22.7 px out
##   BEAK           a triangle 36.5 px across the base and 31.5 px tall
##   HEAL (chest)   a cross 42 px across both ways
## At 13 those were a 7.3 px square, a 22.6 px triangle and a 26 px cross.
##
## ⚠ **It does NOT scale with the node.** A locked node shrinks to `MAP_NODE_LOCKED_SCALE` and its
## glyph does not, because what a place pays is how you choose the route TO it — shrinking the answer
## on the nodes you are choosing between is the one place it must not shrink.
const MAP_GLYPH_R_PX := 21.0              # >= 12 — under it the three COUNT squares fall to 6.7 px
                                          # and a 3 px stroke fills them solid, which is the defect
                                          # this number was raised to fix; <= 26, from the widest
                                          # glyph (1.08 x this, plus half a stroke) having to fit
                                          # inside the SMALLEST drawn node, 40 x MAP_NODE_LOCKED_SCALE
const MAP_GLYPH_WIDTH_PX := 3.0           # >= 2.0 (snap floor); <= 5 — half of a COUNT square's
                                          # 11.8 px side, over which three squares read as three
                                          # blobs

## **How present the glyph is in each of the four states — the INK's own ladder, not the fill's.**
##
## ⚠ **These two are new because reusing the fill's numbers shipped an unreadable glyph.** The ink is
## `COL_PANEL_BG`, a dark tone drawn ON the node so the reward reads as cut out of it — and the fill
## it is cut out of gets DIMMER as the state gets colder. So handing the ink the fill's own alpha
## darkens both sides of the same contrast at once, and the two converge instead of separating.
## Measured on the shipped frame: a LOCKED glyph at `PRESS_ALPHA_OFF` 0.30 against a fill also at
## 0.30 came out at **1.3 : 1**, and on the opening frame six of the seven nodes are LOCKED — which
## is the whole of the user's 「what a node gives cannot be told apart」.
##
## HERE and OPEN have no entry here: they are drawn at `PRESS_ALPHA_ON` and the fill under them is
## opaque, which already measures 5.2 : 1.
##
## ⚠ **The ratios these buy are PLAIN Rec.709 luminance ratios and NOT WCAG's offset form**, and
## that is arithmetic rather than a lowered bar: the ink's own luminance is 0.088 and a LOCKED fill
## over the clear colour is 0.328, so WCAG's `(L+0.05)` form tops out at **2.7 : 1 with the glyph
## fully opaque**. 3 : 1 is not reachable on this pair without changing the ink or the fill, and a
## floor nothing can pass is not a floor. `net_map` pins the plain ratio at 1.8 and measures 2.5
## (PAST) and 2.0 (LOCKED) at the values below.
const MAP_GLYPH_PAST_ALPHA := 0.80        # >= 0.70 — under it a walked node's reward drops under the
                                          # 1.8 ratio; <= 1.0. It is deliberately ABOVE
                                          # MAP_NODE_PAST_ALPHA 0.62: the node dims, the answer on it
                                          # does not
const MAP_GLYPH_LOCKED_ALPHA := 0.75      # >= 0.65 (same floor, against the dimmer LOCKED fill);
                                          # <= 1.0. ⚠ It does NOT track PRESS_ALPHA_OFF and must not
                                          # be folded back into it — that sharing is what shipped the
                                          # defect. What a place PAYS is how the route is chosen
                                          # BEFORE it can be walked, so it is the one thing on a
                                          # locked node that stays readable

## The boss, drawn as three nested rings on top of its circle. Their THICKNESS is
## `MAP_BOSS_RING_WIDTH_PX`, up beside the you-are-here ring it used to share a constant with.
const MAP_BOSS_RINGS := 3                 # exactly 3 — the design's "three nested circles"
const MAP_BOSS_RING_STEP_PX := 14.0       # >= 6 or three rings are one thick ring; <= 18, from
                                          # 56 - 2 * 18 = 20 > 0

## 「병사 %d · 힘 %.0f」, top left. ⚠ **This is the only data on the map screen**, because
## `hud_view._draw` returns on `battle == null` and draws nothing here at all — without it there is no
## way to answer "what am I short of" from the screen, which is the whole question the fork asks.
const MAP_ARMY_POS_PX := Vector2(24.0, 44.0)   # y >= MAP_ARMY_FONT_SIZE_PX (a baseline at 0 is off
                                          # screen); x + text width <= 470 - 48 = 422, clear of the
                                          # leftmost node column
const MAP_ARMY_FONT_SIZE_PX := 26         # > HUD_FONT_SIZE_PX 22 — it is the only readout on this
                                          # screen; <= 30

## Kind -> how many sides its shape has, indexed by `Rules.NodeKind`: 0 is a circle, 4 a diamond.
## ⚠ **A TABLE and not a branch in `map_view`.** Adding the elite one day then costs `rules.gd` plus
## this line and **no view edit**; written as a branch it costs a view edit forever after.
const MAP_NODE_SIDES := [0, 4, 0]


# ---------------------------------------------------------------------------------------------
# Combat juice — the twelve effects. Forty-four values, and not one of them is a truth
# ---------------------------------------------------------------------------------------------

## EVERY NUMBER BELOW IS A FIRST VALUE TO BE RE-MEASURED BY EYE. See combat-juice, which pins that
## in as many words. In the last game a white flash was built at 0.09 s, could not be seen, and was
## doubled to 0.18; an attacker line at 0.08 s was under five frames at 60fps and the user never saw
## it once. Only play decides which of these is wrong and in which direction.
##
## THE FLOOR ON ANY AMPLITUDE IS 2.0 CANVAS PX, and it is arithmetic rather than taste.
## `snap_2d_vertices_to_pixel` rounds each vertex to the nearest integer canvas pixel, so a
## displacement d reaches the screen as `round(x + d) - round(x)`: below 0.5 it is 0 px at half the
## phases and can never exceed 1 px, and at 1.0 it is always at least 1 px. Reading as MOTION needs
## two steps, so the practical floor is 2.0. Nothing here is specified below it.

## 1 — the tracer. A stub of length SHOT_LEN_PX sweeps muzzle to target; drawing the whole line
## would make this item 6 instead. Both endpoints are frozen on the firing frame and carried in the
## fx: a dead target is re-targeted immediately, so re-reading `soldier_target` every frame bends the
## bullet onto the next enemy instead of the corpse. A fixed LENGTH fixes only half of that — the old
## game's line ended in empty grass in one direction and buried itself under a body in the other.
const SHOT_SEC := 0.10                # 4 tiles of range = 160 px crossed in 0.10 s, so 1600 px/s
const SHOT_LEN_PX := 12.0
const SHOT_WIDTH_PX := 5.0            # ⚠ RAISED 2.0 -> 5.0 by the world-width table. A tracer that
                                      # lives 0.10 s has one chance to be seen, and at `ZOOM_MIN` 2.0
                                      # reached the glass at 0.90 px — the same failure shape as the
                                      # 0.08 s attacker line the last game shipped and the user never
                                      # saw once, on the other axis. <= 6, half of SHOT_LEN_PX: a stub
                                      # as thick as it is long is a dot, not a tracer

## 2① — the lunge. Peaks at LUNGE_SEC * 0.5 and is exactly 0 at both ends, so no body is ever left
## sitting displaced.
## ⚠ THIS IS A DRAWING OFFSET AND NEVER `soldier_pos`. Reach tests read positions directly and the
## grid reserves one body per tile, so writing the lunge into the sim would change who is inside
## whose reach — the effect would rewrite the rules it exists to decorate.
## The cap is `gap + LUNGE_BITE_PX` rather than a flat push: the draft's flat 14 px times a per-type
## multiplier drove the lion 33.6 px into a body 40 px away and swallowed it whole, and two of its
## five slots belonged to types whose range is not 0 and so could never be read at all.
const LUNGE_SEC := 0.18               # 11 frames at 60fps. 0.08 was under 5 and invisible last game
const LUNGE_PUSH_RATIO := 0.55        # of one's OWN radius: melee cell 7.7 · bison 8.8 · lion 12.1 px
const LUNGE_BITE_PX := 6.0            # the resulting overlap is 6.0 px at worst, by construction

## 2② — the hit spark. Six shards leave the contact point along the TANGENT of the touching faces,
## fanning to both sides, and they start LUNGE_SEC * 0.5 late.
## **There is deliberately no delay constant**: that instant is when the lunge peaks and the two
## bodies actually meet. Fired on the hit frame the shards appear in the empty gap between two bodies
## that have not moved yet, which reads as a telegraph rather than a collision.
## ⚠ THE TANGENT IS NOT A PREFERENCE. It is the only axis on which every point moves away from BOTH
## centres; a fan opened along ±facing lands every one of its ten points back inside the striker's
## own outline, because the contact point is always `(HIT_HALO_MUL - 1) * own radius` deep inside the
## striker's own halo. See combat-juice, "where the shards land" and the two inequalities under it.
## The shards do NOT escape the target's halo and are not claimed to: what carries this effect is
## that they move (2.5 px per frame) while everything under them stands still.
const SPARK_SEC := 0.12               # 7.2 frames at 60fps; fx lifetime 0.09 + 0.12 = 0.21 s.
                                      # ⚠ NOT a free value. Above 0.125 the per-body bound breaks —
                                      # 8 neighbours * (SPARK_SEC / 1.0 s period) must stay under
                                      # 1.0, or one body's rim is never clean and the spark stops
                                      # reading as "it popped". Lengthen SPARK_REACH_PX instead
const SPARK_COUNT := 6                # three per side of the tangent, so the fan is symmetric
const SPARK_REACH_PX := 18.0          # 45% of a tile. 18 / 7.2 = 2.5 px per frame, above the floor
const SPARK_LEN_PX := 5.0             # one shard spans 13 ~ 18 px out on the last frame. ⚠ EVERY
                                      # margin is computed from the INNER end (13), never the tip
                                      # (18) — built from the tip, half the points pass untested
const SPARK_WIDTH_PX := 2.0           # ⚠ **DELIBERATELY BELOW the world-width floor** (0.90 px at
                                      # `ZOOM_MIN`) and it is the one row that CANNOT be raised on its
                                      # own: its ceiling is half a shard's own length,
                                      # `SPARK_LEN_PX / 2 = 2.5`, and that ceiling sits UNDER the
                                      # floor's 4.45. A shard as wide as it is long is a dot, so
                                      # raising this needs SPARK_LEN_PX and SPARK_REACH_PX to move
                                      # with it — that is a re-measure of item 2, not a width fix, and
                                      # it belongs to whoever scores item 2 by eye.
                                      # ⚠ SPARK_LEN_PX 5.0 is 2.25 px at `ZOOM_MIN` and is under the
                                      # same floor; it is NOT in the width table (it is a length, not
                                      # a stroke) and is flagged here rather than quietly changed.
                                      # The leaf takes this as an ARGUMENT, which is the only reason a
                                      # net can bite on it at all
const SPARK_SPREAD_DEG := 12.0        # HALF-angle off the tangent, so one fan spans 24 degrees.
                                      # 2 * 22 * sin 12 = 9.2 < 13, which is what makes even the
                                      # inner end farther from both centres than the contact point

## 3 — the body being hit: white mixed in, a filled halo UNDER it, and a flinch toward the striker.
## ⚠ WITHOUT THE HALO THIS EFFECT DOES NOT EXIST. A body here is a 2 px outline plus a 3 px dot, so
## a tint has no AREA to paint — mixing white repaints two pixels of border, and that is precisely
## what read as "there is no flash" in the last game.
const HIT_FLASH_SEC := 0.14           # 14% duty against the 1.0 s attack period
const HIT_FLASH_STRENGTH := 0.70      # 1.0 is not "mix" but "cover", and then who was hit is lost
const HIT_HALO_MUL := 1.35            # of body radius: 18.9 · 15.1 · 21.6 · 13.5 · 29.7 px
const HIT_KNOCK_PX := 3.0             # above the 2.0 px snap floor
const HIT_KNOCK_SEC := 0.10

## 4 — the death burst, in that body's own side colour. It is drawn ABOVE everything: on the floor a
## 10 px burst is buried under a 22 px lion.
const BURST_SEC := 0.32
const BURST_GROWTH := 2.2             # lion 22 -> 48.4 px, crow 10 -> 22.0 px
const BURST_WIDTH_PX := 5.0           # ⚠ RAISED 2.0 -> 5.0 by the world-width table. A death is the
                                      # thing on screen that must go DOWN — the last game died partly
                                      # for the want of it — and at `ZOOM_MIN` 2.0 was 0.90 px. <= 5,
                                      # half the crow's own 10 px start radius

## 5 — the area ring, grown to the REAL area radius so the screen finally says which attacks splash:
## the lion's `area` 1.5 tiles = 60 px, and CELL_RANGED's `area` 1.0 = 40 px, which nothing on screen
## currently communicates at all.
const AREA_RING_SEC := 0.25
const AREA_RING_START_RATIO := 0.4    # of the final radius, so 24 px for the lion's 60
const AREA_RING_WIDTH_PX := 5.0       # ⚠ RAISED 3.0 -> 5.0 by the world-width table, and it has TWO
                                      # jobs at `ZOOM_MIN`: the lion's telegraph during a watched
                                      # fight, and the drag candidate ring during planning — an island
                                      # OPENS at `ZOOM_MIN`, so the ring the player aims a drop with
                                      # was a 1.35 px hairline every single time. <= 6, a third of
                                      # TARGET_RING_R_PX 18, over which the candidate ring closes into
                                      # a disc and stops reading as a ring at all

## 6 — target lines, drawn for ENEMIES ONLY. The one item of the twelve that can be a net loss in
## readability: Into the Breach draws intent but is turn-based with under ten actors, and neither TFT
## nor Bad North draws any line at all — Riot explicitly deleted its "cloud of visual effects and
## particles". Hence two narrowings: one side only, and a hard count above which none are drawn.
## ⚠ **DELIBERATELY BELOW the world-width floor** (0.45 px at `ZOOM_MIN`), and this line is the one
## place in this file where being under it is the POINT. `COL_TARGET_LINE` is alpha **0.12** and up to
## `TARGET_LINE_MAX_COUNT` 14 of these cross the whole island at once; the paragraph above records
## that this is the one item of the twelve that can be a net LOSS in readability, which is why Riot
## deleted its own effect cloud. Raise this to 2.25 px and fourteen full-length lines over every body
## on screen is exactly the clutter both narrowings exist to prevent.
const TARGET_LINE_WIDTH_PX := 1.0
const TARGET_LINE_MAX_COUNT := 14     # ⚠ **RAISED 8 -> 14, and it now bites for the first time.**
                                      # `plan-then-watch` stage 4 put 8 · 12 · 14 enemies on the
                                      # three islands; at 8 this guard drew ZERO intent lines until
                                      # 4 and 6 of them were dead on islands 2 and 3 — the OPENING
                                      # of the fight, which is exactly the phase where the hand
                                      # cannot move and reading is the whole activity. 14 is the
                                      # largest island's count, so every fight opens with its lines
                                      # on. ⚠ **It is a FIRST value and verify-look scores it**: if
                                      # 14 lines read as noise it comes back down, and `combat-juice`
                                      # records the measurement. Floor: the largest island's enemy
                                      # count, or the guard is back to hiding the opening

## 7 — one ring under each soldier as it steps off the boat. The five land on ADJACENT tiles, because
## the free-tile search is a BFS out of the dock. Radius is pinned to exactly half a tile: 20 * 2 =
## 40, so two orthogonally adjacent rings touch and never overlap. At 26 px they overlapped by 12.
const LAND_RING_SEC := 0.40
const LAND_RING_R_PX := 20.0
const LAND_RING_WIDTH_PX := 5.0       # ⚠ RAISED 2.0 -> 5.0 by the world-width table. This ring is the
                                      # only mark that says a soldier is ASHORE, and the arrival is
                                      # watched at `ZOOM_MIN` where 2.0 was 0.90 px. <= 6, under a
                                      # third of the 20 px radius so two adjacent rings still read as
                                      # two rings touching rather than one band

## The drag overlay (`boat-and-landing` stage 4, P8) — not one of the twelve combat items, but the
## same "every number is a first value" rule applies. `TARGET_RING_R_PX` is the candidate ring on
## the tile under the cursor; `ROUTE_WIDTH_PX` the water route from that boat's harbour to it, which
## is a POLYLINE now and not a straight line (`speed-off-open-landing`, 2.3).
## ⚠ **`DROP_TINT_ALPHA` is deleted with `COL_SENDABLE`.** It was the alpha the whole sendable coast
## was washed at, and the user asked for the inverse picture: mark what is blocked, nothing else.
## It is also the 0.18 this file's own `PRESS_ALPHA_OFF` paragraph cites as the measured failure —
## that citation is about a NUMBER and survives the constant's deletion.
## ⚠⚠ **`ROUTE_WIDTH_PX` RAISED 3.0 -> 5.0, and this is the row the world-width table was written
## for.** At 3.0 the water route reached the glass at `3.0 * 0.45 = 1.35 px` — under this file's own
## 2.0 px snap floor, at the zoom an island OPENS at and the whole plan is authored at. A capture
## found only the axis-aligned leg rasterising at all, and a fully diagonal route drawing 36 px in
## total. `REFUSE_MARK_WIDTH_PX` forty lines down did this exact sum out loud in its own comment and
## `CLIFF_FACE_WIDTH_PX` was re-measured for it when `ZOOM_MIN` fell; this was the third row of the
## same table and nobody re-measured it. 5.0 is 2.25 px, the same value both of those chose.
## Ceiling 8 — over that the route covers the terrain it is drawn across, and the route's job is to
## say WHICH WATER the boat sails, which needs the water visible beside it.
const ROUTE_WIDTH_PX := 5.0
const TARGET_RING_R_PX := 18.0        # >= 12; <= 20 or two adjacent rings would overlap

## **The refusal mark** — `speed-off-open-landing` 2.5, on the user's 「못내림만 표시하면 됨」. One ring
## at the cursor on the frame the sim REFUSES a drop, fading out. It reuses `COL_LOSE`, which is
## already the tone the drag candidate ring turns when the tile under the cursor cannot be landed on:
## one concept (「여긴 못 내린다」), one value.
##
## ⚠ **It is driven by `Battle.send`'s own -1 and never by a second copy of the rule.** The green
## sendable tint used to carry that guarantee — its predicate was `grid.home_harbour_for(t) >= 0`,
## the exact call `send` refuses on — and deleting the tint deletes the guarantee with it, so the mark
## inherits it from the SIM's answer rather than from a predicate the view evaluates itself.
const REFUSE_MARK_SEC := 0.35         # >= 0.25 — under five rendered frames at 60fps (0.084 s) is
                                      # unseen, and this repo has measured exactly that twice; the
                                      # floor is raised well above it because the mark is a ONE-SHOT
                                      # with nothing before or after it to be read against.
                                      # <= 0.6 or it is still on screen for the next drag
const REFUSE_MARK_R_PX := 26.0        # >= TARGET_RING_R_PX 18 — at or under it the mark is the same
                                      # circle as the drag candidate ring and reads as a candidate
                                      # rather than a refusal; <= 40 (one tile) or it covers the
                                      # terrain that says WHY the tile was refused
const REFUSE_MARK_WIDTH_PX := 5.0     # >= 5, and the 5 is ARITHMETIC: this ring is drawn in WORLD
                                      # space, so at ZOOM_MIN 0.45 it reaches the canvas at 2.25 px —
                                      # just over this file's 2.0 px snap floor. The same sum is why
                                      # `CLIFF_FACE_WIDTH_PX` was re-measured from 4.0 to 5.0 when
                                      # ZOOM_MIN fell; a mark specified at 3.0 would draw at 1.35 px
                                      # and be a hairline exactly where it has to be read.
                                      # <= 8 or the stroke swallows the tile it points at

## The fleet as a picture (`boat-and-landing` stage 5). `CLIFF_FACE_WIDTH_PX` is P10's seaward-edge
## line. ⚠ **RE-MEASURED when `ZOOM_MIN` fell to 0.45**: the old 4.0 drew at 2.25 px at the old
## `ZOOM_MIN` and would draw at **1.8 px** at the new one, under this file's own 2.0 px snap floor.
## 5.0 puts it back at exactly 2.25 px — the value the old floor was derived from in the first place.
## `HULL_WAIT_BLINK_SEC` is P7's stalled-boat blink — a full on/off cycle, not a half.
const CLIFF_FACE_WIDTH_PX := 5.0      # >= 5 (2.25 px at the new ZOOM_MIN); <= 8
const HULL_WAIT_BLINK_SEC := 0.5      # >= 0.3 (under 5 frames at 60fps is unseen); <= 1.0

## 8 — press feedback, inside 100 ms because that is Swink's bound on input-to-response in a
## real-time game. ⚠ The refusal shake rides BOTH the box rect and the glyph position with the same
## offset: shake only the box and the text walks out of it, shake only the text and the box sits
## still, which reads as nothing having shaken.
##
## ⚠ **Renamed, not re-purposed.** `KEY_FX_SEC` / `KEY_REFUSE_SHAKE_PX` were named for the 1/2 keys
## `plan-then-watch` deletes; the effect they drive is now the START BUTTON's refusal — pressing
## start with nothing sent. `BERTH_FX_SEC` is deleted outright with the berths.
## ⚠ `REFUSE_SHAKE_PX` now has exactly ONE reader (`hud_view._chip_offset`), because `_berth_offset`
## was the second one and it is gone. Deleting the start-button shake therefore deletes this
## constant's last reader, which is why the shake is pinned at BOTH ends rather than only above.
const CHIP_FX_SEC := 0.18
const REFUSE_SHAKE_PX := 4.0

## 9 and 10 — the holds, and the panel rising out of nothing rather than snapping to full alpha.
## ⚠ HOLD_OUTCOME_SEC IS A PRECONDITION FOR ITEM 4, not a flourish. Today the shell opens the next
## island on the frame victory is decided, so the last enemy's burst never plays on island 1 at all.
## HOLD_BEAK_SEC is ALSO how long the picked roster row stays stained: there is deliberately no
## separate flash constant, because the moment the two diverge the panel either vanishes mid-stain or
## holds an empty screen after the stain has finished. One concept, one constant.
const PANEL_FADE_SEC := 0.25
const HOLD_OUTCOME_SEC := 0.80
const HOLD_BEAK_SEC := 0.50

## 11 — screen shake, amplitude proportional to damage.
## ⚠ THERE IS STILL NO `Camera2D` IN THE TREE. `boat-and-landing` added a real pan and zoom, but
## `field_view` composes them itself (`position = -cam_px * zoom + shake_offset()`, `scale = zoom`) —
## a `Camera2D` node would be a SECOND place that transform lives, and the two would drift the first
## time one changed without the other. `field_view.screen_to_world_px` (and `world_to_tile` beside it)
## is that ONE function, and `boat-and-landing` stage 4's drag is what finally calls it —
## `game.gd::_tile_at` converts a press, a motion and a release through it, so the hit test a boat
## drag needs and the pan that never needed one go through the same conversion.
## ⚠ THE OFFSET IS ASSIGNED TO `position`, NEVER `+=`. In the last game `+=` became the basis of the
## next frame's lerp and compounded roughly 9x, so a 28 px cap stopped nothing: 67.9 px at 60fps and
## 160.4 px at 144. Keep the unshaken position separately and assign.
const SHAKE_SEC := 0.30
const SHAKE_PER_DAMAGE_PX := 1.2      # damage 2 -> 2.4 px, the lion's 4 -> 4.8 px
const SHAKE_MAX_PX := 6.0             # also the width of the bare band a shake exposes, and the
                                      # size of the click error if the shell fails to subtract the
                                      # offset — 6 px on a 40 px tile is 15% of its edge
const SHAKE_A_FREQ := 61.0            # deterministic `sin`: a random shake cannot be measured
const SHAKE_B_FREQ := 47.0

## ⚠ **RE-MEASURED with `ZOOM_MIN`, and the old value was a real defect at the new one.** At
## `ZOOM_MIN` 0.45 the visible world is 2844.4 px wide against a 1920 px map, so it starts at
## x = (1920 - 2844.4) / 2 = **-462.2 px** — **11.6 tiles** of bare ground on each side, against a
## margin of 5. `net_camera::_painted_area_covers_the_viewport` is the row that catches it.
## The terrain loop runs this many tiles wider on every side and paints the outside with COL_WATER
## DIRECTLY — `terrain_colour_of_char` takes a legend character and there is no legend outside the
## grid, so inventing one would put the island legend in two places.
## ⚠ **Cost, measured rather than assumed**: the loop goes from 58 x 42 = 2436 tiles to 72 x 56 =
## 4032, and `_paint_tile` is 2 draw calls, so 4872 -> 8064 immediate-mode calls a frame. This repo's
## "300 Node2Ds cost 0.065 ms" measurement is about NODES and may NOT be cited for this. If the frame
## time moved, the alternative is one filled rect behind the grid instead of a per-tile loop.
const WATER_MARGIN_TILES := 12        # >= 12 (11.6 tiles of bare ground at ZOOM_MIN 0.45, plus
                                      # SHAKE_MAX_PX 6 px = 0.15 tile); <= 16, or 80 x 64 = 5120
                                      # tiles is 10240 draw calls a frame

## ⚠⚠ **The terrain pass is CULLED to the visible rect now, and this is how far past it the loop still
## goes.** The "cost, measured rather than assumed" paragraph above is what forced it: at 48 x 32 the
## unculled loop was 4,032 tiles = 8,064 immediate-mode calls **every frame**, and `push-inland`'s
## variable grid takes the same loop to 168 x 56 = 9,408 at 144 columns.
##
## **2 is arithmetic, not slack.** Two things move the world under a `cam_px` that has not changed:
## the SHAKE, added to `position` after the span is computed — `SHAKE_MAX_PX 6 / ZOOM_MIN 0.45 =
## 13.3 world px = 0.33 tile` — and a tile straddling the edge, which the span's own `floor` / `ceil`
## already covers. One tile clears both; 2 is one tile of margin on top, and it costs 2 rows and 2
## columns of a loop that just shed a quarter of itself.
## Floor 1 — at 0 a shaking frame exposes bare ground along one edge, which is the defect
## `WATER_MARGIN_TILES` exists to prevent, reintroduced one layer in. Ceiling 6, past which the cull
## stops paying on the tall axis (the visible world is 40 tiles high against a 56-tile margin rect).
const CULL_PAD_TILES := 2

## 12 — gait. Phase turns on DISTANCE TRAVELLED, not on time, and that is the whole of "it must not
## slide": a body that does not move does not animate. Squash is a Vector2 and not a scalar —
## `1 - s*sin(phase)` along the heading, `1 + s*sin(phase)` across it. A scalar radius can only
## pulse uniformly, which is not "squashed along the direction of travel" at all.
const GAIT_PERIOD_TILES := 0.7        # one cycle every 28 px
const GAIT_SQUASH := 0.20             # max displacement crow 2.0 · ranged 2.2 · melee 2.8 ·
                                      # bison 3.2 · lion 4.4 px. The crow sits exactly on the 2.0 px
                                      # floor; at 0.12 all five bodies were at or under it, which
                                      # would have made this item invisible and therefore pointless

## The ceiling on the TRANSIENT drawer only — shots, sparks, bursts, area rings, landing rings.
## Anything bolted to a BODY lives in the other drawer, keyed by body, capped at 19 by the number of
## bodies on screen. That separation is why "drop the oldest" and "one flash per body, age reset
## rather than stacked" never eat each other.
## ⚠ THIS IS NOT WHAT KEEPS SPARKS BOUNDED. Live sparks top out at 12 by lifetime arithmetic (0.21 s
## of life against a 1.0 s minimum melee period, 12 melee attackers at most), which is under 5% of
## this number. A guard that can never bite must not be described as the guard, or the next person
## believes it.
const FX_MAX_COUNT := 256

## Per-effect strength, indexed by the item numbers 1..12 — read it through `fx_gain_of`, never
## directly. Every effect multiplies its own amplitude by its own slot, and 0.0 turns that effect off
## completely.
## This is structure rather than a feature deferred: every shipped game exposes these switches
## (Vampire Survivors carries Flashing VFX and Weapons ScreenShake separately, Nuclear Throne sliders
## screenshake to 0%), and Xbox Accessibility Guideline 118 forbids flashing above approximately
## three per second. An options screen is out of scope here; the point of the array is that bolting
## one on later touches no effect code.
## ⚠ Note that slots 2 and 3 exist for DIFFERENT reasons — 3 is a photosensitivity handle (a halo can
## toggle 3 to 7 times a second), 2 is a clutter handle (one contact point repeats at 1 Hz and covers
## 0.078% of the screen). Explaining both the same way makes neither checkable.
## ⚠ `const X := PackedFloat32Array([...])` is a parse error on 4.7.1, so this is a plain `const`
## Array — read-only, but with no element typing, which is why the accessor casts.
const FX_GAIN := [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]


# ---------------------------------------------------------------------------------------------
# Accessors
# ---------------------------------------------------------------------------------------------

## A `const` Array is read-only but its elements are untyped, so every read casts.
static func body_radius_of(type_id: int) -> float:
	return float(BODY_RADIUS_RATIO[type_id]) * TILE_PX


static func body_corner_radius_of(type_id: int) -> float:
	return float(BODY_CORNER_RATIO[type_id]) * body_radius_of(type_id)


## FX_GAIN holds twelve slots and combat-juice numbers its effects 1..12, so the off-by-one lives
## here and in exactly one place. Spread across callers, one of them eventually reads its
## neighbour's gain and the effect that appears to switch off is the wrong one — which is the
## quietest possible failure, because the round stays green and the screen merely looks different.
## The cast is the same one every read of a `const` Array in this file makes.
static func fx_gain_of(item_no: int) -> float:
	return float(FX_GAIN[item_no - 1])


static func body_colour_of(is_enemy: bool) -> Color:
	return COL_ENEMY if is_enemy else COL_ALLY


## ⚠ **`sendable_tint()` is deleted with the two constants it combined.** It washed every sendable
## tile in `COL_SENDABLE` at `DROP_TINT_ALPHA`; `speed-off-open-landing`'s question C replaced that
## whole picture with a mark on what is BLOCKED. `ghost_tint()` below is the surviving example of the
## tone-plus-ratio split this used to be the other half of.
static func hp_bar_colour(filled: bool) -> Color:
	return COL_HP_FULL if filled else COL_HP_EMPTY


## Keyed by the island legend character in islands.gd, because the grid keeps passability as a
## byte and cannot tell water from a hole — both are impassable and they must not look alike.
## `B` `C` `L` are all passable land and fall through to `COL_LAND`.
##
## ⚠ `H` (harbour) is water, functionally, so it gets the water tone here — the harbour MARKER is a
## separate outline drawn on top, the same way the old dock outline worked. `^` (cliff) is exactly as
## impassable as `#` (3.2 of `boat-and-landing`) but P10 (stage 5) gives it its OWN fill —
## `field_view._draw()` adds a face line along its seaward edge on top of this, which is what turns
## "coloured like a hole" into "reads as height" with no elevation axis at all. `/` (ramp) is
## passable land, the one doorway through a cliff wall, and gets its own tint for the same reason.
static func terrain_colour_of_char(c: String) -> Color:
	match c:
		"~":
			return COL_WATER
		"H":
			return COL_WATER
		"#":
			return COL_HOLE
		"^":
			return COL_CLIFF
		"/":
			return COL_RAMP
		_:
			return COL_LAND


static func viewport_size_px() -> Vector2:
	return Vector2(VIEWPORT_W_PX, VIEWPORT_H_PX)


## Integer tile coordinates are TILE CENTRES in the sim's continuous space, so a unit sitting on
## tile (3, 4) has position Vector2(3, 4) and is drawn at the middle of that tile. Converting with
## a bare `p * TILE_PX` instead puts every body on a tile corner and the half-tile error is small
## enough to look like a rendering wobble rather than a bug.
static func tile_point_px(p: Vector2) -> Vector2:
	return (p + Vector2(0.5, 0.5)) * TILE_PX


static func tile_centre_px(tx: int, ty: int) -> Vector2:
	return tile_point_px(Vector2(tx, ty))


static func tile_rect_px(tx: int, ty: int) -> Rect2:
	return Rect2(Vector2(tx, ty) * TILE_PX, Vector2(TILE_PX, TILE_PX))


## Top-left of the HP bar for a body whose centre is at `centre_px`. The bar hangs below the body,
## so it moves with the unit type's radius rather than sitting at a fixed offset.
static func hp_bar_origin_px(centre_px: Vector2, type_id: int) -> Vector2:
	var below := centre_px.y + body_radius_of(type_id) + HP_BAR_GAP_PX
	return Vector2(centre_px.x - HP_BAR_W_PX * 0.5, below)


static func hp_bar_size_px() -> Vector2:
	return Vector2(HP_BAR_W_PX, HP_BAR_H_PX)


## The start button's RESTING rectangle, in viewport px. The refuse shake is applied on top of this
## by `hud_view`, so the un-shaken button is drawn exactly here and `game.gd` hit-tests exactly here.
##
## ⚠ **`button_rect_px()` below is NOT reused for this**, and that is deliberate: `panel_view` already
## owns that rect for RESTART, and one rectangle answering to two verbs is how a restart gets pressed
## by someone aiming at start.
static func start_rect_px() -> Rect2:
	return Rect2(HUD_START_ORIGIN_PX, HUD_START_SIZE_PX)


## Summon slot `i`'s RESTING rectangle, in viewport px. The refusal shake rides on top of this in
## `hud_view`, so the un-shaken box is drawn exactly here.
##
## ⚠ **There is no `slot_hit_rect_px` and there must not be.** The boxes are not clickable at all — the
## keyboard arms them — so a hit rect would be geometry nothing tests against, and the next reader
## would wire a press to it.
static func slot_rect_px(i: int) -> Rect2:
	var x := HUD_SLOT_ORIGIN_PX.x + i * (HUD_SLOT_SIZE_PX.x + HUD_SLOT_GAP_PX)
	return Rect2(Vector2(x, HUD_SLOT_ORIGIN_PX.y), HUD_SLOT_SIZE_PX)


## The roster bar under slot `i`'s digit: 44 x 8 px, inset 6 either side and 6 up from the bottom.
##
## ⚠ **Derived from `slot_rect_px` here and NOWHERE else.** `hud_view` draws it and `net_slots`
## measures it; geometry written twice is exactly what this second accessor exists to prevent.
static func slot_bar_rect_px(i: int) -> Rect2:
	var box := slot_rect_px(i)
	return Rect2(
		Vector2(box.position.x + HUD_SLOT_BAR_INSET_PX,
			box.position.y + box.size.y - HUD_SLOT_BAR_BOTTOM_PX - HUD_SLOT_BAR_H_PX),
		Vector2(box.size.x - 2.0 * HUD_SLOT_BAR_INSET_PX, HUD_SLOT_BAR_H_PX))


## `COL_ALLY` at `GHOST_ALPHA` — a tone and a ratio kept as two constants so they can be re-measured
## independently, combined in one place so a ghost cannot become a fourth ally colour. **A ghost has
## no colour of its own on purpose.** (`sendable_tint()` was the other half of this pattern and died
## with the coast wash; `speed_rect_px()` died with the speed chips.)
static func ghost_tint() -> Color:
	var c := COL_ALLY
	c.a = GHOST_ALPHA
	return c


## Where soldier `slot_index` stands while it is still in reserve, as an offset from the START
## HARBOUR's tile centre in world px. The index is the SOLDIER ID, not a position in a list, so
## dragging one away leaves a hole rather than re-flowing the stack — the emptying is the feedback.
## Rows go UP (negative y): a harbour is on the bottom row of every island and below it is off-map.
static func idle_soldier_offset_px(slot_index: int) -> Vector2:
	var col := slot_index % IDLE_SOLDIER_COLS
	var row := slot_index / IDLE_SOLDIER_COLS
	return Vector2(
		IDLE_SOLDIER_ORIGIN_PX.x + col * IDLE_SOLDIER_PITCH_PX,
		IDLE_SOLDIER_ORIGIN_PX.y - row * IDLE_SOLDIER_PITCH_PX)


static func panel_rect_px() -> Rect2:
	return Rect2(PANEL_ORIGIN_PX, PANEL_SIZE_PX)


## Absolute viewport rectangles, not panel-relative ones: the shell hit-tests a mouse position
## against these, and a relative rect would have to be offset by whoever asked — which is the
## same value living in two places.
static func roster_entry_rect_px(entry_index: int) -> Rect2:
	var col := entry_index % ROSTER_COLUMNS
	var row := entry_index / ROSTER_COLUMNS
	var x := PANEL_ORIGIN_PX.x + ROSTER_ORIGIN_OFFSET_PX.x \
		+ col * (ROSTER_ENTRY_SIZE_PX.x + ROSTER_COLUMN_GAP_PX)
	var y := PANEL_ORIGIN_PX.y + ROSTER_ORIGIN_OFFSET_PX.y \
		+ row * (ROSTER_ENTRY_SIZE_PX.y + ROSTER_ENTRY_GAP_PX)
	return Rect2(Vector2(x, y), ROSTER_ENTRY_SIZE_PX)


static func roster_capacity() -> int:
	return ROSTER_COLUMNS * ROSTER_ROWS


static func button_rect_px() -> Rect2:
	return Rect2(PANEL_ORIGIN_PX + BUTTON_OFFSET_PX, BUTTON_SIZE_PX)


# --- the two new screens ------------------------------------------------------------------------

## Title slot `i`'s RESTING rectangle, in viewport px. The press dip is applied on top of this by
## `title_view`, so the un-dipped box is drawn exactly here and the hit test below grows exactly this.
##
## ⚠ **Neither `start_rect_px()` nor `button_rect_px()` is reused for a title slot**, and that is the
## same rule those two already carry between themselves: one rectangle answering to two verbs is how a
## restart gets pressed by someone aiming at start.
static func title_slot_rect_px(slot_index: int) -> Rect2:
	var y := TITLE_SLOT_ORIGIN_PX.y + slot_index * (TITLE_SLOT_SIZE_PX.y + TITLE_SLOT_GAP_PX)
	return Rect2(Vector2(TITLE_SLOT_ORIGIN_PX.x, y), TITLE_SLOT_SIZE_PX)


## The same rectangle grown by `PRESS_HIT_PAD_PX` on all four sides. **The pad is added here and
## nowhere else**: a hit rect re-derived by the shell would be the same geometry written twice, and
## the day the pad changes only one of them would move.
static func title_slot_hit_rect_px(slot_index: int) -> Rect2:
	return title_slot_rect_px(slot_index).grow(PRESS_HIT_PAD_PX)


## Node `n`'s centre. A `const` Array loses element typing, so this cast is the same one every read of
## a const Array in this file makes.
static func map_node_pos_px(n: int) -> Vector2:
	return MAP_NODE_POS_PX[n]


## Drawn radius by node kind. The boss is bigger; everything else is one size, because "how big" is
## one of the three axes (shape, colour, size) the kinds are told apart on.
static func map_node_radius_px(kind: int) -> float:
	return MAP_BOSS_R_PX if kind == Rules.NodeKind.BOSS else MAP_NODE_R_PX


## The pressable radius: the drawn one plus the shared pad. **48 and 64 are written nowhere** — they
## are this sum, so moving the pad moves both.
##
## ⚠ **It is ONE number per kind and does not follow the four states, which is why the two state
## scales are both below 1.0.** A node on offer is drawn at the full radius and pulses out by
## `MAP_PULSE_R_PX` on top of that — 40 + 4 = 44 against a hit radius of 48 — so the drawn rim never
## reaches past the circle you can press. Give HERE or OPEN a scale ABOVE 1.0 and that inverts: the
## visible edge of a node stops being pressable, silently, with every net still green.
static func map_node_hit_radius_px(kind: int) -> float:
	return map_node_radius_px(kind) + PRESS_HIT_PAD_PX


static func map_node_sides_of(kind: int) -> int:
	return int(MAP_NODE_SIDES[kind])


static func map_node_colour_of(kind: int) -> Color:
	match kind:
		Rules.NodeKind.CHEST:
			return COL_NODE_CHEST
		Rules.NodeKind.BOSS:
			return COL_NODE_BOSS
		_:
			return COL_NODE_FIGHT


## What a thing that cannot be pressed looks like: **all of its saturation gone and its alpha down to
## `PRESS_ALPHA_OFF`**, in one place, so the title's dead slot and the map's out-of-reach node say the
## same thing the same way. Two screens inventing "dimmed" separately is two vocabularies to learn.
##
## ⚠ The saturation is dropped as well as the alpha, and that is not decoration: alpha alone leaves a
## coloured shape that still reads as "this one is the blue kind", so the eye keeps sorting it with
## the live nodes. Colour is what says WHAT it is; having none says it is not on offer.
static func dimmed(col: Color) -> Color:
	var c := col
	c.s = 0.0
	c.a = PRESS_ALPHA_OFF
	return c


## The same colour lit by `k` in 0..1 — the hover, and nothing else uses it. `lightened` rather than a
## hand-rolled add so the channels cannot clip past 1.0 unevenly and shift the hue.
static func hover_lit(col: Color, k: float) -> Color:
	return col.lightened(PRESS_HOVER_BRIGHTEN * clampf(k, 0.0, 1.0))


## The same colour dipped by the press, `k` in 0..1.
static func press_dipped(col: Color, k: float) -> Color:
	return col.darkened(PRESS_DOWN_DIM * clampf(k, 0.0, 1.0))


## The scene-change wash, at alpha `p`.
##
## ⚠ **The colour is READ from the project's own clear colour rather than written down again here.**
## The fade's whole claim is "the screen went to background and came back", so a second copy of that
## background would be free to disagree with the one actually behind the map — and the disagreement
## would look like a grey rectangle nobody put there.
static func scene_fade_colour(p: float) -> Color:
	var c: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
	c.a = clampf(p, 0.0, 1.0)
	return c
