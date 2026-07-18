class_name BalanceData
extends Resource
## 밸런스 수치 원장 — 코드에 수치를 박지 않는다 (TECH_SPEC §10).
## 인스턴스: res://data/balance.tres · 프로토 손맛 튜닝은 전부 여기서.

@export_group("시간")
## 하루 전체 길이 (초, 게임 시간)
@export var day_length_sec: float = 720.0
## 아침/낮/저녁/밤 비율 (합 1.0)
@export var phase_fracs: PackedFloat32Array = PackedFloat32Array([0.1, 0.5, 0.15, 0.25])

@export_group("마나")
@export var mana_max: float = 100.0
@export var mana_regen_per_sec: float = 2.0
## 🔴 발사 1회당 마나 소모 (세션 35 — 좌클릭 연사 차단). 이게 없던 시절엔 fire()가
## spend_mana를 아예 안 불러 무한 연사가 됐다. 지금은 발당 고정값 하나 — 원정 중 "이 발사
## 지금 쓸까 아낄까"의 예산이다. mana_max 100·재생 2/s 기준으로 ≈6발 연발 후 throttle.
## ⚠ 도안별(룬·화살·진 크기) 정밀 비용은 아직 안 붙였다 — rune_mana_base 등 부품 수치는
## 남아 있으나 합산하는 곳이 없다. 손맛 보고 나눌 몫(BACKLOG). 지금은 이 한 값으로 연사만 끊는다.
@export var cast_mana_cost: float = 16.0

@export_group("허기 (세션 35 — 원정 지속 제한)")
# 🔴 무한 파밍 차단 (사용자: "없으면 그냥 원정 나가서 계속 파밍할 수 있어서"). 포만 게이지는
# **숲에 있는 동안만** 준다(베이스=늘 만복). 0이 되면 HP가 깎여 귀환을 강제한다 = 익스트랙션
# 압박. 먹는 아이템은 v1엔 없다(귀환=회복). 나중에 "원정 연장" 소비템으로 붙일 몫(BACKLOG).
@export var hunger_max: float = 100.0
## 초당 포만 감소 — 만복→0 ≈ 166초(≈2.7분). 정상 원정은 넉넉히 돌 시간, 눌러앉으면 굶는다.
@export var hunger_drain_per_sec: float = 0.6
## 포만 0 이후 1초 간격으로 깎는 HP. 즉사 아님(만HP=100 → ≈25초) — 굶기 시작하면 돌아갈 시간은 준다.
## ⚠ 초당 tick으로 깎는다(연속 아님) — damage_player를 매 프레임 부르면 아픔음이 도배된다.
@export var starve_damage_per_tick: float = 4.0

@export_group("드로잉·잉크")
## 룬별 기본 마나 (인덱스 = Enums.RuneType: 불=0 / (1=옛 충격, 빈 슬롯) / 물=2 / 바람=3).
## v2.2: 충격 제거로 인덱스 1은 안 쓰인다 — 배열 값을 유지해 물·바람 인덱스가 안 밀리게 둔다.
@export var rune_mana_base: PackedFloat32Array = PackedFloat32Array([8.0, 6.0, 7.0, 9.0])
## 화살표 1발당 마나
@export var mana_per_arrow: float = 3.0
## 진 규모 → 마나 가산 (v1.6, TECH_SPEC §4.0). 진이 위력·크기·사거리를 전부 주므로
## 시전 비용에도 진 축이 붙는다 — 잉크만 물리면 큰 진이 일방적으로 우월해진다
@export var circle_mana_mult: float = 6.0
## magnitude 1.0이 되는 화살표 획 길이 (캔버스 정규).
## v1.6: magnitude는 **전투 스탯에서 분리됐다** — 기록만 남는다 (문양 종류 도입 시 재사용)
@export var arrow_full_length: float = 0.45
## 획 길이(정규)당 잉크 소모
## 먹의 양(길이 × 굵기) → 잉크 단위. **잉크는 통에서 나온 양이다** (v1.8, GDD §4.4).
## 이 계수 하나가 종이 상한 판정과 제작 비용 **양쪽에 같은 값**으로 쓰인다 — 할증은 없다
@export var ink_per_stroke_length: float = 10.0
## 인식 정확도 보정 하한 (GDD §4.4). v1.7: 위력이 아니라 **속성 순도**의 하한이다
@export var accuracy_floor: float = 0.6
## ⚠ **폐기 — 미사용** (세션 23). 보정은 **바닥값이 없다**: 펜을 안 끼면 0(그린 대로)이고
## 보정도는 전적으로 펜 아이템이 준다(`data/items/pen_*.tres`의 params.correction).
## 여기 상수를 깔면 맨손에도 보정이 붙어 "자기만의 마법진" 정체성과 어긋난다.
## 읽는 곳은 `GameState.stroke_correction()` 하나뿐이고, 이제 그 함수가 이 값을 안 본다.
@export var stroke_correct_strength: float = 0.55
## 룬 농도 → 마나 가산 (v1.7, TECH_SPEC §4.0). 진과 같은 이유로 시전 비용에 붙는다 —
## 안 물리면 "룬은 언제나 최대한 크게"가 유일한 정답이 된다
@export var rune_density_mana_mult: float = 4.0
# ── ⚠ 아래 둘은 **폐기됐다** (v1.8). 스키마에만 남아 있고 **아무도 읽지 않는다** ──
# 잉크는 통에서 나온 양이므로 **할증을 붙이지 않는다** (GDD §4.4·§5).
# 큰 진은 둘레가 길어서 **이미** 잉크를 더 먹는다 — 할증은 **이중 과금**이었다.
# 새 코드에서 이 값을 읽지 말 것. (구세이브 .tres 호환을 위해 필드만 남긴다)
## ⚠ 폐기 — 미사용 (v1.5 조준진 폐지로 가산할 대상이 없어짐)
@export var aimed_circle_ink_mult: float = 1.15
## ⚠ 폐기 — 진 크기 잉크 할증 (v1.8에서 이중 과금으로 판명, 제거됨)
@export var circle_radius_ink_mult: float = 2.0

@export_group("충격파 = 착탄 축 (v2.1)")
# 🔴 **화살표 하나 = 충격파 하나** (TECH_SPEC §4.0-b). 적을 맞히면 진이 그 자리에 놓이고,
# 진 위의 화살표들이 **각자 제자리에서 제 방향으로** 충격파를 뿜는다.
# **기둥은 여기 없다** — 충격파끼리 부딪히면 저절로 나온다. 규칙이 아니라 결과다.
## 충격파 속도(px/s) — 탄보다 빨라야 "터졌다"는 느낌이 난다
@export var shockwave_speed: float = 420.0
## 충격파 수명(초) — 뻗는 거리 = 속도 × 이 값. 짧아야 착탄 근처의 사건으로 읽힌다
@export var shockwave_lifetime_sec: float = 0.22
## 충격파 피해 = 탄 피해 × 이 값. 화살표를 많이 그으면 총량이 늘지만 낱개는 약하다
@export var shockwave_damage_mult: float = 0.35
## 충격파 히트박스 반경(px)
@export var shockwave_radius_px: float = 5.0

# ── 기둥 — **충격파끼리 만난 자리**에 선다 (창발. 코드가 "수렴하면 기둥"이라 정하지 않는다)
## 기둥 피해 = 탄 피해 × 이 값. 모아 그린 보상이라 낱개 충격파보다 세다
@export var pillar_damage_mult: float = 0.9
## 기둥 지속(초) — 이 동안 안에 있는 적을 계속 때린다
@export var pillar_duration_sec: float = 0.5
## 기둥이 적을 때리는 간격(초)
@export var pillar_tick_sec: float = 0.12
## 기둥 반경(px)
@export var pillar_radius_px: float = 14.0
## 같은 기둥이 겹쳐 서지 않는 최소 간격(px) — 충격파 8개가 한 점에서 만나면 기둥이 28개 설 수 있다
@export var pillar_merge_px: float = 12.0

@export_group("지팡이 = 발사 패턴 축 (v2.0)")
# 🔴 **방향·발수·기점은 지팡이의 것이다** (TECH_SPEC §4.0-a). 도안은 "무엇이 나가는가"만 정하고
# "어디로 몇 발"은 손에 든 지팡이가 정한다. 같은 도안도 지팡이를 바꾸면 다르게 나간다.
## 산탄(MULTI) 발수 — 에임을 중심으로 좌우 균등
@export var wand_multi_count: int = 3
## 산탄 총 퍼짐 각도(도) — 발과 발 사이가 아니라 **양 끝 사이**의 각
@export var wand_multi_spread_deg: float = 24.0
## 전방위(NOVA) 발수 — 360도 균등 분할. 에임이 바뀌면 통째로 돌 뿐 간격은 불변
@export var wand_nova_count: int = 8

@export_group("전투")
@export var projectile_base_speed: float = 260.0
## v1.7: 10.0 → 9.0. 위력에서 rune_accuracy(0.6~1.0) 곱을 떼면서(TECH_SPEC §4.0 축 분리)
## 곱하던 값이 사라져 위력이 통째로 올라갔다 — 잘 그린 도안 +11%, 막 그린 도안 **+67%**.
## 축 분리는 의도했지만 **위력 인플레는 의도한 적 없다.** 기준을 0.9배 낮춰
## **잘 그린 도안(accuracy≈0.9)의 위력을 v1.6과 같게** 되돌린다.
## 부수 효과: 이제 막 그린 도안도 같은 위력이 나온다 — 그게 축 분리의 요지다
## (엉망으로 그린 대가는 위력이 아니라 **속성 순도**로 치른다)
@export var projectile_base_damage: float = 9.0
@export var player_move_speed: float = 120.0
@export var dash_speed: float = 300.0
@export var dash_duration_sec: float = 0.18
@export var player_hp_max: float = 100.0
@export var wand_basic_damage: float = 4.0
## 탁본 모션 무방비 시간 (GDD §6)
@export var rubbing_duration_sec: float = 1.5
## 기준 사거리(초). 실제 수명 = 이 값 × 진 사거리 배율
@export var projectile_lifetime_sec: float = 1.5

# ── 진 = 규모 + **투사체의 모양** 축 (v2.0, TECH_SPEC §4.0) ──
# 위력·크기·기준 사거리를 진이 정한다. 셋 다 circle_radius(0..1)를 입력으로 받고,
# circle_radius 0.5(캔버스 절반)가 기준점 ≈ 1.0배.
# 🔴 **v2.0: 진이 곧 투사체다** (사용자: "투사체의 모양이 진이라고 끝인데?").
# 그린 진(+룬) 먹선이 그대로 날아가고 **히트박스가 진 반지름을 따른다**.
## 위력 배율 = circle_damage_base + circle_radius
@export var circle_damage_base: float = 0.5
## ⚠ **v2.0에서 소비 중단** — 진이 곧 탄이므로 **탄 크기는 진 반지름이 직접 정한다.**
## 여기에 또 배율을 곱하면 **같은 축을 두 번 적용**하는 것이다 (v1.6에 탄이 진과 무관한
## 스프라이트였을 때만 말이 됐던 값). 구세이브·기존 .tres 호환을 위해 필드만 남긴다
@export var circle_size_min: float = 0.6
@export var circle_size_max: float = 1.8
## 사거리 배율 = lerp(min, max, circle_radius) → projectile_lifetime_sec에 곱해진다
@export var circle_range_min: float = 0.6
@export var circle_range_max: float = 1.4
## circle_radius(정규) → 월드 px 스케일. InkRender.unit_px = 이 값 × 2 (§4.4 — 깨지 말 것)
@export var circle_radius_px: float = 48.0
## 🔴 **v2.0: 종이 위의 진 → 날아가는 탄**으로 줄이는 배율. 종이에 그린 크기 그대로 날리면
## 진 하나가 화면 폭의 상당 부분을 먹는다 (캔버스 절반짜리 진 = 반지름 24px, 적이 32px인 세계에서).
## 먹선과 히트박스가 **같은 값**을 쓴다 — 갈라지면 보이는 것과 맞는 것이 어긋난다
@export var projectile_circle_scale: float = 0.5
## 탄 히트박스 최소 반경(px) — 진을 아주 작게 그려도 **보이고 맞아야 한다**.
## 없으면 작은 진이 "그렸는데 아무것도 안 맞는" 탄이 된다
@export var projectile_min_radius_px: float = 4.0

# ── 문양 = 발동 방식 + 세기 축 (v1.9, TECH_SPEC §4.0) — GDD §4.3 ──
# ArrowData.reach = 문양 획 길이 ÷ 진 반지름. **룬의 rune_fill과 대칭**이다.
# 정규화 t = inverse_lerp(glyph_reach_min, glyph_reach_max, reach) → 0..1 이 아래 전부의 입력.
# 사거리는 **진이 기준을 주고 문양이 배율을 정한다** — 축을 도로 뺏지 않는다 (GDD §4.1).
## reach 하한 — 진을 겨우 뚫고 나간 짧은 문양
@export var glyph_reach_min: float = 0.6
## reach 상한 — 종이 끝까지 길게 뺀 문양 (이 위는 잘린다)
@export var glyph_reach_max: float = 3.0
## 사거리 배율 = lerp(min, max, t) → compute_lifetime의 진 사거리에 **곱해진다**
@export var glyph_range_min: float = 0.7
@export var glyph_range_max: float = 1.6
## 문양 세기 → 발당 마나 가산 (t에 비례). 진·룬과 같은 이유 —
## 공짜면 "문양은 언제나 최대한 길게"가 유일한 정답이 된다 (GDD §5)
@export var glyph_reach_mana_mult: float = 2.5
## 팅김⚡ 벽 반사 횟수 = round(lerp(1, max, t)). 길게 그은 팅김이 더 많이 튕긴다
@export var glyph_bounce_max: int = 4
## 관통‖ 뚫는 적 수 = round(lerp(1, max, t)). 길게 그은 관통이 더 많이 뚫는다
@export var glyph_pierce_max: int = 4
## 유도∿ 선회 속도 (rad/s) — 클수록 급하게 꺾어 따라간다
@export var glyph_homing_turn_rate: float = 3.2
## 유도∿ 표적 탐지 반경 (px)
@export var glyph_homing_range_px: float = 220.0
## 유도∿ 추적 지속 = lerp(min, 1.0, t) × 수명. 짧게 그으면 잠깐만 따라가고 놓친다
@export var glyph_homing_duration_min: float = 0.35
## 추진 속도 배율 (v2.2) = lerp(min, max, t) — 옛 충격의 '힘'이 문양으로. 짧게 그어도 한 번은
## 빨라지므로 min>1.0이다(길이=0이 무효가 아니게). 길게 그으면 max까지. ⚠ 손맛(F6)에서 조정
@export var glyph_thrust_speed_min: float = 1.3
@export var glyph_thrust_speed_max: float = 2.4

# ── 룬 = 속성 농도 축 (v1.7, TECH_SPEC §4.0) — 상태이상 세기를 룬 크기가 정한다 ──
# 상태이상 세기 = RuneDef.status_power × lerp(density_min, density_max, rune_fill) × rune_accuracy.
# rune_fill = 룬 bbox 반경 ÷ 진 반지름. 인식기가 "룬은 진 안"으로 가르므로 자연히 0..1이다.
# **위력에는 절대 물리지 않는다** — 그건 진의 축이다 (축 위반 방지).
## 진 구석에 작게 그린 룬 = 옅게 스친다
@export var rune_density_min: float = 0.5
## 진을 꽉 채운 룬 = 깊이 물든다
@export var rune_density_max: float = 1.8

@export_group("고리 = 마력 주입 (세션 23)")
# 🔴 **손으로 그린 점수에 처음으로 이빨이 붙는 축** (사용자 확정 2026-07-17).
# 다 그리면 분석이 위력을 보여 주고, [마력 주입]을 누르면 맺히거나 **펑** 한다.
# 세션 22까지 total_score는 계산·저장만 되고 **아무도 안 읽었다** — 잘 그리든 막 그리든 마법이 같았다.
# 규칙 계산은 `src/core/ring_power.gd`가 쥔다 (조립 리포트와 발사가 **같은 값**을 봐야 해서 core에 있다).
## 🔴 종합 점수가 **이 값 이하면 펑** — 도안이 날아가고 처음부터 다시 그린다 (잃는 건 시간·정성뿐).
## 사용자 확정: "65퍼 이하면 터지고". 🔴 **등급의 최하단이기도 하다** (세션 24) — 이 값 이하 =
## 「사용 불가」다. 등급 경계에 65를 따로 적어 두면 이 값만 바꿨을 때 조용히 갈라진다
## (「무난」인데 터지는 세션 23의 어긋남이 정확히 그거였다). `ring_power.grade_of`가
## `is_stable`을 그대로 불러서 **두 경계가 한 값**이 되게 한다.
## ⚠ **이 값은 위력 곡선에 안 들어간다** — 견디느냐(이 값)와 얼마나 세냐(아래)는 별개 축이다
@export var ring_stability_min: float = 0.65
## 만점(100점) 마법진의 위력 배율
@export var ring_power_max: float = 1.6
## 🔴 점수 → 위력 곡선의 지수: **위력 = ring_power_max × 점수^이 값** (1=선형, 클수록 잘 그린 값이 커짐).
## 왜 곡선이냐: 위력은 기준선 **아래에서도 끊김 없이 이어져야** 한다. 예전엔 기준선~만점을
## 선형 보간하고 아래를 잘라서(clamp), 20점짜리와 64점짜리가 리포트에 **똑같이 "위력 70"**으로
## 떴다 — 받지도 못할 숫자라 거짓말이고, 위력이 70에 붙는 순간이 곧 "너 지금 미달"이라는
## **안내**가 된다 (사용자: 주입 전에 안내하면 안 된다). 지수 곡선은 0점→0, 만점→max로
## 이어져 평평한 구간이 없다.
## ⚠ 2.0이 예전 손맛을 보존한다: 66점→0.70배·만점→1.6배로 **기존 실측(2.2배 차이)과 거의 같다**
@export var ring_power_curve: float = 2.0

# ── 등급 경계 (세션 24, 사용자 확정) ──────────────────────────────────────────────
# 🔴 **최하단 경계는 여기 없다** — 그건 위 `ring_stability_min`이다 (그 이하 = 「사용 불가」).
# 아래 넷은 "쓸 수 있는" 마법진 안에서의 칸이다. 등급 이름은 코드(ring_power.gd) — 수치만 여기.
# 사용자: "65~75가 무난, 75~85가 평타, 85~95가 괜찮은, 95~100이 완벽, 100은 퍼펙트".
## 「무난」 → 「평타」
@export var ring_grade_fair: float = 0.75
## 「평타」 → 「괜찮음」
@export var ring_grade_good: float = 0.85
## 「괜찮음」 → 「완벽」
@export var ring_grade_great: float = 0.95
## 🔴 「완벽」 → 「퍼펙트」. **0.995인 이유**: 리포트가 점수를 `round(점수×100)`으로 찍으므로
## 이 값이 곧 "화면에 100으로 뜨는 순간"이다 (사용자 확정: *"화면에 100으로 뜨면 퍼펙트"*).
## 0.999로 올리면 **100점이라 적어 놓고 완벽**이라는 어긋남이 생긴다 — 표시 반올림과 묶인 값이다
@export var ring_grade_perfect: float = 0.995

@export_group("종이·특별잉크 (세션29)")
# 🔴 종이=규모·특별잉크=상태증폭 (사용자 확정). 잉크 등급=데미지(power_mult)와 **다른 레버**다.
## 진 크기(jin_scale) → 데미지 지수. size_mult = jin_scale ^ 이 값 (1=선형: 2배 크게=2배 데미지,
## <1=완화). 종이 등급이 jin_scale 상한을 올리므로, 이게 "큰 진=데미지↑"의 세기다.
## ⚠ 잉크 배수와 **겹쳐서** 곱해진다 — 둘 다 데미지라 폭주 주의(사용자와 확인한 지점).
@export var paper_size_power_exp: float = 1.0
## 종이 없이 그릴 때의 기본 진 확대 상한 (= paper_basic의 zoom_max와 맞춘다).
## 종이를 안 골라도 여기까지는 키울 수 있다 — 종이는 이 상한을 **더** 올리는 것.
@export var paper_zoom_max_default: float = 1.16
## 특별잉크 획당 소모량 — 그리는 동안 실시간으로 닳는다 (사용자: "그릴 때 실시간으로 소비").
## 다 떨어지면 소모·효과 적립 없이 계속 그린다(기본잉크처럼) — 그만큼 비율(효과)이 낮아진다.
@export var special_ink_per_stroke: int = 1

@export_group("거점 건설 (세션37)")
# 🔴 스테이션 건설 비용 {station_codex_id: {item_id: 수량}}. 거점은 **재료로 직접 짓는다**
# (사용자 확정 세션37: "거점을 내가 직접 업데이트해야 될 거, 시작했을 때 아무것도 없는 상태가 중요").
# 🔴 codex를 건설 상태로 쓴다(룬 해금과 같은 기전) → 저장·is_unlocked·**UNLOCK 퀘스트 자동 진행**이
# 전부 공짜로 재사용된다. "정제대를 지어라" 퀘스트가 건설 순간(codex_unlocked) 저절로 완료된다.
# 🔴 **새 스테이션 = 여기 한 줄 + base.tscn 노드 하나.** 읽는 곳은 base.gd 하나(런타임 인스턴스 읽기라
# const-folding 함정 없음). ⚠ 배선이지 튜닝이 아니다 — 개수·재료는 플레이하며 조율(사용자 몫).
@export var station_build_costs: Dictionary = {
	&"station_refine": {&"mat_slime_core": 3, &"mat_vine": 2},
	&"station_craft": {&"mat_hound_fang": 2, &"mat_beetle_shell": 2},
	&"station_decode": {&"mat_slime_core": 5, &"mat_moon_sap": 1},
}

@export_group("경제")
## 수리비 = 원본 ink_cost 대비 비율
@export var repair_cost_frac: float = 0.2
## 응급 수리: 비용 배율 (일반 수리비 대비)
@export var emergency_repair_cost_mult: float = 0.5
## 응급 수리: 회복 상한 (durability_max 대비 비율)
@export var emergency_durability_frac: float = 0.3
## 해독 소요 (플레이 시간, GDD §6 — 약 10분)
@export var research_time_sec: float = 600.0
