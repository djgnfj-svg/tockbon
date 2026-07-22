class_name MobSpawn
extends Resource
## 챕터 잡몹 배치 한 항목 (세66 도파민 — 잡몹 길). `ChapterDef.mob_spawns`의 원소.
##
## 🔴 "새 잡몹 배치 = ChapterDef.mob_spawns 항목 하나" — boss_room._spawn_mobs가 읽어 forest_enemy를
##  범용 스폰한다(그룹 enemies·layer4·take_hit·_die→coin 드롭). 신규 씬 0.
##  잡몹 = 즉시 보상 무대(돈·손맛 1층). 클리어 판정은 여전히 보스 처치만(잡몹 죽음은 무시).

## 스폰할 적 id — data/enemies/*.tres. 잡몹이므로 drops_chest=false인 것.
@export var enemy_id: StringName
## 방 안 스폰 위치 (플레이어 입구는 남쪽 고정 — 앞쪽에 깔면 뚫고 보스에 닿는다).
@export var position: Vector2 = Vector2.ZERO
