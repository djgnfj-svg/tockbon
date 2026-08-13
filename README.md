# 탁본 (Tockbon)

**다시 짓는 중이다.** 2026-08-12에 게임을 전부 지웠고, 같은 날 새 게임을 시작했다.
**첫 루프는 돌아가고, 만든 사람이 해보고 재미를 확인했다.**

## 지금 만드는 것

**세포 하나가 갈라져 무리가 되고, 잡아먹은 짐승의 부위를 몸에 달아 진화하는 탑다운 로그라이크.**
`F`로 몸을 반씩 쪼개 무리를 늘리고, 흩어 먹이고, `V`로 한 번에 삼킨다.
레벨업 카드는 부위를 주고, 부위는 몸의 열한 칸을 놓고 다툰다.
서식지의 **보스**를 삼키면 판이 끝난다.

**8월 목표는 초원 한 판**이다 — 까마귀와 말, 보스 하나, 말 부위 셋.

설계는 [docs/design/cell-game.md](docs/design/cell-game.md)와
[docs/design/stages-and-evolution.md](docs/design/stages-and-evolution.md)에 있고,
**둘이 어긋나면 뒤쪽이 최신이다.** 지금 짓는 순서는
[docs/plans/1.ready/](docs/plans/1.ready/grassland-whole-loop.md)에 네 장으로 쪼개져 있다.
**하지 않기로 한 것과 이유**는 [docs/decisions/](docs/decisions/)에 있다 —
시뮬레이션을 왜 버렸는지, 멀티를 왜 미뤘는지, 마법진을 왜 통째로 접었는지.

## 지웠던 것 — 2D 횡스크롤 마법 로그라이크

여덟 달치였다. 마법진을 조립해 순열로 마법을 만들고, 지형이 셀 단위로 파이고, 불이 번지고
물이 흐르는 게임. **[▶ 브라우저에서 플레이](https://djgnfj-svg.github.io/tockbon/)** ·
**[▶ 영상 (1분)](https://www.youtube.com/watch?v=fbQDCyPYMOw)**

지운 이유는 하나로 줄여 말할 수 있다 — **여덟 달 동안 재미있는 순간이 한 번도 없었고,
그 게임은 만든 사람이 좋아하는 종류가 아니었다.** 근거는 `docs/next-game.md`에 있다.

소스는 태그 `v1-sim`에 그대로 있다.

## 남긴 것

| | |
|---|---|
| `CLAUDE.md` · `.claude/` | AI 하네스 — 에이전트 정의, 스킬, 세션 규칙 |
| `tests/run_nets.ps1` | 검증 러너. **새 게임의 그물 열 장 · 검사 111개가 1초에 돈다** |
| `tools/pixel/` | 로컬 ComfyUI 픽셀아트 생성. 크레딧이 안 든다 |

외부 에셋은 폰트 하나뿐이다: Noto Sans KR (SIL OFL 1.1, `assets/font/OFL.txt` 동봉).
엔진은 Godot Engine 4.7.1 (MIT).
