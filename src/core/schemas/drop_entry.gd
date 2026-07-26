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
## 🔴 **드롭이 곧 해금** — 문양-고리 두루마리 보너스 드롭 (세87 사냥 흐름 S2).
## 채우면 이 줄은 아이템이 아니라 **codex 해금을 떨군다**(땅에 두루마리가 떨어지고 걸어가 줍는다 —
## 세46 계약. 죽으면 가방과 함께 잃으므로 긴장도 유지된다).
##
## 🔴 **`item_id`와 배타 · `until_unlock`과 병용 금지.** 축이 반대다:
##   `until_unlock` = *"그 codex가 잠긴 동안 이 **아이템**을 확정 드롭"* (스스로 해금하지 않는다)
##   `unlock_id`    = *"이 드롭이 그 codex를 해금한다"*
## ⚠ 병용하면 **확률이 통째로 죽는다** — `_roll_drops`가 `if until_unlock … elif randf() > chance`
## 구조라 `until_unlock`을 채우면 `chance`를 안 본다(0.02 보너스가 모든 잡몹 확정 드롭이 된다).
## 「이미 해금된 고리는 안 떨군다」 가드는 `_roll_drops`의 **별도 줄**이다(확률 굴림 앞).
@export var unlock_id: StringName = &""
