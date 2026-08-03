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
