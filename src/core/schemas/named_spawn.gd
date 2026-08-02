class_name NamedSpawn
extends Resource
## 네임드 굴림 한 줄 — `ChapterDef.named_pool`의 원소.
## 매 판 항목마다 독립으로 굴린다 — 「하나도 안 뜸」이 정상 결과다.
## 🔴 진행(문양)을 여기 걸지 마라 — 보스가 확정 드롭을 쥐고 네임드는 피해도 되는 보너스다.
##
## ⚠ `ChapterDef.boss_enemy_id`를 여기 넣지 마라 — 이유는 `MobWeight` 머리말과 같다.
## ⚠ 네임드는 새 적 종이 아니어도 된다 — 기존 적의 강화판(`EnemyDef.params`의 `tint`·`size`·
##  `sprite`·`anim_fps`)으로 `.tres` 한 장에 성립한다.
## 🔴 몸을 물들이는 건 `params.color`가 아니라 `tint`이고, `_refresh_tint`가 상태이상 틴트와
##  **곱한다** — 대입하면 **첫 상태이상에 색조가 영영 지워지는데 에러가 0**이다.
## 🔴 표시는 생김새다 — 빛나게 하지 마라(오라·HUD 알림·화면 밖 표시는 각하됐다).

## 뽑힐 적 id — `data/enemies/*.tres`.
@export var enemy_id: StringName
## 이 판에 뜰 확률. 🔴 기본이 0.0이다 — 데이터가 명시적으로 켜야 뜬다.
@export_range(0.0, 1.0) var chance: float = 0.0
## 어느 지점에 자리 잡나 — `ChapterDef.landmarks`의 `landmark_id`. 비면 아래 `position`(자유 위치).
@export var at_landmark: StringName = &""
## 자유 위치 (`at_landmark`가 비었을 때만 쓴다).
@export var position: Vector2 = Vector2.ZERO
