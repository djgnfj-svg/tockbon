class_name MobSpawn
extends Resource
## 챕터 잡몹 배치 한 항목 (세66 도파민 — 잡몹 길). `ChapterDef.mob_spawns`의 원소.
##
## 🔴 "새 잡몹 배치 = ChapterDef.mob_spawns 항목 하나" — boss_room._spawn_mobs가 읽어 forest_enemy를
##  범용 스폰한다(그룹 enemies·layer4·take_hit·_die→coin 드롭). 신규 씬 0.
##  잡몹 = 즉시 보상 무대(돈·손맛 1층). 클리어 판정은 여전히 보스 처치만(잡몹 죽음은 무시).

## 스폰할 적 id — data/enemies/*.tres. 잡몹(코인·재료 낱개 드롭). 세66에 상자는 은퇴했다.
## 🔴 세99: **값이 있으면 지금 그대로 그 적이 선다**(회귀 0). 비우고 `pool_tag`를 채우면 굴린다.
@export var enemy_id: StringName
## 방 안 스폰 위치 (플레이어 입구는 남쪽 고정 — 앞쪽에 깔면 뚫고 보스에 닿는다).
@export var position: Vector2 = Vector2.ZERO
## 🔴 세99 D5 — **이 자리를 어느 풀에서 굴리나** (`ChapterDef.mob_pool`의 `MobWeight.pool_tag`와 맞춘다).
## 비면 굴리지 않는다(= `enemy_id` 그대로 = 지금 동작). 정본 = `docs/takbon-design/dungeon_structure_design.md`.
##
## 🔴 **자리는 사람이 놓고 정체만 굴린다** — 사용자 확정 *"지형은 동일하고 나오는 몬스터들이 랜덤"*.
##  좌표는 지형이 정하는 것(길목·빈터)이라 사람이 놓는 게 맞다.
##
## ⚠ **`enemy_id`와 둘 다 비면 아무 적도 안 서는데 에러가 0이다** — 방이 텅 비어도 클리어는 보스로
##  판정되어 **전 스위트 그린**이 된다(설계 §6 S1). 그래서 **스폰된 수를 세는 그물**이 필요하다.
## ⚠ 기존 그물이 `enemy_id`가 빈 항목을 「죽은 항목」으로 센다 — **랜덤을 켜기 전에 그물을 먼저
##  범위형으로 바꿔라**(설계 §7 단계 1.5). 순서가 뒤바뀌면 `test_chapter_auto`가 flaky가 되는데,
##  그 파일은 **세84에 이미 flake로 데인 자리**라 재발하면 「빨간 게 정상」이 되어 그물 신뢰가 죽는다.
@export var pool_tag: StringName = &""
