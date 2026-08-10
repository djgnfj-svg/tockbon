# Tutorial — the game teaches one thing, and it is the magic circle

**One line**: the player's first minutes. **The run starts with an empty circle and no way to fire**, and the
only thing the game asks for is that you open the assembly window and build one — so **assembling is taught
by being the first thing that happens**, not by a page of text.

**Implemented**: **rule #1, the assembly window.** The run starts empty, an arrow points at Tab, and the
palette walks 진 → 룬 → 문양 once, then closes on 「마법진 완성」 — built in
[../plans/3.done/onboarding-and-palette-tabs.md](../plans/3.done/onboarding-and-palette-tabs.md).
**Rules #2 and #3 (layer order, the bull's fire rune) are still unowned.**
**Accepted**: **seen on screen, repeatedly, by the user — with fixes made each time.** The 찰칵/완성
feedback's exact look was not separately called out and has no net; treat it as unconfirmed.

**A concept stays alive and never changes folders.** The two header lines are only "how much runs now" —
format per [README.md](README.md).

---

## Why this doc exists at all

**The GDD leans on a tutorial twice and the repo never had one.** `design/README.md`'s own feature table has
carried the row for a while: "**Newly named by the user** — it teaches how to use the magic circle, and the
town deliberately teaches nothing (`town.md`, 'the starting kit is handed over here'). The GDD already leans
on it twice ('the rule is taught in onboarding' — layer order, and the assembly window). **No doc, no
owner**." `planning-review-order.md` says the same from the other side: "**The tutorial has no doc and no
owner** — it is now carrying the GDD's 'the rule is taught in onboarding' as well."

This is that owner.

---

## The shape — teach by removing, not by explaining

**Nothing here is a text box.** The method is to **take the assembled circle away** and let the missing
thing be the instruction:

```
the circle starts empty  ->  you cannot fire  ->  the only affordance left is the window
```

`spell_circle._init` currently fills the circle and rune at boot, and its own comment argues that booting
unable to fire "reads as a malfunction". **The user reversed that deliberately** and confirmed it: starting
unable to fire is correct, because it is the question the tutorial is the answer to.

**The staff tip already carries the state.** It reads `Fx.DEAD_TINT` — the same grey as an empty rune seat —
so "why can I not fire" is on screen through a device that shipped long ago and needs nothing new.

---

## What gets taught, in order

The GDD names two rules that "are taught in onboarding". They are not taught at the same moment.

| # | Rule | When | Owner |
|---|---|---|---|
| 1 | **The assembly window exists and this is how you fill it** | entering stage 1, before the first monster | [../plans/3.done/onboarding-and-palette-tabs.md](../plans/3.done/onboarding-and-palette-tabs.md) — **built** |
| 2 | **A glyph goes on a layer, and the inner layer runs first** | the first level-up's three-pick | **no owner** |
| 3 | **A rune is a thing you can be given, and it changes what fires** | the bull's fire rune | **no owner** |

**#1 is built. #2 and #3 are still only named**, in that plan, as one line each precisely so nobody derives
their detail from a doc that has not thought about them.

**Layer order has two devices on screen already** and they are not new work: the layer number written beside
each ring, and a brightness ramp from inner to outer (`circle_window._draw_ring` — "A concentric circle alone
says only that an order **exists**, never **which side comes first**"). Whoever writes #2 should lean on
those rather than add a third device.

---

## Where it does not live

**The town teaches nothing, on purpose.** `design/town.md` hands over the starting kit and closes the run;
`decisions/town-is-a-mode-of-the-stage-shell.md` keeps it a mode of the same shell. Putting the lesson there
would mean the player learns the circle in the one room where nothing can shoot back and nothing is at stake.

⇒ **The lesson is in stage 1, in the quiet stretch before the first trash mob.**

**And the 연구대 is taken out of the way for it.** The research bench works — three unlocks, bought with
원석, surviving a reset (`plans/3.done/research-bench-unlocks.md`) — but the user's judgment is that it is
not worth meeting first ("연구대 지금 너무 짜쳐서 별로"), so the first pass has it say 「준비중」 and nothing
more. **The feature is closed off, not deleted.** Whether that is permanent is open — see the plan's TBD.

---

## Bounds

- **No modal text screen, no "press any key to continue" page.** Every beat is a thing the player does
- **It teaches the window, not the game.** Movement, jumping and aiming are not taught — they are the HUD
  key line's job (`stage.gd` already writes one)
- **It runs once**, and what "once" is scoped to is open (a run · a session · forever — the game has no
  persistent storage today, which rules out the third for free)
- **Nothing in it may block firing.** Firing before leaving is explicitly allowed

---

## Accepted

**Write what the user confirmed by eye here, the moment they say it** (CLAUDE.md).

Rule #1 (the assembly window, the empty start, the arrow, the tab walk) was **seen on screen repeatedly**,
with fixes made each time it was looked at. Rules #2 and #3 are still unbuilt.

---

## TBD

- **Where "onboarding is running" lives**, and whether it survives `R`, a stage transition, or a return to
  town. The plan lists the three candidate seats and their different deaths
- **Whether it can be skipped or dismissed**
- **What the pointer looks like** — the first slice says "an arrow at Tab" and nothing more
- **Rules #2 and #3 above** — named, unowned, and deliberately not sketched here
- **Whether 「준비중」 on the 연구대 is permanent.** If it is, `town.md`'s 원석 section and `README.md`'s town
  row go stale in the same change
