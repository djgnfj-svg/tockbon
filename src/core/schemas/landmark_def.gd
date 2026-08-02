class_name LandmarkDef
extends Resource
## 지점(랜드마크) 정의 — `data/landmarks/*.tres`.
## 「새 지점 = 이 `.tres` 한 장 + 프롭 씬 한 장」 — `Db.landmarks`가 읽고 `ChapterDef.landmarks`가
## 어느 챕터 어디에 세울지 정한다.
##
## 🔴 적을 스폰하는 건 지점이 아니라 방이다 — 지점 씬이 `forest_enemy.tscn`을 물면
##  preload 방향(field → props 단방향)이 처음으로 뒤집힌다. 지점은 겉모습·판정만 지고
##  「지금 하나 내보내라」를 부모에게 알린다(스폰 소유자는 `boss_room` 하나).

## 지점 id — `LandmarkSlot.landmark_id`·`NamedSpawn.at_landmark`가 이 값을 가리킨다.
@export var id: StringName
## 무슨 성격인가 — 셋의 차이는 「보상 크기」가 아니라 「무슨 일이 일어나나」다.
@export var kind: Enums.LandmarkKind = Enums.LandmarkKind.RUIN
## 겉모습 프롭 씬. 🔴 경로 문자열인 이유 = 씬끼리 `PackedScene` preload 금지(순환 함정) — 로드를 늦춘다.
@export_file("*.tscn") var scene_path: String = ""
## 화면 표시명 (없으면 UI가 id를 쓴다).
@export var title: String = ""

## 보상은 `DropEntry`를 그대로 쓴다 — 새 드롭 기계를 만들지 마라. 굴림·낱개 스폰은 `forest_enemy`의
##  `_roll_drops`/`_spawn_loose` 한 곳뿐이라, 지점이 자기 로직을 쓰면 `DropEntry`의 배타 짝 규칙이 두 벌이 된다.
##
## 🔴 `until_unlock`을 여기 쓰지 마라 — `unlock_id`와 병용하면 `_roll_drops`가 `if…elif` 구조라
##  **`chance`를 통째로 안 봐서** 모든 굴림이 확정 드롭이 된다.
## 🔴 `unlock_id`도 쓰지 마라 — 진행에 걸린 보상(문양-고리)은 보스·공방·퀘스트 몫인데, 굴림이 이
##  필드를 그대로 처리해서 「지점이 문양-고리를 준다」가 **데이터 한 줄로 조용히 성립한다.**
##
## 🔴 세 층으로 채운다 — 줄마다 독립 굴림이라 바닥 층(`chance = 1.0`)이 없으면 **빈손인 판이
##  확률적으로 반드시 나오는데 에러가 0이고, 재현이 확률이라 버그로 안 보인다.**
##    **바닥** `chance = 1.0` : 허탕 방지 + 겉보기 아귀 · ⚠ coin을 여기 두껍게 깔면 판당 총량이
##                              크게 흔들려 병목이 지갑에서 통째로 빠진다
##    **몸통** `0.45~0.5`     : 매번 종류가 달라지는 부분
##    **꼬리** `0.05~0.1`     : 대박 — 큰 뭉치는 여기 싣는다
##  무엇을 섞나 = 「그 챕터에서 막힌 것」이 주력이고 지역 재료는 구색이다 — 챕터마다 다시 계산해라.
##  ⚠ 다른 챕터의 재료를 여기로 끌어오지 마라 — 그 챕터에 사는 적이 주게 둔다.
@export var drops: Array[DropEntry] = []

## 종류별 세부 — 🔴 읽는 키를 여기 적어 둔다(안 적으면 `.tres`에 오타를 써도 **에러가 0**이다).
##
## 여는 방법은 종류마다 다르지 않다 — 우두머리를 잡든 말든 [E] 한 번이면 즉시 열리고 한 판에
##  한 번뿐이다(열면 비워진 겉모습으로 바뀐다). 그래서 여는 축엔 읽는 키가 하나도 없고,
##  아래 키들은 열린 뒤·또는 겉보기에만 걸린다.
##  ⚠ 홀드로 뒤지는 안은 각하됐다 — 되살리려는 안이 나오면 여기부터 읽어라.
##  ⚠ 무방비 시간은 상자를 여는 순간뿐이다(연 뒤 낱개를 줍는 시간은 없다 — 바로 가방으로 간다).
##
## **RUIN(폐허)** — 열면 소리가 나 몹이 몰려온다
##   `aggro_radius`(float, px)  : 이 반경 안의 적이 반응한다
##   `aggro_count`(int)         : 새로 불러낼 수 (0이면 이미 방에 있는 적만 끌어온다)
##
## **NEST(둥지)** — 🔴 읽는 키가 없다. 산출은 위 `drops`가 지고, 우두머리는 `NamedSpawn.at_landmark`가
##   세운다. 🔴 둥지는 적을 뱉지 않는다 — 무한 스폰·핵 파괴 계약은 각하됐으니 되살리지 마라.
##   ⚠ 대신 필요한 건 재열기 가드다 — 열고 나서 게이트를 안 걸면 무한 파밍이 최적 전략이 된다.
##
## **ALTAR(제단)** — 마법을 바치면 보상
##   `mana_cost`(float)           : 바치는 마나
##   ⚠ 이 트레이드오프는 F5로 검증할 수 없다 — `debug_free_cast = OS.has_feature("editor")`라
##      에디터 실행은 발사 마나가 **공짜**다. HUD의 `마나 = (테스트)`가 그 신호다.
@export var params: Dictionary = {}
