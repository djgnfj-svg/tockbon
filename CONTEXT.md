# CONTEXT — the words this repo uses

**Rewritten 2026-08-22 저녁** when the magic-circle game was dropped and the island game came back as a
**wolf** game. `tdd` and `domain-modeling` both read this file for the vocabulary that test names and
interfaces are built from.

⚠ **The user speaks Korean and the code speaks English.** Both columns are load-bearing: **an answer that
uses only the English word is not an answer to the user**, and a symbol named in Korean is not a symbol.

⚠⚠ **`src/` is restored, so most of this file is now taken from code and not from a design.**
**Where the code and this file disagree, the code wins and this file is corrected.**
**Rows still marked 미정 are designs, and they say so.**

---

## 짐승과 종족 — **the one that was renamed**

| 한국어 | Code | What it is |
|---|---|---|
| 짐승 | **beast** | **One creature on the field.** The thing that lands, walks, and hits |
| 종족 | **species** | Which beast the run is played as. **늑대 (wolf)** is the first |
| 빌드 | **build** | How one species grows inside a run. **목표는 종족마다 둘** |

⚠⚠ **「세포」는 죽은 낱말이다.** 게임이 세포에서 늑대로 바뀌었다(2026-08-22 저녁).
**종족은 데이터지 타입이 아니다** — 코드는 **짐승**을 알고, **늑대는 종족 값 한 줄**이다. 목표가 캐릭터
둘이므로, 코드에 늑대를 박으면 둘째를 넣는 날 전부 다시 고친다.

### ⚠ 코드가 지금 실제로 쓰는 이름 — **아직 안 바꿨다**

| 정한 말 | 코드가 지금 쓰는 것 | 상태 |
|---|---|---|
| 짐승 · beast | **`soldier` · `army` · `unit`** | ✅ **이미 종족 중립이다. 바꿀 이유가 없다** |
| 근접 짐승 · 원거리 짐승 | **`cell_melee` · `cell_ranged`** | ⚠ **여기만 세포가 박혀 있다.** 고도가 도는 데서 바꾼다 |
| — | **`cell_at` · `cells` · `_cell_centre`** | ✅ **격자 칸이다. 생물이 아니다 — 건드리지 않는다** |
| — | **`title_cell_*` · `refit_cell_*`** | ✅ **화면의 칸이다. 건드리지 않는다** |

⚠ **한국어 「세포」는 2026-08-22 저녁에 서른한 곳을 「짐승」으로 바꿨다.** 주석과 그물 라벨이라
코드를 안 깬다. **열일곱 곳은 일부러 남겼다**:

- **사용자가 한 말을 그대로 인용한 두 줄** (`look.gd`·`rules.gd`). ⚠⚠ **인용은 낱말이 바뀌면 인용이
  아니다.** 이 저장소가 사용자 말을 잃은 적이 한 번 있고, 그래서 인용은 절대 안 고친다
- **타이틀 화면의 떠다니는 배경 열다섯 곳** (`net_title`). **상수가 `Look.TITLE_CELL_*`이라 라벨만
  바꾸면 라벨과 상수가 어긋난다.** ⇒ **상수를 바꾸는 날 같이 바꾼다**

## 한 판 — **the loop, and it is in code**

| 한국어 | Code | What it is |
|---|---|---|
| 회차 | **`Run`** | 한 판. 지도의 어느 노드에 서 있고 무슨 보상이 기다리는가 |
| 지도 | **`RunMap`** | 5층 7노드. 갈라졌다 합쳐지고 전체가 늘 보인다. 마지막은 보스 |
| 섬 | **`Islands`** · **`Grid`** | 싸우는 판. 격자에 통행·물·해안·상륙 거리가 얹혀 있다 |
| 전투 | **`Battle`** | 한 섬의 싸움. `step(dt)` 하나가 배·상륙·조준·이동·공격을 전부 민다 |
| 명부 | **`Army`** | 섬을 건너 살아남는 병력. **죽으면 영영 죽는다** |
| 정비 판 | **`Loadout`** | 소환 슬롯마다 하나. 카드가 여기에 값을 치른다 |

⚠ **전투 중에는 손이 안 움직인다.** 시작 전에 다 정하고, 그다음은 구경한다.
⇒ **어디에 내리느냐가 누구와 붙느냐를 정한다. 이게 이 게임의 결정이다.**

## 화면 — **and where the seam is**

| 한국어 | Code | What it is |
|---|---|---|
| 섬 화면 | **`FieldView`** | 지형·해안·바다의 배·몸·체력 |
| 지도 화면 | **`MapView`** | 어디를 지나왔고 어디로 갈 수 있나 |
| 보상 화면 | **`RewardView`** | 이긴 뒤 **카드 여섯 장 중 둘** |
| 껍데기 | **`Game`** | **입력을 읽는 유일한 파일**이고 `sim`과 `view`를 잇는 유일한 자리 |

## 미정 — **⚠ 아래는 설계이고 코드에 없다**

| 한국어 | Code | 상태 |
|---|---|---|
| 아기 | **pup** | **아기 짐승으로 시작해 자란다.** 자람이 **크기**로 보인다 — 스케일이라 그림 값이 0 |
| 빌드가 보이는 법 | — | **미정.** 색조 · 이펙트 · 공격이 나가는 모양 · 수와 대형 · 크기 · 덧붙임 하나 |
| 성장 | — | **미정.** 부위 여섯 조립은 **2026-08-22 저녁에 빠졌다** — 아트 예산 때문이다 |

⚠⚠ **`Loadout`·`RefitView`·「부리」는 빠진 조립의 것이다.** 코드에는 아직 있고, **무엇이 그 자리에
오는지는 안 정해졌다.**

## 도구

| 한국어 | Code | What it is |
|---|---|---|
| 그물 | **net** | 시험 하나. **라벨이 말하는 것보다 적게 재는 초록은 빨강보다 나쁘다** |
| 지도 | **map** | 한 갈래의 계획. `wayfinder`가 갖는다 |
| 티켓 | **ticket** | 질문 하나. 그 답이 **곧** 설계다 |

---

## Where the seams are

`tdd` will not write a test at an unagreed seam. **These are the agreed ones**, and they come from the
folder rule in `CLAUDE.md`:

- **`src/sim/`** — constructible with `.new()`, never touches the tree. **The main seam.** A net drives the
  whole game here in seconds
- **`src/view/`** — reads `sim`, never writes it. **Seam is the paint hook**, not the Node
- **`src/shell/`** — the only reader of `Input`. **Seam is `_ready()`**, which builds the real wiring

**Do not add a seam inside a file.** If something is hard to test, it is in the wrong folder.

⚠ **These three survived three deletions and are not re-decided per game.**
