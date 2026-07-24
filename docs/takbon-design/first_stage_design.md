# 설계: 첫 스테이지 수직 슬라이스 — 조립→탁본 파이어볼 루프 base 편입

> ⚠ **부분 구현 (세78 교차 감사).** 🔴 **핵심(base 책상 [E] → 조립 슬라이스 패널 편입)은 반려됐다** —
> `base.gd`가 여전히 **책(`ring_forge_panel`)**을 연다. `book_redesign_design.md`가 "슬라이스 base 편입 = 너무 큰 변경"으로
> 반려하고 되돌려, 조립은 **책 안에서만** 돈다. **살아있는 것 = `ChapterDef.reward_unlock` 첫 클리어 해금 · gr_radiate5 맨몸
> 시드 제거 · ch1 reward** 뿐. 정합 후계 = `book_redesign_design.md`.
> 작성 = takbon-architect. (「읽고 나면 삭제」는 옛 관행 — 지금은 docs/takbon-design/ 영구 보관.)

---

## 목표 / 왜 (한두 줄)

세70 조립→탁본 슬라이스(현 F6 전용)를 **base 책상의 정식 흐름**으로 편입해 첫 플레이 루프를 만든다:
맨몸 파이어볼(밴드 빔) → ch1(slime_elite) 클리어 → 보상 `gr_radiate5` 해금 → 다시 슬라이스에서 밴드에 끼워 5방향 발산으로 진화. **최소·응집 통합** — 발사·채점·core 계약은 무변경 재사용, 신규 EventBus 시그널 0.

---

## 이미 있는 것 vs 새로 만들 것 (기존 배선 확인 결과)

### 이미 있어 재사용 (건드리지 않음)
- **조립 슬라이스 패널** `src/drawing/assembly_slice_panel.gd/.tscn` — 공개 API `open_panel()`/`close_panel()`/`board()`, 시그널 `committed(assembly)`. `build_assembly()`가 이미 세26 계약(`{ring_count,rune,jin,rings,open,score,ink,size}`)을 싣고 `score`도 실음. `available_rings()`가 codex 게이트(`_is_unlocked`)로 해금분만 목록. mouse_filter 규약 자체구현(루트 IGNORE·RightPane STOP 전면 커버·Board STOP). **base와 동형 = F6이 CanvasLayer 자식으로 이미 호스팅 중.**
- **발사 계약** `to_assembly()` 대응물 = `build_assembly()`(score 실음), `RingDesign.from_assembly`, `EventBus.ring_design_committed`, `ring_power`, `trace_scorer`, `Enums.GlyphCode` — 전부 무변경.
- **q00 DRAW 자동 진행** — `game_state.gd _on_ring_design_committed` → `advance_quests(DRAW)`가 `ring_designs.size()` **상태**로 판정. 즉 committed → `ring_design_committed.emit` 배선만 서면 **q00은 자동 유지**(추가 배선 0). 확인 완료.
- **boss_room 루프** — `_ready`→`_spawn_boss`+`_spawn_mobs`(이미 `mob_spawns` 지원)·`_on_enemy_died`가 boss id면 `_cleared`+`codex_unlocked(chapter_clear_id)`(첫 클리어 가드)+귀환 포탈. `Ground.mouse_filter=2` 있음.
- **ch1.tres** — order 1·title "숲 어귀"·boss `slime_elite`·mob_spawns 빔.
- **gr_radiate5.tres** — `unlock_id=&"gr_radiate5"`(자기 게이트)·motif 1(발산)·count 5.
- **base 오버레이 패턴** `_open_drawing`/`_close_drawing`(player.set_physics_process(false)·caster.enabled=false·ui_modal_open=true·CanvasLayer layer 10).

### 새로 만들 것 (전부 얇음)
1. base `_open_drawing`을 **구 책 대신 슬라이스**를 열도록 재배선 + committed→장착+닫기 경로(dev).
2. 슬라이스 패널에 **`signal closed` + ESC(ui_cancel) 처리** 추가 — base 오버레이가 `closed`로 닫는 대칭 유지(dev, 모듈-로컬 시그널이라 core 아님).
3. **`ChapterDef.reward_unlock: StringName`** 1필드 + boss_room 첫 클리어 시 발신 1줄(**리드/core**).
4. `_seed_starting_unlocks`에서 `gr_radiate5`·`gr_gather3` 시드 2줄 제거(**리드/core**).
5. ch1.tres에 `reward_unlock=&"gr_radiate5"` + `mob_spawns` 잡몹 길(data 한 장씩).
6. 온보딩 대사(DRAW_TUTORIAL_LINES) 텍스트를 슬라이스·견습마법사 프레이밍으로 교체(dev).

---

## 씬 트리 / 노드 책임

base 편입은 **새 노드 트리를 안 만든다** — 기존 `_overlay` 슬롯을 그대로 쓴다.

```
base.tscn (Node2D, 진입점)
├─ (기존 그대로) Ground(ColorRect, mf=2) · TileGrass · TileRoad · Player · Hud · Desk · ...
└─ _overlay : CanvasLayer(layer=10)          ← _open_drawing()이 런타임 생성 (기존 패턴)
   └─ AssemblySlicePanel(Control)            ← forge_scene 대신 이걸 instantiate
      ├─ RightPane(Control, mf=0, full-rect)  = 클릭 전면 캡처 → 루트 forward
      └─ Board(Control, RingBoard)            = 손 트레이스
```

노드 책임:
- **base.gd** — 책상 [E] → 슬라이스 열기(player·caster off, ui_modal_open on), `committed`·`closed` 수신 → 장착·닫기. 호스트 역할만(발사·채점 무참조).
- **assembly_slice_panel** — 조립(밴드 소켓)·통째 트레이스·분석·주입·`build_assembly`. **소유권 불변**: 진 자동선택(jin_single)·룬 고정(fire)은 현행 1종 카탈로그라 그대로.
- **boss_room.gd** — ch1 실행·클리어 시 `reward_unlock` 발신(신규 1줄).

---

## 시그널 맵

```
[base 책상 흐름]
$Desk.interacted ──▶ base._open_drawing()
   슬라이스.committed(assembly) ──▶ base._on_slice_committed()
        └─ RingDesign.from_assembly(assembly,"고리 마법진")
        └─ EventBus.ring_design_committed.emit(design)   (기존 시그널 재사용)
             ├─▶ GameState 첫 빈 슬롯 자동 장착 (기존)
             ├─▶ GameState.advance_quests(DRAW)  → q00 자동 완료 (기존, 상태 판정)
             └─▶ base._refresh_npc_mark (기존 연결)
        └─ base._close_slice()  (오버레이 free·player/caster 복귀)
   슬라이스.closed ──▶ base._close_slice()   (ESC 취소)

[보상 해금]
boss_room._on_enemy_died(boss id, 첫 클리어)
   ├─ EventBus.codex_unlocked.emit(chapter_clear_id)   (기존)
   └─ EventBus.codex_unlocked.emit(reward_unlock)       ★ 신규 1줄, reward_unlock!=&"" 이고 미해금일 때만
        └─▶ GameState.codex[gr_radiate5]=true → 다음 슬라이스 방문 때 available_rings()에 등장
```

### 🔴 신규 EventBus 시그널: **없음** (목표 달성)
`codex_unlocked`·`ring_design_committed` 재사용. 슬라이스 패널의 `closed`는 **모듈-로컬 signal**(EventBus 아님) → dev가 추가 가능, core 무관.

---

## 데이터 흐름 (.tres 스키마 신규 표기)

- **`ChapterDef.reward_unlock: StringName = &""`** ← 🔴 **신규 필드, 리드가 core에 추가**.
  - ch1.tres: `reward_unlock = &"gr_radiate5"`
  - ch2/ch3.tres: 필드 미기재 = 기본 `&""` = 무발신(회귀 0).
  - 근거(QuestDef.reward_unlock 턴인 대신 ChapterDef 직접 해금 선택): 첫 슬라이스엔 퀘스트 턴인 예식이 과함. 보스 처치 = 즉시 해금이 루프를 가장 짧게 닫는다. 도파민 설계의 퀘스트 턴인은 콘텐츠가 늘 때(qR* 사슬) 도입. **ChapterDef가 "새 챕터 = .tres 한 장"에 reward 한 축을 더하는 것 = 데이터 주도 원칙과 정합.**
- **`ch1.mob_spawns: Array[MobSpawn]`** — 잡몹 길(아래 §ch1 튜닝). 스키마 무변경(기존 MobSpawn: enemy_id·position).
- 시드 제거: `game_state.gd _seed_starting_unlocks`의 `codex[&"gr_radiate5"]=true`·`codex[&"gr_gather3"]=true` 2줄 삭제. 남는 시드 = `rune_fire`·`jin_single`뿐 = 맨몸 파이어볼.

---

## 계약 영향 (단일 소스 함수)

| 단일 소스 | 영향 |
|---|---|
| `ring_power.gd`(펑/위력/등급) | **무변경**. 슬라이스가 이미 `is_stable`·`power_display`·`grade_of` 호출 중 |
| `to_assembly()`/`build_assembly` score 계약 | **무변경**. `build_assembly`가 score 이미 실음 |
| `RingDesign.from_assembly` | **무변경**. base._on_slice_committed가 그대로 호출(구 `_on_ring_committed`와 동일 형태) |
| `trace_scorer`·`Enums.GlyphCode` | **무변경** |
| `Db.chapter_clear_id` | **무변경**. reward_unlock은 그 옆 별도 한 줄 |
| `_seed_starting_unlocks` | 시드 2줄 **삭제**(축 변경 아님·데이터만) |

신규 core 작업(리드): ① `ChapterDef.reward_unlock` 필드 ② boss_room `_on_enemy_died` 발신 1줄 ③ 시드 2줄 삭제. **스키마 필드 1·발신 1·삭제 2.**

---

## 회귀 위험 & 완화

| # | 위험 | 원인/증상 | 완화 |
|---|---|---|---|
| R1 | 🔴 **슬라이스 base 호스팅 후 클릭이 안 닿음** | 세25 함정 — 화면 덮는 패널의 mouse_filter. 새 호스팅 컨텍스트 | 슬라이스 RightPane(mf=0)이 **전면 커버**하고 루트로 forward = 구조적으로 F6과 동일. 그래도 **실게임 push_input 필수**(헤드리스 못 잡음) — 소켓 클릭·트레이스·[분석]/[주입] 도달 |
| R2 | 🔴 **ESC로 슬라이스를 못 닫아 갇힘** | 슬라이스에 원래 ESC/`closed` 없음(F6은 E 토글) | dev가 `signal closed`+ESC(ui_cancel) 추가 → base가 `closed`로 `_close_slice`. **주입 거부는 패널 내부 `try_inject` notice가 처리**(committed 무발신)라 base rejected 핸들러 불필요 = 구 책의 `commit_rejected` 배선 은퇴 |
| R2b | committed 후 안 닫힘 | base가 닫기를 안 하면 맺고도 패널 잔류 | `_on_slice_committed`가 emit **후 즉시 `_close_slice`**(F6 `_on_committed` 선례) |
| R3 | 구 책 대체가 **기존 테스트 깸** | `test_ring_forge_panel`(F6 .tscn)·`test_ring_book_jin_auto`가 ring_forge_panel 참조 | **구 책 파일·그 F6/테스트는 안 건드린다** — base 흐름만 바꾼다. 두 테스트는 base를 안 거쳐 그대로 그린. base를 직접 여는 헤드리스 테스트 없음(base.gd `_open_drawing`은 실게임 검증 영역) |
| R4 | q00 DRAW가 안 진행 | 슬라이스 committed가 ring_design_committed를 안 쏘면 온보딩 사슬 막힘 | `_on_slice_committed`가 반드시 `ring_design_committed.emit` — q00은 `ring_designs.size` 상태 판정이라 이 발신만으로 소급 충족 |
| R5 | 시드 제거가 **save 라운드트립·new_game 깸** | `_ready`·`new_game` 둘 다 `_seed`를 부름 | 두 경로가 같은 함수 호출 → 갈라짐 0. codex는 저장/로드되는 Dict이라 **기존 세이브**에 gr_radiate5가 이미 true면 유지(맨몸 시작은 신규 게임만). ⚠ 세이브 격리(-s save_test)·백업→복원 규칙 준수. test_save_auto 라운드트립은 codex 키 집합에 무관 |
| R6 | gr_gather3 도달 불가 | 시드 제거 후 gr_gather3는 해금 경로 없음 | **스코프 밖 명시** — 후속 스테이지 보상(ch2/ch3 reward_unlock)이 나올 때 연결. gr_gather3.tres는 남겨 둠(삭제 아님) |
| R7 | reward가 재입장마다 재발신 | 파밍 재방문 시 codex_unlocked 도배(Audio·퀘스트) | `is_unlocked(reward_unlock)` 가드 + `reward_unlock != &""` 가드 (chapter_clear 가드와 같은 결) |
| R8 | 진/룬 피커 부재 | 슬라이스가 jin_single·fire 하드코딩 | **의도적 스코프 밖** — 현행 진1·룬1이라 무해. 진·룬이 늘면 그때 피커(별도 세션). CLAUDE 룬 하드코딩 함정은 "assembly.rune이 쥔다"인데 build_assembly가 `RUNE_FIRE`를 assembly.rune에 실어 계약은 지켜짐(카탈로그 1종 한정) |

---

## 구현 단계 (역할별 순서)

### 1) 리드 (core — 직접)
- `ChapterDef`에 `@export var reward_unlock: StringName = &""` 추가(주석: 첫 클리어 시 codex 해금·기본 무발신).
- `boss_room._on_enemy_died`에 첫 클리어 블록 안(`_cleared` 세팅 뒤)에서:
  `if _chapter.reward_unlock != &"" and not GameState.is_unlocked(_chapter.reward_unlock): EventBus.codex_unlocked.emit(_chapter.reward_unlock)` + HUD 한 줄(해금 이름). chapter_clear 발신 바로 다음.
- `game_state.gd _seed_starting_unlocks`에서 `gr_radiate5`·`gr_gather3` 시드 2줄 삭제.

### 2) dev (모듈 — src/drawing + src/base)
- `assembly_slice_panel.gd`: `signal closed` 추가 · ESC(`_unhandled_input`에서 `ui_cancel` action) → `close_panel()` 후 `closed.emit()`. (⚠ 패널이 modal 위라 `_unhandled_input`이 옴 — 다른 패널 ESC 규약 참고. 루트 mf=IGNORE라도 key input은 받음.)
- `base.gd`: `const AssemblySlicePanelScene := preload("res://src/drawing/assembly_slice_panel.tscn")`(base↔drawing preload 이미 성립) · `_open_drawing`을 슬라이스 instantiate로 교체(player/caster off·ui_modal_open·overlay layer 10) · `committed`→`_on_slice_committed`·`closed`→`_close_slice` 연결 · `open_panel()` 호출.
  - `_on_slice_committed(assembly)`: `RingDesign.from_assembly` → `ring_design_committed.emit` → `_close_slice()`.
  - `_close_slice()`: 오버레이 free·player/caster 복귀·ui_modal_open=false (구 `_close_drawing` 재명명/재사용).
  - 구 `_on_ring_committed`·`_on_ring_rejected`·`_forge` 필드·forge_scene @export 배선은 제거(또는 forge_scene export는 남기되 미사용 표기). `RingForgePanelScript` preload는 슬라이스 전환 후 미사용이면 정리.
- `base.gd DRAW_TUTORIAL_LINES` 텍스트 교체(§온보딩).

### 3) data (dev 또는 리드)
- `ch1.tres`: `reward_unlock = &"gr_radiate5"` + `mob_spawns` 채움(§ch1 튜닝).

### 4) art
- **거의 없음**(견습=플레이어 자신·상자 없음·잡몹은 기존 slime/beetle 스프라이트). 신규 아트 0 목표. 도형 플레이스홀더 금지 대상 없음.

### 5) 리드 (검증·커밋)
- 전 스위트 + 뮤테이션 + 실게임 MCP(아래).

---

## ch1 튜닝 (첫 파이어볼 스테이지)

- **보스**: slime_elite 유지(boss_spawn 북쪽 (0,-260)).
- **잡몹 길** `mob_spawns` — 방 ≈1200×1040, 플레이어 입구 남쪽. 파이어볼 입문이라 **약한 잡몹 소수**(slime·beetle). 예: 입구~보스 사이 중앙대에 3~4마리 산개(예: (-140,120)·(160,60)·(0,-40)·(-40,-160) 부근). 🔴 **정확한 좌표·수·종류는 사용자가 F5로 조인다**(밸런스는 플레이 튜닝). 카메라 남쪽 경계 안에서 첫 화면에 1~2마리 보이게.
- 잡몹은 죽으면 coin 드롭(기존 forest_enemy 계약) = 즉시 보상 1층. 클리어는 보스 처치만.

---

## 온보딩 대사 플레이버 (견습마법사 프레이밍)

- **새 NPC·아트 0** — 텍스트만. `base.gd DRAW_TUTORIAL_LINES` 5줄을 슬라이스 흐름으로 교체:
  - 구 책 설명("오른쪽에서 진·룬·문양을 고르고")은 **거짓말이 됨** → 조립 슬라이스 설명으로.
  - 새 방향(예): "자네는 아직 견습이지 — 가진 건 불의 진 하나뿐일세." / "책상에서 밑그림을 통째로 손으로 따라 긋게. 정성껏 그을수록 세지네." / "지금은 맨 불덩이지만, 숲에서 문양-고리를 얻어 오면 밴드에 끼워 불을 여러 갈래로 터뜨릴 수 있네." / "[분석 ▶]으로 점수 보고 [마력 주입]으로 맺게. 엉성하면 펑 하니 조심." / "저 책상으로 가서 [E]. 목표는 [Tab] 시트에서."
  - 🔴 **정확한 문구는 사용자 확정** — 위는 방향 제안. "밴드에 문양-고리를 끼운다" 어휘가 3번 보상 루프를 예고하게.
- q02(EXTRACT)·q01(KILL) 텍스트는 ch1 흐름과 이미 정합 — 무변경.

---

## 검증 포인트 (헤드리스 vs 실게임)

### 헤드리스로 잡히는 것
- `test_assembly_slice_auto` — 기존 그물 유지(committed assembly에 score/rings/rune/jin·flatten_bands 라운드로빈·compose_guide). **base 편입은 이 테스트 무영향**(패널 API 불변).
- `test_chapter_auto` — ch1 로드·클리어 키 파생. 🔴 **`reward_unlock` 발신 그물 추가 권고**: ch1 보스 처치 시 `codex[gr_radiate5]` 심기고, 미등록 reward(&"")는 무발신 — **뮤테이션(발신 줄 제거)으로 검출력 확인**. chapter_clear와 별도임을 그물로 못박기.
- `test_save_auto` — 시드 제거 후에도 라운드트립 그린(codex 키 집합 무관). new_game 경로 codex에 gr_radiate5 부재 확인 그물 권고(맨몸 시작 계약).
- `test_progression_auto` — 무영향(관문 데이터 은퇴 상태).
- SCRIPT ERROR grep 필수(슬라이스 ESC/닫기 null 가드).

### 🔴 실게임(F5/MCP) 전용 — 헤드리스 절대 못 잡음
- **세25 클릭 도달**: base 책상 [E]→슬라이스 열림→소켓 클릭·좌 트레이스·[분석]/[주입] **push_input**으로 도달 확인. 맺고 닫힌 뒤 좌클릭 발사 복귀 확인. ⚠ 실세이브 **백업→복원** 먼저(세65 실수 반복 금지).
- **세70 통째 트레이스 손맛**: 파이어볼 밑그림을 손으로 긋는 감·밴드 간격 — 사용자 F5.
- **루프 전체**: 맨몸 파이어볼 발사 → ch1 진입 → 잡몹·보스 처치 → gr_radiate5 해금 HUD → 마을 복귀 → 슬라이스에서 gr_radiate5 밴드 끼움 → 5방향 발산 발사. MCP로 발산 탄 5갈래 렌더 확인.
- **q00 완료**: 슬라이스로 첫 맺기 → 길잡이 [?] 정산 → q00 완료 팝. ESC 취소 시 갇힘 없음.
- **ESC 닫기**: 슬라이스에서 ESC→닫힘·player 복귀(신규 경로라 실측).

---

## 스코프 밖 (명시적으로 안 함)

- 진/룬 피커(슬라이스 jin_single·fire 하드코딩 유지) — 진·룬 카탈로그가 늘 때.
- gr_gather3 획득 경로 — 후속 챕터 reward_unlock.
- 획득 예식 오버레이(도파민 §5 unlock_ceremony) — **미룸**. 최소 슬라이스는 boss_room HUD 한 줄(해금 이름)로 충분. 기존 codex_unlocked가 Audio 해금음·UNLOCK 퀘스트 진행은 이미 태움.
- 필드 문양-고리 낱개 드롭(아트 필요) — reward_unlock codex 게이트로 대체.
- 구 책(ring_forge_panel) 파일 삭제 — 남겨 둠(F6·test_ring_book_jin_auto 소비). 메인 흐름에서만 은퇴.
- q03~q05 건설 퀘스트 은퇴(도파민) — 이 슬라이스 범위 아님.
```
