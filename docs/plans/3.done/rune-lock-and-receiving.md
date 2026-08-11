# The rune lock — you start with none, and the bull hands you fire

**Status**: done — **stages A–D implemented and verified** (verify-read: zero open findings; B/C/D's
behavior confirmed by code review and by running end to end on the real map; verify-run's one finding —
a reset revoked ownership but left the earned rune sitting in the seat — is fixed and mutation-tested).
**Not the same as accepted** — see "Not settled" immediately below.
**One line**: the starting kit becomes **the none rune**, the assembly window stops offering runes you have not
been given, and **the bull's reward is what grants fire.** Three changes, one landing.

## Not settled — read this before assuming any of it is final

- **Nothing here has the user's acceptance.** Verified by code and by nets, not yet seen and confirmed on
  screen by the user
- **The reward is still taken with the debug key L** — no real trigger exists. `_take_boss_reward()` is a
  shell-only door, the same standing gap `stage1-bosses.md` already named for taking the reward at all
- **Which of the three receiving shapes wins is still the user's call** — this plan built "granted, then
  assembled" (Stage C). Auto-equip and corpse-pickup remain live; the grant is a single call site
  (`stage.gd`'s `_take_boss_reward()`) precisely so either alternative moves without touching anything else
- **`three_pick_window` still cannot carry a rune** — glyph-only, unchanged. Out of scope by this plan (see
  "Out of scope" below), not an oversight
- **Room ③'s reward remains unwired to any water or rune** — the gap `stage1-bosses.md` already recorded,
  untouched here

**This is step 3 of the milestone chain** ([planning-review-order.md](planning-review-order.md)) and it
closes **review items 1 and 6** ([planning-review-fixes.md](planning-review-fixes.md)).
**Step 2 (the bull) is done** — [stage1-bosses.md](stage1-bosses.md) built the seam this picks up.

**Source docs**: `docs/design/circle-rune-glyph.md` (what a rune is) · `docs/GDD.md` "First milestone" ·
`docs/decisions/no-inventory.md` (**this plan pushes on it — see "Is this an inventory"**)

---

## Why

**One side alone makes the game worse** (`planning-review-order`, and it is still exactly right):

```
lock the rune with no way to receive one  ->  the bull's reward has nowhere to go (one slot, no stash)
build receiving with the rune unlocked    ->  you already have fire, so the bull hands you nothing
```

⇒ Both, or neither. **The bull now exists**, so the premise that blocked this is gone.

---

## The correction that changes the size of this work

**I told the team earlier that the repo had no rune-placement path. That was wrong**, and it made this look
bigger than it is. I read `three_pick_window.gd` and generalised "no window calls `set_rune()`" from it.

**The assembly window has always placed runes**, `circle_window.gd:158-161`:

```gdscript
var slot := Layout.rune_slot_at(id, area, local)
if slot >= 0:
    _place_or_clear(Palette.KIND_RUNE, func(v: int) -> void:
        _circle.set_rune(slot, v), SpellCircle.RUNE_EMPTY)
```

Pick a rune from the palette, click the rune seat, it goes in. `_place_or_clear` · `_can_pick` ·
`_slot_count` · `_slot_accepts` all already treat runes as a first-class kind.

⇒ **The receiving screen is not missing. Ownership is.** What the three-pick window cannot pass is still
true and still measured (see "Out of scope"), but **it is no longer on the critical path** — the plan does not
need it.

---

## The lock is three changes, not two

| # | Where | Now | After |
|---|---|---|---|
| 1 | `spell_circle.gd:50` | `DEFAULT_RUNE := Tuning.ELEM_FIRE` | `Tuning.ELEM_NONE` |
| 2 | **`palette_layout.gd:73-74`** | `items_of(KIND_RUNE)` returns **`Tuning.ELEM_ALL`, unconditionally** | gated on ownership |
| 3 | — | nothing knows what you have been given | `Progress` owns it; the bull's reward grants fire |

 **#2 is the actual lock.** Change `DEFAULT_RUNE` alone and the player presses Tab, clicks fire in the
palette, and puts it in the seat. **The lock is void and nothing barks.**
**The GDD already says both halves** — its milestone gap table reads "`spell_circle.DEFAULT_RUNE` goes to
`ELEM_NONE` **and the palette stops offering all of `ELEM_ALL`**, or 'get fire from the midboss' stays
meaningless". So this is not a new finding, it is a half that **drops out of the short version of the task**
every time it is restated as two bullets. `palette_layout.gd`'s own header already said this was coming:
"There is no notion of 'owning' — **everything that exists** shows up (earning things in a dungeon is outside
this stage's scope)." That day is now.

###  `ELEM_NONE`, not `RUNE_EMPTY` — these are different and the task's wording is ambiguous

"The starting rune becomes none" has two readings and only one of them is playable:

| | Value | `can_fire()` | Reads as |
|---|---|---|---|
| **The none rune** | `Tuning.ELEM_NONE` (1) | **true** | a real rune that leaves no trace |
| An empty seat | `SpellCircle.RUNE_EMPTY` (−1) | **false** | **"cannot fire"** |

`spell_circle._init`'s own comment forbids the second outright: "Boot with an empty rune and the game starts in
a 'cannot fire' state, and **that reads as a malfunction**." ⇒ **`DEFAULT_RUNE := Tuning.ELEM_NONE`.**
The starting kit stays a working spell; what it loses is fire.

---

## Where ownership lives

**`Progress`, private, with accessors** — the same shape `_drawn` and `_reward_pending` already have, and it is
**forced**: `net_pick._no_pushed_out_glyph_is_stashed_anywhere` scans every `.gd` for a top-level **public**
`Array`/`Dictionary` not on its allowlist (the no-inventory decision). A public `owned_runes` turns that net red.

```
Progress._owned_runes           private
  .grant_rune(id)               the bull's reward calls this
  .owns_rune(id) -> bool        the palette asks this
```

**The rule lives in `src/actor/`, not in the window.** `circle_window._slot_accepts` asks `Progress`; it does
not keep its own list. A net can then drive ownership with no scene at all — the same reason
`three_pick.draw()` is a pure function rather than something you have to open a window to observe.

**`circle_window.setup()` gains a `Progress` argument** — one line there, one at `stage.gd:326`.
`_pick_window.setup(_world.progress(), _circle)` (`stage.gd:331`) is the precedent, verbatim.

### ~~Veiled, not hidden~~ — **reversed by the user. The unowned cell is now gone entirely**

**Read this before trusting anything in this section.** The user looked at the palette and reversed it:
**what you do not own has no cell at all** — not drawn, no seat in the row, nothing returned by the hit test.
The grounds and the rejected branches are in
[`docs/decisions/palette-hides-what-you-do-not-own.md`](../../decisions/palette-hides-what-you-do-not-own.md);
the work is [`onboarding-and-palette-tabs.md`](onboarding-and-palette-tabs.md), built.

⇒ **The table below is now a record of a rejected branch, not of the shipped behavior**, and its right-hand
column inverts: **filtering `items_of` is what happens**, so `net_circle._palette_is_kind_by_item`'s
`items_of(KIND_RUNE) == ELEM_ALL` — the check this section was written to keep green — **goes red on purpose.**
**The veil itself survives** for the other question (`_can_pick`: "you own it, but nothing will take it right
now"); what it stops meaning is "not yours".

Two ways to gate, and they differ on screen and in the nets:

| | Unowned rune | `net_circle:553` (`items_of(KIND_RUNE) == ELEM_ALL`) |
|---|---|---|
| filter `items_of` | **vanishes** from the palette | **goes red** — needs a net edit |
| gate `_slot_accepts` | draws **veiled**, unpickable | **stays green** |

⇒ **Gate `_slot_accepts`.** The player sees that fire and water exist and that they do not have them —
which is the whole of "the midboss reward is the key to progression" being legible before you earn it.
A rune that simply vanishes says nothing.

**The mechanism is already shipped and already uniform across kinds.** `circle_window._draw_palette_item`
ends with `if not _can_pick(kind, item_id): draw_rect(slot, …PALETTE_BLOCKED_VEIL_A…)` for **all three**
kinds, and `_can_pick` → `_slot_accepts` is documented as "the one place" the accepting condition lives.
Today `_slot_accepts` returns `true` for every non-glyph kind; this adds the rune branch **there**, in the
place its own header says such rules belong.

---

## Is this an inventory

`docs/decisions/no-inventory.md` ends with a test line: **"growing during a run is an inventory; visible only
in town is a list."** `_owned_runes` grows during a run. **On its face this fails that test, and it must be
faced rather than stepped around.**

**The argument that it is not a stash:**

- A stash is **a menu you choose from**. With **one rune seat** and a fixed starting kit, the owned set after
  the bull is `{none, fire}` — and swapping back to none is not a build decision, it is undoing a reward
- The decision's own rejected branch was "**stash it and equip from the assembly window**", rejected because
  "it creates *I don't have to decide yet*, deferring the weight of the choice". **The weight here is not
  deferred — it is zero.** There is nothing to trade off: fire strictly adds
- What the field records is **"what you have been granted"**, the same category as town's unlock list

**But it does grow during a run, so the test line has to be amended, not silently violated.**
⇒ **Required edit**: one section in `docs/decisions/no-inventory.md` naming this exception and its bound
(*a record of grants, not a chooseable set — it stops being exempt the day a rune seat count exceeds one*).
**Do not skip this.** A decision doc that a shipped feature quietly contradicts is worse than no doc.

###  And this picks one of the three candidates the user left open

`stage1-bosses.md`'s TBD listed how the fire rune is received: **auto-equipped · dropped and picked up and
assembled · the corpse burns and you pick it out.** This plan is **the second** — you are granted it, and you
place it in the assembly window at a safe moment, which is where the GDD already pushes assembly.

**Provisional, and it is the user's to overturn.** If they want auto-equip, stage C shrinks to one line
(`grant_rune` + `set_rune` together) and the palette work still stands unchanged. If they want the corpse
pickup, stage C grows a world-space trigger and **nothing else in this plan moves.** The lock does not depend
on which of the three wins.

---

## What this lock does **not** do — say it before someone reports it as a bug

**It does not stop the player burning the wood wall.** Verified in code, not assumed:

```
spell_sim.gd:633   grid.apply(CellGrid.cmd_blast(x, y, rd, Tuning.blast_ignite_r(gen)))
                   ^ the ignition radius is applied regardless of `element`
                   `element` reaches only `_notify_blast` (the FX) on the next line
```

⇒ **A none-rune blast ignites wood.** `stage1-map-layout` measured it: three blasts and 159 cells alight,
no fire rune needed.

**The user closed this knowingly** (review item 5): the wall sits beyond pit ①, the pit only opens with the
bull's water, **so you are already carrying fire by the time you can stand in front of that wall.**
**The lock is geometric, not elemental.**

⇒ **No acceptance in this doc may read "without fire you cannot burn the wall."** It would be false, and a
verifier would faithfully report a decision as a defect. What this plan locks is **which rune you carry**,
and the price — that the lock now rests on the map's shape — is already written down in
`planning-review-order`.

---

## Screen

Every stage carries its own screen half. **Ownership growing while the palette keeps offering everything is
this repo's signature fake with the halves swapped.**

- **The palette** — an unowned rune is veiled (`PALETTE_BLOCKED_VEIL_A`, shipped) and cannot be picked
- **The staff tip** — already tinted per rune through `Fx.ELEM_FX` (`fx_tuning.gd:1061`), so "I am carrying
  none, not fire" is **already on screen** the moment `DEFAULT_RUNE` moves. **Confirm by eye, do not build**
- **The moment of the grant** — the fire cell un-veils. That is the reward becoming visible

---

## Order

| # | Stage | Verified by |
|---|---|---|
| **A** | **Ownership exists and the palette obeys it — with the game unchanged.** `Progress._owned_runes` + `grant_rune`/`owns_rune`; `circle_window.setup` takes `Progress`; `_slot_accepts` gains the rune branch. **Starting kit is `{ELEM_NONE, ELEM_FIRE}`** so nothing the player can do changes yet — **only water veils** | Headless: `owns_rune` drives `_can_pick` on an untreed window. On screen: the water cell is veiled and unpickable, fire and none are not. **The game plays exactly as before** |
| **B** | **The lock lands.** Starting kit → `{ELEM_NONE}`; `DEFAULT_RUNE` → `Tuning.ELEM_NONE` | Fresh boot: none is in the seat, **you can still fire**, the staff tip reads none, and **fire is veiled in the palette**. `net_circle:1184` moves with it (below) |
| **C** | **The bull's reward grants fire.** `KEY_L` already clears `_reward_pending` and starts ①'s water (`stage1-bosses` stage I) — it now **also** calls `grant_rune(ELEM_FIRE)` | Kill the bull → press L → the palette's fire cell un-veils → place it in the seat → the staff tip goes fire. **Before the bull, L grants nothing** |
| **D** | **The presets stop wiping an earned rune.** `stage.gd:596` passes `SpellCircle.DEFAULT_RUNE` into `apply_preset`, so keys 1–6 would silently put none back over your fire | Earn fire, place it, press key 4, **fire is still in the seat**. `apply_preset`'s own comment already predicted this day: "**the day there are several kinds of rune, the preset has to take a rune list**" |

**A before B is the whole point of A.** Landing the mechanism while the game is unchanged means a failure in
stage B is unambiguously the lock, not the plumbing.

---

## Files to touch, and why

| File | Why |
|---|---|
| `src/actor/progress.gd` | `_owned_runes` (private) + `grant_rune` / `owns_rune`; `reset()` follows |
| `src/actor/spell_circle.gd` | `DEFAULT_RUNE` → `ELEM_NONE` (stage B). **One line** |
| `src/view/palette_layout.gd` | **Nothing, if the gate goes in `_slot_accepts`** — listed so the next reader knows it was considered and why it was left alone |
| `src/view/circle_window.gd` | `setup()` takes `Progress`; `_slot_accepts` gains the rune branch |
| `src/stage/stage.gd` | `_circle_window.setup(_world.progress(), _circle)`; `KEY_L`'s handler also grants; the preset's rune argument (stage D) |
| `tests/nets/net_circle.gd` | Two named edits below |
| `tests/nets/net_progress.gd` | Ownership: granted · not granted · survives what it should · `reset()` |
| `docs/decisions/no-inventory.md` | The exception and its bound (required — see "Is this an inventory") |
| `docs/design/circle-rune-glyph.md` | One section: **"how you come to have a rune"** — that doc covers all three axes and has no acquisition section at all (grepped: no `owning`/`획득`/`보유`) |

 **No new `docs/design/` doc is needed, and I checked before saying so.** `circle-rune-glyph.md` already owns
the rune concept (10 designed, 3 running); what is missing is one section inside it, not a document. Spawning a
design round for one paragraph would cost more than it buys, and the concept side of this — "the starting kit
is the none rune and the basic circle" — **is already decided by the user** and recorded in
`planning-review-order`. **The one genuinely open question is the receiving shape, and it is flagged above as
the user's to overturn**, not held as a blocker.

---

## Risk

**1. Two net checks move, and both are load-bearing rather than incidental.**

| Where | Says | After |
|---|---|---|
| `net_circle.gd:1184` | `SpellCircle.new().element() == Tuning.ELEM_FIRE` — "새 진의 룬 자리에 불이 들어 있다" | becomes `ELEM_NONE`. **Its own comment says why it exists**: "Change this and the rune that gets fired changes quietly" — that is exactly what is being changed, so **edit the value, keep the check** |
| `net_circle.gd:553` | `want[KIND_RUNE] == Tuning.ELEM_ALL` | **stays green** — this is the reason the gate goes in `_slot_accepts` and not in `items_of` |

`net_circle.gd:1189` (`rune_at(0) == DEFAULT_RUNE`) and `:1213` are written **against the constant**, so they
follow for free. **Do not "fix" them.**

**2. Bricking.** Removing your only rune (`RUNE_EMPTY`) must stay recoverable — **ownership is not cleared by
unequipping.** `_slot_count(KIND_RUNE)` already returns `_circle.rune_count()`, so with the circle removed the
rune veils for a different reason; both paths must leave an owned rune pickable once a circle is back.
`circle_window`'s own header records that this exact class of bug already shipped once ("remove the circle and
the rune stays bright and pickable, and pressing anywhere did nothing").

**3. `ELEM_NONE` vs `RUNE_EMPTY`** — see the box above. Getting this wrong ships a game that boots unable to
fire, and the symptom ("left click does nothing") reads as a breakage, not a rule.

**4. A check that reads only final state cannot measure a grant.** "Fire is pickable" is true both before the
lock lands and after the reward. The measurement is **the transition**: unpickable → grant → pickable, in one
run, asserted in that order.

**5. The screen half of stage A is the whole of stage A.** A `Progress` field with an `owns_rune()` nothing
consumes is a false knob. If A ships without the palette following, it has shipped nothing.

**6. Net baseline**: **3,991 pass / 3 fail**, all three the pre-existing `net_water_rain` reds
(they were red before the bosses work and before this). Round 12.7s. `net_monster` is now four files
(`net_monster` · `_charge` · `_breath` · `_slam`, split by `harness-manager`).

**7. A reset revokes ownership but not possession — found by verify-run, fixed.** Risk 2 above only closed
half of "bricking": ownership was never cleared by *unequipping*, but nothing enforced that ownership stays
in sync with the *seat* the other way. After `reset_stage()` (R), `Progress.reset()` narrows the owned set
back to `{none}`, but `SpellCircle`'s rune slot was untouched — a run that had earned fire could no longer
*pick* fire in the palette (`owns_rune(FIRE) == false`) while still *firing* it at full effect (`element()`
still `FIRE`, a plain bolt still burning a 7,530-cell forest to 1 cell). Stage D's carry-over then actively
preserved that unowned rune across every preset press.

⇒ **The invariant is "seat ⊆ owned".** `stage.gd`'s `_revoke_unowned_rune()`, called from `reset_stage()`
right after `_world.reset()`: if the seat holds a rune that isn't `RUNE_EMPTY` and isn't owned, it comes down
to `Tuning.ELEM_NONE` — never `RUNE_EMPTY`, so the un-emptiable-seat rule (the disarm fix, above) still holds
and `can_fire()` stays true. Does not touch glyphs or the circle id — R still doesn't reset the assembly.
**Mutation-tested three ways**: dropping the call leaves the seat at `FIRE` (red, by value); forcing the seat
to `ELEM_NONE` unconditionally (not checking ownership) passes every check driven only through `reset_stage()`
— `Progress.reset()` always narrows to exactly `{none}`, so "check ownership" and "always clear" are
observationally identical at that one call site — caught only once `net_render` drives `_revoke_unowned_rune()`
directly with the owned set at `{none, water}`, a state `reset_stage()` itself can never produce.

---

## Acceptance

**Write what was seen by eye under this section immediately** (CLAUDE.md).

1. **A fresh run starts with the none rune in the seat — and can still fire**
2. **The staff tip reads none, not fire** — distinguishable by eye from a fire run
3. ~~**Fire is visible in the palette and cannot be picked** — veiled, not missing~~
   **Void — reversed by the user** (see "Veiled, not hidden" above). Fire is **missing**, not veiled
4. ~~**Water is visible and cannot be picked either** — nothing in this game grants it yet~~ **Void, same
   reversal.** Water is missing too, and for the same reason: nothing grants it
5. **Kill the bull, take the reward → fire becomes pickable**, and placing it turns the staff tip fire
6. **Before the bull, nothing grants fire** — the reward key does nothing on its own
7. **A preset key does not wipe an earned rune**
8. **Unequipping fire does not lose it** — it stays pickable
9. **The pit still opens** — the reward gate and ①'s water are unchanged by this work

**Not acceptance, deliberately**: "without fire you cannot burn the wood wall." It is false in code, knowingly
— see "What this lock does not do".

---

## Out of scope

- **The three-pick window's rune card.** Still glyph-only, and still true: `three_pick.draw()` draws from
  `Glyph.ALL`, `_draw_card` indexes `Glyph.DEFS[glyph_id]`, `_gui_input_step2` places with `place_glyph`, and
  **`Tuning.ELEM_FIRE == 0 == Glyph.GLYPH_NONE`** so a rune id is indistinguishable from "no glyph" in that
  path. **It is simply not needed** — the assembly window already places runes. Reopen it the day a reward must
  offer *a choice between runes*, which is the first thing that path buys and nothing today asks for
- **The rooster's reward** (research material + a three-pick) — no owner anywhere
- **Town handing over the starting kit** (`design/town.md`) and **the tutorial that teaches the rule** — both
  named as owner-less in `planning-review-order`; code holds the fixed kit directly until town exists
- **Making the wood wall an elemental lock** — the user closed it as geometric
- **`net_water_rain`'s 3 reds** — red before this started

---

## TBD

**Do not force these full.**

- **Which receiving shape wins** — this plan takes "granted, then assembled". Auto-equip and corpse-pickup
  are still live and only stage C moves
- **Does ownership survive `R`** — the plan resets it with the rest of `Progress` (a stage reset is a fresh
  run). It is one line either way
- **Whether none should be removable at all** — allowed here, guarded by risk 2
