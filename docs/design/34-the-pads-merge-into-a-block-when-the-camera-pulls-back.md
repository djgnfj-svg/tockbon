Status: ✅ **유효하다.** 2026-08-29 에 넷 중 사용자가 `01-grow` 를 골랐고 게임에 들어갔다. ⚠ 문턱 둘은 아직 게임에서 판정 안 됐다. (티켓 34 였다)

# Which of the four makes the 조각 판 merge into a 칸 as the camera pulls back

## Answer

✅ **2026-08-29 — `01-grow`, and it is in the game.**

**The user, flipping the four in the lab**: 「1번이 좋은데?」 — ***"1 is the good one."***

**What that took**: the bake now writes a second UV per vertex — **where that point goes when its 칸
closes up** — and `src/view/pads.gdshader` walks it there by a `merge` the zoom decides
(`Look.PAD_MERGE_ZOOM` 0.72 · `PAD_APART_ZOOM` 1.45). **The hover follows**: one 조각 up close, the
whole 칸 far out.
⚠ **The two thresholds were never judged in the game** — the island opens at zoom 0.76, which is
already 94% merged. **That is the first thing to move if the change reads too early.**

⚠⚠ **THE RAMP IS GONE (2026-09-01), AND HALF OF THIS PARAGRAPH IS NOW HISTORY.** The order became
칸-sized, so `Look.PAD_MERGE_ZOOM`, `PAD_APART_ZOOM` and `field_view.pad_merge()` were all deleted and
**`merge` is pinned at 1.0** — one mark per 칸 at every zoom. **The geometry half survived**: the second
UV per vertex is still there (`UVMap.001` on the `pads` object in `blend/island.blend`), and
`src/view/pads.gdshader` still walks each point along it. ⇒ **What is dead is the ZOOM deciding the
blend, not the displacement.** The argument below stands the day a zoom ramp is wanted back.

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

**Built in `.prototypes/merge/`; the sheet is `docs/reference/2026-08-29-pad-merge-prototypes.png`.**

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

**The winner is rebuilt in `blend/island.blend`'s `pads` object and re-exported**, since the shipped 판
is baked rather than built at runtime. ⚠ **`01-grow` needs a second attribute per vertex** (where each point goes), and
`03-crossfade` needs a second 판 object in `island.glb`; the other two need nothing new in the file.
