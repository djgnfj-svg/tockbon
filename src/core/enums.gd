class_name Enums
## 전역 enum — 매직 넘버 금지, 모든 모듈은 이 정의를 사용한다 (TECH_SPEC §4).

enum CircleType { FIXED, AIMED }
enum RuneType { FIRE, IMPACT, WATER, WIND }
enum StrokeRole { CIRCLE, RUNE, ARROW, TAIL, DECOR }
## 문양의 **발동 방식** — v1.9 문양 축 (GDD §4.3, TECH_SPEC §4.0-a).
## 문양 1개 = 1발이고, 그 탄이 **어떻게 나가는가**를 이 글자가 정한다.
## BASIC = **어느 글자도 아닌 획** — 인식 실패는 거부가 아니라 **폴백**이다.
## 튜토리얼 첫 도안(곧은 화살표)이 그대로 유효하고, 구세이브 도안도 전부 BASIC으로 로드된다.
## 나머지 셋은 **탁본으로 배우는 어휘**다 (룬·진에 이은 세 번째).
enum GlyphType { BASIC, BOUNCE, HOMING, PIERCE }
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
