class_name Enums
## 전역 enum — 매직 넘버 금지, 모든 모듈은 이 정의를 사용한다 (TECH_SPEC §4).

enum CircleType { FIXED, AIMED }
## 룬 = 순수 원소만 (v2.2, TRUTH §4 세션 14). **충격(옛 =1)은 룬을 떠나 문양(추진)으로 갔다** —
## 충격만 원소가 아니었고(불·물·바람=원소, 충격=물리력), 넉백은 화살표 충격파와 중복이었다.
## ⚠ **WATER=2·WIND=3 값을 일부러 유지한다** — 이 값을 밀면 기존 세이브·.tres의 rune_type이
## 조용히 깨진다. 1은 레거시 IMPACT 구멍으로 비워 둔다 — 세션 22에 마이그레이션 코드
## (SpellDesign.migrate_legacy_runes)는 도안 모델과 함께 매장했지만, **구멍은 그대로 둔다**:
## 값을 밀면 남은 세이브·.tres가 조용히 깨진다.
## 🔴 세션49: BOLT=4·EARTH=5·GRASS=6 추가 (1은 옛 IMPACT 자리라 비워 둔 채 끝에 붙였다).
enum RuneType { FIRE = 0, WATER = 2, WIND = 3, BOLT = 4, EARTH = 5, GRASS = 6 }
## 룬 이터레이션은 항상 명시적 리스트로 (RuneType.size()/range 금지 — 구멍 때문).
const RUNE_TYPES: Array[int] = [RuneType.FIRE, RuneType.WATER, RuneType.WIND,
	RuneType.BOLT, RuneType.EARTH, RuneType.GRASS]
const LEGACY_IMPACT: int = 1  # 옛 RuneType.IMPACT — 마이그레이션 판정용
## 🔴 **발사 계약** — 고리의 문양 칸에 들어가는 정수 코드. 착탄 전개를 이 값이 가른다:
##   GATHER = 착탄점에 기둥(안쪽으로 모인다) · RADIATE = 그 방향으로 탄환(바깥으로 퍼진다).
## ⚠ 이 값이 **계약이다** — 조립 UI(ring_board)가 쓰고 발사(ring_spell_system)가 읽고
## `data/glyphs/*.tres`의 `code`가 이 값이다. **밀면 저장된 고리 도안이 조용히 깨진다.**
## 세션 22: 이게 core에 없어서 발사가 UI(ring_board 757줄 Control)를 preload해 정수 2개를
## 꺼내 쓰고 있었다 — 발사가 UI에 의존하는 방향이라 헤드리스 발사·UI 교체를 정면으로 막았다.
# 🔴 발사 계약 코드 (GlyphDef.code · ring_spell_system._deploy_now가 이 값으로 전개를 가른다).
# 값을 바꾸면 저장된 도안이 조용히 깨진다 — **끝에만 덧붙인다**.
#   GATHER(0)=착탄점에 기둥 · RADIATE(1)=그 방향 탄환 · PIERCE(2)=탄환인데 적을 뚫는다(세션44 B).
#   HOMING(3)=적을 쫓는 탄 · BOUNCE(4)=벽에 튕기는 탄 · THRUST(5)=빠른 탄 (세션47 — 어휘 배증).
# ⚠ 이건 "착탄 전개" 축이다. 탄의 행동 효과(GlyphType.BOUNCE/PIERCE/HOMING/THRUST)는 별 enum이며
# projectile.gd가 소비한다 — PIERCE(발사코드 2)는 발사 때 GlyphType.PIERCE 효과로 번역된다.
#
# 🔴 세션 47: 2~5는 전부 **발산 계열**(바깥으로 탄을 쏜다)이고, 다른 건 그 탄이 **어떻게 나는가**뿐이다.
# 즉 이 축은 "세기"가 아니라 **전투 방식**을 가른다 — 자유도 구멍(memory takbon-magic-no-freedom)에
# 대한 답이 여기 있다. 기계(projectile._setup_effects)는 세션44 이전부터 완성돼 있었고 어휘가 없어
# 잠들어 있었을 뿐이다. **새 문양 = data/glyphs/*.tres 한 장 + 여기 값 하나 + deploy 분기 하나.**
# 🔴 세79 M1 「진별 해석」: SPREAD(6)·EXPLODE(7) = **변형형 문양**. 위 0~5와 **계열이 다르다** —
# 0~5는 착탄점에서 스스로 전개하는 **전개형**이고, 6~7은 **안쪽 층의 결과를 받아 바꾸는 연산자**다
# (`폭발(확산(불))`). 그래서 칸 값 하나로 안 끝나고 **층(밴드) 순서**가 의미를 갖는다 —
# 해석은 `ring_spell_system._deploy_now`의 층 루프가 한다. 끝에만 덧붙였다(저장 도안 무회귀).
#   SPREAD(6)=확산: 안쪽 결과의 **각 갈래를 여러 개로 복제해 부채꼴로 벌린다**(넓힘, 갈래마다 세기↓)
#   EXPLODE(7)=폭발: 안쪽 결과를 **통째로 하나의 광역 폭발로 융합한다**(안쪽이 넓게 퍼져 있을수록 반경↑)
# 🔴 두 문양의 성격이 갈려야 순서가 눈에 보인다 (사용자 확정 세79): 폭발이 "각 갈래를 각각 터뜨림"이면
# `폭발(확산(불))`과 `확산(폭발(불))`이 둘 다 "작은 폭발 여러 개"가 돼 순서 실증이 실패한다.
enum GlyphCode { GATHER = 0, RADIATE = 1, PIERCE = 2, HOMING = 3, BOUNCE = 4, THRUST = 5,
	SPREAD = 6, EXPLODE = 7 }
## 🔴 **변형형 문양 집합** — 이 값이 계열 판별의 **단일 소스**다. 발사(층 해석기)·조립 UI·책이
## "이 문양은 전개형인가 변형형인가"를 물을 때 전부 여기를 본다. 복사해 두면 갈라진다
## (`ring_power`가 리포트·발사에 같은 함수를 주는 것과 같은 이유).
## **새 변형형 문양 = GlyphCode 값 하나 + 여기 한 줄 + `_apply_modifier` 분기 하나.**
const MODIFIER_GLYPHS: Array[int] = [GlyphCode.SPREAD, GlyphCode.EXPLODE]

static func is_modifier_glyph(code: int) -> bool:
	return code in MODIFIER_GLYPHS

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
##
## 🔴 세션48: BURST·SPRAY·SEEK를 **끝에 덧붙였다** (문양 GlyphCode와 같은 규약 — 중간에 끼우면
## 저장된 JinDef.pattern·옛 도안이 통째로 밀린다). 이제 이 enum은 지팡이가 아니라 **진**의 축이다.
##   BURST=연발(같은 각도로 시간차) · SPRAY=분사(좁은 각 연속) · SEEK=타겟팅(가장 가까운 적을 골라 감)
enum WandPattern { SINGLE, MULTI, NOVA, BURST, SPRAY, SEEK }
## 🔴 진의 **비행 경로** (세션48 신설). WandPattern이 "언제·어디로 몇 발"이라면 이건 "어떻게 나는가"다.
##
## 두 축을 가른 이유: 세션44에 진 3개가 WandPattern 3개를 1:1로 소진해 **"새 진 = .tres 한 장"이
## 깨져 있었다**(4번째 진 = 새 발사 기하 = 코드). 경로를 독립 축으로 빼면 둘이 **직교**해 조합이
## 열린다 — 나선 산탄·부메랑 연발이 전부 데이터 한 장이다. 축을 늘리는 게 진을 늘리는 것보다 싸다.
##   STRAIGHT=직진 · SPIRAL=나선(사인파로 훑으며 전진) · BOOMERANG=부메랑(나갔다 되돌아온다)
enum JinMotion { STRAIGHT, SPIRAL, BOOMERANG }
## 🔴 진의 **밑그림 도형** (세션48 신설, 사용자 확정: *"진의 궤적은 원처럼 닫힌 도형이어야 함 —
## 그 안에 룬이 들어가야 해서"*). 진 = 룬을 담는 **그릇**이라 궤적이 반드시 **닫혀** 있어야 한다.
##
## 세션44~48까지 진은 종류와 무관하게 **전부 같은 원**이었다 — 룬이 세션34에 종류별 닫힌 다각형을
## 받은 것(`_rune_guide_verts`: 불△·물▽·바람◇)과 달리 진만 그 처리를 못 받았다. 그래서 진을
## 8개로 늘려도 **손 궤적이 똑같아 "색만 다른 8지선다"**가 된다(memory `takbon-glyph-design-principle`).
## 🔴 **`pattern`에서 유추하지 말고 데이터로 둔다** — pattern×motion 조합이 열리면 유추가 깨진다.
##   CIRCLE=원 · TRIANGLE=정삼각 · OCTAGON=팔각 · ELLIPSE=세로 긴 타원
##   PENTAGON=오각 · DIAMOND=마름모 · FLOWER=물결 원(꽃잎) · LENS=렌즈(양쪽 볼록)
enum JinShape { CIRCLE, TRIANGLE, OCTAGON, ELLIPSE, PENTAGON, DIAMOND, FLOWER, LENS }
## 🔴 상태이상 (세션49에 비로소 **실제로 적용**된다 — 세34~48까지 `forest_enemy.take_hit`이
## `_status`를 밑줄로 버려 불·물·바람의 실질 차이가 **색 + 데미지 ±15%**뿐이었다).
##
## 🔴 **설계 원칙 (사용자 확정 세션49): 단독은 약한 바탕, 조합에서 폭발한다.**
## 단독 효과를 다 없애면 한 발 쏠 때 아무 일도 안 나 밋밋하고, 단독이 다 세면 조합할 이유가 없다.
## 그래서 룬마다 **약한** 상태를 남기고, 그 위에 다른 룬이 오면 `StatusRules`가 **반응**시킨다.
## (선례 = 원신 Swirl/Crystallize — 바람·흙은 자체 효과를 억지로 만들지 않고 촉매로 둔다.)
##
## ⚠ **끝에만 붙여라** — 중간에 끼우면 저장된 RuneDef.status·옛 세이브가 통째로 밀린다.
##   SHOCK=감전(약한 경직) · VULNERABLE=취약(다음 상태가 더 세게 걸림, 흙) · ROOT=덩굴(약한 묶임, 풀)
##   MUD=진흙(**반응 산물** — 젖음+흙, 강한 속박) · BLAZE=산불(**반응 산물** — 화상+풀)
enum Status { NONE, BURN, KNOCKBACK, WET, FLOW, SHOCK, VULNERABLE, ROOT, MUD, BLAZE }
enum Phase { MORNING, DAY, EVENING, NIGHT }
## 🔴 PEN = 탁본 펜 (세션 23 신설). 등급이 오를수록 **보정도**가 올라 손을 잡아 준다
## (GameState.stroke_correction → trace_scorer). WAND(지팡이)와 역할이 달라 별도 부위다.
## 🔴 HAT = 모자 (세션 42 신설, 사용자 확정 "펜 유지 + 모자 추가 = 5부위"). 이동 속도 축
## (GameState.move_speed → player). 로브(생존)·부적(마나 지속)과 겹치지 않는 별도 축이다.
## ⚠ **끝에 붙였다** — 중간에 끼우면 저장된 equipment의 부위 키가 통째로 밀린다. HAT도 끝에.
enum ItemKind { INK, PAPER, WAND, ROBE, CHARM, MATERIAL, FRAGMENT, PEN, HAT }
enum CastFailReason { NO_MANA, BROKEN, INVALID }
## 🔴 퀘스트 목표 종류 (세션 36, "진행 목표 = 깊이 스파인"). data/quests/*.tres의 `goal`이 이 값.
## KILL=적 처치 · EXTRACT=살아서 귀환 · UNLOCK=도감 해금(룬) · DRAW=마법진 그리기(온보딩, 세션41 — count장).
## ⚠ .tres가 정수로 저장하니 재정렬 금지. DRAW는 **끝에 추가**했다(=3).
enum QuestGoal { KILL, EXTRACT, UNLOCK, DRAW }
