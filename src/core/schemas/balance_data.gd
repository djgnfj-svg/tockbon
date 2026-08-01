class_name BalanceData
extends Resource
## 밸런스 수치 원장 — 코드에 수치를 박지 않는다.
## 인스턴스: res://data/balance.tres · 프로토 손맛 튜닝은 전부 여기서.
##
## ⚠ **소비자 0인 필드가 여럿 남아 있다**(그리기 폐지·종이 축 은퇴·경제 미구현의 잔재). 이 파일의
## 규약은 「지우지 않고 **표시**한다」이다(아래 `station_build_costs` 자리와 같은 결) — 값을
## 흔들어 보고 아무 일도 안 나면 주석의 「⚠ 소비자 0」을 먼저 봐라. 되살릴 땐 **소비자를 같은 커밋에**.

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
## ⚠ **소비자 0** (세86 실측 — 위 `cast_mana_cost` 주석대로 부품 비용을 합산하는 곳이 없다).
## 🔴 되살릴 땐 **인덱스로 룬을 짚지 마라**: `Enums.RuneType`은 `[0,2,3,4,5,6]`으로 값이 연속이
## 아니고(1=옛 충격 구멍) 지금 룬은 6종인데 이 배열은 4칸이다 — 「없는 룬」이 만들어진다.
@export var rune_mana_base: PackedFloat32Array = PackedFloat32Array([8.0, 6.0, 7.0, 9.0])
## 화살표 1발당 마나. ⚠ 소비자 0 (세86 실측).
@export var mana_per_arrow: float = 3.0
## 진 규모 → 마나 가산 (v1.6). 진이 위력·크기·사거리를 전부 주므로 시전 비용에도 진 축을
## 붙이려던 값 — 잉크만 물리면 큰 진이 일방적으로 우월해진다. ⚠ 소비자 0 (세86 실측).
@export var circle_mana_mult: float = 6.0
## magnitude 1.0이 되는 화살표 획 길이 (캔버스 정규).
## v1.6: magnitude는 **전투 스탯에서 분리됐다**. ⚠ 소비자 0 (세86 실측).
@export var arrow_full_length: float = 0.45
## 획 길이(정규)당 잉크 소모 — 먹의 양(길이 × 굵기) → 잉크 단위. **잉크는 통에서 나온 양이다**(v1.8).
## 종이 상한 판정과 제작 비용에 **같은 값**으로 쓰라고 둔 계수(할증 없음). ⚠ 소비자 0 (세86 실측 —
## 세83 그리기 폐지로 획이 안 생긴다. `balance.skip_drawing`을 되돌리면 다시 필요해진다).
@export var ink_per_stroke_length: float = 10.0
## 인식 정확도 보정 하한. v1.7: 위력이 아니라 **속성 순도**의 하한이다. ⚠ 소비자 0 (세86 실측).
@export var accuracy_floor: float = 0.6
## ⚠ **폐기 — 미사용** (세션 23). 보정은 **바닥값이 없다**: 펜을 안 끼면 0(그린 대로)이고
## 보정도는 전적으로 펜 아이템이 준다(`data/items/pen_*.tres`의 params.correction).
## 여기 상수를 깔면 맨손에도 보정이 붙어 "자기만의 마법진" 정체성과 어긋난다.
## 읽는 곳은 `GameState.stroke_correction()` 하나뿐이고, 이제 그 함수가 이 값을 안 본다.
@export var stroke_correct_strength: float = 0.55
## 룬 농도 → 마나 가산 (v1.7). 진과 같은 이유로 시전 비용에 붙이려던 값 —
## 안 물리면 "룬은 언제나 최대한 크게"가 유일한 정답이 된다. ⚠ 소비자 0 (세86 실측).
@export var rune_density_mana_mult: float = 4.0
# ── ⚠ 아래 둘은 **폐기됐다** (v1.8). 스키마에만 남아 있고 **아무도 읽지 않는다** ──
# 잉크는 통에서 나온 양이므로 **할증을 붙이지 않는다**.
# 큰 진은 둘레가 길어서 **이미** 잉크를 더 먹는다 — 할증은 **이중 과금**이었다.
# 새 코드에서 이 값을 읽지 말 것. (구세이브 .tres 호환을 위해 필드만 남긴다)
## ⚠ 폐기 — 미사용 (v1.5 조준진 폐지로 가산할 대상이 없어짐)
@export var aimed_circle_ink_mult: float = 1.15
## ⚠ 폐기 — 진 크기 잉크 할증 (v1.8에서 이중 과금으로 판명, 제거됨)
@export var circle_radius_ink_mult: float = 2.0

@export_group("기둥 = 응집(←) 착탄 축")
# ── 기둥 — 응집(←) 칸이 모인 착탄점에 선다 (ring_spell_system._spawn_pillar, gather 수만큼 굵다)
# 🔴 **세85: `pillar_damage_mult`(피해 배수)를 걷었다** (세84 감사 #20 · 사용자 결정 ⑧).
# 소비자가 0곳이었다 — `_spawn_pillar`는 `pillar.setup(fire.damage, …)`로 **배수 없이** 넘기고,
# 옛 소비자였던 `shockwave.gd`는 세67에 삭제됐다. 그런데 주석은 「기둥 피해 = 탄 피해 × 이 값」이라
# 적혀 있어 **0.9→0.4로 내려도 한 톨도 안 변하는데** 조인 줄 알게 만들었다(감사 T3 「거짓 손잡이」).
# 지금 기둥 세기를 쥔 값은 아래 **지속·틱**뿐이다(수명 0.5 ÷ 틱 0.12 = 4~5틱).
# ⚠ 되살리려면 **소비자를 같은 커밋에** 붙여라(`_spawn_pillar`가 곱하게) — 그게 ⑧의 규율이다.
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
#
# 🔴🔴 **세82: 이 그룹의 수치 7개가 문양 `.tres`의 `params`로 이사했다** (문양 효과 데이터화).
#   spread_fan_deg · spread_branch_mult · spread_offset_px ·
#   blast_base_radius_px · blast_radius_per_branch · blast_radius_per_count · blast_merge_mult
# 왜: 전역이면 **문양마다 다른 값을 못 준다.** 「확산 46°」 옆에 「돌풍 120°」를 세우려면 수치가
# 그 문양에 딸려야 한다. 응축이 폭발과 같은 `blast` 알고리즘을 쓰면서 반경 계수 **부호만** 뒤집는 게
# 그 첫 사례다 — 새 함수 없이 `.tres` 한 장이 「좁게 모아 세게」가 된다.
# → **되살리지 마라.** 기본값은 `src/core/glyph_rules.gd`의 `DEFAULTS`, 실제 값은 `data/glyphs/*.tres`.
# ⚠ 손맛은 여전히 **F5로 조인다** — 조이는 자리가 balance 한 장에서 문양 .tres 여러 장으로 옮겼을 뿐이다.
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
# 🔴🔴 **그룹 이름이 낡았다 — 이 값들의 주인은 이제 「진」이다**(세85, 감사 #5. `@export_group`
# 문자열은 저장·인스펙터에 걸려 있어 안 건드렸다). 지팡이가 발사 **형태**를 쥐던 축은 은퇴했고
# (도달 불가였다 — `enums.gd`의 `WandPattern` 주석), 지금 아래 값을 읽는 자리는
# `ring_spell_system._shot_plan(jin_def.pattern)` **하나**다. 지팡이가 주는 건 스칼라
# (`wand_speed_mult`·`wand_mana_mult`)뿐이다. ⚠ 형태를 지팡이로 되돌리지 마라 — 소스가 둘이 된다.
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
# 🔴🔴 **세션50 계약: `RuneDef.status_power`는 「세기 배율」이다**(전 룬 1.0) — 상태의 **기본 수치는
# 여기** 있고 룬 배율이 그 위에 곱해진다. 룬마다 뜻이 다르면(불 3.0=초당피해·물 0.35=감속비율…)
# **특별잉크 증폭(`Db.status_mult_of`)이 룬 절반에만 통한다** — 실제로 그랬다. 되돌리지 마라.
# ⚠ 감전 연쇄 세기(0.6→1.8)만 그 정리로 실제 변했다 — **맞는 값인지는 쏴 봐야 정해진다.**
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
## 🔴 무성함(젖음+풀) — 반응 산물(세86 ⑤a). **진흙보다도 오래 묶는다**(덩굴이 물을 먹고 자란다).
## 관계식이 설계다: **지속 무성함(5.0) > 진흙(3.5) > 덩굴(2.0)** · **감속 무성함(0.88) ≥ 진흙(0.85)**.
## ⚠ 감속은 `status_slow_cap`(0.90)이 위를 자른다 — 세기 배율이 조금만 붙어도 진흙과 **둘 다 상한에
## 눌려 체감이 같아진다**. 그래서 무성함의 실질 차별점은 감속이 아니라 **지속시간**이다.
## 이 두 값을 흔들 땐 위 진흙·덩굴 값과의 **부등호**를 깨지 마라(`test_status_auto`[13]이 잰다).
@export var status_overgrowth_sec: float = 5.0
@export var status_overgrowth_slow: float = 0.88
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
## v1.7: 10.0 → 9.0. 위력에서 rune_accuracy(0.6~1.0) 곱을 떼면서(축 분리)
## 곱하던 값이 사라져 위력이 통째로 올라갔다 — 잘 그린 도안 +11%, 막 그린 도안 **+67%**.
## 축 분리는 의도했지만 **위력 인플레는 의도한 적 없다.** 기준을 0.9배 낮춰
## **잘 그린 도안(accuracy≈0.9)의 위력을 v1.6과 같게** 되돌린다.
## 부수 효과: 이제 막 그린 도안도 같은 위력이 나온다 — 그게 축 분리의 요지다
## (엉망으로 그린 대가는 위력이 아니라 **속성 순도**로 치른다)
@export var projectile_base_damage: float = 9.0
## 🔴 세97: 120 → 140 (사용자 *"걷기도 좀 빠르게"*). 달리기를 얹으면서 **바닥도 같이 올렸다** —
## 평소 이동이 느린 채로 달리기만 붙이면 「달리기를 안 쓰면 답답한 게임」이 된다.
@export var player_move_speed: float = 140.0
## 🔴 달리기 배수 (세97 · 스페이스 홀드) — `GameState.run_speed()`가 `move_speed()`에 곱한다.
## **`move_speed()`의 파생이라 모자(HAT) 배수가 달리기에도 자동으로 실린다** — 두 값을 따로 두면
## 장비 효과가 한쪽에만 붙어 조용히 갈라진다(세42 「부적 배수를 아무도 안 보던」 병의 사촌).
## 잠정값 — ⚠ 손맛은 F5가 정한다(140 × 1.45 ≈ 203px/s).
@export var player_run_mult: float = 1.45
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
## 탁본 모션 무방비 시간. ⚠ 소비자 0 (세86 실측 — 필드에서 탁본을 뜨는 모션이 아직 없다).
@export var rubbing_duration_sec: float = 1.5
## 기준 사거리(초). 실제 수명 = 이 값 × 진 사거리 배율
@export var projectile_lifetime_sec: float = 1.5

# ── 진 = 규모 + **투사체의 모양** 축 (v2.0) ──
# 위력·크기·기준 사거리를 진이 정한다. 셋 다 circle_radius(0..1)를 입력으로 받고,
# circle_radius 0.5(캔버스 절반)가 기준점 ≈ 1.0배.
# 🔴🔴 ⚠ **이 그룹은 통째로 소비자 0이다**(세86 실측 — `circle_damage_base`·`circle_size_*`·
# `circle_range_*`·`circle_radius_px`·`projectile_circle_scale`·`projectile_min_radius_px` 전부).
# 「그린 진 먹선이 그대로 날아간다」는 v2.0 모델은 **세72에 은퇴했다** — 지금은 마법진이 수식이고
# (안 날아간다) 해석된 원소 볼이 나간다. 위력은 `ring_power.power_of`가, 몸은 `JinDef.body_scale`이 쥔다.
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
## circle_radius(정규) → 월드 px 스케일. ⚠ 짝이던 `InkRender`(먹선 몸)는 **세22에 매장됐다** —
## "InkRender.unit_px = 이 값 × 2" 계약은 지킬 상대가 없다(`projectile.gd` 머리 주석 참조).
@export var circle_radius_px: float = 48.0
## 🔴 **v2.0: 종이 위의 진 → 날아가는 탄**으로 줄이는 배율. 종이에 그린 크기 그대로 날리면
## 진 하나가 화면 폭의 상당 부분을 먹는다 (캔버스 절반짜리 진 = 반지름 24px, 적이 32px인 세계에서).
## 먹선과 히트박스가 **같은 값**을 쓴다 — 갈라지면 보이는 것과 맞는 것이 어긋난다
@export var projectile_circle_scale: float = 0.5
## 탄 히트박스 최소 반경(px) — 진을 아주 작게 그려도 **보이고 맞아야 한다**.
## 없으면 작은 진이 "그렸는데 아무것도 안 맞는" 탄이 된다
@export var projectile_min_radius_px: float = 4.0

# ── 문양 = 발동 방식 + 세기 축 (v1.9) — GDD §4 「세 축」 ──
# reach = 문양 획 길이 ÷ 진 반지름. 정규화 t = inverse_lerp(glyph_reach_min, glyph_reach_max, reach)
# → 0..1 이 아래 전부의 입력이고, 소비자는 `projectile.reach_t`/`range_mult`다(세86 실측).
# ⚠ 옛 `ArrowData` 스키마는 없다 — reach는 발사부가 넘기는 인자다.
# 사거리는 **진이 기준을 주고 문양이 배율을 정한다** — 축을 도로 뺏지 않는다.
## reach 하한 — 진을 겨우 뚫고 나간 짧은 문양
@export var glyph_reach_min: float = 0.6
## reach 상한 — 종이 끝까지 길게 뺀 문양 (이 위는 잘린다)
@export var glyph_reach_max: float = 3.0
## 사거리 배율 = lerp(min, max, t) → compute_lifetime의 진 사거리에 **곱해진다**
@export var glyph_range_min: float = 0.7
@export var glyph_range_max: float = 1.6
## 문양 세기 → 발당 마나 가산 (t에 비례). 진·룬과 같은 이유 —
## 공짜면 "문양은 언제나 최대한 길게"가 유일한 정답이 된다. ⚠ 소비자 0 (세86 실측).
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

# ── 룬 = 속성 농도 축 (v1.7) — 상태이상 세기를 룬 크기가 정하려던 축 ──
# 설계: 상태이상 세기 = RuneDef.status_power × lerp(density_min, density_max, rune_fill).
# **위력에는 절대 물리지 않는다** — 그건 진의 축이다 (축 위반 방지).
# 🔴 ⚠ **아래 둘도, 입력인 `rune_fill`도 소비자가 0곳이다**(세86 실측 · `ring_spell_system`이
# 같은 자리에 적어 뒀다). CLAUDE.md 「남은 빚」의 *"rune_fill의 소비자가 0곳"*이 바로 이것 —
# 살릴지 접을지 **미결정**이다. 되살릴 땐 곱하는 자리를 하나로 두고 소비자를 같은 커밋에.
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

# ── 🔴 그리기 폐지 실험 (세83, 사용자: *"조립해서 자신의 마법을 만드는거지"*) ──────────────
# **끄고 켜는 스위치다.** `skip_drawing = false`로 되돌리면 손 긋기 흐름이 **그대로** 돌아온다 —
# 채점기·펜·잉크 코드는 하나도 안 지웠다(사용자 확정: *"먼저 꺼보고 판단"*).
# 켜면: 조립을 마치는 순간 마법진이 완성되고, **점수를 손이 아니라 부품이 정한다**.
## 손 긋기 단계를 건너뛴다 (true = 조립만으로 완성)
@export var skip_drawing: bool = true
## 조립 점수의 바탕 — 🔴 `ring_stability_min`보다 **커야 한다**. 안 그러면 멀쩡히 조립하고도
## 「펑」이 나는데, 폐지 모드에선 그 펑을 만회할 수단(더 잘 긋기)이 아예 없다.
@export var assemble_score_base: float = 0.70
## 칸에 놓인 문양 하나당 점수
@export var assemble_score_per_glyph: float = 0.03
## 층(밴드) 하나 늘 때마다 점수 (첫 층은 바탕에 포함)
@export var assemble_score_per_layer: float = 0.05

# ── 시전 시간·감속 (세98 · 정본 = docs/takbon-design/spell_cast_visual_design.md) ──────
## 🔴🔴 **밸런스 계약 — 강한 마법진은 DPS가 아니라 「한 방」이다.**
## 위력은 2배 오르는데(78→157) 시전이 그보다 더 느려지면 **DPS가 떨어진다. 버그가 아니라 의도다** —
## 강한 마법진은 위기에 터뜨리는 물건이지 난사하는 물건이 아니다(사용자 확정 · 노이타형 긴장).
## 🟢 덤: 슬롯 3개가 **새 시스템 0개로** 「속사용 하나 · 한방용 하나」로 갈린다.
## 🔴 **연출값(크기·밝기·색·수명)은 여기 두지 마라** — 그건 스크립트 `const`다(VFX_SPEC §4).
##   여기 있는 건 **DPS를 바꾸는 것뿐**이다. 그게 두 축을 가른 기준이다.
## 🔴 **읽는 문은 `RingPower.cast_time_of`·`cast_move_mult_of` 하나다** — 여기서 직접 lerp하지 마라.
##   품질 정규화(하한이 `assemble_score_base`라 점수 0~1을 그대로 쓰면 안 된다)가 그 안에 있다.
## ⚠ 이름의 plain/perfect는 **품질 양 끝**을 가리키는 라벨일 뿐이다 —
##   등급 이름과 `==` 비교하는 데 쓰지 마라(세24: 이름을 바꾸는 순간 조용히 깨진다).
## ⚠ 넷 다 **잠정값이다 — 손맛은 F5가 정한다**(설계 §3: *"수치는 그 문서가 안 정한다"*).
## 무난한 진(품질 하한)의 시전 시간 — 거의 즉발로 느껴져야 한다
@export var cast_time_plain_sec: float = 0.15
## 퍼펙트 진의 시전 시간 — "공들인 것을 쓴다"가 몸으로 느껴지는 길이
@export var cast_time_perfect_sec: float = 0.75
## 시전 중 이동 배수 — 무난한 진(거의 그대로 움직인다)
@export var cast_move_mult_plain: float = 0.85
## 시전 중 이동 배수 — 퍼펙트 진(눈에 띄게 무겁다 = 그게 위험이다)
@export var cast_move_mult_perfect: float = 0.45

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
## ⚠ 소비자 0 (세86 실측 — 세71d에 종이 축이 은퇴해 진 규모가 1.0 고정이다,
## `ring_forge_panel`의 `_size_mult` 주석).
@export var paper_zoom_max_default: float = 1.16
## 특별잉크 획당 소모량 — 그리는 동안 실시간으로 닳는다 (사용자: "그릴 때 실시간으로 소비").
## 다 떨어지면 소모·효과 적립 없이 계속 그린다(기본잉크처럼) — 그만큼 비율(효과)이 낮아진다.
@export var special_ink_per_stroke: int = 1

# ── 🔴 세85: `station_build_costs`(거점 건설 비용 dict)를 통째로 걷었다 ──────────────────
# (세84 감사 #20·#32 · 사용자 결정 ⑧·⑩). **dict 전체의 소비자가 0곳**이었다.
# 세66 도파민 재편이 「빈 거점 재료 건설」을 은퇴시켜(마을은 처음부터 완비) `base.gd`가 더는
# 비용을 사지 않는데, 비용표만 남아 「건설 게이트가 아직 있다」는 거짓 신호를 줬다(감사 T2·T3).
# ⚠ **「새 스테이션 = 여기 한 줄」은 이제 거짓이다** — 새 스테이션 = `base.tscn` 노드 + `base.gd`
#   존 배선뿐이다(건설 단계가 없다). 되살리려면 `base.gd`의 `_station_interact` 계열을 같이 살려라.
# 되돌림 = git 이력.

@export_group("경제")
# 🔴 ⚠ **이 그룹은 통째로 소비자 0이다** (세86 실측 — 넷 다 정의 한 줄씩뿐). 뜻은 아래에 남긴다:
#   내구·수리 시스템은 아직 없고(도안은 안 닳는다), **해독대는 세85 ⑩에 은퇴했다**.
#   위 `station_build_costs` 자리와 같은 규약으로 지우지 않고 표시만 한다 — 되살리려면
#   소비자(수리 UI·해독 진행)를 같은 커밋에 붙여라.
## 수리비 = 원본 ink_cost 대비 비율
@export var repair_cost_frac: float = 0.2
## 응급 수리: 비용 배율 (일반 수리비 대비)
@export var emergency_repair_cost_mult: float = 0.5
## 응급 수리: 회복 상한 (durability_max 대비 비율)
@export var emergency_durability_frac: float = 0.3
## 해독 소요 (플레이 시간 — 약 10분). ⚠ 해독대 자체가 은퇴했다(세85 ⑩).
@export var research_time_sec: float = 600.0

# ── 💀 `extract_hold_sec`(3.0 — 출구에서 [E]를 꾹 누르는 초)을 **세112에 지웠다**
#    (`room_loop_design.md` R1 · genre_pivot D1 「탈출 홀드 폐기」). 값·근거 전문은 `git show`.
#
# 🔴 **되살릴 때 그대로 쓸 수 있는 결론 둘 — 값보다 이게 비쌌다**:
#  ① **홀드는 폴링(`_process`)으로 재라 — 「뗐나」를 이벤트로 받지 마라.** 실측 셋이 전부 에러 0으로 깨진다:
#     화면 덮는 Control이 뗀 이벤트를 먹고 · alt-tab이면 엔진이 액션만 풀고 · 모달 중엔 `_unhandled_input`이 안 온다
#     (`player_caster._tick_cast` 머리말에 같은 실측이 살아 있다 — **거기서 읽어라**).
#  ② 값의 소유자를 **씬 `@export`가 아니라 balance**에 둔 이유 = 출구가 여럿이면 출구마다 한 벌이 생겨 튜닝값이 흩어진다.
#
# ⚠ **세112에 같이 죽은 것 — `Input.action_press`로 [E]를 진짜 누르던 유일한 그물**(`test_extract_hold_auto`).
#   R9가 나가는 길을 다시 세우면 **실눌림 그물을 새로 세워라** — 안 그러면 세25 자리다(클릭이 안 닿는데 전 스위트 그린).

# ── 💀 시야(세104) · 몬스터 인지(세105) 손잡이 다섯을 **세112에 지웠다**
#    (`room_loop_design.md` R3·R10 · genre_pivot D8 「전부 걷는다」).
#    사라진 것: `vision_fan_deg`(100) · `vision_fan_range`(560) · `vision_near_radius`(110)
#              · `percept_sound_radius_min_px`(240) · `percept_sound_radius_max_px`(700)
#    값·근거 전문은 `git show` (이 커밋의 부모).
#
# 🔴🔴 **되살릴 때 반드시 알아야 하는 것 — 소리 반경 둘은 그냥 수치가 아니었다.**
#    「마법 소리 = 위력」(사용자 확정 ⓔ)은 **조립 점수가 전투 피해 밖에서 무언가를 하던 유일한 자리**였다
#    — *「한 방에 조용히」* 대 *「다 불러내고 광역으로」*를 조립 단계의 선택으로 만들던 축이다.
#    ⇒ 되살리려면 값을 되돌리는 게 아니라 **그 축을 방 단위 전투에서 다시 설계해야 한다**
#      (세112에 사용자가 「같이 죽인다」를 고른 이유 = 방은 문 열고 들어가 다 쓸어버리는 곳이라 잠입할 여지가 없다).
#
# ⚠ `vision_near_radius` 110에 딸렸던 사용자 결정 하나도 같이 묻힌다 —
#   세107에 차폐가 은퇴해 그 값의 근거가 사라졌는데도 사용자가 *"지금 값 유지"*를 골라
#   **「좁은 게 좋아서 좁은 값」**이 돼 있었다. 시야를 되살리는 날 220으로 되돌린다고 혼자 판단하지 마라.
