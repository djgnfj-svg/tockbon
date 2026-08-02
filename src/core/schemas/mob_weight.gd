class_name MobWeight
extends Resource
## 챕터 잡몹 풀 한 줄 — `ChapterDef.mob_pool`의 원소.
## 자리(좌표)는 `MobSpawn`이 쥐고, 매 판 굴리는 건 「거기 뭐가 서 있나」뿐이다.
##
## 🔴🔴 여기에 `ChapterDef.boss_enemy_id`를 넣지 마라 — `boss_room._on_enemy_died`가 `enemy_id`
##  일치 한 줄로 판정해, 잡몹 한 마리가 챕터 클리어·보상을 **전부 조용히 내보낸다(에러 0)**.

## 뽑힐 적 id — `data/enemies/*.tres`.
@export var enemy_id: StringName
## 뽑힐 가중치 (클수록 자주 나온다). 🔴 0 이하면 안 뽑힌다 — 임시로 빼려면 지우지 말고 0으로.
@export var weight: int = 1
## 어느 풀에 속하나 — `MobSpawn.pool_tag`가 이 값을 가리키면 그 자리를 이 풀에서 굴린다.
## 비면 기본 풀(`&""`). 태그를 나누면 「앞은 약한 것, 안쪽은 센 것」을 좌표 없이 표현한다.
@export var pool_tag: StringName = &""
