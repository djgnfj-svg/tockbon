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

@export_group("기둥 = 응집(←) 착탄 축")
# ── 기둥 — 응집(←) 칸이 모인 착탄점에 선다 (ring_spell_system._spawn_pillar, gather 수만큼 굵다)
## 기둥 피해 = 탄 피해 × 이 값. 모아 그린 보상이라 세다
@export var pillar_damage_mult: float = 0.9
## 기둥 지속(초) — 이 동안 안에 있는 적을 계속 때린다
@export var pillar_duration_sec: float = 0.5
## 기둥이 적을 때리는 간격(초)
@export var pillar_tick_sec: float = 0.12
## 기둥 반경(px)
@export var pillar_radius_px: float = 14.0
## 같은 기둥이 겹쳐 서지 않는 최소 간격(px)
@export var pillar_merge_px: float = 12.0

@export_group("변형형 문양 = 확산·폭발 (세79 M1 진별 해석)")
# 🔴 **전개형(발산·응집)과 계열이 다르다** — 확산·폭발은 착탄점에서 스스로 전개하는 게 아니라
# **안쪽 층의 결과를 받아 바꾸는 연산자**다. 해석은 ring_spell_system의 층 루프가 한다.
# ⚠ 아래 전부 **시작값이다. 손맛은 F5로 조인다** — 헤드리스는 "몇 갈래가 나갔나"만 재고
# "넓게 퍼진 느낌인가"는 못 잰다.
## 확산 부채꼴 총각(도) — 안쪽 탄 하나가 이 각 안에서 n갈래로 벌어진다. 크면 넓게 훑고 작으면 집중된다
@export var spread_fan_deg: float = 46.0
## 확산 갈래 하나의 세기 배율. 🔴 n갈래 총합(n×이 값)이 1.0을 넘어야 확산을 그릴 이유가 생긴다
## (3갈래면 1.8배) — 1/n로 정확히 나누면 "퍼지기만 하고 손해"가 돼 문양이 죽는다
@export var spread_branch_mult: float = 0.6
## 제자리 명령(기둥·폭발)을 확산할 때 착탄점 둘레로 흩는 반경(px). 겹쳐 서면 한 발과 구분이 안 된다
@export var spread_offset_px: float = 44.0
## 폭발 기본 반경(px) — 안쪽이 한 갈래일 때
@export var blast_base_radius_px: float = 54.0
## 🔴 안쪽 갈래 하나당 반경 증가 비율. **이 값이 순서를 눈에 보이게 만든다** —
## `폭발(확산(불))`이 `확산(폭발(불))`보다 확연히 큰 폭발이 되는 이유가 여기다. 0이면 순서가 안 보인다
@export var blast_radius_per_branch: float = 0.18
## 폭발 칸 하나당 반경 증가 비율 (많이 그릴수록 크게 터진다)
@export var blast_radius_per_count: float = 0.25
## 융합 효율 — 안쪽 세기 **합**에 곱한다. 1.0이면 손실 없음, 낮추면 "뭉치면 조금 샌다"
@export var blast_merge_mult: float = 0.85
## 🔴 착탄 전개 명령 수 상한 — **확산이 곱셈이라 층이 깊어지면 폭증한다.**
## 최악: 층0 발산 8칸(명령 8) × 층1 확산 8칸(×8) = 탄 64발, 거기에 산탄/둘레 진이면 캐리어가
## 5~8개라 **수백 발**. 지금 밴드 상한 2·확산 count 3이라 실전에선 안 나지만, 진 등급이 **9까지**
## 확정된 축이라(설계 문서 §진 등급) 층이 깊어지는 순간 터진다. 나중에 넣으면 밸런스가 이미
## 그 위에 서 있어 못 내린다 — 지금 박아 둔다. 넘치면 앞에서부터 자르고 경고를 남긴다.
@export var max_deploy_cmds: int = 48
## 🔴 다중 룬 세기 배분 (세81 M2 융합진, 사용자 확정) — 진에 룬이 2개+면 각 룬 피해에 이 값을 곱해
## primary 히트가 **합산**해 진다(2룬 = base × 이값 × 2 = base × 1.4). 룬 1개는 배율 없음(1.0 폴백) =
## 옛 도안 무회귀. "잘 쓰면 이득(합>1)·못 써도 크게 손해 아니게"라 0.5(정확히 나눔)보다 높게 잡았다.
## 시작값 — F5로 조인다. 위력 축이라 책 리포트도 이걸 반영해야 발사와 안 갈라진다(ring_power 파리티).
@export var multi_rune_share: float = 0.7

@export_group("지팡이 = 발사 패턴 축 (v2.0)")
# 🔴 **방향·발수·기점은 지팡이의 것이다** (TECH_SPEC §4.0-a). 도안은 "무엇이 나가는가"만 정하고
# "어디로 몇 발"은 손에 든 지팡이가 정한다. 같은 도안도 지팡이를 바꾸면 다르게 나간다.
## 산탄(MULTI) 발수 — 에임을 중심으로 좌우 균등
@export var wand_multi_count: int = 3
## 산탄 총 퍼짐 각도(도) — 발과 발 사이가 아니라 **양 끝 사이**의 각
@export var wand_multi_spread_deg: float = 24.0
## 전방위(NOVA) 발수 — 360도 균등 분할. 에임이 바뀌면 통째로 돌 뿐 간격은 불변
@export var wand_nova_count: int = 8

@export_subgroup("세션48 새 진")
## 연발(BURST) 발수 — 같은 각도로 시간차. 산탄과 달리 전부 조준선에 맞지만 적이 움직이면 빗나간다
@export var jin_burst_count: int = 3
## 연발 발 간격(초). 너무 길면 한 발씩 쏘는 것과 같고, 짧으면 산탄과 구분이 안 간다
@export var jin_burst_interval_sec: float = 0.10
## 분사(SPRAY) 발수 — 좁은 각으로 연속. 근거리 압박용
@export var jin_spray_count: int = 5
## 분사 총 퍼짐 각도(도) — 산탄(24도)보다 좁아야 "분사"로 읽힌다
@export var jin_spray_spread_deg: float = 10.0
## 분사 발 간격(초) — 연발보다 촘촘
@export var jin_spray_interval_sec: float = 0.05
## 타겟팅(SEEK) 탐색 반경(px). 이 안에 적이 없으면 조준 방향으로 그냥 나간다
@export var jin_seek_radius_px: float = 420.0
## 나선(SPIRAL) 진폭(px) — 진행축에 수직으로 흔들리는 폭. 충돌 경로가 그만큼 넓어진다
@export var jin_spiral_amplitude_px: float = 26.0
## 나선 주기(초) — 한 번 좌우로 훑는 데 걸리는 시간
@export var jin_spiral_period_sec: float = 0.45
## 부메랑(BOOMERANG) 되돌아오기 시점 — 수명 대비 비율. 0.5면 절반 날아가고 절반 돌아온다
@export var jin_boomerang_turn_ratio: float = 0.5

@export_group("상태이상 · 원소 반응 (세션49)")
# 🔴 규칙은 `src/core/status_rules.gd`가 쥔다 — 여기는 **수치만**.
# 🔴 원칙: **단독은 약한 바탕, 조합(반응 산물)이 세다.** 아래 지속시간·배율이 그 차이를 만든다.
#
# 🔴🔴 **세션50: `status_power`의 의미가 「세기 배율」로 통일됐다** (전 룬 1.0). 그전엔 룬마다
# 뜻이 달랐다 — 불 3.0=초당피해 · 물 0.35=감속비율 · 바람 60.0=죽은 값 · 번개/흙/풀은 **아예
# 안 읽혔다**. 그래서 **특별잉크 증폭(`Db.status_mult_of`)이 룬 절반에만 통했다**(세28~29 경제의
# 절반이 죽어 있었다). 이제 각 상태의 **기본 수치는 여기 있고**, 룬이 실어 온 배율이 그 위에
# 곱해진다 — 특별잉크가 6룬 전부에 균일하게 통한다.
# ⚠ 의미 정리가 목적이지 리밸런스가 아니지만, **감전 연쇄만 실제로 세졌다** (0.6 → 1.8, 3배).
#   세49엔 `maxf(번개 1.0, 젖음 0.35) × chain 0.6 = 0.6`이었다 — 번개의 1.0은 **아무 데서도
#   안 읽히던 값**이라 사실상 사고값이었고, 기준으로 삼을 게 못 된다. 증기는 2.4로 보존됐다.
#   🔴 1.8이 맞는 세기인지는 **사용자가 쏴 봐야** 정해진다.
## 🔴 화상 초당 피해의 **기준값** — 실제 DoT = 이 값 × 룬의 status_power(배율).
## (세션49까진 `rune_fire.status_power = 3.0`이 곧 초당피해였다 — 그 값을 그대로 옮겼다.)
@export var status_burn_dot_base: float = 3.0
## 🔴 반응 버스트(증기·감전연쇄) 피해의 **기준값** — 실제 피해 = 이 값 × 배율 × 각 반응의 mult.
## ⚠ **이 필드가 없으면 조용히 깨진다**: 세션49엔 버스트 피해가 `power × mult`였고 power가 곧
## 불의 3.0이었다. 배율을 1.0으로 통일하면서 기준값을 빼내지 않으면 증기·연쇄가 **1/3로 토막**
## 나는데 **에러도 테스트 실패도 없다**(세션50 설계가 잡았다).
@export var status_burst_base: float = 3.0
## 🔴 감속의 상한 — `기본 감속 × 배율`이 아무리 커도 여기서 잘린다(0.90 = 최대 90% 감속).
## ⚠ 1.0(완전정지)을 허용하면 안 된다: 적이 이동 0이 되면 "느려졌다"와 "어그로가 풀렸다/죽었다"가
## 구분되지 않아, 감속 테스트가 엉뚱한 이유로 통과한다(실제로 밟은 함정).
@export var status_slow_cap: float = 0.90
## 화상 지속(초) — 초당 피해는 위 `status_burn_dot_base` × 배율
@export var status_burn_sec: float = 3.0
## 젖음 지속(초) · 감속 비율(0.35 = 35% 느려짐)
@export var status_wet_sec: float = 2.5
@export var status_wet_slow: float = 0.35
## 감전 지속(초) · 감속(경직에 가깝게 짧고 강하게)
@export var status_shock_sec: float = 1.2
@export var status_shock_slow: float = 0.55
## 취약(흙) 지속(초) · 다음 상태 세기 배율 — "밑작업 룬"의 값.
## 🔴 세션50(사용자 확정): 특별잉크로 증폭된 세기는 **이 배수를 흔든다**(지속시간이 아니라).
## 지속을 흔들면 조합의 보상이 「세기」가 아니라 「타이밍 여유」로 미끄러져, 원칙
## 「단독은 약한 바탕, 조합에서 폭발한다」가 「조합 창이 넓어진다」로 변질된다.
## ⚠ 증폭은 **선형**이다(`status_rules.power_mult` 참조) — 곱으로 하면 취약 2배가 배수 2.25배로 튄다.
@export var status_vulnerable_sec: float = 4.0
@export var status_vulnerable_mult: float = 1.5
## 덩굴(풀) 지속(초) · 감속
@export var status_root_sec: float = 2.0
@export var status_root_slow: float = 0.55
## 🔴 진흙(젖음+흙) — 반응 산물이라 **더 오래·더 세다**(거의 정지)
@export var status_mud_sec: float = 3.5
@export var status_mud_slow: float = 0.85
## 🔴 산불(화상+풀) — 반응 산물. 화상보다 오래 타고 초당 피해가 배로 든다
@export var status_blaze_sec: float = 5.0
@export var status_blaze_dot_mult: float = 2.0
## 감전 연쇄(젖음+번개) — 주변 이 반경(px) 안의 적에게 튄다 · 그 피해 배율
## 🔴 **적·허수아비 배치가 이 반경 안이어야 연쇄가 눈에 보인다.** 세44~49 연습장 허수아비는
## 최소 간격이 102px라 90 밖이었고, **배선이 맞는데도 연쇄가 한 번도 안 터졌다**(세50 실측).
## 이 값을 줄이거나 배치를 벌릴 땐 `src/base/base.tscn`의 Targets 좌표를 같이 봐라.
## (씬 쪽에도 같은 주석이 있지만 에디터가 저장하면 날아간다 — **이쪽이 정본**이다.)
@export var status_shock_chain_px: float = 90.0
@export var status_shock_chain_mult: float = 0.6
## 증기(젖음+불) — 즉발 폭발 반경(px) · 피해 배율
@export var status_steam_px: float = 70.0
@export var status_steam_mult: float = 0.8
## 🔴 확산(바람) — 붙은 상태가 이 반경(px) 안의 적에게 퍼진다 (원신 Swirl 모델)
@export var status_spread_px: float = 110.0
## 상태 틱 간격(초) — 지속 피해를 이 주기로 넣는다. 짧을수록 부드럽고 무겁다
@export var status_tick_sec: float = 0.5

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
## 🔴 이동 가속/감속 (세74 이동 필) — player.gd가 `_move_vel`을 목표 속도로 move_toward한다.
## 즉시 대입이 아니라 램프라 스냅·무게감이 생긴다. 값이 클수록 즉각적(작을수록 미끄러지며 붙음/멈춤).
## accel ≈ 목표속도÷도달시간: 1400이면 120px/s 도달 ≈0.086s. 잠정 시작값 — 손맛 F5로 조인다.
## ⚠ "느리다"의 본래 원인은 player_move_speed(위)다 — 가속/감속은 붙는 맛이지 속도 자체가 아니다.
@export var player_accel: float = 1400.0     ## 가속(px/s²) — 입력 방향으로 목표속도까지
@export var player_friction: float = 1800.0  ## 감속(px/s²) — 입력 없을 때 0까지
## 🔴 구르기(Shift) — 짧은 대시 + 대시 동안 무적 프레임 (세션41 온보딩, player.gd가 배선).
## ⚠ 세션40까지 dash 액션·이 두 수치가 **스텁만 있고 아무도 안 읽었다**(죽은 코드) — 구르기로 되살렸다.
## 대시 거리 = dash_speed × dash_duration_sec (≈128px). 잠정값 — 손맛 보며 조인다.
@export var dash_speed: float = 640.0
@export var dash_duration_sec: float = 0.2
@export var dash_cooldown_sec: float = 0.6
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
