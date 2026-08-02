extends Control
## 고리 조립 제작대 — **책을 좌우로 펼친다.**
## 왼쪽 페이지 = 조립 보드(RingBoard) · 오른쪽 페이지 = 조각 선택기(RingBook — 진·룬·층 탭).
##
## 흐름 = **3단계 게이트**(`Phase`): ASSEMBLE(진·룬·문양-고리를 조립) → DRAW(왼쪽 판의 숨은 선을
## 손으로 통째로 문지른다) → RESULT(리포트에서 [마력 주입]으로 맺거나 [◀ 다시 조립]).
## ⚠ **그리기 폐지 모드**(`balance.skip_drawing` 기본 true)에선 DRAW가 **도달 불가**다 —
## `_on_start_draw`가 바로 `_finish()`로 간다. 그래서 그 모드의 시작 버튼은 [마법진 완성 ✦]이다.
##
## 계약: open() → 열림 / closed 시그널 → 닫힘 / design_committed(assembly) → 맺힘.
##
## 🔴 껍데기는 **씬(ring_forge_panel.tscn)**이 쥔다 — 좌표를 코드에 박지 마라.
##   (예외 = `_draw()` 커스텀 렌더인 RingBoard·RingBook·`_draw_pages`·`_draw_report`.)
## 🔴 인스턴스화도 **씬으로** — `.new()`는 껍데기가 없는 빈 Control이다.

const RingBoard := preload("res://src/drawing/ring_board.gd")
const RingBook := preload("res://src/drawing/ring_book.gd")
## 🔴 **발사와 같은 함수를 쓴다** — 리포트가 보여 준 위력과 실제로 때리는 위력이 갈라지면 안 된다.
const RingPower := preload("res://src/core/ring_power.gd")

signal closed
## 도안이 방금 맺혔다 — 여는 쪽(작업대·거점)이 발사·연출에 쓴다.
signal design_committed(assembly: Dictionary)
## 🔴 책을 덮었는데 **점수 미달로 안 맺혔다.** 여는 쪽이 이유를 화면에 띄워야 한다 —
## 안 그러면 슬롯이 조용히 빈 채로 남아 "맺었는데 안 나간다"가 된다.
signal commit_rejected(score: float)

## [⚒ 부품 제작]을 눌렀다 — 🔴 공방을 여기서 직접 열지 않는다(`src/drawing`이 `src/base`의 패널을
## 물면 모듈 경계 위반). 책은 요청만 하고 무대가 연다.
## ⚠ 수신자 없는 무대에서 책을 펴면 아무 일도 안 난다 — 새 무대에서 펴게 되면 그쪽도 이어라.
signal craft_requested

# ── 레이아웃 (**논리 크기** 640×360 — 씬의 좌표도 전부 이 좌표계다) ──
## 🔴 이 좌표계를 화면에 맞추는 방법은 좌표를 다시 재는 게 아니라 **무대(Stage)를 통째로 확대**하는
## 것이다(속의 판·책은 자기 size 비례로 그린다).
## ⚠ 배율을 `Spread`에 얹지 마라 — 책 펼침 애니가 이미 그 scale을 쓴다(애니가 덮어쓴다).
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
## 결과 '탁본 종이' — 내가 그은 획을 종이 톤 위에 눌러 찍은 프리뷰.
const RUBBING_BG := Color(0.85, 0.80, 0.70, 1.0)
const RUBBING_EDGE := Color(0.42, 0.35, 0.27, 0.75)
const RUBBING_CORNER := Color(0.34, 0.28, 0.20, 0.55)
const RUBBING_PAD := 10.0   # 프리뷰 상자 안쪽 여백(획이 테두리에 안 닿게)
## 폐지 모드 「점수 근거」 상자. ⚠ 귀퉁이 눌린 자국은 **없다** — 그건 "탁본지"라는 신호라
## 손으로 긋지 않은 모드에서 거짓말이 된다.
const PARTS_BG := Color(0.87, 0.83, 0.74, 1.0)
const PARTS_EDGE := Color(0.42, 0.35, 0.27, 0.55)
const PARTS_PAD := 10.0
const PARTS_ROW_H := 13.0

## 리포트 세로 배치 — 「조립:」 줄은 두 줄까지 나누고 아래를 그만큼 내린다.
## ⚠ 자리는 **줄 수와 무관하게 고정**이다 — 한 줄일 때 아래가 올라오면 카드가 매번 들썩인다.
## ⚠ `REPORT_BOX_BOTTOM`은 리포트 버튼 줄 위 여백이다 — 버튼을 옮기면 같이 옮겨라.
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
## 주입 **성공** 금빛 섬광 — `_burst`(실패=붉은 섬광)와 대칭인 짝.
const INJECT_FLASH_SEC := 0.4
const INJECT_FLASH_COLOR := Color(1.4, 1.28, 0.75)

# 🔴 책 겉모습 텍스처는 전부 `ResourceLoader.exists` 가드로 로드한다 — PNG가 없어도
# 코드 렌더로 폴백해 안 죽는 게 계약이다.
# ⚠ .tscn/.tres의 ExtResource로 물면 에셋 부재 시 **리소스 전체가 로드 실패**한다 —
# 그래서 씬은 빈 TextureRect만 두고 텍스처는 여기서 채운다.
const BOOK_ART_TEX := "res://assets/sprites/ui/book_spread.png"
const BOARD_PAPER_TEX := "res://assets/sprites/ui/board_paper.png"
const BTN_LEATHER_TEX := "res://assets/sprites/ui/btn_leather.png"
const BTN_LEATHER_PRESSED_TEX := "res://assets/sprites/ui/btn_leather_pressed.png"
const REPORT_PAPER_TEX := "res://assets/sprites/ui/panel_paper.png"
const BTN_TEX_MARGIN := 6.0        # btn_leather 24×24 나인패치 마진
const REPORT_TEX_MARGIN := 12.0    # panel_paper 48×48 나인패치 마진

# 점수 라벨 색 — 안정권이면 먹빛 강조, 이하면 흐린 회갈.
# 🔴 빨강 금지(그리는 중 위협 신호는 소음) · 경계 판정은 `RingPower.is_stable`(기준선 복사 금지).
const SCORE_STRONG := Color(0.20, 0.15, 0.10)
const SCORE_WEAK := Color(0.55, 0.48, 0.40)

## 조립이 먼저, 탁본은 통째로 — 진·룬을 고르고 층에 문양-고리를 끼우면 왼쪽에 전체 밑그림이 뜬다.
const Copy_START := "오른쪽에서 진·룬을 고르고 진의 층에 문양-고리를 끼우세요 — 왼쪽 밑그림 전체를 손으로 한 번에 따라 그으면 [분석 ▶]"
## 🔴 그리기 폐지 모드 전용 안내문 — 손 긋기를 안내하면 **있지도 않은 조작**을 적는 셈이다.
const Copy_START_ASSEMBLE := "오른쪽에서 진·룬을 고르고 진의 층에 문양-고리를 끼우세요 — 다 끼웠으면 [마법진 완성 ✦]"

## 🔴 하단 조작 안내는 **단계에서 파생한다** — 씬에 박아 두면 모든 단계에 상주해
## 있지도 않은 조작을 안내한다.
## ⚠ 여기서 모드(`skip_drawing`)를 읽지 마라 — DRAW 단계 자체가 폐지 모드에서 도달 불가라
## 단계만 보면 분기가 저절로 맞는다. 모드를 또 읽으면 같은 사실을 두 소스가 쥔다.
const HINT_ASSEMBLE := "오른쪽 칸 클릭=조각 고르기 · ESC=덮기"
const HINT_DRAW := "여러 획 OK · 우클릭=다시 · ESC=덮기"
const HINT_RESULT := "[마력 주입]으로 맺는다 · ESC=덮기"

## 잉크 스와치 — 좌표는 DrawTools 로컬. 종이 축은 은퇴해서 잉크만 남았다.
## ⚠ 특별잉크가 6종 이상이면 스와치 줄이 패널 폭을 넘는다.
const INK_SWATCH_SIZE := Vector2(24.0, 18.0)
const INK_LABEL_POS := Vector2(12.0, 40.0)
const INK_SWATCH_X := 44.0
const INK_SWATCH_Y := 37.0
const INK_SWATCH_GAP := 5.0
const INK_EDGE := Color(0.30, 0.24, 0.16, 0.6)
const INK_EDGE_ON := Color(0.95, 0.82, 0.35)

## 🔴 `const X := preload(...)`를 정적 타입으로 쓴다 — `Control`로 받아 `.call(&"...")`로 더듬으면
## 오타가 파싱이 아니라 **런타임에** 터진다.
@onready var _stage: Control = $Stage         # 640×360 논리 무대 — 화면에 맞춰 통째로 확대(_fit_stage)
@onready var _spread: Control = $Stage/Spread
@onready var _pages: Control = $Stage/Spread/Pages
@onready var _book_art: TextureRect = $Stage/Spread/Pages/BookArt   # 없으면 코드 렌더 폴백
@onready var _paper: TextureRect = $Stage/Spread/Paper              # 없으면 책 텍스처가 비친다
@onready var _board: RingBoard = $Stage/Spread/RingBoard
@onready var _book: RingBook = $Stage/Spread/RingBook
@onready var _next_btn: Button = $Stage/Spread/NextBtn
@onready var _commit_btn: Button = $Stage/Spread/CommitBtn
## 「그리기 도구」 패널 — DRAW 단계에서만 보인다. 그 자리를 ASSEMBLE=RingBook·RESULT=Report가 나눠 쓴다.
@onready var _draw_tools: Control = $Stage/Spread/DrawTools
@onready var _score_num: Label = $Stage/Spread/DrawTools/ScoreNum   # 큰 종합 점수(실시간)
@onready var _score_sub: Label = $Stage/Spread/DrawTools/ScoreSub   # 완성도·정밀도 보조 줄
@onready var _title: Label = $Stage/Spread/TitleLabel
@onready var _say: Label = $Stage/Spread/SayLabel
## 하단 조작 안내 — 텍스트는 씬이 아니라 `_update_hint`(단계 파생)가 쥔다.
@onready var _hint: Label = $Stage/Spread/HintLabel
@onready var _report: Control = $Stage/Spread/Report   # 분석 리포트 오버레이 (완성 시 표시)
@onready var _redraw_btn: Button = $Stage/Spread/RedrawBtn   # [다시 조립] — 게이트 풀고 ASSEMBLE 복귀
@onready var _craft_btn: Button = $Stage/Spread/CraftBtn

## 🔴 점진 조립 게이트 — **단일 소스는 이 변수 하나**다. `_set_phase()`가 보드/책 mouse_filter·
## 버튼·탭 잠금을 전부 여기서 파생한다(동기화 지점을 늘리지 않는다).
enum Phase { ASSEMBLE, DRAW, RESULT }
var _phase := Phase.ASSEMBLE

var _committed := false
## 🔴 **패널이 조립 상태를 쥔다** — RingAssembly는 Db를 몰라 층 전개를 못 한다.
## 선택이 바뀔 때마다 `recompose()`로 왼쪽 합성 가이드를 다시 세운다.
var _bands: Array[StringName] = []            # 밴드 idx → 문양-고리 id (&"" = 빈 밴드)
var _sel_band := 0                            # 지금 고른(강조) 밴드
var _sel_jin: StringName = &""                # 고른 진 id (&"" = 아직 — 밑그림 안 뜸)
## 🔴 룬은 **자리별**이다 — 진의 rune_slots만큼 `_sel_runes`를 잡고 자리마다 룬 타입 or RUNE_NONE.
const RUNE_NONE := -1                          # RingAssembly.RUNE_NONE과 같은 값이어야 한다
var _sel_runes: Array[int] = [RUNE_NONE]       # 자리별 고른 룬. size = 진의 rune_slots
var _sel_rune_slot := 0                        # 지금 채울 활성 자리 (융합진 소켓 선택)
## ⚠ 종이 축이 은퇴해 규모는 1.0 고정이다 — 스키마·계약(`build_assembly["size"]`)은 발사부가
## 소비하고 테스트가 재므로 **남긴다**. 값만 굳혔다.
var _size_mult := 1.0
## 🔴 맺은 발사 계약 캐시 — 통째 흐름에선 `_board.get_assembly()`가 빈 값이라 `build_assembly()`로
## 직접 조립해 담는다. 공개 `get_assembly()`가 이걸 돌려준다.
var _committed_asm: Dictionary = {}
var _analysis: Dictionary = {}                # 마지막 분석 {total} (리포트 렌더가 읽는다)
## 완성 시점의 발사 계약 — 리포트가 잉크·크기·특별효과를 여기서 읽는다(_draw마다 재조립하지 않게 캐시).
var _finish_asm: Dictionary = {}

## 잉크 선택 — 고른 잉크의 **색으로 획이 그려지고** 등급 배수·특별효과가 도안에 실린다.
var _ink_ids: Array = []                      # 지금 고를 수 있는 잉크 id들 (기본=늘·특별=보유분)
var _active_ink: StringName = &""
var _ink_swatches: Array = []                 # 스와치 Button들 (색으로 고른다)
var _ink_nodes: Array = []                    # 잉크 UI 노드 전부(라벨+스와치) — 재빌드 때 free
## 🔴 획 도중 특별잉크가 닳아 재빌드가 걸리면 획이 끝날 때까지 미룬다 — 활성 잉크가 튀지 않게.
var _palette_dirty := false
## null이면 `_draw_report`가 플랫 rect로 폴백한다.
var _report_sb: StyleBoxTexture = null


## 껍데기는 씬이 만든다 — 여기서는 **코드 렌더와 배선만** 붙인다.
func _ready() -> void:
	_pages.draw.connect(_draw_pages)
	_report.draw.connect(_draw_report)
	_spread.pivot_offset = BOOK_RECT.get_center()   # 책 펼침 애니의 회전축 = 책 한가운데

	# 통째 흐름이라 판→패널 신호는 이 둘뿐이다.
	_board.score_changed.connect(_on_combined_score)
	_board.stroke_ended.connect(_on_stroke_ended)   # 미뤄 둔 잉크 팔레트 재빌드를 획 끝에 흘린다

	_book.jin_selected.connect(_on_jin_selected)
	_book.rune_selected.connect(_on_rune_selected)
	_book.rune_slot_selected.connect(_on_rune_slot_selected)
	_book.band_selected.connect(_on_band_selected)
	_book.ring_picked.connect(_on_ring_picked)

	# NextBtn = [그리기 시작] 게이트. ASSEMBLE에서만 보이고 진+룬을 골라야 활성.
	# 🔴 폐지 모드면 이 버튼이 곧 완성 버튼이다 — **이름이 하는 일과 같아야 한다.**
	_next_btn.text = _start_btn_name()
	_next_btn.pressed.connect(_on_start_draw)
	_redraw_btn.text = "◀ 다시 조립"
	_redraw_btn.visible = false
	_redraw_btn.pressed.connect(_on_redraw_assemble)
	_commit_btn.pressed.connect(_finish)
	# [⚒ 부품 제작] — 요청만 쏜다(무대가 연다).
	_craft_btn.pressed.connect(func() -> void: craft_requested.emit())
	var inject_btn := $Stage/Spread/Report/ShootBtn as Button
	inject_btn.text = "마력 주입"
	inject_btn.pressed.connect(_on_inject)
	# 🔴 리포트 [다시]의 이름도 **모드에서 판다** — 씬에 박으면 폐지 모드에서 없는 조작을 광고한다.
	var redo_btn := $Stage/Spread/Report/RedoBtn as Button
	redo_btn.text = _redo_btn_name()
	redo_btn.pressed.connect(_on_report_redo)

	# 전부 exists 가드 — 없으면 코드 렌더/기본 버튼으로 폴백한다.
	if ResourceLoader.exists(BOOK_ART_TEX):
		_book_art.texture = load(BOOK_ART_TEX) as Texture2D
	if ResourceLoader.exists(BOARD_PAPER_TEX):
		_paper.texture = load(BOARD_PAPER_TEX) as Texture2D
	_report_sb = _make_paper_sb(REPORT_PAPER_TEX, REPORT_TEX_MARGIN)
	_apply_book_theme()

	resized.connect(_fit_stage)   # 창 크기·전체화면 전환마다 다시 맞춘다
	_fit_stage()
	# 특별잉크는 그리는 동안 닳으므로 창고가 바뀌면 팔레트를 다시 그린다.
	# 제목은 장식이라 숨긴다 — 안 숨기면 잉크 UI와 겹치고, 맥락은 오른쪽 say가 준다.
	_title.visible = false
	EventBus.resources_changed.connect(_rebuild_palettes)
	_rebuild_palettes()


## 논리 무대를 화면에 **비율 유지로** 꽉 채우고 중앙에 놓는다.
## 🔴 배율을 상수로 박지 마라 — `stretch/aspect=expand`라 화면비에 따라 뷰포트가 더 넓어진다.
func _fit_stage() -> void:
	if _stage == null:
		return
	var s := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	if s <= 0.0:
		return
	_stage.scale = Vector2(s, s)
	_stage.position = (size - DESIGN_SIZE * s) * 0.5   # 남는 여백은 위아래(또는 좌우)로 반씩


# ─────────────────────────── 책 겉모습 텍스처 · 테마 ───────────────────────────

## 한지 나인패치 StyleBox — PNG가 없으면 null(호출한 쪽이 플랫 렌더로 폴백한다).
func _make_paper_sb(path: String, margin: float) -> StyleBoxTexture:
	if not ResourceLoader.exists(path):
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = load(path) as Texture2D
	sb.set_texture_margin_all(margin)
	return sb


## 가죽 버튼 StyleBox를 **런타임에** 테마에 채운다 — 🔴 .tres가 ExtResource로 PNG를 물면
## 에셋 미도착 시 리소스 전체가 로드 실패한다. PNG가 없으면 기본 버튼 스타일로 폴백(계약).
## hover/disabled는 같은 텍스처 + modulate 차이 — 상태별 텍스처를 늘리지 않는다.
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
	_reset_selection()                          # 진 안 고름 = 밑그림 없음
	_inject_defs()                              # Db에서 진·룬 정의를 읽어 책 탭에 주입
	_board.clear_all()
	# 열 때마다 팔레트를 다시 짠다 — 정제로 특별잉크가 늘었을 수 있다.
	_rebuild_palettes()
	# ⚠ 잉크 초기화는 여기 있어야 한다(스와치 UI 가시성만 DRAW가 게이팅) — 기본 잉크 색을 지금
	# 판에 걸어 둬야 DRAW 첫 획이 먹빛으로 나간다.
	if not _ink_ids.is_empty():
		_select_ink(_ink_ids[0])
	_sync_book_bands()
	_sync_book_runes()
	recompose()                                 # clear_all 뒤 재진입 (빈 진이면 빈 가이드)
	_set_phase(Phase.ASSEMBLE)
	_set_say(_start_copy(), false)
	_update_score()
	_spread_open()


func close() -> void:
	if not visible:
		return
	# 맺기 버튼을 깜빡해도 쏠 수 있게 — 닫을 때 유효한 시도면 자동으로 맺는다.
	# ⚠ **단, 견디는 마법진만.** 안 그러면 대충 그린 진도 책만 덮으면 맺혀서, 펑이
	# 「누르지 않으면 그만인 벌」이 된다.
	# 🔴 판정 점수는 `_score_now()`다 — `_board.get_assembly().score`는 이 모드에서 빈 값이라
	#   쓰면 조용히 기준 위력으로 나간다.
	if not _committed and _has_attempt():
		var sc := _score_now()
		if RingPower.is_stable(sc):
			_committed = true
			_committed_asm = build_assembly()
			design_committed.emit(_committed_asm)
			_refresh_buttons()
		else:
			# 🔴 **조용히 거부하지 마라** — 거부 자체는 옳지만, 아무 말이 없으면 책은 덮이고
			# 슬롯은 빈 채 남아 "맺었는데 안 나간다"가 된다.
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
	# 🔴 펼침이 끝나면 **현재 단계**가 손 긋기 잠금을 판다 — 무조건 STOP으로 두면
	# 게이트 전에 손 긋기가 열린다.
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
	# Enter는 단계별로 다르다 — ASSEMBLE=[시작], DRAW=[분석 ▶]. RESULT는 리포트 버튼으로만 받는다.
	match k.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			if _phase == Phase.ASSEMBLE:
				_on_start_draw()
			elif _phase == Phase.DRAW:
				_finish()
			get_viewport().set_input_as_handled()


# ─────────────────────────── Db 데이터 주입 ───────────────────────────

## Db에서 진·룬·문양 정의를 읽어 보드·책에 넣는다 — int const 대신 데이터가 UI를 채운다.
## 🔴 룬은 **해금된 것만** 넘긴다. open()마다 불리므로 해금이 다음 개봉에 반영된다.
func _inject_defs() -> void:
	var jins: Array = _unlocked_jins()
	var runes: Array = _unlocked_runes()
	var glyphs: Array = Db.all_glyphs()
	var jin0: JinDef = jins[0] if not jins.is_empty() else null
	_board.set_defs(jin0, runes, glyphs)
	_book.set_defs(jins, runes, glyphs)


## 🔴 해금 판정은 **패널이 한다** — 책·보드는 오토로드를 안 봐서 못 한다.
## unlock_id가 빈 룬은 항상 잠긴 셈이라 안 뜬다.
func _unlocked_runes() -> Array:
	var out: Array = []
	for t: int in Enums.RUNE_TYPES:
		var rd: RuneDef = Db.get_rune(t)
		if rd != null and rd.unlock_id != &"" and GameState.is_unlocked(rd.unlock_id):
			out.append(rd)
	return out


## 해금된 진만 — 룬과 같은 규약. unlock_id가 빈 진은 안 뜬다.
func _unlocked_jins() -> Array:
	var out: Array = []
	for jd: JinDef in Db.all_jins():
		if jd != null and jd.unlock_id != &"" and GameState.is_unlocked(jd.unlock_id):
			out.append(jd)
	return out


# ─────────────────── 조립 → 합성 가이드 (통째 트레이스) ───────────────────

## 진·룬·밴드 선택을 비운다 (열 때·펑·[다시] 뒤). 진 미선택(&"") = 밑그림 없음.
## ⚠ 여기선 band_count를 **모른다**(진 미선택) → 소켓 0. 소켓 수는 진을 고를 때 파생된다.
func _reset_selection() -> void:
	_bands = []
	_sel_band = 0
	_sel_jin = &""
	_sel_runes = [RUNE_NONE]
	_sel_rune_slot = 0


## 각 밴드의 GlyphRingDef(or null) — 밑그림·발사 계약이 받는 형식. Db 조회는 패널이 한다.
## ⚠ 발사는 `flatten_bands`가 아니라 `layer_rings`다 — 층 순서가 곧 연산 순서라 평탄화하면 안 된다.
func _band_defs() -> Array:
	var out: Array = []
	for id in _bands:
		out.append(Db.get_glyph_ring(id) if String(id) != "" else null)
	return out


## 보유(해금)한 문양-고리 목록 — 판정은 패널이 한다.
func _available_rings() -> Array:
	var out: Array = []
	for gr: GlyphRingDef in Db.all_glyph_rings():
		if gr == null:
			continue
		if String(gr.unlock_id).is_empty() or GameState.is_unlocked(gr.unlock_id):
			out.append(gr)
	return out


## 층 소켓·보유 목록을 책에 주입한다 — 패널이 Db·codex를 해석해 넘긴다.
func _sync_book_bands() -> void:
	_book.set_bands(_band_defs(), _sel_band, _available_rings())


## 룬 소켓(자리별 선택·활성 자리)을 책에 주입한다. 자리 1개면 책이 소켓을 안 그린다.
func _sync_book_runes() -> void:
	_book.set_rune_slots(_sel_runes, _sel_rune_slot)


## 조립본을 한 장의 합성 가이드로 만들어 보드에 통째 트레이스로 넣는다.
## 진을 아직 안 골랐으면 빈 가이드 — 진을 먼저 고르는 게 순서다.
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
	# 🔴 합성 가이드 기하는 **고정 ro**다 — 규모는 스칼라(size)로만 싣는다(가이드를 키우면 판을 넘친다).
	# 🔴 룬은 **자리별 목록째** 넘긴다(미선택 = RUNE_NONE 센티넬) — 목록으로 넘겨야 자리 좌표가
	# 안 흔들린다. 개수만 넘기면 융합진의 빈 자리 표식이 어긋난다.
	# 🔴 flat은 서브패스의 flatten이다(소스 하나) — 보드가 조각마다 별도 폴리라인으로 그려 이음선을 없앤다.
	var band_defs := _band_defs()
	var paths := RingBoard.compose_guide_paths(shape, _sel_runes, band_defs, ctr, ro)
	var flat := PackedVector2Array()
	for sub in paths:
		flat.append_array(sub)
	# ⚠ `show_band_lines`가 **DRAW에서만 false**라 손으로 그을 땐 칸막이 선이 안 보인다 —
	#   그래서 `_on_start_draw`가 phase를 DRAW로 바꾼 **뒤에** recompose를 부른다.
	#   이 인자를 만질 땐 `RingBoard.BAND_LANE_PAD` 주석과 함께 봐라(둘이 같은 사안이다).
	# 🔴 `_sel_runes`를 마지막 인자로 **한 번 더** 넘긴다 — 이게 판이 미선택 자리 마커를 그리는
	#   유일한 입력이다. 빼면 보드가 개수 유추 폴백을 타서 빈 자리 표식이 **에러 없이** 어긋난다.
	_board.enter_combined_trace(flat, paths, band_defs.size(), _phase != Phase.DRAW, _sel_runes)
	_update_score()
	_refresh_buttons()


## 맺을 만한 시도가 있었나 — 진을 골랐고 통째로 뭔가 그었나. close 자동맺음·거부의 게이트다
## (아무것도 안 하고 닫으면 commit_rejected를 안 쏜다 — 헛된 "흩어졌다"를 피한다).
func _has_attempt() -> bool:
	if RingPower.skip_drawing():
		return _can_start_draw()   # 폐지 모드 = 「그을 것」이 없다. 조립이 끝났으면 시도가 있는 것
	return String(_sel_jin) != "" and _board.coverage() > 0.02


## 🔴🔴 **점수의 유일한 출처.** 그리기가 살아 있으면 손그림 통째 점수, 폐지 모드면 부품 점수.
## `combined_total()`을 직접 부르는 자리를 하나라도 남기면 **모드가 조용히 갈린다** —
## 폐지 모드에서 그 자리만 0점을 읽어 「조립했는데 펑」이 난다.
func _score_now() -> float:
	if not RingPower.skip_drawing():
		return _board.combined_total()
	var parts := assembled_parts()
	return RingPower.assembled_score(parts.x, parts.y)


## 조립 부품 수 — `x` = 문양 수, `y` = 층 수. 점수와 리포트 「점수 근거」가 **같은 이 함수**를 본다.
## 🔴 같은 숫자를 두 곳에서 따로 세면 리포트와 점수가 갈라진다.
## ⚠ `layer_rings`는 밴드 0개여도 **빈 층 하나**를 돌려준다 — 그게 발사 계약이라 층 수도 그 값을 쓴다.
## 🔴 공개인 이유 = 헤드리스 관측점. 리포트 렌더는 못 봐도 이 숫자는 볼 수 있다.
func assembled_parts() -> Vector2i:
	var rings := RingBoard.layer_rings(_band_defs())
	var glyphs := 0
	for ring_v in rings:
		for g in (ring_v as Array):
			if int(g) != RingBoard.GLYPH_NONE:
				glyphs += 1
	return Vector2i(glyphs, rings.size())


## 진 탭 셀 클릭 → 진을 고르고 왼쪽 밑그림 재합성.
func _on_jin_selected(jin_id: StringName) -> void:
	Audio.play(&"ui_click")
	_sel_jin = jin_id
	var jd := Db.get_jin(jin_id)
	var nm := String(jd.display_name) if jd != null else "진"
	# 🔴 **진이 층 수와 룬 자리 수를 정한다** — 겹치는 옛 선택은 보존하고 활성 인덱스를 clamp한다.
	_resize_bands(_band_count_of(jd))
	_resize_runes(int(jd.rune_slots) if jd != null else 1)
	recompose()
	_sync_book_bands()
	_sync_book_runes()
	_sync_book_tabs()    # 진 골랐다 → 룬 탭 열림
	var rmsg := " · 룬 자리 %d개(융합진)" % _sel_runes.size() if _sel_runes.size() >= 2 else ""
	_set_say("%s 골랐다 (%d층)%s — 이제 룬 탭에서 속성을 고르세요" % [nm, _bands.size(), rmsg], false)


## 진의 층 수 — ⚠ BAND_RADII 개수로 클램프한다(반경이 없는 층은 못 그린다).
func _band_count_of(jd: JinDef) -> int:
	var n := int(jd.band_count) if jd != null else 1
	return clampi(n, 0, RingBoard.BAND_RADII.size())


## `_bands`를 n칸으로 맞춘다 — 겹치는 옛 끼움은 보존하고 `_sel_band`를 범위로 clamp.
func _resize_bands(n: int) -> void:
	var old := _bands
	_bands = []
	for i in n:
		_bands.append(old[i] if i < old.size() else &"")
	_sel_band = clampi(_sel_band, 0, maxi(n - 1, 0))


## `_sel_runes`를 n칸으로 맞춘다 — 최소 1칸. 겹치는 옛 선택은 보존, 활성 자리를 clamp.
func _resize_runes(n: int) -> void:
	var old := _sel_runes
	_sel_runes = []
	for i in maxi(n, 1):
		_sel_runes.append(old[i] if i < old.size() else RUNE_NONE)
	_sel_rune_slot = clampi(_sel_rune_slot, 0, _sel_runes.size() - 1)


## 룬 자리를 **전부** 채웠나 — 시작 게이트. ⚠ `_any_rune()`과 다르다.
func _runes_ready() -> bool:
	if _sel_runes.is_empty():
		return false
	for r in _sel_runes:
		if r == RUNE_NONE:
			return false
	return true


## 룬을 **적어도 하나** 골랐나 — 밑그림에 룬이 뜨나·층 탭이 열리나.
func _any_rune() -> bool:
	for r in _sel_runes:
		if r != RUNE_NONE:
			return true
	return false


## primary 룬 (첫 채운 자리, 없으면 불 폴백). ⚠ 발사 계약의 룬 **목록**은 `_chosen_runes()`다.
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


## 다음 빈 룬 자리 (없으면 -1).
func _next_empty_rune_slot() -> int:
	for i in _sel_runes.size():
		if _sel_runes[i] == RUNE_NONE:
			return i
	return -1


## 룬 탭 셀 클릭 → **활성 자리**에 룬을 넣고 재합성.
## 🔴 룬 타입은 여기서 밑그림·발사·저장까지 그대로 흐른다 — 어디서도 하드코딩하지 마라.
## 고른 뒤 활성 자리를 다음 빈 칸으로 옮긴다 — 소켓을 안 눌러도 두 룬을 연속으로 고를 수 있게.
func _on_rune_selected(rune_type: int) -> void:
	Audio.play(&"ui_click")
	if _sel_rune_slot < 0 or _sel_rune_slot >= _sel_runes.size():
		_sel_rune_slot = 0
	_sel_runes[_sel_rune_slot] = rune_type
	var nxt := _next_empty_rune_slot()
	if nxt >= 0:
		_sel_rune_slot = nxt          # 없으면 방금 자리 유지
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


## 룬 소켓 클릭 → 채울 활성 자리를 바꾼다. 🔴 단일 소스는 패널이고 책은 반영만 한다.
func _on_rune_slot_selected(i: int) -> void:
	if _sel_runes.is_empty():
		return
	_sel_rune_slot = clampi(i, 0, _sel_runes.size() - 1)
	_sync_book_runes()


## 층 소켓 클릭 → 강조 밴드를 바꾼다. 🔴 단일 소스는 패널이다.
func _on_band_selected(i: int) -> void:
	# ⚠ size 0 가드(진 미선택) — 없으면 clampi(i, 0, -1)로 max < min이 된다.
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


# ─────────────────── 단계 게이트 (ASSEMBLE ↔ DRAW ↔ RESULT) ───────────────────

## 단계에 맞춰 보드/책 잠금·버튼·탭을 통째로 세운다 — 파생의 단일 소스.
##   ASSEMBLE = 손 긋기 잠금·조립 열림·룬/층 탭 순서 잠금
##   DRAW     = 손 긋기 열림·조립 잠금
##   RESULT   = 리포트 오버레이. 둘 다 잠금.
func _set_phase(p: Phase) -> void:
	_phase = p
	_report.visible = p == Phase.RESULT
	_draw_tools.visible = p == Phase.DRAW
	# 🔴 오른쪽 페이지는 단계마다 **한 물건만** 쓴다 — mouse_filter만 끄고 두면 책의 회색 탭이
	# 반투명 도구 패널 뒤로 비쳐 지저분하다.
	_book.visible = p == Phase.ASSEMBLE
	_apply_phase_filters()
	_sync_book_tabs()
	_refresh_buttons()
	_update_score()
	_update_hint()


## 하단 안내를 **지금 단계에 실제로 있는 조작**으로 갈아 끼운다.
func _update_hint() -> void:
	match _phase:
		Phase.DRAW:
			_hint.text = HINT_DRAW
		Phase.RESULT:
			_hint.text = HINT_RESULT
		_:
			_hint.text = HINT_ASSEMBLE


## 🔴 잠금은 **mouse_filter 토글로만** 한다 — 새 보드 플래그를 만들지 마라.
## 공개 API `trace_stroke`는 안 막힌다(헤드리스 훅).
func _apply_phase_filters() -> void:
	var drawing := _phase == Phase.DRAW
	_board.mouse_filter = Control.MOUSE_FILTER_STOP if drawing else Control.MOUSE_FILTER_IGNORE
	# DRAW/RESULT엔 책을 얼려 "본 것 = 그은 것"이 안 갈리게 한다.
	_book.mouse_filter = Control.MOUSE_FILTER_STOP if _phase == Phase.ASSEMBLE else Control.MOUSE_FILTER_IGNORE


## 열린 탭 집합 — 🔴 선택 상태에서 **파생**한다. 그래야 리셋·펑이 잠금도 자동으로 되돌린다.
## 층 탭은 룬을 **적어도 하나** 골랐으면 열린다(전부 채움을 요구하는 건 시작 게이트뿐이다).
func _open_tabs() -> Array:
	if _phase != Phase.ASSEMBLE:
		return [false, false, false]
	return [true, String(_sel_jin) != "", _any_rune()]


func _sync_book_tabs() -> void:
	_book.set_open_tabs(_open_tabs())


## 시작 버튼 이름 — 🔴 안내문이 버튼과 어긋나지 않게 **한 곳**에서 낸다.
func _start_btn_name() -> String:
	return "마법진 완성 ✦" if RingPower.skip_drawing() else "그리기 시작 ✎"


## 리포트 [다시] 버튼 이름 — 🔴 모드에서 파생한다. ⚠ 씬(.tscn)에 문구를 박지 마라:
## 폐지 모드엔 「그리기」 단계가 없어 "다시 그리기"가 **있지도 않은 조작을 광고**하고,
## 스위치를 되돌릴 때 한쪽만 따라온다.
func _redo_btn_name() -> String:
	return "다시 조립" if RingPower.skip_drawing() else "다시 그리기"


## 🔴 시작 안내문도 **한 곳**에서 낸다 — 두 자리에서 따로 고르면 한쪽(리포트 [다시] 경로)만
## 옛 문구로 남아 없는 조작을 안내한다.
func _start_copy() -> String:
	return Copy_START_ASSEMBLE if RingPower.skip_drawing() else Copy_START


func _can_start_draw() -> bool:
	return String(_sel_jin) != "" and _runes_ready()


## [그리기 시작] — 조립을 잠그고 손 긋기로 넘어간다.
## 🔴 순서를 못 박는다: recompose(전체 가이드)가 **먼저**, 그 다음 단계 전환이다 —
## 그래야 채점 가이드가 최종 조립본과 일치한다("본 것 = 그은 것 = 쏜 것").
func _on_start_draw() -> void:
	if not _can_start_draw():
		_set_say("진과 룬을 먼저 고르세요", true)
		return
	Audio.play(&"ui_click")
	# 🔴 그리기 폐지 스위치 — 아래 손 긋기 흐름은 **한 줄도 안 지웠다**. `skip_drawing = false`면
	# 이 갈래만 빠지고 그대로 돌아온다.
	if RingPower.skip_drawing():
		_finish()
		return
	# 🔴 phase를 **먼저** DRAW로 바꾼 뒤 recompose한다 — recompose가 `_phase`를 보고 층 구분
	# 동심원을 끄기 때문이다(그을 때 선이 문양에 걸치지 않게). 순서 자체가 그 신호다.
	_set_phase(Phase.DRAW)
	recompose()
	_board.clear_stroke()     # 새 밑그림 위에 옛 획이 남지 않게
	_set_say("이제 이 밑그림을 손으로 따라 그으세요 — 다 그으면 [분석 ▶]", false)


## [다시 조립] — 게이트를 풀고 ASSEMBLE로 되돌린다(획 리셋·조립 다시 열림).
func _on_redraw_assemble() -> void:
	Audio.play(&"ui_click")
	_committed = false
	_committed_asm = {}
	_board.clear_stroke()     # 그은 획을 비운다(선택·가이드는 유지 — 조립을 이어서 고친다)
	_set_phase(Phase.ASSEMBLE)
	_set_say("다시 조립하세요 — 진·룬·층을 바꾼 뒤 [%s]" % _start_btn_name(), false)


# ─────────────────────────── 잉크 선택 ───────────────────────────

## 잉크 팔레트를 다시 그린다 — 창고가 바뀌면 보유분이 달라진다.
## 버튼을 통째로 갈아 끼운다(몇 개뿐이라 싸다). 고른 것이 사라졌으면 기본으로 되돌린다.
func _rebuild_palettes() -> void:
	# 🔴 획을 긋는 도중이면 미룬다 — 특별잉크 소모가 이 함수를 부르는데, 여기서 갈아 끼우면
	# 활성 잉크가 획 중간에 기본 먹으로 튄다. 획이 끝나면 `_on_stroke_ended`가 다시 부른다.
	if _board != null and _board.is_drawing():
		_palette_dirty = true
		return
	_build_ink_palette()


## 획을 뗐다 — 그리는 도중 미뤄 둔 잉크 팔레트 재빌드가 있으면 지금 흘린다.
func _on_stroke_ended() -> void:
	if _palette_dirty:
		_palette_dirty = false
		_rebuild_palettes()


## 잉크 스와치 — 기본잉크(무한)는 늘 보이고, **특별잉크는 보유분만** 뜬다(수량을 버튼에 적는다).
func _build_ink_palette() -> void:
	for n: Node in _ink_nodes:
		n.queue_free()
	_ink_nodes.clear()
	_ink_swatches.clear()
	_ink_ids = _collect_inks()
	# 고른 잉크가 소모로 사라졌으면 첫 잉크(기본 먹)로 되돌린다 — 없는 잉크로 그리지 않게.
	if not _ink_ids.has(_active_ink) and not _ink_ids.is_empty():
		_select_ink(_ink_ids[0])

	# 잉크 노드는 DrawTools의 자식이다 — DRAW에서만 뜨는 컨테이너라 가시성이 자동으로 게이팅된다.
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


## 잉크를 골랐다 → 획 색 + **등급 배수·특별효과**. 색은 그리는 중에만 보이지만
## `set_ink`는 assembly에 실려 발사·저장까지 간다.
func _select_ink(id: StringName) -> void:
	_active_ink = id
	_board.set_trace_ink(_ink_color(id))
	_board.set_ink(id)
	_highlight_ink()
	if _report.visible:
		_finish_asm = build_assembly()   # 리포트가 떠 있으면 새 잉크로 위력·효과 갱신
		_report.queue_redraw()


## 🔴 리졸버는 `Db.ink_mult` 하나뿐이다 — 발사·HUD가 같은 곳을 봐야 리포트가 거짓말을 안 한다.
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

func _on_combined_score(_score: float) -> void:
	_update_score()
	_refresh_buttons()


# ─────────────────────────── 맺기 · 분석 리포트 ───────────────────────────

## [분석 ▶] — 통째로 그은 조립본을 분석한다. ⚠ 여기서 맺지 않는다(맺음은 [마력 주입]).
func _finish() -> void:
	if String(_sel_jin) == "":
		_set_say("먼저 오른쪽에서 진을 고르세요", true)
		return
	# ⚠ 폐지 모드엔 「그은 양」이라는 게 없다 — 이 가드를 그대로 두면 완성이 **영원히 막힌다**.
	if not RingPower.skip_drawing() and _board.coverage() <= 0.02:
		_set_say("먼저 왼쪽 밑그림 전체를 손으로 따라 그으세요", true)
		return
	var total := _score_now()
	_analysis = {"total": total}
	_finish_asm = build_assembly()   # 잉크·크기·특별효과 스냅샷 (리포트가 읽는다)
	_set_say("마법진 완성 — 위력을 보고 [마력 주입]으로 맺으세요" if RingPower.skip_drawing()
		else "마법진 완성 — 탁본 종이를 보고 [마력 주입]으로 맺으세요", false)
	_set_phase(Phase.RESULT)
	_report.queue_redraw()
	# 완성 연출 — 판이 「맺혔다」를 말하는 유일한 자리다.
	# ⚠ **리포트 다음에** 부른다 — 순수 오버레이라 표시를 늦추면 안 된다.
	_board.play_finish()
	Audio.play(&"craft")


## [마력 주입] — 마법진이 맺히거나 **펑** 한다. 기준선 이하면 도안이 통째로 날아간다.
## 🔴 기준선을 여기 상수로 적지 마라 — 판정은 `RingPower.is_stable`이 한다.
func _on_inject() -> void:
	var total := _score_now()   # 🔴 점수 출처는 `_score_now` 하나뿐이다 (모드가 갈리는 자리)
	if not RingPower.is_stable(total):
		_burst(total)
		return
	_committed = true
	_committed_asm = build_assembly()   # 발사·저장이 그대로 쓰는 최종 계약
	_report.visible = false
	_spread.modulate = INJECT_FLASH_COLOR
	var flash := create_tween()
	flash.tween_property(_spread, ^"modulate", Color.WHITE, INJECT_FLASH_SEC) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	design_committed.emit(_committed_asm)
	# 🔴 변형형 문양은 위력을 **갈래로 배분**한다 — 그게 끼면 이 숫자는 "한 갈래당"이라,
	# 그냥 "위력 N"이라 적으면 리포트가 거짓말한다.
	var pw := RingPower.power_display(total, Db.ink_mult(_committed_asm.get("ink", &"")),
		float(_committed_asm.get("size", 1.0)))
	var unit := "갈래당 위력" if _has_modifier_glyph() else "위력"
	_set_say("마력이 돌았다 — %s %d의 마법진이 맺혔다. 책을 덮고(ESC) 쏴 보세요" % [unit, pw], false)
	_refresh_buttons()


## 맺은 도안에 변형형 문양이 끼어 있나 — 리포트 위력 표시 단위를 가른다.
## 🔴 계열 판별의 단일 소스는 문양 데이터이고 코드 목록은 `Db`가 준다 — 판정식을 여기 베끼지 마라.
func _has_modifier_glyph() -> bool:
	var mods: Array = Db.modifier_codes()
	if mods.is_empty():
		return false
	for layer_v in RingDesign.layers_of(_committed_asm.get("rings", []) as Array):
		for g in (layer_v as Array):
			if int(g) in mods:
				return true
	return false


## 🔴 **헤드리스 조립 seam** — 클릭 경로를 안 타고 층 상태를 세운다.
## 테스트가 private을 직접 더듬으면 리팩터 때 **조용히** 죽는다(`-s`는 런타임 에러가 나도
## failures=0으로 OK를 찍는다). 없는 메서드 호출은 `SCRIPT ERROR`로 잡힌다 — 그 차이 때문에 이게 있다.
func set_assembly_state(jin: StringName, bands: Array[StringName]) -> void:
	_sel_jin = jin
	_resize_bands(bands.size())
	for i in mini(bands.size(), _bands.size()):
		_bands[i] = bands[i]


## 🔴 발사 계약 조립 — 밴드를 **층 배열**로 + 통째 점수 + 잉크/크기.
## ⚠ `_board.get_assembly()`를 계약으로 쓰지 마라 — 이 모드에선 rings·score가 빈 값이라
## 조용히 기준 위력으로 나간다. board_asm은 **특별잉크 집계**를 뽑는 창구로만 쓴다.
func build_assembly() -> Dictionary:
	var band_defs := _band_defs()
	# 🔴 `layer_rings`다 — 평탄화하면 밴드가 8칸 하나로 뭉개져 **감쌈 순서가 사라진다**(순서가 곧 연산이다).
	var rings := RingBoard.layer_rings(band_defs)
	var open: Array = []
	for ring_v in rings:
		for k in (ring_v as Array).size():
			if int((ring_v as Array)[k]) != RingBoard.GLYPH_NONE and not (k in open):
				open.append(k)   # 층들의 **합집합** — 렌더·요약용(발사는 층 배열을 그대로 본다)
	open.sort()
	var score := _score_now()
	var board_asm := _board.get_assembly()
	# 🔴 룬은 **목록**("runes")이 정본이고 "rune"(primary)은 단일 룬을 읽는 옛 소비자용이다 —
	# 발사부는 "runes"로 융합한다. 둘 중 하나만 채우면 두 번째 룬이 조용히 사라진다.
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

## 지금 점수를 라벨에 쓴다. 색 = 안정권이면 먹빛·이하면 흐린 회갈(빨강 금지).
## 🔴 경계 판정은 `is_stable`이 한다 — 기준선 숫자를 여기 베끼지 마라.
func _update_score() -> void:
	# 조립 단계엔 아직 안 그었으니 점수 줄을 비운다 — 0% 잡음 제거.
	if _phase == Phase.ASSEMBLE or not _board.is_tracing():
		_score_num.text = ""
		_score_sub.text = ""
		return
	# 🔴 점수 출처는 `_score_now()` **하나**다 — 여기서 `combined_total()`을 직접 읽으면
	# 폐지 모드에서 이 자리만 0점을 세팅한다.
	var total := _score_now()
	_score_num.text = "%d" % _pct(total)
	_score_num.add_theme_color_override(&"font_color",
		SCORE_STRONG if RingPower.is_stable(total) else SCORE_WEAK)
	# 완성도·정밀도는 **손 긋기 축**이라 폐지 모드엔 영구 0%다 — 없는 축을 0으로 적으면
	# 위의 종합 점수와 모순된다. 그 모드의 근거는 리포트가 보여 준다.
	if RingPower.skip_drawing():
		_score_sub.text = ""
	else:
		_score_sub.text = "완성도 %d%% · 정밀도 %d%%" % [
			int(round(_board.coverage() * 100.0)), int(round(_board.accuracy() * 100.0))]


## 단계별 버튼 — ASSEMBLE=[시작]·[부품 제작] / DRAW=[분석 ▶] / RESULT=리포트. [다시 조립]은 둘 다.
func _refresh_buttons() -> void:
	var assemble := _phase == Phase.ASSEMBLE
	_next_btn.visible = assemble
	_next_btn.disabled = not _can_start_draw()
	# [분석 ▶]은 아무것도 맺지 않는다 — 이름이 하는 일과 같아야 한다.
	_commit_btn.visible = _phase == Phase.DRAW
	_commit_btn.text = "✓ 맺힘" if _committed else "분석 ▶"
	_commit_btn.disabled = not _has_attempt()
	_redraw_btn.visible = not assemble
	# 🔴🔴 [⚒ 부품 제작]은 **CommitBtn과 같은 칸을 시분할한다**(이쪽 ASSEMBLE, 저쪽 DRAW) —
	#   한쪽의 visible 조건을 바꾸려면 다른 쪽을 같이 봐라.
	#   ⚠ 왼쪽 칸으로 옮기면 `SayLabel`과 글자가 겹친다(헤드리스는 이 겹침을 못 본다).
	_craft_btn.visible = assemble


## 🔴 반올림은 core가 판다 — 「퍼펙트」가 "표시가 100이 되는 순간"으로 정의돼 있어
## 여기서 따로 반올림하면 등급과 표시가 갈라진다.
func _pct(score: float) -> int:
	return RingPower.score_display(score)


func _set_say(text: String, warn: bool) -> void:
	if text == "":
		return
	_say.text = text
	_say.add_theme_color_override(&"font_color", WARN_COLOR if warn else SAY_COLOR)


# ─────────────────────────── 외부 조회 ───────────────────────────

## 맺은 발사 계약 — ⚠ `_board.get_assembly()`가 아니다(그건 이 모드에서 rings·score가 빈 값이다).
func get_assembly() -> Dictionary:
	if not _committed:
		return {}
	return _committed_asm


## 맺을 만한 시도가 있나 — 여는 쪽이 "쏠 수 있나"를 물을 때 쓴다.
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
	_set_phase(Phase.ASSEMBLE)   # 펑·[다시]는 조립 단계로 되돌린다(리포트 닫힘·탭 잠금 리셋)
	_set_say(_start_copy(), false)   # 🔴 open()과 **같은 술어** — 모드를 여기서 다시 갈래 치지 마라


func play_cast() -> void:
	_board.play_cast()


# ─────────────────────────── 분석 리포트 렌더 (코드 렌더 — 씬에 없다) ───────────────────────────

## 분석 리포트 렌더 — 종합 등급·점수 + 조립 요약 + 점수 막대.
func _draw_report() -> void:
	var w := _report.size.x
	var h := _report.size.y
	# 배경 나인패치가 없으면 플랫 렌더로 폴백.
	if _report_sb != null:
		_report.draw_style_box(_report_sb, Rect2(Vector2.ZERO, Vector2(w, h)))
	else:
		_report.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0.94, 0.90, 0.82, 0.98), true)
		_report.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), EDGE, false, 2.0)
	var font := ThemeDB.fallback_font

	var total := float(_analysis.get("total", 0.0))
	var grade := RingPower.grade_of(total)   # 🔴 등급은 core가 판다
	_report.draw_string(font, Vector2(14, 26), "마법진 분석",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TITLE_COLOR)

	# 🔴 등급 **이름을 == 비교하지 마라** — 이름이 바뀌면 퍼펙트가 조용히 평범해진다.
	var perfect := RingPower.is_perfect(total)
	if perfect:
		_report.draw_rect(Rect2(8, 36, w - 16, 22), Color(1.0, 0.86, 0.45, 0.35), true)
	_report.draw_string(font, Vector2(14, 52),
		("종합 %d점 · ★ %s ★" if perfect else "종합 %d점 · %s") % [_pct(total), grade],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15 if perfect else 13,
		Color(0.72, 0.48, 0.05) if perfect else Color(0.55, 0.30, 0.12))

	# 위력 = 이 진이 **버텨 준다면** 낼 힘. 발사와 같은 함수로 뽑는다.
	# ⚠ **견디는지는 여기서 말하지 마라** — 미리 판정을 흘리면 [마력 주입]이 결과를 확인하는
	# 형식 절차가 된다. 눌러 봐야 아는 게 그 버튼의 전부다.
	var ink_id := StringName(_finish_asm.get("ink", &""))
	var size := float(_finish_asm.get("size", 1.0))
	_report.draw_string(font, Vector2(14, 68), "위력 %d  (기준 100)"
		% RingPower.power_display(total, Db.ink_mult(ink_id), size),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.35, 0.30, 0.20))

	# 잉크·특별효과 요약 한 줄 (있을 때만) — 무엇이 위력·효과를 올렸나.
	var effects: Array[String] = []
	if ink_id != &"" and not is_equal_approx(Db.ink_mult(ink_id), 1.0):
		effects.append("%s ×%.1f뎀" % [_ink_name(ink_id), Db.ink_mult(ink_id)])
	var sratio := float(_finish_asm.get("special_ratio", 0.0))
	var sink := StringName(_finish_asm.get("special_ink", &""))
	if sratio > 0.0 and sink != &"":
		effects.append("%s 화상 ×%.2f" % [_ink_name(sink), Db.status_mult_of(sink, sratio)])
	if not effects.is_empty():
		_report.draw_string(font, Vector2(14, 82), " · ".join(effects),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.50, 0.32, 0.14))

	# **무엇을 조립했나** 한 줄 — 층·문양이 늘수록 길어지므로 카드 폭에 맞춰 최대 2줄로 나눈다.
	# ⚠ 폭은 아래 막대와 **같은 식**을 쓴다 — 좌표를 따로 베끼면 둘이 갈라진다.
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

	# 🔴 **아래 절반은 모드로 갈린다.** 폐지 모드엔 「그은 양」이라는 축 자체가 없어서,
	# 분기 없이 두면 「종합 70점」 옆에 「완성도 0% · 정밀도 0%」와 "(획 없음)"이 같이 뜬다.
	if RingPower.skip_drawing():
		_report.draw_string(font, Vector2(14, REPORT_BODY_Y), "점수 근거",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, REPORT_NAME)
		_draw_parts(Rect2(14.0, REPORT_BOX_Y, w - 28.0, REPORT_BOX_BOTTOM - REPORT_BOX_Y))
	else:
		_report.draw_string(font, Vector2(14, REPORT_BODY_Y),
			"완성도 %d%% · 정밀도 %d%%" % [
				int(round(_board.coverage() * 100.0)), int(round(_board.accuracy() * 100.0))],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, REPORT_DESC)
		# '탁본 종이' — 내가 그은 획을 종이 위에 눌러 찍은 프리뷰.
		_report.draw_string(font, Vector2(14, REPORT_BODY_Y + 18.0), "탁본",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, REPORT_NAME)
		_draw_rubbing(Rect2(14.0, REPORT_BOX_Y + 24.0, w - 28.0,
			REPORT_BOX_BOTTOM - REPORT_BOX_Y - 24.0))


## 내가 그은 먹선을 종이 톤 상자 안에 **자동 맞춤**해 그린다. 좌표가 board-local이라
## 획들의 실제 경계로 스케일·정렬한다.
func _draw_rubbing(box: Rect2) -> void:
	_report.draw_rect(box, RUBBING_BG, true)
	_report.draw_rect(box, RUBBING_EDGE, false, 1.5)
	# 네 귀퉁이 눌린 자국 — "탁본지" 질감 힌트(도형 금지의 명시적 예외).
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


## 폐지 모드 리포트 — **무엇이 이 점수를 만들었나**. 부품이 유일한 성장 축이라 그걸 보여줘야
## 「좋은 부품을 모으면 세진다」가 손끝에 닿는다.
## 🔴 문자열은 전부 `parts_headline()`·`score_reason()`(순수·공개)이 만든다 — 렌더는 헤드리스가
## 못 봐도 문자열은 볼 수 있어 숫자 어긋남을 그물이 잡는다. 여기 남는 건 좌표·색뿐이다.
## ⚠ 부품 수는 `assembled_parts()`에서 온다 — 따로 세지 마라.
func _draw_parts(box: Rect2) -> void:
	_report.draw_rect(box, PARTS_BG, true)
	_report.draw_rect(box, PARTS_EDGE, false, 1.5)
	var font := ThemeDB.fallback_font
	var x := box.position.x + PARTS_PAD
	var y := box.position.y + PARTS_PAD + 12.0
	_report.draw_string(font, Vector2(x, y), parts_headline(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, REPORT_NAME)
	y += 18.0
	# 층마다 무엇이 끼었나 — 안쪽(1층)부터 = 연산 순서. **빈 층도 적는다**: 층 자리 자체가
	# 점수에 들어가므로 안 적으면 "왜 이 점수인가"가 안 맞는다.
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


## 「부품」 머리줄 — 🔴 공개인 이유는 헤드리스 관측점이기 때문이다(렌더는 못 봐도 문자열은 본다).
func parts_headline() -> String:
	var parts := assembled_parts()
	return "층 %d겹 · 문양 %d개" % [parts.y, parts.x]


## 「점수 근거」 한 줄. 🔴 기여도를 **`assembled_score`의 차이로** 뽑는다 — balance 수치를
## 베끼면 조율할 때 리포트만 거짓말한다.
## 🔴 셋을 「반올림한 값의 차」로 내야 점수가 1.0에서 클램프돼도 바탕+문양+층 = 종합이 유지된다.
func score_reason() -> String:
	var parts := assembled_parts()
	var base := _pct(RingPower.assembled_score(0, 1))
	var with_glyphs := _pct(RingPower.assembled_score(parts.x, 1))
	var full := _pct(RingPower.assembled_score(parts.x, parts.y))
	return "바탕 %d + 문양 %d + 층 %d = 종합 %d점" % [
		base, with_glyphs - base, full - with_glyphs, full]


## 한 줄을 폭 안에서 최대 `max_lines`줄로 나눈다(넘치면 마지막 줄을 …로 줄인다).
## 🔴 static·순수 = 헤드리스 관측점 — `_draw_report` 안에 두면 잘림 회귀를 아무도 못 잡는다.
## ⚠ 공백으로만 자른다. 공백 없는 긴 낱말은 그 줄에서 …로 줄인다 — **폭을 안 넘기는 게 계약**이다.
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


## 리포트의 "무엇을 조립했나" 한 줄 — 진 · 룬 · 층(밴드별 문양-고리).
func _compose_summary() -> String:
	var jd := Db.get_jin(_sel_jin)
	var jin_name := String(jd.display_name) if jd != null else "?"
	# 🔴 룬은 여럿일 수 있다 — 다 적는다.
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


## 책 껍데기 렌더 — 책 몸은 BookArt 텍스처가 그린다. 여기는 **그림자만** 깔고,
## 텍스처가 없을 때만 코드 렌더(종이 두 장 + 책등 그라데이션)로 폴백한다.
func _draw_pages() -> void:
	var on := _pages
	var shadow := BOOK_RECT.grow(3.0)
	on.draw_rect(shadow, SHADOW, true)
	if _book_art != null and _book_art.texture != null:
		return   # 책 몸·책등은 텍스처가 이 위에 얹힌다
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
