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

# -- the eleven species ------------------------------------------------
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
## The four added last, and they take the **violet / rose / teal** block because nothing else occupies it:
## every warm hue is spoken for (다람쥐 tan · 사자 orange · 까마귀 red · 호스트와 분신 yellow · 바위 and
## 시체 warm grey). Ratios against `BG` computed the same way: 들쥐 7.49:1 · 토끼 8.85:1 · 들개 4.66:1 ·
## 멧돼지 5.17:1, all clear of the 3.9 floor this block states.
##
## ⚠ **The pairs at risk are named, because "they are all different colours" is not a separation argument:**
##  · 들쥐 vs 보스 — same violet family, separated by saturation (0.25 vs 0.59) and by **radius 5 vs 48**,
##    and the boss also arrives under a full-screen wash and a screen-edge arrow
##  · 들쥐 vs 들개 — same hue family **on purpose** (both are 잡몹), separated by lightness and by radius
##    5 vs 10, the same device this file already uses for 다람쥐 against 사자
##  · 멧돼지 vs 치타 — teal against cyan, and the cheetah carries three afterimage ghosts the boar never has
##  · 토끼 vs 호스트 — rose against yellow, and the rabbit's `SPECIES_SPEED_MUL` 1.05 puts it inside the
##    afterimage gate too, which is wanted: the trail is the mark that says "this one out-runs you"
const MOUSE_COLOR := Color(0.70, 0.60, 0.80)
const RABBIT_COLOR := Color(0.86, 0.64, 0.66)
const DOG_COLOR := Color(0.60, 0.40, 0.82)
const BOAR_COLOR := Color(0.20, 0.58, 0.55)

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
## × the corpse's own radius **as DRAWN** (i.e. after `CORPSE_SHRINK_*`), the same shape `SPLIT_CHARGE_RING`
## has. The ring is around the corpse, so it shrinks with it; at the last bite an unshrunk one is a hoop 3.3×
## the body's diameter with nothing inside it. Left unstated, the arc's radius becomes a literal inside
## `field_view.gd` and this file stops being the one place a size lives.
const CORPSE_PROGRESS_RING := 1.5
## The DRAWN corpse shrinks as it's eaten: `corpse_radius(i) × (CORPSE_SHRINK_BASE + CORPSE_SHRINK_RANGE ×
## bites_left/bites_total)`, floor at 45% so a nearly-finished corpse is still findable rather than a dot.
## **Visual only** — `World.corpse_radius()` itself, which `corpse_reach()` also reads, never shrinks; a
## half-eaten boss must stay as easy to keep eating as a whole one.
const CORPSE_SHRINK_BASE := 0.45
const CORPSE_SHRINK_RANGE := 0.55

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

# -- the fork nobody has decided: is the body a fill or a line ----------------------------------
## Which of the THREE body pictures the field draws. FILL is what the build has drawn since plan 1 — a
## shadow, a filled blob and a lit top edge, and nothing else. LINE is 갈래 ㄱ: what
## `the-body-is-a-line-drawn-by-code` decided by generating candidates and looking at them, and what the cell
## GDD's 화면 section describes — a rounded square stroked as a line, one dot at its centre, and nothing
## between them. RIM is 갈래 ㄴ: the body stays filled and legibility is bought with three marks instead —
## every body y-sorted into one pass, one dark stroke on each body's own silhouette, and a ring on the ground
## under the host. `melee-legibility-ko` opens that fork and **nobody has picked** — all three pictures are
## built so the user can look at photographs of one field, which is how art is decided in this repo.
##
## ⚠ **FILL is not a third candidate anybody proposed — it is today's picture, kept as the control.** Neither
## the rim nor the sort nor the host mark may reach it, or the comparison has no unchanged shot in it.
##
## ⚠ **A `static var` and not a `const`, for a measured reason.** A `const` folds one branch into the build
## and leaves the other as unreachable text: a net could then only ever drive whichever branch happens to be
## selected, and half the drawing code would ship unmeasured. Written this way one net flips it, pumps
## frames and asserts the two branches reach different leaves — which is the whole defence against a switch
## that changes nothing on screen while the round stays green.
##
## **It ships as LINE — the user picked it by looking at the three shots, and said so in those words**
## ("가운데 빈 거"). FILL stays as the control the comparison rests on and RIM stays reachable; neither is
## the picture the game opens with any more. `field_view.gd` is its only
## reader in `src/`; nothing in `src/sim/` may read it, because it moves no radius, no reach and no
## separation distance. A net that flips it must set it back inside the same check — a `static var` is
## process-global and every net in one file shares a process.
enum BodyStyle {FILL, LINE, RIM}
static var BODY_STYLE: int = BodyStyle.LINE

## 갈래 ㄱ's stroke, as a multiple of the body's own radius, floored and capped. **A multiple and not a flat
## number**, because this one stroke has to serve every body on the field and they span 16× — a crumb at
## radius 3 against a full-force boss at 72. A flat 2px is a hairline on the boss and a third of the
## squirrel. The floor is what keeps a 7px 다람쥐 and an empty 8px clone from thinning into nothing; the cap
## is what stops the two largest species reading as blocks rather than as outlines.
##
## ⚠ **This is the one place the "line widths are absolute" convention above is deliberately not followed**,
## and that convention's own reason — a limb that thins with the body disappears — is answered by the floor
## instead. It was written for parts on one body at one size, not for one stroke across eleven.
const OUTLINE_WIDTH_RING := 0.14
const OUTLINE_WIDTH_MIN := 1.5
const OUTLINE_WIDTH_MAX := 6.0

## 갈래 ㄱ's nucleus. **One dot, centred** — the whole of what `the-body-is-a-line-drawn-by-code` decided,
## and the opposite of the two mirrored dots `EYE_DOT_OFFSET` above places. A multiple of the body's radius
## so it cannot slide off as a species is retuned, floored so the smallest bodies still read as alive rather
## than as a plain empty square, which is the row that decision's own rejection table calls
## 「점이 아예 없는 것」.
const OUTLINE_DOT_RING := 0.22
const OUTLINE_DOT_MIN := 2.0

## 갈래 ㄴ's dark rim, traced on every body's own silhouette — every clone, every creature, the host. **One
## tone for every body**, never a darkened copy of each body's own colour: the rim's job is to say "two
## bodies", and a per-body rim says "which body", which is a different question and the one `SPECIES_COLOR`
## already answers. Fatshark's crowd-legibility read is the source `melee-legibility-ko` cites for it.
##
## ⚠ **Deliberately BELOW the field's contrast floor against `BG`, and above it against `CROW_COLOR`** — the
## darkest body it ever borders. A rim that read against grass would be a second outline drawn on empty
## ground; what it has to separate is body from body. `net_numbers` measures both ends, because a floor on
## one end and none on the other is half-measured.
##
## Not on food, not on a corpse, not on an afterimage ghost — three hard edges on a fading trail is the
## opposite of what a trail says — and not on rocks or ponds, which are terrain.
const BODY_RIM_COLOR := Color(0.05, 0.04, 0.04, 0.85)
## Absolute px, the convention `PART_LIMB_WIDTH` and `CLONE_HIT_LINE_WIDTH` already follow: a rim that scaled
## with the body would vanish on the smallest one. **And a fraction cap, because absolute alone EATS the
## smallest body** — a flat 2px rim on a 7px 다람쥐 is over half its diameter. `FieldView._rim_width()` is the
## one place the two meet, and it is a pure function so a net can pin both ends and the knee.
const BODY_RIM_WIDTH := 2.0
const BODY_RIM_MAX_FRACTION := 0.18

## 갈래 ㄴ's host mark: the one permanent thing on screen that says which body is you. **A ring on the
## GROUND, not on the body** — a standing outline on the host would eat the `HIDE` square's only visible
## payout, which `melee-legibility-ko` names as that option's cost, and this candidate already spends the
## same stroke on the rim above.
##
## A multiple of `Rules.BODY_RADIUS`, the `_RING` convention every anchor in this file uses. 2.2 puts it well
## outside a fully loaded clone (`CLONE_BODY_RADIUS × CLONE_LOAD_GROWTH`) so a clone standing on the host
## cannot be read as the ring's owner, and clear of `SPLIT_CHARGE_RING`'s 1.6 so the `F` wind-up is not read
## as the same mark.
##
## The host's own hue, because it is the host's mark and not a UI element — so its contrast against `BG` is
## `HOST_COLOR`'s, which `net_numbers` already measures. ⚠ **It answers "which one is me" when the host is
## AMONG bodies, never when it is buried under forty of them**; a pile is wider than this ring. The fallback
## if the photograph says the pile wins is to move the single call into the overlay beside the `F` arc, at
## the cost of reading as UI drawn over bodies — and that is a decision for eyes, not for a builder.
const HOST_MARK_RING := 2.2
const HOST_MARK_WIDTH := 2.0
const HOST_MARK_COLOR := Color(0.96, 0.88, 0.52, 0.55)

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

# -- hit feedback: a monster's flash and spark, the host's shake and edge vignette -------------------------
## How long a hit's flash, spark, bloom and wave last, read against `World.critter_hit_show` /
## `Swarm.hit_show`.
## ⚠ **This was 0.09 and the user's answer to the whole presentation pass was that none of it was visible**
## — *"과할 정도로 보여주는 게 핵심인데"*. 0.09s is five frames at 60fps, which is a value a net cannot
## judge and an eye cannot catch. Doubling it is the cheap half; the bloom and the wave below are the half
## that adds AREA, which is what a hit on 갈래 ㄱ's hollow body has none of.
const HIT_FLASH_TIME := 0.18
## **Mixed toward, never painted over.** A flat overpaint on forty simultaneous hits reads as the field
## going white and erases which one was actually hit — see the call site in `field_view.gd`.
const HIT_FLASH_COLOR := Color(1.0, 1.0, 1.0)
## ⚠ **The CEILING of that mix, and it is strictly under 1.0 for a reason the sentence above only half
## covered.** The weight is `1 - hit_t / HIT_FLASH_TIME`, which is exactly 1.0 on the frame the hit lands —
## `critter_hit_show` is written `0.0` and the view reads it before the next `+= dt` — so "mixed toward" was
## a flat overpaint for one frame on every single hit, forty at a time, which is the state §B-1 names and
## forbids. Scaling the weight by this keeps the peak bright and keeps the species colour underneath it.
const HIT_FLASH_STRENGTH := 0.75
## The hit spark shrinks from this to 0 over `HIT_FLASH_TIME`, at the struck point — through `_paint_disc`,
## the leaf rocks and ponds already use, so this is not a new leaf.
const HIT_SPARK_R := 16.0

## The bloom and the wave: the two marks that give a hit AREA rather than a tint.
##
## ⚠ **A tint has no area on a hollow body.** 갈래 ㄱ draws the body as a stroke, so `HIT_FLASH_STRENGTH`
## repaints two pixels of outline and nothing else — the whole reason the flash read as absent. The bloom is
## a filled halo that grows from the body's own radius to this multiple of it, and the wave is a ring that
## leaves the body. Both are drawn UNDER the body (see `_paint_hit_bloom`), so the body stays the thing you
## read and the light is what changed around it.
##
## Both ride `HIT_FLASH_TIME` and the body's own `hit_show` column — **no view-owned timer**, so `Tab`, the
## card offer and the ending stop all four marks of a hit together (§0-2 of 연출 한 판).
const HIT_BLOOM_R_MUL := 2.6
const HIT_BLOOM_COLOR := Color(1.0, 0.98, 0.86, 0.55)
const HIT_WAVE_R := 30.0
const HIT_WAVE_WIDTH := 3.0
const HIT_WAVE_COLOR := Color(1.0, 1.0, 1.0, 0.9)

## The screen shake: amplitude per point of the landing hit's force, capped, and how long it takes to decay
## to exactly zero. `shell/main.gd` owns the function that applies these — see `_apply_shake()` — because
## the camera lives there; this file owns only the numbers, which is the §0-3 split.
const SHAKE_PER_FORCE := 0.35
const SHAKE_MAX := 28.0
const SHAKE_TIME := 0.35
## Two different frequencies so the shake is not a straight line back and forth — `sin(t × FREQ)` per axis,
## a pure function of elapsed time so a net can assert "same instant, same offset" rather than trusting
## `Math.random`.
const SHAKE_FREQ_X := 61.0
const SHAKE_FREQ_Y := 47.0

## The edge vignette: a band this wide on all four sides of the screen, alpha carried by
## `host_grace / Rules.HOST_HIT_GRACE` — the same "was just hit" window `HOST_HURT_COLOR` already reads, so
## this owns no clock of its own.
const HURT_VIGNETTE := Color(0.85, 0.15, 0.1, 0.55)
const HURT_VIGNETTE_WIDTH := 40.0
## The cone's fill. Its shape is `Swarm.bite_range` and `Swarm.bite_arc` — the two numbers the sim actually
## tested with on the last bite, never a second pair tuned to look right, or the picture stops being the
## hit. **They are read off the swarm rather than off a constant on purpose**: they used to be
## `Rules.BITE_RANGE`/`BITE_ARC`, and since the parts table landed the range and arc belong to whichever
## part fired — three keys can hold three different ARC parts at three different levels, and a constant
## here would draw one part's cone over another part's hit.
const BITE_COLOR := Color(1.0, 0.86, 0.55, 0.28)

# -- the boss hunts, and it says so ------------------------------------------
## A full-screen wash the instant `World.boss_hunting()` turns true — the boss's own hue, so the flash reads
## as "that thing" rather than a generic warning. Faded, not painted flat: at full alpha for the whole
## window it would hide everything under it for 0.6s straight, and the fade is what reads as the moment
## passing rather than a flicker turning off. `shell/main.gd::_apply_shake()` reuses §B-2's own shake
## machinery for the same moment; this file owns only the wash and the line, the same §0-3 split.
const BOSS_HUNT_FLASH := Color(0.85, 0.35, 0.85, 0.45)
const BOSS_HUNT_FLASH_TIME := 0.6
## The line stays up longer than the wash on purpose — the flash says "now", the line says why.
const BOSS_HUNT_TEXT_TIME := 2.5
const FONT_BOSS_HUNT_TEXT := 32

## The minimap's boss dot, while the hunt is on: it pulses between `MINIMAP_CREATURE_R` and that ×
## this — a pure function of `elapsed`, read in `Hud._minimap_marks()`, so the view holds no timer of its
## own for it (§0-2).
const MINIMAP_BOSS_PULSE_MUL := 2.0
## Radians per second of `elapsed` — how fast the pulse breathes.
const MINIMAP_BOSS_PULSE_FREQ := 3.0

## The screen-edge arrow that points at the boss while it is off camera, in `hud.gd` because it is screen
## space and must not move with the camera — see §D-2. `MARGIN` keeps it off the very edge, where a half-cut
## triangle would read as clipped rather than as a pointer. Its own hue reuses `BOSS_HUNT_FLASH`'s so the two
## read as one thing, at an alpha that stays visible the whole time it is on screen rather than fading.
const BOSS_ARROW_MARGIN := 28.0
const BOSS_ARROW_SIZE := 14.0
## The triangle's own PROPORTIONS, as multiples of `BOSS_ARROW_SIZE`: how far the two back corners sit
## behind the centre, and how far out to each side. They were bare `0.5`s inside `hud.gd::_paint_tri` — the
## last presentation constants left outside this file after plan 5, and invisible to `net_draw_leaf`'s scan,
## which catches colour literals and not pixel ones. Splitting them is what lets the arrow be made sharper
## or blunter without resizing it.
const BOSS_ARROW_BACK := 0.5
const BOSS_ARROW_HALF_WIDTH := 0.5
const BOSS_ARROW_COLOR := Color(0.85, 0.35, 0.85, 0.9)

# -- the arena, once it closes (§E) ------------------------------------------
## The wall the closed arena raises. **Not filled** — a darkened interior would hide the fight it exists to
## frame. ⚠ **And ONE circle**: drawn through `_paint_arc` (a counted leaf already) rather than through
## `_paint_ring`, whose second, inner circle at `r × 0.45` is a marker's echo and lands at 405px on a 900px
## arena — a second wall in the wall's own colour, straight across the fight.
const ARENA_WALL_COLOR := Color(0.95, 0.85, 0.45, 0.55)
const ARENA_WALL_WIDTH := 4.0

## The starting radius of a summoned clone's arrival ring — grown and faded by `BURST_TIME`/`BURST_GROWTH`
## below, the mechanism `§0-4` describes generically ("circles that grow over time and fade").
const ARENA_SUMMON_R0 := 10.0
## **Shared by every burst `field_view.gd`'s `_deaths` list draws**, arena summon included — one growth law,
## several starting sizes. A later step's death burst supplies its own `r0` without touching this pair.
const BURST_TIME := 0.4
const BURST_GROWTH := 2.2

# -- a clone's death, a monster's death, and the clone's own swing line (§B-3, §B-4, §B-5) -------------------
## The clone death burst: base radius plus however much it was carrying, so a fat clone's loss reads bigger
## than an empty one's — the burst radius IS the loss made visible. Colour is the clone's own cargo colour,
## the same lerp `field_view.gd`'s live clone loop already computes from `carried`, so a dying clone's burst
## matches the clone it just was. Grown and faded through `BURST_TIME`/`BURST_GROWTH` above, the same pair
## the arena's summon rings use — one growth law, several starting sizes, never a second one of its own.
const CLONE_DEATH_R_BASE := 10.0
const CLONE_DEATH_R_PER_LOAD := 2.0

## A monster's death burst: its own live radius (read the moment it died, since `critter_radius()` cannot be
## recomputed off a row `_remove_critter()` has already swapped a stranger into) × this — so a boss's burst
## reads bigger than a crow's without a second size table.
const MONSTER_DEATH_R_MUL := 1.4

## The clone's own swing line: how long it stays on screen after a hit lands. **Not a bite cone** — forty of
## those on screen at once is the field disappearing under fans; a single short line toward what the swing
## actually hit is `Swarm.swing_show`'s whole picture.
## ⚠ **0.08s is under five frames at 60fps and the user could not see it at all.** Doubled with the rest of
## the hit marks; the swing is the ONLY thing the attacking side draws, so it is the half of "때리는지
##모르겠다" that lives on the attacker.
const CLONE_HIT_LINE_TIME := 0.16
## Drawn through `_paint_part_line`, the leaf a limb already uses — one line costs no new leaf. Length is a
## multiple of `Rules.CLONE_BODY_RADIUS` (the `_RING` suffix's own convention: a multiple of a body radius),
## so it does not slide off the body as that number is retuned.
const CLONE_HIT_LINE_RING := 3.4
const CLONE_HIT_LINE_WIDTH := 4.0
const CLONE_HIT_LINE_COLOR := Color(1.0, 1.0, 1.0, 1.0)

## The swing every attacker makes, creature and clone alike: the body itself LUNGES at what it is hitting
## and eases back. **This is the "액션" the user said was missing** — until it existed the attacking side
## drew a line at most, and a creature could take your health without anything on screen moving at all.
##
## ⚠ **A drawing offset, not a position.** `sim` never sees it: the lunge would otherwise change who is in
## reach of what, and a body would attack from a place it is not standing. The offset is derived from the
## attacker's own up-counting `swing_show` column, so it owns no timer (§0-2 of 연출 한 판) and `Tab` stops
## it with everything else.
##
## The curve is out-and-back over `SWING_LUNGE_TIME`: peak at the halfway point, zero at both ends, so the
## body never sits displaced. `SWING_LUNGE_PUSH` is absolute px.
##
## ⚠ **This comment used to end "a crow and an elephant lunge the same distance, because it is a gesture and
## not a size", and that sentence is now FALSE and deliberately so.** The per-species gesture pass gave the
## elephant a doubled shove and the lion a tripled pounce — for those two the lunge *is* the gesture, not a
## garnish on one — and the multiplier lives in `SPECIES_LUNGE_MUL` below rather than as two magic numbers at
## the call site. Every other row is 1.0, so the old sentence still describes nine of the eleven.
const SWING_LUNGE_TIME := 0.18
const SWING_LUNGE_PUSH := 14.0

## How far one species lunges, as a multiple of `SWING_LUNGE_PUSH`. **Eleven rows, in `Parts.Species`' own
## order**, the same shape as `FieldView.SPECIES_COLOR` and for the same reason: a short table is an
## index-out-of-range at DRAW time, not at parse time, so `net_field`'s eleven-row scan pins this one beside
## the twelve in `rules.gd`.
##
## Only two rows are not 1.0, and both of them are a whole gesture rather than a tuning:
## **코끼리 밀치기 ×2** (a bar shoved forward, and the body goes with it) and **사자 덮치기 ×3** (the lunge IS
## the pounce — the mark it leaves is one shrinking dot at the landing point and nothing else).
##
## ⚠ **A `const` Array loses element typing**, so every read casts (`float(...)`). Same trap as every
## `SPECIES_*` table in `rules.gd`, and the reason a packed array cannot be used here at all.
const SPECIES_LUNGE_MUL := [1.0, 1.0, 1.0, 1.0, 2.0, 1.0, 3.0, 1.0, 1.0, 1.0, 1.0]
#                        까마귀   말  보스 다람쥐 코끼리  치타  사자  들쥐  토끼  들개 멧돼지

## A creature's own swing line, the mirror of `CLONE_HIT_LINE_*`. **Wider and longer**, because a creature
## is bigger than a clone and a line scaled to a clone vanishes inside a lion. Length is a multiple of the
## creature's OWN radius for the same reason.
##
## ⚠ **`CRITTER_SWING_RING` is the FALLBACK gesture's length now, not every creature's.** Seven species draw
## their own shape (see the block below) and the four that never attack at all can only reach this one
## through a branch the sim cannot enter. It is still the number a species added tomorrow inherits.
const CRITTER_SWING_TIME := 0.18
const CRITTER_SWING_RING := 1.5
const CRITTER_SWING_WIDTH := 5.0
const CRITTER_SWING_COLOR := Color(1.0, 0.86, 0.72, 0.95)

# -- one gesture per species -------------------------------------------------------------------------
## **A monster's attack has to be its own shape, not everyone's line.** The user asked for it twice —
## *"몬스터가 공격하면 몬스터마다 좀 다르게 해야지"* and *"뭔가 뜨면서 공격을 해야 될 거 아니야"* — and this
## repo's standing note on 연출 is that it is shown to the point of excess or it is not shown at all.
##
## Every number below is a multiple of the creature's OWN radius (the `_RING` suffix's convention in this
## file), so a 5px 들쥐 and a 48px 보스 both get a mark in proportion to the body it comes out of. **Nothing
## here is absolute px except the two widths**, which are strokes and would vanish if they scaled down.
##
## ⚠ **Four species never reach any of this**: 말 · 다람쥐 · 치타 · 토끼 carry `Rules.SPECIES_FLEES` 1 and
## `World._contact()`'s second pass returns before writing `critter_swing_show` at all, so a gesture written
## for them would be built, would never fire, and would pass every net. Their mark is the afterimage trail
## they already have, or nothing. See `hunting-and-the-boss-ko`.

## 까마귀 쪼기 — a FORK, not a sweep: two strokes at ±`SWING_PECK_ANGLE` around the swing direction, both at
## full length for the whole window. A crow that stands still and counters should read as two beak points
## arriving at once, which is the one thing a single line cannot say.
const SWING_PECK_ANGLE := deg_to_rad(14.0)
const SWING_PECK_RING := 1.5

## 들쥐 갉기 — **the quietest mark in the game, on purpose.** One filled dot at the contact point, shrinking
## to nothing across the window and no line at all. It is 2–3 damage against a 30-hp host; a mark the size of
## a lion's would teach the wrong thing about what just touched you.
const SWING_GNAW_RING := 0.5

## 들개 물어뜯기 — one stroke that ROTATES across the window, from `-SWING_BITE_SWEEP` to `+SWING_BITE_SWEEP`
## around the swing direction. A static line of the same length reads as a poke; a line that moves reads as a
## shake, which is what three dogs pulling at a scattered swarm is supposed to look like.
const SWING_BITE_RING := 2.0
const SWING_BITE_SWEEP := deg_to_rad(20.0)

## 멧돼지 들이받기 — an arc centred on the swing direction that **WIPES open across the window** rather than
## appearing whole: it starts at `angle - SWING_CHARGE_ARC / 2` and sweeps the full `SWING_CHARGE_ARC` as the
## window runs. Tusks, and the only gesture whose shape at the start of the window is a point.
const SWING_CHARGE_RING := 1.4
const SWING_CHARGE_ARC := deg_to_rad(90.0)

## 코끼리 밀치기 — one bar drawn ACROSS the swing direction at the contact point, `SWING_SHOVE_RING × r` to
## each side, at `SWING_SHOVE_WIDTH_MUL` times a normal creature's stroke. Paired with `SPECIES_LUNGE_MUL`'s
## doubled push: the whole animal moves and a wall arrives in front of it.
const SWING_SHOVE_RING := 0.8
const SWING_SHOVE_WIDTH_MUL := 2.0

## 사자 덮치기 — **the lunge is the gesture** (`SPECIES_LUNGE_MUL` ×3) and this is only where it lands: one
## dot at `SWING_POUNCE_RING × r` ahead of the body, shrinking from `HIT_SPARK_R` to nothing. There is no
## line, because a line drawn from a body that has already thrown itself forward marks the same distance
## twice.
const SWING_POUNCE_RING := 1.8

## 보스 내려찍기 — a full ring on the ground at the boss's feet, growing from its own radius to
## `SWING_STOMP_RING × r` and fading out as it goes. **Drawn through `_paint_arc` from 0 to TAU, never
## through `_paint_ring`** — that leaf draws a SECOND circle at `r × 0.45`, which is exactly the companion
## circle that dragged itself across the arena wall for a plan. Width is `ARENA_WALL_WIDTH`, so the boss's
## two heavy marks are one weight.
const SWING_STOMP_RING := 2.2

# -- §F: food eaten, a level fires, F splits apart, and speed ---------------------------------------------
## The dot sucked from an eaten spot toward whichever body ate it. **Small on purpose, and reused from
## `_deaths`'s own timer rather than its duration or its ring shape** — this is the ONLY event in this build
## that fires several times a second, and the audit's own #7 finding is that overdoing it buries the other
## eleven. Smaller than `CLONE_DEATH_R_BASE` (10px), the next-smallest burst on screen, and drawn through
## `_paint_disc` — a shrinking, TRAVELLING point, not a growing ring, so it does not share `_paint_ring`'s
## call.
const FOOD_POP_R := 4.0
const FOOD_POP_TIME := 0.15

## The host's own pop when a level fires. **Reuses `_absorb_pop`'s IDEA — a radius scaled by a decaying
## 0..1 — but neither its colour (which never tints at all) nor its strength**, so a level reads as its own
## event rather than a bigger harvest bite. Driven off `World.level_show`, a sim-owned up-counting clock,
## never a `view`-owned diff of `level` frame to frame (§0-2).
const LEVEL_POP_TIME := 0.5
const LEVEL_POP_STRENGTH := 0.55
const LEVEL_POP_COLOR := Color(0.55, 0.9, 1.0)

## The level bar's own kick: a bright flash across the whole groove, independent of `_bar_shown`'s chase —
## the chase alone reads as the gauge draining over time, not as a MOMENT the way this flash does.
const LEVEL_BAR_FLASH_TIME := 0.35
const LEVEL_BAR_FLASH_COLOR := Color(1.0, 1.0, 1.0, 0.6)
## The short phrase, positioned clear of both the bar above it and the bank readout below.
const LEVEL_TEXT_AT := Vector2(24.0, 52.0)
const LEVEL_TEXT_TIME := 1.2
const FONT_LEVEL_TEXT := 22

## `F`'s own burst: a ring at the point the two halves split FROM, drawn through `_paint_ring` — the same
## shared `BURST_TIME`/`BURST_GROWTH` growth law every other burst in this file uses — tinted the same
## colour as the wind-up arc so the hold and its own release read as one act in one colour.
const SPLIT_POP_R0 := 8.0

## Trailing ghosts on the two species that out-run the swarm — cheetah and horse, `Rules.SPECIES_SPEED_MUL
## > 1.0`. **The gate is by SPECIES, never by the frame's actual velocity** — the trail itself is the "this
## one cannot be caught" information the audit asked for, not decoration on whatever moves fast for a frame.
const AFTERIMAGE_COUNT := 3
## A multiple of the creature's OWN radius, the same convention every other `_RING`-suffixed anchor in this
## file uses, so a ghost does not slide off a body as a species' radius is retuned.
const AFTERIMAGE_GAP_RING := 0.6
const AFTERIMAGE_ALPHA := 0.35

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
