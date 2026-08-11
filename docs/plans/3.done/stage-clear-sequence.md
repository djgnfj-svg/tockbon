# Stage clear sequence — the beat between the kill and the town

**Status**: done — **implementation finished, acceptance NOT passed.** `3.done/` means the code landed and
the nets are green, not that anyone has seen it. **Every one of this doc's five screen questions is still
open** (they are listed in full under Acceptance → Screen, and carried here so they are visible without
opening the doc):

- Does the wall coming down register at all from where the player is standing.
- Does the arch fading up read as arriving, or as a rendering glitch.
- Does the brightening read as *the gate is taking you*, or does 0.4s just feel like input lag.
- Is the notice readable, and does it land as information rather than as an error message.
- Is `스테이지 1 클리어` obviously not `런 종료` at a glance.

**A sixth question used to be on this list and is not any more** — "do the two notice lines fit in their
band" turned out to be arithmetic, and is a check now (see Acceptance → Screen).

**And the arch's own first look is still owed** from `gate-ending-to-game.md` — it was never seen there
either, so this doc sits on top of an unverified picture.

**The mutations have since been run in full** — 21 of 21 bite, and **four holes were found green and are now
checks** (see "Corrected during implementation"). ⇒ **The headless half is verified. The screen half above is
not, and no amount of green touches it.**
**One line**: the rooster's death kicks the camera, the arch fades up instead of popping, standing in it takes
you over ~0.4s, and the settlement panel that opens says **스테이지 1 클리어** with two lines saying the build
ends here — then the existing button sends you to the town.

**This adds no new door and no new screen.** Every beat below hangs off machinery that already runs:
`gate-ending-to-game.md` (the wall, the arch, the `at_gate` term), `run-end-settlement.md` (the panel and its
button), `town-room-and-fixtures.md` (the town the button returns to).
**The return loop the user asked for already exists** — see "What happens today", step 5. What is missing is
that **a clear is indistinguishable from a death except for one word**, and that **nothing tells the player
the game ends here.**

---

## Why

### What happens today, step by step, in code — read before designing anything

Verified by opening each file, not from the plans.

1. **The rooster dies.** `world_step.gd` sets the boss-death flag; `Progress.boss_died(KIND_ROOSTER)`
   (`progress.gd:223-224`) starts answering true.
2. **The east wall vanishes.** `stage.gd:845-849` (`_on_ticked()`), behind the `_room3_gate_open` latch:
   one `CellGrid.cmd_fill(..., Mat.EMPTY)` over `StageGate.wall_cells()`. **Instant, and silent.** The
   renderer redraws on the same tick (`_grid.consume_changed()` runs after it, `stage.gd:870`). No shake, no
   flash, no sound — the player is 300–600px west of it and, per `net_gate`'s own camera check, **the wall is
   off screen from most of the room.** ⇒ today the wall coming down is an event nobody witnesses.
3. **The arch appears.** `gate_view.gd:37-40` — `visible = _progress != null and boss_died(KIND_ROOSTER)`,
   evaluated every idle frame. **It pops from nothing to fully opaque in one frame**, at full brightness,
   with no motion of any kind. `_draw()` is one `draw_texture_rect` of the town's own `departure_gate.png`
   through the `_paint(tex, rect)` hook (`gate_view.gd:53-68`).
4. **Walking into it opens the panel — on the very first frame of contact.** `stage.gd:815-827`
   (`_sync_settlement()`), every physics frame:
   `at_gate := boss_died(KIND_ROOSTER) and StageGate.at(_char.center())`;
   `want := (_char.downed or at_gate) and not _in_town`; on the rising edge,
   `_settlement.open(run_seconds, damage_dealt, gems_this_run, at_gate and not _char.downed)`.
   **There is no beat between touching the arch and the full-screen panel.** The world stops in the same call
   (`_physics_process` skips `_world.frame()` while `is_showing()`, `stage.gd:773`).
5. **The panel, and the way home.** `settlement_window.gd:135-162` draws exactly what a death draws — the
   only difference in the entire feature is `settlement_window.gd:148`, one ternary picking
   `Fx.SETTLEMENT_TITLE_CLEAR` (`"런 클리어"`) over `Fx.SETTLEMENT_TITLE` (`"런 종료"`).
   The `마을로` button emits `town_pressed`, wired at `stage.gd:408` to `enter_town()` →
   `_in_town = true` → `reset_stage()` → `_settlement.close()`, `_world.reset()` → `Progress.reset()` (the
   flag dies) → `_room3_gate_open = false` → `_build_room()` builds the town and stands the character at
   `TownMap.SPAWN_TILE`. **The loop is closed and it works.**

⇒ **Three gaps, and only three:**

- **A clear reads as a death.** One word out of a full screen. Everything else — timing, layout, motion,
  the way the panel arrives — is byte-identical to dying.
- **Nothing marks the two moments that matter** (the wall falling, the arch taking you). Both are single-frame
  state flips.
- **The player is never told the game ends here.** They clear stage 1, land in the town, and the only thing
  to do is walk back through the departure gate into the same stage. the NAN 2026 submission README sends judges
  to a public build with this exact ending; a judge who clears it is left guessing whether it broke.

### Why the third one is not softenable

This is a demo submitted to NAN 2026 (`docs/archive/nan2026/`). The submission README's own risk list is written
in the same voice — say what is missing plainly. **A player who finishes the only content there is must be
told that, in Korean, on the screen that ends the run**, not left to infer it from an empty town.

---

## Behavior

Four beats. **The first two are decoration on state that already flips; the third is the only one that
changes when the panel opens; the fourth is unchanged from today.**

### Beat 1 — the wall falls, and the camera feels it

On the same tick the wall is filled with `EMPTY` (`stage.gd`'s existing `_on_ticked()` block), kick the
camera shake that already exists: `Fx.GATE_WALL_SHAKE_PX` for `Fx.GATE_WALL_SHAKE_SECS`.

**Reuses `blast_fx`'s shake wholesale** — `_kick(px, secs)` (`blast_fx.gd:164-169`) already holds the
"stronger one wins" rule, the decay curve, and the circular offset; `stage._process` already lays
`shake_offset()` onto `_camera.offset` (`stage.gd:902`). **It is private today**, so `blast_fx.gd` gains one
public `kick(px, secs)` that forwards to it — the same "public so a net can drive it with no scene" seat
`advance()` already occupies in that file (`blast_fx.gd:84-86`).

**Longer and softer than a blast**: `SHAKE_SEC` is 0.20 and a generation-0 blast is a few px. A twelve-tile
stone wall is not a bolt. Values below.

**Why not a flash or debris at the wall**: the player is usually not looking at it (step 2 above), and a
flash nobody sees is a constant nobody can verify. **The shake is felt wherever you are standing** — that is
the entire reason this beat is a shake and not a picture.

### Beat 2 — the arch fades up instead of popping

`gate_view` counts **physics** frames since the rooster's flag went true (`_lit`, raised inside `tick_gate()`
— see the clock note under Interaction, and note it is the flag it counts from, not `visible`, which lives on
a different clock) and modulates its own texture from alpha 0 to 1 over `Fx.GATE_ARCH_FADE_FRAMES`.
Nothing else changes: same texture, same rect, same seat.

### Beat 3 — the arch takes you, and *then* the panel opens

Standing in the band no longer opens the panel on frame 1. `gate_view` counts a second counter (`_take`) on
**the same physics clock**, raised in the same `tick_gate()` call `stage._sync_settlement()` already makes,
and the panel opens when it reaches `Fx.GATE_TAKE_FRAMES`. While
it climbs, the arch's modulate ramps from white toward `Fx.GATE_TAKE_TINT` — **the arch brightens as it
takes you.**

**The order is pinned: increment first, then test.** `tick_gate()` raises `_take`, and only afterwards does
`_sync_settlement()` read `take_done() := _take >= Fx.GATE_TAKE_FRAMES`. ⇒ **the panel opens on the
`GATE_TAKE_FRAMES`-th frame of contact**, counting the first frame inside the band as frame 1. This is
written down because it is the difference between an off-by-one and a wrong expected value in every net
below — and because **no net may hardcode the resulting number.** Every check derives it from
`Fx.GATE_TAKE_FRAMES`; a literal there is the brittle equality that has already broken once in this feature
(see Collisions).

**The take latches once begun, and this is not optional.** `MOVE_SPEED_PX` is 260 (`character.gd:90`) and
the band is `REACH_PX * 2` = 96px wide ⇒ **a running player crosses it in 0.37s ≈ 22 physics frames.** A
derived, resettable hold of any length near that is **outrunnable — the ending would simply not fire**, which
is exactly this repo's "a thing that never happens" failure. ⇒ once `at_gate` is true for one frame, the
count runs to completion regardless of where the player goes.

**Why that latch cannot strand the game** (the standing objection —`run-end-settlement.md` Risk 3, a
`mouse_filter = STOP` panel stranded open makes the whole game unclickable):

- The only state it can produce is *the panel opens*. It has no branch that withholds it — at
  `GATE_TAKE_FRAMES` it opens unconditionally.
- It can only be set at all while `boss_died(KIND_ROOSTER)` is true.
- **Two independent collapses, either one sufficient**, exactly as `at_gate`'s own two are: `reset_stage()`
  calls `_gate_view.reset_gate()` directly (beside `_settlement.close()`), **and** the same call runs
  `Progress.reset()`, which makes the flag false so nothing can re-arm it.
- `want` itself stays **derived**, unlatched, in `_sync_settlement()`. The latch is on the take clock, not on
  the panel — the same distinction `stage.gd:944-948` already draws for `_room3_gate_open` ("this one strands
  nothing").

**The tie rule is unchanged: a death wins.** Touch the arch, then die before the take completes → `downed`
opens the panel that same frame with `cleared = false`. A downed body did not walk through the arch.

**Correction, found while implementing: `take_done()` *replaces* `at_gate` in `want`. It is not `and`ed
with it.** ⇒

```
var want := (_char.downed or _gate_view.take_done()) and not _in_town
_settlement.open(..., _gate_view.take_done() and not _char.downed)
```

The reading this doc invited — `(_char.downed or (at_gate and take_done()))`, and `at_gate and not downed`
for the fourth argument — **silently undoes the latch this whole beat rests on.** By the time the take
completes the player may well have walked out of the band; requiring `at_gate` again on the opening frame
hands back exactly the outrunnable hold the latch exists to prevent, and step 9 below cannot pass. **After
this correction `at_gate` is read for one purpose only: starting the clock.**

### Beat 4 — the panel, with the notice

The panel opens exactly as it does today, with two differences and no others:

- **The clear title becomes `스테이지 1 클리어`** (replacing the provisional `런 클리어` — the gate plan's own
  "the one thing the user has to decide... the user swaps the string"; nothing downstream reads it, and both
  nets that assert it read the constant, not the literal, `net_settlement.gd:205-215`).
- **Two notice lines appear between the rows and the button, on a clear only.**

```
스테이지 1 클리어

   플레이 시간     3분 12초
   준 피해          8,420
   원석            ▸ 7

   지금은 여기까지만 개발돼 있습니다.
   스테이지 2는 아직 없습니다.

        [ 마을로 ]
```

**The exact strings, and they are the deliverable:**

| Constant | Value |
|---|---|
| `SETTLEMENT_TITLE_CLEAR` | `스테이지 1 클리어` |
| `SETTLEMENT_NOTICE_1` | `지금은 여기까지만 개발돼 있습니다.` |
| `SETTLEMENT_NOTICE_2` | `스테이지 2는 아직 없습니다.` |

Two lines because `draw_string` does not wrap and a wrapped 40-character sentence is a layout problem for a
sentence that will be deleted the day stage 2 exists. **Neither line apologises, thanks anybody, or promises
anything.** They are the user's own words (*"지금 여기까지밖에 개발이 안 돼 있습니다"*) shortened by one clause.

**On a death, neither line is drawn.** A death is not the end of the content.

### Beat 5 — the town. Unchanged, deliberately

The button runs `enter_town()`, exactly as it does today, exactly as a death does. **One door home.**

**How a clear return differs from a death return**: everything before the button. Shake at the kill, an arch
that faded up, an arch that brightened while it took you, a different title, two lines of notice. **After
the button the two are identical and should be** — a second town-entry path would be a second copy of
`reset_stage()`'s list of everything that must be cleared, which is the thing `enter_town()`'s own header
(`stage.gd:1066-1069`) exists to prevent.

---

## Screen

**No new art.** Everything below is a modulate on `assets/town/departure_gate.png` (already drawn, already
loaded, already in the town's own table) or text on a panel that already draws text. `assets/fx/` was checked
for something to put at the falling wall (`blast_flash.png`, `debris.png`, `spread_moment.png`) and **none of
them is proposed** — see Beat 1 for why a picture at the wall is the wrong spend.

### New constants — all in `src/view/fx_tuning.gd`

| Constant | Value | Why this value |
|---|---|---|
| `GATE_WALL_SHAKE_PX` | `7` | Larger than any blast in `FX_SIZES` — a twelve-tile stone wall, once |
| `GATE_WALL_SHAKE_SECS` | `0.35` | `SHAKE_SEC` is 0.20 for a bolt; this is longer so it reads as *something collapsed*, not *something hit me* |
| `GATE_ARCH_FADE_FRAMES` | `24` | 0.4s. **Physics frames** — see the clock note under Interaction; on `_process` this same 24 would be 0.167s at 144Hz |
| `GATE_TAKE_FRAMES` | `24` | 0.4s, physics frames. The latch is what makes any value safe against the 22-frame crossing time (Beat 3); 0.4s is the shortest hold that still reads as a beat rather than a stutter |
| `GATE_TAKE_TINT` | `Color(1.7, 1.6, 1.25, 1.0)` | Over-bright warm. **The renderer is `gl_compatibility`** (`project.godot:88`) — no HDR, no glow, and nobody should later reach for either to "fix" this. **What produces the flare is that the mid-tones do not clamp**: the arch's dark linework and mid greys are multiplied up into bright warm tones while only the already-near-white pixels saturate. Clamping is what limits the effect, not what creates it |
| `SETTLEMENT_NOTICE_1` · `_2` | the strings above | |
| `SETTLEMENT_NOTICE_COLOR` | `Color(0.78, 0.70, 0.52)` | Dimmer and warmer than `SETTLEMENT_ROW_VALUE_COLOR` — it is an aside, not a figure |
| `SETTLEMENT_NOTICE_SIZE` | `18` | Under `SETTLEMENT_ROW_SIZE` (20), over nothing |

`SETTLEMENT_TITLE_CLEAR` changes value only.

### Layout — `settlement_layout.gd` gains one rect

`notice_rect(window_size) -> Rect2`. The three rows end at y≈278 (`TITLE_BAND_PX` 110 + 2×(44+18) + 44) and
the button's top is y=440 (`540 − PAD 48 − BUTTON_H 52`); the band between them is empty today.
`NOTICE_TOP_PX := 330`, `NOTICE_H_PX := 64`, full padded width — **measured from the top like `rows()`, not
stacked after them**, and a net asserts it clears both neighbours by literal comparison against
`rows(size)[2]` and `button_rect(size)`.

**A stale comment in that file, found on the way and not fixed here.** `settlement_layout.gd:25` declares
`BUTTON_BOTTOM_MARGIN_PX := 64.0` and `:42` explains that it is what keeps the button clear of the rows —
**but `button_rect()` never reads it**; it uses `Fx.SETTLEMENT_PAD_PX` (48). Grepped: the constant has zero
consumers in `src/` and `tests/`. **Do not build `notice_rect` on it**, and do not trust the 64 in that
comment. Whoever implements this should either delete the constant or make `button_rect` use it — but that is
a separate edit and is not smuggled into this plan.

**The frame counts above are physics frames at 60Hz.** `project.godot` does not set
`physics/common/physics_ticks_per_second` at all (grepped), so this is Godot's default 60, not a project
value — the day someone sets it, every `_FRAMES` constant here changes meaning and nothing barks.

### The hooks a net asserts — **and none of them is named `_paint`**

`monster_view.gd:196` already owns `_paint`, and `gate_view.gd:67`'s own `_paint(tex, r)` is renamed as part
of this work so the two stop sharing a name across a signature change.

| Hook | Where | What a net catches |
|---|---|---|
| `_paint_arch(tex: Texture2D, r: Rect2, tint: Color)` | `gate_view.gd`, cut out of `_draw()` (replaces `_paint`) | the texture, the rect, **and the modulate the fade/take decided** |
| `_draw_notice(font: Font, line1: String, line2: String, r: Rect2)` | `settlement_window.gd`, cut out of `_draw()` beside the existing `_draw_title` | that both Korean strings actually reach the paint on a clear, **and that the hook is never called on a death** |

Plus two pure statics that need no scene at all:

- `GateView.tint(lit_frames: int, take_frames: int) -> Color` — the whole of beats 2 and 3 as a value.
  `alpha = clampf(lit / GATE_ARCH_FADE_FRAMES, 0, 1)`, then
  `Color(1,1,1,alpha).lerp(GATE_TAKE_TINT, clampf(take / GATE_TAKE_FRAMES, 0, 1))`.
- `SettlementLayout.notice_rect(size) -> Rect2`.

**`"_draw() ran" is not "anything was drawn"** (CLAUDE.md, and `gate-ending-to-game.md`'s own finding 2 —
turning `draw_texture_rect` into `pass` left every check green). Both hooks above exist for exactly that, and
both are ordinary script methods because GDScript refuses to override `draw_texture_rect`/`draw_string`
(a hard parse error; `net_gate.gd:41-56` records it being measured).

### How the whole chain is driven in one net, end to end

`net_gate.gd`, one check, no new technique — every step below already appears in that file or
`net_settlement.gd`:

1. `_wired_root(t)`; `root.call("_leave_town")`.
2. **Premise, driven not assumed**: wall solid, `gate_view.visible` false, `_settlement.is_showing()` false.
3. `world.spawn_monster(KIND_ROOSTER, 400, 600)`; `world.monster_at(0).hp = 0`; pump 10 `_physics_process`.
4. `boss_died` true; every cell of `wall_cells()` non-solid; **`_blast_fx.call("advance", 0.01)` then
   `shake_offset() != Vector2i.ZERO`**, and `advance(GATE_WALL_SHAKE_SECS + 0.1)` puts it back to `ZERO`
   (a process measurement — "it shook" and "it stops shaking" are different claims).
5. `gate_view.call("_process", 0.0)` → `visible` true. Then the pure curve, by value:
   `GateView.tint(0, 0).a == 0.0`; `tint(GATE_ARCH_FADE_FRAMES, 0).a == 1.0`;
   `tint(GATE_ARCH_FADE_FRAMES, GATE_TAKE_FRAMES) == GATE_TAKE_TINT`.
6. **The tint through a real node, not only the pure function.** A `_CapturingGateView` (the subclass
   already in this file, its `_paint` override renamed to `_paint_arch(tex, r, tint)`): `setup(pr)` with a
   `Progress` carrying the rooster flag, `tick_gate(true)` **N** times, then `call("_draw")` →
   `last_tint == GateView.tint(N, N)` and `last_rect == GateView.rect()`.
   **Why this check exists**: without it, hardcoding `_paint_arch(_tex, rect(), Color.WHITE)` in `_draw()`
   leaves every other check green — the pure function is measured, the wiring is not, which is CLAUDE.md's
   own "a check that greps/reads the value beside the code, not the code" hole in its `_draw` form.
   The hand-called `_draw()` is safe **here specifically** because after this plan `_paint_arch` is `_draw()`'s
   only drawing call — no bare `draw_rect`/`draw_string` survives in `gate_view._draw()` to bark
   (contrast step 9).
7. **And that the shell actually turns it.** On the wired root with the character on the seat, one
   `root.call("_physics_process", ...)` → `_gate_view.take_frames()` is **1**, not 0. *(Deleting
   `tick_gate()`'s call site in `_sync_settlement()` is otherwise invisible: step 6 drives the view by hand.)*
8. **The exact opening frame, counted.** Character on the seat, then step one `_physics_process` at a time,
   recording the 1-based index on which `is_showing()` first turns true:
   **`t.eq(opened_on, Fx.GATE_TAKE_FRAMES)`** — and separately **`t.ok(Fx.GATE_TAKE_FRAMES >= 12)`**, a
   literal floor so the delay cannot be defeated by shrinking the constant to 1 or 2.
   **Why the first half is not the "bounds from the thing it checks" trap**: the constant is a tuning value
   the user may move, and what this pins is that **the code obeys it**. The literal floor is what pins the
   constant itself. Without this check, `GATE_TAKE_FRAMES = 2` leaves every other check in this plan green.
9. **The latch, measured as what survives the player leaving.** Character on the seat, **one**
   `_physics_process`, then `_char.place(...)` back at the stage's own spawn — **`Stage.SPAWN_TILE`, the one
   tile the shell itself guarantees is standing ground (`_build_room()` uses it), never `seat + 400px`**,
   which is a terrain guess and Track A is repainting the terrain. Pump `GATE_TAKE_FRAMES` more frames →
   panel open. Assert **`not _char.downed` as an explicit premise immediately before** reading `_cleared`:
   a character that fell and went down would flip `_cleared` false via the tie rule and this check would
   fail for a reason that has nothing to do with the latch.
10. **The notice actually painted** — driven the way `net_settlement.gd:198-217` already drives the title,
    **not** by a hand `_draw()`. `settlement_window._draw()` still calls `draw_rect`/`draw_string`/
    `draw_texture_rect` for the rows and the button, and the engine refuses those outside a real
    `NOTIFICATION_DRAW` dispatch (that file's own header, `:193-196`, records the bark verbatim).
    ⇒ `t.root.add_child(win)`, `win.open(..., true)`, `win.queue_redraw()`, **`await t.pump_frames(3)`** →
    both notice strings captured; reopen with `cleared = false`, pump again → **zero `_draw_notice` calls**.
    `remove_child` + `queue_free` after. **The check must be `await`ed in `run()`** — a missing `await` is
    what once made a whole net vanish with exit code 0 (CLAUDE.md, "Running the nets" 1).
11. `root.call("enter_town")` → panel closed, `_in_town` true, `boss_died` false, **`take_frames() == 0`
    and `lit_frames() == 0`**, and `_process` → `visible` false.

**Inversions to run** (each must bite, and confirm the mutation landed before suspecting the check):

| Mutation | Must go red |
|---|---|
| Delete the `kick()` call in `_on_ticked()` | step 4's shake check |
| `tint()` returns `Color.WHITE` always | step 5 |
| **`_paint_arch(_tex, rect(), Color.WHITE)` hardcoded in `_draw()`** | step 6 |
| **Delete `tick_gate()`'s call from `_sync_settlement()`** | step 7 |
| **`GATE_TAKE_FRAMES` → 2** | step 8's literal floor |
| **`take_done()` tests before incrementing** (off by one) | step 8's `opened_on` equality |
| Drop the latch (`_take` resets when `at_gate` goes false) | step 9 |
| Delete `_draw_notice`'s call from `_draw()` | step 10 |
| Draw the notice unconditionally | step 10's death half |
| Delete `reset_gate()` from `reset_stage()` | step 11 |
| **`reset_gate()` clears `_take` but not `_lit`** | step 11's `lit_frames()` half |

---

## Bounds

- **The arch has never been looked at on screen.** `gate-ending-to-game.md`'s Acceptance/Screen half is
  entirely open and this plan sits on top of it. ⇒ **verify-look must confirm the arch appears at all
  before judging the fade.** If it does not appear, that is that plan's bug, not this one's.
- **A clear whose take is interrupted by death** — covered, the tie rule stands (Beat 3).
- **A player who reaches the seat over the roof** — `StageGate.at()`'s y band already refuses it; the take
  never starts. Unchanged.
- **Water deeper than ~3 tiles at the seat lifts the player out of the band** — `gate-ending-to-game.md`
  Risk 6, `3.done/water-jump-and-escape.md`'s to answer. **This plan makes it strictly less bad**: with the
  latch, one frame inside the band is now enough, where today the panel needed the frame the panel opened on.
- **The shake fires once**, off `_room3_gate_open`'s existing latch — it is inside that `if` block, so a
  per-tick re-kick is structurally impossible.
- **`R` during the take** — `reset_stage()` clears `_room3_gate_open`, the panel and now the gate clocks, and
  rebuilds the terrain in the same call. Nothing survives it.
- **The notice is a lie the day stage 2 exists.** It is two constants and one branch; deleting it is one
  edit. Named in TBD.
- **No audio.** There is no audio subsystem in this project at all (`run-end-settlement.md`'s own Decided 1).
  The wall falling and the arch taking you are silent, and that is not fixable here.
- **`net_gate` keeps the untreed `_wired_root`; it was not converted to a treed scene.** The treed approach
  (instantiate `stage.tscn`, `add_child` it, let Godot run `_ready()` so every `@onready` resolves with no
  hand wiring) is the more honest harness in general, and it is what a sibling track adopted. **It was
  rejected here for one specific reason**: a treed root receives `_physics_process` at engine frame
  boundaries, and `_the_panel_opens_on_exactly_the_take_frames_th_frame` counts physics frames one at a time
  and asserts the exact index. Uncounted engine frames would turn **the only check that measures the take's
  length at all** into a timing-dependent one. The honesty this buys elsewhere is already bought here by the
  compiler (the parse-error row above). ⇒ **Converting `net_gate` wholesale is harness-manager's**, not this
  feature's — and that file is 24.3s of a 24.4s round, so it is theirs on two counts.

---

## Interaction with what exists

### `decisions/run-end-is-settlement-only.md` — honoured, no reversal

That decision rejects **a run summary** (the circle you assembled, a route, a kill list) and **a second
screen**. It does not reject text on the settlement screen: two figures already print beside the settlement
under it, on the stated ground that *"the only thing that animates is the currency counting up, and those two
do not scroll, expand or break down."*

**The notice satisfies exactly that test**: it is static, it never expands, and — the deciding point — **it
says nothing about the run.** It is a statement about the build. A run that ends the same way twice prints
the identical two lines.

The two alternatives were weighed and both lose:

| Placement | Why not |
|---|---|
| **Its own beat** (a screen between the panel and the town) | **A second screen — refused by name.** Would be a reversal to record, for a two-line message |
| **The town side after returning** | The town's only text channel is `_town_message`, a debug HUD line (`stage.gd:1264`) that the NAN 2026 submission README already lists as a risk ("개발용 안내 두 줄이... 심사자에게 개발 콘솔을 보여주는 셈"). Adding the one message that must not be missed to the one surface already flagged as noise is the worst of the three. **And the moment has passed** — the player has pressed the button and walked into another room |

⇒ **The settlement screen, on a clear only.** `town.md`'s standing TBD *"do death and clearing look
different"* — which that decision already moved onto this screen — is answered by this doc and can be closed
when it lands.

### Everything else

- **`gate-ending-to-game.md`'s "three reads of one accessor"** stays three. This plan adds **no new read of
  `boss_died()`** — the take clock hangs off the `at_gate` term `_sync_settlement()` already computes.
- **`circle_window.gd:13-15`**'s narrowed "no full-screen `Control` while the run is live" is untouched:
  the fade and the flare are a `Node2D` modulate in world space, not a `Control`. **This is why the beat is
  a brightening arch and not a fade to black** — a full-screen black `Control` during a live run would
  reopen a rule this repo already narrowed once.
- **Both counters run on the physics clock. `_process` is not a clock and must not be used as one.**
  `tick_gate()`, called once from `stage._sync_settlement()`, raises **both** `_lit` and `_take`:

  ```
  func tick_gate(at_gate: bool) -> void:
      if _progress != null and _progress.boss_died(MonsterDefs.KIND_ROOSTER):
          _lit += 1
      if at_gate or _take > 0:      # once begun, it runs to completion
          _take += 1
  ```

  **`_progress` is already held** (`gate_view.gd:21`), so `_lit` needs nothing new passed in.

  **An earlier draft put `_lit` on `gate_view._process()` and argued the mix was harmless. That was wrong.**
  `_process` runs at the **monitor refresh rate**, not 60Hz: `GATE_ARCH_FADE_FRAMES = 24` would be 0.4s on a
  60Hz panel, **0.167s on a 144Hz one**, and longer again in a throttled or background window — one animation
  whose two halves run at different, machine-dependent speeds. The repo had already written this down twice
  (`settlement_window.gd:19-21` and the `three_pick_window.tick_confirm()` header it cites: "a screen clock on
  the idle rate and a HUD reader on the physics rate open a one-frame seam"). **Both clocks are physics now,
  and every frame count in this doc means one `_physics_process`.**

  **`visible` stays on `_process()`** — deliberately, and it is the one thing not moved. Derived there, the
  arch appears on its own even if nothing ever calls `tick_gate`; moved onto `tick_gate` it would depend on
  the shell remembering to call it, which is `gate-ending-to-game.md`'s own finding 1 (deleting `stage.gd`'s
  `_gate_view.setup()` line left every check green and the arch never appeared). `net_gate:383` and `:410`
  keep driving `_process` by hand and need no edit for `visible`.
  **The knock-on**: every new check below drives `root.call("_physics_process", ...)` or `tick_gate()`
  directly, so nothing in this plan depends on the render rate at all.
- **`net_pick`'s collection scan**: both new `gate_view` fields are `int`. No allowlist entry needed.
- **`net_render`**: no node added to `stage.tscn`, so `INTERACTIVE` / `OUT_OF_TREE_SIZE_ZERO` /
  `_wired_stage_root` are all untouched.
- **the NAN 2026 submission README's risk list** ("클리어 판정이 없다") is already stale — the gate landed. Not
  this doc's edit, but whoever closes the submission should re-read that list.

---

## Cost

| Item | Price |
|---|---|
| `blast_fx.gd` | One public `kick(px, secs)` forwarding to the existing `_kick` |
| `stage.gd` | Three insertion points: the kick inside the existing `_on_ticked()` block, `tick_gate(at_gate)` **and `take_done()` replacing `at_gate` in both `want` and `open()`'s fourth argument** inside `_sync_settlement()` (see Beat 3's correction — "`tick_gate(at_gate)` + `take_done()`", as this row first read, invites the one wrong reading that kills the latch), `_gate_view.reset_gate()` inside `reset_stage()` |
| `gate_view.gd` | Two `int` fields, `tick_gate` / `reset_gate` / `take_done` / `take_frames` / `lit_frames`, the static `tint()`, `_paint` → `_paint_arch` with a third argument. **`reset_gate()` zeroes both counters** — clearing only `_take` leaves the arch popping on run two |
| `settlement_window.gd` | One `_draw_notice` hook, called only when `_cleared` |
| `settlement_layout.gd` | One `notice_rect()` |
| `fx_tuning.gd` | Eight new constants, one value changed |
| Art | **Nothing.** No new image, no resize, no regeneration |
| Nets | ~10 new checks in `net_gate.gd`, ~4 in `net_settlement.gd`, plus the edits under Collisions |

**Files to add a fourth beat later: one** (`fx_tuning.gd`) if it is a timing, two if it draws.

---

## Acceptance

**Headless** — the end-to-end chain above, plus every inversion in that table shown to bite. Specifically:

1. A real rooster death moves `shake_offset()` off zero, and it returns to zero on its own.
2. `tint()` walks 0 → opaque over `GATE_ARCH_FADE_FRAMES`, then white → `GATE_TAKE_TINT` over
   `GATE_TAKE_FRAMES`, **and `_paint_arch` on a real node receives that exact colour** (not only the pure
   function — step 6).
3. **`_gate_view.take_frames()` moves when the shell drives one physics frame**, so deleting `tick_gate()`'s
   call site is visible.
4. **The panel opens on exactly the `Fx.GATE_TAKE_FRAMES`-th frame of contact**, measured by counting frames,
   compared against the constant — plus a literal floor `GATE_TAKE_FRAMES >= 12` so the constant itself
   cannot be shrunk to nothing.
5. Touching the seat for **one** frame and then leaving still ends the run (the latch), with `not downed`
   asserted as a premise.
6. Both notice strings reach `_draw_notice` on a clear, **through a treed, pumped draw pass**; it is called
   **zero** times on a death.
7. `notice_rect()` overlaps neither `rows(size)[2]` nor `button_rect(size)`, computed, not literal.
8. `enter_town()` clears **both** gate clocks (`take_frames() == 0` **and `lit_frames() == 0`**), the panel,
   the flag and the arch's `visible` together. **`_lit` surviving is not cosmetic**: on the second run the
   arch would pop fully opaque in one frame — beat 2 gone, every other check green.
9. A death still opens the panel on the frame you go down, with `런 종료` and no notice. Unchanged.

**Screen** (verify-look) — **and the arch's own first look is still owed** (`gate-ending-to-game.md`):

- Does the wall coming down register at all from where the player is standing.
- Does the arch fading up read as arriving, or as a rendering glitch.
- Does the brightening read as *the gate is taking you* — or does 0.4s just feel like input lag.
- **Is the notice readable and does it land as information rather than as an error message.**
- Is `스테이지 1 클리어` obviously not `런 종료` at a glance.

⚠ **One question was removed from this list — "do two 18px lines fit inside `NOTICE_H_PX` 64".**
**It is a value, not a feel**, and filing it here meant nothing measured it. Font metrics are readable
headless (`ThemeDB.fallback_font`, the same default theme font `settlement_window` itself falls back to), so
it is now a check in `net_settlement`. **Measured: line height 26, two lines 52 against 64; widths 289 / 228
against 864 — it fits, with 12px to spare.** Nothing was broken; what was missing was anything that says so
**the day `SETTLEMENT_NOTICE_SIZE` is bumped or a line is lengthened**, both of which would clip in silence.
⇒ **What stays here is only whether the notice *reads* as information. Whether it fits is arithmetic.**

---

## Collisions

**Three tracks are live and this is a three-way contention, not a two-way one.** Track A
(`3.done/left-run-clumps-and-platforms.md`) is editing terrain and the shell; Track B (the research bench)
owns `progress.gd` / `research_window.gd`.

**Correction to an earlier draft of this section, which said this plan touches none of Track B's files.**
That was false. **Track B also edits `stage.gd` and `fx_tuning.gd`** — the same two files this plan's three
shell lines and eight constants land in — **and it adds a node to `stage.tscn`**, which this plan declares
"must not be touched". The accurate statement is narrower: *this plan* adds no node to `stage.tscn` and reads
`progress.gd` without writing it. **`stage.gd`, `fx_tuning.gd` and `stage.tscn` are contended by all three
tracks.** Serialise this one last; it is presentation only and has nothing waiting on it.

| File | Function / symbol | Owned tonight by | Note |
|---|---|---|---|
| `src/stage/stage.gd` | `_on_ticked()` (the `_room3_gate_open` block), `_sync_settlement()`, `reset_stage()` | **left-run track** | Three separate insertion points, none adjacent to terrain/monster code |
| `src/view/fx_tuning.gd` | new `GATE_*` block, new `SETTLEMENT_NOTICE_*`, `SETTLEMENT_TITLE_CLEAR` value | **left-run track** | Append-only except the one changed value |
| `tests/nets/net_gate.gd` | `_CapturingGateView._paint` → `_paint_arch(tex, r, tint)`; **every check that places the character on the seat and pumps one frame** — `_standing_on_the_seat_after_the_kill_ends_the_run` (`:529`) and `_the_button_closes_the_gate_panel_and_returns_to_town` (`:637`) — must pump `Fx.GATE_TAKE_FRAMES`. **`_a_downed_body_on_the_seat_reads_as_a_death_not_a_clear` (`:613`) is struck from this list — it must NOT pump.** `downed` opens the panel on frame 1 regardless of the take clock, which *is* the tie rule Beat 3 states; pumping past the take would weaken it into measuring nothing, since by then the clear path would open the panel anyway; **and `_it_opens_exactly_once_over_two_hundred_frames` (`:552`) needs its expected value changed, not just its pump count** | **left-run track** | **These go red the moment beat 3 lands.** They are correct today and correct after; only the frame counts change. **The once-check is the sharp one**: it asserts `t.eq(_frames, 200)` *exactly* (`:569-570`), and with the take delay the panel no longer opens on the frame the character is placed. **The fix is to keep 200 and change the drive, not to compute a new expected value**: replace the single opening `_physics_process` (`:564`) with `for _i in Fx.GATE_TAKE_FRAMES:` — the panel then opens on the last of those, `_frames` becomes 1 inside it exactly as today, and the following 199-frame loop still lands on 200. **Do not write a new literal here.** An earlier draft of this doc first claimed the check was unaffected (wrong — it is an exact equality, not a threshold) and then predicted `176` (**also unsound**: increment-then-test gives 177, test-then-increment gives 176, and a hardcoded either is the same brittle equality that just broke). This plan pins increment-then-test (Beat 3) and every net derives from `Fx.GATE_TAKE_FRAMES`. `_above_the_seat_does_not_end_the_run` (`:576`) really is unaffected (the take never starts) |
| `src/actor/stage_gate.gd` · `src/stage/terrain_map_generated.gd` · `src/stage/stage.tscn` | none — **read only** | **left-run track (edit in progress)** | That track shifts every map coordinate east of x101 by **−100 tiles**, so `SEAT_TILE_X` / `WALL_TILE_*` move under us. **Every geometric reference in this plan is by name** — `seat_px()`, `floor_y_px()`, `wall_cells()`, `REACH_PX` — and re-pins itself. See the literal audit below |

### Literal audit — every number in this doc that a map shift could rot

**Two, and both are safe. Named so they can be re-pinned rather than trusted.**

| Literal | Where | Safe? |
|---|---|---|
| `spawn_monster(KIND_ROOSTER, 400, 600)` | the net drive, step 3 — **copied verbatim from `net_gate.gd:249`**, not derived | **Yes.** 400 cells ÷ `TILE_CELLS` 8 = **tile 50**, west of x101, so the −100 shift does not touch it. But it is a literal reproduced rather than computed: **if Track A moves it in `net_gate.gd`, copy theirs, do not keep this one** |
| `96px` band width, `0.37s`, `22 frames` | Beat 3's outrun arithmetic | **Yes.** `REACH_PX * 2` and `MOVE_SPEED_PX` (`character.gd:90`) — neither is a map coordinate, and both are read by name |
| ~~`seat + 400px`~~ | step 9's outrun placement | **Deleted.** It assumed standing ground 400px east of a seat whose column is moving and whose terrain Track A is repainting. Replaced with `Stage.SPAWN_TILE` — the one tile the shell itself guarantees — plus an explicit `not _char.downed` premise so a fall can never be mistaken for a latch failure |

**Panel-internal numbers (110 / 278 / 330 / 440 / 540) are screen coordinates inside a 960x540 `Control`.**
They have nothing to do with the map and do not shift. They *are* derived by hand from
`settlement_layout.gd`'s constants, so they rot if that file's layout changes — which is why `notice_rect`'s
acceptance is a **computed** non-overlap against `rows(size)[2]` and `button_rect(size)`, never a literal.
| `src/view/monster_view.gd` | none — **name only** | **left-run track** | `_paint` at `:196` is why the new hook is `_paint_arch` |
| `src/view/gate_view.gd` | `_paint` → `_paint_arch`, `tick_gate`, `reset_gate`, `take_done`, `tint` | free | |
| `src/view/blast_fx.gd` | new public `kick()` | free | |
| `src/view/settlement_window.gd` · `settlement_layout.gd` | `_draw_notice`, `notice_rect` | free | |
| `tests/nets/net_settlement.gd` | notice checks, `notice_rect` layout checks | free | |

**This plan adds nothing to**: `stage.tscn` (no new node — Track B does add one), `progress.gd` (read only),
`world_step.gd`, `fixtures.gd`, `town_view.gd`, `net_tables.gd`, `terrain_map_generated.gd`.

### `net_town.gd` and `net_render.gd` — missed by the list above, and the failure was the dangerous shape

**Correction, found while implementing. This plan claimed to add nothing to `net_render.gd` or
`net_town.gd`. That was wrong, and it is a cost this doc never counted.**

`stage.gd`'s three lines call `_gate_view.tick_gate()` every physics frame and `_gate_view.reset_gate()` in
`reset_stage()`, **both unconditionally.** Every net that stands a *hand-wired* stage root — `_ready()` never
runs outside the tree, so `@onready var _gate_view` is never resolved — must therefore wire `_gate_view`
itself. `net_gate` and `net_settlement` already did. **`net_town._wired_root` and `net_render`'s two helpers
did not**, and each needs one entry: `["_gate_view", "GateView"]`.

**The symptom was not red — it was silence.** `Invalid call. Nonexistent function 'tick_gate' in base 'Nil'`
kills the check *mid-call*, so `net_town` reported **0 passed** rather than a named failure: the checks
**disappeared instead of failing.** That is `net_gate.gd:688`'s own recorded shape ("267 passed for a file
that should have run 305"), and it is why the wrapper's "a net that ran zero checks is a failure" guard is
what caught this rather than any assertion. **A count dropping between rounds is itself the signal.**

**Not fixed by guarding the call site**, deliberately. A null-tolerant `reset_stage()` would let a genuinely
missing wire through in the shipped game, which is the trap CLAUDE.md's hand-wiring section names; the
neighbouring `_settlement` and `_research_window` calls are unguarded for the same reason.

**Deleting the wiring still fails three separate ways** — and **this is reasoning, not measurement.** None of
the three was run as a mutation, because doing so means breaking `src/` in a tree two other tracks were
writing to. Read them as an argument to check, not as a result:

| Deleted | What fails |
|---|---|
| `stage.tscn`'s `GateView` node | The `씬에 GateView 가 있다 (전제)` premise, by name, in `net_gate` · `net_settlement` · `net_town` |
| `stage.gd`'s `@onready var _gate_view` declaration | **A parse error** — three call sites still reference it, so every net that loads `stage.gd` dies |
| `stage.gd:405`'s `_gate_view.setup(...)` | `net_settlement._ready_itself_connects_the_button_to_enter_town`, which nulls `_progress` first for exactly this |

**The middle row is why Track B's treed-scene harness was not needed for this field.** Hand-wiring hides the
shell's own line only when deleting that line stays *green*; here the compiler catches it before any check
runs. That is a genuinely different situation from the one CLAUDE.md describes, and it is the reason
`_wired_root` was kept rather than converted — see also the harness note under Bounds.

**Build order if serialised**: `fx_tuning` constants → `gate_view` (fade/take/tint/hook) → `blast_fx.kick` +
`stage.gd`'s three lines → `settlement_layout` + `settlement_window` → nets. The `net_gate` frame-count edits
must land **in the same commit as** beat 3 or that net goes red for the right reason at the wrong time.

**Do not touch `net_gate.gd` until Track A's coordinate shift is committed.** That file is mid-edit right
now and the two halves already disagree: `stage_gate.gd` on disk carries **`SEAT_TILE_X := 270` /
`WALL_TILE_X0 := 267`** (HEAD has 370 / 367) while `net_gate.gd` still asserts `Rect2(11820, 712, 72, 88)`
and literal tiles 367/368, and symbols cited during this doc's own review had already moved lines by the time
it was re-read. **Editing into that produces red nobody can attribute.** Wait for the commit, re-read the
file, then apply the frame-count edits above.

---

## TBD

- **Does the notice also belong on the title screen or the town** the day the demo is actually judged.
  Decided against for now (see Interaction); reopen only if verify-look finds the panel is skipped past.
- **What the notice becomes when stage 2 exists.** Deleted, presumably — two constants and one branch.
  Not designed here.
- **Whether a clear pays more than a death.** Untouched: `gate-ending-to-game.md`'s Out of scope holds — the
  title changes, the notice appears, and nothing else does.
- **Does the wall need anything more than a shake.** `blast_flash.png` / `debris.png` exist and were
  deliberately not spent (Beat 1). If verify-look reports the wall falling is still invisible, that is the
  cheapest next thing to try.
- **`GATE_TAKE_FRAMES` = 24 is a feel value and has never been felt.** The latch makes any value safe; only
  the screen can say whether 0.4s is a beat or a stutter.

## What I could not close from the repo — read this before implementing

**Three judgment calls and one unverified engine claim.** None blocks the build; all four are places where a
reviewer reading source will be reading further than I did.

**Two remain open. Four earlier entries were closed by review and are kept below the line, because a doc
that quietly fixes itself teaches nothing.**

1. **`GATE_TAKE_TINT = Color(1.7, 1.6, 1.25, 1.0)` has still never been rendered.** The renderer is
   `gl_compatibility` (`project.godot:88`) — no HDR, no glow — and the flare comes from **mid-tones
   multiplying up without clamping**, with only near-white pixels saturating. That is how the backend
   behaves, not something measured on this sprite. **Only verify-look can say whether the arch reads as
   flaring.** Fallback if it does not: a ramp with no component above 1, toward a warm near-white.
   The plan does not rest on it — every net asserts the *colour handed to `_paint_arch`*, never pixels.
2. **The notice's placement is a judgment call, not the user's instruction.** They said the message must be
   shown; they did not say where. The argument against the town and against a third screen is in
   Interaction, and it rests on reading `run-end-is-settlement-only.md` as banning *run reports*, not *all
   text*. **Read that decision more strictly and the notice moves, and this doc then needs a
   `docs/decisions/` entry.** None was written, because on this reading nothing was reversed.

### Corrected during implementation — recorded, not deleted

**Three places this doc was wrong against the code, and four places its nets were.** The wrong reading is
kept visible in each case, because it is the one an implementer would arrive at unaided.

#### The four holes the inversion pass found — **all four were green, all four are now checks**

| Mutation | Was | Now |
|---|---|---|
| **`_draw()` hands `_draw_notice` a `Rect2()`** instead of `Layout.notice_rect(size)` | **320 green.** The notice draws at (0,0) with zero size — off the panel, invisible — and **the one sentence telling the player the build ends here silently does not appear** | `_CapturingSettlementWindow` captures the rect (it was named `_r` and discarded) and asserts it equals `notice_rect()` |
| **`GATE_ARCH_FADE_FRAMES = 2`** | **433 green.** Beat 2 becomes a 2-frame pop — exactly the "pops from nothing to fully opaque" it exists to remove. `= 1` bites only by an integer-division accident in the curve probe, so **the real hole was 2–11** | a literal floor `>= 12`, symmetric with the one already on `GATE_TAKE_FRAMES` |
| **`GATE_WALL_SHAKE_PX = 1`** | **green** — the shake check asked only `!= Vector2i.ZERO` | asserted against `FX_SIZES`' own `shake_px`, which is the constant's own stated reason ("larger than any blast") |
| **`kick()` moved out of the `_room3_gate_open` latch**, firing every tick | **433 green.** The camera shakes for the rest of the run and nothing sees it | one more pass of physics frames after the settle assert, re-asserting `ZERO` |

**The first one is the finding.** This doc closed the *identical* shape one file over, deliberately and with
a comment explaining it — `_the_drawn_tint_is_the_one_the_counters_decided` exists because hardcoding
`_paint_arch(_tex, rect(), Color.WHITE)` left the pure tint curve measured and the wiring unmeasured. The
notice's layout is that same pure function, and **nothing asked whether `_draw()` used it.**
⇒ **Measuring a pure layout function is never measuring the layout**, and the second instance was missed by
the author who had just fixed the first.

**The fourth row's own fix was written wrong the first time, and is recorded because it is the same class of
mistake.** A single extra `_physics_process` did not bite: `_on_ticked()` runs only on a 20Hz tick, so one
physics frame crosses a tick boundary at most one time in three — and in that check's phase, none. The
mutation was confirmed to have landed *before* the check was suspected (CLAUDE.md's rule), and the fix is to
pump `TICK_DIVIDER * 2`. **A check written to close a hole is exactly the kind that gets written wrong and
looks right.**

| Was written | Corrected to |
|---|---|
| Cost: "`tick_gate(at_gate)` + `take_done()` inside `_sync_settlement()`", which reads as `at_gate and take_done()` | **`take_done()` replaces `at_gate`** in both `want` and `open()`'s fourth argument (Beat 3). The `and` reading silently undoes the latch and step 9 cannot pass |
| Collisions: `_a_downed_body_on_the_seat_reads_as_a_death_not_a_clear` "must pump `GATE_TAKE_FRAMES + 1`" | **It must not pump at all.** `downed` opens the panel on frame 1 regardless of the take clock — that *is* the tie rule. Pumping past the take weakens it into measuring nothing |
| "This plan adds nothing to `net_render.gd`, `net_town.gd`" | **Both need `["_gate_view", "GateView"]` wired.** And the failure shape was checks *disappearing*, not failing — see the section above Collisions' file list |

### ~~Still open: none of the new checks has been inverted~~ — **run in full, and it found four holes**

**Closed.** An adversarial pass by an agent that **did not build this feature** ran every row of the
inversion table above plus ten more. **21 mutations, 21 bite** — each on the check it names and nothing
further out of place. That includes the three rows this doc marked as *reasoning, not measurement*, all
three confirmed exactly as argued:

| Deleted | Predicted here | Measured |
|---|---|---|
| `stage.tscn`'s `GateView` node | premise fails by name in three nets | ✓ red in `net_gate` · `net_settlement` · `net_town` |
| `stage.gd`'s `@onready var _gate_view` | a parse error | ✓ `Parse Error: Identifier "_gate_view" not declared` |
| `stage.gd`'s `_gate_view.setup(...)` | `net_settlement` only | ✓ 1 red there, and **`net_gate` stays fully green** — it really is the sole guard |

Deleting `net_town`'s wire went **red *and* dropped the count 259 → 258**, both symptoms this doc predicted.

**But four mutations stayed fully green, and one of them is this feature's own headline failure.**

### Closed by review — recorded, not deleted

| Was open | Closed how |
|---|---|
| `tick_gate()`'s body was left to the implementer | **Written out in full** (Interaction), including the increment-then-test order it turned out to hide |
| `_lit` on the idle clock, argued harmless | **Wrong, and fixed.** `_process` is the monitor refresh rate: 24 frames is 0.4s at 60Hz and **0.167s at 144Hz**. Both counters are physics now |
| `_take` growing unbounded while the panel is open | Still true, still clamped in `tint()`, still harmless — **and now bounded in practice too**, since `reset_gate()` is asserted to zero both counters (acceptance 8) |
| The predicted `176` for the once-check | **Unsound and removed.** Increment-then-test gives 177, test-then-increment 176; the fix is to change the drive and keep the 200, deriving from `Fx.GATE_TAKE_FRAMES` |
