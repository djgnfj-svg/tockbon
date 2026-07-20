extends Node
## 모듈 간 시그널 허브 — 유일한 교차 모듈 통신 경로 (TECH_SPEC §5).
## 시그널 추가·변경은 리드만.
##
## 🔴 2026-07-17 세션 22: 옛 SpellDesign(자유 드로잉) 경로의 시그널 17종을 **매장했다.**
## 세션 21 대청소로 발신자·수신자가 모두 사라졌는데 시그널만 남아, 시그니처가 SpellDesign·EnemyDef를
## **타입으로** 붙들어 그 스키마를 못 지우고 있었다. 되돌리려면 git 이력.

@warning_ignore_start("unused_signal")

# ── 고리 조립 캐스팅 (세션 12~) — 지금의 유일한 발사 경로
# 🔴 고리 모델(진=날아가는 몸, 문양=착탄 전개)은 assembly 사전을 싣는다.
# assembly = ring_board.get_assembly() = {ring_count, rune, rings:[[8칸]], open:[...]}.
# ring_spell_system(모듈 B)이 수신 → 진(캐리어)을 조준 방향으로 쏜다.
signal ring_cast_requested(assembly: Dictionary, origin: Vector2, aim_dir: Vector2)
# 🔴 #17 1단계 — 고리 도안이 맺혔다 (베이스캠프 조립 책 → GameState).
# GameState가 수신 → ring_designs에 넣고 빈 ring_equipped 슬롯에 즉시 장착.
signal ring_design_committed(design: RingDesign)

# ── 전투 (B ↔ C)
signal enemy_hit(enemy: Node2D, damage: float, rune_type: int)
## 🔴 적이 죽었다 (세션 36). forest_enemy._die가 발신 → GameState가 KILL 퀘스트를 센다.
## enemy_hit(매 타격)과 다르다 — 이건 **처치 순간 1회**다. 세션 26 forest_enemy의 `died`
## 로컬 시그널("킬카운트가 붙는 날의 자리표")이 마침내 수신자를 얻은 것이다.
signal enemy_died(enemy_id: StringName)
## ⚠ 발신자 없음 = **HUD가 세션 21에 삭제돼서**다. 발신 측(GameState)은 계약을 지키고 있다 — 지우지 마라.
signal player_hp_changed(hp: float, hp_max: float)

# ── 익스트랙션 (C → D·E)
## 🔴 **발신자 없음 = 필드(원정)가 아직 없어서**다. 수신자는 이미 연결돼 있다
## (GameState 가방 정산 · SaveManager 자동 저장). 필드를 붙이는 쪽이 이 둘을 emit해야 하며,
## 안 그러면 **조용히 안 도는 채로** 시작한다 — 계약이지 죽은 코드가 아니다. 지우지 마라.
signal extraction_success
signal bag_lost

# ── 시간 (Clock → 전체)
## ⚠ 발신자는 있고 수신자가 없다(HUD 삭제 탓). day_started는 SaveManager 자동 저장이 받는다.
signal phase_changed(phase: int)
signal day_started(day: int)

# ── 도감 해금 (누구든 범용 해금)
signal codex_unlocked(unlock_id: StringName)

# ── 퀘스트 (진행 목표 = 깊이 스파인, 세션 36)
## GameState가 목표를 완료했을 때 발신 → 퀘스트 패널 갱신·HUD 알림·사운드. quest_id로 무엇이 끝났는지.
signal quest_completed(quest_id: StringName)
## 진행 카운트가 늘었을 때 (완료 아님) — 패널이 열려 있으면 진행 막대를 다시 그린다.
signal quest_advanced(quest_id: StringName)
## 🔴 목표를 방금 채웠다 (세션40 턴인) — 아직 완료는 아니다. 길잡이에게 돌아가 정산하라는 신호.
## HUD가 "달성! 돌아가라" 넛지를 띄우고, NPC 머리 위 물음표가 켜진다. 완료는 claim_ready_quests()에서만.
signal quest_ready(quest_id: StringName)
## 🔴 새 목표를 "읽었다" (세션43) — 시트(Tab 퀘스트 탭)를 열어 접수하면 발신. NPC 머리 위 [!]를 끄러
## base가 _refresh_npc_mark로 받는다. [!] = 아직 안 읽은 active 목표(has_new_quest) → 시트 열람이 끈다.
signal quests_seen

# ── 자원·장비 (GameState → 전체)
## ⚠ 둘 다 발신만 있고 수신자 0 (HUD 삭제 탓). 정상 — 발신 측은 계약을 지킨다.
signal resources_changed
signal equipment_changed
## 🔴 바닥 픽업이 플레이어에게 흡수돼 가방에 들어갔다 (세션51). drop_pickup이 **도착 순간 1회** 발신.
## HUD가 획득 토스트를 띄운다. `resources_changed`(가방/창고 내용이 변했다)와 **다르다** — 이건
## "방금 이게 도착했다"는 연출용 이벤트다. 무엇이 얼마나 들어왔는지가 실린다.
## ⚠ 창고 입고·제작 소비·정산은 이 신호를 쓰지 않는다 — 쓰면 공방에서 제작할 때마다 토스트가 뜬다.
signal item_collected(item_id: StringName, count: int)

# ── 원소 반응 VFX (세션52) — 몸(forest_enemy·dummy_target)이 방송, src/actors/vfx.gd가 그린다.
## 🔴 연출용 순수 오버레이다 — 게임 로직은 이 신호를 **안 본다**(퀘스트처럼 관찰만). 반응 판정·피해는
## 이미 status_holder/몸이 다 했고, 이 신호는 "어디서·어디로 뭐가 터졌나"를 VFX에만 알린다.
## pos·from·to는 전부 **월드 전역 좌표**. status = Enums.Status(색은 VFX가 SR.tint_of로 되쓴다 —
## 상태 색 단일 소스 재사용). 발신자는 forest_enemy·dummy_target의 `_burst_damage`·`_spread_statuses`.
## ⚠ 발신자가 몸 두 곳으로 갈려 있으니, 한쪽만 고치면 연습장↔숲에서 연출이 조용히 갈라진다.
## 반응이 한 자리에서 터졌다(면적). radius = 실제 게임플레이 반경(감전연쇄/증기 px). status=결과 상태(NONE=증기·SHOCK=감전).
signal reaction_burst(pos: Vector2, radius: float, status: int)
## 상태가 A→B로 튀었다(감전 연쇄 한 가닥 · 바람 확산 한 가닥). 대상마다 1회. 색은 status로 갈린다.
signal reaction_chain(from: Vector2, to: Vector2, status: int)

# ── 설정 (Audio → UI)
## 🔴 음소거 상태가 바뀌었다 (설정). Audio가 소유·저장하고 발신 → HUD 표시·타이틀 버튼이 갱신.
signal audio_muted_changed(muted: bool)
