Type: grilling
Status: open

# 계단이 붕 떠 보인다

## 무엇을 정해야 하나

**계단의 어디가 떠 보이는가 — 꼭대기인가 밑동인가.**

## 어디서 왔나

**2026-08-29, 사용자** — 「뭔가 계단이 너무 붕뜨네」.

## ⚠ 잰 것 — **높이는 안 어긋난다**

**계단 꼭대기와 2층 윗면이 둘 다 1.14 다.** `TOP_H + STOREY` 와 `TOP_H + 2 * LEVEL_H` 가 같은 수다.
⇒ **떠 보이는 것은 높이가 아니라 그림이다.**

## 남들은 어떻게 하나

**Bad North 는 절벽 밑동을 덤불로 감춘다** (2026-08-28 조사, `docs/reference/` 의 노트).
사용자가 보낸 화면에서도 모든 절벽 밑에 덤불이 줄지어 있다 — **땅에 앉은 것처럼 보이게 하는 것이 그것**이다.
⚠ **우리 섬에는 장식이 하나도 안 놓여 있다** (`island.json` 의 `props` 가 빈 배열이다).

## 후보

- **밑동에 어두운 띠** — `WALL_AO` 를 계단에도 태운다. 절벽 후보 C 가 그것이었고 사용자는 B 를 골랐다
- **밑동에 덤불** — Bad North 가 하는 것. 장식을 놓는 첫 자리가 된다
- **계단을 2층 벽 쪽으로 더 밀어 넣는다** — 지금 계단은 벽 밖에 서 있다


## ⚠⚠ **THE STAIR THIS TICKET WAS WRITTEN AGAINST NO LONGER EXISTS** (2026-08-29)

**티켓 06 rebuilt it whole.** The one on the island now is **four treads, no kerb, one 블록**, finished
the way a storey is — a rock wall with a turf plate inset on top of each tread. The old one had **six
treads and a kerb down each side**, and the block under it was RAISED; the new block is flat and the
staircase is a separate mesh laid on it.

⇒ **Every measurement below was taken on the old shape.** Re-measure before acting on any of it.
