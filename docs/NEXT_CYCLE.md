# NEXT_CYCLE — 다음 세션 구현 명세 (바로 착수 가능하게 계약까지 정의)

> 2026-07-12 작성. 우선순위순. 각 건은 서브에이전트 1개 분량으로 스코프됨.
> 착수 절차: 리드가 core 계약(스키마·시그널) 먼저 반영 → 에이전트 투입 (TEAM_PLAN 규칙 그대로).

## 1. 장비 착용·효과 (GDD §5) — 경제 루프 완성 조각

**계약 (리드가 core에 먼저 추가):**
- `GameState.equipment: Dictionary` — {Enums.ItemKind.WAND: StringName, ROBE: ..., CHARM: ...} (착용 아이템 id, 없으면 빈)
- `GameState.equip_gear(item_id) / unequip_gear(kind)` — 창고에 있는 장비만 착용 가능
- EventBus에 `signal equipment_changed` 추가
- **착용 중 장비는 사망해도 보존** (GDD: 가방 소지품만 손실) — 착용=가방 아님을 명시
- ItemDef.params 효과 키 규약:
  - 완드: `attack_cooldown_mult`(연사), `wand_damage_add`(약공격), `aim_assist`(예약)
  - 로브: `mana_max_add`, `hp_max_add`
  - 부적: `dash_cooldown_mult` (기본 부적), 이후 특수는 부적별 자유 키
- 파생 스탯 getter: `GameState.mana_max() / hp_max()` — balance 기본값 + 장비 보정. **기존 balance.mana_max 직접 참조처(HUD·player 등)를 전부 getter로 교체**하는 것까지가 이 작업의 범위

**구현 (에이전트, src/base+src/field 소폭):** 창고 패널에 착용 UI(모듈 D 영역), player.gd가 완드·부적 params 반영, 시작 장비(wand/robe/charm_basic) 자동 착용을 main 시드에 추가. DoD: 장비 착용→마나 상한·연사·대시 쿨다운 변화 자동 검증.

## 2. 종이 등급 적용 (GDD §5) — "캔버스 크기·마나 감면·내구도"

**계약:** paper params는 이미 정의됨 (`ink_capacity` 20/32/48, `mana_discount` 0/0.1/0.2, `durability_bonus` 0/5/12 — data/items/paper_*.tres).
**구현 (에이전트, src/drawing):**
- 드로잉룸 진입 시(또는 캔버스 리셋 시) 종이 선택 UI — 보유 종이만 선택 가능, **도안 완성 시 종이 1장 소모** (GameState.remove_item)
- design_builder: `mana_cost ×= (1-mana_discount)`, `durability_max += durability_bonus`, `paper_grade` 기록
- **잉크 상한 = ink_capacity**: 캔버스에 잉크 게이지 표시, 초과 시 획 무효+경고 (지우면 회복)
- 튜토리얼은 paper_1 자동 지급 상태에서 진행 (시드에 paper_1 있음)
- DoD: 등급별 마나·내구·상한 차이 자동 검증 + 종이 소모 확인

## 3. 퀘스트 온보딩 (GDD 4개월차) — 튜토 이후 목표 안내

**구현 (에이전트, 신규 src/quest):** 선형 목표 스택 — 기존 시그널만으로 판정 (신규 시그널 불요):
1. 튜토 완료(codex_unlocked tutorial_done) → "숲에서 수액 슬라임 우두머리를 찾아 물의 글자를 탁본하라" (rubbing_completed fragment_water)
2. → "연구소에서 물의 글자를 해독하라" (research_completed rune_water)
3. → "물의 도안을 그려 갑주 갑충을 무찔러라" (enemy_died beetle)
4. → "숲 북쪽의 바람을 품은 존재에 도전하라" (enemy_died gale) → 데모 종료 지점
- HUD 우상단 목표 1줄 (완료 시 체크 연출 후 다음 목표). 진행은 codex 방식으로 저장(`quest_<n>` unlock — SaveManager 자동 커버)
- 납품: src/quest/quest.tscn — Main UILayer에 1줄 통합 (튜토리얼과 동일 패턴)

## 4. 중간보스 등장 컷 (GDD §9 데모 마지막 장면)

**구현 (에이전트 또는 리드, src/field):** 보스 존 첫 진입 시 1회 — 시간 짧은 연출 스텁: 화면 어둡게 → 보스 실루엣 확대 → "바람이 글자를 삼켰다" 한 줄 → 전투 개시. 카메라 이동+CanvasModulate 트윈 수준 (무겁게 만들지 말 것). 트리거 지점 주석 있음: field.gd `_build_boss_zone`.

## 5. UX 마무리 (리드 직접, 소규모)

- 게시판·모달 열림 중 플레이어 이동 잠금 (E의 모달 → GameState 플래그 or 시그널)
- 필드에서 자정 시 게시판 자동 팝업 억제 (거점에서만)

## 6. 아트 착수 (Aseprite MCP 설치 후) — docs/ART_SPEC.md 참조

사용자가 Aseprite 정품 보유, MCP 설치 예정. 설치되면 ART_SPEC.md의 P1(주인공·룬 글리프)부터. 팔레트 확정이 첫 작업.
