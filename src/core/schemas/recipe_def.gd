class_name RecipeDef
extends Resource
## 정제·제작 레시피 — data/recipes/*.tres (세션29 경제 배선).
## 정제대가 읽어 **재료(inputs)를 창고에서 빼고 output을 준다** (GameState.spend + add_item).
##
## 🔴 **새 레시피 = .tres 한 장** (선례: 적 EnemyDef·잉크 ItemDef). 조합·수치를 코드에 박지 않는다.
## 창고 소비·지급은 GameState가 이미 쥐고 있다(can_afford·spend·add_item) — 레시피는 데이터일 뿐.

@export var id: StringName
@export var display_name: String = ""
## {재료 item_id: 개수} — 창고에서 이만큼 빠진다 (GameState.spend가 먹는 cost 형식과 같다)
@export var inputs: Dictionary = {}
## 결과 item_id + 개수
@export var output_id: StringName
@export var output_count: int = 1
## 🔴 어느 작업대에서 나오나 — 정제대(&"refine": 잉크·종이) vs 공방(&"craft": 장비). 세션32.
## 안 적은 옛 레시피는 전부 refine이다(기본값). 두 패널이 이 값으로 자기 레시피만 걸러 낸다 —
## 안 걸러 내면 공방 레시피가 정제대에도 뜬다(둘 다 Db.all_recipes를 읽으므로).
@export var station: StringName = &"refine"
## 🔴 제작이 **아이템이 아니라 codex 해금**을 주는 경로 (세87 사냥 흐름 S1).
## 채우면 제작 성공 시 이 unlock_id가 해금된다(`codex_unlocked` 한 발 = codex 심기 + 해금음 +
## UNLOCK 퀘스트 진행이 전부 따라온다 — 세37 station_* 선례).
##
## 🔴 **`output_id`와 배타로 쓴다**: 고리·룬·진은 `ItemDef`가 아니라 codex 키라 `output_id`에 넣으면
## 창고에 **유령 아이템이 쌓이고 세이브에 영구화된다**(`workshop_panel._craft`가 조건 없이 add_item).
## 해금 레시피는 `output_id = &""` · `output_count = 0`으로 두고 이 필드만 채운다.
## ⚠ 그러면 행 제목이 빈 문자열이 되므로 **`display_name`을 반드시 적어라** — 패널은 이 값을
## 우선 읽고 없을 때만 `output_id` 아이템 이름으로 폴백한다(세87 전까지 `display_name`을 읽는
## 코드가 프로젝트에 한 곳도 없었다).
@export var reward_unlock: StringName = &""
