class_name NamedSpawn
extends Resource
## 네임드 굴림 한 줄 (세99 던전 구조 D6 — 「보스=고정 · 네임드=확률」).
## `ChapterDef.named_pool`의 원소. 정본 = `docs/takbon-design/dungeon_structure_design.md` §4.
##
## 🔴 **매 판 항목마다 독립으로 굴린다 — 「하나도 안 뜸」이 정상 결과다.**
##  사용자 원문: *"네임드가 있을 수도 없을 수도 있음"*. 그게 「오늘은 뭔가 있다」를 만든다.
##
## 🔴🔴 **진행(문양)을 여기 걸지 마라** — D6의 존재 이유가 그것이다.
##  세57 사용자 원문: *"언제 어떻게 룬을 얻을지 내가 설계를 못 하니까 불안하다"* →
##  그래서 **보스는 고정**(✦문양 확정 드롭)이고 네임드는 **눈에 띄는 보너스**다. 피해도 되는 것이어야 한다.
##
## ⚠ **`ChapterDef.boss_enemy_id`를 여기 넣지 마라** — 이유는 `MobWeight` 머리말과 같다(설계 §6 S9).
## ⚠ 네임드는 **새 적 종이 아니어도 된다** — 기존 적의 강화판(`EnemyDef.params`의 **`tint`**·`size`·
##  `sprite`·`anim_fps`)으로 `.tres` 한 장에 성립하고 그림자까지 따라온다. 단 **색만 바꾼 것을
##  「새 적」이라 부르지는 마라**(세54의 결).
## 🔴🔴 **`params.color`가 아니다** — 초안이 그렇게 적었다가 세99 구현이 실측으로 반박했다.
##  `color`는 세45에 스프라이트로 갈아타며 **`_visual.color`가 사라져 죽음 퍼프 색으로만 산다**
##  (`forest_enemy._apply_look` 주석이 직접 적어 뒀다). 몸을 물들이는 건 **`tint`**(세99 신설)이고
##  `_refresh_tint`에서 상태이상 틴트와 **곱한다** — ⚠ 대입하면 **첫 상태이상에 색조가 영영 지워지는데 에러가 0**이다.
## 🔴 **표시는 생김새다 — 빛나게 하지 마라**(사용자 확정: *"몸에서 빛이나는거 까진 별로임"*).
##  오라·HUD 알림·화면 밖 표시는 **각하됐다.**

## 뽑힐 적 id — `data/enemies/*.tres`.
@export var enemy_id: StringName
## 이 판에 뜰 확률. 🔴 **기본이 0.0이다** — 데이터가 명시적으로 켜야 뜬다(빈 값 = 지금 동작).
@export_range(0.0, 1.0) var chance: float = 0.0
## 어느 지점에 자리 잡나 — `ChapterDef.landmarks`의 `landmark_id`. 비면 아래 `position`(자유 위치).
## ⚠ 지점이 아직 없는 단계에선 **비워 둬라**(설계 §7 — `at_landmark` 해석은 단계 3 몫이다).
@export var at_landmark: StringName = &""
## 자유 위치 (`at_landmark`가 비었을 때만 쓴다).
@export var position: Vector2 = Vector2.ZERO
