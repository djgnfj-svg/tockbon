class_name ChapterDef
extends Resource
## 챕터(보스방 스테이지) 정의 — data/chapters/*.tres.
## 「새 챕터 = .tres 한 장 (+ 적 .tres·아트)」 — boss_room.tscn 한 씬이 이걸 읽어 돈다.

@export var id: StringName
## 잠금 순서 (1부터). 챕터 N은 챕터 N-1의 클리어(codex `chapter_clear_*`)가 있어야 열린다 —
## 판정은 챕터 선택 패널이 한다(룬 셀과 같은 결).
@export var order: int = 1
## 선택 UI 표시명 (예: "숲 어귀").
@export var title: String = ""
## 보스 적 id — 비었거나 boss_scene_path가 없으면 forest_enemy.tscn + 이 id로 범용 스폰.
## 🔴 클리어 판정도 이 id로 한다 (enemy_died 관찰) — 전용 씬 보스도 이 id를 쏴야 한다.
@export var boss_enemy_id: StringName
## 전용 씬 보스면 경로. 비면 forest_enemy 범용 스폰.
## 🔴 경로 문자열인 이유 = 씬끼리 PackedScene preload 금지(순환 함정)와 같은 결 — 로드를 늦춘다.
@export_file("*.tscn") var boss_scene_path: String = ""
## 방 안 보스 스폰 위치 (플레이어 입구는 남쪽 고정).
@export var boss_spawn: Vector2 = Vector2(0, -260)
## 챕터 분위기 바닥 틴트. ⚠ .tres에서 Color는 **반드시 4인자** — 3인자면 파서가 리소스 전체를
## 조용히 버린다.
@export var room_ground_color: Color = Color(0.13, 0.19, 0.14, 1.0)
## 방 앞쪽에 까는 잡몹 배치. 비면 보스만 있는 방.
## 「새 잡몹 배치 = 여기 MobSpawn 항목 하나」 — boss_room._spawn_mobs가 읽어 forest_enemy를 범용
## 스폰한다. 클리어는 여전히 보스 처치만 본다.
@export var mob_spawns: Array[MobSpawn] = []
## 보스 첫 처치 시 해금할 codex id. 문양-고리·룬·진 등 codex 게이트 어휘를 그대로 쓴다.
## 비면 무발신. 퀘스트 턴인 예식 대신 직접 해금인 이유 — 보스 처치=즉시 해금이 조립→탁본 루프를
## 가장 짧게 닫는다.
@export var reward_unlock: StringName = &""


# ── 아래 넷은 「비면 지금 동작」이지만, 채우는 순간 기존 계약·그물이 깨지는 자리가 있다.
#    「되돌리기가 싸다」와 「켜는 게 안전하다」는 다른 말이다.

## 이 챕터가 쓸 무대 씬. 비면 기본 보스방(공용 한 장).
## ⚠ 실제 소비자는 `base.gd`의 `_on_chapter_selected`다 — `boss_room`이 자기 `_ready`에서 읽으면
##  **이미 그 씬에 들어와 있어서 늦다**. 폴백은 새 문자열을 적지 말고 그쪽 `@export` 값을 써라.
## 💡 새 맵은 상속 씬으로 만들면 노드 계약을 물려받아 함정 재현이 줄어든다.
@export_file("*.tscn") var room_scene_path: String = ""

## 잡몹 풀. `MobSpawn.pool_tag`가 가리키는 자리를 여기서 굴려 세운다. 비면 굴림 없음.
## 🔴🔴 여기에 `boss_enemy_id`를 넣지 마라 — 판정이 `enemy_id` 일치 한 줄이라
##  `chapter_clear_*` + 보상이 **잡몹 한 마리에 조용히 다 나간다(에러 0)**.
@export var mob_pool: Array[MobWeight] = []

## 네임드 굴림. 항목마다 독립으로 굴린다 · 「하나도 안 뜸」이 정상이다. 비면 네임드 없음.
## ⚠ 진행(문양)을 여기 걸지 마라 — 보스가 확정 드롭을 지는 이유가 그것이다.
@export var named_pool: Array[NamedSpawn] = []

## 이 챕터에 설 지점들. 비면 지점 없음.
## ⚠ `Db.landmarks`가 `data/landmarks`를 읽어야 성립한다 — 폴더가 없으면 `_load_dir`이 경고만 하고
##  **빈 배열**을 돌려줘 지점이 0개인데 에러가 0이다.
@export var landmarks: Array[LandmarkSlot] = []
