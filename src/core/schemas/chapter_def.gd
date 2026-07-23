class_name ChapterDef
extends Resource
## 챕터(보스방 스테이지) 정의 — 세58-B 세피리아식 메인 루프. 정본 흐름 = docs/PROGRESSION.md.
## 🔴 "새 챕터 = data/chapters/*.tres 한 장 (+ 적 .tres·아트)" — boss_room.tscn 한 씬이 이걸 읽어 돈다.

@export var id: StringName
## 잠금 순서 (1부터). 챕터 N은 챕터 N-1의 클리어(codex `chapter_clear_*`)가 있어야 열린다 —
## 판정은 챕터 선택 패널이 한다 (해금 판정은 패널이 — 룬 셀과 같은 결).
@export var order: int = 1
## 선택 UI 표시명 (예: "숲 어귀").
@export var title: String = ""
## 보스 적 id — 비었거나 boss_scene_path가 없으면 forest_enemy.tscn + 이 id로 범용 스폰.
## 🔴 클리어 판정도 이 id로 한다 (enemy_died 관찰) — 전용 씬 보스도 이 id를 쏴야 한다.
@export var boss_enemy_id: StringName
## 전용 씬 보스(예: snake_boss.tscn)면 경로. 비면 forest_enemy 범용 스폰.
## 🔴 경로 문자열인 이유 = 씬끼리 PackedScene preload 금지(세26 순환 함정)와 같은 결 — 로드를 늦춘다.
@export_file("*.tscn") var boss_scene_path: String = ""
## 방 안 보스 스폰 위치 (플레이어 입구는 남쪽 고정).
@export var boss_spawn: Vector2 = Vector2(0, -260)
## 챕터 분위기 바닥 틴트. ⚠ .tres에서 Color는 **반드시 4인자** — 3인자면 파서가 리소스 전체를
## 조용히 버린다(세50 바람 룬). test_chapter_auto의 「챕터 로드」 그물이 이걸 잡는다.
@export var room_ground_color: Color = Color(0.13, 0.19, 0.14, 1.0)
## 잡몹 길 (세66 도파민 — 즉시 보상 무대). 방 앞쪽에 까는 잡몹 배치. 비면 보스만 있는 방(세58-B 원형).
## 🔴 잡몹 = forest_enemy 범용 스폰(그룹 enemies·layer4·_die→coin 드롭). 클리어는 여전히 보스 처치만.
##  "새 잡몹 배치 = 여기 MobSpawn 항목 하나". boss_room._spawn_mobs가 읽는다.
@export var mob_spawns: Array[MobSpawn] = []
## 클리어 보상 해금 (세71 첫 스테이지 슬라이스) — 보스 첫 처치 시 이 codex id를 해금한다.
## 🔴 문양 링(GlyphRingDef)·룬·진 등 codex 게이트 어휘를 그대로 쓴다: 예 &"gr_radiate5"(발산×5).
## 비면(&"") 무발신 = 기존 챕터 회귀 0. boss_room._on_enemy_died가 chapter_clear 바로 옆에서 발신(is_unlocked 가드).
## 🔴 도파민 설계의 QuestDef.reward_unlock 턴인 예식이 아니라 **ChapterDef 직접 해금**을 택한 이유:
##  첫 슬라이스엔 마을 턴인 예식이 과함 — 보스 처치=즉시 해금이 조립→탁본 루프를 가장 짧게 닫는다
##  (파밍 문양 링을 밴드에 끼워 파이어볼 진화). 퀘스트 턴인은 콘텐츠가 늘 때(qR* 사슬) 도입.
@export var reward_unlock: StringName = &""
