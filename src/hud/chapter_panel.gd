extends Control
## 챕터 선택 패널 — 베이스의 숲길 게이트 [E]로 열리는 모달 (세58-B 세피리아식 메인 루프).
## `Db.chapters_sorted()`를 열 때마다 읽어 카드로 그리고, 열린 챕터 카드를 클릭하면
## `chapter_selected(id)`를 쏘고 스스로 닫는다. 전환(pending_chapter 대입·change_scene)은
## base가 한다 — 패널은 "어느 챕터인가"만 알린다.
##
## 🔴 **잠금 판정은 이 패널이 한다** (해금 판정은 패널이 — 룬 셀 선례, takbon-rules §3).
## 판정식 = order==1 이거나 앞 챕터(=order가 바로 앞인 챕터)의 클리어 codex
## (`Db.chapter_clear_id`)가 해금돼 있다. boss_room은 잠금을 모른다(pending_chapter를 믿는다 —
## 이 패널이 유일한 입구). 판정식은 `is_chapter_open()` 공개 메서드 한 곳 — 헤드리스 테스트
## (test_chapter_auto ⓖ)가 이걸 직접 잰다(loot_panel의 loot_card/advance 선례).
##
## 🔴 **loot_panel / tab_panel과 완전히 같은 모달 규약이다**(loot_panel이 참고 원본):
##  · 열리면 mouse_filter=STOP → 화면을 덮어 좌클릭을 통째로 먹는다(패널을 보며 실수로 안 쏜다).
##  · 닫히면 visible=false → GUI 히트테스트에서 빠져 클릭이 다시 바닥(발사·이동)으로 샌다.
##  · 열림/닫힘에 GameState.ui_modal_open을 토글 → player(이동)·caster(조준·발사)가 폴링해 멎는다.
##  · 닫힌 Control도 _unhandled_input은 받는다(mouse_filter는 마우스만 가른다) → _open 가드로 가둔다.
##
## ⚠ 헤드리스는 클릭 도달·렌더를 못 잡는다(세25 함정) — 카드 클릭은 `select_card(i)` 공개 훅으로
## 데이터 로직만 검증하고, 실제 클릭 도달·렌더는 리드가 실게임 push_input·MCP 스샷으로 확인한다.
##
## 🔴 **CanvasLayer(layer 5) 위에 산다**(chapter_panel.tscn — loot_panel·tab_panel과 같은 층).
## 스크립트는 자식 $Panel에 있다 — 여는 쪽은 `인스턴스.get_node("Panel")`로 API를 잡는다(chest 선례).
##
## 🔴 class_name 선언 금지(서브에이전트 규칙) — base가 씬을 preload로 문다.

## 열린(또는 클리어된) 챕터 카드를 클릭한 순간 emit — 이어서 스스로 닫는다(closed도 1회 온다).
## base가 받아 `GameState.pending_chapter = id` + change_scene_to_file(boss_room)을 한다.
signal chapter_selected(id: StringName)
## 어떤 경로로든 닫힐 때 정확히 한 번 emit — ESC/E 취소·챕터 선택 완료 둘 다 온다.
## ⚠ "취소"가 아니라 "모달이 끝났다"다 — 취소만 구분하고 싶으면 chapter_selected 수신 여부로 가른다.
signal closed

# ── 레이아웃 (연출값 — 밸런스 아님. loot_panel 선례) ──
const PANEL_W := 480.0
const PAD := 22.0
const HINT_H := 20.0
const CARDS_TOP := 78.0      # 패널 origin.y 기준, 카드 목록 시작 y
const CARD_H := 74.0         # 세 줄(제목·보스·상태)이 들어가는 높이
const CARD_GAP := 10.0

# ── 색 (loot_panel·tab_panel 팔레트 계열 — 한지·먹 톤) ──
const BACKDROP := Color(0.03, 0.025, 0.02, 0.82)
const PANEL_BG := Color(0.12, 0.10, 0.08, 0.98)
const PANEL_EDGE := Color(0.48, 0.43, 0.34, 0.9)
const TITLE_COLOR := Color(0.96, 0.90, 0.78)
const HINT_COLOR := Color(0.66, 0.62, 0.54)
const EMPTY_COLOR := Color(0.60, 0.56, 0.50)

const CARD_BG := Color(0.17, 0.15, 0.12, 0.95)
const CARD_EDGE := Color(0.40, 0.37, 0.31, 0.7)
const CARD_BG_LOCKED := Color(0.11, 0.10, 0.09, 0.95)   # 잠김 — 가라앉은 회갈
const NAME_COLOR := Color(0.93, 0.89, 0.80)
const BOSS_COLOR := Color(0.72, 0.66, 0.56)
const LOCKED_COLOR := Color(0.45, 0.43, 0.40)           # 잠긴 카드의 모든 글줄
const STATE_OPEN_COLOR := Color(0.85, 0.76, 0.52)       # "입장" — 금 계열(진행 바 채움과 같은 결)
const STATE_CLEAR_COLOR := Color(0.55, 0.78, 0.55)      # "✓ 클리어" — 완료 초록
const EDGE_OPEN := Color(0.72, 0.62, 0.40, 0.9)         # 열린 카드 테두리 강조

var _open: bool = false
## open() 시점의 Db.chapters_sorted() 스냅샷 — 그리기·클릭·select_card가 같은 목록을 본다.
var _chapters: Array[ChapterDef] = []


func _ready() -> void:
	# 닫힌 동안엔 클릭을 먹지 않는다(visible=false면 GUI 히트테스트에서 빠진다).
	# 열리면 STOP이라 좌클릭을 통째로 먹는다 — 모달 뒤 게임(발사)을 클릭에서 지키는 게 의도다.
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


# ─────────────────────────── 공개 API (base·테스트가 배선) ───────────────────────────

## 패널을 연다(모달). 챕터 목록은 이 순간 Db에서 새로 읽는다 — 클리어 직후 돌아와 다시 열면
## 다음 챕터가 열려 보이는 이유(스냅샷을 씬에 굳히지 않는다).
func open() -> void:
	_chapters = Db.chapters_sorted()
	_open = true
	visible = true
	GameState.ui_modal_open = true
	# 챕터가 0장이어도 크래시 없이 "챕터가 없다"를 그린다 — .tres 파싱 침묵사(세50)가
	# 빈 화면이 아니라 글줄로 드러나게 하는 방어선이기도 하다.
	queue_redraw()


## 패널이 열려 있나 (base가 게이트 재진입 가드 등에 참고).
func is_open() -> bool:
	return _open


## 🔴 공개 — 잠금 판정 단일 소스. 챕터 N은 첫 챕터(order 1)이거나, order가 바로 앞인 챕터의
## 클리어 codex(`Db.chapter_clear_id`)가 해금돼 있어야 열린다. 클리어된 챕터도 계속 열려 있다
## (재입장 = 파밍 재방문). 헤드리스 테스트(test_chapter_auto ⓖ)가 clear codex를 넣고 빼며 잰다.
## ⚠ order 사이가 비어도(1·3만 있어도) "가장 가까운 앞 챕터"로 판정한다 — 데이터 구멍에 안 죽는다.
func is_chapter_open(ch: ChapterDef) -> bool:
	if ch == null:
		return false
	if ch.order <= 1:
		return true
	var prev: ChapterDef = null
	for c in Db.chapters_sorted():
		if c.order < ch.order and (prev == null or c.order > prev.order):
			prev = c
	if prev == null:
		return true   # 앞 챕터가 아예 없으면 첫 챕터 취급(잠글 근거가 없다)
	return GameState.is_unlocked(Db.chapter_clear_id(prev))


## 🔴 공개 — 클리어 여부(✓ 표시·테스트용). 키 파생은 Db.chapter_clear_id 한 곳 — 여기서 문자열을
## 조립하지 않는다(세50 계열 오타 함정).
func is_chapter_cleared(ch: ChapterDef) -> bool:
	if ch == null:
		return false
	return GameState.is_unlocked(Db.chapter_clear_id(ch))


## 🔴 공개 — index번째(=order 순) 카드를 고른다. _gui_input(카드 클릭)도 이걸 부르고, 헤드리스
## 테스트도 이걸로 구동한다(클릭 도달은 헤드리스가 못 잡으므로). 잠긴 카드·범위 밖·닫힌 상태면
## 무시. 열린 카드면 chapter_selected(id) emit 후 스스로 닫는다(closed도 이어서 1회).
func select_card(index: int) -> void:
	if not _open:
		return
	if index < 0 or index >= _chapters.size():
		return
	var ch := _chapters[index]
	if not is_chapter_open(ch):
		return   # 잠김 — 클릭 무시
	var id := ch.id
	chapter_selected.emit(id)
	_close()


# ─────────────────────────── 입력 ───────────────────────────

## 열려 있고 좌클릭이면 카드 rect를 히트테스트해 select_card(i). root가 STOP이라 마우스가 여기로
## 온다. 🔴 _draw와 같은 _card_rects()를 봐서 그린 곳과 누른 곳이 어긋나지 않는다(loot_panel 선례).
func _gui_input(event: InputEvent) -> void:
	if not _open:
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var rects := _card_rects()
	for i in rects.size():
		if rects[i].has_point(mb.position):
			select_card(i)   # 잠긴 카드는 select_card가 무시한다
			accept_event()
			return
	# 카드 밖 클릭도 STOP이 이미 먹었다(실수 발사 방지) — 소비만 하고 아무 일도 안 한다.
	accept_event()


## ESC(ui_cancel) / E(interact)로 닫는다. 닫힌 Control도 _unhandled_input을 받으므로 _open 가드.
## E도 받는 이유 = 게이트를 [E]로 열었으니 같은 키로 덮는 게 손에 맞다(loot_panel/상자 선례).
func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	var want_close := event.is_action_pressed("ui_cancel")
	if not want_close and InputMap.has_action("interact") and event.is_action_pressed("interact"):
		want_close = true
	if want_close:
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	GameState.ui_modal_open = false
	closed.emit()


# ─────────────────────────── 카드 rect (단일 소스) ───────────────────────────

## 카드 수에 맞춰 패널 높이가 늘어난다 — 챕터 개수(지금 3장)를 하드코딩하지 않는다.
func _panel_size() -> Vector2:
	var n := maxi(_chapters.size(), 1)   # 0장이어도 "챕터가 없다" 한 줄 들어갈 높이
	return Vector2(PANEL_W, CARDS_TOP + n * (CARD_H + CARD_GAP) - CARD_GAP + PAD)


func _origin() -> Vector2:
	return ((size - _panel_size()) * 0.5).round()


## 카드 rect들(Control 로컬 좌표). _draw와 _gui_input이 공유하는 단일 소스 — 그린 것과 누른
## 곳이 어긋나지 않는다(loot_panel _card_rects 선례).
func _card_rects() -> Array[Rect2]:
	var o := _origin()
	var left := o.x + PAD
	var width := PANEL_W - PAD * 2.0
	var y := o.y + CARDS_TOP
	var rects: Array[Rect2] = []
	for i in _chapters.size():
		rects.append(Rect2(Vector2(left, y), Vector2(width, CARD_H)))
		y += CARD_H + CARD_GAP
	return rects


# ─────────────────────────── 그리기 ───────────────────────────

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP, true)

	var origin := _origin()
	var psize := _panel_size()
	draw_rect(Rect2(origin, psize), PANEL_BG, true)
	draw_rect(Rect2(origin, psize), PANEL_EDGE, false, 2.0)

	# 제목 + 안내
	draw_string(font, origin + Vector2(PAD, 30.0), "챕터 선택",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, TITLE_COLOR)
	draw_string(font, origin + Vector2(PAD, 30.0 + HINT_H + 4.0),
		"[클릭] 입장    ·    [ESC/E] 닫기",
		HORIZONTAL_ALIGNMENT_LEFT, PANEL_W - PAD * 2.0, 12, HINT_COLOR)

	if _chapters.is_empty():
		draw_string(font, origin + Vector2(PAD, CARDS_TOP + 20.0),
			"챕터가 없다 (data/chapters/*.tres 로드 실패?)",
			HORIZONTAL_ALIGNMENT_LEFT, PANEL_W - PAD * 2.0, 13, EMPTY_COLOR)
		return

	var rects := _card_rects()
	for i in rects.size():
		_draw_card(font, rects[i], _chapters[i])


## 카드 한 장 — 제N장 제목 · 보스 이름 · 상태 줄. 상태 3종:
##  열림 = 테두리 강조 + "입장" / 잠김 = 회색 전체 + "이전 챕터를 클리어하라" / 클리어 = "✓ 클리어 — 재입장 가능".
func _draw_card(font: Font, rect: Rect2, ch: ChapterDef) -> void:
	var opened := is_chapter_open(ch)
	var cleared := is_chapter_cleared(ch)

	draw_rect(rect, CARD_BG if opened else CARD_BG_LOCKED, true)
	draw_rect(rect, EDGE_OPEN if (opened and not cleared) else CARD_EDGE, false, 1.0)

	var name_c := NAME_COLOR if opened else LOCKED_COLOR
	var boss_c := BOSS_COLOR if opened else LOCKED_COLOR
	var title_text := "제%d장  %s" % [ch.order, ch.title]
	draw_string(font, rect.position + Vector2(14.0, 22.0), title_text,
		HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 28.0, 15, name_c)

	var enemy := Db.get_enemy(ch.boss_enemy_id)
	var boss_name := enemy.display_name if enemy != null and enemy.display_name != "" \
		else String(ch.boss_enemy_id)
	draw_string(font, rect.position + Vector2(14.0, 42.0), "보스: %s" % boss_name,
		HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 28.0, 12, boss_c)

	var state_text := ""
	var state_c := STATE_OPEN_COLOR
	if cleared:
		state_text = "✓ 클리어 — 재입장 가능"
		state_c = STATE_CLEAR_COLOR
	elif opened:
		state_text = "입장 가능"
	else:
		state_text = "잠김 — 이전 챕터를 클리어하라"
		state_c = LOCKED_COLOR
	draw_string(font, rect.position + Vector2(14.0, 62.0), state_text,
		HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 28.0, 12, state_c)
