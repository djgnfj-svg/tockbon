# 탁본 (TAKBON) — Godot 4.6.1 · 2D 탑다운 익스트랙션 로그라이트

낮에는 숲에서 사냥하며 글자를 탁본하고, 밤에는 마법진을 손으로 그리는 게임.
1인 개발(사용자) + Claude 리드 세션 + 서브에이전트 팀으로 개발한다.

## 새 세션이 먼저 읽을 것 (순서대로)

1. **docs/STATUS.md** — 현재 진행 상태·다음 작업 (세션 종료 시마다 갱신됨)
2. **docs/GDD.md** — 기획서 **v1.9** (확정 스펙). **§4.0 역할 축이 이 게임의 심장이다.**
   **세 부품 전부 "모양 = 무엇을 / 크기 = 얼마나"로 읽힌다** — 배울 규칙이 셋이 아니라 하나다:

   | | **모양** | **크기** (÷ 진) |
   |---|---|---|
   | **진** | 구조 (원·별·용) | 규모 — 위력·탄 크기·기준 사거리 |
   | **룬** (N개) | 속성 (원소) | 농도 — 상태이상 세기 |
   | **문양** (N개) | 발동 방식 (팅김⚡·유도∿·관통‖) | 세기 — 사거리 배율·반사 횟수 |

   **룬 N개·문양 N개 조합이 핵심**이고, **진 모양(별·용의 진) 때문에 인식기를 $1→$P로 갈아야
   한다** (한붓그리기로는 원리적으로 불가능). **구현은 문양(v1.9)까지 — 진 모양·룬 N개는 아직**
3. **docs/TECH_SPEC.md** — 스키마·EventBus 시그널 계약. **모듈 간 인터페이스의 유일한 진실** — 변경은 리드만, 이 문서를 먼저 갱신 후 코드. **§4.0-a가 v1.9 구현/미구현 경계를 표로 가른다**
4. **docs/BACKLOG.md** — 아이디어·미결 항목 (문양 어휘 확장·보정·**중첩 진**). 확정되면 GDD로 승격
5. docs/TEAM_PLAN.md — 병렬 에이전트 운영 규칙 (모듈 분담·폴더 소유권)

## 아키텍처 요약

- **오토로드**: EventBus(시그널 허브) / GameState(자원·HP·장착 4장·가방·도감) / Clock(낮밤 시간) / Db(data/ 레지스트리) / SaveManager(user://save, 자동 저장)
- **모듈 폴더 = 소유권**: src/drawing($1 인식·캔버스) · src/spell(도안→발사) · src/field(전투·낮밤·탁본·보스) · src/base(거점 경제) · src/ui(HUD·도감) · src/tutorial(온보딩) · **src/core는 리드 전용**
- 모듈 간 통신은 **EventBus 시그널 + core 스키마만**. 타 모듈 직접 preload/get_node 금지
- 밸런스 수치는 전부 **data/balance.tres** (BalanceData) — 코드에 수치 금지
- typed GDScript 강제. 렌더러 Compatibility, 뷰포트 640×360

## 개발 규칙 (병렬 에이전트 운영 시)

- **git 커밋은 리드(메인 세션)만.** 에이전트는 자기 모듈 폴더 + tests/ 자기 접두사 파일만 수정
- 에이전트 새 스크립트에 **class_name 선언 금지** → `const X := preload(...)` (전역 클래스 캐시는 리드의 `--import` 때만 갱신됨)
- 에이전트는 mcp__godot__* 도구 사용 금지 (에디터는 리드가 관리)
- 스키마·시그널 추가 요청은 에이전트가 보고 → 리드가 core에 반영 (지금까지 전부 이 방식으로 처리됨)

## 검증 명령 (반드시 Bash에서 — PowerShell은 자식 프로세스 stdout을 안 보여줌)

**전 스위트를 다 돌려라.** 목록에서 빠진 테스트는 낡아 죽는다 — 실제로 세션 7이 문법을 바꾸면서
`test_paper_auto`(8건)와 `test_drawing_canvas_auto`(1건)가 목록에 없다는 이유로 **조용히 깨진 채
방치됐다** (세션 8에 발견·복구).

```bash
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_integration_auto.gd     # 통합 스모크
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_save_auto.gd            # 저장/로드
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_drawing_auto.gd         # 룬 인식기
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_glyph_auto.gd           # 문양 글자 인식(v1.9)·reach·손그림 스트레스
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_drawing_canvas_auto.gd  # 캔버스(작성 순서·스탬프)
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_paper_auto.gd           # 종이 등급·잉크 상한
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_forge_auto.gd           # 제작대(책 펼침)·종이 경제
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_spell_auto.gd           # 발사·문양 거동(팅김·유도·관통)
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_base_auto.gd            # 거점 경제
./Godot_v4.6.1-stable_win64.exe --headless --path . -s res://tests/test_onboarding_auto.gd      # 온보딩(튜토·시험발사)
./Godot_v4.6.1-stable_win64.exe --headless --path . res://tests/test_field.tscn --quit-after 600   # 필드·전투
./Godot_v4.6.1-stable_win64.exe --headless --path . res://tests/test_ui.tscn --quit-after 60       # UI
```

눈으로 보는 시험대(F6): `tests/test_forge.tscn` — 세계 안에서 작업대(E)로 책을 펼쳐 그리고 곧바로 쏜다.
**아레나에 벽·기둥이 있다** — 팅김⚡이 튕기는 면이고, 기둥 뒤 허수아비는 **곧은 탄으로는 못 맞힌다**
(팅김으로 돌아가 맞히라는 문제 제기). 화면 아래 라벨에 **문양별 글자·세기(reach)가 낱개로** 뜬다.

**알려진 함정**: `-s` SceneTree 테스트 스크립트는 오토로드 전역 등록 전에 컴파일된다 — 오토로드 식별자(EventBus 등)를 컴파일 타임 참조하면 에러. `root.get_node("/root/EventBus")` 런타임 조회 + 모듈 스크립트는 첫 프레임 후 `load()` 지연 로드로 우회 (기존 테스트 파일들 참고).

**Godot 에디터 노이즈**: 에디터 자체의 split_container.cpp 인덱스 에러는 Godot 4.6 에디터 버그 — 게임 문제 아님, 무시.

## 에디터·MCP

- godot-mcp 애드온 설정됨 (.mcp.json). 에디터 실행: `Start-Process .\Godot_v4.6.1-stable_win64.exe -ArgumentList "--editor","--path","."`
- project.godot을 파일로 수정한 후에는 `godot_project check_stale` → 필요시 에디터 restart
