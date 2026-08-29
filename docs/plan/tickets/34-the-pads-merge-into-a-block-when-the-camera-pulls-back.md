Type: grilling
Status: open

# Which of the four makes the 조각 판 merge into a 칸 as the camera pulls back

## The question

**Four mechanisms are built and photographed. Which one goes into the bake?**

## Where it came from

**The user, having played with the 조각 판 in the game** (2026-08-29):

> 「봤는데 음 좋긴한데 멀면 좀더 합칠 수 있도록 되면 좋을듯? 뭔말알?」

⇒ ***"I looked. It is good — but when the camera is far away it would be better if they could merge
together more."***

**Settled the same round, before anything was built:**

| What | The user's word |
|---|---|
| **What they merge INTO** | ***"far out I want it by 칸"*** 「멀면 칸단위로 하려고함」 |
| **What drives it** | ***"by zoom"*** 「줌에따라」 |
| **How much of the seam goes** | ***"take all four out"*** 「넷다 없애봐」 — the seams inside a 칸 go completely |
| **When it gets tuned** | ***"so it can be adjusted together with the stair"*** 「계단 할떄 같이 조정하게」 |

## The four, and the line that decides each

**Built in `prototypes/merge/`; the sheet is `docs/reference/2026-08-29-pad-merge-prototypes.png`.**

| | Where the merge comes from | ⚠ What it CANNOT do |
|---|---|---|
| `01-grow` | **the vertices move** — each ring point carries where it goes | merge into anything the bake did not already draw |
| `02-carve` | **the gutter is a shader number** on a whole-조각 quad | hold a shape the rounded-rectangle formula cannot say |
| `03-crossfade` | **two finished boards**, faded across | be crossed slowly — the middle is a double exposure |
| `04-filler` | **a bar over each seam**, fading in | change the OUTER shape: a merged 칸 stays four welded squares |

## What is already decided about the hover

⚠⚠ **What lights is whatever the 판 IS at that distance** — one 조각 up close, the whole 칸 once they
have closed up, and a blend between. **All four share one piece of shader code for it**, because a
hover that differed per version would make the four incomparable. This came out of the user's own rule
(「조각에 판을 올리고 왜 뜨는 판은 또 다른데 뜨네... 니가 개념이 좀 잘못된듯?」): the mark that rises is
the mark that was lying there.

## ⚠ What is NOT in the game

**None of it.** The shipped 판 does not merge at any distance; the four live in the lab, which drives
the real game and switches the baked 판 off. **The user closed the round on 「좋네 이대로 마무리하자」
without naming one**, so nothing was applied.

## What the pick costs afterwards

**The winner is rebuilt in `tools/blender/island_build.py`**, since the shipped 판 is baked rather than
built at runtime. ⚠ **`01-grow` needs a second attribute per vertex** (where each point goes), and
`03-crossfade` needs a second 판 object in `island.glb`; the other two need nothing new in the file.
