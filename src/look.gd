class_name Look
extends RefCounted

## Every presentation constant in the game, with **two named exceptions and no others**.
##
## ⚠ **The exceptions**: (1) **on-screen 낱말** stay next to the screen that prints them —
## `title_view.SLOT_LABELS`, `reward_view`'s labels, and `rules.ITEM_COL_LABELS` for the refit
## dashboard; each of those files says so where the constant lives. (2) **geometry a single view
## draws with and nothing else can read** — `field_view.CORNER_SEGMENTS` and
## `field_view.TERRAIN_PICK_STEPS`.
## ⚠⚠ **THIS LINE READ 「nothing outside this file has one」 UNTIL 2026-08-27 and that was false.**
## An absolute the code does not keep is worse than a rule with two doors in it: the next person
## adding a constant reads the absolute, sees the counter-examples, and concludes the rule is dead.
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
## ⚠⚠ **The island mesh's heights are NOT here.** They live in `assets/terrain/island.json`, written
## by the same Blender run that writes the mesh, and `Islands.ground_h` reads them. A copy in this file
## would be the second place a height is written, and the first thing that happens then is that a body
## sinks into the ground for a reason nobody can find.


const TILE_PX := 40.0

## **The board is laid back 40 degrees** (2026-08-24, the user picked the angle by eye off the horde
## sheet and then named the camera as the 애매함 티켓 04 had been asking about since 2026-08-18).
## A tile is still `TILE_PX` wide and is `TILE_H_PX` tall, so **it is the same world seen from a lower
## chair** — nothing in the sim moved, and every drawing site that already went through
## `tile_point_px` / `tile_rect_px` followed for free.
##
## ⚠⚠ **A body is NOT laid back.** Its radius is untouched: the animals are boards that face the
## camera, so they keep their height while the ground under them loses a quarter of its.
## (`MAP_TILT_COS`, the folded cosine, was deleted with its last reader — the 2D shadow ellipse; the
## camera takes `cos()` of this angle at runtime.)
const MAP_TILT_DEG := 40.0

## ⚠⚠ **THE SQUASH MOVED OUT OF THIS FILE AND INTO THE ENGINE** (2026-08-24, 티켓 08). It used to be
## `TILE_PX * MAP_TILT_COS`, which laid the board back by drawing every row 30.64 px tall on a flat
## canvas. **The field is a 3D space now and a real camera does the laying back**, so a tile is square
## again in world space and the foreshortening happens where foreshortening belongs.
## ⚠ **The constant is kept rather than deleted** because the two numbers above it are still true —
## `MAP_TILT_DEG` is now the CAMERA's pitch — and because four nets still read this name. Deleting it
## would stop them parsing, which turns a measurable red into a silent absence.
const TILE_H_PX := TILE_PX


# =================================================================================================
# The 3D field — everything the engine needs to stand the island up
# =================================================================================================
## ⚠ **One world unit is one tile**, so a length in this file's px divided by `TILE_PX` is a length in
## world units and nothing else has to be converted. `Sprite3D.pixel_size` is set to `1 / TILE_PX` for
## the same reason: a picture sized in canvas px lands at the size this file already says it is.

## How high each legend character stands, in tiles. **This table is the whole terrain port** — the
## islands are text grids in `islands.gd` and nothing new is authored; the legend simply gains a
## height column next to the colour column `terrain_colour_of_char` already owns.
## ⚠ **Water is not 0.** A sea at zero height and a hole at zero height would be the same box, and the
## boat has to sit ON something.
##
## ⚠⚠ **THE SEA WENT FROM 0.15 TO -2.00, AND THAT ONE NUMBER IS 「너무 2D 같다」** (2026-08-25, the
## user, looking at the hand-drawn first island: ***"이게 지금 너무 2D처럼 보인다까?"***). At 0.15 the
## land stood **0.85 tiles** out of the water — about 34 canvas px before the 40° tilt shortens it, so
## the island's whole coast was a **rim**, not a cliff. Nothing else was wrong with the geometry: it
## was a solid the sea had swallowed to the ankles. At -2.00 the same coast is **3.00 tiles** of wall,
## half again a tier step, and the island reads as a block of rock standing in the sea.
##
## ⚠ **Lowering the SEA and not raising the land, on purpose.** Land, ramp, cliff, the hills
## (`HILL_AMP_TILES`) and the tier step are all in proportion to each other and every one of them was
## judged on screen; raising land would have moved four numbers and re-opened four judgements.
## Everything that reads the sea's height — the open-sea quad, the summon ring, a hull, and
## `screen_to_world_px`'s water plane (티켓 22) — takes it from this constant, so they all came down
## with it.
const TERRAIN_H_WATER := -0.45
const TERRAIN_H_HOLE := 0.02
const TERRAIN_H_LAND := 1.00
const TERRAIN_H_RAMP := 1.60
const TERRAIN_H_CLIFF := 2.40

## The camera. **Orthogonal, not perspective**: the game is read off a grid, and a perspective camera
## makes two tiles of the same size draw at two sizes, which is exactly the reading this game cannot
## afford to lose. `size` is the visible WIDTH in tiles (`keep_aspect` is set to KEEP_WIDTH), so the
## existing `zoom` ladder converts straight across — `VIEWPORT_W_PX / zoom / TILE_PX`.
const CAM_PITCH_DEG := MAP_TILT_DEG

## --- the tilt, as a HANDLE ---------------------------------------------------------------------
## ⚠⚠ **`CAM_PITCH_DEG` is the value an island OPENS at, not the value it is stuck at** (2026-08-24,
## the user: 「기울기도 조절 되었으면 좋겠네」). The yaw got its handle first — Q and E — and the same
## argument carries: **the tilt does not change what happens, only what is visible**, so it is not the
## hand moving during combat in the sense the base rule forbids (see 티켓 07's answer).
##
## Floor 20 — under it the ground is nearly edge-on, bodies stand in front of each other in a single
## row and the island stops being a map. Ceiling 80 — past it the terrain's own height stops reading
## at all, which is the flat board the 3D move was for.
const CAM_PITCH_MIN_DEG := 20.0
const CAM_PITCH_MAX_DEG := 80.0
## Per key press. 5 is one twelfth of the usable range, so the whole span is twelve presses — the same
## order as the yaw's 15-degree step over a half turn.
const CAM_PITCH_STEP_DEG := 5.0
const CAM_YAW_DEG := 0.0
## Far enough back that the tallest cliff never crosses the near plane at any yaw, and the ortho
## projection makes the distance itself cost nothing in size.
const CAM_DIST_TILES := 90.0
## ⚠⚠ **THE CAMERA'S FAR PLANE, AND UNDER AN ORTHOGONAL CAMERA IT IS ALSO THE SHADOW RANGE**
## (2026-08-26, the user: 「저 집에 생기는 그림자를 분석해보자」). Godot ignores
## `directional_shadow_max_distance` when the camera is orthogonal and stretches the directional shadow
## map over the camera's `far` instead — godot issue #58332. This camera was left at the default **4000**,
## so one shadow map was being spread across four thousand tiles: about half a tile per texel, which is
## WIDER THAN A TREE. **Nothing on the island cast a shadow onto anything**, and the only shadow left on
## screen was the drawn blob under each object.
## ⚠ **It has to clear `CAM_DIST_TILES` plus the island's own depth**, or the far side of the island
## falls out of the shadow map and the boundary draws as a hard line. 140 clears 90 back plus a 16x12
## island at any yaw, with room left over.
## ⚠ **Smaller is sharper** — the whole map is spread over this number — but going under about 110 starts
## putting the island's back edge on the boundary at full zoom-out.
const CAM_FAR_TILES := 140.0

## One light. It is what makes the height read: a box 2.4 tall throws a shadow a box 1.0 tall does
## not, and that difference is the whole reason the field moved into 3D.
const SUN_PITCH_DEG := -52.0
const SUN_YAW_DEG := -35.0
## ⚠⚠ **Raised with the ambient and the fill LOWERED, and the three move together** (2026-08-26, the
## user: 「그림자도 있어야 할 듯?」). Shadows were switched on and correct the whole time; what erased
## them was light arriving from everywhere else. A shadow is not drawn by the sun, it is the absence of
## the sun — so it can only be as dark as the rest of the lighting lets it be.
const SUN_ENERGY := 1.5
## ⚠ **How far from the camera shadows are still cast, in tiles, and it is not decoration.** Godot's
## default is 100 and the camera sits `CAM_DIST_TILES` back, so the far half of the island fell outside
## it and the boundary drew as **a hard line straight across the sea** — seen in the first capture of
## this port before anything else was judged. It has to clear the camera distance plus the whole island.
## ⚠⚠ **220 -> 70** (2026-08-26). One orthogonal split spreads its whole shadow map over this distance,
## so 220 tiles put a tree half a metre wide well under one texel and **nothing small cast anything.**
## The camera cannot see 220 tiles at any zoom; the range was paying for sea nobody looks at.
## ⚠⚠ **AND IT DOES NOTHING, because this camera is orthogonal** (found 2026-08-26). Every number in
## the history above was tuned against a setting the engine was not reading. The range that actually
## applies is `CAM_FAR_TILES`. **Kept, not deleted**: it is what would apply if the camera ever became
## perspective, and deleting it would let the next session tune it again believing it works.
const SUN_SHADOW_DIST_TILES := 60.0
## ⚠ **Higher than Godot's default 1.0**, because one world unit here is a whole tile: the default is
## tuned for a metre and this world's metre is forty pixels of island.
## ⚠⚠ **2.5 -> 0.55, and this is what was actually eating the shadows** (2026-08-26, the user: 「그림자도
## 있어야 할 듯?」). The bias pushes the shadow lookup along the surface normal to stop a flat face
## shading itself; at 2.5 world units it also pushed the lookup clean past anything SMALLER than 2.5
## units — every tree, rock and bush on the island. It was set when the only things casting were tiles
## and cliffs, which are big enough not to notice.
## ⚠ **0.55 was too far the other way**: with the bias almost off, the island's own flat top shadowed
## itself and drew as horizontal bands. The range that works is narrow — enough to lift the lookup off a
## flat face, less than the height of the smallest thing meant to cast.
## ⚠⚠ **Back up to 1.8, and the reason is worth keeping.** Lowering this to reach the props produced
## shadow ACNE — hard bands across the island's own flat top — long before it produced a tree's shadow.
## Measured across five values on 2026-08-26: at 2.5 nothing small casts, at 1.1 nothing small casts, at
## 0.55 and 0.35 and 0.12 the ground stripes and the props STILL cast nothing readable.
## ⚠⚠ **THE CONCLUSION DRAWN FROM THAT MEASUREMENT WAS WRONG** (2026-08-26). It read: 「this renderer's
## directional shadow map cannot resolve a half-metre object at this scale」. The renderer resolves it
## fine. What could not resolve it was a shadow map stretched over the camera's default `far` of 4000
## tiles — see `CAM_FAR_TILES`. **The five values were measured correctly and the cause was guessed**,
## and the guess sent a whole round into the bias when the bias was never the lever.
## ⚠ **1.8 survives the fix unchanged**: with `far` corrected, this value gives clean shadows and no acne,
## and lowering it to 0.5 brings the stripes back. It was the right number for the wrong reason.
const SUN_SHADOW_NORMAL_BIAS := 1.8
## ⚠⚠ **THE FILL LIGHT IS GONE** (2026-08-26, the user: 「해 하나가 맞는듯」). A dim second light from
## the other side used to lift every face the sun never reaches, and its own comment argued for it: with
## one sun the whole shaded coast goes black. That argument was right and the cure was wrong. A second
## LIGHT gives every object a second lit direction, so nothing on the island agrees about where the light
## comes from — invisible while there were no cast shadows, and the first thing on screen once there
## were. **The ambient does that job now**, and an ambient has no direction to disagree with.

## --- the outline ------------------------------------------------------------------------------------
## ⚠⚠ **BAD NORTH DRAWS EVERY MESH TWICE** (2026-08-26, the user: 「배드노스를 위주로 확인해봐」), and
## 티켓 01 has the line from the talk: **the mesh is drawn inverted and pushed out a shell's width in a
## dark colour, then drawn properly on top.** What comes out is a hard contour around every solid, and
## it is a large part of why those islands read as OBJECTS rather than as shaded ground.
## ⚠ **This repo lost that contour once already and noticed**: 티켓 01 records that when the grey rim
## went, the island stopped reading as 「단단한 물체」 from above. This is that rim, done the way the
## talk does it instead of as a band of geometry.
const COL_OUTLINE := Color(0.115, 0.095, 0.080)
## How far the inverted shell is pushed out, in tiles. ⚠ **It is a WORLD width, not a screen width**, so
## it thickens as the camera zooms in — which is what a hand-inked line does, and the opposite of what a
## post-process edge filter does.
const OUTLINE_GROW := 0.022

const COL_SKY := Color(0.055, 0.055, 0.075)
## ⚠ **Warmed and lifted with the fill's removal.** A cold blue-grey was right while a second light was
## adding its own colour to the shaded faces; alone, it turned every shaded face grey-blue.
const COL_AMBIENT := Color(0.620, 0.680, 0.790)
## ⚠⚠ **Back up from 0.42.** The ambient was cut to make cast shadows read, and then the shadows ended
## up DRAWN instead (see `COL_BLOB`) — so the cut was paying for nothing and charging for it: the
## island's side walls face away from the sun, and with almost no ambient they went black. That black
## band is what read as a cliff between the land and the sea.
## ⚠⚠ **0.66 -> 0.92, and it went up because the fill light went away** (2026-08-26, the user:
## 「해 하나가 맞는듯」). The fill was lifting every face the sun could not reach; the ambient does that
## now. **Raise these two together or the shaded side of the island goes black** — that is what the
## fill's own comment warned about, and it is still true, only the cure is different.
const AMBIENT_ENERGY := 0.92

## How far above its tile's top face a body's FEET sit. Zero would let a billboard's bottom row sink
## into the box it stands on at some yaws; a hair of lift costs nothing and never does.
const BODY_LIFT_PX := 1.0

## The body picture that is NOT a wolf — the rounded square the 2D field drew with `draw_polyline`,
## baked once into a texture so a billboard can wear it. Texels, not px: it is scaled to the body's
## own radius wherever it is used.
const BODY_TEX_PX := 64
const BODY_TEX_OUTLINE_PX := 6
const BODY_TEX_DOT_PX := 5

## The two texels a baked texture is written with: the mark, and the clear ground it sits on. **White
## on purpose** — the sprite's one modulate carries the body's own colour, so the texture itself must
## carry none. They live here because every colour in this game lives here; `field_view` writing
## `Color.WHITE` into its bake loops was caught by `net_draw_leaf`'s own scan.
const COL_BAKE_MARK := Color(1.0, 1.0, 1.0)
const COL_BAKE_CLEAR := Color(1.0, 1.0, 1.0, 0.0)

## How big one texel of a `Sprite3D` is in world units. **The inverse of `TILE_PX` and written as that
## division**, because it is the same fact as "one world unit is one tile" at the top of this section —
## a picture sized in canvas px lands at the size this file already says it is.
const SPRITE_PIXEL_SIZE := 1.0 / TILE_PX
## ⚠⚠ **How big a body is DRAWN, against how big it is in the rules** (2026-08-28, the user: 「집이랑
## 캐릭터 확 줄여줘」). The swordsman filled a 칸 and made the island read as a doll's house.
## ⚠⚠ **THIS IS PRESENTATION ONLY. `Rules` still holds the radius that decides what a body reaches,
## and it has not moved** — so the drawn body is now smaller than the space it actually fights over.
## **That is a knowing mismatch, taken because the bodies are placeholders being redone** (the user,
## earlier today: 「캐릭터랑 건물제거 다시잡을꺼임」). When the real body arrives, the radius and this
## number are settled together and this one goes back to 1.
const BODY_SPRITE_SCALE := 0.45
## ⚠⚠ **How big a building is drawn.** Same round, same reason: the one house on the island stood taller
## than the two-storey rock behind it. **Nothing reads a building's size but the eye** — no rule, no
## check, no footprint — so unlike the body above this one costs nothing and hides nothing.
const BUILD_SCALE := 0.45

## The hull, as a box on the water rather than a rectangle on a canvas.
const HULL_H_TILES := 0.22


## **The hills** (2026-08-24, the user: 「뭔가 대각선으로 올라가는 건 있나 혹시? 뭔가 지금 너무 딱딱해서
## 재미가 없을까?」). The first port gave every tile a box, so land was one flat slab and a ramp was a
## step — **the ground had a height and no SHAPE.** The land now carries a smooth rise on top of its
## legend height, and the mesh joins tile corners rather than stacking boxes, so the rise is a slope.
##
## ⚠⚠ **THE SIM DOES NOT KNOW ABOUT ANY OF THIS.** Passability, reach, ranges and every distance are
## the flat grid they always were; a hill is something the eye climbs and a wolf walks straight
## through. That is the whole reason it is affordable — it is drawing, and it is only drawing.
##
## ⚠ **Only land rises.** Water stays flat or the coast breathes, a cliff stays its own height or it
## stops reading as a wall you cannot climb, and a hole stays a hole.
const HILL_AMP_TILES := 2.60

## ⚠⚠ **THE SWELL'S OWN DIALS WENT WITH THE BAKE, 2026-08-27.** Eight constants stood under
## `HILL_AMP_TILES` and shaped the rolling ground the GDScript mesh builder generated: the rung the
## swell snapped to, one swell's width, the finer second swell, the fixed seed, the tone high ground
## drifted toward, the sand the coast took, how far that sand reached inland, how much swell the ring
## behind the shore got and how much a cliff got. **Every one of them was read only by the builder that
## left with the move to `island.glb`**, so each occurred exactly once, at its own declaration.
##
## ⚠ **`HILL_AMP_TILES` STAYED and it is not sentiment.** `terrain_height_ceiling()` adds it to the
## tallest legend height to find where the view ray starts its walk down, so it is load-bearing for
## every press on the ground — and `net_fx_view` reads it to bound how far the baked top surface may
## vary. The amplitude is a fact about the mesh; the dials were instructions for making one.
##
## ⚠⚠ **The shape they made is now the BAKE's promise, not this file's.** A rung about two tiles wide,
## the coast reading as sand rather than as pale grass, a cliff that undulates less than a meadow: none
## of that is measured anywhere any more. `tools/blender/island_build.py` either honours it or does not.

## ⚠⚠ **How wide the open sea is, in tiles, and it exists because the board turns.** The terrain mesh
## runs `WATER_MARGIN_TILES` past the grid, which was enough while the view was a screen-aligned
## rectangle — turn it 45 degrees and the view's corners reach past that square, and **the first turned
## capture of this port had black wedges in all four corners.** One flat quad under everything at the
## water's own height costs two triangles and covers every yaw at every zoom.
const SEA_SPAN_TILES := 400.0
## ⚠ **How far the open sea sits BELOW the water tiles, and it is not zero for a measured reason.** At
## exactly the same height the quad and the tiles fight for the depth buffer and the sea draws as a
## hatched stripe — seen in the capture that added it. Low enough that the step where the two meet is
## under a pixel at `ZOOM_MAX`, high enough that no card gets the comparison wrong.
const SEA_DROP_TILES := 0.03
## **How high the open sea sits, in tiles.** ⚠⚠ **It was 0 — the plane was left where it was built**
## (2026-08-28, the user: 「물 높이를 좀 더 올려줄래?」). Raising it swallows more of the shore's roll, so
## less bare rock stands between the water and the grass, and the island reads as sitting IN the sea
## rather than on it.
## ⚠ **The ceiling is the walking surface**, which is `base_h` out of the island file — go past it and
## the sea closes over the ground bodies stand on. At 0.20 base that leaves real room; on a lower
## island this is the number that has to come down with it.
const SEA_Y_TILES := 0.075

## How far one key press turns the board. **The board turning is the hand moving during a fight**, and
## that is 티켓 07's whole question — this is the knob that lets it be answered by trying it.
const CAM_YAW_STEP_DEG := 15.0

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
const ZOOM_MIN := 0.50
## ⚠ **RAISED 0.45 -> 0.50, which is that paragraph's OWN measured ceiling and not past it** — above
## 0.50 the vertical margin disappears and `_clamp_cam` has nothing to centre into. It buys 11%, and
## 11% is all this lever has: **the survey has to show the whole island, so the island's size is what
## bounds it.** The rest came out of the sprite ratio above.
## ⚠⚠ **Raised 1.0 -> 2.2** (2026-08-26, the user: 「좀 더 확대할 수 있어야 하고」). The old ceiling was
## reasoned as "one tile is 40 px, today's scale — never zoom in past that, nothing is gained". That was
## written when the ground was drawn in 2D and there was genuinely nothing more to see. **The island is
## an authored mesh now**: its coast, its rim and the buildings on it all carry detail that only exists
## above that line.
const ZOOM_MAX := 2.2
## ⚠ **Degrees of yaw per pixel of right-drag.** At 0.5 a screen-width drag spins the board more than
## three full turns and the hand loses where north was; at 0.05 it takes four drags to see the far side.
## This is a bit over half a turn across the window, which is the range a single drag can hold.
const CAM_YAW_PER_PX_DEG := 0.18

## ⚠⚠ **THE DRAWN BLOB AND ITS FOUR NUMBERS ARE DELETED** (2026-08-26). `COL_BLOB`, `BLOB_SPREAD`,
## `BLOB_SPREAD_BUILD`, `BLOB_DARK_BUILD` and `BLOB_SLIDE` stood here, each with a measurement behind it,
## and every one of them was tuning a workaround for a bug that is now fixed — see `CAM_FAR_TILES`. The
## disc pointed nowhere while the real shadow pointed away from the sun, and it slid TOWARD the sun
## rather than away from it. ⚠ **Do not reintroduce it**: one sun, one shadow per object.
const ZOOM_STEP := 1.15

## --- the survey ---------------------------------------------------------------------------------
## ⚠⚠ **An island no longer opens at `ZOOM_MIN`; it opens at whatever zoom SHOWS IT.** `ZOOM_MIN` was
## measured against one map size — 48 x 32 — and it was therefore a promise about that map and nothing
## else. The long map is 144 wide and has never fitted on screen at 0.50; a small map would open with
## the island as a stamp in the middle of an ocean, which is the exact opposite of what shrinking it
## was for. **The survey is a QUESTION about the grid in front of it**, so it is computed from that
## grid, and `ZOOM_MIN` / `ZOOM_MAX` go back to being only what the wheel may reach.
##
## `SURVEY_MARGIN` is how much wider than the island the opening view is. Below 1.0 the island is cut
## off; at exactly 1.0 it touches all four edges and `_clamp_cam` has a zero-length range to centre
## into, which is the failure `ZOOM_MIN`'s own paragraph records at 0.5625. 1.15 leaves a shore.
const SURVEY_MARGIN := 1.40
## ⚠⚠ **RAISED 1.15 -> 1.40** (2026-08-25, the user: 「처음 시작할떄 가메라 좀더 뒤에서 시작할 수
## 있게해줘」). **This is the margin term and nothing else moved** — `ZOOM_MIN`, `ZOOM_MAX` and the
## pitch's sine are all untouched.
##
## ⚠⚠ **AND IT HAD TO PASS 1.231 BEFORE THE FIRST ISLAND MOVED AT ALL.** Island 4 is 26 x 20, so at
## 1.15 the formula wants 1.07 and is **capped by `ZOOM_MAX`** — the opening view was not the survey's
## answer, it was the ceiling. Nothing under `1280 / (26 x 40) = 1.231` changes that island by one
## pixel, which is why a small nudge was not an option.
##
## ⚠ **The boat fix is NOT what the user is reacting to, and this does not undo it.** That fix replaced
## a cosine with the pitch's sine in this same derivation. Re-measured across all six grid sizes: it
## moved **exactly one island** — island 5, 0.9730 -> 0.9938, 2% tighter — and **island 4 not at all**,
## because both formulas clamp it at `ZOOM_MAX`.
##
## **What 1.40 does**, and the body size is quoted with it because the two are read in one glance:
##
## | island | zoom | wolf on screen | one tile |
## |---|---|---|---|
## | **4, the first node** | 1.000 -> **0.879** | 49.0 -> **43.1 px** | 40.0 -> 35.2 px |
## | the hand-written 48 x 32 | 0.580 -> **0.500** | 28.4 -> 24.5 px | 20.0 px |
## | the long map | 0.500, unchanged | — | already on the floor |
##
## The first island goes from filling **81% of the width and 71% of the height** to **71% and 63%**.
##
## ⚠ **The 48 x 32 islands land exactly ON `ZOOM_MIN`, and that is that constant's own framing** — its
## paragraph calls 0.50 the ceiling at which a 48 x 32 island still keeps a vertical margin for
## `_clamp_cam` to centre into. **Nothing derived from `ZOOM_MIN` moved** (`WATER_MARGIN_TILES`,
## `CLIFF_FACE_WIDTH_PX`), because `ZOOM_MIN` itself did not.
##
## ⚠⚠ **It cost `net_camera` a guard and the guard was re-anchored rather than deleted.** That file
## asserted the opening zoom is *not* the `ZOOM_MIN` constant by checking it sat 0.05 above the floor —
## true at 0.580 and false at 0.500. **Any margin past ~1.21 breaks it**, so the claim moved to a grid
## that does not clamp. A survey that is only ever the floor cannot be told from a constant, and that
## distinction is the whole reason this function exists.


## The zoom an island of this many tiles opens at. Both axes, because a wide map binds on width and a
## tall one on height, and the vertical is multiplied by `sin(pitch)` for the same reason
## `_visible_ground_px` divides by it — the ground is leaning away, so a tile of ground reaches the
## glass `sin(pitch)` of a tile tall.
##
## ⚠ **It was `cos(pitch)` and that was the same defect `_visible_ground_px` carried** (2026-08-25).
## Here it only ever framed an island wider than it had to; there it aimed every press. **Both are the
## one formula and they are corrected together** — leaving this one would be the same number written
## two ways again.
static func survey_zoom_of(w_tiles: int, h_tiles: int) -> float:
	if w_tiles <= 0 or h_tiles <= 0:
		return ZOOM_MIN
	var wide := float(w_tiles) * TILE_PX * SURVEY_MARGIN
	var tall := float(h_tiles) * TILE_PX * SURVEY_MARGIN
	var by_w := VIEWPORT_W_PX / wide
	var by_h := VIEWPORT_H_PX / (tall * sin(deg_to_rad(CAM_PITCH_DEG)))
	return clampf(minf(by_w, by_h), ZOOM_MIN, ZOOM_MAX)

## ⚠⚠ **THE WORLD-WIDTH TABLE. Every stroke `field_view` draws is multiplied by `zoom` before it
## reaches the canvas, and an island OPENS at `ZOOM_MIN`** — `field_view.setup` sets it and the whole
## plan is authored there, so `ZOOM_MIN` is the zoom a mark has to be legible at, not an edge case.
##
## The arithmetic: this file's snap floor is **2.0 canvas px** (see the combat-juice banner for why),
## so a WORLD-space width must be **>= 2.0 / 0.45 = 4.45**, and the two constants that already did
## this sum chose **5.0** (= 2.25 px). Every world width in this file is now on one of two sides:
##
##   ABOVE THE FLOOR (5.0 or more)   SHOT · BURST · AREA_RING · LAND_RING · ROUTE · REFUSE_MARK
##   DELIBERATELY BELOW              TARGET_LINE · SPARK — each carries its own reason on its own
##                                   line, and the reason is the whole licence
##   (BODY_OUTLINE · CLIFF_FACE · GRID_LINE · the beak mark left this table with the 3D move: the field's
##   body became a baked texture — BODY_OUTLINE_WIDTH_PX lives on for the refit screen's drawn body,
##   in HUD space where the snap floor bites raw — the cliff line became mesh, and the other two
##   were deleted with zero readers.)
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

## ⚠ **The grid lines are GONE with the flat board and so are their two constants**
## (`GRID_LINE_WIDTH_PX` · `COL_GRID_LINE`, deleted 2026-08-24 with zero readers left): the 3D field
## draws no lattice, and position is read off the terrain itself.


# ---------------------------------------------------------------------------------------------
# Colours — the only `Color(` literals in the tree
# ---------------------------------------------------------------------------------------------

# Terrain. Three tones plus the harbour marker, and the hole has to read as "cannot walk here" at a
# glance. `boat-and-landing` renamed the dock to a harbour (water a boat sails from, not a fixed
# port) and deleted the `D` legend character; the colour is the same value under its new name.
## (`COL_HARBOUR` and `COL_GRID_LINE` were deleted 2026-08-24 — the harbour marker and the lattice
## both died with the flat board and nothing read either.)
## ⚠⚠ **Re-pitched off the reference picture the user supplied** (2026-08-26): a soft grey-green sea,
## not a navy one. The old navy read as night and fought the pale khaki island for attention.
## ⚠⚠ **Darkened 2026-08-26** (the user: 「먼바다는 진하게 가자, 깊은 데 사실상」). The open sea was
## within a shade of the sky and of the shallows, so the pale band around the island read as a glow
## rather than as shallow water. **Depth is told by contrast**: the shallows can only look shallow
## against water that looks deep.
const COL_WATER := Color(0.255, 0.375, 0.410)
## ⚠⚠ **RAISED 2026-08-25 — it was `(0.203, 0.259, 0.184)` and that is not a green on screen.** The
## ambient is a cold blue-grey (`COL_AMBIENT`) and a near-grey green under it comes out as **stone with
## a tint**, which is what made a whole island read as one washed slab. Saturation up and value up: the
## island has to say *grass* before it says anything else, because grass is what the rock wall and the
## sea are told apart FROM.
const COL_LAND := Color(0.235, 0.373, 0.196)
const COL_HOLE := Color(0.055, 0.067, 0.078)

# Cliff and ramp (`boat-and-landing` stage 5, P10). `^` gets its OWN fill now instead of reusing
# COL_HOLE — 3.2 still holds (a cliff is exactly as impassable as a hole), only the picture stops
# saying the two are the same terrain. `COL_CLIFF_FACE` is the seaward-edge line, one tone darker so
# it reads as a drop rather than a second outline. `/` (ramp) is passable land with its own tint so
# the one doorway through a cliff wall does not read as ordinary ground.
## ⚠⚠ **RAISED for the 3D field** (2026-08-24). It was 0.098 — near black — and that was right on a flat
## canvas where a cliff was a FILL and the eye only had to tell it from land. Standing up as a real wall
## it is a large lit surface, and near-black reads as **a hole cut in the island** rather than as rock:
## the first captures of the port show the whole south coast as one black slab. Rock grey, still the
## darkest thing on the island, still unmistakably not walkable.
## (`COL_CLIFF_FACE` was deleted 2026-08-24: the seaward-edge line it painted became a real wall in
## the terrain mesh, told from the top face by its own darkened skirt.)
const COL_CLIFF := Color(0.243, 0.235, 0.251)
const COL_RAMP := Color(0.361, 0.310, 0.235)

## --- the tile rim, and the sea wall's colour: BOTH DELETED 2026-08-27 -------------------------------
## ⚠⚠ **THE MESH IS BAKED IN BLENDER NOW AND IT ARRIVES WITH ITS OWN BEVEL AND ITS OWN COLOURS.**
## Six constants stood here — the rim's width, its three per-edge darkenings, the sea wall's rock
## colour and how far that colour sank at the wall's foot. Every one of them was read by the code that
## built the ground mesh in GDScript, and that code left with the move to `island.glb`. What was left
## was six numbers each occurring exactly once, at its own declaration.
##
## ⚠ **The REASONING they carried is not deleted, because it is not about these numbers.** Bad North's
## rule is *borders, not textures*, and which edges differ is what carries the information: same-height
## neighbour barely there, a step strong because that is where a body can and cannot walk, the sea edge
## strongest of all. **That rule now has to be honoured by the bake**, and `tools/blender/island_build.py`
## is where it is either obeyed or quietly dropped.

## The one tile of a tier boundary a body may climb (티켓 19). **Its own colour and NOT `COL_RAMP`
## reused**, for a measuring reason as much as a visual one: `net_fx_view` picks terrain vertices out
## of the mesh BY COLOUR, so two things sharing a tone are two things no check can tell apart. A ramp
## is a doorway through a cliff wall and a stair is the way up a tier; they are different rules and
## they get different tones.
##
## ⚠ **Lighter than the ramp and warmer than the land.** It has to be findable at `ZOOM_MIN` from 40
## degrees — 「계단이 어디인지 찾을 수 있다」 is one of the things the eye is asked for on this ticket,
## and a stair is one tile on a board of hundreds.
const COL_STAIR := Color(0.588, 0.502, 0.318)

# Bodies. Friend and foe are told apart by COLOUR; the unit type is told apart by SIZE and by how
# round its corners are — see BODY_RADIUS_RATIO and BODY_CORNER_RATIO.
const COL_ALLY := Color(0.451, 0.847, 1.0)
const COL_ENEMY := Color(1.0, 0.420, 0.361)

# HP. The old game died partly because nothing on screen ever went down; the empty half is drawn
# so the bar has a length before it is hurt.
const COL_HP_FULL := Color(0.400, 0.898, 0.451)
const COL_HP_EMPTY := Color(0.118, 0.141, 0.141, 0.851)

# Boats. One tone for every hull, because after `plan-then-watch`'s 결정 14R nothing distinguishes
# two boats: a boat exists between one drag and one round trip, and there is no fleet to tell apart.
# ⚠ `COL_BERTH_EMPTY` died with the berths — there is no resource meter to empty, because the boat
# stopped being a resource. The thing that visibly goes down is now the stack of soldiers standing at
# the harbour — ⚠ **and that stack is deleted too** (`sea-summon`, the user's *"ㅇㅇ 지워줘"*). What
# visibly goes down now is a slot's own bar in `hud_view`, which is a COUNT of bodies still in it.
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
## ⚠ **Deliberately NOT `COL_START` / `COL_WIN` re-typed.** Those are a press, a
## verdict and a map node; a value shared by two concepts diverges the first time one of them is tuned.
##
## ⚠ (`COL_SUMMON_BAND` was deleted 2026-08-24. It washed every summonable water tile green; the
## user cut the wash — 「초록색이 있을 필요는 없다」 — and the band became the drawn circle below.
## It survived a while 「so the checks that still name it keep parsing」, and the ticket-09 net refit
## removed the last of those names.)

## **The ring on the water: where a boat may be put down.** Pale and cool rather than green — it is a
## boundary drawn ON the sea, and a tinted sea was exactly what it replaced. It has to read against
## `COL_WATER` at `ZOOM_MIN` and against nothing else, because it never crosses land.
const COL_SUMMON_RING := Color(0.706, 0.902, 1.0, 0.85)

## ⚠⚠ **THE HOVER MARK'S CONSTANTS ARE DELETED WITH THE MARK (2026-08-28) AND 티켓 14 HOLDS THEM.**
## `HOVER_PLATE_LIFT_TILES`, `COL_HOVER_PAD_LIT`, `HOVER_RIM_TILES`, `COL_HOVER_PLATE`, `COL_HOVER_RIM`
## and `COL_HOVER_DROP` all tuned a mark that no longer exists — the mats became terrain and there is
## no per-mat node to raise. **A constant nothing reads is a value that rots**; the numbers that were
## on screen and worked are written into the ticket instead.



## ⚠⚠ **`COL_WASH` AND `COL_WASH_RIM` ARE DELETED (2026-08-28) AND THE MAT IS STILL THERE.** They
## coloured a white quad laid over every walkable tile. **The mat is baked into the island now** — the
## bake paints each piece's own flat interior lighter (`PAD_LIGHTEN` in `island_build.py`), so the mat
## is the walking surface itself and has no colour of its own to name here. The user's words that
## killed them: 「위에 노드만 살짝 얹은 느낌이어서 너무 별로」·「너무 흰색이 너무 잘 보여」.
## ⚠ **What survives below shapes the HOVER's mask**, which is still drawn at runtime.

## **How many tiles across one mat is.** ⚠⚠ **2, because the island is BUILT that way** —
## `tools/blender/island_build.py` lays the whole island down as 2x2 pieces, and a raised block is
## always a whole piece. A mat per TILE was on screen once and the user's word was 「너무 많으」; mats
## grown freely from seeds were on screen once and the word was 「맘대로 되어있는」. **Two rejections,
## and the piece is what both of them point back to.**
## ⚠ The blocks start at tile 0, the same corner the bake starts from — offset them and every mat
## straddles two pieces.
const WASH_BLOCK_TILES := 2

## How thick that ring is, in tiles. Under about 0.2 it disappears at `ZOOM_MIN`; over about 0.8 it
## stops being a line and starts being a band, which is the picture it exists to replace.
const SUMMON_RING_W_TILES := 0.45
## ⚠ **`SUMMON_RING_SEGMENTS` was deleted 2026-08-27** — it sampled a circle that stopped being built
## when the band ring lost its mesh, and it occurred exactly once, at its own declaration.

## **The sea, as two tones a shader moves between.** `COL_WATER` is the trough; this is the crest.
## ⚠ Close together on purpose: the sea is the background this whole game is read against, and water
## that draws attention is water that competes with the ten bodies fighting on top of it.
const COL_WATER_CREST := Color(0.330, 0.455, 0.485)
## How wide one swell is (in tiles, inverted) and how fast it travels. Slow — a fast sea reads as a
## flowing river, and this one is meant to sit still enough to plan on.
## ⚠⚠ **Chosen by eye from six candidates rendered side by side** (2026-08-26). The user: 「적당히만
## 다르면 될 듯」 — the two that changed the sea's COLOUR or its contrast hardest were rejected for being
## too far from what was there; this one is bigger, slower swell and nothing else.
const WATER_WAVE_SCALE := 0.14
const WATER_WAVE_SPEED := 0.13
## ⚠⚠ **How far apart the two sea tones are pushed at the crest** (2026-08-26, the user: ***"물 자체가
## 임팩트가 있는 건가?"***). The shader was written deliberately quiet on the reasoning that the sea is
## the background bodies are read against, and quiet turned out to mean invisible — the surface read as
## one flat colour. This lifts the crest away from the trough beyond the two constants above, which are
## still only a few percent apart.
const WATER_CONTRAST := 2.6

## --- the ripple the light catches ------------------------------------------------------------------
## ⚠⚠ **What a shop-bought water shader would call its normal map.** Three sine waves gave the sea a
## shape but no surface: the swell was visible and the water between the crests was a flat colour, and
## that is what read as "just code" (2026-08-26, the user: ***"물 자체가 임팩트가 있는 건가?"***).
## Sea of Thieves solves it with four scrolling noise maps; this is the same idea evaluated instead of
## sampled, which costs a little more and owes nothing to an asset store.
## How many ripples per tile. Above about 3.5 they fall under a pixel at ZOOM_MIN and turn to noise.
## ⚠⚠ **THE WHOLE RIPPLE SET WAS RETUNED 2026-08-28** (the user: 「물주름도 한번 개편해줘」). Finer,
## slower, weaker and less chopped: the old set drew a busy crosshatch that competed with the island
## for the eye, on a screen whose subject is the ground. **Five numbers moved together and they only
## make sense together** — scale 1.9 -> 2.6, speed 0.14 -> 0.10, strength 4.2 -> 2.6, stretch 0.34 ->
## 0.24, chop 2.6 -> 1.6.
## ⚠ **티켓 05 asks how broken the ripples should be and it is the USER's pick, not this file's.** This
## is a candidate to look at, not the answer to that ticket.
const WATER_RIPPLE_SCALE := 2.6
## How fast the two noise layers drift apart. Slow: a ripple that races reads as rain, not as sea.
const WATER_RIPPLE_SPEED := 0.10
## How hard the ripple bends the surface normal. ⚠ **This is the whole dial between "glassy" and
## "choppy"** — at 0 the sea is the old flat colour and at 4 it boils.
## ✅ **Raised to what the approved screenshots were actually rendered with** (2026-08-26). ⚠ The sheets
## the user picked from were shot at this value, not at the 1.6 that was in this file — shipping the
## older number would mean the game never looked like the picture that was approved.
const WATER_RIPPLE_STRENGTH := 2.6
## ⚠ **How far from the camera the ripple fades out, in world units.** Detail finer than a pixel is not
## detail, it is fizz — and the far sea is exactly where a repeating pattern gets spotted
## (2026-08-26, the user: 「줌을 뒤로 땡겼을 때 바다에 패턴이 보이는 문제가 있음」).
const WATER_RIPPLE_FADE := 46.0
## ⚠ **Which way the wind runs.** Ripples are long ACROSS the wind and short along it; without a
## direction the noise is round, and round noise on water reads as fog or as marble.
const WATER_RIPPLE_WIND_DEG := 24.0
## How far they are drawn out along that wind. 1.0 is round; under about 0.5 they become streaks.
const WATER_RIPPLE_STRETCH := 0.24
## How hard the streaks are chopped into lengths. 0 leaves them running the whole sea; above about 3
## they stop being streaks and become speckle.
## ✅ **Looked at 2026-08-28 and the dial turned out not to matter.** Seven candidates went up side by
## side and **the four that only moved this and its neighbours were indistinguishable** — the ripple bent
## the surface normal and nothing else, so every setting came out as the same haze. **What the user
## picked is `WATER_RIPPLE_CRISP` below, which draws the crests instead**, and this number is now only
## the shape of the noise underneath it. ⚠ **The lesson is not about this constant**: a candidate sheet
## was rendered twice on an axis nobody had checked could change the picture.
const WATER_RIPPLE_CHOP := 1.6
## ⚠⚠ **How hard the ripple is DRAWN rather than lit.** Every dial above bends the surface normal and
## leaves the light to reveal it; on a board of flat cartoon blocks that comes out as an airbrushed
## haze, which is what a sheet of seven candidates measured (2026-08-28). This lays the crests into the
## water's colour as hard pale lines instead.
## ✅ **PICKED BY EYE 2026-08-28** (the user: 「6번이 좋을듯」). Candidates 1 to 5 moved the old dials —
## chop, scale, strength, stretch — and all five rendered as the same haze; the two that DREW the crests
## were the only two that were a different picture at all.
const WATER_RIPPLE_CRISP := 0.70
## Where along the ripple a drawn line begins, read against the crest mask and not against the ripple
## itself. ⚠⚠ **Measured, not guessed** (2026-08-28): the mask averages about 0.5, so this picks roughly
## the top fifth of the crests. Two earlier attempts drew nothing at all — 0.62 against the ripple value,
## whose average is 0.33 — and a candidate that renders identically to the one it is compared against is
## the failure this file exists to stop.
const WATER_RIPPLE_CRISP_EDGE := 0.58
## ⚠⚠ **How unevenly those lines are spread across the sea, and the user asked for this in the same
## breath as picking it** (2026-08-28: 「계속 막 뭐랄까 일관적이면 안 되고 랜덤해야함 넓게」). An even
## field of crests is a texture rather than a sea. At 0 every stretch of water works equally; at 1 the
## quiet stretches go bare.
const WATER_RIPPLE_CRISP_PATCH := 0.85
## How wide one such stretch is, in inverted tiles — about 12 tiles across at 0.08. ⚠ **Wide is the
## point**: at anything near the ripple's own scale this and the chop only make speckle together.
## ⚠⚠ **There is a CEILING on wide, and it was measured** (2026-08-28). At 0.04 a stretch is 25 tiles,
## which is most of what the camera holds — so the whole screen falls inside one stretch and the sea is
## either all working or all quiet, which is the evenness this was added to break. **Several stretches
## have to fit in frame or there is nothing to be uneven against.**
const WATER_RIPPLE_CRISP_PATCH_SCALE := 0.08

## --- the wash where the sea meets the land ---------------------------------------------------------
## ⚠⚠ **The shoreline is drawn BY THE SEA, and that is the second answer to a question that failed
## once.** A bright ring was built as a mesh laid on the water and it read as a white plate: an object
## floating on the surface, because that is what it was. **This band is part of the water itself** —
## the sea shader is handed how far every point is from land, and it foams where that distance is
## small. Nothing is placed, so there is nothing to be seen lying on top.
##
## ⚠ **It breathes.** A still band is a painted edge; the user asked for ***"바닷물이 첨벙첨벙하면서
## 올라오는"***, and a band whose width moves is the cheapest thing that reads as water running up a
## shore and back.
const COL_WATER_FOAM := Color(0.880, 0.930, 0.945)
## ⚠⚠ **The shallows — what actually joins the land to the sea** (2026-08-26, the user: 「땅하고 바다하고
## 부드럽게 이어져서 바다 주름이 좀 괜찮게 보이는 거를 목표로」). ⚠ **This is NOT the sloped beach coming
## back**: the ground still ends at a straight wall, exactly as decided. The join is made in the WATER,
## by the sea paling over a stretch as it comes up to the land, which is what a real shore does and what
## a hard edge between two flat colours never will.
## ⚠ Kept close to the sea's own tone, only lighter and a shade greener. Far from it and this becomes the
## white plate the mesh band already failed as.
const COL_WATER_SHALLOW := Color(0.560, 0.700, 0.690)
## How wide that stretch is, in tiles. **Several times the foam's reach**: the foam is the last hand's
## width of water and this is the approach to it.
const WATER_SHALLOW_TILES := 3.2
## ⚠⚠ **How strongly the shallows show — and the reason this constant is new is that they were NEVER
## DRAWN** (found 2026-08-28). `COL_WATER_SHALLOW` was chosen on 2026-08-26, handed to the shader, and
## commented in three places; `shallow.rgb` appears nowhere in the shader's entire history. **Everything
## about the feature existed except the line that paints it.** The width above was doing one real job —
## steepening the ripple near the shore — which is why nobody noticed the colour was missing.
## ⚠ Kept well under 1: the shallows are the approach to the shore, not a second shore.
## ⚠⚠ **BACK TO 0 the same day it was first drawn** (2026-08-28, the user: 「물가하고 거품만 계산하면
## 됐든」, then on seeing it: the island wore a soft halo instead of a thin line). At 0.55 the shallows
## are a wide pale glow round the whole coast, and it competes with the one thing the user actually
## asked for — a thin line on the outline that breathes. **0 is what every screen the user has judged so
## far looked like**, because the colour was never painted until today.
## ⚠ The width above still does its other job at any strength: it steepens the ripple near the shore.
const WATER_SHALLOW_STRENGTH := 0.0
## How far out the foam reaches at its widest, in TILES. Under about 0.2 it is a line rather than a
## wash; over about 1.2 it stops looking like a shore and starts looking like shallow sea.
## ⚠⚠ **How far out the travelling wave LINES live, in tiles** (2026-08-26). The shore used to be one
## band that widened and narrowed as a whole, and the user saw it at once: 「다 똑같이 움직이니까
## 이상함」. It is now the standard shoreline shape — a gradient off the land run through a cosine, so
## there are several lines at once and each one moves inward. This is the stretch they live in.
## ⚠⚠ **Widened 2026-08-28 from 2.6** with the window below: the lines now live across their reach
## instead of in a ring one third of a tile thick, so the reach is what is actually seen.
const WATER_FOAM_TILES := 2.2
## How fast a line travels in, in cycles per second. **Slow**: a shore washes about once every three
## seconds, and faster reads as a flicker.
const WATER_FOAM_SPEED := 0.28
## How many lines are inside that reach at once. Above about 4 they crowd into stripes.
const WATER_FOAM_BANDS := 1.2
## How thin each line is. It is an exponent on a cosine: 1 is a soft gradient, 8 is a hard edge.
## ✅ **Chosen by eye from four thicknesses** (2026-08-26, the user: 「3번이 적당하네」). ⚠ **A high
## exponent is the CHEAP way to a thin line** — it costs one `pow` and no extra sampling — but it also
## means the line's width is not a distance anybody can read off this number. If the shore ever has to
## be a measured width, this is the wrong dial.
## ⚠⚠ **Softened 2026-08-28 from 26.** At 26 a line was a wire — under a pixel wide at this camera and
## invisible at anything but a close zoom.
const WATER_FOAM_SHARP := 16.0
## ⚠⚠ **How far the phase drifts ALONG the coast, in radians — the thing that stops the lines being
## concentric.** At 0 every stretch of shore crests at the same instant, which is the defect this
## replaced. Near π the two sides of a headland are in opposite phase.
## ⚠⚠ **Raised 2026-08-28 from 3.1, with the scale below.** Once the gate stopped switching whole coasts
## off, the lines came out as **parallel contours round the island** — a map, not water. The phase break
## is what bends them out of step with one another, and at the old scale it was too coarse to bend
## anything on an island this size.
## ⚠⚠ **Brought back DOWN to 0.9 on 2026-08-28** (the user: 「너무 깨지면 안 되고 ... 그냥 안 깨졌음
## 좋겠는데? 깔끔하게 했으면 좋겠는데?」). It had just been raised to 4.5 to break concentric contours,
## and the answer to the contours was the wrong one: what the user wants is a clean line that bends a
## little, not a line torn into pieces. **The evenness is handled by the gate floor instead.**
const WATER_FOAM_BREAK := 0.9
## How quickly that drift changes as you walk along the coast. Small: a stretch of shore has to act
## together over a few tiles or the lines shatter into speckle.
const WATER_FOAM_BREAK_SCALE := 0.35
## ⚠ **The thin permanent lip right at the land**, separate from the lines. Water always touches the
## shore; the lines are what runs up over it.
## ⚠⚠ **Thinned 2026-08-28 from 0.18** (the user: 「얇고 투명하고 조금 티가 나게」).
## ⚠ **This is the width at REST and `WATER_FOAM_LIP_WOB` swings it either side**, so at 1.0 the line
## runs from nothing to twice this. Read the two together or the thickness on screen is a surprise.
const WATER_FOAM_LIP_TILES := 0.06
## ⚠⚠ **How hard that lip's outer edge is, and 0 is the fade it was born with.** The band was
## `1 - smoothstep(0, w, d)`, which starts dying the instant it leaves the rock — so what stood at the
## coast was a soft halo, and an island wearing a soft halo reads as glowing rather than as wet. At 1
## the band holds its full strength almost to its edge and then stops.
const WATER_FOAM_LIP_HARD := 0.0
## ⚠⚠ **How opaque the lip is where it is strongest, and it was a literal `0.85` in the shader.** The
## user asked for the line to be **얇고 투명하고 조금 티가 나게** (2026-08-28) — noticed, not announced.
## At 0.85 it was very nearly the foam's own white and read as a sticker cut round the island.
const WATER_FOAM_LIP_ALPHA := 0.28
## ⚠⚠ **How opaque the travelling lines are at their strongest, and it was a literal `0.95` in the
## shader** — the foam colour very nearly undiluted. **In the reference picture the user supplied
## (`docs/reference/2026-08-27-bad-north-two-storey-island.png`) the surf is barely lighter than the sea
## it lies on**, which is most of why it reads as water and this read as a stroke.
## ✅ **Cut on 2026-08-28** (the user: 「조금 과하긴 해 저 거품이」 and then 「거품은 조금만 있어도 될 거
## 같아, 얇게」). **Fewer lines and thinner ones, not fainter ones** — the reach and the count came down
## with it, and the opacity went back UP a little: a line too faint to see is not a thin line, it is a
## missing one.
const WATER_FOAM_ALPHA := 0.40
## ⚠⚠ **How much the lip's width swings — and a still lip is the reason it read as a sticker no matter
## how thin it got** (2026-08-28, the user: 「물가가 유동적으로 움직여야 좀 제대로 보이고, 얇아졌다가
## 약간 두꺼워졌다가 떨어져 나갔다가 하는 게 중요할 듯」). **Thinner and fainter were both tried first and
## neither worked**, because the thing being recognised is not the line's size, it is that water does not
## hold still. At 1 the width swings from nothing — a real gap in the line — to double.
## ⚠ **Brought down from 1.0 on 2026-08-28** (the user: 「너무 두꺼워졌다가 얇아졌다가 하고 있고」). The
## swing was doing all the work on its own; the peel below now carries most of the movement, so the
## shore's own line can hold a steadier width.
const WATER_FOAM_LIP_WOB := 0.55
## How long a stretch of coast shares one width, in inverted tiles — about 4 tiles at 0.25 — and how fast
## that width changes. ⚠ **Slow.** A line that flickers reads as a fault, not as a shore.
const WATER_FOAM_LIP_WOB_SCALE := 0.25
const WATER_FOAM_LIP_WOB_SPEED := 0.11
## ⚠⚠ **How strongly the shore lets a line GO** (2026-08-28, the user: 「가끔씩 두 줄이 되기도 하면 좋을
## 거 같은데 ... 멀어지면서 사라지는 거 있잖아. 진짜인 것처럼」). Once a cycle, over patches of coast, the
## line separates from the rock and travels seaward, fading as it goes. **The two lines are the same
## line at two ages**, which is what backwash actually looks like.
const WATER_FOAM_LIP_PEEL := 0.85
## How far a peeled line gets before it is gone, in tiles. ⚠ Short: past about a tile it is out in open
## water and reads as a stray mark rather than as water leaving a shore.
const WATER_FOAM_LIP_PEEL_TILES := 0.75
## ⚠⚠ **The hairline that is always there, in tiles** (2026-08-28, the user: 「해안선에 붙어있는 라인은
## 꼭 있어야 돼 ... 진짜 얇게 하나는 꼭 유지됐음 좋겠어」). The swash and the peel can both take a stretch
## of shore down to nothing, and on the frames where they did the coast had no edge at all. **This much
## is drawn no matter what they are doing.**
## ⚠⚠ **It is a LINE and it is drawn on its own** — flat across its width, hard at its outer edge, and
## carrying its own opacity below. The first attempt folded it into the soft wash and what came out was
## a permanent glow, which is not what was asked for: 「딱붙어있는 얇은선이 필요하다는건디」.
## ⚠⚠ **THERE IS A FLOOR AND IT IS MEASURED: below about 0.04 the line breaks into dots.** At 0.030 the
## band is thinner than the shore's own curvature across one screen pixel and the line came out dashed —
## a defect, not a thinner line. **0.045 is just above that, and the way to go thinner is a finer field,
## not a smaller number here.**
const WATER_FOAM_LIP_MIN_TILES := 0.045
## ⚠ **Its own opacity, well above the wash's.** The wash is faint on purpose so it does not read as a
## stroke; this one is meant to be seen, and it cannot borrow an opacity chosen to hide something.
## ✅ **Picked by eye from four** (2026-08-28). At 0.60 it reads as a marker pen round the island, which
## is the 「그냥 흰색 선」 this whole round has been walking away from.
const WATER_FOAM_LIP_EDGE_ALPHA := 0.32
## ⚠⚠ **Where inside its reach the travelling lines live, as fractions of `WATER_FOAM_TILES`.** These
## two were literals in the shader and they are the reason the lines could barely be found: 0.18 and
## 0.35 of a 2.6-tile reach put every line between 0.47 and 0.91 tiles off the coast, a ring one third
## of a tile thick. **The lines were drawn across the whole reach and then faded out over nearly all of
## it.** `IN` is how quickly they come up out of the shore, `OUT` is where they start dying toward the
## open sea.
const WATER_FOAM_FADE_IN := 0.10
const WATER_FOAM_FADE_OUT := 0.70
## ⚠⚠ **How wide a stretch of coast the gate can switch off, in inverted tiles — about 2 tiles at 0.5.**
## The gate exists so a coast has surf here and flat water twenty metres along; it was sampled at
## `WATER_FOAM_BREAK_SCALE * 0.55`, which is a feature about **eight tiles** wide. **The island is
## sixteen tiles across**, so the gate held two features and turned the lines off down the entire west
## and south coast — found 2026-08-28 by painting the foam red, which showed surf living only off the
## north-east arm. **A gate as big as the thing it gates is not a gate, it is a switch.**
const WATER_FOAM_GATE_SCALE := 0.5
## ⚠ **How much surf a switched-off stretch keeps.** 0 empties it completely, which is what made the bare
## coast above so total. A floor leaves the quiet stretches quiet without leaving them dead.
## ⚠ **Raised 2026-08-28**: with the phase break turned back down, the gate is the only thing left that
## could tear the coast into working and dead stretches, and the user asked for clean.
const WATER_FOAM_GATE_FLOOR := 0.55
## ⚠⚠ **How hard the sheltered coast is spared.** Waves arrive FROM somewhere — the shore facing into
## the wind takes them and the lee shore is nearly flat. A ring of identical surf all the way round is
## what says nothing is actually arriving. Shares the ripple's wind direction on purpose: one weather.
## ✅ **Chosen by eye from four** (2026-08-26): all-round · gentle · this · strong. The user: 「3번이
## 맞긴 한데」.
const WATER_FOAM_LEE := 2.4
## ⚠⚠ **How far outside the tile grid the mesh's real waterline sits, in tiles** (found 2026-08-28, the
## user: 「지금 굴곡에 안 맞춰져 있는 게 보이고」). **The bake exports the square tile outline as the
## coast**, and the mesh's shore is a skirt hung outward and down from that boundary — `SKIRT = 0.46` in
## the Blender run. So the sea was measuring every distance from a line **half a tile inside the rock**,
## and the lip it drew lay under the island's own overhang, showing only where a chamfered corner pulled
## the mesh back.
## ✅ **0 SINCE THE BAKE STARTED EXPORTING THE REAL OUTLINE** (2026-08-28). It stood at 0.30 — measured
## by eye — for exactly as long as the exported coast was the square tile grid with the skirt missing
## from it. **The skirt is in the coordinates now**, so pushing the distance outward pushes the line off
## a shore it is already standing on: measured again from zero across four values, and every non-zero
## one floated the line out with a gap of water behind it.
## ⚠ **Left as a dial rather than deleted**: it is the one number that re-aligns the water to the land
## if the bake's shore ever moves again, and finding it took a round.
const WATER_SHORE_OFFSET_TILES := 0.0
## ⚠⚠ **How far the shore's sample point is dragged about before the distance is read, in tiles — and
## this is the answer to 「너무 그래픽적」** (2026-08-28, the user: 「이게 뭔가 흐름처럼 곡선이어야 되는데
## 이게 전혀 그런 게 없으니까」). **A band at a fixed distance from a line is that line's parallel offset**
## — no amount of softening, thinning or width-swinging changes that, because the SHAPE is still the
## island's outline scaled out. Warping where the distance is measured from is what breaks it, and it is
## the standard technique rather than one invented here.
## ⚠ Bigger than the lip's own width on purpose: below about 0.2 the band still traces the outline.
const WATER_SHORE_WARP_TILES := 0.35
## How wide a bend is, in inverted tiles — about 3 tiles at 0.33 — and how fast the bends travel.
const WATER_SHORE_WARP_SCALE := 0.33
const WATER_SHORE_WARP_SPEED := 0.06
## ⚠⚠ **This was briefly narrowed to 2.6 to buy precision and then put back, because the precision
## problem was somewhere else** (2026-08-28). The field was eight-bit — one level every `span/255`, or
## 0.0157 of a tile at 4.0, against a lip 0.06 wide — and the field is a float texture now, so the span
## costs nothing but reach. ⚠ **It must cover the widest thing that reads it**: `WATER_FOAM_TILES` plus
## `WATER_SHORE_OFFSET_TILES`, and `WATER_SHALLOW_TILES` whenever the shallows are turned back on.
## The farthest distance the field stores, in tiles. Everything beyond is "open sea" and identical.
const WATER_FIELD_SPAN_TILES := 4.0
## Texels per tile in that field. **1 is not an option**: the foam then steps square at tile edges,
## which is the grid drawn back in water.
## ⚠⚠ **Raised 2026-08-28 from 4 to 16** (the user: 「굴곡에 맞춰서 얇게만 있으면 되거든 ... 지금 굴곡에
## 안 맞춰져 있는 게 보이고」). **One texel was a quarter of a tile and the lip is a tenth of one** — a
## line thinner than the grid it is drawn on cannot follow a cut corner, so the coast's tilted corners
## came out stepped. ⚠ **The build had to be rewritten to afford this**: `set_pixel` per texel is an
## engine call a quarter of a million times, and it is a byte buffer now.
const WATER_FIELD_SUBDIV := 16

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
## ⚠⚠ **`COL_NODE_FIGHT` and `COL_NODE_BOSS` ARE GONE** (2026-08-26) with the node map itself. They
## were the last two colours in this file that belonged to a screen rather than to the board.
const COL_SLOT_OFF := Color(0.420, 0.420, 0.440)

# Combat juice. Every one of them is a colour no existing name can stand in for.
# Items 8, 9, 4 and the shake margin deliberately REUSE what is already above — COL_WIN / COL_LOSE,
# COL_BUTTON, COL_ALLY / COL_ENEMY, COL_WATER — because the same value under two names
# diverges the first time one of them is tuned.
const COL_FLASH := Color(1.0, 1.0, 1.0)
## What a bleeding body's colour is dragged toward. ⚠ **The VALUES here are eye values and this
## ticket does not judge them** — how red, and how dark, is `verify-look`'s to say.
const COL_BLEED := Color(0.42, 0.03, 0.06)
## Seconds of REMAINING bleed at which the pull reaches its full strength. The crow's own row lasts
## exactly this long, so a fresh bite reads at full and fades as the clock runs out.
const BLEED_TINT_SEC := 2.0
## How far the pull may go at full strength. **Not 1.0**: a body dragged the whole way to `COL_BLEED`
## stops being its own side's colour, and friend-and-foe-by-colour is the older rule.
const BLEED_TINT_MAX := 0.7
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

## (`COL_BODY_SHADOW` and `SHADOW_R_RATIO` were deleted 2026-08-24: the drawn ellipse they shaped
## was the flat board's way of faking contact, and the 3D sun casts the real shadow now.)


# ---------------------------------------------------------------------------------------------
# Bodies — an outline, a centre dot, nothing between
# ---------------------------------------------------------------------------------------------

## Indexed by the unit type id in rules.gd, and **one entry per row of `UNITS`** — nine now, and a
## sixth body standing on a five-entry array is an index off the end that stops the island drawing at
## all. Radius as a fraction of one tile. AT TILE_PX = 40 THESE ARE, IN ORDER:
##   0 SQUIRREL     0.22 ->  8.8 px
##   1 WOLF         0.35 -> 14.0 px
##   2 COW          0.45 -> 18.0 px
##   3 BEAR         0.50 -> 20.0 px
##   4 CROW         0.28 -> 11.2 px
##   5 SPEARMAN     0.35 -> 14.0 px
##   6 ARCHER       0.25 -> 10.0 px
##   7 SHIELDBEARER 0.40 -> 16.0 px
##   8 LION         0.55 -> 22.0 px
## ⚠ **Four of the nine are transplants** — the wolf, the crow, the archer and the shieldbearer carry
## the exact ratios their pre-rename rows had, for the reason `Rules.UNITS`' own header gives.
## Nothing here changes what happens, which is why body size is in this file and not in rules.gd.
##
## ⚠⚠ **HALVED 2026-08-25 — the row above is what these WERE** (the user: ***"타일 하나가 크고 그 안에
## 병사가 여덟 명은 들어가야 된다. 최소 네다섯 명"***). At 0.35 a wolf is **0.70 tiles across** and one
## body fills one tile, so the grid could never read as tiles a squad stands on — it read as a grid of
## single soldiers. At 0.17 a wolf is 0.34 tiles and **nine fit in one tile, four with room to spare**.
##
## ⚠ **This changes nothing about what happens and that is why it could be done at all**: `rules.gd`
## says so in its own header — every distance in the sim is centre-to-centre in tiles, and body radius
## is deliberately absent from it. Reach, pack radius, summon radius and the tiers are untouched.
##
## AT TILE_PX = 40 THESE NOW ARE, IN ORDER: 4.2 · 6.8 · 8.6 · 9.6 · 5.4 · 6.8 · 4.8 · 7.6 · 10.6 px.
## ⚠⚠ **The BODY got smaller in tiles; whether it gets smaller on SCREEN is the camera's business** —
## a smaller body on a grid the same size is a smaller picture, and the answer to that is fewer, bigger
## tiles (the user's 「타일을 좀 더 크게」), not a bigger sprite.
## ⚠⚠ **SET FROM ONE RULE, 2026-08-25: FOUR WOLVES STAND IN ONE TILE** (the user: ***"칸에 병사가
## 4마리정도 들어간걸 기준 한번 만들어볼래?"***). Four bodies in a tile is a 2x2, so a wolf may be at
## most **0.5 tiles across** and the ratio is half of that. 0.22 leaves a hair of gap so four wolves
## read as four rather than as one blob. Every other species is that same 1.29x off the row before it,
## so the herd keeps the proportions the user already judged: **the bear is still 0.62 across and
## still takes a tile to itself**, which is what a bear is for.
## ⚠⚠ **FIVE, in `Rules.UNITS` order since the sides swapped**: 검사 · 늑대 · 곰 · 까마귀 · 사자.
## **The swordsman takes the shieldbearer's 0.245** — it is the same drawing at the same scale, and a
## new number here would change how big a body reads for a reason nobody chose.
const BODY_RADIUS_RATIO := [0.245, 0.22, 0.31, 0.174, 0.342]

## Corner rounding as a fraction of that body's own radius — this is the "shape" half of telling
## types apart. The heavy walkers are boxy; the small and the flying are nearly circles.
## AT THE RADII ABOVE: 7.48, 3.50, 5.40, 5.00, 9.52, 4.20, 9.00, 4.80, 4.40 px.
const BODY_CORNER_RATIO := [0.85, 0.25, 0.30, 0.25, 0.85, 0.30, 0.90, 0.30, 0.20]

## ⚠⚠ **THESE TWO NOW HAVE NO READER AT ALL** (2026-08-25, 티켓 23). They sized a body drawn as a
## rounded-square outline plus a centre dot. The island stopped drawing that on 2026-08-24 and the
## refit screen's preview — the last one — stopped today, so **nothing in `src/` reads either.**
## ⚠ **Kept rather than deleted**, because `net_draw_leaf`'s pixel sweep is what would catch a new
## width literal appearing somewhere, and these two are the measured answer it would be compared
## against. **If they still have no reader when a later ticket sweeps orphans, they should go.**
## The measurement, kept as the reason for the number:
## RAISED 2.0 -> 5.0 by the world-width table above. A body WAS its outline — a rounded-square
## polyline plus a 3 px dot — and the whole fight is WATCHED at `ZOOM_MIN`, where 2.0 reached the glass at
## **0.90 px**. That is the same finding `COL_HIT_HALO`'s comment already carries one step short of
## the conclusion ("a body here is a 2 px outline plus a 3 px dot, so a tint has no AREA to paint").
## Ceiling 5.0, and it is arithmetic rather than taste: the smallest body is the crow at
## `0.25 * 40 = 10.0 px` radius, and a stroke wider than half that radius closes the shape into a
## solid blob at zoom 1.0 as well as at `ZOOM_MIN`.
## ⚠ It is also the hull outline (`_paint_hull`) and the harbour marker (`_paint_dock`), both of which
## are drawn on rectangles 40 px and wider — neither of them is what bounds this number.
const BODY_OUTLINE_WIDTH_PX := 5.0
const BODY_DOT_RADIUS_PX := 3.0

## The wolf. **The ally ashore is a picture now, not a rounded square** (2026-08-24, the user:
## 「지금 아직 세포여서 보기가 힘드네」). Two files and not one plus a flip, because flipping inside
## `_draw` costs a `draw_set_transform` and `net_draw_leaf` counts every `draw_*` call site — a
## mirrored copy on disk keeps the leaf at exactly one call.
##
## ⚠ **The ghost wears its own species' picture too** (티켓 15) — it used to be the wolf whatever was
## in the slot, which agreed with the plan only while one slot existed.
const BEAST_WOLF_R := "res://assets/beast/wolf_r.png"
const BEAST_WOLF_L := "res://assets/beast/wolf_l.png"
## ⚠⚠ **The beasts, drawn in the SOLDIERS' style** (2026-08-24). The wolf that stood here before was a
## realistic pixel animal and the enemy became a faceless low-poly toy, so the two sides read as two
## games; this replaces the wolf rather than adding beside it.
##
## ⚠⚠ **THE SQUIRREL AND THE COW LEFT AND THEIR PICTURES WENT WITH THEM** (2026-08-27). Neither is a
## row of `UNITS` any more, so neither could reach `BEAST_TEX`, and the four constants that named
## their files were read by nothing at all. **`BEAST_BULL_R` is the one that stayed**, and it stayed
## for a reason that has nothing to do with a body: `ITEM_ART` row 16 draws 우두머리의 뿔 with it.
## ⇒ **It is a card picture now.** Putting the cow back on the field needs a left-facing file again.
const BEAST_BULL_R := "res://assets/beast/bull_r.png"
const BEAST_BEAR_R := "res://assets/beast/bear_r.png"
const BEAST_BEAR_L := "res://assets/beast/bear_l.png"
const BEAST_CROW_R := "res://assets/beast/crow_r.png"
const BEAST_CROW_L := "res://assets/beast/crow_l.png"

## **The spearman, the shield soldier and the archer — CARD PICTURES, and nothing else.** They were
## the enemy once, back when the humans were what you played against.
##
## ⚠⚠ **ONE PICTURE EACH, NOT TWO, SINCE 2026-08-27 — and this is the difference between them and
## every other body constant in this file.** `HUMAN_SPEAR_L`, `HUMAN_BOW_L` and `HUMAN_SHIELD_L` stood
## here and were deleted with their three `.png` files and their three `.import` sidecars. **A body on
## the island needs a left-facing file** — `BEAST_TEX` is a right column and a left column, and
## `beast_tex_path` picks between them by `facing_right` — so a half with only a right file cannot be
## put on the field at all. **`ITEM_ART` needs only the right one**, because a card never faces left:
## rows 10, 11 and 14 draw 뺏은 창끝, 방패 조각 and 사냥꾼의 눈 with exactly these three constants.
## ⇒ **Do not delete the `_R` half.** It is the last thing holding three of the eighteen card pictures.
##
## ⚠⚠ **WHY THE LEFT HALVES DIED, AND IT IS A DECISION, NOT A CLEANUP.** The 2026-08-26 side swap made
## the humans the player and the beasts the enemy, which left these three as bodies for enemy roles
## that no longer exist. The user closed the remaining door 2026-08-27: **a second player weapon is
## not being built**, so nothing was ever going to walk these pictures onto the island again.
##
## ⚠ **What the deleted half carried, kept here because it outlives the files**: they were two files
## and not one plus a flip, for the reason `BEAST_WOLF_*` still states — flipping inside `_draw` costs
## a `draw_set_transform`, and `net_draw_leaf` counts every `draw_*` call site, so a mirrored copy on
## disk keeps the leaf at exactly one call. **A second player body now costs new ART, not a new table
## row** — that is the whole price of this deletion, and it is the sentence that used to be wrong.
##
## ⚠ **ONE BODY, REUSED** (2026-08-24, the user, translated: "make one soldier and have them throw
## spears … spear-throwing, archery, shield soldiers and so on — reuse that one character for now").
## The spear was the first weapon; the bow and the shield are **the same body with the hands changed**,
## generated from the spearman's OWN seed with one clause of the prompt swapped. That is why the three
## still read as one army on the cards rather than as three drawings that happen to be red, and it is
## why a human enemy was cheap where five beasts would have been five drawings.
##
## ⚠ **It is a big head on a stubby body and NOT a realistic man** (the user, translated: "the
## monsters are a bit too real … shouldn't it look like a game, a big-headed shape"). The realistic
## caveman that stood here first could not be read at all on the island — at the size a body is drawn,
## proportion is the only thing that survives, and a big head is the cheapest proportion that does.
const HUMAN_SPEAR_R := "res://assets/human/spear_r.png"
const HUMAN_BOW_R := "res://assets/human/bow_r.png"
const HUMAN_SHIELD_R := "res://assets/human/shield_r.png"
## ⚠⚠ **THE PLAYER, since 2026-08-26.** The same body again with a sword in its hands — drawn back
## when the humans were the enemy, which is exactly why the swap cost no art at all.
const HUMAN_SWORD_R := "res://assets/human/sword_r.png"
const HUMAN_SWORD_L := "res://assets/human/sword_l.png"

## ⚠⚠ **`IDLE` IS NOT A STRIP.** It is the standing picture every row already has and every row
## without a strip falls back to, which is why it carries no frame count and why the frame table below
## starts at `WALK`. Making it a one-frame strip would give eight species an animation made of the
## picture they already wear, and the fallback — the thing that keeps a species with no art working —
## would stop being visible in the code at all.
enum Anim { IDLE, WALK, BITE }

## The `<anim>` piece of `<beast>_<anim>_<frame>_<facing>.png`, indexed by `Anim`. `IDLE`'s is empty
## because an idle picture has no `<anim>` piece — it is `<beast>_<facing>.png` and nothing more.
const ANIM_NAME := ["", "walk", "bite"]

## Frames per strip, in `Anim` order starting at `WALK`. **A 0 is a row with no strip of that kind.**
const NO_ANIM_FRAMES := [0, 0]
## ⚠ **WALK loops 0-1-2-3; BITE plays 0-1-2-3 once and hands the body back to WALK.** Frame 0 of the
## bite is the only closed mouth in the strip, so a bite that looped would leave the jaw hanging open
## for the whole fight.
const WOLF_ANIM_FRAMES := [4, 4]

## How long one frame of any strip is held. **One rate for the whole animal**: 0.12 s puts the walk
## cycle at 0.48 s (8 fps, four frames), which at a 49 px body is a stride you can count — the same
## strip at 60 fps reads as a twitch, and 「연출은 과할 정도로」 cuts that way too. The bite is the same
## four frames, so it also runs 0.48 s against a ~1.0 s attack period: the jaw is moving for about
## half the time a body spends in contact, which is the half 「붙어서 가만히 있으면 재미가 죽는다」 is
## about. **The lunge (`LUNGE_SEC`) is deliberately shorter** — the body snaps out and back inside the
## first frames while the mouth carries the rest.
const BEAST_FRAME_SEC := 0.12

## ⚠⚠ **ONE ROW PER `Rules.UNITS` ROW: the picture that row wears facing right, and facing left.**
## This replaces `field_view._beast_tex`'s `if` chain, and with it the `is_enemy` argument that chain
## needed. **That argument existed only because two species shared one row** — 소 and 까마귀 were the
## enemy's rows while the player's two slots borrowed their bodies, so one row had to answer with two
## different pictures depending on who was asking. Split the rows and there is nothing for it to point
## at: **one row, one picture**, and the argument going away is the structural proof the move landed.
##
## ⚠ **An empty string is a row with NO picture**, and `field_view` draws the plain rounded shape for
## it. The lion is the only one: the last boss is still a beast in a game whose enemies became human,
## and **where it goes is an open question** (티켓 17) — handing it the caveman's picture here would
## answer that by accident, in a place nobody would look for it.
##
## ⚠⚠ **The third column is the row's OWN animation, and it is the only place one is declared.** A
## species animates by editing its own row; every consumer asks the row and falls back on the standing
## picture when the row says nothing, so **there is no species named anywhere in `field_view`**. A
## second list — "these ones have frames" — is the shape that has to be hand-synced with this one, and
## the day they disagree the wrong animal walks.
## ⚠⚠ **FIVE ROWS SINCE THE SIDES SWAPPED** (2026-08-26): the swordsman the player is, and the four
## beasts he fights.
## ⚠⚠ **"The player's second weapon is a row here, not a drawing" STOOD ON THIS LINE AND IT IS NOW
## FALSE** (2026-08-27). It was true while the spear, bow and shield each had a right file AND a left
## file sitting unused on disk: a sixth row could have been written with two existing paths and a body
## would have walked. **The three `_L` files were deleted** — the user settled 2026-08-27 that a second
## player weapon is not being built — and a row needs BOTH columns, so those three constants can only
## be card art now. ⇒ **A second player body costs a new DRAWING, not a new row**, and the estimate
## anyone makes off this table has to include that.
const BEAST_TEX := [
	[HUMAN_SWORD_R, HUMAN_SWORD_L, NO_ANIM_FRAMES],
	[BEAST_WOLF_R, BEAST_WOLF_L, WOLF_ANIM_FRAMES],
	[BEAST_BEAR_R, BEAST_BEAR_L, NO_ANIM_FRAMES],
	[BEAST_CROW_R, BEAST_CROW_L, NO_ANIM_FRAMES],
	["", "", NO_ANIM_FRAMES],
]

const _TEX_COL_RIGHT := 0
const _TEX_COL_LEFT := 1
const _TEX_COL_FRAMES := 2


## The picture path row `type_id` wears facing `facing_right`, or `""` for a row with none.
static func beast_tex_path(type_id: int, facing_right: bool) -> String:
	if type_id < 0 or type_id >= BEAST_TEX.size():
		return ""
	var row: Array = BEAST_TEX[type_id]
	return str(row[_TEX_COL_RIGHT if facing_right else _TEX_COL_LEFT])


## How many frames row `type_id`'s `anim` strip holds. **0 for `IDLE`, for an unknown row and for any
## row that declares no strip** — one answer, so no caller has to know which of the three it hit.
static func beast_anim_frames(type_id: int, anim: int) -> int:
	if type_id < 0 or type_id >= BEAST_TEX.size():
		return 0
	if anim <= Anim.IDLE or anim >= ANIM_NAME.size():
		return 0
	var row: Array = BEAST_TEX[type_id]
	var strips: Array = row[_TEX_COL_FRAMES]
	return int(strips[anim - 1])


## One frame's path, **derived from the standing picture rather than named a second time.** The
## convention is `<beast>_<anim>_<frame>_<facing>.png` and the standing picture is `<beast>_<facing>`,
## so the stem is already on the row; writing the strip out as sixteen more constants would put the
## word `wolf` in seventeen places and rot in sixteen of them the day a species is renamed.
##
## Falls back on the standing picture for `IDLE`, for a row with no strip and for a row with no
## picture at all, so **a caller never has to ask whether this species is animated.**
static func beast_frame_path(type_id: int, anim: int, frame: int, facing_right: bool) -> String:
	var idle := beast_tex_path(type_id, facing_right)
	var count := beast_anim_frames(type_id, anim)
	if idle.is_empty() or count <= 0 or frame < 0 or frame >= count:
		return idle
	var tail := "_r.png" if facing_right else "_l.png"
	return "%s_%s_%d%s" % [idle.trim_suffix(tail), str(ANIM_NAME[anim]), frame, tail]

## How far the body's own colour is mixed INTO the wolf. **0 is the raw grey animal and 1 is a solid
## cyan silhouette**; 0.45 keeps the fur readable while the side stays unmistakable at `ZOOM_MIN`.
##
## ⚠⚠ **This is what keeps friend and foe apart after the picture arrives.** The rule above this file
## has always been 「friend and foe by COLOUR, unit type by SIZE」, and a picture that ignored the
## colour would have quietly deleted the first half of it. **It also keeps the hit flash working**:
## the colour handed to the body is already mixed toward `COL_FLASH` (white), so a hit pulls the tint
## toward white and the animal brightens back to its own fur. A flat white modulate could not have
## done that — multiply can only darken.
const BEAST_TEAM_TINT := 0.45

## Sprite WIDTH as a multiple of the body radius. `0.35 * 40 = 14 px` radius at TILE_PX, so 2.4 puts
## the wolf at **34 px across** — just under one tile, which is what a body that walks a tile grid can
## be without the horde reading as a solid mat. The height follows the texture's own aspect.
const BEAST_SPRITE_W_RATIO := 3.5
## ⚠⚠ **CUT 6.0 -> 3.5** (2026-08-25, the user: 「캐릭터 크기 좀 줄이고」, and on the why: 「지금
## 캐릭터가 너무 커. 계속 플래시게임 같은 문제가 있거든」). **6.0 is kept in this comment because the
## user judges this by eye and has moved it in both directions before.**
##
## **The wolf goes 84 px -> 49 px, 2.1 tiles -> 1.23.** Measured across all nine rows at 3.5: squirrel
## 31x25, wolf 49x34, cow 63x44, bear 70x60, crow 39x26, spearman 49x52, archer 35x42, shieldbearer
## 56x64, lion 44x44.
##
## ⚠⚠ **A TIER IS THE NEW CEILING AND IT IS WHAT CHOSE THE VALUE'S UPPER HALF.** Bodies are
## camera-facing panels; a panel standing taller than the wall behind it hides the wall, and 티켓 19's
## whole point is that the wall is readable. One tier is 2 tiles = 80 px. **At 6.0 the tallest drawn
## body was the shieldbearer at 110 px — 1.37 tiers, taller than the thing it stands in front of. At
## 3.5 he is 64 px, 0.80 of a tier**, so a body never covers a boundary it is standing at.
##
## ⚠ **Chosen at the TOP of the 40-50 px band, deliberately.** The user's history on this axis is two
## complaints of *too small* (34 px, then 56) against one of *too big*, and this repo has written down
## that undershooting a presentation value costs a whole extra round (연출은 과할 정도로). **3.0 (42 px
## wolf) is the low-end alternative if 3.5 still reads big** — it costs one line and moves nothing else.
##
## ⚠ **What moved with it**: `BURST_START_MUL` is derived from this and halves with it (that derivation
## is 2026-08-24's fix for a death burst nobody could see, and `net_fx_view` pins it); the HP bar hangs
## off the sprite's own returned TOP rather than off a radius, so it follows by construction; the sim
## body radius, the halo and `hp_bar_origin_px` read `BODY_RADIUS_RATIO` and do not move at all.
## ⚠ **`BURST_WIDTH_PX` did NOT move and it is the one that got tight** — see its own note.
##
## ⚠⚠ **RAISED AGAIN, 4.0 -> 6.0** (2026-08-24, the user: 「멀리서 봤을때 너무작네」 — 4.0 was already
## the answer to 「너무 작긴 하거든」 and it was still too small). 6.0 puts a body at **84 px, 2.1 tiles**,
## which is 38 screen px at `ZOOM_MIN`. **Bodies now overlap whenever two stand side by side, and that
## is accepted** — see the note under `ZOOM_MIN`. ⚠ **The real cause is not this number**: island 0 is
## 48 x 32 = 1536 tiles carrying eighteen bodies, and no sprite size fixes a field that empty.
## ⚠⚠ **RAISED 2.4 -> 4.0** (2026-08-24, the user: 「맵에 비해 캐릭터가 너무 작긴 하거든. 뭐하는
## 건지 잘 안 보여」). 2.4 put the wolf at 34 px — under one tile, chosen so a horde would not read
## as a solid mat. **The horde was never the problem the eye had**: at the survey zoom a 34 px body is
## 15 px on screen, and at 15 px nothing is doing anything. 4.0 puts it at **56 px, 1.4 tiles**, which
## does overlap when bodies stand shoulder to shoulder — and overlapping bodies that can be told apart
## beat separate bodies that cannot be seen.

## ⚠ (`BEAK_LENGTH_PX` / `BEAK_WIDTH_PX` were deleted 2026-08-24 with zero readers: the triangle
## they shaped was the flat board's on-body beak marker and nothing draws one in 3D. **The beak
## itself was alive at the time. ⚠⚠ **The WHOLE reward is deleted now** (2026-08-25, the user: 「부리
## 보상 없지 끝나면 카드보상으로 통일했잖아」) — the range bonus, the per-body flag and the panel's
## pick all went with it, so there is nothing left for a field mark to mark.)

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

## (`HUD_TIMER_POS_PX` was deleted 2026-08-24: the countdown it placed died with the rule that
## counted to it, and nothing on the HUD draws a clock. `HUD_TIMER_FONT_SIZE_PX` above survives as
## the ceiling other HUD glyphs are still bounded against.)

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
## ⚠⚠ **THE X IS DERIVED FROM THE SLOT COUNT NOW AND IS NOT A CONSTANT ANY MORE.** It was
## `Vector2(956, 632)`, measured so that `956 + 5*56 + 4*8 = 1268 = 1280 - HUD_MARGIN_PX` — the row
## ended on the same right margin every other HUD item does. **The user cut the table to two**
## (*"슬럿 2개로 시작 확장가능"*) and that arithmetic put the last box at 1076, leaving a 192 px hole
## between the row and the corner.
## ⇒ **The row is RIGHT-ANCHORED**: `slot_rect_px` computes the origin backwards from the margin using
## the count it is HANDED, so the last box touches 1268 at one slot, at five, and at whatever the
## table says next. **"확장가능" has to be true of the layout and not only of the table** — otherwise a
## third binding is a `look.gd` edit, which is exactly what the user asked not to happen.
## Only the Y survives as a constant: it shares `HUD_START_ORIGIN_PX`'s own 632 so the two bottom
## widgets sit on one baseline, and 632 + 64 = 696 <= 720.
const HUD_SLOT_ROW_Y_PX := 632.0
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

## ⚠⚠ **`IDLE_SOLDIER_PITCH_PX` / `_COLS` / `_ORIGIN_PX` AND `idle_soldier_offset_px()` ARE DELETED**
## with the thing they laid out: the stack of reserve bodies standing on the water at the start
## harbour. The user pointed at it in a screenshot and said ***"ㅇㅇ 지워줘"*** — it was the DRAG's
## source, and the drag is what they said was not fun. `sea-summon`'s five slot boxes are where the
## roster shows now, and `hud_view` owns their geometry.
##
## ⚠ **One thing went with it and has no home: per-soldier HP.** The stack drew a bar under every
## reserve body because 「which of these thirteen is nearly gone」 is a planning fact — soldiers carry
## damage between islands and a dead one is dead for good. **A slot bar is a COUNT, not a health
## readout.** `sea-summon` §6 raised this as its Open 4 and did not answer it.

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

## Centred: (1280 - 560) / 2 = 360, (720 - 520) / 2 = 100.
##
## ⚠⚠ **THE PANEL NO LONGER HOLDS A ROSTER** (2026-08-25). It was sized to list every body a run can
## field, because the beak reward asked the player to click one of them; the user deleted that reward
## — 「부리 보상 없지 끝나면 카드보상으로 통일했잖아」 — so the panel is a band and a button.
## **The size is deliberately NOT shrunk to fit**: it is the win/lose screen's frame, and re-laying it
## is a look decision nobody has made. Height check: `456 + 48 = 504 <= 520`.
const PANEL_ORIGIN_PX := Vector2(360.0, 100.0)
const PANEL_SIZE_PX := Vector2(560.0, 520.0)

const PANEL_TITLE_OFFSET_PX := Vector2(40.0, 44.0)
const PANEL_TITLE_FONT_SIZE_PX := 28
const PANEL_BODY_FONT_SIZE_PX := 18

## The restart / continue button. **The seven roster constants above it are deleted** with the beak
## reward they laid out (2026-08-25). 456 + 48 = 504 <= 520.
const BUTTON_OFFSET_PX := Vector2(180.0, 456.0)
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
# The reward screen — six cards, take two (`parts-on-a-board-not-on-the-body`)
# ---------------------------------------------------------------------------------------------

## 3 across, 2 down. `≥ (220, 64)` — the largest press in the game, and no new press is smaller;
## `3×280 + 2×32 = 904 ≤ 1280`.
const CARD_SIZE_PX := Vector2(280.0, 200.0)
const CARD_GAP_PX := 32.0             # ≥ 12 or two cards read as one bar; ≤ 80, from the width sum
## x = `(1280 − 904) / 2` exactly; y ≥ 120 (clear of the hint line); `180 + 2×200 + 32 = 612 ≤ 720`.
const CARD_GRID_ORIGIN_PX := Vector2(188.0, 180.0)

## ⚠⚠ **RENAMED, NOT RESIZED** (2026-08-25, 티켓 23). These two were `CARD_PART_*` and
## `CARD_SPECIES_*`, and they sized neither: 부위 and 종 were the DEAD cell game's two card lines,
## and since 2026-08-24 a card carries an item NAME and an EFFECT. **A constant whose name says a
## thing it does not size is the quietest kind of wrong** — nothing reddens, and the next reader
## looks for a species line that is not there. Every number is unchanged.
const CARD_NAME_FONT_SIZE_PX := 34    # > HUD_TIMER_FONT_SIZE_PX 30 — the item name is the loudest
                                      # thing on its own card; ≤ 44, from 4 glyphs at ~0.6em inside
                                      # 280 − 2×24
const CARD_EFFECT_FONT_SIZE_PX := 20  # ≥ 16 (unreadable below); ≤ CARD_NAME_FONT_SIZE_PX − 12, or
                                      # the name and the effect read as one line
## ⚠ **The card was relaid for the art** (티켓 12 fix round): name on top, art in the middle, effect
## at the bottom. The name's descenders end near `44 + 5 = 49`, above the art band at 52.
const CARD_NAME_OFFSET_PX := Vector2(24.0, 44.0)        # x > 0 and y ≥ the name font size; inside
                                      # the card
## The effect line WRAPS now (`_paint_card_effect` is a `draw_multiline_string`), because the longest
## item line — 폭풍의 가죽's 「전설  공격주기 -0.25 · 이동속도 +2.5」 — was measured clipping at the
## card's right border as a single line. Wrapped at `CARD_EFFECT_WRAP_W_PX` it is two lines: first
## baseline 160, second ≈ 188, descenders ≈ 194 ≤ 200 — inside the card for the LONGEST string, not
## an average one. y ≥ art bottom (136) + the font size, or the line overlaps the picture.
const CARD_EFFECT_OFFSET_PX := Vector2(24.0, 160.0)
## The wrap width: `280 − 2 × 24` — the same 24 px inset on both sides. A single token never exceeds
## it (the widest, 공격주기, is 4 glyphs ≈ 80 px), so word-wrap alone guarantees no horizontal clip.
const CARD_EFFECT_WRAP_W_PX := 232.0
## ⚠⚠ **A taken card and a card that can no longer be taken both fall to `PRESS_ALPHA_OFF`, so alpha
## alone cannot tell them apart** — the map measured exactly this and answered it with size AND
## brightness AND what is drawn on top. This mark is the third channel.
const CARD_TAKEN_MARK_R_PX := 26.0    # ≥ 18; ≤ 40, or it covers the part name
const CARD_HINT_POS_PX := Vector2(500.0, 120.0)         # y ≥ the font size, y ≤ 160, clear of the
                                      # grid at 180
const CARD_HINT_FONT_SIZE_PX := 26    # > HUD_FONT_SIZE_PX 22
## How long the taken mark takes to grow to full size. >= 0.084 (five frames); <= 0.40.
const CARD_TAKEN_GROW_SEC := 0.20

## `시작하기` reuses `COL_START` and `종료` reuses `COL_BUTTON`, by this file's own same-verb-same-tone
## rule; a card is a new verb and gets one tone.
const COL_CARD := Color(0.596, 0.549, 0.827)

## ⚠⚠ **WAS `COL_SPECIES`, indexed by `Rules.Species` — a cell-game enum that nothing read.** It is
## indexed by `Rules.Rarity` now (2026-08-24), and there are four rather than three. **Every constraint
## the old table was measured against is kept and re-measured**: pairwise luminance ratio ≥ 1.4 so no
## two rarities read as one tone, and every one WCAG-contrasts ≥ 3:1 against `COL_CARD`, the one surface
## this table is ever drawn on. ⚠ **LEGENDARY is the only one allowed to be warm** — it is the tone the
## eye is meant to catch across a three-card spread, and warmth is what does that here.
## The original paragraph is kept below because its reasoning is what these numbers still obey:
##
## Pairwise luminance ratio ≥ 1.4, so no two species read as one tone —
## and, ⚠⚠ **every one WCAG-contrasts ≥ 3:1 against `COL_CARD`, the ONE surface this table is ever
## drawn on** (`reward_view._paint_card_species`, `refit_view._paint_cell_species`). The three used to
## be picked for pairwise separation alone and land at 1.03:1 / 1.16:1 / 1.56:1 against the card — a
## smudge next to the part name it sits below. All three moved dark (light text was never going to
## clear 3:1 against a card this light without turning white and erasing hue), which is what pushed
## the pairwise floor down near the card-contrast one: the two constraints share the same three
## numbers and both are checked, not just the one this comment used to name.
## ⚠⚠ **THE FOUR LUMINANCES ARE GEOMETRIC AND THEY ARE AT THE ARITHMETIC LIMIT.** `COL_CARD` has
## luminance 0.3013, so the 3:1 floor caps a rarity tone at **0.0671** — and four values spread evenly
## between 0 and that cap can be at most **(0.1171 / 0.05)^(1/3) = 1.328** apart in pairs. **The old
## three-species table's 1.4 pairwise floor is therefore unreachable with four**, and the floor moved
## rather than the constraint being quietly dropped: `net_cards` carries 1.30 and this paragraph.
## ⇒ **The colour is not what tells the rarities apart; the WORD in front of the effect line is.**
## The tone is there to catch the eye across a spread, which is why LEGENDARY is the only warm one.
const COL_RARITY := [
	Color(0.000, 0.000, 0.000),   # COMMON    — black,       luminance 0.0000, 7.03:1 on the card
	Color(0.084, 0.133, 0.241),   # RARE      — deep blue,             0.0165, 5.29:1
	Color(0.060, 0.242, 0.230),   # EPIC      — deep teal,             0.0383, 3.98:1
	Color(0.408, 0.253, 0.061),   # LEGENDARY — burnt amber,           0.0671, 3.00:1
]


## Card `k`'s (0..2) RESTING rectangle, in viewport px. **One row of three** — `Rules.CARDS_PER_WIN`.
## ⚠ **This said "(0..5) ... 3 across, 2 down" until 2026-08-27.** The second row died when the count
## went six -> three (2026-08-24); the `k / 3` below has simply been returning row 0 ever since.
static func card_rect_px(k: int) -> Rect2:
	var col := k % 3
	var row := k / 3
	return Rect2(CARD_GRID_ORIGIN_PX + Vector2(col * (CARD_SIZE_PX.x + CARD_GAP_PX),
		row * (CARD_SIZE_PX.y + CARD_GAP_PX)), CARD_SIZE_PX)


## The same rectangle grown by `PRESS_HIT_PAD_PX` on all four sides — 296×216 at a 312×232 pitch, so
## no two hit rects ever touch (312 − 296 = 16 > 0, 232 − 216 = 16 > 0).
static func card_hit_rect_px(k: int) -> Rect2:
	return card_rect_px(k).grow(PRESS_HIT_PAD_PX)


## --- the picture on the card (티켓 12) ----------------------------------------------------------

## Item id → texture path, one row per `Rules.ITEMS` row IN THE SAME ORDER — the two tables share
## their index, and `Rules.item_count()` is the only size either is allowed to have.
## ⚠⚠ **An empty string means "no honest picture yet" and the view draws NO art there** — never a
## stand-in. Of the eighteen items only five had a picture that tells the truth about what the card
## gives; a wolf on a 가죽끈 card is a picture that lies, and the fork was closed on exactly this
## (2026-08-24, the user: 「그렇게 하자」 — reuse the honest five, generate the other thirteen).
## The five reused rows point at constants above by NAME, never by a repeated path string, so a
## moved file breaks one line instead of two.
## ⚠ **The thirteen `assets/item/` rows are a FIRST-PASS pick** (2026-08-24, the user: 「일단 다
## 니가 선택해둬 나중에 고를게」). Each carries its candidate id from
## `.scratch/cell-hook/prototypes/item-cards/`, so a re-pick after the user looks in game is a
## one-line swap: cut the new candidate with `tools/pixel/cutbg.py` over the same filename.
const ITEM_ART := [
	"res://assets/item/strap.png",           # 0  가죽끈 — pick 0-2
	"res://assets/item/stone_necklace.png",  # 1  돌 목걸이 — pick 1-1
	"res://assets/item/wood_claw.png",       # 2  나무 발톱 — pick 2-1
	"res://assets/item/dry_hide.png",        # 3  마른 가죽 — pick 3-1
	"res://assets/item/bone_shard.png",      # 4  뼛조각 — pick 4-1
	"res://assets/item/dry_sinew.png",       # 5  말린 힘줄 — pick 5-3
	"res://assets/item/tanned_hide.png",     # 6  무두질 가죽 — pick 6-2
	"res://assets/item/flint_tooth.png",     # 7  부싯돌 이빨 — pick 7-1
	"res://assets/item/deer_sinew.png",      # 8  사슴 힘줄 — pick 8-1
	"res://assets/item/wind_mane.png",       # 9  바람 갈기 — pick 9-2
	HUMAN_SPEAR_R,   # 10 뺏은 창끝 — the spearman is carrying exactly this
	HUMAN_SHIELD_R,  # 11 방패 조각 — the shield soldier's own shield
	"res://assets/item/bronze_plate.png",    # 12 청동 판 — pick 12-2
	BEAST_WOLF_R,    # 13 늑대 송곳니 — the wolf the fang came off
	HUMAN_BOW_R,     # 14 사냥꾼의 눈 — the archer, the one hunter on the field
	"res://assets/item/sprint_paw.png",      # 15 질주의 발 — pick 15-2
	BEAST_BULL_R,    # 16 우두머리의 뿔 — the bull the horn came off
	"res://assets/item/storm_hide.png",      # 17 폭풍의 가죽 — pick 17-2
]


## The picture on a card. `""` for a card with no picture, which the art leaf is simply not called for.
## ⚠ **The beast arm was deleted 2026-08-27** with the beast card — it returned the species' own field
## picture, so a card and the island could never show two different animals.
static func card_art_path(kind: int, value: int) -> String:
	if value < 0 or value >= ITEM_ART.size():
		return ""
	return str(ITEM_ART[value])


## Every distinct path a card could ever wear, so a screen can load them once instead of per frame.
## ⚠ **Walked over the table rather than listed**, or a new card face is a picture nobody loads.
## ⚠ **It walked TWO tables until 2026-08-27** — the second was the beast cards' own species pictures,
## and it went with them. A second card kind puts its loop back here and nowhere else.
static func card_art_paths() -> PackedStringArray:
	var out := PackedStringArray()
	for i in ITEM_ART.size():
		var p := card_art_path(Rules.CardKind.ITEM, i)
		if p != "" and not out.has(p):
			out.append(p)
	return out

## The art rectangle inside a card, offset from the card's own origin — the middle band of the
## relaid card, between the name (descenders end ≈ 49) and the effect block (glyph tops at
## `160 − 20 = 140`): x `(280 − 84) / 2 = 98`, y 52..136. ⚠ **RAISED from 42 to 84** in the fix
## round — at 42 the picture read as a badge while the card's lower half sat empty (verify-look),
## and 「연출은 과할 정도로」 is the standing rule. One-line revert if the user dislikes it.
## Square on purpose: every wired texture is a body sprite near 1:1, and a stretched body is a
## different animal.
const CARD_ART_OFFSET_PX := Vector2(98.0, 52.0)
const CARD_ART_SIZE_PX := Vector2(84.0, 84.0)

## How far a card slides in while it fades, in HUD px. ⚠ **No duration of its own**: the slide eases
## on `_reveal_alpha_of(k)`, the fade's own value, so the fade and the slide can never disagree on
## when a card has arrived. The offset is +y — a dealt card starts BELOW its rest and rises — so
## ≥ 24 or the slide reads as a twitch; ≤ 60: the grid's bottom is 380, so the moving card's bottom
## reaches `380 + slide = 420 ≤ 720`, and past 60 the travel reads as the card arriving from
## somewhere off the panel rather than being dealt onto it.
const CARD_DEAL_SLIDE_PX := 40.0

## Four BRIGHT tones indexed by `Rules.Rarity`, for the glow AROUND a card. ⚠ **Deliberately NOT
## `COL_RARITY` reused**: that table is dark text measured 3:1 against `COL_CARD`; this glow is drawn
## outward from the card's edge onto whatever the 3D field behind the panel shows (the field stays on
## screen during the pick — `game.gd`'s own header says so), so it needs bright values of its own.
## LEGENDARY stays the only warm one — the same argument as the text table: warmth is what catches
## the eye across a spread. COMMON's row exists so the table indexes like its ladder siblings below,
## and it is never drawn — `RARITY_GLOW_LAYERS` row 0 is 0.
const COL_RARITY_GLOW := [
	Color(0.918, 0.937, 0.961),   # COMMON    — never drawn (0 layers)
	# ⚠ RARE was (0.451, 0.675, 1.000) and read near-white on COL_CARD (verify-look) — the FIRST rung
	# of the ladder is the one a player learns the ladder from, so it was deepened to a saturated
	# blue. One-line revert if the user dislikes it.
	Color(0.216, 0.443, 0.957),   # RARE      — saturated blue
	Color(0.310, 0.941, 0.867),   # EPIC      — bright teal
	Color(1.000, 0.780, 0.302),   # LEGENDARY — warm gold
]

## The rarity TEXT tones for the game's DARK panels — the refit board and the held pile. ⚠
## `COL_RARITY` above is dark text measured 3:1 against the LIGHT card, and on the dark refit
## palette it sinks: verify-look read 전설's amber and 희귀's navy as markedly less readable than
## plain text there, the second time that exact finding was recorded (티켓 12 wrote it first). The
## bright glow tones are the same ladder the card screen already teaches, so they are POINTED AT
## rather than copied — one place owns the four values. COMMON's near-white row reads as plain text,
## which is what COMMON is.
const COL_RARITY_TEXT_DARK := COL_RARITY_GLOW

## ⚠⚠ **The rarity ladder. Every consumer of 「how loud is this rarity」 reads these tables and
## nothing else**, indexed by `Rules.Rarity` — one place owns the answer. **COMMON is the zero row on
## every axis** (no frame, no glow, no pulse), and LEGENDARY is the only row with everything on plus
## the burst below — that ladder shape, not any single value, is what makes 전설 unmissable
## (「연출은 과할 정도로」). These are HUD-space px with no zoom under them, so the 2.0 px snap floor
## is the only width bound that bites: every non-zero frame width is ≥ 2.0.
const RARITY_FRAME_WIDTH_PX := [0.0, 3.0, 5.0, 8.0]
## The glow is the frame's own stroke layered outward, each layer one frame-width further out and
## linearly fainter (the outermost keeps `1/layers` of the alpha — never zero: a zero-alpha stroke
## would be a call that draws nothing) — layer count is the glow's REACH. 0 layers is no call at
## all. Alpha is the innermost layer's AT REST, and the pulse swings above it: the drawn value is
## `alpha × (1 + pulse × RARITY_PULSE_GAIN)`, so LEGENDARY's crest is `0.50 × 1.60 = 0.80`. The
## ceiling is on that CREST, 0.85 — past it the glow outshines the card it frames — and every row's
## crest is under it (COMMON 0 · RARE 0.25 · EPIC 0.455 · LEGENDARY 0.80).
const RARITY_GLOW_LAYERS := [0, 2, 3, 6]
const RARITY_GLOW_ALPHA := [0.0, 0.25, 0.35, 0.50]
## The pulse — a sine on the screen's own reveal clock (`_reveal_age`; ⚠ no second clock is
## invented). SEC is one full breath, and 0.0 means NO pulse — the view returns 0 rather than divide
## by it. GAIN is how far the glow alpha swings above rest at the crest. SEC floor 0.42 (five frames
## of visible motion per half-breath); ceiling 2.0 or the pulse reads as a slow fade.
const RARITY_PULSE_SEC := [0.0, 0.0, 1.4, 0.9]
const RARITY_PULSE_GAIN := [0.0, 0.0, 0.30, 0.60]
## The legendary burst — rays out from behind the card, drawn iff LEGENDARY, grown over BURST_SEC of
## the card's own reveal. Count ≥ 8 or the rays read as stray lines, ≤ 24 or they read as a solid
## disc. LEN ≤ 60: the row above the cards is clear down to the hint baseline at 120 and the grid top
## is 180. WIDTH ≥ 2.0 (HUD-space snap floor); ≤ 8 or rays read as bars. BURST ≥ 0.084 (five
## frames); ≤ 1.0 or the burst is still crawling out after every card has already arrived.
const LEGEND_RAY_COUNT := 12
const LEGEND_RAY_LEN_PX := 46.0
const LEGEND_RAY_WIDTH_PX := 4.0
const LEGEND_BURST_SEC := 0.60


# ---------------------------------------------------------------------------------------------
# The refit screen (`parts-on-a-board-not-on-the-body`)
# ---------------------------------------------------------------------------------------------

## The beast strip — one box per SPECIES (티켓 11: the board hangs on the type, and all five take
## equipment), drawn on both steps, side by side rather than stacked, because step two also draws
## the board and the two must never share a pixel of hit rect. `≥ (220, 64)`, exactly at the width
## floor — five across is the densest this row can be. `220×5 + 20×4 = 1180` wide, centred:
## `(1280 − 1180) / 2 = 50`; hit rects span x 42…1238, inside the screen.
##
## ⚠⚠ **This is the fix for the BELLY cell that could never be pressed.** The strip used to sit at
## y 200…464 — squarely on top of the board's y 320…628 — so the BELLY cell's centre landed inside
## slot 1's hit rect and `_refit_input` (which asks `slot_at` before `cell_at`) answered "slot 1"
## for a press aimed at the board. Laying the strip out ABOVE the board, with its own hit rect
## entirely inside y 92…172, removes the two regions' only overlap instead of reordering the input
## check that found it (see `_refit_input`'s own comment for why that order cannot change).
const REFIT_SLOT_SIZE_PX := Vector2(220.0, 64.0)
## ≥ 17 (the same hit-pad arithmetic as `REFIT_CELL_GAP_PX` — at 16 two neighbours' hit rects share
## an edge); ≤ 25 (`50 + 220×5 + 25×4 = 1250`, hit right edge 1258 ≤ 1280).
const REFIT_SLOT_GAP_PX := 20.0
## y clears the dashboard above it (ends ~78) and the board below it (hit-top 312) by 14 px and
## 140 px. x centres the 1180-wide strip.
const REFIT_SLOT_ORIGIN_PX := Vector2(50.0, 100.0)
const REFIT_BUTTON_SIZE_PX := Vector2(240.0, 64.0)      # ≥ (220, 64); ≤ (360, 120)
## `600 + 64 = 664 ≤ 720`, and `600 > 172` so it never touches the strip.
const REFIT_DONE_ORIGIN_PX := Vector2(520.0, 600.0)

## The board, the pile, the dashboard, the body — step two. `≥ (220, 64)` — exactly at the width
## floor, deliberately: the board is the densest press on any screen. `3×220 + 2×20 = 700`.
const REFIT_CELL_SIZE_PX := Vector2(220.0, 140.0)
## ⚠⚠ **≥ 17, and the reason is the hit pad, not the eye**: a hit rect grows 8 on each side, so at a
## gap of 16 two neighbours' hit rects share an edge exactly and `Rect2.intersects` (borders excluded
## by default) calls that no overlap. 20 leaves 4 px clear; ≤ 40 (`80 + 3×220 + 2×40 ≤ 800`).
const REFIT_CELL_GAP_PX := 20.0
## `80 + 700 = 780 ≤ 800` (clear of the pile column); `320 + 2×140 + 20 = 620`, hit bottom 628.
const REFIT_BOARD_ORIGIN_PX := Vector2(80.0, 320.0)

## A part landing in its cell fills over this — `MAP_CLEAR_FILL_SEC`'s sibling, same bound and same
## reason: without it, fitting a part and not fitting it look identical on screen for exactly one
## frame less than forever. Its own constant, not a re-read of the map's, because the two screens'
## clocks are never compared against each other and a shared name would suggest they could be.
const REFIT_CELL_FILL_SEC := 0.25         # >= 0.084 (five frames); <= 0.50
## ⚠ **Renamed for the same reason as `CARD_NAME_*` above** (티켓 23): these sized a cell's item name
## and its effect line, not a 부위 and a 종. Numbers unchanged.
const REFIT_CELL_NAME_FONT_SIZE_PX := 26     # > HUD_FONT_SIZE_PX 22; ≤ 34
const REFIT_CELL_EFFECT_FONT_SIZE_PX := 18   # ≥ 16; ≤ the name font − 6

## Where a cell's two lines sit, and the wrap that keeps the effect inside a 220-wide cell — the
## same structure `CARD_EFFECT_WRAP_W_PX` carries, arrived at for the same reason: 뺏은 창끝's line
## was measured sitting flush against the cell border as a single `draw_string`, and the LONGEST
## line (폭풍의 가죽's 「공격주기 -0.25 · 이동속도 +2.5 · 공속」) cannot fit one line at all.
## Wrapped at `220 − 16 − 10` it is two lines: baselines 106 and ≈128, descenders ≈133 ≤ 140. The
## widest token (공격주기, ≈80 px at 18) never exceeds the width, so word-wrap alone guarantees no
## horizontal clip.
const REFIT_CELL_NAME_OFFSET_PX := Vector2(16.0, 30.0)
const REFIT_CELL_EFFECT_OFFSET_PX := Vector2(16.0, 106.0)
const REFIT_CELL_EFFECT_WRAP_W_PX := 194.0

## x > 780 (clear of the board and the dashboard); `800 + 240 + 220 = 1260`, hit right edge 1268.
const REFIT_HELD_ORIGIN_PX := Vector2(800.0, 300.0)
## The exact smallest legal press on this screen.
const REFIT_HELD_SIZE_PX := Vector2(220.0, 64.0)
const REFIT_HELD_GAP_PX := 20.0               # ≥ 17 (the cells' own hit-pad arithmetic); ≤ 32
## ≥ 237 (220 + 8 + 8 + 1) or the two columns' hit rects overlap; ≤ 250 from the right edge.
const REFIT_HELD_COL_PITCH_PX := 240.0

## The held row's two lines inside its 64-tall box, with the effect WRAPPED at `220 − 8 − 8` — 말린
## 힘줄's line was measured running past the row border into the background as one `draw_string`,
## and 우두머리의 뿔's touched it. ⚠ **14, not 16, and the first values here were 16/38 and WRONG**:
## `net_refit._every_effect_line_fits_its_box` measured the real font's line height and four items'
## second line left the 64 px box — the font's height at a size is bigger than the size, which is
## exactly why the net measures metrics instead of this comment doing arithmetic with the number 16.
const REFIT_HELD_NAME_OFFSET_PX := Vector2(8.0, 18.0)
const REFIT_HELD_EFFECT_OFFSET_PX := Vector2(8.0, 34.0)
const REFIT_HELD_EFFECT_FONT_SIZE_PX := 14    # ≥ 12; ≤ REFIT_CELL_EFFECT_FONT_SIZE_PX — two
                                              # wrapped lines have to fit the 64-tall row, and the
                                              # fit is MEASURED by net_refit, not asserted here
const REFIT_HELD_EFFECT_WRAP_W_PX := 204.0
## ⚠⚠ **`refit_held_capacity()` = 2 × 5 = 10, and it must stay ≥ `Rules.CARD_PICKS`.** It used to be
## pinned against the map's longest route (`CARD_PICKS × map_max_card_nodes_on_a_route()` = 8) and
## **the map is deleted** (2026-08-26): one card round is all a run has until waves are built.
## ⚠ `panel_view.roster_ids` shipped a cap that silently dropped the overflow and its comment said the
## cap never bit — it bit. **When waves start paying cards this bound has to be re-pinned to them.**
const REFIT_HELD_ROWS := 5                    # `300 + 4×84 + 64 = 700`, hit bottom 708 ≤ 720

## ⚠ A ROW, not a column — `refit_stat_origin_px` steps this in X. It used to step in Y, which
## stacked the five numbers straight down the board's own left edge (`REFIT_BOARD_ORIGIN_PX.x`)
## starting at the board's own y, so two of the five sat on top of board cells and the fifth sat
## past the bottom of a 720 px screen. A row at the very top of the screen is clear of the strip
## (starts y 100), the board (starts y 320) and the pile (x 800+) by construction.
const REFIT_STAT_ORIGIN_PX := Vector2(80.0, 40.0)      # y ≥ the label font size; `80 + 5×140 =
                                      # 780 ≤ 800`
const REFIT_STAT_PITCH_PX := 140.0    # ≥ 110 (the widest label 「공격주기」 at ~0.6em of 20px is
                                      # 48px, and the value below it needs the same again); ≤ 144
const REFIT_STAT_LABEL_FONT_SIZE_PX := 20     # ≥ 16; < the value font − 10
const REFIT_STAT_VALUE_FONT_SIZE_PX := 34     # > HUD_TIMER_FONT_SIZE_PX 30; ≤ 44

## Step one's hint — 「no line of text anywhere says what this screen is or that a slot presses」.
## Sits in the gap between the strip's hit-bottom (172) and the board's own top (320); drawn only
## while `_open_slot < 0` (`refit_view._draw`), so it never competes with the board for the same band.
const REFIT_HINT_POS_PX := Vector2(400.0, 220.0)
const REFIT_HINT_FONT_SIZE_PX := 22    # == HUD_FONT_SIZE_PX, the map's own hint-adjacent size

## ⚠ Re-sat for the five-species strip (티켓 11): the widest body previewed is the LION's now
## (0.55 × 40), and at the old scale 5 its 110 px radius crossed both the strip above and the pile
## below. y − radius ≥ 166 (the strip draws to 164) and y + radius ≤ 298 (the pile draws from 300),
## at the biggest radius 0.55 × 40 × scale = 66; x ± 66 sits right of the tag rows (≤ 950).
const REFIT_BODY_CENTRE_PX := Vector2(1150.0, 232.0)
const REFIT_BODY_SCALE := 3.0         # ≥ 3 — under it the ranged body's corner rounding is
                                      # invisible; ≤ 3.4, from 0.55 × 40 × 3.4 = 74.8 > the 66 px
                                      # half-band between the strip and the pile

## The tag aggregate — a 「무리」 header line and one line per `Rules.TAG_LABELS` row, drawn on BOTH
## steps (the count is army-wide, so it is true on the strip step too). ⚠ **The header exists
## because the column sits under a strip box** (verify-look): without a word saying whose numbers
## these are, four lines directly beneath one beast's box read as that beast's own. The band between
## the strip's drawn bottom (164) and the pile's drawn top (300): five baselines 196…292 with the
## 20 px glyphs hanging above them (top ≈176), descenders ≈296; x 810…~950, clear of the
## board/dashboard (≤ 780) and the body preview (≥ 1084).
const REFIT_TAG_ORIGIN_PX := Vector2(810.0, 196.0)
const REFIT_TAG_ROW_PITCH_PX := 24.0          # ≥ the font size + 4; ≤ 25 (`196 + 4×25 + 4 ≤ 300`)
const REFIT_TAG_FONT_SIZE_PX := 20            # ≥ 16; ≤ REFIT_STAT_LABEL_FONT_SIZE_PX + 4

## A lit combo line. Gold against `dimmed(COL_HUD_TEXT)` for the unlit
## lines, so "this one is on" reads as colour and not as a symbol nobody explained.
const COL_TAG_LIT := Color(1.0, 0.843, 0.400)

## The button has TWO positions: step one reuses `REFIT_DONE_ORIGIN_PX` above (the strip's hit
## bottom is 172, and 600 clears it); step two moves it clear of the board, which occupies y
## 320…628 including its pad.
## ⚠⚠ The comparison that matters is HIT rect against HIT rect, not resting position against a hit
## rect — `632 > 628` compared the wrong pair (this button's own RESTING top against the board's
## HIT bottom) and forgot this button gets an 8 px pad of its own, so its actual hit-top was 624,
## 4 px INSIDE the board's hit-bottom of 628. `640 − 8 = 632 > 628`, this button's real hit-top,
## is the comparison that has to hold.
const REFIT_DONE_BOARD_ORIGIN_PX := Vector2(80.0, 640.0)       # `632 > 628`; `640 + 64 + 8 = 712 ≤ 720`
const REFIT_BACK_ORIGIN_PX := Vector2(340.0, 640.0)            # 260 apart against a 240 width — the
                                      # two hit rects clear by 4


static func refit_slot_rect_px(slot: int) -> Rect2:
	var x := REFIT_SLOT_ORIGIN_PX.x + slot * (REFIT_SLOT_SIZE_PX.x + REFIT_SLOT_GAP_PX)
	return Rect2(Vector2(x, REFIT_SLOT_ORIGIN_PX.y), REFIT_SLOT_SIZE_PX)


static func refit_slot_hit_rect_px(slot: int) -> Rect2:
	return refit_slot_rect_px(slot).grow(PRESS_HIT_PAD_PX)


## Baseline of tag aggregate line `row` (0..`Rules.tag_kind_count()`-1).
static func refit_tag_origin_px(row: int) -> Vector2:
	return REFIT_TAG_ORIGIN_PX + Vector2(0.0, row * REFIT_TAG_ROW_PITCH_PX)


static func refit_done_rect_px(board_open: bool) -> Rect2:
	return Rect2(REFIT_DONE_BOARD_ORIGIN_PX if board_open else REFIT_DONE_ORIGIN_PX,
		REFIT_BUTTON_SIZE_PX)


static func refit_back_rect_px() -> Rect2:
	return Rect2(REFIT_BACK_ORIGIN_PX, REFIT_BUTTON_SIZE_PX)


## Cell `part`'s (0..5, `Rules.Part`) RESTING rectangle: 3 across, 2 down, same pitch shape the cards
## use.
static func refit_cell_rect_px(part: int) -> Rect2:
	var col := part % 3
	var row := part / 3
	return Rect2(REFIT_BOARD_ORIGIN_PX + Vector2(col * (REFIT_CELL_SIZE_PX.x + REFIT_CELL_GAP_PX),
		row * (REFIT_CELL_SIZE_PX.y + REFIT_CELL_GAP_PX)), REFIT_CELL_SIZE_PX)


static func refit_cell_hit_rect_px(part: int) -> Rect2:
	return refit_cell_rect_px(part).grow(PRESS_HIT_PAD_PX)


## How many held rows the pile can show at once — two columns of `REFIT_HELD_ROWS`.
static func refit_held_capacity() -> int:
	return 2 * REFIT_HELD_ROWS


## Held row `row_index` (0..`refit_held_capacity()`-1), two columns top to bottom then across.
static func refit_held_rect_px(row_index: int) -> Rect2:
	var col := row_index / REFIT_HELD_ROWS
	var row := row_index % REFIT_HELD_ROWS
	return Rect2(REFIT_HELD_ORIGIN_PX + Vector2(col * REFIT_HELD_COL_PITCH_PX,
		row * (REFIT_HELD_SIZE_PX.y + REFIT_HELD_GAP_PX)), REFIT_HELD_SIZE_PX)


static func refit_held_hit_rect_px(row_index: int) -> Rect2:
	return refit_held_rect_px(row_index).grow(PRESS_HIT_PAD_PX)


## The five dashboard columns, left to right, indexed by `Rules.PART_COL_*`.
static func refit_stat_origin_px(col: int) -> Vector2:
	return REFIT_STAT_ORIGIN_PX + Vector2(col * REFIT_STAT_PITCH_PX, 0.0)


## Column `col`'s own bounding rect — label and value stacked, `PITCH` wide (minus a hair of clearance
## from its neighbour) and tall enough to cover both lines. Not a press — this screen's numbers are
## read, never pressed — so it carries no hit pad; it exists only so a net can prove the row lands on
## screen and clear of the board without re-deriving its own copy of this arithmetic.
static func refit_stat_rect_px(col: int) -> Rect2:
	return Rect2(refit_stat_origin_px(col),
		Vector2(REFIT_STAT_PITCH_PX - 4.0, 30.0 + REFIT_STAT_VALUE_FONT_SIZE_PX))


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

## --- the reveal beats, shared by every screen that stages things in ------------------------------
## ⚠⚠ **These were the node map's own beats and the first two are RENAMED**
## (2026-08-26): the screen they were written for is deleted, and `reward_view` and
## `refit_view` are what read them now. **A constant named after a screen that no longer exists is the
## next reader's wrong guess.**
##
## ⚠⚠ `REVEAL_STEP_SEC` is deliberately BELOW the five-frame floor and it is not an oversight: it is
## the offset BETWEEN beats, not a beat. The beat is `REVEAL_FADE_SEC`, and that one is above the
## floor.
const REVEAL_FADE_SEC := 0.18             # >= 0.084 (five frames); <= 0.40
const REVEAL_STEP_SEC := 0.06             # >= 0.03, under which a staggered row appears all at once

## How long a number takes to climb to a new value. ⚠ **A climb, not a fade** — the digits count.
const NUMBER_CLIMB_SEC := 0.60            # >= 0.30; <= 1.00


## The background: **TILES** drifting behind the menu, drawn by code. **No image file** — see the
## decision "the body is a line drawn by code", which forbids a sprite here as much as in the fight.
## ⚠⚠ **THEY WERE CELLS UNTIL 2026-08-25** (티켓 23) — nine translucent CIRCLES, the deleted cell
## game's own picture, on the first screen of a beast roguelike. **A placeholder chosen by the
## builder** on the user's 「이미지나 이런건 니가 임시로 다 넣으면 됨」; only the shape and the names
## moved, so every measured bound below still describes the drift it was measured on.
## ⚠ **The drift is `sin`/`cos` of the index and the age, with NO RNG**: a random drift cannot be
## measured, and this repo has already paid for that once.
## The two frequencies are coprime-ish so nine tiles do not march in step.
const TITLE_TILE_COUNT := 9               # >= 5, under which the background is three dots rather than
                                          # a drift; <= 16 or it competes with the slots
const TITLE_TILE_HALF_PX := 14.0          # half a tile's edge. >= 8; <= 24
const TITLE_TILE_SPEED_PX := 8.0          # px/s. >= 3 — under it nothing visibly moves over a title's
                                          # dwell; <= 20 or it reads as gameplay
const TITLE_TILE_ALPHA := 0.14            # >= 0.06 or there is no background at all; <= 0.30 or it
                                          # ties `PRESS_ALPHA_OFF` and a drifting cell reads as a
                                          # disabled button
const TITLE_TILE_A_FREQ := 0.13
const TITLE_TILE_B_FREQ := 0.19


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
## ⚠⚠ **A RATIO OF THE DRAWN HALF-WIDTH, and it was a raw 3.0 px until 2026-08-25.** See
## `Look.sprite_half_px`: 3.0 px was chosen on the flat board where a body WAS its sim radius, and it
## survived the move to billboards unchanged — 3 px of flinch on a 49 px animal. **0.22 puts a wolf's
## flinch at 5.4 px**, the same fraction of the picture 3.0 was of the old one, and still above the
## 2.0 px snap floor at every zoom this game opens at.
const HIT_KNOCK_RATIO := 0.22
const HIT_KNOCK_SEC := 0.10

## 4 — the death burst, in that body's own side colour. It is drawn ABOVE everything: on the floor a
## 10 px burst is buried under a 22 px lion.
##
## ⚠⚠ **SCALED TO THE SPRITE, NOT THE SIM RADIUS** (2026-08-24, verify-look): the ring used to start
## at the sim body radius (10-22 px) while the bodies on screen are 84-96 px billboards and deaths
## happen inside packed melee — the fx log showed it alive, both buffer rows were green, and **no
## death ever read on the real screen**. `BURST_START_MUL` is the sprite's own half-width ratio,
## DERIVED from `BEAST_SPRITE_W_RATIO` rather than copied, so the day the animals grow again the
## burst grows with them instead of sinking back under the pile (연출은 과할 정도로).
const BURST_SEC := 0.32
const BURST_START_MUL := BEAST_SPRITE_W_RATIO * 0.5   # crow starts at 30 px, lion at 66
const BURST_GROWTH := 2.2             # lion 66 -> 145.2 px, crow 30 -> 66.0 px — past the pile
const BURST_WIDTH_PX := 9.0           # ⚠ RAISED 5.0 -> 9.0 with the sprite scaling: a 5 px stroke on
                                      # a 105 px ring over an 84 px sprite pile was a hairline. Snap
                                      # floor at ZOOM_MIN is 4.5 px; ceiling is half the crow's own
                                      # start radius, past which the ring closes into a disc.
                                      # ⚠⚠ **THE CEILING MOVED WHEN THE BODIES SHRANK AND THIS NUMBER
                                      # DID NOT.** The crow's start radius was 33.6 px at ratio 6.0 and
                                      # is 19.6 at 3.5, so the ceiling went 16.8 -> 9.8 and 9.0 now
                                      # sits at 46% of the radius instead of 27%. **Still legal, with
                                      # 0.8 px of room.** It is left at 9.0 rather than re-derived
                                      # because deriving it would change today's picture as well, and
                                      # `net_fx_view` now holds the ceiling so the next cut reddens
                                      # here instead of quietly drawing a disc.

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

## `HULL_WAIT_BLINK_SEC` is P7's stalled-boat blink — a full on/off cycle, not a half.
## (`CLIFF_FACE_WIDTH_PX` was deleted 2026-08-24: the seaward-edge line it sized became a real wall
## in the terrain mesh, and its last readers were two net labels bounding a line nothing drew.)
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
## ⚠ **`HOLD_BEAK_SEC` is deleted** (2026-08-25): it timed the picked roster row's stain, and both the
## row and the reward it served are gone.
const PANEL_FADE_SEC := 0.25
const HOLD_OUTCOME_SEC := 0.80

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
## ⚠⚠ **THE SCREEN SHAKE IS DELETED** (2026-08-25, the user: 「이게 화면이 흔들릴 필요는 없을듯?」).
## `SHAKE_SEC` · `SHAKE_PER_DAMAGE_PX` · `SHAKE_MAX_PX` · `SHAKE_A_FREQ` · `SHAKE_B_FREQ` are gone,
## and so are `field_view`'s `_shake_amp`, `_shake_left` and `_shake_offset`. **`net_camera` carries
## the check that they are gone** — a deletion nobody measures comes back as a half-alive constant.
##
## ⚠ **It was briefly switched off at the gain instead, and that was not enough**: leaving a dead
## effect wired keeps every check about it green while it describes something the game no longer does.
## ⚠ **`FX_GAIN` slot 11 is now unused and stays 1.0.** The table is numbered 1..12 for the twelve
## combat-juice effects, and renumbering it would shift every other effect onto its neighbour's gain —
## which is the exact failure `fx_gain_of`'s own comment names.
## ⚠ **`REFUSE_SHAKE_PX` is a DIFFERENT thing and is untouched** — the HUD chip's refusal wobble, whose
## one reader is `hud_view._chip_offset`. It is not the camera.

## ⚠ **RE-MEASURED with `ZOOM_MIN`, and the old value was a real defect at the new one.** At
## `ZOOM_MIN` 0.45 the visible world is 2844.4 px wide against a 1920 px map, so it starts at
## x = (1920 - 2844.4) / 2 = **-462.2 px** — **11.6 tiles** of bare ground on each side, against a
## margin of 5. `net_camera::_painted_area_covers_the_viewport` is the row that catches it.
## The water runs this many tiles wider than the board on every side.
## ⚠⚠ **THE PER-FRAME TERRAIN LOOP THIS NUMBER USED TO PAD IS GONE.** Everything from here down was
## written for a flat 2D board that repainted every tile every frame; the island is one mesh built
## once per island now. **The draw-call budget that stood here (「`_paint_tile` is 2 draw calls, so
## 4872 -> 8064 immediate-mode calls a frame」) was removed 2026-08-27: `_paint_tile` has not existed
## in this view since the field went 3D**, and the note two lines below the constant already said so.
## **The measurements below are kept because they are how the SIZE was chosen**, and the size still
## has to cover the screen at `ZOOM_MIN`.
## ⚠⚠ **RAISED 12 -> 16 when the board was laid back** (2026-08-24, the user: 「밖에 물을 더 그리고
## 좀 더 넓어도 돼 어차피 확대할 수 있어가지고」). **12 was the minimum that covered the screen on a
## FLAT board**, and it stopped covering the moment a row went from 40 px to `TILE_H_PX` 30.64:
## `12 * 40 = 480 px` of cover became `12 * 30.64 = 368 px` against the same 480 that has to be
## covered. `480 / 30.64 = 15.7`, so **16 rows**, and the same number is used on the wide axis
## because the alternative is a per-axis margin threaded through `_visible_tile_rect` for a picture
## nobody would see — the user asked for more water on both sides in the same breath.
## ⚠ **The old ceiling of 16 was written for an UNCULLED loop and no longer binds.** The loop is
## intersected with the visible rect, so what is actually drawn is bounded by the screen and not by
## this number: at `ZOOM_MIN` the visible world is 2844 x 1600 px = 72 x 53 tiles, so the pass grew
## from 3168 to about 3800 tiles — not from 4032 to 5120.
const WATER_MARGIN_TILES := 16

## (`CULL_PAD_TILES` was deleted 2026-08-24: the per-frame terrain loop it padded died with the flat
## board — the island is one mesh built once per island now, and there is no cull left to pad.)

## 12 — gait. Phase turns on DISTANCE TRAVELLED, not on time, and that is the whole of "it must not
## slide": a body that does not move does not animate. Squash is a Vector2 and not a scalar —
## `1 - s*sin(phase)` along the heading, `1 + s*sin(phase)` across it. A scalar radius can only
## pulse uniformly, which is not "squashed along the direction of travel" at all.
## ⚠⚠ **THE IDLE SWAY — what a body does when it CANNOT move.** 2026-08-25, the user:
## 「지금 너무 재미없어 그냥 붙어서 그냥 벌렁벌렁하는 거밖에 없어가지고」, against this repo's own
## standing rule 「붙어서 가만히 있으면 재미가 죽는다」(*"존나 중요해"*).
##
## The gait below phases on DISTANCE, on purpose — 「a body that does not move does not animate」 — and
## that is exactly right for a walk cycle and exactly wrong for everything else, because **a body in
## contact does not move.** So the two bodies the player is watching most closely were the only
## perfectly still things on the island. Measured in the sweep: on 31 of 54 landing tiles a body
## stands over 5 seconds with its target out of reach, worst **22.4 seconds** — every better tile
## reserved, queued behind a one-tile stair.
##
## ⚠ **This does NOT shorten that queue and must not be read as fixing it.** It gives a body that
## cannot advance something to be doing. The queue is a sim question and it is still open.
## ⚠ **A ratio of the drawn half-width** (`Look.sprite_half_px`), so it survives the art changing —
## 0.25 puts a wolf's sway at 6.1 px against a 49 px picture. The period is deliberately far from
## `LUNGE_SEC` (0.18 s) so a sway never reads as a blow.
const IDLE_AFTER_SEC := 0.5           # long enough that a pause between tiles does not wobble
const IDLE_SWAY_RATIO := 0.25         # of the drawn half-width: wolf 6.1 px, bear 8.8, squirrel 3.9
const IDLE_PERIOD_SEC := 1.1

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

## --- what it costs to lay a flat mark on ground that is no longer flat -------------------------------
## ⚠⚠ **These two are NEW with the 3D field and they exist because the board stopped being a board.**
## On the flat board a ring was a ring: one `draw_arc` on the same plane as everything else. On a
## landscape a ring drawn at one height either **buries itself in a hill or floats over a valley**, so
## every ground mark here is cut into pieces and each piece is put down at the height of the ground
## under IT.
##
## `FX_GROUND_LIFT_TILES` is how far above that ground it sits. It has to clear z-fighting with the
## terrain and it must not read as hovering: 0.02 tiles is **0.8 px**, under the 0.90 px world-width
## floor on purpose — this is not a mark to be seen edge-on, it is a mark to be seen from above, and
## anything thicker starts casting its own visible gap on a slope.
const FX_GROUND_LIFT_TILES := 0.02

## How finely a ground mark is cut. **20 px is half a tile**, so no piece can span a whole tile's worth
## of height change; the terrain's own steps are one tile wide, which makes half a tile the largest
## piece that cannot straddle two of them.
## ⚠ Lowering this multiplies triangles on every ring and every route. Raising it makes a route lay a
## chord across a ramp instead of following it.
const FX_GROUND_STEP_PX := 20.0

## ⚠⚠ **The intent lines get a COARSER cut, and it is a budget decision written down.** There can be
## fourteen of them, each crossing most of an island, and at 20 px a single line is forty quads — the
## fourteen together were the largest thing the effect layer built every frame. **They are 1 px wide at
## alpha 0.12 by design** (see `TARGET_LINE_WIDTH_PX`): a hairline that sinks half a tile into a hill
## is invisible, where a ring that does the same is broken. 120 px is three tiles.
const FX_INTENT_STEP_PX := 120.0

## How many segments a ring built in the CAMERA'S plane gets. Ground rings size their own segment
## count off `FX_GROUND_STEP_PX` because they have to follow the ground; an air ring does not, so it
## takes a flat count. **24 keeps the biggest ring here — the lion's death burst at 48 px — under
## 13 px of chord**, which is the point where a circle starts reading as a polygon.
const FX_RING_SEGMENTS := 24

## How high above the ground an effect that has NO body of its own hangs: the tracer's two ends and
## the shard fan. **14 px is about one body radius**, so a tracer leaves and arrives at the height the
## bodies actually stand at rather than skimming their feet.
## ⚠ Effects that DO belong to a body (the halo, the death burst) ignore this and use that body's own
## radius through `_body_anchor` — a crow and a lion do not hang their marks at the same height.
const FX_AIR_LIFT_PX := 14.0

## ⚠⚠ **`FX_SETTLE_FRAMES` WAS DELETED 2026-08-27, AND ITS OWN HEADER PREDICTED IT.** It said "nothing
## in `src/` reads it" and justified living here anyway, so that a capture and the screen could not
## disagree. **No capture ever read it either** — it occurred exactly once in the whole repo, at its
## own declaration, while every shooter hard-coded its own settle count. A number kept so two things
## agree, that neither of them reads, is a number that guarantees nothing.

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
## ⚠ **SLOT 11 IS UNUSED**: it was the screen shake and the shake is deleted (the user, 2026-08-25).
## It stays 1.0 and the table stays twelve long — renumbering would move every effect after it onto
## its neighbour's gain, which is the failure `fx_gain_of` is written to prevent.
const FX_GAIN := [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]


# ---------------------------------------------------------------------------------------------
# Accessors
# ---------------------------------------------------------------------------------------------

## A `const` Array is read-only but its elements are untyped, so every read casts.
static func body_radius_of(type_id: int) -> float:
	return float(BODY_RADIUS_RATIO[type_id]) * TILE_PX


## ⚠⚠ **HOW WIDE THE BODY IS ACTUALLY DRAWN, half of it — and it is NOT `body_radius_of`.**
## The sim radius is the collision-ish size (a wolf is 14 px); the PICTURE is a billboard
## `BEAST_SPRITE_W_RATIO` radii wide (a wolf is 49 px, so its half is 24.5). **Anything the eye is
## meant to see next to a body must be sized off THIS**, and this repo has already paid for the
## difference once: the death burst started at the sim radius, both its buffer rows were green, the
## effect log showed it alive for its whole life, and **no death ever read on screen** because the ring
## was swallowed by the sprite pile.
## ⚠ **The lunge, the knockback and the hit halo carried the same defect until 2026-08-25** and were
## never caught, because unlike the burst they are not *invisible* — they are merely half the size
## they read as, which is what 「그냥 붙어서 벌렁벌렁하는 거밖에 없어」 sounds like from the chair.
## `BURST_START_MUL` is this same quantity expressed as a multiplier and the two must not disagree.
static func sprite_half_px(type_id: int) -> float:
	return body_radius_of(type_id) * BEAST_SPRITE_W_RATIO * 0.5


static func body_corner_radius_of(type_id: int) -> float:
	return float(BODY_CORNER_RATIO[type_id]) * body_radius_of(type_id)


## FX_GAIN holds twelve slots and combat-juice numbers its effects 1..12, so the off-by-one lives
## here and in exactly one place. Spread across callers, one of them eventually reads its
## neighbour's gain and the effect that appears to switch off is the wrong one — which is the
## quietest possible failure, because the round stays green and the screen merely looks different.
## The cast is the same one every read of a `const` Array in this file makes.
static func fx_gain_of(item_no: int) -> float:
	return float(FX_GAIN[item_no - 1])


## The modulate a body's picture is drawn with: its own side colour mixed `BEAST_TEAM_TINT` of the way
## into white. **It lives here and not in `field_view` because every colour in this game lives here**,
## and `net_draw_leaf` reddens on a `Color.` written anywhere else.
static func beast_tint(colour: Color) -> Color:
	return Color.WHITE.lerp(colour, BEAST_TEAM_TINT)


static func body_colour_of(is_enemy: bool) -> Color:
	return COL_ENEMY if is_enemy else COL_ALLY


## `col` pulled toward `COL_BLEED` in proportion to the seconds of bleed still on that body.
##
## ⚠⚠ **THIS IS THE ONLY STATUS THAT REACHES THE SCREEN AT ALL, and that is why it was built.** Four
## of the five beast passives are free to draw — they come out as a body's POSITION or its target, and
## the field already draws those. 출혈 is the fifth and `field_view` had **zero** lines reading
## `status_time`: without this, one of the five ways a run can go would be invisible while the other
## four are obvious, and 「어느 짐승을 데려갈까」 would be a four-way decision on screen.
##
## ⚠ **0 seconds returns `col` untouched**, so a body that is not bleeding is byte-identical to one
## that never was — which is what lets a net read the two side by side.
##
## ⚠⚠ **IT IS APPLIED AFTER `beast_tint` AND NOT BEFORE.** Bleeding first and tinting afterwards pulls
## the result 45% back toward white and throws most of the mix away — measured, the body's HUE did not
## move at all and only its brightness fell 27%, which reads as shade rather than as blood.
## `field_view._put_body` is the one place that composes the two, in that order.
static func bleeding(col: Color, left: float) -> Color:
	if left <= 0.0:
		return col
	return col.lerp(COL_BLEED, clampf(left / BLEED_TINT_SEC, 0.0, 1.0) * BLEED_TINT_MAX)


## ⚠ **`sendable_tint()` is deleted with the two constants it combined.** It washed every sendable
## tile in `COL_SENDABLE` at `DROP_TINT_ALPHA`; `speed-off-open-landing`'s question C replaced that
## whole picture with a mark on what is BLOCKED. `ghost_tint()` below is the surviving example of the
## tone-plus-ratio split this used to be the other half of.
static func hp_bar_colour(filled: bool) -> Color:
	return COL_HP_FULL if filled else COL_HP_EMPTY


## ⚠⚠ **THE TWO LEGEND LOOKUPS WERE DELETED 2026-08-27** — `terrain_colour_of_char` turned an island
## letter into a fill colour and `terrain_height_of_char` turned the same letter into a height. Both
## answered for a ground that GDScript painted tile by tile, and **the letter grid stopped painting
## anything the day the mesh moved to `island.glb`**: the colours arrive baked into the vertices and
## the heights arrive as geometry. Neither function had a caller anywhere in the repo.
##
## ⚠ **`TERRAIN_H_*` and `COL_LAND`/`COL_HOLE`/`COL_CLIFF`/`COL_RAMP`/`COL_WATER`/`COL_STAIR` all
## STAYED, and none of them out of habit.** The five heights are what `terrain_height_ceiling()` below
## takes its maximum over, so deleting them blinds every press on the ground. The colours are how
## `net_fx_view` picks a cliff, a hole, a ramp and the stair OUT of the baked mesh — it counts vertices
## by colour, which is the only check that measures what the bake actually produced.

## The highest the landscape can ever stand, in tiles: the tallest character in the table above plus
## the whole swell that character may carry.
##
## ⚠ **Derived from the same five constants rather than written down as a number.** It is the ceiling
## `field_view.screen_to_terrain_px` starts its search at, and a search that starts BELOW the ground
## walks straight past a hilltop and answers with the sea behind it — which is the defect that function
## exists to close. A hand-written 4.2 would be right until somebody raised one row of the table.
static func terrain_height_ceiling() -> float:
	var tallest := maxf(maxf(TERRAIN_H_WATER, TERRAIN_H_HOLE),
		maxf(TERRAIN_H_LAND, maxf(TERRAIN_H_RAMP, TERRAIN_H_CLIFF)))
	return tallest + HILL_AMP_TILES + FX_GROUND_LIFT_TILES


static func viewport_size_px() -> Vector2:
	return Vector2(VIEWPORT_W_PX, VIEWPORT_H_PX)


## Integer tile coordinates are TILE CENTRES in the sim's continuous space, so a unit sitting on
## tile (3, 4) has position Vector2(3, 4) and is drawn at the middle of that tile. Converting with
## a bare `p * TILE_PX` instead puts every body on a tile corner and the half-tile error is small
## enough to look like a rendering wobble rather than a bug.
static func tile_point_px(p: Vector2) -> Vector2:
	return Vector2((p.x + 0.5) * TILE_PX, (p.y + 0.5) * TILE_H_PX)


static func tile_centre_px(tx: int, ty: int) -> Vector2:
	return tile_point_px(Vector2(tx, ty))


static func tile_rect_px(tx: int, ty: int) -> Rect2:
	return Rect2(Vector2(tx * TILE_PX, ty * TILE_H_PX), Vector2(TILE_PX, TILE_H_PX))


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
## ⚠ **The row's left edge is derived, never stored.** `right - n*w - (n-1)*gap` where `right` is the
## HUD's own margin — so the LAST box always ends at 1268 at one slot, at five, and at anything
## between. Stored as a constant it was correct at five and wrong at two.
##
## ⚠⚠ **`n` IS AN ARGUMENT NOW and no longer asked of `Rules`** (티켓 15). The slot count is a per-RUN
## fact since the slots became `Army.slots`, and a layout function that fetched it from a constant
## would draw a row of a different length from the one the run actually has — while the boxes still
## touched the margin, so the geometry check would stay green.
static func slot_row_origin_x_px(n: int) -> float:
	var span := n * HUD_SLOT_SIZE_PX.x + maxf(0.0, float(n - 1)) * HUD_SLOT_GAP_PX
	return VIEWPORT_W_PX - HUD_MARGIN_PX - span


static func slot_rect_px(i: int, n: int) -> Rect2:
	var x := slot_row_origin_x_px(n) + i * (HUD_SLOT_SIZE_PX.x + HUD_SLOT_GAP_PX)
	return Rect2(Vector2(x, HUD_SLOT_ROW_Y_PX), HUD_SLOT_SIZE_PX)


## The roster bar under slot `i`'s digit: 44 x 8 px, inset 6 either side and 6 up from the bottom.
##
## ⚠ **Derived from `slot_rect_px` here and NOWHERE else.** `hud_view` draws it and `net_slots`
## measures it; geometry written twice is exactly what this second accessor exists to prevent.
static func slot_bar_rect_px(i: int, n: int) -> Rect2:
	var box := slot_rect_px(i, n)
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



static func panel_rect_px() -> Rect2:
	return Rect2(PANEL_ORIGIN_PX, PANEL_SIZE_PX)


## Absolute viewport rectangles, not panel-relative ones: the shell hit-tests a mouse position
## against these, and a relative rect would have to be offset by whoever asked — which is the
## same value living in two places.


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
