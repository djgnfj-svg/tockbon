class_name LandmarkSlot
extends Resource
## 지점이 맵의 **어느 자리**에 서나 (세99 던전 구조 D3). `ChapterDef.landmarks`의 원소.
## 정본 = `docs/takbon-design/dungeon_structure_design.md` §2·§3.
##
## 🔴 **자리는 고정이다** — 사용자 확정이 *"지형은 동일"*이라, 지점의 위치는 지형이 정하고
##  매 판 바뀌는 건 **내용물**(몹 구성·네임드 유무)이다. 자리까지 굴리면 지형을 손으로 그린 뜻이 없어진다.
##
## 🔴 D3에서 **위험도 띠(구역)를 안 쓰기로 했다** — 그래서 **위험·보상의 층을 지점 자신이 진다**.
##  「입구에서 멀수록 좋은 지점」은 여기 좌표를 그렇게 놓는 것으로 표현한다(별도 필드가 아니다).

## 어느 지점인가 — `data/landmarks/*.tres`의 `LandmarkDef.id`.
@export var landmark_id: StringName
## 방 안 위치. ⚠ 플레이어 입구는 남쪽 고정이다 — 앞쪽에 몰아 놓으면 「고르는 재미」가 안 생긴다.
@export var position: Vector2 = Vector2.ZERO
