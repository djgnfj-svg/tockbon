---
name: game-planning
description: Designs a tockbon game feature in conversation with the user and lands it as an implementable spec doc. Use when the user throws out a feature idea or a direction for the game — "기획하자" "브레인스토밍" "이런 거 어때" "이 기능 만들고 싶다" "let's design this" — or when what to build, not how, is still open. Output is a design doc in docs/plans/1.ready/, which the build team takes as input.
---

# Game design

## Two principles

**1. Dig for at least 4 rounds, at most 10.**
Normally fewer questions is right; here it is the opposite. Do not write the doc before round 4.
Why: one line of design can burn the entire performance budget, and by the time you find out it is already built.

**2. Don't ask — lay out the options.**
The user does not write game code. "How should we do it?" is a question with nothing to answer from.
Instead, **show how game development generally handles that axis, as a list, and let them pick.**

## Survey the current state before you start

Before laying out options, **always find out what already exists.** Skip it and you propose what's already there.

- `docs/plans/` `3.done` · `2.active` — already designed or built
- The related code. Folders are contracts, so **the question decides where to look**:

| Folder | What | Constants |
|---|---|---|
| `src/sim/` | Grid · projectiles · glyphs · fire. **Integer determinism** | `sim_tuning.gd` |
| `src/actor/` | Character · aim. float allowed | — |
| `src/view/` | Everything on screen | **`fx_tuning.gd` — every presentation knob is here** |
| `src/stage/` | Shell (tick loop · input · HUD · stage map). Won't survive into the real game | — |

Tag every item with a state: **exists (with its current value) / missing / impossible (a prerequisite is absent)**

### When it exists but they don't like it

"The hit feel is weak" is usually solved by **tightening existing values**, not adding an axis. Order:

1. Show what the value is now
2. Split what's lacking — too weak / not visible / mistimed
3. Decide whether tightening fixes it, or the axis genuinely doesn't exist

One common cause: **the axis exists but values don't follow per power tier.** Double the power with no screen
change and it's this. This game's v1 died that way.

## Example

User: *"맞았을 때 타격감이 있었으면 좋겠다"*

**Not this**
> "타격감을 어떻게 구현할까요?"

**This**
> 타격감은 보통 이 7가지로 만듭니다.
>
> - **사운드** — 체감 1위. 이 게임엔 지금 하나도 없음
> - **히트스톱** (몇 프레임 정지) — 무게감이 제일 큼. 이 게임은 의도적으로 뺐고 섬광 지속으로 대신하는 중
> - **화면 흔들림** — 이미 있음. 위력 단마다 진폭·지속이 다름
> - **파티클·스파크** — 이미 있음. 단마다 개수·비거리가 다름
> - **히트 플래시** — 없음. 셰이더 필요
> - **넉백** — 엔티티가 없어서 지금은 불가
> - **슬로모션** — 20Hz 정수 틱이라 주의 필요
>
> 뭘 쓸까요? 추천은 사운드입니다. 없는 것 중 체감이 제일 큽니다.

(The user reads this, so it stays Korean.)

Recommend **after** showing the whole list. Recommend first and they choose without knowing the rest existed.

## Running the rounds

- One axis per round.
- At the end of each round, update "what's settled so far" in 3 lines or fewer.
- If the user's answer raises a new question, that is the next round. It outranks any pre-planned order.

## Axes to dig

| Axis | What you ask | |
|---|---|---|
| What | What exactly happens | Always |
| Why | Where the fun comes from | Always |
| Visible | What does the user see that tells them it happened | Always |
| Bounds | What doesn't work. At extremes | Always |
| Mixing | When it meets water · lightning · explosions · terrain | As needed |
| Cost | The checklist below | As needed |
| Failure | What does it look like built wrong | As needed |
| Measure | What do you look at to judge it worked | As needed |

## Cost checklist

These traps are specific to this game — unasked at design time, they blow up during implementation.
All of them are measurements from code comments.

| When the design says | What actually happens |
|---|---|
| "dries up / disappears over time" | That cell updates every tick → the chunk never sleeps → performance budget collapses |
| "lasting effect / buff" | A timed state keeps that region awake the whole time. A permanent state is free |
| "moves smoothly" | Sim is 20Hz integer. float · sqrt · sin kills multiplayer |
| "several big explosions" | 4 shots per tick is already 54% of budget |
| "full-screen effect" | Render cost can't be measured headless. Only visible as FPS |
| "add a material / element" | 16 palette slots. Only the low 4 state bits are safe |

Do not reject something because it's on this list. **State the price and let the user choose.**

## Record the rejected branch in `docs/decisions/` (decided by the user)

**This skill's method is what creates that problem.** "Lay out options and let them pick" means
**two or three unpicked options appear every round**, and the design doc records **only the picked one.**
⇒ **Months later the same options get laid out from scratch.** The user lived this with inventory.

**When a fork is taken in a round, write the decision right there.** Do not defer to the next round —
**conversations are lost; the repo is kept.**

**Not everything gets recorded.** Only "we dropped B in favor of A" **with a reason.**
Picking a value ("let's make it 20") is not a decision doc; it's a value in the design doc.

Format and index updates follow `docs/decisions/README.md`.

## Stopping conditions

- 4+ rounds done and the first four axes are answered
- The user says "done / write it up"
- Round 10 reached

Before writing the doc, show everything settled at once and get confirmation.

## Output

`docs/plans/1.ready/<feature-name>.md`

```markdown
# <Feature name>

**Status**: ready
**One line**: <what happens>

## Why
## Behavior
## Screen
## Bounds
## Interaction with what exists
## Cost
## Acceptance
## TBD
```

**Do not force the TBD section full.** A spec that pretends to know produces a fake implementation.
Written as TBD, the build team will ask.

## Status moves

```
docs/plans/1.ready/   designed, waiting
docs/plans/2.active/  building — "let's build this" moves it here
docs/plans/3.done/    finished
```

Fix the `**Status**:` line inside the doc at the same time.
