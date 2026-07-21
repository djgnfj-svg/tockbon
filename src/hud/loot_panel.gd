extends Control
## 상자 루팅 패널 — 보스를 잡으면 떨어지는 상자를 [E]로 열면 뜨는 모달.
## 상자 안 아이템을 카드로 보여 주고, 카드를 클릭하면 **등급별로 정해진 시간 동안 진행 바가
## 자동으로 차고**, 다 차면 그 아이템이 가방에 들어간다(타르코프식 능동 루팅). 홀드가 아니라
## 클릭-후-자동충전이다 — 방해가 없으니 홀드는 노동일 뿐이다. 등급 좋은 아이템일수록 오래
## 걸리고, 그게 화면에 보이는 게 이 패널의 핵심 연출이다.
##
## 🔴 **inventory_panel / tab_panel / map_panel과 완전히 같은 모달 규약이다**(그 셋이 참고 원본):
##  · 열리면 mouse_filter=STOP → 좌클릭을 통째로 먹어 상자를 보며 실수로 안 쏜다(그 클릭이 루팅이다).
##  · 닫히면 visible=false → GUI 히트테스트에서 빠져 클릭이 다시 바닥(발사·이동)으로 샌다.
##  · 열림/닫힘에 GameState.ui_modal_open을 토글 → player(이동)·caster(조준·발사)가 폴링해 멎는다.
##  · 닫힌 Control도 _unhandled_input은 받는다(mouse_filter는 마우스만 가른다) → _open 가드로 가둔다.
##
## 🔴 **mouse_filter 함정**(세션25): 화면을 덮는 이 루트가 열린 동안 STOP이라 좌클릭을 먹는다 —
## 카드 클릭이 곧 루팅이다. 닫히면 visible=false라 히트테스트에서 빠져 발사·이동이 되살아난다.
## ⚠ 헤드리스는 클릭·렌더를 못 잡는다 — 리드가 실게임 push_input(클릭 도달)·MCP 스샷(렌더)으로 확인.
## 그래서 loot_card(i)·advance(delta)를 공개로 뺐다 — 테스트는 이 둘로 데이터 로직만 검증한다.
##
## 🔴 **CanvasLayer(layer 5) 위에 산다**(loot_panel.tscn, tab_panel과 같은 층) — 카메라가
## 플레이어를 따라다녀 월드에 그리면 패널이 흘러간다(HUD와 같은 이유).
##
## 🔴 **contents 배열은 참조로 들고 remove_at 한다** — 상자가 같은 배열을 봐서 다 비면 스스로
## 사라진다(GDScript Array는 참조 전달). open()이 배열을 복사하지 않는 이유가 이것이다.
##
## 🔴 class_name 선언 금지(서브에이전트 규칙) — 리드가 preload로 문다.

## 상자 안 아이템 하나를 다 루팅해 가방에 넣은 순간 emit(연출/사운드 훅용).
signal item_looted(id: StringName, count: int)
## ESC/E로 닫힐 때, 또는 모두 루팅해 자동으로 닫힐 때 — 정확히 한 번 emit.
signal closed

# ── 레이아웃 (연출값 — 밸런스 아님. 선례: tab_panel의 PANEL_SIZE 등) ──
const PANEL_SIZE := Vector2(420.0, 460.0)
const PAD := 22.0
const TITLE_H := 30.0        # 제목 줄 높이(패널 상단 여백 안)
const HINT_H := 20.0         # 안내 줄 높이
const CARDS_TOP := 78.0      # origin.y 기준, 카드 격자 시작 y
const CARD_H := 54.0
const CARD_GAP := 8.0
const BAR_H := 6.0           # 카드 위 진행 바 높이
const BAR_GAP := 3.0         # 카드와 진행 바 사이 간격

# ── 등급별 루팅 시간(초) — 🔴 연출값(느낌)이라 스크립트 const다. 밸런스 아님(drop_pickup의 자석
# const 선례). 흔함은 거의 즉시, 전설은 뜸 들인다 — "좋은 건 오래 걸린다"가 화면에 읽혀야 한다.
# 사용자가 나중에 직접 열어 보며 조인다. 등급 1..5 → 인덱스 0..4, 밖이면 양끝으로 clamp.
const LOOT_TIMES: Array[float] = [0.2, 0.45, 0.8, 1.2, 1.6]

# ── 색 (tab_panel·map_panel 팔레트 계열 — 한지·먹 톤) ──
const BACKDROP := Color(0.03, 0.025, 0.02, 0.82)
const PANEL_BG := Color(0.12, 0.10, 0.08, 0.98)
const PANEL_EDGE := Color(0.48, 0.43, 0.34, 0.9)
const TITLE_COLOR := Color(0.96, 0.90, 0.78)
const HINT_COLOR := Color(0.66, 0.62, 0.54)
const EMPTY_COLOR := Color(0.60, 0.56, 0.50)

const CARD_BG := Color(0.17, 0.15, 0.12, 0.95)
const CARD_EDGE := Color(0.40, 0.37, 0.31, 0.7)
const CARD_BG_ACTIVE := Color(0.24, 0.21, 0.15, 1.0)   # 루팅 중인 카드 강조
const NAME_COLOR := Color(0.93, 0.89, 0.80)
const GRADE_COLOR := Color(0.64, 0.60, 0.52)
const COUNT_COLOR := Color(0.98, 0.86, 0.52)

const BAR_BG := Color(0.28, 0.25, 0.20, 1.0)
const BAR_FILL := Color(0.92, 0.78, 0.42)   # 진행 바 채움(금)

## 등급 색 — 🔴 단일 소스는 `src/core/grade_colors.gd` (세션51에 사본 셋을 합쳤다).
const GradeColors := preload("res://src/core/grade_colors.gd")

var _open: bool = false
## 🔴 참조로 들고 remove_at 한다(상자가 같은 배열을 본다). 사본을 만들면 상자가 못 비운다.
var _contents: Array = []

## 루팅 진행 상태 — -1이면 아무 카드도 루팅 중이 아니다(한 번에 하나).
var _loot_active: int = -1
var _loot_t: float = 0.0
var _loot_dur: float = 0.0


func _ready() -> void:
	# 닫힌 동안엔 클릭을 먹지 않는다(visible=false면 GUI 히트테스트에서 빠진다).
	# 열리면 STOP이라 좌클릭을 통째로 먹어 상자를 보며 실수로 안 쏜다.
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


# ─────────────────────────── 공개 API (리드·상자가 배선) ───────────────────────────

## 상자를 연다(모달). contents = Array of {"id": StringName, "count": int}.
## 🔴 이 배열을 **참조로** 들고, 루팅 완료된 항목을 이 배열에서 remove_at 한다 — 상자가 같은
## 배열을 봐서 다 비면 스스로 사라진다. 그래서 복사하지 않는다.
func open(contents: Array) -> void:
	_contents = contents
	_loot_active = -1
	_loot_t = 0.0
	_loot_dur = 0.0
	_open = true
	visible = true
	GameState.ui_modal_open = true
	# 빈 상자로 열려도 크래시 없이 "비었다" 한 줄만 그린다(닫기는 사용자가 ESC/E로). 상자 쪽이
	# 애초에 빈 상자를 안 만드는 게 정상이지만, 방어적으로 여기서도 버틴다.
	queue_redraw()


## 상자가 열려 있나 (리드가 토글·게이트를 배선할 때 참고).
func is_open() -> bool:
	return _open


## 🔴 공개 — index번째 카드의 루팅을 시작한다. _gui_input(카드 클릭)도 이걸 부르고, 헤드리스
## 테스트도 이걸로 구동한다(클릭은 헤드리스가 못 잡으므로). 이미 다른 카드를 루팅 중이면 무시
## (한 번에 하나) · 범위 밖이면 무시.
func loot_card(index: int) -> void:
	if not _open:
		return
	if _loot_active != -1:
		return   # 이미 루팅 중 — 한 번에 하나
	if index < 0 or index >= _contents.size():
		return   # 범위 밖
	_loot_active = index
	_loot_t = 0.0
	_loot_dur = _loot_time_for(_grade_at(index))
	queue_redraw()


## 🔴 공개 — 진행 중인 루팅을 delta만큼 진행시킨다. _process(delta)가 이걸 부르고, 테스트가
## advance(999.0)로 즉시 완료시켜 검증한다. 루팅 중이 아니면 no-op.
func advance(delta: float) -> void:
	if _loot_active == -1:
		return
	_loot_t += delta
	if _loot_t < _loot_dur:
		queue_redraw()
		return
	# ── 완료 ──
	var i := _loot_active
	# 인덱스가 배열 밖으로 어긋났으면(방어) 상태만 리셋.
	if i < 0 or i >= _contents.size():
		_loot_active = -1
		_loot_t = 0.0
		_loot_dur = 0.0
		queue_redraw()
		return
	var entry: Dictionary = _contents[i]
	var id: StringName = entry.get("id", &"") as StringName
	var count: int = int(entry.get("count", 1))
	# 🔴 가방에 넣는 시점 = 루팅 완료(drop_pickup의 "도착에 add_to_bag" 계약과 같은 결).
	if id != &"":
		GameState.add_to_bag(id, count)
		EventBus.item_collected.emit(id, count)   # 세51 획득 토스트가 이걸 듣는다.
		item_looted.emit(id, count)
	# 🔴 상자가 보는 그 배열에서 지운다 — 참조라 상자도 비어 가는 걸 본다.
	_contents.remove_at(i)
	_loot_active = -1
	_loot_t = 0.0
	_loot_dur = 0.0
	# 🔴 다 비면 자동으로 닫는다. 안 비면 계속 열려 다음 카드를 루팅한다.
	if _contents.is_empty():
		_close()
	else:
		queue_redraw()


func _process(delta: float) -> void:
	if _open and _loot_active != -1:
		advance(delta)


# ─────────────────────────── 입력 ───────────────────────────

## 열려 있고 좌클릭이면 카드 rect를 히트테스트해 맞는 index로 loot_card(i). root가 STOP이라
## 마우스가 여기로 온다. 🔴 _draw와 같은 _card_rects()를 봐서 그린 곳과 누른 곳이 어긋나지 않는다.
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
			loot_card(i)
			accept_event()
			return
	# 카드 밖 클릭도 STOP이 이미 먹었다(실수 발사 방지) — 소비만 하고 아무 일도 안 한다.
	accept_event()


## ESC(ui_cancel) / E(interact)로 닫는다. 닫힌 Control도 _unhandled_input을 받으므로 _open 가드.
## 루팅 진행 중이어도 닫을 수 있다(그 항목은 아직 가방에 안 들어갔으니 상자에 그대로 남는다).
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
	_loot_active = -1
	_loot_t = 0.0
	_loot_dur = 0.0
	closed.emit()


# ─────────────────────────── 등급·시간 헬퍼 ───────────────────────────

## index번째 항목의 등급(Db.get_item.grade). 알 수 없으면 1.
func _grade_at(index: int) -> int:
	if index < 0 or index >= _contents.size():
		return 1
	var id: StringName = (_contents[index] as Dictionary).get("id", &"") as StringName
	var it := Db.get_item(id)
	return it.grade if it != null else 1


## 등급 → 루팅 시간(초). 배열 밖 등급은 양끝으로 clamp(GradeColors.of와 같은 결).
func _loot_time_for(grade: int) -> float:
	return LOOT_TIMES[clampi(grade - 1, 0, LOOT_TIMES.size() - 1)]


# ─────────────────────────── 카드 rect (단일 소스) ───────────────────────────

func _origin() -> Vector2:
	return ((size - PANEL_SIZE) * 0.5).round()


## 카드 rect들(Control 로컬 좌표). _draw와 _gui_input이 공유하는 단일 소스 — 그린 것과 누른
## 곳이 어긋나지 않는다(tab_panel _tab_header_rects 선례).
func _card_rects() -> Array[Rect2]:
	var o := _origin()
	var left := o.x + PAD
	var width := PANEL_SIZE.x - PAD * 2.0
	var y := o.y + CARDS_TOP
	var rects: Array[Rect2] = []
	for i in _contents.size():
		rects.append(Rect2(Vector2(left, y), Vector2(width, CARD_H)))
		y += CARD_H + CARD_GAP
	return rects


# ─────────────────────────── 그리기 ───────────────────────────

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP, true)

	var origin := _origin()
	draw_rect(Rect2(origin, PANEL_SIZE), PANEL_BG, true)
	draw_rect(Rect2(origin, PANEL_SIZE), PANEL_EDGE, false, 2.0)

	# 제목 + 안내
	draw_string(font, origin + Vector2(PAD, 30.0), "상자",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, TITLE_COLOR)
	draw_string(font, origin + Vector2(PAD, 30.0 + HINT_H + 4.0),
		"[클릭] 줍기    ·    [ESC/E] 닫기",
		HORIZONTAL_ALIGNMENT_LEFT, PANEL_SIZE.x - PAD * 2.0, 12, HINT_COLOR)

	if _contents.is_empty():
		draw_string(font, origin + Vector2(PAD, CARDS_TOP + 20.0),
			"상자가 비었다",
			HORIZONTAL_ALIGNMENT_LEFT, PANEL_SIZE.x - PAD * 2.0, 13, EMPTY_COLOR)
		return

	var rects := _card_rects()
	for i in rects.size():
		_draw_card(font, rects[i], i)


## 카드 한 장 — 등급 색 띠 + 이름 + ★등급 + ×수량. 루팅 중이면 카드 위에 진행 바를 그린다.
func _draw_card(font: Font, rect: Rect2, index: int) -> void:
	var entry: Dictionary = _contents[index]
	var id: StringName = entry.get("id", &"") as StringName
	var count: int = int(entry.get("count", 1))
	var it := Db.get_item(id)
	var grade := it.grade if it != null else 1
	var is_active := index == _loot_active

	# 진행 바 — 루팅 중인 카드에만, 카드 위쪽에 그린다.
	if is_active:
		var bar_rect := Rect2(
			Vector2(rect.position.x, rect.position.y - BAR_H - BAR_GAP),
			Vector2(rect.size.x, BAR_H))
		draw_rect(bar_rect, BAR_BG, true)
		var frac := 0.0 if _loot_dur <= 0.0 else clampf(_loot_t / _loot_dur, 0.0, 1.0)
		if frac > 0.0:
			draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * frac, BAR_H)),
				BAR_FILL, true)

	# 카드 본체
	draw_rect(rect, CARD_BG_ACTIVE if is_active else CARD_BG, true)
	draw_rect(rect, CARD_EDGE, false, 1.0)
	draw_rect(Rect2(rect.position, Vector2(4.0, rect.size.y)), GradeColors.of(grade), true)

	var name_text := it.display_name if it != null and it.display_name != "" else str(id)
	draw_string(font, rect.position + Vector2(14.0, 22.0), name_text,
		HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 90.0, 14, NAME_COLOR)
	draw_string(font, rect.position + Vector2(14.0, 42.0), "★%d" % grade,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GRADE_COLOR)
	draw_string(font, rect.position + Vector2(rect.size.x - 62.0, 32.0), "×%d" % count,
		HORIZONTAL_ALIGNMENT_RIGHT, 56.0, 15, COUNT_COLOR)
