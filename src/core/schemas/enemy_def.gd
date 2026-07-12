class_name EnemyDef
extends Resource
## 적 정의 — data/enemies/*.tres (인스턴스 작성은 모듈 C 소유).

@export var id: StringName
@export var display_name: String = ""
@export var hp: float = 30.0
## 약점 룬 — 게시판·도감 표기용
@export var counter_rune: Enums.RuneType = Enums.RuneType.FIRE
## false = 약점 없음 (counter_rune 무시, 예: 수액 슬라임 — 다발 도안이 답)
@export var has_counter: bool = true
## 전투 수치 자유 파라미터 (속도·접촉 피해·사거리 등) — 스키마 확장 대신 이것을 쓴다
@export var params: Dictionary = {}
@export var is_elite: bool = false
@export var drops: Array[DropEntry] = []
## 밤 강화 배율 (HP·공격력 공통, 프로토 단순화)
@export var night_buff: float = 1.5
