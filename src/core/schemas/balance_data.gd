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
## 획 길이(정규)당 잉크 소모
@export var ink_per_stroke_length: float = 10.0
## 인식 정확도 위력 보정 하한 (GDD §4.4)
@export var accuracy_floor: float = 0.6
## 조준진 잉크 가산 배율 (GDD §4.1 — 조준 편의는 공짜가 아니게)
@export var aimed_circle_ink_mult: float = 1.15
## 원 반지름 → 잉크 계수
@export var circle_radius_ink_mult: float = 2.0

@export_group("전투")
@export var projectile_base_speed: float = 260.0
@export var projectile_base_damage: float = 10.0
@export var player_move_speed: float = 120.0
@export var dash_speed: float = 300.0
@export var dash_duration_sec: float = 0.18
@export var player_hp_max: float = 100.0
@export var wand_basic_damage: float = 4.0
## 탁본 모션 무방비 시간 (GDD §6)
@export var rubbing_duration_sec: float = 1.5
@export var projectile_lifetime_sec: float = 1.5
## 위력 배율 = magnitude_damage_base + magnitude (모듈 B)
@export var magnitude_damage_base: float = 0.5
## 투사체 크기 배율 = lerp(min, max, magnitude)
@export var magnitude_size_min: float = 0.6
@export var magnitude_size_max: float = 1.8
## circle_radius(정규) → 월드 px 발사 오프셋 스케일
@export var circle_radius_px: float = 48.0

@export_group("경제")
## 수리비 = 원본 ink_cost 대비 비율
@export var repair_cost_frac: float = 0.2
## 응급 수리: 비용 배율 (일반 수리비 대비)
@export var emergency_repair_cost_mult: float = 0.5
## 응급 수리: 회복 상한 (durability_max 대비 비율)
@export var emergency_durability_frac: float = 0.3
## 해독 소요 (플레이 시간, GDD §6 — 약 10분)
@export var research_time_sec: float = 600.0
