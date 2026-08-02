class_name LandmarkSlot
extends Resource
## 지점이 맵의 어느 자리에 서나 — `ChapterDef.landmarks`의 원소.
## 자리는 지형이 정하고, 매 판 바뀌는 건 내용물(몹 구성·네임드 유무)뿐이다.
## 위험·보상의 층은 별도 필드가 아니라 좌표로 표현한다(입구에서 멀수록 좋은 지점).

## 어느 지점인가 — `data/landmarks/*.tres`의 `LandmarkDef.id`.
@export var landmark_id: StringName
## 방 안 위치. ⚠ 플레이어 입구는 남쪽 고정 — 앞쪽에 몰면 고르는 재미가 안 생긴다.
@export var position: Vector2 = Vector2.ZERO
