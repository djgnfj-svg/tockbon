class_name MobSpawn
extends Resource
## 챕터 잡몹 배치 한 항목 — `ChapterDef.mob_spawns`의 원소.
## 「새 잡몹 배치 = 항목 하나」 — `boss_room._spawn_mobs`가 읽어 forest_enemy를 범용 스폰한다(신규 씬 0).
## 클리어 판정은 보스 처치만 본다(잡몹 죽음은 무시).

## 스폰할 적 id — data/enemies/*.tres. 값이 있으면 그 적이 그대로 선다.
@export var enemy_id: StringName
## 방 안 스폰 위치 (플레이어 입구는 남쪽 고정 — 앞쪽에 깔면 뚫고 보스에 닿는다).
@export var position: Vector2 = Vector2.ZERO
## 이 자리를 어느 풀에서 굴리나 (`ChapterDef.mob_pool`의 `MobWeight.pool_tag`와 맞춘다).
## 비면 굴리지 않는다(= `enemy_id` 그대로).
##
## ⚠ `enemy_id`와 둘 다 비면 **아무 적도 안 서는데 에러가 0이다** — 클리어는 보스로 판정되어
##  전 스위트가 그린이 된다. 그래서 스폰된 수를 세는 그물이 필요하다.
@export var pool_tag: StringName = &""
