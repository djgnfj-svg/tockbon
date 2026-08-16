# 무엇이 위치를 결정으로 만드나 — 아홉 게임이 낸 서로 다른 답

**Implemented**: none — `src/`는 비어 있다
**Accepted**: 없음. **아직 아무것도 안 골랐다**

사용자가 낸 문제: *"특정 위치로 특정 부대를 이렇게 보낸다거나 내가 이렇게 한쪽으로 쭉 보내면 재미가
없을 거 같아. 뭔가 좀 더 전투적인, 전략적인 면이 있어야 될 듯?"*

⇒ **「떨구냐 배치냐」보다 앞서는 질문이다.** 위치를 결정으로 만드는 규칙이 없으면 떨구든 배치하든
「한쪽으로 쭉」이 정답이 된다. 이 문서는 실제로 출시된 게임들이 그 규칙을 어떻게 지었는지만 모은다.

---

## ⚠ 먼저, 이 리포지토리가 Bad North를 잘못 인용해 왔다

**Bad North는 「배치하고 끝」이 아니다. 전투 중에 부대를 계속 옮긴다.**
Oskar Stålberg 본인: *"We have this very low granularity of interaction, which means that mostly players
will be simply positioning their squads on a grid and then each of the units in that squad decide
how/when to attack from there."* — 조작을 없앤 것이 아니라 **입도를 낮춘 것**이다.
([Nintendo 인터뷰](https://www.nintendo.com/en-gb/News/2018/April/Interview-Taking-on-hordes-of-invading-Vikings-in-Bad-North-1368315.html) ·
[NWR 리뷰](http://www.nintendoworldreport.com/review/48095/bad-north-switch-review))

⇒ **이 게임의 「무조작」을 Bad North로 정당화할 수 없다.** 참조점으로는 남지만, 근거로는 못 쓴다.

---

## 표 — 조작이 필요한가로 갈라서

**이 게임은 커밋 후 조작이 없다.** 그러니 오른쪽 칸이 「있음」인 것은 그대로 가져올 수 없다.

| 게임 | 규칙 | 무엇 대 무엇을 저울질하나 | 커밋 후 조작 |
|---|---|---|---|
| **Into the Breach** | **적의 다음 턴 행동이 대상 칸까지 전부 미리 보이고 명중 난수가 없다.** 밀치기로 공격을 빗나가게 하는 것이 직접 딜보다 자주 정답 | 건물을 부수게 둘까 vs 메크를 버릴까 | **없음** |
| **Mechabellum** | 유닛은 **산 그 라운드에만** 자유 이동, 이후 **그 자리에 고정**되어 매 라운드 같은 지점에서 출격·사망·재출격 | 지금 이기는 배치 vs 다음 라운드 상대의 카운터. **위치가 되돌릴 수 없는 과거의 투자가 된다** | **없음** |
| **TFT** | 최근접 타겟팅 + **거리에 반응하는 능력** (저격형은 헥스 거리에 비례해 피해가 오른다) | 딜러를 뒤로 뺄수록 안전하나 사거리 밖이 되고, 구석에 몰면 광역기에 같이 쓸린다 | **없음** |
| **Clash Royale** | **자기 진영에만 놓을 수 있고**, 상대 타워를 부수면 다리 너머 작은 pocket이 열린다 | 뒤에 놓으면 안전하나 도착이 느려 대응 시간을 주고, 다리 앞은 즉시 압박이나 내 대응 시간이 없다 — **위치가 시간으로 환산된다** | **없음** |
| **Loop Hero** | 영웅 위치는 결정 대상이 아니다. **지형 카드를 루프 어디에 놓을지**를 정하고, 놓은 타일이 적을 소환하며 보상도 늘린다 | **모든 배치가 보상과 난이도를 동시에 올린다** — 「어디를 지킬까」가 **「얼마나 감수할까」**로 바뀐다 | **없음** |
| Bad North | 섬 하나에 부대 최대 넷, 적은 **어느 모서리로든** 상륙하고 **동시에 여러 지점**에 붙는다 — 상륙 지점이 부대 수보다 많다 | 어디를 포기할까. 그리고 Flee — **지휘관의 목숨 vs 남은 집의 코인** | **있음** |
| They Are Billions | 좀비는 **벽에 부딪히면 부수느라 멈춘다.** 그래서 병목이 아니라 **병목이 다시 넓어지는 뒤쪽**에 벽을 세운다 | 좁히면 화력이 집중되나 광역 사거리에 다 모이고, 넓히면 벽 HP는 크나 화력이 분산 | 부분 |
| Pikmin | 명령 수단이 **한 마리씩 좌표로 던지는 것**뿐 | 던지는 실시간 시간 자체가 비용이라 **「전부 한쪽에」가 물리적으로 느리다** | **있음** |
| **Despot's Game** | 전투 전 배치만, 조작 0, **최근접 타겟팅** | — | 없음 |

---

## ⚠ 가장 날카로운 대비 — TFT와 Despot's Game은 **같은 규칙인데 결과가 반대다**

둘 다 「배치하고 최근접을 때린다」이고 둘 다 커밋 후 조작이 없다.
**TFT에서는 위치가 핵심 결정이고, Despot's Game에서는 위치가 결정이 아니다.**

**차이는 하나뿐이다: 거리와 방향에 반응하는 능력이 있는가.**
TFT의 저격형은 거리에 비례해 피해가 오르고 광역기는 뭉친 것을 벌한다. Despot's Game에는 그런 것이
없고, **개발사가 자동 정렬 버튼을 넣어 스스로 인정했다.** 리뷰가 짚은 결정 지점도 좌표가 아니라
「어떤 무기를 입혀 어떤 클래스로 만들까」였다.
([Despot's Game 리뷰](https://gamecritics.com/eugene-sax/despots-game-dystopian-army-builder-review/) ·
[TFT 포지셔닝](https://mobalytics.gg/blog/tft/tft-positioning-guide-how-to-get-the-most-from-your-units/))

⇒ **「어디에 떨구나」를 결정으로 만드는 것은 지형도 아니고 적의 방향도 아니다.
사거리와 광역이다.** 병사가 전부 같은 거리에서 같은 방식으로 때리면, 어떤 지형을 깔아도 위치는
결정이 되지 않는다. ⇒ **이것이 「교전 규칙」이 미정 목록의 맨 위여야 하는 이유다.**

---

## 반론 — 각 접근이 실제로 치른 값

**무조작 + 자유 배치 (Loop Hero · Despot's Game) — 이 설계에 그대로 꽂힌다**
> *"Because you have no direct control over your character, it means that you always want to play it
> safe when it comes to card placement. This reduces not only the number of viable ways to play Loop
> Hero, but also what cards to take."* — [Game Wisdom](https://game-wisdom.com/analysis/loop-hero)

**무조작은 배치의 선택지를 늘리는 것이 아니라 줄인다.** 되돌릴 수 없으니 안전하게 두게 된다.
Despot's Game은 Metacritic mixed — *"The complete lack of control in battles and the many ways the game
sabotages your ability to make strategic choices really hurts this game."*

**고정 배치 (Mechabellum)** — 유닛이 초반 표적에 락되면 나중에 더 좋은 표적이 나와도 낭비된다.
**읽을 수 없는 형태로 벌을 준다.** ⇒ 개발사가 **이동 수단 다섯 종을 나중에 추가했다** (판매 · 밀치는
스킬 · 이동 아이템 · 라운드당 1기 이동 카드 · 공중 유닛). **순수한 고정 배치는 출하 상태로 유지되지
못했다.** ([Steam 토론](https://steamcommunity.com/app/669330/discussions/0/4518883844569560391/))

**완전 정보 텔레그래프 (Into the Breach)** — *"more puzzle than strategy"*. 매 턴 최적해가 하나인
퍼즐이 되어 긴장이 아니라 계산이 된다. ⚠ **그리고 실시간에 그대로 못 옮긴다 — ItB의 완전 정보는
턴이 멈춰 있어서 성립한다.** ([GameCritics](https://gamecritics.com/mike-suskie/into-the-breach-switch-review/))

**Bad North** — Metacritic 65~74, Destructoid 5.5/10. *"shallow combat"*, 병종이 셋뿐이라 두 시간이면
다 본다. ⇒ **위치 규칙 하나만으로는 깊이가 안 난다.**
([Destructoid](https://www.destructoid.com/reviews/review-bad-north/))

---

## 확인 못 한 것 — 추측하지 않았다

- **Bad North의 섬이 작은 이유에 대한 개발자 직접 진술**: 없다. 절차적 생성의 이유로 개발자가 댄 것은
  전술성이 아니라 **가독성**이었다 (전투에서 벌어지는 것은 다 보여야 한다 → 블록 섬, 격자 배치)
- **Clash Royale의 자기 절반 제한에 대한 Supercell 1차 자료**: 없다. 규칙만 확인, 의도는 추론
- **Bad North의 「동시에 세 척」 수치**: 전략 가이드 출처이고 1차 자료가 아니다
