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
