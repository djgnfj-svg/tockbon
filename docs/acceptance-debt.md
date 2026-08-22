# acceptance-debt — what shipped and nobody has looked at

**The user cannot look at every round.** A round that ships without being looked at used to leave no trace
at all, so the next session read a resolved ticket as "accepted" and built on top of it. **This file is that trace**,
and it exists to be worked off **in one sitting**, not one item at a time.

⚠ **A row here is not a bug.** It is a thing that is built, green, and unwitnessed.

## How a row arrives

**At `wrap-up`, one question is asked and the answer decides:**

- **The user says they looked** → **their own words go under 「본 것」 below, that turn, verbatim**, and the
  open row is struck
- **They did not, or said nothing** → a row is added here. ⚠ **Silence is a row**, not a pass

## How a row leaves

**Only the user's own words remove it, and those words stay in this file.** ⇒ **Striking a row without
writing the sentence loses the one thing the row existed to collect.** A `fail` closes a row exactly as a
`pass` does — **and a fail is the more valuable of the two**, so it is written the same way.

⚠⚠ **Verbatim, not a paraphrase, and not in a design doc.** The design docs that held these sentences were
deleted on 2026-08-22 and took them along. **They were the only measurement this repo had of whether the
game was any good**, and nothing else in the repo could replace them.

## How to write "How to see it"

**This column is the whole value of the file.** When the user sits down to work the list off, they are not
going to re-derive how to reach each thing. **Name the screen, the key, and what should be different** —
if it cannot be reached in the running game, say that instead, because that is itself the finding.

| # | What shipped | How to see it | Landed |
|---|---|---|---|

*(비어 있음 — 2026-08-22에 3차가 접히면서 볼 것이 남지 않았다)*

---

## 본 것 — **the user's own words, verbatim**

**Nothing is deleted from here.** A line arrives the turn the user says it and never leaves. ⚠ **These are
about the folded cell game** and they stay: **they are the only record of what this repo has ever been told
about whether a game of its own was any good.**

| 언제 | 무엇을 보고 | 사용자의 말 |
|---|---|---|
| 2026-08-18 | 배가 해안선으로 들어가는 판 | *"배가 그냥 곁다리로 있는 느낌"* |
| 2026-08-18 | 해안선을 열고 배를 여럿 띄운 뒤 | *"참 애매하네. 그래도 그동안 중에서 제일 평범하네."* ⚠ 「곁다리」는 사라졌고 「애매하다」가 남았다 |
| 2026-08-19 | 타이틀과 지도가 생긴 판을 켜고 | *"뭐 어떻게 동작시키는지 전혀모르겠는데?"* · *"조작감이 너무 ㅈ같음"* ⚠⚠ **드래그가 지워진 원인이다** |
| 2026-08-19 | 같은 판, 전투 | *"싸움이 좀 아직은 별로네? 일단 다음 세션에서 꽉 잡아봐야겠다"* |
| 2026-08-19 | 드래그를 지우고 소환 띠를 해안에서 여섯 칸 물린 뒤 | *"동작방식은 맞음"* → *"잘되네"* ⚠ **이 저장소가 받은 유일한 합격이다** |

⚠ **위 다섯 줄은 2026-08-22에 git 기록에서 되살린 것이다** — 지워진 설계 문서 안에만 있었다.
⚠⚠ **전부 연출과 조작에 대한 말이고, 「재밌나」에 대한 합격은 한 줄도 없다.**
