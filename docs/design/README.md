# docs/design — the GDD, and the forks that were rejected

**Cleared on 2026-08-22 by the user.** Ten concept docs were deleted; the GDD and the eight fork records
stayed. **Everything deleted is still in git** — it was removed because nobody could read it, not because it
was wrong.

**Why the forks stayed and the concepts did not**: a concept doc describes a game that keeps changing, so it
goes stale and then lies. **A fork record describes a decision that was already made, and it does not go
stale — it only gets reversed, and a reversal is written onto the same doc.** Without these, a branch that
was beaten once comes back and gets argued about again.

⚠ **Some of these are marked REVERSED. That is not a reason to delete them.** The reasoning is kept beside
the reversal so the same wrong turn is not taken twice.

---

## The live design

| Doc | What it is |
|---|---|
| **[The cell army GDD](cell-army-gdd.md)** | **「먹을 것을 고르러 간다」.** An autobattler on a node map of islands. A squad of square cells lands by boat on the coastline; combat is automatic; soldiers carry across islands, HP included, and a dead one is dead for good. ⚠ **Its `Implemented` and `Accepted` headers now describe deleted docs.** They are stale until the blueprint is charted again |

## The forks — what was rejected, and why

| Doc | The fork | State |
|---|---|---|
| **[하늘에서 떨군다](dropped-from-the-sky-not-landed-by-boat.md)** | Cells drop from the sky instead of landing by boat | ⚠ **뒤집힘 (2026-08-17)** — 배로 상륙한다. 버린 근거 자체가 틀렸다: *「배는 도착한다의 그림」* 이었는데 **침략하러 가는 배는 도착이 아니다** |
| **[해안선 전체에 상륙한다](open-coastline-over-fixed-docks.md)** | Fixed docks, N per island | **유효 (2026-08-17)** — 막힌 곳이 아니면 해안선 어디로든. 같은 날 먼저 내린 「선착장 N개」를 뒤집는다 |
| **[배는 무한하다](unlimited-boats-not-a-five-boat-cap.md)** | Five boats, one seat each, as a cap | **유효 (2026-08-18)** — 상한을 배로 만들지 않는다. 같은 날 앞선 결정 14번을 뒤집는다 |
| **[커밋은 전투 전에](commit-before-the-fight-not-during.md)** | Decide during the fight | ⚠⚠ **일부 뒤집힘 (2026-08-19)** — ***「저 배만 좀 참여하는 걸로」***. 전투 중에 손이 움직이되 **배에만**. 상륙한 병사는 여전히 못 건드린다 |
| **[빌드는 정비 화면에서 설계한다](build-is-designed-not-inherited.md)** | What you ate becomes the build | **유효 (2026-08-18)** — 레벨 디자인 비용으로 기각. ⚠ **GDD의 「경로가 곧 빌드」를 뒤집는다.** 단 이 문서가 설계 대상으로 적은 「다섯 칸」은 같은 날 나중에 사라졌다 |
| **[층마다 하나](one-node-per-floor-not-two-columns.md)** | Two columns, one taken from each | **유효 (2026-08-19)** — ***「층마다 둘 중 하나」***. 슬더슬 모양 |
| **[몸은 코드가 그리는 선](the-body-is-a-line-drawn-by-code.md)** | The body is a sprite | **유효** — 둥근 사각형 외곽선에 가운데 점 하나, 코드로 그린다. **그림으로 갈아끼우는 건 나중에 열어둠** |
| **[메타는 해금이지 수치가 아니다](meta-unlocks-not-stat-boosts.md)** | Between-run progress raises numbers | ⚠ **뒤집힘 (2026-08-16)** — 둘 다 들어간다. **함정 자체는 안 사라져서** 근거를 남겨뒀다. 지금은 없는 게임을 위해 정해진 것 |

---

## What a doc in here looks like

**Every fork doc opens with a `Status:` line** — `valid`, `REVERSED`, or `partially reversed` — with the
date and who decided it. **A reversal is written onto the existing doc, never by deleting it.**

⚠ **This folder no longer carries `Implemented` / `Accepted`.** Those two axes tracked concept docs against
the running game, and the concept docs are gone. **Whatever replaces them will be decided when the blueprint
is charted again** — until then, what is built is read out of `src/` and `tests/nets/`, not out of here.
