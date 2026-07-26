extends Control
## 고리 조립 제작대 — **책을 좌우로 펼친다.** forge_panel(자유 드로잉)의 껍데기를 그대로
## 잇되(사용자 요청 "이전 왼쪽 UI를 그대로 쓰고 적용되는 형식으로"), 속을 조립 모델로 바꾼다.
##
## 왼쪽 페이지 = **조립 보드**(RingBoard) · 오른쪽 페이지 = **조각 선택기**(RingBook — 진·룬·문양 탭).
##
## 🔴 흐름 = **3단계 게이트**(`Phase`, 세71b): ASSEMBLE(오른쪽에서 진·룬·문양-고리를 조립) →
## DRAW(왼쪽 판의 **숨은 선을 손으로 통째로 문질러** 드러낸다 — 세68 조립→탁본) → RESULT(분석
## 리포트에서 [마력 주입]으로 맺거나 [◀ 다시 조립]).
## ⚠ **세83 그리기 폐지 모드**(`balance.skip_drawing` 기본 true)에선 DRAW가 **도달 불가**다 —
## `_on_start_draw`가 바로 `_finish()`로 간다. 그래서 그 모드의 시작 버튼은 [마법진 완성 ✦]이다.
## ⚠ 조각을 하나씩 잠그던 **per-piece 흐름([다음]으로 진→룬→문양 칸마다)은 세70에 죽었다** —
## 지금 [다음] 버튼(`NextBtn`)은 「그리기 시작」 게이트로 갈아 끼운 것이다.
##
## 계약: open() → 열림 / closed 시그널 → 닫힘 / design_committed(assembly) → 맺힘.
##
## 🔴 세22 (I5): 껍데기는 **씬(ring_forge_panel.tscn)**이 쥔다 — 좌표를 코드에 박지 마라.
## ⚠ 전부 씬으로 옮기지는 **않았다** — RingBoard·RingBook은 `_draw()` 커스텀 렌더라 에디터에서
## 드래그할 게 없다. 그 둘은 씬의 노드로 배치하되 스크립트가 계속 그린다. `_draw_pages`(책등 그라데이션)·
## `_draw_report`(점수 막대)도 코드에 남는다.
##
## 🔴 인스턴스화는 **씬으로** 한다 — `RingForgePanel.new()`는 껍데기가 없는 빈 Control이다:
##   const ForgeScene := preload("res://src/drawing/ring_forge_panel.tscn")
##   var panel := ForgeScene.instantiate() as RingForgePanelScript

const RingBoard := preload("res://src/drawing/ring_board.gd")
const RingBook := preload("res://src/drawing/ring_book.gd")
## 점수 → 안정성·위력 규칙. 🔴 **발사와 같은 함수를 쓴다** — 리포트가 보여 준 위력과 실제로
## 때리는 위력이 갈라지면 안 된다 (src/core/ring_power.gd의 주석 참조).
const RingPower := preload("res://src/core/ring_power.gd")

signal closed
## 도안이 방금 맺혔다 — 여는 쪽(작업대·거점)이 발사·연출에 쓴다. assembly = board.get_assembly()
signal design_committed(assembly: Dictionary)
## 🔴 책을 덮었는데 **점수 미달로 안 맺혔다** (세션 25). 여는 쪽이 이유를 화면에 띄운다 —
## 안 그러면 슬롯이 조용히 빈 채로 남아 "맺었는데 안 나간다"가 된다 (사용자가 실제로 겪었다).
signal commit_rejected(score: float)

# ── 레이아웃 (**논리 크기** 640×360 — 씬의 좌표도 전부 이 좌표계다) ──
## 🔴 세션 21: 뷰포트는 960×540(세션 18에 올림)이고 `stretch/aspect=expand`라 전체화면에선
## 그보다 더 넓어지기도 한다. 이 책은 640×360 좌표로 짜여 있어 그대로 두면 **왼쪽 위에 몰려 깨진다.**
## 고치는 방법은 좌표를 다시 재는 게 아니라 **무대(Stage)를 화면에 맞춰 비율 유지로 확대**하는 것이다.
## RingBoard·RingBook은 자기 size 비례로 그리므로(ring_board.gd `_outer_radius()`) 무대만 키우면
## 속도 같이 커진다.
## ⚠ `Spread.scale`은 **책 펼침 애니가 이미 쓴다**(open/close tween) — 배율을 거기 얹으면 애니가 덮어쓴다.
## 그래서 Spread를 감싸는 별도 무대(Stage)에 배율을 건다.
const DESIGN_SIZE := Vector2(640.0, 360.0)
## 책 껍데기 기하 — `_draw_pages`(코드 렌더)가 쓴다. 나머지 좌표는 전부 씬으로 나갔다.
const BOOK_RECT := Rect2(16, 10, 608, 340)
const PAGE_W := 304.0

# ── 한지·먹 톤 — 코드 렌더(_draw_pages·_draw_report)와 _set_say가 쓰는 것만 남았다 ──
const PAPER_L := Color(0.93, 0.89, 0.80)
const PAPER_R := Color(0.89, 0.84, 0.74)
const SPINE := Color(0.62, 0.55, 0.45, 0.55)
const EDGE := Color(0.45, 0.38, 0.30, 0.70)
const SHADOW := Color(0.0, 0.0, 0.0, 0.35)
const TITLE_COLOR := Color(0.36, 0.26, 0.16)
const HINT_COLOR := Color(0.50, 0.45, 0.38)
const SAY_COLOR := Color(0.30, 0.24, 0.18)
const WARN_COLOR := Color(0.62, 0.22, 0.14)
const REPORT_NAME := Color(0.24, 0.19, 0.14)
const REPORT_DESC := Color(0.44, 0.37, 0.30)
## 세71b 결과 '탁본 종이' — 내가 그은 획을 종이 톤 위에 눌러 찍은 프리뷰(연출 개편, 결과 데이터 무변경).
## 종이 톤은 살짝 어둡게(먹이 배어든 한지) + 네 귀퉁이 눌린 자국으로 "탁본"임을 읽힌다.
const RUBBING_BG := Color(0.85, 0.80, 0.70, 1.0)
const RUBBING_EDGE := Color(0.42, 0.35, 0.27, 0.75)
const RUBBING_CORNER := Color(0.34, 0.28, 0.20, 0.55)
const RUBBING_PAD := 10.0   # 프리뷰 상자 안쪽 여백(획이 테두리에 안 닿게)
## 세84 폐지 모드 「점수 근거」 상자 — 탁본 프리뷰가 있던 자리를 부품 근거가 쓴다. 같은 한지
## 톤이되 **귀퉁이 눌린 자국은 없다**(그건 "탁본지"라는 신호라 폐지 모드에서 거짓말이 된다).
const PARTS_BG := Color(0.87, 0.83, 0.74, 1.0)
const PARTS_EDGE := Color(0.42, 0.35, 0.27, 0.55)
const PARTS_PAD := 10.0
const PARTS_ROW_H := 13.0

## 🔴 세86 B② 리포트 세로 배치 — 「조립:」 줄이 **카드 폭을 넘어 잘리던** 자리를 고치며 상수로 뽑았다
## (세85 F5 실측: `층 [확산 고리 ×3×3, 폭발 고…`). 두 줄까지 나누고 아래를 그만큼 내린다.
## ⚠ 자리는 **줄 수와 무관하게 고정**이다 — 한 줄일 때 아래가 위로 올라오면 카드가 매번 들썩인다.
## ⚠ `REPORT_BOX_BOTTOM`은 리포트 버튼 줄(씬 ShootBtn y=292) 위 여백이다 — 버튼을 옮기면 같이 옮겨라.
const REPORT_SUM_Y := 106.0
const REPORT_SUM_LINE_H := 12.0
const REPORT_SUM_LINES := 2
const REPORT_BAR_Y := 130.0        # 종합 막대 (= REPORT_SUM_Y + 2줄 자리)
const REPORT_BODY_Y := 154.0       # 「점수 근거」 / 「완성도·정밀도」 머리줄
const REPORT_BOX_Y := 160.0        # 그 아래 상자(부품 근거)
const REPORT_BOX_BOTTOM := 284.0

const OPEN_SEC := 0.20
const OPEN_FROM_X := 0.04
const CLOSE_SEC := 0.12
## 펑 섬광이 가시는 시간 — 연출값(밸런스 아님). 짧아야 "터졌다"로 읽히고 길면 화면 전환처럼 보인다
const BURST_SEC := 0.45
## 주입 **성공** 금빛 섬광 — `_burst`(실패=붉은 섬광)와 대칭인 짝 (세62 UI 세련화).
const INJECT_FLASH_SEC := 0.4
const INJECT_FLASH_COLOR := Color(1.4, 1.28, 0.75)

# ── 책 겉모습 텍스처 (세62 UI 세련화) — 🔴 전부 `ResourceLoader.exists` 가드로 로드한다.
# PNG가 아직 없거나(아트 병렬 제작 중) 지워져도 옛 코드 렌더로 폴백해 안 죽는 게 계약이다.
# ⚠ .tscn/.tres의 ExtResource로 물면 에셋 부재 시 리소스 전체가 로드 실패한다(세50 침묵사 계열) —
# 그래서 씬은 빈 TextureRect만 두고 텍스처는 여기서 채운다.
const BOOK_ART_TEX := "res://assets/sprites/ui/book_spread.png"
const BOARD_PAPER_TEX := "res://assets/sprites/ui/board_paper.png"
const BTN_LEATHER_TEX := "res://assets/sprites/ui/btn_leather.png"
const BTN_LEATHER_PRESSED_TEX := "res://assets/sprites/ui/btn_leather_pressed.png"
const REPORT_PAPER_TEX := "res://assets/sprites/ui/panel_paper.png"
const BTN_TEX_MARGIN := 6.0        # btn_leather 24×24 나인패치 마진
const REPORT_TEX_MARGIN := 12.0    # panel_paper 48×48 나인패치 마진

# ── 점수 라벨 색 (세62) — 안정권이면 먹빛 강조, 이하면 흐린 회갈. 🔴 빨강 금지(그리는 중
# 위협 신호는 소음 — 설계 §잔손질 3). 경계 판정은 `RingPower.is_stable` 그대로(65 복사 금지).
const SCORE_STRONG := Color(0.20, 0.15, 0.10)
const SCORE_WEAK := Color(0.55, 0.48, 0.40)

## 🔴 세71 조립→탁본 — **조립이 먼저, 탁본은 통째로.** 오른쪽에서 진·룬을 고르고 진의 층에
## 문양-고리를 끼우면 왼쪽에 전체 밑그림이 뜬다. 그 전체를 손으로 **한 번에** 따라 긋는다.
const Copy_START := "오른쪽에서 진·룬을 고르고 진의 층에 문양-고리를 끼우세요 — 왼쪽 밑그림 전체를 손으로 한 번에 따라 그으면 [분석 ▶]"
## 세83 그리기 폐지 모드의 안내문 — 손 긋기를 안내하면 있지도 않은 조작을 적는 셈이다
## (CLAUDE.md 「안내문에 없는 조작을 적지 마라 — 그 자체가 버그다」).
const Copy_START_ASSEMBLE := "오른쪽에서 진·룬을 고르고 진의 층에 문양-고리를 끼우세요 — 다 끼웠으면 [마법진 완성 ✦]"

## 🔴 세84: 하단 조작 안내(HintLabel)는 **단계에서 파생한다**(`_update_hint`). 예전엔 씬에
## "여러 획 OK · 우클릭=다시 · ESC=덮기"가 박혀 있고 갱신 코드가 한 줄도 없어 **모든 단계에
## 상주**했다 — 폐지 모드엔 손 긋기가 아예 없으니(보드가 영구 IGNORE) 있지도 않은 조작을
## 안내하는 셈이다(CLAUDE.md·감사 #11).
## ⚠ **모드(`skip_drawing`)를 여기서 읽지 않는다** — DRAW 단계는 폐지 모드에서 도달 불가라
## (`_on_start_draw`가 바로 `_finish`) 단계만 보면 모드 분기가 저절로 맞는다. 모드를 또 읽으면
## 같은 사실을 두 소스가 쥐게 되고, 스위치를 되돌릴 때 한쪽만 남는다(세84 감사 T1).
const HINT_ASSEMBLE := "오른쪽 칸 클릭=조각 고르기 · ESC=덮기"
const HINT_DRAW := "여러 획 OK · 우클릭=다시 · ESC=덮기"
const HINT_RESULT := "[마력 주입]으로 맺는다 · ESC=덮기"
## 🔴 세71c 층(band) 수는 이제 **진이 정한다**(`JinDef.band_count`) — 옛 `const BANDS := 2`를 걷어냈다.
## `_bands` 크기가 선택 진 band_count에서 파생되고(`_resize_bands`), 진 미선택이면 소켓 0(`_reset_selection`).
## 일반진(jin_single) = 1층. RingBoard.BAND_RADII가 반경 목록을 쥐고 진은 앞 band_count개만 쓴다.

## 잉크 스와치 — 세71d [그리기 시작] 뒤 오른쪽 「그리기 도구」 패널(DrawTools) 안에 뜬다.
## 좌표는 DrawTools 로컬(292×280). 종이 축은 은퇴(세71d) — 잉크만 남았다.
## ⚠ 특별잉크 6종 이상이면 스와치 줄이 패널 폭(280)을 넘는다 — 잉크 축이 늘어나는 세션의 과제.
const INK_SWATCH_SIZE := Vector2(24.0, 18.0)
const INK_LABEL_POS := Vector2(12.0, 40.0)
const INK_SWATCH_X := 44.0
const INK_SWATCH_Y := 37.0
const INK_SWATCH_GAP := 5.0
const INK_EDGE := Color(0.30, 0.24, 0.16, 0.6)
const INK_EDGE_ON := Color(0.95, 0.82, 0.35)

## 🔴 `class_name` 없이도 정적 타입을 받는다 — `const X := preload(...)`를 타입으로 쓸 수 있다.
## 예전엔 `Control`로 받아 `.call(&"...")`로 더듬었고, 오타가 파싱이 아니라 **런타임에** 터졌다.
@onready var _stage: Control = $Stage         # 640×360 논리 무대 — 화면에 맞춰 통째로 확대(_fit_stage)
@onready var _spread: Control = $Stage/Spread
@onready var _pages: Control = $Stage/Spread/Pages
@onready var _book_art: TextureRect = $Stage/Spread/Pages/BookArt   # 책 스프레드 텍스처 (세62 — 없으면 코드 렌더 폴백)
@onready var _paper: TextureRect = $Stage/Spread/Paper              # 탁본지 텍스처 (세62 — 없으면 책 텍스처/코드 렌더가 비친다)
@onready var _board: RingBoard = $Stage/Spread/RingBoard
@onready var _book: RingBook = $Stage/Spread/RingBook
@onready var _next_btn: Button = $Stage/Spread/NextBtn
@onready var _commit_btn: Button = $Stage/Spread/CommitBtn
## 세71d [그리기 시작] 뒤 오른쪽 「그리기 도구」 패널 — 잉크 스와치(코드가 채움) + 큰 실시간 점수.
## DRAW 단계에서만 보인다(_set_phase). ASSEMBLE=RingBook(조립)·RESULT=Report(리포트)가 그 자리를 쓴다.
@onready var _draw_tools: Control = $Stage/Spread/DrawTools
@onready var _score_num: Label = $Stage/Spread/DrawTools/ScoreNum   # 큰 종합 점수 (세71d 실시간)
@onready var _score_sub: Label = $Stage/Spread/DrawTools/ScoreSub   # 완성도·정밀도 보조 줄
@onready var _title: Label = $Stage/Spread/TitleLabel
@onready var _say: Label = $Stage/Spread/SayLabel
## 하단 조작 안내 — 텍스트는 씬이 아니라 `_update_hint`(단계 파생)가 쥔다 (세84).
@onready var _hint: Label = $Stage/Spread/HintLabel
@onready var _report: Control = $Stage/Spread/Report   # 분석 리포트 오버레이 (완성 시 표시)
@onready var _redraw_btn: Button = $Stage/Spread/RedrawBtn   # 세71b [다시 조립] — 게이트 풀고 ASSEMBLE 복귀

## 🔴 세71b 점진 조립 게이트 — 조립(ASSEMBLE) → 그리기(DRAW) → 탁본 종이(RESULT) 3단계.
## 단일 소스 = 이 변수 하나. `_set_phase()`가 보드/책 mouse_filter·버튼·탭 잠금을 여기서 파생한다
## (동기화 지점 최소화 — 리뷰 각주 ⑥). ASSEMBLE=조립만(손 긋기 잠금)·DRAW=손 긋기·RESULT=결과.
enum Phase { ASSEMBLE, DRAW, RESULT }
var _phase := Phase.ASSEMBLE

var _committed := false
## 🔴 세71 조립→탁본 — **패널이 조립 상태를 쥔다** (슬라이스 패널 규율). RingAssembly는 Db를 몰라
## 층 전개를 못 한다. 선택이 바뀔 때마다 `recompose()`로 왼쪽 합성 가이드를 다시 세운다.
var _bands: Array[StringName] = []            # 밴드 idx → 문양-고리 id (&"" = 빈 밴드)
var _sel_band := 0                            # 지금 고른(강조) 밴드
var _sel_jin: StringName = &""                # 고른 진 id (&"" = 아직 — 밑그림 안 뜸)
## 🔴 세81 M2 융합진 — 룬이 **자리별**이 됐다(일반진=자리 1·융합진=자리 2). 진의 rune_slots만큼
## `_sel_runes`를 잡고(진 선택 때 `_resize_runes`), 자리마다 룬 타입 or RUNE_NONE. `_sel_rune_slot` =
## 지금 채우는 활성 자리(융합진 소켓 선택). 옛 `_sel_rune`(단일)+`_rune_picked`(bool)를 대체한다 —
## 자리 1개면 `_sel_runes=[불]` 하나라 옛 흐름과 계산·밑그림이 동일(무회귀).
const RUNE_NONE := -1                          # 룬 자리 미선택 (compose 센티넬·RingAssembly.RUNE_NONE과 같은 값)
var _sel_runes: Array[int] = [RUNE_NONE]       # 자리별 고른 룬 (RUNE_NONE=미선택). size = 진의 rune_slots
var _sel_rune_slot := 0                        # 지금 채울 활성 자리 (융합진 소켓 선택)
## 🔴 세71d 종이 축 은퇴 — 진 규모는 **1.0 고정**. `RingDesign.size`·`build_assembly["size"]` 스키마·
## 계약은 남긴다(ring_spell_system이 소비·test_ring_design/spell/save가 잰다) — 값만 1.0으로 굳힌다.
## 기본 종이(등급1)도 옛날부터 size 1.0이었다("기준 100 = 기본 종이") → 발사 baseline 무변경.
var _size_mult := 1.0                         # 진 규모 스칼라 — build_assembly.size (세71d 이후 1.0 고정)
## 🔴 맺은 발사 계약 캐시 (세71) — 통째 흐름에선 `_board.get_assembly()`가 COMBINED라 빈 값이라,
## `build_assembly()`로 직접 조립해 여기 담는다. 공개 `get_assembly()`가 이걸 돌려준다(F6·base 발사).
var _committed_asm: Dictionary = {}
var _analysis: Dictionary = {}                # 마지막 분석 {total} (리포트 렌더가 읽는다)
## 🔴 완성 시점의 발사 계약 (세션29) — 리포트가 잉크·크기·특별효과를 여기서 읽는다.
## _draw 안에서 build_assembly를 매번 부르지 않으려고 캐시한다. 잉크/종이를 바꾸면 갱신.
var _finish_asm: Dictionary = {}

## 🔴 잉크 선택 (세션28~29). 고른 잉크의 **색으로 획이 그려지고**, 등급 배수·특별잉크 효과가
## 도안에 실린다. 세션29: 특별잉크는 **보유량으로 걸러** 보인다(있는 것만 + 수량).
var _ink_ids: Array = []                      # 지금 고를 수 있는 잉크 id들 (기본=늘·특별=보유분)
var _active_ink: StringName = &""
var _ink_swatches: Array = []                 # 스와치 Button들 (색으로 고른다)
var _ink_nodes: Array = []                    # 잉크 UI 노드 전부(라벨+스와치) — 재빌드 때 free
## 🔴 획을 긋는 도중 특별잉크가 소모돼 재빌드가 걸리면, 획이 끝날 때까지 미룬다(활성 잉크가 튀지 않게).
var _palette_dirty := false
## 분석 리포트 배경 한지 나인패치 (세62) — _ready에서 exists 가드로 한 번 만들어 캐시.
## null이면 `_draw_report`가 옛 플랫 rect로 폴백한다.
var _report_sb: StyleBoxTexture = null


## 껍데기는 씬이 만든다 — 여기서는 **코드 렌더와 배선만** 붙인다.
func _ready() -> void:
	_pages.draw.connect(_draw_pages)
	_report.draw.connect(_draw_report)
	_spread.pivot_offset = BOOK_RECT.get_center()   # 책 펼침 애니의 회전축 = 책 한가운데

	# 🔴 세71 통째 흐름 — 조립본을 한 번에 긋는 COMBINED 모드라 per-piece 잠금이 없다.
	# ⚠ 그래서 판이 쏘던 stage machine 시그널 넷(stage_advanced·piece_locked·finished·assembly_changed)은
	# 구독자가 0이었고 **세85 ⑨에 판에서 통째로 은퇴했다**. 남은 판→패널 신호는 아래 둘뿐이다.
	_board.score_changed.connect(_on_combined_score)
	_board.stroke_ended.connect(_on_stroke_ended)   # 🔴 미뤄 둔 잉크 팔레트 재빌드를 획 끝에 흘린다

	_book.jin_selected.connect(_on_jin_selected)
	_book.rune_selected.connect(_on_rune_selected)
	_book.rune_slot_selected.connect(_on_rune_slot_selected)   # 세81 M2: 융합진 룬 소켓 선택
	_book.band_selected.connect(_on_band_selected)   # 세71: 강조 밴드 선택
	_book.ring_picked.connect(_on_ring_picked)       # 세71: 선택 밴드에 문양-고리 끼움

	# 🔴 세71b: 은퇴했던 NextBtn을 **[그리기 시작] 게이트**로 되살린다(리뷰 각주 ⑤ — 죽은 노드 안 남긴다).
	# text·핸들러를 갈아 끼운다. ASSEMBLE에서만 보이고, 진+룬을 골라야 활성.
	# 세83: 폐지 모드면 이 버튼이 곧 완성 버튼이다 — 이름이 하는 일과 같아야 한다(세25 「분석 ▶」 교훈).
	_next_btn.text = _start_btn_name()
	_next_btn.pressed.connect(_on_start_draw)
	_redraw_btn.text = "◀ 다시 조립"
	_redraw_btn.visible = false
	_redraw_btn.pressed.connect(_on_redraw_assemble)
	_commit_btn.pressed.connect(_finish)
	# 🔴 [쏘기] → **[마력 주입]** (세션 23). 조용히 성공하던 자리에 성공/실패가 갈리는 의식이 들어갔다.
	var inject_btn := $Stage/Spread/Report/ShootBtn as Button
	inject_btn.text = "마력 주입"
	inject_btn.pressed.connect(_on_inject)
	# 🔴 세86 B①: 리포트 [다시]의 이름도 **모드에서 판다**(`_start_btn_name` 선례). 씬에 박혀 있던
	# "다시 그리기"가 폐지 모드에서 **없는 조작**을 광고했다(세85 F5가 눈으로 잡았다).
	var redo_btn := $Stage/Spread/Report/RedoBtn as Button
	redo_btn.text = _redo_btn_name()
	redo_btn.pressed.connect(_on_report_redo)

	# ── 책 겉모습 텍스처 (세62) — 전부 exists 가드. 없으면 옛 코드 렌더/기본 버튼으로 폴백.
	if ResourceLoader.exists(BOOK_ART_TEX):
		_book_art.texture = load(BOOK_ART_TEX) as Texture2D
	if ResourceLoader.exists(BOARD_PAPER_TEX):
		_paper.texture = load(BOARD_PAPER_TEX) as Texture2D
	_report_sb = _make_paper_sb(REPORT_PAPER_TEX, REPORT_TEX_MARGIN)
	_apply_book_theme()

	resized.connect(_fit_stage)   # 창 크기·전체화면 전환마다 다시 맞춘다
	_fit_stage()
	# 🔴 잉크·종이 팔레트 (세션28~29) — Db가 오토로드라 이미 준비돼 있다.
	# 특별잉크는 그리는 동안 닳으므로, 창고가 바뀌면(소모·정제) 팔레트를 다시 그린다.
	# 🔴 세션29: 좌상단 제목("고리 조립 마법진")을 숨겨 **종이 선택 자리**를 낸다. 제목은 장식이고
	# 오른쪽 say 텍스트가 맥락을 준다 — 안 숨기면 종이 버튼(x14)과 겹친다(실측 확인).
	_title.visible = false
	EventBus.resources_changed.connect(_rebuild_palettes)
	_rebuild_palettes()


## 논리 무대(640×360)를 화면에 **비율 유지로** 꽉 채우고 중앙에 놓는다.
## 뷰포트는 960×540이지만 `stretch/aspect=expand`라 전체화면에선 화면비에 따라 더 넓어질 수 있다 —
## 그래서 배율을 상수로 박지 않고 매번 실측해서 잰다(1.5 하드코딩은 21:9 같은 화면에서 다시 깨진다).
func _fit_stage() -> void:
	if _stage == null:
		return
	var s := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	if s <= 0.0:
		return
	_stage.scale = Vector2(s, s)
	_stage.position = (size - DESIGN_SIZE * s) * 0.5   # 남는 여백은 위아래(또는 좌우)로 반씩


# ─────────────────────────── 책 겉모습 텍스처 · 테마 (세62) ───────────────────────────

## 한지 나인패치 StyleBox — PNG가 없으면 null(호출한 쪽이 플랫 렌더로 폴백한다).
func _make_paper_sb(path: String, margin: float) -> StyleBoxTexture:
	if not ResourceLoader.exists(path):
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = load(path) as Texture2D
	sb.set_texture_margin_all(margin)
	return sb


## 가죽 버튼 StyleBox 4종을 **런타임에** 테마에 채운다. 🔴 forge_book_theme.tres에는 색만 있다 —
## .tres가 ExtResource로 PNG를 물면 에셋 미도착 시 리소스 전체가 로드 실패한다(세50 침묵사 계열).
## PNG가 없으면 테마에 StyleBox가 안 들어가 **기본 버튼 스타일로 폴백**한다(계약).
## hover/disabled는 같은 텍스처 + modulate_color 차이 — 상태별 텍스처를 늘리지 않는다(설계 §테마).
func _apply_book_theme() -> void:
	var th: Theme = _stage.theme
	if th == null or not ResourceLoader.exists(BTN_LEATHER_TEX):
		return
	var tex := load(BTN_LEATHER_TEX) as Texture2D
	var pressed_tex := tex
	if ResourceLoader.exists(BTN_LEATHER_PRESSED_TEX):
		pressed_tex = load(BTN_LEATHER_PRESSED_TEX) as Texture2D
	th.set_stylebox(&"normal", &"Button", _leather_sb(tex, Color.WHITE))
	th.set_stylebox(&"hover", &"Button", _leather_sb(tex, Color(1.08, 1.08, 1.08)))
	th.set_stylebox(&"pressed", &"Button", _leather_sb(pressed_tex, Color.WHITE))
	th.set_stylebox(&"disabled", &"Button", _leather_sb(tex, Color(0.72, 0.72, 0.72)))


func _leather_sb(tex: Texture2D, mod: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.set_texture_margin_all(BTN_TEX_MARGIN)
	sb.modulate_color = mod
	return sb


# ─────────────────────────── 열고 닫기 ───────────────────────────

func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	visible = true
	_fit_stage()          # 숨어 있는 동안 창이 바뀌었을 수 있다(resized는 안 왔을 수 있음)
	_committed = false
	_committed_asm = {}
	_analysis = {}
	_report.visible = false
	_reset_selection()                          # 🔴 세71: 진·룬·밴드 선택을 비운다 (진 안 고름 = 밑그림 없음)
	_inject_defs()                              # 🔴 Db에서 진·룬 정의를 읽어 책 탭에 주입 (세션 13 구조화)
	_board.clear_all()                          # 🔴 빈 판에서 시작 — clear_all은 _trace를 JIN으로 돌린다
	# 🔴 열 때마다 팔레트를 다시 짠다 (세션29) — 정제로 특별잉크·종이가 늘었을 수 있다.
	_rebuild_palettes()
	# 🔴 세71d 잉크 초기화는 open()에 유지(스와치 UI 가시성만 DRAW 게이팅) — 기본잉크 색을
	# 지금 보드에 걸어 둬야 DRAW 첫 획이 먹빛으로 나간다(통짜로 DRAW에 미루면 초기화가 깨진다).
	if not _ink_ids.is_empty():   # 기본 잉크(먹)로 시작 — 색을 판에 걸어 둔다
		_select_ink(_ink_ids[0])
	_sync_book_bands()                          # 🔴 층 소켓·보유 목록을 책에 주입 (세71)
	_sync_book_runes()                          # 🔴 세81 M2: 룬 소켓(자리) 상태를 책에 주입
	recompose()                                 # 🔴 clear_all 뒤 COMBINED 모드로 재진입 (빈 진이면 빈 가이드)
	_set_phase(Phase.ASSEMBLE)                  # 🔴 세71b: 조립 단계부터 — 손 긋기 잠금·룬/층 탭 잠금
	_set_say(_start_copy(), false)
	_update_score()
	_spread_open()


func close() -> void:
	if not visible:
		return
	# 🔴 맺기 버튼을 깜빡해도 쏠 수 있게 — 닫을 때 유효한 시도(진 고름 + 통째로 그음)면 자동으로 맺는다.
	# ⚠ **단, 견디는 마법진만** (세션 23). 안 그러면 대충 그린 진도 책만 덮으면 [마력 주입]을
	# 건너뛰고 맺히는 셈이라 펑이 **누르지 않으면 그만인 벌**이 된다 — 규칙에 구멍이 뚫린다.
	# 🔴 세71: 판정 점수 = `combined_total()`(통째 트레이스), `_board.get_assembly().score` 아님
	#   (COMBINED 모드에선 그게 빈 값이다 — 세26 「score 안 실으면 조용히 기준 위력」의 이번 판).
	if not _committed and _has_attempt():
		var sc := _score_now()
		if RingPower.is_stable(sc):
			_committed = true
			_committed_asm = build_assembly()
			design_committed.emit(_committed_asm)
			_refresh_buttons()
		else:
			# 🔴 **조용히 거부하지 않는다** (세션 25, 사용자: "맽기까지 했는데 안나감").
			# 거부 자체는 옳다(위 주석) — 문제는 **아무 말도 없었다는 것**이다. 책은 덮이고,
			# 슬롯은 비어 있고, 좌클릭해도 안 나가는데 이유가 어디에도 안 보였다.
			commit_rejected.emit(sc)
	var tw := create_tween()
	tw.tween_property(_spread, ^"scale", Vector2(OPEN_FROM_X, 1.0), CLOSE_SEC) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		visible = false
		closed.emit())


func _spread_open() -> void:
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 펼치는 동안은 잠금
	_spread.scale = Vector2(OPEN_FROM_X, 1.0)
	var tw := create_tween()
	tw.tween_property(_spread, ^"scale", Vector2.ONE, OPEN_SEC) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# 🔴 세71b: 펼침이 끝나면 **현재 단계**가 손 긋기 잠금을 판다 — ASSEMBLE이면 IGNORE 유지, DRAW면 STOP.
	# (옛 코드는 무조건 STOP이라 새 게이트 전에 손 긋기가 열려 버렸다.)
	tw.tween_callback(_apply_phase_filters)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	# 🔴 세71b: Enter는 단계별로 다르다 — ASSEMBLE=[그리기 시작], DRAW=[분석 ▶]. RESULT는 리포트 버튼으로.
	match k.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			if _phase == Phase.ASSEMBLE:
				_on_start_draw()
			elif _phase == Phase.DRAW:
				_finish()
			get_viewport().set_input_as_handled()


# ─────────────────────────── Db 데이터 주입 (세션 13 구조화) ───────────────────────────

## Db에서 진·룬·문양 정의를 읽어 보드·책에 넣는다. int const 대신 데이터가 UI를 채운다.
## 🔴 룬은 **해금된 것만** 넘긴다 (세션 34) — open()마다 불리므로 탁본 해금이 다음 개봉에 반영된다.
func _inject_defs() -> void:
	var jins: Array = _unlocked_jins()
	var runes: Array = _unlocked_runes()
	var glyphs: Array = Db.all_glyphs()
	var jin0: JinDef = jins[0] if not jins.is_empty() else null
	_board.set_defs(jin0, runes, glyphs)
	_book.set_defs(jins, runes, glyphs)


## 도감에서 해금된 룬만 (Enums.RUNE_TYPES 순서 = 불·물·바람). is_unlocked 판정은 여기(패널)가
## 한다 — 책·보드는 오토로드를 안 봐서 못 한다. unlock_id 빈 룬은 항상 잠긴 셈이라 안 뜬다.
func _unlocked_runes() -> Array:
	var out: Array = []
	for t: int in Enums.RUNE_TYPES:
		var rd: RuneDef = Db.get_rune(t)
		if rd != null and rd.unlock_id != &"" and GameState.is_unlocked(rd.unlock_id):
			out.append(rd)
	return out


## 🔴 해금된 진만 (세션44, 진=형태). 룬과 같은 규약 — is_unlocked 판정은 패널이 한다(책·보드는
## 오토로드를 안 봐서 못 한다). 시작 시드 = jin_single 하나(GameState, 세션61). unlock_id 빈 진은 안 뜬다.
func _unlocked_jins() -> Array:
	var out: Array = []
	for jd: JinDef in Db.all_jins():
		if jd != null and jd.unlock_id != &"" and GameState.is_unlocked(jd.unlock_id):
			out.append(jd)
	return out


# ─────────────────── 🔴 세71 조립 → 합성 가이드 (통째 트레이스) ───────────────────
## 슬라이스 패널(assembly_slice_panel) 규율 이식 — 패널이 `_bands`/`_sel_jin`/`_sel_rune`을 쥐고,
## 선택이 바뀔 때마다 `recompose()`로 왼쪽 합성 가이드를 다시 세운다. RingAssembly는 Db를 몰라
## 층 전개를 못 하므로 조립 상태는 패널의 소유다.

## 진·룬·밴드 선택을 비운다 (열 때·펑·[다시] 뒤). 진 미선택(&"") = 밑그림 없음.
## 🔴 세71c: `_reset_selection`은 `_sel_jin=&""`에서 불려 band_count를 **모른다** → 소켓 0(빈 배열).
## 진을 고르는 `_on_jin_selected`가 그때 선택 진 band_count로 `_resize_bands`한다(制約④ 시점 규율).
func _reset_selection() -> void:
	_bands = []                          # 진 미선택 = 소켓 없음 (band_count는 진 선택 때 파생)
	_sel_band = 0
	_sel_jin = &""
	# 🔴 세81 M2: 룬 자리도 옛 판(자리 1·미선택)으로 — 진 선택이 그 진의 rune_slots로 다시 잡는다.
	_sel_runes = [RUNE_NONE]
	_sel_rune_slot = 0


## 각 밴드의 GlyphRingDef(or null) — `compose_guide`(밑그림)·`layer_rings`(발사 계약)가 받는 형식.
## Db 조회는 패널이 한다. ⚠ 세79부터 발사는 `flatten_bands`가 아니라 `layer_rings`다(순서 보존).
func _band_defs() -> Array:
	var out: Array = []
	for id in _bands:
		out.append(Db.get_glyph_ring(id) if String(id) != "" else null)
	return out


## 보유(해금)한 문양-고리 목록 — codex 미해금은 뺀다. 판정은 패널이(책·보드는 오토로드를 안 본다).
func _available_rings() -> Array:
	var out: Array = []
	for gr: GlyphRingDef in Db.all_glyph_rings():
		if gr == null:
			continue
		if String(gr.unlock_id).is_empty() or GameState.is_unlocked(gr.unlock_id):
			out.append(gr)
	return out


## 층 소켓·보유 목록을 책에 주입한다 (set_defs와 동형 — 패널이 Db·codex를 해석해 넘긴다).
func _sync_book_bands() -> void:
	_book.set_bands(_band_defs(), _sel_band, _available_rings())


## 🔴 세81 M2: 룬 소켓(자리별 선택·활성 자리)을 책에 주입한다 (set_bands와 동형). 자리 1개면 책이
## 소켓을 안 그린다(무회귀) — 융합진(자리 ≥2)에서만 룬 소켓 줄이 룬 탭 위에 뜬다.
func _sync_book_runes() -> void:
	_book.set_rune_slots(_sel_runes, _sel_rune_slot)


## 🔴 조립본을 한 장의 합성 가이드로 만들어 보드에 통째 트레이스로 넣는다.
## 진을 아직 안 골랐으면(&"") 빈 가이드 — 오른쪽에서 진을 먼저 고르는 게 순서다(세25 규율).
func recompose() -> void:
	if _board == null:
		return
	if String(_sel_jin) == "":
		_board.enter_combined_trace(PackedVector2Array())
		_update_score()
		_refresh_buttons()
		return
	var jd := Db.get_jin(_sel_jin)
	var shape := int(jd.guide_shape) if jd != null else int(Enums.JinShape.CIRCLE)
	var ctr: Vector2 = _board.size * 0.5
	var ro := float(_board.size.x)
	if _board.has_method("_outer_radius"):
		ro = _board._outer_radius()
	# 🔴 합성 가이드 기하는 **고정 ro** — 종이 규모는 스칼라(size)로만 싣는다(설계 §종이 안전안).
	# 가이드를 키우면 판을 넘칠 위험(세50 좌표 실측 자리)이라 이번 슬라이스는 안 키운다.
	# 🔴 세81 M2: 룬을 **자리별 목록**으로 넘긴다(`_sel_runes`, 미선택 자리 = RUNE_NONE 센티넬).
	# 목록째 넘겨야 자리 좌표가 안 흔들린다 — 융합진 슬롯0을 먼저 골라도 왼쪽에 고정(compose가 센티넬
	# 자리는 서브패스만 건너뛴다). 아무 자리도 안 골랐으면(전부 -1) 룬 서브패스 0 = 진 윤곽만(무회귀).
	# 🔴 세71c: 조각별 서브패스로 합성 → flat은 그 flatten(한 소스, 制約 flat=flatten(subpaths)). 보드가
	# 서브패스를 받아 조각마다 별도 폴리라인으로 그린다(이음선 제거) + 밴드 수만큼 빈 층 동심원을 그린다.
	var band_defs := _band_defs()
	var paths := RingBoard.compose_guide_paths(shape, _sel_runes, band_defs, ctr, ro)
	var flat := PackedVector2Array()
	for sub in paths:
		flat.append_array(sub)
	# 🔴 세81 우회 — 4번째 인자 `show_band_lines`가 **DRAW에서만 false**라, 손으로 그을 땐 층
	# 칸막이 선이 안 보인다(그래서 `_on_start_draw`가 phase를 DRAW로 바꾼 **뒤에** recompose를
	# 부른다). ⚠ 세86의 「띠」가 이 우회를 대체하는지는 **미결이다** — 사연은 `RingBoard.BAND_LANE_PAD`
	# 주석 한 곳에 있다. 이 인자만 바꾸면 그 주석과 갈라진다.
	# 🔴 세84 #22: `_sel_runes`를 **한 번 더** 넘긴다(바로 위 `compose_guide_paths`에 넘긴 것과 같은
	# 값) — 판이 미선택 룬 자리 마커를 **상태**로 그리게 하는 유일한 입력이다. 4인자로 남기면 보드가
	# 하위 호환 폴백(개수 유추)을 타서 융합진(자리 2개)의 빈 자리 표식이 중심에 하나만 뜨거나
	# 통째로 사라진다 — 에러는 안 난다.
	_board.enter_combined_trace(flat, paths, band_defs.size(), _phase != Phase.DRAW, _sel_runes)
	_update_score()
	_refresh_buttons()


## 맺을 만한 시도가 있었나 — 진을 골랐고 통째로 뭔가 그었나. close 자동맺음·거부의 게이트다
## (아무것도 안 하고 닫으면 commit_rejected를 안 쏜다 — 헛된 "흩어졌다"를 피한다).
func _has_attempt() -> bool:
	if RingPower.skip_drawing():
		return _can_start_draw()   # 폐지 모드 = 「그을 것」이 없다. 조립이 끝났으면 시도가 있는 것
	return String(_sel_jin) != "" and _board.coverage() > 0.02


## 🔴🔴 **점수의 유일한 출처** (세83). 그리기가 살아 있으면 손그림 통째 점수, 폐지 모드면
## 부품이 정한 점수. 🔴 `combined_total()`을 직접 부르는 자리를 하나라도 남기면 **모드가 조용히
## 갈린다** — 폐지 모드에서 그 자리만 0점을 읽어 「조립했는데 펑」이 난다(세26 「score 안 실으면
## 조용히 기준 위력」의 이번 판).
## 부르는 곳 = `close`·`_finish`·`_on_inject`·`build_assembly`·`_update_score` **다섯 전부**
## (세84에 `_update_score`가 이 규율을 어긴 다섯 번째 자리라 여기로 합쳤다 — 감사 #11).
## ⚠ 이 목록은 계약 문서다. `combined_total()`을 새로 직접 부르는 자리를 만들지 말고, 이 함수의
## 호출자가 늘면 **이 줄도 같이 늘려라**(주석이 코드와 함께 늙지 않으면 다음 사람을 잘못 이끈다).
func _score_now() -> float:
	if not RingPower.skip_drawing():
		return _board.combined_total()
	var parts := assembled_parts()
	return RingPower.assembled_score(parts.x, parts.y)


## 🔴 조립 부품 수 — `x` = 문양 수, `y` = 층 수. `RingPower.assembled_score`의 **두 입력**이고
## 폐지 모드 리포트가 「점수 근거」로 그대로 적는다(세84). 같은 숫자를 두 곳에서 따로 세면
## 리포트와 점수가 갈라진다 — 그래서 세는 자리는 이 함수 하나다.
## ⚠ `layer_rings`는 밴드 0개(진 미선택·band_count 0)여도 **빈 층 하나**를 돌려준다 —
## 그게 발사 계약이라 층 수도 그 값을 그대로 쓴다(패널이 따로 세면 점수와 어긋난다).
## 🔴 **공개인 이유 = 그물의 관측점**(세84). 리포트 렌더는 헤드리스가 못 보지만 이 숫자는 볼 수
## 있다 — private을 더듬는 그물은 리팩터 때 조용히 죽는다(감사 #40 · 세22·23의 그 함정).
func assembled_parts() -> Vector2i:
	var rings := RingBoard.layer_rings(_band_defs())
	var glyphs := 0
	for ring_v in rings:
		for g in (ring_v as Array):
			if int(g) != RingBoard.GLYPH_NONE:
				glyphs += 1
	return Vector2i(glyphs, rings.size())


## 진 탭 셀 클릭 → 진을 고르고 왼쪽 밑그림 재합성 (세71: 밑그림은 통째, 진만 따로 안 긋는다).
func _on_jin_selected(jin_id: StringName) -> void:
	Audio.play(&"ui_click")
	_sel_jin = jin_id
	var jd := Db.get_jin(jin_id)
	var nm := String(jd.display_name) if jd != null else "진"
	# 🔴 세71c: **진이 층 수를 정한다**(JinDef.band_count) — 선택 진 band_count로 소켓을 리사이즈.
	# 겹치는 옛 끼움은 보존하고 `_sel_band`를 새 범위로 clamp(制約⑤ 시점). 그 뒤 책에 재주입.
	_resize_bands(_band_count_of(jd))
	# 🔴 세81 M2: 진이 **룬 자리 수**도 정한다(융합진 rune_slots=2). 겹치는 옛 선택 보존·활성 자리 clamp.
	_resize_runes(int(jd.rune_slots) if jd != null else 1)
	recompose()
	_sync_book_bands()   # 🔴 층 소켓 수(=band_count)를 책에 재주입
	_sync_book_runes()   # 🔴 세81 M2: 룬 소켓 수(=rune_slots)를 책에 재주입
	_sync_book_tabs()    # 🔴 세71b: 진 골랐다 → 룬 탭 열림
	var rmsg := " · 룬 자리 %d개(융합진)" % _sel_runes.size() if _sel_runes.size() >= 2 else ""
	_set_say("%s 골랐다 (%d층)%s — 이제 룬 탭에서 속성을 고르세요" % [nm, _bands.size(), rmsg], false)


## 진의 층 수 (JinDef.band_count, 없으면 1). RingBoard.BAND_RADII 개수로 클램프(반경이 없는 층은 못 쓴다).
func _band_count_of(jd: JinDef) -> int:
	var n := int(jd.band_count) if jd != null else 1
	return clampi(n, 0, RingBoard.BAND_RADII.size())


## `_bands`를 n칸으로 맞춘다 — 겹치는 옛 끼움은 보존하고 `_sel_band`를 범위로 clamp(制約⑤).
func _resize_bands(n: int) -> void:
	var old := _bands
	_bands = []
	for i in n:
		_bands.append(old[i] if i < old.size() else &"")
	_sel_band = clampi(_sel_band, 0, maxi(n - 1, 0))


## 🔴 세81 M2: `_sel_runes`를 n(진의 rune_slots)칸으로 맞춘다 — `_resize_bands` 선례 그대로.
## 최소 1칸(진 미선택·일반진). 겹치는 옛 선택은 보존, 활성 자리를 새 범위로 clamp.
func _resize_runes(n: int) -> void:
	var old := _sel_runes
	_sel_runes = []
	for i in maxi(n, 1):
		_sel_runes.append(old[i] if i < old.size() else RUNE_NONE)
	_sel_rune_slot = clampi(_sel_rune_slot, 0, _sel_runes.size() - 1)


## 룬 자리를 전부 채웠나 (융합진 [그리기 시작] 게이트). 자리 1개면 하나 고르면 참(옛 흐름).
func _runes_ready() -> bool:
	if _sel_runes.is_empty():
		return false
	for r in _sel_runes:
		if r == RUNE_NONE:
			return false
	return true


## 룬을 **적어도 하나** 골랐나 (밑그림에 룬이 뜨나·층 탭이 열리나 = 옛 `_rune_picked`).
func _any_rune() -> bool:
	for r in _sel_runes:
		if r != RUNE_NONE:
			return true
	return false


## primary 룬 (첫 채운 자리, 없으면 불 폴백) — 옛 `_sel_rune` 자리(요약·발사 rune 키).
func _primary_rune() -> int:
	for r in _sel_runes:
		if r != RUNE_NONE:
			return r
	return RingBoard.RUNE_FIRE


## 발사 계약 룬 목록 (자리 순서, 미선택 제외). build_assembly의 "runes" 정본.
func _chosen_runes() -> Array[int]:
	var out: Array[int] = []
	for r in _sel_runes:
		if r != RUNE_NONE:
			out.append(r)
	return out


## 다음 빈 룬 자리 (없으면 -1). 룬을 고른 뒤 활성 자리를 자동으로 다음 빈 칸으로 옮긴다(융합진 편의).
func _next_empty_rune_slot() -> int:
	for i in _sel_runes.size():
		if _sel_runes[i] == RUNE_NONE:
			return i
	return -1


## 룬 탭 셀 클릭 → **활성 자리**에 룬을 넣고 재합성. 룬 타입이 밑그림·발사·저장까지 흐른다(하드코딩 금지).
## 🔴 세81 M2: 융합진은 활성 자리(`_sel_rune_slot`)를 채우고, 고른 뒤 다음 빈 자리로 활성을 옮긴다
## (소켓을 안 눌러도 두 룬을 연속으로 고를 수 있게). 자리 1개면 늘 슬롯0 = 옛 흐름.
func _on_rune_selected(rune_type: int) -> void:
	Audio.play(&"ui_click")
	if _sel_rune_slot < 0 or _sel_rune_slot >= _sel_runes.size():
		_sel_rune_slot = 0
	_sel_runes[_sel_rune_slot] = rune_type
	var nxt := _next_empty_rune_slot()
	if nxt >= 0:
		_sel_rune_slot = nxt          # 다음 빈 자리로 활성 이동 (없으면 방금 자리 유지)
	var rd: RuneDef = Db.get_rune(rune_type)
	var nm := String(rd.display_name) if rd != null else "룬"
	recompose()
	_sync_book_runes()
	_sync_book_tabs()
	if _sel_runes.size() >= 2:
		var filled := _sel_runes.size() - _sel_runes.count(RUNE_NONE)
		var tail := ("모두 채웠으면 [%s]" % _start_btn_name()) if _runes_ready() else "남은 룬 자리를 채우세요"
		_set_say("%s 넣었다 (룬 %d/%d) — %s" % [nm, filled, _sel_runes.size(), tail], false)
	else:
		_set_say("%s 룬 골랐다 — 중심에 반영됐다. 층을 더하거나 [%s]" % [nm, _start_btn_name()], false)


## 🔴 세81 M2: 융합진 룬 소켓 클릭 → 채울 활성 자리를 바꾼다(단일 소스는 패널, 책은 반영만).
func _on_rune_slot_selected(i: int) -> void:
	if _sel_runes.is_empty():
		return
	_sel_rune_slot = clampi(i, 0, _sel_runes.size() - 1)
	_sync_book_runes()


## 층 소켓 클릭 → 강조 밴드를 바꾼다 (책이 자기 _sel_band를 갱신하지만 단일 소스는 패널).
func _on_band_selected(i: int) -> void:
	# 🔴 세71c: 상수 BANDS → `_bands.size()`. size 0 가드(진 미선택) — clampi(i,0,-1)이면 max<min이 된다.
	if _bands.is_empty():
		return
	_sel_band = clampi(i, 0, _bands.size() - 1)
	_sync_book_bands()


## 문양-고리 클릭 → 선택 밴드에 끼우고 재합성.
func _on_ring_picked(gr_id: StringName) -> void:
	Audio.play(&"ui_click")
	if _sel_band < 0 or _sel_band >= _bands.size():
		return
	_bands[_sel_band] = gr_id
	recompose()
	_sync_book_bands()
	var gr := Db.get_glyph_ring(gr_id)
	var nm := String(gr.display_name) if gr != null else "문양-고리"
	_set_say("%s 을(를) 밴드 %d에 끼웠다 — 밑그림에 층이 더해졌다" % [nm, _sel_band + 1], false)


# ─────────────────── 🔴 세71b 단계 게이트 (ASSEMBLE ↔ DRAW ↔ RESULT) ───────────────────

## 단계에 맞춰 보드/책 잠금·버튼·탭을 통째로 세운다 — 파생의 단일 소스.
##   ASSEMBLE = 손 긋기 잠금(board IGNORE)·조립 열림(book STOP)·룬/층 탭 순서 잠금.
##   DRAW     = 손 긋기 열림(board STOP)·조립 잠금(book IGNORE)·"밑그림 확정".
##   RESULT   = 리포트 오버레이(탁본 종이). 둘 다 잠금.
func _set_phase(p: Phase) -> void:
	_phase = p
	_report.visible = p == Phase.RESULT
	# 🔴 세71d: 잉크·큰 점수 「그리기 도구」는 **DRAW에서만** 뜬다 = 사용자 요청("그리기 시작하면
	# 옆에 잉크"). ASSEMBLE=RingBook(조립)·RESULT=Report(리포트)가 같은 오른쪽 페이지를 쓴다.
	_draw_tools.visible = p == Phase.DRAW
	# 🔴 세71e: 오른쪽 페이지는 **단계마다 한 물건만** 쓴다 — DRAW/RESULT엔 책을 **숨긴다**(mouse_filter만
	# 끄면 회색 탭·칸이 반투명 도구 패널 뒤로 비쳐 지저분했다, 사용자 지적). ASSEMBLE에서만 책을 보인다.
	_book.visible = p == Phase.ASSEMBLE
	_apply_phase_filters()
	_sync_book_tabs()
	_refresh_buttons()
	_update_score()
	_update_hint()


## 하단 조작 안내를 **지금 단계에 실제로 있는 조작**으로 갈아 끼운다 (세84 — 씬에 박힌
## 상주 문구를 대체). DRAW는 폐지 모드에서 도달 불가라 모드를 안 읽는다(위 HINT_* 주석).
func _update_hint() -> void:
	match _phase:
		Phase.DRAW:
			_hint.text = HINT_DRAW
		Phase.RESULT:
			_hint.text = HINT_RESULT
		_:
			_hint.text = HINT_ASSEMBLE


## 🔴 손 긋기 잠금은 **board.mouse_filter 토글**로만 한다(리뷰 각주 ② — 새 보드 플래그 없음).
## 조립 잠금은 **book.mouse_filter 토글**로 한다(대칭). 공개 API `trace_stroke`는 안 막힌다(헤드리스 훅).
func _apply_phase_filters() -> void:
	var drawing := _phase == Phase.DRAW
	_board.mouse_filter = Control.MOUSE_FILTER_STOP if drawing else Control.MOUSE_FILTER_IGNORE
	# ASSEMBLE에서만 조립을 만진다. DRAW/RESULT엔 책을 얼려 "본 것=그은 것"이 안 갈린다.
	_book.mouse_filter = Control.MOUSE_FILTER_STOP if _phase == Phase.ASSEMBLE else Control.MOUSE_FILTER_IGNORE


## 열린 탭 집합 — 선택에서 **파생**한다(잠금 단일 소스=선택 상태, 리뷰 각주 ④). 진 선택⇒룬 탭,
## 룬 선택⇒층 탭. ASSEMBLE이 아니면 전부 잠금(조립 얼림). open·clear·[다시 조립]·펑이 선택을
## 리셋하면 잠금도 자동으로 따라 닫힌다.
func _open_tabs() -> Array:
	if _phase != Phase.ASSEMBLE:
		return [false, false, false]
	# 🔴 세81 M2: 층 탭은 룬을 **적어도 하나** 골랐으면 열린다(융합진은 자리를 다 안 채워도 층을 얹을 수
	# 있게 — [그리기 시작] 게이트만 전부 채움을 요구한다). 자리 1개면 하나 고르면 열림 = 옛 흐름.
	return [true, String(_sel_jin) != "", _any_rune()]


func _sync_book_tabs() -> void:
	_book.set_open_tabs(_open_tabs())


## 진+룬을 모두 골랐나 — [그리기 시작] 게이트 활성 조건(층은 선택 사항).
## 🔴 세81 M2: 융합진은 룬 자리를 **전부** 채워야 시작(runes_ready). 자리 1개면 하나면 된다(옛 흐름).
## 시작 버튼의 이름 — 안내문이 버튼과 어긋나지 않게 **한 곳**에서 낸다.
func _start_btn_name() -> String:
	return "마법진 완성 ✦" if RingPower.skip_drawing() else "그리기 시작 ✎"


## 🔴 세86 B①: 리포트 [다시] 버튼의 이름 — `_start_btn_name()`과 **같은 규율로 모드에서 파생**한다.
## 이 버튼이 하는 일은 `_on_report_redo` → `clear_board()`, 즉 **처음부터 다시**다. 폐지 모드엔
## 「그리기」라는 단계 자체가 없으므로 "다시 그리기"는 **있지도 않은 조작을 적는 것**이고,
## CLAUDE.md가 그걸 *"그 자체가 버그"*라고 못 박았다(세85 F5가 실제로 화면에서 잡았다).
## ⚠ 씬(.tscn)에 문구를 도로 박지 마라 — 그러면 스위치를 되돌릴 때 한쪽만 따라온다(감사 T5).
func _redo_btn_name() -> String:
	return "다시 조립" if RingPower.skip_drawing() else "다시 그리기"


## 🔴 세84: 시작 안내문도 **한 곳**에서 낸다(`_start_btn_name` 선례). 예전엔 `open()`만 모드를
## 갈랐고 `clear_board()`는 무조건 손 긋기 문구를 적어, 실경로인 리포트 **[다시]** →
## `_on_report_redo` → `clear_board()`를 타면 폐지 모드인데 "손으로 한 번에 따라 그으면"이
## 떴다(감사 #11). 술어가 하나면 스위치를 되돌릴 때 두 자리가 같이 따라온다.
func _start_copy() -> String:
	return Copy_START_ASSEMBLE if RingPower.skip_drawing() else Copy_START


func _can_start_draw() -> bool:
	return String(_sel_jin) != "" and _runes_ready()


## 🔴 [그리기 시작] — 조립을 잠그고 손 긋기로 넘어간다. **순서 못박음(리뷰 각주 ③)**:
##   ① 룬 확정(이미 _rune_picked) → ② recompose(룬 포함 full 가이드=진+룬+밴드)
##   ③ enter_combined_trace(recompose 안에서) — 채점 가이드 = 최종 조립본과 일치("본 것=그은 것=쏜 것")
##   ④ 조립 잠금 + board STOP (= _set_phase(DRAW))
func _on_start_draw() -> void:
	if not _can_start_draw():
		_set_say("진과 룬을 먼저 고르세요", true)
		return
	Audio.play(&"ui_click")
	# 🔴🔴 세83 그리기 폐지 실험 — 조립이 끝나는 순간 마법진이 완성된다(사용자: *"조립해서 자신의
	# 마법을 만드는거지"*). **아래 옛 흐름은 한 줄도 안 지웠다** — `balance.skip_drawing = false`면
	# 이 갈래만 빠지고 손 긋기가 그대로 돌아온다(사용자 확정: *"먼저 꺼보고 판단"*).
	if RingPower.skip_drawing():
		_finish()
		return
	# 🔴 세81: phase를 **먼저** DRAW로 바꾼 뒤 recompose한다 — recompose가 `_phase != Phase.DRAW`로
	# 층 구분 동심원을 끄기 때문(그릴 때 선이 문양에 걸치는 걸 없앤다). 순서가 곧 그 신호다.
	_set_phase(Phase.DRAW)    # ④ 조립 잠금 + 손 긋기 열림
	recompose()               # ②③ 룬 포함 full 가이드로 재합성 + enter_combined_trace (DRAW라 밴드선 없이)
	_board.clear_stroke()     # 새 밑그림 위에 옛 획이 남지 않게
	_set_say("이제 이 밑그림을 손으로 따라 그으세요 — 다 그으면 [분석 ▶]", false)


## 🔴 [다시 조립] — 게이트를 풀고 ASSEMBLE로 되돌린다(획 리셋·조립 다시 열림). 안전장치.
func _on_redraw_assemble() -> void:
	Audio.play(&"ui_click")
	_committed = false
	_committed_asm = {}
	_board.clear_stroke()     # 그은 획을 비운다(선택·가이드는 유지 — 조립을 이어서 고친다)
	_set_phase(Phase.ASSEMBLE)
	_set_say("다시 조립하세요 — 진·룬·층을 바꾼 뒤 [%s]" % _start_btn_name(), false)


# ─────────────────────────── 잉크·종이 선택 (세션28~29) ───────────────────────────

## 🔴 잉크·종이 팔레트를 다시 그린다 — 창고가 바뀌면(특별잉크 소모·정제) 보유분이 달라진다.
## 버튼을 통째로 갈아 끼운다(몇 개뿐이라 싸다). 고른 것은 유지하되, 사라졌으면 안전한 기본으로.
func _rebuild_palettes() -> void:
	# 🔴 획을 긋는 도중이면 미룬다 — 특별잉크 소모가 resources_changed를 쏴 이 함수를 부르는데,
	# 여기서 팔레트를 갈아 끼우면 활성 잉크가 획 중간에 기본 먹으로 바뀐다(색·id가 튄다).
	# 획이 끝나면 _on_stroke_ended가 다시 부른다.
	if _board != null and _board.is_drawing():
		_palette_dirty = true
		return
	_build_ink_palette()


## 획을 뗐다 — 그리는 도중 미뤄 둔 잉크 팔레트 재빌드가 있으면 지금 흘린다.
func _on_stroke_ended() -> void:
	if _palette_dirty:
		_palette_dirty = false
		_rebuild_palettes()


## 잉크 스와치 — Db의 잉크마다 색 버튼. 🔴 기본잉크(무한)는 늘 보이고, **특별잉크는 보유분만**
## (수량을 버튼에 적는다). 소모로 0이 되면 목록에서 빠진다 → 고른 게 사라지면 기본잉크로 되돌린다.
func _build_ink_palette() -> void:
	for n: Node in _ink_nodes:
		n.queue_free()
	_ink_nodes.clear()
	_ink_swatches.clear()
	_ink_ids = _collect_inks()
	# 고른 잉크가 소모로 사라졌으면 첫 잉크(기본 먹)로 되돌린다 — 없는 잉크로 그리지 않게.
	if not _ink_ids.has(_active_ink) and not _ink_ids.is_empty():
		_select_ink(_ink_ids[0])

	# 🔴 세71d: 잉크 노드는 「그리기 도구」 패널(DrawTools)의 자식이다 — DRAW에서만 뜨는 컨테이너라
	# 가시성은 자동 게이팅된다(스와치 UI만 DRAW, 수집·기본선택은 open()에 유지 — architect (c)).
	var lbl := Label.new()
	lbl.text = "잉크"
	lbl.position = INK_LABEL_POS
	lbl.add_theme_font_size_override(&"font_size", 9)
	lbl.add_theme_color_override(&"font_color", HINT_COLOR)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_tools.add_child(lbl)
	_ink_nodes.append(lbl)
	for i in _ink_ids.size():
		var id: StringName = _ink_ids[i]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(INK_SWATCH_X + float(i) * (INK_SWATCH_SIZE.x + INK_SWATCH_GAP), INK_SWATCH_Y)
		b.size = INK_SWATCH_SIZE
		b.custom_minimum_size = INK_SWATCH_SIZE
		b.tooltip_text = _ink_name(id)
		# 특별잉크면 남은 수량을 버튼에 적는다 (그리는 동안 줄어드는 게 보인다).
		if Db.ink_is_special(id):
			b.text = str(GameState.get_count(id))
			b.add_theme_font_size_override(&"font_size", 9)
			b.add_theme_color_override(&"font_color", Color(1, 1, 1))
		var sb := StyleBoxFlat.new()
		sb.bg_color = _ink_color(id)
		sb.set_border_width_all(1)
		sb.border_color = INK_EDGE
		# 세 상태가 같은 인스턴스를 공유 → 선택 강조는 이 하나의 테두리만 바꾸면 된다.
		b.add_theme_stylebox_override(&"normal", sb)
		b.add_theme_stylebox_override(&"hover", sb)
		b.add_theme_stylebox_override(&"pressed", sb)
		b.pressed.connect(_select_ink.bind(id))
		_draw_tools.add_child(b)
		_ink_nodes.append(b)
		_ink_swatches.append(b)
	_highlight_ink()


## 잉크를 골랐다 → 획 색을 그 잉크로 (즉각 피드백) + **등급 배수·특별효과를 도안에 싣는다**(세션29).
## 색은 그리는 중에만 보이지만, `set_ink`는 assembly에 실려 발사·저장까지 간다.
func _select_ink(id: StringName) -> void:
	_active_ink = id
	_board.set_trace_ink(_ink_color(id))
	_board.set_ink(id)
	_highlight_ink()
	if _report.visible:
		_finish_asm = build_assembly()   # 리포트가 떠 있으면 새 잉크로 위력·효과 갱신 (세71: build_assembly)
		_report.queue_redraw()


## 🔴 지금 고른 잉크의 데미지 배수 — 리포트·주입 메시지가 **발사와 같은 값**을 보여 준다.
## 리졸버는 `Db.ink_mult` 하나뿐이다 (발사·HUD도 같은 곳을 부른다).
func _active_ink_mult() -> float:
	return Db.ink_mult(_active_ink)


func _highlight_ink() -> void:
	for i in _ink_swatches.size():
		var b: Button = _ink_swatches[i]
		var sb := b.get_theme_stylebox(&"normal") as StyleBoxFlat
		if sb == null:
			continue
		var on: bool = _ink_ids[i] == _active_ink
		sb.set_border_width_all(3 if on else 1)
		sb.border_color = INK_EDGE_ON if on else INK_EDGE


## 지금 고를 수 있는 잉크 — 기본잉크는 늘, **특별잉크는 보유분(수량>0)만**. 등급순.
func _collect_inks() -> Array:
	var ids: Array = []
	for it: ItemDef in Db.items.values():
		if it == null or it.kind != Enums.ItemKind.INK:
			continue
		if Db.ink_is_special(it.id) and GameState.get_count(it.id) <= 0:
			continue   # 특별잉크는 있어야 보인다 (없으면 못 고른다)
		ids.append(it.id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return Db.get_item(a).grade < Db.get_item(b).grade)
	return ids


func _ink_color(id: StringName) -> Color:
	var it := Db.get_item(id)
	if it != null and it.params.has("color"):
		return it.params["color"]
	return RingBoard.TRACE_INK


func _ink_name(id: StringName) -> String:
	var it := Db.get_item(id)
	return it.display_name if it != null and it.display_name != "" else String(id)


# ─────────────────── 손맛 피드백 (통째 트레이스 실시간 점수 · 분석) ───────────────────

## 🔴 세71: 통째 트레이스 중 점수가 갱신됐다 (board.score_changed). 종합 점수 라벨·버튼 갱신.
func _on_combined_score(_score: float) -> void:
	_update_score()
	_refresh_buttons()


# ─────────────────────────── 맺기 · 분석 리포트 ───────────────────────────

## 🔴 [분석 ▶] — 통째로 그은 조립본을 분석한다 (판정은 없다 — 맺음은 [마력 주입]).
func _finish() -> void:
	if String(_sel_jin) == "":
		_set_say("먼저 오른쪽에서 진을 고르세요", true)
		return
	# ⚠ 폐지 모드엔 「그은 양」이라는 게 없다 — 이 가드를 그대로 두면 완성이 **영원히 막힌다**.
	if not RingPower.skip_drawing() and _board.coverage() <= 0.02:
		_set_say("먼저 왼쪽 밑그림 전체를 손으로 따라 그으세요", true)
		return
	var total := _score_now()
	_analysis = {"total": total}   # 통째 점수 — per-piece 없음
	_finish_asm = build_assembly()   # 잉크·크기·특별효과 스냅샷 (리포트가 읽는다)
	_set_say("마법진 완성 — 위력을 보고 [마력 주입]으로 맺으세요" if RingPower.skip_drawing()
		else "마법진 완성 — 탁본 종이를 보고 [마력 주입]으로 맺으세요", false)
	_set_phase(Phase.RESULT)   # 🔴 세71b: 결과=탁본 종이 오버레이 (리포트 렌더는 _set_phase가 켠다)
	_report.queue_redraw()
	# 🔴🔴 세86 ⑭ **완성 연출** — 판이 「맺혔다」를 말하는 유일한 자리다. 세70 통째 흐름으로 바뀐 뒤
	# 옛 연출(착지 펄스·완성 발광)은 트리거가 per-piece 잠금이라 **15세션째 한 번도 안 떴다**.
	# ⚠ **리포트 다음에 부른다** — 순수 오버레이라 표시를 늦추지 않는다는 걸 순서로도 못박는다.
	# 🔴 소리는 **기존 wav 재사용**(`craft` = 만들어졌다). 새 소리를 만들지 않는 게 이번 갈래의 규율.
	_board.play_finish()
	Audio.play(&"craft")


## 🔴 리포트에서 [마력 주입] — 마법진이 맺히거나 **펑** 한다 (사용자 확정 2026-07-17 세션 23).
## 기준선(65점) 이하면 도안이 통째로 날아가고 처음부터 다시 그린다. 잃는 건 시간·정성뿐이다.
func _on_inject() -> void:
	var total := _score_now()   # 🔴 점수 출처는 _score_now 하나 (모드가 갈리는 자리)
	if not RingPower.is_stable(total):
		_burst(total)
		return
	_committed = true
	_committed_asm = build_assembly()   # 잉크·크기·특별효과를 실은 최종 계약 (발사·저장이 그대로 쓴다)
	_report.visible = false
	# 세62: 성공 = 금빛 섬광 — `_burst`(실패=붉은 섬광)와 대칭인 짝. 같은 modulate tween 방식.
	_spread.modulate = INJECT_FLASH_COLOR
	var flash := create_tween()
	flash.tween_property(_spread, ^"modulate", Color.WHITE, INJECT_FLASH_SEC) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	design_committed.emit(_committed_asm)
	# 🔴 세79 M1: 변형형 문양(확산·폭발)이 위력을 **갈래로 배분**하므로, 그게 끼어 있으면 이 숫자는
	# "한 갈래당"이다. 그냥 "위력 N"이라 적으면 리포트가 거짓말하는 걸로 읽힌다(ring_power 머리 주석의 경계).
	var pw := RingPower.power_display(total, Db.ink_mult(_committed_asm.get("ink", &"")),
		float(_committed_asm.get("size", 1.0)))
	var unit := "갈래당 위력" if _has_modifier_glyph() else "위력"
	_set_say("마력이 돌았다 — %s %d의 마법진이 맺혔다. 책을 덮고(ESC) 쏴 보세요" % [unit, pw], false)
	_refresh_buttons()


## 맺은 도안에 변형형 문양(확산·폭발)이 끼어 있나 — 리포트 위력 표시 단위를 가른다.
## 🔴 계열 판별의 단일 소스는 문양 데이터(`GlyphDef.behavior`)이고, 코드 목록은 `Db`가 준다
## (세82 — 옛 `Enums.is_modifier_glyph` 은퇴). 여기서 판정식을 베끼지 마라.
func _has_modifier_glyph() -> bool:
	var mods: Array = Db.modifier_codes()
	if mods.is_empty():
		return false
	for layer_v in RingDesign.layers_of(_committed_asm.get("rings", []) as Array):
		for g in (layer_v as Array):
			if int(g) in mods:
				return true
	return false


## 🔴 **헤드리스 조립 seam** (세79) — 클릭 경로(헤드리스가 못 잡는 것)를 안 타고 층 상태를 세운다.
## 테스트가 private(`_sel_jin`·`_bands`)을 직접 더듬으면 리팩터 때 **조용히** 죽는다: `-s`는 런타임
## 에러가 나도 `failures=0`으로 OK를 찍어서 **빨개지지도 않는다**(세22·23에 두 세션 연속 밟은 그 함정).
## 없는 메서드 호출은 `SCRIPT ERROR`로 grep에 잡힌다 — 그 차이 하나 때문에 이 함수가 있다.
func set_assembly_state(jin: StringName, bands: Array[StringName]) -> void:
	_sel_jin = jin
	_resize_bands(bands.size())
	for i in mini(bands.size(), _bands.size()):
		_bands[i] = bands[i]


## 🔴 세71 발사 계약 조립 — 밴드→**층 배열**(세79 M1: 플래튼은 순서를 버려서 걷었다) + 통째 점수 +
## 잉크/크기. `_board.get_assembly()`를
## **안 쓴다**(COMBINED 모드라 rings·score가 빈 값 — 세26 「score 안 실으면 조용히 기준 위력」의 이번 판).
## 특별잉크(화상 증폭)는 보드가 트레이스 중 집계하므로 그 필드만 board_asm에서 뽑는다.
func build_assembly() -> Dictionary:
	var band_defs := _band_defs()
	# 🔴 세79 M1: 밴드를 **층 배열**로 싣는다(`layer_rings`). 옛 `flatten_bands`는 밴드를 8칸 하나로
	# 뭉개 **감쌈 순서를 버렸다** — 순서가 곧 연산인 지금은 그게 곧 기능 손실이다.
	# ⚠ 밴드가 하나뿐인 진은 층 1개라 발사 결과가 예전과 점 단위로 같다 — 🔴 다만 세86 실측으로
	# 그런 진은 `jin_single` **하나뿐**이다(`jin_plain_g2`·`jin_fuse`는 band_count = 2).
	var rings := RingBoard.layer_rings(band_defs)
	var open: Array = []
	for ring_v in rings:
		for k in (ring_v as Array).size():
			if int((ring_v as Array)[k]) != RingBoard.GLYPH_NONE and not (k in open):
				open.append(k)   # 층들의 **합집합** — 렌더·요약용(발사는 층 배열을 그대로 본다)
	open.sort()
	var score := _score_now()
	# 🔴 rings/score는 아래서 직접 싣는다 — board_asm은 **특별잉크 집계**(보드 private)의 유일한 창구다.
	var board_asm := _board.get_assembly()
	# 🔴 세81 M2: 발사·저장 계약에 룬 **목록**을 싣는다("runes", 미선택 제외). "rune"(primary)은
	# 옛 소비자(단일 룬을 읽던 발사·요약·HUD) 무회귀용 — ring_spell_system이 "runes"로 융합한다.
	return {
		"ring_count": 1,
		"rune": _primary_rune(),
		"runes": _chosen_runes(),
		"jin": _sel_jin,
		"rings": rings,
		"open": open,
		"score": score,
		"ink": _active_ink,
		"special_ink": board_asm.get("special_ink", &""),
		"special_ratio": float(board_asm.get("special_ratio", 0.0)),
		"size": _size_mult,
	}


## 펑 — 도안이 날아간다. 붉은 섬광 뒤 판을 비운다 (연출 중엔 입력을 막아 두 번 못 누른다).
func _burst(total: float) -> void:
	_report.visible = false
	_spread.modulate = Color(1.9, 0.5, 0.4)
	var tw := create_tween()
	tw.tween_property(_spread, ^"modulate", Color.WHITE, BURST_SEC) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		clear_board()
		_set_say("펑! — 종합 %d점, %d점을 넘겨야 견딘다. 처음부터 다시."
			% [_pct(total), _pct(RingPower.threshold())], true))


## 리포트에서 [다시] — 처음부터 다시 그린다 (터지기 전에 무르는 길).
func _on_report_redo() -> void:
	_report.visible = false
	clear_board()


# ─────────────────────────── 버튼·점수 라벨 ───────────────────────────

## 지금 조각 점수(완성도·정밀도·종합)를 라벨에 쓴다.
## 세62: 숫자는 고정폭(%3d)으로 — 그리는 동안 자릿수가 바뀔 때마다 줄 전체가 흔들리는 지터 제거.
## 색 = 안정권이면 먹빛 강조·이하면 흐린 회갈(빨강 금지). 경계는 `is_stable` 그대로(65 복사 금지).
func _update_score() -> void:
	# 🔴 세71b: 조립 단계(ASSEMBLE)엔 아직 안 그었으니 점수 줄을 비운다 — 0% 잡음 제거.
	#   (DrawTools 자체가 DRAW에서만 보이지만, 라벨 텍스트도 비워 잔상을 없앤다.)
	if _phase == Phase.ASSEMBLE or not _board.is_tracing():
		_score_num.text = ""
		_score_sub.text = ""
		return
	# 🔴🔴 세84: 점수 출처는 `_score_now()` **하나**다(그 함수 주석의 규율). 예전엔 여기서
	# `combined_total()`을 직접 읽어 **다섯 번째 자리**가 됐고, 폐지 모드 RESULT에서 가드를
	# 통과해 실제로 돌면서 "0" + 미달색을 세팅했다(안 보이던 이유는 `_draw_tools.visible`
	# 가시성 가드 하나뿐 — 그 가드를 건드리는 순간 「조립했는데 0점」이 뜬다).
	var total := _score_now()
	# 🔴 세71d: 종합 점수를 **크게** — 그으면서 바로 오른다(실시간, score_changed 배선 재사용).
	_score_num.text = "%d" % _pct(total)
	_score_num.add_theme_color_override(&"font_color",
		SCORE_STRONG if RingPower.is_stable(total) else SCORE_WEAK)
	# 완성도·정밀도는 **손 긋기 축**이다 — 폐지 모드엔 그을 것이 없어 영구 0%다(없는 축을
	# 0으로 적으면 상단 점수와 모순된다, 감사 #11). 부품 근거는 리포트가 보여 준다.
	if RingPower.skip_drawing():
		_score_sub.text = ""
	else:
		_score_sub.text = "완성도 %d%% · 정밀도 %d%%" % [
			int(round(_board.coverage() * 100.0)), int(round(_board.accuracy() * 100.0))]


## 🔴 세71b 단계별 버튼:
##   ASSEMBLE → [그리기 시작](NextBtn), 진+룬 골라야 활성. [분석 ▶]·[다시 조립] 숨김.
##   DRAW     → [분석 ▶](CommitBtn), 통째로 뭔가 그었어야 활성. [다시 조립] 보임. [그리기 시작] 숨김.
##   RESULT   → 리포트 오버레이(마력 주입·다시). [다시 조립] 보임.
func _refresh_buttons() -> void:
	var assemble := _phase == Phase.ASSEMBLE
	_next_btn.visible = assemble
	_next_btn.disabled = not _can_start_draw()
	# [분석 ▶]은 DRAW에서만 — 아무것도 맺지 않는다(맺음은 리포트의 [마력 주입], 세션25). 이름=하는 일.
	_commit_btn.visible = _phase == Phase.DRAW
	_commit_btn.text = "✓ 맺힘" if _committed else "분석 ▶"
	_commit_btn.disabled = not _has_attempt()
	_redraw_btn.visible = not assemble


## 🔴 반올림은 core가 판다 — 「퍼펙트」가 "이 함수가 100을 돌려주는 순간"으로 정의돼 있어서,
## 여기서 따로 반올림하면 등급과 표시가 갈라진다 (ring_power.score_display 주석).
func _pct(score: float) -> int:
	return RingPower.score_display(score)


func _set_say(text: String, warn: bool) -> void:
	if text == "":
		return
	_say.text = text
	_say.add_theme_color_override(&"font_color", WARN_COLOR if warn else SAY_COLOR)


# ─────────────────────────── 외부 조회 ───────────────────────────

## 🔴 세71: 맺은 발사 계약 = `_committed_asm`(build_assembly 캐시). `_board.get_assembly()`는
## COMBINED 모드라 rings·score가 빈 값이라 못 쓴다 (F6·base가 이 값으로 발사한다).
func get_assembly() -> Dictionary:
	if not _committed:
		return {}
	return _committed_asm


## 맺을 만한 시도가 있나 — base·시험대가 "쏠 수 있나"를 물을 때 쓴다 (세71: 통째 흐름 게이트).
func can_commit() -> bool:
	return _has_attempt()


func clear_board() -> void:
	_board.clear_all()
	_committed = false
	_committed_asm = {}
	_analysis = {}
	_reset_selection()
	_sync_book_bands()
	recompose()            # 진 미선택 = 빈 가이드
	_set_phase(Phase.ASSEMBLE)   # 🔴 세71b: 펑·[다시]는 조립 단계로 되돌린다(리포트 닫힘·탭 잠금 리셋)
	_set_say(_start_copy(), false)   # 🔴 세84: open()과 **같은 술어** — 모드를 여기서 다시 갈래 치지 않는다


func play_cast() -> void:
	_board.play_cast()


# ─────────────────────────── 분석 리포트 렌더 (코드 렌더 — 씬에 없다) ───────────────────────────

## 분석 리포트 렌더 — 종합 등급·점수 + 조각별(진·룬·문양) 완성도·정밀도·점수 막대.
func _draw_report() -> void:
	var w := _report.size.x
	var h := _report.size.y
	# 세62: 배경 = 한지 나인패치(panel_paper 48×48 m12). 없으면 옛 플랫 렌더 폴백.
	if _report_sb != null:
		_report.draw_style_box(_report_sb, Rect2(Vector2.ZERO, Vector2(w, h)))
	else:
		_report.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0.94, 0.90, 0.82, 0.98), true)
		_report.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), EDGE, false, 2.0)
	var font := ThemeDB.fallback_font

	var total := float(_analysis.get("total", 0.0))
	var grade := RingPower.grade_of(total)   # 🔴 세71: 등급은 core가 판다(_analysis엔 total만 있다)
	_report.draw_string(font, Vector2(14, 26), "마법진 분석",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TITLE_COLOR)

	# 🔴 「퍼펙트」는 눈에 띄게 다르다 (사용자: *"백은 뭔가 달랐으면 좋겠네"*). 금색 · 크게 · ★.
	# 등급 **이름을 == 비교하지 않는다** — 이름은 바뀔 수 있고, 그때 조용히 평범해진다.
	var perfect := RingPower.is_perfect(total)
	if perfect:
		_report.draw_rect(Rect2(8, 36, w - 16, 22), Color(1.0, 0.86, 0.45, 0.35), true)
	_report.draw_string(font, Vector2(14, 52),
		("종합 %d점 · ★ %s ★" if perfect else "종합 %d점 · %s") % [_pct(total), grade],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15 if perfect else 13,
		Color(0.72, 0.48, 0.05) if perfect else Color(0.55, 0.30, 0.12))

	# 🔴 위력 = 이 진이 **버텨 준다면** 낼 힘. 발사와 같은 함수(RingPower)로 뽑는다.
	# ⚠ **견디는지는 여기서 말하지 않는다** (사용자 확정: "주입을 하면 그때 평가해서 터지게 할 거임 /
	# 지금은 안내하는 거 같은데 그러면 안 됨"). 미리 판정을 흘리면 [마력 주입]이 결과를 확인하는
	# 형식 절차가 된다 — 눌러 봐야 아는 게 이 버튼의 전부다.
	# 🔴 위력에 **잉크 등급 배수 + 진 크기**가 실린다 (세션29) — 발사·HUD와 같은 값. 기준 100 = 맨손·기본 종이.
	var ink_id := StringName(_finish_asm.get("ink", &""))
	var size := float(_finish_asm.get("size", 1.0))
	_report.draw_string(font, Vector2(14, 68), "위력 %d  (기준 100)"
		% RingPower.power_display(total, Db.ink_mult(ink_id), size),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.35, 0.30, 0.20))

	# 세션29: 잉크·종이·특별효과 요약 한 줄 (있을 때만) — 무엇이 위력·효과를 올렸나.
	var effects: Array[String] = []
	if ink_id != &"" and not is_equal_approx(Db.ink_mult(ink_id), 1.0):
		effects.append("%s ×%.1f뎀" % [_ink_name(ink_id), Db.ink_mult(ink_id)])
	# 🔴 세71d: 종이(규모) 축 은퇴 — size는 1.0 고정이라 "큰 진 ×뎀" 가지는 영구히 죽어 지웠다.
	var sratio := float(_finish_asm.get("special_ratio", 0.0))
	var sink := StringName(_finish_asm.get("special_ink", &""))
	if sratio > 0.0 and sink != &"":
		effects.append("%s 화상 ×%.2f" % [_ink_name(sink), Db.status_mult_of(sink, sratio)])
	if not effects.is_empty():
		_report.draw_string(font, Vector2(14, 82), " · ".join(effects),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.50, 0.32, 0.14))

	# 🔴 세71: per-piece 행이 없다 — 통째로 그은 종합 하나다. 대신 **무엇을 조립했나** 한 줄.
	# 🔴 세86 B②: 카드 폭을 재서 **최대 2줄로 나눈다**(넘치면 …). 층·문양이 늘수록 이 줄이 길어지고,
	# 지금까지는 그냥 잘려 나가 「무엇을 조립했나」의 뒷부분이 안 보였다(세85 F5).
	# ⚠ 폭은 아래 막대와 **같은 식**(size.x − 28)을 쓴다 — 좌표를 따로 베끼면 둘이 갈라진다.
	var sum_w := _report.size.x - 28.0
	var sum_y := REPORT_SUM_Y
	for ln: String in fit_lines("조립: " + _compose_summary(), font, 10, sum_w, REPORT_SUM_LINES):
		_report.draw_string(font, Vector2(14, sum_y), ln,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, REPORT_NAME)
		sum_y += REPORT_SUM_LINE_H
	# 종합 막대 — 그리기 모드=완성도×정밀도, 폐지 모드=부품 점수(둘 다 같은 0~1 척도라 막대는 하나다).
	var bar := Rect2(14, REPORT_BAR_Y, sum_w, 7)
	_report.draw_rect(bar, Color(0.80, 0.74, 0.62, 0.7), true)
	_report.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(total, 0.0, 1.0), bar.size.y)),
		Color(0.72, 0.45, 0.15), true)

	# 🔴🔴 세84: **아래 절반이 모드로 갈린다.** 예전엔 폐지 모드에서도 `coverage`·`accuracy`를
	# 그대로 읽어 상단의 「종합 70점」과 「완성도 0% · 정밀도 0%」가 **같은 카드에** 떴고, 그 아래
	# 탁본 프리뷰가 "(획 없음)"을 찍었다(감사 #11 — `_draw_report`에 모드 분기가 하나도 없었다).
	# 폐지 모드엔 「그은 양」이라는 축 자체가 없으니 그 자리에 **점수 근거**를 적는다 —
	# 사용자 세83 F5 숙제(*"탁본 종이를 보여주던 자리인데 그릴 게 없다"*)를 채우는 자리다.
	if RingPower.skip_drawing():
		_report.draw_string(font, Vector2(14, REPORT_BODY_Y), "점수 근거",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, REPORT_NAME)
		_draw_parts(Rect2(14.0, REPORT_BOX_Y, w - 28.0, REPORT_BOX_BOTTOM - REPORT_BOX_Y))
	else:
		_report.draw_string(font, Vector2(14, REPORT_BODY_Y),
			"완성도 %d%% · 정밀도 %d%%" % [
				int(round(_board.coverage() * 100.0)), int(round(_board.accuracy() * 100.0))],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, REPORT_DESC)
		# 🔴 세71b '탁본 종이' — 내가 그은 획을 종이 위에 눌러 찍은 프리뷰(연출 개편). 버튼(y292) 위 공간.
		_report.draw_string(font, Vector2(14, REPORT_BODY_Y + 18.0), "탁본",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, REPORT_NAME)
		_draw_rubbing(Rect2(14.0, REPORT_BOX_Y + 24.0, w - 28.0,
			REPORT_BOX_BOTTOM - REPORT_BOX_Y - 24.0))


## 내가 그은 먹선을 종이 톤 상자 안에 **자동 맞춤**해 그린다(탁본을 뜬 종이처럼). 좌표는 board-local이라
## 획들의 실제 경계로 스케일·정렬한다(빈 획이면 상자만). 획 색 = 지금 고른 잉크색(그린 그대로).
func _draw_rubbing(box: Rect2) -> void:
	_report.draw_rect(box, RUBBING_BG, true)
	_report.draw_rect(box, RUBBING_EDGE, false, 1.5)
	# 네 귀퉁이 눌린 자국 — "탁본지" 질감 힌트(절차 렌더, 도형금지 예외).
	var cl := 7.0
	for corner in [box.position, box.position + Vector2(box.size.x, 0.0),
			box.position + Vector2(0.0, box.size.y), box.position + box.size]:
		var ix := -1.0 if corner.x > box.get_center().x else 1.0
		var iy := -1.0 if corner.y > box.get_center().y else 1.0
		_report.draw_line(corner, corner + Vector2(ix * cl, 0.0), RUBBING_CORNER, 1.5)
		_report.draw_line(corner, corner + Vector2(0.0, iy * cl), RUBBING_CORNER, 1.5)

	var strokes: Array = _board.trace_strokes()
	var used := Rect2()
	var first := true
	for s: PackedVector2Array in strokes:
		for p: Vector2 in s:
			if first:
				used = Rect2(p, Vector2.ZERO)
				first = false
			else:
				used = used.expand(p)
	if first:
		_report.draw_string(ThemeDB.fallback_font, box.get_center() + Vector2(-30.0, 0.0),
			"(획 없음)", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, REPORT_DESC)
		return
	# 종횡비 유지 자동 맞춤 (여백 안). 한 점짜리 획 대비 0 나눗셈 가드.
	var inner := box.grow(-RUBBING_PAD)
	var sw := maxf(used.size.x, 1.0)
	var sh := maxf(used.size.y, 1.0)
	var sc := minf(inner.size.x / sw, inner.size.y / sh)
	var off := inner.get_center() - used.get_center() * sc
	var ink := _ink_color(_active_ink)
	for s2: PackedVector2Array in strokes:
		if s2.size() < 2:
			continue
		var out := PackedVector2Array()
		for p2: Vector2 in s2:
			out.append(p2 * sc + off)
		_report.draw_polyline(out, ink, 1.6, true)


## 🔴 세84 폐지 모드 리포트 — **무엇이 이 점수를 만들었나**. 손 긋기가 없으니 점수는 전부
## 부품에서 온다(`RingPower.assembled_score`의 두 입력 = 문양 수·층 수) — 그게 폐지 이후 유일한
## 성장 축이라 리포트가 그걸 보여줘야 「좋은 부품을 모으면 세진다」가 손끝에 닿는다.
##
## 🔴 그리는 문자열은 전부 `parts_headline()`·`score_reason()`(순수·공개)이 만든다 — 렌더는
## 헤드리스가 못 보지만 **문자열은 볼 수 있어** 숫자가 틀어지는 건 그물이 잡는다. 여기 남는 건
## 좌표·색뿐이고, 그게 F5로만 확인되는 부분이다.
## ⚠ 부품 수는 `assembled_parts()`(=`_score_now()`가 쓰는 그 함수)에서 온다 — 따로 세지 않는다.
func _draw_parts(box: Rect2) -> void:
	_report.draw_rect(box, PARTS_BG, true)
	_report.draw_rect(box, PARTS_EDGE, false, 1.5)
	var font := ThemeDB.fallback_font
	var x := box.position.x + PARTS_PAD
	var y := box.position.y + PARTS_PAD + 12.0
	_report.draw_string(font, Vector2(x, y), parts_headline(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, REPORT_NAME)
	y += 18.0
	# 층마다 무엇이 끼었나 — 안쪽(1층)부터 = 연산 순서(세79 M1). **빈 층도 적는다**: 층 자리
	# 자체가 점수에 들어가므로 안 적으면 "왜 이 점수인가"가 안 맞는다.
	# ⚠ 진의 band_count가 0이면 `_bands`가 비는데 `layer_rings`는 빈 층 하나를 세므로 행이 0개다 —
	# 그 경우만 층 수를 위 줄이 대신 말한다(지금 진 전부 band_count ≥ 1이라 발생 0).
	for i in _bands.size():
		if y + PARTS_ROW_H > box.end.y - PARTS_PAD - 26.0:
			_report.draw_string(font, Vector2(x + 6.0, y), "… 외 %d층" % (_bands.size() - i),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, REPORT_DESC)
			y += PARTS_ROW_H
			break
		var gr := Db.get_glyph_ring(_bands[i]) if String(_bands[i]) != "" else null
		var row := "%d층 · 빈 층" % (i + 1)
		if gr != null:
			row = "%d층 · %s ×%d" % [i + 1, String(gr.display_name), gr.count]
		_report.draw_string(font, Vector2(x + 6.0, y), row,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, REPORT_DESC)
		y += PARTS_ROW_H
	y += 6.0
	_report.draw_string(font, Vector2(x, y), score_reason(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, REPORT_NAME)
	y += 14.0
	_report.draw_string(font, Vector2(x, y), "더 좋은 부품을 모아 층을 채우면 세진다",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, REPORT_DESC)


## 🔴 폐지 모드 리포트의 「부품」 머리줄 — `_draw_parts`가 그리고 **그물이 읽는다**(세84).
## 렌더는 헤드리스가 못 보지만 문자열은 볼 수 있으니, 숫자가 틀어지는 건 그물이 잡는다.
func parts_headline() -> String:
	var parts := assembled_parts()
	return "층 %d겹 · 문양 %d개" % [parts.y, parts.x]


## 🔴 폐지 모드 리포트의 「점수 근거」 한 줄 — 무엇이 이 점수를 만들었나.
## 기여도를 **`RingPower.assembled_score`의 차이로** 뽑는다(balance 수치를 베끼면 조율할 때
## 리포트만 거짓말한다 — 세24 「경계를 상수로 베끼면 갈라진다」와 같은 함정).
## 🔴 셋을 「반올림한 값의 차」로 내므로 **바탕+문양+층 = 종합**이 표시상 정확히 맞는다
## (`assembled_score`가 1.0에서 클램프돼도 등식이 안 깨진다).
func score_reason() -> String:
	var parts := assembled_parts()
	var base := _pct(RingPower.assembled_score(0, 1))
	var with_glyphs := _pct(RingPower.assembled_score(parts.x, 1))
	var full := _pct(RingPower.assembled_score(parts.x, parts.y))
	return "바탕 %d + 문양 %d + 층 %d = 종합 %d점" % [
		base, with_glyphs - base, full - with_glyphs, full]


## 🔴 세86 B② — 한 줄을 **폭 안에서 최대 `max_lines`줄로 나눈다**(넘치면 마지막 줄을 …로 줄인다).
## 🔴 **static·순수인 이유 = 헤드리스 관측점**: 렌더(`draw_string`)는 헤드리스가 못 보지만 「몇 줄로
## 나뉘었나·폭 안에 드나」는 잰다. `_draw_report` 안에 계산을 두면 잘림 회귀를 아무도 못 잡는다
## (`RingBoard.compose_guide_paths`·`RingBook.jin_cell_rects`와 같은 규율).
## ⚠ 공백으로만 자른다 — 이 게임의 요약은 `진 · 룬 불 · 층 [발산 고리 ×5, …]`처럼 공백이 넉넉하다.
## 공백 없는 긴 낱말 하나는 자를 데가 없으므로 그 줄에서 …로 줄인다(폭을 넘기지 않는 게 계약).
static func fit_lines(text: String, font: Font, fs: int, max_w: float,
		max_lines: int) -> PackedStringArray:
	var out := PackedStringArray()
	if font == null or max_lines <= 0 or text.is_empty():
		out.append(text)
		return out
	var words := text.split(" ", false)
	var line := ""
	for i in words.size():
		var probe: String = words[i] if line.is_empty() else line + " " + words[i]
		if line.is_empty() or _text_w(font, probe, fs) <= max_w:
			line = probe
			continue
		if out.size() + 1 >= max_lines:
			# 마지막 줄 — 남은 말을 전부 이어 붙여 …로 줄인다("뒤에 더 있다"가 보이게).
			var rest := line
			for j in range(i, words.size()):
				rest += " " + words[j]
			out.append(_ellipsize(font, rest, fs, max_w))
			return out
		out.append(line)
		line = words[i]
	out.append(_ellipsize(font, line, fs, max_w))
	return out


static func _text_w(font: Font, s: String, fs: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


static func _ellipsize(font: Font, s: String, fs: int, max_w: float) -> String:
	if _text_w(font, s, fs) <= max_w:
		return s
	var cut := s
	while cut.length() > 1 and _text_w(font, cut + "…", fs) > max_w:
		cut = cut.substr(0, cut.length() - 1)
	return cut + "…"


## 리포트의 "무엇을 조립했나" 한 줄 — 진 · 룬 · 층(밴드별 문양-고리). per-piece 점수는 없다.
func _compose_summary() -> String:
	var jd := Db.get_jin(_sel_jin)
	var jin_name := String(jd.display_name) if jd != null else "?"
	# 🔴 세81 M2: 융합진은 룬이 여럿 — 다 적는다(불+물 …). 없으면 "?".
	var rune_names: Array[String] = []
	for r in _chosen_runes():
		var rd2: RuneDef = Db.get_rune(r)
		rune_names.append(String(rd2.display_name) if rd2 != null else "?")
	var rune_name := "+".join(rune_names) if not rune_names.is_empty() else "?"
	var layers: Array[String] = []
	for i in _bands.size():
		var gr := Db.get_glyph_ring(_bands[i]) if String(_bands[i]) != "" else null
		if gr != null:
			layers.append("%s×%d" % [String(gr.display_name), gr.count])
	var layer_str := ", ".join(layers) if not layers.is_empty() else "빈 층"
	return "%s · 룬 %s · 층 [%s]" % [jin_name, rune_name, layer_str]


## 책 껍데기 렌더. 세62: 책 몸은 BookArt 텍스처가 그린다 — 여기는 **그림자만** 깔고, 텍스처가
## 없을 때(아트 미도착·삭제)만 옛 코드 렌더(종이 두 장 + 책등 그라데이션)로 폴백한다.
func _draw_pages() -> void:
	var on := _pages
	var shadow := BOOK_RECT.grow(3.0)
	on.draw_rect(shadow, SHADOW, true)
	if _book_art != null and _book_art.texture != null:
		return   # 책 몸·책등·페이지 결은 텍스처(자식 BookArt)가 이 위에 얹힌다
	on.draw_rect(BOOK_RECT, PAPER_L, true)

	var right := Rect2(BOOK_RECT.position + Vector2(PAGE_W, 0.0),
		Vector2(PAGE_W, BOOK_RECT.size.y))
	on.draw_rect(right, PAPER_R, true)

	var mid := BOOK_RECT.position.x + PAGE_W
	for i in 7:
		var t := float(i) / 6.0
		var col := SPINE
		col.a = SPINE.a * (1.0 - t) * 0.8
		var w := 1.0 + t * 2.0
		on.draw_line(Vector2(mid - t * 7.0, BOOK_RECT.position.y),
			Vector2(mid - t * 7.0, BOOK_RECT.end.y), col, w)
		on.draw_line(Vector2(mid + t * 7.0, BOOK_RECT.position.y),
			Vector2(mid + t * 7.0, BOOK_RECT.end.y), col, w)
	on.draw_line(Vector2(mid, BOOK_RECT.position.y), Vector2(mid, BOOK_RECT.end.y),
		Color(0.42, 0.35, 0.27, 0.8), 1.0)

	on.draw_rect(BOOK_RECT, EDGE, false, 1.0)
