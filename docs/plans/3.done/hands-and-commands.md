# Plan 2 — hands and commands

**Status**: `3.done` — **built, and the keys are accepted; the picture is not.** Part of
[the grassland index](../1.ready/grassland-whole-loop.md). Built after [the run shell](run-shell.md).
⚠ **`3.done` means implementation finished, not acceptance passed** — see *Acceptance* at the foot of this
file for what was heard and the three questions still open.

✅ **Corrected for [the 2026-08-14 adversarial review](../../adversarial-review-2026-08-14-ko.md) and for
[hunting and the boss](../../design/hunting-and-the-boss-ko.md)** — force ×10, `FORCE_START` 10, the level
pays force instead of clones, `command_rally()` loses its argument, `add_clone()` gets defaults, `_absorb()`
is split in two rather than deleted, and every count in *Fallout* below was taken from a full-repo grep
rather than from memory. **Where this file and any older doc disagree, this file is newer.**

**What it closes**: **the hands.** Every key the game will ever have, wired, with force underneath so `F`
has something to halve. After this plan the swarm grows and shrinks because the player pressed something.

**Planning principle 1: the hands must never be idle.** This is the plan that decides whether that is true.

---

## The full key map, after this plan

| Key | What it does | New? |
|---|---|---|
| `WASD` | move the host | exists |
| **left click** | fire active slot 0 — opens holding `BITE` | **new** |
| **right click** | fire active slot 1 — **empty until plan 3** | **new** |
| **`space`** | fire active slot 2 — **movement actives only**; opens holding `DASH` | rewired |
| **`F` (held)** | split: the host and every clone halve at once | **new** |
| **`V`** | absorb every clone within a radius | **new** |
| `1` | **rally to the host** — clones come to me | **changed** |
| `2` | scatter | exists |
| **`3`** | strike the mouse point — the swarm goes there and stays | **new** |
| **`Tab`** | the body panel: slots, parts, and active binding | **new** |
| `Esc` | closes the body panel in PLAY; title/ending as in plan 1 | extended |

**The three active slots are the whole of the player's offense**, and **`space` accepts only actives flagged
`movement`** (user, 2026-08-14).

⚠ **Slot 0 and slot 2 open bound, slot 1 opens empty, and that is deliberate.** The dash does not vanish
waiting for plan 3 — it moves from a hardcoded key into slot 2, so no hand goes idle across this plan. Right
click is the one square the player can see is empty, which is what makes plan 3's first part legible.

## Force — the material `F` halves

Force is per body, and it is **the** number the game compares. It lands here rather than in plan 3 because
splitting is meaningless without it.

```gdscript
# in Swarm, alongside pos/vel/carried — same packed-array discipline, same reason
var force := PackedInt32Array()   ## per body, index 0 is the host
```

⚠ **`force[i]` is STORED, never recomputed** — see
[force is stored, not derived](../../decisions/force-is-stored-not-derived.md). **Derived, `F` costs
nothing**: halve the host and the next frame recomputes it back to full, so the swarm doubles for free, the
total is not conserved, and the whole reason plan 2 exists evaporates. Silently.

So, precisely:

- **`Rules.FORCE_START` is 10** and is the value `Swarm::setup()` writes into `force[0]`, once. Ten, not one:
  **splitting is the tutorial**, and at force 1 the first `F` was a level-up away —
  see [the host starts at force 10](../../decisions/force-starts-at-ten.md)
- **Levelling ADDS to the stored value.** `World::_grow()` already fires once per level; at that moment it
  does `swarm.force[0] += Rules.FORCE_PER_LEVEL`. **This is the whole payout of a level** — the cards no
  longer hand out clones (see *Fallout 2*). Nothing else ever writes the host's force except splitting,
  absorbing, and (plan 3) wearing a part
- ⚠ **`Rules.START_CLONES` is deleted outright**, not set to 0 (user, 2026-08-14 — 
  [the run opens alone](../../decisions/the-run-opens-alone.md)). **The run opens with the host alone**, so
  no body exists that did not come from a split. Deleting the constant is what makes the net honest: with it
  still present, `t.eq(count, 1 + Rules.START_CLONES)` passes at every value, and *"the swarm started at
  zero"* is a bug that already walked through 102 green checks once
- **A clone made by splitting takes the smaller half**, and after that earns force only by killing (plan 4)
- **`Swarm.total_force()`** sums every row. **The `boss` is still not gated on a comparison** (see
  [the boss is not gated](../../decisions/the-boss-is-not-gated.md)) — but ⚠ **this plan's own build gave it a
  production caller after all**, and the sentence that said it had none is corrected here rather than left to
  be inherited. `World::is_hunter_of()` compared `swarm.count` against `SWARM_PER_THREAT`, which made `F` a
  free power-up: four holds turn force 10 into ten force-1 bodies, the total is unchanged, and every threat-1
  critter flips to prey for nothing. **It reads `total_force()` against `Rules.FORCE_PER_THREAT` (20.0)
  instead**, which is what makes *"splitting buys nothing by itself"* below true rather than merely stated.
  ⚠ **`FORCE_PER_THREAT`'s value is a guess with a real balance consequence** — clearing the stage now wants
  total force ~100 rather than 25 bodies, and nobody has played it

⚠ **`force` is an `int` and the split is exact.** Halving conserves the total, so splitting buys nothing by
itself — what it costs is concentration. **There is no refund rule and none is needed.**

### The array has to be maintained in three places, and the fourth is the one that bites

`force` is the ninth packed array on `Swarm`, and **three existing functions hand-maintain the row set**:

| Function | What to add | What happens if it is missed |
|---|---|---|
| `Swarm::setup()` (`resize` block) | `force.resize(Rules.POOL)`, then `force[0] = Rules.FORCE_START` | index error on the first split |
| `Swarm::add_clone()` | set `force[i]` from the new argument | new clones silently carry 0 |
| `Swarm::remove_at()` | copy `force[last] → force[i]` in the swap | **a dead clone's force lands on a survivor.** No error, no visual |

⚠ **The net for the swap must kill a clone that is NOT the last row.** Killing one clone hits `i == last`,
the swap branch never runs, and a missing `force` line stays green — which is exactly how this class of bug
survives.

⚠ **`add_clone()` gets defaults, or thirteen nets stop parsing.** Its real call count across the repo is
**36 sites in 11 files** (`swarm.gd` `world.gd` and nine nets) — counted, not remembered. The signature is:

```gdscript
func add_clone(parent: int = 0, force_value: int = 0) -> int
```

**No production caller uses either default after this plan** — `world.gd`'s `START_CLONES` loop is deleted
and `take_card`'s two `add_clone()` calls are deleted with the split cards, so the only production caller is
`split_release()`, which passes both. The defaults exist for the nets that measure movement and do not care
about force, and they keep those nets parsing without a mechanical sweep.

### `F` — split

**Held, not tapped** (user, 2026-08-14). Holding runs a wind-up so the split reads as an act, not a
keystroke.

```gdscript
func split_hold(dt: float) -> void   ## called every frame F is down; charges split_charge
func split_release() -> void         ## called when F comes up; cancels an incomplete charge
```

- Charge reaches `Rules.SPLIT_HOLD_TIME` → **every body with `force >= 2` halves**, producing a new clone
- **The parent keeps the larger half.** `5 → 3 + 2`. The host fights in front and keeps the odd point
- ⚠ **`carried` is NOT divided. The parent keeps all of it.** Cargo is a thing the body is holding, not a
  substance it is made of, and splitting it would hand half a harvest to a body that never walked it home.
  The nets in this plan assert `carried` on both rows after a split, because *force-only* checks pass with
  the cargo written either way
- **A body with `force == 1` does not split and is not an error**
- ⚠ **The loop snapshots `count` before it runs.** `for i in range(count)` read live grows as children are
  appended, and one press walks the whole swarm down to force 1 — a `5 → 3+2` whose child `2` is then split
  again inside the same press. Snapshot, then iterate `0 .. snapshot - 1`
- **One split per hold.** Charge resets to zero on firing **and** on release, so holding `F` down does not
  ratchet. Assert this: hold `F` for four times `SPLIT_HOLD_TIME` without releasing and the count goes up
  **once**
- **The hold has to be visible.** 0.45 seconds with no feedback reads as a broken key. `Look.SPLIT_CHARGE_*`
  draws the charge as a ring arc on the host; the value is `split_charge / Rules.SPLIT_HOLD_TIME`
- The new clone spawns at `Rules.CLONE_SPAWN_RING` **from its parent**, inheriting **its parent's** `state`.
  ⚠ `add_clone()` today spawns from **`pos[0]`** with **`state[0]`** — reuse it unchanged and every child of
  every clone piles onto the host. **Every net in this plan still passes.** That is what `parent` is for
- **The pool is `Rules.POOL` (128) and `CLONE_CAP` (40).** A split that would exceed the cap **splits bodies
  in index order, lowest first, until the cap is reached, and the rest keep their force whole** — it does not
  refuse wholesale and it does not split anyone partially. **Assert the order, not only the total**: a total
  is conserved under every order, so the check pins *which* rows kept their force

### `V` — absorb

One press, no hold.

```gdscript
func absorb() -> int   ## returns how many clones were taken; radius comes from Rules
```

- Every clone within `Rules.ABSORB_RADIUS_BODIES * Rules.BODY_RADIUS` of the host **dies**; its `force` and
  its `carried` go to the host. Backwards walk, because `remove_at()` swaps the last row down
- ⚠ **Cargo arriving this way is banked, not eaten.** `banked += carried[i]`, never `swarm.eat()` — it was
  counted into `eaten` the moment it was picked up, and `Swarm::eat()`'s header already says so
- ⚠ **`Rules.BODY_RADIUS` (14.0) is new and it is a `sim` constant, not a `look` one.** The body's radius
  decides who gets absorbed and (plan 4) what reaches what, so it changes what happens — `look.gd` may not
  own it, and `src/sim/` may not read `look.gd`. **`Look.HOST_RADIUS` becomes `Rules.BODY_RADIUS` and
  `Look.CLONE_RADIUS` becomes `Rules.CLONE_BODY_RADIUS` (8.0)**, both of which move to `rules.gd` for the
  same reason. Without the second one, plan 4's "reaching a clone kills it" kills clones **6px away from the
  body the player can see**
- **Two constant-against-constant checks, three lines, and they live forever**:
  `EAT_RADIUS_HOST > BODY_RADIUS` and `EAT_RADIUS_CLONE > CLONE_BODY_RADIUS`. `net_eat_carry` already holds
  this pair against `Look`; it re-points at `Rules` and stays

### `_absorb()` is split in two, NOT deleted

⚠ **This is the joint the review predicted and it is the most dangerous edit in the plan.**
`Swarm::_absorb()` today does **two unrelated jobs in one function**:

| Branch | What it is | This plan |
|---|---|---|
| `elif carried[i] > 0.0` | ordinary contact-handover: touching the host empties a clone and leaves it alive | **delete.** Cargo comes home only because the player pressed `V`, or because the run cleared |
| `if clear_pull:` | the great absorption's arrival-removal — the beat's whole mechanism | **keep, renamed `_clear_arrivals()`** |

**Delete the whole function and the clear beat stops ending**: `Run::step()` waits on `swarm.count <= 1`,
which nothing else ever makes true, so every cleared run hangs for `CLEAR_ABSORB_TIME` and then limps out
through `_finish_clear()`'s fallback loop. The FieldView absorb-pop stops firing per body at the same time.
**Rename, strip the `elif`, keep the call site in `step()`** — and `Rules.ABSORB_RADIUS` (20.0) stays as
*that* branch's arrival distance.

⚠ **`Rules.ABSORB_RADIUS` has a SECOND caller that has nothing to do with absorbing**: `add_clone()` uses it
as the spawn ring. **Give the spawn ring its own name (`CLONE_SPAWN_RING`, 20.0) in the same edit**, or
retuning the arrival distance silently moves where every new body appears.

### `1` — rally to the host, not to a point

**Changed by the user on 2026-08-14** —
[rally is to the host](../../decisions/rally-is-to-the-host.md). Today `command_rally(point)` sends clones
to the mouse and its comment in `swarm.gd` argues *against* rallying at the host. **That argument lost.**

```gdscript
func command_rally() -> void    ## no argument. FOLLOW steers at pos[0], live, every frame
```

- **The `rally` field is deleted**, not repointed. Left in place as "a copy of the host's position updated
  every frame", it is a second source of truth for something the swarm can already read
- `_move_clone()`'s FOLLOW branch reads `pos[0]` directly. `rally_radius()` is unchanged
- ⇒ **Rewrite that comment in `swarm.gd` rather than leaving it to contradict the code.** `CLAUDE.md`: a
  refutation that lands in a different doc than the claim does not propagate

⚠ **`command_rally` has 9 call sites in 5 files, not three** (grepped): `main.gd:_read_input`,
`net_eat_carry` ×2, `net_grid` ×3, `net_run` ×2, `net_swarm_follow` ×1. Dropping the argument breaks every
one of them at parse time — which is the good case. **What each one has to become is spelled out in
*Fallout 6*, because three of them are load-bearing checks that a mechanical sweep would quietly gut.**

### `3` — strike the mouse point

```gdscript
func command_strike(point: Vector2) -> void
```

A third clone state, `STRIKE`. Clones walk to `strike_point` at `CLONE_SPEED_FOLLOW` and, on arrival within
`rally_radius()`, **stay** rather than returning. They do not seek food in this state.

- `strike_point: Vector2` is a real field on `Swarm` and it is what `field_view` draws (see *Fallout 5*)
- **Combat itself is plan 4.** Here `STRIKE` is movement plus a flag; the net asserts they arrive and stay

### The three slots

Actives need somewhere to live before parts exist. **They live on `Swarm` for this plan and move to `Body`
in plan 3** — named here so plan 3 is a move, not a discovery.

```gdscript
# src/sim/actives.gd — new file
class_name Actives
enum { NONE = 0, BITE = 1, DASH = 2 }
const MOVEMENT := [DASH]          ## what `space` will accept
const TITLE := { NONE: "빈 칸", BITE: "물기", DASH: "짧은 숨" }
```

```gdscript
# on Swarm
var bound := PackedInt32Array()      ## size 3, one per slot. setup(): [BITE, NONE, DASH]
var bound_cd := PackedFloat32Array() ## size 3, ticked down in step()
func fire(slot: int, aim: Vector2) -> bool   ## false when empty, on cooldown, or refused
func bind(slot: int, active: int) -> bool    ## false when `space` is handed a non-movement active
```

- **`fire()` is the only entry point**, and the shell calls it for all three keys. A key that does its own
  thing is a fourth code path the panel's gate has to know about
- **`BITE`** is a front cone toward `aim`: `Rules.BITE_RANGE` (70.0) and `Rules.BITE_ARC` (70°, stored as
  radians). It consumes **one** food inside the cone — the nearest — and pays `swarm.eat(0, 1.0)`.
  ⚠ **It is a real function, not an animation.** A left click that only draws is the empty hand this plan
  exists to prevent, and plan 4 replaces *what it hits*, not the key
- **`DASH`** calls the existing `try_dash()` and keeps its own cooldown; `bound_cd[2]` stays 0 so the two
  cooldowns cannot disagree
- `bound_cd[slot] = Rules.BITE_COOLDOWN` on a successful bite. **Assert the refusal**: a second click inside
  the cooldown returns false and no food dies
- **`Look.BITE_SHOW_TIME` (0.12s)**: `field_view` draws the cone for that long after a bite. The sim owns
  `bite_show`, ticked in `step()`, because the view may not hold state the sim does not know about

## The `Tab` panel

**One screen, everything about the body** (user, 2026-08-14): the eleven slots and what is in them, the
host's numbers, and the binding of actives to the three keys. The user flagged that this may be too much for
one key and that `C` might split it later — **build it as one panel now**, and keep the layout in two halves
so splitting it is a re-parent, not a rewrite.

**File: `src/view/body_panel.gd`**, a `Control` built by `main.gd::_ready()` on the same `CanvasLayer` as
`CardPanel`, `visible = false`.

- **The game pauses while it is open** — `Run.paused`, which plan 1 already built as **the one pause flag in
  the game**. `Run::step()` returns early on it. ⚠ **Do not add a second early return to `World::step()`**;
  its `pending_levels` guard is a different sentence and two flags in two files is how one gets missed
- Left half: the body, eleven slots, each showing its part name or empty
- Right half: three active rows — left click · right click · `space` — each showing `Actives.TITLE[bound[i]]`
- **Binding is a click on a slot's active and then a click on a key row.** No dragging. Dragging is a
  different input model and it is not worth it for three rows
- **`space` refuses a non-movement active** and says so in one line of Korean rather than silently ignoring
  the click
- ⚠ **Lay it out from `size` only after `set_anchors_and_offsets_preset(PRESET_FULL_RECT)`**, exactly as
  `hud.gd` and `card_panel.gd` do. `set_anchors_preset` alone leaves `size == (0, 0)` and the whole panel
  piles into the top-left corner with every check about it green

**In this plan the panel opens, pauses, draws eleven empty slots and three rows, binds `DASH` between them,
and closes.** Plan 3 fills the slots. Ship it with the binding working rather than fully empty — the pause,
the toggle and the gate are the parts that break.

### The four interactions that were not decided

| Case | The rule |
|---|---|
| `Tab` while the level-up cards are up | **`Tab` is ignored.** One panel at a time; the cards are not dismissable and a stack of two pauses has no owner |
| `Esc` while the body panel is open (PLAY) | **Closes the body panel**, and nothing else. `Esc` in PLAY still does not pause, quit, or open a menu |
| Left and right click on the same frame | **Both fire.** The slots are independent and share no cooldown |
| `F` charging when a panel opens | **The charge is dropped**, not paused. Resuming a charge across a menu is a decision the player did not make |

## Fallout — nine files outside this plan's own, and every count below was grepped

### 1. `project.godot` — the input map, and the nets bark without it

Registered today: `mv_left` `mv_right` `mv_up` `mv_down` `dash` `cmd_rally` `cmd_scatter` `toggle_fullscreen`.

**Add**: `fire_0` (left mouse button), `fire_1` (right mouse button), `cmd_strike` (`3`), `split` (`F`),
`absorb` (`V`), `body_panel` (`Tab`). **Rename** `dash` → `fire_2` (`space`). `cmd_rally` (`1`) and
`cmd_scatter` (`2`) stay.

⚠ **An unregistered action does not fail quietly.** Measured on 4.7.1 headless:
`ERROR: The InputMap action "cmd_strike" doesn't exist.` — on **stderr, every frame**. `net_cards` and
`net_shell` tree `main.gd` and pump frames, so `_read_input()` runs, so **the wrapper goes red for a reason
that is not the code.** Register them in the same commit. The editor does not re-read `project.godot`;
restart it.

### 2. `cards.gd` — the two split cards are deleted

The level pays force now, so a card that hands out clones is the rule
[the swarm grows by a key](../../decisions/swarm-grows-by-a-key-not-a-level.md) explicitly killed, and it
would create force from nothing (or force-0 ghost bodies, which is worse).

- Delete `SPLIT_1` and `SPLIT_3` from the enum, `TITLE`, `DESC`, and `SPLITS`
- `roll()` becomes **three distinct cards drawn from `REST`** (six entries, so three distinct is always
  possible). The "one of the three always grows the swarm" guarantee and its header paragraph go with it
- `world.gd::take_card()` loses both `Cards.SPLIT_*` branches — **the two `add_clone()` calls in production
  code disappear here**
- `net_cards` asserts the split cards in three places (`:31` `:47` `:49`). Rewrite: **a level raises
  `force[0]` by the literal 10** and the offer is three distinct non-split cards

### 3. `rules.gd` — the constants and two rotted comments

Delete `START_CLONES` and its four-line comment (its measurement is answered by `FORCE_START` 10 now, and the
comment's reasoning — *"with no clones the first minute is one square eating alone"* — is exactly what force
10 fixes). Rename `SPLIT_PER_BANKED` → `LEVEL_COST_BASE`. Add everything in *Numbers*.

⚠ **The speed-order comment at the top of the file names `PREDATOR_SPEED`, which no longer exists** (it is
`CRITTER_SPEED`), and the same ordering is written a second time above the speed block. Plan 4 rewrites the
ordering; **this plan fixes the dead name in both places** rather than leaving a third copy to inherit.

### 4. `world.gd` — the level's payout, and a rising cost

- `setup()`: delete the `START_CLONES` loop; `peak_swarm = 0`
- `_grow()`: `swarm.force[0] += Rules.FORCE_PER_LEVEL` on each level granted
- **The level cost rises**, per [hunting and the boss](../../design/hunting-and-the-boss-ko.md): the cost of
  level *n* is `LEVEL_COST_BASE * pow(LEVEL_COST_GROWTH, n)`, accumulated in the existing `_split_paid`
  (rename it `_level_paid`). A flat cost at the ×10 force scale hands out a level every few seconds by the
  midgame
- ⚠ **The level still comes from `banked`, not from `eaten`** — see
  [the level counts what came home](../../decisions/level-counts-what-came-home.md). This is the rule the
  prototype's confirmed fun rests on: a clone that dies far from home costs you the level it was carrying

### 5. `field_view.gd` — the rally ring becomes the strike marker

`field_view.gd` skips the rally ring when `rally == pos[0]`, which after this plan is **always** — the
feature would vanish with every net green. **Draw `strike_point` instead**, and only while at least one clone
is in `STRIKE`. `Look.RALLY_COLOR` / `RALLY_RADIUS` are renamed `STRIKE_COLOR` / `STRIKE_RADIUS`.

Also new here: the `F` charge arc on the host, and the `BITE` cone. Both go through the existing
`_paint_ring` / a new `_paint_cone` leaf hook — **not through a bare `c.draw_*` call.** `net_draw_leaf` does
not yet cover this file, which is exactly why the discipline has to be hand-held here.

### 6. The nets that break, and what each one has to become

**`add_clone`'s defaults keep all 36 sites parsing. `command_rally` does not — all 9 have to be rewritten,
and three of them are load-bearing.**

| Site | Rewrite |
|---|---|
| `main.gd::_read_input` | `command_rally()` |
| `net_eat_carry` ×2 | The clone is held still by parking the **host** within `rally_radius()` of it. Put the host at `clone + (-20, 0)`; the food at `clone + (17, 0)` (outside `EAT_RADIUS_CLONE` 16, and 37px from the host so the host cannot eat it either) and at `clone + (15, 0)` for the inside case. ⚠ **The comment there is right and must survive**: without this the clone walks the last pixel and turns a failing distance into a passing one |
| `net_grid` ×2 (`:25` `:48`) | Two coincident clones at `(100, 100)`: **move the host there** (`sw.pos[0] = Vector2(100, 100)`) and call `command_rally()`. Separation skips `j <= 0`, so the host does not perturb the pair being measured |
| `net_grid` ×1 (`:64`) | The 300-body rendezvous: host to `(640, 360)`, then `command_rally()` |
| `net_run` (`:141`) | This is check 8, *"`_absorb()` never raises eaten"*. It becomes **`V` never raises `eaten`** — place a loaded clone inside the absorb radius, call `absorb()`, assert `banked` rose and `eaten` did not |
| `net_run` (`:189`) | ⚠ **The trick this check rests on dies.** It rallies 1200px off-host so that a deleted `clear_pull` branch shows up as the mean distance *rising*. With rally at the host both branches steer the same way. **Replace the trick with the pull's own speed**: assert the mean per-frame closing is above a pinned literal (`CLEAR_ABSORB_PULL * DT` is 15px; FOLLOW manages 3.58px), so deleting the branch is still red — and it now measures the process rather than the endpoint |
| `net_swarm_follow` (`:26`) | Host to `(600, 400)` (`sw.pos[0] = ...`), then `command_rally()`. Its `t.eq(sw.rally, ...)` check is replaced by *"the clones close on the host across frames"* — the field it read no longer exists |

Also: **`net_run:23`'s `t.eq(count, 7)` becomes the literal `1`** (and its comment, which explains why the
literal is there, stays); `net_hunt:148`'s header sentence about a run opening with `START_CLONES` is wrong
the moment the constant is gone.

### 7. `hud.gd` — the key legend is false the moment this plan lands

`hud.gd` prints `"WASD 이동 · Space 대시 · 1 모이기(커서) · 2 흩어지기"` for the first 12 seconds — **the
only instruction the player ever gets**, and after this plan every clause of it is a lie. It becomes:

`"WASD 이동 · F 나누기 · V 모으기 · 1 집결 · 2 흩어지기 · 3 보내기 · Tab 몸"`

⚠ **Assert it through the `_paint_text` hook**, not by grepping the file: `net_hud` already captures every
readout that way, and a legend asserted by grep is a check that measures text rather than what is drawn.

### 8. `main.gd` — the input gate

`_read_input()` polls `Input.is_action_just_pressed`. **A polled action is not consumed by a `Control`** — no
`mouse_filter`, no `set_input_as_handled()` stops it. So clicking a level-up card, a binding row, or the
title's 시작하기 **also fires left click.**

⇒ **`_read_input()` runs only when no panel is open.** One helper on the shell:

```gdscript
func _panel_open() -> bool:
    return cards.visible or body.visible
```

`main.gd`'s `pending_levels == 0` condition is replaced by it — that condition was already the same
idea, written narrowly. `Tab` itself is read in `_unhandled_key_input`, which is where `Esc` already lives.

### 9. `run.gd` — one comment

Its header says *"plan 2's `Tab` is its first setter"* about `paused`. It stops being a promise and becomes a
fact; the sentence is rewritten, not deleted, because **why the flag has one owner is the part worth
keeping.**

## Numbers

| Constant | Value | Why this one |
|---|---|---|
| `FORCE_START` | **`10`** | splitting is the tutorial — [why](../../decisions/force-starts-at-ten.md) |
| `FORCE_PER_LEVEL` | **`10`** | the ×10 scale's version of the old +1 on a base of 1. Level 3 is force 40, which is the clone cap |
| `SPLIT_HOLD_TIME` | `0.45` s | long enough to be an act, short enough to spam in a fight |
| `ABSORB_RADIUS_BODIES` | `4.0` | 56px — wide enough that a rallied swarm goes in one press, tight enough to miss stragglers |
| `BODY_RADIUS` | `14.0` | **moved from `look.gd`.** It decides who is absorbed, so it is a sim constant |
| `CLONE_BODY_RADIUS` | `8.0` | **moved from `look.gd`**, same reason. Plan 4's reach checks need it |
| `CLONE_SPAWN_RING` | `20.0` | **new.** `ABSORB_RADIUS`'s old second job, given its own name |
| `BITE_RANGE` | `70.0` | five body-widths in front; the angle is the skill, not the distance |
| `BITE_ARC` | `deg_to_rad(70.0)` | narrow enough that aiming is a decision — [why](../../decisions/hit-shape-comes-from-the-part.md) |
| `BITE_COOLDOWN` | `0.5` s | two bites a second. Faster and the click is a stream, not a hit |
| `LEVEL_COST_BASE` | `10.0` | unchanged value, renamed from `SPLIT_PER_BANKED` |
| `LEVEL_COST_GROWTH` | `1.35` | level 5 costs ~45. The shape is what is settled; the number is expected to move in play |
| `Look.SPLIT_CHARGE_WIDTH` | `3.0` | the charge arc on the host |
| `Look.BITE_SHOW_TIME` | `0.12` s | long enough to read at 60fps, short enough not to lie about the cooldown |

**Every one of these is a guess and is expected to move on the first session** — except `FORCE_START`,
which is a decision.

## Nets

Two new files: **`tests/nets/net_force.gd`** (force, splitting, absorbing, the swap) and
**`tests/nets/net_hands.gd`** (slots, firing, the panel, the gate). Two rather than one because the round is
run in parallel per file, and because a single file holding both would be the slowest net in the round.

Updated: **`net_cards`** (split cards), **`net_eat_carry`**, **`net_grid`**, **`net_run`**,
**`net_swarm_follow`**, **`net_hud`** (the legend), **`net_hunt`** (a comment).

**Every check below names the mutation that must make it red.** *Invert the instrument, not only the
subject*: for the two marked ⚠ the check itself is the thing that has to be attacked first.

### `net_force`

1. **At `t = 0` there is exactly one body and `total_force()` is the literal 10.** *Mutation: `START_CLONES`
   back at 6; `FORCE_START` at 1*
2. Force 10 host, one full hold → two bodies, forces `5` and `5`, total `10`. *Mutation: parent keeps the
   whole value*
3. Force 5 host: one hold → `3` and `2`, **parent keeps the larger**. *Mutation: swap the halves*
4. **`carried` does not divide** — host carrying 6.0 splits, parent still holds 6.0 and the child 0.0.
   *Mutation: halve `carried` alongside `force`*
5. Force 5 host **and** a force-3 clone: one hold → four bodies, forces `3,2,2,1`, total `8`. *The split is
   simultaneous across every body, not the host alone.* *Mutation: loop only over index 0*
6. **The children are not re-split inside the same press**: force 10 host, one hold, assert **exactly 2**
   bodies. *Mutation: iterate live `count` instead of the snapshot — this is the bug that walks a swarm to
   force 1 in one keypress*
7. Force 1 host: holding past `SPLIT_HOLD_TIME` produces **no** clone and is not an error
8. Releasing `F` at 90% of the hold produces nothing, and the charge is back at zero
9. Holding `F` for `4 ×` the hold time **without releasing** adds **one** body. *Mutation: reset the charge
   only on release*
10. ⚠ **The cap splits in index order.** Set up `CLONE_CAP - 3` clones with distinguishable forces, one hold,
    and assert **which** rows halved: the lowest indices did and the highest kept their force whole. Assert
    the total too, but the order is the check — *a total is conserved under every order.* **Attack the check
    first**: give every body the same force and the order assertion becomes unfalsifiable, which is how this
    check would have shipped inert
11. A clone splits: the child sits within `CLONE_SPAWN_RING` of **its parent** and carries **its parent's**
    `state` — **put the parent 900px from the host**, so reusing `pos[0]` fails
12. `V`: clones inside and outside the radius; the inside ones are gone, the outside ones untouched, the
    host's force is the **exact** sum, and `carried` came with it. *Mutation: absorb everything regardless of
    distance; drop `carried`*
13. `V` with nothing in range returns 0 and changes nothing
14. **`V` never raises `eaten`** — it moves cargo, it does not find it. *Mutation: route it through `eat()`*
15. **A clone killed by contact still loses its cargo and its force** — `World::_contact()` kills a loaded
    clone and neither `banked` nor `force[0]` moves. *This is the one rule the whole build rests on*
16. **Kill a clone that is not the last row** (three clones, `remove_at(1)`) and assert the survivor at index
    1 has **its own** force and **its own** cargo. *Mutation: drop the `force` line from the swap —
    removing the only clone never runs that branch*
17. **Constants against constants**: `EAT_RADIUS_HOST > BODY_RADIUS`, `EAT_RADIUS_CLONE > CLONE_BODY_RADIUS`,
    `Look.HOST_RADIUS == Rules.BODY_RADIUS`
18. **The clear beat still ends.** Drive a real `Run` to `stage_cleared`, step it, and assert the phase
    reaches ENDING with `swarm.count == 1`. *Mutation: delete `_clear_arrivals()` along with the handover —
    the beat then never completes and this is the only check that sees it*

### `net_hands`

19. `1` steers the swarm at the host **across frames** — pin two different host positions and assert the
    mean distance falls after each. *Mutation: latch the host's position once at the press*
20. `3` sends clones to a **literal** coordinate and they **stay** there for 2 seconds of stepping. *A check
    whose bounds come from the thing it checks proves nothing* — pin the coordinate, not `strike_point`
21. `3` clones do **not** chase food: put food 30px off the strike point and assert nobody left
22. `fire(0, aim)` with food inside the cone kills exactly one; **with the same food behind the host it kills
    none**. *Mutation: ignore the arc and take the nearest food in range*
23. A second `fire(0)` inside `BITE_COOLDOWN` returns false and no food dies; after the cooldown it works
24. `fire(2)` dashes; `bind(2, Actives.BITE)` is **refused** and slot 2 still holds `DASH`
25. `bind(1, Actives.BITE)` succeeds and `fire(1)` then bites — **binding reaches behaviour**, it does not
    merely move a field
26. **`Tab` sets `Run.paused` and `world.elapsed` does not advance** while it is set — and **advances again
    after it is cleared**. *A pause asserted at one end passes for a panel that never closes*
27. ⚠ **Driven, not grepped**: the panel's `_paint_panel(...)` hook is called with rectangles **inside the
    viewport**, and `size` is not `Vector2.ZERO`. Assert the rectangles against the literal 1280×720, not
    against the panel's own size. **Attack the check first**: a hook that receives a bare `Rect2()` must make
    it red
28. With the card panel open, pressing **every one of the eight actions** changes nothing — asserted by
    driving `main.gd` and pumping frames, **not** by reading the gate flag. *Mutation: gate on
    `pending_levels` only, then open the body panel and fire*
29. `Tab` while the cards are up does nothing, and the cards are still up
30. `Esc` in PLAY closes the body panel and does **not** end the run
31. **The `F` charge is dropped when a panel opens** — charge to 90%, open the panel, close it, and one more
    frame of holding does not split
32. The HUD legend names `F`, `V` and `3`, captured through `_paint_text`. *Mutation: leave the old string*

## Acceptance

**The user plays and reports whether splitting on purpose feels like a decision** — specifically whether the
hold reads as an act, whether losing a fat clone out in the field hurts, and whether force 10 makes the first
thirty seconds busy rather than empty.

**Nothing in this plan is accepted until that is heard.** `3.done` means built.

### Heard so far — the hands, yes; the picture, no (user, 2026-08-14)

The user played the build and said, in their own words: **"디테일은 많이 떨어지지만 키들은 괜찮게 들어가있음"**
— *the detail falls well short, but the keys are in there fine.*

- ✅ **The key map is accepted.** Every key in the table above reads as landing where it should. Planning
  principle 1 — the hands must never be idle — **holds for this build.** That is what this plan set out to
  close and it is closed
- ❌ **Presentation is not.** "Detail falls well short" is about what reaches the screen, and it is the half
  this plan deliberately built thin: the charge arc, the bite cone, the strike marker and the body panel are
  each the smallest thing that could carry the mechanic
- ⏳ **Still unheard, and the three that actually decide this plan**: whether the hold reads as an *act*,
  whether losing a fat clone out in the field *hurts*, and whether force 10 makes the opening busy.
  ⚠ **Do not read "the keys are fine" as any of them.** A key landing is not a decision feeling like one —
  and this repo's own history is thirty-four features shipped against five open acceptance checks

⚠ **`FORCE_PER_THREAT` (20.0) was still unplayed when this was heard**, so nothing above is evidence about
the stage's difficulty either way.
