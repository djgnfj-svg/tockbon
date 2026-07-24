# 설계: 도파민 보상 루프 + 경제 재편  (개정 2 — 결정 A~D 확정 반영)

> ⚠ **부분 구현 (세78 교차 감사 — 방향은 사용자 확정이라 유지, "아직 안 된 것"만 표시).** 실측 체크리스트:
> - **A(돈=가방)·B(마을 완비)** = coin.tres·shop_panel 착지 (부분 O).
> - **C(잡몹=coin·보스=상자)** = 부분 O.
> - 🔴 **D(룬/진=퀘스트 턴인) = 전량 미구현**: `decode_panel.gd`·`test_decode_auto`·`test_progression_auto` **여전히 존재**(해독/until_unlock 은퇴 미실행) · 퀘스트 `q03~q05` 건설퀘 **그대로**·`qR_*` 룬 퀘스트 **0개** · `unlock_ceremony.gd` **없음** · base에 `station_build` 배선 잔존.
> - ⚠ **D의 은퇴는 회귀 위험**(test 2종 폐기·base 배선 제거) → **별도 세션 + 뮤테이션 그물.** 한 번에 몰지 마라.
>
> 작성 = takbon-architect (dopamine-arch). 구현 위임 = takbon-dev / takbon-ui / takbon-art.
> 정합 기준 = CLAUDE.md 최상단 · docs/PROGRESSION.md · memory(ink-economy·chapter-loop·chest-loot·
> drop-absorb-magnet·empty-base-build·onboarding-flow·quest-system·stage-format-decision).
> 읽은 실제 코드 = game_state · save_manager · db · event_bus · forest_enemy · chest · loot_panel ·
> refine_panel · base · boss_room · chapter_panel · quest_def · 스키마(enemy/item/drop/chapter) ·
> balance_data · enums · 샘플 tres(slime·ink_mid·ch1·refine_red_ink·q02·q05).

---

## 개정 요지 (초안 → 개정2)

리드가 열린 결정 4개를 확정했다. 둘은 옵션이 아니라 **게임 구조 재편**이다:

- **A. 돈 = 가방(사망 시 손실).** 익스트랙션 판돈. §7-A 닫힘.
- **C. 잡몹 = coin 전용 · mat_* = 보스 상자로만.** 잡몹 mat 드롭 제거, craft/refine/build 입력 재조정. §7-C 닫힘.
- **B. 🔴 마을 완비 시작 — 건설 온보딩 폐기.** 상점·정제대·공방이 처음부터 있는 마을. `station_*` 건설
  codex·q03~q05 건설 퀘스트 은퇴(§8). §7-B 닫힘.
- **D. 🔴 룬/진 = 퀘스트 턴인으로만 — 조각·해독대·관문(until_unlock) 은퇴.** 보스 상자 = 재료만.
  마을 NPC 퀘스트가 "보스를 잡아와" → 처치 → 마을 턴인 시 룬/진 지급 + 예식. §5·§9 재작성, §7-D 닫힘.

**유지(초안 뼈대 그대로)**: 돈=coin-as-item(신규 시그널 0·저장 필드 0) · 상점=`station=shop` RecipeDef
재사용 · 챕터 잡몹 길(`ChapterDef.mob_spawns`) · HUD 카운터 톡톡 · 데이터 흐름도 · 도형 금지 아트.

---

## 목표 / 왜 (한두 줄)

킬·픽업(1층)이 **눈에 보이게 쌓이는 돈**으로 흘러 → 상점/제작으로 소비(3층) → 새 그림(최심 보상).
룬/진은 **마을 퀘스트를 클리어해서 얻는다**("주지 말고 얻게" — memory magic-needs-purpose) — 조각을
줍고 집에서 해독하던 우회로를 걷어내고, "보스 잡아와 → 룬 받는다"로 직선화한다.

---

## 🟢 헤드라인: core 변경이 세 곳으로 압축된다

돈을 「아이템 한 종(`coin`)」으로 두면 돈 자체는 core 무접촉이다. 이번 재편에서 리드가 core에 손대는 건 셋뿐:

1. **`QuestDef`에 룬/진 해금 보상 추가** — 지금 `reward_items`는 `add_item`(아이템)만 준다. 퀘스트가
   룬을 주려면 codex 해금 보상 필드가 필요하다(§계약 영향 1). **D 전환의 핵심 core 작업.**
2. **`ChapterDef.mob_spawns` 신설** — 잡몹 길(§4).
3. **(선택) `GameState.coin_total()`** — HUD 편의(§2).

그 외(돈 통화·상점·예식·마을 상시화·조각/해독 은퇴)는 데이터·모듈 코드로 닫힌다. 신규 EventBus 시그널 0.

---

## 1. 3층 사다리 → 구체 훅 지도

| 층 | 타이밍 | 사건 | 발화 지점(노드/시그널) | 재사용 vs 신설 |
|---|---|---|---|---|
| **1층 틱** | 0.1~2s | 잡몹 킬 → 돈 드롭 → 자석 흡수 → 카운터 톡톡 | `forest_enemy._die`→`_roll_drops`(coin)→`drop_pickup`(자석/세51)→도착 `item_collected`·`resources_changed` | **전량 재사용.** coin.tres + DropEntry만 신설 |
| **1층 틱** | 즉시 | 타격 팝·숫자·흔들림 | `juice.gd`(세38·63)·`enemy_hit` | 재사용(무변경) |
| **2층 비트** | 10~60s | 보스 킬 → 상자 개봉(**재료만**) | `_spawn_chest`→`chest.gd`→`loot_panel`(세55) | 재사용. 조각 드롭 제거(§9) |
| **3층 성장** | 판당 | 귀환 → 상점(돈→잉크)·공방(돈/재료→도구)·정제대(재료→특별잉크) | `extraction_success`→`shop_panel`·`workshop_panel`·`refine_panel` | 상점 패널만 신설(refine 복제) |
| **3층 마퀴** | 판당 | 보스 퀘스트 **턴인** → 룬/진 획득 예식 | 마을 NPC 정산(`claim_ready_quests`)→`_complete_quest`→`codex_unlocked(rune_*/jin_*)` 관찰 오버레이 | QuestDef 보상 보강 + 예식 오버레이 신설 |

**연결 조직**: 잡몹=돈(1층·상점 연료) · 보스=재료(2·3층·제작 연료) · 마을 퀘스트=룬/진(최심 보상 통로).

---

## 2. 돈 통화 (coin) — 상세  [초안 유지]

### 데이터
- **`data/items/coin.tres`**: `id=&"coin"`, `kind=MATERIAL`, `grade=1`, `display_name="닢"`,
  `params={"cat":"money", "sprite":"res://assets/sprites/props/coin.png"}`.
  `cat="money"`로 창고/제작 재료 목록에서 특별 취급(필터) 훅 확보.

### 저장 / EventBus
- **신규 저장 필드 0** — coin은 `inventory`/`bag` dict의 키라 `SaveManager`가 이미 직렬화(라운드트립·`new_game`·시드 공짜).
- **신규 시그널 0** — 톡톡 = 기존 `item_collected`, 카운터 = 기존 `resources_changed`.

### 흐름 (A 확정 — 가방·사망 손실)
- 잡몹 킬 → coin DropEntry → drop_pickup 낱개 → 자석 → 도착 `add_to_bag`.
- 🔴 **돈은 가방 → 사망 시 손실(익스트랙션 판돈).** 무사 귀환해야 창고(지갑)로 들어가 상점에서 쓴다.
  "상점 소비 = 성공한 원정의 3층 보상"이 성립(세58 익스트랙션 유지).

### HUD 카운터 (`src/hud/hud.gd`)
- `_draw`에 좌상단 막대 아래 **돈 한 줄**(`🪙 %d` 텍스트/작은 코인 도트). 표시값 = 창고 coin + 가방 coin 합.
- **톡톡** = `resources_changed`/`item_collected` 수신 시 `_coin_punch`=1.0 → `_process`에서 감쇠(폰트·색 부풀림).
  기존 토스트 수명 `t` 방식과 동일. 🔴 연출값 = 스크립트 const.
- ⚠ **헤드리스 미검증** — 카운터 렌더·톡톡은 실게임 MCP 스샷(세64 — hud `_draw` 헤드리스 미실행).

### 잡몹 돈 드롭
- 각 잡몹 `data/enemies/*.tres`의 `drops`에 coin DropEntry 한 줄(`item_id=&"coin", chance=1.0, min/max`,
  엘리트 값↑). 🔴 **보스(drops_chest=true)엔 coin 미포함** — 돈=잡몹 낱개, 보스=상자(재료).

---

## 3. 상점 패널 (신규) — `src/base/shop_panel.gd` + `.tscn`  [B 반영: 상시·건설 없음]

### 핵심 판단: RecipeDef 재사용 (새 스키마 0)
- 재고 = `station=&"shop"` RecipeDef. 입력 `{coin:N}`, 출력 잉크. `Db.recipes_for_station(&"shop")`로 나열,
  `GameState.spend`(coin)·`add_item`(잉크). **ShopDef 신설 불필요.** 잉크 다양성 = shop 레시피 .tres 갯수.
- `data/recipes/shop_ink_*.tres`: `station=&"shop"`, `inputs={&"coin":N}`, `output_id=&"ink_<X>"`.
  **새 잉크 = shop 레시피 .tres 한 장.** 기본 잉크(색)=상점, 특별잉크(효과)=정제대 유지(소비처 안 겹침).

### 씬 트리 (refine_panel.tscn 복제 + 잔액 줄)
```
ShopPanel.tscn (루트 Control, 스크립트 shop_panel.gd)
└─ Center/Panel/Margin/VBox/{Title "상점", Coin "보유: N닢", List(레시피 행: 잉크명·N닢·[구매])}
```

### 모달 규약 (refine/loot/chapter 공통 — 세25 함정)
- `_ready`: `mouse_filter=STOP`·`visible=false`·`resources_changed`→`_refresh`. `open/close`: `ui_modal_open` 토글.
  `_unhandled_input` ui_cancel→close(visible 가드). `_buy(id)`: `spend(r.inputs)`→`add_item`+`Audio.play(&"craft")`, 미달 `disabled`.

### base 배선 (🔴 B — 건설 게이트 없이 상시)
- **상점 = 처음부터 있는 마을 시설.** `station_*` codex·`station_build_costs`·건설 퀘스트 **안 쓴다**.
- `base.tscn`에 `$Shop` InteractZone(zone_id=&"shop", layer64/mask2, Prompt "[E] 상점")을 **원색·상시**로 놓는다.
- `base.gd` `_ready`: `_shop_zone.interacted.connect(_open_shop_panel)` — `_station_interact`(건설 게이트) **경유 안 함**.
  `_open_shop_panel`/`_close_shop` = `_open_refine_panel`/`_close_refine` 복제(모달 슬롯 `_overlay` 공유).
- 🔴 **상인 겉모습 = 도형 금지** → **takbon-art `shopkeeper.png`**(48px, Apollo, 좌판/두루마리). 도형 스탠드인 금지.

### 🔴 B 파급: 정제대·공방·해독대의 상시화 (건설 온보딩 폐기)
- 세37 "빈 거점 재료 건설"(`_station_interact`가 `station_*` codex를 사서 여는 구조)을 **폐기**한다.
  마을은 시작부터 상점·정제대·공방·퀘스트 NPC가 다 있다. **해독대는 D로 통째 은퇴**(§9).
- `base.gd`: `_station_interact`·`_refresh_station(s)`·`NOT_BUILT_MOD`·건설 분기 제거 → 각 존은 바로 패널을 연다.
  `balance.station_build_costs`는 사장(스키마만 남김, 무해). 세37 memory(empty-base-build) 방향은 **뒤집힌다**(문서화).
- ⚠ 건설 상태를 codex(`station_*`)로 쓰던 저장 호환: 옛 세이브의 `station_*` codex 키는 그냥 무시된다
  (base가 더는 안 읽는다) — 조용한 갈라짐 없음. test_workshop_auto의 "레시피 station 분리"는 그대로 유효.

---

## 4. 챕터 확장 (잡몹 길 + 보스)  [C 반영: 보스 상자 = 재료만]

### 설계 (웨이브 FSM 없이 배치만 — buildable)
- **`ChapterDef.mob_spawns` 신설**(core — §계약 영향 2). 방 앞쪽(입구=남쪽)에 잡몹, 보스는 뒤(북쪽 `boss_spawn`).
- `boss_room._ready`에 `_spawn_mobs()`:
  ```
  for spawn in _chapter.mob_spawns:
      var m := EnemyScene.instantiate()       # forest_enemy.tscn 범용
      m.set(&"enemy_id", spawn.enemy_id)        # 🔴 add_child 앞(세58-B 함정)
      m.position = spawn.position               # 🔴 위치도 add_child 앞
      add_child(m)
  ```
  잡몹 = forest_enemy 계약 그대로(그룹 "enemies"·layer4·take_hit·`_die`→coin). 신규 씬 0.
- **클리어 = 보스 처치 그대로**(`_on_enemy_died`가 `boss_enemy_id` 확인). 잡몹 죽음은 clear 무접촉
  → 잡몹=돈·손맛(1층) · 보스=clear+상자+포탈(2·3층). `chapter_clear_*` codex·포탈·상자 유지.
- 🔴 **잡몹 접촉 피해 채널 유지**(세58-B 함정, 채널 커버리지 검산). forest_enemy 재사용이라 자동.
- **방 크기/카메라**: 잡몹 길로 세로 확장 — Ground rect 키우면 `_fill_tiles` 자동 추종. 남쪽 카메라 경계도 이때.

### 🔴 C 반영: 보스 상자 = 재료(mat_*)만
- 보스 `drops_chest=true` 적의 `drops`에서 **fragment_* 제거** → mat_* DropEntry만. 관문 조각 은퇴(§9).
- 잡몹 mat 드롭 제거(coin만) → 재료 공급은 **보스 상자로 일원화**. craft/refine/build 입력을
  basic=coin·advanced=보스mat로 재조정(데이터·balance, core 무접촉, §8).

---

## 5. 룬/진 획득 예식 (마퀴)  [D 반영: 트리거 = 퀘스트 턴인]

### 트리거 — 순수 오버레이(세36·52 패턴, 회귀 0)
- 신설 `src/actors/unlock_ceremony.gd`(vfx.gd·juice.gd처럼 EventBus 관찰만). **게임 로직 무접촉.**
- `EventBus.codex_unlocked` 수신 → id가 `rune_*`/`jin_*`이면 예식. (`chapter_clear_*`·`station_*` 무시.)
- 🔴 **발화 시점 = 마을 NPC 퀘스트 턴인**: `claim_ready_quests`→`_complete_quest`가 룬 해금을 `codex_unlocked`로
  쏘는 순간 오버레이가 잡는다(§9 룬 통로 재편). 해독대(옛 트리거)는 은퇴하지만 오버레이는 트리거원과 무관해 그대로 산다.

### 연출 훅 자리 (실제 셰이더·아트는 후속)
- 시간 슬로우: `Engine.time_scale` 딥→복귀. ⚠ 예식 타이머 `ignore_time_scale=true`(juice 선례 — 자동저장·복귀 왜곡 방지).
- 두루마리 배너: "새로운 룬: X" 중앙 Label/스프라이트 + 페이드/스케일. 🔴 아트=takbon-art, 글로우=takbon-shader(후속).
- 사운드: 기존 `Audio` unlock음 재사용(`codex_unlocked` 이미 연결).

---

## 🔴 9. 룬 획득 통로 재편: 관문(조각→해독) → 퀘스트 턴인  [D — 이번 개정의 최대 재편]

### 은퇴하는 것
| 대상 | 무엇 | 근거 |
|---|---|---|
| `DropEntry.until_unlock` 관문 기전 | 미해금 동안 조각 확정 드롭 | 조각이 사라지므로 통로 자체가 소멸 |
| `fragment_*` 아이템 | 룬 조각 | 보스 상자에서 제거(§4) — 재료만 |
| 해독대(decode) | `decode_panel`·`$Decode` 존·`station_decode` 건설·q05 | 조각→룬 변환처가 필요 없어짐 |
| PROGRESSION.md 관문표 | until_unlock 표·복원 레시피 | 퀘스트 턴인 표로 대체(리드가 정본 갱신) |

### 재사용하는 것 (신규가 적다)
- **퀘스트 시스템(세36)**: `QuestDef`·`requires` 사슬·`advance_quests`·`is_quest_satisfied`·소급 완료.
- **턴인(세40)**: 마을 NPC `_on_npc_talk`→`claim_ready_quests`→`_complete_quest`(보상 지급·`quest_completed`).
- **codex_unlocked·예식 오버레이(§5)**: 룬 해금 신호·마퀴는 그대로. 트리거 시점만 해독대→턴인으로 이동.

### 🔴 core 보강 필요 (핵심 발견)
- **지금 `QuestDef.reward_items`는 `add_item`(아이템)만 준다** — codex 해금(룬/진)을 못 준다(quest_def.gd·
  game_state `_complete_quest` 확인). 퀘스트가 룬을 주려면 **해금 보상 필드 신설**이 필요하다:
  - `QuestDef`에 `@export var reward_unlock: StringName = &""`(또는 `Array[StringName]`로 룬+진 동시 지급).
  - `GameState._complete_quest`가 `reward_items` 지급 뒤 `reward_unlock`이 있으면 `codex_unlocked.emit(reward_unlock)`.
  - → codex 심기 + UNLOCK 퀘스트 진행 + Audio + **예식**이 전부 따라온다(기존 `_on_codex_unlocked` 재사용).
- 🔴 **이게 D의 유일한 core 작업이다**(스키마 한 필드 + `_complete_quest` 한 줄). 리드 반영.

### 룬 퀘스트 사슬 (데이터 — 새 룬 = .tres 한 장)
- `data/quests/qR_<룬>.tres`: `goal=KILL`, `target=&"<보스 enemy_id>"`(예: slime_elite), `reward_unlock=&"rune_water"`,
  `requires=&"<이전 룬 퀘스트>"`. 보스 처치→`enemy_died`→`advance_quests(KILL)`→턴인 시 룬 지급+예식.
- 챕터 접근은 `chapter_clear` 게이트(chapter_panel)가, 룬 사슬은 quest `requires`가 각각 관리 — 두 축이 안 부딪힌다.
- 🔴 **보스 처치 한 방이 두 codex를 쏜다**: `chapter_clear_*`(챕터 게이트, boss_room 즉시) + 턴인 룬(퀘스트 정산).
  예식은 rune_*만 필터하므로 chapter_clear엔 안 뜬다(§5).

### 🔴 세57 "퀘스트=거울이라 은퇴" 방향의 반전 (근거 기록)
- 세57 결정 = 관문(조각→해독)이 해금의 주체고 퀘스트는 그 거울이라 은퇴 방향이었다(memory stage-format-decision).
- **지금은 뒤집혔다**: 관문 기전을 은퇴시키고 **퀘스트가 해금의 실제 주체**가 된다 → 거울이 아니라 통로다(중복 아님).
  사용자 확정 *"퀘스트 클리어로 룬을 주고 보스는 재료를 주자."* 이 문장이 세57 반전의 근거다.

---

## 🔴 온보딩 레일 재구성 (마을 완비 + 퀘스트=룬 통로)  [리드 질문 답]

### 현재 사슬 (세41, PROGRESSION.md)
q00 첫 도안 → q01 첫 사냥 · q02 첫 귀환 → **q03 정제대 건설 → q04 공방 건설 → q05 해독대 건설**(q05가 끝).

### 재구성 제안 (건설 사슬 삭제, 룬 첫 턴인으로 잇기)
```
q00 첫 도안(DRAW)  →  q01 첫 사냥(KILL, 챕터1 잡몹 아무나)  →  q02 첫 귀환(EXTRACT)
                                                                    │
                                            → qR1 "첫 보스를 잡아와"(KILL target=ch1 보스)
                                                → 마을 NPC 턴인 → reward_unlock=rune_2 + 예식(첫 룬!)
                                                    → qR2(requires qR1, ch2 보스) → …
```
- **건설 단계(q03~q05) 삭제** — 마을이 완비라 지을 게 없다. 그 자리를 "첫 보스 → 첫 룬 턴인"이 잇는다.
- 자연스러운가(내 판단): **그렇다.** 온보딩이 "그린다(q00) → 싸운다(q01) → 살아 온다(q02) → 더 세게 그릴
  새 룬을 벌러 보스에 도전(qR1)"으로, 코어 루프(그리기→원정→새 그림)를 첫 30분에 압축해 보여 준다.
  건설 온보딩은 "빈 마을 채우기"라 코어와 반보 떨어져 있었다 — 이 재구성이 온보딩을 코어에 더 붙인다.
- ⚠ **q00~q02는 유지**(첫 도안·사냥·귀환은 마을 유무와 무관한 코어 3박자). 세41 dialogue_box·튜토 대사도 유지.
  건설을 가르치던 대사만 "보스 잡아 룬 벌기"로 교체.
- 🔴 **사용자 확인 필요 지점**: qR1의 보상 룬이 무엇인지(현재 시드=rune_fire 1종, 세61) — 첫 턴인이 주는
  두 번째 룬을 사용자가 큐레이션해야 한다(PROGRESSION.md 복원 순서와 한 몸). 이 설계는 "빈 카탈로그에서
  퀘스트가 하나씩 룬을 여는" 틀만 깐다.

---

## 6. 데이터 흐름도 (sink → 층)  [개정]

```
[잡몹 킬] ──coin DropEntry──> [drop_pickup·자석] ──item_collected──> 가방(coin) ──귀환──> 창고(지갑)
                                                                                          │
                        ┌──────────────────────────────────────────────────────────────┤
                        ▼ (3층 sink)                                                     ▼ (3층 sink)
                   [상점] spend(coin) ──> 잉크 다양성                          [공방] spend(coin/재료) ──> 펜·도구(확정)
                        └──────────────► 그리기 재미 확장 ◄──────────────────────────────┘

[보스 킬] ──상자(mat_* 만)──> loot_panel ──> 가방 ──귀환──> 창고 ──> [정제대] 재료──> 특별잉크(효과)
     │                                                          └────> [공방 advanced] 보스mat──> 고급 도구
     ├──chapter_clear codex──> 다음 챕터 개방(챕터 게이트)
     └──enemy_died──> [보스 퀘스트 진행] ──마을 NPC 턴인──> reward_unlock: 룬/진 ──codex_unlocked──> [예식] 마퀴(3층)
                                                                                          │
                                                                              새로 그릴 것(최심 보상)
```
- **coin sink** = 상점(잉크 다양성) + 공방(도구, 결정3 "돈/재료").
- **재료 sink** = 정제대(특별잉크)·공방(고급 도구). 공급 = **보스 상자로 일원화**(C).
- **룬/진 통로** = 마을 퀘스트 턴인(D) — 조각·해독 우회 없음.

---

## 계약 영향 (건드리는 단일 소스 / core)

🔴 **리드가 core에 반영해야 할 것 셋**:

1. **`QuestDef.reward_unlock` 신설 + `GameState._complete_quest` 발신** (D의 핵심):
   - `@export var reward_unlock: StringName = &""`(룬+진 동시면 `Array[StringName]`).
   - `_complete_quest`: `reward_items` 지급 뒤 `if reward_unlock != &"": EventBus.codex_unlocked.emit(reward_unlock)`.
   - ⚠ 이미 해금이면 중복 발신 방지(`is_unlocked` 가드) — 재정산·소급 완료에 예식이 두 번 안 뜨게.

2. **`ChapterDef.mob_spawns` 신설** (잡몹 길):
   - 서브리소스 `MobSpawn`(`enemy_id: StringName`, `position: Vector2`) + `@export var mob_spawns: Array[MobSpawn]`.
   - ⚠ Color 4인자급 파싱 침묵사 주의(세50) — test_chapter_auto "챕터 로드" 그물이 잡게.

3. **(선택) `GameState.coin_total() -> int`** = `get_count(&"coin") + Σbag(coin)`. HUD 편의(없어도 됨).

**은퇴로 인해 지우거나 사장되는 것**(리드 판단·데이터/모듈):
- `DropEntry.until_unlock` 소비처(forest_enemy `_roll_drops`의 관문 분기) — 조각이 없어지면 죽은 분기.
  스키마 필드는 남겨도 무해(옛 세이브 호환), 데이터에서 안 쓰면 그만.
- `decode_panel`·`$Decode` 존·`base.gd`의 해독 배선·`station_build_costs`(건설 은퇴).

**건드리지 않는 단일 소스**(재사용): `ring_power`·`to_assembly`·`trace_scorer`·`ink_mult`·`grade_colors`·
`chapter_clear_id`·`is_chapter_open`·drop_pickup 레이어·loot_panel `loot_card/advance`·`claim_ready_quests`.

**신규 EventBus 시그널 = 0** (돈·상점·예식·룬 턴인 전부 기존 `codex_unlocked`·`item_collected`·`resources_changed`로 닫힌다).

---

## 회귀 위험 & 완화

| 위험 | 완화 |
|---|---|
| coin이 재료 목록에 섞여 오작동 | `cat="money"` 필터(refine/workshop/shop `_refresh`가 category 확인) |
| .tres 파싱 침묵사(coin·shop·mob_spawns·qR·reward_unlock) | "파일 만들었다≠완료 — Db 거쳐 로드 확인"(세50) + 뮤테이션 재점화 |
| 상점 새 Control mouse_filter STOP 함정 | refine/loot/chapter 규약 복제. 🔴 실게임 push_input 확인 |
| 🔴 마을 상시화가 건설 codex 저장 호환 깸 | base가 `station_*`를 더는 안 읽는다 → 옛 키 무시(조용한 갈라짐 없음). test_workshop 유효 |
| 🔴 조각/해독 은퇴가 test_decode/test_progression 깸 | 두 테스트 은퇴/재작성(§검증). 관문 그물이 사라져도 룬 통로는 test_quests가 지킨다 |
| reward_unlock 이중 발신으로 예식 2회 | `_complete_quest`의 `is_unlocked` 가드(boss_room chapter_clear 중복 방지 선례) |
| 잡몹 추가로 접촉 피해 채널 누락 | forest_enemy 재사용 자동 유지 — 채널 커버리지 검산(세58-B) |
| 예식 `Engine.time_scale`가 타이머 왜곡 | 예식 타이머 `ignore_time_scale=true`(juice 선례) |
| 코인 드롭 도형(마름모) | 🔴 도형 금지 — takbon-art `coin.png`. drop_pickup이 item sprite 그리는지 dev 확인 |
| 마을 완비로 온보딩 사슬 끊김 | q03~q05 삭제 자리를 qR1(첫 보스→첫 룬)이 잇는다(§온보딩). q00~q02 유지 |

---

## 구현 단계 (takbon-dev/ui/art)

**병렬 A (돈 통화 — core 무접촉):**
1. `takbon-art`: `coin.png`(엽전) · `shopkeeper.png`.
2. `data/items/coin.tres`(cat=money·sprite). Db 로드 확인.
3. 잡몹 `data/enemies/*.tres`에 coin DropEntry 추가 + **기존 mat 드롭 제거**(C).
4. `takbon-ui/dev`: `hud.gd` 돈 카운터 + `_coin_punch`. 🔴 실게임 MCP.

**병렬 B (상점 + 마을 상시화):**
5. `data/recipes/shop_ink_*.tres`(station=shop, coin 입력).
6. `takbon-ui`: `shop_panel.gd`+`.tscn`(refine 복제 + 잔액 줄).
7. `takbon-dev`: `base.gd` — `$Shop` 상시 배선 + **건설 게이트(`_station_interact`·`_refresh_station`) 제거**,
   정제대·공방 상시화. `base.tscn`에 Shop 노드·해독대 노드 제거(§9).

**리드 core (직렬, 먼저 합의):**
8. `QuestDef.reward_unlock` + `_complete_quest` 발신(is_unlocked 가드). `ChapterDef.mob_spawns`. (선택) `coin_total()`.

**병렬 C (챕터 잡몹 길 — 8 이후):**
9. `takbon-dev`: `boss_room._spawn_mobs()` + 방 크기/카메라. `data/chapters/ch*.tres` mob_spawns.
   보스 `drops_chest` 적의 fragment 드롭 제거 → mat만(C).

**병렬 D (룬 통로 재편 — 8 이후):**
10. 조각/해독 은퇴: `decode_panel`·`$Decode`·해독 배선 제거. `fragment_*`·`until_unlock` 데이터 정리.
11. `data/quests/qR_*.tres`(KILL 보스 + reward_unlock) + 온보딩 사슬 교체(q03~q05 삭제, qR1 편입).
12. `takbon-dev`: `unlock_ceremony.gd`(codex_unlocked 필터 + 배너 자리). 아트/셰이더 후속.

**mat_* 재조정(C):**
13. craft/refine/build 입력 basic=coin·advanced=보스mat 재조정(데이터·balance).

**리드**: 각 단계 후 전 스위트 + 뮤테이션 + 실게임 MCP. 커밋은 리드. PROGRESSION.md 정본 갱신(관문표→퀘스트 턴인표).

---

## 검증 포인트 (헤드리스 vs 실게임)

**헤드리스로 잡히는 것:**
- coin·shop 레시피·mob_spawns·qR·reward_unlock이 Db/파서에 로드되나(파싱 침묵사 그물 + 뮤테이션).
- `spend(coin)`/`add_item` 라운드트립 = 상점 구매 로직(`_buy` 공개 훅, refine 패턴).
- coin 저장→로드 라운드트립(inventory 블록 = test_save_auto 커버, 값 확인).
- 🔴 **test_quests_auto 확장**: `reward_unlock`이 턴인 시 `codex_unlocked`를 쏘나 + UNLOCK 퀘스트 진행/소급
  (뮤테이션: reward_unlock 발신 제거하면 룬 미해금으로 빨감). D의 핵심 그물.
- `boss_room._spawn_mobs`가 "enemies"에 N마리 + clear는 보스만(뮤테이션).
- 예식 오버레이가 `codex_unlocked(rune_*)`에만 반응·`chapter_clear_*`엔 무반응(필터 뮤테이션).

**🔴 실게임 MCP 필수:**
- 돈 카운터 렌더·톡톡(세64 — hud `_draw` 헤드리스 미실행).
- 상점 카드 **클릭 도달**(세25 mouse_filter — push_input, 캔버스 2배) + 렌더.
- 코인 드롭이 **진짜 엽전 스프라이트**로 자석 흡수(세54 도형 금지).
- 잡몹 길→보스→상자→포탈 전 루프 + 룬 턴인 예식 마퀴(방 크기·카메라·슬로우 체감).

**🔴 은퇴 테스트 거취:**
- **test_decode_auto** = 해독대 은퇴로 **폐기**(git 이력 보존). 세7 "목록에서 빠진 테스트는 낡아 죽는다"의
  역방향 — 은퇴는 목록에서 **명시적으로 뺀다**(CLAUDE.md 검증 명령 + takbon-verify 두 곳 동시, 세51 갈라짐 교훈).
- **test_progression_auto** = 관문(until_unlock) 은퇴로 **폐기 또는 재작성**. 룬 통로 검증은 test_quests_auto로 이관.
- test_chapter_auto = mob_spawns·보스 상자 재료화 반영해 **갱신**(폐기 아님 — 챕터 루프는 유지).

---

## 7. 열린 리스크 · 밸런스 (닫힌 결정 표기)

- **A. 돈 손실** — ✅ 닫힘: 가방(사망 손실).
- **B. 상점 형태** — ✅ 닫힘: 마을 완비 상시(건설 온보딩 폐기).
- **C. mat_* 거취** — ✅ 닫힘: 잡몹=coin 전용, mat_*=보스 상자.
- **D. 예식/룬 통로** — ✅ 닫힘: 퀘스트 턴인(조각·해독 은퇴).
- **E. 밸런스(사용자 F5)**: 잡몹 coin 수량·상점 가격·잡몹 밀도(mob_spawns)·coin 자석 반경(세50 실측)·
  예식 슬로우 강도. 전부 데이터/const라 코드 무변경.
- **G. 콘텐츠 리셋 정합(세61)**: 진1·룬1·문양1. 상점 잉크 재고·잡몹·qR 룬 보상은 **하나씩 복원**과 함께
  늘린다. 🔴 **첫 turn-in 룬(qR1 보상)이 무엇인지 = 사용자 큐레이션 필요**(§온보딩, PROGRESSION 복원 순서와 한 몸).
- **H. (신규) PROGRESSION.md 정본 전환**: 관문표(until_unlock)를 **퀘스트 턴인표**로 리드가 재작성. 복원 레시피
  ("룬 하나 = rune.tres + fragment + until_unlock 줄")도 "룬 하나 = rune.tres + qR.tres(reward_unlock)"로 갱신.

---

## 부록: "새 X = 파일 한 장" 성립표 (개정)

- 새 잉크 상품 = `data/recipes/shop_ink_*.tres` 한 장 → 상점 재고 자동.
- 새 잡몹 돈 드롭 = 적 .tres의 coin DropEntry 한 줄.
- 새 챕터 잡몹 배치 = `ChapterDef.mob_spawns` 항목(챕터 .tres 안).
- 새 제작(도구) = `data/recipes/craft_*.tres`(coin/재료) — 기존 공방 그대로.
- **새 룬/진 획득 = `data/runes|jin/*.tres` + `data/quests/qR_*.tres`(reward_unlock) 한 장** — 조각·해독 없이.
- 관문 예식 = 자동(codex_unlocked 관찰, 데이터 0).
```
