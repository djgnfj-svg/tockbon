# HUD — what the player reads while playing

**One line**: health is a **big red number with a thin gauge under it**, bottom-left; everything else is a
small line above it; the debug readout is a separate thing behind F3.

**Implemented**: health · level line · level-up line. **Accepted**: unseen at full frame rate — the browser
tab it was checked in ran at FPS 8.

**A concept stays alive and never changes folders.** The two header lines are only "how much runs now" —
format per [README.md](README.md).

---

## What the user decided

> "ui랑 hp바 나 이런 디자인 한번 뽑아서 설계해줘 니가 골라ㅇㅇ 체력은 숫자만 있어도 될듯 빨간색 표현이랑
> 등등 게임처럼 디자인해주면됨"

Two constraints and one delegation: **the number is the health readout** (not a sentence), **red carries it**,
and the rest was left to whoever built it.

## The layout, and why the corner is not a taste question

```
                                    ← WINDOW_RECT (48,12)-(912,384): assembly · three-pick
   ⬆ 레벨업! P키로 뽑기               y 392
   Lv.3 · XP 12/60 · 돈 24           y 424
   87                                y 460, 34px, red
   ▰▰▰▰▰▰▰▱▱▱                        y 498, 8px strip
```

**The top-left was tried first and does not fit.** `WINDOW_RECT` starts 12px from the top and runs to y 384,
so anything above that line sits *under* the assembly window — and `net_render` has a standing rule that no
window may cover the health readout. **The band below y 384 is the only clear strip on a 540px viewport.**

**The old readout was `체력 100 / 100`, bottom-right.** Two things were wrong and only one was the look:
that corner is the first thing to fall outside the picture when a browser window's aspect does not match
(seen on screen), and a sentence is not a gauge.

## Colour

| | |
|---|---|
| `HP_FULL` `(0.85, 0.18, 0.20)` | full health |
| `HP_LOW` `(1.0, 0.42, 0.30)` | empty — brighter, not darker, so draining reads as *alarm* |

**Interpolated, never stepped.** No threshold to tune, and no frame where the colour jumps and reads as a
state change.

**And no blink.** The character sprite already blinks on invulnerability (`character_view`'s
`invuln_left & 1`); a second blinking thing on screen reads as a rendering fault, not as danger.

## Unresolved

- **Nobody has seen it at speed.** The check was done in a background browser tab at FPS 8
- **The gauge has no ticks.** At 100 max hp one pixel is not one point, so "how much is that" is only
  readable from the number — which is the division the user asked for, but it has not been judged on screen
- **The bottom third of the screen is empty in the town** (the map has nothing under the floor line and
  `sky_background`'s depth fill does not reach it). Not this doc's problem, but it is what the health sits on
