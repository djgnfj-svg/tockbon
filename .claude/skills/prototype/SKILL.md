---
name: prototype
description: Build one thing on screen three or more genuinely different ways and put them side by side, so a look is chosen by seeing rather than by argument. Use when the user says 프로토타입 / 여러 방법으로 / 여러 방면으로 / 다르게 만들어봐, or says they do not know how a thing should be built.
---

# prototype — the same thing, built differently, side by side

A **prototype** here is a throwaway implementation written to answer one question. This skill runs a
**set** of them: three or more, each getting the same result by a **different mechanism**, all
photographed from one camera so the difference on screen is the only difference in the picture.

⚠⚠ **This skill was called `spike` until 2026-08-29** (the user: *"prototype is the right name, because
that is what I call it"*). **A name the user does not reach for is not a name** — this repo learned that
when 「물가」 had to be renamed 「해안선」 for the same reason.
⚠ **There was an imported `prototype` skill and it was deleted on 2026-08-27.** This is not that one
coming back; it is this skill wearing the word the user actually uses.

## ⚠⚠ A prototype set is a different MECHANISM, not a different setting

**Two candidates that differ only by constants are a candidate sheet, and `tools/shot/shoot_water.gd`
already makes those.** A set is for when the dials have run out — when the user is turning knobs on
one implementation and the thing they want is not reachable from any setting of it.

**The test, applied to every pair in the set**: *this one gets the effect from **X**, that one gets it
from **Y**, and X and Y are different sources.* Depth buffer versus baked field is a set. Wider
band versus narrower band is not.

⚠ **This skill exists because a round was spent proving the point** (2026-08-28): four sheets of water
candidates, forty dials moved, and the user's answer was ***"아니그냥 어떻게 구현해야할지 모르겠다"***.
**Every one of those candidates was the same shader.**

## The steps

1. **Write the question down in one sentence**, and put it at the top of the sheet. Without it every
   one is judged on 「which is prettier」 and the round teaches nothing that survives it.
2. **Send `scout` before building anything.** The mechanisms worth spiking are the ones that shipped
   somewhere; inventing three from scratch is three chances to build what nobody uses. ⚠ **Skipping it
   is allowed only when the user named the mechanisms themselves, and then say out loud that it was
   skipped.**
3. **Choose three to five mechanisms that fail differently.** Two that break under the same condition
   are one prototype photographed twice.
4. **Build each as a throwaway under `prototypes/<subject>/<NN-name>/`** — one folder per subject, one
   folder per version inside it, numbered in the order they were built. ⚠ **Never in `src/`**: the folder
   rule there is what lets a net drive the game headless, and a throwaway is not going to obey it.
   ⚠ **A prototype that has to be clean is not one** — the point is to reach a picture in an hour, not
   to ship. **Each version folder carries a `NOTES.md` with the three lines below**, so the picture and
   the reason never separate. The winner is rebuilt properly afterwards; the losers are deleted.
5. **Photograph all of them from one camera, one instant, one sheet.** ⚠ **Take anything not being
   judged out of the frame**, or every picture shares a house and a swordsman and the eye lands on those.
   ⚠ **Never `--headless`**: there is no swapchain to read a frame back from and every PNG comes out
   black with no error.
6. **Report each one as three lines: what it buys · what it costs · what it CANNOT do.** The third line
   is the one that decides, and it is the one that is always missing.

**Done when every mechanism is in one sheet from the same camera, and each carries all three lines.**

## What the set costs, and who pays it

⚠⚠ **Say the cost before building.** A set is three to five implementations; it is a round, not a
reply. **The user chooses whether to spend it** — and a set of two built quietly instead is the failure
this skill is written against, because two mechanisms cannot show a spread.

## Where it lands

**The winner becomes a ticket.** The sheet goes to `docs/reference/` as `YYYY-MM-DD-<subject>-prototypes`,
and the ticket names it; **each version's three lines stay in its own `NOTES.md`** under
`prototypes/<subject>/`. ⚠ **The losers are deleted once one has won** — a throwaway left in the
tree becomes code nobody dares remove, and this repo has paid that before.
