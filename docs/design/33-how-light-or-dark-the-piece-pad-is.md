Status: ✅ **유효하다.** 2026-08-29 에 밝기 여섯을 게임에서 눌러 보고 사용자가 3번을 골랐다 — 「다 별론디 3번으로 해줘」가 그대로 실측이다. (티켓 33 이었다)

# How light or dark the 조각 판 is, and how wide the gutter

## Answer

✅ **2026-08-29 — the faintest light one, and the gutter as it stands.**

**Six tones were put on one key each and flipped in the running game.** The user: 「다 별론디 3번으로
해줘」 — ***"none of them are great, but go with 3."*** ⇒ **`PAD_ALL_LIGHTEN` is +0.12**, the faintest
of the three light ones; **all three dark ones were rejected on sight.**
⚠ **「None of them are great」 is the measurement here** — the tone passed, it was not loved, and the
next round on the 판's look should start from that sentence rather than from the number.

**The gutter**: 「판의 틈은 없어졌고」 — the question is off the table, and what ships is the **narrow**
bake (`PAD_GAP_IN` 0.13, a 0.26 gutter), which is what was on screen when it was said.

## The question

**Which of the twelve is it?** Six tones — three lighter than the ground and three darker — at two
gutter widths, all on the real island under the game's own camera.

## Why this is asked

**The user asked to see both** (2026-08-29): 「밝게해보자 어둡게도 해서 프로토 타입으로 보는게 목적」.
The sheet was made and put on screen; **the pick did not come back before the round closed.**

⚠⚠ **What ships right now is a default, not a choice**: the middle light tone (`PAD_ALL_LIGHTEN` 0.25)
and the **wide** gutter (`PAD_GAP_IN` 0.22 in the bake). Both were what happened to be in place.

## Where the pictures are

`docs/reference/2026-08-29-pad-tone-and-gutter-sheet.png` — twelve shots, near and far, made by
`.prototypes/pads/look_sheet.gd`. **Re-take them with:**

```
Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/pads/look_sheet.gd -- <tag>
python .prototypes/pads/look_sheet.py
```

⚠ **The gutter needs a re-bake to change, the tone does not.** The tone is one uniform pushed from
`look.gd`; the gutter is geometry. ⚠ **It said `tools/blender/island_build.py` — that folder was
deleted 2026-08-31 and the geometry is now edited in `blend/island.blend` (the `pads` object) and
re-exported; `docs/manual/blender.md` carries the loop.**

## What is already known from looking

- **The 판 currently reads DARKER than the sand** at the shipped value, which is what the light half of
  the sheet exists to answer — a mark meaning 「you may stand here」 that reads as shade is the failure
- **The tone is signed since 2026-08-29**: positive pulls toward white, negative toward black, zero is
  bare ground

## ✅ **Looked at — 2026-08-29. It passed, with one thing wanted**

**The user, on the game screen:**

> 「봤는데 음 좋긴한데 멀면 좀더 합칠 수 있도록 되면 좋을듯? 뭔말알?」

⇒ ***"I looked. It is good — but when the camera is far away it would be better if they could merge
together more. You know what I mean?"***

⚠⚠ **That is a pass on the 조각 판 and a separate want**: at distance the 284 separate marks read as
too many separate things, and the gutters should close as the camera pulls back. **It is not about the
tone or the gutter width this ticket holds** — those are still unpicked — and it is not a reversal of
the 조각 unit. ⇒ **ticket 34.**

## ~~⚠ Not looked at yet — 2026-08-29~~ — **answered above the same day**

| What shipped | How to see it | When |
|---|---|---|
| **The 조각 판 in the real game** — one mark per 조각, 284 of them, hover on one 조각 | Run the game, press 시작하기, then **hold TAB**. The whole board's marks appear; the 조각 under the cursor lightens and lifts | 2026-08-29 |

**The user has said nothing about it on screen.** ⚠ **Silence is this row, not a pass.**
