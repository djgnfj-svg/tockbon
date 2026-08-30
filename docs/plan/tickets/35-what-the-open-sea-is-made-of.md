Type: grilling
Status: resolved

# 열린 바다는 무엇으로 채우나

⏸ **PARKED 2026-08-29 by the user, and parked is not resolved.** **Ten mechanisms were built and put in
front of them and every one was turned down.** The flat sea stands — a third confirmation — but this
time it stands because nothing better was found, not because flat won a comparison.

> ***"음 그럼 잘 분리되어있는 느낌인가 ... 물은 일단 이렇게 해서 마무리하자 뭐가 없다 이렇다 할만한게
> 나중에 해야할껄로 정리"***
> — *"so it feels well separated then ... let us wrap the water up like this for now, there is nothing,
> nothing worth calling a result. File it as something to do later."*

## 무엇이 이 티켓을 열게 했나

**사용자가 먼저 꺼냈다** — ***"물 관련해서도 프로토타입 만들어가면서 내가 확정하고 싶어"***, 그리고
바로 범위를 좁혔다: ***"섬에 해안가는 끝났음 먼 바다까지 생각했을 때의 바다를 어떻게 할지 고민하는
중임"***.

⚠⚠ **해안선은 이 티켓이 아니다.** 어디서 나오는지(후보 일곱)와 어떻게 움직이는지(후보 스물일곱,
`27-gaps`)는 둘 다 게임에 박혀 있고 여기서 다시 열지 않는다. **이 티켓은 그 흰 선 바깥의 물 전체다.**

## 무엇을 만들어서 보여줬나 — **열 벌, 두 계열**

**모든 후보가 게임의 진짜 섬·햇빛·카메라 위에 서고, 해안선은 지금 셰이더를 스크립트가 통째로 감싸
붙여서 글자 하나까지 같다.** 두 실험대의 `README.md` 가 그 장치를 들고 있고, 후보마다 `NOTES.md` 에
**사는 것 · 드는 값 · 못 하는 것** 세 줄이 있다.

### `prototypes/sea/` — **무늬 다섯.** 물의 색에 무엇을 칠하나

| | 어디서 나오나 | 먼 바다 |
|---|---|---|
| `01-crests` | 월드 좌표의 노이즈를 문턱으로 자른 흰 획 (Alba · Ameye) | ✅ |
| `02-facets` | 평평한 면의 격자, 격자를 휘어 격자로 안 보이게 (섬과 같은 언어) | ✅ |
| `03-swell` | 메시가 진짜 움직이고 그 높이로 두 색을 고름 (Sea of Thieves) | ✅ |
| `04-bands` | 땅까지의 거리를 계단으로 자름 (Ameye · A Short Hike) | ⛔ **없다** |
| `05-paper` | 화면 픽셀 격자에 점으로 찍음 (A Short Hike) | ✅ |

### `prototypes/wave/` — **빛 다섯.** 해가 물을 어떻게 만지나

⚠⚠ **이 계열은 바다에 빛을 켜야 존재한다.** 지금 바다는 `unshaded` 라 빛을 아예 안 받는다.

| | 어디서 나오나 |
|---|---|
| `01-shadow` | **섬 그림자 하나뿐.** 이 판의 바닥이지 후보가 아니다 |
| `02-ripple` | 면을 휘고 해가 찾게 둔다. 색은 안 건드린다 |
| `03-steps` | 같은 면인데 빛을 세 단으로 자른다 (cel) |
| `04-glint` | 물은 평평한 채로 두고 좁은 반짝임만 (specular) |
| `05-swell` | 메시가 진짜 오르내리고 빛만 그것을 보여준다 (Bad North) |

## 무엇이 재어졌나 — **다음 라운드가 다시 안 재도 되는 것들**

- ⚠⚠ **섬 그림자는 물에 조각 3분의 2밖에 안 진다.** 섬이 물 위로 0.85 조각 서 있고 해가 52도로 높다.
  흰 해안선이 이미 조각 3분의 1이라 **바뀌는 픽셀 3510 개가 거의 다 바깥 흰 선이 회색이 되는 것**이지
  파란 물이 어두워지는 게 아니다. **크게 하려면 해를 내려야 하고, 그것은 섬 전체의 조명 결정이다**
- ⚠⚠ **땅까지의 거리 자료판은 네 조각까지만이다.** 그 밖은 전부 같은 값이라 **거리로 그리는 방식은 먼
  바다에서 할 말이 없다** (`04-bands` 가 그것이다). 넓히는 것은 다이얼이 아니라 굽는 방식의 변경이다
- ⚠ **긴 너울은 키가 커야 보인다.** 스무 조각 파장에 0.3 조각 높이는 기울기가 1도 미만이라 그림자만
  있는 사진과 구별이 안 됐다. **1.3 조각까지 올려야 나타난다** — 열린 바다가 한 층 반씩 오르내린다
- ⚠ **Godot 은 `DIFFUSE_LIGHT` 에 `ALBEDO` 를 곱한다.** 빛 함수에서 `ALBEDO * ...` 로 쓰면 색이 제곱돼
  두 단 어두워진다. 다섯 벌이 전부 그렇게 나왔다가 고쳐졌다
- ⚠ **`VIEW_MATRIX` 는 전역 함수에서 못 읽는다.** 인자로 넘겨야 한다

## 사용자가 무엇을 물렸나 — **그대로 옮긴다**

| 언제 | 말 |
|---|---|
| 무늬 다섯을 보고 | ***"흠... 애매하네 뭐가 좋은건 딱히 없는듯? 아직은 바다쪽에 욕심은 없어서 잔잔하게만 있으면되는데"*** |
| 빛 다섯의 첫 판을 보고 | ***"니가 만드는게 너무 자글자글함 이게 멀리서 봤을때도 고려해야해서"*** |
| 크게 잡아 다시 찍은 것을 보고 | ***"암... 너무 별로네"*** |

⚠⚠ **「자글자글하다」와 「멀리서 봤을 때」가 이 티켓의 판정 기준이다.** 다음에 무엇을 만들든 **여는
화면 한 장으로 판단하지 않는다** — 실험대가 카메라 셋(여는 화면 · 빼서 본 화면 · 땅 없는 먼 바다)으로
찍는 것이 그래서다.

## 다시 열 때 무엇부터 읽나

1. **위의 「무엇이 재어졌나」 다섯 줄.** 전부 실측이고 다시 재면 라운드 하나가 날아간다
2. **`prototypes/sea/` 와 `prototypes/wave/` 의 `NOTES.md` 열 장** — 각각 **못 하는 것** 한 줄이 있고,
   그 줄이 그 방식을 다시 고르지 않을 이유다
3. ⚠ **`look.gd` 에 죽은 물 상수 40 개가 산 것 40 개와 나란히 있다.** 8월 28일에 갈린 옛 바다의 것이고
   **아무것도 안 읽는다.** 바다를 다시 만지는 날 그중 하나를 돌리면 화면이 안 바뀐다
4. ⚠ **바다를 재는 그물이 하나도 없다.** 바꿔도 안 깨지고, 망가져도 안 잡힌다

## 언제 다시 여나

**항해가 들어오는 날**, 또는 사용자가 바다에 욕심이 생기는 날. ⚠ **12 월 데모가 이것에 걸려 있지
않다** — 이번 주의 끝나는 조건은 섬이고 바다가 아니다.

---

## Answer — **2026-08-30. It was asked a second time and this time something won**

⚠⚠ **The 2026-08-29 round rejected all ten** — five patterns, five lightings — **because nothing beat
flat**, and it was parked. **Two things changed and they are why the answer came out different:**

1. **The first round judged EMPTY water.** There was no boat and no wake in any of the ten frames.
2. **The camera now roams 20 조각 out over open water**, so open sea is looked at for much longer.

**Five new candidates were built with a boat crossing in every frame** (`prototypes/sea/06-fleck` ·
`07-near` · `08-drift` · `09-rim`, plus `10-grain` as a **control** — the rejected fine-grain pattern
kept in the sheet so the others could not win merely by being quiet). **The user picked `06-fleck`**
from the running lab: countable objects scattered on the water, drifting as one current.

***"Put it in weakly."*** ⇒ shipped at `WATER_FLECK_AMT` **0.09** against the prototype's **0.11**.
**Only the strength dial moved**; count, size, colour and current are the candidate's own values.

⚠ **What it cannot do, and this was known when it was chosen**: it says nothing about the water
BETWEEN the flecks. **98% of the sea is unchanged.** If the sea still reads as empty, this is not the
thing that will fix it.
⚠ **The flat sea and the 해안선 were not reopened** — every candidate carried both byte for byte.

## ⚠ Chosen in the lab, NOT yet judged in the game

**The user picked it from `prototypes/sea/open_lab.gd`, not from the running game.** The game was
launched with it in and the session moved on to another subject before they said anything about it.
**Silence is a row, not a pass.**

**How to see it**: launch the game, press 시작하기, then **push the cursor to the screen edge and travel out
over open water** — the flecks are easiest to judge away from the island, because with land in frame the
eye goes to the land. **What should look different**: a scatter of small countable marks drifting as one
current, where before there was flat colour.
⚠ **It is deliberately weaker than the candidate** — 0.09 against 0.11 — and the candidate itself only
moved 1–2% of the frame. **If nothing looks different, that is the expected failure and it is one line.**
