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


# ── 세99 던전 구조 (D1·D5·D6·D8) ────────────────────────────────────────────
# 🔴 **다섯 다 「비면 지금 동작」이다** — 데이터 축의 회귀는 0이다.
#    ⚠ 다만 **채우는 순간** 기존 계약·기존 그물이 깨지는 자리가 넷 있고 그중 둘은 에러가 0이다
#    (설계 §6의 S9~S12). **「되돌리기가 싸다」와 「켜는 게 안전하다」는 다른 말이다.**
# 정본 = `docs/takbon-design/dungeon_structure_design.md`.

## 🔴 D8 — 이 챕터가 쓸 무대 씬. 비면 기본 보스방(공용 한 장 = 지금 동작).
## ⚠ **실제 소비자는 `base.gd`의 `_on_chapter_selected`다** — `boss_room`이 자기 `_ready`에서 읽으면
##  **이미 그 씬에 들어와 있어서 늦다**. 폴백은 새 문자열을 적지 말고 그쪽 `@export` 값을 써라(두 벌 = T5).
## ⚠ 이 필드는 `boss_room.gd` 머리말의 명시 「설계 확정」(*"챕터별 씬 3장을 만들지 않는다"*)을 **뒤집는다**
##  — 사용자 확정(세99)이라 뒤집는 것 자체는 문제가 아니고, **그 주석을 같이 안 고치면 다음 세션이
##  그걸 계약으로 읽는다**(T4). 💡 새 맵은 **상속 씬**으로 만들면 노드 계약을 물려받아 함정 재현이 줄어든다.
@export_file("*.tscn") var room_scene_path: String = ""

## 🔴 D5 — 잡몹 풀. `MobSpawn.pool_tag`가 가리키는 자리를 여기서 굴려 세운다. 비면 굴림 없음.
## 🔴🔴 **여기에 `boss_enemy_id`를 넣지 마라 — 잡몹 한 마리가 챕터를 클리어한다**(에러 0).
##  판정이 `enemy_id` 일치 한 줄이라 `chapter_clear_*` + 보상 룬 + 포탈이 전부 조용히 나간다.
##  스폰 쪽 **제외 가드가 계약이다**(설계 §6 S9).
@export var mob_pool: Array[MobWeight] = []

## 🔴 D6 — 네임드 굴림. **항목마다 독립으로 굴린다 · 「하나도 안 뜸」이 정상**이다. 비면 네임드 없음.
## ⚠ 진행(문양)을 여기 걸지 마라 — 보스가 확정 드롭을 지는 이유가 그것이다(`NamedSpawn` 머리말).
@export var named_pool: Array[NamedSpawn] = []

## 🔴 D3·D4 — 이 챕터에 설 지점들. 비면 지점 없음.
## ⚠ `Db.landmarks`가 `data/landmarks`를 읽어야 성립한다 — 폴더가 없으면 `_load_dir`이 경고만 하고
##  **빈 배열**을 돌려줘 지점이 0개인데 에러가 0이다.
@export var landmarks: Array[LandmarkSlot] = []

## 🔴 D1 — 추가 탈출구 위치. 비면 남쪽 출구 하나(= 지금 동작).
## 🔴🔴 **좌표만 늘리면 2번째부터 화면에 아무것도 안 보인다** — 출구는 겉모습이 없는 InteractZone이고
##  **유일한 시각 표시가 `boss_room._fill_tiles`의 풀길**(`_exit.position`에서 파생)이다.
##  플레이어가 「거기 나갈 데가 있다」를 알 방법이 없으면 **D1의 재미가 통째로 무효**다(설계 §6 S12).
## ⚠ 늘린 출구는 **전부 `zone_id = &"exit"`**여야 한다 — `&"portal"`을 주면 「처치 전엔 포탈이 없다」
##  그물이 빨개진다(S5). `portal.tscn` 재사용이 그 실수의 가장 자연스러운 경로다(씬에 값이 구워져 있다).
## ⚠ **모든 출구를 `_extract`에 이어라** — 안 이으면 E가 먹히는데 아무 일도 안 나고 **가방이 조용히 증발**한다.
@export var extract_points: Array[Vector2] = []
