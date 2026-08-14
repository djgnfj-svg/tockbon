# 적대적 검토 — 2026-08-14 (2차)

**대상**: `docs/plans/1.ready/` 네 장 + 인덱스 · `docs/design/` · `docs/decisions/` 31개 · `CLAUDE.md`
**방식**: 서로를 모르는 opus 에이전트 다섯이 각자 다른 각도로 공격. 파일은 하나도 수정하지 않았다.

| 에이전트 | 각도 | 건수 |
|---|---|---|
| joints | 계획서 **사이**의 이음매 (생산자/소비자 불일치) | 19 |
| design-drift | 설계층 대 계획층 (죽은 규칙이 살아 있는가) | 15 |
| decisions | 결정 문서 대 나머지 전부 | 11 |
| buildable | 기억 없는 빌더로 걸어보기 | 4장 판정 + 30여 질문 |
| fake-nets | 계획된 검사 68개가 라벨만큼 재는가 | 20 + 미검사 9 |

**총 74건. 이 문서는 그중 서로 다른 에이전트가 독립적으로 같은 것을 짚은 순서로 배열한다** — 교차 확인이 심각도보다 나은 신호였다.

✅ **네 계획서 모두 이 검토를 반영해 다시 쓰였다 (2026-08-14).** §0의 "플랜 4는 지을 수 없다"는 **답이 끝난
판정**이지 열려 있는 상태가 아니다. **한 곳만 이 문서가 낡았다**: §4가 말을 1.05×로 낮추라고 했는데,
그날 늦게 나온 설계가 반대로 갔다 — **말은 잡는 게 아니라 몬다.** 남은 것은 속도 서열을 지킬 검사가
없었다는 지적이고, 그건 플랜 4에 리터럴 검사로 들어갔다.
이 문서 본문은 **고치지 않는다.** 무엇이 어떻게 새어 나갔는지가 기록의 값이다.

---

## 0. 판정 — 플랜 4는 지금 지을 수 없다

| # | 플랜 | 판정 |
|---|---|---|
| 1 | `run-shell` | BUILDABLE WITH GUESSES |
| 2 | `hands-and-commands` | BUILDABLE WITH GUESSES |
| 3 | `body-and-parts` | BUILDABLE WITH GUESSES |
| 4 | `grassland-field` | **NOT BUILDABLE** |

플랜 4가 닫는다고 선언한 두 가지가 통째로 비어 있다 — **필드가 무엇으로 채워지는가**(까마귀:말 비율 없음, `_spawn_critter`가 보스를 굴리는지 없음, 까마귀 속도 숫자 없음, `critter_hp` 초기화 없음)와 **액티브가 무엇에 맞는가**(함수도 시그니처도 판정 규칙도 없음. `RANGE`가 "px from the body edge"인데 누구의 edge인지, 대상 반지름을 포함하는지, 한 번에 여럿을 맞히는지 전부 없음).

이건 스켈레톤 갭이 아니다. 비율을 추측하면 필드가 전부 까마귀거나 전부 말일 수 있고, 그러면 플랜 4의 수용 질문("말이 안 잡히던 게 잡히는 순간을 플레이어가 이름 붙일 수 있는가")이 **애초에 답할 수 없게 된다.**

**네 문서에 `TBD`·`TODO`·`?`가 하나도 없다.** 그래서 이 구멍들은 표시가 없고, 빌더는 "빠졌다"가 아니라 "내가 못 찾았다"로 읽는다.

---

## 1. 네 에이전트가 같이 짚은 것 — force가 저장값인가 파생값인가

- `cell-game.md:216-218` — "**force has to be derived from the stats** — see `stages-and-evolution`"
- `stages-and-evolution.md:89` — "⚠ **Force is a STORED number.** Recomputed, `F` becomes free"
- `hands-and-commands.md:42` — "STORED, never recomputed. **the single most load-bearing sentence in the plan**"

GDD가 단순히 반대하는 게 아니라 **자기를 반박하는 문서를 근거로 인용한다.** 그리고:

- `hands-and-commands.md:94`가 같은 파일 안에서 `force = FORCE_START + level` 공식을 남겨뒀다 — `:42`가 죽인 그 문장
- 플랜 3이 `force_bonus()`라는 **파생 함수**로 다시 들여온다(`body-and-parts.md:124`). `force[0] + force_bonus()`면 이중 계상, `force[0]`만 읽으면 아무도 안 부르는 순수 함수
- **소화 경로가 `force[0]`을 되돌린다는 말이 없다**(`:141` "the old one is digested") — 부품을 덮어쓸 때마다 유령 force가 쌓이고 `F`가 그걸 증식시킨다
- 이 갈래에 **결정 문서가 없다.** 기각된 쪽(파생)이 왜 죽었는지는 플랜 2 본문에만 있고, 플랜은 `3.done`으로 가면 아무도 안 읽는다

**수리**: `cell-game.md:216-218` 문장 교체 · `hands-and-commands.md:94` 삭제 · `force_bonus()` 삭제하고 `wear()`/digest가 `swarm.force[0]`을 직접 `+=`/`-=` · `docs/decisions/force-is-stored-not-derived.md` 신설.

---

## 2. 세 에이전트 — `cells_eaten`이 두 번 세어지고, 넷 6과 넷 7이 서로를 부정한다

`run-shell.md:103` — "`cells_eaten`, **incremented wherever `banked` or `carried` is**, and never decremented"

문장 그대로면 `swarm.gd:308`의 `_absorb()`(`banked += carried[i]` — 이동이지 섭취가 아니다)와 클리어 비트의 입금에서 **같은 세포를 두 번 센다.** 엔딩의 "312 cells"가 무리가 뚱뚱할수록 부풀어 오른다. 플랜 2가 `_absorb`을 지우지만 **플랜 1이 먼저 지어진다.**

그리고 같은 문서의 검사 둘이 배타적이다:
- 넷 6 — "After a clear, `result.cells` **includes** what the absorbed clones carried"
- 넷 7 — "After a death, a clone's `carried` is **not** in `result.cells`"

`cells_eaten`은 감소하지 않는다고 규정했으므로 **넷 7은 통과할 수 없다.** 넷 7을 만족시키면 `cells`는 "먹은 것"이 아니라 "회수한 것"이 되어 그 필드를 만든 이유가 사라진다(`:100` "The ending must report what the run ATE, not what it banked").

**수리**: `cells_eaten`은 **먹이/사체가 처음 소비되는 자리 한 곳에서만** 오른다. `_absorb()`에서도 클리어 비트 입금에서도 안 오른다. 넷 7을 뒤집는다.

---

## 3. 세 에이전트 — `EAT_RADIUS`는 존재하지 않고, 사용자가 이미 한 번 잡은 버그가 무방비로 재발한다

`grassland-field.md:141` — "A body standing within **`EAT_RADIUS`** of a corpse"

전 계획서 통틀어 1회, Numbers 표에 없음. 실재하는 것은 `EAT_RADIUS_HOST` (26.0)와 `EAT_RADIUS_CLONE` (16.0) 둘이다. 하필 이 상수인 이유가 `rules.gd:62-64`에 적혀 있다:

> at 12px, smaller than the host's own 14px radius, food had to be run over dead centre and hunting read as broken. **Reported by the user on the first play, which is the only instrument that could have found it.**

**같은 형태의 두 번째 구멍**: `hands-and-commands.md:227`이 `BODY_RADIUS = 14.0`을 sim 상수로 도입하는데 `look.gd:23`의 `CLONE_RADIUS := 8.0`은 그대로다. 플랜 4의 "Reaching a clone kills it outright"가 14px를 쓰면 **보이는 몸에서 6px 떨어진 곳에서 클론이 죽는다.**

**그리고 현재 넷이 이걸 구조적으로 못 잡는다.** `net_eat_carry.gd:24,30`이 먹이를 `Rules.EAT_RADIUS_CLONE ± 1`에 놓는다 — 경계가 검사 대상에서 나온다. 상수를 5.0으로 내려도 초록이다.

**수리**: `Rules.CORPSE_EAT_RADIUS` 명명 + 몸에 따라 둘 중 하나 · `Rules.CLONE_BODY_RADIUS = 8.0` 신설 · **상수 대 상수 검사** `EAT_RADIUS_HOST > BODY_RADIUS`, `CORPSE_EAT_RADIUS > BODY_RADIUS`. 세 줄이고 영원히 산다.

---

## 4. 두 에이전트 — 말이 클론보다 빠르다. 이 종의 역할 전체가 숫자 하나로 무효

`grassland-field.md:230` — `HORSE_SPEED | 1.15 × host | faster than WASD, **catchable by a swarm**`
`grassland-field.md:78` — "It is the species that has to be caught with the swarm rather than with `WASD` — **which is what makes `3` a key worth pressing.**"
`rules.gd:25-26` — `HOST_SPEED := 200.0` · `CLONE_SPEED_FOLLOW := 215.0`

**1.15 × 200 = 230 > 215.** 무리로도 못 잡는다. 플랜 4가 존재하는 이유 중 하나가 산술로 무너진다.

**그리고 이걸 지킬 검사가 사라진다.** `net_hunt.gd:18-19`가 지금 `HOST_SPEED > CRITTER_SPEED > CLONE_SPEED_SCATTER`를 단언한다. 플랜 4는 "**This breaks the speed ordering** … Rewrite that comment in the same commit"이라 적고 **새 서열을 지킬 검사는 한 줄도 계획하지 않았다.** 새 서열(말 > 호스트 > 까마귀 > 흩어진 클론, 보스 0.75×)이 명시조차 안 됐고, 명시 안 된 것은 지킬 수 없다.

부수: 속도 순서 주석은 `rules.gd:10-12`와 `:23-24` **두 군데**인데 플랜 4는 하나만 부른다 — 인덱스가 적어둔 "counted in one file and it lived in four"가 같은 커밋에서 재발한다.

**수리**: `HORSE_SPEED`를 `1.05×`(210 < 215)로 · `HORSE_SPEED > HOST_SPEED`와 `HORSE_SPEED < CLONE_SPEED_FOLLOW` 두 검사를 리터럴로 · 주석 두 곳.

---

## 5. 두 에이전트 — 다시 하기를 누르면 화면이 죽은 월드에 얼어붙는다

`run-shell.md:45,48` — `start()`/`restart()`가 매번 새 `World`를 만든다
`run-shell.md:230` — "**Build the children once in `_ready()`** and toggle `visible`"
`main.gd:22,35` — `view.world = world` · `hud.world = world`, `_ready()`에서 한 번뿐

**재배선하는 사람이 없다.** 새 월드는 돌고 화면은 이전 런을 그린다 — `CLAUDE.md`가 signature fake라 부르는 "화면은 바뀌는데 심은 안 바뀐다"의 정확한 반대판.

넷이 못 잡는 이유가 구조적이다: 넷 9·18은 `Run`을 직접 몰고, 넷 10은 세 phase의 `visible`만 본다. **`main.gd`를 통해 restart를 드라이브하는 검사가 하나도 없다.**

**수리**: `main.gd::_bind_world()`를 `start()`/`restart()` 직후 · 넷은 restart 후 `view.world`가 `run.world`와 **동일 인스턴스**인지 pin.

---

## 6. 두 에이전트 — 카메라가 물러나는 순간 화면 가장자리가 안 그려진다

`run-shell.md:221,245` — `zoom = lerp(ZOOM_NEAR 1.6, ZOOM_FAR 0.8, ...)`
`main.gd:87-89` — `return Rect2(cam.position - vp * 0.5 - vp * 0.1, vp * 1.2)` — **zoom으로 나누지 않는다**
`field_view.gd:50,60,69` — 이 rect가 먹이·클론·크리터 **세 컬링 루프를 전부 결정한다**

`zoom = 0.8`이면 실제 가시 폭은 `vp / 0.8 = 1.25 × vp`인데 rect는 `1.2 × vp`. **무리가 커져 카메라가 물러날수록 화면 안에 있는 것이 사라진다** — 줌을 넣은 목적("무리가 보일 만큼 물러난다")이 발동하는 바로 그 순간에. 오류도 로그도 없다.

**그리고 줌에 계획된 검사가 0개다.** `ZOOM_LERP`가 0.01이어도, 줌이 아예 안 변해도 초록이다. 사용자가 "맵이 좁다"고 한 것에 대한 유일한 답인데 무방비.

**수리**: `_camera_rect()`를 `vp / cam.zoom.x * 1.2`로 · `ZOOM_FAR`에서 모서리 안쪽 **리터럴 좌표**의 클론이 `_paint_cell`에 도달하는지 assert.

---

## 7. 평면 배열 유지 지점 — 경고를 쓴 계획서가 자기 표엔 안 붙였다

인덱스가 이미 적어둔 패턴("한 파일에서 센 삭제가 네 곳에 살아 있었다")이 **네 문서 안에서 여섯 번 재발했다.**

| 배열 | 빠진 유지 지점 | 조용히 깨지는 방식 |
|---|---|---|
| 크리터 4열 | **`_spawn_critter()` (`world.gd:206-209`)** — 계획서 전체에서 등장 0회. 플랜은 `setup()`·`_remove_critter()` 둘만 지명 | `resize()`가 0으로 채운다 → 45초 뒤 스폰부터 species=CROW·force=0·hp=0인 유령. 화면엔 멀쩡한 몸 |
| `Swarm.worn` | 플랜 3이 "플랜 4 것"이라 하고 **플랜 4가 선언조차 안 한다**. `setup` resize·`add_clone`·`remove_at` swap·플랜 2의 분열 넷 곳 전부 없음 | 죽은 클론의 부품이 생존자에게 넘어간다. 무음 |
| 사체 5열 | **`_remove_corpse()`가 없다.** 소비가 5행 평면 배열에서 한 행을 빼는 일인데 함수도 swap도 없음 | 다른 시체의 진행도·종·force가 뒤섞인다. `:146` "Never cache a corpse index"가 그 swap 위에 서 있다 |

`swarm.gd:105-118`의 swap은 현재 8열 → 플랜 2가 9열(`force`, 문서화됨) → 플랜 4가 10열(`worn`, 문서화 안 됨).

---

## 8. "repo 전체에서 셌다"가 전수가 아니었다 — 세 번

| 계획서의 주장 | 실제 |
|---|---|
| `hands-and-commands.md:189` "`net_grid` calls `command_rally(point)` **three times**" | **7~8곳**. 빠진 것 중 `net_eat_carry.gd:22`가 결정적 — 그 주석이 "클론이 마지막 픽셀을 걸어서 실패 거리를 통과 거리로 바꾸지 못하게" 라고 적혀 있고, 랠리가 호스트로 바뀌면 바로 아래 두 경계 검사가 **자기 주석이 막으려던 이유로** 무너진다 |
| `run-shell.md:62` "The fallout is **four files**, counted across the whole repo" | `RUN_LENGTH`+`world.over` = 8사이트 **5파일**. `main.gd:45`·`:79`가 표에 없다. `:79`는 `if key.keycode == KEY_R and world.over:` |
| `body-and-parts.md:234` "**Two files** outside this plan's own list break here" | 세 번째가 `net_paint.gd:50,57`(호스트를 `r >= Look.HOST_RADIUS`로 찾고 `_paint_cell` 호출 수를 센다 — `_paint_body` 분리에 둘 다 빨개짐). 그리고 다섯 배율 삭제 목록에 **가장 많은 줄을 가진 `swarm.gd`(10줄)가 빠졌다** |

추가로 `add_clone()`에 parent 인자를 추가하는 변경의 실호출은 **16곳**(넷 13곳 포함)인데 플랜은 셋만 지명 — 기본값이 없으면 넷 다섯이 **사라진다**(플랜 1이 스스로 경고한 그 VANISH). `add_clone(parent: int = 0)`이면 무손상.

---

## 9. 계획된 검사가 라벨만큼 재지 못하는 것 — 상위 7

전체 20건은 아래 *부록 A*. 심각한 순서:

1. **넷 12 vs 넷 20이 배타적** (`grassland-field`) — 12는 뭉친 40마리에 `_paint_force_label` **1회**, 20은 "군집합 + 호스트 = **둘**". 규칙("The host is never absorbed into one")상 2가 맞고, 12를 만족시키는 구현은 20을 깬다. 흩뿌린 쪽도 12는 40, 실제는 41
2. **내부 부품 5칸이 화면에 아무것도 안 해도 초록** (`body-and-parts` 넷 12) — "인자가 다르다"는 정확히 A/B 비교(*diverged는 잡고 vanished는 못 잡는다*). bone이 force만 올리고 corner radius를 안 건드려도 전부 통과. `look.gd` 상수를 흩뿌렸을 때 "출력이 두 배가 됐는데 화면은 하나도 안 바뀌었다"가 측정된 그 실패
3. **`1 + Rules.START_CLONES`** (`run-shell` 넷 2) — 경계가 검사 대상에서 나온다. 0으로 내리면 `1 + 0 == 1`로 초록인데, **"무리가 0으로 시작했다"가 102개 초록을 통과한 그 버그**이고 플랜 2가 실제로 0으로 내린다. `net_hunt.gd:29`가 이미 같은 함정을 주석으로 적어놨다
4. **넷 5가 순서 계약을 총합으로 잰다** (`hands-and-commands`) — 본문이 "**Assert the order, not only the total**"이라 지목해놓고 검사는 "총합이 보존된다". 총합은 어떤 순서로도 참
5. **`Tab` 일시정지가 한쪽 끝만** (넷 11) — 닫으면 다시 도는지가 없다. **영원히 열려 있는 패널이 통과한다**
6. **`grassland-field` 넷 7의 표본이 1개** — "시드를 고정하고 50번" = 같은 결과 50번. `net_hunt.gd:148-155`가 이미 이 함정을 피해 적어놨다("one seed would have let a missing retry loop through about one time in nine. **Ten seeds instead.**"). 그리고 `PART_DROP_CHANCE 0.5`의 **비율을 재는 검사가 없어** 1.0이나 0.02로 출하해도 통과
7. **먹기가 시작조차 안 해도 초록** (넷 5) — "절반 시점에 세포 0, 시체 존재"는 먹기가 아예 안 돌면 참. `corpse_progress`가 0.5 근방임을 재야 한다. 그 값이 이 검사의 전부

**부재 검사 셋**(`RUN_LENGTH` 없음 · `DASH_*` 없음 · `SWARM_PER_THREAT` 없음)은 이름 하나의 부재만 잰다. `300.0`을 하드코딩하거나 함수 본문을 호출부에 인라인하면 전부 초록 — "파일을 grep하는 검사는 텍스트를 잴 뿐 계산을 재지 않는다"의 심볼 판.

---

## 10. 아예 검사가 없는데 조용히 깨지는 것 — 상위 5

1. **보스 → 호스트 방향의 피해.** "한 번 닿으면 런이 끝난다"가 이 스테이지의 아치 전체인데 검사 3은 호스트→생물 한 방향뿐. HP가 3 깎이는지 12 깎이는지, grace가 붙는지 전부 미측정
2. **첫 분열까지 몇 초인가.** `START_CLONES` 0 + `FORCE_START` 1(안 쪼개짐) + 플랜 3이 `take_card`에서 `add_clone()` 제거 = **1레벨 전까지 혼자 먹는 사각형 하나.** `rules.gd:68-71`이 "**Zero was wrong**: 첫 1분이 혼자 먹는 사각형이라 테스트 대상이 화면에 없다"고 측정해 적어둔 바로 그 상태다. 계획의 답은 "첫 레벨업이 온보딩"인데 **그게 몇 초인지 아무도 계산하지 않았다.** 첫인상 전부인데 숫자표에도 검사에도 없다
3. **`BITE`가 슬롯 0에 실제로 물려 있는가.** 없으면 런 전체가 무기 없이 돈다. 그리고 플랜 2·3 구간 내내 좌클릭이 빈 칸이다(엔딩 도달 불가는 명시했으면서 **손이 비는 구간은 명시하지 않았다** — 기획 원칙 1)
4. **레벨 은행.** 본문이 "**Assert it**: 빈 풀로 세 번 레벨업해도 월드가 계속 돈다"라 쓰고 번호 매긴 13개 어디에도 없다. 실패하면 **게임이 얼어붙는다** — 플레이에선 시끄럽고 넷에선 완전 무음
5. **`Lv2`가 실제로 뭘 하는가.** 계획이 "⚠ **A level has to DO something** … 없으면 넷은 숫자가 올랐다만 잴 수 있고 no-op이 초록으로 남는다"라 경고해놓고 force +1과 cooldown -10%를 리터럴로 재는 검사를 안 썼다

나머지 12건(미니맵 size 미단언, 종별 색, `EAT_TIME`이 force 비례인지, 크리터 반경이 전투 판정을 결정하는데 검사 없음, `species_eaten`의 first-eaten **순서**, 클론 접촉 공격 동사 통째 등)은 *부록 B*.

---

## 11. 죽은 규칙이 살아 있는 곳 — 설계층

| 곳 | 살아 있는 죽은 것 | 죽인 것 |
|---|---|---|
| `CLAUDE.md:134` | "`design/`, `decisions/`, `plans/` **do not exist yet**" | **47개 문서가 있다.** 같은 표가 가리키는 `docs/archive/`는 반대로 **없다**. 매 세션·매 에이전트 컨텍스트에 로드되는 가장 비싼 거짓말 |
| `cell-game.md:52` | "Six nouns are live: … **tier**" | tier는 삭제. 다섯이다. 절의 논증이 그 숫자 위에 선다 |
| `cell-game.md:56` | 점유 슬롯 교체 시 "**refunds half**" | 같은 파일 `:152`가 "there is no half-refund" |
| `cell-game.md:421` | "**It is not the opening state** … `START_CLONES` is 6" — ⚠ 붙은 채 **측정을 근거로** | `the-run-opens-alone.md`: 0. ⚠가 죽은 값을 *정정*처럼 읽히게 한다 |
| `cell-game.md:68,412,423` | "**The swarm is a fixed pool of 128** … the number the nets test against" | 실제 상한은 `CLONE_CAP` 40. **`CLONE_CAP`은 `docs/design/` 전체에 0회.** GDD로 경계 검사를 쓰면 게임이 만들 수 없는 128 케이스를 쓴다 |
| `proto-round-trip.md:41-44` | 배치형 랠리 **논증 전체가 취소선 없이** | 다른 세 사본은 전부 "Dead 2026-08-14". CLAUDE.md가 "프로토 위에 뭘 설계하기 전에 읽어라"라고 지목한 문서다 |
| `stages-and-evolution.md:459` + `grassland-field.md:227` | 보스 12 = "**so it cannot be walked into early**" — **한 글자도 안 틀리게 두 파일에** | `the-boss-is-not-gated.md`가 "A force threshold"를 기각. `grassland-field.md:112`가 100줄 위에서 스스로 반박 |
| `circle-rune-glyph.md:9-19` | 문서를 살려두는 근거가 "마법진 뱀서라이크도 답해야 하는 질문" | 그 방향이 **같은 날 나중에** 죽었다. 565줄이 무자격 현재형이고, `planning-principles-ko.md:47`이 이걸 살아 있는 증거로 라우팅한다 |

**계획서가 설계 없이 발명한 것**: `CLONE_CAP 40` 초과 시 인덱스 순 분열(의미 있는 순서 계약인데 설계 문서 없음) · `Tab`(`docs/design/`에 **0회**, GDD 입력 표에 행 없음 — 바인딩을 나르는 유일한 키인데) · "**This is the only lock**"(`body-and-parts.md:164`)이 GDD의 확률 롤과 pity 규칙 **둘 다** 삭제하는데 `parts-drop-by-chance.md`는 "two locks remain"으로 valid.

---

## 12. 결정 문서

**색인은 완벽하다** — 파일 31 ↔ 링크 31, 누락 0, 깨진 링크 0. 31개 전부 기각 갈래 표가 있고 전부 실제 사유를 담는다. `ten-slots-no-duplicates` ↔ `lung-gets-its-own-slot`은 **양방향으로 연결된 유일한 쌍이고 나머지가 따라야 할 형식이다.**

깨진 것:

1. **`no-leaving-the-core-to-fight.md`가 `valid`인데 게임 전체가 그걸 뒤집었다.** 뒤집힌 사실은 `defense-shelved.md:52`에만 있다 — "반박이 다른 파일에 떨어지면 전파되지 않는다"의 교과서
2. **`open-field-with-biomes.md`가 거짓으로 판정된 "no cap on clones"를 그대로 들고 있다.** `swarm-obeys-commands-not-selection.md`가 "저 파일이 죽은 절반을 재인용한다 — 상속하지 말라"고 **자기 파일에** 적었다. **가서 고치는 대신 메모를 남겼다** — 그 실패를 아는 문장 옆에서
3. **`ladder-of-habitats-not-tiers.md`가 상단에서 "이 문서가 값을 매긴 그림 예산은 더 이상 없다"고 취소선을 긋고, 20줄 아래 `:30`이 같은 죽은 값을 다시 쓴다.** 그리고 `stages-and-evolution.md:199`가 그 유령 비용을 **살아 있는 규칙의 근거로** 쓴다. "요란한 행만 재측정하고 조용한 행은 축복받으며 통과했다"의 재현
4. **죽은 게임의 결정 셋이 날짜 없이 `valid`로 섞여 있다** — `no-multiplayer-before-launch`(제목이 "December build"인데 December는 죽었다) · `top-down-not-side-view-floors`(본문이 코어와 마법진 디펜스를 설명한다) · `no-leaving-the-core-to-fight`. 대조군인 `magic-circle-dropped`·`defense-shelved` 등은 전부 `(2026-08-12)`를 달아 죽은 맥락임이 읽힌다
5. **결정 문서가 없는 갈래 넷**: force가 저장값(§1) · 액티브 사거리는 파츠에 적힌다(기각된 쪽이 `cell-game.md:221`에 **아직 살아 있다** — "space는 정확히 하나의 구현: 임펄스"인데 플랜 3의 갤럽은 유지 가속이다) · 시체 값 = force × 6(clone tax 삭제인데 `cell-game.md:461`이 아직 "clone tax가 값을 하는가"를 TBD로 묻는다) · 빈 풀에서 레벨 적립(기각된 쪽이 **현재 코드의 동작**이라 구현자가 "왜 굳이"로 되돌린다)
6. **인용이 다른 메커니즘을 가리킨다** — `grassland-field.md:235`의 `PART_DROP_CHANCE` 근거가 `parts-drop-by-chance.md`(카드 후보 무작위성)인데 실제 근거는 `host-parts-come-from-cards-only.md`이고, **그 파일은 폴더 밖 어디에서도 인용되지 않는다**

---

## 13. 빌더가 되물을 것 — 한 단어면 답이 되는데 안 적힌 것

| 질문 | 답 |
|---|---|
| 분열이 `carried`를 나누나 | 아니다. 부모가 전부 쥔다 (넷 2·3·5는 force만 재서 **어느 쪽으로 짜도 초록**) |
| 분열 루프가 `count`를 스냅샷 하나 | 해야 한다. 5→3+2의 자식은 2라 `>= 2`, 자라는 count를 읽으면 한 번 누름에 무리 전체가 1로 |
| `command_rally`가 인자를 남기나 | 없앤다. 매 프레임 `pos[0]`을 읽는다 |
| 일시정지 플래그 주인이 shell인가 `Run`인가 | 같은 절 `:203`과 `:214`가 서로 다르게 말한다. **`Run` 하나**. 둘로 짜면 넷 11과 넷 18이 **서로 다른 플래그를 재고 둘 다 초록** |
| 액티브 쿨다운 상태가 어디 사나 | `Body`에 `bound_cd` 3칸 + `Body.step(dt)`. **지금은 `fire()`를 쓸 수가 없다** |
| 갤럽이 가속인가 속도 배율인가 | `:222`는 `GALLOP_ACCEL`, 넷 13은 "speed drops back to base". 배율로 통일 |
| 종 이름 문자열 주인 | 없다. `Parts.NAME`은 부품 이름이고 종 이름은 마크다운 표 안에만 있다. 엔딩의 "먹은 종"을 빌더가 지어내게 된다 |
| `Parts.Species`에 `BOSS` | 빠졌다. "플랜 3이 숫자를 발명하고 플랜 4가 맞추는 것"을 막으려 enum을 앞당겨놓고 세 번째 값을 뺐다 → 빌더가 리터럴 `2`를 쓴다 |
| 부품 표의 `HP` 열 | 없다. 갈기의 유일한 효과(+1 HP)에 데이터 소스가 없어 `if part == HORSE_MANE:` 분기가 되고, 그게 "이 표가 곧 게임의 내용"을 무너뜨린다 |
| `body_slots`를 누가 채우나 | `run-shell`이 두 번 "플랜 3이 채운다"고 하는데 `body-and-parts.md`에 `body_slots`도 `RunResult`도 **0회**. 엔딩의 11칸이 영원히 빈다 |
| `cargo_lost` | 산문은 "stays"라 하고 구조체에도 엔딩 표에도 없다. 넷 13이 "`net_hud`에서 물려받은 네 검사"를 요구하는데 그중 하나가 `같이 날아간 것` — **갈 곳이 없다** |
| Tab 패널 파일 경로 | 없다(다른 새 파일은 전부 있다). `src/view/body_panel.gd` |
| 미니맵을 어느 노드가 그리나 | 없다. `field_view`는 월드 좌표 Node2D다 |

**폴더 계약 위반 둘**: `run-shell.md:177`이 `quit`을 "`get_tree().quit()`을 부르니 `sim/`이 아니라 여기"라는 **거짓 이분법**으로 배치한다 — 제3의 자리가 shell이고 `:180`이 이미 시그널 패턴을 정의했다. `:196`의 엔딩 `R`·`Esc`는 `_unhandled_key_input` = **shell 밖 Input 읽기**(`card_panel.gd:67`이 선례지만 그 선례가 위반이다).

---

## 14. 상호작용 — 안 정해진 것

잘 정해진 것(비트 중 레벨업·비트 중 사망·패널 중 `F`·상한 분열·빈 `V`·식사 중 이탈·40이 하나를)은 많다. 없는 것:

- **`Tab` + 레벨업 패널 동시** — 둘 다 일시정지인데 겹치면 무엇이 위인가, `Esc`가 어느 쪽을 닫나
- **카드 픽 중 보스 도착** — 심이 얼어 보스도 멈춘다. 레벨 은행 이후 **매 레벨업이 보스를 옆에 두고 필드를 얼린다.** 의도인지 아닌지 없음
- **식사 중 분열** — 자식이 `SEPARATION_MIN`에 생겨 먹기 반경 안일 수 있다 → 일 안 한 몸이 보상에 낀다
- **좌·우클릭 같은 프레임** — 규칙 없음
- **사체를 먹는 루프가 두 가지로 서술됨** — `:143` "사체별, 프레임당 한 번" vs `:147` "몸은 한 번에 사체 하나". **넷 17은 사체별에서만 통과한다**

---

## 15. 넷 위생

- **플랜 1의 "다섯 개" 규칙 해석이 틀렸다.** 래퍼가 세는 건 라운드의 총 넷 수이고 지금 10개다. 새 넷 하나를 단독 추가해도 5 아래로 안 간다. **결론은 옳고 이유가 틀렸는데, 틀린 이유는 다음 계획으로 전파된다**
- **모든 계획이 "invert every check"를 문장으로만 요구하고 어느 검사에 어떤 뮤테이션을 넣을지 한 건도 지정하지 않았다.** 특히 §9의 2번과 1번은 "자기 결함을 그대로 실은 검사"가 되기 쉬운 모양이다 — 군집 검사가 라벨을 배열 하나로 접으면 호스트 라벨을 지워도 나머지 합이 버텨 초록이 된다(dim-check가 두 알파를 한 배열에 접었던 그 실패)
- **느릴 후보**: `run-shell` 넷 14(`pump_frames`면 라운드에 0.5초 — 동기 `step()`으로) · `grassland-field` 넷 7(50시드 × `FOOD_SPOTS` 500) · 넷 17(클론 40 × 보스 `EAT_TIME` 6초 × 2). 플랜 4가 넷 2개에 21검사를 얹으므로 **착지 직후 `harness-manager`**
- **`net_citations`는 `docs/`를 스캔하지 않는다.** `docs/plans/`에 `file.gd:NNN` 형태가 **19개** 있고 플랜 1만으로 `hud.gd`가 통째로 다시 쓰이며 6개가 그날 죽는다. 규칙 위반은 아니지만(코드 주석에 걸린 금지다) 썩는 방식은 동일하다

---

## 16. 한 줄

**본문은 촘촘하고 구멍은 전부 이음매에 있다.** 인덱스가 이미 적어둔 그 패턴이 네 문서 안에서 여섯 번 재발했다 — "repo 전체에서 셌다"가 세 번 전수가 아니었고, 평면 배열 swap 경고를 쓴 계획서가 자기가 만드는 두 표엔 안 붙였고, "두 파일이 깨진다"가 세 번째를 놓쳤다.

**가장 싼 수리 순서**
1. `add_clone` 기본값 · `command_rally` 시그니처 · `pending_levels` 가드 위치 — 한 단어씩, 넷 16곳을 살린다
2. `cells_eaten` 단일 증가 지점 + 넷 7 반전 · restart 재배선 — 조용히 잘못 나가는 둘
3. `Parts.HP` 열 · `Body.bound_cd`/`step` — 플랜 3의 첫 한 시간을 막는 둘
4. `_spawn_critter`/`_remove_corpse`/`Swarm.worn` 세 유지 지점 · 까마귀:말 비율 · 액티브 명중 함수 — 플랜 4를 buildable로
5. `HORSE_SPEED` 1.05× + 속도 서열 리터럴 검사 · `EAT_RADIUS` 명명 + 상수 대 상수 검사 · `_camera_rect`의 zoom 나눗셈
6. 설계층 좀비 여덟 · 결정 문서 여섯 · `CLAUDE.md:134`

---

## 부록 A — 계획된 검사 20건 (라벨 > 측정)

`run-shell` 2 · 7 · 12 · 14 · 15 · 17 · 18 · 11 / `hands-and-commands` 4 · 5 · 11 · 13 · 18 / `body-and-parts` 8 · 12 / `grassland-field` 1 · 5 · 6 · 7 · 12+20 · 14 · 15.
각 건의 인용·해당 실패 모드·무는 검사는 fake-nets 보고 원문 A1–A20에 있다.

## 부록 B — 미검사 행동 전체

카메라 줌 4상수 · PLAY에서만 Input · 랠리 링 · `F` 충전 표시 · `CLONE_SPAWN_RING` · STRIKE가 먹이를 안 쫓음 · 클론 접촉 공격 · 크리터 반경이 전투 판정 · 종별 색(`is_hunter_of` 삭제로 색 경로가 끊긴다 — 검정이면 어두운 배경에서 **안 보이는데** `net_paint`는 색을 안 본다) · `EAT_TIME`이 force 비례(검사 셋이 전부 단일 상수처럼 쓴다. 평평하게 출하해도 통과인데 "까마귀 0.5초, 보스 6초"가 먹기 비트의 전부다) · 보스가 하나뿐인지 · `species_eaten`의 first-eaten 순서 · `hud.gd:61`의 `maxi(host_hp, Rules.HOST_HP)`(최대 HP가 자라면 하트가 틀린다) · `hud.gd:65-67`의 키 범례(첫 12초에 읽는 유일한 안내문이고 플랜 2 이후 **전 절이 거짓**인데, 문제를 발견한 계획서와 만드는 계획서 **사이로 떨어졌다**).
