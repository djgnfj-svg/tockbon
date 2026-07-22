class_name DropEntry
extends Resource
## 드롭 테이블 한 줄 — EnemyDef.drops 에서 사용.

@export var item_id: StringName
@export_range(0.0, 1.0) var chance: float = 1.0
@export var min_count: int = 1
@export var max_count: int = 1
## 🔴 진행 관문 (세션58, docs/PROGRESSION.md가 정본): 비면 지금과 동일(순수 확률).
## 채우면 그 unlock_id가 **미해금인 동안 chance를 무시하고 확정 드롭, 해금 후엔 드롭 안 함**.
## 「첫 처치 1회」가 아닌 이유 — 조각이 가방째 증발(bag_lost)해도 다시 잡으면 또 나와야
## 진행이 영구 데드락되지 않는다. 판정은 codex 파생 상태라 저장 신규 필드도 0이다.
@export var until_unlock: StringName = &""
