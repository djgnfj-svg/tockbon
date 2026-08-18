# What makes placement a decision — nine games, nine different answers

**Implemented**: none — `src/` is empty
**Accepted**: none. **Nothing has been picked yet**

The problem the user raised: *"특정 위치로 특정 부대를 이렇게 보낸다거나 내가 이렇게 한쪽으로 쭉 보내면
재미가 없을 거 같아. 뭔가 좀 더 전투적인, 전략적인 면이 있어야 될 듯?"* (*"Sending a particular squad to a
particular spot, or just sending everyone down one side — I don't think that would be fun. It needs
something more combative, more strategic."*)

⇒ **This question comes before "drop or place."** Without a rule that makes position a decision, "everyone
down one side" is the right answer whether you drop them or place them. This document collects only how
actually shipped games built that rule.

---

## ⚠ First: this repository has been citing Bad North wrongly

**Bad North is not "place and done." You keep moving squads during the fight.**
Oskar Stålberg himself: *"We have this very low granularity of interaction, which means that mostly players
will be simply positioning their squads on a grid and then each of the units in that squad decide
how/when to attack from there."* — he did not remove control, he **lowered its granularity**.
([Nintendo interview](https://www.nintendo.com/en-gb/News/2018/April/Interview-Taking-on-hordes-of-invading-Vikings-in-Bad-North-1368315.html) ·
[NWR review](http://www.nintendoworldreport.com/review/48095/bad-north-switch-review))

⇒ **This game's "no control" cannot be justified by pointing at Bad North.** It stays as a reference point,
but it cannot be used as evidence.

---

## The table — split by whether control is required

**This game has zero control after commit.** So anything with "yes" in the right-hand column cannot be
carried over as-is.

| Game | Rule | What is weighed against what | Control after commit |
|---|---|---|---|
| **Into the Breach** | **The enemy's next turn is fully telegraphed down to the target tile, and there is no hit randomness.** Shoving an attack off target is more often the answer than dealing damage directly | Let a building be destroyed vs sacrifice a mech | **None** |
| **Mechabellum** | A unit moves freely **only on the round you buy it**, then is **locked in place**, deploying, dying and redeploying from the same spot every round | The placement that wins now vs the opponent's counter next round. **Position becomes an irreversible past investment** | **None** |
| **TFT** | Nearest-target plus **abilities that respond to distance** (snipers scale damage with hex distance) | Pull the carry back and it is safer but out of range; corner it and area attacks sweep it up with everything else | **None** |
| **Clash Royale** | **You can only place on your own half**, and destroying a tower opens a small pocket across the bridge | Place at the back and it is safe but arrives slowly, giving them time to answer; place at the bridge and it pressures instantly but you have no time to answer — **position converts into time** | **None** |
| **Loop Hero** | The hero's position is not the thing you decide. You decide **where on the loop to put terrain cards**, and the tile you place spawns enemies and raises rewards | **Every placement raises reward and difficulty at once** — "where do I defend" becomes **"how much do I take on"** | **None** |
| Bad North | Four squads maximum per island, and enemies land **from any edge** and hit **several points at once** — there are more landing points than squads | What to give up. And Flee — **the commander's life vs the coins in the houses left** | **Yes** |
| They Are Billions | Zombies **stop to break a wall when they hit one.** So you build the wall not at the choke but **behind it, where the choke widens again** | Narrow it and your fire concentrates but so does everything inside an area attack's radius; widen it and the wall has more HP but your fire is spread | Partial |
| Pikmin | The only means of command is **throwing them one at a time to a coordinate** | The real time spent throwing is itself the cost, so **"all of them on one side" is physically slow** | **Yes** |
| **Despot's Game** | Pre-battle placement only, zero control, **nearest-target** | — | None |

---

## ⚠ The sharpest contrast — TFT and Despot's Game have **the same rule and opposite outcomes**

Both are "place them, then they hit whatever is nearest", and both have zero control after commit.
**In TFT position is the core decision; in Despot's Game position is not a decision at all.**

**There is exactly one difference: whether abilities respond to distance and direction.**
TFT's snipers scale damage with distance, and area attacks punish bunching. Despot's Game has nothing like
that, and **the studio admitted it themselves by adding an auto-arrange button.** The decision point the
reviews identified was not a coordinate either — it was "which weapon do I put on them to make which class."
([Despot's Game review](https://gamecritics.com/eugene-sax/despots-game-dystopian-army-builder-review/) ·
[TFT positioning](https://mobalytics.gg/blog/tft/tft-positioning-guide-how-to-get-the-most-from-your-units/))

⇒ **What makes "where do I drop them" a decision is not terrain and not the direction the enemy comes from.
It is range and area.** If every soldier hits at the same distance in the same way, no terrain you lay down
makes position a decision. ⇒ **This is why "engagement rules" belongs at the top of the undecided list.**

---

## The counter-case — what each approach actually cost

**No control + free placement (Loop Hero · Despot's Game) — this lands squarely on this design**
> *"Because you have no direct control over your character, it means that you always want to play it
> safe when it comes to card placement. This reduces not only the number of viable ways to play Loop
> Hero, but also what cards to take."* — [Game Wisdom](https://game-wisdom.com/analysis/loop-hero)

**No control does not widen the placement options, it narrows them.** Because it cannot be undone, you play
it safe. Despot's Game landed as mixed on Metacritic — *"The complete lack of control in battles and the many
ways the game sabotages your ability to make strategic choices really hurts this game."*

**Locked placement (Mechabellum)** — a unit locked onto an early target is wasted when a better target shows
up later. **It punishes you in a form you cannot read.** ⇒ The studio **added five kinds of movement
afterwards** (selling · a shove skill · a movement item · a one-unit-per-round move card · air units).
**Pure locked placement did not survive in its shipped form.**
([Steam discussion](https://steamcommunity.com/app/669330/discussions/0/4518883844569560391/))

**Full-information telegraphing (Into the Breach)** — *"more puzzle than strategy"*. It becomes a puzzle with
one optimal solution per turn, which is calculation rather than tension. ⚠ **And it does not port to
real-time — ItB's full information works because the turn is frozen.**
([GameCritics](https://gamecritics.com/mike-suskie/into-the-breach-switch-review/))

**Bad North** — Metacritic 65–74, Destructoid 5.5/10. *"shallow combat"*; with only three unit classes you
have seen it all in two hours. ⇒ **One positional rule on its own does not produce depth.**
([Destructoid](https://www.destructoid.com/reviews/review-bad-north/))

---

## What could not be confirmed — nothing was guessed

- **A direct developer statement on why Bad North's islands are small**: none. The reason the developer gave
  for procedural generation was not tactics but **readability** (everything happening in a fight must be
  visible → block islands, grid placement)
- **A Supercell primary source on Clash Royale's own-half restriction**: none. The rule is confirmed; the
  intent is inferred
- **Bad North's "three ships at once" figure**: the source is a strategy guide, not a primary source
