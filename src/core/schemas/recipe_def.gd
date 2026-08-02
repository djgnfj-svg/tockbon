class_name RecipeDef
extends Resource
## 정제·제작 레시피 — data/recipes/*.tres.
## 정제대가 읽어 재료(inputs)를 창고에서 빼고 output을 준다 (GameState.spend + add_item).
## 「새 레시피 = .tres 한 장」 — 조합·수치를 코드에 박지 않는다.

@export var id: StringName
@export var display_name: String = ""
## {재료 item_id: 개수} — 창고에서 이만큼 빠진다 (GameState.spend가 먹는 cost 형식과 같다)
@export var inputs: Dictionary = {}
## 결과 item_id + 개수
@export var output_id: StringName
@export var output_count: int = 1
## 어느 작업대에서 나오나 — 정제대(&"refine": 잉크·종이) vs 공방(&"craft": 장비).
## ⚠ 두 패널이 이 값으로 자기 레시피만 걸러 낸다 — 안 걸러 내면 공방 레시피가 정제대에도 뜬다.
@export var station: StringName = &"refine"
## 제작이 아이템이 아니라 codex 해금을 주는 경로 (`codex_unlocked` 한 발 = 심기 + 해금음 +
## UNLOCK 퀘스트 진행이 전부 따라온다).
##
## 🔴 `output_id`와 배타다 — 고리·룬·진은 `ItemDef`가 아니라 codex 키라 `output_id`에 넣으면
##  창고에 **유령 아이템이 쌓이고 세이브에 영구화된다**. `output_id = &""` · `output_count = 0`으로
##  두고 이 필드만 채우되, 행 제목이 비므로 `display_name`을 반드시 적어라.
@export var reward_unlock: StringName = &""
