class_name Enums
## 전역 enum — 매직 넘버 금지, 모든 모듈은 이 정의를 사용한다 (TECH_SPEC §4).

enum CircleType { FIXED, AIMED }
enum RuneType { FIRE, IMPACT, WATER, WIND }
enum StrokeRole { CIRCLE, RUNE, ARROW, TAIL, DECOR }
## 도안 작성 단계 — **진 → 룬 → 문양 순서를 강제한다** (TECH_SPEC §6.2).
## 인식기가 진의 안/밖으로 룬과 화살표를 가르므로 순서가 뒤집히면 오분류가 난다.
## 규칙이 아니라 문법이다 — 캔버스가 단계에 안 맞는 획을 거부하고, 체크리스트가 현재 단계를 보여준다.
## CIRCLE=진(원) 필요 / RUNE=룬 필요(조준 꼬리는 여기서 선택적으로) / ARROW=문양(화살표) 1개 이상
enum DrawStage { CIRCLE, RUNE, ARROW }
enum Status { NONE, BURN, KNOCKBACK, WET, FLOW }
enum Phase { MORNING, DAY, EVENING, NIGHT }
enum ItemKind { INK, PAPER, WAND, ROBE, CHARM, MATERIAL, FRAGMENT }
enum CastFailReason { NO_MANA, BROKEN, INVALID }
