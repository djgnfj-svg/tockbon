class_name DropEntry
extends Resource
## 드롭 테이블 한 줄 — EnemyDef.drops 에서 사용.

@export var item_id: StringName
@export_range(0.0, 1.0) var chance: float = 1.0
@export var min_count: int = 1
@export var max_count: int = 1
## 진행 관문: 비면 순수 확률. 채우면 그 unlock_id가 **미해금인 동안 chance를 무시하고 확정 드롭,
## 해금 후엔 드롭 안 함**. 「첫 처치 1회」가 아닌 이유 — 조각이 bag_lost로 증발해도 다시 잡으면
## 또 나와야 진행이 영구 데드락되지 않는다.
@export var until_unlock: StringName = &""
## 채우면 이 줄은 아이템이 아니라 codex 해금을 떨군다(땅에 두루마리가 떨어지고 걸어가 줍는다).
##
## 🔴 `item_id`와 배타 · `until_unlock`과 병용 금지 — `_roll_drops`가 `if until_unlock … elif
##  randf() > chance` 구조라 병용하면 **확률이 통째로 죽는다**(보너스가 전 잡몹 확정 드롭이 된다).
@export var unlock_id: StringName = &""
