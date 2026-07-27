class_name LandmarkDef
extends Resource
## 지점(랜드마크) 정의 — 세99 던전 구조 D3·D4. `data/landmarks/*.tres`.
## 정본 = `docs/takbon-design/dungeon_structure_design.md` §3.
##
## 🔴 **"새 지점 = 이 `.tres` 한 장 + 프롭 씬 한 장"** — `Db.landmarks`가 읽고
##  `ChapterDef.landmarks`(`LandmarkSlot`)가 어느 챕터 어디에 세울지 정한다.
##
## 🔴🔴 **적을 스폰하는 건 지점이 아니라 방이다** (설계 §3 소유권 ⓐ).
##  지금 리포의 preload 방향은 **field → props 단방향**이고(`forest_enemy`→`drop_pickup`,
##  `boss_room`→`portal`) 그 반대는 **한 건도 없다**. 지점 씬이 `forest_enemy.tscn`을 물면
##  그 방향이 처음으로 뒤집힌다(takbon-rules §0 위반).
##  → 지점은 **겉모습·판정만** 지고 「지금 하나 내보내라」를 부모에게 알린다. 스폰은 `boss_room`이 한다
##  (이미 유일한 스폰 소유자 — `_spawn_boss`·`_spawn_mobs`). **부모가 자식 시그널을 잇는 조합 루트라
##  EventBus 신설이 0**이고, 「스폰 수를 세는 그물」이 한 자리에서 성립한다.

## 지점 id — `LandmarkSlot.landmark_id`·`NamedSpawn.at_landmark`가 이 값을 가리킨다.
@export var id: StringName
## 무슨 성격인가 — 🔴 **셋의 차이는 「보상 크기」가 아니라 「무슨 일이 일어나나」다**(`Enums.LandmarkKind` 머리말).
@export var kind: Enums.LandmarkKind = Enums.LandmarkKind.RUIN
## 겉모습 프롭 씬. 🔴 **경로 문자열인 이유** = 씬끼리 `PackedScene` preload 금지(세26 순환 함정)와 같은 결 — 로드를 늦춘다.
@export_file("*.tscn") var scene_path: String = ""
## 화면 표시명 (없으면 UI가 id를 쓴다).
@export var title: String = ""

## 🔴 **보상은 `DropEntry`를 그대로 쓴다 — 새 드롭 기계를 만들지 마라** (설계 §3 소유권 ⓑ).
##  굴림·낱개 스폰은 `forest_enemy`의 `_roll_drops`/`_spawn_loose` **한 곳뿐**이라, 지점이 자기 로직을
##  새로 쓰면 `DropEntry`의 **배타 짝 규칙 셋**이 두 벌이 된다(takbon-rules §5-1이 「조용히 깨진다」로 못 박은 자리).
##
## 🔴🔴 **`until_unlock`을 여기 쓰지 마라** — `unlock_id`와 병용하면 `_roll_drops`가 `if…elif` 구조라
##  **`chance`를 통째로 안 봐서** 모든 굴림이 확정 드롭이 된다(`DropEntry` 머리말의 그 함정 그대로).
##
## ⚠ **진행에 걸린 보상(문양-고리)은 어느 지점도 주지 않는다**(세99 사용자 확정) —
##  그건 보스·공방·퀘스트 몫이다. 여기 걸면 D6가 막으려던 상태가 된다.
@export var drops: Array[DropEntry] = []

## 종류별 세부 — 🔴 **읽는 키를 여기 적어 둔다**(안 적으면 `.tres`에 오타를 써도 **에러가 0**이다).
##
## **RUIN(폐허)** — 열면 소리가 나 몹이 몰려온다
##   `aggro_radius`(float, px)  : 이 반경 안의 적이 반응한다
##   `aggro_count`(int)         : 새로 불러낼 수 (0이면 이미 방에 있는 적만 끌어온다)
##
## **NEST(둥지)** — 핵을 깨야 멈춘다
##   `spawn_enemy_id`(StringName) : 뱉을 적
##   `spawn_interval_sec`(float)  : 뱉는 간격
##   🔴 `spawn_max_alive`(int)    : **동시 생존 상한**
##   🔴 `spawn_max_total`(int)    : **누적 상한** — 🔴🔴 **둘 다 없으면 무한히 뱉는데 에러가 0이고
##       방이 「더 재미있어 보일 뿐」이다**(설계 §6 S14). 상한은 데이터로 두고 그걸 재라.
##   `core_hp`(float)             : 핵 체력
##
## **ALTAR(제단)** — 마법을 바치면 보상
##   `mana_cost`(float)           : 바치는 마나
##   ⚠ **이 트레이드오프는 F5로 검증할 수 없다** — `debug_free_cast = OS.has_feature("editor")`라
##      에디터 실행은 발사 마나가 **공짜**다(설계 §6 S15). HUD의 `마나 = (테스트)`가 그 신호다.
@export var params: Dictionary = {}
