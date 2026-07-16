extends Node
## 모듈 간 시그널 허브 — 유일한 교차 모듈 통신 경로 (TECH_SPEC §5).
## 시그널 추가·변경은 리드만. 변경 시 docs/TECH_SPEC.md를 먼저 갱신한다.

@warning_ignore_start("unused_signal")

# ── 드로잉/도안 (A → B·D·E)
signal design_created(design: SpellDesign)
signal design_updated(design: SpellDesign)
signal recognition_result(role: int, matched: bool, score: float)

# ── 캐스팅 (C → B, B → C·E)
signal cast_requested(design: SpellDesign, origin: Vector2, aim_dir: Vector2)
signal cast_executed(design: SpellDesign, mana_spent: float)
signal cast_failed(design: SpellDesign, reason: int)

# ── 고리 조립 캐스팅 (세션 12~, 평행 경로 — 옛 cast_requested와 별개)
# 🔴 고리 모델(진=날아가는 몸, 문양=착탄 전개)은 SpellDesign이 아니라 assembly 사전을 싣는다.
# assembly = ring_board.get_assembly() = {ring_count, rune, rings:[[8칸]], open:[...]}.
# ring_spell_system(모듈 B)이 수신 → 진(캐리어)을 조준 방향으로 쏜다.
signal ring_cast_requested(assembly: Dictionary, origin: Vector2, aim_dir: Vector2)
# 🔴 #17 1단계 — 고리 도안이 맺혔다 (거점 조립 책 → GameState). 옛 design_created와 평행.
# GameState가 수신 → ring_designs에 넣고 빈 ring_equipped 슬롯에 즉시 장착.
signal ring_design_committed(design: RingDesign)

# ── 전투 (B ↔ C)
signal enemy_hit(enemy: Node2D, damage: float, rune_type: int)
signal enemy_died(enemy_def: EnemyDef, position: Vector2)
signal player_damaged(amount: float)
signal player_hp_changed(hp: float, hp_max: float)
signal player_died

# ── 탁본·익스트랙션 (C → D·E)
signal rubbing_started(fragment_id: StringName)
signal rubbing_completed(fragment_id: StringName)
signal extraction_success
signal bag_lost

# ── 시간 (Clock → 전체)
signal phase_changed(phase: int)
signal day_started(day: int)

# ── 도감 해금 (C: 적 첫 처치 → enemy_<id> / 누구든 범용 해금)
signal codex_unlocked(unlock_id: StringName)

# ── 거점 (D → E·A)
signal research_completed(unlock_id: StringName)
signal design_repaired(design: SpellDesign)
signal resources_changed

# ── 장비 (GameState → C·D·E)
signal equipment_changed

# ── 온보딩 (거점 시험장 ↔ 튜토리얼) — v1.4
signal training_hit(rune_type: int, damage: float)   # 거점 허수아비 명중 (D → 튜토리얼)
signal tutorial_focus(target_id: StringName)         # 유도 마커 대상 시설. &"" = 해제 (튜토리얼 → D)

# ── 씬 전환 (모듈 → Main / Main → 전체)
signal scene_change_requested(scene_id: StringName)
signal scene_changed(scene_id: StringName)
