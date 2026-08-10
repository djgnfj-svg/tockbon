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

**Then the first build was judged and the layout was cut down again:**

> "XP는 아래 얇은 선으로 (…) HP가 숫자가 바 안에 있어야 줬으면 좋겠고 (…) 레벨도 굳이 여기 보일 필요가
> 없을 거 그냥 레벨이라는 존재 자체가 있다는 것만 알면 될 거 같은데? 돈도 오른쪽 구석에 표시해 주고"

Four decisions: **the number goes inside the bar**, **XP is a hairline** (not a second gauge), **level is
off screen entirely**, and **money moves to the corner** with an icon.

**The level-up prompt survives that cut on purpose** — it is an instruction ("P키로 뽑기"), not a statistic.
Dropping it would leave a pick waiting with nothing on screen saying so.

## The layout, and why the corner is not a taste question

```
                                    ← WINDOW_RECT (48,12)-(912,384): assembly · three-pick
   ⬆ 레벨업! P키로 뽑기               y 392
   ┌──────────────┐                  y 448, hp_frame.png at half scale
   │   87 / 100   │                  현재 / 최대, both inside the bar
   └──────────────┘
   ▬▬▬▬▬▬▬▬                          y 501, 5px XP hairline
                          ★ 24       y 452, right-aligned in the corner
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
| `HP_FULL` `(0.80, 0.16, 0.18)` | the bar's fill |
| `HP_TEXT` → `HP_TEXT_LOW` | the number, cream → white as it drains |
| — | the string is `현재 / 최대` (「최대 체력하고 현재 체력을 다 보이게 슬래시로」). The bar says *what fraction*; the pair says **how much of what** — 40/100 and 40/200 fill it identically |
| `XP_BAR` `(0.38, 0.72, 0.95)` | the hairline — **cool on purpose** |

**The number is not red, and that is a consequence of putting it inside the bar.** A red number on red fill
is invisible at full health and only appears as the bar drains away from under it — which reads as the
number breaking, not as health dropping. It goes cream → white instead, so it gets *more* legible as the
fill retreats.

**XP is deliberately not red.** Sharing health's colour would make the hairline read as a second health bar.

**Interpolated, never stepped.** No threshold to tune, and no frame where the colour jumps.

**And no blink.** The character sprite already blinks on invulnerability (`character_view`'s
`invuln_left & 1`); a second blinking thing on screen reads as a rendering fault, not as danger.

## Next session's job — **the palette's visual language does not match the windows**

**The user looked at it and asked directly** (「이번에 개선한 것들 다 통일성을 좀 갖게 됐나?」), then decided:
**팔레트 부분만 바꾸고 싶은데 다음 세션에서 바꾸자.** So this is written down rather than done.

There are **three** visual languages on screen at once:

| Where | What it looks like |
|---|---|
| Assembly · three-pick · research windows | thin strokes, dark navy ground, **drawn from coordinates** |
| The health frame | thick black border, **pixel art** (`assets/ui/hp_frame.png`) |
| Palette glyphs · runes | cream ink, **generated art** (`assets/circle/icon_*.png`) |
| Town · monsters · terrain | brown pixel art |

**The health frame is the odd one beside the windows** — put them side by side (open the assembly window and
look at the bar under it) and one is a hairline drawing and the other is a chunky sprite. The money icon is a
white star, which is a fourth thing again.

**The cheaper direction is to pull the windows toward the frame**, not the reverse: repaint the window
borders as the same thick pixel border and move the ground from navy toward the dark browns the game world
already uses. Going the other way makes `hp_frame.png` an unused asset again, which is the failure this repo
keeps catching.

**Not judged, and not started.**

## Unresolved

- **Nobody has seen it at speed.** The check was done in a background browser tab at FPS 8
- **The gauge has no ticks.** At 100 max hp one pixel is not one point, so "how much is that" is only
  readable from the number — which is the division the user asked for, but it has not been judged on screen
- **The money icon is `icon_point.png`, a star.** It was the closest thing on disk to 「그 점 그 표시」 and
  it has not been judged; a coin would read as money more directly
- **The bottom third of the screen is empty in the town** (the map has nothing under the floor line and
  `sky_background`'s depth fill does not reach it). Not this doc's problem, but it is what the health sits on
