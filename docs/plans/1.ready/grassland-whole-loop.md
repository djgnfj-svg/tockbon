# Grassland, the whole loop — the index

**Status**: `1.ready` — split into four plans on 2026-08-14. **All four are built and in `3.done`.**
⚠ **Only plan 2 has been played, and nothing has been accepted.** This doc stays in `1.ready` because it is
the index over them, not a plan anyone builds.

> ✅ **All four plans have now absorbed the second review and the design conversation that followed it**
> (both 2026-08-14, later the same day). Read them anyway before building:
> - **[The adversarial review](../../adversarial-review-2026-08-14-ko.md)** — 74 findings from five
>   independent reviewers. **Its NOT BUILDABLE verdict on plan 4 is answered**, not still open; the findings
>   are ordered by how many reviewers found them independently, and that ordering is the part worth re-reading
> - **[Hunting and the boss](../../design/hunting-and-the-boss-ko.md)** — force ×10, size per species, the
>   crow's counter-attack, herding the horse, the arena, terrain. **It is newer than every number below**
>
> ⚠ **On one point the plans are newer than the review**: it told plan 4 to slow the horse to 1.05× so the
> swarm could catch it, and the design then said the opposite — **the horse is not caught, it is herded.**
> The plan keeps 1.15× and guards the ordering with literal checks instead.

**The instruction that shapes every doc under it** (from the user): **build the biggest loop first, then dig
inward, and leave the details for last.** Not parts assembled upward. The last game's loop never ran end to
end, and the user said in as many words that not knowing *what it feels like* was the frustrating part.

**The second instruction, from the planning session on 2026-08-14**: **a plan that sends the builder back to
ask a question is not a plan.** The four docs below carry data shapes, function names, key bindings, literal
numbers and per-piece acceptance. Where something is genuinely undecided it is listed under *Still open* at
the bottom of this file — **and nothing in that list blocks a build.**

---

## The four plans, outermost first

| # | Plan | What it closes | Depends on |
|---|---|---|---|
| 1 | [The run shell](../3.done/run-shell.md) **✅ `3.done`** — **unplayed on its own** | title → play → ending → title. **A run starts and ends** | nothing |
| 2 | [Hands and commands](../3.done/hands-and-commands.md) **✅ `3.done`** — 16 nets · 514 checks, **played: keys accepted, picture not** | `F` `V` `1` `2` `3`, three active slots, `Tab` | 1 |
| 3 | [The body and its parts](../3.done/body-and-parts.md) **✅ `3.done`** — 18 nets · 889 checks, **looked at, unplayed.** Plan 4 unblocked its acceptance: a corpse now fills the card pool | eleven slots, horse parts, cards that only give parts | 2 |
| 4 | [The grassland field](../3.done/grassland-field.md) **✅ `3.done`** — 22 nets · 1889 checks, **unplayed, and the arena has no view at all** | crow · horse · boss, force on every body, the ground, the minimap | 3 |

**Build them in this order.** Each one leaves a playable build behind, and the user plays after 1 and again
after 4. Planning principle 2: planning cannot judge whether this is fun.

### What plan 1 cost, so plans 2–4 do not pay it again

**The code was small and it was right every round. The nets were what took the time.** Four new files plus a
rewritten `main.gd`; **checks went 113 → 293.** Stage 2 alone bounced **four times**, and on every bounce the
implementation was correct and the checks were shallow. **The plan named 22 checks and the build needed 293.**
The second adversarial review predicted this in as many words — *"planned checks that do not measure what
their label claims"* — and it was still under-read.

⇒ **Write each remaining plan's checks against these four questions before the builder sees them.** Every
single hole in plan 1 was one of the four:
- **Does the bound come from the thing it measures?** `t.eq(slots.size(), SLOT_COUNT)` moves both sides.
  Pin literals — the viewport is 1280×720 and the coordinates are known
- **Does it read only final state where an ordering was promised?** A beat that never pulls still ends with
  count 1
- **Does the spy assert everything it captures?** A captured-and-unread field reads exactly like coverage.
  Four buttons with blank labels passed because only `rect` was ever read
- **Can the behaviour VANISH rather than diverge?** A/B catches "changed", never "gone". A hook that threw
  its own drawing away passed 54 of 54 — the fix was cutting the terminal draw into a leaf hook so nothing
  above it can put a pixel on screen unwatched, and `net_draw_leaf` now holds that shape in place

⇒ **And book a `verify-look` pass into every plan that changes the screen.** With 279 checks green, one look
found three defects in minutes: no floor colour at all, a victory beat that was a still frame for 62% of its
length, and the game filling 44% of the window. **Numbers cannot see a picture** — this repo has now measured
that four separate times.

## What the August build is, after the 2026-08-14 narrowing

**One stage, entered bare, left with a finished body.** The scope came down hard in that session and the cut
is deliberate:

- **Two species, not six.** **Crow** and **horse**, plus the **boss**. Small animals · herd · cheetah · lion ·
  elephant are **not in the August build**
- ~~**Horse gives three parts** — legs, mane, lungs. That is the whole part table for now~~ ⚠ **Reversed
  2026-08-15** ([why](../../decisions/the-crow-gives-three-parts.md)): **the crow gives three** (날개 · 부리 ·
  발) and **the horse gives 다리 only.** 말 갈기 and 말 폐활량 stay as rows and leave both pools. The pool now
  opens off the **common** creature, so a run cannot show zero cards
- **The boss is a chimera and it walks the field from the first second.** Eating it ends the run
- **A food layer that gives no parts** — grass, plants, corpses — is in, because the opening minutes need
  something to eat

⚠ **The word "apex" is dropped.** It did not survive contact with the user. **Say boss.**

## The loop it has to close

Title → enter alone → eat crows and grass → level up → wear horse parts → force passes the boss → hunt the
boss → `V` the whole swarm → ending → title.

## Deliberately thin, and it stays thin

Six species · habitats past grassland · chimeras and mutants as a system · genes · meta unlocks · the codex ·
colour · the final boss. **Do not stop to fill these.** `CLAUDE.md`: skeleton first, flesh later.

## The six the review escalated, and the user's answers

**Four adversarial reviews on 2026-08-14 found these; the user answered all six the same day.**

1. **How an active reaches something** — **it differs per active, and the part carries its own shape and
   range.** There is no one combat verb. `Parts` gets `SHAPE` · `RANGE` · `ARC` columns, and the player
   binds whichever active to whichever key
2. **Where parts come from** — **the host's come from level-up cards only.** A finished corpse does not hand
   the host a part. **A clone still wears what it kills**, which is a different path on purpose
3. **What a corpse is worth** — **proportional to that individual's force.** `force × EXP_PER_FORCE`.
   ⚠ **That factor is 3.0, not the 1.0 written here first.** Step 0 struck the 1.0 in `stages-and-evolution`
   and in the grassland field plan and never touched this index — the same divergence re-created one folder
   over, which is the failure this file's own header is about. At 1.0 a crumb of grass pays 1.0 and there are
   500 of them respawning, so the optimal run is split-and-graze and hunting is a hobby.
   ⚠ **Say 경험치, not 세포**
4. **What stops the boss** — **nothing does, and that is allowed.** A low-level host *can* kill it by
   kiting. What it costs is that **damage equals the attacker's force in both directions**, so a level-1
   host is one touch from dead and the boss is hard to disengage from. **The wall is consequence, not a
   threshold**
5. **Alone or with six** — **alone.** `START_CLONES` is deleted outright. ⚠ **And the onboarding moved
   after this list was written**: the host opens at **force 10**, so `F` works on the first second and
   splitting *is* the tutorial ([why](../../decisions/force-starts-at-ten.md)). "The first level-up opens
   `F`" was true only while force started at 1
6. **The map felt small** — **the field stays 3840×2160**, and the **camera starts tight on the host and
   pulls back as the swarm grows.** Early on the body reads big because you are close to it; the field opens
   up as there is more to see. Adjust by feel after the first play

## The prototype is a reference, not a base

**The user's call, 2026-08-14: write it again properly.** Not a line-by-line rewrite of the design — the
loop was played and confirmed — but **the files in `src/` are not carried forward as-is.**

**What survives**: the folder contracts, the flat-array discipline, the uniform grid, the separation
correction, and every measurement written into `rules.gd`'s comments. **What does not**: the eight stat
cards, `threat`, contact-absorb, the six starting clones, the run clock. ⚠ **The dash is not on that list any
more** — plan 3 keeps it as a *part* bound to `space`, because deleting it left a key empty for a whole plan.

## Still open — none of it blocks a build

- ~~**Whether the crow gives the back part (wings).**~~ **Answered, and this line said the opposite for a
  day.** The crow gives **three** parts — 까마귀 날개 (`BACK`), 까마귀 부리 (`HEAD`) and 까마귀 발
  (`HINDLIMBS`), all three with `DROPS 1` ([why](../../decisions/the-crow-gives-three-parts.md)). The strike
  55 lines above this one already recorded the reversal; this line did not, and it is the line a next session
  opens first
- **Round length.** 5 minutes now, possibly 15. Nothing is a timer any more — the boss ends the run — so
  this is an outcome, not a setting
- **Colour, entirely** — species, field, title background. `CLAUDE.md`: decided by generating candidates and
  pointing at one, never by discussion. Every plan ships flat placeholders and says so
- Everything on `stages-and-evolution`'s own *Open* list that these four plans do not touch

## What four adversarial reviews found, so it is not re-found

**Read this before adding a plan to this folder.** The four docs were written as a fix for "implementers keep
coming back to ask questions", and the review said the plans themselves were dense but **their joints with
the existing code and docs were empty.** The shape of what was missed:

- **A deletion was counted in one file and it lived in four.** `RUN_LENGTH` and `World.over` were traced to
  `net_hunt` and were also in `hud.gd` twice — where they hold up a countdown and the result panel
- **Two nets do not go red when a file stops parsing. They VANISH**, taking their checks with them
- **A new column on a flat table has to be added to `setup`, `add_clone` and every hand-written swap.** Four
  arrays were added to the creature table and none of the three maintenance sites was named
- **Numbers stated in two documents had already diverged** — the horse's force was 3 in the design doc and
  3–4 in the plan, on the day both were written
- **A value that reads as derived (`force = base + parts`) makes the mechanic it belongs to free.** Stored
  or computed is not a style question
- **Checks that measure a shape rather than a behaviour**: "a crow never drops a part" passes because the
  crow has no row in the table, so the drop code can be deleted entirely

## Acceptance

**The user plays one grassland run start to finish** and says whether the shape works — splitting on purpose,
losing force to a clone that died out there, and the moment the horse stops being uncatchable.

**Nothing here is accepted.** Every line came out of planning conversations on 2026-08-13 and 2026-08-14.
