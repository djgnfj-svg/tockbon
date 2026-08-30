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
## ⚠⚠ **PICKED BY EYE IN THE GAME, 2026-08-29** (the user, flipping six tones live: 「다 별론디
## 3번으로 해줘」 — none of them loved, and this is the one). **+0.12 is the FAINTEST of the light
## three**; the dark three were rejected outright. ⚠ **Signed since the same day**: negative would pull
## the 판 toward black instead, and the shader draws either.
const PAD_ALL_LIGHTEN := 0.12           # how far the revealed 판 is pulled toward white
const PAD_HOVER_LIGHTEN := 0.55         # > PAD_ALL_LIGHTEN, same reason as the alphas
const PAD_HOVER_LIFT := 0.06            # world units. **3x the 판's own 0.02 thickness**

## ⚠⚠ **HOW FAR OUT THE 판 STOP BEING 조각 AND BECOME A 칸** (2026-08-29, the user: 「멀면 칸단위로
## 하려고함 줌에따라」, then 「1번이 좋은데?」 picking the mechanism that MOVES the vertices). Below
## `PAD_MERGE_ZOOM` a 칸 is one lump; above `PAD_APART_ZOOM` the four are separate; between them it is
## a straight ramp. ⚠ **Zoom is bigger the CLOSER the camera is**, so the merged bound is the lower one.
## ⚠ Chosen by eye in `.prototypes/merge/` against `ZOOM_MIN` 0.50 and the opening framing near 1.0;
## **nobody has re-judged them in the game**, and they are the first thing to move if the change
## happens too early or too late.
const PAD_MERGE_ZOOM := 0.72
const PAD_APART_ZOOM := 1.45

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
const BUILD_SCALE := 0.45

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

## How fast a held pan key moves the view, in SCREEN px per second.
## ⚠ **Screen px and not 조각**, so it goes through the same `pan_by` a mouse drag does — one path to
## the camera, and a key and a drag cannot end up disagreeing about which way is right.
const CAM_PAN_KEY_PX_PER_SEC := 900.0

## **How deep the edge band reaches in from each side of the window, in screen px.** The pointer
## inside it pans the camera for as long as it stays there.
##
## ⚠⚠ **THE EDGE IS THE PRIMARY WAY THE CAMERA TRAVELS NOW** (2026-08-30, the user: 「wasd 보다는
## 마우스가 끝으로 가면 자동으로 이동이 맞을듯」). WASD is not deleted — it was working and nobody
## asked for it to go — but it is no longer the hand that goes looking for a boat.
##
## ⚠ **NOT MEASURED ON A SCREEN. Nobody has looked at this number yet.** Both ends bite: too wide and
## the band covers ground a body is ordered onto, too narrow and the pointer has to be parked on the
## last few pixels of glass, which is the version of this control every review complains about.
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
## is, and how strong. ⚠⚠ **It is a LINE, not a band**: every 거품 drawn before it was a soft wash
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
## NUMBER THAT ARGUES WITH THE GLOSSARY.** `CONTEXT.md` defined 해안선 as ringing the island **without
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
## ⚠⚠ **AN ARRIVED BOAT SITS OFF ITS BEACH FOR THE REST OF THE ISLAND**, and a trail whose newest
## point is re-stamped every frame is forever nought seconds old: it collapses to **a full-strength
## blob the width of the stroke, welded to the transom, that never goes out** — one per landing, and
## they pile up. `FieldView._wake_stamp` freezes the stamp at the last moment the hull actually moved.
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
const BODY_RADIUS_RATIO := [0.245, 0.22, 0.31, 0.174, 0.342]


## **The wolf, seen from four sides — H, the picture the user chose** (티켓 48). Screen-right,
## screen-left, screen-down (coming at the camera), screen-up (going away).
##
## ⚠⚠ **THE FILE NAMES ARE COMPASS WORDS AND WHAT THEY ARE USED AS IS SCREEN DIRECTIONS.** The board
## turns, so a picker written against world north would spin every wolf the moment the player presses
## the turn key with nothing else on screen moving. **The heading is measured against the camera's own
## two ground axes** — `field_view._facing_index`.
## ⚠ **`wolf_h/` also carries `*_n.png` normal maps and NOTHING READS THEM** (티켓 50). Bodies are
## drawn unshaded, and a head-on wolf is a few screen px wide — there is nowhere to put a gradient.
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
const BEAST_BEAR_R := "res://assets/beast/bear_r.png"
const BEAST_BEAR_L := "res://assets/beast/bear_l.png"
const BEAST_CROW_R := "res://assets/beast/crow_r.png"
const BEAST_CROW_L := "res://assets/beast/crow_l.png"

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
## ⚠⚠ **`WOLF_ANIM_FRAMES := [4, 4]` STOOD HERE AND IT IS DELETED** (2026-08-30) with the side-view
## wolf it counted — see `BEAST_WOLF_H_R` above. **NO ROW DECLARES A STRIP ANY MORE**, so everything
## below this line runs and finds nothing, which is exactly what it was built to do: a species with no
## art wears its standing picture through the same call. **The rule it carried, for the day H is given
## frames**: WALK loops 0-1-2-3; BITE plays 0-1-2-3 once and hands the body back to WALK, because
## frame 0 of the bite is the only closed mouth and a looped bite leaves the jaw open all fight.

## How long one frame of any strip is held. **One rate for the whole animal**: 0.12 s puts the walk
## cycle at 0.48 s (8 fps, four frames), which at a 49 px body is a stride you can count — the same
## strip at 60 fps reads as a twitch, and 「연출은 과할 정도로」 cuts that way too. The bite is the same
## four frames, so it also runs 0.48 s against a ~1.0 s attack period: the jaw is moving for about
## half the time a body spends in contact, which is the half 「붙어서 가만히 있으면 재미가 죽는다」 is
## about. **The lunge (`LUNGE_SEC`) is deliberately shorter** — the body snaps out and back inside the
## first frames while the mouth carries the rest.
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
## ⚠⚠ **IT MULTIPLIES THE FRAME AND NOT THE ANIMAL, WHICH IS WHY THE WOLF'S NUMBER IS SO LARGE.**
## Measured off the four files: H's ink fills **72% of its 92 x 92 frame side-on and 24% head-on**,
## against `wolf_r.png`'s 82% — so at 1.0 the H wolf ashore would be SMALLER ink than the side-view
## wolf it replaces (17.7 px against 20.3), even though its frame is nearly twice as tall.
## ⚠ **1.70 is anchored on the swordsman, the one body the user says is about right**: it puts the
## wolf's side-on ink at 30.1 x 19.6 px against the man's 27.4 x 33.3 — an animal his size, lying
## lower. **The frame it sits in is 41.9 px, just over one 조각, and almost all of that is empty.**
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
const BEAST_TEX := [
	[[HUMAN_SWORD_R, HUMAN_SWORD_L], NO_ANIM_FRAMES, 1.0],
	[[BEAST_WOLF_H_R, BEAST_WOLF_H_L, BEAST_WOLF_H_D, BEAST_WOLF_H_U], NO_ANIM_FRAMES, 1.70],
	[[BEAST_BEAR_R, BEAST_BEAR_L], NO_ANIM_FRAMES, 1.0],
	[[BEAST_CROW_R, BEAST_CROW_L], NO_ANIM_FRAMES, 1.0],
	[[], NO_ANIM_FRAMES, 1.0],
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


## **How big row `type_id` is drawn, as a multiple of what `BEAST_SPRITE_W_RATIO` gives everything.**
## 1.0 for an unknown row, so a bad id draws at the shared size rather than vanishing.
static func beast_draw_scale(type_id: int) -> float:
	if type_id < 0 or type_id >= BEAST_TEX.size():
		return 1.0
	return float(BEAST_TEX[type_id][_TEX_COL_DRAW])


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
## `LUNGE_SEC` (0.18 s) so a sway never reads as a blow.
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
const GAIT_SQUASH := 0.1125


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
## game). **The model's origin is its KEEL** — `boat.glb`'s hull runs y from 0.00 to 0.62 — so at 0 the
## entire hull stood above the surface and the boat read as resting ON the sea rather than in it.
##
## ⚠ **Negative, and bounded at both ends.** At -0.20 the keel is 0.20 under and about a third of the
## 0.62-deep hull is submerged. **Too little and it floats again; too much and the benches go under** —
## the lowest seat in `BOAT_DECK_SLOTS` sits 0.4375 up, and the bob moves the whole hull
## `BOAT_BOB_TILES` either way. `net_boats` holds both ends against those two constants.
const BOAT_DRAFT_TILES := -0.20

## **The eight places a rider stands, in the hull's own local space, in tiles.**
##
## ⚠⚠ **READ OFF THE MESH, ONE BENCH AT A TIME.** `boat_bench_0..3` sit at local x = −1.55, −0.55,
## +0.45, +1.45 with their tops at y = 0.4375 (0.41 plus half of the 0.055 they are scaled to), and each
## bench is a unit cube scaled along z by 0.582 / 0.813 / 0.820 / 0.622 — so the two seats on a bench are
## at a quarter of that scale either side of its middle. **A single shared z would put the fore and aft
## pairs off the ends of their own planks**, which is exactly the sort of thing that reads as「the wolves
## are floating」 and gets blamed on the sprite.
##
## ⚠ `const X := PackedVector3Array([...])` is a parse error on 4.7 — see `Rules.UNITS` — so this is a
## plain const Array and its reader casts.
const BOAT_DECK_SLOTS := [
	Vector3(-1.55, 0.4375, -0.146), Vector3(-1.55, 0.4375, 0.146),
	Vector3(-0.55, 0.4375, -0.203), Vector3(-0.55, 0.4375, 0.203),
	Vector3(0.45, 0.4375, -0.205), Vector3(0.45, 0.4375, 0.205),
	Vector3(1.45, 0.4375, -0.155), Vector3(1.45, 0.4375, 0.155),
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
const BOAT_RIDER_W_RATIO := 2.70


## **The disc laid on the plank under a rider, as a fraction of the gap between the two riders sharing
## the tightest bench.** ⚠ **Anchored to that gap and not typed as a length**: it is the one distance
## on the deck that says how much room a rider has, so moving a seat in `BOAT_DECK_SLOTS` moves the
## shadow with it instead of leaving a number here that used to be right.
##
## ⚠⚠ **0.75 PUTS THE DISC WIDER THAN THE WOLF IS, AND THAT IS THE WHOLE POINT** — see
## `how-nets-lie`'s 「a shadow the size of its caster is not a shadow」, measured twice on two subjects.
## The tightest gap is 0.292 조각, so the disc is 0.219 조각 across the radius: **0.438 조각 wide against
## the widest rider's own 0.426 조각 of ink.** Under 0.5 it would sit entirely beneath the animal and
## show nothing at all, which is exactly the failure that entry records.
## ⚠ **The two discs on one bench therefore overlap**, in the same measure the two wolves above them
## already do — see `BOAT_RIDER_W_RATIO`.
const BOAT_RIDER_SHADOW_SEAT_RATIO := 0.75

## How far the disc floats above the plank it lies on. ⚠ **Only enough to lose the z-fight** — at the
## board's 40° tilt this is a fifth of a screen pixel, so it cannot read as the shadow hovering.
const BOAT_RIDER_SHADOW_LIFT_TILES := 0.004

## Segments in the disc. ⚠ **The disc is about 13 screen px across at the opening framing**, so past
## about sixteen the extra triangles land inside one pixel.
const BOAT_RIDER_SHADOW_SEGS := 16

## ⚠⚠ **SIZE AND STRENGTH ARE ONE DECISION** (`how-nets-lie`, same entry). This disc covers about
## **13 times** the area of `COL_BODY_SHADOW`'s disc on the ground, so it is carried a little stronger
## rather than left at the ground's alpha and spread thin.
## ⚠ **It lands on planking that is already dark** — `boat.glb`'s deck albedo is 0.246 luminance and
## the hull's is 0.069, and the gunwale casts a real shadow across some of it — so **this is one flat
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
