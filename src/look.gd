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
## the user: 「기울기도 조절 되었으면 좋겠네」). The yaw got its handle first — Q and E, deleted on
## 2026-08-31, the drag left standing — and the same
## argument carries: **the tilt does not change what happens, only what is visible**, so it is not the
## hand moving during combat in the sense the base rule forbids (see 티켓 07's answer).
##
## Floor 20 — under it the ground is nearly edge-on, bodies stand in front of each other in a single
## row and the island stops being a map. Ceiling 80 — past it the terrain's own height stops reading
## at all, which is the flat board the 3D move was for.
## ⚠⚠ **HOW FAR A BODY IS STRETCHED BACK UP WHEN THE CAMERA LOOKS DOWN** (2026-08-31, 개발지식 01
## 기법 22). Since the bodies became `BILLBOARD_FIXED_Y` they stand upright in the WORLD, so pitching
## the camera down foreshortens them — at 80 degrees a standing man is 17% of his height and reads as
## a puddle. The stretch is `cos(CAM_PITCH_DEG) / cos(cam_pitch_deg)`, which is **exactly 1.0 at the
## opening angle**: the 27 px the user chose at the screen is the height every other angle is pulled
## back toward, rather than some new height nobody looked at.
## ⚠ **The cap is a dial and it is not measured.** Full compensation at 80 degrees is 4.4x, a man
## drawn four times his own height to fight an angle the camera is allowed to reach. 2.0 stops it at
## about 67 degrees and lets the rest foreshorten honestly. **Move it by eye.**
const BILLBOARD_PITCH_STRETCH_MAX := 2.0

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

## --- the plants MOVE ------------------------------------------------------------------------------
##
## ⚠⚠ **The bush's whole job is that the map is not still** (2026-08-31, the user: 「that bush is just
## the amount it sways when it moves — the whole intent is to make the map not look monotonous」).
##
## **A prop LEANS about its own base; nothing bends.** A bend needs a vertex shader, and a vertex
## shader has to be written twice here because every prop carries an inverted-hull outline as a
## `next_pass` — displace the mesh and not the shell and the ink peels off the object. **A lean is one
## Basis per prop per frame and the outline follows for free**, and at 25 to 55 screen px the two are
## not told apart. ⚠ **If a tree ever has to bend rather than lean, that is the round to write the
## shader in, and the shell is the trap.**
##
## ⚠⚠ **A PICTURE PROP CANNOT DO THIS AT ALL.** `BILLBOARD_FIXED_Y` has its basis rebuilt every frame
## and throws the node's rotation away — measured on this repo's own 기법 23, which is inert for
## exactly that reason. **Swaying is a thing only a mesh can be asked for.**

## **How far a prop leans, in degrees, by kind.** ⚠⚠ **A kind that is not in this table does not move**,
## and that is the safe way round: a still rock is invisible, a swaying rock is loud. **The tip travels
## `height * sin(deg)`**, so a tall thing moves further than a short one off the same number — which is
## what wind does.
## ⚠⚠ **MEASURED AND RAISED THE SAME ROUND.** The first cut leaned a bush 5° and its tip travelled
## **1.25 screen px** across a whole cycle — arithmetically a sway and visually nothing. A bush is
## only 0.62 조각 tall, so the angle has to be large for the tip to move at all. **These numbers are
## what the screen needed, not what a tree does in a photograph.**
const PROP_SWAY_DEG_OF := {
	"bush_mound": 12.0,
	"bush_two": 12.0,
	"bush_scrub": 15.0,
	"bush_thicket": 15.0,
	"tree_pine": 3.2,
	"tree_oak": 4.0,
	"tree_cluster": 4.0,
	"tree_bare": 4.5,
	"tree_umbrella": 4.2,
	"tree_young": 7.0,
}

## Full cycles a second. ⚠ **Slow on purpose** — the map has to stop being still, not start being busy.
const PROP_SWAY_HZ := 0.19

## Which way the wind blows, as a compass angle in the ground plane. **One direction for the whole
## island**: plants that lean independently read as a bug, not as weather.
const PROP_SWAY_WIND_DEG := 35.0

## How much of the lean comes from a second, slower wave. **Two waves and no random number** — one
## sine makes every plant a metronome, and this repo does not roll dice at load time.
## ⚠ **0.45 -> 0.30 the same round.** At 0.45 the slow wave took nearly half the lean and, because it
## turns once every fourteen seconds, most of the movement was simply gone. **The gust is seasoning.**
const PROP_SWAY_GUST := 0.30
const PROP_SWAY_GUST_HZ := 0.071

## --- and the same wind, for a prop drawn as a CARD -------------------------------------------------
##
## ⚠⚠ **A card bends, a mesh leans, and the two need different numbers.** The mesh turns about its
## base, so its number is an angle; the card displaces its top vertices sideways in world units,
## weighted to zero at the roots. **They read off one clock so a card and a bush never blow different
## weather** — see `field_view._paint_flat_props`.

## How far the top of a card is pushed, in 조각, at full weight.
const PROP_CARD_WIND_STRENGTH := 0.075
## Radians a second inside the card's own two-sine wave. ⚠ **Not `PROP_SWAY_HZ`** — that one counts
## whole cycles because the mesh's wave is a triangle; this one is fed to `sin` directly.
const PROP_CARD_WIND_SPEED := 2.1


## --- a prop drawn as a PICTURE rather than a mesh --------------------------------------------------
##
## ⚠⚠ **The tree and the bush are 2D and the stone, the ore and the buildings are 3D** (2026-08-31,
## the user). A prop kind is now either a node in `props.glb` or a picture in `assets/props/flat/`,
## and these two numbers are everything the picture path decides.

## **How many world px one picture pixel draws as.** ⚠⚠ **1.0 means one texture pixel per screen pixel
## at the opening zoom**, which is the rule the pixel pipeline already states and the rule the wolf
## broke: a 64 px picture drawn 20.9 px wide keeps one pixel in 9.4 and drops the rest, so a branch
## lands on a dropped row and vanishes. **A 64 px tree therefore stands 1.6 조각 tall.**
## ⚠ **This is the knob if a tree is the wrong size** — not the picture, and not the row's own `scale`,
## which is there to make ONE prop differ from its neighbours.
const PROP_PIC_SCALE := 1.0

## The same hair of lift `BODY_LIFT_PX` gives a body, for the same reason: a picture's bottom row
## sinking into the ground it stands on reads as a prop half-buried.
const PROP_PIC_LIFT_PX := 1.0


## --- 개발지식 01, the four techniques the game was NOT running -------------------------------------
##
## ⚠⚠ **THE USER ASKED FOR EVERYTHING EXCEPT 14 AND 16** (2026-08-31): 「take 14 and 16 out and show me
## it in my game」. **14 is the deliberate wrong answer** (a billboard's real shadow swings as the board
## turns) and **16 was measured today to blow the faction colour to white** — see `_sprite`'s own note.
## The four below are what was left over once those two and the seven already running came out.
##
## ⚠ **25 (숨쉬기) is NOT here on purpose.** It is on the folder's endorsed list and the user **deleted
## it by hand earlier the same day** — 「that springy up-and-down animation, just get rid of it」. The
## request above does not re-open a thing the same person closed six hours earlier.
## ⚠ **2 (카메라 각도 고정) is not here either**: the folder's own conflict table says locking the pitch
## costs the tilt control this game already has, and **that is a trade the user picks, not a constant.**

## **기법 17 · 외곽선.** How much bigger the black copy behind a body is drawn.
##
## ⚠⚠ **1.04 IS ONE SCREEN PIXEL AND IT WAS PHOTOGRAPHED AGAINST 1.10** (2026-08-31). The lab ships
## 1.10 and marks it a guess; **Bad North's own answer is one pixel and no more**, which at a 27 px
## swordsman is 1.037 and at a 20.9 px wolf is 1.048 — **1.04 is one pixel for both bodies at once.**
## **What 1.10 looked like**: a 2 px rim on a 21 px animal. The swordsman survived it because he is a
## flat pale shape, but **the wolves went solid black** — the rim ate the fur it was supposed to edge.
## ⇒ **This number is a fraction of the BODY, so it moves whenever a body's drawn size does.**
const BODY_OUTLINE_SCALE := 1.04

## The outline's colour. Near-black rather than black so it reads as an edge and not as a hole.
const COL_BODY_OUTLINE := Color(0.09, 0.08, 0.10, 1.0)

## How far the outline copy is pushed AWAY from the camera, in 조각. ⚠ **Along the camera's own axis,
## never the world's** — pushed along world Z the copy slides out from behind the body the moment the
## board turns, because a billboard faces the screen and not the world.
const BODY_OUTLINE_BACK_TILES := 0.03

## **기법 23 · 살짝 뒤로 눕히기**, in degrees. ⚠⚠ **MEASURED INERT ON A BILLBOARD** (2026-08-31): a
## `BILLBOARD_FIXED_Y` sprite has its basis rebuilt by the engine every frame, so a node rotation set
## here is thrown away. **Kept as a constant with its measurement**, because the technique is real —
## it just needs the lean baked into the picture or a non-billboard quad, and neither is this line.
const BODY_LEAN_DEG := 0.0

## **기법 24 · 깊이 조금 밀어주기 — 0.0, AND IT WAS TRIED** (2026-08-31). Under an ORTHOGRAPHIC camera
## moving a body along the camera's own axis is invisible on screen, but **the world position moves and
## this camera is pitched, so the body rose 0.0245 조각 off the ground** — the frame-bottom row of
## `net_fx_view` reddened on it within one round. ⇒ **The technique wants a depth BIAS on the material,
## not a translation**, and nothing in this game has reported the z-fighting it cures.
## **Kept at 0 with its measurement**, so the next agent does not re-derive it.
## ⚠ **The OUTLINE is still pushed along that axis and that is right** — it is meant to sit behind, and
## it stands on nothing.
const BODY_DEPTH_PUSH_TILES := 0.0

## **기법 26 · 색으로 배경에서 떼기.** A gain on the body's own colour so it sits above the ground
## rather than in it. ⚠⚠ **THIS MULTIPLIES ON TOP OF THE FACTION TINT**, which is the one thing telling
## the player whose body it is — push it far and both sides go white, which is exactly how 16 failed.
const BODY_SEPARATE_GAIN := 1.10

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
## ⚠⚠ **PICKED BY EYE IN THE GAME, 2026-08-29** (the user, flipping six tones live: 「다 별론디
## 3번으로 해줘」 — none of them loved, and this is the one). **+0.12 is the FAINTEST of the light
## three**; the dark three were rejected outright. ⚠ **Signed since the same day**: negative would pull
## the 판 toward black instead, and the shader draws either.
const PAD_ALL_LIGHTEN := 0.12           # how far the revealed 판 is pulled toward white
const PAD_HOVER_LIGHTEN := 0.55         # > PAD_ALL_LIGHTEN, same reason as the alphas
const PAD_HOVER_LIFT := 0.06            # world units. **3x the 판's own 0.02 thickness**

## ⚠⚠ **THE TWO ZOOMS THAT DECIDED WHETHER A 판 WAS A 조각 OR A 칸 ARE DELETED** (2026-09-01).
## `PAD_MERGE_ZOOM` 0.72 and `PAD_APART_ZOOM` 1.45 were the two ends of a ramp: below the first a 칸
## was one lump, above the second its four 조각 stood apart, and `field_view.pad_merge()` — their only
## reader, deleted with them — worked the blend out from the camera's own zoom. They came from
## 2026-08-29 (the user: "far out I want it by the 칸, depending on the zoom", then "number 1 is the
## good one, no?" picking the mechanism that MOVES the vertices), and were judged in
## `.prototypes/merge/` rather than in the game.
##
## ⚠⚠ **THE MARK IS ONE PER 칸 AT EVERY ZOOM NOW, because the ORDER is** (2026-09-01, the user: "let
## us do it by the 블록"). A ramp would put 280 조각 marks under a cursor that commands one of 70 칸 —
## **the mark and the press counting different things is exactly what the 2026-08-29 reversal was made
## to end**, and leaving these two in would have been that failure read backwards.
## ⚠ **The six `PAD_*` values above were every one judged against a 조각-sized quad** and now cover four
## times the area at the same alpha, and `PAD_HOVER_LIFT` lifts a 2x2 lump. **Nobody has looked at the
## merged board yet.** They are the first thing to move once somebody has.

## **What a 판 the picked body may stand on is worth** (2026-08-31, the user: 「캐릭터를 누르면 이동할
## 수 있는 칸들이 뜨고 눌러서 이동하는거임」).
##
## ⚠⚠ **BETWEEN THE RESTING BOARD AND THE HOVER, AND THAT ORDERING IS THE WHOLE POINT.** Three states
## are on screen at once — the board TAB reveals, the reach the pick lights, and the one 조각 under the
## cursor — and if any two of them are worth the same the player cannot tell which is which.
## ⇒ `PAD_ALL_* < PAD_REACH_* < PAD_HOVER_*` on both channels, and a net asserts exactly that.
const PAD_REACH_ALPHA := 0.55
const PAD_REACH_LIGHTEN := 0.30

## **The two values the reach MASK is written with** — not a colour anybody looks at, but the mask is
## an `Image` and every literal colour in this project lives here. ⚠ **Red is the only channel the
## shader reads** (`FORMAT_R8`); the rest is there because `Image.set_pixel` takes a `Color`.
const COL_REACH_OFF := Color(0.0, 0.0, 0.0, 1.0)
const COL_REACH_ON := Color(1.0, 1.0, 1.0, 1.0)

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
##
## ⚠⚠ **0.45 -> 0.80** (2026-08-30, the user at the screen: 「늑대들이 잘 안 보이고, 조각당 하나보다는
## 더 크게」). **The 2026-08-28 shrink above is not deleted — it is the ceiling this value was raised
## INTO**, and the two judgements pull opposite ways because **one constant sizes both species**:
##
## | at this scale | 검사 drawn | 늑대 drawn |
## |---|---|---|
## | 1.00, the value the user rejected | 34.3 x 41.6 px | 30.8 x 16.6 px |
## | **0.80, here** | **27.4 x 33.3 px** | **24.6 x 13.3 px** |
## | 0.45, what was on screen | 15.4 x 18.7 px | 13.9 x 7.5 px |
##
## ⚠⚠ **THE 늑대 COLUMN ABOVE IS THE SIDE-VIEW WOLF AND THAT PICTURE IS GONE** (2026-08-30). It is
## kept because it is what the 0.45 -> 0.80 judgement was made against; **what stands there now is H
## at its own 1.70, drawn 41.9 x 41.9 of frame around 30.1 x 19.6 of animal.**
##
## ⚠⚠ **THE WOLF'S HEIGHT IS NOT WHAT THIS CONSTANT IS FIGHTING, AND THE PER-SPECIES COLUMN IT ASKED
## FOR NOW EXISTS** (2026-08-30) — the third column of `BEAST_TEX`. A body is sized by WIDTH off
## `BEAST_SPRITE_W_RATIO`, so a wide flat animal stands short beside a narrow tall man at any shared
## scale, and **raising this raised that gap along with everything else.** ⇒ **This number is what
## every body shares and the column is where one species departs from it**; the two multiply, and
## neither is the other's copy.
## ⚠ **The ceiling is the swordsman and it is measured, not guessed**: past about 0.96 he is a whole
## 조각 tall again, which is the picture 「집이랑 캐릭터 확 줄여줘」 rejected. **He is the reason this
## value did NOT move again on 2026-08-30** — the user's own words were 「I'd like the character to be
## about right」, and what moved instead was the wolf's own column.
const BODY_SPRITE_SCALE := 0.80
## ⚠⚠ **How big a building is drawn.** Same round, same reason: the one house on the island stood taller
## than the two-storey rock behind it. **Nothing reads a building's size but the eye** — no rule, no
## check, no footprint — so unlike the body above this one costs nothing and hides nothing.
## ⚠ **0.45 -> 0.34 on 2026-08-31**, the user, on the planted island: 「집도 지금 너무 크고」.
## The wood and the grown rocks went in the same session and the building stopped being the biggest
## thing on open ground — **a size that was right beside an empty island is not right beside a wood.**
const BUILD_SCALE := 0.34

## **How far off its 조각's centre a body stands when it is not alone there, as a fraction of a 조각.**
##
## ⚠⚠ **A 조각 ADMITS `Rules.TILE_CAPACITY` BODIES SINCE 2026-08-30 AND THEY WOULD OTHERWISE DRAW AS
## ONE.** The sim walks every one of them to the same 조각 centre, so without this the second and third
## body in a 조각 are hidden exactly behind the first — the count changes and the screen does not, which
## is this repo's own named fake.
##
## ⚠ **It is DRAWING and the sim knows nothing about it.** Reach, the flow field and every distance
## are still measured from the 조각 centre; what moves is the picture and the disc under it.
## ⚠ **Under 0.5 or a body is drawn outside its own 조각** and reads as standing on its neighbour.
## 0.30 leaves a clear gap at `Rules.TILE_CAPACITY` = 3 and still keeps every body inside its square.
const CROWD_SPREAD_RATIO := 0.30


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

## **How far past the island the camera may travel, on every side, in tiles.**
##
## ⚠⚠ **BEFORE THIS THE CAMERA COULD NOT LEAVE THE ISLAND AT ALL.** `_clamp_cam` centred any axis whose
## board was narrower than the visible ground, and every island is, so **panning did nothing** — a drag
## snapped straight back to the middle and `net_shell` had a row saying so.
##
## ⚠⚠ **IT IS THERE BECAUSE NOTHING TELLS THE PLAYER A BOAT IS COMING** (2026-08-30, the user: 「안
## 알아채는 게 맞겠다 ... 마우스 돌리다가 보이면 그때 가는 걸로」). There is no arrow and no alarm;
## **looking out to sea IS the mechanism**, and a camera pinned to the island has no way to do it.
## ⚠ **20 is bigger than `Rules.BOAT_START_DIST_TILES` is not required and is not the argument** — a
## hull is meant to be findable, not framed. What it does have to be is far enough that a player who
## pans has somewhere to pan TO.
const CAM_ROAM_TILES := 20.0

## **How far the mouse must travel with the button down before a press becomes a pan, in screen px.**
##
## ⚠⚠ **WITHOUT IT A DRAG OVER THE ISLAND MOVED THE CAMERA NOWHERE — most of the opening screen**
## (2026-08-30, measured with a negative control: the same ten-step drag moved the camera **0.0 px**
## starting on land and **315.0 px** starting on water, and the two land frames were pixel-identical).
## The press was eaten by the walk order, so `_panning` never turned on and it read as a broken mouse.
##
## ⚠ **It takes nothing away.** A press that releases without travelling is still a walk order; only a
## press that MOVES becomes a look-around. ⚠ **Small on purpose**: a threshold big enough to be
## comfortable is a threshold that swallows short drags, and a hand that moves 6 px was never clicking.
const DRAG_PAN_THRESHOLD_PX := 6.0

## ⚠⚠ **FOUR CAMERA-TRAVEL CONSTANTS STOOD HERE, ALL FOUR WERE DELETED, AND ALL FOUR ARE BACK**
## (2026-09-02). **The deletion is kept rather than erased, because this repo records a flip and does
## not rub the old line out:**
##
##  - 2026-08-30, the user: 「wasd 보다는 마우스가 끝으로 가면 자동으로 이동이 맞을듯」 — the band is born;
##  - 2026-08-31, the user: 「그것도 지워줘」 — the band goes;
##  - 2026-08-31, the user: 「wasd 도 지워줘」 — the keys follow it the same day;
##  - 2026-09-02 — **both come back in one reversal.** The left drag is being taken away by the
##    selection box, so there is no hand left to push the board with, and RimWorld — which the user
##    asked about — travels on the keyboard and the screen edge.
##
## ⚠ **None of the four has been judged on a screen yet, and that has not changed.** They come back at
## the numbers they were deleted at: **first values, not settled ones.**
## ⚠⚠ **The line that used to close this block — 「nothing in `src/` moves the camera on a clock any
## more」 — is false again.** `Game._process` sums the keys' velocity and the band's into ONE `pan_by`
## every frame, and that summed spend is gated on the run being alive.

## How fast a held pan key moves the view, in SCREEN px per second.
## ⚠ **Screen px and not 조각**, so it goes through the same `pan_by` a mouse drag does — one path to
## the camera, and a key and a drag cannot end up disagreeing about which way is right.
##
## ⚠⚠ **IT IS READ OUTSIDE `src/` TOO, AND THAT IS WHY IT COMES BACK UNDER ITS OLD NAME.** While it was
## deleted, `tools/look/capture_boat.gd` carried its own copy of the 900 so its pictures could keep
## being taken; that tool reads this constant again, so **the repo holds one 900.**
const CAM_PAN_KEY_PX_PER_SEC := 900.0

## **How deep the edge band reaches in from each side of the window, in screen px.** The pointer
## inside it pans the camera for as long as it stays there.
##
## ⚠⚠ **THE EDGE IS THE PRIMARY WAY THE CAMERA TRAVELS** (2026-08-30, the user: 「wasd 보다는 마우스가
## 끝으로 가면 자동으로 이동이 맞을듯」). WASD stands beside it rather than under it — both were deleted
## on the same day and both come back on the same day.
##
## ⚠ **NOT MEASURED ON A SCREEN. Nobody has looked at this number yet.** Both ends bite: too wide and
## the band covers ground a body is ordered onto, too narrow and the pointer has to be parked on the
## last few pixels of glass, which is the version of this control every review complains about.
## ⚠ **28 px against a 1280 x 720 window leaves a 1224 x 664 inert rectangle** — 88% of the glass, not
## the 96% one side's arithmetic gives.
const CAM_EDGE_PAN_BAND_PX := 28.0

## **How fast the edge pans at full depth, in SCREEN px per second** — the same units and the same
## `pan_by` the keys and the drag already go through, so no third idea of which way is right can grow.
##
## ⚠⚠ **DELIBERATELY THE KEYS' OWN SPEED, AND THE LINK IS ONE EDIT TO BREAK.** Two independent
## literals for 「how fast does the camera travel」 drift apart the first time either one is tuned, and
## the edge has not been judged on a screen yet. **When somebody looks at it, this becomes its own
## number** — the name is already here so nothing else has to move that day.
const CAM_EDGE_PAN_PX_PER_SEC := CAM_PAN_KEY_PX_PER_SEC

## **How fast the edge pans at the band's INNER lip, as a fraction of the top speed.** It ramps
## linearly from here at the lip to the full speed at the window's own edge. ⚠ **1.0 is a flat band
## with no ramp at all** — that is what this constant answers 「does it ramp」 with, rather than a
## second flag that could disagree with it.
##
## ⚠ **Without a ramp the whole band is a switch**: brushing the lip is already top speed, so the
## band's width buys nothing and the camera jumps the moment the pointer drifts.
const CAM_EDGE_PAN_LIP_FACTOR := 0.30

## How far ONE NOTCH turns the board. **The board turning is the hand moving during a fight**, and
## that is 티켓 07's whole question — this is the knob that lets it be answered by trying it.
##
## ⚠⚠ **NO KEY READS THIS ANY MORE** (2026-08-31): Q and E were the notch and they were deleted, and
## the right-button drag turned by `CAM_YAW_PER_PX_DEG` instead. ⚠⚠ **THAT LINE SURVIVES THE KEYS
## COMING BACK** (2026-09-02): Q and E turn a QUARTER now and read `CAM_YAW_SNAP_DEG`, so this 15 is
## still read by nothing the player touches.
## ⚠ **Its reader list said 「the shot tool」 and it was one short.** What reads it is **four call sites
## in three files outside `src/`** — the field shooter, the piece viewer's two notch keys, and the
## palette prototype's shooter. Each turns the camera itself to put the island at the angle a picture
## was last judged from, so the number stays a number rather than becoming a literal inside a tool.
const CAM_YAW_STEP_DEG := 15.0

## **How far ONE PRESS of Q or E turns the board.** ⚠⚠ **The board stands at one of FOUR yaws and that
## is a CONSEQUENCE of this number, not a second rule** (2026-09-02, the user having named Don't
## Starve for the feel). ±90 is exact in float, and with the right-button drag deleted nothing else
## writes the yaw — so {0, 90, 180, 270} is where the board can be and nothing drifts.
## ⚠ **`CAM_YAW_STEP_DEG` above is NOT this number.** They are two notches for two different hands:
## 15 is what an instrument turns the camera by, 90 is what the player's key asks for.
const CAM_YAW_SNAP_DEG := 90.0

## **How long a quarter turn takes, in seconds** (2026-09-02, the user choosing between an instant
## snap and a visible sweep: 「즉시 돌 거 같아. 도는 것이 보여」 — *"it starts turning right away, and
## the turning is visible."*).
##
## ⚠⚠ **A FIRST VALUE AND NOT A MEASURED ONE.** 0.22 s is fast enough to read as a snap and slow
## enough to be seen; **the user's eye is what settles it**, and the flip back to instant is this one
## constant going to 0.0.
## ⚠ **It is a DURATION and not a rate**, so the rate follows from it and the notch — 90° in 0.22 s is
## 409°/s — and a notch that changed size would keep taking the same time.
const CAM_YAW_SWEEP_SEC := 0.22

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
##
## ⚠⚠ **THE DRAG IT WAS MEASURED FOR IS DELETED** (2026-09-02, the user: 「오른쪽 마우스로 회전을 하면
## 뭔가 장점이 별로 없어서」 — *"rotating with the right mouse does not really have any advantage"*).
## **The constant is left standing rather than deleted with its shell reader**, because
## `tools/look/piece_viewer.gd` drags a piece around by it and that reader is live. Deleting it breaks
## the piece viewer — the same reason `CAM_YAW_STEP_DEG` above stands for four readers it does not
## share a hand with.
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
##
## ⚠⚠ **MEASURED AND UNRESOLVED: THE BOATS DO NOT FIT IN THIS FRAME** (2026-08-30, 티켓 41). At 1.40 the
## shipped 30 x 26 island opens at 42.0 x 36.75 조각 of visible ground — **about 6 조각 of sea on a
## side** — and a hull born `Rules.BOAT_START_DIST_TILES` out is off screen for **every one of the
## island's coastal 조각**, with roughly half of every crossing happening where nobody can see it.
## ⚠ **It was replaced by an additive ring of 12 조각 for one round and put back.** The framing, the
## boat's speed and its start distance are three halves of one picture, and that picture is being
## prototyped side by side rather than argued about — see `Rules.BOAT_SPEED_TILES`. **An additive ring
## and this multiplier are alternatives, not partners**: two margins compound, and 12 조각 on top of
## 1.40 drove every island onto `ZOOM_MIN`, where a survey cannot be told from a constant.
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


# Bodies. Friend and foe are told apart by COLOUR; the unit type is told apart by SIZE and by how
# round its corners are — see BODY_RADIUS_RATIO and BODY_CORNER_RATIO.
const COL_ALLY := Color(0.451, 0.847, 1.0)
const COL_ENEMY := Color(1.0, 0.420, 0.361)


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

## ⚠ **`SUMMON_RING_W_TILES` went with the boats** (2026-08-29), and `SUMMON_RING_SEGMENTS` before it.
## The width bound is the fact worth keeping: under about 0.2 tiles a ring disappears at `ZOOM_MIN`,
## and over about 0.8 it stops being a line and becomes the band it existed to replace.
# ⚠⚠ ==============================================================================================
# **PARKED 2026-08-28 — EVERYTHING FROM HERE TO `WATER_SHORE_OFFSET_TILES` IS UNREAD.** The sea shader
# was replaced whole when the flat-border spike won (`.prototypes/shoreline/`), and the sea these belong
# to — swell, ripples, drawn crests, travelling foam, the shallows and the shore warp — is not drawn any
# more. **Turning any of them changes nothing on screen.**
#
# ⚠ **They are kept because they are MEASUREMENTS, not because they are live.** Nearly every one was
# chosen by eye from a sheet of candidates and several record a reversal; the comments are the only
# place those results exist. Deleting them throws away what they cost.
# ⚠ **Still live below them**: `WATER_SHORE_OFFSET_TILES`, `WATER_FIELD_SPAN_TILES` and
# `WATER_FIELD_SUBDIV` — the new shader reads the same baked field, so those three did not park.
# ==============================================================================================

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
# `.prototypes/shoreline/` and the user chose the one that does the least: **a flat sea and a border.**
# Everything above this line that is not `COL_WATER` or `COL_WATER_FOAM` belongs to the sea that was
# replaced, and **nothing reads it any more** — see the parking note over that block.
#
# ⚠⚠ **FOUR MOTIONS RUN AT ONCE AND NONE IS IN STEP WITH THE OTHERS** (the user: 「단순하게 원이 아니라
# 이제 복합적으로 움직이는걸 원한 진짜 물처럼」). **A border on one clock is a ring pulsing**, and that is
# what「원 같다」was. Take any one of the four out and it goes back to being a ring.
#
# ⚠⚠ **THE BORDER ITSELF WAS REPLACED ON 2026-08-29 — TWENTY-SEVEN VERSIONS SIDE BY SIDE**
# (`.prototypes/swash/`, each folder carrying a `NOTES.md`) **and the user chose `27-gaps`: two whites,
# thin and hard-edged, slow, and broken.** The flat sea and the one border are untouched; what changed
# is what that border is made of. **Everything from here down is that choice**, and the numbers below
# were each set by eye against the island as it stood on 08-29.
# ==============================================================================================

## **해안선's width, in tiles, at FULL surge.** ⚠ At rest only `WATER_REST_FRAC` of it is on the rock.
const WATER_LINE_TILES := 0.035
## ⚠⚠ **How hard its outer edge is, AND THIS IS THE REAL ANSWER TO 「좀더 얇으면」, not the width above.**
## A soft-edged line spends most of its width on a fade, so it reads thick at any width. **Thinning a
## soft line makes it faint; hardening it makes it thin.** 1 holds full strength to the edge and stops.
const WATER_LINE_HARD := 0.85
const WATER_LINE_ALPHA := 0.90

## **1. The shape of the line, and it TRAVELS along the coast.** `WATER_RUN` is tiles per second and
## `WATER_CYCLE` is how long one lap of the crossfade takes — two copies half a lap apart, so the
## pattern never visibly restarts. ⚠ The amplitudes are in TILES and they add; the scales are inverted
## tiles, so 0.45 is a bend about two tiles across. `WATER_GRAD_STEP` is the stencil the seaward
## direction is measured with.
const WATER_RUN := 0.30
const WATER_CYCLE := 2.6
const WATER_GRAD_STEP := 0.06
const WATER_WARP_A := 0.055
const WATER_WARP_A_SCALE := 0.45
const WATER_WARP_B := 0.030
const WATER_WARP_B_SCALE := 1.30
## ⚠⚠ **The ring-breaker**: the run's phase is read ALONG the coast, so one stretch is coming up while
## the next is draining back. On one clock every point on the island swells at the same instant.
const WATER_ALONG_SCALE := 0.55

## **2. Where the coast bends.** The curvature is measured and a headland is given more energy than a
## cove — which is why the bays stay quiet without a single number saying "bay".
## ⚠⚠ **`WATER_CURVE_STEP` CANNOT SEE A BEND SMALLER THAN ABOUT ITSELF, IN TILES**, so it is the first
## number to re-judge whenever the island's outline starts turning on a different unit. The outline
## went 112 → 280 → 168 segments while these candidates were being judged.
const WATER_CURVE_STEP := 0.30
const WATER_REFRACT := 0.85
const WATER_POINT_GAIN := 2.1
const WATER_BAY_FLOOR := 0.35

## **3. The run.** ⚠ **`WATER_RATE` 0.16 is a run about every six seconds, DOWN FROM 0.42** (the user:
## 「너무 자주 하는데 파형이 좀더 느리게」). `WATER_RISE_FRAC` is how much of the cycle is the water
## coming up; the rest is it draining. `WATER_SWASH` is how far up the rock it reaches, in tiles.
const WATER_RATE := 0.16
const WATER_SWASH := 0.16
const WATER_RISE_FRAC := 0.22
## ⚠⚠ **THE RESTING WIDTH AND THE SURGE ARE SEPARATE, AND THAT SEPARATION IS THE WHOLE POINT**
## (the user: 「얇게 있다가 파형이 왔을떄만 두꺼워야하는데 미리 흔적이 너무 남아있는느낌이야 기본값이
## 너무 있어」). `WATER_REST_FRAC` is the fraction of the width that sits on the rock doing nothing;
## `WATER_SURGE` is what the arriving wave ADDS on top, in multiples of the same width, and it rides
## the run so it is zero for most of the cycle. `WATER_REST_SHAPE` is how much the bay/point energy is
## allowed to thin the RESTING line — at 0 the hairline is the same all round the island.
const WATER_REST_FRAC := 0.45
const WATER_SURGE := 1.6
const WATER_REST_SHAPE := 0.7

## **4. The second white, the one standing off the rock** — how far off in tiles, how wide the stroke
## is, and how strong. ⚠⚠ **It is a LINE, not a band**: every 해안선 drawn before it was a soft wash
## fading outward and the reference frames have a hard stroke. ⚠ Keep `WATER_SECOND_W` at or under the
## resting line or the two whites stop reading as two.
## ⚠ **`WATER_SECOND_AT` is the first number that will look wrong if the blocks change size.**
const WATER_SECOND_AT := 0.22
const WATER_SECOND_W := 0.035
const WATER_SECOND_AMT := 0.85

## **5. The cuts, and there are two of them on the outer white.** `WATER_CUT_SCALE` is how long a
## surviving piece is (inverted tiles — bigger is shorter), then how fast the pattern of gaps drifts and
## where it switches. ⚠ `SHUT` and `OPEN` close together is a clean break; far apart is a fade, and a
## fade is a dimming rather than a gap.
const WATER_CUT_SCALE := 0.55
const WATER_CUT_DRIFT := 0.03
const WATER_CUT_SHUT := 0.40
const WATER_CUT_OPEN := 0.62
## **Where the second line is allowed to exist at all**, in units of the refraction's energy — which
## runs from `WATER_BAY_FLOOR` in a cove to `WATER_POINT_GAIN` off a headland. Raising these walks the
## second white back toward the points and out of the bays.
const WATER_TIP_AT := 0.90
const WATER_TIP_FULL := 1.30
## ⚠⚠ **HOW MUCH THE INNER LINE IS ALLOWED TO THIN WHERE THE OUTER ONE IS MISSING, AND IT IS THE ONE
## NUMBER THAT ARGUES WITH THE GLOSSARY.** `GLOSSARY.md` defined 해안선 as ringing the island **without
## a gap, because water is always touching land**. At 0 that rule holds; at 1 the coast can go bare.
## **0.35 is deliberately partial — the line thins and never disappears.** If it ever reads as a hole
## in the island, the glossary was right and the answer was `25-broken` or `26-tips`.
const WATER_FIRST_CUT := 0.35

## ⚠⚠ **`WATER_ROLL` / `WATER_ROLL_TILES` STOOD HERE FOR ONE ROUND** (2026-08-29). They were 거품 —
## the white line pushed IN toward the rim. **The user asked for it, saw it, and took it back**:
## 「별로다... 그 거품없애봐」. ⇒ **The flat sea with one border stands**, confirmed twice.
## ⚠⚠ **AND ELEVEN DIALS OF THE 08-28 BORDER LEFT WITH `27-gaps`**: the third warp octave and all three
## warp SPEEDS (the line travels now instead of the noise drifting), the four `SWING` dials (the resting
## width and the surge replace them), and the three `PEEL` dials (the second white stands still off the
## rock instead of a line letting go and sailing out). **Their values are in git at `05c2509`** and the
## mechanism itself is kept whole in `.prototypes/swash/01-now/`.

## **6. How much of the coast is quiet**, how wide a quiet stretch is in inverted tiles, and how slowly
## the quiet places move. ⚠ At 0 every part of the shore is equally lively, which is its own kind of ring.
## ⚠ **Down from 0.45**: the cuts now do most of the breaking-up, and two gates at full strength took
## whole stretches of coast down to nothing at once.
const WATER_CALM := 0.25
const WATER_CALM_SCALE := 0.38
const WATER_CALM_SPEED := 0.035

## ⚠⚠ ==============================================================================================
## **먼 바다 — the open water outside the border, and until 2026-08-30 nobody had ever chosen it.**
##
## The flat sea was confirmed three times and each of those was about the RIM. **What the sea is made
## of away from any rock was arrived at by subtraction and never judged**, and the user watching a boat
## cross it said 「물이 좀 너무 없긴하다 뭔가」 — *"there is a bit too little water to it, somehow."*
## **Five mechanisms were built side by side with a hull crossing in frame and the user chose the one
## that puts countable objects on the water** (`.prototypes/sea/06-fleck`), then: 「약하게 넣어주면될듯」
## — *"weakly is probably how to put it in."*
##
## ⚠⚠ **`WATER_FLECK_AMT` IS THE ONE DIAL 「약하게」 MOVED, AND IT IS THE ONE TO MOVE AGAIN.** How many
## there are, how big they are and how bright they are are three separate requests, and the candidate's
## own answer to the first two is what the user looked at. **Everything below except the strength is
## `06-fleck`'s value carried across unchanged** — three dials turned down at once and 「a bit stronger」
## has no single line to change.
##
## ⚠ **The candidate was judged at 0.11.** This ships at 0.09, because the thing the user approved
## already moves about 1% of the frame near the island and 2% out at sea, and 「약하게」 on top of that
## is a step and not a halving. **The screen has not judged 0.09.**
##
## ⚠ **What this mechanism cannot do was known when it was chosen**: it says nothing about the water
## BETWEEN the objects, so about 98% of the sea is still the flat colour it was.

## **The colour of one object on the water.** ⚠ Not `COL_WATER_FOAM` — the border's white is what the
## coast and every hull mark are drawn in, and a fleck reading as bright as a breaking wave was never
## the request.
const COL_WATER_FLECK := Color(0.855, 0.905, 0.930)
## **조각 per lattice cell** — one object's worth of room. At 7.0 about sixteen cells fall in frame.
## ⚠ **This and `WATER_FLECK_R_MAX` fight**: 「more of them」 and 「bigger」 are not the same request.
const WATER_FLECK_CELL := 7.0
## **What fraction of cells carry one**, and it is what keeps the lattice invisible: at 0.55 nearly half
## of them are bare water. ⚠⚠ **At 1.0 it IS a grid**, and that is the failure to watch for.
const WATER_FLECK_FILL := 0.55
## **How big one is, in 조각** — smallest to largest — and where its soft edge starts as a fraction of
## its own radius. ⚠ In 조각 and not in cells, so the size on screen does not move when the count does.
const WATER_FLECK_R_MIN := 0.35
const WATER_FLECK_R_MAX := 1.10
const WATER_FLECK_HARD := 0.25
## **How far toward `COL_WATER_FLECK` the water goes at the middle of one.** See the head of this
## section: **this is the strength, and it is the only dial 「약하게」 touched.**
const WATER_FLECK_AMT := 0.09
## **The whole scatter drifts as one body of water**, in 조각 per second. ⚠ Slow on purpose — these are
## what a crossing hull is measured against, so they have to read as standing still while it passes.
const WATER_FLECK_CURRENT := Vector2(-0.055, -0.030)

# ⚠⚠ ==============================================================================================
# **선체가 물에 닿는 자리 — the trail behind a hull and the mark round it, AND THEY ARE ONE SHAPE.**
#
# **The stern half was chosen by eye out of nine candidates** (2026-08-30, the user: 「상대배는 7번
# 내배는 5번이 좋을듯 한데」 — *"the enemy boats want number 7 and mine number 5, I think"*). **Number
# seven is one fading line down the track**: no V, no crests, nothing to get wrong, and it is the only
# version whose meaning survives being drawn one pixel wide. The other eight went with the lab.
#
# ⚠⚠ **THE ONE LINE IS NOW TWO, ONE OFF EACH SIDE** (2026-08-30, the user watching it run: 「배
# 옆면에서 나오는것처럼 해줄 수 있나?」 — *"can you make it look like it comes off the boat's sides?"*).
# **Every remembered point already carried its own heading, so a point knows where the hull's two sides
# were** and the change is where a stroke is stamped, not what a stroke is. **It is still number seven**
# — the same width, the same fade, no crests and no envelope — and `WAKE_SIDE_CLOSE` is the only dial
# it added. ⚠ **It is NOT number five**: the arms are a Kelvin envelope that opens astern, and these
# two close.
#
# ⚠⚠ **ONE WAKE, AND EVERY BOAT GETS IT** (2026-08-30, the user: 「내배를 다르게 하는건 추후로
# 미루자」 — *"let us put off making my own boat different"*). **Number five — `04b-arms`, the two
# 19.47° Kelvin arms without the transverse crests — was chosen for the PLAYER'S OWN boat and is
# deferred**; the player has no boat until week 10. **Nothing below builds it, and there is no boat
# kind, no wake style and no branch anywhere in this** — a distinction that is not being made gets no
# structure. ⚠ **This is the whole record of that choice.**
#
# **What reviving it costs, measured against what stands rather than guessed**: the history already
# carries everything the V needs — **every remembered point keeps its own heading** — and it is the
# same shader, the same array and the same loop. **What is NOT there is the envelope itself**: an arm
# is the run of the points where the rings a moving hull throws off are tangent, and that is about a
# dozen lines in `water.gdshader` plus the arms' own dials. **A dial change on top of those lines, and
# not a rebuild.** The lab that shot it is in `.prototypes/wake/`.
#
# **The bow half is new and NOBODY HAS LOOKED AT IT.** What the screen found was that the hull reads as
# **a cut-out sticker laid on the sea** — its outline simply ends and flat blue begins, which is why
# lowering the draft did not read. Three marks answer it, and **they are the coast's own three**: a
# dark gap between two whites with the outer one broken, pointed at a hull instead of at rock.
# **`WATER_LINE_HARD`, `COL_WATER_FOAM` and the drifting gate that cuts the outer white are read where
# they stand rather than copied**, so retuning the coast carries this with it.
# ⚠⚠ **EVERY `HULL_` NUMBER BELOW IS A FIRST VALUE, SET BY RATIO AND NOT BY EYE.**
# ==============================================================================================

## **How many hulls the water can mark at once, and how many slots each one's block holds.**
##
## ⚠⚠ **THIS IS THE MECHANISM'S CEILING AND IT IS WRITTEN TWICE** — here, and as a `const int` at the
## top of `water.gdshader`, because a GLSL array's length is a compile-time number and cannot be
## handed in as a uniform. **`net_wake` reads that file's own text and compares the two**, so they go
## red rather than drift.
##
## ⚠⚠ **BOATS PILE UP AND NOTHING EVER REMOVES ONE.** One lands every `Rules.BOAT_INTERVAL_SEC` and
## stays there, so this count is how long an island can run before a hull gets no marks at all: at
## twelve, **the thirteenth landing is drawn with dry water round it** — drawn, not dropped.
const WAKE_HULLS := 12
## ⚠ **Slot 0 is where the hull is NOW and the other seven are where it has been.** Both marks come
## out of one block because they are one shape — see the head of this section.
const WAKE_SLOTS := 8

## **How long a mark on the water lives, in seconds** — the whole length of the trail.
##
## ⚠⚠ **4.0 IS THE NUMBER THAT WAS CHOSEN AND THE LAB SAILED ITS BOAT AT 4.0 조각/s, WHILE THE GAME
## SAILS AT `Rules.BOAT_SPEED_TILES` = 1.2.** The lab copied that speed out of `Rules` by hand and the
## copy went stale. **So the trail the user judged was about 16 조각 long and the same 4.0 seconds
## draw 4.8 조각 here**, against a hull 5.2 조각 long. **The dial is left exactly where it was chosen**
## rather than scaled by whoever noticed: it is a value for the screen to judge again, not one for
## this file to guess at.
const WAKE_LIFE_SEC := 4.0

## **The trail's stroke HALF-width in 조각, and where its soft edge starts** as a fraction of that
## width — 1.0 is a hard edge, 0.0 fades the whole way in.
## ⚠ **`WAKE_HARD` is NOT `WATER_LINE_HARD`.** The coast's 0.85 is a hard stroke standing on rock;
## this is a soft one on open water, and one number for both would thin the trail to a wire.
const WAKE_W_TILES := 0.16
const WAKE_HARD := 0.35

## **What fraction of its starting offset a side still stands off by once it is a whole life old.**
##
## ⚠⚠ **THE ONE DIAL OF THE SIDES, AND THE WIDTH IS NOT IN IT.** Where a side STARTS is the hull's own
## half-beam **at the transom, where the trail leaves it** — the shader's `wake_arm` asks `hull_taper`
## for that — so the trail follows a re-export of the model and there is no width here to drift from
## it. **This says only how fast the two close behind.**
## ⚠⚠ **AT 1.0 THEY NEVER CLOSE AND THE TRAIL READS AS A ROAD**, two rails running off astern. That
## is the failure this number exists to keep away from, and it is why nothing here may reach 1.0.
## ⚠⚠ **0.15 WAS SET AGAINST AN OFFSET THREE TIMES THE ONE IT NOW SCALES AND IT HAS NOT BEEN RE-SET**
## (2026-08-30). It was chosen when a side started at the full half-beam 1.005: the pair opened 2.01
## 조각 and closed to 0.30, about the 0.32 조각 a stroke is wide. **Started at the transom's own
## half-beam 0.336 the pair opens 0.67 조각 and closes to 0.10** — a third of a stroke — so the two
## merge into one line about three fifths of the way down a 4.8 조각 trail. ⚠ **Left where it stands
## on purpose**: it is a value for the screen to judge, and 0.48 is what would hold the old ratio.
const WAKE_SIDE_CLOSE := 0.15

## **How opaque the trail is.** ⚠ **The candidate's `alpha` 0.85 times its `centre_amt` 1.0, as one
## number**: with the arms and the crests off there is a single mark left for the two to multiply
## into, and two dials owning one brightness is two places to look when it is wrong.
const WAKE_ALPHA := 0.85

## The noise that breaks the white up, so the trail is not a clean stroke.
const WAKE_FROTH_SCALE := 2.2
const WAKE_FROTH_AMT := 0.35

## **How far INSIDE the transom the trail is born, in 조각.**
##
## ⚠⚠ **AN INSET AND NOT A POSITION.** The hull's own half-length is `Rules.BOAT_HULL_HALF_TILES` and
## it moves whenever the model is re-exported; a second copy of「how long the boat is」 would be right
## until the next export. See `wake_stern_tiles`.
## ⚠ **The trail is anchored at the transom and not at the hull's middle, and the difference is most
## of the picture**: anchored amidships, the first 2.6 조각 of it lie under an opaque hull and only
## about 2.2 조각 of trail ever reach open water.
const WAKE_STERN_INSET_TILES := 0.15

## **How far a hull has to have moved for the water to call it moving, in 조각.**
##
## ⚠⚠ **AN ARRIVED BOAT STOPS DEAD AND STAYS PUT**, and a trail whose newest point is re-stamped every
## frame is forever nought seconds old: it collapses to **a full-strength blob the width of the stroke,
## welded to the transom, that never goes out.** `FieldView._wake_stamp` freezes the stamp at the last
## moment the hull actually moved.
## ⚠ **Unchanged by the hull leaving after `Rules.BOAT_LINGER_SEC`** (2026-09-01). A row that flipped to
## `GONE` still holds its slot in the water's history — nothing is erased there either — so a stamp that
## kept advancing would weld that blob to a boat the player can no longer see.
##
## ⚠ **A storage band and not a dial.** A `PackedVector4Array` holds 32-bit floats, so a stored
## coordinate differs from the one that was written in about its seventh digit; one frame of real
## motion is `Rules.BOAT_SPEED_TILES` over a sixtieth of a second, which is two hundred times this
## either way. **There is nothing here to tune.**
const WAKE_STILL_TILES := 1.0e-4

## **1. The hull's shadow in the water it displaces — the one mark that says 「in」 rather than 「on」,
## and it does most of the work alone.** How wide it is at the widest part of the beam, in 조각, and
## how much wider it gets toward the bow.
## ⚠ **It thins to nothing at the bow and at the stern** because its width follows the beam's own
## profile; the bow emphasis rides on top of that, so the mark is heaviest forward of amidships.
const HULL_SHADOW_W_TILES := 0.30
const HULL_SHADOW_BOW := 0.35
## How much darker and how much cooler than the open sea that shadow is, and how hard it lands.
## ⚠ **Read through `hull_shadow_colour` and never written out as a `Color`** — a literal here would
## be a second copy of the sea's own hue, and the day `COL_WATER` moves one of the two is wrong.
const HULL_SHADOW_DIM := 0.62
const HULL_SHADOW_COOL := 1.18
const HULL_SHADOW_ALPHA := 0.85

## **2. The thin bright lip standing ON the planking** — how far out from the hull's own outline it
## reaches in 조각, how strong it is, and how much brighter it is at the bow.
##
## ⚠⚠ **`HULL_BREAK_AT_TILES` STOOD HERE AND IT IS DELETED** (2026-08-30, the user on a photographed
## arrival: 「이렇게 띄워져 있는부분 없이 왔으면 좋겠음」 — *"I would like it to come in without this
## floating-off part"*). It held the white 0.10 조각 clear of the shadow's edge, which put its inner
## edge **0.35–0.47 조각 off the planking with plain sea between** — twelve to fifteen pixels at the
## zoom an island opens at, and up to thirty-two at the bow at full zoom. **That gap was the floating
## part.** The shore's own vocabulary is two whites with dark water between them and it was reused
## here on purpose; ⚠⚠ **it is right for rock and wrong for a hull** — the island is large enough that
## the band reads as water and a boat is not.
## ⚠ **0.07 IS THE SAME INK MOVED, NOT A NEW WEIGHT.** It was a half-width about a standoff, so the
## stroke was 0.07 조각 across; as a lip anchored on the outline the whole 0.07 reaches outward.
## ⚠⚠ **It is cut by the coast's own drifting gate**, which is what makes it a hairline that is
## uneven and interrupted rather than a clean ring round the hull. **`WATER_CUT_*` owns where a white
## is missing**, on the rock and here both.
const HULL_BREAK_W_TILES := 0.07
const HULL_BREAK_AMT := 0.85
const HULL_BREAK_BOW := 0.80

## **3. The shallow-looking halo** — how far the sea's colour lifts round the hull in 조각, how much
## it lifts, and how much further it reaches astern than forward.
## ⚠⚠ **The aft reach is what joins this to the trail.** The contact is the bow half of one shape and
## the wake is the stern half; at 0 they become two marks that happen to touch.
const HULL_HALO_TILES := 1.00
const HULL_HALO_AMT := 0.12
const HULL_HALO_AFT := 1.60


## **The colour of the hull's shadow in the water**: the open sea, darker and a little cooler.
##
## ⚠ **A function and not a `Color` literal.** Written out it would be a second copy of the sea's own
## hue and the day `COL_WATER` moves one of the two is wrong. **Cooler means the blue is dimmed less
## than the other two**, which is what makes it read as water in shadow rather than as grey paint.
static func hull_shadow_colour() -> Color:
	return Color(COL_WATER.r * HULL_SHADOW_DIM,
			COL_WATER.g * HULL_SHADOW_DIM,
			minf(1.0, COL_WATER.b * HULL_SHADOW_DIM * HULL_SHADOW_COOL),
			HULL_SHADOW_ALPHA)


## **Seconds between two remembered points of a trail.**
##
## ⚠⚠ **`WAKE_SLOTS - 2` AND NOT `- 1`, AND THE DIFFERENCE IS HOW THE TAIL ENDS.** Slot 0 is where the
## hull is now and the other `WAKE_SLOTS - 1` are remembered points, so they span `WAKE_SLOTS - 2`
## gaps. **The oldest of them has to be at least `WAKE_LIFE_SEC` old**, or the trail runs out of slots
## while it is still visible and stops on a step instead of fading out.
static func wake_every_sec() -> float:
	return WAKE_LIFE_SEC / float(maxi(WAKE_SLOTS - 2, 1))


## **Where a trail is born, in 조각 along the hull's heading.** Negative — it is the transom.
## ⚠ Derived, so `Rules` stays the one owner of how long the boat is. See `WAKE_STERN_INSET_TILES`.
static func wake_stern_tiles() -> float:
	return -(Rules.BOAT_HULL_HALF_TILES - WAKE_STERN_INSET_TILES)

# HUD and panel.
const COL_HUD_TEXT := Color(0.918, 0.937, 0.961)
const COL_BUTTON := Color(0.239, 0.341, 0.459)

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
## ⚠⚠ **THIS WAS FIVE NUMBERS AND IT IS TWO** (2026-08-31), with 곰 0.31 · 까마귀 0.174 · 사자 0.342
## leaving alongside their rows. **The 1.29x ladder they sat on is recorded in the note above and the
## three values are here**, so a beast coming back does not have its size re-guessed by eye.
const BODY_RADIUS_RATIO := [0.245, 0.22]


## **The wolf, seen from four sides.** Screen-right, screen-left, screen-down (coming at the camera),
## screen-up (going away).
##
## ⚠⚠ **THE ANIMAL IN THESE FOUR FILES CHANGED ON 2026-08-31 AND THE FOLDER NAME DID NOT.** It is no
## longer H — it is **g5**, a grey wolf with a pale belly, flat colour and no fur strands, chosen off a
## sheet of seven standing one at a time on the island (the user: 「go with g5 for now」). **`wolf_h/`
## now means「the wolf's four facings」and nothing more**; renaming the folder would rewrite four
## constants, a net and two comments to say the same thing.
## ⚠⚠ **AND THE GENERATOR'S COMPASS WORDS ARE NOT THESE ONES.** g5 was drawn once, in profile, and
## rotated; **the rotation's `south` is this file's `east`, and its `south-west` is this file's
## `south`.** The mapping was made by LOOKING at the eight pictures — taking the names at face value
## puts two rear views on the board.
##
## ⚠⚠ **THE FILE NAMES ARE COMPASS WORDS AND WHAT THEY ARE USED AS IS SCREEN DIRECTIONS.** The board
## turns, so a picker written against world north would spin every wolf the moment the player presses
## the turn key with nothing else on screen moving. **The heading is measured against the camera's own
## two ground axes** — `field_view._facing_index`.
## ⚠⚠ **THE FOUR `*_n.png` NORMAL MAPS ARE DELETED** (2026-08-31). They were H's, nothing ever read
## them (티켓 50), and they would have been four pictures of an animal that is no longer in the game.
## **Bodies are drawn unshaded** and a head-on wolf is a few screen px wide — there is nowhere to put
## a gradient, so they are not re-made for g5 either.
const BEAST_WOLF_H_R := "res://assets/beast/wolf_h/east.png"
const BEAST_WOLF_H_L := "res://assets/beast/wolf_h/west.png"
const BEAST_WOLF_H_D := "res://assets/beast/wolf_h/south.png"
const BEAST_WOLF_H_U := "res://assets/beast/wolf_h/north.png"
## ⚠⚠ **`BEAST_WOLF_R` / `_L` STOOD HERE AND THEY ARE DELETED** (2026-08-30, the user at the screen:
## 「the wolf isn't the H wolf I chose? That's not the wolf I picked」). They were `wolf_r.png` /
## `wolf_l.png`, the 74 x 40 side-view wolf, and they walked the island while H — chosen 2026-08-30 and
## marked resolved — had only ever reached the boat deck.
## ⚠⚠ **THE 46 WALK AND BITE FRAMES WENT WITH THEM AND THEY ARE STILL ON DISK** (`wolf_walk_*`,
## `wolf_bite_*`). They are the OLD animal on a 74 x 40 canvas; H is 92 x 92 with no frames at all, and
## **mixing two canvases is a measured defect** — 티켓 48: 「캔버스가 프레임마다 다르면 몸이 뛰고
## 떠오른다」. ⇒ **The wolf walks unanimated until H is given its own strips**, which is one row of the
## table below and nothing else.
## ⚠⚠ **THE BEAR'S AND THE CROW'S FOUR PICTURES STOOD HERE AND ARE DELETED WITH THEIR ROWS**
## (2026-08-31, the user: *"take out the bear, crow and lion code — there is only the wolf"*).
## **`bear_l/r.png` and `crow_l/r.png` are off disk too**, because a picture no row names is a file
## nobody dares remove later.
## ⚠ **They were the last TWO-picture rows in the table.** Every row left names four, which is why
## `net_fx_view`'s 「a two-picture row never answers with a head-on picture」 lost its subject in the
## same edit — the guarantee stands in `beast_facings`, and **nothing measures it until a species with
## two pictures exists again.**

## ⚠⚠ **THE PLAYER, since 2026-08-26.** ⚠⚠ **AND THE DRAWING WAS REPLACED 2026-08-31.** What stood
## here was `sword_r/_l.png`, a 33 x 40 side-on chibi drawn back when the humans were the enemy; the
## user chose this body from sixteen candidates and it carries **no sword, no clothes and no face** —
## a pale mass, a round bald head and two black dots.
##
## ⚠⚠ **RIGHT AND LEFT ARE TURNED, NOT SIDE-ON** (2026-08-31, the user at the screen: 「지금 너무
## 좌여서」 — what I want is 정면우 and 정면좌). A flat profile shows one eye and reads as a different
## creature from the front view beside it; these two are the **south-east and south-west** rotations,
## so the chest still faces the camera and both eyes stay visible.
## ⚠ **DOWN AND UP ARE STILL THE FLAT FRONT AND BACK.** The user also asked for **뒤우 · 뒤좌**, the
## two turned BACK views, and those cannot be hung on these two slots: `field_view._facing_index`
## picks up/down by **which ground axis is bigger**, and four turned pictures need it to pick by
## **the sign of both axes**. That is a change to the picker the wolf shares, so it is not made here.
##
## ⚠ **ALL FOUR ARE 40 x 60**, which is what keeps the man the same size whichever way he faces —
## `_beast_rect` fixes the drawn WIDTH from the body radius and takes the HEIGHT from this texture's
## aspect ratio, so two facings on two canvases is a body that pulses.
const HUMAN_MAN_R := "res://assets/human/man/right.png"
const HUMAN_MAN_L := "res://assets/human/man/left.png"
const HUMAN_MAN_D := "res://assets/human/man/down.png"
const HUMAN_MAN_U := "res://assets/human/man/up.png"

## ⚠⚠ **`IDLE` WAS NOT A STRIP AND IT IS ONE NOW** (2026-08-31). What stood here said the idle is
## the standing picture every row already wears, that it carries no frame count, and that the frame
## table below starts at `WALK`. **All three stopped being true when the breathing strips arrived** —
## the swordsman and the wolf each declare eight idle frames.
## ⚠ **The fallback those lines were protecting is untouched.** A row that declares 0 idle frames
## still wears its standing picture through `beast_frame_path`, so the bear, the crow and the lion are
## drawn by exactly the same call and changed by nothing.
## ⚠⚠ **`BITE` WAS THE THIRD MEMBER AND IT IS `ATTACK` NOW** (2026-08-31, the user:
## 「물기 때리기 -> 그냥 공격이라는 것으로」). **A 검사 does not bite.** One word for what every
## species does when it swings is what lets `_body_tex` stay free of species names.
## ⚠ **`HURT` and `DEATH` are new with it** — the three the user asked for are 공격 · 피격 · 죽음.
enum Anim { IDLE, WALK, ATTACK, HURT, DEATH }

## The `<anim>` piece of `<beast>_<anim>_<frame>_<facing>.png`, indexed by `Anim`.
## ⚠⚠ **`IDLE`'S PIECE WAS THE EMPTY STRING** — an idle picture had no `<anim>` piece because there
## was only ever one of it. It is `"idle"` now and the files are `<stem>_idle_0.png` upward.
const ANIM_NAME := ["idle", "walk", "attack", "hurt", "death"]

## Frames per strip, in `Anim` order **starting at `IDLE`**. **A 0 is a row with no strip of that kind.**
## ⚠⚠ **THIS TABLE STARTED AT `WALK` AND HAD TWO SLOTS** (2026-08-31). The third slot is what lets
## the idle be a strip, and the `anim - 1` that used to read it is gone with the two-slot shape.
const NO_ANIM_FRAMES := [0, 0, 0, 0, 0]

## **The two rows that have frames, and they are the only two bodies standing on the island.**
## ⚠⚠ **`WOLF_ANIM_FRAMES := [4, 4]` STOOD HERE ONCE AND WAS DELETED** (2026-08-30) with the
## side-view wolf it counted. **This is not that array coming back** — it counts g5, the four-facing
## animal, on its own canvas, and its bite slot is 0 because the 46 bite frames on disk are the dead
## animal's. **The rule the deleted note carried still holds**: WALK loops 0-1-2-3; the three
## one-shots play through once and hand the body back, because frame 0 of the attack is the only
## closed mouth and a looped swing leaves the jaw open all fight.
## ⚠⚠ **EIGHT FOR THE BREATH AND FOUR FOR THE WALK IS A LENGTH, NOT A TASTE.** `BEAST_FRAME_SEC` is
## one rate for every strip, so 0.12 s puts the walk cycle at 0.48 s and the breath at 0.96 s. **A
## four-frame breath run at the walk's rate is a body panting**, which is the opposite of standing still.
## **idle · walk · attack · hurt · death**, and every one of them is drawn for both bodies.
## ⚠⚠ **DEATH IS SIX AND THE OTHER THREE ARE FOUR.** A death plays once and is the last thing a body
## ever does, so it is the one strip a player has time to read: six frames is 0.72 s of falling. **The
## hurt is four and that is already long** — 0.48 s against a 1.0 s attack period is a body flinching
## for half of every exchange, and anything longer buries the walk entirely.
## ⚠⚠ **THE ATTACK WENT 4 → 8 FRAMES** (2026-08-31, 「애니메이션을 좀더 늘려줘」). **0.48 s to
## 0.96 s**, and the eight are a real wind-up-strike-recover rather than four frames of the same
## lunge — the first frames pull back, the middle ones reach, the last settle.
## ⚠⚠ **`Rules.UNITS` MOVED IN THE SAME EDIT AND THE TWO CANNOT BE SEPARATED.** A 0.96 s swing on a
## 1.0 s period is a body that never stops swinging; the periods doubled so the gap did too. **Change
## this number back without changing those and the 텀 disappears.**
const MAN_ANIM_FRAMES := [8, 4, 8, 4, 6]
const WOLF_ANIM_FRAMES := [8, 4, 8, 4, 6]

## **How long a body must have held its position before it stops walking and starts breathing.**
## ⚠ **It is not 0.** `still` is reset to 0 the frame a body moves, so a zero threshold flips the
## picture on a single held frame and the legs stutter between the two strips at low speed. 0.15 s is
## nine frames at 60 fps — longer than any pause a walking body takes, shorter than a stop reads as.
## ⚠⚠ **THIS DOES NOT BRING BACK 「움직이지 않는 몸은 애니메이션하지 않는다」**, which froze a body in melee
## and is written up in `field_view._fx_step`. **A still body swaps strips; it never stops animating.**
# ── 타격감 — the six the user named on 2026-08-31 ─────────────────────────────
## **넉백 · 데미지 넘버 · 히트 스파크 · 히트 플래시 · 히트스톱 · 슬래시 트레일**, and every number below is
## judged against **one thing**: a 늑대 is drawn **20.9 px** across and a 검사 **26.8 px** tall.
## **The reference `2026-08-31-hit-feel-elements` holds what each one is and where the numbers came
## from.** ⚠ **Do not tune these by taste alone** — the page names a shipped value for each.

## **How long both bodies hold their picture at the instant of a blow.** 히트스톱.
## ⚠⚠ **PER BODY AND NOT THE WHOLE ISLAND, AND THAT IS A DEPARTURE FROM THE TECHNIQUE.** A fighting
## game freezes the world because two bodies are the world; **here eight beasts and four 검사 trade
## blows at once**, and a global freeze would stutter without pause. **The two bodies in the exchange
## hold; everything else keeps running.**
## ⚠ **0.07 s is four frames at 60 fps**, against the 0.2 s a fighting game uses. **Shorter on
## purpose**: at this attack period a body is in an exchange most of the time, and a fighting game's
## value would leave the island visibly juddering.
## ⚠ **It freezes the body's own clocks, not the simulation.** The sim runs on — which is honest
## only because a body in contact is standing still; **the day a body is struck while moving, this
## becomes a body that teleports** when the hold ends.
const HITSTOP_SEC := 0.07

## **How long the struck body is washed toward white, and how far.** 히트 플래시.
## ⚠ **0.10 s is the value every engine write-up repeats**, with 0.1-0.3 usable; past that the sprite
## reads as a differently coloured animal rather than as one that was hit.
## ⚠⚠ **HALF OF THIS WAS ALREADY BUILT AND NOBODY HAD WIRED A CLOCK TO IT.** `beast_tint`'s own
## header has said since 2026-08-30 that a body's colour is mixed toward white **so that a hit can pull
## it further** — 「a flat white modulate could not have done that, multiply can only darken」.
const HIT_FLASH_SEC := 0.10
const HIT_FLASH_MIX := 0.85

## **The struck body is thrown away from the striker and eases back.** 넉백.
## ⚠⚠ **THIS IS THE VICTIM AND NOT THE ATTACKER, AND THE DIFFERENCE IS WHY THE LUNGE WAS THROWN
## OUT.** An attacker sliding forward reads as sliding — the user, at the screen: 「이런거 말고」.
## **A body knocked backward reads as a body that was hit**, because nothing it is doing explains it.
## ⚠ **0.30 of the drawn half-width, against the lunge's 0.55** — a knock that travels as far as a
## step is a body walking backwards.
## ⚠⚠ **THE CURVE IS NOT A SINE AND THAT IS THE WHOLE OF HOW IT READS.** It peaks at 18% of the
## window and eases back over the remaining 82%: **out in one frame, back over eight.** A symmetric
## curve spends as long going out as coming back, which is exactly what 「왔다 갔다」 was.
const KNOCK_SEC := 0.14
const KNOCK_RATIO := 0.30
const KNOCK_SNAP := 0.4

## **The four beats of a swing, as fractions of the strip, plus how far the body travels on each.**
##
## ⚠⚠ **THE GENERATOR WILL NOT DRAW AN ATTACK POSE FOR EITHER BODY, AND THAT IS FIVE MEASURED
## ATTEMPTS** (2026-08-31): jaws · rearing · pouncing · an eight-frame wind-up sequence · and img2img
## over the standing sprite itself. **Every one came back as the body standing.** Across the eight
## frames that shipped, the wolf's outline moves **7 px on a 64 px animal** — the mouth opens and
## nothing else. The user, looking at it: 「애니메이션이 너무 공격하기 평범해」.
## ⇒ **The pose is the ENGINE's job now.** The eight drawn frames stay underneath and carry the mouth;
## these four beats carry the body.
##
## ⚠⚠ **THIS IS NOT THE LUNGE THAT WAS THROWN OUT ON THE SAME DAY, AND THE DIFFERENCE IS THE WHOLE
## POINT.** That one was **one symmetric sine, 0.18 s, no wind-up and no hold** — out and back at the
## same speed, which is what 「갑자기 왔다 갔다 하는게 있는데 이런거 말고」 was about. **A motion that
## takes as long to leave as to arrive is a drift, not a blow.** These four beats are the animation
## principle every source names — **anticipation, action, recovery** — and the numbers below are the
## asymmetry that separates them:
##
##  · **wind-up 30% of the strip** — the body eases BACKWARD, away from what it is about to hit
##  · **snap 8%** — forward, five frames, the whole distance
##  · **hold 17%** — at full reach and not moving. ⚠ **`HITSTOP_SEC` lands inside this window**, so the
##    picture and the position freeze together on the frame of contact
##  · **recover, the remaining 45%** — drifting home
##
## ⚠ **The reach is a ratio of the drawn half-width**, like every other body offset here, so it
## survives the art changing.
const SWING_WINDUP := 0.30
const SWING_SNAP := 0.08
const SWING_HOLD := 0.17
const SWING_BACK := 0.18
const SWING_REACH := 0.70

## **How much the body stretches along the blow as it snaps**, and thins across it.
## ⚠⚠ **SQUASH AND STRETCH IS THE ONE ANIMATION PRINCIPLE THIS GAME CAN STILL AFFORD.** The others
## need drawn frames; this one is two numbers on a scale the drawer already computes for the gait.
## ⚠ **0.18 is 4 px on a 21 px wolf** — read at the size a body is actually drawn, which is the bar
## every number in this block is held to.
## ⚠ **It rides on top of `_gait_squash` rather than replacing it**, because a body can be walking
## into a blow and the two are different motions.
const SWING_STRETCH := 0.18

## **The shards thrown out of the contact point.** 히트 스파크, and **this is the 파티클 of the six.**
## ⚠⚠ **THEY LEAVE ALONG THE TANGENT OF THE TWO BODIES, AND THAT WAS MEASURED BEFORE** — effect 2
## of the twelve deleted in 2026-08-29 carried the same rule and the same reason: **a fan opened along
## the facing direction lands every shard back inside the striker's own outline**, because the contact
## point sits deep inside the attacker.
## ⚠ **Five and not ten.** At 20.9 px the animal is smaller than ten shards would be.
## ⚠ **The tooth is drawn 9 px wide** — under half the wolf, so a spray of five still reads as
## debris and not as a second animal.
const SPARK_COUNT := 5
const SPARK_SEC := 0.26
const SPARK_SPEED_PX := 46.0
const SPARK_FAN_DEG := 62.0
## ⚠ **6.0 was photographed and it read as noise** (2026-08-31). At 9 px a shard is 43% of the wolf
## it came out of — still debris, but debris the eye catches at the size a body is actually drawn.
const SPARK_PX := 9.0

## **The arc drawn across the front of a body as it swings.** 슬래시 트레일.
## ⚠⚠ **THE 검사 HOLDS NO WEAPON, SO THIS IS THE ARC OF A PUNCH AND NOT OF A BLADE** (2026-08-31).
## The body the user chose from sixteen candidates carries **no sword, no clothes and no face** — an
## arc traced by a blade would be an arc traced by nothing. **It is placed on the line between the two
## bodies instead of on a hand**, which is true for a fist, a jaw and a sword alike.
## ⚠ **0.16 s is shorter than the swing** (0.48 s): the arc is the first sixth of the strip and gone,
## because a trail that outlives the motion is a shape hanging in the air.
const SLASH_SEC := 0.16
const SLASH_PX := 26.0
const SLASH_REACH := 0.55

## **The number that floats off a struck body.** 데미지 넘버.
## ⚠⚠ **THIS ONE PULLS AGAINST THE GAME AND IT WENT IN ANYWAY, ON THE USER'S WORD** (2026-08-31,
## 「넣어줘」). **The health bar was deleted 2026-08-28** (「체력바 없이」) and **Bad North, this
## repo's stated bar, shows no numbers in combat at all.** Written down so the day it is pulled back
## out, the reason it was in is on the page rather than in a memory.
## ⚠ **16 px is the font's own glyph size**, so a numeral is drawn one texture pixel to one world
## pixel and never resampled. **13 was tried on paper and dropped**: a pixel font at a size it was not
## drawn at is the one thing that makes a made font look typed.
## ⚠ **Rounded to a whole number.** The table's damage is 2.5 and 3.0; 「2.5」 over a 27 px body is
## three glyphs where one will do.
## ⚠ **It rises and fades, and it does NOT scale up.** The convention every write-up gives is a pop
## on arrival for CRITS — this game has none, so a pop here would say something that is not true.
const DAMAGE_SEC := 0.62
const DAMAGE_RISE_PX := 22.0
const DAMAGE_FONT_PX := 16.0

## **How high above the ground a mark floats**, so a shard is not buried in the grass it came from.
const MARK_LIFT_PX := 14.0

## **The two drawn things the six need**, and both were made in a tool rather than typed — `CLAUDE.md`.
const FX_TOOTH := "res://assets/fx/tooth.png"
const FX_SLASH := "res://assets/fx/slash.png"
## **The pixel font the damage number is set in.** ⚠ **`NotoSansKR-Regular.otf` is NOT this** — it is a
## smooth outline face for prose, and a smooth 13 px numeral over pixel-art bodies is the one thing
## that would say the number was typed rather than drawn.
const FX_DIGIT_FONT := "res://assets/font/tockbon-digits.ttf"

## **The colour a damage number is set in**, and the only place it is written — `net_draw_leaf`
## reddens on a `Color(` anywhere else in the tree.
## **How thick the number's outline is.** ⚠ 2 px, because the font is drawn at 16 and a 1 px edge
## disappears against the island's own yellow at this zoom.
const DAMAGE_OUTLINE_PX := 2

const COL_DAMAGE := Color(0.98, 0.96, 0.90)
const COL_DAMAGE_EDGE := Color(0.11, 0.09, 0.08)

const BODY_STILL_SEC := 0.15

## **How wide the disc under a body is, as a multiple of the ANIMAL'S OWN INK.** 1.0 is a disc exactly
## as wide as the animal standing on it.
##
## ⚠⚠ **IT WAS THE DRAWN CANVAS'S HALF-WIDTH AND THAT WAS A TRAP** (2026-08-31). `_put_body` sized
## the disc off `wide`, which is the whole picture including its empty margin — so **every time a strip
## forced the canvas wider, the shadow grew and the animal did not.** The wolf's canvas went 64 x 64 to
## 92 x 66 once the five strips were in — a corpse lies flat and a snapping jaw reaches — so a disc
## sized off the frame would have ended up 44% wider than the animal standing on it.
## ⚠ **The man's disc is 12% smaller than it was**, because his standing picture has 35 px of ink on a
## 40 px canvas and the old number was measuring that margin. **The wolf's does not move at all** — its
## ink filled its canvas edge to edge.
const BODY_SHADOW_OF_INK := 1.0

## How long one frame of any strip is held. **One rate for the whole animal**: 0.12 s puts the walk
## cycle at 0.48 s (8 fps, four frames), which at a 49 px body is a stride you can count — the same
## strip at 60 fps reads as a twitch, and 「연출은 과할 정도로」 cuts that way too. The attack is the same
## four frames, so it also runs 0.48 s against a ~1.0 s attack period: the body is swinging for about
## half the time it spends in contact, which is the half 「붙어서 가만히 있으면 재미가 죽는다」 is
## about. **The lunge (`BODY_LUNGE_SEC`) is deliberately shorter** — the body snaps out and back inside the
## first frames while the swing carries the rest.
## ⚠⚠ **ONE RATE MEANS THE DEATH IS 0.72 s AND THE HURT 0.48 s**, both from their own frame counts.
## A per-strip rate is the second table that has to be kept in step with the first.
const BEAST_FRAME_SEC := 0.12

## ⚠⚠ **ONE ROW PER `Rules.UNITS` ROW, AND IT IS THE WHOLE OF HOW A SPECIES IS DRAWN:** the pictures
## it wears, the strips it animates with, and how big it is drawn against everything else.
## This replaces `field_view._beast_tex`'s `if` chain, and with it the `is_enemy` argument that chain
## needed. **That argument existed only because two species shared one row** — 소 and 까마귀 were the
## enemy's rows while the player's two slots borrowed their bodies, so one row had to answer with two
## different pictures depending on who was asking. Split the rows and there is nothing for it to point
## at: **one row, one picture**, and the argument going away is the structural proof the move landed.
##
## ⚠⚠ **THE FIRST COLUMN IS A LIST AND ITS LENGTH SAYS HOW MANY WAYS THE SPECIES CAN FACE**
## (2026-08-30, 티켓 25's substance). It was two slots, right and left, and **two slots cannot hold the
## four the H wolf came with.** The order is `FACE_RIGHT · FACE_LEFT · FACE_DOWN · FACE_UP`, and the
## first two mean the same thing at both lengths on purpose: a row that gains its up and down pictures
## later does not have its existing two move.
## ⚠ **An EMPTY list is a row with NO picture**, and `field_view` draws the plain rounded shape for
## it. The lion is the only one: the last boss is still a beast in a game whose enemies became human,
## and **where it goes is an open question** (티켓 17) — handing it the caveman's picture here would
## answer that by accident, in a place nobody would look for it.
##
## ⚠⚠ **The second column is the row's OWN animation, and it is the only place one is declared.** A
## species animates by editing its own row; every consumer asks the row and falls back on the standing
## picture when the row says nothing, so **there is no species named anywhere in `field_view`**. A
## second list — "these ones have frames" — is the shape that has to be hand-synced with this one, and
## the day they disagree the wrong animal walks. ⚠ **Every row says 0 today** — see `NO_ANIM_FRAMES`.
##
## ⚠⚠ **THE THIRD COLUMN IS HOW BIG THIS SPECIES IS DRAWN, AND IT IS ON THE PICTURE'S OWN ROW BECAUSE
## IT WAS CHOSEN FOR THAT PICTURE** (2026-08-30, the user at the screen: 「the wolf ... is so small I
## can't spot it」 against 「I'd like the character to be about right」 for the swordsman). One shared
## `BODY_SPRITE_SCALE` had to answer both and could not: **a body is drawn to a WIDTH**, so a 74 x 40
## wolf stood short beside a 33 x 40 man, and past about 0.96 the man was a whole 조각 tall again —
## which is the picture 2026-08-28's 「집이랑 캐릭터 확 줄여줘」 rejected. **Raising the shared number
## could only reach the wolf by breaking the man.**
## ⚠⚠ **IT MULTIPLIED THE FRAME UNTIL 2026-08-31 AND IT MULTIPLIES THE ANIMAL NOW.** While it was
## the frame, **a picture with a wide empty margin drew a small animal** — g5's ink fills 72% of its
## canvas side-on and 24% head-on, so the same number meant two different animals depending on which
## way it faced, and every canvas change had to be paid back here by hand. **`_put_body` divides by
## the row's own measured ink fraction**, so this column is now the animal's drawn width and nothing
## about the frame around it reaches the screen.
## ⚠ **That is why both numbers went DOWN when the strips went in**: 0.78 to 0.569 and 0.956 to 0.85,
## with **neither body changing size on screen.** The canvas is divided out instead of multiplied in.
## ⚠ **`rules.gd` refuses this column and says so in its own header** — body size changes nothing about
## what happens, so it lives here. It sits beside the picture rather than in a fourth parallel array
## for the same reason `BODY_RADIUS_RATIO` is not in `UNITS`: **replace the picture and this number
## must be re-judged**, and adjacency is what makes that impossible to miss.
## ⚠⚠ **FIVE ROWS SINCE THE SIDES SWAPPED** (2026-08-26): the swordsman the player is, and the four
## beasts he fights.
## ⚠⚠ **"The player's second weapon is a row here, not a drawing" STOOD ON THIS LINE AND IT IS NOW
## FALSE** (2026-08-27). It was true while the spear, bow and shield each had a right file AND a left
## file sitting unused on disk: a sixth row could have been written with two existing paths and a body
## would have walked. **The three `_L` files were deleted** — the user settled 2026-08-27 that a second
## player weapon is not being built — and a row needs BOTH columns, so those three constants can only
## be card art now. ⇒ **A second player body costs a new DRAWING, not a new row**, and the estimate
## anyone makes off this table has to include that.
## ⚠⚠ **THE SWORDSMAN'S OWN COLUMN IS 0.65 AND IT WAS CHOSEN AT THE SCREEN** (2026-08-31). Four
## sizes were stood on the island in the same frame — **41 · 33 · 27 · 23 px** — and the user picked
## **27**: 「27이 맞는 듯」. ⚠ **23 was also called fine** 「23도 괜찮네」 and is the value to try
## first if 27 turns out big; the user asked for both to be written down, not only the winner.
## ⚠⚠ **41 px IS WHAT THE NEW PICTURE GAVE FOR FREE, AND NOBODY CHOSE IT.** The old drawing was
## 33 x 40 and the new one is 40 x 60, so the same width ratio bought 24% more height — the body grew
## because the CANVAS grew. **This column is where that is paid back**, and it is the swordsman's
## alone: `BODY_SPRITE_SCALE` sizes every body at once and the wolf was judged at its own value.
const BEAST_TEX := [
	# ⚠⚠ **0.569 IS THE INK AND NOT THE CANVAS, AND THE MAN ON SCREEN HAS NOT MOVED** (2026-08-31).
	# This column was a multiple of the drawn PICTURE, so every strip that forced a wider canvas had to
	# be paid back here by hand — it went 0.65 to 0.78 for the breath alone, and the attack, the hurt and
	# the death would each have moved it again. **`_put_body` divides by the row's own measured ink
	# fraction now**, so the canvas may grow forever and this number never changes.
	# ⚠ **0.65 x 35/40 = 0.569 is the arithmetic**, and 0.65 on a 40 px canvas with 35 px of ink is
	# exactly what the user judged at 27 px: 「27이 맞는 듯」. **23 was also called fine** 「23도
	# 괜찮네」 and is 0.485 under this column's new meaning.
	[[HUMAN_MAN_R, HUMAN_MAN_L, HUMAN_MAN_D, HUMAN_MAN_U], MAN_ANIM_FRAMES, 0.569],
	# ⚠⚠ **0.85, CUT FROM 2.60 — THE WOLF IS SMALLER THAN THE MAN NOW** (2026-08-31 night, the user
	# looking at the two of them side by side for the first time: 「the wolf got too big. Shrink it —
	# it has to be smaller than the human」). **The base frame is 24.6 px**, so this number IS the frame
	# in 조각: 2.60 gave a 64.0 px frame and 0.85 gives 20.9. ⚠ **The comparison is INK, not frame** —
	# the wolf's ink fills its whole 64 x 64 canvas while the man's fills 40 of his 40 x 60, so at 0.85
	# the wolf's ink is **20.9 px against the man's 26.8**: 0.78 of his height and 1.42 of his width, an
	# animal that comes up to his waist and is longer than he is wide.
	#
	# ⚠⚠ **THIS REVERSES THE SAME DAY'S 2.60 AND THE REASON IT WAS RAISED IS NOW DEAD.** 2.60 was not a
	# taste either: **64 px on screen made one texture pixel exactly one screen pixel** at the opening
	# zoom, which is what stopped the art breaking up. **At 0.85 that is gone** — 64 texture px are
	# resampled down into 20.9, so the wolves are a 3.1x downscale. ⇒ **If they read mushy, the fix is
	# re-pulling the art at a ~24 px canvas, NOT raising this back**; the user has now judged the size
	# with a man beside it, which 2.60 never was.
	#
	# ⚠ **Four other sizes were stood on the island in the same frame** and are one edit away:
	# **1.00** (0.92 of his height) · **0.70** (0.64) · **0.55** (0.51, the first that is also narrower
	# than he is). **0.85 is what this file ships**; the rest are written down because the user asked to
	# see them and may want one instead.
	# ⚠⚠ **0.85 IS BACK, AND IT IS THE NUMBER THE USER CHOSE** (2026-08-31, 「the wolf got too big.
	# Shrink it — it has to be smaller than the human」). It was raised to 0.956 for one afternoon to pay
	# back a canvas that went 64 to 72 for the walk, and it is 92 x 66 now that the fight strips are in; **that debt is gone** — this column is a multiple of
	# the ANIMAL'S INK now and the canvas is divided out in `_put_body`. **g5's ink filled its 64 px
	# canvas edge to edge when the user judged it, so 0.85 x 64/64 is 0.85.**
	# ⚠ **The base frame is 24.6 px**, so this number is the animal's ink in 조각: 0.85 gives 20.9 px
	# against the man's 26.8 — 0.78 of his height and 1.42 of his width, an animal that comes up to his
	# waist and is longer than he is wide.
	# ⚠ **Four other sizes were stood on the island in the same frame** and are one edit away:
	# **1.00** (0.92 of his height) · **0.70** (0.64) · **0.55** (0.51, the first that is also narrower
	# than he is). **0.85 is what this file ships**; the rest are written down because the user asked to
	# see them and may want one instead.
	[[BEAST_WOLF_H_R, BEAST_WOLF_H_L, BEAST_WOLF_H_D, BEAST_WOLF_H_U], WOLF_ANIM_FRAMES, 0.85],
	# ⚠⚠ **THREE ROWS STOOD HERE — 곰, 까마귀 AND THE LION'S EMPTY ONE — AND ALL THREE ARE DELETED**
	# (2026-08-31). **The lion's was `[[], NO_ANIM_FRAMES, 1.0]`**, the one row with no picture at all,
	# and `field_view` drew the plain rounded shape for it. ⚠ **That fallback is now unreachable and it
	# is kept anyway**: it is what a row with a missing file lands on, and the day the boss is drawn it
	# is what stands there while the art is being chosen.
]

const _TEX_COL_PICS := 0
const _TEX_COL_FRAMES := 1
const _TEX_COL_DRAW := 2

## **Which way a body is facing, as an index into its own row's picture list.**
##
## ⚠⚠ **THESE ARE SCREEN DIRECTIONS AND NOT COMPASS ONES.** The board turns; the resolution lives in
## `field_view._facing_index`, which is the only place that holds the camera's two ground axes.
## ⚠ **RIGHT and LEFT come first so a two-picture row and a four-picture row agree on them** — the day
## a species gains its up and down pictures, the two it already had do not move.
const FACE_RIGHT := 0
const FACE_LEFT := 1
const FACE_DOWN := 2
const FACE_UP := 3


## **How many ways row `type_id` can face**, which is however many pictures it declares. 0 for a row
## with none, so a caller never has to know which rows are drawn at all.
static func beast_facings(type_id: int) -> int:
	if type_id < 0 or type_id >= BEAST_TEX.size():
		return 0
	return (BEAST_TEX[type_id][_TEX_COL_PICS] as Array).size()


## The picture path row `type_id` wears facing `facing`, or `""` for a row with none — **and `""` for
## a facing that row does not have**, which is the same answer and the same fallback.
static func beast_tex_path(type_id: int, facing: int) -> String:
	if facing < 0 or facing >= beast_facings(type_id):
		return ""
	return str((BEAST_TEX[type_id][_TEX_COL_PICS] as Array)[facing])


## **How wide row `type_id`'s ANIMAL is drawn, as a multiple of what `BEAST_SPRITE_W_RATIO` gives
## everything.** 1.0 for an unknown row, so a bad id draws at the shared size rather than vanishing.
## ⚠⚠ **THE ANIMAL AND NOT THE PICTURE** (2026-08-31) — the caller divides this by the row's measured
## ink fraction to get the picture's width, so **a wider canvas no longer shrinks the body.**
static func beast_draw_scale(type_id: int) -> float:
	if type_id < 0 or type_id >= BEAST_TEX.size():
		return 1.0
	return float(BEAST_TEX[type_id][_TEX_COL_DRAW])


## How many frames row `type_id`'s `anim` strip holds. **0 for an unknown row and for any row that
## declares no strip of that kind** — one answer, so no caller has to know which of the two it hit.
## ⚠⚠ **`IDLE` WAS REFUSED ON THE SECOND LINE OF THIS FUNCTION** (`anim <= Anim.IDLE`, until
## 2026-08-31). It is a strip like the other two now, and a row with no breath art answers 0 through
## the same lookup every other row uses rather than through a special case.
static func beast_anim_frames(type_id: int, anim: int) -> int:
	if type_id < 0 or type_id >= BEAST_TEX.size():
		return 0
	if anim < 0 or anim >= ANIM_NAME.size():
		return 0
	var row: Array = BEAST_TEX[type_id]
	var strips: Array = row[_TEX_COL_FRAMES]
	return int(strips[anim])


## One frame's path, **derived from the standing picture rather than named a second time.** The
## convention is `<beast>_<anim>_<frame>_<facing>.png` and the standing picture is `<beast>_<facing>`,
## so the stem is already on the row; writing the strip out as sixteen more constants would put the
## word `wolf` in seventeen places and rot in sixteen of them the day a species is renamed.
##
## Falls back on the standing picture for a row with no strip of that kind and for a row with no
## picture at all, so **a caller never has to ask whether this species is animated.**
## ⚠ **`IDLE` used to be in that list of fallbacks and is not any more** — a row that declares idle
## frames gets `<stem>_idle_<n>.png` from here like any other strip.
## ⚠ **The facing suffix is read off the standing picture rather than rebuilt from the index.** A
## picture that carries none — the four-facing wolf's files are compass words — keeps its whole name as
## the stem, so its frames would be `<name>_walk_0.png`. **Nothing declares a strip today**, so no such
## file exists; what this does is refuse to invent `_r` for a picture that never had one.
static func beast_frame_path(type_id: int, anim: int, frame: int, facing: int) -> String:
	var idle := beast_tex_path(type_id, facing)
	var count := beast_anim_frames(type_id, anim)
	if idle.is_empty() or count <= 0 or frame < 0 or frame >= count:
		return idle
	var tail := ".png"
	for suffix in ["_r.png", "_l.png"]:
		if idle.ends_with(str(suffix)):
			tail = str(suffix)
			break
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

## ⚠⚠ **THE HP BAR IS BACK AND NOT ONE OF ITS OLD VALUES CAME WITH IT** (2026-09-01, the user:
## 「체력바는 없다고 한 거는 그 당시 없는 거고 지금 추가하겠다는 거야」 — *"saying there was no HP bar
## was about back then; now I am saying we add it"*). It was deleted 2026-08-28 (「체력바 없이」) and
## took `HP_BAR_W_PX`, `HP_BAR_H_PX`, `HP_BAR_GAP_PX`, `hp_bar_origin_px`, `hp_bar_size_px` and
## `hp_bar_colour` with it. **Two of those six names are back and both were measured again**, and
## the height is not a constant at all any more — it rides the picture's own aspect through
## `field_view._billboard_scale`, so a re-pulled picture cannot come out squashed.
##
## ⚠⚠ **IT IS TWO PICTURES AND NOT ONE, BECAUSE A BAR HAS TO SHRINK.** One loaded picture is a fixed
## width; the fill is cropped with `region_rect` to `hp / max_hp` instead. **Both were pulled in
## `tools/pixel/`** and neither is typed — `CLAUDE.md` carries the `draw_rect` failure by name.
##
## ⚠⚠ **THE FILL PICTURE IS THE FRAME'S TROUGH, CUT OUT OF THE SAME CANVAS**, which is the whole of
## how the two register. The frame is 64 x 16 with its stone standing 3 px inside each edge and its
## dark trough occupying x 7..56 and y 4..11 — **centred in the canvas on both axes** — and the fill
## is exactly that 50 x 8 box. ⇒ **Both sprites hang at one anchor, centred, and line up with no
## offset of their own**, and the fill's drawn width comes out of the two pictures' widths rather
## than out of a third number here. **Re-pull either picture and that centring is what has to hold.**
const HP_BAR_FRAME := "res://assets/ui/hp_bar_frame.png"
const HP_BAR_FILL := "res://assets/ui/hp_bar_fill.png"

## **How wide the whole 64 px frame picture is drawn, in world px** — the visible stone is 58/64 of it.
##
## ⚠ **Measured against the bodies it hangs over and nothing else.** `BEAST_TEX`'s 0.85 note records
## the wolf's drawn ink at **20.9 px** and the man's at 1/1.42 of that, **14.7 px**. At 20.0 the bar
## is the animal's own width and half again the man's, which is the widest it can be without reading
## as a thing standing beside the body rather than over it.
## ⚠⚠ **UNJUDGED ON SCREEN.** Nobody has looked at this number yet, and 「연출은 과할 정도로」 says an
## undershoot costs a whole round — **so this is the first value, not a settled one.**
const HP_BAR_W_PX := 20.0                # >= 12 (under it the trough is thinner than one texel drawn);
                                         # <= 24 (past the wolf's own ink it overhangs the animal)

## **The gap between a body's drawn TOP and the bottom of its bar**, in world px.
## ⚠ The bar draws 5.0 px tall at `HP_BAR_W_PX` (16/64 of it), so 3.0 is a little over half its own
## height — enough that `BODY_OUTLINE_SCALE`'s 4% black shell around the head does not touch the stone.
const HP_BAR_LIFT_PX := 3.0

## **The gap between the 성채's drawn ROOF and the bottom of its bar**, in world px.
## ⚠ **Twice a body's, and not the same number.** A building is grown by `_outline` the same way a
## body is, but it is `BUILD_SCALE` times a mesh rather than a 40 px card — its shell is thicker in
## world units, and a bar sitting on the ridge would read as part of the roof.
const HP_BAR_KEEP_LIFT_PX := 6.0

## **How far in front of its frame the fill stands**, in 조각, along the camera's own axis.
## ⚠⚠ **ALONG THE CAMERA AND NOT ALONG THE WORLD**, the same rule `BODY_OUTLINE_BACK_TILES` keeps:
## both quads are billboards standing at one point, so 「in front」 has no world axis. ⚠ **The camera
## is orthographic**, so this moves the fill in depth and not on screen at all.
const HP_BAR_FILL_FRONT_TILES := 0.03

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
# The panel — what is picked, in one corner (03-02)
# ---------------------------------------------------------------------------------------------

## **The plate the picked body's four lines sit on**, pulled in a tool and loaded — never a `draw_rect`.
## ⚠⚠ **Pulled AT `PANEL_SIZE_PX` and asserted to be that size** (`net_panel`): the layout below is
## not re-fitted to whatever picture arrives, so a plate pulled at another size goes red rather than
## quietly shifting every baseline.
const PANEL_TEX := "res://assets/ui/panel.png"

## **The Hangul pixel font the panel is typed in** — Galmuri14, OFL 1.1, whose native size is 15 px.
## ⚠ `draw_string`'s default size is 16, not 15; a leaf that omits the size silently leaves the
## font's pixel grid, which is why the size travels through the hook's arguments.
const PANEL_FONT := "res://assets/font/Galmuri14.ttf"
const PANEL_FONT_PX := 15

## Inside the plate: the padding on every side and the pitch from one baseline to the next.
## ⚠ `PANEL_SIZE_PX.y` is `2 * PANEL_PAD_PX + PANEL_LABELS.size() * PANEL_LINE_PX` — 92 — and the
## plate is pulled at exactly that. Change one and the other must follow.
const PANEL_PAD_PX := 8
const PANEL_LINE_PX := 19
const PANEL_SIZE_PX := Vector2(160, 92)

## The four labels, in the order the lines are drawn (2026-09-02, the user: 「이름 특성 체력으로 일단
## 떠야함」, then 허기 the same day). ⚠ Not `PackedStringArray` — a `const` packed array does not parse
## on 4.7.1; every read casts to `String`.
const PANEL_LABELS := ["이름", "특성", "체력", "허기"]

## Which corner the plate sits in. **Bottom-left is where the build starts** — the 시안 round
## photographs the winner in all four and the user's answer lands here.
enum PanelCorner { TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT }
const PANEL_CORNER := PanelCorner.BOTTOM_LEFT

## The text colour. The HUD's own until the chosen plate asks for another.
const COL_PANEL_TEXT := COL_HUD_TEXT


## **The plate's top-left for `PANEL_CORNER`, flush with the viewport edge, no margin.**
##
## ⚠ Derived from the canvas the same way `game_over_origin_px` is: `window/stretch/mode` is
## `canvas_items`, so the answer survives a resize and a typed `Vector2(0, 628)` would not.
static func panel_origin_px(size: Vector2) -> Vector2:
	var far := viewport_size_px() - size
	match PANEL_CORNER:
		PanelCorner.TOP_LEFT:
			return Vector2.ZERO
		PanelCorner.TOP_RIGHT:
			return Vector2(far.x, 0.0)
		PanelCorner.BOTTOM_LEFT:
			return Vector2(0.0, far.y)
		_:
			return far


## **The BASELINE of line `line`**, which is the point `draw_string` takes — nothing is added inside
## the leaf. `ascent_px` is `font.get_ascent(PANEL_FONT_PX)`, computed once in `_draw` and computed
## the same way by the net, so the first baseline sits one ascent under the top padding.
static func panel_line_baseline_px(origin: Vector2, line: int, ascent_px: float) -> Vector2:
	return origin + Vector2(float(PANEL_PAD_PX),
		float(PANEL_PAD_PX) + ascent_px + float(line * PANEL_LINE_PX))

# ---------------------------------------------------------------------------------------------
# Panel — reward pick, win, lose, restart
# ---------------------------------------------------------------------------------------------


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
# The loss — GAME OVER, and it is ONE picture and ONE position
# ---------------------------------------------------------------------------------------------

## **The words GAME OVER, red, pulled in `tools/pixel/` and loaded** (2026-09-01, the user: *"I
## thought about the ending scene — I think just showing GAME OVER is enough. Red letters, it just
## appears, and that is the end."*). **The island stays behind it and the game stops there**, which is
## the same day's answer.
##
## ⚠⚠ **THERE IS NO WIDTH CONSTANT HERE AND THAT IS THE WHOLE DESIGN.** The picture was cut to the
## width it is drawn at — 640 px, half the 1280 canvas — so the file's own width IS the number and a
## second copy of it cannot drift from the first. **Re-pull the picture at a different width and the
## words simply come out that wide**; nothing in `src/` has to be told.
## ⚠ It is drawn 1:1, and `textures/canvas_textures/default_texture_filter` is Nearest, so every texel
## lands on exactly one canvas pixel. Scaling it here would be the one thing that undoes that.
const GAME_OVER_TEX := "res://assets/ui/game_over.png"

## **Where the picture's top-left corner goes**, from its own size and the canvas's.
##
## ⚠⚠ **Dead centre, and derived rather than written down.** `window/stretch/mode` is `canvas_items`,
## so the canvas is 1280 x 720 whatever the window is doing and this answer survives a resize — the
## risk the ticket named. A hand-written `Vector2(320, 290)` would be right for exactly one picture
## and silently off-centre for the next one pulled.
static func game_over_origin_px(tex_size: Vector2) -> Vector2:
	return (viewport_size_px() - tex_size) * 0.5


## **The picture on the button that takes a lost run back to the title.**
##
## ⚠⚠ **THIS REVERSES 티켓 02-03's OWN 「그대로 멈춘다」** (2026-09-01, the user, after seeing the screen:
## 「그 게임오버 하고 타이틀로 돌아가는 버튼도 만들어줘」). That ticket wrote 「끝」 and put a way back in
## its Out of scope; **the user reversed it themselves once the words were on the glass.**
##
## ⚠ **Made in pixellab, not typed.** A `draw_rect` plate with a `draw_string` label is exactly what the
## island's grey button was, and this repo deleted that once already.
const BACK_TO_TITLE_TEX := "res://assets/ui/back_to_title.png"

## **How far under the GAME OVER lettering the button's top sits, in canvas px.**
const BACK_TO_TITLE_GAP_PX := 28.0

## **Where the button goes, as a rect, from the two pictures' own sizes.**
##
## ⚠⚠ **DERIVED FROM THE LETTERING AND NOT WRITTEN DOWN**, the same argument `game_over_origin_px`
## makes: the words are centred by their own width, so a hand-typed y would drift the moment either
## picture is re-pulled. **Centred on x, and hung under the words on y.**
## ⚠ **It is a Rect2 and not a position**, because the shell hit-tests the very rectangle that was
## drawn — a second rect written beside it is how a button ends up pressable somewhere it is not.
static func back_to_title_rect_px(over_size: Vector2, button_size: Vector2) -> Rect2:
	var over_at := game_over_origin_px(over_size)
	var x := (viewport_size_px().x - button_size.x) * 0.5
	var y := over_at.y + over_size.y + BACK_TO_TITLE_GAP_PX
	return Rect2(Vector2(x, y), button_size)


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


## ⚠⚠ **`ROUTE_WIDTH_PX` AND `TARGET_RING_R_PX` STOOD HERE AND BOTH ARE DELETED** (2026-08-29) with
## the drag overlay and the boats. **The measurement they cost is the world-width table**: a line
## specified in world px reaches the glass multiplied by the zoom, so at `ZOOM_MIN` 0.45 a 3.0 px
## route drew at **1.35 px** — under this file's own 2.0 px snap floor, at exactly the zoom an island
## opens at. A capture found only the axis-aligned leg rasterising at all. **5.0 was the value both
## `REFUSE_MARK_WIDTH_PX` and `CLIFF_FACE_WIDTH_PX` had already been re-measured to**, and this was
## the third row of that table that nobody re-measured. ⚠ **Any new world-space line does this sum.**


## ⚠ **`HULL_WAIT_BLINK_SEC` went with the boats** (2026-08-29) — a stalled hull's blink, a full
## on/off cycle rather than a half. **A blink under 0.3 s is five frames at 60fps and is not seen.**
## (`CLIFF_FACE_WIDTH_PX` was deleted 2026-08-24: the seaward-edge line it sized became a real wall
## in the terrain mesh, and its last readers were two net labels bounding a line nothing drew.)


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
## `BODY_LUNGE_SEC` (0.18 s) so a sway never reads as a blow.
## ⚠⚠ **`BODY_LUNGE_SEC := 0.18` AND `BODY_LUNGE_RATIO := 0.55` STOOD HERE AND BOTH ARE DELETED**
## (2026-08-31, the user at the screen: 「지금 갑자기 왜다 갔다 하는게 있는데 이런거 말고」). They
## pushed a swinging body forward along its heading and eased it back — **8.2 px, 39% of the wolf's
## own drawn width, measured in a real fight** — and it read as the animal sliding rather than
## striking.
## ⚠ **The question it was built for is open**: a wolf's jaws change its outline by 0 px at the
## size it is drawn. The reference `2026-08-31-hit-feel-elements` holds the six answers the user
## named and what each costs. **Do not re-propose the lunge** — it has been seen and rejected.

const IDLE_AFTER_SEC := 0.5           # long enough that a pause between tiles does not wobble
const IDLE_SWAY_RATIO := 0.25         # of the drawn half-width: wolf 6.1 px, bear 8.8, squirrel 3.9
const IDLE_PERIOD_SEC := 1.1

const GAIT_PERIOD_TILES := 0.7        # one cycle every 28 px
## ⚠⚠ **0.20 -> 0.1125** (2026-08-30, the user at the screen: 「it bounces far too much. I'd like the
## character to be about right」). The squash is a FRACTION of the drawn size, so it grew with the
## bodies when `BODY_SPRITE_SCALE` went 0.45 -> 0.80 earlier the same day: **0.20 x 0.45 / 0.80 =
## 0.1125 puts every body back to the displacement it had before that raise**, and that is the whole
## derivation — no new number was chosen by eye.
##
## ⚠⚠ **THE px FIGURES THAT STOOD HERE DESCRIBED TODAY AND NOT 0.45, WHICH IS THE OPPOSITE OF WHAT
## THEY WERE READ AS.** They were 「crow 2.0 · ranged 2.2 · melee 2.8 · bison 3.2 · lion 4.4」 against
## species names from the nine-row table that died with the side swap. Re-measured at 0.20 with the
## five rows that exist: 까마귀 1.9 · 늑대 2.5 · 검사 2.7 · 곰 3.5 · 사자 3.8 px — **so 0.20 was already
## producing roughly those numbers, and「bring the stale figures back」would have changed nothing.**
## ⇒ **What moved this was the user at the screen, not the arithmetic.**
##
## **Measured at 0.1125, max displacement of one edge — half-width first, half-height second:**
## 까마귀 1.10 / 0.73 · 사자 1.23 / 1.23 (no picture, drawn as a square) · 검사 1.54 / 1.87 ·
## 곰 1.95 / 1.66 · 늑대 2.36 / 2.36 px. ⚠ **The wolf is the largest because its own draw column is
## 1.70** — see `BEAST_TEX` — so it barely moved while everything else halved.
##
## ⚠⚠ **THIS CONTRADICTS A MEASUREMENT THAT IS STILL TRUE AND THE CONTRADICTION IS DELIBERATE.** The
## old note said 「the crow sits exactly on the 2.0 px floor; at 0.12 all five bodies were at or under
## it, which would have made this item invisible」 — and at 0.1125 four of the five are under 2.0 px.
## **The user looked at the screen and called it too much anyway**, which outranks a floor nobody has
## re-measured since the bodies, the species table and the camera all changed.
## ⚠⚠ **0.1125 -> 0.0, THE GAIT SQUASH IS OFF** (2026-08-31, the user at the screen: 「that springy
## up-and-down animation — just get rid of it. It will be fine without it. It looks far too strange」).
## **This is the SECOND time the same motion was cut back and the first cut did not settle it**: it went
## 0.20 -> 0.1125 the day before, by arithmetic, and the user still called it wrong by eye.
## ⇒ **The eye outranks the derivation, and the derivation above is kept only to say what was tried.**
##
## ⚠ **`_gait_squash` returns `Vector2.ONE` the moment this is zero**, so nothing downstream branches on
## it and no caller had to move. **The constant stays declared** — `net_draw_leaf` cites it by name, and
## a species that wants a gait back changes this one number.
##
## ⚠⚠ **THE SIDEWAYS IDLE SWAY WAS ALREADY OFF** (2026-08-30, same complaint, different motion), which
## means **every body-bound motion this file had is now silent**. The cost is the one already written
## down beside `_idle_offset`: a body that cannot advance has NOTHING moving on it, and
## 「붙어서 가만히 있으면 재미가 죽는다」 is still an open question — **it is now open for walking bodies
## too, not just stuck ones.** ⚠ **It is not answered by turning this back on.**
const GAIT_SQUASH := 0.0


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

## **The 이동선 — the route the picked body would walk, drawn before it walks it** (2026-08-31, the
## user: 「이동할때 이동선이 미리 보였으면 좋겠네」).
##
## ⚠⚠ **IT IS THE ROUTE AND NOT A STRAIGHT LINE.** `Hand.routes` builds it from the same flow field and
## the same `string_pull` that `Battle.order_walk` uses, so the line drawn is the line walked. A line
## drawn any other way is a promise the walk does not keep, and 티켓 37 is the round that measured a
## walk bending where the picture did not.
##
## ⚠ **Half-width, so the ribbon is twice this across.** Kept under half a 조각 — a line as wide as the
## 판 it crosses reads as another 판 rather than as a route over them.
const MOVE_LINE_HALF_PX := 3.0

## **How near a press has to land to count as pressing a BODY** rather than the ground under it, in
## 조각. ⚠ **A distance and not a 조각 test**: bodies stand up to three to a 조각 and off its centre,
## so 「the body whose 조각 you pressed」 refuses presses that visibly hit somebody and accepts presses
## that visibly missed.
## ⚠ **A body is drawn standing UP from its feet**, so a press aimed at the chest lands past the feet
## on the ground behind them. This is generous on purpose for that reason, and it is the first number
## to move if picking feels sticky or slippery.
const PICK_BODY_TILES := 0.8

## **The white rim around the body the hand is holding** (2026-08-31, the user: 「캐릭터 눌렀을때 살짝
## 내가 누른 캐릭에 흰색 테두리 ... 내가 누른 캐릭이 티가 나야할듯함」).
##
## ⚠⚠ **THE RIM IS THE BODY'S OWN PICTURE DRAWN LARGER BEHIND IT**, so this number is a MULTIPLIER on
## the drawn width and the rim therefore thickens with the body as the camera comes in. A rim in fixed
## world units would vanish at the far zoom and swallow the body at the near one.
## ⚠⚠ **1.10 WAS TOO THIN TO SEE AND THAT WAS MEASURED, NOT GUESSED** (2026-08-31). Photographed at
## 1.10 the rim was there — 1213 near-white pixels around one body — and could not be told from the
## ground beside it: **white on this island reads badly, because the ground is pale.** ⇒ raised until
## it reads while still being 「살짝」 (the user's word). Past about 1.4 it stops being an outline and
## starts being a ghost standing behind.
const PICK_OUTLINE_GROW := 1.22

## How far behind the body the rim sits, in 조각, measured along the CAMERA's own forward.
##
## ⚠⚠ **IT HAS TO BE ALONG THE VIEW AND NOT ALONG AN AXIS.** Both sprites are billboards at the same
## point; without a separation they write the same depth and the rim wins over the body's face in
## whichever order the frame happens to draw them. **The camera's forward is the only direction that
## means 「behind」 for something that always turns to face the camera.**
const PICK_OUTLINE_BACK_TILES := 0.05

## ⚠ **Alpha 1.** The rim is a silhouette and a translucent one reads as a smear rather than a line.
const COL_PICK_OUTLINE := Color(1.0, 1.0, 1.0, 1.0)

## The dot dropped where the route ends. **Bigger than the line is wide**, or the end of the walk is
## indistinguishable from a bend in it.
const MOVE_LINE_END_PX := 7.0

## ⚠ **Alpha is in the colour and there is no second fade.** The ground layer is alpha-blended and
## unshaded, so what is written here is what is on screen.
const COL_MOVE_LINE := Color(1.0, 0.98, 0.86, 0.72)
const COL_MOVE_LINE_END := Color(1.0, 0.98, 0.86, 0.92)

## **How far the 이동선 is allowed to fight the zoom**, as a multiplier on its own width.
##
## ⚠⚠ **THE LINE HOLDS ITS WIDTH ON SCREEN AND THE REST OF THE BOARD DOES NOT** (2026-08-31, the user:
## 「마우스 휠을 내릴 수도 올릴 수도 있는거니까 항상 개발할때 고려해야함 ... 회전 및 확대 축소때」). It
## is a mark the HAND reads rather than a thing standing in the world, so it is drawn at `1 / zoom` —
## and these two stop that from running away. **`ZOOM_MAX` is the far bound**: past it the line would be
## wider than the 조각 it crosses and stop reading as a route.
const MOVE_LINE_ZOOM_MIN := 0.7
const MOVE_LINE_ZOOM_MAX := 2.4


## ⚠⚠ **`FX_SETTLE_FRAMES` WAS DELETED 2026-08-27, AND ITS OWN HEADER PREDICTED IT.** It said "nothing
## in `src/` reads it" and justified living here anyway, so that a capture and the screen could not
## disagree. **No capture ever read it either** — it occurred exactly once in the whole repo, at its
## own declaration, while every shooter hard-coded its own settle count. A number kept so two things
## agree, that neither of them reads, is a number that guarantees nothing.


# ---------------------------------------------------------------------------------------------
# Accessors
# ---------------------------------------------------------------------------------------------

## **Where inside its own 조각 the body in reservation slot `slot` stands, in canvas px.**
##
## ⚠⚠ **SLOT 0 IS THE 조각 CENTRE AND EVERY OTHER SLOT RINGS IT.** A body standing alone is always in
## slot 0 — `Grid._free_slot` hands out the lowest free one — so **a lone body is drawn exactly where it
## was before the crowd existed**, and nothing about the single-body picture had to be re-judged.
##
## ⚠ **`cap` is passed in rather than read from `Rules`.** This file is presentation and holds no rule;
## the caller already has the capacity in hand, and a copy of it here would be the second place the
## number lives.
## ⚠ **The ring is in WORLD axes, not screen axes.** These px are the same px `tile_point_px` answers
## in, so the spread is fixed to the ground and does not swing when the board is turned.
static func crowd_offset_px(slot: int, cap: int) -> Vector2:
	if slot <= 0 or cap <= 1:
		return Vector2.ZERO
	var around := maxi(cap - 1, 1)
	var a := TAU * float(slot - 1) / float(around)
	return Vector2(cos(a), sin(a)) * CROWD_SPREAD_RATIO * TILE_PX


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


## ⚠⚠ **`FX_GAIN` AND `fx_gain_of` STOOD HERE AND BOTH ARE DELETED** (2026-08-29) with the twelve
## effects. **The trap they were built for is the part to carry**: the effects were numbered 1..12 and
## the table was indexed 0..11, so the off-by-one lived in ONE accessor. Spread across callers, one of
## them eventually reads its neighbour's gain — and the effect that appears to switch off is the wrong
## one, with the round still green and only the screen different.


## **A colour with its alpha multiplied by `amount`**, which is the whole of how a mark fades.
## ⚠ **It lives here because `net_draw_leaf` reddens on a `Color(` written anywhere else in the
## tree**, and a fade is a colour like any other.
## **A mark's modulate at `amount` of its life left** — plain white, faded.
## ⚠⚠ **THE VIEW CANNOT WRITE `Color.WHITE` ITSELF**: `net_draw_leaf` reddens on a `Color.` outside
## this file, and it is right to — a colour named in a drawer is a colour nobody can find again.
static func mark_fade(amount: float) -> Color:
	return fade_of(Color.WHITE, amount)


## **A damage number's modulate at `amount` of its life left.**
static func damage_fade(amount: float) -> Color:
	return fade_of(COL_DAMAGE, amount)


static func fade_of(base: Color, amount: float) -> Color:
	return Color(base.r, base.g, base.b, base.a * clampf(amount, 0.0, 1.0))


## **A body's own colour pulled `amount` of the way to white**, which is what a hit flash is.
## ⚠ **It is applied BEFORE `beast_tint`, not after.** The tint is what says which side a body is on;
## washing the tinted colour would make a flashing enemy and a flashing 검사 the same white, and the
## one frame a body is brightest is the worst frame to lose its side in.
static func hit_flash_colour(colour: Color, amount: float) -> Color:
	if amount <= 0.0:
		return colour
	return colour.lerp(Color.WHITE, clampf(amount, 0.0, 1.0) * HIT_FLASH_MIX)


## The modulate a body's picture is drawn with: its own side colour mixed `BEAST_TEAM_TINT` of the way
## into white. **It lives here and not in `field_view` because every colour in this game lives here**,
## and `net_draw_leaf` reddens on a `Color.` written anywhere else.
## ⚠⚠ **기법 26 · 색으로 배경에서 떼기 LIVES HERE AND NOT IN THE VIEW** (2026-08-31). A gain applied
## in `_put_body` broke `net_shell`'s 「a body's colour came from the sim」 the moment it went in, and
## rightly: **two places deciding one colour is two answers.** Folded in here, the check computes the
## same number the drawer does and the guarantee survives the technique.
static func beast_tint(colour: Color) -> Color:
	var lit := Color.WHITE.lerp(colour, BEAST_TEAM_TINT)
	return Color(lit.r * BODY_SEPARATE_GAIN, lit.g * BODY_SEPARATE_GAIN, lit.b * BODY_SEPARATE_GAIN,
		lit.a)


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

## ⚠ **`panel_rect_px` and `button_rect_px` stood here and both are deleted** (2026-08-29) with the
## verdict panel. **The rule they kept between them survives**: one rectangle answering to two verbs
## is how a restart gets pressed by someone aiming at start.


## Absolute viewport rectangles, not panel-relative ones: the shell hit-tests a mouse position
## against these, and a relative rect would have to be offset by whoever asked — which is the
## same value living in two places.


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


# --- The beasts' boat, on screen -------------------------------------------------------------------
## ⚠⚠ **NONE OF THIS CHANGES WHAT HAPPENS.** The sim's boat has a flat position and a heading; the bob,
## the roll and the deck are what the eye is given on top of it. `Rules` holds when a boat comes, how
## fast and how far — **a net driving the sim must not be able to see anything in this block.**

## ⚠ **`BOAT_SCENE` STOOD HERE AND IT MOVED TO `field_view.gd`** (2026-08-30), beside the island, the
## buildings and the scatter. Three scene paths already live there and one exception is worse than the
## rule; **this file keeps every number the hull is DRAWN with, and that file keeps what is loaded.**

## How far the hull rises and falls, in tiles, and how long one full bob takes.
## ⚠ **Small on purpose**: the boat is 5.2 tiles long, and a rise a reader can measure against that
## length reads as a toy on a spring rather than as a hull on water.
const BOAT_BOB_TILES := 0.06
const BOAT_BOB_SEC := 2.2
## How far it leans side to side, about its own length. ⚠ **The period is deliberately NOT a multiple
## of the bob's** — two motions on the same clock read as one motion, which is the thing that makes a
## hull look keyframed.
const BOAT_ROLL_DEG := 3.0
const BOAT_ROLL_SEC := 3.1

## How far along its own bob each successive hull starts, in radians.
##
## ⚠⚠ **IT WAS `float(i)` BAKED INTO `field_view` AND IT IS A LOOK VALUE LIKE ANY OTHER.** Two boats
## sitting off the same island on a shared phase rise and fall as ONE object, which reads as a sprite
## sheet rather than as two hulls on water. **At 0 they are back in lockstep**, which is what makes
## this the knob a candidate sheet varies rather than a constant nobody can find.
const BOAT_BOB_PHASE_PER_HULL := 1.0

## How deep the hull sits relative to the open sea's own surface, in tiles. **Added to `SEA_Y_TILES`**,
## so raising the water carries the boat with it and only the difference lives here.
##
## ⚠⚠ **IT WAS 0 AND THE WHOLE BOAT SAT ON TOP OF THE WATER** (2026-08-30, measured on the running
## game). **The model's origin is its KEEL** — the arriving hull runs y from 0.00 to 0.50 — so at 0 the
## entire hull stood above the surface and the boat read as resting ON the sea rather than in it.
##
## ⚠ **Negative, and bounded at both ends.** At -0.20 the keel is 0.20 under and **40% of the 0.50-deep
## hull is submerged**. **Too little and it floats again; too much and the benches go under** — the
## lowest seat in `BOAT_DECK_SLOTS` sits 0.360 up, and the bob moves the whole hull `BOAT_BOB_TILES`
## either way. `net_boats` holds both ends against those two constants.
## ⚠⚠ **THE VALUE DID NOT MOVE WHEN THE HULL WAS SWAPPED ON 2026-09-01 AND THE FRACTION DID** — the
## measurement above was 「about a third of a 0.62-deep hull」 against `boat.glb`, and the small hull is
## shallower, so the same -0.20 puts proportionally more of it under. **Nothing retunes it here**: how
## deep a boat should look is an eye's answer, and this round only changed which hull comes.
const BOAT_DRAFT_TILES := -0.20

## **The four places a rider stands, in the hull's own local space, in tiles.**
##
## ⚠⚠ **READ OFF THE MESH, ONE BENCH AT A TIME.** `boat_small.glb` is **one joined mesh with no named
## parts**, so a bench is a run of `bs_bench` geometry that crosses the whole beam — there are two, and
## the two narrow end posts wearing the same material are not benches. They sit at local x = −0.42 and
## +0.42, their tops at y = 0.360, and they run 1.200 and 1.070 across the beam — so the two seats on a
## bench are at a quarter of that width either side of its middle. **A single shared z would put the
## fore and aft pairs off the ends of their own planks**, which is exactly the sort of thing that reads
## as「the wolves are floating」 and gets blamed on the sprite.
##
## ⚠⚠ **EIGHT SEATS ON FOUR BENCHES -> FOUR ON TWO** (2026-09-01, with `Rules.BOAT_CAPACITY`). ⚠ **Not
## the old table with four rows deleted**: the small hull's planks are elsewhere and are wider, so every
## number here is new. **The seats are further apart than they were** — the tightest pair was 0.292 조각
## and is now 0.535, which is what `boat_rider_shadow_r_tiles` reads.
##
## ⚠ `const X := PackedVector3Array([...])` is a parse error on 4.7 — see `Rules.UNITS` — so this is a
## plain const Array and its reader casts.
const BOAT_DECK_SLOTS := [
	Vector3(-0.42, 0.36, -0.3), Vector3(-0.42, 0.36, 0.3),
	Vector3(0.42, 0.36, -0.2675), Vector3(0.42, 0.36, 0.2675),
]

## ⚠⚠ **`BOAT_RIDER_TEX` STOOD HERE AND IT IS DELETED** (2026-08-30). It named the four `wolf_h`
## pictures a second time, in a second order, while the wolf's own row in `BEAST_TEX` named nothing but
## the old side-view animal. **That is how the deck ended up wearing the picture the user chose and the
## island wearing the one he did not** — the two lists could not disagree out loud, because neither
## mentioned the other. ⇒ **The deck reads the wolf's row like everything else does**, and the day the
## wolf's pictures change, the boat changes with it or nothing does.

## The rider's picture width as a multiple of a wolf's body radius. ⚠ **Its own number and not
## `BEAST_SPRITE_W_RATIO`**: these four are drawn square (92 x 92) where the walking wolf is wide and
## flat, so the side-on ratio would stand a rider on a deck half again as tall as one on the ground.
##
## ⚠⚠ **RAISED 2.4 -> 4.0** (2026-08-30, measured on the running game). At 2.4 a deck wolf drew about
## **an eighth of a 조각** and was simply not visible at the opening framing — the swordsman beside it
## is three times the size and does read. **3x only reaches the swordsman's floor**, and a rider needs
## more than that: it is a dark figure on a pale deck on an object that is bobbing, not a body standing
## still on flat grass.
## ⚠⚠ **AND AGAIN 4.0 -> 6.0** (2026-08-30, measured on the running game). **4x cleared 「invisible」 and
## not 「identifiable」**: eight distinct marks in four pairs, countable, none merging — and they read as
## generic dark animals rather than as wolves. At 6x each is near **0.6 조각** against the benches' 1.0
## 조각 spacing, so about 0.4 조각 of gap survives between the columns.
## ⚠⚠ **THE CEILING IS SEAT-TO-SEAT AND NOT BENCH-TO-BENCH, AND 6x HAS ALREADY REACHED IT**
## (2026-08-30, measured on the running game; this reverses what was written here twice). The binding
## distance is **the two riders sharing ONE bench**, not the 1.0 조각 between benches: the seats sit a
## quarter of a plank either side of its middle, so they are about 0.3 조각 apart. **At 6x the two on a
## bench overlap and the deck reads as four PAIRS rather than eight figures.**
## ⇒ **6x is where it stops.** The 「about 8x」 and the 「~10.1x headroom」 written here before were both
## measured against the wrong spacing and neither is real for the thing that matters.
## ⚠ `net_boats` pins this value, so raising it goes red rather than being noticed on a later screen.
##
## ⚠⚠ **AND THE NUMBER SIZES THE FRAME, NOT THE WOLF** (2026-08-30, measured off the four files). The
## four pictures are 92 x 92 and the wolf inside one fills **22% to 73% of that width** — against
## `wolf_r.png`, which is 82% filled and is what every other ratio in this file was chosen over. So
## 6 radii buys 0.594 조각 of FRAME and **0.426 조각 of side-on wolf, 0.129 조각 of head-on wolf**. The
## seat-to-seat ceiling above was reached by the side-on picture; the head-on one has never been near
## it. **Nothing here is retuned for that** — the ratio is pinned and this note is what stops the next
## reader taking 6 for the size of the animal.
##
## ⚠⚠ **6.0 -> 2.70, AND NOT ONE PIXEL OF THE DECK MOVED** (2026-08-30). Every measurement above was
## taken with `BODY_SPRITE_SCALE` multiplied in downstream, so 「6 radii」 has always reached the deck as
## `6.0 x 0.45 = 2.70` — which is why the numbers beside it read 0.594 and 0.426 조각 rather than the
## 1.3 and 0.95 that six bare radii would give. **The 0.45 is folded in here and the drawing no longer
## reads that constant.**
## ⚠⚠ **THE COUPLING IS WHAT WAS ACTUALLY WRONG.** `BODY_SPRITE_SCALE` is how big a body is drawn ON
## THE ISLAND and it was raised the same day so the wolves could be told apart there; through the old
## multiplication that raise went straight to the deck, where **the riders overflowed their benches**
## and the shadow discs under them stopped covering them. **The deck was judged against the boat and
## the island against the island** — two judgements, and one number cannot hold both.
## ⚠⚠ **`BEAST_TEX`'s draw column DOES NOT REACH HERE EITHER, for the same reason** (2026-08-30). The
## wolf's 1.70 is how big it reads on grass; a rider sized off it would be 1.70 times over its bench.
##
## ⚠⚠ **EVERY MEASUREMENT ABOVE WAS TAKEN ON A DECK THAT NO LONGER ARRIVES** (2026-09-01). It was eight
## riders on `boat.glb`'s four benches, 1.0 조각 apart, with a 0.292 조각 seat-to-seat gap — and the
## seat-to-seat gap is what the 6x ceiling was reached against. The small hull seats **four on two
## benches 0.84 조각 apart with a 0.535 조각 seat gap**, so the pair-overlap ceiling is not where it was.
## ⚠ **The ratio is deliberately NOT retuned here.** Where it stops is an eye's answer on a running
## screen, and this round only changed which hull comes.
const BOAT_RIDER_W_RATIO := 2.70


## **The disc laid on the plank under a rider, as a fraction of the gap between the two riders sharing
## the tightest bench.** ⚠ **Anchored to that gap and not typed as a length**: it is the one distance
## on the deck that says how much room a rider has, so moving a seat in `BOAT_DECK_SLOTS` moves the
## shadow with it instead of leaving a number here that used to be right.
##
## ⚠⚠ **0.75 PUTS THE DISC WIDER THAN THE WOLF IS, AND THAT IS THE WHOLE POINT** — see
## `how-nets-lie`'s 「a shadow the size of its caster is not a shadow」, measured twice on two subjects.
## Under 0.5 it would sit entirely beneath the animal and show nothing at all, which is exactly the
## failure that entry records.
## ⚠⚠ **THE LENGTHS THIS BOUGHT MOVED WITH THE HULL ON 2026-09-01, THE RATIO DID NOT.** On `boat.glb`
## the tightest gap was 0.292 조각 and the disc came out 0.219 조각 in radius — 0.438 조각 wide against
## the widest rider's own 0.426 조각 of ink. On the small hull the tightest gap is **0.535 조각**, so the
## disc is **0.401 조각 in radius and 0.802 조각 wide** under the same 0.426 조각 of animal. **That is
## nearly twice the ink instead of just over it**, and whether it still reads as a shadow rather than as
## a mat is an eye's answer this round did not take.
## ⚠ **The two discs on one bench therefore overlap**, in the same measure the two wolves above them
## already do — see `BOAT_RIDER_W_RATIO`.
const BOAT_RIDER_SHADOW_SEAT_RATIO := 0.75

## How far the disc floats above the plank it lies on. ⚠ **Only enough to lose the z-fight** — at the
## board's 40° tilt this is a fifth of a screen pixel, so it cannot read as the shadow hovering.
const BOAT_RIDER_SHADOW_LIFT_TILES := 0.004

## Segments in the disc. ⚠ **The disc is about 13 screen px across at the opening framing**, so past
## about sixteen the extra triangles land inside one pixel.
const BOAT_RIDER_SHADOW_SEGS := 16

## ⚠⚠ **SIZE AND STRENGTH ARE ONE DECISION** (`how-nets-lie`, same entry). This disc covered about
## **13 times** the area of `COL_BODY_SHADOW`'s disc on the ground, so it is carried a little stronger
## rather than left at the ground's alpha and spread thin. ⚠⚠ **THE HULL SWAP OF 2026-09-01 TOOK THE
## RADIUS 0.219 -> 0.401, WHICH IS ABOUT 44 TIMES THE GROUND DISC AND NOT 13** — see
## `BOAT_RIDER_SHADOW_SEAT_RATIO`. **The alpha was not re-chosen for that**, and 「a little stronger」
## was decided against the smaller disc.
## ⚠ **It lands on planking that is already dark** — the arriving hull's deck albedo is 0.246 luminance
## and its hull's is 0.069, **the same two values `boat.glb` carried** (the small boat's six materials
## are the big boat's palette), and the gunwale casts a real shadow across some of it — so **this is one flat
## alpha over a surface whose brightness varies**, and where the gunwale's own shadow already falls the
## two darken together. **Nothing compensates for that**; it is a thing for eyes.
## ⚠ Alpha stays under the 0.45 `COL_BODY_SHADOW` names as the point a disc reads as a hole.
const COL_BOAT_RIDER_SHADOW := Color(0.05, 0.06, 0.10, 0.34)


## **The radius of a rider's shadow disc, in 조각** — read off `BOAT_DECK_SLOTS` so the seat table is
## the only place the deck's spacing is written down.
##
## ⚠ **The TIGHTEST bench and not each bench's own.** The benches are different lengths, so a disc
## sized per bench would make the wolves at the ends look like different animals from the ones
## amidships — the animal is one size and its shadow is one size.
static func boat_rider_shadow_r_tiles() -> float:
	var gap := 1e9
	for k in range(0, BOAT_DECK_SLOTS.size(), 2):
		var a := BOAT_DECK_SLOTS[k] as Vector3
		var b := BOAT_DECK_SLOTS[k + 1] as Vector3
		gap = minf(gap, absf(b.z - a.z))
	return gap * BOAT_RIDER_SHADOW_SEAT_RATIO
