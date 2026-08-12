# A level-up card has no price

**Status**: valid (2026-08-13)

## What was decided

**The card still appears at level-up and is still taken by pressing it.** What was deleted is the
`species · slot · price` line and the per-species balance that paid it.

Which species a card shows is still rolled from what has been eaten. **Taking it costs nothing.**

## What wasn't chosen

| Rejected | Why |
|---|---|
| Price paid from that species' balance (the GDD's rule) | **Two locks on one door.** The pool is already rolled from what you ate, so a crocodile card only appears after eating crocodile — and then it charged crocodile again. The user rejected it the moment it was described back to them |
| Keeping the balance but pricing in a shared currency | Cross-species payment was already cut for taxing the one thing the game sells. Re-adding a shared currency re-opens it |
| Free cards with no gate at all | Not chosen either — **the gate moved**, it did not vanish. What you have eaten still decides what appears, and going all-in on one species is now paid for by *not* taking the other cards |

## What's tied to it

**Species balance as a tracked number.** With no price, nothing spends it — only the totals that weight the
roll survive. [One level gauge, two numbers per species](one-level-gauge-two-species-numbers.md) is
half-reversed by this: the *balance* column has no consumer left.

The half-refund on replacing an occupied slot also loses its currency. Order-changes-outcome now rests on
**species traits** instead: filling slots from one species buys a trait, and breaking the set for a better
part gives it up.

## Conditions to reopen

If cards read as free confetti in play — if taking one is never a decision — the gate has to come back, but
**as a scarcity of slots or traits, not as a second charge on the same species.**
