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
## 🔴 죽으면 낱개 바닥 픽업(세46) 대신 **상자 하나**를 떨군다 (세55 능동 루팅).
## true = 보스/특별 적: `drops`를 굴려 나온 걸 상자에 담고, 플레이어가 [E]로 열어 눌러 담는다.
## false = 잡몹(기본): 지금 그대로 낱개 픽업 + 자석(세51). 굴림 로직(_roll_drops)은 두 갈래가 공유해
## loose 경로 바이트 동일 — `params.ai`나 `is_elite`에 커플하지 않고 **드롭 형태만** 명시로 가른다.
@export var drops_chest: bool = false
## 밤 강화 배율 (HP·공격력 공통, 프로토 단순화)
@export var night_buff: float = 1.5
