extends CharacterBody2D
## 적 배우(공용) — 추격·접촉 피해가 바탕이고 `params.ai`로 갈린다(charge·hover·stationary·boss_snake·boss_gale).
## ⚠ 파일 이름의 「forest」는 세26의 흔적이고(그땐 *"한 종류만 — 쫓아와서 접촉 피해"*가 맞았다),
## **라이브 무대는 챕터 보스방**이다 — `boss_room`이 보스·잡몹을 둘 다 이 씬으로 스폰한다(숲 원정은 세58-B 은퇴).
##
## 🔴 **적 노드 계약**을 지킨다 (허수아비 `src/spell/dummy_target.gd`가 그 참고 구현이다):
##   그룹 `"enemies"` · 레이어 4(enemy) · `take_hit(damage, rune_type, status, status_power)` ·
##   그 안에서 `EventBus.enemy_hit`를 **약점 배율까지 반영한 최종 피해**로 발신.
## 발사(ring_spell_system)가 이미 이 계약으로 때린다 — 그래서 이 파일은 발사를 전혀 모른다.
##
## 🔴 **수치는 전부 `data/enemies/*.tres`(EnemyDef)가 쥔다 — 새 적 = .tres 한 장**이다
## (선례: 룬·펜·진). 코드엔 하나도 안 박혀 있고 `enemy_id`만 바꾸면 hp·속도·피해가 따라온다.
##
## 🔴 **레이어: layer 4(enemy) / mask 1(world)** (forest_enemy.tscn).
##  • mask에 2(player)를 넣지 마라 — 적이 플레이어를 **밀어내는** 게임이 되고, 접촉 피해는
##    어차피 아래 거리 판정이 판다 (물리 충돌이 필요 없다).
##  • layer 4가 곧 **맞는 몸**이다 — 캐리어·탄 마스크가 5(world+enemy)라 여길 본다.
##    기본 레이어 1로 되돌리면 world로 읽혀 마법이 **부딪히기만 하고 take_hit이 안 불린다**.

## 적이 죽었다(로컬). ⚠ **로컬 구독자는 아직 0**이다 — 킬카운트·퀘스트·챕터 클리어는 전부
## `EventBus.enemy_died`가 나른다(수신 = `juice`·`game_state`·`boss_room`). 처치 경로를 만질 땐 그쪽을 봐라.
signal died

## 🔴🔴 드롭 굴림·낱개 스폰의 **단일 소스** (세101 추출 · 설계 §10-4 S17) — 아래 `_roll_drops`·
## `_spawn_loose`는 이제 이걸 부르는 **얇은 껍데기**다. 곧 붙는 **지점(랜드마크)**이 같은 함수를
## 부르므로 `DropEntry`의 배타 짝 규칙이 두 벌로 갈리지 않는다.
## ⚠ **여기 로직을 되돌려 적지 마라** — 그 순간 두 벌이 되고 에러가 0이다.
## ⚠ 바닥 픽업 씬(`drop_pickup.tscn`)의 preload도 **같이 옮겨 갔다**(세46 계약 그대로).
const DropRoll := preload("res://src/field/drop_roll.gd")


## 🔴 적 투사체 (세56 gale 연사) — 픽업·상자와 같은 이유로 preload 안전(탄은 field/actors를 안 문다).
const GaleProj := preload("res://src/field/enemy_projectile.tscn")

## 🔴 상태이상·원소 반응의 **규칙 단일 소스** (세션49). 규칙을 여기 베끼지 마라 — 복사하면
## "진흙인데 안 묶인다" 식으로 조용히 갈라진다(ring_power와 같은 이유).
const SR := preload("res://src/core/status_rules.gd")
## 🔴 상태 **보유고** (세션50 추출) — 적·허수아비가 같은 물건을 쓴다.
const SH := preload("res://src/core/status_holder.gd")
## 지속·반경·틱 간격 수치는 전부 balance가 쥔다 (연출값이 아니라 밸런스다).
const BAL := preload("res://data/balance.tres")

## 🔴🔴 시야 판정의 **단일 소스** (세104 N27 · core 순수 규칙 파일 — `SR`·`ring_power` 형제).
##  같은 부채꼴을 두 축이 쓴다: 지금은 적이 *"내가 보이나"*를, 다음(N30 몬스터 인지)엔
##  적이 *"플레이어가 나에게 보이나"*를 같은 함수로 묻는다. 각자 짜면 한쪽만 고쳐도 아무도 모른다.
## ⚠ **수치는 반드시 인자로 넘겨라** — 그 파일 머리말이 「인자를 줄이지 마라」의 이유를 적어 뒀다
##  (static 함수 안의 `const BAL.프로퍼티`는 컴파일 타임에 굳어 뮤테이션이 무효가 된다).
const Vision := preload("res://src/core/vision.gd")

## 🔴 조립 점수 → **품질 t**의 단일 소스 (세105 인지 §5). 마법 소리 반경이 이걸 지난다.
## ⚠ **raw `score`를 쓰지 마라** — 그 함수 머리말이 *"하위 70%가 통째로 죽는다"*고 못 박았다
##  (실사용 범위가 `assemble_score_base`(0.70)~1.0이라 맨 진↔퍼펙트가 1.43배뿐이다).
##  리포트·시전 시간·이동 배수가 전부 이 함수를 지나므로, 소리만 안 지나면 **혼자 다른 축**이 된다.
const RingPower := preload("res://src/core/ring_power.gd")

## 🔴 히트 플래시 셰이더 (세63 설계 §A) — modulate 곱셈(어두운 픽셀이 안 하얘짐) 대신 mix-to-white.
## Shader **리소스** 공유는 안전 — 인스턴스마다 갈라야 하는 건 uniform을 쥔 ShaderMaterial 쪽이다
## (`_ready`가 per-instance 생성. 공유하면 한 마리의 플래시가 전원 플래시다).
const FLASH_SHADER := preload("res://src/actors/hit_flash.gdshader")
## 발밑 그림자 (세63 설계 §D) — 공용 배우 컴포넌트. 여기서 자동 부착하므로 **미래의 모든 적이
## 공짜**다("새 적 = .tres 한 장" 계약 — 씬마다 노드를 요구하면 새 적마다 침묵 누락이 생긴다).
const ShadowScript := preload("res://src/actors/shadow.gd")
## 🔴 죽음 연출(세100) — **몸이 마나로 터져 파편이 플레이어에게 돌아간다**(설계 §3-B).
## 그림자와 **완전히 같은 자리**의 공용 배우 컴포넌트라 preload 관용구도 같다: 죽는 몸은 전부
## 이 파일 하나를 지나므로 **잡몹·보스가 공짜로 따라온다**(`_spawn_death_burst`).
const ManaBurst := preload("res://src/actors/mana_burst.gd")

## ⚠ 세99: 기본값이 **지워진 `&"slime"`**을 가리키고 있었다(잡몹을 늑대 하나로 줄이며 삭제).
##  라이브 경로는 전부 `add_child` **전에** 대입해서 안 깨졌지만, 「기본값으로 스폰되는 길」이
##  하나라도 생기는 순간 `Db.get_enemy`가 null을 돌려주고 **hp 0짜리 유령이 선다**(에러 0).
@export var enemy_id: StringName = &"hound"

@onready var _visual: AnimatedSprite2D = $Visual
## 🔴 세99 — 맞는 몸(히트박스). 씬 기본 반경은 9.0이고 `params.hitbox_radius`가 덮는다(`_apply_hitbox`).
@onready var _shape: CollisionShape2D = $Collision

## 🔴🔴 발밑 그림자 **손잡이** (세104 · `vision_design.md` §5-2 ⑨). `_attach_shadow`가 담는다.
##  그전엔 지역 변수로 만들고 참조를 안 남겨서, 그림자를 끄고 싶어도 **잡을 방법이 없었다**
##  (`shadow.gd` 머리말이 *"어떤 그룹에도 가입하지 않는다"*고 못 박아 그룹으로도 못 찾는다).
## 🔴 **`get_node`나 자식 인덱스 0으로 찾지 마라** — `move_child(shadow, 0)`이 지금은 0번이지만
##  트리 순서는 연출이 만지는 자리다(그러면 어느 날 조용히 엉뚱한 노드를 흐린다).
var _shadow: Sprite2D = null

## 🔴 피격 손맛 (세션 38 · 세63 개편) — 넉백/플래시/스쿼시 **연출값**. 밸런스가 아니라 느낌값이라
## 여기 const (projectile 물리 여유 const 선례). 사용자가 직접 때려 보며 조인다.
## idle 애니 기본 박자 — `params.anim_fps`가 없을 때. 🔴 **옛 하드코딩 값 그대로**라
## 키를 안 준 .tres는 동작이 안 바뀐다(하위호환 계약 · `_idle_fps` 머리말).
const ANIM_FPS_DEFAULT := 6.0
const KNOCKBACK_IMPULSE := 140.0  ## 맞는 순간 플레이어 반대쪽으로 밀려나는 속도
const KNOCKBACK_DECAY := 600.0    ## 넉백 감쇠(속도/s) — 빨리 원래 추격으로 복귀
const POP_SQUASH := Vector2(1.25, 0.78)  ## 피격 스쿼시 — 가로로 눌리며 "맞았다"가 읽힌다
const POP_SEC := 0.18             ## 플래시 감쇠·스쿼시 복귀 시간(s)
const TELEGRAPH_AMOUNT := 0.6     ## 윈드업 붉은 달아오름 세기 (셰이더 telegraph_amount)
const HURT_HOLD_SEC := 0.15       ## 1프레임 hurt 스트립의 홀드 시간 (설계 §C 함정 — 아래 _play_hurt)
const SHADOW_RADIUS_FRAC := 0.30  ## 그림자 반경 = 프레임 한 변 × 이 값
const SHADOW_OFFSET_FRAC := 0.35  ## 발밑 오프셋 = 프레임 한 변 × 이 값 (프레임 바닥 근사)
## 시트를 못 읽었을 때의 프레임 한 변(px) — `_frame_side`. 🔴 **옛 하드코딩 값 그대로**라
## 시트 없는 몸(테스트 스텁)의 그림자 크기가 안 바뀐다(하위호환 계약 · `ANIM_FPS_DEFAULT` 선례).
const FRAME_SIDE_FALLBACK := 32.0

var _def: EnemyDef = null
var _hp: float = 0.0
var _cool: float = 0.0
## 피격 넉백 속도 — 추격 속도 위에 얹혀 빠르게 사그라든다.
var _knockback: Vector2 = Vector2.ZERO

## 🔴 행동 갈래 = `params.ai` (기본 "chase" = 현행). "새 적 = .tres 한 장"이 **행동까지**
## 포함하게 params에 얹었다(스키마 확장 대신 — color·size·sprite 선례 그대로). 수치는 전부
## `_param`으로 .tres에서 읽는다 — balance.tres가 아니다(적 수치는 EnemyDef가 쥔다는 계약).
var _ai: String = "chase"

## 돌진(charge) 상태기계 — hound. 텔레그래프(윈드업)가 있어 **피할 수 있는** 공격이 된다.
enum ChargeState { APPROACH, WINDUP, CHARGE, RECOVER }
var _charge_state: int = ChargeState.APPROACH
var _charge_timer: float = 0.0
var _charge_dir: Vector2 = Vector2.ZERO
## 이번 윈드업의 **전체 길이**(초) — 바닥 예고가 「얼마나 찼나」를 내려면 남은 시간만으론 모자란다.
## 🔴 `_param("windup_sec")`을 그리는 쪽에서 다시 읽지 않는다: 윈드업 도중에 데이터가 바뀌면
##  진행도가 튀고, 무엇보다 **읽는 자리가 둘이 되는 순간 갈라질 자리**가 하나 더 생긴다.
var _charge_windup: float = 0.0
## 🔴 돌진 예고 범위 — 윈드업 동안만 바닥에 뜬다. **지연 생성**이라 charge가 아닌 적은 노드가 없다
##  (`_gale_ring` 선례). 적의 자식이라 **적이 죽으면 같이 죽는다** = 취소·소유·수명을 새로 안 만든다.
var _charge_band: Node2D = null
var _band_base: Polygon2D = null   ## 닿을 범위 전체 (옅은 채움)
var _band_fill: Polygon2D = null   ## 예고가 찬 만큼 (짙은 채움 — 앞으로 뻗는다)
var _band_edge: Line2D = null      ## 범위 테두리 (어두운 와인빛 — 밝은 풀밭에서 이게 제일 잘 읽힌다)
var _band_front: Line2D = null     ## 차오름 앞머리 (밝은 주홍 — 「여기까지 왔다」)

## 🔴 돌진 예고 범위 **연출값** (밸런스 아님 — `GUST_RING_*`·`vfx.gd` 링 상수 선례).
##  ⚠ **크기는 여기 없다** — 길이·폭은 `.tres`의 돌진 수치에서 파생한다(`_charge_reach_*`).
##  여기 있는 건 색·굵기·분할처럼 **사용자가 눈으로 조이는 것**뿐이다.
##
## 🔴 색 = TAKBON 60의 붉은 램프 3단을 그대로 쓴다(`assets/aseprite/takbon.gpl`):
##  `752438`(테두리) → `A53030`(채움) → `CF573C`(앞머리). 사용자 지시가 **「빨간색」**이고,
##  룬·상태 색이 아니라 **적의 공격 예고**라 파생원이 없다(`GUST_RING_COLOR`가 같은 자리다).
##
## 🔴🔴 **알파가 색을 정한다 — 실측으로 고쳤다**(세99 `vfx_shot -- charge` + 픽셀 샘플링).
##  밝은 낮 풀밭(`#4A9E38`) 위에 **붉은색을 옅게 깔면 초록과 상쇄돼 갈색·올리브가 된다**:
##   α0.22 → `#5E8636`(풀과 구분이 거의 안 간다) · α0.55 → `#845632`(**갈색**이지 빨강이 아니다).
##  같은 A53030이라도 α0.92면 `#9E3931`로 **빨갛게 읽힌다** — 사용자 지시가 「빨간색」이라
##  차오르는 쪽은 **거의 불투명해야 한다.** 취향이 아니라 배경과의 산수다.
##  ⚠ 어두운 배경에서 고르면 뭘 깔아도 잘 보여 **도구가 거짓말한다**(프리셋에 `bg`를 둔 이유).
##  ⚠ 반대로 **아직 안 찬 쪽을 짙게 깔지 마라** — 「닿을 범위」와 「찬 만큼」이 같아 보이면
##   남은 시간이 사라진다. 그쪽 읽힘은 채움이 아니라 **불투명한 어두운 테두리**가 진다.
const CHARGE_BAND_EDGE := Color(0.459, 0.141, 0.220, 1.00)    ## 752438 — 짙은 와인 테두리(범위의 실선)
const CHARGE_BAND_BASE := Color(0.647, 0.188, 0.188, 0.45)    ## A53030 — 닿을 범위 전체(아직 안 찬 쪽)
const CHARGE_BAND_FILL := Color(0.647, 0.188, 0.188, 0.92)    ## A53030 — 찬 만큼(거의 불투명 = 빨갛다)
const CHARGE_BAND_FRONT := Color(0.812, 0.341, 0.235, 1.00)   ## CF573C — 앞머리
const CHARGE_BAND_EDGE_W := 3.0     ## 범위 테두리 굵기(px)
const CHARGE_BAND_FRONT_W := 2.5    ## 앞머리 굵기(px)
const CHARGE_BAND_CAP_SEGS := 10    ## 캡슐 반원 캡 분할 수 (`GUST_RING_SEGMENTS`와 같은 결)
const CHARGE_BAND_MIN_FILL := 0.06  ## 채움의 최소 길이 비율 — 0이면 첫 프레임이 「원 하나」라 방향이 안 읽힌다

## 부유(hover) 분산 상태 — mist. 분산 중엔 받는 피해가 준다(take_hit) + 반투명(때리기 나쁨이 보인다).
var _disperse_timer: float = 0.0
var _dispersed: bool = false
## 분산 중 알파 **연출값**(밸런스 아님 — `POP_SEC`·`GUST_RING_*` 선례). 그물 = `test_enemy_ai_auto [3b]`.
const DISPERSED_ALPHA := 0.4

## 🔴 시야 알파 축 (세104 N27) — 1.0 = 보인다 · 0.0 = 기척만 남는다. `_alpha_now()`가 분산과 **곱한다**.
##  ⚠ **여기에 대입하는 곳은 `_update_vision` 하나다** — 다른 데서 만지면 페이드가 튄다.
var _vision_alpha: float = 1.0
## 🔴 이번 프레임의 **판정 결과**(캐시). 공개 리더 = `is_seen()`.
##  ⚠ **알파와 각자 계산하지 마라** — `_vision_alpha`는 이 값의 **페이드**여야 한다.
##   둘이 따로 판정하면 그물이 보는 것과 화면이 보이는 것이 갈려 세85 *"검증 도구가 거짓말한다"*가 된다.
var _seen: bool = true
## 🔴 **무대에 오른 적은 숨지 않는다** (`params.always_visible` · 설계 §4-3) — 지금 켠 건 **보스 셋**이다.
##  ⚠ **네임드에는 켜지 마라 — 반대다.** 네임드는 「잡몹 중 무서운 것」이라 **숨는 게 정체성**이고,
##   주변시(220)보다 큰 aggro(280)로 **등 뒤 60px를 일부러 받는다**(§4-1-b 사용자 확정).
##   켜는 순간 네임드가 바탕 종보다 **순해진다**(설계 V6).
var _always_visible: bool = false

## 🔴 시야 페이드·숨김 알파 = **연출값**이라 balance가 아니라 여기 const다(설계 §4가 그렇게 갈랐다 —
##  balance엔 **난이도를 직접 바꾸는 셋**(각도·사거리·주변시)만 있다).
const VISION_FADE_SEC := 0.18     ## 딱 끊으면 경계에서 깜빡인다. 나무 비침(0.45s)보다 빠르게 — 적은 움직인다
const VISION_HIDDEN_ALPHA := 0.0  ## 🔴 반투명이면 「가려졌다」가 아니라 **「흐린 적」**이 된다(사용자 확정 ⓓ *"안 보이게"*)


# ══ 시야 차폐 — 🔴 **세107에 은퇴했다**(사용자 확정 *"구지 나무나 돌맹이에 시야가 가려지지 않도록"*) ══
#
# 세105엔 여기 `OCCLUDER_GROUP`·`OCCLUDE_R_META`·`_occluders`·`_bake_occluders()`가 있었고
# `Vision.is_seen`의 **일곱 번째 인자**로 나무·큰 바위를 넘겨 시선을 끊었다. 판정·화면(셰이더 그늘)·
# 그물을 **셋 같이** 걷었다 — 🔴 **되살리려면 셋을 같이 열어라**(하나만 열면 「밝은데 적이 안 보인다」가
# 돌아온다). 경위·수학 = `src/core/vision.gd` 머리말 + `git show`(세105~107).


# ══ 인지 (세105 N30 · 정본 `docs/takbon-design/enemy_perception_design.md`) ══════
#
# 🔴🔴 **이 축은 「내 시야」(N27)의 거울이다** — 저쪽이 *"내가 적을 못 본다"*면 이건 *"적이 나를
#  못 본다"*이고, **부채꼴 수학은 `Vision.is_seen` 하나를 같이 쓴다**(설계 §3 · 각자 짜면 T5).
#
# 🔴 **판정은 서로 무관하다**(설계 §8-7). 한쪽을 다른 쪽에서 파생시키지 마라 — 다만 **화면 결과는
#  겹친다**(시야 밖 적의 경계는 몸이 안 보여 통째로 투명하다 ⇒ 소리·느낌표가 그래서 필수다).

## 🔴 인지 상태 — 설계 §2의 흐름도 그대로다.
##  PATROL → (감지) ALERT → (버티면) CHASE → (lose_sec 놓침) SEARCH → (search_sec) PATROL.
## ⚠ 설계 헤더의 *"상태 다섯"*은 오기다 — 흐름도·표·검증 계획이 전부 **넷**을 말한다(리포트에 적었다).
enum Percept { PATROL, ALERT, CHASE, SEARCH }

var _percept: int = Percept.PATROL
var _percept_timer: float = 0.0   ## ALERT 잔여 · SEARCH 잔여 (상태가 배타적이라 한 칸을 나눠 쓴다)
var _lose_timer: float = 0.0      ## CHASE 중 **연속** 감지 실패 시간 — `lose_sec`을 넘기면 놓친다
## 마지막으로 「저기 있었다」고 아는 자리. 눈으로 봤으면 그 좌표, 소리면 **발사 지점**이다.
## 🔴 플레이어의 **지금 위치가 아니다** — 쏘고 옮기면 흘리는 것이 설계 §5의 요점이다.
var _last_seen: Vector2 = Vector2.ZERO
## 이번 ALERT가 **소리**로 시작했나. 눈으로 시작한 경계는 「벗어나면 없던 일」이지만(설계 §2 ⓒ),
## 소리는 애초에 안 보이는 채로 들어오므로 그 규칙을 그대로 쓰면 **한 프레임에 취소된다.**
var _alert_from_sound: bool = false

## 🔴🔴 **「보는 쪽」 — 이 설계를 지탱하는 한 값**(설계 §4). 좌우 반전(`_update_facing`)도, 부채꼴
##  판정(`_detects`)도 **이 하나**를 본다. 각자 방향을 만들면 「보는 것 ≠ 판정하는 것」이 된다.
## ⚠ 기본이 `RIGHT`인 근거 = `SPRITE_FACES_LEFT == false`(시트가 오른쪽을 본다) — 첫 프레임의
##  그림과 판정이 같은 쪽을 가리킨다. 여기 `ZERO`를 넣으면 `Vision.is_seen`이 **fail-open**으로
##  빠져 부채꼴이 통째로 무의미해진다(그 파일 머리말).
var _look_dir: Vector2 = Vector2.RIGHT

## 🔴🔴 배회의 중심 = **스폰 자리**. `_ready`가 아니라 **첫 `_physics_process` 틱**에 잡는다(설계 §9-b).
##  라이브(`boss_room._spawn_enemy_at`)는 `add_child` **앞**에 좌표를 주지만 **그물 넷은 정반대로
##  뒤에 준다**(`test_enemy_ai_auto`·`test_status_auto`·`test_feel_auto`·`test_mana_burst_auto`) —
##  `_ready`에서 잡으면 `_home`이 (0,0)이 되어 **적이 원점으로 끌려간다**(에러 0).
var _home: Vector2 = Vector2.ZERO
var _home_set: bool = false
## 배회 위상 — **자리마다 다르다**(설계 §8-5). 같은 위상이면 둥지 둘레 늑대 다섯이 **한 몸처럼 겹친다.**
## 🔴 스폰 **순서**가 아니라 **좌표**에서 뽑는다: 순서는 방 씬을 재편하면 바뀌지만 자리는 안 바뀐다.
var _patrol_phase: float = 0.0
var _patrol_t: float = 0.0

## 경계·발견 소리 재생기 — 지연 생성(`_gale_ring` 선례: 소리 키가 없는 몸은 노드가 아예 없다).
## 🔴🔴 **`AudioStreamPlayer2D`인 이유 = 거리 감쇠**(설계 §8-6 · 리드 판단 M8). `Audio` 오토로드의
##  풀은 **비위치** `AudioStreamPlayer` 8개라 방 반대편 늑대가 코앞처럼 들린다 — 여러 마리가
##  동시에 짖으면 **통보가 아니라 잡음**이 된다. 스트림은 `Audio.stream_of()`에서 빌려
##  「새 소리 = wav 한 장」과 「Audio가 유일한 로드 경로」를 **둘 다 안 깬다.**
var _percept_sfx: AudioStreamPlayer2D = null

## 🔴🔴 **인지 키의 이름 승계 — `aggro_range` → `sight_range`** (설계 §8-1 · 리드 확정 「전 종 승계」).
##
## 🔴 **은퇴가 아니라 승계다.** 그 키는 `vision_design`(N27)의 **심장**이다 — 주변시 220이
##  *"바탕 종 aggro의 최댓값"*에서 **파생**하고, `hound_alpha`의 **등 뒤 60px**(280−220)가
##  세101에 사용자가 직접 확정한 그 종의 **유일한 정체성**이다. 지우면 `params.get(...)`이 0을
##  돌려줘 **바탕 조건은 자명 통과 · 스토커 조건은 빨강**이 되고, 그 사이 정체성이 증발한다.
##
## 🔴🔴 **보스 셋(`snake_boss`·`gale`·`slime_elite`)에게 이 값은 「시야」가 아니라 `leash` 거리다.**
##  보스는 인지 설계 **밖**이고(§8-2) 인지 키를 **안 준다** — 그러면 §7-b 폴백이 옛 동작을 그대로
##  준다(부채꼴 360° = 늘 본다 · 한 박자 0 = 즉시 · 배회 0). ⚠ **보스에게 부채꼴을 붙이지 마라**:
##  무대에 오른 적이 「등 뒤로 돌면 안 쫓는다」가 되면 보스전이 통째로 갈린다.
##
## 🔴 **없으면 `aggro_range`로 폴백한다** — 하위호환이 이름 승계의 안전망이다(§7-b).
##  그물 6파일이 **인지 키 0개인 몸**을 주입하는데, 그 몸들이 여전히 옛 키를 쓴다.
const SIGHT_KEY := "sight_range"
const SIGHT_KEY_LEGACY := "aggro_range"

## 🔴 §7-b 하위호환 표 — **「키가 없으면 정확히 옛 동작」**. 이 표 하나가 그물 표의 절반을 없앤다.
##  이 파일은 같은 계약을 이미 세 번 명문화했다(`_setup_frames`·`_idle_fps`·`_apply_hitbox`).
const SIGHT_ANGLE_DEFAULT := 360.0   ## 부채꼴이 무의미 = 늘 본다(옛 동작)
const SENSE_RADIUS_DEFAULT := 0.0    ## 360° 부채꼴이 이미 덮는다
const TURN_RATE_DEFAULT := 0.0       ## 🔴 0 = **무제한**(즉시 회전) = 방향 개념 없음(옛 동작)
const ALERT_SEC_DEFAULT := 0.0       ## 한 박자 없음 = 즉시 CHASE(옛 동작)
const LOSE_SEC_DEFAULT := 0.0        ## 놓치면 즉시
const SEARCH_SEC_DEFAULT := 0.0      ## 수색 없음
const AMBUSH_MULT_DEFAULT := 1.0     ## 곱셈 항등
const PATROL_RADIUS_DEFAULT := 0.0   ## 🔴 배회 안 함 — `disperse_period`·`regen_per_sec` 관용구 그대로
const PATROL_SPEED_DEFAULT := 0.0

## ⚠⚠ **지금 `.tres`에 들어간 인지 수치는 전부 「잠정」이다 — F5가 정한다**(설계 §11).
##  손맛은 헤드리스도 스샷도 못 재고 **사용자가 직접 걸어봐야** 정해진다. 여기 표를 남기는 이유는
##  `.tres`의 `;` 주석이 **에디터가 저장하면 통째로 증발하기** 때문이다(takbon-rules §5).
##
##  | 키 | hound | hound_alpha | 왜 이 언저리에서 출발하나 |
##  |---|---|---|---|
##  | `sight_range` | 220 | 280 | 🔴 **승계값이라 잠정이 아니다** — 220은 주변시의 파생원, 280−220=60px가 네임드의 정체성 |
##  | `sight_angle` | 150° | 200° | 네임드가 더 넓다(설계 §11 후보). 좁힐수록 「돌아가기」가 쉬워진다 |
##  | `sense_radius` | 90 | 110 | 등 뒤도 코앞이면 들킨다 — 없으면 「등 뒤에 붙어 따라다니기」가 최적 전략이 된다 |
##  | `turn_rate` | 160°/s | 200°/s | 🔴 **가장 먼저 조일 값**(설계 §11) — 이게 빠르면 안 ⓐ가 통째로 무너진다 |
##  | `patrol_radius` | 84 | 70 | 🔴 **≤ 100 이 계약이다**(`_patrol_velocity` ⓐ — 프롭이 스폰 둘레 100px을 비운다) |
##  | `patrol_speed` | 34 | 28 | move_speed(95·110)의 3분의 1 — 「어슬렁거린다」로 읽혀야 한다 |
##  | `alert_sec` | 0.45 | 0.28 | 🔴 **둘째로 조일 값** — 피할 틈이 있나. 네임드가 더 짧다(설계 §11 후보) |
##  | `lose_sec` | 1.2 | 1.8 | 놓쳤다고 인정하기까지. 짧으면 도망이 너무 쉽다 |
##  | `search_sec` | 2.5 | 3.2 | 「따돌렸다」를 만드는 값 |
##  | `ambush_mult` | 1.8 | 1.8 | 뒤로 도는 것이 **전술**이 될 만큼은 세게 |
##  ⚠ 소리 반경(`percept_sound_radius_*` 240/700)도 잠정이다 — **셋째로 조일 값**(쏘면 늘 들키나).

## 배회 도착 판정(px) — 궤도 목표에 이만큼 붙으면 이번 틱은 멈춘다(제자리 떨림 방지). 연출값.
const PATROL_ARRIVE_PX := 1.0
## 수색 도착 판정(px) — 마지막 본 자리에 이만큼 오면 「와 봤다」. 연출값.
const SEARCH_ARRIVE_PX := 8.0

## 🔴 뱀 보스(boss_snake) 전용 상태 (세션 A). charge 변수를 재사용하지 않는다 — 두 AI가 섞이면
## 조용히 깨진다(설계 A-5). 위브 추격 → 텔레그래프 러시 → 회복 → 다시 위브.
enum SnakeState { WEAVE, RUSH_WINDUP, RUSH, RECOVER }
var _snake_state: int = SnakeState.WEAVE
var _snake_timer: float = 0.0     ## 현재 상태 잔여 시간
var _snake_rush_cd: float = 0.0   ## 러시 재사용 대기(위브 중에만 감소)
var _weave_t: float = 0.0         ## 위브 사인파의 시간 누적(boss 틱 delta)
var _snake_dir: Vector2 = Vector2.RIGHT  ## 러시 락 방향 + 머리 바라보는 방향
## hp 절반 페이즈 전이 — 1회 플래그. 🔴 **보스 공용**이다(세56) — 뱀은 위브 진폭·러시 빈도,
## gale은 돌풍·연사 빈도·이동속도 배율이 오른다. 전이 판정 패턴도 두 분기가 같다.
var _phase2: bool = false

## 🔴 gale 보스(boss_gale) 전용 상태 (세56). charge/snake 변수를 재사용하지 않는다 — 두 AI가
## 섞이면 조용히 깨진다(뱀과 같은 원칙). 거리 유지(DRIFT) → 붙으면 돌풍 윈드업 → 밀쳐내기.
enum GaleState { DRIFT, GUST_WINDUP }
var _gale_state: int = GaleState.DRIFT
var _gale_timer: float = 0.0        ## 윈드업 잔여 시간
var _gale_gust_cd: float = 0.0      ## 다음 돌풍까지 (DRIFT에서만 감소)
var _gale_volley_cd: float = 0.0    ## 다음 연사까지 (DRIFT에서만 감소)
var _gale_volley_left: int = 0      ## 이번 연사의 남은 발수 (DRIFT 위 오버레이 카운터 — 이동은 계속)
var _gale_shot_timer: float = 0.0   ## 다음 발까지
var _gale_ring: Line2D = null       ## 돌풍 반경 텔레그래프 링 (지연 생성 — gale이 아니면 안 만든다)

## 돌풍 텔레그래프 링 **연출값** (밸런스 아님 — vfx.gd 링 상수 선례). 반경은 gust_radius(.tres)가 쥔다.
const GUST_RING_SEGMENTS := 24      ## 링 원 분할 수 (vfx._spawn_ring과 같은 결)
const GUST_RING_WIDTH := 2.5        ## 링 선 굵기(px)
const GUST_RING_COLOR := Color(0.75, 0.95, 1.0, 0.85)  ## 옅은 바람색

## 🔴 상태이상 보유고 (세션49 → 세션50에 `src/core/status_holder.gd`로 **추출**).
## 보유·틱·반응 해결은 전부 holder가 한다 — 여기 남은 건 **몸의 일**(피해·확산·색)뿐이다.
## 추출한 이유: 허수아비가 같은 코드를 못 써서 **연습장에서 반응을 시험할 수 없었다**.
var _status: SH = SH.new()
## 🔴 세99 D6 — 몸 색조(`EnemyDef.params.tint`). 흰색 = 곱셈 항등 = 「색조 없음」(기존 적 전부).
## 대입처는 `_apply_look`(읽기)·`_refresh_tint`(곱하기) 둘뿐이다 — modulate 소유권 계약 참조.
var _base_tint: Color = Color.WHITE
## 🔴 죽음 1회 보장 — DoT·연쇄·즉발이 같은 프레임에 겹쳐도 `_die()`가 두 번 돌면
## 드롭이 두 번 떨어지고 퀘스트가 두 번 센다(queue_free는 프레임 끝에야 반영된다).
var _dead: bool = false
## hurt 홀드 세대 토큰 (세63) — 연타 시 마지막 발동의 타이머만 idle 복귀시킨다 (_play_hurt).
var _hurt_gen: int = 0


func _ready() -> void:
	add_to_group("enemies")
	_wire_status()
	_def = Db.get_enemy(enemy_id)
	if _def == null:
		# 조용히 죽지 않게 — .tres 이름을 틀리면 hp 0짜리 유령이 서 있게 된다.
		push_warning("EnemyDef '%s'를 못 찾았다 (data/enemies/ 확인) — 기본값으로 선다" % enemy_id)
	_hp = _def.hp if _def != null else 10.0
	_ai = str(_def.params.get("ai", "chase")) if _def != null else "chase"
	# 🔴 기본 false — 키가 없는 적은 **숨는다**(잡몹·네임드). 켜는 건 `.tres` 한 줄이고
	#  지금 켜져 있는 곳은 `data/chapters/*.tres`의 `boss_enemy_id` 셋뿐이다(그물이 데이터로 대조한다).
	_always_visible = bool(_def.params.get("always_visible", false)) if _def != null else false
	# 분산 주기를 처음 채워 둔다 — 곧장 분산으로 튀지 않게(첫 토글은 한 주기 뒤).
	_disperse_timer = _param("disperse_period", 2.5)
	# gale 쿨도 한 주기 채워 시작한다 — 조우 즉시 돌풍/연사가 터지지 않게 (disperse_timer 선례).
	_gale_gust_cd = _param("gust_period", 3.0)
	_gale_volley_cd = _param("volley_period", 4.5)
	# 🔴 히트 플래시 material은 **per-instance 생성** (세63 설계 §A) — 같은 ShaderMaterial 리소스를
	# 전원이 공유하면 한 마리의 플래시가 전원 플래시다. .tscn에 박지 않는 이유도 이것
	# (박으면 resource_local_to_scene이 필요한데 코드 생성이 더 단순하고 검증 가능하다).
	if _visual != null:
		var mat := ShaderMaterial.new()
		mat.shader = FLASH_SHADER
		mat.set_shader_parameter(&"flash_amount", 0.0)
		mat.set_shader_parameter(&"telegraph_amount", 0.0)
		_visual.material = mat
	# 🔴🔴 마법 소리 (설계 §5) — **EventBus 신설 0**이다. `ring_cast_requested`가 조립본(`score` 포함)과
	#  **발사 위치**를 이미 함께 나른다. ⚠ 착탄(`spell_impact`)이 아니라 **발사**다 — 소리는 총구에서 난다.
	# ⚠ `_exit_tree`로 끊지 마라(세50 금기) — 노드가 free되면 연결은 엔진이 알아서 지운다.
	EventBus.ring_cast_requested.connect(_on_cast_heard)
	_apply_look()
	_apply_hitbox()
	_attach_shadow()


## 🔴 외형도 .tres가 쥔다 (`params.sprite`·`params.size`·`params.tint`) — "새 적 = .tres 한 장"이
## 생김새까지 포함하게 하려는 것. 없으면 시트 그대로·1배·색조 없음.
## ⚠ **`params.color`는 여기 없다** — 세45에 스프라이트로 갈아타며 `_visual.color`가 사라졌다.
## 🔴🔴 **세100: 그 키의 마지막 소비자가 사라졌다 — 지금은 아무 일도 안 한다**(감사 T3 「거짓 손잡이」).
##  죽음 연출이 **마나 푸른색 통일**로 바뀌면서(설계 §3-B: *"룬 속성별로 가르지 않는다"*) 옛
##  `_spawn_death_puff`가 이 키를 읽던 유일한 자리였다.
##  ✅ **리드가 세 `.tres`(`hound`·`hound_alpha`·`slime_elite`)에서 줄을 걷었다** — 남는 `params` 키는
##   스키마를 안 깨므로 삭제가 안전하다(takbon-rules §5 ⓐ). 🔴 **되살리지 마라**: 죽음 색이 다시
##   적마다 갈리면 *"무슨 마나인가"*라는 **없는 축**이 생긴다(설계 §3-B가 각하한 그것).
##  몸을 물들이는 건 `params.tint`다(다른 키 — 섞지 마라).
## ⚠ 이건 **표시일 뿐 AI가 아니다** — 세션 30 "데이터만(리스킨)" 방침 그대로다. 행동(추격+접촉)은
## 한 가지뿐이고, 색·덩치만 .tres로 달라진다. 스키마를 안 늘리고 `params`에 얹은 이유 = enemy_def.gd
## 주석("스키마 확장 대신 params를 쓴다"). size는 루트 scale이라 **덩치가 곧 히트박스**가 된다
## — 단 **바탕 반경은 `params.hitbox_radius`가 쥔다**(세99, `_apply_hitbox`). size만으로는 그림과
## 판정이 갈린다: 시트를 다시 그리면(32→64px) 덩치는 그대로인데 몸만 커져 **쏴도 통과한다**.
func _apply_look() -> void:
	if _def == null or _visual == null:
		return
	# 🔴 스프라이트 = `params.sprite` 경로 (세션45 — 옛 색 폴리곤에서 실제 도트 시트로). 프레임은
	# 정사각(높이=한 변)으로 가로 스트립이라, 런타임에 SpriteFrames를 구워 붙인다(플레이어 시트와 같은 결).
	# "새 적 = .tres 한 장"이 스프라이트까지 포함하게 params에 얹었다(스키마를 안 늘린다 — params.color·size 선례).
	var sprite_path := str(_def.params.get("sprite", ""))
	if sprite_path != "":
		var tex := load(sprite_path) as Texture2D
		if tex != null:
			_setup_frames(tex)
	var s := float(_def.params.get("size", 1.0))
	if not is_equal_approx(s, 1.0):
		scale = Vector2(s, s)
	# 🔴 세99 D6 — **몸 색조**(`params.tint`). 네임드를 「덩치 + 색」으로 알아보게 하는 축이다
	#  (사용자 확정: *"몸에서 빛이나는거 까진 별로임"* — 오라가 아니라 생김새로 구별한다).
	# 🔴🔴 **옛 `params.color`와 다른 키다 — 되살려 섞지 마라.** `color`는 세45에 `_visual.color`가
	#  사라지고 세100에 죽음 연출이 마나 푸른색으로 통일되며 소비자가 0이 돼 **`.tres`에서 걷혔다**
	#  (위 `_apply_look` 머리말). 그 자리에 몸 틴트를 얹지 않고 **새 키로 간 이유**는, 얹었다면
	#  `color`를 쥐고 있던 적 셋의 겉모습이 **한꺼번에 달라졌을** 것이기 때문이다(지금은 그 셋이
	#  걷혔지만 판단의 근거는 남는다 — 죽음 색과 몸 색은 **다른 축**이다).
	#  없으면 흰색(=곱셈 항등) = 기존 적 회귀 0.
	# ⚠ 실제 적용은 `_refresh_tint`가 한다 — modulate 소유권 계약(거기 머리말)을 안 깨려고
	#  여기선 **값만 들고** 상태 틴트와 곱해 쓴다.
	if _def.params.get("tint") is Color:
		_base_tint = _def.params.get("tint")
		_refresh_tint()


## 🔴🔴 세99 — **맞는 몸도 .tres가 쥔다** (`params.hitbox_radius`). 잡몹 5종이 32px → 64px 프레임으로
## 다시 그려지자 씬 고정 반경 9.0이 **몸의 6분의 1**이 됐다(비율 0.56 → 0.16) — 보이는 몸통에 쏴도
## 탄이 그냥 지나갔다. 스키마를 안 늘리고 `params`에 얹은 이유는 `sprite`·`size`·`anim_fps`와 같다.
##
## 🔴 **값은 「루트 scale 이전」의 로컬 반경이다** — `Collision`이 루트의 자식이라 `params.size`가
##  자동으로 곱해진다(최종 화면 반경 = `hitbox_radius × size`). 그래서 **네임드는 바탕 종과 같은
##  숫자를 그대로 물려받으면 되고**(hound_alpha 20 × 1.35 = 27), 덩치를 조일 때 히트박스가 저절로
##  따라온다. 화면 px로 해석하면 `size`를 만질 때마다 두 숫자를 같이 고쳐야 하고, 한쪽을 잊으면
##  **에러 없이** 몸과 판정이 갈린다. 「덩치가 곧 히트박스」(`_apply_look` 머리말)를 깨지 않는 쪽이 이것이다.
##
## 🔴🔴 **`shape`를 duplicate 없이 쓰지 마라.** `.tscn`의 SubResource는 **씬 인스턴스끼리 공유**돼서
##  radius에 직접 대입하면 **마지막에 스폰된 적의 반경이 전원에게 번진다**(에러 0 — 슬라임 옆의
##  안개가 슬라임 히트박스를 쓴다). `ring_carrier._apply_body_radius`가 *"형상 리소스는 씬들이
##  공유하는 물건이라 건드리면 안 된다"*고 적은 그 함정이다. 그물 = `test_enemy_hitbox_auto [3]`.
##
## ⚠ 키가 없으면 **씬 기본값 9.0 그대로** = 기존 무변경(하위호환). 아직 옛 32px 시트인 `slime_elite`와
##  키를 안 준 보스(`gale`·`snake_boss`)가 그 경로로 산다.
func _apply_hitbox() -> void:
	if _def == null or _shape == null or not (_shape.shape is CircleShape2D):
		return
	var r := float(_def.params.get("hitbox_radius", 0.0))
	if r <= 0.0:
		return
	var circle := (_shape.shape as CircleShape2D).duplicate() as CircleShape2D
	circle.radius = r
	_shape.shape = circle


## 가로 스트립 시트(프레임 = 정사각, 한 변 = 시트 높이)를 루프 "idle" 애니로 굽는다.
## 프레임 수 = 폭 ÷ 높이. slime 128×32=4 · hound 256×32=8 · gale 384×64=6 — 높이 기준이라 다 맞는다.
## 🔴 세63 확장: `params.hurt_sprite` 경로가 있으면 **같은 규약**으로 비루프 "hurt"를 얹는다.
## 없으면 기존과 완전 동일 — **기존 경로 무변경이 하위호환 계약**이다(전 적 공용 함수).
func _setup_frames(tex: Texture2D) -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	# 🔴 세97: idle 박자를 **데이터가 판다**(`params.anim_fps`) — 그전엔 9종 전부 6.0 하드코딩이라
	#   안개 정령과 사냥개가 **같은 속도로 움직였다**(성격이 없었다). 기준선 = ART_SPEC §8-2.
	#   ⚠ hurt는 데이터를 안 본다 — 피격은 **짧은 반응**이라 성격 축이 아니고, 종마다 다르면
	#     "맞았다"가 일관되게 안 읽힌다(느린 적은 피격 반응도 느려져 손맛이 갈린다).
	if not _bake_strip(frames, &"idle", tex, true, _idle_fps()):
		return
	var hurt_path := str(_def.params.get("hurt_sprite", "")) if _def != null else ""
	if hurt_path != "":
		if ResourceLoader.exists(hurt_path):
			var htex := load(hurt_path) as Texture2D
			if htex != null:
				_bake_strip(frames, &"hurt", htex, false)
		else:
			# 시트가 없으면 hurt 없이 선다 — 침묵 대신 경고 (enemy_projectile 시트 부재 선례).
			push_warning("hurt_sprite를 못 찾았다 (%s) — hurt 애니 없이 선다" % hurt_path)
	_visual.sprite_frames = frames
	_visual.play(&"idle")


## 🔴 idle 박자(fps) — **「새 적 = .tres 한 장」이 애니까지 덮는다**(세97).
## 기준선 = `ART_SPEC` §8-2: 떠도는 것 2~4 · 묵직 4~6 · 보통 6~8 · 빠른 짐승 10~14 · 식물 3~5.
## ⚠ **값은 F5로 조인다** — 박자는 헤드리스도 스샷도 못 잰다(그 문서가 그렇게 못박았다).
## 기본값은 옛 하드코딩과 같은 6.0이라, 키가 없는 .tres는 **정확히 옛 동작**이다(하위호환).
func _idle_fps() -> float:
	if _def == null:
		return ANIM_FPS_DEFAULT
	return maxf(0.1, float(_def.params.get("anim_fps", ANIM_FPS_DEFAULT)))


## 가로 스트립 한 장 → 애니 하나 (idle·hurt 공용 굽기). 성공하면 true.
func _bake_strip(frames: SpriteFrames, anim: StringName, tex: Texture2D, loop: bool,
		fps: float = ANIM_FPS_DEFAULT) -> bool:
	var side := tex.get_height()
	if side <= 0:
		return false
	var count := maxi(1, tex.get_width() / side)
	frames.add_animation(anim)
	frames.set_animation_loop(anim, loop)
	frames.set_animation_speed(anim, fps)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * side, 0, side, side)
		frames.add_frame(anim, at)
	return true


## 🔴 idle 첫 프레임의 **한 변**(px) — 이 몸의 크기를 재는 단일 소스.
## 시트가 「정사각 프레임을 가로로 이어붙인 스트립」이라(`_bake_strip`) 높이가 곧 한 변이다.
## 🔴 소비자가 둘이다 — **그림자**(`_attach_shadow`)와 **죽음 폭발**(`_body_px`). 각자 재면
##  같은 몸을 두 크기로 보게 된다(세85 「복사하면 갈라진다」의 작은 판).
## ⚠ 반환은 **루트 배율 이전의 로컬 값**이다 — 그림자는 자식이라 배율을 저절로 먹고,
##  씬에 따로 붙는 폭발은 `_body_px`가 직접 곱한다. 여기서 미리 곱하면 그림자가 두 번 먹는다.
func _frame_side() -> float:
	if _visual != null and _visual.sprite_frames != null \
			and _visual.sprite_frames.has_animation(&"idle") \
			and _visual.sprite_frames.get_frame_count(&"idle") > 0:
		var t := _visual.sprite_frames.get_frame_texture(&"idle", 0)
		if t != null:
			return float(t.get_height())
	return FRAME_SIDE_FALLBACK


## 🔴 발밑 그림자 자동 부착 (세63 설계 §D) — 루트 scale의 자식이라 `params.size`(=덩치)를 공짜로
## 추종한다. 크기·오프셋은 idle 첫 프레임의 한 변에서 근사(연출 시작값 — 사용자 튜닝).
## z는 **0 유지 + move_child(…, 0)** — 음수 z는 Ground(z0) 뒤로 숨는다(세54 마디 실증).
## 🔴 세104: **참조를 `_shadow`에 남긴다** — 시야가 몸을 지울 때 그림자도 같이 꺼야 하기 때문이다.
##  몸이 없는데 발밑 타원만 떠 있으면 **위치가 그대로 새 나간다**(설계 V3).
func _attach_shadow() -> void:
	var side := _frame_side()
	var shadow: Sprite2D = ShadowScript.new()
	shadow.radius_px = side * SHADOW_RADIUS_FRAC
	shadow.position = Vector2(0.0, side * SHADOW_OFFSET_FRAC)
	add_child(shadow)
	move_child(shadow, 0)
	_shadow = shadow
	_refresh_alpha()   # 이미 흐린 상태로 태어난 적(시야 밖 스폰)의 그림자를 첫 프레임부터 맞춘다


## 🔴 행동을 `params.ai`로 가른다 (기본 "chase" = 현행). 각 갈래가 `velocity`(추격 의지)를 세우면
## 공통 꼬리가 넉백을 얹어 move_and_slide한다. 접촉 피해는 각 갈래가 `_contact`로 부른다.
## 수치는 전부 `_param`으로 .tres에서 읽는다 (balance.tres 아님 — 적 수치는 EnemyDef가 쥔다).
func _physics_process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	# 🔴 `_dead`면 틱 자체를 건너뛴다 — holder는 죽음을 모른다(가드는 몸이 쥔다).
	if not _dead:
		_status.tick(delta)
	if _dead:
		return  # DoT로 죽었다 — 이 프레임엔 더 움직이지 않는다(queue_free는 프레임 끝에 반영된다)
	_regen(delta)
	# 🔴🔴 배회 중심은 **여기서** 잡는다 — `_ready`가 아니다(설계 §9-b · `_home` 머리말).
	_capture_home()
	var player := _player()
	# 🔴🔴 **시야 갱신은 여기다 — 아래 조기 return 「앞」이다**(설계 V12).
	#  `_physics_process` 끝에 두면 `player == null` 분기에 먹혀 **적이 마지막 알파에 굳는다**
	#  (씬 전환 사이 · 플레이어 사망 후 · 테스트 리그가 전부 그 경로다 — 에러는 0이다).
	#  그 경로의 값은 **「보인다」**로 흐른다(fail-open — `_judge_seen` 머리말).
	_update_vision(player, delta)
	# 🔴🔴 **발견 판정도 조기 return 「앞」이다 — 시야와 정확히 같은 이유다**(설계 V12).
	#  뒤에 두면 `player == null` 경로에서 안 돌아 **추격 플래그가 참인 채로 굳는다** ⇒ 씬 전환·
	#  플레이어 사망 뒤 다시 만났을 때 그게 **「새 발견」으로 안 읽혀 느낌표가 영영 안 뜬다**(에러 0).
	# 🔴🔴 **인지 갱신도 조기 return 「앞」이다 — 시야·느낌표와 정확히 같은 이유다**(설계 V12).
	#  뒤에 두면 `player == null` 경로에서 안 돌아 **추격 상태가 참인 채로 굳는다** ⇒ 씬 전환·
	#  플레이어 사망 뒤 다시 만나도 「새 발견」이 안 되고, 배회도 그 무대(연출 도구·그물 다수)에서
	#  아예 안 돌아 **헤드리스가 못 잰다**(설계 §9-c).
	_update_percept(player, delta)
	_update_alert(player)
	if player == null:
		velocity = Vector2.ZERO
		# 🔴 배회는 「플레이어를 모르는 상태」의 행동이라 개념상 여기가 맞다(설계 §9-c).
		#  데이터가 없으면 배회 0이므로 주입 몸은 그대로 굳는다(§7-b).
		_apply_percept_velocity(delta)
		_apply_move(delta)
		return
	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()

	match _ai:
		"charge":
			_ai_charge(delta, player, to_player, dist)
		"hover":
			_ai_hover(delta, player, to_player, dist)
		"stationary":
			_ai_stationary(player, dist)
		"boss_snake":
			_ai_boss_snake(delta, player, to_player, dist)
		"boss_gale":
			_ai_boss_gale(delta, player, to_player, dist)
		_:
			_ai_chase(player, to_player, dist)

	# 🔴🔴 **인지는 갈래의 「속도 목표」만 덮는다 — 갈래 호출 자체는 안 끊는다**(설계 §2-b · C2).
	#  `takbon-rules` §5의 세88 계약(*"거리 게이트는 이동 대입만 감싼다 — `return` 금지"*)과 같은
	#  형태다: 갈래 안에서 `return`으로 끊으면 `_contact`(접촉 피해)와 분산·쿨다운 타이머가
	#  **멀리서 멈춘다.** 그래서 갈래를 다 돌린 **뒤** 속도만 갈아 끼운다.
	_apply_percept_velocity(delta)
	_apply_move(delta)


## 넉백을 추격 속도 위에 얹어 움직이고 넉백을 사그라뜨린다 (피격 손맛). 모든 갈래 공통 꼬리.
## 🔴 **감속은 여기 한 곳에만** 곱한다 (세션49) — AI 3종(추격·돌진·부유)이 전부 이 통로를 지나므로
## 한 줄이 전부를 먹는다. 갈래마다 곱하면 새 AI를 넣을 때 조용히 빠진다.
## ⚠ 넉백에는 안 곱한다 — 넉백은 손맛(연출)이지 이동 의지가 아니다.
##
## 🔴🔴 **세104: 「보는 쪽」도 여기서 나온다 — 감속을 여기서만 곱하는 것과 정확히 같은 이유다.**
##  갈래마다 부르면 새 AI를 넣을 때 **조용히 빠진다**(늑대만 뒤집히고 새 적은 안 뒤집힌다).
func _apply_move(delta: float) -> void:
	# 🔴 **감속·넉백을 얹기 「전」 값이다** — 이건 「이동 의지」이지 실제 변위가 아니다:
	#  ⓐ 진흙에 묶여 느려진 늑대도 **가려던 쪽**을 봐야 하고(감속을 곱한 뒤면 데드존에 먹혀 굳는다)
	#  ⓑ 맞아서 밀린다고 **뒤로 돌아보면 안 된다**(넉백을 더한 뒤면 맞을 때마다 고개가 홱 돈다).
	# 🔴🔴 **세105: 「보는 쪽」이 velocity에서 `_look_dir`로 갈렸다** — 그 사이에 `turn_rate`가 들어갔다.
	#  `_update_look`이 이번 틱의 **목표 방향**을 정하고 회전 속도로 감속해 `_look_dir`을 굴리며,
	#  `_update_facing`은 그 결과를 그림에 옮길 뿐이다. **부르는 자리는 여전히 여기 하나다.**
	_update_look(delta)
	_update_facing(_look_dir)
	velocity *= _status.move_mult()
	velocity += _knockback
	move_and_slide()
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)


## "chase" (기본, 슬라임·갑충·엘리트) — sight_range 안이면 다가오고 attack_range 안이면 때린다.
## 🔴🔴 세84: 여기 폴백이 **`slime.tres`의 실값을 그대로 베낀 사본**(160.0·55.0)이었다 —
## slime.tres가 파싱에 실패해 `_def == null`이 돼도 **슬라임과 똑같이 움직여서** 데이터 죽음이
## 행동에 안 드러났다(`test_status_auto`가 slime을 16회 스폰하는데 전부 통과했다. 세50 바람 룬과
## 같은 침묵). 이 두 값은 「없으면 중립」이 아니라 **필수 수치**라 `_param_req`로 바꿨다 —
## 결손이면 적이 굳고 `push_warning`이 뜬다(= 조용하지 않다). 데이터 쪽 짝그물은
## `test_progression_auto [1]`("chase는 sight_range·move_speed를 .tres로 쥔다").
## ⚠ 세105에 그 키가 `aggro_range` → `sight_range`로 **이름 승계**됐다(`SIGHT_KEY` 머리말) —
##  옛 이름도 폴백으로 계속 읽으므로 인지 키 0개인 주입 몸은 한 톨도 안 바뀐다.
func _ai_chase(player: Node2D, to_player: Vector2, dist: float) -> void:
	if dist <= _sight_range_req() and dist > 1.0:
		velocity = to_player / dist * _param_req("move_speed")
	else:
		velocity = Vector2.ZERO
	_contact(player, dist)


## "charge" (사냥개) — 접근 → 윈드업(멈춰 텔레그래프·방향 락 · **바닥에 닿을 범위**) →
## 돌진(락 방향으로 빠르게) → 회복(느림) → 접근. 🔴 락을 **윈드업 시작에** 걸어 두므로, 그 사이
## 옆으로 피하면 돌진을 흘린다(피할 수 있는 공격이 되게 하는 핵심).
## 접촉 피해는 접근·돌진에서만 — 윈드업·회복은 무해(빈틈 = 「피한 보상」).
## 🔴 세99: 윈드업 동안 **바닥 예고 범위**가 뜬다(`_show_charge_band`) — 붉은 달아오름은
##  *"온다"*만 말하고 *"어디까지"*를 안 말했다. 켜고 끄는 자리는 `_set_telegraph`와 **같은 두 줄**이다
##  (한쪽만 옮기면 몸은 식었는데 바닥이 남는다 — 그 짝을 갈라 놓지 마라).
func _ai_charge(delta: float, player: Node2D, to_player: Vector2, dist: float) -> void:
	match _charge_state:
		ChargeState.APPROACH:
			if dist <= _sight_range(220.0) and dist > 1.0:
				velocity = to_player / dist * _param("move_speed", 95.0)
			else:
				velocity = Vector2.ZERO
			_contact(player, dist)
			# 🔴🔴 **인지가 바꾸는 둘째가 여기다 — 「돌진 사이클의 진입 허용 여부」**(설계 §2-b 표).
			#  아직 나를 못 본 늑대가 등 뒤에 붙은 나를 향해 윈드업을 시작하면 **기습(ⓕ)이 성립하지
			#  않는다.** ⚠ 인지 데이터가 없는 몸은 `_percept_allows_attack()`이 늘 참이라 옛 동작이다.
			if _percept_allows_attack() and dist <= _param("charge_trigger_range", 120.0) and dist > 1.0:
				_charge_state = ChargeState.WINDUP
				_charge_windup = maxf(_param("windup_sec", 0.5), 0.001)
				_charge_timer = _charge_windup
				_charge_dir = to_player / dist  # 방향 락 (지금 이 순간의 플레이어 쪽)
				_set_telegraph(true)
				_show_charge_band(true)
		ChargeState.WINDUP:
			velocity = Vector2.ZERO
			_charge_timer -= delta
			# 🔴 매 틱 갱신하는 이유는 둘이다: ⓐ 남은 시간이 채움 길이로 보여야 하고
			#  ⓑ 윈드업 중에 맞으면 넉백으로 **몸이 밀린다** — 안 따라가면 예고가 몸을 떠난다.
			_update_charge_band(1.0 - clampf(_charge_timer / _charge_windup, 0.0, 1.0))
			if _charge_timer <= 0.0:
				_charge_state = ChargeState.CHARGE
				_charge_timer = _param("dash_sec", DASH_SEC_FALLBACK)
				_set_telegraph(false)
				_show_charge_band(false)
		ChargeState.CHARGE:
			velocity = _charge_dir * _param("charge_speed", CHARGE_SPEED_FALLBACK)
			_contact(player, dist)
			_charge_timer -= delta
			if _charge_timer <= 0.0:
				_charge_state = ChargeState.RECOVER
				_charge_timer = _param("recover_sec", 0.8)
		ChargeState.RECOVER:
			velocity = Vector2.ZERO
			_charge_timer -= delta
			if _charge_timer <= 0.0:
				_charge_state = ChargeState.APPROACH


## "hover" (안개) — 거리 유지: hover_min보다 가까우면 물러나고, hover_max보다 멀면 다가오고,
## 그 사이면 천천히 스트레이프. disperse_period마다 분산 상태를 토글(분산 중 피해 경감 + 반투명).
func _ai_hover(delta: float, player: Node2D, to_player: Vector2, dist: float) -> void:
	var spd := _param("move_speed", 70.0)
	var dir := to_player / dist if dist > 0.01 else Vector2.ZERO
	# 🔴🔴 leash (세88 사냥 흐름) — `sight_range`(옛 `aggro_range`) 밖이면 자기 자리를 지킨다. 이게 없으면 hover는
	# 거리와 무관하게 늘 다가와 **절대 안 놓친다**(리드가 우려한 "영영 못 만난다"의 정반대였다).
	# 방이 1200×1040일 때는 안 드러났지만 2400×2200 숲에서는 mist 5마리가 **전부 남쪽 입구로 모여**
	# 구역 배치가 무의미해지고 「깊이 들어간다」가 통째로 사라진다.
	# ⚠ **이동 대입만 감싼다** — `return`으로 끊으면 아래 `_contact`와 분산 타이머가 멀리서 멈춘다
	# (분산 주기가 조용히 고장 나는 자리 — 게이트를 넣는 세 갈래 전부 같은 이유로 이 모양이다).
	if dist > _sight_range(200.0):
		velocity = Vector2.ZERO
	elif dist < _param("hover_min", 55.0):
		velocity = -dir * spd            # 너무 가깝다 → 물러난다
	elif dist > _param("hover_max", 95.0):
		velocity = dir * spd             # 너무 멀다 → 다가온다
	else:
		velocity = Vector2(-dir.y, dir.x) * spd * 0.5  # 사이 → 천천히 옆으로 돈다
	_contact(player, dist)

	var period := _param("disperse_period", 0.0)
	if period > 0.0:
		_disperse_timer -= delta
		if _disperse_timer <= 0.0:
			_disperse_timer = period
			_set_dispersed(not _dispersed)


## "stationary" (덩굴) — 안 움직인다(move_speed 0). 재생은 `_regen`이 공통으로 돌린다.
## 접촉 피해는 긴 attack_range로 — "빨리 몰아쳐 죽여야 하는" 표적.
func _ai_stationary(player: Node2D, dist: float) -> void:
	velocity = Vector2.ZERO
	_contact(player, dist)


## "boss_snake" (뱀 보스, 세션 A) — 세그먼트 몸통(snake_body.gd)을 **살리는** 이동이 핵심이다.
##  • **위브 추격**: 플레이어를 향하는 진행 벡터에 그 수직 방향으로 sin(t·freq)·amp를 얹어 머리가
##    S자로 미끄러진다 → 몸통이 그 S를 물려받아 물결친다(설계 A-3·A-5).
##  • **텔레그래프 러시**: 짧게 멈춰 붉게 달아오른 뒤(기존 `_set_telegraph` 재사용) 플레이어 쪽으로
##    확 뻗고 회복한다. 방향은 윈드업 시작에 락(그 사이 피하면 흘린다 — charge와 같은 손맛).
##  • **hp 절반 페이즈**: 위브 진폭·러시 빈도·이동속도 배율이 오른다(1회 플래그).
## 🔴 수치는 전부 `_param`으로 .tres(EnemyDef)에서 읽는다 — balance.tres 아님(적 수치는 EnemyDef).
## 🔴 머리 회전은 **`_visual.rotation`만** 돌린다(루트 rotation은 SnakeBody 자식 좌표를 꼬는다, A-6).
func _ai_boss_snake(delta: float, player: Node2D, to_player: Vector2, dist: float) -> void:
	# 페이즈 전이 — hp가 임계 밑으로 처음 떨어지는 순간 1회.
	if not _phase2 and _def != null and _hp <= _def.hp * _param("phase2_hp_frac", 0.5):
		_phase2 = true

	_weave_t += delta
	_snake_rush_cd = maxf(0.0, _snake_rush_cd - delta)
	var speed_mult := _param("phase2_speed_mult", 1.35) if _phase2 else 1.0
	var weave_amp := _param("phase2_weave_amp", 90.0) if _phase2 else _param("weave_amp", 60.0)

	match _snake_state:
		SnakeState.WEAVE:
			# 🔴🔴 leash (세88) — gale과 같은 이유다(72px/s로 어귀까지 내려왔다). 위브 계산만 감싼다:
			# 아래 `_contact`·러시 쿨다운·페이즈2는 위(match 밖)에서 이미 돌고 있어 안 건드린다.
			if dist > 1.0 and dist <= _sight_range(320.0):
				var fwd := to_player / dist
				var perp := Vector2(-fwd.y, fwd.x)
				var base_speed := _param("move_speed", 72.0) * speed_mult
				var lateral := sin(_weave_t * _param("weave_freq", 3.2)) * weave_amp
				velocity = fwd * base_speed + perp * lateral
			else:
				velocity = Vector2.ZERO
			_contact(player, dist)
			# 러시 발동 — 쿨다운이 끝났고 사거리 안이면 윈드업으로.
			if _snake_rush_cd <= 0.0 and dist <= _param("rush_range", 240.0) and dist > 1.0:
				_snake_state = SnakeState.RUSH_WINDUP
				_snake_timer = _param("rush_windup", 0.6)
				_snake_dir = to_player / dist  # 방향 락(지금 이 순간)
				_set_telegraph(true)
		SnakeState.RUSH_WINDUP:
			velocity = Vector2.ZERO
			_snake_timer -= delta
			if _snake_timer <= 0.0:
				_snake_state = SnakeState.RUSH
				_snake_timer = _param("rush_dur", 0.5)
				_set_telegraph(false)
		SnakeState.RUSH:
			velocity = _snake_dir * _param("rush_speed", 340.0) * speed_mult
			_contact(player, dist)
			_snake_timer -= delta
			if _snake_timer <= 0.0:
				_snake_state = SnakeState.RECOVER
				_snake_timer = _param("rush_recover", 0.8)
		SnakeState.RECOVER:
			velocity = Vector2.ZERO
			_snake_timer -= delta
			if _snake_timer <= 0.0:
				_snake_state = SnakeState.WEAVE
				var cd := _param("phase2_rush_cd", 1.8) if _phase2 else _param("rush_cd", 3.0)
				_snake_rush_cd = cd

	# 머리는 진행 방향(러시 중이면 락 방향)을 바라본다. 멈춰 있으면 마지막 방향 유지.
	if velocity.length_squared() > 1.0:
		_snake_dir = velocity.normalized()
	_face(_snake_dir)


## "boss_gale" (바람 보스, 세56) — hover형 거리 유지 + 근접 징벌(돌풍) + 원거리 압박(연사).
##  • **DRIFT**: hover_min~hover_max 거리 유지(가까우면 물러나고 멀면 다가오고 사이면 스트레이프).
##    `_ai_hover` 함수를 재사용하지 않고 분기 안에 다시 쓴다 — 그 함수엔 disperse(안개)가 얽혀 있다.
##  • **돌풍(gust)**: 쿨 소진 && dist ≤ gust_radius → 윈드업(붉은 텔레그래프 + 반경 링) →
##    끝나는 순간 반경 안이고 구르는 중이 아니면 피해 + 밀쳐내기(`player.apply_push`).
##    플레이어가 안 붙으면 안 쓴다 — 낭비 텔레그래프 없음.
##  • **연사(volley)**: DRIFT에서만 쿨 감소(윈드업과 안 겹치게). 발동하면 **이동을 유지한 채**
##    volley_interval마다 1발 — 매 발 발사 순간의 플레이어 위치로 **재조준**(움직이며 피하는 재미).
##  • **hp 절반 페이즈**: `_phase2` 공용 재사용 — 돌풍·연사 쿨(rate_mult)·이동속도(speed_mult)가 오른다.
##    배율은 **쿨 리셋 시점에** 곱한다(진행 중 타이머를 건드리면 전이 순간 이중 적용).
## 🔴 수치는 전부 `_param`으로 .tres(EnemyDef)에서 읽는다 — balance.tres 아님(적 수치는 EnemyDef).
func _ai_boss_gale(delta: float, player: Node2D, to_player: Vector2, dist: float) -> void:
	# 페이즈 전이 — hp가 임계 밑으로 처음 떨어지는 순간 1회 (boss_snake 첫 줄과 동일 패턴).
	if not _phase2 and _def != null and _hp <= _def.hp * _param("phase2_hp_frac", 0.5):
		_phase2 = true
	var rate_mult := _param("phase2_rate_mult", 0.65) if _phase2 else 1.0
	var speed_mult := _param("phase2_speed_mult", 1.3) if _phase2 else 1.0

	match _gale_state:
		GaleState.DRIFT:
			# 거리 유지 (hover형 재작성 — 로직 ~8줄이라 분기 내가 깨끗하다).
			var spd := _param("move_speed", 55.0) * speed_mult
			var dir := to_player / dist if dist > 0.01 else Vector2.ZERO
			# 🔴🔴 leash (세88) — 없으면 gale이 **자기 자리를 버리고 남쪽 입구까지 내려온다**
			# (55px/s × 2200px ≈ 40초) → 보스를 어귀에서 잡몹과 함께 만난다. ⚠ 이동 대입만 감싼다:
			# 아래 쿨다운 감소·돌풍/연사 발동·페이즈2 전이는 **멀리 있어도 계속 돌아야 한다**
			# (`return`으로 끊으면 페이즈2가 안 열리는 조용한 고장이 된다).
			if dist > _sight_range(260.0):
				velocity = Vector2.ZERO
			elif dist < _param("hover_min", 110.0):
				velocity = -dir * spd            # 너무 가깝다 → 물러난다
			elif dist > _param("hover_max", 170.0):
				velocity = dir * spd             # 너무 멀다 → 다가온다
			else:
				velocity = Vector2(-dir.y, dir.x) * spd * 0.5  # 사이 → 천천히 옆으로 돈다
			_contact(player, dist)               # attack_range 30 근접 징벌은 그대로 산다
			_gale_gust_cd = maxf(0.0, _gale_gust_cd - delta)
			_gale_volley_cd = maxf(0.0, _gale_volley_cd - delta)
			# 돌풍 — 쿨 소진 && 플레이어가 반경 안일 때만 (안 붙으면 낭비 텔레그래프 없음).
			if _gale_gust_cd <= 0.0 and dist <= _param("gust_radius", 90.0) and dist > 1.0:
				_gale_state = GaleState.GUST_WINDUP
				_gale_timer = _param("gust_windup", 0.8)
				_set_telegraph(true)             # 기존 붉은 달아오름 재사용 (charge·snake와 같은 규약)
				_show_gust_ring(true)
			# 연사 — 진행 중이 아닐 때만 새로 발동. 쿨 리셋 시점에 페이즈 배율을 곱는다.
			elif _gale_volley_cd <= 0.0 and _gale_volley_left <= 0 and dist <= _sight_range(260.0):
				_gale_volley_left = int(_param("volley_count", 3.0))
				_gale_shot_timer = 0.0           # 첫 발은 다음 틱 즉시
				_gale_volley_cd = _param("volley_period", 4.5) * rate_mult
		GaleState.GUST_WINDUP:
			velocity = Vector2.ZERO
			_gale_timer -= delta
			if _gale_timer <= 0.0:
				_gale_state = GaleState.DRIFT
				_set_telegraph(false)
				_show_gust_ring(false)
				_resolve_gust(player, dist)
				_gale_gust_cd = _param("gust_period", 3.0) * rate_mult

	# 연사 발사 — DRIFT 위 오버레이 카운터(전용 상태 아님 — 이동하며 쏘는 바람 궁수 느낌).
	# 윈드업 중엔 멈춘다(돌풍과 안 겹치게) — DRIFT로 돌아오면 남은 발수를 이어 쏜다.
	if _gale_volley_left > 0 and _gale_state == GaleState.DRIFT:
		_gale_shot_timer -= delta
		if _gale_shot_timer <= 0.0:
			_gale_shot_timer = _param("volley_interval", 0.25)
			_gale_volley_left -= 1
			_fire_gale_shot(player)


## 돌풍 판정 — 윈드업이 끝나는 순간 1회. 반경 밖이면 헛방(윈드업을 보고 걸어나가면 피한다),
## 구르는 중이면 피해·밀림 다 흘린다(구르기 = 무적 계약 — `_contact`와 동일 규약).
func _resolve_gust(player: Node2D, dist: float) -> void:
	if player == null or dist > _param("gust_radius", 90.0):
		return
	var dodging: bool = player.has_method(&"is_rolling") and bool(player.call(&"is_rolling"))
	if dodging:
		return
	# 🔴 source_pos(세63) = 내 위치 — player_hurt에 실려 방향성 카메라 킥이 쓴다.
	GameState.damage_player(_param("gust_damage", 8.0), global_position)
	# 밀쳐내기 — 방향 = 나 → 플레이어. has_method 가드: 테스트 더미(Node2D)도 견딘다.
	if player.has_method(&"apply_push"):
		var away := player.global_position - global_position
		if away.length() > 0.1:
			player.call(&"apply_push", away.normalized(), _param("gust_push_dist", 70.0))


## 연사 1발 — **발사 순간의 플레이어 위치**로 재조준(락 조준은 3발이 같은 자리에 몰려 밋밋).
## 탄은 현재 씬에 붙는다(`_spawn_death_burst`·drop_pickup 규약 — 적이 죽어도 탄은 남는다: 유언 탄).
func _fire_gale_shot(player: Node2D) -> void:
	var scene := get_tree().current_scene
	if scene == null or player == null:
		return
	var dir := player.global_position - global_position
	if dir.length() < 0.1:
		return
	var proj := GaleProj.instantiate()
	scene.add_child(proj)
	proj.global_position = global_position
	proj.setup(dir.normalized(), _param("proj_damage", 6.0),
		_param("proj_speed", 170.0), _param("proj_lifetime", 2.8))


## 돌풍 반경 텔레그래프 링 — 윈드업 동안만 보인다. **절차적 VFX라 도형이 맞다**(takbon-rules §0
## 예외 — 돌풍은 형태 없는 공기 흐름, 마나 폭발·vfx.gd 링과 같은 "그림"이다). 지연 생성이라
## gale이 아닌 적은 노드 자체가 없다. 🔴 z_index 양수 명시 — 세54에 음수 z 마디가 Ground(z0)
## 뒤로 숨은 함정의 재발 자리다.
func _show_gust_ring(on: bool) -> void:
	if on and _gale_ring == null:
		_gale_ring = Line2D.new()
		_gale_ring.width = GUST_RING_WIDTH
		_gale_ring.default_color = GUST_RING_COLOR
		var radius := _param("gust_radius", 90.0)
		var pts := PackedVector2Array()
		for i in GUST_RING_SEGMENTS:
			pts.append(Vector2.RIGHT.rotated(TAU * float(i) / float(GUST_RING_SEGMENTS)) * radius)
		pts.append(pts[0])  # 닫는다 (vfx._spawn_ring과 같은 결)
		_gale_ring.points = pts
		_gale_ring.z_index = 40
		add_child(_gale_ring)
	if _gale_ring != null:
		_gale_ring.visible = on


## 🔴🔴 **느낌표(!) — 「나를 못 보는 동안 나를 발견한 적」의 유일한 기척** (세104 · 사용자 요청
##  *"지금 내 시야에 없을 때 나를 발견하면 느낌표가 뜨게"*).
##
## 🔴🔴 **왜 이게 필요한가 — 실측이 설계의 전제를 뒤집었다.** `vision_design`은
##  *"「기척」 = 이미 화면에 있는 것들이다. 새 표현을 만들지 않는다 — 돌진의 **바닥 예고**와
##  **돌풍 링**이 그 자리를 이미 채운다"*라고 적어 뒀는데, **그 장면이 구조적으로 안 나온다**:
##
##  | | 예고가 켜지는 거리(`charge_trigger_range`) | 주변시(`vision_near_radius`) |
##  |---|---|---|
##  | `hound` | **120** | 220 |
##  | `hound_alpha` | **160** | 220 |
##
##  예고는 **주변시보다 한참 안쪽**에서 켜진다 ⇒ **예고가 뜰 땐 적이 이미 보인다.**
##  「몸은 없고 빨간 띠만」은 한 번도 안 일어난다(보스는 `always_visible`이라 애초에 무관).
##  ⇒ **시야 밖 적은 지금 완전히 투명하고, 이 느낌표가 유일한 통보다.** 은은하게 만들지 마라.
##
## 🔴🔴 **뜨는 창은 「aggro − 주변시」다** — 지금 실질적으로 뜨는 건 **네임드뿐**이다:
##  바탕 늑대는 `aggro 220 = 주변시 220`이라 **발견하는 순간 이미 보여** 창이 0이고,
##  `hound_alpha`만 `aggro 280`이라 **220~280 구간**에서 뜬다(설계 §4-1-b가 *"등 뒤 60px"*로
##  일부러 만든 그 차이다). ⚠ **그러니 누가 주변시나 aggro를 조이면 이 기능이 조용히 사라지거나
##  남발된다** — 그때 이 주석을 보고 의도를 알아채라.
## 🔴 **「우두머리냐」로 분기하지 않는다 — `_seen`만 본다.** 그래야 수치를 조이는 날
##  바탕 늑대에게도 **저절로** 켜진다(종을 하드코딩하면 그날 아무 일도 안 일어난다).
##
## 🔴 **도형이 맞다** (takbon-rules §0 도형 금지의 예외): 느낌표는 생명체·프롭의 **겉모습**이 아니라
##  **신호**다 — 돌풍 링·돌진 예고와 같은 「그림」이고 도트로 그릴 물건이 아니다.
##  ⚠ 실게임에서 어색하면 답은 코드가 아니라 **`takbon-art`의 스프라이트**다(리포트에 적었다).
##
## 🔴🔴 **`_visual`의 「형제」여야 한다 — 자식으로 달지 마라.** 자식으로 달면 시야 알파
##  (`_refresh_alpha`가 `_visual.modulate.a`에 0을 찍는다)에 물려 **몸이 안 보일 때 느낌표도 같이
##  사라진다** = 이 기능이 통째로 무의미해진다(에러 0 · 다른 그물은 전부 그린).
##  `_gale_ring`이 정확히 같은 자리에 있고 `test_vision_auto [6]`이 그 계약의 유일한 검출자다.
##  ✅ 형제라서 **좌우 반전(`_update_facing`)에도 안 딸려 간다** — 반전은 `_visual`에만 건다.
## ✅ 대신 **적의 자식이라 수명이 공짜다** — 적이 죽으면 같이 죽는다(`_charge_band`가 씬 소유로
##  옮기며 치른 그 대가가 여기엔 없다).
const AlertMarkName := &"AlertMark"

## 느낌표 **연출값** (밸런스 아님 — `GUST_RING_*`·`CHARGE_BAND_*` 선례).
## 🔴 색은 파생원이 없다 — 룬 색도 상태 색도 아닌 **적의 신호**라 TAKBON 60에서 직접 고른다
##  (`GUST_RING_COLOR`·`CHARGE_BAND_*`가 같은 자리다. `VFX_SPEC` §1의 「자기 색 테이블 금지」는
##  **원소·상태** VFX에 대한 규칙이다).
## 🔴 **`F2CB3F` 쨍한 노랑 + `2E1F18` 따뜻한 최암부 윤곽** — 밝은 낮 풀밭(`#4A9E38`) 위에서
##  가장 멀리 읽히는 짝이다. ⚠ **알파를 낮추지 마라**: 세99 실측이 *"붉은색을 옅게 깔면 초록과
##  상쇄돼 갈색이 된다"*를 픽셀로 증명했다 — 신호는 **불투명해야** 신호다.
## ⚠ 돌진 예고의 붉은 램프와 **일부러 다른 색**이다: 붉은 띠는 *"여기 맞는다"*, 느낌표는
##  *"저기서 나를 봤다"* — 같은 색이면 두 신호가 섞인다.
const ALERT_FILL := Color(0.949, 0.796, 0.247, 1.0)     ## F2CB3F
const ALERT_EDGE := Color(0.180, 0.122, 0.094, 1.0)     ## 2E1F18
const ALERT_EDGE_GROW := 1.3        ## 윤곽이 채움 밖으로 나오는 두께(px)
const ALERT_ABOVE_FRAC := 0.95      ## 머리 위 높이 = 프레임 한 변 × 이 값 (`_frame_side` 파생)
const ALERT_POP_FROM := 0.35        ## 튀어나오는 시작 배율
const ALERT_POP_SEC := 0.10         ## 튀어나오는 시간
const ALERT_HOLD_SEC := 0.55        ## 만빛으로 머무는 시간
const ALERT_FADE_SEC := 0.25        ## 사라지는 시간 (총 0.90s)
const ALERT_RISE_PX := 5.0          ## 사라지며 떠오르는 거리

## 지금 이 몸이 플레이어를 **쫓고 있나**(직전 틱). 느낌표는 이 값의 **false→true 전이**에서만 뜬다 —
## 매 프레임 조건으로 띄우면 추격 내내 계속 떠 있어 통보가 아니라 장식이 된다.
var _pursuing: bool = false
var _alert_mark: Node2D = null
var _alert_tween: Tween = null


## 🔴 발견 전이를 판정한다. **이 함수가 「발견」의 유일한 정의다.**
##
## ✅ **세105에 예고대로 갈아 끼웠다** — 세104 판이 여기에 거리 비교를 **직접** 들고 있었고
##  (`aggro_range`를 읽는 **일곱째** 자리였다) *"인지가 들어오면 이 한 줄을 인지 상태로
##  바꿔라"*라고 스스로 적어 뒀다. 이제 「발견」의 정의는 **`_percept == CHASE` 하나**이고
##  거리·각도·소리 판정은 전부 `_update_percept`가 진다 ⇒ **읽는 자리가 하나 줄었다.**
##
## 🔴 **「우두머리냐」로 분기하지 않는다 — `_seen`만 본다.** 그래야 수치를 조이는 날
##  바탕 늑대에게도 저절로 켜진다(종을 하드코딩하면 그날 아무 일도 안 일어난다).
## ⚠ 인지 데이터가 0인 몸(그물 주입)에서도 뜻이 안 바뀐다: 폴백이 「부채꼴 360° · 한 박자 0」이라
##  `_percept == CHASE`가 **정확히 옛 거리 비교**와 같다(§7-b).
func _update_alert(player: Node2D) -> void:
	var now := player != null and _percept == Percept.CHASE
	# 🔴 **전이 + 안 보일 때만.** 보이는 적까지 띄우면 화면이 시끄러워지고, 무엇보다
	#  「안 보이는 것을 알린다」는 이 기능의 뜻 자체가 사라진다.
	if now and not _pursuing and not _seen:
		_show_alert_mark()
	_pursuing = now


## 느낌표를 띄운다 — 지연 생성(`_gale_ring` 선례: 한 번도 안 뜬 적은 노드가 아예 없다) 뒤 재사용.
## 🔴 **트윈을 갈아치울 때 이전 것을 죽인다** — 어그로 경계에서 들락날락하면 두 트윈이 같은
##  `scale`·`modulate`를 서로 다른 목표로 끌어 값이 튄다(`_pop`의 「마지막 승리」와 같은 규약을
##  명시적으로 건 것이다 — 여기선 `visible = false` 콜백이 있어 늦게 끝난 옛 트윈이 **새로 뜬
##  느낌표를 꺼 버린다**).
func _show_alert_mark() -> void:
	if _alert_mark == null:
		_alert_mark = _build_alert_mark()
		add_child(_alert_mark)     # 🔴 `self`의 자식 = `_visual`의 **형제** (머리말)
	if _alert_tween != null and _alert_tween.is_valid():
		_alert_tween.kill()
	var top := -_frame_side() * ALERT_ABOVE_FRAC
	_alert_mark.position = Vector2(0.0, top)
	_alert_mark.scale = Vector2(ALERT_POP_FROM, ALERT_POP_FROM)
	_alert_mark.modulate.a = 1.0
	_alert_mark.visible = true
	var tw := create_tween()
	tw.tween_property(_alert_mark, "scale", Vector2.ONE, ALERT_POP_SEC) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(ALERT_HOLD_SEC)
	tw.tween_property(_alert_mark, "modulate:a", 0.0, ALERT_FADE_SEC)
	tw.parallel().tween_property(_alert_mark, "position:y", top - ALERT_RISE_PX, ALERT_FADE_SEC)
	tw.tween_callback(func() -> void:
		if _alert_mark != null and is_instance_valid(_alert_mark):
			_alert_mark.visible = false)
	_alert_tween = tw


## 느낌표 도형 — 채움(노랑) 아래에 **부풀린 윤곽**(최암부)을 깐다. 순서 = 윤곽 먼저, 채움 나중.
## ⚠ 크기는 **루트 배율(`params.size`)을 그대로 탄다 — 일부러다.** `_charge_band`가 역스케일을
##  거는 이유는 그쪽이 **월드 px 판정과 짝**이라 부풀면 그림이 거짓말을 하기 때문인데, 느낌표엔
##  그런 짝이 없다. 큰 짐승이 크게 외치는 쪽이 오히려 읽힌다.
func _build_alert_mark() -> Node2D:
	var mark := Node2D.new()
	mark.name = AlertMarkName
	mark.z_index = 45   # 🔴 양수 명시 — 세54에 음수 z 마디가 Ground(z0) 뒤로 숨었다(`_show_gust_ring` 선례)
	var stem := PackedVector2Array([
		Vector2(-2.3, -7.0), Vector2(2.3, -7.0), Vector2(1.5, 1.5), Vector2(-1.5, 1.5)])
	var dot := PackedVector2Array([
		Vector2(-1.8, 3.2), Vector2(1.8, 3.2), Vector2(1.8, 6.8), Vector2(-1.8, 6.8)])
	for pts: PackedVector2Array in [stem, dot]:
		mark.add_child(_alert_poly(_grown(pts, ALERT_EDGE_GROW), ALERT_EDGE))
	for pts: PackedVector2Array in [stem, dot]:
		mark.add_child(_alert_poly(pts, ALERT_FILL))
	return mark


func _alert_poly(pts: PackedVector2Array, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = color
	return p


## 볼록 다각형을 무게중심에서 바깥으로 `grow`px 밀어 윤곽을 만든다 — 도형이 넷뿐이라
## 진짜 오프셋 폴리곤 대신 이 근사로 충분하다(윤곽은 읽히기만 하면 된다).
func _grown(pts: PackedVector2Array, grow: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for p: Vector2 in pts:
		c += p
	c /= float(maxi(pts.size(), 1))
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		var d := p - c
		out.append(p + (d.normalized() * grow if d.length() > 0.001 else Vector2.ZERO))
	return out


## 🔴 공개 관측점 — 지금 느낌표가 떠 있나 (`charge_band_visible()`·`is_seen()` 선례).
## ⚠ **노드의 `visible`을 그대로 읽는다** — 내부 타이머를 돌려주면 트윈이 통째로 죽어도
##  그물이 옳은 값을 본다(세85 「검증 도구가 거짓말한다」).
func alert_mark_visible() -> bool:
	return _alert_mark != null and is_instance_valid(_alert_mark) and _alert_mark.visible


## 🔴🔴 돌진 예고 **바닥 범위** (세99 · 설계 §5-D) — 윈드업 동안만 뜬다. **절차적 VFX라 도형이 맞다**
## (takbon-rules §0 예외 — 예고는 생명체·프롭이 아니라 「빛·가이드선」이다. `_show_gust_ring` 선례).
## 지연 생성이라 charge가 아닌 적은 노드 자체가 없다.
##
## 🔴🔴 **어디에 붙이나 — 설계 §5-D-2의 확정안을 실측으로 두 번 뒤집었다**(`vfx_shot -- charge`).
##  그 절은 *"적 자식 + `move_child(…, 0)` + `top_level`"*을 확정으로 못 박았는데, 그대로 짜고
##  격자 PNG를 뽑아 보니 **「바닥에」가 두 번 깨졌다**:
##   ⓐ `top_level`은 트랜스폼만이 아니라 **같은 CanvasLayer 안에서 맨 위로 그리도록 그리기 순서까지
##      바꾼다** → 예고가 **늑대 몸 위**를 덮었다(트리 순서 손질이 통째로 무효가 된다).
##   ⓑ top_level을 빼면 늑대 아래로는 오지만, **적은 런타임 `add_child`라 씬 자식인 `Player`보다
##      나중에 그려진다** → 예고가 **플레이어 위**를 덮었다. 플레이어가 붉은 후드라 붉은 띠와 겹쳐
##      몸통이 통째로 묻혔다 — **자기가 어디 서 있는지 안 보이면 예고의 목적 자체가 무너진다.**
##  ⇒ 「Ground 위 · 적과 플레이어 아래」는 **z에 없는 자리**다(셋 다 z 0). 있는 건 **트리 순서**뿐이라
##    씬에 붙이고 **플레이어(가 속한 최상위 조각) 바로 앞**으로 옮긴다(`_place_on_floor_layer`).
##    🔴 인덱스를 숫자로 박지 않는다 — 방 씬 구조가 바뀌어도 따라가야 한다.
##    ⚠ 음수 z는 답이 아니다: Ground(ColorRect z0) 뒤로 숨는다(세54 마디 실증 · `shadow.gd` 머리말).
##
## 🔴 **대가 = 수명을 직접 쥐어야 한다**(적 자식이었으면 공짜였던 것). `_die`·`_exit_tree`가 지운다 —
##  안 지우면 **죽은 늑대의 붉은 띠가 바닥에 영영 남는다.** 그건 안 덮는 것보다 나쁘다.
func _show_charge_band(on: bool) -> void:
	if not on:
		if _charge_band != null:
			_charge_band.visible = false
		return
	if _charge_band == null:
		var scene := get_tree().current_scene
		if scene == null:
			return   # 무대가 없으면 그릴 자리도 없다 (`vfx.gd` 스포너들과 같은 가드)
		_charge_band = Node2D.new()
		_charge_band.name = "ChargeBand"
		_band_base = Polygon2D.new()
		_band_base.color = CHARGE_BAND_BASE
		_band_fill = Polygon2D.new()
		_band_fill.color = CHARGE_BAND_FILL
		_band_edge = Line2D.new()
		_band_edge.width = CHARGE_BAND_EDGE_W
		_band_edge.default_color = CHARGE_BAND_EDGE
		_band_front = Line2D.new()
		_band_front.width = CHARGE_BAND_FRONT_W
		_band_front.default_color = CHARGE_BAND_FRONT
		# 순서 = 아래부터: 옅은 전체 → 찬 만큼 → 전체 테두리 → 앞머리.
		_charge_band.add_child(_band_base)
		_charge_band.add_child(_band_fill)
		_charge_band.add_child(_band_edge)
		_charge_band.add_child(_band_front)
		scene.add_child(_charge_band)
		_place_on_floor_layer(scene)
	# ⚠ `visible`을 **먼저** 세운다 — `_update_charge_band`가 안 보이면 즉시 돌아가므로, 뒤에 세우면
	#  두 번째 윈드업의 첫 프레임이 **지난 판의 다 찬 채움**으로 보인다(에러 0 · 한 프레임 거짓말).
	_charge_band.visible = true
	# 🔴 **켤 때마다 범위를 다시 판다** — 수치는 `.tres`가 쥐고 조여지는 물건이라, 만들 때 한 번만
	#  재면 조인 값이 다음 판까지 안 온다(그리고 그 어긋남은 에러가 안 난다).
	var pts := _capsule_points(_charge_reach_length(), _contact_radius())
	_band_base.polygon = pts
	_band_edge.points = _closed(pts)
	_update_charge_band(0.0)


## 🔴 예고를 「바닥층」으로 옮긴다 = **플레이어 바로 앞 트리 순서**(위 머리말 ⓑ).
## 플레이어가 씬 바로 밑에 없을 수도 있으므로(`Actors` 같은 묶음 노드) **씬의 직계 조상까지 거슬러
## 올라가 그 조각의 인덱스**를 쓴다 — 그러면 방 씬을 재편해도 따라간다.
## ⚠ 플레이어를 못 찾으면 **맨 뒤(=위)에 그대로 둔다** — 예고가 안 보이는 것보다는 낫다.
##  (플레이어가 없는 무대 = 연출 도구·테스트뿐이고, 거기선 가릴 몸도 없다.)
func _place_on_floor_layer(scene: Node) -> void:
	var p := _player()
	if p == null:
		return
	var top: Node = p
	while top != null and top.get_parent() != scene:
		top = top.get_parent()
	if top == null or top == _charge_band:
		return
	scene.move_child(_charge_band, top.get_index())


## 🔴 예고를 지운다 — **씬 소유라 적이 죽어도 저절로 안 죽는다**(위 머리말의 「대가」).
## ⚠ 참조를 **전부 null로** 되돌린다: 다음 윈드업이 `_charge_band == null`을 보고 다시 만든다.
##  안 비우면 free된 노드를 만져 에러가 나고, 그 에러는 죽는 순간에만 나서 늦게 발견된다.
func _free_charge_band() -> void:
	if _charge_band != null and is_instance_valid(_charge_band):
		_charge_band.queue_free()
	_charge_band = null
	_band_base = null
	_band_fill = null
	_band_edge = null
	_band_front = null


## ⚠ **여기서 `_exit_tree`를 쓰는 건 세50 금기와 다른 종류다.** 그 금기는 **영구 배선(콜백)을
##  끊지 마라**는 것이었다(`_wire_status`가 `_ready`에만 있어 리페어런팅 시 영영 죽는다).
##  이쪽은 **한 판짜리 연출 노드**이고 다음 윈드업에 `_show_charge_band`가 다시 만든다 —
##  끊기는 계약이 없다. 안 지우면 반대로 **주인 없는 붉은 띠**가 화면에 남는다.
func _exit_tree() -> void:
	_free_charge_band()


## 예고가 「찬 만큼」을 갱신한다 — `progress` 0(방금 멈췄다) ~ 1(지금 튀어나온다).
## 🔴 채움이 **앞으로 뻗는 모양**인 것이 요점이다: 남은 시간이 보이면서 동시에 **어느 쪽으로 오는지**가
##  같은 그림 하나로 읽힌다(원형 게이지로는 방향이 안 나온다 — 늑대는 직선 돌진이다).
func _update_charge_band(progress: float) -> void:
	if _charge_band == null or not _charge_band.visible:
		return
	# 🔴 위치·방향을 매 틱 다시 세운다 — 씬 소유라 부모(=적)를 안 따라간다. 매 틱인 이유는 둘:
	#  ⓐ 윈드업 중에 맞으면 **넉백으로 몸이 밀린다**(안 따라가면 예고가 몸을 떠난다)
	#  ⓑ 방향 락은 윈드업 시작 한 번이지만, 값을 여기서 한곳으로 모아 두면 락을 옮길 때 갈라질 자리가 없다
	# 🔴 **scale은 절대 안 물려받는다** — 돌진 거리·`attack_range`는 월드 px라 덩치(`params.size`)와
	#  무관하다. 적 자식으로 되돌리면 `hound_alpha`(size 1.35)에서 **범위만 1.35배**로 그려져 예고가
	#  거짓말한다. 그물 = `test_charge_telegraph_auto [5]`.
	_charge_band.global_position = global_position
	if _charge_dir.length_squared() > 0.0001:
		_charge_band.rotation = _charge_dir.angle()
	var r := _contact_radius()
	var grown := _charge_reach_length() * lerpf(CHARGE_BAND_MIN_FILL, 1.0, clampf(progress, 0.0, 1.0))
	var pts := _capsule_points(grown, r)
	_band_fill.polygon = pts
	_band_front.points = _closed(pts)


## +X를 향한 캡슐(스타디움) 외곽점 — `(0,0)`부터 `(length,0)`까지의 선분을 반경 `radius`로 부풀린 것.
## 🔴 뒤쪽 캡을 빼지 않는다 — 돌진이 **시작되는 순간** 몸 뒤 `radius` 안에 있어도 `_contact`가 든다.
##  「보기 좋게」 잘라내면 그 자리가 곧 *"안 보이는 데서 맞았다"*가 된다.
func _capsule_points(length: float, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := CHARGE_BAND_CAP_SEGS
	var tip := Vector2(maxf(length, 0.0), 0.0)
	for i in n + 1:   # 앞 캡: -90° → +90°
		pts.append(tip + Vector2.RIGHT.rotated(-PI * 0.5 + PI * float(i) / float(n)) * radius)
	for i in n + 1:   # 뒤 캡: +90° → +270°
		pts.append(Vector2.RIGHT.rotated(PI * 0.5 + PI * float(i) / float(n)) * radius)
	return pts


## Polygon2D는 알아서 닫히지만 Line2D는 안 닫힌다 — 테두리용으로 첫 점을 덧붙인다
## (`_show_gust_ring`이 링에 하는 것과 같은 손질).
func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(pts)
	if out.size() > 0:
		out.append(out[0])
	return out


## 🔴 공개 관측점 — 지금 예고 범위가 떠 있나 (`hp()`·`phase()`·`hitbox_radius()` 선례).
## 헤드리스는 「보인다」를 못 재지만 **「윈드업 동안 있고 돌진에 없다」**는 잴 수 있다.
func charge_band_visible() -> bool:
	return _charge_band != null and is_instance_valid(_charge_band) and _charge_band.visible


## 🔴 공개 관측점 — 예고의 **그리기 순서 자리**(부모 안의 자식 인덱스). 없으면 -1.
## 「바닥에 깔린다」를 z가 아니라 **트리 순서**로 만들었으므로(`_show_charge_band` 머리말)
## **이 숫자가 그 계약의 유일한 측정 가능한 형태**다 — 헤드리스는 픽셀을 못 본다.
func charge_band_order() -> int:
	if _charge_band == null or not is_instance_valid(_charge_band):
		return -1
	return _charge_band.get_index()


## 🔴🔴 공개 관측점 — **화면에 실제로 그려진** 범위의 (도달거리, 반경), 월드 px.
## ⚠ **params에서 되계산하지 않고 폴리곤을 실측한다** — 되계산하면 `top_level`이 빠져 범위가
##  `size`배로 그려져도 이 리더가 옳은 값을 돌려줘 그물이 **거짓 그린**이 된다
##  (`hitbox_radius()`가 형상에서 읽는 것과 같은 이유 — 세85 「검증 도구가 거짓말한다」).
func charge_band_reach() -> Vector2:
	if _band_base == null or _band_base.polygon.size() == 0:
		return Vector2.ZERO
	var xf := _band_base.global_transform
	var fwd := xf.basis_xform(Vector2.RIGHT).normalized()
	var side := xf.basis_xform(Vector2.DOWN).normalized()
	var far := 0.0
	var rad := 0.0
	for p: Vector2 in _band_base.polygon:
		var w := xf.basis_xform(p)
		far = maxf(far, w.dot(fwd))
		rad = maxf(rad, absf(w.dot(side)))
	return Vector2(far - rad, rad)   # 앞 끝 = 길이 + 반경이므로 반경을 뺀다


## 🔴 머리만 회전 — `_visual.rotation`(설계 A-6). boss_snake 분기에서만 부른다(다른 AI 무영향).
## 스프라이트/플레이스홀더는 진행 방향 +x 기준이라 각도를 그대로 준다.
## ⚠ **좌우 반전(`_update_facing`)과 한 몸에서 같이 못 산다** — 아래 `_uses_rotation_facing` 참조.
func _face(dir: Vector2) -> void:
	if _visual == null or dir.length_squared() < 0.0001:
		return
	_visual.rotation = dir.angle()


## 🔴🔴 **좌우 반전 — 「보는 쪽」의 시각 갈래** (세104 · 설계 `enemy_perception_design.md` §4).
##  늑대가 왼쪽으로 가면 왼쪽을, 오른쪽으로 가면 오른쪽을 본다.
##
## 🔴 **방향을 정하는 자리는 이 함수 하나다.** 지금 입력은 「이동 의지」(`_apply_move`가 넘긴다)지만,
##  인지(N30)가 들어오면 **인자만** 상태가 정한 「보는 쪽」으로 갈아끼우면 된다(순찰/경계/추격이
##  `turn_rate`로 감속해 만든 방향). **부르는 자리를 늘리지 마라** — 그 순간 갈아끼울 자리가 둘이 된다.
##
## 🔴🔴 **`_visual`에만 건다 — 루트에 `scale.x = -1`을 걸지 마라.** 루트를 뒤집으면
##  그림자(`_shadow`)·돌풍 링(`_gale_ring`)이 **자식이라 같이 뒤집히고**, `Collision`까지 좌우가
##  바뀌어 **판정이 에러 0으로 어긋난다**(셋 다 `_visual`의 형제다). 그물 = `test_enemy_facing_auto [4]`.
##  ⚠ 돌진 예고(`_charge_band`)는 **씬 소유**라 어느 쪽이든 안 따라오지만, 그건 우연이 아니라
##   `_show_charge_band` 머리말의 계약이다 — 반전을 이유로 그 소유를 되돌리지 마라.
##
## 🔴🔴 **부호는 원본 시트가 어느 쪽을 보나가 정한다.** `hound.png`·`hound_alpha.png` 첫 프레임을
##  8배로 확대해 확인했다 — **둘 다 머리가 오른쪽**이다(늑대는 빨간 눈·귀가 오른쪽, 우두머리는
##  벌린 주둥이·이빨이 오른쪽 · 꼬리는 둘 다 왼쪽). ⇒ `flip_h = false`가 **오른쪽**이고,
##  플레이어(`player.gd _apply_anim`)와 **부호가 같다.**
##
## 🔴🔴 **세104에 이 상수가 한 번 반대로 들어갔다 — 그 경위를 남긴다(같은 실수가 쉽다).**
##  초안은 *"둘 다 머리가 왼쪽"*이라 적고 `true`를 넣었다. 그 결과 **늑대가 늘 뒷걸음질로 달렸는데
##  전 스위트가 45/45 그린이었다** — 그물의 기대치를 **같은 오독 위에** 세웠기 때문이다
##  (memory `takbon-verify-tools-can-lie` — 「그물이 틀린 것을 굳힌다」의 교과서적 사례).
##  🔴 **잡은 것은 헤드리스가 아니라 실게임 스샷이다.** 플레이어 좌우에 늑대를 놓고 쫓게 해
##  찍은 뒤 파이썬으로 확대해 보니 둘 다 가는 쪽의 **반대**를 보고 있었다.
##
## 🔴🔴 **그래서 이 상수는 이제 그물이 PNG를 열어 픽셀로 검산한다** — `test_enemy_facing_auto [7]`.
##  ⇒ **아트가 시트를 좌우 반대로 다시 그리는 날 그 줄이 빨개진다.** 사람의 눈이 유일한 근거인
##   상태로 두지 않는다(그게 이번 사고의 뿌리였다).
##
## ⚠ **지표를 셋 시도해 셋째만 섰다 — 앞의 둘로 되돌리지 마라**(둘 다 실측으로 실패했다):
##   ⓐ 불투명 픽셀 **무게중심**: `hound`가 **−1.8**(왼쪽)로 나온다. 달리는 자세라 뒷다리·꼬리
##     면적이 커서 머리와 **반대로** 끌린다. **부호가 틀린 지표다.**
##   ⓑ **상단 25% 띠 중심**(「머리는 위에 있다」): `hound`는 +17.6으로 잘 서는데 `hound_alpha`가
##     **−0.6**이다. 등이 넓고 고개를 숙인 자세라 상단이 등으로 채워진다. **종마다 안 선다.**
##   ⓒ ⭕ **가장 붉은 화소의 x**(= 얼굴): 몸은 갈색·검정 저채도인데 **얼굴만 붉다**. `hound` **+22.0** ·
##     `hound_alpha` **+20.0**(둘 다 최붉은 화소가 정확히 `CF573C` — 눈·벌린 주둥이) · 16프레임 부호 일치.
##   ⇒ 자세는 종마다 다르지만 **「얼굴만 붉다」는 자세와 무관**하다. 그게 ⓐⓑ와 갈린 이유다.
##
## 🔴🔴 **단, ⓒ도 「전 종에 서는 지표」는 아니다 — 그래서 그물이 목록을 안 박고 「서는지」를 재서
##  파생시킨다**: `slime_elite` +0.0 · `gale` +0.5(부호도 갈린다)라 **스스로 빠진다.**
##  ✅ **그게 맞다 — 지표가 서는 몸과 반전이 뜻을 갖는 몸이 정확히 일치한다**: 구슬·블롭은 얼굴이
##  없어 반전이 화면상 무변화고, 뱀은 회전 몸이라 애초에 반전 대상이 아니다(`_uses_rotation_facing`).
##  ⇒ **지표가 못 서는 몸은 지킬 방향 계약도 없다.** 지표가 통째로 무너지면 그물의 `judged >= 2`가
##  빨개져 **「지표를 다시 골라라」를 사람에게 알린다**(자명 통과로 조용히 죽지 않는다).
## ⚠ 그래도 **최종 판단은 사람이다** — 그물이 빨개지면 시트를 확대해 보고, 방향이 실제로 바뀌었으면
##  이 상수를, 몸통에 붉은 것이 생겨 지표가 흔들린 것이면 **그물의 지표를** 고쳐라.
## ⚠ 앞으로 올 시트가 왼쪽을 보면 이 상수를 몸마다 가르지 말고 **시트를 뒤집어 그려라** —
##   부호가 몸마다 갈리면 읽는 자리가 둘이 되고, 그게 이 리포가 반복해 밟은 T5다.
const SPRITE_FACES_LEFT := false

## 🔴 반전 데드존 — 거의 수직으로만 볼 때 `x`가 0 근처에서 떨려 스프라이트가 **파르르 뒤집히는**
##  것을 막는다(플레이어 `AIM_FLIP_DEADZONE`과 **같은 수법이자 이제 같은 단위**다).
##  **연출값이라 balance가 아니다.**
##
## 🔴🔴 **세105에 단위가 px/s → 「정규화 벡터의 x 성분」으로 바뀌었다 — 짝을 갈라 두면 조용히 죽는다.**
##  세104 판의 입력은 `velocity`(px/s)였고 문턱이 12.0이었다. 세105에 입력이 **`_look_dir`(단위
##  벡터)**로 바뀌었으므로 12.0을 그대로 두면 `absf(x) <= 12`가 **항상 참**이 되어
##  **반전이 통째로 죽는데 에러가 0이다**(늑대가 영원히 오른쪽만 본다).
##  ⇒ 입력을 다시 바꾸는 사람은 **이 상수도 같이** 바꿔야 한다. 지금 값 0.15는 ±8.6°다.
## ⚠ 반대로 되돌리는 것도 같은 함정이다 — 정규화 벡터에 px/s 문턱을 쓰면 위처럼 죽고,
##  속도에 비율 문턱을 쓰면 **거의 멈춘 몸의 미세 속도**가 문턱을 넘어 멈춘 적이 뒤집힌다.
## 🔴 **돌진 윈드업은 이 값에 안 얹혀 있다** — 윈드업 동안 `_desired_look()`이 `_charge_dir`을
##  **고정으로** 돌려주므로 고개가 안 돈다. 설계 §4의 *"윈드업 동안 보는 쪽을 고정"*이 그 자리다.
const FACING_FLIP_DEADZONE := 0.15

func _update_facing(dir: Vector2) -> void:
	if _visual == null or _uses_rotation_facing():
		return
	if absf(dir.x) <= FACING_FLIP_DEADZONE:
		return   # 🔴 데드존 = 「안 바꾼다」 — 마지막 방향을 그대로 둔다(멈추면 보던 쪽에 굳는다)
	_visual.flip_h = (dir.x < 0.0) != SPRITE_FACES_LEFT


## 🔴 **회전으로 방향을 내는 몸** — 지금은 뱀 보스뿐이다(`_face`가 `_visual.rotation`을 돌린다).
##  거기에 `flip_h`를 겹치면 **회전된 스프라이트를 로컬 x축으로 거울질**해서 머리가 진행 방향의
##  **정반대**(θ → θ+180°)를 가리킨다. 설계 §4-b의 *"`_face`를 재사용하지 마라 — 늑대가 눕는다"*와
##  **같은 사실의 뒷면**이다: 회전과 반전은 한 몸에서 같이 못 산다.
## ⚠ **판별이 「보스면 제외」가 아니다** — `gale`·`slime_elite`는 회전을 안 쓰므로 **반전한다**
##  (둘 다 좌우 대칭 스프라이트라 지금 화면상 변화는 없다. 실측 확인함). 기준을 「보스」로 적으면
##  앞으로 올 **비대칭 보스가 조용히 굳는다.**
func _uses_rotation_facing() -> bool:
	return _ai == "boss_snake"


## 🔴 공개 관측점 — 지금 몸이 향한 쪽(-1 왼쪽 · +1 오른쪽 · 0 = 몸이 없다). `hp()`·`is_seen()` 선례.
## ⚠ **`flip_h`에서 되읽는다 — 내부 변수를 돌려주지 마라.** 되돌려 주면 대입이 통째로 죽어도 그물이
##  옳은 값을 봐서 **거짓 그린**이 된다(`hitbox_radius()`가 형상에서 읽는 이유와 같다 —
##  세85 「검증 도구가 거짓말한다」).
## ⚠ 회전으로 방향을 내는 몸(뱀)에겐 **뜻이 없다** — 그쪽은 `_visual.rotation`이 방향이다.
func facing_x() -> float:
	if _visual == null:
		return 0.0
	return -1.0 if (_visual.flip_h != SPRITE_FACES_LEFT) else 1.0


# ══ 인지 엔진 (세105 N30) ══════════════════════════════════════════════════════


## 🔴 「보는 거리」의 **단일 소스** — `sight_range`이고, 없으면 `aggro_range`를 승계한다(§7-b·§8-1).
## ⚠ 갈래별 폴백(`fallback`)은 **옛 코드 그대로**다. 여기서 한 값으로 합치면 그게 특정 `.tres`의
##  사본이 되어 데이터 죽음을 가려 준다(세84 `_param_req`의 교훈).
func _sight_range(fallback: float) -> float:
	if _def != null and _def.params.has(SIGHT_KEY):
		return float(_def.params[SIGHT_KEY])
	return _param(SIGHT_KEY_LEGACY, fallback)


## 🔴 **필수 수치판** (`_ai_chase` 전용 — 세84 계약). 둘 다 없으면 0을 돌려주고 **한 번 경고한다**
##  = 적이 굳는다(눈에 보인다). 경고 문구는 **새 이름**으로 낸다 — 지금의 정본 키가 그것이다.
func _sight_range_req() -> float:
	if _def != null:
		if _def.params.has(SIGHT_KEY):
			return float(_def.params[SIGHT_KEY])
		if _def.params.has(SIGHT_KEY_LEGACY):
			return float(_def.params[SIGHT_KEY_LEGACY])
	return _param_req(SIGHT_KEY)


## 🔴🔴 **이 몸에 인지 개념이 있나.** 「보는 거리」가 0이면(키가 아예 없는 그물 주입 몸) 인지가
##  갈래를 **한 톨도 안 건드린다** — §7-b의 *"키가 없으면 정확히 옛 동작"*이 여기서 실현된다.
## ⚠ 이 가드가 없으면 그런 몸이 영영 PATROL이라 `_apply_percept_velocity`가 속도를 0으로 덮어
##  **모든 주입 몸이 통째로 굳는다**(설계 C3가 경고한 그 사고).
func _percept_active() -> bool:
	return _sight_range(0.0) > 0.0


## 🔴 지금 이 몸이 공격 사이클에 **들어가도 되나** — 인지가 바꾸는 둘째 축(설계 §2-b 표).
func _percept_allows_attack() -> bool:
	return not _percept_active() or _percept == Percept.CHASE


## 🔴🔴 **감지 셋을 한 함수로** (설계 §3): 부채꼴(멀리 본다) ∪ 근접 원(등 뒤도 코앞이면 들킨다).
##  소리는 시간축이 달라 `_on_cast_heard`가 따로 진다.
##
## 🔴 **부채꼴 수학은 `src/core/vision.gd`를 그대로 부른다** — 「내 부채꼴」과 「적 부채꼴」은
##  **완전히 같은 수학**이라 각자 짜면 T5(파생 대신 복제)를 새로 심는다.
## ⚠ **수치는 반드시 인자로 넘겨라**(그 파일 머리말) — static 함수 안에서 데이터를 읽게 「정리」하면
##  컴파일 타임에 굳어 그물의 뮤테이션이 **아무 효과도 못 내면서 초록**이 된다.
## ⚠ `sight_angle` 폴백 360°는 「부채꼴이 무의미 = 늘 본다」 = 옛 동작이다 — 그 처리는 이제
##  `vision.gd`의 전방위 가드가 진다(아래).
##
## ⚠ **「360° = 주변시로 승격」 우회는 세105에 걷었고 세107에도 그대로 걷혀 있다** — 되살리지 마라.
##  그전 두 줄은 `angle >= 360.0`일 때 `sense = maxf(sense, r)`로 **감지 거리 전체를 주변시로 올려**
##  float32 경계(정확히 등 뒤에서 `angle_to`가 π보다 크게 나오는 것)를 피했는데,
##  **`vision.gd`에 `if fan_deg >= 360.0` 가드가 들어와 통째로 중복이다**(세105 `1cb4b8b`).
##  ⚠ 걷은 둘째 이유(*"주변시가 차폐 면제라 우회가 남으면 나무를 무시한다"*)는 **세107 차폐 은퇴로
##   사라졌다** — 지금 이 자리를 떠받치는 건 「중복이다」 하나뿐이다.
##
## 🔴 **호출 자리가 이 파일에 둘이다** — 여기(적이 나를 보나)와 `_judge_seen`(내가 적을 보나).
##  같은 수학을 두 벌로 만들지 마라(T5) — 한쪽만 고치면 「내가 보는 것 ≠ 짐승이 보는 것」이 된다.
func _detects(player: Node2D) -> bool:
	if player == null:
		return false
	var r := _sight_range(0.0)
	if r <= 0.0:
		return false
	var angle := _param("sight_angle", SIGHT_ANGLE_DEFAULT)
	var sense := _param("sense_radius", SENSE_RADIUS_DEFAULT)
	return Vision.is_seen(global_position, _look_dir, player.global_position,
		angle, r, sense)


## 🔴🔴 인지 상태기계 — 설계 §2의 흐름도를 그대로 옮긴 자리.
##
## 🔴 **한 박자(`alert_sec`)가 0이면 같은 틱 안에 CHASE까지 간다** — 그래야 인지 키가 없는 몸이
##  **한 프레임도 안 늦게** 옛 동작과 같아진다(그물 여럿이 `_await_band(e, 30)`처럼 프레임 예산으로
##  잰다). 상태를 「다음 틱에 넘긴다」로 짜면 그 예산이 조금씩 밀린다.
## 🔴 **`_last_seen`은 플레이어의 지금 자리가 아니라 「마지막으로 안 자리」다** — 쏘고 옮기면 흘린다.
func _update_percept(player: Node2D, delta: float) -> void:
	if not _percept_active():
		return
	var seen_now := _detects(player)
	if seen_now:
		_last_seen = player.global_position
	match _percept:
		Percept.PATROL:
			if seen_now:
				_enter_alert(player.global_position, false)
		Percept.ALERT:
			# 🔴 **눈으로 시작한 경계는 「벗어나면 없던 일」이다**(설계 ⓒ — 「아슬아슬하게 피했다」).
			#  ⚠ 소리로 시작한 경계엔 그 규칙을 쓰면 안 된다: 애초에 안 보이는 채로 들어와서
			#   **한 프레임에 취소된다**(소리가 통째로 무의미해진다).
			if not seen_now and not _alert_from_sound:
				_percept = Percept.PATROL
				return
			_percept_timer -= delta
			if _percept_timer <= 0.0:
				if seen_now:
					_enter_chase()
				else:
					_enter_search()   # 소리를 들었다 = 「그 자리에 가 본다」
		Percept.CHASE:
			if seen_now:
				_lose_timer = 0.0
			else:
				_lose_timer += delta
				if _lose_timer >= _param("lose_sec", LOSE_SEC_DEFAULT):
					_enter_search()
		Percept.SEARCH:
			if seen_now:
				_enter_chase()
				return
			_percept_timer -= delta
			if _percept_timer <= 0.0:
				_percept = Percept.PATROL


## 경계에 든다 — 🔴 **한 박자가 0이면 여기서 곧장 다음 상태로 흘린다**(위 머리말).
##  눈이면 CHASE(옛 동작) · 소리면 SEARCH(가 본다)로 갈린다.
func _enter_alert(focus: Vector2, from_sound: bool) -> void:
	_last_seen = focus
	_alert_from_sound = from_sound
	if _param("alert_sec", ALERT_SEC_DEFAULT) <= 0.0:
		if from_sound:
			_enter_search()
		else:
			_enter_chase()
		return
	_percept = Percept.ALERT
	_percept_timer = _param("alert_sec", ALERT_SEC_DEFAULT)
	# 🔴 **ⓓ 경계에도 작은 소리** — 시야 밖 적은 몸이 안 보여 **소리가 유일한 통보**다(설계 ⓓ).
	_play_percept_sfx("alert_sfx")


## 추격에 든다 — 🔴 **짖는다**(설계 ⓒ). 이 발신이 곧 다음 조각(무리)의 **전파 통로**가 된다.
func _enter_chase() -> void:
	if _percept == Percept.CHASE:
		return
	_percept = Percept.CHASE
	_lose_timer = 0.0
	_alert_from_sound = false
	_play_percept_sfx("chase_sfx")


## 수색에 든다 — 마지막으로 안 자리로 가 본다. 🔴 **`search_sec`이 0이면 아예 안 든다**(옛 동작).
##  SEARCH가 「따돌렸다」를 만든다: 즉시 복귀면 도망이 너무 쉽고, 안 놓치면 세88의 그 고장
##  (*"전부 남쪽 입구로 모인다"*)이 돌아온다.
func _enter_search() -> void:
	_alert_from_sound = false
	var sec := _param("search_sec", SEARCH_SEC_DEFAULT)
	if sec <= 0.0:
		_percept = Percept.PATROL
		return
	_percept = Percept.SEARCH
	_percept_timer = sec


## 🔴🔴 **마법 소리 = 위력**(설계 §5 · 사용자 확정 ⓔ). 조립이 **전투 밖(잠입)까지** 의미를 갖는다:
##  *「한 방에 잡고 조용히」* 대 *「다 불러내고 광역으로」*가 **조립 단계의 선택**이 된다.
##
## 🔴🔴 **반경은 `RingPower.quality_t()`를 지난다 — raw `score`를 쓰지 마라**(설계 C4).
##  조립 점수의 실사용 범위가 `assemble_score_base`(0.70)~1.0이라 raw면 맨 진↔퍼펙트가 **1.43배**뿐이고
##  「조용히 한 방」 대 「숲을 깨운다」가 성립하지 않는다. 지금 반경비는 240→700 = **2.92배**다.
## 🔴 **`get("score", 기준선)` 가드가 필수다** — `test_audio_auto`가 `ring_cast_requested.emit({}, …)`로
##  **빈 사전**을 쏜다. 가드가 없으면 SCRIPT ERROR가 나는데 **`-s` 테스트는 그래도 「OK」를 찍는다.**
##  기준선은 `quality_t`가 0을 돌려주는 **맨 진 점수**다(= 가장 조용한 쪽으로 안전하게 무너진다).
## ⚠ 이미 알아챈 적은 무시한다 — 쫓는 중에 소리를 또 들었다고 상태를 되감으면 추격이 리셋된다.
func _on_cast_heard(assembly: Dictionary, origin: Vector2, _aim_dir: Vector2) -> void:
	if _dead or not _percept_active():
		return
	if _percept == Percept.CHASE or _percept == Percept.ALERT:
		return
	var score := float(assembly.get("score", RingPower.assembled_score(0, 1)))
	var radius: float = lerpf(BAL.percept_sound_radius_min_px, BAL.percept_sound_radius_max_px,
		RingPower.quality_t(score))
	if global_position.distance_to(origin) > radius:
		return
	# 🔴 **발사 지점**을 향해 든다 — 플레이어의 지금 위치가 아니다(쏘고 옮기면 흘린다).
	_enter_alert(origin, true)


## 🔴🔴 **인지가 「속도 목표」를 덮는다 — 갈래 호출은 안 끊는다**(설계 §2-b · `_physics_process` 참조).
##
## 🔴 **돌진 사이클이 이미 출발했으면 안 덮는다.** 윈드업/돌진/회복 중에 시야를 잃었다고 속도를
##  갈아 끼우면 **이미 시작한 돌진이 소리 없이 증발한다**(바닥엔 붉은 띠가 떠 있는데 몸이 안 온다
##  = 예고가 거짓말한다 — `_charge_reach_length` 머리말이 막으려는 바로 그 사고).
func _apply_percept_velocity(delta: float) -> void:
	if not _percept_active() or _percept == Percept.CHASE:
		return
	if _ai == "charge" and _charge_state != ChargeState.APPROACH:
		return
	match _percept:
		Percept.ALERT:
			velocity = Vector2.ZERO   # 멈춰 이쪽을 본다 (설계 §2)
		Percept.SEARCH:
			velocity = _search_velocity()
		_:
			velocity = _patrol_velocity(delta)


## 🔴 배회 = **자기 자리 둘레를 도는 궤도**. 「보는 쪽 = 이동 방향」이라 궤도가 곧 **고개가 천천히
##  도는 것**이 된다(설계 ⓑ — 틈이 열릴 때까지 기다렸다 지나간다).
##
## 🔴🔴 **물리로 풀지 마라 — 값으로 푼다**(설계 §8-5 · M10). 배회를 켜는 순간 늑대가 **나무를
##  관통하고 서로를 통과하는 것**이 처음으로 상시 화면에 나온다(적 mask는 1(world)인데 방 안에
##  layer 1 물체가 **하나도 없다** — 프롭 `collision_layer = 0` 계약).
##   ⓐ **`patrol_radius ≤ PROP_CLEAR_SPAWN`(=100px)** — 프롭이 스폰 둘레 100px을 비우므로 그 안이면
##     나무를 안 만난다. ⚠ 이 상한을 넘기면 늑대가 나무를 뚫는다(`data/enemies` 쪽 계약이다).
##   ⓑ **자리마다 위상이 다르다**(`_patrol_phase`) — 같으면 둥지 둘레 다섯이 **한 몸처럼 겹친다.**
## ⚠ 각속도를 `speed / radius`로 낸다 — 반경을 조여도 **걷는 빠르기**가 안 변한다(둘을 따로 적으면
##  반경을 만질 때마다 체감 속도가 같이 흔들린다).
func _patrol_velocity(delta: float) -> Vector2:
	var radius := _param("patrol_radius", PATROL_RADIUS_DEFAULT)
	var speed := _param("patrol_speed", PATROL_SPEED_DEFAULT)
	if radius <= 0.0 or speed <= 0.0:
		return Vector2.ZERO
	_patrol_t += delta * speed / radius
	var target := _home + Vector2.RIGHT.rotated(_patrol_phase + _patrol_t) * radius
	var to := target - global_position
	if to.length() <= PATROL_ARRIVE_PX:
		return Vector2.ZERO
	return to.normalized() * speed


## 마지막으로 안 자리로 걸어가 본다 — 닿으면 그 자리에서 두리번거린다(속도 0 · 고개는 계속 돈다).
func _search_velocity() -> Vector2:
	var to := _last_seen - global_position
	if to.length() <= SEARCH_ARRIVE_PX:
		return Vector2.ZERO
	return to.normalized() * _param("move_speed", 0.0)


## 🔴🔴 배회 중심을 **첫 물리 틱에** 잡는다 (설계 §9-b · M6 — `_home` 머리말이 근거를 든다).
## 🔴 위상을 **좌표에서** 뽑는다: 스폰 순서는 방 씬을 재편하면 바뀌지만 자리는 안 바뀐다.
##  계수 둘은 서로소에 가까운 무리한 값이면 무엇이든 된다 — 재는 것은 「위상이 서로 다른가」뿐이다.
func _capture_home() -> void:
	if _home_set:
		return
	_home_set = true
	_home = global_position
	_patrol_phase = fposmod(_home.x * 0.0173 + _home.y * 0.0119, TAU)


## 🔴🔴 **「보는 쪽」을 이번 틱만큼 굴린다** (설계 §4).
##
## 🔴 **`turn_rate`가 없으면 이 설계가 통째로 성립하지 않는다** — 적이 즉시 뒤를 돌아보면
##  「돌아가기」가 아무 뜻도 없어진다. 그래서 폴백 0(=무제한)은 **옛 동작을 위한 것**이지
##  기본 설계가 아니다.
## ⚠ 회전으로 방향을 내는 몸(뱀)은 `_face`가 `_visual.rotation`을 쥔다 — 여기서 손대면 두 축이 싸운다.
func _update_look(delta: float) -> void:
	if _uses_rotation_facing():
		return
	var want := _desired_look()
	if want.length_squared() < 0.0001:
		return   # 목표가 없다 = 마지막 방향을 그대로 둔다(멈추면 보던 쪽에 굳는다)
	want = want.normalized()
	var rate := _param("turn_rate", TURN_RATE_DEFAULT)
	if rate <= 0.0:
		_look_dir = want
		return
	var step := deg_to_rad(rate) * delta
	_look_dir = _look_dir.rotated(clampf(_look_dir.angle_to(want), -step, step)).normalized()


## 이번 틱에 **보고 싶은** 쪽. 실제로 그만큼 도는지는 `turn_rate`가 정한다.
## 🔴 **윈드업·돌진 동안은 락 방향에 고정한다**(설계 §4) — 고개가 계속 돌면 방향 락이 거짓말이 된다.
##  ⚠ 이건 `turn_rate`를 **건너뛴다**: 락은 「이미 정해진 것」이라 회전 속도의 대상이 아니다.
## 🔴 경계·수색은 **마지막으로 안 자리**를 본다(멈춰서도 고개는 그쪽이다 — 설계 §2 *"멈춰 이쪽을 본다"*).
func _desired_look() -> Vector2:
	if _ai == "charge" and _charge_dir.length_squared() > 0.0001 \
			and (_charge_state == ChargeState.WINDUP or _charge_state == ChargeState.CHARGE):
		return _charge_dir
	if _percept == Percept.ALERT or _percept == Percept.SEARCH:
		var to := _last_seen - global_position
		if to.length_squared() > 1.0:
			return to
		return Vector2.ZERO
	return velocity


## 🔴 경계·발견 소리 — **id도 `.tres`가 쥔다**(`params.alert_sfx`·`params.chase_sfx`).
##  ⚠ 키가 없으면 **아무 소리도 안 난다**: 보스 셋은 인지 키를 안 받으므로(§8-2) 늑대 짖는 소리를
##   내면 안 되고, 그물 주입 몸도 조용해야 한다. 「새 적 = .tres 한 장」이 소리까지 덮는다.
## 🔴 **`bus = &"SFX"`는 부르는 쪽 의무다**(`Audio.stream_of` 머리말) — 안 걸면 볼륨을 버스로
##  가르는 날 늑대 소리만 안 따라온다.
## ⚠ `stream_of`는 없는 id에 **null**을 준다 — 확인이 계약이다(소리가 없다고 게임이 멎으면 안 된다).
func _play_percept_sfx(key: String) -> void:
	var id := str(_def.params.get(key, "")) if _def != null else ""
	if id == "":
		return
	var audio := get_node_or_null(^"/root/Audio")
	if audio == null or not audio.has_method(&"stream_of"):
		return
	var stream: AudioStream = audio.call(&"stream_of", StringName(id))
	if stream == null:
		return
	if _percept_sfx == null:
		_percept_sfx = AudioStreamPlayer2D.new()
		_percept_sfx.bus = &"SFX"
		add_child(_percept_sfx)
	_percept_sfx.stream = stream
	_percept_sfx.play()


## 🔴 공개 관측점 — 지금 인지 상태(`Percept` 값). `hp()`·`is_seen()`·`facing_x()` 선례.
## ⚠ **내부 필드를 그대로 돌려주는 게 맞다** — 이 값 자체가 상태기계의 진실원이고, 되계산하면
##  그물이 상태기계를 안 지나는 사본을 보게 된다(세85 「검증 도구가 거짓말한다」).
func percept_state() -> int:
	return _percept


## 🔴 공개 관측점 — 지금 이 몸이 보고 있는 쪽(단위 벡터). 부채꼴 판정이 쓰는 **그 값**이다.
## ⚠ `facing_x()`는 **그림**(`flip_h`)을 되읽고 이건 **판정**을 돌려준다 — 둘은 일부러 다른 문이다
##  (좌우 반전은 데드존 때문에 판정보다 굵게 움직인다).
func look_dir() -> Vector2:
	return _look_dir


## 🔴 공개 관측점 — 배회 중심(스폰 자리). 「`_ready`가 아니라 첫 물리 틱」 계약(§9-b)의 유일한
##  측정 가능한 형태다. 아직 안 잡혔으면 지금 자리를 돌려준다.
func patrol_home() -> Vector2:
	return _home if _home_set else global_position


## 🔴🔴 **돌진이 닿는 자리 — 판정과 그림이 여기 한 곳에서 나온다** (세99).
##
## 왜 함수인가: 예고 범위를 **그리는 쪽이 값을 베끼면** 한쪽만 조였을 때 *"보이는 곳 밖에서 맞는다"*가
## 된다 — 그건 예고가 **없는 것보다 나쁘다**(설계 §5-D-3 · 감사 T5, 세23 *"리포트는 140 적고 130으로
## 때린다"*와 같은 결). 그래서 **때리는 쪽(`_contact`)과 그리는 쪽(`_update_charge_band`)이 같은
## 함수를 부른다.** 폴백까지 const로 뽑은 것도 같은 이유다 — 리터럴을 두 자리에 적으면 데이터가
## 빠졌을 때 **그림과 판정이 서로 다른 기본값**으로 갈라진다(에러 0).
##
## 기하: 돌진 중 판정은 `_contact`가 **중심 거리 ≤ attack_range** 하나로 재고, 몸은 락 방향으로
## `charge_speed × dash_sec`만큼 미끄러진다 ⇒ **닿는 자리 = 그 선분을 반경 attack_range로 부풀린 캡슐.**
## ⚠ 이 캡슐은 「쓸고 갈 자리」의 상계다 — `attack_cooldown`(1.0s)이 남아 있으면 그중 한 번만 든다.
##  **좁게 그리는 쪽으로는 틀리지 않는다**(예고가 거짓말하는 방향은 그 반대다).
const ATTACK_RANGE_FALLBACK := 18.0    ## 데이터에 attack_range가 없을 때 (판정·그림 공용)
const CHARGE_SPEED_FALLBACK := 330.0   ## 〃 charge_speed
const DASH_SEC_FALLBACK := 0.4         ## 〃 dash_sec

func _contact_radius() -> float:
	return _param("attack_range", ATTACK_RANGE_FALLBACK)


func _charge_reach_length() -> float:
	return _param("charge_speed", CHARGE_SPEED_FALLBACK) * _param("dash_sec", DASH_SEC_FALLBACK)


## 접촉 피해 — attack_range 안이면 attack_cooldown 간격으로 GameState를 깎는다.
## 🔴 구르는 중이면 흘린다 (무적 프레임 — 세션41 구르기). player.is_rolling()가 유일 판정.
## .call로 부른다: player는 Node2D 타입이라 is_rolling()을 정적으로 못 찾는다(공용 배우 계약 무변경).
func _contact(player: Node2D, dist: float) -> void:
	if dist > _contact_radius() or _cool > 0.0:
		return
	_cool = _param("attack_cooldown", 0.9)
	var dodging: bool = player.has_method(&"is_rolling") and bool(player.call(&"is_rolling"))
	if not dodging:
		# 🔴 source_pos(세63) = 내 위치 — player_hurt에 실려 방향성 카메라 킥이 쓴다.
		GameState.damage_player(_param("contact_damage", 4.0), global_position)


## 🔴 재생 — `regen_per_sec > 0`이면 초당 회복(상한 = `_def.hp`). 죽은 뒤(_hp<=0)엔 회복 안 한다.
## "빨리 몰아쳐 죽여야 하는" 표적을 만든다 (덩굴). 대부분 적은 regen_per_sec가 없어 no-op.
func _regen(delta: float) -> void:
	if _def == null or _hp <= 0.0:
		return
	var rps := _param("regen_per_sec", 0.0)
	if rps <= 0.0:
		return
	_hp = minf(_def.hp, _hp + rps * delta)


# ── 상태이상 (세션49) ─────────────────────────────────────────────────────────
# 🔴 **규칙은 전부 `SR`(src/core/status_rules.gd)이 쥔다.** 여기 있는 건 "보유하고 시간을 돌리는"
# 일뿐이다 — 어떤 조합이 무엇이 되는지·얼마나 가는지·얼마나 느려지는지를 이 파일에서 판단하지 마라.


## holder의 콜백을 이 몸에 잇는다 (`_ready`에서 한 번). 🔴 **콜백 경계**가 추출의 핵심이다 —
## holder는 규칙과 시간만 알고, hp를 깎고 씬을 뒤지고 색을 칠하는 건 전부 여기(몸)다.
func _wire_status() -> void:
	_status.on_dot = func(amount: float) -> void:
		# 🔴 DoT는 `EventBus.enemy_hit`을 **안 쏜다** — 그 시그널은 "최종 피해" 계약이라
		# 피해 숫자·히트스톱·피격음이 물려 있다(세38·46). 0.5초마다 쏘면 화면이 숫자로
		# 도배되고 히트스톱에 갇힌다. DoT는 조용히 hp만 깎고 표현은 틴트가 맡는다.
		_hp -= amount
		if _hp <= 0.0:
			_die()
	_status.on_burst = func(radius: float, amount: float, include_self: bool, result_status: int, rune: int) -> void:
		_burst_damage(radius, amount, include_self, result_status, rune)
	_status.on_spread = func(statuses: Dictionary) -> void:
		_spread_statuses(statuses)
	_status.on_changed = _refresh_tint


## ⚠ **여기 `_exit_tree`로 콜백을 끊지 마라** (세50에 넣었다가 리뷰에서 걷어냈다).
## 끊을 순환이 없다: Callable은 대상이 RefCounted일 때만 강참조를 잡는데 소유자는 **Node**라
## ObjectID만 쥔다 — node→holder(강) / holder→node(약)로 이미 비순환이고, node가 free되면
## 멤버 holder도 같이 죽는다. 반대로 끊어 두면 **`_wire_status`가 `_ready`에만 있어서**
## 노드를 뺐다 다시 넣는 순간(리페어런팅·풀링) 콜백이 영구히 죽고 **적이 상태를 하나도 안 받는데
## 에러가 안 난다** — 이 프로젝트가 제일 무서워하는 침묵을 없는 문제를 막으려다 새로 심는 셈이다.
##
## ⚠ **세99에 이 파일에 `_exit_tree`가 생겼는데 모순이 아니다** — 가르는 기준은
##  **「나갔다 들어오면 스스로 되살아나나」**다. 그쪽이 지우는 건 **한 판짜리 연출 노드**(돌진 예고)라
##  다음 윈드업에 다시 만들어지고, 안 지우면 **주인 없는 채로 씬에 남는다.** 여기 콜백은 반대로
##  `_ready`에만 배선돼 되살아날 길이 없다. **「연출은 지운다 · 배선은 안 끊는다」**로 읽어라.


## 반경 안의 다른 적들(그룹 "enemies")에게 즉발 피해. `include_self`면 자신도 맞는다(증기).
## 🔴 `take_hit`이 아니라 `take_reaction_damage`로 때린다 — take_hit을 부르면 상태 판정이 다시
## 돌아 **연쇄가 연쇄를 낳는다**(무한 재귀). 반응 피해는 피해일 뿐 새 상태를 안 만든다.
## rune = 이 버스트의 정체 룬(세56) — 자신·연쇄 대상 모두 take_reaction_damage에 그대로 넘긴다.
func _burst_damage(radius: float, amount: float, include_self: bool, result_status: int, rune: int) -> void:
	# 🔴 VFX 방송 (세52) — 터진 자리·**게임 반경**·결과 상태(증기=NONE·감전=SHOCK). 링이 반경을
	# 폭로하므로 amount 가드 **앞에** 둔다(반응은 일어났으니 링은 늘 뜬다). 피해 계산은 안 바뀐다.
	EventBus.reaction_burst.emit(global_position, radius, result_status)
	if amount <= 0.0:
		return
	if include_self:
		take_reaction_damage(amount, rune)
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not (node is Node2D):
			continue
		if (node as Node2D).global_position.distance_to(global_position) > radius:
			continue
		if node.has_method(&"take_reaction_damage"):
			# 🔴 감전(SHOCK)만 대상마다 번개 아크 — 증기(NONE)는 링만(설계 §4). 피해 전에 쏜다.
			if result_status == Enums.Status.SHOCK:
				EventBus.reaction_chain.emit(global_position, (node as Node2D).global_position, result_status)
			node.take_reaction_damage(amount, rune)


## 🔴 바람 확산 — **내게 이미 붙은 상태를** 반경 안의 적들에게 옮겨 붙인다.
## 내 것은 남긴다(옮기는 게 아니라 번진다) — 안 그러면 바람을 섞을수록 판이 깨끗해진다.
## 🔴 옆 적을 찾는 건 **몸의 일**이라 여기 남았다(holder는 씬을 모른다).
func _spread_statuses(statuses: Dictionary) -> void:
	if statuses.is_empty():
		return
	# 🔴 VFX (세52) — 여러 상태를 옮겨도 아크는 **한 대상에 한 가닥**. 색은 대표 상태(가장 최근).
	# 대표 상태는 holder 공개 API로 얻는다(세52 리뷰) — 몸이 내부 dict의 ["seq"]를 더듬지 않는다.
	var rep := _status.representative()
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not (node is Node2D):
			continue
		if (node as Node2D).global_position.distance_to(global_position) > BAL.status_spread_px:
			continue
		if not node.has_method(&"apply_status"):
			continue
		EventBus.reaction_chain.emit(global_position, (node as Node2D).global_position, rep)
		for key: int in statuses.keys():
			node.apply_status(key, float(statuses[key]["power"]))


## 🔴 공개 — 확산이 옆 적에게 상태를 옮길 때 쓰는 유일 경로(내부 필드를 남이 더듬지 않게).
## 테스트도 이걸로 상태를 세운다. ⚠ 시그니처는 세션49 그대로다 — 공개 계약이라 안 넓혔다.
func apply_status(status: int, power: float) -> void:
	if _dead:
		return
	_status.add(status, power)


## 🔴 공개 관측점 — 헤드리스가 상태를 **공개 API로만** 확인하게 (takbon-verify §3, `hp()` 선례).
func has_status(status: int) -> bool:
	return _status.has(status)


func status_power_of(status: int) -> float:
	return _status.power_of(status)


## 🔴 반응 피해 — 조용히 hp만 깎는 DoT와 달리 **한 번뿐인 사건**이라 `enemy_hit`을 쏴 손맛을 준다
## (연쇄가 눈에 보여야 조합할 이유가 생긴다). 상태를 안 만들어 재귀가 없다.
## 🔴 rune(세56) = 이 반응의 정체 룬(감전=BOLT·증기=WATER) — enemy_hit에 그대로 실어야 소리가
## 반응과 맞는다(그전엔 FIRE 하드코딩이라 감전 연쇄가 불 소리를 냈다). 기본 인자 = 하위호환.
func take_reaction_damage(amount: float, rune: int = Enums.RuneType.FIRE) -> void:
	if _dead or amount <= 0.0:
		return
	_hp -= amount
	EventBus.enemy_hit.emit(self, amount, rune)
	_pop()
	_play_hurt()
	if _hp <= 0.0:
		_die()


## 지금 보여 줄 상태 색 — 고르는 규칙은 holder가 쥔다(적·허수아비가 같게 보이도록).
## 세63: 팝·텔레그래프가 셰이더로 옮겨가 "복귀 목표" 곡예가 소멸했다 — 이 색을 쓰는 곳은
## 이제 `_refresh_tint` 하나뿐이다.
func _status_tint() -> Color:
	return _status.tint()


## 🔴 modulate 소유권 계약 (세63 개편): modulate는 **rgb=상태 틴트 · a=분산** 두 축만 남았다.
## 팝(흰 섬광)·텔레그래프(붉음)는 셰이더 uniform(flash_amount·telegraph_amount)이 쥔다 —
## modulate를 만지는 코드는 이 함수와 `_set_dispersed`뿐이어야 한다(3파전으로 되돌리지 마라).
##
## 🔴🔴 **세99: rgb 축이 「몸 색조 × 상태 틴트」의 곱이 됐다 — 소유자는 여전히 이 함수 하나다.**
##  `_apply_look`이 `params.tint`를 **값으로만** 들고(대입은 여기서만) 계약이 안 깨진다.
##  🔴 곱셈이라 **순서가 없고 되돌릴 필요도 없다**: 몸 색조가 없으면 흰색(항등)이라 기존 적은
##  한 톨도 안 달라지고, 상태가 풀리면 `tint_of`가 흰색이라 몸 색조가 저절로 되돌아온다.
##  ⚠ 대입(`_base_tint`를 여기서 안 곱하고 `_apply_look`에서 modulate에 직접 쓰는 것)으로 바꾸면
##  **첫 상태이상 한 번에 몸 색조가 영영 지워진다**(에러 0) — 그게 이 곱셈의 존재 이유다.
##
## 🔴🔴 **세104: `a`도 파생이 됐다 — 두 함수가 같은 진실원(`_alpha_now`)을 본다.**
##  그전엔 이 줄이 `c.a = _visual.modulate.a`로 **화면에서 되읽고** 있었다. 그러면 알파 대입자와
##  이 함수가 **서로의 결과를 주고받는 왕복**이 되어 순서 의존·부동소수 드리프트가 들어온다.
##  이제 rgb·a **양쪽이 다 파생**이라 세63 계약이 *"두 함수가 같은 진실원을 본다"*로 강화됐다.
func _refresh_tint() -> void:
	if _visual == null:
		return
	var c := _status_tint() * _base_tint
	c.a = _alpha_now()
	_visual.modulate = c


## 🔴🔴 **알파의 유일한 진실원 — 「곱하는 자리를 하나로」** (세104 · `vision_design.md` §5-2).
##
## 알파 축에 주인이 둘이 됐다: **분산**(안개가 흩어지면 반투명)과 **시야**(안 보이는 적은 사라진다).
## 각자 `modulate.a`에 대입하면 세63 소유권 계약이 **3파전**이 되고 — 안개가 분산했다 풀리는 순간
## `a = 1.0`을 찍어 **시야 밖인데 다시 보인다**(에러 0 · 전 스위트 그린). 세63이 rgb에 쓴 수법
## (`_status_tint() * _base_tint`)을 알파에 그대로 옮겨 **곱셈 한 줄**로 합쳤다.
## ⇒ 축을 하나 더 얹고 싶으면 **여기 곱을 늘려라. `modulate.a`에 직접 대입하지 마라.**
func _alpha_now() -> float:
	return (DISPERSED_ALPHA if _dispersed else 1.0) * _vision_alpha


## 🔴 **`modulate.a`에 대입하는 유일한 함수** (위 `_alpha_now` 머리말). 축을 바꾼 쪽이 이걸 부른다.
##
## 🔴🔴 **알파를 거는 노드는 `_visual`과 그림자 둘이다 — 루트에 걸지 마라**(설계 V2).
##  *"루트에 걸면 그림자도 자식이니 공짜"*가 가장 자연스러운 손인데, 그 한 줄이
##  **돌풍 링(`_gale_ring`)을 같이 죽인다** — 링은 `_visual`의 **형제**(적의 자식)라서다.
##  설계 §3 표가 *"공격 예고는 시야 밖에서도 보인다"*를 계약으로 선언해 뒀으므로
##  **아무도 의심하지 않는다.** 그물 = `test_vision_auto`의 돌풍 링 항목(그 사고의 유일한 검출자).
## ⚠ 그림자 자신의 반투명은 **텍스처 그라디언트 안**에 있지 modulate에 없다(`shadow.gd`) — 충돌 없음.
##
## ⚠ **허수아비(`dummy_target.gd`)는 이 구조를 일부러 안 따라간다**: 분산도 시야도 없어 알파 축이
##  상수 1.0이다. 파리티 계약(세56 「두 몸」)은 **셰이더 플래시·틴트 rgb**에 대한 것이고
##  알파 축은 두 몸이 원래 다르다 — 파리티를 이유로 허수아비에 이 함수를 옮겨 심지 마라.
func _refresh_alpha() -> void:
	var a := _alpha_now()
	if _visual != null:
		_visual.modulate.a = a
	if _shadow != null and is_instance_valid(_shadow):
		_shadow.modulate.a = a


## 🔴🔴 **시야 — 「보이는 적」과 「기척만 남은 적」** (세104 N27 · 정본 `vision_design.md`).
##
## 플레이어가 보는 쪽(부채꼴)과 몸 둘레(주변시) **밖**에 있으면 몸과 그림자가 사라지고
## **공격 예고만 남는다** — 그게 「기척」이다(사용자 확정 ⓓ *"몬스터는 공격범위나 이런 기척만"*).
##
## 🔴🔴 **보이는 것만 바꾼다 — 전투는 한 톨도 안 바꾼다**(설계 V5, **의도다**):
##  알파 0인 적도 **맞고·때리고·밀린다.** 이걸 「버그」로 보고 충돌·접촉 피해를 끄는 순간
##  전투가 통째로 갈린다. 여기서 손대는 건 `modulate.a` 하나뿐인 이유가 그것이다.
##
## ⚠ **「그룹 `enemies`를 훑어 판정」하는 구현으로 되돌리지 마라**(설계 V11) — 마을 허수아비도
##  그 그룹이라 **연습장 표적 5개가 시야 밖에서 사라진다.** 지금 마을이 무사한 이유는
##  「이 코드가 `forest_enemy`에 살고 마을엔 그 인스턴스가 없다」는 것 하나다.
func _update_vision(player: Node2D, delta: float) -> void:
	_seen = _judge_seen(player)
	var target := 1.0 if _seen else VISION_HIDDEN_ALPHA
	if VISION_FADE_SEC <= 0.0:
		_vision_alpha = target
	else:
		_vision_alpha = move_toward(_vision_alpha, target, delta / VISION_FADE_SEC)
	_refresh_alpha()


## 🔴 **판정 불가면 「보인다」** (fail-open · 설계 §5-1 A4 — 취향이 아니라 계약이다).
##  *"알 수 없으니 숨긴다"*는 **안 보여야 할 이유가 없는 적을 지우는** 최악의 실패 형태고,
##  기존 그물 둘(`test_feel_auto` [3]·[10])이 `modulate == Color(1,1,1,1)` 완전 일치를 단언한다
##  — 그 리그의 플레이어는 `vision_dir()`이 없는 **맨몸 스텁**이라 이 경로로 산다.
## ⚠ **`player.get_node("Caster").aim()`으로 타고 들어가지 마라** — 그건 진짜 노드 경로 결합이고
##  takbon-rules §0 위반이다. 덕타이핑(`has_method` + `call`)만이 이 계약이다.
func _judge_seen(player: Node2D) -> bool:
	if _always_visible or player == null:
		return true
	if not player.has_method(&"vision_dir"):
		return true
	var aim: Vector2 = player.call(&"vision_dir")
	# 🔴 수치는 **밖에서 주입**한다 — `Vision`은 static이라 안에서 balance를 읽으면 컴파일 타임에
	#  굳어 그물의 뮤테이션이 무효가 된다(그 파일 머리말 · memory `godot-const-resource-folding`).
	# ⚠ **세107: 여기 있던 일곱째 인자(엄폐물)가 은퇴했다** — 나무·바위는 더는 시선을 안 끊는다.
	#  되살릴 땐 **`_detects`(호출 자리 둘 중 첫째)와 같이** 열어라(한쪽만 열면 반쪽만 돈다).
	return Vision.is_seen(player.global_position, aim, global_position,
		BAL.vision_fan_deg, BAL.vision_fan_range, BAL.vision_near_radius)


## 🔴 공개 관측점 — 지금 이 적이 플레이어 눈에 보이나 (`hp()`·`phase()`·`charge_band_visible()` 선례).
## 🔴🔴 **라이브도 이 문을 지난다**: `juice.gd`가 피해 숫자를 띄우기 전에 덕타이핑으로 이걸 묻는다
##  (안 보이는 적의 숫자가 뜨면 **위치와 체력이 통째로 샌다** — 그림자를 끄는 이유와 같은 사고).
##  ⇒ 그물과 화면이 **같은 함수**를 본다.
func is_seen() -> bool:
	return _seen


## 돌진 텔레그래프 — 윈드업 동안 붉게 달아오른다(모으는 중이 보인다 → 피할 수 있다).
## 세63 개편: modulate 대신 셰이더 `telegraph_amount` — 팝 uniform(flash_amount)과 갈라져 있어
## **윈드업 중에 맞아도 섬광이 텔레그래프를 지우는 사고가 없다**(단일 amount로 합치면 팝 트윈이
## 0으로 감쇠하며 텔레그래프까지 끄는 함정). 붉은색은 셰이더 기본 uniform(telegraph_color).
## ⚠ 연출값이다 — 사용자가 실게임에서 보고 조인다.
func _set_telegraph(on: bool) -> void:
	if _visual == null:
		return
	var mat := _visual.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter(&"telegraph_amount", TELEGRAPH_AMOUNT if on else 0.0)


## 분산 표시 — 분산 중엔 반투명(지금은 때리기 나쁨이 보인다). 경감 자체는 take_hit이 적용한다.
## 🔴 세104: **자기 축만 갱신하고 대입은 `_refresh_alpha`에 맡긴다**(3파전 방지 — 위 머리말).
func _set_dispersed(on: bool) -> void:
	_dispersed = on
	_refresh_alpha()


## 🔴 그룹 `"player"`가 유일한 조준 경로다 (player.gd가 `_ready`에서 넣는다).
## 빠지면 적이 **제자리에 굳는데 에러는 안 난다** — 세션 24·25의 침묵과 같은 종류다.
func _player() -> Node2D:
	var found := get_tree().get_first_node_in_group("player")
	return found as Node2D


func _param(key: String, fallback: float) -> float:
	if _def == null:
		return fallback
	return float(_def.params.get(key, fallback))


## 🔴 **필수 수치**용 (세84) — 코드에 밸런스 상수를 두지 않는다(탁본 규칙: 적 수치는 EnemyDef가 쥔다).
## `_param`의 fallback은 「없으면 중립」인 값(`regen_per_sec` 0.0·`armor_reduction` 0.0 등)에는 맞지만,
## 없으면 안 되는 값에 쓰면 **그 폴백이 특정 .tres의 사본**이 되어 데이터 죽음을 가려 준다.
## 여기선 0.0을 돌려주되(적이 굳는다 = 눈에 보인다) 키마다 **한 번** 경고한다
## (매 프레임 경고하면 로그가 잠겨 진짜 경고가 묻힌다 — `dummy_target.print` 선례).
var _warned_params := {}

func _param_req(key: String) -> float:
	if _def != null and _def.params.has(key):
		return float(_def.params[key])
	if not _warned_params.has(key):
		_warned_params[key] = true
		push_warning("적 '%s'의 필수 수치 '%s'가 없다 (data/enemies/%s.tres 확인) — 0으로 선다"
			% [enemy_id, key, enemy_id])
	return 0.0


## 🔴 공개 HP 리더 — 재생·피해를 테스트가 공개 API로 확인할 유일 경로다 (`_hp`는 internal이라
## 리팩터 때 옮겨 다니는 물건 = 계약이 아니다. takbon-verify §3 "공개 API로만").
func hp() -> float:
	return _hp


## 🔴 공개 페이즈 리더 — **보스 공용**(세56: boss_snake·boss_gale) 페이즈 전이를 헤드리스가
## 공개 API로 확인한다(`hp()` 선례). 1 = 기본, 2 = hp 절반 이후. 보스가 아닌 적은 항상 1.
func phase() -> int:
	return 2 if _phase2 else 1


## 🔴 공개 관측점 — **최종(화면) 히트박스 반경**(`hp()`·`phase()` 선례). 루트 scale(=`params.size`)까지
## 곱한 값이라 「보이는 몸에 쏘면 맞나」를 재는 그물이 이걸 그대로 쓴다.
## ⚠ **params에서 되계산하지 않고 실제 형상에서 읽는다** — 되계산하면 `_apply_hitbox`가 통째로
##  죽어도 이 리더가 옳은 값을 돌려줘 그물이 **거짓 그린**이 된다(세85 「검증 도구가 거짓말한다」).
func hitbox_radius() -> float:
	if _shape == null or not (_shape.shape is CircleShape2D):
		return 0.0
	return (_shape.shape as CircleShape2D).radius * absf(scale.x)


## 🔴 계약: `enemy_hit`는 **약점 배율을 반영한 최종 피해**로 발신한다 (dummy_target 주석).
## ✅ 세션49: `status`·`status_power`를 **드디어 쓴다** — 세34~48까지 밑줄로 버려서 불·물·바람의
## 실질 차이가 색 + 데미지 ±15%뿐이었다. 시그니처는 그대로다(계약을 넓히지 않았다).
func take_hit(damage: float, rune_type: int, status: int, status_power: float) -> void:
	if _dead:
		return
	# 🔴 세81 M2 (융합진): 직격 피해가 0 = 보조 룬의 **상태 전용 히트**. 손맛·발신·넉백·죽음판정을
	# 건너뛰고 상태만 얹는다 — 안 그러면 한 발이 룬 수만큼 `enemy_hit`·팝·피해숫자 "0"을 도배한다
	# (`juice.gd`가 발신마다 무조건 그린다). 반응은 `apply_incoming`이 판정하므로 여기서 얹으면 충분하다.
	# ⚠ 반응 **버스트**는 `take_reaction_damage` 별도 경로라 이 가드와 무관하다(그쪽은 계속 pop을 낸다).
	if damage <= 0.0:
		_status.apply_incoming(rune_type, status, status_power)
		return
	var mult := 1.0
	if _def != null and _def.has_counter and rune_type == _def.counter_rune:
		mult = _param("weakness_mult", 1.0)
	var dealt := damage * mult
	# 🔴 피해 경감 — 방어(갑충 armor_reduction) · 분산 중이면(안개 dispersed_resist) "막는 비율"로
	# 곱한다. 0.95로 상한을 둬 완전 무적은 못 만든다. 🔴 계약: enemy_hit은 **이 경감까지 반영한
	# 최종 피해**로 발신한다 (리포트·손맛이 실제 든 피해를 봐야 한다) — 약점 배율과 함께 곱해진 값.
	dealt *= (1.0 - clampf(_param("armor_reduction", 0.0), 0.0, 0.95))
	if _dispersed:
		dealt *= (1.0 - clampf(_param("dispersed_resist", 0.0), 0.0, 0.95))
	# 🔴🔴 **기습 — 나를 아직 못 본 적을 치면 더 아프다** (세105 인지 §6 · 사용자 확정 ⓕ).
	#  「뒤로 돌기」가 회피가 아니라 **전술**이 된다. ✅ **호출자를 한 곳도 안 건드린다** —
	#  적이 자기 인지 상태를 보고 스스로 곱하므로 회귀 위험이 구조적으로 0이다.
	#
	# 🔴 **직격만 받는다 — 반응·DoT는 일부러 제외한다**(설계 M9 정정). hp를 깎는 자리는 **셋**이다:
	#  여기(직격) · `take_reaction_damage`(반응 버스트·연쇄) · `_wire_status`의 `on_dot`(DoT 틱).
	#  ⚠ *"유일한 진입점"*이라고 읽으면 다음 사람이 반응 피해까지 여기로 옮긴다 — **셋이다.**
	# 🔴 자리가 여기인 이유 둘: ⓐ `enemy_hit` emit **앞**이라 계약(*"최종 피해"*)이 지켜진다 ·
	#  ⓑ `damage <= 0.0` 조기 반환 **뒤**라 「기습이 도는 자리」가 하나로 읽힌다.
	#  곱셈 순서는 무해하다(약점·방어·분산이 전부 곱이라 교환법칙이 선다).
	# ⚠ **허수아비(`dummy_target.gd`)엔 안 넣는다** — 인지가 없다(세56 두 몸 파리티의 예외).
	if _percept != Percept.CHASE:
		dealt *= _param("ambush_mult", AMBUSH_MULT_DEFAULT)
	_hp -= dealt
	EventBus.enemy_hit.emit(self, dealt, rune_type)
	# 🔴 상태·반응은 피해 **뒤에** 판정한다 — 증기·연쇄가 이 한 대의 피해까지 얹은 뒤 터져야
	# "한 발로 무너졌다"가 성립한다. 여기서 죽었더라도 `_dead` 가드가 이중 처리를 막는다.
	_status.apply_incoming(rune_type, status, status_power)
	# 넉백 = 플레이어 반대쪽으로 (탄이 플레이어→적 방향으로 오므로 그 근사다 — take_hit 계약을
	# 안 넓히고도 맞는 방향으로 밀린다. 세션 26 forest_enemy 주석의 "계약을 좁히지 않는다"와 같은 결).
	var p := _player()
	if p != null:
		var away := global_position - p.global_position
		if away.length() > 0.1:
			_knockback = away.normalized() * KNOCKBACK_IMPULSE
	_pop()
	_play_hurt()
	if _hp <= 0.0:
		_die()


## 🔴 죽으면 **드롭을 굴려 바닥에 떨군다** (세션46 — 사용자: *"게임답게 걸어가 줍게"*).
## 그전엔 여기서 곧장 `add_to_bag`으로 **가방에 순간이동**했다 — 이제 드롭마다 `drop_pickup` 씬을
## 죽은 자리에 심고, 가방에 넣는 건 픽업이 플레이어에 닿을 때 한다(픽업이 `add_to_bag`을 부른다).
## 인벤 흐름은 그대로다: `add_to_bag` → 귀환(extraction_success) 시 창고로 회수 · 죽으면(bag_lost)
## 통째로 사라진다. 바뀐 건 **가방에 언제 들어가느냐**뿐이다("주웠다"가 진짜 줍는 행위가 됐다).
##
## 🔴 룬 조각(fragment_*)은 **`until_unlock` 관문 드롭으로만** 나온다 (세58, 정본 docs/PROGRESSION.md
## — 「뼈대는 확정, 살은 랜덤」). 잡몹 순수 확률 조각은 세58에 은퇴했다 — 조각을 확률 줄로 되살리면
## test_progression_auto [4]·test_rune_unlock_auto ⑥이 붉는다. 새 관문 = 적 .tres의 until_unlock 드롭 한 줄.
##
## 🔴 `Audio.play(&"pickup")`은 여기서 **뺐다** — 소리는 실제로 주울 때(픽업) 울린다.
##
## 랜덤: Godot 전역 `randf()` — 부팅 시 자동 시드. 이 프로젝트의 첫 게임플레이 랜덤이다
## (세이브에 안 들어간다 — 드롭은 굴린 결과일 뿐 RNG 상태를 저장하지 않는다).
func _die() -> void:
	if _dead:
		return  # 🔴 DoT 틱·연쇄·직격이 같은 프레임에 겹쳐도 드롭·퀘스트는 한 번뿐이어야 한다
	_dead = true
	_status.clear()  # 남은 DoT 틱이 시체를 더 때리지 않게
	var scene := get_tree().current_scene
	if _def != null and scene != null:
		# 🔴 먼저 **굴리기만** 하고, 실제로 나온 걸 안 뒤에 심는다 — 개수를 알아야 낱개 픽업이
		# **균등 각도**를 나눌 수 있기 때문이다(세51 — `DropRoll.spawn_loose`가 rolled.size()로 각을 나눈다).
		var rolled := _roll_drops()
		if not rolled.is_empty():
			# 🔴 세66: 상자 은퇴 (사용자 확정 "상자 시스템 기각, 그냥 다 떨구는 걸로"). 모든 적이
			# 보스 포함 재료를 **낱개로** 떨군다(자석 픽업). 값어치는 픽업의 **등급 후광**이 알린다
			# (상자가 하던 "열기 전 값어치 겉보기"를 후광이 대체 — drop_pickup 등급 halo).
			_spawn_loose(scene, rolled)
	# 🔴 처치 순간 1회 — GameState가 KILL 퀘스트를 센다 (세션36). `died` 로컬 시그널의
	# "킬카운트가 붙는 날의 자리표"가 마침내 수신자를 얻었다. enemy_id를 실어 특정 적 목표도 가능.
	EventBus.enemy_died.emit(enemy_id)
	died.emit()
	_spawn_death_burst()
	# 🔴 예고는 **씬 소유**라 몸과 같이 안 죽는다 — 윈드업 중에 죽으면 붉은 띠가 바닥에 남는다.
	#  (`_exit_tree`도 같은 일을 하지만 여기서 먼저 지운다: 아래 queue_free는 프레임 끝에야 반영돼
	#   그 사이 한 프레임 동안 주인 없는 띠가 보인다.)
	_free_charge_band()
	queue_free()


## 🔴 드롭 테이블을 굴린다 — **로직은 `drop_roll.gd`가 쥔다**(세101 추출 · 설계 §10-4 S17).
## 여기 남은 일은 **`GameState`를 찾아 넘기는 것**뿐이다: static 안에서 오토로드 식별자를 쓰면
## `-s` 테스트 컴파일이 죽어서(오토로드는 컴파일 뒤에 등록된다) 조회를 호출자가 진다.
## ⚠ **굴림 규칙(해금 가드·관문·수량·반환 키)을 여기 다시 적지 마라** — 그게 두 벌이 되는 순간이다.
func _roll_drops() -> Array[Dictionary]:
	return DropRoll.roll(_def.drops, get_node_or_null("/root/GameState"))


## 낱개 바닥 픽업 (잡몹, 세46·51) — **로직은 `drop_roll.gd`가 쥔다**(세101 추출).
## 여기 남은 일은 **죽은 자리를 넘기는 것**뿐이다(지점은 자기 자리를 넘긴다 — 그래서 인자다).
##
## 🔴🔴 **세105 N5 — 지연 실행이 계약이다**(사용자 실플레이 엔진 에러):
## ```
## ERROR: Can't change this state while flushing queries.
##        Use call_deferred() or set_deferred() to change monitoring state instead.
## ```
## 🔴 **그 문구의 「monitoring」은 거짓 단서다** — 엔진 바이너리를 뒤져 보면 이 문자열은
##  `area_set_shape_disabled`/`body_set_shape_disabled`가 **같이 쓰는 사본**이다(실측).
##  진짜 원인은 **`CollisionShape2D`를 가진 씬을 물리 질의 flush 중에 `add_child`하는 것**이다:
##  `CollisionShape2D`가 `NOTIFICATION_ENTER_TREE`에서 `shape_owner_set_disabled`를 다시 걸어서다.
##
## 🔴 **여기가 그 자리다**: `projectile._on_body_entered`(= flush 중) → `_hit_enemy` → `take_hit`
##  → `_die` → 여기 → `drop_pickup.tscn`(Area2D + CollisionShape2D) `add_child` ⇒ **드롭 하나당 에러 하나**.
##  `ring_spell_system._on_carrier_deployed`가 *"물리 콜백 중일 수 있으니 지연 실행"*이라 적어 둔
##  **정확히 같은 함정**이고, 드롭 경로만 그 규율에서 빠져 있었다.
##
## 🔴🔴 **헤드리스가 구조적으로 못 잡는다**: ⓐ 접두가 `SCRIPT ERROR`가 아니라 `ERROR`라 그물의
##  grep을 통과하고 ⓑ **그물은 `take_hit`을 직접 불러 죽여서** 물리 콜백을 아예 안 지난다
##  (세105 실측: 전 스위트 48/48 그린 · `flushing queries` **0건**). 재현은 `body_entered` 안에서
##  픽업을 `add_child`하는 최소 리그로만 됐다.
## ⚠ `global_position`은 **지금** 값이 `bind`로 굳는다 — 이 프레임 끝에 `queue_free`되는 몸이라
##  나중에 읽으면 늦다. 그래서 인자로 넘기는 지금 모양이 그대로 정답이다.
func _spawn_loose(scene: Node, rolled: Array[Dictionary]) -> void:
	DropRoll.spawn_loose.bind(scene, global_position, rolled).call_deferred()


## 팝 — 셰이더 플래시 + 스쿼시 (피격 손맛, 세63 개편). modulate를 **아예 안 만진다** — 흰 섬광은
## 셰이더 `flash_amount`(mix-to-white라 어두운 픽셀도 하얘진다). 🔴 **scale은 _visual에만** 준다:
## 루트 scale은 _apply_look가 쥔 덩치(=히트박스)라 건드리면 히트박스가 출렁인다.
## 연타 시 트윈 중첩은 기존 규약 그대로(마지막 승리) — 단 flash는 트윈 전에 1.0을 직접 찍어
## **매 타마다 만빛에서 다시 시작**한다.
func _pop() -> void:
	if _visual == null:
		return
	var mat := _visual.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter(&"flash_amount", 1.0)
	_visual.scale = POP_SQUASH
	var tween := create_tween()
	tween.set_parallel(true)
	if mat != null:
		tween.tween_property(mat, "shader_parameter/flash_amount", 0.0, POP_SEC)
	tween.tween_property(_visual, "scale", Vector2.ONE, POP_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 피격 프레임 재생 (세63 설계 §C — 보스처럼 `params.hurt_sprite`가 있는 적만). 플래시+스쿼시(_pop)
## 위에 **얹는 층**이다 — hurt가 없는 적은 no-op(기존 무변경). 뱀 머리 회전(_face)은 노드 속성이라
## 애니와 직교 — hurt 재생 중에도 머리가 진행 방향을 본다.
func _play_hurt() -> void:
	if _visual == null or _visual.sprite_frames == null:
		return
	if not _visual.sprite_frames.has_animation(&"hurt"):
		return
	_visual.play(&"hurt")
	# 🔴 1프레임 스트립이면 `animation_finished`가 즉시 온다(설계 §C 함정) — 그대로 두면 한 틱
	# 번쩍하고 끝나 "안 보인다". 타이머로 홀드한 뒤 idle 복귀로 분기한다.
	# 🔴 세대 토큰(juice 히트스톱 선례) — 연타 시 **첫** 타이머가 뒤 hurt를 일찍 끊지 않게, 마지막
	# 발동의 타이머만 복귀시킨다(세63 리뷰). 람다가 아니라 bind인 이유 = 메서드 Callable은 노드가
	# free되면 소멸돼 안 불리지만, 람다는 free된 self를 만져 에러가 난다.
	if _visual.sprite_frames.get_frame_count(&"hurt") <= 1:
		_hurt_gen += 1
		get_tree().create_timer(HURT_HOLD_SEC).timeout.connect(_back_to_idle_gen.bind(_hurt_gen))
	elif not _visual.animation_finished.is_connected(_back_to_idle):
		_visual.animation_finished.connect(_back_to_idle, CONNECT_ONE_SHOT)


## 세대 토큰 검문 — 내 세대가 마지막이 아니면(그 뒤에 또 맞았으면) 복귀를 양보한다.
func _back_to_idle_gen(gen: int) -> void:
	if gen != _hurt_gen:
		return
	_back_to_idle()


## hurt에서 idle로 복귀. 노드가 이미 free됐으면 시그널 연결이 소멸돼 안 불린다(타이머도 안전).
func _back_to_idle() -> void:
	if _dead or _visual == null or _visual.sprite_frames == null:
		return
	if _visual.sprite_frames.has_animation(&"idle"):
		_visual.play(&"idle")


## 🔴🔴 **죽음 = 몸이 마나로 터진다** (세100 · 설계 `enemy_feel_design.md` §3-B 사용자 확정).
## 그전엔 **적 색(`params.color`)으로 커지며 사라지는 Polygon2D 링 하나**였다 — 밝은 낮 풀밭 위에서
## 갈색 얼룩으로 읽혀 *"뭔가 사라졌다"* 이상을 못 말했다(`vfx_shot -- death` 전/후 시트).
##
## 🔴 **연출 자체는 `ManaBurst`가 진다** — 여기 남은 일은 **몸에서 규격을 뽑아 넘기는 것**뿐이다
##  (`_attach_shadow`가 그림자 컴포넌트에 하는 일과 같은 결). 색·시간·모양을 여기 적으면
##  「무엇을 그리나」가 두 파일로 갈린다.
##
## 🔴 **파생원은 「보이는 몸」 하나다** — 프레임 한 변 × 덩치. 왜 곱하는지는 `ManaBurst` 머리말.
## 🔴 **보스 판별 = `params.ai`가 `boss_`로 시작하나** — 이미 데이터에 있는 축이라 새 키가 없다
##  (`boss_snake`·`boss_gale`). 덩치만으로는 못 가른다: gale은 64px로 늑대와 **같은 한 변**이다.
##
## 🔴 적은 이 프레임에 `queue_free`되지만 폭발은 **현재 씬에 따로 붙어 살아남는다**
##  (`_spawn_loose`·유언 탄과 같은 관용구. 그물 = `test_mana_burst_auto [1]`).
##
## 🔴🔴 **플레이어를 안 넘긴다 — 파편은 플레이어에게 안 온다**(세100 사용자 각하:
##  *"잠깐 빨려오는건 없음 … 마나가 들어오는건 없음"*). 여기서 `_player()`를 다시 넘기려는 순간이
##  각하된 궤적을 되살리는 순간이다. 🔴 **마나 수치도 여기서 절대 안 건드린다** —
##  `GameState.mana`를 한 줄이라도 올리면 *"몬스터 잡아서 마나회복하는것도 없어"*를 어긴다.
##  그물 = `test_mana_burst_auto [4]`(수렴 금지)·`[8]`(마나 불변).
func _spawn_death_burst() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var burst: Node2D = ManaBurst.new()
	scene.add_child(burst)
	burst.global_position = global_position
	burst.setup(_body_px(), _ai.begins_with("boss_"))


## 🔴 **화면에 실제로 보이는 몸 한 변**(px) — 프레임 한 변 × 루트 배율.
## 프레임 한 변만 보면 `hound_alpha`(64px 시트 × size 1.35 = 86px 몸)에서 **시체보다 작은 폭발**이
## 터진다. 곱한 값은 `_attach_shadow`가 자식이라 저절로 얻는 그 크기와 같다(그림자와 폭발이
## 같은 몸을 가리키게 된다). ⚠ 설계 §3의 「프레임 한 변 하나」와 갈리는 이유는 `ManaBurst` 머리말.
func _body_px() -> float:
	return _frame_side() * absf(global_scale.x)
