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
const Glyph := preload("res://src/sim/glyph_defs.gd")
const SpellCircle := preload("res://src/actor/spell_circle.gd")

## 🔴🔴 **사본이 아니라 참조다** — 총구와 **같은 것**을 읽는다(계획 §1의 단일 소스).
##  디버그 키 4↔5를 누르면 그림이 뒤집히는 것이 그 증거고, 사본을 두면 그 증거가 사라진다.
## ⚠ **읽기만 한다.** 이 단계는 **클릭으로 못 놓는다**(단계 4).
var _circle: SpellCircle = null


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

	if _circle == null:
		return
	# 🔴 **좌표는 전부 `circle_layout`에서 온다.** 여기서 하나라도 계산하면
	#  단계 4의 히트테스트가 다른 좌표를 쓰게 되고, 그건 에러 없이 엉뚱한 층으로 간다.
	var area := Layout.circle_area(size)
	var id := _circle.circle_id()
	_draw_frame(area)
	_draw_rune_slot(area, id)
	for i in _circle.layer_count():
		_draw_ring(area, id, i, font)


# ══════════════════════════════════════════════════════════════════
#  🔴🔴 축 셋 — **서로를 안 부른다**
#   룬이 둘이 되는 날 열리는 것은 `_draw_rune_slot` 하나뿐이다.
# ══════════════════════════════════════════════════════════════════

## 진 축 — 그릇의 가장자리. ⚠ 진이 없어도 **자리는 그린다.** 그게 「빈 슬롯」이고,
##  진을 뺐을 때 마법진이 슬롯 하나로 줄어드는 것이 눈에 보이는 이유다(단계 5).
func _draw_frame(area: Rect2) -> void:
	var f := Layout.frame(area)
	draw_circle(f["center"], f["radius"], Fx.CIRCLE_FRAME, false, Fx.CIRCLE_FRAME_PX)


## 룬 축 — 룬 자리. ⚠ 자리 **수**도 자리 **위치**도 진 표에서 나온다.
## 🔴 빈 룬은 총구가 꺼질 때와 **같은 회색**이다 — 같은 뜻이라 같은 색이어야 한 눈에 이어진다.
##  ⚠ 「왜 못 쏘나」를 글로 적는 것은 단계 5다. 여기는 **상태를 정직하게 그리는 것**까지다.
func _draw_rune_slot(area: Rect2, circle_id: int) -> void:
	var r := Layout.rune_radius(area)
	var slots := Layout.rune_slots(circle_id, area)
	for i in slots.size():
		var rune_id := _circle.rune_at(i)
		if rune_id == SpellCircle.RUNE_EMPTY:
			draw_circle(slots[i], r, Fx.MUZZLE_DEAD, false, Fx.MUZZLE_DEAD_WIDTH_PX)
			continue
		var fx := Fx.elem_fx(rune_id)
		draw_circle(slots[i], r, fx["glow"], true)
		draw_circle(slots[i], r * 0.45, fx["core"], true)


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
		draw_string(font, c + Vector2(-rings[layer] + 3.0, -3.0), str(layer + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.CIRCLE_LAYER_NUM_SIZE, Fx.CIRCLE_LAYER_NUM)

	var glyph_id := _circle.glyph_at(layer)
	if glyph_id == Glyph.GLYPH_NONE:
		return
	var slots := Layout.layer_slots(circle_id, area)
	if layer < slots.size():
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
			var a := TAU * float(k) / float(Fx.GLYPH_SPAWN_RAYS)
			var d := Vector2(cos(a), sin(a))
			draw_line(at + d * (r * 0.3), at + d * r, tint, Fx.GLYPH_SYMBOL_PX)
		return
	if kind == Glyph.KIND_TERMINAL:
		# 채운 원반 — **그 자리에서 끝난다**가 모양에 있다.
		draw_circle(at, r * 0.8, tint, true)
		return
	# 🔴 모르는 kind에 짖는다 — 표에 종류를 늘리고 그림을 안 늘리면 여기서 걸린다.
	push_error("CircleWindow: 문양 종류 %d에 그림이 없다" % kind)
