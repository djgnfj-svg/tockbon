class_name MobWeight
extends Resource
## 챕터 잡몹 **풀** 한 줄 (세99 던전 구조 D5 — 「지형 고정 · 몹 구성 랜덤」).
## `ChapterDef.mob_pool`의 원소. 정본 = `docs/takbon-design/dungeon_structure_design.md` §2.
##
## 🔴 **자리는 사람이 놓고, 정체는 굴린다** — 스폰 좌표는 `MobSpawn.position`이 그대로 쥐고
##  (지형이 정하는 것이라 사람이 놓는 게 맞다), 바뀌는 건 **「거기 뭐가 서 있나」**뿐이다.
##  사용자 확정: *"지형은 동일하고 나오는 몬스터들이 랜덤"*.
##
## 🔴🔴 **`ChapterDef.boss_enemy_id`를 여기 넣지 마라 — 잡몹 한 마리가 챕터를 클리어한다.**
##  `boss_room._on_enemy_died`의 판정이 **`enemy_id` 일치 한 줄**이라, 풀에 보스 id가 섞이면
##  `chapter_clear_*` + 보상 룬 + 귀환 포탈이 **전부 조용히 나간다(에러 0)**.
##  지금까지 안 겹친 건 `mob_spawns`를 손으로 박아 **우연히 보장**되던 것뿐이다.
##  → 스폰 쪽에 **제외 가드가 계약이다**(설계 §6 S9). 여기 주석은 그 계약의 사본이 아니라 경고다.

## 뽑힐 적 id — `data/enemies/*.tres`.
@export var enemy_id: StringName
## 뽑힐 가중치 (클수록 자주 나온다). 🔴 **0 이하면 안 뽑힌다** — 임시로 빼려면 지우지 말고 0으로.
@export var weight: int = 1
## 어느 풀에 속하나 — `MobSpawn.pool_tag`가 이 값을 가리키면 그 자리를 이 풀에서 굴린다.
## 비면 기본 풀(`&""`). 🔴 태그를 나누면 **「앞쪽엔 약한 것, 안쪽엔 센 것」**을 좌표 없이 표현할 수 있다.
@export var pool_tag: StringName = &""
