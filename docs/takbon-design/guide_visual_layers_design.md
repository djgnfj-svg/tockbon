# 설계: 밑그림 조각 분리 렌더 + 층 시각화 + JinDef.band_count

> 산출물 = takbon-dev/리드가 받는 **구조 설계**. 게임 디자인 = 확정(AskUserQuestion — 재논의 없음).
> 범위 = 책 밑그림 렌더 + 진 층 수. **채점·발사·저장 계약 무변경 목표.** core 신설 = `JinDef.band_count` 하나(리드가 반영).
> 전제 = `progressive_assemble_gate_design.md`(점진 조립+게이트) 구현·검증 완료.

---

## 목적 / 왜

사용자 관찰 3가지:
1. *"룬이랑 진이랑 연결된 선이 생기는데 알려줄래?"* — 룬과 진 윤곽 사이에 **이음선**이 보인다.
2. *"진에 룬이 박히는 위치랑 층들이 시각적으로 보였으면 좋겠음"* — 룬 자리·층 구조가 안 보인다.
3. *"처음에 주는 일반진은 1층짜리임"* — 진마다 층 수가 다르고, 시작 진은 1층.

**원인**:
- 이음선 = `compose_guide`(ring_board.gd:492)가 **진 윤곽+룬+밴드를 한 `PackedVector2Array`로 이어붙인다**.
  보드가 이걸 **연속 폴리라인**으로 그리니 조각 사이(진 마지막 점 → 룬 첫 점 등)에 선이 그어진다. 즉
  **렌더 아티팩트 = 서로 다른 도형을 한 선으로 꿴 자국**(채점엔 무관 — 채점은 점 근접도라 연결선을 안 봄).
- 층 구조가 안 보임 = 빈 층·룬 자리를 안 그린다(채운 것만 보임).
- 층 수 = 코드 상수 `BAND_RADII = [0.42, 0.68]`(2겹 고정). 진이 못 정한다. 패널 주석(103~104)이 이미
  *"진마다 차등은 `JinDef.band_count` 신설이 필요해 지금 팔지 않는다"*고 예고해 둔 자리.

핵심 재미 잣대(`takbon-core-fun-drawing`) = "그리는 재미를 키우나?" → **무엇을 그리는지(룬 자리·층 구조)가
또렷이 보여 손이 갈 곳을 알게** 하므로 그리는 행위를 명료하게 만든다. ✅

---

## 확정된 결정 (AskUserQuestion)

| 결정점 | 확정 |
|---|---|
| 룬 자리·층 시각화 | **조각 분리 + 빈 층 가이드** — 진·룬·각 층을 끊긴 별도 선으로(이음선 제거) + 빈 층/룬 자리를 흐린 가이드로 늘 표시 |
| 층 구조 | **룬=중앙(층 아님), 층=문양-고리를 끼우는 동심원 고리** |
| 층 수 | **일반진=1층. `JinDef.band_count` 신설(기본 1).** 나중 진은 2·3층으로 확장 |

---

## 설계

### A. 조각 분리 렌더 (이음선 제거)
- 🔴🔴 **`compose_guide` 시그니처 절대 불변**(직전 리뷰 계약 — static 단일 소스이자 헤드리스 관측점, 호출자 셋).
- 신설 **`compose_guide_paths(jin_shape, rune_type, band_defs, ctr, ro) -> Array[PackedVector2Array]`**
  = `[진 윤곽, (룬), 밴드0, 밴드1…]` — **각 조각을 별도 서브패스로** 돌려준다(룬 센티넬 -1이면 룬 조각 생략).
  - 🔴 **null 밴드 = 빈 서브패스로 자리만 남긴다**(리뷰③) — flatten엔 무영향이면서 §B의 "빈 층 자리" 렌더에 쓴다.
- **`compose_guide`(flat)는 `compose_guide_paths`를 flatten한 단일 소스에서 파생**(리뷰③ — 패널이 flat·subpaths를 따로 만들면 갈라진다). 점열·순서가 지금과 **점 단위로 동일**해야 한다(채점·리빌-점 정렬 불변).
  - 🔴🔴 **재구현 시 갈라지는 세 자리(리뷰③, verbatim 유지)**: ⓐ 룬 가드 `if seg >= 0: out.append(v[seg])` + 변마다 12등분 루프 그대로 · ⓑ 밴드 frac은 **band_defs 원본 인덱스 i**로 `BAND_RADII[i]` 인덱싱(null 건너뛴 압축 카운터 금지 — band0=null이면 band1 반경이 밀린다) · ⓒ scorer flat = flatten(subpaths) 한 소스에서.
- 🔴🔴 **보드가 서브패스를 받는 창구 = `enter_combined_trace` 확장(리뷰①)**: 이음선의 실제 원인은 `ring_board.gd:1303`이 **scorer flat 가이드 전체를 한 폴리라인**으로 그리는 것. 유일 창구 `enter_combined_trace(guide_pts)`는 flat 하나만 받는다. **선택 인자로 확장** — `enter_combined_trace(flat, subpaths := [], band_count := 0)`:
  - flat은 지금처럼 scorer에 넣음(채점 무변경).
  - **subpaths 비었으면 옛 동작**(flat 한 폴리라인) → 슬라이스 패널·test의 1인자 호출 **무변경**(회귀 그물).
  - forge만 subpaths·band_count를 채워 넘긴다. 보드가 서브패스를 별도 멤버로 보관해 `_draw`가 1303 대신 **서브패스별 `draw_polyline`**. 리빌 점·먹선 렌더는 그대로.
  - 🔴 **band_count를 인자로 받는 이유(잠복 버그, 리뷰①)**: COMBINED 흐름은 `choose_jin`을 안 불러 보드 `_jin_def`가 open 때 jin0에 **고정**된다 → 진이 2종+ 되면 보드가 선택 진 band_count를 모른다(지금 1종이라 우연히 맞음). band_count를 넘겨 보드가 동심원 개수를 알게 한다(0이면 안 그림 = 옛 동작).

### B. 빈 층/룬 자리 가이드
- 보드가 진의 `band_count`만큼 **흐린 동심원 고리**(`BAND_RADII[i]`)를 **빈 층도 늘 그린다** → "여기가 1층" 구조가 보임.
- **룬 미선택 시 중앙에 흐린 룬 자리 마커**(작은 원/링). 룬 고르면 실제 룬 밑그림으로 대체.
- 채운 층(문양-고리 끼움)은 실제 밑그림, 빈 층은 흐린 가이드 → 채운 것과 빈 것이 시각적으로 구분.
- 색·굵기 = 흐린 가이드 톤(const, 손맛 튜닝). 절차 렌더라 도형 금지 예외.
- 🔴 **COMBINED 게이트(리뷰⑥)**: 동심원 밴드·룬 자리 마커는 `_trace == TraceTarget.COMBINED`에서만 그린다. per-piece JIN/RUNE/GLYPH 흐름(`_draw` has_rune 분기)에 얹으면 "기존 경로 무변경" 약속이 흔들린다.

### C. JinDef.band_count (core 스키마 — 리드가 반영)
- `@export var band_count: int = 1` 신설. `jin_single.tres` = 1(기본값이라 옛 .tres 무변경으로도 1 — glyph_slots 선례).
- **패널 `_bands` 크기 파생 시점(🔴 리뷰④)**: `_reset_selection`은 `_sel_jin=&""`에서 불려 band_count를 모른다 → **리셋 시 `_bands = []`**(진 없음=소켓 없음). 리사이즈는 **`_on_jin_selected`에서** 선택 진 band_count로 + `_sync_book_bands` 재주입 + `_sel_band = clampi(_sel_band, 0, maxi(band_count-1, 0))`.
  - 🔴 상수 `BANDS`(=2) 참조 전부를 **`_bands.size()`**로 교체 + **size 0 가드**(`_on_band_selected`의 clampi가 max<min 안 되게).
  - [다시 조립](`_on_redraw_assemble`)은 `_reset_selection`을 **안 부르고** 선택 유지 → `_bands` 크기 불변 = 안전.
- **책 층 탭**: 소켓 수 = `band_count`(지금 2 소켓 → 진 파생). 패널이 주입(`set_bands`와 동형, module-local — 시그니처 불변, 배열 길이만 달라짐).
- `BAND_RADII` = 최대 목록으로 두고 진은 앞 `band_count`개 사용. `band_count=1` → 안쪽 고리 1겹.
- 🔴 **`flatten_bands`·발사 무변경**: 밴드 수가 줄어도 8칸 라운드로빈·빈 칸 `GLYPH_NONE` 계약 그대로. 발사부 무영향.
- ⚠ **`assembly_slice_panel.gd`의 `const BANDS := 2`는 그대로 둔다(리뷰⑤)** — 출시 흐름이 아닌 dev 하네스라 회귀 아님. jin_single이 1층 되면 슬라이스 하네스만 2겹 겉보기로 갈리지만 크래시 없음(compose_guide가 임의 길이 band_defs를 클램프 처리). 다음 세션 혼동 방지로 여기 명시.

---

## 파일별 변경 (구조)

| 파일 | 변경 |
|---|---|
| `src/core/schemas/jin_def.gd` | `band_count: int = 1` 신설(🔴 core — 리드가 반영). |
| `data/jin/jin_single.tres` | `band_count = 1`(기본값이라 명시만, 안 적어도 1). |
| `src/drawing/ring_board.gd` | `compose_guide_paths()` 신설(서브패스 배열, null=빈 서브패스). `compose_guide`는 그 flatten(시그니처·점열 불변). **`enter_combined_trace(flat, subpaths:=[], band_count:=0)` 선택 인자 확장**(1인자 옛 동작 보존). 서브패스를 멤버로 보관해 `_draw`(1303) = 서브패스별 별도 폴리라인(이음선 제거). band_count만큼 흐린 동심원 + 룬 자리 마커 렌더(COMBINED 게이트). `BAND_RADII` 앞 N개. |
| `src/drawing/ring_forge_panel.gd` | `_bands` 크기 = 선택 진 `band_count`(상수 2 → 진 파생). 책 층 탭 소켓 수 주입. |
| `src/drawing/ring_book.gd` | 층 탭 소켓 수 = 주입받은 band_count(지금 2 고정 → 파생). |

🔴 **채점·발사·저장·core 계약**: `trace_scorer`(flat 점열)·`flatten_bands`·`to_assembly()`·`RingDesign`·
`Enums.GlyphCode`·`design_committed` 전부 무변경. core 신설 = `JinDef.band_count` 하나뿐(EventBus·시그널 0).

---

## 회귀 안전

- `compose_guide` 시그니처·**반환 점열 불변** → 채점·슬라이스 패널·`test_assembly_slice_auto` 무변경.
- 이음선 제거·빈 층 가이드 = **순수 렌더 개편** → 채점·발사·저장 무영향.
- `JinDef.band_count` 신설 = 옛 .tres 기본값 1로 조용히 안 깨짐(glyph_slots가 같은 선례 — 세60).
- 밴드 수 2→1 = 발사부 `flatten_bands`가 빈 칸을 `GLYPH_NONE`으로 채워 계약 유지(리셋으로 콘텐츠 1종뿐이라 실사용 영향도 최소).

---

## 검증 (그물 + 실게임)

- 헤드리스:
  - 🔴🔴 **골든 점열 테스트(리뷰② — "flat==flatten(paths)"는 재구현이면 자기동어라 못 씀!)**: **리팩터 전에** 현행 `compose_guide` 출력을 대표 입력 3종(진+룬+2밴드 / 진+룬미선택(-1) / 진+빈밴드 하나)에 대해 **골든 점열로 캡처**해 하드코딩하고, 새 출력이 그 골든과 **점 단위로 정확히 동일**함을 `test_assembly_slice_auto`에 추가. 이것만이 세50 "데이터 조용히 갈라짐"을 실제로 잡는다. (리드가 리팩터 전 캡처.)
  - **서브패스 수**: 진 1 + 룬 유무(센티넬 -1 = 0, 실룬 = 1) + `band_count` 밴드(빈 밴드 = 빈 서브패스 자리 포함).
  - **band_count 파생**: `JinDef.band_count` 기본 1 로드. 진 선택 시 `_bands` 크기 == `band_count`, **진 미선택 시 0**(리뷰④). `flatten_bands`(1밴드) 계약.
  - 🔴 **1인자 호출 회귀 그물(리뷰①)**: `assembly_slice_panel`·`test_assembly_slice_auto`의 `enter_combined_trace(flat)` 1인자 호출이 **여전히 컴파일·통과**(선택 인자 default가 옛 동작 보존).
  - 발사 계약 무변경: `build_assembly`가 score/rings/rune/jin 싣음(세26 to_assembly 그물).
- 🔴 **실게임 MCP 필수**(세25·세50): **이음선 사라짐**(draw 결과라 **뮤테이션+스샷**으로만 확인)·빈 층 동심원·룬 자리 마커·층 탭 소켓 수·1층 겉보기는 헤드리스가 못 잡는다. F5·스샷으로 확인.

---

## 손맛·미결 (사용자 튜닝)

- 흐린 가이드 색·룬 자리 마커 모양·1층 고리 반경(`BAND_RADII[0]`)·서브패스 획 굵기는 F5로 조인다.
- 진마다 층 수(2·3층 진)는 후속 진 큐레이션에서 `band_count`로 붙인다 — 이번 범위는 일반진 1층까지.

> **architect 리뷰 반영**: `scratch_guide_visual_review.md` 조건부 승인의 6개 지적을 반영 완료 — ①enter_combined_trace 서브패스·band_count 선택 인자 확장(1인자 옛 동작 보존) ②골든 점열 테스트(자기동어 회피, 리팩터 전 캡처) ③재구현 세 함정(룬 가드·원본 인덱스 frac·flat=flatten 단일소스) ④`_bands` 크기 파생 시점(리셋=[], 진 선택 때 리사이즈, BANDS→`_bands.size()`) ⑤슬라이스 BANDS=2 그대로 명시 ⑥새 렌더 COMBINED 게이트. core 신설 = `JinDef.band_count` 하나, 방향 재확인 불필요.
