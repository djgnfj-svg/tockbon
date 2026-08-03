extends Control
## 마법진 조립창 — 🔴 **이 단계는 뒷판과 제목뿐이다.**
##  동심원·층 고리·룬 자리·팔레트는 **단계 3~5의 일이다. 미리 만들지 않는다.**
##
## 🔴🔴 **`mouse_filter`가 이 창의 계약이고, 이 단계가 재는 것 전부다.**
##
## ```
##  이 노드의 사각형 안  →  STOP    클릭이 발사로 안 샌다
##  그 밖                →  이 노드가 없는 것과 같다  →  **창을 연 채로 쏴진다**
## ```
##
##  🔴 밖에서 쏴지는 것이 「세상이 안 멈춘다」의 증거다(기획 판정 4). 그래서 **전면 `Control`을
##   깔지 않는다** — 화면을 덮는 순간 `IGNORE`든 `STOP`이든 그 증거가 사라지거나 발사가 죽는다.
##  ⚠ 값은 `stage.tscn`에 적혀 있고 **여기서 런타임에 덮어쓰지 않는다.** 덮어쓰면 씬에 적힌 값이
##   아무 의미 없는 거짓 손잡이가 되고, 나중에 모달이 뒤를 막아야 할 때 그걸 조용히 뒤엎는다
##   (`stage.gd`의 같은 주석 — v1 실측).
##
## 🔴 창은 `HUD`(`CanvasLayer`) 아래다. `Node2D`로 두면 **화면 흔들림에 창이 같이 흔들린다.**
##  ⚠ 그래서 클릭 좌표에 `stage_input._to_world`를 쓰면 안 된다 — `CanvasLayer`는 카메라 변환을
##   안 받으므로 되돌릴 변환이 없다. 되돌리면 흔들리는 동안 클릭이 엉뚱한 데로 간다.
##
## ⚠ **`focus_mode`는 NONE이어야 한다**(씬에 적혀 있다). 창 안 `Control`에 포커스가 잡히면
##  Tab이 `ui_focus_next`로 GUI에서 소비되어 `_unhandled_input`에 **안 온다** ⇒ 「Tab이 안 먹는다」.
##  🔴 증상이 「입력 맵을 안 고쳤다」와 똑같아서 진단이 오래 걸린다 — 포커스를 먼저 의심해라.

const Fx := preload("res://src/view/fx_tuning.gd")
const Layout := preload("res://src/view/circle_layout.gd")
## 🔴 창 축은 **따로다.** 창이 둘을 조립하고, `circle_layout`은 `book_layout`을 모른다.
const Book := preload("res://src/view/book_layout.gd")
## 🔴 팔레트는 **「슬롯 종류 × 항목」**이다 — 문양 전용으로 짜면 단계 5에서 통째로 다시 짠다.
const Palette := preload("res://src/view/palette_layout.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const SpellCircle := preload("res://src/actor/spell_circle.gd")
## 🔴 진을 **빼는** 값이 여기서 온다 — 창이 `0`을 박으면 예약값이 두 곳이 된다.
const CircleDefs := preload("res://src/sim/circle_defs.gd")

## 🔴🔴 **사본이 아니라 참조다** — 총구와 **같은 것**을 읽는다(계획 §1의 단일 소스).
##  디버그 키 4↔5를 누르면 그림이 뒤집히는 것이 그 증거고, 사본을 두면 그 증거가 사라진다.
## ⚠ **읽기만 한다.** 이 단계는 **클릭으로 못 놓는다**(단계 4).
var _circle: SpellCircle = null

## 지금 고른 팔레트 항목. `_picked_kind < 0`이면 아무것도 안 골랐다.
## 🔴 **종류까지 든다** — 진·룬·문양 셋이 다 골라지므로 항목 id만으로는 무엇인지 모른다.
##  ⚠ 딕셔너리가 아니라 정수 둘인 이유: 키 오타가 원리적으로 없고 할당도 없다.
var _picked_kind := -1
var _picked_item := -1


func setup(circle: SpellCircle) -> void:
	_circle = circle
	queue_redraw()


## ⚠ 조립 상태가 바뀌는 **순간**이 따로 없다(디버그 키·조립창 둘 다 모델을 직접 만진다).
##  ⇒ 열려 있는 동안 매 프레임 다시 그린다. `character_view`가 총구에 쓰는 방식과 같다.
##  🔴 닫혀 있으면 아무것도 안 한다 — 창은 대개 닫혀 있다.
func _process(_dt: float) -> void:
	if visible:
		queue_redraw()


func _ready() -> void:
	# 🔴 **이 사각형이 곧 상호작용 영역이다** — `mouse_filter`가 여기서만 먹는다.
	#  치수는 `fx_tuning`이 단일 소스다(씬에 offset을 적으면 두 곳이 된다).
	position = Fx.WINDOW_RECT.position
	size = Fx.WINDOW_RECT.size


## Tab. ⚠ 껍데기가 `visible`을 직접 만지지 않게 문을 하나만 둔다 — 나중에 열고 닫을 때
##  할 일이 늘면(포커스·애니메이션) 그게 여기 한 곳에 붙는다.
func toggle() -> void:
	visible = not visible
	# ⚠ 닫을 때 고른 것을 놓는다 — 안 놓으면 다시 열었을 때 **아무도 안 고른 줄 아는데**
	#  다음 슬롯 클릭이 옛 항목을 놓는다.
	_clear_pick()


# ══════════════════════════════════════════════════════════════════
#  클릭 — 🔴🔴 **고르고 → 놓는다. 놓인 것을 다시 누르면 뺀다**
#
#  ⚠🔴 **여기 아래 함수들을 그물이 못 부른다.** 트리 밖 `Control`이라 `_gui_input`도
#   `_draw`도 안 돌고, 그물이 세울 수도 없다. 경계선이 이렇다:
#     · **정적 좌표 함수**(`circle_layout` · `palette_layout` · `book_layout`) → 그물이 잰다
#     · **`Control` 메서드**(`_gui_input` · `_click_*` · `_place_or_clear` · `_can_pick`) → **안 재진다**
#   ⇒ **verify-run·verify-look이 유일한 감지기다.** 여기를 고치면 그물이 초록이어도
#    아무것도 보증되지 않는다는 걸 알고 고쳐라.
#  🔴 그래서 **판단을 최대한 좌표 함수와 모델로 밀어냈다** — 여기 남은 것은 배선뿐이어야 한다.
# ══════════════════════════════════════════════════════════════════

## 🔴🔴 **`_gui_input`이라 좌표가 이미 창 안쪽 기준이다.** `_unhandled_input`으로 받으면
##  화면 좌표라 창 위치를 또 빼야 하고, 그 뺄 값이 두 곳이 되는 순간 어긋난다.
##  ⚠ 그리고 창이 `STOP`이라 여기 안 받으면 **클릭이 어디에도 안 간다** — 발사로도 안 샌다.
##
## 🔴🔴 **위험 22 — 그리기는 변환 안에서 하고 클릭은 밖에서 받으면 조용히 어긋난다.**
##  아래가 그 답이다: 그리기가 더한 `page.position`을 **여기서 뺀다.** 뺄 값이
##  `book_layout`의 같은 함수에서 나오므로 둘이 갈라질 수가 없다.
##  ⚠ 리포에 같은 실측이 있다 — `stage_input._to_world`가 캔버스 변환을 안 되돌리면
##   「흔드는 동안 조준이 엉뚱한 셀로 간다」(에러 없음).
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	# ⚠ 창 안 클릭은 **발사가 아니다.** 안 먹으면 조립하다 마법이 나간다.
	accept_event()
	if _circle == null:
		return

	var pal := Book.palette_page(size)
	if pal.has_point(mb.position):
		_click_palette(pal, mb.position - pal.position)
		return
	var page := Book.circle_page(size)
	if page.has_point(mb.position):
		_click_circle(page, mb.position - page.position)


## 팔레트에서 고른다. 같은 것을 다시 누르면 고르기를 놓는다.
func _click_palette(pal: Rect2, local: Vector2) -> void:
	var hit := Palette.item_at(pal.size, local)
	if hit.is_empty():
		return
	var kind := int(hit["kind"])
	var item := int(hit["item"])
	# 🔴🔴 **못 놓는 것은 애초에 안 골라진다.** 골라지고 나서 슬롯이 안 받으면
	#  「눌렀는데 아무 일도 안 난다」가 되고 그게 고장으로 읽힌다(기획).
	if not _can_pick(kind, item):
		return
	if _picked_kind == kind and _picked_item == item:
		_clear_pick()
		return
	_picked_kind = kind
	_picked_item = item


## 슬롯을 누른다. 🔴 고른 게 있으면 **놓고**, 없으면 **뺀다**(계획 §9-1).
##
## 🔴🔴 **세 종류가 같은 규칙이다.** 종류마다 다르면 배울 게 셋이 된다.
## ⚠ **안쪽부터 본다** — 진 슬롯은 테두리 안 전체라 층·룬 자리를 먼저 안 보면 그것들을 다 먹는다.
func _click_circle(page: Rect2, local: Vector2) -> void:
	var area := Layout.circle_area(page.size)
	var id := _circle.circle_id()

	var layer := Layout.layer_at(id, area, local)
	if layer >= 0:
		_place_or_clear(Palette.KIND_GLYPH, func(v: int) -> void:
			_circle.place_glyph(layer, v), Glyph.GLYPH_NONE)
		return

	var slot := Layout.rune_slot_at(id, area, local)
	if slot >= 0:
		_place_or_clear(Palette.KIND_RUNE, func(v: int) -> void:
			_circle.set_rune(slot, v), SpellCircle.RUNE_EMPTY)
		return

	if Layout.frame_has_point(area, local):
		_place_or_clear(Palette.KIND_CIRCLE, func(v: int) -> void:
			_circle.set_circle(v), CircleDefs.CIRCLE_NONE)


## 🔴 **놓기와 빼기의 규칙이 여기 한 곳에 있다.** 종류마다 적으면 세 벌이 되고,
##  그중 하나만 고치는 날 「문양은 빼지는데 룬은 안 빠진다」가 된다.
##  ⚠ 고른 것이 **다른 종류**면 아무 일도 안 한다 — 룬을 골라 층에 놓는 것은 뜻이 없다.
func _place_or_clear(kind: int, put: Callable, empty: int) -> void:
	if _picked_kind < 0:
		put.call(empty)
		return
	if _picked_kind != kind:
		return
	put.call(_picked_item)
	# 고르고 → 놓는다가 한 동작이다. 놓았으면 손을 비운다.
	_clear_pick()


func _clear_pick() -> void:
	_picked_kind = -1
	_picked_item = -1


## 🔴🔴 **셋이 같은 물음을 지난다: 「이 항목을 받아 줄 슬롯이 하나라도 있나」.**
##
## ⚠🔴 **여기서 실제 결함이 났다**(verify-look, 2026-08-04). 이 함수가 **문양에만** 묻고
##  진·룬에는 늘 `true`를 주고 있었다 ⇒ 진을 빼면 룬 자리가 0개인데 **룬이 밝게 남아 골라지고,
##  골라 놓고 어디를 눌러도 아무 일이 없었다.** 기획이 경계한 「눌리는데 아무 일도 안 난다」다.
##
## 🔴 **규칙이 종류마다 갈린 것 자체가 원인이었다** — `_place_or_clear`를 한 곳에 모은 것과
##  같은 이유다. 「문양은 막히는데 룬은 안 막힌다」는 「문양은 빼지는데 룬은 안 빠진다」와 같은 병이다.
##  ⇒ 종류마다 다른 것은 **슬롯을 세는 법**과 **받는 조건** 둘뿐이고, 물음은 하나다.
func _can_pick(kind: int, item_id: int) -> bool:
	for i in _slot_count(kind):
		if _slot_accepts(kind, i, item_id):
			return true
	return false


## 그 종류의 슬롯이 몇 개인가. 🔴 **전부 모델에서 나온다** — 진을 빼면 층도 룬 자리도 0이 되고,
##  그러면 위 물음이 저절로 「놓을 데가 없다」로 떨어진다.
func _slot_count(kind: int) -> int:
	if kind == Palette.KIND_CIRCLE:
		# ⚠ 진 슬롯은 테두리 자리 **하나**고 **진이 없어도 있다**(`circle_layout.frame_has_point`).
		#  그래야 진을 뺀 사용자가 다시 놓을 수 있다 — 0으로 두면 **갇힌다.**
		return 1
	if kind == Palette.KIND_RUNE:
		return _circle.rune_count()
	if kind == Palette.KIND_GLYPH:
		return _circle.layer_count()
	push_error("CircleWindow: 모르는 슬롯 종류 %d — 슬롯 수를 0으로 본다" % kind)
	return 0


## 그 슬롯이 이 항목을 받나. 🔴 **제약이 있는 것은 문양뿐**이고 그 제약은 `glyph_defs.DEFS`에서 온다.
##  ⚠ 여기서 **다시 안 적는다**(`can_place_glyph`를 부른다) — 적으면 규칙이 두 벌이 되고
##   `net_circle`의 양방향 일치가 재던 것이 무의미해진다.
## ⚠ **빈 층만 본다.** 확산이 1층에 있을 때 1층에 덮어쓰는 것은 규칙상 되지만, 그걸 허용하면
##  「확산이 있는데 확산이 눌린다」로 보인다. ⇒ 옮기려면 먼저 빼는 것이 한 규칙이다.
func _slot_accepts(kind: int, index: int, item_id: int) -> bool:
	if kind != Palette.KIND_GLYPH:
		return true
	return _circle.glyph_at(index) == Glyph.GLYPH_NONE \
		and _circle.can_place_glyph(index, item_id)


func _draw() -> void:
	# ⚠ 좌표가 **창 안쪽 기준**이다(`Control`의 `_draw`는 자기 사각형 원점을 쓴다).
	#  화면 좌표를 쓰면 창을 옮길 때 그림만 안 따라온다.
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Fx.WINDOW_BG, true)
	draw_rect(r, Fx.WINDOW_EDGE, false, Fx.WINDOW_EDGE_PX)

	# ⚠ 폰트가 없으면 **그리지 않는다.** `null`을 넘기면 엔진이 매 프레임 짖고,
	#  래퍼가 stderr를 실패로 치니 그 순간 그물이 통째로 빨개진다.
	var font := get_theme_default_font()
	if font == null:
		return
	draw_string(font,
		Vector2(Fx.WINDOW_PAD_PX, Fx.WINDOW_PAD_PX + float(Fx.WINDOW_TITLE_SIZE)),
		Fx.WINDOW_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1,
		Fx.WINDOW_TITLE_SIZE, Fx.WINDOW_TITLE_COLOR)

	# ── 책 펼침 ──
	# 🔴 페이지 사각형은 `book_layout` 하나에서 온다 — 그림과 (단계 4b의) 클릭이 같이 읽는다.
	#  ⚠ 접힘을 여기서 따로 그리면 **보이는 경계와 클릭 경계가 갈린다**(위험 23).
	var pages := Book.pages(size)
	draw_rect(pages["left"], Fx.BOOK_PAGE, true)
	draw_rect(pages["right"], Fx.BOOK_PAGE, true)
	draw_rect(pages["fold"], Fx.BOOK_FOLD, true)
	# ⚠ 왼쪽 페이지는 **일부러 비어 있다** — 팔레트는 단계 4b·5다.

	if _circle == null:
		return

	# 🔴🔴 **마법진을 오른쪽 페이지로 옮기는 것은 좌표계 변환이다.** 마법진 좌표에 페이지 위치를
	#  더하지 않는다 — 더하면 `circle_layout`이 자기가 어디 앉았는지 알게 되고, 창 모양이
	#  바뀌는 날 마법진 코드가 같이 열린다(§3.7).
	#  ⚠ **그 대가로 단계 4b가 이 변환을 되돌려 클릭을 받아야 한다**(위험 22).
	#   뺄 값은 `pages()["right"].position` — **여기서 쓰는 것과 같은 값**이다.
	# 🔴 **어느 페이지가 마법진인가는 `book_layout`이 정한다.** 여기서 키를 박으면 좌우를
	#  뒤집는 날 창과 그물이 따로 뒤집혀 **한쪽만 옮겨 간 채로 초록**이 된다(§3.7 — 이미 한 번 뒤집혔다).
	var page := Book.circle_page(size)
	draw_set_transform(page.position)

	# 🔴 **좌표는 전부 `circle_layout`에서 온다.** 여기서 하나라도 계산하면
	#  단계 4b의 히트테스트가 다른 좌표를 쓰게 되고, 그건 에러 없이 엉뚱한 층으로 간다.
	var area := Layout.circle_area(page.size)
	var id := _circle.circle_id()
	_draw_frame(area)
	_draw_rune_slot(area, id)
	# ⚠🔴 **여기 층 수는 모델(`layer_count()`)에서 오고, `_draw_ring` 안의 고리 반지름은
	#  표(`layer_rings()`)에서 온다 — 소스가 둘이다.** 오늘은 둘 다 `circle_defs`에서 파생돼
	#  같은 수지만, 어긋나는 날 `_draw_ring`의 `layer >= rings.size()` 가드가
	#  **짖지도 않고 덜 그린다**(모델이 더 많으면) 또는 **덜 돈다**(표가 더 많으면).
	#  🔴 화면에서는 「층이 하나 안 보인다」로만 읽힌다. 하나로 합칠 거면 **표 쪽**으로 합쳐라 —
	#   그림은 그릴 자리를 표에서 받아야 하고, 모델은 그 자리에 무엇이 놓였는지만 안다.
	for i in _circle.layer_count():
		_draw_ring(area, id, i, font)

	# ⚠ **반드시 되돌린다.** 안 되돌리면 뒤에 그리는 것이 전부 페이지만큼 밀린다 —
	#  아래 팔레트가 정확히 그 「뒤에 그리는 것」이다.
	draw_set_transform(Vector2.ZERO)

	# 🔴 팔레트도 **자기 페이지 안에서** 원점 기준으로 그린다. 마법진과 같은 규율이다.
	var pal := Book.palette_page(size)
	draw_set_transform(pal.position)
	_draw_palette(pal, font)
	draw_set_transform(Vector2.ZERO)


# ══════════════════════════════════════════════════════════════════
#  🔴🔴 축 셋 — **서로를 안 부른다**
#   룬이 둘이 되는 날 열리는 것은 `_draw_rune_slot` 하나뿐이다.
# ══════════════════════════════════════════════════════════════════

## 진 축 — 그릇의 가장자리. ⚠ 진이 없어도 **자리는 그린다.** 그게 「빈 슬롯」이고,
##  진을 뺐을 때 마법진이 슬롯 하나로 줄어드는 것이 눈에 보이는 이유다(단계 5).
func _draw_frame(area: Rect2) -> void:
	var f := Layout.frame(area)
	# 🔴 **팔레트의 진과 같은 함수를 쓴다.** 여기서 따로 그리면 진 테두리를 바꾸는 날
	#  **팔레트의 진만 안 따라온다** — 룬·문양은 이미 함수를 공유하는데 진만 안 하는 상태였다.
	_draw_circle_symbol(f["center"], f["radius"])


## 룬 축 — 룬 자리. ⚠ 자리 **수**도 자리 **위치**도 진 표에서 나온다.
## 🔴 빈 룬은 총구가 꺼질 때와 **같은 회색**이다 — 같은 뜻이라 같은 색이어야 한 눈에 이어진다.
##  ⚠ 「왜 못 쏘나」를 글로 적는 것은 단계 5다. 여기는 **상태를 정직하게 그리는 것**까지다.
##
## ⚠🔴 **여기서 나는 짖음은 「사건마다 한 번」이 아니라 「매 프레임」이다.**
##  `Layout.rune_slots()`가 `rune_slots != 1`에 짖는데 이 함수는 창이 열려 있는 동안 **초당 60번**
##  불린다 ⇒ 룬 2자리 진이 오는 날 로그가 초당 60줄로 덮이고, 래퍼의 stderr 검사도 그만큼 시끄러워진다.
##  🔴 **지금은 안 걸린다**(룬이 1자리다). 룬을 늘리는 사람이 **그때** 짖음을 프레임 밖으로 옮겨라 —
##   `spell_sim._run_glyph`의 짖음은 착탄마다 한 번이라 비용이 전혀 다르다. 아래 `_draw_glyph`도 같다.
func _draw_rune_slot(area: Rect2, circle_id: int) -> void:
	var r := Layout.rune_radius(area)
	var slots := Layout.rune_slots(circle_id, area)
	for i in slots.size():
		var rune_id := _circle.rune_at(i)
		if rune_id == SpellCircle.RUNE_EMPTY:
			# 🔴🔴 **「못 쏜다」를 말하는 셋째 장치다**(§3.5 — 총구·HUD는 단계 1에 이미 섰다).
			#  ⚠ 룬의 빈 자리는 **경고**지 「놓을 수 있다」(초대)가 아니다 —
			#   층의 빈 자리(`+`)와 **뜻이 달라서 그림도 다르다.**
			#   🔴 총구가 꺼질 때와 **같은 회색**이라 두 화면이 같은 말을 한다.
			draw_circle(slots[i], r, Fx.MUZZLE_DEAD, false, Fx.MUZZLE_DEAD_WIDTH_PX)
			continue
		_draw_rune_symbol(slots[i], r, rune_id)


## 층 축 — 고리 하나 + 층 번호 + 놓인 문양.
##
## 🔴🔴 **「안쪽이 먼저」에 장치가 둘 걸려 있다**(기획 판정 3):
##   ① **층 번호** 1·2를 고리 옆에 적는다
##   ② **명도차** — 안쪽이 밝고 밖으로 갈수록 어둡다. 층 수로 나눠 섞으므로 3층이 와도 자동이다
##  ⚠ 동심원 하나만으로는 순서가 **있다**까지만 말하고 **어느 쪽이 먼저인지**는 안 말한다.
func _draw_ring(area: Rect2, circle_id: int, layer: int, font: Font) -> void:
	var rings := Layout.layer_rings(circle_id, area)
	if layer < 0 or layer >= rings.size():
		return
	var n := rings.size()
	# ⚠ 1층뿐이면 나눌 것이 없다 — 0으로 나누면 그림이 통째로 사라진다.
	var t := 0.0 if n <= 1 else float(layer) / float(n - 1)
	# ⚠ **`frame()`을 부르지 않는다.** 중심은 어느 축에도 안 속한 공유값이고,
	#  여기서 진 축을 부르면 층 축이 거기 매달린다(`circle_layout.center` 주석).
	var c := Layout.center(area)
	draw_circle(c, rings[layer], Fx.CIRCLE_RING_INNER.lerp(Fx.CIRCLE_RING_OUTER, t),
		false, Fx.CIRCLE_RING_PX)

	if font != null:
		# 9시 방향. ⚠ 문양 심볼이 12시에 앉으므로 거기 적으면 겹친다.
		# ⚠ 글자 크기도 미는 거리도 **반지름에서 파생한다** — 크기만 키우고 밀기를 px로 두면
		#  글자가 커질수록 고리에 파묻힌다.
		var num := Layout.layer_num_size(area)
		draw_string(font, c + Vector2(
				-rings[layer] + float(num) * Fx.CIRCLE_LAYER_NUM_INSET_FRAC,
				-float(num) * Fx.CIRCLE_LAYER_NUM_LIFT_FRAC),
			str(layer + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, num, Fx.CIRCLE_LAYER_NUM)

	var slots := Layout.layer_slots(circle_id, area)
	if layer >= slots.size():
		return
	var glyph_id := _circle.glyph_at(layer)
	# 🔴🔴 **빈 자리도 그린다 — 「여기 놓을 수 있다」가 그림에 있어야 한다.**
	#  ⚠ 안 그리면 「막힌 자리」와 「빈 자리」가 같아 보이고, 단계 4b-2b에서 어디를 눌러야
	#   하는지가 화면에 없다(슬롯 상태 셋 중 첫째 — `fx_tuning.SLOT_EMPTY` 주석).
	if glyph_id == Glyph.GLYPH_NONE:
		_draw_empty_slot(slots[layer], Layout.glyph_radius(area))
		return
	_draw_glyph(slots[layer], Layout.glyph_radius(area), glyph_id)


## 🔴🔴 **모양은 `kind`, 색은 문양 id.** 문양마다 그림을 두면 그게 **넷째 고칠 곳**이 되고,
##  `glyph_defs.gd`가 스스로 「넷째 곳이 생기면 구조가 틀린 것이니 멈춘다」고 적어 뒀다.
##  ⇒ 새 문양은 모양을 **공짜로** 얻는다. 「바꿈」이 오는 날 kind가 셋이 되고 모양도 셋이 된다.
## 🔴 그리고 그 축이 **파이프라인의 전부**라(design 문서) **그림이 규칙을 가르친다.**
func _draw_glyph(at: Vector2, r: float, glyph_id: int) -> void:
	if not Glyph.DEFS.has(glyph_id):
		push_error("CircleWindow: 표에 없는 문양 %d — 그릴 수 없다" % glyph_id)
		return
	var tint: Color = Fx.GLYPH_TINT.get(glyph_id, Fx.GLYPH_TINT_MISSING)
	var kind := int(Glyph.DEFS[glyph_id]["kind"])
	if kind == Glyph.KIND_SPAWN:
		# 밖으로 뻗는 가지 — **새 탄을 만든다**가 모양에 있다.
		for k in Fx.GLYPH_SPAWN_RAYS:
			# ⚠ 반 칸 돌린다 — 안 돌리면 수평 갈래가 고리 선에 포개져 **사라진다**
			#  (`fx_tuning.GLYPH_SPAWN_ANGLE_STEP_FRAC` 주석에 실측이 있다).
			var a := TAU * (float(k) + Fx.GLYPH_SPAWN_ANGLE_STEP_FRAC) / float(Fx.GLYPH_SPAWN_RAYS)
			var d := Vector2(cos(a), sin(a))
			draw_line(at + d * (r * Fx.GLYPH_SPAWN_INNER_RATIO), at + d * r,
				tint, Fx.GLYPH_SYMBOL_PX)
		return
	if kind == Glyph.KIND_TERMINAL:
		# 채운 원반 — **그 자리에서 끝난다**가 모양에 있다.
		draw_circle(at, r * Fx.GLYPH_TERMINAL_RATIO, tint, true)
		return
	# 🔴 모르는 kind에 짖는다 — 표에 종류를 늘리고 그림을 안 늘리면 여기서 걸린다.
	push_error("CircleWindow: 문양 종류 %d에 그림이 없다" % kind)


## 룬 심볼 — 빛나는 구슬. 🔴 **팔레트와 슬롯이 같은 이 함수를 쓴다.**
##  따로 그리면 「팔레트의 불과 진에 놓인 불이 다르게 보인다」가 되고, 그건 조용하다.
func _draw_rune_symbol(at: Vector2, r: float, rune_id: int) -> void:
	var fx := Fx.elem_fx(rune_id)
	draw_circle(at, r, fx["glow"], true)
	draw_circle(at, r * Fx.CIRCLE_RUNE_CORE_RATIO, fx["core"], true)


## 진 심볼 — 그릇의 테두리. ⚠ 진은 **틀**이라 속이 비어 있는 것이 그 뜻이다.
func _draw_circle_symbol(at: Vector2, r: float) -> void:
	draw_circle(at, r, Fx.CIRCLE_FRAME, false, Fx.CIRCLE_FRAME_PX)


## 🔴🔴 **빈 자리 — 「여기 놓을 수 있다」.**
##  옅은 고리 + **더하기**. ⚠ 고리만 그리면 「자리」로만 읽히고 「놓을 수 있다」가 안 읽힌다.
##  ⚠ 채우면 TERMINAL 원반과 헷갈린다 — 비어 있는 것이 뜻의 일부다.
func _draw_empty_slot(at: Vector2, r: float) -> void:
	draw_circle(at, r, Fx.SLOT_EMPTY, false, Fx.SLOT_EMPTY_PX)
	var a := r * Fx.SLOT_PLUS_RATIO
	draw_line(at - Vector2(a, 0.0), at + Vector2(a, 0.0), Fx.SLOT_EMPTY, Fx.SLOT_PLUS_PX)
	draw_line(at - Vector2(0.0, a), at + Vector2(0.0, a), Fx.SLOT_EMPTY, Fx.SLOT_PLUS_PX)


# ══════════════════════════════════════════════════════════════════
#  팔레트 — 🔴 **「슬롯 종류 × 항목」.** 문양 전용이 아니다
# ══════════════════════════════════════════════════════════════════

## ⚠ **이 단계는 그리기까지다.** 클릭으로 고르고 놓는 것은 4b-2b다.
## 🔴 좌표는 전부 `palette_layout`에서 온다 — 히트테스트가 **같은 함수**를 부를 수 있어야 한다.
func _draw_palette(page: Rect2, font: Font) -> void:
	for ki in Palette.KINDS.size():
		var kind: int = Palette.KINDS[ki]
		var sec := Palette.section(page.size, ki)
		_draw_palette_section(sec, kind, font)
		# 🔴 항목은 **표를 순회해서** 나온다 — 손으로 적으면 표를 늘렸는데 팔레트가 안 늘어난다.
		var items := Palette.items_of(kind)
		for ii in items.size():
			var slot := Palette.item_slot(sec, ii, items.size())
			_draw_palette_item(slot, kind, items[ii])


## 구획 — 🔴 **빈 자리가 「무엇이 들어올 자리」로 읽히게 한다.** 항목이 넷뿐이라 페이지가 크게
##  비는데, 테두리와 제목이 없으면 같은 화면이 그냥 **미완성**으로 읽힌다.
func _draw_palette_section(sec: Rect2, kind: int, font: Font) -> void:
	draw_rect(sec, Fx.PALETTE_SECTION_BG, true)
	draw_rect(sec, Fx.PALETTE_SECTION_EDGE, false, Fx.PALETTE_SECTION_EDGE_PX)
	if font == null:
		return
	if not Palette.KIND_DEFS.has(kind):
		push_error("CircleWindow: 모르는 슬롯 종류 %d — 제목이 없다" % kind)
		return
	var nm: StringName = Palette.KIND_DEFS[kind]["name"]
	draw_string(font, sec.position + Vector2(
			Fx.PALETTE_PAD_PX, Fx.PALETTE_HEAD_PX * Fx.PALETTE_HEAD_BASELINE_FRAC),
		String(nm), HORIZONTAL_ALIGNMENT_LEFT, -1,
		Fx.PALETTE_HEAD_SIZE, Fx.PALETTE_HEAD_COLOR)


## 항목 하나. 🔴 **슬롯에 그리는 것과 같은 심볼 함수를 쓴다** — 따로 그리면
##  「팔레트의 폭발과 진에 놓인 폭발이 다르게 보인다」가 되고, 그건 조용하다.
func _draw_palette_item(slot: Rect2, kind: int, item_id: int) -> void:
	var at := slot.get_center()
	var r := Palette.item_symbol_radius(slot)

	if kind == Palette.KIND_CIRCLE:
		_draw_circle_symbol(at, r)
	elif kind == Palette.KIND_RUNE:
		_draw_rune_symbol(at, r, item_id)
	elif kind == Palette.KIND_GLYPH:
		_draw_glyph(at, r, item_id)
	else:
		push_error("CircleWindow: 슬롯 종류 %d에 항목 그림이 없다" % kind)
		return

	# 🔴🔴 **못 놓는 것은 흐리다** — 확산이 이미 있으면 두 번째 확산이 **애초에 안 눌린다**(기획).
	#  ⚠ 눌리는데 아무 일도 안 나면 그게 고장으로 읽힌다. 한 칸 앞에서 막는 게 요점이다.
	#  ⚠ **`modulate`를 쓰면 안 된다** — 노드 전체에 걸리고 다음 프레임까지 남는다.
	#   ⇒ 그 칸에만 **가림막**을 덮는다.
	# 🔴 세 종류가 같은 길을 지난다 — 제약이 문양에만 있는 것은 `_can_pick`이 안다.
	if not _can_pick(kind, item_id):
		draw_rect(slot, Color(Fx.PALETTE_SECTION_BG, Fx.PALETTE_BLOCKED_VEIL_A), true)
		return
	# 🔴 고른 것에 테두리. **연출이 아니라 동작의 절반이다** —
	#  무엇을 골랐는지 안 보이면 「고르고 → 놓는다」의 앞 절반이 화면에 없다.
	if _picked_kind == kind and _picked_item == item_id:
		draw_rect(slot, Fx.PALETTE_PICK, false, Fx.PALETTE_PICK_PX)
