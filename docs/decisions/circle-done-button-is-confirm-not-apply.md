# 「마법진 완성」 confirms and closes — it is not an apply button

**Status**: valid (decided by the user)

## What was decided

The button under the palette **applies nothing.** Every click in the assembly window has already written into
the one live `SpellCircle` that the muzzle and the fire command read — the circle is armed the moment a piece
lands in a seat. Pressing 완성 makes the circle **glow once** and **closes the window**, and closing the
window any other way (Tab, ESC) leaves exactly the same circle behind.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **An "적용" button that commits the assembly** | A player who builds a circle and closes with Tab or ESC would walk out carrying **nothing**, and "I built it and it did nothing" reads as a broken game, not a missed step. The failure is silent, it happens on the player's very first assembly, and the tutorial is the one place it is guaranteed to happen |
| A **draft** circle that only merges on confirm | It duplicates the equipped state. `spell_circle.gd`'s header exists to stop exactly that: "The debug keys and the assembly window both touch **this one object.** If each held its own state you get 'I pressed the key but the muzzle did not change' and **not one error is raised**" |
| **No button at all** — Tab and ESC already close the window | The tutorial needs a place for the last beat to land, and a player who has just assembled their first circle needs to be told they are finished. A window whose only exit is the key that opened it is fine for the tenth time and wrong for the first |
| A **취소 / 되돌리기** button beside it | There is nothing to cancel — see above. It would have to invent the draft state this decision rejects |

## What's tied to it

- **The button is drawn, not a `Button` node.** `circle_window.gd`'s header: a focusable `Control` inside the
  window eats Tab as `ui_focus_next` and **the window's only key stops working**, with a symptom identical to
  a broken input map. `settlement_layout.button_rect()` and `pick_layout.decline_rect()` are the two shipped
  precedents — a rect in a `*_layout.gd`, hit-tested in `_gui_input`
- **The glow is presentation only.** If it ever gates anything — a state that is "confirmed" versus "not" —
  this decision has been reversed without anyone saying so
- **Acceptance carries it**: firing must work identically whether 완성 was pressed or the window was closed
  with Tab (`plans/3.done/onboarding-and-palette-tabs.md`, acceptance 11)

## Conditions to reopen

**A cost that makes assembly non-free** — the assembly bench's point budget (`design/town.md`'s open TBD), a
currency, or a rule that makes a mid-run swap something the player should have to commit to. A confirm step
is worth building the moment there is something to confirm *against*; today there is not.
