class_name QuestDef
extends Resource
## 진행 목표(퀘스트) 정의 — data/quests/*.tres.
## 퀘스트는 순수 오버레이다 — 이미 도는 EventBus 이벤트(적 처치·귀환·해금)를 관찰해 자동 진행하고,
## 해금 경로를 전혀 안 건드린 채 흩어진 진행을 보이는 사슬로 만든다. 판정·보상은 GameState가 쥔다.
## 「새 퀘스트 = .tres 한 장」 — `requires`로 이전 퀘스트를 물면 그게 곧 스파인이다.

## 목표 종류 — Enums.QuestGoal.
##  KILL   = 적을 처치 (target 비면 아무 적이나, 특정 enemy_id면 그 적만).
##  EXTRACT= 살아서 귀환 (target 무시).
##  UNLOCK = 도감 해금 (target = unlock_id. count는 1로 취급).
##  DRAW   = 마법진을 그렸다. 🔴 판정이 카운트가 아니라 **상태**다(`ring_designs.size() >= need()`) —
##           이미 그린 세이브가 자동 충족돼 사슬이 안 막힌다.
@export var id: StringName
@export var title: String = ""
@export var desc: String = ""
@export var goal: Enums.QuestGoal = Enums.QuestGoal.KILL
## 목표 대상 — KILL의 enemy_id / UNLOCK의 unlock_id. 비면 "아무거나"(KILL)·무시(EXTRACT).
@export var target: StringName = &""
## 필요 횟수 — KILL·EXTRACT의 카운트. UNLOCK은 1로 취급.
@export var count: int = 1
## 완료 보상 {item_id: 수량} — 창고에 지급 (GameState.add_item).
@export var reward_items: Dictionary = {}
## 완료 시 해금할 codex id (룬/진). 비면 해금 없음. reward_items와 별개 —
##  이건 codex_unlocked를 쏴 룬/진을 배우고 예식(unlock_ceremony)을 띄운다.
@export var reward_unlock: StringName = &""
## 선행 퀘스트 id — 이게 완료돼야 이 퀘스트가 열린다. 비면 처음부터 열림. 이 줄이 스파인이다.
@export var requires: StringName = &""

## 표시상 필요 횟수 — UNLOCK은 언제나 1.
func need() -> int:
	return 1 if goal == Enums.QuestGoal.UNLOCK else maxi(1, count)
