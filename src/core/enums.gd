class_name Enums
## 전역 enum — 매직 넘버 금지, 모든 모듈은 이 정의를 사용한다.

## ⚠ 소비자 0 — 옛 조준진의 잔재다.
enum CircleType { FIXED, AIMED }
## 룬 = 순수 원소만 (충격은 원소가 아니라 문양(추진)으로 갔다).
## 🔴 값이 **연속이 아니다** — 1은 은퇴한 IMPACT 구멍이다. 값을 밀면 기존 세이브·.tres의
## rune_type이 조용히 깨지므로 구멍을 그대로 두고 **끝에만 덧붙인다**.
enum RuneType { FIRE = 0, WATER = 2, WIND = 3, BOLT = 4, EARTH = 5, GRASS = 6 }
## 🔴 룬 이터레이션은 항상 이 리스트로 — `RuneType.size()`/`range()`는 구멍 때문에 없는 룬을 만든다.
const RUNE_TYPES: Array[int] = [RuneType.FIRE, RuneType.WATER, RuneType.WIND,
	RuneType.BOLT, RuneType.EARTH, RuneType.GRASS]
const LEGACY_IMPACT: int = 1  # 옛 RuneType.IMPACT — 이 구멍을 메우지 마라.
## 🔴 **발사 계약** — 고리의 문양 칸에 들어가는 정수 코드. `data/glyphs/*.tres`의 `code`가 이 값이고
## 조립 UI(`ring_board`)가 쓰고 발사(`ring_spell_system._deploy_now`)가 읽어 착탄 전개를 가른다.
## 🔴 **값을 밀면 저장된 도안이 조용히 깨진다 — 끝에만 덧붙여라.**
##   GATHER(0)=착탄점에 기둥 · RADIATE(1)=그 방향 탄환 · PIERCE(2)=관통 · HOMING(3)=유도
##   BOUNCE(4)=튕김 · THRUST(5)=빠른 탄   ← 여기까지 **전개형**(착탄점에서 스스로 전개한다)
##   SPREAD(6)=확산 · EXPLODE(7)=폭발 · CONDENSE(8)=응축  ← **변형형**(안쪽 층 결과를 받아 바꾼다)
## ⚠ 이건 「착탄 전개」 축이다 — 탄의 행동 효과(`GlyphType`)는 별 enum이고 `projectile`이 소비한다.
## 변형형이 있어서 **층(밴드) 순서가 의미를 갖는다**(`폭발(확산(불))` ≠ `확산(폭발(불))`).
##  그래서 폭발은 갈래가 많을수록 넓어지고, 응축은 좁아지며 세진다(알고리즘은 같고 계수만 다르다).
## ⚠ 이 값을 UI 쪽 상수에서 되읽지 마라 — 발사가 UI에 의존하는 방향이 된다.
enum GlyphCode { GATHER = 0, RADIATE = 1, PIERCE = 2, HOMING = 3, BOUNCE = 4, THRUST = 5,
	SPREAD = 6, EXPLODE = 7, CONDENSE = 8 }
## 🔴 계열(전개형/변형형) 판별의 단일 소스는 `GlyphRules.BEHAVIORS`다 — 여기에 code 배열을
## 되살리지 마라(문양을 늘릴 때마다 `.tres`·상수·분기가 따로 논다).
## code 목록이 필요한 쪽은 `Db.modifier_codes()`를 부르고, `Db`를 못 보는 쪽은 **인자로 받는다**.

## ⚠ 소비자 0 — 옛 자유드로잉 획 분류의 잔재다.
enum StrokeRole { CIRCLE, RUNE, ARROW, TAIL, DECOR }
## 문양의 **발동 방식** — 문양 1개 = 1발이고, 그 탄이 어떻게 나가는가를 이 값이 정한다.
## BASIC = 어느 것도 아닌 폴백이다 — 인식 실패는 거부가 아니라 폴백이라 구세이브 도안이 전부 여기로 온다.
## 소비자 = `GlyphRules.EFFECTS` → `projectile._setup_effects`.
enum GlyphType { BASIC, BOUNCE, HOMING, PIERCE, THRUST }
## 도안 작성 단계 — 진 → 룬 → 문양 순서. 지금 쓰는 곳은 `RingAssembly`의 STAGE_* 별칭뿐이다.
enum DrawStage { CIRCLE, RUNE, ARROW }
## 🔴 진의 **발사 패턴** — 「언제·어디로 몇 발」. 이름의 `Wand`는 출신지일 뿐 지금 주인이 아니다:
## 형태는 진만 정하고, 소비자는 `ring_spell_system._shot_plan(jin_def.pattern)` 하나다.
##   SINGLE=단발 · MULTI=산탄(에임 좌우로 퍼짐) · NOVA=전방위 · BURST=연발(같은 각도 시간차)
##   SPRAY=분사(좁은 각 연속) · SEEK=타겟팅(가장 가까운 적)
## ⚠ 끝에만 덧붙여라 — 중간에 끼우면 저장된 `JinDef.pattern`이 통째로 밀린다.
enum WandPattern { SINGLE, MULTI, NOVA, BURST, SPRAY, SEEK }
## 🔴 진의 **비행 경로** — WandPattern이 「언제·어디로 몇 발」이면 이건 「어떻게 나는가」다.
## 두 축을 가른 이유: 붙여 두면 진 하나가 패턴 하나를 소진해 「새 진 = .tres 한 장」이 깨진다
## (4번째 진이 곧 코드가 된다). 직교시키면 나선 산탄·부메랑 연발이 전부 데이터 한 장이다.
##   STRAIGHT=직진 · SPIRAL=나선(사인파로 훑으며 전진) · BOOMERANG=부메랑(나갔다 되돌아온다)
enum JinMotion { STRAIGHT, SPIRAL, BOOMERANG }
## 🔴 진의 **밑그림 도형**. 진 = 룬을 담는 그릇이라 궤적이 반드시 **닫혀** 있어야 한다.
## 🔴 `pattern`에서 유추하지 말고 데이터로 둔다 — pattern×motion 조합이 열리면 유추가 깨진다.
## 도형이 갈리지 않으면 진을 8개로 늘려도 손 궤적이 똑같아 「색만 다른 8지선다」가 된다.
##   CIRCLE=원 · TRIANGLE=정삼각 · OCTAGON=팔각 · ELLIPSE=세로 긴 타원
##   PENTAGON=오각 · DIAMOND=마름모 · FLOWER=물결 원(꽃잎) · LENS=렌즈(양쪽 볼록)
enum JinShape { CIRCLE, TRIANGLE, OCTAGON, ELLIPSE, PENTAGON, DIAMOND, FLOWER, LENS }
## 상태이상.
## 🔴 설계 원칙 = **단독은 약한 바탕, 조합에서 폭발한다** — 단독 효과를 다 없애면 한 발 쏠 때
## 아무 일도 안 나 밋밋하고, 단독이 다 세면 조합할 이유가 없다. 반응은 `StatusRules`가 건다.
## ⚠ **끝에만 붙여라** — 중간에 끼우면 저장된 `RuneDef.status`·옛 세이브가 통째로 밀린다.
##   SHOCK=감전(약한 경직) · VULNERABLE=취약(다음 상태가 더 세게 걸림, 흙) · ROOT=덩굴(약한 묶임, 풀)
##   MUD=진흙 · BLAZE=산불 · OVERGROWTH=무성함 — 셋 다 **반응 산물**이다.
enum Status { NONE, BURN, KNOCKBACK, WET, FLOW, SHOCK, VULNERABLE, ROOT, MUD, BLAZE, OVERGROWTH }
enum Phase { MORNING, DAY, EVENING, NIGHT }
## 아이템 종류(= 장비 부위). PEN=탁본 펜은 등급이 오를수록 손그림 **보정도**가 오르고,
## HAT=모자는 **이동 속도** 축이다 — 로브(생존)·부적(마나 지속)과 겹치지 않는 별도 부위다.
## ⚠ **끝에 붙여라** — 중간에 끼우면 저장된 equipment의 부위 키가 통째로 밀린다.
enum ItemKind { INK, PAPER, WAND, ROBE, CHARM, MATERIAL, FRAGMENT, PEN, HAT }
## ⚠ 소비자 0 — 지금 발사 거부는 `player_caster`가 `notice` 문자열로 알린다.
enum CastFailReason { NO_MANA, BROKEN, INVALID }
## 퀘스트 목표 종류 — `data/quests/*.tres`의 `goal`이 이 값이다.
## KILL=적 처치 · EXTRACT=살아서 귀환 · UNLOCK=도감 해금 · DRAW=마법진 그리기.
## ⚠ `.tres`가 정수로 저장하니 재정렬 금지 — 끝에만 덧붙인다.
enum QuestGoal { KILL, EXTRACT, UNLOCK, DRAW }
## 지점(랜드마크) 종류.
##   RUIN=폐허(전투 없음 · 열면 소리가 나 몹이 몰려온다) · NEST=둥지 · ALTAR=제단(바치면 보상)
## 🔴 셋의 차이는 「보상 크기」가 아니라 「무슨 일이 일어나나」다 — 크기만 다르면 나눈 의미가 없다.
## 🔴 진행에 걸린 보상(문양-고리)은 어느 종류도 주지 않는다 — 그건 보스·공방·퀘스트 같은
##  확정 경로 몫이다(「언제 얻을지 모르겠다」가 여기서 돌아온다).
## ⚠ 끝에만 덧붙여라 — `.tres`가 정수로 저장한다.
enum LandmarkKind { RUIN, NEST, ALTAR }
