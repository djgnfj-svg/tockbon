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

@export_group("드로잉·잉크")
## 룬별 기본 마나 (인덱스 = Enums.RuneType: 불/충격/물/바람)
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

# ── 진 = 규모 축 (v1.6, TECH_SPEC §4.0) — 위력·크기·사거리를 전부 진이 정한다 ──
# 셋 다 circle_radius(0..1)를 입력으로 받는다. circle_radius 0.5(캔버스 절반)가 기준점 ≈ 1.0배.
## 위력 배율 = circle_damage_base + circle_radius
@export var circle_damage_base: float = 0.5
## 투사체 크기 배율 = lerp(min, max, circle_radius)
@export var circle_size_min: float = 0.6
@export var circle_size_max: float = 1.8
## 사거리 배율 = lerp(min, max, circle_radius) → projectile_lifetime_sec에 곱해진다
@export var circle_range_min: float = 0.6
@export var circle_range_max: float = 1.4
## circle_radius(정규) → 월드 px 발사 오프셋 스케일
@export var circle_radius_px: float = 48.0

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

# ── 룬 = 속성 농도 축 (v1.7, TECH_SPEC §4.0) — 상태이상 세기를 룬 크기가 정한다 ──
# 상태이상 세기 = RuneDef.status_power × lerp(density_min, density_max, rune_fill) × rune_accuracy.
# rune_fill = 룬 bbox 반경 ÷ 진 반지름. 인식기가 "룬은 진 안"으로 가르므로 자연히 0..1이다.
# **위력에는 절대 물리지 않는다** — 그건 진의 축이다 (축 위반 방지).
## 진 구석에 작게 그린 룬 = 옅게 스친다
@export var rune_density_min: float = 0.5
## 진을 꽉 채운 룬 = 깊이 물든다
@export var rune_density_max: float = 1.8

@export_group("경제")
## 수리비 = 원본 ink_cost 대비 비율
@export var repair_cost_frac: float = 0.2
## 응급 수리: 비용 배율 (일반 수리비 대비)
@export var emergency_repair_cost_mult: float = 0.5
## 응급 수리: 회복 상한 (durability_max 대비 비율)
@export var emergency_durability_frac: float = 0.3
## 해독 소요 (플레이 시간, GDD §6 — 약 10분)
@export var research_time_sec: float = 600.0
