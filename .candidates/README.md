# `.candidates/` — every 시안 ever pulled, and **NOTHING here is ever deleted**

**One subject folder per thing that gets drawn.** Every candidate picture pulled for that subject
lives in it forever — the ones that won, the ones that lost, and the ones that were replaced later.

⚠⚠ **THIS FOLDER EXISTS BECAUSE THE LOSERS KEPT BEING THROWN AWAY** (2026-08-31, the user:
*"why does it keep pulling wolves and then deleting them from assets? Let us make an English-named
folder for the 시안 and collect the images there from now on. Do not delete them."*).

**What it cost before this folder existed**: twenty-two wolf candidates, the installed nine-frame
animation board, and the walk and bite boards were all gone from the working tree. They survived
**only by accident**, baked into Godot's import cache — which is gitignored, so one cache clear would
have ended them. They were decoded back out of that cache and put here.

## ⚠⚠ **THE FOUR VIEWS EVERY BODY IS PULLED IN** (2026-08-31, the user)

***"And every image is 정면우 · 정면좌 · 후면우 · 후면좌 — four of them. Put it somewhere I can refer
to when pulling."***

**Every body in this game is drawn from four DIAGONAL views, and there is no side, front or back view.**

| 한국어 | What it is | The phrase that pulls it |
|---|---|---|
| **정면우** | facing the camera, **turned toward screen-right** | `three quarter front view, facing the camera and turned to its left` |
| **정면좌** | facing the camera, **turned toward screen-left** | `three quarter front view, facing the camera and turned to its right` |
| **후면우** | walking away, **turned toward screen-right** | `three quarter rear view from behind, turned to its left` |
| **후면좌** | walking away, **turned toward screen-left** | `three quarter rear view from behind, turned to its right` |

⚠⚠ **ITS left is the SCREEN's right.** An animal turned toward screen-right has its own left side facing
the camera, and the generator obeys the animal's own words, never the screen's. **Getting this backwards
gives four pictures that are two pairs of the same view**, which is what 「the folder has four files」
cannot catch.

## ⚠⚠ SO ONLY **TWO** IMAGES ARE EVER PULLED, AND THE OTHER TWO ARE MIRRORS

> ***"So in the end we only need two images — do you understand?"*** (2026-09-03, the user)

**정면우 mirrored horizontally IS 정면좌. 후면우 mirrored horizontally IS 후면좌.**
⇒ **Pull 정면우 and 후면우. Flip each one. That is all four facings.**

**One animation is two pulls, not four. A body is 62 images, not 124.**

⚠ **This is the whole reason the set must be diagonals.** A straight front or a straight back is its
own mirror — it has no partner — so the old compass set needs **three** uniques (정면, 정면우, 뒷면)
where the diagonal set needs **two**.

⚠ **What ships today does not do this, and it was measured.** `man/right` and `man/left` were pulled
separately: **7% to 25% of their pixels differ** from a mirror of each other (2026-09-03, over the
standing, idle, walk, attack and death frames). Nobody tried mirroring; it is not that mirroring
failed.

⚠ **Mirroring swaps which hand holds the tool.** On a flat grey body 40 px tall with no asymmetric
marking, that is invisible. **Re-check this the day a body gains a scar, a patch, or a one-sided
piece of kit.**

⚠ **Why diagonal and not the compass.** The board is isometric and it TURNS. A body walking along a grid
row is already moving diagonally on screen, so a straight side view is a pose the camera never actually
asks for — and a dead-on front view collapses the animal to its own width (the top-down lion lesson in
`tools/pixel/README.md`, one folder over).

⚠⚠ **NOTHING IN `src/` PICKS THIS WAY YET.** `field_view._facing_index` chooses **by which of the two
ground axes is bigger** — that is right for right/left/front/back and **wrong for four diagonals**, which
are told apart by **the SIGNS of both axes**. ⇒ **A four-diagonal set installed against today's picker
puts two of the four on screen and never the other two.** The picker is a code round of its own, and the
roadmap already carries it as an open question.

⚠ **What is standing today does not obey this.** The wolf's `wolf_h/` is `east · west · south · north`
and the swordsman's `man/` is `right · left · down · up` — **both are the old compass set**, and both
have to be re-pulled or re-cut before this rule is true of the game rather than only of the folder.

## The rules, and there are five

1. **Nothing is deleted.** A losing candidate is the evidence for why the winner won. ⚠ **This is the
   opposite of `.prototypes/`**, whose README says the losers are deleted — that rule stays there and
   is not copied here.
2. **A picture keeps the name it was generated under**, seed included. The seed is how the same
   picture is pulled again.
3. **One subject, one folder.** `wolf/`, `swordsman/`, `bear/` — named after the thing, not the date.
4. **Dot-prefixed on purpose.** Godot imports everything under the project root, and a few hundred
   candidate PNGs in the import cache is cost for nothing. `.prototypes/` is dot-prefixed for the same
   reason. ⚠ **It is still committed** — only `.godot/` is ignored.
5. **The four views above, and the words that pull them, are written down beside the winner.** ⚠ **A
   phrase nobody wrote down is a view that cannot be matched next time** — thirty-eight wolf candidates
   were pulled before this folder existed and **not one of their prompts survives**, only their job ids.

## What is NOT in here

- **What the game actually loads** — that is `assets/`, and a candidate is not an asset until it wins
- **The screenshots a decision was made from** — those are `docs/reference/`
- **The throwaway scenes that stand candidates up side by side** — those are `.prototypes/`
