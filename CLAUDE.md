# 탁본 (TAKBON) — Godot 4.6.1 · 2D 탑다운 익스트랙션 로그라이트

낮에는 숲에서 사냥하며 글자를 탁본하고, 밤에는 마법진을 손으로 그리는 게임.
1인 개발(사용자) + Claude 리드 세션 + 서브에이전트 팀으로 개발한다.

## 새 세션이 먼저 읽을 것

> 🔴🔴 **세션 21(2026-07-17) 대청소 — 여기부터 읽어라. 아래 docs는 대부분 낡았다.**
>
> **지금 게임 = `src/playground/base.tscn`(베이스캠프, `run/main_scene`) + 고리 조립 책.** 그게 전부다.
> **마법진 = 「고리 조립」**: 진=바깥 그릇(투사체 몸) · 룬=중심(속성) · 문양=진과 룬 사이 고리 칸 ·
> 문양본(스텐실)=어느 칸을 여는 틀 · 방향=어느 칸을 채우냐 · 발사=진이 통째로 날아가 착탄점에서 전개.
> 확정 뒤 손으로 따라 그어(탁본) 맺는다.
>
> **사용자 판단: "이전에 AI들이 멋대로 많이 만들어낸 코드" → 삭제했다.** 옛 자유 드로잉($1 인식기·캔버스·
> 책자·종이/잉크 경제)과 옛 본 게임(src/base 거점·field 원정·ui HUD/도감/게시판·tutorial·quest)이 통째로
> 사라졌다. 되돌리려면 git 이력(삭제 직전 = `dcc3326`). **"하나씩 다시 만든다"가 방침이다.**
>
> ⚠ **docs/ 전체가 옛 자유드로잉 기준이다** — TRUTH·GDD·TECH_SPEC·CHANGELOG는 삭제된 시스템을 설명한다.
> 사실로 믿지 마라. 아직 안 지운 건 설계 근거가 남아 있어서다.
> 📖 **현재 정본** = 이 파일 + `docs/STATUS.md` 최상단 + memory `takbon-playground-clean-restart`.

- **docs/STATUS.md** — 세션별 진행 로그 (세션 종료 시마다 갱신). 옛 로그는 STATUS_ARCHIVE.md
- docs/TRUTH.md · GDD.md · TECH_SPEC.md · CHANGELOG.md — ⚠ **옛 자유드로잉 아카이브**. 경제·적·저장
  계약 일부만 유효. 고리 모델 재작성은 아직 안 됐다
- docs/BACKLOG.md · TEAM_PLAN.md · ART_SPEC.md(에셋·아트 방향 960×540·48px)

## 아키텍처 요약

- **진입점**: `src/playground/base.tscn` (베이스캠프 — 바닥·탁본 책상·WASD). 책상 E → 고리 조립 책
- **오토로드**: EventBus(시그널 허브) / GameState(자원·HP·장착·가방·도감) / Clock(낮밤 시간) /
  Db(data/ 레지스트리) / SaveManager(user://save, 자동 저장)
  - ⚠ **오토로드엔 옛 SpellDesign 경로가 아직 데이터 구조로 남아 있다** (EventBus 시그널 타입·
    GameState.designs/equipped·SaveManager 도안 저장). 쓰는 코드는 없지만 스키마를 지우면 파싱이 깨진다
    → core 수술은 대청소 2단계 (미착수)
  - ⚠ `save_manager.gd:8`이 `src/base/research_service.gd`를 preload한다(스스로 위반이라고 주석에 적혀
    있다). 그래서 src/base에 `research_service.gd`·`recipes.gd`만 살아남았다
- **남은 모듈**: `src/playground`(베이스캠프) · `src/drawing`(고리 조립 = ring_board·ring_book·
  ring_forge_panel **셋뿐**) · `src/spell`(발사 — projectile/shockwave/pillar는 `data/runes/*.tres`가
  물고 있어 못 지운다) · `src/core`(리드 전용)
- 모듈 간 통신은 **EventBus 시그널 + core 스키마만**. 타 모듈 직접 preload/get_node 금지
- 밸런스 수치는 전부 **data/balance.tres** (BalanceData) — 코드에 수치 금지
- typed GDScript 강제. 렌더러 Compatibility, **뷰포트 960×540**(세션 18에 640×360에서 올림, aspect=expand)

## 개발 규칙 (병렬 에이전트 운영 시)

- **git 커밋은 리드(메인 세션)만.** 에이전트는 자기 모듈 폴더 + tests/ 자기 접두사 파일만 수정
- 에이전트 새 스크립트에 **class_name 선언 금지** → `const X := preload(...)` (전역 클래스 캐시는 리드의 `--import` 때만 갱신됨)
- 에이전트는 mcp__godot__* 도구 사용 금지 (에디터는 리드가 관리)
- 스키마·시그널 추가 요청은 에이전트가 보고 → 리드가 core에 반영 (지금까지 전부 이 방식으로 처리됨)

### 🔴 에이전트 위임 라우팅 (2026-07-17 세션 20 — 사용자: "godot 에이전트를 실제로 써라")

> 로컬 Donchitos 49-에이전트 하네스는 이 1인 playground엔 과함이라 제거했다. **Godot 구현 위임은
> `godot-prompter` 플러그인 에이전트로 한다.** 리드가 "직접 다 하는" 습관을 버리고, 아래 조건이면 위임한다.

- **구현 위임 대상 = `godot-prompter:godot-game-dev`** (GDScript 구현·씬·시스템). 설계/계획은
  `godot-prompter:godot-game-architect`, 코드 리뷰는 `godot-prompter:godot-code-reviewer`,
  Control UI는 `godot-prompter:godot-ui-designer`, 셰이더는 `godot-shader-author`.
- **언제 위임하나:** 한 모듈(src/drawing·field·base·ui 등) 안에서 닫히고 병렬화 이득이 있는 구현 작업.
  **언제 리드가 직접:** 인식률·저장 등 회귀 위험이 크고 tight한 검증 루프가 필요한 작업, core 스키마 변경,
  mcp__godot 필요 작업, 커밋. (세션 20 룬·문양 데이터화는 회귀 위험 커서 리드가 직접 한 정당한 예.)
- **위임 시 프로젝트 규칙을 프롬프트에 반드시 주입** — 플러그인 에이전트는 이 규칙을 모른다:
  typed GDScript / class_name 금지(`const X := preload`) / 모듈 간은 EventBus+core 스키마만 /
  수치는 data/balance.tres / mcp__godot 금지 / 커밋은 리드 / 자기 모듈 폴더+tests 자기 접두사만 수정.
- 검증·`--import`·커밋은 위임 후에도 **리드가 직접** 돌린다(위 검증 명령).

## 검증 명령 (반드시 Bash에서 — PowerShell은 자식 프로세스 stdout을 안 보여줌)

**전 스위트를 다 돌려라.** 목록에서 빠진 테스트는 낡아 죽는다 — 실제로 세션 7이 문법을 바꾸면서
`test_paper_auto`(8건)와 `test_drawing_canvas_auto`(1건)가 목록에 없다는 이유로 **조용히 깨진 채
방치됐다** (세션 8에 발견·복구).

```bash
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_save_auto.gd            # 저장/로드 (고리 라운드트립 — 옛 SpellDesign 검증은 세션 21에 걷어냄)
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_ring_spell_auto.gd      # **고리 발사**: 진→투사체·착탄 전개(발산 탄환·응집 기둥)·실제 적 take_hit
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_ring_trace_auto.gd      # **손그림 탁본**: 자동추적(선에 붙음)·완성도/정밀도 점수·[다음] 수동 진행·분석 리포트·문양 칸 자유 편집
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_ring_design_auto.gd     # **고리 도안 통합**: RingDesign 라운드트립·ring_design_committed→GameState 자동 장착
```

🔴 **세션 21 대청소로 목록이 이만큼 줄었다.** 옛 자유 드로잉(인식기·캔버스·책자·종이/잉크 경제)과
옛 본 게임(src/base 거점·field·ui·tutorial·quest)이 **삭제**되면서 그 테스트들(integration·drawing·
glyph·canvas·paper·forge·spell·base·onboarding·fill·equip·quest·bosscut·field·ui·sanity_check)도 함께
지웠다. **되돌리려면 git 이력**(삭제 직전 커밋 = `dcc3326`).

눈으로 보는 시험대(F6):
- `tests/test_ring_forge_panel.tscn` — 책 펼침(진→룬→문양본→문양을 손으로 따라 긋기) + 덮고 발사.
  조작: Q·W=문양 고르기 · ✓맺기/ESC=덮기 · WASD·마우스=조준 · 좌클릭/Space=발사 · R=리셋 · E=책 · C=비움
- `tests/test_ring_forge.tscn` — 칸 클릭 조립 **프로토타입**. ⚠ 본 게임과 **분리된 실험 씬**이고
  팔레트도 다르다(응집◎/확산✳/발산→). 기준 아님 — 헷갈리면 위쪽을 봐라.

**그냥 실행(F5) = 베이스캠프** (`src/playground/base.tscn` = `run/main_scene`): WASD로 책상에 가서 **E** →
고리 조립 책. 맺으면 `GameState.ring_designs`에 들어간다. ⚠ **아직 발사 경로가 베이스캠프엔 없다**
(RingSpellSystem 미배선) — 쏘려면 위 시험대를 쓴다.

**알려진 함정**: `-s` SceneTree 테스트 스크립트는 오토로드 전역 등록 전에 컴파일된다 — 오토로드 식별자(EventBus 등)를 컴파일 타임 참조하면 에러. `root.get_node("/root/EventBus")` 런타임 조회 + 모듈 스크립트는 첫 프레임 후 `load()` 지연 로드로 우회 (기존 테스트 파일들 참고).

**Godot 에디터 노이즈**: 에디터 자체의 split_container.cpp 인덱스 에러는 Godot 4.6 에디터 버그 — 게임 문제 아님, 무시.

## 에디터·MCP

- godot-mcp 애드온 설정됨 (.mcp.json). 에디터 실행: `Start-Process .\Godot_v4.6.1-stable_win64.exe -ArgumentList "--editor","--path","."`
- project.godot을 파일로 수정한 후에는 `godot_project check_stale` → 필요시 에디터 restart
