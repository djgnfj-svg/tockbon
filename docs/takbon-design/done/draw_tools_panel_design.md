---
node: draw_tools_panel
stage: done
owns: [drawing_tools]
needs: []
---

# 설계: DRAW 도구 패널(잉크+실시간 점수) + 종이 축 은퇴

> 산출물 = takbon-dev가 받는 구조 설계. 범위 = 책 포지 패널 UI + 종이(규모) 축 제거.
> **발사·저장·core 무변경 목표.** 전제(Phase 게이트·밴드 서브패스)는 구현 완료 —
> 전제 문서 `progressive_assemble_gate`·`guide_visual_layers`는 **세87에 삭제했다**(구현 완료 아카이브).

> ⚠🔴 **세87 실측 — 이 문서는 구현 완료 아카이브이고, 「후속」이라 적은 종이 purge는 절반 집행됐다.**
> ⓐ **정제대 dead affordance는 이미 닫혔다** — `src/base/refine_panel.gd:86`이 종이 결과 레시피를
> 목록에서 필터로 숨긴다(아래 §리뷰 4의 지시가 집행된 것). `.tres`는 삭제하지 않은 **휴면**이다.
> ⓑ 🔴 **남은 종이 잔재를 「청소」로 걷지 마라 — 테스트가 직접 부른다**:
> `tests/test_ring_design_auto.gd:136-139`가 `Db.paper_zoom_max`(`src/core/db.gd:173`)와
> `data/items/paper_basic.tres`·`paper_high.tres`를 쓴다. 아이템 2장을 지우면 :136의 대소 비교가
> 폴백 동률이 돼 **즉시 빨감**한다.
> ⓒ `RingDesign.size`·`build_assembly["size"]`는 `ring_spell_system`이 소비하므로 그대로 둔다(§리뷰 2).
> ⓓ 남은 종이 표시 잔재 = `src/hud/tab_panel.gd:114` `[&"paper", "종이"]` 카테고리 · :117 `paper_mat`.

## 목적 / 왜
사용자: ① [그리기 시작] 누르면 **옆에 잉크가 뜨는 UI** ② **실시간 점수** ③ **종이 개념 은퇴 → 관련 UI 제거**.

현재 상태(코드 확인):
- 잉크 스와치·종이 버튼이 **상단 띠에 늘** 표시(`INK_SWATCH_*`·`PAPER_BTN_*`). 조립 중에도 떠 있다.
- 점수(`ScoreLabel`)는 **오른쪽 책 하단에 작게**. 실시간 갱신은 **이미 배선됨**(`board.score_changed`→`_on_combined_score`→`_update_score`) — 위치가 멀고 작을 뿐.
- 종이 = `_size_mult`(종이 등급→규모→데미지), `build_assembly["size"]`에 실림. `_paper_ids/_active_paper/_build_paper_palette/_select_paper/_highlight_paper`.

## 확정 결정 (AskUserQuestion)
- **종이 축 통째 은퇴** — 종이 선택 UI + 규모·데미지 기믹 제거. 진 규모 = 기본값 고정.

## 설계

### A. DRAW 도구 패널 (잉크 + 실시간 점수, 보드 옆)
- [그리기 시작]으로 DRAW 진입 시, **오른쪽 페이지(잠긴 책 자리)에 「그리기 도구」**를 띄운다:
  - **잉크 스와치**(획 색 선택) — 상단 고정에서 이리로 이동.
  - **실시간 점수**(완성도 · 정밀도 · 종합, **크게**) — 그으면서 바로 오른다.
- **ASSEMBLE**: 잉크 숨김(조립만 — 아직 안 그림). **RESULT**: 리포트(현행).
- 잉크는 조립 단계엔 필요 없다(획 색이라) → DRAW에서만 등장 = 사용자 요청("그리기 시작하면 옆에 잉크").

### B. 실시간 점수
- **이미 `score_changed` 배선 존재** — 신규 배선 0. DRAW 도구 패널에 **큰 폰트**로 표시(지금 font 9 → 키움). ScoreLabel을 도구 패널 자리로 옮기거나 도구 패널이 자체 렌더.
- ASSEMBLE엔 점수 숨김(현행 `_update_score` 가드 유지).

### C. 종이 축 은퇴 (포지 한정)
- `_build_paper_palette`·`_select_paper`·`_highlight_paper`·`_collect_papers`·`_paper_ids/_active_paper/_paper_btns/_paper_nodes`·`PAPER_*` 상수 제거. `open()`·`_rebuild_palettes`의 종이 호출 제거.
- **`_size_mult = 1.0` 고정** → `build_assembly["size"] = 1.0`. 🔴 **baseline 무변경**: 옛 기본 종이(등급1)도 size 1.0이었다("기준 100 = 기본 종이" 계약, `power_display`) → 발사·위력 baseline 그대로.
- ⚠ **범위**: Db의 `PAPER` 아이템·workshop 종이 레시피·드롭은 **이번 범위 밖(휴면)**. 포지에서 종이를 안 쓰면 겉으로 사라진다. 완전 purge(아이템/레시피 삭제)는 후속 정리 — 지금 지우면 workshop·저장 회귀 위험이라 미룬다.

## 회귀 안전
- **발사·저장**: `build_assembly["size"]=1.0` 고정 = 옛 기본 종이와 동일 → baseline·라운드트립 무변경. `ink`·`special_ink`·`rune`·`jin`·`rings`·`score` 무변경.
- 실시간 점수 = 기존 `score_changed` 배선 재사용(신규 0).
- 잉크는 DRAW로 이동만 — `_select_ink`/`set_trace_ink`/`set_ink` 계약 무변경.
- `_paper_*` 제거 시 **dangling 참조 전부 청산**(open 310·_rebuild_palettes·build_assembly size·_draw 하이라이트) — 남기면 SCRIPT ERROR.

## 검증
- 헤드리스: `build_assembly()["size"] == 1.0`(종이 제거 후) · 잉크 여전히 `build_assembly`에 실림 · 종이 참조 제거 후 **SCRIPT ERROR 0**(grep) · 전 스위트(특히 test_ring_design·test_base — build_assembly 계약).
- 🔴 실게임: [그리기 시작] 시 잉크가 보드 옆에 뜸 · 그으면 점수 실시간 상승 · 상단 종이 UI 사라짐 · ASSEMBLE엔 잉크 숨김(세25 — push_input/F5).

## 🔴 architect 리뷰 반영 (조건부 승인 — 4 실행 디테일)
1. **(c) 잉크 초기화는 open()에 유지 — 표시만 DRAW 게이팅.** `_build_ink_palette`가 「수집 + 기본잉크 선택(보드에 색 걺) + 스와치 생성」을 한 함수에서 한다. 통짜로 DRAW에 미루면 기본 잉크 초기화가 깨진다 → **수집·기본선택·`set_trace_ink`/`set_ink`는 open()에 그대로, 스와치 UI의 가시성만 DRAW로 게이팅**한다.
2. **(b) size 스키마·계약 보존.** `RingDesign.size` 필드·`build_assembly["size"]` 키는 **남긴다**(값만 1.0 고정). 🔴 `ring_spell_system:186`이 size를 소비하고 **`test_ring_design`·`test_ring_spell`(size 2.0)·`test_save`(size 1.4)가 size 기믹을 core로 잰다** — core/스키마를 purge하면 즉시 빨감. 포지가 size=1.0만 보내면 될 뿐, 기계는 살려 둔다(휴면 스코핑 필수).
3. **(a) 죽은 코드 청소.** 종이 제거로 `_draw_report`의 "큰 진 ×뎀" 가지(≈L1036–37)가 영구 죽는다 → 지운다. (설계의 "_draw 하이라이트" = 실제로 `_highlight_paper` 메서드 — 그것 제거.)
4. **(④) `refine_panel` 종이 레시피 숨김.** 정제대가 `craft_paper_mid/high`를 계속 노출하면 효과 없는 종이를 mat_vine 써서 제작하는 **dead affordance(소프트 함정)**가 된다 → 종이 은퇴에 맞춰 정제대 목록에서 종이 레시피를 **숨긴다**(레시피 .tres·아이템은 삭제 말고 목록 필터 = 휴면 스코핑). `src/base/refine_panel.gd:86`.

## 손맛
- DRAW 도구 패널 레이아웃(잉크 위치·점수 폰트 크기·배경)·실시간 점수 강조색은 F5 튜닝.
