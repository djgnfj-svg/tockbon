# A boss arrives with a name and a bar

**Status**: done
**Seen on screen, repeatedly, by the user — with fixes made each time.** The name, the bar and the
walk-out/roar/camera-zoom entrance are confirmed working for the bull.
**One line**: both stage-1 bosses get **a big bar across the top of the screen with the boss's name over it**
(「불의 룬을 삼킨 소」), and the bull **walks out behind you** when you reach the wood wall and roars while
**the camera zooms in on it and back out.**

**Design doc**: [../../design/hud.md](../../design/hud.md) — the boss bar is HUD, and that doc's layout
section is where the top band gets claimed.
**Decision**: [../../decisions/the-back-door-does-not-close.md](../../decisions/the-back-door-does-not-close.md)
— why nothing closes behind you.
**Preceding**: [stage1-bosses.md](stage1-bosses.md) (the patterns) ·
[monster-placement-stage1.md](monster-placement-stage1.md) (the bosses are rows in the
placement table, and that is what this doc reuses).
**Precedent for changing the world as a beat**:
[gate-ending-to-game.md](gate-ending-to-game.md) and `gate_view.gd` — a counter in
physics frames, a pure `tint()` a net can call, and a `_paint_*` hook.
**Depended on**: [burn-out-of-the-bull-room.md](burn-out-of-the-bull-room.md) — built, in `3.done`.
Today's wood wall is `x164-166` at `ty20-25`, standing on the plateau **above** room ①, whose floor is `ty32`
— **6 tiles of face against a 102px jump ceiling.** ⇒ **"the player reaches *the wood*" is unreachable on the
map that exists now.**

> ⚠ **Correction (spec, re-measured on the baked map).** This box used to read **"blocked by"** and
> **"build order: the burn feature first."** That is wrong, and the reason is one column over. `ty26` in
> `terrain_map_generated.gd` is empty through `x159` and solid from `x160` — **room ①'s own east wall is
> already a 6-tile face the player cannot climb.** The choreography this doc is about is *reach a wall you
> cannot pass · turn · it is behind you*, and **that wall exists today at `x160`.** What the burn feature
> changes is only **which material the player is standing in front of**, and the trigger that reads it is
> **one number in one row** (§1, and the plan's `trigger_tx`), which moves with the wall the day the wood
> does. ⇒ **This feature is not blocked.** Build it against `x160`; the burn feature retunes one integer.

**What the burn feature does still own** is the *rooster's* trigger value — see the Bounds box, and the plan's
Risk 3: the two branches of "does the map get shorter" put room ③ in two different places.

**There is no sound in this repo.** The roar is a picture only.

---

## Why

**A boss today is a monster that is bigger.** It materialises at 720px like every other row, walks at you,
and the only thing on screen saying it is different is a 4px health bar over its head — the same bar a pig
has. **The world says these beasts swallowed the circle** (`GDD.md`, World: "a bull that swallowed the fire
rune"), and **that sentence has never once reached the screen.**

Two things fix it and they are the same feature: **a name, big, at the moment it arrives** — this is the
seat the world gets told in — and **a bar you cannot mistake for a mob's**, so "this fight has a length"
reads before the first hit lands.

---

## Behavior

### 1. The trigger — the row simply materialises later

**Nothing is hidden and nothing new is summoned.** The bull is already `{"tx": 145, "kind": KIND_BULL}` in
`stage1_monsters.ROWS`, and `MonsterPlacement.wake_scan()` already materialises it through
`world_step.spawn_monster` — **still the only door**, with the boss reserve
(`decisions/boss-slots-are-reserved-in-the-spawn-door.md`) already holding its slot.

**The only change is the distance a boss row materialises at.** A boss row does not use
`MATERIALIZE_PX` (720); it uses **its own trigger x**, taken from the row. The player walks past the bull's
seat, reaches the wood wall, and *then* the row materialises — **behind them**, which is the whole picture.

- **Position only, not facing.** `Character.facing` survives after you let go of the key, and a player who
  walks to the wall backwards would never fire it. The bull comes out behind you because it is behind you,
  not because the game read which way you were looking. **Whether facing should gate it is TBD.**
- **Once.** The row's own `_monster_id[i] != 0` short-circuit already makes `wake_scan` skip a live row
  forever; walking back over the trigger cannot fire it twice.
- **The bull's `tx` may have to move west.** At the wall its seat is ~15 tiles = 480px away and half the
  viewport is 480px, so it can materialise just barely on screen. **One row in `stage1_monsters.gd`** —
  adjusted against the map doc above, on screen.

### 2. The beats

| # | What | Clock |
|---|---|---|
| 1 | Player crosses the trigger. The row materialises | **tick (20Hz)** — `wake_scan` runs in `frame()`'s tick branch |
| 2 | The bull walks out. Ordinary `Pattern.IDLE` (= walk toward the player), ordinary `MON_WALK` | tick + 60Hz movement, unchanged |
| 3 | The camera leaves the player and closes on the bull; the bar and the name fade in | **physics frames (60Hz)** |
| 4 | **The roar** — the bull's first `Pattern.WINDUP`, which already draws `bull_roar.png` (`MON_WINDUP`, 8 frames × hold 4 = **32 view frames**) | tick decides, view plays |
| 5 | The camera returns to the player. The bar stays | physics frames |

**Beat 4 is a real wind-up, not a cutscene pose.** `monster_view.resolve_state` already maps
`Pattern.WINDUP → MON_WINDUP`, so the roar costs nothing new — and because it is a real telegraph, its red
ground prediction (`ATTACK_PREDICT_*`) draws with it and **the first thing the player ever sees is the tell
they will have to read all fight.** Faking a roar with no move behind it would be presentation with no sim,
which is the failure CLAUDE.md names.

**Beat 2 needs the bull to stay in `IDLE` long enough to walk into view.** `BossAi` gains **one constant** —
an entrance idle count applied to the first `IDLE` after a boss materialises — not a new pattern and not a
new animation state. Everything after beat 4 is the machine that already exists.

**Two clocks, and the split is not cosmetic.** The materialise is on the tick because that is where
`wake_scan` lives. Beats 3 and 5 are physics frames because that is what `gate_view`'s own header already
settled: `_process()` runs at the monitor refresh rate, so a 24-frame beat is 0.4s on a 60Hz panel and
0.167s on a 144Hz one, **with nothing barking.**

### 3. The camera

`stage._process()` writes `_camera.zoom` and `_camera.position` **every frame** from `ZOOM_STEPS[_zoom_step]`
and `_char.center()`. **A cinematic that writes them from somewhere else is overwritten the next frame.**
⇒ the entrance folds into the same two lines, exactly as `_cam_lead` already does:

- **Focus** — the entrance supplies a focus that lerps from the player to the bull and back. It still goes
  through `camera_center()`, **so the clamp still applies** and the camera still refuses to show the void
  outside the map.
- **Zoom** — the entrance supplies a multiplier on `ZOOM_STEPS[_zoom_step]`, so the debug `-`/`=` keys keep
  working underneath it and the entrance does not have to know what step is selected.
- Both are **pure static functions** (`entrance_focus`, `entrance_zoom`), the same seat `camera_lead` and
  `snap_camera_px` already hold — a net feeds a frame count and reads the value, with no scene and no camera.
  **This is the only reason any of this is measurable**: today's zoom is a debug key with nothing measuring it
  (`ZOOM_STEPS`' own comment: "nothing measures this step").

**The world does not stop and input is not taken** — the standing contract for the assembly window
(`stage._ready()`: "**The world is not stopped** — do not touch `get_tree().paused` here"), applied
unchanged. **The cost is real and named**: the player can walk while the camera is looking at the bull, and
can walk off their own screen. **Whether the boss entrance gets the same contract is the user's, and it is
not decided** — see TBD.

### 4. The bar and the name

**Both bosses.** One node, `src/view/boss_bar_view.gd`, under `HUD` (the `CanvasLayer`, so it does not ride
the screen shake — the same seat every window already takes).

- **Top of the screen.** The player's own readout is bottom-left because `WINDOW_RECT` (48,12)-(912,384)
  covers the top-left; **the boss bar sits inside that band on purpose** — it is the one thing that may
  overlap the assembly window, because you are not assembling while a boss is arriving. *(If that turns out
  to be false on screen, it moves down, not the window.)*
  ⚠ **"You are not assembling while a boss is arriving" is exactly what the tutorial breaks.**
  `onboarding-and-palette-tabs.md`'s later beat is *the bull dies → 「불 룬을 껴 보세요」 → open the assembly
  window → slot fire → burn the wall.* The bull's bar is gone by then (it hides on death), **but on the cut
  map the rooster's is up** — see the Bounds box. ⇒ **The game's one guaranteed assembly moment can happen
  under a live boss bar.** Same premise, same sentence, in `design/hud.md`.
- **The name is drawn above the bar, large.** 황소 = **「불의 룬을 삼킨 소」** — the user's own words, and the
  reason is `GDD.md`'s World table ("a bull that swallowed the fire rune"). **The rooster's name is TBD.**
  The string is **not** `MonsterDefs.name_of()` (황소 / 거대 수탉) — that is the kind, this is the title.
- **Structure copied from `hp_view.gd`**: frame art first (`HP_FRAME_TEX`, a hollow box), fill on top, text
  over it. **Not the mob bar** (`_draw_hp_bar`, 4px, no frame) — that is the thing it must not be mistaken for.
- **Appears** when the row materialises (beat 1), fading in with beat 3. **Disappears** when the boss dies.
  Between those it is always on, tracking `Monster.hp / MonsterDefs.max_hp(kind)`.

---

## Screen

```
   ┌────────────────────────────────────────────┐
   │            불의 룬을 삼킨 소                 │   name, above the frame
   ├────────────────────────────────────────────┤
   │██████████████████████████                  │   fill, hp / max_hp
   └────────────────────────────────────────────┘   hp_frame.png, top-centre
```

**Starting points, read out of the code — not proposals.** Viewport 960×540 · player readout
`HP_RECT = (16, 448, 192, 48)` with `HP_FRAME_INSET_PX` 6 and `HP_NUMBER_SIZE` 22 · frame art
`assets/ui/hp_frame.png` is 384×96 drawn at half scale with `HP_FRAME_TINT (1.6, 1.55, 1.5)` (a tint under
1.0 can only darken — `modulate` multiplies) · `HUD_FONT_SIZE` 16 · the roar is 32 view frames.

**Every number the user will set by eye is TBD** — bar width and height, name size, how far the zoom goes,
how long each beat is. They are listed in TBD and **nothing below invents one.**

**Does the fill carry a number.** The player's bar does (`87 / 100`, the user's ask). **A boss's does not by
default** — a boss's exact hp is not a thing the player budgets against, and 「불의 룬을 삼킨 소」 already
fills that line. TBD if the user wants it.

---

## Bounds

| Situation | What must happen |
|---|---|
| The player walks back over the trigger | Nothing. `wake_scan` skips a live row forever |
| The player dies during the entrance | `reset_stage()` re-arms every row (`MonsterPlacement.reset`). The bar hides, the zoom returns, the entrance can fire again on the next run |
| The boss dies during the entrance | Impossible at hp 300, but the bar hides on death regardless of which beat is running |
| The player zooms out with `-` while the entrance runs | The entrance is a **multiplier** on the selected step, so both apply. Debug against debug; not a case to protect |
| Both bosses somehow live at once | One bar. **The bar shows the boss that most recently entered** — two stacked bars is not a thing anyone asked for. ⚠ ~~Cannot happen on stage 1's map~~ — **see the box below** |
| The player walks off screen during the entrance | **It happens, and it is allowed** — the world does not stop. See §3 and TBD |
| The bull is stuck behind terrain the player dug | It walks out when it can. The entrance beats run on their own clock and end either way — a beat that waits for the bull to arrive is a beat that can never end |

### ⚠ **"Cannot happen on stage 1's map" is only true while the two rooms are 78 tiles apart**

`burn-out-of-the-bull-room.md` deletes zone ② and leaves **"does the map get shorter" as an open TBD.**
The two branches are not the same map, and this row's answer flips between them:

```
map NOT cut : rooster tx258, player at the door x163  =>  95 tiles = 3,040px  >>  720   safe
map cut     : everything east of x167 shifts -78; rooster tx258 -> tx180
              player at the door x163  =>  17 tiles = 544px  <  MATERIALIZE_PX 720   ⇒ it materialises
```

⇒ **On the cut map the rooster comes alive while the player is standing at the bull's door**, before the
bull fight starts. That doc has already written the same thing from its side (*"the rooster … may already be
awake and walking at the doorway before the wood finishes burning — **unmeasured**"*).

**The lever already exists in this doc and nobody connected it**: §1 gives a boss row **its own trigger x**
instead of `MATERIALIZE_PX`, so the rooster simply gets a trigger inside room ③. **That is the fix — not the
sentence "it cannot happen."** It has to be written down, because a boss row that keeps `MATERIALIZE_PX` on
the cut map produces two live bosses and this feature has one bar.

**And a runeless blast reaches the same state from the other side**: it opens the door with the bull still
alive (that doc's second ⚠). **Which fork closes that is the thing it is blocked on.**

---

## Interaction with what exists

- **`stage1_monsters.gd`** — the bull's `tx` may move west. One row. No new column.
- **`monster_placement.gd`** — boss rows materialise on their own trigger instead of `MATERIALIZE_PX`, and
  the frame one does gets reported once, the same shape `world_step.died_*` already is. `spawn_monster` stays
  the only door and the boss reserve is untouched.
- **`boss_ai.gd`** — one constant (the entrance idle window). **No new `Pattern`.**
- **`monster_view.gd`** — **untouched.** `resolve_state` already draws the roar from `Pattern.WINDUP`, and
  the per-head 4px bar stays exactly as it is (it is the mob vocabulary; the top bar is a different one).
- **`fx_tuning.gd`** — the new constants and the boss titles. In-game Korean text lives here already
  (`CHAR_DOWNED_TEXT`).
- **`stage.gd`** — the `HUD` child, the entrance counter, and the two camera lines it folds into.
- **`gate_view.gd`** — untouched, but it is the model: `_lit`/`_take` in physics frames, a pure `tint()`, and
  a `_paint_arch` hook.
- ⚠ **`monster_placement.gd`'s header arithmetic is stale and this feature reads it.** It computes "the
  distance a mob becomes visible at" as 480 + `Fx.CAM_LEAD_PX` = **552**, but `CAM_LEAD_PX` **is 32, not 72**
  (lowered by the user; that constant's own comment records the change). The real edge is **512**. It does not
  break anything here — 300 < 512 either way — but **do not copy 552 into this feature's numbers.**

---

## Cost

- **One new view file** (~150 lines), modeled line for line on `hp_view.gd`.
- **~10 new constants**, all presentation, all in `fx_tuning.gd`.
- **One constant in `boss_ai.gd`**, one accessor on `MonsterPlacement`, ~15 lines in `stage.gd`.
- **Runtime: nothing.** One `Control` redrawing per frame while a boss is alive, and two float lerps on the
  camera while the entrance runs. Both are already the shape of things measured at zero here.
- **One new net.** It should not go in `net_gate` — that net is **24.3s of a ~28s round** and is
  `harness-manager`'s to fix, not a place to add to.

---

## Acceptance

**Nets — driven, never grepped.** CLAUDE.md lists five source-text scans evaded in a single feature.

1. **The bar is actually painted at a real size.** Override `_paint_fill` and **assert the captured rect
   equals what the pure `bar_rect()` returns** — measuring the pure function alone is exactly how a notice
   shipped painting at `Rect2()` under 320 green checks.
2. **The name is actually painted.** Override `_paint_name` and assert the string, the size and the colour.
   **"`_draw()` ran" is not "anything was drawn"** — three features shipped that way in one day.
3. **`visible` is measured directly**, false before the trigger and true after. A settlement panel that
   never set `visible` shipped under 5,576 green checks.
4. **The bar drains.** At `max_hp` the fill width equals the inner width; at half hp it is half; at 0 the
   node is gone. **All three, not one** — one bite does not prove the range.
5. **The entrance fires once.** Drive the character across the trigger and back, count materialises.
6. **The zoom comes back.** Assert `_camera.zoom` equals `ZOOM_STEPS[_zoom_step]` again after the last beat.
   *Inversion: delete the return and this goes red.*
7. **Every beat constant gets a floor and a ceiling probe.** `GATE_ARCH_FADE_FRAMES` carried a floor on one
   end and none on the other, and **2 through 11 were green** while the fade collapsed to a pop.
8. **The rooster runs the same path**, not just the bull.
9. ⚠ **Anything observing the materialise pumps `TICK_DIVIDER * 2` (= 6) physics frames, never one.**
   `wake_scan` is on the tick, and **one physics frame crosses a tick boundary at most one time in three.**
   A check that pumped one frame passed while measuring nothing and let a mutation stay green at 437.
10. **Invert the checks, not only the code.** A dim check that folded two alphas into one array stayed green
    with the body dim deleted outright; write a case that fails *this* net.

**The eye's, and none of it is a net's:**

1. **Does「불의 룬을 삼킨 소」read as a world, or as a label** — this is the whole reason the name is here
2. **Does the zoom in-and-out feel like an arrival**, or like the camera glitched
3. **Is the bar readable against the top of the map** at zoom 1.0
4. **Does the bull actually come from behind you** — the picture the trigger exists for
5. **Can the player see themselves during the entrance**, or do they lose their own character

---

## TBD

- **The rooster's name.** The bull's is the user's own words; the rooster's has never been said, and what
  the rooster swallowed is not in `GDD.md` either
- **Does the world stop during the entrance, and is input taken.** §3 builds the "nothing stops" version
  because that is the one standing precedent, but **the user has not decided this** and it is the difference
  between "a beat" and "a cutscene". The GDD's reason for not stopping (multiplayer) is about the assembly
  window; whether it reaches a boss entrance is a real question
- **Every screen number** — bar rect, name size, zoom factor, and the length of beats 3 and 5. The values
  above are the *current* ones read out of the code, offered as starting points only
- **Does the boss bar carry a number** the way the player's does
- **Does the rooster get a walk-out at all.** The bull's choreography is "wall → turn → it is behind you",
  and **room ③ has no wall to check.** The bar and the name are both bosses (the user decided); the
  choreography was only ever described for the bull
- **Does facing gate the trigger**, or position alone (§1)
- **Whether the top band actually clears the assembly window** on screen

---

## Implementation plan

**Two questions the user has to answer before Stage D lands. Everything else is buildable now** — see
*Blockers* at the bottom. Neither one blocks Stages A-C.

### The structure decision, answered first

**This is a variant, not a new kind.** The bar is `hp_view.gd`'s shape with a different rect and a different
source of `hp`; the entrance is `gate_view.gd`'s shape (a physics-frame counter, a pure curve a net can call,
a `_paint_*` hook); the trigger is one more column on a row of a table that already exists.

**Adding a third boss with a bar and an entrance costs two files** — one row in `stage1_monsters.gd`
(`tx`, `kind`, `trigger_tx`) and one row in `fx_tuning.BOSS_TITLES`. `boss_ai.MOVES` needs a row too, but it
needed one before this feature. **Under the three-file contract.**

**The one axis this feature adds is the entrance clock, and it has exactly two consumers** — the camera
(`stage._process`) and the bar's fade (`boss_bar_view`). Both read **one counter**, `stage._entrance_frames`.
A second counter is how the bar finishes fading in while the camera is still on the bull.

### Stages, in order

Each stage is buildable and measurable on its own. **A is what B needs, B is what C needs.**

#### Stage A — the trigger column

**`monster_placement.wake_scan()` learns one alternative to `MATERIALIZE_PX`.**

- `set_rows()` reads an **optional** `"trigger_tx"` off each row into a parallel `_trigger_tx: Array[int]`,
  `-1` when absent. A row without it keeps `MATERIALIZE_PX` **byte-for-byte** — 30 of the 32 rows are that.
- In `wake_scan()`, a row with `trigger_tx >= 0` skips `_primed`/`stays_active` entirely and materialises the
  first tick `target_x >= trigger_tx * TILE_CELLS * CELL_PX`. **Still through `spawn_fn`** — `spawn_monster`
  stays the only door, the boss reserve is untouched, and a cap refusal still retries every tick exactly as a
  primed row does (that path is shared, not copied).
- **The comparison is one-directional and that is written down, not hidden**: *the player has crossed east of
  this tile*. Both stage-1 bosses are entered from the west. A boss approached from the east needs a second
  column that **does not exist yet** — do not invent it.
- **`MonsterPlacement` reports the materialise once**, the shape `world_step.died_*` already is: a
  `_woke_boss_id` field cleared at the top of every `wake_scan()`, set when a row whose kind passes
  `BossAi.has_pattern` materialises, read through `woke_boss_id()`. It lives exactly one tick.
- **`world_step.spawn_monster(kind, px, py, entrance := false)`** — a fourth argument, defaulted false.
  When true **and** the kind has a pattern, the fresh `Monster.pattern_left` is set to
  `BossAi.ENTRANCE_IDLE_TICKS` so the boss walks before it roars. `wake_scan` passes `true`.
  ⚠ **The default is the whole point.** Putting this in `Monster._init` instead shifts the first `WINDUP` of
  every bull and rooster in `net_monster`, `net_monster_charge`, `net_monster_breath` and `net_monster_slam`
  — four nets red for a presentation beat. The entrance idle belongs to *"a row materialised as an entrance"*,
  not to *"a bull exists"*.
- `WorldStep` re-exports `woke_boss_id()` and gains `monster_by_id(id) -> Monster` (linear over ≤20, called
  once per entrance, not per frame).
- **Fix the stale header while in the file**: `monster_placement.gd`'s box computes the visibility edge as
  `480 + CAM_LEAD_PX = 552`. **`CAM_LEAD_PX` is 32** (`fx_tuning.gd`), so the edge is **512**. The doc's
  Interaction section already flags it; the comment itself still says 552 in two places.

**Row values, arithmetic shown — not proposals, but not the user's eye values either.**

```
room ①      x130-159 floor ty32 · east wall x160 (ty26-31 solid) · wood x164-166 above it
player      W_PX 20  =>  center at the wall = 160*32 - 10 = 5110
bull        w_px 88
trigger_tx  159  =>  fires at center_x 5088, ~1.3 tiles short of the wall face
visibility  half viewport 480 + CAM_LEAD_PX 32 = 512   (NOT 552 — see above)
bull tx145  center 4684  =>  5088 - 4684 = 404px  <  512   the bull pops in ON SCREEN
bull tx140  center 4524  =>  5088 - 4524 = 564px  >  512   72px of margin, off screen
            box x140.0-142.75, ten tiles clear of room ①'s west step at x129/130
```

⇒ **`{"tx": 140, "kind": KIND_BULL, "trigger_tx": 159}`.** The `tx` move west is the design doc's own "may
have to"; the 72px is what makes "it comes out from *behind* you" true instead of "it appears".

**The rooster, and the honest version of it.** Room ③'s interior is `x247-266`, the rooster sits at `tx258`
(center 8292). A trigger anywhere inside room ③ is **less than 512px from that seat** — `tx250` gives 292px.
⇒ **On today's map the rooster cannot materialise off screen.** Its entrance is *the bar and the name arrive
and the camera looks at it*, **not** a walk-out — which is exactly what the doc's TBD suspected. Ship
`{"tx": 258, "kind": KIND_ROOSTER, "trigger_tx": 250}` and say so; do not move room ③ to buy a walk-out
nobody asked for. **The reason `trigger_tx` is on the rooster's row at all is the Bounds box** — on the cut
map its seat is 544px from the bull's door and `MATERIALIZE_PX` 720 would wake it there, two live bosses
against one bar.

#### Stage B — the bar and the name

**One new file, `src/view/boss_bar_view.gd`, `extends Control`, `HUD/BossBar` in `stage.tscn`**
(`mouse_filter = 2` in the scene, never written at runtime — `net_render` forbids it).

Modeled on `hp_view.gd` line for line: `_ready()` sets `position`/`size` from `Fx.BOSS_BAR_RECT`,
`_process()` calls `queue_redraw()`, `_draw()` calls **nothing but `_paint_*` hooks**.

- `var _boss: Monster = null` — **a reference, not a copy of `hp`**, the same rule `hp_view._ch` holds.
- `func show_boss(m: Monster) -> void` / `func clear_boss() -> void`.
- `visible` is **derived in `_process()`**, never latched: `_boss != null and _boss.hp > 0`. The gate_view
  precedent, and the settlement panel that shipped with `visible` never set under 5,576 green checks.
- **Pure statics a net calls with no node**, the `gate_view.tint()` / `hp_view.fill_frac()` seat:
  - `fill_frac(hp, kind) -> float` — `clampf(hp / MonsterDefs.max_hp(kind), 0, 1)`
  - `frame_rect(size) -> Rect2` · `bar_rect(size) -> Rect2` (frame inset by `BOSS_BAR_INSET_PX`) ·
    `name_baseline(size, font) -> Vector2`
  - `fade_alpha(entrance_frames) -> float` — `clampf(frames / max(BOSS_BAR_FADE_FRAMES, 1), 0, 1)`.
    **The `maxf` guard against the constant, not the counter** — `gate_view.tint()`'s own reason: set to 0
    the plain division is NaN and a NaN colour reaches the draw call with nothing barking.
  - `title_of(kind) -> String` — `Fx.BOSS_TITLES`.
- **Three hooks, and every one is asserted by its arguments**: `_paint_frame(tex, r, tint)` ·
  `_paint_fill(r, frac)` · `_paint_name(font, pos, text, size, color)`.
  ⚠ **`notice_rect()` is the precedent that makes this non-optional**: the pure function was correct, `_draw()`
  handed the painter a bare `Rect2()`, and it painted at zero size under 320 green checks. **The net captures
  the argument at the hook and asserts it equals what the pure function returns** — not that the pure function
  is right.
- The name is drawn **above** the frame, inside the node's own rect (see the constants below), with
  `ThemeDB.fallback_font` — `hp_view._paint_number`'s own font door, and it exists untreed.

#### Stage C — the entrance clock and the camera

**All of it in `stage.gd`. ~20 lines plus two static functions.**

- `var _entrance_frames := -1` — **`-1` means "no entrance running"**, so `0` can be the first frame.
- `_on_ticked()`: `var id := _world.woke_boss_id()`; if nonzero, `_boss = _world.monster_by_id(id)`,
  `_boss_bar.show_boss(_boss)`, `_entrance_frames = 0`. **In `_on_ticked()`, not `_physics_process`** — the
  notification lives one tick and this is the function that runs exactly on tick frames.
- `_physics_process()`, **inside the `not _settlement.is_showing()` guard** (the panel freezes the world; an
  entrance that kept running under it would be a latch by accident): `if _entrance_frames >= 0 and
  _entrance_frames < Fx.boss_entrance_total_frames(): _entrance_frames += 1`. Then push the clock to the bar:
  `_boss_bar.set_entrance_frames(_entrance_frames)`.
  **Physics frames, not `_process()`** — `gate_view`'s own header: `_process()` runs at the monitor refresh
  rate, so a 24-frame beat is 0.4s on a 60Hz panel and 0.167s on a 144Hz one, with nothing barking.
- `_process()` — the camera, folded into the **two lines that already exist**, because anything written
  elsewhere is overwritten next frame:

```gdscript
var z: float = ZOOM_STEPS[_zoom_step] * entrance_zoom(_entrance_frames)
_camera.zoom = Vector2(z, z)
var focus := entrance_focus(_char.center() + Vector2(_cam_lead, 0.0), _boss_focus(), _entrance_frames)
_camera.position = snap_camera_px(camera_center(focus, get_viewport_rect().size / z, world_size()), z)
```

- **`entrance_zoom(frames) -> float` and `entrance_focus(player, boss, frames) -> Vector2` are pure static**,
  the seat `camera_lead` and `snap_camera_px` already hold — a net feeds a frame count and reads the value,
  with no scene and no camera. **This is the only reason any of it is measurable**: today's zoom is a debug
  key and `ZOOM_STEPS`' own comment says "nothing measures this step".
- Both return the identity outside the entrance: `entrance_zoom(-1) == 1.0` and
  `entrance_focus(p, b, -1) == p`, **and the same at the last frame** — that is acceptance 6.
- The zoom is a **multiplier** on the selected step, so `-`/`=` keep working underneath it and the entrance
  never learns which step is selected.
- The focus goes through `camera_center()`, **so the clamp still applies** — the camera still refuses to show
  the void outside the map, including while it is looking at the bull.
- `_boss_focus()` returns `_boss.center()` when `_boss != null`, else the player's focus, so a boss that died
  mid-entrance collapses the lerp to a no-op instead of reading a null.
- `_rebuild()` clears all of it beside `_gate_view.reset_gate()`: `_entrance_frames = -1`, `_boss = null`,
  `_boss_bar.clear_boss()`. **Left out, the bar rides a fresh run showing a boss from the last one** — the
  exact shape `_gate_view.reset_gate()`'s own comment records for `_lit`.

#### Stage D — the constants

All presentation, all in `fx_tuning.gd`. **Every number below is a starting point the user sets by eye.**

```gdscript
const BOSS_BAR_RECT := Rect2(288.0, 12.0, 384.0, 140.0)  # name band 44px, frame 96px under it
const BOSS_BAR_FRAME_H_PX := 96.0    # hp_frame.png's own height, 1:1
const BOSS_BAR_INSET_PX := 12.0      # HP_FRAME_INSET_PX 6 at the player bar's 0.5 scale => 12 at 1.0
const BOSS_NAME_SIZE := 28
const BOSS_NAME_COLOR := Color(...)
const BOSS_BAR_FULL := Color(...)    # not HP_FULL — that is *your* health's colour
const BOSS_BAR_BG := Color(...)
const BOSS_BAR_FADE_FRAMES := 24
const BOSS_ENTRANCE_ZOOM_IN_FRAMES := 24
const BOSS_ENTRANCE_HOLD_FRAMES := 36
const BOSS_ENTRANCE_OUT_FRAMES := 24
const BOSS_ENTRANCE_ZOOM_MULT := 1.6
const BOSS_TITLES: Dictionary = { MonsterDefs.KIND_BULL: "불의 룬을 삼킨 소", KIND_ROOSTER: <blocked> }
```
plus `const ENTRANCE_IDLE_TICKS := 14` in `boss_ai.gd` (a boss-level tick value, beside `IDLE_TICKS`).

**Why 384 wide and not "big".** `assets/ui/hp_frame.png` is 384×96 and the player's bar draws it at **exactly
0.5**; `net_town`'s standing rule is that a pixel-art sprite is upscaled by an **integer**, never stretched.
384×96 is the 1:1 row. ⇒ **If the user wants it wider, the frame needs a 9-patch or a 2x art row — that is a
real consequence, not a number to nudge.** Say it rather than shipping a 1.25×0.46 stretch.

**The one cross-clock constraint, and it is the beat that carries the whole feature.** The roar must land
while the camera is on the bull:

```
ENTRANCE_IDLE_TICKS * TICK_DIVIDER  must lie strictly inside
[ BOSS_ENTRANCE_ZOOM_IN_FRAMES , ZOOM_IN + HOLD ]
14 * 3 = 42        inside [24, 60]        ✓
```

**A net asserts that inequality directly.** It is the one thing a retune of any of the four constants can
break silently, and the symptom is not a wrong value — it is *the player never sees the roar*, which is
CLAUDE.md's "a thing that never happens".

### Files to touch

| File | Why | Stage |
|---|---|---|
| `src/actor/monster_placement.gd` | the `trigger_tx` column, the woke-boss notification, the stale 552 comment | A |
| `src/actor/world_step.gd` | `spawn_monster`'s 4th arg · `woke_boss_id()` · `monster_by_id()` | A |
| `src/actor/boss_ai.gd` | `ENTRANCE_IDLE_TICKS`, one constant | A |
| `src/stage/stage1_monsters.gd` | bull `tx145 -> tx140` + `trigger_tx`; rooster `trigger_tx` | A |
| **`src/view/boss_bar_view.gd`** | **new.** the bar, the name, three `_paint_*` hooks, the pure statics | B |
| `src/stage/stage.tscn` | `HUD/BossBar`, a `Control` with `mouse_filter = 2` | B |
| `src/stage/stage.gd` | `@onready _boss_bar` · `_boss` · `_entrance_frames` · two camera lines · `_rebuild()` | C |
| `src/view/fx_tuning.gd` | the ~12 constants and `BOSS_TITLES` | D |
| **`tests/nets/net_boss_entrance.gd`** | **new.** the runner sweeps `tests/nets/net_*.gd`; no registry to edit | all |
| `docs/design/hud.md` | flip the boss-bar section's **Implemented** line once it lands | after |

**Not `monster_view.gd`.** `resolve_state` already maps `Pattern.WINDUP -> MON_WINDUP` and both bosses already
have roar art (`bull_roar.png`, `rooster_roar.png`, 8 frames × hold 4). The 4px per-head bar stays exactly as
it is — it is the mob vocabulary and the top bar is a different one.

**Not `net_gate.gd`.** It is 24.3s of a ~28s round and is `harness-manager`'s.

### The net — two roots, and neither one alone is enough

`net_gate._wired_root()` builds an **untreed** stage root and hand-calls `_physics_process`; it refuses to tree
it because uncounted engine frames would break its exact-frame checks. That refusal is right here too — and it
means `_draw()` cannot run on that root. ⇒ **two subjects:**

- **(a) an untreed stage root** — the real materialise, the real `_on_ticked()` handoff, the entrance counter,
  `_camera.zoom` returning to `ZOOM_STEPS[_zoom_step]`. `visible` is read after hand-calling
  `_boss_bar._process(dt)`, which is an ordinary method on an untreed node.
- **(b) a bare `BossBarView` treed under `t.root`** with a synthetic `Monster`, `pump_frames`-ed — the
  `_paint_*` captures. Calling `_draw()` by hand barks "drawing outside NOTIFICATION_DRAW"; the runner pumps
  real frames for exactly this.

**(a) proves the shell hands the boss over. (b) proves something was painted. Ship only (b) and the bar is
beautiful and never appears; ship only (a) and it appears at zero size.**

⚠ **In (a) the net must drive the trigger, never hand-set `_boss_bar._boss`.** A `_wired_root` that pre-sets
the field hides `_on_ticked()`'s handoff line, and deleting the real wiring stays green while the game shows
nothing. Place `_char` east of `trigger_tx`, pump, read.

⚠ **Anything observing the materialise pumps `TICK_DIVIDER * 2` (= 6) physics frames, never one.** `wake_scan`
is on the tick and one physics frame crosses a tick boundary at most one time in three; a check that pumped
one frame passed while measuring nothing and let a mutation stay green at 437.

### Acceptance — what the net measures

1. **The captured `_paint_fill` rect equals `bar_rect(size)`**, and the captured `_paint_frame` rect equals
   `frame_rect(size)`. Not the pure functions alone.
2. **The captured `_paint_name` string, size and colour** equal `title_of(kind)`, `BOSS_NAME_SIZE`,
   `BOSS_NAME_COLOR`. And the captured position is inside the node's rect and **above** the frame rect.
3. **`visible` read directly** — false before the trigger, true after, false again once `hp <= 0`.
4. **The fill drains, three probes**: at `max_hp` the fill width equals `bar_rect().size.x`; at half hp it is
   half; at 0 the node is not visible. *One bite does not prove the range —* `GATE_ARCH_FADE_FRAMES`.
5. **The entrance fires once.** Place the character east of `trigger_tx`, pump, count monsters; place west,
   pump; place east, pump; the count has not moved.
6. **It does not fire early.** The character standing at `trigger_tx - 1` for 20 ticks materialises nothing —
   **and `MATERIALIZE_PX` alone would have**, since 720 > the whole of room ①. *That is the inversion:* delete
   the trigger branch and this goes red while every other check stays green.
7. **The zoom comes back.** After `boss_entrance_total_frames()` physics frames, `_camera.zoom ==
   Vector2(ZOOM_STEPS[_zoom_step], ZOOM_STEPS[_zoom_step])`, and `entrance_focus` returns the player focus
   **exactly**. *Inversion: delete the return leg.*
8. **The zoom is a multiplier, not a set.** Step the debug zoom, run an entrance, assert the end state is the
   *stepped* value — not `1.0`.
9. **Floor and ceiling on every beat constant.** `BOSS_BAR_FADE_FRAMES`, the three entrance lengths and
   `ENTRANCE_IDLE_TICKS` each get a probe at the low end **and** the high end. `GATE_ARCH_FADE_FRAMES` carried
   a floor on one end only and **2 through 11 were green** while the fade collapsed to a pop.
10. **The roar lands inside the hold** — the inequality in Stage D, asserted as an inequality.
11. **The rooster runs the same path**, driven, not asserted by reading the table.
12. **Every kind in `BossAi.MOVES` has a `BOSS_TITLES` row.** A data check, not a source-text scan — it is what
    catches a third boss shipping with a blank name.
13. **A row with no `trigger_tx` is unchanged.** Drive a pig row and assert it still wakes at 720.
14. **Invert the net, not only the code.** Write one case that fails *this net* — e.g. a `_CapturingBossBar`
    whose `_paint_fill` is never called must go red, and a `fill_frac` folded into the same array as
    `fade_alpha` must not let deleting one of them stay green. A dim check that folded two alphas into one
    array stayed green with the body dim deleted outright.

**The eye's, and none of it is a net's** — the design doc's own five, unchanged. Add one: **does the bar's
frame at 1:1 read as "big"**, or does the user want it wider (and therefore want new art).

### Risk

| # | What could break silently | Where it bites |
|---|---|---|
| 1 | **`snap_camera_px` divides by zoom and `ZOOM_STEPS` are powers of two on purpose** ("this division is exact"). `BOSS_ENTRANCE_ZOOM_MULT` 1.6 breaks that for the length of the entrance. The camera is moving the whole time so it should not read as shiver — **but it is a named cost, not an oversight.** If verify-look sees a one-pixel crawl during the hold, this is why | `stage.snap_camera_px` |
| 2 | **The bar sits inside `WINDOW_RECT` (48,12)-(912,384) deliberately**, on the premise "you are not assembling while a boss is arriving" — and **the tutorial breaks that premise** (`onboarding-and-palette-tabs.md`: the bull dies, slot fire, burn the wall — on the cut map the rooster's bar is up). If it reads badly, **the bar moves down, not the window** | `Fx.BOSS_BAR_RECT` |
| 3 | **The rooster's `trigger_tx` has two right answers and the map decides which.** Uncut: room ③ at `x245-268`. Cut: everything east of `x167` shifts −78, room ③ → `x167-190`. **One integer, and it must be re-derived the day the burn feature lands** — not left to rot | `stage1_monsters.gd` |
| 4 | **The bull's `tx145 -> tx140` moves the midboss's seat.** `net_monster_placement` groups rows and resolves them against the real map; `resolve()`'s full-width footing check must still pass at `tx140` (`ty32` is solid from `x130`, so it should). **Re-run the whole placement net, not the row being argued about** | `stage1_monsters.gd` |
| 5 | **`spawn_monster`'s 4th argument is a `Callable` call from `wake_scan`.** GDScript will not bark if the arity drifts through a `Callable` the way a direct call would — the wrong overload is a runtime error, not a parse error | `monster_placement.wake_scan` |
| 6 | **The bar holds a `Monster` that `_monsters` has already dropped.** `RefCounted`, so it stays alive; `hp <= 0` keeps `visible` false. **But it is a stale reference and `_rebuild()` is the only thing that clears it** — a second reset door added later that forgets this line strands a dead boss's bar | `stage.gd` |
| 7 | **The entrance freezes under the settlement panel** by living inside `not _settlement.is_showing()`. Correct — but it means "die during the entrance" leaves `_entrance_frames` mid-count until `R`. `reset_stage()` clears it; **nothing else does** | `stage._physics_process` |
| 8 | **Fake-code list**: the roar is a **real** `Pattern.WINDUP` with its real red ground prediction, not a cutscene pose; the bar reads `Monster.hp` live, never a copy; `visible` is derived, never latched. **The signature fake here would be a camera beat with no boss actually spawned** — check 5 is what stops it | — |
| 9 | **Sim constraints**: nothing in this feature touches `src/sim/`. The trigger comparison is float px in `src/actor/`, which is allowed there; `wake_scan` already does exactly this arithmetic for `MATERIALIZE_PX` | — |

### Out of scope — do not expand into these

- **The back door does not close** (`decisions/the-back-door-does-not-close.md`). No terrain is written.
- **Sound.** There is none in this repo. The roar is a picture.
- **A number inside the boss fill.** Design TBD, defaulted off.
- **Two bars.** One node, showing the boss that most recently entered.
- **Moving room ③ to buy the rooster a walk-out.** Named above as not happening.
- **Widening `WINDOW_RECT` or moving the assembly window.** If the overlap fails on screen the *bar* moves.
- **`net_gate` speed.** `harness-manager`'s.
- **A `trigger_tx` that reads facing, or that fires westward.** Both are TBD; position-and-eastward is what
  ships, and the limit is written into the code's own comment.

### Blockers — two, and `main` has to bring the answers back

1. **The rooster's name.** `BOSS_TITLES` cannot ship a blank row and check 12 makes that a red. **Stages A-C
   land without it; Stage D holds one string.**
2. **Does the world stop during the entrance, and is input taken.** **Planned as "nothing stops"** — that is
   this repo's only precedent (`stage._ready()`: "**The world is not stopped** — do not touch
   `get_tree().paused` here"), and the named cost is that the player can walk while the camera is on the bull
   and can walk off their own screen. **If the user wants a cutscene instead**, it is one guard in
   `_physics_process` and one in `stage_input`, not a redesign — but it is the difference between a beat and a
   cutscene and it is not spec's to decide.
