Type: grilling
Status: open

# 물결 꼬리가 고른 것보다 세 배 짧다

## ⚠⚠ The picture the user chose from was of numbers the game does not have

**The wake lab drove the boat at 4.0 조각/s. The game runs at 1.2.** The lab held a hand-copy of
`Rules.BOAT_SPEED_TILES`, and the copy went stale when the speed was lowered to give the player time to
find a boat.

⇒ **The trail the user approved was about 16 조각 long. The same 4-second life draws 4.8 조각 in the game
— shorter than the 5.2 조각 hull.**

⚠ **This is the failure `how-nets-lie` already names** — 「The approved picture was of numbers the game did
not have」, 2026-08-26. **A comparison tool must start every candidate from the shipped values.**

## The fork, with the numbers attached

- **Leave it at 4.8** — accept that what was chosen at one speed reads differently at another.
- **Raise `WAKE_LIFE_SEC` 4.0 → 13.33** to reach 16 조각. ⚠⚠ **Not free**: the history is **eight slots**,
  so a longer life spreads the remembered points from **0.8 조각 apart to 2.67**, and a turning boat's trail
  becomes six visible facets. **The slot count has to grow with it, and the slot count is the shader's
  per-pixel cost.**
- **Something between**, chosen by eye against the hull's own 5.2 조각.

## ⚠ A second dial waits on the same decision

**`WAKE_SIDE_CLOSE` = 0.15 was tuned when the side lines started at the amidships half-beam (1.005 조각).
They now start at the hull's real taper (0.336).** So the two close to a third of a stroke width and
**read as two only for the first 62% of the trail.** Holding the old ratio means **0.48**. It was
deliberately left alone.

## Settled, does not reopen

**The mechanism** — the water shader draws the wake from the boat's recent positions, no buffer, no
geometry — **and the shape**: `04d-single`, one line, leaving the hull at its sides and converging behind
it. ⚠ **`04b-arms` was chosen for the player's own boat and deferred to week 10.**
