Type: task
Status: resolved


✅ **CLOSED 2026-08-28.** `Grid.can_step` refuses a diagonal unless **both shoulders** are steppable
from the origin. ⚠⚠ **Stricter than this ticket asked for** — it wanted a refusal only when both were
blocked — because a body slides from tile centre to tile centre and is physically over both shoulders on
the way; one blocked shoulder is one wall corner walked through. `_straight_is_all_water` requires both
for the same reason.
⚠ **The 「two places」 this ticket feared was not true**: `flow_field` and `step_toward` both ask
`can_step`, so one edit reached both.
⚠ **The island did not seal itself** — `net_tiers` walks every walkable tile and none is cut off.
# 몸이 대각선으로 벽 모서리를 지나간다

## 무엇이 되면 끝인가

**막힌 조각 둘이 대각선으로 맞닿아 있으면 그 사이를 못 지나간다.**

## 왜 이 티켓이 있나

**2026-08-28 에 사용자가 봤다** — 「이동할때 그냥 벽을 뚫는 문제도 있는상태」.

## 무엇이 원인인가 — **어깨 규칙이 없다**

판 위의 걸음은 여덟 방향이고, **갈 수 있는지를 묻는 함수는 도착 조각 하나만 본다.** 통행 가능한지와
눈금 차이가 1 이하인지만 묻고, **대각선으로 갈 때 양옆에 무엇이 있는지는 안 묻는다.**

⇒ 조각 둘이 대각선으로 맞닿아 있으면 그 사이를 막고 선 벽 모서리를 그냥 가로지른다.

## ⚠⚠ 짝이 이미 물길에 있다

**배가 다니는 물길에는 이 규칙이 있다** — 대각선으로 가려면 **양옆 어깨 조각 중 하나는 물이어야
한다**. 그 함수의 주석이 실패형까지 적어 두고 있다: 물 (4,2) 와 (3,3) 이 한 걸음이면서 (4,3) 과 (3,2)
가 둘 다 땅이면, 배가 물이 하나도 없는 이음매를 건넌다.

⇒ **뭍에 그 짝이 없을 뿐이다.** 새로 발명할 것이 없다.

## ⚠ 두 자리에 같이 넣어야 한다

**흐름장을 만드는 곳과 한 걸음을 고르는 곳이 둘 다 여덟 방향을 돈다.** 한쪽에만 넣으면 장은 못 가는
길을 통해 값을 퍼뜨리고 걸음은 그 값을 보고 멈춘다 — **선 채로 안 움직이는 몸**이 그 모양이고, 이
저장소가 그 실패를 이미 한 번 겪었다.

## ⚠ 재는 것

**그물이 이 라운드에 209 개 빨강이다.** 이 티켓이 그 수를 늘리는지 줄이는지가 판정이고, 늘어난다면
어디가 이 규칙에 기대고 있었는지가 새로 알게 되는 것이다.
