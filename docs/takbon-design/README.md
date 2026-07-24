# 탁본 기획 문서 (takbon-design)

`takbon-design` 스킬로 리드가 사용자와 대화하며 확정한 **기획·설계 문서의 영구 보관소**다.
새 설계는 여기 `<주제>_design.md`로 착지한다. (구현 보고·architect 리뷰는 일회성이라 리포 루트 `scratch_*.md`에 쓰고 반영 뒤 지운다 — 여기 두지 않는다.)

## 문서 (세78 교차 감사로 전량 재인덱싱)

**마법 모델 (읽는 순서)**
| 문서 | 내용 | 상태 |
|------|------|------|
| `takbon_model.md` | 세68 조립→탁본 마법 모델 (조립 vs 그리기 화해) | 🟢 정본 (문양 손대기 전 읽어라) |
| `jin_interpretation_design.md` | 세78 진별 해석 구조 (룬 감쌈=순서 · 진 규칙 합침 · 확산·폭발=M1) | 🔵 **기준점** (개념 확정·미구현. 마법 조립 내부구조의 현행 정본) |
| `nested_design.md` | 중첩 마법진 (복합 룬 × 재귀 진 × rune_fill) | ⚠🟡 **프레임 은퇴** — jin_interpretation이 대체. 살아있는 것=코드 인벤토리·rune_fill 진단(참고 자산) |

**조립·탁본 UI 체인 (내부 정합 양호 — 순차 전제)**
| 문서 | 내용 | 상태 |
|------|------|------|
| `book_redesign_design.md` | 세70/71 고리 조립 책 재설계 (라이브 흐름) | ✅ 구현 (아카이브) |
| `progressive_assemble_gate_design.md` | 조립 Phase 게이트 (ASSEMBLE→DRAW→RESULT) | ✅ 구현 (아카이브) |
| `guide_visual_layers_design.md` | 밑그림 시각 층 (band_count·subpath) | ✅ 구현 (아카이브) |
| `draw_tools_panel_design.md` | 그리기 도구 패널 (DrawTools·종이 축 은퇴) | ✅ 구현 (아카이브 — ⚠종이 완전 purge는 후속) |
| `assemble_trace_slice_design.md` | 세68/70 조립→탁본 최소 슬라이스 | ✅ 구현. ⚠라이브=책, 슬라이스 패널은 F6 대조군(은퇴 대기) |

**진행·경제·스테이지**
| 문서 | 내용 | 상태 |
|------|------|------|
| `dopamine_design.md` | 세66 도파민 보상 루프 + 경제 재편 | ⚠ **부분 구현** (coin·shop O · **D 전량(해독 은퇴·qR 룬퀘·예식) 미구현**) |
| `first_stage_design.md` | 세70 첫 스테이지 수직 슬라이스 | ⚠ **부분** (ChapterDef 해금·시드 제거만 O · **base 편입은 book_redesign이 반려**) |
| `guide_editor_design.md` | 밑그림 직접 제작 도구 (커스텀 가이드) | 🟡 보류 (git stash · ⚠되살리면 세70/71 조립흐름과 재정합 필요 — 단순 복원 불가) |

**아트·필 (독립 — 충돌 없음)**
| 문서 | 내용 | 상태 |
|------|------|------|
| `movement_feel_design.md` | 세74 이동 필 (가속·관성) | ✅ 구현 (아카이브) |
| `player_hooded_redesign.md` | 세75/76 후드 챠비 플레이어 | ✅ 구현 (아카이브) |
| `oblique_impact_design.md` | 세77 오블리크 파이어볼 착탄 | ✅ 구현 (아카이브) |

🔵 기준점 = 현행 마법 모델 정본(개념 확정, 구현은 진행) · 🟢 정본 = 지금도 방향을 규정 ·
🟡 = 대기/보류 · ⚠ = 부분 구현/은퇴 예고(헤더 스텁 참조) · ✅ = 구현돼 코드에 반영된 아카이브.

> 🔴 세78 교차 감사(`takbon-architect`) 결과 이 인덱스를 전량 재작성했다. 상세 = 그 세션 대화·memory `takbon-jin-interpretation-model`. 낡음이 잡힌 5개(nested·dopamine·first_stage·guide_editor·assemble_trace_slice)는 각 헤더에 스텁을 달았다.
