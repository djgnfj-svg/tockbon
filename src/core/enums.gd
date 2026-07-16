class_name Enums
## 전역 enum — 매직 넘버 금지, 모든 모듈은 이 정의를 사용한다 (TECH_SPEC §4).

enum CircleType { FIXED, AIMED }
## 룬 = 순수 원소만 (v2.2, TRUTH §4 세션 14). **충격(옛 =1)은 룬을 떠나 문양(추진)으로 갔다** —
## 충격만 원소가 아니었고(불·물·바람=원소, 충격=물리력), 넉백은 화살표 충격파와 중복이었다.
## ⚠ **WATER=2·WIND=3 값을 일부러 유지한다** — 이 값을 밀면 기존 세이브·.tres의 rune_type이
## 조용히 깨진다. 1은 레거시 IMPACT 구멍으로 비워 둔다 — 세션 22에 마이그레이션 코드
## (SpellDesign.migrate_legacy_runes)는 도안 모델과 함께 매장했지만, **구멍은 그대로 둔다**:
## 값을 밀면 남은 세이브·.tres가 조용히 깨진다.
enum RuneType { FIRE = 0, WATER = 2, WIND = 3 }
## 룬 이터레이션은 항상 명시적 리스트로 (RuneType.size()/range 금지 — 구멍 때문).
const RUNE_TYPES: Array[int] = [RuneType.FIRE, RuneType.WATER, RuneType.WIND]
const LEGACY_IMPACT: int = 1  # 옛 RuneType.IMPACT — 마이그레이션 판정용
## 🔴 **발사 계약** — 고리의 문양 칸에 들어가는 정수 코드. 착탄 전개를 이 값이 가른다:
##   GATHER = 착탄점에 기둥(안쪽으로 모인다) · RADIATE = 그 방향으로 탄환(바깥으로 퍼진다).
## ⚠ 이 값이 **계약이다** — 조립 UI(ring_board)가 쓰고 발사(ring_spell_system)가 읽고
## `data/glyphs/*.tres`의 `code`가 이 값이다. **밀면 저장된 고리 도안이 조용히 깨진다.**
## 세션 22: 이게 core에 없어서 발사가 UI(ring_board 757줄 Control)를 preload해 정수 2개를
## 꺼내 쓰고 있었다 — 발사가 UI에 의존하는 방향이라 헤드리스 발사·UI 교체를 정면으로 막았다.
enum GlyphCode { GATHER = 0, RADIATE = 1 }

enum StrokeRole { CIRCLE, RUNE, ARROW, TAIL, DECOR }
## 문양의 **발동 방식** — v1.9 문양 축 (GDD §4.3, TECH_SPEC §4.0-a).
## 문양 1개 = 1발이고, 그 탄이 **어떻게 나가는가**를 이 글자가 정한다.
## BASIC = **어느 글자도 아닌 획** — 인식 실패는 거부가 아니라 **폴백**이다.
## 튜토리얼 첫 도안(곧은 화살표)이 그대로 유효하고, 구세이브 도안도 전부 BASIC으로 로드된다.
## BOUNCE·HOMING·PIERCE는 **탁본으로 배우는 어휘**다 (룬·진에 이은 세 번째).
## 🔴 **THRUST(추진) = v2.2 신설** (TRUTH §4): 옛 충격 룬의 '힘'이 문양으로 왔다 — 탄이 **빠르게**
## 날아간다(속도 = 그동안 임자 없던 축). 지금은 메커니즘만 (2a) — 손으로 그려 인식하는 건 F1 슬라이스(2b).
enum GlyphType { BASIC, BOUNCE, HOMING, PIERCE, THRUST }
## 도안 작성 단계 — **진 → 룬 → 문양 순서를 강제한다** (TECH_SPEC §6.2).
## 인식기가 진의 안/밖으로 룬과 화살표를 가르므로 순서가 뒤집히면 오분류가 난다.
## 규칙이 아니라 문법이다 — 캔버스가 단계에 안 맞는 획을 거부하고, 체크리스트가 현재 단계를 보여준다.
## CIRCLE=진(원) 필요 / RUNE=룬 필요(조준 꼬리는 여기서 선택적으로) / ARROW=문양(화살표) 1개 이상
enum DrawStage { CIRCLE, RUNE, ARROW }
## 지팡이의 **발사 패턴** — v2.0 지팡이 축 (TECH_SPEC §4.0-a).
## 사용자: *"결국 보는 방향으로 발사가 맞고, **지팡이에 따라** 여러 발이 나가거나
## 내 주변에서 전체 방향으로 나가거나가 정해짐."*
##
## 🔴 **도안이 아니라 지팡이가 발수를 정한다.** v1.9까지는 문양 1개 = 1발이었는데, 방향이
## 지팡이로 간 순간 그게 무너졌다 — 문양이 방향을 안 정하면 N발이 **같은 자리에 겹친다.**
## SINGLE=단발 / MULTI=산탄(에임 좌우로 퍼짐) / NOVA=전방위(내 주변 사방)
enum WandPattern { SINGLE, MULTI, NOVA }
enum Status { NONE, BURN, KNOCKBACK, WET, FLOW }
enum Phase { MORNING, DAY, EVENING, NIGHT }
enum ItemKind { INK, PAPER, WAND, ROBE, CHARM, MATERIAL, FRAGMENT }
enum CastFailReason { NO_MANA, BROKEN, INVALID }
