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

# ── 전투 (B ↔ C)
signal enemy_hit(enemy: Node2D, damage: float, rune_type: int)
signal enemy_died(enemy_def: EnemyDef, position: Vector2)
signal player_damaged(amount: float)
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

# ── 씬 전환 (모듈 → Main)
signal scene_change_requested(scene_id: StringName)
