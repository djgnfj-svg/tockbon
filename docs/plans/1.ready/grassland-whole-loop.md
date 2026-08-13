# Grassland, the whole loop — the index

**Status**: `1.ready` — split into four plans on 2026-08-14. Nothing built.

> ⚠ **These four plans have not absorbed the second review or the design conversation that followed it
> (both 2026-08-14, later the same day).** Read before building:
> - **[The adversarial review](../../adversarial-review-2026-08-14-ko.md)** — 74 findings from five
>   independent reviewers. **Plan 4 is judged NOT BUILDABLE**; the other three are buildable only with
>   guesses. The findings are ordered by how many reviewers found them independently
> - **[Hunting and the boss](../../design/hunting-and-the-boss-ko.md)** — force ×10, size per species, the
>   crow's counter-attack, herding the horse, the arena, terrain. **It is newer than every number below**
>
> **Nothing here has been rewritten yet.** Where a plan and either of those disagree, the plan is wrong.

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
| 1 | [The run shell](run-shell.md) | title → play → ending → title. **A run starts and ends** | nothing |
| 2 | [Hands and commands](hands-and-commands.md) | `F` `V` `1` `2` `3`, three active slots, `Tab` | 1 |
| 3 | [The body and its parts](body-and-parts.md) | eleven slots, horse parts, cards that only give parts | 2 |
| 4 | [The grassland field](grassland-field.md) | crow · horse · boss chimera, force on every body, minimap | 3 |

**Build them in this order.** Each one leaves a playable build behind, and the user plays after 1 and again
after 4. Planning principle 2: planning cannot judge whether this is fun.

## What the August build is, after the 2026-08-14 narrowing

**One stage, entered bare, left with a finished body.** The scope came down hard in that session and the cut
is deliberate:

- **Two species, not six.** **Crow** (early food) and **horse** (the one species that gives parts), plus the
  **boss**. Small animals · herd · cheetah · lion · elephant are **not in the August build**
- **Horse gives three parts** — legs, mane, lungs. That is the whole part table for now
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
3. **What a corpse is worth** — **proportional to that individual's force.** `force × CELLS_PER_FORCE`,
   starting at 6
4. **What stops the boss** — **nothing does, and that is allowed.** A low-level host *can* kill it by
   kiting. What it costs is that **damage equals the attacker's force in both directions**, so a level-1
   host is one touch from dead and the boss is hard to disengage from. **The wall is consequence, not a
   threshold**
5. **Alone or with six** — **alone.** `START_CLONES` goes to 0. The first level-up opens `F`, and that is
   the onboarding
6. **The map felt small** — **the field stays 3840×2160**, and the **camera starts tight on the host and
   pulls back as the swarm grows.** Early on the body reads big because you are close to it; the field opens
   up as there is more to see. Adjust by feel after the first play

## The prototype is a reference, not a base

**The user's call, 2026-08-14: write it again properly.** Not a line-by-line rewrite of the design — the
loop was played and confirmed — but **the files in `src/` are not carried forward as-is.**

**What survives**: the folder contracts, the flat-array discipline, the uniform grid, the separation
correction, and every measurement written into `rules.gd`'s comments. **What does not**: the eight stat
cards, the dash, `threat`, contact-absorb, the six starting clones, the run clock.

## Still open — none of it blocks a build

- **Whether the crow gives the back part (wings).** The design doc has crow wings as grassland's only back
  part; the user named the crow only as early food. **Plan 4 ships the crow with no part**
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
