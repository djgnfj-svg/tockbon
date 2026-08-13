# Plan 2 — hands and commands

**Status**: `1.ready`. Part of [the grassland index](grassland-whole-loop.md). Build after
[the run shell](run-shell.md).
⚠ **Not yet corrected for [the 2026-08-14 adversarial review](../../adversarial-review-2026-08-14-ko.md).**
Its own findings: **`FORCE_START` is 10, not 0/1** ([why](../../decisions/force-starts-at-ten.md)) ·
`add_clone()` needs a default parent or thirteen nets stop parsing · `command_rally` has seven call sites,
not three, and the plan never says whether the argument goes · the pause flag has two owners in one section ·
`force = FORCE_START + level` survives in the same file that kills it · splitting never says what happens
to `carried`.

**What it closes**: **the hands.** Every key the game will ever have, wired, with force underneath so `F`
has something to halve. After this plan the swarm grows and shrinks because the player pressed something.

**Planning principle 1: the hands must never be idle.** This is the plan that decides whether that is true.

---

## The full key map, after this plan

| Key | What it does | New? |
|---|---|---|
| `WASD` | move the host | exists |
| **left click** | fire active slot 0 | **new** |
| **right click** | fire active slot 1 | **new** |
| **`space`** | fire active slot 2 — **movement actives only** | replaces the hardcoded dash |
| **`F` (held)** | split: the host and every clone halve at once | **new** |
| **`V`** | absorb every clone within a radius | **new** |
| `1` | **rally to the host** — clones come to me | **changed** |
| `2` | scatter | exists |
| **`3`** | attack the mouse point — the swarm goes there and fights | **new** |
| **`Tab`** | the body panel: slots, parts, and active binding | **new** |
| `Esc` | (title/ending only) | plan 1 |

**The three active slots are the whole of the player's offense**, and **`space` accepts only parts flagged
`movement`** (user, 2026-08-14). Slot 0 starts holding a default active so the run is never keyless.

## Force — the material `F` halves

Force is per body, and it is **the** number the game compares. It lands here rather than in plan 3 because
splitting is meaningless without it.

```gdscript
# in Swarm, alongside pos/vel/carried — same packed-array discipline, same reason
var force := PackedInt32Array()   ## per body, index 0 is the host
```

⚠ **`force[i]` is STORED, never recomputed.** This is the single most load-bearing sentence in the plan and
the first draft got it wrong — it said the host's force "is `base + parts`", which reads as a derived value.
**Derived, `F` costs nothing**: halve the host and the next frame recomputes it back to full, so the swarm
doubles for free, the total is not conserved, and the whole reason plan 2 exists evaporates. Silently.

So, precisely:

- **Levelling ADDS to the stored value.** `World::_grow()` already fires once per level; at that moment it
  does `swarm.force[0] += Rules.FORCE_PER_LEVEL`. Nothing else ever writes the host's force except splitting,
  absorbing, and (plan 3) wearing a part
- **`Rules.FORCE_START` is the value written into `force[0]` by `Swarm::setup()`**, once
- ⚠ **`Rules.START_CLONES` goes to 0** (user, 2026-08-14). **The run opens with the host alone**, so no body
  exists that did not come from a split and the "what force do the free clones have" hole closes by
  deletion. The six were prototype scaffolding, added when the level-up was the only thing that grew the
  swarm — **`F` is that now, and the first level-up is the onboarding**
- **A clone made by splitting takes the smaller half**, and after that earns force only by killing (plan 4)
- **`Swarm.total_force()`** sums every row. ⚠ **Nothing in the August build reads it** — the boss is not
  gated on a comparison (see `grassland-field`, *Fighting*). **Ship it only when something calls it**; an
  unused public function reads as a contract that exists

⚠ **`force` is an `int` and the split is exact.** Halving conserves the total, so splitting buys nothing by
itself — what it costs is concentration. **There is no refund rule and none is needed.**

### The array has to be maintained in four places, not one

`force` is the fifth packed array on `Swarm`, and **three existing functions hand-maintain the row set**:

| Function | What to add | What happens if it is missed |
|---|---|---|
| `Swarm::setup()` (`resize` block) | `force.resize(Rules.POOL)` | index error on the first split |
| `Swarm::add_clone()` | set `force[i]` explicitly | new clones silently carry 0 |
| `Swarm::remove_at()` | copy `force[last] → force[i]` in the swap | **a dead clone's force lands on a survivor.** No error, no visual |

⚠ **The net for the swap must kill a clone that is NOT the last row.** Killing one clone hits `i == last`,
the swap branch never runs, and a missing `force` line stays green — which is exactly how this class of bug
survives.

### `F` — split

**Held, not tapped** (user, 2026-08-14). Holding runs a wind-up so the split reads as an act, not a
keystroke.

```gdscript
func split_hold(dt: float) -> void   ## called every frame F is down; charges split_charge
func split_release() -> void         ## called when F comes up; cancels an incomplete charge
```

- Charge reaches `Rules.SPLIT_HOLD_TIME` → **every body with `force >= 2` halves**, producing a new clone
- **The parent keeps the larger half.** `5 → 3 + 2`. The host fights in front and keeps the odd point
- **A body with `force == 1` does not split and is not an error.** The host starts at `FORCE_START` = 1, so
  **nothing splits until the first level-up — that is the onboarding, and it is the rule, not a tutorial
  line.** ⚠ `World.level` starts at **0**, so the formula is `force = FORCE_START + level` and level 1 is
  force 2. Do not write `1 + level` anywhere else; the level-up adds to the stored value and that is the
  only place the arithmetic lives
- **One split per hold.** Charge resets to zero on release, **not on firing** — holding `F` down does not
  ratchet the swarm to force 1 in two seconds. Assert this: hold `F` for four times `SPLIT_HOLD_TIME` without
  releasing and the count goes up **once**
- **The hold has to be visible.** 0.45 seconds with no feedback reads as a broken key. `Look.SPLIT_CHARGE_*`
  draws the charge on the body; the value is `split_charge / Rules.SPLIT_HOLD_TIME`
- The new clone spawns at `Rules.SEPARATION_MIN` **from its parent**, inheriting **its parent's** `state`.
  ⚠ `add_clone()` today spawns at `Rules.ABSORB_RADIUS` from **`pos[0]`** with **`state[0]`** — reuse it
  unchanged and every child of every clone piles onto the host. **Every net in this plan still passes.**
  Give `add_clone()` a parent index
- **The pool is `Rules.POOL` (128) and `CLONE_CAP` (40).** A split that would exceed the cap **splits bodies
  in index order, lowest first, until the cap is reached, and the rest keep their force whole** — it does not
  refuse wholesale and it does not split anyone partially. Assert the order, not only the total

### `V` — absorb

One press, no hold.

```gdscript
func absorb(radius: float) -> int   ## returns how many clones were taken
```

- Every clone within `radius` of the host **dies**; its `force` and its `carried` go to the host
- `radius = Rules.ABSORB_RADIUS_BODIES * Rules.BODY_RADIUS` — **4× the body** (design doc, *First numbers*).
  ⚠ **`Rules.BODY_RADIUS` is new and it is a `sim` constant, not a `look` one.** The body's radius decides
  who gets absorbed and (plan 4) what reaches what, so it changes what happens — `look.gd` may not own it,
  and `src/sim/` may not read `look.gd`. `Look.HOST_RADIUS` becomes a read of this value
- **This is not the contact-absorb that exists today.** `Swarm::_absorb()` currently empties a touching
  clone's cargo and leaves it alive. **Delete it.** Cargo now comes home only because the player pressed `V`
  or because the run cleared
- ⚠ **`Rules.ABSORB_RADIUS` (20.0) has a SECOND caller that has nothing to do with absorbing**:
  `add_clone()` uses it as the spawn ring (`swarm.gd:92`). Deleting the constant with the function it was
  named for **silently moves where every new clone appears.** Give the spawn ring its own name first

⚠ **`F` thins and `V` thickens, and `1` decides where the thickening happens.** They are one gesture in the
hand. `G` was tried and dropped — the finger travels too far.

### `1` — rally to the host, not to a point

**Changed by the user on 2026-08-14.** Today `command_rally(point)` sends clones to the mouse and its comment
in `swarm.gd` argues *against* rallying at the host: parking in cleared ground while the clones take the risk.
**That argument lost** — the user wants `1` to mean "come to me", and `3` now covers "go there".

⇒ **Rewrite that comment in `swarm.gd` rather than leaving it to contradict the code.** `CLAUDE.md`: a
refutation that lands in a different doc than the claim does not propagate. The rally point becomes the host's
live position, so it updates every frame as the host moves.

### `3` — attack the mouse point

```gdscript
func command_strike(point: Vector2) -> void
```

A third clone state, `STRIKE`. Clones walk to `point` at `CLONE_SPEED_FOLLOW` and, on arrival, **stay and
engage whatever is there** rather than returning. They do not seek food in this state.

**Combat itself is plan 4.** Here `STRIKE` is movement plus a flag; the net asserts they arrive and stay.

## The `Tab` panel

**One screen, everything about the body** (user, 2026-08-14): the eleven slots and what is in them, the host's
numbers, and the binding of parts' actives to the three keys. The user flagged that this may be too much for
one key and that `C` might split it later — **build it as one panel now**, and keep the layout in two halves
so splitting it is a re-parent, not a rewrite.

- **The game pauses while it is open.** `Run.step()` returns early, exactly as it already does for
  `pending_levels`
- Left half: the body, eleven slots, each showing its part name or empty
- Right half: three active rows — left click · right click · `space` — each a drop target
- **Binding is a click on a slot's active and then a click on a key row.** No dragging. Dragging is a
  different input model and it is not worth it for three rows
- **`space` refuses a non-movement active** and says so in one line of Korean rather than silently ignoring
  the click

**In this plan the panel opens, pauses, draws eleven empty slots and three empty rows, and closes.** Plan 3
fills it. Ship it empty rather than not at all — the pause and the toggle are the parts that break.

## Six things outside this plan's own files that it breaks

**Every one of these was found by adversarial review of the first draft, and every one is silent or
misattributed if it is missed.**

### 1. `project.godot` — six new input actions, and the nets bark without them

Registered today: `mv_left` `mv_right` `mv_up` `mv_down` `dash` `cmd_rally` `cmd_scatter`. This plan needs
**`fire_0` `fire_1` `fire_2` `cmd_strike` `split` `absorb` `body_panel`**, and `dash` goes away in plan 3.

⚠ **An unregistered action does not fail quietly.** Measured on 4.7.1 headless:
`ERROR: The InputMap action "cmd_strike" doesn't exist.` — on **stderr, every frame**. `net_cards` trees
`main.gd` and pumps frames, so `_read_input()` runs, so **the wrapper goes red for a reason that is not the
code.** Register them in the same commit. The editor does not re-read `project.godot`; restart it.

### 2. `net_grid` calls `command_rally(point)` three times and no plan named it

`net_grid.gd:25 :48 :64`. It is the **only** net measuring separation, grid pruning and a 40-body rendezvous.
Dropping the argument breaks its parse; keeping it does not save the checks at `:25`/`:48`, which park two
overlapping clones at a coordinate the host is not standing on — **a thing this plan makes impossible.**
Rewrite those two to place the *host* and rally to it.

### 3. `field_view.gd:54` stops drawing the rally ring the moment `1` means "the host"

It skips the ring when `rally == pos[0]`, which after this plan is **always**. Either delete the ring or
change what it means; leaving it is a feature that vanishes with every net green.

### 4. The mouse fires an active through every panel

`main.gd:63` polls `Input.is_action_just_pressed`. **A polled action is not consumed by a `Control`** — no
`mouse_filter`, no `set_input_as_handled()` stops it. So clicking a level-up card, a `Tab` binding row, or
the title's 시작하기 **also fires left click.** ⇒ **`_read_input()` runs only when no panel is open**, and
the panel-open flag is one boolean owned by the shell. Assert it: open the card panel, press fire, assert
nothing fired.

### 5. `F` and the level-up panel

Level-up freezes the sim. **`F` does not charge while any panel is open**, and an in-progress charge is
**dropped**, not paused — resuming a charge across a menu is a decision the player did not make.

### 6. The pause flag lives on `Run`, and `World.step()` is where the early return already is

`world.gd:58` returns early on `pending_levels > 0`. `Tab` adds a second reason. **Put both behind one
`Run`-owned boolean that `Run.step()` checks before calling `world.step()`** — two independent early returns
in two files is how one of them gets missed.

## Numbers

| Constant | Value | Why this one |
|---|---|---|
| `FORCE_START` | `1` | 1 cannot be split, so the first level-up is what opens `F` |
| `FORCE_PER_LEVEL` | `1` | level 4 means force 5 — three presses of `F` and the swarm is real |
| `SPLIT_HOLD_TIME` | `0.45` s | long enough to be an act, short enough to spam in a fight |
| `ABSORB_RADIUS_BODIES` | `4.0` | wide enough that a rallied swarm goes in one press, tight enough to miss stragglers |
| `STRIKE_ARRIVE_RADIUS` | reuse `rally_radius()` | the same disc maths; a second constant would diverge |
| `BODY_RADIUS` | `14.0` | **new, in `rules.gd`.** It decides who is absorbed, so it is a sim constant. `Look.HOST_RADIUS` reads it |
| `CLONE_SPAWN_RING` | `20.0` | **new.** The old spawn ring's value, given its own name so deleting `ABSORB_RADIUS` cannot move it |
| `START_CLONES` | **`0`** | the run opens alone. The prototype's 6 was scaffolding for a design where the level-up grew the swarm |

**Every one of these is a guess and is expected to move on the first session.**

## Nets

New `tests/nets/net_hands.gd`, plus updates to **`net_eat_carry`** (the `_absorb` deletion and
`ABSORB_RADIUS`), **`net_swarm_follow`** (the rally rule inverts), and **`net_grid`** (three
`command_rally(point)` calls — see *Six things*).

1. Force 1 host: holding `F` past `SPLIT_HOLD_TIME` produces **no** clone, and is not an error
2. Force 5 host: one full hold → two bodies with force `3` and `2`, **total unchanged**
3. Force 5 host and a force-3 clone: one hold → four bodies, forces `3,2,2,1`, **total 8**. *The split is
   simultaneous across every body, not the host alone*
4. Releasing `F` at 90% of the hold produces nothing, and the charge is back at zero
5. Split at `CLONE_CAP - 1` clones: the count lands **exactly** on the cap and the leftover bodies keep their
   force intact — assert the total is still conserved
6. `V` with clones inside and outside the radius: the inside ones are gone, the outside ones untouched, the
   host's force is the exact sum, and `carried` came with it
7. `V` with nothing in range returns 0 and changes nothing
8. **A clone killed by contact still loses its cargo and its force** — the old `_absorb` deletion must not
   have made death cheap. This is the one rule the whole build rests on
9. `1` moves the rally point **with the host** across frames — pin two different host positions
10. `3` sends clones to a literal coordinate and they **stay** there for 2 seconds of stepping. *A check whose
    bounds come from the thing it checks proves nothing* — pin the coordinate
11. `Tab` sets a pause flag and `Run.step()` **does not advance `world.elapsed`** while it is set
12. Binding a non-movement active to `space` is refused and the slot stays empty
13. **Driven, not grepped**: the panel's `_paint_panel(...)` hook is called with rectangles inside the
    viewport, and the panel's `size` is not `Vector2.ZERO`
14. **Kill a clone that is not the last row** (three clones, remove index 1) and assert the survivor at
    index 1 has **its own** force, not the dead one's. *Removing the only clone never runs the swap branch*
15. Holding `F` for `4 ×` the hold time without releasing adds **one** body, not four
16. A clone splits: the child sits within `SEPARATION_MIN` of **its parent** and carries **its parent's**
    state — put the parent far from the host, so reusing `pos[0]` fails
17. At `t = 0` there is **one** body and `total_force()` is the literal 1 — and holding `F` does nothing
18. With a panel open, pressing every one of the seven actions changes **nothing** — assert by driving
    `main.gd`, not by reading the gate flag

## Acceptance

**The user plays and reports whether splitting on purpose feels like a decision** — specifically whether the
hold reads as an act, and whether losing a fat clone out in the field hurts.
