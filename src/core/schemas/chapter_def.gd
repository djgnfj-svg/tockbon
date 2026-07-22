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
