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
| ~~1~~ | ~~**몸마다 바닥 그림자** — 짐승 밑에 눌린 타원 하나~~ | ⚠⚠ **판정을 못 받은 채 삭제됐다** (2026-08-24, 티켓 08). 손으로 그리던 타원은 3D 로 옮기면서 없어졌고 **엔진의 빛이 대신 던진다.** 볼 것이 남아 있지 않으므로 줄을 긋는다 | 2026-08-24 |
| 2 | **전투 화면이 3D 로 섰다** — 언덕·경사로·해안·움직이는 바다·소환 원 | 게임을 켜고 섬에 들어간다. **Q 와 E 로 판이 돌아간다.** 볼 것: 땅이 물결치고, 절벽이 벽이고, 바다가 천천히 움직이고, **바다 위에 옅은 원 하나**가 소환 가능한 데를 두른다. ⚠ **섬 2 에만 경사로가 있다** | 2026-08-24 |
| 3 | **판을 손으로 돌릴 수 있다** — Q 와 E, 한 번에 15도 | 섬에서 Q 나 E 를 누른다. **전투 중에도 먹는다.** ⚠ **이게 「전투 중엔 손이 안 움직인다」를 건드린다** — 남길지 말지가 티켓 07 이다 | 2026-08-24 |

⚠ **2번과 3번은 사용자가 스크린샷으로 봤고 말도 남겼다**(아래 「본 것」). **직접 켜서 돌려 본 적은 없다** — 회전과 물의 움직임은 정지 화면으로는 판정이 안 되는 것들이라 줄을 안 긋는다.

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

## 본 것 — 2026-08-24

| 언제 | 무엇을 보고 | 사용자의 말 |
|---|---|---|
| 2026-08-24 | 늑대 마흔 마리와 곰 섞인 무리를 나란히 놓은 그림 | *"늑대는 5번이 좋은데 때가 갈리기도 하네 좋아 기울기도 좋네 기울기는 일단 40도로 하자"* ⚠ **이 저장소가 그림을 보고 받은 첫 합격이다** |
| 2026-08-24 | 아군 몸이 네모에서 늑대가 된 판 | *"ㅇㅇ 좀 줄었고 내가 생각하는 애매함이 카메라인데"* ⚠⚠ **애매함에 처음 이름이 붙었다** |
| 2026-08-24 | 판을 40도로 눕힌 판 | *"음... 이게 잘모르겠네.."* ⚠ **합격이 아니다. 원인은 그림자와 가림이 없어서다** |
| 2026-08-24 | 전투 화면을 3D 로 옮긴 첫 스크린샷 (칸마다 상자) | *"뭔가 지금 너무 딱딱해서 재미가 없을까? 그 언덕이죠 언덕 큰 것까지 구현할 수 있나 해서"* ⚠⚠ **불합격이고, 진단이 정확했다** — 칸마다 상자는 땅에 높이를 주고 모양을 안 준다 |
| 2026-08-24 | 언덕과 경사와 회전이 들어간 판 | *"지금 생각보다 좋아서 ㅇㅇ"* · *"경사로나 좀더 자연스러운 지형도되나 싶네"* |
| 2026-08-24 | 경사로·해안·채움광까지 들어간 판 | *"무엇보다 지금 굉장히 괜찮은데 초록색이 있을 필요는 없다? 내가 놓을 수 있는 위치는 그냥 원 기준에 눈에 보이면 될 거 같고"* ⚠ **초록 물칠이 여기서 죽었다** |
| 2026-08-24 | 소환 원과 움직이는 바다까지 들어간 판 | *"일단 이 정도면 됐어"* · *"지금 이 정도면은 내가 생각하는 비주얼적인 거 완성이 된 거 같아. 이제 콘텐츠를 채워서 돌아가게 해보자"* ⚠⚠ **이 저장소가 화면 전체에 대해 받은 첫 완성 판정이다** |
