# 설계: 고리 조립 책을 세70 「조립→탁본」 흐름으로 재설계

> 산출물 = takbon-dev/리드가 바로 받는 **구조 설계**. 게임 디자인은 확정(AskUserQuestion — 재논의 없음).
> 범위 = **기존 책 UI(ring_forge_panel + ring_book) 유지, 내부 흐름만 세70으로.** base·발사·core·저장 계약 무변경 목표.
> 🔴 세70 슬라이스를 base에 편입했다가 "너무 변경했다"고 반려 → 되돌림. 이번엔 **책 안에서만** 바꾼다.

---

## 목표 / 왜

책의 흐름을 **단계별 트레이스(진→[다음]→룬→[다음]→문양 칸마다)**에서 **조립 후 통째 트레이스(진·룬 고르고 층에 문양-고리 끼운 뒤 전체를 한 번에 손으로 긋기)**로 바꾼다. 세70 슬라이스가 F6에서 이미 증명한 흐름을, **기존 책 껍데기(양피지·잉크/종이 팔레트·분석 리포트·open/close/design_committed/commit_rejected)를 그대로 두고** 책 내부에 접목한다.

핵심 통찰 = **필요한 엔진은 전부 이미 있다.** `RingBoard.compose_guide`/`flatten_bands`/`enter_combined_trace`/`combined_total`은 세70에 **보드에 가산**됐고(슬라이스 패널이 아니라 보드에), `assembly_slice_panel.gd`는 그 흐름의 **로직 참조**다. 이 설계는 "새 흐름 발명"이 아니라 **슬라이스 로직을 책 껍데기에 이식 + RingBook 문양 탭을 층 소켓으로 교체**다.

---

## 이미 있는 것 vs 새로 만들 것 (기존 배선 확인 결과)

### 그대로 재사용 (무변경)
| 파일/계약 | 재사용하는 것 |
|---|---|
| `RingBoard.compose_guide`·`glyph_ring_pts`·`flatten_bands`·`enter_combined_trace`·`combined_total`·`TraceTarget.COMBINED` | **세70에 이미 보드에 있다.** 책이 그대로 호출. `_gui_input`의 COMBINED 입력 경로도 이미 처리됨(STAGE_GLYPH 분기를 안 타므로 좌클릭 드래그가 통째 트레이스로 흐른다 — 실측 확인). |
| `RingBoard` stage machine(`advance`/`finish`/`choose_jin`/`choose_rune`/`_build_guide`/`STAGE_*`) · `RingAssembly`(`_open`/`_slots`/`place_glyph`/`set_open_slots`) | **삭제하지 않는다.** 책이 안 쓸 뿐, 유닛 테스트가 직접 검증. 슬라이스 패널이 이미 이 경로를 안 건드리는 선례. |
| `trace_scorer.gd` | 무변경. 합성 가이드 = 그냥 긴 단일 가이드(`set_guide`). |
| `ring_power.gd`(is_stable/power_display/grade_of/is_perfect) | 무변경, 그대로 호출. |
| `RingDesign.from_assembly`·`to_assembly()`·`Enums.GlyphCode` | 무변경 — 플래튼된 8칸이 기존 `rings`에 담긴다. |
| `GlyphRingDef`·`Db.all_glyph_rings()`/`get_glyph_ring()`·codex 게이트·GameState 시드 | **세70에 이미 core에 존재.** ch1 클리어→gr_radiate5 배선도 있다. |
| `ring_forge_panel` 껍데기: open/close/spread anim·`_fit_stage`·잉크/종이 팔레트·`_draw_report`·`_draw_pages`·`design_committed`/`commit_rejected`/`closed` | 유지. base가 무는 계약 그대로. |
| `base.gd`(책을 열고 assembly를 받음) | **무변경.** 책이 내는 시그널이 동일하므로 base는 안 건드린다. |

### 새로 만들 것 (전부 모듈-로컬 — core 아님)
| 무엇 | 어디 | 누가 |
|---|---|---|
| 문양 탭 → **층 소켓 UI** (밴드 소켓 + 보유 문양-고리 목록) | `ring_book.gd` | dev/ui |
| RingBook 새 시그널 `band_selected`·`ring_picked` (glyph_selected 대체) + `set_bands(...)` 주입 | `ring_book.gd` (모듈-로컬, EventBus 아님) | dev |
| 책 흐름 스왑: `_bands` 소유 + `recompose()`(=compose_guide→enter_combined_trace) + `build_assembly()`(=flatten+score+ink+size) + 단일 리포트 | `ring_forge_panel.gd` | dev |
| 테스트 재작성/이관 (아래 「테스트 이관」) | `tests/` | 리드 |

🔴 **`assembly_slice_panel.gd` = 로직 참조(청사진)이지 재사용 모듈이 아니다.** 그 안의 오케스트레이션(`socket_ring`/`band_defs`/`recompose`/`build_assembly`/`try_inject`/`available_rings`, ~60줄)을 책으로 이식한 뒤 **은퇴시킨다**(아래 「slice 패널 거취」).

---

## 씬 트리 / 노드 책임

**씬 트리는 무변경**(`ring_forge_panel.tscn`). 노드 책임만 바뀐다:

```
RingForgePanel (Control)                 # 책 컨테이너 — 흐름 오케스트레이터 + _bands 소유(신규)
└─ Stage (640×360 논리 무대, _fit_stage)
   └─ Spread (책 펼침 anim)
      ├─ Pages/BookArt/Paper             # 껍데기 렌더 — 무변경
      ├─ RingBoard  (왼쪽 판)            # 통째 트레이스만 받음(enter_combined_trace). stage machine 안 탐
      ├─ RingBook   (오른쪽 3탭)         # 진·룬 탭=유지 · 문양 탭=층 소켓+고리 목록(신규)
      ├─ NextBtn                         # 🔴 은퇴(숨김 또는 제거) — [다음] 단계 이동이 사라진다
      ├─ CommitBtn  ("분석 ▶")           # 통째 트레이스 coverage>0이면 활성
      ├─ ScoreLabel                      # "이 조각" → "종합" 완성도·정밀도 (통째)
      ├─ Title/Say/Hint
      └─ Report (Control, _draw_report)  # 조각별 행 → 단일 종합 줄(신규)
```

**노드 책임 이동:**
- **RingForgePanel** — 새로 `_bands: Array[StringName]`(층 2칸)·`_sel_band`·`_sel_jin: StringName`·`_sel_rune: int`을 **패널이 쥔다**(슬라이스 패널이 `_bands`를 쥔 규율 그대로 — RingAssembly는 Db를 몰라 층 전개를 못 한다). 선택이 바뀔 때마다 `recompose()`.
- **RingBoard** — `choose_jin`/`advance`/`finish` 대신 `set_defs(jd,…)`(색만)·`enter_combined_trace(guide)`·`combined_total()`만 부른다. stage machine·per-piece 잠금은 **책이 안 건드린다**.
- **RingBook** — 진/룬 탭 그대로. 문양 탭만 **개별 문양 격자 → 층 소켓 UI**. 밴드/고리 상태는 **패널이 주입**(`set_bands`), 책은 렌더+클릭만(오토로드 안 봄 = 기존 규율).

---

## 시그널 맵

**신규 EventBus 시그널 = 0.** RingBook의 새 시그널은 **모듈-로컬**(패널↔책, EventBus 아님)이라 dev가 추가한다.

```
[RingBook → RingForgePanel]  (모듈-로컬)
  jin_selected(jin_id)      유지  → 패널: _sel_jin=jin_id · board.set_defs(jd,…) · recompose()
  rune_selected(rune_type)  유지  → 패널: _sel_rune=rune_type · recompose()
  band_selected(i)          신규  → 패널: _sel_band=i · book.set_bands(...) 되돌림(강조)
  ring_picked(gr_id)        신규  → 패널: _bands[_sel_band]=gr_id · recompose() · set_bands 갱신
  glyph_selected(glyph)     🔴 은퇴 (개별 문양 배치가 사라짐)

[RingForgePanel → RingBook]
  set_bands(bands, sel_band, available_rings)   신규 주입(set_defs와 동형) — codex 필터는 패널이 계산

[RingBoard → RingForgePanel]
  (stage_advanced·piece_locked·finished·score_changed 연결 해제)  # 통째 흐름은 이 시그널을 안 씀
  stroke_ended             유지  → 미뤄둔 잉크 팔레트 재빌드 (경제 보존)
  score_changed(신규 용도)  옵션  → 통째 트레이스 중 실시간 점수 라벨 갱신용으로 재사용 가능
                                    (없으면 패널이 _gui_input 후 폴링/타이머로 combined_total 읽어 표시)

[RingForgePanel → base]  (기존 계약, 무변경)
  design_committed(assembly) · commit_rejected(score) · closed
```

🔴 **리드가 core에 반영할 것 = 없음.** GlyphRingDef·Db·시드 전부 세70에 이미 있고, RingBook 새 시그널은 모듈-로컬이라 dev가 붙인다. (선택 `RingDesign.bands` 출처 필드는 세70 설계에서 이미 "필수 아님"으로 판정 — 이번에도 넣지 않는다.)

---

## 데이터 흐름

```
[조립] (안 그림)
  진 탭 클릭  → jin_selected  → 패널 _sel_jin        ┐
  룬 탭 클릭  → rune_selected → 패널 _sel_rune        │ 셋 중 하나라도 바뀌면
  문양 탭:                                             │   recompose()
    소켓 클릭 → band_selected → 패널 _sel_band        │
    고리 클릭 → ring_picked   → 패널 _bands[_sel]=gr  ┘

[합성] recompose():
  band_defs = _bands.map(id → Db.get_glyph_ring(id))         (패널이 Db 조회)
  jin_shape = Db.get_jin(_sel_jin).guide_shape
  guide = RingBoard.compose_guide(jin_shape, _sel_rune, band_defs, ctr, ro)
        = jin_guide_pts + rune_guide_verts + glyph_ring_pts×층   (전부 기존 static)
  board.enter_combined_trace(guide)                            (TraceScorer.set_guide 무변경)

[트레이스] 왼쪽 판 좌클릭 드래그 → board.trace_stroke (통째)
           완성도×정밀도 = board.combined_total()

[분석] [분석 ▶] → combined_total → 단일 리포트
       RingPower.grade_of / is_perfect / power_display(total, ink_mult, size)

[맺음] [마력 주입] → RingPower.is_stable(total)?
   ├ 아니오 → commit_rejected 계열 처리(펑/notice) — 침묵 금지 (아래 계약)
   └ 예     → build_assembly():
              rings = [flatten_bands(band_defs)]         (8칸 라운드로빈)
              { jin:_sel_jin, rune:_sel_rune, rings, open,
                score:combined_total, ink:_active_ink, size:_size_mult }
              → design_committed(assembly) → base → GameState.ring_designs 자동 장착

[발사] EventBus.ring_cast_requested → ring_spell_system → rings[0] 슬롯 전개  (무변경)
```

🔴 **결정적 정확성 포인트 — `_board.get_assembly()`를 쓰지 마라.** COMBINED 모드에서 `_asm`은 비어 있어(`place_glyph` 안 함) `get_assembly()`의 `score`(=`get_analysis` on empty `_asm`)와 `rings`가 **빈 값**이다. 반드시 **패널이 `build_assembly()`를 직접 조립**한다: `rings`=`flatten_bands`, `score`=`combined_total()`, `ink`/`size`는 패널의 팔레트 상태. 이게 세26 함정(`score` 안 실으면 조용히 기준 위력)의 이번 판 재현 자리다.

**신규 .tres 스키마 = 없음.** GlyphRingDef 재사용.

---

## 잉크·종이(책 경제) 보존 — 세26 계약

슬라이스 패널엔 없던 잉크/종이를 책은 **싣는다**(경제 보존). 다만 통째 흐름엔 per-stage 진 크기 휠이 없다(`_resize_current`는 COMBINED를 안 탐):

- **잉크(ink)** — 팔레트 그대로. `_active_ink`를 `build_assembly`의 `ink`에 싣는다(등급 배수=데미지, `Db.ink_mult`). 획 색은 `board.set_trace_ink`로 즉각 피드백. 특별잉크 소모·`stroke_ended` 재빌드도 그대로(통째 트레이스도 획 단위라 정산 로직 유효).
- **크기(size/종이)** — 🔴 **결정 필요(사용자·리드 확정 대상).** 두 안:
  - **(권고·안전) 스칼라만 싣는다** — 종이 등급 → `_size_mult`(=`Db.paper_zoom_max(id, default)`)를 `build_assembly.size`에만 싣고 **합성 가이드 기하는 고정 `ro`**로 둔다. 데미지 경제(`RingPower.power_display`의 size_mult)는 보존, "큰 원=오버플로우" 회귀(세50 좌표 실측 자리) 없음. 대가 = 종이가 화면에서 "커 보이지" 않고 데미지 숫자로만 작동.
  - **(리치) 가이드도 키운다** — `recompose`에서 `ro *= _size_mult`. "종이=규모"의 시각 의미 복원. 대가 = 합성 가이드가 판을 넘칠 위험 → `_size_mult` clamp + 좌표 실측 필수.
  - → **권고 = (안전).** paper_zoom_max가 이미 ~1.16으로 좁아 시각 차가 작고, 통째 트레이스는 오버플로우에 더 취약하다. 리치는 손맛 보고 후속.

---

## 문양 탭 = 층 소켓 UI (RingBook 재설계 상세)

```
문양 탭 (신규):
  ┌ 층 소켓 (밴드 N칸 — 최소 2)
  │   [ 밴드 1: (고리 아이콘) 발산 고리 ×5 ]   ← _sel_band 강조
  │   [ 밴드 2: 비었다 (아래에서 고리 끼우기) ]
  ├ 보유 문양-고리 (codex 해금분만 — 패널이 available_rings로 필터해 주입)
  │   [ (아이콘) 발산 고리  발산×5 ]  클릭 → ring_picked(gr_id)
  │   [ (아이콘) 응집 고리  응집×3 ]
  └ (진/룬 탭 = 무변경)
```

- **셀 아이콘 = 문양-고리 도안** — `assembly_slice_panel._ring_icon` 참조: `draw_arc`(밴드 원) + `RingBoard.glyph_guide_pts(motif,…)`를 count번 절차 렌더. **도형 플레이스홀더 아님**(절차 가이드선 = 규칙 §0 예외, 슬라이스 선례). `RingBoard.glyph_ring_pts`를 관측점으로 쓸 수도 있다(헤드리스가 점열을 본다).
- **격자 규약 재사용** — 소켓/목록 rect를 순수 static(`glyph_ring_cell_rects` 류)으로 뽑아 헤드리스가 잰다(세47 규율: `_draw_*` 안에 계산 두지 마라). 어휘 축이 늘면 폭 아니라 줄 수가 늘게.
- **jin/rune 셀 문구 조정** — `_draw_rune_cells`의 "왼쪽에 손으로 그리기"·jin `sel_desc`의 "✓ 그림"·`_jin_placed`/`_rune_placed` "✓" 표식은 **per-piece 그리기 전제**라 이제 거짓말이다(마지막에 통째로 긋는다). → "선택됨"/"고름"으로 바꾼다. `placed`(그렸나) 개념 은퇴, `chosen`(골랐나)으로.
- **TAB_DESC[2]** "문양 — 열린 칸을 이걸로 채운다" → "층 — 진의 층에 문양-고리를 끼운다"로.

---

## 진의 층(band) 수 — 결정·권고

- **고정 2**(동심원 2겹, `RingBoard.BAND_RADII = [0.42, 0.68]` 상수 그대로). `assembly_slice_panel.BANDS = 2`와 동일.
- `JinDef.glyph_slots`(8칸)와 **band는 다른 축이다** — 칸은 발산 탄 방향, band는 조립 층. 혼동 금지.
- 🔴 "진마다 층 수 다르게"는 `JinDef.band_count` 필드 신설(리드 core) + `BAND_RADII` 데이터화가 필요 = **지금 팔지 마라**(세47 「안 켠 배선」). 진 카탈로그가 늘 때 데이터화(그때 core 한 줄). 이번 설계는 상수 2.

---

## RingAssembly·저장 — 무엇을 안 쓰게 되나

**저장(RingDesign)은 무변경** — 플래튼된 8칸이 기존 `rings`에 담겨 `from_assembly`/`to_assembly`가 그대로 흐른다. assembly dict 형태 동형(진/룬/rings/open/score/ink/size).

**책이 통째 흐름에서 더 이상 안 쓰는 것**(삭제 판단은 리드 — 여기선 목록화만):
| 안 쓰게 되는 것 | 상태 |
|---|---|
| `RingBoard.advance`/`finish` (책 경로) | 유닛 테스트가 직접 검증 → **남긴다**(보드 API) |
| `RingBoard.choose_jin`/`choose_rune` (책 경로) | 상동 → 남긴다 |
| `RingBoard.stage_advanced`/`piece_locked`/`finished` 시그널 (책 구독) | 책에서 **연결 해제**. 시그널 자체는 보드에 남음 |
| `RingAssembly._open`/`_slots`/`place_glyph`/`set_open_slots`/`get_open` (책 경로) | 유닛 테스트가 직접 검증 → 남긴다 |
| `RingBoard._build_guide` per-target JIN/RUNE/GLYPH | 남긴다(보드 stage 경로가 씀) |
| `ring_forge_panel._on_next`/`_on_stage_advanced`/`_on_piece_locked`/`_stage_to_tab` | **책에서 제거** (흐름이 사라짐) |
| `ring_forge_panel._on_glyph_selected`/`_select_glyph`/`_active_glyph` | **제거** (문양 개별 선택 은퇴) |
| `RingBook.glyph_selected`/`_draw_glyph_cells`/`_glyph_rows`/`glyph_icon_pts`(개별) | **문양 탭 교체로 제거/대체** (아래 테스트 이관 주의) |
| `ring_forge_panel._draw_report`의 per-piece 행 루프 | 단일 줄로 축소 |

🔴 **삭제 vs 방치 = 리드 판단.** 최소 회귀 원칙상 이번엔 **보드/조립기 계약은 손대지 말고**(테스트가 지킴), **책 내부 죽은 코드만** 제거 권고. `ring_forge_panel`의 stage 핸들러·glyph 선택은 확실히 죽으므로 제거, 보드/RingAssembly의 stage machine은 유닛 테스트가 있으니 유지.

---

## 계약 영향 (단일 소스)

- `ring_power.gd`(점수→위력/등급/펑): **무변경**, 그대로 호출.
- `to_assembly()`/`RingDesign.from_assembly` 발사·저장 계약: **무변경** — 플래튼분이 기존 `rings`에.
- `trace_scorer.gd`(채점): **무변경** — 긴 단일 가이드만 넘긴다.
- `Enums.GlyphCode`(발사 계약): **무변경** — `GlyphRingDef.motif`가 참조만.
- 룬 타입 = `assembly.rune`(하드코딩 금지): `_sel_rune`을 dict에 싣는다(기본 fire라도).
- 펜 보정: 보드가 `_pen_correction`으로 GameState에서 읽음 → 통째 트레이스도 자동 상속.
- 잉크 배수 = `Db.ink_mult` 단일 소스 재사용. 크기 배수 = `RingPower.size_mult`.
- **건드리는 단일 소스 = 없음.** 전부 호출 재사용.

---

## 회귀 위험 & 완화

| 위험 | 완화 |
|---|---|
| 🔴 base·발사·저장·core 회귀 | **책 내부만** 바꾼다. base 무변경(같은 시그널)·보드/조립기 계약 무변경(유닛 테스트가 지킴)·core 무변경. 슬라이스가 F6에서 이미 검증한 통째 경로를 껍데기만 갈아 끼움. |
| 🔴 `_board.get_assembly()`로 발사 = 빈 rings·score 0 (세26) | 패널 `build_assembly()`가 flatten+combined_total+ink+size를 **직접** 조립. 테스트로 `asm.score`·`asm.rings==flatten` 못박음(슬라이스 test [5] 이관). 뮤테이션: score 키 빼면 빨감. |
| 🔴 `commit_rejected` 침묵 (세25 「맺었는데 안 나감」) | 책의 close-자동맺음·미달 거부 경로 **유지**. base가 이 무발신/발신에 기대 빈 슬롯 안 만듦. test_base 재작성이 이걸 통째 흐름으로 지킴(아래). |
| 🔴 문양 탭 소켓·고리 목록 클릭 도달 (세25 mouse_filter) | 씬 트리 무변경이라 위험 낮음(새 전체화면 Control 0). 단 **새 클릭 타깃(소켓·고리 셀)** = 실게임 push_input으로 도달 확인(헤드리스 못 잡음). |
| 🔴 층 간격 < 정밀도 tolerance → 획이 엉뚱한 층에 붙음 (세50) | `BAND_RADII 0.42·0.68` 간격이 tolerance(~0.05R)의 수 배 — 세70이 이미 실측. size 리치 안 채택 시 무변경. |
| 🔴 종이 리치안 채택 시 합성 가이드 오버플로우 | 권고=스칼라 안(기하 고정). 리치 채택하면 `_size_mult` clamp + 좌표 실측. |
| 통째 트레이스 "느낌"·"보인다"·긴 탁본 지겨움 | 헤드리스 불가 → 사용자 F5/MCP 스샷. 세70이 남긴 실측 목표. |
| glyph 개별 아이콘 관측점(test_ring_trace 6종 구분) 소멸 | 문양-고리 아이콘 관측점(`glyph_ring_pts`)으로 **이관**(아래). |

---

## 테스트 이관 (이 설계의 큰 부분)

**핵심 사실: 영향 테스트 대부분이 `ring_forge_panel`을 인스턴스화하지 않는다** — ring_board/ring_book/ring_assembly/trace_scorer/ring_design를 **유닛**으로 본다. 보드/조립기 stage machine을 **유지**하므로 대부분 그린으로 남는다.

| 테스트 | 무엇을 재나 | 통째 흐름에서 |
|---|---|---|
| `test_ring_trace_auto` | 보드 stage machine(advance·per-piece·칸 편집·펜 보정·정밀도) + **책 glyph_icon_pts 6종 구분**·jin_icon_marks·rune_cell_rects | 🟢 **대부분 그린**(보드 유닛 유지). ⚠ **책 `glyph_icon_pts` 6종 구분(310~330줄)만** — 문양 탭이 개별 셀을 버리면 이 관측점이 유령. → **문양-고리 아이콘 구분 검사로 이관**(`glyph_ring_pts`가 motif별로 다른가) 또는 `glyph_guide_pts`(모티프 어휘) 직접 검사로 격하. jin/rune 셀 검사는 그대로 그린. |
| `test_ring_book_jin_auto` | 책 진 셀 격자(`jin_cell_rects`)·아이콘(pattern×motion)·8점 다이어그램 | 🟢 **그린** — 진 탭 무변경. |
| `test_ring_design_auto` | RingDesign 라운드트립·등급⇔펑 경계·퍼펙트⇔100 | 🟢 **그린** — assembly 형태(8칸 rings) 유지. |
| `test_ring_assembly_auto` | 조립 상태기계·진이 칸 여는 규칙(glyph_slots→open) | 🟢 **그린** — ring_assembly.gd 무변경, 유닛 직접 검증. 책이 안 쓸 뿐. |
| `test_base_auto [_test_rejected_commit_is_not_silent]` | 🔴 **`forge._on_next`([다음]) 직접 몰고** → 부분 그림 → close → commit_rejected 1회 | 🔴 **필수 재작성** — `_on_next`가 은퇴. 새 버전: 통째 트레이스를 **안/조금** 그은 채(미달) close → `commit_rejected` 1회. 또는 조립만 하고 close. commit_rejected 계약 자체는 유지. (슬라이스 test [5]가 이미 "세71 계약 이관"으로 예고한 그 자리.) |
| `test_assembly_slice_auto` | F6 슬라이스: Db 로드·compose_guide·flatten·통째 채점·플래튼 발사·패널 build_assembly/try_inject/available_rings | 🔴 **재편** — 로직이 책으로 감. **[0]~[4]**(Db·compose·flatten·통째 채점·플래튼 발사)는 **RingBoard/Db 유닛**이라 **그대로 유지**(슬라이스 패널 무관). **[5]**(패널 build_assembly/available_rings/try_inject)는 **책 패널 대상으로 이관** → 새 `test_ring_forge_panel_auto`(또는 test_ring_trace에 절 추가). slice 패널 은퇴 시 [5]만 옮기고 나머지는 남긴다(또는 파일명만 `test_assembly_compose_auto`로 개명). |

**신규/이관 검증 항목(책 패널 대상):**
- `build_assembly()`가 `score`(=combined_total)를 싣는다 — 뮤테이션: score 키 제거 시 빨감(세26 그물).
- `build_assembly().rings[0] == flatten_bands(band_defs)` — 층 구성→8칸.
- `available_rings()` codex 필터 — 미해금 빠짐.
- `try_inject()` 미달 시 `committed` 무발신 + notice(침묵 거부 금지) — 뮤테이션: is_stable 가드 제거 시 빨감.
- 잉크/크기가 assembly에 실림.
- 🔴 헤드리스 못 잡음: 소켓/고리 클릭 도달·합성 가이드 렌더·통째 트레이스 손맛 → 실게임.

---

## slice 패널 거취 — 권고: 은퇴(단, 나중 슬라이스에서)

- `assembly_slice_panel.gd/.tscn` + `tests/test_assembly_slice.tscn`(F6) = 이 흐름의 **프로토타입**. 책이 같은 흐름을 품으면 **두 구현 병존 = 갈라짐 위험**(「복사는 갈라짐」).
- 🔴 **동시 삭제 금지** — 책 흐름을 **실게임에서 검증한 뒤** 은퇴. 그 전까진 F6 슬라이스가 대조군(같은 로직이 책과 F6에서 같게 도는지)이자 폴백.
- 은퇴 시: slice 헤드리스 test의 패널 절([5])을 책 패널 테스트로 이관 완료 후 `assembly_slice_panel.gd/.tscn`·`test_assembly_slice.tscn` 제거. RingBoard의 compose/flatten static·`test_assembly_slice_auto`의 [0]~[4]는 **남긴다**(보드 유닛).

---

## 구현 단계 (얇게 쪼갬 — dev/ui/리드)

병렬 가능하도록 문양 탭(UI)과 흐름 스왑(패널)을 분리한다.

1. **[dev/ui] RingBook 문양 탭 → 층 소켓 UI** (독립 가능)
   - `set_bands(bands, sel_band, available_rings)` 주입 · `band_selected`/`ring_picked` 시그널 · 소켓+고리 목록 렌더(`glyph_ring_pts` 아이콘) · 격자 rect 순수 static · `glyph_selected`/`_draw_glyph_cells` 제거 · TAB_DESC·jin/rune 셀 문구 조정.
   - 검증: 헤드리스로 소켓/목록 rect·아이콘 점열(관측점). 실게임=클릭 도달.
2. **[dev] RingForgePanel 흐름 스왑** (1과 병렬, 끝에 배선)
   - `_bands`/`_sel_band`/`_sel_jin`/`_sel_rune` 소유 · jin/rune/band/ring 시그널→`recompose()`(=`compose_guide`→`enter_combined_trace`) · stage 핸들러(`_on_next`/`_on_stage_advanced`/`_on_piece_locked`/`finished`) 연결 해제·제거 · `build_assembly()`(flatten+combined_total+ink+size+jin+rune) · [분석 ▶]=combined>0 활성 · `_draw_report` 단일 줄 · close 자동맺음/commit_rejected 유지 · NextBtn 숨김.
   - 🔴 `_board.get_assembly()` **금지**, build_assembly 직접.
3. **[리드] 테스트 이관·재작성**
   - `test_base_auto` reject 절 통째 흐름으로 재작성 · slice test [5]→책 패널 테스트로 이관 · test_ring_trace glyph_icon 관측점 이관 · 뮤테이션으로 검출력 재확인.
4. **[리드] `--import` → 전 스위트 → 실게임 MCP**
   - 조립(소켓·고리 클릭 push_input)·합성 가이드 렌더·통째 트레이스·발사 도달·펑/맺음·잉크/종이. 사용자 F5 손맛.
5. **[리드] (검증 후) slice 패널 은퇴** — `assembly_slice_panel.gd/.tscn`·`test_assembly_slice.tscn` 제거, 보드 유닛 테스트 잔류.

---

## 검증 포인트 (헤드리스 vs 실게임)

**헤드리스로 잡히는 것:**
- 책 패널 `build_assembly()`에 score·rings(=flatten)·rune·jin·ink·size 실림 (뮤테이션: score 키·is_stable 가드).
- `available_rings()` codex 필터.
- 문양 탭 소켓/고리 격자 rect·아이콘 점열(관측 static).
- 보드 stage machine·RingAssembly·RingDesign·ring_power 경계 = 무변경 그린(회귀 그물).
- compose_guide/flatten/combined_total = test_assembly_slice_auto [0]~[4] 잔류.

**실게임(F5/MCP)로만:**
- 🔴 문양 탭 소켓·고리 셀 좌클릭 도달(push_input — 세25, 새 클릭 타깃).
- 합성 가이드가 "따라 그을 만큼" 보이는지·층 겹침·룬 자리.
- 🔴 통째 트레이스 손맛(긴 탁본 재밌나/지겹나 — 세70 실측 목표) = 사용자 마우스.
- 잉크/종이 팔레트가 책 안에서 안 겹치는지·리포트 단일 줄 겉보기.
- 펑/맺음 섬광·책 펼침 anim 유지.

---

## 이번 슬라이스 밖 (선 긋기)

- **순서=수식**(층 안/밖이 결과를 바꿈) → 플래튼 유지. 쏴 보고 다겹 링 발사로 승격(스키마 이미 준비, 세70 Q5).
- **진마다 층 수 차등**(`JinDef.band_count`) → 상수 2. 진 카탈로그 늘 때 core 한 줄.
- **종이=규모 시각화**(가이드 확대) → 스칼라 안 권고, 손맛 후속.
- **문양-고리 파밍/필드 드롭 아트** → 시드 소유(맨몸 파이어볼 baseline). 획득 확장은 도파민 루프(세66) 소관.
- **복합 룬·재귀 진** → `scratch_nested_design.md`.
