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
## An earlier version of this comment said "no camera zoom, no window stretch". The zoom half is
## true — `CAMERA_ZOOM` is 1.0 and nothing reads it. **The stretch half was false**: project.godot
## carries `window/stretch/mode="canvas_items"`, so a canvas pixel reaches the screen multiplied by
## `window width / 1280` (1.5x in a 1920 window), and the shell measured that transform at 0.05 in a
## 64px headless window. What survives the multiplier is everything relative — ratios, overlaps, and
## the 2.0 px snap floor, since snapping happens in canvas space BEFORE the stretch. What does not
## survive is any absolute claim about size on the glass. That distinction is exactly what the last
## game got wrong when a radius was read as a diameter and then multiplied.
## 32 x 40 = 1280 and 18 x 40 = 720, so the grid exactly fills the viewport. If a zoom is ever
## added, every px comment in this file becomes a lie silently — change them in the same edit.
const VIEWPORT_W_PX := 1280.0
const VIEWPORT_H_PX := 720.0
const TILE_PX := 40.0
const GRID_W := 32
const GRID_H := 18
const CAMERA_ZOOM := 1.0

## A faint grid, because in a game where position is the decision an invisible grid means the
## player cannot pick a position. It is drawn low-alpha, not thin-and-bright.
const GRID_LINE_WIDTH_PX := 1.0


# ---------------------------------------------------------------------------------------------
# Colours — the only `Color(` literals in the tree
# ---------------------------------------------------------------------------------------------

# Terrain. Three tones plus the dock, and the hole has to read as "cannot walk here" at a glance.
const COL_WATER := Color(0.086, 0.145, 0.255)
const COL_LAND := Color(0.203, 0.259, 0.184)
const COL_HOLE := Color(0.055, 0.067, 0.078)
const COL_DOCK := Color(0.553, 0.443, 0.243)
const COL_GRID_LINE := Color(1.0, 1.0, 1.0, 0.07)

# Bodies. Friend and foe are told apart by COLOUR; the unit type is told apart by SIZE and by how
# round its corners are — see BODY_RADIUS_RATIO and BODY_CORNER_RATIO.
const COL_ALLY := Color(0.451, 0.847, 1.0)
const COL_ENEMY := Color(1.0, 0.420, 0.361)
const COL_BEAK := Color(1.0, 0.863, 0.451)

# HP. The old game died partly because nothing on screen ever went down; the empty half is drawn
# so the bar has a length before it is hurt.
const COL_HP_FULL := Color(0.400, 0.898, 0.451)
const COL_HP_EMPTY := Color(0.118, 0.141, 0.141, 0.851)

# Boats. The berth icon and the boat crossing the water are the same colour on purpose: the limit
# is the picture, so the thing missing from the harbour must be recognisable as the thing at sea.
const COL_BOAT := Color(0.851, 0.780, 0.600)
const COL_BERTH_EMPTY := Color(0.302, 0.322, 0.341, 0.600)

# HUD and panel.
const COL_HUD_TEXT := Color(0.918, 0.937, 0.961)
const COL_PANEL_BG := Color(0.071, 0.090, 0.122, 0.941)
const COL_BUTTON := Color(0.239, 0.341, 0.459)
const COL_WIN := Color(0.549, 0.949, 0.600)
const COL_LOSE := Color(1.0, 0.451, 0.420)

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

const BODY_OUTLINE_WIDTH_PX := 2.0
const BODY_DOT_RADIUS_PX := 3.0

## The beak is a triangle poking OUT past the outline, so it reads at a glance which soldier is
## carrying it. Length is measured from the body edge outward, not from the centre.
const BEAK_LENGTH_PX := 9.0
const BEAK_WIDTH_PX := 8.0

## A thin bar under the body. GAP is from the bottom of the body to the top of the bar.
const HP_BAR_W_PX := 24.0
const HP_BAR_H_PX := 3.0
const HP_BAR_GAP_PX := 4.0

## The boat drawn on the water while it crosses.
const BOAT_W_PX := 26.0
const BOAT_H_PX := 14.0


# ---------------------------------------------------------------------------------------------
# HUD — laid out in absolute viewport pixels
# ---------------------------------------------------------------------------------------------

const HUD_FONT_SIZE_PX := 18
const HUD_TIMER_FONT_SIZE_PX := 24
const HUD_MARGIN_PX := 12.0

## Remaining time, top centre.
const HUD_TIMER_POS_PX := Vector2(600.0, 38.0)

## Two berth icons top left, then the number currently loaded beside them. A berth drawn empty IS
## the resource meter — there is no separate bar anywhere.
const HUD_BERTH_ORIGIN_PX := Vector2(16.0, 20.0)
const HUD_BERTH_SIZE_PX := Vector2(30.0, 18.0)
const HUD_BERTH_GAP_PX := 10.0
const HUD_LOAD_POS_PX := Vector2(96.0, 34.0)

## The 1 / 2 key roster, bottom left, one box per summonable type.
const HUD_KEY_ORIGIN_PX := Vector2(12.0, 640.0)
const HUD_KEY_SIZE_PX := Vector2(150.0, 26.0)
const HUD_KEY_GAP_PX := 6.0
const HUD_KEY_TEXT_OFFSET_PX := Vector2(8.0, 19.0)

## Enemies left, top right. It has to survive onto the lose screen — the player must be able to
## see WHY they lost, and "the timer ran out with four alive" is a different loss to a wipe.
const HUD_ENEMIES_LEFT_POS_PX := Vector2(1060.0, 38.0)


# ---------------------------------------------------------------------------------------------
# Panel — reward pick, win, lose, restart
# ---------------------------------------------------------------------------------------------

## Centred: (1280 - 560) / 2 = 360, (720 - 400) / 2 = 160.
const PANEL_ORIGIN_PX := Vector2(360.0, 160.0)
const PANEL_SIZE_PX := Vector2(560.0, 400.0)

const PANEL_TITLE_OFFSET_PX := Vector2(40.0, 44.0)
const PANEL_TITLE_FONT_SIZE_PX := 28
const PANEL_BODY_FONT_SIZE_PX := 18

## The roster the player clicks to bolt the beak on. Two columns of seven = 14 slots, and the run
## can hold at most 13 soldiers, so no entry is ever off the panel.
## Width check: 40 + 240 + 24 + 240 = 544 <= 560. Height check: 72 + 7 * (28 + 6) = 310 <= 400.
const ROSTER_ORIGIN_OFFSET_PX := Vector2(40.0, 72.0)
const ROSTER_ENTRY_SIZE_PX := Vector2(240.0, 28.0)
const ROSTER_ENTRY_GAP_PX := 6.0
const ROSTER_COLUMN_GAP_PX := 24.0
const ROSTER_COLUMNS := 2
const ROSTER_ROWS := 7
const ROSTER_TEXT_OFFSET_PX := Vector2(8.0, 20.0)

## The restart / continue button. 320 + 48 = 368 <= 400, so it clears the roster block above it.
const BUTTON_OFFSET_PX := Vector2(180.0, 320.0)
const BUTTON_SIZE_PX := Vector2(200.0, 48.0)
const BUTTON_TEXT_OFFSET_PX := Vector2(24.0, 32.0)


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
const SHOT_WIDTH_PX := 2.0

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
const SPARK_WIDTH_PX := 2.0           # same as a body outline. The leaf takes this as an ARGUMENT,
                                      # which is the only reason a net can bite on it at all
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
const BURST_WIDTH_PX := 2.0

## 5 — the area ring, grown to the REAL area radius so the screen finally says which attacks splash:
## the lion's `area` 1.5 tiles = 60 px, and CELL_RANGED's `area` 1.0 = 40 px, which nothing on screen
## currently communicates at all.
const AREA_RING_SEC := 0.25
const AREA_RING_START_RATIO := 0.4    # of the final radius, so 24 px for the lion's 60
const AREA_RING_WIDTH_PX := 3.0

## 6 — target lines, drawn for ENEMIES ONLY. The one item of the twelve that can be a net loss in
## readability: Into the Breach draws intent but is turn-based with under ten actors, and neither TFT
## nor Bad North draws any line at all — Riot explicitly deleted its "cloud of visual effects and
## particles". Hence two narrowings: one side only, and a hard count above which none are drawn.
const TARGET_LINE_WIDTH_PX := 1.0
const TARGET_LINE_MAX_COUNT := 8      # ⚠ THIS NEVER BITES IN PLAY. The three islands hold 4, 6 and 5
                                      # enemies, so the screen tops out at 6 lines and the net that
                                      # measures this builds a SYNTHETIC fight. Calling an
                                      # unreachable guard a guard is how the next person trusts it

## 7 — one ring under each soldier as it steps off the boat. The five land on ADJACENT tiles, because
## the free-tile search is a BFS out of the dock. Radius is pinned to exactly half a tile: 20 * 2 =
## 40, so two orthogonally adjacent rings touch and never overlap. At 26 px they overlapped by 12.
const LAND_RING_SEC := 0.40
const LAND_RING_R_PX := 20.0
const LAND_RING_WIDTH_PX := 2.0

## 8 — summon feedback, inside 100 ms because that is Swink's bound on input-to-response in a
## real-time game. ⚠ The refusal shake rides BOTH the box rect and the glyph position with the same
## offset: shake only the box and the text walks out of it, shake only the text and the box sits
## still, which reads as nothing having shaken.
const KEY_FX_SEC := 0.18
const KEY_REFUSE_SHAKE_PX := 4.0
const BERTH_FX_SEC := 0.25

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
## ⚠ THERE IS NO `Camera2D` IN THE TREE AND NONE MAY BE ADDED. The shell hit-tests dock clicks
## against absolute canvas rectangles, so a camera would break that arithmetic across the whole
## screen at once and silently falsify every px comment in this file. CAMERA_ZOOM stays unread.
## ⚠ THE OFFSET IS ASSIGNED TO `position`, NEVER `+=`. In the last game `+=` became the basis of the
## next frame's lerp and compounded roughly 9x, so a 28 px cap stopped nothing: 67.9 px at 60fps and
## 160.4 px at 144. Keep the unshaken position separately and assign.
const SHAKE_SEC := 0.30
const SHAKE_PER_DAMAGE_PX := 1.2      # damage 2 -> 2.4 px, the lion's 4 -> 4.8 px
const SHAKE_MAX_PX := 6.0             # also the width of the bare band a shake exposes, and the
                                      # size of the dock-click error if the shell fails to subtract
                                      # the offset — 6 px on a 40 px tile is 15% of its edge
const SHAKE_A_FREQ := 61.0            # deterministic `sin`: a random shake cannot be measured
const SHAKE_B_FREQ := 47.0

## The grid fills the viewport exactly, so any shake exposes bare ground at the edges. The terrain
## loop runs this many tiles wider on every side and paints the outside with COL_WATER DIRECTLY —
## `terrain_colour_of_char` takes a legend character and there is no legend outside the grid, so
## inventing one would put the island legend in two places.
const WATER_MARGIN_TILES := 1         # 34 x 20 = 680 tiles painted, up from 576

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


static func hp_bar_colour(filled: bool) -> Color:
	return COL_HP_FULL if filled else COL_HP_EMPTY


## Keyed by the island legend character in islands.gd, because the grid keeps passability as a
## byte and cannot tell water from a hole — both are impassable and they must not look alike.
## B, C and L are land with something standing on it, so they fall through to land.
static func terrain_colour_of_char(c: String) -> Color:
	match c:
		"~":
			return COL_WATER
		"#":
			return COL_HOLE
		"D":
			return COL_DOCK
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


static func berth_rect_px(berth_index: int) -> Rect2:
	var x := HUD_BERTH_ORIGIN_PX.x + berth_index * (HUD_BERTH_SIZE_PX.x + HUD_BERTH_GAP_PX)
	return Rect2(Vector2(x, HUD_BERTH_ORIGIN_PX.y), HUD_BERTH_SIZE_PX)


static func key_rect_px(slot_index: int) -> Rect2:
	var y := HUD_KEY_ORIGIN_PX.y + slot_index * (HUD_KEY_SIZE_PX.y + HUD_KEY_GAP_PX)
	return Rect2(Vector2(HUD_KEY_ORIGIN_PX.x, y), HUD_KEY_SIZE_PX)


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
