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

# ── 자원·장비 (GameState → 전체)
## ⚠ 둘 다 발신만 있고 수신자 0 (HUD 삭제 탓). 정상 — 발신 측은 계약을 지킨다.
signal resources_changed
signal equipment_changed
