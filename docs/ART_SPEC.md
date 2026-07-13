# ART_SPEC — 이미지 에셋 명세 (Aseprite MCP 작업용)

> 2026-07-12 작성 · **2026-07-13 세션 3~5에 걸쳐 P1~P5 전부 완료** (아래 각 절 상태 표기).
> GDD §10.5 규칙 기반. 잔여는 소소한 보류 항목뿐 (P4 tutorial.gd 단색·P5 피격 플래시 등).
> 원본 생성 스크립트(Lua)는 세션 scratchpad — 구조는 memory aseprite-mcp-plan.md 참조. 코드 배선은 전부
> `ResourceLoader.exists()` 가드 + 플레이스홀더 폴백 방식이라 PNG를 지우면 옛 모습으로 돌아간다.

## 불변 규칙 (먼저 확정, 이후 모든 에셋이 따름)

- 뷰포트 640×360 (정수 스케일) · **타일 16×16 · 캐릭터/적 32×32 · 보스 64×64 · UI 아이콘 16×16**
- **팔레트 확정: Apollo 46색** (2026-07-13, 사용자 결정. lospec.com/palette-list/apollo) — 원본 `assets/aseprite/apollo.gpl`(Aseprite에서 로드 가능) · 스와치 `assets/aseprite/palette_apollo.aseprite`. 모든 에셋(구매 에셋 포함)을 이 46색으로 리컬러 (`quantize_to_palette` 활용)
- **낮/밤 톤은 CanvasModulate가 처리** — 스프라이트는 중립(낮) 톤으로만 제작, 밤 버전 별도 제작 금지
- **마법진·잉크 선은 스프라이트가 아님** — Line2D 프로시저럴 렌더 유지 (픽셀 세계 + 매끄러운 먹선 대비가 아이덴티티)
- 파일 규칙: 원본 `assets/aseprite/<이름>.aseprite` (git 포함) → 익스포트 `assets/sprites/<분류>/<이름>.png` (스프라이트시트는 가로 스트립). 임포트 필터는 프로젝트 기본(Nearest)이라 별도 설정 불요

## P1 — 게임의 첫인상 (정체성 자산, 직접 제작 대상) ✅ 완료

player.aseprite 32프레임(idle·걷기 4방향, 대시 4방향, 탁본 4f) → sprites/player/player.png · 룬 글리프·붓 커서 → sprites/ui/

| 에셋 | 크기 | 프레임 | 비고 |
|---|---|---|---|
| 주인공 idle | 32×32 | 4방향 × 2 | 견습 필경사 — 로브+붓/완드 |
| 주인공 걷기 | 32×32 | 4방향 × 4 | |
| 주인공 대시 | 32×32 | 1~2 | 잔상은 셰이더/모듈레이트로 |
| 주인공 탁본 모션 | 32×32 | 3~4 | 쪼그려 종이 대는 동작 — 1.5초 무방비의 시각 언어 |
| 룬 글리프 4종 | 16×16 | 각 1 | 불△·충격>·물~·바람◎ — UI·도감·게시판 공용 |
| 붓 커서 | 16×16 | 1~2 | 드로잉룸 커서 |

## P2 — 적 (전투 가독성) ✅ 완료 — sprites/enemies/ (enemy_base가 def.id로 자동 배선, 처치 팝 포함)

| 에셋 | 크기 | 프레임 | 비고 |
|---|---|---|---|
| 재생 덩굴 | 32×32 | idle 2·공격 2·재생 표시 | 고정형 |
| 숲 사냥개 | 32×32 | idle 2·이동 4·돌진 2 | 예열 자세 구분 필수 |
| 수액 슬라임 / 미니 | 32×32 / 16×16 | idle 2·이동 2 | 미니는 축소 리드로잉 |
| 슬라임 우두머리(엘리트) | 32×32 | 동일 + 왕관/무늬 | 무늬(글자)가 몸에 보이게 |
| 안개 정령 | 32×32 | 응집 2·산개 2 | 산개는 반투명 활용 |
| 갑주 갑충 | 32×32 | idle 2·이동 2 | 젖음 시 색 변화는 모듈레이트 |
| 바람을 품은 존재(보스) | 64×64 | idle 2·돌풍 2·볼리 2·2페이즈 변색 | 몸에 ◎ 무늬 |
| 처치 팝 이펙트 | 32×32 | 4~6 | 간결한 폭발 (GDD 톤: 무겁지 않게) |

## P3 — 환경 ✅ 완료

- ✅ **정식 숲 타일셋 16×16 (2026-07-13 세션 5)**: sprites/field/tileset_field.png — 128×48 아틀라스 8열×3행
  18타일 (풀 4변형·보스존 바닥 2+◎ 문양·게이트 문지방·수풀 벽 3·냉색 돌벽 2·바위 예비·**나무 2타일 높이 2종**
  = 캐노피+둥치 분리). 원본 assets/aseprite/tileset_field.aseprite. **좌표·물리 계약은 field.gd 상수(T_*)가 유일한 진실**.
  field.gd가 TileMapLayer 4장(Ground z-10 / Walls z-9 물리 / Trunks z0 둥치 충돌 / Canopy z1)을 런타임 TileSet으로
  구성, seed 고정 배치·나무 35그루 클리어런스 배치. 세로 벽에 bush_top 금지(밑단 음영이 사다리 무늬 유발 — 재발 주의)
- (구) 경량판 타일러블 텍스처 4종(tile_*.png)은 PNG 삭제 시 폴백 경로에서 계속 사용
- ✅ 채집 노드: 주간 2종·야간 발광 2종 (sprites/field/gather.png, 각 2프레임)
- ✅ 출구 게이트(32×48 나무 문+빛기둥+부적), 탁본 잔류물(금빛 소용돌이 발광 2프레임)
- ✅ 거점 인테리어: 작업대·창고 궤·연구 책상·침대·창호문·이젤 (sprites/base/props.png 32×48×6, base.gd 배선)

## P4 — UI (한지·먹 질감) ✅ 완료

- ✅ 패널 9-slice 3티어 (2026-07-13 사용자 확정): 대형 48×48 마진12(sprites/ui/panel_paper.png)·
  소형 24×24 마진6(panel_paper_s.png — 행·버튼·슬롯 카드)·바 프레임 12×12 마진3(frame_bar.png).
  배선은 InkStyle.make_panel() 단일 지점 — pad_v로 티어 자동 선택, bg색은 modulate(bg/PAPER)로 살림,
  PNG 없으면 기존 StyleBoxFlat 폴백. 텍스처 반복은 StyleBoxTexture AXIS_STRETCH TILE
  (반점 해시는 sin 기반 — 선형 해시는 대각 줄무늬 아티팩트 발생, 재발 주의)
- ✅ 아이템 아이콘 18종 (sprites/ui/items.png — id→인덱스 계약은 src/core/item_icons.gd, 창고 패널 배선)
- 잔여: tutorial.gd는 자체 복제 스타일이라 아직 단색 (ink_style 공용 승격 시 함께 치환)

## P5 — 이펙트 ✅ 완료 (보류 항목 제외)

- ✅ 투사체 4종 (sprites/effects/projectiles.png — 우향 혜성형 2프레임, projectile.gd 공유 SpriteFrames)
- 피격 플래시(셰이더로 대체 가능 — 보류), 돌풍 텔레그래프 링(코드 렌더 유지 — 보류)

## 교체 순서 메모

스프라이트 교체는 노드 구조 변경 없이 가능하게 — 현재 플레이스홀더는 전부 `Visual`이라는 자식 노드(ColorRect/Polygon2D)이므로, 같은 이름의 Sprite2D/AnimatedSprite2D로 바꿔치기하는 방식으로 진행. 적들은 enemy_base가 시각 노드를 만들므로 그 지점 1곳 수정으로 전체 적용 가능.
