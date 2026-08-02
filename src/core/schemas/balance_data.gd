class_name BalanceData
extends Resource
## 밸런스 수치 원장 — 코드에 수치를 박지 않는다.
## 인스턴스: res://data/balance.tres · 프로토 손맛 튜닝은 전부 여기서.
##
## ⚠ **소비자 0인 필드가 여럿 남아 있다.** 이 파일의 규약은 「지우지 않고 **표시**한다」이다 —
## 값을 흔들어 보고 아무 일도 안 나면 주석의 「⚠ 소비자 0」을 먼저 봐라.
## 되살릴 땐 **소비자를 같은 커밋에** 붙여라.

@export_group("시간")
## 하루 전체 길이 (초, 게임 시간)
@export var day_length_sec: float = 720.0
## 아침/낮/저녁/밤 비율 (합 1.0)
@export var phase_fracs: PackedFloat32Array = PackedFloat32Array([0.1, 0.5, 0.15, 0.25])

@export_group("마나")
@export var mana_max: float = 100.0
@export var mana_regen_per_sec: float = 2.0
## 발사 1회당 마나 소모 — 좌클릭 연사를 끊는 발당 고정값이다("이 발사 지금 쓸까 아낄까"의 예산).
## ⚠ 도안별(룬·문양·진 크기) 정밀 비용은 아직 없다 — 아래 부품 수치는 남아 있으나 합산하는 곳이 없다.
@export var cast_mana_cost: float = 16.0

@export_group("드로잉·잉크")
## ⚠ **소비자 0** — 부품 비용을 합산하는 곳이 없다.
## 🔴 되살릴 땐 **인덱스로 룬을 짚지 마라**: `Enums.RuneType`은 값이 연속이 아니고(1=구멍)
## 지금 룬은 6종인데 이 배열은 4칸이다 — 「없는 룬」이 만들어진다.
@export var rune_mana_base: PackedFloat32Array = PackedFloat32Array([8.0, 6.0, 7.0, 9.0])
## 문양 1발당 마나. ⚠ 소비자 0.
@export var mana_per_arrow: float = 3.0
## 진 규모 → 마나 가산. 잉크만 물리면 큰 진이 일방적으로 우월해져서 둔 값. ⚠ 소비자 0.
@export var circle_mana_mult: float = 6.0
## magnitude 1.0이 되는 문양 획 길이 (캔버스 정규). ⚠ 소비자 0.
@export var arrow_full_length: float = 0.45
## 획 길이(정규)당 잉크 소모. 잉크는 통에서 나온 양이라 **할증을 붙이지 않는다** —
## 종이 상한 판정과 제작 비용에 같은 값으로 쓴다. ⚠ 소비자 0(그리기 폐지로 획이 안 생긴다).
@export var ink_per_stroke_length: float = 10.0
## 인식 정확도 보정 하한 — 위력이 아니라 **속성 순도**의 하한이다. ⚠ 소비자 0.
@export var accuracy_floor: float = 0.6
## ⚠ 폐기 — 미사용. 보정은 **바닥값이 없다**: 펜을 안 끼면 0(그린 대로)이고 보정도는 전적으로
## 펜 아이템이 준다. 여기 상수를 깔면 맨손에도 보정이 붙어 「자기만의 마법진」과 어긋난다.
@export var stroke_correct_strength: float = 0.55
## 룬 농도 → 마나 가산. 안 물리면 "룬은 언제나 최대한 크게"가 유일한 정답이 된다. ⚠ 소비자 0.
@export var rune_density_mana_mult: float = 4.0
# ── ⚠ 아래 둘은 폐기됐다 — 스키마에만 남아 있고 아무도 읽지 않는다.
# 큰 진은 둘레가 길어 **이미** 잉크를 더 먹으므로 할증은 이중 과금이었다. 새 코드에서 읽지 마라.
## ⚠ 폐기 — 미사용 (조준진이 없어져 가산할 대상이 없다)
@export var aimed_circle_ink_mult: float = 1.15
## ⚠ 폐기 — 진 크기 잉크 할증 (이중 과금으로 판명)
@export var circle_radius_ink_mult: float = 2.0

@export_group("기둥 = 응집(←) 착탄 축")
# ── 기둥 — 응집(←) 칸이 모인 착탄점에 선다 (gather 수만큼 굵다).
# 🔴 기둥 세기를 쥔 값은 아래 **지속·틱뿐이다** — 피해 배수 필드는 없다.
#   다시 넣을 땐 `_spawn_pillar`가 곱하게 **소비자를 같은 커밋에** 붙여라(안 그러면 값을 내려도
#   한 톨도 안 변하는 「거짓 손잡이」가 된다).
## 기둥 지속(초) — 이 동안 안에 있는 적을 계속 때린다
@export var pillar_duration_sec: float = 0.5
## 기둥이 적을 때리는 간격(초)
@export var pillar_tick_sec: float = 0.12
## 기둥 반경(px)
@export var pillar_radius_px: float = 14.0
## 같은 기둥이 겹쳐 서지 않는 최소 간격(px)
@export var pillar_merge_px: float = 12.0

@export_group("변형형 문양 = 확산·폭발 (세79 M1 진별 해석)")
# 🔴 전개형(발산·응집)과 계열이 다르다 — 확산·폭발은 착탄점에서 스스로 전개하는 게 아니라
# **안쪽 층의 결과를 받아 바꾸는 연산자**다.
#
# 🔴 확산·폭발의 수치(fan_deg·branch_mult·radius 계수…)는 **문양 `.tres`의 `params`에 있다 —
#   여기로 되돌리지 마라.** 전역이면 문양마다 다른 값을 못 줘서 「확산 46°」 옆에 「돌풍 120°」를
#   못 세운다. 기본값은 `glyph_rules.gd`의 `DEFAULTS`, 실제 값은 `data/glyphs/*.tres`.
## 🔴 착탄 전개 명령 수 상한 — **확산이 곱셈이라 층이 깊어지면 폭증한다.**
## 최악: 층0 발산 8칸 × 층1 확산 8칸 = 탄 64발, 산탄/둘레 진이면 캐리어가 여럿이라 수백 발.
## 지금 밴드 상한이 낮아 실전에선 안 나지만 진 등급이 깊어지는 순간 터진다 — 나중에 넣으면
## 밸런스가 이미 그 위에 서 있어 못 내린다. 넘치면 앞에서부터 자르고 경고를 남긴다.
@export var max_deploy_cmds: int = 48
## 다중 룬 세기 배분 — 진에 룬이 2개+면 각 룬 피해에 이 값을 곱해 합산해 진다(2룬 = base × 1.4).
## 룬 1개는 배율 없음(1.0) = 옛 도안 무회귀. "잘 쓰면 이득·못 써도 크게 손해 아니게"라
## 0.5(정확히 나눔)보다 높게 잡았다.
## ⚠ 위력 축이라 **책 리포트도 이걸 반영해야** 발사와 안 갈라진다.
@export var multi_rune_share: float = 0.7

@export_group("지팡이 = 발사 패턴 축 (v2.0)")
# 🔴 **그룹 이름이 낡았다 — 이 값들의 주인은 이제 「진」이다**(그룹 문자열은 저장·인스펙터에
# 걸려 있어 안 건드렸다). 읽는 자리는 `ring_spell_system._shot_plan(jin_def.pattern)` 하나이고,
# 지팡이가 주는 건 스칼라(`wand_speed_mult`·`wand_mana_mult`)뿐이다.
# ⚠ 형태를 지팡이로 되돌리지 마라 — 소스가 둘이 된다.
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
# 🔴 계약: `RuneDef.status_power`는 **「세기 배율」이다**(전 룬 1.0) — 상태의 기본 수치는 여기 있고
# 룬 배율이 그 위에 곱해진다. 룬마다 뜻이 다르면(불=초당피해·물=감속비율…) **특별잉크 증폭이
# 룬 절반에만 통한다.** 되돌리지 마라.
## 🔴 화상 초당 피해의 **기준값** — 실제 DoT = 이 값 × 룬의 status_power(배율).
@export var status_burn_dot_base: float = 3.0
## 🔴 반응 버스트(증기·감전연쇄) 피해의 **기준값** — 실제 피해 = 이 값 × 배율 × 각 반응의 mult.
## ⚠ 이 기준값을 빼고 `power × mult`로 계산하면 배율을 1.0으로 통일할 때 증기·연쇄가
## **1/3로 토막 나는데 에러도 테스트 실패도 없다.**
@export var status_burst_base: float = 3.0
## 🔴 감속의 상한 — `기본 감속 × 배율`이 아무리 커도 여기서 잘린다.
## ⚠ 1.0(완전정지)을 허용하면 안 된다 — 적이 이동 0이 되면 "느려졌다"와 "어그로가 풀렸다/죽었다"가
## 구분되지 않아 감속 테스트가 엉뚱한 이유로 통과한다.
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
## 🔴 특별잉크로 증폭된 세기는 **이 배수를 흔든다**(지속시간이 아니라) — 지속을 흔들면 조합의
## 보상이 「세기」가 아니라 「타이밍 여유」로 미끄러진다.
## ⚠ 증폭은 **선형**이다 — 곱으로 하면 취약 2배가 배수 2.25배로 튄다.
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
## 🔴 무성함(젖음+풀) — 반응 산물. **진흙보다도 오래 묶는다**(덩굴이 물을 먹고 자란다).
## 관계식이 설계다: **지속 무성함 > 진흙 > 덩굴** · **감속 무성함 ≥ 진흙**.
## ⚠ 이 두 값을 흔들 땐 위 진흙·덩굴 값과의 **부등호를 깨지 마라.**
## ⚠ 감속은 `status_slow_cap`이 위를 잘라 세기 배율이 조금만 붙어도 진흙과 체감이 같아진다 —
## 무성함의 실질 차별점은 감속이 아니라 지속시간이다.
@export var status_overgrowth_sec: float = 5.0
@export var status_overgrowth_slow: float = 0.88
## 감전 연쇄(젖음+번개) — 주변 이 반경(px) 안의 적에게 튄다 · 그 피해 배율
## 🔴 **적·허수아비 배치가 이 반경 안이어야 연쇄가 눈에 보인다** — 간격이 반경 밖이면
## 배선이 맞는데도 연쇄가 한 번도 안 터진다. 값을 줄이거나 배치를 벌릴 땐
## `src/base/base.tscn`의 Targets 좌표를 같이 봐라(씬 주석은 에디터 저장에 날아간다 — 여기가 정본).
@export var status_shock_chain_px: float = 90.0
@export var status_shock_chain_mult: float = 0.6
## 증기(젖음+불) — 즉발 폭발 반경(px) · 피해 배율
@export var status_steam_px: float = 70.0
@export var status_steam_mult: float = 0.8
## 확산(바람) — 붙은 상태가 이 반경(px) 안의 적에게 퍼진다
@export var status_spread_px: float = 110.0
## 상태 틱 간격(초) — 지속 피해를 이 주기로 넣는다. 짧을수록 부드럽고 무겁다
@export var status_tick_sec: float = 0.5

@export_group("전투")
@export var projectile_base_speed: float = 260.0
## 기준 피해. 위력에서 정확도 곱을 뗄 때(축 분리) 이 값을 0.9배 낮춰 **잘 그린 도안의 위력을
## 그대로 유지**했다 — 축 분리는 의도했지만 위력 인플레는 의도한 적이 없다.
@export var projectile_base_damage: float = 9.0
## 평소 이동 속도. 🔴 달리기를 얹을 땐 **바닥도 같이 올려라** — 평소가 느린 채로 달리기만 붙이면
## 「달리기를 안 쓰면 답답한 게임」이 된다.
@export var player_move_speed: float = 140.0
## 달리기 배수 — `GameState.run_speed()`가 `move_speed()`에 곱한다.
## 🔴 `move_speed()`의 **파생이라** 모자(HAT) 배수가 달리기에도 자동으로 실린다 — 두 값을 따로
## 두면 장비 효과가 한쪽에만 붙어 조용히 갈라진다.
@export var player_run_mult: float = 1.45
## 이동 가속/감속 — player.gd가 `_move_vel`을 목표 속도로 move_toward한다(즉시 대입이 아니라
## 램프라 스냅·무게감이 생긴다). accel ≈ 목표속도÷도달시간.
## ⚠ "느리다"의 본래 원인은 위 `player_move_speed`다 — 가속/감속은 붙는 맛이지 속도가 아니다.
@export var player_accel: float = 1400.0     ## 가속(px/s²) — 입력 방향으로 목표속도까지
@export var player_friction: float = 1800.0  ## 감속(px/s²) — 입력 없을 때 0까지
## 구르기 — 짧은 대시 + 대시 동안 무적 프레임. 대시 거리 = dash_speed × dash_duration_sec.
@export var dash_speed: float = 640.0
@export var dash_duration_sec: float = 0.2
@export var dash_cooldown_sec: float = 0.6
@export var player_hp_max: float = 100.0
## 탁본 모션 무방비 시간. ⚠ 소비자 0 — 탁본을 뜨는 모션이 아직 없다.
@export var rubbing_duration_sec: float = 1.5
## 기준 사거리(초). 실제 수명 = 이 값 × 진 사거리 배율
@export var projectile_lifetime_sec: float = 1.5

# ── 진 = 규모 + **투사체의 모양** 축 (v2.0) ──
# 🔴 ⚠ **이 그룹은 통째로 소비자 0이다.** 「그린 진 먹선이 그대로 날아간다」는 모델은 은퇴했다 —
# 지금은 마법진이 수식이고 해석된 원소 볼이 나간다. 위력은 `ring_power.power_of`가, 몸은
# `JinDef.body_scale`이 쥔다.
## 위력 배율 = circle_damage_base + circle_radius
@export var circle_damage_base: float = 0.5
## ⚠ 소비 중단 — 탄 크기는 진 반지름이 직접 정하므로 여기에 또 배율을 곱하면
## **같은 축을 두 번 적용**하게 된다. 기존 `.tres` 호환을 위해 필드만 남긴다.
@export var circle_size_min: float = 0.6
@export var circle_size_max: float = 1.8
## 사거리 배율 = lerp(min, max, circle_radius) → projectile_lifetime_sec에 곱해진다
@export var circle_range_min: float = 0.6
@export var circle_range_max: float = 1.4
## circle_radius(정규) → 월드 px 스케일. ⚠ 짝이던 먹선 몸(`InkRender`)이 없어져 지킬 상대가 없다.
@export var circle_radius_px: float = 48.0
## 종이 위의 진 → 날아가는 탄으로 줄이는 배율. 그린 크기 그대로 날리면 진 하나가 화면 폭의
## 상당 부분을 먹는다. ⚠ 먹선과 히트박스가 **같은 값**을 써야 보이는 것과 맞는 것이 안 어긋난다.
@export var projectile_circle_scale: float = 0.5
## 탄 히트박스 최소 반경(px) — 없으면 작은 진이 "그렸는데 아무것도 안 맞는" 탄이 된다.
@export var projectile_min_radius_px: float = 4.0

# ── 문양 = 발동 방식 + 세기 축 ──
# reach = 문양 획 길이 ÷ 진 반지름. 정규화 t = inverse_lerp(glyph_reach_min, glyph_reach_max, reach)
# → 0..1이 아래 전부의 입력이고, 소비자는 `projectile.reach_t`/`range_mult`다.
# 🔴 사거리는 **진이 기준을 주고 문양이 배율을 정한다** — 축을 도로 뺏지 마라.
## reach 하한 — 진을 겨우 뚫고 나간 짧은 문양
@export var glyph_reach_min: float = 0.6
## reach 상한 — 종이 끝까지 길게 뺀 문양 (이 위는 잘린다)
@export var glyph_reach_max: float = 3.0
## 사거리 배율 = lerp(min, max, t) → compute_lifetime의 진 사거리에 **곱해진다**
@export var glyph_range_min: float = 0.7
@export var glyph_range_max: float = 1.6
## 문양 세기 → 발당 마나 가산. 공짜면 "문양은 언제나 최대한 길게"가 유일한 정답이 된다.
## ⚠ 소비자 0.
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
## 추진 속도 배율 = lerp(min, max, t). ⚠ 짧게 그어도 한 번은 빨라져야 하므로 min > 1.0이다
## (0이면 길이 0인 추진이 아무 일도 안 하는 무효 문양이 된다).
@export var glyph_thrust_speed_min: float = 1.3
@export var glyph_thrust_speed_max: float = 2.4

# ── 룬 = 속성 농도 축 — 상태이상 세기를 룬 크기가 정하려던 축 ──
# 설계: 상태이상 세기 = RuneDef.status_power × lerp(density_min, density_max, rune_fill).
# 🔴 **위력에는 절대 물리지 않는다** — 그건 진의 축이다.
# ⚠ 아래 둘도, 입력인 `rune_fill`도 소비자가 0곳이다 — 살릴지 접을지 미결정이다.
#   되살릴 땐 곱하는 자리를 하나로 두고 소비자를 같은 커밋에 붙여라.
## 진 구석에 작게 그린 룬 = 옅게 스친다
@export var rune_density_min: float = 0.5
## 진을 꽉 채운 룬 = 깊이 물든다
@export var rune_density_max: float = 1.8

@export_group("고리 = 마력 주입 (세션 23)")
# 다 조립하면 분석이 위력을 보여 주고, [마력 주입]을 누르면 맺히거나 **펑** 한다.
# 규칙 계산은 `src/core/ring_power.gd`가 쥔다 — 조립 리포트와 발사가 같은 값을 봐야 해서 core다.
## 🔴 종합 점수가 **이 값 이하면 펑** — 도안이 날아가고 처음부터 다시 한다.
## 🔴 **등급의 최하단이기도 하다**(이 값 이하 = 「사용 불가」) — 등급 경계에 같은 숫자를 따로
## 적어 두면 이 값만 바꿨을 때 조용히 갈라져 「무난인데 터지는」 마법진이 생긴다.
## `ring_power.grade_of`가 `is_stable`을 그대로 불러 **두 경계가 한 값**이 되게 한다.
## ⚠ 이 값은 위력 곡선에 안 들어간다 — 견디느냐(이 값)와 얼마나 세냐(아래)는 별개 축이다.
@export var ring_stability_min: float = 0.65
## 만점(100점) 마법진의 위력 배율
@export var ring_power_max: float = 1.6
## 🔴 점수 → 위력 곡선의 지수: **위력 = ring_power_max × 점수^이 값**(1=선형).
## 왜 곡선이냐: 기준선~만점을 선형 보간하고 아래를 clamp하면 미달 구간이 전부 같은 값으로 떠서
## 그 평평함 자체가 「너 지금 미달」이라는 **주입 전 안내**가 된다. 지수 곡선은 0점→0, 만점→max로
## 이어져 평평한 구간이 없다.
@export var ring_power_curve: float = 2.0

# ── 🔴 그리기 폐지 — **끄고 켜는 스위치다.** `skip_drawing = false`로 되돌리면 손 긋기 흐름이
# 그대로 돌아온다(채점기·펜·잉크 코드를 하나도 안 지웠다).
# 켜면: 조립을 마치는 순간 마법진이 완성되고 **점수를 손이 아니라 부품이 정한다**.
## 손 긋기 단계를 건너뛴다 (true = 조립만으로 완성)
@export var skip_drawing: bool = true
## 조립 점수의 바탕 — 🔴 `ring_stability_min`보다 **커야 한다**. 안 그러면 멀쩡히 조립하고도
## 「펑」이 나는데, 폐지 모드에선 그 펑을 만회할 수단(더 잘 긋기)이 아예 없다.
@export var assemble_score_base: float = 0.70
## 칸에 놓인 문양 하나당 점수
@export var assemble_score_per_glyph: float = 0.03
## 층(밴드) 하나 늘 때마다 점수 (첫 층은 바탕에 포함)
@export var assemble_score_per_layer: float = 0.05

# ── 시전 시간·감속 ──────────────────────────────────────────────────────────
## 🔴 **밸런스 계약 — 강한 마법진은 DPS가 아니라 「한 방」이다.** 위력이 오르는 만큼보다 시전이
## 더 느려져 DPS가 떨어지는 것이 의도다(강한 마법진은 위기에 터뜨리는 물건이지 난사용이 아니다).
## 덤으로 슬롯 3개가 새 시스템 0개로 「속사용 하나 · 한방용 하나」로 갈린다.
## 🔴 **연출값(크기·밝기·색·수명)은 여기 두지 마라** — 그건 스크립트 `const`다.
##   여기 있는 건 **DPS를 바꾸는 것뿐**이고, 그게 두 축을 가른 기준이다.
## 🔴 **읽는 문은 `RingPower.cast_time_of`·`cast_move_mult_of` 하나다** — 여기서 직접 lerp하지 마라
##   (점수 0~1을 그대로 쓰면 안 되는 품질 정규화가 그 안에 있다).
## ⚠ 이름의 plain/perfect는 **품질 양 끝**을 가리키는 라벨일 뿐이다 — 등급 이름과 `==` 비교하지 마라.
##
## 🔴🔴 **지금 둘 다 0이다 = 차징이 꺼져 있고, 위 「밸런스 계약」도 같이 죽어 있다**
##   (강한 마법진이 그냥 우월해진다). 이 두 값이 곧 스위치라 0.15/0.75로 되돌리면 차징이 산다 —
##   `player_caster.fire()`의 `if duration <= 0.0` 분기가 그 되돌림을 위해 남아 있다.
##   ⚠ **바닥 마법진도 같이 꺼진다** — `vfx`가 `duration <= 0`이면 원을 안 연다(채워지는 것을
##   보여줄 대상이 없다). 되돌리면 그것도 같이 살아난다.
##   ⇒ 시전 시간 말고 다른 축(마나·쿨다운·이동 배수)으로 대가를 물릴 수도 있다.
##   ⚠ `cast_move_mult_*`는 일부러 안 건드렸다 — 차징을 되살리는 날 같이 살아나야 하는 짝이다.
@export var cast_time_plain_sec: float = 0.0
## 퍼펙트 진의 시전 시간 — 지금 0. 옛값 0.75("공들인 것을 쓴다"가 몸으로 느껴지는 길이)
@export var cast_time_perfect_sec: float = 0.0
## 시전 중 이동 배수 — 무난한 진(거의 그대로 움직인다)
@export var cast_move_mult_plain: float = 0.85
## 시전 중 이동 배수 — 퍼펙트 진(눈에 띄게 무겁다 = 그게 위험이다)
@export var cast_move_mult_perfect: float = 0.45

# ── 등급 경계 ────────────────────────────────────────────────────────────────
# 🔴 **최하단 경계는 여기 없다** — 그건 위 `ring_stability_min`이다(그 이하 = 「사용 불가」).
# 아래 넷은 "쓸 수 있는" 마법진 안에서의 칸이다. 등급 이름은 코드(ring_power.gd) — 수치만 여기.
## 「무난」 → 「평타」
@export var ring_grade_fair: float = 0.75
## 「평타」 → 「괜찮음」
@export var ring_grade_good: float = 0.85
## 「괜찮음」 → 「완벽」
@export var ring_grade_great: float = 0.95
## 🔴 「완벽」 → 「퍼펙트」. **0.995인 이유**: 리포트가 점수를 `round(점수×100)`으로 찍으므로
## 이 값이 곧 "화면에 100으로 뜨는 순간"이다. 올리면 **100점이라 적어 놓고 완벽**이라는 어긋남이
## 생긴다 — 표시 반올림과 묶인 값이다.
@export var ring_grade_perfect: float = 0.995

@export_group("종이·특별잉크 (세션29)")
# 🔴 종이=규모 · 특별잉크=상태증폭. 잉크 등급=데미지(`power_mult`)와 **다른 레버**다.
## 진 크기(jin_scale) → 데미지 지수. size_mult = jin_scale ^ 이 값(1=선형, <1=완화).
## 종이 등급이 jin_scale 상한을 올리므로 이게 "큰 진=데미지↑"의 세기다.
## ⚠ 잉크 배수와 **겹쳐서** 곱해진다 — 둘 다 데미지라 폭주 주의.
@export var paper_size_power_exp: float = 1.0
## 종이 없이 그릴 때의 기본 진 확대 상한 (= paper_basic의 zoom_max와 맞춘다).
## ⚠ 소비자 0 — 종이 축이 은퇴해 진 규모가 1.0 고정이다.
@export var paper_zoom_max_default: float = 1.16
## 특별잉크 획당 소모량 — 그리는 동안 실시간으로 닳는다.
## 다 떨어지면 소모·효과 적립 없이 계속 그린다 — 그만큼 비율(효과)이 낮아진다.
@export var special_ink_per_stroke: int = 1

@export_group("경제")
# 🔴 ⚠ **이 그룹은 통째로 소비자 0이다.** 내구·수리 시스템은 아직 없고(도안은 안 닳는다)
#   해독대는 은퇴했다. 지우지 않고 표시만 한다 — 되살리려면 소비자(수리 UI·해독 진행)를
#   같은 커밋에 붙여라.
## 수리비 = 원본 ink_cost 대비 비율
@export var repair_cost_frac: float = 0.2
## 응급 수리: 비용 배율 (일반 수리비 대비)
@export var emergency_repair_cost_mult: float = 0.5
## 응급 수리: 회복 상한 (durability_max 대비 비율)
@export var emergency_durability_frac: float = 0.3
## 해독 소요 (플레이 시간). ⚠ 해독대 자체가 은퇴했다.
@export var research_time_sec: float = 600.0

# ── ⚠ 홀드형 상호작용을 다시 만들 때 알아야 할 것: **홀드는 폴링(`_process`)으로 재라 —
#    「뗐나」를 이벤트로 받으면 에러 0으로 깨진다**(화면 덮는 Control이 뗀 이벤트를 먹고,
#    alt-tab이면 엔진이 액션만 풀고, 모달 중엔 `_unhandled_input`이 안 온다).
#    실측이 `player_caster._tick_cast` 머리말에 살아 있다 — 거기서 읽어라.
#    ⚠ 홀드를 되살리면 **실눌림(`Input.action_press`) 그물을 같이 세워라** —
#      안 그러면 입력이 안 닿는데 전 스위트가 그린이 된다.
