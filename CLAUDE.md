# 탁본 (TAKBON) — Godot 4.6.1 · 2D 탑다운 익스트랙션 로그라이트

낮에는 숲에서 사냥하며 글자를 탁본하고, 밤에는 마법진을 손으로 그리는 게임.
1인 개발(사용자) + Claude 리드 세션 + 서브에이전트 팀으로 개발한다.

## 새 세션이 먼저 읽을 것

> 📖 **정본 = 이 파일 + `docs/STATUS.md` 최상단(직전 세션 상세) + `docs/WAND_CIRCLE.md` + memory.**
> 지금 게임 = `src/base`(베이스캠프) + 고리 조립 책 + 숲 원정 + 온보딩 레일.
> 🔴 **기록 규칙: 직전 세션만 상세, 그 전은 아래 「한 줄 지도」로 내려보낸다** — 이 절이 길어지면 정리 신호.

🔴🔴 **직전 세션 = 50 「세션49의 빚 3개 청산 — 그런데 곁가지가 본편보다 컸다」** (정본 STATUS「50」+ memory `takbon-silent-data-death`):
사용자 *"빚 먼저 처리해줘"*. 파이프라인을 처음으로 제대로 돌렸다: **architect(설계) → dev 2명(병렬) → reviewer(커밋 전) → 리드(검증·커밋)**.
🔴 **빚① `status_power` = 「세기 배율」로 통일**(전 룬 1.0), 기본 수치는 balance로(`status_burn_dot_base`·`status_burst_base`·`status_slow_cap`). **특별잉크가 6룬 전부에 균일하게 통한다**(전엔 번개·흙·풀에 안 통해 세28~29 경제의 절반이 죽어 있었다). 취약의 세기축 = **증폭 배수**(사용자 확정 — 지속을 흔들면 보상이 「세기」가 아니라 「타이밍 여유」로 미끄러진다).
🔴 **감전 연쇄만 실제로 세졌다: 0.6 → 1.8(3배)** — 옛값은 번개 세기가 안 읽히던 시절의 사고값. **맞는 세기인지는 사용자가 쏴 봐야 한다.**
🔴 **빚② `src/core/status_holder.gd` 추출** — `forest_enemy`(−192줄)와 `dummy_target`이 공유해 **연습장에서 반응을 시험할 수 있다**. **역할 3분할 = 규칙(`status_rules`) / 보유·시간(holder) / 몸(소유자)**. 🔴 **콜백 경계**: holder는 hp를 안 깎고·씬을 안 뒤지고·`modulate`를 안 만진다(틴트는 **Color를 반환만** — 아니면 안개 분산 알파가 조용히 사라진다).
🔴 **빚③ 룬 획득 경로** — 조각 3장 + vine/beetle/mist 드롭 + **gale 숲 심층 배치** + 퀘스트 q08~q10 (사용자 확정 = 기존 적 재활용, 새 적·새 아트 0).
🔴🔴 **곁가지 둘이 더 컸다 — 둘 다 「배선은 맞는데 데이터가 조용히 안 맞던 것」**:
  ⓐ **바람 룬이 통째로 죽어 있었다** — `rune_wind.tres`의 `ui_color`가 **3인자 `Color`**라 파싱 실패 → `Db`가 조용히 건너뛰어 `get_rune(3)`이 계속 null. 세49가 시드까지 해 준 룬을 아무도 못 쓰고 있었다. **버그를 되돌려도 전 스위트 `pass=23 fail=0`(검출력 0)** → `test_decode_auto`에 「룬 6종 전부 로드」+「조각→룬 왕복」을 붙여 **이 반복 함정에 처음으로 자동 감시가 생겼다**.
  ⓑ **연습장에서 감전 연쇄가 한 번도 안 터졌다** — 허수아비 간격 102px vs 연쇄 반경 90px. 78~82px로 좁혔다. 🔴 **정본 주석은 `balance_data.status_shock_chain_px`** (씬의 `;` 주석은 에디터가 저장하면 날아간다).
⏸ **의도적으로 잠자는 콘텐츠 (버그 아님)**: `_seed_starting_unlocks()`가 룬 6종을 미리 열어 **빚③ 산출물이 전부 소급 완료**된다. 사용자 확정으로 유지 — 다음이 "직접 쏴 보기"인데 시드를 빼면 두 번째 룬까지 막힌다. 🔴 **손맛 확인이 끝나면 `game_state.gd`의 5줄을 지워라**(경로 자체는 실게임 확인됨: gale→드롭→줍기→가방).
✅🔴🔴 **ⓐ 완료 — 사용자가 직접 플레이하고 확인했다** (세50 말): *"마법진 손으로 해보니까 재미있으니까 지금까지 잘됨."*
**핵심 가설이 실제 플레이로 확인된 순간이다** — 세13에 세우고 세25에 클릭 조립과 겨뤄 이긴 「손으로 그린다」가, 이제 룬·문양·진이 다 붙은 상태에서도 **재미있다**. 방향 전환 없이 이 축을 계속 키우면 된다([[takbon-hand-trace-commit]]·[[takbon-core-fun-drawing]]).
🔴 **다음 = ⓐ' 드롭 흡수 애니메이션** (사용자 요청, 세50 말): *"몬스터를 잡았을 때 나에게 흡수되는 애니메이션 필요할듯."* 지금은 세46 설계대로 **걸어가 겹쳐야** 줍는데(`src/props/drop_pickup`), 사용자가 원하는 건 **처치 → 아이템이 플레이어에게 빨려오는** 연출이다. ⚠ **줍는 규칙을 바꾸자는 게 아니라 「보상이 도착하는 느낌」이 없다는 말**로 읽어라 — 자석 반경 안에서 끌려오게 할지, 처치 순간 날아오게 할지는 설계 판단(`takbon-architect`).
→ ⓑ **임팩트 표현**(사용자: *"재미는 보장된 시스템이고 임팩트를 어떻게 표현할 문제"* — 지금도 색 틴트뿐). **ⓐ'와 같은 결이다**(둘 다 "일어난 일이 눈에 안 보인다") → 묶어서 하는 게 자연스럽다.
→ ⓒ 아래 남은 빚. 그리고 **연쇄 1.8이 맞는 세기인지는 아직 미확인**(사용자가 반응까지는 안 봤다).
⏸ **보류 = forest_t2(숲2·티어 하강)** — 사용자 확정(세48): *"숲2는 아직 필요없음."* 딸린 **「하강 시 회복 스킵」도 같이 보류**(`src/field/forest.gd:131` 주석).

🔴 **세션50이 남긴 빚**:
- 🔴 **`rune_fill`(룬 농도)의 소비자가 0곳** — "진 안에 룬을 얼마나 크게 그렸나"가 **아무 데도 안 쓰인다**. `ring_spell_system`의 주석이 *"조립 단계에서 반영돼 들어온다"*고 **거짓말을 하고 있었다**(세50에 정정). **빚①과 정확히 같은 병인데 이건 「그리는 재미」 축이다** — 살릴지 접을지 결정 필요.
- **gale은 아직 보스가 아니다** — `params`의 `gust_*`·`volley_*`·`phase2_*` **12개를 읽는 코드가 없어** hp250짜리 평범한 추격체다. `params.ai = "boss_gale"` 분기 하나면 "새 행동 = params 한 줄"이 성립한다(세46 계약).
- **취약 이중 증폭** — 반응 산물에 배수가 두 번 곱한다(세49부터라 회귀는 아님). 의도인지 사고인지 미정.
- **`take_reaction_damage`의 룬이 하드코딩 `FIRE`** — 어떤 반응이든 불 소리가 난다.
- **vine이 숲에 1마리뿐**이라 0.25 드롭이면 풀 조각 하나에 원정 4번(beetle 3·mist 2와 속도가 고르지 않다).

**지난 세션 한 줄 지도** (상세는 STATUS/memory — 필요할 때만 캐라):
- **49** 룬 상태이상·원소 반응 — 룬 축이 실체를 얻었다. **원칙 「단독은 약한 바탕, 조합에서 폭발한다」** · 규칙 단일 소스 `src/core/status_rules.gd`(**반응 추가 = 줄 하나**) · 룬 3→6(바람=**확산자**·흙=**취약**, 원신 Swirl/Crystallize 선례) · **룬 전용 문양 각하** → 문양6×룬6=**36조합**(어휘가 아니라 곱셈이 는다)(`0472cc3`·`c887758`)
- **48** 진 3→8종: `pattern`×`motion` 축 분리 + 진마다 다른 닫힌 밑그림(`e7674bc`)
- **47** 문양 어휘 3→6(유도·팅김·추진) — 잠들어 있던 `projectile` 효과 기계를 켠 것(`620f66d`)
- **45~46** 메인 루프: 던전 깊이 그라디언트+포털 · 바닥 드롭 픽업 · 몬스터 AI 4종 · 스프라이트/타일맵(`2c1f1ba`)
- **44** 자유도 첫 균열: 매직볼 바닥 · 관통 문양(그린 게 전투를 "종류"로) · 진=발사 형태(`632900f`)
- **41~43** 온보딩 레일 · 장비 5부위 · 퀘스트 [!] 새 목표 마크
- **34~37** 룬 해금(E4) · 마나/허기 페이스 · 퀘스트 스파인 · 빈 거점 재료 건설 + 새로하기(F8)
- **26~33** 숲 원정 · 드롭 · 잉크 경제 배선 · 적 5종 · 공방 · 사운드
- **21~25** 대청소(옛 자유드로잉·본게임 삭제) · 고리 조립 모델 · 마력 주입/등급 · 손으로 그리기 확정

🔴 **살아있는 함정** (서사는 지워도 이건 유지 — 전부 실제로 밟은 것):
- 🔴🔴 **`.tres` 한 글자가 틀리면 그 데이터는 조용히 사라진다** (세50) — `Color`를 **3인자**로 쓰면 파서가 **리소스 전체를 거부**하고 `Db`가 말없이 건너뛴다. 바람 룬이 두 세션 내내 그렇게 죽어 있었고 **전 스위트가 그린이었다**(검출력 0). ⚠ 그래서 **"파일을 만들었다"를 완료로 치지 마라 — `Db`를 거쳐 실제로 로드되는지 확인해라**(`test_decode_auto`의 「룬 6종 로드」가 그 그물이다).
- 🔴 **배선이 맞아도 「반경 밖」이면 아무 일도 안 일어난다** (세50) — 연습장 허수아비 간격 102px vs 감전 연쇄 90px라 연쇄가 **한 번도 안 터졌다**. 반경을 쓰는 기능을 붙였으면 **좌표를 실측해라**. ⚠ 씬(`.tscn`)의 `;` 주석은 **에디터가 저장하면 날아간다** — load-bearing한 설명은 코드에 둬라.
- ⚠ **없는 문제를 막다가 진짜 함정을 심지 마라** (세50) — `_exit_tree`로 콜백을 끊어 "참조 순환"을 막으려 했는데 **그 순환이 애초에 없었고**(Callable은 Node를 강참조 안 함), 대신 **리페어런팅 시 콜백이 영구히 죽는** 침묵을 새로 만들었다. 리뷰가 잡았다.
- **화면 덮는 Control엔 `mouse_filter = 2`** (세25) — 없으면 바닥이 좌클릭을 다 먹어 발사가 **에러 없이 죽는다**. 🔴 헤드리스는 못 잡음 → **실게임 `push_input`으로만** 확인된다.
- **씬끼리 PackedScene preload 금지** → `@export_file` + `change_scene_to_file` (세26) — 순환 preload가 껍데기 노드를 만들어 귀환·사망 시 못 돌아옴. 헤드리스 절대 못 잡음.
- **등급/펑 경계는 `is_stable()`을 그대로 부른다** — 65를 상수로 베끼면 갈라진다 (세24, `src/core/ring_power.gd`).
- **발사는 caster의 `to_assembly()`로만** — 직접 Dictionary를 만들면 손그림 점수가 빠져 **조용히 기준 위력**으로 나간다 (세26).
- **`wipe_save()`는 새로하기가 아니다** — 오토로드(GameState·Clock)가 메모리에 남아 귀환 한 번에 옛 진행이 되살아난다. 진짜 새로하기 = `GameState.new_game()` (세37).
- **초록불을 근거로 쓰지 마라** — 헤드리스는 클릭 도달·렌더·시간 경과를 못 잡고 `-s`는 런타임 에러가 나도 "OK"를 찍는다. **뮤테이션으로 검출력 증명 + 실게임 확인** (세22·23·25, skill `takbon-verify`).

- **docs/REFACTOR_PLAN.md** — ✅ **세션 22에 완료** (이력·판단 근거로만 참고). 「문제가 아닌 것」 절은
  아직 유효하다 — 건드리지 마라
- **docs/STATUS.md** — 세션별 진행 로그 (세션 종료 시마다 갱신). 옛 로그는 STATUS_ARCHIVE.md
- docs/BACKLOG.md(E4·E5 정본) · ART_SPEC.md(에셋·아트 방향 960×540·48px)
- ⚠ **세션 39에 옛 자유드로잉 문서 6개(TRUTH·GDD·TECH_SPEC·CHANGELOG·NEXT_CYCLE·TEAM_PLAN) 삭제** —
  삭제된 시스템 설명이라 지웠다. 고리 모델 GDD 재작성이 필요해지면 git(`98e427f`)의 옛 GDD를 참고 삼아 새로 쓴다

## 아키텍처 요약

- **진입점**: `src/base/base.tscn` (베이스캠프 — 바닥·탁본 책상·연습장·**왼쪽 숲길**). 책상 E →
  고리 조립 책 · 숲길 E → 원정 (세션 22에 `src/playground` → `src/base`로 개명 — 옛 이름이
  "버려도 되는 실험"이라 거짓 신호였다)
- **오토로드**: EventBus(시그널 허브) / GameState(자원·HP·장착·가방·도감) / Clock(낮밤 시간) /
  Db(data/ 레지스트리) / SaveManager(user://save, 자동 저장)
  - ✅ 세션 22: 옛 SpellDesign 스키마·research 경로를 **매장했다** (전엔 지우면 파싱이 깨졌다).
    `Clock`의 실질 역할 = **자동저장 틱**(day_started → SaveManager) — 죽은 코드 아님
  - ⚠ EventBus의 `extraction_success`·`bag_lost`는 **수신자만 있고 발신자가 없다** — 필드(원정)
    미구현 탓이다. 필드를 붙이는 쪽이 emit해야 하며, 안 그러면 조용히 안 돈다 (event_bus.gd 주석 참조)
- **남은 모듈**: `src/base`(베이스캠프) · `src/field`(숲 원정 — 세션 26) · `src/actors`·`src/hud`
  (**공용** — base와 field가 같이 쓴다) · `src/drawing`(고리 조립 — 아래) · `src/spell`(발사) ·
  `src/core`(리드 전용)
  - 🔴 **`src/actors` = 공용 배우** (세션 26): `player.tscn`(WASD·그룹 `"player"`) ·
    **`player_caster.gd`**(조준·발사·슬롯) · `interact_zone.gd`(책상·숲 출구·귀환 지점이 **같은
    물건** — 문구는 씬의 `Prompt.text`, 찾기는 `zone_id`).
    🔴 **발사를 복사하지 마라 — caster를 써라**: 직접 Dictionary를 만들면 `to_assembly()`가 빠져
    **손그림 점수가 조용히 사라지고 기준 위력으로 나간다**. 그래서 뽑은 것이다
  - 🔴 **`src/hud/hud.gd` = 공용 HUD** (옛 `src/base/base_hud.gd`). 씬마다 다른 건 `hint_text`·
    `show_hp` **@export 둘뿐**이라 상속하지 않았다. ⚠ 안내문에 **있지도 않은 조작을 적지 마라**
    (숲엔 책상이 없다) — 그 자체가 버그다
  - 🔴 **`src/field`**: `forest.tscn`(원정) · `forest_enemy`(쫓아와 접촉 피해).
    **적 수치는 전부 `data/enemies/*.tres`(EnemyDef) — 새 적 = .tres 한 장**이다.
    **출격 = 만HP**는 `forest.gd _ready`가 한다 (베이스가 아니다 — 다른 진입 경로로 들어가면
    조용히 달라진다). ⚠ `EnemyDef.drops`는 **아직 아무도 안 뿌린다** (BACKLOG F6)
  - `src/drawing` = **ring_assembly**(조립 상태기계·순수 데이터) · **trace_scorer**(탁본 채점·순수 수학)
    · **ring_board**(기하·렌더·입력) · ring_book · ring_forge_panel(+`.tscn` 껍데기)
    🔴 **채점(완성도·정밀도·펜 보정)을 바꿀 땐 `trace_scorer.gd`만 연다** (세션 22 분할의 이유)
  - 🔴 **점수 → 펑/위력/등급 규칙 = `src/core/ring_power.gd`** (세션 23·24). 조립 리포트(UI)와
    발사가 **같은 함수를 부른다** — core에 둔 이유가 이것이다. 복사해 두면 한쪽만 고쳐도 아무도 못
    알아채고 갈라진다(리포트는 "위력 140" 적고 130으로 때리는 식). 수치는 balance.tres
    - `grade_of`(세션 24)도 여기다. **최하단 「사용 불가」는 `is_stable()`을 그대로 부른다** —
      65를 상수로 베끼면 기준선과 갈라진다(세션 23의 「무난인데 터진다」가 정확히 그거였다).
      `is_perfect()`로 UI가 퍼펙트를 강조한다 — **등급 이름을 `==`로 비교하지 마라**
  - 🔴 **보정은 펜이 판다**: `ItemKind.PEN` → `data/items/pen_*.tres`의 `params.correction` →
    `GameState.stroke_correction()` → `ring_board._set_trace` → `trace_scorer.set_correction`.
    **새 펜 = .tres 한 장.** 맨손 = 보정 0 = 그린 대로(정체성은 기본 상태가 지킨다)
  - `src/spell` = ring_spell_system(유일한 발사 경로) · ring_carrier · projectile · pillar · dummy_target
    · ⚠ **shockwave는 지금 참조 0**이다 (세션 22에 projectile의 옛 SpellDesign 충격파 경로가 사라짐)
- 모듈 간 통신은 **EventBus 시그널 + core 스키마만**. 타 모듈 직접 preload/get_node 금지
  - 🔴 **발사 계약 = `Enums.GlyphCode`**(GATHER=0/RADIATE=1). 조립 UI·발사·`data/glyphs/*.tres`가
    이 값을 공유한다 — **밀면 저장된 고리 도안이 조용히 깨진다**
  - ⚠ 예외로 정당한 것: `base.gd`가 책 씬을 무는 것(진입 씬 = 조합 루트)
- 밸런스 수치는 전부 **data/balance.tres** (BalanceData) — 코드에 수치 금지
- typed GDScript 강제. 렌더러 Compatibility, **뷰포트 960×540**(세션 18에 640×360에서 올림, aspect=expand)

## 개발 규칙 (병렬 에이전트 운영 시)

- **git 커밋은 리드(메인 세션)만.** 에이전트는 자기 모듈 폴더 + tests/ 자기 접두사 파일만 수정
- 에이전트 새 스크립트에 **class_name 선언 금지** → `const X := preload(...)` (전역 클래스 캐시는 리드의 `--import` 때만 갱신됨)
- 에이전트는 mcp__godot__* 도구 사용 금지 (에디터는 리드가 관리)
- 스키마·시그널 추가 요청은 에이전트가 보고 → 리드가 core에 반영 (지금까지 전부 이 방식으로 처리됨)

### 🔴 하네스: 탁본 전용 에이전트 (2026-07-19 세션 39 — godot-prompter 대체, 자립형)

> **왜 만들었나:** godot-prompter 플러그인 에이전트는 제네릭 Godot만 알아서, 위임할 때마다 프로젝트
> 규칙 벽(typed·class_name 금지·EventBus·balance.tres…)을 프롬프트에 통째로 주입해야 했다 — 그러느니
> 리드가 직접 하는 게 빨라 위임이 안 굴러갔다. **이제 규칙이 에이전트에 박혀 있어 규칙 주입 없이 바로
> 위임된다.** 로컬 Donchitos 49-에이전트 하네스가 과함이었듯, 이번 하네스도 **린하게** 유지한다
> (오케스트레이터·에이전트 팀 격식 없음).
>
> 🔴 **자립형이다 — godot-prompter 플러그인은 껐다**(`.claude/settings.json`에서 제거). 제네릭 스킬을
> `.claude/skills/`로 **복사**해서 플러그인 없이 돈다(스킬은 disk에 있어도 트리거될 때만 로드돼 안 쓰면 무해).
> ✅ **세션 39 정비: 처음 51개 전부 가져왔다가, 구조적으로 무관한 8개를 삭제해 43개로 줄였다**(+takbon 2개=45).
> 삭제 기준 = **2D·GDScript·데스크톱 확정으로 쓸 일이 없는 것**(3d-essentials·csharp-*·gdextension·
> xr-development·mobile-development·using-godot-prompter·godot-project-setup). **멀티(basics/sync)·
> dedicated-server·beehave·limboai·localization은 「휴면 방향」으로 남겼다** — 사용자가 멀티·다국어·BT
> 보스 AI를 아직 안 접었기 때문(삭제=방향 포기 신호라). 되돌리려면 이 커밋 직전 git 이력.
>
> 🔴 **세션 39: 제네릭 43개 SKILL.md를 한국어로 번역했다 = 상류(godot-prompter)와 「관리된 갈라짐」.**
> 번역 사본이라 상류(`jame581/GodotPrompter`, 현재 `1.11.0`)와 어긋나므로, `.claude/skill-vendor/`가
> 그 갈라짐을 **관리**한다(막지 않는다): ① `upstream-1.11.0/` = 번역 당시 영어 원본 박제본(diff 기준,
> 에이전트가 로드 안 함) · ② `VERSION` = 번역 기준 버전 · ③ `check-upstream.sh` = **한 달에 한 번**
> 돌려 상류 버전이 올랐는지·어느 스킬이 바뀌었는지 출력. 코드 블록·`name:`은 번역 안 함(코드는 상류
> 대조용 원문, name은 호출 키). 상세 = `.claude/skill-vendor/README.md`.
> 🔴 **references(심화문서 150개)는 삭제했다** (사용자: *"깔끔하게 관리"*) — 각 스킬 폴더가 SKILL.md
> 한 장씩만 남아 트리가 깨끗하다. 본문의 "→ references 보라" 죽은 링크도 정리. **영구 손실 아님**:
> 영어 전문이 `skill-vendor/upstream-1.11.0/`(diff 박제본)와 상류 github에 그대로 있어 언제든 복구.
> 즉 심화 레시피가 필요하면 그 두 곳에서 꺼내 온다 — skills/ 트리에만 안 둔다.

- **위임 대상 (`.claude/agents/`):** 핵심 = `takbon-dev`(구현) · `takbon-architect`(설계) ·
  `takbon-reviewer`(리뷰) · `takbon-ui`(패널·모달·HUD) · `takbon-art`(도트 스프라이트). 가끔 =
  `takbon-shader`(2D 셰이더 효과) · `takbon-animator`(스프라이트 애니 배선) · `takbon-profiler`(성능 진단) ·
  `takbon-tools`(에디터 플러그인·@tool). 다들 `.claude/skills/takbon-rules`(아키텍처·계약)와
  `takbon-verify`(검증 규율)를 읽고, 제네릭 Godot
  지식은 로컬 복사한 제네릭 스킬 43개(`gdscript-patterns`·`animation-system`·`physics-system`·`godot-ui` 등)를
  Skill 도구로 부른다. 규칙 충돌 시 탁본이 이긴다.
  - 🔴 **기능 지식은 에이전트가 아니라 스킬에 있다** — 애니/물리/셰이더 등을 만들 때 `takbon-dev`가
    해당 스킬(`animation-system`·`physics-system`·`shader-basics`…)을 읽고 짠다. 그래서 스킬을 다 가져온
    것이다. `takbon-dev.md`의 스킬 매핑에 어느 작업에 어느 스킬을 부를지 전부 적혀 있다.
- 🔴🔴 **기본이 위임이다** (2026-07-20 세션48에 사용자가 예외 목록을 걷어냈다). 그전엔
  *"회귀 위험이 크고 tight한 검증 루프가 필요한 작업·core 스키마 변경·mcp__godot·커밋은 리드가 직접"*
  이라 적혀 있었는데, **이 프로젝트의 재밌는 작업은 죄다 발사·저장·core에 닿아서 거의 매번 예외에
  걸렸다** — 위임 대상으로 남는 게 주변부뿐이라 하네스가 안 굴러갔다. 사용자 의도(세션48):
  *"기획을 처음에 빡세게 잡고 가고 싶고, 코드의 퀄리티를 신경쓰고 싶어."* **위임은 손을 던다기보다
  설계·리뷰 단계를 강제해 품질을 올리는 장치다.**
- **기본 파이프라인:** `takbon-architect`(설계 먼저 — 씬 트리·시그널·데이터 흐름) →
  `takbon-dev`/`takbon-ui`/`takbon-art`(구현) → `takbon-reviewer`(커밋 전 리뷰).
  큰 기능은 **설계를 먼저 받아 사용자와 합의하고** 구현에 넘긴다 — 코드부터 얹지 마라.
- 🔴🔴 **에이전트에게 「보고서를 파일로 써라」고 지시해라** (2026-07-20 세션49에 알아냄).
  **채팅으로 낸 최종 보고는 리드에게 안 온다** — 세48~49에 `jin-ui`·`jin-tests`·`jin-shapes`·
  `status-design` 네 번이 전부 idle 알림만 오고 **내용이 증발했다**(리드가 매번 `git diff`로
  역추적해야 했다). 반면 *"`scratch_<이름>.md`를 리포 루트에 써라"*고 지시한 `status-core`·
  `rune-data`는 **멀쩡히 도착했다**. ⚠ 특히 **`takbon-architect`·`takbon-reviewer`는 산출물이
  보고서뿐이라, 파일로 안 시키면 작업 전체가 사라진다.** 읽고 나면 리드가 scratch 파일을 지운다.
- 🔴 **리드가 절대 안 놓는 것 = 검증과 커밋** (위임하는 게 아니라 리드의 직무다):
  검증·`--import`·커밋(`takbon-verify` = 위 검증 명령). **에이전트의 "그린 나왔습니다"를 근거로
  쓰지 마라** — 리드가 직접 돌리고 뮤테이션으로 검출력을 확인한다.
- ⚠ **에이전트에 뮤테이션을 시킬 땐 원상복구까지가 지시다.** 세션48에 `_scaled`가 뮤테이션 중간
  상태로 잠깐 남았다(에이전트가 복구해 사고는 안 났다). `src/`를 되돌린 채 두면 **기능이 조용히
  죽은 채 커밋된다** — 이 프로젝트가 제일 무서워하는 실패 방식이다. 리드는 커밋 전 `git diff`로
  본다.

**하네스 변경 이력:**
| 날짜 | 변경 | 대상 | 사유 |
|------|------|------|------|
| 2026-07-19 | 초기 구성 | agents/takbon-{dev,architect,reviewer} · skills/takbon-{rules,verify} | godot-prompter가 제네릭이라 위임 시 규칙 주입 비용이 커 위임이 안 굴러감 |
| 2026-07-19 | UI·아트 에이전트 추가 | agents/takbon-ui(패널·mouse_filter 함정) · agents/takbon-art(aseprite 함정·아트 방향) | 탁본이 실제로 쓰는 영역(패널 천지·직접 스프라이트 제작) 커버 |
| 2026-07-19 | 자립형 전환 · 플러그인 끔 | 제네릭 스킬 26개 `.claude/skills/`로 복사 · settings.json에서 godot-prompter 제거 · 에이전트 참조를 로컬 이름으로 | 오버레이가 플러그인에 묶여 있어 플러그인을 끄면 참조가 끊김 → 자립형으로 |
| 2026-07-19 | 스킬 전체(51) 복사 + dev 매핑 완성 | 나머지 25개 스킬 복사(총 51) · takbon-dev 스킬 매핑에 animation/physics/camera/player 등 추가 | 사용자 걱정: "애니 등 만들 때 스킬 안 쓸까 봐" → 기능 지식=스킬이므로 전부 확보 + 에이전트가 부르게 매핑. 노이즈 정비는 추후 |
| 2026-07-19 | 나머지 에이전트 탁본화(총 9) | agents/takbon-{shader,animator,profiler,tools} 추가 | 사용자 "만들어만 둬줘". csharp만 제외(GDScript 전용 규칙과 충돌). 원본 복사 아닌 규칙 주입 재작성 |
| 2026-07-19 | 스킬 노이즈 정비 51→43 | 삭제 8: 3d-essentials·csharp-godot·csharp-signals·gdextension·xr-development·mobile-development·using-godot-prompter·godot-project-setup · takbon-dev 매핑·「휴면 방향」주석 갱신 | 2D·GDScript·데스크톱 확정으로 구조적 무관만 삭제. 멀티·dedicated-server·beehave·limboai·localization은 사용자가 방향을 안 접어 유지(삭제=방향 포기 신호) |
| 2026-07-19 | 제네릭 43개 SKILL.md 한국어 번역 + 벤더링 | skills/*/SKILL.md 본문 번역(references·코드블록·name은 원문) · 신설 `.claude/skill-vendor/`(영어 1.11.0 박제본+VERSION+check-upstream.sh) | 사용자 요청 한국어화. 상류와 갈라지므로 「관리된 갈라짐」 채택 = 월간 대조로 상류 변경분만 반영 |
| 2026-07-20 | 위임 예외 목록 걷어냄 · 파이프라인 기본화 | CLAUDE.md 「개발 규칙」 | 사용자 세48: *"기획을 처음에 빡세게 잡고 가고 싶고, 코드의 퀄리티를 신경쓰고 싶어."* 옛 예외("회귀 위험·core 스키마·mcp__godot·커밋은 리드")가 너무 넓어 재밌는 작업이 죄다 예외에 걸려 위임이 안 굴러갔다 |
| 2026-07-20 | 🔴 보고서는 **파일로** 지시 | 위임 프롬프트 규약 | 세48~49에 채팅 보고 4건이 **증발**(idle 알림만 옴) · 파일로 시킨 2건은 도착. architect·reviewer는 산출물이 보고서뿐이라 치명적 |
| 2026-07-19 | references 심화문서 150개 삭제 | skills/*/references/ 40폴더 + godot-testing 최상위 참조 2개 삭제 · 본문 죽은 링크 정리 | 사용자 "깔끔하게 관리". skills/ 트리를 SKILL.md 한 장씩만 남김. 영어 전문은 skill-vendor 박제본+상류 github에 있어 영구 손실 아님(복구 가능) |

## 검증 명령 (반드시 Bash에서 — PowerShell은 자식 프로세스 stdout을 안 보여줌)

**전 스위트를 다 돌려라.** 목록에서 빠진 테스트는 낡아 죽는다 — 실제로 세션 7이 문법을 바꾸면서
`test_paper_auto`(8건)와 `test_drawing_canvas_auto`(1건)가 목록에 없다는 이유로 **조용히 깨진 채
방치됐다** (세션 8에 발견·복구).

```bash
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_save_auto.gd            # 저장/로드 (고리 라운드트립) · 🔴**부팅만으로 자동 저장이 준비되나**(세션 26 F3 — 이 확인은 `load_game()` **호출 전**에 있어야 한다. 순서가 곧 검출력이다)
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_ring_assembly_auto.gd   # **조립 상태기계 계약**: 단계 전이·문양본이 칸을 여는 규칙·assembly 발사 계약·시그널 (세션 22)
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_ring_trace_auto.gd      # **손그림 탁본**: 완성도/정밀도·[다음] 수동 진행·칸 자유 편집·I3 · **정밀도 이빨(⑨⑩)·펜 보정(⑪⑫)**
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_ring_spell_auto.gd      # **고리 발사**: 진→투사체·착탄 전개(발산 탄환·응집 기둥)·실제 적 take_hit
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_ring_design_auto.gd     # **고리 도안 통합**: RingDesign 라운드트립·ring_design_committed→GameState 자동 장착 · **등급⇔펑 경계·퍼펙트⇔화면100** (세션 24)
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_base_auto.gd            # **베이스캠프 발사 배선** (세션 24): 과녁 사거리 · 🔴**물리 레이어 계약**(내 몸/책상이 world면 진이 총구에서 죽는다 — 에러 없이 조용히) · [8] 숲길
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_forest_auto.gd         # **숲 원정** (세션 26): 출격 만HP · 적이 쫓아옴(그룹 "player") · 접촉 피해 · 🔴**적 레이어 계약**(4=enemy가 아니면 부딪히기만 하고 take_hit이 안 불린다) · 귀환/사망 계약(extraction_success·bag_lost)
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_workshop_auto.gd      # **공방 장비 제작** (세션 32): 레시피 station 분리(정제대⇔공방) · 펜 제작(spend→add) · 장착 라운드트립(equip→correction 0.35→소비, unequip→반환) · 🔴**패널 클릭은 헤드리스가 못 잡는다**(실게임 push_input로 별도 검증)
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_audio_auto.gd         # **사운드 배선** (세션 33): 17 SFX 로드·길이>0 · Audio가 EventBus 9종에 연결 · 발신→올바른 스트림(부작용 순간은 연결만) · 🔴**소리가 실제로 나는지는 헤드리스가 못 잡는다**(오디오 드라이버 없음 — 버스 라우팅·playing은 에디터 실게임 exec로 별도 검증)
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_decode_auto.gd        # **탁본 해독** (세션 34 E4): 조각 소비+룬 해금(codex_unlocked) · 이미 배운 룬은 조각 안 닳림 · 해금이 룬 목록에 흐름 · 🔴**룬 탭 다중셀 렌더·클릭은 헤드리스가 못 잡는다**(문양 탭·refine과 동일 패턴 — 에디터 실게임 스샷으로 별도 확인: 불△·물▽ 셀·바람은 잠겨 안 뜸)
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_quests_auto.gd        # **진행 목표(퀘스트)** (세션 36): KILL/EXTRACT/UNLOCK 배선(enemy_died·extraction·codex_unlocked → advance_quests) · 🔴**requires 사슬 게이트**(잠긴 퀘스트는 이벤트로도 안 진행) · 보상 지급 · 🔴**소급 완료**(이미 해금된 룬 노리는 UNLOCK은 열리는 순간 완료 — 안 하면 사슬이 막힌다) · 저장 라운드트립 · 🔴**Q 패널 렌더·클릭 차단은 헤드리스가 못 잡는다**(전체화면 Control — 닫힘=발사 도달·열림=차단을 실게임 push_input으로 별도 확인, 액션 주입으론 못 잡는다)
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_dialogue_box_auto.gd  # **온보딩 대사 상자** (세션41): open(lines)→줄 넘김→finished · 빈 배열 즉시 finished · ESC 건너뛰기 · ui_modal_open 토글 · 🔴**클릭 진행·하단 밴드 렌더는 헤드리스가 못 잡는다**(실게임 push_input·스샷으로 별도 확인)
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_map_panel_auto.gd     # **원정 지도 패널** (세션41): open(data) 데이터 흡수 · 🔴**world↔map 좌표 왕복**(뮤테이션으로 검출력) · 클릭 역변환→marker_placed(지도 밖 무시) · ui_modal_open 토글 · 🔴**지도 렌더·클릭 도달은 헤드리스가 못 잡는다**(push_input은 **윈도우 픽셀**이라 캔버스 2배 — 실게임 exec push_input·스샷으로 별도 확인)
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_hud_toast_auto.gd     # **HUD 획득 토스트** (세션51): 같은 id 합치기(수량+수명 리셋) · 🔴**합친 줄은 맨 뒤로 이동**(안 하면 FIFO가 **방금 주운 줄**을 밀어낸다 — 시각이 아니라 버그) · 최대 3줄 FIFO · 수명 만료 · 🔴**보이는지·슬롯/막대와 겹치는지는 헤드리스가 못 잡는다**(MCP 스샷으로 별도 확인)
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_drop_pickup_auto.gd   # **바닥 드롭 픽업 + 자석 흡수** (세션46·51): setup→그룹 · 줍기 지연(지연 중 무시) · body_entered→add_to_bag+queue_free · 🔴**layer0/mask2 계약**(캐리어가 픽업에 안 부딪히게) · 🔴**자석**(반경 안이면 거리 단조감소·밖이면 정지·지연 뒤에만·**켜지면 취소불가**·도착 1회 뱅킹·item_collected 1회) · 🔴**null 가드 없으면 SCRIPT ERROR 36줄 내면서 OK 찍힌다**(grep 필수) · 🔴**반경 72px가 체감되는지·속도가 "빨려온다"로 읽히는지는 헤드리스가 못 잡는다**(실게임 좌표 실측 — 세50 감전연쇄 재발 자리)
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_enemy_ai_auto.gd      # **몬스터 AI** (세션46): 방어(armor_reduction→enemy_hit dealt 경감) · 재생(regen_per_sec, 상한 _def.hp) · 분산 경감 · 🔴**돌진/부유 움직임 "느낌"은 헤드리스가 못 잰다**(실게임 runtime_state로 속도파형·거리유지 별도 확인)
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_status_auto.gd        # **룬 상태이상·원소 반응** (세션49): 화상 DoT·젖음 감속·🔴**반응**(젖음+흙=진흙·젖음+번개=감전연쇄·화상+물=꺼짐·화상+풀=산불)·🔴**바람=확산**(자기 상태 안 남기고 옆 적에게 옮김)·중첩=갱신(누적 아님)·취약 증폭 · 🔴**DoT는 enemy_hit을 안 쏜다**(쏘면 피해숫자·히트스톱 도배) · 🔴**색으로 보이는지는 헤드리스가 못 잡는다**(실게임 _visual.modulate로 별도 확인)
```

🔴 **스위트를 돌리면 `user://save`가 날아간다** (세션 26 F3 이후). `SaveManager._ready`가 저장을
살려 놨으므로, `extraction_success`·`bag_lost`·`day_started`를 쏘는 테스트는 **진짜 세이브 파일을
쓴다** — `test_forest_auto`가 실제로 플레이 세이브를 테스트 찌꺼기로 덮었다. 그래서 세이브를
건드리는 테스트는 **끝에 `wipe_save()`로 뒷정리한다**(test_save_auto·test_forest_auto).
⚠ **뒷정리는 지울 뿐 복구가 아니다** — 플레이하던 세이브가 있으면 스위트가 그걸 날린다.
새 시그널을 쏘는 테스트를 더할 땐 **SaveManager가 물려 있는지 먼저 확인해라**.

🔴 **`-s` 테스트는 런타임 에러가 나도 "OK"를 찍을 수 있다.** 세션 22에 실제로 겪었다 —
`test_ring_trace_auto`가 내부 필드(`_slots`)를 더듬다가 리팩터로 그게 옮겨가자 에러로 함수가
**중단**됐는데 `failures=0`이라 통과로 보였다. **grep을 `_OK`만 하지 말고 `SCRIPT ERROR`도 같이 봐라.**
그리고 **테스트는 공개 API로만 검증해라** — 내부 필드는 리팩터 때 옮겨 다니는 물건이라 계약이 아니다.
⚠ **세션 23에 재발했다** (`test_ring_spell_auto`가 내부 `_deploy_now`를 옛 인자 수로 호출) —
같은 함정이 두 세션 연속 나왔다. 그리고 `test_ring_trace_auto`의 `_check`는 **실패할 때만 출력**해서
**침묵이 곧 통과**다 — 함수가 죽어도 조용하다.

🔴🔴 **그래서 초록불을 근거로 쓰지 마라 — 뮤테이션으로 검출력을 증명해라.** 고친 코드를 일부러
되돌려 **정확히 몇 개가 실패하는지** 확인한다. 세션 22·23이 전부 이 방식으로 잡았다.
실제로 세션 23의 기존 테스트 하나(`정밀도 < 0.8`)는 **옛 관대한 판정도 통과**해 검출력이 0이었다.

🔴 **balance 수치를 런타임에 흔들어 규칙을 검증할 수 없다** (세션 24에 알아냈다). GDScript는
static 함수 안의 **`const BAL.프로퍼티`를 컴파일 타임에 굳힌다** — `RP.BAL.ring_stability_min`을
0.8로 바꿔도 `RP.threshold()`는 **0.65를 돌려준다**(같은 인스턴스인데도. 실측 확인).
게임엔 무해하지만(수치를 런타임에 안 바꾼다) **테스트는 조용히 거짓 통과한다.**
→ 대신 **두 함수의 경계가 어긋나지 않는지 전 구간을 훑어라** (`test_ring_design_auto`의
「「사용 불가」⇔펑」이 그 방식이고, 뮤테이션으로 검출력을 확인했다).

🔴 **채점 수치는 헤드리스로 못 검증한다.** 테스트가 가이드 좌표를 그대로 찍으면 이탈이 0이라
**판정 반경을 뭘로 바꾸든 정밀도 100**이다 — 그린 게 아니라 아무것도 안 잰 것이다.
손맛은 **사용자가 마우스로 직접 그려 봐야** 정해진다(리드의 흔들림 시뮬레이션도 시뮬레이션이다).

🔴 **세션 21 대청소로 목록이 이만큼 줄었다.** 옛 자유 드로잉·옛 본 게임과 함께 그 테스트들도 지웠다.
**되돌리려면 git 이력**(삭제 직전 커밋 = `dcc3326`).

눈으로 보는 시험대(F6):
- `tests/test_ring_forge_panel.tscn` — 책 펼침(진→룬→문양본→문양을 손으로 따라 긋기) + 덮고 발사.
  조작: **오른쪽 셀 클릭=진·룬·문양본·문양 고르기**(세션 25에 Q·W 키 폐지) · 왼쪽 판에 손으로 긋기
  (**여러 획 OK** · **우클릭=다시 그리기** · 휠=크기) · ESC=덮기 · WASD·마우스=조준 · R=리셋 · E=책
  ⚠ 시험대는 Space도 발사로 받는다 — **시험대 사정이고 본 게임은 좌클릭만**이다(사용자 확정)
- `tests/test_ring_forge.tscn` — 칸 클릭 조립 **프로토타입**. ⚠ 본 게임과 **분리된 실험 씬**이고
  팔레트도 다르다(응집◎/확산✳/발산→). 기준 아님 — 헷갈리면 위쪽을 봐라.

**그냥 실행(F5) = 베이스캠프** (`src/base/base.tscn` = `run/main_scene`): WASD로 책상에 가서 **E** →
고리 조립 책 → **오른쪽에서 고르면 왼쪽에 밑그림이 뜨고**(세션 25 — 진·룬·문양 칸 전부 같은 규약)
그 위를 손으로 긋는다 → **[분석 ▶]** → 리포트에서 **[마력 주입]**(65점 이하면 펑). 맺으면 점수를
실은 채 `GameState.ring_designs`로 들어가 첫 빈 슬롯에 자동 장착된다.
⚠ **[분석 ▶]은 맺지 않는다** — 맺는 건 [마력 주입]이다. 세션 25까지 이 버튼 이름이 "맺기 (분석)"이라
누른 사람이 맺힌 줄 알고 책을 덮었다. 미달이라 안 맺히면 HUD가 이유를 띄운다(`commit_rejected`) —
**조용히 거부하지 마라**: 슬롯이 빈 채로 남으면 "맺었는데 안 나간다"가 된다.
✅ **세션 24: 베이스캠프에서 쏜다** — 책상 옆이 **연습장**(허수아비 5). 마우스=조준 ·
**좌클릭=발사**(🔴 Space 아님 — 사용자 확정) · **1~4=슬롯** · HUD가 슬롯 4칸(위력·점수)을 보여 준다.
쏘는 건 `GameState.ring_equipped[슬롯].to_assembly()` — **`to_assembly()`를 써야** 손그림 점수가
실려 그때 그 위력이 난다(직접 Dictionary를 만들면 score가 빠져 조용히 기준 위력이 된다).
✅ **세션 26: 왼쪽 숲길에서 E = 원정** — 숲(슬라임 7)에서 같은 조작으로 싸우고, **들어온
자리(남쪽)로 돌아가 E**를 누르면 귀환한다. 죽으면 0.9초 뒤 그냥 베이스로 (벌 없음).

🔴🔴 **헤드리스는 「클릭이 닿는다」도 모른다** (세션 25에 뼈아프게 배웠다). 사용자가 *"마법진이 다
그려져도 발사가 안됨"*이라 했는데 **전 스위트가 그린이었다**. 원인은 `Ground`(화면을 다 덮는
ColorRect)의 `mouse_filter`가 기본값 **STOP**이라 바닥이 좌클릭을 전부 먹은 것 —
`_unhandled_input`에 안 와서 `_fire()`가 아예 안 불렸다. **에러도 경고도 없다.**
리드의 검증이 전부 `_fire()` **직접 호출**·`attack_basic` **액션 주입**이라 **Control 계층을
건너뛰어** 두 세션을 못 잡았고, `push_input`으로 테스트를 새로 써도 **헤드리스에선 그냥 통과했다**
(렌더가 없어 Control 히트 테스트가 실제와 다르다). **에디터로 띄운 실제 게임에서만 0회→1회로
재현됐다.** → **마우스가 닿는 경로를 바꿨으면 `godot_exec`로 실제 게임에 
`viewport.push_input(InputEventMouseButton)`을 밀어 확인해라.** 액션 주입은 이 버그를 못 잡는다.

🔴 **이건 베이스만의 얘기가 아니다 — 새 씬을 만들 때마다 되살아난다.** 세션 26에 숲 Ground의
`mouse_filter = 2`를 빼 보니 **실제 게임에서 발사 0회**였고, 그때도 **헤드리스 전 스위트는
그린이었다**(신규 `test_forest_auto` 포함). **화면을 덮는 Control을 새로 깔았으면 `mouse_filter = 2`를
적었는지 확인하고 실제 게임에서 클릭을 밀어 봐라.**

🔴 **헤드리스는 "존재"만 확인하고 "보인다"는 못 본다** (memory `takbon-mcp-visual-verify`).
렌더·레이아웃을 건드렸으면 **에디터로 띄워 스샷으로 확인해라** — 세션 22의 `ring_board` 분할과
책 씬화(I5)는 테스트가 전부 그린이어도 스샷으로 최종 확인했다(둘 다 픽셀 동일).

**알려진 함정**: `-s` SceneTree 테스트 스크립트는 오토로드 전역 등록 전에 컴파일된다 — 오토로드 식별자(EventBus 등)를 컴파일 타임 참조하면 에러. `root.get_node("/root/EventBus")` 런타임 조회 + 모듈 스크립트는 첫 프레임 후 `load()` 지연 로드로 우회 (기존 테스트 파일들 참고).

**Godot 에디터 노이즈**: 에디터 자체의 split_container.cpp 인덱스 에러는 Godot 4.6 에디터 버그 — 게임 문제 아님, 무시.

## 에디터·MCP

- godot-mcp 애드온 설정됨 (.mcp.json). 에디터 실행: `Start-Process .\Godot_v4.6.1-stable_win64.exe -ArgumentList "--editor","--path","."`
- project.godot을 파일로 수정한 후에는 `godot_project check_stale` → 필요시 에디터 restart
