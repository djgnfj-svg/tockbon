# The palette gets tabs, and the game starts with an empty circle

**Status**: active
**One line**: the right page becomes **three tabs — 진 · 룬 · 문양 — one open at a time**, **what you do not
have has no cell at all**, the circle **starts empty** (so the first thing the game asks you to do is assemble
one), and a short onboarding walks you through it once: an arrow at **Tab**, 진 → 룬 → 문양, then
**「마법진 완성」**.

**Design doc**: [../../design/tutorial.md](../../design/tutorial.md) — this is the first slice of it.
**Reversed by this doc**: [../3.done/rune-lock-and-receiving.md](../3.done/rune-lock-and-receiving.md)'s
"veiled, not hidden" (`docs/decisions/palette-hides-what-you-do-not-own.md`).

**Read the TBD section before estimating.** **Every pixel value** in this doc is genuinely undecided.
**Which glyphs the 문양 tab lists is decided** — see Behavior §2 — and needs no new field.

---

## Why

**The window opens onto fourteen cells, and eleven of them are things the player cannot use.**
`palette_layout` splits the right page into three sections **stacked vertically, all visible at once**:
진 (2 items), 룬 (3), 문양 (9). Everything in every table shows up — `items_of()`'s own header says so:
"There is no notion of 'owning' — **everything that exists** shows up". `rune-lock-and-receiving` added
ownership for runes but deliberately kept the unowned cells **drawn and veiled**, so the count on screen
never went down.

**And nothing ever asks the player to open that window.** `spell_circle._init` places `DEFAULT_CIRCLE` and
`DEFAULT_RUNE` at boot, so a fresh run can already fire. The one window this game is built around is a
window you never have to touch.

⇒ **Two changes, one landing.** Cut the palette down to what you have and show one kind at a time; **start
the circle empty** so assembling it is the first thing that happens, and walk the player through that once.

**"시작하자마자 못 쏘는 상태가 맞다" — the user confirmed this explicitly**, and it reverses a rule written
in code. `spell_circle._init`'s own comment reads: "Boot with an empty rune and the game starts in a 'cannot
fire' state, and **that reads as a malfunction**." That comment must be edited in the same change, not left
standing — see "Interaction with what exists".

---

## Behavior

### 1. The palette is tabbed

- **Three tabs across the top of the right page: 진 · 룬 · 문양.** Exactly one is open
- **The 진 tab is open when the assembly window opens**
- The two closed kinds draw **no section and no items**, and **their coordinates are not clickable**
- **Tabs never auto-switch during normal play.** Auto-advance exists only inside onboarding (§5)

The three kinds and their Korean names already live in one place (`palette_layout.KIND_DEFS`,
`KINDS`) — the tab strip reads that table, so a fourth kind grows a fourth tab with no second list to edit.

### 2. What you do not have has no cell

**The veil is gone. The cell is gone.** An item you do not have is not drawn, takes no seat in the row, and
returns nothing from the hit test.

**This is a different question from "can it be placed right now", and they must not share a function.**

| Question | Answer today | Answer after |
|---|---|---|
| Do I have this at all | runes: `Progress.owns_rune` · circles: **nothing** · glyphs: **nothing** | decides whether a **cell exists** |
| Can it go somewhere right now | `_can_pick` → `_slot_accepts` (empty layer · `max_per_circle` · rune ownership) | decides whether the cell is **dimmed** |

**Fold them together and placing spread makes spread vanish from the palette** — `max_per_circle` is 1, so
`_can_pick(KIND_GLYPH, SPREAD_C)` goes false the instant it is placed, and under a hide-on-`_can_pick` rule
the player would watch the thing they just earned disappear. ⇒ **Ownership hides. `_can_pick` still dims**
(`PALETTE_BLOCKED_VEIL_A` keeps its job for the second question only).

**The rune gate therefore moves from `_slot_accepts` to the item list**, which is the branch
`rune-lock-and-receiving` looked at and rejected. That reversal is filed separately.

**Circles have no ownership field at all** — see TBD (삼각's ownership is still open). 진 is stated as
"일반진은 이미 가지고 있다".

**What the 문양 tab lists is decided: the glyphs currently placed in the circle.** No held-glyph stash, no
new field — `items_of(KIND_GLYPH)` reads `_circle`'s layers directly. It starts empty (no circle → no
glyphs), gains an entry the instant a level-up three-pick calls `place_glyph()`, and the tab's one job is
letting the player pick a seated glyph back up to move it between 1층/2층 (order changes the effect).
Filed as `docs/decisions/the-glyph-tab-shows-the-circle.md`, alongside `no-inventory.md`.

### 3. 문양 starts empty, and says so

The 문양 tab opens on **"현재 문양이 없습니다"** — a line of text where the row of cells would be, not a
blank rectangle. An empty framed box reads as a drawing bug; this is the same reason
`_draw_palette_section` draws a title and a frame at all ("without a frame and a title the same screen simply
reads as **unfinished**").

### 4. One click inserts, when there is only one seat

| Kind | Seats | Click in the palette |
|---|---|---|
| 진 | always **1** (`_slot_count(KIND_CIRCLE)` returns 1, even with no circle) | **inserts immediately** |
| 룬 | `_circle.rune_count()` — **1** for 동그라미, **3** for 삼각 | 1 seat → inserts · 3 seats → pick, then place |
| 문양 | `_circle.layer_count()` — 2 or 3 | pick, then place (**1층/2층 changes the effect**) |

**The rule is "how many seats does this kind have", not "which kind is it".** Write it per kind and the
삼각 circle — three rune sockets, already shipped — silently gets one-click insertion into socket 0 with no
way to reach sockets 1 and 2. `_slot_count(kind)` already answers this and is already the one place the
count comes from.

**Removal is unchanged**: clicking a filled seat with nothing picked clears it, and the rune seat still
clears to `Tuning.ELEM_NONE` rather than `RUNE_EMPTY` (the self-inflicted disarm
`circle_window._click_circle` records). One-click insertion must not delete that path.

### 5. 「마법진 완성」 — it confirms, it does not apply

A button under the palette, **always present**, in every tab.

**Assembly is already live before it is pressed.** Every click has already written into the one `SpellCircle`
the muzzle and the fire command read. Pressing 완성 makes the circle **glow once** and **closes the window**.

**Why this is stated so loudly**: an "적용" button is the failure mode. A player who assembles and closes with
Tab or ESC would carry an unapplied circle and fire nothing, and "I built it and it did nothing" reads as a
broken game, not a missed step. Filed as `docs/decisions/circle-done-button-is-confirm-not-apply.md`.

### 6. 찰칵 on every insert

진, 룬 and 문양 all get the same feedback the instant they land in a seat. **What "찰칵" is has not been
decided** — and **this repo has no sound at all** (measured: **0** `.wav`/`.ogg`/`.mp3` files anywhere, **0**
references to `AudioStream` or `AudioServer` in any `.gd` or `.tscn`; `design/game-feel.md` and
`design/attack-rhythm.md` both already say so). See TBD and Cost.

### 7. The run starts with an empty circle

- No circle, no rune. **`can_fire()` is false on the first frame** and left-click does nothing
- **Nothing is picked up.** 일반진 and the 무속성 룬 are **already in the palette** — the player owns them and
  simply has not assembled them
- The staff tip already reads "dead" in this state (`Fx.DEAD_TINT`, the same grey as an empty rune seat),
  so "why can I not fire" is on screen through a device that already exists

### 8. Onboarding — short, once

| # | Beat |
|---|---|
| 0 | **In town, 연구대 shows 「준비중」 and you walk past it.** The bench's real feature is not deleted, only closed off |
| 1 | Enter stage 1 → **an arrow points at Tab** |
| 2 | Open the window → **진 tab** → press 일반진 → it seats with a 찰칵 → **the tab auto-advances to 룬** |
| 3 | Press 무속성 룬 → it seats in the middle → **the tab auto-advances to 문양** |
| 4 | 문양 is empty — **"현재 문양이 없습니다"** |
| 5 | Press **「마법진 완성」** → the circle glows → the window closes → out into the trash-mob stretch |

**Firing before leaving is allowed.** Nothing gates the exit on having fired.

**Auto-advance is onboarding-only.** Outside it, pressing 일반진 seats it and the 진 tab stays open.

**Two later onboarding beats are not this doc's.** One line each, and no more:
(1) a level-up three-pick creates the 문양 tab's first entry and a donut ring clicks into the circle;
(2) the bull's fire rune adds a cell to the 룬 tab with "불 룬을 껴 보세요". **Whoever writes those owns the
detail** — do not derive it from here.

---

## Screen

**Every number below is what runs today.** The user judges the new ones by eye — **none of them are decided**
(TBD). They are listed so there is a starting point to move from.

### Window and pages — unchanged by this doc

| Value | Now |
|---|---|
| `WINDOW_RECT` | `Rect2(48, 12, 864, 372)` |
| `WINDOW_TITLE` · size · band | `"마법진 조립"` · 16 · `WINDOW_TITLE_BAND_PX` 34 |
| Left page (magic circle) | `Rect2(12, 34, 415, 326)` |
| Fold | `Rect2(427, 34, 10, 326)`, `BOOK_FOLD_PX` 10 |
| Right page (palette) | `Rect2(437, 34, 415, 326)` |

Derived from `BOOK_MARGIN_PX` 12 + `WINDOW_TITLE_BAND_PX` 34 + `BOOK_FOLD_PX` 10 — pinned nowhere, computed
in `book_layout.pages()`.

### The palette as it stands — three sections stacked

| Value | Now |
|---|---|
| `PALETTE_PAD_PX` · `PALETTE_SECTION_GAP_PX` | 14 · 10 |
| One section | 387 × **92.67** — `(326 − 28 − 20) / 3` |
| Section tops (page-local) | y = 14 · 116.67 · 219.33 |
| `PALETTE_HEAD_PX` · `PALETTE_HEAD_SIZE` | 24 · 14 |
| Item row height | 68.67 (section minus the title band) |
| 진 cell (2 items) | 193.5 × 68.67 · symbol r **17.85** |
| 룬 cell (3 items) | 129 × 68.67 · symbol r **17.85** |
| 문양 cell (9 items) | **43** × 68.67 · symbol r **11.18** |
| `PALETTE_SYMBOL_RATIO` | 0.52, **against the cell's short side** — that is why 43-wide 문양 cells are the ones that shrink |

**One tab open instead of three frees roughly 2× the height** (92.67 → up to ~278 minus the tab strip and the
완성 button). **That is the whole point of the tabs on the 문양 row**, where nine cells at 43px are the
tightest thing on the page.

### The magic circle as it stands — the numbers that move

| Value | Now |
|---|---|
| `circle_area` | `Rect2(14, 14, 387, 298)` inside the left page, `CIRCLE_AREA_PAD_PX` 14 |
| Frame radius | **140.06** (`CIRCLE_DISC_RATIO` 0.94) · center (207.5, 163) page-local |
| Rune seat (동그라미) | dead center · drawn radius **23.81** (`CIRCLE_RUNE_RATIO` 0.17) |
| Layer ring zone | `CIRCLE_RING_ZONE` 0.80 → **112.05** |
| Layer 1 · 2 outer radii | **56.02** · **112.05** |
| Layer 1 · 2 glyph seats | 12 o'clock on each ring — (207.5, **106.98**) · (207.5, **50.95**) |
| Glyph symbol radius | **16.11** (`CIRCLE_GLYPH_RATIO` 0.115) |
| Layer hit disc | 29.0 (`SLOT_HIT_RATIO` 1.8 × glyph radius), inner 0 |
| Rune hit disc | 42.86 (1.8 × 23.81) |

**Three requested moves, all TBD in size:**

1. **The rune gets much bigger** — `CIRCLE_RUNE_RATIO` 0.17 is the knob, and `RUNE_ART_FRAC` 0.62 sizes the
   picture inside it
2. **Rune seat · 1층 seat · 2층 seat each move one step outward** — the seats come from
   `circle_layout.layer_bands()`'s `seat` (12 o'clock at each ring's outer radius) and `rune_slots()` (dead
   center for `PIC_ROUND`). **There is no "one step" constant today** — the layer seats sit *on* their rings,
   so pushing them out is either a new offset on `seat` or a change to `CIRCLE_RING_ZONE`. Which, and by how
   much, is TBD
3. **The `+` on an empty layer goes away.** `_draw_empty_slot` currently draws a faint ring **and a plus**
   (`SLOT_PLUS_RATIO` 0.5, `SLOT_PLUS_PX` 1.5). The user: "문양이 도넛 모양으로 껴져야 되는데 위쪽에 플러스
   표시가 왜 있는지 모르겠다". **What replaces it is TBD** — the ring alone, a donut outline, or nothing.
   `_draw_empty_slot`'s own comment argues the ring alone reads as "a seat" and not as "you can place here";
   whoever removes the plus is overturning that sentence and should edit it, not leave it standing

**These three interact with a measured overlap.** The layer-1 hit disc already claims part of the rune's
drawn area — `net_circle._hit_tests_match_the_drawing` records "91 of the rune-seat pixels are claimed by
the layer branch first", and `_click_circle` checks layers before runes on purpose. **Grow the rune and move
the layer seats outward and that overlap changes**, in the direction of getting better — but it is pinned by
that check and by `_triangle_hit_shapes_stay_disjoint`, and both must be re-measured, not assumed.

### New things with no numbers yet

Tab strip height · tab label size · the open/closed tab colors · the "현재 문양이 없습니다" text size and
seat · the 완성 button rect, label size and colors · the 찰칵 animation · the 완성 glow · the onboarding
arrow. **All TBD.** `settlement_layout.button_rect()` and `pick_layout.decline_rect()`/`dice_rect()` are the
two shipped precedents for a drawn button's rect and are the right things to copy the shape of.

---

## Bounds

### Drawing and clicking pass through the same functions — the tab index must enter both

`palette_layout`'s own header: "**Drawing and clicking both pass through the same functions in this file.**
Coordinates in two places gives 'I clicked this and that got picked', and **no error is raised.**"

`item_at()` today walks **all three** kinds and every item. **Give the drawing a tab and forget the hit test
and clicks land on the hidden tab's items** — silently, because the hidden section's rectangle still exists
in `section()`'s arithmetic. ⇒ **The open tab is an argument to `section()`, `item_slot()` and `item_at()`
alike**, and the closed tabs must return nothing from the hit test, not merely go undrawn.

`net_circle._hit_tests_match_the_drawing` already drives `Palette.item_at(pal.size, slot.get_center())` over
every kind's every cell and asserts the answer matches the drawing loop. **That check is the right shape and
must be extended**, not replaced: it needs a hidden-tab case (a cell center in a closed tab returns `{}`),
or the whole tab feature is untested by the one check built to catch exactly this.

### A tab must not be a `Button`, and neither must 완성

`circle_window.gd`'s header: "**`focus_mode` must be NONE**. If a `Control` inside the window takes focus,
Tab is consumed by the GUI as `ui_focus_next` and **never reaches** `_unhandled_input` => 'Tab does not
work'. The symptom is identical to 'the input map was not fixed', so diagnosis takes a long time."

**A `Button` child for each tab closes the assembly window's only key.** Both shipped sibling windows already
show the way: `settlement_window` and `three_pick_window` draw their buttons as rectangles and hit-test them
with `Layout.button_rect(size).has_point(mb.position)` inside `_gui_input`. ⇒ **Tabs and 완성 are drawn
rects with rects in a `*_layout.gd`.** No new node of any kind.

### `draw_set_transform` must still be restored

`_draw()` seats the circle with `draw_set_transform(page.position)`, restores to `Vector2.ZERO`, then seats
the palette with `draw_set_transform(pal.position)` and restores again. "**It must be restored.** Without
restoring, everything drawn afterwards is shifted by the page." The tab strip and the 완성 button are new
things drawn *near* that boundary — decide **once** whether they live inside the palette page's transform
(and therefore in page-local coordinates in both the drawing and the hit test) or outside it, and make
`_gui_input` subtract the same value from the same source. Half in and half out is the risk-22 face and it
raises nothing.

### The window must not become a full-screen `Control`

"**No full-screen `Control` is laid down while the run is live**" — being able to shoot outside the window's
rect is the evidence that the world does not stop. The one declared exception is `settlement_window`, and it
is safe only because the run is already over. Tabs and the 완성 button live **inside `WINDOW_RECT`.**

### `_can_pick` keeps its second job

`_draw_palette_item` ends with `if not _can_pick(...): draw_rect(... PALETTE_BLOCKED_VEIL_A ...)`. That line
stays and keeps meaning "cannot be placed right now". **What it must stop meaning is "not owned"** — see
Behavior §2 for why folding the two kills the feature the moment a glyph is placed.

### One-click insertion must not delete the removal path

`_place_or_clear`'s "nothing picked → clear" branch is what removes a circle, rune or glyph, and the rune
branch's clear value is `Tuning.ELEM_NONE` and **not** `RUNE_EMPTY` — a fix verify-run found after two
harmless clicks dropped a working circle to `can_fire() == false`. One-click insertion means 진 and (round)
룬 **never leave anything in the hand**, so a seat click always takes the clear branch. Confirm that is what
is wanted before shipping: it makes a mis-click on the rune seat an instant disarm-to-무속성 with no undo.

### Tick and frame

Nothing here touches the sim. The window already redraws every frame while visible (`_process` →
`queue_redraw`), so the 찰칵 and the 완성 glow are **frame-counted, not tick-counted**, and the 60Hz/20Hz
trap does not apply to them. **It does apply to anything the onboarding watches for in the world** — if a
beat ever waits on a world event rather than on a click, latch the 60Hz fact and let the tick read it
(CLAUDE.md's `_charge_blocked` shape).

### Not in this doc

- The two later onboarding beats (三택 → 문양 tab, bull → 불 룬). One line each above, deliberately
- **Any change to what a circle, rune or glyph *does*.** This is the window and the first ten seconds
- The 연구대's real feature. It is closed off, not removed

---

## Interaction with what exists

### It reverses `rune-lock-and-receiving.md`

That doc chose "veiled, not hidden" with a table and a reason: "**The player sees that fire and water exist
and that they do not have them** — which is the whole of 'the midboss reward is the key to progression' being
legible before you earn it. A rune that simply vanishes says nothing." **The user has reversed it.**

⇒ Three edits, and the reversal is only real if all three land:
`docs/decisions/palette-hides-what-you-do-not-own.md` (new) · a reversal note **inside**
`rune-lock-and-receiving.md` · this doc. The decision's own note must also reach that doc's **acceptance
items 3 and 4** ("Fire is visible in the palette and cannot be picked — veiled, not missing"), which become
false the day this ships.

### It pushes on `no-inventory.md` harder than the rune did

`rune-lock-and-receiving` already had to amend that decision's test line — "growing during a run is an
inventory; visible only in town is a list" — and argued `_owned_runes` is exempt because **with one rune seat
there is nothing to choose between**, with an explicit bound: "**it stops being exempt the day a rune seat
count exceeds one.**" **삼각 circle has three.**

**A 문양 tab that lists glyphs you hold but have not placed would be a stash by that doc's own definition —
the user did not pick that reading.** The tab lists only what is already seated in the circle, which is a
view, not a collection: nothing grows behind the scenes for the player to choose from later. Filed as
`docs/decisions/the-glyph-tab-shows-the-circle.md`.

Note also `net_pick._no_pushed_out_glyph_is_stashed_anywhere`: it scans every `.gd` under `src/` for a
top-level public `Array`/`Dictionary` not on its allowlist. **Any new ownership collection turns that net red
until it is deliberately allowlisted** — which is the net doing its job, and the allowlist entry is where the
argument gets written down.

### It overturns a sentence in `spell_circle.gd`

`_init`: "**The starting state has the circle and the rune filled in.** Boot with an empty rune and the game
starts in a 'cannot fire' state, and that reads as a malfunction." The user has decided the opposite.
**Edit that comment in the same change.** A comment that argues against the shipped behavior is worse than no
comment — the next session will "fix" the boot state back.

`DEFAULT_CIRCLE` and `DEFAULT_RUNE` also feed `apply_preset` (debug keys 1–6, `stage.gd`), which exists
partly so "a user who removed the circle **is not trapped**". **The debug keys must still work from an empty
circle**, or the empty start makes them dead on the first frame.

### The 연구대 goes to 「준비중」 — and that closes the only 원석 sink

`research-bench-unlocks.md` is in `3.done/`: three unlocks at `Progress.GEMS_PER_UNLOCK` (10), bought at the
bench, surviving `reset()`. `_interact()` routes `Fixtures.KIND_RESEARCH` to `_toggle_research()`, which
opens a real window and sets `_town_message` from `research_text()`.

**With the bench closed, 원석 accumulates with nothing to spend it on** — the exact state
`progress.gd`'s own comment describes as the honest version of a missing feature, but it is a step backward
from what shipped. **`Progress.buy()`, `UnlockDefs`, `research_window.gd`, `research_layout.gd` and
`net_research` all stay.** What changes is the door.

**Whether 「준비중」 is permanent or onboarding-only is not decided** (TBD). It matters: onboarding-only means
one flag; permanent means `design/town.md`'s 원석 section and `design/README.md`'s town row both go stale.

### Files this touches

| File | Why |
|---|---|
| `src/view/palette_layout.gd` | tabs enter `section`/`item_slot`/`item_at`; `items_of` gains ownership; tab-strip rects |
| `src/view/circle_window.gd` | tab state · the tab strip and 완성 drawn + hit-tested · one-click insert · 찰칵 · hide-vs-dim split |
| `src/view/circle_layout.gd` | the rune grows · three seats move outward |
| `src/view/fx_tuning.gd` | every new constant, and `CIRCLE_RUNE_RATIO` · `SLOT_PLUS_*` |
| `src/actor/spell_circle.gd` | the empty start, and the `_init` comment that argues against it |
| `src/actor/progress.gd` | circle ownership **if 삼각 needs it** (see TBD). Glyph ownership needs no field — it reads `_circle` |
| `src/stage/stage.gd` | onboarding state and its arrow · the 연구대 door · `_leave_town()` is the stage-1 entry moment |
| `docs/decisions/` | two new docs (filed with this one) |
| `docs/plans/3.done/rune-lock-and-receiving.md` | the reversal note, in the reversed doc |
| `docs/design/tutorial.md` | the concept doc, created with this one |

---

## Cost

### Nets that go red, by name

| Check | What it pins | After |
|---|---|---|
| `net_circle._palette_is_kind_by_item` | `items_of(KIND_RUNE)` **equals `Tuning.ELEM_ALL` by value**, and the same for circles and glyphs | **red.** This is the check `rune-lock-and-receiving` gated at `_slot_accepts` specifically to keep green. It must now measure "the items are what you own", and it needs a case proving a **granted** rune appears |
| `net_circle._palette_geometry_runs` | all three sections sized, inside the page, mutually non-overlapping | **red or meaningless** — two of three are no longer drawn. It becomes the open tab's geometry, plus the tab strip and the button |
| `net_circle._hit_tests_match_the_drawing` | `item_at(center of every cell)` returns that cell | **must grow a hidden-tab case.** Without it the tab is untested by the one check written for this failure |
| `net_circle._owns_rune_gates_can_pick_on_an_untreed_window` | veiled → grant → pickable, on one live window | **survives in shape**, but "veiled" becomes "absent"; the transition it measures is the valuable part and must be kept |
| `net_circle._refusing_a_veiled_rune_then_clicking_the_seat_does_not_disarm` | clicking a veiled rune then the seat does not disarm | **the premise changes** — a hidden rune cannot be clicked at all. The disarm path itself must stay measured |
| `net_pick._no_pushed_out_glyph_is_stashed_anywhere` | no public top-level collection in `src/` | red on any new ownership collection until allowlisted, **deliberately** |
| `net_research` | the bench's three purchases | unaffected if the feature stays and only the door closes. **Confirm** |

**`net_circle` holds 81 references to the palette across 49 checks.** This is the most net-dense file in the
repo for a reason, and none of the above is a mechanical rename.

**Every new check gets inverted, and the inversion has to bite the *check*, not only the code** (CLAUDE.md).
The specific trap here: a tab check that only counts drawn sections passes while the **hit test** still
answers for hidden tabs — that is the shipped-carrying-its-own-defect shape.

### 찰칵 has no infrastructure at all

Measured, not assumed: **0** audio files of any format in the repo, **0** `AudioStream`/`AudioServer`
references in any `.gd` or `.tscn`. `design/game-feel.md` lists "**No sound anywhere**" as a standing gap and
`design/attack-rhythm.md` counts sound among its six axes with the same note.

⇒ If 찰칵 is a **sound**, this feature is the one that introduces audio to the project: an asset, an import,
a bus, a player node, a volume, and a decision about whether nets can observe it headless. **If it is
motion**, it costs a handful of frames in a window that already redraws every frame. **The user has not
said which.**

### Cost checklist (the game-planning table)

Nothing here dries up over time, keeps a region awake, moves at 20Hz, spawns projectiles, or adds a material.
**The one row that applies is "full-screen effect": render cost is not measurable headless.** The 완성 glow
is one window-sized flash, so this is a look, not a budget.

### What is cheap and what is not

- **Cheap**: the tab strip and 완성 (drawn rects + `has_point`, two shipped precedents) · the 진 tab default
  · the empty start (two constants and a comment) · 「준비중」 (one branch)
- **Not cheap**: the ownership question for glyphs (**it has no field to read and it argues with a decision
  doc**) · the net rewrite in `net_circle` · sound, if that is what 찰칵 means
- **Unknown until the user looks**: every pixel

---

## Acceptance

**Write what was seen by eye under this section immediately** (CLAUDE.md).

1. **A fresh run cannot fire.** No circle, no rune, left-click does nothing, and the staff tip reads dead
2. **Tab opens the window on the 진 tab**, with 룬 and 문양 closed
3. **Only one kind's cells are on screen at a time**, and pressing a closed tab's former area does nothing
4. **Nothing you do not have has a cell.** Not a dimmed cell — no cell
5. **문양 opens on "현재 문양이 없습니다"**
6. **Pressing 일반진 in the palette seats it immediately** — no second click
7. **Pressing 무속성 룬 seats it in the middle immediately**
8. **Every insert reads as a 찰칵** — the same feedback for all three kinds
9. **The rune reads clearly bigger than it does today**, and the rune and the two layer seats have visibly
   moved outward
10. **There is no `+` on an empty layer**
11. **「마법진 완성」 makes the circle glow once and closes the window** — and **firing works identically
    whether it was pressed or the window was closed with Tab**
12. **The onboarding runs once**: arrow at Tab → 진 → auto to 룬 → auto to 문양 → 완성 → out
13. **Tabs do not auto-advance outside onboarding**
14. **You can fire before leaving**
15. **In town, 연구대 says 「준비중」**
16. **삼각 circle still works** — three rune sockets still take pick-then-place, not one-click

---

## TBD

**Do not force these full. A spec that pretends to know produces a fake implementation.**

### Ownership for circles

- **Is 삼각 in the palette at boot?** "일반진과 무속성 룬은 이미 가지고 있고" says nothing about 삼각, and
  **nothing in the repo tracks owning a circle** (`CircleDefs.ALL` is `[ROUND, TRIANGLE]`, unconditional).
  If 삼각 is not owned, a circle-ownership field is needed and `no-inventory`'s bound comes up again

### Every screen value

- **How much bigger is the rune** (`CIRCLE_RUNE_RATIO` is 0.17 today)
- **How far outward is "한 칸"** for the rune seat and the two layer seats — and **whether it is an offset on
  `seat` or a change to `CIRCLE_RING_ZONE`** (0.80 today), which are different pictures
- **Tab strip height, label size, open/closed colors**
- **The 완성 button's rect, label size, colors**, and whether it sits inside the palette page or in the
  window's own band below both pages
- **What replaces the `+`** on an empty layer — the faint ring alone (`SLOT_EMPTY`, 1.5px), a donut outline,
  or nothing at all
- **The "현재 문양이 없습니다" text size and where it sits**

### The 찰칵 and the glow

- **Sound or motion or both.** If sound: the repo has none and this feature introduces the whole axis
- **How many frames**, and what moves — a scale pop, a ring flash, a snap-in from the palette cell
- **The 완성 glow** — how long, what color, and **whether the window closes during it or after it**

### The tab's memory

- **Does closing and reopening the window return to 진, or stay where it was?** "조립창을 처음 열면 진 탭"
  is stated for the first open only. `toggle()` already clears the pick on close; whether it clears the tab
  is the same question and is not answered

### Onboarding's shape

- **Where does "onboarding is running" live** — `Progress` (run-scoped, survives a stage transition, dies on
  `reset()`), the shell (`stage.gd`, dies on `R`), or something permanent (never runs again after the first
  time, which needs storage this game does not have)
- **Does it run again after `R`, or after dying and returning to town?**
- **What the arrow points at.** **Tab is a key, not a thing on screen.** The candidates are the HUD's key
  line (`stage.gd` already writes `"A/D 이동 · Space 점프 · 좌클릭 발사 · F 상호작용 · Tab 조립창 · …"`), a
  drawn key cap somewhere on the HUD, or the screen edge the window will come from. **Nothing to point at is
  the actual problem**, and it is not a drawing question
- **What the arrow looks like**, where it anchors, and whether it animates
- **Is it skippable / can it be dismissed?** And **what happens if the player simply never opens the
  window** and walks into the trash mobs unable to fire — nothing gates the exit, so this is reachable
- **Is 「준비중」 permanent or onboarding-only?** — see "Interaction with what exists" for what it costs each
  way. If permanent, `design/town.md` and `design/README.md`'s town row both go stale in the same change
- **What the 연구대 message actually reads** — "준비중" alone, or a fuller line in the town's HUD band
  (`_town_message` is the existing seat)

### Left open by the reading of this doc itself

- **Does the tab strip live inside the palette page or in the window band above both pages?** "오른쪽 페이지
  위쪽" reads either way, and the two differ in the `draw_set_transform` question above **and** in whether the
  left page's magic circle loses height to it. Same question, separately, for the 완성 button
- **How the empty start is expressed, and what happens to the two constants.** `set_circle(CIRCLE_NONE)`
  resizes `_layers` and `_runes` to 0, which is the empty state — but `DEFAULT_CIRCLE` and `DEFAULT_RUNE`
  feed `apply_preset` too (debug keys 1–6, and stage D of `rune-lock-and-receiving` deliberately routes the
  preset's rune through `DEFAULT_RUNE`). **Point them at nothing and the debug keys stop restoring a
  fireable circle** — which is the one thing `apply_preset`'s own comment says they exist for. Whether the
  constants stay and only `_init` stops calling them, or move, is unstated
- **Where the tab index lives.** `palette_layout` is a static coordinate file with no state; `circle_window`
  holds `_picked_kind`/`_picked_item` already. The tab is state, and the coordinate functions need it as an
  **argument** — but nothing here says which object owns it
- **Whether a closed tab's kind can still be placed by a debug key or a preset.** `apply_preset` writes the
  circle, rune and glyphs at once regardless of any tab — presumably fine, but unstated
- **What happens if the player removes the circle after onboarding.** `_slot_count(KIND_RUNE)` goes to 0, so
  every rune becomes unplaceable — **dimmed, not hidden**, under §2's split. Confirm that is the intent: the
  player would see a rune they own that nothing accepts, which is exactly the state `_can_pick`'s dim was
  built for, but it now sits next to a rule that says invisible means "not yours"

---

## Implementation plan

**Eight stages. Each one is verified before the next starts.** Stage 5 touches no file any other stage
touches and can run in parallel with 1–4.

**Read this first**: everything under "Screen values below are defaults" is a number to put in and move
later. Nothing in this section decides a pixel.

### What was found while reading the code, that the doc above does not say

Four things change the plan, and each is measured, not inferred.

1. **`_town_message` is behind F3.** `stage._update_hud()` sets `_hud.visible = _input.debug_on() and …`,
   and `_debug_on` is false at boot. The 연구대's 「준비중」 cannot land in `_town_message` — the player
   would never see it. **The visible seat is `town_view._draw()`'s prompt line** (`Fx.TOWN_PROMPT_FMT %
   name`, drawn over the fixture the player is standing at), which is on screen unconditionally.
2. **The 문양 tab as specified cannot move a glyph, and can duplicate one.** `_can_pick(KIND_GLYPH, g)`
   asks `_slot_accepts`, which requires an **empty** layer *and* `can_place_glyph`. A seated
   `max_per_circle: 1` glyph (all three spread ids, all three blast ids) fails `can_place_glyph` against
   its own family the moment it is re-offered ⇒ **every such cell is dimmed and the reorder is
   impossible**. A `max_per_circle: 0` glyph (the three dummies) *is* pickable ⇒ placing it on the empty
   layer leaves the original in place and the player now holds **two**. Both faces are the same missing
   idea: a seated glyph must be **moved**, never re-placed. See Stage 8 — it is the one blocked stage.
3. **`net_circle` pins `palette_layout`'s two signatures as literal text** (`:653`, `:655`):
   `func section(page_size: Vector2, kind_index: int) -> Rect2` and
   `func item_at(page_size: Vector2, p: Vector2) -> Dictionary`. Those two lines move with Stage 1 and
   Stage 2. `:657`–`:658` also forbid `Fx.WINDOW_` and any reference to `book_layout` inside that file —
   **every new constant is `Fx.PALETTE_*`**, never `Fx.WINDOW_*`.
4. **Growing the rune very likely flips a pinned assertion, and it must be re-measured rather than
   deleted.** `net_circle._hit_tests_match_the_drawing:1010-1014` asserts a glyph seat lands **inside** the
   rune's hit circle ("그래서 순서가 계약이다"). With the Stage 5 defaults below, layer 1's seat sits at
   **84.0** and `rune_hit + glyph_radius` is **81.6** ⇒ that assertion goes **false**. That is not a
   regression; it is the overlap the doc's own Screen section says "changes, in the direction of getting
   better". **Re-derive the number and rewrite the sentence — do not force the old answer back**
   (CLAUDE.md: re-measure the whole table, not the row being argued about).

### Decisions taken here, so builder is not guessing

These close five of the doc's TBDs. Each is the cheap option and each is one line to reverse.

| Question (TBD) | Taken | Why this one |
|---|---|---|
| Tab strip inside the palette page, or in the window band? | **Inside the palette page** | One transform, one `pal.position` to subtract, already written in `_gui_input`. The left page keeps its full height. `net_circle:690-694` counts `draw_set_transform` set/reset pairs — **a third transform must not appear** |
| 완성 button — same question | **Inside the palette page, bottom band** | Same reason. "아래에" reads as the bottom of the right page |
| Where the tab index lives | **`circle_window._open_tab: int`**, index into `Palette.KINDS` | Beside `_picked_kind`. `palette_layout` stays stateless and takes it as an argument. An `int`, not a collection, so `net_pick`'s stash scan is untouched |
| Does the tab survive closing the window? | **No — `toggle()` resets it to 진**, beside the existing `_clear_pick()` | "조립창을 처음 열면 진 탭"; one line either way |
| Where onboarding state lives | **`stage.gd`** (the shell), so it dies on `R` and runs again | CLAUDE.md: `src/stage/` is the shell and "will not survive into the real game". A first slice of a tutorial is exactly that. **Flagged to the user** — "does it run again after R" is theirs |

### Screen values below are defaults

Put them in, look at them, move them. **None is decided.** They exist so no stage stalls on a number.

```
PALETTE_TAB_BAND_PX      26.0     PALETTE_DONE_BAND_PX     40.0
PALETTE_TAB_GAP_PX        4.0     PALETTE_DONE_TEXT        "마법진 완성"
PALETTE_TAB_SIZE           14     PALETTE_DONE_SIZE          14
PALETTE_EMPTY_TEXT       "현재 문양이 없습니다"            PALETTE_EMPTY_SIZE  14
CIRCLE_RUNE_RATIO   0.17 -> 0.26  CIRCLE_RING_ZONE   0.80 -> 0.88
CIRCLE_RING_GAP_FRAC     0.06     (new — see Stage 5)
CLICK_FRAMES               10     DONE_GLOW_FRAMES           18
```

With those, the open tab's item row is **~212px** tall against today's 68.67 — the 3× the 문양 row needs.

---

### Stage 1 — the tab strip and the 완성 band exist, and one kind is open

**The single largest geometry change. Nothing about ownership or clicking moves yet.**

The tab strip *and* the 완성 button rect both land in this stage even though 완성's behaviour is later,
because **both eat vertical budget out of `section()`**. Land them separately and the palette geometry is
rewritten twice and `net_circle._palette_geometry_runs` with it.

| File | What |
|---|---|
| `src/view/fx_tuning.gd` | the `PALETTE_TAB_*` · `PALETTE_DONE_*` block above, plus open/closed tab colors |
| `src/view/palette_layout.gd` | `tabs()` · `tab_at()` · `done_rect()`; `section()` loses its index; `item_at()` gains the open tab |
| `src/view/circle_window.gd` | `_open_tab`; `_draw_palette` draws strip + one section + 완성; `_click_palette` routes tab → 완성 → item |
| `tests/nets/net_circle.gd` | the four checks named below |

**New shape in `palette_layout`:**

```
tabs(page_size)            -> Array[Rect2]   one per KINDS entry, across the top of the page
tab_at(page_size, p)       -> int            index into KINDS, -1 if not on the strip
section(page_size)         -> Rect2          the one open tab's body. No index — the rect does not
                                             depend on which tab is open, only its contents do
done_rect(page_size)       -> Rect2          the bottom band
item_slot(sec, i, n)                         unchanged
item_at(page_size, p, open_tab) -> Dictionary
```

`section()` dropping its argument rather than ignoring it is the point: an argument a function does not
read is a false knob. **`item_at` walks only `KINDS[open_tab]`** — a closed tab's coordinates must return
`{}`, not merely go undrawn. That is the whole feature and it is where it silently fails.

`_click_palette` order: `tab_at` first, then `done_rect`, then `item_at`. 완성 closes the window
(`toggle()`); the glow is Stage 6.

**Order inside the stage**: `fx_tuning` → `palette_layout` → `circle_window` → nets. `section()`'s
signature change breaks four call sites in `src/` and about twelve in `net_circle` — that count is the
whole blast radius, it was counted, not sampled.

**Nets.** Cut recording hooks; do not count `_draw()`.

- `_draw_palette_tab(rect, kind, is_open)` · `_draw_palette_done(rect, font)` — new named seats in
  `circle_window`, one call each. A recording subclass (the file already has `_RecordingCircleWindow`)
  captures the arguments. **Assert the captured rect equals `Palette.tabs(size)[i]` / `done_rect(size)`** —
  the `settlement_layout.notice_rect` lesson: a pure function asserted alone let `_draw()` hand it a bare
  `Rect2()` under 320 green checks
- Capture the `sec` handed to `_draw_palette_section` and assert it equals `Palette.section(size)`, for the
  same reason
- **Exactly one section is drawn, and exactly `KINDS.size()` tabs** — with exactly one carrying `is_open`
- **The hidden-tab hit test, both directions.** For every kind: compute every cell center with that tab
  open, assert `item_at(size, p, that_tab)` returns the cell, then assert `item_at(size, p, other_tab)`
  returns `{}`. One direction alone is the "drawing got a tab, the hit test did not" defect the doc names
- `_palette_geometry_runs` becomes: the strip, the open section and the 완성 band are inside the page,
  mutually non-overlapping, and the section still clears the title band by `RECT_EPS`
- `net_circle:653`/`:655`'s pinned signature strings move to the new ones. `:657`/`:658` stay as they are —
  and the new constants must not break them
- **Invert the check, not only the code**: write a case where `item_at` ignores `open_tab` and confirm the
  hidden-tab assertion goes red

**Acceptance**: open the window → three tabs across the top of the right page, 진 open, 룬/문양 drawn
closed and empty; clicking a closed tab opens it and closes the other two; clicking where a closed tab's
cells used to be does nothing; 「마법진 완성」 sits at the bottom and closes the window.

**Out of scope**: ownership, one-click, the glow, the circle picture.

---

### Stage 2 — what you do not have has no cell

| File | What |
|---|---|
| `src/view/palette_layout.gd` | `items_of` gains the live state; `item_at` threads it |
| `src/view/circle_window.gd` | passes `_progress`/`_circle` in; `_slot_accepts` loses the rune gate; the empty note |
| `src/actor/progress.gd` | `owns_circle()` **only if 삼각 is not owned at boot** — see Blockers |
| `tests/nets/net_circle.gd` | `_palette_is_kind_by_item` is rewritten; new drawn-cell checks |

```
items_of(kind, pr, circle) -> Array[int]
  KIND_CIRCLE  CircleDefs.ALL filtered by ownership          <- BLOCKED, see below
  KIND_RUNE    Tuning.ELEM_ALL filtered by pr.owns_rune()
  KIND_GLYPH   circle.glyph_list()   -- the seated glyphs, in layer order
item_at(page_size, p, open_tab, pr, circle) -> Dictionary
```

`palette_layout` gains two preloads (`progress.gd`, `spell_circle.gd`). No cycle — neither reaches
`src/view/`. It already preloads three sim tables; knowing the live state is a different axis from knowing
the page, and the page ban (`:657`/`:658`) is untouched.

**The rune gate moves out of `_slot_accepts` and into `items_of`.** `_can_pick` keeps its second job
verbatim: `PALETTE_BLOCKED_VEIL_A` still dims "you own it but nothing takes it right now". Fold the two
and placing spread makes spread vanish — the decision doc's own worked example.

**문양 empty ⇒ `_draw_palette_empty_note(rect, font)`**, a named seat, not a bare `draw_string` inside the
loop. It is what a net asserts the argument of.

**Nets.**

- `_palette_is_kind_by_item` stops asserting `items_of(KIND_RUNE) == ELEM_ALL`. It becomes: **fresh
  `Progress` ⇒ runes are exactly `{ELEM_NONE}`; `grant_rune(FIRE)` on the same object ⇒ fire appears** —
  the transition, on one instance, the same shape
  `_owns_rune_gates_can_pick_on_an_untreed_window` already holds. Water stays the negative control
- **`_draw_palette_item` is never called for an unowned item.** Drive a real `_draw()` (treed +
  `pump_frames`) with the 룬 tab open and assert the recorded item ids equal `items_of`'s answer — not a
  count. A count passes when the wrong three are drawn
- **`item_at` returns `{}` at an unowned item's former coordinates**, and the owned items **re-flow** — cell
  0 of the 룬 tab is `ELEM_NONE` on a fresh boot, not a gap where fire used to be
- **The placed-spread case, by value**: place spread, confirm `items_of(KIND_GLYPH)` still contains it and
  `_can_pick` is false ⇒ **dimmed, present**. This is the check that proves the two questions did not get
  folded
- `_refusing_a_veiled_rune_then_clicking_the_seat_does_not_disarm`: its premise ("click the veiled fire in
  the palette") is now unreachable — **a hidden rune has no coordinates.** Keep the disarm half and rewrite
  the first half as "click where fire's cell would be, nothing is picked". The disarm path itself is the
  valuable part and must stay driven through `_click_palette`/`_click_circle`
- `_draw_palette_empty_note` is called with `Palette.section(size)`-derived geometry, and **only** when the
  circle has no glyphs — assert both branches

**Acceptance**: fresh run, 룬 tab shows one cell (무속성); 문양 tab shows the empty line; grant fire and a
second rune cell appears with no restart; place spread and it stays visible but dimmed.

---

### Stage 3 — the run starts with an empty circle

| File | What |
|---|---|
| `src/actor/spell_circle.gd` | `_init` stops filling; **the comment arguing the opposite is edited, not left** |
| `tests/nets/` | four files' premises move |

`_init` becomes `set_circle(CIRCLE_NONE)` — `_layers` and `_runes` both resize to 0, which is the empty
state. **`DEFAULT_CIRCLE` and `DEFAULT_RUNE` stay** and keep their names: `apply_preset` (debug keys 1–6,
`stage._set_loadout`) is their real consumer and it exists so a player who removed the circle "is not
trapped". Point them at nothing and the debug keys go dead on the first frame — which is the one thing
`apply_preset`'s own comment says they are for.

**The comment edit is not optional.** `_init` currently reads "Boot with an empty rune and the game starts
in a 'cannot fire' state, and that reads as a malfunction." Leave it and the next session reverts the boot
state. Same for `progress.gd`'s two references to it, which are about the *seat*, not the *kit*, and stay
true — check, do not assume.

**Reference count, counted before reading, not `head`-truncated: 61 matching lines** for
`DEFAULT_RUNE|DEFAULT_CIRCLE` across `.gd` and `.md`. In code: `stage.gd` ×7, `spell_circle.gd` ×4,
`progress.gd` ×4 (all comments). In nets: `net_circle` ×12, `net_render` ×2, `net_staff` ×2. The remaining
32 are docs, and `plans/3.done/rune-lock-and-receiving.md` holds 9 of them.

**Nets that move.**

| Where | Today | After |
|---|---|---|
| `net_circle._presets_still_work` | `SpellCircle.new().circle_id() == DEFAULT_CIRCLE`, `rune_at(0) == DEFAULT_RUNE` | **inverted**: a fresh circle is `CIRCLE_NONE`, `layer_count()`/`rune_count()` are 0, `can_fire()` is false |
| `net_circle._set_loadout_preserves_the_equipped_circle` | preset restores a removed circle | **keep exactly** — it is now the *only* path back to fireable, so it matters more |
| `net_circle._refusing_a_veiled_rune_then_clicking_the_seat_does_not_disarm` | `t.ok(c.can_fire(), "시작 상태는 쏠 수 있다 (전제)")` | the check must **place a circle and rune first**, then measure the disarm |
| `net_staff:217-218` | already places circle+rune by hand | unaffected — confirm by running |
| `net_render:1188`, `:1251` | preset/loadout ownership | unaffected — confirm by running |

**A new check this stage owns**: **the debug keys still restore a fireable circle from empty.** Drive
`stage._set_loadout` (or `apply_preset` directly) on a fresh `SpellCircle` and assert `can_fire()` goes
true. Without it, "the empty start" and "the presets" quietly stop agreeing.

**Acceptance**: fresh run — no circle drawn, staff tip grey, left click does nothing, no error in stderr;
press 1 and it fires again.

**Risk**: `stage._fire_at` and `Aim.fire_cmd` on a circle with 0 rune slots. `element()` already guards
`_runes.is_empty()`, `can_fire()` already returns false on `CIRCLE_NONE`, and `shots()` is only reached
past `can_fire()` — **confirm that last link by driving a left click on an empty circle**, do not assume it.

---

### Stage 4 — one click inserts, when there is only one seat

| File | What |
|---|---|
| `src/view/circle_window.gd` | `_click_palette` inserts instead of picking when `_slot_count(kind) == 1` |

**The rule is "how many seats does this kind have"**, read from `_slot_count(kind)` — the function that
already answers it. Write it as `if kind == KIND_CIRCLE or kind == KIND_RUNE` and the 삼각 circle's three
rune sockets silently collapse to socket 0 with sockets 1 and 2 unreachable.

`_click_palette`, after `_can_pick` passes:

```
if _slot_count(kind) == 1:  put(kind, 0, item);  _clear_pick();  click_fx();  return
else:                       (today's pick/unpick toggle)
```

The `put` must be the **same three callables `_click_circle` builds** — extract them into one
`_put(kind, slot, value)` so "what placing means" stays in one place. Two copies is how
`set_circle`-clears-the-layers stops happening on one path only.

**The removal path is untouched.** `_place_or_clear`'s "nothing picked → clear" branch and its
`Tuning.ELEM_NONE` (not `RUNE_EMPTY`) clear value stay exactly as they are. One-click means the hand is
always empty, so **every rune-seat click now takes the clear branch** — a mis-click on the rune seat is an
instant disarm-to-무속성 with no undo. That is a consequence, not a bug, and it is on the flag list.

**Nets.** Drive `_click_palette` on an untreed window (`net_pick`'s technique, already used at
`net_circle:829`).

- 진: one click ⇒ `circle_id()` changed, `_picked_kind == -1`
- 룬 on a round circle: one click ⇒ `rune_at(0)` changed, hand empty
- **삼각 negative control**: equip 삼각 (3 rune sockets) ⇒ one click **picks**, does not insert; then a
  socket click places it. `_slot_count` is 3, so this is the check that catches a kind-keyed rule
- 문양 (2 or 3 layers) ⇒ still pick-then-place
- The disarm path still measured, unchanged

**Acceptance**: 6 and 7 from the doc's list, plus 16 (삼각 still takes pick-then-place).

---

### Stage 5 — the circle picture: bigger rune, seats outward, no `+`

**Independent of stages 1–4.** Different files except `circle_window._draw_empty_slot`. Can be built in
parallel by a second builder; if it is, it lands on `fx_tuning` and `circle_layout` only and merges
cleanly.

| File | What |
|---|---|
| `src/view/fx_tuning.gd` | `CIRCLE_RUNE_RATIO` up, `CIRCLE_RING_ZONE` up, `CIRCLE_RING_GAP_FRAC` new, `SLOT_PLUS_*` deleted |
| `src/view/circle_layout.gd` | `layer_bands()`'s `PIC_ROUND` branch grows an inner hole |
| `src/view/circle_window.gd` | `_draw_empty_slot` loses the plus; its comment is rewritten |
| `tests/nets/net_circle.gd` | the pinned numbers are regenerated; the overlap sentence is re-measured |

**"한 칸씩 바깥으로" is read as one derived rule, not three tuned numbers.** The round rune sits dead
centre, so "move the rune outward" has no direction — what the picture actually needs is the **rings
starting outside the grown rune** instead of on top of it. So:

```
PIC_ROUND, layer_bands():
  hole  = rune_radius(id, area) + _radius(area) * CIRCLE_RING_GAP_FRAC
  outer = hole + (zone - hole) * (i + 1) / n        # was: zone * (i + 1) / n
```

One formula. Grow the rune and **both** layer seats move outward on their own; there is no second number to
keep in step. That is the "if you add an axis, does every consumer follow" test passing by construction.

**`PIC_TRIANGLE` is untouched** — `rune_radius()` and `layer_bands()` both branch on it first and read
`TRI_*`. Confirmed in code, not assumed.

**The `+` goes.** `_draw_empty_slot` keeps only the faint ring, moved into `_draw_slot_ring(at, r)` so a
recording subclass can assert it still paints. `SLOT_PLUS_RATIO`/`SLOT_PLUS_PX` are **deleted**, not left
orphaned. That function's comment argues *for* the plus ("Draw only the ring and it reads as 'a seat' and
'you can place here' does not read") — **rewrite it**, per the doc's own instruction. A comment arguing
against shipped behaviour is worse than none.

**Nets.**

- `_round_numbers_pinned_before_the_triangle_arrives` — **regenerate every literal**, which is exactly what
  its own header authorises ("only if … one of the round circle's own ratios changes on purpose"). Print
  the values, do not hand-compute them
- `_hit_tests_match_the_drawing`'s cross-kind block — **re-measure both directions.** `gap >= rune_draw`
  survives at the defaults (55.0 ≥ 36.4 for layer 1). The `inside` assertion at `:1010-1014` is expected to
  **flip false** (84.0 vs 81.6). If it does, the ordering contract's premise is gone: keep the
  `layer_at` → `rune_slot_at` → `frame_has_point` order check (it is still correct and still cheap) and
  rewrite the "그래서 순서가 계약이다" sentence to record that the seats now clear the rune. **Do not adjust a
  ratio to make the old sentence true again**
- `_triangle_hit_shapes_stay_disjoint` — must stay green untouched. It is the proof the triangle did not
  move
- A new check: **the empty seat still paints.** `_draw_slot_ring` is called once per empty layer, with
  `Layout.glyph_radius(area)`, at the band's own `seat`
- **Invert**: set `CIRCLE_RING_GAP_FRAC` to 0 and confirm the geometry checks move. If nothing moves, the
  constant is not wired in

**Acceptance**: 9 and 10 from the doc's list. **This is the stage the user judges by eye** — expect the
three constants to move afterwards, and expect the pinned numbers to be regenerated a second time.

---

### Stage 6 — 찰칵, and the 완성 glow

**Blocked on one question — sound or motion.** See Blockers. Everything below assumes **motion only**.

| File | What |
|---|---|
| `src/view/fx_tuning.gd` | `CLICK_FRAMES` · `DONE_GLOW_FRAMES` and their colours |
| `src/view/circle_window.gd` | `_click_frames` · `_click_seat` · `_glow_frames`, ticked in `_process` |

The window already `queue_redraw()`s every frame while visible, so this is **frame-counted, not
tick-counted** — the 60Hz/20Hz trap does not reach it. A counter down from `CLICK_FRAMES`, read by a
`_draw_click_fx(at, r, t)` seat that a net records.

**One 찰칵 function, called from `_put`** — not one per kind. Three copies is how "runes click and circles
do not" ships silently.

**완성 glow**: `_draw_done_glow(rect, t)`, and the window closes **after** the glow (the doc leaves
during-vs-after open; after is the one that is visible at all). Guard: while glowing, the window is still
`visible` and still eats clicks — confirm that does not read as "it did not close".

**Nets.** Drive it treed with `pump_frames`. Assert `_draw_click_fx` is called with a **falling** `t` and
stops; assert the seat argument equals the seat that was actually filled. **A pure counter asserted alone
is the `notice_rect` hole again** — capture the argument at the hook.

**Acceptance**: 8 and 11. Firing must work identically whether 완성 was pressed or Tab closed the window —
that is a value check (`can_fire()` and `shots()`), not a look.

---

### Stage 7 — onboarding

| File | What |
|---|---|
| `src/stage/stage.gd` | `_onboard_step: int`, advanced by the window; the 연구대 door |
| `src/stage/stage.tscn` + `src/view/onboard_view.gd` | the arrow, a `Control` under `HUD` |
| `src/view/town_view.gd` | 연구대's prompt reads 「준비중」 |
| `src/view/circle_window.gd` | `set_onboarding(bool)` — auto-advance the tab, **only while true** |

**Beat 0 — 연구대.** `town_view._draw()`'s prompt line for `Fixtures.KIND_RESEARCH` draws 「준비중」
instead of `TOWN_PROMPT_FMT`. `stage._interact()`'s `KIND_RESEARCH` branch stops calling
`_toggle_research()`. **`Progress.buy()`, `UnlockDefs`, `research_window.gd`, `research_layout.gd` and
`net_research` all stay untouched** — only the door closes, and `net_research` must stay green with no
edit. If it goes red, the door was not the only thing that moved.

**The arrow has nothing to point at, and that is the real problem.** The HUD key line
(`"… Tab 조립창 …"`) is behind F3, so it is not a target. ⇒ **`onboard_view` draws its own 「Tab」 key cap
plus an arrow**, seated by an `onboard_layout.gd` function. Default seat: bottom-centre, above the HUD
band. A drawn thing, `mouse_filter` untouched, **not full-screen** and not a `Button`.

**Auto-advance is onboarding-only.** `circle_window` holds a `_onboarding: bool` set by the shell; the
tab advances after a successful insert **only while it is true**. Outside it, pressing 일반진 seats it and
the 진 tab stays open. That flag is the entire difference and it must be one branch, in one place.

**The step machine, five states, in `stage.gd`**: `ARROW → CIRCLE → RUNE → GLYPH → DONE → OFF`. Advanced by
what the player did, never by a timer. Nothing gates the exit and nothing blocks firing.

**Nets.**

- **The `_wired_root` trap.** `net_gate._wired_root` pre-sets `@onready` fields by hand, so adding
  `_onboard_view` there and forgetting the `$HUD/OnboardView` line in `stage.gd` stays green while the
  screen shows nothing. ⇒ **Null the field back out, call `_ready()`, and assert it is non-null again.**
  Same for the `setup()` call if the node needs one
- **The arrow is actually painted**: `_draw_onboard_arrow(rect)` recorded, argument compared to
  `OnboardLayout`'s own answer. "`_draw()` ran" is not "anything was drawn"
- **`visible` is actually set.** This repo shipped a settlement panel that never set it, under 5,576 green
  checks. Assert `visible` by value at each step
- The tab does **not** auto-advance with `_onboarding` false — the inversion of the feature
- 연구대: `_interact()` in town at the research seat leaves `_research_window.visible` false, and
  `town_view`'s prompt text for that kind is 「준비중」 (drive `_draw()`, capture the string)
- **`net_citations`**: no code comment may write a `docs/plans/[0-9]…` path. Name the doc

**Acceptance**: 12, 13, 14, 15.

---

### Stage 8 — the 문양 tab reorders 1층 ↔ 2층 — **BLOCKED**

Do not start this without an answer. As specified it cannot work (finding 2 above): a seated
`max_per_circle: 1` glyph is un-pickable and a seated unlimited one **duplicates**.

**The shape that works**, and the one to confirm: a new `SpellCircle.move_glyph(from, to)` — the glyph
never leaves the circle, so `no-inventory.md` is not touched and nothing can be lost by closing the window
mid-move. `_place_or_clear` grows a third case (picked-from-the-circle), and `_can_pick` for a seated glyph
asks "is there another layer it could move to", not "is there an empty layer that would accept a copy".

Everything in Stages 1–7 ships without this. Until it lands the 문양 tab is a **read-only view** of what is
seated — every cell dimmed, nothing clickable — which is honest and satisfies acceptance 5, and is not the
"pressable and nothing happens" the design warns about.

---

### Risk

Checked against CLAUDE.md's fake-code list and this repo's own recorded failures.

| # | Risk | Where it bites | Guard |
|---|---|---|---|
| 1 | **Drawing and clicking read different coordinates** — the palette's own headline failure, raises nothing | the tab index reaching `_draw_palette` and not `item_at` | Stage 1's two-direction hidden-tab check |
| 2 | **A third `draw_set_transform`** breaks the set/reset pairing net (`net_circle:690-694`) | the strip drawn outside the palette page | Everything inside the palette page's transform; one `pal.position` subtraction, already written |
| 3 | **A `Button` node for a tab** eats Tab as `ui_focus_next` — symptom identical to a broken input map | any tab, and 완성 | Drawn rects + `has_point`, per `settlement_layout`/`pick_layout` |
| 4 | **A full-screen `Control`** kills "you can shoot with the window open" | 완성's glow, the onboarding arrow | Both stay inside their own rects. `mouse_filter` is written in the scene and is not overwritten at runtime |
| 5 | **Ownership folded into `_can_pick`** ⇒ the glyph you just placed vanishes | Stage 2 | The placed-spread check, by value |
| 6 | **One-click deletes the removal path** ⇒ a working circle drops to `can_fire() == false` | Stage 4 | The existing disarm check, kept and driven through the real click path |
| 7 | **The empty start kills the debug keys** ⇒ nobody can get back to fireable | Stage 3 | Keep both constants; new check drives `apply_preset` from empty |
| 8 | **「준비중」 lands in a line only F3 shows** | Stage 7 | It goes in `town_view`'s prompt, measured by driving `_draw()` |
| 9 | **A new class-level `Array`/`Dictionary` in `src/`** turns `net_pick` red | `Progress._owned_circles` (if 삼각 needs one); any onboarding table | Use `const` for tables; allowlist `_owned_circles` **with the argument written there**, deliberately |
| 10 | **A grep-shaped check** measures text, not the picture | every new check | Every one of them captures an argument at a hook |
| 11 | **`_wired_root` hides the shell's wiring line** | Stage 7's new node | Null the field, call `_ready()` |
| 12 | **A line-numbered doc citation in a comment** | anywhere | `net_citations` greps `src/`/`tests/`/`tools/` for `docs/plans/[0-9]` |
| 13 | **The round is 28s and `net_gate` is 24.3s of it.** `net_circle` grows here | Stages 1–2 | If the round grows for any other reason, call `harness-manager` — not a feature's job |

**Not a risk here**: the 60Hz/20Hz sampling trap. Nothing in this feature is tick-driven; the window
redraws every frame and every beat waits on a click. **It returns the moment an onboarding beat waits on a
world event** — latch the 60Hz fact and let the tick read it, and pump `TICK_DIVIDER * 2` frames, never one.

### Acceptance

The doc's own 16 items, mapped to the stage that owns each:

| Item | Stage |
|---|---|
| 1 (cannot fire fresh) | 3 |
| 2, 3 (tabs, one at a time) | 1 |
| 4 (no cell for what you lack) | 2 |
| 5 (문양 empty line) | 2 |
| 6, 7 (one click) | 4 |
| 8 (찰칵) | 6 |
| 9, 10 (rune bigger, no `+`) | 5 |
| 11 (완성 glows and closes; firing identical either way) | 6 |
| 12, 13, 14, 15 (onboarding, no auto-advance outside it, fire before leaving, 준비중) | 7 |
| 16 (삼각 still pick-then-place) | 4 |

**The reversal is only real if all three edits land** (doc's own words): `palette-hides-what-you-do-not-own.md`
exists already ✓, this doc ✓, and **the reversal note inside `plans/3.done/rune-lock-and-receiving.md`,
reaching its acceptance items 3 and 4** — not yet written. Whoever finishes Stage 2 writes it there,
because a refutation filed in the wrong doc does not propagate.

### Out of scope

- The two later onboarding beats (three-pick → 문양 tab · bull → 불 룬). One line each in this doc, and
  **whoever writes them owns the detail** — do not derive it from here
- Any change to what a circle, rune or glyph **does**
- The 연구대's real feature. The door closes; nothing is deleted
- Whether 「준비중」 is permanent, and the `design/town.md` / `design/README.md` staleness that follows if
  it is
- Sound. **If the answer to 찰칵 is "sound", that is its own feature** — an asset, an import, a bus, a
  player node, a volume, and a decision about whether nets can observe it headless

### Blockers — batched, for the user

1. **찰칵: sound or motion?** This repo has **zero** audio (measured: 0 files, 0 `AudioStream`/`AudioServer`
   references). Motion is a handful of frames in a window that already redraws every frame. Sound opens a
   whole axis. **The plan assumes motion.**
2. **Is 삼각 in the palette at boot?** Nothing in the repo tracks owning a circle. If it is owned, Stage 2
   is one line. If not, `Progress` grows `_owned_circles` and a `net_pick` allowlist entry.
3. **Stage 8 — how does a seated glyph move between layers?** As specified it cannot (finding 2). The
   proposed answer is `SpellCircle.move_glyph(from, to)`. Everything else ships without it.
4. **Does the onboarding run again after `R`?** The plan seats it in the shell, so it does. The
   alternatives die differently and none of them is free.

---

## Resolved during build (superseding the TBDs/Blockers above)

Answered by the user mid-build, after this doc was written. Recorded here rather than silently overriding
the sections above, per CLAUDE.md's "acceptance goes into the doc the moment it happens".

- **Blocker 2 — 삼각 is confirmed *not* owned at boot.** `Progress` gains `_owned_circles` (the same
  set-shaped `Dictionary` idiom as `_owned_runes`), starting kit `{CIRCLE_ROUND}`. Allowlisted in
  `net_pick._no_pushed_out_glyph_is_stashed_anywhere` with the argument written at the allowlist entry.
- **Blocker 3 — Stage 8 is approved**, `SpellCircle.move_glyph(from, to)` as specified. **Only after Stages
  1–7 ship green** — do not start it early.
- **Blocker 4 / onboarding's shape — not the shell, and not tied to `R`.** `R` stays a player key above the
  debug gate (`stage_input.gd`'s own comment: a destructible-terrain game needs an un-gated reset or a
  self-dug pit traps the player — moving it behind F3 would reintroduce a fixed bug). Onboarding-seen state
  lives in `Progress` instead: a private `bool` (`_onboarding_seen`), not cleared by `reset()` or
  `next_stage()`, the same survives-a-reset discipline `gems`/`_unlocked` already hold. It is a bare `bool`
  rather than a set — nothing to enumerate, so `net_pick`'s stash scan (which watches `Array`/`Dictionary`)
  does not need an allowlist entry for it.
