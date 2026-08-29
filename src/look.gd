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

## ⚠⚠ **THE 판, AND WHEN ANY OF IT IS ON SCREEN** (2026-08-28, the user: 「마우스올리면 호버되도록
## 해주고 특정버튼 눌러야 그 뜨게해줘 판이」). Blender exports the 판 as its own object inside
## `island.glb`; `src/view/pads.gdshader` reads every one of these five and nothing else decides it.
##
## ⚠ **At rest the board draws NOTHING** — every 판 is fully transparent until the reveal key goes
## down. **A resting alpha above zero would put the grid back on the ground permanently**, the exact
## thing 「위에 노드만 살짝 얹은 느낌이어서 너무 별로」 named.
## ⚠⚠ **AND THE HOVER IS INSIDE THAT GATE** (2026-08-28, the user: 「탭을 눌러서 떳을때만 오버가 되야
## 의미가 있을듯 한데?」). It was outside it for one round: the hovered 칸 rose alone out of blank
## ground with nothing around it to say what it was one of. **A hover means 「this one, of these」**,
## so it shows only while 「these」 are on screen.
##
## ⚠ **The hovered 칸 answers on TWO channels — it rises AND it lightens.** One channel alone was
## what the deleted two-quad mark did, and it read as a sticker rather than as ground.
## ⚠ **The lift is in WORLD units** (one unit is one tile), and it is deliberately small: the 판 is a
## 0.02 lip, so 0.06 is three times its own thickness and still under a tenth of a 조각.
const PAD_ALL_ALPHA := 0.35             # >= 0.15 (under it the reveal reads as nothing); <= 0.60
const PAD_HOVER_ALPHA := 0.85           # > PAD_ALL_ALPHA, or the hovered 칸 loses to the reveal
const PAD_ALL_LIGHTEN := 0.25           # how far the revealed 판 is pulled toward white
const PAD_HOVER_LIGHTEN := 0.55         # > PAD_ALL_LIGHTEN, same reason as the alphas
const PAD_HOVER_LIFT := 0.06            # world units. **3x the 판's own 0.02 thickness**

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
## ⚠⚠ **THIS IS NOW LITERALLY THE COLOUR ON SCREEN** (2026-08-28). The sea shader is `unshaded`
## since the flat-border spike won, so nothing multiplies this any more — no sun, no ambient, no
## specular. **The old value was an albedo that the light roughly doubled**; read straight out it is a
## dark slate, which is why it moves here rather than staying put.
const COL_WATER := Color(0.430, 0.590, 0.660)
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
# ⚠⚠ **`COL_BOAT` AND `COL_HULL_WAIT` STOOD HERE AND BOTH ARE DELETED** (2026-08-29) with the hull
# they painted. The tan was measured on a FLAT BOARD, and in this world's light a 0.85 albedo lands
# past 1.0 — every hull came out **a solid white rectangle** until the material was forced unshaded.
# **A boat has to read the same at every sun angle**, and that is the fact to carry, not the tone.
# ⚠ **`COL_ROUTE` went with the boats** (2026-08-29), and `COL_SENDABLE` with its `DROP_TINT_ALPHA`
# before it (the user: 「못내림만 표시하면 됨 ㅇㅇ」). **The rule they leave: the screen marks what is
# BLOCKED and nothing else** — a tone that washes everything permitted is a colour that rots.
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

## ⚠ **`COL_SUMMON_RING` went with the boats** (2026-08-29). It was pale and cool rather than green
## because a boundary drawn ON the sea replaced a tinted sea — that is the argument, not the tone.
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

## ⚠ **`SUMMON_RING_W_TILES` went with the boats** (2026-08-29), and `SUMMON_RING_SEGMENTS` before it.
## The width bound is the fact worth keeping: under about 0.2 tiles a ring disappears at `ZOOM_MIN`,
## and over about 0.8 it stops being a line and becomes the band it existed to replace.
# ⚠⚠ ==============================================================================================
# **PARKED 2026-08-28 — EVERYTHING FROM HERE TO `WATER_SHORE_OFFSET_TILES` IS UNREAD.** The sea shader
# was replaced whole when the flat-border spike won (`prototypes/shoreline/`), and the sea these belong
# to — swell, ripples, drawn crests, travelling foam, the shallows and the shore warp — is not drawn any
# more. **Turning any of them changes nothing on screen.**
#
# ⚠ **They are kept because they are MEASUREMENTS, not because they are live.** Nearly every one was
# chosen by eye from a sheet of candidates and several record a reversal; the comments are the only
# place those results exist. Deleting them throws away what they cost.
# ⚠ **Still live below them**: `WATER_SHORE_OFFSET_TILES`, `WATER_FIELD_SPAN_TILES` and
# `WATER_FIELD_SUBDIV` — the new shader reads the same baked field, so those three did not park.
# ==============================================================================================

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
## ⚠ **2.6 → 1.4 on 2026-08-28** (the user: 「물주름좀 줄여도 될듯 좀더 리얼한 물을 원함」).
const WATER_RIPPLE_STRENGTH := 1.4
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
## ⚠ **0.70 → 0.30 on 2026-08-28**, same line. The drawn crests are the loudest half of the ripple:
## the bent normal is light finding the water, and this is a white line painted on it.
const WATER_RIPPLE_CRISP := 0.30
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
## ⚠⚠ **PULLED OFF WHITE 2026-08-28** (the user: 「색이 너무 하얀」), the hour the line finally stopped
## floating. **A line that is in the wrong place is judged on where it is; only once it welds is its
## COLOUR the thing you see**, and at 0.880/0.930/0.945 it was very nearly paper. The reference picture
## the user supplied for the surf has it **barely lighter than the sea it lies on**, which is most of
## why that one reads as water and this read as a stroke.
## ✅ **Picked by eye from six** (`tools/shot/out/water/edge_*`): as it was · same colour fainter · a
## shade bluer · bluer and fainter · **this** · nearly gone. **Moving the COLOUR toward the sea beats
## dropping the opacity**: a faint white line is a white line you can hardly see — it still reads as
## paper wherever it is strong — while a sea-toned one reads as water at full strength, which is what
## keeps the hairline the user asked to always be there.
## ⚠⚠ **BACK TOWARD WHITE 2026-08-28, HOURS AFTER BEING PULLED OFF IT, AND THE REVERSAL IS THE
## POINT.** It was taken to 0.630/0.770/0.800 on 「색이 너무 하얀」 — **and that was measured against a
## saturated blue sea.** On the pale sea of `bad-north-foam` a sea-toned line disappears, and the
## reference frames the user then sent have a near-white line on pale water. **What made it read as
## paper was the sea under it, not the line.**
## ⚠⚠ **0.880/0.930/0.945 → 0.630/0.770/0.800 → 0.800/0.880/0.895, ALL ON 2026-08-28.** The middle
## value answered 「색이 너무 하얀」 when there was ONE line at the rock and nothing else; with the rings
## standing off the shore a sea-toned foam left the outer two barely there. **This is the value
## picked by eye from those three, shot on the sea this game actually has** — the earlier near-white
## candidate came off a reference frame whose sea is pale grey, and a colour judged against that sea
## is not a colour for this one.
## ⚠ **Also literal now**, for the same reason as `COL_WATER` above: the sea is unshaded, so the
## line is drawn at exactly this and the earlier hunt for a value that survived the lighting is over.
const COL_WATER_FOAM := Color(0.900, 0.940, 0.950)
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
## ⚠⚠ **`bad-north-foam`: 2.2 → 3.4.** The rings have to stand CLEAR of the rock; at 2.2 the outermost
## died before it was off the shore and there was one line, not three.
## ⚠ **`shore-not-rings`: 3.4 → 1.8.** Reach came back in with the ring count.
## ⚠ **1.8 → 1.0 on 2026-08-28** (the user: 「거품도 너무 멀리서 와서 별로긴하다 조금씩만 있으면되고」).
const WATER_FOAM_TILES := 1.0
## How fast a line travels in, in cycles per second. **Slow**: a shore washes about once every three
## seconds, and faster reads as a flicker.
const WATER_FOAM_SPEED := 0.28
## How many lines are inside that reach at once. Above about 4 they crowd into stripes.
## ⚠⚠ **`bad-north-foam`: 1.2 → 2.6.** One and a bit bands is one ring. The reference frames have two
## or three, evenly spaced, and that count IS the look.
## ⚠⚠ **`shore-not-rings`: 2.6 → 1.0, ONE ROUND AFTER GOING 1.2 → 2.6.** The three rings were built on a
## misreading of the same pictures. **One band, and faint.**
const WATER_FOAM_BANDS := 1.0
## How thin each line is. It is an exponent on a cosine: 1 is a soft gradient, 8 is a hard edge.
## ✅ **Chosen by eye from four thicknesses** (2026-08-26, the user: 「3번이 적당하네」). ⚠ **A high
## exponent is the CHEAP way to a thin line** — it costs one `pow` and no extra sampling — but it also
## means the line's width is not a distance anybody can read off this number. If the shore ever has to
## be a measured width, this is the wrong dial.
## ⚠⚠ **Softened 2026-08-28 from 26.** At 26 a line was a wire — under a pixel wide at this camera and
## invisible at anything but a close zoom.
## ⚠ **`bad-north-foam`: 16 → 18.** Barely moved, and it is recorded because two rounds were spent
## taking it DOWN to 6 chasing 「부드럽게」 — which produced soft slabs. **The reference rings are thin,
## and a high exponent is what makes them thin.**
const WATER_FOAM_SHARP := 18.0
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
## ⚠⚠ **`bad-north-foam`: 0.9 → 0.15, AND THIS DIAL'S WHOLE PURPOSE IS NOW MOSTLY OFF.** It exists to
## stop the lines being concentric — 「without it the lines are concentric and read as a diagram」.
## **The reference frames ARE concentric**, so what was written down as the defect is the thing the
## user is pointing at. Left at a trace so a headland is not perfectly symmetrical.
const WATER_FOAM_BREAK := 0.15
## How quickly that drift changes as you walk along the coast. Small: a stretch of shore has to act
## together over a few tiles or the lines shatter into speckle.
const WATER_FOAM_BREAK_SCALE := 0.35
## ⚠ **The thin permanent lip right at the land**, separate from the lines. Water always touches the
## shore; the lines are what runs up over it.
## ⚠⚠ **Thinned 2026-08-28 from 0.18** (the user: 「얇고 투명하고 조금 티가 나게」).
## ⚠ **This is the width at REST and `WATER_FOAM_LIP_WOB` swings it either side**, so at 1.0 the line
## runs from nothing to twice this. Read the two together or the thickness on screen is a surprise.
## ⚠⚠ **`shore-not-rings`, 2026-08-28** (the user: 「거품이 많아졌는데.. 그 내가 원한건 이미지에서 그
## 물가임 ... 거품도 엄청적어」). **The reference frames were read as RINGS and they are not** — what they
## carry is a soft pale band welded to the rock whose WIDTH changes along the coast, and at most one
## faint line out in the water. ⇒ the swash was widened until it is the thing you see, and the
## travelling foam was taken down to one faint band. **Picked by eye from six.**
## ⚠ **0.22 → 0.25 on 2026-08-28** (the user, on the arc coast: 「살짝만 아주살짝만 두꺼게해줘」).
## A step and not a jump: the two before it were 0.06 → 0.22, and this is the first time the band has
## been in the right neighbourhood to be nudged rather than moved.
const WATER_FOAM_LIP_TILES := 0.25
## ⚠⚠ **How hard that lip's outer edge is, and 0 is the fade it was born with.** The band was
## `1 - smoothstep(0, w, d)`, which starts dying the instant it leaves the rock — so what stood at the
## coast was a soft halo, and an island wearing a soft halo reads as glowing rather than as wet. At 1
## the band holds its full strength almost to its edge and then stops.
const WATER_FOAM_LIP_HARD := 0.0
## ⚠⚠ **How opaque the lip is where it is strongest, and it was a literal `0.85` in the shader.** The
## user asked for the line to be **얇고 투명하고 조금 티가 나게** (2026-08-28) — noticed, not announced.
## At 0.85 it was very nearly the foam's own white and read as a sticker cut round the island.
## ⚠ **0.28 → 0.26 with the colour change of 2026-08-28**: the tone carries the softening now, and
## the opacity came down only enough to keep the wash under the permanent line rather than over it.
## ⚠ **`shore-not-rings`: 0.26 → 0.34.** It is the shore's whole appearance now rather than a wash
## under a line, so it carries the strength the travelling foam gave up.
const WATER_FOAM_LIP_ALPHA := 0.34
## ⚠⚠ **How opaque the travelling lines are at their strongest, and it was a literal `0.95` in the
## shader** — the foam colour very nearly undiluted. **In the reference picture the user supplied
## (`docs/reference/2026-08-27-bad-north-two-storey-island.png`) the surf is barely lighter than the sea
## it lies on**, which is most of why it reads as water and this read as a stroke.
## ✅ **Cut on 2026-08-28** (the user: 「조금 과하긴 해 저 거품이」 and then 「거품은 조금만 있어도 될 거
## 같아, 얇게」). **Fewer lines and thinner ones, not fainter ones** — the reach and the count came down
## with it, and the opacity went back UP a little: a line too faint to see is not a thin line, it is a
## missing one.
## ⚠ **0.40 → 0.36 with the colour change of 2026-08-28.** Same reason as the lip's: the sea-toned
## foam is quieter on its own, so this only had to come off the top.
## ⚠ **`bad-north-foam`: 0.36 → 0.42.** Up, not down: there are three rings now instead of one and each
## has to read on its own.
## ⚠ **`shore-not-rings`: 0.42 → 0.15.** 「거품도 엄청적어」 is this number.
const WATER_FOAM_ALPHA := 0.15
## ⚠⚠ **How much the lip's width swings — and a still lip is the reason it read as a sticker no matter
## how thin it got** (2026-08-28, the user: 「물가가 유동적으로 움직여야 좀 제대로 보이고, 얇아졌다가
## 약간 두꺼워졌다가 떨어져 나갔다가 하는 게 중요할 듯」). **Thinner and fainter were both tried first and
## neither worked**, because the thing being recognised is not the line's size, it is that water does not
## hold still. At 1 the width swings from nothing — a real gap in the line — to double.
## ⚠ **Brought down from 1.0 on 2026-08-28** (the user: 「너무 두꺼워졌다가 얇아졌다가 하고 있고」). The
## swing was doing all the work on its own; the peel below now carries most of the movement, so the
## shore's own line can hold a steadier width.
## ⚠ **`shore-not-rings`: 0.55 → 0.80.** **The naturalness in the reference frames IS the width
## changing along the coast** — thick through a bay, thin off a point — so the swing goes up now that
## the band is wide enough for a swing to be visible in it.
const WATER_FOAM_LIP_WOB := 0.80
## How long a stretch of coast shares one width, in inverted tiles — about 4 tiles at 0.25 — and how fast
## that width changes. ⚠ **Slow.** A line that flickers reads as a fault, not as a shore.
const WATER_FOAM_LIP_WOB_SCALE := 0.25
const WATER_FOAM_LIP_WOB_SPEED := 0.11
## ⚠⚠ **How strongly the shore lets a line GO** (2026-08-28, the user: 「가끔씩 두 줄이 되기도 하면 좋을
## 거 같은데 ... 멀어지면서 사라지는 거 있잖아. 진짜인 것처럼」). Once a cycle, over patches of coast, the
## line separates from the rock and travels seaward, fading as it goes. **The two lines are the same
## line at two ages**, which is what backwash actually looks like.
## ⚠ **`shore-not-rings`: 0.85 → 0.45.** The peel is the one faint line the reference frames have out
## in the water, so it stays — but it was strong enough to be a second shoreline.
const WATER_FOAM_LIP_PEEL := 0.45
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
## ⚠⚠ **RAISED 2026-08-28 FROM 0.045, AND THE FLOOR ABOVE IS A TEXEL FLOOR** (the user: 「지금
## 사진보면 떨어져있음」). The 「분질로 깨진다」 measured at 0.030 was never about the number:
## `WATER_FIELD_SUBDIV` is 16, so **one texel is 0.0625 of a tile** and a line thinner than that is
## asking the field for detail it does not carry — the distance between texel centres is interpolated
## straight, so the band's width wanders texel to texel and the line comes out dashed. **0.045 was
## SUB-TEXEL and only looked continuous because the warp was smearing it**; welding it to the true
## shore is what exposed the dots. ⇒ **Just over one texel.** ⚠ **The way to go thinner is a finer
## field, not a smaller number here** — that was already written and it is now measured.
## ⚠⚠ **BACK TO 0.045 ONCE THE FIELD WAS SIGNED, AND THE TEXEL FLOOR WAS NEVER THE REAL FLOOR.**
## It went to 0.08 an hour earlier to escape a dashed line, on the reasoning that one texel is 0.0625
## of a tile and a thinner band is asking the field for detail it does not carry. **That was measuring
## the wrong thing.** The dashes came from the field being UNSIGNED: absolute distance has a CREASE at
## the coastline, and a band straddling that crease samples a value that folds back on itself, so its
## width wandered texel to texel. A signed field is smooth straight through zero — the interpolation
## has nothing to fold — and 0.045 comes out as a clean line at the same resolution.
## ⚠ **0.08 also broke what it was widened for**: at 0.08 the hairline was WIDER than the swash that is
## supposed to swing outside it (`WATER_FOAM_LIP_TILES` 0.06), so the shore's movement was drawn
## entirely inside a band that never moves, and the coast read as painted on.
const WATER_FOAM_LIP_MIN_TILES := 0.045
## ⚠ **Its own opacity, well above the wash's.** The wash is faint on purpose so it does not read as a
## stroke; this one is meant to be seen, and it cannot borrow an opacity chosen to hide something.
## ✅ **Picked by eye from four** (2026-08-28). At 0.60 it reads as a marker pen round the island, which
## is the 「그냥 흰색 선」 this whole round has been walking away from.
## ⚠ **Held at 0.30 through the colour change of 2026-08-28, and NOT dropped with the others.** This
## is the hairline that has to be there on every frame; the tone is what stopped it reading as white,
## and taking its opacity down as well is how a permanent line becomes an intermittent one.
const WATER_FOAM_LIP_EDGE_ALPHA := 0.30
## ⚠⚠ **Where inside its reach the travelling lines live, as fractions of `WATER_FOAM_TILES`.** These
## two were literals in the shader and they are the reason the lines could barely be found: 0.18 and
## 0.35 of a 2.6-tile reach put every line between 0.47 and 0.91 tiles off the coast, a ring one third
## of a tile thick. **The lines were drawn across the whole reach and then faded out over nearly all of
## it.** `IN` is how quickly they come up out of the shore, `OUT` is where they start dying toward the
## open sea.
const WATER_FOAM_FADE_IN := 0.05
## ⚠ **`bad-north-foam`: 0.70 → 0.90**, so the outermost ring survives to the edge of its reach
## instead of being faded out over the last third of it.
const WATER_FOAM_FADE_OUT := 0.90
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
## ⚠ **`bad-north-foam`: 0.55 → 0.92.** A ring that is switched off down one stretch of coast is a
## broken ring, and the reference frames close all the way round.
const WATER_FOAM_GATE_FLOOR := 0.92
## ⚠⚠ **How hard the sheltered coast is spared.** Waves arrive FROM somewhere — the shore facing into
## the wind takes them and the lee shore is nearly flat. A ring of identical surf all the way round is
## what says nothing is actually arriving. Shares the ripple's wind direction on purpose: one weather.
## ✅ **Chosen by eye from four** (2026-08-26): all-round · gentle · this · strong. The user: 「3번이
## 맞긴 한데」.
## ⚠⚠ **`bad-north-foam`: 2.4 → 0.6**, and this one was CHOSEN by eye from four on 2026-08-26. It is
## being walked back on new evidence, not on argument: the reference frames have the rings closing
## round the whole island, so a sheltered coast cannot be nearly bare.
const WATER_FOAM_LEE := 0.6
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
## ⚠⚠ **BACK TO 0.30 ON 2026-08-28, AND THIS TIME IT IS DERIVED AND NOT EYEBALLED** (the user:
## 「왜 저게 흔색 이 거품이 딱 붙질 못할까」). **The bake measures the coastline where the shore crosses
## `SEA_Z = -0.45`, and the game's water plane is not there any more** — `SEA_Y_TILES` was raised to
## +0.075 the same day, on the user's 「물 높이를 좀 더 올려줄래?」. Half a tile of height between the
## line the sea was told about and the line the sea actually draws itself at, and `island_build.py`
## still says in its own comment that the water sits at 0. **A raised sea swallows more of the shore's
## roll, so the REAL waterline climbs inward up that roll while the exported one stays out at the hem.**
## ⇒ the white line stood a third of a tile out to sea all the way round, on every side at once, which
## is the shape the user kept seeing and no amount of shader work could reach.
## ⚠ **The number is read off the skirt, not judged by eye**: the roll runs from the top edge
## (`TOP_H` 0.20, offset 0) through the knee (`SKIRT * SKIRT_ROLL` = 0.253, z -0.038) to the hem
## (`SKIRT` 0.46, z -0.50). It crosses -0.45 at 0.438 out and +0.075 at 0.133 out — **0.305 apart.**
## ⚠⚠ **THIS IS A PATCH OVER A DISAGREEMENT, NOT THE REPAIR.** The repair is for the bake to measure
## its waterline at the height the game's sea is actually at; until Blender runs again this holds the
## line on the rock. **If either height moves, this number is wrong and nothing will say so.**
## ✅ **BACK TO 0 ON 2026-08-28 — THE BAKE MEASURES ITS WATERLINE AT THE GAME'S SEA HEIGHT NOW.**
## The 0.30 above was a patch over a disagreement between two numbers, and it said so; the bake now
## carries `SEA_LINE_Z`, so the exported line is where the sea actually meets the rock and there is
## nothing left to shift. ⚠ **Left as a dial rather than deleted**: it is still the one number that
## re-aligns the water to the land if the bake's shore ever moves again.
const WATER_SHORE_OFFSET_TILES := 0.0
## ⚠⚠ **How far the shore's sample point is dragged about before the distance is read, in tiles — and
## this is the answer to 「너무 그래픽적」** (2026-08-28, the user: 「이게 뭔가 흐름처럼 곡선이어야 되는데
## 이게 전혀 그런 게 없으니까」). **A band at a fixed distance from a line is that line's parallel offset**
## — no amount of softening, thinning or width-swinging changes that, because the SHAPE is still the
## island's outline scaled out. Warping where the distance is measured from is what breaks it, and it is
## the standard technique rather than one invented here.
## ⚠ Bigger than the lip's own width on purpose: below about 0.2 the band still traces the outline.
## ⚠⚠ **`bad-north-foam`: 0.35 → 0.08.** Same reversal as `WATER_FOAM_BREAK`: this was the answer to
## 「너무 그래픽적」 and the reference frames are exactly that — clean offset rings. Left at a trace so
## the outermost ring is not a perfect scaled copy of the outline.
const WATER_SHORE_WARP_TILES := 0.08
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

# ⚠⚠ ==============================================================================================
# **해안선 — the whole sea, since 2026-08-28.** Seven mechanisms were built side by side on one block in
# `prototypes/shoreline/` and the user chose the one that does the least: **a flat sea and a border.**
# Everything above this line that is not `COL_WATER` or `COL_WATER_FOAM` belongs to the sea that was
# replaced, and **nothing reads it any more** — see the parking note over that block.
#
# ⚠⚠ **FOUR MOTIONS RUN AT ONCE AND NONE IS IN STEP WITH THE OTHERS** (the user: 「단순하게 원이 아니라
# 이제 복합적으로 움직이는걸 원한 진짜 물처럼」). **A border on one clock is a ring pulsing**, and that is
# what「원 같다」was. Take any one of the four out and it goes back to being a ring.
# ==============================================================================================

## **해안선's width at rest, in tiles.** ⚠ The swing below runs either side of it.
const WATER_LINE_TILES := 0.075
## How hard its outer edge is. 1 holds full strength to the edge and stops; 0 is a fade the whole way.
const WATER_LINE_HARD := 0.45
const WATER_LINE_ALPHA := 0.90

## **1. The shape of the line: three octaves, three sizes, three drifts.** ⚠ The amplitudes are in
## TILES and they add, so the line can wander by their sum. The scales are inverted tiles — 0.45 is a
## bend about two tiles across, 3.6 is a fray under a third of one.
const WATER_WARP_A := 0.055
const WATER_WARP_A_SCALE := 0.45
const WATER_WARP_A_SPEED := 0.055
const WATER_WARP_B := 0.030
const WATER_WARP_B_SCALE := 1.30
const WATER_WARP_B_SPEED := 0.130
const WATER_WARP_C := 0.014
const WATER_WARP_C_SCALE := 3.60
const WATER_WARP_C_SPEED := 0.260

## **2. How much the width swings, how fast, and how long a stretch of coast shares one phase.**
## ⚠⚠ `WATER_ALONG_SCALE` is the ring-breaker: the phase is read along the coast, so one stretch is
## running up while the next draws back.
const WATER_SWING := 0.75
const WATER_SWING_RATE := 0.55
const WATER_ALONG_SCALE := 0.55
## How thin a stretch gets at the bottom of its swing, as a fraction of the resting width. ⚠ **Not 0**:
## a line that vanishes is a line that blinks, and a blink reads as a fault rather than as water.
const WATER_SWING_FLOOR := 0.18

## **3. The one that lets go**, how far it gets before it is gone in tiles, and how wide a patch of coast
## does it at all. ⚠ Over patches only, or the island wears two concentric rings.
const WATER_PEEL := 0.55
const WATER_PEEL_TILES := 0.42

## ⚠⚠ **`WATER_ROLL` / `WATER_ROLL_TILES` STOOD HERE FOR ONE ROUND** (2026-08-29). They were 거품 —
## the white line pushed IN toward the rim, which the sea had been missing since the 2026-08-28 rebuild
## left it only the shoreline's breathing and the line that travels seaward. **The user asked for it,
## saw it, and took it back**: 「별로다... 그 거품없애봐」.
## ⇒ **The flat sea with one border stands**, now confirmed twice — once by seven candidates rendered
## side by side, and once by adding the thing back and looking at it.

const WATER_PEEL_GATE_SCALE := 0.85

## **4. How much of the coast is quiet**, how wide a quiet stretch is in inverted tiles, and how slowly
## the quiet places move. ⚠ At 0 every part of the shore is equally lively, which is its own kind of ring.
const WATER_CALM := 0.45
const WATER_CALM_SCALE := 0.38
const WATER_CALM_SPEED := 0.035

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
## body radius and the halo read `BODY_RADIUS_RATIO` and do not move at all. (`hp_bar_origin_px` was
## the third reader and is deleted, 2026-08-28.)
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
## ⚠⚠ **THE HP BAR IS DELETED AND ITS THREE CONSTANTS WITH IT** (2026-08-28, the user: 「체력바 없이」)
## — `HP_BAR_W_PX`, `HP_BAR_H_PX`, `HP_BAR_GAP_PX`, and `hp_bar_origin_px` / `hp_bar_size_px` /
## `hp_bar_colour` further down. **The sim still tracks HP** and still decides who dies; nothing on
## screen says so, and the screen that will is designed rather than typed (`CLAUDE.md`).

## ⚠⚠ **A BODY'S SHADOW IS ONE DISC ON THE GROUND** (2026-08-28, the user: 「그림자도 단순하게 아래
## 동그라미정도해줘」). A billboard's real cast shadow is the shadow of a flat card that turns to face
## the camera — it swings as the board turns, which is the one thing a shadow must not do — so
## `field_view._sprite` stops casting one and this disc is what a body has instead.
##
## ⚠⚠ **THE ISLAND, THE BUILDINGS AND THE PROPS KEEP THEIR REAL SHADOWS**, and that is the line this
## does not cross. A disc was laid under every prop and building on 2026-08-25 and DELETED the next day
## because it stood beside a real shadow pointing the other way (the user: 「해 기준으로 그림자가 있어야
## 하는데 이게 좀 안 그런거 같음」 · 「해 하나가 맞는듯」). **A body now has exactly one shadow — this
## one — so that objection does not apply**, and the rule it produced still holds everywhere else.
##
## ⚠ **Radius is a MULTIPLE of the body's drawn half-width**, not a constant: five species draw at five
## sizes and one number would fit the smallest or the largest, never both.
const BODY_SHADOW_RADIUS_RATIO := 0.62   # >= 0.4 (under it the disc reads as a dot); <= 1.0
const COL_BODY_SHADOW := Color(0.05, 0.06, 0.10, 0.30)  # alpha <= 0.45, over which it reads as a hole

## ⚠⚠ **`BOAT_SLOT_PX` · `BOAT_HULL_PAD_PX` · `BOAT_HULL_H_PX` STOOD HERE AND ALL THREE ARE
## DELETED** (2026-08-29) with the hull that read them. Every hull was the same size, 46 px wide:
## one press made one boat and it carried the one body that press spent.

# ---------------------------------------------------------------------------------------------
# HUD — DELETED 2026-08-29
# ---------------------------------------------------------------------------------------------
## ⚠⚠ **Nineteen constants stood here and their only readers were five accessors in this same file.**
## `HudView._draw` has been `pass` since the island screen lost its chrome, so the start button, the
## slot row, the reserve bars, the enemy counter and the ghost fan were laid out in pixels nobody
## drew. **A designed HUD is built in a tool and measured then** — see `CLAUDE.md`.
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
# The reward screen and the refit screen — DELETED 2026-08-29
# ---------------------------------------------------------------------------------------------
## ⚠⚠ **82 constants and 20 accessors stood here and every one of them is gone.** Both screens were
## deleted on 2026-08-28 (`RewardView`, `RefitView`, `Run.State.PICK`, `Run.State.REFIT`) and this
## file kept their measurements for a day with nothing on earth reading them. **Nothing outside this
## block referenced a single symbol in it — measured, not assumed.**
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

## ⚠⚠ **`ROUTE_WIDTH_PX` AND `TARGET_RING_R_PX` STOOD HERE AND BOTH ARE DELETED** (2026-08-29) with
## the drag overlay and the boats. **The measurement they cost is the world-width table**: a line
## specified in world px reaches the glass multiplied by the zoom, so at `ZOOM_MIN` 0.45 a 3.0 px
## route drew at **1.35 px** — under this file's own 2.0 px snap floor, at exactly the zoom an island
## opens at. A capture found only the axis-aligned leg rasterising at all. **5.0 was the value both
## `REFUSE_MARK_WIDTH_PX` and `CLIFF_FACE_WIDTH_PX` had already been re-measured to**, and this was
## the third row of that table that nobody re-measured. ⚠ **Any new world-space line does this sum.**

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

## ⚠ **`HULL_WAIT_BLINK_SEC` went with the boats** (2026-08-29) — a stalled hull's blink, a full
## on/off cycle rather than a half. **A blink under 0.3 s is five frames at 60fps and is not seen.**
## (`CLIFF_FACE_WIDTH_PX` was deleted 2026-08-24: the seaward-edge line it sized became a real wall
## in the terrain mesh, and its last readers were two net labels bounding a line nothing drew.)

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


## ⚠⚠ **`bleeding()` STOOD HERE AND IT IS DELETED** (2026-08-29) with `COL_BLEED` and the two
## tint constants. It was the only status that ever reached the screen, and it drew a clock that was
## always zero — see `battle.gd`'s status block.


## ⚠⚠ **`hp_bar_colour` STOOD HERE AND IS DELETED** (2026-08-28) with the bar it coloured, and
## `hp_bar_origin_px` / `hp_bar_size_px` further down with it. See `BODY_SHADOW_RADIUS_RATIO` above
## for what a body carries now.


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


## ⚠⚠ **`start_rect_px` · `slot_row_origin_x_px` · `slot_rect_px` · `slot_bar_rect_px` · `ghost_tint`
## STOOD HERE AND ALL FIVE ARE DELETED** (2026-08-29) with the `HUD_*` constants they were the only
## readers of. **Nothing outside this file ever called one** — the island screen has carried no chrome
## since the start button and the slot row were deleted, and a rectangle nobody draws is not a layout.

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

