extends RefCounted
## **Every presentation constant is here. Do not put them anywhere else.**
##  Scatter them and the user cannot tune (v1 measured — the power doubled and 0 things changed on screen).
##
## **Values here are not a contract.** They may differ per client without the world diverging — they only touch the screen.
##  That is why this lives inside `src/view/` and is not a target of `net_determinism` (= the `src/sim/` folder scan).
##  v1 kept sim constants and presentation constants in one file split by `SIM-BLOCK` **text markers**,
##   and that file's own comment said "delete or add a marker and the net silently spins".
##   **Splitting by folder removed that device entirely.**
##
## Write shake amplitude in **integer px** — `snap_2d_transforms_to_pixel` is on, so the fraction is thrown away.
##
## **The sorting rule — split a new value with this.** What to ask is not the unit but
##  **"what did this value come from"**. There are three branches and the three move differently:
##   · **count · time · ratio** (`_RATIO`·`_FRAC`·`_ticks`·`_SEC`) -> unrelated to scale and tiles
##   · **values that came from the character · a tile · a blast** -> they follow tile size
##     (`STAFF_*` · `TRAIL_PX` · `bolt_px`·`flash_px` · `CHAR_BURN_PX`)
##   · **values that came from the viewport** -> they follow the viewport (the assembly window · HUD · `shake_px`)
##
## **Current state: tile 32px · viewport 1920x1080 · screen scale 1x** => the character is 32px on screen,
##  and 60x34 visible tiles fit the stage (64x36) into the screen.
##  **This is the spot where "a 32px world at 1x scale" looks odd** — raise the scale to 2x and the visible world
##   shrinks to 960x540, so **the stage goes off screen** (a static camera cannot follow). Hence 1x.
## Splitting by "the unit is cells, so leave it" **got it wrong once** — blasts, bolts and trails halved on screen.

const Tuning := preload("res://src/sim/sim_tuning.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
## `src/view/` may reference `src/actor/` (`net_layers`) — `character_view.gd` already uses
##  `Character` that way. Here it is used only as the **key** for per-kind art paths (`MONSTER_SHEETS` below).
const MonsterDefs := preload("res://src/actor/monster_defs.gd")
## Same allowance as `MonsterDefs` above — used by `staff_ring_tint`, which reads a circle's own state so the
##  decision can be driven by a net instead of living inside `_draw`.
const SpellCircle := preload("res://src/actor/spell_circle.gd")

# --- character ------------------------------------------------------
## **The body is one sheet, and state -> frame is the single table below.**
##  If adding a new state takes edits in **more than three places, the structure is wrong**:
##   (1) one frame in the sheet png (2) one row in the table below (3) one line of the condition that picks the state
##  (3) remains because the condition is not data but **logic** ("is it downed" is a branch that reads the character).
##
## **Art paths must exist only in this file.** `assets/` is **outside** `net_layers`' folder scan,
##  so **nobody barks** even when `src/sim/`·`src/actor/` reference `res://assets/...`. => **Held by discipline only.**
##
## It must be **far on the color wheel** from terrain (stone 0x5C574F · wood 0x6B4524) so the eye splits it instantly =>
##  the robe being a cold blue is not taste but that contract. **The worst case is on top of a sea of fire.**
##
## **The grounds for the deleted `CHAR_BODY`·`CHAR_TRIM`·`CHAR_TRIM_PX` now live inside the art.**
##  Those three existed because "**seeing the "feet" makes the moment of landing visible**", and verify-look confirmed
##  on a 32px square that "the bottom 6px band makes landing visible to the eye".
##  => **The hem must be split from the torso by brightness.**
##  Left as constants they become **false knobs nobody reads** — only the grounds are kept here, the values were deleted.
##  **Read this line first the next time a frame is drawn.** Draw the hem at the same brightness as the torso
##   and landing goes silently invisible on screen, and that is something the net cannot catch in principle.
const CHAR_SHEET := "res://assets/character/wizard_body.png"

## **One side of one frame in the body sheet (px). The single source of "art size" — not `Character.W_PX`.**
##  The two split apart: the collision box narrowed to **20px** (fixing the character floating off walls)
##  while the art frame stayed **32px**. Before the split, `Character.W_PX` alone carried both meanings,
##  and **shrinking only the box in that state slices the sheet in 20px units, throwing the character off entirely** — no error is raised.
##
## **This value is what holds the GDD's "make the character and tile thickness the same"** (the visible size).
##  Sheet frames are square, so this is the height too — `net_sprite` measures the sheet height with it.
const CHAR_CELL_PX := 32

## State ids. **These are not frame numbers** — frames come from the table below.
##  If the two coincidentally match, "read the table" and "use the id directly as the frame" become
##   **indistinguishable both on screen and in the net.** Right now walking is two frames, so that coincidence
##   is structurally absent (`CHAR_JUMP` 2 -> frame 3).
const CHAR_STAND := 0
const CHAR_WALK := 1
const CHAR_JUMP := 2
const CHAR_FALL := 3
const CHAR_DOWNED := 4

## The values are **frame numbers in the sheet**. One table row = one sheet frame.
## **Do not hardcode the frame count** — it comes out of `tex.get_width() / Character.W_PX`.
##  Hardcode it and the sheet, the table and the constant become **three places**, and when the three diverge
##  the screen draws the wrong frame with **no error raised**. `net_sprite` measures whether the table's frame
##  numbers are inside the sheet · whether their union is the whole sheet.
const CHAR_FRAMES: Dictionary = {
	CHAR_STAND: [0],
	CHAR_WALK: [1, 2],
	CHAR_JUMP: [3],
	CHAR_FALL: [4],
	CHAR_DOWNED: [5],
}

## **Airborne poses do not have their feet on the ground.** The art has the legs folded, so forcing them down
##  to the bottom row stretches the character vertically — measured: jump frame maxy 28 · fall frame maxy 29.
##  => `net_sprite`'s "the feet touch the bottom row" applies **only to states not in this list**.
## **This is the single source of that exception.** Write state names in the net too and there are two places,
##  and the day airborne poses grow only one of them follows.
## **Do not use this exception on a grounded frame** — a grounded frame whose feet do not touch makes the
##  character look like it floats above the terrain.
const CHAR_AIRBORNE: Array[int] = [CHAR_JUMP, CHAR_FALL]

## **The state of "standing" against a wall.** `net_sprite` measures "the collision box is not wider than the art" with this.
##  **It is not the complement of `CHAR_AIRBORNE`.** Downed is on the ground too but is **art lying sideways (width 28)**,
##   so measured as the complement the net stays green even with the box widened to 28 — that hole was confirmed
##   by measurement and this list was made.
##  So **do not put airborne or downed in here.** The moment you do, the contract "stop the character floating off walls"
##   silently loosens, and what has loosened nobody barks about.
## Growing the standing states (crouching, etc.) is **one line here** — state names are not written into the net.
const CHAR_UPRIGHT: Array[int] = [CHAR_STAND, CHAR_WALK]

## **The tick of the walk clock (px).** The clock is `character.x` itself — the frame changes once per this value.
##  **Do not accumulate `delta` into a separate clock.** The moment you do there are two clocks and
##   **"it stopped but the legs are moving"** happens (the same idiom as `invuln_left` being the blink clock).
## Grounds: movement 260px/s / 24px = **10.8 transitions per second** = 5.4 cycles per second on a 2-frame loop.
##  That is a fast gait suited to a character running at 8 tiles/s. **It is a feel value, so fix it by eye** —
##  the grounds have to be written here so the next person cannot undo it.
## Being pushed also looks like walking. **Chosen knowingly** — it beats sliding while standing still.
const CHAR_WALK_PX_PER_FRAME := 24

# --- monsters -------------------------------------------------------
## **A fallback color — the default is a sprite now** (`MONSTER_SHEETS` below).
##  **Do not delete it.** If texture loading fails, `monster_view` draws a rectangle of this color instead —
##  "a pink box" beats "nothing visible" (it reads as a breakage signal. `character_view._body_tex` is simply
##  left to bark with no null check, but monsters always have two or more kinds, so one breaking must still leave
##  the rest visible — that is why this side **substitutes instead of barking**).
##  The size is not here — it comes from `monster_defs.gd` (actor). Put it here too and the box table
##  becomes two, and the only symptom of divergence is "the pig floats 12px off the wall" (the `monster_view` box above).
## It must be far on the color wheel from terrain (stone · wood) · fire (orange) · water (cyan) so the eye splits
##  it instantly — a red purple was chosen.
##  **Per-kind colors are still untouched** — a team-lead instruction: that is the user's place to decide.
const MONSTER_FILL := Color(0.78, 0.22, 0.42, 1.0)

## **Body art — one image per kind. The standing pose, and now the fallback.**
##
## **`MONSTER_ANIM` below is what actually gets drawn.** This table is what is left when that one cannot
##  answer: a kind with no animation row, a sheet that failed to load, or a draw that happens before any
##  animation state exists (which is how the nets stand `monster_view` up). **Do not delete it** for the same
##  reason `MONSTER_FILL` above is kept — the layers of substitution are what keep one broken png from
##  emptying the screen.
## Growing a new kind is one line here + one line in `monster_defs.gd` (+ a row below to animate it).
##
## **The art size is the box size** (`monster_defs.w_px/h_px` — 44x32 · 24x28) — **not a coincidence.**
##  The pixel artist drew to the box. **Even so `monster_view` does not trust this art's actual pixel size** —
##  it draws with the size read from `Defs` (if the two diverge the art looks stretched but still fits
##  the box). `net_monster_sprite` measures "right now they are the same" by value, so the day they diverge it is caught at once.
const MONSTER_SHEETS: Dictionary = {
	MonsterDefs.KIND_PIG: "res://assets/monster/pig_body.png",
	# **`hen_*`, not `chicken_*`.** The design item is 닭 and the art is a hen — "the name follows the mob,
	#  not the art" (`monsters.md`). The old 24x28 `chicken_*.png` set is left on disk and referenced by
	#  nothing; it is the small art the enlargement replaced, kept rather than deleted because it is what the
	#  user approved once and the size question could still swing back.
	MonsterDefs.KIND_HEN: "res://assets/monster/hen_body.png",
	MonsterDefs.KIND_BULL: "res://assets/monster/bull_body.png",
	MonsterDefs.KIND_ROOSTER: "res://assets/monster/rooster_body.png",
	MonsterDefs.KIND_WOLF: "res://assets/monster/wolf_body.png",
}

# --- monster animation ----------------------------------------------
## **State ids — the same idiom as `CHAR_STAND`..`CHAR_DOWNED` above, and for the same reason.**
##  These are **not** frame numbers and **not** `BossAi.Pattern` values. A pattern is what the sim is doing;
##  a state here is what is on screen, and the two are deliberately not the same set — `Pattern.WINDUP`
##  maps to a roar, `Pattern.GORE` and a pig's body shove both map to `MON_ATTACK`, and `MON_HURT` has no
##  pattern behind it at all (it comes from the hp diff the view already keeps).
##  **Reuse `Pattern` here and the table stops being able to hold a trash mob**, which has no patterns.
const MON_IDLE := 0
const MON_WALK := 1
## The pig's body shove · the hen's spit · the bull's gore. **One state, three sheets** — they are the same
##  sentence on screen ("it is hitting me right now"), so splitting them would only make the table wider.
const MON_ATTACK := 2
const MON_HURT := 3
const MON_DEATH := 4
## The boss telegraph — `Pattern.WINDUP`. Draws the roar sheet, **underneath** the red attack prediction
##  (`ATTACK_PREDICT_COLOR`); the two say the same thing in two vocabularies and neither replaces the other.
const MON_WINDUP := 5
const MON_CHARGE := 6
const MON_FIRE := 7
## The bull's slam and the rooster's leap — both are `Pattern.LEAP` (`boss_ai.gd`'s own header: one physics,
##  two moves), so they are one state here too, resolved to a different sheet by kind.
const MON_LEAP := 8
const MON_STUN := 9
## **The trash-mob jump** (`monster-ai-jump-and-separation.md`, Stage B) — `on_ground ==
##  false` for a pig/hen/wolf, resolved by `monster_view.resolve_state`. **No boss row exists or is planned**
##  (`bull_slam`/`rooster_leap` already cover the only airborne thing a boss does, through `MON_LEAP` above) —
##  see that function's own comment for what an idle boss falling actually draws instead.
const MON_AIRBORNE := 10

## **kind -> state -> one sheet.** A sheet is one horizontal row of equal frames, `Defs.w_px` wide each —
##  the same layout as `CHAR_SHEET`, which is why `tools/pixel/anim_sheet.py` writes them this way.
##
## **`frames` is written down and not derived from the png width.** Deriving it would make a truncated or
##  half-imported sheet silently play a shorter loop; written down, `net_monster_sprite` compares the two and
##  the divergence goes red. That is the opposite call from `CHAR_FRAMES` (which lists frame *numbers*, so the
##  count is implicit there) and the reason is the same one that file gives — the single source has to be
##  somewhere a net can read it.
##
## **`hold` is view frames per animation frame.** 60Hz, so `hold: 4` is 15 animation fps.
##
## **Idle is 20 and the one-shots are 3-5, and that gap is the point.** Idle ran at 8 and every standing
##  monster cycled its whole loop **1.5 to 1.9 times a second** — the user's word for a screen holding several
##  of them was 어지럽다. At 20 a 4-frame loop is 0.75/s and a 5-frame loop 0.6/s, which is breathing rather
##  than twitching. A hit, a death or a gore is a **one-shot** and stays fast: it has to finish inside the
##  window it reports on, and `oneshot_frames` (`frames * hold`) is what latches it open, so raising those
##  holds would stretch invulnerability's own picture past invulnerability.
##  **It is a feel value, so it is fixed by eye** — the grounds are written here so the next person does not
##  quietly walk it back.
## **`loop: false` holds the last frame** instead of wrapping — that is what makes a death or a gore read as
##  finished rather than as a stutter.
##
## **A missing state is not an error — it falls back to `MON_IDLE`** (`monster_view.resolve_state`).
##  The bull and the rooster have no `hurt` sheet, and a boss that visibly flinched at every bolt would
##  undercut exactly the thing `stage1-bosses.md` is trying to build. **Do not "fill the table in" for its
##  own sake.**
##
## **The walk clock is not `hold`** — it is `MONSTER_WALK_PX_PER_FRAME` below, for `character_view`'s reason:
##  two clocks means "it stopped but the legs keep moving".
const MONSTER_ANIM: Dictionary = {
	MonsterDefs.KIND_PIG: {
		MON_IDLE: {"path": "res://assets/monster/pig_idle.png", "frames": 4, "hold": 20, "loop": true},
		MON_WALK: {"path": "res://assets/monster/pig_walk.png", "frames": 9, "hold": 4, "loop": true},
		MON_ATTACK: {"path": "res://assets/monster/pig_shove.png", "frames": 8, "hold": 4, "loop": true},
		MON_HURT: {"path": "res://assets/monster/pig_hurt.png", "frames": 4, "hold": 3, "loop": false},
		MON_DEATH: {"path": "res://assets/monster/pig_death.png", "frames": 8, "hold": 4, "loop": false},
		# **`hold` in [3, 8], start at 4** (`monster-ai-jump-and-separation.md`, Stage B) — `frames * hold`
		#  (12) must fit inside the real airtime or the pose never reaches its last cell, the same failure
		#  `_hurt_left` was split from `_flash_left` to avoid. `net_monster._the_airborne_sheet_fits_inside_
		#  the_real_airtime` measures the real airtime driven, not estimated. **Not decided on screen yet.**
		MON_AIRBORNE: {"path": "res://assets/monster/pig_jump.png", "frames": 3, "hold": 4, "loop": false},
	},
	# **`throw`, not `spit`** — `monsters.md`'s "the chicken throws an egg" (decided by the user), and the
	#  enlarged set is drawn that way. The projectile itself is still the old dot; only the animation says egg.
	MonsterDefs.KIND_HEN: {
		MON_IDLE: {"path": "res://assets/monster/hen_idle.png", "frames": 4, "hold": 20, "loop": true},
		MON_WALK: {"path": "res://assets/monster/hen_walk.png", "frames": 8, "hold": 4, "loop": true},
		MON_ATTACK: {"path": "res://assets/monster/hen_throw.png", "frames": 8, "hold": 4, "loop": false},
		MON_HURT: {"path": "res://assets/monster/hen_hurt.png", "frames": 4, "hold": 3, "loop": false},
		MON_DEATH: {"path": "res://assets/monster/hen_death.png", "frames": 8, "hold": 4, "loop": false},
		MON_AIRBORNE: {"path": "res://assets/monster/hen_jump.png", "frames": 3, "hold": 4, "loop": false},
	},
	MonsterDefs.KIND_BULL: {
		MON_IDLE: {"path": "res://assets/monster/bull_idle.png", "frames": 5, "hold": 20, "loop": true},
		MON_WALK: {"path": "res://assets/monster/bull_walk.png", "frames": 9, "hold": 4, "loop": true},
		MON_WINDUP: {"path": "res://assets/monster/bull_roar.png", "frames": 8, "hold": 4, "loop": false},
		MON_CHARGE: {"path": "res://assets/monster/bull_charge.png", "frames": 9, "hold": 3, "loop": true},
		MON_ATTACK: {"path": "res://assets/monster/bull_gore.png", "frames": 17, "hold": 3, "loop": false},
		MON_FIRE: {"path": "res://assets/monster/bull_fire.png", "frames": 9, "hold": 4, "loop": true},
		MON_LEAP: {"path": "res://assets/monster/bull_slam.png", "frames": 17, "hold": 3, "loop": false},
		MON_STUN: {"path": "res://assets/monster/bull_stun.png", "frames": 7, "hold": 5, "loop": true},
		MON_DEATH: {"path": "res://assets/monster/bull_death.png", "frames": 7, "hold": 5, "loop": false},
	},
	MonsterDefs.KIND_ROOSTER: {
		MON_IDLE: {"path": "res://assets/monster/rooster_idle.png", "frames": 5, "hold": 20, "loop": true},
		MON_WALK: {"path": "res://assets/monster/rooster_walk.png", "frames": 9, "hold": 4, "loop": true},
		MON_WINDUP: {"path": "res://assets/monster/rooster_roar.png", "frames": 8, "hold": 4, "loop": false},
		MON_LEAP: {"path": "res://assets/monster/rooster_leap.png", "frames": 9, "hold": 4, "loop": false},
		# The landing recovery **is** `Pattern.STUN` (`boss_ai.gd`'s own header: one field is the window to
		#  hit for both), so the land sheet goes in that slot rather than getting a state of its own.
		MON_STUN: {"path": "res://assets/monster/rooster_land.png", "frames": 7, "hold": 5, "loop": false},
		MON_DEATH: {"path": "res://assets/monster/rooster_death.png", "frames": 7, "hold": 5, "loop": false},
	},
	# **The lunge sits in `MON_ATTACK`, the same slot the pig's shove uses** — and it is driven by the same
	#  contact condition, because the wolf has no lunge in the sim (`monster_defs.KIND_WOLF`'s own box).
	MonsterDefs.KIND_WOLF: {
		MON_IDLE: {"path": "res://assets/monster/wolf_idle.png", "frames": 4, "hold": 20, "loop": true},
		MON_WALK: {"path": "res://assets/monster/wolf_walk.png", "frames": 8, "hold": 3, "loop": true},
		MON_ATTACK: {"path": "res://assets/monster/wolf_lunge.png", "frames": 8, "hold": 3, "loop": false},
		MON_HURT: {"path": "res://assets/monster/wolf_hurt.png", "frames": 4, "hold": 3, "loop": false},
		MON_DEATH: {"path": "res://assets/monster/wolf_death.png", "frames": 8, "hold": 4, "loop": false},
		MON_AIRBORNE: {"path": "res://assets/monster/wolf_jump.png", "frames": 3, "hold": 4, "loop": false},
	},
}

## **The tick of the walk clock (px)** — the monster's own `x`, exactly as `CHAR_WALK_PX_PER_FRAME` uses the
##  character's. One value for every kind on purpose: the kinds already move at different speeds
##  (`monster_defs.speed_px` 140..220), so **the same px tick gives each of them a different cadence for free**,
##  and a fast hen's legs blur while a heavy bull's do not. Add a per-kind column and that falls out of the
##  speed table into a second place that can disagree with it.
## 16px at the pig's 160px/s = 10 frames/s over a 9-frame loop = **1.1 gait cycles/s**, and at the wolf's
##  240px/s = 15 frames/s over 8 frames = **1.9**. **It was 12**, which put the same span at 1.5 to 2.5 — the
##  fast kinds were running, not walking, and it landed in the same complaint the idle hold above records.
##  The whole table moves with one number **by design** (the paragraph above), so the wolf stays the fastest
##  gait on screen; what changed is where the band sits.
## **Being shoved counts as walking** — the same knowing choice `CHAR_WALK_PX_PER_FRAME` records.
const MONSTER_WALK_PX_PER_FRAME := 16

## **How close the player has to be for a pig to play its shove** (px, added to both boxes before the overlap
##  test). **The pig has no attack state in the sim** — it damages by body contact
##  (`world_step._boxes_overlap`), so there is no notification to hang this on and the view asks the same
##  question the damage code asks, one step early.
## **Early on purpose**: at 0 the shove would start on the frame the hit already landed, so the animation
##  would be a *report* rather than a *tell*. 8px at 160px/s is 0.05s of warning — not a dodge window, just
##  enough that the picture and the hit are not the same frame.
const MONSTER_SHOVE_REACH_PX := 8

## **The health bar above the head.** Width and position come from `monster_defs.w_px` (the box) — hardcode
##  a width here and it is exactly the "size in two places" trap above (`monster_view.hp_bar_rect` reads the box).
##  Only the height, the gap and the colors are here.
const MONSTER_HP_BAR_H_PX := 4.0
## Lifted this far above the top of the box — at 0 the health bar overlaps the head and mixes with the body color.
const MONSTER_HP_BAR_GAP_PX := 6.0
const MONSTER_HP_BAR_BG := Color(0.08, 0.08, 0.08, 0.85)
## Green when full · red when empty — linearly interpolated by hp ratio (`Color.lerp`, `monster_view._draw_hp_bar`).
const MONSTER_HP_BAR_FULL := Color(0.25, 0.85, 0.30, 1.0)
const MONSTER_HP_BAR_EMPTY := Color(0.9, 0.15, 0.15, 1.0)

## **Flash on hit — fills the body art's silhouette with white** (this fixed acceptance 13).
##
## **It was originally "a translucent white rectangle over the body" and it failed on screen** — the rectangle
##  **covered the sprite entirely** and read as "a shape is blinking". **The value of attaching sprites was cut in half right there.**
## **It is a shader now** — `monster_silhouette.gdshader`. That file's head wrote down "why vertex color and not
##  a uniform" (a uniform is per node, so several monsters cannot flash at different intensities).
##
## The frame count was matched to invulnerability (`monster_defs.invuln_ticks`, 2 ticks = 0.1s at 20Hz) —
##  "while it flashes, that one hit is still in effect" overlaps naturally.
## **The rgb goes into the shader's `flash_color` uniform, and the alpha is the maximum intensity** — both live.
##  **Color being a uniform and intensity being vertex color is no coincidence**: the color is the same for every
##   monster but the intensity differs per monster, and a uniform is per node so it **cannot hold different intensities in principle.**
const MONSTER_FLASH_COLOR := Color(1.0, 1.0, 1.0, 0.85)
const MONSTER_FLASH_FRAMES := 6
## **The flash and the outline use the same shader** — both are "a silhouette in one flat color" (that file's head).
const MONSTER_FLASH_SHADER := "res://src/view/monster_silhouette.gdshader"

## **The outline — decided by the user.**
##
## **Why**: verify-look stood a pig against a **black sky background** and **its legs and belly melted.**
##  The dark reddish brown of the four legs was too close in brightness to the background, so **the individual
##  legs were invisible, a smeared blob**, and the underside of the hind legs almost vanished.
##  The only recognizable part was **the white tusks**.
##  **Against terrain it is invisible** — that is why the two earlier acceptances missed it.
##
## **It is drawn at runtime, not baked into the png** — the user chose that axis. **It applies to every monster
##  at once and no asset has to be regenerated.** The value is that growing monsters requires no memory of the process.
##
## **It is a bright color. That is the opposite of the pixel-art convention (a dark outline), and it was inverted knowingly.**
##  The problem right now is **"dark pixels stick to a black background"**, so a dark border fixes nothing.
##  **This is a place to look at again once a background lands** (`docs/design/background.md`) — the current
##   "black sky" is not a background but **the color of the empty material**, and once art is laid there the
##   direction of the contrast changes.
const MONSTER_OUTLINE_COLOR := Color(1.0, 0.93, 0.82, 0.9)

## Outline thickness (px). At 1 it is only visible at 4x zoom and nearly absent at 1x — the screen scale is 1.
const MONSTER_OUTLINE_PX := 2.0

## **Eight directions. With four it breaks along diagonal edges** — a slanted silhouette like a pig's leg
##  is exactly that place. It costs 8 more `draw_texture_rect` per monster (160 for 20 monsters).
##  **Nobody measured it.** Look at it together when acceptance 14 (cost) is measured again.
const MONSTER_OUTLINE_DIRS: Array[Vector2] = [
	Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
	Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1),
]

## Damage numbers — they rise above the spot that was hit and fade. `monster_view` reads the value straight
##  from the hp delta (the values here are only color · size · movement — the number itself is not made here).
const MONSTER_DMG_NUM_COLOR := Color(1.0, 0.35, 0.25, 1.0)
const MONSTER_DMG_NUM_SIZE := 14
const MONSTER_DMG_NUM_RISE_PX := 24.0

## **The height the number starts at — it floats above the health bar.**
##  **verify-look caught it on screen**: forcing the numbers to draw **covered the right half of the health bar.**
##   It originally started at `m.y` (the top of the box), and **the health bar is right there** (`hp_bar_rect`).
##  **Derive it from the health bar's height and gap — do not hardcode the number.** If the three drift apart
##   the number covers the bar again the day the bar is thickened, and **no error is raised.**
const MONSTER_DMG_NUM_LIFT_PX := MONSTER_HP_BAR_GAP_PX + MONSTER_HP_BAR_H_PX + 4.0
const MONSTER_DMG_NUM_LIFE_FRAMES := 36

## **Hit the same monster again within this many frames and the numbers are merged** (decided by the user).
##
## **Why**: on screen three `-10`s overlapped and **looked like `-1000`, covering the health bar too.**
##  **The problem was not that there were three numbers but that the three overlapped in the same spot** —
##   merged, **a flurry reads as "one heavy hit", which actually makes the hitting feel better.**
##
## **It must be shorter than `MONSTER_DMG_NUM_LIFE_FRAMES` (36).** Equal and **the numbers merge into one forever** —
##  while hits keep landing the age keeps rewinding and it never grows old. 12 is 0.2s (60Hz), the spot where
##  **a flurry (invulnerability 2 ticks = 6 frames apart) is bound and separate attacks are not.**
const MONSTER_DMG_NUM_MERGE_FRAMES := 12

## **The hen's bolt — it must split from magic bolts. The yardstick was changed.**
##
## **The original yardstick was "make it continue from the monster color (purple)", and that was the cause of the failure** —
##  purple-pink **did not split from the none-element magic trail (violet)** and read on screen as "my own bolt is coming at me".
##  **Acceptance 13 wrote right there that "the yardstick was wrong — measure by distance from the magic trail, not by the monster color".**
##
## **A spot that is genuinely empty on the color wheel was chosen — acid lime (~90°)**:
##
##      fire 30° · water 190° · none 258°   <- the three magics
##      damage numbers 8° · death pop 44° · cell fire 15-40°
##      magenta 300° = `ELEM_FX_MISSING`'s scream color, so it **must not be used**
##
##  => **80-110° is entirely empty.** It is 30° from the health bar green (120°) but **it is in a different place**
##   (the health bar is a 4px bar above the head, the bolt is a flying dot) — and the lime side is yellower.
##
## **Color alone was not enough — it is drawn in two layers.** The original pink (343°) and violet (258°) were
##  **85° apart and still got confused.** The bolt is small and fast and the trail is additively composited so it
##  blooms bright, so **when brightness and saturation are close the hue difference is invisible.**
##  => It uses the **same grammar** as a magic bolt (glow + core) with a different color — "the same grammar in a
##  different color" reads far faster than "a different color".
const MONSTER_BOLT_COLOR := Color(0.45, 0.85, 0.15, 1.0)
## The core — brighter and yellower than the glow. Without it it becomes "a green dot" and lumps in with the health bar family.
const MONSTER_BOLT_CORE := Color(0.85, 1.0, 0.55, 1.0)
const MONSTER_BOLT_R_PX := 4.0
## The core's radius ratio. Above 0.5 the glow is left as a border only and the two layers do not read.
const MONSTER_BOLT_CORE_FRAC := 0.45

## **The bull's fire breath (`stage1-bosses.md` Stage D) reuses `FIRE_LO`/`FIRE_HI` for its glow/core** —
## no new colors declared. "It is burning in that fire" already connects the body-attached flame
## (`MONSTER_BURN_*`, above) to ground fire through these same two constants; the bolt on its way there
## uses the same pair so all three read as one material rather than three unrelated oranges. Same shapes
## (`MONSTER_BOLT_R_PX`/`MONSTER_BOLT_CORE_FRAC`) as the hen's bolt — only the two colors swap per kind.

## The corpse afterimage — it stays briefly where the monster died, darker than the body color, then fades.
##  **The grid is untouched** (`monsters-minimum` "on death" — there is no corpse cell). `monster_view._corpses` ages it.
##
## **A fallback color — corpses are sprites now too** (this fixed the acceptance 13 failure).
##  **Originally a rectangle of this color was the whole corpse, and on screen it read as "was a UI fragment left behind".**
##   On the same screen the body was a sprite and only the corpse was a shape, so **the contrast was brutal.**
##  => Now the body art is laid down darkened by `MONSTER_CORPSE_DIM` and faded. This color is used
##   **only when there is no texture** (the same idiom as `MONSTER_FILL`).
const MONSTER_CORPSE_COLOR := Color(0.35, 0.10, 0.19, 0.9)
## **30 -> 60 when the death animation went in.** The corpse is now the `MON_DEATH` sheet played through, and
##  the longest of those runs 35 view frames (pig, 8 frames x `hold` 4) — at 30 the beast was still mid-fall
##  when the whole afterimage had already faded out, so **the animation could not be seen at all.**
##  The remainder is the pause on the last frame that makes "it is dead" land before the fade takes it.
##  **This value has to stay above every `MON_DEATH` row's `frames * hold`** — `net_monster_sprite` measures it.
const MONSTER_CORPSE_LIFE_FRAMES := 60

## How dark to lay the corpse down (a brightness multiplied into the body art). **At 0 it is a silhouette so kinds
##  do not split, and at 1 it reads as "a living monster standing there translucent."** The spot chosen keeps the
##  shape on a dark background while dropping "alive".
const MONSTER_CORPSE_DIM := 0.42

## **The ring that bursts at the moment of death** (decided by the user).
##
## **Why this is needed — the hen has zero hit feedback in principle.** It dies in one hit, so what
##  `monster_view._scan_hp_changes`' hp diff would look at is **already gone from the array.**
##  => Neither the flash nor the damage number **appears for a single frame.** It reads not as "it was hit" but as "it vanished".
## **So it hangs off the death notification, not hp** — that path is already used by the corpse so it is free
##  (`monster_view.on_tick`). => **Whatever the hp is, however many hits it takes, it appears exactly once.**
##
## **Shorter than the corpse (30 frames).** The pop has to clear first with the corpse left behind, so it reads
##  as "it burst and something was left".
const MONSTER_DEATH_POP_FRAMES := 10
## How far the ring spreads, as a multiple of the box radius. **At 1.0 it ends inside the body and is invisible.**
const MONSTER_DEATH_POP_SCALE := 2.1
const MONSTER_DEATH_POP_COLOR := Color(1.0, 0.86, 0.55, 0.95)
const MONSTER_DEATH_POP_PX := 3.0

## ══ Waking up (`left-run-clumps-and-platforms.md`, Screen) ══
## **A sleeping mob and a walking one were drawn identically** — `monster_view` never read `asleep`
## (grepped: zero hits in `src/view/`). With the clump layout a whole clump now stands there dormant
## before the player arrives, so "you can tell a clump woke up" is a requirement, not a garnish.
##
## **The doc offers A (tint) · B (a staggered mark) · C (a sleep pose) and says A and B compose.**
## **A+B is what shipped** — C is an art job (a sheet per kind) and the user has not picked.
##
## **A · tint.** A dormant body draws at this alpha. **Not a darker colour** — the sky here is near black
##  (verify-look measured bedrock 35,34,40 against sky 14,14,19), so darkening reads as "gone", while
##  alpha keeps the silhouette and its outline readable as "there, but not yet awake".
const MONSTER_ASLEEP_ALPHA := 0.45
## **B · the mark.** The same ring vocabulary as `MONSTER_DEATH_POP_*`, deliberately — copied rather than
##  reinvented so "something changed state" reads as one family. It **opens and fades**, the same two
##  motions together: opening alone reads as a leftover ring, fading alone reads as a blink.
const MONSTER_WAKE_MARK_FRAMES := 14
const MONSTER_WAKE_MARK_SCALE := 1.9
## **The ring's own starting radius, not the box's.** The death pop scales off the box because "this body
##  is gone" is about that body; a wake mark is a fixed-size notice, so six of them across a clump of
##  differently-sized animals read as one repeated symbol instead of six different circles.
const MONSTER_WAKE_MARK_R_PX := 9.0
const MONSTER_WAKE_MARK_COLOR := Color(0.62, 0.86, 1.0, 0.95)
const MONSTER_WAKE_MARK_PX := 3.0
## **How far above the box's own centre the mark sits.** On the box centre it is swallowed by the body;
##  above the head it reads as "this one just noticed you".
const MONSTER_WAKE_MARK_LIFT_PX := 10.0
## **The stagger** (the doc's own word: the clump wakes as a ripple, not as a switch). Frames of delay per
##  monster, applied in world-array order — which is spawn order, which is row order in
##  `stage1_monsters.ROWS`. **A whole clump stirring on one tick is the ordinary case**, not the rare one:
##  `world_step`'s sleep pass walks every monster inside one tick, so with no stagger six rings would pop
##  on the same frame and read as a single UI flash rather than as six animals waking.
const MONSTER_WAKE_STAGGER_FRAMES := 4

## **Fire stuck to the body — in several places** (this fixed acceptance 13. The design text said "several places").
##
## **It was originally one box border and read on screen as "an orange selection box".**
##  **And the ground fire on the same screen is real pixel fire, so the contrast was brutal** — one side was fire,
##   the other was UI emphasis. That is why the `CHAR_BURN` border idiom was abandoned for monsters only.
##  **The character (`CHAR_BURN`) is untouched** — that side has to split axes with the invulnerability dim, so the
##   border is a structural choice (that constant's comment). Monsters have no invulnerability dim.
##
## **The colors come from cell fire (`FIRE_LO`·`FIRE_HI`)** — "it is burning in that fire" has to carry over.
##  It is drawn in two layers: the outside is `FIRE_LO` (red), the core is `FIRE_HI` (yellow).
const MONSTER_BURN_FLAMES := 5
## **How many cells the flame tongues grow to.**
##  **It was originally `MONSTER_BURN_R_PX` (a circle's radius), and the circle was the problem** — verify-look
##   read it as **"five targets"**. The ground fire beside it is a mass of pixels, so the contrast stayed.
##  **A perfect circle is a shape that does not exist on this game's screen** — terrain, fire and water are all cells.
##   => However well the color is matched, a circle reads as "UI". **What was fixed was not the color but the vocabulary.**
## At 3 that is at most 12px — a bit over a third of the pig's box height (32px). Grow it further and it covers the body.
const MONSTER_BURN_TALL_CELLS := 3
## The wobble amplitude — at 0 **the fire freezes and reads as "five dots".** This value is what keeps the fire alive.
const MONSTER_BURN_WOBBLE := 0.42
## How many frames per cycle. The phase is offset per flame, so **they do not all jump together.**
const MONSTER_BURN_PERIOD_FRAMES := 14.0
## Cluster the flames toward the **bottom of the box** (0 = top, 1 = bottom). Scattered evenly over the whole body
##  it looks not like "it is burning" but like "glitter got stuck on" — fire rises from below.
const MONSTER_BURN_LOW_BIAS := 0.35

## The attack prediction (`docs/design/attack-prediction.md`) — **replaces** the wind-up "!" text tell
## (`stage1-bosses.md` Stage B, acceptance 3). The user's own words: the monster's attack should show
## **in red, as a prediction** — a mark on the ground saying *where it lands*, not a symbol above the head
## saying only *something is coming*. verify-look measured the old "!" at roughly one eighth of the bull's
## height at 1.0 zoom against the stun ring's full-body strength; this is sized and drawn to match the ring,
## not the symbol it replaces (`MONSTER_STUN_RING_*` below is the explicit model, unchanged).
##
## **Hue math, the same method `MONSTER_PHASE2_COLOR`'s own comment already used**: damage-number red sits at
## ~8°, terrain/monster fire at ~15-40°, the old telegraph orange at ~42° (now retired), the stun ring's cyan
## at ~185°, phase-2's indigo at ~230°, the reserved scream-magenta at 300°. **True red (~0-3°) is the one hue
## the user asked for**, and it cannot be rotated away from the damage number's own 8° the way phase-2 was
## free to pick 230° — the two are kept apart by **saturation and value instead**: the damage number is a
## light, desaturated coral (`Color(1.0, 0.35, 0.25)`); this is a near-pure, fully saturated red
## (`Color(0.95, 0.12, 0.12)`), and the two never share a vocabulary anyway (floating text vs. a ground mark).
const ATTACK_PREDICT_COLOR := Color(0.95, 0.12, 0.12, 0.5)   ## fill
const ATTACK_PREDICT_EDGE_COLOR := Color(0.95, 0.12, 0.12, 0.95)   ## outline — carries the pulse (below)
const ATTACK_PREDICT_EDGE_PX := 3.0   ## same weight as the stun ring's own outline
## FIRE's stream is drawn as a line this thick, centered on the bolt's own spawn height.
const ATTACK_PREDICT_LINE_PX := 8.0
## **Pulses, the same `sin()` shape `MONSTER_STUN_RING_*` already uses** — copied, not reinvented, so the two
## read as the same family of "an active warning" rather than two different animation languages.
## **Faster than the stun ring (30 frames)** — the shortest phase-2 windup is 0.4s (8 ticks), and a full pulse
## cycle has to complete inside that or the player only ever sees one static-looking half-cycle.
const ATTACK_PREDICT_PULSE_FRAMES := 12
const ATTACK_PREDICT_MIN_ALPHA_FRAC := 0.55
const ATTACK_PREDICT_MAX_ALPHA_FRAC := 1.0

## The stun indicator - the hit-back window (acceptance 3's other half). **A ring around the box, the same
## vocabulary `MONSTER_DEATH_POP_COLOR` already uses** for "a UI state, not a body" - a different color so
## "just died" and "stunned, hit it now" are never confused on screen.
const MONSTER_STUN_RING_COLOR := Color(0.3, 0.9, 1.0, 0.9)
const MONSTER_STUN_RING_PX := 3.0
## The ring pulses (grows/shrinks) so it reads as active feedback, not a fixed decal painted on the ground.
const MONSTER_STUN_RING_PERIOD_FRAMES := 30
const MONSTER_STUN_RING_MIN_FRAC := 0.85
const MONSTER_STUN_RING_MAX_FRAC := 1.15

## **Stage H's phase-2 tell** — `stage1-bosses.md`'s own open TBD ("phase transition presentation — what is
## visible at half health"), picked here as a first provisional answer, not yet the user's decision.
## **On the strong side of verify-look's own line, deliberately**: the old windup "!" text measured as a small
## orange dot at 1.0 zoom (that tell is retired — `ATTACK_PREDICT_*` above replaced it, ground-mark-sized to
## match this same strength); the stun ring measured well. This tell copies the stun ring's strength (a shape
## around the whole box, not a small icon) and goes one step further — **no blink, no pulse, just thick and
## always on** while the condition holds, so it cannot be missed the way a blinking or pulsing state can be
## caught mid-off.
## **Strong indigo/blue, ~230° hue** — measured in degrees against everything else already meaning something
## on this screen, the same method `MONSTER_BOLT_COLOR`'s own comment documents: the (retired) telegraph
## orange sat at ~42°, replaced by the attack prediction's true red at ~0-3°; damage-number red (~8°),
## terrain/monster fire (~15-40°), the stun ring's cyan (~185°), the death pop's light orange (~44°), and the
## reserved scream-magenta (300°, `ELEM_FX_MISSING`, "must not be used"). ~230° sits clear of all of them,
## including a wide margin from the reserved 300° (the file's own header: "even 85° once got confused when
## brightness/saturation were close") — **and clear of the new red too**, the same 230° margin it always had
## from anything in the 0-40° band. **Verify-look confirmed this half works** — kept unchanged across the
## shape fix below and across the telegraph's replacement.
const MONSTER_PHASE2_COLOR := Color(0.35, 0.42, 1.0, 0.95)
## Thicker than the stun ring's 3.0 — a hit-back window (stun) only needs to be noticed for its own duration;
## a phase change needs to keep reading for the rest of the fight, so it earns the extra weight.
const MONSTER_PHASE2_OUTLINE_PX := 4.0
## Drawn outside the box, not flush with its edge — flush would sit directly on top of the outline shader
## (`MONSTER_OUTLINE_COLOR`) already hugging every monster's silhouette, and the two would blur into one line.
const MONSTER_PHASE2_MARGIN_PX := 3.0
## **The shape half, corrected — verify-look's own words: "a square outline around a sprite is what an editor
## draws when something is selected, so it carries no 'this thing got angrier' meaning".** A first version was
## a full `draw_rect` outline; `monster_view.gd`'s own header already recorded this exact mistake once for body
## fire ("an orange selection box", acceptance 13) — a second rectangle repeating it on the same screen was a
## real, avoidable regression, not a new discovery. **Corner brackets instead** (four right-angle marks, like a
## camera/target reticle) — not a rectangle (the middle of each edge is deliberately empty, which is exactly
## what a UI selection box never leaves out) and not the stun ring's circle, so the two states cannot be
## confused at a glance. This is the arm length of each bracket mark, drawn from the grown box's own corners.
const MONSTER_PHASE2_BRACKET_ARM_PX := 12.0

# --- HUD text -------------------------------------------------------
## **A constant that had to be pinned down at the 32px transition. Before, it did not exist at all.**
##  `HUD/Stats`·`HUD/Health` are `Label`s and were using the engine's default font size (16), and
##  **screen scale 2.0 was implicitly making that 32px on screen.**
##  Coming into the 32px world the coordinates got x2 but **only the size did not follow, so the text halved on screen**
##  (a verify-look observation) => it was pinned to 32, and verify-look measured the ink and confirmed 32px on screen.
##
## **Do not delete it with "the engine default will do".** The day the scale changes the same accident happens again,
##  and it only looks like "the text is a bit small", so finding the cause takes a long time — the value of this
##  constant is that the place to fix it stays here, in one place.
## **It is not written in the `.tscn`.** Presentation constants live in one file, and writing it into the scene
##  makes two places that diverge — the shell (`stage.gd._ready`) pushes this value into the Label.
## The assembly window is not covered by this — `circle_window`'s three `draw_string`s already pass a size
##  (`WINDOW_TITLE_SIZE` · `PALETTE_HEAD_SIZE` · the layer number derived from the radius).
const HUD_FONT_SIZE := 16

## **The level-up indicator's color — a call to action, not a status.** `HUD/Stats`·`Health`·`Progress` are all
##  the engine's default white; a `Label` cannot mix colors within one string, so the indicator got its own
##  node (`HUD/LevelUp`) instead of living appended to `HUD/Progress`'s status line, and this is that node's
##  distinct `font_color` override (verify-look's own finding — appended in the same color and weight, it read
##  as legible but never drew the eye, and the plan's own risk is "the player carries a three-pick until the
##  run ends").
## **A warm gold** — reads as "reward", far from the plain white status text and from `CHAR_DOWNED_COLOR`'s red
##  (danger) on the same screen.
const LEVEL_UP_COLOR := Color(1.0, 0.82, 0.25, 1.0)

## **Invulnerability being visible is the only way to say "you cannot be hit right now"** (design "screen").
##  **The blink clock is not here** — the parity of `character.invuln_left` (a tick counter) is the clock itself.
##   0.2s is 4 ticks, so it blinks twice. If the renderer makes its own clock there are two clocks, and
##   it blinks after invulnerability has ended, or the reverse.
## **It is not 0.** Erased completely it reads as "it vanished = did it die" — fading is what says "invulnerable".
const INVULN_DIM_A := 0.35

## **Text that floats above the character when downed** (decided by the user).
##
## **Verifiers got stuck three times even though the HUD already has a line meaning the same thing** —
##  when a pig closes in and it becomes `downed`, `_drain_queue` **throws the shot away entirely** while
##  nothing changes on screen, so it **reads as "the click was swallowed".**
## **Two reasons the HUD is not enough**: seeing the presentation means turning the HUD off (the debug text
##  covers the monsters), and **the gaze is on the character.** => **The text was moved above the character's head.**
##
## **"R" is written on purpose** — you are alone and there is nobody to pick you up, so **a reset is the only way out.**
##  Without it it reads as "the game froze" (`stage._update_hud` gives the same reason).
const CHAR_DOWNED_TEXT := "쓰러짐 — R"
const CHAR_DOWNED_COLOR := Color(1.0, 0.35, 0.30, 1.0)
const CHAR_DOWNED_SIZE := 14
## This far above the head. At 0 the text overlaps the body and neither reads.
const CHAR_DOWNED_LIFT_PX := 10.0

## A burning character. **It is a border** — tinting the torso color uses the same axis as the invulnerability dim
##  above (torso brightness), so the two erase each other when they overlap. That overlap is not an exception:
##  **fire is not gated by invulnerability**, so "burning while invulnerable" is normal, and the screen has to be
##  able to say both **at once**.
## It is the same family as cell fire (`FIRE_HI`) so "it is burning in that fire" connects at a glance.
## **The thickness was x2'd** (2.0 -> 4.0). Its meaning is "the border is this thick on screen", so it falls in the scale branch.
##  **If the meaning changes in stage 5 it has to be decided again** — there it becomes an **integer offset in px**
##   that pushes the silhouette, and then it could move over to the "cell-relative" side. The design wrote "keep 2" in that spot.
const CHAR_BURN := Color(1.0, 0.55, 0.15, 0.95)
const CHAR_BURN_PX := 4.0

# --- the staff ------------------------------------------------------
## Staff rotation is **on the screen side, so float is free.** Only at **that one moment of firing**
##  does `src/actor/aim.gd` quantize it to integers.
##
## **The length (`STAFF_LEN_PX`) is not here — it moved to `LEN_PX` in `src/actor/staff.gd`.**
##  The first line of this file says "values here only touch the screen", but that value reached
##   **the world** through `character_view` -> `stage` -> `aim.fire_cmd`, and with the rule of shortening against
##   terrain layered on, the mismatch became load-bearing. `src/actor/` **cannot read this file**
##   (`net_layers` blocks it) => it was either pass it as an argument or move it, and moving was right.
##  **"Every presentation constant is in fx_tuning" is not broken** — the argument above is that the moved value is not presentation.
##
## **`STAFF_COLOR`·`STAFF_WIDTH_PX` were deleted — the line became art.**
##  The deleted color (0.55, 0.40, 0.24) was **exactly the wood terrain (0x6B4524).** The sheet below being
##   a dark red purple is not taste but the contract "it must be far on the color wheel from terrain so the eye splits it instantly".
##
## **Art paths must exist only in this file** (the same discipline as `CHAR_SHEET` above).
##  `assets/` is **outside** `net_layers`' folder scan, so nobody barks.
const STAFF_SHEET := "res://assets/character/wizard_staff.png"

## **The height at which "the staff's axis" sits inside the art (px). Measured y 1-8 => 4.5.**
##  The centerline of the shaft · the center of the ring · the center of the bbox are **all three here** =>
##  seating the art at this height means **a 180° rotation (= aiming left) leaves the silhouette unchanged.**
##  Swap in art where those three are misaligned and **the staff floats above the shoulder only when looking left.**
##  `net_sprite` measures whether the bbox's y center is this value — the net bites instead of a person remembering.
const STAFF_ANCHOR_Y_PX := 4.5

## **The right-side width the ring at the tip occupies (px). Measured x 29-35 => 7.**
##  **Only the shaft is shortened and the ring is attached at the end at its original size** — scaling the whole
##  art on x **squashes the ring into an ellipse** when the staff is compressed, and the color ring (a true circle)
##  laid on top no longer fits.
## **Do not make an art-width constant here.** The length is `Staff.LEN_PX` alone —
##  put a width here too and "png 36 · length 36 · width constant 36" becomes three places, and the day they diverge
##  **the tip floats outside the art with no error raised** (a trap `net_sprite` wrote down in advance).
const STAFF_RING_W_PX := 7.0

## **The ring at the tip is tinted with the equipped color — what is equipped is visible before firing** (design "screen").
##  Without this the staff is a single image in a constant color, so **changing the assembly changes not one pixel on screen.**
##
## **It cannot be carried by `modulate` — that is why the ring is drawn on top.**
##  `CanvasItem.modulate` is **multiplication**, so with the shaft a dark red purple (~0.4,0.1,0.2), multiplying by
##  cyan gives `(0.18, 0.085, 0.20)` — **almost no change.** And this node has no material, so additive blending is out too.
##  => **The tint has to overwrite pixels** = draw one **empty ring** that overlaps exactly where the ring is in the art.
##
## **Deleting the muzzle bead removed "size", one of the two axes. It was deleted knowingly** (user acceptance:
##  "delete the muzzle bead. I don't like it. Just coming out of the staff would be better").
##  **Write down exactly what was lost: the difference between adding and removing a glyph is invisible on screen before firing.**
##   What the color carries is **the innermost glyph**, so "spread->blast" and "spread" are the same color.
##  **The order (key 4 <-> key 5) is still carried by color** — the place where the GDD wrote "if the order is
##   invisible on screen the player can never learn the rule" is **not broken.**
##  => **If you want it back, find an axis other than size** (ring thickness · ring count · tip brightness).
##   Growing the radius here by layer count misaligns it with the ring in the art and **the ring goes outside the art.**
##
## All four values come from the section 0-(1) measurement (ring x 29-35 · height 8px · width 7px · wall thickness 2px).
##  **Alignment is a place for the eye** — the net cannot measure in principle whether the ring looks aligned with the art's ring.
const STAFF_RING_INSET_PX := 4.0
const STAFF_RING_R_PX := 3.5
const STAFF_RING_PX := 2.0

## The tip color per glyph. **One new glyph = one line here** (the plan's "one line in fx_tuning if the presentation differs").
## If it is empty (no glyph) it falls back to the rune color — `staff_tint` below.
##
## **Rarity does not get its own color here** — every rarity of one family shares its family's color
##  (`RARITY_TINT` below carries rarity as a separate device, the same "two independent devices" idiom
##  `CIRCLE_RING_INNER`/`OUTER` already uses for "innermost first"). Splitting color by rarity too would mean
##  the staff tip alone has to carry **two** axes (which family · which rarity) in one hue, and nine ids would
##  need nine distinguishable colors instead of three.
const GLYPH_TINT: Dictionary = {
	# Spread and blast must be **far apart on the color wheel** so the staff tip for key 4 (spread->blast) and
	#  key 5 (blast->spread) split at a glance. The layer counts are the same, so **only the color carries the order.**
	Glyph.SPREAD_C: Color(0.45, 0.85, 1.0),
	Glyph.SPREAD_R: Color(0.45, 0.85, 1.0),
	Glyph.SPREAD_U: Color(0.45, 0.85, 1.0),
	Glyph.BLAST_C: Color(1.0, 0.45, 0.15),
	Glyph.BLAST_R: Color(1.0, 0.45, 0.15),
	Glyph.BLAST_U: Color(1.0, 0.45, 0.15),
	# **Deliberately neutral — the dummy is not a decided glyph** (`glyph_defs.gd`'s header). Cyan (spread) and
	#  orange (blast) are both spoken for; this sits away from both and away from `DEAD_TINT`'s cool grey
	#  ("cannot fire") so a dummy on the staff tip never misreads as either.
	Glyph.DUMMY_C: Color(0.72, 0.66, 0.56),
	Glyph.DUMMY_R: Color(0.72, 0.66, 0.56),
	Glyph.DUMMY_U: Color(0.72, 0.66, 0.56),
}

## The color of a glyph with no definition. **Deliberately magenta** — grow the glyphs without growing this
##  and the screen screams (the same reason as `MISSING_RGB` in `cell_materials.gd`).
## **Ring and rune art, and the modulate is over-bright on purpose — measured, and the first value was
## wrong in the wrong direction.**
##
## **The measurement**: `ring_*.png` and `rune_*.png` are strokes at **RGB(26,24,22)** on transparent — very
## nearly black. `WINDOW_BG` is **(13,14,22)**. So the art is barely 11 red above the panel it sits on, and
## verify-look duly reported the newly added picture as **the least visible thing in the window**, with the
## two thin procedural rims outside it reading fine.
##
## ⚠ **A cream modulate under 1.0 made it worse, not better.** `draw_texture_rect`'s modulate **multiplies**:
## (26,24,22) x (0.93,0.89,0.78) = **(24,21,17)**, darker than the raw art. The first version of this
## constant did exactly that while its own comment claimed it was the fix.
##
## **`socket_glyph_*.png` is white (255,255,255)**, which is why the same trick works there and is why the
## two were wrongly assumed to behave alike — white x tint = tint, black x tint = black.
##
## ⇒ **Components above 1.0.** The multiply happens before the framebuffer clamps, so >1 genuinely
## brightens; `GATE_TAKE_TINT`'s own comment already relies on exactly this ("what produces the flare is
## that the mid-tones do not clamp"). x7.88/8.17/7.73 lands the strokes at **(204,196,170)**, cream, against
## a (13,14,22) panel.
##
## **This is not a shader case.** `monster_view._draw_outlines` records that modulate "never brightens" —
## true for what *it* needs, which is a **flat** colour regardless of the source pixel. Scaling one dark
## tone up is ordinary multiplication and needs no material and no child node.
const CIRCLE_ART_TINT := Color(7.88, 8.17, 7.73)

## ══ The donut fit — the rune sits **in** the ring's hole (the user: "도넛 모양으로 들어가는 것") ══
##
## **The seats were already right.** Measured: every band's `center` **is** its rune slot, for both the round
## circle and the triangle — `circle_layout` puts them at the same point. Nothing had to move.
## **What was wrong was the size**: the rune picture was drawn big enough that its own strokes ran under the
## ring's teeth, which verify-look saw as the orange bead having its lower edge eaten.
##
## **Measured off the art itself**, by opaque-pixel fraction per radius band:
##  · `ring_spread` ink runs r **0.30 → 0.70** of its half-size; `ring_blast`/`ring_dummy` start at **0.40**.
##    ⇒ **the tightest hole is spread's, 0.30.**
##  · `rune_fire` ink reaches **0.70** of its half-size (`rune_none` only 0.45 — fire is the binding one).
##
## At the triangle's real numbers (ring half 49.17, rune half 32.78) that gave ink **22.9** against a hole of
## **14.8** — overlapping for every one of the three rings. Drawing the rune at **0.62** of its seat radius
## gives ink **14.2** inside 14.8, and **12.9** inside 21.0 on the round circle.
##
## **This scales the picture only.** `rune_radius()` still sizes the click target, the empty-seat dead ring
## and the procedural bead — shrinking those would move where the player has to press.
const RUNE_ART_FRAC := 0.62

## The two measurements above, named so the net can assert the relationship rather than the two rects.
## **Re-measure both if the art is ever regenerated** — they are properties of the pictures, not choices.
const RING_HOLE_FRAC := 0.30
const RUNE_INK_FRAC := 0.70
const GLYPH_TINT_MISSING := Color(1.0, 0.0, 1.0)

## **Rarity — a ring drawn around the glyph symbol, independent of `GLYPH_TINT`'s family color** (the design
##  doc's "rarity must separate by color", provisional values: common grey-blue · rare violet · unique amber).
##  Common is deliberately close to neutral so the eye reads rare and unique as "lit up", not the reverse.
const RARITY_TINT: Dictionary = {
	Glyph.RARITY_COMMON: Color(0.62, 0.68, 0.78, 0.85),
	Glyph.RARITY_RARE: Color(0.62, 0.35, 0.92, 0.95),
	Glyph.RARITY_UNIQUE: Color(0.95, 0.74, 0.22, 0.95),
}
## How far outside the symbol's own radius the rarity ring sits (a ratio, so it grows with the symbol).
##  Sitting **on** the symbol would fight `GLYPH_TINT`'s color for the same pixels — the same trap
##  `GLYPH_SPAWN_ANGLE_STEP_FRAC`'s comment already measured for the spawn rays and the ring line.
const RARITY_RING_RATIO := 1.3
const RARITY_RING_PX := 1.5

## **The socket glyph art** (`triangle-circle-to-game.md` step 6) — glyph id -> path, drawn only inside a
##  **socket band** (`circle_window._draw_ring` only reaches this map when the band owns more than one
##  edge — a concentric band, the round circle's own shape, never does). The palette and the round circle's
##  own ring slot are untouched by this map; they keep drawing the procedural shape (`_draw_glyph`) —
##  "the palette's blast must not look different from the placed blast" is an argument about the **round**
##  circle's slot, and it still holds there. The socket band is a different seat, allowed to look different
##  from the palette on purpose.
##
## **"2/17" (`circle-rune-glyph.md`'s own "Implemented" line: "glyphs 2/17 (spread · blast)") counts by
##  family, not by id** — the 17 is that doc's whole planned glyph roster (`circle-art.md`: "with spread and
##  blast to draw, that is four images [2 families x 2 circle-size sets]. Open all 17 and it is 34" — the
##  multiplier there is circle-size, not rarity), and only two families are drawn. **One family = one image,
##  shared across its three rarity rows** — checked, not assumed: `levelup-and-three-picks.md`'s own decision
##  ("Rarity must separate by color") and this file's existing `GLYPH_TINT` (one color per family, all three
##  rarities) and `RARITY_TINT` (the ring is the *only* rarity-carrying device) already hold this exact rule
##  for the procedural shape; a texture per rarity would add a shape axis that rule was written to prevent.
##  The two `.png` files themselves carry this too — `socket_glyph_spread.png`/`socket_glyph_blast.png`,
##  named by family, no rarity suffix.
## **A glyph missing here is not an error** — `_draw_ring` falls back to the procedural symbol, which is
##  what keeps a socket circle drawable at all before the remaining families get art (`circle-art.md`,
##  "Unresolved"). Falling back to nothing would be this repo's signature fake (CLAUDE.md: "screen changes
##  but sim doesn't" — the model already knows a glyph sits there, and the screen would have to hide it).
## **The layer ring's own picture, by the glyph sitting on it.** Same shape and same discipline as
## `SOCKET_GLYPH_TEX` below: all three rarities of a family point at one file, and a glyph with no entry
## falls through to the procedural stroke rather than drawing nothing.
##
## **`ring_accel.png` and `ring_home.png` are on disk and are deliberately not here** — `glyph_defs` has
## nine ids (spread · blast · dummy, three rarities each) and **there is no accelerate or home glyph in
## code**. Wiring them to a family they do not belong to would be worse than leaving them unused; they are
## waiting for the glyph, not the other way round.
const RING_TEX: Dictionary = {
	Glyph.SPREAD_C: "res://assets/circle/ring_spread.png",
	Glyph.SPREAD_R: "res://assets/circle/ring_spread.png",
	Glyph.SPREAD_U: "res://assets/circle/ring_spread.png",
	Glyph.BLAST_C: "res://assets/circle/ring_blast.png",
	Glyph.BLAST_R: "res://assets/circle/ring_blast.png",
	Glyph.BLAST_U: "res://assets/circle/ring_blast.png",
	Glyph.DUMMY_C: "res://assets/circle/ring_dummy.png",
	Glyph.DUMMY_R: "res://assets/circle/ring_dummy.png",
	Glyph.DUMMY_U: "res://assets/circle/ring_dummy.png",
}

## **The palette card's own picture, by glyph.** Same shape and same fall-through discipline as `RING_TEX`
## above — three files carry nine ids, and an id with no entry drops back to the procedural symbol.
##
## **This is a separate map from `RING_TEX` and that is the whole reason it exists.** A ring is drawn at the
## layer band's diameter; a palette card's symbol radius is `PALETTE_SYMBOL_RATIO` of a cell's short side —
## **a ring shrunk to that size has no room to read as anything** (`circle-art.md`, "the icons exist because a
## ring cannot be a palette card"). Point this at `ring_*.png` and the cards go back to being mush.
##
## **Rarity is not in these files and must not be.** Three rarities share one picture here exactly as they do
## in `RING_TEX`; the tier is the ring `_draw_palette_rarity_ring` strokes outside the symbol.
const ICON_TEX: Dictionary = {
	Glyph.SPREAD_C: "res://assets/circle/icon_spread.png",
	Glyph.SPREAD_R: "res://assets/circle/icon_spread.png",
	Glyph.SPREAD_U: "res://assets/circle/icon_spread.png",
	Glyph.BLAST_C: "res://assets/circle/icon_blast.png",
	Glyph.BLAST_R: "res://assets/circle/icon_blast.png",
	Glyph.BLAST_U: "res://assets/circle/icon_blast.png",
	Glyph.DUMMY_C: "res://assets/circle/icon_dummy.png",
	Glyph.DUMMY_R: "res://assets/circle/icon_dummy.png",
	Glyph.DUMMY_U: "res://assets/circle/icon_dummy.png",
}

## **How much of the card's symbol radius the icon picture fills.** The same split `RUNE_ART_FRAC` records:
## the radius keeps sizing the rarity ring and the procedural fallback, and only the drawn picture moves.
## **Under 1.0 because the rarity ring sits at `RARITY_RING_RATIO` (1.3) of that radius** — draw the picture
## out to the full radius and the ink runs into the ring instead of sitting inside it.
const PALETTE_ICON_FRAC := 0.86

## **The rune bead's own picture, by element.** All three elements have art, so unlike the two maps around
## it this one has no fall-through case in practice — the procedural bead stays as the fallback anyway,
## because a missing file must not draw nothing.
const RUNE_TEX: Dictionary = {
	Tuning.ELEM_FIRE: "res://assets/circle/rune_fire.png",
	Tuning.ELEM_NONE: "res://assets/circle/rune_none.png",
	Tuning.ELEM_WATER: "res://assets/circle/rune_water.png",
}

const SOCKET_GLYPH_TEX: Dictionary = {
	Glyph.SPREAD_C: "res://assets/circle/socket_glyph_spread.png",
	Glyph.SPREAD_R: "res://assets/circle/socket_glyph_spread.png",
	Glyph.SPREAD_U: "res://assets/circle/socket_glyph_spread.png",
	Glyph.BLAST_C: "res://assets/circle/socket_glyph_blast.png",
	Glyph.BLAST_R: "res://assets/circle/socket_glyph_blast.png",
	Glyph.BLAST_U: "res://assets/circle/socket_glyph_blast.png",
}

## **The screen's share of "you cannot fire right now".** With the rune slot empty the staff tip **dies to gray.**
##  The staff tip is **the only place always visible without opening the assembly window**, so this is what stops
##  the user from **reading a left-click that does nothing as a breakage** (design "failing after firing reads as a breakage").
##
## **There are two uses and they mean the same thing, so it is one set** — the staff tip (`character_view`) and
##  the **empty rune slot** in the assembly window (`circle_window._draw_rune_slot`). Two screens say the same thing in the same gray.
##  **The names were `MUZZLE_DEAD`·`MUZZLE_DEAD_WIDTH_PX`.** The muzzle bead is gone, so keeping those names
##   **leaves a "muzzle" in a repo with no muzzle** — the shape this repo calls a "false knob".
##   **They were renamed, not deleted**: deleting them outright would have killed `circle_window` at runtime,
##    and that is **only visible once the assembly window is opened.**
## **Not filling it is the point.** Filled with gray it looks like "a dark bead", and that reads not as "it is off" but as "it is weak".
## **Whether it gets lost on a stone wall (0x5C574F ~ 0.36,0.34,0.31) was not measured** — there is a brightness
##  difference so it looks like it would split, but it is a place for the eye.
const DEAD_TINT := Color(0.62, 0.62, 0.66, 0.85)
const DEAD_RING_PX := 3.0

# --- the assembly window --------------------------------------------
## **The window must not cover the whole stage.** With the world invisible, "the world keeps running with the
##  window open" **cannot be confirmed by eye**, and that is everything this stage measures (design acceptance 4).
##  => Part of the screen + translucent. `net_render` measures the size and the position.
##
## **The reason the position is bottom-right is `HUD/Stats`.** That Label uses (8,8)-(900,210), so overlapping mixes the text.
##  And the character's start position is bottom-left (96,960), so **that is avoided too** —
##  if the window hides the character you cannot see "walking with the window open".
## **This is the single source of the dimensions.** Write offsets into the scene and there are two places, and then
##  the window opens with the scene's values while the net measures these — **both green while diverged.**
## **90% of the screen** — a user acceptance: "just make the book take up 90% of the screen".
##  90% of the 960x540 viewport = 864x486, centered => (48, 27).
##  **The 90% contract is a ratio, not a number** — change the viewport and the numbers here go with it.
##
## **The contract "the character is visible with the window open" was abandoned** (a user acceptance).
##  **With camera following in, the character is always at the center of the screen and the window at 90% covers it.**
##  => It could have been kept by moving the window to a bottom band or shrinking the height to 134px or less, but
##   **the user knew that price and chose "leave it as is".**
##  **Write down exactly what was lost: while the assembly window is open you cannot see whether you are on fire.**
##   That was the reason this contract was made in the first place ("with no monsters and no health the price of not
##   seeing it is 0" had disappeared).
##  **If you want it back, move or shrink the window. Reverting the camera is not the answer** —
##   with a static camera the stage does not fit in one screen (the `MAP` comment in `stage.gd`).
##  That check in `net_render` was deleted. The values and the control are left in the deletion note there.
##
## **Only the height was shrunk and it was pushed up** (a user acceptance). **The 90% width is unchanged.**
##  **If the size changes, recompute `net_circle.CIRCLE_DIAMETER_FLOOR_PX` (180)** —
##   at the current values the circle diameter is **280.1px**, leaving 100px of headroom (plan section 5).
##
## At this size it still **covers** `HUD/Stats` (8,8-900,210). The overlap is safe because the window is **opaque**
##  (the text is not mixed, just hidden), which is why `net_render` measures **"it is opaque"** rather than
##  "it does not overlap". Revert it to translucent and that goes red first.
## **Health is `HUD/Health` (660,494-952,530) so it is outside this window** — visible during assembly too.
##  **That is a living contract** — `Health` is in the same screen coordinate space as the window so it is
##   camera-independent, and `net_render._window_does_not_cover_the_health` measures it as is.
##
## **All `.tscn` `offset_*` values for `HUD` children live in this 960x540 canvas, not the 1920x1080 window.**
##  `project.godot`'s `stretch/mode = "canvas_items"` scales the whole canvas 2x to fill the window; Control
##  coordinates are never doubled by hand. `HUD/Health` shipped for a full session at `(1320,988)-(1904,1060)`
##  — a plausible-looking 1920x1080-scale box that was **entirely off the 960x540 canvas**, so the label never
##  drew one pixel and nobody noticed (correct value, correct `visible`, blank screen — CLAUDE.md's "screen
##  changes but sim doesn't" has a presentation-only cousin: **script state changes, the canvas doesn't**).
##  `net_render._hud_controls_are_inside_the_viewport` measures every `HUD` child against the real,
##  project-settings-read canvas size — the trap this comment describes is exactly what it catches.
## `HUD/Progress` sits just above `Health`, at `(660,450)-(952,486)` — same reasoning, same margin.
const WINDOW_RECT := Rect2(48, 12, 864, 372)

## **It is opaque.** A user acceptance — "there should **be a background color**, like a particular window opening".
##  Stage 2 wrote "translucent" as the grounds for acceptance 4, but **that was the wrong grounds.** What was
##   actually measured was clicks outside the window firing · ticks rising · A/D working · fire spreading
##   => **none of that breaks when it is opaque.**
##  Instead the contract moved to **position**: the character and its surroundings must be visible with the window
##   open (`WINDOW_RECT` above).
const WINDOW_BG := Color(0.05, 0.055, 0.085, 1.0)
const WINDOW_EDGE := Color(0.45, 0.55, 0.75, 0.9)
const WINDOW_EDGE_PX := 2.0
const WINDOW_PAD_PX := 12.0

## The palette is filled in by stages 4-5. Right now there is only the backing · the title · the magic circle art.
const WINDOW_TITLE := "마법진 조립"
const WINDOW_TITLE_COLOR := Color(0.86, 0.90, 0.98)
const WINDOW_TITLE_SIZE := 16
## The band the title occupies. **The two pages start below it** — overlapping and neither reads.
## In stage 3 the whole window was the circle's place, so there was only **6.4px** of headroom (risk 24).
##  With the pages starting below this, that tightness **disappeared structurally** — the circle now exists
##  only inside a page, so it has no way of reaching the title.
const WINDOW_TITLE_BAND_PX := 34.0

# --- the three-pick window (Stage D) ---------------------------------
## **The same rect as `WINDOW_RECT`, on purpose — "copy `CircleWindow`'s contract exactly"** (the plan's own
##  words). The two windows are never both visible (`_toggle_pick`/`_toggle_assembly` each close the other),
##  so sharing a footprint is not a collision risk, and it inherits every position guarantee `WINDOW_RECT`
##  already has for free: enclosed by the 960x540 canvas, does not cover the `Health`/`Progress`/`LevelUp`
##  column (which starts at y 404 — `WINDOW_RECT` ends at y 384, **a 20px gap that is the entire margin**
##  in this layout).
const PICK_RECT := WINDOW_RECT

## **Opaque, for the same reason as the assembly window** — acceptance 12, "there should be a background
##  color, like a window opening" (the user's note this file already carried before Stage D existed).
const PICK_BG := Color(0.05, 0.055, 0.085, 1.0)
const PICK_EDGE := Color(0.62, 0.5, 0.35, 0.9)
const PICK_EDGE_PX := 2.0
const PICK_PAD_PX := 12.0

const PICK_TITLE := "세 장 중 하나"
const PICK_TITLE_COLOR := Color(0.86, 0.90, 0.98)
const PICK_TITLE_SIZE := 16

## **The confirmation screen's own title — not `PICK_TITLE` reused.** "세 장 중 하나" ("one of three") kept
## reading during confirmation, when choosing was already over — measured, verify-look read that combination
## as the window failing to close, not as a placement confirmed.
const PICK_CONFIRM_TITLE := "장착 완료"
## Cards start below this band, the same reason `WINDOW_TITLE_BAND_PX` exists — overlapping the title reads as neither.
const PICK_TITLE_BAND_PX := 34.0

## The band the decline/dice buttons occupy, **below** the cards.
const PICK_BUTTON_BAND_PX := 40.0
## Gap between the (up to 3) cards.
const PICK_CARD_GAP_PX := 12.0

const PICK_CARD_BG := Color(0.10, 0.11, 0.15, 1.0)
## **The card's border is the rarity color** (`RARITY_TINT`) — this is the whole of "rarity separates by
##  color on the card". Stage A already proved these three read on this dark palette, magnified and at
##  native size (verify-look).
const PICK_CARD_EDGE_PX := 3.0

const PICK_NAME_COLOR := Color(0.92, 0.92, 0.90)
const PICK_NAME_SIZE := 16
const PICK_RARITY_SIZE := 12
const PICK_EFFECT_COLOR := Color(0.72, 0.76, 0.82)
const PICK_EFFECT_SIZE := 12

## **Text names for `Glyph.RARITY_*`, in the same one place as their colors** — split the name into a
##  second table and the day a rarity is renamed only one of the two follows.
const RARITY_NAME: Dictionary = {
	0: "일반", 1: "희귀", 2: "유니크",
}

## **The card's own glyph picture — the empty middle third of the card, between the rarity line and the
##  effect sentence** (the user, looking at the real screen: "문양링이나 이런 게 떴을 때 이게 문양 모양이 같이
##  뜨게 해줘, 일단"). Before this a card was name + rarity word + one sentence with nothing pictorial at all —
##  the dummy's small hollow-diamond mark used to be the only shape any card ever drew, and only for `KIND_
##  MODIFY`. That special case is gone now: every id gets the same picture (`three_pick_window._draw_pick_
##  card_glyph` — texture where `SOCKET_GLYPH_TEX` has art, the same procedural shape `_draw_pick_glyph_
##  shape`/`circle_window._draw_glyph` already draw otherwise) plus the rarity ring, so drawing two
##  overlapping diamonds for a dummy card never happens.
## **Not measured on screen** — sized for the real window (864x372, 3 cards ≈ 272x286 each, `Fx.PICK_RECT`);
##  `_draw_card` clamps it down for a narrower card rather than trusting this number alone.
const PICK_CARD_GLYPH_R_PX := 44.0

## Decline is always available — **`can_place_glyph`'s "removing is always allowed" idiom, one level up.**
const PICK_DECLINE_TEXT := "취소"
const PICK_DECLINE_COLOR := Color(0.85, 0.55, 0.5)

## **The dice button — drawn, visibly disabled.** `Progress.dice_left` is 0 and nothing raises it
##  (that field's own comment); a normal-looking button that silently does nothing on click is exactly the
##  fake this doc's own "Against CLAUDE.md's fake-code list" paragraph warns against, so this reads as
##  **off**, not merely unlucky to click — the same device `DEAD_TINT` already uses for "you cannot fire".
const PICK_DICE_TEXT := "주사위 (0)"
const PICK_DICE_COLOR := DEAD_TINT

# --- step 2 — the layer choice ----------------------------------------
## Width of the picked card once it shrinks into the corner (`pick_layout.picked_card_rect`) — narrower than
## a step-1 card (`(864-24)/3 ≈ 280px`), wide enough that its three lines of text (name · rarity · effect,
## the same "what it does, not only what it is" reading Stage D's own draw already leans on) still fit.
const PICK_PICKED_CARD_W_PX := 220.0

## **A layer already holding a glyph draws that glyph dimmed, with the incoming one beside it** — the design
## doc's own words for what "gets pushed out" has to show. `GLYPH_TINT`'s color, alpha-scaled — not a second
## color table, the same "one column, every kind reads it in its own place" idiom `power_pct` already holds.
##
## **"Over it" was tried literally first and failed for one shape combination** — verify-look measured a
## dimmed `MODIFY` diamond (`GLYPH_MODIFY_RATIO` 0.75) sitting entirely inside an incoming `TERMINAL` disc
## (`GLYPH_TERMINAL_RATIO` 0.8) at the *same point, same radius*: **invisible**, alpha or not. `PICK_PUSHOUT_
## OFFSET_RATIO`/`_SCALE` below move the outgoing glyph beside the incoming one instead, so no combination of
## shapes can fully occlude another regardless of which two glyphs happen to collide.
const PICK_PUSHOUT_DIM_ALPHA := 0.35
## How far to the side (a multiple of the glyph radius) the outgoing glyph sits from the incoming one.
const PICK_PUSHOUT_OFFSET_RATIO := 1.3
## The outgoing glyph draws smaller than the incoming one — visually secondary, not competing for attention
## with the placement that is actually about to happen.
const PICK_PUSHOUT_SCALE := 0.55

## **A rejected placement must be visible, not silent** (Stage D's own screen finding, one level up: a card
## reading as identical to its siblings was a real defect; a click that does nothing with no reason shown is
## the same disease). The only rejection `place_glyph` can hand back today is the family cap
## (`glyph_defs.gd`'s `max_per_circle`, counted by family) — layer bounds are unreachable through a real
## `layer_at()` hit, and an unknown glyph id cannot reach this window at all (it only ever holds ids `drawn()`
## itself produced). So the message names the one real cause rather than a generic "no".
const PICK_REJECT_TEXT := "여기엔 놓을 수 없다 — 같은 계열이 이미 있다"
const PICK_REJECT_COLOR := Color(0.85, 0.35, 0.3)

# --- the open book — two pages --------------------------------------
## **Page size is not here.** It is derived from the window size (`book_layout.pages`) —
##  hardcode it and the day the window grows the pages go outside it, and being a screen problem no error is raised.
const BOOK_MARGIN_PX := 12.0
## The width of the center fold. **It is the art of a boundary** — this is both the visible boundary and (in stage 4b) the click boundary.
const BOOK_FOLD_PX := 10.0
## The page ground. It must be **brighter** than the window backing to read as "an opened sheet" — the same and the page is invisible.
const BOOK_PAGE := Color(0.12, 0.13, 0.18, 1.0)
## The fold. It must be **darker** than the page to read as a carved groove.
const BOOK_FOLD := Color(0.03, 0.035, 0.055, 1.0)

# --- the assembly window — the magic circle art ---------------------
## **They are all ratios.** Hardcode pixels and the day the window size changes the art goes outside the window.
##  The layer ring radii come out **divided by the layer count** (`circle_layout.layer_bands`) — only the
##   **outer end** the rings occupy is here. Put a constant per ring and they overlap the day a 3-layer circle arrives.
const CIRCLE_AREA_PAD_PX := 14.0
const CIRCLE_DISC_RATIO := 0.94
const CIRCLE_RING_ZONE := 0.80
const CIRCLE_RUNE_RATIO := 0.17
const CIRCLE_GLYPH_RATIO := 0.115
## The rune slot's inner core. It is "a wick burning white", so it must be smaller than the outer glow
##  (the same idiom as the muzzle and the flash).
const CIRCLE_RUNE_CORE_RATIO := 0.45

## **The triangle circle's geometry — integers on a 512 basis, not pre-divided ratios**
##  (`docs/design/circle-art.md` "the triangle circle's settled parameters", divided by 512 to land here;
##  the same numbers also live in `tools/pixel/draw_circle.py:128`, the asset side — see that file's own
##  comment and `triangle-circle-to-game.md` "TBD" for why there are two copies).
## **Integers so the two equations stay readable and drivable**: `TRI_SOCKET_DIST + TRI_SOCKET_R == TRI_CANVAS_R`
##  and `TRI_SOCKET_R*2 == 288` (a ratio would hide that identity behind rounding).
const TRI_CANVAS_R := 512
const TRI_SOCKET_DIST := 368   ## center -> socket center
const TRI_SOCKET_R := 144      ## socket radius (diameter 288 — the socket glyph ring's own measured size)
const TRI_BAND := 48           ## the socket's clickable/drawn band thickness (the layer axis's seat here)
const TRI_RING := 420          ## the wrapping ring's radius — **not** the full frame; the sockets punch through it
const TRI_CENTER_R := 112      ## the center ornament's outer radius. **Not a glyph seat** — see `circle_window.gd`
const TRI_LINK_HALF := 26      ## half-width of the link band drawn between socket centers
## 12 · 4 · 8 o'clock, straight out of `draw_circle.py:128`. **Seat 0 (12 o'clock) is the only clue the
##  picture gives for "this one goes first"** (the design doc's clockwise-order question).
const TRI_SOCKET_DEG: Array[float] = [-90.0, 30.0, 150.0]

## The circle's border — the rim of the vessel. It must be **darker and thicker** than the layer rings to read as "a frame".
const CIRCLE_FRAME := Color(0.38, 0.45, 0.62, 0.85)
const CIRCLE_FRAME_PX := 2.0

## **"Innermost first" is not entrusted to concentric circles alone** (design acceptance 3).
##  Concentric circles say only that an order **exists**, not **which side comes first**.
##  => **Two** devices are hung: (1) layer numbers (1·2) (2) **a brightness difference with the inside brighter**
##  (the two colors below are mixed per layer).
## With only one color that device drops to one, and then acceptance 3 hangs on concentric circles alone.
const CIRCLE_RING_INNER := Color(0.72, 0.86, 1.0, 0.95)
const CIRCLE_RING_OUTER := Color(0.30, 0.40, 0.58, 0.95)
const CIRCLE_RING_PX := 2.0

## Layer numbers. They are written to the **left** of the ring — the glyph symbol sits at 12 o'clock, so writing there overlaps.
const CIRCLE_LAYER_NUM := Color(0.80, 0.86, 0.96)

## **The text size is derived from the radius.** Hardcode it and when the circle grows only the number stays,
##  making it less noticeable on a large drawing, and that is **the direction of weakening device (1) of acceptance 3.**
##  Measured: as the window went 28.4% -> 90% the diameter went 199 -> 364 while the number was frozen at 12 (verify-look).
## The ratio 0.12 is stage 4a's shape (radius 99.6 · text 12) carried over as is.
const CIRCLE_LAYER_NUM_RATIO := 0.12
## However small it gets, below this it does not read.
const CIRCLE_LAYER_NUM_MIN := 10

## How far inward from the ring's left end · how far the text baseline is lifted. **Proportional to the text size.**
## If the number sits exactly on the ring's line, the line and the text eat each other and **neither reads.**
##  Hardcoded in px, only the text grows while the push stays, so **the bigger it gets the more it is buried in the ring.**
## 0.25 is stage 4a's shape (text 12 · push 3px) carried over as is.
const CIRCLE_LAYER_NUM_INSET_FRAC := 0.25
const CIRCLE_LAYER_NUM_LIFT_FRAC := 0.25

## **The shape of a glyph symbol is decided by `kind`** (`glyph_defs.DEFS`) — drawing per glyph would make that
##  "a fourth place to fix when adding a glyph". The color is `GLYPH_TINT`, so it is **the same color as the staff tip**,
##  and that is why the window and the staff read as the same magic.
##  SPAWN's ray count is **a presentation value.** It does not need to equal spread's 8 directions —
##   kept equal it misreads as "every glyph that makes bolts makes 8 of them".
const GLYPH_SPAWN_RAYS := 6
const GLYPH_SYMBOL_PX := 2.0

## **Rotate the rays by half a step.** Without it the 0° and 180° rays are **horizontal**, and since the symbol sits
##  at 12 o'clock on the ring the tangent at that point is horizontal too, so **the two rays fold onto the ring's line and vanish** —
##  measured, 6 rays looked like **a 4-ray X** on screen (verify-look).
##  Rotating half a step (= spacing/2) empties 0° and 180° out of 6 rays and stands 90° and 270° instead, meeting the ring at a right angle.
##
## **If `GLYPH_SPAWN_RAYS` is odd, one ray necessarily stands at 180° even with the half step.**
##  Not "it can stand" but **"it necessarily stands"**:
##  `360(k+0.5)/N = 180` <=> `k = (N-1)/2`, and that being an integer is equivalent to **N being odd**.
##  => The ray count **must be even.** `net_circle` actually measures the angles and measures that it is even too.
## And this is **a stopgap answer about placement.** The cause is the symbol sitting **on** the ring itself, so
##  it comes back when layers grow and the ring spacing narrows — then the symbol has to shrink or move outside the ring.
const GLYPH_SPAWN_ANGLE_STEP_FRAC := 0.5
# --- empty slot — "you can put something here" -----------------------
## **There are three slot states and the first one was missing** (empty · filled · blocked).
##  Measured: the currently empty rings **read as "a place called layer 1 / layer 2" but not as "you can put
##  something here"** (verify-look). **With only the third (blocked) and not the first, "blocked" and "empty" look the same.**
##
## **It means something different from an empty rune slot** — an empty rune means "you cannot fire" (a warning,
##  `DEAD_TINT` gray) while an empty layer means "you can put something here" (an invitation).
##  **Keep the color and the shape different** — the same and the two meanings mix.
const SLOT_EMPTY := Color(0.55, 0.62, 0.78, 0.55)
const SLOT_EMPTY_PX := 1.5
## The **plus mark** drawn in an empty slot. Without the cross it is just a faint circle and reads only as "a place".
const SLOT_PLUS_RATIO := 0.5
const SLOT_PLUS_PX := 1.5

## **The circle you press is bigger than the symbol.** Kept the same as the symbol you have to aim exactly at an
##  empty layer for it to click, and that becomes "I pressed it and nothing happened". Grown too far it eats the
##  neighboring layer — it must be smaller than the ring spacing (half the radius). `net_circle` measures whether they overlap.
const SLOT_HIT_RATIO := 1.8

## The border of the picked item. **It is part of the behavior, not presentation** — if what you picked is invisible,
##  the first half of "pick, then place" is not on screen.
const PALETTE_PICK := Color(1.0, 0.92, 0.55, 0.95)
const PALETTE_PICK_PX := 2.0
## **The opacity of the veil** covering an unpickable item. **If spread is already there, a second spread
##  cannot be pressed in the first place** (design). If it can be pressed and nothing happens, that reads as a breakage —
##  blocking it one step earlier is the point.
## **Why a veil and not `modulate`**: `modulate` applies to the whole node and persists into the next frame.
const PALETTE_BLOCKED_VEIL_A := 0.72

# --- palette --------------------------------------------------------
## Section size is divided by the **kind count** and item cells by the **item count** (`palette_layout`) —
##  only the margins and the title band are here. Hardcode cell sizes and they overlap the day circle or rune items grow.
const PALETTE_PAD_PX := 14.0
const PALETTE_SECTION_GAP_PX := 10.0
const PALETTE_HEAD_PX := 24.0
const PALETTE_SYMBOL_RATIO := 0.52

## Section border and ground. **Drawing sections is the answer to "an empty palette"** — with only four items
##  the page is largely empty, and with sections that emptiness reads as **"what is this a place for"**.
##  Without sections the same screen just reads as "unfinished".
const PALETTE_SECTION_BG := Color(0.09, 0.10, 0.145, 1.0)
const PALETTE_SECTION_EDGE := Color(0.30, 0.36, 0.50, 0.8)
const PALETTE_SECTION_EDGE_PX := 1.0
const PALETTE_HEAD_COLOR := Color(0.72, 0.79, 0.92)
const PALETTE_HEAD_SIZE := 14
## Where the title text's baseline sits within the band. `draw_string` is **baseline**-based, so at 0
##  the text sticks out **above** the section. At 1.0 it clings to the bottom of the band and collides with the items.
const PALETTE_HEAD_BASELINE_FRAC := 0.7

## ── tabs — 진 · 룬 · 문양, one open at a time (`onboarding-and-palette-tabs.md`) ──
## **`Fx.PALETTE_*` only** — `net_circle` bars this file from `Fx.WINDOW_*` and `book_layout`
##  (`palette_layout.gd`'s own header), so every new value the tab strip and the 완성 band need is prefixed
##  the same way the rest of this section already is.
## **Screen values below are defaults, not decisions** — put them in, look at them, move them
##  (the plan's own "Screen values below are defaults").
const PALETTE_TAB_BAND_PX := 26.0
const PALETTE_TAB_GAP_PX := 4.0
const PALETTE_TAB_SIZE := 14
## Open vs. closed — background and text color both flip, so which tab is open reads even with the
##  labels unread. The open tab reuses the picked-item gold family; closed tabs sit dim and low-contrast.
const PALETTE_TAB_OPEN_BG := Color(0.20, 0.22, 0.30, 1.0)
const PALETTE_TAB_CLOSED_BG := Color(0.09, 0.10, 0.145, 1.0)
const PALETTE_TAB_OPEN_TEXT := Color(1.0, 0.92, 0.55, 1.0)
const PALETTE_TAB_CLOSED_TEXT := Color(0.55, 0.58, 0.66, 0.85)
const PALETTE_TAB_EDGE := Color(0.30, 0.36, 0.50, 0.8)
const PALETTE_TAB_EDGE_PX := 1.0

## The "마법진 완성" band at the bottom of the palette page — always present, in every tab
##  (design §5: "it confirms, it does not apply").
const PALETTE_DONE_BAND_PX := 40.0
const PALETTE_DONE_TEXT := "마법진 완성"
const PALETTE_DONE_SIZE := 14
const PALETTE_DONE_BG := Color(0.16, 0.19, 0.26, 1.0)
const PALETTE_DONE_EDGE := Color(0.40, 0.52, 0.70, 0.9)
const PALETTE_DONE_EDGE_PX := 1.5
const PALETTE_DONE_TEXT_COLOR := Color(0.85, 0.92, 1.0, 1.0)
## The glow the moment 완성 is pressed (Stage 6) — one flash, not a held state.
const PALETTE_DONE_GLOW_COLOR := Color(1.0, 0.95, 0.7, 0.5)
const DONE_GLOW_FRAMES := 18

## The 문양 tab's empty note — "문양이 하나도 없다" is a sentence, not a blank rectangle
##  (design §3: an empty framed box reads as a drawing bug).
const PALETTE_EMPTY_TEXT := "현재 문양이 없습니다"
const PALETTE_EMPTY_SIZE := 14
const PALETTE_EMPTY_COLOR := Color(0.60, 0.64, 0.74, 0.9)

## 찰칵 — a click is motion here, not sound (this repo has none; see the plan's own Blockers).
## How many frames the just-filled seat's ring holds its flash.
const CLICK_FRAMES := 10
const CLICK_COLOR := Color(1.0, 0.95, 0.7, 0.9)

## Where the SPAWN rays **start** (relative to the radius). At 0 they emanate from a single point and look like a clump, not a star.
const GLYPH_SPAWN_INNER_RATIO := 0.3
## The TERMINAL disc's radius (relative to the symbol radius). At 1.0 it looks the same size as the ray symbol,
##  weakening the contrast of "it spreads / it ends right there".
const GLYPH_TERMINAL_RATIO := 0.8

## **MODIFY's shape — a hollow diamond.** It must differ in silhouette from SPAWN's outward rays and
##  TERMINAL's filled disc, the same discipline that separates those two — "it touches neither trajectory nor
##  list" reads as **an outline, not a filled shape and not a burst**, so it does not compete visually with
##  "it spreads" or "it ends here" and is not mistaken for a stronger version of either.
const GLYPH_MODIFY_RATIO := 0.75
const GLYPH_MODIFY_PX := 2.0

# --- **the spread generation table — the screen's half** -------------
## It must have **the same length and the same direction** as `sim_tuning.SIM_SIZES` (both decrease per generation).
##
## **This table is all of "do small things look weak".** If the radius halved in the sim while this stays fixed,
##  nothing changes on screen, and **that is exactly how v1 died**
##  (the power doubled and 0 things changed on screen). `net_tables` measures the two tables' length and monotonicity together.
## Do not make the values equal — the net cannot tell "on purpose" from "forgot".
##
##   bolt_px      head radius. The only axis by which the generation is visible while flying
##   trail_ticks  how many ticks the trail remembers (= the tail length)
##   flash_px     the final radius of the blast flash
##   shake_px     screen shake amplitude (integer px)
##
## **At the 32px transition only `bolt_px`·`flash_px`·`shake_px` were x2'd.** All three mean
##  "this big on screen", while `trail_ticks` is **a tick count** and so is scale-independent —
##  doubling it too makes the tail not **twice as long but twice as long-lived** (a different axis).
##
## **Only `flash_px` was lowered twice, following `rd`**: 216 -> 108 -> **72**.
##  The value is always **`rd` x `CELL_PX` x 2.25** (the `FLASH_SEC` section below). It is matched by hand;
##   the code does not enforce it — **no net measures this ratio.**
##  **Shrink `sim_tuning.SIM_SIZES.rd` and this must follow** — the `FLASH_SEC` section below pinned
##   "the flash is 2.25x the hole" as this table's share, and that ratio is what splits "the hole got bigger"
##   from "it exploded". Shrink only the sim and leave this, and **the hole shrinks while the flash stays**,
##   so on screen the blast looks like it did not shrink — the shape CLAUDE.md writes down as this repo's **representative fake**.
##  **`bolt_px`·`shake_px` were not touched.** The bolt head size is "the axis by which the generation is visible
##   while flying" and shake is "how hard it exploded", so both are **axes other than the radius**. What the user
##   spoke about was only the range.
##   => With only the flash shrinking and the shake unchanged, **if the feel looks off, that is the next knob.**
const FX_SIZES: Array[Dictionary] = [
	{"bolt_px": 8.0, "trail_ticks": 12, "flash_px": 72.0, "shake_px": 5},
	{"bolt_px": 4.0, "trail_ticks": 8, "flash_px": 36.0, "shake_px": 2},
]

# --- projectiles ----------------------------------------------------
## The head radius comes from the table above.
##  One 4px cell is terrain's smallest unit, so a bolt smaller than that "gets buried in the terrain" —
##   generation 1 being about one cell **on screen** is **on purpose**. Small things have to get buried to read as "weak".
##  At the 32px transition the scale went 2 -> 1, so **preserving the screen size requires the value to be doubled**
##   for that meaning to survive (before: 4·2 world px x 2 = 8·4 screen px / after: 8·4 world px x 1 = the same 8·4 screen px).
const BOLT_GLOW_RATIO := 2.4

## **0.45 -> 0.12 (decided by the user). This value is the culprit that failed acceptance 1.**
##
## **The user launched the game, looked, and failed it with "the light follows it so I can't see it".**
##  **The cause was not the spec but "a leftover from the circle era"** — this value and `BOLT_GLOW_RATIO`
##   existed to make the head read as "something glowing" back when it was **a flat circle**.
##  **The art already contains a bright core -> dark edge gradient, so it is light by itself**,
##  and laying a radius 19.2px glow on top of it **additively** washed the detail away.
##
## **The reason it was not deleted outright is generation 1.** The 8 spread bolts have an **8px** head
##  so they can get buried on a black background, and **nobody measured that** (the plan doc warned in advance).
##  => The glow's meaning was changed from "washing out the art" to **"propping small bolts up so they do not get buried".**
## **verify-look saw it — both worked. The worry "should it be split per generation" was not real.**
##  - generation 0: the bolt head art **is visible.** A fireball falling from a yellow core into orange. Not washed out by the light
##  - generation 1 (the 8 spread bolts, 8px): **not buried.** Bright yellow arrows spread clearly in a fan against the black sky
##
## **Something else got caught instead — it was the shape, not the alpha.**
##  One filled circle looked like **"a dark brown disc with a hard edge".**
##  => The brightness was fixed but **the "one circle" the user pointed at was still there, just fainter.**
##  **What fixed it was not this value but `BOLT_GLOW_LAYERS`** — overlapping draws blur the edge.
const BOLT_GLOW_A := 0.12

## How many layers the glow is drawn in. **At 1 it is the old behavior (a hard disc).**
##  **The alpha is divided as `BOLT_GLOW_A / layer count`** — without dividing, the total brightness gets
##   layer-count times stronger and the judgment behind picking 0.12 dies. The layer count changes **only the softness of the edge.**
## 4 means "4 `draw_circle`s per bolt". At the cap of 32 bolts that is 128 calls — nobody measured it.
const BOLT_GLOW_LAYERS := 4

## **The trail is longer than v1's (4-8 ticks).** With drag and gravity in, the tail has to be long for **the droop
##  to be visible** — short and the trajectory reads as a straight line, and then acceptance 3 does not come out at all.
##  12 ticks = 0.6s. In a 20Hz sim a bolt jumps 20 cells (80px) on the first tick, so the early tail reaches 960px —
##   half the screen (1,920px). That is why the thickness and alpha shrink toward the tail as well.
## The thickness is screen-based so it was x2'd (5.0 -> 10.0). **The tick count was not touched** — see the table comment above.
const TRAIL_PX := 10.0
## The alpha at the tail's end. The closer to 0 the more sharply it vanishes.
const TRAIL_TAIL_A := 0.12

## **The tail's alpha at the head end. It is not 1.0** (the user said so looking at the screen).
##
## **User acceptance: "the tail is too bright compared to the bolt so I can't see it well".**
##  **The cause was the product of three things**: the tail color is `core` (a bright cream) · the head-end alpha
##   was **1.0** · the renderer is **additive**. => Right behind the head the tail **burns white** and beats the head art.
##  **The head art has a dark-edged gradient**, so it loses to a thick, uniform line in principle.
##
## **The head is the bolt and the tail is an afterimage — an afterimage must not be brighter than the body.**
##  => This value and `TRAIL_USES_GLOW` went in together. Both are knobs for "putting the tail below the head".
const TRAIL_HEAD_A := 0.55

## **The tail uses `glow`, not `core`.** `core` is the same brightness as the head art's core, so
##  the tail **glows at the same intensity as the head.** `glow` (orange for fire) is one step darker so the head wins.
## **Set to false it is the old behavior** — the way back is this one line.
const TRAIL_USES_GLOW := true

## Below 1px it is not drawn. **It is a render floor, not a feel value** — two places each holding a magic number
##  with the same meaning will necessarily diverge.
## **Do not touch it when the scale changes.** The floor means "filter out sizes the renderer cannot draw",
##  and it is **based on the world side**, so it is scale-independent — moving it with the scale would instead
##  filter out different things at each scale.
##  Right now the scale is 1x, so this floor is **exactly 1 screen px.**
const MIN_DRAW_PX := 1.0

# --- blasts ---------------------------------------------------------
## **Acceptance 2 splits here.** What is measured is "the rhythm of eight bursts vs one big one", so
##  a flash that lingers **smears the eight into one lump** and the two assemblies look the same.
##  => Keep the duration short and cut the overlap with a count cap.
##
## The values were taken straight from v1 P2's measured tuning (`rd 12`, the same radius) —
##  flash 108px · 0.21s · shake 5px · 0.20s. Measuring again is expensive.
##  `rd` went 12 -> 24 -> 12 -> **8**. The flash always followed and is now **72px**.
##   The two seconds are time, so they stayed the same throughout. **They got smaller than the measured tuning
##   above (based on `rd 12`)** — the feel of the flash and the shake was **not measured again at `rd 8`.**
##  **This line said "at the 32px transition shake was x2'd to 10" while the table said 5.**
##   The table (`FX_SIZES.shake_px` 5·2) is what actually runs, and that "10" was nowhere —
##   **which one was intended was not settled.** Whoever touches shake should settle that first.
## The point is that the flash radius is **2.25x** the hole radius (8 cells = 32px). Kept equal it only reads as
##  "the hole got bigger" and "it exploded" does not read. => The sizes are held per generation by `FX_SIZES` above.
##  **`rd` and `flash_px` must always move by the same factor for the 2.25x to survive** — touch only one and it
##   breaks, and the broken shape is not an error but "the blast doesn't seem to have gotten smaller".
const FLASH_SEC := 0.21
## The size at the moment it appears (relative to the final radius). Smaller reads as "it spreads", closer to 1 as "it flashes".
const FLASH_START := 0.35
## The outer glow's brightness · the inner core's radius ratio. The core is "a wick burning white".
const FLASH_GLOW_A := 0.55
const FLASH_CORE_RATIO := 0.34

## The cap on simultaneous flashes. Overflow drops **the oldest first** — dropping the newest makes
## the last blast silently invisible.
## The 8 spread bolts burst split across two ticks (budget 4), so 8 does not hit the cap. 16 is headroom.
const FLASH_MAX := 16

## Screen shake. **It is integer px** — `snap_2d_transforms_to_pixel` is on so the fraction is
##  thrown away anyway. Tightening it as a float gives "I lowered it to 0.5px and nothing happened".
## **They do not stack; the stronger one wins** (`_kick`). Adding them makes the screen fly apart on eight bursts,
##  and then "eight or one" cannot be read at all.
const SHAKE_SEC := 0.20
## The decay curve. 1 = linear · larger means **strong early and dying fast** (the impact is front-loaded).
const SHAKE_DECAY_POW := 1.6

# --- the health / XP readout (`hp_view.gd`) ---------------------------
## **Bottom-left, and top-left was tried first and does not fit.** `WINDOW_RECT` is `(48, 12, 864, 372)` —
##  the assembly and three-pick windows run to y 384, so **anything in the top left is under them**, and
##  `net_render`'s standing rule that no window may cover the health readout went red immediately. The band
##  below y 384 is the only clear strip on a 540px viewport.
## **Everything else here derives from this rectangle** (`hp_inner_rect` · `hp_xp_rect`), so moving the
##  readout moves the frame, the fill, the number and the XP line together.
const HP_RECT := Rect2(16.0, 448.0, 192.0, 48.0)

## The frame art. **It sat in `assets/ui/` referenced by nothing until `hp_view` wired it** — a hollow
##  rounded box at 384x96, drawn here at exactly half that so the pixels land 1:1.
const HP_FRAME_TEX := "res://assets/ui/hp_frame.png"
## **Tinted, and above 1.0 for the same reason `CIRCLE_ART_TINT` is**: `modulate` multiplies, so a tint under
##  1.0 can only darken. The frame's ink is near-black and the panel behind it is dark.
const HP_FRAME_TINT := Color(1.6, 1.55, 1.5)

## How far inside the frame the bar sits. **The art's border is 12px at 384 wide, so 6 at half scale** — one
##  pixel more and a full bar shows a gap at the ends, one less and it laps over the rounded corner.
const HP_FRAME_INSET_PX := 6.0

static func hp_inner_rect(panel: Vector2) -> Rect2:
	var i := HP_FRAME_INSET_PX
	return Rect2(i, i, maxf(0.0, panel.x - i * 2.0), maxf(0.0, panel.y - i * 2.0))

## The XP hairline, under the frame. **Its own gap so it does not touch the frame's shadow.**
const XP_BAR_H_PX := 5.0
const XP_BAR_GAP_PX := 5.0

static func hp_xp_rect(panel: Vector2) -> Rect2:
	return Rect2(0.0, panel.y + XP_BAR_GAP_PX, panel.x, XP_BAR_H_PX)

## The number's size, and where its baseline sits relative to the bar's centre. **`draw_string` takes a
##  baseline, not a top**, so centring vertically means pushing down by roughly a third of the size — measured
##  by eye against this font, not derived.
## **22, down from 26 — the string grew.** It was `87`; it is `87 / 100` now (the user asked for both
##  numbers), which is roughly three times as wide and overran the 180px bar at the old size.
const HP_NUMBER_SIZE := 22
const HP_NUMBER_BASELINE_FRAC := 0.36

## **The fill is red; the number on top of it is not.** A red number inside a red bar is invisible at full
##  health and only appears as the bar drains — which reads as the number breaking, not as health dropping.
const HP_FULL := Color(0.80, 0.16, 0.18, 1.0)
const HP_BAR_BG := Color(0.18, 0.06, 0.07, 1.0)
## Cream at full, pushed toward white as it empties — the number gets *more* legible as the bar behind it
## shrinks away from underneath it.
const HP_TEXT := Color(0.98, 0.93, 0.86, 1.0)
const HP_TEXT_LOW := Color(1.0, 1.0, 1.0, 1.0)

## XP. **Deliberately not red** — sharing health's colour would make the hairline read as a second health
##  bar. A cool tone separates "how hurt am I" from "how close am I".
const XP_BAR := Color(0.38, 0.72, 0.95, 1.0)
const XP_BAR_BG := Color(0.10, 0.14, 0.20, 1.0)

# --- money, bottom-right (`money_view.gd`) ----------------------------
## **The one number the user asked to keep on screen besides health** (「돈도 오른쪽 구석에 표시해 주고」).
##  Level was dropped in the same breath — 「레벨은 안 보이게」.
## **Right-aligned against this rectangle's own right edge**, so the digits grow leftward and the icon does
##  not walk as the amount changes.
const MONEY_RECT := Rect2(768.0, 452.0, 176.0, 40.0)
const MONEY_ICON_TEX := "res://assets/ui/icon_point.png"
const MONEY_ICON_PX := 24.0
const MONEY_GAP_PX := 8.0
const MONEY_TEXT_SIZE := 22
const MONEY_TEXT := Color(0.98, 0.88, 0.55, 1.0)
## The icon is near-black ink like the rest of `assets/ui/`, so it needs lifting the same way the frame does.
const MONEY_ICON_TINT := Color(3.4, 2.9, 1.6)

# --- camera work ------------------------------------------------------
## **How far the camera runs ahead in the direction you are moving, and how fast it comes back**
##  (user request: "the camera goes a bit the way I move, and comes back when I stop").
##
## **Follows the viewport, not the tile** — it is a fraction of what is on screen (72px is 15% of the 480px
##  half-width at zoom 1), so the sorting rule at the top of this file puts it in the third branch.
## **Raise it far and aiming suffers**: the shot origin is the character, and the further the character sits
##  from the screen centre the less of the far side you can see before firing. 72px was chosen as
##  "visible, and it does not move the character out of the middle third".
## **32, down from 72 (decided by the user: 「방향에 따라 카메라 이동하는 거 좀 줄여줘」).**
##  At 72 the camera swung a fifth of the half-width every time the walk direction changed, and on a
##  direction flip that is 144px of travel with the character standing still relative to the world — read as
##  the screen lurching. 32 keeps the "it leans the way I go" reading and cuts the swing to 64px.
const CAM_LEAD_PX := 32.0

## The fraction of the remaining distance **left after one second** — the same idiom as
##  `character.gd`'s `RECOIL_DECAY_PER_SEC`, and for the same reason: raised to `dt` it is
##  **frame-rate independent**, whereas a per-frame lerp constant silently changes the feel with the frame rate.
## 0.02 = 98% of the way there in one second, so it reads as **"it drifts", not "it snaps"**.
const CAM_LEAD_DECAY_PER_SEC := 0.02

# --- fire -----------------------------------------------------------
## **Burning cells overwrite the material color.** Laid lightly over the wood color (0x6B4524) it looks like
##  "the wood is a bit brighter", and then "fire spreads" does not appear on screen —
##  half of acceptance 5 is decided here.
## The cell grid is **not additively composited** (it is one sprite) — the alpha is real alpha, not brightness.
const FIRE_LO := Color(0.75, 0.18, 0.05, 1.0)
const FIRE_HI := Color(1.0, 0.80, 0.30, 1.0)

## Flicker speed (rad/s). The phase is scattered per cell, so this is "the speed the surface ripples at".
## Too fast and it looks like sizzling (noise) on 4px cells and does not read as fire.
const FIRE_FLICKER_HZ := 7.0

# --- water ----------------------------------------------------------
## The color of shallow water (`cell_materials.FLAG_SHALLOW`).
##
## **Why here**: material colors are **integers** in `cell_materials.DEFS` (that folder forbids `Color`),
##  and **a color that comes out of state** is a `Color` in the view folder — fire already paved the same road
##  (`FIRE_LO`·`FIRE_HI`).
##
## **The shallow side is brighter. Invert it and the screen lies** — real shallow water is bright because the
##  bottom shows through, and the other way round it becomes **"the deeper the brighter"** and the eye reads depth backwards.
## It must be **the same hue family** as deep water (`DEFS[WATER].rgb` = 0x2C5F8A) — split the hue too and
##  the two depths look like **two different materials** rather than "two faces of the same water".
##
## **This color solves one screen problem** (verify-look): the water looked like **"a blue brick"**,
##  and the first cause was **"zero variation inside the surface"** — even the top row is the same color as the
##  inside, so it looks like one lump.
##  => Brightening only the shallow cells breaks up that lump.
##  **That does not always come out as one row at the surface, though** — the condition is in the `sim_tuning.WATER_WET` comment.
##
## **The brightness was raised (decided by the user). Not taste, but making the rule readable.**
##
## **verify-look saw it on screen**: the two colors do split, but **the brightness difference is small, so at 4px
##  thickness it reads as "a shading difference in the same blue".** But in this game that difference is **a rule** —
##  **`WATER_WET` decides both the color and fireproofing** (`sim_tuning.WATER_WET`), so shallow water cannot put out fire.
## **So when the two colors are close, "why can't this water put out the fire" does not read on screen.**
##  That symptom actually happened: fire running under the blue line **looked like "fire burning underwater"**
##  (`water-and-chunk-sleep` "result (6)").
##
## **The hue was left alone and only the brightness and saturation were raised** — split the hue too and it runs
##  into "two different materials" above.
##  **It has not been seen on screen yet.** Whether this value is enough is the next thing to look at.
const WATER_SHALLOW := Color(0.62, 0.86, 1.0, 1.0)

# --- runes ----------------------------------------------------------
## **This is the rune's screen share** — the rules are decided by glyphs.
## Runes do not only change the screen. The side that touches the world (igniting the impact point) is in `sim_tuning.ELEM_DEFS`.
## The renderer is **additive**, so alpha reads as brightness. There is no need to go above 1.0.
const ELEM_FX: Dictionary = {
	Tuning.ELEM_FIRE: {"core": Color(1.0, 0.92, 0.66), "glow": Color(1.0, 0.48, 0.12)},
	# It must be **far on the color wheel from fire (orange ~30°)** so the staff tip and the rune slot split by eye. Violet (~270°).
	#  The value of this line is **why three candidates were dropped**:
	#   · gray — **when the rune slot is empty the staff tip is already gray.** "Cannot fire" and "fire with no
	#     element" become the same on screen, and that distinction is the whole of the warning `spell-circle-minimum` section 3.5 set up
	#   · blue/cyan — **the water rune actually took that spot** (the line below)
	#   · magenta — that is `ELEM_FX_MISSING`'s scream color. If a normal rune is that color the scream is not heard
	Tuning.ELEM_NONE: {"core": Color(0.85, 0.80, 1.0), "glow": Color(0.55, 0.35, 1.0)},
	# **Water — cyan (~190°).** Far on the color wheel from both fire (orange ~30°) and none (violet ~270°).
	#  **It must be the same family as the water cell color** (`WATER_SHALLOW` · `DEFS[WATER].rgb`) —
	#   a cyan bolt that makes navy water means **"this bolt makes that water" does not connect on screen.**
	#  **The renderer is additive so the values here are brighter than the cell color** — use the same color as is and the trail dies.
	Tuning.ELEM_WATER: {"core": Color(0.72, 0.97, 1.0), "glow": Color(0.20, 0.62, 0.95)},
}

## The color of a rune with no definition. **Deliberately magenta** — grow the runes without growing this
##  and the screen screams (the same reason as `MISSING_RGB` in `cell_materials.gd`).
const ELEM_FX_MISSING: Dictionary = {
	"core": Color(1.0, 0.0, 1.0), "glow": Color(1.0, 0.0, 1.0),
}

## **The bolt head art. One new rune = one line here.** It must have **the same keys** as `ELEM_FX` above —
##  diverge and a rune appears with a color but no art, and that shows up as magenta (`spell_view` below).
##
## **The art has only the head. The tail is drawn by code** (`spell_view._draw_trail`).
##  **Half of the original grounds is now dead, and it is the half that used to be quoted.** It read: the bolt
##  goes 1,600px/s = **26.7px per frame** while the art's tail is 16px, so the tail is entirely buried in the
##  trail. Generation 0 is **960px/s = 16.0px per frame** today, and the head square is drawn `bolt_px x 2`
##  = 16px (`spell_view._draw_head`), so a tail carried in the same sheet would be drawn 16px too — **exactly
##  equal, not buried.** Generation 1 lands on the same 1.00 (8.0px/frame against an 8px square).
##  **That equality is structural, not luck**: `net_tables._bolt_head_keeps_up` holds `px per frame <= head px`
##  per generation, and both rows sit exactly on it, so **the "buried in the trail" argument can never come back
##  while that check passes.** The old note here ("drop `speed` below 12 and the grounds invert") named a single
##  number; the floor is **per generation**, scaled to that generation's own art, and gen 1 crossed it unnoticed
##  at speed 8 (10.67px/frame against an 8px square).
##  **What still holds is the other half**: fire droops while a painted tail is straight, so an art tail
##  **diverges from the parabola** — speed-independent — and `trail_ticks` (12 ticks) is far longer than any
##  tail that would fit in the sheet. The reference is "the bolt head art" in `docs/design/circle-rune-glyph.md`.
##
## **It is a png with no alpha. That is still right** — `spell_view` is additive so black pixels add to 0,
##  i.e. **the black background acts as transparency.** Turned around, **dark colors do not appear on screen** —
##  put an outline or shading into the art and that area looks punched out.
##
## **`bolt_thunder.png` is not here yet.** **It was not forgotten** — there is no thunder rune yet.
##  Water added a line when its rune stood up. **The day thunder stands up, one more line.**
const BOLT_SHEETS: Dictionary = {
	Tuning.ELEM_FIRE: "res://assets/spell/bolt_fire.png",
	Tuning.ELEM_NONE: "res://assets/spell/bolt_none.png",
	Tuning.ELEM_WATER: "res://assets/spell/bolt_water.png",
}

static func elem_fx(element: int) -> Dictionary:
	return ELEM_FX.get(element, ELEM_FX_MISSING)


# --- reading the generation table ------------------------------------
# The **same rule** as `sim_tuning`'s clamp. If the table lengths diverge, `net_tables` catches it.

static func bolt_px(gen: int) -> float:
	return float(FX_SIZES[_gen_row(gen)]["bolt_px"])


static func trail_ticks(gen: int) -> int:
	return int(FX_SIZES[_gen_row(gen)]["trail_ticks"])


static func flash_px(gen: int) -> float:
	return float(FX_SIZES[_gen_row(gen)]["flash_px"])


static func shake_px(gen: int) -> int:
	return int(FX_SIZES[_gen_row(gen)]["shake_px"])


static func _gen_row(gen: int) -> int:
	return clampi(gen, 0, FX_SIZES.size() - 1)


## **The staff tip color = the innermost layer's glyph. If it cannot fire it dies to gray.**
##  Execution runs from the inside out, so "what happens first" is exactly this color (the GDD's glyph interpretation order).
##  If the list is empty it falls back to the rune color.
##
## **This function swallows the "cannot fire" branch.** Splitting it at the call site with `if can_fire()` leaves
##  that branch in screen code, **a place the net cannot call**, and then acceptance 5 lives only in the eye.
##  => Being pure static, `net_staff` measures it by value.
## **`muzzle_radius` (layer count = size) was deleted.** The grounds for the size axis disappearing are in the
##  `STAFF_RING_*` section above.
## **The staff ring's colour, decided from the circle itself.**
##
## **It lives here and not in `character_view._draw` for one reason: `_draw` is the one seat the nets cannot
##  call** (CLAUDE.md — "only `_draw` truly resists, no live font"). The bug this was extracted after was
##  exactly that: the view asked `element()` unconditionally, and **removing the circle in the assembly window**
##  takes the rune slots to 0, which that function **barks** at. **539 `push_error`s in one play session, and
##  3,509 green checks never saw it** — because the call sat inside `_draw`.
## ⇒ Now a net can build a circle with no circle socketed and call this, and **the wrapper's stderr check is
##  what fails** if the bark ever comes back. Nothing here needs to assert "it did not bark".
##
## **`element()`/`packed_glyphs()` is asked only when it can fire.** On the other branch `staff_tint` returns
##  `DEAD_TINT` without ever reading either, so passing `GLYPH_NONE`/`RUNE_EMPTY` there changes no colour —
##  it just stops asking a question the circle has said it cannot answer.
##
## **Reads `shots()[0]`, not `element()` paired with `packed_glyphs()`** (verify-read found the pairing was a
## splice across sockets, not a real spell). `element()` answers socket 0's rune; `packed_glyphs()` answers
## the **whole circle's** glyph list, densely packed from *whichever* socket has one first — on a triangle
## circle those can be two different sockets (socket 0 fire with no glyph, socket 1 water with blast: the old
## code showed **fire's rune paired with blast's colour**, a bolt no `shots()` entry ever actually fires;
## bolt 0 goes out fire-alone, bolt 1 goes out water+blast). `shots()[0]` is always socket 0's **own**
## element and glyph together — the same real, self-consistent combination that actually leaves first
## (12 o'clock, `shots()`'s own header). For the round circle `shots()[0]` **is** `{element(), packed_glyphs()}`
## unchanged (`PIC_TRIANGLE` never reaches the branch that would differ), so this is byte-identical there.
static func staff_ring_tint(circle: SpellCircle) -> Color:
	if not circle.can_fire():
		return staff_tint(Glyph.GLYPH_NONE, SpellCircle.RUNE_EMPTY, false)
	var first: Dictionary = circle.shots()[0]
	return staff_tint(int(first["glyphs"]), int(first["element"]), true)


static func staff_tint(glyphs: int, element: int, can_fire: bool) -> Color:
	if not can_fire:
		return DEAD_TINT
	if glyphs == Glyph.GLYPH_NONE:
		return ELEM_FX.get(element, ELEM_FX_MISSING)["glow"]
	return GLYPH_TINT.get(Glyph.first(glyphs), GLYPH_TINT_MISSING)


## ---------------------------------------------------------------------
## The background (`src/view/sky_background.gd`). The concept is `docs/design/background.md`.
##
## **These values alone put nothing on screen.** The grid sprite covers the world opaquely, so
##  **empty cells have to be pulled out as transparent** by `cell_grid.gdshader`'s `empty_id` before it becomes visible.
##  The three are one set — the shader · the injection in `cell_renderer` · the node order in `stage.tscn`.
##
## ~~**It forces a night palette.**~~ **Reversed — stage 1 is daylight** (decided by the user, `background.md`).
##  The prediction was that a bright background kills the silhouettes; measured on the mockup it does the opposite,
##  because the terrain (`#5C574F` · `#232228` · `#6B4524`) is far darker than a daylit field.
## Measured (verify-look): bedrock `(35,34,40)` standing in front of empty `(14,14,19)` was
##  **21 per channel apart and completely invisible to the eye.** The purpose of the background is to fill that place —
##  **that reason survives the palette flip**, and daylight separates them further, not less.

const BG_Z_INDEX := -100          ## Clearly behind the grid (`CellRenderer`). Hung doubly with the scene order

## The picture. **A mirrored pair (1920x544) — the right half is the left flipped**, so the left and right edges
##  are the same column and tiling shows no seam. FLUX will not match seams; mirroring is what removes them.
##  Built by `tools/pixel/bgmock.py`'s source images -> `assets/stage/bg_*.png`.
## **Two layers.** Far is the scenery, near is the strip at the player's feet (a fence line · rubble).
##  **The near one has a transparent sky** — cut from chroma green, so it lays over the far one.
const BG_FAR_TEXTURE := "res://assets/stage/bg_farm.png"
const BG_NEAR_TEXTURE := "res://assets/stage/bg_near_farm.png"
## The town's pair. **The same node, a different picture** (`town.md`) — not a second scene.
const BG_TOWN_FAR_TEXTURE := "res://assets/stage/bg_town.png"
const BG_TOWN_NEAR_TEXTURE := "res://assets/stage/bg_near_town.png"

## Parallax ratios. **0 = pinned to the window (infinitely far), 1 = nailed to the world (part of the terrain).**
const BG_FAR_SCROLL_X := 0.25
## **The vertical is much weaker than the horizontal on purpose.** The world is 4,032px tall against a 544px picture,
##  so at the horizontal ratio the picture would leave the screen entirely within one fall.
const BG_FAR_SCROLL_Y := 0.08
const BG_NEAR_SCROLL_X := 0.65   ## Near enough to read as "just behind the terrain", not so near it competes with it
const BG_NEAR_SCROLL_Y := 0.45

## Where each layer sits when its ratio is 1 (world px). **+ is downward.**
## The far one is the horizon — tuned by eye against the spawn point.
const BG_FAR_ANCHOR_Y := 300.0
## The near one is **the ground line the strip stands on**: the map's left half is flat at tile y 20,
##  and 20 x `TILE_CELLS` 8 x `CELL_PX` 4 = 640. **The strip's bottom is placed there, so its own height is
##  subtracted at draw time** — change the picture's height and it still stands on the ground.
const BG_NEAR_GROUND_Y := 640.0

## **Underground depth — `docs/design/underground-depth.md`.** Below the far picture (which now stops at
##  the ground line, `sky_background._draw()`) the old fill was one flat color sampled from the far
##  picture's own bottom row — measured `#7EB356`, a bright grass green standing in for bedrock. These
##  bands replace it, darkening toward bedrock as depth grows.
##
## **The bottom of the range is derived, not guessed.** `CellGrid` is 4096x1008 cells but the map is only
##  300x48 tiles (384 cells tall) seated at (0,0) — 62% of the grid's height is `EMPTY`, off the map entirely,
##  and a range tuned against `CellGrid.H` lands at a third of what it was tuned for (measured in the doc).
##  `TerrainMap.MAP_H` x `TILE_CELLS` x `CELL_PX` is the map's real floor in world px (48 x 8 x 4 = 1536).
const TerrainMap := preload("res://src/stage/terrain_map_generated.gd")
const BG_UNDER_TOP_Y := BG_NEAR_GROUND_Y   ## Reuses the ground line — not a second "where the ground is".
const BG_UNDER_BOTTOM_Y := 1.0 * TerrainMap.MAP_H * Tuning.TILE_CELLS * Tuning.CELL_PX

## **Hard bands, not a smooth gradient** — banding is the pixel-art-native answer the doc measured
##  against three reference games (Motherload's strata), a gradient reads as photo, not tile.
## Top to bottom, ending near bedrock's `#232228` (`cell_materials.gd`'s `BEDROCK` rgb — matched by eye
##  here, not derived, since this is a screen-only fill and not a material the sim tracks).
## **Provisional** — the doc's own open question is how many bands and where they break; not yet looked
##  at on screen.
const BG_UNDER_BANDS: Array[Color] = [
	Color(0.290, 0.224, 0.157),  # #4A3928
	Color(0.227, 0.180, 0.141),  # #3A2E24
	Color(0.173, 0.153, 0.153),  # #2C2727
	Color(0.137, 0.133, 0.157),  # #232228 — matches BEDROCK
]

## **The shader-side depth dim's own normalization** (`cell_grid.gdshader`'s `depth_span` uniform) — the
##  `UV.y` fraction where the map's own floor sits, the same "derive it, don't use `CellGrid.H`" reasoning
##  as `BG_UNDER_BOTTOM_Y` above, just expressed as a 0..1 fraction of the grid instead of world px.
const CellGrid := preload("res://src/sim/cell_grid.gd")
const CELL_DEPTH_SPAN := 1.0 * TerrainMap.MAP_H * Tuning.TILE_CELLS / CellGrid.H
## How dark the deepest cells get (multiplied into rgb, 1.0 = no dim). Provisional, same as the bands above.
const CELL_DEEP_DIM := 0.6

# --- town (`docs/design/town.md`) ------------------------------------
## **Kind -> its sprite and the size it is drawn at.** The art exists (`assets/town/`) and these are its own
##  pixel sizes, **scaled up by `TOWN_FIXTURE_ZOOM`** — the pieces were generated small (36x36 · 44x32 · 36x44)
##  and at 1:1 a bench is barely taller than the 32px character, which reads as scenery rather than as
##  something to walk up to.
##
## **The size is written down and not read off the texture.** The same discipline `MONSTER_SHEETS` records:
##  the drawing side asks this table, so a swapped png draws at the size the game expects and the mismatch is
##  caught by `net_town` as a value, instead of the fixture silently changing size on screen.
const FixturesDefs := preload("res://src/actor/fixtures.gd")
const TOWN_FIXTURE_ZOOM := 2.0
const TOWN_FIXTURES: Dictionary = {
	FixturesDefs.KIND_RESEARCH: {"path": "res://assets/town/research_bench.png", "w": 36.0, "h": 36.0},
	FixturesDefs.KIND_ASSEMBLY: {"path": "res://assets/town/assembly_bench.png", "w": 44.0, "h": 32.0},
	FixturesDefs.KIND_GATE: {"path": "res://assets/town/departure_gate.png", "w": 36.0, "h": 44.0},
}

## **The fallback block, kept and not deleted.** It is drawn only when a sprite fails to load — the same
##  substitute-do-not-bark rule `MONSTER_FILL` holds, and for the same reason: a fixture you cannot see is a
##  fixture you cannot find, and a magenta box says "the art broke" where nothing says nothing.
const TOWN_FIXTURE_FALLBACK := Color(0.78, 0.22, 0.42, 1.0)

## The name plate above every fixture, and the prompt that appears only on the one you are standing at.
## **Both are always drawn for every fixture except the prompt** — a name you can only read by walking into
##  it makes the room unreadable from across it, which is the one thing a walkable room has over a menu.
const TOWN_NAME_SIZE := 14
const TOWN_NAME_COLOR := Color(0.85, 0.85, 0.88, 0.75)
const TOWN_NAME_LIFT_PX := 10.0
## **The prompt is brighter and sits above the name**, so "I can use this" is a different sentence from
##  "this is a bench", not the same sentence louder.
const TOWN_PROMPT_SIZE := 18
const TOWN_PROMPT_COLOR := Color(1.0, 0.95, 0.72, 1.0)
const TOWN_PROMPT_LIFT_PX := 30.0
## **The key is written into the text, not left implicit.** The town does not explain anything
##  (`town.md`, "the town does not explain anything") — but *which key* is not an explanation, it is a label,
##  and with no tutorial in the game yet there is nowhere else for it to be said.
const TOWN_PROMPT_FMT := "[E] %s"
## **연구대's own prompt — 「준비중」, not `TOWN_PROMPT_FMT`** (`onboarding-and-palette-tabs.md` Stage 7).
##  This is the visible seat: `_town_message` sits behind F3 (`stage._update_hud`'s own gate), so a player
##  who never opens the debug HUD would never see it there. The bench's real feature is not deleted —
##  `Progress.buy()`/`UnlockDefs`/`research_window.gd` all stay reachable through code; only this door closes.
const TOWN_RESEARCH_PROMPT := "준비중"

## **Rune names, in Korean, because the player reads them** (CLAUDE.md's language rule).
##  **They live here and not in `sim_tuning`** for the same reason every other string does: `src/sim/` is the
##  integer sim and knows nothing about what anything is called. Until now runes were only ever *drawn* (the
##  palette tells them apart by colour), so no name existed anywhere — the town's research bench is the first
##  place that has to say one out loud.
const ELEM_NAMES: Dictionary = {
	Tuning.ELEM_FIRE: "불",
	Tuning.ELEM_NONE: "무",
	Tuning.ELEM_WATER: "물",
}

# --- the research window (`docs/design/town.md`, "Research bench — two lists") ---
## **The panel is a 9-slice.** `research_panel.png` is a 512x512 stone frame with a parchment middle; drawn
##  at any other size by stretching, the corner stones smear. `draw_texture_rect` cannot 9-slice, so the
##  window cuts nine regions itself (`research_layout.nine`) — the corners 1:1, the edges tiled along one
##  axis, the middle tiled both ways.
## **The border width is measured off the art**, not guessed: the frame's inner edge sits ~46px in.
const RESEARCH_PANEL := "res://assets/ui/research_panel.png"
const RESEARCH_PANEL_BORDER_PX := 46.0

## **One slot frame, cut out of `slot_row.png`.** That png is a row of three slots at 512x320 — the **left**
##  one wears a chain and padlock and the other two are empty, so the same image carries both states and the
##  window cuts whichever it needs. A third of 512 is 170.67, so the cuts are 0..171 and 171..341: rounded,
##  because a slot frame is decorative and a pixel of bevel either way is invisible, unlike the fixture
##  sprites where the size is a contract.
const RESEARCH_SLOT_SHEET := "res://assets/ui/slot_row.png"
const RESEARCH_SLOT_LOCKED_SRC := Rect2(0.0, 0.0, 171.0, 320.0)
const RESEARCH_SLOT_OPEN_SRC := Rect2(171.0, 0.0, 170.0, 320.0)
## How big one slot is drawn. **Square, though the source is taller than wide** — the source's extra height is
##  the stone course above and below the recess, and squaring it keeps the icon inside centred.
const RESEARCH_SLOT_PX := 56.0

## The four unlock axes' icons, and the material's. **White silhouettes**, so they are tinted at draw time
##  (`RESEARCH_ICON_*` below) rather than existing twice in two colours.
const RESEARCH_ICONS: Dictionary = {
	"point": "res://assets/ui/icon_point.png",
	"item": "res://assets/ui/icon_item.png",
	"body": "res://assets/ui/icon_body.png",
	"dice": "res://assets/ui/icon_dice.png",
	"material": "res://assets/ui/icon_material.png",
}
## **The four rows, in the doc's own order** (`town.md`'s slot table: points · items · body · dice).
##  Each is `[icon key, name, what it buys]` — the third column is the whole reason a locked list is worth
##  showing at all ("unlocked and locked sitting in one list is the best possible demonstration that the pool
##  widened"). **Nothing here is a knob**: no price column, because there is no price (that doc's own TBD).
const RESEARCH_ROWS: Array = [
	["point", "점수", "가져갈 수 있는 양"],
	["item", "아이템", "고를 수 있는 진·룬·문양"],
	["body", "신체", "2단 점프 같은 것"],
	["dice", "주사위", "세 장 뽑기를 다시 굴린다"],
]

const RESEARCH_ICON_PX := 24.0
## Dark, because the panel's parchment is bright — the same "far apart from what it sits on" rule every other
##  colour in this file follows.
const RESEARCH_ICON_COLOR := Color(0.24, 0.19, 0.14, 1.0)
const RESEARCH_TITLE := "연구대"
const RESEARCH_TITLE_SIZE := 22
const RESEARCH_TEXT_SIZE := 15
const RESEARCH_DIM_SIZE := 13
const RESEARCH_INK := Color(0.24, 0.19, 0.14, 1.0)
## The "not buyable yet" line and the locked labels — the same ink, faded, so they read as the same hand.
const RESEARCH_INK_DIM := Color(0.24, 0.19, 0.14, 0.62)
## **The footer says what the bench cannot do.** `town.md` says the town explains nothing, and this is not an
##  explanation — it is the state of the bench, and leaving it unsaid would make an inert list look broken.
## **It stopped saying "there is nothing to unlock yet"** (`research-bench-unlocks.md`) — three unlocks are
##  for sale now, and a footer still denying it would be the bench lying about itself on screen.
## **A format, not a sentence, so the price is printed from `progress.GEMS_PER_UNLOCK` rather than typed
##  here.** Typed as a literal, retuning the price would move the number the player is charged and leave the
##  number the player reads behind, with nothing barking.
const RESEARCH_FOOTER_FMT := "해금 하나에 원석 %d · [E] 닫기"
const RESEARCH_LOCKED_TEXT := "잠김"
## The currency line. **원석** — `docs/decisions/gems-from-bosses-and-levels.md` named it.
const RESEARCH_GEMS_FMT := "원석 %d"

## **The research window's rect. Smaller than `WINDOW_RECT`, deliberately.** The assembly window is 90% of
##  the screen because it is a workbench you arrange things on; this is a list you read, and a list stretched
##  across 864px puts four short lines in a field of parchment. Centred on the 960x540 viewport.
const RESEARCH_RECT := Rect2(240, 70, 480, 400)

# --- the run-end settlement screen (`run-end-settlement.md`) ---
## **The whole 960x540 canvas, not a partial window.** Every other window in this file (`WINDOW_RECT`,
##  `PICK_RECT`, `RESEARCH_RECT`) leaves the world visible on purpose — this is the doc's own declared
##  exception: "the world is not visible behind it and the sim stops — the run is over, so there is nothing
##  left to watch". `circle_window.gd`'s own header names why no other screen may do this while a run is live.
const SETTLEMENT_RECT := Rect2(0, 0, 960, 540)

## Opaque, the same reasoning `WINDOW_BG`'s own comment gives for every other window here — and doubly so once
##  the world genuinely is gone rather than merely covered.
const SETTLEMENT_BG := Color(0.05, 0.055, 0.085, 1.0)
const SETTLEMENT_EDGE := Color(0.62, 0.5, 0.35, 0.9)
const SETTLEMENT_EDGE_PX := 2.0
const SETTLEMENT_PAD_PX := 48.0

const SETTLEMENT_TITLE := "런 종료"
## **The gate's own title** (`gate-ending-to-game.md`, Stage D) — a death and a clear must
##  not read identically on the one screen this whole feature exists to produce. Nothing downstream reads the
##  string itself (`settlement_window._draw` only branches on the `cleared` bool), so it is this one constant.
##
## **No longer provisional.** `gate-ending-to-game.md` shipped `"런 클리어"` as a placeholder and named the
##  swap as the one thing the user had to decide; `stage-clear-sequence.md`'s own string table decides it.
##  **It says which stage was cleared** — the notice below tells the player there is no second one, and that
##  only reads as information if the title already said this was stage 1.
const SETTLEMENT_TITLE_CLEAR := "스테이지 1 클리어"
const SETTLEMENT_TITLE_COLOR := Color(0.86, 0.90, 0.98)
const SETTLEMENT_TITLE_SIZE := 30

## **Only 원석 moves — the doc's own words.** Time and damage are printed once and never touched again;
##  these two colors are shared by every row's label/value so a future row cannot quietly pick its own palette.
const SETTLEMENT_ROW_LABEL_COLOR := Color(0.72, 0.76, 0.86)
const SETTLEMENT_ROW_VALUE_COLOR := Color(0.92, 0.94, 1.0)
const SETTLEMENT_ROW_SIZE := 20

const SETTLEMENT_TIME_LABEL := "플레이 시간"
const SETTLEMENT_DAMAGE_LABEL := "준 피해"
const SETTLEMENT_GEMS_LABEL := "원석"

## **The 원석 icon is `RESEARCH_ICONS["material"]` reused, not a sixth entry** — it was drawn white-on-
##  transparent for exactly this reuse (`RESEARCH_ICONS`'s own header). Tinted light here, not the dark
##  `RESEARCH_ICON_COLOR` — that tint was chosen against the research window's bright parchment; this screen's
##  background is dark, the same reasoning `SETTLEMENT_ROW_VALUE_COLOR` above already follows.
const SETTLEMENT_ICON_PX := 24.0
const SETTLEMENT_ICON_COLOR := Color(0.92, 0.94, 1.0)

const SETTLEMENT_BUTTON_TEXT := "마을로"
## **A distinct warm fill, not `SETTLEMENT_BG` again** (verify-read's own finding — the button used to be told
##  apart only by its 2px edge, against a background it was otherwise identical to). Warm against the panel's
##  cool dark blue-black, the same "far apart from what it sits on" rule this file's other colors already
##  follow (`RESEARCH_ICON_COLOR`'s own comment) — this is the one thing on the screen meant to be pressed.
const SETTLEMENT_BUTTON_BG := Color(0.16, 0.13, 0.08, 1.0)
const SETTLEMENT_BUTTON_EDGE := Color(0.85, 0.68, 0.35, 1.0)
const SETTLEMENT_BUTTON_TEXT_COLOR := Color(0.92, 0.94, 1.0)

## **The count-up's whole rate, in frames per point** — the doc's own "the count-up is the whole animation".
##  Read only by `settlement_layout.count_value`, so this is the one place to slow or speed it once it is seen
##  on screen (verify-look's own job — "does the count-up read as counting, the rate, not the endpoints").
const SETTLEMENT_COUNT_FRAMES_PER_POINT := 3

## **Two lines saying the build ends at stage 1** (`stage-clear-sequence.md`, Beat 4).
##  Drawn on a clear only — a death is not the end of the content.
##
## **Two constants rather than one wrapped sentence**: `draw_string` does not wrap, and hand-wrapping a
##  40-character sentence is a layout problem for text that gets deleted the day stage 2 exists.
##
## **Neither line apologises, thanks anybody, or promises anything.** They are the user's own words shortened
##  by one clause, in the same plain voice `docs/submission/README.md`'s risk list is written in.
const SETTLEMENT_NOTICE_1 := "지금은 여기까지만 개발돼 있습니다."
const SETTLEMENT_NOTICE_2 := "스테이지 2는 아직 없습니다."
## Dimmer and warmer than `SETTLEMENT_ROW_VALUE_COLOR` — it is an aside about the build, not a figure from
##  the run, and the two must not read as the same kind of thing.
const SETTLEMENT_NOTICE_COLOR := Color(0.78, 0.70, 0.52)
## Under `SETTLEMENT_ROW_SIZE` (20) — smaller than the numbers it sits below, larger than nothing.
const SETTLEMENT_NOTICE_SIZE := 18

# --- stage 1's ending, the beats (`stage-clear-sequence.md`) ---
## **Named, not pathed** (GDD's own rule): a doc under `docs/plans/` changes folders as its status changes,
##  so a path into it dies the day it moves — and it dies **silently**, since nothing compiles a comment.
##  This one had already gone stale once (`1.ready/` → `3.done/`) before the prefix came off. The bare name
##  is greppable and cannot rot. **Every citation in this file follows it.**
## **The east wall coming down, felt rather than seen.** The player is 300-600px west of that wall and, per
##  `net_gate`'s own camera check, it is off screen from most of the room — so this is a shake and not a
##  picture. `blast_fx.kick()` is the one door; `_kick`'s "the stronger one wins" rule still applies.
##
## **7px is larger than any blast in `FX_SIZES`** and 0.35s is longer than `SHAKE_SEC` (0.20, a bolt) — a
##  twelve-tile stone wall reads as *something collapsed*, not as *something hit me*, and length is what
##  carries that difference.
const GATE_WALL_SHAKE_PX := 7
const GATE_WALL_SHAKE_SECS := 0.35

## **Physics frames, both of them — 0.4s at 60Hz.** `gate_view.tick_gate()` is called from
##  `stage._sync_settlement()`, which is physics; put either counter on `_process` and 24 frames becomes
##  0.167s on a 144Hz panel, with nothing barking. `project.godot` never sets
##  `physics/common/physics_ticks_per_second` (grepped), so this is Godot's default 60 and not a project
##  value — the day someone sets it, both constants change meaning silently.
##
## **`GATE_TAKE_FRAMES` is safe at any length only because the take latches** (`gate_view.tick_gate`'s own
##  header): a running player crosses the 96px band in ~22 frames, so a resettable hold near this length
##  would simply never fire.
const GATE_ARCH_FADE_FRAMES := 24
const GATE_TAKE_FRAMES := 24

## The colour the arch reaches while it is taking you. **Over-bright warm, and the over-1 components are the
##  point**: the renderer is `gl_compatibility` (`project.godot:88`) — no 2D HDR, no glow, and nobody should
##  later reach for either to "fix" this. What produces the flare is that the arch's dark linework and mid
##  greys multiply up into bright warm tones while only the already-near-white pixels saturate. **Clamping is
##  what limits the effect, not what creates it.**
##
## **Never rendered.** Only verify-look can say whether this reads as flaring; every net asserts the colour
##  handed to `gate_view._paint_arch`, never pixels. Fallback if it does not read: a ramp with no component
##  above 1, toward a warm near-white.
const GATE_TAKE_TINT := Color(1.7, 1.6, 1.25, 1.0)

# --- the air-jump ring (`research-bench-unlocks.md`) ---
## **A second jump with no mark reads as a bug the first time it fires.** That is the whole job of these
##  three: the town unlock changes what the character can do, and CLAUDE.md's signature failure is the sim
##  changing while the screen does not.
##
## **Every value here is a starting value, not a tuned one, and nobody has seen any of them.** Whether a ring
##  is even the right mark — versus a puff, a stretch of the sprite, or a sound — is that doc's own TBD.
##  Radius is set against the character's collision box (`character.W_PX` = 20) so the ring reads as *at the
##  feet* rather than as a halo around the whole body; the colour is the pale warm the staff ring already
##  uses for "this came from you", at reduced alpha so it does not compete with the character sprite.
##
## **Never rendered.** Only verify-look can say whether it reads. Every net asserts the arguments handed to
##  `character_view._paint_air_jump_ring`, never pixels — the same discipline `GATE_TAKE_TINT` above holds.
##
## **The ring's lifetime is not here.** It is `character.AIR_JUMP_FLASH_TICKS`, because the counter is sim-side
##  state the screen reads (`invuln_left`'s own precedent) — a second copy of the duration in this file would
##  be a second clock, which is exactly what that comment forbids.
const AIR_JUMP_RING_R_PX := 13.0
const AIR_JUMP_RING_PX := 2.0
const AIR_JUMP_RING_COLOR := Color(1.0, 0.93, 0.72, 0.85)

# --- onboarding (`onboarding-and-palette-tabs.md` Stage 7) ---
## **Tab is a key, not a thing on screen** — the design's own named problem, and the reason this exists at
## all: the HUD key line already says "Tab 조립창", but it sits behind F3 (`stage._update_hud`'s own gate),
## so it is not a target a fresh player can ever see. `onboard_view` draws its own key cap instead.
##
## **Every value below is a starting value — nobody has judged any of them.** Seat: bottom-centre, above the
## HUD band (the plan's own stated default). Small and off to the side on purpose — **not full-screen**
## (CLAUDE.md risk: a full-screen `Control` while the run is live kills "you can shoot with the window open").
const ONBOARD_RECT := Rect2(430.0, 430.0, 100.0, 80.0)

## The "Tab" key cap — a small rounded-looking chip with the key name inside.
const ONBOARD_KEY_W_PX := 44.0
const ONBOARD_KEY_H_PX := 26.0
const ONBOARD_KEY_BG := Color(0.14, 0.15, 0.20, 0.95)
const ONBOARD_KEY_EDGE := Color(1.0, 0.92, 0.55, 0.95)
const ONBOARD_KEY_EDGE_PX := 2.0
const ONBOARD_KEY_TEXT := "Tab"
const ONBOARD_KEY_TEXT_SIZE := 14
const ONBOARD_KEY_TEXT_COLOR := Color(1.0, 0.95, 0.8, 1.0)

## The arrow — directly above the key cap, pointing down at it. A filled triangle, the simplest shape that
## reads as "there, specifically" without needing new art for a first slice.
const ONBOARD_ARROW_W_PX := 22.0
const ONBOARD_ARROW_H_PX := 26.0
const ONBOARD_ARROW_GAP_PX := 6.0
const ONBOARD_ARROW_COLOR := Color(1.0, 0.92, 0.55, 0.95)
