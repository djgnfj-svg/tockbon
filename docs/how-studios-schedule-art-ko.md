# 회사들은 그림을 언제 붙이는가 — 실제 사례

**Implemented**: 해당 없음 (참고 자료)
**Accepted**: unseen

**왜 이 문서가 있나**: 사용자가 게임 개발이 처음이라 **데이터가 없으면 이쪽 말이 그냥 맞는 것처럼
들린다**고 직접 말했다. "코드로 하죠"가 편의였는지 판단이었는지 사용자가 스스로 갈라야 한다.
그래서 **사례와 출처만** 모았다. 아래 결론도 사례 뒤에 놓았고, 사례가 결론을 이긴다.

---

## 0. 먼저, 업계에는 이름 붙은 답이 있다 — **버티컬 슬라이스**

"그림을 먼저냐 나중이냐"는 업계가 이미 **둘 다 아니다**로 답해 둔 질문이다.

- **프리프로덕션(preproduction)** — 프로토타입으로 재미를 찾는 단계. 그림은 임시
- **버티컬 슬라이스(vertical slice)** — 게임의 **작은 한 조각**을, 그림·소리·UI까지
  **최종 품질로** 만든 것. 프리프로덕션의 마지막 산출물
- **프로덕션(production)** — 나머지를 그 기준에 맞춰 **양산**

⇒ **아트는 "스타일 확정"과 "양산"이 다른 단계다.** 스타일 확정은 일찍(슬라이스), 양산은 늦게.
AAA에서는 버티컬 슬라이스 리뷰가 **프로덕션 진입 게이트**이고, 퍼블리셔가 돈을 여기서 낸다.

출처: [Ask a Game Dev — The Vertical
Slice](https://askagamedev.tumblr.com/post/77406994278/game-development-glossary-the-vertical-slice) ·
[Vertical Slice: Definition & Examples](https://tonogameconsultants.com/vertical-slice/)

---

## 1. 게임플레이를 먼저 확정한 쪽

### 밸브 — 『하프라이프』

원래 일정이 거의 끝난 1997년 9월, **"게임이 재미없다"**는 판정이 나왔다. 만들어 둔 것을 상당 부분
버리고 **Cabal**이라는 여러 직군 혼성 소그룹이 설계를 다시 했다. 최종 레벨은 컨셉 아트에 더
가깝게 맞추되 **게임플레이를 깨지 않는 선에서** 조정됐다. 이 과정에서 나온 개념이
**experiential density**(단위 시간·면적당 플레이어에게 일어나는 일의 양)다.

출처: Ken Birdwell, [The Cabal: Valve's Design Process For Creating
Half-Life](https://www.gamedeveloper.com/design/the-cabal-valve-s-design-process-for-creating-i-half-life-i-)
(Gamasutra, 1999)

### 닌텐도 — 『슈퍼 마리오 64』

**레벨이 하나도 만들어지기 전에**, 미야모토는 마리오를 작은 **"정원"**에 두고 뛰고 물건 집는 것만
몇 달을 다듬었다. 마찰과 무게감을 그 정원에서 잡았고, 레벨은 그때까지 **스케치와 메모**뿐이었다.

출처: [Super Mario 64 — 1996 Developer Interviews](https://shmuplations.com/mario64/) ·
[Some Cool Stories About The Making Of Mario 64](https://kotaku.com/some-cool-stories-about-the-making-of-mario-64-1786928623)

### 뱀파이어 서바이버즈 — poncle (루카 갈란테)

**산 에셋팩**의 스프라이트를 그대로 썼다. 개발자 본인 설명: 뭔가에 의미를 부여해야 할 것 같은
기분이 들 때마다 **스스로를 멈추고, 에셋팩에서 아무 스프라이트나 골라 아무 이름을 붙였다.**
나중에 문제가 된 일부는 교체됐다. 이 게임은 그 상태로 얼리액세스에서 성공했다.

출처: [NME 인터뷰](https://www.nme.com/features/gaming-features/vampire-survivors-creator-luca-galante-talks-quitting-his-job-to-fulfil-his-promise-3153107) ·
[PC Gamer](https://www.pcgamer.com/vampire-survivors-didnt-rip-off-castlevania-sprites-after-all/)

### 발라트로 — LocalThunk (1인)

개발 2주차 프로토타입은 **전부 남의 플레이스홀더**였다. 본인 말: *"이때는 픽셀아트나 셰이더를
할 줄 몰라서 저 에셋들은 내가 만든 게 아니고 전부 플레이스홀더였다."*
픽셀아트는 **나중에 배워서** 직접 그렸다.

출처: [LocalThunk, The Balatro Timeline](https://localthunk.com/blog/balatro-timeline-3aarh) ·
[본인 X 게시물](https://x.com/LocalThunk/status/1811781611542687859)

---

## 2. 그림이 정체성인 쪽 — 그런데도 시작은 게임플레이였다

### 컵헤드 — Studio MDHR

세상에서 아트 비용이 가장 큰 인디 중 하나다. 1930년대 방식 그대로 **종이에 연필·잉크·수채**로
전 프레임을 그렸고, **게임플레이 한 프레임에 평균 25분**, 출시 시점에 **약 5만 장**, 개발 **7년**.

⚠ **그런데도 프로젝트는 게임플레이에서 시작했다** — 게임 매체가 그 점을 따로 짚는다.
이 게임이 증명하는 건 "그림을 먼저 하라"가 아니라 **아트 파이프라인의 단가를 늦게 알수록 비싸다**는
것이다. 프레임당 25분은 5만 장을 곱하기 전에 알아야 하는 숫자다.

출처: [The unique development constraints of Cuphead's painstakingly hand-drawn
art](https://www.gamedeveloper.com/design/the-unique-development-constraints-of-i-cuphead-i-s-painstakingly-hand-drawn-art) ·
[The making of Cuphead (GamesRadar)](https://www.gamesradar.com/the-making-of-cuphead/)

---

## 3. 반대 근거 — **사용자 쪽 직관을 지지하는 자료**

이걸 빼면 이 문서가 한쪽만 고른 것이 된다.

**유니티 공식 블로그: 「플레이스홀더 에셋 문제 — 프로그래머 아트가 플레이테스트를 죽인다」**

요지: **플레이스홀더는 플레이테스트 피드백을 오염시킨다.** 어차피 교체할 그림이면
"이 구간이 무섭게 느껴지나" 같은 질문에 **잘못된 답**이 돌아온다.

그래서 그 글이 제시하는 것이 **"비주얼 미니멈"** 셋이다:

1. **알아볼 수 있는 실루엣** — 플레이어가 그게 무엇인지 알 것
2. **색 구분** — 적이 배경에서 분리될 것
3. **기본적인 재질 구분**

그리고 **플레이스홀더가 정당한 때**도 같이 적어 뒀다: **순수 메커닉만 격리해 테스트할 때**,
그리고 **죽을 확률이 높은 컨셉의 첫 주**.

출처: [The placeholder asset problem: How programmer art kills
playtests](https://unity.com/blog/placeholder-asset-problem) (Unity 공식 블로그)

⇒ **이 기준으로 이 게임을 재면**: 루프는 이미 돌고 재미도 확인됐다. 첫 주 컨셉이 아니고 순수
메커닉 격리 테스트도 아니다. **비주얼 미니멈이 필요한 시점이 맞다** — 사용자의 직관 쪽이다.

---

## 4. 그래서 사례들이 함께 말하는 것

| 질문 | 사례가 주는 답 |
|---|---|
| 그림을 마지막에 몰아서? | **아무도 그렇게 안 한다.** 컵헤드조차 단가를 일찍 알아야 했다 |
| 그림을 먼저 다? | 이것도 아니다. 마리오 64는 레벨도 없이 정원에서 몇 달 |
| 그럼 뭐? | **한 조각만 최종 품질로 먼저.** 그게 버티컬 슬라이스이고 업계 표준 게이트다 |
| 임시 그림은 언제까지? | **메커닉 격리 테스트와 첫 주까지.** 그 뒤엔 피드백을 오염시킨다 |
| 최소한 무엇은 있어야? | **실루엣 · 색 구분 · 재질** 셋 (유니티) |

**이 게임에 옮기면**: 지금 크리처는 반지름만 다른 원 셋(12 · 22 · 48)에 색 셋이다.
**색 구분은 있고 실루엣이 없다.** 유니티 기준 셋 중 하나가 비어 있는 상태다.

---

## 5. 추천 — 근거를 붙여서

**초원 한 장면을 최종 품질로 만든다.** 종 표를 전부 설계하는 것도, 코드로 대충 넘기는 것도 아니다.

1. **파츠 6종 열기** — `Parts.DROPS`에서 말 갈기·말 폐활량을 켠다. **한 줄**이고, 4종으로는
   3레벨이면 몸이 완성돼 "먹어서 달라지는 맛"을 잴 대상 자체가 없다. 말 특성도 같이 살아난다
2. **한 판 플레이** — 플랜 4가 녹색이 되면. **몸이 파츠로 바뀌는 화면을 아직 아무도 본 적이 없다**
   (플랜 3은 플레이도 `verify-look`도 안 됐다). 유니티 기준의 "실루엣이 부족한가"를 여기서 눈으로 잰다
3. **버티컬 슬라이스 한 장** — 호스트 + 클론 + 까마귀 + 말 + 보스 + 바위 + 물 + 바닥이 **한 화면에**,
   최종 품질로. 이게 되면 나머지는 이 기준에 맞춰 양산하고, **안 되면 방향이 틀린 것을 지금 아는 게 싸다**
4. **그 기준으로 양산** — 그리고 이때 비로소 종을 늘릴지 결정한다

⚠ **1번과 3번은 순서를 바꿔도 된다.** 슬라이스를 먼저 만들면 아트 단가를 먼저 알게 되고(컵헤드의
교훈), 파츠를 먼저 열면 재미를 먼저 알게 된다(마리오 64의 교훈). **어느 쪽을 먼저 알고 싶은지는
사용자가 고를 문제이지 이쪽이 정할 문제가 아니다.**
